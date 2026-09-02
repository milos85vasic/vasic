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
| **modality** | `spoken` or `on_screen` | **required on every mention** (§2.9, D5). Derived from the passage's kind, never guessed |
| **interval bound** | the sampling period the time span is accurate to, when the passage is `screen_text` | carried, not discarded — the on-screen analogue of timing confidence (§2.9) |
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

### 2.9 On-Screen Text Passage — the `screen_text` kind

**Added 2026-09-02 by operator decision** (spec §Clarifications, D5). The corpus holds only what was
**spoken**; the substance of a screen recording is text that was **shown**. This kind is how that
text becomes addressable. It is a new **passage kind**, not a new entity: it takes the existing
Passage shape in §0 and fills it, so it inherits the minter, the four-outcome resolver, the redaction
flag and the mention model without any of them being touched.

| Registry field | How `screen_text` fills it | Invariant |
|---|---|---|
| identifier | minted through the **same** minter as every other passage | §1. **No second minter and no second identifier format** |
| kind | `screen_text` | joins `transcript_segment`, `doc_section`, `code`, `diagram` — a fifth value, not a fifth registry |
| chapter scope | the chapter whose recording it was read from | exactly one |
| ordering key | the **visibility onset** — its start time, exactly as a transcript segment's ordering key is its start time | media-backed, so the ordering key is a time |
| source reference | the recording, plus the **sample range** the text was observed across | the registry's existing path-plus-range shape; the range counts samples, not lines |
| text | the recognised text | non-empty. An empty recognition is **not a passage** — it is a sample that recognised nothing, and is reported as such |
| immutable machine text | as for every passage | unchanged |
| provenance marking | `ocr`, and the engine and settings that produced it | **distinct from `asr`.** A reader must be able to tell which engine produced a passage without inferring it from the kind |
| confidence | the engine's own confidence for the recognised text | **carried, not discarded** — the on-screen analogue of N3 |
| uncertainty flag and reason | set when the engine's confidence falls below the recorded threshold | the threshold is recorded, never a literal in code |
| redaction flag | inherited unchanged | §5 applies to this kind in full |
| change-detection hash | as for every passage — **explicitly not identity** | unchanged |
| mint time, ingest run | as for every passage | unchanged |

**Its time span is a visibility interval, and the interval has a bound.** A transcript segment's time
span comes from the recogniser's own alignment. An on-screen passage's comes from a **sampling grid**:
the text was first seen at one sample and last seen at another, so the true onset lies within one
sampling period of the observed onset. That bound is a real quantity, it is not zero, and it is
**carried on the passage and on every mention derived from it** rather than left for a reader to
assume away.

**Why this does not add a third precision value.** The temptation is to mint `ocr` as a third value
of the mention `precision` field. It is refused: `precision` is two-valued and every consumer switches
on two values (§2.5, contract §3 N1/N2), and a third value changes the wire, the storage and every
switch — to express something the field does not mean. `precision` records **how the time was
derived**: from a per-word timing record (`word`), or from the enclosing unit (`segment`). An
on-screen mention's time is derived from its enclosing visibility interval, so it declares
**`segment`**, and the interval's accuracy travels beside it as the **interval bound** — exactly as
timing confidence travels beside `word`. The vocabulary stays two-valued; the honesty is carried in
a field of its own rather than smuggled into an enum.

**Honest boundary, measured 2026-09-02.** The contract has always been two-valued and word precision
is *reachable* — the chapter carries a word sidecar of 15,610 records. It is **not produced in this
deployment**: `workshop/docs/limits.md` §10.1 and the defects row `precision-segment-only` in
`workshop/platform/gates/defects-registry.tsv` record that every deep link resolves at `segment`
precision today. This kind therefore joins a model whose second branch is contracted and currently
unexercised. Do not read "joins the existing precision model" as "word precision is live".

### 2.10 Corroboration Group — what stops a term counting twice

A term said aloud **and** shown on screen at the same moment produces **two** mentions on **two**
passages. Both are true and both must be navigable — but they are **one teaching moment**, and the
evidence counts that publication rests on (§2.1 *at least one when published*, §2.2, the attached
proportion in contract §2.4 A3, and the coverage distribution in contract §4.3 C2) must not silently
double because the workshop happened to be recorded with a screen.

| Field | Meaning | Invariant |
|---|---|---|
| identifier | minted, persisted | §1 |
| subject | the term or area corroborated | exactly one |
| members | the mentions grouped | **at least one**; a lone mention is a group of one, so counting is uniform |
| modalities | the distinct modalities present across the members | derived, never stored twice |
| window | the overlap tolerance the grouping used | **recorded on the group**, so the arithmetic can be audited |

- **Grouping is by subject and by overlapping time, within a measured window** — never by text
  equality alone. Two occurrences of one term twenty minutes apart are two occurrences; deduplicating
  on text alone collapses a corpus into a vocabulary list.
- **Nothing is deleted.** Both members remain individually retrievable and individually navigable —
  a learner who wants the moment the term was *shown* gets it. Grouping changes what is **counted**,
  not what exists.
- **Evidence counting is over groups; mention counting is over mentions**, and the two figures are
  published side by side so the difference is visible rather than reconciled in someone's head.
- **The window is measured, not assumed.** A term is commonly displayed *before* it is discussed, so
  a coincidence test tuned to zero lag under-groups, and a window widened until the numbers look
  tidy over-groups. Its value is settled by measurement (**U7**, task T130) with a three-valued exit,
  and task T131 implements the grouping against the value that measurement returns.

**A subject evidenced only on screen is marked `on-screen-only`** — the modality analogue of
`uncertain-only` (FR-012). It is a different fact from a subject the workshop actually talked about,
and a reader who cannot tell them apart will over-read the taxonomy.

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

**The eight targets are unchanged by the `screen_text` kind, and that is the point** — it is a
passage kind, so redacting a `screen_text` passage withdraws its mentions through target 1 and
cascades through the remaining seven by the same rules. What must be proven rather than assumed is
that propagation is not written against ASR-derived mentions only; task **T140** asserts it and its
paired mutation restricts propagation to the spoken modality.

**On-screen text is a wider disclosure surface than the transcript, and the redaction path is not
the whole answer to that.** A screen recording shows what was never said: window titles, file paths,
identifiers, a third party's name in a title bar. The transcript can only carry what somebody spoke;
OCR output carries whatever was visible. The boundary obligation this creates is stated as
**FR-065** and gated by **G-OCR-11** (task T137), and it applies *before* any OCR-derived text
reaches a public artifact — redaction removes what has been recognised as needing removal, and the
boundary check is what recognises it.

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
- **I11** — the mention `precision` vocabulary has exactly **two** values. A `screen_text` mention
  declares `segment` and carries its interval bound; it never declares `word`, and no third value
  exists.
- **I12** — every mention declares its **modality**, and every evidence count that a publication,
  coverage or attachment figure rests on is taken over **corroboration groups**, never over raw
  mentions.
- **I13** — no OCR-derived mention is published for a chapter whose OCR accuracy has not been
  **measured for that chapter**. An unmeasured chapter yields could-not-determine, never a default
  pass.

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
- **No third mention precision.** §2.9 explains why: `precision` records how a time was derived, and
  an on-screen time is derived from its enclosing interval. Adding an `ocr` value would change the
  wire, the storage and every switch in order to express something the field does not mean, while
  the fact a reader actually needs — how wide the interval is — travels better as a number than as
  an enum.
- **No deletion of the duplicate occurrence.** §2.10 explains why: the on-screen occurrence is a real
  moment a learner may want to reach. Only the **count** is deduplicated, and both figures are
  published.
- **No text-equality deduplication.** Two occurrences of one term at different times are two
  occurrences. Grouping is by subject **and** overlapping time within a measured window, or it is
  not grouping — it is a vocabulary list.
