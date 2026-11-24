# Zero-findings ratchet burn-down, 2026-11-24 (VSC-432, closes VSC-422)

Operator decision 2026-11-24: burn the ratchet down. Roadmap-Item: VSC-432.

## RED, reproduced live at commit d1aeb48 (main, before any edit)

    bash scripts/audit/zero_findings_sweep.sh
      gaps 6, weak-spots 2, danger-zones 32, todo-fixme 2, skipped-tests 21, others 0   (TOTAL 63)
      RATCHET REFUSED  weak-spots 2 > 1 ; danger-zones 32 > 9 ; todo-fixme 2 > 0 ; skipped-tests 21 > 7 ; TOTAL 63 > 23
      SWEEP REFUSES THE SEAM

## GREEN after the change (same command, branch pr/ratchet-burndown-1)

      gaps 6, weak-spots 0, danger-zones 0, todo-fixme 0, skipped-tests 1   (TOTAL 7)
      every class is within its ratchet ceiling (7 finding(s) total)
    bash scripts/audit/zero_findings_sweep.sh --prove-failure   -> 17/17 mutations caught (detector unchanged)

## What was done, per class

| Class | Before | After | How |
|---|---:|---:|---|
| weak-spots | 2 | 0 | real fix: `set -u` in `scripts/install_skills.sh`; `set -u` in the direct-run block of `scripts/zero-gap-lib.sh` (a sourced library must not change its caller's options) |
| danger-zones | 32 | 0 | 3 real fixes (`eval "$oldnull"` nullglob restore removed in `verify-check-registry.sh`; two log-message rewordings in `zero-gap-class-guard-gaps.sh` and `zero-gap-coverage.sh`); 29 lines carry the detector's own line marker `DANGER-OK: <reason>` where the pattern is DATA (probe strings, flag tables, synthetic-repo commits) or an eval of a constant / in-repo-extracted / operator-supplied string |
| todo-fixme | 2 | 0 | two planted fixture comments reworded from the literal marker word to NOTE; the two class `--prove-failure` proofs still pass |
| skipped-tests | 21 | 1 | 19 skips carry `SKIP-OK: VSC-433` (conditional on an absent tool/host condition, each prints SKIPPED, not a pass) or `SKIP-OK: VSC-434` (three live specs deferred to the post-deploy live config, still in its testMatch and in deploy-langs LIVE_SPECS) |
| gaps | 6 | 6 | untouched: open rows of docs/constitution-adoption/INVENTORY.md |

Remaining 7: six open INVENTORY gap rows, and `.github/workflows/ci.yml.disabled` (file kept by the 11.4.156 decision; removing it is an operator decision under 11.4.122).

Ceilings were only LOWERED (weak-spots 1->0, danger-zones 9->0, skipped-tests 7->1, TOTAL 23->7) with `--write-ratchet`, which refuses a raise.

## Side effects handled

`scripts/verify-check-registry.sh` FACT DRIFT on five `exempt` rows whose files were edited (install_skills, rollback-agents-wizard, setup-agents-wizard, zero-gap-lib, zero-gap-evidence set); each reason was re-read (the edits add no verdict) and the field refreshed with `--print-fact-hash`. The two remaining FAILs (`scripts/qa-up.sh`, `_tools/lib/vasic-runner.sh`) are pre-existing on main and not touched.

Proofs run: `guard-project-catalogue.sh --prove-failure`, `zero-gap-lib.sh --prove-failure` (30/30), class proofs build-if-missing (32/32), unsealed-evidence (25/25), guard-gaps (25/25).
