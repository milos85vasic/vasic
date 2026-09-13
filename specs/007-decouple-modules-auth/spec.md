# Feature Specification: Decouple Modules, Add Authentication & Extract Reusables

**Feature Branch**: `007-decouple-modules-auth`

**Created**: 2026-09-12

**Status**: Draft

**Input**: User description: We are in vasic umbrella project located under Projects directory which is our main parent directory for all of our projects. First thing we MUST DO is to fully decouple ai_curriculum and workshop as completely independent modules! They MUST BE fully independant and possible to clone and use outside of umbrella project (vasic). All Submodules and other dependencies MUST BE contained withing ai_curriculum and workshop modules (projects) itself so any user can clone them! These users may not have access to vasic umbrella! This is very critical! After all extraction . decoupling is fully done make sure we clone both ai_curriculum and workshop inside Projects directory as separate projects outside of vasic umbrella project and after cloning to setup / install them both, run all tests we have and validate and verify them both working with no issues on LIVE running instances! Once this is done we MUST incorporate login form on both ai_curriculum and workshop. Users we login to both MUST HAVE different set of access. Users MUST BE defined in main database! Create two users: milosvasic / WhiteSnake8587 and rami / Test12345. On workshop project (module) both users MUST HAVE access to everything and they are completely equal. On ai_curriculum rami will not have any access to information or any data about employer we are mentioning or any abalisys of existing GitHub projects, only real knowledge base - areas, lessons, tests and exercises and tracking of progress (which does not work on both modules and MUST BE fully implemented working, tested verified and validated) !!! We MUST BE able to sign out and switch account! Make sure we cannot access any content if users do not sign in into the platofrms! Keep in mind that heavy and exhaustive refinement of users access levels will be required in the future so thuis all MUST BE fully taken into the account! Make sure we extract all reusabvle codebase among the ones we already have as fully decoupled Submodules and all of them / all of it as separate fully generic reusable decouples PUBLIC Submodule hosted in its own repository on GitHub and GitLab. USe GitHub and GitLab CLIs for creation of any new Submodules. All of them shall be created under vasic-digital organization! All existing Submodules MUST BE fully up to date with the latest codebases (fetch / and pull from main branches). Make sure all work is fully and regularly commited and pushed to all upstreams - all Submodules and main repo fully recursively. All documentation we have MUST BE extended, updated and all other materials - user guides, manals, graphs, diagrams, schemes and various defintiions we may have or we may need yet to create (templates, SQL defintiions, and all others). All work MUST BE fully covered with all supported test types (by the constitution) and every test MUST PRODUCE machine rock-solid evidence wgich will be validated and verified deterministically! There MUST BE no false or faulty results or ai slop or bluff of any kind or form!

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Decouple Workshop as Independent Module (Priority: P1)

**Description**: Workshop module must be extractable from the vasic umbrella and function as a completely standalone project that can be cloned, installed, and run by any user without access to the vasic repository.

**Why this priority**: This is the foundational requirement - without decoupling, none of the other features can be validated independently.

**Independent Test**: Can be fully tested by cloning the workshop repository to a fresh machine with no access to vasic, running install/setup, and verifying all functionality works.

**Acceptance Scenarios**:
1. **Given** a fresh machine with only git and required runtime, **When** user clones workshop repo, **Then** all submodules initialize correctly and build passes
2. **Given** workshop cloned independently, **When** user runs installation script, **Then** all dependencies are resolved internally without referencing vasic
3. **Given** standalone workshop, **When** user runs test suite, **Then** all tests pass with deterministic evidence

---

### User Story 2 - Extract ai_interviewing (ai_curriculum) as Independent Module (Priority: P1)

**Description**: ai_interviewing module (user-facing name: ai_curriculum) must be extracted from the vasic umbrella and function as a completely standalone project that can be cloned, installed, and run independently.

**Why this priority**: Parallel to workshop decoupling - both modules must be independently usable. Module already exists as ai_interviewing submodule.

**Independent Test**: Can be fully tested by cloning the ai_interviewing repository to a fresh machine, running install/setup, and verifying all functionality works.

**Acceptance Scenarios**:
1. **Given** a fresh machine, **When** user clones ai_interviewing repo, **Then** all submodules initialize and build passes
2. **Given** ai_interviewing cloned independently, **When** user runs installation, **Then** all dependencies resolved internally
3. **Given** standalone ai_interviewing, **When** user runs test suite, **Then** all tests pass with deterministic evidence

---

### User Story 3 - Authentication with Role-Based Access Control (Priority: P1)

**Description**: Both workshop and ai_interviewing (user-facing name: ai_curriculum) must have login forms with database-backed users and role-based access control.

**Why this priority**: Security requirement - no content accessible without authentication, different permission levels per module.

**Independent Test**: Can be tested by attempting to access content without login (should fail), logging in as each user (should get appropriate access), and switching accounts.

**Acceptance Scenarios**:
1. **Given** unauthenticated user accesses workshop, **When** they try to view any content, **Then** they are redirected to login
2. **Given** user milosvasic logs into workshop, **When** they access any feature, **Then** they have full access
3. **Given** user rami logs into workshop, **When** they access any feature, **Then** they have full access equal to milosvasic
4. **Given** user milosvasic logs into ai_interviewing, **When** they access any feature, **Then** they have full access
5. **Given** user rami logs into ai_interviewing, **When** they access employer data or GitHub project analysis, **Then** access is denied
6. **Given** user rami logs into ai_interviewing, **When** they access knowledge base areas/lessons/tests/exercises/progress, **Then** access is granted
7. **Given** authenticated user, **When** they click sign out, **Then** session ends and they cannot access content
8. **Given** signed out user, **When** they switch to different account, **Then** new session starts with that account's permissions

---

### User Story 4 - Progress Tracking Implementation (Priority: P1)

**Description**: Progress tracking (areas, lessons, tests, exercises) must be fully implemented, working, tested, verified, and validated on both modules.

**Why this priority**: Explicitly required as "MUST BE fully implemented working, tested verified and validated" - currently does not work on either module.

**Independent Test**: Can be tested by completing lessons/exercises as each user and verifying progress is recorded, persisted, and displayed correctly.

**Acceptance Scenarios**:
1. **Given** authenticated user on workshop, **When** they complete a lesson, **Then** progress is recorded and visible
2. **Given** authenticated user on ai_interviewing, **When** they complete exercise/test, **Then** progress is tracked per area/lesson
3. **Given** progress data exists, **When** user returns later, **Then** progress is restored from database
4. **Given** progress tracking, **When** running automated tests, **Then** deterministic evidence of tracking is produced

---

### User Story 5 - Extract Reusable Code as Public Submodules (Priority: P2)

**Description**: All reusable code identified across the codebase must be extracted as fully decoupled, generic, PUBLIC submodules hosted in their own repositories on both GitHub and GitLab under vasic-digital organization.

**Why this priority**: Enables true decoupling of workshop and ai_interviewing while maintaining shared code.

**Independent Test**: Each extracted submodule can be cloned independently, has its own CI/CD, and can be consumed by external projects.

**Acceptance Scenarios**:
1. **Given** identified reusable code, **When** extraction complete, **Then** each submodule has its own GitHub and GitLab repo under vasic-digital
2. **Given** new public submodules, **When** workshop and ai_interviewing reference them, **Then** they work as external dependencies
3. **Given** public submodule, **When** external user clones it, **Then** it builds and tests pass independently

---

### User Story 6 - Update All Existing Submodules (Priority: P2)

**Description**: All existing submodules must be fetched/pulled to latest main branches and verified working.

**Why this priority**: Ensures the decoupled modules use current, secure, compatible dependencies.

**Independent Test**: Each submodule at latest commit, all tests pass.

**Acceptance Scenarios**:
1. **Given** submodules in .gitmodules, **When** update executed, **Then** all at latest main branch
2. **Given** updated submodules, **When** building workshop/ai_interviewing, **Then** no version conflicts

---

### User Story 7 - Comprehensive Documentation (Priority: P2)

**Description**: All documentation extended and updated including user guides, manuals, graphs, diagrams, schemes, templates, SQL definitions.

**Why this priority**: Required for independent usability of decoupled modules.

**Independent Test**: Fresh user can follow docs to clone, install, configure, and run modules.

**Acceptance Scenarios**:
1. **Given** fresh clone of workshop, **When** user follows README, **Then** successful setup without external help
2. **Given** fresh clone of ai_interviewing, **When** user follows docs, **Then** successful setup
3. **Given** API/architecture docs, **When** developer reads them, **Then** they understand system without source diving

---

### User Story 8 - Full Test Coverage with Deterministic Evidence (Priority: P1)

**Description**: All work covered by all supported test types (per constitution), every test produces machine-verifiable deterministic evidence.

**Why this priority**: Constitution mandate - no false/faulty results, no AI slop or bluff.

**Independent Test**: Running test suite produces structured evidence artifacts that can be programmatically validated.

**Acceptance Scenarios**:
1. **Given** test suite execution, **When** tests complete, **Then** evidence artifacts generated (JSON, reports, logs)
2. **Given** evidence artifacts, **When** validated by verification scripts, **Then** all pass with zero false positives
3. **Given** any test failure, **When** evidence examined, **Then** root cause deterministically identifiable

---

## Requirements *(mandatory)*

### Functional Requirements

#### Module Decoupling
- **FR-001**: Workshop module MUST be extractable as a standalone git repository with all submodules and dependencies contained within
- **FR-002**: ai_interviewing module (user-facing name: ai_curriculum) MUST be extracted as a standalone git repository with all submodules and dependencies contained within
- **FR-003**: Both modules MUST be clonable and runnable on a machine with NO access to vasic umbrella repository
- **FR-004**: Both modules MUST have their own .gitmodules files declaring all required submodules
- **FR-005**: Both modules MUST have independent build/install/test scripts that don't reference vasic paths
- **FR-006**: Both modules MUST have independent CI/CD configuration for GitHub and GitLab

#### Authentication & Authorization
- **FR-007**: Both modules MUST have a login form as the entry point - no content accessible without authentication
- **FR-008**: Users MUST be defined in a shared/main database accessible to both modules
- **FR-009**: System MUST support two predefined users: milosvasic (password: WhiteSnake8587) and rami (password: Test12345)
- **FR-010**: On workshop module, BOTH users MUST have FULL EQUAL access to all features and data
- **FR-011**: On ai_interviewing module, user milosvasic MUST have FULL access to all features and data
- **FR-012**: On ai_interviewing module, user rami MUST NOT have access to employer information or GitHub project analysis data
- **FR-013**: On ai_interviewing module, user rami MUST have access to knowledge base: areas, lessons, tests, exercises, and progress tracking
- **FR-014**: Users MUST be able to sign out, ending their session completely
- **FR-015**: Users MUST be able to switch accounts (sign out + sign in as different user) seamlessly
- **FR-016**: Access control MUST be designed for future exhaustive refinement of permission levels
- **FR-017**: Session management MUST be secure (HttpOnly cookies, CSRF protection, secure headers)

#### Progress Tracking
- **FR-018**: Progress tracking MUST be fully implemented on workshop module (areas, lessons, tests, exercises)
- **FR-019**: Progress tracking MUST be fully implemented on ai_interviewing module (areas, lessons, tests, exercises)
- **FR-020**: Progress data MUST persist in database and survive session/restart
- **FR-021**: Progress tracking MUST produce deterministic test evidence

#### Submodule Extraction
- **FR-022**: All reusable code MUST be identified and extracted as independent public submodules
- **FR-023**: Each extracted submodule MUST have its own GitHub repository under vasic-digital organization
- **FR-024**: Each extracted submodule MUST have its own GitLab repository under vasic-digital organization
- **FR-025**: GitHub CLI (gh) and GitLab CLI (glab) MUST be used for repository creation
- **FR-026**: Extracted submodules MUST be fully generic and reusable by external projects
- **FR-027**: Workshop and ai_interviewing MUST consume extracted submodules as external dependencies
- **FR-028**: All existing submodules in .gitmodules MUST be updated to latest main branch

#### Documentation
- **FR-029**: All documentation MUST be extended and updated for both standalone modules
- **FR-030**: User guides, manuals, graphs, diagrams, schemes MUST be created/updated
- **FR-031**: Template files and SQL definitions MUST be documented
- **FR-032**: Each module MUST have complete README with clone/install/run instructions
- **FR-033**: Architecture diagrams MUST show module boundaries and data flows

#### Testing & Evidence
- **FR-034**: All work MUST be covered by all constitution-supported test types
- **FR-035**: Every test MUST produce machine-readable, deterministic evidence
- **FR-036**: Evidence MUST be programmatically verifiable without human interpretation
- **FR-037**: Zero tolerance for false positives, AI slop, or bluff in test results
- **FR-038**: Test evidence MUST be archived and traceable to specific requirements

#### Git & Deployment
- **FR-039**: All work MUST be committed and pushed to all upstreams recursively (submodules + main repo)
- **FR-040**: Both modules MUST be cloned to sibling directories outside the vasic umbrella
- **FR-041**: Both cloned modules MUST be set up, installed, tested, and validated on LIVE running instances

### Key Entities

- **User**: Authentication principal with username, password hash, roles, permissions. Two predefined: milosvasic (admin/full), rami (restricted on ai_interviewing)
- **Module**: Standalone deployable unit (workshop, ai_interviewing) with own repo, submodules, build, tests, docs
- **Submodule**: Git submodule representing reusable code, hosted independently on GitHub/GitLab under vasic-digital
- **ProgressRecord**: User's completion state for areas, lessons, tests, exercises - persisted per user per module
- **Permission**: Granular access rule mapping (user/module/resource/action) for future refinement
- **Session**: Authenticated user context with secure token, expiration, and revocation capability

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Workshop clones and runs on fresh machine (no vasic access) in < 10 minutes with single command
- **SC-002**: ai_interviewing (ai_curriculum) clones and runs on fresh machine (no vasic access) in < 10 minutes with single command
- **SC-003**: 100% of content on both modules requires authentication - zero anonymous access
- **SC-004**: User milosvasic has full access on both modules; user rami has full access on workshop, restricted access on ai_interviewing
- **SC-005**: Account switching (sign out + sign in as different user) completes in < 3 seconds
- **SC-006**: Progress tracking records and restores 100% of user actions (lessons, tests, exercises) on both modules (workshop + ai_interviewing)
- **SC-007**: All reusable code extracted into ≥ 5 public submodules under vasic-digital on both GitHub and GitLab
- **SC-008**: All 14 existing submodules updated to latest main branch with zero version conflicts
- **SC-009**: Documentation enables fresh user to clone→install→run→test each module without external help
- **SC-010**: Test suite executes in < 5 minutes per module, produces structured JSON evidence for every test
- **SC-011**: Evidence validation scripts verify 100% of test results with zero false positives
- **SC-012**: All commits pushed to all remotes (GitHub + GitLab for each submodule, GitHub for main repos)
- **SC-013**: Both modules validated on LIVE running instances (not just local) with passing health checks
- **SC-014**: Zero [NEEDS CLARIFICATION] markers remain in final specification

---

## Assumptions

- Workshop curriculum content exists in the `workshop/curriculum/` directory within the vasic umbrella and can form basis of ai_interviewing
- Database for user authentication is PostgreSQL (common choice for such systems) - can be local or shared
- Both modules are web applications (based on workshop having pipeline/platform structure)
- Constitution test types include: unit, integration, e2e, contract, performance, security, accessibility
- GitHub CLI (gh) and GitLab CLI (glab) are installed and authenticated for vasic-digital org
- vasic-digital organization exists on both GitHub and GitLab with appropriate permissions
- Existing submodules (constitution, design-toolkit, containers, LLMProvider, RAG, verdict, passage, curriculum-kit, superspec, ai_interviewing, monetization, milosvasic.ru, vasic.digital) are candidates for extraction or updating
- Progress tracking data model: User → Module → Area → Lesson → (Test|Exercise) → CompletionRecord
- "Employer information" and "GitHub project analysis" are identifiable data domains in ai_interviewing that can be RBAC-protected
- Live running instances means deployed to staging/production environments accessible via HTTP(S)
- Machine-readable evidence format: JSON with schema, including test name, status, duration, assertions, artifacts

---

## Clarifications Needed

**RESOLVED**:

1. **Technology Stack**: Already defined in existing codebases — workshop, ai_interviewing (formerly ai_curriculum), constitution, and all submodules/* declare their own stacks. Implementation must use each module's native stack.
2. **ai_curriculum Identity**: **ai_curriculum = ai_interviewing** — it already exists as a submodule at `ai_interviewing/` (GitHub: milos85vasic/ai_interviewing). The name "ai_curriculum" was a user alias.
3. **LIVE Running Instances**: Locally running containerized services using the `containers` submodule (`vasic-digital/containers`) with Podman/Docker runners — NOT cloud deployment. Validation runs against local container instances.