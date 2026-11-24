# Launcher `--runner` matrix, 2026-11-24

Real runs, no mocks, host: podman present, docker absent. `matrix.tsv` is produced by
`run-matrix.sh`; every cell has its raw output under `raw/`. `live.*` are real start/stop runs
(workshop: isolated project `zzz-runner-matrix` on :18087, never the live :8087 stack).

Columns: accepts `--runner=podman` / `--runner podman` / `CONTAINERS_RUNNER=podman`;
`--help` rc 0; `--runner=bogus` (both spellings) and `CONTAINERS_RUNNER=bogus` rc 2; absent
runner (docker) rc 2, no fallback. Container-free launchers (od/start-daemon, run-isolated)
accept the flag and print "no containers used" (their bogus/absent cells are `OK(ignored)`).

Result: 16 of 18 rows PASS. The 2 GAP rows (`workshop/scripts/status.sh`, `workshop/scripts/run-isolated.sh`)
are real gaps in the merged workshop `main` (status.sh ignored every argument; run-isolated.sh refused
the flag). The fix is committed on workshop branch `pr/status-runner-flag` (oracle 36/0, `--prove-failure` 11 killed /
0 survived; proof of the fixed behaviour: `raw/fix-pending.workshop-pr-status-runner-flag.txt`) but could NOT be
pushed: the workshop pre-push materials gate blocks it and the offline bypass was refused. Operator action needed.

Earlier in this session the matrix also found `submodules/containers/cmd/boot` exiting 1 (not 2) for an
absent forced runner: fixed upstream already (exitCodeFor); the umbrella gitlink + helix-deps ref were bumped
2d18551c6c99 -> eb70e05439f3 and the row is now PASS.
