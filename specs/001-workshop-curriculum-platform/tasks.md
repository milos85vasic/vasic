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
- **Container orchestration MUST consume `git@github.com:vasic-digital/containers.git` as a git
  submodule** and MUST extend rather than reimplement it (§11.4.76(1),(4)).
- **Rootless container runtime** (§11.4.161). Host has podman 5.7.1; **docker is absent**.
- **Local/internal only** (decision D1). No content leaves the machine when a local provider is
  configured (FR-024).
- **Corpus is the `workshop/` module plus the `vasic` monorepo** (decision D2). Nothing outside
  this working tree.

## File Structure

Decomposition decisions locked in here. Files that change together live together; split by
responsibility, not by technical layer.

| Path | Responsibility |
|---|---|
| `workshop/platform/backend/internal/passage/` | pid minting, source anchors, registry. **The contract every other unit depends on** |
| `workshop/platform/backend/internal/verdict/` | the 0/1/2 three-valued result type, used by every command and endpoint |
| `workshop/platform/backend/internal/transcript/` | immutable machine layer + append-only correction overlay |
| `workshop/platform/backend/internal/store/` | chapter/material persistence |
| `workshop/platform/backend/internal/media/` | local range-serve with seek |
| `workshop/platform/backend/internal/search/` | lexical leg, semantic leg, and the three-state verdict that fuses them |
| `workshop/platform/backend/internal/index/` | generations, verification gate, atomic swap |
| `workshop/platform/backend/internal/crossref/` | passage relationships, cycle-safe traversal |
| `workshop/platform/backend/internal/answer/` | provider seam + the four grounding layers |
| `workshop/pipeline/transcribe/` | VAD, chunking, ASR driver, confidence, checkpointing, coverage |
| `workshop/pipeline/accuracy/` | frozen normaliser + WER scorer + its mutation proof |
| `workshop/pipeline/benchmark/` | the query set and the adversarial unanswerable set |
| `workshop/platform/frontend/src/app/features/` | chapters, transcript, search — one directory each |
| `workshop/scripts/` | thin bash wrappers over `submodules/containers`' `cmd/boot`, plus `add-chapter.sh` |
| `workshop/docs/` | quickstart, user guide, manual, FAQ, training, and the honest-limits page |
| `workshop/evidence/` | machine evidence, retained with the commit that produced it |

**Deliberately NOT created**: a bespoke `Containerfile` or compose stack. §11.4.76 makes that a
violation, not a shortcut — orchestration is consumed from the submodule.

## Task Format

```
[ID] [markers] [Story] Description
```

**Markers**: `[P]` parallelisable · `[TDD]` RED-GREEN-REFACTOR · `[REVIEW]` review before proceeding · `[SUBAGENT]` delegable

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

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: make the module buildable and its dependencies real.

- [ ] T001 Create the module skeleton `workshop/platform/{backend,frontend,bin}` and `workshop/{curriculum,pipeline,docs,evidence}` per plan.md Structure Decision — note NO `workshop/containers/` directory: orchestration is consumed from `submodules/containers`, and a local container stack would violate §11.4.76(4)
- [ ] T002 Initialise the Go module in `workshop/platform/backend/go.mod` (Go 1.26.2, matching `ai_interviewing/platform/backend/go.mod`)
- [ ] T003 Add `replace digital.vasic.containers => ../../../submodules/containers` to `workshop/platform/backend/go.mod` per §11.4.76(2), and verify it builds
- [ ] T004 [P] Scaffold the Angular client in `workshop/platform/frontend` mirroring `ai_interviewing/platform/frontend` conventions (package name, Karma/Jasmine, no new UI framework)
- [ ] T005 [P] Create `workshop/pipeline/requirements.txt` pinning `faster-whisper` + `ctranslate2`, and `workshop/pipeline/venv-setup.sh` building a project-local venv
- [ ] T006 [P] Configure linting/formatting to match the reference module (`gofmt`, Angular ESLint config)
- [ ] T007 [REVIEW] Verify `workshop/` still adds zero CI: `git -C workshop ls-files | grep -E '^\.github/workflows/.*\.ya?ml$'` must be empty, and `bash scripts/pre-push-gates.sh` gate E must pass

**Execution notes**: T003 is the §11.4.76 obligation — the build must consume the submodule, not a vendored copy. Verify the module builds before proceeding.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: the passage contract and environment detection. **No user story can begin until this
phase is complete** — every story depends on the passage identity contract.

- [ ] T008 [TDD] [REVIEW] Implement the ULID passage identifier minter in `workshop/platform/backend/internal/passage/pid.go` per [contracts/passage-contract.md](./contracts/passage-contract.md) — minted at ingest, never positional, never content-derived
- [ ] T009 [TDD] Implement the `<!-- pid: … -->` source anchor reader/writer in `workshop/platform/backend/internal/passage/anchor.go`
- [ ] T010 [TDD] Implement the passage registry (`passages.jsonl` → `passages.db`) in `workshop/platform/backend/internal/passage/registry.go`, with `content_hash` as a change-detection column explicitly documented as NOT identity
- [ ] T011 [TDD] Prove the two survival guarantees in `workshop/platform/backend/internal/passage/pid_test.go`: a text correction must NOT change the pid, and a line-position shift must NOT change the pid (this is SC-016; both alternatives were measured to fail — see research.md D-SEARCH-1)
- [ ] T012 [P] [TDD] Implement three-valued exit helpers in `workshop/platform/backend/internal/verdict/verdict.go` (0 / 1 / 2) used by every command and endpoint
- [ ] T013 [P] [TDD] Implement media-tooling detection in `workshop/pipeline/detect_media.sh` — probe `ffmpeg`/`ffprobe` for actual capability, not `--version`; `ffprobe` here is a Playwright symlink that answers `--version` and rejects `-show_format`
- [ ] T014 [P] [TDD] Implement backend/model detection in `workshop/pipeline/detect_backend.sh` following `scripts/lumen-reindex.sh`'s env → config → live probe → documented fallback ladder
- [ ] T015 [P] Create thin bash wrappers `workshop/scripts/{start,stop,status}.sh` that invoke `submodules/containers`' `cmd/boot` — consumption, not reimplementation (§11.4.76(4)). A bash boot wrapper does not exist upstream; anything beyond thin wrapping must be contributed there
- [ ] T016 [REVIEW] Review the passage contract implementation against [contracts/passage-contract.md](./contracts/passage-contract.md) before anything consumes it — every other component depends on its shape

**Checkpoint**: passage identity is proven to survive correction and movement. Stop here for human approval.

---

## Phase 3: User Story 1 — Read what was actually said (Priority: P1) 🎯 MVP

**Goal**: a faithful, timestamped, verifiable transcript of Chapter 1.

**Independent test**: open the markdown transcript, read Chapter 1 end to end, sample five passages at random and confirm each is accurate and its timestamp lands on the corresponding moment.

- [ ] T017 [US1] Wire `workshop/pipeline/transcribe/reassemble.sh` to invoke the EXISTING `workshop/scripts/extract-videos.sh` — FR-007 is already implemented there with per-part, archive and extracted-video hash verification; do not reimplement it
- [ ] T018 [US1] [TDD] Implement silence detection in `workshop/pipeline/transcribe/vad.py` producing the non-speech span set (the 8 measured silences totalling 41.33 s are a free test fixture)
- [ ] T019 [US1] [TDD] Implement ≤300 s chunking that cuts INSIDE measured silence, in `workshop/pipeline/transcribe/chunker.py`
- [ ] T020 [US1] [TDD] Implement the faster-whisper driver in `workshop/pipeline/transcribe/asr.py` with `condition_on_previous_text=False` — the same setting that makes it resumable also suppresses repetition-loop hallucination
- [ ] T021 [US1] [TDD] Map engine confidence (`avg_logprob`, `no_speech_prob`) to the `uncertain` flag in `workshop/pipeline/transcribe/confidence.py` — FR-003 requires marking, never guessing
- [ ] T022 [US1] [TDD] Implement atomic checkpoint/resume (write-temp → fsync → rename) in `workshop/pipeline/transcribe/checkpoint.py` per FR-029
- [ ] T023 [US1] [TDD] Implement the coverage identity check in `workshop/pipeline/transcribe/coverage.py`: passage spans ∪ VAD silence MUST equal `[0, duration_s)` exactly — this makes SC-001 arithmetic rather than judgement
- [ ] T024 [US1] Emit the markdown transcript with pid anchors and timestamps to `workshop/chapters/01/transcript/transcript.md`
- [ ] T025 [US1] [TDD] Implement the immutable machine layer + append-only correction overlay in `workshop/platform/backend/internal/transcript/layers.go` per FR-038 — the machine output is evidence and must survive correction
- [ ] T026 [US1] [P] Extract the notes PDF text layer in `workshop/pipeline/transcribe/pdf_notes.py` for section structure and a proper-noun gazetteer ONLY — never ground truth; it is a summary and it renders "Spatkit" for SpecKit
- [ ] T027 [US1] [TDD] [REVIEW] Implement the WER scorer in `workshop/pipeline/accuracy/score.py` sampling the AUDIO TIMELINE (≥30 stratified 30 s windows), not passages — sampling passages makes whole-region deletions structurally invisible and biases accuracy upward exactly where the transcript is worst
- [ ] T028 [US1] Freeze and hash the normaliser in `workshop/pipeline/accuracy/normaliser.py` BEFORE the first measurement
- [ ] T029 [US1] [TDD] Paired mutation proof for the scorer in `workshop/pipeline/accuracy/score_mutation_test.sh` — a transcript with a known injected WER must produce that WER
- [ ] T030 [US1] Run the 5-minute calibration on the extracted 300 s sample; this settles research open items U1, U2 and U3 in one run
- [ ] T031 [US1] Produce and publish `workshop/chapters/01/transcript/accuracy-report.md` with the measured figure and its confidence interval
- [ ] T032 [US1] [REVIEW] Human review checkpoint: speaker attribution is HUMAN (D-TRANS-2 — the recording is dual-mono at −90.3 dB and AGC-flattened, so both diarization cues are measurably absent)

**Checkpoint**: transcript exists with a measured accuracy figure. Stop for human approval — everything downstream inherits this artifact's quality.

---

## Phase 4: User Story 2 — Browse and watch (Priority: P2)

**Goal**: the curriculum is browsable and the recording plays.

**Independent test**: start with the documented command, confirm Chapter 1 is listed, its materials readable, its recording plays.

- [ ] T033 [US2] [TDD] Implement the chapter model + store in `workshop/platform/backend/internal/store/chapter.go` per [data-model.md](./data-model.md)
- [ ] T034 [US2] [TDD] Implement `GET /api/chapters` and `GET /api/chapters/{slug}` per [contracts/http-api.md](./contracts/http-api.md)
- [ ] T035 [US2] [TDD] Implement `GET /api/chapters/{slug}/transcript` returning passages with pid, timestamps, provenance and uncertainty
- [ ] T036 [US2] [TDD] Implement local recording range-serve with seek in `workshop/platform/backend/internal/media/serve.go` — a local file with HTTP range support (decision D3), NOT a streaming service
- [ ] T037 [US2] [P] [SUBAGENT] Build the chapter list and detail views in `workshop/platform/frontend/src/app/features/chapters/`
- [ ] T038 [US2] [P] [SUBAGENT] Build the transcript reader with timestamp→recording seek in `workshop/platform/frontend/src/app/features/transcript/`
- [ ] T039 [US2] [P] Reuse `design-system/learning-kit/` curriculum CSS (verified present, framework-free, on the `--od-*` token contract) rather than authoring new styling
- [ ] T040 [US2] [TDD] Persist reader position/progress per FR-010
- [ ] T041 [US2] [TDD] Prove SC-003: transcript passage → recording seek lands within 5 s, in `workshop/platform/frontend/src/app/features/transcript/seek.spec.ts`
- [ ] T042 [US2] Write `workshop/docs/quickstart.md` and time a fresh-clone-to-running run against SC-004's 15-minute budget

**Checkpoint**: a reader can consume Chapter 1 without a terminal. Stop for approval.

---

## Phase 5: User Story 3 — Find anything by meaning (Priority: P3)

**Goal**: semantic search with fast type-ahead and cross-references.

**Independent test**: issue meaning-based queries whose expected passages are known, including queries sharing no literal words with the target.

- [ ] T043 [US3] [TDD] Implement the lexical FTS5 prefix index in `workshop/platform/backend/internal/search/lexical.go` — measured p95 9.58 ms; FTS5 works in `modernc.org/sqlite`, already a dependency, so no new library
- [ ] T044 [US3] [TDD] Implement `GET /api/suggest` backed by the LEXICAL path only — a query embedding measured 18–21 s under load, so semantics cannot meet SC-005's 200 ms budget
- [ ] T045 [US3] [TDD] Implement the semantic leg in `workshop/platform/backend/internal/search/semantic.go` over the passage registry
- [ ] T046 [US3] [TDD] [REVIEW] Implement the three-state contract in `workshop/platform/backend/internal/search/verdict.go` per [contracts/http-api.md](./contracts/http-api.md) invariants I1–I9 — including **I5: `no_match` requires EVERY enabled leg to have succeeded**; if a leg failed and survivors found nothing, that is `unavailable`, never "no results"
- [ ] T047 [US3] [TDD] Parse and promote Lumen's glued `"No results found. | Warning: Index is being updated…"` string to `degraded`, never forward it as a result
- [ ] T048 [US3] [TDD] Paired mutation proof for the degradation contract — the mutation is literally restoring the `error: () => loading.set(false)` handler shape; the gate MUST go red
- [ ] T049 [US3] [TDD] Implement index generations with a verification gate and atomic swap in `workshop/platform/backend/internal/index/generation.go` — measured necessity: during a live rebuild `chunks` moved while `last_indexed_at` still advertised the previous generation
- [ ] T050 [US3] [TDD] Implement cross-reference derivation and storage in `workshop/platform/backend/internal/crossref/`, cycle-safe per the spec edge case
- [ ] T051 [US3] [P] [SUBAGENT] Build the search UI with type-ahead in `workshop/platform/frontend/src/app/features/search/` — it MUST render the three states distinguishably; the reference anti-pattern is `ai_interviewing/.../search.component.ts`
- [ ] T052 [US3] [P] [TDD] WCAG 2.1 AA + full keyboard operability for search (FR-041, FR-042, SC-017); `@axe-core/playwright` is already a dependency of `_tests/` with `_tests/evidence/a11y-audit/run-audit.js` as precedent
- [ ] T053 [US3] Build the ≥20-query benchmark in `workshop/pipeline/benchmark/queries.yaml`, including ≥8 queries sharing no literal words with their target (SC-007, SC-008)
- [ ] T054 [US3] [TDD] Measure and record p95 latencies for suggest and search (SC-005, SC-006), with the load conditions stated
- [ ] T055 [US3] [TDD] Prove SC-016: correct a transcript passage, re-index, and confirm 100% of prior cross-references and citations still resolve
- [ ] T056 [US3] Document the media boundary in `workshop/docs/search.md` — audio and video are reachable THROUGH transcripts, not indexed directly; Lumen's extension allowlist is a compile-time var with no override (FR-031 requires stating what the system cannot do)

**Checkpoint**: search works and degrades honestly. Stop for approval.

---

## Phase 6: User Story 4 — Ask a question, get a grounded answer (Priority: P4)

**Goal**: cited answers that refuse rather than fabricate.

**Independent test**: questions with known answers return correct cited answers; genuinely unanswerable questions are all declined.

**BLOCKED ON AN OPERATOR ACTION**: no generative model exists on this host — ollama serves two models and both are the same embedding model; the whole store is 309 MB, too small for a decoder. The `extractive` adapter path (T058) is the executable-today route and needs no generative model.

- [ ] T057 [US4] [TDD] [REVIEW] Implement the `Provider` interface with adapters `none` (default), `extractive`, `ollama`, `openai_compatible` in `workshop/platform/backend/internal/answer/provider.go` — copy the interface SHAPE from `LLMProvider`, not the dependency (its module path is unresolvable and it carries a relative-path `replace` on a sibling checkout absent from `.gitmodules`)
- [ ] T058 [US4] [TDD] Implement the `extractive` adapter — ~0.3 s, genuinely grounded, structurally unable to fabricate, and works today with zero generative capability
- [ ] T059 [US4] [TDD] Implement L1: the calibrated retrieval gate with BOTH `min_score` and `min_margin` — the margin test is what catches the near-miss that scores high while being unanswerable
- [ ] T060 [US4] [TDD] Implement L2: JSON-schema-constrained generation where `"minItems": 1` on citations makes an uncited claim structurally undecodable
- [ ] T061 [US4] [TDD] Implement L3: deterministic citation pid set-membership against the LIVE generation — **SC-009 is unreachable without this**; attaching a citation is easy, proving it points at a real passage is a microsecond set check
- [ ] T062 [US4] [TDD] Implement L4: support verification (embedding floor, then batched entailment)
- [ ] T063 [US4] [TDD] Any layer failing ⇒ refuse the WHOLE answer; never strip claims silently
- [ ] T064 [US4] Build the ≥10-question adversarial unanswerable set in `workshop/pipeline/benchmark/unanswerable.yaml` using the taxonomy (near-miss attribute, false premise, uncomputable aggregate, misattributed speaker, lexically-overlapping-but-unanswerable, redacted passage, inaudible segment) — ten astrophysics questions would pass any threshold and prove nothing
- [ ] T065 [US4] [TDD] Prove SC-010: 10/10 declined, 0 fabricated. Record `score(top1)` and margin on every run so a 0.002-margin pass is visible as FRAGILE
- [ ] T066 [US4] [TDD] Prove SC-009 over ≥20 answers with human certification per citation
- [ ] T067 [US4] [TDD] [REVIEW] Enforce FR-024 privacy: resolved-address allowlist (`net.LookupIP` + `IsLoopback`, not string matching), egress-denied namespace with a NEGATIVE CONTROL (`curl https://example.com` from inside MUST fail), and packet capture asserting zero non-loopback packets. A config flag is not a guarantee
- [ ] T068 [US4] [TDD] Enforce FR-025 by SEPARATE ROUTE TREES at compile time — browsing and search must survive answering being unavailable, and `unavailable` must remain distinct from `refused`
- [ ] T069 [US4] Implement the ingest exclusive lock that suspends answering while search continues from the existing generation (D-LLM-10)
- [ ] T070 [US4] Document in `workshop/docs/answering.md` that answering is ASYNCHRONOUS — CPU-only generation is ~21 s (1.5B) to ~95 s (7B) idle, so "instant" is off by two orders of magnitude and no prompt engineering closes it. `estimated_seconds` MUST be `null` until measured

**Checkpoint**: answers are cited or refused, never fabricated. Stop for approval.

---

## Phase 7: User Story 5 — Add a chapter (Priority: P5)

**Goal**: one documented, repeatable, idempotent procedure.

**Independent test**: run it against a synthetic chapter; it appears fully integrated with no code change. Run it twice; nothing duplicates.

- [ ] T071 [US5] [TDD] Implement `workshop/scripts/add-chapter.sh` per [contracts/pipeline-cli.md](./contracts/pipeline-cli.md) — transcribe → ingest → index → cross-link, with no code edit required
- [ ] T072 [US5] [TDD] Prove idempotency (FR-027): a second run changes nothing and duplicates no passage, keyed on pid
- [ ] T073 [US5] [TDD] Incomplete materials MUST report precisely what is missing and MUST NOT publish a partial chapter as complete (FR-028)
- [ ] T074 [US5] Make the procedure accept a PRE-SUPPLIED TRANSCRIPT FIXTURE so idempotency and identity can be proven without running ASR — otherwise every US5 proof inherits the ASR block
- [ ] T075 [US5] Write the reusable extension prompt in `workshop/docs/add-chapter-prompt.md` — the operator-facing artifact requested
- [ ] T076 [US5] [TDD] Prove SC-011: a new chapter integrated in under 30 minutes hands-on with zero code or config change

**Checkpoint**: the curriculum is extensible without engineering. Stop for approval.

---

## Phase 8: Polish & Cross-Cutting Concerns

- [ ] T077 [P] [SUBAGENT] Write `workshop/docs/user-guide.md`
- [ ] T078 [P] [SUBAGENT] Write `workshop/docs/manual.md` (operator)
- [ ] T079 [P] [SUBAGENT] Write `workshop/docs/faq.md`
- [ ] T080 [P] [SUBAGENT] Write `workshop/docs/training.md` and `workshop/docs/tutorial-quickstart.md`
- [ ] T081 [P] Document every limit honestly per FR-031: no direct media indexing, asynchronous answering, code-passage identity weaker than transcript identity (SC-016a), and every operator-only step
- [ ] T082 [TDD] Register every check this feature adds in the check registry so `scripts/verify-check-registry.sh` can enforce SC-012 and SC-013 mechanically
- [ ] T083 [TDD] Verify EVERY feature check has a paired mutation proof including a real-entry-point case (SC-012)
- [ ] T084 [TDD] Verify EVERY feature check distinguishes could-not-determine from pass and fail (SC-013)
- [ ] T085 Write machine evidence to `workshop/evidence/` retained with the commit that produced it (FR-040)
- [ ] T086 [REVIEW] Confirm zero CI added anywhere: `bash scripts/pre-push-gates.sh` gate E green across the fleet (SC-014)
- [ ] T087 Update `CONTINUATION.md` and confirm `bash scripts/continuation-check.sh` is rc=0 (FR-035, §12.10)
- [ ] T088 Confirm `workshop/`'s four governance carriers remain in lockstep — `bash scripts/verify-governance-cascade.sh` C8 (FR-035)
- [ ] T089 [REVIEW] Run the whole gate suite green: pre-push-gates, verify-governance-cascade (+ `--prove-failure`), verify-manifest-pins, continuation-check, audit-hardcoded-paths, audit-environment-assumptions
- [ ] T090 Commit and push the umbrella and every submodule to all upstreams; verify each with `git ls-remote`, not a push log (FR-036, SC-015)
- [ ] T091 [REVIEW] Final review against spec.md — every FR traced, every SC measured or explicitly recorded as not-yet-measurable

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

## Parallel Opportunities

- **T004, T005, T006** — different languages, different directories
- **T012, T013, T014, T015** — independent foundational utilities
- **T037, T038, T039** — separate frontend feature directories
- **T051, T052** — search UI and its accessibility audit
- **T077–T081** — the whole documentation set, once contracts are fixed
- **`workshop` governance and gate work** is independent of all feature work

## Independent Test Criteria

| Story | Independently testable by |
|---|---|
| US1 | Reading the transcript and sampling five passages against the recording |
| US2 | Starting the curriculum and opening Chapter 1 |
| US3 | Running the ≥20-query benchmark |
| US4 | Running the answer set and the ≥10 unanswerable set |
| US5 | Running `add-chapter.sh` twice on a synthetic chapter |

## Implementation Strategy

**MVP = Phase 1 + Phase 2 + Phase 3 (US1).** That delivers a faithful, measured, timestamped
transcript of Chapter 1 — which converts a 1.8 GB unusable asset into readable, quotable,
linkable knowledge. It is worth shipping even if nothing else is ever built.

**Deliberate sequencing around what does not exist**: no ASR engine and no generative model are
installed. US1 needs an ASR install (T005). US4 needs an operator `ollama pull` for its
generative path, but T058's `extractive` adapter delivers grounded answering with zero generative
capability, so US4 is not blocked outright.

**Task count**: 91 · US1 16 · US2 10 · US3 14 · US4 14 · US5 6 · Setup 7 · Foundational 9 · Polish 15
