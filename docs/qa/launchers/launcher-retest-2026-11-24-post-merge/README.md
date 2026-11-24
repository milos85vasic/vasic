# VSC-417 post-merge evidence (2026-11-24)

Workshop PR #1 (`pr/runner-flag`, `--runner=NAME` / `CONTAINERS_RUNNER`) merged on origin/main as `5a7acdd1ffe21f10e648fdcb653a2d987a8e5502`. This supersedes the "local only / not merged" status of the workshop row in `../launcher-retest-2026-11-24/README.md`.

Run in a scratch clone with the umbrella layout (workshop at 5a7acdd1, `submodules/containers` at 2d18551, which the branch's relative `replace` needs):

| File | What | Result |
|---|---|---|
| `commit.txt` | commit under test (merge 5a7acdd1 shows as first line of `git log` of that checkout) | see file |
| `go-test-at-5a7acdd1.txt` | `go build`, `go vet ./cmd/...`, `go test` workshop-boot + containers-status-probe at the merge commit | rc 0 |
| `runner-flag-test-at-5a7acdd1.txt` | `scripts/runner-flag.test.sh` at the merge commit | 26 passed, 0 failed |
| `prove-failure-at-7797b732-branch-tip.txt` | `runner-flag.test.sh --prove-failure`, run on the branch tip 7797b732 (second parent of the merge, same code) | 9 killed, 0 survived |

Independent review of the PR: GO (one cosmetic nit, `restart.sh --help` prints two extra lines). The live platform at 127.0.0.1:8087 was not touched. Whether each launcher was run live with each runner is covered by the earlier evidence directory `../launcher-retest-2026-11-24/` and `../launcher-flags-2026-11-24/`; this directory adds only the workshop merge evidence.
