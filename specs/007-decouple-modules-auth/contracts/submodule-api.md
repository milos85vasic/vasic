# Submodule Consumption Contract

**Feature**: specs/007-decouple-modules-auth
**Version**: 1.0
**Generated**: 2026-09-12
**Source**: Plan.md Phase 1 Design

---

## Overview

This contract defines how workshop and ai_interviewing modules consume reusable submodules. All submodules are hosted under the `vasic-digital` organization on both GitHub and GitLab.

---

## Submodule Registry

### Existing Submodules (to be made public on both GitHub/GitLab)

| Submodule | GitHub | GitLab | Purpose | Consumed By |
|-----------|--------|--------|---------|-------------|
| containers | vasic-digital/containers | vasic-digital/containers | Container orchestration, runtime detection, compose management | workshop, ai_interviewing |
| LLMProvider | vasic-digital/LLMProvider | vasic-digital/LLMProvider | LLM provider abstraction (Ollama, OpenAI, etc.) | workshop, ai_interviewing |
| RAG | vasic-digital/RAG | vasic-digital/RAG | Retrieval-augmented generation pipeline | workshop, ai_interviewing |
| verdict | vasic-digital/verdict | vasic-digital/verdict | Evaluation/verdict engine | workshop, ai_interviewing |
| passage | vasic-digital/passage | vasic-digital/passage | Passage/document processing | workshop, ai_interviewing |
| curriculum-kit | vasic-digital/curriculum-kit | vasic-digital/curriculum-kit | Curriculum content toolkit | workshop |
| design-toolkit | vasic-digital/design-toolkit | vasic-digital/design-toolkit | Design system tokens, components | workshop, ai_interviewing |

### Newly Extracted Submodules (to be created)

| Submodule | Purpose | Source | Consumed By |
|-----------|---------|--------|-------------|
| auth-core | Shared authentication (JWT, bcrypt, sessions, RBAC) | workshop/platform/backend, ai_interviewing/platform/backend | workshop, ai_interviewing |
| progress-core | Shared progress tracking (CRUD, persistence, summaries) | workshop, ai_interviewing | workshop, ai_interviewing |
| test-evidence | Test evidence collection & validation | _tests/, both modules | workshop, ai_interviewing |
| config-loader | Environment/config loading (YAML, env, secrets) | Both modules | workshop, ai_interviewing |
| db-migrate | Database migration framework | Both modules | workshop, ai_interviewing |

---

## Declaration Format

### helix-deps.yaml (per module)

```yaml
deps:
  - name: containers
    repo: git@github.com:vasic-digital/containers.git
    ref: main
    path: submodules/containers
    mirrors:
      - git@gitlab.com:vasic-digital/containers.git
  
  - name: LLMProvider
    repo: git@github.com:vasic-digital/LLMProvider.git
    ref: main
    path: submodules/LLMProvider
    mirrors:
      - git@gitlab.com:vasic-digital/LLMProvider.git
  
  - name: RAG
    repo: git@github.com:vasic-digital/RAG.git
    ref: main
    path: submodules/RAG
    mirrors:
      - git@gitlab.com:vasic-digital/RAG.git
  
  - name: auth-core
    repo: git@github.com:vasic-digital/auth-core.git
    ref: main
    path: submodules/auth-core
    mirrors:
      - git@gitlab.com:vasic-digital/auth-core.git
  
  - name: progress-core
    repo: git@github.com:vasic-digital/progress-core.git
    ref: main
    path: submodules/progress-core
    mirrors:
      - git@gitlab.com:vasic-digital/progress-core.git
```

### .gitmodules (per module)

```ini
[submodule "submodules/containers"]
	path = submodules/containers
	url = git@github.com:vasic-digital/containers.git
	branch = main

[submodule "submodules/auth-core"]
	path = submodules/auth-core
	url = git@github.com:vasic-digital/auth-core.git
	branch = main
```

---

## Consumption Patterns

### Go Modules (Backend)

**replace directive in go.mod** (for local development):
```go
module workshop

go 1.22

require (
    github.com/vasic-digital/containers v0.0.0
    github.com/vasic-digital/auth-core v0.0.0
    github.com/vasic-digital/progress-core v0.0.0
)

replace (
    github.com/vasic-digital/containers => ./submodules/containers
    github.com/vasic-digital/auth-core => ./submodules/auth-core
    github.com/vasic-digital/progress-core => ./submodules/progress-core
)
```

**Production**: Tags used (e.g., `v1.2.3`), no replace directives

### Import Paths

```go
// Containers
import "github.com/vasic-digital/containers/pkg/compose"
import "github.com/vasic-digital/containers/pkg/runtime"

// Auth Core
import "github.com/vasic-digital/auth-core/pkg/jwt"
import "github.com/vasic-digital/auth-core/pkg/rbac"
import "github.com/vasic-digital/auth-core/pkg/session"

// Progress Core
import "github.com/vasic-digital/progress-core/pkg/tracker"
import "github.com/vasic-digital/progress-core/pkg/summary"
```

### Version Pinning

- **Development**: `main` branch (replace directive)
- **CI/CD**: Specific commit SHA or tag
- **Release**: Semantic version tags (`v1.2.3`)
- **Lockfile**: `go.sum` commits with module

---

## CI/CD Integration

### GitHub Actions (`.github/workflows/submodules.yml`)

```yaml
name: Submodule Validation

on:
  push:
    paths:
      - 'helix-deps.yaml'
      - '.gitmodules'
  pull_request:
  schedule:
    - cron: '0 6 * * *'  # Daily at 6 AM UTC

jobs:
  validate-submodules:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: recursive
      
      - name: Verify submodule refs match helix-deps.yaml
        run: |
          bash scripts/verify-manifest-pins.sh
      
      - name: Build and test each submodule
        run: |
          for submodule in submodules/*/; do
            (cd "$submodule" && go test ./... -v -json > evidence.json)
            bash scripts/validate-evidence.sh "$submodule/evidence.json"
          done
      
      - name: Check for updates
        run: |
          bash scripts/check-submodule-updates.sh
```

### GitLab CI (`.gitlab-ci.yml`)

```yaml
stages:
  - validate
  - test
  - update-check

validate_submodules:
  stage: validate
  script:
    - git submodule update --init --recursive
    - bash scripts/verify-manifest-pins.sh
  rules:
    - if: $CI_PIPELINE_SOURCE == "schedule"
    - if: $CI_PIPELINE_SOURCE == "push"

test_submodules:
  stage: test
  script:
    - for dir in submodules/*/; do (cd "$dir" && go test ./...); done
  rules:
    - if: $CI_PIPELINE_SOURCE == "schedule"

check_updates:
  stage: update-check
  script:
    - bash scripts/check-submodule-updates.sh --create-mr
  rules:
    - if: $CI_PIPELINE_SOURCE == "schedule"
```

---

## Submodule Creation Process (via gh/glab)

```bash
# For each new submodule
SUBMODULE_NAME="auth-core"
ORG="vasic-digital"

# GitHub
gh repo create "$ORG/$SUBMODULE_NAME" \
  --private=false \
  --description "Shared authentication core for vasic modules" \
  --homepage "https://github.com/$ORG/$SUBMODULE_NAME" \
  --enable-issues --enable-wiki=false

# GitLab
glab repo create "$ORG/$SUBMODULE_NAME" \
  --visibility=public \
  --description "Shared authentication core for vasic modules" \
  --default-branch=main

# Push initial commit
git init
git remote add github git@github.com:$ORG/$SUBMODULE_NAME.git
git remote add gitlab git@gitlab.com:$ORG/$SUBMODULE_NAME.git
git add .
git commit -m "feat: initial commit - $SUBMODULE_NAME"
git tag v0.1.0
git push github main --tags
git push gitlab main --tags
```

---

## Validation Gates

| Gate | Script | Purpose |
|------|--------|---------|
| Manifest Pins | `scripts/verify-manifest-pins.sh` | helix-deps.yaml refs match git submodule pointers |
| Remote Sync | `scripts/verify-submodule-remote-sync.sh` | Local submodules at latest remote main |
| Build Test | `go test ./...` in each submodule | Submodules build and test independently |
| Evidence | `scripts/validate-evidence.sh` | Test evidence valid and deterministic |

---

## Update Protocol

1. **Scheduled**: Daily CI checks for upstream updates
2. **Manual**: `bash scripts/update-submodules.sh` creates MR/PR
3. **Breaking Changes**: Require version bump (semver) and consumer migration
4. **Security**: Automated dependabot/renovate for dependencies

---

## Breaking Change Policy

| Change Type | Version Bump | Migration Required |
|-------------|--------------|-------------------|
| Bug fix | PATCH (1.0.1) | No |
| New feature (backward compat) | MINOR (1.1.0) | No |
| Breaking API change | MAJOR (2.0.0) | Yes - 2 week deprecation |
| Security fix | PATCH + advisory | Immediate |

Consumers pin to MAJOR version (e.g., `v1.x.x`), update MINOR/PATCH freely.