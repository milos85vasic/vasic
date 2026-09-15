# Implementation Plan: Unified Workshop Platform

**Branch**: `main` (this repository works on `main` only)

**Created**: 2026-09-15

**Spec**: [`spec.md`](./spec.md) · **Tasks**: [`tasks.md`](./tasks.md)

**Supersedes**: the `plan.md` of specifications 001, 002, 003, 004, 006 and 007. Specification 005
**had no `plan.md`** — that absence is itself carried forward as a finding, not silently repaired:
its obtainability and red-state work was planned in its `tasks.md` alone, and this document is the
first place its technical approach is written down beside the others.

---

## Summary

This plan states the **union** of what the six existing plans establish, and resolves the four
technical disagreements between them. It does not re-derive any technical decision from zero: every
element below is either cited from a source plan or recorded as a merge resolution with its reason.

The shape it describes is one Go service plus one Angular single-page application, fronted by an
offline content pipeline in Python and Bash, all inside a private module under a public umbrella —
with a defined migration to two such systems standing alone, each behind authentication.

**What is genuinely new in this plan is not a technology. It is an ordering.** Six plans each
sequenced their own feature; none sequenced the seven against each other, and three of the
dependencies between them are hard. Those are stated as migration gates M0 – M6 in the
specification and expanded in *Sequencing* below.

---

## Technical Context

### Agreed across every source plan

**Language and runtime.** Go for the backend, matching the module's own `go.mod`; TypeScript with
Angular standalone components for the front end, matching the reference module; Python 3 and Bash
for the content pipeline and the gate scripts. **No new language and no new runtime is introduced by
any of the seven features** — specification 003 states this explicitly and the others' dependency
lists bear it out.

**Storage.** Files on disk are the source of truth: the passage registry as a sorted, byte-stable,
one-record-per-line file; authored content as JSON and JSONL siblings. SQLite with full-text search
is the **derived** index, never authoritative over the files. Learner progress in the baseline is a
session-keyed store under the index volume.

**Testing.** Go's built-in testing for the backend; Karma and Jasmine for front-end units;
Playwright for end-to-end; Python `unittest` for the pipeline; and Bash three-valued gate scripts,
each owing a **data-driven paired mutation prover**, asserted against the **live binary** rather
than in-process.

**Target platform.** Linux, single machine, containerised with a rootless runtime, served on
loopback. Baseline: local and internal only.

**Project type.** Web service plus single-page application plus content pipeline, inside a PRIVATE
module under a PUBLIC umbrella.

**Constraints, identical in every source plan.** CPU-only inference. No content crosses the
private/public boundary, in either direction. Every gate is three-valued and a could-not-determine
is never a pass. No server-side CI — enforcement is a local pre-push hook. No published history is
rewritten.

### Four technical disagreements between the source plans, and their resolutions

These are plan-level, distinct from the eight specification-level contradictions recorded in
`spec.md` → *Clarifications → merge pass*.

| # | Disagreement | Resolution |
|---|---|---|
| **P1** | **Go version.** Plans 001, 002 and 003 name **Go 1.26.2**, measured from the module's own `go.mod`. Plan 007 names **"Go 1.22+"** for both modules. | **1.26.2 governs as the measured actual**; 007's figure is a *floor*, which 1.26.2 satisfies. No downgrade is implied by the merge, and a plan that names a floor is not evidence that the floor is what is installed. Re-derive from `go.mod` rather than quoting either number. |
| **P2** | **Auth datastore.** The baseline plans state **"no external database — the system is single-machine"** and use SQLite for the derived index. Plan 007 names **PostgreSQL** as a shared auth database across both modules. | **RESOLVED by OQ-9 — operator decision, 2026-09-15.** The store is **genuinely shared: one identity store, its own independently-hosted component**, consumed by both modules over the network — never the `vasic` umbrella's database (FR-295's own standing constraint), and never either module's own store. The signal that carried it was already in the document: FR-296 – FR-299 require the **same two seed identities** on **both** modules with **different** per-module authorization, and two independent stores would mean the same credentials hand-kept in sync across both, doubling the rotation and attack surface for no product benefit. **Accepted cost, stated rather than hidden:** each "standalone" module therefore carries **exactly one external runtime dependency** — this store — in exchange for a single identity across both. **The deferral this cell carried is WITHDRAWN and was correct when written**: it read *"Unresolved by design, and deferred to OQ-9 … This plan does not pick one, because doing so would settle OQ-9 silently."* OQ-9 has since been put to the operator directly and answered, so restating the plan's decision is no longer settling it silently — it is recording what was decided. **The engine is still not named here**, and that is deliberate, not an omission: 007's own Assumptions call PostgreSQL *"a common choice for such systems"*, which is a default, not a measurement, and the resolution fixed the store's **shape and ownership**, not its implementation. |
| **P3** | **Frontend/Angular version.** Plans 002 and 003 name **Angular 19.2**; plan 007 names **"Angular 18+"**; plan 004 names "TypeScript 5.x / Angular" without a version. | Same resolution as P1 — the measured version in the module's own manifest governs, and the "+" forms are floors. Recorded rather than harmonised, because a plan that harmonises unmeasured version strings has invented a fact. |
| **P4** | **Container runtime.** Plan 001 measured **podman present, docker absent** on the development host. Plan 007 names **"Podman/Docker"** via the shared containers module. | Both stand: the *module* supports either runtime through its own auto-detection, and the *host* has one. The requirement is that the runtime is **detected, not assumed** — plan 001 recorded a host-dependent container defect as the reason. Consuming the shared containers module rather than hand-rolling runtime logic is the standing rule. |

### What the source plans measured and recorded as corrected premises — carried forward

Each source plan carries a *"premises checked before they were relied on"* section, and those
corrections are the most reusable part of them. The load-bearing ones:

- **A tool resolving on `PATH` is not evidence the tool is the one you mean.** The development host
  carries a desktop notification client whose name collides with a transcription engine. A capability
  probe testing only for a name will report an engine that is not there while missing the ones that
  are. Probe by invoking, not by locating.
- **The export and OCR toolchain resolves into user-local directories rather than system ones.**
  Plan 002 recorded this as a portability fact the pipeline must **detect** rather than assume.
- **Inference is CPU-only, deliberately.** A GPU fault previously corrupted the index, and the
  repository forces CPU execution as a result.
- **`internal/` is a language-level reuse prohibition, not a style choice.** Plan 002 places every
  reusable package under `pkg/` for that reason, and the decoupling requirements (FR-282) forbid the
  mechanism for anything identified as reusable.
- **Measurements go stale within hours.** Plan/spec 003 recorded its own starting-state table being
  superseded in four rows during the session that produced it.

---

## Architecture — how the parts fit

### The identity spine

Everything hangs off three identity decisions, and they are the reason the seven features compose
rather than collide:

1. **Passages carry minted, persisted identifiers** that are neither positional nor content-derived,
   measured to survive both a content correction and a structural insertion. The passage identifier
   is the **join key for the entire graph** (FR-152); a timestamp is never a join key, because it
   survives neither a re-cut nor a re-transcription.
2. **Areas, terms, lesson sections, questions and mentions inherit that discipline wholesale** —
   there is no reason to invent a weaker scheme for the things that point at passages.
3. **Chapters are the deliberate exception.** A chapter id is a **structural name under an
   operator's control**, not a minted identifier, and hierarchy is derived from it by string
   operation and never stored. Specification 003's D3 records why: a stored `parent_id` is a second
   source of truth about structure, and two facts that can disagree have no symptom until something
   navigates.

### Layering

```
  source material (recordings, notes)         ── split parts + SHA-256 manifest, git-ignored whole
        │
  pipeline (Python + Bash, offline)           ── transcribe · calibrate · mint · extract · author
        │
  passage registry (JSONL, byte-stable)       ── the source of truth
        │                                        one record per line, sorted, one minted id each
        ├──► derived SQLite + FTS index       ── rebuildable; never authoritative
        ├──► taxonomy (areas, terms, mentions)
        ├──► authored content (lessons, materials, question banks, session records)
        └──► cross-reference graph
        │
  Go service (pkg/, never internal/)          ── one resolver, four outcomes; one publication decision
        │                                        route manifest ⇔ interface contract ⇔ live binary
  Angular SPA                                 ── area · practice · progress · study-plan · media views
        │
  three-valued gates (Bash) + paired provers  ── asserted against the LIVE binary, not in-process
```

### The two rules that are architecture rather than implementation

**A process may only assert what its snapshot licenses** (FR-267). The service reads its catalogue
once at start, deliberately. The defect was not the caching — it was answering a determined negative
about on-disk state from a stale snapshot. The remedy is staleness detection returning
could-not-determine, naming what changed.

**The publication decision is computed in exactly one place** (FR-128). The measured cause of the
catalogue/detail disagreement was two implementations that shared their reason strings and differed
in their *sequence of tests*, each passing its own unit tests because nothing asserted the pair.
Sharing a vocabulary of reasons does not satisfy this.

---

## Project Structure

### Documentation for this feature

```
specs/008-unified-workshop-platform/
├── spec.md          the merged dual-state specification (337 FR · 165 SC · 116 edge cases · 33 stories · 15 open questions)
├── plan.md          this file
└── tasks.md         573 remapped tasks, states preserved exactly
```

The seven superseded directories keep every artefact they already carry — `research.md`,
`data-model.md`, `contracts/`, `quickstart.md`, `checklists/`, `analysis.md`, `review.md`,
`decision-record.md`, `progress.yml` and the rendered exports. **This merge deliberately does not
consolidate those**: they are per-feature working material whose value is in the reasoning they
record, and merging them would have produced a second source of truth for design detail that the
source documents already state correctly.

### Source code — baseline (Part I)

```
workshop/                                  PRIVATE
├── chapters/<dotted-id>/                  archived parts + SHA-256 manifest + .verified marker
├── curriculum/
│   ├── passages.jsonl                     the source of truth
│   ├── learning/                          authored areas, lessons, materials, question banks
│   └── chapter-<dotted-id>/knowledge/     per-chapter taxonomy, mentions, session-record inputs
├── pipeline/
│   ├── extract/  mentions/  authoring/    the steps the chapter-addition path GAINS
│   ├── build_transcript.py  calibrate.sh  (no frozen chapter defaults — FR-030 to FR-035)
│   └── engines/  venv/                    ASR engines, project-local
├── platform/
│   ├── backend/pkg/                       knowledge · assessment · sessionrecord · learning ·
│   │                                      curriculum · search · entail  (pkg/, never internal/)
│   ├── backend/cmd/workshop-server/       the route set + route manifest substitution
│   ├── frontend/src/app/                  area · practice · progress · study-plan · media features
│   ├── gates/                             three-valued gates + prove-*.sh mutation provers
│   └── web/                               the staged bundle that is actually SERVED
├── scripts/                               ingest · archive · extract · verify-obtainability
├── docs/                                  limits · QA document · client walkthrough
└── evidence/                              private-side evidence (FR-013)

submodules/curriculum-kit/                 PUBLIC — Catalog → Area → Lesson → Material + Assessment
submodules/passage/                        PUBLIC — identity, minting, four-outcome resolution
submodules/RAG/  submodules/LLMProvider/   PUBLIC — retrieval fusion, model backends
submodules/containers/                     PUBLIC — runtime detection, lifecycle, compose
design-system/                             the token source the served palette must derive from
```

### Source code — target (Part II)

```
Projects/workshop/                         standalone; .gitmodules resolves without the umbrella
├── submodules/<name>/                     the same PUBLIC repositories, mounted at THIS root
├── auth/                                  login surface · module-scoped sessions
└── (everything above, unchanged in shape)

Projects/ai_interviewing/                  standalone
├── submodules/<name>/
├── auth/                                  login surface · module-scoped sessions · RBAC
└── (its own existing structure)

shared identity store                      ONE store, independently hosted, consumed by BOTH
                                           modules over the network — never the umbrella's
                                           database, never either module's own (OQ-9, resolved)
```

The line above previously read `<user store>  independently provisionable — shape is OQ-9`. **That
placeholder is WITHDRAWN**: the shape is decided (see P1 – P4, row **P2**), and the one dependency
each standalone module now carries is named here rather than left as a blank.

**No nested submodules, in either state** (FR-285). Every reusable repository is public, mounted at
a project root, and carries synthetic fixtures only.

---

## Sequencing — the part that is genuinely new

Six source plans each sequenced their own feature. The merge's own contribution is sequencing them
against each other. Three dependencies are hard and are the migration gates in `spec.md` § III.2.

### M0 — the decision that had to come first, and is now made

**OQ-3 is RESOLVED, and M0 is satisfied.** The decision was taken on **2026-09-13** in
[`specs/003-chapter-hierarchy/decision-record.md`](../003-chapter-hierarchy/decision-record.md) —
*before this merge began* — and was confirmed and documented here on **2026-09-15**: keep
`Chapter.ordinal` typed as `int`, **unchanged** (zero-diff); add **`ordinal_path` (`[]int`)** as the
canonical, collision-free ordering key that anything depth-sensitive must use instead; and the
**dotted chapter id is the single path key**, which closes the "not accepted as a path key"
contradiction outright. Both implied amendments were already applied to `001`'s `data-model.md` and
`contracts/http-api.md`. See `spec.md` → *Clarifications → "OQ-3 resolved during this pass"* for the
full evidence, including the one residual gap it does **not** claim to resolve — the live wire
comment scoping the transitional both-fields state to *"one release"* with no version or date named
anywhere, which is a distinct gap carried on task T184, not a reopening of OQ-3.

**The claim this section carried is WITHDRAWN, and it was written in good faith on the evidence then
in hand.** It read, verbatim: *"**OQ-3 must be settled first.** Every ordinal collision — the parent
and child returning the same integer, two chapters rendering the same title, the front end's two
shapes disagreeing — follows from one line typing `Chapter.ordinal` as an integer, plus a contract
that says the zero-padded ordinal is not accepted as a path key while the implementation uses
exactly that as the path key. **No amount of implementation work resolves either.** Ten `[BLOCKED]`
markers in `tasks.md` wait on it."* Its **diagnosis** survives intact — those collisions do follow
from that typing, and the decision-record itself concedes *"the zero-diff option is the only one
that makes the defect permanent"*, because `ordinalOf` still returns the same int for `02` and
`02.01`. What is withdrawn is the **status**: this merge drafted OQ-3 as BLOCKING from `003`'s own
stale pre-decision text, having not yet read the decision-record that settles it. Drafting a blocker
from a source document that a later artifact had already superseded was this merge's own error, and
it is recorded rather than quietly repaired.

**The figure "ten" is separately WITHDRAWN AS WRONG BY MEASUREMENT — it is three.** Counted directly
against the seven source `tasks.md` files, exactly **three** `[BLOCKED: ordinal type]` markers ever
existed — **T176, T177 and T184, all originating from source spec `003`** — and none elsewhere.
`tasks.md`'s own execution-marker legend already carries this correction. With OQ-3 resolved, all
three are **cleared**; each task's own note states what that leaves of its remaining work, which is
unwritten work rather than blocked work.

### M1 — obtainability, before decoupling can mean anything

A standalone module whose value proposition is *"clonable by someone with no umbrella access"*
cannot ship while cloning it is the thing that fails. Obtainability serves both states and is
sequenced before the migration rather than beside it.

### M2 — manual-QA readiness, against a stated build

The operator's absolute priority, and the only point at which a second party can check that the
capabilities Part II is about to move actually work. **Which build the QA document is written
against is OQ-15** — FR-209 requires the document to record its build identifier and be
*regenerated, not patched*, when that build moves, and decoupling moves it in the largest possible
way.

### M3 – M6 — extraction, verification, authentication, cutover

Extraction completes before the umbrella copy stops being operative (M3). Each standalone clone
independently passes install and the full test suite (M4, FR-328) — and **until M4 passes, the
umbrella copy remains the operative one**. Authentication, RBAC, module-scoped sessions and
user-bound progress go live (M5). Only then the cutover (M6): pre-rollout sessions invalidated,
anonymous per-browser progress handled by a stated outcome (FR-321), umbrella copies decommissioned.
M6 is the only irreversible step in the plan.

### Within-phase ordering: test-first, and the shape the tests must have

Every source plan states a TDD requirement; the load-bearing detail is **what the test must be
shaped like**, not that one exists:

- **A one-scope fixture cannot guard the chapter-scope equality rule.** SC-013 exists to measure the
  test's own blindness: the same mutation applied to a single-scope fixture must stay **green**. A
  test that cannot fail is not coverage.
- **Every pattern widening owes two mutations, not one** (FR-028, SC-010): the dotted form now
  matches, **and** the previously-matching flat form still matches. A widening that quietly stopped
  matching the old form would be worse than the defect it fixed.
- **A paired prover works by supplying different data, never by editing the gate** (FR-260). A
  prover that mutates its own gate proves nothing about the gate that ships.
- **A gate asserted in-process is not evidence about the served product** (FR-266). Gates run
  against the live binary.

### Parallel opportunities

Phases 3, 5 and 6 are largely independent of each other once Phase 2 completes: obtainability and
red-state work touches repository plumbing, hierarchy work touches identity and derivation, and the
transcript work touches the pipeline. Phase 4's QA document depends on the platform being reachable
but not on Phases 5–14 being finished — which is exactly why OQ-15 matters. Phase 16 is independent
of Phases 3–15 in its *setup* half and dependent on all of them in its *cutover* half.

Tasks marked `[P]` within a phase touch different files and carry no intra-phase dependency; **106**
of the 573 tasks carry that marker. **The figure "107" this sentence carried is WITHDRAWN as wrong
by measurement**, and the counting rule is stated so the discrepancy is reproducible rather than
arbitrated: a naive `grep -c '\[P\]' tasks.md` returns **108**, of which two occurrences are not
task lines — the execution-marker **legend** entry defining `[P]`, and one inside task **T376**'s
evidence prose. Counting only lines that begin a task (`^- [ ] T<n>` or `^- [x] T<n>`) and carrying
the marker gives **106**, and the distinct task ids among them also number **106**, so no task is
double-counted. Re-derive rather than quoting this figure:

```bash
grep -cE '^- \[[ x]\] T[0-9]+ .*\[P\]' tasks.md   # 106 — task lines only
grep -c '\[P\]' tasks.md                          # 108 — includes the legend and T376's prose
```

---

## Human checkpoints and review gates

Carried from all six source plans, deduplicated:

| Checkpoint | Why a human, not a check |
|---|---|
| **Topical judgement per area** (FR-070, OQ-6) | Whether matched evidence is genuinely *about* a subject is the one judgement the publication reviews explicitly decline to make. An automated classifier inherits a measured blind spot — it cannot see areas whose titles carry no jargon. |
| **Publication review per area** (FR-090) | Recording *"nothing to change"* is a valid review; skipping it is not. |
| **Coverage verdicts on session plans** (FR-200) | A machine may **propose** with per-point evidence and confidence, marked PROPOSED. The served figure does not move until a human confirms. Matching one heuristic extraction against another is a guess wearing a decision's clothes. |
| **The meeting-notes withholding rule** (FR-197, OQ-8) | A content judgement the source specification's own text says *"may not be guessed."* Until settled, the route defaults to **withheld** (FR-279). |
| **Every gitlink pin move** (FR-326, C8) | The check reports and proposes; the move is an operator decision. |
| ~~**The `ordinal` type and the path key** (OQ-3)~~ — **DISCHARGED** | **WITHDRAWN as a pending checkpoint.** It read *"Both recorded in specification 001's own artifacts, both contradicted today, and nothing downstream is implementable until they are amended explicitly."* The human decision this row asked for **was taken**, on 2026-09-13 in `specs/003-chapter-hierarchy/decision-record.md`, and both amendments were applied to `001`'s artifacts before this merge began. The row is kept, struck, for traceability — M0 above states the decision. |
| **Repository visibility for the `workshop` standalone module** (OQ-14) | A disclosure decision about real private material — a recording of a private teaching session with an identifiable third party — and additionally blocked on **OQ-1**, the still-open third-party consent question. **Narrowed 2026-09-15**: this row previously read *"for both standalone modules (OQ-7, OQ-14)"*. **OQ-7 is RESOLVED** — the operator chose that **`ai_interviewing` stays PRIVATE**, with invited/credentialed collaborator access; FR-288's *"no access to the `vasic` umbrella repository"* is satisfied by a credential to the standalone repository itself, which is not umbrella access. **The two are not one decision and must not be conflated**: different repositories, different content, and OQ-7's answer implies nothing about OQ-14. |
| **Credential rotation** (OQ-13) | Two passwords are permanently in a public repository's history. This plan resolves only the safe default — treat as compromised, hash everything, never re-print. |

---

## Complexity tracking — what this merge did not simplify, and why

- **Two architectures, specified to equal depth.** A simpler document would have relegated the
  decoupling to a footnote. That would have understated a decided direction with 55 requirements of
  its own, eight user stories and six open questions, and it would have hidden the fact that the
  baseline and the target have **opposite** answers on access, progress durability and repository
  location.
- **337 requirements, not a tidied subset.** Every source requirement is carried with a
  back-reference. The alternative — pruning to a "clean" set — is exactly the failure mode SC-162
  exists to catch, and it caught three dropped success criteria during this merge's own
  verification (SC-163 – SC-165).
- **Withdrawn claims, corrected figures and refuted hypotheses carried through rather than tidied
  away.** A merged document keeping only the corrected numbers would have discarded the most useful
  thing the seven specifications produced: a record of how each wrong reading was caught.
- **573 tasks remapped rather than re-triaged.** A `[x]` here means *"marked complete in its source
  file"* — not a claim by this merge that the work is verified today. Re-verifying 344 completion
  claims is separate work with its own evidence obligation, and conflating the two would have been
  the first unearned claim in this document.

---

## Phase status

| Phase | State |
|---|---|
| Specification merge | **Complete** — `spec.md` |
| Task remap | **Complete** — `tasks.md`, 573 of 573, states preserved and verified |
| Plan | **Complete** — this document |
| Implementation | **Not started by this merge.** No code, no build, no git operation was performed. 344 of 573 tasks were already marked complete in their source files before it. |
| M0 (OQ-3) | **Satisfied** — OQ-3 resolved. Decided 2026-09-13 in `specs/003-chapter-hierarchy/decision-record.md`; confirmed and documented in this merge 2026-09-15. `ordinal` stays `int` unchanged, `ordinal_path` is the canonical ordering key, the dotted id is the path key. The **"Open — blocking"** this row carried is **WITHDRAWN** — it was drafted from `003`'s stale pre-decision text, not from the decision-record that supersedes it. One residual gap is carried on task T184 and is *not* OQ-3: no artifact names a version or date for retiring the transitional both-fields wire state. |
