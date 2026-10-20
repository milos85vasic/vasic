# Implementation Plan: Live Corpus Promotion and Deploy Gate

**Branch**: `019-live-corpus-promotion-and-deploy-gate` (workshop branch `feat/019-deploy-gate`) | **Date**: 2026-10-20 | **Spec**: [spec.md](./spec.md)
**Input**: `spec.md`; analysis inputs `gap-analysis.md` §0/§4/§5, `architecture.md` §2-§4 (esp. §3.2-§3.4 promotion mechanics),
`cycle-rules.md` (§11.4.236 QA-deploy-readiness, §11.4.264 immutable artefact, §11.4.265 progressive delivery).

## Summary

Three measurable properties, one shared vocabulary:

1. **Served bundle == built bundle.** A new `scripts/promote-web.sh` builds, stages and promotes the Angular bundle
   *additively* (hashed chunks first, `index.html` by rename, `build-info.json`, prune later), which the per-request
   `webHandler` makes safe without a restart (spec.md B5). `build.sh` is not edited.
2. **Running process == repository == artefacts.** A new `scripts/deploy-gate.sh` compares commit, bundle, registry digest
   (host / container / loaded), index and corpus counts, and writes a verdict bound to the candidate fingerprint; restart and
   the promote scripts can *refuse* without a matching PASS (the mechanical seam §11.4.236 demands).
3. **The operator can see it.** A session-gated `GET /api/system/provenance` and a **What is live** panel on `/status`.

Registry promotion (`scripts/promote-registry.sh`) is the safe, journalled, reversible way for 018 and 020 to go live.

## Technical Context

**Language/Version**: Go 1.26 (new `internal/provenance`, `internal/api/provenance.go`, `cmd/workshop-server/wire_provenance.go`);
Bash (gate and promote scripts, `bash -n`/shellcheck clean, §11.4.67); Python 3 stdlib (oracle only, run `-I`); TypeScript/Angular
(standalone components) for the panel.

**Primary Dependencies**: existing — `build_identity.go` (`currentBuildIdentity`), `index.Live` (`router.go:215`), `webServable`
(`main.go:2713`), `passagestore.Load`, `scripts/_common.sh` (runtime resolution, `ws_git_quiescent`, `_server_inputs_state`),
`scripts/_live_auth.sh`, `scripts/agent-admit.sh`, `platform/gates/verify-backup-distinctness.sh`,
`platform/bin/registry-restamp-content-type`. No new third-party dependency.

**Storage**: none new in the server. Host side: `.backups/promotions.jsonl` (git-ignored, append-only, hash-chained), evidence under
`evidence/019-<run>/` (private submodule).

**Testing**: Go `testing` with `-race`, fuzz (`FuzzManifest`), Karma, Playwright against an isolated server, shell tests with a **stub
stack** (local HTTP server + stub container runtime) so gate logic is tested without the live stack; paired-mutation gates
(`platform/gates/prove-*.sh`).

**Target Platform**: single compose project `workshop-curriculum` (`:8087`); promote scripts run on the host; the gate also execs into
the container through the repo's runtime resolution.

**Constraints**:
- Single-writer rules (architecture.md §2.2): new files only — `scripts/{promote-web,promote-registry,deploy-gate,live-drift,write-build-info,bundle-manifest}.sh`,
  `internal/provenance/*`, `internal/api/provenance.go`, `cmd/workshop-server/wire_provenance.go`, `features/status-live/*`. Shared files
  touched only through orchestrator hook lines: `main.go` (1 line), `core/status.component.ts` (1 line), `core/vocabulary.ts` (rows).
  **`scripts/restart.sh` gains one optional flag** (`--require-verdict`), reviewed in T026 — the one deliberate edit of an existing script.
- Fail closed (§11.4.252): provenance output is an allow-list; the gate maps every "unknown" to exit 2.
- Host safety (§12.6/§12.12): `ng build` under `agent-admit.sh -m 6G`; no parallel heavy jobs; restart only by the orchestrator.
- Evidence holds hashes, counts, ids — never passage text, tokens or `http` strings from the flags block.

**Scale/Scope**: registry 34 817 rows / 34 MB today (≈ 36 500 after textbooks); bundle ~200 files; first provenance computation < 1.5 s,
cached < 5 ms.

## Constitution Check

| Anchor | How satisfied |
|---|---|
| §11.4.224 / §11.4.245 test-first, oracle | every code task has a RED task; oracles named (python manifest oracle, `sha256sum`, reader-loop log, stub stack) |
| §11.4.240 / §11.4.249 producer ≠ verifier | test authors, implementers and reviewers are different agents; the gate's checks use independent channels |
| §11.4.142 / §11.4.209 review (Opus xhigh) | `[REVIEW]` T012, T017, T026, T036, T041, T058, T060 |
| §11.4.236 QA-deploy-readiness gate | verdict JSON + fingerprint; `--require-verdict` seam in `restart.sh` and the promote scripts |
| §11.4.115 RED baseline on the broken artefact | T027 runs the gate on the live stack before promotion |
| §11.4.252 / §11.4.253 / §11.4.254 | fail-closed allow-list; idempotent promotion; boot log line + always-mounted endpoint |
| §11.4.246 / §11.4.264 reproducible build, promote one immutable artefact | T004 reproducibility probe; the bundle is built once, staged, and the *same* staged bytes are promoted |
| §11.4.265 progressive delivery | single local container → no traffic-shiftable deploy; strategy recorded as **latent** (honest skip), not claimed |
| §11.4.85 chaos | SIGTERM at each promotion step (T013/T016/T037) |
| §11.4.262 / §11.4.266 | `result.json` + sha256 manifest (T050); ledger rows (T059) |
| §9 backup | real-copy, pre-digest, distinct inode (T037-T038) |
| §11.4.113 | ff-only merge, no force (T061) |
| §11.4.268 | journal hash chain (conditional clause; applied to this one ledger only) |

No violation to justify (Complexity Tracking empty).

## Project Structure

### Documentation (this feature)

```text
specs/019-live-corpus-promotion-and-deploy-gate/
├── spec.md plan.md research.md data-model.md quickstart.md tasks.md
├── contracts/
│   ├── provenance-api.md          # GET /api/system/provenance
│   ├── deploy-gate-verdict.md     # checks G0-G7, exit contract, verdict schema, fingerprint
│   └── registry-promotion.md      # promote-registry.sh / promote-web.sh procedure + journal
└── checklists/requirements.md
```

### Source Code *(NEW unless stated)*

```text
workshop/scripts/
├── promote-web.sh  promote-web.test.sh  write-build-info.sh  bundle-manifest.sh  bundle-manifest.test.sh
├── promote-registry.sh  promote-registry.test.sh
├── deploy-gate.sh  deploy-gate.test.sh  live-drift.sh  live-drift.test.sh  restart-verdict.test.sh
└── restart.sh                     # EXISTING: + --require-verdict (one flag, T024/T026)
workshop/platform/backend/
├── internal/provenance/{manifest.go,manifest_test.go,corpus.go,corpus_test.go,fuzz_test.go}
├── internal/api/{provenance.go,provenance_test.go}
└── cmd/workshop-server/{wire_provenance.go,wire_provenance_test.go}   # main.go: ORCH one-line hook
workshop/platform/frontend/src/app/
├── features/status-live/{live-facts.component.ts,live-facts-api.ts,live-facts-model.ts,*.spec.ts}
├── core/status.component.ts       # ORCH one-line hook: <wk-live-facts/>
└── core/vocabulary.ts             # ORCH hook rows
workshop/platform/frontend/e2e/status-live.spec.ts
workshop/platform/gates/{verify-live-equals-built.sh,prove-live-equals-built-mutation.sh,
                          verify-registry-promotion.sh,prove-registry-promotion-mutation.sh,lib/manifest_oracle.py}
workshop/docs/{deploy-and-promotion.md,guides/promote-the-frontend-bundle.md,guides/read-the-whats-live-panel.md,
               guides/roll-back-a-promotion.md,guides/promote-a-registry.md}
workshop/evidence/019-<run>/                           # machine evidence (private submodule)
```

## Execution Strategy

### TDD Requirements

Strict RED→GREEN for: manifest + corpus stats (T007-T010), `promote-web.sh` (T013-T015), `deploy-gate.sh` and the seam (T021-T024),
provenance handler and panel (T028-T033), `promote-registry.sh` (T037-T038). RED output is pasted into the task note.

### Parallel Execution Opportunities

- After Phase 2: US1 (frontend promotion), US2 (gate on a stub stack) and US3 (provenance endpoint + panel) are independent file sets and
  can run as three streams. G3/G6 of the gate need the endpoint (T030) but are testable earlier against the stub.
- US4 starts after the seam exists (T024). US5 is a thin wrapper after US2.
- The live tasks (T018, T019, T027, T043, T050, T051) are **orchestrator-serial** and sequenced with 018/020's restart.

### Human Checkpoints

1. D1-D3/D5 decisions (T005). 2. Approval to promote the live bundle (T019) — user-visible change. 3. Approval for each registry
promotion (consumers 018/020) and for the restart window (~45 min boot). 4. UI-visible acceptance walks (T020, T051).

### Review Gates

Independent Opus-xhigh review before each commit of: manifest/corpus (T012), promote-web (T017), gate + `restart.sh` edit (T026),
provenance + panel (T036), promote-registry (T041), docs exports (T058), whole feature (T060).

## Complexity Tracking

*(empty)*
