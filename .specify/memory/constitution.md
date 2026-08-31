---
version: 1.0.0
last_updated: '2026-08-31'
---

# vasic Constitution

## Core Principles

### Evidence-Based Claims
Every assertion must be backed by verifiable evidence. Never guess, assume, or fabricate. Constitution §11.4 applies — no bluffing, no speculation disguised as fact.

### Governance Fidelity
All governance carriers (CLAUDE.md, AGENTS.md, QWEN.md, GEMINI.md) must stay in lockstep. The constitution submodule is the single source of truth; no carrier may weaken or override universal clauses.

### Isolation by Default
Mutation-paired gates catch regressions. Every new gate has a paired mutation proving it fires. No naked writes — every destructive operation requires a hardlinked backup first (Constitution §9).

### Comprehensive Documentation
Every non-trivial commit updates CONTINUATION.md. Every architectural decision is recorded. Honest boundaries — gaps are stated openly, never hidden.

### Quality Over Speed
60% RAM cap on heavy work. TDD where possible. Lint and typecheck before claiming done. No shortcuts that compromise integrity.

## Project Structure

The vasic umbrella monorepo owns two personal/portfolio sites and shared tooling:

- **vasic.digital/** — committed static HTML served as-is (no build step)
- **milosvasic.ru/** — Jekyll source; rendered `_site/` is git-ignored; self-publishes on push via `.github/workflows/pages.yml` (ACTIVE, do not disable)
- **_tools/gen/** — Go generator rendering localized pages for both sites
- **design-system/** — shared per-brand tokens and component CSS
- **_tests/** — Playwright plus self-validating harness
- **_content/** — English source; `_content_<lang>/` siblings for translations
- **submodules/constitution/** — the universal constitution (11,101 lines, 261 anchors)

Toolchains: Go 1.26, Node 20, Ruby 3.3 + Bundler, poppler-utils, tesseract-ocr.

## CI/CD Policy

Remote CI is disabled at the umbrella root per operator mandate (2026-05-20). Enforcement is a local pre-push hook:

```
bash scripts/pre-push-gates.sh --install
```

The hook must be installed on fresh clones; `git push --no-verify` bypasses it. Gates run from repository root — no server-side enforcement.

**milosvasic.ru** keeps its active deploy workflow (`pages.yml`) as a documented deviation for production uptime — it is NOT an override of §11.4.156 (which forbids overrides). `vasic.digital` is non-compliant at the provider level with no file-level remedy.

## Testing Strategy

```bash
cd _tools/gen && go test ./... && cd -        # Go unit tests (generator)
bash _tools/audit-hardcoding.sh               # hardcoding audit
bash _tools/translate/reproducibility-selftest.sh
bash _tools/portfolio/self-validate.sh
bash _tests/run-harness-selfvalidation.sh     # harness self-validation
```

Playwright (chromium) requires `npm ci` and `npx playwright install chromium` inside `_tests/`, plus a built `milosvasic.ru/_site`.

## Deploys

Driven by `bash _tools/deploy-langs.sh`. Regenerates EN plus every complete language into both site submodules, commits and pushes each site only when something changed, then validates live sites. `--dry-run` previews without committing.
