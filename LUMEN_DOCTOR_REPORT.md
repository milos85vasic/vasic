# Lumen Index Doctor Report — vasic project

**Project:** `/home/milosvasic/Projects/vasic`
**Index store:** `/home/milosvasic/.local/share/lumen/`
**Doctor script:** `/home/milosvasic/Projects/vasic/scripts/lumen-index-doctor.sh`
**Date:** 2026-11-27

---

## 1. `lumen-index-doctor.sh <project-path>` — full output and exit code

**Command:** `timeout 300 bash /home/milosvasic/Projects/vasic/scripts/lumen-index-doctor.sh /home/milosvasic/Projects/vasic`

**Output:**
```
❌ no Lumen index found for /home/milosvasic/Projects/vasic under /home/milosvasic/.local/share/lumen
```

**Exit code:** `2` (could not inspect)

**Finding:** The doctor could not find a matching index for the vasic project, even though an index clearly exists at `/home/milosvasic/.local/share/lumen/b75ce15456b7b206/index.db` with `project_path = /home/milosvasic/Projects/vasic`. This is a **schema mismatch bug** in the script (see section 7 below): the script's `SELECT key, value FROM project_meta` without a `project_id` filter collapses duplicate keys across the 3 projects stored in that single database file, so `rows.get("project_path")` returns an unpredictable value rather than `/home/milosvasic/Projects/vasic`.

---

## 2. `lumen-index-doctor.sh <project-path> --prove-failure` — full output and exit code

**Command:** `timeout 300 bash /home/milosvasic/Projects/vasic/scripts/lumen-index-doctor.sh /home/milosvasic/Projects/vasic --prove-failure`

**Output:**
```
LUMEN-INDEX-DOCTOR §1.1 PAIRED MUTATION PROOF
----------------------------------------------------------------------
ℹ PRE-FLIGHT live-run            the real instrument RAN and returned rc=2 (could not inspect). REPORTED,
                                 NOT GATING — the battery below uses a synthetic control.
  sandbox: /home/milosvasic/.cache/claude-tmp/lumen-doctor-proof.L6us6s
✅ CONTROL synthetic-healthy      rc=0, and it named 'index healthy'
✅ M1 stale-duplicate-vectors     rc=1, and it named 'duplicate-vector group'
✅ M2 NaN-vector                  rc=1, and it named 'NaN/Inf'
✅ M3 all-zero-vector             rc=1, and it named 'all-zero'
✅ M4 off-norm-vector             rc=1, and it named 'off-norm'
✅ M5 ragged-block                rc=1, and it named 'ragged block'
✅ M5b int8-healthy               rc=0, and it named 'index healthy'
✅ M5c int8-stale-duplicates      rc=1, and it named 'duplicate-vector group'
✅ M5d int8-all-zero-vector       rc=1, and it named 'all-zero'
✅ M5e int8-off-scale-vector      rc=1, and it named 'off-scale'
✅ M5f int8-no-dominant-scale     rc=2, and it named 'not established'
✅ M5f2 never-healthy             and it never printed 'index healthy'
✅ M5g int8 0.5% off-scale        rc=1, and it named 'off-scale'
✅ M5h int8 10% off-scale         rc=1, and it named 'off-scale'
✅ M5i int8 11% off-scale         rc=2, and it named 'not established'
✅ M5i2 never-healthy             and it never printed 'index healthy'
✅ M5j int8 60% off-scale         rc=2, and it named 'not established'
✅ M5j2 never-healthy             and it never printed 'index healthy'
✅ M5k int8 uniform rescale       rc=2, and it named 'not established'
✅ M5k2 never-healthy             and it never printed 'index healthy'
✅ M5l int8 tiny population       rc=2, and it named 'not established'
✅ M5l2 never-healthy             and it never printed 'index healthy'
✅ M6 width-disagreement          rc=2, and it named 'disagrees with itself'
✅ M7 no-vector-table             rc=2, and it named 'no sqlite-vec vector table'
✅ M11a bad-INT8-DOMINANCE        rc=2, named LUMEN_INT8_SCALE_DOMINANCE, no clean bill
✅ M11b bad-INT8-TOP              rc=2, named LUMEN_INT8_SCALE_TOP, no clean bill
✅ M11c bad-INT8-MIN-VECTORS      rc=2, named LUMEN_INT8_MIN_VECTORS, no clean bill
✅ M11d bad-NORM-MIN (float32)    rc=2, named LUMEN_NORM_MIN, no clean bill
✅ M11e bad-NORM-MAX (float32)    rc=2, named LUMEN_NORM_MAX, no clean bill
✅ M8 bad-element-type (env)      rc=2, and it named the rejected element type
✅ M9 no-index-for-project        rc=2, and it named the missing index
✅ M10 required-backend-down      rc=2, and it refused to report healthy or corrupt
✅ CONTROL restored               rc=0, and it named 'index healthy'
----------------------------------------------------------------------
✅ LUMEN-INDEX-DOCTOR §1.1 MUTATION PROOF: PASS — the real entry point ran against
   the real store (reported, never gating), a synthetic control that is healthy by
   construction passed, and all 33 checks above held with the required
   three-valued verdict (the count is the live pass counter, not a literal):
   real corruptions as rc=1 — including the well-formed duplicate-vector fault
   every conventional per-vector test passes, on float32 AND int8 storage —
   could-not-inspect states as rc=2 rather than a clean bill of health, and
   healthy specimens as rc=0.
```

**Exit code:** `0` (all 33 mutation-proof checks passed)

**Finding:** The paired-mutation proof passes completely. The pre-flight live run against the real vasic store returned rc=2 (could not inspect — consistent with the schema mismatch), and this was correctly reported but did not gate the battery. All synthetic control and mutation cases produced the expected three-valued verdicts.

---

## 3. `lumen-index-doctor.sh --help` — full output

**Command:** `bash /home/milosvasic/Projects/vasic/scripts/lumen-index-doctor.sh --help`

**Output:**
```
------------------------------------------------------------------------------
Lumen index doctor — detect SILENTLY corrupt embeddings.

WHY THIS EXISTS
---------------
A GPU fault wrote 758 identical vectors covering 695 distinct texts across 55
files into this project's index. Every conventional check passed: no NaN, no
Inf, no all-zero, L2 norm 1.000000083, correct dimensionality. A full forensic
audit declared the index "TRUSTWORTHY" on exactly those measurements — and was
wrong, because a stale-but-well-formed vector is invisible per-vector.

The only thing that exposes it is AGGREGATE distinctness: N distinct texts
must produce N distinct vectors. This script checks that, alongside the
conventional per-vector tests, and never opens the DB for writing.

  ./scripts/lumen-index-doctor.sh [project-path] [--require-live-backend]

Exit 0 = healthy · 1 = corruption found · 2 = could not inspect

NOTHING BELOW IS ASSUMED ABOUT THE HOST. Every value is derived, and every
derivation has an env override for when detection is wrong:

  LUMEN_STORE          index store dir   (default $XDG_DATA_HOME/lumen,
                                          XDG_DATA_HOME defaulting to
                                          $HOME/.local/share — this is what
                                          lumen's own config.XDGDataDir() does,
                                          on macOS too)
  LUMEN_INDEX_DB       pin one index.db and skip the store scan entirely
  LUMEN_VEC_TABLE      pin the sqlite-vec vector shadow table
  LUMEN_VEC_DIMS       pin the vector width (floats per vector)
  LUMEN_VEC_ELEM       pin the element type: float32 | int8
  LUMEN_EMBED_MODEL    pin the model lumen would use now
  LUMEN_BACKEND        ollama | lmstudio
  OLLAMA_HOST          ollama base URL   (scheme optional: host:port is fine)
  LM_STUDIO_HOST       LM Studio base URL
  LUMEN_CONFIG         lumen config.yaml (default $XDG_CONFIG_HOME/lumen/config.yaml)
  LUMEN_DUP_THRESHOLD  identical-group size that means corruption (default 10)
  LUMEN_NORM_MIN/MAX   accepted L2 norm band (default 0.99 / 1.01). float32
                       indexes ONLY: int8 vectors are stored scaled to their own
                       maximum, so their raw L2 norm is 428..1312 on the real
                       store and no unit-norm band can apply (see INT8 below).
  LUMEN_INT8_SCALE_DOMINANCE  share of distinct live vectors that must sit on
                       ONE max|component| for the int8 scale check to apply
                       (default 0.90)
  LUMEN_INT8_SCALE_TOP the int8 saturation value that scale must equal
                       (default 127; max-abs quantisation puts the largest
                       component AT it). A legitimate int8 store that is NOT
                       quantised max-abs (different scheme or scale) will read
                       rc 2 "scale invariant not established" until this is
                       set to that store's own top; the doctor cannot guess it.
  A set-but-non-numeric value of ANY numeric LUMEN_* tuning variable is rc 2
  naming the variable; it is never silently replaced by the default.
  LUMEN_INT8_MIN_VECTORS  fewest distinct live vectors that can state a scale
                       (default 10)
  LUMEN_DOCTOR_PREFLIGHT_TIMEOUT  seconds --prove-failure allows its live
                       pre-flight run against the real store (default 900; the
                       real run took 157 s on a 1.25M-vector store). 0 DISABLES
                       the timeout, i.e. the run is UNBOUNDED. Applies to
                       --prove-failure only.
  LUMEN_PROBE_TIMEOUT  seconds for backend probes (default 5)

INT8 STORAGE — WHAT IS CHECKED, AND THE RECALL COST (measured on specimens of
1000 vectors, 2026-09-24). The scale invariant is derived from the data and
then held to a fixed anchor: it is ESTABLISHED only if (1) at least
LUMEN_INT8_MIN_VECTORS distinct live vectors exist, (2) one max|component|
covers >= LUMEN_INT8_SCALE_DOMINANCE of them, and (3) that value is
LUMEN_INT8_SCALE_TOP. Established: vectors on any other scale are "off-scale"
and are corruption (rc 1). NOT established: rc 2, COULD NOT DETERMINE — the
same principle as the width / no-vector-table cases, never a clean bill.

    off-scale share of vectors      verdict
    0.5%                            DETECTED   rc 1
    exactly 10%                     DETECTED   rc 1
    11%                             not established   rc 2
    60%                             not established   rc 2
    100% (all rescaled together)    not established   rc 2 (mode != top)
    N < 10 distinct live vectors    not established   rc 2

So above 10% the doctor cannot say WHICH side is right and says so, rather than
reading a broken index as healthy. Duplicate, all-zero and ragged-block checks
run regardless. Corruption (1) outranks could-not-determine (2).

THE VECTOR WIDTH IS NEVER A LITERAL. It is taken from the vec0 virtual-table
declaration (`embedding float[768]`), cross-checked against the block bytes on
disk and against project_meta.vec_dimensions. A wrong width silently misreads
EVERY vector, so when the sources disagree and no override is given the doctor
reports "could not inspect" rather than guessing.

THE BACKEND IS OPTIONAL BY DEFAULT. Inspecting a database does not require a
running ollama, so an unreachable backend degrades the model-mismatch NOTE and
leaves the corruption verdict untouched. Pass --require-live-backend (or set
LUMEN_DOCTOR_REQUIRE_BACKEND=1) to make an unreachable backend "could not
inspect" (exit 2) instead.
```

**Exit code:** `0`

---

## 4. `sqlite3` availability

**Command:** `command -v sqlite3` and `sqlite3 --version`

**Output:**
```
/home/milosvasic/Android/Sdk/platform-tools/sqlite3
3.50.6 2025-09-22 18:50:24 9cc554372371e07bf01d8070a64d461ac85b91be6eef0e642ed129a0c7fa8105 (64-bit)
```

**Exit code:** `0`

**Finding:** `sqlite3` is available (Android platform-tools build, v3.50.6). **Important:** this build does NOT have the `vec0` virtual-table module compiled in — `SELECT ... FROM vec_vectors` returns `no such module: vec0`. The shadow tables (`vec_vectors_vector_chunks00`, `vec_vectors_chunks`, etc.) are ordinary tables and are readable without the extension.

---

## 5. vasic index.db schema

**Index.db path:** `/home/milosvasic/.local/share/lumen/b75ce15456b7b206/index.db`

This database contains **3 projects** (not just vasic):

| id | path | created_at | last_accessed_at |
|----|------|------------|------------------|
| 1 | /home/milosvasic/Projects/vasic | 2026-09-05T13:41:37Z | 2026-11-27T22:45:15Z |
| 3 | /home/milosvasic/Projects/vasic/.claude/worktrees/agent-a3add1f4608f0694d | 2026-10-27T19:01:32Z | 2026-10-27T19:01:34Z |
| 5 | /home/milosvasic/Projects/vasic/.claude/worktrees/agent-a91158766c4f8dbce | 2026-10-27T22:37:18Z | 2026-10-27T22:37:22Z |

**Full schema (`.schema`):**

```sql
CREATE TABLE collection_meta (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
);
CREATE TABLE projects (
    id INTEGER PRIMARY KEY,
    path TEXT NOT NULL UNIQUE,
    created_at TEXT NOT NULL,
    last_accessed_at TEXT NOT NULL
);
CREATE TABLE project_meta (
    project_id INTEGER NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    key TEXT NOT NULL,
    value TEXT NOT NULL,
    PRIMARY KEY(project_id, key)
) WITHOUT ROWID;
CREATE TABLE file_revisions (
    id INTEGER PRIMARY KEY,
    relative_path TEXT NOT NULL,
    content_hash BLOB NOT NULL,
    complete INTEGER NOT NULL DEFAULT 0,
    UNIQUE(relative_path, content_hash)
);
CREATE TABLE project_files (
    project_id INTEGER NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    relative_path TEXT NOT NULL,
    file_revision_id INTEGER NOT NULL REFERENCES file_revisions(id),
    PRIMARY KEY(project_id, relative_path)
) WITHOUT ROWID;
CREATE INDEX idx_project_files_revision ON project_files(file_revision_id);
CREATE TABLE vector_keys (
    id INTEGER PRIMARY KEY,
    input_hash BLOB NOT NULL UNIQUE
);
CREATE TABLE chunk_defs (
    id INTEGER PRIMARY KEY,
    file_revision_id INTEGER NOT NULL REFERENCES file_revisions(id) ON DELETE CASCADE,
    ordinal INTEGER NOT NULL,
    chunk_key TEXT NOT NULL,
    vector_id INTEGER NOT NULL REFERENCES vector_keys(id),
    symbol TEXT NOT NULL,
    kind TEXT NOT NULL,
    start_line INTEGER NOT NULL,
    end_line INTEGER NOT NULL,
    UNIQUE(file_revision_id, ordinal)
);
CREATE INDEX idx_chunk_defs_revision ON chunk_defs(file_revision_id);
CREATE INDEX idx_chunk_defs_vector ON chunk_defs(vector_id);
CREATE VIRTUAL TABLE vec_vectors USING vec0(
    vector_id INTEGER PRIMARY KEY,
    embedding int8[768] distance_metric=cosine
);
CREATE TABLE IF NOT EXISTS "vec_vectors_info" (key text primary key, value any);
CREATE TABLE IF NOT EXISTS "vec_vectors_chunks"(chunk_id INTEGER PRIMARY KEY AUTOINCREMENT,size INTEGER NOT NULL,validity BLOB NOT NULL,rowids BLOB NOT NULL);
CREATE TABLE sqlite_sequence(name,seq);
CREATE TABLE IF NOT EXISTS "vec_vectors_rowids"(rowid INTEGER PRIMARY KEY AUTOINCREMENT,id,chunk_id INTEGER,chunk_offset INTEGER);
CREATE TABLE IF NOT EXISTS "vec_vectors_vector_chunks00"(rowid PRIMARY KEY,vectors BLOB NOT NULL);
CREATE TABLE sqlite_stat1(tbl,idx,stat);
```

**`project_meta` contents for project_id 1 (vasic root):**

| project_id | key | value |
|------------|-----|-------|
| 1 | embedding_model | ordis/jina-embeddings-v2-base-code |
| 1 | last_index_error | (empty) |
| 1 | last_indexed_at | 2026-11-27T16:08:09Z |
| 1 | project_path | /home/milosvasic/Projects/vasic |
| 1 | root_hash | 6d6cc1e4f7e3071ff691a56e13251c2f5bd39bee9e5c00ec0eb77d8399e5e661 |
| 1 | total_files | 180551 |
| 1 | vector_storage | int8 |

**Table names:** `collection_meta`, `projects`, `project_meta`, `file_revisions`, `project_files`, `vector_keys`, `chunk_defs`, `vec_vectors`, `vec_vectors_info`, `vec_vectors_chunks`, `vec_vectors_rowids`, `vec_vectors_vector_chunks00`, `sqlite_sequence`, `sqlite_stat1`

**vec0 declaration:** `CREATE VIRTUAL TABLE vec_vectors USING vec0(vector_id INTEGER PRIMARY KEY, embedding int8[768] distance_metric=cosine)` — width 768, element type `int8`.

---

## 6. Total vector count

**Command attempted:** `sqlite3 <path>/index.db "SELECT COUNT(*) FROM chunks;"`

**Result:** **ERROR — no such table: `chunks`**

The vasic index.db schema has **no `chunks` table**. The closest equivalents are:

| Query | Result |
|-------|--------|
| `SELECT COUNT(*) FROM chunk_defs;` | **3,260,333** |
| `SELECT COUNT(*) FROM vector_keys;` | **3,241,305** |
| `SELECT COUNT(*) FROM vec_vectors_vector_chunks00;` | **3,280** (packed vector blocks) |
| `SELECT COUNT(*) FROM vec_vectors_chunks;` | **3,280** (validity/chunk metadata blocks) |
| `SELECT COUNT(*) FROM vec_vectors;` | ERROR — `no such module: vec0` (the vec0 extension is not loaded in this sqlite3 build) |

**Interpretation:** There are approximately **3.24 million distinct vectors** (vector_keys) and **3.26 million chunk definitions** (chunk_defs), packed into **3,280 blocks** of 1024 vectors each in the sqlite-vec shadow tables. The `vec0` virtual table itself cannot be queried directly because the installed sqlite3 lacks the vec0 extension.

---

## 7. Potential issues and bugs in lumen-index-doctor.sh

The script was read in full. Several significant issues were found, all stemming from a **schema mismatch between the script's assumptions and the actual vasic index.db schema**:

### Bug 1: `project_meta` composite key causes missed project match (PRIMARY — explains exit 2 on the real run)

**The script assumes:**
```sql
CREATE TABLE project_meta(key TEXT PRIMARY KEY, value TEXT)
```
and queries `SELECT key, value FROM project_meta` with no WHERE clause, then does `rows.get("project_path")` and compares `os.path.realpath(p) == proj`.

**The actual schema:**
```sql
CREATE TABLE project_meta (
    project_id INTEGER NOT NULL REFERENCES projects(id),
    key TEXT NOT NULL,
    value TEXT NOT NULL,
    PRIMARY KEY(project_id, key)
) WITHOUT ROWID
```

Three projects share one `project_meta` table. `SELECT key, value FROM project_meta` returns duplicate keys (e.g. `project_path` appears 3 times with different values). Python's `dict()` collapses duplicates, keeping only the last value in iteration order — which is unpredictable and is **not** `/home/milosvasic/Projects/vasic`. Result: `matches` is empty, the script prints "no Lumen index found" and exits rc=2.

**Fix:** Query with `WHERE project_id = (SELECT id FROM projects WHERE path = ?)` or iterate rows and match each project_path individually.

### Bug 2: Missing `files` table silently returns 0

The script calls `scalar("SELECT COUNT(*) FROM files")` and `scalar("SELECT COUNT(*) FROM files WHERE hash<>''")`. There is no `files` table (the actual equivalent is `project_files` + `file_revisions`). The `scalar()` helper catches the exception and returns default 0, so the report silently prints `files: 0 fully indexed, 0 queued placeholders` instead of real counts or an error.

### Bug 3: Missing `chunks` table silently returns 0

The script calls `scalar("SELECT COUNT(*) FROM chunks")`. There is no `chunks` table (the actual equivalents are `vector_keys` and `chunk_defs`). Again silently returns 0: `chunks: 0`.

### Bug 4: Wrong validity-table name derivation

The script derives `validity_table = prefix + "_chunks"` where `prefix` comes from stripping `_vector_chunks\d+$` from the vec table name. With `vec_table = vec_vectors_vector_chunks00`, `prefix = vec_vectors_vector`, so `validity_table = vec_vectors_vector_chunks`. The actual table is `vec_vectors_chunks`. The query fails (caught by `except Exception: pass`), so `validity` stays empty `{}`, all slots are treated as live, and freed/unwritten slots are never excluded — potentially counting stale vectors as data.

### Bug 5: `vec_dimensions` missing from `project_meta`

The script reads `meta.get("vec_dimensions")` as one of three width sources. In the vasic database, `vec_dimensions` is **not present** in `project_meta` at all. The width is still correctly derived from the vec0 declaration (`embedding int8[768]`), so this is degraded but not fatal here.

### Bug 6: `dict()` on multi-project `project_meta` corrupts all metadata lookups

Because all 3 projects share one `project_meta` table, `dict(c.execute("SELECT key, value FROM project_meta").fetchall())` collapses not just `project_path` but also `embedding_model`, `last_indexed_at`, `total_files`, `vector_storage`, etc. The `meta` dict passed downstream contains values from an arbitrary project, not necessarily vasic. This affects model-mismatch detection and width derivation from `vec_dimensions`.

### Bug 7: No `vec0` module in the available sqlite3

The `sqlite3` binary at `/home/milosvasic/Android/Sdk/platform-tools/sqlite3` (v3.50.6) does not have the `vec0` virtual-table module compiled in. `SELECT ... FROM vec_vectors` fails with `no such module: vec0`. The script works around this by reading shadow tables directly, but any future code path that queries `vec_vectors` itself would fail.

---

## Summary

| Step | Result |
|------|--------|
| 1. Doctor on vasic | Exit 2 — "no Lumen index found" (false negative due to Bug 1) |
| 2. Doctor --prove-failure | Exit 0 — all 33 mutation-proof checks passed |
| 3. Doctor --help | Exit 0 — full help printed |
| 4. sqlite3 available | Yes, v3.50.6 (no vec0 module) |
| 5. vasic index.db found | `/home/milosvasic/.local/share/lumen/b75ce15456b7b206/index.db`, int8[768], 3 projects |
| 6. `SELECT COUNT(*) FROM chunks;` | ERROR — no `chunks` table; ~3.24M vectors via `vector_keys` / `chunk_defs` |
| 7. Script bugs | 7 bugs identified, all schema-mismatch related |

The doctor's mutation-proof machinery is sound, but it cannot correctly inspect the vasic index in its current schema form. The schema has evolved (multi-project `project_meta`, no `files`/`chunks` tables, composite keys) while the script's SQL queries and table-name derivations have not been updated to match.
