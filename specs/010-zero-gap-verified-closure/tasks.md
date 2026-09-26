---
description: "Task list for feature 010: Zero-Gap Verified Closure"
---

# Tasks: Zero-Gap Verified Closure

**Input**: Design documents from `specs/010-zero-gap-verified-closure/`
**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md),
[data-model.md](data-model.md), [contracts/](contracts/), [quickstart.md](quickstart.md)

> **For agentic workers:** REQUIRED — implement ONLY through `/speckit-superspec-execute` with the
> superpowers skills engaged (`subagent-driven-development`, `test-driven-development`,
> `systematic-debugging`, `verification-before-completion`, `requesting-code-review`). Operator
> directive 2026-09-25. Do not hand-implement tasks in the main loop.

**Tests**: REQUIRED here (the spec demands machine evidence). Every code task is `[TDD]`: write the
failing test, run it and CAPTURE the failure, implement, run and CAPTURE the pass. A `[TDD]` task
without a captured RED is not done.

**Organization**: grouped by user story; the register (US1) is the MVP and comes first.

## Format: `[ID] [markers] [Story] Description — files`

- **[P]** parallel (different files, no dependency) · **[TDD]** RED→GREEN→REFACTOR ·
  **[REVIEW]** independent review (a different agent, per §11.4.209) before dependents start ·
  **[SUBAGENT]** may be dispatched to a subagent.
- Paths are repository-relative. New `scripts/*.sh` MUST be registered in `scripts/check-registry.tsv`
  with a `--prove-failure` proof in the same task (repo rule R5).

## Global Constraints (every task's requirements include these)

- Exit codes are three-valued everywhere: **0** holds, **1** violated, **2** could not determine;
  a 2 is never a pass and a finding (1) outranks an undetermined (2).
- No new third-party dependency; reuse `docs/workable_items.db`, `_tools/workable-items`,
  `scripts/check-registry.tsv`, `scripts/verify-claim-ledger.sh`, and the constitution's recorder
  (`submodules/constitution/scripts/gates/lib/execution_record.sh`), chain verifier
  (`submodules/constitution/submodules/continuum/cmd/continuum-integrity` (Go source; the chain gate builds it with `go build` into `$TMP`)) and chain gates.
- Schema changes are ADDITIVE only (§11.4.93); never edit the constitution submodule or any
  third-party gitlink; never force-push; stage EXPLICIT paths only (never `git add -A` / `.`).
- Sweeps and the daily job never write tracked files; mutation proofs run on throwaway COPIES,
  never on shipped source; no private content is copied into any public file (paths only).
- Every evidence record states its population (`source`|`process`|`wire`), the exact command and a
  before/after state fingerprint; a moving tree yields rc 2, never a verdict.
- Operator-owned actions (package installs, provider settings, timer installation, submodule bumps,
  oomd protection, deploys) are QUEUED as `Operator-blocked` with the exact command — never done unasked.
- No guessing language in any produced record; every figure carries the command that produced it.
- Host safety: ≤60% RAM (`MemoryMax=16G`), thread-limit check before parallelism, no host
  suspend/reboot, one heavy job at a time.

- **Default RED for class/gate tasks**: a planted fixture yields rc 1 and the failure output is
  captured before any implementation. New directories (`_tests/fixtures/zero-gap/`, `docs/zero-gap/`,
  `ops/systemd/`) are CREATED by the task that first needs them.
- **Push path is serialised**: T040 → T041 → T065 are the only tasks that touch
  `scripts/pre-push-gates.sh`; test with `bash scripts/pre-push-gates.sh` directly (whether
  `git push --dry-run` runs the hook is UNCONFIRMED).
- **Captured outputs are path-normalised** and pass `bash scripts/audit-hardcoded-paths.sh` before commit.

## Review Focus (inputs the spec implies but no single task exercises)

1. An evidence store that is empty, absent or truncated mid-walk → REFUSE (rc 2), never intact.
2. A sweep class whose population enumerates to zero items → COULD-NOT-INSPECT / gap, never clean.
3. Two agents editing the tree during a run → UNSTABLE (rc 2); a fix that lands mid-run is not evidence.
4. A closed item whose fix is reverted → reopen-pending queued; the tracked register is untouched by the job.
5. A check that passes on both pre-fix and post-fix state (a hollow check) → closure refused (RED required).
6. A record containing a credential, guessing language, or private text → FR-020 gate fails the release.
7. A snapshot made with hardlinks lets an in-place writer alter the LIVE tree → snapshots are real copies, and T012's prover asserts the live tree is byte-identical before and after.
8. Date-dependent rules (recheck, plan_due) evaluated against `--as-of`, so repeats stay identical.

---

## Phase 1: Setup — resolve the unknowns the plan deferred

**Purpose**: turn every UNCONFIRMED in research.md into a measured fact BEFORE design work depends on it.

- [x] T001 [P] [SUBAGENT] Run the constitution's chain attack corpus and determine whether
  `continuum-integrity` can read a store shaped like `contracts/evidence-record.schema.json`; write the
  finding (and, if shapes differ, the adaptation on OUR side) into an addendum at the end of
  `specs/010-zero-gap-verified-closure/research.md`. Files: `submodules/constitution/scripts/gates/cm_chain_integrity_detects_alteration.sh`, `submodules/constitution/submodules/continuum/cmd/continuum-integrity` (Go source; the chain gate builds it with `go build` into `$TMP`).
- [x] T002 [P] [SUBAGENT] On a COPY of `docs/workable_items.db` in scratch, apply the planned additive
  columns and the `item_verdicts` table, then run the canonical validator
  (`submodules/constitution/scripts/workable-items/bin/workable-items-linux validate`, G6 of
  `scripts/verify-workable-items.sh`); record whether it tolerates them. Addendum in research.md.
- [x] T003 [P] Re-measure `bash scripts/verify-check-registry.sh --run-proofs` wall time and peak RSS on
  a quiet tree under `systemd-run --user --scope -p MemoryMax=16G`; accept or reject the 3 h ceiling in
  plan.md Performance Goals with the figures.
- [x] T004 [P] Decide extend-vs-sibling for the SIGPIPE idiom check: read
  `scripts/verify-shell-continuations.sh`; record the decision and evidence in research.md.
- [x] T005 Capture the pre-implementation baseline: `docs/workable_items.db` sha256, `git rev-parse` of
  every gitlink, and the output of `verify-workable-items.sh`, `verify-claim-ledger.sh`,
  `verify-manifest-pins.sh` into `specs/010-zero-gap-verified-closure/baseline/` (small text files, absolute paths normalised to `<repo>`; run `bash scripts/audit-hardcoded-paths.sh` before committing).

**Checkpoint**: every UNCONFIRMED is now measured or converted into a named task; T007's schema is final.

---

## Phase 2: Foundational (blocks every user story)

**Purpose**: the store, its validator and the shared libraries.

- [x] T010 [P] [TDD] (FIRST in this phase — T006–T008 consume it) Fixture corpus: CREATE golden-good and golden-bad registers plus a frozen-cycle fixture in
  `_tests/fixtures/zero-gap/registers/`; used by T007/T008 and by every later prover.
- [x] T006 [TDD] Additive schema migration `gap migrate` (idempotent, `--dry-run`): columns
  `kind, category, disposition, classification_reason, classification_owner, classification_recheck,
  plan_due, research_ref, measurable_target, recurrence_of, reopens_count, cycle, sweep_class,
  first_seen_fingerprint` on `items` and add-on table `item_verdicts` per data-model.md. Files:
  `_tools/workable-items/internal/wi/gapschema.go`, `_tools/workable-items/internal/wi/gapschema_test.go`, `_tools/workable-items/main.go`.
  RED: migrating twice changes nothing on the second run; an `item_verdicts` row whose `item_id` does not exist is rejected by a NEW validator rule V-G12 (T002's review showed the tables accept an orphan today); a migrated DB still opens under the canonical tool.  _Covers: FR-002._
- [x] T007 [TDD] Validator rules V-G1..V-G10 with `--as-of`, one RED test and one mutation each
  (contracts/register-cli.md): `_tools/workable-items/internal/wi/validate_gap.go`, `validate_gap_test.go`.
  Includes the closed severity/category/kind sets and the four classification reasons; refuses
  `accepted-as-is`; rejects any item-set change in a frozen cycle; **V-G11**: every `Operator-blocked`
  item has `operator_block_details` listing unblock options AND the cost of each (FR-009).  _Covers: FR-002, FR-006, FR-008, FR-009, FR-025, FR-026, SC-003, SC-011._
- [x] T008 [TDD] `gap` subcommands `add, classify, close, reopen, link, apply-queue, freeze, summary`
  (`--json` byte-stable for an unchanged DB): `_tools/workable-items/internal/wi/gapcmd.go`, `gapcmd_test.go`,
  `_tools/workable-items/main.go`. RED first: `close` exits 1 unless RED+GREEN evidence for the same
  check id, an `item_verdicts` row from a different actor, a review verdict, a closure check authored
  by someone other than the fixer, and `research_ref` all exist. The review verdict is stored in `item_verdicts` with `role='reviewer'` (never `item_history`).  _Covers: FR-002, FR-006, FR-007, FR-008, FR-022, FR-024._
- [x] T009 [REVIEW] Independent review of T006–T008 (schema additivity, canon vocabulary conflicts,
  determinism of `summary`). Blocks T010+ consumers.
- ~~T011~~ **Withdrawn and moved to the T047 governance wave** (review finding): closing G4 before the register exists would skip this list's own closure rules, and `seed-roster` only copies existing rows.
- [x] T012 [TDD] Shared library `scripts/zero-gap-lib.sh`: sha256 state fingerprint over a
  (path, blob-sha) population taken before AND after a check; UNSTABLE ⇒ rc 2; three-valued helpers;
  deterministic sorting. Register as an `exempt` library row with its reason. Prover
  `scripts/zero-gap-lib.sh --prove-failure` (mutating a file mid-run must yield rc 2).  _Covers: FR-012._
- [x] T013 [TDD] Evidence adapter `scripts/zero-gap-evidence.sh`: wraps the constitution recorder and emits TWO files — a verifier-native chain file (9 fields, genesis `""`, via upstream `chain.ExecRow.ToRecord`, which is library-only: T013 therefore includes a small Go shim `_tools/zero-gap-chain/` (imports the nested `continuum` chain package; the caller computes `PrevDigest` with `chain.Digest`; `ToRecord` needs a canonical-decimal STRING `exit_status` and records only `argv[0]` as `command`)) and a sidecar bound by `artifact_path = sha256:<sidecar line>` (T001 finding);
  adds `item_id, check_id, fingerprints, population_kind, outcome, verdict_role`, redacts streams
  before write, validates every record against `contracts/evidence-record.schema.json`.  _Covers: FR-014._
- [x] T014 [TDD] Evidence chain + anchor (the adapter re-hashes every sidecar line against the chain's `artifact_path` —
  the verifier never reads the sidecar): seal records into an append-only chain; write the anchor with
  `continuum-integrity anchor write` in its upstream format (`{head_digest, entry_count, anchor_strength}`,
  our honest value `policy`); a git-history verifier asserts PER-COMMIT forward-only (entry_count never drops;
  each earlier head_digest equals the digest of the chain record at that position). RED: the constitution attack
  corpus (mutation, deletion, reorder, absent store, unwalkable chain ⇒ REFUSE; healthy ⇒ PASS; tail-truncation
  and delete+re-chain ⇒ caught ONLY by the anchor) PLUS the sidecar attacks and invariants listed in
  data-model.md "Adapter invariants". Files: `scripts/zero-gap-evidence-chain.sh`.  _Covers: FR-016._
- [x] T015 [REVIEW] Independent review of T012–T014, including the honest-strength wording of the anchor.
- [x] T016 Register T012–T014's scripts and library in `scripts/check-registry.tsv` (R5) with paired
  proofs; `bash scripts/verify-check-registry.sh` must stay exit 0. EVERY later script task registers
  its own row in its own task (R5 fails the registry the moment an unregistered `*.sh` appears).  _Covers: FR-013._

**Checkpoint**: store, validator, fingerprint, evidence chain and their proofs are green — user stories may start.

---

## Phase 3: User Story 1 — one complete, machine-derived register (P1) 🎯 MVP

Each class task T019–T034 owns ONLY `scripts/zero-gap-class-<id>.sh` plus its corpus under
`_tests/fixtures/zero-gap/<id>/`; its `docs/zero-gap/sweep-classes.tsv` row was pre-seeded by T017, and its
`scripts/check-registry.tsv` row is APPENDED by the class task itself as exactly one line (the command is in
`docs/zero-gap/README.md` "Registering a class"). Class implementers never stage or commit anything; the
controller makes ONE commit for the whole class wave once every script and row exist and
`bash scripts/verify-check-registry.sh` exits 0.

**Goal**: one deterministic sweep that produces the register, states each class's recall, and lists
what it could not inspect.
**Independent Test**: two sweeps on an unchanged fingerprinted state are byte-identical; a planted
defect per class appears; an uninspectable part is listed, never clean.

- [x] T017 [TDD] [US1] (pre-seeds ALL class rows in `docs/zero-gap/sweep-classes.tsv`; registry rows cannot be pre-seeded for scripts that do not exist yet (R3/R2 fail, measured), so each class task appends its own one-line `scripts/check-registry.tsv` row, nobody stages, and the controller makes one wave commit) Runner `scripts/zero-gap-sweep.sh` per `contracts/sweep-runner.md`
  (`--class --json --out --expect-fingerprint --prove-failure`; findings sorted; per-class table;
  fingerprint pair; `COULD-NOT-INSPECT` lines) and the data file `docs/zero-gap/sweep-classes.tsv`
  (schema in data-model.md). RED: an empty class list, a missing entrypoint, and a moving tree each yield rc 2.  _Covers: FR-001, FR-003, FR-005, FR-012._
- [x] T018 [TDD] [US1] (same file as T017, so serial) Recall engine inside the runner: recall = planted-found / planted from each
  class's corpus; `recall=UNKNOWN` printed next to every "no findings" for a class without a corpus.  _Covers: FR-004, SC-002._
- [x] T019 [P] [SUBAGENT] [TDD] [US1] Class `stale-figures`: extends `scripts/verify-claim-ledger.sh`
  toward `--completeness` (recorded counts in carriers, CONTINUATION.md, docs) with a planted-stale corpus.  _Covers: FR-001._
- [x] T020 [P] [SUBAGENT] [TDD] [US1] Class `vacuous-gates`: gates that pass on an empty population or run
  zero cases; corpus of empty-population fixtures.  _Covers: FR-001._
- [x] T021 [P] [SUBAGENT] [TDD] [US1] Class `unproven-checks`: any check without a paired
  `--prove-failure`; built on `check-registry.tsv`.  _Covers: FR-001, FR-013, SC-007._
- [x] T022 [P] [SUBAGENT] [TDD] [US1] Class `pointer-drift`: gitlink vs `helix-deps.yaml` vs remote for
  ALL configured remotes (not only `origin`), and vs carriers.  _Covers: FR-001._
- [x] T023 [P] [SUBAGENT] [TDD] [US1] Class `content-boundary-rows`: registers the RED rows of
  `scripts/verify-content-boundary.sh` as items by count and path class; NEVER allow-lists them.  _Covers: FR-001._
- [x] T024 [P] [SUBAGENT] [TDD] [US1] Class `live-vs-source`: running binary/stamp vs `HEAD` for workshop
  (`/api/health` build id) and ai_interviewing; population_kind `wire`.  _Covers: FR-001, FR-017._
- [x] T025 [P] [SUBAGENT] [TDD] [US1] Class `build-if-missing`: start scripts that build only a missing
  binary (ai_interviewing `platform/scripts/start.sh:17` is the known seed).  _Covers: FR-001._
- [x] T026 [P] [SUBAGENT] [TDD] [US1] Class `missing-toolchain`: gates that exit 2 for an absent tool
  (tesseract, webkit libraries, bundle, jekyll, docker) → `Operator-blocked` items with the exact install command.  _Covers: FR-001._
- [x] T027 [P] [SUBAGENT] [TDD] [US1] Class `unregistered-scripts`: R5 as a sweep class across all owned scanroots.  _Covers: FR-001._
- [x] T028 [P] [SUBAGENT] [TDD] [US1] Class `unsealed-evidence`: gates that produce no sealed record.  _Covers: FR-001._
- [x] T029 [P] [SUBAGENT] [TDD] [US1] Class `untracked-blind-window`: gates over "the repo" that ignore
  untracked-not-ignored files without stating it.  _Covers: FR-001._
- [x] T030 [P] [SUBAGENT] [TDD] [US1] Class `private-in-public`: FR-020 scan reused as a sweep class
  (credentials, guessing language, private text) over public records.  _Covers: FR-001, FR-020._
- [x] T031 [P] [SUBAGENT] [TDD] [US1] Class `doc-count-drift`: documented counts vs measured counts
  (e.g. workshop `CLAUDE.md` gate counts).  _Covers: FR-001._
- [x] T032 [P] [SUBAGENT] [TDD] [US1] Class `coverage-gaps`: registers every `gap` cell from the
  coverage map (needs T052's coverage data; until then the baseline T036 records this class as `COULD-NOT-INSPECT`, never clean).  _Covers: FR-001._
- [x] T033 [P] [SUBAGENT] [TDD] [US1] Class `guard-gaps`: destructive commands the PreToolUse guard does
  not block (`git checkout --`, `restore`, `stash`, `clean -fd`, `add -A`) — third-party/constitution code,
  so registered `classified: third-party` with the reporting route (FR-021).  _Covers: FR-001, FR-021._
- [x] T034 [P] [SUBAGENT] [TDD] [US1] Class `known-open-decisions`: the operator-decision backlog
  (behind-remote submodules, indexed evaluation artefacts, question-shape leak, oomd, Lumen leg,
  `GIT_OPTIONAL_LOCKS`, provider-CI unverified rows) as items with options and cost (FR-009).  _Covers: FR-001, FR-009._
- [x] T035 [TDD] [US1] Determinism harness `scripts/zero-gap-determinism.sh` (`--check <id>`; N=5
  repeats; sha256 of normalised output; any difference ⇒ registered UNSTABLE, not evidence).  _Covers: FR-003, FR-015, SC-001, SC-006._
- [x] T036 [US1] BASELINE sweep on a quiet tree (on a frozen REAL COPY — `rsync -a` of the tracked tree plus needed untracked inputs, never hardlinks — if the live tree moves) and the
  per-class recall table. Nothing is seeded yet.  _Covers: FR-001._
- [ ] T037 [P] [TDD] [US1] CREATE `workable-items-vsc report --by-module` (does not exist yet) generating a per-module page (SC-010) — RED: golden-bad register yields rc 1;
  timed walk-through recorded once.  _Covers: FR-024, SC-010._
  STATUS 2026-09-26: code + tests delivered and reviewed (rc 0/1/2 proven, script timing 35 ms); the SC-010 HUMAN timed walk-through is PENDING and is taken at the T038 checkpoint — this task is ticked only when that walk-through is recorded.
- [ ] T081 [TDD] [US1] (after T037; numbered out of sequence to keep earlier ids stable) Improvement intake:
  CREATE sweep class `improvement-candidates` (`scripts/zero-gap-class-improvement-candidates.sh`, corpus
  `_tests/fixtures/zero-gap/improvement-candidates/`) that harvests improvement candidates from recorded
  operator decisions, KNOWN-LIMITATIONS-style documents and `Operator-blocked` items, PLUS a manual intake
  path (`gap add --kind improvement --measurable-target ...`). RED: a candidate with no measurable target is
  rejected (V-G4). The operator sets the cycle-1 improvement cap at the T038 checkpoint. (FR-001, FR-025)  _Covers: FR-001, FR-025._
- [ ] T038 [REVIEW] [US1] Independent review of the runner, each class's recall claim and the baseline
  output. ONLY THEN: seed the register with `gap add`, publish the recall table, and take the **human
  checkpoint** (operator sizes the improvement scope), and run `gap freeze --cycle 1` immediately
  (FR-026) — discoveries made during the closure waves are assigned to cycle 2.  _Covers: FR-025, FR-026, SC-011._

**Checkpoint**: the register is complete relative to its stated recall and byte-stable; MVP delivered.

---

## Phase 4: User Story 2 — every item closed with proof or classified (P1)

### Closure-wave protocol (applies to EVERY wave task T043–T049)

Each wave task MUST follow this, verbatim, or stop and queue:
(a) **Selection by query**: items = `workable-items-vsc gap summary --json` filtered by the wave's
    category and `cycle=1`; the list is captured at start and does not grow mid-wave.
(b) **Per-item loop** (named, no shortcuts): read `docs/zero-gap/CLOSURE.md` → capture RED →
    fix → `scripts/zero-gap-verify.sh --item <id>` → `item_verdicts` row from a DIFFERENT agent →
    independent review → `gap close`.
(c) **Done condition**: zero `open` items remain in the category AND every `classified` item passes V-G2.
(d) **Batch limit**: at most 5 items per subagent dispatch, one heavy job at a time, `MemoryMax=16G`.
(e) **Stop-and-queue**: anything operator-owned (gitlink bumps, installs, site pushes, provider or
    `.claude/settings.json` changes, deploys) is queued as `Operator-blocked` with the exact command.
(f) **Bans**: never touch the live workshop binary (`workshop/platform/bin`), never copy private text, never edit
    a third-party gitlink, never stage with `add -A`.
(g) **Ownership**: an item spanning categories belongs to its PRIMARY category's wave; one committer per repository.

**Goal**: each item ends closed-with-evidence, classified (four reasons), or open with a dated plan.
**Independent Test**: pick a closed item; its check fails on the pre-fix ref and passes on the current ref.

- [ ] T039 [TDD] [US2] `scripts/zero-gap-verify.sh --item <id>`: re-runs the recorded check against the
  pre-fix ref (scratch worktree) and the current ref; both captured as sealed records; a hollow check
  (passes on both) refuses closure.  _Covers: FR-007, SC-004._
- [ ] T040 [TDD] [US2] `scripts/zero-gap-guard-checks.sh` (FR-023): a diff that removes a
  `check-registry.tsv` row, deletes a check, or adds an allow-list/exempt entry without a paired proof
  fails; wired into `scripts/pre-push-gates.sh`. Files: `scripts/zero-gap-guard-checks.sh`, `scripts/pre-push-gates.sh`.  _Covers: FR-013, FR-023, SC-007._
- [ ] T041 [TDD] [US2] (after T040; serial on `scripts/pre-push-gates.sh`) Third-party edit guard as a
  pre-push gate check: refuse a push whose diff modifies files under `submodules/superspec` or any
  gitlink classified third-party; classification data in `docs/zero-gap/`.  _Covers: FR-021._
- [ ] T042 [US2] Closure procedure document `docs/zero-gap/CLOSURE.md` (hand-written rules only — including the severity/category rubric from data-model.md; every
  status and count is generated): RED-first, evidence capture, independent verdict, review, `research_ref`.
- [ ] T043 [P] [SUBAGENT] [REVIEW] [US2] CLOSURE WAVE `security` — every item of category `security`
  (credential handling and any destructive-command guard gap that IS fixable project-side; editing
  `.claude/settings.json` is queued as an operator decision, not done) via the protocol above.
- [ ] T044 [P] [SUBAGENT] [REVIEW] [US2] CLOSURE WAVE `data-integrity` and `content-boundary`.
- [ ] T045 [P] [SUBAGENT] [REVIEW] [US2] CLOSURE WAVE `false-evidence` (vacuous gates, unproven checks,
  hollow proofs, stale figures).
- [ ] T046 [P] [SUBAGENT] [REVIEW] [US2] CLOSURE WAVE `availability` and `build-freshness`
  (ai_interviewing start-script trap; live-vs-source drift).
- [ ] T047 [P] [SUBAGENT] [REVIEW] [US2] CLOSURE WAVE `governance-drift` and `docs-drift`
  (carrier/CONTINUATION/README counts, workshop CLAUDE.md counts, badge row §11.4.259, zero-findings
  sweep §11.4.261 items actionable in this tree), INCLUDING the roster gap G4: add 8 `proposed`
  rows to `docs/workable-items/sub-projects.tsv` for challenges, doc_processor, llm_orchestrator,
  llm_provider, llms_verifier, qa, security, vision_engine (prefixes need operator ratification — queue it), then run
  `roster` and `seed-roster`; note `submodules/llm_provider` (HelixDevelopment) duplicates
  `submodules/LLMProvider` (vasic-digital) and is registered as its own item.
- [ ] T048 [P] [SUBAGENT] [REVIEW] [US2] CLOSURE WAVE `ux-accessibility` (workshop, ai_interviewing, sites).
- [ ] T049 [P] [SUBAGENT] [REVIEW] [US2] CLOSURE WAVE `host-capability` — prepare and queue the
  `Operator-blocked` install items (tesseract, webkit libs); verify everything else.
- [ ] T050 [US2] Operator queue: every `Operator-blocked` and `classified` item lists its unblock options,
  cost, exact command, owner and recheck date (FR-009); present the queue to the operator. Includes the
  gitlink bumps that end each wave and the three behind-remote submodules.  _Covers: FR-006, FR-009, SC-003._
- [ ] T051 [REVIEW] [US2] Independent review of all closed items' evidence pairs.  _Covers: FR-022._

**Checkpoint**: zero items lack a state, owner or evidence (SC-003); no item is classified except for the four reasons.

---

## Phase 5: User Story 3 — every test kind applied to every part (P2)

**Goal**: a generated module × test-kind matrix with zero blank or unexplained cells.
**Independent Test**: delete one kind's checks in a disposable copy — the cell becomes a gap.

- [ ] T052 [TDD] [US3] Generator `scripts/zero-gap-coverage.sh` + data `docs/zero-gap/coverage.tsv`
  (`subject`, `test_kind`, `status ∈ {check,n/a,gap,could-not-run}`, `ref`); a `check` cell whose last
  recorded run executed zero cases becomes a gap; missing tool ⇒ `could-not-run:<tool>`; `--prove-failure`.  _Covers: FR-010, FR-011, SC-005._
- [ ] T053 [SUBAGENT] [US3] Re-measure every cell of the seed matrix from research D10 with real runs
  (not name counts) and write the true map; extra kinds proposed: content-boundary, claim-ledger, gate
  paired-mutation, SEO/i18n completeness, link integrity, export validation, provider-CI,
  host-capability, fuzz, visual-diff.  _Covers: FR-010._
- [ ] T054 [P] [SUBAGENT] [TDD] [US3] Close gap cells: contract tests for workshop and ai_interviewing HTTP APIs.
- [ ] T055 [P] [SUBAGENT] [TDD] [US3] Close gap cells: load/perf for workshop and ai_interviewing
  (bounded, `MemoryMax`, against a scratch server — never the live one).
- [ ] T056 [P] [SUBAGENT] [TDD] [US3] Close gap cells: stress/chaos for workshop backend, ai_interviewing,
  verdict, passage, curriculum-kit (kill/restart, provider-down, slow-backend, and disk-full simulated ONLY on a bounded tmpfs or inside a container — never the host filesystem).
- [ ] T057 [P] [SUBAGENT] [TDD] [US3] Close gap cells: fuzz targets (`func Fuzz`) for parsers/validators
  outside `submodules/qa`.
- [ ] T058 [P] [SUBAGENT] [TDD] [US3] Close gap cells: mutation proofs for modules without any
  (ai_interviewing, verdict, passage, umbrella `_tools/gen`), run on COPIES.
- [ ] T059 [P] [SUBAGENT] [TDD] [US3] Close gap cells: accessibility for ai_interviewing frontend;
  security spec for workshop frontend.
- [ ] T060 [P] [SUBAGENT] [TDD] [US3] Close gap cells: determinism tests per module beyond
  `reproducibility-selftest.sh`; manual-QA-readiness checks (`scripts/qa-up.sh` boots, all four health
  endpoints answer, documented ports discovered not fixed).
- [ ] T061 [REVIEW] [US3] Independent review of the matrix and of any test that reports PASS with zero cases.

**Checkpoint**: SC-005 — no blank cell; every gap is a register item.

---

## Phase 6: User Story 4 — evidence that cannot lie (P1)

**Goal**: every claim backed by sealed, reproducible, machine-created evidence; no false result anywhere.
**Independent Test**: re-run any recorded command five times on an unchanged state → five identical verdicts; break the guarded thing → the verdict flips.

- [ ] T062 [TDD] [US4] `scripts/zero-gap-scan-records.sh` (FR-020): guessing language in causal
  statements, credentials, private-text leakage over `docs/zero-gap/`, `specs/010-*/`, the register export
  and evidence streams; release gate wired into `gap freeze` and the pre-push gates (coordinated with the T065 serial order); corpus of planted violations.  _Covers: FR-020, SC-008._
- [ ] T063 [TDD] [US4] Wire-evidence rule (FR-017): records with `population_kind=wire` MUST carry a
  wire-capture digest (HTTP response or socket capture); source-only measurements are labelled `source`. RED: a `wire` record without a capture digest is rejected.  _Covers: FR-014, FR-017._
- [ ] T064 [US4] Run the five-repeat determinism harness over every registered check; register each
  UNSTABLE check as an item and exclude it from evidence until fixed.  _Covers: FR-015, SC-006._
- [ ] T065 [TDD] [REVIEW] [US4] (after T041; the LAST task touching the push path) Feed sealed records from `run_gate` in `scripts/pre-push-gates.sh`
  (timestamp, fingerprints, seal) — careful: the gate runner is the push path; RED first, then a
  dry-run push; revert plan documented. Files: `scripts/pre-push-gates.sh`.
- [ ] T066 [SUBAGENT] [TDD] [US4] (after T019; same ledger) Widen `docs/claim-ledger.tsv` toward `--completeness`: register the
  carriers' and CONTINUATION.md's recorded counts as ledger rows with their re-measure commands.
- [ ] T067 [US4] Verify SC-006/SC-007/SC-008 across the whole tree and record the tables.  _Covers: SC-007, SC-008._

**Checkpoint**: zero unmeasured assertions, zero unsealed evidence, every check proven able to fail.

---

## Phase 7: User Story 5 — independent verification and no silent regression (P2)

**Goal**: a different automated agent verifies every closed item; the system re-measures daily.
**Independent Test**: revert a closed item's fix in a disposable copy — the next run flags reopen-pending with failing evidence.

- [ ] T068 [TDD] [US5] Independent-verdict flow: `item_verdicts` rows require `actor ≠ fixer`
  (`actor_kind` agent|script); RED: a verdict whose actor equals the fixer is rejected; disagreement blocks `gap close`; uses the constitution
  `independence_tier.sh` where applicable.  _Covers: FR-018._
  **Before T068 runs the witness fetch daily, fix T014 finding N3** (no submodule recursion, no auto-maintenance, pin `remote.<r>.uploadpack`; see progress.yml). **T068 MUST ALSO bind closure evidence to the evidence chain** (T009 re-review rulings, 2026-09-25): `gap close` and `gap verdict`
  require, for every cited RED/GREEN/verifier record, that `sha256(record bytes)` equals the `artifact_path` of the chain record whose
  `seq = chain_seq` in a store that `scripts/zero-gap-evidence-chain.sh --verify` passes (rc 0); the verifier record's
  `author_session_id` must differ from the GREEN's; a closed item is re-verified against the chain on every `validate`. Until T068
  lands, **"closed" means structurally consistent and self-asserted, NOT proof of an independent run** (an unsigned verifier record can be
  forged by editing a copy of the GREEN — demonstrated in review); the operator inherits that residual risk and FR-016/FR-018 are NOT
  claimed met by the register alone. (FR-016, FR-018)
- [ ] T069 [TDD] [US5] `scripts/zero-gap-daily.sh` per `contracts/daily-job.md`: `flock` single-instance,
  long-op registered BEFORE it runs in `.remember/logs/zero-gap/ops-registry.jsonl` with the exact
  §11.4.232(A) terminal states, heartbeat and no-progress budget, host-pressure refusal (rc 2),
  fingerprint before/after, sealed records, untracked report, `notify-send` on RED/STALE, reopen requests
  appended to `.remember/logs/zero-gap/reopen-queue.jsonl` — and NEVER any write to tracked files. It runs on a frozen REAL COPY (`rsync -a`, never `cp -al`/hardlinks: gates rewrite tracked evidence files in place — the pre-push run regenerated tracked PNGs and `perf-budget.json` on 2026-09-25 — and a hardlink snapshot would write through into the live tree; the live tree also moves constantly). RED: `git status --porcelain`, recursing into submodules, is byte-identical before and after a run that includes `--run-proofs`. `--now` for on-demand.  _Covers: FR-019._
- [ ] T070 [P] [US5] Prepare `ops/systemd/zero-gap-daily.service` and `zero-gap-daily.timer`
  (`OnCalendar=daily`, `Persistent=true`, `RandomizedDelaySec=900`, `MemoryMax=16G`, `Nice=10`,
  `IOSchedulingClass=idle`) and their install/uninstall notes — NOT installed.  _Covers: FR-019._
- [ ] T071 [TDD] [REVIEW] [US5] Revert test (SC-009) in a disposable copy: revert a closed item's fix →
  daily run queues reopen-pending with the failing evidence; `gap apply-queue` inside a commit reopens it.  _Covers: FR-019, SC-009._
- [ ] T072 [US5] Queue the timer installation as an `Operator-blocked` item with the exact commands
  (`systemctl --user daemon-reload`, `enable --now`) and the rollback.
- [ ] T073 [US5] Independent verification pass: a different agent re-runs the evidence of EVERY closed
  item and records its verdict; any disagreement reopens the item.  _Covers: FR-018, SC-004._

**Checkpoint**: SC-004 and SC-009 hold; the daily job runs on demand and is ready for the operator to install.

---

## Phase 8: Polish, freeze and hand-off

- [ ] T074 Close cycle 1: verify the T038 freeze still re-derives byte-identically, write
  `docs/zero-gap/cycles/1/` (freeze.json, register export, chain head + anchor); items discovered during the waves are
  already in cycle 2.  _Covers: FR-026, SC-011._
- [ ] T075 Update every carrier and document whose stated fact changed (same commit as its cause):
  CLAUDE.md/AGENTS.md/QWEN.md/GEMINI.md (lockstep), `CONTINUATION.md`, `docs/check-registry.md`,
  workshop `CLAUDE.md` counts; run `scripts/verify-claim-ledger.sh` and `scripts/continuation-check.sh`.
- [ ] T076 [P] Generate exports for new docs per §11.4.65 where a generator exists; record any gap as an item.
- [ ] T077 Run `quickstart.md` end to end (every [TARGET] command now exists) and paste the outputs.
- [ ] T078 If the programme discovered new project-wide rules, propose an amendment to the PROJECT
  `.specify/memory/constitution.md` via `/speckit-constitution` (MINOR bump); `submodules/constitution` is never edited.
- [ ] T079 [REVIEW] Final independent review against the spec: an SC-001..SC-011 audit table with the
  command and captured output for each criterion.
- [ ] T080 Commit and push the umbrella and every touched NON-SITE module through the `commit` wrapper
  (explicit staging, pre-push gates green, no force-push). `milosvasic.ru` self-publishes on push and
  `vasic.digital` triggers a Pages build, so any push to either site module is an operator decision, and every gitlink bump is too.

---

## Dependencies & Execution Order

- Phase 1 → Phase 2 → everything else. T006 depends on T002; T014 on T001; T012–T014 are independent of T006–T008.
- T009 gates T010+ consumers; T015 gates T016 and later consumers of the evidence chain.
- **US1 (Phase 3) is the MVP.** T017 → T018; T019–T034 are independent classes (parallel after T017/T018);
  T035 after T017; T081 after T037; T036 after T019–T034 (T032 as COULD-NOT-INSPECT until T052); T038 after T036. T032 needs T052's data (stub first).
- **US2 (Phase 4)** needs a seeded register (T036) and the verify/guard scripts (T039–T041); closure waves
  T043–T049 are parallel per category with ONE committer per repository and explicit-path staging.
- **US3 (Phase 5)** T052 first, then T053, then T054–T060 in parallel; T061 last.
- **US4 (Phase 6)** T062–T063 independent; T065 after T013–T015 and is the only task touching the push path.
- **US5 (Phase 7)** T068 → T069 → T071; T070 parallel; T073 after all closure waves.
- Phase 8 last; T074 needs every wave finished and the register frozen-eligible.

## Parallel Example: Phase 3 classes

```text
Subagent A: T019 stale-figures      Subagent B: T020 vacuous-gates     Subagent C: T021 unproven-checks
Subagent D: T022 pointer-drift      Subagent E: T023 content-boundary  Subagent F: T024 live-vs-source
(each owns only its own class file + corpus; no shared files; the runner contract from T017 is fixed)
```

## Implementation Strategy

1. **MVP**: Phases 1–3 → a complete, deterministic register with measured recall (stop and validate; operator checkpoint at T036).
2. **Increment**: Phase 4 closure waves — value is items reaching zero unexplained; Phase 5–7 add coverage, evidence hardening and drift detection in parallel streams.
3. **Never**: hand-implement outside `/speckit-superspec-execute`; skip a RED; edit a third-party gitlink; install the timer or bump a gitlink unasked; touch the live workshop binary (`platform/bin`).
4. Each task ends with: captured RED, captured GREEN, independent review where marked, explicit-path commit through the wrapper.
