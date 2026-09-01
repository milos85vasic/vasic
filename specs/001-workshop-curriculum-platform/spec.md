# Feature Specification: Workshop Curriculum Platform

**Feature Branch**: `001-workshop-curriculum-platform`

**Created**: 2026-08-31

**Status**: Draft

**Input**: User description: "Create full transcription of the workshop's chapter 1! Create it as markdown document and then with it, all materials we have in chapter 1 cover everything we have been talking about during the whole exercise 1. We MUST create under workshop same thing we did for ai interviewing module - the curriculum! It MUST BE properly and structurally organized! We MUST BE able to run it through the containers same way and having all mandatory bash scripts! Extend what we already have - the ideas and technology of ai curriculum for the workshop so users can browse and watch all chapters (we have just one for now), and create the prompt which we will be able to execute after we add every new chapter with materials (if any) which can be easily executed to extend the workshop curriculum with new data. We MUST extend the workshop solution to have semantic / contextual search which will cover all areas by meaning and context fully - all technology, everything discussed during the workshop calls / videos, whole transcriptions, and cross reference by proper linkings all this so we can go from point to point through whole content, semantics, contexts. All covered areas MUST BE fully documented with curriculum materials, same way we did with ai curriculum (interviewing module). Use the same technology as the base we used for ai_interviewing, however bring it to the new level by extending it for new powerful game-changer functionalities! We MUST HAVE interactive search by contexts or semantics, all codebases understood (integration of Lumen semantics too) same and better like it is possible to be done on the https://deepwiki.com !!! Extend UI / UX components for support of search! Search MUST offer blazing fast auto-completion and bringing together all pieces flawlessly! All codebase, all graphs, schemes, diagrams, textual content, audio and video content MUST BE fully indexed by content and semantics, context and searchable with possibility of asking the AI questions and getting instant answers! If bridging with LLM provider is required use all technology we have in HelixDevelopment and vasic-digital organizations so we can easily provide external or internal (local) models which can be connected with the solution and everything ran instantly and maximal UX achieved! Do deep research on all technology we MUST incorporate, create comprehensive documentation, user guides and manuals, FAQs, trainings and quick start tutorials. There MUST BE proper tests coverage which will validate and verify everything by asserting machine evidence produced and there MUST BE no false or faulty results of any kind and no bluff! Constitution MUST BE fully taken into the account, followed and respected with no violations or ignoring any of mandatory rules, points, guidelines! Make sure we do regularly commit and push all the changes - all submodules fully recursively and main repo so git status returns clean result for every single one of them all!"

## Context: Verified Starting State

These facts were measured on 2026-08-31 and constrain the requirements below. They are recorded here because several requirements are only meaningful against them.

| Fact | Measured value |
|---|---|
| Chapter 1 source material | One screen-recording, `Milos teaching … AI workflows - 2026_08_27 09_57 CEST - Recording.mp4`, **1.8 GB** |
| How the recording is stored in git | **36 × 50 MB** `tar.gz` parts, plus a `.sha256` manifest — the whole file is git-ignored |
| Supporting material | One AI-generated notes PDF (**412 KB**), "Notes by Gemini" |
| Existing transcript | **None** |
| `workshop/README.md` | Contains the single word "Tbd." |
| Existing tooling in `workshop/` | `archive-videos.sh`, `extract-videos.sh`, `install-hooks.sh`, `self-test.sh`, git hooks, and a video-archive pipeline design document |
| Reference module | `ai_interviewing/` — carries `platform/`, `assets/`, `docs/`, `scripts/`, and README in md/html/pdf/docx |
| Chapters today | **1** |

## Clarifications

### Session 2026-08-31

Five ambiguities were found by a taxonomy scan and are resolved here. Per the operator's
standing instruction to choose the safest, most stable, risk-free option where a choice is
mandatory, each was answered with the recommended best-practice option rather than deferred.
The reasoning is recorded so any answer can be challenged later.

- Q: How are passages identified so cross-references and citations survive re-indexing and transcript correction? → A: Persisted stable identifiers, assigned once at ingest, never derived from position or content.
  *Why*: identifiers derived from position break whenever the transcript is re-cut; identifiers derived from content hash break whenever a typo is fixed. Either failure silently rots every cross-reference and every citation — the exact "confident but wrong" outcome the governing constitution forbids. A persisted identifier survives both.
- Q: May a human correct a machine-generated transcript, and what happens to the original? → A: Yes; corrections are layered, the machine output is kept immutable, and provenance is recorded per passage.
  *Why*: the machine transcript is evidence of what the recogniser produced; overwriting it destroys the ability to re-measure accuracy later (SC-002). Layering keeps both the claim and its evidence.
- Q: The recording features an identifiable third party. What privacy control is required? → A: Local-only operation (already decision D1), plus a documented redaction step that must run before any export or publication.
  *Why*: D1 removes the exposure today, but a future decision to publish would otherwise inherit no safeguard at all. Requiring the redaction path to exist now costs little and prevents an irreversible mistake later.
- Q: Where does the machine evidence required by the governance rules live, and for how long? → A: Written to a versioned evidence directory inside the repository, retained with the commit that produced it.
  *Why*: this mirrors the repository's existing `_tests/evidence/` practice, so evidence is reviewable at the commit it describes rather than in transient logs that disappear.
- Q: What accessibility standard applies to the curriculum and its search interface? → A: WCAG 2.1 Level AA, with full keyboard operability for search.
  *Why*: AA is the common legal and institutional baseline; keyboard operability is called out explicitly because a type-ahead search box is a well-known accessibility failure point, and the interface's primary interaction is typing.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Read what was actually said in a workshop chapter (Priority: P1)

A learner who could not attend the session opens the workshop curriculum and reads Chapter 1 as a structured written document. They can follow the whole exercise end to end in text, see who said what, and jump from any passage to the exact moment in the recording it came from.

**Why this priority**: Nothing else in this feature can exist without it. Search, cross-linking, question-answering and curriculum navigation are all built on top of a faithful written record. Today that record does not exist at all — the knowledge is locked inside a 1.8 GB video that nobody can grep, quote, or link to. This alone converts an unusable asset into a usable one.

**Independent Test**: Deliver only the transcript and its verification report. A reviewer can open the markdown document, read Chapter 1 in full, pick any five passages at random, and confirm against the recording that each is accurate and that its stated timestamp lands on the corresponding moment. Value is delivered even if no search, UI, or AI features are ever built.

**Acceptance Scenarios**:

1. **Given** the Chapter 1 recording and its notes PDF are available, **When** the transcription process is run, **Then** a markdown transcript is produced covering the entire recording from start to end with no unexplained gaps.
2. **Given** a produced transcript, **When** a reader selects any passage, **Then** the passage carries a timestamp that locates it within the recording to within a few seconds.
3. **Given** a produced transcript, **When** the accuracy verification is run, **Then** it reports a measured accuracy figure derived from a sampled comparison against the source audio, rather than asserting correctness without evidence.
4. **Given** the recording contains segments where speech is unclear or inaudible, **When** the transcript is produced, **Then** those segments are explicitly marked as uncertain rather than silently guessed at or omitted.
5. **Given** the transcript is complete, **When** a reader looks for the topics covered, **Then** the document is organised into navigable sections rather than presented as one undifferentiated block of text.

---

### User Story 2 - Browse and watch the curriculum like a course (Priority: P2)

A learner opens the workshop curriculum and sees the available chapters. They pick Chapter 1, read its materials, watch the recording, and move through the chapter's sections in a deliberate order, the same way they would work through the existing AI-interviewing module.

**Why this priority**: This is what makes the transcript a *curriculum* rather than a file. It is second because it depends on Story 1's output existing, and because a reader can already extract value from a well-structured transcript without a browsing interface.

**Independent Test**: Start the curriculum with the documented command, open it, and confirm that Chapter 1 is listed, its materials are readable, and the recording plays. Testable with exactly one chapter present, which is the current reality.

**Acceptance Scenarios**:

1. **Given** the curriculum is started using its documented start command, **When** a user opens it, **Then** every existing chapter is listed with its title and a summary of what it covers.
2. **Given** a user has opened a chapter, **When** they view it, **Then** they can read its transcript and supporting materials and play its recording without leaving the curriculum.
3. **Given** a user is partway through a chapter, **When** they navigate between its sections, **Then** their position and progress are preserved.
4. **Given** the curriculum is started on a machine that has never run it before, **When** the documented start command is used, **Then** it starts successfully without manual setup steps beyond those the documentation states.
5. **Given** a chapter's recording is stored in split parts, **When** a user plays it, **Then** playback works without the user needing to know about or manually reassemble those parts.

---

### User Story 3 - Find anything by meaning, not by keyword (Priority: P3)

A learner remembers that something was discussed about a topic but not the words used. They type what they mean, get relevant results ranked by meaning across transcripts, documentation, diagrams and code, see them as they type, and follow cross-references from a result to related material elsewhere in the curriculum.

**Why this priority**: This is the "game-changer" capability and the largest body of work. It is third because it is only valuable once there is indexed content (Story 1) and a place to present results (Story 2). Delivering it last keeps the earlier stories shippable.

**Independent Test**: With Chapter 1 indexed, issue a set of meaning-based queries whose expected material is known in advance, and confirm the expected passages are returned and ranked sensibly — including queries that share no literal words with the target text.

**Acceptance Scenarios**:

1. **Given** the curriculum content is indexed, **When** a user searches using words that do not literally appear in the target passage, **Then** the passage is still returned because it matches by meaning.
2. **Given** a user is typing a query, **When** each character is entered, **Then** suggestions appear quickly enough to feel instantaneous.
3. **Given** a search result, **When** the user selects it, **Then** they are taken to the exact passage in its source material, with surrounding context visible.
4. **Given** a passage of content, **When** the user views it, **Then** related material elsewhere in the curriculum is offered as cross-references, so they can move from point to point.
5. **Given** the curriculum includes source code, **When** a user searches for a concept implemented in that code, **Then** the relevant code is returned alongside prose results.
6. **Given** a search returns no relevant match, **When** results are shown, **Then** the interface says so plainly rather than presenting unrelated results as though they were answers.

---

### User Story 4 - Ask a question and get a grounded answer (Priority: P4)

A learner asks a natural-language question about the workshop content and receives a direct answer, together with citations pointing to the passages the answer was drawn from, so they can verify it.

**Why this priority**: Highest-risk item for correctness. It depends on everything above and is the easiest place for the system to produce confident-sounding falsehoods, which the project's governance explicitly forbids. Sequencing it last means it is built on already-verified foundations.

**Independent Test**: Ask a set of questions with known correct answers drawn from Chapter 1, plus a set of questions the content genuinely cannot answer. Confirm the first set is answered correctly with working citations, and the second set is refused rather than fabricated.

**Acceptance Scenarios**:

1. **Given** a question answerable from the indexed content, **When** the user asks it, **Then** the answer is returned with citations to the specific passages it came from.
2. **Given** a citation in an answer, **When** the user follows it, **Then** it lands on material that genuinely supports the claim made.
3. **Given** a question the content cannot answer, **When** the user asks it, **Then** the system states that it does not know instead of inventing an answer.
4. **Given** an operator has configured a locally-hosted model, **When** questions are asked, **Then** they are answered without content being sent to any external service.
5. **Given** no model is configured or reachable, **When** a user asks a question, **Then** the system reports that answering is unavailable, and search and browsing continue to work.

---

### User Story 5 - Add a new chapter without redesigning anything (Priority: P5)

A maintainer receives the recording and materials for Chapter 2. They follow one documented, repeatable procedure, and the new chapter is transcribed, added to the curriculum, indexed, and cross-linked alongside Chapter 1.

**Why this priority**: The curriculum's long-term value depends on cheap extension, but it cannot be validated until at least one chapter has been through the pipeline end to end.

**Independent Test**: Run the documented procedure against a small synthetic chapter and confirm it appears fully integrated — browsable, searchable, cross-linked — with no edits to code or configuration beyond the new chapter's own materials.

**Acceptance Scenarios**:

1. **Given** a new chapter's materials are placed where the procedure specifies, **When** the procedure is executed, **Then** the chapter is transcribed, published, indexed and cross-linked without any code change.
2. **Given** a new chapter has been added, **When** a user searches, **Then** results span both old and new chapters.
3. **Given** the procedure is executed twice on the same chapter, **When** the second run completes, **Then** the result is identical to the first and no duplicate content appears.
4. **Given** a chapter's materials are incomplete, **When** the procedure runs, **Then** it reports precisely what is missing and does not publish a partial chapter as though it were complete.

---

### Edge Cases

- **The recording is only available as split parts.** A fresh clone has 36 archive parts and no playable video. Reassembly must be automatic and integrity-checked; a corrupted or partial reassembly must fail loudly rather than yield a truncated video that appears to work.
- **Transcription is expensive and long-running.** A 1.8 GB recording cannot be transcribed within a normal interactive wait. The process must be resumable, must report progress, and must not lose completed work if interrupted.
- **Speech is unclear, overlapping, or in mixed languages.** Marked as uncertain, never silently invented.
- **The notes PDF and the transcript disagree.** The recording is the authority; the disagreement is surfaced, not silently resolved.
- **Indexing runs while content is being edited.** Results must never be served from a half-written index; a stale-but-consistent index is preferable to an inconsistent one.
- **The indexing backend is unavailable or saturated.** Search must degrade honestly — reporting that it cannot answer right now — rather than returning empty results that read as "nothing found". *(This failure has already occurred in this repository. Corrected figure: the "75 s" first written here was not a measurement — it was the `timeout 75` value of the probe that killed the query, so it recorded the observer, not the system. The real recorded measurements are **>90 s** for a serialised embed call and **~10 min** elsewhere; a controlled re-measurement under load saw three identical two-word embed calls take **20.16 s / 11.05 s / 0.10 s**, a 200x spread driven purely by queue contention. The conclusion stands; the number was wrong and is withdrawn rather than quietly replaced.)*
- **A search returns a passage the user is not expecting to exist.** Because the recording is a private teaching session naming a specific individual, access scope must be explicit rather than assumed.
- **Two chapters cover the same topic.** Cross-references must not create loops that trap a reader.
- **A very large or very small query.** An empty query, a single character, and a multi-paragraph query must all behave predictably.
- **A transcript passage is corrected after cross-references already point at it.** The references must continue to resolve; a correction must not orphan them.
- **A passage is redacted after it has been indexed and cited.** The redaction must propagate to the index and to any stored answers, not merely to the displayed transcript.
- **A screen-reader user searches.** Suggestions appearing as the user types must be announced, and must not trap focus.
- **The curriculum is started on a machine with no GPU, or with a different container runtime.** It must run or state precisely what is missing — this repository already contains host-dependent container logic that has caused portability defects.

## Requirements *(mandatory)*

### Functional Requirements

**Transcription and source material**

- **FR-001**: System MUST produce a complete written transcript of each chapter's recording, covering the recording from beginning to end.
- **FR-002**: System MUST associate each transcript passage with a timestamp locating it in the recording.
- **FR-003**: System MUST explicitly mark passages that could not be transcribed with confidence, and MUST NOT substitute invented text for them.
- **FR-004**: System MUST produce a verification report stating measured transcript accuracy and the method used to measure it.
- **FR-005**: System MUST attribute passages to distinct speakers where the recording allows it, and state where it cannot.
- **FR-006**: System MUST preserve the original recording and all supporting materials unmodified.
- **FR-007**: System MUST reassemble split recordings automatically and verify their integrity against the recorded checksum before use, failing loudly on mismatch.

**Curriculum structure and browsing**

- **FR-008**: System MUST present chapters as a browsable curriculum with titles and summaries.
- **FR-009**: Users MUST be able to read a chapter's transcript and materials, and play its recording, from within the curriculum.
- **FR-010**: System MUST preserve a user's position and progress within a chapter.
- **FR-011**: System MUST organise each chapter's content into navigable sections rather than a single undifferentiated document.
- **FR-012**: System MUST be startable and stoppable through documented commands that require no manual setup beyond what the documentation states.
- **FR-013**: System MUST follow the organisational conventions already established by the existing AI-interviewing module, so that a person familiar with one can navigate the other.

**Search and cross-referencing**

- **FR-014**: System MUST return results matching a query by meaning, including when the query shares no literal words with the matched passage.
- **FR-015**: System MUST offer suggestions as the user types.
- **FR-016**: System MUST index all curriculum content types: transcripts, written documentation, source code, diagrams and schematics, and the recordings themselves.
- **FR-017**: System MUST take a user from a search result to the exact passage in its source, with surrounding context.
- **FR-018**: System MUST offer cross-references from any passage to related material elsewhere in the curriculum.
- **FR-019**: System MUST state plainly when a search has no relevant match, and MUST NOT present unrelated results as answers.
- **FR-020**: System MUST report honestly when search is unavailable or degraded, and MUST NOT render an unavailable backend as an empty result set.

**Question answering**

- **FR-021**: System MUST answer natural-language questions about indexed content, returning citations to the passages supporting each answer.
- **FR-022**: System MUST decline to answer when the indexed content does not support an answer, rather than producing an unsupported one.
- **FR-023**: System MUST support both locally-hosted and externally-hosted answering models, selected by operator configuration.
- **FR-024**: System MUST NOT transmit curriculum content outside the machine when configured to use a local model.
- **FR-025**: System MUST continue to serve browsing and search when answering is unavailable.

**Extension**

- **FR-026**: System MUST provide a single documented, repeatable procedure that ingests a new chapter end to end — transcribe, publish, index, cross-link — without requiring code changes.
- **FR-027**: The extension procedure MUST be idempotent: running it twice on the same chapter MUST NOT duplicate content.
- **FR-028**: The extension procedure MUST report precisely what is missing when a chapter's materials are incomplete, and MUST NOT publish a partial chapter as complete.
- **FR-029**: Long-running processing MUST be resumable and MUST report progress, without losing completed work if interrupted.

**Documentation**

- **FR-030**: System MUST ship user-facing documentation covering: a quick-start tutorial, a user guide, an operator manual, and an FAQ.
- **FR-031**: Documentation MUST state honestly what the system cannot do, including any content it does not index and any capability that requires operator configuration.

**Evidence and governance**

- **FR-032**: Every automated check MUST be accompanied by evidence that it can fail — a paired demonstration that the check reports failure when the condition it guards is broken.
- **FR-033**: System MUST NOT report a check as passed when it could not actually run; "unable to verify" MUST be distinguishable from both "passed" and "failed".
- **FR-034**: The feature MUST NOT introduce any server-side continuous-integration automation, which the governing constitution prohibits without exception.
- **FR-035**: All governance carrier documents MUST remain synchronised, and the continuation document MUST be updated alongside non-trivial changes.
- **FR-036**: All work MUST be committed and pushed across the main repository and every submodule, leaving no uncommitted state.

**Identity, correction and privacy**

- **FR-037**: Every passage MUST carry a stable identifier assigned at ingest that is neither positional nor content-derived, so that cross-references and citations remain valid across re-indexing and transcript correction.
- **FR-038**: System MUST preserve machine-generated transcript output immutably, and MUST record for each passage whether its current text is machine-produced or human-corrected.
- **FR-039**: System MUST provide a documented redaction step capable of suppressing identified passages, and MUST require it to have been run before any export or publication of chapter content.

**Evidence and accessibility**

- **FR-040**: System MUST write the evidence produced by its automated checks to a versioned location within the repository, retained alongside the commit that produced it, rather than to transient logs.
- **FR-041**: The curriculum interface MUST meet WCAG 2.1 Level AA.
- **FR-042**: Search MUST be fully operable by keyboard alone, including entering a query, moving through suggestions, and opening a result.

### Key Entities

- **Chapter**: One workshop session. Has an ordinal, a title, a summary, a recording, supporting materials, and a transcript. Chapters are ordered and independently navigable.
- **Recording**: The source audiovisual asset for a chapter. Large; stored split; has a checksum for integrity verification.
- **Transcript**: The written record of a recording. Composed of timestamped, optionally speaker-attributed passages, each carrying a confidence indication. Exists in two layers: the **immutable machine output** (evidence of what the recogniser produced) and an optional **human correction layer** on top. Each passage records which layer it came from.
- **Passage**: The smallest addressable unit of content — a span of transcript, a documentation section, a code region, or a diagram. The unit that is indexed, returned by search, cited by answers, and linked by cross-references. Carries a **persisted stable identifier** assigned once at ingest, which is neither positional nor content-derived, so cross-references and citations survive both re-indexing and transcript correction.
- **Cross-reference**: A directed relationship between two passages, enabling point-to-point navigation.
- **Index**: The derived searchable representation of all passages. Rebuildable from source; never authoritative over it.
- **Supporting Material**: Non-recording chapter content — notes, documents, diagrams, code.
- **Query**: A user's natural-language input, resolved either to ranked passages or to a cited answer.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A reader can read the complete Chapter 1 session as text, covering 100% of the recording's duration with every gap explicitly accounted for.
- **SC-002**: Transcript accuracy is measured on a random sample of at least 30 passages, and the measured figure is published alongside the transcript.
- **SC-003**: A reader can move from any transcript passage to the corresponding moment in the recording, landing within 5 seconds of the spoken content.
- **SC-004**: A new user can go from a fresh clone to a running curriculum in under 15 minutes using only the quick-start tutorial.
- **SC-005**: Search suggestions appear within 200 milliseconds of a keystroke, measured at the 95th percentile.
- **SC-006**: Search results return within 2 seconds at the 95th percentile.
- **SC-007**: On a benchmark set of at least 20 meaning-based queries with known expected results, at least 90% return the expected passage in the top five results.
- **SC-008**: At least 80% of the benchmark queries succeed when the query shares no literal words with the target passage, demonstrating meaning-based rather than keyword matching.
- **SC-009**: 100% of citations in generated answers resolve to passages that genuinely support the claim, verified by review of a sample of at least 20 answers.
- **SC-010**: On a set of at least 10 questions the content cannot answer, the system declines 100% of them and fabricates none.
- **SC-011**: A maintainer can add a new chapter using only the documented procedure, with zero code or configuration changes, in under 30 minutes of hands-on time.
- **SC-012**: Every automated check in the feature has a paired demonstration that it fails when the guarded condition is broken — 100%, with no exceptions.
- **SC-013**: The system distinguishes "unable to verify" from "passed" and "failed" in 100% of its checks.
- **SC-014**: The repository introduces zero active server-side CI workflows.
- **SC-015**: After completion, the main repository and every submodule report a clean working tree.
- **SC-016**: After a transcript is corrected and the content re-indexed, **100%** of previously created cross-references and citations to passages the curriculum OWNS — transcripts and its own documentation — still resolve to the passage they originally referred to. This holds by construction, because a minted identifier is anchored into the source artifact itself.
- **SC-016a**: For passages in source code the curriculum does NOT own, where an identifier anchor cannot be written into the file, identity is keyed on symbol path with a rename alias table. The guarantee is weaker and is stated rather than overclaimed: **100% of stale code references fail loudly** — an unresolvable identifier returns not-found and is never silently re-pointed at different code. A rename inside the curriculum's own tree without an alias fails ingest rather than shipping a broken link.
  *Why split*: an unqualified 100% across all passage kinds would have been unachievable, and discovering that during implementation would have produced either a quiet exception or a silently wrong link — the exact failure this criterion exists to prevent. The boundary is drawn where the mechanism actually changes.
- **SC-017**: The curriculum interface passes an automated WCAG 2.1 Level AA audit with zero violations at Level A or AA, and every search interaction is completable using only the keyboard.
- **SC-018**: 100% of automated checks write their evidence to the repository's versioned evidence location, verifiable by inspecting that location after a run.

## Assumptions

These are reasonable defaults chosen where the description did not specify. Each is a decision that can be revisited.

- **Reference implementation**: The existing `ai_interviewing/` module is the structural and technical template. Its conventions are followed unless a workshop-specific requirement (notably video-heavy content) makes them unsuitable.
- **Container runtime**: The curriculum runs in containers, started by bash scripts, consistent with existing repository practice. Host-dependent runtime differences are detected rather than assumed.
- **Transcription approach**: Automatic speech recognition over the recording's audio, with the recording treated as the authority when it disagrees with the notes PDF.
- **Answering models are pluggable**: Both locally-hosted and external models are supported, with the choice made by operator configuration; local operation is the privacy-preserving default.
- **Existing semantic search is reused**: The repository already operates a local semantic code-search capability; the feature builds on it rather than introducing a competing one.
- **Chapter numbering**: Chapters are ordinal and zero-padded, following the existing `chapters/01/` convention.
- **Recordings stay out of version control whole**: They remain split into size-bounded parts with checksums, as they are today.
- **The design system is reused**: New interface components adopt the repository's existing shared design tokens and components rather than introducing a new visual language.
- **Governance is binding, not aspirational**: The constitution submodule governs this work. Specifically, no server-side CI may be added; every gate needs a paired mutation proof; governance carriers stay in lockstep; and the continuation document is updated alongside non-trivial changes.
- **Scale**: The design targets the current reality of one chapter, growing to tens of chapters — not thousands.
- **Audience**: Readers are technical practitioners comfortable with a terminal, consistent with the existing module's audience.

## Dependencies

- The Chapter 1 recording and its notes PDF, already present in `workshop/chapters/01/`.
- The existing `ai_interviewing/` module, as the structural reference.
- The repository's existing semantic-search capability and its embedding backend, over the corpus fixed by D2.
- The repository's shared design system.
- An answering model, either locally hosted or externally reachable, for User Story 4 only. Stories 1–3 do not depend on it.
- The constitution submodule, which governs the work.

## Out of Scope

- Public internet publication of the curriculum (decided: local/internal only — see D1).
- Editing or re-recording the source recordings.
- Live transcription of sessions as they happen.
- Authoring content for chapters that do not yet exist.
- Translating the curriculum into other languages.
- Replacing or re-architecting the existing `ai_interviewing/` module.

## Resolved Decisions

Three questions materially affected scope. Per the operator's standing instruction to choose
the safest, most stable and most risk-free option where a choice is mandatory, each is resolved
here rather than left open. Each records what was chosen, why, and what would reopen it.

### D1 — Audience and publication scope: **local / internal only**

*The question*: the Chapter 1 recording is a private teaching session between two named
individuals. Should the curriculum run locally only, or be published like the repository's two
production sites?

*Decision*: **local and internal only.** The curriculum is served on the operator's own machine
or internal network. It is NOT published to the public internet, and no requirement in this
specification implies public hosting.

*Why this is the safe choice*: publishing a recording of an identifiable third party without
recorded consent creates a privacy exposure that cannot be undone once indexed by search
engines. Local-only carries no such risk, requires no consent workflow, no access-control
system, and no public hosting infrastructure — it is strictly less to build and strictly less
to get wrong. It also keeps the feature clear of the two live production sites, which must not
be disturbed.

*What would reopen it*: an explicit operator decision to publish, accompanied by recorded
consent from every identifiable participant. That would add access control, consent tracking
and public hosting to scope.

### D2 — Search corpus: **the workshop module plus the `vasic` monorepo**

*The question*: "all codebases understood" — workshop only, the whole `vasic` monorepo, or
repositories across the wider HelixDevelopment and vasic-digital organisations?

*Decision*: **the `workshop/` module and the `vasic` monorepo that contains it.** Repositories
outside this working tree are out of scope.

*Why this is the safe choice*: this corpus is already indexed by the repository's existing
semantic search today, so the capability is proven rather than speculative, and its cost is
known. Reaching into other organisations' repositories would require credentials this feature
does not have, would index content whose licensing and privacy status has not been reviewed,
and would make index size and refresh cost unbounded. Choosing the already-working corpus
removes all three risks.

*What would reopen it*: a named list of additional repositories, with confirmed read access and
a decision on how their content is refreshed.

### D3 — Video delivery: **local reassembly, played from the curriculum**

*The question*: must the curriculum stream the 1.8 GB recording, or simply hand it to the
user's own player?

*Decision*: the recording is **reassembled locally from its split parts, integrity-checked
against its recorded checksum, and played back from within the curriculum interface from that
local file.** No streaming server, transcoding pipeline, adaptive bitrate ladder, or content
delivery network is in scope.

*Why this is the safe choice*: reassembly already exists in `workshop/scripts/` and is already
checksum-verified, so this reuses proven tooling instead of adding infrastructure. Serving a
local file needs no new moving parts, and — because D1 makes the curriculum local-only — there
is no bandwidth or concurrency problem that streaming would solve. Timestamped navigation from
transcript to recording (FR-002, SC-003) works against a local file without any of it.

*What would reopen it*: publishing the curriculum (D1), or recordings large enough that local
reassembly becomes impractical.
