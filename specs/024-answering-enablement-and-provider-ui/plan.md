# Implementation Plan: Answering Enablement + Provider Status UI

**Branch**: `024-answering-enablement-and-provider-ui` | **Date**: 2026-10-20 | **Spec**: [spec.md](./spec.md)

## Summary

Answering is OFF by default and measured unsafe to turn on (19% recall, 4.6% fabrication, SC-010
unmet). This feature makes enabling a *measured, mechanical, two-sided* decision and makes the state
visible: (1) a read-only `GET /api/answering/overview` + `/settings/providers` page + an honest `/ask`
off banner; (2) a verdict format, a measurement wrapper over the existing `gates/answer-eval` harness,
and a fail-closed boot gate that forces any non-`none` provider off unless a fingerprint-matching
PASS verdict exists; (3) a root-cause/fix path for the three known fabrications with permanent
regression fixtures; (4) verdict history, locality and residency visibility; (5) a guarded
enable/disable procedure whose post-check proves search is unaffected. The compose default stays
`none`. No UI control enables answering. If no configuration passes, the accepted end state is "OFF,
with measured reasons shown".

## Technical Context

**Languages**: Go 1.26 (backend), TypeScript/Angular 19.2 (frontend, standalone components, signals,
Karma + Playwright), Python 3 (measurement tooling, stdlib only), Bash (scripts/gates).
**Primary dependencies reused, not reimplemented (§11.4.74)**: `pkg/answer` (registry, handler,
pipeline), `gates/answer-eval`, `internal/answering/wire.go`, `core/api.ts` patterns
(`LoadStatus`, `httpToLoadStatus`), `app-state`/`UnavailableComponent`, `scripts/_live_auth.sh`.
**New dependency**: none (no new Go module, npm package or Python package).
**Storage**: verdict files on disk (append-only directory + manifest); no DB table.
**Testing**: Go unit/race, Karma, Playwright (+axe), shell tests, paired-mutation gates
(`prove-*.sh`); no Go mutation tool in the repo (UNCONFIRMED) so mutants are hand-written throwaway
copies per architecture §4.
**Target platform**: private `workshop` submodule (Go server in the `workshop-curriculum` compose
project, port 8087); umbrella `vasic` holds only this spec.
**Performance goals**: overview handler p95 < 50 ms on the live index (it reads in-memory state and a
small directory); the page adds one request. UNCONFIRMED until measured (T032).
**Constraints**: never touch the live stack from a worktree; verdict directory read-only mount in
compose; boot-time check must not delay boot noticeably (reads a handful of small files); no network
call to any vendor from the overview.
**Scale**: dozens of verdict files at most; catalogue 30 rows.

## Constitution check (anchors that bind this plan; full text lives in the submodule, read per anchor)

| Anchor | How the plan satisfies it |
|---|---|
| §11.4.224 / §11.4.245 | every implementation task is preceded by a RED task with a named oracle (Wilson reference values, golden fingerprints, `Registrations()`, contract text) |
| §11.4.240 / §11.4.249 | test authors, implementers, labellers and reviewers are distinct agents; the gate's thresholds and benchmark are data a producer cannot silently edit (hash-bound) |
| §11.4.252 / §11.4.254 | boot gate is fail-closed; capability-matrix row (T093) |
| §11.4.236 / §11.4.262 | the enable path binds to a machine-written verdict at two mechanical seams (boot, enable script) |
| §11.4.239 | scenario maps before closing the critical-class items (T034, T055) |
| §11.4.142 / §11.4.209 | `[REVIEW]` tasks after each phase, Opus at xhigh effort, verdict files |
| §11.4.257 / §11.4.258 / §11.4.65 / §11.4.168 | manual/guide/FAQ + four diagrams + exports + independent export validation (T091-T099) |
| §11.4.266 | ledger rows with passing challenges (T100) |
| §11.4.40 / §11.4.151 | full-suite retest before any tag (T101, T107) |
| §11.4.115 / §11.4.146 | RED baseline on the broken artifact (T057) and same-test-confirms-fix (T062) |
| §11.4.267 | attempt record for the fabrication fix loop (T064) |
| §11.4.6 | UNCONFIRMED markers throughout; no unmeasured claim |
| §11.4.113 | no force push; branches merge ff-only; nothing is rewritten |

## Project structure (all new files; existing files listed are read-only references or hook-line targets)

```text
workshop/platform/backend/
  pkg/answer/verdict/{wilson,fingerprint,verdict}.go (+_test.go, testdata/)      NEW
  pkg/answer/demand_check.go (+_test.go)                                          NEW, provisional (US3, only if trace says so)
  pkg/answer/fabrication_regression_test.go                                       NEW
  internal/answering/{overview,overview_http,verdict_history,residency_note}.go   NEW (+tests)
  cmd/workshop-server/{answering_gate,wire_answering_overview,wire_answering_gate}.go  NEW (+tests)
  cmd/answering-verdict-check/main.go                                             NEW
  gates/answer-eval/{gate_verdict.py,classify.py?,test_gate_verdict.py}           NEW
  gates/{verify,prove}-answering-verdict*.sh, prove-g-http-6-*.sh                 NEW
  testdata/benchmark/{questions-v2.tsv,questions-v2.audit.tsv,gate-thresholds.json,
                      gate-thresholds.schema.json,fabrication-fixtures.tsv,search-digest-queries.txt}  NEW (private)
workshop/platform/frontend/src/app/
  core/{answering-api.ts,answering-models.ts}                                     NEW
  features/settings/{settings.routes.ts,settings-vocabulary.ts,providers-page,provider-table,
      locality-badge,gate-verdict-card,audit-summary,verdict-history,residency-note}.component.ts (+specs)  NEW
  features/inquiry/answering-off-banner.component.ts                              NEW
workshop/platform/frontend/e2e/settings-providers.spec.ts                         NEW
workshop/scripts/answering-{measure,enable,disable,postcheck}.sh (+tests)         NEW
workshop/docs/{guides/answering-enablement-guide.md, answering-data-residency.md (operator)} NEW; manual.md, faq.md, answering.md EDITED (docs only)
workshop/evidence/{024-answering-enablement/**, answering-verdicts/**}            NEW (private)
```

## Shared-file protocol (architecture §2)

Files this feature must NOT edit directly: `cmd/workshop-server/main.go`, `app/app.routes.ts`,
`core/vocabulary.ts`, `platform/compose.yml`, `gates/check-registry-*.tsv`, `gates/POPULATION-CHANGES.md`,
`features/inquiry/inquiry.component.ts` (1,826 lines; a hot spot shared with spec 025 US1).
Delivered as hook lines recorded in `workshop/evidence/024-answering-enablement/hook-lines.md`, landed
by the orchestrator in this order: 025-US1's inquiry changes first, then this feature's single banner
tag; compose edit after any other stream's compose edit.

## Stream sizing and parallelism

Two parallel backend/frontend streams after Phase 2 (US1 || US2), one measurement stream (long ops,
registered per §11.4.232), US3 follows. Orchestrator-only: restarts, live verification, gitlink bump.

## Risks

1. **The gate never clears** (likely at first): handled as an accepted outcome; recall improvement
   levers (spec 017 retrieval, provider choice via 011, stronger verifier) are separate work, each
   re-measured through this gate.
2. **Benchmark too small for the Wilson bound**: v2 sized from D1 (about 180 unanswerable trials for
   a 2% bound with zero fabrications).
3. **Measurement drift from corpus changes**: by design a re-measurement is required (D3).
4. **Fix overfits to F1/F3**: adversarial reviewer set (T065).
5. **Shared inquiry component conflicts with 025**: serialised via the orchestrator.
6. **Role not exposed to frontend**: API enforcement is the control; UI is cosmetic.

## Complexity tracking

No constitution deviation. Deliberate omissions recorded: no bypass flag (FR-011), no UI mutation, no
hot switch (blocked in 011), no new unavailable code by default (D4).
