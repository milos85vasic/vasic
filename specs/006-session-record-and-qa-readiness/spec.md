# Feature Specification: A Complete Session Record per Chapter, and a Platform a QA Team Can Test

**Feature Branch**: `main` (this repository works on `main` only)
**Created**: 2026-09-08
**Status**: Draft

**Input**: "For each chapter we MUST HAVE filled in and fully prepared sections with proper content — Next meeting, Open questions, Meeting notes, TODO. […] All points which have not been covered in the current chapter, but they have been planned, they all MUST BE all passed to upcoming chapter, re-planned, and such points clearly marked with some proper indicator! All details screens MUST BE filled with real lessons (content) and tests. […] Make sure we as soon as possible get to the fully manually testable version of the workshop by the QA team! […] There MUST BE no gaps, shortcomings, any misalignments, weak spots, issues or danger zones!"

## Why this specification exists

Two things are being asked for, and they are one problem.

**First:** each recorded working session must leave behind a record a person can act on — what was discussed, what remains open, what must be done, and what the next session will cover. That record must be **cumulative**: a session's record is authored from that session *and every session before it*. And it must be **honest about slippage** — a point that was planned and not covered does not quietly disappear; it moves forward, is re-planned, and says on its face that it slipped.

**Second:** the platform must be in a state where a QA team can test it manually, end to end, and a client can be shown it — with the evidence to back every claim made about it.

They are one problem because the second is unachievable while the first is missing: a QA team handed a chapter with four empty sections cannot tell whether the sections are broken or simply unwritten.

### The measured starting state

| # | Finding | Measurement |
|---|---|---|
| **S1** | **No chapter carries any of the four sections** | 3 chapters exist. Grepping every chapter document for the four section names returns **0 matches inside `chapters/`**. Only one chapter has any notes document at all. |
| **S2** | **The chapter surface exposes almost nothing** | A served chapter carries exactly three fields: an identifier, a hierarchy and a material count. There is nowhere for a session record to appear. |
| **S3** | **No carry-forward mechanism exists** | Nothing records what was planned for a session, so nothing can detect what was planned and not covered, and nothing can move it forward. |
| **S4** | **Area detail is real but uneven — and the row below was WRONG, in an instructive way** | **CORRECTED 2026-09-08.** The original row read "39 areas served, 30 carrying an assessment, 224 graded questions, 12 carrying no test, each stating so to a learner". Measured on the wire: **39 served, 14 with an assessment, 116 questions, 25 with none, and NOT ONE stating why.** Measured on disk at the same moment: **42 areas, 30 with an assessment, 224 questions.** Both readings are correct; they measure different things. The error was reporting a SOURCE measurement as though it described the SERVED product. See *The disk/wire distinction* below — it is the root cause of the platform's largest live defect, not merely a bookkeeping slip. |
| **S7** | **The learning surface is unreachable from a browser** | The learning client never sends the session header the routes require. Live: `GET /api/areas/{id}/lessons` without it → **400**, with it → **200**. Both learning panels render an error card on **every** area page. The API is correct; the omission is client-side. |
| **S8** | **No lesson carries teaching content** | 339 authored lessons, **0** with any body/content/text field at source or served. The builder parsed every section body, used it only to compute a reading-time estimate, and discarded it — because the shared library's `Lesson` type had no field to hold it. |
| **S5** | **3 documents remain unpublished** | 62, 54 and 58 uncited claim blocks. Correctly withheld; a client sees 39 areas, not 42. |
| **S6** | **No QA-facing entry point exists** | There is no document a QA team can be handed that says what to test, how, and what a correct result looks like. |


### The disk/wire distinction — the root cause of the platform's largest live defect

Two measurements taken at the same moment, both correct:

| | areas | with an assessment | questions |
|---|---:|---:|---:|
| **on disk** (the authored catalog) | 42 | **30** | **224** |
| **on the wire** (the running process) | 39 | **14** | **116** |

The gap is not a bug in the loader and not a bad catalog. **The server reads the
catalog ONCE at process start**, deliberately and documentedly. It then answered
*"this area's learning catalog carries no end-of-area test"* — a claim about the
**directory** — from a snapshot taken hours earlier and never re-read. The 14
areas that worked had banks written at 07:13; the 13 that failed had banks
written at 10:47, after the process started at 08:01. **The discriminating
condition was time.**

Two obligations follow, and both are now requirements in this document:

1. **A process may only assert what its snapshot licenses.** A determined
   negative about on-disk state, made from a stale snapshot, is a false claim
   however correct the code is. The remedy is not to reload constantly — it is to
   detect staleness and return could-not-determine, naming what changed.
2. **A measurement of source is not evidence about the served product**, and must
   never be reported as one. This specification made that error in its own S4 row.
   It is corrected above rather than quietly rewritten, because the same mistake
   has now occurred four times in this project — in a palette gate reading token
   files, in a build id hashed over an orphaned stylesheet, in a gate suite
   verified in-process, and here.

## Clarifications

### Session 2026-09-08

- Q: The four sections are served as a key on the chapter object, but four dedicated components exist whose routes 404. Which is the surface? → A: **Build the four routes to match the components.**
- Q: `covered: 0` because no coverage decision has been recorded by anybody. Who judges it? → A: **An agent proposes coverage per point; the operator reviews.**
- Q: The QA documents were written before the rebuild and describe the pre-fix product. → A: **Regenerate both against the current build before QA.**
- Q: 39 areas not 42, 12 without tests, every score indeterminate. What does the client see? → A: **Disclose all three up front in the walkthrough.**

#### What each obliges, and one blocker

**The four routes are wiring, not new capability** — the components exist and the
data is derived. **But one is blocked and the blocker is deliberate**: the route
manifest records that a meeting-notes withholding rule *may not be guessed*,
because one note is a content judgement left undecided for the operator. That
rule must be settled before `/api/chapters/{id}/meeting-notes` can be built
correctly, and building it on a guessed rule would publish a judgement nobody
made.

**Coverage: proposed, never asserted.** The operator chose agent-proposed review
over judging cold — but the agent that built the record explicitly declined this
work, on the grounds that matching one heuristic extraction against another is
*"a guess wearing a decision's clothes"* and every downstream percentage would
inherit it. That refusal was correct and stands. So a proposal is admissible only
if it carries, per point, the evidence it rests on and its own confidence, and is
marked **proposed** in the artefact until a human confirms it. `coverage_state`
stays `undecided` until then — a proposal is not a decision, and the served
figure must not move because an agent drafted something.

**The QA documents are regenerated, not patched.** They describe 14 areas with
tests and 0 lessons with content; live is 27 and 318 of 318. A stale
expected-result column does not merely mislead — it manufactures false defects
and spends a tester's time disproving our own fixes. Both must record the build
id they were written against so they can be re-validated when the build moves.

**Client disclosure is up front, not on discovery.** The three facts — 39 areas
rather than 42, 12 carrying no test, and every score indeterminate because all
banks mix machine-marked and free-text questions — each have a good reason, and
the reasons demonstrate the anti-bluff discipline rather than apologising for it.
A gap discovered live is worse than one disclosed first.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A participant reads what a session produced (Priority: P1)

Someone who attended, or missed, a working session opens that chapter and reads four things: what was discussed, what is still open, what must be done, and what the next session will cover. Each is real content about that session, not a placeholder.

**Why this priority**: This is the operator's stated requirement and the thing whose absence is most visible. It is also what makes a chapter presentable to a client.

**Independent Test**: Open each chapter and read all four sections. Delivers value if every section contains content specific to that session and none is empty or generic.

**Acceptance Scenarios**:

1. **Given** any chapter, **When** a participant opens it, **Then** all four sections are present and each contains content specific to that session.
2. **Given** a chapter's record, **When** a participant reads it, **Then** it reflects that session **and every session before it** — a question opened earlier and still unresolved appears as open.
3. **Given** an item in any section, **When** a participant reads it, **Then** they can tell which session it originated in.
4. **Given** a section with genuinely nothing to report, **When** it is presented, **Then** it says so explicitly with the reason — an empty section and an unwritten section are never indistinguishable.

---

### User Story 2 - A planned point that slipped is visibly carried forward (Priority: P1)

A point planned for a session and not covered appears in the **next** chapter's plan, re-planned, and marked so a reader sees at a glance that it slipped rather than being newly raised.

**Why this priority**: Shares P1 with Story 1 because a session record without carry-forward is a record that quietly loses commitments — the precise failure the operator is asking to prevent.

**Independent Test**: Take a point planned for one session and not covered; confirm it appears in the next chapter, marked as carried over, with its origin visible.

**Acceptance Scenarios**:

1. **Given** a point planned for a session, **When** the session did not cover it, **Then** it appears in the next chapter's plan.
2. **Given** a carried-forward point, **When** a reader sees it, **Then** it is **visually distinguished** from a point raised for the first time.
3. **Given** a point carried forward more than once, **When** a reader sees it, **Then** how many times it has slipped is visible.
4. **Given** a session's plan, **When** the record is assembled, **Then** every planned point is accounted for as covered, carried forward, or explicitly dropped with a reason — **no planned point may simply vanish**.
5. **Given** the most recent chapter, **When** points carry forward from it, **Then** they land somewhere a reader can find them even though no later chapter exists yet.

---

### User Story 3 - A QA team can test the platform manually, end to end (Priority: P1)

A tester who has never seen the platform is handed one document, follows it, and exercises every feature and flow — knowing for each step what a correct result looks like and how to report a wrong one.

**Why this priority**: The operator's stated goal. It also converts every other claim in this specification from an assertion into something a second party can check.

**Independent Test**: Hand the document to someone unfamiliar with the platform and have them complete it without asking a question.

**Acceptance Scenarios**:

1. **Given** the QA document, **When** a tester follows it, **Then** every feature and flow is covered, each with its expected result stated before the tester performs it.
2. **Given** any step, **When** the observed result differs from the expected one, **Then** the document says how to report it and what information to capture.
3. **Given** a capability that is deliberately absent or limited, **When** a tester reaches it, **Then** the document says so in advance — **a tester must never discover a known limitation as if it were a defect**.
4. **Given** the platform, **When** a tester begins, **Then** getting to a testable state requires only the documented steps.

---

### User Story 4 - Every area detail screen shows real teaching and a real test (Priority: P2)

A learner opening any published area finds lessons with real content and, where one exists, a test they can take — and where no test exists, the area says why.

**Why this priority**: Largely delivered — 30 of 39 areas carry assessments. What remains is completing coverage where evidence supports it and ensuring the interface presents it well.

**Independent Test**: Open every published area; confirm each shows lessons with content, and either a test or a stated reason there is none.

**Acceptance Scenarios**:

1. **Given** any published area, **When** a learner opens it, **Then** they see lessons with real content, in order.
2. **Given** an area with a test, **When** the learner completes the required lessons, **Then** they can take it and receive a scored result with per-question feedback.
3. **Given** an area without a test, **When** a learner opens it, **Then** the reason is stated — never an unexplained absence.
4. **Given** any area, **When** its materials are presented, **Then** each renders with a caption and a text alternative.

---

### User Story 5 - A reviewer can confirm no claim is unearned (Priority: P2)

An independent reviewer takes any claim made about the platform and traces it to machine-produced evidence, or finds it explicitly marked as unverified.

**Why this priority**: The operator asked for no bluff of any kind. This is what makes that checkable rather than promised.

**Independent Test**: Sample claims from the QA document and the platform's own reporting; each resolves to evidence or to a stated limitation.

**Acceptance Scenarios**:

1. **Given** any claim that a capability works, **When** a reviewer asks for evidence, **Then** a machine-produced artefact supports it.
2. **Given** any check, **When** it reports, **Then** it distinguishes satisfied, a real finding, and could-not-determine — and a could-not-determine is **never** recorded as satisfied.
3. **Given** any evidence, **When** a reviewer re-runs its producer, **Then** the same inputs produce the same result.
4. **Given** a known gap, **When** a reviewer looks for it, **Then** it is recorded with its reason and who may lift it — not omitted.

---

### Edge Cases

- **A session covered something never planned.** It is recorded as emergent, not silently folded into the plan as though it had been foreseen.
- **A point is carried forward indefinitely.** The slip count is visible and rising; a point that has slipped repeatedly is surfaced rather than buried.
- **A session record would disclose private material.** Sections are authored from private recordings while the umbrella is public — the record must exist without content crossing that boundary.
- **A chapter has no successor.** Carry-forward from the latest chapter must still land somewhere findable.
- **An area's test exists but its lessons do not.** The test is unreachable; this must surface as a finding, not as an area that looks complete.
- **A QA step depends on a capability that is deliberately absent.** Stated in advance, with the reason.
- **Two chapters disagree about an open question's status.** The later chapter's record governs, and the transition is visible rather than a silent overwrite.
- **The evidence is stale.** Evidence must identify the state it was produced from, or it cannot be trusted after that state moves.
- **A record is authored while its source material changes.** Any count reported must carry evidence the source did not move during the measurement.

## Requirements *(mandatory)*

### The session record

- **FR-001**: Every chapter MUST carry four sections — meeting notes, open questions, TODO, and next meeting — each with content specific to that session.
- **FR-002**: A chapter's record MUST be authored from that session **and every session before it**; an item raised earlier and unresolved MUST still appear.
- **FR-003**: Every item MUST identify the session it originated in.
- **FR-004**: A section with nothing to report MUST say so with the reason. **An empty section and an unwritten section MUST NOT be indistinguishable.**
- **FR-005**: The four sections MUST be served, not only present as files, and MUST be reachable at their own routes so a section can be linked to directly.
- **FR-005a**: A withholding rule for any section MUST be settled by the operator before that section's route is built. A route built on a guessed withholding rule publishes a judgement nobody made.

### Carry-forward

- **FR-006**: Every session MUST have a recorded plan, so coverage can be determined at all.
- **FR-007**: Every planned point MUST resolve to exactly one of: covered, carried forward, or explicitly dropped with a reason. **A planned point MUST NOT simply vanish.**
- **FR-007a**: A coverage verdict MAY be proposed by a machine but MUST carry, per point, the evidence it rests on and its own confidence, and MUST be marked PROPOSED until a human confirms it. The served coverage state MUST remain undecided until confirmation — **a proposal is not a decision, and the published figure MUST NOT move because a draft exists.**
- **FR-008**: A point not covered MUST appear in the next chapter's plan, re-planned.
- **FR-009**: A carried-forward point MUST be **visually distinguished** from a newly raised one.
- **FR-010**: The number of times a point has slipped MUST be visible.
- **FR-011**: Carry-forward from the latest chapter MUST land somewhere a reader can find, even with no successor chapter.
- **FR-012**: Carry-forward MUST be derived from recorded plan and coverage, not hand-maintained — a hand-maintained list is a list that drifts.

### Learner-facing completeness

- **FR-013**: Every published area MUST present lessons with real content, in order.
- **FR-014**: Every published area with an authored question bank MUST present a takeable test with scored per-question feedback.
- **FR-015**: An area without a test MUST state the reason to the learner.
- **FR-016**: Every material MUST render with a caption and a text alternative.
- **FR-017**: An area whose test exists but whose lessons do not MUST surface as a finding.

### QA readiness

- **FR-018**: A single QA document MUST exist covering every feature and flow, each step stating its expected result **before** the tester performs it.
- **FR-019**: It MUST state how to report a discrepancy and what to capture.
- **FR-020**: It MUST disclose every known limitation **in advance**. A tester MUST NOT discover a known limitation as if it were a defect.
- **FR-020a**: The QA and client documents MUST record the build identifier they were written against, and MUST be regenerated — not patched — when that build moves. A stale expected-result column manufactures false defects and spends a tester's time disproving fixes.
- **FR-020b**: The client-facing walkthrough MUST disclose, before a client can encounter them: the served area count against the authored total, the count of areas carrying no test with the reason, and that scores are indeterminate while any bank mixes machine-marked and free-text questions.
- **FR-021**: Reaching a testable state MUST require only the documented steps.
- **FR-022**: It MUST cover edge cases and failure paths, not only the paths that succeed.

### Evidence and review

- **FR-023**: Every claim that a capability works MUST be supported by a machine-produced artefact.
- **FR-024**: Every check MUST be three-valued, and a could-not-determine MUST NEVER be recorded as satisfied.
- **FR-025**: Every check MUST ship a paired demonstration that it detects the defect it exists to catch, driven by **data** rather than by altering the check.
- **FR-026**: Evidence MUST identify the state it was produced from, and MUST state whether it measured SOURCE or the SERVED product. The two are different populations and a source measurement MUST NEVER be reported as evidence about what is served.
- **FR-026a**: A process holding a cached snapshot of on-disk state MUST NOT assert a determined negative about that state once the snapshot may be stale. It MUST detect staleness and return could-not-determine, naming what changed. A snapshot licenses claims about the snapshot, never about the directory.
- **FR-027**: Any count reported about source material MUST carry evidence the material did not change during the measurement.
- **FR-028**: Every known gap MUST be recorded with its reason and who may lift it.
- **FR-029**: An independent review MUST confirm that no claim is unearned, and its findings MUST be recorded whether or not they are acted on.

### Boundary

- **FR-030**: Session records are authored from PRIVATE recorded material while the umbrella is PUBLIC. **No recorded content, participant name, or verbatim transcript text may cross into the public repository.** Records refer to private material by location, never by content.

### Key Entities

- **Session record** — the four sections for one chapter. Cumulative over all prior sessions.
- **Record item** — one entry in a section. Has originating session, text, status, and for a carried item a slip count.
- **Session plan** — what a session intended to cover. The thing coverage is measured against.
- **Carry-forward link** — the relation from an uncovered planned point to its re-planned successor, carrying the slip count.
- **QA scenario** — one testable step: what to do, the expected result, and how to report a discrepancy.
- **Evidence artefact** — machine-produced output supporting a claim, identifying the state it came from.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: **100%** of chapters carry all four sections with session-specific content; chapters with an empty or generic section number **0**, against a baseline of 3 of 3 having none.
- **SC-002**: **100%** of record items identify their originating session.
- **SC-003**: **100%** of planned points resolve to covered, carried forward, or explicitly dropped; points that vanish number **0**.
- **SC-004**: **100%** of carried-forward points are visually distinguished and show their slip count.
- **SC-005**: **100%** of published areas present lessons with real content.
- **SC-006**: **100%** of published areas either present a takeable test or state why there is none; unexplained absences number **0**.
- **SC-007**: A tester unfamiliar with the platform completes the QA document **without asking a question**, and every step's expected result was stated before they performed it.
- **SC-008**: **100%** of known limitations are disclosed in the QA document before a tester can reach them; limitations discovered as apparent defects number **0**.
- **SC-009**: **100%** of capability claims resolve to a machine-produced artefact, or are explicitly marked unverified.
- **SC-010**: **0** checks record a could-not-determine as satisfied.
- **SC-011**: **100%** of checks ship a data-driven paired demonstration.
- **SC-012**: Re-running any evidence producer on unchanged inputs reproduces its result **100%** of the time.
- **SC-013**: **0** items of private recorded content appear in the public repository.
- **SC-014**: An independent review completes and its findings are recorded; findings suppressed rather than recorded number **0**.
- **SC-015**: A client-facing walkthrough of the platform completes with **0** steps that cannot be performed as described.

## Assumptions

- **Session records are authored, not generated.** They summarise what happened; a machine can enforce structure, completeness and carry-forward, but the content is authored.
- **A "chapter" is a recorded working session.** Three exist.
- **The QA team is unfamiliar with the platform.** The document assumes no prior knowledge.
- **Carry-forward is derived at build time** from recorded plan and coverage, so it cannot drift from what actually happened.
- **12 areas will still carry no test**, honestly, because their evidence does not support one. That is the correct state and SC-006 is written to accept it, provided the reason is stated.
- **3 documents remain unpublished** pending a human reading their uncited claim blocks. A client sees 39 areas; that is disclosed rather than concealed.
- **"No gaps, no weak spots" means every gap is known and stated**, not that none exists. A specification claiming zero gaps would be the first unearned claim in it.

## Dependencies

- The recorded sessions and their transcripts, referenced by location only.
- The existing area, lesson, material and assessment surfaces.
- The existing three-valued gate suite and its paired-proof discipline.
- The content-boundary instrument, which governs FR-030.

## Out of Scope

- Authoring assessments for areas whose evidence does not support them.
- Publishing the 3 documents that fail review; that awaits a human reading.
- Rewriting published history in any repository.
- Automating the authorship of session content; only its structure, completeness and carry-forward are mechanised.
