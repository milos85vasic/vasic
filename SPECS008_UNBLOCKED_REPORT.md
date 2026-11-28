# SPECS008 Unblocked-Task Report

**Sources:** `specs/008-unified-workshop-platform/spec.md`, `specs/008-unified-workshop-platform/tasks.md`, `specs/008-unified-workshop-platform/plan.md`, measured at this checkout (branch `main`). All figures are dated observations — this tree moves under them, so re-derive before acting on any count or verdict.

**Measured:** 2026-09-16 session state for `tasks.md`; `spec.md` read at its migration-gates section (§III.2).

---

## 1. Layout and evidence directories

`specs/008-unified-workshop-platform/` contains exactly three tracked files:

- `spec.md` — unified specification (Parts I–III, migration gates §III.2, User Stories 12/20/28, ECs 035–042, 33 unified user stories from 40 sources via 8 merges)
- `plan.md`
- `tasks.md` — 3835 lines; 582 tasks (T001–T582, unified numbering); 345 complete / 237 open as recounted 2026-09-15

**`ev/` and `findings/` do NOT exist under `specs/008-unified-workshop-platform/`.** `spec.md` imposes no `ev/` or `findings/` requirement on spec 008. The project's evidence convention lives under the `workshop` submodule instead: `workshop/evidence/`, `workshop/platform/backend/evidence/`, `workshop/platform/qa/evidence/` (the latter two git-ignored, 0 tracked files).

## 2. Migration gates M0–M6 (spec.md §III.2 — "Ordered gates on the migration")

The two architectures are **ordered states, not alternatives**: "the order matters because several baseline requirements are preconditions of the target rather than optional companions to it." Decoupling is additive-then-cutover, never delete-then-hope; the umbrella-hosted copy remains operative until the standalone clone independently passes install and the full test suite.

| Gate | Content (per spec.md) | Status | Blocks |
|---|---|---|---|
| **M0** | Chapter-`ordinal` type decision and path-key contradiction resolved (OQ-3): `ordinal_path` canonical, `ordinal` kept for compatibility | **SATISFIED 2026-09-15** (decision predates this merge, `specs/003-chapter-hierarchy/decision-record.md`) | Was blocking T176/T177/T184 siblings; now ordinary implementation work. **No open task is blocked on M0.** |
| **M1** | Repository obtainability meets FR-241 – FR-247 | Not explicitly marked satisfied; obtainability is "a hard precondition of Part II" — the private curriculum repo failed to clone (2,624.8 MB across 54 tracked archive parts; git smart-HTTP cannot resume) | A decoupled module whose value is "clonable by a user with no umbrella access" cannot ship while cloning fails. **No currently-open task is blocked on M1.** |
| **M2** | Manual-QA readiness against the baseline (FR-206 – FR-217) | Open | Operator's stated absolute priority; only obtainability precedes it. Adjacent publication-review tasks T278/T553/T573 (62/54/58 uncited claim blocks) wait on a human-read operator gate, not on M2 itself. |
| **M3** | Each module's dependencies resolve from its own `.gitmodules`, from public repositories | Open (extraction work complete, e.g. T551 ticked) | Extraction must complete before the umbrella copy stops being operative. **No open task blocked on M3.** |
| **M4** | Each standalone clone independently passes install and the full test suite | Open | **FR-328 decommission gate:** until M4 passes the umbrella copy remains operative; nothing may be decommissioned. |
| **M5** | Auth, RBAC, module-scoped sessions, user-bound progress live on both modules | Open (migration/census tasks T574–T582 ticked) | Part II's access model. **No open task blocked on M5.** |
| **M6** | Cutover: pre-rollout sessions invalidated, anonymous per-browser progress handled (FR-321), umbrella copies decommissioned | Open | **The only irreversible step; may not start before M4 passes. Every step is destructive and subject to FR-338:** each requires a preceding, existence-asserted hardlinked backup before it runs. No published history is rewritten. |

## 3. Gate → task blocking

**Migration-gate level:** spec.md states explicitly, "Nothing in Phases 1–15 depends on it [the migration], and migration gate M4 (FR-328) forbids decommissioning either module's umbrella-hosted copy until its standalone clone independently passes install and the full test suite." So **M0–M6 block nothing in Phases 1–15**; they constrain only Phase 16 (migration, US26–US33) and, via M4→M6 ordering, the cutover.

**Task-level blockers observed in `tasks.md` (open tasks only):**

| Task | Blocker | Owner | Migration-gate involved? |
|---|---|---|---|
| T006 | Task contradicts itself: "match reference module" but `ai_interviewing/platform/frontend` has no ESLint config either | operator (pick a lint baseline) | No |
| T038 | **UNBLOCKED 2026-09-15** — predecessors T031–T033 done, 75/75 tests passing | implementer | No |
| T098 | Operator credential: turn 6 UNVERIFIED provider rows into verdicts (`verify-provider-ci.sh` rc 1) | operator | No |
| T138 | Operator gate: confirm/overturn proposed verdicts (FR-007a→unified FR-200) | operator | No |
| T176 / T184 | `[SUPERSEDED — not owed]` | — | No (M0 was blocking; now satisfied) |
| T196 (both occurrences) | Pid-anchor half not built; chapter-01 `transcript.md` cannot correctly host per-segment anchors under current layout (structural) | — | No |
| T203 | Predecessors T200/T201 (scorer frozen + mutation-proved) first | implementer, after T200/T201 | No |
| T207 | Blocked on operator: human speaker attribution (D-TRANS-2 measured both diarization cues absent) | operator | No |
| T236 | Operator decision: prose-authorship clarification (extractive vs build-time vs run-time) | operator | No |
| T238 | Predecessor T236 | implementer, after T236 | No |
| T278 / T553 / T573 | Operator gate: read the 3 documents failing publication review on 62/54/58 uncited claim blocks and decide publish-or-not | operator / human | No |
| T289 | **No blocker stated** — "Evidence needed: 205 of 213 carry `alt: ""`; disclosed gap, not hidden" | — (subagent-authoring) | No |
| T344 | Genuine structural gap: carry-forward requires identical whole-generation `root_hash`, so adding one chapter invalidates carry-forward for the whole corpus; fix lives in `pkg/search/carryforward.go` + `pkg/crossref/carryforward.go`, outside this round | implementer, next round | No |
| T351 / T356 / T357 | Grounding layer built and wired; SC-010 (unanswerable decline) honestly UNMET; certification owed | — | No |
| T422 | Operator decision: `mmdc` renders exit 1 with no SVG; no diagram-placement decision in seven-section skeleton | operator | No |
| T447 | Operator decision, purely: choose U6 sampling period (forbids rounding to a convenient number) | operator | No |
| T449 / T450 / T451 / T452 / T454 / T456 / T457 / T458 / T459 / T460 / T463 / T464 / T465 | Predecessor chain on T447 (sampling period) and/or T453 (corroboration window) and/or T455 (hand-truthed ground-truth sample, irreducible human labour) | implementer / operator | No |
| T453 | Operator decision: U7 corroboration window | operator | No |
| T455 | Irreducible human labour over a private recording (hand-truthed ground-truth sample) | operator | No |
| T462 | **No blocker** — "none but the work" | implementer | No |
| T521 | Operator decision: move-vs-mirror for `workshop/evidence/` plus FR-040 retention rule; retention breach live right now (`evidence/p-u1/result.json` is ` M`) | operator decides; implementer executes | No |
| T527 | **Blocked on operator, two counts:** (1) T206 (unified T040) Chapter 1 redaction review part 2 incomplete — 7 of 13 REDACT decisions (F8, F9, F12, F13, F14, F15, F16) deferred and unapplied; (2) push is publication; no upstream tracking branch configured; 9 dirty umbrella paths + 39 dirty `workshop/` paths | operator | No (push = publication, not an M-gate) |
| T530 | Blocked on predecessors (essentially all tasks); final review cannot be honest while 50+ tasks open; partly drafted (`specs/001-workshop-curriculum-platform/review.md`) | human reviewer, last | No |
| T540 | Predecessors T042/T022/T084 (SC-029a inbound + final review); 2 of 3 halves green | implementer, last | No |
| **T543** | **No blocker stated** — genuinely unworked, recorded rather than guessed at | implementer | No |
| T554 | Operator/human authored-schema decision: 70% `passPercent`, mcq-2/short-3 weights, 91–95 prefix shift, anchor attachment | operator | No |

## 4. Open-task census (tasks.md phase-order table, recounted 2026-09-15)

| Phase | Subject | Tasks | Complete `[x]` | Open `[ ]` |
|---|---|---:|---:|---:|
| 1 | Setup — shared infrastructure | 23 | 20 | 3 |
| 2 | Foundational — blocking prerequisites | 52 | 39 | 13 |
| 3 | US1 + US9 — obtainability and red-state discipline | 42 | 24 | 18 |
| 4 | US2 + US4 + US5 — session record, carry-forward, manual-QA readiness | 34 | 13 | 21 |
| 5 | US6 + US7 + US8 + US16 + US21 — chapter identity and hierarchy | 37 | 17 | 20 |
| 6 | US3 + US12 — transcript and curriculum browsing | 39 | 21 | 18 |
| 7 | US10 + US11 + US17 — the knowledge layer | 62 | 46 | 16 |
| 8 | US13 + US14 + US15 — deep linking, video anchors, materials | 34 | 24 | 10 |
| 9 | US20 + US22 — search by meaning, grounded answering | 54 | 36 | 18 |
| 10 | US11 — provenanced assessment | 14 | 13 | 1 |
| 11 | US19 + US23 — learning surface, palette, accessibility | 26 | 20 | 6 |
| 12 | US25 — four-format export | 8 | 6 | 2 |
| 13 | US24 — the repeatable chapter pipeline | 20 | 9 | 11 |
| 14 | OCR ingestion — specified and unbuilt | 21 | 2 | 19 |
| 15 | US18 — evidence, independent review, governance | 11 | 7 | 4 |
| 16 | **MIGRATION** — US26–US33, decoupled modules | 43 | 20 | 23 |
| 17 | Polish and cross-cutting concerns | 62 | 28 | 34 |
| | **Total** | **582** | **345** | **237** |

After the 2026-09-16 session, Phase 17 was re-measured at **54 complete / 8 open** (the 09-16 session ticked T517, T518, T522–T529, T537, T541, T542, T544–T582). Phase 17's current 8 open tasks: **T521, T527, T530, T540, T543, T553, T554, T573** — per the phase header, "all genuinely blocked and correctly left open" except T543, which is "genuinely unworked".

## 5. Open tasks NOT blocked by unsatisfied migration gates (≥10)

**Primary answer (migration-gate cut):** every open task in Phases 1–15 is not blocked by M0–M6 — spec.md: "Nothing in Phases 1–15 depends on it." Per the 09-15 recount that is **180 open tasks** (phases 1–15 open counts sum to 180). The current file-wide open total is 211 (180 + Phase 16's 23 + Phase 17's 8), and **none of the 8 Phase-17 open tasks is blocked by a migration gate either** — their blockers are operator decisions, human reviews, or predecessor tasks (see table in §3). The ≥10 threshold is met by a wide margin under the migration-gate reading.

**Autonomy refinement (agent-startable today — no operator, no human, no predecessor, no structural blocker):** exactly four open tasks carry no blocker line at all:

1. **T038** — Review passage contract implementation against `contracts/passage-contract.md`; predecessors done (75/75 tests). Marked `UNBLOCKED 2026-09-15`.
2. **T289** — Author text alternatives for the 205 video materials (`alt: ""` on 205 of 213; disclosed gap). `[P] [SUBAGENT]`.
3. **T462** — Add contract sections and route-manifest rows for `screen_text`; "none but the work". Marked `unblocked today`.
4. **T543** — Closure: publish `max_depth_present` as a measurement, assert no constant bounds depth, record hierarchy limits + archived/uningested `02`/`02.01` in `workshop/docs/limits.md`, update `CONTINUATION.md`, run gate-coverage check. (Audit 2026-09-08: `max_depth_present` IS live via `GET /api/chapters`; `limits.md` records nothing about hierarchy yet, and no gate-coverage check exists.)

**Not autonomously startable right now:** T521, T527, T553, T554, T573 (operator/human sign-off); T530 (predecessors + human reviewer, last); T540 (predecessors T042/T022/T084); plus the operator/predecessor-blocked tasks listed in §3.

## 6. Evidence files

Confirmed absent: no `ev/` or `findings/` directory under `specs/008-unified-workshop-platform/`, and `spec.md` names no such requirement for spec 008. Evidence lives under the `workshop` submodule boundary (`workshop/evidence/`, `workshop/platform/backend/evidence/`, `workshop/platform/qa/evidence/`), consistent with the content-boundary rule that transcript-derived material stays inside `workshop/`'s own tree.

## 7. Recommendation

Start autonomously with **T543, T038, T289, T462** (in that order — T543 is the phase-17 closure item; the other three are scattered earlier phases). Do **not** start T521/T527/T530/T553/T554/T573 (operator or human gating, no agent action available); T540 waits on T042/T022/T084. Migration gates M1–M6 remain unsatisfied but block nothing currently open outside Phase 16; M0 is satisfied and its downstream work proceeds as ordinary implementation. M4 (FR-328) must pass before any decommissioning or M6 cutover, and every M6 step requires a prior FR-338 hardlinked backup.

---

*Honest boundary (§11.4.6): all counts and gate verdicts above are measurements of a single moment. This repository's instruments have changed verdict without being edited, because the fleet moves underneath them. Re-run `tasks.md` greps and the phase-order table before relying on any number here.*