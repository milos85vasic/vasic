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
    after this specification's already-unbuilt tasks — **26 as of 2026-09-03**, the figure of 28
    this line carried being superseded by the T115/T116 ticks rather than wrong when written.
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
      skeleton; `/api/areas` now serves **495** areas at generation **54**, so **490** have no
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

      **PARTIAL (re-measured live 2026-09-03 at generation 54, unchanged).** All four routes serve
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
- [ ] T041 [US1] [REVIEW] Human checkpoint: the reconciliation of promoted against extracted areas.
      A wrong merge here is a wrong curriculum, and every later artifact inherits it

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

      **PARTIAL (re-measured live 2026-09-03). The precision split IS published; the GATE is what
      is missing — and the stated REASON it was missing has expired.** `internal/api/evidence.go`
      emits `precision_split` on every response (line 184). No gate anywhere asserts that **every**
      media-backed citation lands inside its cited span over the whole set: `grep -rn 'SC-009'`
      across `platform/gates/`, `platform/backend/` and `pipeline/` returns only source comments
      plus `backend/gates/bench-answers.sh`, where `SC-009` names spec **001**'s benchmark-
      composition floor and not this criterion at all. That gate is the work.

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

      **None of this ticks the task**, and the reason is unchanged: the SC-009 gate does not exist.
- [x] T053 [US2] [TDD] Prove **SC-010**: replay the identifier-survival experiment extended to all
      five new kinds; compare the full link set before and after **by hash**
- [x] T054 [US2] [P] Add route-manifest rows and contract sections for the endpoints in this phase
- [x] T055 [US2] [P] [SUBAGENT] Build the transcript-to-knowledge affordance in the existing
      transcript view — the entry point for "what is being taught at this moment"

      **NOT DONE (re-measured 2026-09-03, unchanged).** The backend half is live: `GET
      /api/passages/{pid}/knowledge` returns 200 and carries each term inline with its `href`. The
      front-end affordance was deferred in Phase 4 and never picked up in Phase 7 —
      `platform/frontend/src/app/core/api.ts` still has **no** `/api/passages/{pid}/knowledge` call
      (its passage call still ends at `crossrefs`, line 286) and
      `features/transcript/transcript.component.ts` still contains **zero** `knowledge` references.
      This is front-end-only work.
- [x] T056 [US2] [REVIEW] Review the link model against the contract before the surface consumes it

**Checkpoint**: the graph is complete and bidirectional, and both precisions are honest.

---

## Phase 5: User Story 3 — search over everything (P3)

**Goal**: all four content kinds searchable, every hit says where.

- [ ] T057 [US3] [TDD] Index the four new kinds — `area`, `term`, `lesson_section`, `question` —
      indexing **their own text**, not only the passages they cite. A question findable only through
      its citations is not findable by anyone who does not already know the answer (D-KG-10)

      **PARTIAL (re-measured live 2026-09-03, unchanged).** `/api/search`'s `corpus.indexed_kinds`
      still returns exactly `[transcript_segment, doc_section, code, diagram, area, term]`. `area`
      and `term` are indexed on their own text and retrievable. `lesson_section` and `question` are
      **not indexed** — **2 of the 4** kinds this task names (`docs/limits.md` §10.8, defects row
      `lesson-question-not-indexed`). Blocked in turn on T031/T075 content reaching a server-side
      store. The 2026-09-02 switch to the nomic embedding index changed the retrieval MODEL, not
      the set of kinds.
- [ ] T058 [US3] [TDD] Advertise the new kinds in the corpus block, and prove **G-KG-11**: an
      advertised kind must be **retrievable**, proven by a planted known target — **not** by a row
      count, which cannot distinguish a populated index from a populated table nobody queries. The
      corpus already advertises one kind with zero entries

      **PARTIAL (re-measured live 2026-09-03, unchanged).** G-KG-11 is proven in both directions by
      a planted known target rather than a row count, as required — but its scope is `area` + `term`
      only. `lesson_section` and `question` are still neither advertised in the live
      `corpus.indexed_kinds` nor proven, because T057 does not index them.
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
- [ ] T063 [US3] [TDD] Prove **SC-014** over **every** hit of the benchmark run — a hit without a
      resolving locus fails the run, not merely itself

      **PARTIAL (re-measured 2026-09-03, unchanged).** Per-hit locus withholding is proven
      (`TestToHit_WithholdsUnresolvedLocus`). The "over **every** hit of the benchmark run" half is
      still not implemented: `grep -c locus pipeline/benchmark/run_retrieval_benchmark.py` returns
      **0**, so no hit can fail the RUN. The file was edited on 2026-09-02 for the embedding switch
      and gained no locus handling.
- [x] T064 [US3] [TDD] Implement kind and area filters per **C4.1.5**, echoing the applied filter so a
      client can tell a filtered empty result from an unfiltered one
- [x] T065 [US3] [TDD] Add area and term names to suggestions per **C4.2.1**, and prove **C4.2.2**:
      the suggestion service still holds **no embedder**. Type-ahead stays lexical — semantic
      embedding under load has been observed in the tens of seconds against a 200 ms budget
- [ ] T066 [US3] Build the ≥20-query benchmark for the new kinds in the platform's existing benchmark
      directory, beside the gates that read it, with expected identifiers fixed **in advance**

      **PARTIAL (re-measured 2026-09-03).** `pipeline/benchmark/retrieval_benchmark.json` meets the
      ≥20-query and fixed-expectations requirements — **26** positive plus **12** negative queries
      with expected identifiers fixed at build time — and it has since been executed at full scale
      (`SC015-FINDINGS.md`, `results_nomic_full_prefixed.json`). Both halves this task actually asks
      for are still unmet: it is NOT in the platform's existing benchmark directory
      (`platform/backend/testdata/benchmark/` still holds only the specs-001 `questions.tsv`) and
      **no gate reads it**. The one reference from platform code —
      `cmd/workshop-server/main.go:1039` — is a **source comment** citing the file as the provenance
      of the calibrated floor. A comment is not a reader; nothing executes the benchmark from the
      platform side, and `check-registry-002.tsv` has no row naming it.
- [ ] T067 [US3] [TDD] Prove **SC-015**: the gate prints **per-query** outcomes, not only the
      aggregate — which queries fail is the useful information, and an aggregate hides it

      **PARTIAL (re-measured 2026-09-03, unchanged).** `run_retrieval_benchmark.py` prints
      per-query outcomes as required. It is still **not a gate**: its only exit is `return 0` (line
      309) — no `1`, no `2`, so it is not three-valued — and it still has no row in
      `platform/gates/check-registry-002.tsv`.

      **And SC-015 itself is settled NO, which is the second reason this stays unticked.** The
      criterion needs ≥90% of ≥20 queries returning the expected item in the top five — 24 of 26 on
      this benchmark. Measured on the served path after the embedding switch of 2026-09-02: top-5
      **20/26**, top-1 8/26. That is a real improvement over the 13/26 before it and it is still
      below the bar. A gate built now would correctly go red; building it is the work, not
      reaching the number.
- [ ] T068 [US3] [TDD] Prove **SC-016 / SC-017**: re-run the latency harness and **publish before and
      after together**. A single after-figure cannot show a regression that stayed inside the threshold

      **PARTIAL (re-measured 2026-09-03, unchanged).** `docs/limits.md` §2 publishes three latency
      columns side by side with the spread called out, so the publish-before-and-after-together
      discipline is real. The newest column is still the 17:57 UTC one taken against **1,101**
      passages, and its own search p95 of **2,094.8 ms** already breaches SC-017's 2 s budget by
      4.7%. No re-run against today's grown corpus is recorded anywhere — measured 2026-09-03 that
      corpus is **11,622** registry rows, of which **2,478** are the retrievable non-`kg_*` corpus,
      with a **9,406**-row taxonomy beside it. The task needs a fresh harness run published
      **beside** the 1,101-passage column, not replacing it.
- [ ] T069 [US3] [P] [SUBAGENT] Extend the search view for the new kinds, the filters and the locus
      display

      **PARTIAL (re-measured 2026-09-03, unchanged).** The new kinds render as badges in
      `features/search/search.component.ts`. The **filters and the locus display are still absent**:
      `core/api.ts:273` is still `search(q: string, limit = 20)` setting only `q` and `limit` — no
      `kinds`, no `area` — and the component still contains **zero** `locus` and **zero** `filter`
      references. That component was touched on 2026-09-02 by a 3-line styling change only.
- [ ] T070 [US3] [P] Update the route manifest and contract for the changed search and suggest
      endpoints

      **PARTIAL (re-measured 2026-09-03, unchanged).** `platform/gates/route-manifest.tsv` carries
      `/api/suggest`, `/api/search` and `/api/progress`, and all three rows still cite the **001**
      contract sections (3.6 / 3.7 / 3.11). There are still no rows or notes for the 002 delta
      sections **§4.1** (locus/offsets/kinds/filters), **§4.2** (areas and terms in suggest) or
      **§4.4** (progress over areas).

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
- [ ] T079 [US4] [TDD] Implement `GET /api/areas/{area}/coverage` per §3.6: **per-area figures,
      never only an aggregate**; sections with zero questions listed explicitly; **no threshold and no
      pass field**. Gate **G-KG-12**. **Paired mutation**: replace the per-area table with a mean

      **PARTIAL (re-measured live 2026-09-03, unchanged).** The measure is built and gated —
      `pkg/assessment/coverage.go` plus G-KG-12 and its paired mutation
      (`TestT079_PairedMutation_ReplacePerAreaTableWithMean`), with no threshold and no pass field.
      **The §3.6 endpoint is still not built**: `GET /api/areas/{area}/coverage` returns **404**
      live against a real published area id, `main.go` registers `/api/areas`, `/api/areas/{area}`,
      `/api/areas/{area}/evidence` and `/api/areas/{area}/questions` and **no** coverage route, and
      there is no `route-manifest.tsv` row.
- [x] T080 [US4] [TDD] Prove **SC-018** by enumerating every served question and resolving every
      citation, and **record the reference module's measured value — 0 of 785 — beside it**, so the
      comparison is measured rather than claimed
- [x] T081 [US4] [TDD] Prove **SC-019**: the question-to-moment-and-back round trip, over every
      eligible question; if impractical, a seeded sample of ≥30 **with the population size published**
- [x] T082 [US4] [TDD] Extend progress to areas and question sets, and prove **C4.4.2**: progress
      **survives a content re-ingest**. The reference deliberately preserves its progress table while
      wiping everything else; a learner's history is not a derived artifact
- [ ] T083 [US4] [P] Add route-manifest rows and contract sections for the assessment endpoints

      **PARTIAL (re-measured live 2026-09-03, unchanged).** The questions row `002.3.5` is
      registered. **Coverage (§3.6) and export (§3.9) still have neither a manifest row nor a
      mounted route** — both return **404** live against a real published area id.
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

      **PARTIAL (re-measured 2026-09-03, unchanged).** `pipeline/extract/export.py:549
      render_diagram` is implemented and proven in isolation, but **`export_area` still never calls
      it** — `grep -rn render_diagram pipeline/` returns its definition plus call sites in
      `verify_export.py` and `test_export.py` only. No exported document can carry a diagram.
      `docs/limits.md` §10.5 investigates and deliberately leaves it unwired because the
      source-location convention is an unmade content decision (defects row
      `render-diagram-never-called`).
- [ ] T102 [US6] [TDD] Prove **SC-024**: the file-existence matrix must be **complete**. Record the
      reference's measured 25-of-34 beside it, so nobody later matches the reference and calls it done

      **PARTIAL (re-measured 2026-09-03, unchanged).** `export.py::file_existence_matrix` and
      `::sc024_matrix_is_complete` exist, but the matrix has **never been exercised over real
      content**: `real_materials_export_status` still hardcodes `review=None` at `export.py:713`
      with the comment that this ALWAYS raises `PublicationBlocked`, so every real area document
      reports PRECONDITION_BLOCKED even though 2 now have reviews, and the §3.9 route still 404s
      live. The reference's measured **25 of 34** is not recorded beside a workshop matrix.
      Registered as a status check, not a gate.
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
- [ ] T117 Update the shipped limits document to name **every** open defect, including the measured
      fabrication rate on unanswerable questions and the undefended
      topically-related-but-non-answering case (FR-050)

      **PARTIAL (re-measured 2026-09-03; still incomplete, and the denominator moved).**
      `docs/limits.md` §10 names the open defects with a consequence each, including the measured
      fabrication rate and the undefended topically-related-but-non-answering case — §10.15 was
      added for the L5 layer and the registry gained `l5-question-verifier-partial`, taking the
      enumeration from 13 rows to **14**. It is measurably incomplete **right now**: `bash
      workshop/platform/gates/verify-limits-completeness.sh` exits **1** — `MISSING
      area-term-over-generation`, now 1 of **14** registered defects — because §10.9's anchor text
      changed when that section was corrected and `defects-registry.tsv` was not updated with it.
      One-line fix; T118's gate is working, not broken.
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
**in place**, and then chose to **specify now and build later**. Nothing here is built. No checkbox
in this phase may be ticked by the act of writing it down.

**Sequenced after the tasks this specification already carries unbuilt — 26 as of 2026-09-03, down
from 28 when this phase was written, because T115 and T116 were built.** That is a deliberate
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
probes rather than assumes. **No OCR artifact of any kind exists in the workshop today**
(`find workshop -iname '*ocr*'` returns nothing outside vendored environments), so every task below
is genuinely unbuilt. And a boundary that must not be misread: **every deep link in this deployment
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
- [ ] T124 [UNBUILT] [REVIEW] Settle **U6** — what sampling period keeps an on-screen visibility
      interval **no coarser than the segment precision it sits beside**? Measure it against the
      recorded segment distribution (median **6.74 s**, p95 **10.78 s**, max **20.22 s**); do not
      pick a round number. Three-valued exit. Record under `workshop/evidence/`. **T126 and T128 are
      bounded by this** — an interval bound chosen before it is measured is the same class of guess
      the no-threshold rule forbids elsewhere
- [ ] T125 [UNBUILT] [TDD] [REVIEW] Gate **G-OCR-2** — declare `screen_text` as a **passage kind** in
      the registry contract per `data-model.md` §2.9: minted through the **same** minter, resolved
      through the **same** four-outcome resolver, ordering key = visibility onset, provenance `ocr`
      and distinct from `asr`, engine confidence carried, redaction flag inherited. **Paired
      mutation**: mint an OCR passage through a second minter or a second identifier format; the
      gate must go red. **A fifth kind, not a fifth registry** (FR-060)
- [ ] T126 [UNBUILT] [TDD] Implement sampling and recognition across a chapter recording, producing
      text plus a **visibility interval** and its **interval bound** (FR-061). The sampling period is
      a **recorded parameter** the run writes into its evidence, never a literal in the code — and
      the bound is never omitted and never presented as zero. Sources open read-only per **S7**
- [ ] T127 [UNBUILT] [TDD] Gate **G-OCR-3** — implement the **stability rule**: text visible across
      consecutive samples is **one** passage with one interval, not one per sample. **Paired
      mutation**: emit one passage per sample; the gate must go red. This is not tidiness — a static
      slide left up for two minutes would otherwise inflate an area's evidence by the sampling rate,
      and the inflated count is what publication decisions rest on
- [ ] T128 [UNBUILT] [TDD] Gate **G-OCR-4** — join `screen_text` mentions to the **existing
      two-valued** precision model (FR-062, contract §3 N1/N2): declare `segment`, carry the
      **interval bound** beside it exactly as `word` precision carries timing confidence (N3).
      **Paired mutations**: (a) introduce a third `precision` value; (b) declare `word` precision on
      an OCR mention. Both must go red — (a) because every consumer switches on two values,
      (b) because no per-word timing record produced that time
- [ ] T129 [UNBUILT] [TDD] Gate **G-OCR-5** — record **modality** (`spoken` / `on_screen`) on every
      mention, derived from the passage kind and never guessed, and mark a subject evidenced **only**
      on screen as `on-screen-only`, the modality analogue of `uncertain-only` (FR-012, FR-063).
      **Paired mutation**: default the modality to `spoken` where it is unset; the gate must go red.
      A term the workshop displayed but never discussed is a different fact from one it taught, and
      a reader who cannot tell them apart will over-read the taxonomy
- [ ] T130 [UNBUILT] [REVIEW] Settle **U7** — the **corroboration window**. A term is commonly
      displayed *before* it is discussed, so measure the observed lead/lag distribution between
      on-screen and spoken occurrences rather than assuming coincidence. Three-valued exit. Record
      under `workshop/evidence/`. **T131 is bounded by this**: a window tuned to zero lag
      under-groups, and a window widened until the numbers look tidy over-groups — and over-grouping
      destroys evidence silently
- [ ] T131 [UNBUILT] [TDD] Gate **G-OCR-6** — implement **corroboration grouping** per
      `data-model.md` §2.10: mentions of one subject whose times overlap within the measured window
      form one group, and every publication, coverage and attachment figure counts **groups**, never
      raw mentions (FR-063). Both figures are published together; **neither mention is deleted** and
      both stay individually retrievable and navigable. **Paired mutations**: (a) count raw
      mentions; (b) widen the window to the whole chapter. Both must go red — (b) because two
      genuinely distinct occurrences twenty minutes apart would collapse, which is how
      deduplication turns a corpus into a vocabulary list
- [ ] T132 [UNBUILT] [TDD] Build the **hand-truthed ground-truth sample** — drawn by a recorded seed
      so it is reproducible, with the **population size published** beside it, matching the sampling
      discipline T081 already uses. This artifact is the input to **both** accuracy axes; a figure
      published without its seed and population is not a measurement anyone can re-derive
- [ ] T133 [UNBUILT] [TDD] Gate **G-OCR-7** — measure **textual** accuracy per chapter: word error
      rate and character error rate against T132's sample, scored by the **same** edit-distance
      method the speech calibration already uses, so the two figures are comparable rather than
      merely adjacent (FR-064, SC-031). **Paired mutation**: score against the recogniser's own
      output instead of the ground truth; the gate must go red
- [ ] T134 [UNBUILT] [TDD] Gate **G-OCR-8** — measure **temporal** accuracy per chapter: the
      proportion of on-screen mentions whose declared visibility interval **contains** the moment the
      text was actually on screen (FR-064, SC-032). **Paired mutation**: assert only that an interval
      exists; the gate must go red. **This axis is separate from T133 deliberately**: deep linking
      depends on this figure and on no other, and a perfect textual score is entirely compatible
      with every interval being wrong — a text-only measurement cannot see the failure at all
- [ ] T135 [UNBUILT] [TDD] Gate **G-OCR-9** — implement the **accuracy budget, derived and never
      picked** (FR-064a): the floor is **read at run time** from the recorded speech calibration for
      the same corpus, and the gate publishes the OCR figures and the speech baseline **together**
      (SC-033). Three-valued — calibration record or ground-truth sample unreadable ⇒ **2**, never
      a pass. **Paired mutations**: (a) hardcode the floor as a literal; (b) measure accuracy over
      the frames the engine was tuned on. Both must go red. **This is how an accuracy budget is
      stated without violating the no-guessed-threshold rule**: U2 and U3 forbid guessing a target
      for a quantity nobody has measured, and this floor is not guessed — it is read from a
      measurement this project already has
- [ ] T136 [UNBUILT] [TDD] Gate **G-OCR-10** — implement the **per-chapter publication precondition**
      (FR-064b): no OCR-derived mention is published for a chapter until **that chapter's** accuracy
      run has been observed passing. **Paired mutation**: publish from a chapter whose accuracy
      run returned could-not-determine; the gate must go red. Font, resolution and compression differ
      between recordings, so a figure measured on one chapter is not evidence about another — the
      same per-chapter discipline **V2** already applies to word timings
- [ ] T137 [UNBUILT] [TDD] Gate **G-OCR-11** — extend the content-boundary check over OCR output and
      run it **before** publication (FR-065, SC-036). **Paired mutation**: scope the check to
      transcript text only; the gate must go red. **On-screen text is a wider disclosure surface than
      the transcript** — a recording displays window titles, file paths, identifiers and names that
      nobody ever said aloud, so a boundary check written against spoken text does not cover this
      kind. The umbrella repository is public and this material is not
- [ ] T138 [UNBUILT] [TDD] Index `screen_text` on its own text and prove **G-KG-11** for it — an
      advertised kind must be **retrievable**, proven by a planted known target, **never** by a row
      count. Do not advertise the kind until it is retrievable (FR-066). The corpus already
      advertises `diagram` with **0** entries, and this task exists so a second such kind is not
      created
- [ ] T139 [UNBUILT] [P] Add the contract sections and route-manifest rows for the `screen_text`
      kind, its evidence entries and the modality and interval-bound fields (FR-059). Gate
      **G-KG-1**. This task is also what moves gates **G-OCR-1**..**G-OCR-11** into `contracts/`,
      where the gate-attachment closure check enumerates them — they are attached to task lines
      already, so that check must still print `unattached: 0` after this task lands
- [ ] T140 [UNBUILT] [TDD] Prove redaction reaches **OCR-derived** mentions across all eight targets
      in `data-model.md` §5. Gate **G-KG-7** extended. **Paired mutation**: restrict propagation to
      the spoken modality; the gate must go red. The eight targets do not change — what must be
      proven rather than assumed is that the propagation was not written against ASR-derived
      mentions only
- [ ] T141 [UNBUILT] [US7] Add the OCR stage to the platform's **existing** chapter-addition path per
      **S1** — a stage added, **not a second procedure**; three-valued and resumable per **S3**/**S4**;
      writing to no source per **S7**; writing evidence on every outcome including could-not-determine
      per **S8**. Gate **G-KG-17** extended to assert the OCR outputs appear in the synthetic-chapter
      run. **Paired mutation**: remove the OCR stage; the gate must go red naming the missing output
- [ ] T142 [UNBUILT] [REVIEW] Publish both OCR accuracy figures **beside** the speech-recognition
      ones in the shipped limits document and state plainly what OCR cannot do (FR-050 discipline);
      register every check added by this phase (SC-027); and drive each of **G-OCR-1**..**G-OCR-11**
      into its **could-not-determine** condition and assert the third state (SC-028). A figure
      published alone is not an accuracy claim a reader can act on, and a gate never observed in its
      third state is not known to have one

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

**18 gates, 18 paired mutations, all owed.** A gate never observed failing is not known to work, and
every proof must include a case that runs the real entry point against the real tree.

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
for g in $(grep -rhoE 'G-[A-Z]+-[0-9]+' contracts/ | sort -u); do
  grep -qE "${g}([^0-9]|$)" /tmp/blocks.txt || { echo "UNATTACHED $g"; miss=$((miss+1)); }
done
echo "unattached: $miss"     # MUST be 0 — measured 2026-09-02 it IS 0
```

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

**Task count: 142**, contiguous `T001`–`T142`, verified by parsing this file rather than by counting.
Of those, **96 are ticked and 46 are not** — **26** carried forward from `T001`–`T122` and **20
added by Phase 11 on 2026-09-02**, none of the twenty built. **The figure this line carried, "94
ticked and 48 not / 28 carried forward", is superseded 2026-09-03, not wrong when written**: T115
and T116 were reconciled against work that landed and was pushed on 2026-09-02, and nothing was
un-ticked to pay for them. Both earlier counts, *"Task count: 122 … `T001`–`T122`"* and the 94/48
line, are superseded by this one.

Re-derive rather than trusting the sentence above — this file's checkbox state has gone stale twice:

```bash
cd specs/002-knowledge-areas-deep-linking
grep -c '^- \[x\] T' tasks.md    # 96
grep -c '^- \[ \] T' tasks.md    # 46
grep -c '^- \[[ xX]\] T' tasks.md  # 142
```
