# Implementation Plan: Knowledge Areas & Bidirectional Deep Linking

**Branch**: `002-knowledge-areas-deep-linking` | **Date**: 2026-09-01 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/002-knowledge-areas-deep-linking/spec.md`

## Summary

Feature 001 built a substrate: a faithful transcript, 1,101 addressable passages with minted
identifiers, a two-leg search, a cross-reference graph and a media surface that can seek. It did not
build a curriculum. Measured, the result has **more** front-end code than the reference module and
**none** of its substance — 10 components against 8, 25 routes against 4, and 0 knowledge areas
against 34.

This feature builds the knowledge layer on top of that substrate, taking its **shape** from the
reference module and its **substance** from the workshop's own chapters. Concretely: promote the
five areas that exist today as prose into first-class entities, extract the rest of the taxonomy
from the corpus, author materials and short and long question sets against the workshop's own
passages, and wire every one of the four content kinds — transcript, recording, code, knowledge
base — into one bidirectional graph joined on the passage identifier. Then extend search to cover
all of it and to say *where* each hit occurs, reshape the front end from a media viewer into a
learning surface, and make the whole thing a repeatable pipeline that the next chapter runs
through unchanged.

The one place the workshop is designed to exceed its reference is provenance: the reference's 785
questions carry no source of any kind, and every workshop question must cite the passage that
teaches it.

## Technical Context

**Language/Version**: Go 1.26.2 for the backend, matching the workshop platform's existing module
and the reference module's. TypeScript with Angular 19.2 standalone components for the front end,
matching both. Python 3.14.6 and Bash for pipeline tooling, matching the existing pipeline.

**Primary Dependencies** — measured in the workshop's own module, not assumed:
`github.com/vasic-digital/passage` for identity, minting and resolution, consumed from
`submodules/passage`; `digital.vasic.rag` for hybrid fusion and reranking, consumed rather than
reimplemented; `modernc.org/sqlite` with FTS5 for the derived index; the platform's own
`pkg/entail` for entailment-based support verification. Export depends on a Markdown converter, an
HTML-to-PDF renderer and a Mermaid renderer — **all three resolve on this host, and all three
resolve into user-local directories rather than system ones**, which is a portability fact the
pipeline must detect rather than assume.

**Storage**: unchanged in kind. `curriculum/passages.jsonl` remains the source of truth — sorted,
byte-stable, one compact record per line. The derived SQLite database gains tables for the new
entities. No new database engine, no external store; the local-and-internal decision inherited from
001 makes a single machine the target.

**Testing**: Go's built-in testing for the backend; Karma and Jasmine for the front end; Playwright
for end-to-end; the platform's existing challenge banks and gate scripts for behavioural
assertions against the live binary. Every new gate owes a paired mutation proof.

**Target Platform**: Linux, single machine, local and internal only.

**Project Type**: web application — Go service plus Angular client — with an offline content
pipeline in front of it.

**Performance Goals**: the thresholds already established must survive the corpus growing, not be
renegotiated by it: suggestions at or below 200 ms p95, results at or below 2 s p95, and at least
90% top-five accuracy on a meaning-based benchmark over the new kinds.

**Constraints**: CPU-only inference. No generative model on this host. No content leaves the
machine. No server-side CI may be added anywhere in the fleet. The reference module is a private
repository and its content must not migrate.

### Premises checked before they were relied on

Each of these was assumed by an earlier draft of this plan or by the request, and each was measured.
Two did not hold and are recorded as corrections rather than quietly fixed.

**1. CORRECTED — word-level timings are not absent.** An earlier draft, and the first revision of
the specification, stated that the corpus carried nothing finer than a per-segment end time. The
registry half of that is true. But a per-chapter word sidecar holds **15,610 word records**, each
with a start, an end and a probability, of which 2,717 are flagged below the confidence threshold.
The claim is withdrawn in the specification under its own heading. *Consequence for design*:
mention precision is two-valued — word level where the sidecar covers the material, segment level
otherwise — and the design must carry both rather than collapsing them, because collapsing them is
how a segment-derived link comes to be displayed as though it were word-accurate.

**2. CORRECTED — the workshop is not starting from an empty taxonomy.** Five areas already exist,
as prose, under the workshop's training documentation, already using an adapted form of the
reference skeleton. What does not exist is any machine-readable form: no identifier, no schema, no
table, no endpoint. *Consequence for design*: the first move is promotion, not extraction. A design
that extracted afresh would produce a second set of areas competing with the first, and the
resulting merge would be exactly the kind of silent reconciliation the specification forbids.

**3. HELD — the passage identifier is stable enough to carry the graph.** The property the whole
feature rests on is measured, not asserted: identity attaches through an anchor key, an anchor that
is present but unknown to the registry is an **error** rather than a silent mint, and the paired
mutation proofs for content-derived identity, positional identity and unconditional minting are all
present and passing. This is why the specification requires the graph to be keyed on the identifier
and forbids keying it on time.

**4. HELD, and it is a defect rather than a capability — the match-offset field is always empty.**
A search hit already advertises a list of offset pairs, and the construction path sets it
unconditionally to the empty list; the snippet is generated with empty match delimiters, so even the
snippet carries no in-string marker. The relevance floor is likewise uncalibrated and the envelope
says so. *Consequence for design*: "say where it appears" is not a matter of surfacing something
that exists. Offsets must be produced, or the field must go — a field promising a position and never
carrying one is the blind-instrument shape the governing principles name.

**5. HELD — the export and OCR toolchain is fully present.** A Markdown converter, an HTML-to-PDF
renderer, an office suite, a PDF text extractor, an OCR engine and a Mermaid renderer all resolve.
*Consequence*: four-format export is buildable today, and the open question about on-screen content
is a scope question, not a capability question. The plan must not present it as blocked on tooling.

**6. HELD — there is no generative model on this host, and an entailment path exists anyway.** The
local inference host serves two models and both are embedding models. Separately, the platform
already implements entailment-based support verification behind a configured model directory, with
lexical overlap as the fallback, and refuses to silently degrade from one to the other.
*Consequence*: prose authorship at run time is not possible here, which is why it is an open
clarification; but the answer-to-question verification layer the specification requires is buildable
on an existing seam rather than from nothing.

## Constitution Check

*GATE: must pass before Phase 0 research. Re-check after Phase 1 design.*

Principles from `.specify/memory/constitution.md` v1.1.0, which extends the constitution submodule.

| Principle | Status | Basis |
|---|---|---|
| **Evidence-Based Claims** | **PASS** | Every figure in the specification's starting-state table names the command that re-derives it. Two premises were disproved by measurement and are **withdrawn explicitly** rather than replaced, one of them a claim this plan's own earlier draft made. The specification's counts are produced by enumeration, and the checklist prints the commands that reproduce them. |
| **Honest Instruments** | **PASS** | The three-valued contract is inherited and extended rather than re-litigated: SC-028 requires every new check to be driven into a could-not-determine condition and observed reporting the third state. FR-049 forbids an absent export toolchain from reporting success over empty output. FR-052 forbids a requested verifier that could not load from degrading silently to a weaker one. |
| **Governance Fidelity** | **PASS** | No carrier changes. The feature adds no submodule and no governance surface; it consumes the identity library already mounted at the project root. |
| **Isolation by Default** | **PASS** | Every success criterion that guards a silent failure names its paired mutation: SC-001, SC-004, SC-011, SC-012, SC-015b, SC-015d, SC-015e, SC-026 and SC-029a each state the mutation that must turn the check red. Assertions are behavioural — SC-013 explicitly refuses a row count as evidence that a kind is searchable, because a row count cannot distinguish a populated index from a populated table nobody queries. |
| **Comprehensive Documentation** | **PASS** | FR-050 requires the shipped limits document to name the open answering defects, and SC-026 fails when a recorded defect goes unnamed. The two withdrawn premises are recorded with their reasons rather than deleted. |
| **Environment Adaptability** | **PASS** | The export and OCR tooling resolves into user-local directories on this host, so the pipeline must detect it rather than assume a system path — the same class of defect that produced a Playwright-symlinked media tool in feature 001. Word-timing availability is likewise detected per chapter, not assumed corpus-wide. |
| **Quality Over Speed** | **PASS** | The identity, resolution and provenance components are marked for test-first development below, chosen where a defect would be silent rather than loud. |
| **§11.4.156 — no server-side CI** | **PASS** | FR-056 and SC-030 forbid adding any, and the fleet-wide gate already sweeps the submodules. |

**Gate result (initial): PROCEED**, with three open clarifications recorded in the specification.
None of them blocks Phase 0; each bounds a subset of Phase 1.

### What the gate does *not* certify

Stated because a gate table that reads as uniformly green invites over-reading. This table records
that the **design** satisfies the principles. It is not a claim that the platform's existing gates
pass today — none was run for this plan — and it is not a claim that the three clarifications have
safe defaults. Two of them do not: prose authorship has no safe default on a host with no
generative model, and the answering defect has no safe default at all, only an honest disclosure.

## Port, adapt, or newly design — the FR-003 register

FR-003 requires every element taken from the reference to be classified. The register is here
because it is a design artifact, and it is the primary defence against the failure mode the operator
named: copying what should have been authored.

| Element | Verdict | Reason |
|---|---|---|
| Curriculum → track → module → lesson hierarchy | **Ported as-is** | It is a sound learning hierarchy, already proven at 34 modules, and inventing a second one would fragment navigation. The area becomes the module level (D1). |
| Area document skeleton — seven ordered sections | **Adapted** | The sequence and intent are ported. Two sections are worded for interview preparation and are re-aimed at the workshop's subject. The workshop's existing prose areas already made this adaptation, which is evidence it is the right call rather than a guess. |
| Question record shape — prompt, choices, correct index, explanation, category, difficulty | **Adapted** | The schema is ported. One field is **added and made mandatory**: the citations. This is the single deliberate divergence from the reference and the reason the feature exists. |
| Question kinds — multiple choice, short answer, flashcard | **Ported as-is** | Three kinds cover recall, reasoning and drill. Nothing suggests a fourth. |
| Difficulty and category vocabulary | **Ported as-is** | An established closed vocabulary with a measured distribution across 785 items. Reusing it costs nothing and makes the two modules comparable. |
| Question-bank file layout — one file per area per kind, keyed by area code | **Adapted** | The layout is ported. The linkage is upgraded from a positional code to a minted identifier, because a positional code is exactly the identity form the platform's own identity contract forbids. |
| Derived flashcards from area Markdown headings | **Ported as-is** | A neat mechanism that turns authored material into drill without duplicating it. |
| Progress model — per item, with status, grade and streak, preserved across re-ingest | **Ported as-is** | Preserving learner history across a content rebuild is a decision the reference already got right, and it is easy to get wrong by accident. |
| Four-format export toolchain and its validator | **Ported as-is** | The design is sound and the tools are present. The workshop must exceed the reference on *coverage*, where the reference is measured at 25 of 34. |
| Diagram rendering from text source | **Ported as-is** | Text-sourced diagrams are reproducible; embedded binaries are not. |
| Behavioural challenge bank with a three-valued exit | **Ported as-is** | The workshop already has its own; the new endpoints extend it. |
| **Search** | **NOT ported** | The reference's search is a substring scan over three tables with a fixed limit, no ranking and no locus. The workshop's existing search — two legs, fused, with a real relevance model — already exceeds it on every axis. Recorded explicitly so the omission is not read as an oversight (FR-030a). |
| **Question and area content** | **NOT ported, and forbidden** | 34 finished area documents and 785 finished questions, about a different subject, in a private repository. Reusing them would be faster, would survive a superficial review, and would be worthless (FR-004, FR-004a). |
| Mention entity and the bidirectional graph | **Newly designed** | The reference has no notion of where a concept occurs, so there is nothing to port. This is the feature's own contribution. |
| Two-valued mention precision — word and segment | **Newly designed** | Follows from a property of the workshop's material that the reference does not have: a recording. |
| Repeatable chapter pipeline | **Adapted** | The workshop already contracts a chapter-addition procedure and ships its prompt; the script does not exist yet. The knowledge layer joins that path rather than starting a second one (FR-033e). |

## Project Structure

### Documentation (this feature)

```text
specs/002-knowledge-areas-deep-linking/
├── spec.md                       # Feature specification
├── plan.md                       # This file
├── research.md                   # Phase 0 consolidated findings and decisions
├── data-model.md                 # Phase 1 entities and the identity model
├── contracts/
│   ├── knowledge-graph.md        # Entities, identity, the link matrix, resolution
│   └── http-api-delta.md         # The endpoints this feature adds or changes
├── quickstart.md                 # Phase 1 validation guide
├── tasks.md                      # Phase 2 task breakdown
└── checklists/
    └── requirements.md           # Spec quality checklist
```

### Source Code

Paths are given by responsibility rather than reproduced as a full tree, because the tree already
exists and only its additions are this feature's business.

```text
submodules/passage/pkg/passage/        # EXISTING — identity, minting, anchors, resolution.
                                       # EXTENDED here to mint the new identifier kinds through the
                                       # same minter, never a second one.

workshop/platform/backend/
├── pkg/knowledge/                     # NEW — areas, terms, lessons, mentions, the graph and its
│                                      #       bidirectional traversal. Reusable: it depends on the
│                                      #       identity library, not on the curriculum.
├── pkg/assessment/                    # NEW — question model, banks, provenance enforcement,
│                                      #       short/long set construction, coverage measurement.
├── pkg/search/                        # EXISTING — extended with the new kinds, with locus, and
│                                      #       with the match offsets that are currently never
│                                      #       produced.
├── pkg/curriculum/                    # EXISTING — chapters and sections; gains the area relation.
├── pkg/answer/                        # EXISTING — gains the answer-to-question verification layer,
│                                      #       behind the same seam the entailment verifier uses.
├── internal/api/                      # EXISTING — new handlers for areas, terms and assessment.
├── internal/store/                    # EXISTING — persistence for the new entities and progress.
└── cmd/workshop-server/               # EXISTING — the single main package. Route registration
                                       #       only; no logic (the server-unity gate enforces this).

workshop/pipeline/
├── extract/                           # NEW — taxonomy derivation, term significance, promotion of
│                                      #       the existing prose areas, contradiction reporting.
├── mentions/                          # NEW — mention location, word-sidecar join, precision
│                                      #       labelling, segment-boundary spanning.
└── authoring/                         # NEW — materials assembly and question-set construction
                                       #       against the workshop's own passages.

workshop/curriculum/                   # EXISTING — passages.jsonl stays the source of truth.
                                       #       Gains taxonomy and assessment sources beside it,
                                       #       under the same byte-stability rules.

workshop/platform/frontend/src/app/features/
├── areas/                             # NEW — area list and area detail
├── practice/                          # NEW — the practice surface
├── progress/                          # NEW — progress across areas
├── plans/                             # NEW — study plan
├── chapters/ transcript/ search/      # EXISTING — subordinated under areas, not removed (D2)
└── ../styles/learning-kit/            # EXISTING — vendored kit; the workshop's identity comes
                                       #       from token values, never from forking this

workshop/platform/gates/               # EXISTING — route manifest and server-unity verifier;
                                       #       every new endpoint gets a row (FR-059)
workshop/platform/qa/challenges/       # EXISTING — behavioural banks; new banks join here
workshop/docs/                         # EXISTING — limits, quickstart, manual, FAQ, the
                                       #       add-a-chapter prompt this feature extends
workshop/evidence/                     # EXISTING — machine evidence, retained with its commit
```

**Structure Decision**: the knowledge layer lands in `pkg/`, not `internal/`, because the
decoupling rules already established for this platform forbid `internal/` for anything reusable —
Go's `internal/` is importable only from within its own module, so it forecloses reuse by language
rule rather than by style. `pkg/knowledge` in particular knows about passages and identifiers and
nothing about curricula, which is what makes it testable with no curriculum present.

The pipeline additions sit beside the existing pipeline stages rather than inside them, so that the
chapter-addition procedure gains steps rather than being rewritten.

## Execution Strategy

### Test-first components

Marked `[TDD]` in the task breakdown. Chosen where a defect would be **silent** rather than loud —
the same rule feature 001 applied, and the same reason: these are the failures that keep rendering.

- [ ] **Identifier minting for the new entity kinds.** Areas, terms, lesson sections, questions and
      mentions must mint through the existing minter and inherit its proven properties. A second
      minting path, or a content-derived identifier slipped in for convenience, would break link
      survival with no visible symptom until a correction lands.
- [ ] **Bidirectional traversal.** A one-way link renders identically to a two-way one from the
      forward direction. The reverse traversal is the only thing that distinguishes them, so it is
      tested before it is built.
- [ ] **Mention precision labelling.** A segment-derived mention displayed as word-accurate is a
      confident wrong answer about where something was said. The two precisions must be
      distinguishable in the type, not by convention.
- [ ] **Question provenance enforcement.** A question served without a resolving citation converts
      the feature's central guarantee into a claim. Withholding must be the default path, not an
      error path.
- [ ] **Search locus and match offsets.** The field exists and is always empty today; the tests must
      assert offsets are present and correct before the implementation is written, or the same
      empty-field outcome is the likely result a second time.
- [ ] **Redaction propagation to the new artifact kinds.** Redaction that stops at one layer looks
      complete from that layer. Every new kind needs its own assertion.
- [ ] **Taxonomy merge on a new chapter.** Preserving identifiers while absorbing new evidence is
      the operation that makes the pipeline repeatable, and getting it wrong silently re-mints.
- [ ] **Question coverage measurement.** The measurement is the criterion — a coverage figure
      computed wrongly is worse than no figure, because it will be believed.

### Parallel work

Marked `[SUBAGENT]`. These share no files.

- [ ] Taxonomy extraction and the front-end learning surface — different languages, different
      directories, joined only by the knowledge contract.
- [ ] Question authoring and the export pipeline — the export consumes documents, not the process
      that wrote them.
- [ ] The documentation set and the behavioural challenge banks.

### Human checkpoints

The agent stops and waits for explicit approval at each.

1. **After Phase 0** — before committing to a taxonomy shape and a mention model, because both are
   expensive to reverse once links exist.
2. **After the promotion of the existing prose areas** — this is where the workshop's own five areas
   are reconciled with what extraction derives, and a wrong merge is a wrong curriculum.
3. **After the first area's materials** — the authored substance is reviewed before the pattern is
   applied to every other area.
4. **After each user story** — checked against that story's acceptance scenarios.
5. **Before the pipeline is declared repeatable** — the synthetic-chapter run is observed, not
   reported.

### Review gates

Marked `[REVIEW]`.

- [ ] **The knowledge contract** — identity, the link matrix, resolution and precision. Everything
      else depends on its shape; review before anything consumes it.
- [ ] **The three clarifications** — each must be answered by the operator before the work it bounds
      begins. Prose authorship bounds materials; on-screen content bounds ingestion; the answering
      defect bounds any generation over the new material.
- [ ] **Every area's publication review** — a standing gate, not a one-off. Publication is blocked
      on it by FR-016.
- [ ] **The content boundary, in both directions** — before anything is published or exported.

## Complexity Tracking

| Violation | Why needed | Simpler alternative rejected because |
|---|---|---|
| A mention entity carrying two different precisions rather than one | The material genuinely has two: word timings exist for 15,610 words in a sidecar, and only segment timings exist in the registry, with 17.4% of words flagged below the confidence threshold. | Collapsing to segment precision throws away accuracy the data already contains, and would have been the design had the withdrawn premise stood. Collapsing to word precision asserts accuracy the data does not have wherever the sidecar does not reach. Either collapse is a confident wrong answer about where something was said, which is the one failure the deep-linking feature cannot afford. |
| Promoting five existing prose areas rather than extracting the taxonomy fresh | The five exist, are already in the reference's skeleton, and represent human judgement about what the workshop teaches. | A fresh extraction is simpler to build and would produce a second set of areas competing with the first. Reconciling them afterwards is the same work, done later, with links already pointing at both — and the reconciliation would happen silently, which the specification forbids. |
| Adding a mandatory citation field to a ported question schema | Provenance is the entire justification for this feature over its reference. | Making it optional is one word simpler and destroys the guarantee: an optional field is absent in exactly the cases that matter, and a learner cannot tell a question with provenance from one without. |
