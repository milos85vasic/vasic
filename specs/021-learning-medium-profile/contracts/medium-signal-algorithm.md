# Contract: Medium Signal Algorithm (FR-003 – FR-008, FR-010)

This is the normative definition. `pkg/medium` implements it; `pipeline/medium_reference.py` re-implements it
independently as the test oracle (constitution §11.4.245, §11.4.249: producer, oracle and gate are different
actors). Pure functions: no I/O, no clock, no randomness, no network.

## 1. Inputs

`[]Observation` for ONE session (data-model §1.2), a `Config`, and a `Scope`.

```go
type Config struct {
    D           float64 // logistic divisor, imported from pkg/scoring config (default 1.5)
    NMin        int     // graded observations required PER medium to be compared (default 8)
    GapMin      float64 // minimum mean-residual gap to name a medium (default 0.10)
    ZLeaning    float64 // z for "leaning" (default 2.5 - delegate default, operator may amend; RETUNED by SC-009 simulation, was 0.67; research.md 3.1)
    ZPreferred  float64 // z for "preferred" (default 3.0 - delegate default, operator may amend; was 1.28)
    MaxObs      int     // newest rows read (default 5000)
    WindowDays  int     // 0 = all history (default 0)
    ConfirmLooks int    // consecutive evaluations with new evidence showing the same lead before it is suggested (default 3)
}
```

Boot validation (FR-019): `NMin ≥ 2`, `GapMin > 0`, `0 < ZLeaning < ZPreferred`, `MaxObs ≥ 100`, `ConfirmLooks ≥ 1`,
`WindowDays ≥ 0`, `D > 0`; else the server refuses to start with the offending key named.

## 2. Steps

1. **Filter**: keep observations of the scope (`overall` = all areas; `area` = that area), within `WindowDays`
   of the newest observation's `At` when `WindowDays > 0` (relative to the data, never to the wall clock).
2. **Grade**: `Graded` observations are performance evidence. Others increment `NTotal` only.
3. **Expected**: `p = 1 / (1 + 10^(−(θ − d)/D))` using the stored `ability_before` (θ) and `served_difficulty` (d).
4. **Aggregate per medium**: `n = NGraded`, `s = Observed`, `E = Σp`, `V = Σp(1−p)`, `m = (s − E)/n`,
   `se = √V / n` (zero when `n == 0`).
5. **Per-medium eligibility**: a question medium with `NTotal > 0` and `NGraded == 0` AND no possibility of
   machine grading (`short`) ⇒ `not_measurable`. A medium with `0 < n < NMin` ⇒ `insufficient_evidence`.
6. **Comparison** among the eligible mediums (`n ≥ NMin`): sort by `m` descending, ties broken by medium name
   ascending (determinism). Best `a`, runner-up `b`:
   `g = m_a − m_b`, `se_g = √(se_a² + se_b²)`, `z = g / se_g` (if `se_g == 0` ⇒ `z = 0`: a zero-variance
   comparison is never evidence of a preference).
7. **State of the best medium**:
   - fewer than two eligible mediums ⇒ every medium `insufficient_evidence` for *comparison* (own numbers shown);
   - `g ≥ GapMin` and `z ≥ ZPreferred` ⇒ `preferred`;
   - `g ≥ GapMin` and `z ≥ ZLeaning` ⇒ `leaning`;
   - otherwise ⇒ `no_clear_preference` for all eligible mediums.
   Non-best eligible mediums are `no_clear_preference` (never "worst").
8. **Recommendation**: only `preferred` or `leaning` yield a medium. Reason `preferred_by_evidence` /
   `leaning_by_evidence`. `insufficient_evidence` / `no_clear_preference` yield `Medium = nil`, reason
   `no_signal_yet` (FR-006).
9. **Override** (applied last, FR-009): `off` ⇒ state `off_by_learner`, no evidence computed for display;
   `pinned(m)` ⇒ `Medium = m`, reason `learner_pinned`, `Overridden = true`, evidence still attached.
10. **Area scope fallback** (FR-010): compute the area scope; if it yields no eligible comparison, compute the
    overall scope and, if that yields a recommendation, return it with `Scope = overall`,
    reason `scope_fallback_overall`.

## 3. State machine (per medium and scope)

```
            +-------------------+
   start -> | no observations   |--(any observation)--> counting
            +-------------------+
 counting --(NGraded==0 && medium=short)----------------> not_measurable
 counting --(0<NGraded<NMin)----------------------------> insufficient_evidence
 counting --(NGraded>=NMin, <2 eligible mediums)--------> insufficient_evidence (comparison)
 counting --(>=2 eligible, g<GapMin or z<ZLeaning)-------> no_clear_preference
 counting --(g>=GapMin, ZLeaning<=z<ZPreferred)----------> leaning
 counting --(g>=GapMin, z>=ZPreferred)-------------------> preferred
 any state --(preference.mode=off)-----------------------> off_by_learner
```

Transitions are monotone only in the evidence, not in time: a `preferred` medium may fall back to
`no_clear_preference` when later evidence erodes the gap. The UI states the date range of evidence.

## 4. Explanation payload (FR-007)

```json
{
  "scope": "overall",
  "mediums": [
    {"medium":"mcq","n_total":4,"n_graded":4,"observed":3,"expected":1.1658,
     "mean_residual":0.4586,"std_error":0.1903,"state":"preferred"},
    {"medium":"flashcard","n_total":4,"n_graded":4,"observed":2,"expected":1.9326,
     "mean_residual":0.0168,"std_error":0.2158,"state":"no_clear_preference"}
  ],
  "comparison": {"best":"mcq","runner_up":"flashcard","gap":0.4417,"z":1.535},
  "thresholds": {"n_min":3,"gap_min":0.10,"z_leaning":0.67,"z_preferred":1.28,"confirm_looks":1},
  "evidence_refs": ["01J9…", "01J9…"],
  "window": {"from":"…","to":"…","truncated":false},
  "text": "Multiple choice went 1.8 answers better than expected over 4 graded answers; flashcards went 0.1 better over 4."
}
```

`text` is produced by a fixed template with numbers substituted (no model). Rounding: figures to 4 dp in the
payload, 1 dp in `text`; rounding happens only at serialisation.

## 5. Determinism requirements

- Sort every slice before aggregation (entry id ascending); sum in that order (floating-point addition order is
  part of the contract; the reference implementation uses the same order).
- No map iteration order may reach the output (iterate sorted keys).
- No `time.Now()` inside `pkg/medium`; `At` comes from the data; the HTTP layer injects `now` only for
  `set_at` stamps on the preference store.
- Locale-independent number formatting.

## 5a. Persistence (review F1)

A lead (`leaning` or `preferred`) is surfaced only when the same leading format was the verdict on `ConfirmLooks` consecutive evaluations,
each with evidence that differs from the previous one (a new graded answer). The state is kept per (learner, scope) as (verdict, evidence
fingerprint, counter). Until then the scope is reported `no_clear_preference` with a `confirmation` note (`seen`, `needed`), the numbers stay
visible and nothing is recommended. `gap_min` is a practical-significance floor that binds only for large samples (roughly above 300 graded
answers per format, where a statistically clear but tiny gap would otherwise be named).

## 6. Non-goals

No ML, no Bayesian posterior, no bandit, no clustering, no cross-learner prior, no LLM. See `research.md` §2 for
why each alternative was rejected and under what evidence it would be reconsidered.
