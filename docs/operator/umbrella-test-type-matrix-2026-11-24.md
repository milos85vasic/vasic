# Umbrella test-type matrix, 2026-11-24

| Field | Value |
|---|---|
| Date | 2026-11-24 |
| Scope | Umbrella repo root tooling: `_tools/gen` (Go), `_tools/career` (Python), `_tools/containers`, `_tests` (Playwright and node harness), `scripts/` gates, `design-system`, `_tools/deploy-langs.sh` |
| Anchors | §11.4.169 (test-type coverage), §11.4.262 (machine-created evidence), §11.4.289 (no stubs as evidence), §11.4.102 |
| Companion | [`umbrella-gap-register-2026-11-24.md`](umbrella-gap-register-2026-11-24.md) |
| Evidence normalisation | `scripts/normalise-evidence-paths.sh` (re-derive the recipe from `--help`); raw logs were captured in the session scratchpad, only the figures below are quoted |
| Reading rule | A cell says what ran in THIS session. "Not run" is stated, never inferred as pass. Last committed evidence is cited separately and is NOT a result of this session. |

## Contents

1. [Matrix](#matrix)
2. [Determinism proofs](#determinism-proofs)
3. [Missing areas](#missing-areas)
4. [Risk-ordered backlog](#risk-ordered-backlog)

## Matrix

15 types are tracked. 11 produced a captured result this session, 2 are partial, 2 were not run.

| # | Type | Command | Result captured this session | Determinism | Missing |
|---|---|---|---|---|---|
| 1 | Unit, Go (`_tools/gen`, `_tools/containers`) | `( cd _tools/gen && go test ./... )`, `( cd _tools/containers && go test ./... )` | gen `ok 0.552s`; containers: `distribute-helixtranslate`, `port-discover`, `runtime-probe`, `runnersel` ok; `site-build` and `internal/orchestrate` `[no test files]` | Go test is deterministic by construction; `-count=2` not run | tests for the Jekyll build path (B2) |
| 2 | Unit, Python (`_tools/career`) | `python3 -B -m unittest <module>` per `test_*.py` (no pytest on host) | see the career block below the table | not measured | `pytest` is absent; a single combined `unittest discover` did not finish inside 150 s |
| 3 | Unit, JS (`_tests/tools`) | `python3 _tests/tools/glossary_protect_test.py`; `node _tests/tools/validate.mutation.test.mjs` | glossary `OK`; validate mutation `RESULT: PASS … (4/4)` | not measured | no unit runner over `_tests/*.js` helpers |
| 4 | Integration (build chain, remote-sync, cascade) | `bash scripts/verify-governance-cascade.sh`, `bash scripts/verify-manifest-pins.sh`, `bash scripts/verify-submodule-remote-sync.sh` | cascade rc 2 (10 PASS, 2 ENV: uninitialised owned submodules); manifest pins rc 0 `22 MATCH, 0 DRIFT`; remote-sync rc 1 `21 CURRENT, 1 DRIFT, 0 UNDETERMINED` (the DRIFT is `job_seeker`, real) | gates are read-only and re-runnable | cascade needs `submodule update --init` to reach a verdict (B5) |
| 5 | E2E Playwright | `( cd _tests && npx playwright test --project=chromium vasic-digital-a11y seo-meta security-hardening perf-budget )` run from a scratch copy with `npm ci` | `41 passed (1.5m)` | passing counts only; run-to-run not repeated | 3 live specs and `milosvasic.ru` full suite not run (`milosvasic.ru/_site` absent, preflight rc 2) |
| 6 | Contract (data gates, hreflang reciprocity, ledger) | `node _tests/tools/validate.mutation.test.mjs`; `bash scripts/verify-claim-ledger.sh` | validator `4/4` mutants caught; ledger rc 0, 11 claims agree | claim ledger re-measures live | no schema contract between `_tools/gen` input and the Jekyll side |
| 7 | Mutation, paired proofs | `bash scripts/verify-submodule-remote-sync.sh --prove-failure` and targeted mutants | remote-sync proof rc 0 with new P18; 4 targeted verdict mutants on `verify-manifest-pins` and `verify-claim-ledger` all caught (proof rc 1) | proofs run in a `mktemp` sandbox | `--run-proofs` over 79 checks (about an hour) not run; sample is 3 gates |
| 8 | Property and fuzz | `( cd _tools/gen && go test -run '^$' -fuzz '^FuzzInline$' -fuzztime 10s . )` | `elapsed 11s, execs 759012 (38259/sec), new interesting 28`, PASS | fuzz corpus grows; seed corpus deterministic | fuzz exists for `gen`, `workable-items`, `zero-gap-chain`; none for `_tools/containers`, `_tools/career` |
| 9 | Performance and budget | `perf-budget.spec.js` inside row 5; committed `_tests/evidence/test-types/perf-budget.json` | passed within row 5 | NOT deterministic: JSON is rewritten by every run; committed JSON and `playwright-summary.txt` disagree (324,494 B vs 221,252 B for `vasic.digital/`) | no stable baseline file, no regression threshold other than the 1,500,000 B and 45-request ceilings |
| 10 | Security | `security-hardening.spec.js` inside row 5 (22 passed with a11y, chromium); `bash scripts/verify-provider-ci.sh` | spec passed; provider-ci rc 1 `provider-side triggering CONFIRMED on 1 upstream row(s)` (known, `vasic-digital.github.io`) | provider-ci reads a live API | no dependency or secret scan registered for `_tools/*`; `zero-gap-class-credentials-public-tree` not run |
| 11 | Accessibility (axe), both sites | `vasic-digital-a11y.spec.js`, `milosvasic-ru-a11y.spec.js` | `vasic-digital-a11y` passes on chromium (inside the 22) and on webkit (`12 passed (40.9s)`); `milosvasic-ru-a11y` not run (no `_site`) | pass counts only | `milosvasic.ru` axe result not captured this session |
| 12 | Visual regression | `_tests/run-harness-selfvalidation.sh`; committed screenshots under `_tests/evidence/homepages/` | self-validation rc 2 UNDETERMINED: `Cannot find module '@playwright/test'` in the worktree (correct rc 2) | screenshots are modified in the shared checkout (`M milos-*.png`), so image bytes are not stable run to run | no pixel-diff tolerance recorded; no baseline update rule |
| 13 | i18n and RTL render | `ui-l10n-chrome.spec.js`, `i18n-completeness.spec.js`, RTL checks in `css-visual-regression.spec.js` | not run this session | not measured | languages `ar`, `fa` are RTL; no captured RTL screenshot evidence this session |
| 14 | Determinism and reproducibility | `SOURCE_DATE_EPOCH=1700000000 gen -site vasic.digital -lang en -root <copy>` twice | both runs hash `56475a4dbfbda1d3433bde2fa3c476ce90d1c4e6a1508baa632f4f218b470717`; byte-identical | see next section | equality against committed output is NOT claimed: the scratch copy carried only `en` and `ru` content, so hreflang rows for other languages differ (37 files) |
| 15 | Link and sitemap, deploy, rollback | `all-languages-link-integrity.spec.js` (live spec); `_tools/deploy-langs.sh --dry-run` | not run (needs the live sites and egress); rollback has no tool (gap UG-17) | not applicable | rollback test absent; live specs only run at deploy time |

### Career block (row 2)

Run per module (`timeout 40 python3 -B -m unittest <module>`); 24 test modules exist and 18 were reached before the loop ended. Captured tails: `test_expertise_localized` 18 tests OK, `test_expertise_css_logical` 3 OK, `test_keyword_match` 22 OK, `test_locale_comp_items` 5 OK, `test_locale_guards` 15 OK, `test_overlay` 30 OK (26.1 s), `test_private_identity` 4 OK, `test_profile_facts` 10 OK, `test_expertise_tile_geometry` skipped=1, `test_vault_browser` skipped=1. Two are not green. `test_vault` ended `FAILED (failures=1)` in `test_node_decrypts_python_sealed_vault_and_rejects_tampering`: `Cannot find module '../../milosvasic.ru/assets/js/vault.js'`; that file is not in the pinned `milosvasic.ru` submodule (`ls milosvasic.ru/assets/js` lists articles, downloads, i18n, main only), gap UG-19. `test_pdf_pipeline` printed `manifest NOT written: 1 failed/undetermined cell(s): cv-a-en` and `CANNOT VERIFY` (no PDF toolchain on this host; rc 2 semantics, not a pass). The `test_vault_*` stress, chaos, concurrency, fuzz, review and throttle modules and `test_manifest_contract` were not individually confirmed.

## Determinism proofs

* Generator, two runs: identical sha256 over the full output tree for `vasic.digital` (`56475a4d…0717` both). Command and inputs are in row 14. Scope limit stated there.
* Go build and fuzz: the fuzz seed corpus is committed; the `new interesting` count is not a determinism claim.
* Gates: `zero-gap-determinism.sh --runs N` exists and is registered (`zero-gap-determinism`); it was not run here because it copies the tree. It is the right instrument for the sweep; backlog B7.
* Evidence files that are NOT deterministic today: `_tests/evidence/test-types/perf-budget.json` (timings), `_tests/evidence/homepages/*.png`. A deterministic evidence rule needs a normalisation or tolerance step; this was gap UG-15, which PR #90 FIXED (evidence stability; re-run the perf-budget spec twice and compare the JSON to confirm before relying on it).

## Missing areas

1. No Go tests for `_tools/containers/cmd/site-build` and `internal/orchestrate`.
2. No rollback test and no rollback tool for a failed live validation.
3. i18n and RTL render not captured this session; the run needs `milosvasic.ru/_site`.
4. Visual regression has no stable baseline: the screenshots churn.
5. Perf budget has no stable baseline and the summary doc disagrees with the committed JSON.
6. No cross-boundary contract test between the Go generator output and the Jekyll site build.
7. Fuzz covers the markdown path only.
8. Nested constitution submodules uninitialised in worktrees, so about a third of the sweep returns REFUSE rc 4 (decides nothing).

## Risk-ordered backlog

Ordered by blast radius on the two live production sites, then by how often the gap lets a false green through.

| ID | Item | Why this rank | Type |
|---|---|---|---|
| B1 | Remote-sync, upstream-sync and cascade must reach a verdict in a fresh worktree: provide one documented init command and have each gate say rc 2 for uninitialised paths (done for remote-sync in this PR) | a false DRIFT or an undetermined fleet hides real drift | tooling |
| B2 | Tests for `site-build` and `internal/orchestrate` | the only Jekyll build path; failure means a stale production publish | unit and integration |
| B3 | Stable perf-budget and visual baselines with a tolerance and a refresh rule | evidence churn makes real regressions invisible | performance and visual |
| B4 | Deploy rollback: a documented `git revert` PR path plus a test; decide whether tolerated `gen <lang>` failures for a COMPLETE language should be fatal | live sites, no recovery step | deploy |
| B5 | Worktree bootstrap script: `submodule update --init --recursive`, `npm ci` in a scratch copy, build `docs_chain` | UG-06, UG-09, UG-10, UG-14 all share this root cause | environment |
| B6 | `CONTINUATION.md` Synced-Commit update (C3 DRIFT) and anchor its 520 unanchored figures into the claim ledger incrementally | stale carrier text already misled once (webkit, three sweep gates) | docs |
| B7 | Sweep runtime: gates that hit the 900 s timeout need a root cause (`cm_agent_type_label_mutation_test.sh`) and the sweep needs a resumable ledger | sweep never finishes in a session | tooling |
| B8 | `--run-proofs` across all 79 checks with the targeted-mutation method, not blanket `sed` | only 3 gates sampled | mutation |
| B9 | i18n and RTL render run with captured screenshots for `ar` and `fa` | RTL regressions are visually silent | i18n |
| B10 | Add a dependency and secret scan to `_tools/*` and register it with a paired proof | no security gate beyond the page-level spec | security |

Top 10 risks, same order as the backlog, one line each, are the ten rows above.
