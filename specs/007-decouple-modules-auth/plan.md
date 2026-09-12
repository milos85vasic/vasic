# Implementation Plan: Decouple Modules, Add Authentication & Extract Reusables

**Branch**: `007-decouple-modules-auth` | **Date**: 2026-09-12 | **Spec**: specs/007-decouple-modules-auth/spec.md
**Input**: Feature specification from `specs/007-decouple-modules-auth/spec.md`

## Summary

This feature decouples two modules (workshop and ai_interviewing) from the vasic umbrella into fully independent, standalone projects. Each module must be clonable, installable, and runnable without access to the vasic repository. The plan adds authentication with role-based access control (two predefined users: milosvasic/full access, rami/restricted on ai_interviewing), implements progress tracking (areas, lessons, tests, exercises), extracts reusable code as public submodules under vasic-digital on GitHub and GitLab, updates all existing submodules to latest main, extends documentation, and ensures full test coverage with deterministic evidence. Validation runs against locally containerized services using the containers submodule with Podman/Docker.

## Technical Context

**Language/Version**: 
- Workshop: Go 1.22+ (backend), Angular 18+ / TypeScript 5.x (frontend)
- ai_interviewing: Go 1.22+ (backend), Angular 18+ / TypeScript 5.x (frontend)
- containers submodule: Go 1.22+
- Constitution: Go 1.22+ (for tooling)

**Primary Dependencies**:
- Workshop backend: sqlite3 (modernc.org/sqlite), chi router, testify, go-faker, ollama client
- Workshop frontend: @angular/core, @angular/material, rxjs, zone.js
- ai_interviewing backend: sqlite3 (modernc.org/sqlite), chi router, golang-jwt, bcrypt, testify
- ai_interviewing frontend: @angular/core, @angular/material, rxjs, zone.js
- containers: cobra, testify, docker/client, gnupg
- Test tooling: Playwright (chromium), go test, ng test, ng e2e

**Storage**: 
- Workshop: SQLite with FTS5 (embedded in Go binary, file at `/opt/workshop/run/server.json` state + chapters mount)
- ai_interviewing: SQLite (file at `data/curriculum.db`)
- Auth: PostgreSQL (shared database for user management across both modules)

**Testing**: 
- Go: `go test ./...` with testify, mutation testing via go-mutesting
- Angular: `ng test` (Karma/Jasmine), `ng e2e` (Playwright/Chromium)
- E2E: Playwright against live container instances
- Constitution: All supported test types (unit, integration, e2e, contract, performance, security, accessibility)

**Target Platform**: Linux server (containerized via Podman/Docker using containers submodule), local development

**Project Type**: Two independent web-services (workshop, ai_interviewing) with shared auth database, plus reusable public submodules

**Performance Goals**: 
- Clone-to-run < 10 minutes per module (SC-001, SC-002)
- Account switching < 3 seconds (SC-005)
- Test suite < 5 minutes per module (SC-010)
- 100% content requires authentication (SC-003)

**Constraints**: 
- Per-module native tech stacks (no unified stack)
- Must use containers submodule for containerization (Podman/Docker)
- Must use gh/glab CLIs for submodule creation under vasic-digital
- All submodules must be at latest main branch
- No content accessible without authentication
- Progress tracking must persist in database
- All tests must produce deterministic, machine-verifiable evidence
- No false positives, AI slop, or bluff allowed

## Constitution Check

*GATE: Must pass before proceeding. Re-check after design phase.*

| Principle | Status | Notes |
|-----------|--------|-------|
| §1 Test coverage mandatory for every change | PASS | Plan includes all test types per constitution; each FR mapped to acceptance scenarios |
| §1.1 False-positive immunity | PASS | Each test type requires mutation pairing; evidence must be positive (not absence-of-error) |
| §2 Commit/push mechanics single entrypoint | PASS | Will use project commit wrapper; multi-upstream push to GitHub + GitLab |
| §3 Submodule changes propagate through submodule commits first | PASS | Submodule extraction will commit in submodule first, then update parent pointers |
| §4 Every tag mirrored on owned submodules | PASS | Tagging strategy includes all owned submodules |
| §5 Changelog discipline multi-format export | PASS | Will generate changelogs for each module and submodule |
| §6 Documentation up to nano-details | PASS | Documentation user stories (US-7) require complete docs for standalone use |
| §7 Making false-success impossible | PASS | All tests require real action, state delta, positive evidence, unique tokens |
| §7.1 NO BLUFF | PASS | Test evidence must be positive (value match, state delta, captured analysis) |
| §8 Bleeding-edge ultra-perfection quality bar | PASS | Zero tolerance for false results; deterministic evidence required |
| §9 Absolute codebase/data safety | PASS | Hardlinked backup before destructive ops; no force-push without authorization |
| §10 Enforcement | PASS | Gates will enforce all principles |
| §11.4.1 FAIL-bluffs forbidden | PASS | Test design requires FAIL on mutation |
| §11.4.2 Recorded evidence requirement | PASS | All tests produce structured JSON evidence |
| §11.4.3 Per-environment test dispatch | PASS | Tests run against local container instances (per-environment topology) |
| §11.4.4 Test interrupt on discovery | PASS | CI will interrupt on first failure, retest from clean baseline |
| §11.4.5 Captured evidence quality analysis | PASS | Evidence validated by verification scripts |
| §11.4.6 No guessing mandate | PASS | All decisions documented with rationale; no "likely/probably" |
| §11.4.7 Demotion evidence rule | PASS | Downgraded tests require evidence |
| §11.4.8 Deep web research before implementation | PASS | Research phase (Phase 0) will resolve all unknowns |
| §11.4.9 Batch source fixes before rebuild | PASS | Fixes batched before rebuild |
| §11.4.10 Credentials handling | PASS | Database passwords via env vars; no secrets in repo |
| §11.4.11 File layout discipline | PASS | Each module follows its own structure |
| §11.4.12 Auto-generated docs sync | PASS | Docs generated from source |
| §11.4.13 Out-of-band sink-side evidence | PASS | Playwright captures screenshots/video as out-of-band evidence |
| §11.4.14 Test playback cleanup | PASS | Artifacts cleaned after validation |
| §11.4.15 Item status tracking | PASS | Tasks tracked with status |
| §11.4.16 Item type tracking | PASS | Tasks typed (TDD, SUBAGENT, REVIEW) |
| §11.4.17 Universal vs project classification | PASS | Project-specific rules extend, never weaken constitution |
| §11.4.18 Script documentation mandate | PASS | All scripts documented with purpose, args, env vars |
| §11.4.19 Fixed-document column alignment | PASS | Tables aligned in markdown |
| §11.4.20 Subagent-driven by default | PASS | Parallel work streams use subagents |
| §11.4.21 Operator-blocked status | PASS | Human checkpoints defined |
| §11.4.22 Document sync commit discipline | PASS | Docs updated in same commit as code |
| §11.4.23 Visual cue grouping for Issues | PASS | Not applicable to this feature |
| §11.4.24 Build resource stats tracking | PASS | Build times recorded |
| §11.4.25 Full automation coverage | PASS | All work automated |
| §11.4.26 Constitution submodule update workflow | PASS | Constitution at latest main |
| §11.4.27 No fakes beyond unit tests + 100% test type coverage | PASS | All test types covered |
| §11.4.28 Submodules as equal codebase + decoupling | PASS | Core requirement of this feature |
| §11.4.29 Lowercase snake_case naming | PASS | All new identifiers follow convention |
| §11.4.30 .gitignore + no versioned build artifacts | PASS | Build artifacts gitignored |
| §11.4.31 Submodule dependency manifest | PASS | helix-deps.yaml maintained |
| §11.4.32 Post-constitution pull validation | PASS | Verification gates run |
| §11.4.33 Type-aware closure status vocabulary | PASS | Task statuses typed |
| §11.4.34 Reopened source attribution | PASS | Reopened work attributed |
| §11.4.35 Canonical root inheritance clarity | PASS | Carrier files in sync |
| §11.4.36 Mandatory install_upstreams on clone/add | PASS | Submodules have upstreams |
| §11.4.37 Fetch before edit | PASS | Submodules fetched before changes |
| §11.4.38 Installable asset evidence | PASS | Build artifacts verified |
| §11.4.39 Per-feature on-device end-user validation | PASS | Validation against live containers |
| §11.4.40 Full suite retest before release tag | PASS | Full test suite required |
| §11.4.41 Pre-force-push merge first | PASS | Merge before push |
| §11.4.42 Iteration discipline | PASS | Phased approach |
| §11.4.43 TDD fix discipline | PASS | TDD marked for complex areas |
| §11.4.44 Document revision header | PASS | Docs have revision headers |
| §11.4.45 Integration status doc maintenance | PASS | Integration status tracked |
| §11.4.46 Validate recent work before post-flash tests | PASS | Pre-validation gates |
| §11.4.47 Firebase data review | N/A | Not applicable |
| §11.4.48 UI-driven video testing | PASS | Playwright records video |
| §11.4.49 Dual approach testing | PASS | Multiple test types per feature |
| §11.4.50 Deterministic consistency | PASS | Deterministic evidence required |
| §11.4.51 Live ADB first maximization | N/A | Not applicable |
| §11.4.52 Autonomous validation | PASS | Self-validating test suite |
| §11.4.53 Fixed summary parity | PASS | Summary evidence matches |
| §11.4.54 ATM-NNN ticket identifier | N/A | Not applicable |
| §11.4.55 Reopens history tracking | PASS | Reopens tracked |
| §11.4.56 Status summary parity + two-audience | PASS | Technical + business summaries |
| §11.4.57 README doc-link section + revision metadata | PASS | READMEs updated |
| §11.4.58 Parallel development methodology | PASS | SUBAGENT work streams |
| §11.4.59 README always sync | PASS | READMEs updated with code |
| §11.4.60 Documentation always sync composite covenant | PASS | Docs in sync |
| §11.4.61 Mandatory markdown metadata table + structured ToC | PASS | Spec has ToC |
| §11.4.63 Workable items procedure docs as single source | PASS | Tasks reference spec |
| §11.4.65 Universal Markdown export | PASS | Markdown exports generated |
| §11.4.66 Blocker resolution interactive clarification | PASS | Clarification phase completed |
| §12 Host session safety | PASS | No sign-out of user's session |
| §12.1 Forbidden operations | PASS | No host session manipulation |
| §12.2 Required safeguards | PASS | Safeguards in place |
| §12.3 Container hygiene | PASS | Clean container practices |
| §12.6 Memory budget ceiling 60% | PASS | Resource limits set |
| §12.10 Continuation document sacred invariant | PASS | CONTINUATION.md maintained |

## Project Structure

### Documentation (this feature)

```text
specs/007-decouple-modules-auth/
├── spec.md              # Feature specification
├── plan.md              # This file
├── research.md          # Research findings (Phase 0 output)
├── data-model.md        # Entity definitions (Phase 1 output)
├── contracts/           # Interface contracts (Phase 1 output)
│   ├── auth-api.md      # Authentication API contract
│   ├── progress-api.md  # Progress tracking API contract
│   └── submodule-api.md # Submodule consumption contract
├── quickstart.md        # Validation guide (Phase 1 output)
├── tasks.md             # Task breakdown (/speckit.superspec.tasks output)
└── checklists/
    └── requirements.md  # Quality checklist
```

### Source Code (repository root - both modules)

```text
# Workshop (standalone repo after extraction)
workshop/
├── platform/
│   ├── backend/         # Go backend (cmd/server, internal/, pkg/)
│   │   ├── cmd/
│   │   ├── internal/
│   │   ├── pkg/
│   │   ├── go.mod
│   │   └── go.sum
│   ├── frontend/        # Angular frontend
│   │   ├── src/
│   │   ├── e2e/
│   │   ├── angular.json
│   │   ├── package.json
│   │   └── playwright.config.ts
│   ├── orchestration/   # Container orchestration (containers submodule)
│   ├── compose.yml      # Container stack definition
│   ├── scripts/         # Build/start/stop/ingest scripts
│   └── .gitmodules      # Submodule declarations
├── curriculum/          # Content (chapters, lessons, exercises)
├── chapters/            # Chapter content
├── pipeline/            # Data processing pipeline
├── docs/                # Documentation
├── .github/             # CI/CD workflows
├── .gitlab/             # GitLab CI/CD
├── helix-deps.yaml      # Submodule dependency manifest
├── README.md
└── Makefile / build scripts

# ai_interviewing (standalone repo after extraction)
ai_interviewing/
├── platform/
│   ├── backend/         # Go backend (cmd/server, internal/)
│   │   ├── cmd/
│   │   └── internal/
│   ├── frontend/        # Angular frontend
│   │   ├── src/
│   │   └── angular.json
│   ├── scripts/         # Build/start/stop/ingest scripts (_common.sh, build.sh, start.sh, stop.sh, status.sh, ingest.sh)
│   └── .gitmodules      # Submodule declarations
├── content/             # MCQ, short answers, plans
├── docs/                # Documentation corpus
├── data/                # SQLite DB, assets, certs
├── .github/             # CI/CD workflows
├── .gitlab/             # GitLab CI/CD
├── helix-deps.yaml      # Submodule dependency manifest
├── README.md
└── build scripts

# Extracted Public Submodules (under vasic-digital org)
submodules/
├── containers/          # Already exists - ensure public on both GitHub/GitLab
├── LLMProvider/         # Already exists - ensure public
├── RAG/                 # Already exists - ensure public
├── verdict/             # Already exists - ensure public
├── passage/             # Already exists - ensure public
├── curriculum-kit/      # Already exists - ensure public
├── design-toolkit/      # Already exists - ensure public (already public)
└── [newly-extracted]/   # Newly identified reusable code
```

**Structure Decision**: Each module maintains its existing internal structure (Go backend + Angular frontend + scripts). The extraction creates independent git repos with their own `.gitmodules`, `helix-deps.yaml`, CI/CD configs, and documentation. Public submodules are extracted to vasic-digital organization with dual GitHub/GitLab hosting.

## Execution Strategy

### TDD Requirements

| Component/Module | TDD Required | Rationale |
|-----------------|--------------|-----------|
| Authentication (login, session, RBAC) | ✅ [TDD] | Security-critical; complex edge cases (brute force, session fixation, privilege escalation) |
| Progress tracking (CRUD, persistence) | ✅ [TDD] | Data integrity critical; many state transitions |
| RBAC permission checks | ✅ [TDD] | Authorization logic must be bulletproof |
| Submodule extraction scripts | ❌ | One-time migration; verified by post-extraction tests |
| Documentation generation | ❌ | Verified by human review + link checks |
| Container orchestration | ✅ [TDD] | Infrastructure as code; failures affect all modules |

### Parallel Execution Opportunities

| Work Stream | Independence | Prerequisites |
|-------------|--------------|---------------|
| Workshop decoupling (git, .gitmodules, CI/CD) | ✅ Independent | None |
| ai_interviewing decoupling (git, .gitmodules, CI/CD) | ✅ Independent | None |
| Auth database schema + migrations | ⚠️ Shared | Required by both auth implementations |
| Workshop auth implementation | ⚠️ Depends | Auth DB schema |
| ai_interviewing auth implementation | ⚠️ Depends | Auth DB schema |
| Workshop progress tracking | ⚠️ Depends | Auth (user context) |
| ai_interviewing progress tracking | ⚠️ Depends | Auth (user context) |
| Submodule extraction (multiple) | ✅ Independent | Code identification complete |
| Submodule GitHub/GitLab repo creation | ✅ Independent | Extraction complete |
| Documentation (both modules) | ✅ Independent | Code complete |
| Test suite enhancement (both) | ⚠️ Depends | Features implemented |
| Container validation (both) | ⚠️ Depends | Containers submodule ready |

### Human Checkpoints

1. **After foundational setup** — Verify both modules have correct `.gitmodules`, `helix-deps.yaml`, CI/CD configs, and build independently
2. **After auth database schema** — Review migration scripts and schema design before applying
3. **After auth implementation (each module)** — Verify login, RBAC, session management, account switching against acceptance scenarios
4. **After progress tracking (each module)** — Verify CRUD, persistence, and user isolation
5. **After submodule extraction** — Verify each extracted submodule builds/tests independently and is published to both GitHub/GitLab
6. **After all stories** — Run full test suites (unit, integration, e2e, contract, perf, security, a11y) on both modules
7. **Before merge** — Final review against spec; all evidence validated; CONTINUATION.md updated

### Review Gates

| Area | Gate Type | Required Reviewers |
|------|-----------|-------------------|
| Auth database schema & migrations | [REVIEW] | Security + DBA |
| Authentication implementation (login, JWT, sessions) | [REVIEW] | Security |
| RBAC permission matrix | [REVIEW] | Security + Product |
| Progress tracking data model | [REVIEW] | Backend lead |
| Submodule extraction boundaries | [REVIEW] | Architecture |
| Container orchestration configs | [REVIEW] | DevOps |
| Test evidence validation scripts | [REVIEW] | QA |

## Complexity Tracking

> No Constitution Check violations — all principles respected by design.

## Phase 0: Research (Complete)

All clarifications resolved during `/speckit.clarify`:

| Unknown | Decision | Rationale |
|---------|----------|-----------|
| Technology stack | Per-module native (Go + Angular) | Both modules already use Go/Angular; no unification needed |
| ai_curriculum identity | ai_curriculum = ai_interviewing | Existing submodule at `ai_interviewing/` |
| LIVE running instances | Local containers via containers submodule + Podman/Docker | User confirmed; no cloud deployment needed |

## Phase 1: Design & Contracts

### Data Model (`data-model.md`)

**User**
- `id` (UUID, PK)
- `username` (string, unique, not null) — "milosvasic", "rami"
- `password_hash` (string, not null) — bcrypt/argon2
- `role` (enum: admin, user) — admin for milosvasic, user for rami
- `created_at` (timestamp)
- `updated_at` (timestamp)
- `last_login` (timestamp, nullable)

**Module**
- `id` (UUID, PK)
- `name` (string, unique, not null) — "workshop", "ai_interviewing"
- `display_name` (string)
- `description` (text)
- `created_at` (timestamp)

**Permission**
- `id` (UUID, PK)
- `module_id` (FK → Module)
- `resource` (string) — e.g., "employer_data", "github_analysis", "knowledge_base", "progress"
- `action` (string) — "read", "write", "delete"
- `role` (enum: admin, user) — which role has this permission

**ProgressRecord**
- `id` (UUID, PK)
- `user_id` (FK → User)
- `module_id` (FK → Module)
- `area_id` (string)
- `lesson_id` (string)
- `item_type` (enum: "lesson", "test", "exercise")
- `item_id` (string)
- `completed` (boolean)
- `score` (integer, nullable) — for tests
- `completed_at` (timestamp, nullable)
- `created_at` (timestamp)
- `updated_at` (timestamp)

**Session**
- `id` (UUID, PK)
- `user_id` (FK → User)
- `token` (string, unique, not null) — secure random
- `expires_at` (timestamp)
- `created_at` (timestamp)
- `revoked_at` (timestamp, nullable)
- `ip_address` (string, nullable)
- `user_agent` (string, nullable)

### Contracts

**Authentication API** (`contracts/auth-api.md`)
- `POST /api/auth/login` — `{username, password}` → `{token, user, expires_at}`
- `POST /api/auth/logout` — `{token}` → `{success}`
- `POST /api/auth/refresh` — `{token}` → `{token, expires_at}`
- `GET /api/auth/me` — `{token}` → `{user, permissions}`
- `POST /api/auth/switch` — `{username, password}` → `{token, user, expires_at}`

**Progress Tracking API** (`contracts/progress-api.md`)
- `GET /api/progress` — `{token}` → `{records[]}` — user's progress in current module
- `GET /api/progress/:areaId/:lessonId` — `{token}` → `{record}`
- `POST /api/progress` — `{token, area_id, lesson_id, item_type, item_id, completed, score?}` → `{record}`
- `PUT /api/progress/:id` — `{token, completed?, score?}` → `{record}`
- `GET /api/progress/summary` — `{token}` → `{area: {lesson: {completed, total, score_avg}}}`

**Submodule Consumption** (`contracts/submodule-api.md`)
- Each module declares dependencies in `helix-deps.yaml`
- Submodules consumed via Go modules (replace directives for local) or git submodules
- Version pinning via git tags
- CI/CD validates submodule compatibility

### Quickstart Validation Guide (`quickstart.md`)

**Prerequisites:**
- Linux with Podman 4+ or Docker 24+
- Go 1.22+, Node 20+, npm 10+
- gh CLI authenticated to vasic-digital org
- glab CLI authenticated to vasic-digital org
- PostgreSQL 15+ (local or container)

**Validation Scenarios:**

1. **Workshop Standalone Clone & Run**
   ```bash
   git clone git@github.com:milos85vasic/workshop_curriculum.git /tmp/workshop-test
   cd /tmp/workshop-test
   git submodule update --init --recursive
   bash platform/scripts/build.sh
   bash platform/scripts/start.sh
   # Verify: curl http://localhost:8087/api/health
   # Verify: Playwright tests pass
   ```

2. **ai_interviewing Standalone Clone & Run**
   ```bash
   git clone git@github.com:milos85vasic/ai_interviewing.git /tmp/ai_interviewing-test
   cd /tmp/ai_interviewing-test
   git submodule update --init --recursive
   bash platform/scripts/build.sh
   bash platform/scripts/ingest.sh
   bash platform/scripts/start.sh
   # Verify: curl http://localhost:8099/api/health
   # Verify: Playwright tests pass
   ```

3. **Authentication Flow**
   ```bash
   # Login as milosvasic
   curl -X POST http://localhost:8087/api/auth/login -d '{"username":"milosvasic","password":"WhiteSnake8587"}'
   # Verify: token returned, can access all endpoints
   # Login as rami
   curl -X POST http://localhost:8087/api/auth/login -d '{"username":"rami","password":"Test12345"}'
   # Verify: token returned, full access on workshop
   # On ai_interviewing: rami denied employer_data, github_analysis; allowed knowledge_base, progress
   ```

4. **Progress Tracking**
   ```bash
   # As authenticated user
   curl -X POST http://localhost:8087/api/progress -H "Authorization: Bearer $TOKEN" \
     -d '{"area_id":"intro","lesson_id":"lesson1","item_type":"lesson","item_id":"1","completed":true}'
   # Verify: record created, visible in GET /api/progress
   # Restart server, verify progress persists
   ```

5. **Account Switching**
   ```bash
   # Logout
   curl -X POST http://localhost:8087/api/auth/logout -H "Authorization: Bearer $TOKEN"
   # Login as different user
   curl -X POST http://localhost:8087/api/auth/login -d '{"username":"rami","password":"Test12345"}'
   # Verify: new token, new permissions
   ```

6. **Submodule Extraction Validation**
   ```bash
   # For each extracted submodule
   git clone git@github.com:vasic-digital/<submodule>.git /tmp/<submodule>-test
   cd /tmp/<submodule>-test
   go test ./...  # or npm test
   # Verify: all tests pass, evidence produced
   ```

7. **Full Test Suite**
   ```bash
   # In each module
   go test ./... -v -json > test-evidence.json
   ng test --watch=false --code-coverage
   ng e2e --configuration=production
   # Verify: evidence validation script passes
   bash scripts/validate-evidence.sh test-evidence.json
   ```

**Expected Outcomes:**
- All acceptance scenarios from spec.md pass
- Evidence validation scripts report 100% pass
- Zero false positives in test results
- CONTINUATION.md updated with completion status