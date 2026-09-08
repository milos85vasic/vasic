---
description: "Task breakdown for the per-chapter session record and QA readiness"
---

# Tasks: A Complete Session Record per Chapter, and a Platform a QA Team Can Test

**Input**: [spec.md](spec.md) · [plan.md](plan.md) · [research.md](research.md) · [data-model.md](data-model.md) · [contracts/](contracts/) · [quickstart.md](quickstart.md)

## How to read this file

**`[x]` means a command was run and its exit code observed**, with the evidence on
the task line. Tasks are kept rather than deleted because eleven parallel streams
built this during the session that specified it, and a list hiding completed work
would misrepresent both what remains and how the remainder must be verified.

**A checked box is not a claim that the capability is live.** Where a task was
verified in-process only, the line says so — that distinction is the subject of
constitution principle *Source Is Not Served*, which this feature's own spec
violated before it was written.

## Task Format

```
[ID] [P] [TDD] [REVIEW] [SUBAGENT] [Story] Description with file path
```

`[P]` parallelizable · `[TDD]` RED-GREEN-REFACTOR · `[REVIEW]` human gate before consumers · `[SUBAGENT]` delegable

## Paths

Repository-relative from the umbrella root. `workshop/` is the PRIVATE module;
`submodules/curriculum-kit/` is the public reusable library.

---

## Phase 1: Setup — the shape the content is authored against

- [x] T001 [REVIEW] Publish the reusable content library as `vasic-digital/curriculum-kit` (PUBLIC), mount as a gitlink, declare in `helix-deps.yaml` with a real ref (FR-030, SC-013). **Evidence** (source): 82 files; content-boundary scan 0 prose / 0 name rows; `verify-standalone-clone.sh` 3 gaps → 2.
- [x] T002 Add `Lesson.Body` to `submodules/curriculum-kit/pkg/curriculum/model.go` as opaque marked-up text the library neither parses nor renders (FR-013). **Evidence** (in_process): `go build`/`go test`/`go vet` rc 0; commit `07af6fb`.
- [x] T003 [P] Keep `Body` **optional** in the library and record why in `TestValidateDoesNotRequireALessonBody` (FR-013). **Evidence**: a materials-only lesson is legitimate, so "every lesson has a body" is a consumer policy the library may not impose; a future rule must change a test that explains its absence.
- [x] T004 [P] Assert `Body` and `Summary` have not collapsed into one value in `TestLessonBodyIsCarriedAndIsDistinctFromSummary`, including that an absent body decodes as `""` rather than a copy of the summary (FR-013).

**Execution note**: `DecodeDocument` calls `DisallowUnknownFields()`, so a `body`
key the library does not declare fails the **entire directory load**. Prove one
file decodes before writing 42.

---

## Phase 2: Foundational — one derivation per fact

**No user-story work may begin until T005 and T008 are complete.** Every story's
correctness derives from them.

- [x] T005 [TDD] [REVIEW] Compute the publication decision once in `workshop/platform/backend/internal/api/area_publication.go` and consume it from all three surfaces (FR-023, FR-025). **Evidence** (population: unstated): `verify-area-publication-consistency.sh` rc 0 (6 passed); prover rc 0 (7 mutations); `TestAreaListAndDetailAgree` asserts the **pair**, which is what was missing while both handlers' own tests passed.
- [x] T006 Make catalog staleness four-valued in `workshop/platform/backend/pkg/learning/catalog.go` — `Fresh`/`Stale`/`StalenessUnknown`/`NoSource` (FR-026a). **Evidence**: `NoSource` is separate so an in-memory test catalog, having no directory to have drifted from, keeps its legitimate negatives.
- [x] T007 Guard every determined negative about the catalog in `workshop/platform/backend/internal/api/lessons.go` via `catalogNegativeRefused()` (FR-024, FR-026a). **Evidence** (population: unstated): stale ⇒ 503 with `catalog_snapshot: "stale"` and the changed filenames; polarity proven — guard off returns the false 404, guard on returns 503.
- [x] T008 Build the session-record derivation in `workshop/platform/backend/pkg/sessionrecord/sessionrecord.go` — one place the rules live (FR-007, FR-012, SC-003). **Evidence** (source): `Resolve` has **no fourth branch**, so `vanished=0` holds by construction; a drop without a reason is refused and carries instead.
- [x] T009 [P] Order chapters by the existing `curriculum.ChapterID.OrdinalPath` rather than a new scheme (FR-002, FR-008). **Evidence**: a second ordering is a second thing to disagree.

**Checkpoint**: `areas[]` is exactly the set whose detail answers 200 (817 unopenable → 0), and no planned point can vanish.

---

## Phase 3: User Story 1 — a participant reads what a session produced (P1)

**Goal**: four sections per chapter, cumulative, each with content specific to that session.
**Independent test**: open each chapter, read all four sections, confirm none is empty or generic.

- [x] T010 [US1] Reuse the existing producer `workshop/pipeline/extract/meeting_notes.py` rather than forking it (FR-001, SC-001). **Evidence** (source): it already emitted all four sections into `curriculum/chapter-<slug>/knowledge/*.jsonl`; the brief's "0 matches in `chapters/`" was accurate and misleading — the material lives under `curriculum/`.
- [x] T011 [US1] Serve `session_record` on `GET /api/chapters/{id}` in `workshop/platform/backend/internal/api/chapters.go`, degrading on that key alone and never 503-ing the chapter (FR-005).
- [x] T012 [US1] Split `own_count` from `carried_count` per section (FR-004, FR-009). **Evidence** (population: unstated): two sections carry `own_count=0` with an authored reason; without the split they would read as productive sessions.
- [x] T013 [US1] Require a `reason` when `own_state` is `empty` (FR-004). **Evidence** (population: unstated): 12 of 12 sections present, **0 empty-without-reason** — this is the property that lets a tester tell a defect from a blank.
- [x] T014 [P] [US1] Carry `origin_chapter` on every item (FR-003, SC-002).
- [ ] T015 [US1] Build `GET /api/chapters/{id}/open-questions`, preserving the three-valued `resolution` the client already types (`answered_in_chapter`/`answered_by_research`/`unanswered`) (FR-005). **The wire must not narrow it** — the consumer already knows what it needs.
- [ ] T016 [P] [US1] Build `GET /api/chapters/{id}/todo` reading `pkg/sessionrecord`, never re-deriving (FR-005).
- [ ] T017 [P] [US1] Build `GET /api/chapters/{id}/next-meeting` reading `pkg/sessionrecord` (FR-005).
- [ ] T018 [TDD] [US1] Assert the routes and the embedded key serve the **same items** in `workshop/platform/gates/verify-session-record.sh` (FR-005, FR-023). **This is the pair assertion** — a route and a key that agree today are exactly what drift, and that class produced the 819-vs-817 catalogue bug.
- [ ] T019 [REVIEW] [US1] **BLOCKED — operator decision.** `GET /api/chapters/{id}/meeting-notes` is NOT built. Its withholding rule **may not be guessed** (FR-005a): one note is a content judgement left undecided. Update its DEBT row in `workshop/platform/gates/route-manifest.tsv` to name that specific blocker rather than the general one (FR-028).

---

## Phase 4: User Story 2 — a planned point that slipped is visibly carried forward (P1)

**Goal**: nothing planned disappears; slippage is visible.
**Independent test**: take a point planned and not covered; confirm it appears in the next chapter, marked, with its origin.

- [x] T020 [US2] Derive `plan(N) = unresolved(plan(N−1)) with slip+1 + next-meeting points of N−1` in `pkg/sessionrecord` (FR-006, FR-008, FR-010, FR-012). **Evidence** (population: unstated): 66 planned · 0 covered · 66 carried · 0 dropped · **0 vanished**.
- [x] T021 [US2] Resolve absence of a coverage decision to `carried`, never to a silent drop (FR-007, SC-003). **Evidence**: `Resolve` has no fourth branch — the invariant holds by construction, not by diligence.
- [x] T022 [P] [US2] Emit `marker: CARRIED-FORWARD` and `marker_label` with the count (FR-009, FR-010, SC-004). **Evidence** (population: unstated): 126 markers, 281 slip references on chapter 02.
- [x] T023 [US2] Serve the latest chapter's carry-forward as an **outbox** with `is_outbox: true` and a stated reason (FR-011). **Evidence** (population: unstated): 42 points, `max_slip=2`.
- [x] T024 [US2] Record `basis: undetermined` for chapter 01 and **compute no coverage percentage for it** (FR-006, FR-024). **Evidence**: no predecessor and no recorded intent; a percentage over an invented plan is a fiction with a denominator.
- [x] T025 [TDD] [US2] Prove the derivation with 16 corpus mutations in `workshop/platform/gates/prove-session-record.sh` (FR-025, SC-011). **Evidence** (population: unstated): rc 0, 14 assertions — control green, vacuity refusal exits 2, duplicate planned point rc 1, reasonless drop refused.
- [ ] T026 [SUBAGENT] [US2] Propose a coverage verdict per point with **per-point evidence and confidence**, marked `PROPOSED`, written to a separate artefact — never into `plan-coverage.json`, which is the decision record (FR-007a).
- [ ] T027 [TDD] [US2] Assert `coverage_state` is still `undecided` and the served counts have not moved after a proposal exists (FR-007a). **This is what makes "a proposal is not a decision" mechanical rather than aspirational.**
- [ ] T028 [REVIEW] [US2] **Operator gate**: confirm or overturn the proposed verdicts (FR-007a). Until then the served figure stays `undecided`.

---

## Phase 5: User Story 3 — a QA team can test the platform manually (P1)

**Goal**: a tester unfamiliar with the platform completes the document without asking a question.
**Independent test**: hand it to someone who has never seen this and watch.

- [x] T029 [US3] Write `workshop/docs/qa/MANUAL-TEST-PLAN.md` with every scenario's expected result stated **before** the action (FR-018, FR-019, FR-020, FR-022). **Evidence** (source): 82 scenarios across 11 surfaces; §0 is an "already known" table read first; §3 specifies seven mandatory defect-report fields.
- [x] T030 [US3] Write `workshop/docs/qa/CLIENT-WALKTHROUGH.md`, every step performed (population: unstated) (SC-015).
- [ ] T031 [SUBAGENT] [US3] **Regenerate both against the current build** (FR-020a). They describe 14 areas with tests and 0 lessons with content; live is **27** and **318 of 318**. **A stale expected-result column manufactures false defects** and spends a tester's day disproving our own fixes.
- [ ] T032 [US3] Record the build identifier in both — served-CSS `sha256`, served area count, index generation — and state they must be regenerated when it moves (FR-020a, FR-026).
- [ ] T033 [US3] Disclose up front (FR-020, FR-020b): 39 served against 42 authored; 12 areas carrying no test with the reason; every score indeterminate while banks mix machine-marked and free-text questions.
- [ ] T034 [P] [US3] Disclose that `/meeting-notes` is deliberately unbuilt and that three sibling routes may or may not be live — **check, do not assume** (FR-020, FR-028, SC-008).

---

## Phase 6: User Story 4 — every area detail shows real teaching and a real test (P2)

**Goal**: lessons with content; a test where one exists; a stated reason where none does.
**Independent test**: open every published area.

- [x] T035 [US4] Emit `"body"` verbatim from `workshop/pipeline/extract/build_learning_catalog.py` (FR-013, SC-005). **Evidence** (source): the builder already parsed every body, used it only for `estimatedMinutes`, and discarded it — 339 of 339 now carry one, median 328 words, longest 4,563.
- [x] T036 [US4] Emit `body` unconditionally from `workshop/platform/backend/pkg/learning/wire.go` (FR-013). **Evidence**: `""` is a determined "unauthored"; an absent key is indistinguishable from a transport fault.
- [x] T037 [US4] Render the body through the app's existing markdown renderer in `workshop/platform/frontend/src/app/features/areas/area-lessons.component.ts` — **not** a second renderer and **not** `[innerHTML]` (FR-013).
- [x] T038 [TDD] [US4] Ship `verify-lesson-content.sh` with **two arms** (FR-013, FR-023, FR-026). **Evidence**: in-process 339/339 rc 0; **live rc 1 at `318 of 318 EMPTY` before the restart** — the red baseline on the broken artefact. A gate with only the passing arm proves nothing.
- [x] T039 [US4] Send `X-Session` from the learning client via the **one** exported header builder in `workshop/platform/frontend/src/app/core/api.ts` (FR-013, FR-014). **Evidence** (served): lessons and assessment 400 → 200; the entire surface was unreachable in a browser.
- [x] T040 [US4] Fix the assessment envelope read one level too high, so a healthy 200 no longer renders as `malformed_response` (FR-014).
- [x] T041 [US4] Stop treating an empty `questions` array behind a **shut gate** as "no test exists" — consult `question_count` and the required-lesson gate first (FR-014, FR-015).
- [x] T042 [TDD] [US4] Ship `verify-bank-reachability.sh` — the **population** check that was missing (FR-014, FR-023, FR-026). **Evidence** (population: unstated): the existing gate checked route mountedness against one fixture area, so 89 questions were unreachable while it passed.
- [x] T043 [US4] Make the no-test copy state only what the server established (FR-015, FR-026a, SC-006). **Evidence** (population: unstated): it asserted *"there is genuinely none"* for 13 areas that had a bank — **confident prose asserting the opposite of the truth**.
- [ ] T044 [P] [SUBAGENT] [US4] Author text alternatives for the 205 video materials (FR-016, FR-028). **Evidence needed**: 205 of 213 carry `alt: ""`; the interface names the absence rather than hiding it, so this is a disclosed gap, not a hidden one.

---

## Phase 7: User Story 5 — a reviewer can confirm no claim is unearned (P2)

**Goal**: every claim resolves to machine-produced evidence or is marked unverified.
**Independent test**: sample claims; each resolves or is explicitly unverified.

- [x] T045 [US5] Withhold answer keys from the open practice route in `workshop/platform/backend/internal/api/questions_graded.go` (FR-?). **Evidence** (population: unstated): the decks are the same rows — 224 of 224 match by prompt, 0 of 224 by id — so gating practice would delete a feature; the defect was the disclosure.
- [x] T046 [US5] Fail closed on a nil, unreadable **or stale** catalog (FR-024, FR-026a). **Evidence**: a graded prompt the snapshot never saw would look "graded nowhere" to a literal index and be published.
- [x] T047 [US5] Refuse a malformed submission in `workshop/platform/backend/internal/api/assessment_submit_body.go`, naming the offending key, before the store is touched (FR-014). **Evidence** (population: unstated): a misspelled key returned 200 and permanently recorded a 0% attempt; `responses: []` still grades.
- [x] T048 [US5] Assert word-span containment on **both** endpoints in `workshop/platform/backend/pkg/knowledge/wordjoin.go` (FR-?). **Evidence** (population: unstated): containment was checked on word *starts* while the published span was derived from word *ends*; 7 of 2158 joined segments could publish a span their own passage does not contain.
- [x] T049 [P] [US5] Fix the gate-server leak in `workshop/platform/gates/lib/learning_stack.sh` (FR-?). **Evidence** (population: unstated): `BASE="$(ls_start …)"` runs in a **subshell**, so `LS_PID=$!` never reached the caller and every trap read an empty variable and returned 0 — 21 orphans reaped from this host.
- [ ] T050 [TDD] [SUBAGENT] [US5] Add the build identifier to `/api/health` (FR-026). **Evidence needed**: nothing noticed the container was four hours older than the code, because no reading could be tied to a revision.
- [ ] T051 [SUBAGENT] [US5] Commission a **second** independent adversarial review against the rebuilt container (FR-029, SC-014). The first found four false headline claims; a review that confirms is worth little.

---

## Phase 8: Polish & cross-cutting

- [x] T052 Untrack the 54 video-archive parts with `git rm --cached` and gitignore the pattern (FR-028). **Evidence** (source): tracked 54 → 0, on-disk bytes unchanged at 2,752,266,473, fresh checkout 2,711.7 MB → 87.0 MB. **`size-pack` did not fall and could not** — history rewriting is forbidden; the gate prints that limit itself.
- [x] T053 [P] Return **rc 2** with `TODO(storage-fetch)` when archive parts are absent, and keep **rc 1** for a present-but-corrupt part (FR-024, SC-010). **Evidence**: a missing download is not a corrupt archive, and conflating them sent a previous investigation at the wrong thing.
- [x] T054 [P] Make `_tools/watch-deploy.sh` read its exit codes (FR-023, FR-025). **Evidence** (in_process): it could loop 240 times against a deploy failing every cycle and exit 0; the proof fails **6 of 8** against a reconstruction of the pre-fix watcher.
- [x] T055 [P] Fix the hardcoded checkout path in `workshop/docs/training/curriculum-areas/16-*.md` and regenerate its four derived artefacts (FR-?). **Evidence** (source): the document teaches pointer discipline and broke it; audit 22 occurrences → rc 0; 597 citations still resolve; 18 of 18 sidecar pids present in the registry.
- [ ] T056 Restart once when every writer has stopped, verified by two `git status` readings 30 s apart (FR-027). **A restart triggers a 45-minute cross-reference derivation** over 24,929 passages, during which `verify-crossref-currency.sh` correctly reports rc 1.
- [ ] T057 Re-run the full gate sweep against the rebuilt container and record each figure with its **population** — `source`, `in_process` or `served` (FR-023, FR-026).
- [ ] T058 [P] [SUBAGENT] Register every new gate in `workshop/platform/gates/check-registry-006.tsv` (FR-?). **Evidence needed**: an unregistered gate fails the registry's own R5 anti-drift rule, which caught one of mine today.
- [ ] T059 [P] [SUBAGENT] Re-validate every `exempt` row whose subject changed this session (FR-028). **Evidence needed**: one said *"it judges nothing"* of a script that had gained a three-valued verdict — an exemption whose justification expired still looks reviewed.
- [ ] T060 [REVIEW] **Operator gate**: read the 3 documents failing publication review on 62, 54 and 58 uncited claim blocks (FR-020b, FR-023). They stay unpublished until read; a client sees 39 areas, not 42.

---

## Dependencies

```
Phase 1 (kit + Body)
  └─> Phase 2 (T005 publication · T008 session derivation)   ← the checkpoint
        ├─> Phase 3 US1  ─┐
        ├─> Phase 4 US2  ─┤   independent of one another
        ├─> Phase 5 US3  ─┤
        ├─> Phase 6 US4  ─┤
        └─> Phase 7 US5  ─┘
Phase 8  — T056 requires EVERY writer stopped; T057 requires T056
```

**T005 and T008 block every story.** Nothing else does — the five stories touch
disjoint file sets and were built concurrently.

**T019, T028 and T060 are operator gates, not work items.** **T031 blocks the QA
session** — handing over stale documents is worse than handing over none.

## Parallel Execution

| Stream | Owns | Tasks |
|---|---|---|
| Content | `docs/training/`, `curriculum/`, `pipeline/` | T010, T020–T026, T035, T055 |
| Backend | `platform/backend/`, `platform/gates/` | T005–T009, T011–T018, T036, T042, T045–T050 |
| Frontend | `platform/frontend/src/app/` | T037, T039–T041, T043, T044 |
| QA docs | `docs/qa/` | T029–T034 |
| Umbrella | `_tools/`, `scripts/` | T052–T054 |

**Cross-stream rule**: any stream measuring another's output must **rebuild
immediately before measuring and state which build it read.** The partition held
today; the timing did not — a stylesheet was read mid-rewrite and a build id was
hashed over an orphaned file a `cp -a` left behind.

## Implementation Strategy

**MVP = Phases 1, 2 and 3.** A chapter that carries its four sections honestly.

**Increment 2 = Phase 4** — carry-forward, which is what makes the record more
than a snapshot: nothing planned disappears.

**Increment 3 = Phases 5–7.** QA readiness, learner completeness, evidence.

**Phase 8 is not optional polish.** Until T056 and T057 run, every fix in Phases
6–7 is verified **in process** and unverified **as served** — the exact
distinction constitution principle *Source Is Not Served* exists to enforce, and
the one this feature's own specification violated before it was written.

## Status

Counted from this file by script, not transcribed.

| Phase | tasks | done | open |
|---|---:|---:|---:|
| 1 Setup | 4 | 4 | 0 |
| 2 Foundational | 5 | 5 | 0 |
| 3 US1 session record | 10 | 5 | 5 |
| 4 US2 carry-forward | 9 | 6 | 3 |
| 5 US3 QA readiness | 6 | 2 | 4 |
| 6 US4 area completeness | 10 | 9 | 1 |
| 7 US5 evidence | 7 | 5 | 2 |
| 8 Polish | 9 | 4 | 5 |
| **Total** | **60** | **40** | **20** |

```bash
grep -c '^- \[' specs/006-session-record-and-qa-readiness/tasks.md     # 60
grep -c '^- \[x\]' specs/006-session-record-and-qa-readiness/tasks.md  # 40
```

**40 of 60 carry a captured run.** Of the 20 open, **3 are operator gates**
(T019, T028, T060) and **2 require the single restart** (T056, T057). The
remaining 15 are engineering work, and T031 is the one that blocks the QA session.

---

## Superspec bridge — where the bite-sized steps live

`/speckit-superspec-tasks` ran `superpowers:writing-plans` over the remainder.
Output:

**`workshop/docs/superpowers/plans/2026-09-08-qa-handover-remainder.md`** (313 lines)

**Scope check:** of the 20 open tasks, **9 are in flight** with live agents
(T015–T018 routes, T026 coverage, T031–T034 QA documents) and **3 are operator
gates** (T019, T028, T060). Writing bite-sized steps for work in flight would
duplicate an agent mid-task and create two authorities for one file. The
blueprint therefore covers the **8 unheld** tasks.

| Blueprint | tasks.md | Produces |
|---|---|---|
| A1 | T044 | `verify-material-alt.sh` + prover; 205 video alts authored |
| A2 | T050 | build identity on `/api/health`, dirty-tree marked |
| A3 | T059 | expired exemptions withdrawn, not overwritten |
| A4 | T058 | every new gate registered; R5 green |
| B1 | T056 | the single restart, gated on two stable readings |
| B2 | T057 | full re-measurement, every figure carrying its population |
| C1 | T051 | the second adversarial review, against the rebuilt container |

**Two properties worth naming.**

**A1 writes the gate BEFORE authoring the content, and requires it to fail
first.** If it passes on today's tree its population is wrong, because the 205
missing alternatives are real. Its prover includes an overreach case — *an alt
identical to its caption fails* — which a gate written only against emptiness
would have certified as correct.

**The blueprint's own self-review found a sequencing gap and states it rather
than hiding it**: A2's build stamp is invisible until B1 restarts, so A2's *live*
verification belongs to Track B. That is written into A2's step 4.

**Execution order:**

```
A1 A2 A3 A4   (independent, now)      A2's live check defers to B2
[every writer stops] -> B1 -> (45 min derivation) -> B2 -> C1
```
