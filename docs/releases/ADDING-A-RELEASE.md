# Adding a release: the repeatable procedure

| | |
|---|---|
| Purpose | One repeatable way to cut a numbered development release of the platform: build once, hash, verdict, promote, restart, tag, push |
| Constitution | 11.4.230(D) (incremental delivery), 11.4.235 (build and deploy once source is proven correct), 11.4.236 (QA-deploy-readiness gate), 11.4.264 (build once, promote one immutable artifact), 11.4.113 (never force-push), 11.4.151 (project-prefixed tag names), 11.4.40 (full-suite retest before a release tag), 11.4.61 (metadata table and contents) |
| Revision | 1 (2026-10-20) |
| Status | Draft for independent review (11.4.142). Written from the scripts as they are on `workshop` `main` at `e16a196`; **no step was executed to write it** |
| Tag scheme | `vasic-1.0.0-dev-0.0.N`, annotated tags, N counting up from the baseline `vasic-1.0.0-dev-0.0.1` (workshop `ce62bcb`, umbrella `a55e878`) |
| Not covered | Release channels beyond "dev", signing, and any step that needs a credential. No credential appears or is needed in this document |

## Contents

1. [Planned versus current](#1-planned-versus-current)
2. [Preconditions](#2-preconditions)
3. [The procedure](#3-the-procedure)
4. [Tag message template](#4-tag-message-template)
5. [What can go wrong](#5-what-can-go-wrong)
6. [Evidence to keep for each release](#6-evidence-to-keep-for-each-release)

## 1. Planned versus current

| Item | State |
|---|---|
| `scripts/restart.sh`, `scripts/build.sh`, `scripts/verify.sh`, `scripts/status.sh` | **Exist** on `workshop` `main` and are what this procedure uses |
| `scripts/promote-registry.sh` and `scripts/promote-web.sh` (with `scripts/lib/promote_lib.py` and their `.test.sh` files) | **Planned.** They exist only on the unmerged `workshop` branch `s12-019-promotion` (spec 019). Do not call them from `main`. Until they merge, step 5 below is manual |
| A single command that performs the whole release | **Does not exist.** Each step below is separate on purpose |

When the promotion scripts merge, replace step 5 with them and keep the other steps. Do not edit this
file to describe them before they are on `main` and have been run.

## 2. Preconditions

All of these must hold, and each is checked, not assumed:

1. **The increment is merged on `main`.** Fetch first: `git fetch --all`. Integrate by merging onto the
   latest `main` (fast-forward where possible). Never rebase published history.
2. **Independent review is GO** for every change in the release (11.4.142), recorded by the
   orchestrator.
3. **The tree is quiescent.** `scripts/restart.sh` takes two `git status --porcelain` readings
   (default 30 seconds apart, `WORKSHOP_RESTART_QUIESCE_SECONDS`) and refuses (exit 1 or 2) if they
   differ. Stop other writers first.
4. **A backup of the live data exists** before anything destructive (Constitution section 9:
   hardlinked backup before a destructive operation). The relevant live data is the registry
   (`curriculum/passages.jsonl`), the served bundle (`platform/prebuilt`) and the index volume.
5. **Heavy commands are admitted.** Builds and gate runs go through
   `bash scripts/agent-admit.sh --slots 4 --tag <tag> --wait 1800 -m 6G -T 3600 -- <command>`
   (the umbrella script; 4 slots since 2026-10-20). A refusal means wait and retry; never bypass it.
6. **Nothing here uses a model on recordings, transcripts or textbooks** (token rule). A release does
   not re-process content with models.

## 3. The procedure

Run from the `workshop` checkout unless a step says otherwise. Every script is three-valued: 0 good,
1 a real problem, 2 could not determine. **A 2 is never a pass.**

### Step 1. Build once

```bash
bash scripts/build.sh            # server + web bundle (heavy; admit it)
# or, when only the Go server changed:
bash scripts/build.sh --server-only
```

`scripts/restart.sh` also builds, to a temporary name next to the live binary, and verifies it
**before stopping anything** (`prepare_fresh_server`); a compile error ends with exit 2 and the old
stack still serving. So the artifact that runs is the one restart prepared. Do not rebuild in a later
stage: one artifact moves through the stages (11.4.264).

### Step 2. Hash the artifact

```bash
sha256sum platform/bin/workshop-server        # record this in the release evidence
git rev-parse HEAD                   # the source commit
git status --porcelain               # must be empty: a dirty tree is not a release
```

`restart.sh` exports `WORKSHOP_PREPARED_SERVER_SHA` and `start.sh` confirms the same hash instead of
building twice; the value you recorded must equal it.

### Step 3. Verdict

```bash
bash scripts/verify.sh               # aggregates every gate; 0 / 1 / 2
```

A candidate is releasable only with a PASS verdict tied to the fingerprint of the artifact from step 2
(11.4.236). Record the output. If any gate returned 1, stop. If any returned 2, it is not a pass: fix
the instrument or record the gap explicitly. The full-suite retest of 11.4.40 is required for a
non-dev tag; for a `dev` tag, say in the tag message whether it was run (the baseline tag says it was
**not**).

### Step 4. Back up

Take the hardlinked backup named in the preconditions. Record its path in the release evidence.

### Step 5. Promote (manual until the scripts merge)

Planned: `scripts/promote-registry.sh` (registry and index) and `scripts/promote-web.sh` (web bundle)
from branch `s12-019-promotion`. **Current manual-safe procedure:**

1. Apply data changes only through a script that is committed in the repository and that you have
   already run against a scratch copy; never hand-edit `curriculum/passages.jsonl`.
2. Verify counts and identity against the scratch result before touching the live files.
3. Copy into place only after the backup of step 4 exists; keep the previous files for rollback.
4. Do not touch `:8087` or the live container by any route other than step 6.

### Step 6. Restart

```bash
bash scripts/restart.sh --dry-run    # prints the order; touches nothing
bash scripts/restart.sh              # full down/up, never a compose restart
bash scripts/status.sh               # RUNNING / STOPPED / DEGRADED / UNKNOWN
```

`restart.sh` refuses `--destroy-volumes`, refuses a half-set answering opt-in, and short-circuits if
`stop.sh` returns 1 or 2 (it does not start on top of an unknown). A restart starts a long
cross-reference derivation (about 45 minutes per its own header); the stack is usable meanwhile but
the derivation runs over whatever tree exists, which is why quiescence matters.

Confirm the running build is the one you released:

```bash
curl -s http://127.0.0.1:8087/api/health    # source_commit equals step 2; source_dirty is false
```

(The health fields `source_commit`, `source_dirty`, `build`, `built_at` are the ones
`scripts/run-isolated.sh` stamps; that the live endpoint reports the same keys is expected, and
**UNCONFIRMED** until you read the output.)

### Step 7. Tag

Tags are annotated and carry the project prefix. Decide N as the next number after the highest
existing `vasic-1.0.0-dev-0.0.*` tag (`git tag -l 'vasic-1.0.0-dev-0.0.*' | sort -V | tail -1`).

Tag **three kinds of repository**, each at the commit the release actually uses:

1. the **workshop** repository (`workshop/`), at the released commit;
2. the **umbrella** repository, at the commit whose gitlinks pin that workshop commit;
3. every **owned submodule that changed** since the previous release tag
   (`git -C <submodule> log <previous-tag>..HEAD --oneline` is non-empty).

```bash
git -C workshop tag -a vasic-1.0.0-dev-0.0.N -m "<message from section 4>" <workshop-commit>
git tag -a vasic-1.0.0-dev-0.0.N -m "<message from section 4> (umbrella commit pinning workshop <short>)" <umbrella-commit>
# for each changed owned submodule:
git -C submodules/<name> tag -a vasic-1.0.0-dev-0.0.N -m "..." <submodule-commit>
```

Never move or delete a published tag. A wrong tag is superseded by the next number.

A gitlink bump and the matching `helix-deps.yaml` `ref` entry go in **one** change; otherwise cascade
check C9 reports DRIFT. Bumping a submodule other than `submodules/constitution` is an operator
decision, per the carriers.

### Step 8. Push, fast-forward only, to every upstream

Use the project's commit wrapper or the `upstreams/*.sh` recipes so that **every** upstream receives
the branch and the tags. Plain form, per remote:

```bash
git fetch --all                                 # integrate first; merge onto the latest main
git push <remote> main                          # fast-forward only
git push <remote> vasic-1.0.0-dev-0.0.N         # the tag, by name
```

**Never** `--force`, `--force-with-lease`, a `+ref`, `--no-verify`, or a history rewrite, on any
repository or submodule (11.4.113). If a push is rejected as non-fast-forward, fetch, merge onto the
latest main, and push again.

### Step 9. Verify the publication

```bash
git ls-remote <remote> refs/heads/main refs/tags/vasic-1.0.0-dev-0.0.N   # equals local, per remote
bash scripts/verify-manifest-pins.sh            # umbrella: refs equal gitlinks
bash scripts/verify-submodule-remote-sync.sh    # umbrella: gitlinks vs remotes
```

## 4. Tag message template

```
<one line: what this release adds>.
Build: workshop <short sha>, artifact sha256 <first 12>, verdict <PASS/..> (verify.sh output kept at <path>).
Full-suite retest (11.4.40): <run | NOT run>. <If not run, say so; dev markers may omit it, they may not hide it.>
(umbrella commit pinning workshop <short>)
```

## 5. What can go wrong

| Symptom | Cause | Action |
|---|---|---|
| `restart.sh` exit 1 at the first step | a writer is active in the tree | stop the writer, re-run; `--skip-quiescence-check` only if quiescence was established another way |
| `restart.sh` exit 2 with the old stack still up | the pre-build refused or failed | read the message; nothing was stopped |
| `verify.sh` exit 2 | an instrument could not run | not a pass; fix the instrument or record the gap |
| Push rejected (non-fast-forward) | upstream moved | fetch, merge onto the latest main, push again; never force |
| `source_dirty` is true in `/api/health` | the artifact was built from a dirty tree | not a release; rebuild from a clean commit |
| C9 reports DRIFT | gitlink and `helix-deps.yaml` ref moved separately | stage them together |

## 6. Evidence to keep for each release

The commit hashes (workshop, umbrella, each tagged submodule), the artifact sha256, the `verify.sh`
output, the backup path, the `/api/health` output after restart, the `git ls-remote` output per
upstream, and the tag messages. A release without these is a claim, not a record.
