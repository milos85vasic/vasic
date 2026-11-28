# Lumen index doctor — schema-mismatch bug fixes

## Summary

Fixed the schema-mismatch bugs in `scripts/lumen-index-doctor.sh` so the
doctor reads the real lumen index schema (multi-project `projects` /
`project_meta` / `file_revisions` / `project_files` / `chunk_defs` +
sqlite-vec shadow tables) instead of the nonexistent flat `files` /
`chunks` tables, and so it never requires the `vec0` extension to be
loadable. The fixed doctor was then run against the vasic project.

**Result: `EXIT=0`, `✅ index healthy`, stderr empty.**

## Command run

```bash
bash scripts/lumen-index-doctor.sh /home/milosvasic/Projects/vasic
```

The index is opened read-only (`mode=ro`); the real index is never written.

## Output from the fixed doctor (vasic project)

```
index: /home/milosvasic/.local/share/lumen/b75ce15456b7b206/index.db
model: ordis/jina-embeddings-v2-base-code
backend: ollama at http://localhost:11434 (reachable: yes)
integrity_check: SKIPPED (7 GB exceeds LUMEN_DOCTOR_MAX_INTEGRITY_GB=2.0 GB)
files: 64454 fully indexed, 0 incomplete | chunks: 1568822
vector width: 768 int8 (derived from: block bytes on disk=768; vec0 declaration=768)
slots: 1562985 live, 104087 freed/unwritten (excluded from every check below)
vectors: 1562985 total, 1562985 distinct
✅ every stored vector is distinct
per-vector: NaN/Inf n/a (int8), 0 all-zero, 0 off-scale (max|component| != 127; 100.00% of live vectors share it), 0 ragged block(s)

✅ index healthy
```

The file/chunk counts now reflect **project 1 (`/home/milosvasic/Projects/vasic`)**
only (verified against `project_files`/`file_revisions`/`chunk_defs` directly),
rather than returning `0` (bugs 2/3) or aggregating across all 3 projects in
the index.db (bugs 1/6).

## The 7 bugs and their status

| # | Bug | Status | Fix |
|---|-----|--------|-----|
| 1 | `project_meta` uses composite key `(project_id, key)` but the script did `SELECT key, value FROM project_meta` without a `project_id` filter, causing `dict()` collapse across projects | **Already handled** (working tree) | Query now `WHERE project_id=?` for the matched project; results built via `dict(rows)` keyed to one project |
| 2 | No `files` table — `scalar("SELECT COUNT(*) FROM files")` silently returns 0 | **Fixed** | Reads `project_files` (total) joined to `file_revisions` (`complete=1`) for done, scoped to `proj_pid` |
| 3 | No `chunks` table — `scalar("SELECT COUNT(*) FROM chunks")` silently returns 0 | **Fixed** | Reads `chunk_defs` joined to `file_revisions` + `project_files`, scoped to `proj_pid` |
| 4 | Wrong validity-table name derivation | **Fixed** | Prefix (`<vec>`) is now read from the `USING vec0` declaration in `sqlite_master`; falls back to deriving from the vector data-table name for schemas/specimens without a declared vec0 table. Validity bitmap = `<vec>_chunks` |
| 5 | `vec_dimensions` missing from `project_meta` | **Already handled** | Read via `meta.get(...)` with an `isdigit()` guard; skipped when absent |
| 6 | Multi-project `project_meta` dict collapse corrupts lookups | **Already handled** (same fix as #1) | `project_id`-filtered query + per-project `meta` |
| 7 | No `vec0` module in sqlite3 — shadow tables assumed unreadable without the extension | **Already handled** | The doctor already reads only regular shadow tables; the fix makes the vec0-table name resolution explicitly read `USING vec0` from `sqlite_master` rather than requiring the extension to be loadable |

## Additional prerequisite fixes (not schema-mismatch bugs, but required to run)

- `scalar(sql, default=0, params=())` → reordered to `scalar(sql, params=(), default=0)` so callers passing query params positionally actually bind them (was binding the param tuple to `default`, causing a `TypeError`/`default` misuse on every parametrised count).
- Added `struct, math` to the main embedded-Python import block. `struct.unpack` is used in the int8 per-vector path but `import struct` only existed inside the float `else` branch, so every int8 index died with `NameError: name 'struct' is not defined` before any verdict.

## Verification of the fix

- `bash -n scripts/lumen-index-doctor.sh` passes (syntax clean).
- The doctor exits `0` on the real vasic index (3 projects present; project 1 = vasic).
- Files/chunks are non-zero and match a direct `sqlite3` query against
  `project_files`/`file_revisions`/`chunk_defs` scoped to `project_id=1`.
- Validity bitmap read is confirmed: `freed/unwritten` slots reported (104087)
  proves `<vec>_chunks` is being decoded, not skipped.
- The index is opened read-only (`mode=ro`); no write to the real index.

## Notes

- The vasic `index.db` holds 3 projects (root `vasic` plus two `.claude/worktrees`
  agent checkouts). Exact `realpath` matching ensures only the vasic project's
  rows are counted; the worktrees are excluded.
- File/chunk counts fluctuate between runs because the live index is actively
  being reindexed by the workshop pipeline; each run reports a consistent
  project-scoped snapshot.

## Files changed

- `scripts/lumen-index-doctor.sh` (working tree; not yet committed)
