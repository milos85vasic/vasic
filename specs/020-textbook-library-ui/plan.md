# Implementation Plan: Textbook Library UI and Deterministic Textbook Ingestion

**Branch**: `020-textbook-library-ui` (workshop branch `feat/020-textbook-library`) | **Date**: 2026-10-20 | **Spec**: [spec.md](./spec.md)
**Input**: `spec.md`; analysis inputs `gap-analysis.md` §0.2/§4/§5, `architecture.md` §2 (conflict protocol), §3 (textbook ingestion end to end), §4 (test layers), `cycle-rules.md`.

## Summary

Two coupled deliverables on top of what 017 already built:

1. **Data** — `scripts/ingest-textbooks.sh`, a thin, auditable bash driver around the existing extractors and `ingest-transcript`, that produces the three books' sidecars,
   a deterministic **catalogue** (`curriculum/textbooks/catalogue.json`), a rows-only registry delta, and (through spec 019) a safe live merge. A three-arm **model-free guard** proves the procedure
   makes no network or model call.
2. **Surface** — a new server module `internal/textbooks` + `internal/api/textbooks*.go` (list, detail, citations, sections, pages, diagrams) and an Angular feature `features/textbooks/`
   (list, book, page, figures, citation component, "Search textbooks"). The server resolves citations **by pid** because the wire deliberately carries no source path any more (spec.md B8).

The design avoids four traps found while verifying the baseline: the redactor turning a page into "line N" (B8); the filename-shape guard turning ~3 passages into HTTP 410 (B11); the license
basis living only in a companion file (B4); pids being known only to the main sidecar after ingest (B5).

## Technical Context

**Language/Version**: Go 1.26 (backend), Python 3.14 stdlib (`pipeline/textbook_catalogue.py` — no network import), Bash (`scripts/`), TypeScript / Angular standalone components.

**Primary Dependencies**: existing only — `pipeline/pdf_textbook_sections.py`, `pipeline/pdf_textbook_diagrams.py` (poppler `pdftotext`/`pdfinfo`/`pdfimages`/`pdftocairo`, PIL),
`platform/bin/ingest-transcript`, `registry-restamp-content-type`, `internal/passagestore`, `internal/api` helpers, `internal/sourceref`, `pkg/search`, spec 019 scripts, the Angular
`WorkshopApi.passage`, `core/markdown.ts` not needed (page text is plain). No new third-party dependency.

**Storage**: tracked — `curriculum/textbooks/{books.json,<id>.sections.json,<id>.report.json,catalogue.json}`, `curriculum/passages.jsonl`; git-ignored —
`curriculum/textbooks/diagrams/<id>/*.png` and `diagrams.json` copies in scratch. No database change.

**Testing**: Go `testing` (`-race`, `Fuzz*`), pytest for the catalogue builder, shell tests with fixture PDFs, the three-arm guard, Karma, Playwright (`WORKSHOP_BASE_URL` = isolated server),
paired-mutation gates under `platform/gates/` (`prove-*.sh`), retrieval-only before/after benchmark.

**Target Platform**: single compose project `workshop-curriculum` (`:8087`); worktree streams verify on an isolated throwaway server; only the orchestrator runs real PDFs, merges and restarts.

**Constraints**:
- Single-writer rules (architecture.md §2.2): new files only — `internal/textbooks/*`, `internal/api/textbooks*.go`, `cmd/workshop-server/wire_textbooks.go`, `features/textbooks/*`,
  `scripts/ingest-textbooks*.sh`, `pipeline/textbook_catalogue.py`. Shared files via orchestrator hook lines only: `main.go` (1), `app.routes.ts` (1), `app.component.ts` nav (1),
  `core/vocabulary.ts` (rows), the search hit card (1) and the passage page (1) for `<wk-textbook-citation>`. `internal/passagestore/domain.go` is **not** touched (no new kind or content type).
- `pkg/search/service.go:resolveLocus` is **not** edited; citations come from the new resolver (a one-case locus edit is recorded as a possible follow-up only).
- Fail closed (§11.4.252): every new endpoint is an allow-list of fields; unknown/suppressed pids are indistinguishable; apply refuses on missing licence basis or missing verdict.
- Host safety (§12.6/§12.12): extraction under `scripts/agent-admit.sh -m 6G -T 3600` (the 991-page book took ~2 min in 017), one heavy job at a time, thread headroom checked first.
- Content boundary: private-submodule evidence only; counts, hashes, page numbers, ids.

**Scale/Scope**: 3 books, 1 697 pages total, ≈ 1 675 sections, ≈ 94+ figures (cookbook alone), registry 34 817 → ≈ 36 492 rows; catalogue ≈ 1 675 section entries (≈ 250 KB JSON).

## Constitution Check

| Anchor | How satisfied |
|---|---|
| §11.4.224 / §11.4.245 | RED tasks with named oracles for every code task; oracle is never the code under test (Python golden, kernel trace, listener log, sidecar page numbers) |
| §11.4.240 / §11.4.249 | separate test-author / implementer / reviewer agents; guard arms are independent of each other and of the procedure |
| §11.4.142 / §11.4.209 | `[REVIEW]` T016, T021, T040, T053, T067, T080, T082 (Opus, xhigh, verdict files with `finding_layer`) |
| §11.4.252 / §11.4.253 / §11.4.254 | fail-closed resolvers; idempotent apply (second run 0/0); unconditional mounts + boot log + catalogue invariants checked at load |
| §11.4.236 / §11.4.264 | merge and restart go through spec 019's verdict-bound seam; the same staged bytes are promoted |
| §11.4.262 / §11.4.266 | `result.json` + sha256 manifests (T031, T072); ledger rows (T081) |
| §11.4.257 / §11.4.258 | manual, 3 guides, FAQ, 4 diagram classes (T074-T080) |
| §9 | real-copy backup with pre-write digest; rollback rehearsed (T027) before the live step |
| §11.4.66 | operator go/no-go recorded (T028); decisions D-* recorded (T004) |
| §11.4.84 / §11.4.113 | explicit-path staging, mutation-marker grep; ff-only merge, no force |

No violation to justify (Complexity Tracking empty).

## Project Structure

### Documentation (this feature)

```text
specs/020-textbook-library-ui/
├── spec.md plan.md research.md data-model.md quickstart.md tasks.md
├── contracts/
│   ├── textbook-catalogue.md              # books.json -> catalogue.json
│   ├── textbooks-api.md                   # /api/textbooks* wire contract
│   └── textbook-ingestion-procedure.md    # ingest-textbooks.sh, exit codes, the model-free guard
└── checklists/requirements.md
```

### Source Code *(NEW unless stated)*

```text
workshop/curriculum/textbooks/                     # books.json (operator input, tracked), <id>.sections.json + .report.json (tracked),
│                                                  # catalogue.json (generated, tracked), diagrams/<id>/*.png (git-ignored)
workshop/pipeline/{textbook_catalogue.py,test_textbook_catalogue.py}
workshop/scripts/{ingest-textbooks.sh,ingest-textbooks.test.sh,ingest-textbooks.guard.test.sh}
workshop/platform/gates/{verify-textbook-ingest-model-free.sh,prove-textbook-ingest-model-free-mutation.sh,
                         verify-textbook-citations.sh,prove-textbook-citations-mutation.sh,
                         verify-textbook-figures.sh,prove-textbook-figures-mutation.sh}
workshop/platform/backend/
├── internal/textbooks/{catalogue.go,join.go,*_test.go,fuzz_test.go}
├── internal/api/{textbooks.go,textbooks_diagrams.go,textbooks_test.go,textbooks_diagrams_test.go}
└── cmd/workshop-server/{wire_textbooks.go,wire_textbooks_test.go}      # main.go: ORCH one-line hook
workshop/platform/frontend/src/app/
├── features/textbooks/{textbooks.routes.ts,textbooks-api.ts,textbooks-model.ts,textbooks-list.component.ts,
│                       textbook-book.component.ts,textbook-page.component.ts,textbook-figures.component.ts,
│                       textbook-citation.component.ts,textbook-search.component.ts,testing/textbooks.fixture.json,*.spec.ts}
├── app.routes.ts · app.component.ts · core/vocabulary.ts            # ORCH hook lines / rows
└── (search hit card, passage page)                                  # ORCH one line each: <wk-textbook-citation>
workshop/platform/frontend/e2e/{textbooks.spec.ts,textbook-citation.spec.ts}
workshop/docs/{textbooks.md,guides/textbooks-*.md}  + faq.md additions
workshop/evidence/020-<run>/                                          # machine evidence (private submodule)
```

## Execution Strategy

### TDD Requirements

Strict RED→GREEN for: catalogue builder + loader + join (T009-T014), the ingestion wrapper and the model-free guard (T017-T020), every endpoint (T033, T043, T047, T055, T061) and every component
(T036, T045, T049, T057, T063). RED output pasted into the task note; reviewers refuse a task with no RED record.

### Parallel Execution Opportunities

- After Phase 2: Phase 3 (data/procedure; the real-PDF steps are orchestrator-serial) and Phases 4-7 (code on the isolated server) are independent file sets and run as separate streams.
- US4 and US5 backends are independent of each other and of UI hooks; their UI parts wait for the orchestrator's route hook (T041).
- The real-PDF steps (T022-T026) and the live steps (T029-T031) are **not** parallel with any code-merge window (quiescent tree, one restart shared with 018's data).

### Human Checkpoints

1. T004 decisions D-*; 2. **T028 go/no-go** for the live merge (licence note, ~45-minute restart, rollback); 3. UI-visible acceptance walks T042, T054, T060, T068, T073.

### Review Gates

Independent Opus-xhigh review before each commit of: foundation (T016), guard (T021), list endpoints/UI (T040), citation + page (T053), figures (T067), docs exports (T080), whole feature (T082).

## Complexity Tracking

*(empty)*
