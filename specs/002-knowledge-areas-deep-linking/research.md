# Phase 0 Research — Knowledge Areas & Bidirectional Deep Linking

**Feature**: `specs/002-knowledge-areas-deep-linking` | **Date**: 2026-09-01

Every decision below is labelled `D-KG-n` and carries the measurement that produced it. Where a
question could not be settled from evidence in the tree, it appears in the **Unverified register**
at the end rather than being answered by a plausible guess. An entry in that register is not a
minor caveat: three tasks in the breakdown are explicitly blocked on one.

---

## D-KG-1 — Word-level mention precision is reachable, and the join is measured

**Question**: the specification requires mention positions to be as precise as the data supports and
to state which precision they used. Is word precision actually reachable, and at what cost?

**Measured**, on the one chapter that exists:

| Quantity | Value |
|---|---|
| Word records in the chapter's word sidecar | **15,610** |
| Fields per record | a word, a start time, an end time, a probability |
| Word starts monotonically ordered | **yes** |
| Span covered by the word sidecar | 0.00 s to 6,924.10 s |
| Span covered by the segment set | 0.00 s to 6,924.10 s — **identical** |
| Words locatable to a segment by time | **15,535 of 15,610 = 99.52%** |
| Words **not** locatable to any segment | **75 = 0.48%** |
| Word probability, 5th / 50th / 95th percentile | 0.559 / 0.997 / 1.000 |
| Words below the recorded flag threshold | 2,717 = 17.4% |
| Independent cross-check | the segment sidecar's own word count is 15,610 — the two files agree |

**Decision**: mention positions are resolved at **word precision by a time join** from the word
sidecar onto the segment set, and from the segment onto its passage identifier. Where a word does
not fall inside any segment span — 0.48% of them, occupying the gaps between segments — the mention
resolves at **segment precision** against the nearest enclosing segment, and is labelled as such.

**Why this and not the alternatives**:

- Storing word offsets *in* the registry was rejected: the registry is the source of truth and its
  byte-stability is a proven property with its own gates. Adding 15,610 rows of derived data per
  chapter to a file whose stability is load-bearing trades a measured guarantee for a convenience.
- Discarding the sidecar and using segment precision everywhere was rejected on measurement: the
  segment distribution is median 6.74 s and maximum 20.22 s, so a "jump to where this was said"
  could land 20 seconds away while the data to land on the word was sitting unused.
- Silently mixing the two was rejected as the worst option and is forbidden by FR-021. A
  segment-derived position displayed as word-accurate is a confident wrong answer, and it is
  invisible — the link still renders and still plays.

**The honest limit, stated rather than discovered later**: word precision is *available*, not
*uniformly trustworthy*. The median word probability is 0.997, but the 5th percentile is 0.559 and
17.4% of words fall below the recorded flag threshold. A mention anchored on a low-confidence word
inherits that uncertainty and must carry it, exactly as an uncertain passage does.

---

## D-KG-2 — Identity: one minter, five new kinds, no second scheme

**Question**: areas, terms, lesson sections, questions and mentions all need identifiers. Reuse the
passage minter, or give each kind its own scheme?

**Measured**: the existing minter produces 26-character sortable identifiers, monotonic within a
process, and attaches identity through an anchor key with a deliberate hard edge — an anchor that is
present but unknown to the registry is an **error**, never a silent mint and never an adoption. Its
paired mutation proofs exist and pass for all three ways this can go wrong: content-derived
identity, positional identity, and unconditional minting on every run. Identity survival is measured
at 1,101 of 1,101 across a content correction and a section insertion.

**Decision**: **one minter, five new kinds.** Every new entity mints through the existing library.
No kind derives its identifier from its own text, its position, its title, its slug, or its
ordinal.

**Why**: the property the whole feature rests on — that a link survives a correction — is a property
of *that minter*, proven by *those* mutation tests. An identifier scheme invented for areas would
inherit none of that and would be tested, at best, by tests written by the same person who wrote the
scheme. The failure mode is also the specific one this repository has already measured elsewhere: a
content-derived identifier changes when a typo is fixed, which is the operation a curriculum
performs most.

**Consequence recorded now rather than discovered**: the reference module links a question to its
area by a **positional code**. That linkage form is exactly what this decision forbids, so the
question-bank layout is ported and its linkage is **upgraded** to a minted identifier. This is
recorded in the plan's port register as an adaptation, not as a port.

---

## D-KG-3 — The taxonomy is promoted first, extracted second, and reconciled visibly

**Question**: five areas already exist as prose. Extraction will derive its own. Which wins?

**Measured**: the workshop's training documentation carries **5 area documents**, identified `01`
through `05`, already following an adapted form of the reference's seven-section skeleton. They have
no identifier, no schema, no database representation and no endpoint. The corpus they describe is
the same 1,101 passages extraction would read.

**Decision**: a three-step order, and the order is the decision.

1. **Promote.** The five prose areas become first-class entities with minted identifiers, and are
   evidenced against the corpus — every one must acquire at least one evidencing passage or it fails
   promotion loudly rather than being published unevidenced.
2. **Extract.** Derivation runs over the whole corpus and proposes areas and terms.
3. **Reconcile, visibly.** Where extraction proposes something the promoted set already covers, it
   attaches as evidence. Where it proposes something new, it is added. Where it **contradicts** a
   promoted area — different scope, different boundary — it is reported for a decision and is
   neither merged nor discarded.

**Why this order**: the prose areas encode human judgement about what the workshop teaches.
Extraction encodes statistics about what words occur. Running extraction first and merging prose in
afterwards inverts the authority, and the merge would happen at the moment when the machine's
proposal already has links pointing at it. Promoting first means the human judgement holds the
identifiers, and extraction enriches it.

**Rejected**: extracting fresh and treating the prose as documentation to be rewritten. Simpler to
build, and it produces two competing sets of areas whose reconciliation is the same work done later
with more links to break.

---

## D-KG-4 — Match offsets must be produced; the field cannot stay as it is

**Question**: the specification requires a search hit to say where within its text the match
occurred. What exists?

**Measured**: the hit already declares a list of offset pairs, and the construction path sets it to
the empty list **unconditionally** — there is no branch in which it is populated. The snippet is
generated with **empty** match delimiters, so the snippet carries no in-string marker either. The
relevance floor is uncalibrated and the response says so honestly.

**Decision**: **offsets are produced.** The lexical leg computes them, because it is the only leg
that knows which terms matched; the semantic leg carries no offsets and must say so rather than
returning an empty list that reads like "no matches inside".

**Why this matters more than it looks**: an empty list and "this leg cannot produce offsets" are
different facts, and the current field cannot express the difference. A consumer reading the schema
would reasonably build a highlighter against it and ship a highlighter that never highlights. This
is the blind-instrument shape the governing principles name, sitting in the exact field the
operator's "link exactly where they appear" requirement lands on.

**The alternative, which is also acceptable and must be chosen deliberately**: remove the field and
state its absence. What is *not* acceptable is leaving a field that promises a position and never
carries one. FR-029 admits both outcomes and forbids the third.

**Unverified**: whether the index's full-text engine exposes match positions directly, or whether
offsets must be recomputed from the query against the matched text. See **U1** — this determines
whether offsets are cheap or whether they are a second pass.

---

## D-KG-5 — The graph is keyed on the passage identifier, never on time

**Question**: a mention has a time. A citation has a time. Why not key the graph on time?

**Measured**: identity survival across a content correction and a structural insertion is 1,101 of
1,101 for the passage identifier. Timestamps have no such measurement and could not have one — a
re-transcription with a different segmentation moves every boundary, and the segment set is already
known to be derived rather than authored.

**Decision**: **every relationship is keyed on the passage identifier.** Time is carried as a
*position*, never as a key. SC-015b measures this by inspecting every stored relationship, with a
paired mutation that introduces one time-keyed link.

**Why the distinction is not pedantic**: a time-keyed graph does not break loudly. After a
re-transcription every link still resolves, still renders, and points a few seconds off — or, where
segmentation changed more, at a different topic entirely. There is no error, no missing target, and
no symptom until a learner notices the video is discussing something else. That is precisely the
class of failure the identity contract exists to prevent, and it would be reintroduced by a
shortcut that looks natural.

---

## D-KG-6 — Term significance is demonstrated, not asserted, and frequency alone is disqualified

**Question**: how is a term distinguished from a common word?

**Measured constraint**: the corpus is a single spoken session. Spoken language is dominated by
function words and by domain-neutral verbs. A frequency-ranked term list over 15,610 words would be
led by words that carry no knowledge.

**Decision**: significance is a **recorded, re-derivable measure** combining at minimum
distinctiveness against a general-language baseline, distribution across the corpus (a term
concentrated in one passage is a mention, not an area's vocabulary), and — where available — the
term's presence in the workshop's own written material as corroboration. Raw frequency alone is
explicitly disqualified by FR-013. The measure's inputs are printed so the arithmetic can be
audited, per the repository's adaptability principle.

**Why it is specified as "a recorded measure" rather than a named algorithm**: the specification is
technology-agnostic by requirement, and the choice of measure is a Phase 1 design decision. What is
fixed here is that the measure must be *inspectable* and that a reviewer must be able to disagree
with a specific term and see why it scored as it did. SC-002 makes this concrete: a sample of at
least 30 terms is reviewed against a recorded seed, so the verdict is reproducible and the sample is
not chosen after the fact.

**Rejected**: a hand-curated term list. It would be better on day one and stale on day two, and it
would violate the rule that the fleet is derived rather than hardcoded — the same rule, applied to
a different set.

---

## D-KG-7 — Question sets: short and long are distinguished structurally, not by feel

**Question**: the operator requires "exhaustive long and short tests / quizzes". What makes a set
long rather than merely larger?

**Measured, in the reference**: 312 multiple-choice and 473 short-answer items across 34 areas, with
a closed difficulty vocabulary of three values and a measured distribution skewed to the middle
value. **None of the 785 carries any source reference.**

**Decision**: the distinction is **structural and checkable**. A short-set question tests recall of
an area's core concepts and may cite a single passage. A long-set question requires reasoning across
evidence and **must cite more than one distinct passage**. SC-017a measures exactly that.

**Why structural**: "harder" is not reproducible. Two reviewers disagree, the same reviewer
disagrees with themselves a week later, and a criterion that cannot be re-measured cannot be a
success criterion. Citation breadth is a proxy, and it is an honest one — a question that genuinely
requires connecting two parts of the material has two parts to cite, and a question that does not
cannot manufacture them without the citation check catching it.

**And the anti-gaming clause**: coverage is measured **per lesson section**, not per area (SC-017b),
and the per-area ratio of cited evidencing passages is published as a **distribution, not a mean**
(SC-017c). A hundred questions about one popular topic satisfies neither.

**No threshold is set for the coverage ratio, deliberately.** The density of assessable substance
per passage has not been measured for this corpus. Naming a percentage would be a guess presented as
a target, and a guessed target is worse than a measured figure with no target, because the guess
gets optimised toward.

---

## D-KG-8 — Materials authorship is bounded by the host, and that is why it is a clarification

**Question**: can the platform write area prose?

**Measured**: the local inference host serves exactly two models and both are embedding models —
encoders with no capacity to generate text. Separately, the platform already implements
entailment-based support verification behind a configured model directory, with lexical overlap as a
fallback, and it refuses to degrade silently from the former to the latter.

**Finding, not a decision**: run-time prose generation is **not possible on this host today**. This
is not an argument against option (c) in the specification's first clarification; it is the fact that
makes the clarification necessary. Options (a) and (b) run here today; option (c) requires an
operator action first, and that is an operator decision rather than an implementation detail.

**What is decided, because it holds under all three options**: every unit of prose records whether
it was **authored** or **assembled** (FR-017), and assembled model answers are marked as such
(FR-038, SC-020). Under option (a) everything is assembled; under (b) everything is authored; under
(c) both appear and the distinction becomes load-bearing. Building the distinction now costs one
field and makes all three options shippable.

---

## D-KG-9 — Export: port the toolchain, exceed the reference on coverage

**Measured on this host**: a Markdown converter, an HTML-to-PDF renderer, an office suite, a PDF
text extractor, an OCR engine and a Mermaid renderer **all resolve on `PATH`** — and all of them
resolve into **user-local directories**, not system ones.

**Measured in the reference**: a per-file four-format generator, a diagram renderer from text
source, an export validator, and an orchestrator that runs the three in order. Coverage achieved:
**25 of 34 areas complete; 9 are Markdown only.**

**Decision**: port the toolchain design as-is, and require **complete** coverage (SC-024) —
explicitly a higher bar than the model it is taken from, stated so nobody later "matches the
reference" and calls it done.

**Adaptability requirement that follows from the measurement, not from principle**: because every
tool resolves into a user-local directory, the pipeline **must detect its export tooling and probe
its capability**, not test for a name on `PATH`. This repository has already been bitten by exactly
this: a media tool that answered a version query and rejected the flag that mattered, because the
name on `PATH` was a symlink into a browser-automation cache. FR-049 requires an absent toolchain to
report that export could not be performed, never that it succeeded over empty output.

---

## D-KG-10 — Search extends; it is not replaced, and the reference's search is not ported

**Measured, reference**: a substring scan across three tables joined by union, a fixed result limit,
no relevance ordering, and a hit carrying a type, an area id, a title and a snippet — **no position
of any kind**.

**Measured, workshop**: a lexical leg over a full-text index with a real ranking function, a
semantic leg over stored vectors keyed by identifier and scoped by index generation, a third leg for
code, fused and reranked through a consumed library rather than a local reimplementation, with an
honest three-state envelope and an explicitly uncalibrated relevance floor.

**Decision**: the new content kinds join the **existing** index. The reference's search is **not
ported**, and the omission is recorded in the plan's register so it is not later read as an
oversight.

**One thing the reference does that is worth taking**: it searches *derived* lesson and question
text, not only source documents — which is why its search finds a question by its prompt. The
workshop must index the new kinds' own text for the same reason, rather than relying on the
passages they cite. A question that can only be found through its citations is not findable by
anyone who does not already know the answer.

---

## D-KG-11 — Answering: retrieval extends now, generation waits on a decision

**Measured**: the answering path already runs four verification layers — a retrieval gate that
refuses before any model runs, a schema constraint, a two-part citation check that separates
"cited an identifier never retrieved" from "cited an identifier that no longer resolves", and a
support verifier with two implementations. Any layer failing refuses the **whole** answer; no layer
may strip a claim and return the rest. The four resolution outcomes are kept distinct.

**Also measured, and open**: on the unanswerable set, **3 of 33** questions were answered rather
than declined. And every one of those four layers verifies the claim against the **passage**.
**None verifies the claim against the question.** A fragment that is topically related and does not
answer what was asked passes lexical overlap, passes entailment against its passage, and passes the
citation check — because all three are true statements about a fragment that is nonetheless not an
answer.

**Decision, bounded by the third clarification**: retrieval over the new kinds is extended now, and
that is safe because retrieval refuses rather than generates. Generation *about* areas, lessons and
questions waits on the operator's answer. If the answer is to close the defect, the verification
layer required by FR-051 checks the answer against the question, and it has a seam to live in —
the existing support-verifier interface is the natural place, and the entailment implementation
shows the shape.

**What is decided regardless**: the defect is named in the shipped limits document and SC-026 fails
if it is not. The one option this feature forecloses is describing it as solved.

---

## Unverified register

Entries that could **not** be settled from evidence in the tree. Each names what would settle it.
A task that depends on an entry names the entry and names the task that settles it.

- **U1 — Do match offsets come from the index, or must they be recomputed?** D-KG-4 requires offsets
  to be produced. Whether the full-text engine exposes match positions through a supported interface,
  or whether the matched terms must be re-located within the matched text as a second pass,
  determines the cost and the correctness boundary — a recomputation can disagree with what the
  index actually matched, particularly under prefix matching, which the lexical leg uses on the final
  query token. *Settled by*: probing the engine's available functions against the real index and
  comparing the positions it reports with a recomputation over the same query.
- **U2 — SETTLED 2026-09-01, for chapter 01.** *The question was*: what is the corpus's actual
  topical density? *Measured*, by the taxonomy extraction that landed while this document was being
  written: of 1,055 transcript passages, **884 are covered (83.79%)** and **171 carry no area**; by
  words, **14,290 of 15,610 are covered (91.54%)**. Every uncovered passage carries a **stated
  reason** — the extraction classifies them rather than dropping them, which is what FR-010 requires.
  Of the 267 uncertain passages, **211 are covered**.
  *What remains open*: this is one chapter. The figure is a measurement, **not a target**, and
  SC-003 still sets no threshold — a second chapter may differ, and the moment a number becomes a
  target it starts being optimised toward. The criterion continues to require the figure be
  published, not that it clear a bar.
- **U3 — SETTLED 2026-09-01.** *The question was*: how many areas does this corpus evidence? The
  reference has 34 and the workshop had 5 in prose, so the answer could plausibly have been anywhere
  between. *Measured*: the landed taxonomy carries **7 tracks, 37 modules and 137 terms** for the
  one chapter that exists.
  *Recorded because it is easy to misread*: 37 against the reference's 34 is a coincidence of
  similar magnitude, **not** a target that was met. No area count was aimed at, and the closeness of
  the two numbers must not be cited as evidence of parity — one is a 34-area interview corpus and
  the other is a 37-module extraction from a single working session, and they are not comparable
  quantities.
- **U4 — Is an entailment model actually loadable on this host?** The platform's entailment verifier
  is selected when a model directory is configured, and the fallback is lexical. Whether a model is
  present and loads here has not been measured for this feature. *Settled by*: attempting the load
  and observing the result. It must report could-not-determine rather than degrading, and this is
  the exact behaviour to verify rather than assume — the platform's own code claims it, and a claim
  is not a measurement.
- **U5 — Do the 75 unlocatable words cluster or scatter?** 0.48% of words fall outside every segment
  span. If they scatter across inter-segment gaps, the segment-precision fallback is uninteresting.
  If they cluster in one region, that region has a segmentation problem worth knowing about before
  mentions are built on it. *Settled by*: plotting their time distribution against the measured
  silence spans.
