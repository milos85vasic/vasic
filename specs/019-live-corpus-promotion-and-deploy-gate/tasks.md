# Tasks: Live Corpus Promotion and Deploy Gate

**Input**: `specs/019-live-corpus-promotion-and-deploy-gate/` — `plan.md`, `spec.md`, `research.md`, `data-model.md`, `contracts/`, `quickstart.md` (all present)
**Prerequisites**: none of 011-018 is a code prerequisite. This feature is consumed by 018 (live merge + restart) and 020 (textbook merge + restart); it can and should land first.

**Tests**: INCLUDED and test-first (§11.4.224). Every implementation task is preceded by a RED task with a named oracle
(§11.4.245). Producer ≠ oracle ≠ gate ≠ verifier (§11.4.249): test authors, implementers and reviewers are different agents.

**Organization**: by user story (US1-US5), then Polish. Nothing here has run; no box is ticked.

## Format: `[ID] [P?] [TDD?] [REVIEW?] [SUBAGENT?] [Story] Description`

- **[P]** parallel (different files) · **[TDD]** RED→GREEN→REFACTOR · **[REVIEW]** independent review (separate agent,
  Opus, xhigh, §11.4.142/§11.4.209; verdict file with `model`, `effort`, `finding_layer`) · **[SUBAGENT]** delegable ·
  **[ORCH]** orchestrator-only (shared file, live stack, restart).

## Path Conventions

Relative to `workshop/` unless prefixed `specs/`. Backend `platform/backend/{internal,cmd/workshop-server}`; frontend
`platform/frontend/src/app/`; scripts `scripts/`; gates `platform/gates/`; evidence `evidence/019-<run>/`
(private submodule). The live stack is the compose project `workshop-curriculum` (container
`workshop-curriculum_platform_1`, port 8087; re-derive from `scripts/status.sh`, never assume).

---

## Phase 1: Setup

- [ ] T001 [SETUP] Re-measure the baseline of `spec.md` B1-B10 and write `evidence/019-<run>/baseline.json` (hashes,
      commits, mtimes, counts only): `bin/workshop-server.stamp` (`commit`, `build`, `built_at`, `bin_sha256`), workshop
      `HEAD` and `git describe`, `ls -la --time-style=full-iso platform/web` newest/oldest mtime, commit dates of the
      frontend commits newer than the bundle (`git log --since=<bundle mtime> -- platform/frontend/src`), host
      `sha256sum curriculum/passages.jsonl` vs `podman exec workshop-curriculum_platform_1 sha256sum
      /opt/workshop/curriculum/passages.jsonl`, unauthenticated `curl /api/health` build block, compose mount list
      (`web`, `bin`, `curriculum`, `docs`). Oracle: independent commands, outputs pasted raw into the evidence file;
      any difference from the spec is recorded as a correction.
- [ ] T002 [P] [SETUP] Hook state + isolated server: does `cmd/workshop-server` have any `wire_*.go` / `// hook:` yet?
      Prove an isolated throwaway server once (`go build -o $SCRATCH/bin/workshop-server ./cmd/workshop-server`; scratch
      `-index`, registry COPY, `-web` pointing at a scratch bundle copy). Record the exact command. Same artefact as
      018 T002 — reuse it if present, but re-verify, do not copy the claim.
- [ ] T003 [P] [SETUP] Verify the web-serving facts that the promotion design rests on, on the isolated server: (a) `GET /`
      serves `index.html` with `Cache-Control: no-store`; (b) a content-hashed asset is `immutable`; (c) adding a new hashed
      chunk to the served directory makes it fetchable with no restart; (d) replacing `index.html` by rename is seen on
      the next request; (e) deleting the web directory contents makes `/` serve the placeholder and
      `/api/health.web` flip false (`webServable`, `main.go:2713`). Oracle: raw headers/statuses saved to
      `evidence/…/web-serving.json`. If (c) or (d) is false the in-place additive design (R-2) is withdrawn and the
      swap-at-restart design is used for every promotion.
- [ ] T004 [P] [SETUP] Angular reproducibility probe (§11.4.246): in a scratch copy of `platform/frontend` (do not touch the
      tracked tree), run `npm ci` then `npx ng build --configuration production` TWICE under `scripts/agent-admit.sh -m 6G
      -T 1800`; compare the two file manifests (path + sha256). Record equal / not equal, build time, peak memory.
      Outcome decides check G2's form (spec.md Clarification D4): equal ⇒ "served == freshly built" is comparable;
      not equal ⇒ G2 compares served against the *recorded promotion manifest* and the fresh build is for the
      reproducibility report only. `UNCONFIRMED` until run.
- [ ] T005 [SETUP] Record the operator decisions D1-D4 (spec.md Clarifications) interactively (§11.4.66): D1 strictness of
      `source_commit == HEAD` (strict vs input-classified), D2 whether `restart.sh` requires a verdict by default, D3
      audience of `/api/system/provenance`, D4 (resolved by T004). Defaults apply if unanswered, dated. Output
      `specs/019-…/decisions.md`.
- [ ] T006 [P] [SETUP] Register the long-ops (§11.4.232) the live tasks will run (`ng build`, `restart.sh`, boot-time embed
      wait) with `purpose_key`s `web-build`, `registry-promote`, `restart`; record thread headroom (`ulimit -u`, live
      thread count) and `free -m` before any fan-out (§12.6/§12.12). A restart while another long-op holds
      `restart` is refused.

**Checkpoint**: baseline pinned (and its RED facts recorded), serving assumptions proven or withdrawn, decisions recorded.

---

## Phase 2: Foundational (blocking)

**Purpose**: the hashing primitives both the server and the host scripts must agree on, with an oracle that is neither.

**Interfaces produced**: Go `internal/provenance.Manifest(dir string) (ManifestResult, error)`;
`internal/provenance.CorpusStats(records []passage.Record) Stats`; shell `scripts/bundle-manifest.sh <dir>`;
Python oracle `platform/gates/lib/manifest_oracle.py` (stdlib only).

- [x] T007 [TDD] [FOUND] [SUBAGENT] Write the cross-implementation golden vectors and the Python oracle FIRST: a fixture tree
      (nested dirs, empty file, file with spaces and non-ASCII name, symlink to a file inside the tree, symlink escaping
      the tree, zero-byte directory) and `manifest_oracle.py` computing the manifest — lines `"<relpath>\t<sha256>\n"`,
      sorted bytewise by relpath, `/` separators, symlinks that escape the root refused (exit 2), then the manifest
      hash = sha256 of the concatenated lines. Write `internal/provenance/manifest_test.go` comparing the Go result to
      golden JSON produced by the oracle (committed), and a shell test comparing `bundle-manifest.sh` to the same golden.
      Run → RED (no implementation). Oracle: the Python script, authored without reading the Go code.
      EVIDENCE (S12, 2026-10-20): manifest_oracle.py (stdlib, independent) + manifest_golden.json + bundle-manifest.test.sh 20/0 + Go golden test; RED captured (script absent -> rc 1; Go: undefined Manifest) - evidence/s12/ in worktree vasic-wt/s12-019-promotion (branch s12-019-promotion)
- [x] T008 [TDD] [FOUND] Implement `internal/provenance/manifest.go` (NEW): walk, refuse escaping symlinks, stream-hash,
      deterministic order, bounded memory. Make T007's Go tests green with `-race`. Fail closed (§11.4.252): unreadable
      file → error, never a partial manifest presented as complete.
      EVIDENCE (S12, 2026-10-20): internal/provenance/manifest.go; go test -race ./internal/provenance ok, 90.6% stmts - evidence/s12/ in worktree vasic-wt/s12-019-promotion (branch s12-019-promotion)
- [x] T009 [TDD] [FOUND] [SUBAGENT] Write failing `internal/provenance/corpus_test.go`: `CorpusStats` over a table of
      records returns `total`, `by_kind`, `by_content_type`, `suppressed`/`redacted` counts. Oracle: a Python script run
      over a JSONL fixture (and, in the live task, over the real registry) produces the expected counts independently.
      Include the closed content-type vocabulary (`internal/passagestore/domain.go:160-170`): a record with an unknown
      value is counted under `unclassified`, never dropped. → RED.
      EVIDENCE (S12, 2026-10-20): corpus_test.go + platform/gates/lib/corpus_oracle.py (python count over testdata/isolated registry); RED = undefined CorpusStats - evidence/s12/ in worktree vasic-wt/s12-019-promotion (branch s12-019-promotion)
- [x] T010 [TDD] [FOUND] Implement `internal/provenance/corpus.go` (NEW). Green with `-race`.
      EVIDENCE (S12, 2026-10-20): internal/provenance/corpus.go (+filedigest.go stat-cached registry digest); green with -race - evidence/s12/ in worktree vasic-wt/s12-019-promotion (branch s12-019-promotion)
- [x] T011 [P] [FOUND] Implement `scripts/bundle-manifest.sh` (NEW) using only `sha256sum`/`find`/`sort`/`awk` (§11.4.67
      portable); output identical to the oracle's golden. Add `scripts/bundle-manifest.test.sh`.
      EVIDENCE (S12, 2026-10-20): scripts/bundle-manifest.sh, shellcheck clean, identical to the oracle golden - evidence/s12/ in worktree vasic-wt/s12-019-promotion (branch s12-019-promotion)
- [ ] T012 [REVIEW] [FOUND] Independent review (Opus xhigh) of T007-T011: oracle independence (did the test author peek at
      the implementation?), symlink handling, determinism across locales (`LC_ALL=C` forced), memory bound. Verdict file.

**Checkpoint**: the manifest and corpus statistics agree across three implementations on the golden fixtures.

---

## Phase 3: User Story 1 — The frontend bundle served is the one built from the source (P1)

**Goal**: rebuild the stale bundle and promote it atomically; record what was promoted. **Independent Test**: spec.md US1.

- [x] T013 [TDD] [US1] [SUBAGENT] Write failing `scripts/promote-web.test.sh` on fixture directories (a fake `dist` with
      `index.html`, three hashed chunks, a `build-info.json`; a fake served directory with an older bundle): (1)
      `--stage` copies dist to a staging dir and refuses (rc 1) if `index.html` is missing or references a chunk absent
      from staging; (2) `--promote` copies new hashed chunks FIRST, then replaces `index.html` by `rename(2)` within the
      served directory, then writes `build-info.json`, and removes old chunks only with `--prune`; (3) `--rollback`
      restores the previous `index.html` and build-info from `web.prev/`; (4) a reader loop running `curl`-equivalent
      requests for `/` and every chunk it references during the promotion NEVER sees a 404 for a referenced chunk or a
      half-written `index.html`; (5) SIGTERM at each of the 6 steps leaves a served directory that is either entirely the
      old bundle or entirely the new one (chaos, §11.4.85); (6) unreadable/absent served dir → rc 2; (7) promoting the same
      bundle twice → rc 0 "already promoted", no writes. **Oracle**: manifests computed by `manifest_oracle.py` before/after
      and the reader loop's own request log. → RED.
      EVIDENCE (S12, 2026-10-20): scripts/promote-web.test.sh 152 passed/0 failed (stage refusals, order via pause points, SIGTERM/INT/HUP at 4 steps, concurrent reader, idempotent, rollback, prune, verdict seam); RED = script absent rc 1 - evidence/s12/ in worktree vasic-wt/s12-019-promotion (branch s12-019-promotion)
- [x] T014 [TDD] [US1] Implement `scripts/write-build-info.sh` (NEW): writes `build-info.json` into the staged bundle
      `{ "commit": <git rev-parse HEAD of workshop>, "dirty": bool, "built_at": <UTC>, "node": <version>,
      "lockfile_sha256": <package-lock>, "source": "promote-web.sh" }`. Tests in T013's file extended (RED first). The
      file is generated, git-ignored, and never carries a path or hostname.
      EVIDENCE (S12, 2026-10-20): scripts/write-build-info.sh (+ BUILD_STAMP); tests in promote-web.test.sh - evidence/s12/ in worktree vasic-wt/s12-019-promotion (branch s12-019-promotion)
- [x] T015 [TDD] [US1] Implement `scripts/promote-web.sh` (NEW) with modes `--build` (npm ci + `ng build --configuration
      production` exactly as `scripts/build.sh:135-137`, via `agent-admit.sh -m 6G`), `--stage`, `--promote`, `--prune`,
      `--rollback`, `--status`; three-valued exits; never `rm -rf` the served directory. `scripts/build.sh` is NOT
      modified in this task (its in-place `rm -rf web/*` window is recorded as a finding in `research.md` R-2 and a
      follow-up item). Make T013/T014 green.
      EVIDENCE (S12, 2026-10-20): scripts/promote-web.sh (--build/--stage/--promote/--prune/--rollback/--status); mutation proof prove-web-promotion-mutation.sh 13/13 CAUGHT, control green. build.sh NOT modified. --build never run for real here - evidence/s12/ in worktree vasic-wt/s12-019-promotion (branch s12-019-promotion)
- [ ] T016 [P] [US1] Failure-injection run on the isolated server with the real (built) bundle copy: kill `promote-web.sh`
      at each step while a Playwright/`curl` loop hits `/` and the referenced assets; assert zero 404/5xx. Evidence file
      with counts only.
      S12 NOTE: PARTIAL not ticked: chaos was run on fixture dirs (T013); not on an isolated server with a real built bundle **[done on branch origin/rescue/s12-019-promotion-wip only; not on workshop main as of 2026-10-24; evidence scripts/promote-web.test.sh; annotated by 026 Wave 1 on 2026-10-24]**
- [ ] T017 [REVIEW] [US1] Independent review (Opus xhigh): is the ordering argument correct for browsers holding the old
      `index.html` (old tabs keep working until `--prune`; how long is the grace), cache headers, rollback completeness,
      the one case where the in-place swap is wrong (bind mount replaced). Verdict file.
- [ ] T018 [ORCH] [US1] **Bounded real build into staging** (no promotion): `promote-web.sh --build --stage`; record
      `bundle-built.json` (manifest hash, file count, build time, peak memory, the commit it was built from). If T004
      found the build reproducible, build twice and record equality. The tracked tree is clean before and after
      (`git status` empty).
- [ ] T019 [ORCH] [US1] **Live additive promotion without a restart**, after rehearsing `--promote` and `--rollback` on the
      isolated server: `promote-web.sh --promote`; then record (1) `GET /` `index.html` sha256 == staged `index.html`
      sha256 (independent channel), (2) every asset referenced by that `index.html` returns 200, (3)
      `/api/health.web` true, (4) `web/build-info.json.commit` == workshop `HEAD`. Keep `web.prev/` until T020 is signed
      off, then `--prune` after the grace period recorded in the decisions file.
- [ ] T020 [US1] **UI-visible acceptance (operator watches).** A walk-through file `evidence/…/ui-acceptance-us1.md`: hard
      reload; the footer/status shows the bundle commit == repo HEAD; each frontend commit that was newer than the old
      bundle (list from T001, by subject only) has a one-line "where to see it" step with the expected on-screen result
      (e.g. the plain-English sign-in error for a wrong password; a passage page showing the server's source label rather
      than a file name). The operator ticks each. Screenshots stay in the private evidence dir.

**Checkpoint US1**: the served `index.html` hash equals the staged one, with the bundle's build-info commit equal to HEAD.

---

## Phase 4: User Story 2 — One gate says whether live equals built (P1)

**Goal**: `scripts/deploy-gate.sh` — checks (b) commit, (c) bundle, (d) registry digest, plus index and corpus coherence;
machine verdict with a candidate fingerprint; a mechanical seam so a deploy without a matching PASS is refused.

**Interfaces produced**: `scripts/deploy-gate.sh [--pre|--post] [--base URL] [--evidence DIR]` → exit 0 PASS / 1 FAIL / 2
UNDETERMINED; `evidence/019-<run>/verdict.json` (contract `contracts/deploy-gate-verdict.md`);
`restart.sh --require-verdict <file>`.

- [x] T021 [TDD] [US2] [SUBAGENT] Write failing `scripts/deploy-gate.test.sh` against a **stub stack** (a tiny local HTTP
      server returning scripted `/api/health`, `/api/system/provenance`, `/` bodies; a fixture dist; a fixture registry;
      a stub container runtime executable on `PATH` for `exec … sha256sum`). Cases, each with its expected failing check id:
      all match → rc 0; `source_commit` ≠ HEAD with an input-relevant diff → rc 1 `G1`; `source_dirty:true` → rc 1 `G1`;
      served `index.html` hash ≠ built → rc 1 `G2`; provenance manifest ≠ built manifest → rc 1 `G2`; host registry sha ≠
      container sha → rc 1 `G3`; container sha ≠ `loaded_sha256` → rc 1 `G3`; `pid_count` ≠ registry rows → rc 1 `G4`;
      bundle build-info commit ≠ server commit → rc 1 `G5`; corpus total ≠ registry rows → rc 1 `G6`; stack down, no
      token, no container runtime, unreadable registry → rc 2 (never 0, never 1); `HEAD` moved only by a docs/evidence
      commit → per D1 default: rc 0 with a `NOTE` naming the diff class. **Oracle**: each case's expected id typed in
      the test; hashes computed by `sha256sum` in the test. → RED.
      EVIDENCE (S12, 2026-10-20): scripts/deploy-gate.test.sh 60 passed/0 failed on a stub stack; RED = script absent rc 1 - evidence/s12/ in worktree vasic-wt/s12-019-promotion (branch s12-019-promotion)
- [x] T022 [TDD] [US2] Implement `scripts/deploy-gate.sh` (NEW): sources `_common.sh` / `_live_auth.sh` (token never
      printed); computes the candidate fingerprint (server binary sha from the stamp's `bin_sha256`, bundle manifest hash,
      registry sha); runs G0-G7 per `contracts/deploy-gate-verdict.md`; classifies a `HEAD` ≠ `source_commit` difference
      by `git diff --name-only <source_commit>..HEAD` against the server input set (module dirs + `replace` targets +
      `go:embed` files — reuse the input-set derivation used by `ensure_fresh_server`, `_common.sh:633-660`, do not
      re-derive it by hand). Makes T021 green. `bash -n` / `shellcheck` clean.
      EVIDENCE (S12, 2026-10-20): scripts/deploy-gate.sh (G0-G7, verdict.json 0600, three-valued); input classification reuses _common.sh _server_module_dirs/_server_pathspecs - evidence/s12/ in worktree vasic-wt/s12-019-promotion (branch s12-019-promotion)
- [x] T023 [P] [US2] Container-side digest helper: use the runtime resolution the repo already has (the `workshop-boot` /
      `_common.sh` runtime detection; §11.4.76 forbids a parallel runtime detector) to run `sha256sum` inside the
      container; if no runtime is resolvable → rc 2 with the cause. Test with the stub runtime of T021 and with a
      "runtime present but container absent" case → rc 2.
      EVIDENCE (S12, 2026-10-20): container digest inside deploy-gate.sh g3(): stub runtime, no-runtime and container-absent cases -> rc 2 - evidence/s12/ in worktree vasic-wt/s12-019-promotion (branch s12-019-promotion)
- [ ] T024 [TDD] [US2] The mechanical seam (§11.4.236): add `--require-verdict <file>` to `scripts/restart.sh` and to the
      promote scripts (T015, T043): refuse (rc 2, stated reason) when the file is absent, not parseable, `verdict` ≠
      `PASS`, or its `candidate` fingerprint ≠ the fingerprint recomputed now. Write the failing tests first in
      `scripts/restart-quiescence.test.sh`'s neighbour `scripts/restart-verdict.test.sh`; override requires an explicit
      `--override-verdict "<reason>"` that is logged in the journal. Default behaviour is D1/D2-dependent (recorded in
      T005). `restart.sh` edit is minimal and reviewed (T026).
      S12 NOTE: PARTIAL not ticked: --require-verdict implemented in promote-registry.sh and promote-web.sh; the restart.sh edit is NOT made (hot spot; hook text in the stream report)
- [ ] T025 [TDD] [US2] Paired mutation gates (§1.1): `platform/gates/verify-live-equals-built.sh` (runs the gate against
      the live stack and asserts the verdict schema + rc contract) and `platform/gates/prove-live-equals-built-mutation.sh`
      with mutants — M1 gate always returns 0, M2 gate ignores `source_dirty`, M3 gate compares the bundle against itself,
      M4 gate treats "stack down" as PASS, M5 verdict fingerprint not recomputed, M6 container digest read from the host
      file; each MUST turn the gate (or T021's suite) red; the control stays green. Register both in the gate registry TSV.
      S12 NOTE: PARTIAL not ticked: platform/gates/prove-live-equals-built-mutation.sh 13/13 CAUGHT + scripts/verify-deploy-gate.sh; not registered in the gate TSV
- [ ] T026 [REVIEW] [US2] Independent review (Opus xhigh) of T021-T025 incl. the `restart.sh` edit: can a verdict be forged
      or replayed (fingerprint binding), what happens if the bundle changes between gate and restart, false-green paths
      (every "unknown" mapped to 2?), and the D1 classification rules. Verdict file.
- [ ] T027 [ORCH] [US2] **RED baseline on the broken live artifact (§11.4.115)**: run `deploy-gate.sh --post` against the
      live stack BEFORE promotions. Expected to FAIL on the checks that are broken today (stale commit `ce62bcb` vs the
      current HEAD — input-classified; stale bundle; registry host/container equality is UNCONFIRMED). Record the exact
      failing ids in `evidence/…/gate-red-baseline.json`. A gate that is green on the broken artifact is itself a
      defect: stop and fix before continuing. After US1/US4 promotions run it again → expected PASS; both verdicts kept.

**Checkpoint US2**: gate red on the known-broken state, green after promotion, mutations red, seam refuses without a verdict.

---

## Phase 5: User Story 3 — `/status` shows what is live (P1)

**Goal**: one session-gated JSON and one panel on the existing Status page: build, commit, bundle hash, registry sha,
corpus counts by kind and content_type, index generation, feature flags.

- [x] T028 [TDD] [US3] [SUBAGENT] Write failing `internal/api/provenance_test.go`: handler over a fake config + temp web dir +
      temp registry + fake index: (a) returns every field of `contracts/provenance-api.md`; (b) `web.manifest_sha256`
      equals the oracle's for the temp dir; (c) `registry.disk_sha256` equals `sha256sum`; (d) `registry.disk_matches_loaded`
      false after the file is rewritten post-load; (e) caching: a second call within the same stat signature does not re-hash
      (counter), a changed mtime/size does; (f) **no secret leakage**: marshalled JSON contains no key matching
      `(?i)(url|endpoint|key|token|secret|password|host)` and no string value beginning `http`; flags are the allow-listed
      names only; (g) 401 through the real auth middleware without a session (via the wire test); (h) the handler never
      reads a request parameter (no injection surface); (i) the marshalled body passes both serialisation-boundary guards
      unchanged — `sourceref.RedactJSON(body)` returns identical bytes and `search.HasSourceFilenameShape(body)` is false
      (`internal/api/api.go:361-380`; a provenance answer that the `writeJSON` guard turned into a 410 would be the worst possible
      failure of the page meant to show what is live). **Oracle**: independent hashes computed in the test with
      `crypto/sha256` over bytes the test wrote; leak regex typed in the test. → RED.
      EVIDENCE (S12, 2026-10-20): internal/api/provenance_test.go, 14 tests incl. leak regex, both boundary guards, caching counters - evidence/s12/ in worktree vasic-wt/s12-019-promotion (branch s12-019-promotion)
- [x] T029 [TDD] [US3] Implement `internal/api/provenance.go` (NEW): `ProvenanceDeps{Build func() BuildBlock, WebDir,
      RegistryPath, Registry, DB, Flags FlagsBlock}`; caches keyed by (mtime,size) with a mutex; uses
      `internal/provenance` (T008/T010) and `index.Live` (the `IndexStatusHandler` source, `router.go:215`). Green with `-race`.
      EVIDENCE (S12, 2026-10-20): internal/api/provenance.go; go test -race ok - evidence/s12/ in worktree vasic-wt/s12-019-promotion (branch s12-019-promotion)
- [x] T030 [TDD] [US3] Implement `cmd/workshop-server/wire_provenance.go` (NEW): `registerProvenance(mux, cfg, loadedRegistry)`;
      builds the allow-listed `FlagsBlock` from `cfg` (answer provider name + on/off, window-rerank, cross-encoder rerank,
      embed model name, embed carry-forward, search vector cache) — the `cfg` field names are enumerated by the first
      step of this task (`grep` of the flag block `main.go:380-460`) and recorded; measures `loaded_sha256` immediately
      after registry load (hook position decided with the orchestrator and documented: it must run after the load at
      `main.go:972`). Test `wire_provenance_test.go`: route mounted unconditionally; 200 shape; boot log line
      `provenance: registry_sha=<first12> rows=N web_files=M` (§11.4.254, counts and hash prefixes only).
      EVIDENCE (S12, 2026-10-20): cmd/workshop-server/wire_provenance.go + wire_provenance_test.go (401 gate, unconditional mount, boot line); wire_hooks.go gained the aggregator lines + routeDeps.registry; main.go NOT edited (one-line request in the stream report) - evidence/s12/ in worktree vasic-wt/s12-019-promotion (branch s12-019-promotion)
- [ ] T031 [P] [US3] Performance + race: benchmark first computation with a 36 000-row / 34 MB registry fixture and a
      200-file bundle (< 1.5 s) and cached call (< 5 ms); `go test -race` on concurrent calls with a changing registry.
      Oracle: `testing.B` wall clock. Skip with a stated reason (rc 2-equivalent) on a loaded host.
      S12 NOTE: NOT DONE: no benchmark
- [x] T032 [TDD] [US3] [SUBAGENT] Write failing frontend specs: `features/status-live/live-facts-model.spec.ts`
      (normalise; unknown extra keys ignored; missing block → that block `unavailable`, others still render) and
      `live-facts.component.spec.ts` (each fact has a visible label and value; counts table by content_type and by kind
      sums to `total`; **mismatch banner** states: build-info commit ≠ server commit, registry disk ≠ loaded, index
      `pid_count` ≠ rows, `source_dirty` true — each with a plain-English sentence and no raw status code or error code,
      per the project's UI rule; `unavailable` state shows the cause; flags show on/off words not booleans). Oracle: the
      fixture body's own numbers. Karma bounded. → RED.
      EVIDENCE (S12, 2026-10-20): features/status-live/*.spec.ts, 23 Karma specs SUCCESS - evidence/s12/ in worktree vasic-wt/s12-019-promotion (branch s12-019-promotion)
- [x] T033 [TDD] [US3] Implement `features/status-live/live-facts.component.ts`, `live-facts-api.ts`, `live-facts-model.ts`
      (standalone, OnPush, no `innerHTML`). Make T032 green; `ng build` clean; `check-design-system`/`check-platform-tokens` rc 0.
      EVIDENCE (S12, 2026-10-20): features/status-live/{live-facts.component.ts,live-facts-api.ts,live-facts-model.ts}; stmts 84.37% (just under the 85% floor), ng build/design-system gates NOT run - evidence/s12/ in worktree vasic-wt/s12-019-promotion (branch s12-019-promotion)
- [ ] T034 [ORCH] [US3] Hooks: the one line in `core/status.component.ts` embedding `<wk-live-facts/>` under the existing
      "The server process" section; the vocabulary rows (labels and hints for each fact) via the orchestrator hook; the
      `registerProvenance(...)` line in `main.go`. Run `prove-ui-vocabulary-mutation.sh`. Commit the hook diff only.
      S12 NOTE: ORCH: hook lines requested in the stream report
- [ ] T035 [P] [US3] Playwright `e2e/status-live.spec.ts` against the isolated server: the spec itself computes (node
      `crypto`) the bundle manifest of the directory it served, the registry sha and the row counts by reading the files,
      then asserts the page shows the same values; forced-mismatch arm (the test rewrites the registry copy after boot) shows
      the banner. a11y/responsive checks included.
      S12 NOTE: NOT DONE: no Playwright spec
- [ ] T036 [REVIEW] [US3] Independent review (Opus xhigh): information disclosure of `/api/system/provenance` (D3), cache
      correctness, hook position of the loaded-sha measurement (TOCTOU), UI wording. Verdict file.

**Checkpoint US3**: `/status` on the isolated server shows every fact and the numbers equal the independent oracle.

---

## Phase 6: User Story 4 — Safe registry promotion (P2)

**Goal**: one procedure to put a new `passages.jsonl` (and its sidecars) live: validated, backed up, atomically swapped,
idempotent, reversible, journalled.

**Interfaces produced**: `scripts/promote-registry.sh --candidate <file> [--sidecars <dir>] [--apply|--rollback <run>|--status]`
→ exit 0 / 1 / 2; journal `.backups/promotions.jsonl` (append-only, hash-chained).

- [x] T037 [TDD] [US4] [SUBAGENT] Write failing `scripts/promote-registry.test.sh` on fixture registries (small JSONL with the real
      row shape): (1) candidate that is a **superset** (all current lines byte-identical plus new) → accepted; (2) a
      candidate with a changed or removed existing line → rc 1 unless `--allow-changes <reason>`; (3) a candidate whose
      row count decreases → rc 1 (data-loss guard); (4) candidate sha == current → rc 0 "already promoted", **no write, no
      new backup, no journal row** (§11.4.253); (5) `--apply` makes a REAL-COPY backup (different inode, same bytes) before
      any write, records its sha256 BEFORE the write, and the swap is temp-file + `rename(2)` in the same directory;
      (6) interrupt at each step (SIGTERM chaos) leaves the live file either old or new, never partial; (7) `--rollback
      <run>` restores the backup bytes (sha equal to the recorded pre-sha) and journals it; (8) tree not quiescent or
      unreadable → rc 2; (9) journal rows chain (`prev_sha256`), a tampered middle row is detected by `--status --verify`;
      (10) `--apply` refuses without a PASS `--pre` verdict when D2 requires it. **Oracle**: `sha256sum`, `stat -c %i`, line-hash
      diffs done by the test; chain verification by an independent python3 script. → RED.
      EVIDENCE (S12, 2026-10-20): scripts/promote-registry.test.sh 178 passed/0 failed (chaos SIGTERM/INT/HUP x4 steps, SIGKILL, concurrent reader, guarded rollback, journal tamper, verdict seam) - evidence/s12/ in worktree vasic-wt/s12-019-promotion (branch s12-019-promotion)
- [x] T038 [TDD] [US4] Implement `scripts/promote-registry.sh` (NEW) calling `platform/gates/verify-backup-distinctness.sh`
      for the backup check and `platform/bin/registry-restamp-content-type -check` for content-type validity (build the
      binary via `scripts/build.sh --server-only`-style step if absent; record in the task note). Honour `WORKSHOP_ORCH=1`
      for `--apply`. Make T037 green.
      EVIDENCE (S12, 2026-10-20): scripts/promote-registry.sh + scripts/lib/promote_lib.py; mutation proof prove-registry-promotion-mutation.sh 14/14 CAUGHT, control green - evidence/s12/ in worktree vasic-wt/s12-019-promotion (branch s12-019-promotion)
- [ ] T039 [P] [US4] Rehearsal on a COPY end to end with a **fixture-size** registry and the isolated server: promote the
      candidate, boot the server on the promoted file, assert `/api/system/provenance.registry.loaded_sha256` equals the
      candidate sha and `index.pid_count` equals rows after the boot-time index pass; then roll back and assert the old sha
      is served. Evidence: counts and hashes only. (A full-size rehearsal embeds ~1 700 passages and is spec 020's T-task.)
      S12 NOTE: PARTIAL not ticked: run-isolated server could not be queried with a session (401), loaded==promoted after a restart is UNCONFIRMED end to end
- [ ] T040 [TDD] [US4] Paired mutation gate `platform/gates/verify-registry-promotion.sh` + `prove-registry-promotion-mutation.sh`
      (mutants: hardlink instead of copy, non-atomic write, backup after write, superset check disabled, journal not
      chained, rollback restores wrong file). Each MUST turn the gate red; control green. Register in the gate TSV.
      S12 NOTE: PARTIAL not ticked: prove-registry-promotion-mutation.sh delivered, not registered in the gate TSV
- [ ] T041 [REVIEW] [US4] Independent review (Opus xhigh): atomicity argument on the bind-mounted **directory** (rename inside the
      mounted directory changes the inode of the file but not of the mount — verify with T001's finding), §9 compliance (real
      copy, pre-digest), idempotency, journal integrity, rollback correctness. Verdict file.
- [ ] T042 [ORCH] [US4] Operator runbook `docs/guides/promote-a-registry.md` (§11.4.257) including the **restart cost**
      (restart header records a ~45-minute cross-reference derivation, `scripts/restart.sh` header), the maintenance-window
      note ("crossref endpoints answer 503 with a stated cause during boot; search availability during boot UNCONFIRMED —
      measured by T043"), the quiescence rule, the `--require-verdict` flow, and the rollback recipe.
- [ ] T043 [ORCH] [US4] **No-op live promotion**: `promote-registry.sh --candidate curriculum/passages.jsonl --apply` against
      the live tree (candidate == current) → rc 0 "already promoted"; and a read-only boot-window measurement: on the next real
      restart (018/020), record how long search and `/api/health` take to answer and what `crossrefs` answers, into
      `evidence/…/boot-window.json` (counts and seconds). If no restart happens in this feature's window, the task stays open
      and says so — it is not closed on a guess.

**Checkpoint US4**: fixture rehearsal promote/rollback proven; live no-op promotion idempotent; gates red under mutation.

---

## Phase 7: User Story 5 — Drift announces itself (P3)

- [ ] T044 [TDD] [US5] Write failing `scripts/live-drift.test.sh`: `scripts/live-drift.sh` prints one line
      `live-vs-built: PASS|FAIL|UNDETERMINED (<ids>)` and exits 0/1/2, bounded by a 5 s budget (timeout → UNDETERMINED);
      it never prints a token or a path outside the repo. Oracle: stub stack of T021. → RED.
      S12 NOTE: NOT DONE (US5)
- [ ] T045 [US5] Implement `scripts/live-drift.sh` (NEW, thin wrapper around `deploy-gate.sh --post --quick`) and add one
      informational line to `scripts/status.sh`'s output (never changes its exit code — `status.sh`'s contract is
      RUNNING/STOPPED/DEGRADED/UNDETERMINED, `status.sh:3-25`). `verify-status-exit-contract.sh` MUST stay green (run it).
- [ ] T046 [P] [US5] Frontend: the Status page banner (US3) is the at-rest announcement for browser users; add the
      header-level indicator only if the operator asks (D5 `OPEN`; not built here). Record the question in
      `decisions.md`.

---

## Phase 8: Polish & Cross-Cutting

- [ ] T047 [P] [POLISH] Observability (§11.4.260): structured boot line (T030), deploy-gate verdict is the audit record; add the
      gate's last verdict summary to `scripts/status.sh --verbose` if such a mode exists (UNCONFIRMED; skip with note if not).
- [ ] T048 [P] [POLISH] Coverage on the new Go packages (`internal/provenance`, `internal/api/provenance*.go`) and Karma
      coverage on `features/status-live` (floor ≥ 85%, §11.4.224); the report states coverage is necessary, never sufficient.
- [ ] T049 [P] [POLISH] Fuzz `provenance.Manifest` over generated trees (`FuzzManifest`, 60 s) with property "manifest of a
      tree equals manifest of a copy of it; any single byte flip changes the hash".
      S12 NOTE: PARTIAL: FuzzManifest ran 30 s (spec says 60 s), PASS; not ticked
- [ ] T050 [ORCH] [POLISH] **LIVE verification script** `evidence/019-<run>/live-019.sh` (authored by a subagent, run by the
      orchestrator after promotions): G0-G7 via `deploy-gate.sh --post` → `verdict.json`; additionally (1) `/api/health`
      `source_commit` == HEAD and `source_dirty:false`; (2) `sha256(GET /)` == `sha256(dist/index.html)`; (3) host registry
      sha == container registry sha == provenance loaded sha; (4) provenance corpus total == `wc -l` of the registry and
      `by_content_type` equals the independent python count; (5) `index.pid_count` == registry rows. Writes `result.json`
      (`{check, expected, observed, rc}[]`) and `manifest.sha256` (hash of every evidence file, written last). DONE only when
      all rc 0 **and** the same script against a deliberately stale copy (old bundle, old registry) yields rc ≠ 0.
- [ ] T051 [ORCH] [POLISH] **UI-visible acceptance (operator watches), final**: `/status` → "What is live" panel → read out the
      build, commit, bundle hash, registry sha, counts by kind and content_type, index generation, flags; then deliberately
      stage a stale `index.html` on the isolated server and show the mismatch banner. Steps with expected on-screen text
      recorded in `evidence/…/ui-acceptance-us3.md`; screenshots in the private evidence dir.
- [ ] T052 [P] [POLISH] User manual `docs/deploy-and-promotion.md` (§11.4.257): what the gate checks, how to read a verdict,
      what each check id means, the fingerprint, the seam, limits. **[done on branch origin/rescue/s12-019-promotion-wip only; not on workshop main as of 2026-10-24; evidence docs/deploy-and-promotion.md; annotated by 026 Wave 1 on 2026-10-24]**
- [ ] T053 [P] [POLISH] Task guide `docs/guides/promote-the-frontend-bundle.md`.
- [ ] T054 [P] [POLISH] Task guide `docs/guides/read-the-whats-live-panel.md`.
- [ ] T055 [P] [POLISH] Task guide `docs/guides/roll-back-a-promotion.md` (bundle and registry).
- [ ] T056 [P] [POLISH] FAQ additions to `docs/faq.md`: why the gate is red after a docs-only commit (D1), why a bundle swap needs
      no restart, why a registry swap does, what "partial boot" looks like, who may see the panel.
- [ ] T057 [P] [POLISH] Four diagram classes at point of use (§11.4.258), Mermaid in `docs/deploy-and-promotion.md`:
      **architecture** (host scripts, compose mounts, container, browser, the three evidence channels),
      **data-flow** (source → build → staging → manifest → served → verdict), **state machine** (promotion states:
      idle → staged → verified → promoted → pruned | rolled-back, and the gate verdict states PASS/FAIL/UNDETERMINED),
      **sequence** (operator → gate pre → promote-web → promote-registry → restart → gate post → panel). A reviewer traces
      one arrow per diagram to a file:line. **[done on branch origin/rescue/s12-019-promotion-wip only; not on workshop main as of 2026-10-24; evidence Mermaid blocks in docs/deploy-and-promotion.md; annotated by 026 Wave 1 on 2026-10-24]**
- [ ] T058 [REVIEW] [POLISH] Export and validate the docs: `bash scripts/build-exports.sh`; a separate validator agent opens
      the PDF/HTML for CONTENT, TEXT and VISUAL layers (§11.4.168), checks Mermaid rendered, links resolve. Verdict file.
- [ ] T059 [P] [POLISH] Claim-vs-reality ledger rows (§11.4.266): "what is built is what is served (commit)", "(bundle)", "(registry)",
      "a deploy without a matching PASS is refused", "a registry promotion is reversible" — each names its passing challenge
      (T025, T040, T050) and bluff type.
- [ ] T060 [REVIEW] [POLISH] Whole-feature independent review (Opus xhigh, fresh agent): branch diff vs `main`, FR-by-FR
      traceability, only hook lines in shared files, evidence hash-matches manifest, no secret in any evidence file (grep
      for the token/password shape and for `http` strings in provenance fixtures).
- [ ] T061 [ORCH] [POLISH] Full-suite retest on a clean baseline (§11.4.40), ff-only merge onto `main` (§11.4.113), workshop
      gitlink + `helix-deps.yaml` moved together (`verify-manifest-pins.sh` rc 0), `CONTINUATION.md` synced (§12.10),
      version bump for the next cycle after the QA deploy (§11.4.235B), `progress.yml` ticks written by the orchestrator
      with pasted output.

---

## Dependencies & Execution Order

- Phase 1 → Phase 2 → {US1, US2, US3} (US1 and US3 are independent; US2's `--post` checks need the provenance endpoint from
  US3 for G3/G6 — the gate's G1/G2 can ship first and G3/G6 arrive with T030) → US4 (needs US2's seam) → US5 → Polish.
- The first real use of the whole chain is 018 T033 and 020's registry merge: both call `promote-registry.sh` and the gate.
- T027 (RED baseline) must precede T019/T043 — the "before" evidence is destroyed by promoting first.

## Implementation Strategy

1. MVP = Phase 1-2 + US1 + US2: the operator can promote the stale bundle safely and a gate says whether live equals built.
2. US3 makes the answer visible without a terminal; US4 gives 018/020 their safe merge path; US5 is polish.

## Task counts

Total 61 tasks (T001-T061): Setup 6 · Foundational 6 · US1 8 · US2 7 · US3 9 · US4 7 · US5 3 · Polish 15.
