# Per-class recall table: baseline 2026-09-26 (T036 re-baseline after T038 review)

| Field | Value |
|---|---|
| Composition | per-class snapshots; the "Measured on" column names the state of each class |
| Source files | `report.txt` / `report.json` (16 classes, copy of `f05817ba3c7a`), `content-boundary-rows-50470448.txt` (first-pass runner lines of that class, copy of `50470448d594`), `live-vs-source-live-f05817ba.txt` (runner `--class live-vs-source` on the LIVE tree at `f05817ba3c7a`) |
| Detection figure | Planted-corpus detection: 1.0 (N = planted rows per class, 5-22, in total 210), a regression check of known patterns; live-population recall UNMEASURED. For `content-boundary-rows`: synthetic fleet, N = 6; not a recall of the gate |
| Published? | NO. `docs/zero-gap/sweep-classes.tsv` still reads `UNKNOWN`; publishing is the controller's step |
| Runtime | the runner's per-class "fingerprint window" in seconds (class runs on live + planted + clean, plus its after-fingerprint), from its stderr |

Class rc follows the class contract (a finding outranks an undetermined): findings => 1, could-not-inspect
with no finding => 2. CNI = COULD-NOT-INSPECT lines. Population and Inspected are the runner's `CLASS` fields.
"Planted" is the number of rows of the class's corpus `expect.tsv` at `f05817ba3c7a` (at `50470448d594` for
content-boundary-rows): the denominator of the detection figure.

| Class | Measured on | Population | Inspected | High | Medium | Low | Findings | CNI | Detection | Planted (N) | rc | Runtime (s) |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| `build-if-missing` | copy of `f05817ba3c7a` | 13 | 13 | 1 | 5 | 2 | 8 | 1 | 1.0 | 14 | 1 | 17.3 |
| `content-boundary-rows` | copy of `50470448d594` (gate cache, point-in-time) | 121 | 121 | 186 | 0 | 0 | 186 | 2 | 1.0 | 6 | 1 | 21.4 |
| `coverage-gaps` | copy of `f05817ba3c7a` | 0 | 0 | 0 | 0 | 0 | 0 | 2 | 1.0 | 10 | 2 | 5.9 |
| `doc-count-drift` | copy of `f05817ba3c7a` | 1531 | 1531 | 3 | 10 | 225 | 238 | 0 | 1.0 | 14 | 1 | 13.3 |
| `guard-gaps` | copy of `f05817ba3c7a` | 52 | 52 | 21 | 0 | 0 | 21 | 0 | 1.0 | 5 | 1 | 13.3 |
| `improvement-candidates` | copy of `f05817ba3c7a` | 216 | 216 | 0 | 2 | 28 | 30 | 0 | 1.0 | 12 | 1 | 6.1 |
| `known-open-decisions` | copy of `f05817ba3c7a` | 3 | 3 | 0 | 3 | 0 | 3 | 0 | 1.0 | 11 | 1 | 6.4 |
| `live-vs-source` | LIVE tree at `f05817ba3c7a` | 5 | 5 | 1 | 2 | 0 | 3 | 0 | 1.0 | 13 | 1 | 9.4 |
| `missing-toolchain` | copy of `f05817ba3c7a` | 30 | 30 | 0 | 0 | 4 | 4 | 0 | 1.0 | 15 | 1 | 6.8 |
| `pointer-drift` | copy of `f05817ba3c7a` | 132 | 132 | 0 | 23 | 0 | 23 | 0 | 1.0 | 19 | 1 | 31.3 |
| `private-in-public` | copy of `f05817ba3c7a` | 31 | 31 | 0 | 7 | 0 | 7 | 0 | 1.0 | 22 | 1 | 8.2 |
| `stale-figures` | copy of `f05817ba3c7a` | 1545 | 1545 | 1 | 519 | 2 | 522 | 0 | 1.0 | 15 | 1 | 17.9 |
| `unproven-checks` | copy of `f05817ba3c7a` | 838 | 837 | 0 | 103 | 0 | 103 | 2 | 1.0 | 18 | 1 | 59.9 |
| `unregistered-scripts` | copy of `f05817ba3c7a` | 109 | 109 | 0 | 16 | 0 | 16 | 0 | 1.0 | 5 | 1 | 6.7 |
| `unsealed-evidence` | copy of `f05817ba3c7a` | 69 | 69 | 8 | 61 | 0 | 69 | 0 | 1.0 | 10 | 1 | 21.9 |
| `untracked-blind-window` | copy of `f05817ba3c7a` | 59 | 59 | 0 | 4 | 0 | 4 | 0 | 1.0 | 5 | 1 | 6.4 |
| `vacuous-gates` | copy of `f05817ba3c7a` | 62 | 60 | 2 | 0 | 0 | 2 | 3 | 1.0 | 16 | 1 | 7.5 |
| **total** | | | | **223** | **755** | **261** | **1239** | **10** | 17 of 17 at 1.0 | 210 | | |
