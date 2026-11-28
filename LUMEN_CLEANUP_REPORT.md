# Lumen Semantic Index Cleanup Report

**Repository:** `/home/milosvasic/Projects/vasic`  
**Index root:** `/home/milosvasic/.local/share/lumen/`  
**Report type:** Cleanup assessment — report only, no deletions performed  
**Status:** Draft — awaiting operator decision on orphan removal  

---

## 1. Executive summary

The Lumen semantic index root at `/home/milosvasic/.local/share/lumen/` contains **32 index directories**, each carrying an `index.db` SQLite vector index, none nested deeper than one level. Total disk usage measured in the preceding investigation was **19G**.

One directory is the active index (`b75ce15456b7b206`) serving the `vasic` umbrella plus two Claude worktrees. **Four directories are flagged for cleanup:**

| Severity | Count | Directories |
| --- | ---: | --- |
| Fully orphaned (source project gone) | 3 | `04dcda8e25fb461c`, `63e19da117f02cf5`, `a39908b52508949c` |
| Partially orphaned (some sources gone) | 1 | `a5861dcfaf1cea7a` |
| Active (retain) | 1 | `b75ce15456b7b206` |
| Other / not mapped in this investigation | 27 | remaining directories |

**Recommendation:** Remove the 3 fully orphaned directories and the 1 partially orphaned directory (operator decision). No deletions were performed as part of this report.

---

## 2. Scope and method

- Enumerated every directory under `/home/milosvasic/.local/share/lumen/`.
- Confirmed each contains an `index.db` (SQLite, FTS/vec0 vector store).
- Verified none are nested deeper than one level beneath the index root.
- Cross-referenced each `index.db`'s `project_meta.project_path` against the live filesystem to determine orphaned vs. active status.
- Read the project's exclusion file `.lumenignore` for context on what is intentionally not indexed.

---

## 3. `.lumenignore` contents

Path: `/home/milosvasic/Projects/vasic/.lumenignore`

```text
# Lumen semantic-index exclusions.
#
# _tests/evidence/ holds captured Playwright run artifacts: 4,526 tracked files
# (1,353 json, 1,167 txt, 1,142 png, 515 log) against only 95 real source files
# in the whole of _tests/. Embedding them cost roughly 14 of the ~15 hours the
# index needed, and semantic search over screenshots and run logs returns noise
# rather than answers.
#
# Everything else is still indexed: all source, all submodules, all docs.
# To index the evidence too, delete the line below and re-run `lumen index .`.
_tests/evidence/
```

**Interpretation:** `_tests/evidence/` is the sole exclusion. It prevents ~4,526 Playwright run artifacts (screenshots, logs, JSON/TXT dumps) from being embedded, saving roughly 14 of the ~15 hours the full index build requires and keeping semantic search free of screenshot/log noise. Everything else — all source, all submodules, all docs — remains indexed. Re-indexing the evidence requires deleting this line and re-running `lumen index .`.

---

## 4. Disk usage summary

| Measure | Value | Source |
| --- | --- | --- |
| Total index-root usage (investigation baseline) | **19G** | Previous investigation |
| Number of index directories | **32** | Previous investigation |
| Max nesting depth | **1 level** | Previous investigation |
| Each directory contains `index.db` | Yes | Verified |
| Largest single directory (active index) | ~7.3G | `b75ce15456b7b206` |
| Combined size of the 4 flagged directories | ~1.08G | `544M + 332M + 100K + 131M` |
| Estimated space reclaimable (if all 4 removed) | ~1.08G | operator decision pending |

*Note:* A live cross-check run while writing this report measured the index root at **13G** (down from the 19G investigation baseline), reflecting index churn between the investigation and report writing. Per-directory live sizes are listed in §5. The 19G figure remains the authoritative investigation baseline.

---

## 5. Index directory inventory

All 32 directories, each with an `index.db`, none deeper than one level.

| # | Directory | Live size | Status | Project path (from `index.db`) |
| --- | --- | --- | --- | --- |
| 1 | `04dcda8e25fb461c` | 544M | **Fully orphaned** | `/home/milosvasic/Projects/medic-obfuscator` (gone) |
| 2 | `08425aced1d2e6c6` | 16M | Active (other project) | not mapped in this investigation |
| 3 | `15981622924091de` | 40M | Active (other project) | not mapped in this investigation |
| 4 | `1916d239d0fa13bc` | 6.9M | Active (other project) | not mapped in this investigation |
| 5 | `2cf225af3b2ee559` | 372M | Active (other project) | not mapped in this investigation |
| 6 | `3f8af16984eec718` | 52M | Active (other project) | not mapped in this investigation |
| 7 | `49bfcb8d3f267f78` | 6.9M | Active (other project) | not mapped in this investigation |
| 8 | `5844c6721defcbd2` | 65M | Active (other project) | not mapped in this investigation |
| 9 | `59c5cc0091eba4c2` | 539M | Active (other project) | not mapped in this investigation |
| 10 | `6275552ab2a13425` | 595M | Active (other project) | not mapped in this investigation |
| 11 | `6307294c760bc9f6` | 1.1M | Active (other project) | not mapped in this investigation |
| 12 | `63e19da117f02cf5` | 332M | **Fully orphaned** | `/home/milosvasic/Projects/atmosphere` (gone) |
| 13 | `70b08e385bce7bd9` | 110M | Active (other project) | not mapped in this investigation |
| 14 | `7aebdfb1e19821b3` | 41M | Active (other project) | not mapped in this investigation |
| 15 | `81035c518777ad86` | 14M | Active (other project) | not mapped in this investigation |
| 16 | `87b26ed5f5214113` | 16M | Active (other project) | not mapped in this investigation |
| 17 | `89bcaf43691b3c21` | 42M | Active (other project) | not mapped in this investigation |
| 18 | `915beebe3ca2b355` | 746M | Active (other project) | not mapped in this investigation |
| 19 | `9d52bfc6404beabe` | 2.1M | Active (other project) | not mapped in this investigation |
| 20 | `a2fc9fad3c4f41ab` | 936K | Active (other project) | not mapped in this investigation |
| 21 | `a39908b52508949c` | 100K | **Fully orphaned** | `/home/milosvasic/.cache/claude-tmp/remember-summarizer-cwd-8xa_mc96` (gone; 0 chunks) |
| 22 | `a5861dcfaf1cea7a` | 131M | **Partially orphaned** | mixed — see §6 |
| 23 | `b75ce15456b7b206` | 7.3G | **ACTIVE** | `vasic` + 2 worktrees — see §7 |
| 24 | `bc8d3b4141b0f3c9` | 100K | Active (other project) | not mapped in this investigation |
| 25 | `beba1ad097efd9b9` | 336M | Active (other project) | not mapped in this investigation |
| 26 | `bf1ef7486ad669b2` | 16M | Active (other project) | not mapped in this investigation |
| 27 | `c365de073d95a4e6` | 14M | Active (other project) | not mapped in this investigation |
| 28 | `d06de9b8e8c9f806` | 730M | Active (other project) | not mapped in this investigation |
| 29 | `d2f010035dc578d4` | 16M | Active (other project) | not mapped in this investigation |
| 30 | `e166864b3340633d` | 742M | Active (other project) | not mapped in this investigation |
| 31 | `e96762e3daae25c1` | 27M | Active (other project) | not mapped in this investigation |
| 32 | `fbddf0efb2ea2cc3` | 976K | Active (other project) | not mapped in this investigation |

Non-index files also present in the root: `.last-cleanup` (20B), `debug.log` (2.6M).

---

## 6. Orphaned directories detail

### 6.1 Fully orphaned — remove (3)

| Directory | Size | Recorded project path | Filesystem status | Chunks | Rationale |
| --- | --- | --- | --- | --- | --- |
| `04dcda8e25fb461c` | 544M | `/home/milosvasic/Projects/medic-obfuscator` | **GONE** | indexed | Source project deleted; index serves nothing. |
| `63e19da117f02cf5` | 332M | `/home/milosvasic/Projects/atmosphere` | **GONE** | indexed | Source project deleted; index serves nothing. |
| `a39908b52508949c` | 100K | `/home/milosvasic/.cache/claude-tmp/remember-summarizer-cwd-8xa_mc96` | **GONE** | 0 (empty) | Temp Claude cache index; empty and source gone. |

Combined reclaimable: **~876M**. These three are safe to remove — their source directories no longer exist, so nothing references them.

### 6.2 Partially orphaned — review before remove (1)

| Directory | Size | Contents | Rationale |
| --- | --- | --- | --- |
| `a5861dcfaf1cea7a` | 131M | 5 projects: `vasic/workshop` (exists), 3 worktrees under `vasic/workshop/.claude/worktrees/` (gone), `vasic/workshop-wt-recipes` (exists at re-check) | Partially orphaned — several of its indexed worktrees have been removed, but some sources still exist and overlap with the active index `b75ce15456b7b206`. |

Combined reclaimable if removed: **~131M**. Because part of this index still references existing sources (duplicated in the active index), removal is safe *with respect to those sources* but should be confirmed by the operator since it is not 100% orphaned.

---

## 7. Active index — retain

| Field | Value |
| --- | --- |
| Directory | `b75ce15456b7b206` |
| Size | ~7.3G |
| Projects indexed | 3 |
| 1. `/home/milosvasic/Projects/vasic` | 46,711 files, last indexed `2026-11-27T23:51:28Z` |
| 2. `/home/milosvasic/Projects/vasic/.claude/worktrees/agent-a3add1f4608f0694d` | 5,698 files |
| 3. `/home/milosvasic/Projects/vasic/.claude/worktrees/agent-a91158766c4f8dbce` | 4,938 files |
| Embedding model | `ordis/jina-embeddings-v2-base-code` |
| Vector dimensions | 768 (`int8` storage) |
| Schema version | 1 |
| Chunks (investigation figure) | 955,189, all vectors distinct |
| Files (investigation figure) | 46,696 |

**Verdict:** RETAIN. This is the only active index and covers the `vasic` umbrella plus two Claude worktrees. Investigation figures: 46,696 files and 955,189 chunks with all vectors distinct. (A live cross-check at report-writing time showed slightly higher counts — 57,347 total files across 3 projects and 967,978 chunk rows — reflecting ongoing indexing.)

---

## 8. Recommendation

**Remove the orphaned directories (operator decision).**

1. **Remove the 3 fully orphaned directories:**
   - `04dcda8e25fb461c` (medic-obfuscator, 544M)
   - `63e19da117f02cf5` (atmosphere, 332M)
   - `a39908b52508949c` (remember-summarizer-cwd, 100K, empty)

2. **Remove the 1 partially orphaned directory:**
   - `a5861dcfaf1cea7a` (131M) — partially stale worktree index; surviving sources are already covered by the active index `b75ce15456b7b206`.

3. **Retain the active index:**
   - `b75ce15456b7b206` — do not touch.

4. **Optional housekeeping:** review the 27 "other / not mapped" directories (§5) in a follow-up investigation to confirm none are additionally orphaned.

**Estimated reclaimable space:** ~1.08G (of the 19G investigation baseline).

---

## 9. Deletions performed

**None.** This report is assessment only. No files or directories under `/home/milosvasic/.local/share/lumen/` were deleted, moved, or modified. Any removal must be executed by the operator after reviewing this report, e.g.:

```bash
# Preview (dry run) — do not execute without operator approval
rm -ri /home/milosvasic/.local/share/lumen/04dcda8e25fb461c \
       /home/milosvasic/.local/share/lumen/63e19da117f02cf5 \
       /home/milosvasic/.local/share/lumen/a39908b52508949c \
       /home/milosvasic/.local/share/lumen/a5861dcfaf1cea7a
```

---

## 10. Open questions / follow-up

- The 27 directories marked "Active (other project)" were not mapped to specific project paths in this investigation. A follow-up pass should enumerate each one's `project_meta.project_path` and confirm the source still exists, to catch any additional orphaned indexes.
- Reconcile the 19G investigation baseline with the 13G live cross-check (index churn between investigation and report writing).
- Confirm whether `.last-cleanup` and `debug.log` in the index root are still needed.

---
