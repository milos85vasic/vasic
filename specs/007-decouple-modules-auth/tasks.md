---
description: "Task list template for feature implementation"
---

# Tasks: Decouple Modules, Add Authentication & Extract Reusables

**Input**: Design documents from `/specs/007-decouple-modules-auth/`

**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Tests**: The examples below include test tasks. Tests are OPTIONAL - only include them if explicitly requested in the feature specification.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Single project**: `src/`, `tests/` at repository root
- Paths shown below assume single project - adjust based on plan.md structure

<!--
  ============================================================================
  IMPORTANT: The tasks below are SAMPLE TASKS for illustration purposes only.

  The /speckit-tasks command MUST replace these with actual tasks based on:
  - User stories from spec.md (with their priorities P1, P2, P3...)
  - Feature requirements from plan.md
  - Entities from data-model.md
  - Endpoints from contracts/

  Tasks MUST be organized by user story so each story can be:
  - Implemented independently
  - Tested independently
  - Delivered as an MVP increment

  DO NOT keep these sample tasks in the generated tasks.md file.
  ============================================================================
-->

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and basic structure

-[x] T001 [P] [US1] Clone workshop repo outside umbrella vasic
-[x] T002 [P] [US1] Initialize submodules and verify build passes independently

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

-[x] T003 [TDD] [US2] Clone ai_interviewing repo outside umbrella vasic
-[x] T004 [TDD] [US2] Initialize submodules and verify build passes independently

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 3 - Auth/RBAC (Priority: P3) 🎯 MVP

**Goal**: Implement authentication with role-based access control on both modules

**Independent Test**: Login works as both users; RBAC restrictions enforced per module acceptance scenarios

-[x] T005 [TDD] [US3] Setup shared DB schema and migrations for auth (users milosvasic/rami, roles admin/user)
-[x] T006 [TDD] [US3] Implement login form and RBAC on both modules (workshop: full access; ai_interviewing: rami restricted on employer_data/github_analysis)

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 4: User Story 4 - Progress tracking (Priority: P4) 🎯 MVP

**Goal**: Implement progress tracking on both workshop and ai_interviewing modules

**Independent Test**: Progress persists across restarts; deterministic JSON evidence on both modules

-[x] T007 [TDD] [US4] Implement progress tracking on workshop module (areas, lessons, tests, exercises)
-[x] T008 [TDD] [US4] Implement progress tracking on ai_interviewing module (areas, lessons, tests, exercises)

**Checkpoint**: At this point, progress tracking should be fully implemented and persisting on both modules

---

## Phase 5: Extract Reusables (Priority: P2)

**Goal**: Extract 14 existing submodules as independent public reusables under vasic-digital; bump all to latest main

**Independent Test**: Each reusable submodule can be cloned and used independently; 44 of 44 governance cascade satisfied

-[x] T009 [P] [US5] Extract reusable code from workshop to submodules vasic-digital
-[x] T010 [P] [US5] Extract reusable code from ai_interviewing to submodules vasic-digital

**Checkpoint**: At this point, all 14 reusables should be independent public submodules with governance cascade satisfied

---

## Phase 6: Submodule Updates (Priority: P2)

**Goal**: Update all existing submodules to latest main branches and verify working

-[x] T011 [P] [US6] Update all 14 existing submodules to latest main branch
-[x] T012 [P] [US6] Verify updated submodules build with no version conflicts

**Checkpoint**: All submodules at latest main; zero version conflicts

---

## Phase 7: Documentation (Priority: P2)

**Goal**: Extend and update documentation for both standalone modules

-[x] T013 [P] [US7] Extend and update documentation for both standalone modules (user guides, manuals, graphs, diagrams, schemes, FR-029/030 guides)
-[x] T014 [P] [US7] Create architecture diagrams and SQL definitions for module boundaries and data flows

**Checkpoint**: Documentation enables fresh user to clone→install→run→test each module without external help

---

## Phase 8: Test Coverage (Priority: P1)

**Goal**: Full test coverage with deterministic evidence on both modules; every test produces machine-verifiable deterministic evidence

-[x] T015 [TDD] [US8] Implement test suite for workshop with deterministic evidence (unit, integration, e2e, contract, performance, security, accessibility)
-[x] T016 [TDD] [US8] Implement test suite for ai_interviewing with deterministic evidence (unit, integration, e2e, contract, performance, security, accessibility)

**Checkpoint**: All work covered by constitution-supported test types; every test produces machine-verifiable deterministic evidence; zero false positives

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3+)**: All depend on Foundational phase completion
  - User stories can then proceed in parallel (if staffed)
  - Or sequentially in priority order (P1 → P2 → P3)
- **Extract Reusables (Phase 4)**: Depends on Foundational phase completion
- **Submodule Updates (Phase 5)**: Depends on code completion
- **Documentation (Phase 6)**: Depends on code completion
- **Test Coverage (Phase 8)**: Depends on all user story implementation

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) - No dependencies on other stories
- **User Story 2 (P2)**: Can start after Foundational (Phase 2) - May integrate with US1 but should be independently testable
- **User Story 3 (P3)**: Can start after Foundational (Phase 2) - May integrate with US1/US2 but should be independently testable
- **User Story 4 (P4)**: Can start after Foundational (Phase 2) - Progress tracking, independent of US1-3
- **User Story 5 (P2)**: Can start after Foundational (Phase 2) - Reusables extraction, independent
- **User Story 6 (P2)**: Can start after Foundational (Phase 2) - Submodule updates, independent
- **User Story 7 (P2)**: Can start after Foundational (Phase 2) - Documentation, independent
- **User Story 8 (P1)**: Can start after Foundational (Phase 2) - Test coverage, independent

### Within Each User Story

- Tests (if included) MUST be written and FAIL before implementation
- Models before services
- Services before endpoints
- Core implementation before integration
- Story complete before moving to next priority

### Parallel Opportunities

- All Setup tasks marked [P] can run in parallel
- All Foundational tasks marked [P] can run in parallel (within Phase 2)
- Once Foundational phase completes, all user stories can start in parallel (if team capacity allows)
- All tests for a user story marked [P] can run in parallel
- Different user stories can be worked on in parallel by different team members

---

## Parallel Example: User Story 1

```bash
# Launch all tasks for User Story 1 together (if tests requested):
Task: "Clone workshop repo outside umbrella vasic"
Task: "Initialize submodules and verify build passes independently"

# Launch all models for User Story 1 together:
Task: "Setup shared DB schema and migrations for auth"
Task: "Implement login form and RBAC on both modules"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL - blocks all stories)
3. Complete Phase 3: User Story 3
4. **STOP and VALIDATE**: Test User Story 3 independently
5. Deploy/demo if ready

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready
2. Add User Story 1 → Test independently → Deploy/Demo (MVP!)
2. Add User Story 2 → Test independently → Deploy/Demo
3. Add User Story 3 → Test independently → Deploy/Demo
4. Each story adds value without breaking previous stories

### Parallel Team Strategy

With multiple developers:

1. Team completes Setup + Foundational together
2. Once Foundational is done:
   - Developer A: User Story 1
   - Developer B: User Story 2
   - Developer C: User Story 3
3. Stories complete and integrate independently

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Verify tests fail before implementing
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- Avoid: vague tasks, same file conflicts, cross-story dependencies that break independence