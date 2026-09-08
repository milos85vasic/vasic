# Phase 1 — Data Model

**Feature**: Session record + QA readiness · **Date**: 2026-09-08

Entities, invariants, and states. The wire form is in [`contracts/`](contracts/).

**Four invariants govern everything, and each exists because its absence was a
measured defect:**

- **I1 — One derivation, many consumers.** A fact is computed once. Two
  implementations that agree today produced this platform's 819-listed-vs-817-
  openable catalogue bug.
- **I2 — Absence is a state, not a null.** Every missing case is named and
  reported with a reason. A synthesised value standing in for an absent one is
  how 814 mined areas acquired names they never had.
- **I3 — A snapshot licenses only itself.** A cached copy may assert what it
  holds, never a determined negative about the source it can no longer see.
- **I4 — A proposal is not a decision.** A machine-drafted verdict may not move a
  published figure.

---

## SessionRecord

One chapter's record, cumulative over that session and every prior one.

| Field | Notes |
|---|---|
| `chapter` | The chapter this record belongs to. |
| `prior_chapters` | The chapters folded in. Cumulativeness is data, not an assumption. |
| `sections` | The four, keyed by name. |
| `section_order` | `meeting_notes`, `open_questions`, `todo`, `next_meeting` — one order, so no surface invents its own. |
| `plan` | What this session intended to cover. |
| `carry_forward` | Points moving to the successor, or the outbox. |
| `privacy` | The boundary statement carried with the record itself. |

**Invariants**

- All four sections present (FR-001). Cumulative over prior sessions (FR-002).
- **Both the embedded chapter key and the standalone routes read the same
  derivation** (I1). A gate asserts they agree; agreeing today is what drifts.

---

## Section

| Field | Notes |
|---|---|
| `own_state` | `authored` or `empty`. |
| `own_count` | Items originating in **this** session. |
| `carried_count` | Items arriving from earlier sessions. |
| `items[]` | Both, together. |
| `reason` | Required when `own_state` is `empty`. |

**Invariant (FR-004, I2)**: a section with nothing to report **says so with its
reason**. **An empty section and an unwritten section must never be
indistinguishable** — this is the single property that lets a QA team tell a
defect from a blank.

**The `own_count`/`carried_count` split is load-bearing.** Two sections currently
carry `own_count=0` with an authored reason. Without the split they would read as
productive sessions.

---

## RecordItem

| Field | Notes |
|---|---|
| `id`, `text` | |
| `origin_chapter` | Which session raised it (FR-003). |
| `slip_count` | How many times it has been carried (FR-010). |
| `marker` | `CARRIED-FORWARD` when carried (FR-009). |
| `marker_label` | e.g. `CARRIED-FORWARD x2` — the count is visible, not merely stored. |
| `resolution` | Open questions only: `answered_in_chapter` / `answered_by_research` / `unanswered`. The client already types this; the wire must not narrow it. |

---

## SessionPlan

| Field | Notes |
|---|---|
| `basis` | `predecessor_next_points` or `undetermined`. |
| `coverage_state` | `undecided` until a human confirms (I4). |
| `coverage_source`, `coverage_reason` | Where a verdict came from, or why none exists. |
| `planned_count`, `covered_count`, `carried_count`, `dropped_count` | |

**Invariants**

- Every planned point resolves to **covered / carried / dropped-with-reason**
  (FR-007). **`vanished` is 0 by construction** — `Resolve` has no fourth branch.
- **A drop without a reason is refused and carries instead**, so "dropped" cannot
  become a quiet disposal route.
- **`basis: undetermined` computes no coverage percentage.** Chapter 01 has no
  predecessor and no recorded intent; a percentage over an invented plan would be
  a fiction with a denominator.

---

## CoverageProposal *(new)*

| Field | Notes |
|---|---|
| `point_id` | |
| `verdict` | `covered` / `not_covered` / **`cannot_determine`** — a first-class answer. |
| `evidence[]` | Passage and section ids the verdict rests on. |
| `confidence` | The proposer's own. |
| `status` | Always `PROPOSED` until a human confirms. |

**Invariant (I4, FR-007a)**: a proposal **MUST NOT** move `coverage_state` or any
served count. A check asserts the served state is still `undecided` after a
proposal exists — that assertion is what makes the rule mechanical rather than
aspirational.

---

## CarryForward

| Field | Notes |
|---|---|
| `to_chapter` | Successor, or null when this is the outbox. |
| `is_outbox` | True for the latest chapter, which has no successor (FR-011). |
| `reason` | Why these points are here. |
| `max_slip_count` | The worst slip in the set — a point slipping repeatedly is surfaced, not buried. |
| `points[]` | |

---

## Lesson

| Field | Notes |
|---|---|
| `id`, `ord`, `title` | `ord` drives one server-side sort; prev/next use the same slice. |
| **`body`** | The teaching content. Declared **upstream in the kit**, optional there by deliberate choice — a materials-only lesson is legitimate, so "every lesson has a body" is a *consumer* policy. |
| `summary` | A one-line blurb. **Kept distinct from `body`**; collapsing them was the semantic lie that caused 339 bodies to be discarded. |
| `estimated_minutes`, `materials[]`, `required_for_assessment` | |

**Invariant (FR-013)**: every served lesson of a published area carries non-empty
content. Asserted by a gate with **two arms** — in-process and live — because
in-process alone is a source measurement.

---

## Assessment · Question · Attempt

Unchanged from spec 004 except three properties this feature added:

- **The taking projection has no answer field at all** — built as a map, not as
  the domain type with fields omitted. Omission depends on every future field
  remembering to omit itself; absence does not.
- **Graded rows are withheld from the open practice route**, and the withholding
  **says so**. The two decks are the same authored rows: 224 of 224 match by
  prompt, 0 of 224 by id.
- **A malformed submission is refused**, naming the offending key, before the
  store is touched. `responses: []` still grades — a blank paper is a real
  submission.

**Fail-closed (I3)**: a nil, unreadable **or stale** catalog withholds every
answer key rather than risking one.

---

## Catalog snapshot

| State | Meaning |
|---|---|
| `Fresh` | Source unchanged since load. |
| `Stale` | Source changed — determined negatives are refused; 503 names the changed files. |
| `StalenessUnknown` | Cannot tell. Never a pass. |
| `NoSource` | No directory to have drifted from. **Negatives still stand** — an in-memory test catalog is legitimately authoritative about itself. |

**`NoSource` is a separate state on purpose.** Folding it into `Fresh` would
license false negatives; folding it into `Unknown` would break every in-memory
test.

---

## QAScenario · EvidenceArtefact

| QAScenario | |
|---|---|
| `action` | What the tester does. |
| `expected` | Stated **before** the action (FR-018). |
| `report_procedure` | How to report a discrepancy and what to capture. |

| EvidenceArtefact | |
|---|---|
| `claim` | |
| `population` | **`source` / `in_process` / `served`** — required (FR-026). The same figure over different populations is a different fact. |
| `build_id` | What state it was produced from. |
| `corpus_fingerprint` | Proof the corpus did not move mid-measurement (FR-027). |
| `verdict` | satisfied / finding / **could-not-determine** — never recorded as satisfied (FR-024). |
