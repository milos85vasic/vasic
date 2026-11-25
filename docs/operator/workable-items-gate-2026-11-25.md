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

## Second pass, 2026-11-25 (re-judgement from current evidence)

Method: `gap classify` (the only CLI path that changes a recheck date) was run through `_tools/workable-items/bin/workable-items-vsc` for items whose block was RE-MEASURED today and still holds, keeping reason, owner and block text unchanged and setting `--recheck 2026-12-09` (14 days). No plan date was edited, no item was closed, and nothing was classified from a guess. `validate` before 67 V-G2/V-G10 findings in this checkout, after 49 (V-G2 48 to 30, V-G10 19 unchanged). Issues.md and Fixed.md regenerated with `sync db-to-md`: byte-identical, because recheck dates are not rendered. Issue-sync stayed in dry-run.

Re-affirmed (18), with the evidence:

| Ids | Why the block still holds |
|---|---|
| CON-003..CON-008 (third-party) | Guard script at constitution `0d9e638f69d9` (equals remote HEAD by `git ls-remote`) fed the seven probes `reboot`, `git branch -D`, `git reset --hard`, `git add -A`, `pkill -f`, `rm -rf ~`, `git checkout -- .`: all rc 0 (not blocked). Control probes `git push --force` and `sudo systemctl suspend` returned rc 2, so the harness does refuse. |
| CON-009 | Depends on the content-boundary decision below; no decision record exists. |
| VSC-389..VSC-395 | Decision `G-content-boundary-rows-01` appears only in the register itself; no operator decision record under `docs/` resolves it. |
| HLP-001, LLP-001 | Gitlink `bd302c8ab57d` vs `ls-remote` HEAD `97af6f0c7ef4`: still behind; bump is an operator decision. |
| VSC-387, VSC-397 | `docs/operator-decisions/` D-02 (2026-10-21) records rotation as DEFERRED by the operator. |

### Closure candidates (work appears delivered; NOT closed, because `gap close` needs RED+GREEN evidence records, an independent verifier verdict and a reviewer verdict that one agent cannot supply, §11.4.240)

| Id | Evidence seen today |
|---|---|
| VSC-070 | workshop `364850d3d9a6` carries `verify-/prove-g-http-5-...` and `verify-/prove-g-cli-13-...` |
| VSC-079 | workshop carries `verify-/prove-g-pid-6-ingest.sh` and `scripts/ingest.sh` |
| VSC-367 | `.claude/settings.json` line 16 wires `scripts/hooks/guard-project-catalogue.sh` |
| VSC-285 | `GITFLIC_TOKEN` and `GITVERSE_TOKEN` are set in the environment (names only checked) |
| VSC-398 | previous pass: `node _tests/preflight.js` READY (0) |
| AII-003 | ai_interviewing `d508b8e16697` has `--prove-failure` arms in `platform/qa/challenges/api-challenges.sh` and `scripts/validate-exports.sh` |
| AII-005 | same commit exposes `source_commit` and `source_dirty` in `/api/health` |
| WSP-068 | workshop has `verify-/prove-containers-actually-booted.sh` |
| CON-002 | constitution pin equals remote HEAD (`0d9e638f69d9`) |

Note: LMV-001, listed in the first table, is already Completed; that row was stale.

### Decisions needed (not resolvable by this pass)

1. V-G10, 19 open items (AII-002, CON-002, HQA-001, MON-001, PSG-007, VSC-028, VSC-349, VSC-351, VSC-354, VSC-356..358, VSC-378..380, VSC-396, WSP-151, WSP-165, WSP-166): no CLI command re-dates an open item's `plan_due` (`gap reopen --plan-due` applies to closed items only; `classify` clears `plan_due` and needs one of four reasons that do not fit docs-hygiene work). Options: (a) add a `gap replan --id --plan-due --reason` subcommand (code change, tests, independent review); (b) do the work and close with evidence; (c) operator picks a documented reason.
2. V-G2 items not re-judged (30): AII-004, LMV-002, LMV-003, VSC-078, VSC-125, VSC-293, VSC-300, VSC-301, VSC-362, VSC-368..371, WSP-028, WSP-042, WSP-054, WSP-060, WSP-062, WSP-066, WSP-125, WSP-167, WSP-168, plus the closure candidates above. Each needs the owning repo's current state read, then a re-classify or an independent-verifier closure.
3. Confirm whether the 2026-10-27 "do not rotate keys" decision extends to VSC-387/397 (it names Yandex, GitHub PAT and DeepSeek keys only).
4. G5 also reports 2 V-G1 and 1 V-G6 on PSG-007 and WSP-169 in a fresh worktree; the PSG-007 one is the uninitialised submodule, WSP-169 (Obsolete, zero-gap columns wiped) is unexamined.
