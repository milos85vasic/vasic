# Umbrella gap register, 2026-11-24

| Field | Value |
|---|---|
| Date | 2026-11-24 |
| Scope | Umbrella repo `milos85vasic/vasic` root and its own tooling: `_tools/gen`, `_tools/career`, `_tools/containers`, `_tests`, `scripts/`, `design-system`, `_tools/deploy-langs.sh`. Not `job_seeker` (separate agent). |
| Operator order | 2026-11-24, gaps, weak spots and danger zones investigated to root cause, covered by 10+ test types with machine-produced deterministic evidence (§11.4.169, §11.4.262, §11.4.289, §11.4.102) |
| Measured at | umbrella `main` merge `3fd715b` (worktree off `github/main`, submodules initialised with `--reference`), host Ubuntu 26.04, Go, Node 20, Python 3 |
| Companion | [`umbrella-test-type-matrix-2026-11-24.md`](umbrella-test-type-matrix-2026-11-24.md) |
| Status vocabulary | DETERMINED (root cause measured, captured output exists), UNDETERMINED (named reason, next step stated), FIXED-IN-THIS-PR, OPERATOR (host or provider action) |

Every reading below is a dated measurement from this session. Re-run the named command; do not quote a number from here (§11.4.6).

## Contents

1. [Register](#register)
2. [Fixed in this PR](#fixed-in-this-pr)
3. [Details per gap](#details-per-gap)
4. [Top risks](#top-risks)

## Register

| ID | Gap | State | Root cause (one line) | Next owner |
|---|---|---|---|---|
| UG-01 | Gate 6 webkit missing libs | DETERMINED, carrier claim CORRECTED 2026-11-25 (four root carriers); `_site` build still open (item 7) | `libmanette-0.2-0` and `libwoff1` are now installed; webkit launches. The remaining preflight blocker is a missing `milosvasic.ru/_site` | build step, see UG-01 |
| UG-02 | `build_warn` tolerance in deploy-langs | DETERMINED, partly closed, one misreport FIXED | tolerated set is deliberate (per-language gen and pdf); `pdf built` echo printed after a tolerated failure | FIXED-IN-THIS-PR |
| UG-03 | Claims drift (`verify-claim-ledger`) | DETERMINED green, slice only | 11 recorded claims, all agree; coverage is a slice, 520 unanchored figures in `CONTINUATION.md` | backlog B6 |
| UG-04 | Remote-sync false DRIFT for uninitialised submodules | DETERMINED, FIXED-IN-THIS-PR | `git -C <empty submodule dir> rev-parse --git-dir` walks up to the superproject and reads ITS pushurl | FIXED-IN-THIS-PR |
| UG-05 | Upstream-sync exemption hides the mirror's `master` read-back | DETERMINED (design, recorded) | exemption row matches the whole mirror URL for the submodule check | operator decision |
| UG-06 | Upstream-sync rc 2 in worktrees (uninitialised submodules, nested constitution submodules) | DETERMINED | instrument reports `declared submodule is not initialised` per submodule; 20 undetermined rows in a partly initialised worktree | backlog B5 |
| UG-07 | content-boundary RED by design | see section | reading recorded below | operator (decision packet in carrier) |
| UG-08 | Hardcoded-path and environment-assumption audits | DETERMINED measurement, fixes owned by agent a3ac97ad | 11011 and 8943 occurrences in a fully initialised tree, mostly consumed submodules | a3ac97ad |
| UG-09 | Docs-chain check C-set | UNDETERMINED | `docs_chain` binary absent: nested submodule `constitution/submodules/docs_chain` not initialised and not built | backlog B5 |
| UG-10 | Constitution sweep, failures actionable in this tree | DETERMINED partial; carrier sentence CORRECTED 2026-11-25; PR #93 had pushed the zero-findings ratchet to 9 > 7 with two `t.Skip` lines, removed 2026-11-25 (live 7 <= 7 again) | the three carrier-named gates now PASS; 4 of the first failing gates are REFUSE rc 4 caused by uninitialised nested constitution submodules; sweep does not finish in a session | backlog B5, B7 |
| UG-11 | `continuation-check` DRIFT C3 | DETERMINED | three gitlink-bump commits changed watched governance files without touching `CONTINUATION.md` | backlog B6 |
| UG-12 | Paired proofs that could false-green (§11.4.201) | DETERMINED sample, no vacuous mutant found in 4 targeted mutants; one crude mutation method rejected | see section | backlog B8 |
| UG-13 | `_tools/containers/cmd/site-build` and `internal/orchestrate` have no Go tests | DETERMINED | `go test` prints `[no test files]` for both; they are the only Jekyll build path | backlog B2 |
| UG-14 | Harness self-validation UNDETERMINED in a fresh worktree | DETERMINED | `@playwright/test` not installed (`_tests/node_modules` absent); gate returns rc 2 correctly | environment, B5 |
| UG-15 | `perf-budget.json` rewritten non-deterministically by test runs, summary doc quotes stale numbers | FIXED by PR #90 (evidence stability) | committed JSON says `vasic.digital/` 324,494 B, `playwright-summary.txt` says 221,252 B; the main checkout shows the JSON modified | backlog B3 |
| UG-16 | `TEST-TYPES.md` a11y row lists one spec; two exist | DETERMINED, FIXED-IN-THIS-PR | `vasic-digital-a11y.spec.js` exists and passes (12 passed webkit) | FIXED-IN-THIS-PR |
| UG-17 | No deploy rollback tooling | DETERMINED | `grep -n rollback _tools/deploy-langs.sh` returns nothing; only `rollback-agents-wizard.sh` exists | backlog B4 |
| UG-19 |  cross-language test fails | MITIGATED by PR #91 (vault skip); the owner still decides whether the submodule should ship the file | the test requires , which is not in the pinned submodule; the test fails instead of skipping | backlog B2 area, owner of the vault feature |
| UG-18 | Root `main` behind `github/main` between worktree creation and PR | DETERMINED | `verify-upstream-sync` reported `tip 3a46674… not in the local object store` for the root | merge before PR |

## Fixed in this PR

1. UG-04. `scripts/verify-submodule-remote-sync.sh` gains `own_repo`, used where it previously asked `rev-parse --git-dir`. RED before, GREEN after, captured: before the fix a worktree with uninitialised submodules printed 10 `DRIFT REMOTE-SYNC <path> push target 1 — DIFFERS` rows that all named the umbrella's own URL `git@github.com:milos85vasic/vasic.git`; after the fix the same worktree prints 0 such rows (21 CURRENT, 1 DRIFT where the 1 is `job_seeker`, a real remote-ahead drift, 0 UNDETERMINED). A paired proof `P18` was added to `--prove-failure`; with the fix reverted the proof fails (`P18 … rc=2, wanted 0. THIS GATE WOULD BE A SHAM`), with the fix it passes and the control stays green.
2. UG-02 (misreport only). `_tools/deploy-langs.sh` printed `[deploy-langs] pdf built: <lang>` unconditionally after a tolerated `pdf <lang>` failure. The line now prints only on success.
3. UG-16. `_tests/TEST-TYPES.md` row 6 now names both a11y specs.

## Details per gap

### UG-01 gate 6, webkit

Carrier text says webkit cannot launch because `libmanette-0.2-0` and `libwoff1` are missing, and that fixing it is an operator action (`sudo apt-get install -y libmanette-0.2-0 libwoff1`). Measured now:

```
dpkg -s libmanette-0.2-0 libwoff1        -> Status: install ok installed  (both)
node _tests/preflight.js                 -> browser OK webkit: launched and closed cleanly
npx playwright test --project=webkit vasic-digital-a11y -> 12 passed (40.9s)
```

So the carrier claim "webkit BLOCKED" is stale on this host: someone installed the packages (an operator action, not done here). On a host without them the remedy remains the operator package install above. What still blocks gate 6: `milosvasic.ru/_site` does not exist in a fresh worktree (`preflight.js` prints `CANNOT DETERMINE (2)`, `MV_BASE serves milosvasic.ru/_site, which does not exist`). Remedy per the preflight: `_tools/containers/bin/site-build -workload jekyll` (container build; not run in this session, heavy). State: DETERMINED. The carrier sentence should be corrected by whoever next edits the carriers (they are byte-identical across four files; not edited here to avoid a lockstep conflict with other PRs).

### UG-02 deploy-langs

The 2026-09-08 change already split the set: `en gen`, `pdf en`, jekyll rebuild are FATAL (`build_fail`, exit 5), toolchain-absent is `build_undet` (exit 2), and `gen <lang> vasic|milos` and `pdf <lang>` stay `build_warn` by design (a half-written language is an expected state, the previous generation is republished). `grep -n build_warn _tools/deploy-langs.sh` shows the remaining tolerated call sites at the `gen <lang>` pair and the `pdf <lang>` step in the per-language loop. The residual defect found is the misreport above. There is no remaining silent-success path for the fatal steps. Not changed: whether the tolerated steps should be fatal for a language the cycle itself declares COMPLETE. That is a product decision; backlog B4.

### UG-03 claims

`bash scripts/verify-claim-ledger.sh` rc 0: `every one of the 11 recorded claim(s) is still made and still agrees`. The gate states its own limit: the ledger is a slice. `zero-gap-class-stale-figures` reports 478 findings (`CONTINUATION.md` 520 figures with no re-measure command, `README.md` 3 including `'20 owned'`). Finding count is a coverage measure, not a defect count. The carrier statements fixed in this session sit outside the ledger: the webkit claim (UG-01) and the three sweep FAILs named in the carrier (UG-10) were both stale and neither was a ledger row.

### UG-05 and UG-06 upstream-sync

`config/upstream-parity-exemptions.tsv` carries one row (`submodules/doc_processor`, mirror `HelixDevelopment/DocProcessor`). The decision record `OPERATOR-DECISION-DOC-PROCESSOR-BRANCH-MASTER-2026-11-24.md` states the consequence itself: the row exempts that URL for the whole submodule check, so its `master` is no longer read back either. That is the gap: the exempt mirror's `master` could drift without any verifier noticing. Smallest closing change (not made, it changes an instrument that reads an operator decision): exempt only the `main` ref, keep reading `master`. Recorded as an operator decision candidate.

In a worktree, `bash scripts/verify-upstream-sync.sh` printed `RESULT: BEHIND-OR-DIVERGED (1 finding(s), 20 undetermined)` with rows `CANNOT-DETERMINE <path> declared submodule is not initialised` (including six nested constitution submodules). The 1 finding is the root itself, `DIFFERS … tip 3a46674 not in the local object store`, because other PRs landed after the worktree was cut. The instrument is honest (rc 2 rows are not passes); the gap is that a fresh worktree cannot reach a verdict without `git submodule update --init --recursive`.

### UG-07 content boundary

RED by design. Reading from a fully initialised worktree (all 23 submodules, `env -u GITHUB_TOKEN`): see the section at the end of this file, filled in from the captured log.

### UG-08 audits (owned by agent a3ac97ad, not fixed here)

Fully initialised worktree, captured logs: `audit-hardcoded-paths.sh` `❌ 11011 occurrence(s) across 853 file(s)` (728 of the flagged files are inside `submodules/constitution`, 119 in `workshop`, 3 in `job_seeker`); `audit-environment-assumptions.sh` `❌ 8943 frozen environment assumption(s)` (1560 files, 417 in `submodules/constitution`, 272 `workshop`, 244 `submodules/llms_verifier`, 194 `submodules/qa`, 167 `job_seeker`). Both counts moved by orders of magnitude against the carrier's 2026-09 readings (1 and 0) because the fleet population grew to 23 submodules and the constitution pin moved. Whether a regression exists in umbrella-owned files is UNDETERMINED here: no per-file comparison against the previous baseline was made. Next step for the owner: filter to umbrella-owned paths.

### UG-09 docs-chain

`verify-docs-chain.sh` prints `UNDETERMINED: no docs_chain binary is resolvable`. Root cause: `submodules/constitution/submodules/docs_chain` is a nested submodule, uninitialised in this worktree, and its binary is not built. Build recipe is printed by the gate. A 2 is not a pass; the C-checks have no reading here.

### UG-10 sweep

`verify-all-constitution-rules.sh` was started and measured for about 50 minutes; it had reported 11 PASS, 5 FAIL, 7 ERROR when stopped being useful: `cm_agent_type_label_mutation_test.sh` ERROR rc=124 after 900223 ms (the sweep's own gate timeout), and four `cm_anchor_*` gates ERROR rc=4 because `submodules/constitution/submodules/continuum` has no `go.mod` (nested submodule uninitialised, `REFUSE … carries no go.mod`, which the gate itself says decides nothing). The three gates named in the carrier now PASS when run directly: `cm_readme_badge_row_at_top` rc 0 (12 badges), `cm_zero_findings_audit_sweep` rc 0, `cm_zero_findings_monotone_ratchet` rc 0 (`live=7 <= ceiling=7`). The carrier's "none acted on" sentence is stale. A complete sweep split is NOT claimed.

### UG-11 continuation

`bash scripts/continuation-check.sh` after initialising `workshop`: 7 PASS, 1 DRIFT, 0 UNDET, rc 1. The one DRIFT is C3: commits `74889b2dd5b4`, `6fc143d974ce`, `178cc2ba525b` changed watched governance files without updating `CONTINUATION.md` (§12.10 protection 2). (Before `workshop` was initialised the same run read 22 DRIFT, 21 of them C5 entry points inside `workshop/`; that is the uninitialised-submodule effect again, not a document defect.)

### UG-12 vacuous-mutant sampling (§11.4.201)

Method one (rejected): a blanket `sed` turning every `exit 1` into `exit 0` outside proof lines, then running `--prove-failure`. For `verify-manifest-pins.sh` the 11 changed lines were all inside fake-`stat` shims and the proof stayed green. That is evidence the mutation was off target, not that the proof is vacuous, so no claim is made from it.

Method two (targeted, verdict-computation edits, `--prove-failure` rc under the mutant, captured in `targeted-mutants.txt`):

| Gate | Mutation | Proof rc under mutant |
|---|---|---|
| `verify-manifest-pins.sh` | final `exit "$_rc"` becomes `exit 0` | 1 (caught) |
| `verify-claim-ledger.sh` | finding branch threshold `-gt 0` becomes `-gt 9999` | 1 (caught) |
| `verify-claim-ledger.sh` | UNDETERMINED branch `-gt 0` becomes `-gt 9999` | 1 (caught) |
| `verify-claim-ledger.sh` | vacuity guard `ROWS -eq 0` becomes `-eq 9999` | 1 (caught) |
| `verify-submodule-remote-sync.sh` | revert `own_repo` fix | proof P18 fails rc 2 (caught) |

No vacuous mutant found in this sample of 3 gates. The static class `zero-gap-class-vacuous-gates` read `INSPECTED 79`, 0 findings, 2 COULD-NOT-INSPECT (the two `pre-push-gates.sh` non-shell gates, 1 and 6). Earlier reviewer findings of vacuous mutants are not reproduced here. The sample is 3 of 79 registered checks; it does not bound the rest. `check-registry` structure: 164 PASS, 0 FAIL, 0 DEBT (structure only; `--run-proofs` takes about an hour and was not run).

### UG-13 containers tests

`go test ./...` in `_tools/containers`: `cmd/site-build` and `internal/orchestrate` `[no test files]`; `cmd/runtime-probe`, `cmd/port-discover`, `internal/runnersel`, `cmd/distribute-helixtranslate` pass. 477 lines of untested code sit on the only local Jekyll build path.

### UG-17 rollback

`deploy-langs.sh` regenerates, commits and pushes each site, then validates live. There is no step that reverts a pushed deployment when live validation fails. `milosvasic.ru` publishes through the active `pages.yml` and must not be changed. A rollback is `git revert` of the pushed commit through the normal PR path (merge commit, never force); no automation or test exists for it.

## Top risks

The ten highest, in order (identifiers refer to the backlog in the matrix companion):

1. B1 fleet gates reaching a verdict in a fresh worktree (UG-04 fixed here, UG-06 and UG-09 open).
2. B2 no tests on the Jekyll build path `site-build` and `internal/orchestrate` (UG-13).
3. B3 evidence that churns: `perf-budget.json` and homepage screenshots (UG-15).
4. B4 no rollback path for a failed live validation on two production sites (UG-17), and a tolerated per-language failure that republishes a stale generation (UG-02).
5. B5 nested constitution submodules uninitialised: sweep REFUSE rc 4, docs-chain UNDETERMINED (UG-06, UG-09, UG-10).
6. B6 stale carrier text that already misled (webkit libs, three sweep gates) and a `CONTINUATION.md` C3 DRIFT (UG-01, UG-10, UG-11).
7. B7 sweep never completes in a session; one gate hits its 900 s timeout (UG-10).
8. B8 paired-proof coverage sampled on 3 of 79 gates, no vacuous mutant found, the rest unmeasured (UG-12).
9. UG-19 a test that fails on a file the pinned submodule does not ship (`vault.js`).
10. UG-05 an exemption row that stops a mirror's `master` from being read back.

## Content-boundary reading (UG-07)

Command: `env -u GITHUB_TOKEN bash scripts/verify-content-boundary.sh` in a worktree with all 23 submodules initialised and no other writer touching that worktree (a separate worktree was used for the PR edits so the scanned corpus stayed fixed). The gate admitted itself under `agent-admit` and runs under `bounded-run -m 6G -T 3600`. State at the time this file was written: the run was still executing after 38 minutes (the gate's own bound is 60); no verdict line exists yet, so this reading is UNDETERMINED at the time of this commit. The result is appended below by a follow-up commit on this branch if it completes before merge, otherwise the next session must re-run the command above.

The designed verdict (RED, rc 1, a reading assignment and not a regression) is unchanged and is not made green here: no allow-list entry, no baseline move and no redaction was made.
