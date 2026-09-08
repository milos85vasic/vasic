# Phase 1 — Data Model

**Feature**: Authored AI/IT Knowledge Areas · **Date**: 2026-09-07

Entities, their invariants, and the state each can be in. Field names are the
shape, not a serialisation; the wire form is in [`contracts/`](contracts/).

**Two invariants govern everything below**, and both exist because their absence
was the measured defect:

- **I1 — One decision, many consumers.** The publication decision is computed
  once. Any entity's visibility derives from that single computation. Two
  implementations that agree today are the D3 defect waiting to recur.
- **I2 — Absence is a state, not a null.** Every "missing" case is a named,
  reportable state with a reason. A synthesised value standing in for an absent
  one is how 814 mined areas acquired names they never had.

---

## Area

The published unit: a named AI/IT subject.

| Field | Notes |
|---|---|
| `id` | ULID. **The identity.** Minted by extraction; authored content binds to it. Never displayed as a title. |
| `title` | Human-readable. **Non-empty is the publication rule** (R3). |
| `summary` | What the subject covers. |
| `tags` | Derived. **Never `null` — an empty array instead**, because a null breaks the field the interface filters on. |
| `evidence_count` | Passages supporting this area. Reported, never used as a publication filter (R2). |
| `lessons` | Ordered. May be empty only if the area is not published. |
| `assessment` | Zero or one. |
| `corpus_revision` | The revision this area was built from (FR-023a). |

**Invariants**

- `title` non-empty is the title test for publication.
- An area appears in the catalogue **iff** its detail, lessons and assessment are servable (FR-018). Listing and openability are one condition.
- Withheld areas keep their identifier and reason, and disclose a derived name **when one is derivable** (FR-018b). Withholding an area is not a reason to withhold what it is called.
- Thinly-evidenced areas still report `evidence_count` (FR-005b).

**States** — the closed vocabulary, every one reportable by every surface:

| State | Meaning | Detail route | In `areas[]` |
|---|---|---|---|
| `published` | all tests pass | 200 | yes |
| `no_title` | mined proposal, never authored | refusal | no |
| `no_evidence` | no supporting passages | refusal | no |
| `no_publication_review` | authored, unreviewed | refusal + derived name | no |
| `stale_publication_review` | review predates content | refusal + derived name | no |
| `no_materials_record` | editorial: nothing attached | refusal | no |
| **`build_inconsistent`** | review present, materials absent — a **build** fault, not editorial | **503** | no |

`build_inconsistent` is deliberately distinct (FR-018c): the author stage writes
review and materials in one run, so their disagreement is a broken build. It
answers 503 while the catalogue still answers 200 — one bad record must not take
the catalogue down.

---

## Lesson

| Field | Notes |
|---|---|
| `id`, `ord` | `ord` drives one server-side sort. One order, used by list and by prev/next. |
| `title`, `body` | |
| `estimated_minutes` | Per lesson; summed to an area total. |
| `materials[]` | Zero or more. |
| `anchors[]` | Zero or more video anchors. |
| `required` | Whether it counts toward assessment availability. |

**Invariants**

- Order is total and stable. Prev/next are computed **from the same sorted slice the list uses** — a second ordering is a second thing to disagree.
- The required set MUST be able to be a **proper subset** of the lessons; a model where they coincide cannot express the gate correctly and hides the "any lesson opens it" defect (R6).

---

## Material

| Field | Notes |
|---|---|
| `kind` | Closed vocabulary: illustration, diagram, scheme, graph, video. An unknown kind is a **400**, never an empty list. |
| `caption` | What it shows. |
| `alt` | Text alternative conveying **content**, not a file name. |
| `ref` | Where the asset is. |

**Invariant**: a material whose asset is missing renders as *unavailable*, never as a broken element.

---

## VideoAnchor

| Field | Notes |
|---|---|
| `chapter_id` | Which recording. |
| `start_millis` | **Measured** from the segment sidecar. Not derivable from the passage registry, which carries only an end time. |
| `end_millis` | Optional. |
| `transcript_anchor` | The passage id to scroll to and mark. |

**Invariants**

- Every anchor in a published lesson resolves to an existing recording **and** an existing passage (FR-016); an unresolvable anchor blocks publication of that lesson rather than reaching a learner.
- `end` is emitted **only when `> t`**. A malformed span is ignored by the consumer, so emitting one produces a broken link that renders correctly.
- The `#p-` fragment is emitted **only for a Crockford-shaped ULID**.
- An unservable chapter yields `href: null` + `unresolved_reason` + intact anchor + a count. **No link is invented.**

---

## Assessment

| Field | Notes |
|---|---|
| `questions[]` | The bank. |
| `pass_percent` | Declared per area; **shown before the attempt** (FR-008b). |
| `required_lessons[]` | The availability condition. |

**Invariants**

- Availability is decided **where content is served**, not where it is displayed (FR-012a).
- While unavailable, the response carries **zero** prompts, options and answers (FR-010, SC-009).
- An area may have lessons and **no** assessment. That is an honest state; a fabricated question bank is worse than a missing one.

---

## Question

| Field | On the taking path | In the result |
|---|---|---|
| `id`, `prompt`, `options[]` | yes | yes |
| `correct_choices[]` | **absent by construction** | yes |
| `explanation` | **absent by construction** | yes |

**Invariant**: the taking projection is built as a map with **no answer field at
all** — not as the domain type with fields omitted. Omission depends on every
future field remembering to omit itself; absence does not.

Answers are identified **by ID, never by index** (FR-012), so presentation order
cannot change what an answer means.

---

## Attempt

| Field | Notes |
|---|---|
| `session` | Opaque, header-supplied, one channel only (R7). |
| `answers` | By question id and choice id. |
| `score`, `passed` | |
| `outcomes[]` | Per question: correct?, correct answer, explanation. |

**Invariants**

- A submitted result is **stable** — re-reading returns the same result (FR-011).
- Progress is mutated under a single lock in one operation; a read-then-write cycle silently drops a concurrent completion (R7).

---

## Catalogue

| Field | Notes |
|---|---|
| `areas[]` | Exactly the set whose detail answers 200. |
| `held_back[]` | id + reason for every withheld area. |
| `reason_table` | The closed vocabulary, in the same response. |
| `total_areas` | The population, so a filtered list never hides the denominator. |
| `corpus_revision` | What this was built from (FR-023a). |

**Invariant (I1, asserted end to end)**: `areas[]` is exactly the set whose
`href` answers 200. This is a property a gate can check, and does.

**Nothing becomes unreachable by being held back**: `?include=held_back`
returns full objects for those rows.
