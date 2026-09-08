# Contract — The session record

Four sections per chapter, cumulative, with derived carry-forward.

## Two surfaces, ONE derivation

| Surface | Shape |
|---|---|
| `GET /api/chapters/{id}` | a `session_record` key carrying everything |
| `GET /api/chapters/{id}/{open-questions,todo,next-meeting}` | one section each, for deep-linking |

**Both read `pkg/sessionrecord`. Neither re-derives.** A gate asserts they serve
the same items — **a route and a key that agree today are exactly what drift**,
and this platform has the 819-vs-817 catalogue bug to prove it.

## `meeting-notes` is deliberately NOT built

Its withholding rule **may not be guessed**: one note is a content judgement left
undecided for the operator. **A route built on a guessed withholding rule
publishes a judgement nobody made** (FR-005a). Its DEBT row names that specific
blocker rather than the general one.

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

`verify-session-record.sh` rc 0 · `prove-session-record.sh` 14 passed, including
a control that goes green, a vacuity refusal exiting 2, a duplicate planned point
caught as rc 1, and a reasonless drop refused.
