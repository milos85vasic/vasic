# Implementation Plan: Workshop Curriculum Platform

**Branch**: `001-workshop-curriculum-platform` | **Date**: 2026-08-31 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `specs/001-workshop-curriculum-platform/spec.md`

## Summary

Turn a 1.8 GB workshop recording into a browsable, searchable curriculum.

The primary requirement is a faithful, verifiable transcript (User Story 1) — everything else is
built on it. On top of that sits a chapter-browsing interface modelled on the existing
`ai_interviewing` module (US2), a semantic search layer over all curriculum content with stable
citable passages (US3), grounded question answering that refuses rather than fabricates (US4),
and a repeatable procedure for adding each new chapter (US5).

The technical approach reuses what this repository already runs — a Go backend, an Angular
frontend, the existing Lumen semantic index, and the local ollama inference endpoint — and adds
transcription, a passage-identity layer, and a search interface. **Five premises did not survive
verification** and are corrected in Technical Context below — including two of this plan's own.

## Technical Context

**Language/Version**: Go 1.26.2 (backend, matching `ai_interviewing/platform/backend/go.mod`);
TypeScript/Angular (frontend, matching `ai_interviewing/platform/frontend`, package name
`ai-curriculum`); Python 3.14.6 and Bash for pipeline tooling.

**Primary Dependencies**: `ffmpeg` for media handling — **but see the corrected premise below:
`ffprobe` is NOT installed**, and `ffmpeg` itself resolves into an npx-managed Playwright cache.
`faster-whisper` (CTranslate2, CPU int8, `large-v3-turbo`) for speech recognition — **not
installed; must be added in a project-local venv**. Lumen for semantic indexing over text.
ollama at `http://localhost:11434` for embeddings only — **it serves no generative model**.

**Storage**: Files on disk for source material, transcripts and curriculum content. SQLite for
the derived index, following the pattern the existing Lumen index already uses. No external
database — decision D1 makes the system single-machine.

**Testing**: Go's built-in testing for the backend; Karma + Jasmine for the frontend, matching
the reference module; Bash harness tests for pipeline scripts, following the repository's
existing convention of behavioural assertions with paired mutation proofs.

**Target Platform**: Linux, single machine, local/internal only (decision D1). Host container
runtime is **podman + podman-compose**; `docker` is **absent** on this host.

**Project Type**: Web application (Go service + Angular client) with an offline content pipeline.

**Performance Goals**: Suggestions ≤200 ms p95 (SC-005); search results ≤2 s p95 (SC-006);
≥90% top-5 accuracy on a 20-query benchmark (SC-007); ≥80% success on queries sharing no literal
words with the target (SC-008).

**Constraints**: CPU-only inference — the repository deliberately forces `library=cpu` and
`GGML_VK_VISIBLE_DEVICES=-1` after a GPU fault corrupted the index. 8 CPUs. No content leaves the
machine when a local model is configured (FR-024). No server-side CI may be added (FR-034).

### Five corrected premises

These are recorded because the request or an earlier draft of this plan assumed each of them,
and none held when measured. Three concern the environment and two concern this plan's own
earlier claims — both kinds are listed, because a plan that hides its own corrections is not
evidence of anything.

**1. The reference module is not containerised — and a bespoke stack would have been a
violation.** The request says the curriculum must run "through the containers same way" as
`ai_interviewing`. Measured: `ai_interviewing` contains **zero** container definitions; it runs as
a native Go binary (`platform/bin/aicur`) serving an Angular frontend. So "the same way" cannot
mean copying a setup that does not exist.

More importantly, the obvious fallback — hand-rolling a Containerfile — is forbidden. **§11.4.76**
(verified verbatim at `submodules/constitution/Constitution.md:7113`) mandates that for ANY
containerised workload the project MUST consume `git@github.com:vasic-digital/containers.git` as a
git submodule, and clause (4) requires **extending it, never reimplementing it**. It was not
declared in this tree.

*Resolution*: the submodule is now mounted at `submodules/containers` — the tree's `submodules/`
path is for non-product infrastructure gitlinks (`constitution`, `superspec`), and containers is a
consumed Go library, not a product. It classifies OWNED automatically, because
`github.com/vasic-digital` now hosts three declared submodules and the fleet roster derives
ownership from that evidence rather than a hardcoded list.

*What it actually provides* — verified by building it and running its tests, not read off its
README: six runtime backends behind one interface with **podman first, explicitly for rootless**
(satisfying §11.4.161); compose orchestration that detects the compose CLI and resolves to
`podman-compose` on this host, correctly suppressing the docker-only `--wait` flag and defending
against the podman-docker shim; TCP/HTTP/gRPC health checkers; lazy boot with idle shutdown; and a
`cmd/boot` CLI. It is Go-only, which fits — the workshop backend is Go 1.26.2.

*Three gaps named rather than discovered later*:
- **No bash boot wrapper exists.** The request's "all mandatory bash scripts" is not satisfied by
  the submodule; lifecycle is a Go API plus Go CLIs. Thin workshop wrappers that invoke `cmd/boot`
  are *consumption*, so they are §11.4.76-legal. Anything beyond that must be contributed upstream.
- `DefaultHelixServices()` is postgres/redis/etcd-shaped, irrelevant here — but not a defect, since
  `ComposeProject.File` accepts an arbitrary compose file, so the workshop supplies its own.
- **`submodules/containers/scripts/build-all.sh` is broken upstream**: it builds `./cmd/core/` and
  `./cmd/host-agent/`, neither of which exists. Do not use it as a model.

*One blocker it exposed*: the submodule's own four carriers are 414/246/24/24 lines — four
genuinely different documents, a §11.4.157(B) violation latent upstream. The new C8 in-submodule
lockstep check catches it, which currently blocks the pre-push hook. Being fixed upstream per
§11.4.76(4), not worked around locally.

**2. Generative capability — resolved, and the answer is "none".** Superseded by premise 5
below, which measured it. US1–US3 are deliberately sequenced to deliver value without it, and
FR-025 already requires browsing and search to work when answering is unavailable, so US4
degrades to a documented operator step rather than blocking the feature.

**3. `ffprobe` is not installed, and `ffmpeg` is not durably installed either.** An earlier
draft of this plan asserted "ffmpeg/ffprobe 7.0.2 (present on host)". Measured:
`$(command -v ffprobe)` resolves to a **symlink to Playwright's ffmpeg binary** and rejects
`-show_format` ("Unrecognized option"). The original probe ran `ffprobe --version`, which the
ffmpeg binary accepts — so a tool that does not exist looked present. Both `ffmpeg` and
`ffprobe` resolve into `~/.cache/ms-playwright/ffmpeg-1011/`, an npx-managed cache that a
`npx playwright uninstall` or a cache clean would remove.

*Consequence*: any pipeline step invoking `ffprobe` fails here with what reads like a bad-argument
error rather than a missing-binary error. The pipeline MUST detect its media tooling rather than
assume it (Environment Adaptability), and MUST NOT depend on a browser-automation cache for a
production content pipeline.

**4. No speech-recognition engine is installed.** `/usr/bin/whisper` is `whisper-1.3.1-alt1`, a
microphone-loopback GUI by a different author — not OpenAI Whisper; `import whisper` fails.
ollama's `/v1/audio/transcriptions` endpoint is real, but its Whisper strings are an *encoder*
projecting audio into an LLM token space; `word_timestamps`, `avg_logprob` and `no_speech_prob`
appear nowhere in the binary, so it cannot satisfy FR-002 (timestamps) or FR-003 (confidence).

**5. There is no generative model, so User Story 4 cannot run at all today.** ollama serves
exactly two models and they are the **same** embedding model (`jina-bert-v2`, 160.28M, an encoder
with no LM head). The entire model store is 309 MB across 7 blobs — too small to hold a decoder.
US4 is blocked on an operator `ollama pull`, not on code. Corroborating trap: `~/helix-agent` is
a 23.7 MB **cluster mesh node** (SWIM / WireGuard / etcd), not an LLM agent; and HelixLLM appears
in this repository only as portfolio marketing copy.

**Measured recording properties** (these, not "1.8 GB", drive every estimate):
duration **01:55:28.75 (6928.75 s)**, H.264 1920x1080 24 fps, AAC-LC 48 kHz stereo — but the
stereo is **dual-mono** (L-R difference -90.3 dB), so channel-based speaker separation is
impossible. Uniformly AGC-compressed. Only 8 long silences totalling 41.33 s (0.597%).
The notes PDF has a real text layer (3,034 words) — a **summary**, roughly 26 words per minute
of recording, and demonstrably erroneous ("Spatkit" for SpecKit), which is why the spec makes the
recording authoritative.

**Open items entering Phase 1**:

- Whether Lumen's chunk identifiers are stable across re-index — determines whether FR-037 needs
  its own identity layer. Highest-risk unknown: SC-016 fails silently if wrong. Research pending.
- Whether the cp314 wheels for CTranslate2/faster-whisper install and run on this host.
- Real transcription throughput, settled by a 5-minute calibration run on an already-extracted
  300 s sample.

## Constitution Check

*GATE: Must pass before proceeding. Re-check after design phase.*

Principles taken from `.specify/memory/constitution.md`, which inherits from the constitution
submodule.

| Principle | Status | Notes |
|-----------|--------|-------|
| **Evidence-Based Claims** — no guessing, no fabrication (§11.4) | **PASS** | The spec's Context table records only measured values. FR-004 requires a *measured* accuracy figure, not an assertion. FR-033 forbids reporting a check as passed when it could not run. This plan corrects two premises that measurement disproved rather than carrying them forward. |
| **Governance Fidelity** — four carriers in lockstep; constitution is authoritative | **PASS** (was NEEDS ATTENTION) | Resolved 2026-09-01, after this row was first written. `workshop` carried none of the four carriers (coverage 20/24) and `verify-governance-cascade.sh` FAILed C1 and C6 on it. All four are now present **and committed** in that submodule at `55076bf` — committing mattered, because until then a fresh `git submodule update --init` would have reconstructed a `workshop` without them. Coverage is 24/24; the verifier reports 10 PASS / 0 FAIL / rc=0, and its `--prove-failure` — which was itself inoperative, failing at CONTROL so zero mutations were ever reached — now runs the real entry point first. |
| **Isolation by Default** — mutation-paired gates; hardlinked backup before destructive ops (§1.1, §9) | **PASS** | FR-032 and SC-012 require every check to carry a paired proof that it fails when its condition is broken. The transcription pipeline reads source media and never writes to it (FR-006). |
| **Comprehensive Documentation** — CONTINUATION.md updated; honest boundaries | **PASS** | FR-030/031 mandate the doc set including an explicit statement of what the system cannot do. FR-035 covers CONTINUATION.md. |
| **Quality Over Speed** — 60% RAM cap, TDD, lint/typecheck before "done" | **PASS** | Execution Strategy below marks the correctness-critical components `[TDD]`. Transcription is chunked and resumable (FR-029), keeping memory bounded rather than loading a 1.8 GB file whole. |
| **§11.4.156 — no active server-side CI** | **PASS** | FR-034 and SC-014 forbid adding any. The repository's local pre-push gate remains the enforcement point. |

**Gate result (initial): PROCEED**, with one blocking prerequisite — `workshop` governance
onboarding. That prerequisite is now **discharged** (see the row above).

### Post-design re-check (2026-09-01, after Phase 1)

Re-evaluated against the design rather than the intent, as the gate requires.

| Principle | Status | What the design does about it |
|---|---|---|
| Evidence-Based Claims | **PASS** | Phase 0 replaced five assumed premises with measurements and withdrew two of this plan's own claims explicitly. `research.md` carries an UNVERIFIED register (U1–U5) naming what settles each. |
| Honest Instruments | **PASS** | The 0/1/2 contract is bound into the design, not bolted on: `Answer.verdict` has `unavailable` as a first-class third state distinct from `refused`, and D-SEARCH-4 forbids deriving degradation from a liveness probe — measured necessity, since `health_check` returned OK 2 ms before `semantic_search` failed. |
| Governance Fidelity | **PASS** | 24/24 carriers, committed. |
| Isolation by Default | **PASS** | Every gate this feature adds owes a paired mutation proof (FR-032/SC-012). The quickstart enumerates 14 such proofs as owed rather than assumed. |
| Comprehensive Documentation | **PASS** | FR-030/031 require the doc set to state what the system cannot do — which now includes real limits: media is reachable only via transcripts (D-SEARCH-3), and answering is asynchronous, not instant (D-LLM-5). |
| Environment Adaptability | **PASS** | The pipeline must detect its media tooling rather than assume it — a rule this plan earned by asserting `ffprobe` was present when it is a Playwright symlink. |
| Quality Over Speed | **PASS** | Transcription is chunked and resumable, so memory stays bounded rather than loading a 1.8 GB file whole. |
| §11.4.156 — no server-side CI | **PASS**, and strengthened | Enforcement itself was defective: gate E swept only the umbrella, so an added workflow inside `workshop/` would have shipped unnoticed. Closed and mutation-proven on 2026-09-01. |

**Post-design gate result: PROCEED to `/speckit-tasks`.** No unjustified violation. The two
Complexity Tracking entries stand, and the second is no longer speculative — D-SEARCH-1 measured
that Lumen chunk IDs are content-derived, so the passage-identity layer is required.

## Project Structure

### Documentation (this feature)

```text
specs/001-workshop-curriculum-platform/
├── spec.md                  # Feature specification
├── plan.md                  # This file
├── research.md              # Phase 0 consolidated findings
├── research/
│   ├── transcription.md     # ASR engine, accuracy methodology, resumability
│   ├── search-architecture.md  # Index design, passage identity, autocomplete
│   └── llm-bridging.md      # Provider seam, grounding, refusal design
├── data-model.md            # Phase 1 entities
├── contracts/               # Phase 1 interface contracts
├── quickstart.md            # Phase 1 validation guide
├── tasks.md                 # Task breakdown
└── checklists/
    └── requirements.md      # Spec quality checklist
```

### Source Code (repository root)

```text
workshop/                             # the feature's home (a submodule)
├── CLAUDE.md AGENTS.md QWEN.md GEMINI.md   # governance carriers — PREREQUISITE, absent today
├── chapters/
│   └── 01/                           # existing: recording parts, .sha256, notes PDF
│       └── transcript/               # NEW: machine transcript + corrections + evidence
├── curriculum/                       # NEW: published, browsable chapter content
├── platform/                         # NEW: mirrors ai_interviewing/platform layout
│   ├── backend/                      # Go service: content, search, answering
│   ├── frontend/                     # Angular client: browse, watch, search UI
│   └── bin/
├── pipeline/                         # NEW: offline content pipeline
│   ├── transcribe/                   # media → timestamped passages
│   ├── ingest/                       # passages → stable ids → index
│   └── crossref/                     # passage relationships
├── scripts/                          # existing archive/extract/hooks + NEW run/build/test
│                                     # NO containers/ dir — orchestration is CONSUMED from
│                                     # submodules/containers; a local stack violates §11.4.76(4)
└── docs/                             # NEW: quickstart, user guide, manual, FAQ, training
```

**Structure Decision**: mirror `ai_interviewing/platform`'s `backend/` + `frontend/` + `bin/`
split, because the spec's FR-013 requires a person familiar with one module to navigate the
other, and because that layout is already proven in this repository. Everything the workshop
needs that `ai_interviewing` does not have — the transcription pipeline, passage identity,
containers — is added alongside rather than by reshaping the reference.

The feature lives inside the `workshop/` submodule, not the umbrella. That keeps the curriculum
independently cloneable and keeps the umbrella's working tree clean, which FR-036 requires.

## Execution Strategy

### TDD Requirements

Marked `[TDD]` in the task breakdown. Chosen where a defect would be silent rather than loud.

- [ ] **Passage identity and cross-reference resolution**: SC-016 demands 100% of references
      still resolve after correction plus re-index. This fails *invisibly* — links keep
      rendering, they just point at the wrong text. Tests must exist before the implementation.
- [ ] **Refusal behaviour in question answering**: SC-010 requires 10/10 unanswerable questions
      declined. A system that fabricates confidently is the single worst outcome this feature
      can produce, and the governing constitution names it as a release blocker.
- [ ] **Citation verification**: SC-009 requires 100% of citations to genuinely support their
      claim. Attaching a citation is easy; verifying it supports the claim is the actual work.
- [ ] **Three-state search contract**: results / no-match / cannot-answer. This repository has
      already shipped the failure once — a saturated backend produced timeouts that a naive
      client would render as "no results".
- [ ] **Transcript accuracy measurement**: the sampling and scoring harness must be correct
      before any accuracy figure is published, or the number means nothing.
- [ ] **Extension procedure idempotency**: FR-027 requires a second run to change nothing.

### Parallel Execution Opportunities

Marked `[SUBAGENT]`. These share no files.

- [ ] **Transcription pipeline** and **frontend search UI** — different languages, different
      directories, joined only by the passage contract.
- [ ] **Documentation set** (quickstart, user guide, manual, FAQ, training) can proceed once
      the contracts are fixed, independently of implementation.
- [ ] **Container definitions** and **backend service** — the container work depends only on
      the run commands, not on their internals.
- [ ] **`workshop` governance onboarding** is fully independent of all feature work and should
      start immediately; it is a prerequisite for completion, not for progress.

### Human Checkpoints

The agent pauses and waits for explicit approval at each.

1. **After Phase 0 research** — before committing to an ASR engine and an index architecture,
   because both are expensive to reverse.
2. **After foundational setup** — `workshop` governance onboarding green, project structure in
   place, gates passing.
3. **After User Story 1** — the transcript and its *measured* accuracy figure reviewed. This is
   the gate that matters most: everything downstream inherits this artifact's quality.
4. **After each subsequent user story** — behaviour checked against that story's acceptance
   scenarios.
5. **Before merge** — full gate suite green, `CONTINUATION.md` synced, all submodules and the
   umbrella committed and pushed clean (FR-036, SC-015).

### Review Gates

Marked `[REVIEW]`.

- [ ] **Passage contract** (identity, timestamps, provenance) — review before anything consumes
      it; every other component depends on its shape.
- [ ] **Privacy handling** — the redaction path (FR-039) and the local-only guarantee (FR-024)
      concern an identifiable third party. Review before integration.
- [ ] **Answering prompt and refusal thresholds** — review before enabling, because a permissive
      threshold silently converts refusals into fabrications.
- [ ] **Container definitions** — first containers in this module; review before they become
      the pattern others copy.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| Adding a submodule dependency (`vasic-digital/containers`) that the reference module does not use | Not actually optional: §11.4.76 mandates it for ANY containerised workload and clause (4) forbids reimplementing it. Hand-rolling a Containerfile would satisfy the operator's container request while violating the constitution the same request demands be respected. | Running natively like `ai_interviewing` adds zero new concepts — but forgoes containers entirely, which the operator asked for explicitly, and inherits the host-drift problem this repo has repeatedly been bitten by (podman-not-docker, ugrep-not-GNU-grep, a GPU that must stay out of the inference path). Writing a bespoke Containerfile was rejected outright as a §11.4.76 violation, not merely as inferior. |
| A passage-identity layer duplicating what the index appears to provide | FR-037 requires identifiers that survive re-indexing AND text correction. | Reusing Lumen's chunk identifiers was the preferred outcome and is now **rejected on measurement** (D-SEARCH-1): a controlled three-run re-index showed a one-character typo fix changes the id, while a line shift does not — they are content-derived, exactly one of the two forms FR-037 forbids, and the one that breaks on the operation this feature performs most. Built on them, SC-016 would score 0% on every corrected passage with no visible symptom. The ids are not exposed through the CLI or MCP either, leaving only a positional key, which the same experiment showed moves. |

## Phase Status

- **Phase 0 (Research)**: IN PROGRESS. Three research streams dispatched — transcription,
  search architecture, LLM bridging. Consolidated into `research.md` on completion.
- **Phase 1 (Design & Contracts)**: NOT STARTED. Requires Phase 0.
