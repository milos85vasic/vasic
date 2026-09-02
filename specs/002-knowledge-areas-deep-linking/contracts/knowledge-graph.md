# Knowledge Graph Contract — Extraction, Mentions, Authorship, Pipeline

**Feature**: `specs/002-knowledge-areas-deep-linking` | **Date**: 2026-09-01

Companion to [`http-api-delta.md`](./http-api-delta.md), which covers the wire. This document covers
**how the graph comes to exist**: minting, promotion, extraction, reconciliation, mention derivation,
authorship rules and the repeatable pipeline. Entity shapes live in [`../data-model.md`](../data-model.md)
and are not restated. The knowledge-model contract in the workshop's own documentation is
authoritative for the ported hierarchy (FR-005); where it and this document describe the same thing,
it wins.

## 1. Minting — normative

- **M1** — every new entity mints through the **existing** passage minter. There is no second minter
  and no second identifier format.
- **M2** — minting happens **once, at creation**. Re-running any stage over unchanged input mints
  **zero** identifiers.
- **M3** — an identifier is never derived from the entity's text, title, slug, ordinal, heading,
  file position or any hash of these.
- **M4** — minting is the **last** branch of every matching algorithm, never the first. If an entity
  can be matched to an existing one, it is matched; minting is what happens when it demonstrably
  cannot.
- **M5** — an anchor that is present but unknown to the registry is an **error**. It is never a
  silent mint and never an adoption. This mirrors the passage registry's existing hard edge, and it
  exists because the alternative — adopt on mismatch — turns a corrupted reference into a plausible
  one.

**Gate G-KG-13** — run every stage twice over unchanged input and assert zero mints, a byte-identical
taxonomy file, and no source file modified. **Paired mutation**: make minting unconditional whenever
no anchor was read in the current run; the gate must go red on all three assertions at once.

## 2. Promotion, extraction, reconciliation — the order is normative

Order per research D-KG-3. Running these out of order produces a defensible-looking result that has
quietly inverted which source of truth holds the identifiers.

### 2.1 Promote (first)

- **P1** — each area that exists today as prose becomes a first-class entity with a minted
  identifier.
- **P2** — each promoted area is evidenced against the corpus. **An area that acquires zero
  evidencing mentions fails promotion loudly** and is not published. It is not published unevidenced
  and it is not silently dropped; both are reported.
- **P3** — the prose document becomes the area's materials, and its existing section headings become
  lesson sections. It is not rewritten as a side effect of promotion.
- **P4** — promotion records, per area, that its origin is `promoted`. This is not decoration: it
  tells a later reader which areas embody human judgement about what the workshop teaches and which
  a machine proposed.

### 2.2 Extract (second)

- **E1** — extraction reads the **whole corpus** and proposes areas and terms. It never reads the
  reference module (FR-004a).
- **E2** — every proposal carries its evidence and its significance measure **with the inputs to
  that measure**, so a reviewer can disagree with a specific term and see why it scored as it did.
- **E3** — raw frequency alone is **not** a significance measure (FR-013). A measure that ranks a
  spoken corpus by frequency returns function words.
- **E4** — a proposal with a low-confidence score is marked `uncertain` and is never presented as
  confident (FR-011).
- **E5** — **no area count is targeted.** The corpus evidences as many areas as it evidences.
  Producing areas to match the reference's 34 would mean inventing coverage the recording does not
  contain, which is the failure this whole contract is arranged against. Research **U3** records that
  the actual number is unknown until the first run, and **no downstream artifact may assume one**.

### 2.3 Reconcile (third, and visibly)

Every extracted proposal falls into exactly one of three branches, and the third is the one that
matters:

- **R1 — attaches**: the proposal is within a promoted area's scope. It becomes evidence on that
  area. No new area, no new identifier.
- **R2 — adds**: the proposal is outside every promoted area's scope. A new area is minted with
  origin `extracted`.
- **R3 — contradicts**: the proposal overlaps a promoted area but disagrees about its scope or
  boundary. It is **reported for a decision**. It is **neither merged nor discarded**, and the
  pipeline does not proceed past it silently.

**Why R3 is a hard stop rather than a heuristic**: merging on overlap silently redraws a boundary a
human drew. Discarding on overlap silently ignores evidence. Either is a decision about what the
workshop teaches, made by a similarity score, invisibly. Reporting costs a review; the alternatives
cost the taxonomy's credibility.

**Gate G-KG-14** — seed a contradiction, run reconciliation, and assert it appears in the report and
that neither a merge nor a discard occurred. **Paired mutation**: make R3 fall through to R1 above a
similarity threshold; the gate must go red.

### 2.4 Account for everything

- **A1** — every passage is either attached to at least one area or **explicitly classified as
  unattached with a stated reason** (FR-010).
- **A2** — attached plus classified equals the registry count. Exactly. A shortfall is a failure, not
  a rounding.
- **A3** — the **proportion** attached is published as a measured figure. **No threshold is set**
  (research U2): the density of teachable substance in a spoken working session has not been
  measured, and a guessed target gets optimised toward.

## 3. Mention derivation — the measured join

The algorithm is normative because its two branches produce genuinely different guarantees, and
collapsing them is invisible.

**Given** an occurrence of a term or area in a passage:

1. Record the **text span** — character offsets within the passage's text. Always.
2. If the passage is **not** a transcript segment, stop. No time span, no precision.
3. If it **is**, attempt the word join: locate the occurrence's words in the chapter's word sidecar
   and take their start and end times.
   - **Joined** → time span from the word times; **precision = `word`**; carry the word's timing
     confidence.
   - **Not joined** → time span from the enclosing segment; **precision = `segment`**.
4. If the occurrence crosses a segment boundary, emit **one mention per segment it touches**
   (FR-022).

**Measured, and both branches are real**: 15,610 words, monotonic, spanning exactly the same range as
the segment set. **15,535 (99.52%) join to a segment by time; 75 (0.48%) do not**, falling in the
gaps between segments. The second branch is not a theoretical fallback.

- **N1** — `precision` is **required** whenever a time span exists. There is no default. A default
  would make every unjoined mention claim word accuracy.
- **N2** — the two precisions are **never** conflated in storage, on the wire, or in the interface.
  Measured segment durations are median 6.74 s, p95 10.78 s and maximum 20.22 s, so the difference
  between the branches is up to twenty seconds of recording — long enough to be a different topic.
- **N3** — timing confidence is carried, not discarded. 17.4% of words fall below the recorded flag
  threshold and the 5th percentile is 0.559; "usually confident" is the reasoning that ships the
  wrong link.
- **N4** — the join is by **time into segment**, and the segment yields the **passage identifier**.
  The identifier is what is stored. The time is a position (FR-033b).

**Gate G-KG-4** (shared with the wire contract) — assert every time-carrying mention declares its
precision. **Paired mutation**: omit precision and default it to `word`; the gate must go red.

**Gate G-KG-15** — assert the unjoined fraction is measured and reported rather than assumed zero.
**Paired mutation**: silently treat an unjoined occurrence as `word` precision at the segment start;
the gate must go red. Research **U5** asks whether the 75 unjoined words cluster or scatter; the
answer changes nothing about this contract but changes whether there is a segmentation defect worth
fixing.

## 4. Authorship — materials and questions

### 4.1 Provenance of prose

- **W1** — every lesson section records `authored` or `assembled` (FR-017). Under a purely extractive
  authorship decision everything is `assembled`; under an agent-authored one everything is
  `authored`; under a generated one both appear. The field is built now so all three remain
  shippable without a schema change.
- **W2** — every substantive claim carries at least one resolving citation, or is **visibly marked as
  editorial framing that is not workshop content** (FR-015). There is no unmarked, uncited claim.
- **W3** — an area is not published until its publication review is recorded, and a review older
  than the materials it reviews is **stale** and fails (FR-016). Recording *"nothing to change"* is
  a valid review; skipping it is not.

### 4.2 Questions

- **Q1** — every question carries at least one citation and **every citation must resolve**, or the
  question is **withheld** (FR-035, FR-036). Withholding is the default path, not an error path.
- **Q2** — a `long`-set question cites **more than one distinct** passage; a `short`-set question may
  cite one (D-KG-7). This is the structural distinction, chosen because perceived difficulty is not
  reproducible and citation breadth is.
- **Q3** — every question names the lesson sections it assesses. This is what makes per-section
  coverage measurable rather than estimated.
- **Q4** — an assembled model answer is marked assembled wherever it appears (FR-038).
- **Q5** — **no question, prompt, choice, answer or explanation may originate from the reference
  module** (FR-004, FR-004a). It holds 785 finished questions about a different subject, in a
  private repository. Reusing them would be faster, would survive a superficial review, and would be
  worthless.

**Gate G-KG-16** — plant one reference-module question in a workshop bank and assert the content
boundary check fails. **Paired mutation**: scope the boundary check to the outbound direction only;
the gate must go red. The check runs **both** ways deliberately: outbound keeps a private recording
out of public repositories, inbound keeps the workshop from shipping someone else's curriculum under
its own name.

### 4.3 Coverage measurement

- **C1** — every lesson section of every published area is assessed by at least one question
  (SC-017b). A section with zero is listed explicitly, never omitted from the enumeration.
- **C2** — the proportion of an area's evidencing passages cited by at least one question is computed
  **per area** and published as a **distribution**, never as a mean (SC-017c). A mean is how a
  well-covered area conceals an empty one.
- **C3** — **no threshold** is expressed and no field says "pass" (research U2).

## 5. The repeatable pipeline

The feature is complete when the **next** chapter runs through unchanged, not when this chapter's
materials look finished.

- **S1** — the knowledge layer is a set of stages **added to the platform's existing chapter-addition
  path** — its documented procedure and its prompt — not a second way to add a chapter (FR-033e).
  Two procedures for one act guarantee one of them rots.
- **S2** — processing a chapter yields, without hand-authoring of structure: transcript, passages
  with minted identifiers, extracted areas and themes, authored materials, short and long question
  sets, cross-references, index entries, deep links.
- **S3** — every stage is **three-valued**: determined-good, a real problem found, or could not
  determine. A missing dependency, an unreachable service or a crashed helper is always the third.
- **S4** — every stage is **idempotent** (M2) and **resumable**, and reports progress from measured
  rate rather than from an estimate.
- **S5** — a chapter that cannot be fully processed reports **precisely what is missing** and
  publishes nothing (FR-033g). A partially processed chapter is never presented as complete.
- **S6** — adding a chapter **updates** the taxonomy: established areas keep their identifiers and
  gain evidence, newly evidenced areas are added, contradictions are reported (FR-033f, §2.3 R3).
- **S7** — no stage writes to a source. Sources are opened read-only; derived artifacts land only in
  the derived locations.
- **S8** — every stage writes its evidence to the versioned evidence location, including — and
  especially — on a could-not-determine outcome, which is the run a reader most needs the record of.

**Gate G-KG-17** — run the whole pipeline against a small synthetic chapter and assert every output
in S2 exists and that the diff contains **no hand-created structural file**. **Paired mutation**:
remove one stage from the procedure; the gate must go red naming the missing output. This is the
gate that proves the pipeline is repeatable rather than that one chapter happens to be finished.

**Gate G-KG-18** — withhold one required input and assert the run names exactly what is missing and
publishes nothing. **Paired mutation**: downgrade the missing input to a warning; the gate must go
red.

## 6. Resolution and redaction

Both are inherited from the platform's existing contracts and are **not** reimplemented here. Two
consequences bind this feature specifically:

- **X1** — every link, citation and mention resolves through the **one** existing resolution
  function, with its four outcomes. There is no second path and no fallback of any kind — no fuzzy
  text match, no nearest neighbour, no prefix match, no same-hash lookup (FR-023, FR-024).
- **X2** — redaction propagates to all **eight** targets enumerated in the data model: mentions,
  terms, areas, questions, lesson sections, index entries, exports and stored answers. **Gate
  G-KG-7** skips exactly one and must go red.

## 7. Environment adaptability

Requirements that follow from measurement on this host, not from principle:

- **V1** — every export and diagram tool is **detected and capability-probed**, never assumed from a
  name on `PATH`. Measured: all of them resolve into **user-local** directories rather than system
  ones. This repository has already shipped a defect of exactly this shape — a media tool that
  answered a version query and rejected the flag that mattered, because the name resolved into an
  unrelated cache.
- **V2** — word-timing availability is detected **per chapter**, not assumed corpus-wide. One chapter
  has a word sidecar; nothing guarantees the next one will.
- **V3** — the significance measure prints the host facts and the arithmetic it used, so the score
  can be audited rather than trusted.
- **V4** — no stage assumes a generative model. There is none on this host, and a stage that requires
  one reports could-not-determine rather than failing as though the content were at fault.

## 8. Gate inventory

| Gate | Subject | Owned by |
|---|---|---|
| G-KG-1 | route manifest completeness | wire contract §2 |
| G-KG-2 | unprovenanced question withheld | wire §3.5 / here §4.2 Q1 |
| G-KG-3 | long-set citation breadth | here §4.2 Q2 |
| G-KG-4 | precision declared on every time-carrying entry | here §3 |
| G-KG-5 | offsets populated or field absent | wire §4.1 |
| G-KG-6 | no time-keyed relationship | here §3 N4 |
| G-KG-7 | redaction reaches all eight targets | here §6 X2 |
| G-KG-8 | unresolvable link fails loudly | here §6 X1 |
| G-KG-9 | export toolchain unavailable ⇒ could-not-determine | here §7 V1 |
| G-KG-10 | unevidenced area or term never served | here §2.1 P2 |
| G-KG-11 | advertised kind is actually retrievable | wire §5 |
| G-KG-12 | coverage per area, never a mean | here §4.3 C2 |
| G-KG-13 | idempotency: zero mints on re-run | here §1 |
| G-KG-14 | contradiction reported, never merged or discarded | here §2.3 |
| G-KG-15 | unjoined mention fraction measured, not assumed zero | here §3 |
| G-KG-16 | content boundary enforced **in both directions** | here §4.2 Q5 |
| G-KG-17 | synthetic chapter produces every output, no hand-assembly | here §5 |
| G-KG-18 | incomplete chapter names what is missing, publishes nothing | here §5 |

Eighteen gates, eighteen paired mutations. A gate that has never been observed failing is not known
to work, and this repository has twice shipped a proof that could not fail — one whose control
failed so zero mutations ever ran, one that exercised only sandboxed copies while the real entry
point could not start. **Every proof here must include a case that runs the real entry point against
the real tree.**
