---
description: "Task list for Knowledge Areas & Bidirectional Deep Linking"
---

# Knowledge Areas & Bidirectional Deep Linking — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: use `superpowers:subagent-driven-development`
> (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** turn the workshop from a media viewer into a curriculum — a knowledge layer of areas,
terms, lessons and provenanced questions, joined to the transcript, the recording and the code by
one bidirectional graph, searchable end to end, and produced by a pipeline the next chapter runs
through unchanged.

**Architecture:** the knowledge layer is derived from the existing passage registry and mints its
identifiers through the **same minter**, so every link inherits a survival property that is already
measured rather than a new one that would have to be proven. Mentions are the join: term or area →
passage → text span, and for media-backed passages a time span at one of two explicitly-labelled
precisions. Areas, terms, lessons and questions join the existing two-leg search rather than
arriving with a second one. The front end gains the reference module's learning vocabulary and
subordinates the media views it already has.

**Tech stack:** Go 1.26.2 · Angular 19.2 standalone (Karma/Jasmine, Playwright) · SQLite + FTS5 ·
the existing identity library consumed from `submodules/passage` · fusion and reranking consumed
from the existing retrieval library · Python 3.14.6 + Bash for the pipeline · a Markdown converter,
an HTML-to-PDF renderer and a Mermaid renderer for export, **all user-local on this host and
therefore capability-probed, never assumed**.

## Global constraints

Every task's requirements implicitly include this section. Values are copied verbatim from
`spec.md` and `research.md` — do not round them and do not "improve" them.

- **Shape from the reference, substance from our own chapters** (FR-004, FR-004a). The reference
  holds **34 finished area documents** and **785 finished questions** about a different subject, in
  a **private** repository. Copying them would be faster, would survive a superficial review, and
  would be worthless. This is the single easiest way for this feature to go wrong.
- **One minter, five new kinds** (D-KG-2). No identifier derives from text, title, slug, ordinal,
  heading or position. The reference's positional question code is **not** ported as a linkage.
- **The graph is keyed on the passage identifier; never on a time** (FR-033b, D-KG-5). A time-keyed
  graph does not break loudly — it keeps resolving and points a few seconds off.
- **Mention precision is two-valued and always declared** (FR-021, D-KG-1). Measured: 15,610 words,
  **15,535 (99.52%) join to a segment, 75 (0.48%) do not**; word probability p05 **0.559**, p50
  **0.997**; **17.4%** below the flag threshold. Segment durations: median **6.74 s**, p95
  **10.78 s**, max **20.22 s**.
- **A question without a resolving citation is withheld** (FR-036, D4). Withholding is the default
  path, not an error path. The reference's measured value for this property is **0 of 785**.
- **A long-set question cites more than one distinct passage** (D-KG-7). This is the structural
  distinction between short and long; perceived difficulty is not reproducible.
- **The match-offset field is currently a promise that is never kept.** It is declared and set
  unconditionally to empty; the snippet uses empty delimiters. Either populate it or remove it and
  state its absence (FR-029, C4.1.3).
- **Existing latency thresholds are not renegotiated by corpus growth**: suggestions ≤ 200 ms p95,
  results ≤ 2 s p95, ≥ 90% top-5 on a ≥20-query benchmark.
- **Every check is three-valued**: `0` fine · `1` a real problem found · `2` could not determine. A
  missing dependency, unreachable service or crashed helper is always `2`. This conflation has been
  found and fixed four times in this repository.
- **Every check owes a paired mutation proof that includes a case running the real entry point
  against the real tree** (FR-053, SC-027). Two proofs have already shipped here that could not
  fail.
- **No server-side CI anywhere in the fleet** (FR-056, SC-030). The fleet-wide gate sweeps
  submodules, so an attempt will be caught.
- **Redaction reaches all eight propagation targets** (FR-027). Enumerated in `data-model.md` §5.
- **No coverage threshold, no area count target** (research U2, U3). Figures are measured and
  published; a guessed target gets optimised toward.
- **Three open clarifications bound real work.** Prose authorship bounds materials (Phase 4); the
  on-screen-content question bounds ingestion (out of scope until answered); the answering defect
  bounds generation over the new kinds (Phase 10). **Tasks blocked on them say so.**

## Task format

```
[ID] [markers] [Story] Description
```

**Markers**: `[P]` parallelisable · `[TDD]` test-first · `[REVIEW]` review before proceeding ·
`[SUBAGENT]` delegable · `[BLOCKED]` waiting on a named clarification or unverified entry.

**Numbering is permanent.** Ids are never reused or renumbered — other documents and agent reports
cite them, so renumbering silently invalidates every citation.

## Standing rules

1. **An assertion that greps for a string is not a test.** It must execute the behaviour and check
   the observable result. This repository has shipped an assertion that stayed green while the
   thing it tested was deleted.
2. **A task MUST NOT assume a capability nobody has verified.** Where a task depends on an
   unverified entry, it names the entry and names the task that settles it.
3. **No frozen host assumptions.** Export tooling, diagram tooling and word-timing availability are
   all **detected**, with environment overrides. Every export tool on this host resolves into a
   user-local directory.
4. **No stage writes to a source.** Sources open read-only; derived artifacts land only in derived
   locations.
5. **Never edit a shell script while it is executing.**
6. **Nothing from the reference module's content enters the workshop**, including as a placeholder,
   a fixture, or a template with the words left in.

---

## Phase 1: Setup

**Purpose**: make the new packages buildable and their dependencies real.

- [ ] T001 Create `workshop/platform/backend/pkg/knowledge/` and `pkg/assessment/` — **`pkg/`, not
      `internal/`**: Go's `internal/` is importable only from within its own module, so it forecloses
      reuse by language rule rather than by style, and the platform's decoupling requirements forbid
      it for anything reusable
- [ ] T002 Create `workshop/pipeline/{extract,mentions,authoring}/` beside the existing pipeline
      stages, so the chapter-addition path **gains steps rather than being rewritten**
- [ ] T003 [P] Scaffold the four new front-end feature directories under
      `workshop/platform/frontend/src/app/features/{areas,practice,progress,plans}/`, mirroring the
      existing feature-directory conventions
- [ ] T004 [P] Extend the capability probe in `workshop/scripts/_capabilities.sh` to
      **capability-probe** the export and diagram toolchain — invoke each tool with the flag that
      matters, never `--version`. Gate **G-KG-9** precondition
- [ ] T005 [P] Add a per-chapter word-timing detector: presence of a word sidecar is a **per-chapter**
      fact (contract V2), never a corpus-wide assumption
- [ ] T006 [REVIEW] Confirm the module still adds zero CI: `git -C workshop ls-files` must show no
      active workflow file, and the fleet-wide gate must pass

---

## Phase 2: Foundational — identity, mentions, resolution

**Purpose**: the contract everything else depends on. **No user story may begin until this phase is
complete**, because every later artifact points at something through the mechanism built here.

- [ ] T007 [TDD] [REVIEW] Implement minting for the five new entity kinds in
      `pkg/knowledge/identity.go`, delegating to the **existing** minter — no second minter, no
      second format (contract §1 M1–M5)
- [ ] T008 [TDD] Prove **G-KG-13** in `pkg/knowledge/identity_test.go`: run every stage twice over
      unchanged input and assert **zero mints**, a byte-identical taxonomy file, and no source file
      modified. **Paired mutation**: make minting unconditional whenever no anchor was read this run;
      the gate must go red on all three assertions simultaneously
- [ ] T009 [TDD] Prove identifiers are neither content-derived nor positional: rename an area, fix a
      term's canonical form, reorder questions, shift a heading — assert **no** identifier changed.
      **Paired mutation**: key an area on its slug; the gate must go red. This reproduces, for the new
      kinds, the exact defect already measured and gated for passages
- [ ] T010 [TDD] Implement the mention model in `pkg/knowledge/mention.go` with **precision as a
      required field on every time-carrying mention** — no default, because a default makes every
      unjoined mention claim word accuracy (contract §3 N1)
- [ ] T011 [TDD] Implement the word-sidecar time join in `workshop/pipeline/mentions/join.py`
      following contract §3 exactly: word join succeeds ⇒ `word` precision plus the word's timing
      confidence; word join fails ⇒ `segment` precision against the enclosing segment. **Both
      branches are real** — 99.52% and 0.48% measured
- [ ] T012 [TDD] Prove **G-KG-4** and **G-KG-15**: assert every time-carrying mention declares its
      precision, and that the unjoined fraction is **measured and reported**, never assumed zero.
      **Paired mutations**: (a) omit precision and default it to `word`; (b) treat an unjoined
      occurrence as `word` precision at the segment start. Both must go red
- [ ] T013 [TDD] Implement segment-boundary spanning: an occurrence crossing a seam emits **one
      mention per segment it touches** (FR-022). Attaching it to one loses half its evidence, and
      evidence counts are what publication decisions rest on
- [ ] T014 [REVIEW] Settle **U5** — do the 75 unjoined words cluster or scatter? Plot their time
      distribution against the measured silence spans. Three-valued exit. A cluster indicates a
      segmentation defect worth knowing about **before** mentions are built on it; scatter means the
      fallback branch is uninteresting. Record under `workshop/evidence/`
- [ ] T015 [TDD] Wire all new-kind resolution through the **one existing** resolution function with
      its four outcomes — found · redacted · not present · could not determine. **No second path and
      no fallback**: no fuzzy text match, no nearest neighbour, no prefix match, no same-hash lookup
- [ ] T016 [TDD] Prove **G-KG-8**: delete a link target and assert a loud outcome. **Paired
      mutation**: make the resolver re-point by nearest text match; the gate must go red. A silently
      re-pointed link is the one outcome the whole identity model exists to prevent
- [ ] T017 [TDD] Prove that **could not determine is never collapsed into not present**: make the
      registry unreadable and assert the fourth outcome. **Paired mutation**: map an unreadable
      registry to not-found; the gate must go red — that collapse makes a broken database look like a
      curriculum that never contained the passage
- [ ] T018 [TDD] Implement bidirectional traversal in `pkg/knowledge/graph.go`, **derived from
      mentions and citations** rather than from stored reverse edges. Two representations of one fact
      can disagree, and the disagreement has no symptom
- [ ] T019 [TDD] Prove **G-KG-6**: inspect every stored relationship for its join key and assert none
      is a time. **Paired mutation**: introduce one time-keyed link; the gate must go red
- [ ] T020 [TDD] Implement cycle-safe traversal with a visited set and a depth bound, **reporting
      truncation** rather than stopping silently — matching how the existing cross-reference response
      already reports truncation
- [ ] T021 [P] [TDD] Extend redaction propagation to all **eight** targets in `data-model.md` §5.
      Gate **G-KG-7**. **Paired mutation**: skip exactly one target; the gate must go red
- [ ] T022 [REVIEW] Review the knowledge contract implementation before anything consumes it —
      every other component depends on its shape, and a shape changed after adoption is a migration

**Checkpoint**: identity, precision, resolution and traversal are proven. Stop for human approval.

---

## Phase 3: User Story 1 — the taxonomy and its materials (P1) 🎯 MVP

**Goal**: areas exist as first-class entities, evidenced, with materials.

**Independent test**: open the area list, pick five at random, confirm each has materials in the
seven-section skeleton and that every substantive claim carries a citation that resolves.

- [ ] T023 [US1] [TDD] [REVIEW] Implement **promotion** of the five existing prose areas in
      `workshop/pipeline/extract/promote.py` per contract §2.1: mint identifiers, evidence each
      against the corpus, adopt the existing document as materials and its headings as lesson
      sections. **Do not rewrite the prose as a side effect of promotion**
- [ ] T024 [US1] [TDD] Implement **P2**: an area acquiring zero evidencing mentions **fails promotion
      loudly**. It is neither published unevidenced nor silently dropped, and both outcomes are
      reported. Gate **G-KG-10**. **Paired mutation**: publish one with its mentions removed
- [ ] T025 [US1] [TDD] Implement the significance measure in `workshop/pipeline/extract/significance.py`
      per contract §2.2 E2/E3 — combining distinctiveness against a general-language baseline,
      distribution across the corpus, and corroboration in the workshop's own written material.
      **Raw frequency alone is disqualified**: frequency-ranking a spoken corpus returns function
      words. The measure **prints its inputs** so the arithmetic can be audited
- [ ] T026 [US1] [TDD] Implement area and term extraction in `workshop/pipeline/extract/derive.py`.
      **No area count is targeted** (E5, research U3) — the corpus evidences what it evidences.
      Reading the reference module from this stage is forbidden
- [ ] T027 [US1] [TDD] Implement the three reconciliation branches per contract §2.3: **R1 attaches**,
      **R2 adds**, **R3 contradicts ⇒ reported for a decision, neither merged nor discarded**
- [ ] T028 [US1] [TDD] Prove **G-KG-14**: seed a contradiction, assert it appears in the report and
      that neither a merge nor a discard occurred. **Paired mutation**: make R3 fall through to R1
      above a similarity threshold; the gate must go red. Merging on overlap silently redraws a
      boundary a human drew
- [ ] T029 [US1] [TDD] Implement passage accounting per contract §2.4: `attached + classified_unattached
      == registry_count`, **exactly**. Publish the attached proportion as a **measured figure with no
      threshold** (research U2). The check is arithmetic — a total, not a ratio — so it cannot be
      satisfied by redefining what counts as attached
- [ ] T030 [US1] [TDD] Implement uncertainty marking: a low-confidence term is marked `uncertain`
      (FR-011), and an area evidenced **only** by uncertain passages is marked `uncertain-only`
      (FR-012). 267 of 1,101 passages are uncertain, so this is not a rare branch
- [ ] T031 [US1] [BLOCKED: prose authorship] [REVIEW] Author area materials in the **seven-section
      skeleton**, adapting the two interview-specific sections to the workshop's subject. **Blocked
      on the first clarification** — extractive assembly, agent-authored at build time, and run-time
      generation are three different pieces of work, and this host has **no generative model**, so
      the third cannot run here today
- [ ] T032 [US1] [TDD] Implement the authored/assembled marking on every lesson section (FR-017,
      contract W1). Build the field regardless of how the clarification resolves — it costs one field
      and keeps all three options shippable without a schema change
- [ ] T033 [US1] [TDD] Implement claim citation enforcement (contract W2): every substantive claim
      carries a resolving citation **or** is visibly marked as editorial framing that is not workshop
      content. There is no unmarked, uncited claim
- [ ] T034 [US1] [TDD] Implement the publication review record and its **staleness rule**: a review
      older than the materials it reviews **fails**, it does not warn (contract W3). Recording
      *"nothing to change"* is valid; skipping the review is not
- [ ] T035 [US1] [TDD] Implement the seven-section presence check across every area source document
      (SC-005). Any missing section fails
- [ ] T036 [US1] Implement the taxonomy source file with the same byte-stability discipline the
      passage registry already has — sorted, fixed key order, final newline — so a diff means a change
- [ ] T037 [US1] [TDD] Implement `GET /api/areas` per wire contract §3.1, including **A3.1.2**: report
      the count of areas held back and why. A client cannot distinguish five areas existing from
      eleven existing and six failing publication unless told
- [ ] T038 [US1] [TDD] Implement `GET /api/areas/{area}` per §3.2, and `GET /api/terms` and
      `GET /api/terms/{term}` per §3.4 — including the significance measure **and its inputs** on the
      single-term response
- [ ] T039 [US1] [TDD] Implement **A3.4.2**: a term whose last evidence is redacted is **withdrawn
      from the taxonomy**, not merely unlinked
- [ ] T040 [US1] Add route-manifest rows and contract sections for every endpoint above (FR-059).
      Gate **G-KG-1**. An endpoint built but undeclared fails the server-unity verifier by
      construction — that is deliberate and must not be "fixed" by loosening the verifier
- [ ] T041 [US1] [REVIEW] Human checkpoint: the reconciliation of promoted against extracted areas.
      A wrong merge here is a wrong curriculum, and every later artifact inherits it
- [ ] T042 [US1] [REVIEW] Record the content boundary check **in both directions** before anything is
      published (SC-029, SC-029a)

**Checkpoint**: areas exist, are evidenced, have materials and a recorded review. Stop for approval.

---

## Phase 4: User Story 2 — deep linking (P2)

**Goal**: any point reaches every related point, both ways.

**Independent test**: enumerate every relationship, traverse it in reverse, confirm the origin comes
back. No interface required.

- [ ] T043 [US2] [TDD] Implement `GET /api/areas/{area}/evidence` per §3.3, with **precision required**
      on every time-carrying entry and the word's timing confidence carried where precision is `word`
- [ ] T044 [US2] [TDD] Implement **A3.3.3**: a redacted passage contributes no mention and the omitted
      count is reported, matching the existing cross-reference behaviour
- [ ] T045 [US2] [TDD] Implement `GET /api/passages/{pid}/knowledge` per §3.7 — the reverse direction,
      and the endpoint that makes the recording navigable
- [ ] T046 [US2] [TDD] Implement **A3.7.1**: every entry is reachable in **one** step. A response that
      returns identifiers a client must resolve separately does not satisfy FR-019
- [ ] T047 [US2] [TDD] Implement **A3.7.3**: an unattached passage says it is unattached **and why**,
      rather than returning an empty list. "No areas" and "not yet classified" are different facts and
      an empty list reads as the first
- [ ] T048 [US2] [TDD] Implement `GET /api/graph/traverse` per §3.8 across all four content kinds
- [ ] T049 [US2] [TDD] Implement **A3.8.3**: a hop whose target cannot be resolved **reports its
      outcome and continues**; it is never dropped, because a dropped hop is indistinguishable from a
      hop that never existed
- [ ] T050 [US2] [TDD] Implement the six-row connectivity matrix (FR-033a) and its exercise harness.
      **A row with zero exercised origins fails** — an unexercised traversal is unmeasured, not
      passing (SC-015a)
- [ ] T051 [US2] [TDD] Prove **SC-008** over the **whole** relationship set, not a sample: a one-way
      link is indistinguishable from a two-way one when read forward, so sampling cannot find it
- [ ] T052 [US2] [TDD] Prove **SC-009**: every media-backed citation lands inside its cited span,
      **and the precision split is published** alongside the pass rate. A 100% pass at segment
      precision and at word precision are different products, and a test that only asserts "inside the
      span" cannot tell them apart
- [ ] T053 [US2] [TDD] Prove **SC-010**: replay the identifier-survival experiment extended to all
      five new kinds; compare the full link set before and after **by hash**
- [ ] T054 [US2] [P] Add route-manifest rows and contract sections for the endpoints in this phase
- [ ] T055 [US2] [P] [SUBAGENT] Build the transcript-to-knowledge affordance in the existing
      transcript view — the entry point for "what is being taught at this moment"
- [ ] T056 [US2] [REVIEW] Review the link model against the contract before the surface consumes it

**Checkpoint**: the graph is complete and bidirectional, and both precisions are honest.

---

## Phase 5: User Story 3 — search over everything (P3)

**Goal**: all four content kinds searchable, every hit says where.

- [ ] T057 [US3] [TDD] Index the four new kinds — `area`, `term`, `lesson_section`, `question` —
      indexing **their own text**, not only the passages they cite. A question findable only through
      its citations is not findable by anyone who does not already know the answer (D-KG-10)
- [ ] T058 [US3] [TDD] Advertise the new kinds in the corpus block, and prove **G-KG-11**: an
      advertised kind must be **retrievable**, proven by a planted known target — **not** by a row
      count, which cannot distinguish a populated index from a populated table nobody queries. The
      corpus already advertises one kind with zero entries
- [ ] T059 [US3] [REVIEW] Settle **U1** before implementing offsets: does the full-text engine expose
      match positions through a supported interface, or must offsets be recomputed by re-locating
      query terms in the matched text? Three-valued exit. This has a correctness edge — a
      recomputation can disagree with what the index actually matched, particularly under the prefix
      matching the lexical leg applies to the final query token. **T060 is blocked on this**
- [ ] T060 [US3] [TDD] [BLOCKED: U1 / T059] Implement match offsets per **C4.1.3**: the lexical leg
      produces real offsets, **or** the field is removed and its absence stated. Leaving a field that
      promises a position and never carries one is forbidden. Gate **G-KG-5**. **Paired mutation**:
      return an empty offset list from a leg that could produce offsets
- [ ] T061 [US3] [TDD] Implement **C4.1.4**: the semantic leg reports that it **cannot** produce
      offsets — a different fact from producing none. One empty list meaning both is exactly the
      collapse this contract exists to prevent
- [ ] T062 [US3] [TDD] Implement the locus on every hit per **C4.1.2**, and withhold any hit whose
      locus does not resolve (FR-030)
- [ ] T063 [US3] [TDD] Prove **SC-014** over **every** hit of the benchmark run — a hit without a
      resolving locus fails the run, not merely itself
- [ ] T064 [US3] [TDD] Implement kind and area filters per **C4.1.5**, echoing the applied filter so a
      client can tell a filtered empty result from an unfiltered one
- [ ] T065 [US3] [TDD] Add area and term names to suggestions per **C4.2.1**, and prove **C4.2.2**:
      the suggestion service still holds **no embedder**. Type-ahead stays lexical — semantic
      embedding under load has been observed in the tens of seconds against a 200 ms budget
- [ ] T066 [US3] Build the ≥20-query benchmark for the new kinds in the platform's existing benchmark
      directory, beside the gates that read it, with expected identifiers fixed **in advance**
- [ ] T067 [US3] [TDD] Prove **SC-015**: the gate prints **per-query** outcomes, not only the
      aggregate — which queries fail is the useful information, and an aggregate hides it
- [ ] T068 [US3] [TDD] Prove **SC-016 / SC-017**: re-run the latency harness and **publish before and
      after together**. A single after-figure cannot show a regression that stayed inside the threshold
- [ ] T069 [US3] [P] [SUBAGENT] Extend the search view for the new kinds, the filters and the locus
      display
- [ ] T070 [US3] [P] Update the route manifest and contract for the changed search and suggest
      endpoints

**Checkpoint**: everything is searchable and every hit says where — or honestly says it cannot.

---

## Phase 6: User Story 4 — provenanced assessment (P4)

**Goal**: the property the reference module does not have, at 100%.

- [ ] T071 [US4] [TDD] Implement the question model in `pkg/assessment/question.go`, porting the
      reference's field shape and **adding the mandatory citations field**. This is the feature's one
      deliberate divergence and the reason it exists
- [ ] T072 [US4] [TDD] Implement **Q1 / G-KG-2**: a question is served **only** if it carries at least
      one citation and **every** citation resolves. A citation resolving to redacted, not-present or
      could-not-determine ⇒ **withheld**. Not served with a warning, not with the citation stripped,
      not with an empty list. **Paired mutation**: serve it with the citation stripped
- [ ] T073 [US4] [TDD] Implement **Q2 / G-KG-3**: every long-set question cites **more than one
      distinct** passage. **Paired mutation**: admit a single-citation question to the long set
- [ ] T074 [US4] [TDD] Implement **Q3**: every question names the lesson sections it assesses — this
      is what makes per-section coverage measurable rather than estimated
- [ ] T075 [US4] Author the short and long question sets **from the workshop's own passages** (Q5).
      **Nothing from the reference's 785 items may appear**, including as a placeholder
- [ ] T076 [US4] [TDD] Implement **G-KG-16**: plant one reference question in a workshop bank and
      assert the boundary check fails. **Paired mutation**: scope the check to the outbound direction
      only. It runs both ways deliberately — outbound keeps a private recording out of public
      repositories, inbound keeps the workshop from shipping someone else's curriculum
- [ ] T077 [US4] [TDD] Implement the assembled-answer marking per **Q4 / A3.5.4** — a client must not
      have to infer it
- [ ] T078 [US4] [TDD] Implement `GET /api/areas/{area}/questions` per §3.5, including **A3.5.5**:
      report how many questions were withheld and why. A silently shorter set is how a provenance
      guarantee decays into a claim without anyone noticing
- [ ] T079 [US4] [TDD] Implement `GET /api/areas/{area}/coverage` per §3.6: **per-area figures,
      never only an aggregate**; sections with zero questions listed explicitly; **no threshold and no
      pass field**. Gate **G-KG-12**. **Paired mutation**: replace the per-area table with a mean
- [ ] T080 [US4] [TDD] Prove **SC-018** by enumerating every served question and resolving every
      citation, and **record the reference module's measured value — 0 of 785 — beside it**, so the
      comparison is measured rather than claimed
- [ ] T081 [US4] [TDD] Prove **SC-019**: the question-to-moment-and-back round trip, over every
      eligible question; if impractical, a seeded sample of ≥30 **with the population size published**
- [ ] T082 [US4] [TDD] Extend progress to areas and question sets, and prove **C4.4.2**: progress
      **survives a content re-ingest**. The reference deliberately preserves its progress table while
      wiping everything else; a learner's history is not a derived artifact
- [ ] T083 [US4] [P] Add route-manifest rows and contract sections for the assessment endpoints
- [ ] T084 [US4] [REVIEW] Review question provenance end to end before the practice surface consumes
      it

**Checkpoint**: every served question is traceable to the moment that teaches it.

---

## Phase 7: User Story 5 — the learning surface (P5)

**Goal**: a learning platform, with its own identity, that loses nothing it already had.

- [ ] T085 [US5] **Enumerate the four existing capabilities — chapter list, transcript, recording
      player, cross-references — and write the list down BEFORE any reshaping**. SC-023 is a
      before-and-after comparison, and a list reconstructed afterwards is a recollection, not a
      measurement
- [ ] T086 [US5] [P] [SUBAGENT] Build the area list and area detail views
- [ ] T087 [US5] [P] [SUBAGENT] Build the practice view with the question-to-moment jump and return
- [ ] T088 [US5] [P] [SUBAGENT] Build the progress view across areas
- [ ] T089 [US5] [P] [SUBAGENT] Build the study-plan view
- [ ] T090 [US5] Subordinate the existing media views under areas per **D2** — reachable from within
      an area rather than as top-level objects. They are the working half of what exists and are what
      makes a timestamp jump possible at all
- [ ] T091 [US5] [TDD] Prove **SC-023** against T085's written list: every enumerated capability is
      still reachable
- [ ] T092 [US5] Give the workshop its own token **values** against the shared contract. **Do not
      fork the component library** — forking doubles maintenance and guarantees drift (FR-043)
- [ ] T093 [US5] [TDD] Prove **SC-022** with **both** checks: the design toolkit's token conformance
      check **and** a literal-value scan. Either alone passes a stylesheet that defines perfect tokens
      and ignores them
- [ ] T094 [US5] [BLOCKED: UX research] Implement interaction and motion from the platform's ranked,
      sourced user-experience research, each decision naming the finding it rests on (FR-044a). An
      effect with no supporting finding does not ship on the grounds that it looks better
- [ ] T095 [US5] [TDD] Implement reduced-motion support: final visual state preserved without the
      transition, and no effect load-bearing for comprehension (FR-044b)
- [ ] T096 [US5] [TDD] Prove **SC-021**: an automated audit per view plus a keyboard-only traversal
      that **visits every deep-link affordance** and asserts each can be reached, activated and
      returned from

**Checkpoint**: the product is a learning surface and nothing was lost getting there.

---

## Phase 8: User Story 6 — four-format export (P6)

- [ ] T097 [US6] Port the export toolchain design as-is, driving it from the **capability probe** in
      T004 rather than from a name on `PATH`
- [ ] T098 [US6] [TDD] Implement **G-KG-9**: an unavailable toolchain yields **could not determine**,
      never an empty format list (FR-049). **Paired mutation**: return an empty list instead
- [ ] T099 [US6] [TDD] Implement the publication precondition: an area without a review exports
      nothing **and says so** (FR-048, A3.9.1)
- [ ] T100 [US6] [TDD] Implement citation preservation across all four formats (FR-047)
- [ ] T101 [US6] Port diagram rendering from text source — reproducible, unlike an embedded binary
      (FR-014a)
- [ ] T102 [US6] [TDD] Prove **SC-024**: the file-existence matrix must be **complete**. Record the
      reference's measured 25-of-34 beside it, so nobody later matches the reference and calls it done
- [ ] T103 [US6] [TDD] Prove **SC-025** by **extracting text and diffing**, not by byte comparison —
      embedded timestamps make byte equality unachievable for some formats, and a criterion nobody can
      meet is worse than none

---

## Phase 9: User Story 7 — the repeatable pipeline (P7)

**Goal**: the next chapter runs through unchanged. This is the phase that distinguishes a finished
chapter from a finished feature.

- [ ] T104 [US7] Extend the platform's **existing** chapter-addition procedure and its prompt with the
      knowledge-layer stages. **Do not create a second way to add a chapter** (S1) — two procedures
      for one act guarantee one of them rots
- [ ] T105 [US7] [TDD] Implement three-valued exits and resumability on every new stage (S3, S4), with
      progress projected from **measured rate**, never from an estimate
- [ ] T106 [US7] [TDD] Implement the taxonomy **update** path (S6): established areas keep their
      identifiers and gain evidence, newly evidenced areas are added, contradictions are reported
- [ ] T107 [US7] [TDD] Prove **SC-015d**: capture the taxonomy before and after, assert **0**
      established identifiers changed and the contradiction report is non-empty when one was seeded.
      **Paired mutation**: re-derive area identifiers on each run
- [ ] T108 [US7] Build a **small synthetic chapter** fixture — synthetic, because it must contain no
      workshop content and it must exercise the **minting** path
- [ ] T109 [US7] [TDD] Prove **G-KG-17 / SC-015c**: run the whole pipeline against the synthetic
      chapter; assert every output in S2 exists and the diff contains **no hand-created structural
      file and no code change**. **Paired mutation**: remove one stage; the gate must go red naming
      the missing output.
      **Do not substitute a re-run of the real chapter.** That tests idempotency, which is SC-004; it
      cannot test whether a *new* chapter works, because every identifier it needs already exists — the
      run would pass by matching and never by minting
- [ ] T110 [US7] [TDD] Prove **G-KG-18 / SC-015e**: withhold one required input; assert the run names
      exactly what is missing and publishes nothing. **Paired mutation**: downgrade it to a warning
- [ ] T111 [US7] [TDD] Prove **S7**: no stage writes to a source. Assert every source file's size,
      modification time and inode are unchanged after a full run. **Paired mutation**: have a stage
      rewrite a source in place
- [ ] T112 [US7] [TDD] Prove **S8**: evidence is written for every outcome, **especially** could not
      determine — the run that determined nothing is the one a reader most needs the record of.
      **Paired mutation**: skip evidence writing on the could-not-determine path

**Checkpoint**: the pipeline is observed producing a complete chapter, not reported as doing so.

---

## Phase 10: Polish and honest limits

- [ ] T113 [TDD] Extend retrieval — **not generation** — over the new kinds (C4.3.1). Safe because the
      retrieval gate refuses before any model runs
- [ ] T114 [REVIEW] Settle **U4**: does an entailment model load on this host? Three-valued exit. The
      platform's code claims it refuses to degrade silently; **a claim is not a measurement**
- [ ] T115 [BLOCKED: answering clarification / U4] [TDD] Implement the **answer-against-question**
      verification layer (FR-051) in the existing support-verifier seam. All four current layers
      verify the claim against the **passage**; none verifies it against the **question**, which is
      why a topically related fragment that does not answer what was asked passes all four
- [ ] T116 [BLOCKED: answering clarification] [TDD] Implement **C4.3.4**: a verifier that was
      requested and could not load reports **could not determine** and does **not** degrade to the
      weaker one
- [ ] T117 Update the shipped limits document to name **every** open defect, including the measured
      fabrication rate on unanswerable questions and the undefended
      topically-related-but-non-answering case (FR-050)
- [ ] T118 [TDD] Prove **SC-026**: cross-check recorded defects against the limits document; an
      unnamed defect fails. **Paired mutation**: remove one defect from the document
- [ ] T119 [TDD] Prove **SC-028**: drive every new check into a could-not-determine condition and
      assert the **third** state, not either of the other two
- [ ] T120 Register every new check in the check registry (SC-027). Note the registry prints known
      debt on every run **by design** — a zero exit means every check is accounted for, **not** that
      every check has a paired proof
- [ ] T121 Update the platform's documentation set — quickstart, user guide, manual, FAQ — for the
      knowledge layer, and state plainly what it cannot do
- [ ] T122 [REVIEW] Final content-boundary check **in both directions** (SC-029, SC-029a), plus the
      fleet-wide no-CI gate (SC-030), plus `CONTINUATION.md` synchronised

---

## Dependencies

- **Phase 2 blocks everything.** Every later artifact points at something through the identity,
  precision and resolution mechanism built there.
- **Phase 3 blocks Phases 4–9.** There is nothing to link, search, assess or export until areas
  exist.
- **Phase 4 blocks Phases 5–7.** Search locus, question jumps and the surface all navigate through
  the graph.
- **Phase 6 blocks Phase 7's practice view** (T087).
- **T059 blocks T060.** Offsets must not be implemented on an assumption about the index.
- **T114 blocks T115 and T116.**
- **T085 blocks T091.** The before-list must exist before the reshaping it measures.
- **T004 blocks T097 and T098.**
- **T031 is blocked on the prose-authorship clarification**; **T094** on the UX research;
  **T115/T116** on the answering clarification.

## Parallel opportunities

- Taxonomy extraction (Phase 3) and the front-end surface (Phase 7) — different languages, different
  directories, joined only by the knowledge contract.
- Question authoring (T075) and the export pipeline (Phase 8) — export consumes documents, not the
  process that wrote them.
- Documentation (T121) and the behavioural gates, once the contracts are fixed.

## Independent test criteria

| Story | Deliverable that stands alone |
|---|---|
| US1 | the taxonomy and the area documents — readable and citable with no interface |
| US2 | every relationship traversed in reverse through the platform's own interfaces |
| US3 | the benchmark run, with per-query outcomes and locus assertions |
| US4 | every served question enumerated and every citation resolved |
| US5 | each view opened and completed by keyboard, audited, token-checked |
| US6 | the format matrix and the re-export text diff |
| US7 | the synthetic-chapter run and its diff |

## Gate coverage — every contracted gate has a task that builds it

| Gate | Task |
|---|---|
| G-KG-1 | T040, T054, T070, T083 |
| G-KG-2 | T072 |
| G-KG-3 | T073 |
| G-KG-4 | T012 |
| G-KG-5 | T060 |
| G-KG-6 | T019 |
| G-KG-7 | T021 |
| G-KG-8 | T016 |
| G-KG-9 | T098 |
| G-KG-10 | T024 |
| G-KG-11 | T058 |
| G-KG-12 | T079 |
| G-KG-13 | T008 |
| G-KG-14 | T028 |
| G-KG-15 | T012 |
| G-KG-16 | T076 |
| G-KG-17 | T109 |
| G-KG-18 | T110 |

**18 gates, 18 paired mutations, all owed.** A gate never observed failing is not known to work, and
every proof must include a case that runs the real entry point against the real tree.

## Implementation strategy

Build Phase 2 completely and stop. It is the only phase whose defects are invisible — a wrong
identifier scheme, a conflated precision or a collapsed resolution outcome all keep rendering links
that look correct. Everything after it fails loudly by comparison.

Then take one area end to end — promoted, evidenced, authored, linked, searchable, assessed,
exported — before applying the pattern to the rest. A pattern proven on one area is cheap to correct;
the same mistake made across every area is a migration.

**Task count: 122**, contiguous `T001`–`T122`, verified by parsing this file rather than by counting.
