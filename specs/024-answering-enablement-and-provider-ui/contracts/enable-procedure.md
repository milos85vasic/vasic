# Contract: Guarded Enable / Disable Procedure

**Implements**: FR-009, FR-010, FR-017 | **Files**: `workshop/scripts/answering-measure.sh`,
`answering-enable.sh`, `answering-disable.sh`, `answering-postcheck.sh` (all new).

## Exit codes (every script)

`0` done/allowed, `1` refused (gate not cleared, mismatch, precondition failed), `2` could not
determine (tool missing, unreadable verdict dir, unreachable server). **2 is never a pass.**

## `answering-measure.sh [--provider P --model M ... | --from-live-cmdline] [--runs N]`

Wraps `gates/answer-eval/eval.sh` + `gate_verdict.py`. Runs ONLY against a scratch server on a free
port with a COPY of the index (the harness's existing behaviour). Refuses (rc 2) if the scratch
server reports answering disabled. Writes the verdict + runs TSV + manifest line. Safe from any
worktree stream; never touches the live stack.

## `answering-enable.sh --provider P --model M [--dry-run]`

1. Reads the live cmdline/config for the values that enter the fingerprint (provider, model,
   endpoint, thresholds, verifier kinds) from the intended compose environment, and the live corpus
   root hash from `/api/index/status`.
2. Looks for `PASS` verdict with an equal fingerprint. None, stale, invalid: rc 1, prints which
   fingerprint input differs from the newest verdict (short hashes only).
3. With a match: prints exactly
   `WORKSHOP_ANSWER_PROVIDER=P WORKSHOP_ANSWER_MODEL=M [WORKSHOP_QUESTION_VERIFY=...] bash scripts/restart.sh`
   (the same form the compose comments at `platform/compose.yml:279,519` document), the pre-capture
   command, and the post-check command; rc 0. It does NOT run the restart (live-stack lock: only the
   orchestrator restarts, per architecture §2.2 rule 6). `--dry-run` prints without reading the
   network.

## `answering-disable.sh [--dry-run]`

Prints `WORKSHOP_ANSWER_PROVIDER=none bash scripts/restart.sh` and the post-check; rc 0. Never
requires a verdict (turning OFF is always allowed).

## `answering-postcheck.sh --expect on|off [--out DIR]`

Authenticated probes via `scripts/_live_auth.sh` (token helper; credentials never printed):
`/api/answering/overview.state`, `/api/ask/status.enabled`, one known-answerable and one
known-unanswerable question from the benchmark (on only), the search digest of the fixed query set
(sha256 over the canonical JSON of results), compared with the pre-capture digest. Writes
`result.json` (check, expected, observed, rc per row) and `manifest.sha256`; rc 0 only when every
row matches.

## Boot-side counterpart

`cmd/workshop-server/answering_gate.go`: after flags are parsed and before the answering route tree
is built, if provider != `none`, load verdicts, compute the running fingerprint, and either pass the
provider through unchanged or replace it with `none` and record `forced_off_reason=gate_not_cleared`.
The replacement uses the existing `none` provider; no new provider kind is added. The decision and
short fingerprints are logged once.
