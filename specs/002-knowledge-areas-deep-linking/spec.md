# Feature Specification: Knowledge Areas & Bidirectional Deep Linking

**Feature Branch**: `002-knowledge-areas-deep-linking`

**Created**: 2026-09-01

**Status**: Draft

**Input**: User description:

> *"No knowledge covered - areas - like we have in AI Curriculum (ai_interviewing)! We have to
> extract all terms and areas and for them all to create same materials kinds like ai_interviewing
> has! All areas and terms mentioned in transcript and video MUST BE linked to these knowledge
> resources - areas with chapters and quizzes! Extend this properly! Use the same technology we
> have used to create UI / UX for ai_interviewing! Design unique look and feel using OpenDesign…
> Search MUST be able to search all contents - areas with chapters, quizzes, everything from the
> interview and to link exactly where they appear! In videos we MUST BE linked to exact times, and
> from whole transcripts to jump to whole areas, proper chapters and part of the chapters (or
> quizzes / tests) where content is mentioned and where it appears!"*

Amended the same day by a second operator directive, which reframes the work rather than adding
to it:

> *"Use ai_interviewing as reference and base on top of which we shall build our workshop! Do not
> clone or copy it but use as the reference / port it properly (parts we may need)! Current
> workshop is extremely poorly made!"*

And amended again, with the two corrections that decide how the work is judged:

> *"Do not just pickup materials from ai_interviewing but create the materials which are following
> our chapters (chapter 01 we have currently), and then as we are adding more chapters after they
> are processed we MUST extract all areas and themes which will be fully covered through added
> areas and chapters with exhaustive long and short tests / quizzes! Everything MUST BE
> cross-referenced, searchable by meaning and context and fully connected! Transcripts and video
> content, codebases, knowledge base - areas with chapters, quizzes / tests - all of it!"*

---

## Why this feature exists: the workshop is the wrong kind of artefact

This framing is stated first because it is the reason the feature is not an add-on.

Measured 2026-09-01, comparing the reference module with what feature 001 produced:

| Dimension | `ai_interviewing` (reference) | `workshop` (today) |
|---|---|---|
| Frontend components | 8 | **10** |
| Frontend lines of code | 2,690 | **4,566** |
| Backend API routes | 4 | **25** |
| Content files | 68, plus a taxonomy of areas | **8** |
| Knowledge areas with materials | 34 area documents | **0** |
| Questions with source provenance | 0 of ~68 files | n/a — no questions exist |

The workshop has **more** code and almost none of the substance. The component vocabulary shows
why:

- `ai_interviewing`: **module · practice · progress · plans** — a *learning platform*.
- `workshop`: **chapter-list · transcript · recording-player · crossrefs** — a *media viewer*.

The workshop is not badly built. It is an excellent document browser over a recording, when what
is wanted is a curriculum a person learns from. Feature 001 delivered the substrate — a faithful
transcript, 1,101 addressable passages, a working search and a cross-reference graph. Feature 002
delivers the missing half: the knowledge layer that turns that substrate into a course.

**And it does one thing the reference cannot do at all.** The reference's questions carry a prompt
and an answer and nothing else — no link to any source. The workshop's 1,101 passages each carry a
minted identifier that has been *measured* to survive both a content correction and a structural
insertion. So every workshop question can cite the exact moment that teaches it, and a learner can
jump from a quiz question to that moment in the recording and back. That is the game-changer, and
it is the operator's *"linked to exact times … jump to whole areas, proper chapters and part of the
chapters (or quizzes / tests)"* stated as a mechanism.

## Context: Verified Starting State

Measured on 2026-09-01. Every figure below is re-derivable by the command in the right-hand
column; none is quoted from a document. Requirements later in this specification are only
meaningful against these values.

| Fact | Measured value | Re-derive with |
|---|---|---|
| Platform reachable | live on the LAN, HTTP 200 on `/api/health` | `curl -s -o /dev/null -w '%{http_code}' http://<host>:<port>/api/health` |
| Passages in the corpus | **1,101** | count records in the passage registry |
| — transcript segments | **1,055** | group the registry by `kind` |
| — document sections | **44** | ” |
| — code passages | **2** | ” |
| Passages flagged uncertain | **267** (24.2%) | count `uncertain == true` |
| Distinct scopes (chapters) present | **1** | count distinct `scope` |
| Passage identifier | minted ULID, persisted, never positional, never content-derived | registry `pid` field |
| Identifier survival, measured | 1,101 / 1,101 preserved across a content correction and a section insertion | replay of the 001 experiment |
| Segment timing granularity | median segment **6.74 s**, p95 **10.78 s**, max **20.22 s**, mean 6.56 s over 1,055 segments spanning 6,924.10 s | derive per-segment spans from the registry |
| Word-level timings | **present, in a per-chapter sidecar — not in the registry.** 15,610 word records, each carrying a start, an end and a probability; 2,717 (17.4%) flagged below the confidence threshold | read the chapter's word sidecar; inspect `counts` |
| Indexed content kinds declared by search | `transcript_segment`, `doc_section`, `code`, `diagram` — but the corpus holds **0** diagram passages, so one declared kind is empty | `/api/search` response `corpus.indexed_kinds`; group the registry by `kind` |
| Positional match offsets in a search hit | the hit carries a `highlights` field typed as a list of offset pairs and it is **unconditionally set to empty**; the snippet is generated with empty match delimiters. **No offsets are produced anywhere today** | inspect the hit-construction path and any live `/api/search` response |
| Relevance floor | **uncalibrated** — the envelope reports `floor_calibrated: false` and nothing is demoted | any `/api/search` response |
| Media reachability declared by search | *"transcripts and captions only"* | `/api/search` response, `corpus.media_reached_via` |
| Endpoints for areas / terms / quizzes | **absent** — `/api/areas`, `/api/terms`, `/api/quizzes` all return 404 | probe each path |
| Server behaviour suite | **25 PASS / 4 DEBT**; the 4 are permanent negative-route assertions, driven from a route manifest | the server-unity verifier |
| Existing workshop taxonomy | **5 areas — as prose only.** Area documents exist under the workshop's training documentation, ids `01`–`05`, already using an adapted form of the reference skeleton. There is **no machine-readable representation**: no identifiers, no schema, no database table, no endpoint | list the training area documents; search the platform for an area type or table |
| Existing workshop term inventory | **none.** No glossary, no term table, no term field anywhere in the platform or the curriculum | search the platform and curriculum for a term entity |
| Existing workshop assessment model | **none.** Quiz styling is present in the vendored design kit; the concept is not — no data model, no endpoint, no component | search for a question or quiz entity |
| Extracted taxonomy (landed 2026-09-01, during drafting) | **7 tracks, 37 modules, 137 terms** for the one chapter; linkage for all 1,101 passages; a reverse index keyed by module, term and track | count the records in the chapter's knowledge directory |
| Extracted taxonomy coverage | **884 of 1,055 transcript passages (83.79%)** and **14,290 of 15,610 words (91.54%)**; every uncovered passage carries a stated reason; 211 of the 267 uncertain passages are covered | read the coverage record |
| Chapter sections | **already modelled**, and derived rather than authored: transcript sections carry a rule and a cross-check; the chapter's document sections number **46** | the chapter endpoint's `sections`; the document section sidecar |
| Reference area skeleton | **7 level-2 headings in a fixed order**, present in 34/34 area documents (one document substitutes two alternatives for one heading) | count headings across the reference area documents |
| Reference area corpus | **34** area documents in Markdown, plus **74 diagrams** rendered to 3 formats each from Mermaid source | count `.md` files and diagram files in the reference area directory |
| Reference four-format coverage | **25 of 34** areas carry all four formats — **9 are Markdown only** | file-existence matrix over `md`/`html`/`docx`/`pdf` |
| Reference question bank | **312 multiple-choice + 473 short-answer = 785 authored items** across 34 files each, linked to an area by a code rather than by a key | count items in the reference question banks |
| Reference question provenance | **0 of 785.** The question record has fields for prompt, choices, answer, explanation, category and difficulty — and no source field of any kind | reference question type definition and bank schema |
| Reference search | a substring scan over three tables with a fixed result limit, **no ranking and no locus**; its hit carries a type, an area id, a title and a snippet | reference search implementation |
| Generative model on this host | **none.** The local inference host serves two models, both embedding models | list the local model store |
| Entailment path | an entailment-based support verifier **exists in the platform** and is selected when a model directory is configured; the fallback is lexical overlap with a configurable floor | inspect the answering verifier wiring |
| Export and OCR toolchain | **all present on this host**: a Markdown converter, an HTML-to-PDF renderer, an office suite, a PDF text extractor, an OCR engine and a Mermaid renderer all resolve on `PATH` | `command -v` each |

### A claim this document made and now withdraws

An earlier revision of this table stated **"Word-level timings: absent."** That was **wrong** and is
withdrawn rather than quietly corrected, because the rules governing this repository require a
retracted figure to be retracted visibly.

What was actually measured: the *passage registry* carries a per-segment end time and nothing
finer — that half was right. But a **per-chapter word sidecar exists** alongside it and holds
15,610 word records with individual start and end times. The error was to infer the corpus from
one file. Its consequence would have been material: the specification would have committed to
segment-level precision as a ceiling when word-level precision is reachable by joining the
sidecar on time.

The corrected position, which the requirements below are written against: **precision is
word-level where the word sidecar covers the material and segment-level otherwise**, the two are
not interchangeable, and every link must state which one it used. 17.4% of words are flagged below
the confidence threshold, so word-level precision is *available*, not *uniformly trustworthy*.

### Three facts that are load-bearing and easy to misread

1. **The workshop is not starting from zero, and not starting from data either.** Five areas
   already exist as prose, in an adapted form of the reference skeleton. What does not exist is any
   machine-readable form of them — no identifier, no schema, no endpoint. The work is to promote
   prose into a first-class entity and then extend it, not to invent a taxonomy against an empty
   page and not to write documents that already exist.
2. **The `highlights` field is a measured lie waiting to happen.** A search hit already advertises a
   list of match offsets, and that list is unconditionally empty. A consumer reading the schema
   would reasonably conclude offsets are available. This is exactly the shape of defect the
   governing rules call a blind instrument, and the "say *where* it appears" requirement lands
   directly on it.
3. **There is no generative model on this host.** Anything requiring new prose to be written at run
   time cannot execute here today. This is why prose authorship is an open clarification rather
   than an assumption. Note the contrast with the export and OCR toolchain, which *is* fully
   present — so the second clarification is a question about scope, not about capability.

## Clarifications

### Session 2026-09-01

Three questions are left open because each genuinely changes the size and the risk of the work and
none can be settled from evidence in the tree. Everything else the description left unstated was
decided, and those decisions are recorded under **Assumptions** and **Resolved Decisions** with the
reasoning, per the operator's standing instruction to take the safest, most stable, risk-free
option whenever a choice is forced.

- **[NEEDS CLARIFICATION: prose authorship]** Area materials in the reference are written prose —
  *"Why this matters"*, *"Core concepts in one page"*, model answers. Three ways to produce the
  workshop's equivalent differ by an order of magnitude in scope and in risk, and the host makes
  the difference concrete rather than theoretical, because **it has no generative model**:
  **(a) extractive only** — an area document is assembled entirely from cited passages and fixed
  templated connective text, so every sentence is traceable and nothing is invented, but the prose
  reads as an anthology rather than a lesson; **(b) agent-authored at build time** — a human or an
  agent working in this repository writes the prose once, cites passages for every claim, and the
  platform never generates text at run time; **(c) platform-generated at run time** — the platform
  drafts area prose itself, which requires a generative model to be installed and brings the
  fabrication risk this repository has already measured. *Scope impact*: (a) needs no model and no
  review workflow; (b) needs a review-and-publication gate; (c) needs a model, a grounding
  pipeline, and a fabrication measurement before anything may be published.
- **[NEEDS CLARIFICATION: what "in videos" covers]** The description requires terms mentioned *"in
  transcript and video"* to be linked to *"exact times"*. The corpus contains only what was
  **spoken**. Text that appeared **on screen** — the substance of a screen recording — is not
  transcribed and is not in the registry, and the one declared content kind that could hold it is
  measured empty. Linking on-screen occurrences would mean optical character recognition across the
  whole recording, producing a new passage kind, new timings and a new accuracy obligation of its
  own. *Scope impact*: spoken-only is a linking feature over data that already exists;
  spoken-plus-on-screen is a second ingestion pipeline that must be measured before it can be
  trusted. **This is a question about scope, not about capability** — the OCR engine resolves on
  this host, so the answer is not forced by the environment.
- **[NEEDS CLARIFICATION: answering over the new material]** Question answering over the workshop
  corpus has a **known, measured, unclosed defect**: on the unanswerable set, 3 of 33 questions were
  answered rather than declined, and separately, *extractive evasion* is undefended — a passage
  fragment that is topically related but does not answer the question passes every existing check,
  because every layer verifies *claim against passage* and no layer verifies *claim against
  question*. Extending answering across areas, lessons and quiz questions multiplies the surface
  on which that defect can appear. *Scope impact*: closing it means building a claim-to-question
  relevance verifier and measuring it — and on this host, an entailment-class model would have to be
  installed first; leaving it open means the feature ships with the defect stated in its limits
  document and answering held to retrieval over the new kinds without generating answers about them.
  **The one option that is not available is to describe it as solved.**

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The workshop teaches areas, not just chapters (Priority: P1)

A learner opens the workshop and sees the knowledge it covers laid out as areas — the way the
reference module lays out its taxonomy — rather than as a single recording with a transcript
underneath. They pick an area, read its materials, and every claim in those materials points back
to the moment in the workshop where it was actually taught.

**Why this priority**: this is the missing substance. Without it the platform remains a media
viewer, which the starting-state table measures rather than asserts: 0 areas, 0 area materials, and
`/api/areas` returning 404. Every later story navigates to, from, or across areas, so nothing else
can exist first.

**Independent Test**: deliver only the taxonomy and the area documents. A reviewer opens the area
list, picks any five areas at random, and confirms each has materials in the reference skeleton and
that every substantive claim carries a citation that resolves to a real passage. Value is delivered
even if no new interface, search or assessment is ever built.

**Acceptance Scenarios**:

1. **Given** the indexed corpus, **When** taxonomy extraction is run, **Then** a set of knowledge
   areas and terms is produced in which every area and every term is evidenced by at least one
   passage, and no area or term exists without evidence.
2. **Given** the extracted taxonomy, **When** a reviewer inspects any area, **Then** it carries a
   materials document following the same section skeleton the reference module uses.
3. **Given** an area's materials, **When** a reviewer examines any substantive claim, **Then** it
   carries at least one passage citation that resolves, or it is visibly marked as editorial
   framing rather than as workshop content.
4. **Given** extraction is run a second time on unchanged content, **When** it completes,
   **Then** the taxonomy is identical and no identifier has changed.
5. **Given** a passage that no area claims, **When** the extraction completes, **Then** that
   passage is explicitly classified as unattached with a stated reason, rather than silently
   dropped from the accounting.
6. **Given** a term the extractor recognised with low confidence, **When** it is published,
   **Then** it is marked uncertain and is not presented as a confidently identified term.

---

### User Story 2 - Go from any point to every related point, in both directions (Priority: P2)

A learner watching the recording pauses at a moment and jumps straight to the area that moment
belongs to, and from there to the lesson section and to the questions that test it. Later they come
at it from the other end: they open a quiz question and jump to the exact moment in the recording
that teaches its answer, then come back without losing their place.

**Why this priority**: this is the heart of the operator's description and the mechanism every
other story depends on. It is second only because it needs areas to link to. Once it exists, search
results, quizzes and the learning surface all navigate through it rather than each inventing its own
notion of "where".

**Independent Test**: with the taxonomy present, enumerate every recorded link, traverse it forward
and then backward, and confirm the reverse traversal returns the origin. No interface is required —
this is testable entirely through the platform's own interfaces.

**Acceptance Scenarios**:

1. **Given** a transcript moment, **When** a learner asks what it belongs to, **Then** the areas,
   the chapter section and the questions attached to it are returned, each reachable in one step.
2. **Given** an area, **When** a learner asks where it appears, **Then** every passage that
   evidences it is returned, each with the position at which it occurs.
3. **Given** a question, **When** a learner follows its citation, **Then** playback lands inside the
   time span of the cited passage.
4. **Given** any recorded link, **When** it is traversed in reverse, **Then** the origin is
   returned; no link is one-way.
5. **Given** a passage whose text is corrected and the content re-indexed, **When** every link is
   re-traversed, **Then** all of them still resolve to the same targets.
6. **Given** a link whose target no longer exists, **When** it is followed, **Then** it fails
   loudly with a stated reason, and is never quietly re-pointed at a different target.
7. **Given** a chain of related material that forms a cycle, **When** a learner traverses it,
   **Then** they are not trapped; the traversal terminates.
8. **Given** a passage that has been redacted, **When** any link to it is followed, **Then** the
   redaction is honoured at every layer, not merely in the transcript view.

---

### User Story 3 - Search everything, and be told exactly where it is (Priority: P3)

A learner searches once and gets results drawn from areas, lesson sections, quiz questions, the
transcript, the written documents, the code and the diagrams — and each result says *where* it
occurs: which area and chapter section contain it, and at what point within them.

**Why this priority**: search already works over the 001 corpus, so this story extends a proven
capability rather than creating one. It is third because the new content kinds must exist before
they can be indexed.

**Independent Test**: with the new kinds indexed, run a benchmark of meaning-based queries whose
expected targets are known in advance and confirm both that the expected item is returned and that
every returned hit carries a locus that resolves.

**Acceptance Scenarios**:

1. **Given** all content kinds are indexed, **When** a learner searches, **Then** results may come
   from any kind, and a kind with content but no index entries is a failure rather than an empty
   category.
2. **Given** a search result, **When** it is displayed, **Then** it states the unit that contains it
   and the position within that unit — a time span where the source is media-backed, a text span
   otherwise.
3. **Given** a learner types the first characters of an area or term name, **When** suggestions
   appear, **Then** areas and terms are offered alongside the existing suggestions.
4. **Given** a learner wants to narrow results, **When** they filter by area or by kind, **Then**
   only matching results are returned and the filter is reflected in what is shown.
5. **Given** the search backend is degraded or unavailable, **When** a learner searches, **Then**
   the system says it could not answer, and does not render the failure as "no results".
6. **Given** the corpus has grown with the new kinds, **When** latency is measured, **Then** it
   still meets the thresholds established for the existing corpus.

---

### User Story 4 - Practice, and see exactly where each answer comes from (Priority: P4)

A learner finishes an area and practises it: multiple-choice questions, short-answer questions and
flashcards. Every question shows where its answer comes from, and a single action takes the learner
to that moment in the recording and back to the question afterwards.

**Why this priority**: this is where the workshop exceeds its reference rather than catching up to
it, so it is worth building deliberately and on top of proven linking rather than early and
fragile. It depends on areas (US1) and on the link mechanism (US2).

**Independent Test**: enumerate every served question, resolve every citation it carries, and
confirm none is unresolvable; then, for questions citing a transcript segment, follow the citation
and confirm playback lands inside that segment's time span.

**Acceptance Scenarios**:

1. **Given** an area, **When** a learner opens its practice set, **Then** questions of the reference
   module's kinds are available — multiple choice, short answer and flashcard.
2. **Given** any served question, **When** its provenance is inspected, **Then** it carries at least
   one passage citation that resolves.
3. **Given** a question whose citation cannot be resolved, **When** the practice set is assembled,
   **Then** that question is withheld rather than served without provenance.
4. **Given** a question citing a transcript segment, **When** the learner follows the citation,
   **Then** playback lands inside that segment, and returning restores the question and the
   learner's progress.
5. **Given** a model answer that was assembled rather than authored, **When** it is shown, **Then**
   it is marked as such, and is not presented as a verified answer.
6. **Given** a learner completes practice, **When** they return later, **Then** their progress per
   area and per question set is preserved.

---

### User Story 5 - A learning surface, with its own visual identity (Priority: P5)

A learner uses an interface built for learning — an area view, a practice view, a progress view and
a study-plan view — rather than a file browser with a video in it. It looks like the workshop's own
product, not like a copy of the reference module.

**Why this priority**: the surface is the vehicle, not the cargo. Stories 1 to 4 are all testable
through the platform's interfaces without it, and the workshop already has a working, if
mis-shaped, front end. Reshaping it last means it is reshaped around behaviour that has already been
proven.

**Independent Test**: open each new view and complete its primary task using only the keyboard, then
run an accessibility audit and a design-token conformance check against the whole surface.

**Acceptance Scenarios**:

1. **Given** the platform is running, **When** a learner opens it, **Then** the entry point is the
   knowledge the workshop covers, with the recording reachable from within an area rather than being
   the top-level object.
2. **Given** an area, **When** a learner opens it, **Then** they can read it, practise it, see their
   progress in it, and reach every linked point from it.
3. **Given** the existing chapter, transcript, recording and cross-reference views, **When** the new
   surface is delivered, **Then** those capabilities remain reachable, subordinated to the area they
   belong to rather than removed.
4. **Given** any new view, **When** its styling is inspected, **Then** every colour, spacing and
   typographic value resolves through the shared design-token contract, and no brand value is
   written literally.
5. **Given** any new view, **When** an accessibility audit is run, **Then** it reports no Level A or
   Level AA violation, and every deep link is reachable and operable by keyboard alone.
6. **Given** a learner is midway through an area, **When** they follow a deep link out and come
   back, **Then** their position is restored.

---

### User Story 6 - Take an area away with you, in four formats (Priority: P6)

A learner exports an area and gets the same set of document formats the reference module ships:
Markdown, HTML, Word and PDF — with the citations preserved.

**Why this priority**: last because it is a transformation of material that must exist and be
correct first. Exporting wrong material in four formats is four times the damage.

**Independent Test**: run the export over every published area and check the format matrix is
complete, then re-run it and confirm the extracted text of each regenerated document is unchanged.

**Acceptance Scenarios**:

1. **Given** a published area, **When** export is run, **Then** all four formats are produced.
2. **Given** the export has been run, **When** an area is exported again from unchanged source,
   **Then** the extracted text of each output is identical to the previous run.
3. **Given** an exported document, **When** a reader inspects a cited claim, **Then** the citation
   is present and identifies the passage it came from.
4. **Given** an area that has not passed its publication review, **When** export is run, **Then**
   that area is not exported and the omission is reported.
5. **Given** a diagram belonging to an area, **When** the area is exported, **Then** the diagram is
   rendered into each format rather than being dropped.

---

### User Story 7 - Add the next chapter and get the whole knowledge layer (Priority: P7)

A maintainer finishes recording Chapter 2. They run one documented procedure. The chapter arrives
transcribed, its passages minted, its areas extracted and merged into the existing taxonomy, its
materials written, its short and long question sets built, everything cross-referenced, indexed and
deep-linked — with no hand-assembly of structure and no code change.

**Why this priority**: last, because it validates every earlier story at once. It is not the least
important — it is arguably the point of the whole feature, since a curriculum that cannot grow is a
document. But it can only be *tested* once the things it must produce are known to be producible,
so it is sequenced where it can actually be proven rather than where it feels most important.

**Independent Test**: run the documented procedure against a small synthetic chapter and confirm
that every output appears and that the diff contains no hand-created structural file.

**Acceptance Scenarios**:

1. **Given** a new chapter's raw material placed where the procedure specifies, **When** the
   procedure runs, **Then** the chapter emerges transcribed, with minted passage identifiers,
   extracted areas, authored materials, short and long question sets, cross-references, index
   entries and deep links.
2. **Given** an existing taxonomy, **When** a new chapter is processed, **Then** established areas
   keep their identifiers and gain evidence, newly evidenced areas are added, and a contradiction
   between new evidence and an existing area is reported rather than silently resolved.
3. **Given** the procedure is run twice on the same chapter, **When** the second run completes,
   **Then** nothing has changed and nothing is duplicated.
4. **Given** a chapter whose material is incomplete, **When** the procedure runs, **Then** it names
   exactly what is missing and publishes nothing.
5. **Given** two chapters are present, **When** a learner searches or browses an area, **Then**
   results and evidence span both chapters, and no area is confined to the chapter it first
   appeared in.
6. **Given** the procedure exists, **When** a maintainer looks for how to add a chapter, **Then**
   there is exactly one documented way to do it.

---

### Edge Cases

- **A term appears in a passage that has been redacted.** The term keeps its evidence count only if
  another passage supports it; otherwise the term itself must disappear from the published
  taxonomy, not merely lose one link. Redaction that stops at the display layer is the failure mode
  this repository has already contracted against.
- **A term is a common word.** "Test", "run", "build" occur constantly. An extractor that treats
  frequency as significance produces a taxonomy of stopwords. Significance must be demonstrated, and
  the demonstration must be recorded so it can be challenged.
- **An area is evidenced only by passages flagged uncertain.** 267 of 1,101 passages are uncertain.
  An area resting entirely on uncertain evidence must be marked as such and must not read like a
  confident one.
- **A mention spans a segment boundary.** A term spoken across the seam between two segments belongs
  to both; attaching it to one silently loses half its evidence.
- **Two areas overlap almost completely.** Near-duplicate areas fragment the taxonomy and split
  their own evidence. Merging is a decision with consequences for every link already pointing at
  either one.
- **A question's only citation is corrected after the question is written.** The citation must
  survive the correction; that is exactly what the minted identifier exists for, and it must be
  proven, not assumed.
- **A question cites a passage in a different chapter than the area it belongs to.** Legitimate once
  more than one chapter exists; the model must not assume an area lives in one chapter.
- **The export toolchain is not installed.** Four-format export depends on document conversion
  tooling. Its absence must report that the export could not be performed — never that it was
  performed and produced nothing.
- **A learner follows a deep link into a passage whose time span exceeds twenty seconds.** The
  measured maximum is 20.22 s. Landing "inside the segment" is the guarantee; landing on the word is
  not, and the interface must not imply the precision it does not have.
- **The taxonomy is re-extracted while the index is being served.** Half-written taxonomies must
  never be served; a stale but coherent taxonomy is preferable to an incoherent one.
- **A search hit's containing unit was deleted between indexing and display.** The locus must fail
  loudly rather than render a link into nothing.
- **An area has zero questions.** Presenting an empty practice set as though practice exists is a
  small lie that erodes trust in every other count on the page.
- **A screen-reader user follows a deep link into the recording.** The jump changes context; the
  change must be announced, and returning must restore focus, not dump the user at the top of the
  page.

## Requirements *(mandatory)*

### Functional Requirements

**Ported knowledge model — port, do not clone**

- **FR-001**: The workshop MUST adopt the reference module's learning hierarchy — curriculum,
  track, module, lesson — as its curriculum spine, taking the shape from the reference rather than
  inventing a second one.
- **FR-002**: The mapping between that hierarchy and the workshop's existing concepts — chapters,
  passages, cross-references — MUST be defined explicitly and MUST NOT create a parallel hierarchy
  that covers the same ground. A knowledge area is the workshop's module; a chapter is a *source*
  of material for areas, not a level of the hierarchy above them.
- **FR-003**: For every element taken from the reference, the design MUST record which of three it
  is — **ported as-is**, **adapted**, or **newly designed** — and why. An element recorded as
  "ported as-is" that in fact differs is a defect.
- **FR-004**: **The reference supplies shape, never substance.** No content, wording, fixture,
  question, model answer or asset MAY be copied from the reference module into the workshop. What
  is reused is structure: the hierarchy, the document skeleton, the question-bank schema, the
  export toolchain's design. What is authored fresh is everything a reader actually reads. Every
  workshop area, lesson and question MUST be derived from the workshop's own chapters and MUST be
  evidenced against the workshop's own passages.
  *Why this is stated so bluntly*: the reference holds 785 ready-made questions and 34 finished area
  documents about a different subject entirely. Reusing them would be faster than authoring, would
  pass a superficial review because the documents look right, and would be worthless — the workshop
  would ship a curriculum about interview preparation while claiming to teach its own material. It
  is the single easiest way for this feature to go wrong.
- **FR-004a**: The reference module is a **separate private repository**. Its content MUST NOT
  migrate into the workshop under any justification, including as a placeholder, a fixture, a
  template with the words left in, or an example. This is a content boundary, not a style
  preference, and it is enforced by the same check that keeps workshop content out of public
  repositories.
- **FR-005**: The normative definition of the ported model MUST live in a single knowledge-model
  contract document, and this specification and every downstream artifact MUST reference it rather
  than restate it, so that the two cannot drift.

**Taxonomy extraction**

- **FR-006**: The system MUST derive its knowledge areas and terms from the indexed corpus, not from
  a hand-written list, and MUST record how each was derived.
- **FR-007**: Every area and every term MUST carry a persisted identifier assigned once at creation,
  neither positional nor derived from its own text, following the same identity discipline the
  passage identifier already follows.
- **FR-008**: Every published area and every published term MUST be evidenced by at least one
  passage. An area or term with no evidencing passage MUST NOT be published.
- **FR-008a**: The five areas that already exist as prose in the workshop's training documentation
  MUST be **promoted** into the machine-readable model — given identifiers, evidenced against the
  corpus and reconciled with what extraction derives — rather than being ignored, duplicated, or
  overwritten by a fresh extraction. Where extraction and the existing prose disagree about what an
  area is, the disagreement MUST be surfaced for a decision, not silently resolved in either
  direction.
- **FR-009**: Extraction MUST be idempotent: a second run over unchanged content MUST produce an
  identical taxonomy and MUST change no identifier.
- **FR-010**: Extraction MUST account for every passage — each is either attached to at least one
  area or explicitly classified as unattached with a stated reason. Silent omission is forbidden.
- **FR-011**: The system MUST distinguish a term identified with confidence from one identified
  with low confidence, MUST mark the latter, and MUST NOT present it as the former.
- **FR-012**: An area evidenced only by passages flagged uncertain MUST be marked as resting on
  uncertain evidence.
- **FR-013**: Term significance MUST be demonstrated by a recorded, re-derivable measure rather than
  asserted, and raw frequency alone MUST NOT be that measure.

**Area materials**

- **FR-014**: Every published area MUST carry a materials document following the reference module's
  section skeleton — measured as seven level-2 sections in a fixed order: why the area matters, its
  core concepts on one page, questions and model answers subdivided per topic, real-world challenge
  scenarios, red flags and strong signals, how the area maps back to the workshop, and sources. The
  two sections whose reference wording is specific to interviewing MUST be **adapted** to the
  workshop's subject rather than carried over verbatim, and that adaptation MUST be recorded under
  FR-003.
- **FR-014a**: Where an area's materials contain a diagram, the diagram MUST be authored as text
  source and rendered, never embedded as an unreproducible binary, following the reference module's
  practice.
- **FR-015**: Every substantive claim in an area's materials MUST carry at least one passage
  citation that resolves, or MUST be visibly marked as editorial framing that is not workshop
  content.
- **FR-016**: An area MUST NOT be published until its publication review has been recorded.
  Recording *"nothing to change"* is a valid review; skipping the review is not.
- **FR-017**: Materials MUST record for each unit of prose whether it was authored or assembled,
  and MUST NOT present assembled text as authored.

**Deep linking — the identity and navigation model**

- **FR-018**: Every relationship the system records between two addressable things MUST be
  traversable in both directions. A relationship that can only be followed one way MUST NOT be
  recorded.
- **FR-019**: From any transcript moment, the system MUST return the areas, the lesson section and
  the questions attached to it, each reachable in a single step.
- **FR-020**: From any area, lesson section or question, the system MUST return every passage that
  evidences it, with the position at which the evidence occurs.
- **FR-021**: For evidence that is media-backed, the position MUST be a time span, and following it
  MUST land within that span. Two precisions exist and the system MUST NOT conflate them: **word
  level**, available where a word-timing sidecar covers the material, and **segment level**,
  available everywhere else. Every media-backed link MUST record which precision produced it, MUST
  NOT present segment precision as word precision, and MUST NOT treat a word whose timing
  confidence is below the recorded threshold as though it were confident.
- **FR-022**: A mention that spans a segment boundary MUST be attached to every segment it touches.
- **FR-023**: Every link MUST resolve through one shared resolution path with four distinct
  outcomes — found, redacted, not present, and could not determine — with no fuzzy fallback, no
  nearest-match, and no second path.
- **FR-024**: An unresolvable link MUST fail loudly and MUST NEVER be silently re-pointed at a
  different target.
- **FR-025**: All links MUST continue to resolve to their original targets after a passage's text
  is corrected and the content re-indexed.
- **FR-026**: Traversal of the relationship graph MUST terminate on cyclic material and MUST NOT
  trap a reader.
- **FR-027**: Redaction MUST propagate to every artifact kind this feature introduces — taxonomy,
  materials, questions, index entries, exports and stored answers — not only to displayed
  transcript.

**Search**

- **FR-028**: Every content kind the feature introduces — areas, lesson sections, terms and
  questions — MUST be indexed and searchable alongside the existing kinds.
- **FR-029**: Every search result MUST carry a locus: the unit that contains it and the position
  within that unit. The position MUST include the **match offsets within the matched text**. Today
  the result already advertises an offset list and that list is always empty; a field that promises
  a position and never carries one MUST NOT survive this feature. Either it is populated, or it is
  removed and its absence stated.
- **FR-030**: A locus MUST resolve. A result whose locus cannot be resolved MUST NOT be returned as
  though it could.
- **FR-030a**: The reference module's search MUST NOT be ported. It is a substring scan with no
  ranking and no locus, and the workshop's existing search already exceeds it on both counts.
  This is recorded as an explicit "not ported" decision under FR-003 so that a later reader does not
  mistake the omission for an oversight.
- **FR-031**: Suggestions MUST include area and term names.
- **FR-032**: Results MUST be filterable by content kind and by area.
- **FR-033**: The existing three-state search behaviour — results, no relevant match, could not
  determine — MUST be preserved across every new kind. A degraded backend MUST NOT be rendered as
  an empty result set.

**Full connectivity across all four content kinds**

- **FR-033a**: Four content kinds MUST be interlinked, and the requirement is not satisfied by
  linking any subset: **transcripts**, **the recording**, **codebases**, and **the knowledge base**
  — areas with their lessons and their questions. Every pair that can meaningfully relate MUST be
  traversable in both directions:

  | From | To | What the traversal must return |
  |---|---|---|
  | a moment in the recording | area / lesson / question | what is being taught at that moment and what tests it |
  | an area, lesson or question | a moment in the recording | the position where the material was actually taught |
  | a transcript passage | area / lesson / question | the knowledge the passage evidences |
  | a code passage | transcript passage | the moment that code was discussed |
  | an area | code passages | the code that the area's knowledge is realised in |
  | any of the four | any other, transitively | a path, not a dead end |

- **FR-033b**: The join across all four kinds MUST be the passage identifier. A timestamp MUST NOT
  be used as a join key. *Why*: the identifier is measured to survive both a content correction and
  a structural insertion; a timestamp survives neither a re-cut nor a re-transcription, so a graph
  keyed on time would silently rot at the first correction while continuing to render links.
- **FR-033c**: Search MUST cover all four kinds by meaning and by context, and MUST report where
  each hit occurs, in the terms of the kind it came from — a time position for the recording, a text
  position for a transcript or a document, a file and symbol position for code, and a containing
  area and lesson for the knowledge base.

**A repeatable chapter pipeline, not a one-off build**

- **FR-033d**: Everything this feature produces MUST be produced by a **repeatable pipeline**, not
  hand-assembled for the chapter that exists today. Processing a new chapter MUST yield, without
  hand-authoring of the structure: its transcript, its passages with minted identifiers, its
  extracted areas and themes, its authored materials, its long and short question sets, its
  cross-references, its search index entries and all of its deep links.
- **FR-033e**: That pipeline MUST **extend the chapter-addition path the platform already
  contracts** — the documented add-a-chapter procedure and its accompanying prompt — rather than
  introducing a second, parallel way to add a chapter. Two procedures for the same act guarantee
  that one of them rots.
- **FR-033f**: Adding a chapter MUST update the taxonomy rather than replace it: areas already
  established keep their identifiers and gain new evidence, areas newly evidenced are added, and an
  area that a new chapter contradicts is surfaced for a decision rather than silently rewritten.
- **FR-033g**: The pipeline MUST report precisely what is missing when a chapter cannot be fully
  processed, and MUST NOT publish a partially processed chapter as though it were complete.

**Assessment with provenance**

- **FR-034**: The system MUST support the reference module's question kinds — multiple choice,
  short answer and flashcard — with the reference's difficulty and category vocabulary, taking the
  schema from it and the questions from the workshop's own material.
- **FR-034a**: Every area MUST carry both a **short** question set and a **long** question set, and
  the distinction MUST be a real difference in depth rather than in count: a short set checks recall
  of the area's core concepts, a long set requires reasoning across more than one passage of
  evidence.
- **FR-034b**: Question coverage MUST be **exhaustive against the area's evidence, not against a
  target count**. Every lesson section of an area MUST be assessed by at least one question, and the
  proportion of the area's evidencing passages that are cited by at least one question MUST be
  measured and published. A large number of questions concentrated on a small part of an area does
  not satisfy this requirement, and the measurement is defined so that it cannot.
- **FR-035**: Every question MUST carry at least one passage citation. This is the property the
  reference module does not have, and it is mandatory here.
- **FR-036**: A question whose citation does not resolve MUST NOT be served.
- **FR-037**: From any question, a learner MUST be able to reach the position its citation names and
  return, with their progress preserved.
- **FR-038**: A model answer that was assembled rather than authored MUST be marked as assembled.
- **FR-039**: The system MUST record a learner's progress per area and per question set, and that
  record MUST survive a re-ingest of the content it refers to — a learner's history is not a
  derived artifact and MUST NOT be discarded when the curriculum is rebuilt.

**Learning surface and visual identity**

- **FR-040**: The interface MUST offer the reference module's learning views — an area view, a
  practice view, a progress view and a study-plan view — as first-class surfaces.
- **FR-041**: The workshop's existing chapter, transcript, recording and cross-reference
  capabilities MUST remain reachable, subordinated to the area they serve rather than removed.
- **FR-042**: All new styling MUST resolve through the shared design-token contract, and MUST NOT
  write brand values literally.
- **FR-043**: The workshop MUST have a visual identity distinguishable from the reference module,
  achieved through the token layer rather than by forking the component library.
- **FR-044**: Every new view MUST meet WCAG 2.1 Level AA, and every deep link MUST be operable by
  keyboard alone, with context changes announced.
- **FR-044a**: Interaction, motion and transition behaviour MUST be taken from the platform's own
  ranked, sourced user-experience research rather than chosen by taste, and each interaction
  decision MUST name the finding it rests on. Where a proposed effect has no supporting finding, it
  MUST NOT ship on the grounds that it looks better.
- **FR-044b**: Every motion effect MUST respect a reduced-motion preference, preserving the final
  visual state without the transition. An effect that becomes load-bearing for comprehension — one
  a user who disables motion would lose information by not seeing — MUST NOT be used.

**Export**

- **FR-045**: Every published area MUST be exportable to Markdown, HTML, Word and PDF.
- **FR-046**: The non-Markdown formats MUST be generated from the Markdown source; no format may be
  authored independently of the others.
- **FR-047**: Citations MUST be preserved in every exported format.
- **FR-048**: An area that has not passed publication review MUST NOT be exported, and the omission
  MUST be reported.
- **FR-049**: When the export toolchain is unavailable, the system MUST report that export could not
  be performed, and MUST NOT report success over an empty or partial output.

**Answering over the new material**

- **FR-050**: The known unclosed defects in question answering — the measured fabrication rate on
  unanswerable questions, and the undefended case where a topically related fragment that does not
  answer the question passes every existing check — MUST be stated in the shipped limits
  documentation, and MUST NOT be described as solved anywhere.
- **FR-051**: If answering is extended to generate answers about areas, lessons or questions, a
  verification layer that checks the answer against the **question** — not only against the
  passage — MUST exist and MUST be measured before that extension is enabled.
- **FR-052**: Where a verification layer cannot run because its prerequisite is absent on the host,
  it MUST report that it could not determine, and the answer MUST NOT be served as verified. An
  entailment-based verifier already exists in the platform behind a configured model directory,
  with lexical overlap as its fallback; a verifier that was *requested* and could not load MUST NOT
  silently degrade to the weaker one.

**Evidence and governance**

- **FR-053**: Every check this feature adds MUST have a paired demonstration that it reports failure
  when the condition it guards is broken.
- **FR-054**: Every check MUST distinguish "could not determine" from both "passed" and "failed".
- **FR-055**: Checks MUST write their evidence to the repository's versioned evidence location.
- **FR-056**: No server-side continuous-integration automation may be introduced, anywhere in the
  fleet.
- **FR-057**: No workshop content — no transcript text, no participant name, no chapter material,
  no recording filename — may appear in any public repository, including this specification
  directory. Content is referenced by identifier only.
- **FR-058**: Components this feature produces MUST follow the decoupling and reuse rules already
  established for the workshop platform: usable without the curriculum, testable without it, and
  where genuinely reusable, resident in their own public repository with synthetic fixtures.
- **FR-059**: Every endpoint this feature adds MUST be declared in the platform's interface contract
  **and** in the route manifest the server-unity verifier reads, and MUST be probed against the
  running binary. The existing verifier already fails when a contracted endpoint has no manifest
  row, so an endpoint that is built but undeclared is a failure by construction — and one that is
  declared but not built must answer as a not-built route rather than being swallowed by the
  single-page application.

### Key Entities

- **Knowledge Area**: a coherent body of knowledge the workshop covers. The workshop's realisation
  of the reference module's *module*. Carries a persisted identifier, a title, a summary, an
  ordering, its evidencing passages, its lesson sections, its questions and its publication-review
  record. An area is *not* a chapter and does not live inside one; it draws evidence from any
  number of chapters.
- **Term**: a named concept within one or more areas. Carries a persisted identifier, a canonical
  form, its known surface variants, a confidence marking and its evidencing passages. A term with
  no evidence does not exist.
- **Lesson Section**: an addressable part of an area's materials. Carries a persisted identifier and
  its own citations, so a link can name a part of an area rather than only the whole.
- **Question**: an assessment item belonging to an area. Carries a persisted identifier, its kind,
  its prompt, its answer or choices, an authored-or-assembled marking, and — mandatorily — its
  citations. **This last field is the difference from the reference module, where it does not
  exist.**
- **Mention**: the join that carries the whole feature. Relates a term or an area to a passage, and
  records the position within that passage — a text span always, and for media-backed passages the
  containing segment's time span. Mentions are what make both directions of navigation possible.
- **Passage**: unchanged from the existing platform. The smallest addressable unit of source
  content, carrying a minted identifier that is neither positional nor content-derived. This feature
  adds nothing to it and depends on it entirely.
- **Publication Review**: the record that an area has been reviewed and may be published and
  exported. Has a subject, a decision, a reviewer and a time. Its absence blocks publication.
- **Locus**: what a search result reports about where it is — the containing unit and the position
  within it. Distinct from the result itself, because the same passage can be reached through more
  than one containing unit.
- **Progress**: a learner's state within an area and within a question set.

## Success Criteria *(mandatory)*

### Measurable Outcomes

Every criterion below names the method that measures it. A criterion whose measurement method is
"inspection by a reviewer" says so and states the sample size and how the sample is drawn. This
discipline exists because feature 001 shipped a criterion that no task measured, and the gap was
found late.

**Taxonomy**

- **SC-001**: 100% of published areas and 100% of published terms have at least one evidencing
  passage. **Measured by**: joining the taxonomy to the mention set and counting entries with zero
  mentions; the count must be 0. Paired mutation: publish an area with its mentions removed — the
  check must go red.
- **SC-002**: On a random sample of at least 30 extracted terms, drawn with a recorded seed, at
  least 90% are judged genuine domain terms rather than extraction noise. **Measured by**: a
  reviewer's recorded judgement sheet, stored with the seed so the sample is reproducible and the
  verdict is challengeable.
- **SC-003**: 100% of the 1,101 passages are accounted for — attached to at least one area or
  classified as unattached with a stated reason. **Measured by**: summing attached and classified
  counts and asserting the total equals the registry count. The attachment *proportion* is
  published as a measured figure; no threshold is claimed for it, because the corpus's topical
  density has not been measured and inventing a threshold would be a guess.
- **SC-004**: A second extraction run over unchanged content changes nothing: 0 identifiers
  reassigned, 0 areas or terms added or removed, and a byte-identical taxonomy file. **Measured
  by**: running extraction twice and diffing; paired mutation: make one identifier depend on
  content — the check must go red.

**Materials**

- **SC-005**: 100% of published areas contain every section of the reference skeleton. **Measured
  by**: a heading-presence check across all area source documents; any missing section fails.
- **SC-006**: 100% of substantive claims in published areas either carry a resolving citation or are
  marked as editorial. **Measured by**: parsing each area document into claims, resolving every
  citation, and asserting no claim is both unmarked and uncited.
- **SC-007**: 0 areas are published without a recorded publication review. **Measured by**: a
  publication precondition check that enumerates published areas and asserts each has a review that
  is newer than the materials it reviews.

**Deep linking**

- **SC-008**: For 100% of recorded relationships, reverse traversal returns the origin. **Measured
  by**: enumerating every relationship, traversing it in reverse through the platform's own
  interface, and counting failures; the count must be 0.
- **SC-009**: For 100% of media-backed citations, following the link lands inside the cited
  passage's own time span. **Measured by**: asserting the landing time falls within the span, over
  every such citation. The precision this delivers is the segment, whose measured distribution is
  median 6.74 s, p95 10.78 s and maximum 20.22 s; that distribution is published with the result
  rather than being smoothed into a single number.
- **SC-010**: After a content correction and a structural insertion, 100% of area, term, lesson,
  question and mention links still resolve to the same targets. **Measured by**: replaying the
  identifier-survival experiment already measured for passages, extended to the new identifier
  kinds, and comparing the full link set before and after by hash.
- **SC-011**: 100% of unresolvable links fail loudly; 0 are silently re-pointed. **Measured by**: a
  mutation that deletes a link target and asserts the resolver returns a loud outcome; the paired
  proof makes the resolver re-point by nearest match and requires the check to go red.
- **SC-012**: 100% of redactions propagate to every artifact kind this feature introduces.
  **Measured by**: redacting a passage and asserting its text is absent from the taxonomy, the
  materials, the questions, the index, the exports and any stored answer; paired mutation: skip one
  propagation target — the check must go red.

**Search**

- **SC-013**: 100% of content kinds are represented in the index. **Measured by**: for each kind, a
  query with a planted, known target must return it; a kind with content but zero index entries
  fails. This is deliberately not a count of rows, because a row count cannot tell a populated index
  from a populated table nobody queries.
- **SC-014**: 100% of returned search hits carry a locus that resolves. **Measured by**: running the
  retrieval benchmark and asserting the property on every hit; any hit without a resolving locus
  fails the run.
- **SC-015**: On a benchmark of at least 20 meaning-based queries over the new content kinds, with
  expected targets fixed in advance, at least 90% return the expected item in the top five.
  **Measured by**: a stored benchmark file of query-to-expected-identifier pairs, executed by a
  gate that prints the per-query outcome, not only the aggregate.
- **SC-016**: Suggestion latency remains at or below 200 ms at the 95th percentile after the new
  kinds are indexed. **Measured by**: re-running the existing latency harness against the grown
  corpus and publishing the measured p95 alongside the pre-existing figure, so a regression is
  visible rather than merely absent.
- **SC-017**: Search result latency remains at or below 2 s at the 95th percentile after the new
  kinds are indexed. **Measured by**: the same harness and the same before-and-after publication.

**Full connectivity and the repeatable pipeline**

- **SC-015a**: All six traversals in the connectivity matrix are exercised and return a non-empty
  result wherever the underlying material exists. **Measured by**: a connectivity harness that, for
  each row of the matrix, picks every eligible origin and asserts the traversal returns at least one
  target — and, where no target exists, asserts the system says so rather than returning an empty
  list that reads as "nothing here". Any row with zero exercised origins fails, because an
  unexercised traversal is unmeasured, not passing.
- **SC-015b**: 0 links in the knowledge graph are keyed on a timestamp. **Measured by**: inspecting
  every stored relationship for its join key; any relationship keyed on time rather than on a
  passage identifier fails. Paired mutation: introduce one time-keyed link — the check must go red.
- **SC-015c**: A chapter that has never been processed goes from raw material to a complete,
  connected knowledge layer using only the documented procedure, with **zero hand-authoring of
  structure and zero code changes**. **Measured by**: running the procedure end to end against a
  small synthetic chapter and asserting the presence of every output — passages with identifiers,
  areas, materials, short and long question sets, cross-references, index entries and deep links —
  then asserting the diff contains no manually created structural file. This is the criterion that
  proves the pipeline is repeatable rather than that one chapter happens to be finished.
- **SC-015d**: Adding a chapter preserves the existing taxonomy: 0 identifiers of previously
  established areas or terms change, and every contradiction between new evidence and an existing
  area is reported rather than resolved silently. **Measured by**: capturing the taxonomy before and
  after, diffing identifiers, and asserting the contradiction report exists and is non-empty
  whenever a contradiction was seeded. Paired mutation: make the pipeline re-derive area identifiers
  on each run — the check must go red.
- **SC-015e**: An incompletely processed chapter is never published as complete. **Measured by**:
  withholding one required input, running the procedure, and asserting it names precisely what is
  missing and publishes nothing. Paired mutation: make the missing input a warning — the check must
  go red.

**Assessment**

- **SC-017a**: 100% of areas carry both a short and a long question set, and the two are
  distinguishable by depth rather than by count. **Measured by**: asserting both sets exist for every
  area, then asserting that every question in a long set cites **more than one distinct passage**
  while a short-set question may cite one. The depth test is structural on purpose — a reviewer's
  impression of difficulty is not reproducible, and a citation count is.
- **SC-017b**: 100% of lesson sections in every published area are assessed by at least one
  question. **Measured by**: joining lesson sections to the questions that cite passages belonging to
  them and counting sections with zero; the count must be 0.
- **SC-017c**: The proportion of each area's evidencing passages that are cited by at least one
  question is **measured and published per area**, and the distribution across areas is published
  with it. **Measured by**: computing the ratio per area and emitting the full per-area table, not
  an average. No threshold is claimed, for a stated reason: the density of assessable substance per
  passage has not been measured, and inventing a percentage would be a guess dressed as a target.
  What the criterion forbids is the figure going unmeasured or being reported only as a mean, which
  is how a well-covered area conceals an empty one.

- **SC-018**: 100% of served questions carry at least one citation that resolves. **Measured by**:
  enumerating every served question, resolving every citation, and counting failures; the count must
  be 0. **The reference module's measured value for this property is 0%**, so this criterion is
  where the workshop exceeds it, and the comparison is recorded rather than claimed.
- **SC-019**: 100% of questions whose citation is a transcript segment support a round trip — from
  question to the cited moment and back — with progress preserved. **Measured by**: an end-to-end
  traversal over every such question; if the count of such questions makes exhaustive traversal
  impractical, a sample of at least 30 is drawn with a recorded seed and the total population is
  published alongside it.
- **SC-020**: 100% of assembled model answers are marked as assembled. **Measured by**: a schema
  assertion over the whole question set; an unmarked assembled answer fails.

**Surface**

- **SC-021**: Every new view reports zero Level A and zero Level AA accessibility violations, and
  100% of deep links are operable by keyboard alone. **Measured by**: an automated audit per view
  plus a keyboard-only traversal that visits every deep-link affordance and asserts it can be
  reached, activated and returned from.
- **SC-022**: 100% of new styling resolves through the shared design-token contract; 0 literal brand
  values appear in new stylesheets. **Measured by**: the design toolkit's own token conformance
  check, plus a literal-value scan over the new stylesheets; both must pass, because the first
  proves the tokens are valid and the second proves they are actually used.
- **SC-023**: 100% of the existing chapter, transcript, recording and cross-reference capabilities
  remain reachable after the surface is reshaped. **Measured by**: enumerating those capabilities
  before the change and asserting each is still reachable after it — a before-and-after list, not a
  recollection.

**Export**

- **SC-024**: 100% of published areas carry all four formats. **Measured by**: a file-existence
  matrix over every published area. The reference module's measured coverage is 25 of 34; this
  criterion requires the workshop to be complete, and the comparison is stated so the bar is known
  to be higher than the model it was taken from.
- **SC-025**: Re-exporting an unchanged area produces documents whose extracted text is identical to
  the previous run. **Measured by**: extracting text from each output and diffing; extraction rather
  than byte comparison, because embedded timestamps make byte equality unachievable for some formats
  and a criterion nobody can meet is worse than none.

**Honesty and governance**

- **SC-026**: The shipped limits documentation names every open defect the evidence directory
  records, including the measured fabrication rate on unanswerable questions and the undefended
  topically-related-but-non-answering case. **Measured by**: a cross-check that reads the recorded
  defects and asserts each is named in the limits document; an unnamed defect fails. Paired
  mutation: remove one defect from the limits document — the check must go red.
- **SC-027**: 100% of checks this feature adds have a paired demonstration that they fail when their
  guarded condition is broken. **Measured by**: the check registry, which fails on an unregistered
  or unpaired check.
- **SC-028**: 100% of checks this feature adds distinguish "could not determine" from "passed" and
  "failed". **Measured by**: driving each check into a could-not-determine condition — an absent
  dependency or an unreachable service — and asserting the third state rather than either of the
  other two.
- **SC-029**: 0 occurrences of workshop content appear in any public repository, including this
  specification directory. **Measured by**: the content-boundary check, run across the public
  surface.
- **SC-029a**: 0 occurrences of reference-module content appear anywhere in the workshop.
  **Measured by**: the same boundary check run in the opposite direction — every workshop area,
  lesson and question is checked against the reference's own corpus, and any substantive overlap
  fails. Paired mutation: plant one reference question in a workshop bank — the check must go red.
  This runs in both directions deliberately: one direction protects a private recording from a
  public repository, the other protects the workshop from shipping someone else's curriculum under
  its own name.
- **SC-029b**: 100% of interaction and motion decisions in new views name the research finding they
  rest on. **Measured by**: a traceability check over the interaction inventory; an entry with no
  named finding fails.
- **SC-030**: 0 active server-side continuous-integration workflows exist anywhere in the fleet
  after this feature lands. **Measured by**: the existing fleet-wide gate.

## Assumptions

Decisions taken where the description did not specify, each chosen for the safest and most stable
option and each revisitable.

- **The reference is a model, not a source.** Its structure, hierarchy, question kinds, document
  skeleton and export toolchain are the template; none of its content, wording or fixtures crosses
  into the workshop. Its 34 finished area documents and 785 finished questions are about a different
  subject and are, for this feature's purposes, not material but a shape.
- **Everything a reader reads is authored from the workshop's own chapters.** Areas, lessons and
  questions are derived from what was actually taught and evidenced against the workshop's own
  passages. There is no scenario in which borrowed material is acceptable, including as a temporary
  placeholder.
- **This is a pipeline, and it is judged as one.** One chapter exists today. The feature is complete
  when *the next* chapter can go through it and come out with the same completeness, not when this
  chapter's materials look finished.
- **A knowledge area is the workshop's module.** Mapping areas onto the reference's *module* level
  keeps one hierarchy rather than two, which FR-002 requires. Chapters supply evidence to areas;
  they are not a level above them.
- **Areas span chapters from the first day.** The corpus currently has one chapter, so a
  one-chapter-per-area shortcut would work today and break at the second chapter. Modelling the
  relationship as many-to-many now costs nothing and avoids a migration later.
- **The taxonomy is bounded by evidence, not by the reference's size.** The reference has 34 areas.
  The workshop will have as many as its corpus evidences and no more. Producing areas to match a
  count would mean inventing coverage the recording does not contain — the exact failure the
  governing rules forbid.
- **Identity discipline is inherited wholesale.** Areas, terms, lesson sections, questions and
  mentions all take minted, persisted identifiers on the same rules as the passage identifier,
  because the property that makes links survive corrections is already measured for passages and
  there is no reason to invent a weaker scheme for the things pointing at them.
- **Mention precision is the containing segment.** Word-level timings do not exist in the registry,
  so segment-level is what can be delivered honestly. The measured distribution is published rather
  than a single reassuring number.
- **Assessment mirrors the reference's grading model.** Multiple choice is scored automatically;
  short answer reveals a model answer for self-assessment. Automatic grading of free text would
  require a capability the host does not have and would import the fabrication risk into the one
  place a learner is most likely to trust the output.
- **The corpus for area extraction is the workshop's own material.** Transcript segments, chapter
  documents and diagrams create areas. Code passages in the wider monorepo may be *linked* as
  evidence, following the corpus decision already recorded for the platform, but they do not create
  areas — code in an unrelated project is not a thing the workshop taught.
- **The platform stays local and internal.** The publication scope already decided for the platform
  is unchanged; nothing here implies public hosting, and the privacy handling and redaction path
  already contracted continue to apply.
- **Search is extended, not replaced.** The existing two-path search and its three-state behaviour
  are proven; new kinds join that index rather than arriving with a second search system.
- **The existing front end is reshaped, not rebuilt.** It has more code than the reference and it
  works; the defect is its shape. Subordinating the media views under areas preserves working
  behaviour while fixing the shape, and avoids discarding capability that took a feature to build.
- **The visual identity comes from the token layer.** A distinct look is achieved by giving the
  workshop its own token values against the shared contract, not by forking the component library —
  forking would double the maintenance and guarantee drift.
- **Scale is tens of areas and one to tens of chapters**, matching the platform's existing scale
  assumption. Nothing is designed for thousands.
- **Governance is binding.** No server-side CI, paired mutation proofs for every gate, three-valued
  checks, evidence written to the versioned location, carriers in lockstep, and the continuation
  document updated alongside non-trivial changes.

## Dependencies

- **The knowledge-model contract** in the workshop's documentation. It is the normative definition
  of the ported hierarchy, and this specification deliberately references it rather than restating
  it (FR-005), so the two cannot drift. **It landed while this specification was being written**,
  and its opening rule — that the contract transfers *form* and transfers no *content* — is the same
  boundary FR-004 states independently. The two were written in parallel and agree; that agreement is
  a check that passed, not a coordination.
- **The area and term taxonomy**, extracted into the workshop's curriculum directory by a separate
  effort. **It also landed while this specification was being written**, and the requirements here
  were written against what a taxonomy must *satisfy* rather than against any particular one — so
  what landed is evidence, not a premise. Measured on arrival, for the one chapter that exists:
  **7 tracks, 37 modules, 137 terms**; per-passage linkage for all **1,101** passages; a coverage
  record showing **884 of 1,055 transcript passages covered (83.79%)** and **14,290 of 15,610 words
  (91.54%)**, with every uncovered passage carrying a **stated reason**; and a reverse index keyed by
  module, by term and by track. Its own identity rule states that the passage identifier is the
  citable identity and that timestamps are for navigation only because a re-cut moves them — which is
  FR-033b, arrived at independently.
  *What this does not settle*: the taxonomy is an input to be reconciled under FR-008a and
  contract §2.3, not a finished answer. The five prose areas still hold the promotion path, and any
  contradiction between them and these 37 modules is reported for a decision rather than merged.
- **The platform's user-experience research** (FR-044a). **This has not landed.** The research
  directory now exists but holds a document on a different subject. Until it does, the interaction
  and motion requirements state what a decision must be able to show, and **T094 is marked blocked**
  rather than being written against taste.
- **The existing platform**: the passage registry and its minted identifiers, the resolution path,
  the search index and its three-state behaviour, the cross-reference graph, and the media
  range-serving that makes a timestamp jump possible.
- **The reference module**, as the structural template and as the source of the export toolchain's
  design — and **only** as that. It is a separate private repository; it is read for shape and never
  for substance (FR-004, FR-004a).
- **The documented chapter-addition procedure and its prompt**, which exist in the workshop's
  documentation today while the script that automates them does not. This feature extends both
  rather than replacing them (FR-033e).
- **The platform's user-experience research**, being produced as this specification is drafted, as
  the source of the interaction and motion requirements (FR-044a). At the time of writing the
  research directory did not yet exist, so this specification states what interaction decisions must
  be able to show rather than naming any particular finding.
- **The shared design system and the design toolkit** that owns the token contract and its
  conformance check.
- **Document conversion tooling** for the four-format export.
- **An entailment-capable or generative model**, for the answer-to-question verification layer only,
  and only if the third clarification is resolved towards closing that defect. Nothing else in this
  specification depends on a model that this host does not have.

## Out of Scope

- Public internet publication of the curriculum. The platform's local-and-internal decision stands.
- Re-transcribing, re-recording or editing source recordings.
- Authoring material for chapters that do not exist.
- Translating the curriculum.
- Replacing or re-architecting the reference module. It is read, never written.
- Optical character recognition of on-screen content — **pending the second clarification**, which
  is precisely the question of whether this belongs in scope.
- Automatic grading of free-text answers.
- A second search system, a streaming service, or any new content delivery infrastructure.

## Resolved Decisions

Questions that materially affect scope and were settled here rather than left open, each recording
what was chosen, why it is the safe choice, and what would reopen it.

### D1 — The knowledge area is the module level of the ported hierarchy

*The question*: the reference has curriculum, track, module and lesson. The workshop has chapters
and passages. Where does a knowledge area sit?

*Decision*: a knowledge **area is the workshop's module**. Lesson sections sit beneath it. Chapters
are a *source* of evidence that areas draw on, related many-to-many, and are not a level of the
hierarchy.

*Why this is the safe choice*: the alternative — areas nested inside chapters — is simpler today,
with one chapter, and wrong at the second one, because knowledge recurs across sessions. Choosing
the correct shape while the data is small costs a design decision; choosing it later costs a
migration of every link already created, which is exactly the class of change this feature's
identity discipline exists to survive but should not be made to prove unnecessarily.

*What would reopen it*: a decision that areas are per-chapter by definition, which would make the
curriculum a set of session summaries rather than a body of knowledge.

### D2 — The existing media surface is subordinated, not removed

*The question*: the operator judged the current workshop poorly made. Do the existing chapter,
transcript, recording and cross-reference views go away?

*Decision*: they **stay and are subordinated**. They become the way a learner reaches source
material from within an area, rather than the top-level objects the product is organised around.

*Why this is the safe choice*: those views are the working half of what exists — they are what makes
a timestamp jump possible at all, and the deep linking this feature is built on runs through them.
Removing them would discard proven capability to fix a problem that is one of *arrangement*.
Keeping them without subordinating them would leave the product a media viewer with a curriculum
bolted to the side, which is the criticism itself. Subordination fixes the shape and keeps the
capability, and SC-023 measures that nothing was lost in the process.

*What would reopen it*: an explicit decision that the recording is not part of the learning
experience.

### D3 — Assessment is scored where scoring is objective, and self-assessed where it is not

*The question*: must the workshop grade free-text answers?

*Decision*: multiple-choice questions are **scored automatically**; short-answer questions reveal a
model answer for **self-assessment**, as the reference module does. No automatic grading of free
text.

*Why this is the safe choice*: automatic grading of free text needs a judging model. This host has
none, so the capability would be unverifiable here — and worse, a grader is the single place where a
wrong confident output does the most damage, because a learner told they were wrong when they were
right will unlearn something correct. The reference module has lived without it. Deferring costs a
feature; adding it now risks the product's credibility on a capability that cannot be measured on
the machine it must run on.

*What would reopen it*: a judging model available and measured on this host, with a fabrication rate
established the same way the answering path's was.

### D4 — Citations are mandatory on questions, and a question without one is withheld

*The question*: what happens when a question cannot be traced to a passage?

*Decision*: it is **not served**. Provenance is a precondition of a question existing, not a
decoration on it.

*Why this is the safe choice*: the entire justification for this feature over its reference is that
the workshop's questions can be traced. A question served without provenance is indistinguishable
to a learner from one with it, so a single unprovenanced question silently converts the guarantee
into a claim. Withholding is loud, cheap and reversible; serving is quiet and irreversible once
trusted.

*What would reopen it*: nothing short of abandoning the provenance guarantee itself.
