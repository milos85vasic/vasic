# Implementation Plan: Research Library and Research-Document Re-ingestion

**Branch**: `018-research-library-and-doc-reingest` (workshop branch `feat/018-research-library`) | **Date**: 2026-10-20 | **Spec**: [spec.md](./spec.md)
**Input**: `specs/018-research-library-and-doc-reingest/spec.md`; analysis inputs `gap-analysis.md` §0.3/§4/§5, `architecture.md` §2-§4, `cycle-rules.md`.

## Summary

Two independent halves joined by one UI:

1. **Door** — a metadata-only `GET /api/library` (new file in `internal/api/`), wired through a new
   `cmd/workshop-server/wire_library.go`, and a lazy Angular feature `features/library/` with a list page and a
   reader. Bytes keep flowing through the existing `/docs/` file server (`main.go:1669`). The reader reuses
   `core/markdown.ts` + `wk-document-view`; it adds no renderer.
2. **Content** — a deterministic wrapper `scripts/ingest-research.sh` (new) that regenerates the 5 missing
   research sidecars with the standing `md_sections.py` convention, excludes literally-`[REDACTED]` sections,
   dry-runs against a **copy** of the live registry, proves "rows added, nothing changed", then (orchestrator
   only) merges into the live registry with a §9 backup. It does not use `scripts/ingest.sh` corpus mode
   (spec.md B10).

Everything is deterministic: no language model, no speech recognition. Embedding of the new rows is done by the
server's existing boot pass with carry-forward (`-embed-carry-forward=true`), a local model call that spends no
tokens; spec 019 owns the restart.

## Technical Context

**Language/Version**: Go 1.26 (backend `platform/backend`), TypeScript / Angular (standalone components, lazy
routes) in `platform/frontend`, Bash (`scripts/`), Python 3.14 (`pipeline/md_sections.py`, run via the project venv
`pipeline/venv/bin/python`, as `ingest.sh` does).

**Primary Dependencies**: existing only — `internal/api` (`documentTitle`, `docsHref` helpers in `sections.go`,
callable from a sibling file in the same package without editing it), `pkg/authhttp` gate (inherited by every
`/api/*` route), `internal/passagestore`, `cmd/ingest-transcript`, `pipeline/md_sections.py`, `core/markdown.ts`,
`features/section/document-view.component.ts`.

**Storage**: none new. The listing is derived per request from the docs root; searchable counts are derived from
the in-memory registry (`api.RegistryAdapter.All()`), cached per registry load.

**Testing**: Go `testing` (+ `-race` for the handler's cache), Karma unit tests, Playwright e2e against a running
stack (`WORKSHOP_BASE_URL`), paired-mutation gates under `platform/gates/` (`prove-*.sh` convention), pytest for
the redaction-exclusion filter. Fuzz target for the path validator (`Fuzz*`, 60 s).

**Target Platform**: the single compose project `workshop-curriculum` (port 8087). Worktree streams use an
isolated throwaway server (architecture.md §2.2 rule 6); only the orchestrator runs `restart.sh`.

**Constraints**:
- Single-writer rules (architecture.md §2.2): feature code goes in NEW files — `internal/api/library.go`,
  `cmd/workshop-server/wire_library.go`, `frontend/src/app/features/library/*`. `main.go`, `app.routes.ts`,
  `vocabulary.ts`, `app.component.ts` are touched only by the orchestrator's one-line hooks.
- `/docs/` and `/api/library` are session-gated (`main.go:3570`); the e2e must authenticate.
- Fail closed (§11.4.252): the handler mutates nothing, but takes a path-like parameter; ambiguous input → refusal.
- Host safety (§12.6/§12.12): heavy steps wrapped by `scripts/agent-admit.sh`; no parallel ingest.
- Private content boundary: evidence files hold counts, ids and hashes — never passage text.

**Scale/Scope**: 9 documents + 5 supporting files today; the handler must stay O(tree) and < 50 ms for ≤ 500
files (SC budget asserted by a benchmark test).

## Constitution Check *(canon pin read from `submodules/constitution`; anchors named, not paraphrased from memory beyond their headings)*

| Anchor | How this plan satisfies it |
|---|---|
| §11.4.224 / §11.4.245 test-first, named oracle | every task writes the failing test first; oracle named per task (disk `find`, golden JSON, independent hash) |
| §11.4.240 / §11.4.249 producer ≠ verifier | test-authoring, implementation and review are separate subagents; review agents never edit tests |
| §11.4.142 / §11.4.209 independent review, Opus xhigh | `[REVIEW]` tasks T012, T022, T031, T037, T052, T054; model + effort stamped in the verdict file |
| §11.4.252 fail closed | path validator refuses on any ambiguity; ingest wrapper exits 2 when redaction state is undeterminable |
| §11.4.253 idempotency | second ingest = 0 new / 0 changed, proven (T030) |
| §11.4.254 boot-time invariants | `registerLibrary` refuses to mount (and the status row says so) when the docs root is absent — 503 `docs_unconfigured`, never a bare 404 |
| §11.4.257 / §11.4.258 docs + diagrams | manual, 3 guides, FAQ, 4 diagram classes (T046-T051) |
| §11.4.262 / §11.4.266 machine evidence, claim ledger | `result.json` + sha256 manifest (T044); ledger rows (T053) |
| §11.4.84 commit hygiene | pre-commit mutation-marker grep recorded in every commit task |
| §11.4.113 no force-push | n/a to code; stated in the merge task |
| §9 backup before destructive op | real-copy backup of `passages.jsonl` before the live merge (T033) |

**Result**: no violations to justify (Complexity Tracking empty).

## Project Structure

### Documentation (this feature)

```text
specs/018-research-library-and-doc-reingest/
├── spec.md  plan.md  research.md  data-model.md  quickstart.md  tasks.md
├── contracts/
│   ├── library-api.md                   # GET /api/library wire contract
│   └── research-reingest-stage.md       # wrapper contract, exit codes, evidence
└── checklists/requirements.md
```

### Source Code *(real paths; NEW = file does not exist today)*

```text
workshop/platform/backend/
├── internal/api/
│   ├── library.go                       # NEW  LibraryHandler, enumerateLibrary
│   ├── library_sources.go               # NEW  LibrarySourcesHandler (pid -> document resolver, FR-016)
│   ├── library_test.go                  # NEW  table + golden + fuzz seeds
│   ├── library_fuzz_test.go             # NEW  FuzzLibraryPath
│   └── sections.go                      # UNCHANGED (documentTitle, docsHref reused in-package)
├── cmd/workshop-server/
│   ├── wire_library.go                  # NEW  registerLibrary(mux, cfg, reg)
│   ├── wire_library_test.go             # NEW  503-vs-404 mount test
│   └── main.go                          # ORCHESTRATOR ONE-LINE HOOK ONLY: registerLibrary(...)
workshop/platform/frontend/src/app/
├── features/library/
│   ├── library.routes.ts                # NEW  lazy child routes
│   ├── library-list.component.ts        # NEW  /library
│   ├── library-reader.component.ts      # NEW  /library/read?doc=
│   ├── library-api.ts                   # NEW  settled-value service (never errors on the next channel)
│   ├── library-model.ts                 # NEW  normaliseLibrary(), id codec
│   └── *.spec.ts                        # NEW  unit specs
├── app.routes.ts                        # ORCHESTRATOR HOOK: one path entry loading library.routes
├── app.component.ts                     # ORCHESTRATOR HOOK: Library nav link
└── core/vocabulary.ts                   # ORCHESTRATOR HOOK: four label rows (document kinds)
workshop/platform/frontend/e2e/library.spec.ts           # NEW Playwright
workshop/scripts/ingest-research.sh                      # NEW wrapper (three-valued exit)
workshop/scripts/ingest-research.test.sh                 # NEW shell tests (redaction filter, guard)
workshop/pipeline/research_redaction_filter.py           # NEW removes literal-[REDACTED] sections from a sidecar
workshop/pipeline/test_research_redaction_filter.py      # NEW pytest
workshop/platform/gates/verify-library-listing.sh        # NEW + prove-library-listing-mutation.sh
workshop/platform/gates/verify-research-reingest.sh      # NEW + prove-research-reingest-mutation.sh
workshop/docs/library.md (+ .html/.pdf/.sections.json)   # NEW manual; guides/ and faq.md additions
workshop/evidence/018-<run>/                             # NEW machine evidence (private submodule)
```

## Execution Strategy

### TDD Requirements

Strict RED→GREEN for: path validator (T006-T008), listing enumeration (T009-T011), redaction filter
(T024-T026), ingest wrapper guard (T027-T029), reader component (T016-T018). RED output is pasted into the
task note; the reviewer refuses a task with no RED record (§11.4.224).

### Parallel Execution Opportunities

- US1 backend (T006-T012) and US1 frontend list (T013-T015, against the contract mock in `contracts/library-api.md`)
  run in parallel — disjoint files.
- US3 (ingest wrapper, T024-T035) shares no file with US1/US2 and runs in parallel from the start.
- The live merge (T033-T035) is **not** parallel with any code-merge window: it needs a quiescent tree and one
  restart, shared with the wave's other data changes (spec 019 procedure).

### Human Checkpoints

1. Q1-Q3 operator decisions (spec.md Clarifications) — defaults implemented unless overridden before T030.
2. Approval of the live registry merge (T033) — data change to a tracked 34 MB file; never automated.
3. UI-visible acceptance walk-through (T045) with the operator watching.

### Review Gates

Independent review (separate agent, Opus, xhigh) before each commit of: handler + validator, reader component,
redaction filter + wrapper, live-merge evidence, docs. Verdict files carry `finding_layer` tags (§11.4.235D).

## Complexity Tracking

*(empty — no constitution violation)*
