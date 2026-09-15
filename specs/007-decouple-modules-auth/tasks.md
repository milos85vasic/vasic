---
description: "Task list template for feature implementation"
---

# Tasks: Decouple Modules, Add Authentication & Extract Reusables

> **SUPERSEDED 2026-09-15** by [specs/008-unified-workshop-platform/spec.md](../008-unified-workshop-platform/spec.md) — this document is preserved for historical/traceability reasons; the unified spec is the active source of truth.

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
- [ ] T030 [P] [US1] Add decommission gate for workshop: the umbrella-hosted `workshop/` copy remains the operative one and MUST NOT be removed/decommissioned until the standalone workshop clone independently passes `install` and the full test suite on its own (FR-052)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

-[x] T003 [TDD] [US2] Clone ai_interviewing repo outside umbrella vasic
-[x] T004 [TDD] [US2] Initialize submodules and verify build passes independently
- [ ] T031 [P] [US2] Add decommission gate for ai_interviewing: the umbrella-hosted `ai_interviewing/` copy remains the operative one and MUST NOT be removed/decommissioned until the standalone ai_interviewing clone independently passes `install` and the full test suite on its own (FR-052)

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

- [x] T009 [P] [US5] Extract reusable code from workshop to submodules vasic-digital
- [x] T010 [P] [US5] Extract reusable code from ai_interviewing to submodules vasic-digital
- [ ] T028 [REVIEW] [US5] Add a mandatory content-boundary review gate to the reusable-code extraction pipeline: run the `scripts/verify-content-boundary.sh`-class check against each candidate extraction from workshop/ai_interviewing and block creation/push of the new public vasic-digital repository until it confirms zero private data (FR-051)
- [ ] T029 [P] [US5] Implement additive-then-cutover extraction pattern: keep each existing in-tree reusable code path functional in workshop/ai_interviewing until the corresponding consumer is confirmed migrated to, and re-tested against, the extracted public submodule (FR-053)

**Checkpoint**: At this point, all 14 reusables should be independent public submodules with governance cascade satisfied

---

## Phase 6: Submodule Updates (Priority: P2)

**Goal**: Update all existing submodules to latest main branches and verify working

- [x] T011 [P] [US6] Update all 14 existing submodules to latest main branch
- [x] T012 [P] [US6] Verify updated submodules build with no version conflicts

**Checkpoint**: All submodules at latest main; zero version conflicts

---

## Phase 7: Documentation (Priority: P2)

**Goal**: Extend and update documentation for both standalone modules

- [x] T013 [P] [US7] Extend and update documentation for both standalone modules (user guides, manuals, graphs, diagrams, schemes, FR-029/030 guides)
- [x] T014 [P] [US7] Create architecture diagrams and SQL definitions for module boundaries and data flows

**Checkpoint**: Documentation enables fresh user to clone→install→run→test each module without external help

---

## Phase 8: Test Coverage (Priority: P1)

**Goal**: Full test coverage with deterministic evidence on both modules; every test produces machine-verifiable deterministic evidence

- [x] T015 [TDD] [US8] Implement test suite for workshop with deterministic evidence (unit, integration, e2e, contract, performance, security, accessibility)
- [x] T016 [TDD] [US8] Implement test suite for ai_interviewing with deterministic evidence (unit, integration, e2e, contract, performance, security, accessibility)

**Checkpoint**: All work covered by constitution-supported test types; every test produces machine-verifiable deterministic evidence; zero false positives

---

## Phase 9: Security & Privacy Hardening (FR-042–FR-055, added 2026-09-15 brainstorm pass)

**Goal**: Harden the authentication/authorization implementation from Phase 3 against the security/privacy edge cases and Functional Requirements added in the 2026-09-15 brainstorm pass on spec.md. This spec has real, live security stakes: FR-009's example credentials (`milosvasic`/`WhiteSnake8587`, `rami`/`Test12345`) are already committed to this public repository's history and MUST be treated as compromised, never as real production secrets.

**Independent Test**: Each control below has its own automated, deterministic test that fails RED against an unhardened implementation and passes GREEN once the control is implemented, on both workshop and ai_interviewing.

- [ ] T017 [TDD] [REVIEW] [US3] Implement salted password hashing (Argon2id or bcrypt) for the shared user store on both modules; verify by test that no plaintext or reversibly-encrypted password value exists in any table, log, or fixture (FR-042)
- [ ] T018 [P] [REVIEW] [US3] Add a pre-deployment boot guard that refuses to start a production-flagged environment while the FR-009 example password hashes (for `milosvasic`/`WhiteSnake8587` and `rami`/`Test12345`) are still active, and document in each module's README that these already-committed values are compromised and MUST NOT be reused as real secrets (FR-043)
- [ ] T019 [TDD] [REVIEW] [US3] Add automated log/error-output scanning (unit + integration test) asserting that session tokens, session identifiers, and passwords never appear in application logs, error responses, crash reports, or URL/query strings on either module (FR-044)
- [ ] T020 [TDD] [REVIEW] [US3] Implement session-ID regeneration on successful login on both modules; add a regression test proving the pre-authentication session id is discarded and cannot become the authenticated session id (session-fixation protection) (FR-045)
- [ ] T021 [TDD] [REVIEW] [US3] Implement audience-scoped (module-restricted) tokens; add a contract test proving a token minted by workshop is rejected by ai_interviewing and vice versa, even though both modules read the shared user store (FR-046)
- [ ] T022 [TDD] [REVIEW] [US3] Implement fail-closed behavior on both modules when the auth provider/user database is unreachable; add an integration test that simulates database unavailability and asserts every protected route denies access (never grants it) during the outage (FR-047)
- [ ] T023 [TDD] [P] [US3] Implement per-account and per-source login rate limiting/throttling on both modules; add a test that exceeds the threshold and asserts subsequent attempts are throttled/blocked (FR-048)
- [ ] T024 [TDD] [P] [US3] Implement generic ("invalid username or password") authentication failure messages on both modules; add a test asserting byte-identical response content/shape for an unknown username vs. a known username with a wrong password (username-enumeration prevention) (FR-049)
- [ ] T025 [TDD] [P] [US3] Exempt health-check/readiness endpoints from authentication on both modules; add a test asserting these endpoints return HTTP 200 with no content or user data of any kind (FR-050)
- [ ] T026 [TDD] [REVIEW] [US3] Implement default-deny access for any user record with no assigned role/permission on both modules; add a test creating a roleless user and asserting zero access is granted — never admin-equivalent or inherited access (FR-054)
- [ ] T027 [TDD] [REVIEW] [US3] Implement cutover invalidation of any session/cookie issued before secure session handling (FR-017) was enforced; add a migration test proving a pre-rollout session cookie is rejected post-cutover on both modules (FR-055)

**Checkpoint**: Every security/privacy edge case resolved in the 2026-09-15 brainstorm pass has a corresponding implemented control and a deterministic passing test on both modules; FR-009's committed example credentials are confirmed non-functional as production secrets.

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
- **Security & Privacy Hardening (Phase 9)**: Depends on Phase 3 (Auth/RBAC) for the tasks it hardens (T017, T019-T027) and on Phase 5 (Extract Reusables) for the content-boundary/extraction tasks (T028, T029); FR-052 decommission-gate tasks (T030, T031) depend only on Phase 1/Phase 2 completion respectively

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
- Phase 9 security-hardening tasks marked [P] (T018, T023, T024, T025, T029, T030, T031) can run in parallel with each other once their respective prerequisite phase is complete

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