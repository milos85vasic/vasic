# Implementation Plan: Authored AI/IT Knowledge Areas with Lessons, Tests and Video Anchors

**Branch**: `main` (this repository works on `main` only; `004-authored-ai-areas` is the spec directory, not a branch)
**Date**: 2026-09-07
**Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/004-authored-ai-areas/spec.md`

## Summary

Replace a catalogue of mined vocabulary with a catalogue of **authored AI/IT
subjects**, each carrying lessons, supporting materials, video anchors into the
recorded sessions, and a gated end-of-area test — and make every claim about
that catalogue provable by a three-valued gate with a data-driven mutation
proof.

**A large part of this plan is already built and measured.** This is not an
estimate: the work landed from three parallel streams during the session that
produced this specification. The plan therefore has an unusual shape — it
records **what is done and how it was verified**, **what is done but unverified
against real content**, and **what is not done** — because a plan that
re-proposes finished work would hide the two gaps that actually matter.

The technical approach in one line: **one decision function, one authored
content format, one time-link contract, and a gate for each — with the
publication decision computed once and consumed by every surface.**

## Technical Context

**Language/Version**: Go 1.26.2 (backend, `workshop/platform/backend`), TypeScript 5.x / Angular (frontend, `workshop/platform/frontend`), Python 3 (curriculum pipeline, `workshop/pipeline/extract/`), Bash (gates, `workshop/platform/gates/`)
**Primary Dependencies**: `submodules/curriculum-kit` (the reusable Catalog → Area → Lesson → Material + Assessment library), the existing passage registry (`workshop/curriculum/passages.jsonl`), the existing transcript segment sidecars (start/end times), the design token source under `design-system/`
**Storage**: Files. Authored content as JSON under `workshop/curriculum/learning/`; taxonomy, materials, reviews and time links as JSONL/JSON siblings; learner progress as a session-keyed JSON store under the index volume
**Testing**: Go `go test` (unit + handler gates), Playwright (frontend e2e), Bash three-valued gates with paired `prove-*.sh` mutation provers, Python `unittest` for the pipeline
**Target Platform**: Linux container (`podman`), served on `127.0.0.1:8087`; frontend bundle staged into `platform/web/`
**Project Type**: Web service + single-page application + content pipeline, inside a private module that must also clone standalone
**Performance Goals**: A learner reaches a scored test result without any step reporting not-found; video anchors position within 1 s of the referenced moment (SC-008)
**Constraints**: Content is PRIVATE and this umbrella is PUBLIC — no content may cross; the reusable library must stay project-unaware; every gate is three-valued and a 2 is never a pass; no CI, enforcement is local

**NEEDS CLARIFICATION**: none. The five open decisions were closed in
[spec.md § Clarifications](spec.md), each against a measurement. Two are flagged
there as most likely to want operator override (the area-set boundary and the
70% default pass threshold); neither blocks this plan, because the first changes
*which* areas are in scope and the second changes one declared number.

## Constitution Check

*GATE: Must pass before proceeding. Re-checked after design — see the second
table at the end of this document.*

| Principle | Status | Notes |
|---|---|---|
| **Evidence-Based Claims** | PASS | Every figure in this plan is a captured run or a file measurement. The three items that are **not** verified are named in *Known gaps*, not omitted. |
| **Honest Instruments** | PASS | All four new gates are three-valued and each ships a `prove-*.sh` whose mutations are DATA read from an env var, never code edits. Each prover carries a control mutation that must go green, and each carries a **vacuity refusal that exits 2** — asserted by the prover itself. |
| **Governance Fidelity** | PASS | No universal clause is weakened. New gates register in `platform/gates/check-registry-002.tsv`; `verify-check-registry-002.sh` currently exits **0** at `checks=94 debt=3`. |
| **Isolation by Default** | **NEEDS ATTENTION** | `curriculum-kit` is consumed by a `replace` directive pointing outside the repository, because it is a plain directory rather than a git repository and has no commit to pin. Inside the umbrella this builds; a standalone clone does not. See *Known gaps* — the remedy is upstream and is an operator decision. |
| **Comprehensive Documentation** | PASS | The time-link URL contract is written down (`platform/frontend/docs/time-links.md`) and is the producer's authority, not a convention. |
| **Environment Adaptability** | PASS | No absolute path is introduced. Gates build their own server from source on a kernel-assigned free port. |
| **Authored Curriculum** | PASS | The published set is the 37 authored subjects. An evidence-frequency floor was **measured and rejected** as a selector, because it made topicality worse (0 of 36 at floor 2 vs 32 of 814 at floor 1). |
| **Published Means Served** | **NEEDS ATTENTION** | Now enforced in code by a single `AreaPublicationOf`, and asserted end to end. But the **running container still serves the old binary and the old 819**; the served state is undetermined until it reloads. That is the principle's own failure mode and it is currently live. |
| **Derived Presentation** | **NEEDS ATTENTION** | Titles, tags and summaries are derived rather than stored — which is exactly why null-titled mined areas rendered as single synthesised words. The derivation is correct; whether the **served** stylesheet reflects the widened palette is unverified. |
| **Standalone Cloneable** | **NEEDS ATTENTION** | `verify-standalone-clone.sh` went 2 gaps → 3, and the new row is the `curriculum-kit` replace target. This is the gate working, not drift. |
| **Quality Over Speed** | PASS | Three areas fail publication review on 62, 54 and 58 uncited claim blocks and are **left failing**. Stamping them would be the bypass. |

**No principle is violated. Four need attention, and all four are recorded in
*Known gaps* with the measurement behind them.** None is silenced.

## Project Structure

### Documentation (this feature)

```text
specs/004-authored-ai-areas/
├── spec.md                      # Feature specification (393 lines)
├── plan.md                      # This file
├── research.md                  # Phase 0 — decisions, each with the measurement that decided it
├── data-model.md                # Phase 1 — entities, invariants, state
├── contracts/
│   ├── catalogue.md             # Area list + detail, publication reasons
│   ├── learning.md              # Lessons, materials, assessment, submission
│   ├── time-links.md            # Video anchor URL grammar
│   └── authored-document.md     # The on-disk authored content format
├── quickstart.md                # Runnable end-to-end validation
├── tasks.md                     # /speckit-tasks output
└── checklists/
    └── requirements.md          # Spec quality checklist (16/16)
```

### Source Code (repository root)

```text
submodules/curriculum-kit/               # The reusable library — project-UNAWARE
├── catalog.go  area.go  lesson.go       # Catalog → Area → Lesson → Material
├── material.go  anchor.go               # VideoAnchor{chapterId,start,end,transcriptAnchor}
├── assessment.go  question.go           # Answers by ID, never by index
├── availability.go                      # AvailabilityOf — the single gate
├── submit.go                            # Submit; returns no populated result when locked
└── document.go                          # DecodeDocument — REJECTS unknown fields

workshop/
├── curriculum/
│   ├── learning/NN-<slug>.json          # ← AUTHORED CONTENT (the remaining gap)
│   ├── taxonomy.jsonl                   # extracted areas + terms
│   ├── unpublished-areas.jsonl          # withheld rows, never deleted
│   ├── area-materials.jsonl             # materials per area
│   ├── publication-reviews.jsonl        # review per area
│   ├── area-timelinks.json              # measured spans → video anchors
│   └── questions/*.senior.json          # authored senior question banks
├── docs/training/curriculum-areas/      # 37 authored area documents
├── pipeline/extract/
│   ├── measure_module_evidence.py       # evidence per module, all chapters
│   ├── build_area_timelinks.py          # spans from segment sidecars
│   ├── promote_curriculum_areas.py      # publication, via the real minting bridge
│   ├── publication_policy.py            # the title-non-empty rule
│   └── verify_curriculum_areas.py       # gate, 11 data mutations
└── platform/
    ├── backend/internal/api/
    │   ├── area_publication.go          # AreaPublicationOf — THE decision, once
    │   └── lessons.go                   # the six learning routes
    ├── backend/pkg/learning/            # authoring layout, loader, session store
    ├── frontend/src/app/                # area detail, lessons, test, transcript
    ├── frontend/docs/time-links.md      # the URL contract
    ├── gates/verify-*.sh prove-*.sh     # 23 gates / 27 proofs and growing
    └── qa/fixtures/learning/            # synthetic corpus — every byte invented
```

**Structure Decision**: The reusable shape lives in `curriculum-kit` and knows
nothing about this project; `pkg/learning` is the only consumer that knows both.
That boundary is enforced by construction rather than by discipline —
`curriculum-kit` has an empty require set, so a project import would not compile.
`pkg/learning` contains **no second availability test, scoring routine or answer
comparison**; `AvailabilityOf` decides availability and `Submit` (never the
ungated `Grade`) decides whether a submission is allowed and what it scores.

## Execution Strategy

### TDD Requirements

- [x] **The publication decision** — TDD, and it is the reason D3 existed. Both handlers had passing unit tests; nothing tested the *pair*. `TestAreaListAndDetailAgree` is the test that had to exist. **Done.**
- [x] **The assessment gate** — TDD. The load-bearing mutation is B4/M7, "the gate opens as soon as *any* lesson completes": it passes B1, B2, B3, B5 and B7 and is caught **only** by B4, which is why the fixture's required set must be a proper subset of its lessons. **Done, 17 mutations.**
- [x] **Answer-key non-disclosure** — TDD, with a leak check that fails if `correct_choices` or `explanation` appears on the taking path. **Done.**
- [ ] **The authored-document loader against real content** — the loader rejects unknown fields, so the first authored file either decodes or fails loudly. Write one file, prove it loads, then write the rest. **In flight.**
- [ ] **Contrast and hue measurement of the SERVED bundle** — the check must read what is served, not what is in the token source. **Not done.**

### Parallel Execution Opportunities

Four streams have run concurrently and their file sets were disjoint by
construction. They are recorded because the partition is reusable:

- [x] **Content authoring** (`docs/training/`, `curriculum/`, `pipeline/extract/`) — no `platform/**` writes.
- [x] **Backend serving** (`platform/backend/**`, `platform/gates/**`) — no `curriculum/**` writes.
- [x] **Frontend** (`platform/frontend/src/app/**`) — components and routes.
- [x] **Theming** (`platform/frontend/src/styles/**`) — stylesheets only.

**One collision was observed and is the lesson**: the frontend stream measured a
stylesheet the theming stream was mid-rewrite of, and read a transiently
unbalanced file. The partition held; the *timing* did not. Any stream that
measures another stream's output must rebuild immediately before measuring, and
say which build it measured.

### Human Checkpoints

1. **Before the container restarts** — the restart is what makes the on-disk work
   served, and it is also what invalidates every "before" measurement. Do it once,
   deliberately, after all writers have stopped.
2. **Before any area is marked published without a review** — three areas fail on
   uncited claim blocks. They stay failing until a human reads them.
3. **Before `curriculum-kit` is published upstream** — that closes the standalone
   gap and is an operator decision.
4. **Before the 70% pass threshold is fixed** — the only decided value in the spec
   with no measurement behind it.

### Review Gates

- [x] **The publication decision function** — every surface consumes it; a second implementation is the defect class it exists to prevent.
- [x] **The time-link URL grammar** — a producer that emits a malformed span produces a link that looks fine and is broken.
- [ ] **The authored document format** — reviewed before 37 files are written to it, not after.

## Known gaps — what is NOT done, and what is done but unverified

Recorded here rather than in a footnote, because these are the difference
between this plan and a completion claim.

**Not done:**

1. **No authored learning content exists.** Every real area answers a determined
   `no_learning_catalog`. The six learning routes are proved against a synthetic
   bicycle-maintenance fixture and **have never been exercised against authored
   curriculum content**. Dispatched; in flight.
2. **The served palette is unmeasured.** Token files widened the hue span; no
   check reads the served stylesheet. SC-010 and SC-011 have no instrument yet.
3. **`difficulty` and `category` on questions cannot be closed here** — no such
   field exists in `curriculum-kit`. Upstream change required. Not fabricated.
4. **Spaced repetition is not ported.** The kit declines it deliberately; the
   interviewing module writes `streak`/`due_at` and reads neither.
5. **Chapter 02 was never mined into this taxonomy.** A topic taught only there,
   in words the chapter-01 lexicon lacks, is invisible to every coverage figure.

**Done but unverified, and therefore not a pass:**

6. **The running container serves the old binary and the old 819 areas.**
   `verify-server-unity.sh` is RED against it at 6 FAIL — all six the new routes
   answering a plain-text 404. Against a server built from this tree the same
   gate is `PASS=43 FAIL=0 UNDET=0 DEBT=8`. This clears on restart.
7. **The 8 diagram SVGs were not rasterised.** Well-formedness, theming and
   absence of external references are verified; text fit at a given font metric
   is not.
8. **`unpublished-areas.jsonl` holds 1,128 rows, a superset of the 814 actually
   withheld.** The exact 814 cannot be identified — the pre-filter taxonomy is
   git-ignored and was not retained.

**Blocked on an operator decision:**

9. **`submodules/curriculum-kit` is not a git repository.** It has no commit, so
   no truthful `helix-deps.yaml` entry can be written and a fabricated `ref:`
   would be a bluff. Recorded verbatim in `go.mod`.

## Post-design Constitution re-check

Re-evaluated after Phase 1 produced `data-model.md` and `contracts/`.

| Principle | Before design | After design | What changed |
|---|---|---|---|
| Evidence-Based Claims | PASS | PASS | The contracts state which figures are measured and which are undetermined. |
| Honest Instruments | PASS | PASS | Unchanged. |
| Governance Fidelity | PASS | PASS | Unchanged. |
| Isolation by Default | NEEDS ATTENTION | NEEDS ATTENTION | Unchanged — the remedy is upstream. |
| Comprehensive Documentation | PASS | PASS | The authored-document format is now written down before 37 files are written to it. |
| Environment Adaptability | PASS | PASS | Unchanged. |
| Authored Curriculum | PASS | PASS | Unchanged. |
| Published Means Served | NEEDS ATTENTION | NEEDS ATTENTION | The design adds a served corpus revision (FR-023a) so the discrepancy becomes detectable; it does not by itself resolve the live one. |
| Derived Presentation | NEEDS ATTENTION | NEEDS ATTENTION | Unchanged until a served-bundle instrument exists. |
| Standalone Cloneable | NEEDS ATTENTION | NEEDS ATTENTION | Unchanged. |
| Quality Over Speed | PASS | PASS | Unchanged. |

**No gate failed. No unresolved clarification remains.** Ready for
`/speckit-tasks`.
