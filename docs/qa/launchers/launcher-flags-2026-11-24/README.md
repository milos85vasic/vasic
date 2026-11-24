# Launcher flag fixes, 2026-11-24 (VSC-417)

- milosvasic.ru PR #3 (start.sh --help / unknown args rc 2): RED/GREEN/prove-failure files here; live-site verifier before/after the merge (both VERDICT PASS, regressions=0).
- job_seeker PR #55 (jsstack clean rc 2 on unset compose vars; jobseekerd --help rc 0): js-RED / js-GREEN files.
- Umbrella: qa-up parse-time check of a FORCED --runner name. qa-up-RED/GREEN are scripts/verify-runner-flag.sh runs.
- Honest boundary: qa-up-prove-failure-partial.txt holds M0-M7 of the full --prove-failure run (each mutant takes ~8 min; the run was stopped). New mutants M12 and M14 were caught and M13 is caught only by the no-Go case, in a manual targeted run, not by the full harness.
