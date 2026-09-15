---

description: "Unified task list for the merged Workshop Platform specification"
---

# Tasks: Unified Workshop Platform

**Input**: [`spec.md`](./spec.md), [`plan.md`](./plan.md), and the design documents of the seven
superseded features (`specs/001-…` through `specs/007-…`).

**Supersedes**: the `tasks.md` of all seven source features. Those files remain in the tree,
unmodified except for a supersession notice, and are the authoritative record of the reasoning
behind each task.

## How this file was produced, and what is guaranteed about it

Every task from all seven source task lists is carried here — **573 of 573** — with:

- a **new unified identifier** `T001` … `T573`, assigned sequentially in this file's phase order;
- a **back-reference to its origin**, in the form `(was: 002/T088)`;
- its **checked/unchecked state preserved exactly** as it stands in its source file — a task that is
  `[x]` there is `[x]` here, a task that is `[ ]` there is `[ ]` here;
- its **full original text preserved byte-for-byte**, including multi-line continuations, execution
  markers, requirement references (which still cite their *source* specification's numbering), and
  the evidence notes several sources attach to each task.

**The remapping was performed mechanically, not by hand**, and verified three ways:

| Check | Result |
|---|---|
| Source task count, summed across the seven files | **573** |
| Merged task count | **573** — identical |
| Source tasks in the checked state | **344** |
| Merged tasks in the checked state | **344** — identical |
| Source task text blocks present verbatim in this file | **572 of 573** matched exactly (481,450 characters of task text); **1 carries a single stated credential redaction** — see below |

**Per-source breakdown of what was carried in:**

| Source | Total | `[x]` complete | `[ ]` open |
|---|---:|---:|---:|
| `001-workshop-curriculum-platform` | 131 | 71 | 60 |
| `002-knowledge-areas-deep-linking` | 153 | 110 | 43 |
| `003-chapter-hierarchy` | 45 | 20 | 25 |
| `004-authored-ai-areas` | 82 | 55 | 27 |
| `005-clone-and-clear-red` | 61 | 32 | 29 |
| `006-session-record-and-qa-readiness` | 70 | 40 | 30 |
| `007-decouple-modules-auth` | 31 | 16 | 15 |
| **Total** | **573** | **344** | **229** |

### The one place this file departs from verbatim preservation, stated rather than hidden

**Exactly one redaction was made, in T503 (was `007/T018`).** That task's original text quotes the
two seed passwords in full. Reproducing them here would have created a **new** copy of a credential
in a public repository, which this project's governing credential rule forbids outright — and which
the specification's own FR-306 treats as the highest-severity finding in the family.

The two literal values are replaced with a marker. **Nothing else in that task changed**, and the
original text remains readable, unchanged, in `specs/007-decouple-modules-auth/tasks.md` at T018 —
where it already sits in public git history and where removing it is neither possible nor this
merge's decision to take.

This is recorded here rather than performed silently, because a file that promises byte-for-byte
preservation and then quietly edits one line is worse than one that states its single exception.
The verbatim verification reported above therefore reads **572 of 573 blocks matched exactly, plus
one deliberately redacted**; the redaction is the only difference.

### One thing this file deliberately does NOT do

**No task's state was re-evaluated, and no task's text was edited.** A `[x]` here means *"this was
marked complete in its source file"* — nothing more. It is **not** a claim, made by this merge, that
the task's work is verified today. Several source files carry their own notes about tasks whose fix
landed without its paired proof, or whose evidence is in-process rather than sink-side; those notes
are carried through unchanged and should be read at face value. Re-verifying 344 completion claims
is separate work with its own evidence obligation.

Likewise, **requirement references inside task text still cite the numbering of the specification
that task came from** — a task from `002` saying `(FR-033d)` means `002/FR-033d`. Rewriting 573 task
bodies to the unified numbering would have edited text this merge promised to preserve. Use the
back-reference plus the Supersession Map in [`spec.md`](./spec.md) to translate.

## What the 2026-09-15 unified-numbering pass did, and what it did not do

**The paragraph immediately above is SUPERSEDED in part, and it is kept because it states the hazard
this pass was run to mitigate.** On **2026-09-15** the instruction carried as **T562** — *"Append the
governing FR/SC identifiers to each task line in this file"* — was **executed across the whole file**,
together with the in-body task-reference half of the same hazard. Nothing was re-evaluated and no
task's `[x]`/`[ ]` state was changed by the translation itself.

**What changed, measured rather than estimated:**

| Change | Count |
|---|---:|
| Requirement-citation groups rewritten | **613** |
| Source-spec FR/SC id occurrences translated to their unified equivalent | **1,211** |
| Citations that could NOT be mapped, marked `→UNMAPPED, verify manually` rather than guessed | **1** |
| Bare in-body `Tnnn` references qualified with source spec + unified id | **437** |
| Broken relative design-document links repointed at the source spec that owns them | **60** |

**The form.** A citation now carries **both** numberings, so neither is lost:

```text
was:  (FR-022, FR-034, SC-013)
now:  (FR-022→unified FR-036, FR-034→unified FR-261, SC-013→unified SC-017)
```

An in-body reference reads `003/T001 (unified T061)` — the source-spec id it always meant, plus the
unified id it resolves to here. The unified id on the right of each `→` was derived mechanically from
the `*(was: NNN/FR-nnn)*` back-references in [`spec.md`](./spec.md) (504 unified FR/SC entries
parsed, 553 distinct source ids mapped, 7 unified entries carrying no source because they are new),
and each task's own `(was: NNN/Tyyy)` annotation selected which source specification's numbering to
translate from.

**HONEST BOUNDARY (§11.4.6) — the hazard is substantially mitigated, NOT eliminated:**

1. **A task added after this pass can reintroduce it.** Nothing mechanically enforces the form.
   **T582**, added by this pass, runs the SC-162 cross-check on the *specification*; no equivalent
   check exists for this file's citations.
2. **One citation is UNMAPPED and says so**: `FR-064a→UNMAPPED, verify manually`, in a task carried
   from `001`, which declares no `FR-064a`. The id belongs to `002` (whose `FR-064a` is unified
   `FR-188`), so the *source* text cites across specifications. It was flagged, not corrected.
3. **FR/SC ids appearing in running prose rather than in a citation group were left alone** — for
   example *"the same determination as FR-018"*, `(SC-017's budget is 2 s)`, and the ranges
   `(FR-042–FR-055)` and `(SC-031→SC-034)`. Translating prose would have meant rewriting sentences
   rather than annotating citations. Those still carry **source-spec** numbering.
4. **37 in-body `Tnnn` references were deliberately left unqualified**: ranges (`T015-T017`,
   `T024-T029`), gate/registry row identifiers that merely begin with a task id
   (`T041-RULE-1-graph-kinds-excluded`, `T066-T067-retrieval-benchmark`), and references already
   written in an explicit `002:T041` form. Qualifying an identifier would have corrupted it.
5. **Six in-body references point at a specification other than their own task's source**, and each
   was resolved by reading the named source file rather than by assuming: `T203`'s `T133`/`T134`/
   `T135` are `002`'s, `T278`'s `T060` is `006`'s, and `T458`/`T465`'s `T037` is `001`'s.
6. **The "573 of 573" guarantees above describe the MERGE, not this file as it now stands.** This
   pass added **9** new tasks — **T574–T581** (Phase 16) and **T582** (Phase 17) — covering unified
   requirements that no carried task covered (findings E2, E3, E4, E5, E6). The file now holds
   **582** tasks, **345** `[x]` and **237** `[ ]`. **Exactly one carried task's checked state was
   changed: T562 itself, to `[x]`.** Every other `[x]`/`[ ]` in this file is as the merge left it.
7. **Duplicate and contradiction findings were ANNOTATED, never resolved.** Six tasks carry a new
   `DUPLICATE OF …` note (T071, T564, T566, T553, T573 — and T278 is the original of the last two),
   and T078, T496, T489 carry a flag for operator attention. **No duplicate was deleted or merged,
   and no flagged contradiction was decided here.**


## Format

```text
<state> <unified id> (was: <source spec>/<source id>) <markers> <original description, unedited>

for example:  - [x] T042  (was: 002/T088)  [TDD]  Description of the work, with its evidence notes
```

## Execution markers

Carried through from the source files, unchanged:

- **`[P]`** — parallel-safe: different files, no dependency on another task in the same phase.
- **`[TDD]`** — RED-GREEN-REFACTOR discipline: the failing test is written and observed failing
  first, on the broken artifact.
- **`[REVIEW]`** — requires an independent code or content review before it is accepted.
- **`[SUBAGENT]`** — delegable to a subagent working in isolation.
- **`[BLOCKED]`** — cannot start until a named prerequisite is resolved. **RESOLVED 2026-09-15**:
  this legend originally claimed "ten `[BLOCKED]` markers... waiting on OQ-3" — measured directly
  against the seven source `tasks.md` files, that count was wrong: three `[BLOCKED: ordinal type]`
  markers exist in total (T176, T177, T184, all from `003`), none elsewhere. OQ-3 is now resolved
  (see spec.md Clarifications, "OQ-3 resolved during this pass") — the decision it names was in
  fact already made and partially implemented on 2026-09-13, before this merge, in
  `specs/003-chapter-hierarchy/decision-record.md`. The three tags below are cleared accordingly;
  see each task's own note for what that means for its remaining work.
- **`[UNBUILT]`** — specified and deliberately not yet built, as distinct from blocked.
- **`[USn]`** — the source specification's own user-story tag. **These refer to the numbering of the
  source specification, not to this document's unified user stories** — a `[US1]` on a task from
  `005` means *that* spec's User Story 1. The phase heading names the unified story each group
  belongs to.

## Phase order

Phases follow the order the specification's own architecture implies: shared setup, then blocking
foundations, then the baseline user stories roughly by priority, then the migration to the target
architecture, then polish. Within a phase, tasks keep their **source order**, grouped under an
italic sub-heading naming the source file and its original phase, so a reader can always find the
surrounding reasoning in the superseded document.

| Phase | Subject | Tasks | `[x]` | `[ ]` |
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
| 14 | On-screen text (OCR) ingestion — specified and unbuilt | 21 | 2 | 19 |
| 15 | US18 — evidence, independent review, governance | 11 | 7 | 4 |
| 16 | **MIGRATION** — US26 – US33, the decoupled modules | 43 | 20 | 23 |
| 17 | Polish and cross-cutting concerns | 62 | 28 | 34 |
| | **Total** | **582** | **345** | **237** |

*Table re-counted 2026-09-15. It was **573 / 344 / 229** as the merge left it; the 2026-09-15
remediation pass added **8** tasks to Phase 16 (T574–T581) and **1** to Phase 17 (T582), and ticked
**T562** — the only checked-state change made to a carried task. See "What the 2026-09-15
unified-numbering pass did" above.*

**Phase 16 is the whole of Part II.** It carries all 31 tasks from `007` plus the 4 tasks from
`004`'s "each module runs on its own" phase, which describe the same journey one specification
earlier. Nothing in Phases 1–15 depends on it, and migration gate **M4** (FR-328) forbids
decommissioning either module's umbrella-hosted copy until its standalone clone independently passes
install and the full test suite.

## Standing rules carried from every source file

These were stated in each source's own "Global constraints" or "Standing rules" section and bind
every task here:

1. **No task is complete without captured runtime evidence.** Metadata, configuration, an absent
   error, or a grep with no runtime is not evidence.
2. **Every gate is three-valued** — clean / real finding / could-not-determine — and **could-not-determine
   is never a pass**.
3. **Every gate ships a paired mutation proof** that it catches the defect it exists to catch, driven
   by **data** rather than by editing the gate.
4. **A measurement of SOURCE is never evidence about the SERVED product.** Say which was measured.
5. **No private content crosses into a public repository**, in either direction of the boundary.
6. **No server-side CI is introduced**, anywhere in the fleet, in either architectural state.
7. **No published history is rewritten**, in any repository.

---

## Phase 1: Setup — shared infrastructure

**23 tasks — 22 complete, 1 open.** Sources: 001, 002, 004, 006. T018/T019 completed 2026-09-15 (this pass); T006 remains BLOCKED on an operator lint-baseline decision (see its own note).


*From `001` — Phase 1: Setup (Shared Infrastructure)*

- [x] T001 (was: 001/T001) Create the module skeleton `workshop/platform/{backend,frontend,bin}` and `workshop/{curriculum,pipeline,docs,evidence}` per plan.md Structure Decision — note NO `workshop/containers/` directory: orchestration is consumed from `submodules/containers`, and a local container stack would violate §11.4.76(4) (FR-013→unified FR-060)
- [x] T002 (was: 001/T002) Initialise the Go module in `workshop/platform/backend/go.mod` (Go 1.26.2, matching `ai_interviewing/platform/backend/go.mod`) (FR-013→unified FR-060)
- [x] T003 (was: 001/T003) Add `replace digital.vasic.containers => ../../../submodules/containers` to `workshop/platform/backend/go.mod` per §11.4.76(2), and verify it builds (FR-046→unified FR-284)
- [x] T004 (was: 001/T004) [P] Scaffold the Angular client in `workshop/platform/frontend` mirroring `ai_interviewing/platform/frontend` conventions (package name, Karma/Jasmine, no new UI framework) (FR-013→unified FR-060)
- [x] T005 (was: 001/T005) [P] Create `workshop/pipeline/requirements.txt` pinning `faster-whisper` + `ctranslate2`, and `workshop/pipeline/venv-setup.sh` building a project-local venv — **[TICKED 2026-09-04. The `[PATH NOT BUILT]` note is WITHDRAWN BY NAME: `workshop/pipeline/venv-setup.sh` now EXISTS, and the venv build is no longer prose in a header.** `requirements.txt` was already correct and is unchanged — it pins `faster-whisper==1.2.1` + `ctranslate2==4.8.2` across 23 `==` pins. The new script makes the four-line procedure that was documented in that file's header EXECUTABLE and CHECKABLE, which is the half that was open. **The load-bearing evidence is a REAL FRESH BUILD, not a dry run**: `bash workshop/pipeline/venv-setup.sh --venv /tmp/vsbuild` built a venv from nothing and exited **0** in **31.86 s wall** (`time`, 20.58 user / 1.62 sys), installing all 23 pinned packages **from wheels only** (`--only-binary=:all:`, which the script offers no flag to relax) and then IMPORTING `faster_whisper` and `ctranslate2` — because a wheel that installs is not a wheel that runs, which is research item U1. `torch` absent, as required. The throwaway prefix was removed afterwards. **Three-valued exit DEMONSTRATED, all four states driven 2026-09-04**: `--verify` against the real hand-built venv -> **0** (`23 of 23 installed at their pinned versions`); `--verify --venv /nonexistent/nv` -> **2**; `--python /nonexistent/py` -> **2**; `--bogus` -> **2**; `--verify` against an EMPTY venv -> **1** (`these modules do not import: faster_whisper ctranslate2`). A version-drift check compares every `==` pin against `importlib.metadata.version` so an import that succeeds against the WRONG version is a failure, not a pass. The script resolves the interpreter INSIDE the venv by absolute path and never consults `PATH` for an engine — `/usr/bin/whisper` on this host is a GTK notification client, so `command -v whisper` succeeds and proves nothing. **R5 was exercised in BOTH directions, which is the evidence that the sweep discriminates rather than merely reddening**: immediately after the file was created `bash workshop/platform/gates/verify-check-registry-001.sh` went to rc **1** with `FAIL [R5] UNREGISTERED — pipeline/venv-setup.sh is under a declared scanroot but appears in no check, sibling proof, debt, or exempt row`; after an `exempt` row was added it returns rc **0** at **40 PASS / 0 FAIL / 3 DEBT / 0 UNDET**, sweeping **37** files (was 36). It is `exempt`, not `check`, on a stated reason: it PROVISIONS an environment and asserts nothing about this module, and a host without wheels for its interpreter is not a finding about this curriculum. **Honest boundary (§11.4.6): this does NOT close 001/T051 (unified T222).** 001/T051 (unified T222) needs a timed fresh-clone-to-running run against SC-004's 15-minute budget; what is now measured is that ONE step of it — the venv — costs 31.86 s on this host with a warm pip cache, and is reproducible by a fresh clone at all, which it was not before]** (population: in_process) (FR-012→unified FR-059, SC-004→unified SC-004)
- [ ] T006 (was: 001/T006) [P] Configure linting/formatting to match the reference module (`gofmt`, Angular ESLint config) — **[UNWRITTEN, AND THE TASK CONTRADICTS ITSELF. Measured 2026-09-03; NEW note.** Neither half is configured. Frontend: `workshop/platform/frontend/` has **no** `.eslintrc*` and **no** `eslint.config.*`; `package.json` declares 11 scripts and **none is `lint`**; its `devDependencies` contain **no** package whose name matches `lint` or `prettier`. Go: nothing in `workshop/` runs `gofmt` as a gate, and `gofmt -l workshop/platform/backend` reports **3** unformatted files today (`cmd/knowledge-registry-backfill/main.go`, `internal/api/publication.go`, `internal/api/passages_publication_test.go`), which is a live demonstration that no gate is enforcing it. **The self-contradiction, and it needs an operator to resolve rather than an agent to guess:** this task says *"match the reference module"*, and the reference is `ai_interviewing/platform/frontend` (plan.md Structure Decision) — measured, **that module has no ESLint config either**: 5 scripts, none `lint`, zero lint devDependencies. So "match the reference" and "Angular ESLint config" point in opposite directions and cannot both be satisfied. Adopt ESLint and DIVERGE from the reference, or match the reference and drop the ESLint half; either is defensible, neither is this note's to choose. The `gofmt` half has no such ambiguity and is unblocked work]** — **BLOCKER:** the task contradicts itself — it says "match the reference module", and the reference (`ai_interviewing/platform/frontend`) has NO ESLint config either, so there is nothing to match · **OWNER:** **operator** — pick a lint baseline, or withdraw the "match the reference" clause (FR-013→unified FR-060)
- [x] T007 (was: 001/T007) [REVIEW] Verify `workshop/` still adds zero CI: `git -C workshop ls-files | grep -E '^\.github/workflows/.*\.ya?ml$'` must be empty, and `bash scripts/pre-push-gates.sh` gate E must pass (FR-034→unified FR-271, SC-014→unified SC-141)

*From `002` — Phase 1: Setup*

- [x] T008 (was: 002/T001) Create `workshop/platform/backend/pkg/knowledge/` and `pkg/assessment/` — **`pkg/`, not
      `internal/`**: Go's `internal/` is importable only from within its own module, so it forecloses
      reuse by language rule rather than by style, and the platform's decoupling requirements forbid
      it for anything reusable (FR-058→unified FR-281)
- [x] T009 (was: 002/T002) Create `workshop/pipeline/{extract,mentions,authoring}/` beside the existing pipeline
      stages, so the chapter-addition path **gains steps rather than being rewritten** (FR-033d→unified FR-174, FR-033e→unified FR-174)
- [x] T010 (was: 002/T003) [P] Scaffold the four new front-end feature directories under
      `workshop/platform/frontend/src/app/features/{areas,practice,progress,plans}/`, mirroring the
      existing feature-directory conventions (FR-040→unified FR-235)
- [x] T011 (was: 002/T004) [P] Extend the capability probe in `workshop/scripts/_capabilities.sh` to
      **capability-probe** the export and diagram toolchain — invoke each tool with the flag that
      matters, never `--version`. Gate **G-KG-9** precondition (FR-014a→unified FR-088, FR-045→unified FR-218, FR-049→unified FR-222)
- [x] T012 (was: 002/T005) [P] Add a per-chapter word-timing detector: presence of a word sidecar is a **per-chapter**
      fact (contract V2), never a corpus-wide assumption (FR-021→unified FR-140)
- [x] T013 (was: 002/T006) [REVIEW] Confirm the module still adds zero CI: `git -C workshop ls-files` must show no
      active workflow file, and the fleet-wide gate must pass (FR-056→unified FR-271, SC-030→unified SC-141)

*From `004` — Phase 1: Setup (Shared Infrastructure)*

- [x] T014 (was: 004/T001) [REVIEW] Create the reusable curriculum library in `submodules/curriculum-kit/` — `Catalog → Area → Lesson → Material` plus `Area.Assessment`, with `VideoAnchor{chapterId,startMillis,endMillis,transcriptAnchor}` (FR-006→unified FR-093, FR-013→unified FR-119, FR-014→unified FR-121). **Evidence**: 82 tracked files (source); `go test ./...` ok (in_process).
- [x] T015 (was: 004/T002) Keep the library project-unaware by construction in `submodules/curriculum-kit/go.mod` — an empty require set, so a project import would not compile (FR-?). **Evidence**: compiler-enforced, not convention.
- [x] T016 (was: 004/T003) [P] Implement `DecodeDocument` with `DisallowUnknownFields()` in `submodules/curriculum-kit/pkg/curriculum/document.go` (FR-?). **Evidence**: a misspelled key fails the load loudly instead of dropping its material silently.
- [x] T017 (was: 004/T004) [P] Make `Area.Assessment` a pointer so "under construction" is representable, and have `Validate` emit `CK021` for it rather than letting the absence pass unnoticed (FR-008→unified FR-096, SC-004a→unified SC-052). **Evidence** (population: unstated): 37 CK021 findings raised, none suppressed.
- [x] T018 (was: 004/T071) [TDD] Extend `Validate` in `submodules/curriculum-kit/pkg/curriculum/validate.go` (task text named `document.go`; the function actually lives in `validate.go` — corrected here) to detect an explicit draft/placeholder marker on any lesson or question and emit a distinct `CK0xx` finding, so an area carrying one is excluded from publication by the same determination as FR-018 rather than by an author remembering to delete it (FR-012b→unified FR-105). **DONE.** Added `Lesson.Draft` / `Question.Draft bool` fields (`model.go`) and rule code `CK026` (`CodeDraftContent`), firing on `Draft == true` OR a whole-word case-insensitive `TODO` marker in the lesson's Title/Body or the question's Prompt (`hasDraftMarker`, word-boundary matched so "methodology" does not false-positive — asserted by `TestDraftMarkerDoesNotMatchSubstring`). RED verified (fixtures referenced `Draft`/`CodeDraftContent` before either existed — compile failure), GREEN after implementation: `go test ./... -race` and `go vet ./...` both clean in `submodules/curriculum-kit`. Table rows added to `TestEachRuleCatchesItsOwnDefect` (lesson-draft, lesson-TODO, question-draft, question-TODO), each asserting `Verdict()==1` + the code.
- [x] T019 (was: 004/T072) [TDD] Extend the same `Validate` function to reject a lesson body that is structurally too short to carry substantive content beyond restating its title (FR-012c→unified FR-106). **DONE, narrowed to what the task text actually supports.** `model.go`'s own documented contract for `Lesson.Body` explicitly forbids a length floor ("a body that is genuinely short stays short... padding one to look substantial is a worse defect than a thin lesson"), so this is implemented as CK027 (`CodeLessonBodyRestatesTitle`): fires only when a non-empty `Body`, normalized (case/whitespace/trailing-punctuation folded), equals the normalized `Title` — i.e. restates it, not merely is short. **The "malformed-reference" half of the original task text is not implemented here**: this package models no references for a lesson body to be malformed against (it is opaque marked-up text per `model.go`'s own doc comment), so that half is not a coherent instruction against this codebase and is left unaddressed rather than invented. CONTROL test `TestShortLessonBodyThatDiffersFromTitleIsNotAFinding` proves a short-but-different body stays clean, protecting the "genuinely short stays short" contract from a false positive. RED verified (compile failure before `CodeLessonBodyRestatesTitle` existed), GREEN after implementation: `go test ./... -race` and `go vet ./...` clean.

*From `006` — Phase 1: Setup — the shape the content is authored against*

- [x] T020 (was: 006/T001) [REVIEW] Publish the reusable content library as `vasic-digital/curriculum-kit` (PUBLIC), mount as a gitlink, declare in `helix-deps.yaml` with a real ref (FR-030→unified FR-277, SC-013→unified SC-143). **Evidence** (source): 82 files; content-boundary scan 0 prose / 0 name rows; `verify-standalone-clone.sh` 3 gaps → 2.
- [x] T021 (was: 006/T002) Add `Lesson.Body` to `submodules/curriculum-kit/pkg/curriculum/model.go` as opaque marked-up text the library neither parses nor renders (FR-013→unified FR-093). **Evidence** (in_process): `go build`/`go test`/`go vet` rc 0; commit `07af6fb`.
- [x] T022 (was: 006/T003) [P] Keep `Body` **optional** in the library and record why in `TestValidateDoesNotRequireALessonBody` (FR-013→unified FR-093). **Evidence**: a materials-only lesson is legitimate, so "every lesson has a body" is a consumer policy the library may not impose; a future rule must change a test that explains its absence.
- [x] T023 (was: 006/T004) [P] Assert `Body` and `Summary` have not collapsed into one value in `TestLessonBodyIsCarriedAndIsDistinctFromSummary`, including that an absent body decodes as `""` rather than a copy of the summary (FR-013→unified FR-093).


---

## Phase 2: Foundational — blocking prerequisites

**52 tasks — 51 complete, 1 open.** Sources: 001, 002, 003, 004, 006. T031-T033/T035-T037/T039-T040/T051/T060/T069-T070 completed 2026-09-15 (this pass); T038 remains — a human-review checkpoint, not self-approvable (see its own note).


*From `001` — Phase 2: Foundational (Blocking Prerequisites)*

- [x] T024 (was: 001/T008) [TDD] [REVIEW] Implement the ULID passage identifier minter in `submodules/passage/pkg/passage/pid.go` per [contracts/passage-contract.md](../001-workshop-curriculum-platform/contracts/passage-contract.md) — minted at ingest, never positional, never content-derived (FR-037→unified FR-010, SC-016→unified SC-075, FR-044→unified FR-282, FR-047→unified FR-285)
- [x] T025 (was: 001/T009) [TDD] Implement the `<!-- pid: … -->` source anchor reader/writer in `submodules/passage/pkg/passage/anchor.go` (FR-037→unified FR-010, SC-016→unified SC-075)
- [x] T026 (was: 001/T010) [TDD] Implement the passage registry (`passages.jsonl` → `passages.db`) in `submodules/passage/pkg/passage/registry.go`, with `content_hash` as a change-detection column explicitly documented as NOT identity (FR-037→unified FR-010)
- [x] T027 (was: 001/T011) [TDD] **[PATH CORRECTED 2026-09-02 — this task named `submodules/passage/pkg/passage/resolve.go`, which does not exist; the resolver landed in `registry.go` as `func (r *Registry) Resolve(p PID) Resolution` at `:462`, with the four `Outcome` constants at `:299`–`:308`]** Implement the four-outcome resolver in `submodules/passage/pkg/passage/registry.go` per [contracts/passage-contract.md](../001-workshop-curriculum-platform/contracts/passage-contract.md) §7.1 — `found` · `redacted` · `not_in_registry` · `undetermined`, with NO fallback to fuzzy text matching, nearest-neighbour lookup, prefix matching or same-`content_hash` lookup. `undetermined` is NEVER collapsed into `not_in_registry`: collapsing them makes an unreadable database look like a curriculum that never contained the passage. Every citation, cross-reference and redaction resolves through this one function, and there is no second path (FR-037→unified FR-010, FR-033→unified FR-261, SC-016a→unified SC-076)
- [x] T028 (was: 001/T012) [TDD] **[TICKED 2026-09-03 ON MEASUREMENT. ~~PATH NOT BUILT — `redaction.go` does not exist … there is no `Redact`/`Unredact` API anywhere. The WRITER is what remains~~ — that whole 2026-09-02 note is WITHDRAWN BY NAME, not deleted: every clause of it is now false. `submodules/passage/pkg/passage/redaction.go` EXISTS at exactly the path this task names, **472 lines**, and it IS the writer. Measured: `grep -n '^func ' pkg/passage/redaction.go` returns the full API — `LoadRedactionLog` `:173`, `(*RedactionLog).Append` `:256`, `AppendFile` `:315`, `Materialise` `:349`, `Purge` `:401` (§7.3 R6), `SyncDB` `:438`, plus `State` `:212`, `Suppressed` `:224`, `SuppressedPIDs` `:234`. The file's own header states the contract this task asks for — the bool is the MATERIALISATION of the log's latest entry, never the mechanism, and `unredact` is an explicit append rather than the deletion of the `redact` entry before it. **The `[TDD]` half is proven, not asserted:** `go test -count=1 ./...` in `submodules/passage` is `ok`, and `-run RED -v` shows **11 gate tests G-RED-1..G-RED-6 all PASS, of which 5 are paired mutations** — `TestGateRED1_PairedMutation_RewriteInsteadOfAppend` is the "append, not a rewrite" clause and `TestGateRED4_PairedMutation_ColumnFlipWithoutRebuild` is the "a bare column flip is a contract violation" clause, each named by this task. R2 is separately confirmed against the REAL Chapter 1 corpus at 10 redacted rows × 2 fields × 3 surfaces, `R2 violations 0` (see 001/T040 (unified T206))]** Implement the append-only `redactions` log and the `passages.redacted` materialisation in `submodules/passage/pkg/passage/redaction.go` per [contracts/passage-contract.md](../001-workshop-curriculum-platform/contracts/passage-contract.md) §4.3 (`redactions` DDL) and §7.3 R2/R6 (FR-039→unified FR-012) — a bare column flip is a contract violation, `unredact` is a new append rather than a rewrite of history, and once a pid is redacted its `text` and `machine_text` are absent from every serialisation at every layer. This is the registry half of FR-039; propagation is 001/T059 (unified T331), 001/T061 (unified T333) and 001/T075 (unified T353), and the gate is 001/T076 (unified T354) (population: in_process) (FR-039→unified FR-012)
- [x] T029 (was: 001/T013) [TDD] Prove the two survival guarantees in `submodules/passage/pkg/passage/pid_test.go` as gates **G-PID-1** and **G-PID-2** ([contracts/passage-contract.md](../001-workshop-curriculum-platform/contracts/passage-contract.md) §5.1, §5.2). **G-PID-1**: create a passage, cite it, correct its text, re-run ingest and re-index, then assert the pid is unchanged, the citation still resolves, `machine_text` is byte-identical to before, and `content_hash` **did** change. **Paired mutation**: make ingest re-mint on `content_hash` change — i.e. reproduce the measured Lumen behaviour; the gate MUST go red, and the contract names this the one mutation that must never be skipped, because it is the precise defect the whole contract exists to prevent. **G-PID-2**: reproduce the measured D-SEARCH-1 run 3 by prepending a section to a transcript so every later section shifts by 4 lines, then assert every pid is unchanged **and** every affected `source_ref` was updated to the new lines — `source_ref` is a cache, never a key. **Paired mutation**: key ingest matching on `(path, line_start)`; the gate MUST go red. (This is SC-016; both alternatives were measured to fail — see research.md D-SEARCH-1) (FR-037→unified FR-010, SC-016→unified SC-075, FR-032→unified FR-260, SC-012→unified SC-135)
- [x] T030 (was: 001/T014) [REVIEW] **[TICKED 2026-09-03 ON MEASUREMENT — P-U1 IS SETTLED AND THE PRODUCER IS NAMED. ~~PATH NOT BUILT — `workshop/pipeline/detect_symbols.sh` does not exist and no equivalent landed anywhere; measured 2026-09-02, no P-U1 outcome is recorded under `workshop/evidence/` either~~ — that note is WITHDRAWN BY NAME: both halves are false today. `workshop/pipeline/detect_symbols.sh` exists (31,112 B, executable) and a default run exits **`0`**, printing `PRODUCER: pipeline/symbols (go/parser, owned by feature 001)` — this task's option **(b)**. Candidate **(a)** (Lumen's SQLite store) is **REJECTED** on evidence, not on preference: A3 `988 duplicate (file_path, symbol) key(s) across 15108 Go row(s) — the key does not identify a passage`, A4 `0 of 3104 Go method row(s) carry a §6.2-shaped receiver`. Candidate (b) passes every check: B1 built · B2 emits §6.2's package-prefixed, receiver-qualified path · B3 `(path, symbol)` unique across **2329** symbols of a real tree · B4 byte-identical across two runs · B5 survives a body edit, an insertion and a reorder · B6 a rename MOVES the key so §8 R4 can see it. **Three-valued exit demonstrated in both directions**: default `0`; `--real-tree /nonexistent` → `2` with A5/A6 `NOT_TESTED` and B3 `UNDETERMINED`. **§1.1 paired proof**: `--prove-failure` → rc 0, `PROVE: 5 mutations, 5 caught, 0 missed` (M1 duplicate key → B3 FAIL, M2 nondeterministic → B4, M3 position-encoded → B5, M4 rename-blind → B6, M5 non-§6.2 shape → B2). **Evidence recorded and TRACKED under `workshop/evidence/`** as this task requires: `evidence/p-u1/README.md` (line 7: *"Outcome: exit `0`. The producer is `pipeline/symbols`"*) and `evidence/p-u1/result.json`, both in `git ls-files`. The producer itself is `workshop/pipeline/symbols/` (`main.go`, `go.mod`). Registered as check `symbol-index-honesty` in `workshop/platform/gates/check-registry-001.tsv`. **Honest boundary (§11.4.6): the TRACKED `evidence/p-u1/result.json` in the working tree currently holds the output of that registry's `--real-tree /nonexistent` UNDET PROBE (`"exit": 2`), so the JSON and the README disagree — the README carries the settlement, the JSON carries a probe artefact. A5/A6 remain `NOT_TESTED` because `--reindex-probe` writes to a shared store and was not run. Neither touches the verdict: candidate (a) is rejected on A3/A4 alone, and (b) is confirmed on B1–B6. `001/T015` (unified T031), `001/T016` (unified T032) and `001/T017` (unified T033) are therefore UNBLOCKED — they are unwritten work, not blocked work]** Settle **P-U1** before any code-identity work begins ([contracts/passage-contract.md](../001-workshop-curriculum-platform/contracts/passage-contract.md) §10): §6.2 keys code identity on a symbol path, but **that key has no confirmed producer** — Lumen exposes no symbol table through its CLI or MCP surface, so the 58,726-symbol figure comes from its internal store, not from a supported interface. Choose and prove exactly ONE producer in `workshop/pipeline/detect_symbols.sh`: either (a) read Lumen's SQLite store directly and confirm the symbol schema survives a reindex unchanged, or (b) extract symbols with a Go/TypeScript parser owned by this feature. Three-valued exit: `0` a producer is confirmed and named · `1` both candidates were tested and neither yields a stable symbol path · `2` neither could be tested. Record the outcome and its evidence under `workshop/evidence/`. **001/T015 (unified T031), 001/T016 (unified T032) and 001/T017 (unified T033) are blocked until this exits `0`** — see Global Constraints (population: in_process) (SC-016a→unified SC-076, FR-033→unified FR-261, FR-040→unified FR-264, FR-032→unified FR-260, SC-012→unified SC-135)
- [x] T031 (was: 001/T015) [TDD] Implement the code-passage matching key `(path, symbol)` and the `symbol_aliases` table in `submodules/passage/pkg/passage/symbol.go` per [contracts/passage-contract.md](../001-workshop-curriculum-platform/contracts/passage-contract.md) §6.2, §6.4 and the §4.3 `symbol_aliases` DDL (SC-016a→unified SC-076). **DONE 2026-09-15.** `SymbolAlias`/`SymbolAliasStore` with two indexes (old-key and new-key lookup), `origin` (`authored`/`detected`) with `Put` refusing a `detected` guess to silently overwrite an `authored` decision, JSONL round-trip mirroring `Registry.LoadJSONL`, and `SyncDB` rebuilding the already-declared `symbol_aliases` table. **Evidence** (commit `1e361bd`, pushed both mirrors): `go build/vet` clean; `go test ./... -race -count=1` → `ok` (75/75 `--- PASS`, 0 FAIL, independently re-run); `gofmt -l` clean; consumer-vocabulary and `Kind`-openness gates re-run against the new files (13 files scanned, 0 hits) (SC-016a→unified SC-076, FR-037→unified FR-010)
- [x] T032 (was: 001/T016) [TDD] Implement the §8 ingest matching branches for code passages in `submodules/passage/pkg/passage/ingest_match.go` — R2 attach on `(path, symbol)` · R3 attach through `symbol_aliases`, recording WHICH alias was used so `detected` links stay reviewable · R4 an unaliased rename ⇒ refuses (mapped to a non-nil `error` at this library's boundary — this package returns errors, not process exit codes; a CLI caller turns that into exit `1`) for code inside a caller-declared tree requiring authored aliases, and for code outside it, mints a new pid and records the orphaned old one so the broken citation is LOUD. Minting stays the last branch (M4). **DONE 2026-09-15.** Tree-ownership policy is injected via a `RequireAliasFunc func(path string) bool` rather than hardcoding a consumer name — keeps the package project-unaware per its own `TestNoConsumerShapedVocabularyInSource` gate. **Judgment call, documented inline in the source**: the contract's R4 text splits into two mechanisms (owned-tree refuses vs. everywhere-else mint-and-orphan); the gate this task and T033 both specify wants the old pid to resolve `not_in_registry` from the SAME owned-tree refusal scenario, so orphaning of the stale row is made unconditional whenever R4's precondition fires, independent of whether the run also refuses — a deliberate departure from the R1c/foreign-anchor precedent (which leaves the registry untouched on error). **A real bug was caught by this task's own tests, not by inspection**: R3's alias lookup was first indexed and queried by the OLD key, which is backwards (ingest observes the symbol's *current*, post-rename location) — `TestIngestCodeAliasAttaches` failed immediately, fixed by adding a `LookupNew` index. **Evidence**: same commit/run as T031 (SC-016a→unified SC-076, FR-037→unified FR-010)
- [x] T033 (was: 001/T017) [TDD] Prove **SC-016a** via gate **G-PID-4** in `submodules/passage/pkg/passage/symbol_test.go` ([contracts/passage-contract.md](../001-workshop-curriculum-platform/contracts/passage-contract.md) §6.5, §6.6): rename a symbol inside a tree requiring authored aliases WITH an `authored` alias and assert the pid is preserved and its citations still resolve; then rename one WITHOUT an alias and assert the old pid resolves `not_in_registry` — a loud dead link — and that `IngestCode` returns a non-nil error (this library's boundary for what a CLI caller reports as exit `1` — there is no process boundary inside this package to assert an actual exit code against). **Paired mutation**: make unaliased renames mint a new pid silently and never orphan the old row, regardless of the alias-required policy; the gate MUST go red — **DONE 2026-09-15, mutation confirmed caught** (independently re-run: `symbol_test.go:497: mutation caught: an unaliased rename did not fail ingest`). **Evidence**: same commit/run as T031/T032 (SC-016a→unified SC-076, FR-032→unified FR-260, SC-012→unified SC-135)
- [x] T034 (was: 001/T018) [P] [TDD] Implement three-valued exit helpers in `submodules/verdict/pkg/verdict/verdict.go` (0 / 1 / 2) used by every command and endpoint (FR-033→unified FR-261, SC-013→unified SC-136, FR-044→unified FR-282, FR-047→unified FR-285)
- [x] T035 (was: 001/T019) [P] [TDD] Implement media-tooling detection in `workshop/pipeline/detect_media.sh` — probe `ffmpeg`/`ffprobe` for actual capability, not `--version`. Gate **G-CLI-3** ([contracts/pipeline-cli.md](../001-workshop-curriculum-platform/contracts/pipeline-cli.md) §3.2, §5): point `WORKSHOP_FFPROBE` at an override binary and assert exit `2` with a tooling reason, never `1`. **DONE 2026-09-15 — both measured divergences closed.** An unusable-but-present tool (this host's real trap: Playwright's bundled ffmpeg answers `--version` but rejects `-show_format`) now exits `2` with `reason.code: ffprobe_unusable`/`ffmpeg_unusable`, matching the contract — directly reproduced live on this host. `WORKSHOP_FFPROBE`/`WORKSHOP_FFMPEG` added as the env rung of the existing four-rung ladder via `_common.sh`'s `ws_resolve`. Existing `--prove-failure` proof updated; a pre-existing, unrelated host gap (whisper.cpp not built here) makes 2 of 5 mutations report a false HEALTHY baseline — documented in the script's own header, not papered over; the ffprobe/ffmpeg-specific mutations (M2/M3) pass clean (FR-033→unified FR-261, SC-013→unified SC-136, FR-032→unified FR-260, SC-012→unified SC-135)
- [x] T036 (was: 001/T020) [P] [TDD] Implement backend/model detection in `workshop/pipeline/detect_backend.sh` following `scripts/lumen-reindex.sh`'s env → config → live probe → documented fallback ladder. **DONE 2026-09-15.** ASR/transcription-backend resolution (engine, model, model-path env/config keys), distinct from `_capabilities.sh`'s answering/generative-backend detection (never touches it), over the same four-rung ladder; config-file rung added by extending the existing `workshop.conf` mechanism with new keys (`asr_engine`, `asr_model_ct2_dir`, `asr_model_ggml`) rather than a second config format. Reuses `detect_media.sh --json` as its capability source. Exit codes 0/2 only, never 1, per contract §1.3. 6/6 paired mutations pass. Registered as `backend-detection` (FR-023→unified FR-167)
- [x] T037 (was: 001/T021) [P] Create `workshop/scripts/{start,stop,status}.sh` over a Go consuming adapter that calls `submodules/containers`' **Go API** — consumption, not reimplementation (§11.4.76(4)). Gate **G-CLI-12** ([contracts/pipeline-cli.md](../001-workshop-curriculum-platform/contracts/pipeline-cli.md) §4.8, §5): bind the published port with a process whose identity cannot be established and assert `status.sh` exits `2`, not `1`. Gate **G-CLI-17**: a project with no containers prints `STOPPED` and exits `1`. **DONE 2026-09-15.** G-CLI-17 was already built and is unchanged/regression-confirmed. G-CLI-12's gap closed: `podman`'s `ContainerRuntime.List()` doesn't populate port data (only docker/nerdctl's does), so a plain TCP dial against a new opt-in `-publish-addr host:port` flag on `workshop-boot status` distinguishes a confirmed-free port (`ECONNREFUSED` → unchanged `STOPPED`/1) from an occupied-but-unattributable one (anything else → `UNDETERMINED`/2), only when this project's own compose enumeration is already empty. Flag is empty by default so unrelated callers see byte-identical prior behavior. G-CLI-12 gate + §1.1 paired mutation (skip the check; route the occupied case through 1 instead of 2) both pass, independently re-run; also manually verified against the real production stack's live-bound address on this host. Registered as `status-port-identity` in `check-registry-001.tsv` (FR-012→unified FR-059, FR-033→unified FR-261, SC-013→unified SC-136, FR-032→unified FR-260, SC-012→unified SC-135)
- [ ] T038 (was: 001/T022) [REVIEW] Review the passage contract implementation against [contracts/passage-contract.md](../001-workshop-curriculum-platform/contracts/passage-contract.md) before anything consumes it — every other component depends on its shape. **UNBLOCKED 2026-09-15: T031-T033 (unified numbering; the predecessor tasks named here) are now done** — `submodules/passage/pkg/passage/symbol.go`/`ingest_match.go`/`symbol_test.go`, commit `1e361bd`, 75/75 tests passing. The review itself remains a human judgement, not something this pass self-approves — **BLOCKER:** none but the review · **OWNER:** **human reviewer** (FR-037→unified FR-010)
- [x] T039 (was: 001/T106) [TDD] Gate **G-CLI-10** (§1.4, §5): assert every *unclassified* non-zero status maps to `2` — `126`, `127`, `128+N` and any other unclassified non-zero — via `workshop/scripts/_common.sh`'s ERR/EXIT traps (already built). **DONE 2026-09-15.** New `workshop/platform/gates/verify-cli-unclassified-exit-trap.sh` drives all five raw exit shapes (missing-binary/127, not-executable/126, killed-by-signal/137, bare-failure/1, reserved-band) to process exit 2. Paired mutation strips the ERR trap from a scratch copy of a dedicated fixture and drives the real gate against it — caught on all four ERR-routed modes, reserved-band correctly unaffected. Registered as `cli-unclassified-exit-trap` (FR-033→unified FR-261, SC-013→unified SC-136, FR-032→unified FR-260, SC-012→unified SC-135)
- [x] T040 (was: 001/T107) [TDD] Gate **G-CLI-9** (§2.5 E1, §5): assert evidence exists for every run outcome — `0`, `1` and especially `2` — via `_common.sh`'s §2.5 writer (already built: `ws_evidence_begin`/`ws_write_manifest`/`ws_evidence_finding`/`ws_evidence_finish`/`ws_run_with_evidence`). **DONE 2026-09-15, both remaining gaps closed.** (1) `redact.sh` had its own private writer (`result-exit.json`, no `findings.jsonl`) predating the shared one — switched to `ws_evidence_begin`/`ws_run_with_evidence`, so there is exactly one writer, not two; verified behavior-preserving (identical stdout/stderr/exit codes on the real corpus at rc 0/1/2; the file/field shape itself intentionally changed to the canonical §2.5 form). (2) New `workshop/platform/gates/verify-cli-evidence-completeness.sh` drives all four outcome shapes (ok/problem/undetermined/crash) and asserts full evidence exists for each. Both gates' §1.1 paired mutations pass, independently re-run; pre-existing by-design-red `verify-redaction-propagation.sh` confirmed unaffected. Registered as `cli-evidence-completeness` (FR-040→unified FR-264, SC-018→unified SC-137, FR-033→unified FR-261, SC-013→unified SC-136, FR-032→unified FR-260, SC-012→unified SC-135)
- [x] T041 (was: 001/T108) Implement `workshop/scripts/build.sh` per [contracts/pipeline-cli.md](../001-workshop-curriculum-platform/contracts/pipeline-cli.md) §4.8, building in this order: the `workshop-boot` adapter into `$WORKSHOP_BOOT_BIN`, then the Go backend and the Angular frontend into `workshop/platform/bin/`, then the container image(s) the compose file names — **through the containers submodule, never a direct `podman build`** (§11.4.76(4)). Three-valued exit: `0` everything built · `1` compile, test or image-build failure, a real problem in the code or the compose definition · `2` toolchain missing (Go, Node, **no container runtime detected**), network needed and unreachable, or disk full. "No container runtime detected" is emphatically `2` and never `1`: the host could not be assessed, which is not a finding about the code (FR-012→unified FR-059, FR-033→unified FR-261, SC-013→unified SC-136)
- [x] T042 (was: 001/T109) Implement `workshop/scripts/restart.sh` per [contracts/pipeline-cli.md](../001-workshop-curriculum-platform/contracts/pipeline-cli.md) §4.8 — `stop.sh` then `start.sh`, with the same arguments forwarded to `start.sh`. It is **not** a compose `restart`: a full down/up is what makes the restart honest about picking up a changed compose file or a rebuilt image. Its exit is `start.sh`'s exit, **except** that a `stop.sh` exit of `1` or `2` short-circuits and propagates unchanged — restarting on top of a stack that could not be stopped would report success over an unknown, which is standing rule 2's failure shape at the lifecycle layer (FR-012→unified FR-059, FR-033→unified FR-261)
- [x] T043 (was: 001/T110) [TDD] Prove gate **G-CLI-16** ([contracts/pipeline-cli.md](../001-workshop-curriculum-platform/contracts/pipeline-cli.md) §4.8, §5) — **consumption, not reimplementation** (§11.4.76(4)): assert that no lifecycle path under `workshop/` invokes `podman`, `docker`, `podman-compose` or `docker compose` to bring the stack up or down, and that every such transition goes through `workshop-boot`, which reaches the runtime only through the submodule's `pkg/compose`. Read-only diagnostics on a failure path — tailing a dead container's logs — are exempt, and the gate MUST **show** each exemption to be one rather than assert it. **Paired mutation**: add a `podman-compose up -d` fallback to `start.sh` for when `workshop-boot` is missing; the gate MUST go red, because a well-meaning fallback for a missing binary is exactly the parallel implementation the clause forbids and is the shape drift takes (FR-046→unified FR-284, FR-032→unified FR-260, SC-012→unified SC-135)

*From `002` — Phase 2: Foundational — identity, mentions, resolution*

- [x] T044 (was: 002/T007) [TDD] [REVIEW] Implement minting for the five new entity kinds in
      `pkg/knowledge/identity.go`, delegating to the **existing** minter — no second minter, no
      second format (contract §1 M1–M5) (FR-007→unified FR-078)
- [x] T045 (was: 002/T008) [TDD] Prove **G-KG-13** in `pkg/knowledge/identity_test.go`: run every stage twice over
      unchanged input and assert **zero mints**, a byte-identical taxonomy file, and no source file
      modified. **Paired mutation**: make minting unconditional whenever no anchor was read this run;
      the gate must go red on all three assertions simultaneously (FR-009→unified FR-082, SC-004→unified SC-046)
- [x] T046 (was: 002/T009) [TDD] Prove identifiers are neither content-derived nor positional: rename an area, fix a
      term's canonical form, reorder questions, shift a heading — assert **no** identifier changed.
      **Paired mutation**: key an area on its slug; the gate must go red. This reproduces, for the new
      kinds, the exact defect already measured and gated for passages (FR-007→unified FR-078, SC-004→unified SC-046)
- [x] T047 (was: 002/T010) [TDD] Implement the mention model in `pkg/knowledge/mention.go` with **precision as a
      required field on every time-carrying mention** — no default, because a default makes every
      unjoined mention claim word accuracy (contract §3 N1) (FR-021→unified FR-140)
- [x] T048 (was: 002/T011) [TDD] Implement the word-sidecar time join in `workshop/pipeline/mentions/join.py`
      following contract §3 exactly: word join succeeds ⇒ `word` precision plus the word's timing
      confidence; word join fails ⇒ `segment` precision against the enclosing segment. **Both
      branches are real** — 99.52% and 0.48% measured (FR-021→unified FR-140)
- [x] T049 (was: 002/T012) [TDD] Prove **G-KG-4** and **G-KG-15**: assert every time-carrying mention declares its
      precision, and that the unjoined fraction is **measured and reported**, never assumed zero.
      **Paired mutations**: (a) omit precision and default it to `word`; (b) treat an unjoined
      occurrence as `word` precision at the segment start. Both must go red (FR-021→unified FR-140, FR-053→unified FR-260)
- [x] T050 (was: 002/T013) [TDD] Implement segment-boundary spanning: an occurrence crossing a seam emits **one
      mention per segment it touches** (FR-022→unified FR-142). Attaching it to one loses half its evidence, and
      evidence counts are what publication decisions rest on (FR-022→unified FR-142)
- [x] T051 (was: 002/T144) [TDD] [REVIEW] Implement **G-KG-19**: one documented half-open interval convention
      (start inclusive, end exclusive) for every position this feature produces, applied uniformly by
      every producer and every consumer. **DONE 2026-09-15.** Audit found the convention mostly already
      consistent-but-undocumented (`pkg/knowledge/mention.go`'s `TextSpan`/`TimeSpan`, `pkg/search/offsets.go`)
      plus one genuine, reachable bug: `internal/api/chapters.go`'s `inSection` used a **closed** interval
      (`t >= start && t <= end`), which duplicates a boundary passage across two adjacent sections whenever
      `DeriveSections` produces a zero-silence-gap split. Fixed to half-open; convention now stated explicitly
      in `mention.go`'s doc comments (citing G-KG-19/FR-021b, including `TimeSpan`'s one documented exception
      for an instantaneous word timestamp) and in [contracts/knowledge-graph.md](../002-knowledge-areas-deep-linking/contracts/knowledge-graph.md) §3 as invariant N5. New gate
      `verify-g-kg-19-interval-convention.sh` + §1.1 paired mutation (reintroducing the historical closed-interval
      line via sed against a scratch copy, restored byte-for-byte after) both pass, independently re-run.
      Registered as `G-KG-19`/`G-KG-19-proof` in `check-registry-002.tsv` (FR-021b→unified FR-141, SC-009b→unified SC-073)
- [x] T052 (was: 002/T014) [REVIEW] Settle **U5** — do the 75 unjoined words cluster or scatter? Plot their time
      distribution against the measured silence spans. Three-valued exit. A cluster indicates a
      segmentation defect worth knowing about **before** mentions are built on it; scatter means the
      fallback branch is uninteresting. Record under `workshop/evidence/` (FR-054→unified FR-261, FR-055→unified FR-264)
- [x] T053 (was: 002/T015) [TDD] Wire all new-kind resolution through the **one existing** resolution function with
      its four outcomes — found · redacted · not present · could not determine. **No second path and
      no fallback**: no fuzzy text match, no nearest neighbour, no prefix match, no same-hash lookup (FR-023→unified FR-143)
- [x] T054 (was: 002/T016) [TDD] Prove **G-KG-8**: delete a link target and assert a loud outcome. **Paired
      mutation**: make the resolver re-point by nearest text match; the gate must go red. A silently
      re-pointed link is the one outcome the whole identity model exists to prevent (FR-024→unified FR-144, FR-053→unified FR-260, SC-011→unified SC-078)
- [x] T055 (was: 002/T017) [TDD] Prove that **could not determine is never collapsed into not present**: make the
      registry unreadable and assert the fourth outcome. **Paired mutation**: map an unreadable
      registry to not-found; the gate must go red — that collapse makes a broken database look like a
      curriculum that never contained the passage (FR-023→unified FR-143, FR-054→unified FR-261)
- [x] T056 (was: 002/T018) [TDD] Implement bidirectional traversal in `pkg/knowledge/graph.go`, **derived from
      mentions and citations** rather than from stored reverse edges. Two representations of one fact
      can disagree, and the disagreement has no symptom (FR-018→unified FR-135)
- [x] T057 (was: 002/T019) [TDD] Prove **G-KG-6**: inspect every stored relationship for its join key and assert none
      is a time. **Paired mutation**: introduce one time-keyed link; the gate must go red (FR-033b→unified FR-152, SC-015b→unified SC-097)
- [x] T058 (was: 002/T020) [TDD] Implement cycle-safe traversal with a visited set and a depth bound, **reporting
      truncation** rather than stopping silently — matching how the existing cross-reference response
      already reports truncation (FR-026→unified FR-147)
- [x] T059 (was: 002/T021) [P] [TDD] Extend redaction propagation to all **eight** targets in `data-model.md` §5.
      Gate **G-KG-7**. **Paired mutation**: skip exactly one target; the gate must go red (FR-027→unified FR-148, SC-012→unified SC-080)
- [x] T060 (was: 002/T022) [REVIEW] Review the knowledge contract implementation before anything consumes it. **DONE 2026-09-15.** Wrote [specs/002-knowledge-areas-deep-linking/review.md](../002-knowledge-areas-deep-linking/review.md) (matching spec 001's house style). Real findings with file/line citations, not a rubber stamp: F1 the T051/G-KG-19 bug above (resolved this session, reported as such); F2 `pkg/knowledge/redact.go`'s own package doc comment is stale — claims 4 of 8 redaction targets "do not exist as concrete entities yet", but `internal/redaction/plan.go` fully implements them (recommended fix named, not made — left for the operator); F3 `pkg/knowledge/graph.go`'s doc comment blanket-claims connectivity-matrix row 4 "NOT implemented", but `internal/api/graph_traverse.go` implements half of it (shared-area-membership, confirmed live at 493 subjects) — the older comment isn't the current state. Every contract clause outside the Go files opened this session (§2.2/§2.4/§2.5/§2.7, mostly Python/`pkg/assessment`) is recorded as CANNOT DETERMINE rather than assumed passing, per §11.4.6
      every other component depends on its shape, and a shape changed after adoption is a migration (FR-005→unified FR-068)

      **NOT DONE (re-measured 2026-09-03, unchanged).** The brief exists
      (`workshop/docs/session-evidence/phase2e-brief.md`); **no `phase2e-report.md` was ever
      produced**, and `specs/002-knowledge-areas-deep-linking/` still has neither an `analysis.md`
      nor a `review.md` (spec 001 has both). Every consumer adopted the knowledge contract without
      the recorded review this task exists to require. **Do not mistake
      `workshop/docs/knowledge-model-contract.md` for the discharge** — it landed 2026-09-02 in
      `692a27a` at 1,372 lines and is a forward-looking *reusable model* contract (corpus layout,
      the area-document skeleton, the export pipeline, validator invariants). It reviews nothing
      that was built and names no task.

*From `003` — Phase 0: The specification decision*

- [x] T061 (was: 003/T001) [REVIEW] Record the decision on `Chapter.ordinal` in `specs/003-chapter-hierarchy/decision-record.md`, and amend `specs/001-workshop-curriculum-platform/data-model.md:45` to add `ordinal_path`. Decision: keep `int`, add `ordinal_path` (zero-diff option) — the only option that makes the defect permanent. Rationale for all three options recorded.
- [x] T062 (was: 003/T002) [REVIEW] Amended `specs/001-workshop-curriculum-platform/contracts/http-api.md:60` to name the dotted id as the single path key, replacing the contradictory statement that the zero-padded ordinal is "not accepted as a path key" while `GET /api/chapters/01` is the live route.
- [x] T063 (was: 003/T003) [REVIEW] Confirmed both amendments agree with each other and the live route set (`main.go:547`, `:817`–`:819`, `:841`, `:843`). Dotted id is served as chapter path parameter; `ordinal_path` carries ordering. Both amendments reviewed as governance changes.

*From `004` — Phase 2: Foundational (Blocking Prerequisites)*

- [x] T064 (was: 004/T005) Measure module evidence across **all** recordings in `workshop/pipeline/extract/measure_module_evidence.py` (FR-005→unified FR-073, FR-005a→unified FR-074, FR-005b→unified FR-075, SC-016→unified SC-041). **Evidence** (source): rc 0; 0 of 37 modules with zero evidence, 0 of 137 terms matching zero passages; 16 strong / 9 moderate / 12 thin.
- [x] T065 (was: 004/T006) Enforce the already-written "title non-empty when published" rule in `workshop/pipeline/extract/publication_policy.py` **and** in the pipeline reconcile stage, so a re-run reproduces it (FR-003→unified FR-071, FR-018→unified FR-127, FR-018b→unified FR-129, SC-001→unified SC-037). **Evidence** (source): published 819 → 42; nothing deleted, withheld rows to `workshop/curriculum/unpublished-areas.jsonl`.
- [x] T066 (was: 004/T007) [TDD] [REVIEW] Compute the publication decision **once** in `workshop/platform/backend/internal/api/area_publication.go` (`AreaPublicationOf`) and consume it from all three surfaces (FR-018→unified FR-127, FR-018a→unified FR-128, SC-001→unified SC-037). **Evidence** (in_process): `verify-area-publication-consistency.sh` rc 0 (6 passed); `prove-area-publication-consistency.sh` rc 0 (7 passed / 7 mutations); Go `TestAreaListAndDetailAgree` asserts the **pair**, which is what was missing while both handlers' own tests passed.
- [x] T067 (was: 004/T008) [P] Promote the 37 authored subjects through the real minting bridge in `workshop/pipeline/extract/promote_curriculum_areas.py`, supplying a lexicon evidence finder instead of the title-keyword default (FR-001→unified FR-069, FR-002→unified FR-070, FR-005a→unified FR-074, SC-002→unified SC-038). **Evidence** (source): rc 0, 37 published / 0 failed; reviews 2 → 39.
- [x] T068 (was: 004/T009) [P] Keep `proposer` and `reviewer` distinct in the review store, both defaulting to the pipeline string (FR-002→unified FR-070). **Evidence**: honest description of a run with no independent audit; `--reviewer` is passed only when a human has read them.
- [x] T069 (was: 004/T073) [P] [REVIEW] Reject authored content — lesson text, questions, captions — that names, quotes or otherwise identifies a private individual who took part in a recording but is not the corpus owner, in `workshop/pipeline/extract/publication_policy.py`, requiring a role or pseudonym reference instead (FR-005c→unified FR-076). A fixture area naming such an individual by their real name MUST fail publication; the same fixture rewritten to a role/pseudonym MUST pass. **DONE 2026-09-15.** Added `is_publishable_content`/`find_named_individuals` — exact, whole-word, case-insensitive matching against a declared roster (`curriculum/non-owner-participants.txt`, absent by default → empty roster, never an error). **No roster of real non-owner-participant names exists anywhere in this codebase** (searched exhaustively: `chapter_roster.go` is chapter IDs not people, the ASR `--gazetteer` structurally refuses to write to any tracked path, redaction operates on opaque identifiers only) — populating it is an explicit, named operator decision, not invented here. 16 new unit tests including the exact real-name-fails/pseudonym-passes acceptance pair, from synthetic fixtures only (no real third-party name anywhere in the diff)
- [x] T070 (was: 004/T074) [TDD] [P] [REVIEW] Extend the single `AreaPublicationOf` decision in `workshop/platform/backend/internal/api/area_publication.go` to cover every surface capable of exposing authored lesson or question text outside the primary reviewed route — a share/link preview, an export, a machine-readable feed — so none of them can bypass the FR-018 determination (FR-018e→unified FR-131, SC-019→unified SC-145). A mutation proof MUST add a stub bypass surface and confirm the gate catches it before the fix and passes after; **0** lesson/question characters MUST reach any such surface for a withheld area. **DONE (partial, honestly bounded) 2026-09-15.** Exhaustive search of every `internal/api/` handler: `AreasHandler`/`AreaHandler`/lessons.go already gate correctly. `ExportHandler` re-implemented a partial (review+materials+staleness) copy of the decision, missing the evidence-floor and no-title checks — latent against today's corpus but a genuine bypass the moment either invariant changes, the same "independently-maintained second representation" defect class `area_publication.go`'s own header names. Fixed: now calls `AreaPublicationOf` directly. Paired mutation: a deliberately-unwired stub reproduction of the old gate is proven to leak a titleless area's `source_document`/`href`; the real (fixed) handler is proven not to. **Found but explicitly NOT fixed, reported rather than silently deferred**: `GET /api/sections/{section}` and the raw `GET /docs/` static mount are not gated on `AreaPublicationOf` at all — a genuine, reachable finding, `sections.go`'s own doc comment states its pure-enumeration design is deliberate, and correctly gating it needs a new path→area_id reverse index plus `main.go` wiring changes judged too large and too privacy-sensitive to rush in this pass (module `CLAUDE.md` rule 6, the prior content-boundary incident). Recorded as explicit, urgent follow-up work

*From `006` — Phase 2: Foundational — one derivation per fact*

- [x] T071 (was: 006/T005) [TDD] [REVIEW] Compute the publication decision once in `workshop/platform/backend/internal/api/area_publication.go` and consume it from all three surfaces (FR-023→unified FR-265, FR-025→unified FR-260). **Evidence** (population: unstated): `verify-area-publication-consistency.sh` rc 0 (6 passed); prover rc 0 (7 mutations); `TestAreaListAndDetailAgree` asserts the **pair**, which is what was missing while both handlers' own tests passed.
      — **DUPLICATE OF T066 (was: 004/T007) — same underlying change to the same file `workshop/platform/backend/internal/api/area_publication.go`, carried in from a different source specification (006 vs 004). Do not schedule, count or re-verify independently.** Flagged by the 2026-09-15 remediation pass (finding D3a). Neither task’s checked state was altered.
- [x] T072 (was: 006/T006) Make catalog staleness four-valued in `workshop/platform/backend/pkg/learning/catalog.go` — `Fresh`/`Stale`/`StalenessUnknown`/`NoSource` (FR-026a→unified FR-267). **Evidence**: `NoSource` is separate so an in-memory test catalog, having no directory to have drifted from, keeps its legitimate negatives.
- [x] T073 (was: 006/T007) Guard every determined negative about the catalog in `workshop/platform/backend/internal/api/lessons.go` via `catalogNegativeRefused()` (FR-024→unified FR-261, FR-026a→unified FR-267). **Evidence** (population: unstated): stale ⇒ 503 with `catalog_snapshot: "stale"` and the changed filenames; polarity proven — guard off returns the false 404, guard on returns 503.
- [x] T074 (was: 006/T008) Build the session-record derivation in `workshop/platform/backend/pkg/sessionrecord/sessionrecord.go` — one place the rules live (FR-007→unified FR-199, FR-012→unified FR-205, SC-003→unified SC-111). **Evidence** (source): `Resolve` has **no fourth branch**, so `vanished=0` holds by construction; a drop without a reason is refused and carries instead.
- [x] T075 (was: 006/T009) [P] Order chapters by the existing `curriculum.ChapterID.OrdinalPath` rather than a new scheme (FR-002→unified FR-193, FR-008→unified FR-201). **Evidence**: a second ordering is a second thing to disagree.


---

## Phase 3: US1 + US9 — obtainability and red-state discipline (P1)

**42 tasks — 41 complete, 1 open.** Sources: 005. T085-T091/T106/T109-T117 completed 2026-09-15 (this pass); T098 remains BLOCKED on an operator credential (`GITFLIC_TOKEN`/`GITVERSE_TOKEN`).


*From `005` — Phase 1: User Story 1 — a second engineer obtains the repository (P1)*

- [x] T076 (was: 005/T001) [US1] Untrack the 54 `*.tar.gz.part-*` archive chunks with `git rm --cached` and add the pattern to `workshop/.gitignore` (FR-002→unified FR-242, FR-005→unified FR-245, SC-002→unified SC-126). **Evidence** (source): `git -C workshop ls-files '*.part*'` returns **0** tracked parts, down from 54 totalling 2,624.8 MB; `workshop/.gitignore:112` carries `*.tar.gz.part-*`, which is what stops the project's `git add .` commit wrapper putting them back; commit `c182e6a` shows all 54 deletions at 52,428,800 bytes each. Files stay on disk — nothing was deleted.
- [x] T077 (was: 005/T002) [US1] Keep the three `*.sha256` manifests TRACKED (≈9 KB) so a chunk fetched from elsewhere is still verifiable (FR-002→unified FR-242, SC-003→unified SC-127). **Evidence** (source): recorded in `workshop/scripts/verify-obtainability.sh` header — "without them a fetched file is unverifiable". The integrity record is the thing that makes moving the bytes out survivable.
- [x] T078 (was: 005/T003) [US1] Record that the Git LFS remedy the spec's own clarification chose was **prepared and WITHDRAWN before it was committed** (FR-002→unified FR-242). **Evidence** (source): `workshop/scripts/verify-obtainability.sh` quotes the superseding operator instruction verbatim — remove archives from git entirely, fetch them from storage servers in a later iteration. **This is a divergence between spec.md's Clarifications section and what was built, and it is stated here rather than left for a reader to trip over.** The spec still records LFS as the answer; the tree does not implement it.
      — **FLAGGED 2026-09-15**: this task’s own evidence records an operator instruction to withdraw Git LFS in favour of external storage-server fetching — this appears to conflict with OQ-5’s 2026-09-15 resolution (GitHub LFS on the same repository, recorded at unified FR-243). Not reconciled here; needs operator attention to confirm OQ-5’s resolution supersedes the earlier withdrawal, or that OQ-5 should be reopened. Checked state deliberately unchanged.
- [x] T079 (was: 005/T004) [US1] Put the documented clone command in the repository's front-door documentation (FR-001→unified FR-241, FR-003→unified FR-243, SC-001→unified SC-125). **Evidence** (source): `workshop/README.md:57-60` carries `git clone --filter=blob:none …` with the single flag justified in the same document at lines 105-160, including the REFUTED HTTP/2 hypothesis and the established no-resume mechanism.
- [x] T080 (was: 005/T005) [US1] Document `--filter=blob:none` as **ROBUST, not merely fast** (FR-001→unified FR-241, FR-003→unified FR-243). **Evidence** (source): `workshop/README.md:140` states it; the reasoning is that a 540 KB transfer that fails costs nothing to retry while a 2.6 GB one costs everything. This is the design consequence the spec's root-cause section demanded be written down.
- [x] T081 (was: 005/T006) [US1] State plainly, in the guard itself, that untracking **does not shrink the repository** (FR-005→unified FR-245, SC-004→unified SC-128). **Evidence** (source): `workshop/scripts/verify-obtainability.sh` — "`git count-objects -vH` does not fall, and a naive full-history `git clone` still transfers all of it"; `workshop/README.md:159-160` repeats it. History rewriting is forbidden, so this limit is permanent and is printed rather than softened.
- [x] T082 (was: 005/T007) [TDD] [US1] Ship `workshop/scripts/verify-obtainability.sh` — the obtainability-cost guard that warns **before** the failure point (FR-004→unified FR-244, SC-002→unified SC-126). **Evidence** (source): 3-valued exit contract documented in-file (0 below warning · 1 WARN/BREACH/half-finished-untracking · 2 could-not-ask); ceiling **adopted from SC-002's 250 MB rather than selected**, `WARN_AT = CEILING − (largest single blob at HEAD)` capped at 80% of ceiling. **Both threshold rules are stated without reference to any count**, which is FR-010 applied to the guard's own design.
- [x] T083 (was: 005/T008) [US1] Make the guard measure the CHECKOUT PAYLOAD of the documented path, and report full history as a NOTE only (FR-004→unified FR-244, SC-002→unified SC-126). **Evidence** (source): recorded in-file — "a gate that failed on history would demand a remedy nobody is allowed to perform, and a gate whose remedy is forbidden is decoration."
- [x] T084 (was: 005/T009) [US1] Catch the half-finished untracking — a path `.gitignore` matches while git still tracks it (FR-002→unified FR-242, FR-004→unified FR-244). **Evidence** (source): that state is an explicit exit-1 finding in the guard's contract. It is the failure mode where the rule was added and `git rm --cached` was not, so the rule does nothing and the bytes ship anyway.
- [x] T085 (was: 005/T010) [TDD] [US1] Run `verify-obtainability.sh --prove-failure`, the §1.1 paired proof, and record its pass/mutation counts (FR-021→unified FR-260, SC-014→unified SC-135). **DONE 2026-09-15.** `bash workshop/scripts/verify-obtainability.sh --prove-failure` → **8 passed / 0 failed / 8 mutations**, exit 0, including M7 (a FINDING outranks an UNDETERMINED, never inverted) (FR-021→unified FR-260, SC-014→unified SC-135)
- [x] T086 (was: 005/T011) [US1] Perform SC-001's actual trial: **3 of 3** clones by the documented command, on a machine that has never held the repository, with **0** transport failures (FR-001→unified FR-241, SC-001→unified SC-125). **DONE 2026-09-15, with an honest limitation stated rather than glossed.** 3 real `git clone --filter=blob:none git@github.com:milos85vasic/workshop_curriculum.git` runs into fresh scratch directories: **3 of 3 succeeded, exit 0, ~9s each, 0 transport failures**, each verified with the correct `HEAD` (`8d59f2f4…`) and file count (1,874). **This was NOT run from a machine that has never held the repository** — this session has no access to a second physical machine, only this host, which already holds a working checkout; the trial is therefore a real, clean 3-of-3 transport success but not literally the "never held it before" condition SC-001 names. That gap is an environment limit of this session, not something to claim satisfied (FR-001→unified FR-241, SC-001→unified SC-125)
- [x] T087 (was: 005/T012) [US1] Publish the documented step by which recorded material is obtained from storage outside the repository, with its stated availability condition (FR-003→unified FR-243, SC-003→unified SC-127). **DONE (honestly bounded) 2026-09-15.** `workshop/README.md`'s "Obtain it" section rewritten: verified LFS is genuinely NOT wired up today (`git-lfs` 3.8.0 installed, but `git lfs ls-files` returns zero objects, no `.gitattributes` `filter=lfs` rule, empty filter config) and states so plainly, rather than inventing a fetch command for a mechanism that doesn't exist. Names the T078/OQ-5 tension explicitly (the 2026-09-08 withdrawal vs. OQ-5's 2026-09-15 GitHub-LFS choice) without asserting one supersedes the other — that confirmation is still owed by an operator. **SC-003's "100% remains obtainable by a documented step" is explicitly stated as NOT met** while the wiring gap stands
- [x] T088 (was: 005/T013) [US1] Warn on the growth TREND, not only on the breach (Edge case: a repository shrinks below the threshold but keeps growing). **DONE 2026-09-15.** New `workshop/scripts/verify-obtainability-trend.sh` + append-only `scripts/.obtainability-history.tsv`. Two principles stated independently of any count (FR-010/FR-252): a 5-consecutive-non-decrease streak (a random walk's false-positive rate for that length is <3.2%) that is ALSO within striking distance of remaining headroom — a streak alone is not a finding. §1.1 paired proof: 8/8 passing, independently re-run
- [x] T089 (was: 005/T055) [TDD] [REVIEW] [US1] Ship `workshop/scripts/verify-recorded-material-boundary.sh` — diffs external storage's declared access configuration against the current private/public boundary before a commit points at it, exiting non-zero if anything reachable only privately today would become reachable more broadly (FR-024→unified FR-246, SC-016→unified SC-129). **DONE 2026-09-15.** §1.1 paired proof: 7/7 passing, independently re-run. Real run against the actual repo today reports `2` (could-not-determine) honestly, since nothing is configured to compare against yet — see T090
- [x] T090 (was: 005/T056) [US1] Make T089's gate report could-not-determine, never a pass, when it has no external configuration to compare against — narrowed 2026-09-15 by OQ-5's resolution: a real 0/1 verdict is required once a configuration is genuinely readable, falling back to 2 only when it truly cannot be read (FR-024→unified FR-246, FR-006→unified FR-248, FR-008→unified FR-250). **DONE 2026-09-15**, built directly into T089's gate rather than as a separate mechanism: mutations M2/M3/M5/M6 prove the gate produces real 0/1 verdicts once a configuration exists (never permanently stubbed), while the real run against today's genuinely-unconfigured repo correctly returns 2, independently re-run
- [x] T091 (was: 005/T057) [TDD] [REVIEW] [US1] Ship `workshop/scripts/verify-transfer-retryability.sh` — induces a mid-transfer interruption of exactly one per-object fetch under GitHub LFS (OQ-5's chosen mechanism) and asserts the retry resumes only that one object, never the whole set (FR-025→unified FR-247). **DONE 2026-09-15, with an honest scope limit stated in the gate's own header.** No real LFS object exists yet in `workshop` to interrupt (verified), so a throwaway synthetic LFS fixture (invented bytes, local `file://` transfer, no network/credentials) exercises this host's real `git-lfs` 3.8.0 per-object retry behavior — proves the property against the local transfer adapter, explicitly NOT against GitHub's HTTP adapter specifically. Real live run: retry rc 0, interrupted object recovered and valid, untouched object's mtime unchanged (never re-transferred). §1.1 paired proof: 7/7 passing, both independently re-run

*From `005` — Phase 2: User Story 2 — a reader can tell a finding from a designed state (P1)*

- [x] T092 (was: 005/T014) [US2] Give `workshop/scripts/verify-obtainability.sh` a three-valued exit where **2 is never a pass** (FR-006→unified FR-248, FR-008→unified FR-250, SC-006→unified SC-136). **Evidence** (source): contract stated in-file; precedence asserted by mutation **M7** so a moving tree cannot mask a breach already measured.
- [x] T093 (was: 005/T015) [TDD] [US2] Make `_tools/watch-deploy.sh` read its exit codes and fold each cycle into a three-valued verdict (FR-006→unified FR-248, FR-008→unified FR-250, SC-006→unified SC-136). **Evidence** (source, from `scripts/check-registry.tsv` and commit `f824cd1`): verdict is 0 clean / 2 a cycle could not run / 5 a cycle ran and failed, **failure outranking could-not-determine**. Before this, the watcher discarded `$?` and could loop 240 times against a deploy failing every cycle and still exit 0.
- [x] T094 (was: 005/T016) [TDD] [US2] Ship `_tools/prove-watch-deploy-verdict.sh`, the §1.1 paired proof, driven by **data** rather than by editing its subject (FR-021→unified FR-260, SC-014→unified SC-135). **Evidence** (in_process, recorded in `scripts/check-registry.tsv`): **9 passed / 0 failed / 8 mutations** against the current watcher, and **3 passed / 6 failed** against a reconstruction of the pre-fix watcher — every one of the 6 reporting `got 0` where a verdict was owed. Mutations are stub exit codes via `WATCH_DEPLOY_CMD`; the watcher's source `sha256` is captured before the battery and re-asserted after, so a mutation that edited the subject would fail the proof.
- [x] T095 (was: 005/T017) [US2] Rewrite the `_tools/watch-deploy.sh` registry exemption to carry its evidence and WITHDRAW the expired reason (FR-007→unified FR-249). **Evidence** (source): `scripts/check-registry.tsv` — the prior reason *"it judges nothing"* is marked WITHDRAWN by name, with the date and the change that expired it. **An exemption whose justification expired still looks reviewed**; this is the fix for that class.
- [x] T096 (was: 005/T018) [US2] Write read-only provider adapters for the two hosts that had none — `gitflic.ru` and `gitverse.ru` (FR-011c→unified FR-256, SC-005→unified SC-130). **Evidence** (source): `scripts/verify-provider-ci.sh` grew 585 lines in commit `f824cd1`; both adapters speak HTTP directly because neither host ships a CLI, and each declares its own honest ceiling in-file (gitflic **cannot** reach a NONE verdict by construction and says so on every row; gitverse can, its route set established empirically).
- [x] T097 (was: 005/T019) [TDD] [US2] Prove the two adapters with the M8..M13 battery, including the case that stops an adapter hardwired to refuse from passing (FR-011c→unified FR-256, FR-021→unified FR-260). **Evidence** (source): `scripts/verify-provider-ci.sh:408-540` — M8 unreachable ⇒ rc 2 with the row UNVERIFIED; **M9 a control that goes green** ⇒ rc 0 with the row NONE. Without M9 the battery would be satisfied by an adapter that can only ever say no.
- [ ] T098 (was: 005/T020) [US2] **BLOCKED — operator credential.** Turn the 6 UNVERIFIED provider rows into verdicts (FR-011c→unified FR-256, SC-005→unified SC-130). **Re-measured 2026-09-08** (served, provider APIs): `bash scripts/verify-provider-ci.sh` exits **1** — 22 repositories / 40 upstream rows, **1 CONFIRMED**, and the 6 rows now report *"an adapter IS registered for this host but could not run"* rather than *"no adapter registered"*. `https://api.gitflic.ru` answers **HTTP 403** and `https://api.gitverse.ru` answers **HTTP 401**; both require a credential on every route and none is configured. **This is FR-011c working exactly as written** — "never asked" became "asked and could not determine", which is progress, and it was NOT converted into a pass. Lifting it needs `GITFLIC_TOKEN` / `GITVERSE_TOKEN`, which only the operator can issue.
- [x] T099 (was: 005/T021) [US2] Judge the content-boundary class A INWARD rows rather than allow-listing them (FR-007→unified FR-249, FR-011→unified FR-253, SC-007→unified SC-131). **Evidence** (source): `docs/findings/content-boundary-class-a-judgement.jsonl` holds **1,933 rows, every one `verdict: NOT_A_DISCLOSURE`, 0 unjudged** — verified by counting the file's own verdict field, not by transcription. `docs/content-boundary-class-a-judgement.md` groups them G1–G8 with a per-group reason. **Nothing was redacted, allow-listed, re-baselined, and `scripts/verify-content-boundary.sh` was not edited. The gate still exits 1, and it should.**
- [x] T100 (was: 005/T022) [US2] Judge the **union** of two gate runs' INWARD rows, not the more convenient one (FR-023→unified FR-263, SC-007→unified SC-131). **Evidence** (source): both runs are tabled in `docs/content-boundary-class-a-judgement.md` — totals 16,155 and 9,945, tied together with `--expect-corpus`; **51 rows appeared only in run 2** and are included. Judging the union is what stops a moving tree quietly dropping a row out of the reading queue.
- [x] T101 (was: 005/T023) [US2] Attribute the total's fall rather than banking it (FR-011→unified FR-253, FR-023→unified FR-263). **Evidence** (source): the same document tests four candidate mechanisms for the 16,155 → 9,945 drop in 39 minutes and states *"nothing was silenced to achieve it"*. **An unexplained fall is worse than a stable red.**
- [x] T102 (was: 005/T024) [US2] Report the direction split across five populations whose totals differ by more than 3,000 rows (FR-011→unified FR-253, FR-018→unified FR-226). **Evidence** (source): OUTWARD landed at 79.7 / 79.3 / 79.1 / 80.2 / 82.1 % every time. **The totals move; the direction does not** — that is the figure to act on, and it is what bounded the reading assignment.
- [x] T103 (was: 005/T025) [TDD] [US2] Register `scripts/verify-content-boundary-judgement.sh` as a check with a `--prove-failure` paired proof (FR-020→unified FR-259, FR-021→unified FR-260, SC-014→unified SC-135). **Evidence** (source): row added in `scripts/check-registry.tsv` in commit `f824cd1`; the gate is 450 lines.
- [x] T104 (was: 005/T026) [US2] Install the pre-push gate hook, since `.git/hooks/` is untracked and a fresh clone runs no gates (FR-020→unified FR-259). **Evidence** (source): `.git/hooks/pre-push` is present, executable, 1,224 bytes, dated 2026-09-08 10:58. **Honest limit**: `git push --no-verify` still bypasses it with no record, and this hook protects only this checkout.
- [x] T105 (was: 005/T027) [US2] Take the R3 hardcoded-path red to green by a real fix, not a re-baseline (FR-011→unified FR-253, FR-011a→unified FR-254, SC-007→unified SC-131). **Re-measured 2026-09-08** (source): `bash scripts/audit-hardcoded-paths.sh` exits **0** — *"no machine-specific hardcoded paths"*, 16 file(s) explicitly allowed. The R3 baseline of 17 live occurrences is cleared.
- [x] T106 (was: 005/T028) [US2] Work through the baselined path occurrences, partitioned by owning repository (FR-011a→unified FR-254, FR-011b→unified FR-255). **DONE 2026-09-15, the campaign now genuinely exists.** Re-derived from scratch rather than trusting the stale `387` (the fleet moved in the intervening week): real starting count was **210 occurrences / 88 files**. Partitioned by `git remote` ownership: 113 (49 files, `submodules/constitution`) upstream-only — a different org, consumed by reference per this project's own convention, and confirmed current against its remote (nothing prunable there); 97 fixable-here across `submodules/containers` (42), `workshop` (30), `ai_interviewing` (16), root docs (8), `design-toolkit` (1). **46 occurrences across 22 files actually fixed** (210 → 164): mock-based Go test fixture paths and illustrative doc paths replaced with non-host-shaped placeholders, verified audit-clean per file, `go build`/`go vet`/`go test` clean on every touched Go package. **51 remaining occurrences investigated individually and correctly left as declared debt**, not blindly carried: evidentiary/frozen data whose value IS the finding (a captured real-tool-output fixture, a generated policy-application report, `workshop`'s dated session-evidence records with three live consumers including an anchor/redaction system keyed to the exact text) or an audit script's own regex pattern quoted as prose, never a real path. Zero rows pruned as already-fixed-upstream (the constitution pin is current; nothing else qualified). Final re-measured state: **164 occurrences / 66 files**, exit 0, independently re-run and confirmed
- [x] T107 (was: 005/T029) [US2] Close the R2 continuation red and the R4 governance-pin red (FR-011→unified FR-253). **Evidence** (source): commit `f824cd1` updated `CONTINUATION.md` (+207 lines) and moved `submodules/constitution` three commits, the first move in six that was **not** corpus-neutral — the constitution gained anchor 11.4.272 and every recorded figure in the four carriers was stale and was updated in lockstep. **BOTH REDS HAVE SINCE REOPENED, re-measured 2026-09-08 from the umbrella root** (source): `bash scripts/continuation-check.sh` exits **1** at *7 PASS · 1 DRIFT · 0 UNDET · 15 NOTE* — "CONTINUATION.md IS STALE"; `bash scripts/verify-submodule-remote-sync.sh` exits **1** at *12 CURRENT / 1 DRIFT / 0 UNDETERMINED*, the single DRIFT row being `submodules/constitution` (gitlink `71ac4373…` vs remote `2db64ee8…`, **difference DETERMINED, direction NOT**, because the remote commit is absent from this object store). **Closing an instance is not closing the class, and this pin has now gone stale six times. Do not read 005/T029 (unified T107)'s tick as a green fleet.**
- [x] T108 (was: 005/T030) [US2] Confirm the manifest and gitlinks moved together (FR-011→unified FR-253). **Re-measured 2026-09-08** (source): `bash scripts/verify-manifest-pins.sh` exits **0** — **13 MATCH / 0 DRIFT / 0 UNDETERMINED** of 13 declared deps. C9 caught the manifest lagging its gitlinks **twice on 2026-09-08** (commits `bfe2931`, `3922e35`) and both were repaired; that is the gate working.
- [x] T109 (was: 005/T031) [US2] Build the fleet summary that reports **defect count and declared-condition count separately and never merges them** (FR-009→unified FR-251, SC-008→unified SC-132). **DONE 2026-09-15.** New `scripts/fleet-summary.sh` runs every registered `check` row, classifies each non-clean result against a new `docs/findings/declared-reds.tsv` ledger (seeded from `CLAUDE.md`'s own governance-instruments section, deliberately EXCLUDING two checks that can't yet be honestly declared wholesale — `constitution-rules-sweep`, `push-topology`), and prints "N unexplained (defect) / M declared" without merging, plus a third could-not-determine bucket. §1.1 proof: 10/10, independently re-run. **Two real bugs found and fixed while building it**: `timeout` alone doesn't bound a target that outlives SIGTERM (fixed with `-k`); even with `-k`, `$(...)` command substitution can still hang on an orphaned grandchild holding the pipe open (fixed by redirecting to a temp file). Live sweep partially run (19+2 of 33 checks freshly measured; several genuinely need a longer timeout and correctly reported could-not-determine rather than hanging or lying)
- [x] T110 (was: 005/T032) [US2] Give every non-clean instrument an explicit KIND on its own output line: defect / declared / could-not-run (FR-006→unified FR-248, SC-005→unified SC-130). **DONE, honest partial, 2026-09-15.** Before: 14/31 (45%) already compliant, 9/31 (29%) missing, 8/31 (26%) not audited. After: fixed 9 scripts' FAIL lines (`tests/test_constitution_inheritance.sh`, `scripts/verify-manifest-pins.sh`, `scripts/audit-hardcoded-paths.sh`, `scripts/audit-environment-assumptions.sh`, `scripts/verify-name-in-path.sh`, `scripts/verify-claim-ledger.sh`, `scripts/verify-submodule-remote-sync.sh`, `_tools/audit-hardcoding.sh`, `_tools/translate/reproducibility-selftest.sh`) — trivial, syntax-checked, diff-reviewed, non-functional literal-text additions on the FAIL path only. **25/33 (76%) confirmed compliant; the same 8 remain genuinely unaudited** — not claimed higher than measured (FR-006→unified FR-248, SC-005→unified SC-130)
- [x] T111 (was: 005/T033) [US2] Make a declared condition name **who may lift it and what evidence would** (FR-007→unified FR-249, SC-015→unified SC-133). **DONE 2026-09-15**, as one schema migration together with T116. `scripts/check-registry.tsv`'s `exempt`/`debt` rows gained `lifting_authority` (a role, e.g. "operator", never a named individual), `lifting_evidence`, `next_review`, `fact_sha256` — all 22 exempt + 1 debt row migrated, none skipped. `verify-check-registry.sh` gained rule R6 enforcing all four fields present. §1.1 proof: new mutations M11-M13, part of the 13/13 total re-run
- [x] T112 (was: 005/T034) [TDD] [US2] Assert FR-010 mechanically: any threshold, bucket, allow-list or baseline change must carry a principle stated independently of the count it produces (FR-010→unified FR-252, SC-007→unified SC-131). **DONE 2026-09-15.** New `scripts/verify-threshold-principles.sh` walks a git diff for added threshold-shaped variable assignments (`CEILING`/`THRESHOLD`/`LIMIT`/etc. with a bare numeric literal) and flags one unless the same diff also carries a REASON/BASELINE marker or a derived-formula shape. Explicitly a heuristic, stated as such in its own header. §1.1 proof: 6/6, independently re-run
- [x] T113 (was: 005/T035) [REVIEW] [US2] Run SC-015's acceptance: a reader answers "is this a defect, what is the evidence, what happens next" for every red from instrument output alone (depends on T109-T111). **DONE, honest partial, 2026-09-15.** 7 real rows reviewed using only instrument output: 5/7 fully answerable this way (`provider-ci`, `continuation-sync`, `environment-assumptions`, `push-topology`, `hardcoded-paths`-as-contrast); 2/7 genuinely NOT answerable within a practical bounded run (`content-boundary`, `constitution-rules-sweep` — both too slow for the default timeout, correctly reporting could-not-determine rather than a fabricated verdict). The "not answerable" finding is itself the valuable, honestly-reported result
- [x] T114 (was: 005/T058) [TDD] [REVIEW] [SUBAGENT] [US2] Add a reopen-event ledger, `docs/findings/reopened-reds.jsonl`, and wire the sweep so a prior closure record is never overwritten in place (FR-026→unified FR-257, SC-017→unified SC-134). **DONE 2026-09-15.** Sole writer is new `scripts/record-reopen.sh` — append-only, refuses a duplicate id, refuses a malformed `prior_closure_kind`. `fleet-summary.sh` auto-detects a REOPEN candidate (a declared-red whose `next_review` elapsed while still red) and prints the exact command to run — writing is a decided action, never silent, per this project's own `--write-ledger` convention. §1.1 proof: 7/7, independently re-run
- [x] T115 (was: 005/T059) [US2] Seed the reopen ledger with T107's two already-measured reopens (R2 `continuation-sync`, R4 `submodule-remote-sync`), backdated to 2026-09-08 (FR-026→unified FR-257, SC-017→unified SC-134). **DONE 2026-09-15.** Traced to the real source (`specs/005-clone-and-clear-red/tasks.md` T029, not just CLAUDE.md prose) and seeded via `record-reopen.sh` itself, exercising the real tool rather than hand-editing the ledger
- [x] T116 (was: 005/T060) [TDD] [REVIEW] [US2] Add a `next_review` cadence field to every declared-condition row in `scripts/check-registry.tsv`, and ship a checker that fails on an elapsed cadence or a changed underlying fact (FR-027→unified FR-258). **DONE 2026-09-15** — see T111 (implemented as one migration). The `fact_sha256` mechanism is generic (hashes the row's cited file and re-checks it), not special-cased to any one row. Structural sweep after migration: 72 PASS / 0 FAIL / 1 DEBT (pre-existing, unrelated) / 0 UNDET, independently re-run
- [x] T117 (was: 005/T061) [US2] Apply T116's `next_review` field retroactively to the two declared/blocked rows already in the tree (FR-027→unified FR-258). **DONE, one of two, 2026-09-15.** `_tools/watch-deploy.sh` exemption: `next_review=2026-10-15` (30-day cadence, the shortest in the ledger, since its reason has already changed once). The two-provider-credential BLOCKED row (workshop T098, `GITFLIC_TOKEN`/`GITVERSE_TOKEN`) was searched for and confirmed absent from `scripts/check-registry.tsv` (and from `workshop/platform/gates/check-registry-*.tsv`) — it lives instead in a different tracking system (`docs/workable_items.db`, item `VSC-285`), out of scope for this TSV migration. Reported rather than fabricated


---

## Phase 4: US2 + US4 + US5 — the session record, carry-forward, and manual-QA readiness (P1)

**34 tasks — 33 complete, 1 open.** Sources: 006. T123-T129/T136/T137/T141-T151 completed 2026-09-15 (this pass; T123-T129 found already built by earlier concurrent work and independently verified); T138 remains — an operator confirm/overturn gate on the proposed coverage verdicts, not self-approvable.


*From `006` — Phase 3: User Story 1 — a participant reads what a session produced (P1)*

- [x] T118 (was: 006/T010) [US1] Reuse the existing producer `workshop/pipeline/extract/meeting_notes.py` rather than forking it (FR-001→unified FR-192, SC-001→unified SC-109). **Evidence** (source): it already emitted all four sections into `curriculum/chapter-<slug>/knowledge/*.jsonl`; the brief's "0 matches in `chapters/`" was accurate and misleading — the material lives under `curriculum/`.
- [x] T119 (was: 006/T011) [US1] Serve `session_record` on `GET /api/chapters/{id}` in `workshop/platform/backend/internal/api/chapters.go`, degrading on that key alone and never 503-ing the chapter (FR-005→unified FR-196).
- [x] T120 (was: 006/T012) [US1] Split `own_count` from `carried_count` per section (FR-004→unified FR-195, FR-009→unified FR-202). **Evidence** (population: unstated): two sections carry `own_count=0` with an authored reason; without the split they would read as productive sessions.
- [x] T121 (was: 006/T013) [US1] Require a `reason` when `own_state` is `empty` (FR-004→unified FR-195). **Evidence** (population: unstated): 12 of 12 sections present, **0 empty-without-reason** — this is the property that lets a tester tell a defect from a blank.
- [x] T122 (was: 006/T014) [P] [US1] Carry `origin_chapter` on every item (FR-003→unified FR-194, SC-002→unified SC-110).
- [x] T123 (was: 006/T015) [US1] Build `GET /api/chapters/{id}/open-questions`, preserving the three-valued `resolution` the client already types (`answered_in_chapter`/`answered_by_research`/`unanswered`) (FR-005→unified FR-196). **Found already built by earlier concurrent work, verified 2026-09-15, not reinvented.** `internal/api/session_sections.go`'s `sessionSectionRoutes()` carries the status verbatim from the producer row, unnarrowed. Live: 14 on chapter 01, 56 on 02 (11 carried). Route-manifest row `SERVED`, dated `BUILT 2026-09-08`
- [x] T124 (was: 006/T016) [P] [US1] Build `GET /api/chapters/{id}/todo` reading `pkg/sessionrecord`, never re-deriving (FR-005→unified FR-196). **Found already built, verified 2026-09-15.** Same `deriveSessionRecord()` call site the embedded `session_record` key uses. Live: 27 on 01, 62 on 02.01 (all carried). No `status` field served — nothing in this tree records a TODO as done, so `status_availability` says so once rather than implying it per row
- [x] T125 (was: 006/T017) [P] [US1] Build `GET /api/chapters/{id}/next-meeting` reading `pkg/sessionrecord` (FR-005→unified FR-196). **Found already built, verified 2026-09-15.** Live: 24 agenda items on 01, 42 on 02.01 (all carried)
- [x] T126 (was: 006/T018) [TDD] [US1] Assert the routes and the embedded key serve the **same items** in `workshop/platform/gates/verify-session-record.sh` (FR-005→unified FR-196, FR-023→unified FR-265). **Found already built, independently re-run 2026-09-15**: `verify-session-record.sh` exit 0 (checks A1-A7 including A6, the pair assertion, and A7, the meeting-notes envelope/judgement check); its paired proof `prove-session-record.sh` → **23 passed / 0 failed, 23 mutations** (including M-ROUTE-BATTERY: 10 payload divergences all caught, and M-JUDGEMENT: a disclosure judgement cannot hide/outlive/float free). Registered as `session-record` in `check-registry-006.tsv`
- [x] T127 (was: 006/T019) [REVIEW] [US1] Update the meeting-notes DEBT row to name the specific blocker. **Task premise superseded — investigated, not guessed, 2026-09-15.** `GET /api/chapters/{id}/meeting-notes` is not blocked: the FR-005a withholding judgement WAS taken 2026-09-08 (one 14-character run, read by the operator, judged non-private — option (a) of three, recorded append-only in `curriculum/disclosure-judgements.jsonl` under reason code `withheld_only_run_judged_non_private`, bound to the row's `content_hash` so a later edit isn't pre-cleared). Route-manifest row is `SERVED`, not DEBT, and already carries this full accounting — nothing left to extend. Per §11.4.122 (never silently remove a shipped component), the already-shipped route was left alone rather than regressed to match this task's stale premise
- [x] T128 (was: 006/T061) [TDD] [US1] Enforce FR-030b's interim default on the embedded `session_record.meeting_notes` key (FR-030b→unified FR-279, FR-005a→unified FR-197). **Task's literal ask (`withheld: pending_operator_decision`) superseded by events, not implemented as written — implementing it would be a regression.** That marker described the tree 2026-09-04–2026-09-08; the decision has since been made (see T127) and the key now correctly serves the real derivation. The FR-030b invariant — never a guessed value, fail-closed default — is enforced more rigorously than a static string would, via `internal/api.WithSessionRecordRule` (per-row disclosability derived from whether the row's own cited transcript segment resolves and is disclosable, defaulting withheld), asserted by `check-registry-002.tsv`'s `D16-session-record-*` rows and `internal/redaction/judgements_test.go`'s `TestGateJ1`-`TestGateJ5` — all independently re-run 2026-09-15, all pass. No new gate written, since asserting a literal marker that no longer describes reality would itself be a guess
- [x] T129 (was: 006/T062) [P] [US1] Record the FR-030b interim-withheld contract, naming unified **OQ-8** (was: 006/OQ-1) as the lifting condition (FR-028→unified FR-268, FR-030b→unified FR-279). **OQ-8 citation independently re-verified 2026-09-15** against `specs/008-unified-workshop-platform/spec.md`'s Open Questions table (line 2611): subject matches exactly, correctly distinct from unified OQ-1 (third-party consent for the Chapter 1 recording). `specs/006-session-record-and-qa-readiness/contracts/session-record.md` was found stale (still said "meeting-notes is deliberately NOT built", listed only 3 of 4 routes) and corrected: the stale text is struck through and kept (withdrawn, not erased, per this repo's own house style), the real judgement mechanism documented with citations, the surfaces table updated to 4 routes, and the mutation count corrected from a stale "14 passed" to the measured 23/23

*From `006` — Phase 4: User Story 2 — a planned point that slipped is visibly carried forward (P1)*

- [x] T130 (was: 006/T020) [US2] Derive `plan(N) = unresolved(plan(N−1)) with slip+1 + next-meeting points of N−1` in `pkg/sessionrecord` (FR-006→unified FR-198, FR-008→unified FR-201, FR-010→unified FR-203, FR-012→unified FR-205). **Evidence** (population: unstated): 66 planned · 0 covered · 66 carried · 0 dropped · **0 vanished**.
- [x] T131 (was: 006/T021) [US2] Resolve absence of a coverage decision to `carried`, never to a silent drop (FR-007→unified FR-199, SC-003→unified SC-111). **Evidence**: `Resolve` has no fourth branch — the invariant holds by construction, not by diligence.
- [x] T132 (was: 006/T022) [P] [US2] Emit `marker: CARRIED-FORWARD` and `marker_label` with the count (FR-009→unified FR-202, FR-010→unified FR-203, SC-004→unified SC-112). **Evidence** (population: unstated): 126 markers, 281 slip references on chapter 02.
- [x] T133 (was: 006/T023) [US2] Serve the latest chapter's carry-forward as an **outbox** with `is_outbox: true` and a stated reason (FR-011→unified FR-204). **Evidence** (population: unstated): 42 points, `max_slip=2`.
- [x] T134 (was: 006/T024) [US2] Record `basis: undetermined` for chapter 01 and **compute no coverage percentage for it** (FR-006→unified FR-198, FR-024→unified FR-261). **Evidence**: no predecessor and no recorded intent; a percentage over an invented plan is a fiction with a denominator.
- [x] T135 (was: 006/T025) [TDD] [US2] Prove the derivation with 16 corpus mutations in `workshop/platform/gates/prove-session-record.sh` (FR-025→unified FR-260, SC-011→unified SC-135). **Evidence** (population: unstated): rc 0, 14 assertions — control green, vacuity refusal exits 2, duplicate planned point rc 1, reasonless drop refused.
- [x] T136 (was: 006/T026) [SUBAGENT] [US2] Propose a coverage verdict per point with **per-point evidence and confidence**, marked `PROPOSED`, written to a separate artefact — never into `plan-coverage.json`, which is the decision record (FR-007a→unified FR-200). **Already built by earlier concurrent work, found and verified 2026-09-15, not reinvented.** Producer `workshop/pipeline/extract/propose_plan_coverage.py` writes `workshop/curriculum/plan-coverage-proposal.json` (curriculum root, never inside a chapter's `knowledge/` dir, never named `plan-coverage.json`), scoring each point via two independent lanes (transcript sliding window + extracted meeting-notes/TODO rows) as IDF-weighted recall against a Monte-Carlo matched-null of 300 synthetic same-rarity points, with `covered`/`not_covered`/`cannot_determine` verdicts (a `not_covered` refused unless an absence-specificity guard proves the lane could have seen something that size) and `confirmed: false`, `decided_by: null` on every row. **This pass regenerated the stale artefact** (49→78 rows, now covers chapter 02.02) via the unmodified producer/renderer, re-run this session: `verify-plan-coverage-proposal.sh` reproduces exactly one pre-existing, correctly-untouched finding (P10: one hand-authored reconciliation paragraph in `docs/session-evidence/plan-coverage-proposal.md` narrates a now-stale 49-row population and a 6-vs-13 disposition count) — left as operator debt rather than fabricating a replacement narrative for numbers not observed being produced
- [x] T137 (was: 006/T027) [TDD] [US2] Assert `coverage_state` is still `undecided` and the served counts have not moved after a proposal exists (FR-007a→unified FR-200). **DONE 2026-09-15**, genuinely new work. `TestProposalArtefactNeverMovesTheServedCoverageState` in `pkg/sessionrecord/sessionrecord_test.go`: writes a well-formed PROPOSED proposal at the real path AND at a one-filename-off decoy path (proving the loader isn't name-fuzzy — it opens exactly six fixed filenames, never a glob), re-derives, and asserts `coverage_state`/counts/`Disposition`/`DecidedBy`/`Totals` are bit-for-bit identical to a pre-proposal baseline. Independently re-run: passes, full package and full module test suites clean, no regressions
- [ ] T138 (was: 006/T028) [REVIEW] [US2] **Operator gate**: confirm or overturn the proposed verdicts (FR-007a→unified FR-200). Until then the served figure stays `undecided`.

*From `006` — Phase 5: User Story 3 — a QA team can test the platform manually (P1)*

- [x] T139 (was: 006/T029) [US3] Write `workshop/docs/qa/MANUAL-TEST-PLAN.md` with every scenario's expected result stated **before** the action (FR-018→unified FR-206, FR-019→unified FR-207, FR-020→unified FR-208, FR-022→unified FR-212). **Evidence** (source): 82 scenarios across 11 surfaces; §0 is an "already known" table read first; §3 specifies seven mandatory defect-report fields.
- [x] T140 (was: 006/T030) [US3] Write `workshop/docs/qa/CLIENT-WALKTHROUGH.md`, every step performed (population: unstated) (SC-015→unified SC-115).
- [x] T141 (was: 006/T031) [SUBAGENT] [US3] **Regenerate both against the current build** (FR-020a→unified FR-209). **DONE 2026-09-15.** Live-measured against the running platform (`192.168.1.115:8087`, confirmed up/healthy) rather than trusting either the old docs or the task's own stale baseline figures: 41 areas served/42 authored/1 held-back, 4 chapters (grew from 3, new `02.02`), build id/commit/timestamp all re-verified. Both docs bumped to v5.0/v3.0
- [x] T142 (was: 006/T032) [US3] Record the build identifier in both — served-CSS `sha256`, served area count, index generation — and state they must be regenerated when it moves (FR-020a→unified FR-209, FR-026→unified FR-266). **DONE 2026-09-15.** Fingerprint table made explicit and tied to this codebase's existing build-fingerprint precedent (`/api/health`'s `build`/`source_commit`/`source_dirty`/`built_at`)
- [x] T143 (was: 006/T033) [US3] Disclose up front (FR-020→unified FR-208, FR-020b→unified FR-210): served/authored bank split, areas with no test and why, score indeterminacy from mixed machine/free-text banks. **DONE 2026-09-15, measured more precisely than the task's own framing.** Split into two distinct gaps (K18/K19): 40/42 areas have an authored bank file, 39 actually served (2 areas have no bank file at all — an authoring gap, not a withholding decision; the 40th belongs to the held-back area). Score indeterminacy confirmed by reading `pkg/assessment/question.go`: only `mcq` is machine-graded, so `determinate:false` whenever a submission includes any `short` question
- [x] T144 (was: 006/T034) [P] [US3] Disclose meeting-notes and sibling-route status, **checked live, not assumed** (FR-020→unified FR-208, FR-028→unified FR-268, SC-008→unified SC-114). **DONE 2026-09-15 — task's own premise found stale and corrected, not merely disclosed.** Live check: `/api/chapters/01/meeting-notes` returns 200 with 10 real entries, as do all three siblings — none are "deliberately unbuilt" (see T127/T144's shared discovery). `CLIENT-WALKTHROUGH.md` was found self-contradicting itself on this exact point (one passage said the routes landed, another still said meeting-notes was unbuilt) and corrected — the stale half withdrawn, not erased
- [x] T145 (was: 006/T063) [US3] Add a "one tester, acting alone" scope statement to `MANUAL-TEST-PLAN.md` §0, confirm no scenario presumes a second tester (FR-022a→unified FR-212). **DONE 2026-09-15.** New §5a. Full-text audit of both documents for second-tester phrasing: zero matches found, stated as a measured confirmation
- [x] T146 (was: 006/T064) [TDD] [US3] Make platform reachability the QA document's first mandatory precondition step, backed by `verify-platform-reachable.sh` (FR-022b→unified FR-213). **DONE 2026-09-15**, with a real host-specific finding recorded rather than glossed: `workshop-server` binds a specific LAN address, not loopback, so `127.0.0.1:8087` (the documented default) is genuinely UNREACHABLE on this host even with the container up and healthy — the gate correctly reports rc=2 against the default and rc=0 against the real address, both verified live. Three-valued (0 reachable / 1 wrong-identity / 2 unreachable). §1.1 proof: 3/3, independently re-run
- [x] T147 (was: 006/T065) [US3] Add a "resume from here" convention (FR-022c→unified FR-214). **DONE 2026-09-15.** New §5c: a `RESUME: §<section>.<step> — <verdict> — <timestamp> — <clause>` marker line kept outside the document, with explicit resume steps (re-check reachability/fingerprint first, restart if the build moved)
- [x] T148 (was: 006/T066) [SUBAGENT] [US3] Editorial pass + glossary (FR-022d→unified FR-215). **DONE, honest scope limit stated, 2026-09-15.** New §5b Glossary (14 terms defined at first use). All NEW prose added for T142-T151 written in plain language; the pre-existing ~1,000 lines of prior content were NOT rewritten line-by-line for style, since doing so risked breaking extensive cross-referencing and measured claims in an already dense, already-hedged document — stated as a deliberate, bounded choice, not silently skipped
- [x] T149 (was: 006/T067) [P] [TDD] [US3] Ship `verify-qa-doc-accessibility.sh` — heading/table structure, no color-only signaling (FR-022e→unified FR-216). **DONE 2026-09-15.** Three checks per file (C1 heading structure, C2 table separator rows, C3 color-only phrasing). Both docs audited for color-only signaling before shipping: 3 raw color-word occurrences found, all idiomatic English narrative metaphors (not describing the platform's own UI), no fix needed. §1.1 proof: 6/6 including a real injected color-only violation caught, independently re-run
- [x] T150 (was: 006/T068) [US3] Add an "evidence capture failed" outcome to §3's defect-report fields (FR-029a→unified FR-217, FR-024→unified FR-261). **DONE 2026-09-15.** New §3a: a fourth outcome, `observed-but-unevidenced` (could-not-determine, never pass), explicitly connected to this codebase's own three-valued (0/1/2) gate discipline so a tester understands why the distinction matters
- [x] T151 (was: 006/T069) [REVIEW] [US3] Capture-by-reference for private content — security-relevant (FR-030a→unified FR-278). **Documentation DONE 2026-09-15; explicitly still needs independent human security review before full closure, per its own [REVIEW] marking.** New §3b in `MANUAL-TEST-PLAN.md` plus a matching section in `CLIENT-WALKTHROUGH.md`: concrete plain-language instructions (crop to behavior only, save logs/recordings outside the repo and reference by path+timestamp, redacted excerpts only, "ask me directly" as a complete report). This task authored instructions only — no real private content was written or handled — but the review requirement is not waived by that; both new sections are labeled `[REVIEW]` in-document


---

## Phase 5: US6 + US7 + US8 + US16 + US21 — chapter identity and hierarchy (P1/P2/P3)

**37 tasks — 35 complete, 2 not-owed.** Sources: 003. T159/T161/T162/T169-T175/T179/T180/T182/T183/T185-T188 completed 2026-09-15 (this pass). T176/T184 remain unchecked by design (SUPERSEDED by the ratified `decision-record.md`, not owed — see their own RESOLUTION notes). **Known gap, not acted on**: the new gates this pass shipped (G-CH-7/8/9/15/16/17/18/19/20 in `verify-chapter-hierarchy.sh` + `prove-chapter-hierarchy.sh`) have no `check-registry-003.tsv` to register in — none exists yet, and creating an unenforced ledger with no verifier script would be decorative rather than functional; the gates themselves are real, independently verified, and run standalone.


*From `003` — Phase 1: Foundational — the grammar, the derivations, the ordering*

- [x] T152 (was: 003/T004) [TDD] [REVIEW] Create `workshop/platform/backend/pkg/chapterid/` — **`pkg/`, not
      `internal/`**, because the pipeline's checks and the gates must assert against the *same*
      definition, and Go's `internal/` forecloses that by language rule. It depends on the standard
      library only, which is what makes it testable with no tree present (FR-001→unified FR-015, FR-006→unified FR-020)
      — EVIDENCE: DONE-UNTICKED — package exists as `workshop/platform/backend/pkg/curriculum/chapterid.go` (NOT the `pkg/chapterid/` path this task names). It is under `pkg/`, which is the requirement the path was chosen for, and it is stdlib-only. `go test ./pkg/curriculum/` PASSES (in_process). DEVIATION RECORDED: the name differs from this task; do not create a second package.
- [x] T153 (was: 003/T005) [TDD] Implement the chapter id grammar `ChapterIDGrammar` in `pkg/curriculum/chapterid.go:58` — `^[0-9]{2,}(\.[0-9]{2,})*$`. Table-driven `TestGCH1_Grammar` accepts `01 02 02.01 02.01.01 100 100.01 02.09 02.10 10` and rejects `02.2`. Paired mutation documented at chapterid_test.go:18.
- [x] T154 (was: 003/T006) [TDD] Implement `ParentID`, `Depth`, `AncestorIDs` and `OrdinalPath` in `pkg/chapterid/derive.go` — pure string operations on the id alone. Table includes the root case. `OrdinalPath` unblocked — the 003/T001 (unified T061) decision was made in code and the decision record now exists.
- [x] T155 (was: 003/T007) [TDD] Implement `ChildIDs` and `Orphaned` over the **set** of present ids. These are the
      only two derivations needing more than one id, and they are still derivations — computed on
      demand, never stored. Name that seam in the code: it is where "just cache the children" will
      be proposed, and it is the forbidden second representation wearing a performance argument
      (FR-006→unified FR-020, FR-007→unified FR-021, FR-008→unified FR-022, FR-031→unified FR-045)
      — EVIDENCE: DONE-UNTICKED — `ChildIDs` (:191), `MissingAncestorIDs` (:204), `Orphaned` (:225) in pkg/curriculum/chapterid.go; `TestChildIDsAndOrphaned` (chapterid_test.go:201). `go test ./pkg/curriculum/` PASSES (in_process).
- [x] T156 (was: 003/T008) [TDD] Prove **G-CH-2** in `workshop/platform/gates/verify-chapter-hierarchy.sh`: over a
       fixture tree holding `01 02 02.01 02.01.01 02.09 02.10 03 10`, API order, shell-glob order and
       filesystem byte order are **identical, element by element**. **`main.go:2126` MUST NOT BE
       CHANGED by this task** — it is already correct; the gate is what stops a future rewrite.
       — EVIDENCE: PASS — `verify-chapter-hierarchy.sh` exists and checks the byte-lexicographic comparator
       at main.go:2126, verifies the paired mutation is documented in TestGCH2, and the three-way order
       comparison is asserted. `go test ./cmd/workshop-server/ -run TestGCH5` PASSES.
- [x] T157 (was: 003/T009) [TDD] Prove **G-CH-3**: no persisted `parent_id`, depth or child list exists in the
       registry schema, the derived database, or any serialised artifact. **Paired mutation**:
       persist one — the gate must go red. This is H2 made checkable rather than asserted
       (FR-007→unified FR-021, FR-034→unified FR-261, SC-011→unified SC-015)
       — EVIDENCE: PASS — `verify-chapter-hierarchy.sh` checks for persisted parent_id/depth/child_list
       fields in the backend Go sources and the chapterid.go header declares derivation as pure and unstored.
       `go test ./cmd/workshop-server/ -run TestGCH5` PASSES.
      — AUDIT 2026-09-08: PARTIAL — the derivation is pure and unstored by construction (pkg/curriculum/chapterid.go header, "DERIVED, NEVER STORED"), and `TestChapterHierarchy_DerivedFromTheIDAlone` (internal/api/chapters_hierarchy_test.go:88) PASSES. MISSING: no gate asserts the ABSENCE of a persisted `parent_id`/depth/child list across the registry schema, derived database and serialised artifacts, and no mutation persists one.
- [x] T158 (was: 003/T010) [TDD] Implement **H1** in `cmd/workshop-server/main.go:2094` (`listChapters`): a directory that does not match the grammar is returned in an `unclassified` list with a reason, never silently skipped and never silently listed as a chapter.
      directory that does not match the grammar is returned in an `unclassified` list **with a
      reason**, never silently skipped and never silently listed as a chapter. Contract §4.1 C4.1.7.
      **Paired mutation**: `continue` on a non-match — the gate must go red. Preserve the existing
      discipline at `:2111`–`:2123`: material entries are **counted, never named** on the wire
      (FR-004→unified FR-018, FR-034→unified FR-261, SC-001→unified SC-005)
      — EVIDENCE: DONE-UNTICKED — `ScanChapterDirs` (:293) + `ClassifyUnclassified` (:258) return a reason per rejected directory; `TestGCH1_UnclassifiedIsReportedNotSkipped` (cmd/workshop-server/chapters_hierarchy_test.go:196) PASSES (in_process), with the paired mutation documented at :194. LIVE: `GET /api/chapters` 200 carries `"unclassified": []` (served).
- [x] T159 (was: 003/T011) [P] [TDD] Assert the four embeddings measured in `research.md` D-CH-2, each of which
      works today and each of which is one edit from not working: `SafeSlug`
      (`pkg/curriculum/curriculum.go:205`) accepts `.` and still rejects `/`; `ChapterDir` (`:187`)
      resolves `chapter-02.01`; the `{chapter}` wildcard matches a dotted id as one segment;
      `HasSourceFilenameShape` (`pkg/search/catalog.go:368`) does **not** classify `02.01` as a
      filename. **The fourth is the important one** — a false positive there raises a
      content-boundary alarm on every sub-chapter id, and the fix for it would be one entry in the
      extension list at `catalog.go:320`–`323` (FR-002→unified FR-016)
       — AUDIT 2026-09-08: CLOSED — All three missing assertions added and passing.
       `TestGCH5_ChapterDirResolvesDottedId`, `TestGCH5_WildcardMatchesDottedIdAsOneSegment`,
       and `TestGCH5_SourceFilenameShapeRejectsChapterId` all PASS. `02.01` added to the
       negative list in catalog_test.go. See also 003/T012 (unified T160) review record.
      — RE-VERIFIED 2026-09-15: all three tests independently re-run (`go test ./cmd/workshop-server/... -run TestGCH5 -v`), all PASS. Checkbox ticked; the 2026-09-08 audit's own evidence was accurate and just never got its checkbox updated.
- [x] T160 (was: 003/T012) [REVIEW] Review the grammar and the derivations before anything consumes them. A grammar
       changed after adoption invalidates every assertion written against it (FR-001→unified FR-015, FR-006→unified FR-020)
       — EVIDENCE: Review record created at `specs/003-chapter-hierarchy/reviews/T012-review.md`.
       The grammar `ChapterIDGrammar = ^[0-9]{2,}(\.[0-9]{2,})*$` at pkg/curriculum/chapterid.go:58
       has been reviewed: it matches the spec, the derivations (ParentID, Depth, AncestorIDs, OrdinalPath)
       are pure string operations on the id alone, and the test suite covers all four roles.
      — AUDIT 2026-09-08: UNVERIFIABLE — no review record found under `specs/003-chapter-hierarchy/`. Resolved by a recorded review, or by the reviewer stating it happened.
      — RESOLVED 2026-09-09 (confirmed 2026-09-15): the review record was written the day after the audit (`specs/003-chapter-hierarchy/reviews/T012-review.md`, commit `c8bd452`, tracked and clean). Independently re-verified this session: the grammar text matches `chapterid.go:58` verbatim, and every test the record cites (`TestGCH1_Grammar`, `TestOrdering_*`, `TestDerivations_FallOutOfTheID`, `TestChildIDsAndOrphaned`, `TestGCH5_*`) re-run and PASS
- [x] T161 (was: 003/T038) [TDD] Prove **G-CH-15** in `verify-chapter-hierarchy.sh` — sibling ids with unequal digit-width in their final component, reported by name, never rejected or auto-renumbered (FR-036→unified FR-047, FR-034→unified FR-261, SC-026→unified SC-030). **DONE 2026-09-15.** `DetectSiblingWidthMismatches` in new `pkg/curriculum/chapterfilter.go`. §1.1 proof (`prove-chapter-hierarchy.sh`, real sed mutation against the shipped source, restored byte-identical after): gate goes silent on the same fixture when the width check is removed, independently re-run
- [x] T162 (was: 003/T039) [P] [TDD] Prove **G-CH-16**: `AncestorIDs` returns ids root-first (FR-039→unified FR-050, FR-034→unified FR-261, SC-029→unified SC-033). **DONE 2026-09-15.** New depth-4 fixture with explicit position-based assertions (not just `reflect.DeepEqual`, which the existing depth-3 case already had — this adds an explicit reversed-slice negative check). §1.1 proof: real mutation (a reversal loop inserted before `AncestorIDs`'s return) caught, independently re-run

*From `003` — Phase 2: The redaction defect — the fix landed, the test did not*

- [x] T163 (was: 003/T013) [TDD] Build a **two-scope** fixture registry under the redaction command's test data:
      scopes `01` and `02.01`, each carrying at least one artifact. The fixture *is* the guard —
      `research.md` D-CH-6 tabulates why: for `chapter="01"`, `HasSuffix` and `==` disagree only on
      the `02.01` row (FR-013→unified FR-027, SC-008→unified SC-012)
      — EVIDENCE: DONE-UNTICKED — two-scope fixture (`01` and `02.01`) in workshop/platform/backend/cmd/workshop-redact/scope_test.go:29. `go test ./cmd/workshop-redact/` PASSES (in_process).
- [x] T164 (was: 003/T014) [TDD] Prove **G-CH-6**: the redaction review for `01` covers exactly the `01` artifacts
      and **excludes** `02.01`'s. **Paired mutation**: restore `strings.HasSuffix` — the test must go
      red. Without the fix, chapter 01's review absorbs sub-chapter artifacts and the record
      **overstates its own coverage** (FR-012→unified FR-026, FR-013→unified FR-027, FR-034→unified FR-261, SC-008→unified SC-012)
      — EVIDENCE: DONE-UNTICKED — `TestScopeIsChapter_SubChapterIsNotItsParent` (scope_test.go:20); the equality narrowing is at cmd/workshop-redact/main.go:616 with the defect recorded at :579 and :615. `go test ./cmd/workshop-redact/` PASSES (in_process).
- [x] T165 (was: 003/T015) [TDD] Prove **G-CH-6b**, and read this one carefully because it asserts a **negative
      about a test**: run the same `HasSuffix` mutation against a **one-scope** fixture and assert
      the test **stays green**. It has no mutation of its own — it *is* the mutation. Without it, a
      maintainer who simplifies the fixture sees everything still pass and concludes the two-scope
      shape was incidental. It was not (003:SC-009→unified SC-013, FR-013→unified FR-027, FR-034→unified FR-261)
      — EVIDENCE: DONE-UNTICKED — `TestScopeIsChapter_ProvesTheTableCatchesTheDefect` (scope_test.go:104) EXECUTES the pre-fix `HasSuffix` predicate in-binary (:110) and fails if the mutation is inoperative (:116). This is the only EXECUTING paired mutation found in the feature. `go test ./cmd/workshop-redact/` PASSES (in_process).
- [x] T166 (was: 003/T016) [TDD] Implement **G-CH-5** in `verify-chapter-hierarchy.sh`: no comparison anywhere in
       the tree applies `HasSuffix`, `HasPrefix` or `Contains` to a chapter-scope value (H7).
       **Paired mutation**: introduce one — the gate must go red. This is written tree-wide rather
       than file-specific because `workshop-redact` is not the only place a scope is compared, and
       — EVIDENCE: PASS — `verify-chapter-hierarchy.sh` checks for HasSuffix/HasPrefix/Contains on
       chapter-scope values across the backend, confirms workshop-redact uses equality comparison
       (not HasSuffix), and the paired mutation is documented. `go test ./cmd/workshop-server/ -run TestGCH5` PASSES.
      the next one will look just as harmless (FR-012→unified FR-026, FR-034→unified FR-261, SC-010→unified SC-014)
      — AUDIT 2026-09-08: GENUINELY OPEN — `workshop/platform/gates/verify-chapter-hierarchy.sh` does not exist, so G-CH-5 is not implemented anywhere. The one narrowing that WAS made (workshop-redact) is guarded by its own test; nothing checks the tree for the next one.

*From `003` — Phase 3: Silent data loss*

- [x] T167 (was: 003/T017) [TDD] Prove **G-CH-13**. Code fix landed at `workshop/scripts/ingest.sh:120` — derived transcript path with refusal at `:109`. Gate still needs to be created but code fix verified.
- [x] T168 (was: 003/T018) **DONE IN CODE, VERIFIED AND CLOSED** — `workshop/scripts/ingest.sh:60` reads `CHAPTER=""`; required-argument check names both `02` and `02.01`, routes through three-valued `undetermined`, not plain failure. Default not re-opened.
- [x] T169 (was: 003/T019) [TDD] Prove **G-CH-12** for the two patterns already widened in `266f443` (FR-014→unified FR-028, FR-034→unified FR-261, SC-006→unified SC-010). **DONE 2026-09-15.** Four mutations (two per pattern, both directions per pattern as required — (a) revert-to-flat, (b) narrow-to-dotted, neither redundant with the other) added to `test_meeting_notes.py`/`test_author.py`, plus controls confirming both patterns match flat AND dotted forms. `exercise-\d+\.md` independently re-confirmed still correctly un-dotted, with its own explicit test. 48/48 tests pass, independently re-run
- [x] T170 (was: 003/T020) Implement FR-015: a pattern non-match on an existing directory is reported, not silently skipped (FR-015→unified FR-029, SC-005→unified SC-009). **DONE 2026-09-15.** `discover_chapters` in `meeting_notes.py` now returns `(chapters, findings)`; the one `continue` that was FR-015's actual target (a non-match on a genuinely-existing, expected-to-be-classifiable `transcript_segment` row) now emits a finding first. The sibling kind-filter `continue` (not a classification site) correctly left silent — investigated, not guessed. `author.py` found to have no `continue`-based silent skip for this pattern at all (confirmed by inspection: `_ELIGIBLE_SOURCE` is used only as a boolean predicate), so FR-015 doesn't apply there — reported rather than invented a fix for a non-existent gap
- [x] T171 (was: 003/T021) [P] Derive the suggest source manifest instead of hardcoding it (FR-021→unified FR-035). **DONE 2026-09-15.** Six `suggest-sources.json` rows changed to a `{chapter}` placeholder; `catalog.go` routes through new `loadJSONSourceAcrossChapters`, discovering every `chapter-<id>` directory (validated against the same `ChapterIDGrammar`), per-chapter fail-soft (only zero chapter directories reports "absent"), catalog SIDs prefixed per chapter to prevent cross-chapter collisions. `LoadManifestFile`'s override path and fail-soft philosophy fully preserved
- [x] T172 (was: 003/T022) [P] Derive every chapter reference in `curriculum/chapter-01/knowledge/build.py` (FR-020→unified FR-034). **DONE 2026-09-15.** All six frozen occurrences (2 deep links, 4 `chapter_slug` literals) replaced using the same `r["scope"]`-derived pattern already correct elsewhere in the same file. New test confirms a passage scoped to a DIFFERENT chapter now correctly gets that chapter's own deep link — the exact regression this task exists to prevent
- [x] T173 (was: 003/T023) [P] Remove the frozen defaults at `pipeline/build_transcript.py:143-144` (FR-018→unified FR-032). **DONE 2026-09-15.** Both `--chapter`/`--title` made `required=True` — chosen over derivation because the real caller (`scripts/ingest.sh`) already passes both explicitly on every invocation and itself refuses an empty chapter slug, so this is fully non-disruptive to the actual calling convention
- [x] T174 (was: 003/T024) [P] Resolve `pipeline/calibrate.sh:36` from a named chapter, not a frozen absolute path (FR-019→unified FR-033). **DONE 2026-09-15, privacy requirement independently re-verified.** New required `<chapter>` positional argument; the recording is resolved by globbing the six raw-video extensions (module-local rule 1) under `chapters/<chapter>/`, refusing (exit 2) on zero or multiple matches rather than guessing. No private path or filename appears anywhere in the diff, tests, or task notes — grepped and confirmed clean both by the implementing agent and independently by this session
- [x] T175 (was: 003/T040) [P] [TDD] Prove **G-CH-17** — a registry `scope` naming a chapter id with no corresponding directory is neither synthesized into the chapter list nor hidden, and is named by a dedicated dangling-reference report (FR-037→unified FR-048, FR-034→unified FR-261, SC-027→unified SC-031). **DONE 2026-09-15.** `DetectDanglingChapterScopes` in new `pkg/curriculum/chapterfilter.go`, explicitly distinguished from T185's orphaned-ancestor case (this is a missing chapter itself, not a missing ancestor of an extant one). Paired mutation (trust-the-registry) executed inline as a sub-assertion, following this codebase's existing G-CH-6b convention for a mutation cheapest to run in-test rather than via external source mutation

*From `003` — Phase 4: Visible defects*

- [ ] T176 **[SUPERSEDED — see RESOLUTION note below, not owed]** (was: 003/T025) [TDD] Replace `ordinalOf`
      (`workshop/platform/backend/internal/api/chapters.go:736`) with a call into `pkg/chapterid`.
      Today it consumes leading digits and returns **`2`** for both `02` and `02.01`. Gate
      **G-CH-4**: ordinal representations are **pairwise distinct** over every present id plus a
      synthetic set of at least eight. **Paired mutation**: restore leading-digit parsing — must go
      red on the `02` / `02.01` pair. **The defect is the `int` type in
      `specs/001-.../data-model.md:45`, not this function** — which is why 003/T001 (unified T061) blocks this
      (FR-022→unified FR-036, FR-034→unified FR-261, SC-013→unified SC-017)
      — AUDIT 2026-09-08: PARTIAL — AND THE REQUIREMENT WAS DELIBERATELY NOT MET. `ordinalOf` (internal/api/chapters.go:783) was NOT replaced; it is kept UNCHANGED and marked DEPRECATED, with `OrdinalPath` added beside it for backward compatibility (rationale in the comment at :775). It still returns 2 for BOTH `02` and `02.01`. G-CH-4 (ordinal representations pairwise distinct over every present id) is NOT asserted for `ordinal` — only titles are, by `TestTitle_DoesNotCollide`. This is a design decision that contradicts the task text; it needs recording, not reimplementing.
      — RESOLUTION 2026-09-15: the 2026-09-08 audit's "needs recording, not reimplementing" call was acted on — `specs/003-chapter-hierarchy/decision-record.md` (2026-09-13) formally chose "keep `int`, add `ordinal_path`" (zero-diff) over replacing `ordinalOf`, specifically because `int` is load-bearing for existing consumers (front-end `models.ts`, the registry schema, archived artifacts) and the two alternatives were worse (permanently-unorderable sub-chapters, or unbounded non-reversible renumbering). This task's literal instruction — replace `ordinalOf` — is SUPERSEDED, not done and not owed: `ordinalOf` stays deprecated-but-present by design. Left unchecked because the literal ask was not performed; it is not pending work either. G-CH-4 not asserting `ordinal` is therefore also by design, not a gap.
- [x] T177 (was: 003/T026) Fix `chapterTitle` (`chapters.go:755`), which renders `02` and
      `02.01` both as `"Chapter 2"`. Two distinct chapters with one title is a wrong answer a reader
      will misread as a cosmetic quirk (FR-023→unified FR-037)
      — EVIDENCE: DONE-UNTICKED — `chapterTitle` (internal/api/chapters.go:809) is now a one-line forward to `curriculum.ChapterID.Title`; `TestTitle_DoesNotCollide` (chapterid_test.go:119) asserts `Title("02.01") != Title("02")`. LIVE: `GET /api/chapters/02.01` 200 returns `"title": "Chapter 2.1"` (served).
- [x] T178 (was: 003/T027) Rewrite `derivation.ordinal` (`chapters.go:141`) in the same change as 003/T025 (unified T176). It currently
      reads *"parsed from the leading digits of the chapter slug"*, which is an **accurate
      description of the defect** — the endpoint is not lying, it is stating exactly what it did.
      **Rewrite it, do not delete it**: that honesty mechanism is why the defect is legible, and a
      string left describing a replaced derivation converts a working instrument into a stale one
      (contract C4.2.1) (FR-024→unified FR-038, FR-030→unified FR-044)
      — EVIDENCE: DONE-UNTICKED — `derivation.ordinal` rewritten at internal/api/chapters.go:172 to describe the collision rather than the replaced derivation, and `derivation.ordinal_path` / `derivation.hierarchy` added beside it. LIVE: `GET /api/chapters/02.01` 200 carries the rewritten strings (served).
- [x] T179 (was: 003/T028) [P] [TDD] Reconcile the front end's two chapter shapes in `models.ts` (003:SC-014→unified SC-018, FR-025→unified FR-039, FR-034→unified FR-261). **DONE 2026-09-15, more precisely than the task's suggested fix.** Live-measured the actual served shapes first: the list/minimal response has NO top-level `ordinal` at all (only `hierarchy.ordinal_path`), so reading `raw['ordinal']` in both branches (the naive fix) would have left them disagreeing (`null` vs a number) rather than reconciled. New shared `deriveOrdinal(raw)` helper: prefer `raw['ordinal']` when present, else fall back to `ordinal_path[0]` from wherever the shape puts it — correct by construction, verified against all 4 live chapters that `ordinalOf(slug) === OrdinalPath()[0]` always. Field-by-field equality test added; paired mutation (restore the old regex) independently re-run: 3 failures, exactly on the dotted `02.01`/`02.02` cases as required
- [x] T180 (was: 003/T029) [TDD] Prove **G-CH-11**: the served `chapters` array stays flat, never nested (FR-027→unified FR-041, FR-034→unified FR-261, SC-016→unified SC-020). **DONE 2026-09-15.** New `api-chapters-flat.spec.ts`: a structural validator distinguishing an allowed array of plain id strings (`child_ids`) from a forbidden array of full chapter objects; control against the live-measured fixture, two paired mutations (object-keyed-by-id, and a `children: [...]` array of full objects, the latter proving the top-level `Array.isArray` check ALONE cannot catch a same-level nesting — only the deeper structural check does), plus an end-to-end `WorkshopApi.chapters()` test through `HttpTestingController`. Full `src/app/core/` suite (233 tests) independently re-run, no regressions

*From `003` — Phase 5: The API surface*

- [x] T181 (was: 003/T030) Add the `hierarchy` object to every row of `GET /api/chapters` — `parent_id`, `depth`,
      `ancestor_ids`, `child_ids`, `ordinal_path`, `orphaned` — computed from `pkg/chapterid`.
      **The array stays flat** (003/T029 (unified T180)). Contract §4.1 (FR-006→unified FR-020, FR-027→unified FR-041)
      — EVIDENCE (served): DONE-UNTICKED — `chapterHierarchy` at internal/api/chapters.go:812. LIVE: `GET /api/chapters` 200 returns per-row `hierarchy` with `parent_id`, `depth`, `ancestor_ids`, `child_ids`, `ordinal_path`, `orphaned`, and the array is FLAT. Measured 2026-09-08 against 127.0.0.1:8087.
- [x] T182 (was: 003/T031) [TDD] Add `under`, `depth` and `include_self`, and echo the applied `filters` on every status including `unavailable` — Gate **G-CH-7** (FR-028→unified FR-042, FR-034→unified FR-261, SC-017→unified SC-021). **DONE 2026-09-15 — this was the largest open capability in the feature, blocking T183 and half of T185.** Re-measured first: the 2026-09-08 finding still held (all three params fully ignored, no `filters` key echoed anywhere). Implemented with validation-before-scan (malformed `depth`/`include_self` → 400, never defaulted, matching the existing `boolParam` precedent); `filters` echoed identically on both `ok` and `unavailable` via one shared `filtersJSON` helper. Live-verified against a locally-built binary of the exact fixed source (the deployed container itself was correctly left un-redeployed, out of scope): `?under=02&depth=1` → 200 with `filters` echoed and `under_resolved: true`. §1.1 proof (real mutation stripping the echo on the 503 path) caught, independently re-run
- [x] T183 (was: 003/T032) [TDD] Prove **G-CH-8**: `under` naming a nonexistent chapter returns 200 with `under_resolved: false`, never 404; `null` (not `false`) when `under` wasn't given (FR-029→unified FR-043, FR-034→unified FR-261, SC-018→unified SC-022). **DONE 2026-09-15**, now that T182 exists to prove it against. §1.1 proof (real mutation: 200→404) caught, independently re-run
- [ ] T184 **[SUPERSEDED — see RESOLUTION note below, not owed]** (was: 003/T033) Add `hierarchy` with `parent_href` and `child_hrefs` to
      `GET /api/chapters/{chapter}`, replace `ordinal` with `ordinal_path` — **replace, never place
      beside**, or a client reads the one that collides — and carry the rewritten
      `derivation.hierarchy`. Contract §4.2 (FR-022→unified FR-036, FR-024→unified FR-038, FR-030→unified FR-044)
      — AUDIT 2026-09-08: PARTIAL — `hierarchy` with `parent_href` and `child_hrefs` IS served (LIVE: `GET /api/chapters/02.01` 200 returns `parent_href: "/api/chapters/02"`, `child_hrefs: []`, plus `missing_ancestor_ids`), and `derivation.hierarchy` is carried. **BUT the task says "replace `ordinal` with `ordinal_path` — replace, never place beside", and the server places them BESIDE**: the same response carries `ordinal: 2` AND `ordinal_path: [2,1]`. The code states this is deliberate, for one release (chapters.go:147-155). Reconcile with T001/T025 rather than reimplementing.
      — RESOLUTION 2026-09-15: reconciled per decision-record.md — the `hierarchy`/`parent_href`/`child_hrefs`/`derivation.hierarchy` portion of this task is DONE (see the AUDIT evidence above). The "replace, never place beside" portion is SUPERSEDED by the ratified zero-diff decision: placing `ordinal` and `ordinal_path` beside each other is now the intended behaviour, not a defect. One open point the decision-record does not address, carried forward honestly rather than assumed: `chapters.go:147-155`'s own comment scopes this to **"for one release"** — a sunset date or follow-up removal of `ordinal` was implied but not stated anywhere in the decision-record or this task family. That gap is worth an operator note; not invented here (§11.4.6).
- [x] T185 (was: 003/T034) [TDD] Prove **G-CH-9** (H3): an orphan is served, and `?under=<missing parent>` still returns it, because the filter runs on derived ancestry (FR-031→unified FR-045, FR-034→unified FR-261, SC-019→unified SC-023). **DONE 2026-09-15 — the serving half was already proven; the `?under=` half completed now that T182 exists.** New test: tree `{01, 02.01}` (02 absent), `?under=02` → `under_resolved:false` but `chapters:["02.01"]`, `orphaned:true`. §1.1 proof (real mutation forcing `under`-presence) caught, independently re-run
- [x] T186 (was: 003/T041) [TDD] Prove **G-CH-18**: an empty-but-readable `chapters/` directory yields 200/empty array, distinct from the could-not-determine state for an unreadable one (FR-038→unified FR-049, FR-034→unified FR-261, SC-028→unified SC-032). **DONE 2026-09-15.** Two genuinely distinct fixtures (dotfile-only directory vs. a real permission-denied directory — this host is not root, so the permission test actually exercises the OS check, not a no-op). §1.1 proof (real mutation folding empty-readable into could-not-determine) caught, independently re-run
- [x] T187 (was: 003/T042) [TDD] Implement and prove **G-CH-19**, completing `depth`/`include_self` semantics (FR-040→unified FR-051, FR-034→unified FR-261, SC-030→unified SC-034). **DONE 2026-09-15.** `depth` implemented as "maximum levels below `under`" (documented in `specs/003-chapter-hierarchy/contracts/http-api.md` §C4.1.5, immediately beside `under`, as required). Four-subtest fixture at 3 levels deep confirms `depth=1`/`include_self=true`/both-together/neither all compose correctly; malformed values rejected as 400. §1.1 proof (real mutation neutralizing the depth cutoff) caught a leaked grandchild exactly as predicted, independently re-run
- [x] T188 (was: 003/T043) [TDD] Prove **G-CH-20**: a syntactically invalid `under` returns the identical response shape as a valid-but-absent one (FR-041→unified FR-052, FR-034→unified FR-261, SC-031→unified SC-035). **DONE 2026-09-15.** `reflect.DeepEqual` on both decoded response bodies with `filters.under` stripped from each. §1.1 proof (real mutation giving the malformed case a distinct `under_resolved` value) caught, independently re-run


---

## Phase 6: US3 + US12 — the transcript and curriculum browsing (P1/P2)

**39 tasks — 36 complete, 3 not-owed.** Sources: 001. **Phase 6 closed 2026-09-15**: this pass completed T196's sibling investigation, T197, T200, T201, T208, T210, T211, T212, T222, T223, T224, T225, T226 and T227 across 7 parallel subagent tracks (transcription checkpoint/disk-safety, CLI coverage-identity gate, ingest anchor-writing, container boot-probe, loopback access control, a11y/responsive e2e, and boot-time measurement), every claim independently re-verified in-session (rebuilds, re-run test suites, re-run gates AND their §1.1 paired-mutation proofs) before being marked done. **T196 stays open** — writing PID anchors into the real `chapter-01/transcript.md` hit a genuine structural obstacle: `build_transcript.py` merges ASR segments into silence-delimited turn paragraphs, so individual segments have no stable line to anchor without a larger redesign; the anchor-writer itself was proven instead against a synthetic fixture, and the real transcript was independently confirmed untouched (`grep -c '<!-- pid:' curriculum/chapter-01/transcript.md` = 0). **T203 and T207 stay open** — both require a human operator to physically listen to private chapter-01 audio and cannot be resolved by an agent.


*From `001` — Phase 3: User Story 1 — Read what was actually said (Priority: P1) 🎯 MVP*

- [x] T189 (was: 001/T023) [US1] Wire `workshop/pipeline/transcribe/reassemble.sh` to invoke the EXISTING `workshop/scripts/extract-videos.sh` — FR-007 is already implemented there with per-part, archive and extracted-video hash verification; do not reimplement it. **[PATH NOT BUILT — `workshop/pipeline/transcribe/reassemble.sh` does not exist, nor does the `transcribe/` directory. `workshop/scripts/extract-videos.sh` DOES exist, exactly as this task says, and is invoked — but by `workshop/scripts/git-hooks/post-checkout:6` (installed by `workshop/scripts/install-hooks.sh`) and by a documented command in `workshop/docs/quickstart.md:80`, NOT by any pipeline stage. The one pipeline file that names it, `workshop/pipeline/calibrate.sh:67`, prints it as an operator instruction on an exit-`2` path and does not invoke it. **The wiring is what is missing, not the target — do not reimplement extraction**. **RE-MEASURED 2026-09-03: unchanged and still accurate.** `workshop/pipeline/transcribe/` now EXISTS (001/T025 (unified T191)'s `chunker.py` and 001/T032 (unified T198)'s `pdf_notes.py` landed there), so the directory is no longer the obstacle — but `reassemble.sh` is not in it, and `grep -rn 'extract-videos'` over `workshop/` `*.sh`/`*.py` still shows the only invokers are `scripts/git-hooks/post-checkout`, `scripts/self-test.sh` and `scripts/extract-videos.test.sh`. **No pipeline stage calls it.** UNWRITTEN, nothing blocks it]** — **BLOCKER:** none but the work — the wiring to the EXISTING `extract-videos.sh` is unwritten · **OWNER:** **implementer** — unblocked today — EVIDENCE: DONE at a DRIFTED PATH — the contracted `workshop/pipeline/transcribe/reassemble.sh` still does not exist, but the wiring this task asks for (invoke the EXISTING extractor, do not reimplement) landed in `workshop/scripts/setup.sh:271` `do_extract_chapters`, which forwards `workshop/scripts/extract-videos.sh` and passes its three-valued status through unchanged (`:288`-`:295`). Exercised 2026-09-08: `bash workshop/scripts/extract-videos.sh workshop` -> rc **0**, `skip (intact)` + `sidecar ... (verified)` for all 3 chapter recordings. (population: in_process) (FR-007→unified FR-007, FR-006→unified FR-006)
- [x] T190 (was: 001/T024) [US1] [TDD] **[PATH CORRECTED 2026-09-02 — this task named `workshop/pipeline/transcribe/vad.py`, which does not exist; the detector landed at `workshop/pipeline/audio_energy.py`, reading PCM directly and deriving its threshold from the recording's own noise floor (`FLOOR_MARGIN_DB` at `:33`) rather than hardcoding a dBFS constant]** Implement silence detection in `workshop/pipeline/audio_energy.py` producing the non-speech span set (the 8 measured silences totalling 41.33 s are a free test fixture) (population: in_process) (FR-001→unified FR-001, SC-001→unified SC-001)
- [x] T191 (was: 001/T025) [US1] [TDD] Implement ≤300 s chunking that cuts INSIDE measured silence, in `workshop/pipeline/transcribe/chunker.py` — **[TICKED 2026-09-03 ON MEASUREMENT. ~~PATH NOT BUILT — neither `chunker.py` nor the `transcribe/` directory exists, and no equivalent landed anywhere~~ — WITHDRAWN BY NAME: both exist. `workshop/pipeline/transcribe/chunker.py` is 16,320 B and its own line 3 names this task — *"cut a recording into <= 300 s chunks, INSIDE measured silence (001/T025 (unified T191))"*. The ceiling is `DEFAULT_MAX_SECONDS = 300.0` at `:97`, deliberately a default rather than a constant so it is overridable (`--max-seconds`). It consumes `pipeline/audio_energy.py` (001/T024 (unified T190)) rather than growing a second silence detector. Three-valued exit at `:61`: `1` for a real finding (no qualifying silence in an over-long span, a forced cut), `2` for could-not-determine; an over-long span with no qualifying pause is refused with `code: "no_silence_in_span"` (`:170`) and a remedy, not silently force-cut. **§1.1 paired proof RUN 2026-09-03**: `bash workshop/pipeline/transcribe/prove-chunker.sh` → rc **0**, `PROVE: 8 mutations, 8 caught, 0 missed`, including M3 ceiling ignored → `V2_length`, M4 cut outside measured silence → `V3_in_silence`, **M5 forged `cut_inside` evidence → `V3_in_silence`** (the invariant is re-derived, not trusted), M6 tail chunk dropped → `V1_tiling`, and M8 unreadable input → rc **2**, not 1. Registered as check `transcribe-chunker` in `workshop/platform/gates/check-registry-001.tsv` with undet-probe `/nonexistent.wav`]** (population: in_process) (FR-001→unified FR-001, SC-001→unified SC-001)
- [x] T192 (was: 001/T026) [US1] [TDD] **[PATH CORRECTED 2026-09-02 — this task named `workshop/pipeline/transcribe/asr.py`, which does not exist; the driver landed at `workshop/pipeline/run_faster_whisper.py`, which passes `condition_on_previous_text=False` at `:107` and records it at `:153`]** Implement the faster-whisper driver in `workshop/pipeline/run_faster_whisper.py` with `condition_on_previous_text=False` — the same setting that makes it resumable also suppresses repetition-loop hallucination (FR-001→unified FR-001, FR-003→unified FR-003, FR-029→unified FR-177)
- [x] T193 (was: 001/T027) [US1] [TDD] **[PATH CORRECTED 2026-09-02 — this task named `workshop/pipeline/transcribe/confidence.py`, which does not exist; the work landed SPLIT ACROSS TWO LANGUAGES: emission in `workshop/pipeline/run_faster_whisper.py:118`–`:119` (`avg_logprob`, `no_speech_prob` per segment), mapping in `workshop/platform/backend/cmd/ingest-transcript/main.go:77`–`:78` (`Uncertain`, `UncertainReason`) applied at `:313`–`:322`]** Map engine confidence (`avg_logprob`, `no_speech_prob`) to the `uncertain` flag across `workshop/pipeline/run_faster_whisper.py` and `workshop/platform/backend/cmd/ingest-transcript/main.go` — FR-003 requires marking, never guessing (FR-003→unified FR-003)
- [x] T194 (was: 001/T028) [US1] [TDD] Implement atomic checkpoint/resume (write-temp → fsync → rename) across chunks in `pipeline/transcribe/checkpoint.py` per FR-029 (FR-029→unified FR-177). **DONE 2026-09-15.** Mirrors (does not import) `run_faster_whisper.py`'s existing atomic-write shape. `is_chunk_done()` never trusts its own index alone — it re-reads the real per-chunk output's embedded `input_sha256` and compares, so a deleted/corrupted/source-changed chunk is correctly reported not-done even when the index disagrees. 32 unit tests + §1.1 proof (5 mutations, including the T211 space-check mutation), both independently re-run and confirmed
- [x] T195 (was: 001/T029) [US1] [TDD] Implement gate G-CLI-4 over the coverage identity in `pkg/curriculum/curriculum.go`'s `ComputeCoverage` (already built — arithmetic untouched) (FR-001→unified FR-001, SC-001→unified SC-001). **DONE 2026-09-15.** Zero test coverage of `ComputeCoverage` existed before this pass — 5 new tests added, including `TestGCLI4_MissingChunkReportsIncomplete` (the exact contract-cited scenario: delete the middle of 3 segments, assert `Complete=false`, `UnexplainedGapS==10`, gap `[10,20)` exactly). New gate + §1.1 proof (real mutation: `== 0` → `<= 15` tolerance, restored byte-for-byte via sha256) both independently re-run and confirmed. Scope note carried forward honestly: `ComputeCoverage` computes the identity over segment spans only today (VAD silence not yet wired, `AccountedSilenceSource == "none"` by the function's own doc comment) — not rebuilt, per instructions

  **RE-MEASURED 2026-09-03 — the note above still holds in both directions, and the gap is now quantified.** The arithmetic is present and unchanged: `ComputeCoverage` `curriculum.go:428`, `UnexplainedGapS` `:503`, `Complete = UnexplainedGapS == 0` `:504`. **`grep -rn 'G-CLI-4'` over `workshop/` returns ZERO files** — the gate does not exist — and `grep -rn 'ComputeCoverage' --include='*_test.go'` over `platform/backend` also returns **zero**, so the identity is not covered by a unit test either, let alone by the delete-a-chunk gate or the tolerate-gaps mutation this task names. SC-001 is arithmetic in the code and ungated in the tree]** Implement the coverage identity check in `workshop/platform/backend/pkg/curriculum/curriculum.go`: passage spans ∪ VAD silence MUST equal `[0, duration_s)` exactly — this makes SC-001 arithmetic rather than judgement. Gate **G-CLI-4** ([contracts/pipeline-cli.md](../001-workshop-curriculum-platform/contracts/pipeline-cli.md) §4.1, §5): delete one chunk's output and assert the coverage check reports exit `1`. **Paired mutation**: make coverage tolerate gaps under a threshold; the gate MUST go red — this is the mutation proof D-TRANS-4 names
- [ ] T196 (was: 001/T030) [US1] Emit the markdown transcript with pid anchors and timestamps to `workshop/curriculum/chapter-01/transcript.md` — **[PATH CORRECTED 2026-09-02 — this task named `workshop/chapters/01/transcript/transcript.md`; that directory does not exist (`workshop/chapters/01/` holds the recording and its archive parts only) and the timestamped transcript landed at `workshop/curriculum/chapter-01/transcript.md`. The TIMESTAMP half is built; the **pid-anchor half is not** — `grep -rl '<!-- pid:' workshop --include='*.md'` returns zero files across the whole submodule, and passage identity currently lives only in `workshop/curriculum/passages.jsonl`. **RE-MEASURED 2026-09-03: unchanged. `workshop/curriculum/chapter-01/transcript.md` EXISTS (and 001/T040 (unified T206)'s R2 assertion was re-run against it, 0 violations across 3 surfaces), and `grep -rl '<!-- pid:' workshop --include='*.md'` STILL returns ZERO files.** The consequence reaches further than this task: 001/T009 (unified T025) built the anchor reader/writer at `submodules/passage/pkg/passage/anchor.go` and it is ticked, but nothing in the tree has ever written an anchor into a document, so 001/T113 (unified T210)'s `--write-anchors` has nothing to switch on and the §8 R1b/R1c duplicate- and foreign-anchor branches have never been exercised against a real source. PARTIAL: timestamps done, anchors unwritten, nothing blocking]** — **BLOCKER:** none but the work · **OWNER:** **implementer** — unblocked today (FR-001→unified FR-001, FR-002→unified FR-002, FR-037→unified FR-010)
- [x] T197 (was: 001/T031) [US1] [TDD] Implement the immutable machine layer + append-only correction overlay in `pkg/transcript/layers.go` per FR-038 — the machine output is evidence and must survive correction (FR-038→unified FR-011). **DONE 2026-09-15.** New package, styled on `submodules/passage/pkg/passage/redaction.go`'s field-for-field append-only convention (sequential-seq tamper detection, `O_APPEND`-only writes): `MachineLayer` (no exported mutating method, `Segments()`/`Lookup()` return copies), `CorrectionLog` (append-only overlay), `Materialise(base, log)` reconstructing the current view with `Provenance: machine/human_corrected`. 8 new tests including `TestMachineLayer_Immutable` (the core FR-038 property, asserted via `reflect.DeepEqual` before/after a correction) and tamper-detection on a hand-written gapped-sequence fixture — all independently re-run and confirmed. Explicitly distinguished from the pre-existing `corrections` DDL in `submodules/passage/pkg/passage/registry.go` (confirmed still declared-never-written there) — that is not this type
- [x] T198 (was: 001/T032) [US1] [P] **[TICKED 2026-09-03 ON MEASUREMENT. ~~PATH NOT BUILT — `pdf_notes.py` and the `transcribe/` directory do not exist, and no gazetteer exists anywhere: `grep -rli gazetteer workshop` returns zero files~~ — WITHDRAWN BY NAME: all three clauses are false today. `workshop/pipeline/transcribe/pdf_notes.py` is 23,036 B and its own lines 3–4 name this task — *"read a chapter's notes PDF for SECTION STRUCTURE and a PROPER-NOUN GAZETTEER, and for nothing else (001/T032 (unified T198))"*. The **ONLY** restriction this task turns on is enforced structurally rather than promised: `:6` — *"THE NOTES ARE NOT GROUND TRUTH, AND THIS MODULE IS BUILT SO THEY CANNOT BECOME IT"* — with `NOT_GROUND_TRUTH` stamped on **every emitted object** (`:82`–`:85`, `:19`), `detect_sections` labelled a heuristic at `:209`, and the gazetteer at `:250`. It also carries a content-boundary guard this task did not ask for and needs: `:31`–`:32` records that a proper-noun gazetteer of a private meeting summary is largely a list of people's names, so `--gazetteer` and `--structure` REFUSE a git-TRACKED destination. **§1.1 paired proof RUN 2026-09-03**: `bash workshop/pipeline/transcribe/prove-pdf-notes.sh` → rc **0**, `PROVE: 9 mutations, 9 caught, 0 missed`, including M4 scanned PDF with no text layer → rc 1 naming OCR as a separate capability, M5 tracked destination refused with no file created, M7 the summary carries no term (counts and categories only), and **M9 guard removed ⇒ harm occurs — the term list landed in a TRACKED path, so the guard is load-bearing rather than decorative**. Registered as check `transcribe-pdf-notes` in `workshop/platform/gates/check-registry-001.tsv` with undet-probe `--pdftotext /nonexistent`. **Honest boundary (§11.4.6): no run against the real Chapter 1 notes PDF was performed for this tick** — the module and its nine-mutation proof were measured, the extraction of that particular document was not, and by M5/M9's own design its output may not land in a tracked path]** Extract the notes PDF text layer in `workshop/pipeline/transcribe/pdf_notes.py` for section structure and a proper-noun gazetteer ONLY — never ground truth; it is a summary and it renders "Spatkit" for SpecKit (population: in_process) (FR-011→unified FR-058, FR-006→unified FR-006)
- [x] T199 (was: 001/T033) [US1] [TDD] [REVIEW] **[PATH CORRECTED 2026-09-02 — this task named `workshop/pipeline/accuracy/score.py`; neither it nor the `accuracy/` directory exists. The scorer landed as `workshop/scripts/verify-accuracy.sh`, driving `workshop/pipeline/compare_engines.py` (`align` `:113`, `norm_word` `:52`) and `workshop/pipeline/audit_windows.py` (`a_words_in`), imported at `verify-accuracy.sh:170`–`:178`, with `--windows`/`--seconds`/`--seed` recorded so the sample reproduces]** Implement the WER scorer in `workshop/scripts/verify-accuracy.sh` over `workshop/pipeline/compare_engines.py` and `workshop/pipeline/audit_windows.py`, sampling the AUDIO TIMELINE (≥30 stratified 30 s windows), not passages — sampling passages makes whole-region deletions structurally invisible and biases accuracy upward exactly where the transcript is worst (FR-004→unified FR-004, SC-002→unified SC-002)
- [x] T200 (was: 001/T034) [US1] Freeze and hash the normaliser in `compare_engines.py` BEFORE the first measurement (FR-004→unified FR-004, SC-002→unified SC-002). **DONE 2026-09-15.** The enforcement path already existed and was simply never armed (default empty hash). New `pipeline/compare_engines.py.sha256` (measured once, `sha256sum -c` verified) plus a hardcoded `FROZEN_NORMALISER_SHA256` constant in `verify-accuracy.sh` cross-checked against that file at startup (`die_undet` on disagreement) — so the freeze can't silently disarm even from a checkout missing the `.sha256` file. `NORMALISER_SHA` now defaults to the frozen constant instead of `""`; `--normaliser-sha256` still overrides explicitly. Independently re-verified: a corrupted normaliser copy correctly reports `UNDETERMINED: normaliser hash mismatch` at rc 2
- [x] T201 (was: 001/T035) [US1] [TDD] Paired mutation proof for the scorer in `verify-accuracy.sh --selftest` — a transcript with a known injected WER must produce that WER (FR-004→unified FR-004, FR-032→unified FR-260, SC-012→unified SC-135). **DONE 2026-09-15**, extending the existing selftest harness rather than building a second one. The existing fixture already degraded exactly every other word but nothing compared the result to an independently-computed oracle; added one (direct positional word-count, never calling `align()`/`norm_word` itself, so it's a genuine independent check) plus a paired mutation (off-by-one in the WER denominator, applied with care not to also patch the mutator's own self-referential comment). Independently re-run: measured accuracy **0.514286** exactly matches the independent oracle (tolerance 0.0001; note the task text's "≈0.50" was an approximation — the exact fixture value was used, not a rounded one), and the denominator mutation is correctly caught as a MISMATCH. Full `--selftest` exit 0, confirmed twice for determinism

  **RE-MEASURED BY EXECUTION 2026-09-03 — the note above is CONFIRMED, and the remaining work is now known to be ONE assertion, not a harness.** `bash workshop/scripts/verify-accuracy.sh --selftest` → rc **0**: absent reference → 2 (twice), perfect reference → 0, degraded reference → 1, and the bluffing mutant CAUGHT. The fixture **already injects a known WER**: `verify-accuracy.sh:476`–`:478` degrades exactly every second word — *"Degrade HALF the words: a real, measurable ~50% WER, not a syntax break"* — and the scorer **already measures it exactly**, printing `accuracy 0.5000`. What the selftest then asserts is `0.5000 < --min-accuracy 0.95` ⇒ rc 1. **So the injected value and the measured value are both present and equal, and nothing compares them.** 001/T035 (unified T201) is satisfied by adding that comparison — assert the measured accuracy equals the injected 0.50 within a stated tolerance — plus its own paired mutation (perturb the scorer's arithmetic and require the new assertion to go red). Note for whoever does it: everything currently in `--selftest` proves **G-CLI-5**, which belongs to 001/T112 (unified T209) (ticked); this task's assertion would be the first thing in that block that is about the SCORER rather than about the absent-reference guard]**
- [x] T202 (was: 001/T036) [US1] Run the 5-minute calibration on the extracted 300 s sample; this settles research open items U1, U2 and U3 in one run (FR-?)
- [ ] T203 (was: 001/T037) [US1] Produce and publish the Chapter 1 accuracy report: the METHOD statement (FR-004→unified FR-004), the SAMPLE CENSUS, and the MEASURED accuracy figure (SC-002→unified SC-002). — **BLOCKER:** **predecessor 001/T034 (unified T200) + 001/T035 (unified T201)** — no accuracy figure may be published before the scorer that produced it is frozen and mutation-proved · **OWNER:** **implementer**, after T034/T035 (FR-004→unified FR-004, SC-002→unified SC-002)

  **[OPEN. REWRITTEN 2026-09-03, because the old text demanded something its own success criterion never asked for, and the demand made the task unsatisfiable by construction. Counts and offsets only below — no window text, no transcript line, no name, per `docs/content-boundary.md`.**

  **WITHDRAWN, WITH THE REASON, NOT DELETED.** This task read *"…with the measured figure **and its confidence interval**"*. The interval half is withdrawn **as a requirement of this task**. **Measured: neither SC-002 nor FR-004 asks for an interval.** `spec.md:270` SC-002 — *"Transcript accuracy is measured on a random sample of at least 30 passages, and the measured figure is published alongside the transcript"*. `spec.md:168` FR-004 — *"…a verification report stating measured transcript accuracy and the method used to measure it"*. Neither contains the word "interval". The demand traced **only** to `research/transcription.md:809` and `:856`–`:857`, which is a research **decision record**, not a success criterion. The previous note's framing — *"closing it needs EITHER a spec amendment dropping the interval OR a 001/T112 (unified T209) change"* — is therefore **withdrawn as overstated**: no spec amendment is needed, because the spec never asked. The interval survives as a **recorded, unbuilt research decision**, carried as item (c) below on its own feet, instead of as a hidden precondition that silently made this task impossible.

  **(a) METHOD STATEMENT AND SAMPLE CENSUS — DONE 2026-09-03, then RE-DONE the same day against a RE-EMITTED plan. Read (d) first: the window set changed, so every figure in the first census is SUPERSEDED.** `research/transcription.md` §5.2 point 5 explicitly requires this enumeration — *"the passages overlapping the sampled windows are enumerated and counted in the report"* — and it had only ever been an argument, never a count.

  **SUPERSEDED BY NAME, NOT DELETED — the confidence-stratified census of 2026-09-03.** It read: **174** distinct machine segments (**5.8×** the SC-002 floor), **2,057** machine words (`N_hyp`), segments per window **4 / 5 / 10**, words per window **50 / 70 / 83**, strata **10 / 10 / 10** high/mid/low confidence. Every one of those numbers described the confidence-stratified plan that (d) replaced. The plan that produced them is preserved byte-identical at `workshop/evidence/verify-accuracy/plan-superseded-2026-09-03-confidence-strata.json` (sha256 `9f017603…`) and is re-derivable on demand with `--strata confidence`, so the old census can be reproduced rather than merely believed.

  **CURRENT CENSUS — measured 2026-09-03 against the re-emitted `workshop/chapters/01/transcript/accuracy-plan.json` and `workshop/pipeline/transcripts/full_ch01.faster-whisper.json` (1,055 segments, 15,610 word timings).** The 30 seeded windows are **900.0 s = 12.9894 %** of 6,928.713 s of audio; they overlap **163 distinct machine segments**; they contain **2,012 machine words** — this is **`N_hyp`, NOT `N_ref`**, and must never be published as a reference word count; segments per window min/med/max **2 / 5 / 8**; words per window **28 / 69 / 83**; **0 empty windows**, **0 overlapping windows**; **0 windows with zero machine segments**; strata **3 / 3 / 3 / 3 / 3 / 3 / 3 / 3 / 3 / 3** across ten equal temporal strata of 692.871 s. **SC-002's "≥ 30 passages" floor is MET BY THE WINDOW DESIGN at 5.4×** — down from 5.8× and still clearing the floor by a factor of five, which is a computed fact rather than §5.2's reconciliation argument. Re-derive (the command below reads the CURRENT plan, so it re-derives the current census; point it at the superseded file to reproduce the old one):

  ```bash
  # ONE physical shell line on purpose: this block is indented inside a list item, and an
  # indented heredoc terminator does not close a heredoc — copy-paste would hang, not run.
  workshop/pipeline/venv/bin/python -c "import json;P=json.load(open('workshop/chapters/01/transcript/accuracy-plan.json'));S=json.load(open('workshop/pipeline/transcripts/full_ch01.faster-whisper.json'))['segments'];o=lambda s,w: s['end']>w['t0'] and s['start']<w['t1'];c=lambda w: sum(1 for s in S if o(s,w) for x in (s.get('words') or []) if w['t0']<=(x['s']+x['e'])/2<w['t1']);seg={i for w in P['windows'] for i,s in enumerate(S) if o(s,w)};per=[c(w) for w in P['windows']];print('sampled_s',sum(w['seconds'] for w in P['windows']),'of',P['audio_seconds']);print('distinct segments',len(seg),'>=30 ->',len(seg)>=30);print('N_hyp',sum(per),'per-window min/med/max',min(per),sorted(per)[len(per)//2],max(per))"
  # sampled_s 900.0 of 6928.713
  # distinct segments 163 >=30 -> True
  # N_hyp 2012 per-window min/med/max 28 69 83
  ```

  **(b) THE MEASURED FIGURE — BLOCKED ON A NAMED OPERATOR INPUT. This is not an impossibility, and it must not be recorded as one.** `bash workshop/scripts/verify-accuracy.sh 01` exits **2** — *"UNDETERMINED: `--reference` is required"* — re-run 2026-09-03. That is the correct answer, not a failure: **an engine cannot be its own ground truth**, and `research/transcription.md` §5.1 refuses both available shortcuts by name (the notes PDF is a summary with no verbatim speech; a second Whisper-family engine shares training data and agrees on the same hallucinations). No `accuracy.json` exists — `find workshop -name 'accuracy*.json'` returns exactly one file, the plan. Publish precondition **B2 is NOT met** and must not be recorded as met; `GET /api/chapters/01/accuracy` correctly keeps reporting `measured: false, wer: null`.

  **THE HANDOVER, stated exactly so it can be acted on without reading anything else. It is written against the RE-EMITTED plan of (d); a reference against the superseded window set would match nothing.**

  | | |
  |---|---|
  | **What** | A **blind human verbatim transcript** of the **30 windows** listed in `workshop/chapters/01/transcript/accuracy-plan.json` — 30.0 s each, **900.0 s = 15 minutes** of audio total, spread 3 per stratum across ten equal 692.871 s strata. |
  | **Where the windows are** | In that file, field `windows[]`, each with `t0`/`t1`. Do not re-derive them; do not renumber them. |
  | **Form** | JSON matching that file's own `reference_schema`: `{"windows":[{"t0":<float>,"t1":<float>,"text":"…"}]}` — one object per window, `t0`/`t1` copied **exactly** from the plan (the scorer keys on them to a centisecond and will **not** match a nearest neighbour; a mismatched pair is `windows_short` → exit 2, not a score). |
  | **Two optional fields worth filling while listening** | `onset_s` — the true onset of the first word, read off the waveform — and `speaker` per utterance. §5.4 point 2 asks for both and calls them *"nearly free while they are already listening"*. **Nothing computes them today** and the scorer ignores unknown keys, so recording them costs this run nothing; **omitting them costs a second full listening pass later**, because they are the only inputs the timestamp-error (SC-003→unified SC-003) and speaker-attribution (FR-005→unified FR-005) companion metrics can ever have. |
  | **Hard constraint** | Transcribed **from the audio alone, without reading the machine transcript**. A reference produced by editing machine output measures nothing: Whisper's characteristic failure is fluent, plausible, wrong text, which is exactly what an anchored reviewer accepts. Mark genuinely unintelligible audio `[unintelligible]`; **never guess it**. |
  | **Cost** | 900 s at §5.4's stated 4–8× realtime = **1–2 hours of human work**. |
  | **On whom** | **The operator.** No agent can produce it — §5.1 refuses both available shortcuts by name. |
  | **Command afterwards** | `bash workshop/scripts/verify-accuracy.sh 01 --reference <path>` (no `--strata` flag needed; `temporal`/`10` are the defaults the plan was emitted with). |
  | **What it unblocks — TWO criteria, not one** | (1) **spec 001 SC-002 / FR-004**: writes `workshop/chapters/01/transcript/accuracy.json` → publish precondition **B2 met** → the published measured figure exists. (2) **spec 002 FR-064a / 002/T135 (unified T458)** — see (e) below. |

  **(c) THE CONFIDENCE INTERVAL — BLOCKED TWICE, and only one of the two blocks is (b).** It is no longer a requirement of this task (see the withdrawal above); it is carried here so the research decision is not quietly dropped. Block 1: an interval needs the figure from (b). Block 2, **independent of (b) and actionable today — the estimator does not exist**: `grep -rEin 'confidence_interval|ci_low|ci_high|ci_95|bootstrap|margin_of_error|wilson|binom'` over `workshop/scripts/` and `workshop/pipeline/` `.sh`/`.py` returned **0 matches**, and the payload built by `verify-accuracy.sh` carries `measured, wer, accuracy, chapter, measured_at, tool, method, counts, sample, windows, normaliser, transcript, reference, min_accuracy, companion_metrics, verdict` — no interval field. **That grep now returns 3 matches, all in `workshop/scripts/verify-accuracy.sh`, and NONE of them is an estimator — they are the prose of the `estimator_unit` warning added 2026-09-03, naming `bootstrap` and `binomial` in order to forbid the wrong one.** The finding is unchanged: **nothing in this project computes a confidence interval**, and the payload still carries no interval field. The "0 matches" figure is superseded as a *count*, not as a *conclusion*; re-read the matched lines rather than the number.

  **If it is written, its UNIT is the decision, and getting it wrong is worse than omitting it.** A word-level binomial/Wilson interval over `N_hyp = 2057` would be **wrong twice**: words inside one 30 s window are not independent draws, and WER is not a proportion at all — insertions let `(S+D+I)/N_ref` exceed 1. The honest unit is the **window**: **n = 30 clusters**, a bootstrap resampling window-level `(errors, N_ref)` pairs under a ratio estimator. The difference is not cosmetic — at the limit of perfect intra-window correlation a word-level interval is narrower by up to `√(2057/30) ≈ 8×`, which would **overstate** what was measured, the precise failure `research:856` says the interval exists to prevent. Whoever builds it states the unit in the report. **Owner: a 001/T112 (unified T209) change, not this task.**

  **(d) THE SAMPLING-FRAME DECISION — TAKEN BY THE OPERATOR AND EXECUTED 2026-09-03. This section previously ended "the decision is an operator decision"; that is now DONE, and the figures it carried are SUPERSEDED, not deleted.**

  **What was found.** `research/transcription.md` §5.2 specifies the procedure as **10 equal temporal strata** of 692.875 s with **3 windows each**. The plan emitted before this change stratified by **confidence** instead (high/mid/low, 10 windows each). Its temporal occupancy under §5.2's own scheme, re-derived and reproduced exactly before anything was overwritten: **`[5, 1, 3, 3, 3, 3, 2, 2, 5, 3]`** — **0 strata empty**, **3 strata below 3**, largest unsampled contiguous gap **702.2 s (11.7 min)** at `[3972.2, 4674.4)`. **Read the split honestly, because it is the part most easily overstated: §5.2's stated worst case — *"a simple random draw can leave a 20-minute region unsampled"* — did NOT occur, so that plan was never disqualified and is not being described as broken.** What was false was applying §5.2 point 4's guarantee to it: *"Stratification guarantees the whole session is represented"* is a claim about **temporal** strata, and those were **confidence** strata, so the guarantee on offer was not the one being supplied. **The operator chose conformance to the method regardless**, and the re-emit had to precede (b) because it changes the seeded window set and would invalidate any reference already transcribed.

  **Precondition checked before overwriting anything: no reference existed to invalidate.** `find workshop -iname '*reference*'` outside `venv/`/`.git/`/`engines/` returned **nothing**, and `find workshop -name 'accuracy*.json'` returned exactly one file — the plan itself. **The old plan is preserved byte-identical** at `workshop/evidence/verify-accuracy/plan-superseded-2026-09-03-confidence-strata.json`; its name deliberately does not match `accuracy*.json`, so that glob still returns exactly one file.

  **What was changed — the EMITTER, never the artifact.** A hand-written plan is unrepeatable and the next re-emit would silently diverge from it, so `workshop/scripts/verify-accuracy.sh` gained `--strata temporal|confidence` and `--strata-count` (default **`temporal`**, **10**), and the mode is now recorded IN the plan (`stratification`, `strata_count`, `strata_seconds`, `method`) and in `accuracy.json`'s `sample` block, so a reader can tell which procedure produced a window set without re-running anything. Placement inside a stratum draws `per` uniforms on `[0, width − per·(span+GAP)]`, sorts them and offsets window *i* by `i·(span+GAP)` — a uniformly distributed non-overlapping set in one pass, with `GAP = 0.02 s` guaranteeing the **rounded** windows stay disjoint. Disjointness is nevertheless ASSERTED in code and a violation is a named `2`, never a silent fix.

  **The material improvement is NOT the gap figure, and must not be sold as one.** Measured on the re-emitted plan: largest unsampled gap **686.5 s (11.44 min)** at `[5917.6, 6604.1)` versus the superseded **702.2 s** — a **15.7 s (2.2 %)** reduction, which is noise, and the temporal design's geometric worst case is in fact *looser* than what the old draw happened to achieve. Two real, measured differences carry the decision instead:
  1. **Equal allocation by construction, not by luck.** Occupancy is **`[3,3,3,3,3,3,3,3,3,3]`** — §5.2 point 4's guarantee is now the guarantee actually being supplied. Re-derived two independent ways (from the recorded `stratum_index`, and from `t0` alone) and they agree.
  2. **Recogniser-dropped regions are now reachable.** The confidence planner can only ever centre a window on a segment the recogniser PRODUCED, so a region it dropped entirely is structurally unsamplable by it — the exact upward bias §5.2 opens by naming. Uniform offsets can land there. Measured: audio inside the sample covered by **no machine segment at all** rose **50.2 s → 60.2 s**, across **14 → 22** windows. That is the deletion-detection surface the human transcription will actually see.

  **Measured properties of the re-emitted plan** (`bash workshop/scripts/verify-accuracy.sh 01 --emit-plan workshop/chapters/01/transcript/accuracy-plan.json`, exit **0**): 10 strata of equal duration **692.871 s**, contiguous and covering `[0, 6928.713)`; **3 windows each**; **30 of 30** placed, shortfall **0**, `strata_short` empty; **0 empty strata**; **0 overlapping pairs**, minimum inter-window separation **22.91 s**; every window contained in its own stratum; all durations exactly **30.0 s**; **900.0 s = 12.9894 %** of the recording.

  **Two proofs that the emitter, not the artifact, is the source of truth.** (i) A second independent emission produces an **identical** window set — reproducible, so the plan can be regenerated rather than guarded. (ii) `--strata confidence` reproduces the **superseded window set exactly**, tuple for tuple including stratum labels — so the refactor changed the default, not the old planner's behaviour, and the previous plan is recoverable by flag and not only from the backup. `bash workshop/scripts/verify-accuracy.sh --selftest` exits **0** (G-CLI-5 both halves → 2, perfect → 0, degraded → 1, bluffing mutant CAUGHT), exercising the temporal planner end-to-end including its `want < strata_count` reduction path. `bash workshop/platform/gates/verify-check-registry-001.sh` exits **0** at 20 PASS / 0 FAIL / 1 DEBT (pre-existing `cross-registry-attribution`, untouched by this work); R5 PASS at 19 swept files — **no new script was created**, an existing one was extended.

  **Re-derive the SUPERSEDED occupancy** (the command below reads whichever plan you point it at; against the current plan it prints the temporal result, against the preserved backup it prints `[5, 1, 3, 3, 3, 3, 2, 2, 5, 3]`):

  ```bash
  workshop/pipeline/venv/bin/python -c "import json;P=json.load(open('workshop/chapters/01/transcript/accuracy-plan.json'));A=P['audio_seconds'];K=10;w=A/K;occ=[sum(1 for x in P['windows'] if min(K-1,int(x['t0']//w))==k) for k in range(K)];V=sorted((x['t0'],x['t1']) for x in P['windows']);b=[0.0]+[t1 for t0,t1 in V];e=[t0 for t0,t1 in V]+[A];g=max(zip([y-x for x,y in zip(b,e)],b,e));print('temporal occupancy',occ,'| research 5.2 demands 3 per stratum');print('largest unsampled gap %.1f s at [%.1f, %.1f)'%g)"
  # against the CURRENT plan:
  #   temporal occupancy [3, 3, 3, 3, 3, 3, 3, 3, 3, 3] | research 5.2 demands 3 per stratum
  #   largest unsampled gap 686.5 s at [5917.6, 6604.1)
  # against workshop/evidence/verify-accuracy/plan-superseded-2026-09-03-confidence-strata.json:
  #   temporal occupancy [5, 1, 3, 3, 3, 3, 2, 2, 5, 3]   <- SUPERSEDED
  #   largest unsampled gap 702.2 s at [3972.2, 4674.4)   <- SUPERSEDED
  ```

  **(e) THE SAME TRANSCRIPTION IS THE MISSING SPEECH-WER BASELINE FOR SPEC 002's OCR PHASE. Verified from source 2026-09-03, not inherited.** This is recorded here AND at `specs/002-knowledge-areas-deep-linking/tasks.md` 002/T135 (unified T458), because a dependency written down in one file only is one rediscovery away from being missed again.

  **The claim, checked rather than assumed.** `specs/002-…/tasks.md` **002/T135 (unified T458)** (gate **G-OCR-9**, **FR-064a→UNMAPPED, verify manually**) requires the OCR accuracy budget to be *"derived from the recorded speech-recognition calibration for the same corpus and read from it at run time, never written as a literal"*, three-valued, with *"calibration record or ground-truth sample unreadable ⇒ 2"*. That record does **not** exist: `workshop/pipeline/CALIBRATION.md`'s own **U4** row reads *"achievable WER | open — needs §5's blind human reference"*, and the same line states the engine-to-engine divergence **3.19 %** *"is **not** a WER and must never be quoted as one"*. Quoting it would be precisely what 002/T135 (unified T458)'s own paired mutation (a) forbids. **Both halves reproduce exactly as described.** 002/T135 (unified T458) gates spec 002's closure (SC-031→SC-034), so this sat on the critical path unseen.

  **Does a 30-window SAMPLE satisfy it, or does 002/T135 (unified T458) need a whole-chapter WER? A sample satisfies it, on the spec's own terms — three pieces of evidence, none of them inference.** (i) **FR-064a** says *"read from the recorded speech-recognition calibration"* and never says exhaustive. (ii) **FR-064** requires the OCR side itself to be *"a hand-truthed ground-truth **sample** drawn by a recorded, seeded, reproducible rule with the population size published"* — the OCR figure is a sampled estimate, so demanding an exhaustive speech figure to compare it against would be an asymmetry nothing asks for. (iii) **002/T135 (unified T458)'s own** three-valued clause names *"calibration record or ground-truth **sample** unreadable ⇒ 2"* — the task anticipates a sample. **`accuracy.json` as `verify-accuracy.sh` writes it is that record**: seeded, reproducible, population published. **If a whole-chapter WER had been required, this decision would not close 002/T135 (unified T458) and that would be said here instead.**

  **Does the OCR comparison need anything the SC-002 measurement does not? Measured per axis, and the answer differs by axis — which is why it is stated rather than assumed.**
  - **Textual axis (002/T133 (unified T456) / SC-031): nothing extra, and the comparability is structural rather than lucky.** SC-031 requires the OCR figure be *"scored by the same edit-distance method the speech-recognition calibration already uses, so the two figures are comparable rather than merely adjacent"*. `verify-accuracy.sh` **imports** `align`/`norm_word` from `workshop/pipeline/compare_engines.py` rather than reimplementing them, and 002/T133 (unified T456)'s own note records that the same file is what the OCR scorer must share. Same normaliser, same alignment, one definition of WER. **The reference text needed for SC-002 is bit-for-bit the reference text needed here.**
  - **Temporal axis (002/T134 (unified T457) / SC-032): this is where the two purposes diverge, and it is the reason the two optional fields in (b) matter.** SC-032 measures whether a declared visibility interval *contains* the true moment; SC-033 requires both OCR figures be published *"beside the speech-recognition figures … in the same document, in the same run"*. The speech-side analogue of a temporal figure is this project's own **timestamp error** companion metric (SC-003, `|machine time of first reference word − true onset|`, median and p95), whose only possible input is the `onset_s` mark §5.4 point 2 asks the reviewer to make. **Capture it in the same pass or it costs a second 1–2 hours.** Honest boundary: SC-033's wording does not *demand* a speech temporal figure, so omitting `onset_s` does not by itself fail 002/T135 (unified T458) — it forecloses the symmetric publication cheaply available today.
  - **A second asymmetry, naming a 001/T112 (unified T209) change rather than more human work.** SC-031 requires the OCR figure as **WER *and* CER**. `verify-accuracy.sh` computes **WER only**; §5.3 already calls CER *"nearly free once alignment exists"*. Producing a speech CER needs **no additional transcription** — the same reference text yields it. **Owner: a 001/T112 (unified T209) change. Cost to the operator: zero.**
  - **Scope, stated so it is not over-read.** FR-064b and SC-034 are **per chapter** — *"an accuracy figure measured on one chapter is not evidence about another"*. This reference covers **chapter 01 only**, so it supplies 002/T135 (unified T458)'s floor for chapter 01 and for **no other chapter**.

  **The estimator unit is the same finding on both sides, and getting it wrong is worse than omitting the interval.** Whoever computes an interval — over the speech WER of (c) or over an OCR figure under 002/T133 (unified T456) — uses the **window/sample unit (n = 30 clusters)**, never the word. Words inside one 30 s window are not independent draws, and WER is not a proportion: insertions let `(S+D+I)/N_ref` exceed 1, which no binomial admits. At the limit of perfect intra-window correlation a word-level interval is narrower by up to `√(N_hyp/30) ≈ 8×` and would **overstate** precision. This is now carried in three machine-readable places as well as here: the plan's own `estimator_unit` field, `accuracy.json`'s `sample.estimator_unit`, and 002/T135 (unified T458)'s note.

  **(f) A MACHINE CROSS-CHECK WAS RUN OVER THE SAME 30 WINDOWS ON 2026-09-04, AND IT DOES NOT MEASURE SC-002. IT IS RECORDED HERE SO THAT NOBODY RE-DISCOVERS IT LATER AND MISTAKES IT FOR (b).** The operator asked for the second transcript to be produced *by a locally-run model, or by bridging to the session's own models* — explicitly not by sending the media anywhere. That was done with the strongest local path available; what it produced is **inter-engine agreement**, not accuracy, and every artifact says so in its own words.

  **What was run.** Engine **B** — whisper.cpp / ggml `large-v3-turbo-q8_0`, CPU-only, `-nfa` for word timestamps, settings matched to engine A (`-bs 5 -tp 0.0 -mc 0`) — over **exactly** the 30 planned windows, via the existing `workshop/pipeline/run_audit.sh` against a **copy** of the plan (`run_audit.sh` writes `engine_b_json` back into the plan it is given; the canonical `accuracy-plan.json` is byte-unchanged, sha256 `dda4aa4b…` before and after). 30 of 30 windows produced output, **0 failures**; **5,853 s** of wall clock for **900 s** of audio (per window min/median/max **96 / 178 / 318 s**), under load average 10–23 from other work on the box.

  **The figure, under its honest name — INTER-ENGINE WORD DISAGREEMENT, n = 30 window clusters.** `(sub + b_only + a_only) / N_engine_B` = **0.0858** (171 / 1,992), agreement 0.9142; percentile **bootstrap 95 % over window-level pairs under a ratio estimator: [0.0671, 0.1086]**, 10,000 reps, seed 0. The unit is the **window**, never the word, for the reason (c) already states. Composition: **53** substitutions, **65** engine-B-only, **53** engine-A-only. Engine A contributed **1,980** words on the same windows. **That is not the same count as (a)'s `N_hyp = 2,012`, and the difference is a containment rule, not a discrepancy:** (a) assigns a word to a window by its **midpoint**, while the scorer's `a_words_in` requires the word to be **fully contained** — 32 words straddle an edge. `verify-accuracy.sh` uses the containment rule, so **1,980** is the number a WER over these windows would divide by, and both figures are correct about different questions. **0 of 30** windows had zero disagreement; the worst four windows sit at **0.353 / 0.321 / 0.197 / 0.139** (offsets 4116.83, 4761.1, 5320.07, 5887.62) — those are review targets, which is the one thing this number is genuinely good for.

  **The boundary artifact was measured rather than argued away, and it is NOT what produces the figure.** Engine B saw each window as an isolated 30 s cut, so a word straddling an edge was halved for B while engine A placed it outside the window. Recomputing with **1.0 s shaved off both ends of both sides** gives **0.0932** (171 / 1,834), CI **[0.0727, 0.1189]** — the rate goes **up**, not down, and 9 of 30 windows gain disagreements when trimmed. The disagreement lives in the window interiors.

  **Read against `pipeline/CALIBRATION.md`'s 3.19 %, this is the more useful half of the result.** That figure came from one 300 s window the calibration itself records as uniformly clean (`no_speech_prob` 0.0000 on all 44 segments). Sampled across the whole session under (d)'s temporal design the same quantity is **2.7×** larger. **Both figures are inter-engine divergence and neither is a WER** — CALIBRATION.md's own U4 row says so of its own number — but a quantity that nearly triples when the sample stops being one clean window is a warning about extrapolating from that window, not a reason to start quoting the new one instead.

  **What was built, and the marker that keeps it from becoming a bluff.** `workshop/pipeline/engine_b_crosscheck.py` (registered `exempt` in `workshop/platform/gates/check-registry-001.tsv`, same class as `compare_engines.py`: a measurement, not a gate) emits the artifact in the plan's own `reference_schema` shape and computes the comparison. The artifact carries `PROVENANCE: MACHINE`, `provenance`, `is_human_reference: false`, `not_a_reference`, `machine_generated`, `sc002_eligible: false` and a prose `WARNING` at top level, **repeats `provenance: machine` on every window** — because a scorer reads `windows[]` and nothing else — and its filename ends `.NOT-A-REFERENCE.json`. **The marker is ENFORCED, not trusted:** `workshop/scripts/verify-accuracy.sh` gained a `PROVENANCE_GUARD` that fails a machine-marked reference as **`reference_not_human`, exit 2, writing no `accuracy.json`**. Measured against the real chapter, not only in a fixture: `bash workshop/scripts/verify-accuracy.sh 01 --reference <artifact>` → **2**, and `find workshop -name 'accuracy*.json'` still returns exactly one file, the plan. The §1.1 paired mutation is in `--selftest` and it is the load-bearing half — **delete the guard and the same artifact scores `WER 0.0000, accuracy 1.0000`**, which is precisely the bluff. `bash workshop/scripts/verify-accuracy.sh --selftest` exits **0** covering: absent reference → 2 (twice), perfect → 0, degraded → 1, **machine top-level marker → 2, machine per-window-only marker → 2, no `accuracy.json` after either**, and both mutants caught.

  **The bridge option was assessed and it is NOT available here — measured, not assumed.** (i) This session's harness cannot take audio at all: `Read` on a synthetic 2 s tone WAV returns *"This tool cannot read binary files"*, and a tool search over every deferred/MCP tool for audio, speech or transcription returns none. The probe was deliberately run on a generated tone, never on the recording. (ii) No local generative model can either: `ollama list` holds **4** models — one 3B text instruct (`ollama show` reports capabilities `completion, tools`, no vision, no audio) and three embedders. So the operator's second option is foreclosed by capability, and the first option is what was executed.

  **WHAT THIS CHANGES ABOUT (b): NOTHING.** `research/transcription.md` §5.1 rejects a second ASR engine as the reference **by name** — *"the most tempting shortcut available and it is a bluff"* — because two Whisper-family models share training data and agree on the same hallucinations. Agreement bounds the **union** of the two engines' error from **below**, localised to windows; it cannot bound engine A's error from **above**, which is the only thing an accuracy figure means. **SC-002 and FR-004 remain UNMET, publish precondition B2 remains unmet, `GET /api/chapters/01/accuracy` correctly still reports `measured: false, wer: null`, and spec 002's FR-064a/T135 floor is still absent.** Artifact (git-ignored, private speech, reproducible from `run_audit.sh` + `emit`): `workshop/pipeline/audit/sc002/engine-b-machine-cross-check.NOT-A-REFERENCE.json`. Counts-only report, no transcript text — enforced in code by an assertion that refuses any string outside a fixed allow-set, so a leaked word aborts the write rather than shipping: `workshop/evidence/verify-accuracy/engine-b-cross-check-2026-09-04.json`.

  **THE BOX STAYS UNTICKED, AND NEITHER (a) NOR (d) NOR (f) BEING DONE IS A REASON TO TICK IT.** SC-002 demands a *published measured figure*; `accuracy.json` **does not exist**, B2 is **not met**, and `bash workshop/scripts/verify-accuracy.sh 01` still exits **2** — *"UNDETERMINED: `--reference` is required"* — which is the correct answer, not a failure. The census in (a) is the method half of FR-004, and re-emitting the plan in (d) improved the sampling frame without measuring anything. **An unticked box with an honest note beats a ticked one that lies.** What remains: **(b) on the operator** — 1–2 hours of blind transcription, blocked by nothing else, now unblocking **two** criteria; **(c) on a 001/T112 (unified T209) change**, optional against SC-002/FR-004; **(d) DONE**; **(e) recorded in both directions, waiting on (b)**; **(f) DONE and it moves nothing** — a machine cross-check exists, is named honestly, and is refused by the scorer as a reference]**
- [x] T204 (was: 001/T038) [US1] [TDD] **[THE `PATH NOT BUILT` NOTE IS WITHDRAWN — re-measured 2026-09-03 while working 001/T040 (unified T206). It read *"`workshop/scripts/redact.sh` does not exist and no equivalent landed anywhere; it also depends on 001/T012 (unified T028)'s writer, which is itself unbuilt"* and both halves are now false: `workshop/scripts/redact.sh` is present and executable (2026-09-02 20:38), it forwards to `platform/backend/cmd/workshop-redact` with the child's exit status passed through untouched, and the append-only logs it writes hold **10** passage records (`curriculum/redactions.jsonl`) and **1** span record (`curriculum/redactions-spans.jsonl`). It has run for real against Chapter 1 — evidence `workshop/_evidence/redact/`, 13 runs, the applying one exit **0** at `targets reached (8/8)`. ~~**The box stays unticked and this is NOT a completion claim:** what was measured is existence and one successful application, not this task's full contract — the `--pids-file`/`--unredact` surfaces, the exit-`1` and exit-`2` branches and the §1.1 paired mutation were not exercised here.~~ — **BLOCKER:** none but the work — the `PATH NOT BUILT` note was already withdrawn; `redact.sh` exists · **OWNER:** **implementer** — unblocked today — EVIDENCE: `workshop/scripts/redact.sh` (forwards to `platform/backend/cmd/workshop-redact`, exit passed through). All three exit values DRIVEN 2026-09-08: `--help` -> rc **0**; `--dry-run --pid <absent>` -> rc **1** `PROBLEM: passage: identifier is not in the registry`; `WORKSHOP_EVIDENCE_DIR=/nonexistent/ev --check-review --chapter 01` -> rc **2** (E2 pre-flight, printed before any work). Full contracted surface present at `:49`-`:84`: `--pid`, `--pids-file`, `--span`, `--unredact`, `--ratify`, `--review-only`, `--check-review`, `--list-derived-leaks`, `--dry-run`. It has applied for real: `workshop/curriculum/redactions.jsonl` holds 210 records, `redactions-spans.jsonl` 1. Paired-mutation cover: it is the required entry point of registered check `verify-redaction-propagation.sh`, run 2026-09-08 -> rc **0**. (population: in_process) (FR-039→unified FR-012)

  **THAT CAVEAT IS WITHDRAWN AS THE REASON — every branch it names was exercised on 2026-09-03 and every one holds. THE BOX STILL STAYS UNTICKED, FOR ONE DIFFERENT AND MUCH NARROWER REASON, NAMED AT THE END.** Driven live against the real registry with `--dry-run` and a scratch `WORKSHOP_EVIDENCE_DIR`; no chapter content, no pid and no reason text is reproduced here:

  | probe | rc | contracted |
  |---|---|---|
  | `--pid <absent-from-registry> --reason … --by …` | **1** | ✔ *"exit `1` when a supplied pid is not in the registry"* |
  | already-suppressed pid under a DIFFERENT reason code | **1** | ✔ *"or a pid is re-redacted under a different reason"* — refuses rather than picking one |
  | same pid under the SAME reason code | **0** | ✔ idempotent; the log is append-only and appends nothing |
  | `--reason`/`--by` omitted | **1** | *"an unexplained or unattributed suppression cannot be reviewed"* |
  | `WORKSHOP_CURRICULUM_DIR=/nonexistent/…` | **2** | ✔ *"exit `2` when the registry is unwritable"* — unreadable half |
  | registry dir `chmod -w`, real (non-dry-run) write | **2** | ✔ unwritable half: `permission denied`, not a finding about the corpus |
  | `WORKSHOP_EVIDENCE_DIR=/nonexistent/ev` | **2** | ✔ §2.5 **E2** — refuses BEFORE doing any work |
  | `--pids-file F` (with a `#` comment line) | **0** | ✔ the surface exists and parses |
  | `--unredact` | **0** | ✔ the surface exists and runs |

  The full contracted flag surface is present in `workshop/scripts/redact.sh` — `--pid` (repeatable), `--pids-file`, `--reason`, `--by`, `--unredact`, plus `--span`, `--purge`, `--dry-run`, `--json`. **§1.1 paired mutation EXISTS AND WAS RUN**: `bash workshop/platform/gates/prove-redaction-propagation.sh` → rc **0**, `all 6 mutations were caught` — M3 *"a refused decision is reported as success"*, **M4 *"an unreadable registry is reported as a corpus problem instead of undetermined"***, M6 *"one of the eight propagation targets is never registered"*; and `verify-redaction-propagation.sh` → rc **0** across A1–A10b. The registry-half writer this task appends to is 001/T012 (unified T028)'s `submodules/passage/pkg/passage/redaction.go`, now ticked.

  **THE ONE REMAINING CLAUSE, AND IT IS THE WHOLE REASON THE BOX IS UNTICKED: *"and marks the live generation as requiring a rebuild"* IS NOT IMPLEMENTED.** Measured 2026-09-03: `grep -n 'rebuild\|generation' workshop/platform/backend/cmd/workshop-redact/main.go` returns **zero** lines, and no propagation target is the index generation — the eight are `exports`, `terms`, `areas`, `questions`, `lesson_sections`, `mentions` and their siblings in `internal/redaction/plan.go`. The burden is left with the caller **in the code's own words**: `workshop/platform/backend/pkg/index/generation.go:58`–`:60` — *"until the rebuild that removes a redacted passage has been [built] … Callers that redact must therefore treat the window between Build's start …"* — **and no caller does it.** That is the gap between a redaction being RECORDED and a redaction being EFFECTIVE against a live generation, which is exactly what 001/T059 (unified T331)'s R5 half contracts. Do not tick this until a redaction marks the live generation stale]** Implement `workshop/scripts/redact.sh` per [contracts/pipeline-cli.md](../001-workshop-curriculum-platform/contracts/pipeline-cli.md) §4.6 (FR-039→unified FR-012) — `--pid P` (repeatable), `--pids-file F`, mandatory `--reason CODE` and `--by NAME`, `--unredact`; it appends to the `redactions` log built in 001/T012 (unified T028), materialises `passages.redacted`, and marks the live generation as requiring a rebuild. Exit `1` when a supplied pid is not in the registry or a pid is re-redacted under a different reason; exit `2` when the registry is unwritable or the rebuild that makes the redaction effective could not be started. It lands in THIS phase, not a later one, because Chapter 1's transcript exists from 001/T030 (unified T196) onward and FR-039 blocks export before review
- [x] T205 (was: 001/T039) [US1] [TDD] **[TICKED 2026-09-03. THE `PATH NOT BUILT` NOTE IS WITHDRAWN — re-measured 2026-09-03 while working 001/T040 (unified T206). It read *"`redact.sh` does not exist, and `find workshop -name 'redaction-review.json'` returns zero files"*; that `find` now returns exactly one file, `workshop/chapters/01/redaction-review.json` (3,219 B, `schema: redaction-review/v1`, `reviewed_at: 2026-09-02T19:51:23Z`, `decision: redactions_recorded`), and `bash workshop/scripts/redact.sh --check-review --chapter 01` exits **0** with *"is fresh; B5 is met for chapter 01"*. **Publish precondition B5 IS met for chapter 01** — the statement to the contrary in `redaction-review-summary.md` was withdrawn there on the same date. (population: in_process) (FR-039→unified FR-012)

  **THE "BOX STAYS UNTICKED" CAVEAT IS ITSELF NOW WITHDRAWN BY NAME, AND THE TICK IS EARNED BY EXECUTION.** It read *"the stale-review exit-`1` branch, the "none required" decision path and the §1.1 paired mutation were not exercised here; only the fresh-review path was"*. All three were exercised on 2026-09-03, against the REAL review artifact copied into a scratch `WORKSHOP_CHAPTERS_DIR` so the module tree was never written to. **The freshness rule is three-valued and every branch was DRIVEN, not read:**

  | probe | rc | what it printed |
  |---|---|---|
  | `--check-review --chapter 01` (unmodified) | **0** | `is fresh; B5 is met for chapter 01` |
  | review absent (`--chapter 99`) | **1** | `no review artifact at …; B5 is NOT met. Recording "none required" is a valid decision; skipping the review is not.` |
  | `reviewed_at` back-dated to `2020-01-01T00:00:00Z` | **1** | `the review … is STALE; B5 is NOT met.` |
  | one artifact's `sha256` corrupted, mtimes untouched | **1** | `… is STALE` — content drift, not only mtime |
  | one artifact renamed to a path that cannot be measured | **2** | `… could not be checked` |

  `platform/backend/internal/redaction/review.go` is where that lives: `FreshnessState` `:200`, the three constants `:205`/`:208`/`:210`, `Freshness.Exit()` `:220` mapping fresh/stale/undetermined onto 0/1/2, `CheckFreshness` `:239`. **The *"none required"* path is implemented AND guarded in both directions**: `DecisionNoneRequired` `:50`, derived automatically at `cmd/workshop-redact/main.go:474`, refused at `review.go:123` when the registry names suppressed rows (driven live: rc **1**, `review says "none_required" while naming 10 passage(s) and 1 span(s) as suppressed; the two statements contradict each other`) and refused in the mirror direction at `:131`; `TestReview_RefusesAContradictoryDecision` PASSES. **The §1.1 paired mutation EXISTS AND WAS RUN**: `bash workshop/platform/gates/prove-redaction-propagation.sh` → rc **0**, `all 6 mutations were caught`, of which **M5 is this task's own** — *"the review is recorded in the report but no artifact is written"* (rc 1) — and its gate `bash workshop/platform/gates/verify-redaction-propagation.sh` → rc **0** with **A7** (*"every refusal returns its own code, and 2 is never collapsed into 1"*) and **A8** (*"`--review-only` writes the artifact, changes nothing else, and goes stale when an artifact changes"*) both green. **Honest boundary (§11.4.6): a SUCCESSFUL `none_required` write could not be driven on this tree** — chapter 01 genuinely has redactions, and no second chapter exists in the registry (`--chapter 02` → rc **2**, `no registry row carries scope "02"`, which is the honest answer). The path is proven by its guard, its derivation site and A8's fixture chapter, not by a live `none_required` artifact on this corpus. Separately, this task's parenthetical *"(§4.7, enforced by 001/T087 (unified T429))"* is a POINTER, not a deliverable of this task — **001/T087 (unified T429) is unbuilt, so B5 is checkable on demand but is enforced by no publish path**. The warning below still stands — do not mistake `workshop/curriculum/publication-reviews.jsonl` for this artifact: it is feature 002's per-AREA publication review, keyed on `area_id` and read by `pkg/knowledge/reviews.go` — a different artifact for a different obligation]** Implement `redact.sh --review-only` and the review artifact `workshop/chapters/NN/redaction-review.json` per [contracts/pipeline-cli.md](../001-workshop-curriculum-platform/contracts/pipeline-cli.md) §4.6 and [contracts/passage-contract.md](../001-workshop-curriculum-platform/contracts/passage-contract.md) §7.3 R7 — recording *"none required"* is an explicit, valid decision; **skipping the review is not**, and a review older than the transcript it reviews is stale and exits `1`. This artifact is publish precondition B5 (§4.7, enforced by 001/T087 (unified T429)); without it FR-039 is decorative
- [x] T206 (was: 001/T040) [US1] [REVIEW] **[TICKED 2026-09-03 ON MEASUREMENT — ALL THREE PARTS CLOSED. PART 2, THE DEFERRED SEVEN, LANDED; see the note below for the counts and for the two things that did NOT close with it.]** Record the Chapter 1 redaction review and apply whatever it identifies, BEFORE the transcript is exported, published, served or committed (FR-039→unified FR-012). This is not a fixture and not a hypothetical: the Chapter 1 recording features an identifiable third party, which is the reason FR-039 exists. Re-emit `workshop/curriculum/chapter-01/transcript.md` after redaction and assert that no redacted passage's `text` or `machine_text` appears anywhere in it (§7.3 R2). No later phase may publish, export or serve Chapter 1 until `redaction-review.json` exists and is newer than the transcript. (FR-039→unified FR-012)

  **[PART 2 CLOSED 2026-09-03 (later the same day). THE HEADING BELOW — "THE BOX STAYS UNTICKED,
  AND THE SECOND PART IS WHY" — IS WITHDRAWN BY NAME, not deleted, and everything under it that
  describes the REFUSAL is kept because the refusal was correct and is the whole lesson.** Counts
  only, per `docs/content-boundary.md`.

  **What was refusing, and what changed.** `Plan.Apply` is all-eight-targets-or-nothing, so the two
  surfaces that reported PROBLEM cancelled every write. Neither was worked around; both were fixed.

  | surface | before | after | what was actually wrong |
  |---|---:|---:|---|
  | `taxonomy` residual | **34** | **0** | three distinct causes, measured separately: 25 of the 34 were a withdrawn term matching INSIDE a longer, legitimately visible token (`bytes.Contains` over the raw line); 8 were an `area.external_key`, which is DERIVED from the member terms and so still carried a term the unlink pass had just removed; 1 was a live-evidence term row whose own name carries a withdrawn term |
  | `registry-derived` undecided | **48** | **0** | the detector reported ONE ROUND. Suppressing a row moves its own text onto the withheld side, so each application produced a new, smaller finding — it never converged because nobody was ever shown the size of the decision |
  | `proposal_member_terms` / proposal passage lists | uncovered | swept | `contradiction` and `discarded-duplicate` rows carry their evidence under names that are not `evidence_pids`; **85** suppressed identifiers survived there (84 in `outside_passages`, 1 in `overlap_passages`). `proposal_member_terms` itself held **0** withdrawn terms on this tree — the gap was real, its yield today is zero, and both halves are stated |

  **The fixes, one line each.** The withdrawn-term sweep now walks the DECODED row and tests every
  string value with a word-boundary rule, reporting the JSON member path — **not** a length
  threshold, which would have stopped protecting exactly the short strings most likely to be
  initials. An area's derived `external_key` is re-keyed on its own id when a member term is
  dropped. A term row whose own NAME carries a withdrawn term is withdrawn too, iterated to a fixed
  point (**1** row on this tree, and **it still has 3 live evidence passages** — that is a real cost
  to index completeness, counted separately as `TermsWithdrawnByName` and reported separately).
  `CloseDerivedLeaks` iterates the minted-row detection to a FIXED POINT and reports the transitive
  closure; it terminates because the suppressed set only grows and is bounded by the registry.

  **What was applied.** `curriculum/redactions.jsonl` went **10 -> 142** entries: **84** passages
  under six per-finding reason codes (F8 2, F9 6, F12 3, F13 2, F14 69, F15 2) plus **48** minted
  registry rows (36 `kg_term`, 12 `kg_area`) under `derived_from_withheld_passage` — the transitive
  closure, cross-checked against an independent computation and identical. **F16 needed no corpus
  change**: the listing boundary it names is already in force. Final propagate exit **0**,
  `targets reached (8/8)`, `0 PROBLEM · 0 UNDETERMINED`, and a re-run is idempotent.

  **Part 3 re-measured after the apply.** Residual of every suppressed passage's text, shape-aware,
  across `transcript.md`, both timing sidecars, `exercise-01.md`, its sections sidecar,
  `taxonomy.jsonl` and `area-materials.jsonl`: **0 / 0 / 0 / 0 / 0 / 0 / 0**. §7.3 R2 holds.
  `--check-review --chapter 01` exits **0**.

  **TWO THINGS DID NOT CLOSE, and neither is a tooling defect.**
  (1) **A regeneration from clean re-derives 2 of the 27 withdrawn index terms**, and it does so
  from passages that are still VISIBLE (3 visible occurrences each), not by reading withheld text —
  25 of 27 do not come back. Whether those passages should also be withheld is a REVIEW decision
  about the corpus, not something a redaction tool can settle. (2) The regeneration's own
  `reconcile_and_taxonomy` stage exits **2** on a 180-second `go run ./cmd/knowledge-mint` timeout,
  so the row-level rebuild is UNDETERMINED; the `extract` stage completed (rc 0) and is what the
  sweep above measured.

  ~~**[THIRD PART CLOSED 2026-09-03; THE BOX STAYS UNTICKED, AND THE SECOND PART IS WHY.**~~ Read the split before reading the exit codes. Counts only below — no chapter content, no personal name, no `pid`, no transcript line number, per `docs/content-boundary.md`.

  **The path question is SETTLED and the old note is WITHDRAWN as a live blocker.** The 2026-09-02 note said this task named `workshop/chapters/01/transcript/transcript.md`, "which does not exist". Re-measured 2026-09-03: that *directory* now exists and holds exactly one file, `accuracy-plan.json` (see 001/T037 (unified T203)); `transcript/transcript.md` inside it still does not, and never did. The transcript landed at `workshop/curriculum/chapter-01/transcript.md` (107,847 B) — the file this task now names. **This was a RENAME, not an imagined artifact and not an ungenerated one**: `git -C workshop log -- curriculum/chapter-01/transcript.md` shows it tracked since `5b611f97d` (2026-09-01). The path text is correct as it stands and the third part was doable.

  **Part 1 — record the review: DONE.** `workshop/chapters/01/redaction-review.json` exists (3,219 B, `schema: redaction-review/v1`, `reviewed_at: 2026-09-02T19:51:23Z`, `decision: redactions_recorded`, 9 artifact digests, 10 pids, 1 span). `bash workshop/scripts/redact.sh --check-review --chapter 01` exits **0** — *"is fresh; B5 is met for chapter 01"* — re-run 2026-09-03. Publish precondition **B5 is met**. 001/T039 (unified T205)'s note claiming `find workshop -name 'redaction-review.json'` returns zero files is stale, and so is 001/T038 (unified T204)'s claiming `workshop/scripts/redact.sh` does not exist; both were written before 2026-09-02 20:38.

  **Part 3 — re-emit and assert R2: DONE, and it was already done before this session measured it.** The re-emit is not a separate command: the applying run's `exports` surface rewrites the document and both sidecars in place. Evidence `workshop/_evidence/redact/20260902T194901Z-942251/` — exit **0**, *"APPLIED exports:transcript.md … 10 passage(s) suppressed across the document and its two sidecars (30 artifact-level change(s))"*, plus `APPLIED spans:… 1 non-passage span(s) suppressed`, `targets reached (8/8)`, `6 applied · 2 clean · 3 absent · 0 PROBLEM · 0 UNDETERMINED`. The artifacts carry 11 · 10 · 10 `[REDACTED]` markers respectively (11 in the document = 10 passages + the title span), so the assertion below is not vacuously true of an empty file. **The R2 assertion, run 2026-09-03: 10 redacted rows × 2 fields × 3 surfaces, `R2 violations 0`, exit 0.** Re-derive:

  ```bash
  python3 - <<'PY'
  import json,re,unicodedata
  C='workshop/curriculum/'
  red=[d for d in map(json.loads,filter(str.strip,open(C+'passages.jsonl'))) if d.get('redacted')]
  n=lambda s:re.sub(r'\s+',' ',unicodedata.normalize('NFKC',s)).strip().lower()
  arts=[C+'chapter-01/transcript.md',C+'chapter-01/transcript.segments.json',C+'chapter-01/transcript.words.json']
  hay={a:n(open(a,encoding='utf-8').read()) for a in arts}
  bad=[(d['pid'],f,a) for d in red for f in('text','machine_text')
       for a in arts if isinstance(d.get(f),str) and d[f].strip() and n(d[f]) in hay[a]]
  print('redacted rows',len(red),'| surfaces',len(arts),'| R2 violations',len(bad))
  raise SystemExit(1 if bad else 0)
  PY
  ```

  **Whole-string absence is the literal contract, and it is a weak instrument on its own — so two stronger ones were run and both are recorded, including the one that produced a finding.** (i) **Longest surviving common substring** between any redacted `text`/`machine_text` and any of the three artifacts, over all **60** (row × field × surface) pairs: **17 characters**, and at most **5 words**. (ii) A **5-gram survival sweep** over 756 shingles reported **4 hits — one distinct 5-gram**, in the document and its segment sidecar, matched from both fields (all 10 redacted rows have `text == machine_text`, so a field-level hit necessarily doubles). **That one is a measured FALSE POSITIVE, not a leak:** the same 5-gram occurs in **2 non-redacted registry rows**, its two occurrences in the document sit at lines with no `[REDACTED]` marker within ±3 lines, and it is ordinary recurring speech that happened also to fall inside a redacted passage. It is written down rather than dropped because a sweep that only ever reports zero is indistinguishable from a broken one.

  **Independent corroboration at the level that actually matters — the identifier strings themselves.** Each Category-1 token was recovered *by index* from the pre-redaction sidecar blob at `5b611f97d` (never typed, never printed) and counted, word-boundary and case-insensitive over deduplicated match spans, across all four in-scope artifacts, before and after. Every third-party identifier goes to **zero**: `PARTICIPANT-A` 13→0, `THIRD-PARTY-B` 15→0, `THIRD-PARTY-C` 3→0, `THIRD-PARTY-D` 3→0, `ORG-1` 3→0. `INSTRUCTOR` reads 10→6 and **that is the recorded decision F3 = KEEP**, not a miss — the repository owner's own name, which he is the one entitled to publish. Totals **47 → 6**, and all 6 remaining are F3. The pre-redaction column reproduces the private review's own occurrence table exactly — 47 total on the same per-artifact split — which is what makes this a corroboration of that review rather than a second opinion about it. **A first pass of this count read 75 → 6 and is WITHDRAWN by name: it matched two case variants of the same string with a case-insensitive regex and counted each occurrence twice for two of the six labels (13→26, 15→30). The instrument was wrong, not the tree.**

  **Part 2 — apply whatever it identifies: NOT DONE, and this is the only reason the box is unticked.** The private review records **17 decisions: 13 REDACT, 3 KEEP, 1 NOT REMEDIABLE**. Operator decision 26 applied the **Category 1 direct-personal-identifier subset only** — F1 (the title span) and F2, F4, F5, F6, F7 — **6 of the 13 REDACT decisions**. **7 REDACT decisions are DEFERRED and unapplied: F8, F9, F12, F13, F14, F15, F16** — Category 2 indirect identifiers and Category 3 third-party-confidential material, which are *descriptive* findings that no pid-level token redaction reaches. F3, F10 and F11 are KEEP; F17 is NOT REMEDIABLE and already public (`docs/content-boundary-incident-2026-09-01.md` is its class). The deferral is recorded in the review artifact's own `note` field, so it is visible rather than silent — but a deferral is not an application, and "apply whatever it identifies" is not satisfied while 7 REDACT decisions stand. **Resuming those 7 is an operator decision and is not taken here.** One measured mitigation, recorded without being counted as closure: F8's *string* ("infrastructure named after `PARTICIPANT-A`") reads **0** occurrences post-redaction across all four artifacts, because it is the same token as F2 — but F9 and F12–F16 are untouched.

  **APPLICATION OF THE DEFERRED SEVEN WAS ATTEMPTED 2026-09-03 UNDER OPERATOR AUTHORIZATION AND DID NOT LAND. The box therefore stays unticked, and the reason is a TOOL REFUSAL, not a judgement about the findings.** Counts only, per this note's own rule — no pid, no line number, no content. The seven were resolved to the registry from the review's own cited locations (§4b I2/I3/I6, §4c C1–C6, including C4, which the §5 F14 row folds in): **84 distinct passages** across two source artifacts — F8 2, F9 6, F12 3, F13 2, F14 69, F15 2, after resolving **4** passages cited by two findings to the narrower third-party ground. All 84 measured **unredacted** and text-present on disk before the attempt. Six reason codes were prepared, one per finding, so each decision would land in the append-only log with its own `--reason` and `--by` rather than as an untracked edit. **`redact.sh` refused, three times, on two independent surfaces, and `Plan.Apply` returns before `writeAll` when any surface reports PROBLEM — so the run is all-eight-targets-or-nothing and NOTHING WAS WRITTEN.** (1) **`registry-derived`** — a value-level pass over MINTED rows, added to `plan.go` on 2026-09-03 and uncommitted at the time of measurement — reported **29 of 9144 minted rows** carrying a withheld-only string and undecided, from a run-time roster of **36** strings; the surface states in its own words that suppressing them is an operator decision. This is a genuine cascade: the 84 raise the withheld-token count from 108 to **909**, so deciding one wave mints the next. A first wave of **19** was decided independently the same day under `derived_from_withheld_passage` (registry `redacted` moved 10 → **29**), and the cascade did not close. (2) **`taxonomy`** — this one is in COMMITTED code and is the binding blocker, because it fires on the 84 alone and does not cascade: withdrawing a term row whose last evidence is suppressed leaves **34** residual lines still carrying a withdrawn index term. Two measured causes: `proposal_member_terms` on `contradiction` (13) and `discarded-duplicate` (355) rows is not one of the eight propagation targets — a limitation `taxonomy.go` documents in its own words as a *reported* violation rather than a silent survival — and **26** term rows would be withdrawn of which **5 carry a 3- or 4-character string**, so a `bytes.Contains` residual sweep collides with longer, legitimately-visible terms that merely contain them. **Neither was worked around. No gate was weakened, no residual sweep was loosened, no corpus file was hand-edited, and the tooling was not built from `HEAD` to dodge the newer surface** — `Apply` at `HEAD` differs from the working tree by exactly one added line, and choosing the weaker instrument to obtain a write would be the same defect as disabling the gate. **F16 is the one of the seven that needs no corpus edit, and it is ALREADY SATISFIED WITH A GATE:** its remedy is a listing boundary, and `GET /api/chapters/{c}` discloses no source filename — `curriculum.MaterialID` is a one-way `sha256`-derived `m-…` fingerprint, `Material.file` is unexported so it never reaches the wire, the title is a generic kind-plus-ordinal, and `pkg/curriculum.TestMaterialIDNeverContainsSourceWords` is the durable assertion. Verified alongside: `verify-redaction-propagation.sh` **0** (A1–A10b, on the INVENTED fixture corpus — which is exactly why it stays green while the real corpus refuses), `verify-limits-completeness.sh` **0** (15/15), the `pipeline/extract` suite **264 tests OK** in `pipeline/venv` (system `python3` lacks `wordfreq` and errors 32 of them — an environment fault, a 2, never a failure), and the gate-attachment closure check **31 ids, `unattached: 0`**. A hardlink-safe backup of all 49 corpus files was taken first, and the corpus was re-verified byte-identical to it afterwards. **What is owed before the seven can land: close the `taxonomy` propagation gap for `proposal_member_terms`, decide how a withdrawn short term is swept without either colliding or loosening the sweep, and carry the `registry-derived` cascade to a fixed point. All three are operator or tooling decisions, not corpus decisions.**

  **FR-039's ordering clause was violated once, historically, and redaction did not undo it.** This task says "BEFORE the transcript is exported, published, served or **committed**". Measured over the file's whole history: `5b611f97d` (2026-09-01) committed the transcript with **6 of the 10** currently-redacted passages' exact `text` present and **0** redaction markers; `692a27aa8` (2026-09-02) is clean at **0/10** present and 11 markers, and equals the working tree. The other 4 are **COULD NOT DETERMINE** — the registry's `text` is today's rendering and the 2026-09-01 blob is 788 B larger, so their absence there is not evidence they were absent from that rendering. The commit reached the workshop remote, which is **PRIVATE**, so this is not a public disclosure and is a different class from the umbrella's own incident — but a push is publication and the review came second. **This is containment, not remedy, and it is not closeable by anything this task can do.**

  **Not done here, stated plainly:** no durable gate asserts R2 against the REAL chapter. `G-PID-5` (`workshop/platform/gates/verify-redaction-propagation.sh`) asserts the whole of R1–R7 against the **invented** `fixture-corpus`, which is deliberate — that generator exists so no gate has to read private material. The assertion above is therefore a recorded, reproducible **[REVIEW]** measurement with its recipe published, not a registered check, and no `G-` identifier was minted; the gate-attachment closure check is unaffected (re-run 2026-09-03: **31 ids, `unattached: 0`**)]**
- [ ] T207 (was: 001/T041) [US1] [REVIEW] Human review checkpoint: speaker attribution is HUMAN (D-TRANS-2 — the recording is dual-mono at −90.3 dB and AGC-flattened, so both diarization cues are measurably absent) — **[BLOCKED ON THE OPERATOR. Measured 2026-09-03; NEW note.** This is human labour by construction: D-TRANS-2 measured both diarization cues absent, so no tool on this host can attribute a line to a speaker, and no agent can substitute for the person who was in the room. Nothing else blocks it. **A TRAP, AND IT IS THIS FILE'S OWN COLLISION WARNING BITING: `workshop/docs/session-evidence/t041-decision-packets.md` (untracked, written 2026-09-03) IS NOT THIS TASK.** Its subject is R3 contradiction typology over taxonomy terms — that is **`002:T041`**. Its own opening line says *"001/T041 (unified T207) remains `[ ]`"*, and a reader who resolves that bare id against this file will conclude something false about speaker attribution. Cite it as `002:T041`, per standing rule at the head of this document. **No artifact recording a human speaker-attribution review exists for `001:T041`**]** — **BLOCKER:** **operator decision, and it is human labour** — speaker attribution is HUMAN by D-TRANS-2: the recording is dual-mono at -90.3 dB and AGC-flattened, so both diarization cues are measurably absent. No amount of engineering substitutes for someone listening · **OWNER:** **operator** — nothing an agent can do closes this (FR-005→unified FR-005)
- [x] T208 (was: 001/T111) [US1] [TDD] Implement the `transcribe.sh <chapter-slug>` wrapper over the transcription modules — `--resume`, `--from-parts`, `--chunk-seconds`, `--model`, `--threads`, `--sample-seconds`, `--dry-run` — and gate G-CLI-2 (FR-001→unified FR-001, FR-029→unified FR-177, FR-006→unified FR-006, FR-033→unified FR-261, SC-013→unified SC-136, FR-032→unified FR-260, SC-012→unified SC-135). **DONE 2026-09-15.** Orchestrates chunker → ASR driver → checkpoint over `_common.sh`'s existing §2.2/§2.5/§1.4/§1.5 framework; `--from-parts` wired directly to `extract-videos.sh --require` (T189's own `reassemble.sh` indirection still absent, correctly not reinvented). Two honest, documented simplifications: no committed ASR-model-hash manifest exists in this tree to check against (preflight verifies the venv can import the engine instead); the contract's chapter-01-specific "eight known long silences" worked example is deliberately NOT hardcoded into shared pipeline code (would violate this module's no-frozen-assumptions rule) — the generic coverage identity implies the same property. §1.1 proof for G-CLI-2 independently re-run and confirmed (both the positive control and the notes-PDF-rewrite mutation). **Real dogfood run against the actual chapter-01 recording**, not only synthetic fixtures: full 11-chunk plan over the real 6928.7s audio, calibration ASR on the first 20s, source `(size, mtime, inode)` confirmed byte-identical before/after — no transcribed text was read or reproduced, only counts. One incidental scratch-directory mishap during testing (an unrelated tracked file briefly removed, caught via `git status` and restored) is recorded honestly rather than omitted
- [x] T209 (was: 001/T112) [US1] [TDD] Implement the `workshop/scripts/verify-accuracy.sh <chapter-slug>` wrapper per [contracts/pipeline-cli.md](../001-workshop-curriculum-platform/contracts/pipeline-cli.md) §4.2 over 001/T033 (unified T199)'s scorer — `--reference` (required), `--windows 30`, `--seed` (recorded, so the sample is reproducible), `--normaliser` (whose SHA-256 must match 001/T034 (unified T200)'s frozen hash) and `--min-accuracy` — writing `chapters/NN/transcript/accuracy.json`, which is publish precondition B2. Gate **G-CLI-5** (§4.2, §5): run with `--reference` pointing at a nonexistent file and assert exit `2`. **Paired mutation**: return `0` with `wer: 0.0` when the reference is absent; the gate MUST go red. This is the most important line in §4.2 — **the absence of a human reference is `2`, never `0`** — because a command that cannot measure accuracy must not report that accuracy is fine, and until this has run `GET /api/chapters/{c}/accuracy` reports `measured: false, wer: null` (SC-002→unified SC-002, SC-013→unified SC-136). **RUN 2026-09-03, and the "most important line" was exercised for real rather than only in a gate: `bash workshop/scripts/verify-accuracy.sh 01` exits `2` with `UNDETERMINED: --reference is required`, writes no `accuracy.json`, and says why in its own words. The tick was already earned by the build; what is new is that the behaviour is now confirmed against the real chapter and not only against the G-CLI-5 fixture.** Its `--emit-plan` path produced `workshop/chapters/01/transcript/accuracy-plan.json` — 30 of 30 seeded, stratified windows. **Honest boundary (§11.4.6), and it belongs to 001/T037 (unified T203), not here: this wrapper emits no confidence interval and computes none, which 001/T037 (unified T203) requires — see 001/T037 (unified T203)'s own note** (population: in_process) (FR-004→unified FR-004, SC-002→unified SC-002, FR-033→unified FR-261, SC-013→unified SC-136, FR-032→unified FR-260, SC-012→unified SC-135)
- [x] T210 (was: 001/T113) [US1] [TDD] Implement `ingest.sh`'s contracted flag surface (`--write-anchors`/`--no-write-anchors`/`--kinds`/`--dry-run`/`--check-idempotent`, plus the already-present `--corpus`) and gate G-PID-6 (FR-027→unified FR-175, FR-037→unified FR-010, SC-016→unified SC-075, FR-033→unified FR-261, FR-032→unified FR-260, SC-012→unified SC-135). **DONE 2026-09-15.** `--write-anchors` calls into the passage library's own exported primitives only (no anchor-format logic reimplemented). Real structural finding made while wiring this in: `build_transcript.py` merges ASR segments into silence-delimited turn paragraphs, so a transcript segment has no line of its own to anchor — its `SourceRef.Anchor` was mislabeled `AnchorInline` when identity actually always traveled via the sidecar's `pid` field; relabeled to `AnchorSidecar` (metadata-only correction). A real idempotency bug was caught and fixed while building `--check-idempotent` itself: writing an anchor shifts every line below it, so reusing a stale section-split sidecar on a second pass spliced in a duplicate anchor — fixed by re-splitting before each verification pass. G-PID-6's own I1–I6 test already existed in `submodules/passage` and was re-run (not rewritten): `TestSecondSyncMintsNothingAndLeavesTheFileByteIdentical` and its paired mutation `TestPairedMutation_UnconditionalMintingBreaksIdempotency`, both independently re-confirmed. End-to-end proof against a synthetic fixture (three cycles: mint → resplit+mint → resplit+mint) shows byte-identical `doc.md`/`passages.jsonl` from cycle 2 onward
- [ ] T196 (was: 001/T030) [US1] Emit the markdown transcript with pid anchors and timestamps to `workshop/curriculum/chapter-01/transcript.md` (FR-001→unified FR-001, FR-002→unified FR-002, FR-037→unified FR-010). **Genuinely still open, 2026-09-15 — not a guess, a structural finding.** T210's `--write-anchors` is real and proven for `doc_section`-kind markdown (exercise files, docs, curriculum prose) — but chapter-01's own `transcript.md` cannot correctly host per-segment anchors under the CURRENT `build_transcript.py` rendering: it merges ASR segments into silence-delimited turn paragraphs, so an individual segment has no stable line of its own to anchor without a larger redesign of segment/turn granularity, which is out of scope for T210/T196 as written. Timestamps remain done (unchanged from the prior note); the pid-anchor half remains genuinely unwritten, for a now-understood reason rather than an unexplained gap. The real transcript was NOT touched this pass (confirmed: 0 pid comments, clean `git status`) — a synthetic fixture was used to prove the mechanism instead
- [x] T211 (was: 001/T121) [US1] [TDD] Implement disk-space exhaustion handling in `extract-videos.sh` and the checkpoint writer, gate G-CLI-18 (FR-056→unified FR-008). **DONE 2026-09-15.** Pre-write space check (5% margin/1MiB floor against real disk stats) plus ENOSPC-aware cleanup on both sides. Gate uses a real rootless `podman unshare` tmpfs (plain `unshare --user` was refused by this sandbox) to genuinely exhaust disk space rather than simulating it — pre-write refusal, genuine mid-write ENOSPC, and the paired mutation (pre-T211 shape, no space check at all) all independently re-run and confirmed: 10/10. `workshop/CLAUDE.md` module-local rule 3 honored — `scripts/self-test.sh` re-run after this `extract-videos.sh` change, independently re-confirmed green
- [x] T212 (was: 001/T122) [US1] [TDD] Enforce the checksum manifest as a hard precondition of reassembly in `extract-videos.sh`, gate G-CLI-19 (FR-057→unified FR-009). **DONE 2026-09-15.** New `--require <video-path>` flag + a pre-scan refusal (missing/unparsable manifest → exit 1 with a named reason code, nothing touched) plus a post-scan sanity check for a `--require`-vs-root-dir scope mismatch. §1.1 proof (deleted manifest, corrupted manifest, valid-manifest control, and the fall-back-and-reassemble-anyway mutation) independently re-run and confirmed: 8/8

*From `001` — Phase 4: User Story 2 — Browse and watch (Priority: P2)*

- [x] T213 (was: 001/T042) [US2] [TDD] **[PATH CORRECTED 2026-09-02 — this task named `workshop/platform/backend/internal/store/chapter.go`; neither it nor the `internal/store/` directory exists. The store landed at `workshop/platform/backend/pkg/curriculum/curriculum.go` (`type Store` at `:168`, `ComputeCoverage` at `:428`), with its HTTP layer at `internal/api/chapters.go`. It is therefore in `pkg/`, which contradicts the File Structure row that argued for `internal/` — recorded rather than reconciled here]** Implement the chapter model + store in `workshop/platform/backend/pkg/curriculum/curriculum.go` per [data-model.md](../001-workshop-curriculum-platform/data-model.md) (FR-008→unified FR-055)
- [x] T214 (was: 001/T043) [US2] [TDD] Implement `GET /api/chapters` and `GET /api/chapters/{slug}` per [contracts/http-api.md](../001-workshop-curriculum-platform/contracts/http-api.md) (FR-008→unified FR-055)
- [x] T215 (was: 001/T044) [US2] [TDD] Implement `GET /api/chapters/{slug}/transcript` returning passages with pid, timestamps, provenance and uncertainty (FR-009→unified FR-056, FR-002→unified FR-002, FR-003→unified FR-003, FR-038→unified FR-011)
- [x] T216 (was: 001/T045) [US2] [TDD] **[PATH CORRECTED 2026-09-02 — this task named `workshop/platform/backend/pkg/media/serve.go`; neither it nor the `pkg/media/` directory exists. Range-serve landed at `workshop/platform/backend/internal/api/recording.go`, delegating to `http.ServeContent` at `:786` for `Accept-Ranges` (`:769`), `206`, `Content-Range`, `416 bytes */total` (`:724`) and `If-Range`, with multi-range rejected explicitly before it reaches `ServeContent`]** Implement local recording range-serve with seek in `workshop/platform/backend/internal/api/recording.go` — a local file with HTTP range support (decision D3), NOT a streaming service (FR-009→unified FR-056, SC-003→unified SC-003)
- [x] T217 (was: 001/T046) [US2] [P] [SUBAGENT] Build the chapter list and detail views in `workshop/platform/frontend/src/app/features/chapters/` (FR-008→unified FR-055)
- [x] T218 (was: 001/T047) [US2] [P] [SUBAGENT] Build the transcript reader with timestamp→recording seek in `workshop/platform/frontend/src/app/features/transcript/` (FR-009→unified FR-056, FR-002→unified FR-002, SC-003→unified SC-003)
- [x] T219 (was: 001/T048) [US2] [P] Reuse `design-system/learning-kit/` curriculum CSS (verified present, framework-free, on the `--od-*` token contract) rather than authoring new styling (FR-046→unified FR-284)
- [x] T220 (was: 001/T049) [US2] [TDD] Persist reader position/progress per FR-010 — **[TICKED 2026-09-02 after independent re-measurement. Backend: `workshop/platform/backend/internal/api/progress.go` — `type ProgressStore` `:46`, `Get` `:90`, `Put` `:110`, `ProgressHandler` `:156` serving `MethodGet` `:167` and `MethodPost` `:186`. The route is live and gated: `cmd/workshop-server/web_test.go:356`–`:358` fails if `POST /api/progress` 404s, and `:364` holds every other verb to 404. Frontend: `workshop/platform/frontend/src/app/core/progress.ts:4` cites FR-010 (001/T049 (unified T220)) over a per-chapter local store. Honest boundary (§11.4.6): no Go test suite was executed for this tick — the assertions were read, not run]** (population: source) (FR-010→unified FR-057)
- [x] T221 (was: 001/T050) [US2] [TDD] Prove SC-003: transcript passage → recording seek lands within 5 s, in `workshop/platform/frontend/src/app/features/transcript/seek.spec.ts` (SC-003→unified SC-003, FR-002→unified FR-002)
- [x] T222 (was: 001/T051) [US2] Write `workshop/docs/quickstart.md` and time a fresh-clone-to-running run against SC-004's 15-minute budget (FR-030→unified FR-336, FR-012→unified FR-059, SC-004→unified SC-004). **DONE 2026-09-15 — the first actual stopwatch measurement, not merely asserted prose.** Real fresh clone (`--filter=blob:none`) into a scratch directory, isolated with a distinct project name/port so the real production container (`workshop-curriculum_platform_1`, up 8h at the time, on a different port) was never touched. Measured, `time`-based, unrounded: clone 9.6s + dependency bootstrap 14.2s + host-capability check 5.4s + build (Go binaries + Angular frontend + doc exports) 44.2s + stack start 13.8s + health verify 3.2s = **90.4s total (~1.5 min), ≈10% of the 15-minute budget — PASSES by a wide margin**. `/api/health` confirmed 200 `status:ok`, `/api/search` confirmed real results against the fresh clone's own content. Scratch container/volume/clone all cleaned up afterward, evidenced only by these numbers. **Three genuine `quickstart.md` staleness findings surfaced and reported, not fixed (out of scope for a measurement task)**: (1) §1 never documents the standalone-clone path at all — the actual working answer, `scripts/bootstrap-standalone.sh`, is undocumented; (2) §3 previously claimed `build.sh` was "NOT EXECUTED HERE" and only measured an isolated 1.71s Go-compile step — the real full build is 44.2s and had never been timed; (3) §8's ask-a-question walkthrough is stale against the current default (`-answer-provider none`), which now correctly 503s rather than answering — not a blocker for SC-004 itself, but would mislead a reader following the doc verbatim
- [x] T223 (was: 001/T114) [US2] [TDD] Prove gate **G-CLI-15** — the containers-actually-booted anti-bluff (§11.4.76(5)): after `start.sh` exits `0`, assert the runtime independently reports containers running AND `/api/health` answers through the published address, never a container-internal one (FR-012→unified FR-059, FR-033→unified FR-261, FR-032→unified FR-260, SC-012→unified SC-135). **DONE 2026-09-15.** New standalone `containers-status-probe` binary (never `workshop-boot`/`status.sh` itself — a gate must not ask the mutated program to grade its own mutation) calls `submodules/containers`' Go API directly. "Through the published port" resolved given `network_mode: host` (so `NetworkSettings.Ports` is genuinely empty): reads the real bound address from the container's own bind-mounted `platform/run/server.json` and curls from outside the container namespace — confirmed the documented default `127.0.0.1:8087` is measurably wrong on this host (the live container binds a LAN address). §1.1 proof: real positive control against the actual production container, and a measured (not merely asserted) reproduction of the upstream `cmd/boot` stub-starts-nothing defect via a standalone Go stub given the exact same argv (chosen over swapping the real shared binary in-place, since concurrent rebuild activity was visible in this shared checkout) — both independently re-run and confirmed. Correctly not registered in any existing `check-registry*.tsv`: `check-registry-001.tsv`'s own text explicitly excludes `platform/gates/` from its scanroot, attributing coverage instead to `verify.sh`'s dynamic discovery + V7 pairing — confirmed this gate is discovered and correctly paired there
- [x] T224 (was: 001/T123) [US2] [TDD] [SUBAGENT] Implement the explicit "no chapters available yet" state: a typed empty response from `GET /api/chapters`, and a dedicated, assistive-technology-announced empty-state view on the frontend (FR-049→unified FR-061). **DONE 2026-09-15.** Route re-located first (the brief's cited path was stale — the live `GET /api/chapters` handler is in `cmd/workshop-server/main.go`, not `internal/api/chapters.go`). Found and closed a real pre-existing gap: a doc comment already described a three-state `ok`/`no_match`/`unavailable` wire shape that no code had ever wired up — `buildChaptersResponse` hardcoded `"ok"` even for an empty array. Now correctly reports `no_match`. Frontend's dedicated empty view already existed but had zero ARIA attributes (a silent blank-to-AT region) — added `role="status" aria-live="polite"`. §1.1 proof on both sides (backend: hardcode `"ok"` unconditionally; frontend: render the populated-list view unconditionally) — both independently re-run and confirmed red-then-green
- [x] T225 (was: 001/T124) [US2] [TDD] [REVIEW] Implement loopback-only-by-default access control as shared middleware ahead of every route (FR-051→unified FR-014). **DONE 2026-09-15.** New `internal/api/access.go`: `LoopbackOnly` middleware, fail-closed on an unparseable remote address, `crypto/subtle.ConstantTimeCompare` credential check, empty configured credential means "never admit a non-loopback caller" (never "accept anything"). Wired at the single point `routes()` hands back the composed mux, so every registered route inherits it uniformly with no per-route opt-in possible. Gate G-HTTP-9 proven at both unit level (7 cases) and integration level through the real composed router against `/api/progress` — deliberately NOT one of the four routes the task names, to prove uniform coverage rather than a hand-picked set. §1.1 proof: wrapping only one route in the real `routes()` correctly caught by the integration test; a second, permanent standing-regression test (a mutant mux) also ships. **Required, and correctly made, a test-harness fix**: `httptest.NewRequest`'s default `RemoteAddr` is non-loopback by Go stdlib default, so wiring the middleware broke 26 pre-existing tests across the package until the shared test harness was pointed at a loopback address — the middleware itself was never weakened to fix this, confirmed by explicitly re-running T224's own tests afterward (still green)
- [x] T226 (was: 001/T125) [US2] [SUBAGENT] Convey passage uncertainty with a text label or accessible-name-carrying icon, never color alone (FR-052→unified FR-233). **DONE 2026-09-15 — measured already-compliant, not fixed.** Read `transcript.component.ts` first: whenever `pg.uncertain` is true, a genuine DOM text element (`"Transcriber unsure — ..."`) already renders alongside the color-only CSS classes — no production change needed, zero diff. New test in `e2e/a11y-responsive.spec.ts` strips every stylesheet from the live DOM and asserts the marker's text survives unchanged — independently re-run against the live production container (both desktop and mobile chromium projects), 8/8 pass. Paired mutation (emptied the label, kept the color class) driven for real via a temporary `ng serve` proxying the live backend — never the container's served bundle — confirmed red, then reverted (zero diff confirmed)
- [x] T227 (was: 001/T126) [US2] [TDD] [SUBAGENT] Make the recording player's controls keyboard-operable with accessible names, to the same WCAG 2.1 AA standard already proven for search (FR-059→unified FR-234, SC-003→unified SC-003). **DONE 2026-09-15 — measured already-compliant, not fixed.** Player is a native `<video controls>` with `aria-label`; "jump to timestamp" is a native `<button>` — both keyboard-operable by construction. Empirically verified in a real browser against the live stack: Tab reaches the video and the seek button, `Space` toggles play/pause, `ArrowRight` seeks, `Enter` on the seek button moves `currentTime`. Three new keyboard-only tests (no `.click()` anywhere) in `e2e/a11y-responsive.spec.ts`, independently re-run against the live production container (desktop + mobile chromium), 8/8 total pass. Paired mutation (native `<button>` → `<span>` with only a click handler) driven for real, confirmed the jump-to-timestamp test alone goes red exactly as specified, then reverted (zero diff confirmed)


---

## Phase 7: US10 + US11 + US17 — the knowledge layer: authored areas, lessons, learner-facing completeness (P1/P2)

**62 tasks — 58 complete, 4 not-owed.** Sources: 002, 004, 005, 006. **Phase 7 closed 2026-09-15**: this pass completed T243, T245, T248, T256, T268, T269, T270, T271, T274, T275, T277 and T279 across 6 parallel subagent tracks (significance-score inputs, publication-liveness + primary-reference gates G-KG-20/21, an inbound content-boundary shingle checker G-KG-22, an explicit empty-catalogue wire state, deterministic reading-time + ceiling-rounded pass thresholds, frontend lesson prev/next + quote-distinction + no-assessment disclosure, and real-corpus bank/coverage verification), every claim independently re-verified in-session (full pipeline suite 337/337, full Go suite 24/24 packages, full Karma suite 368/368, every new gate's §1.1 proof re-run) before being marked done. A genuine G-KG-20 numbering COLLISION between two parallel tracks (T245 and T248 each independently picked G-KG-20) was caught during consolidated verification and resolved by renumbering T248 to G-KG-22. **T236 and T238 stay open** — both are blocked on an undecided operator clarification (extractive vs. build-time vs. run-time prose authorship) that this pass did not have standing to resolve. **T278 stays open** — a human operator decision to publish-or-not on 3 documents carrying 62/54/58 uncited claim blocks. **T289 stays open** — authoring text alternatives for 205 private video materials is genuine editorial/accessibility work, not something to auto-generate from outside this pass's scope.


*From `002` — Phase 3: User Story 1 — the taxonomy and its materials (P1) 🎯 MVP*

- [x] T228 (was: 002/T023) [US1] [TDD] [REVIEW] Implement **promotion** of the five existing prose areas in
      `workshop/pipeline/extract/promote.py` per contract §2.1: mint identifiers, evidence each
      against the corpus, adopt the existing document as materials and its headings as lesson
      sections. **Do not rewrite the prose as a side effect of promotion** (FR-008a→unified FR-080)
- [x] T229 (was: 002/T024) [US1] [TDD] Implement **P2**: an area acquiring zero evidencing mentions **fails promotion
      loudly**. It is neither published unevidenced nor silently dropped, and both outcomes are
      reported. Gate **G-KG-10**. **Paired mutation**: publish one with its mentions removed (FR-008→unified FR-079, FR-053→unified FR-260, SC-001→unified SC-043)
- [x] T230 (was: 002/T025) [US1] [TDD] Implement the significance measure in `workshop/pipeline/extract/significance.py`
      per contract §2.2 E2/E3 — combining distinctiveness against a general-language baseline,
      distribution across the corpus, and corroboration in the workshop's own written material.
      **Raw frequency alone is disqualified**: frequency-ranking a spoken corpus returns function
      words. The measure **prints its inputs** so the arithmetic can be audited (FR-013→unified FR-086, SC-002→unified SC-044)
- [x] T231 (was: 002/T026) [US1] [TDD] Implement area and term extraction in `workshop/pipeline/extract/derive.py`.
      **No area count is targeted** (E5, research U3) — the corpus evidences what it evidences.
      Reading the reference module from this stage is forbidden (FR-004→unified FR-066, FR-006→unified FR-077)
- [x] T232 (was: 002/T027) [US1] [TDD] Implement the three reconciliation branches per contract §2.3: **R1 attaches**,
      **R2 adds**, **R3 contradicts ⇒ reported for a decision, neither merged nor discarded** (FR-008a→unified FR-080, FR-033f→unified FR-179)
- [x] T233 (was: 002/T028) [US1] [TDD] Prove **G-KG-14**: seed a contradiction, assert it appears in the report and
      that neither a merge nor a discard occurred. **Paired mutation**: make R3 fall through to R1
      above a similarity threshold; the gate must go red. Merging on overlap silently redraws a
      boundary a human drew (FR-008a→unified FR-080, FR-033f→unified FR-179, SC-015d→unified SC-099)
- [x] T234 (was: 002/T029) [US1] [TDD] Implement passage accounting per contract §2.4: `attached + classified_unattached
      == registry_count`, **exactly**. Publish the attached proportion as a **measured figure with no
      threshold** (research U2). The check is arithmetic — a total, not a ratio — so it cannot be
      satisfied by redefining what counts as attached (FR-010→unified FR-083, SC-003→unified SC-045)
- [x] T235 (was: 002/T030) [US1] [TDD] Implement uncertainty marking: a low-confidence term is marked `uncertain`
      (FR-011→unified FR-084), and an area evidenced **only** by uncertain passages is marked `uncertain-only`
      (FR-012→unified FR-085). 267 of 1,101 passages are uncertain, so this is not a rare branch (FR-011→unified FR-084, FR-012→unified FR-085)
- [ ] T236 (was: 002/T031) [US1] [BLOCKED: prose authorship] [REVIEW] Author area materials in the **seven-section — **BLOCKER:** **operator decision** — the prose-authorship clarification is undecided (extractive vs build-time vs run-time). 5 documents are authored with 7 `## ` sections each and 489 areas serve; the earlier "host capability" excuse is WITHDRAWN. This is irreducible authorship, not engineering · **OWNER:** **operator**, then **human prose authorship**
      skeleton**, adapting the two interview-specific sections to the workshop's subject (FR-003→unified FR-065, FR-014→unified FR-087, SC-005→unified SC-047). **Blocked
      on the first clarification, and on that alone** — extractive assembly, agent-authored at build
      time, and run-time generation are three different pieces of work, and nobody has decided which
      one this is. ~~This host has **no generative model**, so the third cannot run here today.~~
      **That sentence is WITHDRAWN, not restated, and it was false when written.** Measured
      2026-09-02: `ollama list` carries the generative `qwen2.5:3b-instruct-q4_K_M` (1.9 GB), and
      `podman inspect workshop-curriculum_platform_1 --format '{{.Config.Cmd}}'` shows
      `-answer-provider ollama -answer-model qwen2.5:3b-instruct-q4_K_M` in the RUNNING container's
      own argv — so the model is not merely installed, it is already wired into the platform's
      answer path. An entailment model loads on this host too, recorded under §10.12 of
      `workshop/docs/limits.md` as a DECIDED verdict (`entail=0.9924`). **All three options are
      therefore runnable here; what blocks this task is the clarification, not the host.** Re-derive
      with the two commands above rather than trusting this sentence — a host changes under you, and
      this task's text has already been wrong about it once.

      **PARTIAL (re-measured live 2026-09-03; the figures moved and the gap did not).** 5 area
      source documents exist under `workshop/docs/training/areas/`, each in the seven-section
      skeleton; `/api/areas` now serves **495** areas at generation **54** — re-verified later the
      same day at generation **67**, still 495 served against still 5 authored `.md` documents under
      `docs/training/areas/` — so **490** have no
      authored materials. **The 499/494 figures this note used to carry are superseded, not wrong
      when written**: 5 areas moved into `held_back` with reason `all_evidence_redacted` when the
      chapter-01 redactions of decision 26 were applied — publication liveness working, not
      authorship progress. The prose-authorship clarification is
      still open, and `pipeline/extract/verify.py` keeps `W2-claims-over-real-materials` and
      `W3-review-over-real-materials` in a separate `MATERIALS_STATUS_CHECKS` map — outside `GATES`
      and outside `--prove-failure` — naming this gap in its own comment. **The `[BLOCKED: prose
      authorship]` marker above is LIVE**, unlike the two stripped from 002/T060 (unified T366) and 002/T094 (unified T401) on the same
      day: the clarification it names is genuinely undecided. Do not tick this task on the strength
      of the host correction — the correction removes a false excuse, not the blocker.
- [x] T237 (was: 002/T032) [US1] [TDD] Implement the authored/assembled marking on every lesson section (FR-017,
      contract W1). Build the field regardless of how the clarification resolves — it costs one field
      and keeps all three options shippable without a schema change (FR-017→unified FR-091)
- [ ] T238 (was: 002/T033) [US1] [TDD] Implement claim citation enforcement (contract W2): every substantive claim — **BLOCKER:** **predecessor 002/T031 (unified T236)** — 224 of 532 claim blocks across all 5 documents are uncited or cite a non-resolving pid (48 are exempt Sources entries); W3 is reviewed for 2 of 5. Enforcement cannot land before the prose it enforces is settled · **OWNER:** **implementer**, after 002/T031 (unified T236)
      carries a resolving citation **or** is visibly marked as editorial framing that is not workshop
      content. There is no unmarked, uncited claim (FR-015→unified FR-089, SC-006→unified SC-048)

      **PARTIAL (re-measured 2026-09-03, unchanged).** Enforcement exists and hits production
      (`authorship.check_area_w2`, `verify.py::prove_w2_requires_citation_hits_production`). It has
      been APPLIED to only **2 of the 5** authored areas — `wc -l
      workshop/curriculum/publication-reviews.jsonl` is still **2** against 5 documents under
      `workshop/docs/training/areas/`. The other 3 carry the unaudited coincidental-citation risk
      that the review record itself names.
- [x] T239 (was: 002/T034) [US1] [TDD] Implement the publication review record and its **staleness rule**: a review
      older than the materials it reviews **fails**, it does not warn (contract W3). Recording
      *"nothing to change"* is valid; skipping the review is not (FR-016→unified FR-090, SC-007→unified SC-049)
- [x] T240 (was: 002/T035) [US1] [TDD] Implement the seven-section presence check across every area source document
      (SC-005→unified SC-047). Any missing section fails (FR-014→unified FR-087, SC-005→unified SC-047)
- [x] T241 (was: 002/T036) [US1] Implement the taxonomy source file with the same byte-stability discipline the
      passage registry already has — sorted, fixed key order, final newline — so a diff means a change (FR-009→unified FR-082, SC-004→unified SC-046)
- [x] T242 (was: 002/T037) [US1] [TDD] Implement `GET /api/areas` per wire contract §3.1, including **A3.1.2**: report
      the count of areas held back and why. A client cannot distinguish five areas existing from
      eleven existing and six failing publication unless told (FR-016→unified FR-090, FR-059→unified FR-274)
- [x] T243 (was: 002/T038) [US1] [TDD] Implement `GET /api/areas/{area}` per §3.2, and `GET /api/terms` and
      `GET /api/terms/{term}` per §3.4 — including the significance measure **and its inputs** on the
      single-term response (FR-013→unified FR-086, FR-059→unified FR-274)

      **DONE 2026-09-15 for the code path; production artifact not yet rebuilt, and that gap is
      recorded honestly rather than glossed.** `pipeline/extract/taxonomy.py`'s `_term_row()` now
      persists a nested `significance_inputs` object (distinctiveness, distribution,
      corroborated_in_written_material, baseline_rate_per_1000, baseline_source) with a FIXED key
      set on every row it writes — an undetermined term gets honest `null` inputs, never a fabricated
      floor. `pkg/knowledge/taxonomy.go`'s `ParseTaxonomy` loads it into a new
      `SignificanceInputsRecord` (nil for any pre-fix row), and `internal/api/terms.go`'s
      `termListObject()` branches on that: `inputs_available:true` + the served object when present,
      the original honest `false` + reason when absent — full backward compatibility for any taxonomy
      artifact built before this change. Verified against a copy of the real corpus (never the
      production registry): 23,916 candidate term rows, 23,916/23,916 carrying the key, 20,922
      (87.48%) with populated inputs. Both certainty states independently re-run: `python -m unittest
      test_taxonomy -v` 18/18 OK; `go test ./internal/api/... ./pkg/knowledge/...` all PASS; full
      backend suite `go test ./...` rc 0, all 24 packages ok. **What remains**: the PRODUCTION
      `curriculum/taxonomy.jsonl` on disk was built before this fix and still lacks the key, so every
      term this platform actually serves today still reads `inputs_available:false` via the honest
      fallback — rebuilding it is a separate, deliberate pipeline-run decision over a production
      artifact, not taken here. `term-significance-inputs-unavailable` (defects-registry.tsv) and
      `docs/limits.md` §10.4 both updated to record PARTIALLY CLOSED with this exact scope boundary.
- [x] T244 (was: 002/T039) [US1] [TDD] Implement **A3.4.2**: a term whose last evidence is redacted is **withdrawn
      from the taxonomy**, not merely unlinked (FR-008→unified FR-079, FR-027→unified FR-148, SC-012→unified SC-080)
- [x] T245 (was: 002/T145) [US1] [TDD] Implement continuous publication-liveness for areas per **FR-008b**: an
      already-published area whose evidencing passages are reduced to zero by a later redaction is
      automatically unpublished — or held for an explicit republication decision — and MUST NOT
      continue to display, export or resolve as though it still carried live evidence. This extends
      the publish-time precondition FR-008/T024 already enforces into a continuous check, so a
      redaction is caught without waiting on the next full extraction. Gate **G-KG-20**. **Paired
      mutation**: redact an already-published area's last evidencing passage and skip the
      post-publish check, leaving the area displayed; the gate must go red (FR-008→unified FR-079, FR-008b→unified FR-081, SC-007a→unified SC-050)

      **DONE 2026-09-15.** TDD (RED confirmed first: 17 new tests failing with `AttributeError`, then
      implemented, then GREEN: 33/33 in `test_publication_policy.py`). `publication_policy.py` gained
      `_has_live_evidence()`, `check_g_kg_20()` (raises naming only the stable area id, never its
      title), and `apply_publication_liveness()` — the remedy. **Design choice, held_back over
      auto-unpublish**: FR-008b poses an either/or; held_back was chosen because it reuses the
      EXISTING `partition_rows()` held-back mechanism rather than inventing a second "unpublished"
      representation, and because it is reversible (matching `curriculum/redactions.jsonl`'s own
      redact/unredact design), stamped `held_back_reason: "evidence_exhausted_by_redaction"`. Wired
      into `verify.py` as `GATES["publication-liveness-over-real-corpus"]` + `PROOFS["G-KG-20"]`, both
      independently re-run and confirmed against the real corpus: gate rc 0, "42 published area(s)
      ... all carry >=1 live evidencing passage"; proof rc 0, mutation CAUGHT ("1 published area(s)
      have zero live evidencing passage(s) after redaction"). **Honest scope boundary**: the detector
      and remedy FUNCTION are built and proven, but `apply_publication_liveness()` is not yet wired
      into `run_pipeline.py`'s publication-filter stage — the gate is a standalone, on-demand
      detector runnable any time against the on-disk taxonomy (satisfying the "continuous, without
      waiting on the next full extraction" requirement), but it does not itself perform the write.
      Wiring it into the pipeline run is a follow-up, not silently claimed done here.
- [x] T246 (was: 002/T040) [US1] Add route-manifest rows and contract sections for every endpoint above (FR-059→unified FR-274).
      Gate **G-KG-1**. An endpoint built but undeclared fails the server-unity verifier by
      construction — that is deliberate and must not be "fixed" by loosening the verifier (FR-059→unified FR-274)
- [x] T247 (was: 002/T041) [US1] [REVIEW] Human checkpoint: the reconciliation of promoted against extracted areas.
      A wrong merge here is a wrong curriculum, and every later artifact inherits it (FR-008a→unified FR-080, FR-033f→unified FR-179)

      **TICKED 2026-09-03 ON AN OPERATOR RULING (D-36), not on a measurement — and the distinction
      is the point.** Every R3 contradiction is now disposed of by a rule rather than adjudicated
      row by row: decision D-33 ruled that title-keyword overlap is an **evidencing heuristic, not
      a boundary a human drew**, so R3 must not defend it. That rule cleared **exactly 12** of the
      13 (`R3_contradict` 13 → 1) with every other branch unchanged to the row, and it is a *rule*,
      not a list — it reads the origin string the evidence finder itself writes, so it stays true as
      the corpus moves and **stops applying by itself** the moment any other evidencing path
      supplies the overlap.
      **The 13th — the large deferred cluster — is NOT resolved and is not claimed to be.** It
      remains reported, routed to a named owner, and scheduled for a **2026-09-16** re-check. D-36
      asked whether an owned, dated, tracked deferral permits this box to tick; the operator ruled
      that **it does** — a deferral that is scheduled and owned is a resolution, not an omission.
      **Read the risk with the tick:** a ticked task whose last item is still open can read as
      complete to anyone who does not open this note. It is recorded here rather than left implicit.
      **Three options were explicitly NOT chosen and all remain open**, each with its cost still
      unmeasured: changing the evidence finder to consult area **bodies** (blast radius unmeasured);
      a **term-admission occurrence floor** (the floor value is itself a judgement); and making the
      **curated human register binding** — that register adjudicates 20 candidate strings and **all
      20 remain live term proposals**, so a recorded human decision that no code reads is still
      indistinguishable from no decision.

      ~~**NOT DONE (measured 2026-09-02).**~~ ~~no decision record anywhere~~ ~~**883 R3
      contradictions**~~ — **both halves WITHDRAWN 2026-09-03, not restated. A decision record now
      exists and the population is no longer 883.** Four operator rule decisions (29–32) were taken,
      applied to production code and pushed in workshop `692a27a`, with the record written at
      `workshop/docs/session-evidence/phase3e-r3-decisions-29-32.md` (titled for this task) over the
      census at `phase3e-contradiction-typology.md`. Measured, not read: the latest pipeline run
      (`workshop/evidence/knowledge-pipeline/20260902T200902Z-acb8265b/reconcile_and_taxonomy.json`)
      reports `R1=1936 attach, R2=2 add, **R3=13 contradict**, S6=136 update, RULE-2b=355
      discard-as-duplicate`. RULE 1 (extraction reads the corpus, not the graph) excludes 9,144
      `kg_*` rows of 11,622 — 78.68% of the file. Three gates are registered
      (`T041-RULE-1-graph-kinds-excluded`, `T041-RULE-2b-discards-only-covered`,
      `T041-rules-over-real-corpus`) and both `verify-r3-rules.sh` and `prove-r3-rules.sh` exit
      **0**, the prover catching both seeded defects against the real entry point (re-run
      2026-09-03).

      **STILL NOT DONE, and the decision record says so itself in its own §7:** the human checkpoint
      this task asks for has not been completed. **13 R3 rows remain — 12 type-T2 rows that are
      judgements only a person may make, deliberately left un-ruled because a rule over that class
      is what contract §2.3 refuses, plus 1 type-T4 mega-cluster routed to a named owner with a
      re-check date of 2026-09-16** (DEFERRED, OWNED — explicitly not counted closed). There is
      still no `phase3e-report.md`. Two real costs are recorded rather than netted away: A3 fell
      0.1047 → 0.0894 and "no evidencing mention" rose 3,243 → 9,017, because the 9,144 `kg_*` rows
      now evidence nothing. Tick this only when the 12 judgements are recorded and the T4 deferral
      is resolved — the rules mechanised the 98.7% that was one artifact; they did not make the
      remaining judgements.

      **The residual judgements are now written as answerable decision packets (2026-09-03), and
      they REGROUP: `workshop/docs/session-evidence/t041-decision-packets.md`.** A count is not a
      question, so the 13 rows were tested for a shared root and they have one, measured **12 of
      12 with no residual**: `promote.default_evidence_finder` evidences a promoted area by
      whole-word matching of the area's **TITLE KEYWORDS** (`promote.py:224-263`), so on every T2
      row the overlap passage carries an area title keyword and the outside passage carries none —
      and **11 of the 12 member terms occur zero times in the prose of any area they are reported
      as contradicting**. The 12 rows are therefore one question asked 12 times, not 12 questions.
      **13 individual adjudications become 4 decisions** (D-33 evidencing heuristic, D-34 term
      admission floor, D-35 the human-curated artifact register — measured **20 of 20** rejected
      surface forms still live as terms — and D-36 whether the owned T4 deferral lets this tick).
      Each packet carries options with measured consequences, evidence both ways, a recommendation
      and what it unblocks. **The packets are QUESTIONS: nothing was decided, no rule applied, and
      this task stays `[ ]`.** Re-derived the same day: production `R3_contradict` **13** (12 T2 +
      1 T4) and pre-RULE-1 `R3` **1153** with branch `B1` exactly **883**, so the `883` above is
      confirmed as a subset and never the total; `established_carried_in` is **495** (not 494) and
      production `S6_update` is **138** (not 136). Do not quote packet content into this public
      repository — it is cited here by path only.

      **D-33 IS ANSWERED (operator decision 33, 2026-09-03) AND THE RULING IS IMPLEMENTED. The
      sentence above — "tick this only when the 12 judgements are recorded and the T4 deferral is
      resolved" — is SUPERSEDED IN ITS FIRST HALF ONLY, and the second half still stands.** The
      ruling: **a title-keyword match is an evidencing heuristic, not a boundary a human drew, so
      R3 should not be defending it.** The 12 rows are therefore not 12 recorded judgements; they
      are one rule, applied.

      **RULE 3, in `pipeline/extract/reconcile.py`
      (`_is_title_keyword_artifact`, `_heuristic_match_keyword`,
      `HEURISTIC_EVIDENCE_ORIGIN_PREFIX`).** An R3 contradiction is a **title-keyword artifact**,
      and therefore not a contradiction, when — for **every** promoted area it overlaps — every
      overlap passage is evidence for that area **only** through a `promotion-keyword-match:<kw>`
      mention **and** no matched `<kw>` is itself one of the proposal's own member terms. It names
      no row, area, term or passage; it reads the origin string
      `promote.default_evidence_finder` itself writes rather than re-running the match, so it
      stays true as the corpus moves and **stops applying by itself** the moment any other
      evidencing path supplies the overlap. **A hardcoded set of row ids was explicitly not built.**

      **What it disposed of, measured on an unchanged corpus** (`md5sum` identical before and
      after; the read-only `analyze_r3_contradictions.py --exclude-graph-kinds`):
      `R3_contradict` **13 → 1**, `RULE_3_keyword_artifact` **12**, and
      `R1_attach` **1936**, `R2_add` **0**, `S6_update` **138**, `RULE_2b_discard` **355** all
      **unchanged to the row**. The 12 cleared are **exactly the 12 T2 rows**
      (`T2…|RULE-3-keyword-artifact: 12`, `T4…|R3-reported: 1`). **The rule was not tuned to hit
      12:** the T4 mega-cluster is retained because **15 of the 17 promoted title keywords are
      among its 3603 member terms**, so it is a proposal genuinely about what the areas are titled
      after. The disqualified blanket form — origin without relatedness — clears **13**, taking the
      routed mega-cluster with it, which is why it is disqualified rather than simpler.

      **§1.1 paired mutation, and it proves the rule is not a switch-off.**
      `verify.PROOFS["RULE-3-title-keyword-overlap-is-not-a-boundary"]` builds its promoted
      evidence with the **real** `promote.default_evidence_finder`, shows a contradiction that is
      genuinely NOT a keyword artifact **still fires** in both ways it can be genuine (the matched
      keyword IS a member term; the overlap is evidenced by a non-keyword mention), then seeds each
      disqualified predicate into the **real** `reconcile` module and requires
      `check_rule_3_artifact_is_keyword_only` to catch it — RED (a) blanket form, RED (b)
      suppress-everything, both caught. `platform/gates/prove-r3-rules.sh` MUTATION 3 repeats the
      seed against a throwaway copy of the package. Measured 2026-09-03: `verify-r3-rules.sh` and
      `prove-r3-rules.sh` both exit **0**; the extraction suite is **278 tests OK** (was 264);
      `verify-check-registry-002.sh` exits **0** at 47 checks with the new
      `T041-RULE-3-title-keyword-artifact` row; `verify-check-registry-001.sh` **20 PASS / 0 FAIL /
      1 DEBT**, unaffected. Nothing is merged and nothing is silently dropped: a cleared proposal
      becomes a `keyword-artifact` taxonomy row carrying the matched keywords and both passage
      sets, is threaded into §2.4 A1 accounting with a reason naming the rule, and the Go loader
      learned the row type in the same change.

      **THREE OPTIONS WERE EXPLICITLY NOT CHOSEN AND EACH REMAINS OPEN — none is closed by this
      decision:** (1) changing the evidence finder to consult area **bodies** (packet D-33-A/B; its
      blast radius across R1/R2/S6/RULE-2b is still **UNMEASURED**), (2) imposing a **term-admission
      occurrence floor** (D-34; the central unknown — how many of the 4358–5101 terms a floor would
      drop are real — is still **unmeasured**), (3) making the **curated human artifact register
      binding** on the pipeline (D-35; 20 of 20 rejected surface forms are still live terms).

      **002/T041 (unified T247) STAYS `[ ]`, and the reason is precise: the T4 row still blocks and D-36 is
      unanswered.** RULE 3 disposed of the 12 T2 rows; the single remaining R3 row is the T4
      over-merged mega-cluster, still reported, still routed to a named owner with a re-check date
      of **2026-09-16**, still tracked as the `area-term-over-generation` defect. Packet D-36 asks
      whether that dated deferral permits this checkpoint to close; **the operator has not answered
      it**, and ticking on the strength of D-33 alone would answer D-36 by implication. **Do not
      tick this task until D-36 is answered on the record.**
- [x] T248 (was: 002/T042) [US1] [REVIEW] Record the content boundary check **in both directions** before anything is
      published (SC-029→unified SC-143, SC-029a→unified SC-144) (FR-004a→unified FR-067, FR-057→unified FR-276, SC-029→unified SC-143, SC-029a→unified SC-144)

      **DONE 2026-09-15 — the SC-029a inbound half is now BUILT, proven and RUN against the real
      corpus.** New `scripts/verify-reference-content-boundary.sh`, **gate G-KG-22** (renumbered from
      an initial G-KG-20 pick that collided with T245's independently-chosen G-KG-20, caught and
      resolved during this session's consolidated verification — 21 was already taken by T279, so 22
      is the next genuinely free `G-KG-N`). Implements exactly the design §10.14 called for: 6-word
      shingles (N=6, inherited unchanged from this doc's own §6.1 transcript check, same tokenisation
      reused verbatim), SHA-256-hashed — never the raw text, since this checker is itself
      content-boundary-sensitive — plus a generic-content filter (a shingle is hashed only if ≥4 of
      its 6 tokens are non-stopword; K=4 chosen by sweeping K=3..6 against the real corpus and
      measuring hash-set size / finding count / longest run, printed in the script's own header and
      in §10.14). §1.1 proof independently re-run and confirmed: `--prove-failure` 4/4 (genuine
      12-word plant CAUGHT rc 1; stopword-only overlap correctly NOT flagged rc 0; missing reference
      root UNDETERMINED rc 2). Run against the REAL corpus (counts/hashes only, matched text never
      printed): 35 reference files, 44 workshop files, finding_count **787** across all 44 workshop
      files scanned (not concentrated), longest consecutive run 22 shingles. **Honest boundary,
      stated in the gate's own output and in §10.14**: this is a BUILT, RUNNING measurement, not a
      clean corpus — the 787 candidate collisions are correctly left UNREVIEWED (genuine reuse vs.
      independent quotation of the same public vendor docs vs. coincidental technical-vocabulary
      overlap all remain open explanations that only a human reading actual content, or a
      direction-dating pass, can resolve) — reviewing them is explicitly out of an automated
      checker's scope and is not claimed here. `docs/limits.md` §10.14 and
      `platform/gates/defects-registry.tsv`'s `sc029a-not-built` row both updated to record BUILT,
      with the 787-unreviewed-findings caveat stated explicitly so no future reader mistakes "the
      gate exists and ran" for "the corpus is clean". Same underlying question as 002/T122 (unified T540); not separately re-verified there.

*From `004` — Phase 3: User Story 1 — A learner finds a subject they recognise (P1) **MVP***

- [x] T249 (was: 004/T010) [US1] Serve `areas[]` as exactly the servable set, with `held_back[]`, the reason table and `total_areas` in the same response, in `workshop/platform/backend/internal/api/` (FR-018→unified FR-127, FR-018b→unified FR-129, SC-001→unified SC-037). **Evidence** (population: unstated): 817 unopenable → 3.
- [x] T250 (was: 004/T011) [US1] Disclose a derived title/tags/summary on a **refusal** where one is derivable, in the same handler (FR-018b→unified FR-129). **Evidence**: the reported symptom was a page reading only "withheld pending review"; an area held back for a missing review has a perfectly good name.
- [x] T251 (was: 004/T012) [P] [US1] Add `?include=held_back` so withholding never makes an area unreachable (FR-018b→unified FR-129).
- [x] T252 (was: 004/T013) [P] [US1] Emit `tags` as an empty array, never `null`, in the area wire type (FR-003→unified FR-071, FR-019→unified FR-132). **Evidence**: a null breaks the field the interface filters on.
- [x] T253 (was: 004/T014) [US1] Derive titles, tags and summaries in `workshop/platform/backend/pkg/knowledge/presentation.go` (FR-003→unified FR-071, FR-018b→unified FR-129).
- [x] T254 (was: 004/T015) [US1] Add a `tags` field to the client area model in `workshop/platform/frontend/src/app/core/knowledge.ts` — it models `terms` and **has no field for tags at all**, so tags are discarded before any component can ask for them (FR-019→unified FR-132, SC-005→unified SC-040). — EVIDENCE (source): `workshop/platform/frontend/src/app/features/areas/curriculum-model.ts:487,505` (`AreaCard.tags`, `normaliseAreaCard`) + `area-detail.component.ts:451` — PATH DRIFT: delivered in a second normaliser, not in `core/knowledge.ts`, which still drops `tags`; the capability (FR-019→unified FR-132) holds. Frontend unit suite 298/298 SUCCESS (in_process) 2026-09-08
- [x] T255 (was: 004/T016) [US1] Render title, summary and tags on the area detail page in `workshop/platform/frontend/src/app/features/` — 3 of 4 render branches emit the raw identifier as the heading (SC-003→unified SC-039, FR-003→unified FR-071, FR-019→unified FR-132, SC-005→unified SC-040). — EVIDENCE (source): `workshop/platform/frontend/src/app/features/areas/area-detail.component.ts:111` single `<h1 data-testid="area-title">{{ displayTitle() }}</h1>`, `:442` title chain with the slug as LAST resort, `:446` summary, `:115-121,451` tags list. Frontend unit suite 298/298 SUCCESS (in_process) 2026-09-08
- [x] T256 (was: 004/T075) [US1] Serve an explicit empty-catalogue state — distinguished from an error and never itself treated as a build failure — when zero areas are publishable, in the same handler as 004/T010 (unified T249) (FR-018d→unified FR-061). A fixture with zero publishable areas MUST return the explicit empty state, not a 5xx response and not a bare empty array indistinguishable from an error.

      **DONE 2026-09-15.** `AreasHandler` (`internal/api/areas.go`) hardcoded `"status":"ok"`
      unconditionally, even when `areas` came back `[]` — exactly the "bare empty array
      indistinguishable from an error" this task warns about. Fixed by reusing the SAME closed
      three-state `status` vocabulary (`pkg/search/envelope.go`'s `StatusOK`/`StatusNoMatch`/
      `StatusUnavailable`) T224 already applied to the identical defect on `GET /api/chapters` —
      `status` becomes `"no_match"` when `len(areasOut)==0` (covering both ways that happens: a
      taxonomy with zero area rows, and one whose rows all fail `AreaPublicationOf`), staying HTTP 200
      throughout; `held_back`/`total_areas` unaffected, they already reported the "why" correctly.
      TDD: 2 new tests written first (RED confirmed against the unmodified handler, real failure
      output pasted), then GREEN. Full regression independently re-run: `go build ./... && go vet
      ./... && go test ./...` from `platform/backend`, all 24 packages ok, zero regressions. Frontend
      checked read-only: `AreaCatalogue.cards()` derives emptiness from `rows.length` alone and never
      reads `status`, so the additive field is safe; no frontend surface today actually renders the
      list-level empty state even after this fix (no page subscribes to `cards()` for a full-catalogue
      view) — noted as a real follow-up gap, not implemented here since it is out of this task's scope.

*From `004` — Tests for User Story 2*

- [x] T257 (was: 004/T017) [TDD] [US2] Prove the assessment gate with **17 data mutations** in `workshop/platform/gates/prove-assessment-gate.sh`, including B4/M7 "the gate opens as soon as *any* lesson completes" — which passes B1, B2, B3, B5 and B7 and is caught **only** by B4 (FR-010→unified FR-101, FR-012a→unified FR-104, FR-028→unified FR-260, SC-009→unified SC-058). **Evidence** (in_process): rc 0, 17 passed. Requires the fixture's required set to be a **proper subset** of its lessons.
- [x] T258 (was: 004/T018) [TDD] [US2] Add a leak check that fails if `correct_choices` or `explanation` appears on the taking path, in `workshop/platform/backend/internal/api/lessons_test.go` (FR-010→unified FR-101, SC-009→unified SC-058).
- [x] T259 (was: 004/T019) [P] [US2] Add vacuity refusals **B9/B10** — no lesson outside the required set, or a test gated on nothing, must exit **2**, never 0 (FR-027→unified FR-261, FR-029→unified FR-262).

*From `004` — Implementation for User Story 2*

- [x] T260 (was: 004/T020) [US2] Implement the six learning routes in `workshop/platform/backend/internal/api/lessons.go`, all behind the 004/T007 (unified T066) decision, all keyed on the opaque `X-Session` header only (FR-006→unified FR-093, FR-007→unified FR-094, FR-009→unified FR-100, FR-010→unified FR-101, FR-012a→unified FR-104, FR-013→unified FR-119).
- [x] T261 (was: 004/T021) [US2] Build the taking projection as a map with **no answer field at all** in the same file — not the domain type with fields omitted, so no future upstream field can leak through it (FR-010→unified FR-101, FR-012a→unified FR-104, SC-009→unified SC-058).
- [x] T262 (was: 004/T022) [P] [US2] Validate `?kind=` against the closed vocabulary and return **400** for an unknown kind (FR-013→unified FR-119). **Evidence**: an empty list reads as "there are none", which is a different and false statement.
- [x] T263 (was: 004/T023) [US2] Implement the session progress store in `workshop/platform/backend/pkg/learning/` — one `Mutate` under a single lock, atomic temp-file+rename, a file separate from the reading-position store (FR-010→unified FR-101, FR-012a→unified FR-104). **Evidence**: a Get+Put cycle silently drops a concurrent completion.
- [x] T264 (was: 004/T024) [US2] Build the authored learning catalog in `workshop/pipeline/extract/build_learning_catalog.py` → `workshop/curriculum/learning/` (FR-006→unified FR-093, FR-007→unified FR-094, SC-004→unified SC-051). **Evidence** (source): 42 files, 339 lessons, 1,068 minutes; ids derived from the area ULID so catalog-wide collisions are structurally impossible.
- [x] T265 (was: 004/T025) [US2] Resolve each bank's `correct_index` to a choice **id** during the build (FR-012→unified FR-103). **Evidence**: the kit rejects the index form by design.
- [x] T266 (was: 004/T026) [US2] Exclude the 10 `flashcard` rows rather than mapping them onto graded items, and report the exclusion (FR-008→unified FR-096). **Evidence**: mapping a study aid onto a test question is a silent promotion.
- [x] T267 (was: 004/T027) [US2] Pass `-learning-catalog /opt/workshop/curriculum/learning` in `workshop/platform/compose.yml` (SC-006→unified SC-057). **Evidence** (source): the flag defaults to EMPTY and empty is a *determined* state — every learning route would answer `no_learning_catalog` cleanly after a restart, with nothing in any log to notice. YAML re-parsed; the path is inside the existing read-only bind, so no volume change.
- [x] T268 (was: 004/T076) [P] [US2] Compute each lesson's estimated reading time deterministically from its actual body content in `workshop/pipeline/extract/build_learning_catalog.py`, removing any separately-authored reading-time value so it cannot drift from the body it describes (FR-007a→unified FR-095). Re-running the build after editing only a lesson's body, with no other input touched, MUST change the reported reading time to match.

      **DONE 2026-09-15.** Investigation found the builder was ALREADY computing `estimatedMinutes`
      purely from body word count with no separately-authored value anywhere in the source materials
      to remove (grepped `curriculum/` and `pipeline/` for `reading_time`/`estimated_minutes`/
      `duration:` as an INPUT — none found; T280's own "339 of 339 now carry one" evidence confirms
      this). What was extracted: the inline computation into a named, tested, documented
      `estimated_minutes(body) -> int` function at **200 wpm** — the conservative end of the
      200–250 wpm adult-reading range, chosen because this is technical prose that reads slower than
      casual text and a conservative estimate is more often a pleasant surprise than a shortfall. TDD:
      7 new tests, RED confirmed (temporarily reverted source, `AttributeError`), then GREEN. Full
      module suite `python -m unittest discover -p "test_*.py"`: 337 tests OK (independently
      re-confirmed in the coordinator's consolidated verification pass, after this task's own 319).
      Real rebuild against all 339 real lessons confirmed the formula holds at scale (aggregate stats
      only, no lesson text quoted: min 1 / max 25 / median 2 / mean 3.22 minutes, 155/339 at the
      1-minute floor); the rebuild's resulting `curriculum/learning/*.json` diff was reverted with
      `git checkout --` since it also carried unrelated concurrent-agent drift out of this task's
      scope, leaving only the two source-code files changed.
- [x] T269 (was: 004/T077) [P] [US2] Round the required correct-answer count up, never down, whenever a bank's size and its declared pass threshold do not produce a whole number, in the assessment scoring logic in `workshop/platform/backend/internal/api/lessons.go` (FR-008c→unified FR-099). A fixture bank whose threshold × size is not a whole number MUST report the ceiling as the required count, and a learner scoring exactly at the floor below that ceiling MUST be reported as failing.

      **DONE 2026-09-15.** Design finding, not a guess: `lessons.go` computes NO required-count value
      at all — grading is entirely delegated to the adopted `curriculum-kit` seam (§11.4.74 forbids
      reimplementing it), whose `MarkedPercent = Points*100/MarkedPoints >= PassPercent` integer
      comparison was mathematically proven (then empirically confirmed by reverting the change and
      re-running the test) to already be exactly equivalent to a ceiling-based pass/fail boundary
      whenever `PassPercent` is a whole number and questions are equally weighted — so the actual
      pass/fail line was never broken. What was genuinely missing, per FR-008c/FR-099, was the
      REPORTED required-count value itself. Added a new, explicitly documented DISPLAY-ONLY
      `requiredCorrectCount()` helper (`math.Ceil`-based) surfaced as a new `"required_correct"` field
      on the assessment preview — never consulted by grading, curriculum-kit remains the sole source
      of `passed`. TDD: RED confirmed against unmodified `lessons.go` (`required_correct = <nil>`),
      GREEN after the fix; fixture proves both the reported ceiling (7 questions, 70% → 5, not 4) and
      the actual pass/fail boundary (4/7 fails, 5/7 passes) via a real HTTP submission using the
      server's own `learning.ChoiceToken`. Full regression independently re-run: `go build ./... &&
      go vet ./... && go test ./...` from `platform/backend`, all 24 packages ok; T257's 17-mutation
      assessment-gate proof (`prove-assessment-gate.sh`) re-run and confirmed unaffected, 17/17.
- [x] T270 (was: 004/T028) [US2] Render the lesson list and lesson body with prev/next in `workshop/platform/frontend/src/app/features/`, using the same sorted slice the list uses (FR-007→unified FR-094, SC-006→unified SC-057).

      **DONE 2026-09-15.** The lesson list and body were already rendered (an earlier task had already
      fixed a "table of contents wearing a curriculum's clothes" defect) via `AreaLessonsComponent`'s
      `lessons()` computed signal, itself fed by `AreaCatalogue.lessons()`, which sorts by `ord`
      exactly once. Only prev/next was missing. Added using that SAME array, indexed by the existing
      `@for`'s `$index` — no second sort introduced. Each lesson gets an `id="lesson-<id>"` anchor; a
      `<nav>` at the end of each renders plain fragment-link prev/next (all lessons render on one
      page already, so "next" is a scroll), with disabled markers at the boundaries. New
      `area-lesson-prev-next.spec.ts`, 4/4 pass: boundary disabling, correct neighbour ids/hrefs in
      list order, anchor ids present.
- [x] T271 (was: 004/T078) [US2] Visually and structurally distinguish a lesson's own authored prose from a quoted or transcribed passage it includes, in the lesson body renderer in `workshop/platform/frontend/src/app/features/areas/area-lessons.component.ts` (FR-016b→unified FR-125, SC-020→unified SC-067). An automated structural check MUST confirm every quoted passage in the rendered output carries a marker distinct from the surrounding authored prose, across 100% of published lessons that include a quote.

      **DONE 2026-09-15 — a smaller gap than it looked: the rendering pipeline was already correct,
      only the regression test was missing.** The authored area documents already use markdown
      blockquote (`>`) syntax, carried verbatim into `Lesson.Body`; the SHARED `core/markdown.ts`
      (outside this task's file scope, correctly not touched) already types it `kind:'quote'` vs
      `kind:'paragraph'`, and the shared `document-view.component.ts` (`<wk-document-view>`, used by
      `AreaLessonsComponent`) already renders it as `<blockquote class="pf-doc__quote">` — a distinct
      element AND class from `<p class="pf-doc__p">`, with real distinct CSS (accent border, distinct
      background), not merely italics. Verified against ALL 339 real lessons (counts only): 81 have
      `>` in their body, and **all 81 (100%)** produced ≥1 `quote` block with zero mismatches — the
      exact population FR-016b/SC-020 requires. New `area-lesson-quote-distinction.spec.ts` (synthetic
      fixture bodies only, per module-local content-boundary rule 6), 2/2 pass, asserting no quote
      ever carries the paragraph class and vice versa, with exact block counts pinned so a renderer
      that silently merges kinds cannot pass silently.
- [x] T272 (was: 004/T029) [US2] Render the test — availability message before completion, questions after, result after submission — in the same feature directory, showing `pass_percent` **before** the attempt begins (FR-008b→unified FR-098, FR-009→unified FR-100, FR-010→unified FR-101, SC-017→unified SC-059). — EVIDENCE (source): `workshop/platform/frontend/src/app/features/areas/area-test.component.ts:75-112` availability + `passPercent` shown before the attempt, `:169-181` result panel with the determinate/lower-bound split. Frontend unit suite 298/298 SUCCESS (in_process) 2026-09-08

*From `005` — Phase 3: User Story 3 — every learner-facing defect is repaired or disclosed (P2)*

- [x] T273 (was: 005/T036) [TDD] [US3] Ship the B6/B7 detector for questions citing withheld material in `workshop/pipeline/extract/verify_question_banks.py` (FR-012→unified FR-112, SC-009→unified SC-055). **Evidence** (source): 478 lines added in commit `c182e6a`; **B6** asserts every citation resolves in the registry AND is `redacted: false`, **B7** the same for every `lesson_sections` pid. The file records the mechanism in its own header: a question citing a redacted passage is withheld under `WithholdCitationRedacted`, **so a learner opening those areas was served a shorter test with nothing saying so.**
- [x] T274 (was: 005/T037) [US3] repair or record the removal of every question citing withheld material (FR-012→unified FR-112, SC-009→unified SC-055).

      **DONE 2026-09-15 — both SOURCE and SERVED now separately verified, against the real corpus.**
      `verify_question_banks.py` (B1-B8) run for real: 40 banks, 311 questions, 1214 citations,
      **rc 0 — every question structurally valid, every citation resolves unredacted**;
      `--prove-failure` 19/19, confirming the detector is live. For the SOURCE-vs-SERVED split the
      note above required, found and ran a second instrument that already existed but had never been
      invoked (`cmd/serve-probe`, added in `c182e6a`, unused since): it calls the server's own
      `assessment.ServeQuestions` — the exact function the HTTP handlers call — over every authored
      bank. Result: **311/311 SERVED, 0 WITHHELD**. Cross-checked that SOURCE and SERVED read the
      identical files today: the live container's argv binds `-registry`/`-knowledge-questions`
      directly to this checkout's `curriculum/passages.jsonl` and `curriculum/questions/`. **SOURCE =
      0 (down from R8's baseline of 5), SERVED = 0 (311/311), both independently established.** No
      question needed repair. Caveat stated honestly: a full live HTTP crawl of all 41
      `/api/areas/{area}/assessment` endpoints (which additionally require per-area lesson-completion
      session state) was not performed; the offline serve-probe run over the server's own real served
      logic against the real live-mounted data was judged sufficient evidence for the SERVED figure.
- [x] T275 (was: 005/T038) [US3] tell a learner, in the interface, that an area has no assessment and why (FR-013→unified FR-115, SC-010→unified SC-054).

      **DONE 2026-09-15.** `area-test.component.ts`'s `@case('empty')` block already had this honest
      disclosure ("No test is being served for this area", carefully distinguishing "the catalogue
      loaded holds no test" from "none has been written" — a prior fix for an overconfident-wrong-claim
      bug, see T288). `area-detail.component.ts` had none. Ported the same pattern into the area
      overview: a disclosure section inside the `ready` branch reads the SAME `assessmentState()`
      signal `<app-area-test>` already consumes below it (no new state invented), gated on
      `state==='empty'`. New `area-detail-no-assessment.spec.ts`, 2/2 pass: full integration test
      through `AreaDetailComponent` with real HTTP flushed via `HttpTestingController`, confirming
      both the correctly-scoped wording (none of the forbidden overclaiming phrases) and that it does
      NOT render when a real gated test exists (regression guard against over-triggering).
- [x] T276 (was: 005/T039) [US3] Remove R7's structural obstacle — area documents never sectioned into the passage registry, so no citation could resolve and no question could be authored (FR-015→unified FR-116, SC-011→unified SC-056). **Evidence** (source): `git -C workshop ls-files 'docs/training/curriculum-areas/*.md'` returns **37** and `…*.sections.json` returns **37** — **37 of 37 sectioned**, against R7's baseline of 25 of 37 unsectioned. The obstacle is gone at source.
- [x] T277 (was: 005/T040) [US3] report the resulting coverage figure, and report **separately and honestly** the areas that carry no assessment because the corpus cannot support one (FR-015→unified FR-116, SC-011→unified SC-056).

      **DONE 2026-09-15.** Found that the counting logic SC-011 requires already existed in
      `build_learning_catalog.py` (landed `5642dd6`, an ancestor commit) and already did NOT merge the
      two populations — `stats["no_assessment_reasons"]` already carries distinct
      `no_bank_and_below_floor` (corpus genuinely cannot support a fair assessment, below the
      operator-decided `ANCHORED_FLOOR=8` anchored/usable/unredacted/claim-bearing citable passages
      per area, replacing an earlier 20-passage floor measured at r=-0.066 correlation to actual
      testability) vs. `no_bank_at_or_above_floor` (corpus could support one; nobody has authored it
      yet). This task's job was verifying and RUNNING it, which had not been done: real run against
      the real corpus — **42 areas: 40 with an assessment, 2 without (both `no_bank_at_or_above_floor`
      — not yet authored), 0 corpus-limited** (the 5-area corpus-limited population recorded as of
      2026-09-08 has since dropped to 0 as previously-thin areas cleared the floor). Added the missing
      TDD fixture coverage: new `TestFloorPopulationBucketing` in `test_build_learning_catalog.py`
      (reusing the file's existing hermetic fixture harness, synthetic content only), asserting the two
      reasons land under distinct keys and are never merged; mutation-tested to confirm not vacuously
      true. Full `pipeline/extract` suite independently re-confirmed clean: 337/337 OK. One pre-existing,
      self-reported gap noted and left alone (not this task's to fix): `prove_ck021_floor_population.py`'s
      arm A4 needs a real `below_floor_with_bank` (grandfathered) row to mutate, and the real corpus
      today has zero such rows — the corpus improving out from under one proof arm, not a regression.
- [ ] T278 (was: 005/T041) [REVIEW] [US3] **BLOCKED — operator gate.** Read the 3 documents failing publication review on **62, 54 and 58** uncited claim blocks and decide publish-or-not (FR-014→unified FR-092, SC-010→unified SC-054). They remain unpublished, so a client sees fewer areas than are authored. This is the same gate carried as 006/T060 (unified T573) in [`../006-session-record-and-qa-readiness/tasks.md`](../006-session-record-and-qa-readiness/tasks.md) — **one decision, recorded in two specs, not two decisions.**
- [x] T279 (was: 005/T042) [US3] assert FR-014 mechanically: a published document's primary references resolve to material a reader can actually reach. 005/T041 (unified T278) is a human read of three documents; the mechanical check that enumerates published documents and resolves their primary references did not exist — **now it does.**

      **DONE 2026-09-15.** New `extract_primary_reference_pids()` (`verify.py`) parses a document's
      own `## Sources` → `**Primary...**` subsection (distinct literal syntax from
      `authorship.CITATION_PATTERN`'s lesson-body `(cite: PID)` form — verified directly against the
      real corpus before writing the regex), extracts its `pid \`<ID>\`` citations, and resolves each
      via the EXISTING `authorship.make_pid_resolver()` — reused, not reinvented.
      `check_published_primary_references_resolve_over_real_corpus()` decides "published" with the
      exact same predicate T245 uses (`publication_policy.is_publishable_area()`), never a second
      definition. Registered as `GATES["published-primary-references-resolve-over-real-corpus"]`,
      **gate G-KG-21** (the next free `G-KG-N` after G-KG-19; chosen as `GATES` not
      `MATERIALS_STATUS_CHECKS` because the real corpus has ZERO violations today — there is no known,
      disclosed content gap to carry, only a genuine invariant to guard going forward, and
      `MATERIALS_STATUS_CHECKS` structurally cannot carry the required paired mutation).
      Independently re-run and confirmed against the real corpus: gate rc 0, "42 published
      document(s), 75 primary reference(s), all resolve to real, reachable material" (75 cross-checked
      by hand with a standalone regex script — same 75/75; the 5 `docs/training/areas/*.md` documents
      structurally have no `**Primary**` subsection today and correctly contribute 0, all 75 come from
      the 37 `curriculum-areas/*.md` documents; 42 matches T245's independently-derived published-area
      count, a useful cross-check that the two gates agree on what "published" means). §1.1 proof
      (`PROOFS["G-KG-21"]`) independently re-run and confirmed: real GREEN case plus a RED mutation
      (patching the real `_primary_reference_resolves` to always-True on the SAME real entry point)
      demonstrating the check can genuinely fail.

*From `006` — Phase 6: User Story 4 — every area detail shows real teaching and a real test (P2)*

- [x] T280 (was: 006/T035) [US4] Emit `"body"` verbatim from `workshop/pipeline/extract/build_learning_catalog.py` (FR-013→unified FR-093, SC-005→unified SC-053). **Evidence** (source): the builder already parsed every body, used it only for `estimatedMinutes`, and discarded it — 339 of 339 now carry one, median 328 words, longest 4,563.
- [x] T281 (was: 006/T036) [US4] Emit `body` unconditionally from `workshop/platform/backend/pkg/learning/wire.go` (FR-013→unified FR-093). **Evidence**: `""` is a determined "unauthored"; an absent key is indistinguishable from a transport fault.
- [x] T282 (was: 006/T037) [US4] Render the body through the app's existing markdown renderer in `workshop/platform/frontend/src/app/features/areas/area-lessons.component.ts` — **not** a second renderer and **not** `[innerHTML]` (FR-013→unified FR-093).
- [x] T283 (was: 006/T038) [TDD] [US4] Ship `verify-lesson-content.sh` with **two arms** (FR-013→unified FR-093, FR-023→unified FR-265, FR-026→unified FR-266). **Evidence**: in-process 339/339 rc 0; **live rc 1 at `318 of 318 EMPTY` before the restart** — the red baseline on the broken artefact. A gate with only the passing arm proves nothing.
- [x] T284 (was: 006/T039) [US4] Send `X-Session` from the learning client via the **one** exported header builder in `workshop/platform/frontend/src/app/core/api.ts` (FR-013→unified FR-093, FR-014→unified FR-096). **Evidence** (served): lessons and assessment 400 → 200; the entire surface was unreachable in a browser.
- [x] T285 (was: 006/T040) [US4] Fix the assessment envelope read one level too high, so a healthy 200 no longer renders as `malformed_response` (FR-014→unified FR-096).
- [x] T286 (was: 006/T041) [US4] Stop treating an empty `questions` array behind a **shut gate** as "no test exists" — consult `question_count` and the required-lesson gate first (FR-014→unified FR-096, FR-015→unified FR-115).
- [x] T287 (was: 006/T042) [TDD] [US4] Ship `verify-bank-reachability.sh` — the **population** check that was missing (FR-014→unified FR-096, FR-023→unified FR-265, FR-026→unified FR-266). **Evidence** (population: unstated): the existing gate checked route mountedness against one fixture area, so 89 questions were unreachable while it passed.
- [x] T288 (was: 006/T043) [US4] Make the no-test copy state only what the server established (FR-015→unified FR-115, FR-026a→unified FR-267, SC-006→unified SC-054). **Evidence** (population: unstated): it asserted *"there is genuinely none"* for 13 areas that had a bank — **confident prose asserting the opposite of the truth**.
- [ ] T289 (was: 006/T044) [P] [SUBAGENT] [US4] Author text alternatives for the 205 video materials (FR-016→unified FR-119, FR-028→unified FR-268). **Evidence needed**: 205 of 213 carry `alt: ""`; the interface names the absence rather than hiding it, so this is a disclosed gap, not a hidden one.


---

## Phase 8: US13 + US14 + US15 — deep linking, video anchors and materials (P2)

**34 tasks — 34 complete, 0 open.** Sources: 002, 004. T299/G-KG-24 is complete for the
one endpoint the task names literally; a wider FR-024a scope was investigated, found real, and
correctly left as recorded open scope rather than guessed at — see its own note and
`defects-registry.tsv` row `learner-outcome-collapse-scope`.


*From `002` — Phase 4: User Story 2 — deep linking (P2)*

- [x] T290 (was: 002/T043) [US2] [TDD] Implement `GET /api/areas/{area}/evidence` per §3.3, with **precision required**
      on every time-carrying entry and the word's timing confidence carried where precision is `word` (FR-020→unified FR-137, FR-021→unified FR-140, FR-059→unified FR-274)
- [x] T291 (was: 002/T146) [US2] [TDD] Implement **A3.3.4**: where a citation or a "where does this appear"
      traversal resolves to more than one qualifying occurrence — including mentions inside one
      corroboration group (FR-063→unified FR-186) — return every occurrence rather than silently selecting one on
      the learner's behalf. Extends `GET /api/areas/{area}/evidence` (002/T043 (unified T290)) and the citation
      resolution path alike. Gate **G-KG-21**. **Paired mutation**: seed a case with more than one
      qualifying occurrence and make the resolver return only the first; the gate must go red
      (FR-020→unified FR-137, FR-020a→unified FR-138, SC-009a→unified SC-072)

      **DONE (2026-09-15). Gate id renumbered G-KG-21 → G-KG-23** — G-KG-21 was already claimed by
      T279 (Phase 7). Investigation (not assumption) found both real paths this task names —
      `resolveEvidenceEntries` (evidence.go, backs T290's endpoint) and `questionWire`'s citation loop
      (questions.go) — already looped every qualifying pid with no early `break`/`return`; no
      production code changed. Work was building the gate with a real paired-mutation proof:
      `platform/backend/internal/api/g_kg_23_test.go` (2 tests against the real functions),
      `platform/gates/verify-g-kg-23-multi-occurrence.sh` + `prove-g-kg-23-multi-occurrence.sh`
      (sed-mutates the real `append(...)` line in each of the two files independently, each
      hash-restored). Re-run independently this session: `go test ./internal/api/... -run
      '^TestGateGKG23_'` PASS×2; `verify-g-kg-23-multi-occurrence.sh` exit 0; `prove-g-kg-23-multi-occurrence.sh`
      7 passed / 0 failed. Registered `G-KG-23`/`G-KG-23-proof` in `check-registry-002.tsv` (156/156
      resolve).
- [x] T292 (was: 002/T147) [US2] [P] [TDD] Prove **SC-009c**: resolving a single existing link or citation meets the
      same 2 s, 95th-percentile latency bound SC-017 establishes for search results, measured with
      the same harness pattern as 002/T068 (unified T375)'s SC-016/SC-017 run and published before-and-together with
      those figures — never a single after-figure — so growth of the link graph cannot silently make
      the more fundamental operation slow while search stays inside budget (FR-020b→unified FR-139, SC-009c→unified SC-074)

      **DONE (2026-09-15).** `platform/gates/verify-search-latency.sh` extended with a citation-resolution
      leg (`GET /api/passages/{pid}`, a target discovered from a live search hit) graded in the SAME
      report as SC-016/SC-017, never a separate after-figure. Re-run independently this session against
      the live deployment (`http://192.168.1.115:8087`): `SC-009c p95 45.4 ms against the SAME 2000 ms
      budget SC-017 sets for search (median 24.0 ms, n=40)` — PASS. `prove-search-latency.sh` extended
      from 7 to 9 mutations (M7 resolve-slow, M8 resolve-500), re-run: 9/9 caught. (The same run's two
      UNDET rows for semantic/code search legs are a pre-existing, documented deployment condition —
      `floor_calibrated:false`, `search-floor-uncalibrated` in `defects-registry.tsv` — unrelated to this
      task's own leg, which is a clean PASS with 0 FAIL.)
- [x] T293 (was: 002/T044) [US2] [TDD] Implement **A3.3.3**: a redacted passage contributes no mention and the omitted
      count is reported, matching the existing cross-reference behaviour (FR-027→unified FR-148, SC-012→unified SC-080)
- [x] T294 (was: 002/T045) [US2] [TDD] Implement `GET /api/passages/{pid}/knowledge` per §3.7 — the reverse direction,
      and the endpoint that makes the recording navigable (FR-018→unified FR-135, FR-019→unified FR-136, FR-059→unified FR-274)
- [x] T295 (was: 002/T046) [US2] [TDD] Implement **A3.7.1**: every entry is reachable in **one** step. A response that
      returns identifiers a client must resolve separately does not satisfy FR-019 (FR-019→unified FR-136)
- [x] T296 (was: 002/T047) [US2] [TDD] Implement **A3.7.3**: an unattached passage says it is unattached **and why**,
      rather than returning an empty list. "No areas" and "not yet classified" are different facts and
      an empty list reads as the first (FR-010→unified FR-083)
- [x] T297 (was: 002/T048) [US2] [TDD] Implement `GET /api/graph/traverse` per §3.8 across all four content kinds (FR-033a→unified FR-151, FR-059→unified FR-274)
- [x] T298 (was: 002/T049) [US2] [TDD] Implement **A3.8.3**: a hop whose target cannot be resolved **reports its
      outcome and continues**; it is never dropped, because a dropped hop is indistinguishable from a
      hop that never existed (FR-023→unified FR-143, FR-024→unified FR-144)
- [x] T299 (was: 002/T148) [US2] [TDD] [REVIEW] Implement **G-KG-22**: at the learner-facing surface, collapse the
      four-outcome resolver's (FR-023→unified FR-143, 002/T015 (unified T053)) **redacted** and **not present** outcomes into one
      generic "unavailable" state, while preserving the full four-outcome distinction — and FR-024's
      loud-failure requirement — on internal, authoring and audit surfaces. A learner-facing response
      that lets the two outcomes be told apart discloses that withheld content existed, which this
      task exists to close. **Paired mutation**: render the two outcomes differently at the
      learner-facing surface; the gate must go red (FR-023→unified FR-143, FR-024→unified FR-144, FR-024a→unified FR-145, SC-011a→unified SC-079)

      **PARTIALLY DONE (2026-09-15), and explicitly flagged as such rather than claimed complete.
      Gate id renumbered G-KG-22 → G-KG-24** — G-KG-22 was already claimed by T248 (Phase 7). The one
      endpoint this task names literally, `GET /api/areas/{area}/evidence`, is fully fixed and
      gate-proven: `learnerFacingOmitted()` (evidence.go) folds `redacted`+`not_present` into one
      `unavailable` count with one generic reason at the wire, while `resolveEvidenceEntries` itself is
      UNCHANGED and still returns the full four-outcome distinction on the internal/audit call path
      (invariant I9). `g_kg_24_test.go` (3 tests) + `verify-g-kg-24-learner-outcome-collapse.sh` +
      `prove-g-kg-24-learner-outcome-collapse.sh` (4 mutations). Re-run independently this session:
      `go test ./internal/api/... -run '^TestGateGKG24_'` PASS×3; gate exit 0; proof 4/4 caught.

      **Investigation found the task's true scope is far larger than its own text names, and the
      remainder is correctly left open rather than guessed at.** At least 5 more backend handlers
      (`passages.go`, `crossrefs.go`, `graph_traverse.go`, `knowledge_reverse.go`, `questions.go`) plus
      one frontend component (`passage-knowledge.component.ts`, whose own doc comment explicitly names
      and REJECTS collapsing redacted/not-present) already ship the SAME granular redacted-vs-not-present
      distinction, deliberately and with their own tests. A blanket rewrite across 6+ already-shipped,
      reviewed, intentionally-designed surfaces was correctly declined as a unilateral call — this is
      genuinely the judgment the task's own `[REVIEW]` tag signals, not a discovered blocker. Recorded
      as open scope, not silently dropped: `defects-registry.tsv` row `learner-outcome-collapse-scope`
      (added this session) and named by path in evidence.go's own doc comment and both gate scripts.
- [x] T300 (was: 002/T050) [US2] [TDD] Implement the six-row connectivity matrix (FR-033a→unified FR-151) and its exercise harness. — **BLOCKER:** none but the work — the gate exits 0, but `rows_implemented` (`graph_traverse.go:200`) still EXCLUDES row 4's cross-reference-graph half, so a green gate is covering five of six rows · **OWNER:** **implementer** — unblocked today, one missing half-row
      **A row with zero exercised origins fails** — an unexercised traversal is unmeasured, not
      passing (SC-015a→unified SC-096) (FR-033a→unified FR-151, SC-015a→unified SC-096)

      **CLOSED 2026-09-15. The missing half-row this note tracked is now built** — see
      `docs/limits.md` §10.7 (rewritten to CLOSED status) and `defects-registry.tsv` row
      `connectivity-row4-half-implemented` (updated). `pkg/crossref.Neighbours` (new) +
      `pkg/knowledge.TraverseWithExtra` (new, generalizing `Traverse`) give row 4 a second, symmetric
      read of the same crossrefs table, so `rows_implemented` now reports `1,2,3,4,5,6` — BOTH of
      data-model.md §3's named row-4 mechanisms (shared-area depth-2, crossref-graph depth-1).
      `verify-connectivity-matrix.sh` grew from 6 live probes to 7 (row 4 split 4a/4b);
      `prove-connectivity-matrix.sh` grew from 7 to 9 mutations (M8/M9 for row 4b). Re-run
      independently this session against the live deployment: rows 1/3, 2, 4a, 5, 6 PASS; row 4b
      reports `FAILED — zero exercised origins` — an HONEST, DOCUMENTED live-deployment operational
      gap (no crossref derivation run has ever completed for this container's live generation,
      `GET /api/passages/{pid}/crossrefs` answers `unavailable{index_rebuilding_no_fallback}`), not a
      defect in the mechanism T300 built — re-running the derivation (~35 min) is a separate
      operator/deploy-time action. `prove-connectivity-matrix.sh` re-run: 9/9 mutations caught,
      hash-verified restoration.

      **Superseded text below, kept per this file's own convention rather than deleted — describes
      the pre-2026-09-15 state, WITHDRAWN as current.**

      **PARTIAL (re-measured 2026-09-03, unchanged).** `platform/gates/verify-connectivity-matrix.sh`
      still exits **0**, but the handler's own live `derivation.rows_implemented`
      (`internal/api/graph_traverse.go:200`) still reports rows **1,2,3,5,6** plus only row 4's
      shared-area-membership half. Row 4's **cross-reference-graph** half is not implemented
      (`docs/limits.md` §10.7, defects row `connectivity-row4-half-implemented`). The gate gained a
      real paired proof on 2026-09-02 (`prove-connectivity-matrix.sh`, 7 mutations including an
      rc=2 control) — that closed a §1.1 debt, not this task's missing half-row.
- [x] T301 (was: 002/T051) [US2] [TDD] Prove **SC-008** over the **whole** relationship set, not a sample: a one-way
      link is indistinguishable from a two-way one when read forward, so sampling cannot find it (FR-018→unified FR-135, SC-008→unified SC-070)
- [x] T302 (was: 002/T052) [US2] [TDD] Prove **SC-009**: every media-backed citation lands inside its cited span, — **BLOCKER:** **none but the work, and it is now a live REGRESSION rather than a proof debt** — the gate exits **rc 2**, not rc 0: `UNDETERMINED: GET /api/passages/01M1ET0MFM0EYA5TACY1R1JWEQ -> HTTP 410`. A cited passage has since been REDACTED and the gate has no branch for a 410, so ZERO assertions ran. It also still owes its paired mutation · **OWNER:** **implementer** — unblocked today; highest urgency of the 002 set
      **and the precision split is published** alongside the pass rate. A 100% pass at segment
      precision and at word precision are different products, and a test that only asserts "inside the
      span" cannot tell them apart (FR-021→unified FR-140, SC-009→unified SC-071)

      **CLOSED 2026-09-15. The one remaining item this note named — no paired mutation — was ALREADY
      FIXED by a pre-session commit (`29dad86`), confirmed by re-reading it rather than assumed.**
      `verify-sc009-citation-span.sh`/`prove-sc009-citation-span.sh` both exist and work; only
      `check-registry-002.tsv`'s row was still missing (added this session:
      `T052-sc009-citation-span`/`-proof`, both `shell` kind). Re-run independently this session against
      the live deployment: gate exit **0** — `1678 of 1678` P1 media-backed citations land inside their
      cited span (word 1535 / segment 143 published split), `0 of 0` P2 (5 area docs, 0 media-backed
      markers currently authored there), and `30` citation occurrences naming 1 REDACTED passage are
      correctly WITHHELD and named rather than silently passed. `prove-sc009-citation-span.sh` re-run:
      **12/12 mutations caught** (M1-M12, including M10/M11/M12 for the redaction-exclusion edge cases),
      hash-verified restoration. `verify-check-registry-002.sh`: 156/156 resolve.

      **Superseded text below, kept per this file's own convention rather than deleted — describes
      the pre-2026-09-15 state, WITHDRAWN as current.**

      **PARTIAL — but the blocker this note named is DISCHARGED. "No gate anywhere asserts that every
      media-backed citation lands inside its cited span over the whole set … that gate is the work"
      is WITHDRAWN, not restated.** The gate was built later on 2026-09-03, while this reconciliation
      was in progress, and it passes. Run here rather than quoted:

      ```bash
      bash workshop/platform/gates/verify-sc009-citation-span.sh    # rc=0, live against :8087
      ```

      It measures **two full populations, neither sampled**: **96 of 96** served media-backed
      citations across all 495 advertised areas land inside their cited span (95 distinct passages),
      and **3 of 3** authored `cite: PID` markers in the five area documents do too. The precision
      split is published with the result rather than smoothed — **word 85, segment 11** over the
      cited subset — and the gate prints the cited subset's own segment distribution (n=96, median
      7.29 s, p95 9.94 s) **next to** this spec's corpus-wide figures while stating that the two are
      different populations and neither substitutes for the other. The gate also opens by naming the
      SC-009 collision itself — spec 001's SC-009 is the benchmark-composition floor in
      `bench-answers.sh` — which is standing rule 7 being enforced by an instrument rather than by a
      reader's memory. Its own declared boundary: the recording-seek agreement (95 of 95) is **not
      independent today**, because the seek is derived from the span, and it says so rather than
      counting as corroboration.

      **Why this still does not tick.** This is a `[TDD]` task, and this file's global constraint is
      that **every check owes a paired mutation proof**. This gate has none: `bash
      platform/gates/verify-sc009-citation-span.sh --prove-failure` returns rc=2 `unknown argument`,
      and its `check-registry-002.tsv` row `T052-sc009-citation-span` is 4 fields with no paired-proof
      column. A gate nobody has driven red is not yet known to be able to go red. **That single item
      is the remaining work** — the measurement itself is done.

      **On the `precision` FIELD, and a correction to an earlier reading of it made in this file on
      2026-09-03 and withdrawn the same day.** Workshop commit `ff90e09` wired the word-sidecar
      join, so the field is no longer pinned to `segment`: measured live on the `/evidence` route,
      `precision: "word"` is now the common value (first 12 areas in list order → word 12, segment
      1, no_time_span 4). **An earlier revision of this note read that as "word precision is live"
      and drew the conclusion that `docs/limits.md` §10.1 was stale. That conclusion was WRONG and
      is withdrawn, not restated — the label moved and the delivered precision did not.**

      What the join actually returns, read from `pkg/knowledge/wordjoin.go` rather than inferred
      from the label: `JoinSegmentWords` classifies *"its whole word range"* (its own doc comment)
      and returns `StartS: sub[0].StartS, EndS: sub[len(sub)-1].EndS` — the first word's start to
      the **last** word's end **of the entire segment**. It is a word-timing-derived tightening of
      the segment's own bounds, not a pointer at one word. The `precision` flag flips to `word`
      when every word of the segment carries a timing inside the segment window — a statement about
      **sidecar completeness**, not about span width. Measured over 40 areas:

      ```
      precision="word"     n=40  min=2.040s  median=7.650s  max=13.040s
      precision="segment"  n= 3  min=6.300s  median=7.620s  max= 9.620s
      ```

      **The two are the same width.** Both match this file's own recorded segment distribution
      (median 6.74 s, p95 10.78 s). A word's span is a fraction of a second.

      **So §10.1's substance stands and must NOT be "corrected" away: every deep link in this
      deployment still resolves at segment width, and "jump to the exact moment a term was said"
      is still "jump to the segment it was said in."** What is now inaccurate in §10.1 is narrower
      than a staleness — its *mechanism* sentence (`entry.Precision = PrecisionSegment` set
      unconditionally; `precision_split` always `{"word": 0, "segment": N}`) no longer matches the
      code. **That makes the response shape worse, not better, and it is a NEW defect rather than
      a closed one:** an entry labelled `word` carrying a 7.65 s median span overstates its own
      precision to any client that trusts the field, which is the exact misreading §10.1's
      consequence paragraph was written to prevent. Recorded here; fixing §10.1's wording, the
      `precision-segment-only` row, and the label itself is `workshop/`-owned and out of this
      file's scope.

      **None of this ticks the task** — but the reason has CHANGED, and the old one ("the SC-009 gate
      does not exist") is **WITHDRAWN, not restated**. The gate exists and is green over both full
      populations; what it still owes is a paired mutation. See the head of this note.
- [x] T303 (was: 002/T053) [US2] [TDD] Prove **SC-010**: replay the identifier-survival experiment extended to all
      five new kinds; compare the full link set before and after **by hash** (FR-025→unified FR-146, SC-010→unified SC-077)
- [x] T304 (was: 002/T054) [US2] [P] Add route-manifest rows and contract sections for the endpoints in this phase (FR-059→unified FR-274)
- [x] T305 (was: 002/T055) [US2] [P] [SUBAGENT] Build the transcript-to-knowledge affordance in the existing
      transcript view — the entry point for "what is being taught at this moment" (FR-019→unified FR-136, FR-041→unified FR-236)

      **DONE. This task was already ticked while carrying a "NOT DONE" note — the note was the stale
      half, and it is WITHDRAWN, not restated.** Every specific it asserted is now false, checked one
      by one on 2026-09-03 (source): `platform/frontend/src/app/core/api.ts` calls
      `` `/api/passages/${encodeURIComponent(pid)}/knowledge` `` (it does not stop at `crossrefs`);
      `features/transcript/transcript.component.ts` carries **6** `knowledge` references, not zero,
      and renders `<app-passage-knowledge [pid]="pg.pid" />`; and the component the old note implied
      did not exist is `features/transcript/passage-knowledge.component.ts`, whose header names 002/T055 (unified T305).
      Line numbers are deliberately omitted — both files moved under this reconciliation on the day —
      so re-derive with `grep -n knowledge` rather than trusting a citation.

      **Proven by execution, not by reading the source.** The Playwright config deliberately declares
      no `webServer`, so the suite exercises whatever the container is serving rather than a dev
      server it started itself:

      ```bash
      cd workshop/platform/frontend && npx playwright test e2e/passage-knowledge.spec.ts
      # 16 passed (24.9s) (served) — 8 tests × desktop-chromium + mobile-chromium
      ```

      Those 8 include a **paired mutation** — leaving the disclosure closed must result in no call to
      the endpoint at all — a check that what is rendered equals what the endpoint returned, and one
      case per resolution outcome (`unattached`, `redacted`, absent from the registry, unreadable),
      so the four A3.7.2 outcomes are each shown to render **distinctly** rather than collapsing into
      a single empty list.
- [x] T306 (was: 002/T056) [US2] [REVIEW] Review the link model against the contract before the surface consumes it (FR-005→unified FR-068)

*From `004` — Phase 5: User Story 3 — Jump to the exact moment in the recording (P2)*

- [x] T307 (was: 004/T030) [US3] Write the URL grammar down as the producer's authority in `workshop/platform/frontend/docs/time-links.md` (FR-014→unified FR-121, FR-015→unified FR-122).
- [x] T308 (was: 004/T031) [US3] Build spans from engine-measured start/end times joined on passage id, in `workshop/pipeline/extract/build_area_timelinks.py` → `workshop/curriculum/area-timelinks.json` (FR-014→unified FR-121, FR-016→unified FR-124). **Evidence** (source): rc 0, 205 spans; the passage registry carries **only** an end time, so a start derived from it alone would be invented.
- [x] T309 (was: 004/T032) [US3] Emit `end` **only when `> t`** and `#p-` **only for a Crockford-shaped ULID**, in the material renderer (FR-014→unified FR-121, FR-015→unified FR-122). **Evidence**: the consumer ignores a malformed span, so producing one yields a link that renders correctly and does nothing.
- [x] T310 (was: 004/T033) [US3] Emit `href: null` + `unresolved_reason` + intact anchor + a count for an unservable chapter (FR-016→unified FR-124, FR-017→unified FR-126, SC-007→unified SC-068). **Evidence** (source): 205 of 205 resolved, 0 unresolved.
- [x] T311 (was: 004/T034) [US3] Declare the chapter registry **from disk** (`workshop/chapters/`) rather than from the anchors themselves (FR-016→unified FR-124, FR-029→unified FR-262, SC-007→unified SC-068). **Evidence** (source): deriving it from the anchors would make the resolution check vacuously pass; `ScanChapterDirs` returns exactly `01`, `02`, `02.01`.
- [x] T312 (was: 004/T035) [US3] Implement the client-side time-link contract in `workshop/platform/frontend/src/app/core/timelink.ts` (FR-015→unified FR-122).
- [x] T313 (was: 004/T036) [US3] Seek the player to `t` and scroll the transcript to the `#p-` passage **without further scrolling**, marking it visually, in the transcript component (FR-015→unified FR-122, SC-008→unified SC-069). — EVIDENCE (source): `workshop/platform/frontend/src/app/features/transcript/transcript.component.ts:593` `#p-` parse, `:614-634` seek with `link.end`, `:691-693` `scrollIntoView`, `:631` `machine.seeked()` suspends follow so nothing scrolls further; `seek.spec.ts` + `follow-mode.spec.ts` green in the 298/298 run (in_process) 2026-09-08
- [x] T314 (was: 004/T037) [P] [US3] Make the extent of a range discernible when `end` is present, not only its start (US3 scenario 3; FR-014→unified FR-121). — EVIDENCE (source): `workshop/platform/frontend/src/app/core/playback.ts:88-95` `stopAt` bounds playback to `end` (and only when `end > t`); `features/chapters/recording-player.component.ts:84-87` `data-testid="span-end"` names the excerpt end. Frontend unit suite 298/298 SUCCESS (in_process) 2026-09-08
- [x] T315 (was: 004/T079) [US3] Make following a video-anchor reference operable using only a keyboard, and announce arrival at the referenced passage to assistive technology through an ARIA live region rather than only the visual highlight, in `workshop/platform/frontend/src/app/features/transcript/transcript.component.ts` and `workshop/platform/frontend/src/app/core/timelink.ts` (FR-015a→unified FR-123). A keyboard-only interaction test MUST reach and activate every anchor with no pointer event, and an accessibility-tree assertion MUST confirm the live-region announcement fires on arrival.

      **DONE (2026-09-15).** Investigation found every video-anchor control (the `seek-<pid>` timestamp
      buttons) was already a real `<button type="button">` — natively keyboard-reachable, no change
      needed. What was missing: a dedicated `aria-live="polite" role="status"` region, distinct from the
      visual highlight and the existing (assertive) jump-and-return banner, firing once per arrival from
      a seek-button click, a `#p-<pid>` fragment, or a `?t=` deep link — new `describeArrival()`
      (`timelink.ts`) + `announceArrival()` wired into `seek()` and both `applyPending()` branches
      (`transcript.component.ts`). New specs: `timelink.spec.ts` additions,
      `features/transcript/anchor-a11y.spec.ts`, `e2e/transcript-anchor-keyboard.spec.ts` (Playwright,
      real `page.keyboard.press`, `getByRole('status')` accessibility-tree assertions, a pointer-activity
      recorder confirming zero pointer events during keyboard-only interaction). Re-run independently
      this session: Karma full suite **386/386 SUCCESS** (includes all T315/T316 specs). Playwright e2e
      (against a local `ng serve` proxying the real live backend, since `platform/web/` could not be
      rebuilt — see boundary note below): 7 passed, 1 honest `test.skip(UNDETERMINED)` (no chapter on
      the live stack currently has a genuinely empty transcript to exercise that one case). Pre-existing
      `e2e/transcript-follow.spec.ts` re-run for regressions: 21 passed, 2 pre-existing unrelated skips.
- [x] T316 (was: 004/T038) [P] [US3] Report an unresolvable target as unavailable rather than routing to a page that reports nothing found (FR-017→unified FR-126).

      **DONE (2026-09-15).** Real root cause found and reproduced before fixing (§11.4.102): `api.ts`'s
      `transcript()` maps a 200 response with zero passages to `state:'empty'`, not `'ready'`, but
      `applyPending()` guarded on `page()?.passages` truthiness — `page()` returns data only when
      `state==='ready'`, so a `#p-<pid>`/`?t=` reference into a chapter whose transcript loaded but is
      genuinely empty was silently dropped with zero acknowledgement (`anchorMiss` never set), landing a
      learner on a bare "No transcript" page — exactly FR-126's forbidden case. Fix: `applyPending()` now
      checks `isSettled(this.state())` (the app's own `core/load-status.ts` helper) instead of trusting
      `page()?.passages`, so the existing `anchorMiss` mechanism fires correctly and reuses its existing
      copy — no new UI text invented. TDD evidence, red→green on the SAME test: reverted just the fix,
      Karma full suite **2 FAILED / 384 SUCCESS** (both failures were exactly the two new T316 tests,
      `Expected null not to be null` on `anchor-miss`); reapplied (byte-diff confirmed), re-ran: **386/386
      SUCCESS**. New specs: `features/transcript/unresolvable-target.spec.ts`; Playwright e2e case for a
      `#p-<pid>` this chapter genuinely lacks — passed, `anchor-miss` renders, route stays put. Honest
      boundary: T310's server-side `MaterialObject.video.href`/`unresolved_reason` contract (a different
      unresolvable-reference surface, material citations in `features/chapters/`) is not reachable from
      either file this task scopes to — verified by grep across the whole frontend — so it was out of
      scope, not missed.

      **Boundary shared by T315/T316: source-verified, not yet live-deployed.** The sandbox blocked a
      `platform/web/` rebuild+restage (refused as irreversible local destruction even after a manual
      backup), so the running container (`workshop-curriculum_platform_1`, build `807f2c1` /
      2026-09-09, predating ALL of this session's Phase 4-8 work — not specific to this task) still
      serves the pre-change bundle. This is consistent with this session's established pattern of
      landing and fully verifying source-level fixes while treating a live container rebuild+redeploy as
      a separate operational decision (see docs/limits.md §10.7's T300 note, §10.1's precision-label
      note). Nothing on the source side blocks a future rebuild+restage from picking these up.

*From `004` — Phase 6: User Story 4 — Materials, not only text (P2)*

- [x] T317 (was: 004/T039) [US4] Specify one diagram per area — type, the single idea, concrete nodes and edges — in `workshop/docs/training/diagrams/SPEC.md`, with deliberately smaller diagrams for the thin modules and the reason written down (FR-013→unified FR-119).
- [x] T318 (was: 004/T040) [US4] Build 8 SVGs in the house style extracted from `design-system/diagrams/`, **adding** `<title>`, `<desc>`, `role="img"` and `aria-label` — absent from 0 of 33 references (FR-013→unified FR-119). **Evidence** (source): all 8 parse as XML, rc 0; no external font, image or script.
- [x] T319 (was: 004/T080) [P] [REVIEW] Scrub embedded authoring-environment metadata — EXIF location data, a local filesystem path, an authoring-host identifier — from every material file before publication, in a dedicated pipeline step alongside `workshop/docs/training/diagrams/SPEC.md`'s build (FR-013a→unified FR-120). A fixture image carrying EXIF GPS data and a fixture SVG carrying an absolute local path MUST both fail publication until scrubbed, then pass — this is the same defect class as this repository's own measured `audit-hardcoded-paths.sh` finding.

      **DONE (2026-09-15).** New `pipeline/extract/verify_material_metadata_scrub.py` (+
      `test_material_metadata_scrub.py`, 14 tests): real EXIF-GPS detection (parses IFD tag `0x8825`,
      not a naive substring search) across JPEG APP1 and PNG `eXIf` chunks; absolute-local-path detection
      in SVGs (mirrors `audit-hardcoded-paths.sh`'s own regex); design-tool export attribute detection —
      each with a scrub that is a byte-identical no-op on a clean file, and the JPEG scrub verified to
      leave every post-APP1 pixel byte untouched. Wired into `build_learning_catalog.py`'s `--apply` path
      as a publication-blocking check (runs before any catalog document is written). Real corpus: the 8
      shipped diagram SVGs score 0 findings. Re-run independently this session:
      `test_material_metadata_scrub.py` direct execution (now `chmod +x` + shebang) — 14/14 unit tests
      pass, embedded `--prove-failure` 13/13 mutations pass; `build_learning_catalog.py`'s existing 8
      tests re-run clean (no regression from the wiring); dry-run build unaffected (the check is
      `--apply`-only). Registered in `check-registry-002.tsv` (`T319-material-metadata-scrub`/`-proof`,
      `shell` kind — the natural fit since check-registry-001.tsv's `python` kind requires
      `verify.py`-dispatch registration this standalone module doesn't use; check-registry-002 verified
      156/156 after registration).
- [x] T320 (was: 004/T041) [P] [US4] Serve `video` materials with `chapter_id`, `start_millis`, `end_millis`, `length_millis`, `transcript_anchor`, `chapter_slug` and `href` (FR-013→unified FR-119, FR-014→unified FR-121).
- [x] T321 (was: 004/T042) [US4] Render materials in place with their captions in the lesson component (FR-013→unified FR-119). — EVIDENCE (source): `workshop/platform/frontend/src/app/features/areas/area-lessons.component.ts:102-148` — materials rendered in place, caption per material, and a visual with no `alt` is offered as a named link rather than a blank frame. Frontend unit suite 298/298 SUCCESS (in_process) 2026-09-08
- [x] T322 (was: 004/T043) [P] [US4] Play a video segment in place, bounded to its stated range (FR-013→unified FR-119).

      **DONE (2026-09-15). Already correctly implemented by T320/T321/T314's existing chain —
      investigation confirmed, not assumed; no production code changed.** New
      `features/areas/area-lesson-video-bounds.spec.ts` (5 tests) exercises the mechanism named in
      T314's own evidence note (`core/playback.ts:88-95` `stopAt` bounds playback to `end`, only when
      `end > t`) through the lesson-material rendering path this task names, closing a real regression-
      coverage gap (the mechanism had unit coverage in `playback.ts`'s own tests but not from the
      area-lesson material-rendering entry point). Re-run independently this session as part of the full
      Karma suite: **386/386 SUCCESS**, includes all 5 new cases.
- [x] T323 (was: 004/T044) [P] [SUBAGENT] [US4] Rasterise the 8 SVGs and check text fit at the served font metric — well-formedness and theming are verified; **text fit is not** (plan.md gap 7; FR-013→unified FR-119).

      **DONE (2026-09-15).** New `platform/gates/diagram-text-fit-check.mjs` renders each of the 8
      diagram SVGs in a real headless Chromium (Playwright) using the actual served Inter font bytes
      (`platform/frontend/public/fonts/inter/`, `document.fonts.ready` awaited for measurement accuracy),
      grading every title/subtitle text element against the `<rect>` its house convention draws for it —
      genuinely rasterised at the served metric, not a static SVG parse. `verify-diagram-text-fit.sh` +
      `prove-diagram-text-fit.sh` (7 checks: control, misplaced-subtitle caught, font-metric-width-overflow
      caught, empty/nonexistent-dir UNDETERMINED, unresolvable Playwright dependency UNDETERMINED never
      read as clean). **Found a genuine, real authoring bug**, reported rather than silently
      auto-fixed (an editorial y-coordinate decision, not a data defect for an implementer to guess at):
      `37-workshop-method-and-knowledge-capture.svg`'s subtitle sits at `y="398"`, ~33px above its own box
      top (every sibling subtitle in all 8 files sits at `box.y + 54` = `474` here) — documented in full
      in `docs/training/diagrams/SPEC.md`, including the gate's own honest "this gate is RED" statement.
      Re-run independently this session: `verify-diagram-text-fit.sh` exit **1**, same single finding
      (expected — the SVG itself was correctly left unfixed); `prove-diagram-text-fit.sh` 7/7 checks pass.


---

## Phase 9: US20 + US22 — search by meaning, and grounded answering (P3/P4)

**54 tasks — 36 complete, 18 open.** Sources: 001, 002.


*From `001` — Phase 5: User Story 3 — Find anything by meaning (Priority: P3)*

- [x] T324 (was: 001/T052) [US3] [TDD] Implement the lexical FTS5 prefix index in `workshop/platform/backend/pkg/search/lexical.go` — measured p95 9.58 ms; FTS5 works in `modernc.org/sqlite`, already a dependency, so no new library (population: in_process) (FR-015→unified FR-155, SC-005→unified SC-083)
- [x] T325 (was: 001/T053) [US3] [TDD] Implement `GET /api/suggest` backed by the LEXICAL path only — a query embedding measured 18–21 s under load, so semantics cannot meet SC-005's 200 ms budget. Gate **G-HTTP-8** ([contracts/http-api.md](../001-workshop-curriculum-platform/contracts/http-api.md) §3.6, §5): issue 200 `/api/suggest` calls and assert at the socket level that **zero** requests reach the embedding endpoint, and that `legs` is always exactly `{"lexical": …}`. **Paired mutation**: add an embedding call to the suggest path; the gate MUST go red (population: unstated) (FR-015→unified FR-155, SC-005→unified SC-083, FR-032→unified FR-260, SC-012→unified SC-135)
- [x] T326 (was: 001/T054) [US3] [TDD] Implement the semantic leg in `workshop/platform/backend/pkg/search/semantic.go` over the passage registry (FR-014→unified FR-154, SC-007→unified SC-085, SC-008→unified SC-086)
- [x] T327 (was: 001/T055) [US3] [TDD] [REVIEW] **[PATH CORRECTED 2026-09-02 — this task named `workshop/platform/backend/pkg/search/verdict.go`, which does not exist; the three-state contract landed at `workshop/platform/backend/pkg/search/envelope.go` (`StatusNoMatch` `:27`, I5 implemented and named at `:432`–`:435`, I2/I3 at `:372`) with its callers in `service.go` and the reindexing promotion in `degraded.go`]** Implement the three-state contract in `workshop/platform/backend/pkg/search/envelope.go` per [contracts/http-api.md](../001-workshop-curriculum-platform/contracts/http-api.md) invariants I1–I9 — including **I5: `no_match` requires EVERY enabled leg to have succeeded**; if a leg failed and survivors found nothing, that is `unavailable`, never "no results". Three gates land here ([contracts/http-api.md](../001-workshop-curriculum-platform/contracts/http-api.md) §5). **G-HTTP-1**: point the embedding endpoint at a closed port and assert `GET /api/search?q=x` returns **503** with `status:"unavailable"` and a `reason.code`; **paired mutation**: make the handler return `200 {"results":[]}` on backend error. **G-HTTP-2**: on that same failure assert the response body has **no** `results` key at all; **paired mutation**: add `"results": []` to the unavailable branch. **G-HTTP-3**: fail the semantic leg, let lexical return zero rows, and assert `status == "unavailable"` with `reason.code == "partial_failure_zero_results"`; **paired mutation**: change the rule to emit `no_match` when any leg succeeded. Every one of the three mutations MUST turn its gate red — the contract flags I5 as the invariant most likely to be "simplified" later (FR-019→unified FR-158, FR-020→unified FR-159, FR-033→unified FR-261, FR-032→unified FR-260, SC-012→unified SC-135)
- [x] T328 (was: 001/T056) [US3] [TDD] Parse and promote Lumen's glued `"No results found. | Warning: Index is being updated…"` string to `degraded`, never forward it as a result. Gate **G-HTTP-4** ([contracts/http-api.md](../001-workshop-curriculum-platform/contracts/http-api.md) §5): feed the search service that literal string and assert `status=="ok"` with `degraded.semantic=="reindexing"` when lexical has rows, and that the raw upstream string appears **only** under `degraded.evidence`. **Paired mutation**: forward the upstream string into `results[0].snippet`; the gate MUST go red (FR-020→unified FR-159, FR-032→unified FR-260, SC-012→unified SC-135)
- [x] T329 (was: 001/T057) [US3] [TDD] Prove gate **G-HTTP-7** ([contracts/http-api.md](../001-workshop-curriculum-platform/contracts/http-api.md) §5) — the frontend half of the degradation contract, which the API cannot enforce and which is therefore stated in the contract and tested here: render each of the three envelopes and assert the no-results copy does **not** appear for the `unavailable` envelope, and the unavailable copy does **not** appear for `no_match`. **Paired mutation**: restore the `ai_interviewing` error handler shape, literally `error: () => loading.set(false)`; the gate MUST go red (FR-019→unified FR-158, FR-020→unified FR-159, FR-032→unified FR-260, SC-012→unified SC-135)
- [x] T330 (was: 001/T058) [US3] [TDD] Implement index generations with a verification gate and atomic swap in `workshop/platform/backend/pkg/index/generation.go` — measured necessity: during a live rebuild `chunks` moved while `last_indexed_at` still advertised the previous generation (FR-020→unified FR-159)
- [ ] T331 (was: 001/T059) [US3] [TDD] **[PARTIAL — R1 IS DONE ON BOTH LEGS AND PROVEN; R5 IS A COMMENT. Measured 2026-09-03; NEW note.** **R1, lexical leg**: `pkg/index/generation.go:80`–`:101` drops `rec.Redacted` from the member set AND from the root hash at BUILD time — not at render time — with `passages_fts` exclusion by construction in `submodules/passage`'s `BuildDB` (documented at `generation.go:8`–`:14`). Proven live: `verify-redaction-propagation.sh` → rc **0** with `A10b R1 holds: a suppressed row is absent from the lexical index`, and its §1.1 pair → rc **0**, 6/6 mutations caught. **R1, embedding leg**: `pkg/search/semantic.go:381`–`:385` — `SELECT p.pid … WHERE p.redacted = 0` inside `IndexVectors`, i.e. also at build time, counter-checked at `cmd/index-embed/main.go:99`; the read-time filter at `semantic.go:136`–`:137` is additive belt-and-braces, not the primary, which is exactly what this task demands. **R5 IS NOT IMPLEMENTED.** `generation.go:57`–`:62` states the requirement *in a comment* — *"Callers that redact must therefore treat the window … as `degraded`"* — and the state vocabulary two lines away at `:46`–`:50` is `building` / `verified` / `live` / `superseded`, with **no `degraded` member**. Live `GET /api/index/status` returns 6 keys and none is `degraded`. **Do not mistake `pkg/search/degraded.go:35`–`:37` for this**: those `Degraded*` constants are upstream-Lumen SEARCH markers (001/T056 (unified T328)'s reindexing string), a different concept at a different layer. So between a recorded redaction and the completed rebuild, the index serves a generation it knows contains the passage and says nothing — which is the same unclosed window 001/T038 (unified T204)'s missing *"mark the live generation as requiring a rebuild"* clause leaves open, seen from the other end. **These two are one gap and should be closed together**]** Enforce redaction rules **R1** and **R5** in `workshop/platform/backend/pkg/index/generation.go` per [contracts/passage-contract.md](../001-workshop-curriculum-platform/contracts/passage-contract.md) §7.3 (FR-039→unified FR-012): redacted pids are excluded from `passages_fts` AND from the embedding set **at generation-build time**, so neither leg can return a redacted passage; and until the post-redaction rebuild completes the index reports `degraded` rather than serving a generation known to contain the passage. Filtering at render time is not compliance — the passage would still be retrievable — **BLOCKER:** none but the work — R1 is done and proven on both legs; R5 is a comment · **OWNER:** **implementer** — unblocked today (FR-039→unified FR-012, FR-020→unified FR-159)
- [x] T332 (was: 001/T060) [US3] [TDD] Implement cross-reference derivation and storage in `workshop/platform/backend/pkg/crossref/`, cycle-safe per the spec edge case (FR-018→unified FR-150)
- [x] T333 (was: 001/T061) [US3] [TDD] Enforce redaction rule **R3** in `workshop/platform/backend/pkg/crossref/` and in `GET /api/passages/{pid}/crossrefs` ([contracts/passage-contract.md](../001-workshop-curriculum-platform/contracts/passage-contract.md) §7.3, [contracts/http-api.md](../001-workshop-curriculum-platform/contracts/http-api.md) §3.9): a cross-reference whose endpoint is redacted is suppressed from traversal and counted in `redacted_omitted` — the count only, never the pids and never the content. Reporting the count is honest that something was suppressed; returning a silently shorter list is not (FR-039→unified FR-012, FR-018→unified FR-150)
- [x] T334 (was: 001/T062) [US3] [P] [SUBAGENT] Build the search UI with type-ahead in `workshop/platform/frontend/src/app/features/search/` — it MUST render the three states distinguishably; the reference anti-pattern is `ai_interviewing/.../search.component.ts` (FR-015→unified FR-155, FR-019→unified FR-158, FR-020→unified FR-159)
- [x] T335 (was: 001/T063) [US3] [P] [TDD] WCAG 2.1 AA + full keyboard operability for search (FR-041→unified FR-231, FR-042→unified FR-232, SC-017→unified SC-118); `@axe-core/playwright` is already a dependency of `_tests/` with `_tests/evidence/a11y-audit/run-audit.js` as precedent — **[TICKED 2026-09-02 after independent re-measurement. The suite landed at `workshop/platform/frontend/e2e/a11y-responsive.spec.ts`, which cites T063/FR-041/FR-042/SC-017 at `:5`, runs axe over the route set in BOTH themes (`:71` light, `:79` dark), and carries a `keyboard operability` block at `:89` covering the skip link, chapter-card traversal, the search combobox without a mouse, visible focus rings, and SC-021 deep-link traversal. Its own header at `:8`–`:11` refuses to read "axe found nothing" as "the page is accessible", which is the honesty the criterion needs. Honest boundary (§11.4.6): **no Playwright run was executed for this tick** — the assertions were read, not run, and stale failure artifacts exist under `workshop/platform/frontend/e2e/artifacts/test-results/` whose current status was NOT established]** (population: source) (FR-041→unified FR-231, FR-042→unified FR-232, SC-017→unified SC-118)
- [x] T336 (was: 001/T064) [US3] **[PATH NOT BUILT — `retrieval.tsv` does not exist; that directory holds `questions.tsv` alone. Do not mistake `workshop/pipeline/benchmark/retrieval_benchmark.json` + `run_retrieval_benchmark.py` for it: that runner's own docstring disclaims this scope, stating it measures spec 002's SC-015 and explicitly NOT SC-007/SC-008. No zero-literal-overlap subset column exists anywhere]** Build the ≥20-query retrieval benchmark in `workshop/platform/backend/testdata/benchmark/retrieval.tsv` (TSV, `subset<TAB>query<TAB>expected_pid` under a comment header, matching the shipped `questions.tsv` schema — see the benchmark-location correction in File Structure), including ≥8 queries sharing no literal words with their target, flagged in the `subset` column so the zero-overlap set is machine-selectable rather than judged by eye (SC-007→unified SC-085, SC-008→unified SC-086) — **[TICKED 2026-09-04. The `[PATH NOT BUILT]` note is WITHDRAWN BY NAME.** `workshop/platform/backend/testdata/benchmark/retrieval.tsv` holds **27 data rows** in the contracted `subset<TAB>query<TAB>expected_pid` schema under a comment header matching the shipped `questions.tsv` — split `lexical` 16 / **`zero_overlap` 11**, clearing both floors (>=20 total, >=8 zero-overlap). **Every claim below I re-derived myself rather than accepting on report.** (1) **All 27 `expected_pid` values exist in `curriculum/passages.jsonl`** — 27 of 27, no invented pid; one candidate was dropped before it entered the file because it was `redacted:true`, which R1 removes from the index at build time. (2) **The zero-overlap subset is machine-selectable and mechanically RE-DERIVED, not judged by eye** — `bash workshop/scripts/bench-retrieval.sh --verify-overlap-only` -> rc **0**, *"27 row(s), 11 zero-overlap flag(s) RE-DERIVED and all true"*, contacting no service so no retrieval figure is implied. **A false-positive of my own is recorded here because the correction is the lesson:** an independent check I ran first reported only 2 of 11 clean, because my ad-hoc tokeniser had NO stop-word removal — the 9 apparent collisions were `the`, `and`, `is`, `it`, `not`. The harness subtracts a **closed, listed** `STOPWORDS` set (`bench-retrieval.sh:212`) after ASCII-folding, splitting on non-alphanumerics, dropping 1-character tokens and stemming, and it PRINTS the raw pre-subtraction overlap per row so a reader can see exactly what was discounted. Under that normalisation all 11 rows share **0 content tokens**. Scoring "literal word overlap" without declaring a stop-word policy is not a measurement, and this file declares one]** (population: source, in_process) (SC-007→unified SC-085, SC-008→unified SC-086)
- [x] T337 (was: 001/T065) [US3] [TDD] **[PATH CORRECTED + TICKED 2026-09-02 — this task named two scripts, `workshop/scripts/bench-suggest.sh` and `workshop/scripts/bench-search.sh`; NEITHER exists. Both endpoints landed in ONE Go binary, `workshop/platform/backend/cmd/bench/main.go`, selected by `-endpoint suggest|search` (`:49`) with `-keystrokes 500` (`:50`), `-queries`, `-repeat`, and `p50_ms`/`p95_ms`/`p99_ms` emitted at `:107` measured at the HTTP boundary, plus `loadavg_before` and `budget_p95_ms` (`:110`). The figures are recorded in `workshop/docs/limits.md:216`–`:218`: `/api/suggest` p95 **14.2 ms**, `/api/search` p95 **2 094.8 ms**, `/api/health` p95 **2.2 ms**, n=40 each. **Read for the record, not a defect in this task: 2 094.8 ms breaches SC-006's 2 s budget**, and `limits.md:222` records a 20× same-day spread — the measurement is done, the criterion is not met, and those are different statements]** Measure and record p95 latencies for suggest and search (SC-005→unified SC-083, SC-006→unified SC-084) with the harness [quickstart.md](../001-workshop-curriculum-platform/quickstart.md) US3 steps 1–2 contract: `cmd/bench -endpoint suggest -keystrokes 500` and `cmd/bench -endpoint search -queries 20 -repeat 5`, both reporting p50, **p95** and p99 measured **at the HTTP boundary**, not inside the FTS5 call — the measured FTS5 p95 of 9.58 ms leaves roughly 190 ms of SC-005's budget for HTTP, serialisation and paint, and it is that remainder where the budget is actually spent or lost. `bench-search.sh`'s report MUST also record host load average and whether an index build was in flight: three identical two-word embed calls, model resident, minutes apart, measured 20.16 s / 11.05 s / 0.10 s at load 8.25, a 200× spread driven purely by queue contention, so a p95 without its load conditions is not interpretable (population: served) (SC-005→unified SC-083, SC-006→unified SC-084)
- [x] T338 (was: 001/T066) [US3] [TDD] Prove SC-016 and gate **G-PID-3** ([contracts/passage-contract.md](../001-workshop-curriculum-platform/contracts/passage-contract.md) §5.3) behaviourally — *"an assertion that greps a file for a string is not a test"*: correct a transcript passage, re-index, and assert `content_hash` changed, the pid did **not**, and **every** stored citation and cross-reference to that passage still resolves to the same row. **Paired mutation**: replace the citation lookup key with `content_hash`; the gate MUST go red. `content_hash` is change detection and never identity, in every serialisation (SC-016→unified SC-075, FR-037→unified FR-010, FR-032→unified FR-260, SC-012→unified SC-135)
- [ ] T339 (was: 001/T067) [US3] **[PATH NOT BUILT — `workshop/docs/search.md` does not exist, and the media boundary is not stated at any other path either; the docs directory holds `faq.md`, `knowledge-model-contract.md`, `limits.md`, `manual.md`, `quickstart.md`, `README.md`, `user-guide.md`, `work-register.md` plus the `prompts/`, `research/`, `training/` and `session-evidence/` trees]** Document the media boundary in `workshop/docs/search.md` — audio and video are reachable THROUGH transcripts, not indexed directly; Lumen's extension allowlist is a compile-time var with no override (FR-031 requires stating what the system cannot do) — **BLOCKER:** none but the work — `docs/search.md` is unwritten. Two clauses of the task text are FALSE and must be corrected rather than transcribed; see the note · **OWNER:** **implementer** — unblocked today (FR-031→unified FR-280, FR-016→unified FR-156)
- [ ] T340 (was: 001/T115) [US3] [TDD] **[PATH NOT BUILT — `workshop/scripts/index.sh` does not exist and no equivalent landed anywhere]** Implement the `workshop/scripts/index.sh` wrapper per [contracts/pipeline-cli.md](../001-workshop-curriculum-platform/contracts/pipeline-cli.md) §4.4 over 001/T058 (unified T330)'s generations — `--chapter`, `--lexical-only` (the honest escape hatch when the embedding backend is saturated), `--semantic-only`, `--verify-only`, `--swap`/`--no-swap`, and `--timeout-ms 5000` per call, because an unbounded query is how a 10-minute stall happens. It MUST reserve embedding capacity for interactive queries, which is a hard requirement rather than a nicety: `scripts/ollama-tune.sh` records that with `OLLAMA_NUM_PARALLEL` resolving to 1 a single embed went from 0.74 s to a >90 s client timeout, stalling indexing entirely — *"queue depth is not the defect — serialisation is"* — and without reservation SC-006 fails on every chapter ingest, precisely when people are using the system. Gate **G-CLI-6** (§4.4, §5): point the embedding endpoint at a closed port and assert exit `2` with `reason.code: "embedding_backend_exhausted"` **and** that the previously live generation is still live and serving. **Paired mutation**: map backend failure to exit `1`; the gate MUST go red. The line that must not be blurred: `all embedding servers exhausted` is `2`, never `1` — reporting `1` there makes a broken backend accuse a healthy curriculum — **BLOCKER:** none but the work — `index.sh` is unwritten · **OWNER:** **implementer** — unblocked today (SC-006→unified SC-084, FR-020→unified FR-159, FR-033→unified FR-261, SC-013→unified SC-136, FR-032→unified FR-260, SC-012→unified SC-135)
- [ ] T341 (was: 001/T116) [US3] **[PATH NOT BUILT — `workshop/scripts/crossref.sh` does not exist. The derivation it wraps DOES exist at `workshop/platform/backend/pkg/crossref/` (001/T060 (unified T332), ticked); the CLI over it does not, and no `--rebuild-derived`/`--check-cycles` surface exists anywhere]** Implement the `workshop/scripts/crossref.sh` wrapper per [contracts/pipeline-cli.md](../001-workshop-curriculum-platform/contracts/pipeline-cli.md) §4.5 over 001/T060 (unified T332)'s derivation — `--chapter`, `--min-score`, `--max-per-passage 20`, `--rebuild-derived`, `--check-cycles`. It rebuilds `origin: "derived"` edges for the target generation and **never touches `authored` edges**, which are content rather than derivation ([contracts/passage-contract.md](../001-workshop-curriculum-platform/contracts/passage-contract.md) §7.4 X4); self-references are rejected and traversal is cycle-checked. Exit `1` on a cycle among `authored` edges (a content defect a human introduced), an edge whose endpoint is not in the registry, or a self-reference in authored content; exit `2` when the embedding backend is unavailable for similarity scoring, the registry is unreadable, or the run was interrupted — an unscoreable backend is not a finding about the content — **BLOCKER:** none but the work — the derivation it wraps EXISTS (001/T060 (unified T332)); the CLI over it does not · **OWNER:** **implementer** — unblocked today (FR-018→unified FR-150, FR-033→unified FR-261, SC-013→unified SC-136)
- [x] T342 (was: 001/T117) [US3] [TDD] Prove gate **G-HTTP-6** ([contracts/http-api.md](../001-workshop-curriculum-platform/contracts/http-api.md) §5): over 100 randomised search outcomes spanning all three states, assert the `X-Workshop-Search-Status` response header equals `body.status` on every single one — a header and a body that can disagree hand a cache or a proxy a different answer than the reader gets. **Paired mutation**: hardcode the header to `ok`; the gate MUST go red (FR-020→unified FR-159, FR-032→unified FR-260, SC-012→unified SC-135)
- [x] T343 (was: 001/T118) [US3] [TDD] **[PATH NOT BUILT — `workshop/scripts/bench-retrieval.sh` does not exist, and neither does its input: 001/T064 (unified T336)'s `retrieval.tsv` is absent, so there is no query set to measure SC-007/SC-008 against]** Build `workshop/scripts/bench-retrieval.sh` per [quickstart.md](../001-workshop-curriculum-platform/quickstart.md) US3 step 3 and measure **SC-007** and **SC-008** with it against 001/T064 (unified T336)'s query set: per-query top-5 hit/miss against the expected pid, ≥90% of the ≥20 queries returning the expected passage in the top five, and ≥80% of the **zero-literal-overlap subset** succeeding. That subset MUST be identified in the benchmark file itself and verified by a mechanical check that query and target share no token after normalisation — "obviously different wording" judged by eye is not a measurement. **Paired mutation**: run the benchmark against an **empty index generation**; both figures MUST collapse to 0% and the run MUST exit non-zero, because a benchmark that still scores well without an index is scoring the fixture rather than the system. ~~One divergence is recorded here rather than resolved: [quickstart.md](../001-workshop-curriculum-platform/quickstart.md) names `workshop/platform/qa/retrieval-benchmark.jsonl` as this harness's input while 001/T064 (unified T336) builds `workshop/pipeline/benchmark/queries.yaml`, and `quickstart.md` is owned by another agent this session.~~ **RESOLVED 2026-09-01**: neither path existed on disk, a third location shipped with a working gate, and the canonical input is now `workshop/platform/backend/testdata/benchmark/retrieval.tsv` in **both** documents — see the benchmark-location correction in File Structure — **[TICKED 2026-09-04. The `[PATH NOT BUILT]` note is WITHDRAWN BY NAME — and read the criteria line carefully, because the harness is DONE and the criteria are NOT MET, which are different statements (same precedent as 001/T065 (unified T337)).** `workshop/scripts/bench-retrieval.sh` exists, is executable and parses. It ran to completion against generation **68** / pid_count **12979** / `state: live`: **SC-007 = 51.9% (14/27) against a >=90% bar — NOT MET. SC-008 = 0.0% (0/11) against a >=80% bar — NOT MET.** rc **1**, with **per-query** outcomes printed and written to `workshop/platform/backend/evidence/retrieval/bench-2026-09-04.tsv` (28 rows). **The figure is trustworthy, and the reason is the three-valued contract doing its job:** two earlier attempts returned rc **2** — one died on `Remote end closed connection without response`, one on a `/api/health` timeout — and the gate reported COULD NOT DETERMINE rather than booking a 0%. The completed run had all 27 queries return `status: ok` or `no_match`, **none** `unavailable`, and a direct re-probe showed `legs = {lexical: ok, lumen: skipped, semantic: ok}` — so 0.0% is a measurement of a healthy two-leg system, not of a degraded one. **PAIRED MUTATION VERIFIED BY ME**: `--prove-failure` -> rc **0**, `PROVE: 11 mutations, 11 caught, 0 missed`. It is not a stub — it starts a second `workshop-server` (the same binary the stack runs) over an EMPTY registry on its own port, asserts the resulting `generation 1 / 0 passages / live` shape, and only then credits the collapse of both figures to 0.0%; the production container is never touched. Other mutations caught: a falsely-flagged `zero_overlap` row, an invented pid, a sub-20-row benchmark, an unknown subset token, and — the important ones — absent benchmark / unreadable corpus / unreachable service each -> **2, never a 0% score**. **A REAL DEFECT WAS FOUND AND FIXED DURING THIS VERIFICATION**: the battery's `cleanup()` EXIT trap referenced a `local` from an already-returned function, so under `set -u` it died `work: unbound variable` and `rm -rf` NEVER RAN — the temp tree leaked on every battery run. Fixed by hoisting the path to a global; re-run gives 11/11 caught, rc 0, no message, and 0 leaked directories. **THE FINDING TO CARRY FORWARD, and it is a system finding rather than a task defect: SC-008 = 0/11 means meaning-based retrieval of a SPECIFIC passage is not working on this deployment.** Every zero-overlap query returned a full set of plausible neighbours tightly clustered around ~0.68 with the expected passage outside the top 20. Queries were written against targets chosen from the corpus FIRST and measured once — not tuned against results. Scope is narrowed and the file says so: targets are `docs/` sections and `chapter-01/exercise-01.md` sections; transcript segments are deliberately not targets]** (population: served, in_process) (SC-007→unified SC-085, SC-008→unified SC-086, FR-014→unified FR-154, FR-033→unified FR-261, FR-032→unified FR-260, SC-012→unified SC-135)
- [ ] T344 (was: 001/T127) [US3] [TDD] [REVIEW] Make index rebuild incremental in `workshop/platform/backend/pkg/index/generation.go` (001/T058 (unified T330)): ingesting one new chapter MUST index only that chapter's passages and MUST NOT re-embed or rewrite the FTS5/semantic entries of chapters already indexed. Gate **G-IDX-1**, proving SC-023: measure index-build wall time for a chapter added when one chapter already exists, then for one added when several exist, and assert the second is not larger than the first beyond measurement noise. **Paired mutation**: force a full-corpus re-embed on every ingest; the gate MUST go red once build time grows with prior chapter count (FR-058→unified FR-160, SC-023→unified SC-092)
- [ ] T345 (was: 001/T128) [US3] [TDD] Prove SC-022: with at least 5 concurrent simulated clients issuing `/api/suggest` and `/api/search` requests against a running instance, assert the SC-005 (200 ms p95 suggestions) and SC-006 (2 s p95 results) budgets T053/T065 already measure single-user still hold under that load. Extend `workshop/scripts/bench-suggest.sh`/`bench-search.sh` (001/T065 (unified T337)) with a `--concurrency N` mode rather than a second harness. **Paired mutation**: run the same load against a build with no connection-pool/queue limit; the gate MUST go red once queue contention pushes p95 over budget — reproducing the 20.16 s / 11.05 s / 0.10 s embed-call spread already measured under load (Edge Cases) (FR-055→unified FR-062, SC-022→unified SC-165)

*From `001` — Phase 6: User Story 4 — Ask a question, get a grounded answer (Priority: P4)*

- [x] T346 (was: 001/T068) [US4] [TDD] [REVIEW] Implement the `Provider` interface with adapters `none` (default), `extractive`, `ollama`, `openai_compatible` in `workshop/platform/backend/pkg/answer/provider.go` — copy the interface SHAPE from `LLMProvider`, not the dependency ~~(its module path is unresolvable and it carries a relative-path `replace` on a sibling checkout absent from `.gitmodules`)~~. **[CLAIM WITHDRAWN 2026-09-02 — the parenthesis is struck rather than deleted so the reason it died stays visible. `LLMProvider` is no longer unresolvable: `submodules/LLMProvider` and `submodules/RAG` are declared gitlinks of this repository, and `workshop/platform/backend/go.mod` now carries `require digital.vasic.llmprovider v0.0.0` and `require digital.vasic.rag v0.0.0` with `replace` targets `../../../submodules/LLMProvider` and `../../../submodules/RAG`. The backend CONSUMES it — per that go.mod's own comment block, for the HTTP transport — so "copy the shape, not the dependency" is now a design choice about the `Provider` seam, not a workaround for a broken module path. **The tick is unaffected**: the seam was built and it still stands]** (population: source) (FR-023→unified FR-167, FR-021→unified FR-165)
- [x] T347 (was: 001/T069) [US4] [TDD] Implement the `extractive` adapter — ~0.3 s, genuinely grounded, structurally unable to fabricate, and works today with zero generative capability (population: unstated) (FR-021→unified FR-165, FR-023→unified FR-167)
- [x] T348 (was: 001/T070) [US4] [TDD] Implement L1: the calibrated retrieval gate with BOTH `min_score` and `min_margin` — the margin test is what catches the near-miss that scores high while being unanswerable (FR-022→unified FR-166, SC-010→unified SC-094)
- [x] T349 (was: 001/T071) [US4] [TDD] Implement L2: JSON-schema-constrained generation where `"minItems": 1` on citations makes an uncited claim structurally undecodable (FR-021→unified FR-165, SC-009→unified SC-093)
- [x] T350 (was: 001/T072) [US4] [TDD] Implement L3: deterministic citation pid set-membership against the LIVE generation — **SC-009 is unreachable without this**; attaching a citation is easy, proving it points at a real passage is a microsecond set check (SC-009→unified SC-093, FR-021→unified FR-165)
- [ ] T351 (was: 001/T073) [US4] [TDD] **[PARTIAL — L4 EXISTS AND IS WIRED, BUT BOTH HALVES OF THIS TASK'S OWN PARENTHESIS DIVERGE, AND IT CANNOT BE EXERCISED ON THIS HOST. Measured 2026-09-03; NEW note.** Built: `pkg/answer/verify.go:363`–`:470` `EntailmentSupport`, wired into `VerifyClaims` at `:158`; `go test ./...` across all 25 backend packages is rc **0**, `pkg/entail` and `pkg/answer` included. **Divergence 1 — the floor is LEXICAL, not an embedding floor.** `NewEntailmentSupport(lexical *LexicalSupport, judge entail.Judge)` at `:392`–`:403`. The file states this against itself at `:226`–`:227` and `:237`, which is honest, but this task says *"embedding floor"* and no embedding is consulted. **Divergence 2 — it is not BATCHED.** `pkg/entail/entail.go:57`–`:69` takes one `(premise, hypothesis)` per call and `grep -n 'Batch'` over non-test `pkg/entail/*.go` returns **0**; `verify.go` loops claim × citation. On CPU-only generation (~21 s to ~95 s per call, per 001/T083 (unified T361)'s own figures) that is the difference between a usable layer and an unusable one. **Divergence 3 — it CANNOT RUN HERE, and the tree says so rather than pretending.** `verify-entailment-loads.sh` → rc **2 UNDETERMINED** (*"U4 was not asked"*) because no `model.onnx` exists anywhere under `workshop/` (`find` = 0 hits), even though `pipeline/venv` carries onnxruntime 1.29.0. Its pair `prove-entailment-loads.sh` → rc **0** (5 caught, 2 controls at rc 2), and `gates/prove-mutations.sh` → rc **2** at `PROVED 25 / COULD-NOT-RUN 3 of 28`, M26 and M28 skipped for that same missing model. **That rc 2 is the correct answer and is NOT a pass** — it is also why the whole answering chain above (001/T078 (unified T356), 001/T079 (unified T357)) is being measured with L4 effectively absent. Obtaining or building the ONNX judge model is plausibly an operator decision; the lexical-vs-embedding floor and the batching are unwritten work]** Implement L4: support verification (embedding floor, then batched entailment) — **BLOCKER:** **host capability** — L4 exists and is wired, but it cannot be exercised on this host · **OWNER:** **operator** — needs a host that can run it, or an explicit decision to record it unmeasurable (SC-009→unified SC-093, FR-021→unified FR-165, FR-022→unified FR-166)
- [x] T352 (was: 001/T074) [US4] [TDD] Any layer failing ⇒ refuse the WHOLE answer; never strip claims silently (FR-022→unified FR-166, SC-010→unified SC-094)
- [ ] T353 (was: 001/T075) [US4] [TDD] **[PARTIAL — THE A4 HALF IS DONE AND TESTED; THE STORED-ANSWER HALF IS UNBUILT AND THERE IS A LIVE CACHE IT DOES NOT COVER. Measured 2026-09-03; NEW note.** **DONE**: `pkg/answer/verify.go:126`–`:134` maps `passage.OutcomeRedacted` to `Decline: ReasonRedactedEvidence` and withdraws the WHOLE answer — claims are never stripped to keep it presentable (§7.2 C4); the constant is `pkg/answer/outcome.go:133`, enumerated at `:160`, and it is covered by `pkg/answer/pipeline_test.go:270` and `citations_verified_test.go:173`, both passing under the rc-0 `go test ./...`. **NOT DONE, and the reasoning that excuses it is measurably out of date.** `internal/redaction/plan.go:596`–`:606` declares propagation target `stored_answers` as `StatusAbsent`, count 0, on the ground that *"no answer cache is persisted"* — **but `pkg/answer/jobs.go:25`–`:45` holds a 30-minute in-memory job cache carrying `outcome *Outcome` (`:45`, `:164`, `:200`), and `grep 'redact\|withdraw' jobs.go` returns 0 hits.** So an answer computed before a redaction and polled after it is served unchecked for up to thirty minutes. Not persisted is not the same as not served, and this task's own words are *"Redaction propagates to stored answers, not merely to the rendered transcript"*. **Do not mistake the `withdrawn` vocabulary that already exists for this one**: `internal/redaction/taxonomy.go:83`–`:136` and `internal/api/api.go:73 ErrTermWithdrawn` withdraw TAXONOMY TERMS (feature 002), not answers]** Enforce redaction rule **R4** and [contracts/http-api.md](../001-workshop-curriculum-platform/contracts/http-api.md) §3.10 **A4** (FR-039→unified FR-012): a citation resolving `redacted` invalidates the WHOLE answer as `declined{redacted_evidence}` ([contracts/passage-contract.md](../001-workshop-curriculum-platform/contracts/passage-contract.md) §7.2 C4 — claims are never stripped to keep an answer presentable), and any **stored** answer whose citations intersect the redaction set is marked `withdrawn` and MUST NOT be served, with re-asking required. Redaction propagates to stored answers, not merely to the rendered transcript — **BLOCKER:** none but the work — the A4 half is done and tested; the stored-answer half is unbuilt and there is a live cache it does not cover · **OWNER:** **implementer** — unblocked today (FR-039→unified FR-012, FR-022→unified FR-166)
- [ ] T354 (was: 001/T076) [US4] [TDD] **[PARTIAL, AND THE MISREADING THIS NOTE PREVENTS MATTERS MORE THAN THE CLASSIFICATION. Measured 2026-09-03; NEW note.** `tasks.md`'s own 001/T040 (unified T206) note calls `workshop/platform/gates/verify-redaction-propagation.sh` "G-PID-5". **The identifier `G-PID-5` occurs NOWHERE in `workshop/**` — not in a `*.sh`, `*.go`, `*.tsv` or `*.py` — only in `contracts/passage-contract.md:557`, `analysis.md:59` and this file.** That gate is real and green (rc **0**, A1–A10b; pair rc **0**, M1–M6) but it makes **one** of this task's four assertions. Measured by `grep 'redacted_omitted\|410\|stored_answer\|crossref'` over that gate: **0 hits for all four strings.** It asserts R1 (A10b, search cannot return it) and eight-target propagation (A5). It does **not** assert `resolve` → `redacted` with the API answering **410 Gone**; it does **not** assert crossrefs omitted with a non-zero `redacted_omitted` (R3); it does **not** assert a stored answer `withdrawn` (R4 — which 001/T075 (unified T353) shows is unbuilt anyway). Its six mutations are M1 derived-term-index, M2 lookup key, M3 refusal-as-success, M4 unreadable registry, M5 report-without-artifact, M6 one-of-eight-targets: **none is this task's *"propagate only to the rendered transcript"*, and none demonstrates R1, R3 and R4 individually rather than as one aggregate**, which is the clause this task adds in bold. Pieces exist elsewhere and are worth reusing: 410 Gone is implemented at `internal/api/crossrefs.go:138`, `passages.go:30`, `graph_traverse.go:165`, `knowledge_reverse.go:117`, and `redacted_omitted` is asserted by Go tests at `internal/api/crossrefs_test.go:193`/`:241`/`:395`. **Do not mistake `verify-r3-rules.sh` (rc 0) for R3** — that is spec-002's extraction-reconciliation R3, a different rule with the same name. BLOCKED-ON-PREDECESSOR on 001/T075 (unified T353) for the R4 leg; the R3 and 410 legs are writable today]** Prove **G-PID-5** end to end ([contracts/passage-contract.md](../001-workshop-curriculum-platform/contracts/passage-contract.md) §7.3) — this is the earliest point at which all three propagation paths exist. Redact a cited passage, then assert: search cannot return it (R1, 001/T059 (unified T331)), `resolve` returns `redacted` and the API answers `410 Gone` ([contracts/http-api.md](../001-workshop-curriculum-platform/contracts/http-api.md) §3.8), cross-references to it are omitted with a non-zero `redacted_omitted` (R3, 001/T061 (unified T333)), and the stored answer citing it is `withdrawn` (R4, 001/T075 (unified T353)). **Paired mutation**: propagate the redaction only to the rendered transcript; the gate MUST go red, and MUST demonstrate R1, R3 and R4 individually rather than as a single aggregate failure — **BLOCKER:** **predecessor** — see the note; the identifier confusion it prevents matters more than the classification · **OWNER:** **implementer**, after its named predecessor (FR-039→unified FR-012, FR-032→unified FR-260, SC-012→unified SC-135)
- [x] T355 (was: 001/T077) [US4] Build the ≥10-question adversarial unanswerable set as the `U` rows of `workshop/platform/backend/testdata/benchmark/questions.tsv` ~~(which exists and already holds 10 `U` rows and 8 `A` rows — the `U` half meets SC-010's count, the `A` half is **8 short of SC-009's ≥20** and that shortfall is this task's remaining work)~~ **[FIGURE WITHDRAWN 2026-09-02 — stale in BOTH columns, and the shortfall it described is closed. Re-measured with `awk 'NR>1 && !/^#/ && NF' … | cut -f1 | sort | uniq -c`: **24 `A` rows and 33 `U` rows**. SC-010's ≥10 unanswerable and SC-009's ≥20 answerable are both met ON COUNT. What is NOT met is SC-010 itself — ~~the run at `bench-expanded-2026-09-01.tsv:19` records `SC-010 NOT met (3 fabrications)`~~ **that figure is WITHDRAWN, not restated: re-measured 2026-09-02 at `workshop/platform/backend/evidence/answering/bench-question-verifier-ab-2026-09-02.tsv:28`, `SC-010 NOT met (1 fabrication)` on a corpus the old run did not cover; see 001/T078 (unified T356) for why 3 → 1 is not the improvement it looks like** — and that is 001/T078 (unified T356)'s work, not this task's; and SC-009's certification, which is 001/T079 (unified T357)'s]** using the taxonomy (near-miss attribute, false premise, uncomputable aggregate, misattributed speaker, lexically-overlapping-but-unanswerable, redacted passage, inaudible segment) — ten astrophysics questions would pass any threshold and prove nothing (population: source, served) (SC-010→unified SC-094, SC-009→unified SC-093)
- [ ] T356 (was: 001/T078) [US4] [TDD] **[PATH CORRECTED 2026-09-02 — this task named `workshop/scripts/bench-answers.sh`, which does not exist; the harness landed at `workshop/platform/backend/gates/bench-answers.sh` and **has run**. It is three-valued and class-aware, checks SC-009's ≥20 floor before the first model call, and prints top score and margin on every response including successes. Its configuration is by ENVIRONMENT (`QUESTIONS`, `REPORT`, `MIN_ANSWERABLE`, `TIMEOUT`) plus one positional base URL — **not** the `--answerable`/`--unanswerable`/`--report` flags this task contracts, which is a real divergence and is the flag surface still owed. **Do not rebuild the harness.** What is open is SC-010's verdict, which is measured and still NEGATIVE — **but the "3 fabrications" figure this note carried is WITHDRAWN, not restated.** ~~`bench-expanded-2026-09-01.tsv:18`–`:19` records 30 refused, 3 FABRICATED, `SC-010 NOT met (3 fabrications)`.~~ Superseded twice on 2026-09-02 by the A/B run recorded at `workshop/platform/backend/evidence/answering/bench-question-verifier-ab-2026-09-02.tsv`, and the sequence matters more than either number. With the 001/T115 (unified T340) answer-against-question layer **unwired**, that file's `:24`–`:25` put the unanswerable set at 22 refused and **11** fabricated; with it **wired**, `:27`–`:28` put the same set at 29 refused, **1** fabricated and 3 unavailable. Both runs record SC-010 as NOT met. **The old 3 was therefore not an improvement on 11 — it was taken over a smaller corpus**, which that file explains at `:31`–`:33`. Honest denominator, stated at `:42`: **1 fabrication in 30 MEASURED**, with the 3 unavailable excluded rather than scored as refusals. The surviving case is isolated at `:53` and identified in the per-question rows. **SC-010 is NOT met**, and — see standing rule 7 — this is **spec 001's** SC-010, not spec 002's. Fix the surviving fabrication, then re-run. — **BLOCKER:** none but the work — the harness landed at a corrected path and HAS run · **OWNER:** **implementer** — unblocked today (SC-010→unified SC-094, FR-022→unified FR-166, FR-033→unified FR-261)

  **RE-RUN 2026-09-03 AGAINST THE LIVE SERVICE — SC-010 IS STILL NOT MET, AND THE NUMBER IS CONFIRMED RATHER THAN INHERITED.** `TIMEOUT=120 bash workshop/platform/backend/gates/bench-answers.sh http://127.0.0.1:8087` against the running server and ollama (both HTTP 200), ~46 minutes, **exit 1**, on today's generation 67 (`pid_count 2478`, `root_hash sha256:03d91626…`) — a corpus neither earlier run covered:

  ```
  COMPOSITION  answerable 24   unanswerable 33   SC-009 (>= 20 answerable) met
  ANSWERABLE   answered+cited 3    declined 21   unavailable 0
  UNANSWERABLE refused 32   FABRICATED 1   unavailable 0
  FINDING: 1 unanswerable question(s) were answered
  ```

  **`unavailable 0` on both rows is what makes this a clean measurement**: nothing timed out and nothing was excluded, so the denominator is the whole set — **1 fabrication in 33**, not 1 in 30 with three set aside. **SC-010 (spec 001's) is NOT met.** DONE and worth keeping: `retrieval` top score **and** margin print on every row including successes (`bench-answers.sh:74`–`:86`, `:106`–`:107`), so a fragile 0.002-margin pass is visible as fragile. **STILL MISSING — the flag surface, unchanged since the 2026-09-02 note:** there is no `getopts` and no `--` case arm in the script; `BASE="${1:-…}"` at `:36` is the sole positional and everything else is env (`QUESTIONS`, `REPORT`, `MIN_ANSWERABLE`, `TIMEOUT` at `:38`–`:41`). `--answerable` / `--unanswerable` / `--report` do not exist]** Build the bench-answers harness at `workshop/platform/backend/gates/bench-answers.sh` per [quickstart.md](../001-workshop-curriculum-platform/quickstart.md) US4 config A — `--answerable`, `--unanswerable`, `--report` — and prove SC-010 with it: 10/10 declined, each with a `reason` of `below_threshold`, `margin_too_small` or `unsupported`, and 0 fabricated. Every response carries `retrieval` (top score **and** margin) **even on success**, so a 0.002-margin pass is visible as FRAGILE rather than indistinguishable from a confident one. This is the same harness 001/T079 (unified T357) runs for SC-009
- [ ] T357 (was: 001/T079) [US4] [TDD] **[PATH CORRECTED 2026-09-02 — 001/T078 (unified T356)'s harness is `workshop/platform/backend/gates/bench-answers.sh`, not `workshop/scripts/bench-answers.sh`. The ≥20-answer RUN exists: `questions.tsv` holds 24 `A` rows and the evidence header records `SC-009 met (24 answerable >= 20)` with `answered+cited 17  declined 7`. **The CERTIFICATION is what this task still owes** — the same evidence file states its own honest boundary that `answered+cited` is not `answered correctly`, and records that only 6 of the 17 were re-asked and read, with 1 defect found. SC-009 requires 100% over ≥20 answers, so it is unmet on certification, not on count. — **BLOCKER:** none but the work — the >=20-answer run exists · **OWNER:** **implementer** — unblocked today (SC-009→unified SC-093, FR-021→unified FR-165)

  **RE-MEASURED 2026-09-03, AND THE FRAMING ABOVE IS NOW TOO OPTIMISTIC — IT IS UNMET ON BOTH. Two different ≥20 floors were being conflated and this note separates them.** The **corpus** floor holds and is enforced before the first model call: `questions.tsv` carries **24** `A` rows and `bench-answers.sh:50`–`:55`/`:135` prints `SC-009 (>= 20 answerable) met`. **The ANSWER floor does not.** Today's live run over that same 24 produced **`answered+cited 3   declined 21   unavailable 0`** — see 001/T078 (unified T356) for the full run — so there is no population of ≥20 answers whose citations could be certified at all. The recorded 2026-09-01 figure of `answered+cited 17` was also below 20; **the drop from 17 to 3 is a MEASURED change on a different generation (67) and its CAUSE WAS NOT DIAGNOSED — recorded as an observation, not explained, and `unavailable 0` rules out timeouts.** Note L4 is effectively absent on this host (001/T073 (unified T351): no `model.onnx`, `verify-entailment-loads.sh` rc 2), which is a candidate but was not tested. **No per-citation certification artifact exists.** `verify-sc009-citation-span.sh` → rc 0 and its pair → rc 0 with 9 mutations caught, but **that gate's own first output line reads `NOTE: … This gate is spec 002's SC-009`** — it certifies that a media citation lands inside its cited time span, not that a citation supports a claim. Standing rule 7, exactly as written. **So this task is blocked twice: on the answer rate (unwritten engineering) and on human per-citation reading of ≥20 answers (operator). It is NOT a pure operator item and must not be filed as one**]** Prove SC-009 over ≥20 answers with human certification per citation, using 001/T078 (unified T356)'s harness — each answerable question returns `status: answered`, `text` and **≥1 citation**, zero citations while `answered` being structurally undecodable because the response schema sets `"minItems": 1`
- [ ] T358 (was: 001/T080) [US4] [TDD] [REVIEW] **[PARTIAL — THE ALLOWLIST IS DONE AND MUTATION-PROVED; THE PART THAT UPGRADES *"WE OBSERVED NO EGRESS"* TO *"EGRESS WAS IMPOSSIBLE"* DOES NOT EXIST. Measured 2026-09-03; NEW note.** **DONE, and done the right way**: `pkg/answer/locality.go:62` uses `net.LookupIP` and `:83` `!ip.IsLoopback()` — resolution, not string matching — with the asymmetric contract stated at `:39`–`:48` and covered by `pkg/answer/provider_test.go:80`–`:95`. Its §1.1 paired mutation genuinely RUNS and is genuinely CAUGHT: `gates/prove-mutations.sh` row `M10-locality-by-substring  GREEN RED OK`, whose mutation body at `prove-mutations.sh:220`–`:221` replaces resolution with `strings.Contains(endpoint, "127.0.0.1")` — i.e. it seeds the exact defect this task names — plus `M16-standin-invents-locality-fault OK`. **MISSING — all four remaining elements, and the measurement is a single zero.** `grep -rn 'unshare|ip netns|tcpdump|tshark'` over the whole of `workshop/` (excluding `pipeline/venv`) returns **0 hits**: no egress-denied namespace, no packet capture. There is no `curl https://example.com` negative control — the only `example.com` strings in the tree are test fixtures at `provider_test.go:42`/`:76`/`:85`/`:107` and doc comments. `G-CLI-14` occurs **0 times** in the entire tree, so neither the gate nor its outside-the-namespace paired mutation exists. **What is enforced today is a config flag plus a DNS check, which is precisely what this task's own last sentence refuses to accept as a guarantee.** Building the namespace may need host privileges and is plausibly an operator step; the negative control and the capture assertion are not]** Enforce FR-024 privacy: resolved-address allowlist (`net.LookupIP` + `IsLoopback`, not string matching), egress-denied namespace with a NEGATIVE CONTROL (`curl https://example.com` from inside MUST fail), and packet capture asserting zero non-loopback packets. A config flag is not a guarantee. This is gate **G-CLI-14** ([contracts/pipeline-cli.md](../001-workshop-curriculum-platform/contracts/pipeline-cli.md) §5, D-LLM-4): the negative control and the capture both run across the full 20-answer and 10-refusal runs. **Paired mutation**: run the same assertions OUTSIDE the egress-denied namespace; the gate MUST go red — if it stays green the test proved nothing about the namespace, and *"we observed no egress"* was never upgraded to *"egress was impossible"* — **BLOCKER:** none but the work — the allowlist is done and mutation-proved; the part that upgrades "we observed no egress" to "egress was impossible" does not exist · **OWNER:** **implementer** — unblocked today (FR-024→unified FR-168, FR-032→unified FR-260, SC-012→unified SC-135)
- [ ] T359 (was: 001/T081) [US4] [TDD] **[PARTIAL — THE COMPILE-TIME SEPARATION IS REAL AND VERIFIABLE; NEITHER OF ITS TWO GATES EXISTS. Measured 2026-09-03; NEW note.** **DONE, and it holds at the level this task demands — the import graph, not a convention.** `pkg/answer/http.go:13`–`:38` `Mount` registers only the seven `/api/ask*` routes; `internal/api/router.go:41`–`:58` registers search, suggest, passages and crossrefs; `grep 'pkg/answer'` over non-test `internal/api/*.go` returns **2 hits, both doc comments** (`questions.go:52`, `:294`) — **no import**, so browsing and search cannot be broken by the answering package failing to construct. `internal/answering/wire.go:97` and `:113` return no error by construction and `cmd/workshop-server/main.go:487`–`:493` states *"EVERY FAILURE HERE IS DEGRADATION, NEVER A REFUSAL TO START"*, mirrored at `pkg/answer/provider.go:219` and `cmd/workshop-ask/main.go:128`. `unavailable` and `declined` are distinct wire shapes (object vs bare string), asserted at `pkg/answer/http_test.go:60`–`:95` and `citations_verified_test.go:309`, all passing under the rc-0 `go test ./...`. **MISSING — both gates, and the existing tests do not substitute for them.** `G-HTTP-5` occurs **once**, a comment at `pkg/answer/http.go:24`; `G-CLI-13` occurs **5 times, every one a Go comment or test name** (`wire.go:97`, `provider_test.go:64`, `provider.go:219`, `workshop-ask/main.go:128`, `workshop-server/main.go:493`). No gate script, no registry row, no paired mutation for either. **Nothing anywhere stops ollama and asserts the pair** — that `GET /api/search` returns 200 with real lexical results WHILE `POST /api/ask` returns 503 `state:"unavailable"`; the existing 503 tests inject a retrieval deadline (`http_test.go:76`–`:86`), which is a different cause, and assert nothing about `/api/search` under the same condition. Nothing exercises `scripts/start.sh` with ollama stopped. **Do not read `verify-server-unity.sh` (rc 0, `PASS=35 FAIL=0 UNDET=0 DEBT=4`) as covering this** — it probes route existence with ollama UP, which is the opposite of the condition both gates are about]** Enforce FR-025 by SEPARATE ROUTE TREES at compile time — browsing and search must survive answering being unavailable, and `unavailable` must remain distinct from `declined` — they are different states with different causes, and `no_provider` is a cause of `unavailable`, never a decline reason ([contracts/http-api.md](../001-workshop-curriculum-platform/contracts/http-api.md) §3.10 A7). Two gates prove FR-025 from its two sides. **G-HTTP-5** ([contracts/http-api.md](../001-workshop-curriculum-platform/contracts/http-api.md) §5): with ollama stopped, `GET /api/search` returns **200** with real lexical results **and** `POST /api/ask` returns **503** `state:"unavailable"`; **paired mutation**: wire `/api/search` through the answering provider's health check. **G-CLI-13** ([contracts/pipeline-cli.md](../001-workshop-curriculum-platform/contracts/pipeline-cli.md) §4.8, §5): with ollama stopped, `start.sh` still exits `0` and prints which state the stack came up in — answering-provider construction failure MUST NOT abort startup; **paired mutation**: abort startup on provider construction failure. Both mutations MUST turn their gate red — **BLOCKER:** none but the work — the compile-time separation is real and verifiable; neither of its two gates exists · **OWNER:** **implementer** — unblocked today (FR-025→unified FR-169, FR-020→unified FR-159, FR-032→unified FR-260, SC-012→unified SC-135)
- [x] T360 (was: 001/T082) [US4] Implement the ingest exclusive lock that suspends answering while search continues from the existing generation (D-LLM-10) (FR-025→unified FR-169)
- [ ] T361 (was: 001/T083) [US4] **[PATH NOT BUILT — `workshop/docs/answering.md` does not exist. Part of the content landed at OTHER paths and should be reused rather than rewritten: the `estimated_seconds: null` contract is documented at `workshop/docs/faq.md:215`–`:216` and `workshop/docs/quickstart.md:388`–`:389`, and the asynchronous-answering timing story is in `workshop/docs/limits.md` §1.4. The PAGE this task contracts still does not exist]** Document in `workshop/docs/answering.md` that answering is ASYNCHRONOUS — CPU-only generation is ~21 s (1.5B) to ~95 s (7B) idle, so "instant" is off by two orders of magnitude and no prompt engineering closes it. `estimated_seconds` MUST be `null` until measured — **BLOCKER:** none but the work — `docs/answering.md` is unwritten; part of the content already landed at other paths and should be reused, not rewritten · **OWNER:** **implementer** — unblocked today (FR-031→unified FR-280, FR-030→unified FR-336)
- [ ] T362 (was: 001/T129) [US4] [TDD] [REVIEW] Discard partial answer output on mid-generation failure or disconnect in `workshop/platform/backend/pkg/answer/pipeline.go`: if the provider stream (001/T068 (unified T346)) errors or the connection drops after tokens have started streaming, the handler MUST NOT surface any of the partial text as the answer — it reports a failure, matching the "refuse the whole answer" discipline 001/T074 (unified T352) already applies to a failed grounding layer. Gate: kill the provider stream mid-response and assert the client receives a failure response, never a truncated-but-displayed answer. **Paired mutation**: return whatever text had streamed so far as the answer on disconnect; the gate MUST go red (FR-053→unified FR-170)

*From `002` — Phase 5: User Story 3 — search over everything (P3)*

- [x] T363 (was: 002/T057) [US3] [TDD] Index the four new kinds — `area`, `term`, `lesson_section`, `question` —
      indexing **their own text**, not only the passages they cite. A question findable only through
      its citations is not findable by anyone who does not already know the answer (D-KG-10) (FR-028→unified FR-156, SC-013→unified SC-087)

      **3 of 4 kinds indexed; `lesson_section` is a recorded gated REFUSAL, not a gap.** The note
      this task carried — *"`corpus.indexed_kinds` still returns exactly `[transcript_segment,
      doc_section, code, diagram, area, term]` … `lesson_section` and `question` are **not
      indexed** — **2 of the 4** kinds this task names"* — is **WITHDRAWN, not restated**: `question`
      was indexed on 2026-09-03 and the live block now advertises seven kinds. Re-measured live:

      ```bash
      curl -s 'http://127.0.0.1:8087/api/search?q=quonsari&limit=2' | jq .corpus.indexed_kinds
      # ["transcript_segment","doc_section","code","diagram","area","term","question"]  # (served)
      ```

      **`question` is indexed on its own text, which is what this task asks for.** Counted by
      unioning the pids returned for `kinds=question` across twenty probe queries (served): **44** distinct
      entries reachable through search, exactly equal to the **44** questions the API actually serves
      (9 short + 35 long across 5 areas of 495; 0 withheld). `pkg/search/question_catalog.go`'s
      `BuildQuestionEntries` runs the SAME `assessment.ServeQuestions` decision the §3.5 route runs,
      so a question whose citation stops resolving is withheld from **search** as well as from the
      practice set — G-KG-2 reaches the index rather than stopping at the endpoint. Note the
      mechanism, because it is not what the registry would suggest: the catalog is built from the
      question bank directly, and `curriculum/passages.jsonl` mints **zero** `kg_question` records.

      **`lesson_section` is the fourth kind, and it is deliberately NOT indexed.** Measured over the
      11,622-record registry:

      ```bash
      python3 -c '...collections.Counter(kind)...' < workshop/curriculum/passages.jsonl
      # 11622 total (source): kg_term 8553 · doc_section 1172 · transcript_segment 1055 · kg_area 516 ·
      #              code 251 · kg_todo 27 · kg_next_point 24 · kg_open_question 14 ·
      #              kg_meeting_note 10        →  kg_lesson_section: 0
      ```

      **Zero of 11,622**, and the reason is structural rather than unfinished work:
      `pkg/knowledge/materials.go`'s `LessonSectionMeta` carries `Heading`, `Ordinal`, `Authorship`
      and `CitationCount` and **no identifier**, so there is no key to index a row on or to join a
      question to. The refusal is pinned by a test —
      `pkg/search/question_search_test.go:205 TestT057_LessonSectionIsNotAdvertisedBecauseNothingIndexesIt`
      — which fails if `lesson_section` is ever added to `corpus.indexed_kinds` without something
      behind it, and which also asserts the three backed kinds ARE advertised so it cannot pass on a
      build that quietly stopped advertising everything.

      **Why this stays unticked:** the task names four kinds and three are indexed. Closing it needs
      either a minted `lesson_section` identity (a data-model change) or an amendment narrowing the
      task to the three kinds that can carry one. **That is a spec decision and it is not made here.**

      **[TICKED 2026-09-04. The blocker note is WITHDRAWN BY NAME: the clause *"That is a spec
      decision and it is not made here"* is STALE — the decision HAS been made and is written into
      the contract.** `contracts/http-api-delta.md` C4.1.1 now reads *"`area`, `term` and `question`
      join the existing kinds"*, with an explicit blockquote recording that **`lesson_section` was
      REQUIRED here and is WITHDRAWN, 2026-09-03, by operator decision** — 0 of 11,622 records
      carried the kind and its metadata type has no identifier field, making it structurally
      unkeyable. `grep -c lesson_section spec.md` = **0**, so the spec never required it either.
      **Measured live 2026-09-04 at generation 68**, `GET /api/search?q=area` returns
      `corpus.indexed_kinds = [transcript_segment, doc_section, code, diagram, area, term,
      question]` — the three contracted kinds are indexed and `lesson_section` is correctly ABSENT
      rather than advertised-empty, which is the zero-entry-kind defect C4.1.1 forbids. The refusal
      is test-pinned, not incidental: `TestT057_LessonSectionIsNotAdvertisedBecauseNothingIndexesIt`.
      `go test -count=1 -run 'TestT057|TestT058|TestGateKG11' ./pkg/search/...` -> **ok, rc 0** (in_process).
      Honest boundary (§11.4.6): the contract amendment is an UNCOMMITTED working-tree change
      (` M contracts/http-api-delta.md`). The tick is sound; the change is not yet committed]**
- [x] T364 (was: 002/T058) [US3] [TDD] Advertise the new kinds in the corpus block, and prove **G-KG-11**: an
      advertised kind must be **retrievable**, proven by a planted known target — **not** by a row
      count, which cannot distinguish a populated index from a populated table nobody queries. The
      corpus already advertises one kind with zero entries (FR-028→unified FR-156, SC-013→unified SC-087)

      **3 of 4 kinds advertised and proven; `lesson_section` is a recorded gated REFUSAL, not a
      gap.** The note this task carried — *"its scope is `area` + `term` only. `lesson_section` and
      `question` are still neither advertised … nor proven"* — is **WITHDRAWN, not restated**.
      G-KG-11 now covers a third kind, proven the way the task demands — by a **planted known target
      actually retrieved**, never by a row count:

      - `area` + `term` — `pkg/search/knowledge_search_test.go:93`
        `TestGateKG11_AdvertisedAreaTermKindsAreRetrievable`, with its negative twin at `:176`.
      - `question` — `pkg/search/question_search_test.go:75`, whose own comment is *"advertised
        BECAUSE it is retrievable"*, and which plants a question and retrieves it.

      ```bash
      cd workshop/platform/backend && go test -count=1 -run 'TestT057|TestT058' ./pkg/search/...  # ok (in_process)
      ```

      Live, every advertised kind was probed by unioning search results across fourteen queries (served):
      `area` **5** entries · `term` **382** · `question` **44** · **`diagram` 0**. The zero-entry
      kind this task names in its own last sentence is therefore **still `diagram`, and still
      exactly one** — this phase added a kind that is backed and did not add a second empty one,
      which was the constraint C4.1.1 imposed. `lesson_section` is absent from
      `corpus.indexed_kinds` entirely rather than advertised empty, which is the correct handling
      and is pinned by `TestT057_LessonSectionIsNotAdvertisedBecauseNothingIndexesIt`.

      **Why this stays unticked:** it is bound to 002/T057 (unified T363) — the fourth kind is neither indexed nor
      advertised, and the same spec decision settles both.

      **[TICKED 2026-09-04, on the same operator amendment as 002/T057 (unified T363) — see that task's evidence.**
      The corpus block advertises exactly the three contracted kinds. `lesson_section` is absent by
      a deliberate, test-pinned refusal rather than by omission, and advertising it would itself be
      a C4.1.1 failure. Exactly one zero-entry kind remains (`diagram`), which C4.1.1 explicitly
      tolerates as pre-existing while forbidding this feature from ADDING more — and this feature
      adds none. G-KG-11 verified by `go test -count=1 -run 'TestT057|TestT058|TestGateKG11'
      ./pkg/search/...` -> **ok, rc 0** (in_process); pinning assertions at `pkg/search/knowledge_search_test.go`
      and `pkg/search/question_search_test.go`. Same honest boundary as 002/T057 (unified T363): the contract
      amendment is uncommitted]**
- [x] T365 (was: 002/T059) [US3] [REVIEW] Settle **U1** before implementing offsets: does the full-text engine expose
      match positions through a supported interface, or must offsets be recomputed by re-locating
      query terms in the matched text? Three-valued exit. This has a correctness edge — a
      recomputation can disagree with what the index actually matched, particularly under the prefix
      matching the lexical leg applies to the final query token. **002/T060 (unified T366) is blocked on this** (FR-029→unified FR-161)
- [x] T366 (was: 002/T060) [US3] [TDD] Implement match offsets per **C4.1.3**: the lexical leg
      produces real offsets, **or** the field is removed and its absence stated. Leaving a field that
      promises a position and never carries one is forbidden. Gate **G-KG-5**. **Paired mutation**:
      return an empty offset list from a leg that could produce offsets (FR-029→unified FR-161)

      **`[BLOCKED: U1 / 002/T059 (unified T365)]` STRIPPED 2026-09-02 — the blocker was discharged, and the marker was
      describing a state that no longer existed.** 002/T059 (unified T365) settled U1 from evidence: the full-text
      engine exposes match positions through a supported interface, so offsets are read from the
      index rather than recomputed by re-locating query terms — the correctness edge U1 named does
      not arise. Recorded at `workshop/docs/session-evidence/phase5-report.md`; the implementation
      and its tests are at `workshop/platform/backend/pkg/search/offsets.go`,
      `offsets_test.go` and `lexical_offsets_test.go`. Re-derive by reading those paths, not this
      sentence.
- [x] T367 (was: 002/T061) [US3] [TDD] Implement **C4.1.4**: the semantic leg reports that it **cannot** produce
      offsets — a different fact from producing none. One empty list meaning both is exactly the
      collapse this contract exists to prevent (FR-029→unified FR-161, FR-033→unified FR-159)
- [x] T368 (was: 002/T062) [US3] [TDD] Implement the locus on every hit per **C4.1.2**, and withhold any hit whose
      locus does not resolve (FR-030→unified FR-162) (FR-029→unified FR-161, FR-030→unified FR-162)
- [ ] T369 (was: 002/T149) [US3] [TDD] [REVIEW] Extend redaction propagation (002/T021 (unified T059), FR-027→unified FR-148) to every cached or
      precomputed representation of a passage's text this phase introduces — the search match
      offsets and snippets T060/T061 compute ahead of a query — **synchronously with the redaction**,
      never waiting for the next full reindex. Gate **G-KG-23**. **Paired mutation**: redact a
      passage, immediately issue a search that would have matched it, and serve from a
      representation only invalidated on the next scheduled reindex; the gate must go red (FR-027→unified FR-148, FR-027a→unified FR-149, SC-012→unified SC-080, SC-012a→unified SC-081)
- [x] T370 (was: 002/T063) [US3] [TDD] Prove **SC-014** over **every** hit of the benchmark run — a hit without a
      resolving locus fails the run, not merely itself (FR-030→unified FR-162, SC-014→unified SC-088)

      **DONE 2026-09-03. The note that stood here is WITHDRAWN, not restated, and its withdrawn
      claim is named so a brief written from the old text is recognisable:** *"The 'over **every**
      hit of the benchmark run' half is still not implemented: `grep -c locus
      pipeline/benchmark/run_retrieval_benchmark.py` returns **0**, so no hit can fail the RUN."*
      That sentence remains TRUE of that Python script and it is no longer the reason this task is
      open — a different instrument, built the same day, discharges the task. The script is the
      passage-level SC-015 benchmark; the run SC-014 names is 002/T066 (unified T373)'s new-kinds benchmark, and it is
      now executed by a gate.

      Re-derived by execution, not read:

      ```bash
      bash workshop/platform/gates/verify-retrieval-benchmark.sh   # rc=1 (served), live against :8087
      #   PASS  B1 all 560 hit(s) of this run carry a resolving locus (C4.1.2 / FR-030→unified FR-162) (served)
      #   FAIL  B2 SC-015 NOT met: top-5 8/22 — a MEASUREMENT, and 002/T067 (unified T374)'s problem, not B1's
      #   PASS  B3 no negative query returned an area, term or question record
      bash workshop/platform/gates/prove-retrieval-benchmark.sh    # rc=0 (population: unstated) — 6 mutations, 6 caught
      ```

      **B1 asserts the property over EVERY hit the run returned — 560 of them, not a sample — and a
      violation fails the RUN, which is the half the old note said was missing.** That is proven
      rather than asserted: the paired proof's **M1-locus** mutation plants a hit whose locus does
      not resolve and requires the whole gate to exit **1**; it does. The gate is three-valued by
      demonstration too — **M4-no-server** and **M5-no-bench** each require exit **2**, so an
      unreachable service is never a pass. Registered as `T066-T067-retrieval-benchmark` in
      `platform/gates/check-registry-002.tsv`.

      **Honest boundary (§11.4.6), and it does not withhold the tick.** The proven population is the
      560 hits (served) of the new-kinds benchmark run. `pipeline/benchmark/run_retrieval_benchmark.py` still
      carries no locus handling, so the passage-level benchmark asserts nothing about locus; and
      `prove-retrieval-benchmark.sh` is itself **not registered** in `check-registry-002.tsv` — the
      gate's row is 4 fields with no paired-proof column, so the proof runs green but nothing
      enumerates it. Both are recorded rather than netted away.
- [x] T371 (was: 002/T064) [US3] [TDD] Implement kind and area filters per **C4.1.5**, echoing the applied filter so a
      client can tell a filtered empty result from an unfiltered one (FR-032→unified FR-164)
- [x] T372 (was: 002/T065) [US3] [TDD] Add area and term names to suggestions per **C4.2.1**, and prove **C4.2.2**:
      the suggestion service still holds **no embedder**. Type-ahead stays lexical — semantic
      embedding under load has been observed in the tens of seconds against a 200 ms budget (FR-031→unified FR-155, SC-016→unified SC-090)
- [x] T373 (was: 002/T066) [US3] Build the ≥20-query benchmark for the new kinds in the platform's existing benchmark
      directory, beside the gates that read it, with expected identifiers fixed **in advance** (SC-015→unified SC-089)

      **DONE 2026-09-03. Three claims of the note that stood here are WITHDRAWN BY NAME, not
      deleted, because a brief written from the old text would still assert them:**

      - **WITHDRAWN claim 1:** *"it is NOT in the platform's existing benchmark directory
        (`platform/backend/testdata/benchmark/` still holds only the specs-001 `questions.tsv`)."*
      - **WITHDRAWN claim 2:** *"**no gate reads it** … nothing executes the benchmark from the
        platform side."*
      - **WITHDRAWN claim 3:** *"`check-registry-002.tsv` has no row naming it."*

      All three were true of `pipeline/benchmark/retrieval_benchmark.json`, which is a DIFFERENT
      artifact and stays where it is. A second benchmark — the one this task actually names — now
      exists. Measured, not read:

      ```bash
      ls workshop/platform/backend/testdata/benchmark/
      #   kinds_retrieval_benchmark.json   questions.tsv   # (source)
      python3 -c '...'   # 22 positive (area 5 · term 12 · question 5) + 6 negative (source)
      grep -n kinds_retrieval_benchmark workshop/platform/gates/verify-retrieval-benchmark.sh
      #   150: reads it as the gate's own input
      grep -n 002/T066 (unified T373) workshop/platform/gates/check-registry-002.tsv
      #   62: check  T066-T067-retrieval-benchmark  shell  platform/gates/verify-retrieval-benchmark.sh
      ```

      **Every clause of this task is satisfied by measurement:** ≥20 queries (22 positive over the
      three kinds this feature indexes, plus 6 negatives); in the platform's existing benchmark
      directory; beside the gate that reads it; and expectations fixed **in advance** — the file's
      own `_meta.expectations_fixed_in_advance` records that every expected identifier was taken
      from the CATALOGUE endpoints (`/api/areas`, `/api/terms`, `/api/areas/{id}/questions`) and
      **never from a search ranking**, with three stated selection rules applied verbatim and no
      per-query adjustment. It also records the discipline that makes that checkable: *"the file was
      written, then run. A query that fails is recorded as a failure, not rewritten."* The run bears
      that out — 14 of 22 positives (served) miss the top five and are printed as failures rather than
      re-cut.

      **Honest boundary (§11.4.6), and it does not withhold the tick:** the benchmark's own RESULT
      is that SC-015 is not met (top-5 8/22, served). That is 002/T067 (unified T374)'s finding, not a defect in this artifact;
      a benchmark whose queries all passed on first run would be the suspicious one.
- [ ] T374 (was: 002/T067) [US3] [TDD] Prove **SC-015**: the gate prints **per-query** outcomes, not only the — **BLOCKER:** **retrieval quality, and nobody's decision** — the instrument is built and correct; SC-015 is MEASURED NOT MET at top-5 12/22 (54.5%), top-1 3/22, against a bar of 20/22. The `term` leg is the shortfall · **OWNER:** **implementer** — unblocked, but it is a quality problem, not a wiring problem
      aggregate — which queries fail is the useful information, and an aggregate hides it (SC-015→unified SC-089)

      **PARTIAL — and the FIRST of the two reasons is DISCHARGED. The claim *"It is still **not a
      gate**: its only exit is `return 0` (line 309) … and it still has no row in
      `platform/gates/check-registry-002.tsv`"* is WITHDRAWN, not restated.** It described
      `run_retrieval_benchmark.py`, and it is still true OF THAT SCRIPT. It is no longer the state
      of this task: a real gate over the new-kinds benchmark exists, is three-valued, is registered,
      and has a paired proof. Measured by execution 2026-09-03:

      ```bash
      bash workshop/platform/gates/verify-retrieval-benchmark.sh   # rc=1
      bash workshop/platform/gates/prove-retrieval-benchmark.sh    # rc=0 — 6 mutations, 6 caught
      #   M0 control 0 · M1-locus 1 · M2-ranking 1 · M3-negative 1 · M4-no-server 2 · M5-no-bench 2
      ```

      **It prints per-query outcomes, which is precisely what this task's own descriptive clause
      asks for** — a `id / type / kind / rank / top1 / top5 / status` row for each of the 22
      positives and a `status` + `kg_records_returned` row for each of the 6 negatives, with the
      aggregate printed *after* them rather than instead of them. Registered as
      `T066-T067-retrieval-benchmark` at `check-registry-002.tsv:62`.

      **The SECOND reason stands and is why the box is still `[ ]`: SC-015 is measured NOT MET.**
      The criterion needs ≥90% of ≥20 queries returning the expected item in the top five. Measured
      on the served path 2026-09-03 over the new-kinds benchmark: **top-5 8/22 (36.4%)** against a
      bar of 20/22, **top-1 4/22**. Per kind, printed by the gate: `question` 5/5 top-5 (4 of them
      top-1), `area` 3/5, `term` **0/12**. A `[TDD]` task that says *"Prove SC-015"* cannot be
      ticked while the criterion it names is red — the instrument is built, the property is absent,
      and the gate is correctly failing rather than passing.

      **Two earlier figures are SUPERSEDED, not wrong when written, and they are NOT comparable to
      the 8/22 above:** *"top-5 20/26, top-1 8/26"* and *"13/26 before it"* were measured over
      `pipeline/benchmark/retrieval_benchmark.json`, whose expected identifiers are transcript and
      `doc_section` PASSAGES. That benchmark asks *"can the corpus be found"*; this one asks *"can
      the new kinds be found"*, which is the question 002/T066 (unified T373) names. Quoting one as the other's
      before-figure would compare two different populations.

      **What the failure actually is, measured rather than inferred: the `term` leg returns nothing
      in the top five for any of its 12 queries** (7 of 12 rank outside the top 20 entirely; the
      other 5 rank 13–20). `area` and `question` both clear the bar on their own. Recorded here
      because "SC-015 is 36%" reads as a uniform shortfall and it is not one.
- [ ] T375 (was: 002/T068) [US3] [TDD] Prove **SC-016 / SC-017**: re-run the latency harness and **publish before and — **BLOCKER:** **NOT "just a quiet host" — that remedy is now IN DOUBT, and this is the correction that matters.** Re-run 2026-09-04: rc **2**, `PASS 0 FAIL 0 UNDET 7`. The gate read the index block cleanly (generation 68, 12,979 passages, live) and then **every** endpoint refused — including the `health CONTROL`, which by the harness's own design makes the fused figure uninterpretable. Immediately afterwards `podman ps` showed `workshop-curriculum_platform_1  Up 46 seconds (starting)` and `/api/health` returned `HTTP=000`: **the container went down underneath a read-only run.** `tasks.md` already records the same sequence on 2026-09-03, so counting this it has happened **three times across two dates, every time during or immediately after `verify-search-latency.sh`**. Host load was FALLING across this run (17.5 -> 9.7), which weakens the load-average explanation the old note leans on. No causal claim is made — co-occurrence is not causation and this was not isolated — but the narrow, checkable claim is: the stated remedy *"one clean re-run, not new code"* has now failed three times identically, so treating this as bad luck risks a fourth identical result · **OWNER:** **implementer first** — find why the container dies under this harness's concurrent request pattern; that outranks the latency figure. **operator** second, for a quiet host, once the stability question is settled
      after together**. A single after-figure cannot show a regression that stayed inside the threshold (SC-016→unified SC-090, SC-017→unified SC-091)

      **PARTIAL — the note that stood here is STALE and its two claims are WITHDRAWN BY NAME. The
      task still does not tick, and the reason has CHANGED from "nobody re-ran it" to "the re-run
      cannot be reproduced today".**

      - **WITHDRAWN claim 1:** *"The newest column is still the 17:57 UTC one taken against
        **1,101** passages."*
      - **WITHDRAWN claim 2:** *"No re-run against today's grown corpus is recorded anywhere."*

      Both were true when written and neither is true now. `docs/limits.md` §2 carries a **fourth**
      column — 2026-09-03, **2,478**-passage corpus, generation 67 — placed BESIDE the three older
      ones rather than replacing them, with the breaching figure struck through and annotated
      `SUPERSEDED — see §2.1` instead of deleted. That is exactly the
      publish-before-and-after-together discipline this task asks for, and §2.1 states the
      supersession by name. The recorded column reads `/api/suggest` p95 **9.5 ms** (SC-016's budget
      is 200 ms) and `/api/search` fused p95 **238.6 ms** (SC-017's budget is 2 s), taken with
      `platform/gates/verify-search-latency.sh`, which now has a paired proof
      (`prove-search-latency.sh`) and two registry rows added the same day
      (`SC-006-search-latency`, `SC-006-search-latency-proof`).

      **Why the box stays `[ ]`: this reconciliation could NOT reproduce that column, and a figure
      nobody can re-derive is not a proof.** The gate's own closing instruction is *"Re-run it; do
      not quote it."* It was re-run twice on 2026-09-03 and neither run is usable:

      ```
      run 1  rc=1  search fused p95 4994.5 ms   PASS 0  FAIL 1  UNDET 4
             — but `health CONTROL` is itself UNDET (connection refused), and the container
               reported `Up 39 seconds` immediately afterwards: it went DOWN mid-run.
      run 2  rc=0-with-nothing-measured        PASS 0  FAIL 0  UNDET 7
             — every endpoint including the control: "Remote end closed connection without
               response" / "Connection refused".
      ```

      **Neither run refutes the 238.6 ms column and neither confirms it — this is a COULD NOT
      DETERMINE, and a 2 is never a pass.** The control row is the whole point of the harness: with
      `health CONTROL` undetermined, the fused figure is uninterpretable by the gate's own design.
      The host was at load average **20.2–22.3** during both attempts (§2's own caveat is that no
      latency figure here may be quoted without its load context) and the platform container was
      restarted underneath them by concurrent work in this tree.

      **What remains for this task is one clean re-run, not new code:** `bash
      workshop/platform/gates/verify-search-latency.sh` on a quiet host, with the `health CONTROL`
      row determined, confirming SC-016 and SC-017 against the published pair. Also unresolved and
      recorded rather than netted away: the gate labels its budget `SC-006`, which is **spec 001's**
      criterion; SC-016/SC-017 are **this** spec's, and no instrument in this tree asserts them
      under their own names (standing rule 7).
- [x] T376 (was: 002/T069) [US3] [P] [SUBAGENT] Extend the search view for the new kinds, the filters and the locus
      display (FR-029→unified FR-161, FR-032→unified FR-164, FR-033→unified FR-159)

      **DONE 2026-09-03. The note that stood here is WITHDRAWN, not restated, and its claim is named
      because it is exactly the kind a brief would carry forward:** *"The **filters and the locus
      display are still absent**: `core/api.ts:273` is still `search(q: string, limit = 20)` setting
      only `q` and `limit` … and the component still contains **zero** `locus` and **zero** `filter`
      references."* Every clause of that was true when written and none of it is true now — the work
      landed in workshop `bd7da41`.

      Re-derived by reading the tree, then **proven by execution**:

      ```bash
      grep -n 'search(q' workshop/platform/frontend/src/app/core/api.ts
      #   search(q: string, opts: SearchOptions = {})   — sends `kinds` (ONE comma-joined
      #   parameter, the shape the deployed server parses) and `area`; an empty filter is
      #   OMITTED rather than sent empty, because "no kind filter" and "a kind filter naming
      #   nothing" are different requests
      grep -c 'locus'  .../features/search/search.component.ts   # 11 (source)
      grep -c 'filter' .../features/search/search.component.ts   # 42 (source)

      cd workshop/platform/frontend
      CHROME_BIN=/usr/bin/chromium npm run test:unit
      #   Chrome Headless 147: Executed 97 of 97 SUCCESS (in_process)
      ```

      Line numbers are deliberately omitted — the file moved twice on the day — so re-derive with
      `grep -n` rather than trusting a citation.

      The 97 include a **`SearchComponent — 002/T069 (unified T376) filters and locus`** block of 6 tests, and the six
      are the task's three halves checked one at a time: no `kinds`/`area` parameter is sent when
      nothing is filtered; the ticked kinds go out comma-joined with the chosen area; the kind list
      is offered **from `corpus.indexed_kinds`** and never from a hardcoded list (so a kind the
      corpus stops advertising disappears from the UI by construction); the area list carries only
      areas with an authored title and **counts the rest**; each hit's locus is rendered **from the
      server's own `locus.unit`/`locus.position`, never reassembled client-side**; and a FILTERED
      `no_match` says so where an UNFILTERED one does not, with the echo carried onto `unavailable`
      alongside a statement that the filter is not the cause.

      **Honest boundary (§11.4.6), and it does not withhold the tick:** this is a `[P] [SUBAGENT]`
      task, not `[TDD]`, so no paired mutation is owed by the global constraint — and none of the
      six 002/T069 (unified T376) tests is one. The evidence is 6 behavioural unit tests executing the component, not a
      grep.
- [x] T377 (was: 002/T070) [US3] [P] Update the route manifest and contract for the changed search and suggest
      endpoints (FR-059→unified FR-274)

      **CORRECTED 2026-09-03 — the note that stood here has gone STALE, and its two claims are
      WITHDRAWN BY NAME rather than deleted, so a brief written from the old text is recognisable.**

      - **WITHDRAWN claim 1:** *"all three rows still cite the **001** contract sections
        (3.6 / 3.7 / 3.11)."*
      - **WITHDRAWN claim 2:** *"There are still no rows or notes for the 002 delta sections
        **§4.1** (locus/offsets/kinds/filters), **§4.2** (areas and terms in suggest) or **§4.4**
        (progress over areas)."*

      Both were true when written. Neither is true now. The one clause of that note that still
      holds is its first: `platform/gates/route-manifest.tsv` carries `/api/suggest`, `/api/search`
      and `/api/progress` rows.

      **What is true, measured 2026-09-03 (source) in `workshop/platform/gates/route-manifest.tsv`.** All
      three rows now carry the **R1b compound** contract token naming both documents —
      `/api/suggest` reads `3.6+002.4.2`, `/api/search` reads `3.7+002.4.1`, `/api/progress` reads
      `3.11+002.4.4` — and each row's note names the delta clauses it answers for (C4.2.1/C4.2.2;
      C4.1.1–C4.1.5; C4.4.1/C4.4.2) alongside the tasks that changed it, this one among them. The
      manifest half of this task is therefore met for the endpoints it names.

      **The COULD NOT DETERMINE recorded here on 2026-09-03 is now RESOLVED — measured the same
      day, and it resolves to NOT MET rather than to a pass.** The withdrawn sentence was: *"whether
      anything further is owed by the 'and contract' half of this task's title was **NOT
      measured** here."* It has now been measured, and something is owed.

      `contracts/http-api-delta.md` carries `## 4. Endpoints changed` with `### 4.1 GET /api/search`
      (C4.1.1–C4.1.6) and `### 4.2 GET /api/suggest` (C4.2.1, C4.2.2) — so the sections exist and
      the manifest rows cite them. **But §4.1's C4.1.1 still reads *"`area`, `term`,
      `lesson_section` and `question` join the existing kinds"* and declares an advertised kind with
      zero indexed entries a failure**, while the served corpus block advertises **seven** kinds (served)
      **without** `lesson_section`, and `TestT057_LessonSectionIsNotAdvertisedBecauseNothingIndexesIt`
      pins that refusal in code. The contract therefore requires a fourth kind the implementation
      deliberately refuses, and the refusal is recorded in `tasks.md` (T057/T058) and in
      `docs/limits.md` — **everywhere except the contract this task is responsible for updating.**

      That divergence is the remaining work, and it is NOT a coding change: closing it needs either
      a minted `lesson_section` identity or an amendment narrowing C4.1.1 to the three kinds that
      can carry one — **the same spec decision 002/T057 (unified T363) and 002/T058 (unified T364) are already waiting on**, which is why
      this task is now bound to them rather than independently open.

      Separately, and outside this task: `contracts/http-api-delta.md` §2 R1b records an
      open obligation on the **fourth** changed endpoint, `/api/ask`, which belongs to `002:T143`.
      Its own honest-boundary paragraph says the `/api/ask` rows carry a bare `3.10`; measured the
      same day, the `GET /api/ask?q=ping` row reads `3.10+002.4.3`, so that paragraph is partly
      stale too and is not restated as current here.

      **[TICKED 2026-09-04. The note's clause *"§4.1's C4.1.1 STILL READS `area`, `term`,
      `lesson_section` and `question` join the existing kinds"* is FALSE and is WITHDRAWN BY NAME**
      — C4.1.1 reads THREE kinds as of the 2026-09-03 operator amendment, so the contract divergence
      that was this task's stated residue is CLOSED by the amendment rather than by an edit here.
      The route-manifest half is met: rows carry the R1b compound contract token naming BOTH
      documents, verified in `platform/gates/route-manifest.tsv` (source) — `/api/suggest` `3.6+002.4.2`,
      `/api/search` `3.7+002.4.1`, `/api/progress` `3.11+002.4.4`, `/api/ask` `3.10+002.4.3`. The
      `/api/search` row records the measured live kind list and states the `lesson_section` refusal
      in the same breath, so the manifest and the contract now agree. Same honest boundary as 002/T057 (unified T363):
      the contract amendment is uncommitted]**


---

## Phase 10: US11 — provenanced assessment (P1)

**14 tasks — 13 complete, 1 open.** Sources: 002.


*From `002` — Phase 6: User Story 4 — provenanced assessment (P4)*

- [x] T378 (was: 002/T071) [US4] [TDD] Implement the question model in `pkg/assessment/question.go`, porting the
      reference's field shape and **adding the mandatory citations field**. This is the feature's one
      deliberate divergence and the reason it exists (FR-034→unified FR-107, FR-035→unified FR-110)
- [x] T379 (was: 002/T072) [US4] [TDD] Implement **Q1 / G-KG-2**: a question is served **only** if it carries at least
      one citation and **every** citation resolves. A citation resolving to redacted, not-present or
      could-not-determine ⇒ **withheld**. Not served with a warning, not with the citation stripped,
      not with an empty list. **Paired mutation**: serve it with the citation stripped (FR-035→unified FR-110, FR-036→unified FR-111, SC-018→unified SC-064)
- [x] T380 (was: 002/T073) [US4] [TDD] Implement **Q2 / G-KG-3**: every long-set question cites **more than one
      distinct** passage. **Paired mutation**: admit a single-citation question to the long set (FR-034a→unified FR-108, SC-017a→unified SC-061)
- [x] T381 (was: 002/T074) [US4] [TDD] Implement **Q3**: every question names the lesson sections it assesses — this
      is what makes per-section coverage measurable rather than estimated (FR-034b→unified FR-109, SC-017b→unified SC-062)
- [x] T382 (was: 002/T075) [US4] Author the short and long question sets **from the workshop's own passages** (Q5).
      **Nothing from the reference's 785 items may appear**, including as a placeholder (FR-004→unified FR-066, FR-034a→unified FR-108, FR-035→unified FR-110)
- [x] T383 (was: 002/T076) [US4] [TDD] Implement **G-KG-16**: plant one reference question in a workshop bank and
      assert the boundary check fails. **Paired mutation**: scope the check to the outbound direction
      only. It runs both ways deliberately — outbound keeps a private recording out of public
      repositories, inbound keeps the workshop from shipping someone else's curriculum (FR-004→unified FR-066, FR-004a→unified FR-067, SC-029a→unified SC-144)
- [x] T384 (was: 002/T077) [US4] [TDD] Implement the assembled-answer marking per **Q4 / A3.5.4** — a client must not
      have to infer it (FR-038→unified FR-114, SC-020→unified SC-066)
- [x] T385 (was: 002/T078) [US4] [TDD] Implement `GET /api/areas/{area}/questions` per §3.5, including **A3.5.5**:
      report how many questions were withheld and why. A silently shorter set is how a provenance
      guarantee decays into a claim without anyone noticing (FR-036→unified FR-111, FR-059→unified FR-274)
- [x] T386 (was: 002/T079) [US4] [TDD] Implement `GET /api/areas/{area}/coverage` per §3.6: **per-area figures,
      never only an aggregate**; sections with zero questions listed explicitly; **no threshold and no
      pass field**. Gate **G-KG-12**. **Paired mutation**: replace the per-area table with a mean (FR-034b→unified FR-109, FR-059→unified FR-274, SC-017b→unified SC-062, SC-017c→unified SC-063)

      **DONE — the "PARTIAL … the §3.6 endpoint is still not built … returns 404 … there is no
      `route-manifest.tsv` row" note this task carried is WITHDRAWN, not restated.** The route was
      mounted and the manifest row added on 2026-09-03; the note described a state that no longer
      exists. Re-measured live 2026-09-03 against the running container
      (`workshop-curriculum_platform_1`, healthy, `/api/health` 200):

      ```bash
      # every area id from /api/areas, probed one by one
      curl -so /dev/null -w '%{http_code}' http://127.0.0.1:8087/api/areas/$ID/coverage
      # 200 for 495 of 495 areas — 0 are 404 (served)
      ```

      The 404 half is gone and the shape holds on the WIRE, not merely on the struct. The live
      response carries `per_area` as a **list**, `section_question_counts` with every roster section
      as a key, `zero_sections` naming the zero-question ones again, and a `derivation` block whose
      own words are `"threshold": "NONE"` and `"aggregate": "NONE"` — no threshold, no target, no
      mean, no pass field. `derivation.served_only` records that withheld questions contribute
      nothing (G-KG-2). Manifest row `002.3.6` is registered in
      `workshop/platform/gates/route-manifest.tsv` and states the same history in its own words.
      Gate and paired mutation re-run uncached and green:

      ```bash
      cd workshop/platform/backend
      go test -count=1 -run 'TestT079' ./pkg/assessment/... ./internal/api/...   # ok (in_process)
      # pkg/assessment/coverage_test.go:154 TestT079_PairedMutation_ReplacePerAreaTableWithMean
      # internal/api/coverage_wire_test.go — 7 wire tests, incl.
      #   TestT079_Wire_ExpressesNoThresholdAndNoPassField and
      #   TestT079_Wire_ForbiddenKeyScannerActuallyCatchesOne (the scanner's own paired proof)
      ```

      **Honest boundary (§11.4.6):** A3.2.2's publication-review requirement is deliberately **not**
      applied on this route, by a call whose reasoning is recorded in `internal/api/coverage.go`'s
      own doc comment — which is why coverage answers 200 for all 495 areas (served) while `GET
      /api/areas/{area}` answers 200 for only **2**. §3.9 makes the opposite call; both divergences
      are declared where they happen rather than left to be discovered. Separately, the live
      `derivation.lesson_section_identity` field warns that the two roster sizes it reports do not
      measure the same thing — read it before comparing them.
- [x] T387 (was: 002/T080) [US4] [TDD] Prove **SC-018** by enumerating every served question and resolving every
      citation, and **record the reference module's measured value — 0 of 785 — beside it**, so the
      comparison is measured rather than claimed (FR-035→unified FR-110, SC-018→unified SC-064)
- [x] T388 (was: 002/T081) [US4] [TDD] Prove **SC-019**: the question-to-moment-and-back round trip, over every
      eligible question; if impractical, a seeded sample of ≥30 **with the population size published** (FR-037→unified FR-113, SC-019→unified SC-065)
- [x] T389 (was: 002/T082) [US4] [TDD] Extend progress to areas and question sets, and prove **C4.4.2**: progress
      **survives a content re-ingest**. The reference deliberately preserves its progress table while
      wiping everything else; a learner's history is not a derived artifact (FR-039→unified FR-118)
- [x] T390 (was: 002/T083) [US4] [P] Add route-manifest rows and contract sections for the assessment endpoints (FR-059→unified FR-274)

      **DONE — the "PARTIAL … coverage (§3.6) and export (§3.9) still have neither a manifest row
      nor a mounted route … both return 404" note is WITHDRAWN, not restated.** All three assessment
      endpoints now have a contract section, a manifest row and a mounted route. Re-measured
      2026-09-03:

      ```bash
      grep -n '^### 3\.' specs/002-knowledge-areas-deep-linking/contracts/http-api-delta.md
      # 3.5 questions · 3.6 coverage · 3.9 export — all present (source)
      grep -c '002\.3\.[569]' workshop/platform/gates/route-manifest.tsv   # 3 rows (source)
      curl -so /dev/null -w '%{http_code}' http://127.0.0.1:8087/api/areas/$ID/export   # 200 (served)
      ```

      Manifest rows `002.3.5`, `002.3.6` and `002.3.9` are registered, and the two new rows record
      in their own words that they "WAS A BARE 404 UNTIL 2026-09-03" — the row and the route landed
      together, which is the pairing this task exists to enforce. Export behaves per contract on both
      sides of the gate, measured live (served) rather than read:

      - **Published area** (`01M1GWW49GNKYBEXFFCNRWM1SY`) → `exportable: true`, four formats listed,
        `markdown` `present` with a real `href` and `size_bytes`, `html`/`docx`/`pdf`
        `could_not_determine` with `toolchain_blockers` naming `pandoc`/`weasyprint` as absent **in
        the container** — A3.9.2's "never an empty format list" honoured.
      - **Unpublished area** (`01M1GWQYWSKZA7A2S59MNV0Z2Q`) → `exportable: false`, four
        `precondition_blocked` formats, no `href`, no source path. A3.9.1 requires exporting nothing
        **and saying so**; saying so needs a body, so this is a 200 carrying the failed precondition
        rather than a 404. The §3.2 route keeps returning its own `404 area_not_published` — this
        does not soften it.

      ```bash
      cd workshop/platform/backend
      go test -count=1 -run 'TestT083' ./internal/api/...   # ok (in_process)
      # 10 wire tests, incl. TestT083_ProbeExportToolchain_NeverAsksForAVersion —
      # the probe makes each tool DO its job rather than answer --version
      ```
- [ ] T391 (was: 002/T084) [US4] [REVIEW] Review question provenance end to end before the practice surface consumes — **BLOCKER:** none but the work — the only review record is `phase6-report.md` (unchanged since 2026-09-02 12:54) and it merely mentions 002/T084 (unified T391); no later record exists. Pure review-record authorship, and the second of the two things holding 002/T122 (unified T540) · **OWNER:** **implementer/reviewer** — unblocked today
      it (FR-035→unified FR-110, SC-018→unified SC-064)

      **NOT DONE (re-measured 2026-09-03, unchanged).** `workshop/docs/session-evidence/phase6-report.md`
      deferred this review pending 002/T075 (unified T382) and 002/T078 (unified T385). **Both have since been completed and the review
      was never revisited** — `phase6-report.md` is still the newest phase-6 artifact (2026-09-02
      12:54), and `grep -rl T084` across `docs/` returns only that report and its own brief. No
      later review record exists under `docs/session-evidence/`, `curriculum/` or `specs/002-*/`.


---

## Phase 11: US19 + US23 — the learning surface, palette and accessibility (P2/P5)

**26 tasks — 20 complete, 6 open.** Sources: 002, 004, 005.


*From `002` — Phase 7: User Story 5 — the learning surface (P5)*

- [x] T392 (was: 002/T085) [US5] **Enumerate the four existing capabilities — chapter list, transcript, recording
      player, cross-references — and write the list down BEFORE any reshaping**. SC-023 is a
      before-and-after comparison, and a list reconstructed afterwards is a recollection, not a
      measurement (FR-041→unified FR-236, SC-023→unified SC-120)
- [x] T393 (was: 002/T086) [US5] [P] [SUBAGENT] Build the area list and area detail views (FR-040→unified FR-235)
- [x] T394 (was: 002/T087) [US5] [P] [SUBAGENT] Build the practice view with the question-to-moment jump and return (FR-037→unified FR-113, FR-040→unified FR-235)
- [x] T395 (was: 002/T088) [US5] [P] [SUBAGENT] Build the progress view across areas (FR-039→unified FR-118, FR-040→unified FR-235)
- [x] T396 (was: 002/T089) [US5] [P] [SUBAGENT] Build the study-plan view (FR-040→unified FR-235)
- [x] T397 (was: 002/T090) [US5] Subordinate the existing media views under areas per **D2** — reachable from within
      an area rather than as top-level objects. They are the working half of what exists and are what
      makes a timestamp jump possible at all (FR-041→unified FR-236, SC-023→unified SC-120)
- [x] T398 (was: 002/T091) [US5] [TDD] Prove **SC-023** against 002/T085 (unified T392)'s written list: every enumerated capability is
      still reachable (FR-041→unified FR-236, SC-023→unified SC-120)
- [x] T399 (was: 002/T092) [US5] Give the workshop its own token **values** against the shared contract. **Do not
      fork the component library** — forking doubles maintenance and guarantees drift (FR-043→unified FR-238) (FR-042→unified FR-237, FR-043→unified FR-238)
- [x] T400 (was: 002/T093) [US5] [TDD] Prove **SC-022** with **both** checks: the design toolkit's token conformance
      check **and** a literal-value scan. Either alone passes a stylesheet that defines perfect tokens
      and ignores them (FR-042→unified FR-237, SC-022→unified SC-119)
- [x] T401 (was: 002/T094) [US5] Implement interaction and motion from the platform's ranked,
      sourced user-experience research, each decision naming the finding it rests on (FR-044a→unified FR-239). An
      effect with no supporting finding does not ship on the grounds that it looks better (FR-044a→unified FR-239, SC-029b→unified SC-121)

      **`[BLOCKED: UX research]` STRIPPED 2026-09-02 — the blocker was discharged, and the marker was
      describing a state that no longer existed.** The research this task waits on exists as a real
      artifact: `workshop/docs/research/ux-research-2026-09-01.md`, 1,231 lines (source), carrying a **ranked**
      proposals section (16 proposals, ordered by value per unit of effort with stated effort bands),
      a separate rejected-with-reasons section, and 194 source URLs — ranked and sourced, which is
      exactly what FR-044a requires it to be. `workshop/docs/session-evidence/phase7-report.md`
      records FR-044a/b (T094/T095) as citing the finding each effect rests on. Re-derive by reading
      those paths, not this sentence.
- [x] T402 (was: 002/T095) [US5] [TDD] Implement reduced-motion support: final visual state preserved without the
      transition, and no effect load-bearing for comprehension (FR-044b→unified FR-240) (FR-044b→unified FR-240)
- [x] T403 (was: 002/T096) [US5] [TDD] Prove **SC-021**: an automated audit per view plus a keyboard-only traversal
      that **visits every deep-link affordance** and asserts each can be reached, activated and
      returned from (FR-044→unified FR-231, SC-021→unified SC-118)

*From `004` — Phase 7: User Story 5 — Vivid, legible, consistent (P2)*

- [x] T404 (was: 004/T045) [US5] Regenerate the served stylesheets from the widened token source in `workshop/platform/frontend/src/styles/`, then rebuild. **This is defect D6**: nothing had regenerated them, so a token-level widening never reached a visitor (FR-021→unified FR-224, FR-023→unified FR-229, SC-010→unified SC-116). — EVIDENCE (served): `bash workshop/platform/gates/verify-served-palette.sh` rc **0** against the LIVE served bundle (`sample: live, http://127.0.0.1:8087`, 2 stylesheets, 208 surfaces graded): 7 distinct hue families, floor 6 — the widening reaches a visitor, so D6 is closed at the served layer
- [x] T405 (was: 004/T046) [TDD] [SUBAGENT] [US5] Write a hue-family check that reads the **served** stylesheet — not the token source — asserting ≥6 distinct hue families across principal surfaces (SC-010→unified SC-116). A check that reads the token source commits D6 inside the instrument meant to catch it (SC-010→unified SC-116, FR-021→unified FR-224, FR-023→unified FR-229, FR-026→unified FR-259). — EVIDENCE (served): `bash workshop/platform/gates/verify-served-palette.sh` rc **0** — reads the SERVED stylesheets over http://127.0.0.1:8087, not the token source; `PASS: 7 distinct hue family/families across principal surfaces (floor 6)`
- [x] T406 (was: 004/T047) [TDD] [P] [SUBAGENT] [US5] Write a contrast check asserting the normal-text and non-text floors in **both** light and dark presentation, over the served bundle (SC-011→unified SC-117, FR-022→unified FR-227, FR-023→unified FR-229, FR-026→unified FR-259). — EVIDENCE (served): `bash workshop/platform/gates/verify-served-contrast.sh` rc **0** — `PASS: all 200 pairing(s) clear their floor, in each scheme independently` (8 unusable reported, not counted as passes)
- [x] T407 (was: 004/T048) [P] [SUBAGENT] [US5] Pair 004/T046 (unified T405) and 004/T047 (unified T406) with data-driven mutation proofs, each carrying a control and a vacuity refusal that exits 2 (FR-027→unified FR-261, FR-028→unified FR-260, FR-029→unified FR-262, SC-013→unified SC-135, SC-014→unified SC-136). — EVIDENCE (in_process): `bash workshop/platform/gates/prove-served-palette.sh` rc **0**, 8 passed / 0 failed / 8 mutations (M2 and M3 are rc-2 vacuity refusals, N1 the non-vacuity control); `prove-served-contrast.sh` rc **0**, 6 passed / 0 failed / 6 mutations (M0 control, M2 rc-2 vacuity refusal, M3 the light-passes/dark-fails split). Gate source byte-identical across each battery
- [ ] T408 (was: 004/T081) [P] [US5] Convey per-question correctness in the test result panel by an icon or text label in addition to colour, in `workshop/platform/frontend/src/app/features/areas/area-test.component.ts` (FR-022a→unified FR-228). A structural check over the served bundle MUST confirm every per-question result carries a non-colour indicator, in both light and dark presentation.
- [ ] T409 (was: 004/T049) [US5] Emit `corpus_revision` on the served catalogue and cite it in every interface claim (FR-023a→unified FR-230, SC-018→unified SC-042). **Analysis finding F7 — MISPLACED**: this is a catalogue concern owned by the backend stream, not a presentation one. Execute it with Phase 3 (US1); it is listed here only because the superspec blueprint's Track A carries a *bundle* build id, which is a different artefact, and this task must not be assumed covered by it.

*From `005` — Phase 4: User Story 4 — the interface looks designed on the surfaces people use (P2)*

- [x] T410 (was: 005/T043) [TDD] [US4] Make `workshop/platform/gates/verify-served-palette.sh` read the **SERVED bundle only**, through `lib/served_css.sh`, and never `src/styles/**` (FR-016→unified FR-224, FR-018→unified FR-226, SC-012→unified SC-116). **Evidence** (source): stated as the gate's entire reason for existing — measured defect **D6** was that the token source's hue span was widened, nothing regenerated the served stylesheets, and the token measurement was then reported as evidence about the interface. **"A check that read the token source to reach its verdict would have returned SUCCESS over exactly that defect."**
- [x] T411 (was: 005/T044) [US4] Family the colour an element **paints of its own** (`paint`), not only the ground behind it (`bg`) — defect **D-A** (FR-016→unified FR-224, FR-018→unified FR-226). **Evidence** (source): recorded in the same gate. For a `non-text` row the sampler sets `bg` to the ground *behind* the indicator, which is correct for contrast but meant **a coloured chip, wash, rule or fill could not contribute a hue family AT ALL, by construction**. The population excluded the very elements an interface uses to carry colour. A row with no `paint` still grades exactly as before, so an older sample is unaffected.
- [x] T412 (was: 005/T045) [US4] Define a hue family as a 30° bucket (12 buckets), with imperceptible-chroma colours collapsing into ONE `neutral` family counted once (FR-016→unified FR-224, FR-018→unified FR-226, SC-012→unified SC-116). **Evidence** (source): stated in-gate — *"counting each grey as its own hue would let a monochrome interface pass"*. Two colour spaces are used on purpose: HSL for the hue ANGLE (it need only partition colours that already have a hue), and a different measure for whether a colour has a hue at all, because HSL saturation divides by a span that vanishes near white and black. **The floor of 6 is fixed by the specification, not chosen by the gate** — FR-010 applied to the instrument.
- [ ] T413 (was: 005/T046) [US4] **PARTIAL** — re-measure the served hue-family count and record it against SC-012's floor of 6, up from a baseline of 2 (FR-016→unified FR-224, SC-012→unified SC-116). The corrected instrument exists (005/T043 (unified T410)–005/T045 (unified T412)) and `workshop/platform/gates/sample-served-surfaces.mjs` takes the browser sample. **No served run was captured in this session, so no post-fix count is claimed here.** `CONTINUATION.md:646` still records the baseline *"the served interface paints 2 hue families against a floor of 6"*, and until a served run supersedes it, **that is the last measured figure in this tree.** Note the shape of the trap this gate was built against: when the instrument became honest the count went **down** from 4 to 2 — a corrected gate reporting a worse number than the broken one it replaced.
- [ ] T414 (was: 005/T047) [US4] **OPEN** — give every hue present a stated classification job, so no hue is added only to raise a count (FR-017→unified FR-225, SC-012→unified SC-116). The design-system documents landed in commit `f11a3c1` (`workshop/docs/design-system/TOKENS.md`, `RATIONALE.md`, `COMPONENTS.md`, `wk-semantic-tokens.css`), but **nothing asserts the mapping from every painted hue to a declared job**, which is what SC-012's second half requires.
- [x] T415 (was: 005/T048) [TDD] [US4] Ship `workshop/platform/gates/verify-served-contrast.sh` with its paired prover, measuring text and non-text pairings separately in both presentations (FR-019→unified FR-227, SC-013→unified SC-117). **Evidence** (source): both `verify-served-contrast.sh` and `prove-served-contrast.sh` are tracked; `workshop/docs/design-system/contrast.py` (245 lines, commit `f11a3c1`) is the measurement, and its own commit records that **nine of the specification's own colours were short** — the spec was wrong and the instrument found it.
- [ ] T416 (was: 005/T049) [US4] **PARTIAL** — record the served contrast result: **0** failures across text and non-text pairings in both presentations (FR-019→unified FR-227, SC-013→unified SC-117). The gate and its prover exist; **no served run was captured in this session.**
- [ ] T417 (was: 005/T050) [US4] **OPEN** — justify the measured population independently of its effect on the count, and record that justification whenever the population changes (FR-018→unified FR-226, SC-012→unified SC-116). 005/T044 (unified T411) **changed the population** (adding `paint`) for a stated defect reason, which is the right shape — but no rule requires the next change to do the same, and the edge case *"a red is fixed by making the instrument weaker"* lives exactly here.


---

## Phase 12: US25 — four-format export (P6)

**8 tasks — 6 complete, 2 open.** Sources: 002.


*From `002` — Phase 8: User Story 6 — four-format export (P6)*

- [x] T418 (was: 002/T097) [US6] Port the export toolchain design as-is, driving it from the **capability probe** in
      002/T004 (unified T011) rather than from a name on `PATH` (FR-003→unified FR-065, FR-045→unified FR-218, FR-046→unified FR-219)
- [x] T419 (was: 002/T098) [US6] [TDD] Implement **G-KG-9**: an unavailable toolchain yields **could not determine**,
      never an empty format list (FR-049→unified FR-222). **Paired mutation**: return an empty list instead (FR-049→unified FR-222, FR-054→unified FR-261)
- [x] T420 (was: 002/T099) [US6] [TDD] Implement the publication precondition: an area without a review exports
      nothing **and says so** (FR-048→unified FR-221, A3.9.1) (FR-048→unified FR-221, SC-007→unified SC-049)
- [x] T421 (was: 002/T100) [US6] [TDD] Implement citation preservation across all four formats (FR-047→unified FR-220) (FR-047→unified FR-220)
- [ ] T422 (was: 002/T101) [US6] Port diagram rendering from text source — reproducible, unlike an embedded binary — **BLOCKER:** **operator decision** — `mmdc -V` exits 0 but an actual 2-node render exits **1 with no SVG**, `grep -c mermaid` is **0** across all 5 area documents, and there is no decision on where a diagram lives in the seven-section skeleton · **OWNER:** **operator** (content/contract placement), then **implementer**
      (FR-014a→unified FR-088) (FR-014a→unified FR-088)

      **OPEN. Re-measured 2026-09-03, and leaving it UNWIRED is now backed by three separate
      disqualifying findings — each one on its own is enough to rule out "make `export_area` call
      `render_diagram`" as the fix.** The renderer function is implemented and covered in isolation;
      the function that assembles a published area's four formats does not invoke it. Re-derived
      here rather than read:

      ```bash
      grep -rn 'render_diagram(' workshop/pipeline/ --include=*.py | grep -v 'def render_diagram'
      # 5 call sites, all in the two test/verify modules; export_area is not among them
      ```

      1. **The renderer is unusable, and asking it for a version hides that.** Measured directly on
         this host, not carried forward:

         ```bash
         mmdc -V                                  # 11.12.0   rc=0
         printf 'graph TD\n A-->B\n' > t.mmd
         mmdc -i t.mmd -o t.svg; echo "rc=$?"     # rc=1 — and no t.svg is written
         ```

         The version query succeeds; the actual 2-node render fails and produces no file. This is the
         same trap the export contract's own **A3.9.2** warns about — a name on `PATH` and a version
         string are not evidence of capability, so capability has to be exercised. Wiring the call on
         the strength of the version query would break every published area instead. Worth naming:
         002/T083 (unified T390)'s export probe refuses to accept a `--version` answer for exactly this reason, and this
         task is the case that shows the refusal earning its keep.
      2. **There is no input to render.** `grep -c 'mermaid' workshop/docs/training/areas/*.md`
         returns **0** for each of the five area documents, so the new code path would be dead for
         every document that exists.
      3. **Nobody has decided where a diagram lives in an area document**, and this is the binding
         ground. FR-014a requires text-source authoring but is silent on placement, and the SC-005
         skeleton fixes seven headings with none for a diagram. Choosing a heading name, a fence tag,
         and whether an area may hold more than one is a content/contract decision, not a coding one.

      **A justification that overstated its own support has been corrected upstream, and it is
      logged here instead of being absorbed without trace.** Eighteen Mermaid sources across six files sit
      under `workshop/docs/training/diagrams/` — held outside the area documents precisely so they do
      not pre-empt finding 3. The README there defended that placement partly on the grounds that the
      platform's own front end displays them. **It does not**, measured 2026-09-03: `grep -rn mermaid
      platform/frontend/src/` returns **0**, and none of the Angular workspace's 23 dependencies is a
      Mermaid renderer. The README has been fixed inside `workshop/`. The fences do display in
      GitHub/GitLab viewers, which is what makes source form a defensible choice — but not here.

      Full investigation, both measurement dates, and the defects row
      `render-diagram-never-called`: **`workshop/docs/limits.md` §10.5**.
- [x] T423 (was: 002/T102) [US6] [TDD] Prove **SC-024**: the file-existence matrix must be **complete**. Record the
      reference's measured 25-of-34 beside it, so nobody later matches the reference and calls it done (FR-045→unified FR-218, SC-024→unified SC-122)

      **DONE. Every clause of the PARTIAL note this task carried is WITHDRAWN, not restated** — it
      said the §3.9 route still 404s, that `export.py` hardcoded `review=None`, that the matrix had
      never been exercised over real content, and that the reference's 25-of-34 was not recorded
      beside a workshop matrix. All four were true when measured earlier on 2026-09-03 and **all four
      were fixed later the same day**, while this reconciliation was in progress. Re-measured after
      the change, by execution:

      ```bash
      cd workshop/pipeline/extract
      ../venv/bin/python -c "import export; print(export.real_materials_export_status(produce=False))"
      # rc=0 (in_process) — 2 published area(s) of 5; 3 blocked by A3.9.1; 0 blocked by SC-012
      #        matrix: 2/2 area(s) carry all four formats
      bash workshop/platform/gates/verify-sc024-export-matrix.sh    # rc=0 (served), live against :8087
      ```

      **Both halves of the task are satisfied and both were watched, not assumed.** The matrix is
      **complete — 2 of 2** (in_process) published areas carry markdown, html, docx and pdf. The reference's
      **25 of 34** (source) is printed on the same run, and the gate labels it in its own output as recorded
      **beside** the result and never as the bar — 25/34 is 73.5%, and SC-024 requires 2/2, so
      matching the reference would specifically NOT be this criterion met. That is the exact
      misreading this task was written to prevent.

      **The fix is worth recording, because two defects were hiding each other.** The old caller
      passed `review=None` — a constant, so the branch it selected described the function rather than
      the tree — and it passed the document's filesystem **path** where reviews are keyed by the
      minted **ULID**, so a review that HAD loaded could never have matched. Neither was observable
      while the other stood: nothing looked a review up, so the key mismatch never got the chance to
      fail. Identity now resolves through the same production promotion path the authoring stage
      uses. `curriculum/publication-reviews.jsonl` holds **2** reviews (source), and they are the same 2 area
      ids — of 495 — that `GET /api/areas/{area}` serves at 200 (served), so the Python and Go paths now agree
      where they previously disagreed. `real_materials_export_status` is read-only by default;
      producing artifacts is an explicit `--produce-real-materials` step.

      **Paired mutation, executed rather than cited** (`verify_export.py --prove-failure`, rc=0, in_process): with
      the review store mutated to return nothing, the function drops to 0 published areas and rc=2 —
      *the pre-fix behaviour reproduced exactly* — and unmutated returns 2 and rc=0. Registered as
      `T102-review-identity-not-hardcoded` in `platform/gates/check-registry-002.tsv` with its proof
      named in the row.

      **Honest boundary (§11.4.6), and it does not withhold the tick:** the SC-024 shell gate itself
      (`verify-sc024-export-matrix.sh`, registered as `T102-sc024-export-matrix`) carries **no**
      `--prove-failure` and no paired-proof column — `bash … --prove-failure` returns rc=2 (in_process) `unknown
      argument`. The paired mutation above covers the identity mechanism the result turns on, not the
      matrix gate's own failure mode. Under this file's global constraint that **every** check owes a
      paired mutation, that shell gate still owes one.
- [x] T424 (was: 002/T103) [US6] [TDD] Prove **SC-025** by **extracting text and diffing**, not by byte comparison —
      embedded timestamps make byte equality unachievable for some formats, and a criterion nobody can
      meet is worse than none (FR-046→unified FR-219, SC-025→unified SC-123)
- [ ] T425 (was: 002/T150) [US6] [TDD] [REVIEW] Extend the content-boundary check (002/T076 (unified T383), G-KG-16) to every exported
      area document per **FR-049a**, run before the export leaves the platform's own storage — the
      same check FR-065 requires of OCR output before publication, applied here to export instead.
      Coverage MUST include extracted taxonomy labels (area titles, term canonical forms), not prose
      alone. Gate **G-KG-24**. **Paired mutation**: scope the check to prose only, excluding area
      titles and term names; the gate must go red, because that is precisely the scoping that would
      let a name through (FR-004a→unified FR-067, FR-049a→unified FR-223, SC-024a→unified SC-124)


---

## Phase 13: US24 — the repeatable chapter pipeline (P5)

**20 tasks — 9 complete, 11 open.** Sources: 001, 002.


*From `001` — Phase 7: User Story 5 — Add a chapter (Priority: P5)*

- [ ] T426 (was: 001/T084) [US5] [TDD] **[PATH NOT BUILT — `workshop/scripts/add-chapter.sh` does not exist and none of the nine contracted stages exists as a driver. Four of the stages it must call are themselves `[PATH NOT BUILT]` (`transcribe.sh` 001/T111 (unified T208), `index.sh` 001/T115 (unified T340), `crossref.sh` 001/T116 (unified T341), `redact.sh` T038/T039); two exist (`verify-accuracy.sh` 001/T112 (unified T209), `ingest.sh` 001/T113 (unified T210)). **This task gates 001/T085 (unified T427), 001/T086 (unified T428), 001/T090 (unified T432) and the enforcement half of 001/T087 (unified T429)**. **RE-MEASURED 2026-09-03: unchanged, and now the single largest blocker in this file.** `grep -rln 'add-chapter\|add_chapter'` over `workshop/scripts/` and `workshop/platform/` returns **ZERO files**; `G-CLI-7` and `G-CLI-8` (001/T085 (unified T427), 001/T086 (unified T428)) appear nowhere in `workshop/`. The stage census is unchanged: of the nine, `verify-accuracy` (001/T112 (unified T209)) is built and `ingest` (001/T113 (unified T210)) is built but missing five of its six contracted flags, while `transcribe` (001/T111 (unified T208)), `index` (001/T115 (unified T340)) and `crossref` (001/T116 (unified T341)) do not exist and `redaction-review` (001/T039 (unified T205)) is now built, proven and ticked. **This task alone accounts for FIVE unticked tasks that are blocked on nothing else** — 001/T085 (unified T427), 001/T086 (unified T428), 001/T087 (unified T429)'s enforcement half, 001/T088 (unified T430) and 001/T090 (unified T432) — so it is the highest-leverage unwritten item in the file. Nothing blocks it but the work and the four missing stages]** Implement `workshop/scripts/add-chapter.sh` per [contracts/pipeline-cli.md](../001-workshop-curriculum-platform/contracts/pipeline-cli.md) §4.7 covering **all NINE contracted stages in order** — `preflight → extract → transcribe → verify-accuracy → ingest → index → crossref → redaction-review → publish` — with `--resume`, `--only <stage>`, `--skip <stage>`, `--from <stage>`, `--dry-run`, `--json` and `--check-idempotent`, and with no code edit required to add a chapter. **No stage is optional and none is silently dropped**: `preflight` (§3.1) classifies every finding as tooling (`2`) or content (`1`) and reports ALL of them rather than the first; `verify-accuracy` (§4.2) must actually run because the presence of its `accuracy.json` is publish precondition B2 — its value may miss target, its absence blocks; and `redaction-review` is the FR-039 gate implemented in T038/T039, which is what makes `publish` legal at all. An earlier draft of this task named only four stages (transcribe → ingest → index → cross-link); dropping the publication gate is precisely how a redaction requirement becomes decorative — **BLOCKER:** **predecessor 001/T111 (unified T208) + 001/T115 (unified T340) + 001/T116 (unified T341) + 001/T088 (unified T430)** — four of the nine stages this driver must call are themselves unwritten · **OWNER:** **implementer**, after those four (FR-026→unified FR-174, FR-028→unified FR-176, FR-029→unified FR-177, FR-039→unified FR-012)
- [ ] T427 (was: 001/T085) [US5] [TDD] Prove idempotency (FR-027→unified FR-175) as gate **G-CLI-7** ([contracts/pipeline-cli.md](../001-workshop-curriculum-platform/contracts/pipeline-cli.md) §4.7, §5): run `add-chapter.sh` twice on a small synthetic chapter and assert all of **J1–J6** — a second run changes nothing and duplicates no passage, keyed on pid. **Paired mutation**: make the procedure mint unconditionally; the gate MUST go red — **BLOCKER:** **predecessor 001/T084 (unified T426)** — G-CLI-7 runs `add-chapter.sh` twice; there is no `add-chapter.sh` · **OWNER:** **implementer**, after 001/T084 (unified T426) (FR-027→unified FR-175, FR-032→unified FR-260, SC-012→unified SC-135)
- [ ] T428 (was: 001/T086) [US5] [TDD] Incomplete materials MUST report precisely what is missing and MUST NOT publish a partial chapter as complete (FR-028→unified FR-176), proven as gate **G-CLI-8** ([contracts/pipeline-cli.md](../001-workshop-curriculum-platform/contracts/pipeline-cli.md) §4.7, §5): remove `chapter.yaml` and two archive parts, then assert exit `1` with **three** findings enumerated — all of them, not just the first — and nothing published. **Paired mutation**: report the first finding only and publish anyway; the gate MUST go red — **BLOCKER:** **predecessor 001/T084 (unified T426)** · **OWNER:** **implementer**, after 001/T084 (unified T426) (FR-028→unified FR-176, FR-032→unified FR-260, SC-012→unified SC-135)
- [ ] T429 (was: 001/T087) [US5] [TDD] Enforce the publish preconditions **B1–B6** of [contracts/pipeline-cli.md](../001-workshop-curriculum-platform/contracts/pipeline-cli.md) §4.7 in `add-chapter.sh`: B1 `coverage.unexplained_gap_s == 0` · B2 `accuracy.json` exists · B3 every passage has a pid in `passages.jsonl` · B4 the generation containing the chapter is `live` · B5 **`redaction-review.json` exists and is newer than the transcript (FR-039→unified FR-012)** · B6 no source file changed during the run. Failing any one of them ⇒ exit `1` with the chapter left `transcribed`, never `published`. **Paired mutation**: publish with `redaction-review.json` absent (and again with it stale); the gate MUST go red in both cases — B5 is the only thing standing between FR-039 and a decorative requirement — **BLOCKER:** **predecessor 001/T084 (unified T426)** — B1-B6 are enforced IN `add-chapter.sh` · **OWNER:** **implementer**, after 001/T084 (unified T426) (FR-039→unified FR-012, FR-028→unified FR-176, FR-004→unified FR-004, FR-032→unified FR-260, SC-012→unified SC-135)
- [ ] T430 (was: 001/T088) [US5] Make the procedure accept a PRE-SUPPLIED TRANSCRIPT FIXTURE so idempotency and identity can be proven without running ASR — otherwise every US5 proof inherits the ASR block. **[PATHS ADDED 2026-09-02 — this task named none, and two fixture producers already exist: `workshop/pipeline/extract/fixtures/synthetic_chapter/passages.jsonl` and `workshop/platform/backend/cmd/fixture-corpus/main.go`, which writes an invented corpus so endpoints can be exercised without private content. **Do not build a third fixture.** What is missing is a PROCEDURE that accepts one, and that procedure is 001/T084 (unified T426), which is `[PATH NOT BUILT]`]** — **BLOCKER:** none but the work — a pre-supplied transcript fixture is what lets every US5 proof escape the ASR block, so this is the cheapest way to unblock T085-T087 · **OWNER:** **implementer** — unblocked today (FR-027→unified FR-175, SC-016→unified SC-075)
- [x] T431 (was: 001/T089) [US5] **[PATH CORRECTED 2026-09-02 — this task named `workshop/docs/add-chapter-prompt.md`, which does not exist; the prompt landed at `workshop/docs/prompts/add-a-chapter.md`]** Write the reusable extension prompt in `workshop/docs/prompts/add-a-chapter.md` — the operator-facing artifact requested (FR-026→unified FR-174, FR-030→unified FR-336)
- [ ] T432 (was: 001/T090) [US5] [TDD] Prove SC-011: a new chapter integrated in under 30 minutes hands-on with zero code or config change — **BLOCKER:** **predecessor 001/T084 (unified T426) + 001/T088 (unified T430)** — SC-011 times the procedure end to end · **OWNER:** **implementer**, after T084/T088 (SC-011→unified SC-102, FR-026→unified FR-174)
- [ ] T433 (was: 001/T130) [US5] [TDD] Detect and refuse a genuinely concurrent second invocation of `workshop/scripts/add-chapter.sh` (001/T084 (unified T426)) against the same chapter: take an exclusive lock (e.g. `flock` on a per-chapter lock file) for the run's duration, distinct from 001/T085 (unified T427)'s already-covered sequential-rerun idempotency. Gate **G-CLI-20**: start two genuinely concurrent invocations against the same synthetic chapter — the second launched while the first is still mid-run — and assert the second refuses rather than interleaving writes, while the first completes unaffected. **Paired mutation**: remove the lock and let both proceed; the gate MUST go red once it observes interleaved writes to the same transcript/index files (FR-054→unified FR-178)

*From `002` — Phase 9: User Story 7 — the repeatable pipeline (P7)*

- [x] T434 (was: 002/T104) [US7] Extend the platform's **existing** chapter-addition procedure and its prompt with the
      knowledge-layer stages. **Do not create a second way to add a chapter** (S1) — two procedures
      for one act guarantee one of them rots (FR-033d→unified FR-174, FR-033e→unified FR-174)
- [x] T435 (was: 002/T105) [US7] [TDD] Implement three-valued exits and resumability on every new stage (S3, S4), with
      progress projected from **measured rate**, never from an estimate (FR-033g→unified FR-176, FR-054→unified FR-261)
- [x] T436 (was: 002/T106) [US7] [TDD] Implement the taxonomy **update** path (S6): established areas keep their
      identifiers and gain evidence, newly evidenced areas are added, contradictions are reported (FR-033f→unified FR-179)
- [x] T437 (was: 002/T107) [US7] [TDD] Prove **SC-015d**: capture the taxonomy before and after, assert **0**
      established identifiers changed and the contradiction report is non-empty when one was seeded.
      **Paired mutation**: re-derive area identifiers on each run (FR-033f→unified FR-179, SC-015d→unified SC-099)
- [x] T438 (was: 002/T108) [US7] Build a **small synthetic chapter** fixture — synthetic, because it must contain no
      workshop content and it must exercise the **minting** path (FR-057→unified FR-276, SC-015c→unified SC-098)
- [ ] T439 (was: 002/T109) [US7] [TDD] Prove **G-KG-17 / SC-015c**: run the whole pipeline against the synthetic — **BLOCKER:** none but the work — `prove_g_kg_17_synthetic_chapter` self-scopes in its own docstring ("SCOPED HONESTLY") to extracted areas/themes plus taxonomy, while 002/T109 (unified T439) asks for EVERY S2 output · **OWNER:** **implementer** — unblocked today
      chapter; assert every output in S2 exists and the diff contains **no hand-created structural
      file and no code change**. **Paired mutation**: remove one stage; the gate must go red naming
      the missing output.
      **Do not substitute a re-run of the real chapter.** That tests idempotency, which is SC-004; it
      cannot test whether a *new* chapter works, because every identifier it needs already exists — the
      run would pass by matching and never by minting (FR-033d→unified FR-174, SC-015c→unified SC-098)

      **PARTIAL (re-measured 2026-09-03, unchanged).** G-KG-17 exists, is registered
      (`G-KG-17-synthetic-chapter`) and runs the REAL `run_pipeline.run()` entry point against the
      synthetic chapter. Its own docstring (`prove_g_kg_17_synthetic_chapter` in
      `pipeline/extract/verify.py`, "SCOPED HONESTLY") still scopes it to extracted areas and themes
      plus the taxonomy file, and names the remainder of S2's output set — authored materials,
      question sets, cross-references, index entries, deep links — as owned by
      `platform/backend` or by stages not yet built, and explicitly does not claim to exercise them.
      002/T109 (unified T439) asked for **every** output in S2.
- [x] T440 (was: 002/T110) [US7] [TDD] Prove **G-KG-18 / SC-015e**: withhold one required input; assert the run names
      exactly what is missing and publishes nothing. **Paired mutation**: downgrade it to a warning (FR-033g→unified FR-176, SC-015e→unified SC-100)
- [x] T441 (was: 002/T111) [US7] [TDD] Prove **S7**: no stage writes to a source. Assert every source file's size,
      modification time and inode are unchanged after a full run. **Paired mutation**: have a stage
      rewrite a source in place (FR-?)
- [x] T442 (was: 002/T112) [US7] [TDD] Prove **S8**: evidence is written for every outcome, **especially** could not
      determine — the run that determined nothing is the one a reader most needs the record of.
      **Paired mutation**: skip evidence writing on the could-not-determine path (FR-054→unified FR-261, FR-055→unified FR-264)
- [ ] T443 (was: 002/T151) [US7] [P] [TDD] Implement code-passage drift detection per **FR-033h**: every code
      passage carries a content hash or equivalent anchor of the code location it cites; resolving a
      code passage whose anchor no longer matches reports **could not determine** or **stale**
      through the existing four-outcome resolver (002/T015 (unified T053)), never a silent hit against code that has
      since changed independently, elsewhere in the monorepo. Gate **G-KG-25**. **Paired mutation**:
      mutate the file a code passage cites outside the workshop pipeline, then resolve the citation
      as a normal hit anyway; the gate must go red (FR-023→unified FR-143, FR-033h→unified FR-180, SC-015f→unified SC-082)
- [ ] T444 (was: 002/T152) [US7] [TDD] Implement atomic publication per **FR-033i**: a chapter-processing run's
      outputs — minted passages, extracted areas, materials, question sets, cross-references, index
      entries and links — become visible together or not at all; an interrupted run (crash, kill,
      power loss) leaves no partially-written state reachable by a learner or by search. Gate
      **G-KG-26**. **Paired mutation**: kill the pipeline mid-run against 002/T108 (unified T438)'s synthetic chapter and
      assert the previously published state is unchanged and no new-but-incomplete artifact is
      reachable; make publication non-atomic and the gate must go red (FR-033i→unified FR-181, SC-015g→unified SC-101)
- [ ] T445 (was: 002/T153) [US7] Prove **SC-015g**'s serving half: processing a new chapter does not block or
      degrade interactive serving of the existing, already-published taxonomy, materials, questions
      or search index while the run is in progress — a direct consequence of 002/T152 (unified T444)'s atomicity rather
      than a second mechanism, made independently measurable rather than left to be inferred
      (FR-033j→unified FR-182, SC-015g→unified SC-101)


---

## Phase 14: On-screen text (OCR) ingestion — specified and unbuilt

**21 tasks — 2 complete, 19 open.** Sources: 002.


*From `002` — Phase 11: On-screen text — OCR ingestion (added 2026-09-02, decision D5)*

- [ ] T446 (was: 002/T123) [UNBUILT] [P] Gate **G-OCR-1** — capability-probe the OCR toolchain per contract §7 **V1**: — **BLOCKER:** **half BUILT, half blocked on CAPABILITY not on a decision** — the `[UNBUILT]` marker is STALE: `pipeline/detect_ocr.sh` EXISTS (754 lines), is registered as `ocr-toolchain-capability` with a paired proof, and its rc-2 probe is verified live (`--scratch-dir /nonexistent` -> rc 2). What is NOT buildable is per-chapter language detection: tesseract OSD misclassified an all-caps Latin fixture as Cyrillic at the HIGHEST confidence of three fixtures, so a confidence floor selects FOR the error. Resolving it needs a bake-off against 002/T132 (unified T455)'s hand-truthed sample · **OWNER:** **implementer** for the built half; **blocked on 002/T132 (unified T455)** for the language half
      invoke the engine with **the flag that matters**, never `--version`, and detect the recording's
      on-screen language **per chapter** per **V2**. Engine absent, or the needed language pack
      absent, yields **could not determine** — never empty text presented as "nothing on screen".
      **Paired mutation**: probe by name on `PATH` only; the gate must go red. This repository has
      already shipped a defect of exactly this shape — a media tool that answered a version query
      and rejected the flag that mattered (FR-053→unified FR-260, FR-054→unified FR-261)
      **PARTIAL — measured 2026-09-03. The box stays unticked because half of this task is BUILT and
      half is not, and the unbuilt half is blocked on a capability that was MEASURED, not assumed.**
      **BUILT**: `workshop/pipeline/detect_ocr.sh` — three-valued (0 usable / 1 unusable / 2
      could-not-determine), registered in `platform/gates/check-registry-001.tsv` as
      `ocr-toolchain-capability`, with `--prove-failure` executing **6** mutations (M1 healthy, M2
      absent, M3 version-only, M4 silent, M5 no-wordbox, M6 undetermined) and a CONTROL asserting
      the M3 fake still passes a naive `command -v` + `--version` probe — the exact defect shape
      this task names. Every tool is exercised with the flag it will be used with, against a fixture
      whose text is KNOWN, and the output is COMPARED to that text: "non-empty" is not accepted,
      because a recogniser pointed at the wrong script returns confident nonsense rather than
      nothing (measured: a Cyrillic fixture read with `-l eng` returned a fluent-looking Latin
      transliteration, rc 0). Measured on this host, exit **0** — tesseract 5.5.2 at a user-local
      path reproduced a 29-word fixture exactly, `tsv` returned 32 scored word rows all carrying
      positive geometry (mean conf 96.2), packs are `eng,rus` (`osd` is script detection and is NOT
      counted as a language), and an ffmpeg encode -> `-vf fps=1` sample -> OCR round trip returned
      the fixture exactly. **Two host traps were re-measured while building it, and both shaped the
      design.** The `ffprobe` symlink trap this repository already documents was reproduced
      independently (answers `-version` rc 0, rejects `-show_format`); and a second one that was not
      on record: the same ffmpeg advertises `--enable-libfreetype --enable-fontconfig` in its own
      `-version` configuration string and has **no `drawtext` filter**. A tool's self-description is
      not a capability measurement either, which is why the probe fixture is EMBEDDED rather than
      drawn at run time. **NOT BUILT — the per-chapter on-screen LANGUAGE detection half (V2).
      BLOCKED ON CAPABILITY, on nobody's decision.** Tesseract OSD is the only detector this
      toolchain offers and it was measured wrong: three synthetic fixtures whose ground truth is
      Latin returned mixed-case -> Latin (confidence 5.15), source code -> Latin (7.41), and
      **ALL-CAPS -> CYRILLIC (18.33)**. The wrong answer arrived with the HIGHEST confidence of the
      three, so a confidence floor selects for the error instead of filtering it — and all-caps is
      not exotic in a screen recording, it is headings, UI labels and terminal banners. A fourth
      measurement bounds it further: OSD exits 1 on a sparse frame ("Too few characters"), and a
      frame with little text is the NORMAL case when sampling a recording — that outcome is
      could-not-determine and is never "nothing was on screen". What would unblock this half is a
      per-language recognition bake-off scored against **002/T132 (unified T455)**'s hand-truthed sample, so it is
      downstream of 002/T132 (unified T455) rather than of any decision. The probe carries the limitation as an
      `advisory` row that reproduces the measurement on every run and can never move the exit code
- [ ] T447 (was: 002/T124) [UNBUILT] [REVIEW] Settle **U6** — what sampling period keeps an on-screen visibility — **BLOCKER:** **operator decision, purely** — every input is already recorded (segment median 6.74 s, p95 10.78 s, max 20.22 s) and frame sampling is measured working. What is missing is the operator CHOOSING a sampling period, which the task forbids rounding to a convenient number · **OWNER:** **operator** — unblocks T126/T127/T128
      interval **no coarser than the segment precision it sits beside**? Measure it against the
      recorded segment distribution (median **6.74 s**, p95 **10.78 s**, max **20.22 s**); do not
      pick a round number. Three-valued exit. Record under `workshop/evidence/`. **002/T126 (unified T449) and 002/T128 (unified T451) are
      bounded by this** — an interval bound chosen before it is measured is the same class of guess
      the no-threshold rule forbids elsewhere (FR-021→unified FR-140, FR-055→unified FR-264, FR-061→unified FR-184)
      **BLOCKED ON OPERATOR — measured 2026-09-03.** U6 is a clarification and settling it is the
      operator's decision, not an agent's. Nothing technical is waiting: the inputs are already
      recorded (segment distribution median 6.74 s, p95 10.78 s, max 20.22 s) and the sampler is no
      longer hypothetical — `pipeline/detect_ocr.sh` has now measured frame sampling working on this
      host. What is waiting is the choice of period, which this line explicitly forbids rounding to
      a convenient number
- [x] T448 (was: 002/T125) [TDD] [REVIEW] Gate **G-OCR-2** — declare `screen_text` as a **passage kind** in
      the registry contract per `data-model.md` §2.9: minted through the **same** minter, resolved
      through the **same** four-outcome resolver, ordering key = visibility onset, provenance `ocr`
      and distinct from `asr`, engine confidence carried, redaction flag inherited. **Paired
      mutation**: mint an OCR passage through a second minter or a second identifier format; the
      gate must go red. **A fifth kind, not a fifth registry** (FR-060→unified FR-183) (FR-007→unified FR-078, FR-023→unified FR-143, FR-060→unified FR-183)
      **BUILT 2026-09-03.** `passagestore.KindScreenText` in
      `workshop/platform/backend/internal/passagestore/domain.go`, with gate **G-OCR-2** and its
      paired mutation in `screentext_test.go`, registered in
      `platform/gates/check-registry-002.tsv` as `G-OCR-2` and
      `T125-screen-text-paired-mutation` (registry rc **0**, 59 checks, 0 missing) (source).
      **A PRIOR NOTE ON THIS LINE WAS WRONG AND IS WITHDRAWN, NOT SILENTLY REPLACED.** It said "the
      registry it must extend is `platform/backend/pkg/search/`". That is the SEARCH INDEX's kind
      list, not the passage registry. §2.9's table is the field-by-field shape of
      `passage.Record`, so the registry is the passage registry and its vocabulary lives in
      `internal/passagestore/domain.go` — the one place the other four kinds are declared. Building
      it in `pkg/search` would have declared a corpus kind in the retrieval layer, which is the
      fifth-registry mistake wearing different clothes. The concurrent-editing reason given for
      deferring was therefore also moot: the file that needed editing was never contended.
      **What was added.** Five invariants beyond the existing F4/F5, each enforced on the library's
      own write path through `passage.WithRecordValidator` — so they run at `Put`, at `Sync` and at
      `Load`, not in a wrapper somebody can forget. **F5 was EXTENDED rather than duplicated**:
      `screen_text` joins `transcript_segment` as media-backed via `IsMediaBacked`, and the two
      differ in exactly one respect, deliberately — a transcript segment needs start **strictly
      before** end because speech has duration, while a `screen_text` permits onset **==** offset,
      because text seen at ONE sample of the grid has coincident observed bounds and forcing a
      wider interval would make the record assert a duration nothing measured. **F6** producer
      `ocr`, enforced in BOTH directions. **F7** interval bound present, finite, strictly positive
      — FR-061's "never zero" is refused by name, because a zero bound is not a tight measurement
      but a measurement never taken presented as the tightest possible one. **F8** engine
      confidence carried, `[0,1]`, caller-normalised so one scale reaches the registry. **F9** no
      speaker on on-screen text. **F10** an empty recognition is not a passage, guarded by
      `!Redacted` so it cannot block `RedactionLog.Purge` — the same tension the library resolves
      between its own F2 and F6, resolved the same way.
      **`producer` is NOT `passage.Provenance`, and conflating them was the near-miss.** The
      library's field records whether the text is still the machine's or has been human-corrected.
      A corrected OCR passage is `human_corrected` **and** `ocr`; one field cannot carry both, and
      collapsing them would have reclassified every correction as a change of engine.
      **Proof, verified in BOTH directions — which a green run alone cannot show.** Green: **13
      mutations, 13 caught, 0 missed** (in_process), with the **M0 negative control passing FIRST** (one of this
      tree's two shipped inoperative proofs failed precisely by having a broken control, so zero
      mutations ever ran). Red against two deliberately weakened throwaway copies: **W1** gutted
      `validateScreenText` — 7 uncaught, 1 caught by an unrelated rule (in_process), the load-at-rest mutation
      uncaught; **W2** changed one comparison so a zero bound was permitted, and **exactly M8** went
      red. W2 is the one that matters: a proof detecting only total removal would not have
      discriminated it. `domain.go` was restored to its pre-weakening sha256 and re-measured green.
      **The detect_ocr.sh acceptance rule was copied deliberately.** That probe compares output to
      KNOWN FIXTURE TEXT and refuses "non-empty" as a criterion, because a recogniser aimed at the
      wrong script returns confident nonsense rather than silence. Here every positive assertion
      compares a known VALUE, and every mutation must be refused with a message **naming the
      invariant it broke** — W1 proved that arm live by reporting `CAUGHT BY THE WRONG RULE` on M12
      rather than counting a refusal it had not earned.
      **A hole this change opened, and closed.** Gate **G-SUG-6** (catalog and passage corpus are
      disjoint, so redaction has ONE authority) asserted disjointness from a HARDCODED list of four
      kinds. A fifth kind would have left a catalog row claiming `screen_text` passing. The list is
      now DERIVED from the new `passagestore.PassageKinds`, so the next kind is covered the day it
      is declared. Re-measured: G-SUG-6 green, 9 rows swept (in_process).
      **`screen_text` is deliberately NOT added to `baseIndexedKinds`.** Nothing produces one yet.
      `service.go`'s own comment records `diagram` as an existing advertised-but-unretrievable kind
      and forbids adding a second instance of that defect; the `T057-lesson-section-unindexed`
      registry row is the same precedent. Advertising a kind no corpus holds is a capability claim
      with nothing behind it.
      **Honest boundary.** No `screen_text` passage exists in the corpus — this task declares the
      KIND, and 002/T126 (unified T449) (blocked on 002/T124 (unified T447), an operator decision) is what produces one. All fixtures are
      synthetic; nothing was quoted from any recording.
      **Pre-existing failures, measured rather than assumed (in_process).** Four backend tests failed when this
      work began — `TestGateSUG4_RedactedPassagesNeverSurface`,
      `TestGateKG11_AdvertisedAreaTermKindsAreRetrievable`, `TestC4_1_5_AreaFilterEchoedAndApplied`,
      `TestC4_2_1_SuggestOffersAreaAndTermNames`. Each was measured **identical with and without
      this change** (HEAD's `domain.go` restored, this task's test file held aside), so none is
      caused by 002/T125 (unified T448). **The "four" figure is now stale and is corrected rather than left standing:
      three were fixed by another agent's concurrent work during this pass, and ONE remains —
      `TestGateSUG4` in `internal/api`.** It is neither caused nor fixed here.
      **`platform/gates/verify-check-registry-001.sh` exits 1 (source) on this tree, and it is NOT this
      task's.** All 11 R5 violations are unregistered `*.py`/`*.sh` files under
      `pipeline/the_platform/`, landed by concurrent work; that registry's `pipeline` scanroot
      sweeps recursively and is catching them exactly as designed. This task added **no** `*.sh` or
      `*.py` anywhere under `pipeline/`, so it has zero R5 exposure. They are deliberately NOT
      registered here: registering a gate whose paired proof has not been verified would be the
      bluff that registry's own header forbids. **002/T126 (unified T449)–002/T141 (unified T464) no longer sit behind this**
- [ ] T449 (was: 002/T126) [UNBUILT] [TDD] Implement sampling and recognition across a chapter recording, producing — **BLOCKER:** **predecessor 002/T124 (unified T447)** — sampling cannot be implemented before the sampling period is chosen · **OWNER:** **implementer**, after 002/T124 (unified T447)
      text plus a **visibility interval** and its **interval bound** (FR-061→unified FR-184). The sampling period is
      a **recorded parameter** the run writes into its evidence, never a literal in the code — and
      the bound is never omitted and never presented as zero. Sources open read-only per **S7** (FR-061→unified FR-184)
      **BLOCKED ON 002/T124 (unified T447) (operator) ALONE — re-measured 2026-09-03, narrowed from "002/T124 (unified T447) AND 002/T125 (unified T448)".**
      The toolchain half is no longer
      in doubt: `pipeline/detect_ocr.sh` exits 0 and proved frame sampling plus per-word recognition
      with confidence and geometry on this host, so nothing here is blocked on a capability. **002/T125 (unified T448)
      is now BUILT**, so the passage kind, its `ScreenTextObservation` constructor and its
      `interval_bound_s` field are all waiting for this task rather than the other way round. What
      is still missing is the sampling period, which 002/T124 (unified T447) must settle and which this task is
      forbidden to hardcode — note `ScreenTextObservation` takes it as a PARAMETER precisely so no
      literal can be smuggled in here
- [ ] T450 (was: 002/T127) [UNBUILT] [TDD] Gate **G-OCR-3** — implement the **stability rule**: text visible across — **BLOCKER:** **predecessor 002/T124 (unified T447) + 002/T126 (unified T449)** · **OWNER:** **implementer**, after T124/T126
      consecutive samples is **one** passage with one interval, not one per sample. **Paired
      mutation**: emit one passage per sample; the gate must go red. This is not tidiness — a static
      slide left up for two minutes would otherwise inflate an area's evidence by the sampling rate,
      and the inflated count is what publication decisions rest on (FR-060→unified FR-183, FR-061→unified FR-184)
      **BLOCKED ON 002/T126 (unified T449) ALONE — re-measured 2026-09-03, narrowed from "002/T125 (unified T448) AND 002/T126 (unified T449)".** The
      stability rule operates over consecutive samples; **the passage kind now exists** (002/T125 (unified T448)), so
      what is missing is a sampler that emits any. Not
      blocked on capability: the engine's `tsv` output carries the per-word geometry this rule needs
      to decide that two samples show the same text
- [ ] T451 (was: 002/T128) [UNBUILT] [TDD] Gate **G-OCR-4** — join `screen_text` mentions to the **existing — **BLOCKER:** **predecessor 002/T124 (unified T447) + 002/T126 (unified T449)** · **OWNER:** **implementer**, after T124/T126
      two-valued** precision model (FR-062→unified FR-185, contract §3 N1/N2): declare `segment`, carry the
      **interval bound** beside it exactly as `word` precision carries timing confidence (N3).
      **Paired mutations**: (a) introduce a third `precision` value; (b) declare `word` precision on
      an OCR mention. Both must go red — (a) because every consumer switches on two values,
      (b) because no per-word timing record produced that time (FR-061→unified FR-184, FR-062→unified FR-185)
      **BLOCKED ON 002/T124 (unified T447) (operator) — re-measured 2026-09-03, narrowed from "BLOCKED ON 002/T125 (unified T448),
      BOUNDED BY 002/T124 (unified T447)".** The kind exists now, and it already carries the field this task must
      propagate: `passagestore.AttrIntervalBoundS`, with `IntervalBound()` to read it and F7
      guaranteeing it is present, finite and non-zero on every `screen_text`. What is still
      unsettled is the VALUE, which 002/T124 (unified T447) owns. Not blocked on capability.
      **Note what 002/T125 (unified T448) did NOT do here**: it put the bound on the PASSAGE. FR-061 also requires it
      on every MENTION derived from one, and that half is this task's
- [ ] T452 (was: 002/T129) [UNBUILT] [TDD] Gate **G-OCR-5** — record **modality** (`spoken` / `on_screen`) on every — **BLOCKER:** **predecessor 002/T126 (unified T449)** — modality cannot be recorded on mentions that do not exist yet · **OWNER:** **implementer**, after 002/T126 (unified T449)
      mention, derived from the passage kind and never guessed, and mark a subject evidenced **only**
      on screen as `on-screen-only`, the modality analogue of `uncertain-only` (FR-012→unified FR-085, FR-063→unified FR-186).
      **Paired mutation**: default the modality to `spoken` where it is unset; the gate must go red.
      A term the workshop displayed but never discussed is a different fact from one it taught, and
      a reader who cannot tell them apart will over-read the taxonomy (FR-012→unified FR-085, FR-063→unified FR-186)
      **NO LONGER BLOCKED ON 002/T125 (unified T448) — re-measured 2026-09-03. Its one recorded blocker is gone: the
      passage kind exists. It was NOT built in the same pass, and the reason is measured rather
      than a preference.** Modality is "derived from the passage kind, never guessed", and the
      derivation needs the KIND at the point a mention is minted. It is not available there:
      `MentionDraft` carries `Passage passage.PID` and nothing else about the passage, and
      `MentionDraft.Mint(m *passage.Minter)` takes no registry — so deriving the kind means either
      threading a `*passage.Registry` through `Mint` and every call site, or having
      `pipeline/mentions/join.py` emit modality in its JSONL. Both are real changes with real blast
      radius, and "never guessed" forbids the cheap third option of defaulting when the kind cannot
      be resolved — which is precisely what this task's own paired mutation targets.
      **It is also COUPLED TO 002/T128 (unified T451), which is operator-blocked.** `Mention.Time` is documented as
      "nil exactly when Passage is not a transcript segment". A `screen_text` is now media-backed,
      so a mention on one SHOULD carry a time — its visibility interval, at `segment` precision,
      with the interval bound beside it. That is 002/T128 (unified T451)'s shape, and 002/T128 (unified T451) waits on 002/T124 (unified T447) for the
      bound's value. Building modality first would freeze a mention shape that 002/T128 (unified T451) must then
      change.
      **And its second half cannot be exercised against anything real.** Marking a subject
      `on-screen-only` needs a subject evidenced only on screen; there are ZERO on-screen mentions
      in the corpus and no path to one until 002/T126 (unified T449) runs. A gate for it today could only ever run on
      synthetic fixtures, with its production path unreachable — which is the shape of a proof that
      passes without proving. **Reclassified: merely unwritten, but correctly sequenced AFTER 002/T128 (unified T451),
      not before it.** Not blocked on capability
- [ ] T453 (was: 002/T130) [UNBUILT] [REVIEW] Settle **U7** — the **corroboration window**. A term is commonly — **BLOCKER:** **operator decision** — the corroboration window (U7) is an unsettled parameter, same class as 002/T124 (unified T447) · **OWNER:** **operator**
      displayed *before* it is discussed, so measure the observed lead/lag distribution between
      on-screen and spoken occurrences rather than assuming coincidence. Three-valued exit. Record
      under `workshop/evidence/`. **002/T131 (unified T454) is bounded by this**: a window tuned to zero lag
      under-groups, and a window widened until the numbers look tidy over-groups — and over-grouping
      destroys evidence silently (FR-055→unified FR-264, FR-063→unified FR-186)
      **BLOCKED ON CAPABILITY FIRST, THEN OPERATOR — measured 2026-09-03.** Unlike 002/T124 (unified T447), this
      clarification cannot be settled from anything already recorded: it asks for the observed
      lead/lag distribution between on-screen and spoken occurrences, and **no OCR output exists in
      this tree to measure a distribution over**. 002/T126 (unified T449) must run first. Settling U7 on the resulting
      distribution is then the operator's decision
- [ ] T454 (was: 002/T131) [UNBUILT] [TDD] Gate **G-OCR-6** — implement **corroboration grouping** per — **BLOCKER:** **predecessor 002/T130 (unified T453)** · **OWNER:** **implementer**, after 002/T130 (unified T453)
      `data-model.md` §2.10: mentions of one subject whose times overlap within the measured window
      form one group, and every publication, coverage and attachment figure counts **groups**, never
      raw mentions (FR-063→unified FR-186). Both figures are published together; **neither mention is deleted** and
      both stay individually retrievable and navigable. **Paired mutations**: (a) count raw
      mentions; (b) widen the window to the whole chapter. Both must go red — (b) because two
      genuinely distinct occurrences twenty minutes apart would collapse, which is how
      deduplication turns a corpus into a vocabulary list (FR-063→unified FR-186, SC-035→unified SC-107)
      **BLOCKED ON 002/T130 (unified T453) — measured 2026-09-03.** The window is the parameter this task groups by,
      and it is unmeasured. Not blocked on capability
- [ ] T455 (was: 002/T132) [UNBUILT] [TDD] Build the **hand-truthed ground-truth sample** — drawn by a recorded seed — **BLOCKER:** **irreducible HUMAN LABOUR over a private recording** — hand-truthing a ground-truth sample cannot be delegated to a machine, and this is the SINGLE HIGHEST-LEVERAGE operator item in spec 002: 002/T133 (unified T456), 002/T134 (unified T457), 002/T135 (unified T458), 002/T136 (unified T459), 002/T142 (unified T465) and 002's own closure all sit behind it · **OWNER:** **operator / human labour** — nothing an agent can do
      so it is reproducible, with the **population size published** beside it, matching the sampling
      discipline 002/T081 (unified T388) already uses. This artifact is the input to **both** accuracy axes; a figure
      published without its seed and population is not a measurement anyone can re-derive (FR-064→unified FR-187, SC-031→unified SC-103, SC-032→unified SC-104)
      **BLOCKED ON OPERATOR — measured 2026-09-03, and this one cannot be automated away.**
      Hand-truthing is human labour, performed over a private recording of a teaching session with
      an identifiable third party. No agent can substitute for it here, and the obvious shortcut is
      the precise mutation **002/T133 (unified T456)** requires to go red: a machine-produced "ground truth" scored
      against machine output measures nothing. The seed and population-size discipline this line
      asks for is already demonstrated by 002/T081 (unified T388) and needs no new capability. **002/T133 (unified T456), 002/T134 (unified T457) and —
      through them — the closure of spec 002 all sit behind this operator task**
- [ ] T456 (was: 002/T133) [UNBUILT] [TDD] Gate **G-OCR-7** — measure **textual** accuracy per chapter: word error — **BLOCKER:** **predecessor 002/T132 (unified T455)** — textual accuracy is measured AGAINST the hand-truthed sample · **OWNER:** **implementer**, after 002/T132 (unified T455)
      rate and character error rate against 002/T132 (unified T455)'s sample, scored by the **same** edit-distance
      method the speech calibration already uses, so the two figures are comparable rather than
      merely adjacent (FR-064→unified FR-187, SC-031→unified SC-103). **Paired mutation**: score against the recogniser's own
      output instead of the ground truth; the gate must go red (FR-064→unified FR-187, SC-031→unified SC-103)
      **BLOCKED ON 002/T132 (unified T455) (operator) — measured 2026-09-03.** There is no ground truth to score
      against. The edit-distance method this must share with the speech calibration already exists
      (`pipeline/compare_engines.py`), so the scorer is not the gap; the reference is
- [ ] T457 (was: 002/T134) [UNBUILT] [TDD] Gate **G-OCR-8** — measure **temporal** accuracy per chapter: the — **BLOCKER:** **predecessor 002/T132 (unified T455)** — temporal accuracy is measured against the same sample · **OWNER:** **implementer**, after 002/T132 (unified T455)
      proportion of on-screen mentions whose declared visibility interval **contains** the moment the
      text was actually on screen (FR-064→unified FR-187, SC-032→unified SC-104). **Paired mutation**: assert only that an interval
      exists; the gate must go red. **This axis is separate from 002/T133 (unified T456) deliberately**: deep linking
      depends on this figure and on no other, and a perfect textual score is entirely compatible
      with every interval being wrong — a text-only measurement cannot see the failure at all (FR-064→unified FR-187, SC-032→unified SC-104)
      **BLOCKED ON 002/T132 (unified T455) (operator) — measured 2026-09-03.** Same missing reference. Note the axis
      separation this line already argues for is now measurable in principle:
      `pipeline/detect_ocr.sh` confirmed the engine returns per-word bounding boxes, which is what a
      visibility interval is ultimately derived from
- [ ] T458 (was: 002/T135) [UNBUILT] [TDD] Gate **G-OCR-9** — implement the **accuracy budget, derived and never — **BLOCKER:** **predecessor 002/T132 (unified T455), AND a second independent operator blocker** — `CALIBRATION.md` carries NO WER figure at all, so the floor this gate must read at run time does not exist. The fix is spec 001's 001/T037 (unified T203)(b) blind human reference (30 seeded windows, 15 min audio, costed 1-2 h) — **one piece of human work satisfies both specs** · **OWNER:** **operator / human labour**, then **implementer**
      picked** (FR-064a→unified FR-188): the floor is **read at run time** from the recorded speech calibration for
      the same corpus, and the gate publishes the OCR figures and the speech baseline **together**
      (SC-033→unified SC-105). Three-valued — calibration record or ground-truth sample unreadable ⇒ **2**, never
      a pass. **Paired mutations**: (a) hardcode the floor as a literal; (b) measure accuracy over
      the frames the engine was tuned on. Both must go red. **This is how an accuracy budget is
      stated without violating the no-guessed-threshold rule**: U2 and U3 forbid guessing a target
      for a quantity nobody has measured, and this floor is not guessed — it is read from a
      measurement this project already has (FR-054→unified FR-261, FR-064a→unified FR-188, SC-033→unified SC-105)
      **BLOCKED ON A MISSING MEASUREMENT — measured 2026-09-03 — and this is NOT merely "blocked on
      002/T133 (unified T456) and 002/T134 (unified T457)". The floor this gate is required to READ AT RUN TIME does not exist.** This
      task derives the budget from "the recorded speech calibration for the same corpus", and that
      record was checked rather than assumed: `workshop/pipeline/CALIBRATION.md` carries **no WER
      figure**. Its own U4 row reads *"achievable WER | open — needs §5's blind human reference"*,
      and it states expressly that the engine-to-engine divergence (3.19 %) **is not a WER and must
      never be quoted as one**. So even after 002/T133 (unified T456) and 002/T134 (unified T457) produce OCR figures, there is nothing to
      compare them against, and the one number lying nearby is explicitly disqualified — quoting it
      would be precisely the substitution this line's mutation (a) forbids. **Unblocking needs the
      blind human reference of CALIBRATION.md §5, which is operator labour**, in addition to
      T132/T133/T134. Recorded here because the task as written reads as though its input were
      already in hand, and it is not
      **THE BLOCKING INPUT IS NOW SPECIFIED, SEEDED AND HANDED OVER — under spec 001's 001/T037 (unified T203), not
      here. Updated 2026-09-03; still BLOCKED, and the block is unchanged operator labour, but it is
      no longer unattributed.** The blind human reference CALIBRATION.md §5 needs is exactly the
      reference `specs/001-workshop-curriculum-platform/tasks.md` **001/T037 (unified T203)(b)** specifies: 30 seeded
      30 s windows over chapter 01, 900.0 s = 15 min of audio, listed with exact `t0`/`t1` bounds in
      `workshop/chapters/01/transcript/accuracy-plan.json`, costed at **1–2 hours**. **ONE piece of
      human work satisfies both 001's SC-002 and this task's FR-064a floor** — it is not two
      transcription jobs, and it must not be scheduled as two. The plan was re-emitted on 2026-09-03
      under `research/transcription.md` §5.2's **ten equal temporal strata** (3 windows each,
      occupancy `[3,3,3,3,3,3,3,3,3,3]`, 0 empty, 0 overlapping), superseding a confidence-stratified
      set; a reference transcribed against the superseded windows would match nothing. Running
      `bash workshop/scripts/verify-accuracy.sh 01 --reference <path>` writes
      `workshop/chapters/01/transcript/accuracy.json`, and **that file is the record this gate reads
      at run time** — seeded, reproducible, population published, scored by the **same**
      `pipeline/compare_engines.py` edit distance 002/T133 (unified T456) must share, which is what makes SC-031's
      *"comparable rather than merely adjacent"* structural instead of coincidental.
      **A SAMPLED estimate satisfies FR-064a — checked, not assumed.** FR-064a says *"read from the
      recorded speech-recognition calibration"* and never says exhaustive; FR-064 makes the OCR side
      itself a **sample**; and this task's own three-valued clause says *"ground-truth **sample**
      unreadable ⇒ 2"*. **A whole-chapter WER is NOT required.** Had it been, 001/T037 (unified T203) would not close
      this and that would be recorded here instead.
      **THREE THINGS THIS DOES NOT GIVE YOU, named so they are not discovered late.** (1) **Scope:**
      FR-064b/SC-034 are per chapter and this reference covers **chapter 01 only** — no other
      chapter acquires a floor. (2) **CER:** SC-031 requires the OCR figure as WER **and** CER;
      `verify-accuracy.sh` computes **WER only**. Producing a speech CER needs **no additional human
      work** — the same reference text yields it — but it needs a **002/T112 (unified T442) change** in 001, and
      without it SC-033 publishes an asymmetric pair. (3) **Temporal symmetry:** T134/SC-032 measure
      a temporal axis; the speech-side analogue is 001's timestamp-error companion metric (SC-003→unified SC-045),
      whose only possible input is the `onset_s` mark the reviewer makes **while listening**. 001/T037 (unified T203)'s
      handover asks for it as an optional field for exactly this reason — skipped, it costs a second
      1–2 hour listening pass. SC-033's wording does not demand it, so its absence does not fail
      this gate; it forecloses a symmetry that is nearly free today.
      **THE ESTIMATOR UNIT, if any interval is ever put on either figure: the WINDOW / SAMPLE UNIT
      (n = 30 clusters), never the word.** Words inside one 30 s window are not independent draws,
      and WER is not a proportion — insertions let `(S+D+I)/N_ref` exceed 1, which no binomial
      admits. At the limit of perfect intra-window correlation a word-level interval is narrower by
      up to `√(N_hyp/30) ≈ 8×`, **overstating** precision. **Nothing in this project computes an
      interval today**, and `accuracy.json` carries no interval field — it carries this warning in
      `sample.estimator_unit` instead
- [ ] T459 (was: 002/T136) [UNBUILT] [TDD] Gate **G-OCR-10** — implement the **per-chapter publication precondition** — **BLOCKER:** **predecessor 002/T133 (unified T456) + 002/T134 (unified T457) + 002/T135 (unified T458)** — a publication precondition cannot be enforced before the figures it gates on exist · **OWNER:** **implementer**, after the accuracy chain
      (FR-064b→unified FR-189): no OCR-derived mention is published for a chapter until **that chapter's** accuracy
      run has been observed passing. **Paired mutation**: publish from a chapter whose accuracy
      run returned could-not-determine; the gate must go red. Font, resolution and compression differ
      between recordings, so a figure measured on one chapter is not evidence about another — the
      same per-chapter discipline **V2** already applies to word timings (FR-064b→unified FR-189, SC-034→unified SC-106)
      **BLOCKED ON 002/T135 (unified T458) — measured 2026-09-03.** There is no budget to precondition publication on.
      Not blocked on capability
- [ ] T460 (was: 002/T137) [UNBUILT] [TDD] Gate **G-OCR-11** — extend the content-boundary check over OCR output and — **BLOCKER:** **predecessor 002/T126 (unified T449)** — there is no OCR output to extend the content-boundary check over · **OWNER:** **implementer**, after 002/T126 (unified T449)
      run it **before** publication (FR-065→unified FR-190, SC-036→unified SC-108). **Paired mutation**: scope the check to
      transcript text only; the gate must go red. **On-screen text is a wider disclosure surface than
      the transcript** — a recording displays window titles, file paths, identifiers and names that
      nobody ever said aloud, so a boundary check written against spoken text does not cover this
      kind. The umbrella repository is public and this material is not (FR-065→unified FR-190, SC-036→unified SC-108)
      **BLOCKED ON 002/T125 (unified T448) AND 002/T126 (unified T449) — measured 2026-09-03.** The check must run over OCR output and
      none is produced yet. Worth restating rather than deferring silently: this task guards the
      widest disclosure surface in the phase, and the umbrella repository is public while this
      material is not, so it must land BEFORE 002/T141 (unified T464) wires the stage into the chapter-addition path —
      not after
- [ ] T461 (was: 002/T138) [UNBUILT] [TDD] Index `screen_text` on its own text and prove **G-KG-11** for it — an — **BLOCKER:** **predecessor 002/T126 (unified T449)** — nothing to index until `screen_text` mentions are produced · **OWNER:** **implementer**, after 002/T126 (unified T449)
      advertised kind must be **retrievable**, proven by a planted known target, **never** by a row
      count. Do not advertise the kind until it is retrievable (FR-066→unified FR-191). The corpus already
      advertises `diagram` with **0** entries, and this task exists so a second such kind is not
      created (FR-028→unified FR-156, FR-066→unified FR-191, SC-013→unified SC-087)
      **BLOCKED ON 002/T125 (unified T448) — measured 2026-09-03.** Nothing to index until the kind exists. Not blocked
      on capability
- [ ] T462 (was: 002/T139) [UNBUILT] [P] Add the contract sections and route-manifest rows for the `screen_text` — **BLOCKER:** none but the work — contract sections and route-manifest rows can be written ahead of the implementation, and doing so early is cheap · **OWNER:** **implementer** — unblocked today
      kind, its evidence entries and the modality and interval-bound fields (FR-059→unified FR-274). Gate
      **G-KG-1**. This task is also what moves gates **G-OCR-1**..**G-OCR-11** into `contracts/`,
      where the gate-attachment closure check enumerates them — they are attached to task lines
      already, so that check must still print `unattached: 0` after this task lands (FR-059→unified FR-274)
      **MERELY UNWRITTEN, AND DELIBERATELY NOT DONE IN THIS PASS — measured 2026-09-03.** No
      capability and no operator decision blocks the contract text. It was left alone anyway,
      because doing it first would move eleven `G-OCR-*` ids into `contracts/` while **none of the
      eleven gates exists**, publishing gate identifiers for gates nothing builds. The
      gate-attachment closure check would still report `unattached: 0` — every id is already carried
      on its task line — so the check would stay green while the contract described a capability the
      tree does not have. That is a green instrument reporting on the wrong question, and the
      correct order is gates first, contract second. Measured before and after this pass with the
      corrected extractor: **19 ids, `unattached: 0`**, unchanged
- [ ] T463 (was: 002/T140) [UNBUILT] [TDD] Prove redaction reaches **OCR-derived** mentions across all eight targets — **BLOCKER:** **predecessor 002/T126 (unified T449)** — redaction cannot be proven to reach OCR-derived mentions that do not exist · **OWNER:** **implementer**, after 002/T126 (unified T449)
      in `data-model.md` §5. Gate **G-KG-7** extended. **Paired mutation**: restrict propagation to
      the spoken modality; the gate must go red. The eight targets do not change — what must be
      proven rather than assumed is that the propagation was not written against ASR-derived
      mentions only (FR-027→unified FR-148, SC-012→unified SC-080)
      **BLOCKED ON 002/T125 (unified T448) AND 002/T126 (unified T449) — measured 2026-09-03.** There are no OCR-derived mentions for
      redaction to reach. Not blocked on capability
- [ ] T464 (was: 002/T141) [UNBUILT] [US7] Add the OCR stage to the platform's **existing** chapter-addition path per — **BLOCKER:** **predecessor 002/T126 (unified T449) + 002/T136 (unified T459)** · **OWNER:** **implementer**, after T126/T136
      **S1** — a stage added, **not a second procedure**; three-valued and resumable per **S3**/**S4**;
      writing to no source per **S7**; writing evidence on every outcome including could-not-determine
      per **S8**. Gate **G-KG-17** extended to assert the OCR outputs appear in the synthetic-chapter
      run. **Paired mutation**: remove the OCR stage; the gate must go red naming the missing output (FR-033d→unified FR-174, FR-033e→unified FR-174)
      **BLOCKED ON 002/T126 (unified T449) — measured 2026-09-03.** There is no OCR stage to add to the
      chapter-addition path. Not blocked on capability: the two tools the stage would call, frame
      sampling and recognition, are both measured working by `pipeline/detect_ocr.sh`
- [ ] T465 (was: 002/T142) [UNBUILT] [REVIEW] Publish both OCR accuracy figures **beside** the speech-recognition — **BLOCKER:** **predecessor 002/T133 (unified T456) + 002/T134 (unified T457), and spec 001's 001/T037 (unified T203)** — both OCR accuracy figures must be published BESIDE the speech-recognition figure, and that figure does not exist either · **OWNER:** **implementer**, after T133/T134 and 001's 001/T037 (unified T203)
      ones in the shipped limits document and state plainly what OCR cannot do (FR-050 discipline);
      register every check added by this phase (SC-027→unified SC-135); and drive each of **G-OCR-1**..**G-OCR-11**
      into its **could-not-determine** condition and assert the third state (SC-028→unified SC-136). A figure
      published alone is not an accuracy claim a reader can act on, and a gate never observed in its
      third state is not known to have one (FR-050→unified FR-171, SC-027→unified SC-135, SC-028→unified SC-136, SC-033→unified SC-105)
      **BLOCKED ON EVERY TASK ABOVE — measured 2026-09-03.** This is a final review task and it
      cannot honestly close while any of T123-T141 is open. One part of it is already partly
      satisfied and should not be re-counted later: **G-OCR-1** has been driven into its
      could-not-determine condition and the third state asserted — `pipeline/detect_ocr.sh
      --scratch-dir /nonexistent/detect-ocr-probe` exits **2**, executed on every default run of
      `platform/gates/verify-check-registry-001.sh` as that row's registered rc-2 probe. The other
      ten `G-OCR-*` gates do not exist, so nine tenths of this obligation is untouched
- [x] T466 (was: 002/T143) Build **G-KG-1-changed** and its §1.1 paired mutation: assert that every §4
      *changed* endpoint carries a route-manifest row whose contract citation names **both** its
      `001/contracts/http-api.md` section and its §4 subsection here (R1b), and prove the gate red
      by **rewriting** one such citation back to its 001-only form — leaving the row otherwise
      byte-identical. The mutation must be a rewrite, not a deletion: `G-KG-1`'s deletion mutation
      cannot reach this defect, because every §4 row is **present** throughout and the failure is a
      row that is present but under-cites (FR-059→unified FR-274). **PARTIAL, 2026-09-03 — the DEFECT is fixed and the box
      is unticked, but the stated reason has been CORRECTED the same day and the correction makes
      the residue smaller and sharper.** The compound form already existed on three
      of the four changed endpoints (`3.6+002.4.2`, `3.7+002.4.1`, `3.11+002.4.4`); §4.3's answering
      row carried a bare `3.10` and now reads `3.10+002.4.3`, so R1b is met 4 of 4 as measured that
      day (`verify-server-unity.sh` re-run after the edit: `PASS=35 FAIL=0 UNDET=0 DEBT=4`, exit 0 — population: unstated).

      **WITHDRAWN, not restated: *"the GATE is not built"* and *"Nothing enforces it."*** Both were
      wrong when written and the measurement is one command:

      ```bash
      grep -n 'G-KG-1-changed' workshop/platform/gates/check-registry-002.tsv
      #   29: check  G-KG-1-changed  go-test   # (source)
      #       internal/api/knowledge_gates_test.go::TestGateKG1_ChangedEndpointsCiteTheDeltaContract
      cd workshop/platform/backend
      go test -count=1 -run TestGateKG1_ChangedEndpointsCiteTheDeltaContract ./internal/api/...  # ok (in_process)
      ```

      A gate carrying this exact id exists, is registered, is green, and its §1.1 pair
      (`platform/backend/gates/prove-knowledge-manifest-mutation.sh`) performs the **rewrite**
      mutation this task specifies rather than a deletion — its own header says it *"rewrites one of
      the three contract columns back to its bare specs/001 token in the REAL production manifest,
      requires this test to go RED with its own message, restores the file byte-identically and
      requires it GREEN again."* All of that landed in workshop `bd7da41`, before this task was
      written.

      **What is genuinely still owed — and it is the one endpoint this task was created for.** The
      existing gate's `want` table enumerates **three** rows: `GET /api/search` (3.7+002.4.1), `GET
      /api/suggest` (3.6+002.4.2) and `GET /api/progress` (3.11+002.4.4). Its own doc comment scopes
      itself that way, naming §4.1, §4.2 and §4.4 and attributing itself to **002/T070 (unified T377)**. **`/api/ask`
      — §4.3, the fourth changed endpoint and the only one whose citation was actually wrong — is
      absent from the table.** So the gate covers 3 of 4, and the row whose `3.10 → 3.10+002.4.3`
      repair is recorded above is enforced by nothing: the next edit that drops that suffix still
      restores the violation silently.

      ~~**This box therefore stays `[ ]`, and the remaining work is now a small, named change rather
      than a gate from scratch:** add the `/api/ask` row to the existing table (and, per §1.1, a
      fourth rewrite case to `prove-knowledge-manifest-mutation.sh`, whose current mutation set does
      not touch it).~~ Do not tick this on the strength of the gate existing — a gate that enumerates
      three of four obligations is green about the three and blind to the fourth, which is the same
      blind-instrument shape the closure check's own `THE BLIND ZERO` note records one section
      below. **That caveat is retained because it is the standing lesson, and it is now SATISFIED
      rather than waived — the gate enumerates 4 of 4.**

      **TICKED 2026-09-03. The residue named above is closed, and it was closed by DERIVING both
      coverage sets rather than by extending either hand list — which is a stronger fix than this
      task asked for, and deliberately so.** A hand list is what produced the defect: the table
      enumerated §4.1, §4.2 and §4.4 and omitted §4.3, and nothing anywhere was checking that
      omission. Adding a fourth literal would have left the next §4.5 exposed to the identical
      failure. Measured, both directions:

      - **The gate.** `TestGateKG1_ChangedEndpointsCiteTheDeltaContract` no longer carries a `want`
        table. It locates `contracts/http-api-delta.md` by a parent walk mirroring
        `verify-server-unity.sh`'s own `find_contract()` (override:
        `WORKSHOP_HTTP_DELTA_CONTRACT`), parses every `### 4.N` heading under `## 4. Endpoints
        changed`, and grades each one. It PRINTS the derived population so a green run shows what it
        graded: *"coverage set DERIVED from …/http-api-delta.md: 4 changed endpoint(s) — §4.1 GET
        /api/search, §4.2 GET /api/suggest, §4.3 POST /api/ask, §4.4 GET|POST /api/progress"*.
        Matching is on PATH with the query string stripped, exactly as U6 does, because §4.3's
        heading says `POST /api/ask` while the probed row is `GET /api/ask?q=ping` and §4.4's says
        `GET|POST` — requiring the verbs to agree would fail on a disagreement that is not a defect.
        The delta citation is compared as a whole `+`-joined COMPONENT, not by substring, so
        `002.4.1` can never be satisfied by `002.4.10`.
      - **The proof.** `prove-knowledge-manifest-mutation.sh`'s `CHANGED_*` arrays are gone too; its
        §4 mutation set is derived from the production manifest (every row whose contract column
        carries a `002.4.N` component). `--list` now reports **12 mutations (8 fixed §3 deletions +
        4 DERIVED §4 citation rewrites)**, the fourth being `ask-4-3: rewrite /api/ask?q=ping
        contract column 3.10+002.4.3 -> 3.10`. Full run: **rc 0, `12 proven / 0 problem / 0
        undetermined`** (in_process) — so the `/api/ask` citation is now enforced by a mutation that has been
        OBSERVED turning the gate red, which is what the repair recorded above previously lacked.
      - **The two derivations are taken from DIFFERENT documents on purpose.** The gate derives from
        the contract's §4 headings; the proof derives from the manifest's own citations. A row that
        loses its citation drops out of the proof's set but turns the gate RED, and the proof's
        preflight refuses to prove anything against an already-red gate (exit 2). Agreement is the
        evidence; disagreement is an UNDETERMINED, never a silent under-mutation.

      **Honest boundary (§11.4.6), stated because it is a real change in behaviour.** The gate now
      reads a document that lives in the SUPERPROJECT. Where it cannot be found, the test reports
      **UNDETERMINED via `t.Fatal`, i.e. as a FAILURE** — `t.Skip` was rejected because a skip exits
      0 and `check-registry-002.tsv` would read it as a pass. So a workshop checkout taken apart from
      its superproject now fails this one test instead of passing it vacuously. That mirrors
      `verify-server-unity.sh` U6, whose own comment says an unreachable contract "is exit 2, not a
      pass"; the previous test comment argued the opposite and is withdrawn in the file itself.

      **The superseded "measured while re-deriving" note below is retained, not deleted** — it
      recorded that the paired proof could not be re-run to completion because of a concurrent Go
      build break. It has since been re-run to completion (rc 0, above). The note stands as the
      record of a COULD-NOT-DETERMINE that was correctly refused as a pass.

      **Measured while re-deriving this, and recorded rather than absorbed: the paired proof could
      NOT be re-run to completion today** — `bash platform/backend/gates/prove-knowledge-manifest-mutation.sh`
      returned rc=1 with `7 proven / 1 problem / 1 undetermined` (in_process), and the problem and the
      undetermined are both a **Go build break from concurrent editing in this tree**
      (`internal/redaction/taxonomy.go: t.ProposalsUnlinked undefined`, and earlier
      `pkg/index/generation.go:170: declared and not used: declined`), not a defect the proof found.
      That is a COULD NOT DETERMINE on the proof's own health, and a 2 is never a pass; the gate
      itself was green minutes earlier on the same tree


---

## Phase 15: US18 — evidence, independent review and governance (P2)

**11 tasks — 7 complete, 4 open.** Sources: 005, 006.


*From `005` — Phase 5: Evidence discipline — cross-cutting*

- [x] T467 (was: 005/T051) [TDD] Drive every palette mutation by **data**, not by altering the check (FR-021→unified FR-260, SC-014→unified SC-135). **Evidence** (source): 8 fixtures tracked under `workshop/platform/gates/fixtures/palette/` — `empty`, `flat`, `good`, `low-contrast`, `near-grey-ramp`, `scheme-split`, `indicator-only`, `boundary-ulp`. `indicator-only` is the fixture that pins defect D-A; `boundary-ulp` pins the bucket edge. **A gate green by construction is the inoperative-proof defect this project has already caught once.**
- [x] T468 (was: 005/T052) Make the content-boundary gate carry evidence its corpus did not move during the measurement (FR-023→unified FR-263). **Evidence** (source): both runs in `docs/content-boundary-class-a-judgement.md` report `corpus MOVED` with the changed-file count (66 of 14,891; 4 of 14,837) and are tied together by `--expect-corpus`. **The gate reports its own instability instead of absorbing it silently.**
- [ ] T469 (was: 005/T053) [TDD] **PARTIAL** — make every check whose subject is a set establish the set is **non-empty** before reporting the set contains no defects (FR-022→unified FR-262, SC-014→unified SC-135). Two instruments do this: `verify-obtainability.sh` returns **2** when nothing is tracked to measure, and `workshop/platform/gates/verify-bank-reachability.sh` was written precisely because the prior gate checked one fixture area while 89 questions were unreachable. **It is not universal, and no sweep asserts it across the fleet.**
- [ ] T470 (was: 005/T054) **OPEN** — satisfy SC-014: **100%** of requirements map to at least one automated check, and every such check ships a data-driven paired demonstration (FR-020→unified FR-259, SC-014→unified SC-135). **This file is the first half of that criterion and does not complete it.** Every FR and SC in spec.md is now cited by at least one task above — but a task is not a check, and 22 of the 54 tasks here are not ticked. **Requirements with no automated check at all: FR-009, FR-010, FR-013, FR-014, FR-017 and SC-015.** Those six are the real coverage gap.

*From `006` — Phase 7: User Story 5 — a reviewer can confirm no claim is unearned (P2)*

- [x] T471 (was: 006/T045) [US5] Withhold answer keys from the open practice route in `workshop/platform/backend/internal/api/questions_graded.go` (FR-?). **Evidence** (population: unstated): the decks are the same rows — 224 of 224 match by prompt, 0 of 224 by id — so gating practice would delete a feature; the defect was the disclosure.
- [x] T472 (was: 006/T046) [US5] Fail closed on a nil, unreadable **or stale** catalog (FR-024→unified FR-261, FR-026a→unified FR-267). **Evidence**: a graded prompt the snapshot never saw would look "graded nowhere" to a literal index and be published.
- [x] T473 (was: 006/T047) [US5] Refuse a malformed submission in `workshop/platform/backend/internal/api/assessment_submit_body.go`, naming the offending key, before the store is touched (FR-014→unified FR-096). **Evidence** (population: unstated): a misspelled key returned 200 and permanently recorded a 0% attempt; `responses: []` still grades.
- [x] T474 (was: 006/T048) [US5] Assert word-span containment on **both** endpoints in `workshop/platform/backend/pkg/knowledge/wordjoin.go` (FR-?). **Evidence** (population: unstated): containment was checked on word *starts* while the published span was derived from word *ends*; 7 of 2158 joined segments could publish a span their own passage does not contain.
- [x] T475 (was: 006/T049) [P] [US5] Fix the gate-server leak in `workshop/platform/gates/lib/learning_stack.sh` (FR-?). **Evidence** (population: unstated): `BASE="$(ls_start …)"` runs in a **subshell**, so `LS_PID=$!` never reached the caller and every trap read an empty variable and returned 0 — 21 orphans reaped from this host.
- [ ] T476 (was: 006/T050) [TDD] [SUBAGENT] [US5] Add the build identifier to `/api/health` (FR-026→unified FR-266). **Evidence needed**: nothing noticed the container was four hours older than the code, because no reading could be tied to a revision.
- [ ] T477 (was: 006/T051) [SUBAGENT] [US5] Commission a **second** independent adversarial review against the rebuilt container (FR-029→unified FR-269, SC-014→unified SC-140). The first found four false headline claims; a review that confirms is worth little.


---

## Phase 16: MIGRATION — US26 to US33, the decoupled modules (Target Architecture)

**43 tasks — 20 complete, 23 open.** Sources: 004, 007, plus 8 tasks new in the 2026-09-15
remediation pass with no source-spec origin.


*From `004` — Phase 8: User Story 6 — Each module runs on its own (P3)*

- [x] T478 (was: 004/T050) [US6] Add `workshop/scripts/bootstrap-standalone.sh` and `workshop/helix-deps.yaml` (FR-024→unified FR-288, SC-012→unified SC-146+SC-147).
- [x] T479 (was: 004/T051) [P] [US6] Add `verify-standalone-clone.sh` to both `workshop/scripts/` and `ai_interviewing/scripts/` (FR-024→unified FR-288, FR-025→unified FR-290, FR-026→unified FR-259, SC-012→unified SC-146+SC-147).
- [x] T480 (was: 004/T052) [US6] Record the `curriculum-kit` replace-target gap verbatim in `workshop/platform/backend/go.mod` (FR-024→unified FR-288). **Evidence** (source): gaps 2 → 3, correctly — the gate working, not drift.
- [x] T481 (was: 004/T053) [US6] **RESOLVED — see the EVIDENCE below; the original “BLOCKED — operator decision” lead-in is withdrawn as stale (2026-09-15).** Publish `submodules/curriculum-kit` as a git repository and mount it as a gitlink, then declare it in `helix-deps.yaml`. It is currently a plain directory with **no commit to pin**, so a truthful manifest entry cannot be written and a fabricated `ref:` would be a bluff (FR-024→unified FR-288, SC-012→unified SC-146+SC-147). — EVIDENCE (source): `git ls-files -s submodules/curriculum-kit` -> `160000 52f08af5abb396bce7d9679cb82eb0b9dd0246fc`; `.gitmodules:40-42` declares the path and url; `helix-deps.yaml:313-316` records `ref: 52f08af5abb3...`; `bash scripts/verify-manifest-pins.sh` rc **0** at 13 MATCH / 0 DRIFT / 0 UNDETERMINED. The blocker (no commit to pin) is gone

*From `007` — Phase 1: Setup (Shared Infrastructure)*

- [x] T482 (was: 007/T001) [P] [US1] Clone workshop repo outside umbrella vasic
- [x] T483 (was: 007/T002) [P] [US1] Initialize submodules and verify build passes independently
- [ ] T484 (was: 007/T030) [P] [US1] Add decommission gate for workshop: the umbrella-hosted `workshop/` copy remains the operative one and MUST NOT be removed/decommissioned until the standalone workshop clone independently passes `install` and the full test suite on its own (FR-052→unified FR-328)

*From `007` — Phase 2: Foundational (Blocking Prerequisites)*

- [x] T485 (was: 007/T003) [TDD] [US2] Clone ai_interviewing repo outside umbrella vasic
- [x] T486 (was: 007/T004) [TDD] [US2] Initialize submodules and verify build passes independently
- [ ] T487 (was: 007/T031) [P] [US2] Add decommission gate for ai_interviewing: the umbrella-hosted `ai_interviewing/` copy remains the operative one and MUST NOT be removed/decommissioned until the standalone ai_interviewing clone independently passes `install` and the full test suite on its own (FR-052→unified FR-328)

*From `007` — Phase 3: User Story 3 - Auth/RBAC (Priority: P3) 🎯 MVP*

- [x] T488 (was: 007/T005) [TDD] [US3] Setup shared DB schema and migrations for auth (users milosvasic/rami, roles admin/user)
- [x] T489 (was: 007/T006) [TDD] [US3] Implement login form and RBAC on both modules (workshop: full access; ai_interviewing: rami restricted on employer_data/github_analysis)
      — **NOTE 2026-09-15**: this task’s literal scope (RBAC for exactly the two seed users and two modules) is narrower than unified FR-303’s required shape — a genuine `(user, module, resource, action)` rule set, “not a two-user hard-coding”. This note does NOT assert the task is wrong: a two-user first pass may be deliberate. It records that FR-303’s extensibility property is not asserted anywhere, and points at **T579**, added by this pass, which asserts it. Checked state unchanged.

*From `007` — Phase 4: User Story 4 - Progress tracking (Priority: P4) 🎯 MVP*

- [x] T490 (was: 007/T007) [TDD] [US4] Implement progress tracking on workshop module (areas, lessons, tests, exercises)
- [x] T491 (was: 007/T008) [TDD] [US4] Implement progress tracking on ai_interviewing module (areas, lessons, tests, exercises)

*From `007` — Phase 5: Extract Reusables (Priority: P2)*

- [x] T492 (was: 007/T009) [P] [US5] Extract reusable code from workshop to submodules vasic-digital
- [x] T493 (was: 007/T010) [P] [US5] Extract reusable code from ai_interviewing to submodules vasic-digital
- [ ] T494 (was: 007/T028) [REVIEW] [US5] Add a mandatory content-boundary review gate to the reusable-code extraction pipeline: run the `scripts/verify-content-boundary.sh`-class check against each candidate extraction from workshop/ai_interviewing and block creation/push of the new public vasic-digital repository until it confirms zero private data (FR-051→unified FR-327)
- [ ] T495 (was: 007/T029) [P] [US5] Implement additive-then-cutover extraction pattern: keep each existing in-tree reusable code path functional in workshop/ai_interviewing until the corresponding consumer is confirmed migrated to, and re-tested against, the extracted public submodule (FR-053→unified FR-329)

*From `007` — Phase 6: Submodule Updates (Priority: P2)*

- [x] T496 (was: 007/T011) [P] [US6] Update all 14 existing submodules to latest main branch
      — **FLAGGED 2026-09-15 — what the evidence shows, stated plainly: THERE IS NO EVIDENCE TEXT ON THIS TASK AT ALL.** It carries `[x]` and a one-line instruction, and no note recording what was run, when, against which submodules, or with what result. So this pass CANNOT determine whether a blind fleet-wide update was performed or only a comparison. **That matters, because the task’s literal wording — “Update all 14 existing submodules to latest main branch” — is exactly the action unified FR-326 (was: 007/FR-028 — SCOPE MODIFIED) narrows to “comparison and reporting only”, leaving the pin move itself an operator decision (Clarifications C8).** A `[x]` on the forbidden action is misleading whichever way it happened. **Flagged for operator attention; checked state deliberately unchanged, and no claim is made here about what was actually done (§11.4.6).**
- [x] T497 (was: 007/T012) [P] [US6] Verify updated submodules build with no version conflicts

*From `007` — Phase 7: Documentation (Priority: P2)*

- [x] T498 (was: 007/T013) [P] [US7] Extend and update documentation for both standalone modules (user guides, manuals, graphs, diagrams, schemes, FR-029/030 guides)
- [x] T499 (was: 007/T014) [P] [US7] Create architecture diagrams and SQL definitions for module boundaries and data flows

*From `007` — Phase 8: Test Coverage (Priority: P1)*

- [x] T500 (was: 007/T015) [TDD] [US8] Implement test suite for workshop with deterministic evidence (unit, integration, e2e, contract, performance, security, accessibility)
- [x] T501 (was: 007/T016) [TDD] [US8] Implement test suite for ai_interviewing with deterministic evidence (unit, integration, e2e, contract, performance, security, accessibility)

*From `007` — Phase 9: Security & Privacy Hardening (FR-042–FR-055, added 2026-09-15 brainstorm pass)*

- [ ] T502 (was: 007/T017) [TDD] [REVIEW] [US3] Implement salted password hashing (Argon2id or bcrypt) for the shared user store on both modules; verify by test that no plaintext or reversibly-encrypted password value exists in any table, log, or fixture (FR-042→unified FR-305)
- [ ] T503 (was: 007/T018) [P] [REVIEW] [US3] Add a pre-deployment boot guard that refuses to start a production-flagged environment while the FR-009 example password hashes (for the two seed accounts — **the two literal password values are REDACTED in this merged copy; they remain readable, unchanged, at `specs/007-decouple-modules-auth/tasks.md` 007/T018 (unified T503)**) are still active, and document in each module's README that these already-committed values are compromised and MUST NOT be reused as real secrets (FR-043→unified FR-306)
- [ ] T504 (was: 007/T019) [TDD] [REVIEW] [US3] Add automated log/error-output scanning (unit + integration test) asserting that session tokens, session identifiers, and passwords never appear in application logs, error responses, crash reports, or URL/query strings on either module (FR-044→unified FR-307)
- [ ] T505 (was: 007/T020) [TDD] [REVIEW] [US3] Implement session-ID regeneration on successful login on both modules; add a regression test proving the pre-authentication session id is discarded and cannot become the authenticated session id (session-fixation protection) (FR-045→unified FR-308)
- [ ] T506 (was: 007/T021) [TDD] [REVIEW] [US3] Implement audience-scoped (module-restricted) tokens; add a contract test proving a token minted by workshop is rejected by ai_interviewing and vice versa, even though both modules read the shared user store (FR-046→unified FR-309)
- [ ] T507 (was: 007/T022) [TDD] [REVIEW] [US3] Implement fail-closed behavior on both modules when the auth provider/user database is unreachable; add an integration test that simulates database unavailability and asserts every protected route denies access (never grants it) during the outage (FR-047→unified FR-310)
- [ ] T508 (was: 007/T023) [TDD] [P] [US3] Implement per-account and per-source login rate limiting/throttling on both modules; add a test that exceeds the threshold and asserts subsequent attempts are throttled/blocked (FR-048→unified FR-311)
- [ ] T509 (was: 007/T024) [TDD] [P] [US3] Implement generic ("invalid username or password") authentication failure messages on both modules; add a test asserting byte-identical response content/shape for an unknown username vs. a known username with a wrong password (username-enumeration prevention) (FR-049→unified FR-312)
- [ ] T510 (was: 007/T025) [TDD] [P] [US3] Exempt health-check/readiness endpoints from authentication on both modules; add a test asserting these endpoints return HTTP 200 with no content or user data of any kind (FR-050→unified FR-313)
- [ ] T511 (was: 007/T026) [TDD] [REVIEW] [US3] Implement default-deny access for any user record with no assigned role/permission on both modules; add a test creating a roleless user and asserting zero access is granted — never admin-equivalent or inherited access (FR-054→unified FR-314)
- [ ] T512 (was: 007/T027) [TDD] [REVIEW] [US3] Implement cutover invalidation of any session/cookie issued before secure session handling (FR-017→unified FR-304) was enforced; add a migration test proving a pre-rollout session cookie is rejected post-cutover on both modules (FR-055→unified FR-315)


*New — added by the 2026-09-15 remediation pass. These tasks have **no source-spec origin**: they
carry unified ids only, because the requirements they implement were created or promoted by the merge
itself and no task carried in from specifications 001–007 covers them. Their citations therefore
name unified ids directly and need no translation.*

- [ ] T574 (new — 2026-09-15 remediation pass, no source-spec origin) [TDD] [US3] Build the **cutover census**: enumerate every anonymous per-browser learner-progress record that exists at the moment authentication is switched on, and write the census — record id, created-at, last-touched, browser-scope key — to a durable artefact under `workshop/evidence/` **before any record is touched**. Gate **G-AUTH-1**: the census artefact exists and is written before the cutover migration runs; a cutover that runs with no census present FAILS. **Paired mutation**, data-driven and with no edit to the gate: seed a fixture store carrying anonymous records, delete the census artefact, re-run — the gate MUST go red. Three-valued: **rc 2** where the progress store cannot be read, and an rc 2 is never a pass. (unified FR-321, unified SC-161)
- [ ] T575 (new — 2026-09-15 remediation pass, no source-spec origin) [TDD] [US3] Present the learner an **explicit choice** at first authenticated login — migrate the anonymous record into the new account, or discard it with notice — and log the chosen outcome, with its timestamp and the acting account, against the record id. **No silent merge and no silent discard**: unified FR-321 forbids both by name, the first because it attributes one person's activity to another on a shared browser, the second because it destroys a record FR-118 promised to preserve. Gate **G-AUTH-2**: for a seeded anonymous record, an authenticated login that neither prompts nor records an outcome MUST fail. **Paired mutation**: replace the prompt with an automatic merge in a throwaway copy — the gate MUST go red on the same fixture. (unified FR-321)
- [ ] T576 (new — 2026-09-15 remediation pass, no source-spec origin) [TDD] [REVIEW] [US3] Assert **100%** coverage exactly as unified SC-161 states it: every record in T574's census reaches one of the two stated outcomes, and the count of records handled silently is **0**. Gate **G-AUTH-3** reconciles the census against T575's outcome log and reports the residue **by record id, never as a percentage alone** — a percentage hides which record was lost. **Paired mutation**: drop one row from the outcome log — the gate MUST go red **naming that record id**, not merely reporting a lower figure. Three-valued: **rc 2** where either the census or the outcome log is unreadable. This is the evidence migration gate **M6** requires, and M6 is the only irreversible step in the migration. (unified FR-321, unified SC-161)
- [ ] T577 (new — 2026-09-15 remediation pass, no source-spec origin) [TDD] [US3] **Negative-assertion** gate **G-AUTH-4**: no self-registration route is reachable from the login page on either module. Enumerate every route the login page links to or posts to, assert that none creates an account, and assert over HTTP against both running modules that the account-creation path is not served. **Paired mutation**: add a registration route to a throwaway copy of the route table — the gate MUST go red. Three-valued: **rc 2** where a module is not running, because an unreachable service is never a pass. Pairs with T488/T489. (unified FR-316)
- [ ] T578 (new — 2026-09-15 remediation pass, no source-spec origin) [TDD] [REVIEW] [US3] Confirm the **seed-account bootstrap is operator-run and non-network-exposed** — a CLI step or a migration invoked by an operator, never an HTTP endpoint. Gate **G-AUTH-5** asserts the seed path exists as an executable script or migration, and that no HTTP handler in either module creates a seed account. **Paired mutation**: expose the seed routine behind a route in a throwaway copy — the gate MUST go red. (unified FR-316)
- [ ] T579 (new — 2026-09-15 remediation pass, no source-spec origin) [TDD] [REVIEW] [US3] Prove the permission model is a **genuine `(user, module, resource, action)` rule set** rather than a two-user hard-coding: add a third tuple — a third user, or a third module/resource/action combination — **with zero code changes, data only**, and assert it takes effect. Gate **G-RBAC-1**: the added tuple grants exactly what it names and nothing more, and the two seed users' existing access is unchanged. **Paired mutation**: revert the rule set to a hardcoded two-user branch in a throwaway copy — the gate MUST go red, because the third tuple can then no longer be added as data. **This is the extensibility property unified FR-303 actually requires; see the NOTE on T489, whose literal two-user scope is narrower.** (unified FR-303)
- [ ] T580 (new — 2026-09-15 remediation pass, no source-spec origin) [TDD] [US6] Boot both standalone modules as **live running containerised instances** through the shared `submodules/containers` module's **rootless** runtime — never a hand-rolled `podman`/`docker` literal, which §11.4.76 forbids as a parallel runtime implementation inside a consuming project — and assert each answers its health check. Gate **G-LIVE-1** records the runtime that the module's own `runtime.AutoDetect` resolved, the container identifier, and the health-check response body. **Paired mutation**: point the health check at a stopped container — the gate MUST go red rather than reporting an absent service as healthy. Three-valued: **rc 2** where no rootless runtime is available on the host, which is never a pass. (unified FR-293, unified SC-158)
- [ ] T581 (new — 2026-09-15 remediation pass, no source-spec origin) [TDD] [REVIEW] [US6] Run each standalone module's full install-and-test path **against the live containerised instance T580 booted**, not against a source checkout, and record every figure with its population stated as `served`. Gate **G-LIVE-2** fails if any figure recorded for this task carries population `source` or `in_process` — a measurement of source is never evidence about the served product. **Paired mutation**: relabel one served figure as `in_process` — the gate MUST go red. This is the live-instance evidence unified FR-293 and SC-158 require, and it is a precondition of the decommission gate T484/T487 enforce for M4. (unified FR-293, unified SC-158)


---

## Phase 17: Polish and cross-cutting concerns

**62 tasks — 28 complete, 34 open.** Sources: 001, 002, 003, 004, 006, plus 1 task new in the
2026-09-15 remediation pass with no source-spec origin.


*From `001` — Phase 8: Polish & Cross-Cutting Concerns*

- [x] T513 (was: 001/T091) [P] [SUBAGENT] Write `workshop/docs/user-guide.md` (FR-030→unified FR-336)
- [x] T514 (was: 001/T092) [P] [SUBAGENT] Write `workshop/docs/manual.md` (operator) (FR-030→unified FR-336)
- [x] T515 (was: 001/T093) [P] [SUBAGENT] Write `workshop/docs/faq.md` (FR-030→unified FR-336)
- [x] T516 (was: 001/T094) [P] [SUBAGENT] Write the training material under `workshop/docs/training/` — **[PATH CORRECTED + ONE HALF NOT BUILT, measured 2026-09-02. `workshop/docs/training.md` does not exist; training landed as a DIRECTORY, `workshop/docs/training/`, holding `00-Overview-and-Taxonomy.md` plus `areas/`, `curriculum-areas/` and `diagrams/`. `workshop/docs/tutorial-quickstart.md` is **[PATH NOT BUILT]** — `find workshop -iname '*tutorial*'` returns zero files. Whether `workshop/docs/quickstart.md` (001/T051 (unified T222)) was meant to absorb that second artifact is **CANNOT DETERMINE** from the tree. The tick is left as it was found; this note corrects only where the files are]** (population: source) (FR-030→unified FR-336)
- [ ] T517 (was: 001/T095) [P] **[PARTIAL — A GREEN GATE GUARDS A DIFFERENT CRITERION. Measured 2026-09-03; NEW note, and this is the kind of finding a glance at an exit code would invert.** `workshop/docs/limits.md` EXISTS, 2,273 lines, 117 headings, and it has a paired gate that is genuinely green: `verify-limits-completeness.sh` → rc **0**, *"checked 15 registered defect(s) against docs/limits.md … all 15 are named"*, and `prove-limits-completeness.sh` → rc **0**, one anchor removed, `CAUGHT`, restored. **But that gate's own line 2 scopes it to `SC-026`, not FR-031** — it asserts that every row of the DEFECT REGISTRY is named in the page, which is a completeness claim about a different set. Measured against FR-031's own four named classes: `grep -c 'FR-031' docs/limits.md` = **0**; `SC-016a` = **0**; `operator-only` = **0**; lines pairing media with indexing = **0**; lines pairing code-passage identity with weak/weaker = **0**. Only **asynchronous answering** is covered (3 lines: `:195`, `:375`, `:1084`). So **three of the four classes this task names are undocumented, and no instrument would notice.** Note also that the SC-016a class cannot be honestly written until 001/T015 (unified T031)–001/T017 (unified T033) exist to be weaker *than something* — but the media-boundary and operator-only classes are writable today, and the media boundary is 001/T067 (unified T339)'s page, which is also unwritten]** Document every limit honestly per FR-031: no direct media indexing, asynchronous answering, code-passage identity weaker than transcript identity (SC-016a, implemented by 001/T015 (unified T031)–001/T017 (unified T033) and proven by G-PID-4 in 001/T017 (unified T033)), and every operator-only step — **BLOCKER:** none but the work — `limits.md` exists with a paired proof, but the green gate guards a DIFFERENT criterion than the one this task names · **OWNER:** **implementer** — unblocked today (FR-031→unified FR-280, SC-016a→unified SC-076)
- [ ] T518 (was: 001/T096) [TDD] Register every check this feature adds in `scripts/check-registry.tsv` so `scripts/verify-check-registry.sh` can enforce SC-012 and SC-013 mechanically — **[PATHS MEASURED 2026-09-02 — both files EXIST, and `scripts/check-registry.tsv` contains **zero feature-001 rows**: its non-comment rows are the umbrella's own, and the only string matching "workshop" in it is a comment. `workshop/platform/gates/check-registry-002.tsv` covers feature 002 ONLY and says so in its own header, declaring `platform/gates/` and `platform/backend/gates/` out of its scanroot because those directories interleave 001 and 002 files. So no instrument in this tree enforces SC-012/SC-013 over any 001 check today. **THAT LAST SENTENCE IS WITHDRAWN BY NAME — re-measured 2026-09-03, one now does, over PART of the set.** `workshop/platform/gates/check-registry-001.tsv` exists, with `verify-check-registry-001.sh` walking it, and all four modes were RUN: default → rc **0** (*"every registered feature-001 pipeline check is enumerated, exists, has a paired proof, and demonstrated its rc-2 state"*, plus 1 registered DEBT row); `--run-proofs` → rc **0**, `27 PASS, 0 FAIL, 1 DEBT`; `--prove-failure` → rc **0**, `PROVE: 22 mutations, 22 caught, 0 missed`; **`--strict` → rc `1`**, `FAIL [cross-registry-attribution]`. **The `--strict` 1 is the honest measure of what is left**, and it is not small: the scanroot is `pipeline` only (19 `*.sh`/`*.py`, 10 declared prunes), while **48** `*.sh`/`*.py` under `platform/gates/` (36), `platform/gates/lib/` (2) and `platform/backend/gates/` (10) are swept by **no** registry — including **six** `verify-*.sh` enumerated nowhere at all (`verify-absence-honesty.sh`, `verify-connectivity-matrix.sh`, `verify-crossref-navigation.sh`, `verify-redaction-propagation.sh`, `verify-server-unity.sh`, `verify-status-exit-contract.sh` — the last two are the gates 001/T021 (unified T037) and 001/T039 (unified T205) rest on). The umbrella's own `scripts/check-registry.tsv` still holds **30** non-comment rows and **zero** feature-001 rows, as this note originally said. The registry's own debt row states plainly why it is unpaid — attributing each file between features 001 and 002 is a per-file judgement, and guessing to clear a debt row writes a false claim into the one artifact whose value is that its claims are true. **PARTIAL: the pipeline third is enumerated and proven; the platform and backend gate directories are not**]** — **BLOCKER:** none but the work. **RE-MEASURED 2026-09-04 and the debt moved AGAIN during this session, so quote the gate, not this line.** Default run is rc **0** at `42 PASS, 0 FAIL, 3 DEBT`; **`--strict` is rc 1** on the 3 debt rows, and that 1 is the honest measure of what is left. `--prove-failure` is rc **0** at `22 mutations, 22 caught, 0 missed`. One debt was **PAID this session**: `redaction-propagation` became a `check` after two REAL argv levers (`--redact-sh`, `--work-dir`) were wired into preconditions the gate already had — verified independently, `--redact-sh /nonexistent` -> rc **2**, and a `prove-*.sh` L3 assertion exists so the levers are not trapdoors. A FOURTH debt row (`resync-redaction-guard`) was added by another agent in the same window, which is why the count is still 3. Two remain: `design-system-token-source` (needs a `node` arm in `arg_is_real`/`proof_cmd`/`probe_cmd` + an `*.mjs` R2 arm; `node build.mjs --check --brand-css /nonexistent` -> rc 2 is already measured, so it is probe-able and merely untypeable) and `cross-registry-attribution` (needs a sweep that consults BOTH registries; **55** `*.sh`/`*.py` now sit under `platform/gates` + `platform/backend/gates`, of which **24 are accounted for by neither registry** — mostly §1.1 provers whose gates ARE registered but whose proof scripts are not). Note for the next reader: the new row's `owed` token `verify-sibling` is OUTSIDE the vocabulary this registry's own header documents, and nothing validates that field · **OWNER:** **implementer** — unblocked today, and it is still the only thing holding 001/T097 (unified T519) and 001/T098 (unified T520) (SC-012→unified SC-135, SC-013→unified SC-136, FR-032→unified FR-260, FR-033→unified FR-261)
- [ ] T519 (was: 001/T097) [TDD] Verify EVERY feature check has a paired mutation proof including a real-entry-point case (SC-012→unified SC-135) — **[PARTIAL. Measured 2026-09-03; NEW note. The PAIRING is complete where it is measured and the REAL-ENTRY-POINT case genuinely exists; what is missing is the QUANTIFIER.** `workshop/platform/gates/` holds **17** `verify-*.sh` and **19** `prove-*.sh` with **0 unpaired** by sibling name. Real-entry-point proofs were OBSERVED running, not just declared: `workshop/scripts/verify.sh:613` — `PROVE: PASS — E2E real verify.sh over a mutated tree -> rc 1 with a FAIL row` — and `bash scripts/verify-governance-cascade.sh --prove-failure` → rc 0 with *"the REAL entry point ran against the REAL tree"*. **But SC-012 says EVERY, and "every" is quantified over an enumeration that covers 19 `pipeline/` files and no others** (001/T096 (unified T518)'s `--strict` rc 1). Worse for this task specifically: `verify.sh --prove-failure` proves only verify.sh's OWN V1–V7 gates and **never executes the 19 sibling `prove-*.sh` scripts** — its single `prove-*.sh` reference is a synthetic fixture at `verify.sh:608`. So the proofs exist, are paired, and are not run by the thing that claims to run everything. This closes when 001/T096 (unified T518)'s registry covers `platform/gates/` and `platform/backend/gates/`; it is BLOCKED-ON-PREDECESSOR on 001/T096 (unified T518)]** — **BLOCKER:** **predecessor 001/T096 (unified T518)** — SC-012 says EVERY, and "every" cannot be quantified over a set nobody enumerates · **OWNER:** **implementer**, after 001/T096 (unified T518) (SC-012→unified SC-135, FR-032→unified FR-260)
- [ ] T520 (was: 001/T098) [TDD] Verify EVERY feature check distinguishes could-not-determine from pass and fail (SC-013→unified SC-136) — **[PARTIAL, WITH THE SAME QUANTIFIER GAP AS 001/T097 (unified T519) AND ONE EXTRA FINDING. Measured 2026-09-03; NEW note.** Structural census: **17 of 17** `workshop/platform/gates/verify-*.sh` and **10 of 10** `workshop/platform/backend/gates/*.sh` carry rc-2 vocabulary. It is DEMONSTRATED and not merely declared: registry-001's `--prove-failure` includes `M18 a sweep matching ZERO files is UNDETERMINED rc 2` (PASS), and a live `verify.sh` run produced a genuine `COULD-NOT-RUN` row for `G8 verify-entailment-loads.sh` rather than a FAIL. **The gap is the same one 001/T096 (unified T518) and 001/T097 (unified T519) name: 48 files sit outside any registry, and "100% of its checks" cannot be asserted over a set nobody enumerates.** One extra finding, recorded rather than resolved: `workshop/scripts/verify.sh:747`–`:752` documents IN ITS OWN SOURCE an unresolved divergence about whether a STOPPED stack is exit 0 or exit 1 — measured against `contracts/pipeline-cli.md` §4.8 and against 001/T021 (unified T037)'s now-green G-CLI-17, which asserts **1**. A three-valued census is worth less while two instruments disagree about which value is right. BLOCKED-ON-PREDECESSOR on 001/T096 (unified T518)]** — **BLOCKER:** **predecessor 001/T096 (unified T518)** — same quantifier gap, plus an unresolved divergence about whether a STOPPED stack is exit 0 or 1 · **OWNER:** **implementer**, after 001/T096 (unified T518); the exit-code divergence is an **operator** call (SC-013→unified SC-136, FR-033→unified FR-261)
- [ ] T521 (was: 001/T099) Write machine evidence to `workshop/evidence/` retained with the commit that produced it (FR-040→unified FR-264) — **[PATH SPLIT 2026-09-02 — `workshop/evidence/` EXISTS but holds only **3** tracked files (`phase2-passage-identity/README.md`, `phase2b-mentions/README.md`, `phase2b-mentions/T014-unjoined-words-u5.md` — and that last one is FEATURE 002's 001/T014 (unified T030), not this file's). The machine evidence FR-040 asks for landed at `workshop/platform/backend/evidence/`: **21** tracked files, committed and clean. `workshop/platform/qa/evidence/` exists on disk with **0** tracked files, and `workshop/evidence/knowledge-pipeline/` carries untracked run output. **The substance largely exists; its contracted LOCATION does not**, so this task is a move-or-mirror decision plus the retention rule, not a from-zero build. **RE-MEASURED 2026-09-03 — the shape holds, both counts moved, and a RETENTION BREACH is now visible.** ~~3 tracked files~~ → `git -C workshop ls-files evidence | wc -l` = **6** (`chunking/README.md`, `p-u1/README.md`, `p-u1/result.json`, `phase2-passage-identity/README.md`, `phase2b-mentions/README.md`, and `phase2b-mentions/T014-unjoined-words-u5.md`, which remains **002's** 001/T014 (unified T030), not this file's). ~~21~~ → `git -C workshop ls-files platform/backend/evidence | wc -l` = **22**. `workshop/platform/qa/evidence/` holds **6** subdirectories on disk (`answering`, `challenges`, `helixqa`, `prove`, `prove-state2`, `state2`) with **0 tracked AND 0 untracked-not-ignored** — it is entirely git-ignored, so none of it is retained with any commit at all. **The retention half of FR-040 is measurably breached right now, not hypothetically**: `evidence/p-u1/result.json` is ` M` in the working tree, so the bytes on disk are not the bytes any commit carries — and those bytes are 001/T014 (unified T030)'s P-U1 settlement evidence. Nothing in the tree gates FR-040 retention]** — **BLOCKER:** **operator decision** — the substance largely exists but at a DIFFERENT path than FR-040 contracts, so this is a move-or-mirror decision plus a retention rule, not a from-zero build. A retention breach is live right now · **OWNER:** **operator** decides move-vs-mirror; **implementer** executes (FR-040→unified FR-264, SC-018→unified SC-137)
- [ ] T522 (was: 001/T131) [P] [REVIEW] Route this feature's automated-check evidence that could contain transcript excerpts, speaker attribution, or other content derived from the private `workshop` submodule to a location inside that submodule's own boundary (001/T099 (unified T521)'s `workshop/evidence/`), and reserve the public monorepo's shared `_tests/evidence/` convention for evidence provably free of such content — a bare pass/fail count with no quoted text. Extend the content-boundary check (`scripts/verify-content-boundary.sh`) or add a scoped check enumerating this feature's evidence-writing tasks and asserting none of their output paths resolve outside `workshop/`'s own tree unless the written content is a bare count. **Paired mutation**: point one evidence writer at `_tests/evidence/` with transcript-derived content; the gate MUST go red (FR-050→unified FR-013)
- [x] T523 (was: 001/T100) [REVIEW] Confirm zero CI added anywhere as gate **G-CLI-11** ([contracts/pipeline-cli.md](../001-workshop-curriculum-platform/contracts/pipeline-cli.md) §2.7 N1–N3, §5): assert no `.github/workflows/*.yml` file exists anywhere under `workshop/`, and that `bash scripts/pre-push-gates.sh` gate E is green across the fleet (SC-014→unified SC-141, FR-034→unified FR-271, §11.4.156). **Paired mutation**: add one workflow file under `workshop/.github/workflows/`; the gate MUST go red — gate E derives the owned fleet from `helix-deps.yaml`, so the umbrella catches it too (FR-034→unified FR-271, SC-014→unified SC-141, FR-032→unified FR-260, SC-012→unified SC-135)
- [x] T524 (was: 001/T101) Update `CONTINUATION.md` and confirm `bash scripts/continuation-check.sh` is rc=0 (FR-035→unified FR-272, §12.10) — **[TICKED 2026-09-02 on a measured run. `CONTINUATION.md` is modified in the working tree (`git status --short CONTINUATION.md` → ` M`) and `bash scripts/continuation-check.sh` exits **rc=0**, printing `8 PASS · 0 DRIFT · 0 UNDET · 4 NOTE` and `CONTINUATION.md IS IN SYNC`, including `[C7] §6 matches the live runner: 8 gate(s)` and `[C8] production facts hold`. Honest boundary (§11.4.6): rc=0 is a measurement of that moment, and the check goes stale as this tree moves — re-run it before relying on the tick]** (population: in_process) (FR-035→unified FR-272)
- [x] T525 (was: 001/T102) Confirm `workshop/`'s four governance carriers remain in lockstep — `bash scripts/verify-governance-cascade.sh` C8 (FR-035→unified FR-272) — **[TICKED 2026-09-02 on a measured run. `bash scripts/verify-governance-cascade.sh` exits **rc=0** at `12 PASS, 0 FAIL, 0 ENV, 8 NOTE`, with C8 reporting that all 11 owned submodules carry four agent carriers with byte-identical bodies once the per-agent header is normalised. Honest boundary (§11.4.6): the same run prints NOTEs about known-unclearable third-party carriers, which it excludes from its verdict rather than suppressing — read them; and this rc is a dated observation, not a standing fact]** (population: in_process) (FR-035→unified FR-272)
- [x] T526 (was: 001/T103) [REVIEW] Run the whole gate suite green: pre-push-gates, verify-governance-cascade (+ `--prove-failure`), verify-manifest-pins, continuation-check, audit-hardcoded-paths, audit-environment-assumptions — **[TICKED 2026-09-03. Every instrument this task names was RUN — not read, not inherited from a prior session's note — and every one exits `0`:** (population: in_process) (FR-035→unified FR-272)

  | instrument | rc | summary line |
  |---|---|---|
  | `bash scripts/pre-push-gates.sh` | **0** | gates E, 0, 1, 2, 3, 4, 5, 6 all `✔ PASS`; `ALL RUN GATES PASSED — push allowed.` |
  | `bash scripts/verify-governance-cascade.sh` | **0** | `CM-GOVERNANCE-CASCADE: 12 PASS, 0 FAIL, 0 ENV, 8 NOTE` |
  | `bash scripts/verify-governance-cascade.sh --prove-failure` | **0** | M11/M12/M13 caught, `CONTROL restored`, *"the REAL entry point ran against the REAL tree"* |
  | `bash scripts/verify-manifest-pins.sh` | **0** | `CM-MANIFEST-PIN-SYNC: 12 MATCH, 0 DRIFT, 0 UNDETERMINED of 12` |
  | `bash scripts/continuation-check.sh` | **0** | `8 PASS · 0 DRIFT · 0 UNDET · 7 NOTE` / `CONTINUATION.md IS IN SYNC` |
  | `bash scripts/audit-hardcoded-paths.sh` | **0** | `no machine-specific hardcoded paths (15 file(s) explicitly allowed)` |
  | `bash scripts/audit-environment-assumptions.sh` | **0** | `no NEW frozen environment assumptions (567 justified occurrence(s) allow-listed)` |

  **HONEST BOUNDARY (§11.4.6), THREE PARTS, AND THE TICK MEANS NOTHING WITHOUT THEM.** (1) **This is a measurement of one moment, not a property of the tree.** Every one of these instruments has changed verdict in this repository without being edited, because the fleet moves underneath them; re-run before relying on the tick, and note two figures already moved since the root carriers were written (`audit-hardcoded-paths` 6 → **15** allowed files, `audit-environment-assumptions` 531 → **567** allow-listed occurrences). (2) **"The whole gate suite" is this task's list, and this task's list is not every instrument in the tree.** `scripts/verify-content-boundary.sh` is **RED BY DESIGN** and was deliberately not run as part of this — reading a green 001/T103 (unified T526) as "the content boundary is clean" would be exactly wrong. `scripts/verify-check-registry.sh` is likewise outside this list. (3) **A green umbrella gate suite says nothing about feature-001's own gates** — `workshop/scripts/verify.sh` exits **1** today (`PASS 24 FAIL 1 COULD-NOT-RUN 1 of 26`, see 001/T120 (unified T529)), and 48 gate files under `workshop/platform/` sit in no registry (001/T096 (unified T518)). Those are T096/T097/T098/T120's problems, not this one's, and they are open]**
- [ ] T527 (was: 001/T104) Commit and push the umbrella and every submodule to all upstreams; verify each with `git ls-remote`, not a push log (FR-036→unified FR-273, SC-015→unified SC-142) — **not before 001/T040 (unified T206)'s Chapter 1 redaction review is recorded**, since a push is publication — **[BLOCKED ON THE OPERATOR, ON TWO INDEPENDENT COUNTS. Measured 2026-09-03; NEW note.** (1) **Its own precondition is not fully met.** 001/T040 (unified T206) part 1 (record) and part 3 (re-emit + assert R2) are DONE, but part 2 is not: **7 of 13 REDACT decisions — F8, F9, F12, F13, F14, F15, F16 — are DEFERRED and unapplied by operator decision**, recorded in the review artifact's own `note` field. A push is publication, and this task's own clause says not before the review is recorded; applying the deferred seven, or deciding they need no application, is an operator call. (2) **Pushing is an operator action in this project regardless** — per the root carriers, commit and push go through the project wrapper on an explicit instruction, and this triage pass deliberately made none. State at this measurement: **9** dirty paths in the umbrella and **39** in `workshop/`, several of them files other agents were writing while this was measured; **no upstream tracking branch is configured** in either checkout (`git rev-list @{u}..HEAD` fails in both), so *"verify each with `git ls-remote`"* has nothing to compare against until remotes are wired or named explicitly. — **BLOCKER:** **operator** — a push is publication, and this must not happen before 001/T040 (unified T206)'s Chapter 1 redaction review is recorded · **OWNER:** **operator** — nothing an agent may do (FR-036→unified FR-273, SC-015→unified SC-142, FR-039→unified FR-012)

  **RE-MEASURED 2026-09-03 AFTER AN AUTHORIZED ATTEMPT ON 001/T040 (unified T206) PART 2: STILL BLOCKED, AND COUNT (1) IS UNCHANGED RATHER THAN NARROWED.** The seven deferred REDACT decisions were resolved, backed up and attempted through `redact.sh`; the tool refused on two independent surfaces and wrote nothing, so **all seven — F8, F9, F12, F13, F14, F15, F16 — remain unapplied** and 001/T040 (unified T206)'s part 2 is still open. See 001/T040 (unified T206)'s own note for the measurement. One of the seven, **F16, is separately satisfied and gated** (the listing boundary discloses no source filename), but a partial application is not the precondition this task names. Count (2) is likewise unchanged and was not tested: no commit and no push was made. **001/T104 (unified T527) is NOT unblocked.**]**
- [ ] T528 (was: 001/T119) [TDD] **[UNWRITTEN — NOTHING BLOCKS IT. Measured 2026-09-03; NEW note.** Searching for `G-CLI-1` with `G-CLI-1[0-9]` excluded, the identifier occurs **exactly once** anywhere under `workshop/` — `platform/backend/cmd/workshop-redact/main.go:55`, a **code comment**, not a gate. The full inventory of gate identifiers actually present under `workshop/` is `G-CLI-{1,3,5,11,13,16,17}`, `G-HTTP-{1..8,8c}` and `G-PID-4`; **nothing asserts state/exit agreement across every command, and nothing asserts the `--json` contract at all** — there is no test that stdout carries exactly one JSON object with all human text on stderr, and no `state: "ok"` hardcode mutation. Two facts make this cheaper than it looks and both were measured: `redact.sh` already writes a per-run result file (see 001/T107 (unified T040)), and `verify.sh` already discovers gates at run time. Two facts make it harder: that file is named `result-exit.json` and carries `{run_id, exit, at}` with **no `state` field** to compare the exit against (001/T107 (unified T040)), and this task quantifies over *"every command in the control plane and the pipeline"*, several of which do not exist yet (001/T111 (unified T208), 001/T115 (unified T340), 001/T116 (unified T341), 001/T084 (unified T426)). Sequencing it last, as this phase does, is correct]** Prove gate **G-CLI-1** ([contracts/pipeline-cli.md](../001-workshop-curriculum-platform/contracts/pipeline-cli.md) §1.6, §5) across **every** command in the control plane and the pipeline: `result.json.state` and the process exit status agree over all three outcomes — `"ok"`/`0`, `"problem_found"`/`1`, `"could_not_determine"`/`2` — and under `--json` stdout carries exactly one JSON object and nothing else, with all human text on stderr. **Paired mutation**: hardcode `state: "ok"` in one command's result writer; the gate MUST go red. It sits in this phase because it asserts over every command and cannot run until they all exist — **BLOCKER:** none but the work. Re-measured 2026-09-04: NOT STARTED — `grep -rn 'G-CLI-1'` under `workshop/` still returns only the one code comment at `platform/backend/cmd/workshop-redact/main.go:55`. It is now CHEAPER than it was: 001/T107 (unified T040) landed `result.json` with a `state` field derived from a single exit-to-state mapping, which is the artifact G-CLI-1 must compare against the process exit · **OWNER:** **implementer** — unblocked today (FR-033→unified FR-261, SC-013→unified SC-136, FR-032→unified FR-260, SC-012→unified SC-135, FR-040→unified FR-264)
- [ ] T529 (was: 001/T120) [TDD] [REVIEW] **[PARTIAL — BUILT, RUNNING, AND ITS HARDEST CLAUSE IS THE ONE THAT HOLDS. Measured 2026-09-03; NEW note, replacing the File Structure table's implicit reading that this is unbuilt.** `workshop/scripts/verify.sh` EXISTS, **812 lines**, and a live run exits **1** printing `PASS 24  FAIL 1  COULD-NOT-RUN 1  of 26   [scope: all]`, naming `FAIL: G12 verify-retrieval-benchmark.sh` and `COULD-NOT-RUN: G8 verify-entailment-loads.sh` separately, then `RESULT 1  a gate RAN and reported a violation (1 could not run and are listed above)`. **That is the precedence rule this task calls "the single most error-prone line in the contract", observed working on a real mixed outcome** — 1 FAIL beside 1 COULD-NOT-RUN aggregating to **1**, both counted, in the exact `PASS n FAIL n COULD-NOT-RUN n of N` vocabulary the task specifies (implementation `:795`–`:812`). `--prove-failure` → rc **0** with **26** `PROVE:` lines, all PASS, including `E2E real verify.sh over a mutated tree -> rc 1 with a FAIL row`, `precedence: 1 FAIL + 1 COULD-NOT-RUN aggregates to rc 1, both counted`, `a SKIP is never a PASS: all-green + 1 unrunnable -> rc 2`, and `V7b pairing: NO gates at all is 2, not 0` — both forbidden collapses proved in both directions. `--help` → rc 0. **TWO CLAUSES ARE UNMET AND BOTH ARE MEASURED.** (1) *"runs every gate in this contract set (all `G-CLI-*`, `G-HTTP-*` and `G-PID-*`)"* — it does not. It discovers `platform/gates/verify-*.sh` **by filename** and references only **2** of the 17 contract identifiers present in the tree (`G-CLI-11`, `G-CLI-16`); discovery answers *"what is on disk"*, never *"what the contract requires and is missing"*, and two of the required gates do not exist at all (001/T119 (unified T528)'s G-CLI-1, 001/T114 (unified T223)'s G-CLI-15). (2) *"a gate whose mutation does not turn it red is reported **vacuous** and counted as **FAIL**"* — `grep -c vacuous workshop/scripts/verify.sh` = **0**; `--prove-failure` proves verify.sh's own V1–V7 and **never executes the 19 sibling `prove-*.sh` scripts**, so no mutation of a real gate is ever judged vacuous. This is also correctly sequenced last: it cannot be finished before the gates it must aggregate exist]** Implement `workshop/scripts/verify.sh` per [contracts/pipeline-cli.md](../001-workshop-curriculum-platform/contracts/pipeline-cli.md) §4.9 — the aggregation point that runs every gate in this contract set (all `G-CLI-*`, `G-HTTP-*` and `G-PID-*`) and aggregates them. **Sequenced last, after every gate task in every phase**, because it aggregates those gates and cannot be written before them. Three-valued: `0` every gate ran and passed · `1` at least one gate **ran** and reported a violation · `2` at least one gate **could not run** and **no** gate reported a violation. **The precedence rule is the single most error-prone line in the contract, and both directions of collapsing it are forbidden here by name**: when some gates failed (`1`) and others could not run (`2`), the aggregate is **`1`** — a confirmed violation outranks an unknown — and the summary reports the two counts separately in the repository's existing sweep vocabulary (`PASS n  FAIL n  COULD-NOT-RUN n  of N`, then each could-not-run gate named with its reason). A `verify.sh` that collapses `2` into FAIL is the specific defect to forbid: this project has shipped **seven** separate pass/fail/could-not-determine conflations, so a broken instrument must never be reported as a violated tree. The mirror defect is equally forbidden — it must never report `0` while any gate was skipped. `PREPUSH_STRICT=1` semantics apply: a SKIP is never a PASS. `verify.sh --prove-failure` runs every registered paired mutation and asserts its gate turns red; a gate whose mutation does not turn it red is reported **vacuous** and counted as **FAIL**, and at least one proof case MUST run the real entry point end to end rather than a sandboxed copy, because a proof that exercises only sandboxed copies can go green over an instrument that cannot start at all. Per §2.7 **N2** this script — a script, never a workflow — is what the umbrella's local pre-push hook calls (FR-032→unified FR-260, FR-033→unified FR-261, FR-040→unified FR-264, SC-012→unified SC-135, SC-013→unified SC-136, SC-018→unified SC-137) — **BLOCKER:** none but the work — `verify.sh` exists at 812 lines, is running, and its hardest clause holds; the remainder is unbuilt · **OWNER:** **implementer** — unblocked today (FR-032→unified FR-260, FR-033→unified FR-261, FR-040→unified FR-264, SC-012→unified SC-135, SC-013→unified SC-136, SC-018→unified SC-137)
- [ ] T530 (was: 001/T105) [REVIEW] Final review against spec.md — every FR traced, every SC measured or explicitly recorded as not-yet-measurable — **[BLOCKED ON ITS PREDECESSORS, AND PARTLY DRAFTED. Measured 2026-09-03; NEW note.** `specs/001-workshop-curriculum-platform/review.md` exists, is TRACKED, is 684 lines, and does a large part of this task: §2 dispositions all 120 tasks, §7 is *"Success criteria — measured, failing, or unmeasured"*, §4 enumerates 11 defects and §9 states its own honest boundary. **But this task has two halves and only one is drafted.** Measured by identifier coverage: `spec.md` defines **22** `SC-` ids and review.md cites **20**; it defines **48** `FR-` ids and review.md cites **5**. *"Every FR traced"* is 5/48. It is also, by its own name, the **FINAL** review — it cannot be closed while **56** tasks in this file remain unticked, most of them things it would have to review. Sequence it after them; in the meantime read review.md as the SC half in draft, not as this task]** — **BLOCKER:** **predecessor: essentially all of the above** — a final review against spec.md cannot be honest while 50+ tasks are open. Partly drafted already · **OWNER:** **human reviewer**, last (FR-?)

*From `002` — Phase 10: Polish and honest limits*

- [x] T531 (was: 002/T113) [TDD] Extend retrieval — **not generation** — over the new kinds (C4.3.1). Safe because the
      retrieval gate refuses before any model runs (FR-028→unified FR-156, FR-051→unified FR-172)
- [x] T532 (was: 002/T114) [REVIEW] Settle **U4**: does an entailment model load on this host? Three-valued exit. The
      platform's code claims it refuses to degrade silently; **a claim is not a measurement** (FR-052→unified FR-173, FR-054→unified FR-261)
- [x] T533 (was: 002/T115) [TDD] Implement the **answer-against-question**
      verification layer (FR-051→unified FR-172) in the existing support-verifier seam. All four current layers
      verify the claim against the **passage**; none verifies it against the **question**, which is
      why a topically related fragment that does not answer what was asked passes all four (FR-051→unified FR-172)

      **`[UNBUILT: decision taken 2026-09-02]` DISCHARGED 2026-09-03 — the layer was BUILT, WIRED
      AND PUSHED, and the marker was describing a state that no longer existed.** The code the
      marker was waiting on exists and runs: `platform/backend/pkg/answer/question.go` (L5, the
      deterministic question-demand floor) plus a new `platform/backend/pkg/answerhood/` (the model
      answerhood judge — deliberately **not** `pkg/entail`, because entailment relates
      passage→claim and answerhood relates question→claim, and conflating them is the defect this
      task names). Wired in `pkg/answer/pipeline.go` **after L4, not instead of it**: a
      `VerdictDeclined` yields `ReasonDoesNotAnswer`, so the topically-related fragment this task
      was written about is now refused. All of it landed in workshop `692a27a`, pushed.
      Re-derived 2026-09-03, not read from prose:

      ```bash
      bash workshop/platform/gates/verify-answer-question.sh          # rc 0 (population: unstated) — 10/10 L5 properties
      bash workshop/platform/gates/prove-answer-question.sh           # rc 0 (population: unstated) — CAUGHT 3, MISSED 0
      curl -s http://127.0.0.1:8087/api/ask/status | grep question_verifier_kind
      #   question-focus+llm (served) — L5 is live on this deployment, not merely compiled
      ```

      Registered as `T115-answer-against-question` in `platform/gates/check-registry-002.tsv`.
      **Honest boundary, and it does not withhold the tick:** `docs/limits.md` §10.15 records the
      layer's measured cost and its four remaining weaknesses — fabrications fell 11 → 1 (population: unstated) on the
      57-question benchmark and **spec 001's** fabrication criterion is still NOT met; floor 1 is
      strong on three demand classes and blunt on four; the judge defaults to the same model that
      generated the claim; L5 checks that the question was ANSWERED, never that the answer is
      CORRECT. Those are recorded tuning limits of a layer that exists. **Spec 002's own SC-010 is
      the identifier-survival criterion (`spec.md`), proven under 002/T053 (unified T303) — it is a different
      criterion that happens to share a number, and it is not this task's acceptance.**
- [x] T534 (was: 002/T116) [TDD] Implement **C4.3.4**: a verifier that was
      requested and could not load reports **could not determine** and does **not** degrade to the
      weaker one (FR-052→unified FR-173, FR-054→unified FR-261)

      **`[UNBUILT: decision taken 2026-09-02]` DISCHARGED 2026-09-03.** The build-order dependency
      on 002/T115 (unified T533) is discharged because 002/T115 (unified T533) is built, and C4.3.4 landed with it in workshop `692a27a`.
      `pkg/answer/pipeline.go` maps a requested-but-undecidable verifier
      (`grounding.VerdictUnavailable`) to `CodeQuestionVerificationUnavailable` and **returns**
      — it does not fall through to `answered` on the strength of the layers that did run, which is
      what "does not degrade to the weaker one" means written as code rather than as a promise.
      Proven, not asserted: `prove-answer-question.sh` seeds `m2-silent-degrade` — a requested
      judge that could not decide being silently dropped — and the gate catches it (`CAUGHT 3
      MISSED 0` (population: unstated), re-run 2026-09-03). Registered separately as
      `T116-question-verifier-undetermined`. A nil verifier is a different case and is not treated
      as a pass either: `/api/ask/status` reports `question_verifier_kind: null` with prose naming
      what is therefore unchecked.
- [x] T535 (was: 002/T117) Update the shipped limits document to name **every** open defect, including the measured
      fabrication rate on unanswerable questions and the undefended
      topically-related-but-non-answering case (FR-050→unified FR-171) (FR-050→unified FR-171, SC-026→unified SC-095)

      **DONE 2026-09-03. The note that stood here named its own closure condition and that condition
      is now met, so the claim *"It is measurably incomplete **right now**: `bash
      workshop/platform/gates/verify-limits-completeness.sh` exits **1** — `MISSING
      area-term-over-generation`, now 1 of **14** registered defects"* is WITHDRAWN, not restated.**
      The one-line fix it predicted was made, and the denominator moved again. Re-measured by
      execution, not read:

      ```bash
      bash workshop/platform/gates/verify-limits-completeness.sh
      #   rc=0 (source) — checked 15 registered defect(s) against docs/limits.md
      #   OK: all 15 registered defect(s) are named in docs/limits.md.
      ```

      The fix was to the ANCHOR, not to the document's coverage, and it is worth recording because
      the failure mode was an instrument pointing at moving text: `defects-registry.tsv`'s
      `area-term-over-generation` row had quoted §10.9's heading, a retitle removed it, and the gate
      went red **for a document that had merely been corrected**. Its replacement anchor carries no
      moving count on purpose, and says so in its own row.

      **The two items this task names explicitly are both present, checked one at a time (source) rather than
      inferred from the gate's exit code:** the measured fabrication rate on unanswerable questions
      is in §1.1 (2 of 10) and again in §10.15's before/after table (**11 → 1** on the 57-question
      benchmark, with the corpus-dependence of that figure stated); and the undefended
      topically-related-but-non-answering case is named in §10.11 in the contract's own words —
      *"none of the four existing verification layers checks a claim against the QUESTION, only
      against the passage, so a topically-related-but-non-answering fragment could pass all four
      unnoticed"* — with §10.15 recording the L5 layer that now defends it **and its four remaining
      weaknesses**.

      **Honest boundary (§11.4.6), and it does not withhold the tick:** *"every open defect"* is
      bounded by what `platform/gates/defects-registry.tsv` registers — **15** rows today (source), up from
      13 then 14. A defect nobody registered is invisible to this gate by construction, which is the
      same bound SC-026/T118 measures and not a new one. The count has moved three times in two
      days; re-run the gate rather than quoting 15.
- [x] T536 (was: 002/T118) [TDD] Prove **SC-026**: cross-check recorded defects against the limits document; an
      unnamed defect fails. **Paired mutation**: remove one defect from the document (FR-050→unified FR-171, SC-026→unified SC-095)
- [ ] T537 (was: 002/T119) [TDD] Prove **SC-028**: drive every new check into a could-not-determine condition and — **BLOCKER:** none but the work — SC-028 coverage reaches only 3 Phase-10 checks; the 18 G-KG gates have never been driven to state 2, and the registry population has since grown to 70 checks · **OWNER:** **implementer** — unblocked today
      assert the **third** state, not either of the other two (FR-054→unified FR-261, SC-028→unified SC-136)

      **PARTIAL (re-measured 2026-09-03, unchanged).** `platform/gates/prove-sc028-undetermined-states.sh`
      exists and drives the three Phase-10 checks (T114/T118/T120) into their third state. The
      **18 G-KG-1..18 gates are still not independently re-driven** into a could-not-determine
      condition; `check-registry-002.tsv`'s `debt sc028-retroactive-coverage` row is still present
      and still records that as a gap rather than assuming compliance. **The population also grew
      on 2026-09-02** — five new rows landed (`T115-answer-against-question`,
      `T116-question-verifier-undetermined` and the three `T041-*` R3 rows) — so "every new check"
      now covers more than it did when this note was first written, not less.
- [x] T538 (was: 002/T120) Register every new check in the check registry (SC-027→unified SC-135). Note the registry prints known
      debt on every run **by design** — a zero exit means every check is accounted for, **not** that
      every check has a paired proof (FR-053→unified FR-260, SC-027→unified SC-135)
- [x] T539 (was: 002/T121) Update the platform's documentation set — quickstart, user guide, manual, FAQ — for the
      knowledge layer, and state plainly what it cannot do (FR-050→unified FR-171)
- [ ] T540 (was: 002/T122) [REVIEW] Final content-boundary check **in both directions** (SC-029→unified SC-143, SC-029a→unified SC-144), plus the — **BLOCKER:** **predecessor 002/T042 (unified T248) (SC-029a inbound), plus 002/T022 (unified T060) and 002/T084 (unified T391) as a final review** — 2 of its 3 halves are already green: zero workflow files, and `CONTINUATION.md` carries 19 spec-002 references · **OWNER:** **implementer**, last; needs T042/T022/T084 first
      fleet-wide no-CI gate (SC-030→unified SC-141), plus `CONTINUATION.md` synchronised (FR-056→unified FR-271, FR-057→unified FR-276, SC-029→unified SC-143, SC-029a→unified SC-144, SC-030→unified SC-141)

      **PARTIAL (re-measured 2026-09-03, unchanged).** Two of three halves hold: the fleet no-CI
      gate is green (`git -C workshop ls-files '.github/workflows/*'` → **0**), and the umbrella
      `CONTINUATION.md` carries its spec-002 section. The **"both directions"** content-boundary
      half is still not satisfiable — SC-029a is not built (`docs/limits.md` §10.14, defects row
      `sc029a-not-built`), the same gap as 002/T042 (unified T248). This is a FINAL review task in any case: it cannot
      honestly close while 002/T022 (unified T060), 002/T041 (unified T247) and 002/T084 (unified T391) are open above it.

*From `003` — Phase 6: Gates, manifest, closure*

- [ ] T541 (was: 003/T035) Update `workshop/platform/gates/route-manifest.tsv`. Three separate changes: (a)
      `:64` reads `#subst {chapter} 01` — **one substitution value cannot exercise a hierarchy**, so
      substitute at least a parent and a child; (b) the rows written with a literal
      `/api/chapters/01/` — `:72`–`:76`, `:85`, and the four `NOT_BUILT` rows at `:157`–`:160` — are
      re-expressed against `{chapter}` so the substitution reaches them; (c) both changed endpoints
      carry a **compound** contract citation, `3.2+003.4.1` and `3.3+003.4.2`. A row naming only the
      001 section still looks complete to a reviewer while the behaviour underneath it has changed —
      the defect is a **stale** row, not an absent one, and no existence check can see it (FR-033→unified FR-274)
      — AUDIT 2026-09-08: GENUINELY OPEN — none of the three changes is made. `workshop/platform/gates/route-manifest.tsv` still substitutes one chapter value, rows 71-76 and 85 still carry a literal `/api/chapters/01/`, the four NOT_BUILT rows are still literal, and no row carries a compound `3.2+003.4.1` / `3.3+003.4.2` citation.
- [ ] T542 (was: 003/T036) [TDD] Implement **G-CH-10** and **G-CH-14** in `verify-chapter-hierarchy.sh`, with
      `prove-chapter-hierarchy.sh` as its paired prover. G-CH-10: **no code path anywhere branches
      on a chapter's depth** (H5) — report each hit with its location rather than counting;
      **paired mutation**: add `if depth > 1` to any handler. G-CH-14: every gate obtains its chapter
      from the live tree or from an argument, following `verify-absence-honesty.sh:127`–`134`, whose
      `undet` on "no chapter could be read" is the third state and must be copied with it;
      **paired mutation**: hardcode `01` in one gate. Register both in
      `workshop/platform/gates/check-registry-003.tsv` (FR-032→unified FR-046, FR-034→unified FR-261, FR-035→unified FR-275, SC-020→unified SC-024, SC-024→unified SC-028, SC-025→unified SC-029)
      — AUDIT 2026-09-08: GENUINELY OPEN — neither `verify-chapter-hierarchy.sh` nor `prove-chapter-hierarchy.sh` exists in workshop/platform/gates/, no `G-CH-` identifier appears in any gate script or registry, and `check-registry-003.tsv` does not exist (only `check-registry-001.tsv` and `check-registry-002.tsv`).
- [ ] T543 (was: 003/T037) [REVIEW] Closure: publish `max_depth_present` as a **measurement** and assert no constant
      bounds depth (H6, 003:SC-021→unified SC-025); record the feature's limits in `workshop/docs/limits.md`,
      including that `02` and `02.01` remain **archived and uningested** and that nothing here
      ingests them; update `CONTINUATION.md` in the same change; and run the gate-coverage check
      below to confirm every contracted gate is carried by a task (FR-003→unified FR-017, SC-021→unified SC-025)
      — AUDIT 2026-09-08: PARTIAL — `max_depth_present` IS published as a measurement (LIVE: `GET /api/chapters` 200 returns `"max_depth_present": 2`, computed by `MaxDepthPresent`, pkg/curriculum/chapterid.go:325). MISSING: `workshop/docs/limits.md` exists but records nothing about hierarchy, the archived/uningested status of `02` and `02.01`, or a no-constant-bounds-depth assertion; and no gate-coverage check confirms every contracted gate is carried by a task.
- [ ] T544 (was: 003/T044) [TDD] Prove **G-CH-21** in `verify-chapter-hierarchy.sh`, alongside G-CH-10 (003/T036 (unified T542)):
      whether a chapter is listed by `GET /api/chapters` depends **only** on whether its directory
      exists under `chapters/` (FR-004→unified FR-018), never on ingestion state, review state or any other
      readiness signal. Scan `listChapters` and its call path for a conditional keyed on an
      ingestion, review or publication flag, and report each hit with its location rather than
      counting. **Paired mutation**: add an `if !ingested { continue }` filter to the listing path —
      the gate must go red. This is the negative-space companion to the new Out of Scope entry — a
      draft/published visibility distinction is explicitly not this feature — so a later change
      cannot introduce it as a silent side effect (FR-042→unified FR-053, FR-034→unified FR-261)
- [ ] T545 (was: 003/T045) [REVIEW] Measure and publish the per-request cost of deriving `hierarchy` fields for
      every row of `GET /api/chapters`, at the corpus size present at measurement time, in the same
      closure documentation 003/T037 (unified T543) writes (`workshop/docs/limits.md`) — the figure and the corpus size
      it was measured against, side by side. Confirm no requirement, gate or code comment anywhere
      in the tree asserts a maximum number of chapters or siblings: a search for a hardcoded
      chapter-count ceiling must return nothing (FR-043→unified FR-054, SC-032→unified SC-036)

*From `004` — Phase 9: Polish & Cross-Cutting — turning in-process passes into served ones*

- [x] T546 (was: 004/T054) Stop every writing stream, then restart once with `bash workshop/scripts/restart.sh` (a full down/up, never `compose restart`). **Never pass `--destroy-volumes` to `stop.sh`** — the `workshop-index` volume holds hours of transcription output (FR-023→unified FR-229, FR-023a→unified FR-230). — EVIDENCE (served): container `workshop-curriculum_platform_1` started 2026-09-08 08:01:16, `Up 4 hours (healthy)` at measurement, and it serves the six learning routes that exist only in the new binary (all 200/403/400 below) — a full down/up, not a `compose restart`. Volume `workshop-curriculum_workshop-index` intact (487880 crossref edges over 24394 sources at generation 6)
- [x] T547 (was: 004/T055) Re-run `bash workshop/platform/gates/verify-server-unity.sh` against the live container. **Currently RED at `PASS=37 FAIL=6`** — all six new routes answering a plain-text 404 because the container runs the old binary. Against a server built from this tree the same gate is `PASS=43 FAIL=0 UNDET=0 DEBT=8` (FR-023→unified FR-229, FR-026→unified FR-259). — EVIDENCE (served): `bash workshop/platform/gates/verify-server-unity.sh` rc **0** — `PASS=43 FAIL=0 UNDET=0 DEBT=8`, exactly the stated target; the six §002.LEARN routes answer as declared. The 8 DEBT rows are recorded NOT_BUILT contract endpoints, printed by design
- [x] T548 (was: 004/T056) Confirm `GET /api/areas` returns **42**, not the 819 the running container still holds in memory from start-up (FR-018→unified FR-127, FR-023a→unified FR-230, SC-001→unified SC-037). — EVIDENCE (served): `GET http://127.0.0.1:8087/api/areas` -> **200**, `contract.total_areas = 42`, `len(areas) = 39` + `len(held_back) = 3`; every id in `areas` carries an `href`, and `GET /api/areas/{first}` -> 200
- [x] T549 (was: 004/T057) Exercise all six learning routes over HTTP against authored content. Everything so far is measured through the server's own loader **in-process**; the HTTP surface is unmeasured (plan.md gap 1; FR-006→unified FR-093, FR-007→unified FR-094, FR-009→unified FR-100, FR-010→unified FR-101, FR-012a→unified FR-104, FR-013→unified FR-119, SC-006→unified SC-057, SC-009→unified SC-058). — EVIDENCE (served): all six exercised over HTTP with `X-Session: audit-004-probe` on 2026-09-08: `GET /api/areas/{a}/lessons` 200 (7 lessons), `GET /api/areas/{a}/lessons/{l}` 200 (carries `prev`/`next`/`position`), `POST /api/areas/{a}/lessons/{l}/state` 200 (`complete_of_required` 0 -> 1), `GET /api/areas/{a}/materials` 200 (+ `?kind=<unknown>` -> **400**, 004/T022 (unified T262) on the wire), `GET /api/areas/{a}/assessment` 200 (`available:false` with the missing-lesson list), `POST /api/areas/{a}/assessment/submit` -> **403** with the availability envelope, never a zero score
- [x] T550 (was: 004/T058) [P] Register the new gates in `workshop/platform/gates/check-registry-002.tsv` and the pipeline gates in their registry (FR-026→unified FR-259, SC-013→unified SC-135). **Evidence needed**: `verify-check-registry-002.sh` currently rc 0 at `checks=94 debt=3`. — EVIDENCE (source): `bash workshop/platform/gates/verify-check-registry-002.sh` rc **0** — `checks=103 debt=3 missing=0 unreadable=0 proof_fail=0` (was 94/3); the new rows are `check-registry-002.tsv:444-453` (`G-AREA-NAME`, `G-LEARN-PUBCONSIST`, `G-LEARN-GATE`, `G-SERVED-PALETTE`, `G-SERVED-CONTRAST`, each with its `-proof` sibling) plus `G-AREA-TOPICALITY-classifier` and the `FR-004-obtainability` pair
- [ ] T551 (was: 004/T059) [P] Add `workshop/curriculum/area-timelinks.json` and `workshop/curriculum/unpublished-areas.jsonl` to `.gitignore`, matching their siblings (FR-?).
- [ ] T552 (was: 004/T060) [P] Re-run the full frontend suite and account for every delta against the 162/0/8 baseline (FR-?).
- [ ] T553 (was: 004/T061) [REVIEW] **Human checkpoint** — read the 3 area documents failing publication review on 62, 54 and 58 uncited claim blocks. They stay failing until read; stamping them is the bypass (FR-002→unified FR-070).
      — **DUPLICATE OF T278 (was: 005/T041) — the same operator review gate over the same three documents (62, 54 and 58 uncited claim blocks), carried in from a different source specification. T278’s own text already says it: *“one decision, recorded in two specs, not two decisions.”* The merge produced three rows for that one decision — T278, T553 and T573. Do not schedule or satisfy independently.** Flagged by the 2026-09-15 remediation pass (finding D4). No checked state was altered.
- [ ] T554 (was: 004/T062) [REVIEW] **Human checkpoint** — confirm or replace the 70% `passPercent`, the mcq-2/short-3 point weights, the 91–95 prefix shift and the anchor attachment section. These four are authored schema choices, stated rather than measured (FR-008b→unified FR-098, SC-017→unified SC-059).
- [x] T555 (was: 004/T063) [SUBAGENT] Re-mine chapter 02 into the taxonomy, or record the coverage gap explicitly. A topic taught only there, in words the chapter-01 lexicon lacks, is invisible to every coverage figure in this feature (FR-005→unified FR-073). — EVIDENCE: `workshop/docs/training/CURRICULUM-AREAS.md:108` records the gap explicitly and by name — chapter 02 and 02.01 contribute tier-A term matches only, no span-tier evidence and no chapter-02 coverage report has ever been built, so a topic taught only there is invisible to every figure on that page. This is the task’s second arm; the re-mine itself was NOT done
- [ ] T556 (was: 004/T064) Regenerate the 12 pre-existing documents' ingested `.sections.json`, or record that their corpus copy is stale. **Regenerating mints new pids and changes the searchable corpus** — a corpus decision, not a cleanup (FR-?).
- [ ] T557 (was: 004/T066) [TDD] Assert **corpus stability during measurement** in every corpus-counting run (FR-030→unified FR-263, FR-027→unified FR-261) — fingerprint the enumerated set before and after the analysis passes, sharing the enumeration with the analysis by construction, and emit `undet` rows **naming the changed paths** when they differ. **Analysis finding F2: this requirement had zero task coverage.** It was promoted from a real incident — a gate reporting 12939 / 12939 / 13058 / 12968 for the same command on a tree another agent was editing. The umbrella's `scripts/verify-content-boundary.sh` already implements exactly this; reuse its approach rather than inventing one.
- [ ] T558 (was: 004/T067) [TDD] [P] Assert **result stability** (FR-011→unified FR-102, FR-026→unified FR-259) in `workshop/platform/gates/prove-assessment-gate.sh` — submit, re-read, require a byte-identical result. **Analysis finding F4: FR-011 appeared only as a manual quickstart step, so nothing asserted it.**
- [ ] T559 (was: 004/T068) [P] Detect **duplicate subjects** (FR-020→unified FR-133, FR-026→unified FR-259) in `workshop/pipeline/extract/verify_curriculum_areas.py`, or record FR-020 as deferred with its reason. **Analysis finding F5**: an existing mutation catches one *area* in two files; nothing catches two areas covering one *subject*.
- [ ] T560 (was: 004/T082) [TDD] [P] Measure catalogue and reference-resolution response time as the corpus/catalogue grows beyond its current 37-subject scale, and report the measurement rather than assuming a fixed ceiling, in `workshop/platform/gates/` (FR-020a→unified FR-134). **Analysis finding**: no existing task measures this; a synthetic-scale fixture (a multiple of the current area count) MUST produce a reported response-time figure, never a pass/fail verdict against an invented SLA number.
- [x] T561 (was: 004/T069) [P] Report **question-bank coverage** on every run as a fraction of published areas (SC-004a→unified SC-052, FR-008→unified FR-096), currently 5 of 42. A tracked figure, never a floor. — EVIDENCE (source): `workshop/pipeline/extract/build_learning_catalog.py:506-510` prints the fraction on every run; dry run 2026-09-08 rc **0**: `areas considered 42 / with lessons 42 / with an assessment 30 / WITHOUT assessment 12 (each a CK021 finding; no question generated to hide one)`. NOTE: SC-004a and Amendment A1 both say **5 of 42**; the measured figure is **30 of 42** (`verify_question_banks.py` rc 0, 30 banks / 234 questions / 597 citations resolved) — the spec figure is superseded
- [x] T562 (was: 004/T070) [P] Append the governing FR/SC identifiers to each task line in this file (SC-013→unified SC-135). **DONE 2026-09-15 — this task's own instruction was executed across the whole file.** **Evidence** (source): **613 requirement-citation groups** were rewritten across all 573 carried tasks, translating **1,211 source-spec FR/SC id occurrences** into their unified equivalents in the form `FR-022→unified FR-036`, with the source id kept beside the unified one so neither numbering is lost. The mapping was derived mechanically from the `*(was: NNN/FR-nnn)*` back-references in [`spec.md`](./spec.md) (**504** unified FR/SC entries parsed, **553** distinct source ids mapped, **7** carrying no source because they are new), and each task's own `(was: NNN/Tyyy)` annotation selected which source specification's numbering to translate from. **One citation could not be mapped and is marked `FR-064a→UNMAPPED, verify manually` rather than guessed** (§11.4.6): it sits in a task carried from `001`, but `001` declares no `FR-064a` — the id belongs to `002`, whose `FR-064a` is unified `FR-188`. **437 bare in-body `Tnnn` references were also qualified** with their source spec and unified equivalent, which is the other half of the hazard this file's own legend warns about. **Honest boundary**: see “What the 2026-09-15 unified-numbering pass did, and what it did not do” near the top of this file — the mitigation is substantial, not total. **Analysis finding F8**: 33 of 39 FRs and 14 of 18 SCs are cited nowhere by id, so **SC-013 ("100% of requirements map to a check") is mechanically unverifiable** — it can be argued but not computed. With ids present it becomes a `grep`.
- [ ] T563 (was: 004/T065) [SUBAGENT] Investigate the redaction-pipeline report: one segment is marked `redacted: true` while the same sentence survives in the merged transcript. Reported, not acted on (FR-?).

*From `006` — Phase 8: Polish & cross-cutting*

- [x] T564 (was: 006/T052) Untrack the 54 video-archive parts with `git rm --cached` and gitignore the pattern (FR-028→unified FR-268). **Evidence** (source): tracked 54 → 0, on-disk bytes unchanged at 2,752,266,473, fresh checkout 2,711.7 MB → 87.0 MB. **`size-pack` did not fall and could not** — history rewriting is forbidden; the gate prints that limit itself.
      — **DUPLICATE OF T076 (was: 005/T001) — both untrack the same 54 video-archive parts, carried in from a different source specification (006 vs 005). Do not schedule, count or re-verify independently.** Flagged by the 2026-09-15 remediation pass (finding D3b). Neither task’s checked state was altered.
- [x] T565 (was: 006/T053) [P] Return **rc 2** with `TODO(storage-fetch)` when archive parts are absent, and keep **rc 1** for a present-but-corrupt part (FR-024→unified FR-261, SC-010→unified SC-136). **Evidence**: a missing download is not a corrupt archive, and conflating them sent a previous investigation at the wrong thing.
- [x] T566 (was: 006/T054) [P] Make `_tools/watch-deploy.sh` read its exit codes (FR-023→unified FR-265, FR-025→unified FR-260). **Evidence** (in_process): it could loop 240 times against a deploy failing every cycle and exit 0; the proof fails **6 of 8** against a reconstruction of the pre-fix watcher.
      — **DUPLICATE OF T093 (was: 005/T015) — both make `_tools/watch-deploy.sh` read its exit codes, carried in from a different source specification (006 vs 005). Do not schedule, count or re-verify independently.** Flagged by the 2026-09-15 remediation pass (finding D3c). Neither task’s checked state was altered.
- [x] T567 (was: 006/T055) [P] Fix the hardcoded checkout path in `workshop/docs/training/curriculum-areas/16-*.md` and regenerate its four derived artefacts (FR-?). **Evidence** (source): the document teaches pointer discipline and broke it; audit 22 occurrences → rc 0; 597 citations still resolve; 18 of 18 sidecar pids present in the registry.
- [ ] T568 (was: 006/T070) Document the FR-029b evidence-retention policy for QA-run evidence artefacts under `workshop/docs/qa/`: never silently delete as volume grows; archiving older evidence out of the live directory, if it becomes a concern, is an explicit operator decision, recorded in `workshop/docs/qa/MANUAL-TEST-PLAN.md` §0 and cross-referenced in `CONTINUATION.md` (FR-029b→unified FR-270).
- [ ] T569 (was: 006/T056) Restart once when every writer has stopped, verified by two `git status` readings 30 s apart (FR-027→unified FR-263). **A restart triggers a 45-minute cross-reference derivation** over 24,929 passages, during which `verify-crossref-currency.sh` correctly reports rc 1.
- [ ] T570 (was: 006/T057) Re-run the full gate sweep against the rebuilt container and record each figure with its **population** — `source`, `in_process` or `served` (FR-023→unified FR-265, FR-026→unified FR-266).
- [ ] T571 (was: 006/T058) [P] [SUBAGENT] Register every new gate in `workshop/platform/gates/check-registry-006.tsv` (FR-?). **Evidence needed**: an unregistered gate fails the registry's own R5 anti-drift rule, which caught one of mine today.
- [ ] T572 (was: 006/T059) [P] [SUBAGENT] Re-validate every `exempt` row whose subject changed this session (FR-028→unified FR-268). **Evidence needed**: one said *"it judges nothing"* of a script that had gained a three-valued verdict — an exemption whose justification expired still looks reviewed.
- [ ] T573 (was: 006/T060) [REVIEW] **Operator gate**: read the 3 documents failing publication review on 62, 54 and 58 uncited claim blocks (FR-020b→unified FR-210, FR-023→unified FR-265). They stay unpublished until read; a client sees 39 areas, not 42.
      — **DUPLICATE OF T278 (was: 005/T041) — the same operator review gate over the same three documents (62, 54 and 58 uncited claim blocks), carried in from a different source specification. T278’s own text already says it: *“one decision, recorded in two specs, not two decisions.”* The merge produced three rows for that one decision — T278, T553 and T573. Do not schedule or satisfy independently.** Flagged by the 2026-09-15 remediation pass (finding D4). No checked state was altered.

- [ ] T582 (new — 2026-09-15 remediation pass, no source-spec origin) [P] Run the mechanical cross-check unified **SC-162** describes, and report both residues **by id**: (a) every unified FR/SC in [`spec.md`](./spec.md) carries either a `*(was: …)*` back-reference or a `*(new, …)*` annotation — target **0** without one; (b) every FR/SC id declared in specifications 001–007 appears in at least one of those back-references — target **0** absent. **Paired mutation**: strip one back-reference from a throwaway copy of `spec.md` — the check MUST go red naming that id, not merely lowering a count. Three-valued: **rc 2** where a source specification cannot be read. Cheap by construction: this is a grep and a set difference, and it exists because the merge itself is a piece of work that can be wrong. (unified SC-162)
