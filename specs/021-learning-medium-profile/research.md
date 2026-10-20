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

### 3.1 MEASURED result (T026/T027, 2026-10-20, stream S16) - thresholds RETUNED, OD-1 raised

Evidence: `evidence/s16/simulation/sim-results.json` in the workshop worktree branch `s16-021-medium`
(sha256 `0fd9bb5bde5de2592bb35574954a4cf84a9de1cb065850fa695099f2a2f8f632`), produced by
`pkg/medium/sim_test.go` (PCG seed 2026/1020, 1000 learners per cell, `MEDIUM_SIM_OUT=<file> go test -run TestSimulationSC009`).
Model: ability U(3,7); difficulty matched to ability, d = theta + {-1,0,+1} (spec 013 serves adaptively; an
earlier draft with unmatched difficulty saturated p near 0/1 and capped the simulated power - a simulator
artefact, recorded and corrected); effect = +0.20 on flashcards.

| config | null: leaning/preferred @30 | power @30 | power @60 | power @90 | power @120 |
|---|---:|---:|---:|---:|---:|
| PROPOSED z 0.67 / 1.28, gap 0.10 | **35.7%** (non-preference 64.3%: SC-009 null bound MISSED) | 80.2% | 86.2% | 92.3% | - |
| z 1.28 / 1.64 | 19.6% | 65.3% | 86.1% | - | - |
| z 1.64 / 1.96 | 9.5% | 51.2% | 77.1% | - | - |
| **SHIPPED z 1.96 / 2.58, gap 0.10** | **4.9%** (non-preference 95.1%: bound met) | **37.7%** | 65.9% | 84.9% | 92.7% |

Finding (not hidden): **the two SC-009 bounds cannot both hold at 30 graded answers per format for a +0.20
effect.** With two competing formats the best-of-two selection makes the false-positive rate two-sided, so a
5% null rate needs z >= 1.96; a +0.20 effect at 30 answers has an expected z of only ~1.55, which gives ~38%
power. 80% power at a 5% null rate needs roughly 85 graded answers per format (measured: 84.9% at 90).
The operator-delegate default was to protect the learner from a wrongly asserted preference (research 1(c),
self-fulfilling narrowing), so the shipped defaults meet the null bound and MISS the power bound at 30; below
~85 answers per format the honest output is mostly `no_clear_preference`/`insufficient_evidence`.
Recorded risks: (a) family-wise false preference across 4 areas at the shipped defaults is ~20% (measured
0.189/0.216/0.195 at n = 10/30/60), because each area is a separate comparison; (b) a third graded format would
raise the best-of-k false-positive rate further; (c) the n=30 null figure (0.951) clears the 0.95 bound by a
thin margin on this fixed seed. **OD-1 (accept or retune) is open with these numbers.**

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
