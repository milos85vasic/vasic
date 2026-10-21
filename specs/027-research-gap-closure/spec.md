# Feature Specification: Research Gap Closure (research requirements that had no implementing task)

**Feature Branch**: `027-research-gap-closure` (no git branch created; authored directly into `specs/027-research-gap-closure/`, the same simplification specs 015 and 026 record)

**Created**: 2026-10-21

**Status**: Draft (specification only; nothing here has been built; independent review §11.4.142 PENDING)

**Input**: Operator brief of 2026-10-21: a spec that covers every requirement in `workshop/docs/research/**` that no spec task implements. The input audits are the session scratch file `completion-backlog-B-specs-018-026.md` (section 3 and the per-part "research requirements" sections) and `research-traceability-2026-10-21.md` (section 3). Both are session scratch files, not committed: every fact this spec relies on is restated with `file:line` in `research.md`, so this spec does not depend on them.

**Builds on / cross-references (never duplicates)**: `012` (FR-018, FR-019, FR-020, SC-009), `013` (US3 crowd recalibration T037-T044, `pkg/scoring`), `015` (location anchors), `018`, `020`, `021` (US1-US5, OD-1..OD-5), `022` (corpus-only, OD-2), `024` (benchmark v2 FR-012, residency T072-T078, claim ledger T100), `025` (P1-P16 table, T006), `026` (O-1..O-8). Spec `023` is being authored by another stream and is neither read as a dependency nor edited here.

**Content boundary**: public repository. Paths, counts and line numbers only; no chapter, transcript or textbook text; no credential value; no client name beyond what specs 021/022/024 already carry.

## Why this exists

The 2026-10-21 audits found research requirements that no task in any spec implements. Some are real build work (OCR for scanned PDFs, the policy and operator report around an adaptive-assessment gaming detector that spec 013 now builds), some are tooling decisions that were never taken (the 23-item skills-and-plugins shortlist and its nine "gaps with no solution"), some are blocked on facts only the operator or the client has (the Jordan client's section 6 unknowns), and some turned out, when read against the code, to be already covered (ux-research P2 has 025 tasks T031-T041; the accessibility items U32/U35 have 025 T006; the textbook-id-versus-chapter-list rule has 012 T021 and `pkg/curriculum/textbook_scope_test.go`). A research document with no owner is a claim nobody checks, so this feature gives each requirement exactly one disposition: **BUILD**, **ADOPT**, **ADVISORY-ONLY** (with the reason), **REJECT**, **BUILT-ALREADY** (with the evidence), **CROSS-REFERENCE** (an existing task owns it), or **NEEDS-OPERATOR** (an explicit clarification entry with a recommended default, not a guess).

The full row-by-row register is [`contracts/requirement-register.md`](./contracts/requirement-register.md) (RG-01..RG-48). The 33-row tooling decision table is [`contracts/tooling-decisions.md`](./contracts/tooling-decisions.md). This file holds the stories, the requirements and the success criteria they roll up into.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - No research requirement is silently ownerless (Priority: P1)

An operator or reviewer opens one register and, for any requirement in `workshop/docs/research/**`, finds its disposition, the FR/SC that carries it, how it is tested and where an end user (or, for operator-only items, the operator) sees the result. A mechanical check fails when a row loses its disposition.

**Why this priority**: every other story in this spec exists because this was missing; without the check the next audit repeats this one.

**Independent Test**: delete the `Decision` cell of any register row in a throwaway copy; the check exits 1 naming the row. Corrupt the file so it cannot be parsed; the check exits 2 (never 0).

**Acceptance Scenarios**:

1. **Given** the register, **When** the check runs, **Then** every RG row has exactly one disposition from the closed vocabulary and, unless the disposition is ADVISORY-ONLY/REJECT/BUILT-ALREADY, at least one FR and one SC id that exist in this spec or in the cross-referenced spec.
2. **Given** a CROSS-REFERENCE row, **When** the check runs, **Then** the named task id exists in the named `tasks.md` (so a task renumbering cannot orphan the row).
3. **Given** the tooling table, **When** it is diffed against the research ranked table (#1-#23, #5b) and section 9 (9.1-9.9), **Then** zero research rows are missing.

---

### User Story 2 - A repeat attempt has a stated policy and an operator report, and the 2PL shadow fit has a reader (Priority: P1)

Spec 013 now builds the repeat-attempt / rapid-guess detector (T050), the integrity reading on submit and progress (T051), the Progress-page neutral note (T053) and the shadow-only 2PL fit with its seeded recovery test (T052) on branch `n1-013-adaptive`. This feature does NOT build a second detector or fit. It adds only what that branch lacks, verified by reading its code: (a) the repeat-attempt policy, so an operator can choose that a repeat never raises the score (NEEDS-OPERATOR NO-5; `gaming.go` documents that it deliberately does not discount the ability update); (b) an admin-only report of repeat counts per session and per question; (c) a read-only operator export of the fitted item parameters and a recorded recovery run against the operator's tolerance (NO-4), because `item_irt` has no reader outside `pkg/scoring`.

**Why this priority**: the research names the inflation risk (`adaptive-assessment-and-scoring.md:692-700`); 013 detects and reports it, but nothing yet lets the operator decide what a repeat is worth.

**Independent Test**: with policy `no-upward-change` a repeated submit leaves the area ability unchanged or lower; with `record-only` the response bytes equal today's. With the shadow fit on or off and `IRTApply` false, every served byte of a fixed script is identical.

**Acceptance Scenarios**:

1. **Given** policy `no-upward-change` and a session that submits question Q twice, **When** the second submit is scored, **Then** the log has two rows, the ability change is not upward, and the existing `scoring.integrity` object says so neutrally.
2. **Given** a serving-token replay, **When** it is submitted, **Then** behaviour is exactly 013's replay behaviour.
3. **Given** the shadow fit and a log below the operator's thresholds, **When** the export runs, **Then** it reports "insufficient data" per item and writes nothing a learner can read.

---

### User Story 3 - A scanned textbook is either refused with a reason or read with a visible fidelity warning (Priority: P1)

An operator adds a scanned (image-only) PDF. Today it is refused (`pipeline/pdf_textbook_sections.py:222-223`). After this feature, and only if the operator has opted that book in (NEEDS-OPERATOR NO-1: OCR against the standing token rule OR-04), it is read with a local, deterministic OCR engine and every section is marked OCR-derived; pages that contain tables carry a notice that column alignment may be wrong. The library page the learner reads shows both marks.

**Why this priority**: spec 012 states the requirement (FR-018 second half, FR-019, SC-009) but its tasks defer it explicitly (`012 tasks.md:253`); no spec owns the task-level work.

**Independent Test**: a fixture scanned PDF (generated at test time from a text fixture) is refused with exit 2 before opt-in and yields sections whose text equals the fixture after opt-in, each section carrying the OCR marker; a fixture with a table region is reported in the extraction report.

**Acceptance Scenarios**:

1. **Given** no opt-in, **When** a scanned PDF is ingested, **Then** it is refused with the existing "no text layer" reason and no model/OCR process starts.
2. **Given** the opt-in and the installed `eng` pack, **When** a scanned English PDF is ingested, **Then** sections are minted `textbook_section` with an OCR marker and per-page confidence summary in the report.
3. **Given** a scanned PDF whose language pack is not installed (only `eng` and `osd` are, measured 2026-10-21), **When** ingestion is attempted, **Then** it is refused naming the missing pack, never degraded to the wrong language.

---

### User Story 4 - A textbook's table of contents becomes a reviewable draft outline, never an unreviewed curriculum (Priority: P2)

REQ-2 asks for textbooks as a primary source that produces areas, lessons and questions. An author opens a draft outline derived deterministically from a book's table of contents (no model), edits it, and accepts or rejects each node; only accepted nodes enter the existing authoring path. Question drafting by a model over textbook text is not built unless the operator carves an exception to OR-04 (NO-2).

**Independent Test**: the draft generator run twice on the same catalogue yields byte-identical files; a guard test proves zero model/network calls; nothing is written to the registry or to `curriculum/learning/` by the generator.

**Acceptance Scenarios**:

1. **Given** a book with a table of contents, **When** drafts are generated, **Then** one draft node exists per TOC node, each citing its section pids.
2. **Given** an unaccepted draft, **When** a learner browses areas, **Then** it is invisible.

---

### User Story 5 - Per-participant format signals are shown only when the evidence supports them (Priority: P2)

REQ-1 asks which question kind AND which content format a participant does best with. 021 delivers question kinds and keeps formats engagement-only (`021 spec.md:194-197`). This story adds a format performance view that is displayed only when the same evidence discipline as 021 passes (deterministic, own data only, "insufficient evidence" is a first-class state), uses consented engagement events as exposure (021 US4), and is silent otherwise.

**Independent Test**: simulation with no true format effect: false "leaning" rate bounded by the 021 SC-009 null criterion; golden fixture reproduces byte-identically.

---

### User Story 6 - The quality instruments the research asks for exist as 0/1/2 gates (Priority: P2)

An operator runs gates for: quiz-bank validity, transcription WER/CER, retrieval MRR/nDCG/recall, and design-token usage. Each exits 0 (good), 1 (a real finding) or 2 (could not determine, never a pass), each with a paired mutation proof (§1.1).

**Independent Test**: each gate's `--prove-failure` seeds its violation and requires rc 1, and seeds a broken environment and requires rc 2.

---

### User Story 7 - Every research caveat about honest answering is measured, not assumed (Priority: P2)

The answer gate (024) is also measured on an out-of-corpus unanswerable stratum, and the entailment judge's short-versus-long claim behaviour is recorded, because the research says in-corpus unanswerable rows alone cannot show how abstention behaves under domain shift (`retrieval-and-grounding.md:116-138`).

**Independent Test**: the benchmark v2 reports recall and fabrication per stratum; a stratum with fewer trials than the 024 minimum is reported "insufficient", never folded into the pooled figure.

---

### User Story 8 - Items that need facts only the operator or client has are visible as questions, with a default (Priority: P1)

Every item blocked on a fact nobody in the repository holds (the client's section 6 unknowns, retention policy, whether OCR counts as a "vision pass", licence choices) appears as a numbered NEEDS-OPERATOR entry with a recommended default and what stays blocked until it is answered. No FR in this spec quietly assumes an answer.

**Independent Test**: the register check (US1) fails when a row is marked "blocked" without a NO-id that exists in the NEEDS-OPERATOR table.

## Edge Cases

- **A research claim contradicts the code.** The code wins and the register row records the correction (e.g. research §9.1 says no tool pairs a gate with a mutation proof; `scripts/verify-check-registry.sh:1-40` and the `check-registry-*.tsv` registries do exactly that in this repository: BUILT-ALREADY).
- **A requirement is already carried by an unticked task.** It is CROSS-REFERENCE, not re-specified: unticked is not the same as unowned (ux-research P2: `025 tasks.md:83-93`).
- **An operator-blocked item has a recommended default.** The default is a recommendation recorded in the NEEDS-OPERATOR table; no task may build against it until the entry is marked answered.
- **A gate cannot read its input** (settings file absent, registry unreadable): exit 2, never 0 (§11.4 anti-bluff).
- **A research document is edited later.** The register check re-reads the research tables; a new unregistered row is a failure (anti-drift, mirrors `verify-check-registry.sh` R5).
- **Standing token rule.** OR-04 (`docs/OPERATOR-DECISIONS-2026-10-20.md:51`) bars any model pass over recordings, transcripts and textbooks, and D-06 (`docs/OPERATOR-DECISIONS-2026-10-21.md:52`) says it still does. Every BUILD row that touches those corpora is deterministic and carries a zero-model guard test, or it is a NEEDS-OPERATOR entry.

## Requirements *(mandatory)*

### Functional Requirements

**Traceability and tooling (RG-01..RG-12)**

- **FR-001**: The repository MUST carry a tooling decision register `docs/tooling/TOOLING-REGISTER.md` (seeded from `contracts/tooling-decisions.md`) with one row per research ranked item #1-#23 and #5b and per section 9 gap 9.1-9.9, each with exactly one disposition from {BUILD, ADOPT, ADVISORY-ONLY, REJECT, BUILT-ALREADY, NEEDS-OPERATOR} and a reason that cites a measurement or a research section.
- **FR-002**: A read-only check `scripts/verify-research-register.sh` (three-valued, with `--prove-failure`, registered in `scripts/check-registry.tsv`) MUST verify (a) every RG row of `contracts/requirement-register.md` has one disposition and the ids it names exist, (b) every tooling row has a disposition, (c) the research ranked table and section 9 headings contain no row absent from the register, (d) every NEEDS-OPERATOR reference resolves to an entry. Unreadable inputs MUST yield exit 2.
- **FR-003**: A read-only drift report MUST compare the register's REJECT/ADVISORY-ONLY rows with the plugins enabled in the Claude config directory named by `$CLAUDE_CONFIG_DIR` (or reported as not set, exit 2), printing plugin names only and never any other settings value. Divergence is reported, not remediated (changing enabled plugins is an operator action).
- **FR-004**: Any third-party gate adopted in future MUST be wrapped so its failures map to exit 1 and its inability to run maps to exit 2 (research §9.3: every third-party gate surveyed is binary). The wrapper MUST have a paired proof that a missing tool yields 2.
- **FR-005**: Disposition of the section 9 gaps is fixed by this spec: 9.1 paired-mutation, 9.2 contract testing and 9.3 three-valued semantics are BUILT-ALREADY (evidence in the register); 9.4 quiz-bank validation, 9.5 transcription QA, 9.6 WebVTT export, 9.7 retrieval metrics and 9.8 design-token usage are BUILD (FR-020..FR-029); 9.9 prose/spell lint is BUILD limited to user-facing documentation (FR-030).

**Adaptive assessment (RG-13..RG-15)**

- **FR-006**: Repeat-attempt detection is CROSS-REFERENCED, not specified here: `013 tasks.md` T050 (detector), T051 (integrity reading) and T053 (Progress note) own it. This feature MUST NOT add a second detector. The register check (FR-002) MUST fail if those task ids disappear from `013 tasks.md`.
- **FR-007**: The repeat-attempt policy MUST be one configurable value with the values `record-only` and `no-upward-change`, beside 013's other scoring configuration; the default MUST be the one the operator selects at NO-5 (until then `record-only`, the behaviour that changes nothing a learner sees). Under `no-upward-change` a repeat MUST be logged, MUST NOT raise the ability score, MAY lower it exactly as a first attempt would, and MUST be disclosed through the existing `scoring.integrity` object with neutral wording that does not accuse.
- **FR-008**: An operator-facing report MUST list repeat-attempt counts per session and per question with no learner identity beyond the existing session id, and MUST be admin-only like 024 FR-006 (absent from `n1-013-adaptive`: its reading is per-session on GET /api/progress).
- **FR-009**: The per-item 2PL fit is CROSS-REFERENCED to `013 tasks.md` T052 (shadow-only unless `Config.IRTApply`). This feature adds only a read-only operator export of the fitted parameters (a, b, response count, convergence flag per item) and a shadow invariant: with `IRTApply` false, no served score, item selection or response byte changes. Promotion into serving is OUT of this feature until NO-4 sets the thresholds.
- **FR-010**: A fixed-seed parameter-recovery run MUST be recorded against the operator's tolerance and minimum-response thresholds (NO-4, operator inputs, not values asserted here) before any promotion decision. 013's own seeded recovery unit test is the mechanism; this requirement adds only the recorded evidence.

**Document ingestion (RG-16..RG-23)**

- **FR-011**: A scanned/image-only PDF MUST continue to be refused with an explicit reason unless the operator has opted that book in (NO-1). With the opt-in, extraction MUST use a local deterministic OCR engine only (no model service, no network), MUST refuse a language whose pack is not installed, and MUST mark every resulting section OCR-derived (012 FR-018 second half, FR-019).
- **FR-012**: OCR-derived provenance MUST survive to the reader: the textbook library page (spec 020) and a search hit on such a section MUST show a fidelity notice. The marker is a location-metadata attribute, never inside the license record (026 FR-004).
- **FR-013**: Extractors MUST report table regions they detect (page, reason) in the extraction report, and a section containing one MUST carry a notice that column alignment may be wrong. Structured table extraction is ADVISORY-ONLY: the research records layout-mode text as sometimes worse than no attempt (`document-ingestion-architecture.md:380-404`) and this feature does not claim to fix it.
- **FR-014**: The research-document re-ingest path (spec 018) MUST self-report extraction failures (unreadable or empty sources, undecodable bytes) in its report beyond redaction counts, so a bare success count is never the only output (`document-ingestion-architecture.md:799-818`).
- **FR-015**: Citation resolution for textbook passages (spec 020's pid-to-catalogue path) and the location-anchor model (spec 015) MUST agree: for any textbook pid both produce the same reader href. A contract test MUST pin it.
- **FR-016**: A draft-outline generator MUST derive, deterministically and without any model, one draft node per table-of-contents node of a catalogued book, each citing its section pids, into a review-queue file outside the registry and outside `curriculum/learning/`. Accepting a node is a human action through the existing authoring path; 012 FR-020 (no automatic promotion) is preserved.
- **FR-017**: Model-assisted question drafting from textbook text is NOT built by this feature (OR-04, D-06) unless NO-2 is answered otherwise. Until then no FR may call a model over textbook text.
- **FR-018**: Citation affordances: the peek target contract of spec 025 (US7, FR-016) MUST list spec 020 textbook citations and spec 018 library links as eligible targets, with a test per target kind. (Owner of the component stays 025.)

**Client requirements (RG-30..RG-36)**

- **FR-019**: REQ-1 format signal: a content-format performance view MUST exist only as an evidence-gated extension of 021: exposure is the learner's consented engagement events (021 US4) preceding a machine-graded attempt on the same area in the same session; states are 021's closed set; insufficient evidence MUST be shown as insufficient, never as a preference; the inference MUST be deterministic and own-data only (021 FR-002, FR-008).
- REQ-3 (per-client generation), REQ-4 (routing), REQ-5 (client-facing comparison) and REQ-6 (residency copy) are dispositioned in the register as NEEDS-OPERATOR/CROSS-REFERENCE (NO-8, NO-13, NO-14, NO-9); no FR builds against an unanswered entry.

**Quality gates (RG-24..RG-29, RG-37..RG-42)**

- **FR-020**: `verify-quiz-bank` MUST check, deterministically: every knowledge area has at least one assessment item (the server already logs "2 areas have no assessment" at boot, CK021), every item's cited passage resolves in the registry, the answer key resolves to exactly one option, no two options are identical after normalisation, and coverage per area is reported. It MUST disclose that lexical citation-overlap is a necessary, not sufficient, condition (the house wording, `retrieval-and-grounding.md:100-103`).
- **FR-021**: The quiz-bank gate MUST report a readability figure per item computed by a deterministic in-repo or dependency-verdicted routine (§11.4.270); a judgement from an LLM or prose skill MUST NOT be a PASS input (research §9.4).
- **FR-022**: A transcription-quality gate MUST compute WER and CER between the two installed engines' outputs using the existing word alignment (`pipeline/compare_engines.py:111`, `:165`) plus a character-level alignment, and exit 0/1/2 against a threshold that is recorded data from a measured baseline, not asserted.
- **FR-023**: Where a human reference transcript exists, the gate MUST also report weighted/error-class WER and a retrieval correlate; absent a reference the figures are reported UNDETERMINED (exit 2 for that check), never zero (NO-6).
- **FR-024**: The two-engine disagreement MUST be usable to rank windows for human review (research `asr-transcription-and-provenance.md:61-72`): a deterministic ranked list with the disagreement score per window.
- **FR-025**: A seek-error measurement MUST exist for the word-timing boundary artifact (`asr...:46-60`) against SC-003's 5-second criterion, computed from the existing word-timing sidecar and a reference set (NO-6); without a reference it is UNDETERMINED.
- **FR-026**: Speaker attribution (DER) is measured only against an operator-supplied human reference (NO-6); until supplied the check is UNDETERMINED and the report says "no DER claim".
- **FR-027**: The retrieval benchmark MUST report MRR, nDCG@k and recall@k in addition to top-1/top-5 (`pipeline/benchmark/run_retrieval_benchmark.py:149`, `:245-267` report top-1/top-5 only), deterministically, with exit 0/1/2, no LLM judge.
- **FR-028**: A design-token usage gate MUST fail when a component stylesheet or template carries a literal colour or spacing value that is not a declared token, and MUST be paired with the existing contrast gate (`platform/gates/verify-served-contrast.sh`).
- **FR-029**: A WebVTT export MUST be generated deterministically from the existing transcript segment sidecar (no media re-processing, no model) and attached to the recording player as a captions track, with the cue count equal to the segment count. Chapter detection from silence is ADVISORY-ONLY (ux P16 is DEFERRED by 025 pending a generative-titling decision).
- **FR-030**: A spelling/prose check MUST cover the user-facing documents only (user manual, FAQ, quickstart), as an advisory three-valued gate; it MUST NOT gate the research or specification corpora.
- **FR-031**: The 024 benchmark v2 MUST include an out-of-corpus unanswerable stratum reported separately; a stratum below the 024 minimum trials MUST be reported "insufficient" and MUST NOT be pooled (D-05: at least 60 trials for recall, at least 189 for fabrication, `docs/OPERATOR-DECISIONS-2026-10-21.md:51`).
- **FR-032**: The entailment judge's behaviour on short versus long claims MUST be recorded as a stratified measurement in the gate evidence (research §5, granularity); atomic claim decomposition is ADVISORY-ONLY because it needs a model over the answer (NO-15).
- **FR-033**: Property-based tests MUST be added for the scoring invariants (clamp to [0,10], order-independence of the audit link, idempotent replay) and the three-state answer contract, with the library chosen under a §11.4.270 dependency verdict; installing the Trail of Bits skill itself is NEEDS-OPERATOR (NO-10, licence).

**Reference prototypes (RG-43..RG-44)**

- **FR-034**: Each file under `workshop/docs/research/education-platform/poc/` MUST have a recorded supersession mapping to its real counterpart and a parity result: the seed-42 adaptive trace against `pkg/scoring` is already 013 T045; the EPUB sample through `pipeline/epub_sections.py` and the toast component are new checks.

**Residue from specs 005-009 research (RG-45..RG-47)**

- **FR-035**: Late-redaction propagation (research `asr...:108-117`) MUST be proven for rows of notes-PDF origin: a redaction applied after minting reaches every derived `kg_*` row (test). Backlog Part E sub4 R2/R4/R5 are re-verified first (UNCONFIRMED against code) and either closed as covered or added as tasks.

**NEEDS-OPERATOR handling**

- **FR-036**: Each NEEDS-OPERATOR entry (table below) MUST be answered by the operator in `docs/OPERATOR-DECISIONS-<date>.md` form before any task tagged with its NO-id may start; the register check (FR-002) enforces that a blocked row names a live entry.

### Key Entities

- **Register row (RG)**: research source, gap statement, disposition, FR ids, SC ids, acceptance-test shape, end-user reachability, owner/state.
- **Disposition**: one of BUILD, ADOPT, ADVISORY-ONLY, REJECT, BUILT-ALREADY, CROSS-REFERENCE, NEEDS-OPERATOR.
- **Repeat attempt**: a scored submission of question Q by session S after an earlier scored submission of (S, Q) that is not a token replay.
- **Draft outline node**: a reviewable TOC-derived node; never a registry row.

## NEEDS-OPERATOR clarifications (recommended defaults; none is a decision)

| ID | Question | Why it is not decidable from the repository | Recommended default | Blocked until answered |
|---|---|---|---|---|
| NO-1 | Is a local classical OCR pass (tesseract) over a scanned textbook a "vision pass" forbidden by OR-04? | OR-04 text names "vision" without defining it (`OPERATOR-DECISIONS-2026-10-20.md:51`); D-EMB set a precedent for allowing local embedding (`:125`) | Allowed only per book, by explicit opt-in, local only, disclosed; default OFF. Installed packs: `eng`, `osd` only | tasks T032-T034 (the OCR path); T030, T031 and the refusal path are not blocked |
| NO-1b | Does the spec 008 OCR chain over video frames (screen text, T449-T465) conflict with OR-04? | backlog Part E addendum A5 records the conflict as needing an operator ruling | Keep unbuilt; it processes recordings, which OR-04 names | spec 008 T449-T465 (not this spec) |
| NO-2 | May a model draft questions from textbook text under an OR-04 exception? | D-06 says OR-04 still bars any model over textbooks | No. Deterministic TOC drafts only (FR-016) | any question-drafting task |
| NO-3 | 012 FR-020 options: never promote / draft-then-accept / new kind | `document-ingestion-architecture.md:836-866` leaves it open | Draft-then-accept (FR-016): nothing minted without a human accept; no new Kind | task T040 (the accept path) |
| NO-4 | IRT shadow fit: minimum responses per item, recovery tolerance, and the promotion rule | no response volume exists to calibrate on; research §8 says premature at launch | Shadow-only forever until the operator sets numbers | any promotion task |
| NO-5 | Repeat-attempt policy: `record-only` or `no-upward-change` | changes what a learner experiences | `no-upward-change`, disclosed (013 research: never default toward the learner-favourable direction) | switching the default; the detector and report build regardless |
| NO-6 | Who produces human-reference labels (WER strata, DER, seek error) and how many? | requires human listening; the existing human checkpoint, spec 008 T207 (`specs/008-unified-workshop-platform/tasks.md:917`) | None assumed: gates report UNDETERMINED (2) | FR-023, FR-025, FR-026 reference-dependent checks |
| NO-7 | REQ-1 exposure window | no data on how learners study | Same area, same session, event precedes the attempt; no time constant | FR-019 tuning only |
| NO-8 | What does REQ-3 "client" mean (tenant, audience profile, nothing)? | client identity UNCONFIRMED (`clients/jordan/...:441-460`) | An "audience brief": a saved topic list feeding spec 022; no tenant separation, no new identity | any per-client generation task (none exists) |
| NO-9 | Residency/deployment-locality copy for the Jordan client; legal review | 024 T078 forbids agents drafting it; the statute applicability is UNCONFIRMED | Ship the absent state (024 T072-T074 already do) | 024 T078 |
| NO-10 | Licence and trust: CC BY-SA skill packs (`trailofbits/skills`, `education-agent-skills`), adding third-party marketplaces, updating `superpowers` | trust/licence choices are the operator's | Adopt nothing new; ADOPT only items already enabled | tooling rows marked ADOPT-pending |
| NO-11 | 021 OD-4: retention versus erasure of the append-only response log | legal regime UNCONFIRMED | State plainly in the manual that erasure covers 021's own rows only (021 FR-012) | any erasure promise |
| NO-12 | 021 OD-5: instructor visibility of participant signals | needs spec 023 roles and a consent model | None; own-data only | any instructor view |
| NO-13 | 021 OD-2: may an inferred preference influence server serving (REQ-4 routing)? | changes learner experience | No (021's own default); kind-easing O-4 (013 T036b) proceeds separately | 021 T048a |
| NO-14 | Who authors the client-facing trust comparison (REQ-5)? | sales material, not product | Operator-authored; ADVISORY-ONLY here; in-product claims live in the 024 ledger (T100) | nothing in-product |
| NO-15 | Acquire ONNX NLI weights, enable batching, or add an embedding-based support floor (008 T351, T073)? | downloads model weights (egress, licence) | No new weights; keep the lexical floor plus the existing judge | any weights task |
| NO-16 | Who labels the out-of-corpus unanswerable rows? | 024 FR-012 requires a labeller other than the pipeline tuner | Someone other than the tuner; count not below the D-05 trial minimum | FR-031 stratum population |
| NO-J1 | Jordan doc §6.1: is there a trailing clause or a point (d) in feedback point 1(c)? | not in any repository file | Treat 1(c) as complete as quoted; no new requirement | any spec change from 1(c) |
| NO-J2 | §6.2: how does the Valaeon fragment ("a platform that...") continue? | the source is cut off | Keep REQ-5 scoped as written | scoping of Valaeon-specific requirements |
| NO-J3 | §6.3: which organisation is "ACS consulting"? | no public footprint ties it | Verify from the internal record | per-client identity design (NO-8) |
| NO-J4 | §6.4: who is "Valaeon"? | no public footprint | Verify from the client relationship owner | same |
| NO-J5 | §6.5: what was the "Drall platform" failure? | unidentifiable | Keep the generic inference labelled as inference | REQ-5 selling-point text |

## Success Criteria *(mandatory)*

- **SC-001**: The tooling register has 33 rows (24 shortlist rows, item 15 split in two and item 5b folded into #10, plus gaps 9.1-9.9, as defined in `contracts/tooling-decisions.md`), each with a disposition and a cited reason; the check finds zero research rows missing and its mutation (delete a disposition) exits 1.
- **SC-002**: 100% of RG rows pass the register check; a corrupted register exits 2.
- **SC-003**: Under policy `no-upward-change` 100% of seeded repeat submissions leave the area ability unchanged or lower and 0 of the first attempts are affected; under `record-only` the response bytes equal the run without the policy. Detection itself is 013's (T050).
- **SC-004**: With the shadow IRT job enabled, the bytes of every served practice response over a fixed script are identical to the run with it disabled (difference = 0), and the export lists every item with its response count.
- **SC-005**: 100% of scanned-PDF fixture attempts without opt-in are refused; 100% with opt-in produce sections that carry the OCR marker (satisfies 012 SC-009).
- **SC-006**: 100% of fixture table regions appear in the extraction report and the matching section shows the notice.
- **SC-007**: 100% of seeded unreadable/empty research sources appear in the 018 re-ingest report.
- **SC-008**: For every textbook pid sampled by the contract test (all 1,675 current sections), the 020 resolver href equals the 015-anchor-derived href (difference = 0).
- **SC-009**: Draft outlines are byte-identical across two runs; a guard test proves zero model/network calls; zero draft nodes are present in the registry or in `curriculum/learning/` without an accept record.
- **SC-010**: In a fixed-seed simulation with no true format effect, the false "leaning" rate does not exceed the type-I bound 021 SC-009 sets for question kinds.
- **SC-011**: The quiz-bank gate detects 100% of seeded defects (area with no item, unresolvable citation, duplicate options) and reports the live bank's counts.
- **SC-012**: The WER/CER gate returns 0, 1 and 2 on the three golden pairs (equal, divergent, unreadable), and its threshold is traceable to a recorded baseline run.
- **SC-013**: MRR, nDCG@k and recall@k equal hand-computed values on a golden ranking and are byte-identical over 100 runs.
- **SC-014**: The token-usage gate detects a seeded literal colour in 100% of cases and reports the real tree's finding count.
- **SC-015**: Benchmark v2 reports the out-of-corpus stratum separately, and an under-populated stratum is shown as insufficient (0 pooled rows from it).
- **SC-016**: The WebVTT export's cue count equals the segment count for every chapter with a sidecar, and an independent parser reads the file.
- **SC-017**: Every POC file has a supersession mapping and a recorded parity result.
- **SC-018**: Every task tagged with a NO-id is unstarted while its entry is unanswered (check output: 0 violations).

## Assumptions

- Dispositions marked "delegate default" are recommendations by the authoring agent and amendable by the operator; they are not operator decisions.
- Code facts are read from `workshop` `main` (`827e79e`) unless a row says `int-0.0.3` (`35f2ea3`); nothing was built or run for this spec except read-only commands recorded in `research.md`.
- The host plugin facts in the tooling register are one alias's settings (`~/.claude-claude5/settings.json`, plugin names only); other aliases were not read.
- Spec 023's content is not assumed; where this spec touches roles or per-client identity it says "when 023 lands".
