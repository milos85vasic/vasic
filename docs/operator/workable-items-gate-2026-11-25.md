# Workable-items gate: remaining findings for the operator, 2026-11-25

| | |
|---|---|
| Date | 2026-11-25 |
| Gate | `bash scripts/verify-workable-items.sh` |
| Anchors | §11.4.33, §11.4.90, §11.4.93, §11.4.95, §11.4.148, §11.4.6 |

This PR fixed what the sanctioned tooling could fix from evidence (3 title read-back violations, 5 missing provenance rows, the PSG-007 V-G1 finding that was an uninitialised submodule). The 69 findings below are NOT cleared: no date was extended, no item was re-classified without evidence, and `gap close` was not used because it needs an independent verifier verdict (V-G3, §11.4.240) that one agent cannot honestly supply. Each row is an item whose recheck or plan date elapsed.

V-G2 = classification recheck elapsed; V-G10 = open item whose plan_due elapsed. Re-measure with `_tools/workable-items/bin/workable-items-vsc validate`.

| Id | Rule | Status | Re-judgement from current evidence |
|---|---|---|---|
| AII-002 | V-G10 | Queued | not judgeable from evidence in this pass; operator or owning agent to re-judge |
| AII-003 | V-G2 | Operator-blocked | not judgeable from evidence in this pass; operator or owning agent to re-judge |
| AII-004 | V-G2 | Operator-blocked | not judgeable from evidence in this pass; operator or owning agent to re-judge |
| AII-005 | V-G2 | Operator-blocked | not judgeable from evidence in this pass; operator or owning agent to re-judge |
| CON-002 | V-G10 | Queued | pin f92868dd7036 now EQUALS remote HEAD (git ls-remote 2026-11-25); condition appears met, closure needs an independent verifier verdict (gap close) |
| CON-003 | V-G2 | Queued | not judgeable from evidence in this pass; operator or owning agent to re-judge |
| CON-004 | V-G2 | Queued | not judgeable from evidence in this pass; operator or owning agent to re-judge |
| CON-005 | V-G2 | Queued | not judgeable from evidence in this pass; operator or owning agent to re-judge |
| CON-006 | V-G2 | Queued | not judgeable from evidence in this pass; operator or owning agent to re-judge |
| CON-007 | V-G2 | Queued | not judgeable from evidence in this pass; operator or owning agent to re-judge |
| CON-008 | V-G2 | Queued | not judgeable from evidence in this pass; operator or owning agent to re-judge |
| CON-009 | V-G2 | Queued | not judgeable from evidence in this pass; operator or owning agent to re-judge |
| HLP-001 | V-G2 | Operator-blocked | gitlink bd302c8ab57d now EQUALS remote HEAD (ls-remote 2026-11-25); closure needs independent verifier |
| HQA-001 | V-G10 | Queued | not judgeable from evidence in this pass; operator or owning agent to re-judge |
| LLP-001 | V-G2 | Operator-blocked | gitlink bd302c8ab57d now EQUALS remote HEAD (ls-remote 2026-11-25); closure needs independent verifier |
| LMV-001 | V-G2 | Operator-blocked | gitlink 94e666d416f0 now EQUALS remote HEAD (ls-remote 2026-11-25); closure needs independent verifier |
| LMV-002 | V-G2 | Operator-blocked | not judgeable from evidence in this pass; operator or owning agent to re-judge |
| LMV-003 | V-G2 | Operator-blocked | not judgeable from evidence in this pass; operator or owning agent to re-judge |
| MON-001 | V-G10 | Queued | not judgeable from evidence in this pass; operator or owning agent to re-judge |
| PSG-007 | V-G10 | Queued | still unfixed: os.WriteFile remains at registry.go:672, registry.go:945, symbol.go:286 in the pinned passage submodule |
| VSC-028 | V-G10 | Queued | not judgeable from evidence in this pass; operator or owning agent to re-judge |
| VSC-070 | V-G2 | Operator-blocked | not judgeable from evidence in this pass; operator or owning agent to re-judge |
| VSC-078 | V-G2 | Operator-blocked | not judgeable from evidence in this pass; operator or owning agent to re-judge |
| VSC-079 | V-G2 | Operator-blocked | not judgeable from evidence in this pass; operator or owning agent to re-judge |
| VSC-125 | V-G2 | Operator-blocked | not judgeable from evidence in this pass; operator or owning agent to re-judge |
| VSC-285 | V-G2 | Operator-blocked | operator block still recorded (tokens); not re-measured here |
| VSC-293 | V-G2 | Operator-blocked | not judgeable from evidence in this pass; operator or owning agent to re-judge |
| VSC-300 | V-G2 | Operator-blocked | not judgeable from evidence in this pass; operator or owning agent to re-judge |
| VSC-301 | V-G2 | Operator-blocked | not judgeable from evidence in this pass; operator or owning agent to re-judge |
| VSC-349 | V-G10 | Queued | not judgeable from evidence in this pass; operator or owning agent to re-judge |
| VSC-351 | V-G10 | Queued | not judgeable from evidence in this pass; operator or owning agent to re-judge |
| VSC-354 | V-G10 | Queued | not judgeable from evidence in this pass; operator or owning agent to re-judge |
| VSC-356 | V-G10 | Queued | not judgeable from evidence in this pass; operator or owning agent to re-judge |
| VSC-357 | V-G10 | Queued | not judgeable from evidence in this pass; operator or owning agent to re-judge |
| VSC-358 | V-G10 | Queued | not judgeable from evidence in this pass; operator or owning agent to re-judge |
| VSC-362 | V-G2 | Operator-blocked | not judgeable from evidence in this pass; operator or owning agent to re-judge |
| VSC-367 | V-G2 | Operator-blocked | not judgeable from evidence in this pass; operator or owning agent to re-judge |
| VSC-368 | V-G2 | Operator-blocked | not judgeable from evidence in this pass; operator or owning agent to re-judge |
| VSC-369 | V-G2 | Operator-blocked | not judgeable from evidence in this pass; operator or owning agent to re-judge |
| VSC-370 | V-G2 | Operator-blocked | not judgeable from evidence in this pass; operator or owning agent to re-judge |
| VSC-371 | V-G2 | Operator-blocked | not judgeable from evidence in this pass; operator or owning agent to re-judge |
| VSC-378 | V-G10 | Queued | not judgeable from evidence in this pass; operator or owning agent to re-judge |
| VSC-379 | V-G10 | Queued | not judgeable from evidence in this pass; operator or owning agent to re-judge |
| VSC-380 | V-G10 | Queued | not judgeable from evidence in this pass; operator or owning agent to re-judge |
| VSC-387 | V-G2 | Operator-blocked | not judgeable from evidence in this pass; operator or owning agent to re-judge |
| VSC-389 | V-G2 | Operator-blocked | not judgeable from evidence in this pass; operator or owning agent to re-judge |
| VSC-390 | V-G2 | Operator-blocked | not judgeable from evidence in this pass; operator or owning agent to re-judge |
| VSC-391 | V-G2 | Operator-blocked | not judgeable from evidence in this pass; operator or owning agent to re-judge |
| VSC-392 | V-G2 | Operator-blocked | not judgeable from evidence in this pass; operator or owning agent to re-judge |
| VSC-393 | V-G2 | Operator-blocked | not judgeable from evidence in this pass; operator or owning agent to re-judge |
| VSC-394 | V-G2 | Operator-blocked | not judgeable from evidence in this pass; operator or owning agent to re-judge |
| VSC-395 | V-G2 | Operator-blocked | not judgeable from evidence in this pass; operator or owning agent to re-judge |
| VSC-396 | V-G10 | Queued | not judgeable from evidence in this pass; operator or owning agent to re-judge |
| VSC-397 | V-G2 | Operator-blocked | not judgeable from evidence in this pass; operator or owning agent to re-judge |
| VSC-398 | V-G2 | Operator-blocked | node _tests/preflight.js in the main checkout printed READY (0) with chromium, firefox, webkit launching (2026-11-25); closure needs independent verifier |
| WSP-028 | V-G2 | Operator-blocked | not judgeable from evidence in this pass; operator or owning agent to re-judge |
| WSP-042 | V-G2 | Operator-blocked | not judgeable from evidence in this pass; operator or owning agent to re-judge |
| WSP-054 | V-G2 | Operator-blocked | not judgeable from evidence in this pass; operator or owning agent to re-judge |
| WSP-060 | V-G2 | Operator-blocked | not judgeable from evidence in this pass; operator or owning agent to re-judge |
| WSP-062 | V-G2 | Operator-blocked | not judgeable from evidence in this pass; operator or owning agent to re-judge |
| WSP-066 | V-G2 | Operator-blocked | not judgeable from evidence in this pass; operator or owning agent to re-judge |
| WSP-068 | V-G2 | Operator-blocked | not judgeable from evidence in this pass; operator or owning agent to re-judge |
| WSP-125 | V-G2 | Operator-blocked | not judgeable from evidence in this pass; operator or owning agent to re-judge |
| WSP-151 | V-G10 | Queued | tasks.md T019 is ticked [x] "CLOSED IN 008 AS T127" with the note that gates were not re-run; item still Queued; closure/obsolete needs an independent verifier |
| WSP-165 | V-G10 | Queued | not judgeable from evidence in this pass; operator or owning agent to re-judge |
| WSP-166 | V-G10 | Queued | not judgeable from evidence in this pass; operator or owning agent to re-judge |
| WSP-167 | V-G2 | Operator-blocked | not judgeable from evidence in this pass; operator or owning agent to re-judge |
| WSP-168 | V-G2 | Operator-blocked | not judgeable from evidence in this pass; operator or owning agent to re-judge |
| WSP-169 | V-G2 | Operator-blocked | not judgeable from evidence in this pass; operator or owning agent to re-judge |
