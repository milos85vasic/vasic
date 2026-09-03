---
description: "Task list for Workshop Curriculum Platform"
---

# Workshop Curriculum Platform Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development
> (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn a 1h55m workshop recording into a browsable, semantically searchable curriculum
whose every claim is traceable to a timestamped passage.

**Architecture:** An offline pipeline transcribes the recording into timestamped passages, each
carrying a minted ULID anchored into its source artifact. A Go service serves the curriculum and
a two-path search (lexical FTS5 for type-ahead, embeddings on submit) over a passage registry;
an Angular client renders it. Answering is a pluggable provider seam that refuses rather than
fabricates. Container orchestration is consumed from `submodules/containers`, never reimplemented.

**Tech Stack:** Go 1.26.2 · Angular (Karma/Jasmine) · SQLite + FTS5 (`modernc.org/sqlite`) ·
`faster-whisper` / CTranslate2 CPU int8 · Lumen + ollama embeddings · podman (rootless) via
`digital.vasic.containers` · Python 3.14.6 + Bash for the pipeline.

## Global Constraints

Project-wide requirements. Every task's requirements implicitly include this section. Values are
copied verbatim from spec.md and research.md — do not round them, do not "improve" them.

- **Suggestions ≤ 200 ms p95** (SC-005). Semantic embedding measured **18.2–21.0 s** under load, so
  type-ahead MUST be lexical; FTS5 prefix measured **p95 9.58 ms**.
- **Search results ≤ 2 s p95** (SC-006).
- **≥ 90% of a ≥20-query benchmark returns the expected passage in the top 5** (SC-007).
- **≥ 80% success on queries sharing NO literal words with the target** (SC-008).
- **Transcript accuracy measured over ≥ 30 sampled 30-second AUDIO-TIMELINE windows** (SC-002).
- **Timestamp lands within 5 seconds** of the spoken content (SC-003).
- **100% of citations genuinely support their claim**, verified over ≥ 20 answers (SC-009).
- **≥ 10 unanswerable questions declined 100%, 0 fabricated** (SC-010).
- **Fresh clone to running curriculum in under 15 minutes** (SC-004).
- **A new chapter added in under 30 minutes hands-on, zero code or config change** (SC-011).
- **100% of checks carry a paired failure proof** (SC-012) and **100% distinguish
  could-not-determine from pass and fail** (SC-013).
- **Zero active server-side CI workflows** (SC-014, §11.4.156 — "No escape hatch").
- **WCAG 2.1 Level AA**, zero Level A/AA violations, search fully keyboard-operable (SC-017).
- **No chapter content is exported, published or served until that chapter's redaction review has
  been recorded** (FR-039; [contracts/passage-contract.md](./contracts/passage-contract.md) §7.3 R7;
  [contracts/pipeline-cli.md](./contracts/pipeline-cli.md) §4.6, §4.7 B5). Recording *"none
  required"* is an explicit, valid decision; **skipping the review is not**. FR-039 is measured by
  **no success criterion** — it is enforced only by gate G-PID-5 and publish precondition B5, so
  dropping either leaves the obligation decorative. This is a live obligation and not a
  hypothetical: the Chapter 1 recording features an identifiable third party.
- **The `symbol` matching key that code-passage identity rests on has NO CONFIRMED PRODUCER**
  ([contracts/passage-contract.md](./contracts/passage-contract.md) §10, **P-U1**). §6.2 keys code
  identity on a symbol path, but Lumen exposes no symbol table through its CLI or MCP surface
  (measured: no tool returns chunk identifiers or symbols), so the 58,726-symbol figure comes from
  its internal store rather than from a supported interface. **T015, T016 and T017 are conditional
  on T014 settling P-U1** and MUST NOT be started on the assumption that a producer exists. If T014
  exits `1` — both candidate producers tested, neither yields a stable symbol path — then SC-016a is
  not implementable as specified, and that is an operator decision to record, not something to work
  around. The one outcome forbidden either way is a heuristic that re-points a citation quietly.
- **Container orchestration MUST consume `git@github.com:vasic-digital/containers.git` as a git
  submodule** and MUST extend rather than reimplement it (§11.4.76(1),(4)).
- **Rootless container runtime** (§11.4.161). Host has podman 5.7.1; **docker is absent**.
- **Local/internal only** (decision D1). No content leaves the machine when a local provider is
  configured (FR-024).
- **Corpus is the `workshop/` module plus the `vasic` monorepo** (decision D2). Nothing outside
  this working tree.
- **EVERY component and service MUST be fully decoupled and reusable** (operator directive,
  2026-09-01; FR-043..FR-045, SC-019). Concretely: no Go `internal/` package for anything
  reusable — `internal/` is importable only from within its own module, so it forecloses reuse by
  language rule. Reusable units go in public packages, and where the reuse is genuine they become
  their own module, following the in-repo precedent `digital.vasic.containers`
  (`submodules/containers`, consumed via `replace` in development and a pinned SHA in production).
  The test is concrete: a component that must import a curriculum type to function is not
  decoupled.

## File Structure

Decomposition decisions locked in here. Files that change together live together; split by
responsibility, not by technical layer.

| Path | Responsibility | Where it actually is — measured 2026-09-02 |
|---|---|---|
| `submodules/passage/pkg/passage/` | pid minting, source anchors, registry, resolution, redaction log, code-symbol identity. **The contract every other unit depends on**, and reusable on its own — it knows nothing about curricula | AS NAMED. Holds `pid.go`, `anchor.go`, `registry.go`, `decoupling_test.go` + tests. `resolve.go`, `redaction.go`, `symbol.go`, `ingest_match.go`, `symbol_test.go` are ABSENT — resolution landed inside `registry.go`; the other three are unbuilt (T012, T015, T016, T017) |
| `submodules/verdict/pkg/verdict/` | the 0/1/2 three-valued result type, used by every command and endpoint | AS NAMED (`verdict.go`) |
| `workshop/platform/backend/pkg/transcript/` | immutable machine layer + append-only correction overlay | **[PATH NOT BUILT]** — the directory does not exist and no equivalent landed anywhere (T031) |
| `workshop/platform/backend/internal/store/` | chapter/material persistence. **Deliberately `internal/`** — this is the one genuinely workshop-specific unit; reusing it would mean reusing this curriculum's schema, which no other consumer wants (FR-043 asks for decoupling, not for exporting everything) | **[PATH CORRECTED]** → `workshop/platform/backend/pkg/curriculum/curriculum.go` (`type Store` at `:168`), with its HTTP layer at `internal/api/chapters.go`. Note the consequence for this row's own argument: the unit shipped in `pkg/`, not `internal/` |
| `workshop/platform/backend/pkg/media/` | local range-serve with seek | **[PATH CORRECTED]** → `workshop/platform/backend/internal/api/recording.go` (`http.ServeContent` at `:786`, `Accept-Ranges` `:769`, `416` `Content-Range` `:724`) |
| `workshop/platform/backend/pkg/search/` | lexical leg, semantic leg, and the three-state verdict that fuses them | AS NAMED. `lexical.go`, `semantic.go`, `service.go` present; the three-state type is in `envelope.go`, **not** the `verdict.go` T055 names |
| `workshop/platform/backend/pkg/index/` | generations, verification gate, atomic swap | AS NAMED (`generation.go`) |
| `workshop/platform/backend/pkg/crossref/` | passage relationships, cycle-safe traversal | AS NAMED |
| `workshop/platform/backend/pkg/answer/` | provider seam + the four grounding layers | AS NAMED (`provider.go`, `extractive.go`, `ollama.go`, `schema.go`, `verify.go`, `pipeline.go`) |
| `workshop/pipeline/transcribe/` | VAD, chunking, ASR driver, confidence, checkpointing, coverage | **[PATH NOT BUILT]** — the directory does not exist. What shipped is FLAT under `workshop/pipeline/`: VAD → `audio_energy.py`; ASR driver → `run_faster_whisper.py`; confidence emission → the same file; atomic write → the same file `:179`–`:184`. Chunking and checkpoint/resume are unbuilt; the coverage identity landed in `workshop/platform/backend/pkg/curriculum/curriculum.go` |
| `workshop/pipeline/accuracy/` | frozen normaliser + WER scorer + its mutation proof | **[PATH NOT BUILT]** — the directory does not exist. The normaliser is `workshop/pipeline/compare_engines.py` (`norm_word` `:52`, `align` `:113`); the scorer is `workshop/scripts/verify-accuracy.sh` over it plus `workshop/pipeline/audit_windows.py`; the mutation proof is that script's `--selftest` |
| `workshop/platform/backend/testdata/benchmark/` | the retrieval query set and the answering answerable/unanswerable set — **both**, in one directory, beside the gates that read them (see the benchmark-location correction below) | AS NAMED, but holds `questions.tsv` ONLY. `retrieval.tsv` (T064) is **[PATH NOT BUILT]**, so the "both" this row promises is one |
| `workshop/platform/frontend/src/app/features/` | chapters, transcript, search — one directory each | AS NAMED, and wider: `areas ask chapters curriculum plans practice progress search transcript` |
| `workshop/scripts/` | control-plane scripts over a Go adapter consuming `submodules/containers`' API (**not** its `cmd/boot` — see T021), plus `add-chapter.sh` and `redact.sh` | AS NAMED for the control plane (`build.sh`, `start.sh`, `stop.sh`, `status.sh`, `restart.sh`, `_common.sh`, `_capabilities.sh`, `extract-videos.sh`, `ingest.sh`, `verify.sh`, `verify-accuracy.sh`; the adapter is `workshop/platform/orchestration/cmd/workshop-boot/main.go`). **[PATH NOT BUILT]** for `add-chapter.sh` (T084), `redact.sh` (T038/T039), `transcribe.sh` (T111), `index.sh` (T115), `crossref.sh` (T116), `bench-suggest.sh`/`bench-search.sh` (T065), `bench-answers.sh` (T078 — it shipped elsewhere), `bench-retrieval.sh` (T118) |
| `workshop/docs/` | quickstart, user guide, manual, FAQ, training, and the honest-limits page | AS NAMED for `quickstart.md`, `user-guide.md`, `manual.md`, `faq.md`, `limits.md`. Training shipped as the DIRECTORY `workshop/docs/training/`, not `training.md`; the extension prompt as `workshop/docs/prompts/add-a-chapter.md`. `search.md` (T067) and `answering.md` (T083) are **[PATH NOT BUILT]** |
| `workshop/evidence/` | machine evidence, retained with the commit that produced it | EXISTS but holds **3** tracked files. The machine evidence FR-040 contracts landed at `workshop/platform/backend/evidence/` — **21** tracked files. `workshop/platform/qa/evidence/` exists on disk with **0** tracked files. See T099 |

**Deliberately NOT created**: a bespoke `Containerfile` or compose stack. §11.4.76 makes that a
violation, not a shortcut — orchestration is consumed from the submodule.

> #### FILE PATHS RE-MEASURED 2026-09-02 — this feature was built BY HAND, and the paths moved
>
> The 2026-09-01 block below corrected twelve paths. It was not the whole of it. This feature was
> implemented by hand rather than through `speckit-implement`, and a second, larger set of paths
> diverged from what the tasks name. **A path-existence check over this file therefore misjudges
> tasks in both directions**: it calls finished work unbuilt (the file moved) and it can read an
> existing sibling directory as evidence for a file that was never written.
>
> Two markers now separate the two states, and they must never be blurred:
>
> - **`[PATH CORRECTED]`** — the requirement is satisfied; only the location differs. The real path
>   is written in the task line and the superseded one is named beside it so a reader can tell a
>   corrected path from one that was never wrong. **Nothing about the requirement changed.**
> - **`[PATH NOT BUILT]`** — the named path does not exist AND no equivalent work landed anywhere.
>   The path is left exactly as written, because it is still the destination.
>
> **Ticks were not touched by this sweep**, except for the five ids independently re-measured as
> complete on 2026-09-02 (T049, T063, T065, T101, T102). Correcting where a file is says nothing
> about whether the task is done; those are separate questions and this block answers only the first.
>
> Re-derive the whole sweep rather than trusting it — every path below was checked with `ls`/`test`
> and every line number with `grep -n`:
>
> ```bash
> grep -ohE '`[a-zA-Z0-9_./-]+\.(go|py|sh|ts|md|json|tsv|txt)`' \
>   specs/001-workshop-curriculum-platform/tasks.md \
>   | tr -d '`' | sort -u | while read -r p; do
>       [ -e "$p" ] && echo "EXISTS  $p" || echo "ABSENT  $p"
>     done
> ```
>
> Note the residual limit (§11.4.6): that loop resolves paths relative to the repository root, so a
> bare filename or a path fragment quoted in prose reports ABSENT without that being a finding. It
> is a starting point for re-measurement, not a verdict.

> #### FILE PATHS CORRECTED 2026-09-01 — `passage` and `verdict` are root submodules, not backend packages
>
> ~~`workshop/platform/backend/pkg/passage/` and `workshop/platform/backend/pkg/verdict/`.~~ Both
> paths are **withdrawn**, struck through rather than deleted so a reader can tell a corrected path
> from one that was never wrong. **Twelve task file paths moved** — two rows in the table above and
> `T008`–`T013`, `T015`–`T018`. **No task was renumbered.** Other documents and agent reports cite
> these T-numbers, and renumbering would silently invalidate every one of those citations; the file
> is still `T001`–`T120`, contiguous, and that invariant is verified by parsing the file, not by
> counting.
>
> - *Believed when written (2026-08-31)*: both units would live under the backend module's `pkg/`,
>   which was already the *right* call in spirit — the paragraph below on `pkg/` versus `internal/`
>   is the reasoning that produced it, and it was correct. It just did not go far enough.
> - *Measured 2026-09-01*, re-derivable in one line each:
>
>   ```bash
>   git config -f .gitmodules --get-regexp 'submodule\.submodules/(passage|verdict)\.(path|url)'
>   # submodule.submodules/verdict.path submodules/verdict
>   # submodule.submodules/verdict.url  git@github.com:vasic-digital/verdict.git
>   # submodule.submodules/passage.path submodules/passage
>   # submodule.submodules/passage.url  git@github.com:vasic-digital/passage.git
>   head -1 submodules/passage/go.mod   # module github.com/vasic-digital/passage
>   head -1 submodules/verdict/go.mod   # module github.com/vasic-digital/verdict
>   ls workshop/platform/backend/pkg/   # answer crossref embed index search — no passage, no verdict
>   ```
>
>   Both are now **separately published public repositories**, mounted as submodules at the project
>   root and consumed by the backend through `go.mod` `require` + `replace`, exactly as
>   `digital.vasic.containers` is. `workshop/platform/backend/pkg/` no longer contains either.
> - *When it changed*: during this feature's own implementation work, after the table was written.
> - *What still holds*: everything the `pkg/`-not-`internal/` paragraph below argues. Promotion to
>   a separate module is that argument carried to its conclusion, not a departure from it — and the
>   root placement is required, because §11.4.28 forbids nesting a submodule inside a submodule.
> - *What is NOT claimed*: that the files those tasks name now exist. `submodules/passage/pkg/passage/`
>   currently holds `pid.go`, `anchor.go`, `registry.go` and their tests. `resolve.go`,
>   `redaction.go`, `symbol.go` and `ingest_match.go` are **not there** — T011, T012, T015 and T016
>   remain unbuilt work. Only their destination changed.

> #### BENCHMARK LOCATION DECIDED 2026-09-01 — one directory, one format, beside its gate
>
> ~~`workshop/pipeline/benchmark/` (`queries.yaml`, `unanswerable.yaml`) in this file;
> `workshop/platform/qa/` (`retrieval-benchmark.jsonl`, `answerable-20.jsonl`,
> `unanswerable-10.jsonl`) in [quickstart.md](./quickstart.md).~~ Both are **withdrawn**. The
> canonical location is **`workshop/platform/backend/testdata/benchmark/`**, TSV, and both documents
> now say so.
>
> - *Measured 2026-09-01* — the decisive fact is that neither disputed path exists:
>
>   ```bash
>   ls workshop/pipeline/benchmark/                          # No such file or directory
>   ls workshop/platform/qa/                                 # No such file or directory
>   ls workshop/platform/backend/testdata/benchmark/          # questions.tsv
>   grep -n 'QUESTIONS=' workshop/platform/backend/gates/bench-answers.sh
>   #   QUESTIONS="${QUESTIONS:-$HERE/../testdata/benchmark/questions.tsv}"
>   ```
>
>   Two paths were argued over for a year of document-time and **neither was ever created**. A third
>   location shipped, wired to a working gate, while the argument was in progress. That settles it:
>   the only candidate with a producer, a consumer and bytes on disk wins.
> - *Why this location*: it is where the gate that reads it already looks; `testdata/` is Go's own
>   convention for fixtures a test or gate consumes, and the toolchain excludes it from builds; and
>   it puts the retrieval set beside the answering set instead of splitting two benchmarks of the
>   same corpus across two trees. `workshop/pipeline/` is the transcription pipeline — it neither
>   produces nor consumes either benchmark, so the original placement filed them by topic rather
>   than by who reads them.
> - *Why TSV and not YAML or JSONL*: the shipped file is TSV with a `class<TAB>question` schema and
>   a comment header, matching `platform/gates/route-manifest.tsv`. One format across the tree's
>   fixtures, line-diffable in review, and parseable by `awk` in a gate with no dependency.
> - *Why one file per benchmark rather than one file per class*: `answerable-20.jsonl` /
>   `unanswerable-10.jsonl` encode their counts **in their filenames**, which are wrong the moment a
>   twenty-first question is added, and two files can drift apart. A class column cannot.
> - *What is NOT fixed by this decision, and must not be read as fixed*: ~~`questions.tsv` currently
>   holds **8 `A` rows and 10 `U` rows**. SC-010 needs ≥10 unanswerable — **met**. SC-009 needs ≥20
>   answerable — **8 is not 20, and the shortfall is real**.~~ **WITHDRAWN, not restated — the count
>   moved.** Re-measured 2026-09-02 with the command this bullet already carried:
>
>   ```bash
>   awk 'NR>1 && !/^#/ && NF' workshop/platform/backend/testdata/benchmark/questions.tsv \
>     | cut -f1 | sort | uniq -c
>   #  24 A
>   #  33 U
>   ```
>
>   **24 `A` and 33 `U`.** SC-009's *count* floor (≥20 answerable) is **met**; SC-010's (≥10
>   unanswerable) was already met and is now met three times over. **What is short is the
>   CERTIFICATION, not the count** — SC-009 requires 100% of citations to genuinely support their
>   claim over those answers, and that is T079's open work, not T077's. Canonicalising the path says
>   where the file lives; it says nothing about whether its contents satisfy the criteria. T064
>   remains open work.
> - *Also unbuilt*: `workshop/scripts/bench-retrieval.sh` (T118) does not exist, and no retrieval
>   benchmark file exists at any path. Only the answering half has shipped.

**`pkg/` not `internal/`, and why it is not cosmetic.** Go's `internal/` is importable ONLY from
within its own module — by language rule, not convention. Placing a component there forecloses
reuse permanently, no matter how cleanly it is written. FR-043 to FR-045 therefore put every
reusable unit in `pkg/`. The decoupling test is concrete and checkable: a component that must
import a curriculum type to function is not decoupled, and SC-019 requires each to build and pass
its tests with the curriculum absent.

Where reuse is genuine rather than theoretical, a unit should become its own module, following the
in-repo precedent `digital.vasic.containers` (`submodules/containers`) — consumed via `replace`
during development and a pinned SHA in production. ~~The counter-example is equally instructive:
`LLMProvider` has 43 adapters and the right interface shape but an unresolvable module path and a
relative-path `replace` on a sibling checkout, so nothing can consume it. Reusable in intent,
unusable in fact.~~

> **CLAIM WITHDRAWN 2026-09-02 — `LLMProvider` is no longer the counter-example; it is consumed.**
> The struck-through sentence is left visible rather than deleted so a reader can see that the
> counter-example was retired by work, not by editing. `LLMProvider` and `RAG` both joined the owned
> submodule fleet at the repository root and the backend now `require`s and `replace`s both.
> Re-derive:
>
> ```bash
> grep -n 'llmprovider\|vasic.rag' workshop/platform/backend/go.mod
> #   digital.vasic.llmprovider v0.0.0
> #   digital.vasic.rag v0.0.0
> #   replace digital.vasic.rag => ../../../submodules/RAG
> #   replace digital.vasic.llmprovider => ../../../submodules/LLMProvider
> ```
>
> The `replace` targets are now submodules declared in this repository's `.gitmodules`, not a
> sibling checkout absent from it — which is precisely the difference between "unusable in fact"
> and "consumed". **What is NOT claimed**: that the 43-adapter figure was ever re-measured, or that
> every adapter works. Only the module path and the consumption are measured here.

## Task Format

```
[ID] [markers] [Story] Description
```

**Markers**: `[P]` parallelisable · `[TDD]` RED-GREEN-REFACTOR · `[REVIEW]` review before proceeding · `[SUBAGENT]` delegable

**Numbering is permanent and ids are never reused or renumbered.** Other documents and agent
reports cite T-numbers, so renumbering would silently invalidate every one of them. Tasks added
after the original T001–T105 therefore take new contiguous ids and are appended to the **phase
whose subject they belong to**, which means ids ascend within each phase's appended block rather
than monotonically down the file. Read the phase, not the number, to know when a task runs.

## Path Conventions

The feature lives inside the `workshop/` submodule, mirroring `ai_interviewing/platform`'s
`backend/` + `frontend/` + `bin/` split (plan.md Structure Decision). Container orchestration is
consumed from `submodules/containers` — **never reimplemented** (§11.4.76(4)).

## Standing rules for every task in this file

These come from measurement, not preference. Violating any of them produces work that looks done
and is not.

1. **No check may be added without a paired mutation proof that it FAILS when its guarded
   condition is broken** (FR-032, SC-012, §1.1). Two gates in this repository have already shipped
   with inoperative proofs — one whose control failed so zero mutations ever ran, one that
   exercised only sandboxed copies while the real entry point could not start. Every proof MUST
   include a case that runs the real entry point against the real tree.
2. **Three-valued exit everywhere**: `0` fine · `1` a real problem found · `2` could not
   determine. A missing dependency, unreachable backend or crashed helper is always `2`. This
   conflation has been found and fixed four times here.
3. **An assertion that greps for a string is not a test.** It must execute the behaviour and check
   the observable result — this repo has shipped an assertion that stayed green while the thing it
   tested was deleted.
4. **No CI may be added, including inside `workshop/`** (FR-034, §11.4.156). Gate E now sweeps the
   submodule fleet, so an attempt will be caught.
5. **No frozen host assumptions.** Derive paths, tool locations and tuned values; provide env
   overrides. `ffprobe` is NOT installed here (it is a Playwright symlink), so the pipeline must
   detect its media tooling rather than assume it.
6. **A task MUST NOT assume a capability nobody has verified exists.** Where a task depends on an
   entry in an unverified register, it names the entry and names the task that settles it. T014 and
   the P-U1 constraint above are the worked example.
7. **`SC-###` identifiers COLLIDE with feature 002 — always name the spec before citing one as
   acceptance.** Added 2026-09-03, after the ambiguity produced a wrong acceptance claim. The two
   specs number their success criteria independently and the same number means different things:

   | id | **this** spec (001) | spec **002** |
   |---|---|---|
   | SC-009 | 100% of answer citations genuinely support the claim | a media-backed citation lands inside its cited span |
   | SC-010 | on ≥10 unanswerable questions, **fabricates none** — **NOT met** (see T078) | identifier survival across correction and insertion — **proven** there under its T053 |

   Re-derive before citing, never from memory:

   ```bash
   grep -n '^- \*\*SC-010\*\*' specs/001-workshop-curriculum-platform/spec.md \
                               specs/002-knowledge-areas-deep-linking/spec.md
   ```

   **"SC-010 is proven" is TRUE of 002 and FALSE of this spec.** A bare `SC-010` in a note, a commit
   message or an agent report is therefore not a citation — it is an ambiguity, and it has already
   been resolved the wrong way once. The same applies to SC-009.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: make the module buildable and its dependencies real.

- [x] T001 Create the module skeleton `workshop/platform/{backend,frontend,bin}` and `workshop/{curriculum,pipeline,docs,evidence}` per plan.md Structure Decision — note NO `workshop/containers/` directory: orchestration is consumed from `submodules/containers`, and a local container stack would violate §11.4.76(4)
- [x] T002 Initialise the Go module in `workshop/platform/backend/go.mod` (Go 1.26.2, matching `ai_interviewing/platform/backend/go.mod`)
- [x] T003 Add `replace digital.vasic.containers => ../../../submodules/containers` to `workshop/platform/backend/go.mod` per §11.4.76(2), and verify it builds
- [x] T004 [P] Scaffold the Angular client in `workshop/platform/frontend` mirroring `ai_interviewing/platform/frontend` conventions (package name, Karma/Jasmine, no new UI framework)
- [ ] T005 [P] Create `workshop/pipeline/requirements.txt` pinning `faster-whisper` + `ctranslate2`, and `workshop/pipeline/venv-setup.sh` building a project-local venv — *measured 2026-09-02: `requirements.txt` EXISTS and pins `faster-whisper==1.2.1` + `ctranslate2==4.8.2` with the full transitive set; `workshop/pipeline/venv-setup.sh` is **[PATH NOT BUILT]** — the venv build is prose in that file's header, not an executable script, so only the second half of this task is open*
- [ ] T006 [P] Configure linting/formatting to match the reference module (`gofmt`, Angular ESLint config)
- [x] T007 [REVIEW] Verify `workshop/` still adds zero CI: `git -C workshop ls-files | grep -E '^\.github/workflows/.*\.ya?ml$'` must be empty, and `bash scripts/pre-push-gates.sh` gate E must pass

**Execution notes**: T003 is the §11.4.76 obligation — the build must consume the submodule, not a vendored copy. Verify the module builds before proceeding.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: the passage contract, resolution, redaction identity and environment detection. **No
user story can begin until this phase is complete** — every story depends on the passage identity
contract, and everything that points at content resolves through the one function built here.

- [x] T008 [TDD] [REVIEW] Implement the ULID passage identifier minter in `submodules/passage/pkg/passage/pid.go` per [contracts/passage-contract.md](./contracts/passage-contract.md) — minted at ingest, never positional, never content-derived
- [x] T009 [TDD] Implement the `<!-- pid: … -->` source anchor reader/writer in `submodules/passage/pkg/passage/anchor.go`
- [x] T010 [TDD] Implement the passage registry (`passages.jsonl` → `passages.db`) in `submodules/passage/pkg/passage/registry.go`, with `content_hash` as a change-detection column explicitly documented as NOT identity
- [x] T011 [TDD] **[PATH CORRECTED 2026-09-02 — this task named `submodules/passage/pkg/passage/resolve.go`, which does not exist; the resolver landed in `registry.go` as `func (r *Registry) Resolve(p PID) Resolution` at `:462`, with the four `Outcome` constants at `:299`–`:308`]** Implement the four-outcome resolver in `submodules/passage/pkg/passage/registry.go` per [contracts/passage-contract.md](./contracts/passage-contract.md) §7.1 — `found` · `redacted` · `not_in_registry` · `undetermined`, with NO fallback to fuzzy text matching, nearest-neighbour lookup, prefix matching or same-`content_hash` lookup. `undetermined` is NEVER collapsed into `not_in_registry`: collapsing them makes an unreadable database look like a curriculum that never contained the passage. Every citation, cross-reference and redaction resolves through this one function, and there is no second path
- [ ] T012 [TDD] **[PATH NOT BUILT — `redaction.go` does not exist. Measured 2026-09-02, part of this task landed inside `registry.go` and part did not: the `redactions` DDL is at `registry.go:946` and the `passages.redacted` materialisation at `:128`/`:260`/`:268`, but `registry.go:1091` states in its own source that this package "never writes … redactions", and there is no `Redact`/`Unredact` API anywhere. The WRITER is what remains, and it still belongs at the path named here]** Implement the append-only `redactions` log and the `passages.redacted` materialisation in `submodules/passage/pkg/passage/redaction.go` per [contracts/passage-contract.md](./contracts/passage-contract.md) §4.3 (`redactions` DDL) and §7.3 R2/R6 (FR-039) — a bare column flip is a contract violation, `unredact` is a new append rather than a rewrite of history, and once a pid is redacted its `text` and `machine_text` are absent from every serialisation at every layer. This is the registry half of FR-039; propagation is T059, T061 and T075, and the gate is T076
- [x] T013 [TDD] Prove the two survival guarantees in `submodules/passage/pkg/passage/pid_test.go` as gates **G-PID-1** and **G-PID-2** ([contracts/passage-contract.md](./contracts/passage-contract.md) §5.1, §5.2). **G-PID-1**: create a passage, cite it, correct its text, re-run ingest and re-index, then assert the pid is unchanged, the citation still resolves, `machine_text` is byte-identical to before, and `content_hash` **did** change. **Paired mutation**: make ingest re-mint on `content_hash` change — i.e. reproduce the measured Lumen behaviour; the gate MUST go red, and the contract names this the one mutation that must never be skipped, because it is the precise defect the whole contract exists to prevent. **G-PID-2**: reproduce the measured D-SEARCH-1 run 3 by prepending a section to a transcript so every later section shifts by 4 lines, then assert every pid is unchanged **and** every affected `source_ref` was updated to the new lines — `source_ref` is a cache, never a key. **Paired mutation**: key ingest matching on `(path, line_start)`; the gate MUST go red. (This is SC-016; both alternatives were measured to fail — see research.md D-SEARCH-1)
- [ ] T014 [REVIEW] **[PATH NOT BUILT — `workshop/pipeline/detect_symbols.sh` does not exist and no equivalent landed anywhere; measured 2026-09-02, no P-U1 outcome is recorded under `workshop/evidence/` either]** Settle **P-U1** before any code-identity work begins ([contracts/passage-contract.md](./contracts/passage-contract.md) §10): §6.2 keys code identity on a symbol path, but **that key has no confirmed producer** — Lumen exposes no symbol table through its CLI or MCP surface, so the 58,726-symbol figure comes from its internal store, not from a supported interface. Choose and prove exactly ONE producer in `workshop/pipeline/detect_symbols.sh`: either (a) read Lumen's SQLite store directly and confirm the symbol schema survives a reindex unchanged, or (b) extract symbols with a Go/TypeScript parser owned by this feature. Three-valued exit: `0` a producer is confirmed and named · `1` both candidates were tested and neither yields a stable symbol path · `2` neither could be tested. Record the outcome and its evidence under `workshop/evidence/`. **T015, T016 and T017 are blocked until this exits `0`** — see Global Constraints
- [ ] T015 [TDD] **[PATH NOT BUILT — `symbol.go` does not exist. Measured 2026-09-02, only the SCHEMA landed, in `registry.go`: `Symbol *string` at `:73`, `CREATE UNIQUE INDEX … passages_symbol_key ON passages(path, symbol)` at `:934`, `CREATE TABLE … symbol_aliases` at `:966`. No code reads or writes `symbol_aliases` — `registry.go:1091` names it among the tables this package never writes — so the behaviour this task contracts is still owed at the path named here]** Implement the code-passage matching key `(path, symbol)` and the `symbol_aliases` table in `submodules/passage/pkg/passage/symbol.go` per [contracts/passage-contract.md](./contracts/passage-contract.md) §6.2, §6.4 and the §4.3 `symbol_aliases` DDL (SC-016a) — `origin` separates `authored` (written by the maintainer performing the rename; authoritative) from `detected` (ingest's heuristic, which can mis-attach two similar helpers), so a reviewer can see exactly which links rest on a guess. **Conditional on T014**
- [ ] T016 [TDD] **[PATH NOT BUILT — `ingest_match.go` does not exist and no equivalent landed anywhere]** Implement the §8 ingest matching branches for code passages in `submodules/passage/pkg/passage/ingest_match.go` — R2 attach on `(path, symbol)` · R3 attach through `symbol_aliases`, recording WHICH alias was used so `detected` links stay reviewable · R4 an unaliased rename ⇒ **exit `1`** for `workshop/`-owned code (§6.6 makes an `authored` alias a mandatory step of any rename inside the tree) and, for code outside `workshop/`, mint a new pid and record the orphaned old one so the broken citation is LOUD. Minting stays the last branch (M4). **Conditional on T014**
- [ ] T017 [TDD] **[PATH NOT BUILT — `symbol_test.go` does not exist; measured 2026-09-02 the identifier `G-PID-4` appears nowhere in `submodules/passage`]** Prove **SC-016a** via gate **G-PID-4** in `submodules/passage/pkg/passage/symbol_test.go` ([contracts/passage-contract.md](./contracts/passage-contract.md) §6.5, §6.6): rename a `workshop/`-owned symbol WITH an `authored` alias and assert the pid is preserved and its citations still resolve; then rename one WITHOUT an alias and assert the old pid resolves `not_in_registry` — a loud dead link — and that ingest reports the unaliased rename as exit `1`. **Paired mutation**: make unaliased renames mint a new pid silently and re-point the old citation by nearest-text match; the gate MUST go red. 100% of stale code references failing loudly is the entire criterion — a confident link to the wrong code is the failure it exists to prevent. **Conditional on T014**
- [x] T018 [P] [TDD] Implement three-valued exit helpers in `submodules/verdict/pkg/verdict/verdict.go` (0 / 1 / 2) used by every command and endpoint
- [ ] T019 [P] [TDD] Implement media-tooling detection in `workshop/pipeline/detect_media.sh` — probe `ffmpeg`/`ffprobe` for actual capability, not `--version`; `ffprobe` here is a Playwright symlink that answers `--version` and rejects `-show_format`. Gate **G-CLI-3** ([contracts/pipeline-cli.md](./contracts/pipeline-cli.md) §3.2, §5): point `WORKSHOP_FFPROBE` at Playwright's ffmpeg binary and assert exit `2` with a tooling reason, never `1` — an unusable tool determines nothing. **Paired mutation**: replace the capability probe with `ffprobe --version`; the gate MUST go red, because that binary answers `--version` happily and the probe would pass over a tool that cannot do the job
- [ ] T020 [P] [TDD] Implement backend/model detection in `workshop/pipeline/detect_backend.sh` following `scripts/lumen-reindex.sh`'s env → config → live probe → documented fallback ladder — **[PATH NOT BUILT — `workshop/pipeline/detect_backend.sh` does not exist. Measured 2026-09-02, PART of the substance landed at a different path, for the ANSWERING backend only: `workshop/scripts/_capabilities.sh` carries the env-override rung, a live daemon probe and a documented read-only fallback. The config-file rung and ASR-model-backend detection are absent, so this task is not satisfied by that file — read it before rebuilding, then build the missing rungs]**
- [ ] T021 [P] Create `workshop/scripts/{start,stop,status}.sh` over a Go consuming adapter that calls `submodules/containers`' **Go API** — consumption, not reimplementation (§11.4.76(4)). **Do NOT wrap `cmd/boot`**: measured 2026-09-01, that CLI hardcodes a `helixagent` endpoint, accepts no `ComposeFile`, and constructs `BootManager` with neither an orchestrator nor a health checker, so pointed at this project it **exits `0` having started nothing** — a silent false pass, which standing rule 2 forbids. The adapter constructs the manager with this project's compose file and health checker; anything the adapter needs that the submodule cannot express must be contributed upstream, not forked here. Gate **G-CLI-12** ([contracts/pipeline-cli.md](./contracts/pipeline-cli.md) §4.8, §5): bind the published port with a process whose identity cannot be established and assert `status.sh` exits `2`, not `1` — an unidentifiable holder is could-not-determine, while `DEGRADED` (containers exist but not all are running) is a determined negative and stays `1`. **Paired mutation**: make the unidentifiable-holder branch return `1`; the gate MUST go red. Gate **G-CLI-17** ([contracts/pipeline-cli.md](./contracts/pipeline-cli.md) §4.8, §5) — **assigned to this task 2026-09-02 by operator decision**, because the contract itself calls it the sibling of G-CLI-12 on the same script: `status.sh` against a project with **no containers** prints `STOPPED` **and** exits `1`, a determined negative distinguishable by exit code alone from `RUNNING`'s `0`. Reproduce with `WORKSHOP_PROJECT_NAME=<unused-name> bash workshop/scripts/status.sh`. **Paired mutation**: restore the `return nil` in `cmdStatus`'s `len(statuses) == 0` branch — i.e. reproduce the behaviour measured on 2026-09-01; the gate MUST go red
- [ ] T022 [REVIEW] Review the passage contract implementation against [contracts/passage-contract.md](./contracts/passage-contract.md) before anything consumes it — every other component depends on its shape
- [ ] T106 [TDD] **[PATH CORRECT, FILE PARTIAL — measured 2026-09-02, `workshop/scripts/_common.sh` EXISTS at 273 lines but is the CONTAINER CONTROL-PLANE helper, not the §2.1 contract. Present: the three-valued exit constants, `undetermined()`/`problem()`, derived-never-hardcoded paths, `set -euo pipefail`. Absent: the §2.2 four-rung resolution order over every `WORKSHOP_*` var, the §2.4 `(size, mtime, inode)` fingerprint helpers, the §2.9 self-hash re-check, and the §1.4 `ERR`/`EXIT` traps — `grep -c '^\s*trap '` returns **0**. **Extend that file; do not write a second one**]** Implement the shared wrapper library `workshop/scripts/_common.sh` contracted in [contracts/pipeline-cli.md](./contracts/pipeline-cli.md) §2.1 — sourced, never executed. It owns the §2.2 resolution order **environment → config file → live probe → documented fallback**, identical for every `WORKSHOP_*` variable and copied from `scripts/lumen-reindex.sh` so an operator learns one pattern rather than two, printing at `-v` the host facts it measured and the arithmetic it performed; the §2.4 source-fingerprint helpers that record `(size, mtime, inode)` for every source before a run and re-check them after; the §2.9 self-hash re-check that aborts with `2` and `reason.code: "script_modified_while_running"` when a long-running script is edited mid-flight; and the §1.4 `ERR` and `EXIT` traps. Gate **G-CLI-10** (§1.4, §5): assert every *unclassified* non-zero status maps to `2` — `126`, `127`, `128+N` and any other unclassified non-zero — that only statuses set by a command's own classification logic may be `0` or `1`, and that `3`–`125` stay reserved and unused. **Paired mutation**: remove the `ERR` trap; the gate MUST go red, because a missing binary then surfaces as `127` and a tool that was never there reads as a real problem found
- [ ] T107 [TDD] **[PATH CORRECT, CONTENT NOT BUILT — measured 2026-09-02, no §2.5 evidence writer exists at that path or any other: `grep -rln 'findings.jsonl' workshop --include='*.py' --include='*.sh' --include='*.go'` returns **zero** files, and `result.json` is written by exactly one script, `workshop/scripts/verify-accuracy.sh`, into its own tree with no `manifest.json`, no E2 pre-flight abort and no E4 rule. **Every pipeline wrapper task below depends on this**]** Implement the §2.5 evidence writer in `workshop/scripts/_common.sh` per [contracts/pipeline-cli.md](./contracts/pipeline-cli.md) — every run writes `manifest.json`, `result.json`, `stdout.log`, `stderr.log` and `findings.jsonl` under `$WORKSHOP_EVIDENCE_DIR/<command>/<UTC-timestamp>-<run_id>/`, with **E2**: if the evidence directory cannot be created or written the command exits `2` **immediately, before doing any work**, printing the reason to stderr rather than proceeding unrecorded or attempting to write evidence about failing to write evidence; and **E4**: `api_key_env` records the NAME of an environment variable, never its value and never a file path. Gate **G-CLI-9** (§2.5 E1, §5): assert evidence exists for every run outcome — `0`, `1` and **especially `2`**, the run whose evidence matters most, because a run that determined nothing is the one a reader most needs the record of. **Paired mutation**: skip evidence writing on the failure path; the gate MUST go red (FR-040, SC-018)
- [x] T108 Implement `workshop/scripts/build.sh` per [contracts/pipeline-cli.md](./contracts/pipeline-cli.md) §4.8, building in this order: the `workshop-boot` adapter into `$WORKSHOP_BOOT_BIN`, then the Go backend and the Angular frontend into `workshop/platform/bin/`, then the container image(s) the compose file names — **through the containers submodule, never a direct `podman build`** (§11.4.76(4)). Three-valued exit: `0` everything built · `1` compile, test or image-build failure, a real problem in the code or the compose definition · `2` toolchain missing (Go, Node, **no container runtime detected**), network needed and unreachable, or disk full. "No container runtime detected" is emphatically `2` and never `1`: the host could not be assessed, which is not a finding about the code
- [x] T109 Implement `workshop/scripts/restart.sh` per [contracts/pipeline-cli.md](./contracts/pipeline-cli.md) §4.8 — `stop.sh` then `start.sh`, with the same arguments forwarded to `start.sh`. It is **not** a compose `restart`: a full down/up is what makes the restart honest about picking up a changed compose file or a rebuilt image. Its exit is `start.sh`'s exit, **except** that a `stop.sh` exit of `1` or `2` short-circuits and propagates unchanged — restarting on top of a stack that could not be stopped would report success over an unknown, which is standing rule 2's failure shape at the lifecycle layer
- [x] T110 [TDD] Prove gate **G-CLI-16** ([contracts/pipeline-cli.md](./contracts/pipeline-cli.md) §4.8, §5) — **consumption, not reimplementation** (§11.4.76(4)): assert that no lifecycle path under `workshop/` invokes `podman`, `docker`, `podman-compose` or `docker compose` to bring the stack up or down, and that every such transition goes through `workshop-boot`, which reaches the runtime only through the submodule's `pkg/compose`. Read-only diagnostics on a failure path — tailing a dead container's logs — are exempt, and the gate MUST **show** each exemption to be one rather than assert it. **Paired mutation**: add a `podman-compose up -d` fallback to `start.sh` for when `workshop-boot` is missing; the gate MUST go red, because a well-meaning fallback for a missing binary is exactly the parallel implementation the clause forbids and is the shape drift takes

**Checkpoint**: passage identity is proven to survive correction and movement; code-passage identity
either has a confirmed producer and fails loudly when stale, or P-U1 is recorded as unsettled and
SC-016a is explicitly open. Stop here for human approval.

---

## Phase 3: User Story 1 — Read what was actually said (Priority: P1) 🎯 MVP

**Goal**: a faithful, timestamped, verifiable transcript of Chapter 1.

**Independent test**: open the markdown transcript, read Chapter 1 end to end, sample five passages at random and confirm each is accurate and its timestamp lands on the corresponding moment.

- [ ] T023 [US1] Wire `workshop/pipeline/transcribe/reassemble.sh` to invoke the EXISTING `workshop/scripts/extract-videos.sh` — FR-007 is already implemented there with per-part, archive and extracted-video hash verification; do not reimplement it. **[PATH NOT BUILT — `workshop/pipeline/transcribe/reassemble.sh` does not exist, nor does the `transcribe/` directory. `workshop/scripts/extract-videos.sh` DOES exist, exactly as this task says, and is invoked — but by `workshop/scripts/git-hooks/post-checkout:6` (installed by `workshop/scripts/install-hooks.sh`) and by a documented command in `workshop/docs/quickstart.md:80`, NOT by any pipeline stage. The one pipeline file that names it, `workshop/pipeline/calibrate.sh:67`, prints it as an operator instruction on an exit-`2` path and does not invoke it. **The wiring is what is missing, not the target — do not reimplement extraction**]**
- [x] T024 [US1] [TDD] **[PATH CORRECTED 2026-09-02 — this task named `workshop/pipeline/transcribe/vad.py`, which does not exist; the detector landed at `workshop/pipeline/audio_energy.py`, reading PCM directly and deriving its threshold from the recording's own noise floor (`FLOOR_MARGIN_DB` at `:33`) rather than hardcoding a dBFS constant]** Implement silence detection in `workshop/pipeline/audio_energy.py` producing the non-speech span set (the 8 measured silences totalling 41.33 s are a free test fixture)
- [ ] T025 [US1] [TDD] Implement ≤300 s chunking that cuts INSIDE measured silence, in `workshop/pipeline/transcribe/chunker.py` — **[PATH NOT BUILT — neither `chunker.py` nor the `transcribe/` directory exists, and no equivalent landed anywhere: `workshop/pipeline/run_faster_whisper.py` transcribes a whole WAV (`ap.add_argument("wav")`) and its only "chunk" mentions are the `condition_on_previous_text=False` rationale comment at `:95`–`:96`]**
- [x] T026 [US1] [TDD] **[PATH CORRECTED 2026-09-02 — this task named `workshop/pipeline/transcribe/asr.py`, which does not exist; the driver landed at `workshop/pipeline/run_faster_whisper.py`, which passes `condition_on_previous_text=False` at `:107` and records it at `:153`]** Implement the faster-whisper driver in `workshop/pipeline/run_faster_whisper.py` with `condition_on_previous_text=False` — the same setting that makes it resumable also suppresses repetition-loop hallucination
- [x] T027 [US1] [TDD] **[PATH CORRECTED 2026-09-02 — this task named `workshop/pipeline/transcribe/confidence.py`, which does not exist; the work landed SPLIT ACROSS TWO LANGUAGES: emission in `workshop/pipeline/run_faster_whisper.py:118`–`:119` (`avg_logprob`, `no_speech_prob` per segment), mapping in `workshop/platform/backend/cmd/ingest-transcript/main.go:77`–`:78` (`Uncertain`, `UncertainReason`) applied at `:313`–`:322`]** Map engine confidence (`avg_logprob`, `no_speech_prob`) to the `uncertain` flag across `workshop/pipeline/run_faster_whisper.py` and `workshop/platform/backend/cmd/ingest-transcript/main.go` — FR-003 requires marking, never guessing
- [ ] T028 [US1] [TDD] Implement atomic checkpoint/resume (write-temp → fsync → rename) in `workshop/pipeline/transcribe/checkpoint.py` per FR-029 — **[PATH NOT BUILT for the CHECKPOINT half; the ATOMIC-WRITE half moved. Measured 2026-09-02: `checkpoint.py` and the `transcribe/` directory do not exist, but `workshop/pipeline/run_faster_whisper.py:179`–`:184` already implements exactly the contracted shape — `tmp = out.with_suffix(out.suffix + ".tmp")` → `json.dump` → `fh.flush()` → `os.fsync(fh.fileno())` → `tmp.replace(out)`. Do NOT rebuild that. What is genuinely absent is checkpoint/resume across chunks and any `--resume` flag, and it depends on T025's chunker, which is also unbuilt]**
- [ ] T029 [US1] [TDD] **[PATH CORRECTED 2026-09-02 for the IDENTITY, `[PATH NOT BUILT]` for the GATE — this task named `workshop/pipeline/transcribe/coverage.py`, which does not exist. The identity landed in Go, in the backend: `workshop/platform/backend/pkg/curriculum/curriculum.go` `ComputeCoverage` at `:428`, `UnexplainedGapS` at `:503`, `Complete = UnexplainedGapS == 0` at `:504`, the identity string in the `Identity` field at `:376`; it is served at `internal/api/chapters.go:177`/`:362` and made a contract violation for a published chapter at `:216`. **Do not rebuild the arithmetic.** Gate G-CLI-4 and its tolerate-gaps mutation are what remain, and they must gate whatever actually computes coverage — which is this Go path, not a Python module]** Implement the coverage identity check in `workshop/platform/backend/pkg/curriculum/curriculum.go`: passage spans ∪ VAD silence MUST equal `[0, duration_s)` exactly — this makes SC-001 arithmetic rather than judgement. Gate **G-CLI-4** ([contracts/pipeline-cli.md](./contracts/pipeline-cli.md) §4.1, §5): delete one chunk's output and assert the coverage check reports exit `1`. **Paired mutation**: make coverage tolerate gaps under a threshold; the gate MUST go red — this is the mutation proof D-TRANS-4 names
- [ ] T030 [US1] Emit the markdown transcript with pid anchors and timestamps to `workshop/curriculum/chapter-01/transcript.md` — **[PATH CORRECTED 2026-09-02 — this task named `workshop/chapters/01/transcript/transcript.md`; that directory does not exist (`workshop/chapters/01/` holds the recording and its archive parts only) and the timestamped transcript landed at `workshop/curriculum/chapter-01/transcript.md`. The TIMESTAMP half is built; the **pid-anchor half is not** — `grep -rl '<!-- pid:' workshop --include='*.md'` returns zero files across the whole submodule, and passage identity currently lives only in `workshop/curriculum/passages.jsonl`]**
- [ ] T031 [US1] [TDD] Implement the immutable machine layer + append-only correction overlay in `workshop/platform/backend/pkg/transcript/layers.go` per FR-038 — the machine output is evidence and must survive correction. **[PATH NOT BUILT — neither `layers.go` nor the `pkg/transcript/` directory exists, and no equivalent landed anywhere. The nearest thing on disk is the `corrections` DDL at `submodules/passage/pkg/passage/registry.go:936`–`:944`, which `registry.go:1091` says that package never writes; a table declaration is not the layered type this task contracts]**
- [ ] T032 [US1] [P] **[PATH NOT BUILT — `pdf_notes.py` and the `transcribe/` directory do not exist, and no gazetteer exists anywhere: `grep -rli gazetteer workshop` returns zero files. `workshop/pipeline/extract/meeting_notes.py` looks adjacent but is NOT this work — its own header says it extracts from the chapter's own TRANSCRIPT, not from the notes PDF]** Extract the notes PDF text layer in `workshop/pipeline/transcribe/pdf_notes.py` for section structure and a proper-noun gazetteer ONLY — never ground truth; it is a summary and it renders "Spatkit" for SpecKit
- [x] T033 [US1] [TDD] [REVIEW] **[PATH CORRECTED 2026-09-02 — this task named `workshop/pipeline/accuracy/score.py`; neither it nor the `accuracy/` directory exists. The scorer landed as `workshop/scripts/verify-accuracy.sh`, driving `workshop/pipeline/compare_engines.py` (`align` `:113`, `norm_word` `:52`) and `workshop/pipeline/audit_windows.py` (`a_words_in`), imported at `verify-accuracy.sh:170`–`:178`, with `--windows`/`--seconds`/`--seed` recorded so the sample reproduces]** Implement the WER scorer in `workshop/scripts/verify-accuracy.sh` over `workshop/pipeline/compare_engines.py` and `workshop/pipeline/audit_windows.py`, sampling the AUDIO TIMELINE (≥30 stratified 30 s windows), not passages — sampling passages makes whole-region deletions structurally invisible and biases accuracy upward exactly where the transcript is worst
- [ ] T034 [US1] Freeze and hash the normaliser in `workshop/pipeline/compare_engines.py` BEFORE the first measurement — **[PATH CORRECTED 2026-09-02 — this task named `workshop/pipeline/accuracy/normaliser.py`; neither it nor the `accuracy/` directory exists, and the normaliser landed inside `workshop/pipeline/compare_engines.py` (`norm_word` `:52`, `align` `:113`), which `workshop/scripts/verify-accuracy.sh:112` resolves as `$NORMALISER`. **The FREEZING is what is missing, not the normaliser**: `verify-accuracy.sh` measures its sha256 on every run and enforces it only when `--normaliser-sha256` is passed (default empty at `:113`), and no frozen hash is committed anywhere — no `*.sha256` under `workshop/pipeline/`, no normaliser record under `workshop/evidence/`]**
- [ ] T035 [US1] [TDD] Paired mutation proof for the scorer in `workshop/scripts/verify-accuracy.sh --selftest` — a transcript with a known injected WER must produce that WER. **[PATH CORRECTED 2026-09-02 — this task named `workshop/pipeline/accuracy/score_mutation_test.sh`; neither it nor the `accuracy/` directory exists, and the mutation harness landed inside the scorer wrapper as `workshop/scripts/verify-accuracy.sh --selftest` (`:88`, `:140`, `:393`, `:405`). **Do not build a second harness** — extend that one. What is genuinely missing is THIS task's assertion: the existing selftest degrades a reference and checks that a threshold is crossed, which is not the same as asserting that a KNOWN INJECTED WER produces THAT WER]**
- [x] T036 [US1] Run the 5-minute calibration on the extracted 300 s sample; this settles research open items U1, U2 and U3 in one run
- [ ] T037 [US1] Produce and publish the accuracy report for Chapter 1 with the measured figure and its confidence interval — **[OPEN. THE RUN HAPPENED AND RETURNED A CORRECT `CANNOT DETERMINE`; B2 IS STILL NOT MET.** Re-measured 2026-09-03. **Three claims this note used to carry are WITHDRAWN, not restated:** *"`workshop/chapters/01/transcript/` does not exist"*, *"`find workshop -name 'accuracy*.json'` returns zero files"*, and the destination question recorded as **CANNOT DETERMINE**. The directory exists and holds one file — `workshop/chapters/01/transcript/accuracy-plan.json` (3,970 bytes) — and `find` now returns exactly that one and no `accuracy.json`. **The destination question is settled by construction, not by opinion**: the plan landed at `chapters/01/transcript/` and `verify-accuracy.sh`'s own `OUT_DEFAULT="$CHAPTER_DIR/transcript/accuracy.json"` writes to that same directory, so the report path and the B2 path agree — the report belongs beside the *recording*, and T030's transcript sitting under `workshop/curriculum/chapter-01/` does not move it. **What was actually run:** `bash workshop/scripts/verify-accuracy.sh 01` exits **2** with `UNDETERMINED: --reference is required`, and that is the correct answer rather than a failure — **no blind human reference exists, and an engine cannot be its own ground truth**. `accuracy.json` is deliberately NOT written on this path, so `GET /api/chapters/{c}/accuracy` keeps reporting `measured: false, wer: null` instead of acquiring a file that says nothing. Publish precondition **B2 is NOT met** and must not be recorded as met. The deliverable that DOES exist is the sampling plan: **30 of 30** windows placed (`shortfall: 0`) at 30.0 s each, seeded `0` so the sample is reproducible, stratified across high/mid/low-confidence strata over 6,928.713 s of audio, with a `how_to_use` field whose instruction is that each window be transcribed **BLIND — from the audio alone, without reading the machine transcript** — because a reference derived by editing the engine's own output measures nothing. Producing that reference is human work and is the only thing standing between here and a figure. **A SECOND, STRUCTURAL DEFECT, RECORDED AND NOT FIXED HERE: as written this task CANNOT BE SATISFIED even once a reference exists.** It demands the measured figure **AND its confidence interval**; `accuracy.json` has no field for one and the scorer never computes one. Measured: the payload built at `verify-accuracy.sh:724` carries `measured`, `wer`, `accuracy`, `chapter`, `measured_at`, `tool`, `method`, `counts`, `sample`, `windows`, `normaliser`, `transcript`, `reference`, `min_accuracy`, `companion_metrics` and `verdict` — no interval — and `grep -rin 'confidence_interval|ci_low|ci_high|bootstrap|margin_of_error' workshop/scripts/ workshop/pipeline/` returns **0** across `.sh` and `.py`. The demand traces to `research/transcription.md:856` ("15 minutes of audio is a sample, and a point estimate quoted without a stated confidence interval..."), so it is a real requirement, not a drafting slip. Closing it needs EITHER a spec amendment dropping the interval OR a T112 change computing and emitting one — **that is an operator decision and it is not taken here**]**
- [ ] T038 [US1] [TDD] **[PATH NOT BUILT — `workshop/scripts/redact.sh` does not exist and no equivalent landed anywhere; it also depends on T012's writer, which is itself unbuilt]** Implement `workshop/scripts/redact.sh` per [contracts/pipeline-cli.md](./contracts/pipeline-cli.md) §4.6 (FR-039) — `--pid P` (repeatable), `--pids-file F`, mandatory `--reason CODE` and `--by NAME`, `--unredact`; it appends to the `redactions` log built in T012, materialises `passages.redacted`, and marks the live generation as requiring a rebuild. Exit `1` when a supplied pid is not in the registry or a pid is re-redacted under a different reason; exit `2` when the registry is unwritable or the rebuild that makes the redaction effective could not be started. It lands in THIS phase, not a later one, because Chapter 1's transcript exists from T030 onward and FR-039 blocks export before review
- [ ] T039 [US1] [TDD] **[PATH NOT BUILT — `redact.sh` does not exist, and `find workshop -name 'redaction-review.json'` returns zero files. Do not mistake `workshop/curriculum/publication-reviews.jsonl` for this artifact: it is feature 002's per-AREA publication review, keyed on `area_id` and read by `pkg/knowledge/reviews.go` — a different artifact for a different obligation]** Implement `redact.sh --review-only` and the review artifact `workshop/chapters/NN/redaction-review.json` per [contracts/pipeline-cli.md](./contracts/pipeline-cli.md) §4.6 and [contracts/passage-contract.md](./contracts/passage-contract.md) §7.3 R7 — recording *"none required"* is an explicit, valid decision; **skipping the review is not**, and a review older than the transcript it reviews is stale and exits `1`. This artifact is publish precondition B5 (§4.7, enforced by T087); without it FR-039 is decorative
- [ ] T040 [US1] [REVIEW] Record the Chapter 1 redaction review and apply whatever it identifies, BEFORE the transcript is exported, published, served or committed (FR-039). This is not a fixture and not a hypothetical: the Chapter 1 recording features an identifiable third party, which is the reason FR-039 exists. Re-emit `workshop/curriculum/chapter-01/transcript.md` after redaction and assert that no redacted passage's `text` or `machine_text` appears anywhere in it (§7.3 R2). **[PATH CORRECTED 2026-09-02 — this task named `workshop/chapters/01/transcript/transcript.md`, which does not exist; see T030]** No later phase may publish, export or serve Chapter 1 until `redaction-review.json` exists and is newer than the transcript
- [ ] T041 [US1] [REVIEW] Human review checkpoint: speaker attribution is HUMAN (D-TRANS-2 — the recording is dual-mono at −90.3 dB and AGC-flattened, so both diarization cues are measurably absent)
- [ ] T111 [US1] [TDD] **[PATH NOT BUILT — `workshop/scripts/transcribe.sh` does not exist and no `--resume`/`--from-parts`/`--chunk-seconds`/`--sample-seconds` wrapper landed anywhere. Note it is contracted over T024–T029, whose modules moved (see each) and two of which are unbuilt]** Implement the `workshop/scripts/transcribe.sh <chapter-slug>` wrapper per [contracts/pipeline-cli.md](./contracts/pipeline-cli.md) §4.1 over the T024–T029 modules — `--resume`, `--from-parts`, `--chunk-seconds`, `--model`, `--threads`, `--sample-seconds` (the calibration run T036 uses) and `--dry-run`. Its progress figure is projected **from the measured rate so far, never from the D-TRANS-1 estimate**, which is itself UNVERIFIED. Exit `1` for an unexplained coverage gap, a VAD-declared silence contradicting a measured long silence, a source `(size, mtime, inode)` change during the run, or an `extract-videos.sh` checksum mismatch; exit `2` for ffmpeg/ffprobe unusable, venv or model missing, a crashed helper, disk full, an unsatisfiable RAM cap, a held lock, interruption, or a part `extract-videos.sh` could not read. Gate **G-CLI-2** (§2.4 S1–S4, §5): run the full pipeline and assert every source file's `(size, mtime, inode)` is unchanged, since sources are opened `O_RDONLY` and derived artifacts land only under `chapters/NN/transcript/`, `curriculum/`, `_evidence/` and `.locks/`. **Paired mutation**: have transcribe rewrite the notes PDF in place; the gate MUST go red (FR-006)
- [x] T112 [US1] [TDD] Implement the `workshop/scripts/verify-accuracy.sh <chapter-slug>` wrapper per [contracts/pipeline-cli.md](./contracts/pipeline-cli.md) §4.2 over T033's scorer — `--reference` (required), `--windows 30`, `--seed` (recorded, so the sample is reproducible), `--normaliser` (whose SHA-256 must match T034's frozen hash) and `--min-accuracy` — writing `chapters/NN/transcript/accuracy.json`, which is publish precondition B2. Gate **G-CLI-5** (§4.2, §5): run with `--reference` pointing at a nonexistent file and assert exit `2`. **Paired mutation**: return `0` with `wer: 0.0` when the reference is absent; the gate MUST go red. This is the most important line in §4.2 — **the absence of a human reference is `2`, never `0`** — because a command that cannot measure accuracy must not report that accuracy is fine, and until this has run `GET /api/chapters/{c}/accuracy` reports `measured: false, wer: null` (SC-002, SC-013). **RUN 2026-09-03, and the "most important line" was exercised for real rather than only in a gate: `bash workshop/scripts/verify-accuracy.sh 01` exits `2` with `UNDETERMINED: --reference is required`, writes no `accuracy.json`, and says why in its own words. The tick was already earned by the build; what is new is that the behaviour is now confirmed against the real chapter and not only against the G-CLI-5 fixture.** Its `--emit-plan` path produced `workshop/chapters/01/transcript/accuracy-plan.json` — 30 of 30 seeded, stratified windows. **Honest boundary (§11.4.6), and it belongs to T037, not here: this wrapper emits no confidence interval and computes none, which T037 requires — see T037's own note**
- [ ] T113 [US1] [TDD] Implement the `workshop/scripts/ingest.sh [<chapter-slug>]` wrapper per [contracts/pipeline-cli.md](./contracts/pipeline-cli.md) §4.3 over T010's registry and T016's matching branches — `--write-anchors` (default on for `workshop/`-owned text), `--no-write-anchors`, `--kinds`, `--corpus` (D2), `--dry-run`, `--check-idempotent` — writing a sorted, byte-stable `curriculum/passages.jsonl` plus `passages.db`, anchors back into `workshop/`-owned text sources, and sidecars for anchorless formats. It implements [contracts/passage-contract.md](./contracts/passage-contract.md) §8 exactly and restates none of it, so the two cannot drift. Exit `1` on a duplicate anchor (R1b), a foreign anchor (R1c), an unaliased rename of `workshop/`-owned code (R4), a non-idempotent second run, a pid collision, or a passage violating a field invariant F1–F7; exit `2` when the registry is unreadable or locked, the symbol source is unavailable (P-U1, T014), disk is full, or the run was interrupted. Gate **G-PID-6** ([contracts/passage-contract.md](./contracts/passage-contract.md) §8.1): run ingest twice over unchanged inputs and assert **I1–I6** by diffing the tree and counting mints — zero pids minted, zero anchors written, a byte-identical `passages.jsonl`, every source byte-identical, no new index generation, exit `0`. **Paired mutation**: make R5 unconditional so it mints whenever no anchor was *read this run*; the gate MUST go red on I1, I3 and I5 simultaneously (FR-027)

**Checkpoint**: transcript exists with a measured accuracy figure AND a recorded redaction review. Stop for human approval — everything downstream inherits this artifact's quality, and nothing downstream may publish Chapter 1 without that review.

---

## Phase 4: User Story 2 — Browse and watch (Priority: P2)

**Goal**: the curriculum is browsable and the recording plays.

**Independent test**: start with the documented command, confirm Chapter 1 is listed, its materials readable, its recording plays.

- [x] T042 [US2] [TDD] **[PATH CORRECTED 2026-09-02 — this task named `workshop/platform/backend/internal/store/chapter.go`; neither it nor the `internal/store/` directory exists. The store landed at `workshop/platform/backend/pkg/curriculum/curriculum.go` (`type Store` at `:168`, `ComputeCoverage` at `:428`), with its HTTP layer at `internal/api/chapters.go`. It is therefore in `pkg/`, which contradicts the File Structure row that argued for `internal/` — recorded rather than reconciled here]** Implement the chapter model + store in `workshop/platform/backend/pkg/curriculum/curriculum.go` per [data-model.md](./data-model.md)
- [x] T043 [US2] [TDD] Implement `GET /api/chapters` and `GET /api/chapters/{slug}` per [contracts/http-api.md](./contracts/http-api.md)
- [x] T044 [US2] [TDD] Implement `GET /api/chapters/{slug}/transcript` returning passages with pid, timestamps, provenance and uncertainty
- [x] T045 [US2] [TDD] **[PATH CORRECTED 2026-09-02 — this task named `workshop/platform/backend/pkg/media/serve.go`; neither it nor the `pkg/media/` directory exists. Range-serve landed at `workshop/platform/backend/internal/api/recording.go`, delegating to `http.ServeContent` at `:786` for `Accept-Ranges` (`:769`), `206`, `Content-Range`, `416 bytes */total` (`:724`) and `If-Range`, with multi-range rejected explicitly before it reaches `ServeContent`]** Implement local recording range-serve with seek in `workshop/platform/backend/internal/api/recording.go` — a local file with HTTP range support (decision D3), NOT a streaming service
- [x] T046 [US2] [P] [SUBAGENT] Build the chapter list and detail views in `workshop/platform/frontend/src/app/features/chapters/`
- [x] T047 [US2] [P] [SUBAGENT] Build the transcript reader with timestamp→recording seek in `workshop/platform/frontend/src/app/features/transcript/`
- [x] T048 [US2] [P] Reuse `design-system/learning-kit/` curriculum CSS (verified present, framework-free, on the `--od-*` token contract) rather than authoring new styling
- [x] T049 [US2] [TDD] Persist reader position/progress per FR-010 — **[TICKED 2026-09-02 after independent re-measurement. Backend: `workshop/platform/backend/internal/api/progress.go` — `type ProgressStore` `:46`, `Get` `:90`, `Put` `:110`, `ProgressHandler` `:156` serving `MethodGet` `:167` and `MethodPost` `:186`. The route is live and gated: `cmd/workshop-server/web_test.go:356`–`:358` fails if `POST /api/progress` 404s, and `:364` holds every other verb to 404. Frontend: `workshop/platform/frontend/src/app/core/progress.ts:4` cites FR-010 (T049) over a per-chapter local store. Honest boundary (§11.4.6): no Go test suite was executed for this tick — the assertions were read, not run]**
- [x] T050 [US2] [TDD] Prove SC-003: transcript passage → recording seek lands within 5 s, in `workshop/platform/frontend/src/app/features/transcript/seek.spec.ts`
- [ ] T051 [US2] Write `workshop/docs/quickstart.md` and time a fresh-clone-to-running run against SC-004's 15-minute budget — *path is correct: `workshop/docs/quickstart.md` EXISTS. **The MEASUREMENT is what is open**, not the document: no fresh-clone-to-running wall clock appears in it, so SC-004 is unmeasured*
- [ ] T114 [US2] [TDD] Prove gate **G-CLI-15** ([contracts/pipeline-cli.md](./contracts/pipeline-cli.md) §4.8, §5) — the **containers-actually-booted anti-bluff** (§11.4.76(5)): after `start.sh` exits `0`, assert the container runtime reports the compose project's containers **running** and that `/api/health` was answered by one of them **through the published port**, never against a container's internal address, which would pass while the port mapping is broken. A green control plane MUST imply the infra was up. It lands in this phase rather than with T021 because this is the first phase in which the stack actually serves an HTTP endpoint to probe. **Paired mutation**: replace `workshop-boot` with a stub that exits `0` and starts nothing — reproducing `cmd/boot`'s measured behaviour exactly; the gate MUST go red. The mutation is not hypothetical: it is what the upstream CLI does today, which is why this is the gate that would have caught the withdrawn `cmd/boot` specification (T021)

**Checkpoint**: a reader can consume Chapter 1 without a terminal. Stop for approval.

---

## Phase 5: User Story 3 — Find anything by meaning (Priority: P3)

**Goal**: semantic search with fast type-ahead and cross-references.

**Independent test**: issue meaning-based queries whose expected passages are known, including queries sharing no literal words with the target.

- [x] T052 [US3] [TDD] Implement the lexical FTS5 prefix index in `workshop/platform/backend/pkg/search/lexical.go` — measured p95 9.58 ms; FTS5 works in `modernc.org/sqlite`, already a dependency, so no new library
- [x] T053 [US3] [TDD] Implement `GET /api/suggest` backed by the LEXICAL path only — a query embedding measured 18–21 s under load, so semantics cannot meet SC-005's 200 ms budget. Gate **G-HTTP-8** ([contracts/http-api.md](./contracts/http-api.md) §3.6, §5): issue 200 `/api/suggest` calls and assert at the socket level that **zero** requests reach the embedding endpoint, and that `legs` is always exactly `{"lexical": …}`. **Paired mutation**: add an embedding call to the suggest path; the gate MUST go red
- [x] T054 [US3] [TDD] Implement the semantic leg in `workshop/platform/backend/pkg/search/semantic.go` over the passage registry
- [x] T055 [US3] [TDD] [REVIEW] **[PATH CORRECTED 2026-09-02 — this task named `workshop/platform/backend/pkg/search/verdict.go`, which does not exist; the three-state contract landed at `workshop/platform/backend/pkg/search/envelope.go` (`StatusNoMatch` `:27`, I5 implemented and named at `:432`–`:435`, I2/I3 at `:372`) with its callers in `service.go` and the reindexing promotion in `degraded.go`]** Implement the three-state contract in `workshop/platform/backend/pkg/search/envelope.go` per [contracts/http-api.md](./contracts/http-api.md) invariants I1–I9 — including **I5: `no_match` requires EVERY enabled leg to have succeeded**; if a leg failed and survivors found nothing, that is `unavailable`, never "no results". Three gates land here ([contracts/http-api.md](./contracts/http-api.md) §5). **G-HTTP-1**: point the embedding endpoint at a closed port and assert `GET /api/search?q=x` returns **503** with `status:"unavailable"` and a `reason.code`; **paired mutation**: make the handler return `200 {"results":[]}` on backend error. **G-HTTP-2**: on that same failure assert the response body has **no** `results` key at all; **paired mutation**: add `"results": []` to the unavailable branch. **G-HTTP-3**: fail the semantic leg, let lexical return zero rows, and assert `status == "unavailable"` with `reason.code == "partial_failure_zero_results"`; **paired mutation**: change the rule to emit `no_match` when any leg succeeded. Every one of the three mutations MUST turn its gate red — the contract flags I5 as the invariant most likely to be "simplified" later
- [x] T056 [US3] [TDD] Parse and promote Lumen's glued `"No results found. | Warning: Index is being updated…"` string to `degraded`, never forward it as a result. Gate **G-HTTP-4** ([contracts/http-api.md](./contracts/http-api.md) §5): feed the search service that literal string and assert `status=="ok"` with `degraded.semantic=="reindexing"` when lexical has rows, and that the raw upstream string appears **only** under `degraded.evidence`. **Paired mutation**: forward the upstream string into `results[0].snippet`; the gate MUST go red
- [x] T057 [US3] [TDD] Prove gate **G-HTTP-7** ([contracts/http-api.md](./contracts/http-api.md) §5) — the frontend half of the degradation contract, which the API cannot enforce and which is therefore stated in the contract and tested here: render each of the three envelopes and assert the no-results copy does **not** appear for the `unavailable` envelope, and the unavailable copy does **not** appear for `no_match`. **Paired mutation**: restore the `ai_interviewing` error handler shape, literally `error: () => loading.set(false)`; the gate MUST go red
- [x] T058 [US3] [TDD] Implement index generations with a verification gate and atomic swap in `workshop/platform/backend/pkg/index/generation.go` — measured necessity: during a live rebuild `chunks` moved while `last_indexed_at` still advertised the previous generation
- [ ] T059 [US3] [TDD] Enforce redaction rules **R1** and **R5** in `workshop/platform/backend/pkg/index/generation.go` per [contracts/passage-contract.md](./contracts/passage-contract.md) §7.3 (FR-039): redacted pids are excluded from `passages_fts` AND from the embedding set **at generation-build time**, so neither leg can return a redacted passage; and until the post-redaction rebuild completes the index reports `degraded` rather than serving a generation known to contain the passage. Filtering at render time is not compliance — the passage would still be retrievable
- [x] T060 [US3] [TDD] Implement cross-reference derivation and storage in `workshop/platform/backend/pkg/crossref/`, cycle-safe per the spec edge case
- [x] T061 [US3] [TDD] Enforce redaction rule **R3** in `workshop/platform/backend/pkg/crossref/` and in `GET /api/passages/{pid}/crossrefs` ([contracts/passage-contract.md](./contracts/passage-contract.md) §7.3, [contracts/http-api.md](./contracts/http-api.md) §3.9): a cross-reference whose endpoint is redacted is suppressed from traversal and counted in `redacted_omitted` — the count only, never the pids and never the content. Reporting the count is honest that something was suppressed; returning a silently shorter list is not
- [x] T062 [US3] [P] [SUBAGENT] Build the search UI with type-ahead in `workshop/platform/frontend/src/app/features/search/` — it MUST render the three states distinguishably; the reference anti-pattern is `ai_interviewing/.../search.component.ts`
- [x] T063 [US3] [P] [TDD] WCAG 2.1 AA + full keyboard operability for search (FR-041, FR-042, SC-017); `@axe-core/playwright` is already a dependency of `_tests/` with `_tests/evidence/a11y-audit/run-audit.js` as precedent — **[TICKED 2026-09-02 after independent re-measurement. The suite landed at `workshop/platform/frontend/e2e/a11y-responsive.spec.ts`, which cites T063/FR-041/FR-042/SC-017 at `:5`, runs axe over the route set in BOTH themes (`:71` light, `:79` dark), and carries a `keyboard operability` block at `:89` covering the skip link, chapter-card traversal, the search combobox without a mouse, visible focus rings, and SC-021 deep-link traversal. Its own header at `:8`–`:11` refuses to read "axe found nothing" as "the page is accessible", which is the honesty the criterion needs. Honest boundary (§11.4.6): **no Playwright run was executed for this tick** — the assertions were read, not run, and stale failure artifacts exist under `workshop/platform/frontend/e2e/artifacts/test-results/` whose current status was NOT established]**
- [ ] T064 [US3] **[PATH NOT BUILT — `retrieval.tsv` does not exist; that directory holds `questions.tsv` alone. Do not mistake `workshop/pipeline/benchmark/retrieval_benchmark.json` + `run_retrieval_benchmark.py` for it: that runner's own docstring disclaims this scope, stating it measures spec 002's SC-015 and explicitly NOT SC-007/SC-008. No zero-literal-overlap subset column exists anywhere]** Build the ≥20-query retrieval benchmark in `workshop/platform/backend/testdata/benchmark/retrieval.tsv` (TSV, `subset<TAB>query<TAB>expected_pid` under a comment header, matching the shipped `questions.tsv` schema — see the benchmark-location correction in File Structure), including ≥8 queries sharing no literal words with their target, flagged in the `subset` column so the zero-overlap set is machine-selectable rather than judged by eye (SC-007, SC-008)
- [x] T065 [US3] [TDD] **[PATH CORRECTED + TICKED 2026-09-02 — this task named two scripts, `workshop/scripts/bench-suggest.sh` and `workshop/scripts/bench-search.sh`; NEITHER exists. Both endpoints landed in ONE Go binary, `workshop/platform/backend/cmd/bench/main.go`, selected by `-endpoint suggest|search` (`:49`) with `-keystrokes 500` (`:50`), `-queries`, `-repeat`, and `p50_ms`/`p95_ms`/`p99_ms` emitted at `:107` measured at the HTTP boundary, plus `loadavg_before` and `budget_p95_ms` (`:110`). The figures are recorded in `workshop/docs/limits.md:216`–`:218`: `/api/suggest` p95 **14.2 ms**, `/api/search` p95 **2 094.8 ms**, `/api/health` p95 **2.2 ms**, n=40 each. **Read for the record, not a defect in this task: 2 094.8 ms breaches SC-006's 2 s budget**, and `limits.md:222` records a 20× same-day spread — the measurement is done, the criterion is not met, and those are different statements]** Measure and record p95 latencies for suggest and search (SC-005, SC-006) with the harness [quickstart.md](./quickstart.md) US3 steps 1–2 contract: `cmd/bench -endpoint suggest -keystrokes 500` and `cmd/bench -endpoint search -queries 20 -repeat 5`, both reporting p50, **p95** and p99 measured **at the HTTP boundary**, not inside the FTS5 call — the measured FTS5 p95 of 9.58 ms leaves roughly 190 ms of SC-005's budget for HTTP, serialisation and paint, and it is that remainder where the budget is actually spent or lost. `bench-search.sh`'s report MUST also record host load average and whether an index build was in flight: three identical two-word embed calls, model resident, minutes apart, measured 20.16 s / 11.05 s / 0.10 s at load 8.25, a 200× spread driven purely by queue contention, so a p95 without its load conditions is not interpretable
- [x] T066 [US3] [TDD] Prove SC-016 and gate **G-PID-3** ([contracts/passage-contract.md](./contracts/passage-contract.md) §5.3) behaviourally — *"an assertion that greps a file for a string is not a test"*: correct a transcript passage, re-index, and assert `content_hash` changed, the pid did **not**, and **every** stored citation and cross-reference to that passage still resolves to the same row. **Paired mutation**: replace the citation lookup key with `content_hash`; the gate MUST go red. `content_hash` is change detection and never identity, in every serialisation
- [ ] T067 [US3] **[PATH NOT BUILT — `workshop/docs/search.md` does not exist, and the media boundary is not stated at any other path either; the docs directory holds `faq.md`, `knowledge-model-contract.md`, `limits.md`, `manual.md`, `quickstart.md`, `README.md`, `user-guide.md`, `work-register.md` plus the `prompts/`, `research/`, `training/` and `session-evidence/` trees]** Document the media boundary in `workshop/docs/search.md` — audio and video are reachable THROUGH transcripts, not indexed directly; Lumen's extension allowlist is a compile-time var with no override (FR-031 requires stating what the system cannot do)
- [ ] T115 [US3] [TDD] **[PATH NOT BUILT — `workshop/scripts/index.sh` does not exist and no equivalent landed anywhere]** Implement the `workshop/scripts/index.sh` wrapper per [contracts/pipeline-cli.md](./contracts/pipeline-cli.md) §4.4 over T058's generations — `--chapter`, `--lexical-only` (the honest escape hatch when the embedding backend is saturated), `--semantic-only`, `--verify-only`, `--swap`/`--no-swap`, and `--timeout-ms 5000` per call, because an unbounded query is how a 10-minute stall happens. It MUST reserve embedding capacity for interactive queries, which is a hard requirement rather than a nicety: `scripts/ollama-tune.sh` records that with `OLLAMA_NUM_PARALLEL` resolving to 1 a single embed went from 0.74 s to a >90 s client timeout, stalling indexing entirely — *"queue depth is not the defect — serialisation is"* — and without reservation SC-006 fails on every chapter ingest, precisely when people are using the system. Gate **G-CLI-6** (§4.4, §5): point the embedding endpoint at a closed port and assert exit `2` with `reason.code: "embedding_backend_exhausted"` **and** that the previously live generation is still live and serving. **Paired mutation**: map backend failure to exit `1`; the gate MUST go red. The line that must not be blurred: `all embedding servers exhausted` is `2`, never `1` — reporting `1` there makes a broken backend accuse a healthy curriculum
- [ ] T116 [US3] **[PATH NOT BUILT — `workshop/scripts/crossref.sh` does not exist. The derivation it wraps DOES exist at `workshop/platform/backend/pkg/crossref/` (T060, ticked); the CLI over it does not, and no `--rebuild-derived`/`--check-cycles` surface exists anywhere]** Implement the `workshop/scripts/crossref.sh` wrapper per [contracts/pipeline-cli.md](./contracts/pipeline-cli.md) §4.5 over T060's derivation — `--chapter`, `--min-score`, `--max-per-passage 20`, `--rebuild-derived`, `--check-cycles`. It rebuilds `origin: "derived"` edges for the target generation and **never touches `authored` edges**, which are content rather than derivation ([contracts/passage-contract.md](./contracts/passage-contract.md) §7.4 X4); self-references are rejected and traversal is cycle-checked. Exit `1` on a cycle among `authored` edges (a content defect a human introduced), an edge whose endpoint is not in the registry, or a self-reference in authored content; exit `2` when the embedding backend is unavailable for similarity scoring, the registry is unreadable, or the run was interrupted — an unscoreable backend is not a finding about the content
- [x] T117 [US3] [TDD] Prove gate **G-HTTP-6** ([contracts/http-api.md](./contracts/http-api.md) §5): over 100 randomised search outcomes spanning all three states, assert the `X-Workshop-Search-Status` response header equals `body.status` on every single one — a header and a body that can disagree hand a cache or a proxy a different answer than the reader gets. **Paired mutation**: hardcode the header to `ok`; the gate MUST go red
- [ ] T118 [US3] [TDD] **[PATH NOT BUILT — `workshop/scripts/bench-retrieval.sh` does not exist, and neither does its input: T064's `retrieval.tsv` is absent, so there is no query set to measure SC-007/SC-008 against]** Build `workshop/scripts/bench-retrieval.sh` per [quickstart.md](./quickstart.md) US3 step 3 and measure **SC-007** and **SC-008** with it against T064's query set: per-query top-5 hit/miss against the expected pid, ≥90% of the ≥20 queries returning the expected passage in the top five, and ≥80% of the **zero-literal-overlap subset** succeeding. That subset MUST be identified in the benchmark file itself and verified by a mechanical check that query and target share no token after normalisation — "obviously different wording" judged by eye is not a measurement. **Paired mutation**: run the benchmark against an **empty index generation**; both figures MUST collapse to 0% and the run MUST exit non-zero, because a benchmark that still scores well without an index is scoring the fixture rather than the system. ~~One divergence is recorded here rather than resolved: [quickstart.md](./quickstart.md) names `workshop/platform/qa/retrieval-benchmark.jsonl` as this harness's input while T064 builds `workshop/pipeline/benchmark/queries.yaml`, and `quickstart.md` is owned by another agent this session.~~ **RESOLVED 2026-09-01**: neither path existed on disk, a third location shipped with a working gate, and the canonical input is now `workshop/platform/backend/testdata/benchmark/retrieval.tsv` in **both** documents — see the benchmark-location correction in File Structure

**Checkpoint**: search works and degrades honestly. Stop for approval.

---

## Phase 6: User Story 4 — Ask a question, get a grounded answer (Priority: P4)

**Goal**: cited answers that refuse rather than fabricate.

**Independent test**: questions with known answers return correct cited answers; genuinely unanswerable questions are all declined.

~~**BLOCKED ON AN OPERATOR ACTION**: no generative model exists on this host — ollama serves two models and both are the same embedding model; the whole store is 309 MB, too small for a decoder.~~

> #### NOT BLOCKED — CLAIM WITHDRAWN 2026-09-02, and withdrawn on measurement, not on optimism
>
> The struck-through paragraph is left visible so a reader can see that this phase was unblocked by
> an operator action that actually happened, not by an edit. **A generative model exists on this
> host and is WIRED IN.** Re-derive:
>
> ```bash
> ollama list
> #   qwen2.5:3b-instruct-q4_K_M   1.9 GB   (generative)
> #   nomic-embed-text:latest      274 MB   (embedding)
> #   jina-embeddings-code-cpu / ordis/jina-embeddings-v2-base-code   323 MB each (embedding)
> podman inspect workshop-curriculum_platform_1 --format '{{.Config.Cmd}}'
> #   … -answer-provider ollama -answer-model qwen2.5:3b-instruct-q4_K_M …
> ```
>
> Every clause of the old paragraph is false as measured 2026-09-02: ollama serves **four** models,
> not two; they are **not** all the same embedding model; and the running container's own argv names
> `qwen2.5:3b-instruct-q4_K_M` as `-answer-model`, so the answering path is wired to it today rather
> than merely capable of being wired to it. The 57-question benchmark under T078/T079 was driven
> through that model. Separately, an **entailment** judge also loads here and produced a decided
> verdict — `workshop/docs/limits.md:1642` records `entail=0.9924` — over `pkg/entail`'s ONNX and
> ollama judges.
>
> **What is NOT claimed**: that a 3B q4 instruct model is FIT for this work. That is a separate
> question this block does not answer, and T078's measured `SC-010 NOT met` is the evidence that it
> is a live question. **The parenthetical "(3 fabrications)" this line carried is WITHDRAWN, not
> restated** — re-measured 2026-09-02 the count is **1**, and T078 records why that is not the
> improvement the two numbers suggest. T069's `extractive` adapter remains the zero-generative route
> and is unaffected.

- [x] T068 [US4] [TDD] [REVIEW] Implement the `Provider` interface with adapters `none` (default), `extractive`, `ollama`, `openai_compatible` in `workshop/platform/backend/pkg/answer/provider.go` — copy the interface SHAPE from `LLMProvider`, not the dependency ~~(its module path is unresolvable and it carries a relative-path `replace` on a sibling checkout absent from `.gitmodules`)~~. **[CLAIM WITHDRAWN 2026-09-02 — the parenthesis is struck rather than deleted so the reason it died stays visible. `LLMProvider` is no longer unresolvable: `submodules/LLMProvider` and `submodules/RAG` are declared gitlinks of this repository, and `workshop/platform/backend/go.mod` now carries `require digital.vasic.llmprovider v0.0.0` and `require digital.vasic.rag v0.0.0` with `replace` targets `../../../submodules/LLMProvider` and `../../../submodules/RAG`. The backend CONSUMES it — per that go.mod's own comment block, for the HTTP transport — so "copy the shape, not the dependency" is now a design choice about the `Provider` seam, not a workaround for a broken module path. **The tick is unaffected**: the seam was built and it still stands]**
- [x] T069 [US4] [TDD] Implement the `extractive` adapter — ~0.3 s, genuinely grounded, structurally unable to fabricate, and works today with zero generative capability
- [x] T070 [US4] [TDD] Implement L1: the calibrated retrieval gate with BOTH `min_score` and `min_margin` — the margin test is what catches the near-miss that scores high while being unanswerable
- [x] T071 [US4] [TDD] Implement L2: JSON-schema-constrained generation where `"minItems": 1` on citations makes an uncited claim structurally undecodable
- [x] T072 [US4] [TDD] Implement L3: deterministic citation pid set-membership against the LIVE generation — **SC-009 is unreachable without this**; attaching a citation is easy, proving it points at a real passage is a microsecond set check
- [ ] T073 [US4] [TDD] Implement L4: support verification (embedding floor, then batched entailment)
- [x] T074 [US4] [TDD] Any layer failing ⇒ refuse the WHOLE answer; never strip claims silently
- [ ] T075 [US4] [TDD] Enforce redaction rule **R4** and [contracts/http-api.md](./contracts/http-api.md) §3.10 **A4** (FR-039): a citation resolving `redacted` invalidates the WHOLE answer as `declined{redacted_evidence}` ([contracts/passage-contract.md](./contracts/passage-contract.md) §7.2 C4 — claims are never stripped to keep an answer presentable), and any **stored** answer whose citations intersect the redaction set is marked `withdrawn` and MUST NOT be served, with re-asking required. Redaction propagates to stored answers, not merely to the rendered transcript
- [ ] T076 [US4] [TDD] Prove **G-PID-5** end to end ([contracts/passage-contract.md](./contracts/passage-contract.md) §7.3) — this is the earliest point at which all three propagation paths exist. Redact a cited passage, then assert: search cannot return it (R1, T059), `resolve` returns `redacted` and the API answers `410 Gone` ([contracts/http-api.md](./contracts/http-api.md) §3.8), cross-references to it are omitted with a non-zero `redacted_omitted` (R3, T061), and the stored answer citing it is `withdrawn` (R4, T075). **Paired mutation**: propagate the redaction only to the rendered transcript; the gate MUST go red, and MUST demonstrate R1, R3 and R4 individually rather than as a single aggregate failure
- [x] T077 [US4] Build the ≥10-question adversarial unanswerable set as the `U` rows of `workshop/platform/backend/testdata/benchmark/questions.tsv` ~~(which exists and already holds 10 `U` rows and 8 `A` rows — the `U` half meets SC-010's count, the `A` half is **8 short of SC-009's ≥20** and that shortfall is this task's remaining work)~~ **[FIGURE WITHDRAWN 2026-09-02 — stale in BOTH columns, and the shortfall it described is closed. Re-measured with `awk 'NR>1 && !/^#/ && NF' … | cut -f1 | sort | uniq -c`: **24 `A` rows and 33 `U` rows**. SC-010's ≥10 unanswerable and SC-009's ≥20 answerable are both met ON COUNT. What is NOT met is SC-010 itself — ~~the run at `bench-expanded-2026-09-01.tsv:19` records `SC-010 NOT met (3 fabrications)`~~ **that figure is WITHDRAWN, not restated: re-measured 2026-09-02 at `workshop/platform/backend/evidence/answering/bench-question-verifier-ab-2026-09-02.tsv:28`, `SC-010 NOT met (1 fabrication)` on a corpus the old run did not cover; see T078 for why 3 → 1 is not the improvement it looks like** — and that is T078's work, not this task's; and SC-009's certification, which is T079's]** using the taxonomy (near-miss attribute, false premise, uncomputable aggregate, misattributed speaker, lexically-overlapping-but-unanswerable, redacted passage, inaudible segment) — ten astrophysics questions would pass any threshold and prove nothing
- [ ] T078 [US4] [TDD] **[PATH CORRECTED 2026-09-02 — this task named `workshop/scripts/bench-answers.sh`, which does not exist; the harness landed at `workshop/platform/backend/gates/bench-answers.sh` and **has run**. It is three-valued and class-aware, checks SC-009's ≥20 floor before the first model call, and prints top score and margin on every response including successes. Its configuration is by ENVIRONMENT (`QUESTIONS`, `REPORT`, `MIN_ANSWERABLE`, `TIMEOUT`) plus one positional base URL — **not** the `--answerable`/`--unanswerable`/`--report` flags this task contracts, which is a real divergence and is the flag surface still owed. **Do not rebuild the harness.** What is open is SC-010's verdict, which is measured and still NEGATIVE — **but the "3 fabrications" figure this note carried is WITHDRAWN, not restated.** ~~`bench-expanded-2026-09-01.tsv:18`–`:19` records 30 refused, 3 FABRICATED, `SC-010 NOT met (3 fabrications)`.~~ Superseded twice on 2026-09-02 by the A/B run recorded at `workshop/platform/backend/evidence/answering/bench-question-verifier-ab-2026-09-02.tsv`, and the sequence matters more than either number. With the T115 answer-against-question layer **unwired**, that file's `:24`–`:25` put the unanswerable set at 22 refused and **11** fabricated; with it **wired**, `:27`–`:28` put the same set at 29 refused, **1** fabricated and 3 unavailable. Both runs record SC-010 as NOT met. **The old 3 was therefore not an improvement on 11 — it was taken over a smaller corpus**, which that file explains at `:31`–`:33`. Honest denominator, stated at `:42`: **1 fabrication in 30 MEASURED**, with the 3 unavailable excluded rather than scored as refusals. The surviving case is isolated at `:53` and identified in the per-question rows. **SC-010 is NOT met**, and — see standing rule 7 — this is **spec 001's** SC-010, not spec 002's. Fix the surviving fabrication, then re-run]** Build the bench-answers harness at `workshop/platform/backend/gates/bench-answers.sh` per [quickstart.md](./quickstart.md) US4 config A — `--answerable`, `--unanswerable`, `--report` — and prove SC-010 with it: 10/10 declined, each with a `reason` of `below_threshold`, `margin_too_small` or `unsupported`, and 0 fabricated. Every response carries `retrieval` (top score **and** margin) **even on success**, so a 0.002-margin pass is visible as FRAGILE rather than indistinguishable from a confident one. This is the same harness T079 runs for SC-009
- [ ] T079 [US4] [TDD] **[PATH CORRECTED 2026-09-02 — T078's harness is `workshop/platform/backend/gates/bench-answers.sh`, not `workshop/scripts/bench-answers.sh`. The ≥20-answer RUN exists: `questions.tsv` holds 24 `A` rows and the evidence header records `SC-009 met (24 answerable >= 20)` with `answered+cited 17  declined 7`. **The CERTIFICATION is what this task still owes** — the same evidence file states its own honest boundary that `answered+cited` is not `answered correctly`, and records that only 6 of the 17 were re-asked and read, with 1 defect found. SC-009 requires 100% over ≥20 answers, so it is unmet on certification, not on count]** Prove SC-009 over ≥20 answers with human certification per citation, using T078's harness — each answerable question returns `status: answered`, `text` and **≥1 citation**, zero citations while `answered` being structurally undecodable because the response schema sets `"minItems": 1`
- [ ] T080 [US4] [TDD] [REVIEW] Enforce FR-024 privacy: resolved-address allowlist (`net.LookupIP` + `IsLoopback`, not string matching), egress-denied namespace with a NEGATIVE CONTROL (`curl https://example.com` from inside MUST fail), and packet capture asserting zero non-loopback packets. A config flag is not a guarantee. This is gate **G-CLI-14** ([contracts/pipeline-cli.md](./contracts/pipeline-cli.md) §5, D-LLM-4): the negative control and the capture both run across the full 20-answer and 10-refusal runs. **Paired mutation**: run the same assertions OUTSIDE the egress-denied namespace; the gate MUST go red — if it stays green the test proved nothing about the namespace, and *"we observed no egress"* was never upgraded to *"egress was impossible"*
- [ ] T081 [US4] [TDD] Enforce FR-025 by SEPARATE ROUTE TREES at compile time — browsing and search must survive answering being unavailable, and `unavailable` must remain distinct from `declined` — they are different states with different causes, and `no_provider` is a cause of `unavailable`, never a decline reason ([contracts/http-api.md](./contracts/http-api.md) §3.10 A7). Two gates prove FR-025 from its two sides. **G-HTTP-5** ([contracts/http-api.md](./contracts/http-api.md) §5): with ollama stopped, `GET /api/search` returns **200** with real lexical results **and** `POST /api/ask` returns **503** `state:"unavailable"`; **paired mutation**: wire `/api/search` through the answering provider's health check. **G-CLI-13** ([contracts/pipeline-cli.md](./contracts/pipeline-cli.md) §4.8, §5): with ollama stopped, `start.sh` still exits `0` and prints which state the stack came up in — answering-provider construction failure MUST NOT abort startup; **paired mutation**: abort startup on provider construction failure. Both mutations MUST turn their gate red
- [x] T082 [US4] Implement the ingest exclusive lock that suspends answering while search continues from the existing generation (D-LLM-10)
- [ ] T083 [US4] **[PATH NOT BUILT — `workshop/docs/answering.md` does not exist. Part of the content landed at OTHER paths and should be reused rather than rewritten: the `estimated_seconds: null` contract is documented at `workshop/docs/faq.md:215`–`:216` and `workshop/docs/quickstart.md:388`–`:389`, and the asynchronous-answering timing story is in `workshop/docs/limits.md` §1.4. The PAGE this task contracts still does not exist]** Document in `workshop/docs/answering.md` that answering is ASYNCHRONOUS — CPU-only generation is ~21 s (1.5B) to ~95 s (7B) idle, so "instant" is off by two orders of magnitude and no prompt engineering closes it. `estimated_seconds` MUST be `null` until measured

**Checkpoint**: answers are cited or refused, never fabricated, and a redacted passage cannot reach a reader through search, cross-references or a stored answer. Stop for approval.

---

## Phase 7: User Story 5 — Add a chapter (Priority: P5)

**Goal**: one documented, repeatable, idempotent procedure.

**Independent test**: run it against a synthetic chapter; it appears fully integrated with no code change. Run it twice; nothing duplicates.

- [ ] T084 [US5] [TDD] **[PATH NOT BUILT — `workshop/scripts/add-chapter.sh` does not exist and none of the nine contracted stages exists as a driver. Four of the stages it must call are themselves `[PATH NOT BUILT]` (`transcribe.sh` T111, `index.sh` T115, `crossref.sh` T116, `redact.sh` T038/T039); two exist (`verify-accuracy.sh` T112, `ingest.sh` T113). **This task gates T085, T086, T090 and the enforcement half of T087**]** Implement `workshop/scripts/add-chapter.sh` per [contracts/pipeline-cli.md](./contracts/pipeline-cli.md) §4.7 covering **all NINE contracted stages in order** — `preflight → extract → transcribe → verify-accuracy → ingest → index → crossref → redaction-review → publish` — with `--resume`, `--only <stage>`, `--skip <stage>`, `--from <stage>`, `--dry-run`, `--json` and `--check-idempotent`, and with no code edit required to add a chapter. **No stage is optional and none is silently dropped**: `preflight` (§3.1) classifies every finding as tooling (`2`) or content (`1`) and reports ALL of them rather than the first; `verify-accuracy` (§4.2) must actually run because the presence of its `accuracy.json` is publish precondition B2 — its value may miss target, its absence blocks; and `redaction-review` is the FR-039 gate implemented in T038/T039, which is what makes `publish` legal at all. An earlier draft of this task named only four stages (transcribe → ingest → index → cross-link); dropping the publication gate is precisely how a redaction requirement becomes decorative
- [ ] T085 [US5] [TDD] Prove idempotency (FR-027) as gate **G-CLI-7** ([contracts/pipeline-cli.md](./contracts/pipeline-cli.md) §4.7, §5): run `add-chapter.sh` twice on a small synthetic chapter and assert all of **J1–J6** — a second run changes nothing and duplicates no passage, keyed on pid. **Paired mutation**: make the procedure mint unconditionally; the gate MUST go red
- [ ] T086 [US5] [TDD] Incomplete materials MUST report precisely what is missing and MUST NOT publish a partial chapter as complete (FR-028), proven as gate **G-CLI-8** ([contracts/pipeline-cli.md](./contracts/pipeline-cli.md) §4.7, §5): remove `chapter.yaml` and two archive parts, then assert exit `1` with **three** findings enumerated — all of them, not just the first — and nothing published. **Paired mutation**: report the first finding only and publish anyway; the gate MUST go red
- [ ] T087 [US5] [TDD] Enforce the publish preconditions **B1–B6** of [contracts/pipeline-cli.md](./contracts/pipeline-cli.md) §4.7 in `add-chapter.sh`: B1 `coverage.unexplained_gap_s == 0` · B2 `accuracy.json` exists · B3 every passage has a pid in `passages.jsonl` · B4 the generation containing the chapter is `live` · B5 **`redaction-review.json` exists and is newer than the transcript (FR-039)** · B6 no source file changed during the run. Failing any one of them ⇒ exit `1` with the chapter left `transcribed`, never `published`. **Paired mutation**: publish with `redaction-review.json` absent (and again with it stale); the gate MUST go red in both cases — B5 is the only thing standing between FR-039 and a decorative requirement
- [ ] T088 [US5] Make the procedure accept a PRE-SUPPLIED TRANSCRIPT FIXTURE so idempotency and identity can be proven without running ASR — otherwise every US5 proof inherits the ASR block. **[PATHS ADDED 2026-09-02 — this task named none, and two fixture producers already exist: `workshop/pipeline/extract/fixtures/synthetic_chapter/passages.jsonl` and `workshop/platform/backend/cmd/fixture-corpus/main.go`, which writes an invented corpus so endpoints can be exercised without private content. **Do not build a third fixture.** What is missing is a PROCEDURE that accepts one, and that procedure is T084, which is `[PATH NOT BUILT]`]**
- [x] T089 [US5] **[PATH CORRECTED 2026-09-02 — this task named `workshop/docs/add-chapter-prompt.md`, which does not exist; the prompt landed at `workshop/docs/prompts/add-a-chapter.md`]** Write the reusable extension prompt in `workshop/docs/prompts/add-a-chapter.md` — the operator-facing artifact requested
- [ ] T090 [US5] [TDD] Prove SC-011: a new chapter integrated in under 30 minutes hands-on with zero code or config change

**Checkpoint**: the curriculum is extensible without engineering, and no chapter reaches `published` without a fresh redaction review. Stop for approval.

---

## Phase 8: Polish & Cross-Cutting Concerns

- [x] T091 [P] [SUBAGENT] Write `workshop/docs/user-guide.md`
- [x] T092 [P] [SUBAGENT] Write `workshop/docs/manual.md` (operator)
- [x] T093 [P] [SUBAGENT] Write `workshop/docs/faq.md`
- [x] T094 [P] [SUBAGENT] Write the training material under `workshop/docs/training/` — **[PATH CORRECTED + ONE HALF NOT BUILT, measured 2026-09-02. `workshop/docs/training.md` does not exist; training landed as a DIRECTORY, `workshop/docs/training/`, holding `00-Overview-and-Taxonomy.md` plus `areas/`, `curriculum-areas/` and `diagrams/`. `workshop/docs/tutorial-quickstart.md` is **[PATH NOT BUILT]** — `find workshop -iname '*tutorial*'` returns zero files. Whether `workshop/docs/quickstart.md` (T051) was meant to absorb that second artifact is **CANNOT DETERMINE** from the tree. The tick is left as it was found; this note corrects only where the files are]**
- [ ] T095 [P] Document every limit honestly per FR-031: no direct media indexing, asynchronous answering, code-passage identity weaker than transcript identity (SC-016a, implemented by T015–T017 and proven by G-PID-4 in T017), and every operator-only step
- [ ] T096 [TDD] Register every check this feature adds in `scripts/check-registry.tsv` so `scripts/verify-check-registry.sh` can enforce SC-012 and SC-013 mechanically — **[PATHS MEASURED 2026-09-02 — both files EXIST, and `scripts/check-registry.tsv` contains **zero feature-001 rows**: its non-comment rows are the umbrella's own, and the only string matching "workshop" in it is a comment. `workshop/platform/gates/check-registry-002.tsv` covers feature 002 ONLY and says so in its own header, declaring `platform/gates/` and `platform/backend/gates/` out of its scanroot because those directories interleave 001 and 002 files. So no instrument in this tree enforces SC-012/SC-013 over any 001 check today]**
- [ ] T097 [TDD] Verify EVERY feature check has a paired mutation proof including a real-entry-point case (SC-012)
- [ ] T098 [TDD] Verify EVERY feature check distinguishes could-not-determine from pass and fail (SC-013)
- [ ] T099 Write machine evidence to `workshop/evidence/` retained with the commit that produced it (FR-040) — **[PATH SPLIT 2026-09-02 — `workshop/evidence/` EXISTS but holds only **3** tracked files (`phase2-passage-identity/README.md`, `phase2b-mentions/README.md`, `phase2b-mentions/T014-unjoined-words-u5.md` — and that last one is FEATURE 002's T014, not this file's). The machine evidence FR-040 asks for landed at `workshop/platform/backend/evidence/`: **21** tracked files, committed and clean. `workshop/platform/qa/evidence/` exists on disk with **0** tracked files, and `workshop/evidence/knowledge-pipeline/` carries untracked run output. **The substance largely exists; its contracted LOCATION does not**, so this task is a move-or-mirror decision plus the retention rule, not a from-zero build]**
- [x] T100 [REVIEW] Confirm zero CI added anywhere as gate **G-CLI-11** ([contracts/pipeline-cli.md](./contracts/pipeline-cli.md) §2.7 N1–N3, §5): assert no `.github/workflows/*.yml` file exists anywhere under `workshop/`, and that `bash scripts/pre-push-gates.sh` gate E is green across the fleet (SC-014, FR-034, §11.4.156). **Paired mutation**: add one workflow file under `workshop/.github/workflows/`; the gate MUST go red — gate E derives the owned fleet from `helix-deps.yaml`, so the umbrella catches it too
- [x] T101 Update `CONTINUATION.md` and confirm `bash scripts/continuation-check.sh` is rc=0 (FR-035, §12.10) — **[TICKED 2026-09-02 on a measured run. `CONTINUATION.md` is modified in the working tree (`git status --short CONTINUATION.md` → ` M`) and `bash scripts/continuation-check.sh` exits **rc=0**, printing `8 PASS · 0 DRIFT · 0 UNDET · 4 NOTE` and `CONTINUATION.md IS IN SYNC`, including `[C7] §6 matches the live runner: 8 gate(s)` and `[C8] production facts hold`. Honest boundary (§11.4.6): rc=0 is a measurement of that moment, and the check goes stale as this tree moves — re-run it before relying on the tick]**
- [x] T102 Confirm `workshop/`'s four governance carriers remain in lockstep — `bash scripts/verify-governance-cascade.sh` C8 (FR-035) — **[TICKED 2026-09-02 on a measured run. `bash scripts/verify-governance-cascade.sh` exits **rc=0** at `12 PASS, 0 FAIL, 0 ENV, 8 NOTE`, with C8 reporting that all 11 owned submodules carry four agent carriers with byte-identical bodies once the per-agent header is normalised. Honest boundary (§11.4.6): the same run prints NOTEs about known-unclearable third-party carriers, which it excludes from its verdict rather than suppressing — read them; and this rc is a dated observation, not a standing fact]**
- [ ] T103 [REVIEW] Run the whole gate suite green: pre-push-gates, verify-governance-cascade (+ `--prove-failure`), verify-manifest-pins, continuation-check, audit-hardcoded-paths, audit-environment-assumptions
- [ ] T104 Commit and push the umbrella and every submodule to all upstreams; verify each with `git ls-remote`, not a push log (FR-036, SC-015) — **not before T040's Chapter 1 redaction review is recorded**, since a push is publication
- [ ] T119 [TDD] Prove gate **G-CLI-1** ([contracts/pipeline-cli.md](./contracts/pipeline-cli.md) §1.6, §5) across **every** command in the control plane and the pipeline: `result.json.state` and the process exit status agree over all three outcomes — `"ok"`/`0`, `"problem_found"`/`1`, `"could_not_determine"`/`2` — and under `--json` stdout carries exactly one JSON object and nothing else, with all human text on stderr. **Paired mutation**: hardcode `state: "ok"` in one command's result writer; the gate MUST go red. It sits in this phase because it asserts over every command and cannot run until they all exist
- [ ] T120 [TDD] [REVIEW] Implement `workshop/scripts/verify.sh` per [contracts/pipeline-cli.md](./contracts/pipeline-cli.md) §4.9 — the aggregation point that runs every gate in this contract set (all `G-CLI-*`, `G-HTTP-*` and `G-PID-*`) and aggregates them. **Sequenced last, after every gate task in every phase**, because it aggregates those gates and cannot be written before them. Three-valued: `0` every gate ran and passed · `1` at least one gate **ran** and reported a violation · `2` at least one gate **could not run** and **no** gate reported a violation. **The precedence rule is the single most error-prone line in the contract, and both directions of collapsing it are forbidden here by name**: when some gates failed (`1`) and others could not run (`2`), the aggregate is **`1`** — a confirmed violation outranks an unknown — and the summary reports the two counts separately in the repository's existing sweep vocabulary (`PASS n  FAIL n  COULD-NOT-RUN n  of N`, then each could-not-run gate named with its reason). A `verify.sh` that collapses `2` into FAIL is the specific defect to forbid: this project has shipped **seven** separate pass/fail/could-not-determine conflations, so a broken instrument must never be reported as a violated tree. The mirror defect is equally forbidden — it must never report `0` while any gate was skipped. `PREPUSH_STRICT=1` semantics apply: a SKIP is never a PASS. `verify.sh --prove-failure` runs every registered paired mutation and asserts its gate turns red; a gate whose mutation does not turn it red is reported **vacuous** and counted as **FAIL**, and at least one proof case MUST run the real entry point end to end rather than a sandboxed copy, because a proof that exercises only sandboxed copies can go green over an instrument that cannot start at all. Per §2.7 **N2** this script — a script, never a workflow — is what the umbrella's local pre-push hook calls (FR-032, FR-033, FR-040, SC-012, SC-013, SC-018)
- [ ] T105 [REVIEW] Final review against spec.md — every FR traced, every SC measured or explicitly recorded as not-yet-measurable

---

## Dependencies

```
Phase 1 Setup
    ↓
Phase 2 Foundational  ← BLOCKING: passage identity gates everything
    ↓
Phase 3 US1 transcript (P1) ── MVP
    ↓
Phase 4 US2 browse (P2)         [needs US1's transcript]
    ↓
Phase 5 US3 search (P3)         [needs US2's surface to present results]
    ↓
Phase 6 US4 answers (P4)        [needs US3's retrieval; L3 needs the pid registry]
    ↓
Phase 7 US5 add-chapter (P5)    [exercises the whole pipeline]
    ↓
Phase 8 Polish
```

**Cross-story dependency worth stating**: US4's L3 citation check depends on Phase 2's pid
registry, not on US3. If the registry were skipped, SC-009 becomes unreachable.

**FR-039 redaction spans five phases and is deliberately not a single task.** The registry half is
foundational (T011 resolution, T012 the append-only log); the CLI and the real Chapter 1 review land
in US1 (T038, T039, T040) because the transcript exists from T030 onward and FR-039 blocks its
export; propagation into search and cross-references is T059 and T061; propagation into stored
answers is T075; the composite gate G-PID-5 is T076, the earliest point at which all three
propagation paths exist to be proven; and the publish precondition is T087. **Removing any one of
them leaves FR-039 decorative**, which is why none of them sits in Phase 8.

**Code-passage identity (SC-016a) is gated on an unverified producer.** T014 must settle P-U1 and
exit `0` before T015, T016 and T017 may be started. If it exits `1`, SC-016a is not implementable as
specified and the gap is recorded rather than papered over — see Global Constraints.

## Parallel Opportunities

- **T004, T005, T006** — different languages, different directories
- **T018, T019, T020, T021** — independent foundational utilities
- **T046, T047, T048** — separate frontend feature directories
- **T062, T063** — search UI and its accessibility audit
- **T091–T095** — the whole documentation set, once contracts are fixed
- **`workshop` governance and gate work** is independent of all feature work

**Not parallelisable, despite looking it**: T015, T016 and T017 all depend on T014's outcome, and
T059, T061, T075 and T076 all depend on T012's redaction log.

## Independent Test Criteria

| Story | Independently testable by |
|---|---|
| US1 | Reading the transcript and sampling five passages against the recording |
| US2 | Starting the curriculum and opening Chapter 1 |
| US3 | Running the ≥20-query benchmark |
| US4 | Running the answer set and the ≥10 unanswerable set |
| US5 | Running `add-chapter.sh` twice on a synthetic chapter |

## Gate coverage — every contracted gate has a task that builds it

~~`contracts/` defines **30** distinct gate identifiers matching `G-[A-Z]+-[0-9]+`.~~ **COUNT
CORRECTED 2026-09-02: `contracts/` defines **31**.** Each row below names the task that builds the
gate **and** its §1.1 paired mutation. A gate defined in a contract and built by no task is a gate
that will not exist, so this table is the closure condition, not a convenience. Re-derive it rather
than trusting it — with the ATTACHMENT check, not the presence check:

```bash
# THE CLOSURE CHECK. A contract gate must be carried by a TASK LINE, not merely
# appear somewhere in this file. Prints one row per unattached gate; silence = closed.
cd specs/001-workshop-curriculum-platform
miss=0
for g in $(grep -rhoE 'G-[A-Z]+-[0-9]+' contracts/ | sort -u); do
  grep -qE "^[[:space:]]*-?[[:space:]]*\[[ xX]\][[:space:]]*T[0-9]+.*${g}([^0-9]|$)" tasks.md \
    || { echo "UNATTACHED $g"; miss=$((miss+1)); }
done
echo "unattached: $miss"     # MUST be 0 — measured 2026-09-02 it IS 0
```

> **WHY PRESENCE-COUNTING IS INSUFFICIENT, and this is the durable part of this section.** The
> obvious check is set difference over identifiers anywhere in the file:
>
> ```bash
> grep -rhoE 'G-[A-Z]+-[0-9]+' contracts/ | sort -u > /tmp/defined
> grep -ohE  'G-[A-Z]+-[0-9]+' tasks.md    | sort -u > /tmp/cited
> comm -23 /tmp/defined /tmp/cited     # NOT the closure condition — see below
> ```
>
> That form was the closure check here, and it **lied**. When the G-CLI-17 gap was first found it
> read 31 defined vs 30 cited and correctly printed `G-CLI-17`. Then the gap was **written down** —
> in prose, in this very section — and the prose mentioned `G-CLI-17` twice. The next run read
> **31 vs 31 and PASSED**, with the defect completely untouched: no task built the gate, and the
> only thing that had changed was that a paragraph now named it. **Documenting the defect turned
> the check green.** A presence check cannot tell a gate that is BUILT from a gate that is merely
> DISCUSSED, and prose about a gap is exactly the thing most likely to mention the gap's
> identifier. The attachment form above is anchored to a task line — `^[ ]*- [ ]` or `- [x]`
> followed by `T###` — so a mention in a note, a table, a dependency list or a withdrawal block
> counts for nothing. Verify the discrimination on one gate directly:
>
> ```bash
> grep -nE '^\s*-?\s*\[[ xX]\].*G-CLI-17' specs/001-workshop-curriculum-platform/tasks.md
> ```
>
> Keep both forms if you like — but read the ATTACHMENT one for the verdict. A check that a
> comment about the problem can satisfy is not a check.

> **THE G-CLI-17 GAP — RECORDED OPEN 2026-09-02, ASSIGNED 2026-09-02. Kept, not deleted, because
> the reason it was open is the lesson.** As found, `comm -23` printed **`G-CLI-17`** — a gate
> defined at `contracts/pipeline-cli.md:989` (`status.sh` against a project with no containers must
> print `STOPPED` and exit `1`, the determined-negative sibling of G-CLI-12's `2`) and cited by **no
> task in this file**. It was not a regression from the 2026-09-02 path sweep: the same command over
> `git show HEAD:specs/001-workshop-curriculum-platform/tasks.md` printed it too, so the gap predated
> that sweep and the sweep removed no gate identifier (30 cited before, 30 cited after).
>
> **The sentence this block used to carry — *"This block records the gap; it does not close it …
> the table below is therefore left at 30 rows and is knowingly incomplete"* — is WITHDRAWN, not
> restated.** The operator took the decision on 2026-09-02: **G-CLI-17 is assigned to T021**,
> alongside G-CLI-12, because the contract itself calls them siblings on the same script. The task
> line now carries the gate and its paired mutation, and the table below is **31 rows**. Assigning
> a gate changes what this file asks for, which is why it needed an operator decision and not a
> path correction — that reasoning stands; it has simply been answered.

| Gate | Built by | Gate | Built by |
|---|---|---|---|
| G-CLI-1 | T119 | G-CLI-9 | T107 |
| G-CLI-2 | T111 | G-CLI-10 | T106 |
| G-CLI-3 | T019 | G-CLI-11 | T100 |
| G-CLI-4 | T029 | G-CLI-12 | T021 |
| G-CLI-5 | T112 | G-CLI-13 | T081 |
| G-CLI-6 | T115 | G-CLI-14 | T080 |
| G-CLI-7 | T085 | G-CLI-15 | T114 |
| G-CLI-8 | T086 | G-CLI-16 | T110 |
| G-CLI-17 | T021 (with G-CLI-12; assigned 2026-09-02) | — | — |
| G-HTTP-1 | T055 | G-HTTP-5 | T081 |
| G-HTTP-2 | T055 | G-HTTP-6 | T117 |
| G-HTTP-3 | T055 | G-HTTP-7 | T057 |
| G-HTTP-4 | T056 | G-HTTP-8 | T053 |
| G-PID-1 | T013 | G-PID-4 | T017 |
| G-PID-2 | T013 | G-PID-5 | T076 |
| G-PID-3 | T066 | G-PID-6 | T113 |

~~**T120 (`verify.sh`) aggregates all thirty**~~ — **thirty-one** as of the 2026-09-02 G-CLI-17
assignment — and it is therefore sequenced after every one of them.
A gate whose mutation does not turn it red is **vacuous** and counts as FAIL there, not as a pass.

**Contracted scripts and their tasks**, so a missing entry point is as visible as a missing gate.
**Existence re-measured 2026-09-02** — BUILT means the file is on disk at the path shown, not that
its contracted option surface is complete:

| Script | Task | Measured 2026-09-02 |
|---|---|---|
| `workshop/scripts/build.sh` | T108 | BUILT |
| `workshop/scripts/{start,stop,status}.sh` | T021 | BUILT |
| `workshop/scripts/restart.sh` | T109 | BUILT |
| `workshop/scripts/verify.sh` | T120 | BUILT |
| `workshop/scripts/_common.sh` | T106, T107 | BUILT — but it is the container control-plane helper, not the §2.1 contract; §2.4/§2.5/§2.9 are absent |
| `workshop/scripts/transcribe.sh` | T111 | **[PATH NOT BUILT]** |
| `workshop/scripts/verify-accuracy.sh` | T112 | BUILT — and **RUN 2026-09-03** against the real chapter: exits **2** `UNDETERMINED: --reference is required`, a correct CANNOT DETERMINE. *"NEVER RUN … no `accuracy*.json` exists anywhere"* is **WITHDRAWN, not restated** — `chapters/01/transcript/accuracy-plan.json` exists. **No `accuracy.json`, so B2 is NOT met** (T037) |
| `workshop/scripts/ingest.sh` | T113 | BUILT — option surface is `[chapter-slug] [--require-suspend] [--corpus]` only |
| `workshop/scripts/index.sh` | T115 | **[PATH NOT BUILT]** |
| `workshop/scripts/crossref.sh` | T116 | **[PATH NOT BUILT]** |
| `workshop/scripts/redact.sh` | T038, T039 | **[PATH NOT BUILT]** |
| `workshop/scripts/add-chapter.sh` | T084 | **[PATH NOT BUILT]** |
| ~~`workshop/scripts/bench-suggest.sh` / `bench-search.sh`~~ | T065 | **[PATH CORRECTED]** → one Go binary, `workshop/platform/backend/cmd/bench/main.go`, `-endpoint suggest\|search` |
| `workshop/scripts/bench-retrieval.sh` | T118 | **[PATH NOT BUILT]** — and its input `retrieval.tsv` is absent too |
| ~~`workshop/scripts/bench-answers.sh`~~ | T078 | **[PATH CORRECTED]** → `workshop/platform/backend/gates/bench-answers.sh`, which exists and has run |

## Implementation Strategy

**MVP = Phase 1 + Phase 2 + Phase 3 (US1).** That delivers a faithful, measured, timestamped
transcript of Chapter 1 — which converts a 1.8 GB unusable asset into readable, quotable,
linkable knowledge. It is worth shipping even if nothing else is ever built. Its redaction review
(T040) is part of the MVP, not a follow-up: the recording features an identifiable third party, so
the MVP cannot be published without it.

~~**Deliberate sequencing around what does not exist**: no ASR engine and no generative model are
installed. US1 needs an ASR install (T005). US4 needs an operator `ollama pull` for its
generative path~~ — **BOTH PREMISES WITHDRAWN 2026-09-02, and withdrawn on measurement.** A dual
ASR stack is installed in a project-local venv (`workshop/pipeline/venv` with CT2 weights under
`workshop/pipeline/models/ct2/`, plus a CPU-only `workshop/pipeline/engines/whisper.cpp` build with
`ggml` weights), and `qwen2.5:3b-instruct-q4_K_M` is pulled and named in the running container's
`-answer-model` argv — see the withdrawal block at the head of Phase 6. Re-derive with `ollama list`
and `workshop/pipeline/venv/bin/python -c 'import faster_whisper'` rather than trusting this
sentence; note that bare `python3` still has no ASR engine, so a probe that runs the system
interpreter concludes the opposite and is wrong. What T005 still owes is `venv-setup.sh`, not the
engine. T069's `extractive` adapter delivers grounded answering with zero generative
capability, so US4 was never blocked outright and is not blocked now.

**Task count**: 120 · US1 22 · US2 11 · US3 20 · US4 16 · US5 7 · Setup 7 · Foundational 20 · Polish 17

Ids run T001–T120, contiguous and unique. The count was re-derived by parsing this file, not by
arithmetic on the previous line; re-derive it the same way rather than trusting the number:

```bash
awk '/^## Phase /{p=$0} /^- \[ \] T[0-9]+/{n++; c[p]++} END{for(k in c) print c[k], k; print "TOTAL", n}' \
  specs/001-workshop-curriculum-platform/tasks.md
```
