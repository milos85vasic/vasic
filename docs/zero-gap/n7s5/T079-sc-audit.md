# T079 — SC-001..SC-011 audit table (producer-prepared; PENDING-INDEPENDENT-REVIEW)

Environment: linked worktree `n7-010-umbrella`, submodules absent (so results about submodule subjects are not obtainable here). Nothing below is a GO.

| SC | Command | Captured output | State |
|---|---|---|---|
| 001 | `bash scripts/zero-gap-sweep.sh --json --out .remember/logs/zero-gap/run{1,2}`; `cmp` | both sha256 `6469c2d5fad5...`, cmp rc 0 (`T077-q1-sweep-determinism.txt`); 824 findings, 607 could-not-inspect | MET in this environment, on a quiet tree (a first attempt during my own edits correctly reported UNSTABLE) |
| 002 | `bash scripts/zero-gap-sweep.sh --prove-failure` | 124 passed / 4 failed (`T077-q4-...txt`): I6 x3 name paths inside absent submodules, R2-I5 a 121 s flood case under host load | NOT shown here; re-run in the main checkout |
| 003 | `workable-items-vsc gap summary`; `validate` | 94 gap items: 25 closed / 50 classified / 19 open; 35 findings (V-G1 1, V-G2 16, V-G10 18: elapsed dates) | NOT met |
| 004 | `validate --chain-store`-equivalent measurement | 88 of 88 cited records of 25 closed items bind to the chain; none shares a session (`T068-real-register-binding-measurement.txt`); V-G3 raises nothing on closed items | MET structurally; independent re-run (T073) not done |
| 005 | `bash scripts/zero-gap-class-coverage-gaps.sh --root .` | 199 findings, 12 could-not-inspect (`T087-...`) | NOT met |
| 006 | `bash scripts/zero-gap-determinism-registry.sh --runs 5` | 47 stable / 0 unstable / 20 not run to completion (`T067-tables.md`) | NOT met (incomplete) |
| 007 | `bash scripts/verify-check-registry.sh` | 160 PASS / 0 FAIL (structure) | MET structurally; `--run-proofs` not run |
| 008 | `bash scripts/zero-gap-scan-records.sh docs/zero-gap specs/010-zero-gap-verified-closure --private-root ...` | VERDICT HOLDS (rc 0) | MET for guessing/credential/private; "unmeasured assertions" NOT shown |
| 009 | `go test ./internal/wi -run TestT071` (real daily script + real apply-queue, disposable repo) | PASS; mutant caught (`T071-*.txt`) | MET in a disposable copy; the 24 h cadence needs the timer (OQ-S5-TIMER) |
| 010 | `bash scripts/zero-gap-module-page-check.sh` | page in ~0.1 s, 23 modules; HOLDS | machine half only; human timed read NOT done |
| 011 | register: V-G4 / V-G6 | no V-G4 or V-G6 finding; `freeze` re-derives byte-identically (`T074-freeze-rederive.txt`) | MET structurally for the frozen cycle |
