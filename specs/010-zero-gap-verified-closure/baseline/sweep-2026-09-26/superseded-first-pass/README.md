> SUPERSEDED 2026-09-26 by the re-baseline in the parent directory (copy of f05817ba3c7a); kept for history only — its report.txt, report.json and FINDINGS-BY-CLASS.tsv were removed and remain in git at commit f05817ba3c7a.

# Baseline sweep 2026-09-26 (feature 010, task T036)

| Field | Value |
|---|---|
| Date | 2026-09-26 |
| Task | T036: BASELINE sweep of the real tree plus the per-class recall table. **Nothing seeded**: no `gap add`, no register change |
| Swept state | a frozen REAL copy (`rsync -a`, no hardlinks) of umbrella commit `50470448d594927522d2b23412c795849ab24f8e`, made on a disk-backed scratch outside the repository and removed afterwards |
| Copy fingerprint (`zg_fingerprint`) | `9685cc2ba4ab37b454011b783eb7fcccd9df5a7b793bbeccf5ca71c0c577064c` files=8407: live source before the copy = after the copy = the copy, and the copy unchanged before and after every sweep run |
| Runner fingerprint (`FINGERPRINT` lines) | `60c62213bae73f3ddaca63a34bf80615db8b458881c6ffdb466f3ac93bac97eb` files=8407, identical before and after every class |
| Verdict | `VERDICT VIOLATED rc=1 findings=1229 could-not-inspect=15 classes=17 unknown-recall=0` |
| Identity | run 1 and run 2 byte-identical: `cmp` equal, both sha256 `c67a9f5fb3212f26b907e715c2dab35cc7eb4380c2fb402c23c93901d58423f6`, 357029 bytes, rc 1, 267 s / 266 s |
| Files | `report.txt` (runner stdout, run 1), `report.json` (runner `--json`, a third run: rc 1, same fingerprints, the same 1229 (class, severity, category, location) set as `report.txt`), `recall-table.md`, `FINDINGS-BY-CLASS.tsv` (one row per FINDING: class, severity, category, location, description, evidence_ref) |

## Content-boundary cache (the one-time refresh)

The standing ruling for class `content-boundary-rows` reads, verbatim: **"until the one-time cache refresh
this class reports rc 2 (cache absent) in every sweep"**. That refresh was made here, inside the frozen copy,
by the recipe in the header of `scripts/zero-gap-class-content-boundary-rows.sh`:
`nice -n 10 bash scripts/verify-content-boundary.sh --root <copy> --json --expect-corpus <copy>/.remember/logs/zero-gap/content-boundary-rows.corpus`,
piped through `jq -c '.leaks |= map(del(.match))'`.

- Gate run: rc 1, **2030 s**, default parameters (windows 10/5/9, names on, direction `ran`), fleet derived from
  the provider, `corpus.stable=true`, 20646 manifest files; 14621 surviving rows (prose 12965, short 1073,
  name 178, fingerprint 405), 3 undetermined, 137 not indexed, 0 untracked files unscanned.
- Stored cache: `.leaks[]` rows carry only `class`, `line`, `private` (a path), `public` (a path); the count of the
  `match` key is **0**. No matched text is stored.
- So in THIS sweep the class did NOT report cache-absent: it read the cache, registered 186 path-class findings and
  kept 2 COULD-NOT-INSPECT lines on the gate token (137 unindexed files, 3 undetermined rows).
- A copy of the cache with `.root` set to the live root was placed in the live tree's git-ignored
  `.remember/logs/zero-gap/`. The live fingerprint still equalled the copy's afterwards, and the class run alone on
  the live root accepted it: rc 1, `INSPECTED 121`, the same 186 FINDING lines as in `report.txt`. **The cache goes
  stale the moment any fleet file changes.** From then on the class reports rc 2 with the refresh command until the
  refresh is repeated.
- An earlier gate run (2057 s) was DISCARDED. The copy lacked `.remember/.gitignore` (the file is ignored by its own
  `*` rule, so the ls-files-based copy drops it). The included `.remember/logs/zero-gap/` then became
  untracked-not-ignored, and the gate listed its own output files as unscanned untracked public files
  (`files_unscanned=2`). The copy was repaired (that one ignore file copied in, fingerprint back to `9685cc2b…`)
  and the gate was re-run. See "Defect found" below.

## Per-class result

| Class | rc | High | Medium | Low | CNI | Recall | Runtime (s) |
|---|---:|---:|---:|---:|---:|---:|---:|
| build-if-missing | 1 | 1 | 4 | 2 | 1 | 1.0 | 17.4 |
| content-boundary-rows | 1 | 186 | 0 | 0 | 2 | 1.0 | 21.4 |
| coverage-gaps | 2 | 0 | 0 | 0 | 2 | 1.0 | 5.9 |
| doc-count-drift | 1 | 3 | 9 | 222 | 0 | 1.0 | 13.5 |
| guard-gaps | 1 | 16 | 0 | 0 | 0 | 1.0 | 12.8 |
| improvement-candidates | 1 | 0 | 2 | 28 | 0 | 1.0 | 6.3 |
| known-open-decisions | 1 | 0 | 3 | 0 | 0 | 1.0 | 6.3 |
| live-vs-source | 2 | 0 | 0 | 0 | 5 | 1.0 | 8.3 |
| missing-toolchain | 1 | 3 | 3 | 4 | 0 | 1.0 | 7.2 |
| pointer-drift | 1 | 0 | 23 | 0 | 0 | 1.0 | 32.8 |
| private-in-public | 1 | 0 | 3 | 0 | 0 | 1.0 | 7.4 |
| stale-figures | 1 | 1 | 519 | 2 | 0 | 1.0 | 18.1 |
| unproven-checks | 1 | 0 | 103 | 0 | 2 | 1.0 | 60.8 |
| unregistered-scripts | 1 | 0 | 16 | 0 | 0 | 1.0 | 6.6 |
| unsealed-evidence | 1 | 8 | 61 | 0 | 0 | 1.0 | 22.2 |
| untracked-blind-window | 1 | 0 | 4 | 0 | 0 | 1.0 | 6.4 |
| vacuous-gates | 1 | 3 | 0 | 0 | 3 | 1.0 | 7.2 |
| **total** | **1** | **221** | **750** | **258** | **15** | 17/17 | 267 wall |

The class rc is derived from the runner's `status` field under the class contract (a finding outranks an
undetermined). The runner prints no per-class rc. Population, INSPECTED and planted-corpus sizes are in `recall-table.md`.

**Consistency check**: the T035 real run (same runner, no cache) recorded 1043 findings. 1043 + 186
content-boundary findings = 1229, the total here.

## Recall publication

`docs/zero-gap/README.md` defines the `recall` column of `docs/zero-gap/sweep-classes.tsv` as "the last PUBLISHED
figure … never read as a measurement", and tasks.md T038 says "ONLY THEN: … publish the recall table" after the
independent review. **The TSV was therefore NOT edited**: it still reads `UNKNOWN` for all 17 classes. The measured
figures (1.0 for all 17, on corpora of 5–19 planted rows) are in `recall-table.md` for T038 to publish.

## What a reviewer should check first

1. **`live-vs-source` is blind on a copy.** Its 5 COULD-NOT-INSPECT lines ("not running") are an artefact of the
   copy, not host state. Checked live the same day: container `workshop-curriculum_platform_1` is up, but its compose
   config-file label names the LIVE root, which the class (rooted at the copy) skips. The qa-up state files are
   git-ignored and were not copied. This `wire` class needs a separate live-tree run before T038 can treat its
   population as inspected.
2. **186 high `content-boundary-rows` findings.** These are the operator's unjudged reading assignment,
   registered by path class and count only. Nothing was judged, allow-listed or subtracted.
3. **16 high `guard-gaps`.** Destructive commands (for example `git add -A`, `git add .`) the PreToolUse guard lets
   through. The class classifies them as upstream (third-party) fixes.
4. **The other high findings**: `unsealed-evidence` 8, `vacuous-gates` 3, `missing-toolchain` 3,
   `doc-count-drift` 3, `stale-figures` 1, `build-if-missing` 1.
5. **Precision of the two largest classes.** `stale-figures` has 522 findings and `doc-count-drift` 234. Earlier
   reviews measured partial precision for both (progress.yml), and this baseline did not re-measure precision.
6. The 11 findings located inside private submodules (`build-if-missing` 2, `doc-count-drift` 5,
   `unproven-checks` 4). Their descriptions carry paths, line numbers, counts and filename patterns only. They were
   read before being written here and contain no quoted private prose, but that is one reader's judgement; a
   reviewer should re-read them.

## Defect found (recorded, not fixed)

- `scripts/zero-gap-determinism.sh` header (the `--include` help, which recommends
  `--include .remember/logs/zero-gap` for T036) and the copy step `det_rsync_copy`: an ignored path copied with
  `--include` loses its ignore rule when that rule lives in an ignore file that is itself ignored
  (`.remember/.gitignore` holds `*`). In the copy, the included directory becomes untracked-not-ignored and enters
  the fingerprint and every class population that walks untracked files. Here this showed up as the gate counting
  its own output (`untracked.files_unscanned=2`, fingerprint 8407 → 8409 files). Remedy: copy the ignore file(s)
  governing each `--include` path, or `.remember/.gitignore` explicitly. The same recipe text is in the header of
  `scripts/zero-gap-class-content-boundary-rows.sh` ("run the same gate command … inside a real copy").

## Honest limits

- One swept state only (the copy of `50470448d594`). The live tree may have moved since, and any change to a fleet
  file makes the live content-boundary cache stale (rc 2 until refreshed).
- The identity evidence covers 2 text runs plus 1 JSON run of the same state. It is not the N=5 of the T035 harness.
- Recall 1.0 is measured on small planted corpora (5–19 rows per class). It is a floor for those corpora, not a
  recall on the live population.
- Classes that consult the host (podman, remotes in `pointer-drift`, host tools in `missing-toolchain`, the guard
  in `guard-gaps`) read state outside the copy. The copy freezes only the tree.
- `coverage-gaps` stays COULD-NOT-INSPECT until T052.
- Per-class runtime is the runner's "fingerprint window" (class plus its after-fingerprint), not the class alone.
- The report and `FINDINGS-BY-CLASS.tsv` quote short excerpts of PUBLIC tracked documents in some descriptions
  (`improvement-candidates`, `known-open-decisions`, `stale-figures`, `private-in-public`). One `private-in-public`
  description quotes the guessing term it flags. These files are now tracked text, and later sweeps will read them.
