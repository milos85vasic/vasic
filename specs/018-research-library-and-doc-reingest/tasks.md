# Tasks: Research Library and Research-Document Re-ingestion

**Input**: `specs/018-research-library-and-doc-reingest/` — `plan.md`, `spec.md`, `research.md`, `data-model.md`, `contracts/`, `quickstart.md` (all present)
**Prerequisites**: none of specs 011-017 is a code prerequisite; spec 019 supplies the rebuild/restart/promotion procedure the live tasks (T033, T044, T045) rely on.

**Tests**: INCLUDED and test-first. Every code task is preceded by a RED task with a named oracle (§11.4.224/§11.4.245).
Producer ≠ verifier (§11.4.240/§11.4.249): the agent that writes a test is not the agent that writes the code it
judges, and neither reviews.

**Organization**: grouped by user story (US1-US4), then Polish. Nothing in this file is marked done; no task has run.

## Format: `[ID] [P?] [TDD?] [REVIEW?] [SUBAGENT?] [Story] Description`

- **[P]** parallel (different files, no dependency) · **[TDD]** strict RED→GREEN→REFACTOR · **[REVIEW]** independent
  review (separate agent, Opus, effort xhigh, §11.4.142/§11.4.209) before the next dependent task · **[SUBAGENT]**
  delegable · **[Story]** US1-US4, `SETUP`, `FOUND`, `POLISH`.
- **Orchestrator-only** tasks are tagged `[ORCH]`: they touch shared files or the live stack (architecture.md §2.2).

## Path Conventions

Backend `workshop/platform/backend/{internal/api,cmd/workshop-server}`; frontend
`workshop/platform/frontend/src/app/features/library/`; scripts `workshop/scripts/`; pipeline `workshop/pipeline/`;
gates `workshop/platform/gates/`; docs `workshop/docs/`; evidence `workshop/evidence/018-<run>/` (private
submodule — never copied into the public umbrella). All paths are relative to `workshop/` unless prefixed `specs/`.

---

## Phase 1: Setup

- [ ] T001 [SETUP] Re-measure baseline B1-B10 of `spec.md` and write `evidence/018-<run>/baseline.json` (counts only):
      file counts per extension under `docs/research`, rows per `source_ref.path` prefix `docs/research` in
      `curriculum/passages.jsonl`, sidecar section counts and pid counts, `grep -c 'pid:'` per `.md`. Also resolve the
      one UNCONFIRMED: whether the 3 `pid:` occurrences in the ingestion-architecture document are anchors or prose
      (report the line numbers only, not the text). Oracle: independent `find`/`python3 -I` scan; any difference from
      the spec's numbers is recorded as a correction to `spec.md`, not silently absorbed.
- [ ] T002 [P] [SETUP] Determine hook state: does `cmd/workshop-server` contain any `wire_*.go` or `// hook:` marker
      (`ls`, `grep`)? Prove an isolated throwaway server launch once (`go build -o $SCRATCH/bin/workshop-server
      ./cmd/workshop-server`; run with `-http 127.0.0.1:<free port>`, scratch `-index`, a COPY of the registry, `-docs`
      pointing at a COPY of `docs/`) and record the exact command in `evidence/018-<run>/isolated-server.md`. Every
      later worktree task verifies against this server, never against `:8087` (architecture.md §2.2 rule 6).
- [ ] T003 [P] [SETUP] Authenticated probe of the live `/docs/` behaviour (read-only, via `scripts/_live_auth.sh`):
      HEAD/GET one `.md`, one `.html`, one `.pdf`, one `.epub` under `/docs/research/…`; record status, content-type,
      length, and whether the `.html`/`.pdf` of the document with literal `[REDACTED]` headings contain any text
      beyond what its markdown contains (compare extracted text against the markdown, counts of lines only). Also GET
      `/api/sections/research` and record status + `counts` (resolves spec.md B6 UNCONFIRMED). Oracle: raw HTTP status
      lines saved to `evidence/…/docs-probe.json`. If the PDF/HTML of the redacted document leaks anything the
      markdown withholds → STOP and report (blocks US2).
- [ ] T004 [SETUP] Record operator decisions Q1-Q3 (spec.md Clarifications) interactively (§11.4.66); if no answer is
      available, record "default applied" with the date. Output `specs/018-…/decisions.md` (counts/choices only).
- [ ] T005 [P] [SETUP] Register the long-op for the ingest (§11.4.232): create the registry row (op_id,
      purpose_key `research-reingest`, owner, pgid) in the durable long-op registry the repo uses
      (`scripts/_common.sh` helpers; if none exists, write `evidence/018-<run>/long-op.json` and record that absence as
      a finding). Check thread headroom (`ulimit -u`, `ps -L --no-headers -u "$USER" | wc -l`) and `free -m` before
      launching any fan-out; record the figures.

**Checkpoint**: baseline numbers pinned, isolated server proven, hook state known, decisions recorded.

---

## Phase 2: Foundational (blocking)

**Purpose**: the one security-sensitive primitive both the listing and the reader depend on — the path validator.

**Interfaces produced**: `internal/api.validateLibraryName(string) (string, error)`;
`internal/api.resolveUnderRoot(root, rel string) (abs string, reason string, ok bool)`;
frontend `library-model.ts: encodeDocId(rel) / decodeDocId(id)`.

- [ ] T006 [TDD] [FOUND] Write failing tests `internal/api/library_path_test.go`: table of accepted/refused inputs.
      Refused: `..`, `a/../b`, `/etc/passwd`, `a%2fb`, `a\\b`, NUL byte, 4096-char name, name with leading `.`,
      a symlink inside the root pointing outside (built in `t.TempDir()`), a symlink to a sibling directory with the
      same prefix (`root` vs `root-evil`, the classic prefix bug). Accepted: nested relative path, name with spaces
      and non-ASCII. **Oracle**: the stdlib `filepath.EvalSymlinks` + `filepath.Rel` result computed independently in
      the test (not by the function under test), and a hand-listed expected reason per row. Run → RED (function absent).
- [ ] T007 [TDD] [FOUND] Implement `validateLibraryName` and `resolveUnderRoot` in `internal/api/library_path.go`
      (NEW) to make T006 green. Rule: clean → reject separators/NUL/`..` → `EvalSymlinks` → require
      `strings.HasPrefix(abs, root+string(os.PathSeparator))` (not a bare prefix). Fail closed on any error from
      `EvalSymlinks` other than not-exist. Run `go vet` + the tests with `-race`. Commit message carries the
      mutation-marker grep (§11.4.84).
- [ ] T008 [P] [TDD] [FOUND] Add `internal/api/library_fuzz_test.go` with `FuzzResolveUnderRoot` (seed corpus = the T006
      refusal rows). Property: for any input the function either returns `ok=false` or an absolute path whose
      `filepath.Rel(root, abs)` does not start with `..`. Run `go test -run xxx -fuzz FuzzResolveUnderRoot
      -fuzztime 60s ./internal/api` under `scripts/agent-admit.sh -m 4G`; commit the generated `testdata/fuzz`
      corpus. Oracle: the Rel-based property above, independent of the implementation's prefix check.

**Checkpoint**: validator green, fuzz run clean (no new crashers).

---

## Phase 3: User Story 1 — See every research document in one place (P1)

**Goal**: `GET /api/library` + `/library` list page. **Independent Test**: spec.md US1.

### Tests first

- [ ] T009 [TDD] [US1] [SUBAGENT] Write failing tests `internal/api/library_test.go` against a `t.TempDir()` tree that
      mirrors the real shape (root docs with md+html+pdf, a doc with md only, nested `clients/x`, `education-platform`
      docs, `poc/` with `.py .ts .epub .txt` and a `*.sections.json`). Assertions: (a) `counts` equal an
      independently computed expectation (the test builds the tree from a table and counts the table, not the
      response); (b) a `*.sections.json` is never listed; (c) a md-only doc has `html:null,pdf:null`; (d) ordering is
      deterministic (two calls byte-identical); (e) an unreadable subdirectory (mode 0000) lands in `undetermined`
      with the rest still listed; (f) missing/unconfigured docs root → 503 `docs_unconfigured`; unknown name → 404
      `library_not_found`; (g) response body contains no file bytes (assert body size < 2 KB per document and that a
      sentinel string planted in a file never appears); (h) `searchable` is `undetermined` when no registry is passed
      and `indexed`/`partial`/`not_indexed` against a fake registry. **Oracle**: the table the tree was built from + a
      golden JSON `testdata/library_golden.json`. Run → RED.
- [ ] T010 [TDD] [US1] Implement `internal/api/library.go`: `LibraryDeps{DocsDir string, Registry
      PassageLister}`, `LibraryHandler`, `enumerateLibrary`. Reuse `documentTitle` and `docsHref` from `sections.go`
      (same package; do NOT edit that file). Count passages per path once per registry load (cache keyed by the
      registry's content hash; guarded by `sync.Once`/mutex; `-race` clean). Count literal `[REDACTED]` headings per
      `.md` with a bounded line scan (first 1 MB). Make T009 green. Mount in `cmd/workshop-server/wire_library.go`
      (`registerLibrary(mux, cfg, reg)`) **unconditionally** so an unconfigured docs root is a 503, not a 404; add
      `wire_library_test.go` proving 503-vs-404 (§11.4.254).
- [ ] T011 [P] [TDD] [US1] Add `BenchmarkEnumerateLibrary` (500-file synthetic tree) and a test asserting < 50 ms
      median on the dev host (skip with a stated reason, rc 2-equivalent, if the host is loaded: PSI check from
      `agent-admit.sh`). Oracle: wall clock from `testing.B`, independent of the handler.
- [ ] T012 [REVIEW] [US1] Independent review (separate agent, Opus xhigh) of T006-T011: path safety (try to break
      `resolveUnderRoot`), disclosure (what can a title or id leak), `-race`, cache invalidation, 503/404 split.
      Verdict file `evidence/018-<run>/review-backend.json` with `model`, `effort`, `finding_layer` per finding.
      GO required before T013 starts consuming the contract.

### Frontend list

- [ ] T013 [P] [TDD] [US1] Write failing unit specs `features/library/library-model.spec.ts` and
      `library-list.component.spec.ts` against `testing/library.fixture.json` (golden copy of the contract body):
      codec round-trip incl. spaces/non-ASCII/`%`; `normaliseLibrary` rejects a body with an unknown `kind` into an
      explicit `unavailable('malformed_response')`; the list renders one row per document grouped, format chips
      present only when the href is non-null; the three states (`ready`, `empty`, `unavailable` with cause) render
      differently and `empty` never shows the unavailable text; `searchable` badge text comes from vocabulary rows.
      Oracle: the fixture's own `counts`. Run `npm run test:unit` (bounded) → RED.
- [ ] T014 [TDD] [US1] Implement `library-model.ts`, `library-api.ts` (settled-value service, never errors on the
      next channel — same discipline as `core/section-api.ts`), `library-list.component.ts` (standalone, OnPush),
      `library.routes.ts` (lazy: `''` → list, `read` → reader placeholder until T017). No `innerHTML`. Make T013
      green; `npx ng build` clean.
- [ ] T015 [P] [US1] Design-system conformance: run `npm run check-design-system && npm run check-platform-tokens`;
      add the group/format-chip styles using existing tokens only. Oracle: both gates rc 0 (they fail on vendored
      drift).

**Checkpoint US1**: against the isolated server (T002), `curl /api/library` and the list page show 9 documents + 5
supporting files; `go test ./internal/api -race` and Karma green; review GO.

---

## Phase 4: User Story 2 — Open and read a document (P1)

- [ ] T016 [TDD] [US2] [SUBAGENT] Write failing specs `library-reader.component.spec.ts`: given a doc id and a fixture
      markdown body, the reader (a) calls `parseMarkdown` and binds `wk-document-view`, (b) shows the heading outline,
      (c) shows the renderer's `unsupported` list when non-empty, (d) for `supporting_binary` shows the download link
      and the sentence "binary file, not previewed" and does **not** issue a text GET, (e) for `supporting_code`
      renders in `CodeBlockComponent`, (f) 404 from `/docs/` → not-found state, 401 → the app's existing sign-in
      redirect path (not a local message), (g) a doc id that decodes to `..` never issues a request. A grep-style
      spec asserts the component file contains no `innerHTML` / `bypassSecurityTrust`. Oracle: fixture files + the
      HTTP testing controller's recorded requests. → RED.
- [ ] T017 [TDD] [US2] Implement `library-reader.component.ts` (route `/library/read?doc=`), reuse
      `wk-document-view` from `features/section/document-view.component.ts` and `SectionApi.document(href)`
      semantics via `library-api.ts`. Format switcher: **Read** (in-app), **HTML** and **PDF** as `target=_blank
      rel=noopener` anchors to the `/docs/` hrefs (cookie session carries). Make T016 green.
- [ ] T018 [P] [US2] Playwright `e2e/library.spec.ts` (desktop-chromium, `WORKSHOP_BASE_URL` = isolated server): list
      shows the oracle counts computed from the on-disk tree by the spec itself (`fs` walk in the test, not from the
      response); each document's **Read** opens; every format anchor `request.head()` → 200; binary shows the note;
      a hand-typed `?doc=..%2f..%2fsecret` shows not-found and the server log shows no file outside the tree was opened.
      Uses `settle.ts`. → run RED first by pointing it at a server without the route, then GREEN.
- [ ] T019 [P] [US2] Accessibility + responsive pass: extend `e2e/a11y-responsive.spec.ts` set with `/library` and
      `/library/read` (axe rules already used there), keyboard path (Tab order, skip to content), 360 px width, reduced
      motion. Oracle: axe violations = 0 at the existing severity threshold.
- [ ] T020 [TDD] [US2] Negative-path tests (fail closed, §11.4.252) added to `library_test.go`: `GET /api/library?name=../x`,
      `name=research%2f..`, 10 000 concurrent-ish requests (loop) to prove no goroutine/descriptor leak (`runtime.NumGoroutine`
      before/after within a bound). Oracle: stdlib counters before/after.
- [ ] T021 [US2] Resolve T003's outcome in code: if `/docs/` serves `.html`/`.pdf` for the redacted document with no
      added text, record "proved equal" in the evidence; if T003 found any divergence, replace the HTML/PDF links for
      that document with a "not available — export pending" state (data-driven from `formats`) and open a tracked item.
- [ ] T022 [REVIEW] [US2] Independent review (Opus xhigh) of T016-T021: XSS surface (none expected), link `rel`,
      redirect behaviour on 401, binary handling, the e2e's oracle independence. Verdict file with `finding_layer`.

**Checkpoint US2**: all formats open under a session on the isolated server; e2e + a11y green; review GO.

---

## Phase 5: User Story 3 — Missing research becomes searchable (P2)

**Goal**: 5 documents / 120 sidecar rows added to the registry, rows-only, idempotent, no model, redaction intact.

### Tests first

- [ ] T023 [TDD] [US3] Stale-sidecar gate (FR-010, edge case): write failing `pipeline/test_sidecar_freshness.py` — a sidecar
      whose recorded source hash (the wrapper writes `source_sha256` into a companion `*.sections.meta` file next to the
      sidecar, NOT into the sidecar itself, which `ingest-transcript` decodes with `DisallowUnknownFields`) differs from
      the markdown on disk → rc 1 naming the file; matching → rc 0; missing meta → rc 2. Then implement
      `pipeline/sidecar_freshness.py` (NEW). Oracle: hashes computed by the test with `hashlib` over fixture files. → RED then GREEN.
- [ ] T024 [TDD] [US3] [SUBAGENT] Write failing `pipeline/test_research_redaction_filter.py`: fixture sidecars with (a)
      a row whose text is exactly `[REDACTED]`, (b) a row whose text is `## [REDACTED]`, (c) a row whose body merely
      *mentions* the word redacted in prose, (d) a row with trailing whitespace/NBSP around the literal, (e) an
      undecodable row (invalid UTF-8 bytes in the file). Expected: (a),(b),(d) dropped; (c) kept; (e) exit 2 and the
      file untouched. Also `--self-check` mode prints counts only. **Oracle**: expected survivor list typed in the
      test, never computed from the filter's own predicate. → RED.
- [ ] T025 [TDD] [US3] Implement `pipeline/research_redaction_filter.py` (NEW, stdlib only, deterministic, writes the
      sidecar atomically via temp+rename, prints counts only). Make T024 green. Exit 0 / 1 / 2 per
      `contracts/research-reingest-stage.md`.
- [ ] T026 [P] [US3] Run the filter against the real `retrieval-and-grounding` sidecar COPY and record
      `{rows_in, rows_dropped}` in `evidence/…/redaction-filter.json`. Oracle: `rows_dropped` equals the independent
      `grep -c '^## \[REDACTED\]'` count of the markdown headings (4) **or** the difference is explained row by row
      by line number (no text). Mismatch → STOP, report.
- [ ] T027 [TDD] [US3] Write failing `scripts/ingest-research.test.sh`: (1) `--dry-run` on a fixture workshop tree
      (3 tiny md docs + a mini registry) adds exactly the fixture's section count and changes 0 existing lines;
      (2) a second run reports new=0 changed=0; (3) the wrapper never contains the strings `ingest.sh` or
      `--corpus`; (4) a recording network sandbox (`unshare -n` if available, else a stub `curl`/DNS that logs and
      refuses; if neither is possible the test exits 2, never 0) shows 0 outbound connection attempts; (5) a sidecar
      row without `content_type` → rc 1 naming file+row; (6) unreadable registry → rc 2; (7) pre/post sha256 of every
      `.md` equal (no anchors written). **Oracle**: line-hash comparison done by `sha256sum`/`diff` in the test, not by
      the wrapper's own report. → RED.
- [ ] T028 [TDD] [US3] Implement `scripts/ingest-research.sh` (NEW) per `contracts/research-reingest-stage.md`:
      `--dry-run` (default) / `--apply` (refuses unless `WORKSHOP_ORCH=1` and a quiescent tree), uses
      `scripts/agent-admit.sh`, `pipeline/venv/bin/python`, the filter, `platform/bin/ingest-transcript … -kinds
      doc_section,code -skip-suppressed -no-write-anchors`; writes `reingest.json`. Source `scripts/_common.sh`
      conventions (three-valued exits). Make T027 green. `shellcheck`/`bash -n` clean (§11.4.67).
- [ ] T029 [P] [TDD] [US3] Hard guard task (FR-008): add `scripts/ingest-research.guard.test.sh` that runs the wrapper
      under a mocked `OLLAMA_URL`/`WORKSHOP_ANSWER_PROVIDER` pointing at a local listener that records every request,
      then asserts the listener saw 0 requests and that `model_calls` in `reingest.json` is 0. Also asserts
      `ingest-transcript` was started without any `-embed*`/`-answer*` flag. Oracle: the listener's own request log.
- [ ] T030 [US3] Idempotency + rows-only proof on a COPY of the live registry (`$SC/regcopy`): run the wrapper dry-run,
      compute independently with `python3 -I`: `rows_after − rows_before == 120 − excluded`, per-line sha256 of all
      pre-existing lines identical, counts by kind/content_type unchanged except the adds; run again → new=0 changed=0
      (§11.4.253). Save `reingest.json`, including `filename_shape_rows` — the count of added rows whose text matches the writeJSON
      source-filename-shape pattern (`pkg/search/catalog.go:320-355`; expected 1, spec.md B11), counted with the independent
      regex in `python3 -I`, ids only. If any pre-existing line differs after a no-op sync → STOP (the library
      re-serialises sorted by pid; this is a finding, not an expected difference).
- [ ] T031 [REVIEW] [US3] Independent review (Opus xhigh) of T024-T030: could a `[REDACTED]` section slip through
      (try variants), is the guard test able to fail (does the reviewer's deliberately broken wrapper make it red),
      does the wrapper ever write inside the live tree on `--dry-run`. Verdict with `finding_layer`.
- [ ] T032 [TDD] [US3] Paired mutation gates (CLAUDE.md §1.1): `platform/gates/verify-research-reingest.sh` (asserts the
      four invariants over a `reingest.json`: changed=0, second run 0/0, model_calls=0, redacted_minted=0) and
      `prove-research-reingest-mutation.sh` which feeds it (i) a `reingest.json` with `changed_existing_rows: 1`,
      (ii) a doctored wrapper that minted a literal `[REDACTED]` section, (iii) a wrapper that issues one HTTP call;
      each MUST make the gate exit non-zero; a good input exits 0. Register both in the gate registry TSV (stream-local
      row appended, conflicts resolved mechanically by the orchestrator).
- [ ] T033 [ORCH] [US3] **Live merge — only after the operator says go (Human Checkpoint 2).** On a quiescent tree
      (two `git status` reads 30 s apart): (1) real-copy backup `.backups/passages.jsonl.pre-research-<UTC>` and
      sha256 recorded **before** the write (§9; not a hardlink); (2) `WORKSHOP_ORCH=1 bash scripts/ingest-research.sh
      --apply`; (3) `bash platform/gates/verify-backup-distinctness.sh --backup … --source curriculum/passages.jsonl
      --digest <pre>`; (4) `platform/bin/registry-restamp-content-type -check -registry curriculum/passages.jsonl`
      rc 0; (5) `verify-research-reingest.sh` over the produced evidence rc 0. Rollback recipe recorded:
      `cp .backups/… curriculum/passages.jsonl` + restart. The restart and boot-time embed are spec 019's procedure.
- [ ] T034 [US3] Commit the regenerated sidecars (they now carry pids) together with `curriculum/passages.jsonl` using
      explicit paths only (`git add <paths>`, never `git add .`), pre-commit mutation-marker grep recorded, review GO
      (T031) referenced in the message. Bump of the workshop gitlink + `helix-deps.yaml` ref in the umbrella is the
      orchestrator's, in the same change (cascade C9).
- [ ] T035 [US3] Post-restart live check (after spec 019 promotion): authenticated `GET /api/search` for one term
      chosen by the verifier from each of the 5 sidecars (term selection recorded by hash only) → each returns ≥ 1
      hit whose pid `GET /api/library/sources` attributes to that document (the wire carries no path, spec.md B12; until T036b lands the check uses the registry row's `source_ref.path` read from the file on disk); `GET /api/index/status` `pid_count` equals registry rows;
      a nonsense term returns 0 hits. Save status code, pid, rank only. Oracle: the registry row count measured on
      disk.

**Checkpoint US3**: registry delta proven rows-only and idempotent on a copy; live merge + search evidence recorded.

---

## Phase 6: User Story 4 — Find the Library and search within it (P3)

- [ ] T036a [TDD] [US4] [SUBAGENT] Write failing `internal/api/library_sources_test.go` for `GET /api/library/sources`
      (FR-016, `contracts/library-api.md`): table over a fake registry + temp tree — a pid whose `source_ref.path` is a listed
      research document → `{id,title}`; a pid for a non-research doc (`docs/manual.md`) → `document:null`; unknown pid →
      null; suppressed pid → null **indistinguishable** from unknown (byte-equal bodies apart from the pid); 51 pids →
      400; malformed pid → 400; a path that escapes the root via `..` or a symlink → null; response bytes are unchanged
      by `sourceref.RedactJSON` (call it in the test: output == input, no key `path`/`source_ref`). **Oracle**: expected
      table typed in the test; the redactor invariance uses the real package, independent of the handler. → RED.
- [ ] T036b [TDD] [US4] Implement `internal/api/library_sources.go` (NEW) and mount it in `wire_library.go`; reuses
      `resolveUnderRoot` (T007) and the listing's membership test; green with `-race`; included in T012-style
      review scope (reviewer of T037 re-checks it).
- [ ] T036 [TDD] [US4] Write failing specs: `library-search.spec.ts` (title filter narrows client-side with no HTTP
      request per keystroke; empty result text differs from the failed-load text; content search calls `/api/search`
      then ONE batched `/api/library/sources` request for the pids on screen and keeps only attributed hits, with the
      text "N of M hits are research documents"), `research-hit-link.spec.ts` (a hit whose resolved `document` is
      non-null renders the document title + router link to `/library/read?doc=<encoded>`; `document:null` renders the hit
      unchanged; a failed resolver call leaves the hit unchanged and shows no error banner for the hit). Oracle:
      `HttpTestingController` request log and fixture hits. → RED.
- [ ] T037 [REVIEW] [US4] Review of the shared-file hook proposals before the orchestrator applies them (T038): the exact
      one-line hunks for `app.routes.ts`, `app.component.ts` (nav), `core/vocabulary.ts` (four label rows),
      `features/inquiry/*` or the hit-card (research link — if the hit card lives in a shared component the change is
      a new `research-source-link.component.ts` used by one existing line). Verdict: the diff touches only hook lines.
- [ ] T038 [ORCH] [US4] Apply the hooks: nav link **Library** (`routerLink="/library"`, `routerLinkActive`,
      `ariaCurrentWhenActive="page"`), the lazy route entry, the vocabulary rows, the Curriculum-home entry (FR-012),
      `registerLibrary(...)` in `main.go`. Run the vocabulary paired-mutation gate (`prove-ui-vocabulary-mutation.sh`)
      and `ng build`; commit with the hook diff only.
- [ ] T039 [TDD] [US4] Implement title filter, search-within-library (calls `/api/search?chapter=docs&q=…`, resolves the
      returned pids through `GET /api/library/sources`, shows "N of M hits are research documents", R-7 corrected) and the
      hit-card research link (`research-source-link.component.ts`, NEW; one orchestrator hook line in the hit card).
      Make T036 green.
- [ ] T040 [P] [US4] Extend `e2e/library.spec.ts`: nav link present on `/`, current-page state on `/library*`, filter
      narrows, content search returns only research hits, a hit opens the reader. Oracle: the on-disk tree and the
      registry row counts read by the spec itself.

**Checkpoint US4**: Library reachable in ≤ 1 click from `/`; search-within-library works on the isolated server.

---

## Phase 7: Polish & Cross-Cutting

- [ ] T041 [P] [POLISH] Observability (§11.4.260): `registerLibrary` logs one structured line at boot
      (`library: root=<basename> documents=N supporting=M undetermined=K`) and the handler logs request duration at
      debug level. Test: boot the isolated server and assert the line (counts only).
- [ ] T042 [P] [POLISH] Coverage: run the project's real Go coverage instrument on `internal/api` library files and
      the Karma coverage on `features/library`; record the percentages (floor ≥ 85%, §11.4.224). Coverage is necessary,
      never sufficient — the report states that sentence.
- [ ] T043 [P] [POLISH] Paired mutation for the listing: `platform/gates/verify-library-listing.sh` (compares the
      live/isolated `/api/library` against a `find` oracle: documents, supporting files, every href HEAD 200,
      no `.sections.json`) and `prove-library-listing-mutation.sh` (mutants: handler lists `.sections.json`; handler
      accepts `..`; handler drops the `pdf` format; each MUST turn the gate red).
- [ ] T044 [ORCH] [POLISH] **LIVE verification script** `evidence/018-<run>/live-018.sh` (authored by a subagent,
      executed by the orchestrator after the spec 019 promotion): checks (1) `/api/health` build stamp == repo HEAD and
      `source_dirty:false`; (2) `/api/library` counts == disk oracle; (3) every format href HEAD 200; (4) the 5
      documents each return ≥ 1 search hit; (5) 0 hits for a nonsense term; (6) `withheld_sections` > 0 for the
      redacted document and no retrievable text for it; (7) `/library` served by the live bundle (the bundle hash from
      spec 019's provenance equals the freshly built one). Writes `result.json` (`{check, expected, observed, rc}[]`)
      and `manifest.sha256` (sha256 of every file in the evidence dir, written last). DONE only when all rc 0 **and**
      the paired mutation (the same script against a deliberately broken copy) yields rc ≠ 0.
- [ ] T045 [ORCH] [POLISH] **UI-visible acceptance — the operator watches.** Walk-through script
      `evidence/018-<run>/ui-acceptance.md` + a Playwright video/screenshot set under the private evidence dir:
      sign in → header **Library** → see "9 documents · 5 supporting files" → open the Jordan client document → open
      its PDF → return → search for a term from it → hit card shows the document and link → open it. Each step has an
      expected on-screen text/element and the operator ticks it. Screenshots are stored in the private submodule only.
- [ ] T046 [P] [POLISH] User manual `docs/library.md` (§11.4.257): what the Library is, who sees what, formats, the
      searchable badge, withheld sections, limits. No private content quoted; paths and counts only.
- [ ] T047 [P] [POLISH] Task guide `docs/guides/library-open-a-research-document.md`.
- [ ] T048 [P] [POLISH] Task guide `docs/guides/library-find-a-term-in-research.md`.
- [ ] T049 [P] [POLISH] Task guide (operator) `docs/guides/library-add-or-reingest-a-research-document.md` — the
      `ingest-research.sh` dry-run/apply/rollback procedure.
- [ ] T050 [P] [POLISH] FAQ additions to `docs/faq.md` (why a document is `partial`, why a section shows as withheld,
      why the PDF opens in a new tab, who can see the Jordan document, how to hide one).
- [ ] T051 [P] [POLISH] Four diagram classes embedded at point of use (§11.4.258), Mermaid fenced blocks in
      `docs/library.md`: **architecture** (browser ↔ `/api/library` ↔ docs root ↔ registry; `/docs/` byte path),
      **data-flow** (docs tree → sidecar → filter → ingest-transcript → registry → search → library badge),
      **state machine** (document `searchable` states and the withheld flag; list-page load states ready/empty/unavailable),
      **sequence** (operator re-ingest dry-run → apply → restart → live check). Each diagram is truthful to the code
      named in `plan.md`; a reviewer traces one arrow per diagram to a file:line.
- [ ] T052 [REVIEW] [POLISH] Export + validate: `bash scripts/build-exports.sh` for the new docs (md/html/pdf/docx where
      the script produces them); a **separate** validator agent opens the PDF/HTML and verifies content, text and
      visual layers, Mermaid rendered (no raw source leaking), per §11.4.168; links in the manual resolve. Verdict file.
- [ ] T053 [P] [POLISH] Claim-vs-reality ledger rows (§11.4.266) in the repo's ledger: "Library lists every research
      document", "every format opens", "research is searchable", "redacted sections stay withheld", "re-ingest spends
      no model" — each row names its passing challenge (T043/T044/T029/T032) and bluff type.
- [ ] T054 [REVIEW] [POLISH] Whole-feature independent review (Opus xhigh, fresh agent with no prior context of the
      work): diff of the feature branch against `main`, spec FR-by-FR traceability table, checks the hook lines are
      the only shared-file edits, evidence files exist and hash-match the manifest. GO before the merge.
- [ ] T055 [ORCH] [POLISH] Full-suite retest on a clean baseline (§11.4.40) — Go `./...` bounded (`-p 2`, GOMAXPROCS=4),
      Karma, relevant Playwright projects, paired gates — then `git merge` of the feature branch onto `main` ff-only
      (§11.4.113, never force), workshop gitlink + `helix-deps.yaml` moved together, `scripts/verify-manifest-pins.sh`
      rc 0, `CONTINUATION.md` synced (§12.10), `progress.yml` ticks written by the orchestrator with pasted output.

---

## Dependencies & Execution Order

- Phase 1 → Phase 2 → US1 (T009-T015) → US2 (T016-T022). US3 (Phase 5) depends only on Phase 1 (T001, T005) and runs
  in parallel with Phases 2-4 (disjoint files). US4 depends on US1+US2 and on the orchestrator hooks (T038).
- T033 (live merge) needs: T030 proof, T031 GO, T032 gates, operator go-ahead, a quiescent tree, and is sequenced with
  spec 019's single restart so the ~45-minute boot cost is paid once (architecture.md §3.3).
- T044/T045 need spec 019's rebuilt bundle and restart; until then the UI scenarios are verified on the isolated server only.
- Polish docs (T046-T051) can start once the contracts are frozen (after T012).

## Implementation Strategy

1. MVP = Phase 1-2 + US1 + US2: the operator can see and open every research document (the literal complaint).
2. Add US3 as soon as the operator approves the live merge; it is independent code.
3. US4 last (needs orchestrator hooks); T045 is the operator-facing proof.

### Subagent Dispatch Strategy

T009, T013, T016, T024, T027 (test authors) are delegated to subagents that **do not** implement; the implementers
(T007, T010, T014, T017, T025, T028) are different subagents; reviewers (T012, T022, T031, T037, T052, T054) are a third
set. Dispatch prompts carry the content-boundary briefing (paths and counts only) and the §11.4.84 staging rule
(explicit paths, worktree-local commits).

## Task counts

Total 57 tasks (T001-T055 plus T036a, T036b): Setup 5 · Foundational 3 · US1 7 · US2 7 · US3 13 · US4 7 · Polish 15.
`[REVIEW]` 6 (T012, T022, T031, T037, T052, T054) · `[ORCH]` 5 (T033, T038, T044, T045, T055) · `[TDD]` 22.
