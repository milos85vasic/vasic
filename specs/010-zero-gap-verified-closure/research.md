# Phase 0 Research: Zero-Gap Verified Closure

Method: four read-only research agents (register reuse, evidence/determinism reuse, test-kind
inventory, local scheduling/host limits) plus direct reads of canon §11.4.15 and §11.4.268 and of
the constitution's shipped chain/recorder gates, 2026-09-25. Every finding names its command or
source. Where an agent could not verify something it is marked UNCONFIRMED and turned into a
Phase-1 task rather than an assumption.

## Decisions

### D1 — The register is the existing workable-items store, extended additively
- **Decision**: extend `docs/workable_items.db` (canonical, tracked, §11.4.93/95) rather than build a
  second store.
- **Evidence**: file is tracked (`git ls-files --error-unmatch` succeeds), not ignored, 530 items
  (Completed 325, Queued 203, In progress 1, Obsolete 1), all `type=Task`, last commit `9b7cf6a`
  (2026-09-09, so 16 days stale today). It already has `items`, `item_history` (with
  `evidence_path`), `test_diary` (PASS requires an evidence path — a CHECK), `item_provenance`,
  `obsolete_details`, `operator_block_details`, `meta`, `sub_projects`.
- **Rationale**: §11.4.93 makes the DB the sole SSoT with generated docs; a parallel register would
  violate it and immediately drift.
- **Alternatives rejected**: a new SQLite/JSON register (duplicates SSoT); Markdown issue files
  (§11.4.93 forbids hand-edited status docs); GitHub issues (outward-facing, CI-adjacent, no
  offline evidence).
- **Constraint**: §11.4.93 fixes the minimum tables, so changes MUST be additive (`migrateColumns`
  pattern already used by the tool).

### D2 — "Classified" is a column pair, not a new status
- **Decision**: add `disposition ∈ {open, closed, classified}` and `classification_reason ∈
  {operator-decision, operator-action, third-party, documented-deviation}`; the item keeps a legal
  §11.4.15 status: `Operator-blocked` (with its options and their cost in `operator_block_details`)
  for the two operator reasons, and plain `Queued` for third-party and documented deviation — the DB
  CHECK accepts only the exact value `Queued`, and §11.4.148 D3 rewrites any BLOCKED alias to
  `Operator-blocked`, so the qualifier lives in the disposition columns.
- **Evidence**: §11.4.15's closed set is Queued / In progress / Ready for testing / In testing /
  Reopened / Fixed; the DB CHECK adds Operator-blocked and Obsolete via other anchors (§11.4.21,
  §11.4.90). "Classified" appears in none. Obsolete reasons are also a closed list that has no
  third-party value.
- **Rationale**: a new status would conflict with §11.4.15's closed set (agent finding, verified
  against the anchor text); a column pair is additive and validator-enforceable.
- **Flagged**: this is new governance VOCABULARY, so it is Human Checkpoint 1.

### D3 — Type and closure vocabulary
- **Decision**: defects and danger zones → `Bug` (closes `Fixed`); unfinished promises that add a
  capability → `Feature` (closes `Implemented`); improvements to existing capabilities and pure
  hygiene → `Task` (closes `Completed`). The FR-025 measurable-target rule keys on a separate
  `kind='improvement'` column, NOT on type, because §11.4.16 defines Feature as a new capability and
  an improvement typed `Task` would otherwise escape the rule (review finding).
- **Evidence**: §11.4.33 makes the closure word type-bound; the DB today has zero Bug/Feature rows,
  so the register introduces the first real Bugs.

### D4 — Severity and category are closed sets enforced by the validator
- **Decision**: `severity ∈ {critical, high, medium, low}`; `category` from a fixed list
  (`security`, `data-integrity`, `false-evidence`, `availability`, `content-boundary`,
  `governance-drift`, `test-coverage`, `build-freshness`, `ux-accessibility`, `docs-drift`,
  `host-capability`, `other`).
- **Evidence**: `items.severity` is free TEXT today and only VSC-001 carries one (`high`).
- **Note**: per clarification 1, severity NEVER lowers the closure bar; it only orders work.

### D5 — Reopen/recurrence uses existing history rows plus one link column
- **Decision**: reuse `item_history.event_type='Reopened'` (already in the constitution's fixed
  set); add `recurrence_of` (atm_id) and `reopens_count`; `composes_with` stays for other links.
  Independent verdicts go in a NEW add-on table `item_verdicts` (D11), never in `item_history`,
  whose CHECK set is fixed by canon and cannot be extended without rebuilding the constitution's table.
- **Evidence**: 0 Reopened rows exist; no reopens_count or recurrence column exists; §11.4.214
  forbids minting a new id for a returning defect and §11.4.55 wants a reopens count.

### D6 — Evidence = the constitution's recorder + chain, consumed not rewritten
- **Decision**: seal evidence using `submodules/constitution/scripts/gates/lib/execution_record.sh`
  (records `ts, cwd, argv, exit_status, duration_ms, stdout/stderr digests over the FULL stream,
  stream_ref outside VCS, truncation and redaction flags`) and verify with the shipped chain gates
  (`cm_chain_integrity_detects_alteration.sh`, `cm_anchor_detects_tail_truncation.sh`,
  `cm_anchor_record_complete.sh`; the shipped verifier binary is
  `submodules/constitution/submodules/continuum/cmd/continuum-integrity` — `execution_record.sh` is the RECORDER, not the
  verifier; the chain gate was run read-only by the reviewer: exit 0, 8 PASS). Build only the thin
  adapter (state fingerprint + population field + item link).
- **Evidence**: those files exist in the pinned submodule; §11.4.268 requires detection of deletion,
  reorder and tail-truncation and an honestly-labelled anchor `mechanism`; the repo implements none
  of it today (grep of scripts/ and docs/ found no chain; `pre-push-gates.sh` keeps only temporary
  logs and an in-memory summary with no timestamp or seal).
- **Rationale**: §11.4.74 (extend, don't reimplement) and §11.4.240 (producer ≠ verifier): the
  chain is produced by our adapter and verified by upstream code we do not author.
- **Honest limit (recorded, not hidden)**: the anchor location is a tracked file in git. An ordinary
  commit CAN rewrite that file without any force-push, and `git remote -v` shows `github`, `origin`
  and `upstream` all pointing at the SAME repository (`upstreams/` holds only `GitHub.sh`), so there is
  one upstream, not a mirror set. The claim is therefore worded
  `append-only-by-policy (single upstream)`, which is prose only; the stored value is the upstream enum `anchor_strength: policy`
  (NOT "cryptographically enforced"), and the git-history verifier checks PER-COMMIT forward-only: `entry_count` never drops and each
  earlier `head_digest` equals the digest of the chain record at that position (see data-model.md AnchorRecord).
- ~~UNCONFIRMED~~ **SUPERSEDED by the Phase 1 addendum (T001)**: the verifier REFUSES our schema; the two-file design (D6a) adapts OUR side. Anchors use the upstream format `{head_digest, entry_count, anchor_strength}` with our honest value `policy`; the mechanism string `append-only-by-policy (single upstream)` is prose, not a stored enum value.

### D7 — State fingerprint generalises the content-boundary mechanism
- **Decision**: fingerprint = sha256 over the sorted (path, blob-sha) list of the population a check
  reads, taken before AND after the check; a difference marks the run UNSTABLE (rc 2), never
  averaged.
- **Evidence**: `verify-content-boundary.sh --expect-corpus` already does this with `cksum`, which is
  not cryptographic; it turned a concurrently-edited tree into a named `undet` row. sha256 is the
  upgrade.

### D8 — Recall is measured with planted-defect corpora
- **Decision**: each sweep class in `docs/zero-gap/sweep-classes.tsv` names a fixture directory of
  planted defects and a golden-clean control; recall = planted-found / planted. A class with no
  corpus prints `recall=UNKNOWN` next to every "no findings".
- **Evidence**: the `verify-content-boundary` gate already prints its subtraction recall cost, but
  only for that gate; the claim ledger prints "a slice of 10 claims" and says `--completeness` is
  unmet (agent measurement, ledger run twice, byte-identical, rc 1).
- **Bounded-window rule**: classes that compare against neighbours declare their window in the TSV
  (constitution: "A Gate Cannot See a Displacement Larger Than Its Window").

### D9 — Determinism is measured, not asserted
- **Decision**: `zero-gap-determinism.sh` runs any check N=5 times on a fingerprinted state and
  compares sha256 of normalised output; any difference registers the check as UNSTABLE and it does
  not count as evidence (SC-006).
- **Evidence**: only `verify-claim-ledger.sh` has been measured twice (identical output, rc 1); no
  other instrument has been.
- **Known nuisance**: `verify-claim-ledger.sh` output is ~124 KB — the harness hashes, it does not diff text.

### D10 — Coverage map is generated from data and probes
- **Decision**: `docs/zero-gap/coverage.tsv` maps (subject × test kind) → check id | `n/a:<reason>` |
  `gap`; the generator verifies every check id exists in `check-registry.tsv` or as a named
  entrypoint, that its last recorded run executed >0 cases, and marks a cell it cannot run
  `could-not-run:<tool>`.
- **Seed evidence (name-based, weak — Phase-1 task re-measures every cell)**: present real
  mutation only in workshop and curriculum-kit; stress/chaos only in `submodules/containers` and
  `submodules/qa`; fuzz (`func Fuzz`) only in `submodules/qa` (5 files); no load harness beyond
  `_tests/perf-budget.spec.js` for the two static sites; `verdict` (1 test file) and `passage`
  (6) essentially unit-only; ai_interviewing frontend has no a11y-named spec; workshop frontend no
  security spec. Counts are `git ls-files` name matches (noisy).
- **Extra test kinds proposed by the survey** (clarification 5 allows them): content-boundary,
  claim-ledger, gate paired-mutation, SEO/i18n completeness, link integrity, export validation,
  provider-CI, host-capability, fuzz, visual-diff.

### D11 — Independent verification
- **Decision**: two layers, recorded in the add-on table `item_verdicts` (never `item_history`).
  (a) `zero-gap-verify.sh` re-runs a closed item's recorded check on the
  pre-fix ref and the current ref, written by a producer that is not the fixer's session
  (constitution `independence_tier.sh`); (b) fixes made by agents are reviewed by a different agent
  and the verdict is stored as an `item_history` row naming the reviewer. No human sign-off step
  (clarification 2); operator-owned actions stay the operator's.
- **Evidence**: this session's reviews caught real defects the author missed (a false force-push
  precedent claim, a false venv Python claim, an orphaned claim-ledger row created by an "innocent"
  quoting change), which is the empirical case for FR-018.

### D12 — Daily job: systemd user timer, bounded, single-instance, registered
- **Decision**: reopen requests are QUEUED, not written: the job appends them to
  `.remember/logs/zero-gap/reopen-queue.jsonl` and applies them only through an explicit
  `workable-items-vsc gap apply-queue` run inside a commit made by an agent session (the register is
  tracked; the job must never touch tracked files — §11.4.121/§11.4.84). `zero-gap-daily.timer` (`OnCalendar=daily`, `Persistent=true`,
  `RandomizedDelaySec` small) → `zero-gap-daily.service` that runs `zero-gap-daily.sh` under
  `MemoryMax=16G`, `nice -n 10`, `ionice -c3`, `flock` on a purpose-key file.
- **Evidence**: 14 user timers exist (13 at first survey; the count moves) and `Linger=yes`
  (`systemctl --user list-timers`, `loginctl`); the repo has no scheduling recipe and no bounded-execution wrapper today (grep of
  scripts/, _tools/, docs/); §12.6 caps RAM at 60% (host 30 GiB → 18 GiB cap, 16G chosen with
  margin); §11.4.232 requires registration before run, a heartbeat, a terminal verdict, and no two
  same-purpose runs at once; success is read from the terminal verdict, NOT the process exit code.
- **Cost evidence**: manifest pins 0.71 s, continuation 1.15 s, registry structure 6.36 s, cascade
  7.11 s, claim ledger 10.03 s — ≈25 s together, all <100 MB. `--run-proofs`, the content-boundary
  gate and the full constitution sweep were NOT run and are budgeted from recorded figures only.
- **Clarification 3 honoured**: full run once a day and on demand; not per push.
- **Install is an operator action**: it edits host configuration; the plan prepares the units and
  documents them, and does not install them unasked.

### D13 — Daily results surface without CI or tracked-file churn
- **Decision**: the job writes an untracked report under `.remember/logs/zero-gap/<date>.json`
  (git-ignored) and, on RED or STALE, a `notify-send` toast plus a one-line banner at next session
  start; tracked docs change only by an explicit commit (§11.4.121/§11.4.84).
- **Evidence**: `.remember/.gitignore` is `*`; `notify-send` is on PATH; `docs/SESSION-REPORT.*` is
  tracked so a daily writer there would dirty the tree.

### D14 — Cycle freeze
- **Decision**: `freeze` writes `docs/zero-gap/cycles/<cycle>/freeze.json` (sha256 of the ordered
  register export + sweep manifest + chain head + count) and stores it in the DB `meta` table;
  afterwards the validator rejects any item-set change for that cycle, and new discoveries get
  `cycle = next` (FR-026).

## Findings already actionable (seed items for the baseline)

These were verified this session and are registered by the first baseline sweep, not fixed here:
`verify-workable-items.sh` currently reports COULD NOT DETERMINE (G4: 8 declared submodules carry
no roster identifier — challenges, doc_processor, llm_orchestrator, llm_provider, llms_verifier,
qa, security, vision_engine; G5: 1 unresolved condition); the workable-items DB is 16 days stale;
the claim ledger covers 10 claims only; `pre-push-gates.sh` keeps no sealed record; and the
ai_interviewing `start.sh` still has the build-only-if-missing shape. One defect found DURING this
planning was fixed at once as a correction to today's own work: my carrier edit had switched
`grep -c '^### §'` to double quotes and silently orphaned claim-ledger row
`carriers-constitution-anchors` (ledger verdict went 9 VERIFIED / 1 ORPHAN → 10 VERIFIED / 0
ORPHAN after restoring the quoting).

## Open items carried to tasks (none block planning)

- Re-measure `verify-check-registry.sh --run-proofs` wall time before accepting the 3 h ceiling.
- Settled by review: the Go tool uses the pure-Go `modernc.org/sqlite` driver and shells out only to
  `git`, so the odd `sqlite3` CLI path does not matter. Still open: confirm the canonical validator
  (`verify-workable-items.sh` G6) tolerates the added columns and the `item_verdicts` table; the
  additive `migrateColumns` pattern lives in the constitution's tool
  (`submodules/constitution/scripts/workable-items/…/db.go`), NOT in `_tools/workable-items`.
- Run the constitution's chain attack corpus against a scratch store before trusting the adapter.
- Confirm `verify-shell-continuations.sh` can be extended to the SIGPIPE idiom or add a sibling check.
- Decide whether the daily report is also mirrored into a tracked per-cycle summary at cycle close
  (planned: yes, by an explicit commit).


## Phase 1 addendum — measured 2026-09-25 (tasks T001–T005; each was run by a separate subagent)

### T001 — the verifier CANNOT read the planned store shape (plan change required)
`continuum-integrity` (built from `submodules/constitution/submodules/continuum/cmd/continuum-integrity`) refused a
store in our proposed shape with rc 4 (`unknown field "cwd"`). Its native format is 9 fields, JSONL, unknown fields
refused, genesis `""`, digest = sha256 of the decoded record. The constitution's own gates ran clean:
`cm_chain_integrity_detects_alteration.sh` 8 PASS / 0 FAIL / 0 BLIND, `cm_anchor_detects_tail_truncation.sh` 7/7,
`cm_anchor_record_complete.sh` 16/16. A native-shape store verified rc 0 healthy; mutation, deletion and reorder
were DETECTED (rc 3); tail truncation and delete+re-chain PASS the chain alone (documented limit) and are caught
only by `anchor verify` (rc 3); an absent file REFUSES (rc 4). **Decision D6a:** two files — a native chain file
plus a sidecar bound by `artifact_path = sha256:<sidecar line>`; the adapter verifies the binding; reuse
`chain.ExecRow.ToRecord`. Recorded in data-model.md and `contracts/evidence-record.schema.json`. UNCONFIRMED:
`execution_record.sh` was not run (upstream `ExecRow` types `argv` as an array and byte counts as strings, unlike our
schema); anchor `--remote` strength probing was not exercised, so anchors recorded `anchor_strength: unknown` — the
honest mechanism string stays `append-only-by-policy (single upstream)`.

### T002 — the canonical and umbrella validators tolerate the additive columns and the new table
On a COPY of `docs/workable_items.db` (repo original sha256 unchanged), all 14 planned columns were added with
`ALTER TABLE` (`items` 23 → 37 columns; composite PK unaffected) and `item_verdicts` was created. Canonical validator
(`workable-items-linux validate --db`, the G6 invocation): rc 0, "validate: OK — 530 items" both before and after.
Umbrella validator (`workable-items-vsc validate --repo . --db`): rc 2 both before and after, from the ALREADY-KNOWN
roster gap (8 declared submodules without a roster row) — not from the new schema. Limits: only `validate` was
exercised; write paths (backfill, CRUD, db→md) were not, so any `SELECT *` into a fixed struct is UNCONFIRMED; the
prebuilt `workable-items-vsc` binary is dated Sep 8 and was not rebuilt from current source.

### T004 — SIGPIPE idiom: build a SIBLING check
Decision: a new registered script (working name `verify-shell-pipefail-sigpipe.sh`) copying the skeleton of
`verify-shell-continuations.sh` (enumeration over `git ls-files '*.sh'`, three-valued rc, `--prove-failure` lab),
NOT an in-place extension: that gate's F1/F2 are context-free zero-tolerance syntax defects, while this idiom is
pipefail-conditional and producer-dependent and needs an allow-list. Measured candidates over 95 tracked `*.sh`:
33 `| grep -q*` REGEX hits in files that set pipefail (at least 2 are not pipes: `verify-shell-continuations.sh:164` and `_tools/prove-watch-deploy-verdict.sh:21`) (15 with a non-`printf` producer, e.g. `verify-content-boundary.sh:1144`,
`verify-provider-ci.sh:349,378`, `verify-workable-items.sh:121`, `qa-up.sh:109,113,326`, several in
`setup-agents-wizard.sh`); `printf` is a builtin and only SIGPIPEs above the ~64 KB pipe buffer, so a purely
syntactic detector over-reports it. No output size was measured per site, so NO exploitable count is claimed.
**Open policy decision (operator/Phase 2):** whether `printf`/`echo` producers are exempt.

### T005 — baseline captured (path-normalised) in `baseline/`
Files: `workable_items.db.sha256`, `gitlinks.txt` (22), `umbrella-head.txt`, and the outputs of
`verify-workable-items.sh` (rc 2: COULD NOT DETERMINE, 2 unresolved), `verify-claim-ledger.sh` (rc 0) and
`verify-manifest-pins.sh` (rc 0), with `rc=` appended.

### T003 — `--run-proofs` measured (2026-09-25, in place, `systemd-run --user --scope -p MemoryMax=16G`, nice + ionice)
Exit 1 after **33 min 24.6 s** wall, peak RSS **1,181,344 KB (~1.13 GiB)**, 440 s user + 651 s system CPU; available memory stayed
16–18 GiB (swap was already ~7955/8191 MB used before the run — not caused by it). Summary line:
`CM-CHECK-REGISTRY: 120 PASS, 2 FAIL, 0 DEBT, 1 UNDET, 0 NOTE`. **The tree was unchanged**: `git status --porcelain` for the umbrella and all 22
submodules matches the pre-run capture (excluding this spec directory). Planning figure: budget ~35 min and ~1.2 GiB per full run, so the
3 h daily ceiling in plan.md is accepted with wide margin.
The run is NOT green, and each of these is a baseline finding for the register (none was investigated in Phase 1):
- FAIL `provider-ci`: its `--selftest` proof exited rc 1 (check M3 wanted 0 clean rows, got 2).
- FAIL `workable-items`: its `--prove-failure` proof exited rc 1 — the CONTROL ("well-formed copy validates clean") wanted rc 0 and got rc 2
  (consistent with the known roster gap; UNCONFIRMED).
- UNDET `content-boundary`: its paired proof hit the script's own 900 s per-proof timeout, so whether the proof works is unknown.
- The log carries no per-proof timings (a long quiet stretch of ~33 lines between minutes 7 and 14), so any other slow proof is UNCONFIRMED;
  the sweep's evidence records should capture per-proof duration.
**A recorded claim is now stale:** CLAUDE.md records `--run-proofs` as exiting 0 at "65 PASS / 0 FAIL" (2026-09-03); today it is 120 PASS / 2 FAIL / 1 UNDET.
The claim-ledger extension (T019/T066) must cover it.
