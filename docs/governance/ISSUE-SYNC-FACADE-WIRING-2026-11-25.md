# Issue-sync facade wired into the umbrella, 2026-11-25

| Field | Value |
|---|---|
| Revision | 1 |
| Created | 2026-11-25 |
| Authority | Anchor 11.4.300; operator decision 2026-11-25 (one pipeline entry point, database wins, inbound is reviewable proposals); 11.4.6 governs wording |
| Mode | dry-run. No apply decision is recorded, `config/forge/issue_sync_proven.tsv` is not extended, nothing was written to any tracker |
| Secrets | none recorded; tokens are referenced by variable NAME only |

## What was wired

- Constitution pin `71c5e178707d` -> `0d9e638f69d9` (PR #46, the `scripts/issues_sync_pipeline.sh` facade). Fast-forward only, 0 divergent / 11 behind, `Constitution.md` unchanged on both sides (blob `1cab1d0726bb`, 13,174 lines, 281 anchors, 2,283,524 bytes, sha256 `d72bd3b4…`). `diff --stat` over the range: 17 files, 1,454 insertions, 28 deletions (the facade, `inbound.py`, `pipeline.py`, `prove_pipeline.py`, store/adapter edits, two gates, the Docs Chain template, the manual).
- `.docs_chain/contexts/issues-sync.yaml` installed with `scripts/issues_sync_pipeline.sh init-context --root . --owner-repo github.com/milos85vasic/vasic --write` (never overwrites). The existing `.workable-items-sync.yaml` (enabled, `mode: dry-run`, no `apply_decision`, mirrors map) is unchanged.

## Measured on this host (read-only)

| Command | Result |
|---|---|
| `init-context` (dry run, then `--write`) | rc 0, wrote the 4,635-byte context |
| `docs_chain doctor` on the context | rc 0 |
| `run` before any `docs_chain sync` | `docs_chain verify` rc 1, `STALE: [inbound_report outbound_report verify_report]` (no baseline yet) |
| `docs_chain sync --root . issues-sync` | applied, committed the three report nodes under `docs/issues_sync/` (local, no tracker contact beyond the plan's read-only probes) |
| `run --config .workable-items-sync.yaml --db docs/workable_items.db --owner-repo github.com/milos85vasic/vasic --db-repo github.com/milos85vasic/vasic --target github.com/milos85vasic/vasic` | doctor rc 0, `docs_chain verify` rc 0, facade `verify` **rc 1** (DRIFT) |

**`run` does NOT exit 0 here, and that is the honest reading.** The facade `verify` leg reports 435 items still to be created on the GitLab, Codeberg, git.m3w.org and GitFlic mirrors (DRIFT, 1) and 435 UNCONFIRMED on GitHub and GitVerse (`capability-unverified:can_create`, 2). Nothing has been applied, by design (11.4.300 is default OFF; no apply decision). The chain itself (doctor + docs_chain verify) is rc 0 once a baseline exists. Exit 0 needs an apply decision plus proven write verbs; it is not obtainable read-only.

## Findings carried (not fixed here, they are upstream or environmental)

1. **docs_chain binary must match the facade's CLI.** The facade calls `docs_chain doctor|verify|sync --root DIR <context>`. The binary at `~/Projects/atmosphere/docs_chain/docs_chain` (Oct 2026 build) uses `--repo-root` and cannot parse the context (`from: [a, b]` list); it fails with `unexpected argument "."`. A binary built from `~/Projects/constitution/submodules/docs_chain` (commit `8e0abe0`, `go build ./cmd/docs_chain`) matches. Point `DOCS_CHAIN_BIN` at it.
2. `docs_chain` flags must precede the context name: `sync --root . issues-sync` works, `sync issues-sync --root .` answers `specify exactly one <context> or --all`.
3. `.docs_chain/state.json` is git-ignored, so every fresh checkout reports the three report nodes STALE until `docs_chain sync --root . issues-sync` is run once. The generated reports (`docs/issues_sync/verify.md` is ~313 KB) are deliberately NOT committed.
4. The umbrella has no `docs/Issues.md` / `Fixed.md` at the paths the template names (`docs/workable-items/Issues.md` exists and is what the context points at).

## Post-merge hook

`scripts/hooks/issue_sync_post_merge.sh` is fail-closed in the 0d9e638f69d9 engine: while any tracker-edited issue has no captured proposal, its background apply stops with a REFUSED row in `.git/issue-sync.log` until `issues_sync_pipeline.sh pull --write` has run once. No write leg (`pull --write`, `apply`, `run --write`) was run against any tracker in this change; that first `pull --write` is an operator-timed step (it reads trackers and writes proposal files under `docs/issues_sync/inbound/`).
