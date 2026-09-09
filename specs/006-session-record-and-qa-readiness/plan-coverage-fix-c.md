# Plan-coverage proposal rule — the veto guard and Fix C

**Feature:** 006-session-record-and-qa-readiness · FR-007, FR-007a
**Date:** 2026-09-09
**Status:** BOTH CHANGES APPLIED on operator decision. Not committed by the
authoring session.
**Subject:** `pipeline/extract/propose_plan_coverage.py`,
`platform/gates/verify-plan-coverage-proposal.sh`,
`platform/gates/prove-plan-coverage-proposal.sh` (private `workshop` submodule)

**CONTENT BOUNDARY — BINDING.** This file lives in a PUBLIC repository and its
subject is inside the PRIVATE `workshop` submodule. Every planned point,
passage and extracted row below is named **by identifier or path only**. No
point text, no transcript text, no curriculum prose, no area title and no
person's name appears here, and none may be added. Matched vocabulary is
reported as counts, never as words — a bag of discriminative terms is a
paraphrase of the sentence it came from.

---

## 1. Why the rule was investigated at all

Three proposal rows that a human had **independently recorded `covered`**, each
with an evidence locator, came back from the rule as `cannot_determine`
(medium confidence):

| plan_id | chapter |
|---|---|
| `01M1H9DJ052XDSQQJVZNSN8KCB` | 02 |
| `01M1H9DJ052XDSQQJVZNSN8KCC` | 02 |
| `01M1SD6HJ78ZTKAXSW0185YKH8` | 02.01 |

The operator was offered "rewrite them", "correct them to covered" and
"withdraw them", and **chose none of those**: *investigate the rule that
produced them first*. What follows is that investigation and the two changes it
led to. **No row was repaired by hand at any point.**

## 2. What the rule does

Two lanes per planned point, each scored as IDF-weighted recall of the point's
discriminative terms and each compared against a **matched null** of 300
synthetic points built from same-rarity terms drawn from the origin chapter's
vocabulary:

- **transcript lane** — a sliding 5-segment window over the chapter's own
  transcript;
- **own-row lane** — the best match against a **single** extracted row
  (meeting note / TODO / open question) whose `origin_chapter` is this chapter.

An absence guard already existed for the negative branch: a lane may support
`not_covered` only when `q_upper95 <= alpha`, where `q` is the probability that
a same-rarity *unrelated* point leaves **no** trace in this chapter. That guard
had replaced a `transcript_segments >= 500` constant under decision #14 of
2026-09-08, precisely because the constant made `not_covered` structurally
unreachable for a short chapter.

## 3. Root cause — TWO causes, not one

**The three rows do not share a cause, and forcing one story would have been
wrong.** All three were `ONE_LANE_ONLY`: the transcript lane beat its null, the
own-row lane did not.

**Cause 1 — `01M1SD6HJ78ZTKAXSW0185YKH8` (chapter 02.01).** The own-row lane is
*measurably blind* here (`q_upper95 = 0.8618`). The absence guard already
computed that number, already printed it, and already refused to let this lane
create a negative — and then let the same lane **veto a positive** with no
guard at all. **Decision #14's guard had been applied to one branch only.**

**Cause 2 — `…KCB` and `…KCC` (chapter 02).** Blindness does **not** explain
these. Their own-row lane is measurably sighted (`q_upper95 = 0.0099`) and it
genuinely dissented (`p` = 0.1367 and 0.1867, no ties, 299 distinct null
values). The rule's local reasoning was valid. The defect is one level up: a
lane with **no measurable relationship to the outcome** was a mandatory
conjunct.

**The measurement that carried both decisions.** Against the 7 points a human
has recorded `covered` on this tree:

| lane | fires | captures human-recorded `covered` | expected by chance | one-sided hypergeometric |
|---|---|---|---|---|
| transcript | 7/49 | **4/7** | 1.00 | **p = 0.0049** |
| own-row | 5/49 | **1/7** | 0.71 | **p = 0.55** |

**Supporting structural measurements.** The median own row carries 5 content
tokens after stoplisting (chapter 02) against a point of 6–8 discriminative
terms; chapter 02.01's entire own-row evidence base is **3 rows for 30 planned
points**, so 27 of those 30 have zero overlap with any own row and score
exactly 0.0 with `p = 1.0` by arithmetic. This is the single-unit design the
transcript lane's 5-segment window exists to avoid — *"a single segment cannot
hold a whole point and a per-segment match would be unfair by construction"* —
and that argument was never applied to the own-row lane. **Widening it does not
help and was tried:** a union over *all* own rows fires on 1/49 instead of
5/49.

**Excluded by measurement, not by assumption.** Threshold and seed instability
are not the cause: across four seeds only 2–3 of 49 rows change any lane's
significance and the `covered` count stayed 1 every time. A mid-p correction
for ties changes nothing.

**Withdrawn during the investigation.** An intermediate finding that `covered`
was "physically unreachable for 44 of 49 rows" **is withdrawn** — it restated
the observed lane failure rather than proving unreachability. Checked properly,
a single own row carrying 1–2 of the point's rarest terms would suffice
everywhere (`k_needed` = 1 or 2 against a max own-row length of 10–30). There
is no unreachability theorem; there is an extreme power deficit.

## 4. The two changes

### 4.1 The veto guard (applied first)

A lane whose `q_upper95 > alpha` is **disqualified as a witness** on both
branches: it may neither create a negative nor veto a positive. Same alpha,
same already-computed number, **no new parameter and no new draw from the RNG**.

**Blast radius, predicted before and confirmed after: exactly 1 row of 49.**
`01M1SD6HJ78ZTKAXSW0185YKH8`, `cannot_determine` → `covered`; `covered` 1 → 2.
It fixed cause 1 and, correctly, did **not** fix cause 2.

### 4.2 Fix C (applied second, separate operator decision)

`covered` now requires the **transcript lane and nothing else**. The own-row
lane is reported on every row and decides nothing — it may neither create a
verdict nor veto one. This mirrors what the rule has always done for
`not_covered`: *a coverage claim is a claim about the SESSION, and the
transcript is the session.*

Three positive codes, differing **only** in what the demoted lane did, so that
demoting it hides nothing:

| code | meaning | rows |
|---|---|---|
| `TWO_LANES_BEAT_MATCHED_NULL` | both lanes agreed | 1 |
| `ONE_LANE_BEAT_MATCHED_NULL_THE_OTHER_IS_MEASURABLY_BLIND` | the own-row lane could not see | 1 |
| `TRANSCRIPT_LANE_DECISIVE_OWN_ROW_LANE_SIGHTED_AND_DISSENTING` | the own-row lane **could** see, **dissented**, and **was overridden** | 5 |

`ONE_LANE_ONLY` is **renamed** to
`OWN_ROW_LANE_ONLY_THE_DECISIVE_LANE_DID_NOT_AGREE` (4 rows) — the old name
asserted a symmetry between the lanes that no longer exists.

**Removed by Fix C:** the veto guard's *symmetric* arm — a significant own-row
lane while the transcript lane was blind. Under Fix C the own-row lane never
creates a verdict. That arm **never fired** on this tree, so the removal is
measurable at zero rows; it is recorded here rather than left to be discovered.

## 5. Blast radius of Fix C — predicted 6 rows, observed 6 rows

`covered` 1 → 7 against the original artefact (2 → 7 against the veto-guard
artefact). **No recorded human decision is contradicted, and none could be:
all 7 recorded dispositions are `covered`; no human has recorded a negative
anywhere in this tree.**

| chapter | plan_id | → code | human decision? |
|---|---|---|---|
| 02 | `01M1H9DJ052XDSQQJVZNSN8KCB` | sighted-dissent overridden | **`covered`, with evidence locator** — refuted row 1 |
| 02 | `01M1H9DJ052XDSQQJVZNSN8KCC` | sighted-dissent overridden | **`covered`, with evidence locator** — refuted row 2 |
| 02.01 | `01M1SD6HJ78ZTKAXSW0185YKH8` | overridden blind lane | **`covered`, with evidence locator** — refuted row 3 |
| 02 | `01M1H9DJ052XDSQQJVZNSN8KC6` | sighted-dissent overridden | **none** — surfaced for reading |
| 02 | `01M1H9DJ052XDSQQJVZNSN8KC8` | sighted-dissent overridden | **none** — surfaced for reading |
| 02 | `01M1H9DJ052XDSQQJVZNSN8KCT` | sighted-dissent overridden | **none** — surfaced for reading |

## 6. HONEST BOUNDARY — what Fix C costs and what it does not establish

These four points are carried in the generator's own docstring and in the
gate's header, not only here.

1. **It discards a measured dissent by design.** On `…KC6` and `…KC8` the
   own-row lane is measurably able to see and dissented strongly
   (`p` = 0.8433 and 0.5733). Those are disagreements, not silences, and this
   rule overrides them. The third positive code exists so every such row says
   so about itself; `evidence.own_row_lane.p_value` is the size of what was
   discarded. **The pre-Fix-C behaviour is recoverable exactly by ignoring
   every row carrying that code.**
2. **Specificity is UNMEASURED and the evidence is one-sided.** `p = 0.0049`
   and `p = 0.55` are agreement on **positives only**. **No human has recorded
   a `not_covered` or a `dropped` anywhere in this tree**, so there is no
   negative ground truth and nothing establishes either lane's specificity. A
   lane that fired on every row would score as well. The ground truth is 7
   rows. Read the change as *"the own-row lane adds nothing measurable to the
   positives"*, never as *"the transcript lane is right"*.
3. **Three of the six moved rows are flagged `near_decision_threshold`** —
   `…KC6`, `…KCB`, `…KCT`. At least one of their lanes has a p-value inside
   0.02..0.12, so a different Monte-Carlo seed could move them back. A verdict
   that moves with a seed is not a verdict.
4. **The three undecided rows are NOT measured false positives.** They are rows
   no human has read, which this change now puts in front of one. Nothing here
   says they are covered.

**And the standing limit both changes inherit:** a planned point is the output
of a cue-phrase heuristic over ASR text and is *what was said* about the next
session, never a ratified agenda. Every verdict inherits that and cannot be
stronger than it. A proposal remains a **draft for a human**; it is not the
decision record, and the served figure still moves only when a human decides.

## 7. Evidence

- `verify-plan-coverage-proposal.sh` — **rc 0, zero findings** (P1–P11).
- `prove-plan-coverage-proposal.sh` — **71 passed / 0 failed / 61 mutations /
  10 controls**, rc 0.
- **RNG invariant.** The null draws are one shared sequential stream, so an
  added or removed draw would shift every downstream row. Measured after both
  changes: **0 of 49 rows show any change to `evidence`** — every p-value, null
  p95, `zero_trace_trials` and `q_upper95` byte-identical to the original
  artefact. Both changes touch the DECISION only.

**P11**, the new assertion, is the mirror of P7 and enforces two things: the
**decisive lane must have carried the positive** (the demoted lane may not
decide), and the **code must match what the own-row lane actually did**, so a
row that overrode a real sighted dissent can never be filed as corroboration or
as blindness. P11 checks that a positive is well-formed and honestly labelled.
**It does not check, and cannot check, that a positive is true.**

Controls, one per admissible positive shape (`C11`, `C11a`, `C11b`), keep
`covered` from being made unreachable by tightening the gate. `M29` — a
`covered` created by the own-row lane alone — and `M35` — an overridden sighted
dissent mislabelled as an overridden blind lane — are the two arms that hold
Fix C to its stated shape.

**P11 was rewritten the day it was written.** Its first form forbade exactly
what Fix C then adopted, and its paired mutation `M29` existed to prevent that
adoption. Both were replaced rather than deleted when the operator adopted the
larger rule on measured grounds. **A proof left pointing at a withdrawn rule is
a gate green over something nobody believes.**

## 8. Population reconciliation, 66 → 49 — traced per row

Recorded here because an exact total can hide two offsetting errors, and here
it did.

**Every one of the 17 removed rows is accounted for. 0 unreconciled.** Traced
two ways: from each ledger entry's own `affected_plan_points` field, and by
**counterfactual re-derivation** (a throwaway copy of `curriculum/` with all
dispositions removed, re-run through `cmd/session-record`).

**The 6 ledger retractions remove 11 ROWS, not 6** — five origin-01 points cost
two rows each (once in chapter 02, once carried into 02.01); one origin-02
point costs one:

| retracted point | minted in | rows removed |
|---|---|---|
| `01M1H9DJ052XDSQQJVZNSN8KC4` | 01 | `02/…8KC4`, `02.01/…8KC4` |
| `01M1H9DJ052XDSQQJVZNSN8KCG` | 01 | `02/…8KCG`, `02.01/…8KCG` |
| `01M1H9DJ052XDSQQJVZNSN8KCK` | 01 | `02/…8KCK`, `02.01/…8KCK` |
| `01M1H9DJ052XDSQQJVZNSN8KCQ` | 01 | `02/…8KCQ`, `02.01/…8KCQ` |
| `01M1H9DJ052XDSQQJVZNSN8KCF` | 01 | `02/…8KCF`, `02.01/…8KCF` |
| `01M1SD6HJ78ZTKAXSW0185YKHB` | 02 | `02.01/…YKHB` |

**The other 6 rows are decision #12's human `covered` decisions** — six chapter
02 points resolved and therefore stopped carrying into 02.01. Measured, not
inferred: emptying the dispositions restores exactly these six rows and no
others — `02.01/…8KCB`, `…8KCC`, `…8KCH`, `…8KCN`, `…8KCP`, `…8KCV`. (The 7th
decision, `…YKH8` in 02.01, removes no row: that chapter has no successor.)

**So `66 − 11 − 6 = 49` is right and the attribution was inverted.** The
reconciliation as previously written credited the 11 to a separate population
of "extraction defects" and the 6 to the ledger. In fact **the ledger accounts
for the 11** and **the coverage decisions account for the 6**. There is no
separate population: decision #13's "11" and the ledger's "6" are **the same
retirement counted two ways — 11 rows, 6 distinct points**.

Two supporting measurements: the 6 retracted ids are **absent from every
chapter's `next-meeting-points.jsonl`** — the extractor fix, not the ledger, is
the mechanism, and the ledger is documentation of it — and the counterfactual
derivation with an emptied ledger returns **55**, not 60, which is what proves
that.

**A label that survives because two wrong numbers cancel is a false-green in
prose.** That is why the per-row trace was required, and it is the transferable
lesson of this section.
