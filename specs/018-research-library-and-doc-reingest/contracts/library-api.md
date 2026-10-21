# Contract: `GET /api/library`

**Implements**: FR-001, FR-002, FR-003 | **Handler**: `workshop/platform/backend/internal/api/library.go` (NEW)
**Mount**: `cmd/workshop-server/wire_library.go` → `registerLibrary(mux, cfg, reg)`; the only `main.go` change is the
orchestrator's one-line hook. **Auth**: session required (the `/api/` gate); no new auth surface.

## Request

```text
GET /api/library                    # default library name "research"
GET /api/library?name=research      # name matches ^[a-z0-9][a-z0-9-]{0,63}$ AND is a published library: only `research`
```

No other query parameters. Unknown parameters are ignored (not an error), as in `sections`.

## Responses *(three-valued)*

### 200 — the tree was read (possibly empty = determined negative)

```json
{
  "library": "research",
  "groups": [
    { "id": "", "documents": [ { "id": "<stem>", "title": "…", "title_source": "heading",
        "group": "", "kind": "document",
        "formats": { "md": "/docs/research/<stem>.md", "html": "/docs/research/<stem>.html",
                     "pdf": "/docs/research/<stem>.pdf", "source": null },
        "bytes": 12345, "searchable": "indexed", "passages": 59, "withheld_sections": 0 } ] },
    { "id": "clients/jordan", "documents": [ … ] },
    { "id": "education-platform", "documents": [ … ] },
    { "id": "education-platform/poc", "documents": [ { "kind": "supporting_binary", "formats": { "source": "/docs/research/education-platform/poc/<file>" }, … } ] }
  ],
  "counts": { "documents": 9, "supporting_files": 5, "groups": 4, "undetermined": 0 },
  "undetermined": []
}
```

`counts.documents` counts `kind=document`; `supporting_files` counts the other kinds. The numbers shown are the
tree as measured on 2026-10-20 (spec.md B1) — a test oracle, not a constant in the handler.

### 404 — `library_not_found`

`{"error":{"code":"library_not_found","message":"no library by that name","field":"name"}}` — name invalid, the
directory does not exist, or the name is not a published library (only `research` is; `/docs/` refuses directory
listings by design, so no other docs subtree becomes browsable through `?name=`). A determined negative.

### 503 — could not determine

`{"status":"unavailable","reason":{"code":"docs_unconfigured"|"docs_unreadable","message":"…"}}` — mounted
unconditionally (same discipline as `sections`, `main.go:1544-1552`) so "cannot say" never arrives as a bare 404.

## Invariants *(each has a test)*

1. **Metadata only** — the response never contains file bytes, never contains section text.
2. **Fail closed paths** — a name or id containing `..`, a NUL, a backslash, an encoded `/` (`%2f`), an absolute path,
   or resolving (after `filepath.EvalSymlinks`) outside the research root is never listed and never accepted;
   such a file found during the walk is reported in `undetermined` with reason `symlink_escape` / `outside_root`.
3. **Extension allow-list** — `.md`, `.html`, `.pdf` group into one document; `.py`, `.ts`, `.sh` are
   `supporting_code`; `.json`, `.jsonl`, `.txt` are `supporting_data`; `.epub` and any other extension are
   `supporting_binary`. `*.sections.json` is **never** listed (internal).
4. **Deterministic** — groups ordered by id, documents by id; two calls on an unchanged tree are byte-identical.
5a. **One bad entry never withholds the listing** — every entry is judged in the form it has on the wire (JSON-escaped,
   percent-encoded); a title that is source-filename-shaped there falls back to the stem, and an entry whose id,
   href or group still is, is not listed and is reported as `withheld_name` under a safe path. The listing answers 200.
5b. **Never advertise a link the server refuses** — with the suppression guard installed, a file it is certain to
   answer 410 (unclassified type, backup copy, an export without a source document) is not listed and is reported
   in `undetermined` with the guard's reason (`unclassified_file_type`, `backup_file_not_served`,
   `export_source_unresolved`). A refusal that depends on file CONTENT stays an honest 410 at download time.
5c. **Unique ids, no silent gap** — ids are lookup keys: a supporting file whose id equals a document's is excluded
   (`duplicate_id`), a second file for an already-filled format slot (`x.md` + `x.MD`) is `duplicate_format`, a name
   containing a backslash is `withheld_name`, a walk past the entry cap stops with `too_many_entries`. All appear in
   `undetermined`.
5. **No title leakage of disallowed names** — titles come from file content or stem exactly as `sections` does; the
   existing `writeJSON` disclosure guard stays in force underneath.
5d. **Bounded cost** — per-file metadata is read once per (path, size, mtime) with a fixed 16 KiB buffer and cached
   (bounded); walks are shared between concurrent requests and capped at 4 at a time; a walk visits at most
   20 000 entries.
6. **No state mutation** — read-only; `HEAD` and `GET` only; other verbs → 405 like other routes.

## `GET /api/library/sources?pids=<csv>` *(FR-016)*

```json
{ "sources": [ { "pid": "<pid>", "document": { "id": "<id>", "title": "…" } },
               { "pid": "<pid>", "document": null } ] }
```
Rules: ≤ 50 pids (`400 too_many_pids`); each pid must match the pid grammar used by `GET /api/passages/{pid}` (`400 malformed_pid`);
order = request order; a pid whose registry `source_ref.path` is not under the research root, is unknown, or is suppressed → `document: null`
(indistinguishable, by design); `document.id` is always a member of the `/api/library` listing. The body has **no** `path`/`source_ref`
key — the serialisation-boundary redactor (`internal/sourceref`) must have nothing to rewrite, and a test asserts the bytes are unchanged by it.

## Client mock *(for parallel frontend development)*

`workshop/platform/frontend/src/app/features/library/testing/library.fixture.json` is a golden copy of a 200 body for
the current tree; the frontend unit tests bind to it and the live gate diffs the live response against `find`.
