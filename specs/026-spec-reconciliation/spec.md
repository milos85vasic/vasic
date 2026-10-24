# Feature Specification: Specs 011-017 Reconciliation (contradictions, stale baselines, hot-spot ownership)

**Feature Branch**: `026-spec-reconciliation` (no git branch created; authored directly into the reserved `specs/026-spec-reconciliation/` directory, same simplification as spec 015)

**Created**: 2026-10-20

**Status**: Draft (revision 2, 2026-10-21: Open Decisions updated by 027 after the operator ratified O-2 to O-8 and the crossref floor; documentation-only feature; every edit it describes has ALREADY been applied to the target specs, see `tasks.md`)

**Input**: Operator directive of 2026-10-20: reconcile specs 011, 012, 013, 014, 015, 016 and 017 against each other and against the real `workshop/` code at HEAD `33e9760` (the gap analysis was taken at `bb69fe5`; every code claim below was re-verified at `33e9760`), before any of them is implemented. Source of the contradictions: the 2026-10-20 gap analysis and architecture plan (session scratchpad, not committed; the facts are restated with file:line in `research.md`, so this spec does not depend on it).

**Scope**: specs/ markdown only. No product code, nothing under `workshop/` is touched, no private chapter or transcript text is quoted (paths only).

**Builds on**: `specs/011-multi-provider-llm-providers`, `specs/012-document-ingestion-textbooks`, `specs/013-adaptive-assessment-scoring`, `specs/014-gamification-design-system`, `specs/015-universal-content-model-profile`, `specs/016-workshop-live-qa-fixes`, `specs/017-exhaustive-rag-expansion`.

## Why this exists

Specs 011-015 were written before spec 017 was implemented and merged. 017 changed three facts the others depend on (a `textbook_section` passage Kind exists; `ingest-transcript` refuses a sidecar row without `content_type`; the PDF extractor was shipped under a different name and shape). Separately, 012/013/014/015 contain cross-references that were never closed (an event stream 014 consumes and 013 never defines; remedial routing 013 hands to 014 which has no requirement for it), stale numeric baselines, and one path-convention error. Implementing any of them as written would fail at the first real run (measured causes in `research.md`). This feature records one decision per contradiction, applies it to the affected specs, and states the file-ownership rules that let several specs be implemented in parallel without colliding.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - An implementer can follow spec 012 literally and the first ingest succeeds (Priority: P1)

An engineer implements spec 012's PDF/EPUB work from `tasks.md` without reading anything else. Today that produces a sidecar the real decoder rejects. After reconciliation, every sidecar field, kind, content type and license location named in 012 matches what `ingest-transcript` accepts.

**Why this priority**: This is the only contradiction that is a guaranteed runtime failure (`DisallowUnknownFields`, missing `content_type`) rather than a design inconsistency.

**Independent Test**: Take the sidecar shape now written in 012's `data-model.md`, feed it to the real decoder (`cmd/ingest-transcript`) in a unit test: it decodes, `docContentTypes` accepts the (kind, content_type) pair, and the license record is found in the companion report file. Paste the output.

**Acceptance Scenarios**:

1. **Given** 012's reconciled sidecar example, **When** it is compared field-by-field with `docSection` (`cmd/ingest-transcript/main.go:102-117`), **Then** every key in `sections[]` is a declared field of `docSection`.
2. **Given** a textbook section from any format, **When** its (kind, content_type) is checked against `docContentTypes` (`cmd/ingest-transcript/content_type.go:23-29`), **Then** it is `(textbook_section, textbook)` and passes.
3. **Given** the license record, **When** a reader looks for where it is stored, **Then** two named, sibling locations answer: the full record in `<out>.license.json` and its deterministic summary `{basis, basis_class, record_file}` under the key `license` of `<out>.report.json`; both are outside the decoded sidecar.

### User Story 2 - Spec 014 has a producer to consume and spec 013 owns its definition (Priority: P1)

An engineer starting `014-T016` finds a defined event contract in 013, with payload, triggers, storage, idempotency and delivery.

**Independent Test**: The contract file `specs/013-adaptive-assessment-scoring/contracts/achievement-events.md` defines every field of 014's `AchievementEvent` (`data-model.md` of 014) plus a wire mapping, and 013's `tasks.md` contains tasks that emit each of the three kinds.

**Acceptance Scenarios**:

1. **Given** 014's `AchievementKind` (`level-up | chapter-complete | adjusted`), **When** 013's contract is read, **Then** each kind has an emitting trigger, a `coalesceKey`, and a payload.
2. **Given** a retried submit, **When** the event is emitted, **Then** no duplicate event row exists (uniqueness key stated).
3. **Given** 013 hands remedial routing to 014, **When** 014's `spec.md` is read, **Then** an FR exists for it and a task implements it.

### User Story 3 - Parallel implementation streams do not collide (Priority: P2)

An orchestrator dispatches several specs at once. Each spec's `plan.md` names which shared files it may and may not edit.

**Independent Test**: Every plan of 011-015 and 017 contains a pointer to the ownership rules recorded here; the hot-spot table in `research.md` lists each shared file with its owner.

### User Story 4 - Baselines in the specs are measured, not remembered (Priority: P3)

**Independent Test**: The practice-bank figures in 013 equal a re-runnable measurement (`research.md` section 5): 292 questions, 113 medium, 179 hard, 0 easy at workshop `33e9760`.

## Edge Cases

- A decision here conflicts with an operator decision still open in the target spec (per-area vs cross-curriculum ability, modal routing map): the open item stays open and is listed under Open Decisions; this feature does not close it. (The license vocabulary, formerly in this list, was resolved 2026-10-20 as O-1 by the operator's delegate and is no longer open.)
- A reconciliation edit would change a task already ticked: ticked tasks are never edited (011 T001-T005 are left as is).
- The gap analysis disagrees with the code: the code wins and the discrepancy is recorded in `research.md`.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001** (D1): All textbook content from every format (PDF, EPUB, FB2, DOCX, HTML) MUST mint as `kind: textbook_section` with `content_type: textbook` under a registry scope `textbook-<slug>`. Spec 012's statements "mint as `doc_section`" and spec 015 FR-007's "use `doc_section`" are superseded; no further `passagestore.Kind` is introduced by 011-015.
- **FR-002** (D1): Every sidecar row MUST carry `content_type`; spec 012's sidecar contract `{text, path, line_start, line_end, kind}` is extended to `{pid?, text, path, line_start, line_end, kind, content_type}` (+ optional `attrs` once 012-T006a lands).
- **FR-003** (D2): The License Record MUST be stored as two sibling files next to the sidecar, never as a field of the sidecar or of a `sections[]` row: (a) the FULL record `{basis, basis_class, recorded_by, recorded_at}` in `<out>.license.json` (stem + `.license` + suffix); (b) the DETERMINISTIC summary `{basis, basis_class, record_file}` under the top-level key `license` of the companion report `<out>.report.json` (stem + `.report` + suffix, the path `pdf_textbook_sections.py` already writes). The split exists because `scripts/ingest-textbooks.sh` compares report hashes across runs and `recorded_at`/`recorded_by` are not derived from the inputs. Write order MUST be license file, report, sidecar last. The extractor MUST still refuse to run without `--license-basis` before reading any source byte. The same rule applies to the Phase-3 `failures` list (key `failures` of the report file). *(Amended 2026-10-20 after the S4 independent review, M5; the original D2 text put the full record in the report.)*
- **FR-004** (D2): Spec 012's `attrs` passthrough (FR-021 / T006a) is retained, but its Go change MUST target the CURRENT signature `DocumentObservation(chapterSlug, text string, kind passage.Kind, contentType string, ref passage.SourceRef)` (`internal/passagestore/domain.go:642`) and the CURRENT call site `cmd/ingest-transcript/main.go:443`. `attrs` is for location metadata only; the license record MUST NOT be carried in `attrs`.
- **FR-005** (D3): Spec 013 MUST define the achievement event stream consumed by spec 014: kinds `level-up`, `chapter-complete`, `adjusted`; payload per `specs/013-adaptive-assessment-scoring/contracts/achievement-events.md`; persisted append-only; delivered inline in the submit response and replayable through `GET /api/progress?events_after=<seq>`; idempotent per source entry.
- **FR-006** (D3): The server wire form is snake_case (consistent with the rest of 013's contracts); spec 014's adapter (task T016) maps it to its camelCase `AchievementEvent`.
- **FR-007** (D4): Spec 014 MUST contain an FR and a task for the remedial link on `adjusted` events (FR-022 / T016b). The kind-easing half of the 013 hand-off (routing to an easier question kind) is a server-side behavior, is NOT a 014 UI concern, and is recorded as deferred with owner 013 (a post-MVP follow-up, operator decision; see Open Decisions).
- **FR-008** (D5): Practice-bank baselines MUST cite a re-runnable measurement. Measured at workshop `33e9760`: 292 questions in 40 files, 113 medium, 179 hard, 0 easy. Spec 013's 311 / 121 / 190 figures are superseded; the zero-`easy` gap persists. The measurement command is recorded in `research.md` section 5.
- **FR-009** (D6): Spec 015's frontend MUST live under `platform/frontend/src/app/features/profile/` (lazy child routes in `features/profile/profile.routes.ts`, one route `profile`), not `src/app/profile/`, matching every existing feature directory (`app/features/{areas,auth,chapters,curriculum,inquiry,passage,plans,practice,progress,section,transcript}`) and spec 014.
- **FR-010** (D7): Cross-references (crossrefs) MUST NOT use Maximal-Marginal-Relevance. Decision: crossrefs keep cosine ranking with a minimum-score floor and a per-source cap (`pkg/crossref` declines MMR in its own package doc; spec 017 research section 0 measured MMR as non-deterministic and score-corrupting). Diversity concerns raised by the UX research are met through the score floor and the honest empty state (spec 016 T045b), not through MMR.
- **FR-011** (D8): Spec 012's PDF work MUST adopt `workshop/pipeline/pdf_textbook_sections.py` (shipped by 017, commit `66c6b78`) as the single PDF implementation. 012's planned `pdf_sections.py` is NOT created; 012 tasks T031-T033, T046-T047 become "extend `pdf_textbook_sections.py`".
- **FR-012** (D9): Task checkboxes MUST reflect evidence. Spec 016 tasks proved DONE by source evidence (list in `tasks.md` T016) are ticked with an evidence note; tasks with ledger-only, partial, absent or unconfirmed evidence stay unticked and are annotated.
- **FR-013** (D10): Every plan of specs 011, 012, 013, 014, 015 and 017 MUST reference the hot-spot ownership rules (section "Hot-spot ownership rules" in `plan.md` of this feature): hook files `cmd/workshop-server/wire_<feature>.go`, single-writer files, one branch + worktree per stream, never run restart/start/stop against the live stack from a worktree.
- **FR-014** (D11): Open decisions that this feature does not close MUST be listed in one place (this spec, "Open Decisions") and cross-referenced from the target spec.

### Key Entities

- **Decision (D1..D11)**: one resolved contradiction: statement, evidence (file:line), affected spec files, status.
- **Hot spot**: a shared file or directory edited by more than one spec, with one named owner.
- **Reconciliation note**: the marker `Reconciled by 026 on 2026-10-20` placed at every edited location in a target spec.

## Open Decisions (not closed by this feature; need an operator)

| ID | Decision needed | Where it lives / state |
|---|---|---|
| O-1 | **RESOLVED 2026-10-20 by the operator's delegate (not an operator-typed decision; the operator may amend).** License `basis` closed vocabulary: `public-domain` \| `open-license` \| `rights-holder-permission` \| `operator-directed`, written `<class>[: detail]` (a bare Creative Commons id such as `CC-BY-4.0` reads as `open-license`). `UNVERIFIED`, `unknown`, empty and typos are REFUSED for EPUB (`pipeline/textbook_license.py`, enforced by `epub_sections.py`). The PDF path (`pdf_textbook_sections.py`, spec 017) is deliberately NON-ENFORCING for its legacy callers: it requires a non-empty basis and records `basis_class: null` when out of vocabulary; enforcing it there is a separate behaviour change. `operator-directed` is the class the three current books use. | 012 spec FR-005, 017 `contracts/textbook-ingestion-stage.md` |
| O-2 | Per-area vs cross-curriculum ability score | **RATIFIED 2026-10-21** (`docs/OPERATOR-DECISIONS-2026-10-21.md` D-08, row "O-2 (ability score per area)"). Implemented per area: `pkg/scoring/doc.go:8` on `int-0.0.3` (not on `main`). 013 spec "Clarifications Needed" and T049 still showed it open until *Reconciled by 027 on 2026-10-21* |
| O-3 | Modal routing map (which events are modal-worthy) | **RATIFIED 2026-10-21** (D-08): a modal only for `level-up` and `chapter-complete`. The `modal_worthy` flag is at `pkg/scoring/events.go:40` on `int-0.0.3`; the modal host is on branch `s9-014-modal-polish`, not in `int-0.0.3` (state as audited 2026-10-21) |
| O-4 | Kind-easing (route a struggling learner to an easier question kind) | **RATIFIED 2026-10-21** (D-08): BUILD it, server side, owner 013. 013 T036b is therefore no longer "post-MVP deferred": it is an owed task (text annotated by 027). **Corrected by 026 Wave 1 on 2026-10-24:** the 2026-10-21 "no implementation found" reading is SUPERSEDED. 013 T036b is ticked in `specs/013-adaptive-assessment-scoring/tasks.md` and the implementation exists (commit `94a074a`, `kind_easing_test.go`, `questions_kind_easing_test.go`, revised 2026-10-22), but it is reachable ONLY from `origin/rescue/n8-013-ui-gate`, `origin/rescue/qa-candidate` and `qa-candidate-wip`; re-measured 2026-10-24 `git merge-base --is-ancestor 94a074a main` is FALSE and no `kind_easing` file is on workshop `main` (`git ls-tree -r main`). Built, NOT merged: stays open for the Wave 0 branch integration |
| O-5 | `chapter-complete` granularity | **RATIFIED 2026-10-21** (D-08): all lessons in an area completed. Implemented at `internal/api/lessons.go:552-561` on `int-0.0.3` |
| O-6 | Live merge of the 1,675 textbook passages and enabling the reranker | **RATIFIED 2026-10-21** (D-08): merge approved and EXECUTED (workshop data commits `576f8d6`, `827e79e`, `OPERATOR-DECISIONS-2026-10-21.md` DC-01, DC-02); the reranker stays OFF until a two-sided regression passes (flags default false at `cmd/workshop-server/main.go:429,438`) |
| O-7 | Whether the stale 011 `spec.md` FR-005 NEEDS CLARIFICATION marker (audit schema) is resolved by `data-model.md` section 4 | **RATIFIED 2026-10-21** (D-08): counts as resolved. The marker text in 011 `spec.md` is annotated by 027 |
| O-8 | Graded questions join adaptive practice per question after the session attempted them in the assessment | **RATIFIED 2026-10-21** (D-08). No spec, task or code recording this join was found in the 2026-10-21 audit (`internal/api/questions_graded.go` is the answer-key withholding rule, a different thing): a task is owed in the 013 stream (see `specs/027-research-gap-closure/research.md` section 6, finding A-04) |
| crossref floor | A single noise floor at quantile 0.90, value 0.6391, applied at the next crossref derivation | **RATIFIED 2026-10-21** (D-08). Not yet applied: `pkg/crossref/crossref.go:250` `MinScore` default is 0 and no compose file sets `WORKSHOP_CROSSREF_MIN_SCORE` (audit addendum A3). `cmd/crossref-floor/main.go` exists |

**Not covered by the 2026-10-21 ratification** (D-08 says so): X-01 (LAN link-local), X-02 (014 FR-007 queue cap), X-05, X-07 and the open items D-PDF, D-DIAG, D-EMB, D-SVG and the audit failure mode. They stay as `docs/OPERATOR-DECISIONS-2026-10-20.md` has them. *(Reconciled by 027 on 2026-10-21.)*

## Success Criteria *(mandatory)*

- **SC-001**: 100% of the contradictions C1-C8 of the gap analysis plus the MMR and PDF-duplication items have a numbered decision (D1-D8) and an applied edit; verified by `grep -c "Reconciled by 026 on 2026-10-20"` over each target spec dir returning at least 1 for 011, 012, 013, 014, 015, 016, 017.
- **SC-002**: The reconciled 012 sidecar example decodes with the real decoder (checked by a unit test written when 012-T006a/T013 is implemented; until then the field-by-field comparison of User Story 1 is the evidence).
- **SC-003**: Zero edits touch `workshop/` or product code (`git status` shows changes only under `specs/`).
- **SC-004**: Every figure in the target specs that this feature changed cites a measurement command and a `workshop` commit.

## Assumptions

- The workshop checkout at HEAD `33e9760` is the reference for code claims. Claims taken from the gap analysis and not re-verified are marked UNCONFIRMED in `research.md`.
- Live-stack facts (build `ce62bcb`, reranker off, no textbook rows in the live registry) come from the gap analysis and were not re-measured (no authenticated calls).
- Hook files named `wire_<feature>.go` do not exist yet in `cmd/workshop-server` (existing wiring files are `authkit_wire.go`, `lan_admit.go`, `migration_wiring.go`, `redaction_log.go`, `suppression.go`); creating them is a Wave-0 task of the implementation orchestrator, not of this feature.
