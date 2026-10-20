# Tasks: Specs 011-017 Reconciliation

**Input**: `specs/026-spec-reconciliation/` (`spec.md`, `plan.md`, `research.md`, `checklists/requirements.md`)
**Prerequisites**: read-only access to `workshop/` at HEAD `33e9760`.
**Tests**: none (documentation only). Verification is by grep for the marker `Reconciled by 026 on 2026-10-20` and by field-by-field comparison against the real decoder.

## Format: `[ID] [P?] [Decision] Description`

- Every edit adds the marker "Reconciled by 026 on 2026-10-20" at the edited place.
- `[x]` = applied on 2026-10-20 (evidence: the named file). Unticked = owed.

## Phase 1: Research (read-only)

- [x] T001 [P] Re-verify each contradiction against code at workshop `33e9760`; cite file:line in `research.md` (sections 1-7).
- [x] T002 [P] Re-measure the practice-bank baseline: 292 / 113 medium / 179 hard / 0 easy (`research.md` section 5).

## Phase 2: Decisions applied to the target specs

- [x] T003 [D1] Textbooks are `textbook_section` + `content_type: textbook`: edited `012` spec.md (banner, FR-001, entities), plan.md, tasks.md (global constraint, T013), data-model.md (sidecar example, note), contracts/epub-ingestion-stage.md; `015` spec.md (FR-007, entity), plan.md, tasks.md (acceptance-scenario, T-anchor-resolution and cross-spec text), data-model.md, contracts/location-anchor.md; `017` banner.
- [x] T004 [D2] License record in companion report `<out>.report.json` key `license`; `attrs` retargeted to the 5-parameter `DocumentObservation`: edited `012` spec.md (FR-005, FR-017, FR-021, entities), tasks.md (T006a, T016, T045), data-model.md (License Record block), contract; `017` spec.md (FR-002), data-model.md, contract.
- [x] T005 [D3] Achievement event stream: created `013/contracts/achievement-events.md`; edited `013` spec.md (banner, FR-017, SC-009), plan.md, tasks.md (T008a, T025a-T025d, T036a); `014` spec.md, plan.md, data-model.md, contracts/achievement-components.md, tasks.md (cross-spec section, T016 unblock condition, T016a).
- [x] T006 [D4] Remedial routing owned: `014` spec.md FR-022, tasks.md T016b, T016c; `013` spec.md assumption note, tasks.md T036a (carries `remedial_href`), T036b (kind-easing DEFERRED, owner 013, operator decision O-4).
- [x] T007 [D5] Baselines: `013` spec.md (edge case, FR-009, assumption), plan.md (scale, constitution row), data-model.md corrected to 292 / 113 / 179 / 0 with the measurement command.
- [x] T008 [D6] `015` plan.md (structure tree), tasks.md (frontend heading), spec/plan banners: frontend under `features/profile/`, one route `profile`.
- [x] T009 [D7] MMR for crossrefs rejected: `026` spec FR-010, `research.md` section 7; pointers in `017` banner and `016` T045b annotation.
- [x] T010 [D8] 012 adopts `pdf_textbook_sections.py`: `012` spec.md FR-013, FR-018, tasks.md T031, T032, T033, T046, T047 re-scoped; contract; `017` contract reconciliation block.
- [x] T011 [D9] Task hygiene: `016` tasks.md 41 tasks ticked with evidence notes; PARTIAL/ABSENT/relocated tasks annotated and left unticked; banner lists why the rest stay unticked. `011` tasks.md T001-T005 left exactly as the operator's working tree has them (untouched).
- [x] T012 [D10] Hot-spot ownership rules recorded in `026/plan.md`; every one of `011`, `012`, `013`, `014`, `015`, `017` plan.md/tasks.md references them; wire-file mapping: 011 `wire_audit.go` + `wire_lan.go` (T012 annotated), 013 `wire_scoring.go` (T022/T035/T042 annotated), 015 `wire_profile.go`, 017 `wire_rerank.go`.
- [x] T013 [D11] Open decisions O-1..O-7 listed once in `026/spec.md`.

## Phase 3: Verification

- [x] T014 Marker count per spec dir (`grep -rc "Reconciled by 026 on 2026-10-20" specs/01[1-7]*/`): 011=7, 012=29, 013=20, 014=14, 015=15, 016=55, 017=6.
- [x] T015 `git status --short` shows only `specs/` paths; `workshop/` untouched by this feature (the `M workshop` gitlink in the status snapshot pre-dates it).
- [ ] T016 [REVIEW] Independent review (§11.4.142) of every edit; recorded by the orchestrator before commit.
- [ ] T017 When 012-T013 is implemented: decode the produced sidecar with the real `readJSON`/`docSection` in a unit test (SC-002) and paste output.
- [ ] T018 Wave-0 (implementation orchestrator, not this feature): create the `wire_*.go` hook files and the `// hook:*` lines in `main.go`; verify with `go build ./... && go vet ./...`.

## Dependencies

T001-T002 -> T003-T013 -> T014-T015 -> T016. T017 and T018 belong to the implementing specs' waves.
