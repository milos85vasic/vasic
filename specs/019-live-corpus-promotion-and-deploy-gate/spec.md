# Feature Specification: Live Corpus Promotion and Deploy Gate

**Feature Branch**: `019-live-corpus-promotion-and-deploy-gate`

**Created**: 2026-10-20

**Status**: Draft

**Input**: Gap analysis (`gap-analysis.md` §0.1-§0.5, §4 item 2): "implemented" is not "served". The operator sees a
platform that does not match the source: the frontend bundle in `platform/web` was built before later frontend commits,
textbook and research passages exist only in scratch registries or sidecars, and nothing in the system can say whether
the running thing is the built thing. This feature makes "what is built is what is served" a **measured, gated,
visible** property, and gives registry changes one safe, reversible way to go live.

**Builds on**: `specs/001-workshop-curriculum-platform` (build identity, `/api/health`, `scripts/restart.sh`, backups
policy), `specs/006` build-identity work (`verify-build-identity.sh`), `specs/017-exhaustive-rag-expansion` (the
ingest-then-merge residual), and the existing `/status` page. It **extends** them; it does not replace
`build.sh`/`restart.sh`/`verify-build-identity.sh`.

**Consumed by**: spec 018 (research re-ingest merge) and spec 020 (textbook merge). Both end in "orchestrator merges a
registry and restarts"; this feature is that procedure.

**Content boundary**: names paths, hashes and counts only. No passage text, no research or transcript wording.

## Verified Baseline *(read on 2026-10-20 — re-measure; do not trust)*

| # | Fact | Evidence |
|---|---|---|
| B1 | The running server binary is stamped `commit=ce62bcb68fe2…`, `build=ce62bcb-20261020T111922Z`, `dirty=false`, `src_dirty=false`, `bin_sha256=6dfddf7d…`. Workshop `HEAD` is now `33e9760` (descendants: `bb69fe5` catalogue rows, then a wave-0 evidence commit). So `source_commit != HEAD` today; whether the differing commits touch the compiled inputs is **UNCONFIRMED** (not diffed in this authoring pass). | `platform/bin/workshop-server.stamp`; `git -C workshop log --oneline` |
| B2 | `GET /api/health` already carries a build block (`build`, `source_commit`, `source_dirty`, `built_at`, `identity_source`), is exempt from the session gate, and is built per request (not cached). | `cmd/workshop-server/build_identity.go:50-118`; `main.go:2936-2952`; `main.go:3556` |
| B3 | `platform/web` (the served Angular bundle) has file mtimes of **Oct 7 17:10**. Frontend commit `eb691db` is dated **Oct 7 23:32** and `1d4cdfa` **Oct 15 13:20** — both after the bundle. Which other behaviour differs is UNCONFIRMED. | `ls -la --time-style=full-iso platform/web`; `git log -1 --format=%cd eb691db 1d4cdfa` |
| B4 | The bundle is mounted as the **directory** `./web:/opt/workshop/web:ro`; `scripts/build.sh` replaces it with `rm -rf "$WEB_DIR"/*` then `cp -a` — a non-atomic window in which `webServable` is false and `/` serves the placeholder. `restart.sh` deliberately does not rebuild the bundle. | `platform/compose.yml:645`; `scripts/build.sh:135-154`; `scripts/_common.sh:452-455` |
| B5 | `webHandler` reads the bundle directory **per request**: hashed assets are served `immutable`, other files `no-cache`, and `index.html` `no-store`. | `main.go:2739-2790` |
| B6 | The registry is loaded **once at boot** (`passagestore.Load`, `main.go:967-977`) and "nothing else in this codebase reloads the registry … outside server startup" (router.go R5 note). The container reads `curriculum` as a directory bind (`-registry /opt/workshop/curriculum/passages.jsonl`); an atomic rename swaps the inode inside the mount. | `main.go:967-977`; `internal/api/router.go:205-215`; `architecture.md` §3.3 (i) |
| B7 | `GET /api/index/status` returns `generation`, `state`, `pid_count`, `built_at`, `root_hash`. There is **no** endpoint that reports corpus counts by `kind` or `content_type`, the loaded registry's digest, the bundle's identity, or the feature flags. `/status` (`core/status.component.ts`) shows health, chapters, `web` true/false, index dir and the embed model reachability — no commit, no hashes. | `internal/api/router.go:215-263`; `status.component.ts:36-80` |
| B8 | A build-identity gate exists: `platform/gates/verify-build-identity.sh` with arm B1 (binary on disk) and B2 (served `/api/health`). It does not look at the bundle, the registry or the container. | `platform/gates/verify-build-identity.sh:1-30` |
| B9 | A backup-distinctness gate exists (`platform/gates/verify-backup-distinctness.sh`): fails if the backup shares an inode with the live file or no longer holds its bytes. Real-copy backups for the registry are the rule (a hardlink was lost on 2026-09-09, `ingest.sh` header). | `platform/gates/prove-backup-distinctness.sh:1-30`; `architecture.md` §3.2 step 3 |
| B10 | `restart.sh` is a full down/up that refuses when the tree is not quiescent (two `git status` readings 30 s apart); its header records a **~45-minute** cross-reference derivation after each start. | `scripts/restart.sh:1-60` |
| B11 | No `wire_*.go` file and no `// hook:` marker exists in `cmd/workshop-server` at commit `33e9760` (the hook split is a Wave-0 orchestrator task). | `ls cmd/workshop-server`; `grep -n '// hook:' main.go` |

## Clarifications

### Session 2026-10-20 *(decisions still `OPEN` carry the default this spec implements)*

- D1 `OPEN`: Must `source_commit` equal `HEAD` **strictly**? → **Default: input-classified.** A difference is a FAIL only
  when `git diff --name-only <source_commit>..HEAD` touches the server's compiled input set (backend module, `replace`d
  modules, `go:embed` files); a docs/evidence-only difference is a `NOTE`. Reason: strict equality would demand a rebuild
  and a ~45-minute restart for every evidence commit. A `--strict` flag provides the other behaviour.
- D2 `OPEN`: Does `restart.sh` refuse by default without a matching PASS verdict? → **Default: no for one release cycle**
  (`--require-verdict` is opt-in; the promote scripts always set it), then flip to default-on. Reason: changing the
  default of the script the operator uses daily needs the operator's explicit say-so.
- D3 `OPEN`: Who may read `/api/system/provenance`? → **Default: any signed-in user** (same gate as every `/api/*`
  route); the allow-listed fields contain hashes, counts and flag names, no URLs, hostnames or credentials. If the
  operator wants operator-only, that needs a role model that does not exist (UNCONFIRMED) and is out of scope.
- D4 *(resolved by task T004, not by a person)*: is `ng build` reproducible? Decides whether gate check G2 compares served
  vs freshly built, or served vs the recorded promotion manifest.
- D5 `OPEN`: a header-level "stale" indicator beyond the Status page — default not built.

## User Scenarios & Testing *(mandatory)*

### User Story 1 — The frontend the browser gets is the frontend that was built (Priority: P1)

The operator reloads the application and gets the current UI: the stale October-7 bundle is rebuilt from the source at
`HEAD`, promoted without taking the site down, and the bundle states which commit it was built from.

**Why this priority**: the operator's complaint is literally "I cannot see what you built". Everything the other specs
add to the UI is invisible until this is true.

**Independent Test**: after promotion, `sha256(GET /)` equals `sha256(index.html)` of the fresh build, and
`GET /build-info.json` names the workshop `HEAD`.

**Acceptance Scenarios**:

1. **Given** a built bundle in staging, **When** it is promoted, **Then** new content-hashed chunks are in place **before**
   `index.html` is replaced, `index.html` is replaced by a single rename, and a reader loop requesting `/` and every
   referenced chunk during the promotion never sees a 404 or a half-written file.
2. **Given** promotion is interrupted at any step (SIGTERM), **When** the site is next requested, **Then** it serves either
   entirely the old bundle or entirely the new one.
3. **Given** a promoted bundle, **When** `--rollback` runs, **Then** the previous `index.html` and build-info are restored
   and the site serves the old bundle again.
4. **Given** the same bundle is promoted twice, **When** the second runs, **Then** it reports "already promoted" and writes
   nothing.
5. **Given** a promoted bundle, **When** the operator reloads, **Then** every UI change committed after October 7 is
   present, shown by a stated walk-through (T020).

---

### User Story 2 — One gate says whether live equals built (Priority: P1)

A single command checks: (b) the served `source_commit` equals the repository `HEAD` and `source_dirty` is false;
(c) the served bundle equals the built bundle; (d) the registry digest agrees on the host, in the container and in the
running process; plus index and corpus coherence. It writes a machine verdict bound to the artefacts' fingerprint, and
the restart/promote scripts can refuse to proceed without a matching PASS.

**Why this priority**: without a gate, "implemented" and "served" drift again within a day (this tree's own history:
pins and bundles went stale four times in three days).

**Independent Test**: run the gate against the live stack now — it MUST be red on whatever is broken (recorded as the RED
baseline) — and green after promotion.

**Acceptance Scenarios**:

1. **Given** a stub stack where everything matches, **When** the gate runs, **Then** exit 0 and `verdict:"PASS"`.
2. **Given** each of: commit mismatch with input-relevant diff, dirty build, bundle mismatch, host≠container registry,
   container≠loaded registry, index count ≠ rows, build-info commit ≠ server commit, corpus total ≠ rows, **When** the
   gate runs, **Then** exit 1 and the failing check id is named.
3. **Given** the stack is down, no credential is available, no container runtime resolves, or the registry is unreadable,
   **When** the gate runs, **Then** exit 2 and the cause is named — never 0 and never 1.
4. **Given** a PASS verdict for fingerprint F, **When** the artefacts change before restart, **Then** `restart.sh
   --require-verdict` refuses (the fingerprint no longer matches).
5. **Given** each gate mutant (always-pass, ignores dirty, compares bundle to itself, treats "down" as PASS, reads the
   container digest from the host file), **When** the paired proof runs, **Then** the gate or its test suite goes red.

---

### User Story 3 — `/status` shows what is live (Priority: P1)

The Status page gains a **What is live** panel: build id and commit, whether the build is dirty, bundle manifest hash and
build-info commit, registry digest (loaded vs on disk), corpus counts by kind and by content type, index generation and
passage count, and the feature flags (answering on/off, rerank on/off, embedding model). A mismatch shows a plain-English
banner.

**Why this priority**: the operator should not need a terminal to know what they are looking at.

**Independent Test**: open `/status`; read the panel; its numbers equal an independent computation from the files.

**Acceptance Scenarios**:

1. **Given** a running stack, **When** `/status` opens, **Then** every fact above is shown with a label and a value, and the
   counts by content type sum to the total.
2. **Given** the registry file on disk changed after boot, **When** the panel loads, **Then** it says the file on disk is not
   what the running server loaded.
3. **Given** the bundle's build-info commit differs from the server's commit, **When** the panel loads, **Then** it says the
   frontend and backend come from different builds.
4. **Given** the provenance endpoint is unavailable, **When** the panel loads, **Then** the rest of the Status page still
   renders and the panel says it could not determine, with the cause — never a blank.
5. **Given** the provenance response, **When** inspected, **Then** it contains no URL, hostname, credential or token (leak
   test).

---

### User Story 4 — A new registry goes live safely, once, and can be undone (Priority: P2)

The orchestrator puts a candidate `passages.jsonl` live with one procedure: validated as a pure addition, backed up (real
copy, §9), swapped atomically, journalled, and reversible; repeating it is a no-op.

**Why this priority**: 018's research delta and 020's textbooks both need it; without it each would invent its own.

**Independent Test**: fixture rehearsal (promote → boot → verify → rollback) and a live no-op promotion.

**Acceptance Scenarios**:

1. **Given** a candidate that contains every current line byte-for-byte plus new rows, **When** `--apply` runs, **Then** it is
   accepted; a candidate that changes or drops a line, or has fewer rows, is refused (override needs a stated reason).
2. **Given** `--apply`, **When** it runs, **Then** a real-copy backup (different inode) with a pre-write digest exists before
   any write, and the swap is temp-file + rename in the same directory.
3. **Given** the candidate equals the live file, **When** `--apply` runs, **Then** it exits 0 "already promoted" with no
   write, no backup and no journal row.
4. **Given** a promotion, **When** `--rollback <run>` runs, **Then** the live file's digest equals the recorded pre-promotion
   digest and the rollback is journalled.
5. **Given** any interruption, **When** the live file is read, **Then** it is the complete old file or the complete new file.
6. **Given** the journal, **When** `--status --verify` runs, **Then** a tampered or reordered row is detected (hash chain).

---

### User Story 5 — Drift announces itself (Priority: P3)

`scripts/status.sh` prints one informational line, `live-vs-built: PASS|FAIL|UNDETERMINED`, without changing its exit
contract; the Status page banner covers browser users.

**Acceptance Scenarios**: (1) the line appears within a 5-second budget or reads UNDETERMINED; (2) `status.sh`'s own exit
codes and `verify-status-exit-contract.sh` are unchanged.

---

### Edge Cases

- The tree has a docs-only commit after the build: D1 default classifies it as a NOTE, `--strict` makes it a FAIL.
- Two promotions race: the second sees the first's journal row and the `registry-promote` long-op owner and refuses (rc 2).
- The container is up but the registry bind is a single-file mount (inode pinned): the gate's G3 compares host vs container
  digests and FAILS naming "bind mount pinned to an old inode" — the symptom this spec's design was built around.
- `ng build` is not reproducible (D4): G2 compares served vs recorded promotion manifest; the report says so.
- Very large registry hash on a loaded host: first hash is cached by (mtime,size); the panel shows "measuring…" never a stale value.
- Browser tab holding the old `index.html` after `--prune`: lazy chunk 404 → the app's own error state; `--prune` waits the
  recorded grace period for this reason.
- Evidence files must never contain a token, password shape, or any `http` URL from the flags block.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: `scripts/promote-web.sh` MUST build (`npm ci` + `ng build --configuration production`, bounded), stage, and
  promote the bundle additively: new hashed assets first, `index.html` replaced by a single rename, `build-info.json`
  written, old assets removed only by explicit `--prune` after a recorded grace period; it MUST NOT `rm -rf` the served
  directory.
- **FR-002**: Promotion MUST be interruption-safe (served directory is entirely old or entirely new at every step), idempotent
  (same bundle twice → no writes) and reversible (`--rollback`).
- **FR-003**: The bundle MUST carry `build-info.json` `{commit, dirty, built_at, node, lockfile_sha256}` generated at build
  time, git-ignored, containing no path or hostname.
- **FR-004**: `GET /api/system/provenance` (session required) MUST return the build block, web block (servable, file count,
  manifest sha256, `index.html` sha256, parsed build-info, `build_info_matches_server_commit`), registry block (basename,
  `loaded_sha256`, `loaded_rows`, `disk_sha256`, `disk_mtime`, `disk_matches_loaded`), corpus block (`total`, `by_kind`,
  `by_content_type`, `suppressed`), index block (`generation`, `state`, `pid_count`, `root_hash`, `built_at`,
  `pid_count_matches_registry`) and features block (allow-listed names only).
- **FR-005**: The provenance response MUST NOT contain any URL, hostname, key, token, secret or password; this is enforced by
  an allow-list of fields and a test (fail closed, §11.4.252).
- **FR-006**: Hashing in the endpoint MUST be cached by file stat signature and MUST NOT run per request when nothing changed.
- **FR-007**: `scripts/deploy-gate.sh` MUST implement checks G0-G7 of `contracts/deploy-gate-verdict.md`, exit 0/1/2, and write a
  verdict JSON containing the candidate fingerprint (`server_bin_sha256`, `bundle_manifest_sha256`, `registry_sha256`).
- **FR-008**: The gate MUST obtain the bundle comparison over two independent channels: the server-reported manifest and a
  direct `GET /` hash compared to the built `index.html`.
- **FR-009**: The gate MUST compare the registry digest on the host, inside the container (via the repo's runtime resolution,
  §11.4.76) and as loaded by the process; any "cannot read" is exit 2.
- **FR-010**: `restart.sh --require-verdict <file>` and the promote scripts MUST refuse without a parseable PASS verdict whose
  fingerprint equals the one recomputed now; an override MUST be explicit, reasoned and journalled (§11.4.236).
- **FR-011**: `scripts/promote-registry.sh` MUST implement US4 including superset validation, real-copy backup with pre-digest,
  atomic swap, no-op detection, rollback and a hash-chained append-only journal at `.backups/promotions.jsonl`.
- **FR-012**: The Status page MUST show the What is live panel from FR-004 with plain-English mismatch banners and an explicit
  could-not-determine state; no raw status codes or error codes are shown to the user.
- **FR-013**: Every check outcome that cannot be determined MUST say so and name the cause; "unknown" is never mapped to PASS.
- **FR-014**: The feature MUST ship a user manual, three task guides, an FAQ and the four diagram classes (§11.4.257,
  §11.4.258), exported (§11.4.65) and validated by a separate agent (§11.4.168).
- **FR-015**: The feature MUST ship a live verification script writing `result.json` and a sha256 manifest, and its RED baseline
  on the broken artefact before any promotion (§11.4.115, §11.4.262).

### Key Entities

- **Bundle manifest** — sorted `(relpath, sha256)` lines of the served web directory and the hash of that listing.
- **Candidate fingerprint** — `(server_bin_sha256, bundle_manifest_sha256, registry_sha256)` of what is about to be deployed.
- **Verdict** — the gate's JSON: checks, expected/observed, rc, fingerprint, `PASS|FAIL|UNDETERMINED`.
- **Promotion** — one run of `promote-web.sh` or `promote-registry.sh`: run id, candidate digest, backup, steps, outcome.
- **Journal row** — append-only record `{ts, run, kind, pre_sha256, post_sha256, backup, outcome, prev_sha256}`.
- **Provenance** — the read-only JSON of FR-004.

## Success Criteria *(mandatory)*

- **SC-001**: After promotion, `sha256(GET /)` == `sha256(built index.html)` and `build-info.commit` == `HEAD` (before: bundle
  predates two frontend commits).
- **SC-002**: During promotion, requests for `/` and every referenced asset: 404 count = 0, 5xx count = 0 (reader loop), including
  under SIGTERM at each step.
- **SC-003**: The gate is RED on the pre-promotion live state for at least the checks that are broken, and GREEN after; both
  verdicts are on file. Gate mutants M1-M6 are all caught.
- **SC-004**: The What is live panel's numbers equal an independent computation: bundle manifest, registry sha, row counts by
  kind and content type (difference = 0).
- **SC-005**: A registry promotion changes pre-existing lines = 0, creates a distinct-inode backup, and `--rollback` restores the
  recorded pre-digest; a repeated promotion writes nothing.
- **SC-006**: Provenance leak test: 0 URL/host/credential-shaped strings.
- **SC-007**: `restart.sh --require-verdict` refuses with a stale/forged fingerprint (100% of mutants).
- **SC-008**: An operator reads every fact on `/status` without a terminal (UI-visible acceptance T051).

## Assumptions

- The live stack is the single compose project; only the orchestrator restarts it; worktree streams verify on an isolated
  server.
- `restart.sh` is a full down/up with a long boot; this feature does not shorten the boot, it makes its cost and outcome visible.
- The Angular bundle can be built on this host (`node`/`npm` present; peak memory fits under the bounded wrapper) — verified by
  T004/T018, not assumed.
- Answering stays OFF; reranker settings are not changed by any task here.

## Out of Scope

- Progressive delivery / canary (§11.4.265) — the stack is a single local container; recorded as latent in `plan.md`.
- Changing `scripts/build.sh`'s in-place bundle replacement (recorded as a finding and follow-up).
- Role-based access to the panel (D3).
- Making embedding or index boot faster.
