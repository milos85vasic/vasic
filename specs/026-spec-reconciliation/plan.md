# Implementation Plan: Specs 011-017 Reconciliation

**Branch**: `026-spec-reconciliation` (none created) | **Date**: 2026-10-20 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `specs/026-spec-reconciliation/spec.md`

## Summary

Documentation-only. Eleven decisions (D1-D11) resolve contradictions among specs 011-017 and between those specs and
the code at workshop `33e9760`. Each decision is applied as a minimal, marked edit to the affected spec files. No product
code changes. The plan's other deliverable is the hot-spot ownership rule set below, which every implementing spec's
`plan.md` references.

## Technical Context

**Language/Version**: Markdown only (SpecKit artefacts). Verification by `grep`/`diff` against `workshop/` source, read-only.
**Primary Dependencies**: none.
**Storage**: n/a. **Testing**: marker grep per spec dir; field-by-field comparison of the 012 sidecar against `docSection` (`cmd/ingest-transcript/main.go:102-117`).
**Target Platform**: n/a. **Project Type**: documentation.
**Constraints**: workshop is PRIVATE; this repository is PUBLIC. Only paths, counts and line numbers are quoted; no `workshop/chapters/**` or transcript text (content-boundary rule, umbrella `CLAUDE.md`).

## Constitution Check

| Rule | Status | Note |
|---|---|---|
| §11.4.6 no guessing | PASS | Unverified items are marked UNCONFIRMED (`research.md` section 8). |
| §11.4.122 no silent removal | PASS | Nothing deleted: superseded statements are kept and annotated, ticked tasks untouched. |
| §11.4.113 no force push | PASS | No git operations performed by this feature. |
| §11.4.142 independent review | PENDING | Orchestrator records it before commit. |
| Content boundary | PASS | Paths and counts only. |

## Project Structure

```text
specs/026-spec-reconciliation/
  spec.md plan.md tasks.md research.md checklists/requirements.md
specs/011..017/   (edited in place; every edit carries "Reconciled by 026 on 2026-10-20")
specs/013-adaptive-assessment-scoring/contracts/achievement-events.md   (NEW, D3)
```

## Hot-spot ownership rules (decision D10)

Source: architecture plan section 2 of the 2026-10-20 analysis; each file's size re-measured at workshop `33e9760`
(`wc -l`): `cmd/workshop-server/main.go` is 3,905 lines with 34 `mux.Handle` sites. These rules bind every stream that
implements 011-015, 016 and 017-residual work.

1. **One branch per stream, one `git worktree` per branch**, base = `workshop` `main` at wave start. The orchestrator is the only actor that merges, only into `main` of the primary checkout, fast-forward or merge commit, never force (§11.4.113).
2. **`cmd/workshop-server/main.go` is single-writer (owner: orchestrator).** Wave 0 splits out hook files before any stream starts: one `cmd/workshop-server/wire_<feature>.go` per stream (`wire_audit.go` and `wire_lan.go` for 011, `wire_scoring.go` for 013, `wire_profile.go` for 015, `wire_rerank.go` for 017 residual), each exporting `add<Feature>Flags(fs, *config)` and `register<Feature>(mux, cfg)`, plus pre-created one-line call sites in `main.go` marked `// hook:audit`, `// hook:lan`, `// hook:scoring`, `// hook:profile`. *(Corrected by 027 on 2026-10-21, measured on workshop `main` `827e79e` and `int-0.0.3` `35f2ea3`: what was BUILT differs from the text above. The files are `wire_hooks.go` (the aggregators `addStreamFlags`, `validateStreamConfig`, `registerStreamRoutes`, `closeStreamHooks`, each with one call line per stream, plus the `streamConfigs` struct) and `wire_{providers,scoring,profile,practice,retrieval,ingestion,textbooks}.go` on `main`, plus `wire_answering.go` on `int-0.0.3`. There are NO `// hook:*` lines in `main.go` (`grep -n 'hook:' main.go` is empty); the aggregator calls replace them. `wire_audit.go`, `wire_lan.go` and `wire_rerank.go` were never created: the `-answer-audit-log` flag is in `wire_providers.go:47`, the `-answer-lan-extra-deny` flag is in `wire_providers.go:58` (`int-0.0.3` only), LAN locality validation is in `pkg/answer/locality.go`, and the two reranker flags are still declared in `main.go:429,438` (`-search-window-rerank`, `-search-cross-encoder-rerank`, both default OFF).)* A stream edits only its own `wire_*.go` and replaces its own single hook line. Existing wiring files (`authkit_wire.go`, `lan_admit.go`, `migration_wiring.go`, `redaction_log.go`, `suppression.go`) are not renamed.
3. **`internal/passagestore/domain.go` vocabulary (kinds, content types, `Attr*` keys): owner = spec 012.** 015's `LocationAnchor` fields and any 017-residual diagram kind go in new files (`domain_anchor.go`, `domain_diagram.go`) sequenced after 012-Foundational merges.
4. **`pkg/scoring/store.go`: sequential within 013** (ServeNext T017 -> downgrade branch T031 -> RecalibrateBatch); US2 and US3 add independent methods and the later one re-runs `go build`.
5. **Practice-answer submit path** (`internal/api/questions*.go`, `progress.go`): 016-US1 (bug fix on the existing endpoint) and 013-US1 (new submit/next with scoring) are a SEMANTIC conflict. Both go to ONE stream, 016-US1 first. 013-US1 starts after 016-US1 is merged.
6. **Frontend**: `app.routes.ts`, `app.component.ts`, `core/vocabulary.ts` (has the paired-mutation gate `prove-ui-vocabulary-mutation.sh`) are single-writer (owner: orchestrator); a feature adds `features/<x>/<x>.routes.ts` and one append line at the END of the route array. Vendored design CSS: `scripts/sync-learning-kit.sh --check` and `sync-platform-tokens.sh --check` must stay green.
7. **Submodule gitlinks and `helix-deps.yaml`**: one owner per submodule (curriculum-kit = 015, passage = 012); gitlink and manifest ref move in ONE change; `bash scripts/verify-manifest-pins.sh` before acceptance.
8. **`curriculum/passages.jsonl` and `*.sections.json` sidecars**: registry is rewritten whole (atomic rename); single writer at a time; sidecars are committed with the registry. Textbook live merge, 016-US8 and 016-US5 re-transcription are serialized by the orchestrator.
9. **Gate registries / TSVs and `specs/*/tasks.md` + `progress.yml`**: each stream owns only its own spec directory; TSV conflicts are resolved by keeping both rows.
10. **Live stack lock**: worktree streams NEVER run `scripts/restart.sh`, `start.sh`, `stop.sh` or `ingest.sh` against the live compose project `workshop-curriculum`; only the orchestrator does, from the primary checkout, after merge. Streams verify with unit tests and an isolated throwaway server on a free port with a scratch registry copy.
11. **Staging**: explicit paths only, never `git add .`; the umbrella `commit` wrapper runs `git add .` and is not used inside shared checkouts.
12. **Definition of done per stream**: RED seen failing, GREEN, `go vet`, own gates green, `git diff --stat` limited to declared files plus hook lines, independent review recorded.

## Merge order (sequential, orchestrator)

Wave-0 hook split -> 016-US1 -> 011-US2/US3 -> 013 -> 012 Foundational + A + B(extend 017 PDF) -> 015 backend -> 014 -> remaining 016 stories -> docs. After each merge: `go build ./... && go vet ./...` on `main`; a breaking merge is reverted with a new revert commit, never a history rewrite.

## Complexity Tracking

None. No code, no new dependency, no new storage.
