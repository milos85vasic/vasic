# Contract — The session record

Four sections per chapter, cumulative, with derived carry-forward.

## Two surfaces, ONE derivation

| Surface | Shape |
|---|---|
| `GET /api/chapters/{id}` | a `session_record` key carrying everything |
| `GET /api/chapters/{id}/{open-questions,todo,next-meeting,meeting-notes}` | one section each, for deep-linking |

**Both read `pkg/sessionrecord`. Neither re-derives.** A gate asserts they serve
the same items — **a route and a key that agree today are exactly what drift**,
and this platform has the 819-vs-817 catalogue bug to prove it. All FOUR
standalone routes exist as of 2026-09-08 (see below) — the table above WITHDRAWS
the earlier three-route listing, which omitted `meeting-notes` while it was
still blocked.

## `meeting-notes` — WAS deliberately not built; NOW served, on a recorded judgement

**Corrected 2026-09-15. The section below is WITHDRAWN AS STALE, not deleted,
because it is why the route did not exist for four days (2026-09-04 to
2026-09-08) and that history is worth keeping legible:**

> ~~Its withholding rule **may not be guessed**: one note is a content judgement
> left undecided for the operator. **A route built on a guessed withholding rule
> publishes a judgement nobody made** (FR-005a). Its DEBT row names that
> specific blocker rather than the general one.~~

**The judgement WAS taken, 2026-09-08, and `GET /api/chapters/{id}/meeting-notes`
is SERVED.** Re-verified live 2026-09-15:
`bash workshop/platform/gates/verify-session-record.sh` exits 0, and its check
**A7** asserts specifically that this fourth route is served under the same
envelope as its siblings, that its FR-005a judgement is recorded, and that no
sibling still advertises it as unbuilt.

One `kg_meeting_note` row (chapter 01) carried a 3-word / 14-character run that
`internal/redaction/registryderived_phrase.go` found occurring only in withheld
passages — the FR-005a blocker. The operator read the span itself and judged it
carries nothing private: ordinary English phrasing, merely rare in a
one-chapter corpus. That is option (a) of the three
`workshop/platform/gates/route-manifest.tsv` names in full (serve in full /
serve redacted / withhold the row) — not (b) or (c). **The detecting rule
itself was not narrowed** to reach that outcome; it is what found this row and
four independent true positives on the same corpus.

The decision is recorded, not merely asserted in a commit message: one
append-only line in `curriculum/disclosure-judgements.jsonl` (six-field shape
matching `curriculum/redactions.jsonl`) under reason code
`withheld_only_run_judged_non_private` (`internal/redaction/judgements.go`),
carrying the row's identifier, deciding author, date, AND its `content_hash` at
decision time — so a later edit to that note is **not** pre-cleared: the row
returns to the finding list and the report says why.
`workshop/platform/gates/prove-session-record.sh`'s `M-JUDGEMENT` arm asserts
exactly this — a disclosure judgement "cannot hide, outlive or float free" (9
refusal mutations + a control + a staleness arm + a revocation arm, all caught
— re-run 2026-09-15, `internal/redaction/judgements_test.go`'s `TestGateJ1`
through `TestGateJ5` all PASS).

**This is a judgement about ONE row, not a blanket lift.** FR-279
(`006/FR-030b`) still governs every OTHER, unjudged row across every session-
record kind (`kg_todo`, `kg_next_point`, `kg_open_question`, `kg_meeting_note`
alike): `internal/api.WithSessionRecordRule` derives disclosability PER ROW from
whether that row's own cited transcript segment resolves and is itself
disclosable, and withholds by default when it does not — never a guess, never a
blanket serve. That is asserted independently of the one row's manual judgement
above by `workshop/platform/gates/check-registry-002.tsv`'s `D16-session-
record-*` rows (`internal/api/publication_session_test.go`) — re-run
2026-09-15, `TestSessionRule_WithholdsOnEveryFailingClause`,
`TestSessionRule_ServesARowWhoseCitationIsDisclosable`,
`TestSessionRule_FailsClosedWithoutARegistry`,
`TestSessionRule_LeavesEveryOtherKindAlone` and
`TestSessionRule_pkgSearchReadsTheSameDecision` all PASS.

**The correct Open Question citing this is unified OQ-8**
(`specs/008-unified-workshop-platform/spec.md`, was `006/OQ-1`) —
*"Which specific content in the meeting-notes section must be withheld from the
public record?"* — verified 2026-09-15 to match this section's subject. Its own
table entry records: *"Interim state, resolved: the route and any dependent
content default to withheld (FR-279) — nothing publishes on a guess."* That
default is exactly what `WithSessionRecordRule` implements for every row that
has not been individually judged; the one row above is the sole recorded
exception, and it is an exception **by judgement**, never a departure from the
default. **Do not cite bare "OQ-1" for this** — unified OQ-1 is a different
question (third-party consent for the Chapter 1 recording).

## Section shape

```
own_state    authored | empty
own_count    items originating in THIS session
carried_count items arriving from earlier sessions
items[]      both
reason       REQUIRED when own_state is empty
```

**An empty section and an unwritten section are never indistinguishable**
(FR-004). Two sections currently carry `own_count=0` with an authored reason;
without the split they would read as productive sessions.

## Item shape

`origin_chapter` (FR-003) · `slip_count` (FR-010) · `marker: CARRIED-FORWARD`
(FR-009) · `marker_label` e.g. `CARRIED-FORWARD x2`.

Open questions keep the three-valued `resolution` the client already types:
`answered_in_chapter` / `answered_by_research` / `unanswered`. **The wire must not
narrow it** — the consumer already knows what it needs.

## Plan and carry-forward

`plan(N) = unresolved(plan(N−1)) with slip+1  +  next-meeting points of N−1`

- Every planned point resolves to **covered / carried / dropped-with-reason**.
- **`vanished` is 0 by construction** — `Resolve` has no fourth branch.
- **A drop without a reason is refused and carries instead.**
- `basis: undetermined` ⇒ **no coverage percentage is computed.** Chapter 01 has
  no predecessor; a percentage over an invented plan is a fiction with a
  denominator.
- The latest chapter's carry-forward is an **outbox** (`is_outbox: true`) with a
  stated reason (FR-011).

## Coverage is proposed, never asserted

`coverage_state` stays **`undecided`** until a human confirms. A proposal carries
per-point evidence, confidence and `status: PROPOSED`. **A draft must not move a
published figure** (FR-007a, I4) — and a check asserts the served state is still
`undecided` after a proposal exists.

## Measured

39 chapters' worth of items across 3 chapters: 12 of 12 sections present, **0
empty-without-reason**, 436 items, 210 carried, `max_slip=2`, one outbox of 42.
Plan: 66 planned · 0 covered · 66 carried · 0 dropped · **0 vanished**.

## Asserted by

`verify-session-record.sh` rc 0 · `prove-session-record.sh` **23 passed / 0
failed, 23 mutations** (re-run 2026-09-15; the earlier "14 passed" figure is
WITHDRAWN as stale, not restated — the battery grew with the route-vs-key and
disclosure-judgement arms below), including a control that goes green, a
vacuity refusal exiting 2, a duplicate planned point caught as rc 1, a
reasonless drop refused, the served-surface floor (M10–M13c, including M13b:
the check fails when `meeting-notes` is declared `NOT_BUILT` again), the
route-vs-embedded-key pair assertion (M-ROUTE-BATTERY: 10 payload mutations +
control + vacuity), and the disclosure-judgement battery (M-JUDGEMENT: 9
refusals + control + staleness + revocation, all caught).
