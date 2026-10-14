# 05 — Consumer adoption (PROPOSED)

| Field | Value |
|---|---|
| Revision | 1 |
| Created | 2026-10-14 |
| Status | proposal |

## 1. Checklist for every consuming project

Each item is closed only with captured evidence (§11.4.262); "done" without an
artefact is not done.

**ANCHOR-A — wrapper**
- [ ] Constitution pin includes the wrapper; `find_constitution.sh` resolves it from the project root and from every nested submodule (evidence: the resolved path printed from each).
- [ ] `CM-LLMCTL-WRAPPER-ONLY` run over the project and its owned submodules: rc 0, or every finding converted to a wrapper call.
- [ ] Untracked per-host config for remote host aliases created with mode 0600; `git check-ignore` proves it is ignored.

**ANCHOR-B — validation**
- [ ] DATA declared: profiles used, host roles, max age (≤ 30 days).
- [ ] `require-validated` wired into every use path: service boot (§11.4.254), test harness preflight, HelixQA preflight.
- [ ] One fresh PASS record per (profile, host role), ≥ 3 runs, committed as summary + hashes; raw evidence in the untracked store.
- [ ] A deliberately stale record (key changed) shown to refuse use (rc ≠ 0) — the negative case is evidence too.

**ANCHOR-C — bank**
- [ ] Base bank passes `CM-GOLDEN-BANK-REPRODUCIBLE` and `CM-GOLDEN-BANK-CONTROLS` on this host.
- [ ] Project bank: at least one golden + control-bad pair per surface, rendered from a pinned build, every pin recorded.
- [ ] Defect-classification record template present; first wrong answer (if any) classified, not loosened.

**ANCHOR-D — UI QA (only if an interactive UI ships)**
- [ ] IA contract (§11.4.219) exists for every surface; ledger generated from it.
- [ ] Every prose/TODO step converted to an executable, frame-bound assertion, or left visibly `UNCOVERED`.
- [ ] HelixQA pinned at a version that passes `CM-UI-VISION-VERDICT-NO-BLUFF`.
- [ ] One seeded-defect build per platform, caught on the right row.
- [ ] Release checklist blocks on any non-PASS or stale row.

**ANCHOR-E — docs**
- [ ] Project manual, FAQ and coverage graph updated; diagrams exported (§11.4.65).
- [ ] Pointer paragraph added to all four root carriers in lockstep.

## 2. Phased rollout for the reference multi-platform consumer (catalogizer)

Baseline (orchestrator measurement 2026-10-12/13, not re-measured here): 46 UI
screens — web 16, desktop 6, setup wizard 10, Android 4, Android TV 10; about
6–9 have screenshot assertions; most bank steps are TODO prose. Phases are
sliced so each one is reviewable inside the §11.4.276 round budget.

| Phase | Scope | Exit evidence |
|---|---|---|
| 0 — Precondition | HelixQA `feature/vision-no-bluff` merged and `CM-UI-VISION-VERDICT-NO-BLUFF` rc 0 at the pinned version; wrapper available; `vision` profile fresh PASS on the hosts that will run QA | gate outputs; record summaries |
| 1 — Ledger truth | Generate the ledger from the IA for all 46 screens × declared states × platforms; mark every prose step `UNCOVERED`. Expect the ledger to be mostly red — that is the honest starting point | ledger TSV; counts by verdict |
| 2 — Web (16) | Executable, frame-bound assertions for every web row; DOM as second oracle; project golden pairs for two web screens; web seeded defect caught | ledger rows PASS with frame hashes; seed run FAIL on the mutated row |
| 3 — Desktop (6) + wizard (10) | Same as phase 2; wizard flows as end-to-end journeys (every step a row) | as above |
| 4 — Android (4) + Android TV (10) | Same; TV/leanback surfaces use the §11.4.117 pixel oracle where the hierarchy is blank; protected surfaces recorded `BLOCKED` with the §11.4.112 reason | as above; per-platform seeds |
| 5 — Edge cases and states | Empty/maximum data, long and Cyrillic strings, offline/error, permission denied, rotation where applicable, both themes | rows for every declared state PASS |
| 6 — Release binding | `CM-UI-VISION-COVERAGE-LEDGER` and `CM-UI-VISION-SEEDED-DEFECT` in the pre-push hook and the release checklist | gate rc 0 on a clean checkout |

Ordering rationale: web first because it has a DOM to cross-check vision
against, which surfaces vision misreads early and cheaply; TV last because it
is the surface class §11.4.117 names as having near-empty accessibility trees,
so it is the one expected to need the pixel-oracle path and protected-surface
handling (UNCONFIRMED for this consumer until its hierarchy is dumped).

## 3. This repository (`vasic`)

The two sites (`vasic.digital`, `milosvasic.ru`) ship web UIs, so ANCHOR-D
applies to them once placed. Their existing Playwright suites are not HelixQA
suites; whether a Playwright run with a vision step decided by the validated
model satisfies "HelixQA full suites" or must be migrated is open (Q6 in
`06_open_questions.md`). No adoption work is claimed here.
