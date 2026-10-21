# Phase 1 Data Model: Learning-Medium Profile

Everything performance-related is **derived at read time** from spec 013's append-only response log. The only
state this feature persists is the learner's own preference, consent and (US4 only) engagement events.

## 1. Derived (never stored)

### 1.1 `Medium` — closed vocabulary

```go
// platform/backend/pkg/medium/medium.go
type Medium string

const (
    // Question mediums: exactly assessment.Kind (pkg/assessment/question.go:51-53).
    MediumMCQ       Medium = "mcq"
    MediumShort     Medium = "short"
    MediumFlashcard Medium = "flashcard"
    // Format mediums: US4 engagement path ONLY. Never produced by the outcome path.
    MediumLessonText Medium = "lesson_text"
    MediumRecording  Medium = "recording"
    MediumTranscript Medium = "transcript"
    MediumVisual     Medium = "visual"   // curriculum-kit illustration|diagram|scheme|graph
    MediumDocument   Medium = "document"
)
func (m Medium) IsQuestion() bool { ... }   // the three question kinds
func (m Medium) Valid() bool { ... }        // closed-set check; the ONLY validity test
func FromKind(k assessment.Kind) (Medium, bool)
```

A parity test asserts `FromKind` covers every member of `assessment` kinds, so a future new question kind fails
the build instead of silently falling out of the profile (§11.4.241: illegal state unrepresentable by test).

### 1.2 `Observation` — one response through the medium lens

| Field | Type | Source | Rule |
|---|---|---|---|
| `Entry` | string | 013 `ResponseLogEntry.ID()` | evidence reference, shown to the learner |
| `Session` | string | 013 `Session()` | MUST equal the caller; asserted in the reader |
| `Area` | string | 013 `Area()` | may be a retired area (reported, not dropped) |
| `Medium` | Medium | question-kind lookup by `Question()` | unknown question id → observation dropped AND counted in `unmapped` |
| `Graded` | bool | 013 outcome provenance (`machine` / `self_reported` / `ungraded`) | only `machine` is performance evidence (FR-004) |
| `Correct` | bool | 013 `Correct()` | meaningful only if `Graded` |
| `Expected` | float64 | `ExpectedScore(AbilityBefore(), ServedDifficulty(), D)` | recomputed from the **stored** inputs (FR-003) |
| `Residual` | float64 | `Correct − Expected` | only if `Graded` |
| `At` | time.Time | 013 `At()` | used for the optional recency window |

`D` is spec 013's logistic divisor (1.5 by default, `specs/013-adaptive-assessment-scoring/data-model.md` §3). It
is imported from `pkg/scoring`'s config, not copied, so the two features cannot disagree.

### 1.3 `MediumEvidence` — per (medium, scope)

```go
type Scope struct { Kind ScopeKind /* overall|area */; Area string }
type MediumEvidence struct {
    Medium      Medium
    Scope       Scope
    NTotal      int     // all observations of this medium (activity)
    NGraded     int     // machine-graded only
    Observed    int     // graded and correct
    Expected    float64 // sum of p
    Variance    float64 // sum of p(1-p)
    MeanResid   float64 // (Observed-Expected)/NGraded; 0 when NGraded==0
    StdError    float64 // sqrt(Variance)/NGraded; 0 when NGraded==0
    Refs        []string // evidence entry ids, sorted ascending (determinism)
}
```

### 1.4 `MediumSignal` and `Recommendation`

```go
type SignalState string // insufficient_evidence | no_clear_preference | leaning | preferred | not_measurable | off_by_learner
type ReasonCode  string // preferred_by_evidence | leaning_by_evidence | learner_pinned | no_signal_yet | learner_off | scope_fallback_overall
type Recommendation struct {
    Area        string  // "" for overall
    Medium      *Medium // nil = no recommendation
    State       SignalState
    Reason      ReasonCode
    Scope       ScopeKind // the scope the evidence actually came from
    Overridden  bool
    Explanation Explanation
}
```

`SignalState`, `ReasonCode` and the endpoint `unavailable` codes are three **disjoint** closed sets (FR-018).

## 2. Persisted (small, per learner)

Opened from the server data directory like `pkg/authstore` (`Open(dir)`), a **separate** file `medium.db`, so a
corpus re-ingest never touches it (same reasoning as 013 plan, "Storage placement decision").

```sql
CREATE TABLE IF NOT EXISTS medium_preference (
  session  TEXT PRIMARY KEY,
  mode     TEXT NOT NULL CHECK (mode IN ('auto','pinned','off')),
  medium   TEXT,                       -- required iff mode='pinned'
  set_at   TEXT NOT NULL,
  CHECK ((mode = 'pinned') = (medium IS NOT NULL))
);

-- US4 only. Created by the same migration but never written unless consent exists.
CREATE TABLE IF NOT EXISTS medium_consent (
  session          TEXT PRIMARY KEY,
  engagement       INTEGER NOT NULL CHECK (engagement IN (0,1)),
  set_at           TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS medium_event (
  id               INTEGER PRIMARY KEY AUTOINCREMENT,
  session          TEXT NOT NULL,
  medium           TEXT NOT NULL,        -- format mediums only (CHECK below)
  area             TEXT NOT NULL,
  duration_bucket  TEXT NOT NULL CHECK (duration_bucket IN ('lt1m','1to5m','5to15m','gt15m')),
  at               TEXT NOT NULL,
  idem_key         TEXT NOT NULL,        -- client-supplied; UNIQUE => retry-safe (constitution §11.4.253)
  UNIQUE (session, idem_key),
  CHECK (medium IN ('lesson_text','recording','transcript','visual','document'))
);
CREATE INDEX IF NOT EXISTS medium_event_session ON medium_event(session, at);
```

Notes: no passage text, no URL, no free text, no per-second timing (coarse bucket only). `medium_event` has no
foreign key to any content table — an event survives re-ingest and says nothing a reader could use to
reconstruct what was read.

## 3. Worked example (the hand oracle)

`D = 1.5`, `ExpectedScore(θ,d) = 1 / (1 + 10^(−(θ−d)/1.5))`. Use `n_min = 3` and the ILLUSTRATIVE thresholds below for the arithmetic; the shipped defaults are n_min 8, z_leaning 2.5, z_preferred 3.0 (research.md 3.1), under which this 4-answer example is `insufficient_evidence` for both formats (fixture `golden_shipped`), and even at n_min 3 the z of 1.535 is below the shipped 2.5.

| # | medium | θ (ability_before) | d (served) | correct | expected p | residual |
|---|---|---|---|---|---|---|
| 1 | mcq | 5.0 | 5.0 | 1 | 0.5000 | +0.5000 |
| 2 | mcq | 5.4 | 7.5 | 0 | 0.0383 | −0.0383 |
| 3 | mcq | 5.2 | 5.0 | 1 | 0.5762 | +0.4238 |
| 4 | mcq | 5.6 | 7.5 | 1 | 0.0513 | +0.9487 |
| 5 | flashcard | 5.0 | 5.0 | 1 | 0.5000 | +0.5000 |
| 6 | flashcard | 5.4 | 5.0 | 1 | 0.6489 | +0.3511 |
| 7 | flashcard | 5.8 | 7.5 | 0 | 0.0685 | −0.0685 |
| 8 | flashcard | 5.6 | 5.0 | 0 | 0.7153 | −0.7153 |

Per medium (`n` graded, `s` observed correct, `E = Σp`, `V = Σp(1−p)`):

- mcq: `n=4`, `s=3`, `E=1.1658`, `V=0.5797`, mean residual `m=(3−1.1658)/4 = 0.4586`, `se=√0.5797/4 = 0.1903`.
- flashcard: `n=4`, `s=2`, `E=1.9326`, `V=0.7453`, `m=(2−1.9326)/4 = 0.0168`, `se=√0.7453/4 = 0.2158`.

Comparison (best vs runner-up): gap `g = 0.45855 − 0.01684 = 0.4417` (unrounded means); `se_g = √(0.1903² + 0.2158²) = 0.2877`;
`z = g / se_g = 1.535`. With the illustrative thresholds (`gap_min=0.10`, `z_leaning=0.67`, `z_preferred=1.28`):
`g ≥ 0.10` and `z ≥ 1.28` ⇒ **mcq = `preferred`**, flashcard = `no_clear_preference` (not the winner, not
insufficient). Test oracle: this table is a golden fixture; the independent Python reference
(`pipeline/medium_reference.py`, authored by a different agent than the Go implementation) must reproduce
`E`, `V`, `m`, `se`, `z` to 1e-9, and a human can reproduce the 4-decimal figures with a calculator.

Counter-example for FR-006: the same data with `n_min = 5` ⇒ both mediums `insufficient_evidence` ⇒ **no
recommendation**, reason `no_signal_yet`.

## 4. Validation rules

- A `pinned` preference with a format medium is allowed only for mediums the UI can act on (question mediums);
  format mediums are display-only (rejected `400 unsupported_pin_medium`).
- `Refs` are sorted ascending and de-duplicated; `NTotal ≥ NGraded ≥ Observed` always (property test).
- `Variance ≥ 0`; if `NGraded == 0` then `MeanResid == StdError == 0` **and** the state is `not_measurable` or
  `insufficient_evidence`, never a number presented as an estimate.
- `Expected ∈ (0,1)` per observation; a non-finite value in the log (corrupt row) drops the observation and
  counts it in `unmapped` rather than poisoning the aggregate.
