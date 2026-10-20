# Contract: `/api/textbooks*`

**Implements**: FR-006..FR-010 | **Handlers**: `internal/api/textbooks.go`, `textbooks_diagrams.go` (NEW) | **Mount**: `cmd/workshop-server/wire_textbooks.go` → `registerTextbooks(mux, cfg, loadedRegistry)`
(unconditional; one orchestrator hook line in `main.go`). **Auth**: session required via the existing `/api/` gate. Ids match `^[a-z0-9][a-z0-9-]{0,63}$` or answer 404 before any lookup.

## Endpoints

| Method + path | Returns |
|---|---|
| `GET /api/textbooks` | `{ "catalogue": "present"\|"absent", "books": [Book…] }` — Book per data-model §4 |
| `GET /api/textbooks/{id}` | `Book` + `chapters:[{index,title,first_page,last_page,sections}]` |
| `GET /api/textbooks/{id}/sections?offset=&limit=&chapter=` | `{ total, offset, limit, sections:[{pid,page,title}] }` — `limit` default 50, max 100; ordered by page; **no text** |
| `GET /api/textbooks/{id}/pages/{n}` | `{ book_id, book_title, page, pid, section_title, prev:{page,pid}\|null, next:{page,pid}\|null, diagrams:[index…] }` — **no text**; `n` is a canonical decimal (`+1`, `01` → 400 `bad_page`); `prev`/`next` skip pages without text; a suppressed page keeps its place (the passage endpoint answers it with 410) |
| `GET /api/textbooks/citations?pids=<csv>` | `{ "citations":[ {"pid":"…","citation":{book_id,book_title,section_title,page}\|null } … ] }` (≤ 50) |
| `GET /api/textbooks/{id}/diagrams` | `{ total, diagrams:[{index,page,caption,width,height,quality,redraw}] }` — no file name |
| `GET /api/textbooks/{id}/diagrams/{n}/image` | PNG bytes (see headers) |

Page **text** is read from the existing `GET /api/passages/{pid}` (the suppression and publication guards stay the single gate).

## Status codes *(three-valued)*

`200` determined (possibly empty) · `400` malformed parameter (`malformed_pid`, `too_many_pids`, `bad_offset`) · `404` unknown book / page without text (`page_has_no_text`) / figure out of range /
`figure_file_missing` / any path-ish input · `503` catalogue present but invalid or registry unavailable, with `reason.code` · `410 withheld` can still come from the shared `writeJSON` guard (B11) and is the
expected answer for the few passages whose text trips it — never produced by this module's own bodies (tested).

## Image headers

`Content-Type: image/png`, `X-Content-Type-Options: nosniff`, `Content-Security-Policy: default-src 'none'; sandbox`, `Cache-Control: private, max-age=3600`, `Content-Disposition: inline; filename="figure-<n>.png"`;
size cap 16 MB else `404 figure_file_missing`-class refusal with reason `figure_too_large`; the file is opened as `<curriculum>/textbooks/diagrams/<id>/<catalogue file>` after `resolveUnderRoot`.

## Invariants *(each has a test)*

1. Allow-listed fields; no key named `path`, `source_ref`, `file`, `filename`, `pdf`.
2. Every body passes `sourceref.RedactJSON` unchanged and `search.HasSourceFilenameShape` is false for it for the fixture bodies; a separate test documents that a body containing a `.zip`/`.wav`-shaped title is answered 410 by the shared guard, which is why the catalogue builder reports such titles (display titles: rc 1; section titles: listed for the operator, T010/T024).
3. `null` citations are byte-identical for unknown / non-textbook / suppressed pids.
4. Deterministic ordering; read-only; GET/HEAD only.
5. No route serves `.svg` or the original PDF (404).
