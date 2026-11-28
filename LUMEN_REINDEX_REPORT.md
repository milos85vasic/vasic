# Lumen Reindex Audit — vasic project

**Date:** 2026-11-27  
**Project:** /home/milosvasic/Projects/vasic  
**Branch:** pr/root-fixes-2026-11-27  
**Lumen binary:** /home/milosvasic/go/bin/lumen  
**Index path:** /home/milosvasic/.local/share/lumen/b75ce15456b7b206/index.db

---

## Step 1 — Confirm no lumen process running

Command: `pgrep -a lumen`

**Output:** (empty — no matches)

**Exit code:** 1

**Finding:** No lumen process is running. PID 3517736 was already killed and no new index process has started. Proceeding to index run.

---

## Step 2 — Run lumen index with 300-second timeout

Command: `timeout 300 /home/milosvasic/go/bin/lumen index /home/milosvasic/Projects/vasic --force`

**Output:**
```
INFO: Indexing /home/milosvasic/Projects/vasic (model: ordis/jina-embeddings-v2-base-code, dims: 768)
```

**Exit code:** 143 (128 + SIGTERM(15)) — killed by `timeout` at the 300-second (5-minute) boundary.

**Finding:** The full reindex did NOT complete within 300 seconds (a previous full reindex takes ~2 hours). Only the startup INFO line was emitted before the timeout terminated the process. This is expected per the task instructions. The index process was allowed to be terminated; no lumen process was left running after the `timeout` boundary.

---

## Step 3 — Timeout handling

As anticipated, the index run hit the 300-second timeout and produced only the single INFO line above. No partial progress summary was printed by lumen before termination. Per instructions, this is expected and not an error condition.

---

## Step 4 — Check index.db after (timeout of) indexing

Commands:
```
ls -la "/home/milosvasic/.local/share/lumen/b75ce15456b7b206/index.db"
sqlite3 "file:/home/milosvasic/.local/share/lumen/b75ce15456b7b206/index.db?mode=ro" "SELECT COUNT(*) FROM chunk_defs; SELECT COUNT(*) FROM vector_keys;"
```

**Output:**
```
644  /home/milosvasic/.local/share/lumen/b75ce15456b7b206/index.db  7393.8M
3260333
3241305
```

**Exit code:** 0

**Findings:**
- index.db exists at 7,393.8 MB (~7.4 GB)
- `chunk_defs` row count: **3,260,333**
- `vector_keys` row count: **3,241,305**

These counts indicate a substantial index was already present before/around this run; the 300-second timed-out run did not materially change them within the window (no delta could be measured because no "before" count was captured).

---

## Step 5 — Test lumen search

Command: `timeout 30 /home/milosvasic/go/bin/lumen search "git submodule" --cwd /home/milosvasic/Projects/vasic -p /home/milosvasic/Projects/vasic -n 5 --summary`

**Output:** (empty — no results printed within the window)

**Exit code:** 124 (124 = `timeout` killed the command at the 30-second boundary)

**Finding:** Lumen search did not return within 30 seconds and produced no output. The search process was terminated by `timeout`. Whether this is because the index is still being built / not fully ready, or because search is slow on this index, could not be determined from this run.

---

## Summary

| Step | Action | Result | Exit code |
|------|--------|--------|-----------|
| 1 | `pgrep -a lumen` | No process running | 1 (no matches) |
| 2 | `lumen index ... --force` | Timed out at 300s; only INFO line emitted | 143 (SIGTERM) |
| 3 | Timeout | Expected — full reindex needs ~2h | — |
| 4 | index.db inspection | 7,393.8 MB; chunk_defs=3,260,333; vector_keys=3,241,305 | 0 |
| 5 | `lumen search "git submodule"` | Timed out at 30s; no output | 124 (SIGTERM) |

**Conclusion:** The lumen index is present and large (~7.4 GB, >3.2M chunks/vectors), but the 300-second index run did not complete (timed out at 5 minutes as expected), and a subsequent search timed out at 30 seconds with no results. The index may need a full uninterrupted run (~2 hours) before search becomes responsive. No lumen process was left running after any step.
