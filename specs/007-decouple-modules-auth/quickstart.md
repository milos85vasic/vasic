# Quickstart Validation Guide

**Feature**: specs/007-decouple-modules-auth
**Version**: 1.0
**Generated**: 2026-09-12
**Source**: Plan.md Phase 1 Design

---

## Prerequisites

### System Requirements
- **OS**: Linux (tested on Ubuntu 22.04+, Arch, Fedora)
- **Container Runtime**: Podman 4.0+ (preferred) or Docker 24.0+
- **Go**: 1.22+ (via `go install` or package manager)
- **Node.js**: 20.x LTS (via nvm/fnm or package manager)
- **npm**: 10.x (bundled with Node 20)
- **PostgreSQL**: 15+ (local or containerized)
- **gh CLI**: 2.40+ (authenticated to `vasic-digital` org)
- **glab CLI**: 1.35+ (authenticated to `vasic-digital` org)
- **git**: 2.40+ with submodule support

### Authentication Setup
```bash
# GitHub
gh auth login --git-protocol ssh --hostname github.com
gh auth status  # Verify vasic-digital org access

# GitLab
glab auth login --hostname gitlab.com
glab auth status  # Verify vasic-digital org access
```

### Clone Locations
```bash
export PROJECTS_DIR="$HOME/Projects"
mkdir -p "$PROJECTS_DIR"
```

---

## Validation Scenarios

### 1. Workshop Standalone Validation

```bash
# Clone
cd "$PROJECTS_DIR"
git clone git@github.com:milos85vasic/workshop_curriculum.git workshop-standalone
cd workshop-standalone

# Initialize submodules
git submodule update --init --recursive

# Verify submodule refs match helix-deps.yaml
bash scripts/verify-manifest-pins.sh
# Expected: 13 MATCH / 0 DRIFT / 0 UNDET

# Verify governance cascade passes
bash scripts/verify-governance-cascade.sh
# Expected: 12 PASS / 0 FAIL / 0 ENV / 8 NOTE

# Verify submodules at latest remote
bash scripts/verify-submodule-remote-sync.sh
# Expected: 13 CURRENT / 0 DRIFT / 0 UNDET

# Build backend
bash platform/scripts/build.sh
# Expected: Binary at platform/bin/workshop-server

# Start (requires ollama running on host:11434)
bash platform/scripts/start.sh
# Expected: "UP: http://127.0.0.1:8087  (pid XXXX)"

# Health check
curl -fsS http://localhost:8087/api/health
# Expected: {"status":"ok","stats":{...}}

# Run tests
go test ./... -v -json > test-evidence.json
bash scripts/validate-evidence.sh test-evidence.json
# Expected: All tests pass, evidence valid

# Frontend tests
cd platform/frontend
npm ci --no-audit --no-fund
ng test --watch=false --code-coverage
ng e2e --configuration=production
# Expected: All tests pass

# Stop
bash platform/scripts/stop.sh
```

**Success Criteria**:
- [ ] Clone completes without errors
- [ ] Submodules initialize correctly
- [ ] Build produces working binary
- [ ] Server starts and responds to health check
- [ ] All Go tests pass with deterministic evidence
- [ ] All Angular tests pass
- [ ] E2E tests pass against live server

---

### 2. ai_interviewing Standalone Validation

```bash
# Clone
cd "$PROJECTS_DIR"
git clone git@github.com:milos85vasic/ai_interviewing.git ai_interviewing-standalone
cd ai_interviewing-standalone

# Initialize submodules
git submodule update --init --recursive

# Verify submodules
bash scripts/verify-manifest-pins.sh  # Expected: 13 MATCH / 0 DRIFT / 0 UNDET
bash scripts/verify-governance-cascade.sh  # Expected: 12 PASS / 0 FAIL

# Build backend
bash platform/scripts/build.sh
# Expected: Binary at platform/bin/aicur

# Ingest curriculum data (first run only)
bash platform/scripts/ingest.sh
# Expected: "Ingestion complete" with stats

# Start server
bash platform/scripts/start.sh
# Expected: "UP: http://localhost:8099  (pid XXXX)"

# Health check
curl -fsS http://localhost:8099/api/health
# Expected: {"status":"ok","stats":{...}}

# Run tests
go test ./... -v -json > test-evidence.json
bash scripts/validate-evidence.sh test-evidence.json

# Frontend tests
cd platform/frontend
npm ci --no-audit --no-fund
ng test --watch=false --code-coverage
ng e2e --configuration=production

# Stop
bash platform/scripts/stop.sh
```

**Success Criteria**:
- [ ] Clone completes without errors
- [ ] Submodules initialize correctly
- [ ] Build produces working binary
- [ ] Ingestion completes successfully
- [ ] Server starts on ports 8099/8443
- [ ] All Go tests pass with deterministic evidence
- [ ] All Angular tests pass
- [ ] E2E tests pass against live server

---

### 3. Authentication Flow Validation

```bash
# Start both modules (in separate terminals)
# Terminal 1: Workshop
cd "$PROJECTS_DIR/workshop-standalone"
bash platform/scripts/start.sh

# Terminal 2: ai_interviewing
cd "$PROJECTS_DIR/ai_interviewing-standalone"
bash platform/scripts/start.sh

# Test login as milosvasic (admin)
TOKEN_MILOS=$(curl -s -X POST http://localhost:8087/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"milosvasic","password":"WhiteSnake8587"}' | jq -r .token)

echo "milosvasic token: $TOKEN_MILOS"

# Verify milosvasic has full permissions on workshop
curl -s -H "Authorization: Bearer $TOKEN_MILOS" http://localhost:8087/api/auth/me | jq .
# Expected: role=admin, permissions=[{"resource":"all","actions":["read","write","delete"]}]

# Test login as rami (user)
TOKEN_RAMI=$(curl -s -X POST http://localhost:8087/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"rami","password":"Test12345"}' | jq -r .token)

echo "rami token: $TOKEN_RAMI"

# Verify rami has full permissions on workshop
curl -s -H "Authorization: Bearer $TOKEN_RAMI" http://localhost:8087/api/auth/me | jq .
# Expected: role=user, permissions=[{"resource":"all","actions":["read","write","delete"]}]

# Test ai_interviewing permissions
TOKEN_RAMI_AI=$(curl -s -X POST http://localhost:8099/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"rami","password":"Test12345"}' | jq -r .token)

curl -s -H "Authorization: Bearer $TOKEN_RAMI_AI" http://localhost:8099/api/auth/me | jq .
# Expected: role=user, permissions=[knowledge_base:read, progress:read/write]
# NOT: employer_data, github_analysis

# Test logout
curl -s -X POST http://localhost:8087/api/auth/logout \
  -H "Authorization: Bearer $TOKEN_MILOS" | jq .
# Expected: {"success":true}

# Test account switch
TOKEN_SWITCH=$(curl -s -X POST http://localhost:8087/api/auth/switch \
  -H "Content-Type: application/json" \
  -d '{"username":"rami","password":"Test12345"}' | jq -r .token)

curl -s -H "Authorization: Bearer $TOKEN_SWITCH" http://localhost:8087/api/auth/me | jq .
# Expected: role=user, new token
```

**Success Criteria**:
- [ ] milosvasic login works on both modules
- [ ] rami login works on both modules
- [ ] milosvasic has full access on both modules
- [ ] rami has full access on workshop
- [ ] rami has restricted access on ai_interviewing (no employer_data, no github_analysis)
- [ ] Logout revokes session
- [ ] Account switch works (logout + login in one call)

---

### 4. Progress Tracking Validation

```bash
# Use rami's token (has progress.write on both)
TOKEN="$TOKEN_RAMI"

# Create progress record (workshop)
curl -s -X POST http://localhost:8087/api/progress \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"area_id":"intro","lesson_id":"lesson1","item_type":"lesson","item_id":"1","completed":true}' | jq .

# Create test progress with score
curl -s -X POST http://localhost:8087/api/progress \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"area_id":"intro","lesson_id":"quiz1","item_type":"test","item_id":"1","completed":true,"score":85}' | jq .

# Get all progress
curl -s -H "Authorization: Bearer $TOKEN" http://localhost:8087/api/progress | jq .

# Get summary
curl -s -H "Authorization: Bearer $TOKEN" http://localhost:8087/api/progress/summary | jq .

# Verify persistence: restart server and check progress
bash platform/scripts/stop.sh
bash platform/scripts/start.sh
curl -s -H "Authorization: Bearer $TOKEN" http://localhost:8087/api/progress | jq .
# Expected: Records still present

# Test ai_interviewing progress
TOKEN_AI="$TOKEN_RAMI_AI"
curl -s -X POST http://localhost:8099/api/progress \
  -H "Authorization: Bearer $TOKEN_AI" \
  -H "Content-Type: application/json" \
  -d '{"area_id":"ml-fundamentals","lesson_id":"supervised","item_type":"exercise","item_id":"ex1","completed":true}' | jq .

curl -s -H "Authorization: Bearer $TOKEN_AI" http://localhost:8099/api/progress/summary | jq .
```

**Success Criteria**:
- [ ] Progress records created for lessons, tests, exercises
- [ ] Scores recorded for tests (0-100)
- [ ] Progress summary aggregated correctly
- [ ] Progress persists across server restarts
- [ ] User isolation: users only see their own progress
- [ ] Works on both modules

---

### 5. Submodule Extraction Validation

```bash
# For each extracted submodule (example: auth-core)
SUBMODULE="auth-core"
cd "$PROJECTS_DIR"
git clone git@github.com:vasic-digital/$SUBMODULE.git $SUBMODULE-validation
cd $SUBMODULE-validation

# Verify dual remote
git remote -v
# Expected: github and gitlab remotes

# Build and test
go test ./... -v -json > evidence.json
bash ../vasic/scripts/validate-evidence.sh evidence.json
# Expected: All tests pass

# Verify public visibility and dual remotes
gh repo view vasic-digital/$SUBMODULE --json visibility
# Expected: "PUBLIC"
glab repo view vasic-digital/$SUBMODULE --json visibility
# Expected: "public"

# Verify governance cascade
cd "$PROJECTS_DIR/vasic"
bash scripts/verify-governance-cascade.sh
# Expected: 12 PASS / 0 FAIL
```

**Success Criteria** (per submodule):
- [ ] Clones from GitHub
- [ ] Clones from GitLab
- [ ] Builds successfully
- [ ] All tests pass with deterministic evidence
- [ ] Public visibility on both platforms
- [ ] Version tags present

---

### 6. Full Test Suite & Evidence Validation

```bash
# In each module directory
cd "$PROJECTS_DIR/workshop-standalone"

# Run complete test suite with evidence collection
bash scripts/run-full-test-suite.sh
# This script runs:
# 1. go test ./... -v -json > evidence-go.json
# 2. cd platform/frontend && ng test --watch=false --code-coverage > evidence-ng.json
# 3. ng e2e --configuration=production > evidence-e2e.json
# 4. bash scripts/validate-evidence.sh evidence-go.json
# 5. bash scripts/validate-evidence.sh evidence-ng.json
# 6. bash scripts/validate-evidence.sh evidence-e2e.json

# Verify evidence validation
cat validation-report.json
# Expected: {"passed": true, "total_tests": N, "false_positives": 0}
```

**Evidence Validation Script Requirements** (`scripts/validate-evidence.sh`):
- Parses JSON test output
- Verifies each test has: action, state delta, positive evidence, unique token
- Checks for mutation test pairing (gate catches seeded failures)
- Reports pass/fail with structured output
- Zero tolerance for false positives

**Success Criteria**:
- [ ] All test types execute (unit, integration, e2e, contract, perf, security, a11y)
- [ ] Evidence validation passes for all test outputs
- [ ] Zero false positives detected
- [ ] Mutation tests prove gates catch failures
- [ ] Total execution time < 5 minutes per module

---

### 7. Documentation Validation

```bash
# In each module
cd "$PROJECTS_DIR/workshop-standalone"

# Verify README exists and has required sections
cat README.md | grep -E "(# |## |### )" | head -20
# Expected: Clone, Install, Run, Test, Configure, Architecture sections

# Verify all links work
bash scripts/check-links.sh README.md
# Expected: 0 broken links

# Verify API docs generated
ls docs/api/
# Expected: OpenAPI/Swagger files

# Verify architecture diagrams
ls docs/architecture/
# Expected: .md, .png, .svg files

# Verify user guide
ls docs/guides/
# Expected: user-guide.md, admin-guide.md, developer-guide.md
```

**Success Criteria**:
- [ ] README complete with all required sections
- [ ] Zero broken internal/external links
- [ ] API documentation generated and accurate
- [ ] Architecture diagrams present and current
- [ ] User/admin/developer guides exist
- [ ] Fresh user can follow docs to successful setup

---

## Expected Evidence Artifacts

Each validation produces structured evidence:

| Validation | Evidence File | Format |
|------------|---------------|--------|
| Go tests | `evidence-go.json` | JSON lines (go test -json) |
| Angular unit | `evidence-ng.json` | JUnit XML + custom JSON |
| E2E Playwright | `evidence-e2e.json` | Playwright JSON reporter |
| Submodule tests | `evidence-<name>.json` | JSON lines |
| Evidence validation | `validation-report.json` | `{passed, total, false_positives, details[]}` |

---

## Troubleshooting

| Issue | Resolution |
|-------|------------|
| `ollama not found` | `podman run -d --network=host ollama/ollama` |
| `port 8087/8099 in use` | `PORT=8088 bash platform/scripts/start.sh` |
| `submodule not found` | `git submodule update --init --recursive --force` |
| `go module not found` | Check `go.mod` replace directives point to local submodules |
| `npm ci fails` | `rm -rf node_modules package-lock.json && npm install` |
| `Playwright browsers missing` | `npx playwright install chromium` |
| `PostgreSQL connection refused` | `podman run -d -p 5432:5432 -e POSTGRES_PASSWORD=test postgres:15` |

---

## Cleanup

```bash
# Stop all servers
cd "$PROJECTS_DIR/workshop-standalone" && bash platform/scripts/stop.sh
cd "$PROJECTS_DIR/ai_interviewing-standalone" && bash platform/scripts/stop.sh

# Remove test directories (optional)
rm -rf "$PROJECTS_DIR/workshop-standalone" "$PROJECTS_DIR/ai_interviewing-standalone"
rm -rf "$PROJECTS_DIR"/*-validation
```

---

## Success Checklist Summary

| Scenario | Status |
|----------|--------|
| Workshop standalone clone & run | ☐ |
| ai_interviewing standalone clone & run | ☐ |
| Authentication (login, logout, switch, RBAC) | ☐ |
| Progress tracking (CRUD, persistence, summary) | ☐ |
| Submodule extraction & validation | ☐ |
| Full test suite with evidence | ☐ |
| Documentation completeness | ☐ |
| All success criteria met | ☐ |

**All items must be checked before feature complete.**