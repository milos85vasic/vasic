---
description: "Task list for Knowledge Areas & Bidirectional Deep Linking"
---

# Knowledge Areas & Bidirectional Deep Linking — Implementation Plan

> **TASK IDS ARE PER-FEATURE AND ARE NOT GLOBALLY UNIQUE — CITE THEM QUALIFIED.**
> This file and [`specs/001-workshop-curriculum-platform/tasks.md`](../001-workshop-curriculum-platform/tasks.md)
> number their tasks independently from `T001`, so the same id names two unrelated pieces of work
> in the two documents. **Measured 2026-09-03, the overlap is total, not an edge case: `T001`
> through `T120` — all 120 of feature 001's task ids — exist in both files meaning different
> things.** Only this file's `T121`–`T143` are unambiguous on their own. `T115` here is the
> answer-against-question verifier; `T115` in 001 is the `workshop/scripts/index.sh` wrapper.
> `T116` here is the verifier that could not decide; `T116` in 001 is the `crossref.sh` wrapper.
>
> **The requirement ids collide the same way, and by the same construction.** Measured the same
> day against the two `spec.md` files, which define their own ids independently from `001`:
> `SC-001`–`SC-021` (**21** ids) and `FR-001`–`FR-048` (**48** ids) are defined in both specs with
> different meanings. This feature's `SC-009` is a media-backed citation landing inside its cited
> span; 001's `SC-009` is citation support over generated answers. Unique to this file:
> `SC-015a`–`SC-015e`, `SC-017a`–`SC-017c`, `SC-022`–`SC-036`, `SC-029a`, `SC-029b`,
> `FR-049`–`FR-066` and `T121`–`T143`. Unique to 001: `SC-016a`.
>
> **Rule — prefix the feature number: `002:T115` vs `001:T115`, `002:SC-009` vs `001:FR-030`.**
> A bare `T115` in a brief, a commit message, a review or a source comment is ambiguous by
> construction. An unqualified citation of exactly this form already exists in the platform
> backend's own source at `workshop/platform/backend/pkg/answer/outcome.go`, where the pair it
> names is this file's; and two briefs written from these files are **reported** to have resolved
> a bare id to the wrong task — that report is recorded here as received and was not
> independently measured.
>
> **Ids are NOT renumbered to fix this.** Every existing cross-reference — in both `spec.md`
> files, in both `contracts/` trees, in `plan.md`, and in the implementation's own source
> comments — resolves against the current numbering, and renumbering would invalidate all of them
> at once. Qualification at the point of citation is the remedy; renumbering is not.

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
- ~~**Three open clarifications bound real work.**~~ ~~**Correction, 2026-09-02: "three" is now
  TWO."**~~ **Correction, later the same day: "two" is now ONE, and both earlier counts are
  WITHDRAWN rather than restated.** The block used to read: prose authorship bounds materials
  (Phase 4); the on-screen-content question bounds ingestion (out of scope until answered); the
  answering defect bounds generation over the new kinds (Phase 10). Two of those three are now
  decided:
  - **Answering — DECIDED, and now BUILT.** The operator took the product decision to build the
    verifier, and U4 (does an entailment model load on this host?) was measured settled by T114.
    ~~T115 and T116 are **unbuilt**, not blocked, and their markers say `[UNBUILT]`.~~ **WITHDRAWN
    2026-09-03, not restated:** both were built, wired, gated and pushed on 2026-09-02, their
    `[UNBUILT]` markers are discharged and both are ticked. See their own notes for the commands.
  - **On-screen content — DECIDED 2026-09-02.** The operator chose **spoken PLUS on-screen OCR**,
    extending this specification **in place** rather than opening a feature 003, and then chose to
    **specify now and build later**. It is written down as **Phase 11, tasks T123–T142**, sequenced
    after this specification's already-unbuilt tasks — **18 as of 2026-09-03 (second
    reconciliation)**, the figures of 28, then 26, then 23, then 22 this line carried being
    superseded by the T115/T116, T079/T083, T102 and T063/T066/T069/T117 ticks rather than wrong
    when written.
    `spec.md`'s Out of Scope entry excluding
    OCR is **withdrawn**; the decision and its reasoning are recorded as **D5**.
  - **Prose authorship (T031) — GENUINELY OPEN.** It is the ONE remaining clarification, and its
    `[BLOCKED: prose authorship]` marker is LIVE.

  **The on-screen decision moved this feature's finish line, and that is recorded here rather than
  discovered later: spec 002 cannot close until OCR accuracy is MEASURED** (SC-031 to SC-034) — not
  designed, not implemented, not reviewed. **Measured.** Speech-recognition accuracy in this project
  is a measured quantity with a recorded procedure (`workshop/pipeline/CALIBRATION.md`,
  `workshop/pipeline/compare_engines.py`, `workshop/scripts/verify-accuracy.sh` — all three present,
  measured 2026-09-02). On-screen text entering the same corpus at a lower evidentiary standard than
  the speech beside it would make the corpus's accuracy unknown while every published figure kept
  looking precise.

## Task format

```
[ID] [markers] [Story] Description
```

**Markers**: `[P]` parallelisable · `[TDD]` test-first · `[REVIEW]` review before proceeding ·
`[SUBAGENT]` delegable · `[BLOCKED]` waiting on a named clarification or unverified entry ·
`[UNBUILT]` the clarification or entry it once waited on is **settled** and the decision is taken —
what remains is code nobody has written. Added 2026-09-02 so a settled decision can never keep
wearing a `[BLOCKED]` marker, which reads as "not our move" when the move is ours.

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
7. **`SC-###` identifiers COLLIDE across specifications — always name the spec before citing one as
   acceptance.** Added 2026-09-03, after the ambiguity produced a wrong acceptance claim. The two
   specs number their success criteria independently and the same number means different things:

   | id | **this** spec (002) | spec **001** |
   |---|---|---|
   | SC-009 | a media-backed citation lands inside its cited span | 100% of answer citations genuinely support the claim |
   | SC-010 | identifier survival across correction and insertion — **proven here under T053** | on ≥10 unanswerable questions, **fabricates none** — **NOT met**; one fabrication survives |

   Re-derive before citing, never from memory:

   ```bash
   grep -n '^- \*\*SC-010\*\*' specs/001-workshop-curriculum-platform/spec.md \
                               specs/002-knowledge-areas-deep-linking/spec.md
   ```

   "SC-010 is proven" is TRUE of this spec and FALSE of 001. A bare `SC-010` in a note, a commit
   message or an agent report is therefore not a citation — it is an ambiguity, and it has already
   been resolved the wrong way once.

---

## Phase 1: Setup

**Purpose**: make the new packages buildable and their dependencies real.

- [x] T001 Create `workshop/platform/backend/pkg/knowledge/` and `pkg/assessment/` — **`pkg/`, not
      `internal/`**: Go's `internal/` is importable only from within its own module, so it forecloses
      reuse by language rule rather than by style, and the platform's decoupling requirements forbid
      it for anything reusable
- [x] T002 Create `workshop/pipeline/{extract,mentions,authoring}/` beside the existing pipeline
      stages, so the chapter-addition path **gains steps rather than being rewritten**
- [x] T003 [P] Scaffold the four new front-end feature directories under
      `workshop/platform/frontend/src/app/features/{areas,practice,progress,plans}/`, mirroring the
      existing feature-directory conventions
- [x] T004 [P] Extend the capability probe in `workshop/scripts/_capabilities.sh` to
      **capability-probe** the export and diagram toolchain — invoke each tool with the flag that
      matters, never `--version`. Gate **G-KG-9** precondition
- [x] T005 [P] Add a per-chapter word-timing detector: presence of a word sidecar is a **per-chapter**
      fact (contract V2), never a corpus-wide assumption
- [x] T006 [REVIEW] Confirm the module still adds zero CI: `git -C workshop ls-files` must show no
      active workflow file, and the fleet-wide gate must pass

---

## Phase 2: Foundational — identity, mentions, resolution

**Purpose**: the contract everything else depends on. **No user story may begin until this phase is
complete**, because every later artifact points at something through the mechanism built here.

- [x] T007 [TDD] [REVIEW] Implement minting for the five new entity kinds in
      `pkg/knowledge/identity.go`, delegating to the **existing** minter — no second minter, no
      second format (contract §1 M1–M5)
- [x] T008 [TDD] Prove **G-KG-13** in `pkg/knowledge/identity_test.go`: run every stage twice over
      unchanged input and assert **zero mints**, a byte-identical taxonomy file, and no source file
      modified. **Paired mutation**: make minting unconditional whenever no anchor was read this run;
      the gate must go red on all three assertions simultaneously
- [x] T009 [TDD] Prove identifiers are neither content-derived nor positional: rename an area, fix a
      term's canonical form, reorder questions, shift a heading — assert **no** identifier changed.
      **Paired mutation**: key an area on its slug; the gate must go red. This reproduces, for the new
      kinds, the exact defect already measured and gated for passages
- [x] T010 [TDD] Implement the mention model in `pkg/knowledge/mention.go` with **precision as a
      required field on every time-carrying mention** — no default, because a default makes every
      unjoined mention claim word accuracy (contract §3 N1)
- [x] T011 [TDD] Implement the word-sidecar time join in `workshop/pipeline/mentions/join.py`
      following contract §3 exactly: word join succeeds ⇒ `word` precision plus the word's timing
      confidence; word join fails ⇒ `segment` precision against the enclosing segment. **Both
      branches are real** — 99.52% and 0.48% measured
- [x] T012 [TDD] Prove **G-KG-4** and **G-KG-15**: assert every time-carrying mention declares its
      precision, and that the unjoined fraction is **measured and reported**, never assumed zero.
      **Paired mutations**: (a) omit precision and default it to `word`; (b) treat an unjoined
      occurrence as `word` precision at the segment start. Both must go red
- [x] T013 [TDD] Implement segment-boundary spanning: an occurrence crossing a seam emits **one
      mention per segment it touches** (FR-022). Attaching it to one loses half its evidence, and
      evidence counts are what publication decisions rest on
- [x] T014 [REVIEW] Settle **U5** — do the 75 unjoined words cluster or scatter? Plot their time
      distribution against the measured silence spans. Three-valued exit. A cluster indicates a
      segmentation defect worth knowing about **before** mentions are built on it; scatter means the
      fallback branch is uninteresting. Record under `workshop/evidence/`
- [x] T015 [TDD] Wire all new-kind resolution through the **one existing** resolution function with
      its four outcomes — found · redacted · not present · could not determine. **No second path and
      no fallback**: no fuzzy text match, no nearest neighbour, no prefix match, no same-hash lookup
- [x] T016 [TDD] Prove **G-KG-8**: delete a link target and assert a loud outcome. **Paired
      mutation**: make the resolver re-point by nearest text match; the gate must go red. A silently
      re-pointed link is the one outcome the whole identity model exists to prevent
- [x] T017 [TDD] Prove that **could not determine is never collapsed into not present**: make the
      registry unreadable and assert the fourth outcome. **Paired mutation**: map an unreadable
      registry to not-found; the gate must go red — that collapse makes a broken database look like a
      curriculum that never contained the passage
- [x] T018 [TDD] Implement bidirectional traversal in `pkg/knowledge/graph.go`, **derived from
      mentions and citations** rather than from stored reverse edges. Two representations of one fact
      can disagree, and the disagreement has no symptom
- [x] T019 [TDD] Prove **G-KG-6**: inspect every stored relationship for its join key and assert none
      is a time. **Paired mutation**: introduce one time-keyed link; the gate must go red
- [x] T020 [TDD] Implement cycle-safe traversal with a visited set and a depth bound, **reporting
      truncation** rather than stopping silently — matching how the existing cross-reference response
      already reports truncation
- [x] T021 [P] [TDD] Extend redaction propagation to all **eight** targets in `data-model.md` §5.
      Gate **G-KG-7**. **Paired mutation**: skip exactly one target; the gate must go red
- [ ] T022 [REVIEW] Review the knowledge contract implementation before anything consumes it —
      every other component depends on its shape, and a shape changed after adoption is a migration

      **NOT DONE (re-measured 2026-09-03, unchanged).** The brief exists
      (`workshop/docs/session-evidence/phase2e-brief.md`); **no `phase2e-report.md` was ever
      produced**, and `specs/002-knowledge-areas-deep-linking/` still has neither an `analysis.md`
      nor a `review.md` (spec 001 has both). Every consumer adopted the knowledge contract without
      the recorded review this task exists to require. **Do not mistake
      `workshop/docs/knowledge-model-contract.md` for the discharge** — it landed 2026-09-02 in
      `692a27a` at 1,372 lines and is a forward-looking *reusable model* contract (corpus layout,
      the area-document skeleton, the export pipeline, validator invariants). It reviews nothing
      that was built and names no task.

**Checkpoint**: identity, precision, resolution and traversal are proven. Stop for human approval.

---

## Phase 3: User Story 1 — the taxonomy and its materials (P1) 🎯 MVP

**Goal**: areas exist as first-class entities, evidenced, with materials.

**Independent test**: open the area list, pick five at random, confirm each has materials in the
seven-section skeleton and that every substantive claim carries a citation that resolves.

- [x] T023 [US1] [TDD] [REVIEW] Implement **promotion** of the five existing prose areas in
      `workshop/pipeline/extract/promote.py` per contract §2.1: mint identifiers, evidence each
      against the corpus, adopt the existing document as materials and its headings as lesson
      sections. **Do not rewrite the prose as a side effect of promotion**
- [x] T024 [US1] [TDD] Implement **P2**: an area acquiring zero evidencing mentions **fails promotion
      loudly**. It is neither published unevidenced nor silently dropped, and both outcomes are
      reported. Gate **G-KG-10**. **Paired mutation**: publish one with its mentions removed
- [x] T025 [US1] [TDD] Implement the significance measure in `workshop/pipeline/extract/significance.py`
      per contract §2.2 E2/E3 — combining distinctiveness against a general-language baseline,
      distribution across the corpus, and corroboration in the workshop's own written material.
      **Raw frequency alone is disqualified**: frequency-ranking a spoken corpus returns function
      words. The measure **prints its inputs** so the arithmetic can be audited
- [x] T026 [US1] [TDD] Implement area and term extraction in `workshop/pipeline/extract/derive.py`.
      **No area count is targeted** (E5, research U3) — the corpus evidences what it evidences.
      Reading the reference module from this stage is forbidden
- [x] T027 [US1] [TDD] Implement the three reconciliation branches per contract §2.3: **R1 attaches**,
      **R2 adds**, **R3 contradicts ⇒ reported for a decision, neither merged nor discarded**
- [x] T028 [US1] [TDD] Prove **G-KG-14**: seed a contradiction, assert it appears in the report and
      that neither a merge nor a discard occurred. **Paired mutation**: make R3 fall through to R1
      above a similarity threshold; the gate must go red. Merging on overlap silently redraws a
      boundary a human drew
- [x] T029 [US1] [TDD] Implement passage accounting per contract §2.4: `attached + classified_unattached
      == registry_count`, **exactly**. Publish the attached proportion as a **measured figure with no
      threshold** (research U2). The check is arithmetic — a total, not a ratio — so it cannot be
      satisfied by redefining what counts as attached
- [x] T030 [US1] [TDD] Implement uncertainty marking: a low-confidence term is marked `uncertain`
      (FR-011), and an area evidenced **only** by uncertain passages is marked `uncertain-only`
      (FR-012). 267 of 1,101 passages are uncertain, so this is not a rare branch
- [ ] T031 [US1] [BLOCKED: prose authorship] [REVIEW] Author area materials in the **seven-section
      skeleton**, adapting the two interview-specific sections to the workshop's subject. **Blocked
      on the first clarification, and on that alone** — extractive assembly, agent-authored at build
      time, and run-time generation are three different pieces of work, and nobody has decided which
      one this is. ~~This host has **no generative model**, so the third cannot run here today.~~
      **That sentence is WITHDRAWN, not restated, and it was false when written.** Measured
      2026-09-02: `ollama list` carries the generative `qwen2.5:3b-instruct-q4_K_M` (1.9 GB), and
      `podman inspect workshop-curriculum_platform_1 --format '{{.Config.Cmd}}'` shows
      `-answer-provider ollama -answer-model qwen2.5:3b-instruct-q4_K_M` in the RUNNING container's
      own argv — so the model is not merely installed, it is already wired into the platform's
      answer path. An entailment model loads on this host too, recorded under §10.12 of
      `workshop/docs/limits.md` as a DECIDED verdict (`entail=0.9924`). **All three options are
      therefore runnable here; what blocks this task is the clarification, not the host.** Re-derive
      with the two commands above rather than trusting this sentence — a host changes under you, and
      this task's text has already been wrong about it once.

      **PARTIAL (re-measured live 2026-09-03; the figures moved and the gap did not).** 5 area
      source documents exist under `workshop/docs/training/areas/`, each in the seven-section
      skeleton; `/api/areas` now serves **495** areas at generation **54** — re-verified later the
      same day at generation **67**, still 495 served against still 5 authored `.md` documents under
      `docs/training/areas/` — so **490** have no
      authored materials. **The 499/494 figures this note used to carry are superseded, not wrong
      when written**: 5 areas moved into `held_back` with reason `all_evidence_redacted` when the
      chapter-01 redactions of decision 26 were applied — publication liveness working, not
      authorship progress. The prose-authorship clarification is
      still open, and `pipeline/extract/verify.py` keeps `W2-claims-over-real-materials` and
      `W3-review-over-real-materials` in a separate `MATERIALS_STATUS_CHECKS` map — outside `GATES`
      and outside `--prove-failure` — naming this gap in its own comment. **The `[BLOCKED: prose
      authorship]` marker above is LIVE**, unlike the two stripped from T060 and T094 on the same
      day: the clarification it names is genuinely undecided. Do not tick this task on the strength
      of the host correction — the correction removes a false excuse, not the blocker.
- [x] T032 [US1] [TDD] Implement the authored/assembled marking on every lesson section (FR-017,
      contract W1). Build the field regardless of how the clarification resolves — it costs one field
      and keeps all three options shippable without a schema change
- [ ] T033 [US1] [TDD] Implement claim citation enforcement (contract W2): every substantive claim
      carries a resolving citation **or** is visibly marked as editorial framing that is not workshop
      content. There is no unmarked, uncited claim

      **PARTIAL (re-measured 2026-09-03, unchanged).** Enforcement exists and hits production
      (`authorship.check_area_w2`, `verify.py::prove_w2_requires_citation_hits_production`). It has
      been APPLIED to only **2 of the 5** authored areas — `wc -l
      workshop/curriculum/publication-reviews.jsonl` is still **2** against 5 documents under
      `workshop/docs/training/areas/`. The other 3 carry the unaudited coincidental-citation risk
      that the review record itself names.
- [x] T034 [US1] [TDD] Implement the publication review record and its **staleness rule**: a review
      older than the materials it reviews **fails**, it does not warn (contract W3). Recording
      *"nothing to change"* is valid; skipping the review is not
- [x] T035 [US1] [TDD] Implement the seven-section presence check across every area source document
      (SC-005). Any missing section fails
- [x] T036 [US1] Implement the taxonomy source file with the same byte-stability discipline the
      passage registry already has — sorted, fixed key order, final newline — so a diff means a change
- [x] T037 [US1] [TDD] Implement `GET /api/areas` per wire contract §3.1, including **A3.1.2**: report
      the count of areas held back and why. A client cannot distinguish five areas existing from
      eleven existing and six failing publication unless told
- [ ] T038 [US1] [TDD] Implement `GET /api/areas/{area}` per §3.2, and `GET /api/terms` and
      `GET /api/terms/{term}` per §3.4 — including the significance measure **and its inputs** on the
      single-term response

      **PARTIAL (re-measured live 2026-09-03 at generation 54, and AGAIN at generation 67 later the
      same day — unchanged both times, over 8,537 served terms).** All four routes serve
      200, but every term in `GET /api/terms` still carries
      `significance.inputs_available: false` with an `inputs_reason`
      (`internal/api/terms.go:188`): `pipeline/extract/taxonomy.py` persists only the final
      significance score, and `score_determined` being `true` beside it is what makes the gap
      precise rather than a general outage. The missing work is PERSISTING the inputs
      (distinctiveness, distribution, corroboration, baseline rate and its source); changing the
      handler is not the fix. `term-significance-inputs-unavailable` remains a registered defect.
- [x] T039 [US1] [TDD] Implement **A3.4.2**: a term whose last evidence is redacted is **withdrawn
      from the taxonomy**, not merely unlinked
- [x] T040 [US1] Add route-manifest rows and contract sections for every endpoint above (FR-059).
      Gate **G-KG-1**. An endpoint built but undeclared fails the server-unity verifier by
      construction — that is deliberate and must not be "fixed" by loosening the verifier
- [x] T041 [US1] [REVIEW] Human checkpoint: the reconciliation of promoted against extracted areas.
      A wrong merge here is a wrong curriculum, and every later artifact inherits it

      **TICKED 2026-09-03 ON AN OPERATOR RULING (D-36), not on a measurement — and the distinction
      is the point.** Every R3 contradiction is now disposed of by a rule rather than adjudicated
      row by row: decision D-33 ruled that title-keyword overlap is an **evidencing heuristic, not
      a boundary a human drew**, so R3 must not defend it. That rule cleared **exactly 12** of the
      13 (`R3_contradict` 13 → 1) with every other branch unchanged to the row, and it is a *rule*,
      not a list — it reads the origin string the evidence finder itself writes, so it stays true as
      the corpus moves and **stops applying by itself** the moment any other evidencing path
      supplies the overlap.
      **The 13th — the large deferred cluster — is NOT resolved and is not claimed to be.** It
      remains reported, routed to a named owner, and scheduled for a **2026-09-16** re-check. D-36
      asked whether an owned, dated, tracked deferral permits this box to tick; the operator ruled
      that **it does** — a deferral that is scheduled and owned is a resolution, not an omission.
      **Read the risk with the tick:** a ticked task whose last item is still open can read as
      complete to anyone who does not open this note. It is recorded here rather than left implicit.
      **Three options were explicitly NOT chosen and all remain open**, each with its cost still
      unmeasured: changing the evidence finder to consult area **bodies** (blast radius unmeasured);
      a **term-admission occurrence floor** (the floor value is itself a judgement); and making the
      **curated human register binding** — that register adjudicates 20 candidate strings and **all
      20 remain live term proposals**, so a recorded human decision that no code reads is still
      indistinguishable from no decision.

      ~~**NOT DONE (measured 2026-09-02).**~~ ~~no decision record anywhere~~ ~~**883 R3
      contradictions**~~ — **both halves WITHDRAWN 2026-09-03, not restated. A decision record now
      exists and the population is no longer 883.** Four operator rule decisions (29–32) were taken,
      applied to production code and pushed in workshop `692a27a`, with the record written at
      `workshop/docs/session-evidence/phase3e-r3-decisions-29-32.md` (titled for this task) over the
      census at `phase3e-contradiction-typology.md`. Measured, not read: the latest pipeline run
      (`workshop/evidence/knowledge-pipeline/20260902T200902Z-acb8265b/reconcile_and_taxonomy.json`)
      reports `R1=1936 attach, R2=2 add, **R3=13 contradict**, S6=136 update, RULE-2b=355
      discard-as-duplicate`. RULE 1 (extraction reads the corpus, not the graph) excludes 9,144
      `kg_*` rows of 11,622 — 78.68% of the file. Three gates are registered
      (`T041-RULE-1-graph-kinds-excluded`, `T041-RULE-2b-discards-only-covered`,
      `T041-rules-over-real-corpus`) and both `verify-r3-rules.sh` and `prove-r3-rules.sh` exit
      **0**, the prover catching both seeded defects against the real entry point (re-run
      2026-09-03).

      **STILL NOT DONE, and the decision record says so itself in its own §7:** the human checkpoint
      this task asks for has not been completed. **13 R3 rows remain — 12 type-T2 rows that are
      judgements only a person may make, deliberately left un-ruled because a rule over that class
      is what contract §2.3 refuses, plus 1 type-T4 mega-cluster routed to a named owner with a
      re-check date of 2026-09-16** (DEFERRED, OWNED — explicitly not counted closed). There is
      still no `phase3e-report.md`. Two real costs are recorded rather than netted away: A3 fell
      0.1047 → 0.0894 and "no evidencing mention" rose 3,243 → 9,017, because the 9,144 `kg_*` rows
      now evidence nothing. Tick this only when the 12 judgements are recorded and the T4 deferral
      is resolved — the rules mechanised the 98.7% that was one artifact; they did not make the
      remaining judgements.

      **The residual judgements are now written as answerable decision packets (2026-09-03), and
      they REGROUP: `workshop/docs/session-evidence/t041-decision-packets.md`.** A count is not a
      question, so the 13 rows were tested for a shared root and they have one, measured **12 of
      12 with no residual**: `promote.default_evidence_finder` evidences a promoted area by
      whole-word matching of the area's **TITLE KEYWORDS** (`promote.py:224-263`), so on every T2
      row the overlap passage carries an area title keyword and the outside passage carries none —
      and **11 of the 12 member terms occur zero times in the prose of any area they are reported
      as contradicting**. The 12 rows are therefore one question asked 12 times, not 12 questions.
      **13 individual adjudications become 4 decisions** (D-33 evidencing heuristic, D-34 term
      admission floor, D-35 the human-curated artifact register — measured **20 of 20** rejected
      surface forms still live as terms — and D-36 whether the owned T4 deferral lets this tick).
      Each packet carries options with measured consequences, evidence both ways, a recommendation
      and what it unblocks. **The packets are QUESTIONS: nothing was decided, no rule applied, and
      this task stays `[ ]`.** Re-derived the same day: production `R3_contradict` **13** (12 T2 +
      1 T4) and pre-RULE-1 `R3` **1153** with branch `B1` exactly **883**, so the `883` above is
      confirmed as a subset and never the total; `established_carried_in` is **495** (not 494) and
      production `S6_update` is **138** (not 136). Do not quote packet content into this public
      repository — it is cited here by path only.

      **D-33 IS ANSWERED (operator decision 33, 2026-09-03) AND THE RULING IS IMPLEMENTED. The
      sentence above — "tick this only when the 12 judgements are recorded and the T4 deferral is
      resolved" — is SUPERSEDED IN ITS FIRST HALF ONLY, and the second half still stands.** The
      ruling: **a title-keyword match is an evidencing heuristic, not a boundary a human drew, so
      R3 should not be defending it.** The 12 rows are therefore not 12 recorded judgements; they
      are one rule, applied.

      **RULE 3, in `pipeline/extract/reconcile.py`
      (`_is_title_keyword_artifact`, `_heuristic_match_keyword`,
      `HEURISTIC_EVIDENCE_ORIGIN_PREFIX`).** An R3 contradiction is a **title-keyword artifact**,
      and therefore not a contradiction, when — for **every** promoted area it overlaps — every
      overlap passage is evidence for that area **only** through a `promotion-keyword-match:<kw>`
      mention **and** no matched `<kw>` is itself one of the proposal's own member terms. It names
      no row, area, term or passage; it reads the origin string
      `promote.default_evidence_finder` itself writes rather than re-running the match, so it
      stays true as the corpus moves and **stops applying by itself** the moment any other
      evidencing path supplies the overlap. **A hardcoded set of row ids was explicitly not built.**

      **What it disposed of, measured on an unchanged corpus** (`md5sum` identical before and
      after; the read-only `analyze_r3_contradictions.py --exclude-graph-kinds`):
      `R3_contradict` **13 → 1**, `RULE_3_keyword_artifact` **12**, and
      `R1_attach` **1936**, `R2_add` **0**, `S6_update` **138**, `RULE_2b_discard` **355** all
      **unchanged to the row**. The 12 cleared are **exactly the 12 T2 rows**
      (`T2…|RULE-3-keyword-artifact: 12`, `T4…|R3-reported: 1`). **The rule was not tuned to hit
      12:** the T4 mega-cluster is retained because **15 of the 17 promoted title keywords are
      among its 3603 member terms**, so it is a proposal genuinely about what the areas are titled
      after. The disqualified blanket form — origin without relatedness — clears **13**, taking the
      routed mega-cluster with it, which is why it is disqualified rather than simpler.

      **§1.1 paired mutation, and it proves the rule is not a switch-off.**
      `verify.PROOFS["RULE-3-title-keyword-overlap-is-not-a-boundary"]` builds its promoted
      evidence with the **real** `promote.default_evidence_finder`, shows a contradiction that is
      genuinely NOT a keyword artifact **still fires** in both ways it can be genuine (the matched
      keyword IS a member term; the overlap is evidenced by a non-keyword mention), then seeds each
      disqualified predicate into the **real** `reconcile` module and requires
      `check_rule_3_artifact_is_keyword_only` to catch it — RED (a) blanket form, RED (b)
      suppress-everything, both caught. `platform/gates/prove-r3-rules.sh` MUTATION 3 repeats the
      seed against a throwaway copy of the package. Measured 2026-09-03: `verify-r3-rules.sh` and
      `prove-r3-rules.sh` both exit **0**; the extraction suite is **278 tests OK** (was 264);
      `verify-check-registry-002.sh` exits **0** at 47 checks with the new
      `T041-RULE-3-title-keyword-artifact` row; `verify-check-registry-001.sh` **20 PASS / 0 FAIL /
      1 DEBT**, unaffected. Nothing is merged and nothing is silently dropped: a cleared proposal
      becomes a `keyword-artifact` taxonomy row carrying the matched keywords and both passage
      sets, is threaded into §2.4 A1 accounting with a reason naming the rule, and the Go loader
      learned the row type in the same change.

      **THREE OPTIONS WERE EXPLICITLY NOT CHOSEN AND EACH REMAINS OPEN — none is closed by this
      decision:** (1) changing the evidence finder to consult area **bodies** (packet D-33-A/B; its
      blast radius across R1/R2/S6/RULE-2b is still **UNMEASURED**), (2) imposing a **term-admission
      occurrence floor** (D-34; the central unknown — how many of the 4358–5101 terms a floor would
      drop are real — is still **unmeasured**), (3) making the **curated human artifact register
      binding** on the pipeline (D-35; 20 of 20 rejected surface forms are still live terms).

      **T041 STAYS `[ ]`, and the reason is precise: the T4 row still blocks and D-36 is
      unanswered.** RULE 3 disposed of the 12 T2 rows; the single remaining R3 row is the T4
      over-merged mega-cluster, still reported, still routed to a named owner with a re-check date
      of **2026-09-16**, still tracked as the `area-term-over-generation` defect. Packet D-36 asks
      whether that dated deferral permits this checkpoint to close; **the operator has not answered
      it**, and ticking on the strength of D-33 alone would answer D-36 by implication. **Do not
      tick this task until D-36 is answered on the record.**
- [ ] T042 [US1] [REVIEW] Record the content boundary check **in both directions** before anything is
      published (SC-029, SC-029a)

      **PARTIAL (re-measured 2026-09-03, unchanged).** The outbound half exists —
      `pkg/assessment/boundary.go` with G-KG-16, plus the umbrella's
      `scripts/verify-content-boundary.sh`. The **inbound** half (SC-029a) is still NOT built:
      `platform/gates/defects-registry.tsv` still carries the `sc029a-not-built` row, and
      `docs/limits.md` §10.14 still records the naive probe attempted and rejected (1,410 of 1,438
      files matched, ~37,000 noise occurrences) with the shape a real check would need — long
      shingles plus a generic-content filter, not short-term substring matching. Same gap as T122.

**Checkpoint**: areas exist, are evidenced, have materials and a recorded review. Stop for approval.

---

## Phase 4: User Story 2 — deep linking (P2)

**Goal**: any point reaches every related point, both ways.

**Independent test**: enumerate every relationship, traverse it in reverse, confirm the origin comes
back. No interface required.

- [x] T043 [US2] [TDD] Implement `GET /api/areas/{area}/evidence` per §3.3, with **precision required**
      on every time-carrying entry and the word's timing confidence carried where precision is `word`
- [x] T044 [US2] [TDD] Implement **A3.3.3**: a redacted passage contributes no mention and the omitted
      count is reported, matching the existing cross-reference behaviour
- [x] T045 [US2] [TDD] Implement `GET /api/passages/{pid}/knowledge` per §3.7 — the reverse direction,
      and the endpoint that makes the recording navigable
- [x] T046 [US2] [TDD] Implement **A3.7.1**: every entry is reachable in **one** step. A response that
      returns identifiers a client must resolve separately does not satisfy FR-019
- [x] T047 [US2] [TDD] Implement **A3.7.3**: an unattached passage says it is unattached **and why**,
      rather than returning an empty list. "No areas" and "not yet classified" are different facts and
      an empty list reads as the first
- [x] T048 [US2] [TDD] Implement `GET /api/graph/traverse` per §3.8 across all four content kinds
- [x] T049 [US2] [TDD] Implement **A3.8.3**: a hop whose target cannot be resolved **reports its
      outcome and continues**; it is never dropped, because a dropped hop is indistinguishable from a
      hop that never existed
- [ ] T050 [US2] [TDD] Implement the six-row connectivity matrix (FR-033a) and its exercise harness.
      **A row with zero exercised origins fails** — an unexercised traversal is unmeasured, not
      passing (SC-015a)

      **PARTIAL (re-measured 2026-09-03, unchanged).** `platform/gates/verify-connectivity-matrix.sh`
      still exits **0**, but the handler's own live `derivation.rows_implemented`
      (`internal/api/graph_traverse.go:200`) still reports rows **1,2,3,5,6** plus only row 4's
      shared-area-membership half. Row 4's **cross-reference-graph** half is not implemented
      (`docs/limits.md` §10.7, defects row `connectivity-row4-half-implemented`). The gate gained a
      real paired proof on 2026-09-02 (`prove-connectivity-matrix.sh`, 7 mutations including an
      rc=2 control) — that closed a §1.1 debt, not this task's missing half-row.
- [x] T051 [US2] [TDD] Prove **SC-008** over the **whole** relationship set, not a sample: a one-way
      link is indistinguishable from a two-way one when read forward, so sampling cannot find it
- [ ] T052 [US2] [TDD] Prove **SC-009**: every media-backed citation lands inside its cited span,
      **and the precision split is published** alongside the pass rate. A 100% pass at segment
      precision and at word precision are different products, and a test that only asserts "inside the
      span" cannot tell them apart

      **PARTIAL — but the blocker this note named is DISCHARGED. "No gate anywhere asserts that every
      media-backed citation lands inside its cited span over the whole set … that gate is the work"
      is WITHDRAWN, not restated.** The gate was built later on 2026-09-03, while this reconciliation
      was in progress, and it passes. Run here rather than quoted:

      ```bash
      bash workshop/platform/gates/verify-sc009-citation-span.sh    # rc=0, live against :8087
      ```

      It measures **two full populations, neither sampled**: **96 of 96** served media-backed
      citations across all 495 advertised areas land inside their cited span (95 distinct passages),
      and **3 of 3** authored `cite: PID` markers in the five area documents do too. The precision
      split is published with the result rather than smoothed — **word 85, segment 11** over the
      cited subset — and the gate prints the cited subset's own segment distribution (n=96, median
      7.29 s, p95 9.94 s) **next to** this spec's corpus-wide figures while stating that the two are
      different populations and neither substitutes for the other. The gate also opens by naming the
      SC-009 collision itself — spec 001's SC-009 is the benchmark-composition floor in
      `bench-answers.sh` — which is standing rule 7 being enforced by an instrument rather than by a
      reader's memory. Its own declared boundary: the recording-seek agreement (95 of 95) is **not
      independent today**, because the seek is derived from the span, and it says so rather than
      counting as corroboration.

      **Why this still does not tick.** This is a `[TDD]` task, and this file's global constraint is
      that **every check owes a paired mutation proof**. This gate has none: `bash
      platform/gates/verify-sc009-citation-span.sh --prove-failure` returns rc=2 `unknown argument`,
      and its `check-registry-002.tsv` row `T052-sc009-citation-span` is 4 fields with no paired-proof
      column. A gate nobody has driven red is not yet known to be able to go red. **That single item
      is the remaining work** — the measurement itself is done.

      **On the `precision` FIELD, and a correction to an earlier reading of it made in this file on
      2026-09-03 and withdrawn the same day.** Workshop commit `ff90e09` wired the word-sidecar
      join, so the field is no longer pinned to `segment`: measured live on the `/evidence` route,
      `precision: "word"` is now the common value (first 12 areas in list order → word 12, segment
      1, no_time_span 4). **An earlier revision of this note read that as "word precision is live"
      and drew the conclusion that `docs/limits.md` §10.1 was stale. That conclusion was WRONG and
      is withdrawn, not restated — the label moved and the delivered precision did not.**

      What the join actually returns, read from `pkg/knowledge/wordjoin.go` rather than inferred
      from the label: `JoinSegmentWords` classifies *"its whole word range"* (its own doc comment)
      and returns `StartS: sub[0].StartS, EndS: sub[len(sub)-1].EndS` — the first word's start to
      the **last** word's end **of the entire segment**. It is a word-timing-derived tightening of
      the segment's own bounds, not a pointer at one word. The `precision` flag flips to `word`
      when every word of the segment carries a timing inside the segment window — a statement about
      **sidecar completeness**, not about span width. Measured over 40 areas:

      ```
      precision="word"     n=40  min=2.040s  median=7.650s  max=13.040s
      precision="segment"  n= 3  min=6.300s  median=7.620s  max= 9.620s
      ```

      **The two are the same width.** Both match this file's own recorded segment distribution
      (median 6.74 s, p95 10.78 s). A word's span is a fraction of a second.

      **So §10.1's substance stands and must NOT be "corrected" away: every deep link in this
      deployment still resolves at segment width, and "jump to the exact moment a term was said"
      is still "jump to the segment it was said in."** What is now inaccurate in §10.1 is narrower
      than a staleness — its *mechanism* sentence (`entry.Precision = PrecisionSegment` set
      unconditionally; `precision_split` always `{"word": 0, "segment": N}`) no longer matches the
      code. **That makes the response shape worse, not better, and it is a NEW defect rather than
      a closed one:** an entry labelled `word` carrying a 7.65 s median span overstates its own
      precision to any client that trusts the field, which is the exact misreading §10.1's
      consequence paragraph was written to prevent. Recorded here; fixing §10.1's wording, the
      `precision-segment-only` row, and the label itself is `workshop/`-owned and out of this
      file's scope.

      **None of this ticks the task** — but the reason has CHANGED, and the old one ("the SC-009 gate
      does not exist") is **WITHDRAWN, not restated**. The gate exists and is green over both full
      populations; what it still owes is a paired mutation. See the head of this note.
- [x] T053 [US2] [TDD] Prove **SC-010**: replay the identifier-survival experiment extended to all
      five new kinds; compare the full link set before and after **by hash**
- [x] T054 [US2] [P] Add route-manifest rows and contract sections for the endpoints in this phase
- [x] T055 [US2] [P] [SUBAGENT] Build the transcript-to-knowledge affordance in the existing
      transcript view — the entry point for "what is being taught at this moment"

      **DONE. This task was already ticked while carrying a "NOT DONE" note — the note was the stale
      half, and it is WITHDRAWN, not restated.** Every specific it asserted is now false, checked one
      by one on 2026-09-03: `platform/frontend/src/app/core/api.ts` calls
      `` `/api/passages/${encodeURIComponent(pid)}/knowledge` `` (it does not stop at `crossrefs`);
      `features/transcript/transcript.component.ts` carries **6** `knowledge` references, not zero,
      and renders `<app-passage-knowledge [pid]="pg.pid" />`; and the component the old note implied
      did not exist is `features/transcript/passage-knowledge.component.ts`, whose header names T055.
      Line numbers are deliberately omitted — both files moved under this reconciliation on the day —
      so re-derive with `grep -n knowledge` rather than trusting a citation.

      **Proven by execution, not by reading the source.** The Playwright config deliberately declares
      no `webServer`, so the suite exercises whatever the container is serving rather than a dev
      server it started itself:

      ```bash
      cd workshop/platform/frontend && npx playwright test e2e/passage-knowledge.spec.ts
      # 16 passed (24.9s) — 8 tests × desktop-chromium + mobile-chromium
      ```

      Those 8 include a **paired mutation** — leaving the disclosure closed must result in no call to
      the endpoint at all — a check that what is rendered equals what the endpoint returned, and one
      case per resolution outcome (`unattached`, `redacted`, absent from the registry, unreadable),
      so the four A3.7.2 outcomes are each shown to render **distinctly** rather than collapsing into
      a single empty list.
- [x] T056 [US2] [REVIEW] Review the link model against the contract before the surface consumes it

**Checkpoint**: the graph is complete and bidirectional, and both precisions are honest.

---

## Phase 5: User Story 3 — search over everything (P3)

**Goal**: all four content kinds searchable, every hit says where.

- [ ] T057 [US3] [TDD] Index the four new kinds — `area`, `term`, `lesson_section`, `question` —
      indexing **their own text**, not only the passages they cite. A question findable only through
      its citations is not findable by anyone who does not already know the answer (D-KG-10)

      **3 of 4 kinds indexed; `lesson_section` is a recorded gated REFUSAL, not a gap.** The note
      this task carried — *"`corpus.indexed_kinds` still returns exactly `[transcript_segment,
      doc_section, code, diagram, area, term]` … `lesson_section` and `question` are **not
      indexed** — **2 of the 4** kinds this task names"* — is **WITHDRAWN, not restated**: `question`
      was indexed on 2026-09-03 and the live block now advertises seven kinds. Re-measured live:

      ```bash
      curl -s 'http://127.0.0.1:8087/api/search?q=quonsari&limit=2' | jq .corpus.indexed_kinds
      # ["transcript_segment","doc_section","code","diagram","area","term","question"]
      ```

      **`question` is indexed on its own text, which is what this task asks for.** Counted by
      unioning the pids returned for `kinds=question` across twenty probe queries: **44** distinct
      entries reachable through search, exactly equal to the **44** questions the API actually serves
      (9 short + 35 long across 5 areas of 495; 0 withheld). `pkg/search/question_catalog.go`'s
      `BuildQuestionEntries` runs the SAME `assessment.ServeQuestions` decision the §3.5 route runs,
      so a question whose citation stops resolving is withheld from **search** as well as from the
      practice set — G-KG-2 reaches the index rather than stopping at the endpoint. Note the
      mechanism, because it is not what the registry would suggest: the catalog is built from the
      question bank directly, and `curriculum/passages.jsonl` mints **zero** `kg_question` records.

      **`lesson_section` is the fourth kind, and it is deliberately NOT indexed.** Measured over the
      11,622-record registry:

      ```bash
      python3 -c '...collections.Counter(kind)...' < workshop/curriculum/passages.jsonl
      # 11622 total: kg_term 8553 · doc_section 1172 · transcript_segment 1055 · kg_area 516 ·
      #              code 251 · kg_todo 27 · kg_next_point 24 · kg_open_question 14 ·
      #              kg_meeting_note 10        →  kg_lesson_section: 0
      ```

      **Zero of 11,622**, and the reason is structural rather than unfinished work:
      `pkg/knowledge/materials.go`'s `LessonSectionMeta` carries `Heading`, `Ordinal`, `Authorship`
      and `CitationCount` and **no identifier**, so there is no key to index a row on or to join a
      question to. The refusal is pinned by a test —
      `pkg/search/question_search_test.go:205 TestT057_LessonSectionIsNotAdvertisedBecauseNothingIndexesIt`
      — which fails if `lesson_section` is ever added to `corpus.indexed_kinds` without something
      behind it, and which also asserts the three backed kinds ARE advertised so it cannot pass on a
      build that quietly stopped advertising everything.

      **Why this stays unticked:** the task names four kinds and three are indexed. Closing it needs
      either a minted `lesson_section` identity (a data-model change) or an amendment narrowing the
      task to the three kinds that can carry one. **That is a spec decision and it is not made here.**
- [ ] T058 [US3] [TDD] Advertise the new kinds in the corpus block, and prove **G-KG-11**: an
      advertised kind must be **retrievable**, proven by a planted known target — **not** by a row
      count, which cannot distinguish a populated index from a populated table nobody queries. The
      corpus already advertises one kind with zero entries

      **3 of 4 kinds advertised and proven; `lesson_section` is a recorded gated REFUSAL, not a
      gap.** The note this task carried — *"its scope is `area` + `term` only. `lesson_section` and
      `question` are still neither advertised … nor proven"* — is **WITHDRAWN, not restated**.
      G-KG-11 now covers a third kind, proven the way the task demands — by a **planted known target
      actually retrieved**, never by a row count:

      - `area` + `term` — `pkg/search/knowledge_search_test.go:93`
        `TestGateKG11_AdvertisedAreaTermKindsAreRetrievable`, with its negative twin at `:176`.
      - `question` — `pkg/search/question_search_test.go:75`, whose own comment is *"advertised
        BECAUSE it is retrievable"*, and which plants a question and retrieves it.

      ```bash
      cd workshop/platform/backend && go test -count=1 -run 'TestT057|TestT058' ./pkg/search/...  # ok
      ```

      Live, every advertised kind was probed by unioning search results across fourteen queries:
      `area` **5** entries · `term` **382** · `question` **44** · **`diagram` 0**. The zero-entry
      kind this task names in its own last sentence is therefore **still `diagram`, and still
      exactly one** — this phase added a kind that is backed and did not add a second empty one,
      which was the constraint C4.1.1 imposed. `lesson_section` is absent from
      `corpus.indexed_kinds` entirely rather than advertised empty, which is the correct handling
      and is pinned by `TestT057_LessonSectionIsNotAdvertisedBecauseNothingIndexesIt`.

      **Why this stays unticked:** it is bound to T057 — the fourth kind is neither indexed nor
      advertised, and the same spec decision settles both.
- [x] T059 [US3] [REVIEW] Settle **U1** before implementing offsets: does the full-text engine expose
      match positions through a supported interface, or must offsets be recomputed by re-locating
      query terms in the matched text? Three-valued exit. This has a correctness edge — a
      recomputation can disagree with what the index actually matched, particularly under the prefix
      matching the lexical leg applies to the final query token. **T060 is blocked on this**
- [x] T060 [US3] [TDD] Implement match offsets per **C4.1.3**: the lexical leg
      produces real offsets, **or** the field is removed and its absence stated. Leaving a field that
      promises a position and never carries one is forbidden. Gate **G-KG-5**. **Paired mutation**:
      return an empty offset list from a leg that could produce offsets

      **`[BLOCKED: U1 / T059]` STRIPPED 2026-09-02 — the blocker was discharged, and the marker was
      describing a state that no longer existed.** T059 settled U1 from evidence: the full-text
      engine exposes match positions through a supported interface, so offsets are read from the
      index rather than recomputed by re-locating query terms — the correctness edge U1 named does
      not arise. Recorded at `workshop/docs/session-evidence/phase5-report.md`; the implementation
      and its tests are at `workshop/platform/backend/pkg/search/offsets.go`,
      `offsets_test.go` and `lexical_offsets_test.go`. Re-derive by reading those paths, not this
      sentence.
- [x] T061 [US3] [TDD] Implement **C4.1.4**: the semantic leg reports that it **cannot** produce
      offsets — a different fact from producing none. One empty list meaning both is exactly the
      collapse this contract exists to prevent
- [x] T062 [US3] [TDD] Implement the locus on every hit per **C4.1.2**, and withhold any hit whose
      locus does not resolve (FR-030)
- [x] T063 [US3] [TDD] Prove **SC-014** over **every** hit of the benchmark run — a hit without a
      resolving locus fails the run, not merely itself

      **DONE 2026-09-03. The note that stood here is WITHDRAWN, not restated, and its withdrawn
      claim is named so a brief written from the old text is recognisable:** *"The 'over **every**
      hit of the benchmark run' half is still not implemented: `grep -c locus
      pipeline/benchmark/run_retrieval_benchmark.py` returns **0**, so no hit can fail the RUN."*
      That sentence remains TRUE of that Python script and it is no longer the reason this task is
      open — a different instrument, built the same day, discharges the task. The script is the
      passage-level SC-015 benchmark; the run SC-014 names is T066's new-kinds benchmark, and it is
      now executed by a gate.

      Re-derived by execution, not read:

      ```bash
      bash workshop/platform/gates/verify-retrieval-benchmark.sh   # rc=1, live against :8087
      #   PASS  B1 all 560 hit(s) of this run carry a resolving locus (C4.1.2 / FR-030)
      #   FAIL  B2 SC-015 NOT met: top-5 8/22 — a MEASUREMENT, and T067's problem, not B1's
      #   PASS  B3 no negative query returned an area, term or question record
      bash workshop/platform/gates/prove-retrieval-benchmark.sh    # rc=0 — 6 mutations, 6 caught
      ```

      **B1 asserts the property over EVERY hit the run returned — 560 of them, not a sample — and a
      violation fails the RUN, which is the half the old note said was missing.** That is proven
      rather than asserted: the paired proof's **M1-locus** mutation plants a hit whose locus does
      not resolve and requires the whole gate to exit **1**; it does. The gate is three-valued by
      demonstration too — **M4-no-server** and **M5-no-bench** each require exit **2**, so an
      unreachable service is never a pass. Registered as `T066-T067-retrieval-benchmark` in
      `platform/gates/check-registry-002.tsv`.

      **Honest boundary (§11.4.6), and it does not withhold the tick.** The proven population is the
      560 hits of the new-kinds benchmark run. `pipeline/benchmark/run_retrieval_benchmark.py` still
      carries no locus handling, so the passage-level benchmark asserts nothing about locus; and
      `prove-retrieval-benchmark.sh` is itself **not registered** in `check-registry-002.tsv` — the
      gate's row is 4 fields with no paired-proof column, so the proof runs green but nothing
      enumerates it. Both are recorded rather than netted away.
- [x] T064 [US3] [TDD] Implement kind and area filters per **C4.1.5**, echoing the applied filter so a
      client can tell a filtered empty result from an unfiltered one
- [x] T065 [US3] [TDD] Add area and term names to suggestions per **C4.2.1**, and prove **C4.2.2**:
      the suggestion service still holds **no embedder**. Type-ahead stays lexical — semantic
      embedding under load has been observed in the tens of seconds against a 200 ms budget
- [x] T066 [US3] Build the ≥20-query benchmark for the new kinds in the platform's existing benchmark
      directory, beside the gates that read it, with expected identifiers fixed **in advance**

      **DONE 2026-09-03. Three claims of the note that stood here are WITHDRAWN BY NAME, not
      deleted, because a brief written from the old text would still assert them:**

      - **WITHDRAWN claim 1:** *"it is NOT in the platform's existing benchmark directory
        (`platform/backend/testdata/benchmark/` still holds only the specs-001 `questions.tsv`)."*
      - **WITHDRAWN claim 2:** *"**no gate reads it** … nothing executes the benchmark from the
        platform side."*
      - **WITHDRAWN claim 3:** *"`check-registry-002.tsv` has no row naming it."*

      All three were true of `pipeline/benchmark/retrieval_benchmark.json`, which is a DIFFERENT
      artifact and stays where it is. A second benchmark — the one this task actually names — now
      exists. Measured, not read:

      ```bash
      ls workshop/platform/backend/testdata/benchmark/
      #   kinds_retrieval_benchmark.json   questions.tsv
      python3 -c '...'   # 22 positive (area 5 · term 12 · question 5) + 6 negative
      grep -n kinds_retrieval_benchmark workshop/platform/gates/verify-retrieval-benchmark.sh
      #   150: reads it as the gate's own input
      grep -n T066 workshop/platform/gates/check-registry-002.tsv
      #   62: check  T066-T067-retrieval-benchmark  shell  platform/gates/verify-retrieval-benchmark.sh
      ```

      **Every clause of this task is satisfied by measurement:** ≥20 queries (22 positive over the
      three kinds this feature indexes, plus 6 negatives); in the platform's existing benchmark
      directory; beside the gate that reads it; and expectations fixed **in advance** — the file's
      own `_meta.expectations_fixed_in_advance` records that every expected identifier was taken
      from the CATALOGUE endpoints (`/api/areas`, `/api/terms`, `/api/areas/{id}/questions`) and
      **never from a search ranking**, with three stated selection rules applied verbatim and no
      per-query adjustment. It also records the discipline that makes that checkable: *"the file was
      written, then run. A query that fails is recorded as a failure, not rewritten."* The run bears
      that out — 14 of 22 positives miss the top five and are printed as failures rather than
      re-cut.

      **Honest boundary (§11.4.6), and it does not withhold the tick:** the benchmark's own RESULT
      is that SC-015 is not met (top-5 8/22). That is T067's finding, not a defect in this artifact;
      a benchmark whose queries all passed on first run would be the suspicious one.
- [ ] T067 [US3] [TDD] Prove **SC-015**: the gate prints **per-query** outcomes, not only the
      aggregate — which queries fail is the useful information, and an aggregate hides it

      **PARTIAL — and the FIRST of the two reasons is DISCHARGED. The claim *"It is still **not a
      gate**: its only exit is `return 0` (line 309) … and it still has no row in
      `platform/gates/check-registry-002.tsv`"* is WITHDRAWN, not restated.** It described
      `run_retrieval_benchmark.py`, and it is still true OF THAT SCRIPT. It is no longer the state
      of this task: a real gate over the new-kinds benchmark exists, is three-valued, is registered,
      and has a paired proof. Measured by execution 2026-09-03:

      ```bash
      bash workshop/platform/gates/verify-retrieval-benchmark.sh   # rc=1
      bash workshop/platform/gates/prove-retrieval-benchmark.sh    # rc=0 — 6 mutations, 6 caught
      #   M0 control 0 · M1-locus 1 · M2-ranking 1 · M3-negative 1 · M4-no-server 2 · M5-no-bench 2
      ```

      **It prints per-query outcomes, which is precisely what this task's own descriptive clause
      asks for** — a `id / type / kind / rank / top1 / top5 / status` row for each of the 22
      positives and a `status` + `kg_records_returned` row for each of the 6 negatives, with the
      aggregate printed *after* them rather than instead of them. Registered as
      `T066-T067-retrieval-benchmark` at `check-registry-002.tsv:62`.

      **The SECOND reason stands and is why the box is still `[ ]`: SC-015 is measured NOT MET.**
      The criterion needs ≥90% of ≥20 queries returning the expected item in the top five. Measured
      on the served path 2026-09-03 over the new-kinds benchmark: **top-5 8/22 (36.4%)** against a
      bar of 20/22, **top-1 4/22**. Per kind, printed by the gate: `question` 5/5 top-5 (4 of them
      top-1), `area` 3/5, `term` **0/12**. A `[TDD]` task that says *"Prove SC-015"* cannot be
      ticked while the criterion it names is red — the instrument is built, the property is absent,
      and the gate is correctly failing rather than passing.

      **Two earlier figures are SUPERSEDED, not wrong when written, and they are NOT comparable to
      the 8/22 above:** *"top-5 20/26, top-1 8/26"* and *"13/26 before it"* were measured over
      `pipeline/benchmark/retrieval_benchmark.json`, whose expected identifiers are transcript and
      `doc_section` PASSAGES. That benchmark asks *"can the corpus be found"*; this one asks *"can
      the new kinds be found"*, which is the question T066 names. Quoting one as the other's
      before-figure would compare two different populations.

      **What the failure actually is, measured rather than inferred: the `term` leg returns nothing
      in the top five for any of its 12 queries** (7 of 12 rank outside the top 20 entirely; the
      other 5 rank 13–20). `area` and `question` both clear the bar on their own. Recorded here
      because "SC-015 is 36%" reads as a uniform shortfall and it is not one.
- [ ] T068 [US3] [TDD] Prove **SC-016 / SC-017**: re-run the latency harness and **publish before and
      after together**. A single after-figure cannot show a regression that stayed inside the threshold

      **PARTIAL — the note that stood here is STALE and its two claims are WITHDRAWN BY NAME. The
      task still does not tick, and the reason has CHANGED from "nobody re-ran it" to "the re-run
      cannot be reproduced today".**

      - **WITHDRAWN claim 1:** *"The newest column is still the 17:57 UTC one taken against
        **1,101** passages."*
      - **WITHDRAWN claim 2:** *"No re-run against today's grown corpus is recorded anywhere."*

      Both were true when written and neither is true now. `docs/limits.md` §2 carries a **fourth**
      column — 2026-09-03, **2,478**-passage corpus, generation 67 — placed BESIDE the three older
      ones rather than replacing them, with the breaching figure struck through and annotated
      `SUPERSEDED — see §2.1` instead of deleted. That is exactly the
      publish-before-and-after-together discipline this task asks for, and §2.1 states the
      supersession by name. The recorded column reads `/api/suggest` p95 **9.5 ms** (SC-016's budget
      is 200 ms) and `/api/search` fused p95 **238.6 ms** (SC-017's budget is 2 s), taken with
      `platform/gates/verify-search-latency.sh`, which now has a paired proof
      (`prove-search-latency.sh`) and two registry rows added the same day
      (`SC-006-search-latency`, `SC-006-search-latency-proof`).

      **Why the box stays `[ ]`: this reconciliation could NOT reproduce that column, and a figure
      nobody can re-derive is not a proof.** The gate's own closing instruction is *"Re-run it; do
      not quote it."* It was re-run twice on 2026-09-03 and neither run is usable:

      ```
      run 1  rc=1  search fused p95 4994.5 ms   PASS 0  FAIL 1  UNDET 4
             — but `health CONTROL` is itself UNDET (connection refused), and the container
               reported `Up 39 seconds` immediately afterwards: it went DOWN mid-run.
      run 2  rc=0-with-nothing-measured        PASS 0  FAIL 0  UNDET 7
             — every endpoint including the control: "Remote end closed connection without
               response" / "Connection refused".
      ```

      **Neither run refutes the 238.6 ms column and neither confirms it — this is a COULD NOT
      DETERMINE, and a 2 is never a pass.** The control row is the whole point of the harness: with
      `health CONTROL` undetermined, the fused figure is uninterpretable by the gate's own design.
      The host was at load average **20.2–22.3** during both attempts (§2's own caveat is that no
      latency figure here may be quoted without its load context) and the platform container was
      restarted underneath them by concurrent work in this tree.

      **What remains for this task is one clean re-run, not new code:** `bash
      workshop/platform/gates/verify-search-latency.sh` on a quiet host, with the `health CONTROL`
      row determined, confirming SC-016 and SC-017 against the published pair. Also unresolved and
      recorded rather than netted away: the gate labels its budget `SC-006`, which is **spec 001's**
      criterion; SC-016/SC-017 are **this** spec's, and no instrument in this tree asserts them
      under their own names (standing rule 7).
- [x] T069 [US3] [P] [SUBAGENT] Extend the search view for the new kinds, the filters and the locus
      display

      **DONE 2026-09-03. The note that stood here is WITHDRAWN, not restated, and its claim is named
      because it is exactly the kind a brief would carry forward:** *"The **filters and the locus
      display are still absent**: `core/api.ts:273` is still `search(q: string, limit = 20)` setting
      only `q` and `limit` … and the component still contains **zero** `locus` and **zero** `filter`
      references."* Every clause of that was true when written and none of it is true now — the work
      landed in workshop `bd7da41`.

      Re-derived by reading the tree, then **proven by execution**:

      ```bash
      grep -n 'search(q' workshop/platform/frontend/src/app/core/api.ts
      #   search(q: string, opts: SearchOptions = {})   — sends `kinds` (ONE comma-joined
      #   parameter, the shape the deployed server parses) and `area`; an empty filter is
      #   OMITTED rather than sent empty, because "no kind filter" and "a kind filter naming
      #   nothing" are different requests
      grep -c 'locus'  .../features/search/search.component.ts   # 11
      grep -c 'filter' .../features/search/search.component.ts   # 42

      cd workshop/platform/frontend
      CHROME_BIN=/usr/bin/chromium npm run test:unit
      #   Chrome Headless 147: Executed 97 of 97 SUCCESS
      ```

      Line numbers are deliberately omitted — the file moved twice on the day — so re-derive with
      `grep -n` rather than trusting a citation.

      The 97 include a **`SearchComponent — T069 filters and locus`** block of 6 tests, and the six
      are the task's three halves checked one at a time: no `kinds`/`area` parameter is sent when
      nothing is filtered; the ticked kinds go out comma-joined with the chosen area; the kind list
      is offered **from `corpus.indexed_kinds`** and never from a hardcoded list (so a kind the
      corpus stops advertising disappears from the UI by construction); the area list carries only
      areas with an authored title and **counts the rest**; each hit's locus is rendered **from the
      server's own `locus.unit`/`locus.position`, never reassembled client-side**; and a FILTERED
      `no_match` says so where an UNFILTERED one does not, with the echo carried onto `unavailable`
      alongside a statement that the filter is not the cause.

      **Honest boundary (§11.4.6), and it does not withhold the tick:** this is a `[P] [SUBAGENT]`
      task, not `[TDD]`, so no paired mutation is owed by the global constraint — and none of the
      six T069 tests is one. The evidence is 6 behavioural unit tests executing the component, not a
      grep.
- [ ] T070 [US3] [P] Update the route manifest and contract for the changed search and suggest
      endpoints

      **CORRECTED 2026-09-03 — the note that stood here has gone STALE, and its two claims are
      WITHDRAWN BY NAME rather than deleted, so a brief written from the old text is recognisable.**

      - **WITHDRAWN claim 1:** *"all three rows still cite the **001** contract sections
        (3.6 / 3.7 / 3.11)."*
      - **WITHDRAWN claim 2:** *"There are still no rows or notes for the 002 delta sections
        **§4.1** (locus/offsets/kinds/filters), **§4.2** (areas and terms in suggest) or **§4.4**
        (progress over areas)."*

      Both were true when written. Neither is true now. The one clause of that note that still
      holds is its first: `platform/gates/route-manifest.tsv` carries `/api/suggest`, `/api/search`
      and `/api/progress` rows.

      **What is true, measured 2026-09-03 in `workshop/platform/gates/route-manifest.tsv`.** All
      three rows now carry the **R1b compound** contract token naming both documents —
      `/api/suggest` reads `3.6+002.4.2`, `/api/search` reads `3.7+002.4.1`, `/api/progress` reads
      `3.11+002.4.4` — and each row's note names the delta clauses it answers for (C4.2.1/C4.2.2;
      C4.1.1–C4.1.5; C4.4.1/C4.4.2) alongside the tasks that changed it, this one among them. The
      manifest half of this task is therefore met for the endpoints it names.

      **The COULD NOT DETERMINE recorded here on 2026-09-03 is now RESOLVED — measured the same
      day, and it resolves to NOT MET rather than to a pass.** The withdrawn sentence was: *"whether
      anything further is owed by the 'and contract' half of this task's title was **NOT
      measured** here."* It has now been measured, and something is owed.

      `contracts/http-api-delta.md` carries `## 4. Endpoints changed` with `### 4.1 GET /api/search`
      (C4.1.1–C4.1.6) and `### 4.2 GET /api/suggest` (C4.2.1, C4.2.2) — so the sections exist and
      the manifest rows cite them. **But §4.1's C4.1.1 still reads *"`area`, `term`,
      `lesson_section` and `question` join the existing kinds"* and declares an advertised kind with
      zero indexed entries a failure**, while the served corpus block advertises **seven** kinds
      **without** `lesson_section`, and `TestT057_LessonSectionIsNotAdvertisedBecauseNothingIndexesIt`
      pins that refusal in code. The contract therefore requires a fourth kind the implementation
      deliberately refuses, and the refusal is recorded in `tasks.md` (T057/T058) and in
      `docs/limits.md` — **everywhere except the contract this task is responsible for updating.**

      That divergence is the remaining work, and it is NOT a coding change: closing it needs either
      a minted `lesson_section` identity or an amendment narrowing C4.1.1 to the three kinds that
      can carry one — **the same spec decision T057 and T058 are already waiting on**, which is why
      this task is now bound to them rather than independently open.

      Separately, and outside this task: `contracts/http-api-delta.md` §2 R1b records an
      open obligation on the **fourth** changed endpoint, `/api/ask`, which belongs to `002:T143`.
      Its own honest-boundary paragraph says the `/api/ask` rows carry a bare `3.10`; measured the
      same day, the `GET /api/ask?q=ping` row reads `3.10+002.4.3`, so that paragraph is partly
      stale too and is not restated as current here.

**Checkpoint**: everything is searchable and every hit says where — or honestly says it cannot.

---

## Phase 6: User Story 4 — provenanced assessment (P4)

**Goal**: the property the reference module does not have, at 100%.

- [x] T071 [US4] [TDD] Implement the question model in `pkg/assessment/question.go`, porting the
      reference's field shape and **adding the mandatory citations field**. This is the feature's one
      deliberate divergence and the reason it exists
- [x] T072 [US4] [TDD] Implement **Q1 / G-KG-2**: a question is served **only** if it carries at least
      one citation and **every** citation resolves. A citation resolving to redacted, not-present or
      could-not-determine ⇒ **withheld**. Not served with a warning, not with the citation stripped,
      not with an empty list. **Paired mutation**: serve it with the citation stripped
- [x] T073 [US4] [TDD] Implement **Q2 / G-KG-3**: every long-set question cites **more than one
      distinct** passage. **Paired mutation**: admit a single-citation question to the long set
- [x] T074 [US4] [TDD] Implement **Q3**: every question names the lesson sections it assesses — this
      is what makes per-section coverage measurable rather than estimated
- [x] T075 [US4] Author the short and long question sets **from the workshop's own passages** (Q5).
      **Nothing from the reference's 785 items may appear**, including as a placeholder
- [x] T076 [US4] [TDD] Implement **G-KG-16**: plant one reference question in a workshop bank and
      assert the boundary check fails. **Paired mutation**: scope the check to the outbound direction
      only. It runs both ways deliberately — outbound keeps a private recording out of public
      repositories, inbound keeps the workshop from shipping someone else's curriculum
- [x] T077 [US4] [TDD] Implement the assembled-answer marking per **Q4 / A3.5.4** — a client must not
      have to infer it
- [x] T078 [US4] [TDD] Implement `GET /api/areas/{area}/questions` per §3.5, including **A3.5.5**:
      report how many questions were withheld and why. A silently shorter set is how a provenance
      guarantee decays into a claim without anyone noticing
- [x] T079 [US4] [TDD] Implement `GET /api/areas/{area}/coverage` per §3.6: **per-area figures,
      never only an aggregate**; sections with zero questions listed explicitly; **no threshold and no
      pass field**. Gate **G-KG-12**. **Paired mutation**: replace the per-area table with a mean

      **DONE — the "PARTIAL … the §3.6 endpoint is still not built … returns 404 … there is no
      `route-manifest.tsv` row" note this task carried is WITHDRAWN, not restated.** The route was
      mounted and the manifest row added on 2026-09-03; the note described a state that no longer
      exists. Re-measured live 2026-09-03 against the running container
      (`workshop-curriculum_platform_1`, healthy, `/api/health` 200):

      ```bash
      # every area id from /api/areas, probed one by one
      curl -so /dev/null -w '%{http_code}' http://127.0.0.1:8087/api/areas/$ID/coverage
      # 200 for 495 of 495 areas — 0 are 404
      ```

      The 404 half is gone and the shape holds on the WIRE, not merely on the struct. The live
      response carries `per_area` as a **list**, `section_question_counts` with every roster section
      as a key, `zero_sections` naming the zero-question ones again, and a `derivation` block whose
      own words are `"threshold": "NONE"` and `"aggregate": "NONE"` — no threshold, no target, no
      mean, no pass field. `derivation.served_only` records that withheld questions contribute
      nothing (G-KG-2). Manifest row `002.3.6` is registered in
      `workshop/platform/gates/route-manifest.tsv` and states the same history in its own words.
      Gate and paired mutation re-run uncached and green:

      ```bash
      cd workshop/platform/backend
      go test -count=1 -run 'TestT079' ./pkg/assessment/... ./internal/api/...   # ok
      # pkg/assessment/coverage_test.go:154 TestT079_PairedMutation_ReplacePerAreaTableWithMean
      # internal/api/coverage_wire_test.go — 7 wire tests, incl.
      #   TestT079_Wire_ExpressesNoThresholdAndNoPassField and
      #   TestT079_Wire_ForbiddenKeyScannerActuallyCatchesOne (the scanner's own paired proof)
      ```

      **Honest boundary (§11.4.6):** A3.2.2's publication-review requirement is deliberately **not**
      applied on this route, by a call whose reasoning is recorded in `internal/api/coverage.go`'s
      own doc comment — which is why coverage answers 200 for all 495 areas while `GET
      /api/areas/{area}` answers 200 for only **2**. §3.9 makes the opposite call; both divergences
      are declared where they happen rather than left to be discovered. Separately, the live
      `derivation.lesson_section_identity` field warns that the two roster sizes it reports do not
      measure the same thing — read it before comparing them.
- [x] T080 [US4] [TDD] Prove **SC-018** by enumerating every served question and resolving every
      citation, and **record the reference module's measured value — 0 of 785 — beside it**, so the
      comparison is measured rather than claimed
- [x] T081 [US4] [TDD] Prove **SC-019**: the question-to-moment-and-back round trip, over every
      eligible question; if impractical, a seeded sample of ≥30 **with the population size published**
- [x] T082 [US4] [TDD] Extend progress to areas and question sets, and prove **C4.4.2**: progress
      **survives a content re-ingest**. The reference deliberately preserves its progress table while
      wiping everything else; a learner's history is not a derived artifact
- [x] T083 [US4] [P] Add route-manifest rows and contract sections for the assessment endpoints

      **DONE — the "PARTIAL … coverage (§3.6) and export (§3.9) still have neither a manifest row
      nor a mounted route … both return 404" note is WITHDRAWN, not restated.** All three assessment
      endpoints now have a contract section, a manifest row and a mounted route. Re-measured
      2026-09-03:

      ```bash
      grep -n '^### 3\.' specs/002-knowledge-areas-deep-linking/contracts/http-api-delta.md
      # 3.5 questions · 3.6 coverage · 3.9 export — all present
      grep -c '002\.3\.[569]' workshop/platform/gates/route-manifest.tsv   # 3 rows
      curl -so /dev/null -w '%{http_code}' http://127.0.0.1:8087/api/areas/$ID/export   # 200
      ```

      Manifest rows `002.3.5`, `002.3.6` and `002.3.9` are registered, and the two new rows record
      in their own words that they "WAS A BARE 404 UNTIL 2026-09-03" — the row and the route landed
      together, which is the pairing this task exists to enforce. Export behaves per contract on both
      sides of the gate, measured live rather than read:

      - **Published area** (`01M1GWW49GNKYBEXFFCNRWM1SY`) → `exportable: true`, four formats listed,
        `markdown` `present` with a real `href` and `size_bytes`, `html`/`docx`/`pdf`
        `could_not_determine` with `toolchain_blockers` naming `pandoc`/`weasyprint` as absent **in
        the container** — A3.9.2's "never an empty format list" honoured.
      - **Unpublished area** (`01M1GWQYWSKZA7A2S59MNV0Z2Q`) → `exportable: false`, four
        `precondition_blocked` formats, no `href`, no source path. A3.9.1 requires exporting nothing
        **and saying so**; saying so needs a body, so this is a 200 carrying the failed precondition
        rather than a 404. The §3.2 route keeps returning its own `404 area_not_published` — this
        does not soften it.

      ```bash
      cd workshop/platform/backend
      go test -count=1 -run 'TestT083' ./internal/api/...   # ok
      # 10 wire tests, incl. TestT083_ProbeExportToolchain_NeverAsksForAVersion —
      # the probe makes each tool DO its job rather than answer --version
      ```
- [ ] T084 [US4] [REVIEW] Review question provenance end to end before the practice surface consumes
      it

      **NOT DONE (re-measured 2026-09-03, unchanged).** `workshop/docs/session-evidence/phase6-report.md`
      deferred this review pending T075 and T078. **Both have since been completed and the review
      was never revisited** — `phase6-report.md` is still the newest phase-6 artifact (2026-09-02
      12:54), and `grep -rl T084` across `docs/` returns only that report and its own brief. No
      later review record exists under `docs/session-evidence/`, `curriculum/` or `specs/002-*/`.

**Checkpoint**: every served question is traceable to the moment that teaches it.

---

## Phase 7: User Story 5 — the learning surface (P5)

**Goal**: a learning platform, with its own identity, that loses nothing it already had.

- [x] T085 [US5] **Enumerate the four existing capabilities — chapter list, transcript, recording
      player, cross-references — and write the list down BEFORE any reshaping**. SC-023 is a
      before-and-after comparison, and a list reconstructed afterwards is a recollection, not a
      measurement
- [x] T086 [US5] [P] [SUBAGENT] Build the area list and area detail views
- [x] T087 [US5] [P] [SUBAGENT] Build the practice view with the question-to-moment jump and return
- [x] T088 [US5] [P] [SUBAGENT] Build the progress view across areas
- [x] T089 [US5] [P] [SUBAGENT] Build the study-plan view
- [x] T090 [US5] Subordinate the existing media views under areas per **D2** — reachable from within
      an area rather than as top-level objects. They are the working half of what exists and are what
      makes a timestamp jump possible at all
- [x] T091 [US5] [TDD] Prove **SC-023** against T085's written list: every enumerated capability is
      still reachable
- [x] T092 [US5] Give the workshop its own token **values** against the shared contract. **Do not
      fork the component library** — forking doubles maintenance and guarantees drift (FR-043)
- [x] T093 [US5] [TDD] Prove **SC-022** with **both** checks: the design toolkit's token conformance
      check **and** a literal-value scan. Either alone passes a stylesheet that defines perfect tokens
      and ignores them
- [x] T094 [US5] Implement interaction and motion from the platform's ranked,
      sourced user-experience research, each decision naming the finding it rests on (FR-044a). An
      effect with no supporting finding does not ship on the grounds that it looks better

      **`[BLOCKED: UX research]` STRIPPED 2026-09-02 — the blocker was discharged, and the marker was
      describing a state that no longer existed.** The research this task waits on exists as a real
      artifact: `workshop/docs/research/ux-research-2026-09-01.md`, 1,231 lines, carrying a **ranked**
      proposals section (16 proposals, ordered by value per unit of effort with stated effort bands),
      a separate rejected-with-reasons section, and 194 source URLs — ranked and sourced, which is
      exactly what FR-044a requires it to be. `workshop/docs/session-evidence/phase7-report.md`
      records FR-044a/b (T094/T095) as citing the finding each effect rests on. Re-derive by reading
      those paths, not this sentence.
- [x] T095 [US5] [TDD] Implement reduced-motion support: final visual state preserved without the
      transition, and no effect load-bearing for comprehension (FR-044b)
- [x] T096 [US5] [TDD] Prove **SC-021**: an automated audit per view plus a keyboard-only traversal
      that **visits every deep-link affordance** and asserts each can be reached, activated and
      returned from

**Checkpoint**: the product is a learning surface and nothing was lost getting there.

---

## Phase 8: User Story 6 — four-format export (P6)

- [x] T097 [US6] Port the export toolchain design as-is, driving it from the **capability probe** in
      T004 rather than from a name on `PATH`
- [x] T098 [US6] [TDD] Implement **G-KG-9**: an unavailable toolchain yields **could not determine**,
      never an empty format list (FR-049). **Paired mutation**: return an empty list instead
- [x] T099 [US6] [TDD] Implement the publication precondition: an area without a review exports
      nothing **and says so** (FR-048, A3.9.1)
- [x] T100 [US6] [TDD] Implement citation preservation across all four formats (FR-047)
- [ ] T101 [US6] Port diagram rendering from text source — reproducible, unlike an embedded binary
      (FR-014a)

      **OPEN. Re-measured 2026-09-03, and leaving it UNWIRED is now backed by three separate
      disqualifying findings — each one on its own is enough to rule out "make `export_area` call
      `render_diagram`" as the fix.** The renderer function is implemented and covered in isolation;
      the function that assembles a published area's four formats does not invoke it. Re-derived
      here rather than read:

      ```bash
      grep -rn 'render_diagram(' workshop/pipeline/ --include=*.py | grep -v 'def render_diagram'
      # 5 call sites, all in the two test/verify modules; export_area is not among them
      ```

      1. **The renderer is unusable, and asking it for a version hides that.** Measured directly on
         this host, not carried forward:

         ```bash
         mmdc -V                                  # 11.12.0   rc=0
         printf 'graph TD\n A-->B\n' > t.mmd
         mmdc -i t.mmd -o t.svg; echo "rc=$?"     # rc=1 — and no t.svg is written
         ```

         The version query succeeds; the actual 2-node render fails and produces no file. This is the
         same trap the export contract's own **A3.9.2** warns about — a name on `PATH` and a version
         string are not evidence of capability, so capability has to be exercised. Wiring the call on
         the strength of the version query would break every published area instead. Worth naming:
         T083's export probe refuses to accept a `--version` answer for exactly this reason, and this
         task is the case that shows the refusal earning its keep.
      2. **There is no input to render.** `grep -c 'mermaid' workshop/docs/training/areas/*.md`
         returns **0** for each of the five area documents, so the new code path would be dead for
         every document that exists.
      3. **Nobody has decided where a diagram lives in an area document**, and this is the binding
         ground. FR-014a requires text-source authoring but is silent on placement, and the SC-005
         skeleton fixes seven headings with none for a diagram. Choosing a heading name, a fence tag,
         and whether an area may hold more than one is a content/contract decision, not a coding one.

      **A justification that overstated its own support has been corrected upstream, and it is
      logged here instead of being absorbed without trace.** Eighteen Mermaid sources across six files sit
      under `workshop/docs/training/diagrams/` — held outside the area documents precisely so they do
      not pre-empt finding 3. The README there defended that placement partly on the grounds that the
      platform's own front end displays them. **It does not**, measured 2026-09-03: `grep -rn mermaid
      platform/frontend/src/` returns **0**, and none of the Angular workspace's 23 dependencies is a
      Mermaid renderer. The README has been fixed inside `workshop/`. The fences do display in
      GitHub/GitLab viewers, which is what makes source form a defensible choice — but not here.

      Full investigation, both measurement dates, and the defects row
      `render-diagram-never-called`: **`workshop/docs/limits.md` §10.5**.
- [x] T102 [US6] [TDD] Prove **SC-024**: the file-existence matrix must be **complete**. Record the
      reference's measured 25-of-34 beside it, so nobody later matches the reference and calls it done

      **DONE. Every clause of the PARTIAL note this task carried is WITHDRAWN, not restated** — it
      said the §3.9 route still 404s, that `export.py` hardcoded `review=None`, that the matrix had
      never been exercised over real content, and that the reference's 25-of-34 was not recorded
      beside a workshop matrix. All four were true when measured earlier on 2026-09-03 and **all four
      were fixed later the same day**, while this reconciliation was in progress. Re-measured after
      the change, by execution:

      ```bash
      cd workshop/pipeline/extract
      ../venv/bin/python -c "import export; print(export.real_materials_export_status(produce=False))"
      # rc=0 — 2 published area(s) of 5; 3 blocked by A3.9.1; 0 blocked by SC-012
      #        matrix: 2/2 area(s) carry all four formats
      bash workshop/platform/gates/verify-sc024-export-matrix.sh    # rc=0, live against :8087
      ```

      **Both halves of the task are satisfied and both were watched, not assumed.** The matrix is
      **complete — 2 of 2** published areas carry markdown, html, docx and pdf. The reference's
      **25 of 34** is printed on the same run, and the gate labels it in its own output as recorded
      **beside** the result and never as the bar — 25/34 is 73.5%, and SC-024 requires 2/2, so
      matching the reference would specifically NOT be this criterion met. That is the exact
      misreading this task was written to prevent.

      **The fix is worth recording, because two defects were hiding each other.** The old caller
      passed `review=None` — a constant, so the branch it selected described the function rather than
      the tree — and it passed the document's filesystem **path** where reviews are keyed by the
      minted **ULID**, so a review that HAD loaded could never have matched. Neither was observable
      while the other stood: nothing looked a review up, so the key mismatch never got the chance to
      fail. Identity now resolves through the same production promotion path the authoring stage
      uses. `curriculum/publication-reviews.jsonl` holds **2** reviews, and they are the same 2 area
      ids — of 495 — that `GET /api/areas/{area}` serves at 200, so the Python and Go paths now agree
      where they previously disagreed. `real_materials_export_status` is read-only by default;
      producing artifacts is an explicit `--produce-real-materials` step.

      **Paired mutation, executed rather than cited** (`verify_export.py --prove-failure`, rc=0): with
      the review store mutated to return nothing, the function drops to 0 published areas and rc=2 —
      *the pre-fix behaviour reproduced exactly* — and unmutated returns 2 and rc=0. Registered as
      `T102-review-identity-not-hardcoded` in `platform/gates/check-registry-002.tsv` with its proof
      named in the row.

      **Honest boundary (§11.4.6), and it does not withhold the tick:** the SC-024 shell gate itself
      (`verify-sc024-export-matrix.sh`, registered as `T102-sc024-export-matrix`) carries **no**
      `--prove-failure` and no paired-proof column — `bash … --prove-failure` returns rc=2 `unknown
      argument`. The paired mutation above covers the identity mechanism the result turns on, not the
      matrix gate's own failure mode. Under this file's global constraint that **every** check owes a
      paired mutation, that shell gate still owes one.
- [x] T103 [US6] [TDD] Prove **SC-025** by **extracting text and diffing**, not by byte comparison —
      embedded timestamps make byte equality unachievable for some formats, and a criterion nobody can
      meet is worse than none

---

## Phase 9: User Story 7 — the repeatable pipeline (P7)

**Goal**: the next chapter runs through unchanged. This is the phase that distinguishes a finished
chapter from a finished feature.

- [x] T104 [US7] Extend the platform's **existing** chapter-addition procedure and its prompt with the
      knowledge-layer stages. **Do not create a second way to add a chapter** (S1) — two procedures
      for one act guarantee one of them rots
- [x] T105 [US7] [TDD] Implement three-valued exits and resumability on every new stage (S3, S4), with
      progress projected from **measured rate**, never from an estimate
- [x] T106 [US7] [TDD] Implement the taxonomy **update** path (S6): established areas keep their
      identifiers and gain evidence, newly evidenced areas are added, contradictions are reported
- [x] T107 [US7] [TDD] Prove **SC-015d**: capture the taxonomy before and after, assert **0**
      established identifiers changed and the contradiction report is non-empty when one was seeded.
      **Paired mutation**: re-derive area identifiers on each run
- [x] T108 [US7] Build a **small synthetic chapter** fixture — synthetic, because it must contain no
      workshop content and it must exercise the **minting** path
- [ ] T109 [US7] [TDD] Prove **G-KG-17 / SC-015c**: run the whole pipeline against the synthetic
      chapter; assert every output in S2 exists and the diff contains **no hand-created structural
      file and no code change**. **Paired mutation**: remove one stage; the gate must go red naming
      the missing output.
      **Do not substitute a re-run of the real chapter.** That tests idempotency, which is SC-004; it
      cannot test whether a *new* chapter works, because every identifier it needs already exists — the
      run would pass by matching and never by minting

      **PARTIAL (re-measured 2026-09-03, unchanged).** G-KG-17 exists, is registered
      (`G-KG-17-synthetic-chapter`) and runs the REAL `run_pipeline.run()` entry point against the
      synthetic chapter. Its own docstring (`prove_g_kg_17_synthetic_chapter` in
      `pipeline/extract/verify.py`, "SCOPED HONESTLY") still scopes it to extracted areas and themes
      plus the taxonomy file, and names the remainder of S2's output set — authored materials,
      question sets, cross-references, index entries, deep links — as owned by
      `platform/backend` or by stages not yet built, and explicitly does not claim to exercise them.
      T109 asked for **every** output in S2.
- [x] T110 [US7] [TDD] Prove **G-KG-18 / SC-015e**: withhold one required input; assert the run names
      exactly what is missing and publishes nothing. **Paired mutation**: downgrade it to a warning
- [x] T111 [US7] [TDD] Prove **S7**: no stage writes to a source. Assert every source file's size,
      modification time and inode are unchanged after a full run. **Paired mutation**: have a stage
      rewrite a source in place
- [x] T112 [US7] [TDD] Prove **S8**: evidence is written for every outcome, **especially** could not
      determine — the run that determined nothing is the one a reader most needs the record of.
      **Paired mutation**: skip evidence writing on the could-not-determine path

**Checkpoint**: the pipeline is observed producing a complete chapter, not reported as doing so.

---

## Phase 10: Polish and honest limits

- [x] T113 [TDD] Extend retrieval — **not generation** — over the new kinds (C4.3.1). Safe because the
      retrieval gate refuses before any model runs
- [x] T114 [REVIEW] Settle **U4**: does an entailment model load on this host? Three-valued exit. The
      platform's code claims it refuses to degrade silently; **a claim is not a measurement**
- [x] T115 [TDD] Implement the **answer-against-question**
      verification layer (FR-051) in the existing support-verifier seam. All four current layers
      verify the claim against the **passage**; none verifies it against the **question**, which is
      why a topically related fragment that does not answer what was asked passes all four

      **`[UNBUILT: decision taken 2026-09-02]` DISCHARGED 2026-09-03 — the layer was BUILT, WIRED
      AND PUSHED, and the marker was describing a state that no longer existed.** The code the
      marker was waiting on exists and runs: `platform/backend/pkg/answer/question.go` (L5, the
      deterministic question-demand floor) plus a new `platform/backend/pkg/answerhood/` (the model
      answerhood judge — deliberately **not** `pkg/entail`, because entailment relates
      passage→claim and answerhood relates question→claim, and conflating them is the defect this
      task names). Wired in `pkg/answer/pipeline.go` **after L4, not instead of it**: a
      `VerdictDeclined` yields `ReasonDoesNotAnswer`, so the topically-related fragment this task
      was written about is now refused. All of it landed in workshop `692a27a`, pushed.
      Re-derived 2026-09-03, not read from prose:

      ```bash
      bash workshop/platform/gates/verify-answer-question.sh          # rc 0 — 10/10 L5 properties
      bash workshop/platform/gates/prove-answer-question.sh           # rc 0 — CAUGHT 3, MISSED 0
      curl -s http://127.0.0.1:8087/api/ask/status | grep question_verifier_kind
      #   question-focus+llm — L5 is live on this deployment, not merely compiled
      ```

      Registered as `T115-answer-against-question` in `platform/gates/check-registry-002.tsv`.
      **Honest boundary, and it does not withhold the tick:** `docs/limits.md` §10.15 records the
      layer's measured cost and its four remaining weaknesses — fabrications fell 11 → 1 on the
      57-question benchmark and **spec 001's** fabrication criterion is still NOT met; floor 1 is
      strong on three demand classes and blunt on four; the judge defaults to the same model that
      generated the claim; L5 checks that the question was ANSWERED, never that the answer is
      CORRECT. Those are recorded tuning limits of a layer that exists. **Spec 002's own SC-010 is
      the identifier-survival criterion (`spec.md`), proven under T053 — it is a different
      criterion that happens to share a number, and it is not this task's acceptance.**
- [x] T116 [TDD] Implement **C4.3.4**: a verifier that was
      requested and could not load reports **could not determine** and does **not** degrade to the
      weaker one

      **`[UNBUILT: decision taken 2026-09-02]` DISCHARGED 2026-09-03.** The build-order dependency
      on T115 is discharged because T115 is built, and C4.3.4 landed with it in workshop `692a27a`.
      `pkg/answer/pipeline.go` maps a requested-but-undecidable verifier
      (`grounding.VerdictUnavailable`) to `CodeQuestionVerificationUnavailable` and **returns**
      — it does not fall through to `answered` on the strength of the layers that did run, which is
      what "does not degrade to the weaker one" means written as code rather than as a promise.
      Proven, not asserted: `prove-answer-question.sh` seeds `m2-silent-degrade` — a requested
      judge that could not decide being silently dropped — and the gate catches it (`CAUGHT 3
      MISSED 0`, re-run 2026-09-03). Registered separately as
      `T116-question-verifier-undetermined`. A nil verifier is a different case and is not treated
      as a pass either: `/api/ask/status` reports `question_verifier_kind: null` with prose naming
      what is therefore unchecked.
- [x] T117 Update the shipped limits document to name **every** open defect, including the measured
      fabrication rate on unanswerable questions and the undefended
      topically-related-but-non-answering case (FR-050)

      **DONE 2026-09-03. The note that stood here named its own closure condition and that condition
      is now met, so the claim *"It is measurably incomplete **right now**: `bash
      workshop/platform/gates/verify-limits-completeness.sh` exits **1** — `MISSING
      area-term-over-generation`, now 1 of **14** registered defects"* is WITHDRAWN, not restated.**
      The one-line fix it predicted was made, and the denominator moved again. Re-measured by
      execution, not read:

      ```bash
      bash workshop/platform/gates/verify-limits-completeness.sh
      #   rc=0 — checked 15 registered defect(s) against docs/limits.md
      #   OK: all 15 registered defect(s) are named in docs/limits.md.
      ```

      The fix was to the ANCHOR, not to the document's coverage, and it is worth recording because
      the failure mode was an instrument pointing at moving text: `defects-registry.tsv`'s
      `area-term-over-generation` row had quoted §10.9's heading, a retitle removed it, and the gate
      went red **for a document that had merely been corrected**. Its replacement anchor carries no
      moving count on purpose, and says so in its own row.

      **The two items this task names explicitly are both present, checked one at a time rather than
      inferred from the gate's exit code:** the measured fabrication rate on unanswerable questions
      is in §1.1 (2 of 10) and again in §10.15's before/after table (**11 → 1** on the 57-question
      benchmark, with the corpus-dependence of that figure stated); and the undefended
      topically-related-but-non-answering case is named in §10.11 in the contract's own words —
      *"none of the four existing verification layers checks a claim against the QUESTION, only
      against the passage, so a topically-related-but-non-answering fragment could pass all four
      unnoticed"* — with §10.15 recording the L5 layer that now defends it **and its four remaining
      weaknesses**.

      **Honest boundary (§11.4.6), and it does not withhold the tick:** *"every open defect"* is
      bounded by what `platform/gates/defects-registry.tsv` registers — **15** rows today, up from
      13 then 14. A defect nobody registered is invisible to this gate by construction, which is the
      same bound SC-026/T118 measures and not a new one. The count has moved three times in two
      days; re-run the gate rather than quoting 15.
- [x] T118 [TDD] Prove **SC-026**: cross-check recorded defects against the limits document; an
      unnamed defect fails. **Paired mutation**: remove one defect from the document
- [ ] T119 [TDD] Prove **SC-028**: drive every new check into a could-not-determine condition and
      assert the **third** state, not either of the other two

      **PARTIAL (re-measured 2026-09-03, unchanged).** `platform/gates/prove-sc028-undetermined-states.sh`
      exists and drives the three Phase-10 checks (T114/T118/T120) into their third state. The
      **18 G-KG-1..18 gates are still not independently re-driven** into a could-not-determine
      condition; `check-registry-002.tsv`'s `debt sc028-retroactive-coverage` row is still present
      and still records that as a gap rather than assuming compliance. **The population also grew
      on 2026-09-02** — five new rows landed (`T115-answer-against-question`,
      `T116-question-verifier-undetermined` and the three `T041-*` R3 rows) — so "every new check"
      now covers more than it did when this note was first written, not less.
- [x] T120 Register every new check in the check registry (SC-027). Note the registry prints known
      debt on every run **by design** — a zero exit means every check is accounted for, **not** that
      every check has a paired proof
- [x] T121 Update the platform's documentation set — quickstart, user guide, manual, FAQ — for the
      knowledge layer, and state plainly what it cannot do
- [ ] T122 [REVIEW] Final content-boundary check **in both directions** (SC-029, SC-029a), plus the
      fleet-wide no-CI gate (SC-030), plus `CONTINUATION.md` synchronised

      **PARTIAL (re-measured 2026-09-03, unchanged).** Two of three halves hold: the fleet no-CI
      gate is green (`git -C workshop ls-files '.github/workflows/*'` → **0**), and the umbrella
      `CONTINUATION.md` carries its spec-002 section. The **"both directions"** content-boundary
      half is still not satisfiable — SC-029a is not built (`docs/limits.md` §10.14, defects row
      `sc029a-not-built`), the same gap as T042. This is a FINAL review task in any case: it cannot
      honestly close while T022, T041 and T084 are open above it.

---

## Phase 11: On-screen text — OCR ingestion (added 2026-09-02, decision D5)

**Every task in this phase is `[UNBUILT]` in the exact sense the marker legend defines: the
clarification it waited on is SETTLED, the operator's decision is TAKEN, and what remains is code
nobody has written.** The operator chose **spoken PLUS on-screen OCR**, extending this specification
**in place**, and then chose to **specify now and build later**. No checkbox
in this phase may be ticked by the act of writing it down.

**"Nothing here is built" is WITHDRAWN as of 2026-09-03, and the correction is deliberately small:
one HALF of one task is built, and it is still unticked.** `workshop/pipeline/detect_ocr.sh` now
exists — the T123 toolchain capability probe, three-valued, registered in
`platform/gates/check-registry-001.tsv` as `ocr-toolchain-capability`, with a `--prove-failure` that
executes 6 mutations. **Twenty of twenty boxes in this phase remain unticked**, re-verified
2026-09-03 in a second reconciliation: `grep -rl screen_text` over `platform/`, `pipeline/` and
`docs/` returns **nothing**, and `find workshop -iname '*ocr*'` outside vendored environments returns
`pipeline/detect_ocr.sh` and an empty `platform/backend/ocrprobe/` directory — so T125's passage kind,
on which T126–T141 all sit, still does not exist. **The file-level count "unchanged at 100 ticked /
43 unticked" is WITHDRAWN, not restated: it is 104 / 39 of 143 after that reconciliation ticked
T063, T066, T069 and T117 — none of them in this phase, and nothing here was touched.** Read the
per-task notes below before planning any of
this: each of T123–T142 now carries a measured blocked-note naming what blocks it and on whom, and
the three classes are not interchangeable — **blocked on an OPERATOR** (T124, T130, T132, and the
missing speech-WER baseline behind T135), **blocked on a CAPABILITY that was measured rather than
assumed** (the per-chapter language-detection half of T123), and **merely unwritten** (T125, which is
the head of the chain, and T139, which is unwritten but must not run first).

**Two preamble claims below are now measured rather than inferred, and one of them changed sign.**
The OCR engine is not merely present: it reproduced a known fixture exactly, returned per-word
confidence and geometry, and survived a video encode → frame-sample → recognise round trip. What
does NOT work is the language-detection half — tesseract OSD misclassified an all-caps Latin fixture
as Cyrillic **at the highest confidence of the three fixtures tried**, so the wrong answer is the
confident one. The consequence for planning is specific: a task that assumed on-screen language
could be detected per chapter from the engine's own signal was assuming something this host does not
provide, and the substitute is a bake-off against T132's hand-truthed sample — which makes that half
of T123 downstream of an operator task, not of a decision.

**Sequenced after the tasks this specification already carries unbuilt — 18 as of 2026-09-03, down
from 28 when this phase was written, then 26, then 23, then 22, as T115/T116, T079/T083, T102 and
T063/T066/T069/T117 were built.** That is a deliberate
ordering, not a formality: on-screen mentions attach to areas, feed coverage figures and are exported
alongside spoken ones, so a Phase-3-to-Phase-10 defect reached through OCR-derived evidence would be
diagnosed twice.

**Purpose**: make the substance of a screen recording addressable — and make its accuracy a measured
quantity before a single on-screen mention is published.

**Why the accuracy obligation is the load-bearing half of this phase.** The risk in OCR is not that
it fails to run; it runs on this host. The risk is that it runs **well enough to look right** and
deposits thousands of passages whose text is approximately correct and whose timings are
approximately placed — degrading the measured accuracy of a corpus that currently has one, while
every published figure keeps looking precise. Speech recognition here is calibrated with a recorded
procedure (`workshop/pipeline/CALIBRATION.md`, `workshop/pipeline/compare_engines.py`,
`workshop/scripts/verify-accuracy.sh`, all three present, measured 2026-09-02). **A task that said
"OCR the video" without an accuracy budget would be exactly the defect this spec's own clarification
was raised to prevent.**

**Two host facts, measured 2026-09-02, and one that is NOT a capability claim.** The OCR engine
resolves at a **user-local** path and reports **three** language packs — consistent with contract
§7 V1's finding that every export tool on this host resolves user-locally, and the reason T123
probes rather than assumes. ~~**No OCR artifact of any kind exists in the workshop today**
(`find workshop -iname '*ocr*'` returns nothing outside vendored environments), so every task below
is genuinely unbuilt.~~ **WITHDRAWN 2026-09-03: one artifact now exists —
`workshop/pipeline/detect_ocr.sh`, the T123 toolchain probe. The same `find` now returns it. Every
task below is still genuinely unbuilt as a TASK, and the probe is exactly the reason that sentence
has to be rewritten rather than reused: an artifact existing and a task being done are different
claims.** The "three language packs" figure above also needs reading with care — re-measured
2026-09-03 they are `eng`, `rus` and `osd`, and **`osd` is a script-detection model, not a
recognition language**, so this host reads **two** languages, not three. And a boundary that must
not be misread: **every deep link in this deployment
resolves at SEGMENT width** — `workshop/docs/limits.md` §10.1 and the defects row
`precision-segment-only`. **"Joins the existing precision model" does not mean "word precision is
live."**

**Read that boundary from the SPAN, never from the `precision` field — the two disagree today.** An
attempt was made on 2026-09-03 to withdraw the sentence above on the strength of the field having
flipped to `word` after commit `ff90e09`; **that withdrawal was itself wrong and has been reversed.**
Measured the same day over 40 areas, entries labelled `word` have a median span of **7.650 s**
against **7.620 s** for entries labelled `segment` — the same width, and the recorded segment
distribution (median 6.74 s). `pkg/knowledge/wordjoin.go`'s `JoinSegmentWords` returns the first-to-
last word of the **whole segment**, so the flag reports sidecar completeness, not span width. See
T052's note. A `word` label on a 7-second span is a defect to fix, not a capability to build on —
and Phase 11 must not assume it.

**Independent test**: with the OCR stage run over one chapter, open any area and confirm that its
evidence distinguishes what was said from what was shown, that the two are counted once where they
coincide, and that both accuracy figures are published beside the speech-recognition ones.

- [ ] T123 [UNBUILT] [P] Gate **G-OCR-1** — capability-probe the OCR toolchain per contract §7 **V1**:
      invoke the engine with **the flag that matters**, never `--version`, and detect the recording's
      on-screen language **per chapter** per **V2**. Engine absent, or the needed language pack
      absent, yields **could not determine** — never empty text presented as "nothing on screen".
      **Paired mutation**: probe by name on `PATH` only; the gate must go red. This repository has
      already shipped a defect of exactly this shape — a media tool that answered a version query
      and rejected the flag that mattered
      **PARTIAL — measured 2026-09-03. The box stays unticked because half of this task is BUILT and
      half is not, and the unbuilt half is blocked on a capability that was MEASURED, not assumed.**
      **BUILT**: `workshop/pipeline/detect_ocr.sh` — three-valued (0 usable / 1 unusable / 2
      could-not-determine), registered in `platform/gates/check-registry-001.tsv` as
      `ocr-toolchain-capability`, with `--prove-failure` executing **6** mutations (M1 healthy, M2
      absent, M3 version-only, M4 silent, M5 no-wordbox, M6 undetermined) and a CONTROL asserting
      the M3 fake still passes a naive `command -v` + `--version` probe — the exact defect shape
      this task names. Every tool is exercised with the flag it will be used with, against a fixture
      whose text is KNOWN, and the output is COMPARED to that text: "non-empty" is not accepted,
      because a recogniser pointed at the wrong script returns confident nonsense rather than
      nothing (measured: a Cyrillic fixture read with `-l eng` returned a fluent-looking Latin
      transliteration, rc 0). Measured on this host, exit **0** — tesseract 5.5.2 at a user-local
      path reproduced a 29-word fixture exactly, `tsv` returned 32 scored word rows all carrying
      positive geometry (mean conf 96.2), packs are `eng,rus` (`osd` is script detection and is NOT
      counted as a language), and an ffmpeg encode -> `-vf fps=1` sample -> OCR round trip returned
      the fixture exactly. **Two host traps were re-measured while building it, and both shaped the
      design.** The `ffprobe` symlink trap this repository already documents was reproduced
      independently (answers `-version` rc 0, rejects `-show_format`); and a second one that was not
      on record: the same ffmpeg advertises `--enable-libfreetype --enable-fontconfig` in its own
      `-version` configuration string and has **no `drawtext` filter**. A tool's self-description is
      not a capability measurement either, which is why the probe fixture is EMBEDDED rather than
      drawn at run time. **NOT BUILT — the per-chapter on-screen LANGUAGE detection half (V2).
      BLOCKED ON CAPABILITY, on nobody's decision.** Tesseract OSD is the only detector this
      toolchain offers and it was measured wrong: three synthetic fixtures whose ground truth is
      Latin returned mixed-case -> Latin (confidence 5.15), source code -> Latin (7.41), and
      **ALL-CAPS -> CYRILLIC (18.33)**. The wrong answer arrived with the HIGHEST confidence of the
      three, so a confidence floor selects for the error instead of filtering it — and all-caps is
      not exotic in a screen recording, it is headings, UI labels and terminal banners. A fourth
      measurement bounds it further: OSD exits 1 on a sparse frame ("Too few characters"), and a
      frame with little text is the NORMAL case when sampling a recording — that outcome is
      could-not-determine and is never "nothing was on screen". What would unblock this half is a
      per-language recognition bake-off scored against **T132**'s hand-truthed sample, so it is
      downstream of T132 rather than of any decision. The probe carries the limitation as an
      `advisory` row that reproduces the measurement on every run and can never move the exit code
- [ ] T124 [UNBUILT] [REVIEW] Settle **U6** — what sampling period keeps an on-screen visibility
      interval **no coarser than the segment precision it sits beside**? Measure it against the
      recorded segment distribution (median **6.74 s**, p95 **10.78 s**, max **20.22 s**); do not
      pick a round number. Three-valued exit. Record under `workshop/evidence/`. **T126 and T128 are
      bounded by this** — an interval bound chosen before it is measured is the same class of guess
      the no-threshold rule forbids elsewhere
      **BLOCKED ON OPERATOR — measured 2026-09-03.** U6 is a clarification and settling it is the
      operator's decision, not an agent's. Nothing technical is waiting: the inputs are already
      recorded (segment distribution median 6.74 s, p95 10.78 s, max 20.22 s) and the sampler is no
      longer hypothetical — `pipeline/detect_ocr.sh` has now measured frame sampling working on this
      host. What is waiting is the choice of period, which this line explicitly forbids rounding to
      a convenient number
- [ ] T125 [UNBUILT] [TDD] [REVIEW] Gate **G-OCR-2** — declare `screen_text` as a **passage kind** in
      the registry contract per `data-model.md` §2.9: minted through the **same** minter, resolved
      through the **same** four-outcome resolver, ordering key = visibility onset, provenance `ocr`
      and distinct from `asr`, engine confidence carried, redaction flag inherited. **Paired
      mutation**: mint an OCR passage through a second minter or a second identifier format; the
      gate must go red. **A fifth kind, not a fifth registry** (FR-060)
      **MERELY UNWRITTEN — measured 2026-09-03. Nothing blocks this but the work, and it is the HEAD
      of the phase's dependency chain.** No operator decision and no missing capability stands in
      front of it. The registry it must extend is `workshop/platform/backend/pkg/search/`
      (`catalog.go`, `service.go`, and the kind strings asserted in `catalog_test.go`). It was not
      attempted in this pass for two stated reasons rather than one: it is substantial
      implementation rather than the tractable subset the pass was scoped to, and that package was
      being edited concurrently by another agent. **T126-T141 all sit behind it**
- [ ] T126 [UNBUILT] [TDD] Implement sampling and recognition across a chapter recording, producing
      text plus a **visibility interval** and its **interval bound** (FR-061). The sampling period is
      a **recorded parameter** the run writes into its evidence, never a literal in the code — and
      the bound is never omitted and never presented as zero. Sources open read-only per **S7**
      **BLOCKED ON T124 (operator) AND T125 — measured 2026-09-03.** The toolchain half is no longer
      in doubt: `pipeline/detect_ocr.sh` exits 0 and proved frame sampling plus per-word recognition
      with confidence and geometry on this host, so nothing here is blocked on a capability. What is
      missing is the sampling period, which T124 must settle and which this task is forbidden to
      hardcode, and the passage kind T125 must declare first
- [ ] T127 [UNBUILT] [TDD] Gate **G-OCR-3** — implement the **stability rule**: text visible across
      consecutive samples is **one** passage with one interval, not one per sample. **Paired
      mutation**: emit one passage per sample; the gate must go red. This is not tidiness — a static
      slide left up for two minutes would otherwise inflate an area's evidence by the sampling rate,
      and the inflated count is what publication decisions rest on
      **BLOCKED ON T125 AND T126 — measured 2026-09-03.** The stability rule operates over
      consecutive samples, and neither the passage kind nor a sampler that emits any exists yet. Not
      blocked on capability: the engine's `tsv` output carries the per-word geometry this rule needs
      to decide that two samples show the same text
- [ ] T128 [UNBUILT] [TDD] Gate **G-OCR-4** — join `screen_text` mentions to the **existing
      two-valued** precision model (FR-062, contract §3 N1/N2): declare `segment`, carry the
      **interval bound** beside it exactly as `word` precision carries timing confidence (N3).
      **Paired mutations**: (a) introduce a third `precision` value; (b) declare `word` precision on
      an OCR mention. Both must go red — (a) because every consumer switches on two values,
      (b) because no per-word timing record produced that time
      **BLOCKED ON T125, BOUNDED BY T124 — measured 2026-09-03.** Nothing to join until the kind
      exists, and the interval bound this task must carry beside `segment` precision is exactly the
      quantity T124 has not settled. Not blocked on capability
- [ ] T129 [UNBUILT] [TDD] Gate **G-OCR-5** — record **modality** (`spoken` / `on_screen`) on every
      mention, derived from the passage kind and never guessed, and mark a subject evidenced **only**
      on screen as `on-screen-only`, the modality analogue of `uncertain-only` (FR-012, FR-063).
      **Paired mutation**: default the modality to `spoken` where it is unset; the gate must go red.
      A term the workshop displayed but never discussed is a different fact from one it taught, and
      a reader who cannot tell them apart will over-read the taxonomy
      **BLOCKED ON T125 — measured 2026-09-03.** Modality is derived from the passage kind, so there
      is nothing to derive it from until the kind is declared. Not blocked on capability and not on
      an operator
- [ ] T130 [UNBUILT] [REVIEW] Settle **U7** — the **corroboration window**. A term is commonly
      displayed *before* it is discussed, so measure the observed lead/lag distribution between
      on-screen and spoken occurrences rather than assuming coincidence. Three-valued exit. Record
      under `workshop/evidence/`. **T131 is bounded by this**: a window tuned to zero lag
      under-groups, and a window widened until the numbers look tidy over-groups — and over-grouping
      destroys evidence silently
      **BLOCKED ON CAPABILITY FIRST, THEN OPERATOR — measured 2026-09-03.** Unlike T124, this
      clarification cannot be settled from anything already recorded: it asks for the observed
      lead/lag distribution between on-screen and spoken occurrences, and **no OCR output exists in
      this tree to measure a distribution over**. T126 must run first. Settling U7 on the resulting
      distribution is then the operator's decision
- [ ] T131 [UNBUILT] [TDD] Gate **G-OCR-6** — implement **corroboration grouping** per
      `data-model.md` §2.10: mentions of one subject whose times overlap within the measured window
      form one group, and every publication, coverage and attachment figure counts **groups**, never
      raw mentions (FR-063). Both figures are published together; **neither mention is deleted** and
      both stay individually retrievable and navigable. **Paired mutations**: (a) count raw
      mentions; (b) widen the window to the whole chapter. Both must go red — (b) because two
      genuinely distinct occurrences twenty minutes apart would collapse, which is how
      deduplication turns a corpus into a vocabulary list
      **BLOCKED ON T130 — measured 2026-09-03.** The window is the parameter this task groups by,
      and it is unmeasured. Not blocked on capability
- [ ] T132 [UNBUILT] [TDD] Build the **hand-truthed ground-truth sample** — drawn by a recorded seed
      so it is reproducible, with the **population size published** beside it, matching the sampling
      discipline T081 already uses. This artifact is the input to **both** accuracy axes; a figure
      published without its seed and population is not a measurement anyone can re-derive
      **BLOCKED ON OPERATOR — measured 2026-09-03, and this one cannot be automated away.**
      Hand-truthing is human labour, performed over a private recording of a teaching session with
      an identifiable third party. No agent can substitute for it here, and the obvious shortcut is
      the precise mutation **T133** requires to go red: a machine-produced "ground truth" scored
      against machine output measures nothing. The seed and population-size discipline this line
      asks for is already demonstrated by T081 and needs no new capability. **T133, T134 and —
      through them — the closure of spec 002 all sit behind this operator task**
- [ ] T133 [UNBUILT] [TDD] Gate **G-OCR-7** — measure **textual** accuracy per chapter: word error
      rate and character error rate against T132's sample, scored by the **same** edit-distance
      method the speech calibration already uses, so the two figures are comparable rather than
      merely adjacent (FR-064, SC-031). **Paired mutation**: score against the recogniser's own
      output instead of the ground truth; the gate must go red
      **BLOCKED ON T132 (operator) — measured 2026-09-03.** There is no ground truth to score
      against. The edit-distance method this must share with the speech calibration already exists
      (`pipeline/compare_engines.py`), so the scorer is not the gap; the reference is
- [ ] T134 [UNBUILT] [TDD] Gate **G-OCR-8** — measure **temporal** accuracy per chapter: the
      proportion of on-screen mentions whose declared visibility interval **contains** the moment the
      text was actually on screen (FR-064, SC-032). **Paired mutation**: assert only that an interval
      exists; the gate must go red. **This axis is separate from T133 deliberately**: deep linking
      depends on this figure and on no other, and a perfect textual score is entirely compatible
      with every interval being wrong — a text-only measurement cannot see the failure at all
      **BLOCKED ON T132 (operator) — measured 2026-09-03.** Same missing reference. Note the axis
      separation this line already argues for is now measurable in principle:
      `pipeline/detect_ocr.sh` confirmed the engine returns per-word bounding boxes, which is what a
      visibility interval is ultimately derived from
- [ ] T135 [UNBUILT] [TDD] Gate **G-OCR-9** — implement the **accuracy budget, derived and never
      picked** (FR-064a): the floor is **read at run time** from the recorded speech calibration for
      the same corpus, and the gate publishes the OCR figures and the speech baseline **together**
      (SC-033). Three-valued — calibration record or ground-truth sample unreadable ⇒ **2**, never
      a pass. **Paired mutations**: (a) hardcode the floor as a literal; (b) measure accuracy over
      the frames the engine was tuned on. Both must go red. **This is how an accuracy budget is
      stated without violating the no-guessed-threshold rule**: U2 and U3 forbid guessing a target
      for a quantity nobody has measured, and this floor is not guessed — it is read from a
      measurement this project already has
      **BLOCKED ON A MISSING MEASUREMENT — measured 2026-09-03 — and this is NOT merely "blocked on
      T133 and T134". The floor this gate is required to READ AT RUN TIME does not exist.** This
      task derives the budget from "the recorded speech calibration for the same corpus", and that
      record was checked rather than assumed: `workshop/pipeline/CALIBRATION.md` carries **no WER
      figure**. Its own U4 row reads *"achievable WER | open — needs §5's blind human reference"*,
      and it states expressly that the engine-to-engine divergence (3.19 %) **is not a WER and must
      never be quoted as one**. So even after T133 and T134 produce OCR figures, there is nothing to
      compare them against, and the one number lying nearby is explicitly disqualified — quoting it
      would be precisely the substitution this line's mutation (a) forbids. **Unblocking needs the
      blind human reference of CALIBRATION.md §5, which is operator labour**, in addition to
      T132/T133/T134. Recorded here because the task as written reads as though its input were
      already in hand, and it is not
      **THE BLOCKING INPUT IS NOW SPECIFIED, SEEDED AND HANDED OVER — under spec 001's T037, not
      here. Updated 2026-09-03; still BLOCKED, and the block is unchanged operator labour, but it is
      no longer unattributed.** The blind human reference CALIBRATION.md §5 needs is exactly the
      reference `specs/001-workshop-curriculum-platform/tasks.md` **T037(b)** specifies: 30 seeded
      30 s windows over chapter 01, 900.0 s = 15 min of audio, listed with exact `t0`/`t1` bounds in
      `workshop/chapters/01/transcript/accuracy-plan.json`, costed at **1–2 hours**. **ONE piece of
      human work satisfies both 001's SC-002 and this task's FR-064a floor** — it is not two
      transcription jobs, and it must not be scheduled as two. The plan was re-emitted on 2026-09-03
      under `research/transcription.md` §5.2's **ten equal temporal strata** (3 windows each,
      occupancy `[3,3,3,3,3,3,3,3,3,3]`, 0 empty, 0 overlapping), superseding a confidence-stratified
      set; a reference transcribed against the superseded windows would match nothing. Running
      `bash workshop/scripts/verify-accuracy.sh 01 --reference <path>` writes
      `workshop/chapters/01/transcript/accuracy.json`, and **that file is the record this gate reads
      at run time** — seeded, reproducible, population published, scored by the **same**
      `pipeline/compare_engines.py` edit distance T133 must share, which is what makes SC-031's
      *"comparable rather than merely adjacent"* structural instead of coincidental.
      **A SAMPLED estimate satisfies FR-064a — checked, not assumed.** FR-064a says *"read from the
      recorded speech-recognition calibration"* and never says exhaustive; FR-064 makes the OCR side
      itself a **sample**; and this task's own three-valued clause says *"ground-truth **sample**
      unreadable ⇒ 2"*. **A whole-chapter WER is NOT required.** Had it been, T037 would not close
      this and that would be recorded here instead.
      **THREE THINGS THIS DOES NOT GIVE YOU, named so they are not discovered late.** (1) **Scope:**
      FR-064b/SC-034 are per chapter and this reference covers **chapter 01 only** — no other
      chapter acquires a floor. (2) **CER:** SC-031 requires the OCR figure as WER **and** CER;
      `verify-accuracy.sh` computes **WER only**. Producing a speech CER needs **no additional human
      work** — the same reference text yields it — but it needs a **T112 change** in 001, and
      without it SC-033 publishes an asymmetric pair. (3) **Temporal symmetry:** T134/SC-032 measure
      a temporal axis; the speech-side analogue is 001's timestamp-error companion metric (SC-003),
      whose only possible input is the `onset_s` mark the reviewer makes **while listening**. T037's
      handover asks for it as an optional field for exactly this reason — skipped, it costs a second
      1–2 hour listening pass. SC-033's wording does not demand it, so its absence does not fail
      this gate; it forecloses a symmetry that is nearly free today.
      **THE ESTIMATOR UNIT, if any interval is ever put on either figure: the WINDOW / SAMPLE UNIT
      (n = 30 clusters), never the word.** Words inside one 30 s window are not independent draws,
      and WER is not a proportion — insertions let `(S+D+I)/N_ref` exceed 1, which no binomial
      admits. At the limit of perfect intra-window correlation a word-level interval is narrower by
      up to `√(N_hyp/30) ≈ 8×`, **overstating** precision. **Nothing in this project computes an
      interval today**, and `accuracy.json` carries no interval field — it carries this warning in
      `sample.estimator_unit` instead
- [ ] T136 [UNBUILT] [TDD] Gate **G-OCR-10** — implement the **per-chapter publication precondition**
      (FR-064b): no OCR-derived mention is published for a chapter until **that chapter's** accuracy
      run has been observed passing. **Paired mutation**: publish from a chapter whose accuracy
      run returned could-not-determine; the gate must go red. Font, resolution and compression differ
      between recordings, so a figure measured on one chapter is not evidence about another — the
      same per-chapter discipline **V2** already applies to word timings
      **BLOCKED ON T135 — measured 2026-09-03.** There is no budget to precondition publication on.
      Not blocked on capability
- [ ] T137 [UNBUILT] [TDD] Gate **G-OCR-11** — extend the content-boundary check over OCR output and
      run it **before** publication (FR-065, SC-036). **Paired mutation**: scope the check to
      transcript text only; the gate must go red. **On-screen text is a wider disclosure surface than
      the transcript** — a recording displays window titles, file paths, identifiers and names that
      nobody ever said aloud, so a boundary check written against spoken text does not cover this
      kind. The umbrella repository is public and this material is not
      **BLOCKED ON T125 AND T126 — measured 2026-09-03.** The check must run over OCR output and
      none is produced yet. Worth restating rather than deferring silently: this task guards the
      widest disclosure surface in the phase, and the umbrella repository is public while this
      material is not, so it must land BEFORE T141 wires the stage into the chapter-addition path —
      not after
- [ ] T138 [UNBUILT] [TDD] Index `screen_text` on its own text and prove **G-KG-11** for it — an
      advertised kind must be **retrievable**, proven by a planted known target, **never** by a row
      count. Do not advertise the kind until it is retrievable (FR-066). The corpus already
      advertises `diagram` with **0** entries, and this task exists so a second such kind is not
      created
      **BLOCKED ON T125 — measured 2026-09-03.** Nothing to index until the kind exists. Not blocked
      on capability
- [ ] T139 [UNBUILT] [P] Add the contract sections and route-manifest rows for the `screen_text`
      kind, its evidence entries and the modality and interval-bound fields (FR-059). Gate
      **G-KG-1**. This task is also what moves gates **G-OCR-1**..**G-OCR-11** into `contracts/`,
      where the gate-attachment closure check enumerates them — they are attached to task lines
      already, so that check must still print `unattached: 0` after this task lands
      **MERELY UNWRITTEN, AND DELIBERATELY NOT DONE IN THIS PASS — measured 2026-09-03.** No
      capability and no operator decision blocks the contract text. It was left alone anyway,
      because doing it first would move eleven `G-OCR-*` ids into `contracts/` while **none of the
      eleven gates exists**, publishing gate identifiers for gates nothing builds. The
      gate-attachment closure check would still report `unattached: 0` — every id is already carried
      on its task line — so the check would stay green while the contract described a capability the
      tree does not have. That is a green instrument reporting on the wrong question, and the
      correct order is gates first, contract second. Measured before and after this pass with the
      corrected extractor: **19 ids, `unattached: 0`**, unchanged
- [ ] T140 [UNBUILT] [TDD] Prove redaction reaches **OCR-derived** mentions across all eight targets
      in `data-model.md` §5. Gate **G-KG-7** extended. **Paired mutation**: restrict propagation to
      the spoken modality; the gate must go red. The eight targets do not change — what must be
      proven rather than assumed is that the propagation was not written against ASR-derived
      mentions only
      **BLOCKED ON T125 AND T126 — measured 2026-09-03.** There are no OCR-derived mentions for
      redaction to reach. Not blocked on capability
- [ ] T141 [UNBUILT] [US7] Add the OCR stage to the platform's **existing** chapter-addition path per
      **S1** — a stage added, **not a second procedure**; three-valued and resumable per **S3**/**S4**;
      writing to no source per **S7**; writing evidence on every outcome including could-not-determine
      per **S8**. Gate **G-KG-17** extended to assert the OCR outputs appear in the synthetic-chapter
      run. **Paired mutation**: remove the OCR stage; the gate must go red naming the missing output
      **BLOCKED ON T126 — measured 2026-09-03.** There is no OCR stage to add to the
      chapter-addition path. Not blocked on capability: the two tools the stage would call, frame
      sampling and recognition, are both measured working by `pipeline/detect_ocr.sh`
- [ ] T142 [UNBUILT] [REVIEW] Publish both OCR accuracy figures **beside** the speech-recognition
      ones in the shipped limits document and state plainly what OCR cannot do (FR-050 discipline);
      register every check added by this phase (SC-027); and drive each of **G-OCR-1**..**G-OCR-11**
      into its **could-not-determine** condition and assert the third state (SC-028). A figure
      published alone is not an accuracy claim a reader can act on, and a gate never observed in its
      third state is not known to have one
      **BLOCKED ON EVERY TASK ABOVE — measured 2026-09-03.** This is a final review task and it
      cannot honestly close while any of T123-T141 is open. One part of it is already partly
      satisfied and should not be re-counted later: **G-OCR-1** has been driven into its
      could-not-determine condition and the third state asserted — `pipeline/detect_ocr.sh
      --scratch-dir /nonexistent/detect-ocr-probe` exits **2**, executed on every default run of
      `platform/gates/verify-check-registry-001.sh` as that row's registered rc-2 probe. The other
      ten `G-OCR-*` gates do not exist, so nine tenths of this obligation is untouched

- [ ] T143 [UNBUILT] Build **G-KG-1-changed** and its §1.1 paired mutation: assert that every §4
      *changed* endpoint carries a route-manifest row whose contract citation names **both** its
      `001/contracts/http-api.md` section and its §4 subsection here (R1b), and prove the gate red
      by **rewriting** one such citation back to its 001-only form — leaving the row otherwise
      byte-identical. The mutation must be a rewrite, not a deletion: `G-KG-1`'s deletion mutation
      cannot reach this defect, because every §4 row is **present** throughout and the failure is a
      row that is present but under-cites. **PARTIAL, 2026-09-03 — the DEFECT is fixed and the box
      is unticked, but the stated reason has been CORRECTED the same day and the correction makes
      the residue smaller and sharper.** The compound form already existed on three
      of the four changed endpoints (`3.6+002.4.2`, `3.7+002.4.1`, `3.11+002.4.4`); §4.3's answering
      row carried a bare `3.10` and now reads `3.10+002.4.3`, so R1b is met 4 of 4 as measured that
      day (`verify-server-unity.sh` re-run after the edit: `PASS=35 FAIL=0 UNDET=0 DEBT=4`, exit 0).

      **WITHDRAWN, not restated: *"the GATE is not built"* and *"Nothing enforces it."*** Both were
      wrong when written and the measurement is one command:

      ```bash
      grep -n 'G-KG-1-changed' workshop/platform/gates/check-registry-002.tsv
      #   29: check  G-KG-1-changed  go-test
      #       internal/api/knowledge_gates_test.go::TestGateKG1_ChangedEndpointsCiteTheDeltaContract
      cd workshop/platform/backend
      go test -count=1 -run TestGateKG1_ChangedEndpointsCiteTheDeltaContract ./internal/api/...  # ok
      ```

      A gate carrying this exact id exists, is registered, is green, and its §1.1 pair
      (`platform/backend/gates/prove-knowledge-manifest-mutation.sh`) performs the **rewrite**
      mutation this task specifies rather than a deletion — its own header says it *"rewrites one of
      the three contract columns back to its bare specs/001 token in the REAL production manifest,
      requires this test to go RED with its own message, restores the file byte-identically and
      requires it GREEN again."* All of that landed in workshop `bd7da41`, before this task was
      written.

      **What is genuinely still owed — and it is the one endpoint this task was created for.** The
      existing gate's `want` table enumerates **three** rows: `GET /api/search` (3.7+002.4.1), `GET
      /api/suggest` (3.6+002.4.2) and `GET /api/progress` (3.11+002.4.4). Its own doc comment scopes
      itself that way, naming §4.1, §4.2 and §4.4 and attributing itself to **T070**. **`/api/ask`
      — §4.3, the fourth changed endpoint and the only one whose citation was actually wrong — is
      absent from the table.** So the gate covers 3 of 4, and the row whose `3.10 → 3.10+002.4.3`
      repair is recorded above is enforced by nothing: the next edit that drops that suffix still
      restores the violation silently.

      **This box therefore stays `[ ]`, and the remaining work is now a small, named change rather
      than a gate from scratch:** add the `/api/ask` row to the existing table (and, per §1.1, a
      fourth rewrite case to `prove-knowledge-manifest-mutation.sh`, whose current mutation set does
      not touch it). Do not tick this on the strength of the gate existing — a gate that enumerates
      three of four obligations is green about the three and blind to the fourth, which is the same
      blind-instrument shape the closure check's own `THE BLIND ZERO` note records one section
      below.

      **Measured while re-deriving this, and recorded rather than absorbed: the paired proof could
      NOT be re-run to completion today** — `bash platform/backend/gates/prove-knowledge-manifest-mutation.sh`
      returned rc=1 with `7 proven / 1 problem / 1 undetermined`, and the problem and the
      undetermined are both a **Go build break from concurrent editing in this tree**
      (`internal/redaction/taxonomy.go: t.ProposalsUnlinked undefined`, and earlier
      `pkg/index/generation.go:170: declared and not used: declined`), not a defect the proof found.
      That is a COULD NOT DETERMINE on the proof's own health, and a 2 is never a pass; the gate
      itself was green minutes earlier on the same tree

**Checkpoint**: on-screen text is addressable, counted once where it coincides with speech, and its
accuracy is **measured and published beside the speech baseline**. **This is the checkpoint that
closes spec 002** — until T133, T134 and T135 have produced figures, this feature is not finished
regardless of how many checkboxes above it are ticked.

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
- **T114 blocks T115 and T116.** **Discharged 2026-09-02** — T114 ran and settled U4 (the
  entailment judge produced a DECIDED verdict on this host). ~~T115 and T116 are unbuilt, not
  blocked.~~ **Superseded 2026-09-03: both are BUILT and ticked.** The whole chain — U4 measured,
  decision taken, verifier built, gates registered and green, live on the deployment — is closed.
- **T085 blocks T091.** The before-list must exist before the reshaping it measures.
- **T004 blocks T097 and T098.**
- **Phase 11 is sequenced after every unbuilt task above it.** On-screen mentions attach to areas,
  feed coverage figures and export alongside spoken ones, so a Phase-3-to-Phase-10 defect reached
  through OCR-derived evidence would be diagnosed twice.
- **T124 bounds T126 and T128** (the sampling period, hence the interval bound). **T130 bounds T131**
  (the corroboration window). Both are `[REVIEW]` measurements with three-valued exits, and both
  exist so a number is measured rather than picked.
- **T125 blocks T126–T141.** Nothing may produce, join, count or index a `screen_text` passage before
  the kind exists in the registry contract.
- **T132 blocks T133 and T134**, which together block **T135**, which blocks **T136**. The budget
  cannot be evaluated before both axes are measured, and nothing may be published before the budget
  is evaluated.
- **T133, T134 and T135 block the closure of spec 002 itself.** This is the dependency D5 added.
- **T031 is blocked on the prose-authorship clarification** — and on nothing else, and it is now the
  ONLY `[BLOCKED: …]` marker left in this file; ~~**T094** on the
  UX research~~; ~~**T115/T116** on the answering clarification~~ — **both withdrawn 2026-09-02**:
  the answering clarification is decided and U4 is measured, so T115/T116 became `[UNBUILT]`, not
  `[BLOCKED]` — **and on 2026-09-03 that marker was discharged too, because the code was written**;
  T094's blocker was resolved by a real ranked, sourced research artifact
  (`workshop/docs/research/ux-research-2026-09-01.md`), and T060's was discharged when T059 settled
  U1 (`workshop/docs/session-evidence/phase5-report.md`).
- **The rule this section used to state — *"Markers record what a task waited on, not what it is
  still waiting on — read the checkbox for that"* — is WITHDRAWN, not restated.** It was a rule
  written to excuse two stale markers rather than to remove them, and it made `[BLOCKED: …]`
  unreadable: under it, a marker asserted nothing a reader could act on, and the only way to learn
  whether a task was actually held up was to ignore the marker. **The markers on T060 and T094 were
  stripped on 2026-09-02 instead**, with the discharge and its evidence recorded in each task's own
  note, so the history survives without the standing claim. The rule in force now is the plain one:
  **a `[BLOCKED: …]` marker means the task is blocked TODAY.** Discharge it by removing the marker
  and recording what discharged it — never by redefining what the marker means.

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
| Phase 11 | the two OCR accuracy figures, published beside the speech-recognition ones |

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
| G-KG-17 | T109, T141 |
| G-KG-18 | T110 |
| G-KG-1-changed | T143 |

**19 gates, 19 paired mutations, all owed. The `18 gates, 18 paired mutations` figure this line
carried is WITHDRAWN, not restated** — it was the population the OLD, blind extractor could see, and
the nineteenth id (`G-KG-1-changed`, defined in `contracts/http-api-delta.md` §5) was missing from
this table for the same reason it was missing from the closure check: an extractor that stopped at
the digits read it as `G-KG-1`. See `THE BLIND ZERO` below. A gate never observed failing is not
known to work, and every proof must include a case that runs the real entry point against the real
tree.

### On-screen text gates — added 2026-09-02, and NOT yet in `contracts/`

| Gate | Task | Subject |
|---|---|---|
| G-OCR-1 | T123 | OCR toolchain capability-probed, not assumed from a name on `PATH` |
| G-OCR-2 | T125 | `screen_text` mints through the one existing minter |
| G-OCR-3 | T127 | one passage per contiguous visibility, never one per sample |
| G-OCR-4 | T128 | precision stays two-valued; interval bound carried beside it |
| G-OCR-5 | T129 | modality declared on every mention; `on-screen-only` marked |
| G-OCR-6 | T131 | evidence counted over corroboration groups, never raw mentions |
| G-OCR-7 | T133 | textual accuracy measured per chapter against a seeded truth sample |
| G-OCR-8 | T134 | temporal accuracy measured per chapter — intervals actually contain the text |
| G-OCR-9 | T135 | budget read from the speech calibration, never a literal; three-valued |
| G-OCR-10 | T136 | nothing published from a chapter whose accuracy was not measured |
| G-OCR-11 | T137 | OCR output passes the content boundary before it reaches a public artifact |

**Eleven gates, eleven paired mutations, all owed and none built.**

**Honest boundary on the closure check — read this before quoting its green result.** The
gate-attachment closure check enumerates gate ids from `contracts/`, and `contracts/` is **not**
modified by this change. It still defines exactly the **18** `G-KG-*` ids, so the check's population
is unchanged and it reports **`unattached: 0`** — measured 2026-09-02 both before and after this
phase was written. **That zero is a true result and it is not evidence about these eleven gates:
they are not in its population yet.** A green check here says nothing whatever about `G-OCR-*`, and
reading it as though it did would be exactly the blind-instrument error the standing rules name.

**T139 is the task that puts them into the population**, and the forward guarantee was made
checkable rather than promised: all eleven ids were placed on the **task line itself** — not on a
continuation line — and that was verified, so the check must still report `unattached: 0` the moment
T139 lands, under **either** reading of "attached". Measured 2026-09-02: 11 of 11 `G-OCR-*` ids
satisfy the strict line-anchored form. If a later run reports one unattached, the failure is real
and belongs to whoever moved the id off its task line.

```bash
# THE CLOSURE CHECK, in the wrap-aware form this file's line-wrapping requires.
# A contract gate must be carried by a TASK BLOCK — the "- [ ] T###" line plus its
# indented continuation lines. Prints one row per unattached gate; silence = closed.
cd specs/002-knowledge-areas-deep-linking
awk '
  /^- \[[ xX]\] T[0-9][0-9][0-9]/ { if (blk!="") print blk; blk=$0; next }
  /^## /                          { if (blk!="") print blk; blk=""; next }
  /^[[:space:]]*$/                { next }
  /^[[:space:]]/                  { if (blk!="") blk = blk " " $0; next }
  { if (blk!="") { print blk; blk="" } }
  END { if (blk!="") print blk }
' tasks.md > /tmp/blocks.txt
miss=0
for g in $(grep -rhoE 'G-[A-Z]+-[0-9]+(-[a-z]+)*' contracts/ | sort -u); do
  grep -qE "${g}([^0-9A-Za-z-]|$)" /tmp/blocks.txt || { echo "UNATTACHED $g"; miss=$((miss+1)); }
done
echo "unattached: $miss"     # 19 ids. On 2026-09-03 the corrected extractor
                             # first reported ONE — G-KG-1-changed; it is now
                             # attached to T143, so this reads 0. The ONE is
                             # what the old extractor could not see at all.
```

> **THE BLIND ZERO, found 2026-09-03 — and this file is where it actually bit.** Feature 001's
> companion section records the general lesson; this is the instance. Until that date both
> regexes above were `G-[A-Z]+-[0-9]+` and `([^0-9]|$)`, and this check printed `unattached: 0`.
> **That zero was blind, not clean.** The extractor stops at the digits, so the id
> `G-KG-1-changed` — defined in `contracts/http-api-delta.md` §5 — was read as **`G-KG-1`**, a
> different gate that *is* attached, to T040. The compound id never entered the loop, so it
> could be neither attached nor reported. The corrected extractor sees **19** ids where the old
> one saw 18, and the nineteenth reports `UNATTACHED G-KG-1-changed`.
>
> **What the blind zero was hiding is worse than an unattached id.** `G-KG-1-changed` asserts
> R1b: every §4 *changed* endpoint carries a manifest row citing **both** its 001 section and
> its §4 subsection here. Measured the same day, the compound citation form already exists and
> three of the four changed endpoints carry it — `3.6+002.4.2` (`/api/suggest`),
> `3.7+002.4.1` (`/api/search`), `3.11+002.4.4` (`/api/progress`). **§4.3's rows carried a bare
> `3.10`.** So the gate nobody could see was a gate that would have been **red**, and the thing
> it would have caught was a real, standing contract violation — not a bookkeeping slip.
>
> T040 was **not** the right place to attach it, and attaching it there would have been the
> papering-over this section exists to forbid: T040 builds the manifest rows for the endpoints
> **new in §3**, whereas R1b governs rows that already existed from feature 001 and were only
> *amended*. The gate needs a task that owns that work — see **T143**.

> **Why the wrap-aware form, and why presence-counting is not the check.** Feature 001 records the
> durable lesson: a set-difference over identifiers appearing *anywhere* in the file went green the
> moment a paragraph **describing** the missing gate mentioned its id — documenting the defect fixed
> the check while the defect stood untouched. The check must therefore be anchored to a task, not to
> the file. It must also be anchored to a task **block** rather than a task **line**, because this
> file wraps its tasks across several lines: run against `tasks.md` in the single-line form 001 uses,
> five ids (`G-KG-1`, `G-KG-5`, `G-KG-7`, `G-KG-10`, `G-KG-12`) report unattached purely because
> their id fell past a line break. That is a measurement of the line-wrapping, not of the gates. The
> block form above is the same closure condition read correctly, and **both counts were re-measured
> after this phase was added and neither moved**.

## Implementation strategy

Build Phase 2 completely and stop. It is the only phase whose defects are invisible — a wrong
identifier scheme, a conflated precision or a collapsed resolution outcome all keep rendering links
that look correct. Everything after it fails loudly by comparison.

Then take one area end to end — promoted, evidenced, authored, linked, searchable, assessed,
exported — before applying the pattern to the rest. A pattern proven on one area is cheap to correct;
the same mistake made across every area is a migration.

**Phase 11 comes last, and its accuracy tasks come before its publication task.** The ordering inside
the phase carries the same logic as Phase 2's: measure the property that is invisible when wrong
before anything depends on it. OCR that is 90% right looks identical to OCR that is 99% right in
every interface built on top of it — the difference is only ever visible in a measurement, and only
if that measurement was taken before the mentions were published rather than after somebody
complained.

**Task count: 143**, contiguous `T001`–`T143`, verified by parsing this file rather than by counting.
Of those, **104 are ticked and 39 are not** — **18** carried forward from `T001`–`T122` and **21 in
the Phase 11 block** (`T123`–`T142`, added 2026-09-02, none of the twenty built, plus `T143`, added
2026-09-03). **Every earlier figure is WITHDRAWN, not restated**, and the sequence is kept because
the reason each one died is the lesson:

- *"Task count: 122 … `T001`–`T122`"* — superseded when Phase 11 added twenty tasks.
- *"94 ticked and 48 not / 28 carried forward"* — superseded 2026-09-03 by T115 and T116.
- *"96 ticked and 46 not / 26 carried forward"* — **it was already wrong when this file was last
  read**: the tree measured **97/45**. T055 had been ticked without its own note or this block being
  updated, so the file disagreed with itself in two places at once. That is exactly the failure mode
  the "re-derive" instruction below exists to catch, and it caught it.
- *"99 ticked and 43 not / 23 carried forward"* — held for roughly an hour. It was written after
  T079 and T083 were reconciled and superseded by T102 **within the same reconciliation**.
- *"Task count: 142 … 100 ticked and 42 not / 22 carried forward"* — **wrong in two independent
  ways at once, and neither was a tick.** The TOTAL was already 143 when it was written: `T143` had
  been added to this file and this block was not updated with it, so the file disagreed with itself
  about how many tasks it contains — the identical failure the `96/46` bullet above records, one
  line lower. And the split was then superseded by the T063/T066/T069/T117 ticks below.

The present 104/39 reflects a second reconciliation on 2026-09-03, which ticked **T063** (SC-014
proven over every one of 560 hits, with an `M1-locus` mutation that fails the RUN), **T066** (the
new-kinds benchmark, now in `platform/backend/testdata/benchmark/` beside the gate that reads it),
**T069** (search filters and locus display, 97/97 unit tests) and **T117** (the limits-completeness
gate at rc=0, 15 of 15). **Nothing was un-ticked to pay for them**, the twenty Phase 11 `[UNBUILT]`
tasks were not touched, and `T041` was left entirely alone because another agent was editing it.

**Read the `142` bullet as a warning about this whole block, not as trivia — and read T102's as the
same warning one turn earlier.** T102 was measured `[ ]` with a hardcoded `review=None`, and was
fixed, gated and paired-proven **while this file was being edited** — the note written for it was
stale before it was saved, and only a re-measurement caught it. The second reconciliation then found
**six** notes stale in the same way (T063, T066, T068, T069, T117, T143), every one of them because
work landed under them within hours. **A count here is a reading of one moment.** Re-derive rather
than trusting the sentence above; this file's checkbox state has now gone stale five times:

```bash
cd specs/002-knowledge-areas-deep-linking
grep -c '^- \[x\] T' tasks.md    # 104
grep -c '^- \[ \] T' tasks.md    # 39
grep -c '^- \[[ xX]\] T' tasks.md  # 143
grep '^- \[ \] T' tasks.md | grep -c '\[UNBUILT\]'   # 21 — the 20 Phase 11 OCR tasks plus T143
```
