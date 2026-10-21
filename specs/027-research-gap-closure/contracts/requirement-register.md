# Contract: Research requirement register (RG-01..RG-48)

Machine-checked by `scripts/verify-research-register.sh` (FR-002). One row per research requirement that had no implementing task on 2026-10-21. Dispositions: BUILD, ADOPT, ADVISORY-ONLY, REJECT, BUILT-ALREADY, CROSS-REFERENCE, NEEDS-OPERATOR. The column **End user sees it** states where a learner, author or operator meets the result; "operator only" is stated where true. `workshop/docs/research/` is abbreviated `R/`.

Row format is fixed so the check can parse it: `| RG-nn | source | DISPOSITION | FR ids | SC ids | test shape | reachability | owner/state |`.

## A. Tooling and traceability

| RG | Source (R/) | Disposition | FR | SC | Acceptance test shape | End user sees it | Owner / state |
|---|---|---|---|---|---|---|---|
| RG-01 | `skills-and-plugins-2026-09-01.md` §6 ranked table #1-#23, §7 shortlist incl. #5b | BUILD (the register; per-item dispositions in `tooling-decisions.md`) | FR-001, FR-002 | SC-001, SC-002 | Parse register vs research table; delete one disposition in a copy: rc 1; unreadable file: rc 2 | Operator only: `docs/tooling/TOOLING-REGISTER.md` and its exports | NEW (this spec) |
| RG-02 | same §9.1 paired-mutation-for-gates | BUILT-ALREADY | FR-005 | SC-001 | Register row cites `scripts/verify-check-registry.sh:1-40` and `workshop/platform/gates/check-registry-00{1,2,3,6,8,9}.tsv` with `prove-check-registry-*.sh`; check confirms the files exist | Operator only | verified 2026-10-21 (`ls`) |
| RG-03 | same §9.2 contract testing | BUILT-ALREADY (local contract gates); Schemathesis/Pact ADVISORY-ONLY | FR-005 | SC-001 | Register row cites `platform/gates/verify-contract-{http,cli,pid}.sh` and `prove-contract-*.sh`; check confirms existence | Operator only | verified 2026-10-21 |
| RG-04 | same §9.3 three-valued semantics | BUILT-ALREADY (house contract); adoption rule for third-party gates is BUILD | FR-004, FR-005 | SC-001 | Wrapper fixture: tool absent maps to rc 2, tool failing maps to rc 1, tool passing maps to rc 0 | Operator only | NEW wrapper only if a third-party gate is ever adopted |
| RG-05 | same §9.4 quiz-bank validation | BUILD | FR-020, FR-021 | SC-011 | Seed three defects (area with no item, unresolvable citation, duplicate options): rc 1 each; unreadable bank: rc 2; real bank run prints counts | Learner: practice never serves an item whose citation does not resolve; author/operator: coverage report | NEW; precondition exists: boot CK021 logs "2 areas have no assessment" |
| RG-06 | same §9.5 transcription QA (jiwer, WER/CER) | BUILD (in-repo, no new dependency unless §11.4.270 verdict says otherwise) | FR-022 | SC-012 | Golden pairs: equal gives 0, divergent gives 1, unreadable gives 2; threshold read from a recorded baseline file | Operator only; learners benefit from measured transcript accuracy (001 SC-002 publishes it) | NEW; `pipeline/compare_engines.py:111,165` already aligns words |
| RG-07 | same §9.6 subtitle / WebVTT / chaptering | BUILD (WebVTT export); chaptering ADVISORY-ONLY | FR-029 | SC-016 | Cue count equals segment count; independent parser reads output; player loads the track | Learner: captions track on the recording player (UNCONFIRMED whether a track element exists today; first task reads `recording-player.component.ts`) | NEW |
| RG-08 | same §9.7 retrieval-quality evaluation | BUILD | FR-027 | SC-013 | Hand-computed golden ranking equals MRR/nDCG@k/recall@k; 100 byte-identical runs | Learner: search quality changes are now measurable before release; operator report | NEW; `run_retrieval_benchmark.py:149,245-267` reports top-1/top-5 only |
| RG-09 | same §9.8 design-token contract verification | BUILD | FR-028 | SC-014 | Seeded literal colour in a component style: rc 1; contrast gate unchanged | Learner: consistent themes and contrast in both themes | NEW; `verify-served-contrast.sh` exists; `design-tokens.spec.ts` exists |
| RG-10 | same §9.9 prose and spell lint | BUILD (user-facing docs only) | FR-030 | SC-001 | Seeded misspelling in a copy of the FAQ: rc 1; missing tool: rc 2 | Learner: manual/FAQ/quickstart read cleanly | NEW; advisory |
| RG-11 | same §1.6 "things this project needs most are switched off", §1.4-1.5 state | BUILD (read-only drift report) | FR-003 | SC-002 | Fixture settings with a REJECT row enabled: reported; names only; config dir unset: rc 2 | Operator only | NEW |
| RG-12 | same §10 security ladder and pinning | ADVISORY-ONLY | FR-001 | SC-001 | Register row states: nothing above risk tier 3 is adopted without NO-10 | Operator only | policy text |
| RG-48 | `education-platform/multi-provider-llm-and-content-model.md:538,611-646` (`screen_text` Kind, engine tracking `asr` vs `ocr`); spec 008 T449-T465 | NEEDS-OPERATOR (NO-1b) | FR-036 | SC-018 | Register check: row names a live NO entry | none until answered | spec 008 owns the build; OR-04 conflict recorded in backlog A5 |

## B. Adaptive assessment (`education-platform/adaptive-assessment-and-scoring.md`)

| RG | Source | Disposition | FR | SC | Acceptance test shape | End user sees it | Owner / state |
|---|---|---|---|---|---|---|---|
| RG-13 | §6 lines 692-700, §7 Phase 3 (A9) | BUILD (detector, report); policy NEEDS-OPERATOR NO-5 | FR-006, FR-007, FR-008 | SC-003 | Golden log: seeded repeats flagged, non-repeats not; 100 shuffles byte-identical; token replay unaffected | Learner: on the practice result, a neutral notice when a repeat did not raise the score; operator: admin-only report | NEW; `013 spec.md:70,127` defer it; no 013 task mentions it (grep 2026-10-21) |
| RG-14 | §1.3, §7 Phase 3 (2PL) | BUILD shadow fit only; promotion NEEDS-OPERATOR NO-4 | FR-009, FR-010 | SC-004 | Parameter-recovery simulation on fixed seed writes an error table; served-bytes diff with job on/off = 0 | Operator only until promoted; no learner-visible change | NEW; depends on `pkg/scoring` (on `int-0.0.3`, not `main`) |
| RG-15 | §3.1, §3.4, §5.3 (A7 crowd recalibration) | CROSS-REFERENCE | none | none | n/a | Learner: item difficulty self-corrects (013 SC) | `013 tasks.md` T037-T044 (unticked) |

## C. Document ingestion (`education-platform/document-ingestion-architecture.md`)

| RG | Source | Disposition | FR | SC | Acceptance test shape | End user sees it | Owner / state |
|---|---|---|---|---|---|---|---|
| RG-16 | §2.2 lines 380-404, §6 Phase 3 | BUILD, gated by NO-1 | FR-011, FR-012 | SC-005 | Generated scanned fixture: refused without opt-in (exit 2), sections equal fixture text with OCR marker with opt-in; missing language pack refused | Learner/author: `/textbooks` page and search hit show an "OCR-derived, may contain errors" notice | 012 FR-018/019, SC-009 state it; `012 tasks.md:253` defers it; refusal exists at `pdf_textbook_sections.py:222-223`; `eng`+`osd` only installed |
| RG-17 | §2.1, §2.2 tables and alt text | BUILD detection and notice; structured extraction ADVISORY-ONLY | FR-013 | SC-006 | Table fixture region listed in report; notice on section | Learner: notice "table may be misaligned" on the page view | NEW; 012 spec.md:141 accepts the limitation without a notice |
| RG-18 | §5.3 lines 799-818 | BUILD (018 path) | FR-014 | SC-007 | Seed an unreadable and an empty source: both listed in report | Author/operator: the Library reader shows "N sections could not be read" (UNCONFIRMED whether 018 UI can show it; task decides) | PDF path already reports `extraction_failures` (`pdf_textbook_sections.py:212,335`); 018 path reports redaction counts only |
| RG-19 | §B.3 (multi-provider doc), 015 location anchors, 020 resolver | BUILD (contract test) | FR-015 | SC-008 | For all 1,675 textbook pids the two paths give the same href | Learner: a citation opens the same page whichever path produced it | `020 spec.md:18` builds its own resolver and "does not wait for 015" |
| RG-20 | §5.5 lines 836-866 (promotion) | BUILD draft outlines, NEEDS-OPERATOR NO-3 for the accept path | FR-016 | SC-009 | Byte-identical drafts; zero model calls; nothing in registry/`curriculum/learning/` without accept | Author: a review queue; learner: sees nothing until accepted | NEW; 012 FR-020 forbids automatic promotion |
| RG-21 | `clients/jordan/...:425` REQ-2 (questions from textbooks) | NEEDS-OPERATOR NO-2 | FR-017 | SC-018 | Register check | none until answered | OR-04, D-06 |
| RG-22 | `ux-research-2026-09-01.md` P6 applied to 020/018 | BUILD (eligibility test) | FR-018 | SC-017 | One test per target kind (textbook citation, library link) | Learner: hover/focus preview on those links when 025's peek flag is on | component owner 025 US7 |
| RG-23 | §3.2 lines 550-560 (textbook ids are not chapter ids) | BUILT-ALREADY | none | none | Register cites `012 tasks.md:149` (T021) and `workshop/platform/backend/pkg/curriculum/textbook_scope_test.go` | Learner: `/api/chapters` count unchanged (`chapters:6`) | verified 2026-10-21 (file exists on `main`) |

## D. Retrieval, grounding and ASR (root research docs)

| RG | Source | Disposition | FR | SC | Acceptance test shape | End user sees it | Owner / state |
|---|---|---|---|---|---|---|---|
| RG-24 | `retrieval-and-grounding.md` §6 (domain shift) | BUILD stratum in 024 benchmark v2; labeller NO-16 | FR-031 | SC-015 | Per-stratum results; under-populated stratum shown insufficient, never pooled | Operator: the answer-gate verdict shows per-stratum numbers; learner: answering stays OFF until D-05 holds | 024 FR-012 builds v2 without the stratum |
| RG-25 | same §5 (granularity) and atomic claim checks | BUILD measurement; atomic decomposition ADVISORY-ONLY | FR-032 | SC-015 | Stratified short/long claim sample recorded in gate evidence | Operator only | NEW; 024 US3 addresses F1-F3 only |
| RG-26 | same §5 (batching, embedding floor, weights) | NEEDS-OPERATOR NO-15 | FR-036 | SC-018 | Register check | none | 008 T351, T073 note it |
| RG-27 | `asr-transcription-and-provenance.md` §4 | BUILD, reference-dependent NO-6 | FR-023 | SC-012 | With reference: weighted and class WER; without: exit 2 for that check | Operator only | NEW |
| RG-28 | same §3 (ROVER, query-by-committee) | BUILD | FR-024 | SC-012 | Deterministic ranked windows with scores; identical across runs | Operator: a ranked list of windows to review | NEW; `engine_b_crosscheck.py` is a cross-check only |
| RG-29 | same §5 (DER) | NEEDS-OPERATOR NO-6 | FR-026 | SC-018 | Absent reference: "no DER claim", exit 2 | none | 008 T207 is the human checkpoint |
| RG-30 | same §2 (boundary artifact) vs `001 spec.md:402` SC-003 | BUILD, reference-dependent NO-6 | FR-025 | SC-012 | Seek error computed from word-timing sidecar vs reference; absent reference exit 2 | Learner: a transcript click lands within the promised window | NEW |

## E. Client requirements (`clients/jordan/client-requirements-and-context.md`)

| RG | Source | Disposition | FR | SC | Acceptance test shape | End user sees it | Owner / state |
|---|---|---|---|---|---|---|---|
| RG-31 | REQ-1 (content-format half), §5 line 425 | BUILD, evidence-gated | FR-019 | SC-010 | Null-effect simulation bounded; golden fixture byte-identical | Learner: `/profile/medium` format section, only when evidence supports; otherwise "not enough evidence yet" | 021 FR-001 keeps formats engagement-only; US4 capture is consent-gated |
| RG-32 | REQ-3 (per client / participant need) | NEEDS-OPERATOR NO-8 | FR-036 | SC-018 | Register check | none until answered | 022 is corpus-only (`022 research.md:33-40`) |
| RG-33 | REQ-4 routing | CROSS-REFERENCE (+NO-13) | none | none | n/a | Learner: in-context hint exists (021 US3); server bias blocked | `021 tasks.md:271` T048a BLOCKED; `013 tasks.md:598` T036b |
| RG-34 | REQ-5 client-facing trust statement | ADVISORY-ONLY (NO-14) | none | none | Claim ledger row exists in 024 (T100) | none | `024 tasks.md:196` |
| RG-35 | REQ-6 residency copy | CROSS-REFERENCE (+NO-9) | none | none | n/a | Learner/operator: residency note on `/settings/providers` or its absent state | `024 tasks.md:158-164` T072-T074, T078 |
| RG-36 | §6 items 1-5 | NEEDS-OPERATOR NO-J1..NO-J5 | FR-036 | SC-018 | Register check | none | cannot be specced |
| RG-37 | 021 OD-4, OD-5 | NEEDS-OPERATOR NO-11, NO-12 | FR-036 | SC-018 | Register check | none | no task, no operator record (021 spec.md:312-321) |

## F. UX research (`ux-research-2026-09-01.md`)

| RG | Source | Disposition | FR | SC | Acceptance test shape | End user sees it | Owner / state |
|---|---|---|---|---|---|---|---|
| RG-38 | P2 self-explanation and confidence | CROSS-REFERENCE (correction: it HAS tasks) | none | none | n/a | Learner: confidence prompt before the reveal | `025 tasks.md:83-93` T031-T041 (unticked) |
| RG-39 | §4/§5 U32, U35 | CROSS-REFERENCE (correction: it HAS a task) | none | none | n/a | Learner: keyboard scroll and 24x24 targets | `025 tasks.md:34` T006 |
| RG-40 | §3 live-region caution (line 124) | ADVISORY-ONLY (reviewed, deliberate) | none | none | The single `aria-live="assertive"` context-change announcement is documented in code (`transcript.component.ts:117-142`); axe baseline in T006 | Learner (screen reader) | reviewed 2026-10-21; `core/state.component.ts:333` assertive set not enumerated (UNCONFIRMED which states) |
| RG-41 | P3, P8, P10, P14, P15, P16, offline subset | ADVISORY-ONLY (deferred or rejected by decision) | none | none | Register carries each revisit condition from `025 spec.md:36-52` | none | 025 table |

## G. Gamification, reference prototypes, property tests, residue

| RG | Source | Disposition | FR | SC | Acceptance test shape | End user sees it | Owner / state |
|---|---|---|---|---|---|---|---|
| RG-42 | `education-platform/poc/*` | BUILD (supersession map + parity) | FR-034 | SC-017 | Map file lists each poc file's counterpart; EPUB sample through real extractor diffed; toast spec exists | Operator only | adaptive POC parity is `013 tasks.md:706` T045 |
| RG-43 | `gamification-and-design-system.md` design-QA of the full family | CROSS-REFERENCE | none | none | n/a | Learner: consistent component states | `014 tasks.md:325,327` T030, T031 |
| RG-44 | `skills-and-plugins` §7 item 3 (property-based testing) | BUILD technique; skill install NEEDS-OPERATOR NO-10 | FR-033 | SC-003 | Properties hold over generated input; paired mutation breaks one | Learner: scoring invariants hold | NEW |
| RG-45 | `document-ingestion-architecture.md` ~l.183-204 (R2 of backlog Part E sub4) | BUILD verification, re-verify first | FR-035 | SC-007 | Registry-minted `kg_*` counts for the notes document match the expected | Operator only | UNCONFIRMED against code |
| RG-46 | `asr-transcription-and-provenance.md` §7 | BUILD proof | FR-035 | SC-007 | Late redaction propagates into every derived `kg_*` row | Learner: a redacted statement never reappears via a derived row | NEW |
| RG-47 | `multi-provider-llm-and-content-model.md:140-150` (standalone clone needs `go.work`), ux §4 "axe is not accessibility" | NEEDS re-verification; ADVISORY-ONLY for the axe caution | FR-035 | SC-007 | Re-verify first; add a task or close with evidence | Operator only | backlog Part E sub4 R4, R5: UNCONFIRMED |
