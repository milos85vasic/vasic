# Phase 1 Data Model: Research Library and Research-Document Re-ingestion

**Feature**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Research**: [research.md](./research.md)

No new storage. Entities are derived views over the docs tree and the loaded registry, plus one on-disk artefact
type (the tracked sidecar) that already exists.

## 1. LibraryDocument *(derived, per request)*

| Field | Type | Rule |
|---|---|---|
| `id` | string | percent-encoded relative path **without** extension, relative to the research root, `/`-separated (e.g. a root doc `<stem>`; nested `<dir>/<dir>/<stem>`). Unique. Never a title. |
| `title` / `title_source` | string / enum | from `documentTitle` (`sections.go:329`): first heading, else file stem. `title_source` ∈ {`heading`,`stem`}. |
| `group` | string | directory part of `id` (`""` = root research). |
| `kind` | enum | `document` (has `.md`), `supporting_code` (`.py`,`.ts`,`.sh`), `supporting_data` (`.json`,`.txt`,`.jsonl`), `supporting_binary` (anything else, e.g. `.epub`). |
| `formats` | map | keys `md`,`html`,`pdf`,`source`; value = `/docs/research/<rel>` href or `null`. `sections_json` is **not** exposed (internal artefact). |
| `bytes` | int | size of the primary file (`md` or `source`). |
| `searchable` | enum | `indexed` (≥ 1 registry row with this `source_ref.path`), `partial` (some sections of the file have rows, some do not), `not_indexed`, `undetermined` (registry not loaded). |
| `passages` | int \| null | rows counted for the path; null when `undetermined`. |
| `withheld_sections` | int | count of suppressed rows for the path + count of literal `[REDACTED]` headings in the `.md`. A number only; no text. |

**Validation**: every `formats` href MUST resolve (HEAD under session → 200) — enforced by the live gate; `id` MUST
round-trip through the codec (`decode(encode(p)) == p`).

**State**: none (stateless). `searchable` changes only when the registry is reloaded (next boot).

## 2. LibraryGroup *(derived)*

`{ id: string, label: string, documents: LibraryDocument[] }`, ordered: root research (`""`), then groups in path
order. `label` comes from the frontend vocabulary (hook rows), never from the server (server sends ids only).

## 3. UndeterminedEntry *(derived)*

`{ path: string, reason: "unreadable" | "outside_root" | "symlink_escape" | "name_invalid" }`. A failure below the
root is reported here and the response still carries what was read (mirrors `sectionUndetermined`).

## 4. ResearchSidecar *(existing tracked artefact, regenerated)*

Path: `workshop/docs/research/<rel-stem>.sections.json`. Shape is `docPayload` as decoded by
`cmd/ingest-transcript` with `DisallowUnknownFields` (`main.go:157-165`):

```json
{ "chapter_slug": "docs", "source_file": "<name>.md",
  "sections": [ { "text": "…", "path": "docs/research/<rel>.md", "line_start": 1, "line_end": 24,
                  "kind": "doc_section", "content_type": "authored_lesson", "pid": "<assigned after first ingest>" } ] }
```

Rules: every row has `content_type` ∈ allowed(kind); rows whose text is the literal `[REDACTED]` are removed before
ingest; after the first ingest each row carries `pid` (written back by `ingest-transcript`); the sidecar is committed
with the registry (it is the identity store, spec 017 research §5).

## 5. ReingestRun *(machine evidence, one JSON)*

| Field | Type | Notes |
|---|---|---|
| `run_id` | string | `research-<UTC>` |
| `docs` | array | per document: `{path, sections_in_sidecar, sections_excluded_redacted, sections_added}` |
| `rows_before` / `rows_after` | int | registry line counts |
| `changed_existing_rows` | int | MUST be 0 |
| `filename_shape_rows` | int | added rows whose text matches the writeJSON source-filename-shape pattern (served 410 `withheld`); informational, expected 1 |
| `second_run` | `{new:int, changed:int}` | MUST be `{0,0}` |
| `model_calls` | int | MUST be 0 (guard test count) |
| `backup` | `{path, sha256_before, distinctness_gate_rc}` | |
| `exit_class` | enum | `0` / `1` / `2` |

## 6. Relationships

`LibraryDocument 1—* registry rows` via `source_ref.path` (derived, not stored). `LibraryDocument 1—1 ResearchSidecar`
for `kind=document`. `ReingestRun *—* ResearchSidecar`.
