# Per-class recall table: baseline sweep 2026-09-26 (T036)

| Field | Value |
|---|---|
| Source | `report.txt` in this directory (runner stdout, run 1; run 2 byte-identical) |
| Swept state | frozen real copy of umbrella commit `50470448d594`; runner fingerprint `60c62213bae73f3d…` (files=8407) before and after |
| Recall | MEASURED by the runner on each class's planted corpus this run (`_tests/fixtures/zero-gap/<class>/expect.tsv`); NOT yet published — `docs/zero-gap/sweep-classes.tsv` still reads `UNKNOWN` for every class (publishing is T038's step, after independent review) |
| Runtime | the runner's own per-class "fingerprint window" (class runs on live + planted + clean, plus the after-fingerprint), from its stderr |

Class rc follows the class contract: a finding outranks an undetermined, so `findings` means rc 1 and
`could-not-inspect` with zero findings means rc 2. CNI = COULD-NOT-INSPECT lines in the report.
Population and INSPECTED are the runner's `CLASS` line fields. "Planted" is the number of rows in the corpus
`expect.tsv`, i.e. the denominator of the recall figure: a recall of 1.0 on a small corpus is a floor
for that corpus only, never a measurement of the live population.

| Class | Population | Inspected | High | Medium | Low | Findings | CNI | Recall | Planted | Status (class rc) | Runtime (s) |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|
| `build-if-missing` | 13 | 13 | 1 | 4 | 2 | 7 | 1 | 1.0 | 12 | findings (1) | 17.4 |
| `content-boundary-rows` | 121 | 121 | 186 | 0 | 0 | 186 | 2 | 1.0 | 6 | findings (1) | 21.4 |
| `coverage-gaps` | 0 | 0 | 0 | 0 | 0 | 0 | 2 | 1.0 | 10 | could-not-inspect (2) | 5.9 |
| `doc-count-drift` | 1520 | 1520 | 3 | 9 | 222 | 234 | 0 | 1.0 | 14 | findings (1) | 13.5 |
| `guard-gaps` | 42 | 42 | 16 | 0 | 0 | 16 | 0 | 1.0 | 5 | findings (1) | 12.8 |
| `improvement-candidates` | 216 | 216 | 0 | 2 | 28 | 30 | 0 | 1.0 | 12 | findings (1) | 6.3 |
| `known-open-decisions` | 3 | 3 | 0 | 3 | 0 | 3 | 0 | 1.0 | 11 | findings (1) | 6.3 |
| `live-vs-source` | 5 | 5 | 0 | 0 | 0 | 0 | 5 | 1.0 | 13 | could-not-inspect (2) | 8.3 |
| `missing-toolchain` | 37 | 37 | 3 | 3 | 4 | 10 | 0 | 1.0 | 11 | findings (1) | 7.2 |
| `pointer-drift` | 132 | 132 | 0 | 23 | 0 | 23 | 0 | 1.0 | 19 | findings (1) | 32.8 |
| `private-in-public` | 25 | 25 | 0 | 3 | 0 | 3 | 0 | 1.0 | 19 | findings (1) | 7.4 |
| `stale-figures` | 1545 | 1545 | 1 | 519 | 2 | 522 | 0 | 1.0 | 15 | findings (1) | 18.1 |
| `unproven-checks` | 838 | 837 | 0 | 103 | 0 | 103 | 2 | 1.0 | 18 | findings (1) | 60.8 |
| `unregistered-scripts` | 109 | 109 | 0 | 16 | 0 | 16 | 0 | 1.0 | 5 | findings (1) | 6.6 |
| `unsealed-evidence` | 69 | 69 | 8 | 61 | 0 | 69 | 0 | 1.0 | 10 | findings (1) | 22.2 |
| `untracked-blind-window` | 59 | 59 | 0 | 4 | 0 | 4 | 0 | 1.0 | 5 | findings (1) | 6.4 |
| `vacuous-gates` | 62 | 60 | 3 | 0 | 0 | 3 | 3 | 1.0 | 10 | findings (1) | 7.2 |
| **total** | | | **221** | **750** | **258** | **1229** | **15** | 17 of 17 at 1.0 | 195 | VIOLATED (sweep rc 1) | 267 wall |

## Reading the table

- **Every recall is 1.0 and no RECALL-* finding was emitted** (`grep -c RECALL- report.txt` = 0). That is the planted
  corpora being found, not a statement about the live population.
- **`coverage-gaps`**: population 0 is by design until T052 generates `docs/zero-gap/coverage.tsv`; the class is
  COULD-NOT-INSPECT (never clean), as tasks.md T032 requires.
- **`live-vs-source`** (population kind `wire`): its 5 CNI are an ARTEFACT OF SWEEPING A COPY, not the host state.
  Measured on the live host the same day: container `workshop-curriculum_platform_1` is running (its compose
  config-file label names the LIVE root's `workshop/platform/compose.yml`, so the class, rooted at the copy, skips it),
  and the qa-up state files `workshop/platform/run/server.json`, `ai_interviewing/platform/run/server.json` and
  `.service-registry/qa/*` exist live but are git-ignored and were not copied. This class needs a live-tree run to
  inspect anything.
- **`content-boundary-rows`**: 186 findings over 121 path classes come from the one-time gate cache (14,621 surviving
  rows). The class still reports 2 CNI on the gate token (137 files the gate did not index; 3 undetermined rows).
- **`unproven-checks` 837 of 838, `build-if-missing` 1 CNI**: `submodules/qa/scripts/anti-bluff-scan.sh` is a tracked
  symlink (mode 120000) to `anti-bluff/bluff-scanner.sh`; both classes refuse non-regular files by design.
- **`vacuous-gates` 60 of 62**: `scripts/pre-push-gates.sh` gate_1 (go test) and gate_6 (Playwright) are non-shell
  gates the analyser cannot read.
