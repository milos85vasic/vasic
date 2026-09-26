# Baseline sweep 2026-09-26 (feature 010, T036 re-baseline after the T038 review)

| Field | Value |
|---|---|
| Date | 2026-09-26 |
| Task | T036 re-baseline, following the T038 reviews (rev-base-A, rev-base-B) and fix rounds F1 and F2. **Nothing seeded**: no `gap add`, no register change; `docs/workable_items.db` sha256 prefix `9413fd96f2647c63` before and after |
| Composition | per-class snapshots. 15 classes on a frozen copy of `f05817ba3c7a`, `live-vs-source` on the LIVE tree at `f05817ba3c7a`, and `content-boundary-rows` from the first-pass copy of `50470448d594` (see the composition table) |
| Frozen copy | `rsync -a`, no hardlinks, of `f05817ba3c7a` (clean tree), on a disk-backed scratch outside the repository, removed afterwards. `.remember/.gitignore` was copied in, the fix for the T036 copy defect. `zg_fingerprint` `23a3b9ff6cce3059…` files=8447 was equal on the source before the copy, after the copy, on the copy, and before and after every run |
| Runner fingerprint | `fc67cecec2ab008b…` files=8447, identical before and after every class, in every run |
| Verdict of `report.txt` | `VERDICT VIOLATED rc=1 findings=1050 could-not-inspect=13 classes=16 unknown-recall=0` (16 classes: `content-boundary-rows` was not run in this sweep, see below) |
| Composed totals | **1239 rows, 1237 distinct (class, severity, category, location) keys** (`doc-count-drift` holds two keys twice each: `specs/008-unified-workshop-platform/tasks.md:3607` and `:3608` carry two claims each). By severity: 223 high, 755 medium, 261 low. 10 COULD-NOT-INSPECT lines in the composed view |
| Files | `report.txt` (runner stdout, run 3), `report.json` (runner `--json` run, same finding set as run 3), `FINDINGS-BY-CLASS.tsv` (one row per composed finding, with a 7th column `measured_on`), `content-boundary-rows-50470448.txt` and `live-vs-source-live-f05817ba.txt` (runner lines backing those two snapshots), `recall-table.md`, `superseded-first-pass/README.md` (the first pass, for history) |

## Composition: where each class was measured

| Class | Measured on | Runner output | rc | High | Medium | Low | CNI | Runtime (s) |
|---|---|---|---:|---:|---:|---:|---:|---:|
| build-if-missing | copy `f05817ba3c7a` | report.txt | 1 | 1 | 5 | 2 | 1 | 17.3 |
| content-boundary-rows | copy `50470448d594` (gate cache) | content-boundary-rows-50470448.txt | 1 | 186 | 0 | 0 | 2 | 21.4 |
| coverage-gaps | copy `f05817ba3c7a` | report.txt | 2 | 0 | 0 | 0 | 2 | 5.9 |
| doc-count-drift | copy `f05817ba3c7a` | report.txt | 1 | 3 | 10 | 225 | 0 | 13.3 |
| guard-gaps | copy `f05817ba3c7a` | report.txt | 1 | 21 | 0 | 0 | 0 | 13.3 |
| improvement-candidates | copy `f05817ba3c7a` | report.txt | 1 | 0 | 2 | 28 | 0 | 6.1 |
| known-open-decisions | copy `f05817ba3c7a` | report.txt | 1 | 0 | 3 | 0 | 0 | 6.4 |
| live-vs-source | LIVE tree `f05817ba3c7a` | live-vs-source-live-f05817ba.txt | 1 | 1 | 2 | 0 | 0 | 9.4 |
| missing-toolchain | copy `f05817ba3c7a` | report.txt | 1 | 0 | 0 | 4 | 0 | 6.8 |
| pointer-drift | copy `f05817ba3c7a` (remotes read live) | report.txt | 1 | 0 | 23 | 0 | 0 | 31.3 |
| private-in-public | copy `f05817ba3c7a` | report.txt | 1 | 0 | 7 | 0 | 0 | 8.2 |
| stale-figures | copy `f05817ba3c7a` | report.txt | 1 | 1 | 519 | 2 | 0 | 17.9 |
| unproven-checks | copy `f05817ba3c7a` | report.txt | 1 | 0 | 103 | 0 | 2 | 59.9 |
| unregistered-scripts | copy `f05817ba3c7a` | report.txt | 1 | 0 | 16 | 0 | 0 | 6.7 |
| unsealed-evidence | copy `f05817ba3c7a` | report.txt | 1 | 8 | 61 | 0 | 0 | 21.9 |
| untracked-blind-window | copy `f05817ba3c7a` | report.txt | 1 | 0 | 4 | 0 | 0 | 6.4 |
| vacuous-gates | copy `f05817ba3c7a` | report.txt | 1 | 2 | 0 | 0 | 3 | 7.5 |
| **total** | | | **1** | **223** | **755** | **261** | **10** | |

Runtime is the runner's per-class "fingerprint window" (the class on live + planted + clean, plus its
after-fingerprint). A full 16-class run took 235-251 s.

**Detection figure (binding wording)**: Planted-corpus detection: 1.0 (N = planted rows per class, 5-22, in
total 210), a regression check of known patterns; live-population recall UNMEASURED. For
`content-boundary-rows`: synthetic fleet, N = 6; not a recall of the gate. The corpora grew from 195 to 210
planted rows in fix rounds F1 and F2, and the per-class N is in `recall-table.md`. No RECALL-* finding was
emitted in any run.

## Identity

- **Runs 3 and 4** (16 classes, text): byte-identical, `cmp` equal, sha256 `f92eab8ae512c5ba…`, 280524 bytes,
  rc 1. `report.txt` is run 3.
- **The JSON run** (`--json`, sha256 `0fd79386df897488…`) holds the same 1050 finding lines as run 3
  (sorted, full text equal).
- **Runs 1 and 2 differ from each other, and only in `pointer-drift`.** Remote tips moved between the runs:
  every constitution remote read `2d8661414dbe` in run 1 and `647f7553533a` in runs 2-4 and the JSON run.
  Run 2 also had one gitlab `ls-remote` timeout (20 s), which the class reported as COULD-NOT-INSPECT, not as
  current. Every other class line of runs 1 and 2 is identical. So are the five changed classes
  (missing-toolchain, private-in-public, vacuous-gates, build-if-missing, guard-gaps) in all four text runs.
  `pointer-drift` is a `wire` class: its findings go stale with the remotes.

## content-boundary-rows: point-in-time from copy 50470448, live cache stale since

The standing ruling, as CONTINUATION.md:489 reads it: "`content-boundary-rows` reports rc 2 (cache absent)
in every sweep until the ONE-TIME cache refresh". The refresh was made once, in the first-pass copy of
`50470448d594`: the gate ran 2030 s, rc 1, with default parameters, a stable corpus and 14621 surviving rows,
and the stored cache has 0 `.match` keys. The 34-minute gate was NOT re-run for this re-baseline.

- On this copy of `f05817ba3c7a`, with the cache placed and its `.root` pointed at the copy, the class
  reported rc 2: "cache stale: 59 enumerated file(s) differ between the cached corpus manifest and the tree
  now". That result has no content, so it is not part of `report.txt`.
- Its baseline is the first-pass snapshot: 186 high findings over 121 public path classes, and 2
  COULD-NOT-INSPECT on the gate token (137 files not indexed by the gate; 3 undetermined rows). These are the
  verbatim runner lines in `content-boundary-rows-50470448.txt`. They are 186 unjudged rows: nothing was
  judged, allow-listed or subtracted.
- The live cache in `.remember/logs/zero-gap/` (git-ignored) went stale as soon as the tree moved past
  `50470448d594`.

## live-vs-source: live-tree result

This class is blind on a copy. On the copy, all 5 services were COULD-NOT-INSPECT: the compose label names
the live root, and the qa-up state files are git-ignored. It was therefore run once on the LIVE tree
(`zero-gap-sweep.sh --class live-vs-source`, rc 1, 5 of 5 inspected, 0 CNI, fingerprint unchanged in its
window). Its 3 findings are:

- **high build-freshness** `service:qa-up/workshop:commit`: the served build `185fb15-20260925T090616Z`
  reports source_commit `185fb158c4f4`, while workshop HEAD is `e076fa6aa26f` (1 commit ahead).
- **medium build-freshness** `service:compose/workshop-curriculum/platform:started`: container
  `42c12e533a91` was started at 2026-09-25T09:06:32Z, before source HEAD `e076fa6aa26f` was committed
  (2026-09-25T10:18:12Z).
- **medium false-evidence** `service:qa-up/ai:stamp`: the running binary's vcs.revision `923779e06397` is a
  commit of the umbrella, not of ai_interviewing, and `/api/health` carries no source_commit, so the served
  build cannot be tied to its source.

## Private paths (measured on FINDINGS-BY-CLASS.tsv)

**322 of the 1239 findings name a private path or private repository.** Every one of them carries only paths,
counts, units, commit ids or pattern names. Each group was checked against its fixed description template,
and the 19 free-form rows were read one by one.

- **128 are located inside a private repository**: 11 with a plain path location (build-if-missing 2,
  doc-count-drift 5, unproven-checks 4) and 117 doc-count-drift low rows located at `figures:<private path>`.
  113 of those 117 match the template "N unmeasurable recorded count(s) on line(s) …; first: <number>
  <unit>". The other 4 end "first: <number> entries of a backticked glob".
- **186** are the content-boundary-rows findings. Each names private repositories only as
  "private source repositories by path: <repo> <count>". All 186 match that template.
- **8 more** name a private path in the description or evidence_ref: doc-count-drift 5 (medium; the path is
  what was measured), improvement-candidates 2 (register item titles from the tracked
  `docs/workable_items.db`) and live-vs-source 1 (its compose file).

## Class caveats (from the T038 reviews, re-stated for this baseline)

- **known-open-decisions**: precision 1/3 (2 known FPs). The rows `progress.yml:68` and `:77` are review-log
  lines, not operator decisions.
- **private-in-public**: 7 findings, of which 1 is real (`docs/zero-gap/sweep-classes.tsv:21`). The other six
  are not guesses:
  - `progress.yml:43` is normative.
  - `progress.yml:72` and `:86` mention the vocabulary.
  - 3 are self-references from the first-pass baseline files (report.txt:465, FINDINGS-BY-CLASS.tsv:466,
    report.json:468). Each carries an improvement-candidates finding whose description copies the
    `progress.yml:43` sentence.

  **This re-baseline carries the same self-reference.** The improvement-candidates row for
  `progress.yml:43` sits in the new `report.txt`, `report.json` and `FINDINGS-BY-CLASS.tsv`, so the next
  sweep reports 3 rows from this directory in place of the 3 old ones. The F2 JSON fix removed the 123 false
  CRITICALs that the first-pass `report.json` produced.
- **coverage-gaps**: not inspected until T052; `docs/zero-gap/coverage.tsv` is absent. Population 0,
  COULD-NOT-INSPECT, never clean.
- **stale-figures**: read the 522 findings as **unanchored recorded figures (staleness unmeasured)**. The
  medium and low rows mean "this figure has no re-measure command", NOT "this figure is stale". Only figures
  with a `docs/claim-ledger.tsv` row are checked for staleness; the 1 high is such a figure. One known false
  negative: `CLAUDE.md:315` says "14 declared" while `.gitmodules` declares 22 paths (re-measured today). The
  class reports that line only as the unanchored figure '0 DRIFT'.
- **missing-toolchain**: depends on the caller's PATH. The probe PATH is recorded on the class's first stderr
  line and its sha in each finding. This run used the interactive PATH of the sweeping session, sha256
  `109a5efb81e1`, 303 entries, HOME shown as `~`. Its 4 findings are all low: docs_chain, ifconfig, lumen,
  shellcheck. The earlier 3 high (the class's own self-test strings) and 3 medium (bundle, jekyll, tesseract,
  which now resolve to their containerised route) are gone after F1. Under
  `env -i PATH=/usr/local/bin:/usr/bin:/bin`, F1 measured an extra high `derived:node`.
- **unregistered-scripts**: declared blind spot. Only `*.sh` files are in the population, so non-.sh
  executables are not seen (for example `_tests/preflight.js`, `_tools/translate/glossary_protect.py`).
- **guard-gaps**: the population is bounded by the catalogue `docs/zero-gap/guarded-commands.tsv` (26 rows,
  52 probe items). 21 of them are let through by the guard, including the 5 added in F2: `host-halt`,
  `host-reboot`, `remote-branch-delete-refspec`, `remote-branch-delete-flag` and `remove-home`. Commands
  outside the catalogue are not probed.
- **pointer-drift**: findings go stale with the remotes (shown above between runs 1 and 2).
- **vacuous-gates** 60 of 62 and **unproven-checks** / **build-if-missing** CNI: two non-shell pre-push
  gates (go test, Playwright) and one tracked symlink (`submodules/qa/scripts/anti-bluff-scan.sh`), refused
  by design.

## What changed since the first pass (copy of 50470448d594, 1229 rows)

Compared by (class, severity, category, location) key, 17 were added and 7 removed:

- **missing-toolchain** −6 (F1: self-scan false positives and the container route).
- **vacuous-gates** −1 (F2: proof-helper setup loop).
- **build-if-missing** +1 (F2: `scripts/verify-workable-items.sh:185`, a build in the `if` condition).
- **guard-gaps** +5 (F2: newly catalogued commands).
- **private-in-public** +4 (the first-pass baseline files and `progress.yml:86`).
- **doc-count-drift** +4 (new files between the two commits: `docs/zero-gap/module-page-walkthrough.md` and
  the first-pass baseline README and recall-table).
- **live-vs-source** +3 (live-tree run).

The first-pass `report.json` and `FINDINGS-BY-CLASS.tsv` are removed and remain in git at `f05817ba3c7a`
(sha256 `d611df067c89b823…` and `1b89d305326c247a…`).

## What a reviewer should check first

1. The live-vs-source high finding: a qa-up workshop server serving a build one commit behind its source.
2. The 21 high guard-gaps findings: destructive commands the PreToolUse guard lets through. The fix is
   upstream in the constitution guard.
3. The 186 unjudged content-boundary-rows findings: point-in-time data, older than the rest of this baseline.
4. The remaining highs: unsealed-evidence 8, doc-count-drift 3, vacuous-gates 2, stale-figures 1,
   build-if-missing 1.

## Reproduce

```bash
# a frozen real copy (rsync -a, never hardlinks) at an ABSOLUTE path, including .remember/.gitignore
bash scripts/zero-gap-sweep.sh --root <absolute path of the copy> $(awk -F'\t' '!/^#/ && NF && $1 != "class_id" && $1 != "content-boundary-rows" { printf "--class %s ", $1 }' docs/zero-gap/sweep-classes.tsv)
bash scripts/zero-gap-sweep.sh --root <absolute path of the copy> --class <class_id> --json
# live-vs-source is blind on a copy: run it on the checkout that serves
bash scripts/zero-gap-sweep.sh --root <absolute path of the live checkout> --class live-vs-source
```

## Honest limits

- Per-class snapshots of three states. The findings of the wire classes (pointer-drift, live-vs-source,
  guard-gaps and missing-toolchain, which read host tools and the PATH) describe the host at run time, not the
  copy.
- The identity evidence is 2 byte-identical text runs plus a JSON run of the same set. It is not the N = 5 of
  the T035 harness.
- Precision was not re-measured here. The T038 reviews measured it by hand per class.
- This directory's own files are tracked text that later sweeps read: doc-count-drift reports their figures,
  and private-in-public reports the self-reference above.

## Post-snapshot note (fix round F3, 2026-09-26)

After the snapshot of `f05817ba3c7a` a further fix round strengthened detectors in `missing-toolchain`
(symlinked container routes), `vacuous-gates` (whole-word proof-harness names; setup chains only when every
command is a fixture builder), `private-in-public` (unterminated JSON strings), `build-if-missing` (long
conditions) and `guard-gaps` (source wording), and added two cases to the determinism harness. Re-measured on the
quiet tree afterwards: the live findings of those classes are unchanged (`vacuous-gates` 2, `build-if-missing` 8,
`guard-gaps` 21, `missing-toolchain` unchanged) except `private-in-public`, which reads the ledger itself and moved
7 to 8 when the ledger grew (the new row is a vocabulary mention, not a finding of substance). The table above keeps
the `f05817ba3c7a` figures; no second full re-baseline was taken.
