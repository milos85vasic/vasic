# Tasks: Research Gap Closure

**Input**: `specs/027-research-gap-closure/` (`spec.md`, `plan.md`, `research.md`, `contracts/`)
**Tests**: TDD throughout (§11.4.224): every BUILD task has a RED step on the broken artifact before GREEN (§11.4.115) and a paired mutation (§1.1). Every gate is three-valued (0 good, 1 finding, 2 could not determine, never a pass).
**State on 2026-10-21**: 0 of the tasks below are done; nothing in this spec has been built. Counts are re-derivable with `grep -c '^- \[x\]' tasks.md`.

## Format: `- [ ] Tnnn [P?] [TAGS] [FR/SC] description`

Tags: `[NO-n]` blocked until that NEEDS-OPERATOR entry (spec.md) is answered in an operator decisions record; `[XREF]` touches another spec's file (single-writer rule: the task is delivered to that spec's owner stream via its hook file, never by editing a shared file); `[REVIEW]` independent review (§11.4.142). Workshop code lives in the private `workshop/` repository, one branch and worktree per stream (see `plan.md`).

## Phase 1: Traceability and tooling register (US1, US8) - umbrella repo

- [ ] T001 [TDD] [FR-002, SC-002] RED: `scripts/test-verify-research-register.sh` with fixtures under `scripts/fixtures/research-register/`: good register, register with a row missing its disposition, with an unresolved task id, with a blocked row naming a non-existent NO id, with an unparsable file. Expected RED: script absent.
- [ ] T002 [FR-002] GREEN: `scripts/verify-research-register.sh` (parses `specs/027-research-gap-closure/contracts/requirement-register.md` and `docs/tooling/TOOLING-REGISTER.md`, resolves FR/SC/task ids against the named spec files, diffs the research ranked table and section 9 headings, resolves every in-repository `path:line` citation to an existing file and a line within its length (drift risk noted in `research.md`), exit 0/1/2). Header documents WHY/WHAT per the repository's script convention.
- [ ] T003 [FR-002] `--prove-failure`: seeds each T001 defect in a throwaway copy and requires the specific exit code; control run green. Register in `scripts/check-registry.tsv` as `research-register` with its paired proof (R5 anti-drift) and run `bash scripts/verify-check-registry.sh`.
- [ ] T004 [FR-001, FR-005, SC-001] Seed `docs/tooling/TOOLING-REGISTER.md` from `contracts/tooling-decisions.md`; export per the repository's markdown-export mandate; add the metadata table and ToC (§11.4.61).
- [ ] T005 [P] [FR-003, SC-002] Drift report `scripts/report-tooling-drift.sh`: compares REJECT/ADVISORY-ONLY rows with `enabledPlugins` names read from `$CLAUDE_CONFIG_DIR/settings.json`; prints names only; unset or unreadable gives rc 2. Paired fixture proof. Register it.
- [ ] T006 [FR-004] Wrapper rule for third-party gates: `scripts/lib/wrap-third-party-gate.sh` plus fixture proof (absent tool gives 2, failing gives 1, passing gives 0). No third-party gate is adopted by this task; it exists so the first adoption cannot collapse 2 into 1.
- [ ] T007 [REVIEW] Independent review of T001-T006 and of every disposition in `tooling-decisions.md` against the cited research sections; record the verdict before commit.

## Phase 2: Operator clarifications (US8)

- [ ] T004a [FR-005] Plan, do not claim: `prove-check-registry-003.sh`, `-008.sh` and `-009.sh` are absent (only 001, 002, 006 exist in `workshop/platform/gates/`, measured 2026-10-22). Each missing proof is written test-first (seeded violation must give rc 1, broken environment rc 2) in the workshop repo, or the register row records why the registry needs none.
- [ ] T010 [NO-all] [FR-036] Operator answers NO-1 .. NO-16 and NO-J1 .. NO-J5 in a new `docs/OPERATOR-DECISIONS-<date>.md` (the agent that authored this spec records recommendations only). Each answered entry unblocks the tasks tagged with its id; T003's check refuses a started task whose entry is unanswered (SC-018).

## Phase 3: Adaptive assessment integrity (US2) - workshop repo; CROSS-REFERENCES 013 T050-T054 (branch `n1-013-adaptive`) and adds only the residue: policy flag, admin report, shadow export, recorded recovery evidence

- [ ] T020 [XREF] [FR-006, SC-003] The detector is NOT built here. `013 tasks.md` T050 (`pkg/scoring/gaming.go`, `Store.GamingReport(s)`), T051 (`scoring.integrity` on submit and progress) and T053 (Progress-page neutral note) own it, ticked on branch `n1-013-adaptive`. This task is the cross-reference check only: T003's checker confirms those task ids still exist in `013 tasks.md`; if the golden-fixture properties (seeded repeats flagged, non-repeats not, byte-identical across 100 row-order shuffles, a serving-token replay never flagged) are not already asserted by `gaming_test.go`, the missing assertion is filed against the 013 stream (single-writer on `pkg/scoring`), not implemented as a second package.
- [ ] T021 [TDD] [FR-007, SC-003] RED: policy test in the 013 stream's `pkg/scoring` (after n1 merges): with policy `no-upward-change` a repeat submit leaves the area ability unchanged or lower and the response says so; with `record-only` the ability and the response bytes equal today's. Expected RED: no policy value exists (`gaming.go` states it deliberately does not discount the ability update, verified by reading the file on `n1-013-adaptive` 2026-10-22).
- [ ] T022 [XREF] [FR-007] GREEN: one configuration value `-scoring-repeat-policy record-only|no-upward-change` beside `-scoring-rapid-guess-min` in `wire_scoring.go` and `scoring.Config` (013-owned files: delivered to the 013 owner stream as a patch, not applied from this stream); default `record-only` until NO-5. Paired mutation: policy ignored.
- [ ] T023 [TDD] [FR-007] The submit response states, in the existing `scoring.integrity` object (013 T051), that a repeat did not raise the score when the policy is `no-upward-change`; absent otherwise. Neutral wording, no accusation.
- [ ] T024 [FR-007] Frontend: only the policy sentence is new; the neutral integrity note exists (013 T053, `progress.component.ts`). Behind a feature flag default OFF, wording reviewed for non-accusation; Karma spec and axe check; hook line only (single-writer rule).
- [ ] T025 [FR-008] Admin-only repeat-attempt report endpoint (same gate as 024 FR-006) aggregating `Store.GamingReports` per session and per question, and a CLI form; verified absent from `n1-013-adaptive` 2026-10-22 (the reading is per-session on GET /api/progress only); unauthenticated request gets 401, non-admin 403.
- [ ] T026 [NO-5] Select the default policy after the operator answers NO-5.
- [ ] T027 [XREF] [TDD] [FR-009, FR-010, SC-004] The 2PL fit is NOT built here: `013 tasks.md` T052 (`Fit2PL`, `Store.FitIRT`, `item_irt`, shadow-only unless `Config.IRTApply`) owns it, with a seeded parameter-recovery unit test (`irt_test.go`: 4000 responses from a=1.6, b=6.0). Residue only. RED: a shadow-invariant test over a fixed script, served bytes identical with `IRTApply` false whether the fit ran or not; and a read-only operator export of `item_irt` (no export was found: `item_irt` is referenced only by `irt.go`, `store.go`, `config.go`).
- [ ] T028 [FR-009] GREEN: read-only operator export (`fit-report.json`: per item a, b, response count, convergence flag) from `item_irt` to an operator path; never writes the serving tables.
- [ ] T029 [NO-4] [FR-010] Operator sets minimum responses, recovery tolerance and the promotion rule; until then no promotion task exists and `IRTApply` stays false. A recorded fixed-seed recovery run against the operator's tolerance, and the export on the live log, are evidence only.

## Phase 4: Document ingestion (US3, US4) - workshop repo

- [ ] T030 [FR-011] Re-measure the baseline: `pdf_textbook_sections.py` refusal text and exit code for an image-only PDF generated at test time; `tesseract --list-langs` output; paste both (§11.4.5).
- [ ] T031 [TDD] [FR-011, SC-005] RED: scanned-PDF fixture generated from a text fixture; refused (exit 2) without the opt-in; with the opt-in (flag and per-book config key) sections equal the fixture text and carry `attrs.derived=ocr`; missing language pack refused naming the pack.
- [ ] T032 [NO-1] [FR-011] GREEN: local OCR path in `pipeline/pdf_textbook_sections.py` (or a sibling module it calls) using the installed engine only; zero network; per-page confidence summary in `<out>.report.json`; license record untouched (026 FR-004).
- [ ] T033 [FR-012, SC-005] Plumb the OCR marker through `ingest-transcript` `attrs` (012 T006a/FR-021 mechanism) to the passage store and to `GET /api/textbooks` section payloads.
- [ ] T034 [XREF] [FR-012] Frontend: fidelity notice on `features/textbooks` page view and on a search hit for an OCR-derived section (owner: spec 020 stream; hook-line change).
- [ ] T035 [TDD] [FR-013, SC-006] RED then GREEN: table-region detection in the text-layer path (heuristic recorded in the report with page and reason); notice flag on the section; fixture with and without a table.
- [ ] T036 [TDD] [FR-014, SC-007] RED then GREEN: 018 re-ingest report lists unreadable and empty sources and undecodable bytes; fixture-driven; the existing redaction counts are unchanged.
- [ ] T037 [TDD] [FR-015, SC-008] Contract test: for every textbook pid in the catalogue (1,675 at `827e79e`), the 020 resolver href equals the 015 location-anchor-derived href; a mismatch fixture fails the test.
- [ ] T038 [TDD] [FR-016, SC-009] RED: draft generator tests (one node per TOC node, citations present, byte-identical twice, outside registry and `curriculum/learning/`). GREEN: `scripts/textbook-draft-outline.sh` plus Python module; no model, no network.
- [ ] T039 [FR-016, FR-017, SC-009] Zero-model guard: a test that fails if the generator imports or calls any model/network client (mirror `pipeline/test_zero_token_scan.py`).
- [ ] T040 [NO-3] [FR-016] Accept path: how an author accepts a draft node into the existing authoring path; blocked on NO-3.
- [ ] T041 [XREF] [FR-018, SC-017] Peek eligibility tests for textbook citation and library link targets; delivered to the 025 US7 owner.

## Phase 5: Client signal (US5)

- [ ] T045 [TDD] [FR-019, SC-010] Depends on 021 US4 merged. RED: fixed-seed null-effect simulation and golden fixture for the exposure-linked format view; GREEN: extend `pkg/medium` through 021's owner (single-writer); states reuse 021's closed set; insufficient evidence is shown as insufficient.
- [ ] T046 [NO-7] [FR-019] Operator confirms the exposure rule before the view ships.

## Phase 6: Quality gates (US6, US7) - workshop repo `platform/gates/`

- [ ] T050 [TDD] [FR-020, FR-021, SC-011] RED then GREEN: `verify-quiz-bank.sh` plus `prove-quiz-bank.sh` (three seeded defects, unreadable bank rc 2); disclosure line for the lexical necessary-not-sufficient limit.
- [ ] T051 [TDD] [FR-022, SC-012] RED then GREEN: `verify-transcript-wer.sh`: WER via existing alignment, CER via a new character alignment, threshold from `calibration/` baseline file; three golden pairs.
- [ ] T052 [TDD] [FR-024, SC-012] Ranked review windows from two-engine disagreement; deterministic.
- [ ] T053 [NO-6] [FR-023, FR-025, FR-026] Reference-dependent checks (weighted WER, seek error, DER) report UNDETERMINED until references exist; test that absent references give rc 2, not 0.
- [ ] T054 [TDD] [FR-027, SC-013] RED then GREEN: MRR, nDCG@k, recall@k in `run_retrieval_benchmark.py` (or a sibling) with hand-computed golden ranking; `verify-retrieval-benchmark.sh` keeps its contract.
- [ ] T055 [TDD] [FR-028, SC-014] RED then GREEN: `verify-token-usage.sh` (literal colour or spacing outside the token set in component styles); record the real tree's finding count before any fix.
- [ ] T056 [TDD] [FR-029, SC-016] RED then GREEN: WebVTT export from `transcript.segments.json`; attach as a captions track; first read `recording-player.component.ts` to record whether a track exists today.
- [ ] T057 [P] [FR-030] Advisory spell check for manual, FAQ, quickstart; dependency verdict (§11.4.270) recorded before any CLI is introduced.
- [ ] T058 [NO-16] [FR-031, SC-015] Out-of-corpus unanswerable stratum added to benchmark v2 (024 FR-012) with separate reporting; population blocked on the labeller (NO-16); the reporting code is not.
- [ ] T059 [FR-032] Record the entailment judge's short-versus-long claim measurement in the 024 gate evidence format.
- [ ] T060 [TDD] [FR-033, SC-003] Property tests: score clamp, audit-link order independence, replay idempotence, three-state contract; library under a dependency verdict; paired mutation.
- [ ] T061 [FR-034, SC-017] POC supersession map and parity results (adaptive POC parity is 013 T045; run the sample EPUB through the real extractor and diff section counts; confirm the toast component spec exists).
- [ ] T062 [FR-035, SC-007] Re-verify backlog Part E sub4 R2, R4, R5 against code; then add the late-redaction propagation proof for notes-PDF-origin `kg_*` rows.

## Phase 7: Closure

- [ ] T070 [REVIEW] Independent review (§11.4.142, Fable xhigh per §11.4.209) of each gate and its proof.
- [ ] T071 [FR-002] Claim-vs-reality ledger rows (§11.4.266) for: "every research requirement has an owner", "scanned PDFs are refused or marked", "repeat attempts do not raise the score under the selected policy".
- [ ] T072 User manual, FAQ and operator-guide entries for: repeat-attempt notice, OCR-derived marker, table notice, captions, draft outline queue (§11.4.257); each entry names the route where the user sees the behaviour.
- [ ] T073 Live verification script writing `result.json` plus a sha256 manifest from the running stack for every learner-visible item (T024, T034, T056); UI-visible acceptance by the operator.
- [ ] T074 Update `specs/026-spec-reconciliation` Open Decisions and `docs/OPERATOR-DECISIONS-*.md` cross-links when NO entries are answered.

## Dependencies

T001 -> T002 -> T003 -> T007. T010 gates every `[NO-n]` task. T020 -> T021 -> T022 -> T023 -> T024; T027 -> T028; T031 -> T032 -> T033 -> T034; T038 -> T039. T045 depends on 021 US4. T070 depends on all BUILD tasks it reviews.
