# Phase 0 Research: Learning-Medium Profile and Best-Method Recommendation

Status key: **MEASURED** = checked against code this session (2026-10-20); **UNCONFIRMED** = not verified, a
task closes it; **HYPOTHESIS** = design reasoning to be tested by a named task.

## 0. Baseline — what exists (MEASURED unless marked)

| Fact | Evidence |
|---|---|
| Closed question-kind set `mcq`/`short`/`flashcard` | `workshop/platform/backend/pkg/assessment/question.go:46-57` |
| Closed lesson-material kinds incl. `video`, `diagram`, `scheme`, `graph`, `illustration`, `document` | `workshop/submodules/curriculum-kit/pkg/curriculum/model.go:25-50` |
| `short` is never machine-marked | `workshop/submodules/curriculum-kit/pkg/curriculum/assess.go:213-220` |
| Reading position store keeps only the latest position per chapter | `workshop/platform/backend/internal/api/progress.go:33-38,80` |
| `ckit.Progress` = lesson state (no timestamps) + timestamped graded `Attempt`s | `workshop/submodules/curriculum-kit/pkg/curriculum/progress.go:33-68` |
| `assessment.Progress` type exists but is unwired | `workshop/platform/backend/pkg/assessment/progress.go:43-56` (gap analysis, spec-011-015 audit) |
| No learning-style/medium mechanism in platform code | Jordan research §4.1 plus gap analysis §1; re-run `grep -ri "learning.style\|learning.medium" platform/backend` in task T002 |
| `Pipeline`/answering is a separate subsystem; this feature does not touch it | `workshop/platform/backend/pkg/answer/pipeline.go:178` |
| Spec 013 has 0/52 tasks done; its `ResponseLogEntry` is the only adequate evidence source | `specs/013-adaptive-assessment-scoring/data-model.md` §1.1; architecture plan §0 |
| Routes today: no `/profile`; `app.routes.ts` is orchestrator-owned | `workshop/platform/frontend/src/app/app.routes.ts` (184 lines) |
| Frontend features live under `src/app/features/<x>/` | `ls workshop/platform/frontend/src/app/features` |
| Roles `admin`/`user` exist in the auth store | `workshop/platform/backend/pkg/authstore/authstore.go:47` |
| Practice deck position is a sessionStorage convenience, not a record | `workshop/platform/frontend/src/app/core/practice-store.ts:1-40` |

**Consequence (MEASURED)**: with today's data no per-medium comparison is possible. The honest sequencing is
algorithm first (pure, buildable now against fixtures), integration after 013.

## 1. Why "what works for you, with evidence" and not "your learning style"

HYPOTHESIS to be settled by task T003 (constitution §11.4.150 requires deep research before implementation):
the proposition that matching instruction to a self-reported or inferred "learning style" improves outcomes is
widely reported as lacking support in controlled studies, while *measured performance per format against an
expectation* needs no such proposition — it is a descriptive statistic of the learner's own history. The
feature is therefore designed to survive the research either way: if style-matching is unsupported, the feature
claims nothing about styles; if it is supported, the feature still only reports measured performance. The task
must cite primary sources (title, venue, year) in this file; until then every sentence in this section is
HYPOTHESIS, not finding.

Related design consequence: no personality-like label (FR-017). A label travels beyond the page; a count does not.

## 2. Algorithm alternatives (HYPOTHESIS ranking, decided by SC-009 evidence)

| Option | For | Against | Decision |
|---|---|---|---|
| **Difficulty-adjusted mean residual + z-comparison** (chosen) | closed form; hand-checkable; uses values 013 already stored; no tuning parameters beyond four thresholds; explainable in one sentence | normal approximation is rough at small n (mitigated by `n_min`); treats attempts as independent | **chosen** |
| Raw accuracy per medium | trivial | confounded by difficulty: a learner who mostly meets easy flashcards looks better at flashcards; REJECTED on correctness grounds | rejected |
| Beta-Binomial posterior per medium | well-known small-n behaviour | ignores item difficulty unless extended; harder to hand-verify; priors are a hidden parameter | reconsider only if SC-009 fails |
| Multi-armed bandit / Thompson sampling | optimal exploration | needs server-side routing (US5 blocked); injects randomness (violates FR-008) | rejected for now |
| Logistic regression with medium covariate | principled | needs fitting library, opaque to learner, unstable at tens of rows | rejected |
| LLM judgement of "learning style" | none | non-deterministic, unexplainable, privacy-hostile (would ship the learner's history to a model) | rejected by FR-008 |

## 3. Threshold validation design (feeds SC-009)

A seeded simulator (`platform/backend/pkg/medium/sim_test.go` using `math/rand` **in test code only**, seed fixed)
generates learners whose true probability of success in each medium is `p_true = ExpectedScore(θ,d) + δ_m`
(clamped), with `δ` = 0 for all mediums (null) or +0.20 for one medium (effect). 1000 learners per condition at
10/20/30/60 graded answers per medium. Reported: fraction classified `no_clear_preference|insufficient_evidence`
under null (target ≥ 95%), fraction `leaning|preferred` under effect at 30 per medium (target ≥ 80%), and the
confusion matrix. Because three thresholds interact, the simulator also reports the curve over `z_preferred ∈
{1.0,1.28,1.64,1.96}`. **Risk recorded**: with a one-sided z of 1.28 and one comparison per scope per medium
pair the family-wise false-positive rate across areas is higher than 10%; the area-level view mitigates by
requiring `n_min` per area, and the simulator measures the multi-area case rather than assuming it away.

### 3.1 MEASURED result (T026/T027, stream S16, re-run 2026-10-21 after independent review) - thresholds RETUNED, OD-1 raised

**Delegate default, operator may amend (OD-1).** Evidence: `evidence/s16/simulation/sim-results.json` on branch `s16-021-medium`
(sha256 `c5d2ba3b17b1c2df0141ee47900fec855441687d69b909bcf17c1229bae80c75`), produced by `pkg/medium/sim_test.go` (PCG seed 2026/1020,
1000 learners per condition; `MEDIUM_SIM_OUT=<file> go test -run TestSimulationSC009 ./pkg/medium`). Model: ability U(3,7); difficulty matched
to ability, d = theta + {-1,0,+1} (013 serves adaptively; an earlier draft with unmatched difficulty saturated p and capped power - a simulator
artefact, corrected); effect = +0.20 on flashcards; sequential runs revisit after every 5 new graded answers per format (as a returning learner
does, since the profile is recomputed on every visit).

Round 1 (superseded) shipped z 1.96/2.58 and judged only a SINGLE look. The review showed that was a knife edge (null non-preference 0.945-0.959
across n; 4 of 6 cells below the 0.95 bound) and that repeated visits inflate the false-lead rate: a null learner EVER sees a lead with probability
0.182 by 60 and 0.246 by 120 per format at those settings (measured again here, grid row 1).

**Shipped defaults now: z_leaning 2.5, z_preferred 3.0, gap_min 0.10, n_min 8, confirm_looks 3.** A lead is shown as a suggestion only after the
SAME leading format has been the verdict on 3 consecutive evaluations that each had NEW graded answers (a refresh without new answers does not
count); a held-back lead stays visible as numbers but is reported `no_clear_preference` with a "seen N of 3" note. The memory is a medium name,
a counter and an evidence fingerprint per learner and scope. `leaning` is display-only: it never produces a hint on an area page.

| measure (shipped defaults) | n=10 | 20 | 30 | 60 | 90 | 120 |
|---|---:|---:|---:|---:|---:|---:|
| null, one look: NOT told a lead (bound >= 0.95 at EVERY n) | 0.990 | 0.990 | 0.992 | 0.989 | 0.987 | 0.992 |
| +0.20 effect, one look: lead present (raw power) | 0.049 | 0.120 | 0.191 | 0.467 | 0.669 | 0.820 |

| sequential (returning learner, persistence on) | by 30/format | by 60 | by 120 |
|---|---:|---:|---:|
| null learner EVER shown a lead | 0.002 | 0.015 | 0.031 |
| null learner ever has a raw lead (before persistence) | 0.034 | 0.058 | 0.076 |
| effect learner shown a lead (power with persistence) | 0.104 | 0.374 | 0.803 |
| shown a lead for the WRONG format under a true effect | - | - | 0.000 |

Other settings, sequential, null ever-shown at 60 / 120 and effect shown at 60 / 120: z 1.96/2.58 K=1: 0.182 / 0.246 and 0.784 / 0.966;
z 2.5/3.0 K=1: 0.040 / 0.061 and 0.574 / 0.875; z 2.5/3.0 K=3 (shipped): 0.013 / 0.022 and 0.401 / 0.810 (grid seed differs slightly from the
table above). Family-wise, four areas each with one look: 0.054 / 0.054 / 0.051 false lead for at least one area at n = 10 / 30 / 60 per format.

Honest power statement (not hidden; the 30-per-format bound is the ORIGINAL SC-009 wording, withdrawn by the OD-1 decision below): with these thresholds the original SC-009 power bound (80% at 30 graded answers per format) is **MISSED** - power at 30
is 0.19 single look. About 120 graded answers per format are needed for 80% (single look 0.82; with persistence 0.80). The two SC-009 bounds cannot
both hold at 30 answers for a +0.20 effect (best-of-two competition makes the false-lead rate two-sided; the expected z at 30 is ~1.55). Protecting a
learner from a wrongly asserted preference (research 1(c), self-fulfilling narrowing) was chosen over speed of a suggestion. Below ~100 answers per
format the honest output is mostly "no clear difference". Residual risks: construct validity (residuals can reflect item calibration - a format
whose items are systematically easier than their stated difficulty looks better for everyone; see the calibration check, research 7 and the
operator guide) and a third graded format would raise the best-of-k false-lead rate.

**Assumptions of the figures above.** Persistence figures assume a look every 5 new graded answers per format. A denser cadence (reviewer's worst case, null learner ever shown a lead) gives 0.025 / 0.043 / 0.064 by 30 / 60 / 120 per format, power by 120 0.867. Documented rather than mitigated: the profile is recomputed on every visit by design. Four areas with persistence: null learner sees a confirmed lead in at least one area 0.051 by 60 and 0.142 by 120. About 7.7% of null learners see "a lead is showing, not confirmed yet" by 120.

**OD-1 DECIDED 2026-10-21 (operator): option (a), power >= 80% at 120 graded answers per format.** SC-009 in spec.md is reworded to that bound (single look measured 0.82; with persistence measured 0.803, a margin of 0.003; four-area no-preference false-positive risk 0.142 by 120 stays documented). `TestSimulationSC009` asserts it for both the single look and the persistence rule. Options (b) and (c) below are kept as the considered alternatives, not adopted.

**OD-1 options as they stood before the decision.** SC-009 as originally written (null >= 95% AND power >= 80% at 30 graded answers per format for a +0.20 effect) cannot hold; at the shipped defaults power at 30 is 0.19. Candidate rewordings:
- (a) Power >= 80% at 120 graded answers per format. Measured: single look 0.82; with persistence 0.80 (sequential, shipped defaults). Keeps the effect size, moves the sample size.
- (b) Null ever-shown <= 5% by 120 plus power monotone in n. Measured: null ever-shown 0.031 by 120 (dense-look worst case 0.064 would miss 5%); power 0.19 / 0.47 / 0.82 at 30 / 60 / 120, monotone. States the protection actually bought and asserts no power level.
- (c) A larger effect size at 30 per format. Not re-measured at other effect sizes in this round: UNCONFIRMED what effect gives 80% at 30; from the measured z, an effect of roughly 0.35-0.40 would be needed (extrapolation, not simulated).

## 4. Privacy-by-design analysis

| Principle | How it is met | Residual risk (stated) |
|---|---|---|
| Data minimisation | performance signal derived at read time from data 013 already holds; only preference/consent/events persisted | the 013 log itself is the retention surface (OD-4) |
| Purpose limitation | endpoints return the caller's own aggregates only; no cohort, no admin view | a future instructor view needs its own spec and consent model (OD-5) |
| Transparency | explanation payload with evidence refs; hand-reproducible | text template is fixed; no model wording |
| User control | `auto`/`pinned`/`off`; reset; consent default OFF for engagement | anonymous `X-Session` learners lose settings with the session |
| No profiling labels | FR-017 | UI copy review is a task (T050) |
| Security | session-scoped SQL; 403/400 fail-closed; closed event shape; size bounds | identity model inherited from 015 (anonymous session is bearer-like) |
| Legal regime | **UNCONFIRMED** for the Jordan-based client (the research doc records the national data-protection statute as a consent-oriented regime for cross-border transfer, without confirming applicability to this feature) | OD-4: legal review before client use |

## 5. Input availability matrix (what each medium can honestly be measured from)

| Medium | Performance evidence | Activity evidence | Notes |
|---|---|---|---|
| `mcq` | yes (machine-graded) | yes | primary signal |
| `flashcard` | UNCONFIRMED (machine-graded vs self-rated; T004) | yes | if self-rated: activity only by default |
| `short` | no (never machine-marked) | yes | `not_measurable` by design |
| `lesson_text` / `recording` / `transcript` / `visual` / `document` | no (time spent is not learning) | only with US4 opt-in | shown as activity, never as performance |

## 6. Integration plan and hot-spot avoidance

Per `architecture.md` §2.2 (single-writer rule): all backend registration through `wire_medium.go`; frontend
through `features/medium/medium.routes.ts` (lazy child) plus one orchestrator-owned append line in
`app.routes.ts`; UI strings in `features/medium/medium.vocabulary.ts` plus one orchestrator-owned registration
line in `core/vocabulary.ts` (that file has a paired-mutation gate, `prove-ui-vocabulary-mutation.sh`). Area-page
hint and practice selector require minimal edits to existing components (`features/areas`, `features/practice`);
these are declared in tasks as `[HOOK]` with the exact lines, kept to ≤ 10 lines each, and flagged to the
orchestrator because 013-US1 and 016-US1 also touch the practice path (architecture §2.2 item 5 semantic-conflict
pair).

## 7. Open research questions

- **R-1** (T003) Evidence for/against style-matching and for performance-adjusted feedback; cite sources.
- **R-2** (T004) Flashcard grading semantics in 013's submit path.
- **R-3** (T005) Whether 013's read path can serve `(session, at)` newest-first reads without a new index.
- **R-4** (T006) Practice-page kind filtering: does the questions endpoint already return `kind` per question
  (the `Question` JSON has `kind`, `question.go:115`)? confirm on the served bundle, not source (§ "Source Is Not Served").

## 8. UNCONFIRMED register

013 implementation shape (not built); flashcard grading; the served frontend bundle's practice behaviour (the
bundle is stale relative to source per the gap analysis); legal regime; who the client is.
