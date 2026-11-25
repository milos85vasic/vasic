# Open operator items, 2026-11-25

| Field | Value |
|---|---|
| Revision | 1 |
| Created | 2026-11-25 |
| Scope | Items only the operator can unblock (credentials, hosts, decisions). Nothing here has been acted on by an agent |
| Secrets | none recorded; credentials are named by variable or file NAME only, never by value |

## A. Credentials and access

| # | Item | Why it blocks | What is needed |
|---|---|---|---|
| 1 | GitHub token: add `Issues: write` and access to the private repositories | The fine-grained token in `~/api_keys.sh` answers 403 on issue PATCH (`issues=write` required) and 404 on `vasic-digital/ai_interviewing`, `vasic-digital/monetization`, `vasic-digital/workshop_curriculum` | Regrant the token (or issue a new one) with Issues read/write and the three private repositories; github.com cannot enter `config/forge/issue_sync_proven.tsv` until a live create and read-back is recorded |
| 2 | GitVerse issue create 403, `is_verified: false` | gitverse.ru issue creation is refused for the account | Verify the GitVerse account or grant the token issue-create; then a live create and read-back |
| 3 | m3w SSH key | git.m3w.org SSH access for the push topology | Provide or authorise a key for the m3w account |
| 4 | mistborn.local key-based SSH | CLOSED 2026-11-25: key access exists; test-level macOS proof recorded in docs/qa/evidence/runner-macos-2026-11-25/ | none |

## B. macOS live proof of workshop --runner (workshop main 364850d3, tag vasic-1.0.0-dev-0.0.10)

Done 2026-11-25 (test level, PROVISIONAL): on mistborn.local (bash 3.2.57) runner-flag.test.sh 45/0, portable-helpers.test.sh 50 OK (5/5 mutants killed), runner-prepare.test.sh 39/0, after fixing a real macOS defect (BSD realpath -m -s and readlink -m in run-isolated.sh, GNU timeout in start.sh). Evidence: docs/qa/evidence/runner-macos-2026-11-25/. NOT done: start.sh live on the Mac, the reboot case and the docker/colima cases.

Operator reboot test, to run on the Mac once it is back up (checkout /Volumes/T7/Projects/vasic/workshop):

```
cd /Volumes/T7/Projects/vasic/workshop
env -i HOME=$HOME PATH=/usr/bin:/bin:/usr/sbin:/sbin bash scripts/start.sh --runner=podman; echo rc=$?
bash scripts/status.sh --runner=podman; echo rc=$?
env -i HOME=$HOME PATH=/usr/bin:/bin:/usr/sbin:/sbin bash scripts/start.sh --runner=podman; echo rc=$?
PATH=/opt/homebrew/bin:$PATH bash scripts/runner-flag.test.sh | tail -2
```

Original steps (kept):

1. Stop the podman machine.
2. `env -i HOME=$HOME PATH=/usr/bin:/bin:/usr/sbin:/sbin bash scripts/start.sh --runner=podman` (minimal environment; expect the prepare step to start the machine itself).
3. `--runner=Podman` (case-insensitive name).
4. Idempotence: run the same command twice, no second prepare action.
5. Reboot case: restart the host, repeat step 2.
6. Mount check: the platform container sees the workshop mount.
7. docker and colima cases: `--runner=docker`, `--runner=colima`.

Record each result under `docs/qa/` with the command, rc and output.

## C. Decisions and tooling

| # | Item | Detail |
|---|---|---|
| 5 | LLMProvider pin bump | Decide whether to move the `submodules/LLMProvider` gitlink to its current upstream main (per-bump operator decision; not covered by the constitution standing authorization) |
| 6 | VSC-398 and WSP-151 | Need `gap close-by-decision` tooling before they can be closed from the recorded decision |
| 7 | CON-002, HLP-001, LLP-001 | Need fresh pins plus recorded closure records (CON-002: pin now equals remote HEAD per `docs/operator/workable-items-gate-2026-11-25.md`; closure needs an independent verifier verdict) |
| 8 | Five ungated GitHub Actions pins in `milosvasic.ru/.github/workflows/pages.yml` | Unpinned action references; `pages.yml` is the sole publish path and must not be disabled, so pinning is a separate reviewed change |
| 9 | Deploy-key private half | The private half of the deploy key sits in the agent scratchpad directory `dk/` and must be deleted after its use is confirmed finished |
| 10 | First `issues_sync_pipeline.sh pull --write` | Makes the post-merge hook stop failing closed (see `docs/governance/ISSUE-SYNC-FACADE-WIRING-2026-11-25.md`); reads trackers and writes proposals, so its timing is the operator's |

## D. Gate state to keep no worse

`bash scripts/verify-workable-items.sh` exits 1 with 69 date findings (listed in `docs/operator/workable-items-gate-2026-11-25.md`). The wrap change adds no workable item and no date, so the count is unchanged.
