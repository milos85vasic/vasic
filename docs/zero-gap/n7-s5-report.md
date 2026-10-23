# Stream S5 report — spec 010 umbrella code (branch n7-010-complete, 2026-10-21/22)

Not a GO. Producer-prepared; every DONE below is PENDING-INDEPENDENT-REVIEW (`docs/zero-gap/n7s5/review-packets.md`). Evidence directory: `docs/zero-gap/n7s5/`. Nothing was pushed or merged; no gitlink changed.

| Task | State | Commit | RED -> GREEN |
|---|---|---|---|
| T062 | DONE | 80b6d2a | RED `T062-RED.txt` (script absent), `T062-freeze-RED.txt` (3 of 5 gate tests failed); GREEN `T062-prove-failure.txt` (15 cases), `T062-freeze-GREEN.txt` |
| T063 fix | DONE (found a regression in the earlier T063: schema `allOf` made EVERY sealing refuse) | 80b6d2a | RED `T063fix-RED.txt`; mutant `T063fix-MUTANT.txt` (3 tests); adapter proof 37 passed / 0 failed `T063fix-evidence-prove-failure.txt` |
| T064 | PARTIAL: harness + census run; 47 stable, 0 unstable, 20 not run | a3604c1, b1f0ab6, 0a4d926 | `T064-census-run.txt`, `docs/zero-gap/determinism-registry.tsv` |
| T065 | DONE | 14ca1b0, b1f0ab6 | RED `T065-RED.txt` (6 cases failed); GREEN `T065-GREEN.txt`; unsealed-evidence class gate findings 11 -> 0 (`T065-unsealed-class-after.txt`); dry run with the real adapter `T065-dryrun-real-adapter.txt` |
| T066 | PARTIAL (+2 rows; 2 stale figures fixed) | a3604c1 | `T066-RED.txt` -> `T066-GREEN.txt` |
| T067 | DONE as tables, SC-006 NOT met | 0b44d08 | `T067-tables.md` |
| T068 | DONE (V-G13; close/verdict require it unless `--skip-chain-binding REASON`) | a3604c1 | RED `T068-RED.txt` -> GREEN `T068-GREEN-fullpkg.txt`; real register: 88/88 records bind |
| T069 | DONE | 45962b1, b1f0ab6 | RED `T069-RED.txt`; hardlink mutant caught `T069-MUTANT-hardlink.txt`; proof 17 cases `T069-prove-failure.txt` |
| T070 | DONE (units NOT installed) | 45962b1 | `T070-systemd-analyze.txt` |
| T071 | DONE | 45962b1 | mutant `T071-MUTANT.txt` -> `T071-GREEN.txt` |
| T072, T083 | PREPARED, Operator-blocked | 45962b1 | `docs/zero-gap/operator-queue-S5.md`; anchor flow shown on a throwaway repo `T083-scratch-demo.txt` (verify rc 2 -> rc 0) |
| T037 | machine half DONE; human read pending | 06436f7 | script + 8-case proof |
| T050 | queue written for all 50 classified items (options/costs = labelled estimates) | ab1c050 | `docs/zero-gap/operator-queue-register-S5.md` |
| T053 | root re-measured; submodule subjects impossible here | ab1c050 | `T053-root-remeasure.txt` |
| T054-T056, T058-T060 | BLOCKED: modules are submodules, absent here, gitlinks untouchable | - | - |
| T057 | PARTIAL: +2 fuzz targets | 06436f7 | `T057-fuzz-*.txt` |
| T061, T051, T073, T079 | PENDING-INDEPENDENT-REVIEW (T079 table prepared) | 0b44d08 | `T079-sc-audit.md` |
| T074 | PARTIAL (freeze byte-identical; anchor operator-blocked) | 06436f7 | `T074-freeze-rederive.txt` |
| T075, T077 | PARTIAL (CONTINUATION Z2 + S5 section; 3 stale quickstart commands corrected) | ab1c050 | `T077-*.txt` |
| T076 | GAP: exports need the docs-chain tooling (absent here) | - | - |
| T078 | none needed | - | - |
| T080 | NOT DONE by design (no push) | - | - |
| T043-T049, T088-T090 | NOT CLOSED: register closure needs independent verifier + register commit; open/classified lists produced | - | `register-open-items.md` |
| T087 | re-run: 199 findings | b1f0ab6 | `T087-coverage-gaps-class-run.txt` |

## Other findings
* The live register has 35 findings at 2026-10-21 (V-G2 x16, V-G10 x18, V-G1 x1): elapsed recheck / plan dates. Needs operator re-dating.
* Two exempt rows in `check-registry.tsv` had elapsed cadence; re-verified (proof 9/0) and re-dated, registry now 160 PASS / 0 FAIL.
* The sweep `--prove-failure` shows 4 failures here caused by the environment (3 cases name submodule paths; 1 timing case under host load).
* `zero-gap-determinism.sh` refuses a linked worktree.

## Final check
`bash scripts/verify-check-registry.sh` -> see the last message.
