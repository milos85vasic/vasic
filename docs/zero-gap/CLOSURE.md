# Zero-gap closure procedure

| Field | Value |
|---|---|
| Feature | 010 zero-gap verified closure (task T042) |
| Audience | any agent or person closing, classifying or reviewing a register item |
| Kind | hand-written RULES only; every status and count is generated (see "Where numbers come from") |
| Spec sources | `specs/010-zero-gap-verified-closure/{spec.md,data-model.md,research.md,tasks.md}` |
| Revision | 4 - 2026-10-08 (V-G3(c) review fixes: malformed or future-dated verdict rows are excluded from the ordering and are findings; superseded history is not re-validated) |

## Contents

1. [Where numbers come from](#where-numbers-come-from)
2. [The closure bar](#the-closure-bar)
3. [RED first](#red-first)
4. [Evidence capture](#evidence-capture)
5. [Independent verdict](#independent-verdict)
6. [Review](#review)
7. [research_ref](#research_ref)
8. [Classification: the four reasons](#classification-the-four-reasons)
9. [Severity and category rubric](#severity-and-category-rubric)
10. [The per-item loop](#the-per-item-loop)
11. [Batch limits](#batch-limits)
12. [Stop and queue](#stop-and-queue)
13. [Bans](#bans)
14. [Recurrence](#recurrence)
15. [Closing an item: command sequence](#closing-an-item-command-sequence)

## Where numbers come from

This document states rules and carries no status, count or percentage. Derive them:

```bash
workable-items-vsc gap summary --json      # register totals and per-category selection
bash scripts/zero-gap-sweep.sh             # findings, COULD-NOT-INSPECT, per-class recall
bash scripts/zero-gap-coverage.sh --json   # module x test-kind matrix
bash scripts/zero-gap-verify.sh --item <id>   # RED/GREEN re-run for one item
```

A figure typed into this file is a defect (FR-024); the claim ledger and the validator reject hand-edited
statuses.

## The closure bar

An item is closed only when ALL hold; any missing precondition keeps it open:

- a recorded check that FAILS on the pre-fix state (RED) and PASSES on the current state (GREEN), both
  captured by machine (FR-007);
- a `PASS` diary row with an evidence path;
- an independent verdict row from an actor who is not the fixer (FR-018);
- a review verdict row (FR-022);
- the closure check authored by someone other than the fixer (section 11.4.240(C)(1));
- a `research_ref` (section 11.4.150).

Severity never lowers this bar. It only orders work.

## RED first

1. Write or select the check BEFORE the fix.
2. Run it against the broken artifact (a scratch worktree at the pre-fix ref, never a hand-edited copy)
   and capture the failure. A check that passes on the broken state is hollow and refuses closure.
3. Only then change the code. "It was probably flaky" and guess-and-retry are not findings.
4. Re-run the same check on the current ref and capture GREEN. The check id must be the same in both
   records.

## Evidence capture

- Every run is recorded by machine: argv, cwd, exit status, stream digests, state fingerprint before and
  after, and the check's own three-valued outcome (0 pass, 1 finding, 2 could not determine).
- If the fingerprint before differs from the fingerprint after, the outcome is 2, not a pass.
- Outcome comes from the check's contract, never from a process exit code alone.
- Streams are redacted before being written. Never place a credential, token or private text in a record,
  a diary row or this document.
- Cited evidence files are digested at verdict and close time; a later swap is a validator finding.
- Records live in the evidence store described in `specs/010-zero-gap-verified-closure/contracts/`.
  Do not hand-write a record.

## Independent verdict

- The verifier re-runs the recorded check through `scripts/zero-gap-verify.sh --item <id>` on the pre-fix
  ref and the current ref, and writes an `item_verdicts` row with role `verifier`.
- The verifier actor MUST differ from the fixer and from the check author. Disagreement with the author's
  result blocks closure.
- A verdict of 2 (could not determine) is not a pass.

## Review

- A different agent from the fixer reviews the change and writes an `item_verdicts` row with role
  `reviewer`. The review follows the section 11.4.142 and 11.4.209 requirements.
- Self-review precedes review and never substitutes for it.
- A review that finds a defect sends the item back to the loop; the item is not closed "pending fixes".

## research_ref

Record the path of the section 11.4.150 research note (sources consulted, alternatives rejected, why the
fix is the right one) before closure. The path must exist in the tree. Do not copy private material into
it; reference private paths by name only.

## Classification: the four reasons

An item may be `classified` (not closed, not counted as fixed) only when it cannot be fixed from here, and
only for one of these reasons:

| Reason | Meaning |
|---|---|
| `operator-decision` | a choice only the operator can make; record the options and the cost of each (FR-009) |
| `operator-action` | an action only the operator can perform (install, provider setting, gitlink bump, push, deploy) |
| `third-party` | code the project does not own: third-party gitlinks and upstream governance sources; record the reporting route in `classification_owner` |
| `documented-deviation` | a deliberate, documented departure with a written justification |

Every classified item also carries `classification_owner` and `classification_recheck`; an elapsed recheck
date is a validator failure. Severity, effort and "low value" are NEVER reasons. `accepted-as-is` does not
exist as a state. `Obsolete` is not a substitute for classification.

## Severity and category rubric

Severity is judged by consequence, not effort.

- **critical**: exposes private or credential material; a release or PASS gate can report success over a
  broken product; a live service is down or serving wrong data; an integrity check (evidence chain,
  boundary) is defeated.
- **high**: a user-reachable wrong result; a fix or claim recorded as verified without evidence; a gate
  that can pass vacuously; a destructive command left unguarded.
- **medium**: recorded figures or documents that drifted from measured fact; a missing test kind that
  hides no known defect; a build or start script that can run stale code.
- **low**: cosmetic or wording defects with no effect on results.

Category is the ROOT CAUSE class, not the symptom. An item spanning categories belongs to the primary one,
chosen in this order: `security`, `data-integrity`, `false-evidence`, `content-boundary`, `availability`,
`build-freshness`, `governance-drift`, `docs-drift`, `test-coverage`, `ux-accessibility`,
`host-capability`, `other`.

## The per-item loop

No shortcuts, in this order:

1. Read this document.
2. Capture RED (pre-fix ref).
3. Fix (the minimal change; no unrelated edits).
4. Run `scripts/zero-gap-verify.sh --item <id> --verdict-role author --session <fixer handle>` as the fixer (see the closing sequence below).
5. Obtain the `item_verdicts` verifier row from a DIFFERENT agent.
6. Obtain independent review.
7. `workable-items-vsc gap close` with the RED, GREEN and verdict references. rc 0 only when every
   precondition holds.

## Batch limits

- Selection is by query: the wave's category and cycle, captured at start; the list does not grow mid-wave.
- At most 5 items per subagent dispatch.
- One heavy job at a time, with a memory cap (`MemoryMax=16G`).
- One committer per repository; stage explicit paths only.
- An item that spans categories is handled by its primary category's wave.

## Stop and queue

Anything operator-owned is not done; it is queued as `Operator-blocked` with the exact command and the
cost of each option: gitlink bumps, package installs, site pushes, provider settings, edits to
`.claude/settings.json`, deploys. Then continue with the next item.

## Bans

- Never touch the live workshop binary (`workshop/platform/bin`).
- Never copy private text into this public repository (names, quotes, transcripts); path references only.
- Never edit a third-party gitlink.
- Never stage with `git add -A` or `git add .`.
- Never force-push, never rewrite history, never bypass hooks.
- Never close on metadata, config presence or absence-of-error alone.
- Never remove or weaken a check, registry row or guard to turn a result green; never add an allow-list
  or exemption entry without a paired proof.
- Never write a credential into any record, diary row or document.
- Never remove an item from the register.

## Recurrence

A defect that returns links to the earlier record through `recurrence_of`, reopens the head record if it is
terminal, and increments `reopens_count`. Minting an unrelated id is a validator failure (section 11.4.214).

## Closing an item: command sequence

Rules only; run each step as the actor named. `ID` is the item, `F` the fixer handle, `A` the check
author handle, `V` the verifier handle, `R` the reviewer handle. F, A, V and R are four different
handles. Paths are repository-relative; every cited record must be a regular file inside the repository.

1. **Check author (A), before the fix.** Write `docs/zero-gap/checks/ID.check` (check_id, pre_fix_ref,
   cmd). A is not F. The same `check_id` must appear in every record below.
2. **Fixer (F) fixes**, then runs the check as the AUTHOR, under F's own session handle:
   `bash scripts/zero-gap-verify.sh --item ID --verdict-role author --session F`.
   This seals a RED (pre-fix) and a GREEN (current) record labelled `author`. The label is a claim the
   script cannot check, so `--session` MUST be the same handle that is later passed as `--fixer`. Never
   pass `--verdict-role author` as anyone but the fixer. Omitting the option records `verifier`, which the
   validator refuses as a GREEN (V-G3: the GREEN is the author's run).
3. **Extract the two records** (the second-to-last and last sidecar lines of that run) to one JSON file
   each, for example `ev/ID.red.json` and `ev/ID.green.json`. The RED has outcome 1, the GREEN outcome 0.
4. **Verifier (V), a different session, later:** `bash scripts/zero-gap-verify.sh --item ID --session V`
   (role `verifier` is the default). Extract its current-state record to `ev/ID.verifier.json`. It must be
   a separate run, later than the GREEN, with a different chain position and different bytes.
5. **Verdict rows.** `workable-items-vsc gap verdict --id ID --role verifier --actor V --actor-kind agent
   --outcome 0 --evidence ev/ID.verifier.json`, then, by R after reading the change,
   `gap verdict --id ID --role reviewer --actor R --actor-kind agent --outcome 0 --evidence <review note>`.
   The reviewer note is a non-empty file written by R; the review is dated on or after the GREEN day.
6. **Diary row (anyone but the closing command): `workable-items diary add --id ID --db <db> --tested-by
   AI-agent --result PASS --observations <text> --evidence ev/ID.green.json`**, run from the repository
   root, dated no earlier than the GREEN record. `gap close` never writes this row.
7. **research_ref** present on the item (or passed as `--research-ref`).
8. **Close:** `workable-items-vsc gap close --id ID --red-evidence ev/ID.red.json --green-evidence
   ev/ID.green.json --verdict-ref ev/ID.verifier.json --fixer F --check-author A --research-ref <path>`.
   rc 0 only if V-G1 to V-G12 hold on the resulting register; any miss is rc 1 with nothing written.

**Legacy items and re-verification (V-G3(c)).** Per item and per role (`verifier`, `reviewer`) only the
NEWEST verdict row (by `on_date`, then insertion order) is evaluated. Older rows stay in `item_verdicts`
as history and neither satisfy nor block closure. So an item whose old verifier row predates any author
GREEN is closed by: the fixer's fresh author GREEN (step 2), a NEW verifier run strictly later than that
GREEN (step 4), a NEW `gap verdict` row for it (step 5), a new reviewer row, and `--verdict-ref` naming
that newest verifier record. The converse holds: a newer verifier or reviewer row with outcome 1 or 2
supersedes any older approval, and a newest row that fails any check (not later than the GREEN, the
fixer's own handle, a non-regular reviewer file) is refused and cannot be rescued by an older row.
A verdict row whose `on_date` is not an ISO date, or is after `--as-of`, is excluded from the ordering
and is itself a finding, so it can neither win nor hide a genuine later row. Superseded history rows are
not re-validated; tamper-evidence of history is the evidence chain's job (T068).
This change needs independent review by a different actor before it is relied on.

Refused, each by its own message: GREEN labelled `verifier`; no diary PASS row citing the GREEN; check
author equal to the fixer; verifier or reviewer equal to the fixer; no verifier or reviewer row; no
`research_ref`; `--verdict-ref` not naming a valid verifier row; RED or GREEN reused from before a reopen.

Honest limits. The register stores handles as text: it does not prove that the session behind the author
GREEN belonged to the fixer, nor that a handle names a distinct person or model. Anything sealed with the
wrong role stays sealed; it is never relabelled, and a new run under the true role is the only remedy. A
close built from records that were produced by an actor other than the one named is a false record, not a
closure.

## Coverage matrix: statuses, designed-red and cycle-2 intake

`bash scripts/zero-gap-coverage.sh` regenerates `docs/zero-gap/coverage.tsv` from `docs/zero-gap/coverage-measured.tsv`
(written only by `scripts/zero-gap-coverage-measure.py`, real runs) and the evidence files in `docs/zero-gap/coverage-evidence/`.

- A cell is `check` only when the kind ran **cases>0 AND failed==0 AND rc==0** and its evidence header binds to the row
  (`subject kind cases failed rc` plus `head= tree= ts= limit=`). A kind that ran but is red is `check-red`: applied, not
  proven, not coverage.
- **Binding is compared, not format-checked (round 2, F1).** `coverage-measured.tsv` carries the `head` (`git rev-parse HEAD`)
  and `tree` (sha256 of head + `git status --porcelain`) the measurer recorded. The generator rejects an all-zero or malformed
  head/tree, requires the evidence header's head and tree to EQUAL the TSV row's, requires the head to be a commit in this
  repository's object store that is HEAD or an ancestor of HEAD, and otherwise emits `gap:evidence-mismatch: <fields>`
  (`head`, `head-differs-from-tsv`, `head-not-in-object-store`, `head-not-ancestor-of-HEAD`, `tree`, `tree-differs-from-tsv`, ...).
  Allowance: by default ANY ancestor is accepted and the generator prints, per measured head, how many commits behind HEAD the
  cells were measured (`evidence-freshness` lines); `--max-behind N` (or `ZERO_GAP_COVERAGE_MAX_BEHIND=N`) makes a head more than
  N commits behind `gap:evidence-stale`. Honest limit: `tree` covers a dirty working tree that cannot be reproduced afterwards,
  so it is bound for presence, non-zero and header/TSV agreement only; rewriting both files consistently with a different REAL
  ancestor head is indistinguishable from a measurement taken there (unsigned evidence).
- **Environment build failures are not test failures (round 2, F2).** The measurer analyses `go test -json` per package. A build
  failure whose cause is the measurer's environment (`goproxy-off`: GOPROXY=off and the module is not in the offline cache;
  `missing-replace-dir`: a `replace` directive points at a sibling checkout that is absent; `missing-module`) makes the cell
  `could-not-run:go-build:<cause>` with the unbuilt packages and the passing cases of the packages that did run recorded. The
  cell stays `check-red` whenever a real failure also exists (failed>0, a package-level failure such as a panic or TestMain exit,
  a compile error that is not an environment cause) or rc != 0 is unexplained; the evidence then lists both the failing tests and
  the unbuilt packages. Genuinely red cells are never relabelled.
- **Failing names (round 2, F3).** Every evidence file of a red cell lists every failing test (`package :: Test`) or, for a root
  gate, the failing case lines of its output (best effort; rc is authoritative), capped at 500 names with the omitted count stated.
- **Limits are explicit (round 2, F4).** `--timeout` (default 240 s) bounds every go test / gate run; `--gate-timeout` (default
  600 s) bounds the fleet-wide scanning gate `content-boundary` and replaces the former hidden `max(timeout,600)`. The limit used is
  written as `limit=` in the evidence header and quoted in the cycle-2 reason of a `could-not-run:timeout` cell.
- `designed-red` exists only for a gate declared in `docs/zero-gap/designed-red.tsv` (subject, kind, expected_rc, reason,
  ref) whose measured rc equals the declared one. `sweep-classes.tsv` cannot express this (it lists sweep classes with a
  fixed eight-field schema, not gates), hence the separate data file. Never declare a genuinely failing suite there.
- `docs/zero-gap/cycle-2-candidates.tsv` is **generated by the same command** (never hand-typed) and lists every `gap*`,
  `check-red` and `could-not-run` cell. These are **cycle-2 intake**: the register is frozen at cycle 1 (T038), so the
  file adds no register row and reopens no frozen item; the generator is the source.
- Counting note (round 2, F5): `submodules/LLMProvider` (vasic-digital remote) and `submodules/llm_provider` (HelixDevelopment
  remote) are two gitlinks pinned to the same commit (`e05ec64ebc48`), so their cells are one codebase counted twice. They are
  declared in `docs/zero-gap/duplicate-subjects.tsv` (duplicate, of, reason): both rows stay in `coverage.tsv`, and the generator's
  `coverage totals:` line prints the RAW count and the DE-DUPLICATED count per status. A declaration is honoured only while both
  checked-out HEADs are the identical commit and is refused loudly (stderr) otherwise, so it cannot hide a subject whose code differs.
  Root gates that are red by design (e.g. `content-boundary`, exit 1) are labelled `designed-red` only through
  `designed-red.tsv`; their own `--prove-failure` runs are not counted as coverage of anything else.
