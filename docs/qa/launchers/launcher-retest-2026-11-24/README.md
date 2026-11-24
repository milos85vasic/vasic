# Launcher retest 2026-11-24 (VSC-417)

Real runs on the development host (podman 5.7.0, docker ABSENT, podman graphroot on the data disk).
Every row of [matrix.md](matrix.md) is a command that was executed here, with its captured output in `raw/*.txt`
(tail of each run + `--- rc=N`). No mocks, no stubs. Nothing that was not started by this test was touched; the
other containers on the host were left alone. Scratch copies used alternative ports (18087, 18099, 18199, 14000,
discovered qa-up ports) and were stopped afterwards: no container, process or listener of ours is left (checked
with `podman ps -a` and `ss -ltn`).

## Scope and what was tested against what

| launcher | tested from | notes |
|---|---|---|
| workshop `scripts/{start,stop,restart,status}.sh` (shipped, main checkout, pin d58ae75d) | main checkout | NO `--runner` yet: `--runner=podman` is correctly refused as unknown argument (rc 2) |
| workshop `--runner` branch `pr/runner-flag` (7797b732, local only, blocked at the materials gate) | clean worktree, project `wsretest`, port 18087 | reported separately; positive path with real container |
| ai_interviewing `platform/scripts/{start,stop,restart,status}.sh` | worktree of origin/main (30da696, then the fix) | native process, `--runner` validated, no containers |
| milosvasic.ru `start.sh` | worktree of origin/main (9b5bf27) | dry-run matrix + a real `--runner=podman` container serve on 14000 |
| umbrella `scripts/qa-up.sh` | main checkout, state/registry dirs in scratch | vd, mv (--no-rebuild), workshop (reused live), ai |
| umbrella tools (hawkscan, helixtranslate-local, od/start-daemon, deploy-langs --prove-args) and Go tools (runtime-probe, site-build, ocr) | main checkout / built into scratch | refusal matrix; no real deploy, no translation |
| job_seeker `jsstack`, `make live-h3 RUNNER=podman`, `gates/verify_runner_flag.sh` | worktree of github/main (dfeee77), containers submodule 2d18551c | real container HTTP/3 + Brotli gate |
| vasic.digital | n/a | static, no launcher; served by qa-up (`--only vd`, HTTP 200) |

## Matrix summary (steps run / steps with non-zero rc)

| launcher | steps | rc != 0 |
|---|---|---|
| workshop (shipped) | 24 | 7 |
| workshop (`--runner` branch) | 24 | 10 |
| ai_interviewing | 23 | 8 |
| milosvasic.ru | 14 | 5 |
| qa-up | 24 | 7 |
| umbrella tools | 13 | 11 |
| umbrella Go tools | 17 | 12 |
| job_seeker | 22 | 15 |

A non-zero rc is the EXPECTED result for refusal rows (docker forced -> rc 2, bogus runner -> rc 2, `--runner`
without value -> rc 2, unknown flag -> rc 2, status of a stopped stack, curl against a stopped port rc 7). The rows
whose non-zero rc was NOT an intended refusal are listed here, none hidden:

- workshop `--runner` branch, first `start-runner-podman-altport`: rc 1, build failed because my scratch umbrella
  lacked the `replace` targets of platform/backend/go.mod (test-harness layout, not a launcher defect); fixed by
  linking the submodules, second run rc 0.
- umbrella: `ocr-run.sh --prove-args` rc 3 (that flag belongs to `deploy-langs.sh`; ocr-run runs inside the
  container, my misuse), `port-discover` rows rc 1 (positional syntax, my misuse; qa-up exercised it for real).
- `od/start-daemon.sh --help` rc 1 (macOS app absent; the script has no help and does not parse unknown flags).
- job_seeker: `jsstack down` with the compose variables unset: podman-compose Python traceback, rc 1 (the gate
  always supplies them through `jsstack port`; ugly but intended precondition); `jobseekerd -h` rc 1 because
  config validation (`JOBSEEKER_DB_KEY missing`) runs before help.

## Checks that hold everywhere they apply

- Forced `docker` (flag or `CONTAINERS_RUNNER`) refused rc 2, no fallback, before any side effect: workshop branch,
  ai_interviewing, milosvasic.ru, qa-up (workshop/ai paths), hawkscan, helixtranslate-local, runtime-probe,
  site-build, ocr, jsstack, live_h3.
- Bogus runner rc 2 with the supported list; `--runner` / `--runner=` without value rc 2.
- Precedence flag > env > default: `CONTAINERS_RUNNER=docker` + `--runner=auto` resolves to podman; env alone docker
  refused; env podman accepted.
- Idempotent start (double start), idempotent stop (stop when stopped rc 0), restart when stopped and when running.
- After each stop: no leftover container/listener of ours (snap rows in raw).
- Workshop platform: it was down (exited 16 h earlier). Started with its own `scripts/start.sh` (default order),
  `GET /api/health` 200 with build `d58ae75d`, `GET /` 200 (13344 bytes), stop/stop-again/restart cycles, and it is
  LEFT RUNNING healthy on 127.0.0.1:8087 (it was down only because of the earlier exit). Note: the start rebuilt
  `platform/bin/workshop-server` in the main checkout (git-ignored build output).
- Storage move: podman images/volumes of our stacks present (ruby:3.3 image used by the milosvasic.ru serve,
  workshop named volumes preserved across stop: "named volumes preserved").

## Defects and observations

1. FIXED, ai_interviewing PR #2 (merge 5c5091111c97): `start.sh`, `stop.sh`, `restart.sh` silently ignored every
   argument that was not `--runner`: `start.sh --help` STARTED the server, `stop.sh --bogus` stopped it. Root cause:
   `aicur_runner_init` stored the remainder in `AICUR_REST` and nothing read it. Test-first:
   `raw/ai_interviewing-RED-verify-runner-flag.txt` (7 fail) -> `...GREEN...` (16 pass; the one remaining FAIL,
   "module-absent", fails identically before the change and is an artifact of the scratch checkout layout, where
   a sibling `submodules/containers` exists) and `raw/ai_interviewing-prove-failure.txt` (7/7 mutations killed,
   new M7). Independent read-only review: GO.
2. NOT FIXED, milosvasic.ru `start.sh`: same class (unknown flag and `--help` fall through to host
   `bundle install && jekyll serve`; seen in the dry-run rows). The default path is deliberately
   "byte-compatible with the previous start.sh"; a push to main there deploys production, so no PR was made.
   Recommend a tiny follow-up the operator can approve.
3. DESIGN OBSERVATION, qa-up: with a static-only selection (`--only vd`) a forced `--runner=docker` or
   `--runner=bogus` is accepted without validation by documented design ("loaded and selected only when a
   container is about to be used"); with workshop/ai/mv-rebuild it is refused rc 2. Not changed.
4. BLOCKED, workshop `--runner` branch (7797b732): not merged (materials pre-push gate pending operator
   decision). Its behaviour is fully recorded in `raw/workshop-runner-branch.txt`; the shipped scripts have no
   `--runner`.
5. Minor: workshop `restart.sh` runs `seed-test-accounts.sh` which reports COULD NOT DETERMINE when no student
   password is configured (non-fatal warning, stack up); ai_interviewing `/` answers 404 (API-only, `/api/health`
   200).

Files: `matrix.md` (generated from `raw/`), `raw/*.txt`, `SHA256SUMS`.
