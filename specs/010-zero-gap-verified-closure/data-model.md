# Data Model: Zero-Gap Verified Closure

All persistent state lives in the existing SQLite store `docs/workable_items.db` (additive changes
only, §11.4.93) plus small tracked data files. No new database.

## Entities

### GapItem (extends `items`)
Existing columns are kept unchanged (`atm_id, type, status, severity, title, description,
forensic_anchor, closure_criteria, composes_with, created_by, assigned_to, closure_date,
commit_ref, parent_atm_id, created_at, last_modified, …`). New nullable columns:

| Column | Type | Rule |
|---|---|---|
| `category` | TEXT | closed set (see research D4); required for every gap item |
| `kind` | TEXT | `defect` \| `unfinished-promise` \| `weak-spot` \| `danger-zone` \| `improvement`; required; V-G4 keys on `kind='improvement'`, not on `type` |
| `disposition` | TEXT | `open` \| `closed` \| `classified`; derived-checked against `status` |
| `classification_reason` | TEXT | required iff `disposition='classified'`: `operator-decision` \| `operator-action` \| `third-party` \| `documented-deviation`. `third-party` means code the project does not own — third-party gitlinks AND upstream governance sources such as `submodules/constitution` — matching FR-021's "third-party or upstream"; the reporting route is recorded in `classification_owner` |
| `plan_due` | TEXT (date) | required for `open` items: the dated plan (FR-006); an elapsed date is a validator finding |
| `research_ref` | TEXT | path of the §11.4.150 deep-research record, required before closure |
| `classification_owner` | TEXT | required iff classified; who can lift it |
| `classification_recheck` | TEXT (date) | required iff classified; an elapsed date is a validator failure |
| `measurable_target` | TEXT | required for improvement items (Feature), FR-025 |
| `recurrence_of` | TEXT | atm_id of the earlier record (FR-008); chain resolves to head, never a cycle |
| `reopens_count` | INTEGER | incremented by each `Reopened` history row |
| `cycle` | TEXT | programme cycle id; immutable after freeze for that cycle (FR-026) |
| `sweep_class` | TEXT | class that found it, or `manual` |
| `first_seen_fingerprint` | TEXT | state fingerprint at discovery |

Severity is constrained to `critical|high|medium|low` by the validator (column stays TEXT).
`type` follows research D3 (defects and danger zones → Bug; unfinished promises that add a
capability → Feature; improvements to existing capabilities and hygiene → Task, so the closure word
stays type-bound per §11.4.33 and §11.4.16's "Feature = new capability" is respected).

### Severity and category rubric (also reproduced in `docs/zero-gap/CLOSURE.md`, T042)
Severity is judged by consequence, not by effort; it orders work and never lowers the closure bar.
- **critical**: exposes private or credential material; a release/PASS gate can report success over a broken
  product; a live service is down or serving wrong data; an integrity check (evidence chain, boundary) is defeated.
- **high**: a user-reachable wrong result; a fix or claim recorded as verified without evidence; a gate that
  can pass vacuously; a destructive command left unguarded.
- **medium**: recorded figures or documents that drifted from measured fact; a missing test kind that hides
  no known defect; a build or start script that can run stale code.
- **low**: cosmetic or wording defects with no effect on results.
Category is the item's ROOT CAUSE class (not its symptom); an item spanning categories belongs to the primary
category, chosen in the order `security`, `data-integrity`, `false-evidence`, `content-boundary`, `availability`,
`build-freshness`, `governance-drift`, `docs-drift`, `test-coverage`, `ux-accessibility`, `host-capability`, `other`.

### StateMachine (validator-enforced)
```
Queued ──► In progress ──► Ready for testing ──► In testing ──► Fixed/Implemented/Completed  (disposition=closed)
   │            │                                     │
   │            └──────── Operator-blocked (operator-decision | operator-action)   ┐ disposition=classified,
   │                      Queued (third-party | documented-deviation)             ┘ needs reason+owner+recheck
   └── Reopened ◄── (any closed item whose recorded check now fails; increments reopens_count)
```
Rules:
- `closed` requires: a `test_diary` row `PASS` with `evidence_path`, a RED-pre-fix evidence record and
  a GREEN-current evidence record for the SAME check id, an independent verdict row (table
  `item_verdicts`) from a DIFFERENT actor than the fixer, a review verdict row, the closure check
  authored by someone other than the fixer (§11.4.240(C)(1)), and a `research_ref` (§11.4.150)
  (FR-007/018/022).
- `classified` items are never counted as closed; SC-003 requires their reason to be one of the four.
  The database stores the exact status value `Queued` (the `Queued — BLOCKED` sub-state cannot be
  stored, and §11.4.148 D3 rewrites any BLOCKED alias to `Operator-blocked`); the qualifier lives in
  `disposition` + `classification_reason`. `Operator-blocked` items MUST carry their unblock
  choices and the cost of each in `operator_block_details` (FR-009).
- `Obsolete` keeps its existing reason list and is not a substitute for classification.
- No `accepted-as-is` state exists (clarification 1).
- A recurrence MUST set `recurrence_of` and reopen the head record if terminal; minting an unrelated
  id is a validator failure (§11.4.214).

### SweepClass (data file `docs/zero-gap/sweep-classes.tsv`)
| Field | Meaning |
|---|---|
| `class_id` | stable id, e.g. `SC-gates-vacuous`, `SC-stale-figures` |
| `population` | what it enumerates (derived, not a hand list) and why that set is right |
| `window` | comparison window if bounded, else `none` |
| `entrypoint` | runnable command producing findings |
| `corpus` | path to planted-defect fixtures + clean control |
| `recall` | last measured value or `UNKNOWN` |
| `population_kind` | `source` \| `process` \| `wire` (FR-014/017) |

### EvidenceRecord — TWO files (T001 finding, 2026-09-25)
The constitution's verifier (`continuum-integrity`) accepts a JSONL chain of records with EXACTLY nine fields —
`seq, ts, command, exit_status, artifact_path, evidence_class, author_session_id, independence_tier, prev_digest` —
refuses unknown fields (rc 4 REFUSE, measured: `unknown field "cwd"`), requires genesis `prev_digest = ""`, walks in
file order and hashes the decoded record (not the file bytes). Our richer record therefore lives in a SIDECAR
JSONL (schema: `contracts/evidence-record.schema.json`): `chain_seq, ts, cwd, argv, exit_status, duration_ms,
stdout_digest, stderr_digest, stdout_bytes, stderr_bytes, stream_ref, stream_truncated, stream_redacted, item_id,
check_id, state_fingerprint_before, state_fingerprint_after, population_kind, outcome, verdict_role,
independence_tier, evidence_class`. The two are bound by `artifact_path = "sha256:<hex of the exact sidecar line
bytes>"` in the chain record. The verifier never reads the sidecar, so OUR adapter re-hashes every sidecar line and
compares (measured: changing `outcome` in a sidecar line still gave `chain verify` rc 0 while the adapter's
re-hash flagged it). Sidecar canonicalisation is a pinned byte rule: the exact stored line bytes. Reuse upstream
`chain.ExecRow.ToRecord` (`pkg/chain/exec_call.go`) for the recorder→chain step rather than writing a second one.
Invariants: `state_fingerprint_before == state_fingerprint_after` else outcome MUST be 2; `outcome` is the check's
own three-valued result, never inferred from a process exit code alone (§11.4.232); streams are redacted before write.

### AnchorRecord (upstream format — stored exactly as `continuum-integrity anchor write` produces it)
`{head_digest, entry_count, anchor_strength}` with `anchor_strength ∈ policy | mechanism | unknown`; `anchor write`
overwrites the record forward-only and refuses a lower count or a rewrite. Our honest claim is `policy`
(append-only by policy; `git remote -v` shows `github`, `origin` and `upstream` all pointing at ONE repository, so
there is no mirror set and no cryptographic enforcement — research D6). Written per cycle freeze and daily.
The git-history verifier checks forward-only PER COMMIT (never "no line rewritten", which would fire on every
legitimate anchor write): `entry_count` never drops between consecutive commits, and every earlier commit's
`head_digest` equals the digest of the chain record at that position in the current chain.

### Adapter invariants T013/T014 MUST test (review of T001, 2026-09-25)
Sidecar line *i* hashes to chain record *i*'s `artifact_path` (by position, never a set lookup); equal line counts;
sidecar `chain_seq` equals the bound record's `seq`; every `artifact_path` unique; duplicated fields agree (`ts`,
`exit_status`, `evidence_class`, `independence_tier`, chain `command == argv[0]`); fixed byte rule — hash excludes
the trailing `\n`, reject `\r`, no blank lines, file ends with a newline, `sha256:` + 64 lowercase hex. Attack
fixtures: flip a sidecar byte; delete a sidecar line; swap two lines; duplicate a line; add an unbound line;
replay a line under a new tail record; truncate BOTH tails (only the anchor catches this). Also keep the raw
recorder row so the constitution's `continuum-unionrule` can be reused.

### CoverageCell (data file `docs/zero-gap/coverage.tsv`)
`subject \t test_kind \t status \t ref` where `status ∈ {check, n/a, gap, could-not-run}` and `ref` is
a registered check id / a reason / a gap item id / the missing tool. The generator FAILS a `check`
cell whose last run executed zero cases (FR-011).

### IndependentVerdict (NEW add-on table `item_verdicts`, the same pattern as `item_provenance`)
`item_verdicts(item_id, role CHECK(role IN ('verifier','reviewer')), actor, actor_kind CHECK(actor_kind
IN ('agent','script')), on_date, outcome CHECK(outcome IN (0,1,2)), evidence_path)`. The constitution's
`item_history` CHECK fixes its `event_type` set (Opened/Updated/Reopened/Fixed/Implemented/Completed/
Obsolete) and its `by` column only allows `AI|User`, so neither can carry a new event or distinguish
two agents; a separate table can. Disagreement with the author's verdict blocks closure (FR-018).

### CycleFreeze (`docs/zero-gap/cycles/<cycle>/freeze.json` + DB `meta`)
`{cycle, frozen_at, register_sha256, sweep_manifest_sha256, chain_head, entry_count, item_count}`.

## Derived views (never typed — FR-024)
Summary counts (`total, closed, classified, open, could-not-inspect`), per-class recall table,
coverage matrix, per-module status page. Generated by `workable-items report` and
`zero-gap-coverage.sh`; hand edits that change a status without evidence are rejected by the
validator and by the pre-push registry gate.

## Volume / scale
Register: hundreds to low thousands of items (DB is 2.4 MB at 530 rows). Evidence chain: one record
per check run; full daily run ≈ tens to low hundreds of records. Streams live outside VCS.
