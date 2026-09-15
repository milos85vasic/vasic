# Feature Specification: Authored AI/IT Knowledge Areas with Lessons, Tests and Video Anchors

**Feature Branch**: `main` (no feature branch; this repository works on `main` only)

**Created**: 2026-09-07

**Status**: Draft

**Input**: User description: "Workshop curriculum must publish authored AI/IT knowledge areas — not mined transcript vocabulary — each with lessons, senior-level interview question banks and an end-of-area test, rich materials (illustrations, diagrams, schemes, graphs, and video with time ranges), video deep-links that seek the recording and scroll the transcript to that position, tags and every field ai_interviewing exposes, a vivid accessible theme derived from seeded tokens, and full standalone cloneability. Measured defects to resolve: 814 of 819 published areas are single mined terms (3.9% AI-relevant); the list serves 819 areas while the detail route refuses 817 with area_not_published; area detail pages render raw ULIDs and have no lessons or tests; the widened palette never reached the served stylesheets. Every requirement must be covered by machine-produced deterministic evidence with three-valued gates."

## Why this specification exists

This is not a greenfield feature. It is the remedy for a set of defects an
operator found by **manual retesting of the running platform**, each of which
has since been reproduced by machine and is quoted below with its measurement.
The specification exists so the remedy is designed once, in the open, rather
than patched four times by four agents.

**Nothing in this document quotes private content.** The curriculum corpus, the
recordings and the notes derived from them live in a PRIVATE submodule while
this specification lives in a PUBLIC repository. Areas, terms, questions and
transcript text are referred to by **shape, count and location only** — never by
their words. A single pasted line would be a permanent disclosure.

### The measured starting state

| # | Finding | Measurement |
|---|---|---|
| D1 | Knowledge areas are **mined vocabulary**, not authored subjects | 814 of 819 published areas carry a single extracted term. Two independent probes agree the set is not topical: a topical classifier scored **3.9%** AI/IT-relevant, and a term-in-name probe scored **2.4%** carrying an AI/ML term and **4.5%** carrying an AI *or* IT term. No relevance threshold rescues the set — at classifier floors 2 and 3 the surviving population is **0**, and at an evidence floor of 2 the AI-term share falls to **0 of 36**. |
| D2 | Area identity is machine-readable only | Area detail pages rendered the raw opaque identifier as the page heading in **3 of 4** render branches. |
| D3 | The catalogue and the detail route **disagree** | The list endpoint serves **819** areas; the detail route refuses **817** of them as not published. A visitor can therefore reach a listed area and be told it does not exist. |
| D8 | A verified on-disk state is **not** a served state | With the corrected catalogue verified on disk, the running server continued to serve the old **819** because it had loaded its taxonomy at start-up. The served result was undetermined until the process reloaded. This is D6's failure mode on a second surface. |
| D4 | There are **no lessons and no tests** | The lessons and assessment routes return not-found for every area. |
| D5 | Tags are discarded before the interface can ask for them | The list response carries tags for every row; the client-side area model has **no field for them at all**. |
| D6 | The palette work never reached the visitor | Token files widened the hue span, but no served stylesheet was regenerated from them. A token-level measurement is evidence about tokens — it is not evidence about the interface. |
| D7 | Each module cannot be used on its own | The two private learning modules could not be cloned and run outside this umbrella without hand-assembling their dependencies. |

## Clarifications

### Session 2026-09-07

These five decisions were the highest-impact unresolved points in the ambiguity
scan. **Each was resolved from measurement taken on this tree, not from
preference**, and each is recorded with the evidence that decided it so an
operator can overturn it by disputing the evidence rather than the taste. The
measurements arrived from the area-authoring work that ran concurrently with
this specification; nothing here is speculative, and nothing here is a
completion claim.

- Q: How is the authored area set bounded — how many areas, and what decides which subjects the recorded material warrants? → A: The **37 modules of the existing hand-authored lexicon** (7 tracks, 137 terms), each published only with measured passage evidence, an authored document and a review. Not a new mined list, and not an evidence-frequency ranking.
- Q: Must a learner have a durable identity for test gating? → A: **No — anonymous, per-browser.** Gating is enforced on the serving side by withholding the question bank, not by trusting the client.
- Q: May assessment questions be drafted from the recorded material, or must they be written independently? → A: **Authored against this corpus only.** Framing and structure may be reused from the established interviewing module; questions themselves may not be imported.
- Q: What must be true before an interface measurement counts as evidence about the served product? → A: The served catalogue MUST **declare the corpus revision it was built from**, and an interface claim MUST cite it.
- Q: What is the pass threshold for an end-of-area test? → A: **A stated per-area threshold, defaulting to 70%**, shown to the learner before they start.

#### The evidence behind each

**Q1 — the area set is 37, and frequency was measured and rejected as the
selector.** A hand-authored lexicon already existed in the private corpus and
was unused by the publication path: **7 tracks, 37 modules, 137 terms**, with
alias patterns written against what the transcription engines actually emitted
rather than against idealised spellings. Measured across all three recordings:
**0 of 37** modules have zero evidence and **0 of 137** terms match zero
passages, so the set is fully evidenced. It is not evenly evidenced — **16**
modules are strongly evidenced (≥40 matching passages), **9** moderately
(20–39), and **12** are thin (<20), the thinnest at exactly **1** matching
passage in the entire corpus.

An evidence floor was tried as the selector and **rejected by measurement,
because it made relevance worse**: at floor 2, **0 of 36** surviving titles
carried an AI/ML term, against **32 of 814** at floor 1. Frequency is not
topicality. The set is therefore bounded by authored subject matter with
evidence *reported*, not by evidence *ranked*.

**Q2 — anonymous is sufficient because the gate is not on the client.** No
sign-in exists. A per-browser record is enough to decide what to *show*,
because the security property that matters is stated in FR-010 and SC-009: the
serving side does not emit question prompts, options or answers for an
unavailable test. A tampered client can therefore reveal only that it has
tampered — it cannot reveal an answer key it was never sent. Durable
cross-device progress would be a separate capability with its own identity
requirements.

**Q3 — the prohibition is written down, and it was hit during authoring.**
The private module's own knowledge-model contract forbids importing questions
from the interviewing module. The authoring work resolved this the way both
documents permit: reuse the framing, author every question and scenario against
this corpus, and record the decision per area. Where the recordings did not
cover a topic the interviewing module covers, the port was **refused and the
refusal named** rather than filled with plausible content.

**Q4 — this was measured as a live discrepancy, not anticipated as a risk.**
With the corrected catalogue verified on disk, the running server still served
the **old 819** areas, because it had loaded its taxonomy at start-up. The
on-disk state was verified; the served state was **undetermined** until the
container reloaded. That is precisely defect D6 in a second costume — a
measurement of the source reported as a measurement of the product. A declared
corpus revision on the served catalogue makes the discrepancy detectable
instead of invisible.

**Q5 — 70% is a default, and the number is less important than its visibility.**
The requirement is that the threshold is stated per area and shown before the
attempt. An undisclosed threshold makes a result unfalsifiable to the learner.

### Session 2026-09-15

A structured ambiguity scan across five categories — boundary conditions,
error scenarios, scale/performance, security/privacy, and user experience —
against this spec's Edge Cases and Requirements as they stood after the
2026-09-07 session. **Every resolution below is the safest, most reversible
option available**: none invents a numeric ceiling this spec cannot justify,
none proposes a mechanism that would touch or re-derive private corpus
content, and none downgrades an existing requirement. One genuine ambiguity
is left open rather than force-resolved; it is marked as such below.

- Q: How is a lesson's reading-time estimate kept honest as content is authored and re-authored? → A: **Computed from the body, not authored as a separate field.** An independently-authored number can drift from the content it describes with no check catching the drift.
- Q: Does an extremely short, near-empty lesson body need its own minimum-length rule? → A: **No — it is caught by the same structural validation that catches malformed content (FR-012c)**, not a new word-count threshold. Inventing an arbitrary minimum would be exactly the kind of automated judgement Amendment A2 already declined to make for topicality; content substance is a reviewable finding, not a number to tune.
- Q: What does the catalogue show when zero areas are currently publishable? → A: **An explicit empty state, distinguished from an error, and not itself a build failure.** The alternative — an ambiguous blank page — is indistinguishable from D3's "listed but broken" failure mode this whole specification exists to remedy.
- Q: How is a pass threshold rounded when it does not divide evenly into a small question bank? → A: **Round up, never down.** Rounding down would let a learner pass below the threshold that was shown to them before the attempt, which contradicts the disclosure guarantee FR-008b already makes (see Q5, 2026-09-07).
- Q: What happens to content left mid-authored when a session is interrupted? → A: **An explicit draft/placeholder marker excludes the area from publication automatically**, by the same determination as FR-018. Relying on an author to remember to delete a marker before committing is the same class of failure that produced D3 — two separately-trusted mechanisms instead of one.
- Q: What happens when authored content is structurally malformed — a broken reference, an unparseable field? → A: **It is a build-time finding, never a learner-facing runtime error.** This is FR-018c's existing principle ("an inconsistent build MUST be distinguishable from an editorial refusal") applied to content shape rather than publication logic.
- Q: Can a lesson or a test assert something that contradicts another lesson or the assessment for the same area? → A: **Left as a genuine Open Question — see below.** Automated contradiction-detection across authored prose is not a check this specification can respect (FR-026–FR-029 all require a deterministic, three-valued, paired-proof check); a heuristic "contradiction finder" would produce exactly the confident-but-wrong verdicts Amendment A2 already refused for topicality, at higher stakes because the subject is a graded test.
- Q: Does this feature need to assume a fixed ceiling on the number of areas or the size of the corpus? → A: **No — growth is measured, not assumed.** The Assumptions section already states scale is 37 subjects today and the design must not assume that number; this session extends the same principle to response time: report the measurement, do not invent an untested SLA number.
- Q: Can authored lesson or question text reach a learner through a channel this specification's publication gate does not cover — a share preview, an export, a feed? → A: **No — every such channel is covered by the same FR-018 determination as the primary route.** This is the highest-priority resolution in this session given the repository's ACTIVE, unremedied content-boundary incident (see root `CLAUDE.md`): a second, unreviewed path to the same text is exactly the shape of risk that incident describes, and closing it here costs nothing already built.
- Q: May authored content name a private individual who took part in a recording? → A: **No — role or pseudonym only, never a real name.** This restates, as a functional requirement of this feature rather than only a repository-wide incident finding, the same protection the content-boundary incident documentation already requires. It does not weaken or duplicate that documentation; FR-005c is the feature-level enforcement point.
- Q: Can a material file (image, diagram) carry metadata from the machine it was authored on? → A: **No — it MUST be scrubbed before publication.** The umbrella repository has an independently measured, real finding of exactly this shape (`audit-hardcoded-paths.sh`, a developer-host path frozen into a tracked private-submodule file); requiring scrubbing here prevents the same class of defect from recurring inside this feature's own material pipeline.
- Q: How does a learner tell authored teaching prose apart from a quoted transcript passage in the same lesson? → A: **They are visually and structurally distinguished (FR-016b, SC-020).** This is not a new idea so much as the presentation-layer expression of why this feature exists at all — D1 names the defect as mined vocabulary presented as authored subject matter; a lesson that quotes its source material without marking the quote as a quote would reintroduce the same confusion one layer up.
- Q: Is a video-anchor jump usable without a mouse, and does assistive technology learn that the jump happened? → A: **Yes to both — keyboard-only operation and an announced arrival, not only a visual highlight (FR-015a).** FR-013's existing text-alternative requirement covers static materials; this closes the equivalent gap for the interactive jump itself, which FR-015 as originally written did not address.
- Q: Is per-question test correctness legible to a learner who cannot perceive colour? → A: **No colour-alone indicators (FR-022a).** FR-022 already sets a contrast floor; contrast alone does not help a learner who cannot distinguish red from green regardless of contrast ratio, so an icon or text label is required alongside colour.

**The one genuine Open Question this session did not resolve:** whether, and
how, to detect a substantive contradiction between two pieces of authored
content about the same subject (for example a lesson stating one trade-off and
the assessment's explanation stating the opposite). This is left open rather
than resolved because it is irreversible in the same way Amendment A2's
topicality judgement is irreversible — building an automated "contradiction
checker" and trusting its verdicts risks a confident false pass on a genuinely
conflicting pair, or a confident false finding on two claims that are merely
differently framed, and either failure mode reaches a learner as either a
silent defect or an eroded trust in every other automated check this
specification relies on. The safe default already in force is human review at
authoring time (the same review checkpoint FR-002 and Amendment A2 already
require for topicality); this session did not invent a new mechanism beyond
that, and does not claim one is needed — only that automating it further is a
decision for an operator, not a specification default.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A learner finds a subject they recognise (Priority: P1)

A learner opens the knowledge catalogue and sees a list of named AI and IT
subjects — each with a human-readable title, a one-paragraph summary of what it
covers, and tags describing its domain and difficulty. Every entry they can see
is an entry they can open.

**Why this priority**: Every other story in this document is reached *through*
this list. While the catalogue shows opaque identifiers and refuses to open most
of them, no other capability is reachable, so nothing else can be demonstrated.
This story alone — a catalogue that is honest about what it holds — is a viable
increment.

**Independent Test**: Open the catalogue, read every visible entry, and open
each one. Delivers value if every entry is nameable by a person and every entry
opens.

**Acceptance Scenarios**:

1. **Given** the catalogue is served, **When** a learner views the area list, **Then** every entry shows a title composed of words rather than an opaque identifier.
2. **Given** the catalogue is served, **When** a learner opens any entry from the list, **Then** the detail view for that entry loads and never reports that the entry does not exist.
3. **Given** the catalogue is served, **When** a learner reads any entry, **Then** it shows a summary and at least one tag.
4. **Given** an area exists but is not ready to be shown, **When** the catalogue is assembled, **Then** it does not appear in the list at all — being listed and being openable are the same condition.

---

### User Story 2 - A learner works through an area and is tested on it (Priority: P1)

Having opened an area, the learner reads its lessons in order. At the end of the
area they take a test built from senior-level interview questions on that
subject, submit answers, and receive a result telling them which questions they
got right and what the correct answers were.

**Why this priority**: This is the mission the operator stated — areas covered
"with lessons and senior interviewing questions and tests". An area that opens
but teaches nothing is the defect D4 restated, not a fix for it. It shares P1
with Story 1 because a catalogue of empty areas delivers no learning value.

**Independent Test**: Open one area, read its lessons end to end, take its test,
answer deliberately (some right, some wrong), and check that the score and the
per-question feedback match what was answered.

**Acceptance Scenarios**:

1. **Given** a published area, **When** the learner opens it, **Then** they see its lessons listed in a stated order, each with a title and an estimated reading time.
2. **Given** a published area, **When** the learner opens a lesson, **Then** they see its body content and can move to the next and previous lesson without returning to the area.
3. **Given** an area whose lessons the learner has not finished, **When** they look for its test, **Then** they are told what remains before the test opens, and the test's questions and answers are not disclosed.
4. **Given** an area whose lessons the learner has finished, **When** they take the test, **Then** they may answer each question, submit once, and receive a score plus, for every question, whether they were right and what the correct answer is.
5. **Given** a submitted test, **When** the learner re-reads the result, **Then** the result is the same as when it was first shown.

---

### User Story 3 - A learner jumps from a lesson to the exact moment in the recording (Priority: P2)

A lesson references a moment in a recorded session. The learner follows the
reference and lands on the recording positioned at that moment, with the
accompanying transcript scrolled to the matching passage and that passage marked
so it is findable on the page.

**Why this priority**: This is the capability that makes the lessons worth more
than prose — it binds authored teaching to the primary recorded material. It
sits below P1 because a learner can complete Stories 1 and 2 without it, and it
depends on Story 2 existing to link *from*.

**Independent Test**: Follow every reference in one area's lessons and confirm
each lands on the right recording, at the right moment, with the right passage
in view and marked.

**Acceptance Scenarios**:

1. **Given** a lesson with a reference to a recorded moment, **When** the learner follows it, **Then** the recording page opens with the player positioned at the referenced start time.
2. **Given** the same reference, **When** the page settles, **Then** the transcript is scrolled so the referenced passage is visible without further scrolling, and that passage is visually distinguished from its neighbours.
3. **Given** a reference that names a start and an end, **When** the learner follows it, **Then** the extent of the referenced range is discernible, not only its start.
4. **Given** a reference whose target recording or passage is not available, **When** the learner follows it, **Then** they are told the target is unavailable — they are never sent to a page that reports nothing found.
5. **Given** any published lesson, **When** its references are inspected, **Then** every one of them resolves to an existing recording and an existing passage.

---

### User Story 4 - A learner uses supporting materials, not only text (Priority: P2)

Within a lesson the learner encounters illustrations, diagrams, schemes and
graphs alongside the prose, and — where the subject warrants it — a segment of
recorded video presented in place rather than as a link away.

**Why this priority**: The operator named these explicitly. They raise
comprehension for the same content, but a lesson without them still teaches, so
they rank below the lesson mechanism itself.

**Independent Test**: Open every lesson in one area and confirm each declared
material renders, carries a caption, and is reachable without a mouse.

**Acceptance Scenarios**:

1. **Given** a lesson declaring a visual material, **When** the learner reads it, **Then** the material renders in place with a caption stating what it shows.
2. **Given** a lesson declaring a video segment, **When** the learner reads it, **Then** the segment is playable in place and bounded to its stated range.
3. **Given** any material, **When** it is presented to assistive technology, **Then** it carries a text alternative that conveys its content rather than its file name.

---

### User Story 5 - The interface is vivid, legible and consistent (Priority: P2)

A visitor perceives the platform as a designed product with a distinct and
varied palette, rather than a two-tone monochrome document — and every
foreground/background pairing remains legible, including for a visitor using a
dark colour scheme or a high-contrast setting.

**Why this priority**: The operator raised it twice, the second time noting no
change had reached the interface. It is P2 because it changes how existing
capability is perceived rather than what capability exists.

**Independent Test**: Load the served interface, sample the colours actually
painted on each principal surface, and measure both the variety across them and
the contrast within each pairing.

**Acceptance Scenarios**:

1. **Given** the served interface, **When** its painted colours are sampled across principal surfaces, **Then** they span a materially wider range of distinct hues than a two-tone scheme.
2. **Given** any text on any surface, **When** its contrast against its background is measured, **Then** it meets the normal-text accessibility floor; non-text indicators meet the non-text floor.
3. **Given** the interface in light and in dark presentation, **When** both are measured, **Then** both satisfy the two criteria above independently.
4. **Given** a colour decision recorded in the design source, **When** the served interface is measured, **Then** the served interface reflects it — a measurement taken on the design source alone does not satisfy this story.

---

### User Story 6 - Each learning module runs on its own (Priority: P3)

An engineer clones either learning module by itself, follows its own written
instructions on a machine that has never held this umbrella repository, and
reaches a running system.

**Why this priority**: It affects contributors and deployment rather than
learners, and the learner-facing stories can be demonstrated inside the umbrella
without it. It is nonetheless a stated requirement and is verifiable.

**Independent Test**: Clone one module into an empty directory outside the
umbrella, run its documented bootstrap, and reach a state its own status
command calls ready.

**Acceptance Scenarios**:

1. **Given** an empty directory outside the umbrella, **When** the engineer clones a module and runs its documented bootstrap, **Then** every dependency the module needs is obtained by that bootstrap.
2. **Given** the bootstrapped module, **When** the engineer runs its status command, **Then** it reports ready, or reports precisely which host capability is missing and the exact command to obtain it.
3. **Given** the module in that standalone state, **When** any of its own scripts resolve paths, **Then** none of them require the umbrella to be present.

---

### Edge Cases

- **An area is authored but incomplete.** It has a title but no lessons, or lessons but no test. It MUST NOT appear in the catalogue; a listed area that cannot be completed is defect D3 in a new costume.
- **A test is taken twice.** The result of the submitted attempt is the one that stands; a second submission does not silently overwrite the first without the learner being told.
- **A learner requests a test before finishing the lessons.** The response states what remains. It MUST NOT include the questions, the options or the answers — an "unavailable" response that ships the answer key has disclosed it.
- **A referenced recording moment lies beyond the end of the recording.** The reference is reported as unresolvable at authoring time, not silently clamped to the end at reading time.
- **Two areas claim the same subject.** The catalogue exposes each subject once; duplicates are a defect of the authored set and are detectable before publication.
- **The corpus is edited while the catalogue is being measured.** Any count reported about the corpus must be accompanied by evidence that the corpus did not move during the measurement; a count taken over a moving corpus is not reproducible and MUST be reported as undetermined rather than as a number.
- **A material file is missing.** The lesson states the material is unavailable rather than rendering a broken element.
- **A visitor uses reduced-motion or high-contrast settings.** Both are honoured; neither degrades legibility below the stated floors.
- **The interface is measured but the served bundle was not rebuilt.** Any interface claim must establish that what was measured is what is served.
- **A lesson body is extremely long or extremely short.** Its stated reading time MUST be computed from the body it actually describes rather than authored as an independent guess (FR-007a); a body so short it carries no substantive content MUST fail the same structural check that catches malformed content (FR-012c), not a separate word-count rule.
- **The catalogue has zero publishable areas.** It MUST show an explicit empty state, not an error and not a blank page, and that state alone MUST NOT be read as a build failure.
- **A test's question bank is very small.** Where the stated pass threshold applied to the question count does not land on a whole number, the required correct-answer count MUST round up, never down — a learner is never told they passed on a downward rounding of the stated bar.
- **Authoring is interrupted before an area is finished**, leaving a lesson, question or field carrying an explicit draft/placeholder marker. That marker MUST be detected automatically and MUST exclude the area from publication by the same determination as FR-018 — it MUST NOT rely on the author remembering to delete it before committing.
- **Authored content is malformed** — broken structure, an unparseable reference, a field the schema does not expect. This MUST surface as a build-time finding, never as a runtime error shown to a learner.
- **The catalogue or the corpus grows far beyond its current 37-area scale.** The effect on catalogue and reference-resolution response time MUST be measured as scale changes; the design MUST NOT assume a fixed ceiling, and a measured slowdown MUST be reported rather than silently absorbed.
- **Authored content reaches a channel outside the primary reviewed route** — a share/link preview, an export, a machine-readable feed. That channel MUST be covered by the same FR-018 publication determination as the primary route; there is no bypass for authored text.
- **Authored content would need to reference a private individual who took part in a recording.** It MUST do so by role or pseudonym, never by that person's real name — the same protection the standing content-boundary incident already requires of this repository's own documents.
- **A material file (illustration, diagram, scheme, graph) carries embedded authoring-environment metadata** — EXIF location data, a local filesystem path, an authoring-host identifier. It MUST be scrubbed before publication.
- **A learner cannot tell authored teaching prose from a quoted transcript passage inside the same lesson.** The two MUST be visually and structurally distinguished — this is the presentation-layer expression of the reason this feature exists (D1): the platform publishes authored subjects, not mined material, and a reader must be able to see that distinction, not just be told it in a specification.
- **A learner follows a video-anchor reference using only a keyboard or a screen reader.** The jump MUST be reachable without a pointing device, and arrival at the referenced passage MUST be announced to assistive technology rather than conveyed only by a visual highlight.
- **A test result is read by a learner who cannot perceive colour.** Per-question correctness MUST be conveyed by an icon or text label in addition to colour, never by colour alone.

## Requirements *(mandatory)*

### Functional Requirements

#### Authored subject matter

- **FR-001**: The catalogue MUST present knowledge areas that are **authored subjects** — a named topic with a scope a practitioner would recognise — and MUST NOT present entries derived solely by extracting a term from source material.
- **FR-002**: Every published area MUST be an AI or information-technology subject. The **evidence** for that character MUST be recorded and reviewable per area. The **topical judgement itself** — whether the matched evidence is genuinely about the subject — is a named human checkpoint, not an automated classification. **AMENDED 2026-09-07** — see *Amendment A2*, which is provisional and awaits an operator decision.
- **FR-003**: Every published area MUST carry a human-readable title, a summary describing what it covers, and at least one tag. Titles MUST NOT be, or contain, an opaque machine identifier.
- **FR-004**: Every published area MUST expose the descriptive fields that the established interviewing module exposes **and that the shared curriculum library can express**, so the two present consistently to a learner. Fields the library cannot express are recorded as a named exception list with the reason for each, and MUST NOT be fabricated to satisfy this requirement. **AMENDED 2026-09-07** — see *Amendment A3*.
- **FR-005**: The set of published areas MUST be derived from the recorded source material's actual AI/IT content, and the coverage relationship between the source material and the published set MUST be recorded so gaps are visible.
- **FR-005a**: The published set MUST be the authored subject set, and MUST NOT be selected by ranking areas on how often their terms occur. Evidence volume MUST be reported per area, including for thinly-evidenced areas, rather than used as a publication filter.
- **FR-005b**: An area whose supporting evidence is thin MUST still state its evidence volume rather than presenting itself as equally supported.
- **FR-005c**: Authored content — lesson text, questions, captions — MUST NOT name, quote, or otherwise identify a private individual who took part in a recording but is not the corpus owner. Where such a participant must be referenced, the reference MUST use a role or a pseudonym, never a real name.

#### Lessons and assessment

- **FR-006**: Every published area MUST carry at least one lesson, and lessons MUST have a defined order.
- **FR-007**: Every lesson MUST carry a title, body content and an estimated reading time, and MUST be navigable to its neighbours without returning to the area.
- **FR-007a**: A lesson's estimated reading time MUST be computed deterministically from its actual body content, not authored as a separate value that can drift from the content it describes.
- **FR-008**: Every published area for which an authored question bank exists MUST carry an end-of-area test drawn from senior-level interview questions on that subject, and an area with no such bank MUST carry no assessment rather than a generated one. **AMENDED 2026-09-07** — see *Amendment A1* below.
- **FR-008a**: Assessment questions MUST be authored against this corpus. Framing and structure may be adopted from the established interviewing module; question text, options and answers MUST NOT be imported from it.
- **FR-008b**: Every assessment MUST declare a pass threshold, and that threshold MUST be shown to the learner before the attempt begins.
- **FR-008c**: Where a stated pass threshold applied to a question bank's size does not produce a whole number of required correct answers, the required count MUST round up, never down.
- **FR-009**: A learner MUST be able to submit answers to a test and receive a score together with, for each question, whether their answer was correct and what the correct answer is.
- **FR-010**: Until an area's lessons are complete, its test MUST be reported as unavailable with the remaining requirement stated, and the response MUST NOT contain question text, options, or correct answers.
- **FR-011**: A submitted test result MUST be stable — re-reading it returns the same result, asserted by an automated check rather than by a manual validation step.
- **FR-012**: Answers MUST be identified in a way that does not depend on the order options are presented in.
- **FR-012a**: Test availability MUST be enforced where the content is served, not where it is displayed. A learner record held only in the browser MAY decide what is shown; it MUST NOT be what prevents an answer key from being sent.
- **FR-012b**: Authored content carrying an explicit incomplete/placeholder marker (for example a stated draft or TODO indicator) MUST be excluded from publication by the same automated determination that governs FR-018, not by an author remembering to remove it before commit.
- **FR-012c**: Authored content MUST validate against its defined structure before publication — including a lesson body so short it carries no substantive content beyond restating its title. A structural validation failure MUST be reported as a build-time finding and MUST NEVER be surfaced to a learner as a runtime error.

#### Materials and video anchors

- **FR-013**: A lesson MUST be able to carry supporting materials — illustration, diagram, scheme, graph, and video segment — each with a caption and a text alternative.
- **FR-013a**: A material file MUST be scrubbed of embedded authoring-environment metadata — for example EXIF location data, a local filesystem path, or an authoring-host identifier — before publication.
- **FR-014**: A lesson MUST be able to reference a moment or a range in a recorded session, identifying the recording, a start position, optionally an end position, and the transcript passage that corresponds to it.
- **FR-015**: Following such a reference MUST position the recording at the referenced start, scroll the transcript so the referenced passage is in view, and visually distinguish that passage.
- **FR-015a**: Following a video-anchor reference MUST be achievable using only a keyboard, and arrival at the referenced passage MUST be announced to assistive technology, not conveyed only by a visual highlight.
- **FR-016**: Every reference in every published lesson MUST resolve to an existing recording and an existing passage; an unresolvable reference MUST prevent publication of that lesson rather than surfacing to a learner.
- **FR-016b**: Every published lesson MUST visually and structurally distinguish its own authored prose from any quoted or transcribed passage it includes, so a learner cannot mistake one for the other.
- **FR-017**: A reference that cannot be satisfied at reading time MUST tell the learner the target is unavailable rather than presenting an empty or not-found page.

#### Catalogue integrity

- **FR-018**: An area MUST appear in the catalogue if and only if its detail view, its lessons and its assessment are all servable. Listing and openability are one condition, not two.
- **FR-018a**: The publication decision MUST be computed in exactly one place and consumed by every surface that needs it. Sharing a vocabulary of reasons between separately-implemented decisions does NOT satisfy this — the measured cause of D3 was two implementations that shared their reason strings and differed in their *sequence of tests*, each passing its own unit tests because nothing asserted the pair.
- **FR-018b**: An area withheld from the catalogue MUST still be identifiable — its identifier and the reason it was withheld MUST remain retrievable, and where a name is derivable it MUST be disclosed. Withholding an area is not a reason to withhold what it is called.
- **FR-018c**: An inconsistent build MUST be distinguishable from an editorial refusal, and one bad record MUST NOT take the catalogue down.
- **FR-018d**: A catalogue with zero publishable areas MUST present an explicit empty state rather than an error or a blank page, and that state MUST NOT by itself be treated as a build failure.
- **FR-018e**: Any surface capable of exposing authored lesson or question text outside the primary reviewed route — a share or link preview, an export, a machine-readable feed — MUST be covered by the same publication determination as FR-018. There is no bypass route for authored content.
- **FR-019**: Descriptive fields present in the catalogue listing MUST survive to the interface that presents them; a field carried by the listing and discarded before display is a defect.
- **FR-020**: The catalogue MUST expose each subject once.
- **FR-020a**: The effect of catalogue or corpus growth beyond its current scale on catalogue and reference-resolution response time MUST be measured, not assumed; the design MUST NOT assume a fixed ceiling, and a measured slowdown MUST be reported rather than silently tolerated.

#### Presentation

- **FR-021**: The served interface MUST present a palette spanning a materially wider range of distinct hues than a two-tone scheme, across its principal surfaces.
- **FR-022**: Every text pairing in the served interface MUST meet the normal-text contrast floor and every non-text indicator the non-text floor, in both light and dark presentation.
- **FR-022a**: Per-question correctness in a test result MUST be conveyed by a means other than colour alone — for example an icon or a text label — so it is legible without colour perception.
- **FR-023**: Design decisions recorded in the design source MUST be reflected in the served interface; a claim about the interface MUST be supported by a measurement of what is served.
- **FR-023a**: The served catalogue MUST declare the corpus revision it was built from, and any claim about served content MUST cite that revision. A verified on-disk state is not evidence about what is being served.

#### Independence

- **FR-024**: Each learning module MUST be cloneable and runnable on its own, outside this umbrella, obtaining every dependency through its own documented bootstrap.
- **FR-025**: No module script MUST require the umbrella to be present in order to resolve its own paths.

#### Evidence

- **FR-026**: Every requirement above MUST be covered by an automated check that produces machine-readable evidence.
- **FR-027**: Every such check MUST report three outcomes — satisfied, a real finding, or could-not-determine — and a could-not-determine MUST NEVER be recorded as satisfied.
- **FR-028**: Every such check MUST ship a paired demonstration that it detects the defect it exists to catch, and that demonstration MUST work by supplying different data rather than by altering the check.
- **FR-029**: Every check whose subject is a set MUST establish that the set is non-empty before reporting that the set contains no defects; an absence reported over an empty set is not evidence.
- **FR-030**: Any count reported about the corpus MUST be accompanied by evidence that the corpus did not change during the measurement.

### Key Entities

- **Area** — a named AI/IT subject. Has a stable identifier, a human-readable title, a summary, tags, an ordered set of lessons, and exactly one assessment. Published or not; publication requires all its parts to be servable.
- **Lesson** — one unit of teaching within an area. Has a title, ordered position, body content, estimated reading time, zero or more materials and zero or more video anchors.
- **Material** — a supporting artefact attached to a lesson: illustration, diagram, scheme, graph or video segment. Has a kind, a caption and a text alternative.
- **Video anchor** — a reference from a lesson into recorded material: which recording, start position, optional end position, and the corresponding transcript passage.
- **Assessment** — the end-of-area test. Has a question bank, a pass threshold, and an availability condition tied to lesson completion.
- **Question** — one item in an assessment. Has prompt text, identified options, one or more identified correct answers, and an explanation shown after submission.
- **Attempt** — a learner's submission against an assessment. Has the answers given, a score, and per-question outcomes.
- **Catalogue** — the served set of published areas. Its membership is defined by servability, not by a separate flag.

## Amendments

Recorded rather than silently applied, because a specification that changes
without saying so is as untrustworthy as one that is wrong. Each amendment names
the analysis finding that produced it and the measurement that settled it.

### Amendment A1 — assessments are required where a bank exists, not universally

**Finding F1 (CRITICAL).** As originally written, FR-008 and SC-004 required
every published area to carry an end-of-area test. The delivered design
deliberately permits an area with lessons and no assessment, and the measured
state is **5 of 42**. The two positions could not both hold.

**Resolved in favour of the design, and the reason is the point.** All 44
authored bank questions carry their own area identifier and every one names a
platform area; the 37 curriculum areas genuinely have no bank. The alternative —
generating 37 banks to satisfy a number — is forbidden elsewhere in this same
specification and by the constitution's *Quality Over Speed* principle, and the
validator raises a finding for each missing assessment rather than passing over
it. **A fabricated question bank is worse than a missing one: it is a test a
learner can fail for the wrong reason.**

The obligation did not weaken. It moved: bank coverage is now **reported on
every run** (SC-004a) instead of being asserted and quietly unmet.

### Amendment A2 — topical judgement is a checkpoint, not a classifier (PROVISIONAL)

**Finding F3 (HIGH).** FR-002 required the AI/IT character of each area to be
"determinable from a recorded, reviewable classification". The publication
reviews record what was checked **and explicitly what was not** — including
*whether the matched evidence is topical*. The requirement therefore asked for
exactly the judgement the reviews decline to make.

**Provisionally resolved by splitting evidence from judgement**: the evidence is
recorded and reviewable; the judgement is a named human checkpoint.

**This amendment awaits an operator decision and is the only one that does.**
The alternative — build an automated topical classifier and give it its own
review — is defensible and was not chosen here, because it is a curriculum call
rather than an engineering one. Two measurements bear on it: a term-in-name
probe scores 64.3% AI-or-IT, and its own author records that it *understates*
the result because it cannot see areas whose titles carry no jargon. An
automated classifier would inherit that blind spot; a human reading the area
does not.

### Amendment A3 — field parity is bounded by what the library can express

**Finding F6 (MEDIUM).** FR-004 required exposing "the same descriptive fields"
as the interviewing module. Four cannot be expressed here: `difficulty` and
`category` (no such field exists in the shared library — an upstream change),
spaced repetition, and localisation. **As written the requirement was
unsatisfiable**, and the only way to "satisfy" it would have been to invent
fields.

Two of the four are worth recording precisely, because they are not the same
kind of gap. `difficulty`/`category` are a genuine capability gap needing an
upstream change. Spaced repetition is not: the interviewing module **writes
those fields and reads them from no route**, so porting them would add a
maintenance surface with no behaviour.

Related and deliberately **not** ported: that module's kind filter passes an
unvalidated value through to storage, so an unknown kind returns an empty list
that reads as "there are none". Here an unknown kind is a **400**. Copying the
behaviour would have copied a defect.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: **100%** of areas visible in the catalogue can be opened; the count of listed-but-unopenable areas is **0**, against a measured baseline of **817**.
- **SC-002**: **100%** of published areas are classified AI/IT by a recorded classification, against a measured baseline of **3.9%**.
- **SC-003**: **0** published areas display an opaque machine identifier as their title, against a baseline of 3 of 4 render branches doing so.
- **SC-004**: **100%** of published areas carry at least one lesson; the count with none is **0**, against a baseline of all of them. **100%** of published areas that have an authored question bank carry exactly one assessment. **AMENDED 2026-09-07** — see *Amendment A1*.
- **SC-004a**: Question-bank coverage is **reported on every run** as a fraction of published areas, currently **5 of 42**. This is a tracked figure, not a floor: it rises only when a bank is authored against evidence, never by generation.
- **SC-005**: **100%** of published areas carry a summary and at least one tag, and those fields are visible in the interface — not merely present in the data.
- **SC-006**: A learner can go from opening the catalogue to receiving a scored test result **without leaving the product** and without encountering a not-found response at any step.
- **SC-007**: **100%** of video references in published lessons resolve to an existing recording and an existing passage; unresolvable references number **0**.
- **SC-008**: Following a video reference positions the recording within **1 second** of the referenced moment and brings the referenced passage into view without further scrolling, in **100%** of sampled references.
- **SC-009**: Requesting an unavailable test discloses **0** question prompts, **0** options and **0** correct answers.
- **SC-010**: The served interface presents at least **6** distinct hue families across its principal surfaces, up from **2**.
- **SC-011**: **100%** of text pairings meet the normal-text contrast floor and **100%** of non-text indicators meet the non-text floor, in both light and dark presentation; failures number **0**.
- **SC-012**: Each learning module reaches a self-reported ready state from a clone into an empty directory outside the umbrella, on a host that has never held the umbrella.
- **SC-013**: **100%** of the requirements in this specification map to at least one automated check, and every such check ships a paired demonstration that it detects its own defect.
- **SC-014**: **0** checks report a could-not-determine as a pass.
- **SC-015**: A learner completing one area's lessons and test spends no time waiting on a page that has not told them what it is doing.
- **SC-016**: **100%** of published areas report their supporting evidence volume, including the thinly-evidenced ones; areas presenting no evidence figure number **0**.
- **SC-017**: **100%** of assessments declare a pass threshold that is visible before the attempt begins.
- **SC-018**: The served catalogue declares the corpus revision it was built from in **100%** of responses, so a served-versus-on-disk discrepancy is detectable rather than silent.
- **SC-019**: **0** authored lesson or question characters reach a learner through a channel that bypassed the FR-018 publication determination — share previews, exports, machine-readable feeds — measured by an automated check.
- **SC-020**: **100%** of published lessons that include a quoted or transcribed passage visually and structurally distinguish it from the lesson's own authored prose, measured by an automated structural check.

## Assumptions

These are reasonable defaults chosen where the input did not specify. Each is
recorded so it can be challenged in clarification rather than discovered later.

- **Learners are anonymous** (decided, Q2). Progress and attempts are held per browser session; the serving side, not the browser, is what withholds an unavailable test's content. Durable cross-device progress is a separate capability.
- **Content is authored in English.** The recorded source material and the existing lessons are English; localisation is out of scope for this feature.
- **The existing interviewing module is the reference for field shape**, because the operator named it as the model. It is a reference for *what fields exist and how they present*, not a source of content to copy.
- **"Senior-level" means questions a practising engineer with several years in the subject would find non-trivial** — scenario and trade-off questions rather than definition recall. The bank is authored against this corpus (decided, Q3), not generated from transcript text and not imported from the interviewing module.
- **Video is served from material already present in the private module.** No new recording, hosting or transcoding capability is introduced.
- **Materials are authored assets committed alongside the lessons.** No authoring tool or upload path is introduced by this feature.
- **The palette is derived from the existing seeded design tokens** rather than chosen afresh, so brand continuity holds; what changes is that the derivation reaches the served interface.
- **Existing search, answer and evidence capability is unchanged.** This feature adds a curriculum surface beside it and must not regress it.
- **Scale is 37 authored subjects over three recorded sessions** (decided, Q1), matching what the corpus holds today. The design must not assume those numbers, but the acceptance evidence is measured against them.
- **Publication is a build-time determination.** Whether an area is servable is decided when the catalogue is assembled, not per request.

## Dependencies

- The private curriculum corpus and its recordings, which are referenced by path and never by content.
- The existing transcript passage registry, which supplies the passages video anchors resolve against.
- The existing design token source, from which the palette is derived.
- The reusable curriculum library that carries the area/lesson/material/assessment shape, so this capability is not welded to one application.

## Out of Scope

- Learner accounts, cross-device progress, and certificates.
- Authoring tools or a content management interface; content is authored as committed files.
- Localisation of lessons or questions.
- New recording, video hosting or transcoding capability.
- Changes to the existing search and answer surfaces beyond what integration requires.
