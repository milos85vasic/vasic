# Data Model — Knowledge Areas & Bidirectional Deep Linking

**Feature**: `specs/002-knowledge-areas-deep-linking` | **Date**: 2026-09-01
**Normative dependency**: the knowledge-model contract in the workshop's documentation is the
authority on the ported hierarchy. This document defines the entities this feature adds and how they
attach to what already exists; where the two describe the same thing, the contract wins (FR-005).

## 0. What already exists and is not redefined here

Restated only to fix the boundary — none of this is changed by this feature.

- **Passage** — the smallest addressable unit of source content. 1,101 of them. Carries a minted
  26-character identifier, a kind, a chapter scope, an ordering key that is also its start time for
  transcript segments, a source reference with path and line range, its text, its immutable machine
  text, a provenance marking, a confidence value, an uncertainty flag and reason, a redaction flag, a
  change-detection hash that is explicitly **not** identity, a mint time and an ingest run.
- **Chapter** and **Section** — chapters are identified by a zero-padded slug; sections are
  **derived**, never authored, and carry their own derivation rule and cross-check.
- **Cross-reference** — an existing passage-to-passage relation with a relation type, an origin, a
  score and a depth.
- **Word timing sidecar** — per chapter, 15,610 records for the chapter that exists, each a word, a
  start, an end and a probability. Derived; not part of the registry.

## 1. Identity — one rule, five new kinds

Every entity below mints its identifier through **the same minter** the passage registry uses
(D-KG-2). The rule is stated once and applies to all of them:

> An identifier is minted once, at creation, and persisted. It is never derived from the entity's
> text, its title, its slug, its ordinal, its position in a file, or a hash of any of these. It never
> changes. Two entities never share one.

**What this forbids, concretely**, because these are the forms that look reasonable:

- an area identified by its slug — breaks when the area is renamed, which is a normal editorial act;
- a term identified by its canonical form — breaks when the canonical form is corrected, which is
  the single most likely edit a term will ever receive;
- a question identified by an area code plus an ordinal, which is how the reference module does it —
  breaks when a question is inserted, deleted or reordered;
- a mention identified by a time — breaks on every re-transcription (D-KG-5);
- a lesson section identified by its heading text — breaks on every wording fix.

Each of these is a *content-derived* or *positional* identifier, and the platform's identity contract
already forbids both, with paired mutation proofs demonstrating that it catches them.

## 2. Entities

### 2.1 Area

The workshop's realisation of the reference module's *module* level (D1).

| Field | Meaning | Invariant |
|---|---|---|
| identifier | minted, persisted | §1 |
| title | human-readable name | non-empty |
| summary | one-paragraph statement of what the area covers | non-empty when published |
| ordinal | display order | unique within the curriculum; **not** identity |
| origin | `promoted` — from the five existing prose areas — or `extracted` | closed vocabulary |
| evidence | the mentions that evidence it | **at least one when published** (FR-008) |
| evidence certainty | `mixed` or `uncertain-only`, derived from the evidencing passages | an area evidenced only by uncertain passages is `uncertain-only` (FR-012) |
| lesson sections | ordered | may be empty before materials are authored; not publishable so |
| question sets | one short, one long | both required when published (FR-034a) |
| publication review | the recorded review | **publication and export are blocked without it** (FR-016, FR-048) |
| chapters | the chapters this area draws evidence from | **many-to-many.** An area is never owned by a chapter |

**The many-to-many relation to chapters is load-bearing**, not future-proofing for its own sake.
With one chapter present, a one-to-many shortcut is indistinguishable in behaviour and cheaper to
build. It breaks at the second chapter, when a topic recurs — and it breaks after links exist.

### 2.2 Term

| Field | Meaning | Invariant |
|---|---|---|
| identifier | minted, persisted | §1 |
| canonical form | the term's preferred name | non-empty |
| variants | observed surface forms that resolve to this term | may be empty |
| areas | the areas this term belongs to | may be several |
| significance | the recorded measure and its inputs | **inspectable**; raw frequency alone is disqualified (FR-013, D-KG-6) |
| certainty | `confident` or `uncertain` | an uncertain term is marked and never presented as confident (FR-011) |
| evidence | the mentions that evidence it | **at least one when published** |

**A term with no evidence does not exist.** This is a stronger statement than "is not published": if
its last evidencing passage is redacted, the term is withdrawn from the taxonomy, not merely
unlinked (edge case; FR-027).

### 2.3 Lesson Section

An addressable part of an area's materials, so a link can name a part of an area rather than only
the whole. This is what makes the operator's *"proper chapters and part of the chapters"* navigable.

| Field | Meaning | Invariant |
|---|---|---|
| identifier | minted, persisted | §1 |
| area | owning area | exactly one |
| heading | the section's title | one of the seven skeleton sections, or a per-topic subsection within one |
| ordinal | order within the area | **not** identity |
| authorship | `authored` or `assembled` | required (FR-017) |
| citations | the passages its claims rest on | every substantive claim cited or marked editorial (FR-015) |

### 2.4 Question

| Field | Meaning | Invariant |
|---|---|---|
| identifier | minted, persisted | §1 |
| area | owning area | exactly one |
| set | `short` or `long` | closed |
| kind | `mcq`, `short`, `flashcard` | ported vocabulary |
| prompt | the question | non-empty |
| choices, correct index | multiple choice only | present exactly when kind is `mcq` |
| answer | model answer | present for `short` and `flashcard` |
| explanation | why the answer is right | optional |
| category, difficulty | ported closed vocabularies | difficulty is one of the reference's three values |
| answer authorship | `authored` or `assembled` | assembled answers are marked as such wherever shown (FR-038, SC-020) |
| **citations** | **the passages that teach the answer** | **at least one, and every one must resolve, or the question is not served** (FR-035, FR-036, D4) |
| lesson sections | the sections this question assesses | at least one — this is what makes SC-017b measurable |

**Two invariants distinguish the sets and are checkable rather than felt** (D-KG-7):

- a `short`-set question may cite **one** passage;
- a `long`-set question **must cite more than one distinct passage**.

**This entity is the feature's one deliberate divergence from the reference.** The reference's
equivalent has fields for prompt, choices, answer, explanation, category and difficulty — measured
across 785 items — and **no source field of any kind**. The citations field is the difference, and
making it mandatory rather than optional is the difference between a guarantee and a claim.

### 2.5 Mention — the join that carries the feature

| Field | Meaning | Invariant |
|---|---|---|
| identifier | minted, persisted | §1 |
| subject | the term or area being mentioned | exactly one |
| passage | the passage it occurs in | **the join key.** Never a time (FR-033b, D-KG-5) |
| text span | character offsets within the passage's text | required |
| time span | start and end, for media-backed passages | present exactly when the passage is a transcript segment |
| **precision** | `word` or `segment` | **required whenever a time span is present** (FR-021, D-KG-1) |
| timing confidence | the word's probability, when precision is `word` | carried, not discarded — 17.4% of words fall below the flag threshold |
| origin | how the mention was found | inspectable |

**Precision is a field, not a convention.** A mention resolved by joining the word sidecar has
`word` precision; one resolved only against its enclosing segment has `segment`. Measured: 99.52% of
words join to a segment and 0.48% do not, so both branches are real and the second is not a
theoretical fallback. Conflating them is forbidden because the failure is invisible — the link still
plays, just in the wrong place.

**A mention spanning a segment boundary produces one mention per segment it touches** (FR-022).
Attaching it to one silently loses half its evidence, and the evidence count is what publication
decisions rest on.

### 2.6 Publication Review

| Field | Meaning | Invariant |
|---|---|---|
| subject | the area reviewed | exactly one |
| decision | recorded outcome — including *"nothing to change"* | **required.** Recording nothing to change is valid; skipping the review is not (FR-016) |
| reviewer | who | non-empty |
| time | when | must be **newer than the materials it reviews**, or it is stale and fails |

### 2.7 Progress

Ported from the reference, whose model already gets the important part right.

| Field | Meaning | Invariant |
|---|---|---|
| session | whose progress | — |
| item type, item | what the progress is about | an area, a question set, or a question |
| status, grade, streak | the learner's state | — |

**Survives re-ingest** (FR-039). The reference deliberately preserves this table when it rebuilds
everything else, and that is the behaviour to port: a learner's history is not derived from the
content and must not be discarded when the content is rebuilt.

### 2.8 Locus

Not stored — computed, and returned with every search hit. Named as an entity because the
specification requires it to *resolve*, and a thing that must resolve needs a defined shape.

| Field | Meaning |
|---|---|
| containing unit | the area, chapter, lesson section or file that contains the hit |
| position | a time span for media-backed content; a text span with **match offsets** otherwise; a file and symbol position for code |
| precision | inherited from the mention model where the position is a time |

The same passage can be reached through more than one containing unit — it may evidence two areas —
so the locus is a property of the *hit*, not of the passage.

## 3. Relationships — the connectivity matrix, and its storage

FR-033a requires six traversals across four content kinds. Every one is **derived from mentions and
citations**; none is a separately stored edge that could drift out of agreement with them.

| From | To | Derived through |
|---|---|---|
| a moment in the recording | area / lesson / question | the enclosing segment's passage → its mentions → their subjects; and passage → citations → questions |
| an area, lesson or question | a moment in the recording | citations → passages → time spans, with precision |
| a transcript passage | area / lesson / question | mentions and citations on that passage |
| a code passage | a transcript passage | the existing cross-reference graph, plus shared area membership |
| an area | code passages | mentions whose passage kind is code |
| any kind | any other, transitively | traversal over the above, cycle-guarded |

**Every traversal is bidirectional** (FR-018), and bidirectionality is a property of the derivation
rather than of a second stored edge: a mention read forward gives subject-to-passage and read
backward gives passage-to-subject. Storing a reverse edge would be faster and would introduce the
possibility of the two disagreeing, which is a class of bug with no symptom.

**Cycle safety** (FR-026): traversal carries a visited set and a depth bound, and reports truncation
rather than silently stopping — the existing cross-reference response already carries a truncation
field, and the same discipline applies here.

## 4. Resolution — one path, four outcomes

Every link, citation, mention and cross-reference resolves through **one** function, the one the
platform already uses, with four outcomes that are never collapsed:

| Outcome | Meaning |
|---|---|
| **found** | the target exists and is readable |
| **redacted** | the target exists and its content is suppressed — distinct from absent |
| **not present** | the target is not in the registry — a loud dead link |
| **could not determine** | the registry could not be read — **never** collapsed into "not present" |

**Why the fourth outcome is not optional**: collapsing "could not determine" into "not present"
makes an unreadable database look like a curriculum that never contained the passage. That is the
conflation this repository has found and fixed four separate times, and it is why the platform's
resolver already has this shape.

**No fallback of any kind** (FR-023, FR-024): no fuzzy text matching, no nearest-neighbour lookup,
no prefix matching, no same-content-hash lookup. An unresolvable link fails loudly. A silently
re-pointed link is the one outcome the whole identity model exists to prevent.

## 5. Redaction propagation

FR-027 requires redaction to reach every artifact kind this feature introduces. The propagation
targets, enumerated so that none is discovered missing later:

1. **Mentions** on the redacted passage — withdrawn.
2. **Terms** whose last evidence was that passage — the term itself is withdrawn, not merely
   unlinked.
3. **Areas** whose last evidence was that passage — unpublished, and reported.
4. **Questions** citing it — **withheld**, because an unresolvable citation means the question is not
   served (FR-036).
5. **Lesson sections** citing it — the claim is marked as having lost its evidence, not silently
   left standing.
6. **Index entries** — removed; the existing index already excludes redacted rows and the new kinds
   must inherit that rather than reimplement it.
7. **Exports** — regenerated or withdrawn; an exported document is a copy that outlives the
   redaction if nothing acts on it.
8. **Stored answers** — any cached answer citing it.

SC-012 measures all eight, with a paired mutation that skips exactly one.

## 6. Invariants the model must not be able to violate

Stated as invariants rather than as tests, because a test can be deleted and an invariant enforced
in the type cannot be — this is the "an assertion that greps is not a test" rule applied to shape.

- **I1** — no entity carries an identifier derived from its own content or position.
- **I2** — a mention with a time span always carries a precision.
- **I3** — a served question always has at least one resolving citation.
- **I4** — a long-set question always cites more than one distinct passage.
- **I5** — a published area always has at least one evidencing mention and a review newer than its
  materials.
- **I6** — a published term always has at least one evidencing mention.
- **I7** — no stored relationship is keyed on a time.
- **I8** — every relationship is traversable in both directions.
- **I9** — resolution has exactly four outcomes, and "could not determine" is never one of the other
  three.
- **I10** — every passage is either attached to an area or explicitly classified as unattached.

## 7. What this model deliberately does not have

- **No area hierarchy.** Areas are flat with an ordering. The reference has a track level above its
  modules, ported as the curriculum spine, but nesting areas inside areas is not modelled — nothing
  in the corpus evidences a need for it, and a hierarchy nobody needs is a navigation cost.
- **No authored chapter sections.** Sections stay derived, with their existing rule and cross-check.
  Authoring them would create a second source of truth about a chapter's structure.
- **No free-text grade.** D3 keeps automatic grading out of scope; a grade field for short answers
  would invite it back in by accident.
- **No stored reverse edges.** §3 explains why: two representations of one fact can disagree, and
  the disagreement has no symptom.
