---
description: "Task breakdown for authored AI/IT knowledge areas with lessons, tests and video anchors"
---

# Tasks: Authored AI/IT Knowledge Areas with Lessons, Tests and Video Anchors

**Input**: Design documents from `specs/004-authored-ai-areas/`
**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md), [data-model.md](data-model.md), [contracts/](contracts/), [quickstart.md](quickstart.md)

## How to read this file

**Tasks marked `[x]` are DONE and were verified with a captured run**; the
evidence is on the task line. They are kept rather than deleted because this
feature was built by four parallel streams during the session that specified it,
and a task list that hid the completed work would misrepresent both what remains
and how the remainder must be verified.

**A checked box here means a command was run and its exit code observed.** It
does not mean the capability is live — several completed tasks are verified
in-process and remain unverified over HTTP. Those are checked here and listed
again under Phase 8, which exists precisely so an in-process pass is never
mistaken for a served one.

## Task Format

```
[ID] [markers] [Story] Description with file path
```

**Markers**: `[P]` parallelizable · `[TDD]` RED-GREEN-REFACTOR · `[REVIEW]`
review before consumers are built · `[SUBAGENT]` delegable

**Story labels**: `[US1]`..`[US6]` map to the user stories in
[spec.md](spec.md).

## Path Conventions

Paths are repository-relative from the umbrella root. The two roots that matter:
`workshop/` (the private module) and `submodules/curriculum-kit/` (the reusable
library, project-unaware).

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: The reusable shape and the strict content format exist before
anything is authored against them.

- [x] T001 [REVIEW] Create the reusable curriculum library in `submodules/curriculum-kit/` — `Catalog → Area → Lesson → Material` plus `Area.Assessment`, with `VideoAnchor{chapterId,startMillis,endMillis,transcriptAnchor}`. **Evidence**: 82 tracked files; `go test ./...` ok.
- [x] T002 Keep the library project-unaware by construction in `submodules/curriculum-kit/go.mod` — an empty require set, so a project import would not compile. **Evidence**: compiler-enforced, not convention.
- [x] T003 [P] Implement `DecodeDocument` with `DisallowUnknownFields()` in `submodules/curriculum-kit/pkg/curriculum/document.go`. **Evidence**: a misspelled key fails the load loudly instead of dropping its material silently.
- [x] T004 [P] Make `Area.Assessment` a pointer so "under construction" is representable, and have `Validate` emit `CK021` for it rather than letting the absence pass unnoticed. **Evidence**: 37 CK021 findings raised, none suppressed.

**Execution notes**: T003 is the load-bearing decision of this phase. Everything
authored later either decodes or fails at load; there is no partial-success path.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: The single publication decision, and the evidence base the authored
set is selected from. **No user story work can begin until this phase is
complete**, because every story's visibility derives from T007.

- [x] T005 Measure module evidence across **all** recordings in `workshop/pipeline/extract/measure_module_evidence.py`. **Evidence**: rc 0; 0 of 37 modules with zero evidence, 0 of 137 terms matching zero passages; 16 strong / 9 moderate / 12 thin.
- [x] T006 Enforce the already-written "title non-empty when published" rule in `workshop/pipeline/extract/publication_policy.py` **and** in the pipeline reconcile stage, so a re-run reproduces it. **Evidence**: published 819 → 42; nothing deleted, withheld rows to `workshop/curriculum/unpublished-areas.jsonl`.
- [x] T007 [TDD] [REVIEW] Compute the publication decision **once** in `workshop/platform/backend/internal/api/area_publication.go` (`AreaPublicationOf`) and consume it from all three surfaces. **Evidence**: `verify-area-publication-consistency.sh` rc 0 (6 passed); `prove-area-publication-consistency.sh` rc 0 (7 passed / 7 mutations); Go `TestAreaListAndDetailAgree` asserts the **pair**, which is what was missing while both handlers' own tests passed.
- [x] T008 [P] Promote the 37 authored subjects through the real minting bridge in `workshop/pipeline/extract/promote_curriculum_areas.py`, supplying a lexicon evidence finder instead of the title-keyword default. **Evidence**: rc 0, 37 published / 0 failed; reviews 2 → 39.
- [x] T009 [P] Keep `proposer` and `reviewer` distinct in the review store, both defaulting to the pipeline string. **Evidence**: honest description of a run with no independent audit; `--reviewer` is passed only when a human has read them.

**Checkpoint**: The catalogue is honest about itself. **T007 is the checkpoint** —
`areas[]` is now exactly the set whose detail answers 200, asserted end to end.

---

## Phase 3: User Story 1 — A learner finds a subject they recognise (P1) **MVP**

**Goal**: Every catalogue entry is nameable by a person and every entry opens.
**Independent Test**: Open the catalogue, read every visible entry, open each one.

- [x] T010 [US1] Serve `areas[]` as exactly the servable set, with `held_back[]`, the reason table and `total_areas` in the same response, in `workshop/platform/backend/internal/api/`. **Evidence**: 817 unopenable → 3.
- [x] T011 [US1] Disclose a derived title/tags/summary on a **refusal** where one is derivable, in the same handler. **Evidence**: the reported symptom was a page reading only "withheld pending review"; an area held back for a missing review has a perfectly good name.
- [x] T012 [P] [US1] Add `?include=held_back` so withholding never makes an area unreachable.
- [x] T013 [P] [US1] Emit `tags` as an empty array, never `null`, in the area wire type. **Evidence**: a null breaks the field the interface filters on.
- [x] T014 [US1] Derive titles, tags and summaries in `workshop/platform/backend/pkg/knowledge/presentation.go`.
- [ ] T015 [US1] Add a `tags` field to the client area model in `workshop/platform/frontend/src/app/core/knowledge.ts` — it models `terms` and **has no field for tags at all**, so tags are discarded before any component can ask for them (FR-019).
- [ ] T016 [US1] Render title, summary and tags on the area detail page in `workshop/platform/frontend/src/app/features/` — 3 of 4 render branches emit the raw identifier as the heading (SC-003).

**Checkpoint**: A learner can open every listed area and read what it is.

---

## Phase 4: User Story 2 — A learner works through an area and is tested (P1)

**Goal**: Lessons in order, a gated end-of-area test, a scored result.
**Independent Test**: Read one area's lessons, take its test answering some right and some wrong, check the score and per-question feedback match.

### Tests for User Story 2

> Written FIRST and verified to fail. The load-bearing one is T017.

- [x] T017 [TDD] [US2] Prove the assessment gate with **17 data mutations** in `workshop/platform/gates/prove-assessment-gate.sh`, including B4/M7 "the gate opens as soon as *any* lesson completes" — which passes B1, B2, B3, B5 and B7 and is caught **only** by B4. **Evidence**: rc 0, 17 passed. Requires the fixture's required set to be a **proper subset** of its lessons.
- [x] T018 [TDD] [US2] Add a leak check that fails if `correct_choices` or `explanation` appears on the taking path, in `workshop/platform/backend/internal/api/lessons_test.go`.
- [x] T019 [P] [US2] Add vacuity refusals **B9/B10** — no lesson outside the required set, or a test gated on nothing, must exit **2**, never 0.

### Implementation for User Story 2

- [x] T020 [US2] Implement the six learning routes in `workshop/platform/backend/internal/api/lessons.go`, all behind the T007 decision, all keyed on the opaque `X-Session` header only.
- [x] T021 [US2] Build the taking projection as a map with **no answer field at all** in the same file — not the domain type with fields omitted, so no future upstream field can leak through it.
- [x] T022 [P] [US2] Validate `?kind=` against the closed vocabulary and return **400** for an unknown kind. **Evidence**: an empty list reads as "there are none", which is a different and false statement.
- [x] T023 [US2] Implement the session progress store in `workshop/platform/backend/pkg/learning/` — one `Mutate` under a single lock, atomic temp-file+rename, a file separate from the reading-position store. **Evidence**: a Get+Put cycle silently drops a concurrent completion.
- [x] T024 [US2] Build the authored learning catalog in `workshop/pipeline/extract/build_learning_catalog.py` → `workshop/curriculum/learning/`. **Evidence**: 42 files, 339 lessons, 1,068 minutes; ids derived from the area ULID so catalog-wide collisions are structurally impossible.
- [x] T025 [US2] Resolve each bank's `correct_index` to a choice **id** during the build. **Evidence**: the kit rejects the index form by design.
- [x] T026 [US2] Exclude the 10 `flashcard` rows rather than mapping them onto graded items, and report the exclusion. **Evidence**: mapping a study aid onto a test question is a silent promotion.
- [x] T027 [US2] Pass `-learning-catalog /opt/workshop/curriculum/learning` in `workshop/platform/compose.yml`. **Evidence**: the flag defaults to EMPTY and empty is a *determined* state — every learning route would answer `no_learning_catalog` cleanly after a restart, with nothing in any log to notice. YAML re-parsed; the path is inside the existing read-only bind, so no volume change.
- [ ] T028 [US2] Render the lesson list and lesson body with prev/next in `workshop/platform/frontend/src/app/features/`, using the same sorted slice the list uses.
- [ ] T029 [US2] Render the test — availability message before completion, questions after, result after submission — in the same feature directory, showing `pass_percent` **before** the attempt begins (FR-008b).

**Checkpoint**: The full learner journey works against authored content.

---

## Phase 5: User Story 3 — Jump to the exact moment in the recording (P2)

**Goal**: Follow a lesson reference; land on the recording at that moment with the transcript scrolled and the passage marked.
**Independent Test**: Follow every reference in one area and confirm all four consumer obligations.

- [x] T030 [US3] Write the URL grammar down as the producer's authority in `workshop/platform/frontend/docs/time-links.md`.
- [x] T031 [US3] Build spans from engine-measured start/end times joined on passage id, in `workshop/pipeline/extract/build_area_timelinks.py` → `workshop/curriculum/area-timelinks.json`. **Evidence**: rc 0, 205 spans; the passage registry carries **only** an end time, so a start derived from it alone would be invented.
- [x] T032 [US3] Emit `end` **only when `> t`** and `#p-` **only for a Crockford-shaped ULID**, in the material renderer. **Evidence**: the consumer ignores a malformed span, so producing one yields a link that renders correctly and does nothing.
- [x] T033 [US3] Emit `href: null` + `unresolved_reason` + intact anchor + a count for an unservable chapter. **Evidence**: 205 of 205 resolved, 0 unresolved.
- [x] T034 [US3] Declare the chapter registry **from disk** (`workshop/chapters/`) rather than from the anchors themselves. **Evidence**: deriving it from the anchors would make the resolution check vacuously pass; `ScanChapterDirs` returns exactly `01`, `02`, `02.01`.
- [x] T035 [US3] Implement the client-side time-link contract in `workshop/platform/frontend/src/app/core/timelink.ts`.
- [ ] T036 [US3] Seek the player to `t` and scroll the transcript to the `#p-` passage **without further scrolling**, marking it visually, in the transcript component.
- [ ] T037 [P] [US3] Make the extent of a range discernible when `end` is present, not only its start (US3 scenario 3).
- [ ] T038 [P] [US3] Report an unresolvable target as unavailable rather than routing to a page that reports nothing found (FR-017).

---

## Phase 6: User Story 4 — Materials, not only text (P2)

**Goal**: Illustrations, diagrams, schemes, graphs and in-place video segments.
**Independent Test**: Open every lesson in one area; each declared material renders, is captioned, and is reachable without a mouse.

- [x] T039 [US4] Specify one diagram per area — type, the single idea, concrete nodes and edges — in `workshop/docs/training/diagrams/SPEC.md`, with deliberately smaller diagrams for the thin modules and the reason written down.
- [x] T040 [US4] Build 8 SVGs in the house style extracted from `design-system/diagrams/`, **adding** `<title>`, `<desc>`, `role="img"` and `aria-label` — absent from 0 of 33 references. **Evidence**: all 8 parse as XML, rc 0; no external font, image or script.
- [x] T041 [P] [US4] Serve `video` materials with `chapter_id`, `start_millis`, `end_millis`, `length_millis`, `transcript_anchor`, `chapter_slug` and `href`.
- [ ] T042 [US4] Render materials in place with their captions in the lesson component.
- [ ] T043 [P] [US4] Play a video segment in place, bounded to its stated range.
- [ ] T044 [P] [SUBAGENT] [US4] Rasterise the 8 SVGs and check text fit at the served font metric — well-formedness and theming are verified; **text fit is not** (plan.md gap 7).

---

## Phase 7: User Story 5 — Vivid, legible, consistent (P2)

**Goal**: A varied palette that remains legible in both presentations.
**Independent Test**: Sample the colours actually painted on each principal surface; measure variety across them and contrast within each pairing.

- [ ] T045 [US5] Regenerate the served stylesheets from the widened token source in `workshop/platform/frontend/src/styles/`, then rebuild. **This is defect D6**: nothing had regenerated them, so a token-level widening never reached a visitor.
- [ ] T046 [TDD] [SUBAGENT] [US5] Write a hue-family check that reads the **served** stylesheet — not the token source — asserting ≥6 distinct hue families across principal surfaces (SC-010). A check that reads the token source commits D6 inside the instrument meant to catch it.
- [ ] T047 [TDD] [P] [SUBAGENT] [US5] Write a contrast check asserting the normal-text and non-text floors in **both** light and dark presentation, over the served bundle (SC-011).
- [ ] T048 [P] [SUBAGENT] [US5] Pair T046 and T047 with data-driven mutation proofs, each carrying a control and a vacuity refusal that exits 2.
- [ ] T049 [US5] Emit `corpus_revision` on the served catalogue and cite it in every interface claim (FR-023a). **Analysis finding F7 — MISPLACED**: this is a catalogue concern owned by the backend stream, not a presentation one. Execute it with Phase 3 (US1); it is listed here only because the superspec blueprint's Track A carries a *bundle* build id, which is a different artefact, and this task must not be assumed covered by it.

**Execution note**: rebuild immediately before measuring and **state which build
was measured**. A stream that measures another stream's output mid-write reads a
transiently broken file — this happened during construction and the partition was
not what failed; the timing was.

---

## Phase 8: User Story 6 — Each module runs on its own (P3)

**Goal**: Clone either module alone, bootstrap it, reach a running system.
**Independent Test**: Clone into an empty directory outside the umbrella on a host that has never held it.

- [x] T050 [US6] Add `workshop/scripts/bootstrap-standalone.sh` and `workshop/helix-deps.yaml`.
- [x] T051 [P] [US6] Add `verify-standalone-clone.sh` to both `workshop/scripts/` and `ai_interviewing/scripts/`.
- [x] T052 [US6] Record the `curriculum-kit` replace-target gap verbatim in `workshop/platform/backend/go.mod`. **Evidence**: gaps 2 → 3, correctly — the gate working, not drift.
- [ ] T053 [US6] **BLOCKED — operator decision.** Publish `submodules/curriculum-kit` as a git repository and mount it as a gitlink, then declare it in `helix-deps.yaml`. It is currently a plain directory with **no commit to pin**, so a truthful manifest entry cannot be written and a fabricated `ref:` would be a bluff.

---

## Phase 9: Polish & Cross-Cutting — turning in-process passes into served ones

**Purpose**: Every task above marked `[x]` that was verified **in-process** is
still a **2** over HTTP. This phase is where that changes, and it exists as its
own phase so the distinction is never quietly dropped.

- [ ] T054 Stop every writing stream, then restart once with `bash workshop/scripts/restart.sh` (a full down/up, never `compose restart`). **Never pass `--destroy-volumes` to `stop.sh`** — the `workshop-index` volume holds hours of transcription output.
- [ ] T055 Re-run `bash workshop/platform/gates/verify-server-unity.sh` against the live container. **Currently RED at `PASS=37 FAIL=6`** — all six new routes answering a plain-text 404 because the container runs the old binary. Against a server built from this tree the same gate is `PASS=43 FAIL=0 UNDET=0 DEBT=8`.
- [ ] T056 Confirm `GET /api/areas` returns **42**, not the 819 the running container still holds in memory from start-up.
- [ ] T057 Exercise all six learning routes over HTTP against authored content. Everything so far is measured through the server's own loader **in-process**; the HTTP surface is unmeasured (plan.md gap 1).
- [ ] T058 [P] Register the new gates in `workshop/platform/gates/check-registry-002.tsv` and the pipeline gates in their registry. **Evidence needed**: `verify-check-registry-002.sh` currently rc 0 at `checks=94 debt=3`.
- [ ] T059 [P] Add `workshop/curriculum/area-timelinks.json` and `workshop/curriculum/unpublished-areas.jsonl` to `.gitignore`, matching their siblings.
- [ ] T060 [P] Re-run the full frontend suite and account for every delta against the 162/0/8 baseline.
- [ ] T061 [REVIEW] **Human checkpoint** — read the 3 area documents failing publication review on 62, 54 and 58 uncited claim blocks. They stay failing until read; stamping them is the bypass.
- [ ] T062 [REVIEW] **Human checkpoint** — confirm or replace the 70% `passPercent`, the mcq-2/short-3 point weights, the 91–95 prefix shift and the anchor attachment section. These four are authored schema choices, stated rather than measured.
- [ ] T063 [SUBAGENT] Re-mine chapter 02 into the taxonomy, or record the coverage gap explicitly. A topic taught only there, in words the chapter-01 lexicon lacks, is invisible to every coverage figure in this feature.
- [ ] T064 Regenerate the 12 pre-existing documents' ingested `.sections.json`, or record that their corpus copy is stale. **Regenerating mints new pids and changes the searchable corpus** — a corpus decision, not a cleanup.
- [ ] T066 [TDD] Assert **corpus stability during measurement** in every corpus-counting run (FR-030) — fingerprint the enumerated set before and after the analysis passes, sharing the enumeration with the analysis by construction, and emit `undet` rows **naming the changed paths** when they differ. **Analysis finding F2: this requirement had zero task coverage.** It was promoted from a real incident — a gate reporting 12939 / 12939 / 13058 / 12968 for the same command on a tree another agent was editing. The umbrella's `scripts/verify-content-boundary.sh` already implements exactly this; reuse its approach rather than inventing one.
- [ ] T067 [TDD] [P] Assert **result stability** (FR-011) in `workshop/platform/gates/prove-assessment-gate.sh` — submit, re-read, require a byte-identical result. **Analysis finding F4: FR-011 appeared only as a manual quickstart step, so nothing asserted it.**
- [ ] T068 [P] Detect **duplicate subjects** (FR-020) in `workshop/pipeline/extract/verify_curriculum_areas.py`, or record FR-020 as deferred with its reason. **Analysis finding F5**: an existing mutation catches one *area* in two files; nothing catches two areas covering one *subject*.
- [ ] T069 [P] Report **question-bank coverage** on every run as a fraction of published areas (SC-004a), currently 5 of 42. A tracked figure, never a floor.
- [ ] T070 [P] Append the governing FR/SC identifiers to each task line in this file. **Analysis finding F8**: 33 of 39 FRs and 14 of 18 SCs are cited nowhere by id, so **SC-013 ("100% of requirements map to a check") is mechanically unverifiable** — it can be argued but not computed. With ids present it becomes a `grep`.
- [ ] T065 [SUBAGENT] Investigate the redaction-pipeline report: one segment is marked `redacted: true` while the same sentence survives in the merged transcript. Reported, not acted on.

---

## Dependencies

```
Phase 1 (kit + strict format)
  └─> Phase 2 (T007 single decision)          ← the checkpoint
        ├─> Phase 3 US1  ─┐
        ├─> Phase 4 US2  ─┤  independent of each other
        ├─> Phase 5 US3  ─┤
        ├─> Phase 6 US4  ─┤
        └─> Phase 7 US5  ─┘
Phase 8 US6  — independent of all stories
Phase 9      — requires every writing stream to have STOPPED (T054)
```

**T007 blocks every story.** Nothing else does: US1–US5 touch disjoint file sets
and were in fact built concurrently.

**T054 blocks T055–T057** and must run exactly once, after all writers stop. A
restart mid-write measures a tree that is still moving.

## Parallel Execution

Four streams with disjoint file sets, as actually run:

| Stream | Writes | Tasks |
|---|---|---|
| Content | `workshop/docs/training/`, `workshop/curriculum/`, `workshop/pipeline/` | T005, T006, T008, T024–T026, T031, T039, T040, T063, T064 |
| Backend | `workshop/platform/backend/`, `workshop/platform/gates/` | T007, T010–T014, T017–T023, T032–T034, T041, T058 |
| Frontend | `workshop/platform/frontend/src/app/` | T015, T016, T028, T029, T035–T038, T042, T043 |
| Theming | `workshop/platform/frontend/src/styles/` | T045–T048 |

**Cross-stream rule**: any stream measuring another stream's output must rebuild
immediately before measuring and state which build it measured.

## Implementation Strategy

**MVP = Phase 1 + Phase 2 + Phase 3 (US1).** A catalogue that is honest about
what it holds. T007 alone took listed-but-unopenable areas from 817 to 3.

**Increment 2 = Phase 4 (US2)** — lessons and a gated test. This is the mission
as stated, and its backend is done; T028/T029 are what remain.

**Increment 3 = Phases 5–7.** Anchors, materials, presentation.

**Phase 9 is not optional polish.** Until T054–T057 run, this feature is verified
on disk and in process, and **unverified as served** — which is the exact defect
class (D6, D8) it was written to eliminate. Reporting it complete before then
would repeat the mistake inside the fix for it.

## Status

Counted from this file by script, not transcribed from a draft. An earlier
revision of this table said 44 done; the file said 37. **The file was right**,
and the discrepancy is recorded rather than quietly corrected, because a task
list whose summary disagrees with its own checkboxes is the same defect class as
a catalogue whose list disagrees with its detail route.

| | tasks | done | remaining |
|---|---:|---:|---:|
| Phase 1 Setup | 4 | 4 | 0 |
| Phase 2 Foundational | 5 | 5 | 0 |
| Phase 3 US1 | 7 | 5 | 2 |
| Phase 4 US2 | 13 | 11 | 2 |
| Phase 5 US3 | 9 | 6 | 3 |
| Phase 6 US4 | 6 | 3 | 3 |
| Phase 7 US5 | 5 | 0 | 5 |
| Phase 8 US6 | 4 | 3 | 1 (blocked) |
| Phase 9 Polish | 17 | 0 | 17 |
| **Total** | **70** | **37** | **33** |

Re-derive rather than trusting the table:

```bash
grep -c '^- \[' specs/004-authored-ai-areas/tasks.md    # 70
grep -c '^- \[x\]' specs/004-authored-ai-areas/tasks.md  # 37
```

**Five tasks (T066–T070) were added by `/speckit-analyze` remediation**, closing
the three requirements that had zero coverage (FR-011, FR-020, FR-030) plus the
two traceability findings. None is done.

**37 of 65 tasks carry a captured run.** Zero of the 12 Phase 9 tasks do, which
is the honest headline: the work is built and proved in process, and **not one
line of it has been proved as served**.

---

## Superspec bridge — where the bite-sized steps live

`/speckit-superspec-tasks` ran the `superpowers:writing-plans` skill over the
remainder. Its output is an implementation blueprint at

**`workshop/docs/superpowers/plans/2026-09-07-served-verification-and-presentation-instruments.md`** (380 lines)

which decomposes the **unheld** remainder into bite-sized TDD steps with exact
files, real commands and expected exit codes.

**Why only the unheld remainder.** The scope check found that 6 of the 28 open
tasks — T015, T016, T028, T029, T036 (frontend) and T045 (theming) — are being
worked by live agents right now. Writing bite-sized steps for work in flight
would have duplicated an agent mid-task and produced two authorities for the
same file. Those tasks keep their entries here and take their direction from
their agents.

| Blueprint task | tasks.md | What it produces |
|---|---|---|
| A1 | (new) | `lib/served_css.sh` — one definition of "what is served", refusing with **2** rather than guessing |
| A2 | (new) | `sample-served-surfaces.mjs` — samples what is **painted**, both colour schemes, no verdict |
| A3 | T046, T048 | `verify-served-palette.sh` + prover, 3 data mutations, mutation 0 the control |
| A4 | T047, T048 | `verify-served-contrast.sh` + prover, incl. a mutation that passes light and fails dark |
| A5 | T058 | Registry rows; `checks=94 -> 98`, debt unchanged |
| B1 | T054 | The single restart, gated on a tree that has stopped moving |
| B2 | T056 | The list/detail pair asserted **over HTTP** |
| B3 | T057 | SC-009 measured **on the wire**, which is the only place it counts |
| B4 | T055 | `verify-server-unity.sh` 37/6 -> 43/0 |
| B5 | T044, FR-023a | Presentation measured against the restarted stack, with the build id stated |

**Sampling is split from verdict on purpose.** It is what lets every mutation be
a **data** edit to a fixture rather than a code edit to a gate — the §1.1
requirement that makes a prover trustworthy.

**One gap the blueprint's self-review found and did not paper over**: FR-023a
asks the *served catalogue* to declare its corpus revision, while Track A carries
a build id for the *bundle*. Different artefacts. That is **T049**, it belongs to
the backend stream, and the blueprint says so rather than letting A2 look like it
covers it.

**Execution order:**

```
A1 -> A2 -> A3 --+
            A4 --+-> A5        buildable NOW, writers still running
[all writers stop] -> B1 -> B2 -> B3 -> B4 -> B5   (B5 needs A3+A4)
```
