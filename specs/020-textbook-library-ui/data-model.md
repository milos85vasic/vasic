# Phase 1 Data Model: Textbook Library UI and Deterministic Textbook Ingestion

**Feature**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Research**: [research.md](./research.md)

No database change and no new passage kind or content type (`textbook_section` / `textbook` exist: `internal/passagestore/domain.go:71, 167, 199`). New entities are files plus derived views.

## 1. `books.json` *(operator input, tracked)*

```json
{ "schema": 1,
  "books": [ { "id": "ai001-openai-cookbook", "display_title": "…", "author": "…" | null,
               "scope_slug": "textbook-ai001-cookbook", "pdf": "textbooks/ai_001/<file>.pdf",
               "license_basis": "operator-directed 2026-10-20", "order": 1 } ] }
```
Rules: `id` matches `^[a-z0-9][a-z0-9-]{0,63}$` and is unique; `scope_slug` unique and **not** equal to any `chapters/<NN>` directory name (so `/api/chapters` excludes it structurally, 017); `license_basis`
non-empty and not `UNVERIFIED`; `pdf` is a repo-relative path used only by the host scripts (never copied into the catalogue); `display_title`/`author` must not match the filename-shape pattern.
(`scope_slug` values above are proposals — 017's scratch slugs are `UNCONFIRMED`.)

## 2. Sidecars *(tracked; produced by 017's extractor)*

`curriculum/textbooks/<id>.sections.json`: `{chapter_slug, source_file, sections:[{text, path, line_start, line_end, kind:"textbook_section", content_type:"textbook", pid?}]}` with
`line_start == line_end == PDF page`. `curriculum/textbooks/<id>.report.json`: `{license_basis, total_pages, sections:[{line, section_title, pid}], extraction_failures:[{page, reason}]}`.
`path` inside the main sidecar is the recorded source path (private repo only; stripped on the wire by `internal/sourceref`).

## 3. `catalogue.json` *(generated, tracked)*

```json
{ "schema": 1, "generated_from": {"books_json_sha256": "…"},
  "books": [ { "id": "…", "display_title": "…", "author": null, "scope_slug": "…", "license_basis": "operator-directed 2026-10-20",
               "pdf_sha256": "…", "total_pages": 0, "extraction_failures": 0,
               "sections": [ { "page": 57, "pid": "…", "title": "…" } ],
               "chapters": [ { "index": 0, "title": "…", "first_page": 1, "last_page": 12, "sections": 11 } ],
               "diagrams": [ { "index": 0, "page": 14, "caption": "…" | null, "width": 0, "height": 0,
                               "quality": "high" | "low", "redraw": "vector_source_available" | "none_available" | "undetermined",
                               "file": "img-014-001.png", "sha256": "…", "bytes": 0 } ],
               "order": 1 } ] }
```
Invariants *(checked by the builder and again by the Go loader)*: keys sorted, `\n` line endings, no absolute path / username / hostname / file name anywhere; `sections` ascending by unique `page`;
`chapters` partition `sections` exactly (`sum(sections)==len(sections)`); every diagram `file` is a bare name (no `/`); `license_basis` equals `books.json`'s; `--final` requires a `pid` on every section.

## 4. Book *(API view = catalogue ⨝ loaded registry)*

| Field | Type | Source |
|---|---|---|
| `id`, `title`, `author?`, `license_basis` | string | catalogue |
| `pages` | int | catalogue `total_pages` |
| `sections` | int | catalogue `len(sections)` |
| `live_sections` | int | registry rows with `scope == scope_slug`, kind `textbook_section`, not suppressed |
| `chapters` | int | catalogue |
| `diagrams` | `{total, high_quality, low_quality}` | catalogue |
| `state` | enum | `ingested` (`live_sections == sections`), `partial` (0 < live < sections), `not_ingested` (live == 0) |
| `pages_over_embed_limit` | int | registry text length > 6000 chars (informational) |
| `extraction_failures` | int | catalogue |

## 5. Citation *(`GET /api/textbooks/citations`)*

`{ "pid": "…", "citation": { "book_id": "…", "book_title": "…", "section_title": "…", "page": 57 } | null }`. `page` = registry `source_ref.line_start`; `section_title` = catalogue `sections[page].title`.

## 6. IngestionRun *(machine evidence JSON)*

`{run_id, books:[{id, pdf_sha256, pages, sections, stub_pages_skipped, extraction_failures, sidecar_sha256, seconds}], diagrams:[{id, candidates, high, low, vector_source_available, no_automated_redraw, bytes}],
rows_before, rows_after, added, changed_existing_rows (MUST be 0), second_run:{new, changed} (MUST be 0/0), filename_shape_rows, pages_over_embed_limit, model_calls (MUST be 0), tools_exec_d:[…],
backup:{path, sha256_before}, exit_class}`.

## 7. State machines

**Book state** (derived, never stored): `catalogued → not_ingested` (catalogue present, rows absent) `→ partial → ingested`; a registry rollback returns `ingested → not_ingested`.
**Page view load states**: `loading → ready | withheld (410 guard, plain words) | no_text (gap page) | unavailable (cause)`. **Procedure**: `extracted → dry_run_proved → operator_go → promoted → restarted → verified`
(any step may end `refused` rc 2; `promoted → rolled_back`).
