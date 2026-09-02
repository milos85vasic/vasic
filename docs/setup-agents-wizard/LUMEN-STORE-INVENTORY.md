# Lumen Index Store — Read-Only Inventory

**Host:** this machine (`nezha`)  
**Store:** `~/.local/share/lumen/`  
**Generated:** 2026-08-27 20:34  
**Mode:** READ-ONLY. No index was deleted, no DB was opened read-write, `lumen purge` was never invoked, `lumen index` was never invoked.

---

## 0. STOP — four indexers are writing RIGHT NOW

The brief warned about one active rebuild. There are in fact **four concurrent `lumen index` processes** holding
open write handles on the store. All four index directories must be excluded from any purge.

| Index dir | PID | Project being indexed | Size | Note |
|---|---|---|---|---|
| `74e360aac96f417e` | 1693992 | `/run/media/milosvasic/DATA4TB/Projects/boba` | 681.9 MB | index |
| `21bf1507a8925bcf` | 840272 | `/run/media/milosvasic/DATA4TB/Projects/vasic` | 347.9 MB | index -f (THE named active rebuild) |
| `feaae19c7a38712e` | 1692994 | `/run/media/milosvasic/DATA4TB/Projects/lava` | 270.4 MB | index |
| `06dd1f85fde5febb` | 1789297 | `/run/media/milosvasic/DATA4TB/Projects/boba/constitution` | 15.1 MB | index (no project_path written yet) |

- **`21bf1507a8925bcf` is the index for `/run/media/milosvasic/DATA4TB/Projects/vasic`** — the rebuild the operator
  flagged. It is 347.9 MB with an 82 MB write-ahead log open by PID 840272. **It must never be purged.**
- **`06dd1f85fde5febb` is a trap.** A naive inventory classifies it as an orphan, because it has *no* `project_path`
  in `project_meta`. It is not an orphan — it is a *brand-new index in flight* for
  `/run/media/milosvasic/DATA4TB/Projects/boba/constitution` (PID 1789297). Lumen writes `project_path` only when
  indexing **completes**, so an in-progress index is indistinguishable from a crashed one by DB contents alone.
  It is the 7th-largest directory in the store. Verified by reading `/proc/1789297/fd`.

> Practical consequence: **do not purge anything while these four processes are alive.** Re-check with
> `ps -ef | grep 'lumen.*index'` immediately before acting, and re-derive the in-flight set — a different set of
> indexers may be running by then.

---

## 1. Totals

| Metric | Value |
|---|---|
| Entries under `~/.local/share/lumen/` | 765 — **764** index directories + `debug.log` |
| Index directories | **764** |
| Total size on disk | **2.55 GB** (2608.4 MB, 2735061888 bytes) |
| Distinct `project_path` values recorded | 537 |
| Duplicate `project_path` (2+ dirs, same project) | **0** |
| Embedding models in use | 1 — `ordis/jina-embeddings-v2-base-code` |
| `vec_dimensions` values in use | 1 — `768` |
| Non-index file | `debug.log`, 6.9 MB, appended to by all 4 running indexers |

### Breakdown by classification

| Class | Count | Size | % of store | Meaning |
|---|---:|---:|---:|---|
| ACTIVE-REBUILD | 2 | 362.9 MB | 13.9% | **Being written right now — never purge** |
| LIVE | 10 | 1288.7 MB | 49.4% | `project_path` exists, current model, not in flight |
| DEAD | 525 | 934.7 MB | 35.8% | `project_path` no longer exists on disk |
| WRONG-MODEL | 0 | 0.0 MB | 0.0% | `project_path` exists but model differs from default |
| INCOMPLETE | 227 | 22.1 MB | 0.8% | DB opens, but no `project_path`/`embedding_model` recorded |
| **TOTAL** | **764** | **2608.4 MB** | 100% | |

**There are zero WRONG-MODEL indexes.** Every index that records an `embedding_model` records
`ordis/jina-embeddings-v2-base-code`, and every index records `vec_dimensions = 768`. The "past embedding-model
switch" hypothesis in the brief is **not supported by the data** — there is no evidence of a model switch in this store.

---

## 2. Reclaimable space, split by confidence

| Tier | Class | Count | Size | Confidence |
|---|---|---:|---:|---|
| **1** | DEAD — ephemeral `/tmp` scratch dirs | 524 | **934.6 MB** | Definitely deleted |
| **2** | DEAD — real project path | 1 | 0.1 MB | Definitely deleted |
| **3** | INCOMPLETE — aborted index runs | 227 | 22.1 MB | Safe, but not purgeable by path |
| | **Total reclaimable** | **752** | **956.8 MB (0.93 GB)** | |
| | *Possibly unmounted (do not touch)* | **0** | **0.0 MB** | n/a — see §4 |
| | WRONG-MODEL | 0 | 0.0 MB | none exist |

Reclaiming everything in tiers 1-3 takes the store from **2.55 GB to 1.61 GB** (a 37% reduction), leaving the 10 LIVE
indexes untouched — including the two (`boba`, `lava`) that are themselves being written right now, and both
ACTIVE-REBUILD entries. All four in-flight index directories from §0 are excluded from every command in §7.

> **Perspective on the payoff.** 752 of the 764 directories (98%) are garbage, but they are only 957 MB of a
> 2.55 GB store. The store is big because of **five real projects**, not because of orphans. `boba` alone (681.9 MB)
> is larger than every DEAD and INCOMPLETE index combined. If the goal is disk space rather than tidiness, the
> orphans are the smaller half of the problem.

---

## 3. The 20 largest indexes

| # | Index dir | Class | Size | Files | Chunks | DB mtime | Project |
|---:|---|---|---:|---:|---:|---|---|
| 1 | `74e360aac96f417e` | LIVE ⚠️**IN FLIGHT** | 681.9 MB | 14825 | 201252 | 2026-08-27 20:02 | `/run/media/milosvasic/DATA4TB/Projects/boba` |
| 2 | `21bf1507a8925bcf` | ACTIVE-REBUILD ⚠️**IN FLIGHT** | 347.9 MB | 2111 | 52516 | 2026-08-27 20:06 | `/run/media/milosvasic/DATA4TB/Projects/vasic` |
| 3 | `feaae19c7a38712e` | LIVE ⚠️**IN FLIGHT** | 270.4 MB | 7920 | 77163 | 2026-08-27 20:28 | `/run/media/milosvasic/DATA4TB/Projects/lava` |
| 4 | `e7758398337f6aa7` | LIVE | 139.5 MB | 282 | 2038 | 2026-07-27 00:24 | `/tmp/.private/milosvasic` |
| 5 | `0e540668e98c02ce` | LIVE | 125.2 MB | 2247 | 37348 | 2026-07-26 21:21 | `/run/media/milosvasic/DATA4TB/Projects/claude_toolkit` |
| 6 | `40b9531ba54c9f4f` | LIVE | 45.7 MB | 1000 | 13255 | 2026-08-26 21:10 | `/run/media/milosvasic/DATA4TB/Projects/tmux` |
| 7 | `06dd1f85fde5febb` | ACTIVE-REBUILD ⚠️**IN FLIGHT** | 15.1 MB | 7 | 1503 | 2026-08-27 20:05 | `/run/media/milosvasic/DATA4TB/Projects/boba/constitution` |
| 8 | `6ea66d6d87cbf1e9` | LIVE | 13.0 MB | 294 | 3208 | 2026-08-18 21:02 | `/run/media/milosvasic/DATA4TB/Projects/assignments/…` |
| 9 | `8addff8070269398` | LIVE | 6.5 MB | 220 | 1051 | 2026-08-20 17:38 | `/run/media/milosvasic/DATA4TB/Projects/lava/.claude/worktrees/agent-ae3b1805128e2e0c8` |
| 10 | `35d7137ceae5a7b4` | LIVE | 3.2 MB | 51 | 351 | 2026-07-22 19:59 | `/run/media/milosvasic/DATA4TB/Projects/helix_seller` |
| 11 | `d0d7a5956ee798fd` | LIVE | 3.2 MB | 66 | 512 | 2026-07-31 17:45 | `/home/milosvasic/Downloads` |
| 12 | `002451c5e88e19b1` | DEAD | 3.1 MB | 1 | 1 | 2026-07-26 22:30 | `/tmp/.private/milosvasic/tmp.Wi8cikm3Dw` |
| 13 | `00e9aeba4da4732b` | DEAD | 3.1 MB | 1 | 1 | 2026-07-26 20:20 | `/tmp/.private/milosvasic/tmp.pHsCTrLuTv` |
| 14 | `0191bb1eccd8cf77` | DEAD | 3.1 MB | 1 | 1 | 2026-07-26 20:18 | `/tmp/.private/milosvasic/tmp.IVP5aXoSOH` |
| 15 | `01c1ac8c33a35b28` | DEAD | 3.1 MB | 1 | 1 | 2026-07-26 20:19 | `/tmp/.private/milosvasic/tmp.YBPulpZDCl` |
| 16 | `02011d8b05db8e4a` | DEAD | 3.1 MB | 1 | 1 | 2026-07-26 20:19 | `/tmp/.private/milosvasic/tmp.Llwop4kAk8` |
| 17 | `02118a328d9a3f28` | DEAD | 3.1 MB | 1 | 1 | 2026-07-26 22:42 | `/tmp/.private/milosvasic/tmp.ZBVHJFFTJc` |
| 18 | `0289aee246bb4ef0` | DEAD | 3.1 MB | 2 | 2 | 2026-07-26 20:56 | `/tmp/.private/milosvasic/tmp.B85zEfpw25` |
| 19 | `0356037ef790e0b0` | DEAD | 3.1 MB | 1 | 1 | 2026-07-26 14:58 | `/tmp/.private/milosvasic/tmp.1eKyQetVKd` |
| 20 | `0483a5cd64a52c6e` | DEAD | 3.1 MB | 1 | 2 | 2026-07-26 22:27 | `/tmp/.private/milosvasic/tmp.8XhBWPFChO` |

> **Redaction — 2026-09-02.** The `6ea66d6d87cbf1e9` row above (rank 8) ends in `assignments/…`. The `…` is a
> deliberate elision, not a truncated path: that project path's final component was a third party's given name, and
> this repository is public. Recorded as a separate instance in
> [`docs/content-boundary-incident-2026-09-01.md`](../content-boundary-incident-2026-09-01.md) §13.

Everything below rank 20 is a 3.1 MB DEAD scratch index or a 0.1 MB INCOMPLETE stub — the tail is flat and
uninteresting. The whole store is: 5 real projects, 1 in-flight newcomer, and ~740 pieces of lint.

---

## 4. Unmounted-drive risk — assessed and cleared

The brief correctly flags the danger: this host mounts projects under `/run/media/...`, so an unmounted external
drive would make a LIVE project look DEAD. **That risk was checked explicitly and it does not materialise here.**

Evidence:

1. **No DEAD index records a path under `/run/media/` at all.** Of 525 DEAD indexes, 524 point into `/tmp` and 1
   points at `/home/milosvasic/Projects`. Zero point at removable media.
2. The only volume ever mounted under `/run/media/milosvasic/` is `DATA4TB`, and it **is mounted right now**
   (`/dev/nvme0n1p1` → `/run/media/milosvasic/DATA4TB`, btrfs, 3.6 TB). Every `/run/media/...` path in the store
   resolves successfully.
3. `/home` is a separate mounted filesystem (`/dev/nvme1n1p3`) and is mounted. `/tmp` is mounted.
4. `lsblk` shows no other block device with an unmounted filesystem holding projects.

| Path prefix of DEAD indexes | Count | Size | Filesystem mounted? | Verdict |
|---|---:|---:|---|---|
| `/tmp/.private/milosvasic/tmp.*` | 511 | 933.4 MB | yes (`/tmp`) | **Definitely deleted** — per-session agent scratch dirs |
| `/tmp/*` (other) | 13 | 1.2 MB | yes (`/tmp`) | **Definitely deleted** — test fixtures |
| `/home/milosvasic/Projects` | 1 | 0.1 MB | yes (`/home`) | **Definitely deleted** — parent dir absent |
| `/run/media/**` | **0** | 0.0 MB | — | none exist |

**Conclusion: "possibly unmounted" = 0 indexes / 0.0 MB. All 525 DEAD indexes are definitely deleted.**

The `/tmp` finding also explains the store's shape: 511 of 525 DEAD indexes are one-file, one-chunk indexes of
`mktemp`-style agent scratch directories that were indexed once and vanished at reboot. Each costs ~3.1 MB
(a near-empty SQLite + vector-table skeleton), which is why 511 trivial indexes add up to 933.4 MB.

---

## 5. LIVE indexes (keep)

| Index dir | Size | Files | Chunks | Last indexed | Project path |
|---|---:|---:|---:|---|---|
| `74e360aac96f417e` | 681.9 MB | 14825 | 201252 | 2026-08-25T23:41:53Z | `/run/media/milosvasic/DATA4TB/Projects/boba` |
| `feaae19c7a38712e` | 270.4 MB | 7920 | 77163 | 2026-08-26T13:28:54Z | `/run/media/milosvasic/DATA4TB/Projects/lava` |
| `e7758398337f6aa7` | 139.5 MB | 282 | 2038 | 2026-07-26T22:24:38Z | `/tmp/.private/milosvasic` |
| `0e540668e98c02ce` | 125.2 MB | 2247 | 37348 | 2026-07-26T19:21:56Z | `/run/media/milosvasic/DATA4TB/Projects/claude_toolkit` |
| `40b9531ba54c9f4f` | 45.7 MB | 1000 | 13255 | 2026-08-13T09:55:35Z | `/run/media/milosvasic/DATA4TB/Projects/tmux` |
| `6ea66d6d87cbf1e9` | 13.0 MB | 294 | 3208 | 2026-08-18T19:02:55Z | `/run/media/milosvasic/DATA4TB/Projects/assignments/…` |
| `8addff8070269398` | 6.5 MB | 220 | 1051 | 2026-08-20T15:38:47Z | `/run/media/milosvasic/DATA4TB/Projects/lava/.claude/worktrees/agent-ae3b1805128e2e0c8` |
| `35d7137ceae5a7b4` | 3.2 MB | 51 | 351 | 2026-07-22T17:59:52Z | `/run/media/milosvasic/DATA4TB/Projects/helix_seller` |
| `d0d7a5956ee798fd` | 3.2 MB | 66 | 512 | 2026-07-31T15:45:07Z | `/home/milosvasic/Downloads` |
| `97e1836a7eabe96a` | 0.1 MB | 0 | 0 | 2026-07-12T16:41:04Z | `/home/milosvasic/Downloads/flashing/1.2.1-dev-0.0.3` |

> **Redaction — 2026-09-02.** The `6ea66d6d87cbf1e9` row above ends in `assignments/…`. The `…` is a deliberate
> elision, not a truncated path: that project path's final component was a third party's given name, and this
> repository is public. Recorded as a separate instance in
> [`docs/content-boundary-incident-2026-09-01.md`](../content-boundary-incident-2026-09-01.md) §13.

Two entries are worth a second look, though neither is an orphan by the brief's definition:

- **`e7758398337f6aa7` — `/tmp/.private/milosvasic` (139.5 MB).** This is an index of the *agent scratchpad root*,
  not a project. The path exists, so it classifies LIVE, but it indexes throwaway data and is the 4th-largest
  directory in the store. It is also the single most dangerous purge target — see the warning in §7.
- **`d0d7a5956ee798fd` — `/home/milosvasic/Downloads` (3.2 MB)** and **`97e1836a7eabe96a` —
  `/home/milosvasic/Downloads/flashing/1.2.1-dev-0.0.3` (0.1 MB, 0 files, 0 chunks).** Also not projects.

These are judgement calls for the operator, not orphans. They are **excluded** from the reclaim commands below.

---

## 6. INCOMPLETE indexes — 227 dirs, 22.1 MB

These DBs open fine and have valid schemas, but `project_meta` contains **only** `vec_dimensions = 768` — no
`project_path`, no `embedding_model`, no `root_hash`, no `last_indexed_at`.

This is not an old-binary artefact. It is the signature of an **index run that was interrupted before it finished**:

| Evidence | Reading |
|---|---|
| 220 of 227 have rows in `files` | the file walk completed |
| **1** of 227 has rows in `chunks` | embedding had barely started or not at all |
| 0 of 227 record `project_path` | lumen writes it only on successful completion |
| `06dd1f85fde5febb` looked identical — and is a *live, running* index | confirms the mechanism |

So the write order is: create schema → walk files → embed chunks → **write `project_meta` and finalise**. Anything
killed before the last step leaves exactly this fingerprint. With ~4 indexers running concurrently on this host and
agent sessions being cancelled, a steady drip of aborted runs is expected.

**Consequence for cleanup — this is the important part:** `lumen purge <path>` matches on `project_path` recorded
inside the DB. These 227 directories have no `project_path`, so **they can never be matched by any per-project purge**.
Lumen's own help says the only supported way to remove them is bare `lumen purge` — which is exactly the
irreversible, everything-including-the-active-rebuild command the operator must not run. They therefore require
`rm -rf` of the specific directories, listed in §7.4.

Their contents are unrecoverable anyway: no path, relative filenames only, and essentially no embeddings.

---

## 7. Proposed commands

> **None of the following was executed.** They are written for the operator to run, after the four indexers exit.

### 7.0 Preconditions — run these first, every time

```bash
# 1. Confirm NO indexer is running. Must print nothing.
ps -ef | grep -E 'lumen(-linux-amd64)? +index' | grep -v grep

# 2. Confirm the vasic rebuild finished and is intact (expect a project_path row).
sqlite3 'file:$HOME/.local/share/lumen/21bf1507a8925bcf/index.db?mode=ro' \
  'SELECT key,value FROM project_meta;'

# 3. Snapshot sizes so you can prove what was reclaimed.
du -sh ~/.local/share/lumen
```

### 7.1 ⚠️ Read this before running any purge

`lumen purge <path>` **normalises the path to its git root before matching** (the binary shells out to
`git rev-parse`). Every DEAD path below **no longer exists**, so that normalisation cannot be verified in advance.
There is a plausible failure mode:

- If lumen falls back to the nearest *existing* ancestor when a path is gone, then
  `lumen purge /tmp/.private/milosvasic/tmp.XXXX` could resolve to **`/tmp/.private/milosvasic`** — which is a
  **LIVE 139.5 MB index** (`e7758398337f6aa7`). You would delete the wrong thing, 511 times over.
- If lumen instead uses the path verbatim (the more likely behaviour: `git rev-parse` fails on a missing dir), the
  commands work as intended and unmatched paths simply print `No index found for <path>.`

**This could not be settled without running `purge`, which was out of scope. So: dry-run on ONE path first.**

```bash
# Canary. Note the size of the LIVE scratchpad index BEFORE:
du -sh ~/.local/share/lumen/e7758398337f6aa7   # expect ~140M

lumen purge /tmp/.private/milosvasic/tmp.Wi8cikm3Dw

# Now verify: 002451c5e88e19b1 should be GONE, e7758398337f6aa7 must still be ~140M.
ls -d ~/.local/share/lumen/002451c5e88e19b1 2>&1   # expect: No such file or directory
du -sh ~/.local/share/lumen/e7758398337f6aa7      # MUST still be ~140M
```

**If `e7758398337f6aa7` shrank or vanished, STOP.** Do not run the bulk commands; use the `rm -rf` form in §7.4,
which addresses index directories directly and cannot mis-resolve.

### 7.2 Tier 1 — DEAD ephemeral `/tmp` scratch indexes (524 dirs, 934.6 MB)

The bulk of the win. Batched to stay under `ARG_MAX`.

```bash
cat > /tmp/lumen-dead-paths.txt <<'EOF'
/tmp/.private/milosvasic/tmp.0IvWvhTGtC
/tmp/.private/milosvasic/tmp.0J4Hgg6WXK
/tmp/.private/milosvasic/tmp.0Oggx6IuEl
/tmp/.private/milosvasic/tmp.0dm71SJYE5
/tmp/.private/milosvasic/tmp.0opbsPzeIw
/tmp/.private/milosvasic/tmp.0qiz4BxjCz
/tmp/.private/milosvasic/tmp.0qoPxbtWhc
/tmp/.private/milosvasic/tmp.19RxbUEFBK
/tmp/.private/milosvasic/tmp.1CXo0uK06j
/tmp/.private/milosvasic/tmp.1OwQq7tmGn
/tmp/.private/milosvasic/tmp.1YBpfUc4lH
/tmp/.private/milosvasic/tmp.1eKyQetVKd
/tmp/.private/milosvasic/tmp.1zjlwkkCKf
/tmp/.private/milosvasic/tmp.29o5eKoVrx
/tmp/.private/milosvasic/tmp.2DFvwGaSKG
/tmp/.private/milosvasic/tmp.2DtnY8k5a2
/tmp/.private/milosvasic/tmp.2Ra7LjJYMo
/tmp/.private/milosvasic/tmp.2WFbM2lAGz
/tmp/.private/milosvasic/tmp.2XVdQlqeYp
/tmp/.private/milosvasic/tmp.2Z6QDvI3eT
/tmp/.private/milosvasic/tmp.2aBAPmNU2o
/tmp/.private/milosvasic/tmp.2fk1sFayfE
/tmp/.private/milosvasic/tmp.2idtDVOSv2
/tmp/.private/milosvasic/tmp.2ovpmsSi9L
/tmp/.private/milosvasic/tmp.324800akKg
/tmp/.private/milosvasic/tmp.3AuPGUo4uX
/tmp/.private/milosvasic/tmp.3FeePFeihQ
/tmp/.private/milosvasic/tmp.3HTes9ySYu
/tmp/.private/milosvasic/tmp.3OrtWk7QCl
/tmp/.private/milosvasic/tmp.3aArywA7YA
/tmp/.private/milosvasic/tmp.3aNzj5zJxq
/tmp/.private/milosvasic/tmp.3naMrNbKJk
/tmp/.private/milosvasic/tmp.3s2siPRpGO
/tmp/.private/milosvasic/tmp.4BHS6FUFTz
/tmp/.private/milosvasic/tmp.4IWedpbATt
/tmp/.private/milosvasic/tmp.4Ry6BV9l6S
/tmp/.private/milosvasic/tmp.4SQKFvhC2d
/tmp/.private/milosvasic/tmp.4UMmImXSsY
/tmp/.private/milosvasic/tmp.4Ywk9IBa4m
/tmp/.private/milosvasic/tmp.4fLcYKb6cz
/tmp/.private/milosvasic/tmp.4iUz1ck45G
/tmp/.private/milosvasic/tmp.4lGuHhXQVA
/tmp/.private/milosvasic/tmp.51mClspO3t
/tmp/.private/milosvasic/tmp.52VwdEzGZl
/tmp/.private/milosvasic/tmp.58zavFOlAf
/tmp/.private/milosvasic/tmp.5D0ODih5Z0
/tmp/.private/milosvasic/tmp.5Dub3XtiMO
/tmp/.private/milosvasic/tmp.5KiuoWIoBr
/tmp/.private/milosvasic/tmp.5MmvuZ3iK2
/tmp/.private/milosvasic/tmp.5Oeqe11zNr
/tmp/.private/milosvasic/tmp.5kOWTflmtU
/tmp/.private/milosvasic/tmp.5urDr6jZng
/tmp/.private/milosvasic/tmp.5wYv9sh901
/tmp/.private/milosvasic/tmp.5wo0wZ5Sl1
/tmp/.private/milosvasic/tmp.607VQxL42C
/tmp/.private/milosvasic/tmp.64vk2O8OTD
/tmp/.private/milosvasic/tmp.6GFXHSW3Rz
/tmp/.private/milosvasic/tmp.6O1X15aZjF
/tmp/.private/milosvasic/tmp.6SX0d58p8D
/tmp/.private/milosvasic/tmp.6eXUwEksYr
/tmp/.private/milosvasic/tmp.6k4dsIEw3V
/tmp/.private/milosvasic/tmp.6k4wOPSjAr
/tmp/.private/milosvasic/tmp.6t2i5dB0dB
/tmp/.private/milosvasic/tmp.6wePAMrCCd
/tmp/.private/milosvasic/tmp.74OwIKvK6H
/tmp/.private/milosvasic/tmp.7G5kTaeBZ4
/tmp/.private/milosvasic/tmp.7J0pV0CKHu
/tmp/.private/milosvasic/tmp.7KclkKM1TH
/tmp/.private/milosvasic/tmp.7UslVwapBb
/tmp/.private/milosvasic/tmp.7eckFiaosr
/tmp/.private/milosvasic/tmp.7pLreu1krU
/tmp/.private/milosvasic/tmp.7qqFATVZZ0
/tmp/.private/milosvasic/tmp.7sCkFgMyNs
/tmp/.private/milosvasic/tmp.7umwkiFLrq
/tmp/.private/milosvasic/tmp.89o66vsdnL
/tmp/.private/milosvasic/tmp.8GFSdTZoBA
/tmp/.private/milosvasic/tmp.8XhBWPFChO
/tmp/.private/milosvasic/tmp.8c7ue5SYzz
/tmp/.private/milosvasic/tmp.8d20cv0aiz
/tmp/.private/milosvasic/tmp.8mjMuRmtm4
/tmp/.private/milosvasic/tmp.8uqMY4HGDB
/tmp/.private/milosvasic/tmp.8yGVffe8U0
/tmp/.private/milosvasic/tmp.90lBMyoCIx
/tmp/.private/milosvasic/tmp.96Mz5XEkKz
/tmp/.private/milosvasic/tmp.9S5sLXmH5P
/tmp/.private/milosvasic/tmp.9b7YOzjm6I
/tmp/.private/milosvasic/tmp.9eCNAjxclM
/tmp/.private/milosvasic/tmp.9qPw7PwXDp
/tmp/.private/milosvasic/tmp.9wr2TVZOGX
/tmp/.private/milosvasic/tmp.9wzsT75y7S
/tmp/.private/milosvasic/tmp.9xqbdHh1u3
/tmp/.private/milosvasic/tmp.A3zaSlAoxi
/tmp/.private/milosvasic/tmp.AHuONfW5jS
/tmp/.private/milosvasic/tmp.AWP5WRvPIb
/tmp/.private/milosvasic/tmp.AtiqqFAk8s
/tmp/.private/milosvasic/tmp.B4U9Qst9Vq
/tmp/.private/milosvasic/tmp.B85zEfpw25
/tmp/.private/milosvasic/tmp.BCjV7eTE37
/tmp/.private/milosvasic/tmp.BJ0HMypRYk
/tmp/.private/milosvasic/tmp.BX2tEp8SbL
/tmp/.private/milosvasic/tmp.BbiBu4txd9
/tmp/.private/milosvasic/tmp.BcubaEOAxc
/tmp/.private/milosvasic/tmp.Bj9CggcxAV
/tmp/.private/milosvasic/tmp.BmnFObLjhG
/tmp/.private/milosvasic/tmp.BxOa6XNFGs
/tmp/.private/milosvasic/tmp.CRTTpcgTQv
/tmp/.private/milosvasic/tmp.CzRtbl8PUO
/tmp/.private/milosvasic/tmp.DArB4IKhrl
/tmp/.private/milosvasic/tmp.DBpdmliEcH
/tmp/.private/milosvasic/tmp.DCSsx819w2
/tmp/.private/milosvasic/tmp.DLm4dI078H
/tmp/.private/milosvasic/tmp.DP6qqJfqS6
/tmp/.private/milosvasic/tmp.Da0dgzD4k4
/tmp/.private/milosvasic/tmp.DnpzA7EzGF
/tmp/.private/milosvasic/tmp.DpGto5jreI
/tmp/.private/milosvasic/tmp.DyrpdnaXJj
/tmp/.private/milosvasic/tmp.ENnDgPbNCi
/tmp/.private/milosvasic/tmp.ET1oNeeTjL
/tmp/.private/milosvasic/tmp.EZgXQwQEV7
/tmp/.private/milosvasic/tmp.Eji05C7BHi
/tmp/.private/milosvasic/tmp.EkjFclX72L
/tmp/.private/milosvasic/tmp.EmA3MnxHvQ
/tmp/.private/milosvasic/tmp.F1fk7NEh50
/tmp/.private/milosvasic/tmp.F9emslQ5l5
/tmp/.private/milosvasic/tmp.FC214dsbvk
/tmp/.private/milosvasic/tmp.FISFQQfGGK
/tmp/.private/milosvasic/tmp.FQAv7kCFPG
/tmp/.private/milosvasic/tmp.FQkxArbyiY
/tmp/.private/milosvasic/tmp.FVxoAPjsgl
/tmp/.private/milosvasic/tmp.FeYytiIaVF
/tmp/.private/milosvasic/tmp.FslkqBQrpS
/tmp/.private/milosvasic/tmp.Ft1S9ur6MP
/tmp/.private/milosvasic/tmp.GFcovxR6Or
/tmp/.private/milosvasic/tmp.GIygnTMIPl
/tmp/.private/milosvasic/tmp.GR58nJsQQZ
/tmp/.private/milosvasic/tmp.GTmYybChPV
/tmp/.private/milosvasic/tmp.GVR5aVA2r0
/tmp/.private/milosvasic/tmp.GYpQhKlxQS
/tmp/.private/milosvasic/tmp.GZge1GMaKP
/tmp/.private/milosvasic/tmp.Gt2GP3ibJZ
/tmp/.private/milosvasic/tmp.GyfnfTqzjW
/tmp/.private/milosvasic/tmp.H3uakg9JHy
/tmp/.private/milosvasic/tmp.Hapfon2jqO
/tmp/.private/milosvasic/tmp.Hi0ugDkjjo
/tmp/.private/milosvasic/tmp.HlAaHLGRB1
/tmp/.private/milosvasic/tmp.I314YcMUSu
/tmp/.private/milosvasic/tmp.I7T0CBgL9w
/tmp/.private/milosvasic/tmp.ICq9gBrXyU
/tmp/.private/milosvasic/tmp.IDPxDKwT0X
/tmp/.private/milosvasic/tmp.IJxbHvJ8VS
/tmp/.private/milosvasic/tmp.IVP5aXoSOH
/tmp/.private/milosvasic/tmp.Idccj4y7De
/tmp/.private/milosvasic/tmp.IekkAYeguq
/tmp/.private/milosvasic/tmp.IjEXtoXUEJ
/tmp/.private/milosvasic/tmp.IoJ983i2QN
/tmp/.private/milosvasic/tmp.Izkb7vpyWg
/tmp/.private/milosvasic/tmp.J34yfXmSsN
/tmp/.private/milosvasic/tmp.JCH1zWGNRI
/tmp/.private/milosvasic/tmp.JNmeqiSMwR
/tmp/.private/milosvasic/tmp.JWckZVNQVZ
/tmp/.private/milosvasic/tmp.JXRHCreuVf
/tmp/.private/milosvasic/tmp.JZMiHXahnW
/tmp/.private/milosvasic/tmp.JaA5Qq9aa5
/tmp/.private/milosvasic/tmp.JbkaEbGLXH
/tmp/.private/milosvasic/tmp.JoYdnvPoEO
/tmp/.private/milosvasic/tmp.JtUf9Zl1it
/tmp/.private/milosvasic/tmp.K5h1LImlTr
/tmp/.private/milosvasic/tmp.KKcG4rRfU6
/tmp/.private/milosvasic/tmp.KPKQvEzhhP
/tmp/.private/milosvasic/tmp.KVW73QhuAL
/tmp/.private/milosvasic/tmp.KZzWkUEVRn
/tmp/.private/milosvasic/tmp.KgVvXrZYaD
/tmp/.private/milosvasic/tmp.KrSxAwDS0T
/tmp/.private/milosvasic/tmp.L3DzT1pfD6
/tmp/.private/milosvasic/tmp.LBynsZaLfM
/tmp/.private/milosvasic/tmp.LZOP3k5l2n
/tmp/.private/milosvasic/tmp.Ld7OCfjZ21
/tmp/.private/milosvasic/tmp.LdrRe9Bkbk
/tmp/.private/milosvasic/tmp.Llwop4kAk8
/tmp/.private/milosvasic/tmp.Lxso9jdrjA
/tmp/.private/milosvasic/tmp.M2tbI9V7an
/tmp/.private/milosvasic/tmp.M5MJ9tse5k
/tmp/.private/milosvasic/tmp.MSyDEaLffg
/tmp/.private/milosvasic/tmp.Mc5qpGf5I6
/tmp/.private/milosvasic/tmp.MnVOq3Tqvk
/tmp/.private/milosvasic/tmp.MnXhi7kgNk
/tmp/.private/milosvasic/tmp.MqVxJ0zEEV
/tmp/.private/milosvasic/tmp.MyoNLtDkFF
/tmp/.private/milosvasic/tmp.MzucfzvA3F
/tmp/.private/milosvasic/tmp.NK0F0HU5Dn
/tmp/.private/milosvasic/tmp.NgBmcPVj1c
/tmp/.private/milosvasic/tmp.Nl5yKBl25a
/tmp/.private/milosvasic/tmp.NoIHW7guZw
/tmp/.private/milosvasic/tmp.NpX5dsD0sw
/tmp/.private/milosvasic/tmp.O3ZSjJ2rJo
/tmp/.private/milosvasic/tmp.O54g3z97Z4
/tmp/.private/milosvasic/tmp.OEVfRubU3k
/tmp/.private/milosvasic/tmp.OKtofyIo3W
/tmp/.private/milosvasic/tmp.OYsJysznvt
/tmp/.private/milosvasic/tmp.ObgmN5ojcd
/tmp/.private/milosvasic/tmp.OmuOpGs8Wm
/tmp/.private/milosvasic/tmp.Oubi8a0mfL
/tmp/.private/milosvasic/tmp.OwQPabPmcL
/tmp/.private/milosvasic/tmp.P2EqsjWiO4
/tmp/.private/milosvasic/tmp.P3Z786Hlhs
/tmp/.private/milosvasic/tmp.P4IYlzRhWr
/tmp/.private/milosvasic/tmp.P6ss3qCY34
/tmp/.private/milosvasic/tmp.P7ZOwUV0fN
/tmp/.private/milosvasic/tmp.PSQd21GFCr
/tmp/.private/milosvasic/tmp.PfjChiwwmX
/tmp/.private/milosvasic/tmp.PjRRlL9hJt
/tmp/.private/milosvasic/tmp.Pr5iMHF6hG
/tmp/.private/milosvasic/tmp.PwBS9Imur8
/tmp/.private/milosvasic/tmp.PwXmhylZrl
/tmp/.private/milosvasic/tmp.QQjL4kglRm
/tmp/.private/milosvasic/tmp.QXMOseuaRv
/tmp/.private/milosvasic/tmp.QZyAJL2VC5
/tmp/.private/milosvasic/tmp.QhnpTEMvkx
/tmp/.private/milosvasic/tmp.QipPxwIBU2
/tmp/.private/milosvasic/tmp.QmZrNXj0XO
/tmp/.private/milosvasic/tmp.QnNW9TpmgS
/tmp/.private/milosvasic/tmp.RBGzLd72FT
/tmp/.private/milosvasic/tmp.RBq3bCO2u7
/tmp/.private/milosvasic/tmp.RDzNI3FgVn
/tmp/.private/milosvasic/tmp.RNgN0d36nH
/tmp/.private/milosvasic/tmp.ROzxfAz0IE
/tmp/.private/milosvasic/tmp.RVV5yR6LwI
/tmp/.private/milosvasic/tmp.RWlN7wvLuo
/tmp/.private/milosvasic/tmp.RleDBwWJpy
/tmp/.private/milosvasic/tmp.Ry0xVwCsVM
/tmp/.private/milosvasic/tmp.S8VGFV7aqE
/tmp/.private/milosvasic/tmp.SC52F1ilp5
/tmp/.private/milosvasic/tmp.SEesDgRUMn
/tmp/.private/milosvasic/tmp.SSIURCp4DO
/tmp/.private/milosvasic/tmp.SeA4XbTC8A
/tmp/.private/milosvasic/tmp.SlyFnT7l5f
/tmp/.private/milosvasic/tmp.SoGB5UZbnm
/tmp/.private/milosvasic/tmp.SyEjDkFjLl
/tmp/.private/milosvasic/tmp.T3rUogCeYl
/tmp/.private/milosvasic/tmp.T7sUdUvmCr
/tmp/.private/milosvasic/tmp.T9fgZzZb0J
/tmp/.private/milosvasic/tmp.TKG8xxNeTD
/tmp/.private/milosvasic/tmp.TRfMR2AgfU
/tmp/.private/milosvasic/tmp.TUCAGOHNbm
/tmp/.private/milosvasic/tmp.Tqasgu8J85
/tmp/.private/milosvasic/tmp.TqqkPBNre8
/tmp/.private/milosvasic/tmp.U618SD8Fa7
/tmp/.private/milosvasic/tmp.U8TzNVt4hN
/tmp/.private/milosvasic/tmp.UGw7ciIb1S
/tmp/.private/milosvasic/tmp.UHaZ6BKrrH
/tmp/.private/milosvasic/tmp.UP0CA7vxY1
/tmp/.private/milosvasic/tmp.Uh1gTjniAs
/tmp/.private/milosvasic/tmp.UkdXCROAr1
/tmp/.private/milosvasic/tmp.Ul4a9JX5Gv
/tmp/.private/milosvasic/tmp.UpmsbGns01
/tmp/.private/milosvasic/tmp.UqnnvmVhuD
/tmp/.private/milosvasic/tmp.Uumd2Uxxmi
/tmp/.private/milosvasic/tmp.UwFGbBOmDX
/tmp/.private/milosvasic/tmp.VJXy8q7lwS
/tmp/.private/milosvasic/tmp.VQLgnuSxZX
/tmp/.private/milosvasic/tmp.VRTvXcoMBW
/tmp/.private/milosvasic/tmp.VUor5UTAzn
/tmp/.private/milosvasic/tmp.VW8BNP9osv
/tmp/.private/milosvasic/tmp.VZ6gHKTtd9
/tmp/.private/milosvasic/tmp.VyxwYq7Hw3
/tmp/.private/milosvasic/tmp.VzHwo1Chhx
/tmp/.private/milosvasic/tmp.W4btjsCWve
/tmp/.private/milosvasic/tmp.W5yKzCYonZ
/tmp/.private/milosvasic/tmp.WBSIpzwTPk
/tmp/.private/milosvasic/tmp.WMD1SHLIe1
/tmp/.private/milosvasic/tmp.WbDoxR3vaT
/tmp/.private/milosvasic/tmp.Wi8cikm3Dw
/tmp/.private/milosvasic/tmp.Wud6oqAcaA
/tmp/.private/milosvasic/tmp.X428h1kjab
/tmp/.private/milosvasic/tmp.X4VncZOIZW
/tmp/.private/milosvasic/tmp.X4YWVGq2Zo
/tmp/.private/milosvasic/tmp.X72C2Qv5HP
/tmp/.private/milosvasic/tmp.XOCaUEgbP3
/tmp/.private/milosvasic/tmp.XUuuTMF0Fh
/tmp/.private/milosvasic/tmp.XwtYN15j4D
/tmp/.private/milosvasic/tmp.XxU0DurvUx
/tmp/.private/milosvasic/tmp.YBPulpZDCl
/tmp/.private/milosvasic/tmp.YC4cTpHBBr
/tmp/.private/milosvasic/tmp.YH7mr1BAyu
/tmp/.private/milosvasic/tmp.YUbodevquq
/tmp/.private/milosvasic/tmp.YbLpq5VCtv
/tmp/.private/milosvasic/tmp.YpdeUllb5K
/tmp/.private/milosvasic/tmp.Z15X6lQXZy
/tmp/.private/milosvasic/tmp.Z1LmO948rF
/tmp/.private/milosvasic/tmp.ZAUsf7IyCX
/tmp/.private/milosvasic/tmp.ZAhN5q4oqN
/tmp/.private/milosvasic/tmp.ZBVHJFFTJc
/tmp/.private/milosvasic/tmp.ZCUBoc8os4
/tmp/.private/milosvasic/tmp.ZINR4XutHd
/tmp/.private/milosvasic/tmp.ZKHhwsDigw
/tmp/.private/milosvasic/tmp.ZYnlIqbedv
/tmp/.private/milosvasic/tmp.ZaGsKSjAKy
/tmp/.private/milosvasic/tmp.Zdtka6mjv4
/tmp/.private/milosvasic/tmp.Zn8dVEA3aJ
/tmp/.private/milosvasic/tmp.Zne85y6EjZ
/tmp/.private/milosvasic/tmp.Zw3H8fL7Pv
/tmp/.private/milosvasic/tmp.ZyWzHuczPB
/tmp/.private/milosvasic/tmp.a1wzvnjx3B
/tmp/.private/milosvasic/tmp.a4mg4h4DIJ
/tmp/.private/milosvasic/tmp.a5ZNlbamjn
/tmp/.private/milosvasic/tmp.aAAiZ3U2C9
/tmp/.private/milosvasic/tmp.aDopDIrKoi
/tmp/.private/milosvasic/tmp.aLMpn68kQH
/tmp/.private/milosvasic/tmp.aXG7PrTXVO
/tmp/.private/milosvasic/tmp.aYdPZxtYkZ
/tmp/.private/milosvasic/tmp.adBzO5pSJt
/tmp/.private/milosvasic/tmp.apd0vZPbBP
/tmp/.private/milosvasic/tmp.b1mdgz0vwo
/tmp/.private/milosvasic/tmp.b51aGLwlr4
/tmp/.private/milosvasic/tmp.b7SxTmrIOa
/tmp/.private/milosvasic/tmp.bAziMNrdn7
/tmp/.private/milosvasic/tmp.bFrHWDAfax
/tmp/.private/milosvasic/tmp.bHrbxdeCdT
/tmp/.private/milosvasic/tmp.bLlUIYqOOg
/tmp/.private/milosvasic/tmp.blDrExgY4H
/tmp/.private/milosvasic/tmp.bmvPv6RSWr
/tmp/.private/milosvasic/tmp.c1Fg5LCDeK
/tmp/.private/milosvasic/tmp.c9kjZQkoY1
/tmp/.private/milosvasic/tmp.cIB2o0fDch
/tmp/.private/milosvasic/tmp.cNsRzVkd2a
/tmp/.private/milosvasic/tmp.cgOZToGDKD
/tmp/.private/milosvasic/tmp.cljr6xs33M
/tmp/.private/milosvasic/tmp.d8G7u7LZDG
/tmp/.private/milosvasic/tmp.dEpfXQLc7M
/tmp/.private/milosvasic/tmp.dLPmiyHLW7
/tmp/.private/milosvasic/tmp.dTVevLQjYD
/tmp/.private/milosvasic/tmp.daKmO1yRbm
/tmp/.private/milosvasic/tmp.ddpJ6sHieC
/tmp/.private/milosvasic/tmp.df6yXxuRkY
/tmp/.private/milosvasic/tmp.dp8ubUoTsR
/tmp/.private/milosvasic/tmp.drZnF2abBe
/tmp/.private/milosvasic/tmp.e3G8wJ9rBL
/tmp/.private/milosvasic/tmp.e92phECe0F
/tmp/.private/milosvasic/tmp.eCAr2ZseE1
/tmp/.private/milosvasic/tmp.ee3p9bsprx
/tmp/.private/milosvasic/tmp.eeGkOr6cVv
/tmp/.private/milosvasic/tmp.emQPm7mbkf
/tmp/.private/milosvasic/tmp.eo5uKrq7Nl
/tmp/.private/milosvasic/tmp.erXDyScnoi
/tmp/.private/milosvasic/tmp.etpf7h5bea
/tmp/.private/milosvasic/tmp.exyY2WpvAO
/tmp/.private/milosvasic/tmp.f8axKuPPtS
/tmp/.private/milosvasic/tmp.f9ugaIrTPw
/tmp/.private/milosvasic/tmp.fVwfsAtztX
/tmp/.private/milosvasic/tmp.fjjM0Qon0H
/tmp/.private/milosvasic/tmp.fkoETCAPVm
/tmp/.private/milosvasic/tmp.fsGw2JyP6U
/tmp/.private/milosvasic/tmp.fubCGoRuST
/tmp/.private/milosvasic/tmp.g5mGwpijpR
/tmp/.private/milosvasic/tmp.gBt2og4Eaq
/tmp/.private/milosvasic/tmp.gFLqjwkgxa
/tmp/.private/milosvasic/tmp.gJwKvlXKLi
/tmp/.private/milosvasic/tmp.gNM7SD3Uoo
/tmp/.private/milosvasic/tmp.gSrO64BwFA
/tmp/.private/milosvasic/tmp.gTcvpT2vwG
/tmp/.private/milosvasic/tmp.hGVx81WsZz
/tmp/.private/milosvasic/tmp.hYV8rylBen
/tmp/.private/milosvasic/tmp.hkBpz3bgTj
/tmp/.private/milosvasic/tmp.hxExvlUtbx
/tmp/.private/milosvasic/tmp.i9mYlGO9eS
/tmp/.private/milosvasic/tmp.iAeEmbcnso
/tmp/.private/milosvasic/tmp.iF4yIGaY0w
/tmp/.private/milosvasic/tmp.iG8bNhxUej
/tmp/.private/milosvasic/tmp.iS1wmdPQ0o
/tmp/.private/milosvasic/tmp.j1Cjjbtrlg
/tmp/.private/milosvasic/tmp.j1hcTy0Yjt
/tmp/.private/milosvasic/tmp.j39XczccSv
/tmp/.private/milosvasic/tmp.j3Qi97UncL
/tmp/.private/milosvasic/tmp.jGcouZmqQ3
/tmp/.private/milosvasic/tmp.jPSKUarddp
/tmp/.private/milosvasic/tmp.jWsGr5AnOL
/tmp/.private/milosvasic/tmp.jcNkQz8sn3
/tmp/.private/milosvasic/tmp.jeiDVTZH85
/tmp/.private/milosvasic/tmp.kCMghnfNlI
/tmp/.private/milosvasic/tmp.kCe50YklSE
/tmp/.private/milosvasic/tmp.kLNFLTZqU3
/tmp/.private/milosvasic/tmp.kNY8liWZd9
/tmp/.private/milosvasic/tmp.kTNR6qsQyW
/tmp/.private/milosvasic/tmp.kZmXQmxEiB
/tmp/.private/milosvasic/tmp.kcvCzjjJx8
/tmp/.private/milosvasic/tmp.koVf83kyd0
/tmp/.private/milosvasic/tmp.lGDVvuwXTl
/tmp/.private/milosvasic/tmp.lGUHyxSGAH
/tmp/.private/milosvasic/tmp.lJjk2A4AWJ
/tmp/.private/milosvasic/tmp.lXvRVE0FBB
/tmp/.private/milosvasic/tmp.lZ61XvxPsc
/tmp/.private/milosvasic/tmp.lfJiZ40TJP
/tmp/.private/milosvasic/tmp.ll5LLHVIg3
/tmp/.private/milosvasic/tmp.lxcOlXnDte
/tmp/.private/milosvasic/tmp.lzGDYrBGqj
/tmp/.private/milosvasic/tmp.mCOX7fvSqI
/tmp/.private/milosvasic/tmp.mEr5BMFdhw
/tmp/.private/milosvasic/tmp.mPEMtoV5i9
/tmp/.private/milosvasic/tmp.mSwXER62wV
/tmp/.private/milosvasic/tmp.mTYeS3MIsT
/tmp/.private/milosvasic/tmp.mV2DRdaztr
/tmp/.private/milosvasic/tmp.mWhvOUtlzC
/tmp/.private/milosvasic/tmp.mdKmhvczeq
/tmp/.private/milosvasic/tmp.n1vDtBPSJx
/tmp/.private/milosvasic/tmp.n4optUCF4c
/tmp/.private/milosvasic/tmp.n8J6uszf6n
/tmp/.private/milosvasic/tmp.nZ9om1GtUX
/tmp/.private/milosvasic/tmp.ndlovjw22C
/tmp/.private/milosvasic/tmp.neV83t6AgS
/tmp/.private/milosvasic/tmp.njcyrFNdBP
/tmp/.private/milosvasic/tmp.nnxrnxKohp
/tmp/.private/milosvasic/tmp.ntpcVfwrUj
/tmp/.private/milosvasic/tmp.o1UeBKFzCm
/tmp/.private/milosvasic/tmp.oA3D9wPDEv
/tmp/.private/milosvasic/tmp.oEECIFXAPX
/tmp/.private/milosvasic/tmp.oUlBC1rUcU
/tmp/.private/milosvasic/tmp.oei28o53eR
/tmp/.private/milosvasic/tmp.pHsCTrLuTv
/tmp/.private/milosvasic/tmp.pMLEakV8FK
/tmp/.private/milosvasic/tmp.pPexwV8AhQ
/tmp/.private/milosvasic/tmp.pRK8ea3u7f
/tmp/.private/milosvasic/tmp.pS3n7NyouT
/tmp/.private/milosvasic/tmp.pTUBblVYCg
/tmp/.private/milosvasic/tmp.pZhGYGuuqF
/tmp/.private/milosvasic/tmp.poOIqoVz9v
/tmp/.private/milosvasic/tmp.pwom89Qlha
/tmp/.private/milosvasic/tmp.q5N3Eq3laD
/tmp/.private/milosvasic/tmp.qAPQ9uzea0
/tmp/.private/milosvasic/tmp.qCgI9OH1Ci
/tmp/.private/milosvasic/tmp.qDAHqtKJCn
/tmp/.private/milosvasic/tmp.qNI2UvI25P
/tmp/.private/milosvasic/tmp.qTBimFdRBT
/tmp/.private/milosvasic/tmp.qWH1h0N7vj
/tmp/.private/milosvasic/tmp.qdjwH49GGI
/tmp/.private/milosvasic/tmp.qiC9YkNg3w
/tmp/.private/milosvasic/tmp.qohbIqaa4G
/tmp/.private/milosvasic/tmp.r14ORgKnuB
/tmp/.private/milosvasic/tmp.r3ACBsvX48
/tmp/.private/milosvasic/tmp.r6khJGlNlW
/tmp/.private/milosvasic/tmp.rCZNwDx9uu
/tmp/.private/milosvasic/tmp.rPO3xBYlVT
/tmp/.private/milosvasic/tmp.rVi6MY0oJE
/tmp/.private/milosvasic/tmp.rnBZwR53Nn
/tmp/.private/milosvasic/tmp.rts1ZxJuVk
/tmp/.private/milosvasic/tmp.ru8YX4qJKc
/tmp/.private/milosvasic/tmp.rxQBBrq0V2
/tmp/.private/milosvasic/tmp.rxfbHet9tv
/tmp/.private/milosvasic/tmp.rzvadTYh1m
/tmp/.private/milosvasic/tmp.s1Q08QkEAD
/tmp/.private/milosvasic/tmp.s1W34C0aDO
/tmp/.private/milosvasic/tmp.s6QnRhCsyf
/tmp/.private/milosvasic/tmp.s80G9I6cBX
/tmp/.private/milosvasic/tmp.s8o0i4O7C3
/tmp/.private/milosvasic/tmp.sQgBrWt3Xx
/tmp/.private/milosvasic/tmp.sQxYvZbdM6
/tmp/.private/milosvasic/tmp.sW6S2DNSIj
/tmp/.private/milosvasic/tmp.sX2B26PcF7
/tmp/.private/milosvasic/tmp.sqq2jtsFx1
/tmp/.private/milosvasic/tmp.sz3og8EESB
/tmp/.private/milosvasic/tmp.tKsbtbbB7L
/tmp/.private/milosvasic/tmp.tMDudAkq0v
/tmp/.private/milosvasic/tmp.tNldbHsMfs
/tmp/.private/milosvasic/tmp.tX6BoBfbj0
/tmp/.private/milosvasic/tmp.tkF8kuElCF
/tmp/.private/milosvasic/tmp.uD2hptlVgy
/tmp/.private/milosvasic/tmp.uIzH0sdmrP
/tmp/.private/milosvasic/tmp.umaBfzzKgk
/tmp/.private/milosvasic/tmp.urPitc51OK
/tmp/.private/milosvasic/tmp.uxNXmWMFdk
/tmp/.private/milosvasic/tmp.v1ck1xO13T
/tmp/.private/milosvasic/tmp.vDxJxa3oMQ
/tmp/.private/milosvasic/tmp.vIFVqK8Xb4
/tmp/.private/milosvasic/tmp.vWFnwOaPLV
/tmp/.private/milosvasic/tmp.vXPIuglsE0
/tmp/.private/milosvasic/tmp.vh7Vn81OPw
/tmp/.private/milosvasic/tmp.w4EUz2qIYe
/tmp/.private/milosvasic/tmp.wFOXpKMuZB
/tmp/.private/milosvasic/tmp.wH9lrtjB73
/tmp/.private/milosvasic/tmp.wJUUFWBYqX
/tmp/.private/milosvasic/tmp.wVzGlpaWB6
/tmp/.private/milosvasic/tmp.ws9WzlMMJB
/tmp/.private/milosvasic/tmp.wxz9rJcTHF
/tmp/.private/milosvasic/tmp.xAF1gJmlhH
/tmp/.private/milosvasic/tmp.xDYaKUrBkT
/tmp/.private/milosvasic/tmp.xHIyvgRLpN
/tmp/.private/milosvasic/tmp.xKzzwfB7ca
/tmp/.private/milosvasic/tmp.xTKh90ctIu
/tmp/.private/milosvasic/tmp.xZ8TaMabsJ
/tmp/.private/milosvasic/tmp.xnaZLKYww6
/tmp/.private/milosvasic/tmp.y3E0HnRvV5
/tmp/.private/milosvasic/tmp.y4NqL9aqe3
/tmp/.private/milosvasic/tmp.y8WECBYg5S
/tmp/.private/milosvasic/tmp.yEcMvR065X
/tmp/.private/milosvasic/tmp.yH2wgh5XxI
/tmp/.private/milosvasic/tmp.yKqgQSHYTA
/tmp/.private/milosvasic/tmp.ySLr5aQCHb
/tmp/.private/milosvasic/tmp.yeLp05xdOt
/tmp/.private/milosvasic/tmp.ygEogG1zrl
/tmp/.private/milosvasic/tmp.yqgtjRZHO0
/tmp/.private/milosvasic/tmp.yyeQywXlX5
/tmp/.private/milosvasic/tmp.z2jmNRvj43
/tmp/.private/milosvasic/tmp.z3J3uuDOfk
/tmp/.private/milosvasic/tmp.z6JiUOZy13
/tmp/.private/milosvasic/tmp.z9xZEdLHyf
/tmp/.private/milosvasic/tmp.zDBPbX6YpA
/tmp/.private/milosvasic/tmp.zO2Gfxolf9
/tmp/.private/milosvasic/tmp.zWo3jawOj3
/tmp/.private/milosvasic/tmp.zYsqmUEpaT
/tmp/.private/milosvasic/tmp.zdF29lj8M8
/tmp/.private/milosvasic/tmp.zrYM3Yj2EV
/tmp/.private/milosvasic/tmp.zrmK66rEU3
/tmp/cma-color-1022316/proj
/tmp/cma-color2-1026250/proj
/tmp/cma-color3-1032220/proj
/tmp/cma-colortest-624526/proj
/tmp/cma-dbg-1028887/proj
/tmp/cma-dbg2-1030103/proj
/tmp/cma-e2e-232399/LegacyProj
/tmp/cma-e2e-232399/MyLiveProj
/tmp/cma-final-1102115/proj
/tmp/cma-nameprobe-176563/proj
/tmp/cma-probe-159271/proj
/tmp/xsess
/tmp/xsess2
EOF

# 524 paths, all confirmed non-existent. Purge in batches of 50.
xargs -a /tmp/lumen-dead-paths.txt -n 50 lumen purge
```

### 7.3 Tier 2 — DEAD real project path (1 dir, 0.1 MB)

```bash
# /home/milosvasic/Projects — 0.1 MB, last indexed 2026-06-28T09:53:08Z, index dir 0062e9326404910c
lumen purge /home/milosvasic/Projects
```

Sanity-check first: `/home/milosvasic/Projects` is a plausible former projects root on the internal `/home`
filesystem (mounted). It was last indexed 2026-06-28T09:53:08Z and the directory is absent. Projects now live under
`/run/media/milosvasic/DATA4TB/Projects/`, so this looks like a genuine relocation, not an unmounted volume.

### 7.4 Tier 3 — INCOMPLETE indexes (227 dirs, 22.1 MB) — NOT purgeable by path

`lumen purge <path>` **cannot** touch these (§6). Bare `lumen purge` would work but is forbidden — it destroys
everything. The only targeted option is direct removal of the index directories.

```bash
# PRECONDITION: no lumen indexer running (§7.0). An in-flight index is
# byte-for-byte indistinguishable from these until it completes --
# 06dd1f85fde5febb proved exactly that during this inventory.

# Re-derive the list at run time rather than trusting this file's snapshot,
# so a newly-aborted (or newly-started) index cannot be caught by a stale list.
cd ~/.local/share/lumen
for d in */; do
  d=${d%/}
  [ -f "$d/index.db" ] || continue
  pp=$(sqlite3 "file:$d/index.db?mode=ro" \
        "SELECT value FROM project_meta WHERE key='project_path';" 2>/dev/null)
  [ -z "$pp" ] && echo "$d"
done | tee /tmp/lumen-incomplete.txt | wc -l    # expect ~227

# Review the list, then:
# xargs -a /tmp/lumen-incomplete.txt -I{} rm -rf ~/.local/share/lumen/{}
```

The `rm -rf` line is left commented deliberately. 22.1 MB across 227 dirs is the smallest tier — the least payoff and
the highest chance of clipping a running index. Consider skipping it entirely.

### 7.5 Never run

```bash
lumen purge          # ← NO ARGUMENTS. Irreversible. Wipes every index,
                     #   including 21bf1507a8925bcf (the vasic rebuild),
                     #   boba (681.9 MB), lava (270.4 MB), and any index
                     #   currently being written. ~1.3 GB of live indexes
                     #   would need a full re-embed.
```

---

## 8. Duplicates

**Zero.** No `project_path` is recorded by more than one index directory. The 537 indexes that record a path map to
537 distinct paths, one-to-one.

The model-switch duplicate pattern the brief anticipated is absent, consistent with §1: a single embedding model
and a single vector dimensionality across the entire store.

---

## 9. Method

- Every `index.db` opened with `sqlite3.connect("file:<path>?mode=ro", uri=True)` plus `PRAGMA query_only=1`.
  No write handle was ever taken. The four in-flight DBs were read through this path safely.
- Sizes: byte-accurate `os.walk` + `lstat` per directory (includes `index.db`, `-wal`, `-shm`, `.lock`).
- Liveness: `os.path.exists(project_path)`.
- Mount state: `/proc/mounts`, `os.path.ismount()`, `lsblk`.
- In-flight detection: `ps`, `lsof +D`, and `/proc/<pid>/fd` — the step that caught `06dd1f85fde5febb`.
- `lumen purge` and `lumen index` were **not** run in any form. No file outside this report was created,
  modified, or deleted.

---

## Appendix A — all 525 DEAD indexes

Recorded `project_path` for each, so the operator can confirm each is genuinely gone. All verified non-existent
on mounted filesystems at inventory time.

| Index dir | Size (MB) | Files | Last indexed | Recorded project_path (absent) |
|---|---:|---:|---|---|
| `0062e9326404910c` | 0.1 | 0 | 2026-06-28T09:53:08 | `/home/milosvasic/Projects` |
| `93e0be39d2d441b6` | 0.1 | 0 | 2026-07-04T23:04:29 | `/tmp/.private/milosvasic/tmp.0IvWvhTGtC` |
| `721b0a291a1d12dd` | 3.1 | 1 | 2026-07-26T18:17:38 | `/tmp/.private/milosvasic/tmp.0J4Hgg6WXK` |
| `8f35d02501d97670` | 3.1 | 1 | 2026-07-26T18:17:41 | `/tmp/.private/milosvasic/tmp.0Oggx6IuEl` |
| `e2fb6c80a0efe988` | 0.1 | 0 | 2026-07-26T18:17:45 | `/tmp/.private/milosvasic/tmp.0dm71SJYE5` |
| `4c6633cdb4fe071b` | 0.1 | 0 | 2026-07-26T20:13:23 | `/tmp/.private/milosvasic/tmp.0opbsPzeIw` |
| `c75e2bf1fb684cdc` | 3.1 | 1 | 2026-07-26T20:32:04 | `/tmp/.private/milosvasic/tmp.0qiz4BxjCz` |
| `dc86e6d71158bfcf` | 0.1 | 0 | 2026-07-26T20:13:30 | `/tmp/.private/milosvasic/tmp.0qoPxbtWhc` |
| `f61d60c7a60565d7` | 0.1 | 0 | 2026-07-04T23:04:30 | `/tmp/.private/milosvasic/tmp.19RxbUEFBK` |
| `78b9fa70d0c02ac7` | 0.1 | 0 | 2026-07-26T18:01:58 | `/tmp/.private/milosvasic/tmp.1CXo0uK06j` |
| `776b8d4ba274e829` | 3.1 | 1 | 2026-07-26T20:40:34 | `/tmp/.private/milosvasic/tmp.1OwQq7tmGn` |
| `0475eb451028057f` | 0.1 | 0 | 2026-07-04T23:04:31 | `/tmp/.private/milosvasic/tmp.1YBpfUc4lH` |
| `0356037ef790e0b0` | 3.1 | 1 | 2026-07-26T12:58:19 | `/tmp/.private/milosvasic/tmp.1eKyQetVKd` |
| `1549a0ea0f5846de` | 3.1 | 1 | 2026-07-26T14:32:19 | `/tmp/.private/milosvasic/tmp.1zjlwkkCKf` |
| `bcb16c321a0cf9b0` | 0.1 | 0 | 2026-07-04T23:04:33 | `/tmp/.private/milosvasic/tmp.29o5eKoVrx` |
| `bd0c0ea0ccb8055f` | 0.1 | 0 | 2026-07-26T20:51:22 | `/tmp/.private/milosvasic/tmp.2DFvwGaSKG` |
| `5e3c2fdb2c6dc12a` | 0.1 | 0 | 2026-07-26T17:13:23 | `/tmp/.private/milosvasic/tmp.2DtnY8k5a2` |
| `07571856b323eda9` | 3.1 | 1 | 2026-07-26T20:52:05 | `/tmp/.private/milosvasic/tmp.2Ra7LjJYMo` |
| `0bafccd38745613e` | 3.1 | 1 | 2026-07-26T18:17:54 | `/tmp/.private/milosvasic/tmp.2WFbM2lAGz` |
| `135dfea954d44682` | 0.1 | 0 | 2026-07-26T18:17:55 | `/tmp/.private/milosvasic/tmp.2XVdQlqeYp` |
| `3119f80e3c0659d7` | 0.1 | 0 | 2026-07-04T23:04:35 | `/tmp/.private/milosvasic/tmp.2Z6QDvI3eT` |
| `9c0d85d430974447` | 3.1 | 1 | 2026-07-26T21:06:58 | `/tmp/.private/milosvasic/tmp.2aBAPmNU2o` |
| `259ccf689c4625ec` | 0.1 | 0 | 2026-07-26T20:14:21 | `/tmp/.private/milosvasic/tmp.2fk1sFayfE` |
| `53114d0522fd2967` | 3.1 | 2 | 2026-07-26T18:17:57 | `/tmp/.private/milosvasic/tmp.2idtDVOSv2` |
| `746691e9a91dcf55` | 3.1 | 1 | 2026-07-26T14:32:21 | `/tmp/.private/milosvasic/tmp.2ovpmsSi9L` |
| `27b55e43df298974` | 3.1 | 2 | 2026-07-26T20:33:36 | `/tmp/.private/milosvasic/tmp.324800akKg` |
| `a9703003b2b1e6b2` | 3.1 | 1 | 2026-07-26T18:17:59 | `/tmp/.private/milosvasic/tmp.3AuPGUo4uX` |
| `54ddd794c0c737eb` | 0.1 | 0 | 2026-06-29T19:23:51 | `/tmp/.private/milosvasic/tmp.3FeePFeihQ` |
| `71ccd67ccc5548a4` | 3.1 | 1 | 2026-07-26T18:18:00 | `/tmp/.private/milosvasic/tmp.3HTes9ySYu` |
| `9a1d1efba17d4e8a` | 3.1 | 1 | 2026-07-26T18:18:01 | `/tmp/.private/milosvasic/tmp.3OrtWk7QCl` |
| `27a0965fc91a4d28` | 3.1 | 1 | 2026-07-26T20:42:02 | `/tmp/.private/milosvasic/tmp.3aArywA7YA` |
| `dd98e6923d2e09c6` | 3.1 | 2 | 2026-07-26T18:18:02 | `/tmp/.private/milosvasic/tmp.3aNzj5zJxq` |
| `387dd55f9f27f8a2` | 0.1 | 0 | 2026-07-26T20:34:18 | `/tmp/.private/milosvasic/tmp.3naMrNbKJk` |
| `8962730331d98556` | 0.1 | 0 | 2026-07-26T20:42:25 | `/tmp/.private/milosvasic/tmp.3s2siPRpGO` |
| `951e4ba61392b6ca` | 0.1 | 0 | 2026-07-26T17:52:57 | `/tmp/.private/milosvasic/tmp.4BHS6FUFTz` |
| `11b0299d6a271436` | 3.1 | 1 | 2026-07-26T12:58:22 | `/tmp/.private/milosvasic/tmp.4IWedpbATt` |
| `b04c64efb7ad1147` | 3.1 | 1 | 2026-07-26T18:18:05 | `/tmp/.private/milosvasic/tmp.4Ry6BV9l6S` |
| `e424f92c3e47ca29` | 3.1 | 1 | 2026-07-26T17:14:41 | `/tmp/.private/milosvasic/tmp.4SQKFvhC2d` |
| `fdc50c33439287b7` | 3.1 | 1 | 2026-07-26T20:43:05 | `/tmp/.private/milosvasic/tmp.4UMmImXSsY` |
| `e5151e2d016a3c2e` | 3.1 | 2 | 2026-07-26T18:18:07 | `/tmp/.private/milosvasic/tmp.4Ywk9IBa4m` |
| `18f43c2263308d80` | 3.1 | 1 | 2026-07-26T18:18:08 | `/tmp/.private/milosvasic/tmp.4fLcYKb6cz` |
| `1a3f77bca2b00f81` | 3.1 | 1 | 2026-07-26T18:18:09 | `/tmp/.private/milosvasic/tmp.4iUz1ck45G` |
| `6af1b9aeb83390e9` | 0.1 | 0 | 2026-06-29T19:23:53 | `/tmp/.private/milosvasic/tmp.4lGuHhXQVA` |
| `4ef11fb94497219d` | 3.1 | 2 | 2026-07-26T18:18:11 | `/tmp/.private/milosvasic/tmp.51mClspO3t` |
| `13944dad36de9345` | 3.1 | 1 | 2026-07-26T20:59:55 | `/tmp/.private/milosvasic/tmp.52VwdEzGZl` |
| `d48c7f2bb476766d` | 3.1 | 1 | 2026-07-26T20:16:04 | `/tmp/.private/milosvasic/tmp.58zavFOlAf` |
| `e989ca880a988f98` | 3.1 | 1 | 2026-07-26T20:16:06 | `/tmp/.private/milosvasic/tmp.5D0ODih5Z0` |
| `11165987e1882adf` | 0.1 | 0 | 2026-07-26T20:23:52 | `/tmp/.private/milosvasic/tmp.5Dub3XtiMO` |
| `10331bf7faba2f3f` | 3.1 | 1 | 2026-07-26T20:16:09 | `/tmp/.private/milosvasic/tmp.5KiuoWIoBr` |
| `5a02b41ac29260b3` | 0.1 | 0 | 2026-07-26T18:18:12 | `/tmp/.private/milosvasic/tmp.5MmvuZ3iK2` |
| `e2a4bb560300bdc6` | 3.1 | 1 | 2026-07-26T18:18:13 | `/tmp/.private/milosvasic/tmp.5Oeqe11zNr` |
| `5c94120662b82670` | 0.1 | 0 | 2026-07-26T17:53:01 | `/tmp/.private/milosvasic/tmp.5kOWTflmtU` |
| `98bd5ab242f6dc72` | 3.1 | 2 | 2026-07-26T14:32:25 | `/tmp/.private/milosvasic/tmp.5urDr6jZng` |
| `272ec64757305dd4` | 3.1 | 1 | 2026-07-26T20:16:20 | `/tmp/.private/milosvasic/tmp.5wYv9sh901` |
| `f7383bb61465e980` | 0.1 | 0 | 2026-07-26T20:16:22 | `/tmp/.private/milosvasic/tmp.5wo0wZ5Sl1` |
| `9bf3413d50424197` | 3.1 | 1 | 2026-07-26T20:16:23 | `/tmp/.private/milosvasic/tmp.607VQxL42C` |
| `480dffeffc833e49` | 0.1 | 0 | 2026-07-26T14:32:28 | `/tmp/.private/milosvasic/tmp.64vk2O8OTD` |
| `0e8d463203b2657d` | 0.1 | 0 | 2026-07-26T21:23:39 | `/tmp/.private/milosvasic/tmp.6GFXHSW3Rz` |
| `d7907708faf4c214` | 0.1 | 0 | 2026-07-26T17:53:04 | `/tmp/.private/milosvasic/tmp.6O1X15aZjF` |
| `3a6bcdf59b237f88` | 0.1 | 0 | 2026-07-26T20:37:52 | `/tmp/.private/milosvasic/tmp.6SX0d58p8D` |
| `5599c21e11ba5ffd` | 0.1 | 0 | 2026-07-26T20:16:32 | `/tmp/.private/milosvasic/tmp.6eXUwEksYr` |
| `48bc7cb83861fc13` | 0.1 | 0 | 2026-07-26T12:58:25 | `/tmp/.private/milosvasic/tmp.6k4dsIEw3V` |
| `52b26deb07c02ad0` | 3.1 | 1 | 2026-07-26T18:18:18 | `/tmp/.private/milosvasic/tmp.6k4wOPSjAr` |
| `d7e9e179a6e84ea4` | 3.1 | 1 | 2026-07-26T18:55:36 | `/tmp/.private/milosvasic/tmp.6t2i5dB0dB` |
| `8c33312dcddf0b68` | 3.1 | 1 | 2026-07-26T12:58:29 | `/tmp/.private/milosvasic/tmp.6wePAMrCCd` |
| `8d024e33b67d8350` | 3.1 | 1 | 2026-07-26T18:18:20 | `/tmp/.private/milosvasic/tmp.74OwIKvK6H` |
| `658e2be932640013` | 3.1 | 1 | 2026-07-26T21:25:01 | `/tmp/.private/milosvasic/tmp.7G5kTaeBZ4` |
| `49d7487627f4a0b7` | 3.1 | 2 | 2026-07-26T18:18:21 | `/tmp/.private/milosvasic/tmp.7J0pV0CKHu` |
| `7ccda7aaaa3552c2` | 0.1 | 0 | 2026-07-26T20:26:45 | `/tmp/.private/milosvasic/tmp.7KclkKM1TH` |
| `9979f00218de6dbe` | 0.1 | 0 | 2026-07-26T18:18:22 | `/tmp/.private/milosvasic/tmp.7UslVwapBb` |
| `112ea56af141f50b` | 3.1 | 1 | 2026-07-26T18:18:23 | `/tmp/.private/milosvasic/tmp.7eckFiaosr` |
| `f14ac12b29290e8f` | 0.1 | 0 | 2026-07-04T23:04:39 | `/tmp/.private/milosvasic/tmp.7pLreu1krU` |
| `0d24063112e5b783` | 3.1 | 1 | 2026-07-26T20:17:14 | `/tmp/.private/milosvasic/tmp.7qqFATVZZ0` |
| `ff0a51c585e04d52` | 0.1 | 0 | 2026-07-26T20:17:18 | `/tmp/.private/milosvasic/tmp.7sCkFgMyNs` |
| `89a0806f2a3ab906` | 3.1 | 1 | 2026-07-26T18:55:57 | `/tmp/.private/milosvasic/tmp.7umwkiFLrq` |
| `c5898a7c3526e78c` | 3.1 | 2 | 2026-07-26T18:18:25 | `/tmp/.private/milosvasic/tmp.89o66vsdnL` |
| `cb4adf15159c1fb1` | 3.1 | 2 | 2026-07-26T18:56:04 | `/tmp/.private/milosvasic/tmp.8GFSdTZoBA` |
| `0483a5cd64a52c6e` | 3.1 | 1 | 2026-07-26T20:27:36 | `/tmp/.private/milosvasic/tmp.8XhBWPFChO` |
| `723f1e54d32da848` | 3.1 | 1 | 2026-07-26T20:17:26 | `/tmp/.private/milosvasic/tmp.8c7ue5SYzz` |
| `94a08e6cbcb8b35d` | 0.1 | 0 | 2026-07-26T17:24:16 | `/tmp/.private/milosvasic/tmp.8d20cv0aiz` |
| `8bda21c37068931e` | 0.1 | 0 | 2026-07-26T18:18:26 | `/tmp/.private/milosvasic/tmp.8mjMuRmtm4` |
| `34e8bec3b3cb4bd7` | 3.1 | 1 | 2026-07-26T14:32:38 | `/tmp/.private/milosvasic/tmp.8uqMY4HGDB` |
| `7a68f694192d090e` | 3.1 | 1 | 2026-07-26T20:17:44 | `/tmp/.private/milosvasic/tmp.8yGVffe8U0` |
| `6ff5a5ac3478150f` | 0.1 | 0 | 2026-07-04T23:04:41 | `/tmp/.private/milosvasic/tmp.90lBMyoCIx` |
| `1bd92fa41a37a19a` | 3.1 | 1 | 2026-07-26T20:17:50 | `/tmp/.private/milosvasic/tmp.96Mz5XEkKz` |
| `52a8f4822304875f` | 3.1 | 2 | 2026-07-26T20:17:56 | `/tmp/.private/milosvasic/tmp.9S5sLXmH5P` |
| `04bc73d43663b3bf` | 3.1 | 1 | 2026-07-26T12:58:32 | `/tmp/.private/milosvasic/tmp.9b7YOzjm6I` |
| `8b005b3b46cdc8a5` | 3.1 | 1 | 2026-07-26T12:58:34 | `/tmp/.private/milosvasic/tmp.9eCNAjxclM` |
| `498f3664a1406875` | 3.1 | 2 | 2026-07-26T20:18:09 | `/tmp/.private/milosvasic/tmp.9qPw7PwXDp` |
| `2d8c070a32bd68e1` | 0.1 | 0 | 2026-07-26T20:28:33 | `/tmp/.private/milosvasic/tmp.9wr2TVZOGX` |
| `729a47e1b8ec22ca` | 3.1 | 1 | 2026-07-26T18:18:30 | `/tmp/.private/milosvasic/tmp.9wzsT75y7S` |
| `55c9fb7e0e4b6983` | 3.1 | 1 | 2026-07-26T18:18:31 | `/tmp/.private/milosvasic/tmp.9xqbdHh1u3` |
| `c33f432ed83298eb` | 0.1 | 0 | 2026-07-26T18:02:35 | `/tmp/.private/milosvasic/tmp.A3zaSlAoxi` |
| `22b7a5fbaffa6923` | 0.1 | 0 | 2026-07-26T20:18:20 | `/tmp/.private/milosvasic/tmp.AHuONfW5jS` |
| `f32b1bc32cad9335` | 3.1 | 1 | 2026-07-26T18:18:33 | `/tmp/.private/milosvasic/tmp.AWP5WRvPIb` |
| `0b97e14dee032254` | 3.1 | 1 | 2026-07-26T21:29:42 | `/tmp/.private/milosvasic/tmp.AtiqqFAk8s` |
| `67282aff3ba0587e` | 3.1 | 1 | 2026-07-26T20:47:56 | `/tmp/.private/milosvasic/tmp.B4U9Qst9Vq` |
| `0289aee246bb4ef0` | 3.1 | 2 | 2026-07-26T18:56:34 | `/tmp/.private/milosvasic/tmp.B85zEfpw25` |
| `b43501ec2bcdbcd0` | 3.1 | 2 | 2026-07-26T20:18:33 | `/tmp/.private/milosvasic/tmp.BCjV7eTE37` |
| `21d0414be31d31fc` | 3.1 | 1 | 2026-07-26T20:18:32 | `/tmp/.private/milosvasic/tmp.BJ0HMypRYk` |
| `3f0ab61792fc64fe` | 0.1 | 0 | 2026-07-04T23:04:47 | `/tmp/.private/milosvasic/tmp.BX2tEp8SbL` |
| `6a72b978ca929bbb` | 0.1 | 0 | 2026-06-29T19:23:58 | `/tmp/.private/milosvasic/tmp.BbiBu4txd9` |
| `89aa223a18e51101` | 0.1 | 0 | 2026-06-29T19:23:59 | `/tmp/.private/milosvasic/tmp.BcubaEOAxc` |
| `2912cf65c0dbb352` | 3.1 | 2 | 2026-07-26T12:58:36 | `/tmp/.private/milosvasic/tmp.Bj9CggcxAV` |
| `11d0370b7f2f62b3` | 0.1 | 0 | 2026-07-26T21:31:24 | `/tmp/.private/milosvasic/tmp.BmnFObLjhG` |
| `ddaac465f07c4ab2` | 3.1 | 1 | 2026-07-26T21:31:40 | `/tmp/.private/milosvasic/tmp.BxOa6XNFGs` |
| `cde02fc8df480b63` | 3.1 | 1 | 2026-07-26T20:18:46 | `/tmp/.private/milosvasic/tmp.CRTTpcgTQv` |
| `fe5c40201d2a996f` | 0.1 | 0 | 2026-07-04T23:04:50 | `/tmp/.private/milosvasic/tmp.CzRtbl8PUO` |
| `c6139082c5a7200f` | 3.1 | 1 | 2026-07-26T18:18:35 | `/tmp/.private/milosvasic/tmp.DArB4IKhrl` |
| `cd1ab938cdfa9c89` | 3.1 | 1 | 2026-07-26T21:32:09 | `/tmp/.private/milosvasic/tmp.DBpdmliEcH` |
| `548a0c08602b23e4` | 0.1 | 0 | 2026-07-04T23:04:50 | `/tmp/.private/milosvasic/tmp.DCSsx819w2` |
| `6a297eacead1e568` | 3.1 | 1 | 2026-07-26T18:18:36 | `/tmp/.private/milosvasic/tmp.DLm4dI078H` |
| `03f9ea8943a0bae6` | 0.1 | 0 | 2026-07-26T20:29:37 | `/tmp/.private/milosvasic/tmp.DP6qqJfqS6` |
| `9ad0f647a6128c69` | 0.1 | 0 | 2026-07-26T20:19:12 | `/tmp/.private/milosvasic/tmp.Da0dgzD4k4` |
| `3b35bd4dab4f3f70` | 3.1 | 1 | 2026-07-26T21:00:03 | `/tmp/.private/milosvasic/tmp.DnpzA7EzGF` |
| `6847d907ca858933` | 3.1 | 1 | 2026-07-26T20:19:25 | `/tmp/.private/milosvasic/tmp.DpGto5jreI` |
| `e7f6cbf03bc67d5b` | 0.1 | 0 | 2026-07-26T21:33:50 | `/tmp/.private/milosvasic/tmp.DyrpdnaXJj` |
| `e856dd6c8ed0fa9a` | 0.1 | 0 | 2026-07-26T21:00:22 | `/tmp/.private/milosvasic/tmp.ENnDgPbNCi` |
| `bc40bbb9d1e8f37d` | 0.1 | 0 | 2026-07-26T21:00:29 | `/tmp/.private/milosvasic/tmp.ET1oNeeTjL` |
| `8910350bf435b05d` | 3.1 | 1 | 2026-07-26T21:20:19 | `/tmp/.private/milosvasic/tmp.EZgXQwQEV7` |
| `6543e2f46c7f6f90` | 3.1 | 1 | 2026-07-26T21:00:33 | `/tmp/.private/milosvasic/tmp.Eji05C7BHi` |
| `5778c12ce6877c3e` | 3.1 | 2 | 2026-07-26T18:18:37 | `/tmp/.private/milosvasic/tmp.EkjFclX72L` |
| `129026a7499572ec` | 0.1 | 0 | 2026-07-26T21:21:21 | `/tmp/.private/milosvasic/tmp.EmA3MnxHvQ` |
| `6932c4b0f24c47bd` | 0.1 | 0 | 2026-06-29T19:24:03 | `/tmp/.private/milosvasic/tmp.F1fk7NEh50` |
| `5a4296ca01826b21` | 3.1 | 1 | 2026-07-26T18:18:38 | `/tmp/.private/milosvasic/tmp.F9emslQ5l5` |
| `544d5c8346e35db1` | 3.1 | 1 | 2026-07-26T21:22:06 | `/tmp/.private/milosvasic/tmp.FC214dsbvk` |
| `8b6f75120ca314f0` | 3.1 | 1 | 2026-07-26T18:18:39 | `/tmp/.private/milosvasic/tmp.FISFQQfGGK` |
| `0868f305eb6945c6` | 0.1 | 0 | 2026-07-04T23:04:53 | `/tmp/.private/milosvasic/tmp.FQAv7kCFPG` |
| `a880e2a6e1ddf2e9` | 3.1 | 1 | 2026-07-26T20:30:28 | `/tmp/.private/milosvasic/tmp.FQkxArbyiY` |
| `fca61bd0455ed1cc` | 3.1 | 1 | 2026-07-26T14:32:44 | `/tmp/.private/milosvasic/tmp.FVxoAPjsgl` |
| `2ec2d6d6423d1dd0` | 3.1 | 1 | 2026-07-26T18:18:41 | `/tmp/.private/milosvasic/tmp.FeYytiIaVF` |
| `6b6b73c9bfa45066` | 0.1 | 0 | 2026-07-26T21:01:36 | `/tmp/.private/milosvasic/tmp.FslkqBQrpS` |
| `d9728f6944475682` | 0.1 | 0 | 2026-07-26T17:18:14 | `/tmp/.private/milosvasic/tmp.Ft1S9ur6MP` |
| `ecdb5afaf9c606d0` | 3.1 | 1 | 2026-07-26T12:58:37 | `/tmp/.private/milosvasic/tmp.GFcovxR6Or` |
| `c7c9b29c2f920423` | 0.1 | 0 | 2026-07-04T23:04:56 | `/tmp/.private/milosvasic/tmp.GIygnTMIPl` |
| `f55eef6d6eaae5b4` | 0.1 | 0 | 2026-07-26T18:57:13 | `/tmp/.private/milosvasic/tmp.GR58nJsQQZ` |
| `53d2666ab1b10d35` | 3.1 | 1 | 2026-07-26T20:21:10 | `/tmp/.private/milosvasic/tmp.GTmYybChPV` |
| `3194afa09bb4a706` | 3.1 | 1 | 2026-07-26T18:18:44 | `/tmp/.private/milosvasic/tmp.GVR5aVA2r0` |
| `d25e718b65020611` | 0.1 | 0 | 2026-07-26T20:54:24 | `/tmp/.private/milosvasic/tmp.GYpQhKlxQS` |
| `48c6240dcb7814b0` | 0.1 | 0 | 2026-07-04T23:04:56 | `/tmp/.private/milosvasic/tmp.GZge1GMaKP` |
| `857471b6d95b208d` | 3.1 | 1 | 2026-07-26T20:55:05 | `/tmp/.private/milosvasic/tmp.Gt2GP3ibJZ` |
| `ef00e2a62badab1d` | 3.1 | 1 | 2026-07-26T18:18:45 | `/tmp/.private/milosvasic/tmp.GyfnfTqzjW` |
| `5a3292f4dcbd3381` | 0.1 | 0 | 2026-07-26T12:58:38 | `/tmp/.private/milosvasic/tmp.H3uakg9JHy` |
| `da0ae5c192e13c35` | 3.1 | 1 | 2026-07-26T21:39:44 | `/tmp/.private/milosvasic/tmp.Hapfon2jqO` |
| `24f90c9c81819ad2` | 0.1 | 0 | 2026-07-26T18:18:47 | `/tmp/.private/milosvasic/tmp.Hi0ugDkjjo` |
| `ed64fbcf12505c79` | 3.1 | 1 | 2026-07-26T21:36:44 | `/tmp/.private/milosvasic/tmp.HlAaHLGRB1` |
| `887058fbfe2d6c6b` | 0.1 | 0 | 2026-07-04T23:05:01 | `/tmp/.private/milosvasic/tmp.I314YcMUSu` |
| `fdf5d0cad4ca3bd0` | 3.1 | 1 | 2026-07-26T18:18:48 | `/tmp/.private/milosvasic/tmp.I7T0CBgL9w` |
| `f5171b16da6bf1e4` | 0.1 | 0 | 2026-07-04T23:05:02 | `/tmp/.private/milosvasic/tmp.ICq9gBrXyU` |
| `1f4aac79c1694c09` | 3.1 | 2 | 2026-07-26T18:18:49 | `/tmp/.private/milosvasic/tmp.IDPxDKwT0X` |
| `7b71873522e18775` | 3.1 | 1 | 2026-07-26T18:18:50 | `/tmp/.private/milosvasic/tmp.IJxbHvJ8VS` |
| `0191bb1eccd8cf77` | 3.1 | 1 | 2026-07-26T18:18:51 | `/tmp/.private/milosvasic/tmp.IVP5aXoSOH` |
| `8d9e8d5b33ba5295` | 3.1 | 1 | 2026-07-26T18:18:52 | `/tmp/.private/milosvasic/tmp.Idccj4y7De` |
| `da300c5d274cb22d` | 3.1 | 2 | 2026-07-26T20:22:24 | `/tmp/.private/milosvasic/tmp.IekkAYeguq` |
| `f7dd1a8e3ebd791d` | 0.1 | 0 | 2026-07-26T12:58:39 | `/tmp/.private/milosvasic/tmp.IjEXtoXUEJ` |
| `a8bdfcf67a234a35` | 3.1 | 1 | 2026-07-26T18:18:54 | `/tmp/.private/milosvasic/tmp.IoJ983i2QN` |
| `ea642748c8aaf3c7` | 3.1 | 2 | 2026-07-26T20:22:46 | `/tmp/.private/milosvasic/tmp.Izkb7vpyWg` |
| `b71a643294e6e18a` | 0.1 | 0 | 2026-07-26T18:02:53 | `/tmp/.private/milosvasic/tmp.J34yfXmSsN` |
| `efd1a5a63bef7a76` | 3.1 | 2 | 2026-07-26T18:18:56 | `/tmp/.private/milosvasic/tmp.JCH1zWGNRI` |
| `b67da54f6e2ebfa9` | 3.1 | 1 | 2026-07-26T18:18:57 | `/tmp/.private/milosvasic/tmp.JNmeqiSMwR` |
| `fec4abd2655022e9` | 3.1 | 2 | 2026-07-26T21:29:37 | `/tmp/.private/milosvasic/tmp.JWckZVNQVZ` |
| `5bf5b9e17a5515e4` | 3.1 | 2 | 2026-07-26T20:23:29 | `/tmp/.private/milosvasic/tmp.JXRHCreuVf` |
| `078841321b2899ed` | 3.1 | 1 | 2026-07-26T20:23:40 | `/tmp/.private/milosvasic/tmp.JZMiHXahnW` |
| `618e1d31b83a7a4b` | 3.1 | 2 | 2026-07-26T14:32:49 | `/tmp/.private/milosvasic/tmp.JaA5Qq9aa5` |
| `eee71743caba759d` | 3.1 | 1 | 2026-07-26T21:45:15 | `/tmp/.private/milosvasic/tmp.JbkaEbGLXH` |
| `2bfe395f48a93ed8` | 0.1 | 0 | 2026-07-26T21:40:42 | `/tmp/.private/milosvasic/tmp.JoYdnvPoEO` |
| `e0958da2486d1e90` | 3.1 | 1 | 2026-07-26T18:18:59 | `/tmp/.private/milosvasic/tmp.JtUf9Zl1it` |
| `3eed1c5b0bfc20c8` | 0.1 | 0 | 2026-07-04T23:05:05 | `/tmp/.private/milosvasic/tmp.K5h1LImlTr` |
| `633534e7c99e96a7` | 0.1 | 0 | 2026-07-26T21:46:52 | `/tmp/.private/milosvasic/tmp.KKcG4rRfU6` |
| `82ae01bb5d4dae75` | 0.1 | 0 | 2026-07-04T23:05:07 | `/tmp/.private/milosvasic/tmp.KPKQvEzhhP` |
| `98620159f4c42943` | 0.1 | 0 | 2026-07-04T23:05:08 | `/tmp/.private/milosvasic/tmp.KVW73QhuAL` |
| `fd82a2b2fc4cfe40` | 0.1 | 0 | 2026-07-26T21:01:21 | `/tmp/.private/milosvasic/tmp.KZzWkUEVRn` |
| `4611e71120b8032a` | 3.1 | 1 | 2026-07-26T18:19:00 | `/tmp/.private/milosvasic/tmp.KgVvXrZYaD` |
| `6fd9d35b62a893d9` | 3.1 | 1 | 2026-07-26T21:50:19 | `/tmp/.private/milosvasic/tmp.KrSxAwDS0T` |
| `7918886320f650e4` | 3.1 | 1 | 2026-07-26T20:24:22 | `/tmp/.private/milosvasic/tmp.L3DzT1pfD6` |
| `1cf09dabfebd4ffa` | 0.1 | 0 | 2026-07-04T23:05:09 | `/tmp/.private/milosvasic/tmp.LBynsZaLfM` |
| `0d3471ee05d85215` | 0.1 | 0 | 2026-07-04T23:05:10 | `/tmp/.private/milosvasic/tmp.LZOP3k5l2n` |
| `327ca2ac19fc97ad` | 3.1 | 1 | 2026-07-26T21:42:03 | `/tmp/.private/milosvasic/tmp.Ld7OCfjZ21` |
| `38f465e1d68d718c` | 0.1 | 0 | 2026-07-26T18:19:01 | `/tmp/.private/milosvasic/tmp.LdrRe9Bkbk` |
| `02011d8b05db8e4a` | 3.1 | 1 | 2026-07-26T18:19:02 | `/tmp/.private/milosvasic/tmp.Llwop4kAk8` |
| `4490656c006866d9` | 3.1 | 2 | 2026-07-26T21:13:27 | `/tmp/.private/milosvasic/tmp.Lxso9jdrjA` |
| `2a700560f6b6af60` | 3.1 | 1 | 2026-07-26T18:19:03 | `/tmp/.private/milosvasic/tmp.M2tbI9V7an` |
| `66c6cc9cd95bfb08` | 0.1 | 0 | 2026-07-26T21:14:04 | `/tmp/.private/milosvasic/tmp.M5MJ9tse5k` |
| `848a67640f645167` | 3.1 | 1 | 2026-07-26T18:19:04 | `/tmp/.private/milosvasic/tmp.MSyDEaLffg` |
| `0ad5dd1282b0bf23` | 3.1 | 1 | 2026-07-26T18:19:05 | `/tmp/.private/milosvasic/tmp.Mc5qpGf5I6` |
| `d3639f4e0da5b173` | 0.1 | 0 | 2026-07-26T12:58:40 | `/tmp/.private/milosvasic/tmp.MnVOq3Tqvk` |
| `ead0c0fd3508fa07` | 3.1 | 1 | 2026-07-26T21:04:24 | `/tmp/.private/milosvasic/tmp.MnXhi7kgNk` |
| `708b562333a0f175` | 3.1 | 1 | 2026-07-26T20:25:23 | `/tmp/.private/milosvasic/tmp.MqVxJ0zEEV` |
| `795d156799203ff5` | 0.1 | 0 | 2026-07-26T20:25:33 | `/tmp/.private/milosvasic/tmp.MyoNLtDkFF` |
| `6996b5f00cc7e154` | 0.1 | 0 | 2026-07-26T17:53:32 | `/tmp/.private/milosvasic/tmp.MzucfzvA3F` |
| `0fa1d50e7a51604c` | 0.1 | 0 | 2026-07-26T17:32:56 | `/tmp/.private/milosvasic/tmp.NK0F0HU5Dn` |
| `782643c53dc9cc05` | 3.1 | 1 | 2026-07-26T21:06:09 | `/tmp/.private/milosvasic/tmp.NgBmcPVj1c` |
| `60ebe58dd5406491` | 3.1 | 1 | 2026-07-26T14:32:51 | `/tmp/.private/milosvasic/tmp.Nl5yKBl25a` |
| `7d51e4a62c645a65` | 0.1 | 0 | 2026-07-26T18:19:10 | `/tmp/.private/milosvasic/tmp.NoIHW7guZw` |
| `9ebfa676e65c8faa` | 0.1 | 0 | 2026-07-04T23:05:12 | `/tmp/.private/milosvasic/tmp.NpX5dsD0sw` |
| `8099e2cfdb3b8044` | 3.1 | 1 | 2026-07-26T18:19:11 | `/tmp/.private/milosvasic/tmp.O3ZSjJ2rJo` |
| `d332d785cfacd98d` | 0.1 | 0 | 2026-06-29T19:24:09 | `/tmp/.private/milosvasic/tmp.O54g3z97Z4` |
| `5261f167e656c757` | 3.1 | 1 | 2026-07-26T14:32:52 | `/tmp/.private/milosvasic/tmp.OEVfRubU3k` |
| `07f665aa5aab35e0` | 3.1 | 1 | 2026-07-26T18:58:32 | `/tmp/.private/milosvasic/tmp.OKtofyIo3W` |
| `eee17027e4bb1aaa` | 3.1 | 1 | 2026-07-26T20:26:58 | `/tmp/.private/milosvasic/tmp.OYsJysznvt` |
| `40f3f8e693006032` | 3.1 | 1 | 2026-07-26T12:58:41 | `/tmp/.private/milosvasic/tmp.ObgmN5ojcd` |
| `2ff9c43b4b482f29` | 3.1 | 1 | 2026-07-26T20:27:19 | `/tmp/.private/milosvasic/tmp.OmuOpGs8Wm` |
| `3d0c3cd70ae28352` | 3.1 | 1 | 2026-07-26T18:19:14 | `/tmp/.private/milosvasic/tmp.Oubi8a0mfL` |
| `0b348c5401cfb43e` | 0.1 | 0 | 2026-06-29T19:24:10 | `/tmp/.private/milosvasic/tmp.OwQPabPmcL` |
| `b4da93bbb93155bd` | 0.1 | 0 | 2026-07-26T18:58:40 | `/tmp/.private/milosvasic/tmp.P2EqsjWiO4` |
| `78a14ca3887f52be` | 0.1 | 0 | 2026-07-04T23:05:15 | `/tmp/.private/milosvasic/tmp.P3Z786Hlhs` |
| `46528e0f3996a88c` | 3.1 | 1 | 2026-07-26T21:53:55 | `/tmp/.private/milosvasic/tmp.P4IYlzRhWr` |
| `4c9ac3f8a294eca1` | 0.1 | 0 | 2026-07-26T17:33:01 | `/tmp/.private/milosvasic/tmp.P6ss3qCY34` |
| `2dfcce4435feb073` | 0.1 | 0 | 2026-07-26T20:34:51 | `/tmp/.private/milosvasic/tmp.P7ZOwUV0fN` |
| `fa9c31f49a6a84c6` | 3.1 | 1 | 2026-07-26T12:58:42 | `/tmp/.private/milosvasic/tmp.PSQd21GFCr` |
| `40e3548baaf7b47b` | 3.1 | 1 | 2026-07-26T22:04:51 | `/tmp/.private/milosvasic/tmp.PfjChiwwmX` |
| `465eb5e42fd8f13e` | 0.1 | 0 | 2026-07-26T18:03:10 | `/tmp/.private/milosvasic/tmp.PjRRlL9hJt` |
| `a7d31f31d1d6eed4` | 3.1 | 1 | 2026-07-26T20:28:23 | `/tmp/.private/milosvasic/tmp.Pr5iMHF6hG` |
| `bb11cf32259812ff` | 0.1 | 0 | 2026-07-04T23:05:17 | `/tmp/.private/milosvasic/tmp.PwBS9Imur8` |
| `21c082cf7812c811` | 3.1 | 1 | 2026-07-26T18:58:53 | `/tmp/.private/milosvasic/tmp.PwXmhylZrl` |
| `c4e2ca0649786d61` | 3.1 | 1 | 2026-07-26T18:58:55 | `/tmp/.private/milosvasic/tmp.QQjL4kglRm` |
| `d23a4b778ab01fa3` | 0.1 | 0 | 2026-07-26T20:28:46 | `/tmp/.private/milosvasic/tmp.QXMOseuaRv` |
| `348b7397e2ed6bb5` | 0.1 | 0 | 2026-07-04T23:05:19 | `/tmp/.private/milosvasic/tmp.QZyAJL2VC5` |
| `d7c01742c9d22fb2` | 3.1 | 1 | 2026-07-26T20:28:54 | `/tmp/.private/milosvasic/tmp.QhnpTEMvkx` |
| `e07f7c229d57fa16` | 3.1 | 1 | 2026-07-26T18:19:17 | `/tmp/.private/milosvasic/tmp.QipPxwIBU2` |
| `4586d6a90573a865` | 0.1 | 0 | 2026-07-26T18:58:58 | `/tmp/.private/milosvasic/tmp.QmZrNXj0XO` |
| `a0d1cb54cb145864` | 0.1 | 0 | 2026-06-29T19:24:11 | `/tmp/.private/milosvasic/tmp.QnNW9TpmgS` |
| `e2cc1d377b5d30e8` | 3.1 | 1 | 2026-07-26T14:32:56 | `/tmp/.private/milosvasic/tmp.RBGzLd72FT` |
| `c8265e06e57f6edc` | 0.1 | 0 | 2026-07-04T23:05:21 | `/tmp/.private/milosvasic/tmp.RBq3bCO2u7` |
| `33c1988a60776ea2` | 0.1 | 0 | 2026-07-26T22:08:00 | `/tmp/.private/milosvasic/tmp.RDzNI3FgVn` |
| `82c6526af3370fce` | 3.1 | 2 | 2026-07-26T20:36:00 | `/tmp/.private/milosvasic/tmp.RNgN0d36nH` |
| `4806f214f8c478e5` | 0.1 | 0 | 2026-07-04T23:05:22 | `/tmp/.private/milosvasic/tmp.ROzxfAz0IE` |
| `4e30af01a8278ee5` | 0.1 | 0 | 2026-07-26T20:36:00 | `/tmp/.private/milosvasic/tmp.RVV5yR6LwI` |
| `16334118ed6f3e49` | 3.1 | 1 | 2026-07-26T18:19:19 | `/tmp/.private/milosvasic/tmp.RWlN7wvLuo` |
| `ee7716923ba4c8e0` | 3.1 | 1 | 2026-07-26T20:29:12 | `/tmp/.private/milosvasic/tmp.RleDBwWJpy` |
| `6c9346a1b2656cf9` | 3.1 | 1 | 2026-07-26T18:19:20 | `/tmp/.private/milosvasic/tmp.Ry0xVwCsVM` |
| `2e58c7379c6279b0` | 0.1 | 0 | 2026-07-26T20:29:21 | `/tmp/.private/milosvasic/tmp.S8VGFV7aqE` |
| `135386cf53d91a01` | 3.1 | 1 | 2026-07-26T20:29:25 | `/tmp/.private/milosvasic/tmp.SC52F1ilp5` |
| `24c6a90027f0cb18` | 3.1 | 1 | 2026-07-26T18:19:21 | `/tmp/.private/milosvasic/tmp.SEesDgRUMn` |
| `277b858df26c6571` | 0.1 | 0 | 2026-07-26T17:53:42 | `/tmp/.private/milosvasic/tmp.SSIURCp4DO` |
| `7a21958b61614372` | 3.1 | 2 | 2026-07-26T22:08:40 | `/tmp/.private/milosvasic/tmp.SeA4XbTC8A` |
| `a24c15ffa5083fc0` | 3.1 | 1 | 2026-07-26T18:19:23 | `/tmp/.private/milosvasic/tmp.SlyFnT7l5f` |
| `16ec08f308512215` | 3.1 | 1 | 2026-07-26T18:19:24 | `/tmp/.private/milosvasic/tmp.SoGB5UZbnm` |
| `c40bf394df10084e` | 3.1 | 2 | 2026-07-26T20:29:47 | `/tmp/.private/milosvasic/tmp.SyEjDkFjLl` |
| `ee5513770eeba705` | 3.1 | 1 | 2026-07-26T21:19:16 | `/tmp/.private/milosvasic/tmp.T3rUogCeYl` |
| `b87bd11ca8e1f36b` | 3.1 | 1 | 2026-07-26T21:45:11 | `/tmp/.private/milosvasic/tmp.T7sUdUvmCr` |
| `149f304d47a35a3a` | 0.1 | 0 | 2026-07-26T17:18:34 | `/tmp/.private/milosvasic/tmp.T9fgZzZb0J` |
| `1636c68c11080f07` | 3.1 | 1 | 2026-07-26T22:12:09 | `/tmp/.private/milosvasic/tmp.TKG8xxNeTD` |
| `feb9ab390193a879` | 3.1 | 1 | 2026-07-26T22:12:10 | `/tmp/.private/milosvasic/tmp.TRfMR2AgfU` |
| `6683911de77e684a` | 3.1 | 1 | 2026-07-26T20:29:55 | `/tmp/.private/milosvasic/tmp.TUCAGOHNbm` |
| `5de91ec2627d08e6` | 0.1 | 0 | 2026-07-04T23:05:25 | `/tmp/.private/milosvasic/tmp.Tqasgu8J85` |
| `4a0e64b86e13f476` | 3.1 | 1 | 2026-07-26T18:19:26 | `/tmp/.private/milosvasic/tmp.TqqkPBNre8` |
| `1c2454c3354d847f` | 0.1 | 0 | 2026-07-26T17:18:35 | `/tmp/.private/milosvasic/tmp.U618SD8Fa7` |
| `dd01cdab4ada5a36` | 3.1 | 1 | 2026-07-26T20:30:06 | `/tmp/.private/milosvasic/tmp.U8TzNVt4hN` |
| `7f44cc0309d3734e` | 3.1 | 1 | 2026-07-26T22:19:34 | `/tmp/.private/milosvasic/tmp.UGw7ciIb1S` |
| `c1817e0371571626` | 0.1 | 0 | 2026-07-04T23:05:26 | `/tmp/.private/milosvasic/tmp.UHaZ6BKrrH` |
| `b273aaab0303eaec` | 3.1 | 1 | 2026-07-26T21:27:38 | `/tmp/.private/milosvasic/tmp.UP0CA7vxY1` |
| `64d4f4c849beb06d` | 0.1 | 0 | 2026-07-26T21:48:29 | `/tmp/.private/milosvasic/tmp.Uh1gTjniAs` |
| `04581583ea2eba9d` | 0.1 | 0 | 2026-07-26T18:03:20 | `/tmp/.private/milosvasic/tmp.UkdXCROAr1` |
| `5b9b0e6a3b0701f5` | 0.1 | 0 | 2026-07-26T17:18:36 | `/tmp/.private/milosvasic/tmp.Ul4a9JX5Gv` |
| `0c6630acd81c145b` | 0.1 | 0 | 2026-07-26T20:37:44 | `/tmp/.private/milosvasic/tmp.UpmsbGns01` |
| `da5e3348a1eaeaab` | 3.1 | 1 | 2026-07-26T12:58:43 | `/tmp/.private/milosvasic/tmp.UqnnvmVhuD` |
| `c7e10f18271263ba` | 0.1 | 0 | 2026-06-29T19:24:14 | `/tmp/.private/milosvasic/tmp.Uumd2Uxxmi` |
| `a564749efe559852` | 0.1 | 0 | 2026-07-26T20:30:22 | `/tmp/.private/milosvasic/tmp.UwFGbBOmDX` |
| `5c3b4d75a27a0b41` | 0.1 | 0 | 2026-07-26T12:58:44 | `/tmp/.private/milosvasic/tmp.VJXy8q7lwS` |
| `2d7f84e066862b8b` | 3.1 | 1 | 2026-07-26T21:53:55 | `/tmp/.private/milosvasic/tmp.VQLgnuSxZX` |
| `08293ba7b96b747a` | 3.1 | 1 | 2026-07-26T18:19:32 | `/tmp/.private/milosvasic/tmp.VRTvXcoMBW` |
| `ebf3f16cb4ba8f25` | 3.1 | 1 | 2026-07-26T18:19:32 | `/tmp/.private/milosvasic/tmp.VUor5UTAzn` |
| `5efe87340347dde3` | 3.1 | 2 | 2026-07-26T20:38:43 | `/tmp/.private/milosvasic/tmp.VW8BNP9osv` |
| `e1b5bdde907c0711` | 0.1 | 0 | 2026-06-29T19:24:15 | `/tmp/.private/milosvasic/tmp.VZ6gHKTtd9` |
| `8002f46eb4dc37f7` | 3.1 | 1 | 2026-07-26T20:30:38 | `/tmp/.private/milosvasic/tmp.VyxwYq7Hw3` |
| `1cbde589309a2fba` | 0.1 | 0 | 2026-06-29T19:24:15 | `/tmp/.private/milosvasic/tmp.VzHwo1Chhx` |
| `a7c92c8df71aa4f3` | 3.1 | 1 | 2026-07-26T14:32:59 | `/tmp/.private/milosvasic/tmp.W4btjsCWve` |
| `95c05346bb4267ea` | 0.1 | 0 | 2026-07-04T23:05:29 | `/tmp/.private/milosvasic/tmp.W5yKzCYonZ` |
| `def47e8abc175679` | 0.1 | 0 | 2026-07-26T22:23:46 | `/tmp/.private/milosvasic/tmp.WBSIpzwTPk` |
| `3bdec243369103f6` | 0.1 | 0 | 2026-07-26T21:56:16 | `/tmp/.private/milosvasic/tmp.WMD1SHLIe1` |
| `90f3f04185f14b16` | 3.1 | 1 | 2026-07-26T20:30:46 | `/tmp/.private/milosvasic/tmp.WbDoxR3vaT` |
| `002451c5e88e19b1` | 3.1 | 1 | 2026-07-26T20:30:51 | `/tmp/.private/milosvasic/tmp.Wi8cikm3Dw` |
| `d224e8ed3738d853` | 0.1 | 0 | 2026-07-26T17:53:52 | `/tmp/.private/milosvasic/tmp.Wud6oqAcaA` |
| `b9401edd8e9e4e8f` | 0.1 | 0 | 2026-07-26T18:19:35 | `/tmp/.private/milosvasic/tmp.X428h1kjab` |
| `e735fcecd2117133` | 3.1 | 1 | 2026-07-26T18:19:36 | `/tmp/.private/milosvasic/tmp.X4VncZOIZW` |
| `48f8aea0e9198c79` | 3.1 | 1 | 2026-07-26T12:58:46 | `/tmp/.private/milosvasic/tmp.X4YWVGq2Zo` |
| `6d141b4ab4d0061e` | 3.1 | 1 | 2026-07-26T22:00:51 | `/tmp/.private/milosvasic/tmp.X72C2Qv5HP` |
| `e246ffbac89b4d54` | 3.1 | 1 | 2026-07-26T18:19:38 | `/tmp/.private/milosvasic/tmp.XOCaUEgbP3` |
| `e61ccb21af50777d` | 3.1 | 1 | 2026-07-26T18:19:39 | `/tmp/.private/milosvasic/tmp.XUuuTMF0Fh` |
| `92aef9694d9701de` | 3.1 | 1 | 2026-07-26T18:19:40 | `/tmp/.private/milosvasic/tmp.XwtYN15j4D` |
| `502ea33ed06eb3a9` | 0.1 | 0 | 2026-07-26T21:31:41 | `/tmp/.private/milosvasic/tmp.XxU0DurvUx` |
| `01c1ac8c33a35b28` | 3.1 | 1 | 2026-07-26T18:19:41 | `/tmp/.private/milosvasic/tmp.YBPulpZDCl` |
| `b0c33a0615a90951` | 3.1 | 1 | 2026-07-26T21:32:14 | `/tmp/.private/milosvasic/tmp.YC4cTpHBBr` |
| `177149c9e9bf0f42` | 3.1 | 1 | 2026-07-26T21:32:30 | `/tmp/.private/milosvasic/tmp.YH7mr1BAyu` |
| `751e43570f5aaab7` | 0.1 | 0 | 2026-06-29T19:24:17 | `/tmp/.private/milosvasic/tmp.YUbodevquq` |
| `b778fccc455121a5` | 3.1 | 1 | 2026-07-26T18:19:42 | `/tmp/.private/milosvasic/tmp.YbLpq5VCtv` |
| `4400e9aeb0e5cce8` | 3.1 | 1 | 2026-07-26T18:19:43 | `/tmp/.private/milosvasic/tmp.YpdeUllb5K` |
| `44cd3fe37ba497bf` | 3.1 | 1 | 2026-07-26T19:00:03 | `/tmp/.private/milosvasic/tmp.Z15X6lQXZy` |
| `611485adc52bdc96` | 0.1 | 0 | 2026-06-29T19:24:19 | `/tmp/.private/milosvasic/tmp.Z1LmO948rF` |
| `a648158c75c29dbe` | 0.1 | 0 | 2026-07-26T19:00:05 | `/tmp/.private/milosvasic/tmp.ZAUsf7IyCX` |
| `2178569820deefc7` | 0.1 | 0 | 2026-07-04T23:05:33 | `/tmp/.private/milosvasic/tmp.ZAhN5q4oqN` |
| `02118a328d9a3f28` | 3.1 | 1 | 2026-07-26T20:42:39 | `/tmp/.private/milosvasic/tmp.ZBVHJFFTJc` |
| `2c5e36e2030d0ec9` | 0.1 | 0 | 2026-07-26T17:53:58 | `/tmp/.private/milosvasic/tmp.ZCUBoc8os4` |
| `ac4db92ce1a61bd9` | 3.1 | 2 | 2026-07-26T21:33:54 | `/tmp/.private/milosvasic/tmp.ZINR4XutHd` |
| `b98b4f8c0294d77a` | 0.1 | 0 | 2026-07-26T17:18:44 | `/tmp/.private/milosvasic/tmp.ZKHhwsDigw` |
| `58a156ce2ef92618` | 3.1 | 1 | 2026-07-26T18:19:46 | `/tmp/.private/milosvasic/tmp.ZYnlIqbedv` |
| `507e49a2d71a682a` | 3.1 | 2 | 2026-07-26T18:19:47 | `/tmp/.private/milosvasic/tmp.ZaGsKSjAKy` |
| `423550a7462e03ce` | 3.1 | 1 | 2026-07-26T22:12:09 | `/tmp/.private/milosvasic/tmp.Zdtka6mjv4` |
| `ab222b5d6b75a5b7` | 3.1 | 1 | 2026-07-26T19:00:13 | `/tmp/.private/milosvasic/tmp.Zn8dVEA3aJ` |
| `928881bae5292d68` | 0.1 | 0 | 2026-07-04T23:05:38 | `/tmp/.private/milosvasic/tmp.Zne85y6EjZ` |
| `3a6e4438b5f1675e` | 3.1 | 1 | 2026-07-26T18:19:48 | `/tmp/.private/milosvasic/tmp.Zw3H8fL7Pv` |
| `2add9bae3893d720` | 0.1 | 0 | 2026-07-26T19:00:15 | `/tmp/.private/milosvasic/tmp.ZyWzHuczPB` |
| `138cc6d1b4766b0c` | 0.1 | 0 | 2026-07-26T18:19:49 | `/tmp/.private/milosvasic/tmp.a1wzvnjx3B` |
| `9945e355c0c7cad0` | 3.1 | 1 | 2026-07-26T14:33:02 | `/tmp/.private/milosvasic/tmp.a4mg4h4DIJ` |
| `446fa6cfaae1f8fb` | 0.1 | 0 | 2026-07-26T17:18:47 | `/tmp/.private/milosvasic/tmp.a5ZNlbamjn` |
| `5c350caf62561421` | 0.1 | 0 | 2026-07-26T14:33:03 | `/tmp/.private/milosvasic/tmp.aAAiZ3U2C9` |
| `480ab69600b7e31a` | 0.1 | 0 | 2026-07-26T22:29:28 | `/tmp/.private/milosvasic/tmp.aDopDIrKoi` |
| `c576badee9fc263f` | 3.1 | 1 | 2026-07-26T18:19:53 | `/tmp/.private/milosvasic/tmp.aLMpn68kQH` |
| `3fa62e73271f4519` | 0.1 | 0 | 2026-07-04T23:05:40 | `/tmp/.private/milosvasic/tmp.aXG7PrTXVO` |
| `1e578f940c6a0d23` | 3.1 | 1 | 2026-07-26T20:32:34 | `/tmp/.private/milosvasic/tmp.aYdPZxtYkZ` |
| `3b417955a588264e` | 3.1 | 1 | 2026-07-26T18:19:54 | `/tmp/.private/milosvasic/tmp.adBzO5pSJt` |
| `319fcddb40104110` | 3.1 | 1 | 2026-07-26T18:19:55 | `/tmp/.private/milosvasic/tmp.apd0vZPbBP` |
| `d07e5a2af1c108a5` | 3.1 | 2 | 2026-07-26T18:19:56 | `/tmp/.private/milosvasic/tmp.b1mdgz0vwo` |
| `6de4c4b4b91bae81` | 3.1 | 1 | 2026-07-26T18:19:57 | `/tmp/.private/milosvasic/tmp.b51aGLwlr4` |
| `fb95d142807807a2` | 0.1 | 0 | 2026-07-04T23:05:40 | `/tmp/.private/milosvasic/tmp.b7SxTmrIOa` |
| `dd037746cd558851` | 3.1 | 1 | 2026-07-26T21:31:22 | `/tmp/.private/milosvasic/tmp.bAziMNrdn7` |
| `b11fffeab8283874` | 0.1 | 0 | 2026-07-26T18:19:58 | `/tmp/.private/milosvasic/tmp.bFrHWDAfax` |
| `6ab6a42edfff1b37` | 3.1 | 1 | 2026-07-26T18:19:59 | `/tmp/.private/milosvasic/tmp.bHrbxdeCdT` |
| `9821eb723e26031d` | 3.1 | 2 | 2026-07-26T18:20:00 | `/tmp/.private/milosvasic/tmp.bLlUIYqOOg` |
| `a8a9c398733cb8dd` | 0.1 | 0 | 2026-07-26T20:33:06 | `/tmp/.private/milosvasic/tmp.blDrExgY4H` |
| `36f78704c9a29c26` | 3.1 | 1 | 2026-07-26T22:23:11 | `/tmp/.private/milosvasic/tmp.bmvPv6RSWr` |
| `a3372cdc0199dff5` | 0.1 | 0 | 2026-07-26T20:33:12 | `/tmp/.private/milosvasic/tmp.c1Fg5LCDeK` |
| `2b24bb43b7d1b920` | 3.1 | 1 | 2026-07-26T14:33:04 | `/tmp/.private/milosvasic/tmp.c9kjZQkoY1` |
| `e57fe29ad636cc53` | 3.1 | 1 | 2026-07-26T18:20:02 | `/tmp/.private/milosvasic/tmp.cIB2o0fDch` |
| `2563655f0565f86c` | 0.1 | 0 | 2026-07-26T17:18:51 | `/tmp/.private/milosvasic/tmp.cNsRzVkd2a` |
| `f8a45234b201f15b` | 3.1 | 1 | 2026-07-26T20:33:36 | `/tmp/.private/milosvasic/tmp.cgOZToGDKD` |
| `ed2301caa9796771` | 0.1 | 0 | 2026-06-29T19:24:25 | `/tmp/.private/milosvasic/tmp.cljr6xs33M` |
| `31a14ca0bf5c330e` | 3.1 | 1 | 2026-07-26T19:00:34 | `/tmp/.private/milosvasic/tmp.d8G7u7LZDG` |
| `b034bd463fe47fda` | 3.1 | 1 | 2026-07-26T18:20:04 | `/tmp/.private/milosvasic/tmp.dEpfXQLc7M` |
| `7cf27c2d6328a6fa` | 3.1 | 1 | 2026-07-26T18:20:05 | `/tmp/.private/milosvasic/tmp.dLPmiyHLW7` |
| `7e00e660265a8189` | 3.1 | 1 | 2026-07-26T20:33:57 | `/tmp/.private/milosvasic/tmp.dTVevLQjYD` |
| `34e30bfd4e18d1b0` | 3.1 | 1 | 2026-07-26T18:20:06 | `/tmp/.private/milosvasic/tmp.daKmO1yRbm` |
| `fdfa34c81e6b4cf7` | 3.1 | 1 | 2026-07-26T21:41:33 | `/tmp/.private/milosvasic/tmp.ddpJ6sHieC` |
| `4bdd008d80f9a0c0` | 3.1 | 1 | 2026-07-26T19:00:42 | `/tmp/.private/milosvasic/tmp.df6yXxuRkY` |
| `8ac5b615516d2cc2` | 0.1 | 0 | 2026-07-26T17:33:32 | `/tmp/.private/milosvasic/tmp.dp8ubUoTsR` |
| `b6a4493dde5fc941` | 0.1 | 0 | 2026-07-04T23:05:43 | `/tmp/.private/milosvasic/tmp.drZnF2abBe` |
| `22c2e5a26e18ed24` | 3.1 | 1 | 2026-07-26T22:32:22 | `/tmp/.private/milosvasic/tmp.e3G8wJ9rBL` |
| `89cd1c42f7a5951f` | 3.1 | 1 | 2026-07-26T20:34:12 | `/tmp/.private/milosvasic/tmp.e92phECe0F` |
| `ffb7bfa819b76b77` | 3.1 | 1 | 2026-07-26T20:34:15 | `/tmp/.private/milosvasic/tmp.eCAr2ZseE1` |
| `84c84a053cdeb36f` | 0.1 | 0 | 2026-07-26T17:18:53 | `/tmp/.private/milosvasic/tmp.ee3p9bsprx` |
| `74ba3042a7920be8` | 3.1 | 1 | 2026-07-26T22:27:36 | `/tmp/.private/milosvasic/tmp.eeGkOr6cVv` |
| `2679bc3454ec8557` | 3.1 | 1 | 2026-07-26T20:34:24 | `/tmp/.private/milosvasic/tmp.emQPm7mbkf` |
| `b47fdcb7c3b325a8` | 3.1 | 1 | 2026-07-26T18:20:08 | `/tmp/.private/milosvasic/tmp.eo5uKrq7Nl` |
| `9fa9aae67c0254da` | 3.1 | 1 | 2026-07-26T21:38:01 | `/tmp/.private/milosvasic/tmp.erXDyScnoi` |
| `d1b51e457229dac4` | 0.1 | 0 | 2026-07-04T23:05:45 | `/tmp/.private/milosvasic/tmp.etpf7h5bea` |
| `7eb2cd5f1c4440e6` | 0.1 | 0 | 2026-07-26T22:33:36 | `/tmp/.private/milosvasic/tmp.exyY2WpvAO` |
| `46017ef262b7018e` | 3.1 | 1 | 2026-07-26T19:00:47 | `/tmp/.private/milosvasic/tmp.f8axKuPPtS` |
| `60b2bdcc39b6fb64` | 3.1 | 1 | 2026-07-26T18:20:09 | `/tmp/.private/milosvasic/tmp.f9ugaIrTPw` |
| `6f17b06780d31ca6` | 0.1 | 0 | 2026-07-26T22:28:57 | `/tmp/.private/milosvasic/tmp.fVwfsAtztX` |
| `5a44356770aa44ba` | 0.1 | 0 | 2026-07-26T22:34:17 | `/tmp/.private/milosvasic/tmp.fjjM0Qon0H` |
| `ec49525470dabe0b` | 0.1 | 0 | 2026-07-26T20:34:42 | `/tmp/.private/milosvasic/tmp.fkoETCAPVm` |
| `223d9fd1c5dd751b` | 3.1 | 1 | 2026-07-26T20:34:45 | `/tmp/.private/milosvasic/tmp.fsGw2JyP6U` |
| `5af14acb195ace74` | 3.1 | 1 | 2026-07-26T22:34:44 | `/tmp/.private/milosvasic/tmp.fubCGoRuST` |
| `1556299b2831bb59` | 3.1 | 1 | 2026-07-26T20:34:51 | `/tmp/.private/milosvasic/tmp.g5mGwpijpR` |
| `6fe9a02a1e7a06ba` | 3.1 | 1 | 2026-07-26T22:37:18 | `/tmp/.private/milosvasic/tmp.gBt2og4Eaq` |
| `11eabdd7b46e3599` | 0.1 | 0 | 2026-07-26T21:44:19 | `/tmp/.private/milosvasic/tmp.gFLqjwkgxa` |
| `1346e09e646fd039` | 3.1 | 1 | 2026-07-26T20:57:08 | `/tmp/.private/milosvasic/tmp.gJwKvlXKLi` |
| `379a0b43dfb7c948` | 3.1 | 1 | 2026-07-26T20:57:30 | `/tmp/.private/milosvasic/tmp.gNM7SD3Uoo` |
| `ca5dd74659e815b1` | 3.1 | 1 | 2026-07-26T18:20:10 | `/tmp/.private/milosvasic/tmp.gSrO64BwFA` |
| `6526337ac7c5f34b` | 3.1 | 2 | 2026-07-26T22:30:44 | `/tmp/.private/milosvasic/tmp.gTcvpT2vwG` |
| `824fe4b3b645a625` | 0.1 | 0 | 2026-06-29T19:24:27 | `/tmp/.private/milosvasic/tmp.hGVx81WsZz` |
| `8c4bc00da4037a79` | 0.1 | 0 | 2026-07-26T20:35:00 | `/tmp/.private/milosvasic/tmp.hYV8rylBen` |
| `dd7fa9111894c4e0` | 3.1 | 1 | 2026-07-26T18:20:11 | `/tmp/.private/milosvasic/tmp.hkBpz3bgTj` |
| `d3355593b751ff00` | 3.1 | 1 | 2026-07-26T20:35:16 | `/tmp/.private/milosvasic/tmp.hxExvlUtbx` |
| `89849620d08c50da` | 0.1 | 0 | 2026-07-04T23:05:50 | `/tmp/.private/milosvasic/tmp.i9mYlGO9eS` |
| `d5f84c3879001a0a` | 3.1 | 1 | 2026-07-26T22:31:31 | `/tmp/.private/milosvasic/tmp.iAeEmbcnso` |
| `6af87a41a4a82c6e` | 0.1 | 0 | 2026-07-26T14:33:05 | `/tmp/.private/milosvasic/tmp.iF4yIGaY0w` |
| `aa0fd6fba0f866df` | 3.1 | 1 | 2026-07-26T20:35:26 | `/tmp/.private/milosvasic/tmp.iG8bNhxUej` |
| `b266959b0f41b32d` | 3.1 | 1 | 2026-07-26T21:41:34 | `/tmp/.private/milosvasic/tmp.iS1wmdPQ0o` |
| `ab7d784239b1ff2c` | 3.1 | 2 | 2026-07-26T18:20:13 | `/tmp/.private/milosvasic/tmp.j1Cjjbtrlg` |
| `67baf90ce27e2c3d` | 0.1 | 0 | 2026-07-26T22:38:44 | `/tmp/.private/milosvasic/tmp.j1hcTy0Yjt` |
| `81da99f986700105` | 0.1 | 0 | 2026-07-26T14:33:07 | `/tmp/.private/milosvasic/tmp.j39XczccSv` |
| `52be2b9dfc50b9d5` | 3.1 | 1 | 2026-07-26T21:00:50 | `/tmp/.private/milosvasic/tmp.j3Qi97UncL` |
| `1433e3e13c2086a0` | 3.1 | 2 | 2026-07-26T22:39:02 | `/tmp/.private/milosvasic/tmp.jGcouZmqQ3` |
| `95bc62e18865ac75` | 3.1 | 1 | 2026-07-26T20:35:48 | `/tmp/.private/milosvasic/tmp.jPSKUarddp` |
| `5189b5d811fa6445` | 3.1 | 1 | 2026-07-26T18:20:15 | `/tmp/.private/milosvasic/tmp.jWsGr5AnOL` |
| `3e47f8441eca627e` | 3.1 | 1 | 2026-07-26T20:35:57 | `/tmp/.private/milosvasic/tmp.jcNkQz8sn3` |
| `21541a645055a8fc` | 3.1 | 1 | 2026-07-26T20:36:03 | `/tmp/.private/milosvasic/tmp.jeiDVTZH85` |
| `ce8d096620c2e4ee` | 3.1 | 1 | 2026-07-26T19:01:07 | `/tmp/.private/milosvasic/tmp.kCMghnfNlI` |
| `def5c0e60a11a11b` | 3.1 | 2 | 2026-07-26T18:20:16 | `/tmp/.private/milosvasic/tmp.kCe50YklSE` |
| `0491a2bcc4a980f5` | 0.1 | 0 | 2026-07-26T20:36:13 | `/tmp/.private/milosvasic/tmp.kLNFLTZqU3` |
| `77e01e9fb1b739e6` | 3.1 | 1 | 2026-07-26T14:33:08 | `/tmp/.private/milosvasic/tmp.kNY8liWZd9` |
| `5ae7f4597ac66056` | 3.1 | 2 | 2026-07-26T12:58:48 | `/tmp/.private/milosvasic/tmp.kTNR6qsQyW` |
| `6707d7fdb4ce434b` | 3.1 | 1 | 2026-07-26T18:20:18 | `/tmp/.private/milosvasic/tmp.kZmXQmxEiB` |
| `638588c745a5e817` | 0.1 | 0 | 2026-07-04T23:05:52 | `/tmp/.private/milosvasic/tmp.kcvCzjjJx8` |
| `908909477b18f0e5` | 3.1 | 2 | 2026-07-26T22:37:14 | `/tmp/.private/milosvasic/tmp.koVf83kyd0` |
| `3a909405ec01a5bb` | 3.1 | 1 | 2026-07-26T18:20:19 | `/tmp/.private/milosvasic/tmp.lGDVvuwXTl` |
| `5580fcd5ff339487` | 0.1 | 0 | 2026-07-26T17:33:43 | `/tmp/.private/milosvasic/tmp.lGUHyxSGAH` |
| `87bd7cc4d12e5496` | 0.1 | 0 | 2026-07-26T17:19:10 | `/tmp/.private/milosvasic/tmp.lJjk2A4AWJ` |
| `897ccd4890960b74` | 3.1 | 1 | 2026-07-26T12:58:49 | `/tmp/.private/milosvasic/tmp.lXvRVE0FBB` |
| `e00156a2f03b996f` | 3.1 | 1 | 2026-07-26T20:37:00 | `/tmp/.private/milosvasic/tmp.lZ61XvxPsc` |
| `57904bada453630c` | 0.1 | 0 | 2026-07-26T20:37:06 | `/tmp/.private/milosvasic/tmp.lfJiZ40TJP` |
| `ce36e9f544db40d6` | 0.1 | 0 | 2026-07-26T20:37:11 | `/tmp/.private/milosvasic/tmp.ll5LLHVIg3` |
| `eddcec20b502ceb8` | 0.1 | 0 | 2026-07-26T20:37:16 | `/tmp/.private/milosvasic/tmp.lxcOlXnDte` |
| `6b92d8b65b432175` | 3.1 | 1 | 2026-07-26T18:20:23 | `/tmp/.private/milosvasic/tmp.lzGDYrBGqj` |
| `a944f17880c93377` | 0.1 | 0 | 2026-07-26T17:25:55 | `/tmp/.private/milosvasic/tmp.mCOX7fvSqI` |
| `421931993fc5dbbd` | 3.1 | 1 | 2026-07-26T22:35:26 | `/tmp/.private/milosvasic/tmp.mEr5BMFdhw` |
| `24a0cdafec83fd07` | 0.1 | 0 | 2026-07-04T23:05:53 | `/tmp/.private/milosvasic/tmp.mPEMtoV5i9` |
| `bd34920c0f5167ac` | 0.1 | 0 | 2026-07-26T17:33:48 | `/tmp/.private/milosvasic/tmp.mSwXER62wV` |
| `c56c4aa1b9c93795` | 3.1 | 1 | 2026-07-26T18:20:25 | `/tmp/.private/milosvasic/tmp.mTYeS3MIsT` |
| `e06fb54cadb05179` | 3.1 | 1 | 2026-07-26T20:37:45 | `/tmp/.private/milosvasic/tmp.mV2DRdaztr` |
| `738140ac4f159afe` | 0.1 | 0 | 2026-06-29T19:24:31 | `/tmp/.private/milosvasic/tmp.mWhvOUtlzC` |
| `4f067b87c563e7b7` | 3.1 | 1 | 2026-07-26T21:55:11 | `/tmp/.private/milosvasic/tmp.mdKmhvczeq` |
| `adbad21f51103ab9` | 3.1 | 1 | 2026-07-26T14:33:12 | `/tmp/.private/milosvasic/tmp.n1vDtBPSJx` |
| `b989ca222ca92755` | 3.1 | 1 | 2026-07-26T21:09:23 | `/tmp/.private/milosvasic/tmp.n4optUCF4c` |
| `c9f2b11ccc21055e` | 0.1 | 0 | 2026-07-26T17:25:59 | `/tmp/.private/milosvasic/tmp.n8J6uszf6n` |
| `2294d41f4fcfcf4b` | 0.1 | 0 | 2026-07-26T20:37:58 | `/tmp/.private/milosvasic/tmp.nZ9om1GtUX` |
| `3041208ec9db72db` | 0.1 | 0 | 2026-06-29T19:24:33 | `/tmp/.private/milosvasic/tmp.ndlovjw22C` |
| `4a224c8d2b200791` | 0.1 | 0 | 2026-06-29T19:24:33 | `/tmp/.private/milosvasic/tmp.neV83t6AgS` |
| `9adfd8f5a4d6f048` | 0.1 | 0 | 2026-07-26T17:26:00 | `/tmp/.private/milosvasic/tmp.njcyrFNdBP` |
| `1c376c47dab6ef09` | 3.1 | 1 | 2026-07-26T18:20:29 | `/tmp/.private/milosvasic/tmp.nnxrnxKohp` |
| `bb5f0b3f0af4debd` | 0.1 | 0 | 2026-07-04T23:05:56 | `/tmp/.private/milosvasic/tmp.ntpcVfwrUj` |
| `fe52e9f980f6e3fd` | 3.1 | 1 | 2026-07-26T22:38:38 | `/tmp/.private/milosvasic/tmp.o1UeBKFzCm` |
| `f818a44186d99b0a` | 3.1 | 1 | 2026-07-26T21:11:30 | `/tmp/.private/milosvasic/tmp.oA3D9wPDEv` |
| `3b92657d20e8d7b8` | 3.1 | 1 | 2026-07-26T18:20:30 | `/tmp/.private/milosvasic/tmp.oEECIFXAPX` |
| `96d4517388b74348` | 0.1 | 0 | 2026-07-04T23:05:57 | `/tmp/.private/milosvasic/tmp.oUlBC1rUcU` |
| `98801ad872058af8` | 3.1 | 1 | 2026-07-26T18:20:30 | `/tmp/.private/milosvasic/tmp.oei28o53eR` |
| `00e9aeba4da4732b` | 3.1 | 1 | 2026-07-26T18:20:31 | `/tmp/.private/milosvasic/tmp.pHsCTrLuTv` |
| `154ac8b1ebe4ba97` | 3.1 | 1 | 2026-07-26T20:38:34 | `/tmp/.private/milosvasic/tmp.pMLEakV8FK` |
| `5298f4d5e1c4f13a` | 0.1 | 0 | 2026-07-26T20:38:34 | `/tmp/.private/milosvasic/tmp.pPexwV8AhQ` |
| `24c70efb85cc87e1` | 0.1 | 0 | 2026-07-26T17:26:02 | `/tmp/.private/milosvasic/tmp.pRK8ea3u7f` |
| `150e74ebb08433cf` | 0.1 | 0 | 2026-07-26T22:39:08 | `/tmp/.private/milosvasic/tmp.pS3n7NyouT` |
| `6286018b7a96d73c` | 3.1 | 1 | 2026-07-26T22:39:13 | `/tmp/.private/milosvasic/tmp.pTUBblVYCg` |
| `ec1bd72e8193f3bf` | 3.1 | 1 | 2026-07-26T20:38:56 | `/tmp/.private/milosvasic/tmp.pZhGYGuuqF` |
| `c2543faf99ef7091` | 0.1 | 0 | 2026-07-26T22:39:19 | `/tmp/.private/milosvasic/tmp.poOIqoVz9v` |
| `be3df0e4dc78e9c0` | 0.1 | 0 | 2026-07-26T19:01:29 | `/tmp/.private/milosvasic/tmp.pwom89Qlha` |
| `8a80dbbf575f152f` | 3.1 | 2 | 2026-07-26T22:43:15 | `/tmp/.private/milosvasic/tmp.q5N3Eq3laD` |
| `ed20b013ae56d14d` | 0.1 | 0 | 2026-07-26T17:19:14 | `/tmp/.private/milosvasic/tmp.qAPQ9uzea0` |
| `e59766eb22144caf` | 0.1 | 0 | 2026-07-26T22:38:07 | `/tmp/.private/milosvasic/tmp.qCgI9OH1Ci` |
| `fd23718f2ecc6c3c` | 0.1 | 0 | 2026-07-26T21:58:43 | `/tmp/.private/milosvasic/tmp.qDAHqtKJCn` |
| `6dbc9f73fbb700c9` | 0.1 | 0 | 2026-07-04T23:05:58 | `/tmp/.private/milosvasic/tmp.qNI2UvI25P` |
| `aca6d4690c20b1c8` | 0.1 | 0 | 2026-07-26T17:26:05 | `/tmp/.private/milosvasic/tmp.qTBimFdRBT` |
| `e2c1b428601e5b13` | 3.1 | 1 | 2026-07-26T18:20:35 | `/tmp/.private/milosvasic/tmp.qWH1h0N7vj` |
| `900ec063c54a5156` | 0.1 | 0 | 2026-07-04T23:06:00 | `/tmp/.private/milosvasic/tmp.qdjwH49GGI` |
| `730acef9c66b35bc` | 0.1 | 0 | 2026-07-26T17:19:19 | `/tmp/.private/milosvasic/tmp.qiC9YkNg3w` |
| `7fbcfcb0399f0eed` | 0.1 | 0 | 2026-07-26T17:26:09 | `/tmp/.private/milosvasic/tmp.qohbIqaa4G` |
| `dd09764a01d105ee` | 0.1 | 0 | 2026-07-04T23:06:02 | `/tmp/.private/milosvasic/tmp.r14ORgKnuB` |
| `c94db5603d2608ed` | 3.1 | 1 | 2026-07-26T20:40:51 | `/tmp/.private/milosvasic/tmp.r3ACBsvX48` |
| `465ff73ccbd08c4e` | 3.1 | 2 | 2026-07-26T18:20:38 | `/tmp/.private/milosvasic/tmp.r6khJGlNlW` |
| `5c7ca2f469ccc824` | 0.1 | 0 | 2026-07-26T18:20:39 | `/tmp/.private/milosvasic/tmp.rCZNwDx9uu` |
| `421fdc3ccdfe984c` | 3.1 | 1 | 2026-07-26T18:20:40 | `/tmp/.private/milosvasic/tmp.rPO3xBYlVT` |
| `83980171dc91dd0a` | 0.1 | 0 | 2026-07-26T20:41:54 | `/tmp/.private/milosvasic/tmp.rVi6MY0oJE` |
| `64b32232603c1822` | 3.1 | 1 | 2026-07-26T18:20:41 | `/tmp/.private/milosvasic/tmp.rnBZwR53Nn` |
| `8aadea7fd39b1160` | 0.1 | 0 | 2026-07-26T17:34:00 | `/tmp/.private/milosvasic/tmp.rts1ZxJuVk` |
| `a957ddc8e1ba2e7a` | 3.1 | 1 | 2026-07-26T21:18:56 | `/tmp/.private/milosvasic/tmp.ru8YX4qJKc` |
| `8bc56b92d4137d31` | 3.1 | 1 | 2026-07-26T18:20:43 | `/tmp/.private/milosvasic/tmp.rxQBBrq0V2` |
| `eb0831d3e8cdab0a` | 0.1 | 0 | 2026-07-26T22:40:07 | `/tmp/.private/milosvasic/tmp.rxfbHet9tv` |
| `4e95ceec02bd629f` | 0.1 | 0 | 2026-07-26T20:42:50 | `/tmp/.private/milosvasic/tmp.rzvadTYh1m` |
| `e145ce5cba0d924c` | 0.1 | 0 | 2026-07-26T20:43:05 | `/tmp/.private/milosvasic/tmp.s1Q08QkEAD` |
| `ed8eb5c05654238c` | 0.1 | 0 | 2026-07-26T17:34:02 | `/tmp/.private/milosvasic/tmp.s1W34C0aDO` |
| `08289df2783a1c13` | 0.1 | 0 | 2026-07-26T18:20:45 | `/tmp/.private/milosvasic/tmp.s6QnRhCsyf` |
| `542b34d21b3afdee` | 0.1 | 0 | 2026-07-04T23:06:04 | `/tmp/.private/milosvasic/tmp.s80G9I6cBX` |
| `1176a7ee4a92c78d` | 3.1 | 1 | 2026-07-26T21:20:35 | `/tmp/.private/milosvasic/tmp.s8o0i4O7C3` |
| `8ed6ae38e363fa61` | 0.1 | 0 | 2026-07-26T22:40:01 | `/tmp/.private/milosvasic/tmp.sQgBrWt3Xx` |
| `c4314c65ae618b74` | 0.1 | 0 | 2026-07-26T22:08:31 | `/tmp/.private/milosvasic/tmp.sQxYvZbdM6` |
| `d30b1582ce28a12f` | 0.1 | 0 | 2026-07-04T23:06:05 | `/tmp/.private/milosvasic/tmp.sW6S2DNSIj` |
| `b5f88dd3ed42e141` | 3.1 | 1 | 2026-07-26T22:15:53 | `/tmp/.private/milosvasic/tmp.sX2B26PcF7` |
| `8525ce739e1b707e` | 3.1 | 1 | 2026-07-26T18:20:46 | `/tmp/.private/milosvasic/tmp.sqq2jtsFx1` |
| `77373e1f65c3c65e` | 0.1 | 0 | 2026-07-04T23:06:07 | `/tmp/.private/milosvasic/tmp.sz3og8EESB` |
| `50caa3e73a5da246` | 3.1 | 1 | 2026-07-26T20:44:37 | `/tmp/.private/milosvasic/tmp.tKsbtbbB7L` |
| `e9a8729fefbeb99a` | 3.1 | 1 | 2026-07-26T18:20:47 | `/tmp/.private/milosvasic/tmp.tMDudAkq0v` |
| `7c8141817026f1cd` | 3.1 | 1 | 2026-07-26T22:40:47 | `/tmp/.private/milosvasic/tmp.tNldbHsMfs` |
| `bb195bdf738707ae` | 0.1 | 0 | 2026-07-26T17:19:25 | `/tmp/.private/milosvasic/tmp.tX6BoBfbj0` |
| `8f37b3a215073b4f` | 0.1 | 0 | 2026-07-26T18:20:49 | `/tmp/.private/milosvasic/tmp.tkF8kuElCF` |
| `785d383c0fcee40e` | 0.1 | 0 | 2026-06-29T19:24:37 | `/tmp/.private/milosvasic/tmp.uD2hptlVgy` |
| `9b07e4544b4201be` | 0.1 | 0 | 2026-07-04T23:06:08 | `/tmp/.private/milosvasic/tmp.uIzH0sdmrP` |
| `2fdbf88d4fe9eabd` | 3.1 | 1 | 2026-07-26T22:12:10 | `/tmp/.private/milosvasic/tmp.umaBfzzKgk` |
| `d893537def90a10c` | 0.1 | 0 | 2026-06-29T19:24:39 | `/tmp/.private/milosvasic/tmp.urPitc51OK` |
| `c115b267c6fe1e97` | 3.1 | 1 | 2026-07-26T18:20:51 | `/tmp/.private/milosvasic/tmp.uxNXmWMFdk` |
| `12579a5a484dcfcd` | 3.1 | 1 | 2026-07-26T19:01:50 | `/tmp/.private/milosvasic/tmp.v1ck1xO13T` |
| `2b26bfe113a9f2bc` | 3.1 | 1 | 2026-07-26T22:15:53 | `/tmp/.private/milosvasic/tmp.vDxJxa3oMQ` |
| `459e17e59865c30e` | 3.1 | 1 | 2026-07-26T18:20:52 | `/tmp/.private/milosvasic/tmp.vIFVqK8Xb4` |
| `ca5e8a78e0b5a6a8` | 3.1 | 1 | 2026-07-26T18:20:53 | `/tmp/.private/milosvasic/tmp.vWFnwOaPLV` |
| `3d012e8ee2456f77` | 3.1 | 1 | 2026-07-26T18:20:56 | `/tmp/.private/milosvasic/tmp.vXPIuglsE0` |
| `05a40fd1d8deaaa1` | 3.1 | 1 | 2026-07-26T22:45:17 | `/tmp/.private/milosvasic/tmp.vh7Vn81OPw` |
| `9a4545180987a790` | 0.1 | 0 | 2026-07-26T20:48:51 | `/tmp/.private/milosvasic/tmp.w4EUz2qIYe` |
| `6b9efd02496283e8` | 3.1 | 2 | 2026-07-26T18:21:00 | `/tmp/.private/milosvasic/tmp.wFOXpKMuZB` |
| `8b1345dedb7b8e29` | 0.1 | 0 | 2026-07-26T18:04:51 | `/tmp/.private/milosvasic/tmp.wH9lrtjB73` |
| `9af375dba1161a3e` | 0.1 | 0 | 2026-06-29T19:24:40 | `/tmp/.private/milosvasic/tmp.wJUUFWBYqX` |
| `684d32a10fd51ffc` | 3.1 | 1 | 2026-07-26T22:24:02 | `/tmp/.private/milosvasic/tmp.wVzGlpaWB6` |
| `5260e562b7ca1056` | 3.1 | 1 | 2026-07-26T18:21:05 | `/tmp/.private/milosvasic/tmp.ws9WzlMMJB` |
| `1b160b0055ee2d79` | 3.1 | 1 | 2026-07-26T20:49:34 | `/tmp/.private/milosvasic/tmp.wxz9rJcTHF` |
| `bbf52fbd36eac666` | 3.1 | 1 | 2026-07-26T12:58:50 | `/tmp/.private/milosvasic/tmp.xAF1gJmlhH` |
| `c30ecb01cb3d5597` | 3.1 | 1 | 2026-07-26T18:21:07 | `/tmp/.private/milosvasic/tmp.xDYaKUrBkT` |
| `84402ad0d27fe377` | 3.1 | 1 | 2026-07-26T20:49:57 | `/tmp/.private/milosvasic/tmp.xHIyvgRLpN` |
| `b44f79def80a8c4d` | 3.1 | 1 | 2026-07-26T21:25:42 | `/tmp/.private/milosvasic/tmp.xKzzwfB7ca` |
| `85f340234b092f8f` | 0.1 | 0 | 2026-07-26T12:58:50 | `/tmp/.private/milosvasic/tmp.xTKh90ctIu` |
| `3fbe4d728b7c8150` | 0.1 | 0 | 2026-07-26T12:58:51 | `/tmp/.private/milosvasic/tmp.xZ8TaMabsJ` |
| `e173ed6f47c3c343` | 0.1 | 0 | 2026-07-26T19:02:00 | `/tmp/.private/milosvasic/tmp.xnaZLKYww6` |
| `2ee772064092b285` | 3.1 | 1 | 2026-07-26T18:21:12 | `/tmp/.private/milosvasic/tmp.y3E0HnRvV5` |
| `fd387fb8faa54584` | 0.1 | 0 | 2026-07-04T23:06:12 | `/tmp/.private/milosvasic/tmp.y4NqL9aqe3` |
| `29fd02bc56c9cc5f` | 3.1 | 1 | 2026-07-26T22:23:11 | `/tmp/.private/milosvasic/tmp.y8WECBYg5S` |
| `1cb12913b75877fb` | 0.1 | 0 | 2026-07-26T17:19:40 | `/tmp/.private/milosvasic/tmp.yEcMvR065X` |
| `9482ba9ff0eae1e1` | 0.1 | 0 | 2026-07-26T22:23:42 | `/tmp/.private/milosvasic/tmp.yH2wgh5XxI` |
| `50cc7c2331bccb28` | 0.1 | 0 | 2026-07-26T14:33:16 | `/tmp/.private/milosvasic/tmp.yKqgQSHYTA` |
| `cf5a67f077d23de5` | 3.1 | 1 | 2026-07-26T22:43:15 | `/tmp/.private/milosvasic/tmp.ySLr5aQCHb` |
| `21e71182b298e7f7` | 3.1 | 1 | 2026-07-26T18:21:20 | `/tmp/.private/milosvasic/tmp.yeLp05xdOt` |
| `3bc3022431632c5e` | 3.1 | 1 | 2026-07-26T21:27:34 | `/tmp/.private/milosvasic/tmp.ygEogG1zrl` |
| `46786833101333d2` | 3.1 | 2 | 2026-07-26T22:24:50 | `/tmp/.private/milosvasic/tmp.yqgtjRZHO0` |
| `3c229d40a8f6cf3c` | 3.1 | 1 | 2026-07-26T18:21:23 | `/tmp/.private/milosvasic/tmp.yyeQywXlX5` |
| `49901a4cbb761db2` | 0.1 | 0 | 2026-07-26T20:51:33 | `/tmp/.private/milosvasic/tmp.z2jmNRvj43` |
| `fc6887384c1880f7` | 3.1 | 1 | 2026-07-26T18:21:26 | `/tmp/.private/milosvasic/tmp.z3J3uuDOfk` |
| `8e04572306dfd932` | 0.1 | 0 | 2026-07-04T23:06:14 | `/tmp/.private/milosvasic/tmp.z6JiUOZy13` |
| `27c3db149c2be370` | 0.1 | 0 | 2026-07-26T14:33:17 | `/tmp/.private/milosvasic/tmp.z9xZEdLHyf` |
| `e6a8e74e17f67336` | 0.1 | 0 | 2026-07-26T20:51:54 | `/tmp/.private/milosvasic/tmp.zDBPbX6YpA` |
| `2283760898dba587` | 3.1 | 1 | 2026-07-26T18:21:32 | `/tmp/.private/milosvasic/tmp.zO2Gfxolf9` |
| `242aba5e904729fc` | 0.1 | 0 | 2026-07-26T18:05:04 | `/tmp/.private/milosvasic/tmp.zWo3jawOj3` |
| `07ec26af4df875f2` | 0.1 | 0 | 2026-07-26T14:33:18 | `/tmp/.private/milosvasic/tmp.zYsqmUEpaT` |
| `9d4cb250beb94113` | 3.1 | 2 | 2026-07-26T20:52:49 | `/tmp/.private/milosvasic/tmp.zdF29lj8M8` |
| `cb26f7db6dc35b89` | 3.1 | 1 | 2026-07-26T22:46:31 | `/tmp/.private/milosvasic/tmp.zrYM3Yj2EV` |
| `6148d39e0e56ed2c` | 3.1 | 1 | 2026-07-26T18:21:40 | `/tmp/.private/milosvasic/tmp.zrmK66rEU3` |
| `bb844e7a08075483` | 0.1 | 0 | 2026-06-29T14:51:57 | `/tmp/cma-color-1022316/proj` |
| `200a3e2b795d704a` | 0.1 | 0 | 2026-06-29T14:53:39 | `/tmp/cma-color2-1026250/proj` |
| `0e17b62edfec5a0d` | 0.1 | 0 | 2026-06-29T14:58:18 | `/tmp/cma-color3-1032220/proj` |
| `3d5d92dff812d3b8` | 0.1 | 0 | 2026-06-29T13:49:58 | `/tmp/cma-colortest-624526/proj` |
| `c028eac4bd275129` | 0.1 | 0 | 2026-06-29T14:54:49 | `/tmp/cma-dbg-1028887/proj` |
| `6a0c1998f2b95430` | 0.1 | 0 | 2026-06-29T14:56:04 | `/tmp/cma-dbg2-1030103/proj` |
| `624e868a5bbfc135` | 0.1 | 0 | 2026-06-29T12:59:51 | `/tmp/cma-e2e-232399/LegacyProj` |
| `bcdb6120ae15fe88` | 0.1 | 0 | 2026-06-29T12:59:42 | `/tmp/cma-e2e-232399/MyLiveProj` |
| `95578d7f5dd49894` | 0.1 | 0 | 2026-06-29T15:24:43 | `/tmp/cma-final-1102115/proj` |
| `4e8ba10abe256463` | 0.1 | 0 | 2026-06-29T12:48:42 | `/tmp/cma-nameprobe-176563/proj` |
| `e6bbdef6f732ec3d` | 0.1 | 0 | 2026-06-29T12:44:18 | `/tmp/cma-probe-159271/proj` |
| `03757daee1704e18` | 0.1 | 0 | 2026-07-18T11:27:17 | `/tmp/xsess` |
| `0c3a404e73b79319` | 0.1 | 0 | 2026-07-18T12:53:55 | `/tmp/xsess2` |

## Appendix B — all 227 INCOMPLETE indexes

No `project_path` recorded; not addressable by `lumen purge <path>`.

| Index dir | Size (MB) | Files | Chunks | DB mtime |
|---|---:|---:|---:|---|
| `b8e0d4184f441af8` | 0.2 | 1291 | 0 | 2026-07-07 11:47 |
| `e28e407c6009f307` | 0.2 | 924 | 0 | 2026-08-26 21:10 |
| `5e077c8a01a83a6c` | 0.2 | 458 | 0 | 2026-06-30 16:58 |
| `80b67a7594d07a7c` | 0.2 | 520 | 0 | 2026-07-12 08:37 |
| `35a23b347ebba693` | 0.1 | 386 | 0 | 2026-07-02 09:43 |
| `7d942c0f69ca9162` | 0.1 | 271 | 0 | 2026-07-04 14:12 |
| `081012c2052d080c` | 0.1 | 355 | 0 | 2026-08-26 21:10 |
| `374ad9f24fa93cc2` | 0.1 | 170 | 0 | 2026-07-04 13:32 |
| `d29e9f53b3f3f5b4` | 0.1 | 222 | 0 | 2026-07-07 09:26 |
| `eacc64d7fb49fe83` | 0.1 | 179 | 0 | 2026-08-26 21:10 |
| `caccea829e41021e` | 0.1 | 248 | 0 | 2026-07-21 11:06 |
| `fbe97929eb1c1523` | 0.1 | 159 | 0 | 2026-06-28 18:22 |
| `4e6d8cb66c5614bc` | 0.1 | 59 | 0 | 2026-06-29 21:24 |
| `9940cb65b3d6b960` | 0.1 | 70 | 0 | 2026-08-26 21:10 |
| `a6e67382fff23fb7` | 0.1 | 84 | 0 | 2026-08-26 21:10 |
| `b41987530dc925ef` | 0.1 | 128 | 0 | 2026-07-04 18:20 |
| `c44b571dd22a61df` | 0.1 | 59 | 0 | 2026-06-29 21:25 |
| `c669e6fe45ba1a90` | 0.1 | 102 | 0 | 2026-06-28 11:53 |
| `dc2607ab23bd0e3f` | 0.1 | 111 | 0 | 2026-06-28 18:22 |
| `007fa12ee853110a` | 0.1 | 1 | 0 | 2026-07-05 01:06 |
| `026837f942f355d8` | 0.1 | 1 | 0 | 2026-06-29 21:25 |
| `03c39f6700a1ee88` | 0.1 | 73 | 0 | 2026-06-28 18:22 |
| `0421a376b78c435d` | 0.1 | 12 | 0 | 2026-06-28 18:20 |
| `045591978bd1afa6` | 0.1 | 1 | 0 | 2026-07-05 01:06 |
| `0687e5762d9219fd` | 0.1 | 1 | 0 | 2026-06-29 21:25 |
| `07da1ea72d7431d2` | 0.1 | 1 | 0 | 2026-07-05 01:04 |
| `09fe53195b34f5f7` | 0.1 | 1 | 0 | 2026-06-29 21:25 |
| `0a1ead775a1ed0a4` | 0.1 | 1 | 0 | 2026-07-05 01:06 |
| `0bc39c73edc89dcc` | 0.1 | 1 | 0 | 2026-07-05 01:04 |
| `0dc91a9ba9a7be2c` | 0.1 | 11 | 0 | 2026-06-28 18:20 |
| `0f5cbab7e433220a` | 0.1 | 9 | 0 | 2026-06-27 21:44 |
| `106bc981c8491564` | 0.1 | 1 | 0 | 2026-07-05 01:05 |
| `10e2301ea00b090a` | 0.1 | 1 | 0 | 2026-07-05 01:05 |
| `1121fac9f995a4e3` | 0.1 | 2 | 0 | 2026-06-29 21:25 |
| `1223c2ceaf6e825c` | 0.1 | 1 | 0 | 2026-06-29 21:25 |
| `12a5bc76a1cc017f` | 0.1 | 22 | 0 | 2026-06-27 21:44 |
| `1382a0a96027176b` | 0.1 | 1 | 0 | 2026-06-29 21:26 |
| `13ef06de01809972` | 0.1 | 32 | 0 | 2026-06-27 21:44 |
| `1540123f5895cbcd` | 0.1 | 1 | 0 | 2026-07-05 01:04 |
| `1617cea6e45268be` | 0.1 | 10 | 0 | 2026-07-01 10:11 |
| `16244e141d811793` | 0.1 | 23 | 0 | 2026-06-27 21:46 |
| `16983e4d4d2415e1` | 0.1 | 1 | 0 | 2026-07-05 01:05 |
| `18a29f825fd3ca58` | 0.1 | 1 | 0 | 2026-07-05 01:05 |
| `18e6d49944b3f94f` | 0.1 | 2 | 0 | 2026-07-05 01:04 |
| `1a125e7b55186285` | 0.1 | 0 | 0 | 2026-07-26 19:29 |
| `1a5895ab9b324b87` | 0.1 | 1 | 0 | 2026-06-29 21:25 |
| `1d45f854a7a8e4a6` | 0.1 | 1 | 0 | 2026-06-29 21:24 |
| `1de63eff3d2b0216` | 0.1 | 2 | 0 | 2026-07-05 01:05 |
| `1ed6f012017be369` | 0.1 | 1 | 0 | 2026-07-05 01:05 |
| `1f83bf69b05a58c0` | 0.1 | 1 | 0 | 2026-07-05 01:06 |
| `212c5107c0f32819` | 0.1 | 2 | 0 | 2026-07-05 01:05 |
| `227b6a2d1d8d9a5e` | 0.1 | 1 | 0 | 2026-07-05 01:04 |
| `2416b675934a4fea` | 0.1 | 1 | 0 | 2026-06-29 21:25 |
| `254849acded57a32` | 0.1 | 1 | 0 | 2026-07-05 01:05 |
| `25612fcf7639bd70` | 0.1 | 1 | 0 | 2026-07-05 01:04 |
| `25938509c33dc512` | 0.1 | 25 | 0 | 2026-06-27 21:44 |
| `2a886ddce0c668df` | 0.1 | 1 | 0 | 2026-07-05 01:04 |
| `2ddc84e590b69361` | 0.1 | 1 | 0 | 2026-06-29 21:24 |
| `2e3cb108fc757608` | 0.1 | 1 | 0 | 2026-07-05 01:06 |
| `2e986ab5e668c7a7` | 0.1 | 32 | 0 | 2026-06-28 10:54 |
| `2fca947486225701` | 0.1 | 12 | 0 | 2026-06-28 18:20 |
| `2fd963a6d879ea47` | 0.1 | 1 | 0 | 2026-06-29 21:24 |
| `30e722c6676f76db` | 0.1 | 24 | 0 | 2026-06-27 21:35 |
| `344ab6ba743289cc` | 0.1 | 1 | 0 | 2026-07-05 01:05 |
| `34787a682a3d4c8c` | 0.1 | 1 | 0 | 2026-07-05 01:05 |
| `35d28ce5ae263cf2` | 0.1 | 1 | 0 | 2026-06-29 21:24 |
| `36fa2d3a55caffdb` | 0.1 | 0 | 0 | 2026-07-26 19:19 |
| `37982cc9d259aeee` | 0.1 | 1 | 0 | 2026-07-05 01:04 |
| `386e463fa22ab01e` | 0.1 | 14 | 0 | 2026-08-26 21:10 |
| `38ff018438c30059` | 0.1 | 1 | 0 | 2026-07-05 01:05 |
| `3b4417dae8d99875` | 0.1 | 10 | 0 | 2026-06-27 21:44 |
| `3bd9da92051a14e1` | 0.1 | 1 | 0 | 2026-07-05 01:04 |
| `3d4a9c82134902ce` | 0.1 | 1 | 0 | 2026-07-05 01:05 |
| `3d81febc5643fe73` | 0.1 | 5 | 0 | 2026-06-27 21:44 |
| `3da59c829920db9a` | 0.1 | 26 | 0 | 2026-06-27 21:44 |
| `400f1f9e428df447` | 0.1 | 1 | 0 | 2026-07-05 01:05 |
| `44db21811446280b` | 0.1 | 75 | 0 | 2026-06-28 18:22 |
| `450d645108b51aab` | 0.1 | 2 | 0 | 2026-06-29 21:24 |
| `46c4bb5c0ddfa918` | 0.1 | 2 | 0 | 2026-07-05 01:05 |
| `47c865ec2aeabf74` | 0.1 | 0 | 0 | 2026-07-26 23:40 |
| `47dd267592804bcf` | 0.1 | 13 | 0 | 2026-06-27 21:44 |
| `48eac75888177a20` | 0.1 | 1 | 0 | 2026-07-05 01:04 |
| `4c7aad272e1fa20a` | 0.1 | 1 | 0 | 2026-07-05 01:05 |
| `4d7ef73b1ad5b4fd` | 0.1 | 2 | 0 | 2026-07-05 01:04 |
| `4ebe5d8d8fdc9eab` | 0.1 | 1 | 0 | 2026-07-05 01:05 |
| `4ec1f5716ed047b9` | 0.1 | 12 | 0 | 2026-06-28 18:20 |
| `4fddf6594b76653c` | 0.1 | 1 | 0 | 2026-07-05 01:05 |
| `50cdabd9500dfc28` | 0.1 | 24 | 0 | 2026-08-26 21:10 |
| `50e43afe311c94da` | 0.1 | 1 | 0 | 2026-06-29 21:24 |
| `51099ae324c0463e` | 0.1 | 1 | 0 | 2026-07-05 01:05 |
| `51c0e1b7430b57db` | 0.1 | 1 | 0 | 2026-06-29 21:25 |
| `536a45cd2f7e1fcc` | 0.1 | 1 | 0 | 2026-07-05 01:06 |
| `54fddd22915a39b5` | 0.1 | 1 | 0 | 2026-06-29 21:24 |
| `5712007d0e7ba255` | 0.1 | 1 | 0 | 2026-07-05 01:04 |
| `57758d31b63888f4` | 0.1 | 1 | 0 | 2026-06-29 21:24 |
| `582d489c0cc7236e` | 0.1 | 1 | 0 | 2026-07-05 01:05 |
| `596ce0ad4d716663` | 0.1 | 24 | 0 | 2026-06-27 21:44 |
| `59fd8e01d1b14d78` | 0.1 | 1 | 0 | 2026-06-29 21:24 |
| `5aa4418ca17ec21e` | 0.1 | 1 | 0 | 2026-07-01 22:55 |
| `5b657859dc3ac6b0` | 0.1 | 1 | 0 | 2026-07-05 01:05 |
| `5c8db3b9665c9026` | 0.1 | 1 | 0 | 2026-07-05 01:04 |
| `5df4a4dceb8a39f6` | 0.1 | 11 | 0 | 2026-06-28 18:20 |
| `5e7a5b7a15f5c0ee` | 0.1 | 1 | 0 | 2026-07-05 01:06 |
| `5f58499905ec8c9b` | 0.1 | 7 | 0 | 2026-06-27 21:46 |
| `629d892526d5f8ae` | 0.1 | 2 | 0 | 2026-06-29 21:24 |
| `62fefa548865cbc4` | 0.1 | 20 | 0 | 2026-06-27 21:44 |
| `647cf18de24b631e` | 0.1 | 43 | 0 | 2026-06-28 18:22 |
| `6511a094d09bf4bb` | 0.1 | 9 | 0 | 2026-07-04 13:39 |
| `66bbab2944c26609` | 0.1 | 5 | 0 | 2026-06-27 21:44 |
| `68422c82916be790` | 0.1 | 1 | 0 | 2026-07-05 01:05 |
| `69a5e31ac008583b` | 0.1 | 2 | 0 | 2026-07-05 01:06 |
| `6b737c31340fa272` | 0.1 | 1 | 0 | 2026-06-29 21:26 |
| `6d0051cf54af0376` | 0.1 | 1 | 0 | 2026-07-05 01:05 |
| `6d9367afc88489c2` | 0.1 | 2 | 0 | 2026-07-05 01:05 |
| `6da4adb064547364` | 0.1 | 1 | 0 | 2026-07-26 19:32 |
| `6e2cf5c262fdd76f` | 0.1 | 1 | 0 | 2026-07-05 01:05 |
| `6f0f5aeb6a58d3a6` | 0.1 | 56 | 0 | 2026-06-27 21:44 |
| `6f2f37e13eb196aa` | 0.1 | 1 | 0 | 2026-07-05 01:05 |
| `701592287abd8a87` | 0.1 | 20 | 0 | 2026-06-27 21:44 |
| `70ccc9de563c6f38` | 0.1 | 1 | 0 | 2026-07-05 01:05 |
| `71fff8e3ed485a6c` | 0.1 | 30 | 0 | 2026-06-27 21:44 |
| `72217f810a0965b6` | 0.1 | 1 | 0 | 2026-07-05 01:05 |
| `72d73e81b7cc91fb` | 0.1 | 11 | 0 | 2026-06-28 18:20 |
| `74f337e5a0f49eb1` | 0.1 | 1 | 0 | 2026-06-29 21:26 |
| `767e0683a5227308` | 0.1 | 1 | 0 | 2026-07-05 01:06 |
| `76b84cfae1f2f601` | 0.1 | 1 | 0 | 2026-06-29 21:25 |
| `7726d7a055076e9c` | 0.1 | 1 | 0 | 2026-07-05 01:04 |
| `772a2197667fe135` | 0.1 | 1 | 0 | 2026-06-29 21:24 |
| `7a7085bb1908a258` | 0.1 | 18 | 0 | 2026-06-27 21:46 |
| `7c61627bca2d40d2` | 0.1 | 1 | 0 | 2026-07-05 01:04 |
| `7cd212ab754cd97d` | 0.1 | 1 | 0 | 2026-07-05 01:05 |
| `7d157220c56948af` | 0.1 | 1 | 0 | 2026-06-29 21:25 |
| `7da9b83aae738599` | 0.1 | 1 | 0 | 2026-06-29 21:24 |
| `7dafa11feab6a178` | 0.1 | 1 | 0 | 2026-07-05 01:06 |
| `7fcffa408dc45f3f` | 0.1 | 11 | 0 | 2026-06-27 21:44 |
| `808e7aac4cb5fcc8` | 0.1 | 2 | 0 | 2026-07-05 01:05 |
| `839ee73eb75e5361` | 0.1 | 1 | 0 | 2026-07-05 01:05 |
| `8418563d8adfced5` | 0.1 | 11 | 0 | 2026-06-28 18:20 |
| `89eea1f5558e5aa1` | 0.1 | 17 | 0 | 2026-06-27 21:46 |
| `8b38bf1bbb729f80` | 0.1 | 1 | 0 | 2026-07-05 01:04 |
| `8d6df59ea01a8ad4` | 0.1 | 1 | 0 | 2026-07-05 01:04 |
| `8ddbc6761815c53a` | 0.1 | 1 | 0 | 2026-07-05 01:04 |
| `8dffed2f004c6c6e` | 0.1 | 1 | 0 | 2026-07-05 01:05 |
| `91089131034bcd2f` | 0.1 | 1 | 0 | 2026-07-05 01:04 |
| `91105816a71ac42c` | 0.1 | 1 | 0 | 2026-07-05 01:05 |
| `91444354d2c59af1` | 0.1 | 2 | 0 | 2026-07-05 01:05 |
| `91dcaba4ac3ab46a` | 0.1 | 0 | 0 | 2026-07-26 22:57 |
| `932a286dae71400b` | 0.1 | 1 | 0 | 2026-07-05 01:06 |
| `9396cacfd78c1bae` | 0.1 | 12 | 0 | 2026-06-27 21:44 |
| `94521c6447b4073b` | 0.1 | 0 | 0 | 2026-07-27 00:40 |
| `9513bbebfcd4c458` | 0.1 | 24 | 0 | 2026-08-26 21:10 |
| `95426807fe20a08b` | 0.1 | 1 | 0 | 2026-07-05 01:04 |
| `97ad601531e72997` | 0.1 | 8 | 0 | 2026-06-27 21:44 |
| `9808a7f77d976cac` | 0.1 | 27 | 0 | 2026-07-09 23:57 |
| `98dfbc45dedde1dc` | 0.1 | 12 | 0 | 2026-06-28 18:20 |
| `99cdeb10c097a8ae` | 0.1 | 21 | 0 | 2026-06-28 11:53 |
| `99dc0fb321700ba1` | 0.1 | 1 | 0 | 2026-06-29 21:26 |
| `9a88aa72c6a2b0c3` | 0.1 | 1 | 0 | 2026-06-29 21:25 |
| `9ca7733d1d6d620e` | 0.1 | 1 | 0 | 2026-07-05 01:05 |
| `9e3cb9df03cbe22a` | 0.1 | 6 | 0 | 2026-06-27 21:35 |
| `9e7e4f46acfe4bc9` | 0.1 | 1 | 0 | 2026-07-05 01:05 |
| `9f635fea02669a03` | 0.1 | 36 | 0 | 2026-06-27 21:46 |
| `9fc69134080093e5` | 0.1 | 1 | 0 | 2026-07-05 01:04 |
| `a03b2e3b03b6ef54` | 0.1 | 9 | 0 | 2026-06-27 21:46 |
| `a3809b63340604fa` | 0.1 | 2 | 0 | 2026-07-05 01:05 |
| `a6cdc53565d8c53e` | 0.1 | 2 | 0 | 2026-06-29 21:25 |
| `a85e43803df4a952` | 0.1 | 1 | 0 | 2026-07-05 01:04 |
| `a91a833c96d0dd7c` | 0.1 | 1 | 0 | 2026-07-05 01:04 |
| `aa76bdedf4c1350e` | 0.1 | 18 | 0 | 2026-06-27 21:44 |
| `ab764893eedca09c` | 0.1 | 1 | 0 | 2026-06-29 21:24 |
| `ae13cf6e19778bf9` | 0.1 | 1 | 0 | 2026-06-29 21:26 |
| `af5581b5a02afe8e` | 0.1 | 1 | 0 | 2026-06-29 21:25 |
| `b01b9c320b03d222` | 0.1 | 7 | 0 | 2026-06-27 21:44 |
| `b0f6028b8ce3ba94` | 0.1 | 1 | 0 | 2026-06-29 21:25 |
| `b0fa370701ae0529` | 0.1 | 2 | 0 | 2026-06-29 21:25 |
| `b133be0616fd141b` | 0.1 | 1 | 0 | 2026-07-05 01:05 |
| `b2c56a929be09860` | 0.1 | 2 | 0 | 2026-07-05 01:05 |
| `b380ddf18f336afc` | 0.1 | 1 | 0 | 2026-07-05 01:04 |
| `b525dd25f9b9aa87` | 0.1 | 1 | 0 | 2026-07-05 01:05 |
| `b84018a50cd903a0` | 0.1 | 1 | 0 | 2026-06-29 21:25 |
| `b856320076af9757` | 0.1 | 1 | 0 | 2026-06-29 21:24 |
| `b8868c3313771aa4` | 0.1 | 2 | 0 | 2026-07-05 01:05 |
| `b9e129528f5d8396` | 0.1 | 1 | 0 | 2026-06-29 21:24 |
| `bbd3aabbbb06bdee` | 0.1 | 1 | 0 | 2026-07-05 01:05 |
| `bcb69a1910d6da3f` | 0.1 | 1 | 0 | 2026-07-05 01:05 |
| `be782a5eed451630` | 0.1 | 1 | 0 | 2026-06-29 21:24 |
| `bf200a53e9927227` | 0.1 | 2 | 0 | 2026-06-29 21:24 |
| `bf8a6fc5f5264ef0` | 0.1 | 12 | 0 | 2026-06-28 18:20 |
| `c189dbddcb8102d2` | 0.1 | 1 | 0 | 2026-07-05 01:04 |
| `c26ff1c60dbe6f2e` | 0.1 | 1 | 0 | 2026-07-05 01:05 |
| `c2a3d658641f6150` | 0.1 | 1 | 0 | 2026-07-05 01:05 |
| `c3a5454e67bda4fc` | 0.1 | 1 | 0 | 2026-07-05 01:06 |
| `c3d342dba37152c1` | 0.1 | 1 | 0 | 2026-06-29 21:25 |
| `c573d9dd1deccf5b` | 0.1 | 17 | 0 | 2026-06-27 21:44 |
| `c5a246c8819d63b5` | 0.1 | 1 | 0 | 2026-07-05 01:05 |
| `c84896e26d1137a9` | 0.1 | 23 | 0 | 2026-06-27 21:44 |
| `cc305394bc003ddb` | 0.1 | 14 | 0 | 2026-06-27 21:44 |
| `ccc078ea57b2fe9c` | 0.1 | 16 | 0 | 2026-07-04 23:34 |
| `cfc5d9d94f4bf27d` | 0.1 | 24 | 0 | 2026-06-27 21:44 |
| `d0bd3cad682eb7e0` | 0.1 | 1 | 0 | 2026-07-05 01:05 |
| `d173faf781cbdd8d` | 0.1 | 1 | 0 | 2026-07-05 01:06 |
| `d3be352c648df556` | 0.1 | 1 | 0 | 2026-07-05 01:06 |
| `d7312426cd894bf1` | 0.1 | 1 | 0 | 2026-07-05 01:04 |
| `da489d92759c446a` | 0.1 | 0 | 0 | 2026-07-26 22:57 |
| `db0938ca8a0ecf66` | 0.1 | 1 | 0 | 2026-07-05 01:05 |
| `db170584e69c54cc` | 0.1 | 39 | 0 | 2026-06-27 21:46 |
| `dbe378fe56d49288` | 0.1 | 32 | 0 | 2026-06-27 21:46 |
| `dc5b95709cc232a5` | 0.1 | 2 | 0 | 2026-07-05 01:05 |
| `ddcee6fad5353fc7` | 0.1 | 1 | 0 | 2026-07-05 01:05 |
| `de19c04f546d935b` | 0.1 | 1 | 0 | 2026-07-05 01:05 |
| `df05f5ff9ad67793` | 0.1 | 28 | 0 | 2026-06-28 18:22 |
| `e045c9d5acffd784` | 0.1 | 1 | 0 | 2026-07-05 01:05 |
| `e380cb1ce7d39c5b` | 0.1 | 1 | 0 | 2026-07-05 01:05 |
| `e5ddaec31ef354fd` | 0.1 | 12 | 0 | 2026-06-28 18:20 |
| `e749916a10167cae` | 0.1 | 1 | 0 | 2026-07-05 01:06 |
| `e7f4374b95f5101d` | 0.1 | 21 | 0 | 2026-06-27 21:44 |
| `e857186e0083b197` | 0.1 | 0 | 0 | 2026-07-26 19:23 |
| `e9a1ac0869165ac7` | 0.1 | 1 | 0 | 2026-07-05 01:05 |
| `e9e469d19a2c0d99` | 0.1 | 1 | 0 | 2026-07-05 01:04 |
| `ebb55f0ef3efd589` | 0.1 | 2 | 0 | 2026-07-05 01:04 |
| `eda559d9438539b7` | 0.1 | 1 | 0 | 2026-07-05 01:05 |
| `f17628b432665775` | 0.1 | 7 | 0 | 2026-06-27 21:44 |
| `f409e8480f352f01` | 0.1 | 1 | 0 | 2026-06-29 21:25 |
| `fb80c5c289d190ad` | 0.1 | 1 | 0 | 2026-07-05 01:05 |
| `fc7b087d35e89810` | 0.1 | 1 | 0 | 2026-06-29 21:25 |
| `fcfd52644d717ac1` | 0.1 | 17 | 0 | 2026-06-27 21:44 |
| `fed3d2aaeffb1ea0` | 0.1 | 1 | 0 | 2026-06-29 21:25 |

