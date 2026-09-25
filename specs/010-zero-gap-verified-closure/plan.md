# Implementation Plan: Zero-Gap Verified Closure

**Branch**: `010-zero-gap-verified-closure` | **Date**: 2026-09-25 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/010-zero-gap-verified-closure/spec.md`

## Summary

Turn the spec's five stories into tooling and a working programme, **reusing what the repository
and the constitution already ship** (constitution §11.4.74, extend rather than reimplement):

1. **Register (US1, FR-001..005, FR-024, FR-026)** — the canonical workable-items SQLite store
   `docs/workable_items.db` (§11.4.93, tracked, 530 rows today, no Bug rows) is extended
   ADDITIVELY into the gap register; a deterministic sweep runner enumerates the estate from a
   data file of *sweep classes*, each carrying a planted-defect corpus so recall is measured, not
   claimed.
2. **Closure (US2, FR-006..009, FR-021..023, FR-025)** — every item ends `closed` / `classified` /
   `open`; "classified" is a NEW column pair because it is not in the closed §11.4.15 status set;
   closure requires a recorded RED-on-pre-fix / GREEN-on-post-fix pair.
3. **Coverage (US3, FR-010..011)** — a generated (never typed) module × test-kind matrix built
   from `check-registry.tsv` entries and declared data; an empty population is a gap.
4. **Evidence (US4, FR-012..017, FR-020)** — an append-only, sealed evidence chain built from the
   constitution's own shipped recorder (`scripts/gates/lib/execution_record.sh`), chain verifier
   (`submodules/continuum/cmd/continuum-integrity`) and chain gates
   (`cm_chain_integrity_detects_alteration.sh`, `cm_anchor_detects_tail_truncation.sh`; the chain gate
   ran clean, 8 PASS). UNCONFIRMED until the adapter task: that the verifier can read our store shape, fed from
   `pre-push-gates.sh`'s `run_gate` and the sweep.
5. **Independence and drift (US5, FR-018..019)** — a separate verifier script and a distinct agent
   record a second verdict per closed item; a daily local `systemd --user` timer (Persistent,
   bounded, registered as a §11.4.232 long-op) re-measures everything and reopens regressions.

## Technical Context

**Language/Version**: POSIX `sh`/Bash for gates and runners (§11.4.67 parseability; repo convention),
Go 1.26.0 for `_tools/workable-items` (measured `go version`, 2026-09-25); SQLite as the store.
**Primary Dependencies**: none new. Reused: `docs/workable_items.db` and `_tools/workable-items`;
`scripts/check-registry.tsv` + `verify-check-registry.sh`; `scripts/verify-claim-ledger.sh`;
`scripts/verify-content-boundary.sh --expect-corpus` (state-fingerprint idea, upgraded from
`cksum` to sha256); constitution `scripts/gates/lib/{execution_record,independence_tier,
gate_mutation_harness,control_needle}.sh` and the chain/anchor gates.
**Storage**: (a) `docs/workable_items.db` — TRACKED, canonical (§11.4.93/95); (b) per-cycle tracked
records `docs/zero-gap/cycles/<cycle>/` (freeze fingerprint, register export, chain head + anchor
record); (c) daily raw run output UNTRACKED under `.remember/logs/zero-gap/` (`.remember/` is
git-ignored: `.remember/.gitignore` is `*`), with captured streams outside version control as the
recorder already requires (`stream_ref`).
**Testing**: Go unit tests for the store extension; shell provers with `--prove-failure` for every
new gate (§1.1); planted-defect corpora per sweep class; a five-repeat determinism harness
(SC-006); mutation runs on throwaway COPIES only (constitution: never on shipped source).
**Target Platform**: this Linux host; `systemd --user` timers work (14 exist at last count, Linger=yes,
`OnCalendar` + `Persistent=true` supported); `flock`, `systemd-run`, `notify-send` present;
`crontab` empty; `at` absent. `sqlite3` resolves only via an Android SDK path on this host, which does not matter: the Go tool uses
the pure-Go `modernc.org/sqlite` driver and shells out only to `git` (verified by review).
**Project Type**: governance/verification tooling inside the umbrella monorepo (scripts + one Go
tool + data files); no new service.
**Performance Goals**: cheap subset (manifest pins, continuation check, registry structure, cascade,
claim ledger) measured at ≈25 s total and <100 MB each (2026-09-25); daily FULL run budget is a
ceiling of 3 h wall-clock, dominated by `verify-check-registry.sh --run-proofs` (recorded ≈1 h in
CLAUDE.md, not re-measured today — the first baseline run MUST measure it before the ceiling is
accepted).
**Constraints**: ≤60% RAM (§12.6; host 30 GiB → `MemoryMax=16G`), thread-limit check before
parallelism (§12.12), `nice`/`ionice`, single instance via `flock` on a purpose-key file, registered
long-op with heartbeat and terminal verdict (§11.4.232), no CI/CD (§11.4.156), no force-push
(§11.4.113), private/public content boundary, never edit third-party code (FR-021), no commits
while the daily job writes tracked artifacts (§11.4.121/§11.4.84).

Every unknown is resolved or turned into a task in [research.md](research.md); no clarification marker remains.

## Constitution Check

*GATE: passed before Phase 0 and re-checked after Phase 1 design (both PASS, see bottom).*
Checked against `.specify/memory/constitution.md` v1.5.0 and the universal constitution it extends.

| Principle | Status | Notes |
|-----------|--------|-------|
| Evidence-Based Claims | PASS | Every register item cites evidence; counts are derived from rows, never typed (FR-024). |
| Honest Instruments (0/1/2) | PASS | Every new script is three-valued; "could not inspect" is a first-class register state (FR-005/FR-012). |
| Governance Fidelity | PASS | Fleet derived from `.gitmodules`; roster gap in `verify-workable-items.sh` G4 (8 modules without identifiers) is registered as the first real item. |
| Isolation by Default (paired mutation) | PASS | Every new check gets a `--prove-failure`; mutations run on throwaway copies (FR-013). |
| Comprehensive Documentation | PASS | `CONTINUATION.md` updated in the same commit as any non-trivial state change; docs generated from the DB, not hand-edited (§11.4.93). |
| Environment Adaptability | PASS | Paths, ports, MemoryMax derived/overridable; no host literals in new scripts. |
| Source Is Not Served | PASS | Evidence records name the population measured; running-product claims require wire evidence (FR-017). |
| A Snapshot Licenses Only Itself | PASS | Cycle freeze (FR-026) is an explicit fingerprinted snapshot; anything after it is next-cycle. |
| A Gate's Population Is Part of Its Claim | PASS | Each sweep class states its population and recall; a widened population needs a recorded justification before the count is read. |
| An Exemption Is a Claim That Can Expire | PASS | Classified items carry reason, owner, and a re-check date; expiry is machine-checked. |
| A Screen's Precision Is Not Its Recall | PASS | Recall per class from planted corpora, or printed UNKNOWN (FR-004). |
| A Gate Cannot See a Displacement Larger Than Its Window | PASS | Classes declare their comparison window; a bounded-window class cannot be the only instrument over a population. |
| A Rule Enforced by Nothing Is Not a Rule | PASS | Each requirement names its enforcing check in the traceability table (below). |
| Reproduce Before Repairing | PASS | Closure requires RED on the pre-fix state first (FR-007). |
| Shared-Tree Discipline | PASS | Explicit-path staging only; sweeps read, never write tracked files; daily output is untracked. The PreToolUse guard does NOT block `checkout --`/`restore`/`add -A` (measured), so this stays discipline + review. |
| A Restart Runs What Was Built | PASS | Applies to the ai_interviewing start-script gap, registered as a Bug item and fixed in the closure waves. |
| A Capability With Measured Harm Ships Off | PASS | Answering stays OFF; its item stays open until SC-010/SC-094 of feature 001 are met or explicitly reclassified by the operator. |
| The Content Boundary Is a Standing Invariant | PASS | Register/evidence describe private modules by path and description only; FR-020 scan is a release gate. `verify-content-boundary.sh` stays RED BY DESIGN — this feature does not allow-list it; its rows become register items. |
| Stage the Pointer and Its Manifest Together | PASS | Gitlink + `helix-deps.yaml` moved together; three behind-remote submodules stay operator decisions. |
| A Decision, Once Executed, Updates Its Carriers | PASS | Every closure that changes a stated fact edits its carrier in the same commit; the claim ledger (today a slice of 10) is widened toward `--completeness`. |
| Shell Idioms Must Survive `pipefail` | PASS | New scripts avoid `producer | grep -q`; covered by `verify-shell-continuations.sh` extension. |
| Independent review (§11.4.142/§11.4.209) | PASS | Every change reviewed by a different agent; model/effort per §11.4.209 as it currently reads. |
| No CI/CD (§11.4.156) | PASS | Daily job is a local user timer, not hosted automation (Clarification 3). |
| No force-push (§11.4.113) | PASS | Integration by merge + fast-forward only. |

**Complexity Tracking**: no violations to justify. One deliberate deviation from canon *vocabulary* is
recorded rather than hidden: "classified" is not in the §11.4.15 closed status set, so it is modelled
as a separate `disposition` + `classification_reason` column pair and the item keeps a legal status
(`Operator-blocked` with its options and costs, or plain `Queued` — the database cannot store the
`Queued — BLOCKED` sub-state).

## Project Structure

### Documentation (this feature)

```text
specs/010-zero-gap-verified-closure/
├── spec.md              # Feature specification (clarified 2026-09-25)
├── plan.md              # This file
├── research.md          # Phase 0 decisions (D1..D14)
├── data-model.md        # Phase 1 entities, columns, states, invariants
├── quickstart.md        # Phase 1 runnable validation guide
├── contracts/           # Phase 1 interface contracts
│   ├── register-cli.md          # workable-items gap subcommands (exit codes, flags)
│   ├── sweep-runner.md          # zero-gap-sweep.sh contract + sweep-classes.tsv schema
│   ├── evidence-record.schema.json
│   └── daily-job.md             # timer/service unit, long-op registry, surfacing
├── checklists/requirements.md
└── tasks.md             # /speckit-tasks output (not created here)
```

### Source Code (repository root)

```text
_tools/workable-items/            # EXTEND (Go): additive schema migration, `gap` subcommands, validator rules
scripts/
├── zero-gap-sweep.sh             # enumerate estate → findings (deterministic, three-valued)
├── zero-gap-verify.sh            # independent re-run of a closed item's evidence
├── zero-gap-coverage.sh          # generate module × test-kind matrix; empty population = gap
├── zero-gap-daily.sh             # full re-measurement wrapper (flock, bounded, registered long-op)
├── zero-gap-determinism.sh       # N-repeat harness (SC-006)
├── zero-gap-scan-records.sh      # FR-020: guessing language / credential / private-text scan
└── check-registry.tsv            # + rows registering every script above (R5)
docs/zero-gap/
├── sweep-classes.tsv             # DATA: class id, population, window, planted-corpus path, recall
├── coverage.tsv                  # DATA: (subject, test kind) → check id | n/a reason | gap
└── cycles/<cycle>/               # freeze fingerprint, register export, chain head + anchor
_tests/fixtures/zero-gap/         # planted-defect corpora + golden-good / golden-bad registers
ops/systemd/                      # zero-gap-daily.{service,timer} recipes (install is an operator action)
```

**Structure Decision**: extend the existing SSoT and check registry instead of a new database or
runner framework. New code is small, script-shaped, and each unit is registered in
`check-registry.tsv` with a paired proof (repo rule R5: an unregistered `*.sh` under a scanroot
fails `verify-check-registry.sh`). Recorder/chain logic is NOT rewritten; it is imported from the
constitution submodule and consumed read-only.

## Requirement → Enforcing Check Traceability

| Requirement | Enforced by (new unless marked reused) |
|---|---|
| FR-001..005, FR-024 | `zero-gap-sweep.sh` + `sweep-classes.tsv`; register report derived by `workable-items report` (reused) |
| FR-003, SC-001, SC-006 | `zero-gap-determinism.sh` (N identical repeats, sha256 of output) |
| FR-004, SC-002 | planted-defect corpus per class under `_tests/fixtures/zero-gap/`; recall printed per class |
| FR-006..009, SC-003 | `workable-items validate` extended rules (state machine, classification reasons, recurrence link) |
| FR-007, SC-004 | `zero-gap-verify.sh` runs recorded check on pre-fix ref and current ref; both captured |
| FR-010..011, SC-005 | `zero-gap-coverage.sh` (fails a cell whose check runs zero cases) |
| FR-012..013, SC-007 | three-valued exit convention + `--prove-failure` per check; `verify-check-registry.sh --run-proofs` (reused) |
| FR-014..017 | recorder + chain verifier from constitution gates (reused); sealed store; wire-evidence rule in sweep class metadata |
| FR-018, SC-004 | `zero-gap-verify.sh` invoked by a producer distinct from the fixer (§11.4.240 independence tier lib, reused) |
| FR-019, SC-009 | `zero-gap-daily.sh` + systemd user timer; reopen logic in `workable-items` |
| FR-020, SC-008 | `zero-gap-scan-records.sh` (release gate) |
| FR-021 | classification `third-party` + validator refuses edits under third-party gitlink paths (pre-push gate rule) |
| FR-022 | review verdict stored as an `item_history` row with reviewer identity; validator requires it for closure |
| FR-023 | `scripts/zero-gap-guard-checks.sh` (new, registered): a diff that removes a `check-registry.tsv` row, deletes a check, or adds an allow-list/exempt entry without a paired proof fails; run from the pre-push gates |
| FR-002, FR-006, FR-009 | validator V-G1 (owner, location, evidence ref), V-G10 (`plan_due` for open items), `operator_block_details` options+cost for `Operator-blocked` |
| FR-017 | records with `population_kind=wire` MUST carry a wire-capture digest (HTTP response or socket capture) the adapter validates; source-only measurements are labelled `source` |
| SC-010 | `workable-items-vsc report --by-module` generated page + a timed manual walk-through recorded once per cycle |
| FR-025, SC-011 | validator: Feature/improvement items require non-empty `measurable_target` |
| FR-026, SC-011 | `cycle freeze` records fingerprint; validator rejects membership change after freeze |

## Execution Strategy

### Implementation Mandate

Operator directive (2026-09-25): ALL implementation of this feature MUST be executed through the
`/speckit-superspec-execute` command with the superpowers skills fully engaged (test-driven
development, systematic debugging, verification before completion, subagent-driven execution,
independent code review). Tasks are produced by `/speckit-tasks` or `/speckit-superspec-tasks`
carrying the `[TDD]`, `[SUBAGENT]` and `[REVIEW]` markers from the sections below; nothing here is
implemented by hand outside that command.

### TDD Requirements

- [ ] `_tools/workable-items` schema migration + validator (state machine, classification, freeze):
  complex invariants; RED tests first, one per invariant (Go `_test.go`).
- [ ] `zero-gap-sweep.sh` classes: each class ships a planted-defect fixture that must produce a
  finding (RED) before the class is implemented.
- [ ] Evidence seal/anchor consumption: reuse the constitution's attack corpus (mutation, deletion,
  reorder, tail-truncation) against the store before trusting it.
- [ ] `zero-gap-coverage.sh`: a cell with zero executed cases must fail (FR-011).

### Parallel Execution Opportunities

- [ ] Store migration/validator (Go) and sweep-class fixtures share no files — parallel subagents.
- [ ] Sweep classes are independent of each other (one class per subagent) once the runner contract
  (`contracts/sweep-runner.md`) is fixed.
- [ ] Closure waves after the baseline are parallel per module (workshop, ai_interviewing,
  umbrella/sites, shared modules) — with **explicit-path staging** and one committer per repo.
- [ ] Independent verification (US5) runs in parallel with the next wave's fixes.

### Human Checkpoints

1. After the schema migration + validator: operator confirms the disposition/classification model
   (it introduces vocabulary canon does not have).
2. After the first BASELINE sweep: operator reviews the seeded register and the recall table before
   any fix wave starts (this is where the "improvement" scope of clarification 4 is sized).
3. Before installing the daily timer: operator installs it (a host configuration change) after
   reading `contracts/daily-job.md`.
4. Before each cycle freeze and before merge: final review against the spec.
5. Every operator-owned action found by the sweep (package installs, provider settings, pending
   submodule bumps — including the gitlink bump that ends each closure wave in `workshop` or
   `ai_interviewing` — oomd protection, exposing/deploying) is queued as `Operator-blocked` with its
   exact command; none is performed unasked.

### Review Gates

- [ ] Store schema + validator: independent review before any consumer is written.
- [ ] Sweep runner contract and each class's recall claim: review before its findings seed the register.
- [ ] Evidence store integration (chain/anchor): review, including the honest-strength statement of
  the anchor (git history + multi-upstream mirrors; append-only by policy, not cryptographically).
- [ ] Anything touching a private module's content or a third-party gitlink: review before merge.
- [ ] Every closure fix: independent review + independent verdict (FR-018/FR-022).

## Phase Outputs and Post-Design Constitution Re-check

Phase 0 → `research.md`; Phase 1 → `data-model.md`, `contracts/*`, `quickstart.md`. Post-design
re-check against the table above: still PASS. The one item needing operator attention is the
`disposition` vocabulary (checkpoint 1), status NEEDS ATTENTION: it is additive and
non-breaking but is new governance vocabulary, so it is flagged for the operator rather than assumed.
