# Feature Specification: Decouple Modules, Add Authentication & Extract Reusables

> **SUPERSEDED 2026-09-15** by [specs/008-unified-workshop-platform/spec.md](../008-unified-workshop-platform/spec.md) — this document is preserved for historical/traceability reasons; the unified spec is the active source of truth.

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

### Edge Cases

This spec previously carried zero recorded edge cases. The list below is the result of a
2026-09-15 brainstorm pass, weighted toward the security/authentication boundary because it is
the only boundary of this kind in the spec family. Each entry is resolved with a stated reason
where the resolution is a safe technical default; where it is a genuine business/product
decision, it is deferred to "Open Questions" below instead.

- **Plaintext credentials are committed in this public specification (FR-009).** `milosvasic`/`WhiteSnake8587` and `rami`/`Test12345` are recorded in this repository's git history, and this repository is PUBLIC. They MUST be treated as compromised from the moment of commit: the system MUST NOT rely on these literal values as real production secrets, MUST store only salted password hashes, and MUST NEVER re-print a plaintext password anywhere (log, error, doc). Whether the actually-deployed passwords are rotated to different values is an operator decision — see Open Questions.
- **The "main database" of users (FR-008) is itself a new cross-module dependency.** If workshop reaches standalone status before ai_interviewing does, a database shared with the still-coupled ai_interviewing would silently re-couple the two "independent" modules, violating FR-003's "no access to vasic umbrella" requirement for whichever module is decoupled first. Resolved: the shared user store MUST be its own described, independently-provisionable component (bundled with each module or run as a documented external dependency) — it MUST NOT be "the vasic umbrella's database" by default.
- **A session/token minted by one module is replayed against the other.** Because workshop and ai_interviewing read the same user table, proving "this is milosvasic" is not sufficient — the token must also prove "for this module," or a rami session obtained on workshop could be replayed on ai_interviewing to reach data FR-012 denies. Resolved: tokens MUST be audience-scoped per module and rejected by the other module even though both modules trust the same user store.
- **The auth provider/database is unreachable at request time.** Resolved: fail closed — access is denied, never silently granted, during an outage. An availability failure must never become an accidental all-access window.
- **A malformed or expired token is presented.** Resolved: rejected outright, user redirected to login. It MUST NOT be treated as an anonymous/limited-access request — that would let a token-parsing bug violate FR-007's "no content accessible without authentication" by accident rather than by design.
- **A module fails to decouple cleanly, leaving a partially-extracted state** (e.g. new `.gitmodules` entries added but old in-tree code not yet removed, or the reverse). Resolved: the umbrella-hosted copy remains the operative one until the standalone clone independently passes install + full test suite on its own; a module is never left with no fully-working copy of itself.
- **A reusable-code extraction ships before every consumer is updated.** Resolved: extraction is additive-then-cutover, not delete-then-hope — the old in-tree path keeps working until each consumer (workshop, ai_interviewing) is confirmed migrated and re-tested against the extracted version.
- **Extracted "reusable" code actually carries private content.** Workshop and ai_interviewing sit adjacent to and reference PRIVATE material (curriculum content, "employer information"). A generic-looking utility pulled out for a new PUBLIC vasic-digital submodule could still embed private strings, names, or paths — this repository's own recorded content-boundary incident (`docs/content-boundary-incident-2026-09-01.md`) is the concrete precedent for exactly this failure. Resolved: every extraction MUST pass a content-boundary review (the same class of check as `scripts/verify-content-boundary.sh`) confirming zero private data before the public repository is created or pushed.
- **Rami's zero-access domains are inferred rather than enumerated.** "Employer information" and "GitHub project analysis" (FR-012) are named informally, not as a closed list of tables/fields/routes; an implementer could miss a path that also carries this data. Resolved: default-deny for rami on ai_interviewing — anything not explicitly on the FR-013 allow-list (areas, lessons, tests, exercises, progress) is denied by default, never allowed until proven sensitive.
- **First-ever login / bootstrap of the two seed users.** Creating the milosvasic and rami accounts is itself a privileged action. Resolved: it MUST happen through a controlled, non-network-exposed bootstrap step (seed script / migration run by an operator), never through a self-registration endpoint reachable from the same login page.
- **Many concurrent login attempts against the same account.** Resolved: rate-limited/throttled per account and per source. With only two usernames, both already public in this spec's own history, brute-force risk here is elevated rather than theoretical.
- **A session predating the authentication rollout survives the cutover.** Resolved: invalidated at cutover. A cookie or session issued before secure session handling (FR-017) was enforced MUST NOT be grandfathered into "already authenticated."
- **A user exists in zero roles or groups.** Resolved: falls back to zero access — never to admin-equivalent, and never to whatever the previous session on that browser happened to grant.
- **A screen-reader or keyboard-only user hits an auth error** (wrong password, locked account, expired session). Resolved: errors MUST be announced and every control keyboard-reachable, matching the WCAG 2.1 AA floor this spec family already set in specs/001.
- **An auth failure message reveals whether an account exists.** Resolved: the message is generic ("invalid username or password"), never "unknown user" vs. "wrong password" — a standard enumeration-prevention default.
- **A health-check/readiness probe is gated behind login.** Would break "passing health checks" (SC-013) for automated validation. Resolved: health/readiness endpoints MAY be exempt from authentication, but MUST NOT return content or user data of any kind.

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

#### Security & Privacy (added 2026-09-15 brainstorm pass)

- **FR-042**: Passwords MUST be stored only as salted cryptographic hashes (e.g. Argon2id or bcrypt) — never in plaintext, never in a reversible form
- **FR-043**: Any plaintext credential value that has appeared in documentation, a spec, or commit history (including FR-009's example values) MUST be treated as compromised; production deployments MUST NOT rely on those literal values as real secrets
- **FR-044**: Tokens, session identifiers, and passwords MUST NEVER be written to logs, error output, crash reports, or included in a URL/query string
- **FR-045**: A session identifier MUST be regenerated at successful login; a pre-authentication session id MUST NOT become the authenticated session id (session-fixation protection)
- **FR-046**: Authentication/session tokens MUST be scoped to a single module (audience-restricted); a token issued for workshop MUST be rejected by ai_interviewing and vice versa, even though both read the shared user store
- **FR-047**: On auth-provider or user-database unavailability, both modules MUST fail closed (deny access) rather than fail open (grant access)
- **FR-048**: Failed login attempts MUST be rate-limited/throttled per account and per source to mitigate brute-force and credential-stuffing attempts
- **FR-049**: Authentication failure messages MUST be generic and MUST NOT disclose whether a given username exists
- **FR-050**: Health-check/readiness endpoints MAY be exempt from authentication but MUST NOT expose content or user data
- **FR-051**: Extraction of code from a currently-PRIVATE module (workshop, ai_interviewing) into a new PUBLIC submodule MUST pass a content-boundary review confirming zero private data before the public repository is created or pushed
- **FR-052**: A module MUST NOT be decommissioned from its current umbrella-hosted location until its standalone clone independently passes install and the full test suite; no module may be left with no fully-working copy
- **FR-053**: A reusable-code extraction MUST preserve a working path for existing consumers (workshop, ai_interviewing) until each is confirmed migrated and re-tested against the extracted version — extraction is additive-then-cutover, not delete-then-hope
- **FR-054**: A user record with no assigned role or permission MUST default to zero access (fail closed), never to admin-equivalent or inherited access
- **FR-055**: Any session or cookie issued before secure session handling (FR-017) was enforced MUST be invalidated at the authentication-rollout cutover

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

### Session 2026-09-15 — Edge-case brainstorm and resolution

This spec had zero recorded edge cases and zero open questions before this session. A structured
scan across five categories (boundary conditions, error scenarios, scale & performance, security &
privacy, user experience) was run, weighted toward security & privacy because this is the only
spec in the family with an authentication/authorization boundary. 16 edge cases were identified and
resolved into the "Edge Cases" section above, 14 new Functional Requirements (FR-042–FR-055) were
added, and 6 items that are genuine business/product decisions — not technical safety defaults —
were left unresolved for the operator in "Open Questions" below, per the operator's standing
instruction to resolve only what has a safe, conservative, standard-practice default and to defer
what does not.

Representative resolutions (full list is the Edge Cases section):

- Q: What happens if the auth provider or user database is unreachable? → A: Fail closed — deny access, never grant it, during an outage.
  *Why*: an availability failure must never silently become an all-access window; this is the standard secure default and reverses the failure mode of the classic "auth service down, app defaults to letting everyone in" defect class.
- Q: Can a session/token issued by one decoupled module be used against the other? → A: No — tokens MUST be scoped (audience-restricted) per module.
  *Why*: workshop and ai_interviewing are required to read the same "main database" of users (FR-008) but enforce different access rules; without per-module scoping, a rami token obtained on workshop (full access) could be replayed on ai_interviewing to reach the employer/GitHub-analysis data FR-012 explicitly denies her — a direct privilege-escalation path created by the decoupling itself.
- Q: How are passwords stored? → A: Salted cryptographic hashes only (Argon2id/bcrypt); never plaintext, never reversible; never printed, logged, or echoed.
  *Why*: this is a direct restatement of this repository's own governing rule ("Credentials never tracked... Never commit, print, log or echo a credential") applied to the one place in this spec family where real credentials are actually handled.
- Q: FR-009 embeds two real-looking plaintext passwords directly in this public spec file — what does that mean for those values? → A: They MUST be treated as already compromised (this file is public and the values are now in git history); production MUST NOT rely on them as real secrets.
  *Why*: this is the highest-severity finding of the pass. It is resolved only to the extent of stating the safe default (treat as compromised, hash everything, never re-print); whether the actual deployed passwords are rotated is an operator decision — see Open Questions.
- Q: Should code extracted from a currently-private module (workshop, ai_interviewing) into a new public vasic-digital submodule (User Story 5) be reviewed before the public repository is created? → A: Yes — a content-boundary review MUST pass first (FR-051).
  *Why*: this repository has an on-the-record incident (`docs/content-boundary-incident-2026-09-01.md`) of exactly this failure mode — private material crossing into a public repository during what looked like routine extraction/reuse work. The same risk applies directly to User Story 5 of this spec.
- Q: What happens to a session created before the login form existed? → A: Invalidated at the authentication-rollout cutover; never grandfathered in.
  *Why*: "Make sure we cannot access any content if users do not sign in" (spec Input) is a stated hard requirement; a surviving pre-rollout session would violate it silently.
- Q: Does a login-error message confirm whether a username exists? → A: No — always a generic "invalid username or password."
  *Why*: standard username-enumeration prevention; low cost, no functional downside, and directly relevant given only two usernames exist and are already public.

---

## Open Questions

These are genuine business/product decisions, not technical safety defaults, and are intentionally
**not** resolved here. Each needs an explicit operator answer before or during implementation.

| # | Question | Why it can't be resolved as a safe default |
|---|---|---|
| OQ-1 | Should the standalone `ai_interviewing` (ai_curriculum) repository be made **PUBLIC** (to satisfy FR-003's "clonable by a user with no access to vasic umbrella") or remain **PRIVATE** with invited/credentialed access, given it holds "employer information" that user rami is explicitly denied (FR-012)? | FR-003 and FR-012 pull in opposite directions and only the operator can decide which one bends — this is a visibility/business decision about real private content, not a technical default. |
| OQ-2 | Is the "main database" of users (FR-008) genuinely **shared** across both standalone modules (requiring a new, independently-hosted shared component once neither module has vasic-umbrella access), or does each decoupled module get its **own copy** of the user table? | Both readings satisfy the literal spec text; the choice changes the architecture (a new shared service vs. two independent stores kept in sync) and is a product decision about how tightly the two "independent" modules are allowed to stay coupled. |
| OQ-3 | What are the concrete session/token lifetime, idle-timeout, and "remember me" policies? | This spec resolves the *direction* (short-lived over long-lived, FR-045/046) as a safe default, but the actual numeric values are a product/UX trade-off between security and convenience that only the operator can set. |
| OQ-4 | Which authentication mechanism is used — self-hosted password auth, or an external identity provider (OAuth/OIDC)? Does the answer differ between workshop (equal-access) and ai_interviewing (RBAC)? | The Assumptions section defers technology choice to "each module's native stack" but names no auth library or provider; this is a real build-vs-integrate decision with cost and maintenance implications. |
| OQ-5 | Should the two already-committed example passwords (`WhiteSnake8587`, `Test12345`) be **rotated to different real values** before go-live, given they are now permanently recorded in this PUBLIC repository's git history? | Rotating a credential that may already be in use, or choosing to keep these as intentionally-throwaway seed values, is an operator call — this pass can only flag that treating them as compromised is the safe default (see FR-043), not decide the rotation itself. |
| OQ-6 | Is multi-factor authentication required for either or both users at launch, or only planned for the "future exhaustive refinement of permission levels" already anticipated by FR-016? | This is a scope/timeline decision about how much security investment ships now versus later, not a technical default that has one obviously-safe answer. |