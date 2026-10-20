# Tasks: Textbook Library UI and Deterministic Textbook Ingestion

**Input**: `specs/020-textbook-library-ui/` — `plan.md`, `spec.md`, `research.md`, `data-model.md`, `contracts/`, `quickstart.md` (all present)
**Prerequisites**: spec 019 (`promote-registry.sh`, `deploy-gate.sh`, `restart.sh --require-verdict`, `/api/system/provenance`) is the live-merge and
verification path; its tools must exist before T029. Code tasks (Phases 2, 4-7) do not depend on 019 and run on an isolated server.
Spec 017 shipped the extractors (`pipeline/pdf_textbook_sections.py`, `pipeline/pdf_textbook_diagrams.py`); this feature **uses** them, it does not rewrite them.

**Tests**: INCLUDED and test-first (§11.4.224) with a named oracle per RED task (§11.4.245). Producer ≠ oracle ≠ gate ≠ verifier (§11.4.249):
test authors, implementers and reviewers are different agents.

**Organization**: by user story (US1-US5), then Polish. No task has run; nothing is ticked.

## Format: `[ID] [P?] [TDD?] [REVIEW?] [SUBAGENT?] [Story] Description`

- **[P]** parallel (different files) · **[TDD]** RED→GREEN→REFACTOR · **[REVIEW]** independent review (separate agent, Opus, xhigh,
  §11.4.142/§11.4.209; verdict file with `model`, `effort`, `finding_layer`) · **[SUBAGENT]** delegable · **[ORCH]** orchestrator-only
  (shared file, live stack, restart, real PDFs).

## Path Conventions

Relative to `workshop/` unless prefixed `specs/`. Backend `platform/backend/{internal/textbooks,internal/api,cmd/workshop-server}`; frontend
`platform/frontend/src/app/features/textbooks/`; pipeline `pipeline/`; scripts `scripts/`; data `curriculum/textbooks/`; gates `platform/gates/`; evidence
`evidence/020-<run>/` (private submodule — textbook text and images never enter the public umbrella). The PDFs live in `textbooks/ai_001/` (git-ignored).

---

## Phase 1: Setup

- [ ] T001 [SETUP] Re-measure the baseline of `spec.md` B1-B12 and write `evidence/020-<run>/baseline.json` (counts, hashes, sizes — no text): the 3 PDFs'
      `sha256`, byte size and `pdfinfo` page count and `Title:` field; `grep -c` of textbook rows in `curriculum/passages.jsonl` (expected 0) and counts by
      kind; `ls -la platform/bin` build dates of `ingest-transcript` and `index-embed`; `git check-ignore -v textbooks/` and `curriculum/textbooks/`;
      `/api/chapters` count (via `_live_auth.sh`); available isolation tools (`command -v strace unshare bwrap`). Oracle: independent commands, raw outputs pasted;
      differences from the spec are recorded as corrections to `spec.md`.
- [ ] T002 [P] [SETUP] Hook state + isolated server: any `wire_*.go` / `// hook:` in `cmd/workshop-server`? Prove an isolated throwaway server once with a registry
      COPY, a scratch `-index`, and `-docs`/`-curriculum` pointing at a scratch tree (same artefact as 018/019 T002 — reuse if present, re-verify, do not copy
      the claim). Also confirm `pipeline/venv/bin/python`, `pdftotext`, `pdfinfo`, `pdfimages`, `pdftocairo` resolve and `platform/bin/ingest-transcript` is current
      against its source (rebuild into scratch and compare `-h` flag lists if unsure) and build `registry-restamp-content-type` into scratch if it is absent.
- [ ] T003 [P] [SETUP] Classify every tool the ingestion procedure may touch as **model-free** or **model-using** by reading source (not guessing): `pdf_textbook_sections.py`,
      `pdf_textbook_diagrams.py` (imports: `subprocess`, `PIL` — confirm), `ingest-transcript` (does `-docs` mode ever construct an HTTP client? `grep` its
      imports), `registry-restamp-content-type`, `scripts/bench-retrieval.sh` (does it call generation or only retrieval?), `scripts/index.sh`. Output
      `evidence/…/model-free-allowlist.md`: tool → evidence line (file:line) → classification. Anything `UNCONFIRMED` is excluded from the allow-list until proven. This
      table is the input of the guard tasks T019-T021.
- [ ] T004 [SETUP] Record operator decisions D-LIC, D-PDF, D-DIAG, D-EMB, D-SVG, D-TITLES (spec.md Clarifications) interactively (§11.4.66): the license-basis string
      `operator-directed 2026-10-20` exactly as given, display titles (and optional authors) for the 3 books, whether original PDFs may be served (default no),
      whether diagram captions become searchable (default no), whether local embedding at boot counts as a model call (default: allowed, disclosed), SVG serving
      (default no). Defaults apply if unanswered, dated. Output `specs/020-…/decisions.md` (choices only, no book text).
- [ ] T005 [SETUP] Filename-shape collision measurement (spec.md B11): for each PDF run `pdftotext -layout` once, split on form feed, apply the exact regex of
      `pkg/search/catalog.go:320-355` with `python3 -I`, and record per book `{pages, pages_matching}` and the **page numbers** (no matched text). Repeat for the
      candidate display titles. Expected from the authoring-time scan: 0 / 0 / 3 pages (cookbook 3). Oracle: the regex is copied from the Go source by the task, and a
      Go test in T013-T014 re-checks the same pages with `search.HasSourceFilenameShape`.
- [ ] T006 [P] [SETUP] Sandbox capability probe for the model-free guard: determine which of `strace -f -e trace=network`, `unshare -rn` (rootless net namespace),
      `bwrap --unshare-net` work for an unprivileged process here. Record the result and the chosen mechanism; if none works the guard test exits 2 (undetermined) and
      the ingestion tasks T022-T024 are blocked until one does — an unenforced guard is not a guard.
- [ ] T007 [P] [SETUP] Long-ops + headroom (§11.4.232/§12.6/§12.12): register `purpose_key`s `textbook-extract`, `textbook-diagrams`, `registry-promote`, `restart`; record
      `ulimit -u`, live thread count, `free -m`, and free disk under `curriculum/` (diagram PNGs can be large — measured in T023, estimated here from `pdfimages -list`
      sizes without extracting).
- [ ] T008 [P] [SETUP] §11.4.150 research note `evidence/…/research-note.md` (executed at implementation time; sources recorded): how mature RAG/document UIs present
      page-anchored citations (page index vs printed label), how to make PDF extraction deterministic, safe image serving from derived third-party PDFs. Nothing in the
      design depends on an unverified external claim; the note may only refine it.

**Checkpoint**: baseline pinned, decisions recorded, tool classification and isolation mechanism known.

---

## Phase 2: Foundational (blocking)

**Purpose**: the catalogue — the one derived, tracked, deterministic description of the books — and its server-side loader and registry join.

**Interfaces produced**: `curriculum/textbooks/books.json` (operator input), `curriculum/textbooks/catalogue.json` (generated),
`pipeline/textbook_catalogue.py`, Go `internal/textbooks.Catalogue`, `Join(cat, registry) []BookState`, `Cite(pid) (Citation, bool)`.

- [ ] T009 [TDD] [FOUND] [SUBAGENT] Write failing `pipeline/test_textbook_catalogue.py`: fixtures — a `books.json`, per-book main sidecar (`sections[]` with `pid`, `line_start`==`line_end`==page),
      `.report.json` (`license_basis`, `total_pages`, `sections[{line,section_title,pid}]`, `extraction_failures`), and `diagrams.json`. Cases: (a) catalogue equals a hand-written
      golden; (b) output is byte-identical across two runs (sorted keys, `\n` endings); (c) `books.json` entry with `license_basis` `UNVERIFIED` or empty → rc 1 in `--final`;
      (d) `--final` with a section lacking a `pid` in the main sidecar (not yet ingested) → rc 1 naming book+page; (e) the report's null-pid sections are joined to the main
      sidecar's pids **by page**, and two sections on one page → rc 1; (f) unreadable file → rc 2; (g) absolute paths in `diagrams.json` (`raster_path`) are rewritten to
      relative names and no absolute path or username appears anywhere in the output (grep test); (h) `chapters[]` = maximal runs of consecutive pages with identical
      `section_title`. (i) a display title matching the filename-shape regex → rc 1, a section title matching it → listed by page in the output (rc 0). **Oracle**: golden typed in the test; page/pid joins computed by the test. → RED.
- [ ] T010 [TDD] [FOUND] Implement `pipeline/textbook_catalogue.py` (NEW, stdlib only, no network import — checked by T019's static scan) producing `catalogue.json` per
      `contracts/textbook-catalogue.md`. Atomic write (temp + rename). Three-valued exit. It also tests every display title and section title with the filename-shape regex of `pkg/search/catalog.go:320-355`: a matching display title → rc 1; matching section titles → listed by page number in the output for the operator (they come from the PDF and are not edited). Green.
- [ ] T011 [TDD] [FOUND] [SUBAGENT] Write failing `internal/textbooks/catalogue_test.go`: strict decode (`DisallowUnknownFields`), invariants (`sum(sections)==len(sections list)`,
      pages unique and ascending, `chapters` partition the section list, ids match `^[a-z0-9][a-z0-9-]{0,63}$`), golden JSON built by the Python builder from the T009 fixture,
      malformed file → `ErrCatalogueInvalid` naming the field (never a partial catalogue), absent file → `ErrCatalogueAbsent` (distinct: a determined "no textbooks ingested yet").
      **Oracle**: the Python-produced golden; invariant checks written independently of the loader. → RED.
- [ ] T012 [TDD] [FOUND] Implement `internal/textbooks/catalogue.go` (NEW). Green with `-race`.
- [ ] T013 [TDD] [FOUND] [SUBAGENT] Write failing `internal/textbooks/join_test.go`: `Join` over a fake `[]passage.Record` — per book counts of `textbook_section` rows by `scope`;
      `state` ∈ `ingested` (all catalogue sections have a live row), `partial`, `not_ingested` (catalogue present, no rows — registry not yet promoted/restarted); suppressed rows are
      not counted and not citable; `Cite(pid)` returns book, page (= `source_ref.line_start`), section title from the catalogue (by pid) — `false` for a non-textbook pid, unknown pid, or
      suppressed pid (indistinguishable). Also: the six-thousand-character embed limit (`-embed-max-chars 6000`) — `Join` reports `pages_over_embed_limit` per book (count). **Oracle**: counts
      from a typed table + a Python count over a JSONL fixture. → RED.
- [ ] T014 [TDD] [FOUND] Implement `internal/textbooks/join.go` (NEW), green with `-race`; include a test that runs `search.HasSourceFilenameShape` over the fixture titles (the boundary guard,
      spec.md B11).
- [ ] T015 [P] [FOUND] `FuzzCatalogueDecode` (60 s, `agent-admit.sh -m 4G`): arbitrary bytes never panic; any accepted catalogue satisfies the invariants.
- [ ] T016 [REVIEW] [FOUND] Independent review (Opus xhigh) of T009-T015: oracle independence, determinism, the by-page join assumption (one section per page — verify against
      `pdf_textbook_sections.py:195-215`), disclosure (no absolute path, no filename in any field), fail-closed decode. Verdict file.

**Checkpoint**: the catalogue builder and loader agree on golden fixtures; join and citation lookup are proven on fakes.

---

## Phase 3: User Story 1 — The three books enter the live corpus deterministically (P1)

**Goal**: ingest `textbooks/ai_001/*.pdf` through the deterministic bash-driven procedure; license basis recorded as `operator-directed 2026-10-20`; backup; verify counts; restamp;
**zero language-model and zero speech-recognition spend, proven by a hard guard.** Independent Test: spec.md US1.

**Interfaces produced**: `scripts/ingest-textbooks.sh --extract | --diagrams | --catalogue | --dry-run | --apply | --verify`; `curriculum/textbooks/{books.json,<id>.sections.json,<id>.report.json,catalogue.json}`;
`curriculum/textbooks/diagrams/<id>/` (git-ignored).

### Tests first

- [ ] T017 [TDD] [US1] [SUBAGENT] Write failing `scripts/ingest-textbooks.test.sh` on **fixture PDFs** (tiny text-layer PDFs produced by the helpers already used in
      `pipeline/test_pdf_textbook_sections.py` — if those cannot be imported, by `pdftocairo`-free hand-written PDF bytes; no model tooling): (1) `--extract` run twice → sidecars
      byte-identical (sha256) (FR-007 of 017); (2) `--license-basis` absent or `UNVERIFIED` → rc 2 before any write; (3) `--dry-run` on a copy of a fixture registry adds exactly the
      expected rows, changes 0 existing lines (per-line sha256, done by the test), scope slugs are not chapter directories; (4) second `--dry-run` on the merged copy → new 0 / changed 0;
      (5) an image-only PDF → rc 2 "no text layer", never rc 0; (6) a page below `--min-chars` is skipped and the gap is listed in `report.json`; (7) the catalogue built after the dry-run
      equals the golden; (8) wrapper exit contract 0/1/2 on each failure class (missing pdf, unreadable registry, tool absent); (9) `--apply` refuses without `WORKSHOP_ORCH=1`
      and a PASS `--pre` verdict (019 seam). **Oracle**: line-hash diffs and counts computed by the test with `sha256sum`/`wc`/`python3 -I`. → RED.
- [ ] T018 [TDD] [US1] Implement `scripts/ingest-textbooks.sh` (NEW) per `contracts/textbook-ingestion-procedure.md`: reads `curriculum/textbooks/books.json` for ids/scope slugs/license basis (single
      source of truth — the string is passed to `pdf_textbook_sections.py --license-basis` verbatim), runs the extractors under `scripts/agent-admit.sh`, places sidecars under
      `curriculum/textbooks/`, runs `ingest-transcript -dir <copy|live> -kinds textbook_section -skip-suppressed -no-write-anchors -source-root "$PWD" -docs …`, builds the catalogue,
      verifies counts, delegates the live swap to `scripts/promote-registry.sh` (019). `bash -n`/shellcheck clean (§11.4.67). Green T017.
- [ ] T019 [TDD] [US1] **Hard guard — no model call (the ZERO-token proof).** Write failing `scripts/ingest-textbooks.guard.test.sh` with three independent arms, each able to fail:
      (A) *static*: scan `ingest-textbooks.sh`, `pdf_textbook_sections.py`, `pdf_textbook_diagrams.py`, `textbook_catalogue.py` and the Go ingest path's import list for any token in the
      deny-list (`ollama`, `curl`, `wget`, `llama`, `whisper`, `faster_whisper`, `transcribe`, `openai`, `anthropic`, `/api/generate`, `/api/chat`, `/v1/`, `-answer`, `index-embed`, `urllib.request`,
      `http.client`, `requests`, `socket`, `aiohttp`) and require every external command in the script to be in the T003 allow-list; (B) *runtime*: run the whole fixture procedure under the
      isolation mechanism chosen in T006 and assert **zero `connect()`/`sendto()` attempts** (strace) or that every network call fails in the empty namespace and the procedure still
      succeeds (proving it never needed one); (C) *environment*: run with a recording listener standing in for the Ollama port and the answering endpoint (`OLLAMA_URL`,
      `WORKSHOP_ANSWER_PROVIDER` pointed at it) and assert the listener saw **0 requests**. Output `model_calls` = measured count (must be 0) and the tool list actually exec'd (from strace
      `execve`). **Oracle**: kernel-level syscall trace and the listener's own log — neither is the code under test. → RED (script absent) then GREEN with T018.
- [ ] T020 [TDD] [US1] Paired mutation gate (§1.1): `platform/gates/verify-textbook-ingest-model-free.sh` (runs T019 and asserts the evidence schema) and
      `platform/gates/prove-textbook-ingest-model-free-mutation.sh` with mutants M1 add a `curl` call to the wrapper, M2 add `import urllib.request` to the catalogue builder, M3 call the Ollama
      stand-in from the extractor wrapper, M4 remove the isolation step (guard must go red because the arm cannot run: rc 2, not 0), M5 add an `index-embed` invocation, M6 weaken the deny-list;
      each MUST make the gate exit non-zero; the control exits 0. Register in the gate registry TSV.
- [ ] T021 [REVIEW] [US1] Independent review (Opus xhigh) of T017-T020: can the guard be fooled (a library that shells out to a binary not on the deny-list; a socket opened by a child), does arm (B)
      cover child processes (`strace -f`), is "0" meaningful (a trace that captured nothing must be rc 2), does any step of the real procedure fall outside the fixture's coverage. Verdict file.

### Real run (orchestrator)

- [ ] T022 [ORCH] [US1] **Extraction of the 3 real PDFs** under `agent-admit.sh --tag textbooks -m 6G -T 3600` and the T006 isolation: `ingest-textbooks.sh --extract` into
      `$SCRATCH/textbooks/` (not the tree). Record per book `{pdf_sha256, pages, sections, skipped_stub_pages, extraction_failures, sidecar_sha256, seconds}`; run twice and require equal
      sidecar sha256 (determinism); expected sections 179 / 513 / 983 = 1675 (017 T017 — **re-derive, do not trust**). `extraction_failures` > 0 → report per page, do not hide. Evidence
      `extract.json` (numbers only).
- [ ] T023 [ORCH] [US1] **Diagram extraction** for the 3 PDFs (`--diagrams`): record per book `{candidates, high_quality, low_quality, vector_source_available, no_automated_redraw}`, total bytes of
      the PNG tree, the number of pages carrying ≥ 1 diagram; convert to relative paths in `diagrams.json`. Cookbook expected 94 candidates (87 high / 7 low) per 017 — re-derive; the other two books
      are `UNCONFIRMED` until this task. Free disk checked first (T007); abort rc 2 if < 2× the estimate.
- [ ] T024 [ORCH] [US1] **Dry run on a COPY of the live registry** (`--dry-run`): rows `34817 → 36492` (re-derive both numbers), changed existing rows 0, counts by kind unchanged except
      `+textbook_section`, `content_type=textbook` on every added row; second run new 0 / changed 0; `filename_shape_rows` (expected 3, T005); `pages_over_embed_limit` per book; `/api/chapters`
      expectation unchanged (6). If any pre-existing line differs after a no-op sync → STOP (finding, not tolerance). Evidence `registry-diff.json`.
- [ ] T025 [ORCH] [US1] **Retrieval baseline BEFORE** (read-only): the committed benchmark questions through the retrieval path only (`GET /api/search`, no generation; if T003 proved
      `bench-retrieval.sh` retrieval-only, use it) against the isolated server on the registry copy WITHOUT textbooks; record per-question top-5 hit/miss and the aggregate. The compose comment's
      "15/22" is a claim to re-measure, not a baseline.
- [ ] T026 [ORCH] [US1] **Rehearsal on the isolated server with the textbook registry copy**: boot with an Ollama **recording proxy** in front of the embedder; after the boot-time index pass assert
      (1) embed requests == number of new passages (carry-forward copies the old vectors — 017 measured exactly this), (2) requests to any path other than the embedding endpoints = 0 (no
      `generate`/`chat`), (3) `/api/index/status.pid_count` == registry rows, (4) a book-unique term returns a `textbook_section` hit with `content_type=textbook`, a nonsense term returns 0, (5)
      the AFTER retrieval numbers; regression rule: any question that hit in BEFORE and misses in AFTER is listed; > 0 regressions → STOP and bring to the operator (do not tune retrieval in this
      feature). Evidence `rehearsal.json`.
- [ ] T027 [ORCH] [US1] **Rollback rehearsal** on the isolated server: `promote-registry.sh --rollback` restores the pre-merge sha; boot; textbook hits gone. Proves reversibility before the
      live step.
- [ ] T028 [ORCH] [US1] **Human checkpoint — operator go/no-go** (§11.4.66): present T022-T027 numbers, the licence note (textbook text enters tracked files of the private repo `curriculum/textbooks/*.sections.json`
      and `passages.jsonl`; the operator directive of 2026-10-20 is the recorded basis), the ~45-minute restart window and the rollback path. Record the decision and time. No live write before this.
- [ ] T029 [ORCH] [US1] **Live merge via the 019 procedure**: `deploy-gate.sh --pre` → `ingest-textbooks.sh --apply` (sidecars to `curriculum/textbooks/`, `catalogue.json --final`, real-copy backup with
      pre-digest, `promote-registry.sh --apply --require-verdict`, `verify-backup-distinctness.sh`, `registry-restamp-content-type -check` rc 0) → commit explicit paths only (§11.4.84: pre-commit
      mutation-marker grep; no `git add .`) with the review GO (T021) referenced; workshop gitlink + `helix-deps.yaml` moved together by the orchestrator.
- [ ] T030 [ORCH] [US1] Restart (`restart.sh --require-verdict`), wait for boot (measure and record seconds to health, to search, to crossrefs), `deploy-gate.sh --post` → PASS.
- [ ] T031 [ORCH] [US1] **LIVE verification of ingestion** (script `evidence/020-<run>/live-ingest.sh`, authored by a subagent, run by the orchestrator, `_live_auth.sh` for the token):
      provenance `corpus.by_kind.textbook_section == 1675` and `by_content_type.textbook == 1675` (or the T022 numbers); `/api/chapters` count unchanged; a book-unique term → ≥ 1
      `textbook_section` hit, same term with `content_type=transcript` → none of them; nonsense term → 0 hits; `/api/passages/{pid}` for one pid per book → 200 (and the T005 pages → 410
      `withheld`, counted, not hidden). Writes `result.json` (`{check, expected, observed, rc}[]`) and `manifest.sha256`. DONE only when all rc 0 **and** the same script against the pre-merge
      registry copy yields rc ≠ 0 (paired negative).
- [ ] T032 [ORCH] [US1] **Model-free evidence file** `evidence/020-<run>/model-free.json`: the guard's three arms (T019) re-run against the REAL procedure's command list (from the shell history of the
      T022-T029 runs, `execve` trace of the extraction) — `model_calls: 0`, the exec'd tool list, and, separately and disclosed, the boot-time embedding request count from T026 (D-EMB). Hash-manifested.

**Checkpoint US1**: 1675 `textbook_section` rows live, rows-only and idempotent, zero model calls in the procedure (kernel-level proof), reversible.

---

## Phase 4: User Story 2 — `/textbooks` lists each ingested book (P1)

- [ ] T033 [TDD] [US2] [SUBAGENT] Write failing `internal/api/textbooks_test.go` for `GET /api/textbooks` and `GET /api/textbooks/{id}` (`contracts/textbooks-api.md`): shape; counts equal the
      catalogue joined with the fake registry; `state` ∈ `ingested|partial|not_ingested`; `license_basis` echoed verbatim from the catalogue; no key named `path`/`source_ref`/`filename`; the body is unchanged by
      `sourceref.RedactJSON` and does not match `search.HasSourceFilenameShape`; absent catalogue → 200 `{books:[]}` with `catalogue:"absent"` (determined negative) while unreadable/invalid →
      503 with reason; unknown id → 404; id not matching the slug pattern → 404 (never reaches the filesystem); deterministic ordering (`order` then id). **Oracle**: typed expectations + the
      Python-built golden catalogue. → RED.
- [x] T034 [TDD] [US2] Implement `internal/api/textbooks.go` (list + detail) using `internal/textbooks`; green with `-race`. — DONE s13 commit 613d0b6 (worktree s13-020-textbooks-ui): internal/api/textbooks.go, evidence/s13/run.txt
- [ ] T035 [TDD] [US2] Implement `cmd/workshop-server/wire_textbooks.go` (NEW): `registerTextbooks(mux, cfg, loadedRegistry)`, mounted **unconditionally** (absent catalogue ⇒ determined-empty, not 404;
      §11.4.254), boot log line `textbooks: books=N sections=M state=…`; `wire_textbooks_test.go`. (`main.go` hook line is T041.)
- [ ] T036 [TDD] [US2] [SUBAGENT] Write failing frontend specs `textbooks-model.spec.ts` + `textbooks-list.component.spec.ts` against `testing/textbooks.fixture.json`: one row per book with title, license basis
      (shown as stated, with the label "License basis"), section count, diagram count, page count, state badge; `not_ingested` shows "catalogued, not yet live" (never a count of 0 that looks like an
      empty book); empty and unavailable states differ; no raw status codes in the UI; counts formatted. Oracle: fixture numbers. → RED.
- [ ] T037 [TDD] [US2] Implement `features/textbooks/{textbooks.routes.ts,textbooks-api.ts,textbooks-model.ts,textbooks-list.component.ts}` (standalone, OnPush, no `innerHTML`). Green; `ng build` clean;
      `check-design-system` + `check-platform-tokens` rc 0.
- [ ] T038 [P] [US2] Playwright `e2e/textbooks.spec.ts` (isolated server): the spec reads `curriculum/textbooks/catalogue.json` itself (node `fs`) and independently counts `textbook_section` rows in the
      served registry copy with a line scan, then asserts the page shows the same titles and numbers; license basis string equals `books.json`'s.
- [ ] T039 [P] [US2] a11y/responsive pass (extend `a11y-responsive.spec.ts` with `/textbooks`).
- [ ] T040 [REVIEW] [US2] Review (Opus xhigh) of T033-T039: disclosure surface of the new JSON, guard invariance, honesty of `not_ingested`, UI wording. Verdict file.
- [ ] T041 [ORCH] [US2] Hooks: nav **Textbooks**, lazy route, vocabulary rows (labels/hints for `state`, `license_basis`, figure quality words), Curriculum-home entry, `registerTextbooks(...)` in `main.go`.
      Run the vocabulary paired-mutation gate and `ng build`; commit the hook diff only.
- [ ] T042 [US2] **UI-visible acceptance US2 (operator watches)**: `evidence/…/ui-acceptance-us2.md` — sign in → **Textbooks** → three books with title, license basis, sections, diagrams → counts equal the
      T022/T023 numbers. Screenshots in the private evidence dir.

**Checkpoint US2**: `/textbooks` lists the 3 books with numbers equal to the independent oracle.

---

## Phase 5: User Story 3 — Search results carry a usable citation (P1)

- [ ] T043 [TDD] [US3] [SUBAGENT] Write failing tests for `GET /api/textbooks/citations?pids=<csv>` (`contracts/textbooks-api.md`): pid of a live textbook row → `{book_id, book_title, section_title, page}` where
      `page` equals the registry's `source_ref.line_start` (degenerate page range) and `section_title` the catalogue's; non-textbook / unknown / suppressed pid → `null` (indistinguishable bodies);
      > 50 pids → 400; malformed → 400; response unchanged by `RedactJSON`, no `path` key, `HasSourceFilenameShape` false for all citation strings of the fixture. **Oracle**: sidecar-derived expectations typed
      in the test. → RED.
- [x] T044 [TDD] [US3] Implement the citations handler in `internal/api/textbooks.go` (or `textbooks_citations.go`), green with `-race`. — DONE s13 commit 613d0b6 (worktree s13-020-textbooks-ui): internal/api/textbooks.go, evidence/s13/run.txt
- [ ] T045 [TDD] [US3] [SUBAGENT] Write failing frontend specs: `textbook-citation.component.spec.ts` (given search hits, ONE batched citations request for the textbook-kind pids on screen; renders
      "`<book> · <section> · PDF page N`" with a router link to `/textbooks/<id>/page/<N>`; accessible name; non-textbook hits untouched; a failed lookup leaves the hit unchanged with no error banner;
      a hit with `kind=textbook_section` whose citation is `null` shows "textbook (source not available)" rather than a fabricated one) and `textbook-search.component.spec.ts` (the
      "Search textbooks" box calls `/api/search?content_type=textbook`, shows the facet in plain words, empty vs failed states). Oracle: `HttpTestingController` log + fixtures. → RED.
- [ ] T046 [TDD] [US3] Implement `features/textbooks/textbook-citation.component.ts` and `textbook-search.component.ts`; green.
- [ ] T047 [TDD] [US3] [SUBAGENT] Write failing tests for `GET /api/textbooks/{id}/pages/{n}` (`contracts/textbooks-api.md`): returns `{book_id, page, pid, section_title, prev, next, diagrams:[index…]}`
      without text (text stays on the single `/api/passages/{pid}` path so the suppression/publication guards remain the only gate); `n` not an integer or < 1 or > `total_pages` → 400/404 per contract;
      a page with no extractable text (skipped stub) → 404 `page_has_no_text` (determined negative); `prev`/`next` skip such gaps and are `null` at the ends. → RED.
- [ ] T048 [TDD] [US3] Implement the page endpoint; green.
- [ ] T049 [TDD] [US3] [SUBAGENT] Write failing specs `textbook-page.component.spec.ts`: header "`<book> · <section> · PDF page N`"; page text loaded through `WorkshopApi.passage(pid)`; the 410
      `withheld` case (spec.md B11 pages) renders the plain-English sentence from the vocabulary rows ("This page cannot be shown here because it contains a file name the server never discloses") with
      prev/next still working; prev/next links; figures strip placeholder; deep link reload works. → RED.
- [ ] T050 [TDD] [US3] Implement `features/textbooks/textbook-page.component.ts`; green.
- [ ] T051 [ORCH] [US3] Hooks: `<wk-textbook-citation>` in the search hit card and in the passage page (one line each, reviewed first — T053), vocabulary rows for the new sentences.
- [ ] T052 [P] [US3] Playwright `e2e/textbook-citation.spec.ts`: search for a term chosen by the spec from the sidecar (hashed in logs); the hit shows the citation; click opens the page view; the page
      number displayed equals the sidecar's `line_start` read by the spec itself; prev/next reach adjacent pages; keyboard path works.
- [ ] T053 [REVIEW] [US3] Review (Opus xhigh): citation honesty (PDF page index vs printed page label — the UI says "PDF page"), the by-pid resolver as an enumeration oracle (suppressed vs unknown
      indistinguishable), hook lines, the 410 path. Verdict file.
- [ ] T054 [US3] **UI-visible acceptance US3 (operator watches)**: search a term → the hit reads "book · section · PDF page N" → click → the page opens at page N with its text → follow "next page".

**Checkpoint US3**: a search hit from a book names the book, section and page, and opens that page.

---

## Phase 6: User Story 4 — Browse the sections of a book (P2)

- [ ] T055 [TDD] [US4] [SUBAGENT] Write failing tests for `GET /api/textbooks/{id}/sections?offset=&limit=&chapter=` (≤ 100 per page, default 50; `offset` beyond total → empty list with `total`; `limit` clamped; `chapter` =
      a catalogue chapter index; order by page; rows carry `{pid, page, section_title}` and no text): oracle = catalogue; plus `GET /api/textbooks/{id}` chapters list. → RED.
- [x] T056 [TDD] [US4] Implement; green. — DONE s13 commit 613d0b6 (worktree s13-020-textbooks-ui): internal/api/textbooks.go, evidence/s13/run.txt
- [ ] T057 [TDD] [US4] [SUBAGENT] Write failing specs `textbook-book.component.spec.ts`: chapter outline with section counts and page ranges, paging control, deep links `/textbooks/:id?chapter=`, clicking a row opens
      the page view, empty/unavailable states. → RED.
- [ ] T058 [TDD] [US4] Implement `features/textbooks/textbook-book.component.ts`; green.
- [ ] T059 [P] [US4] Playwright: outline totals equal the catalogue; paging covers every section exactly once (union of pages == all pids, no duplicates); a chapter link filters.
- [ ] T060 [US4] **UI-visible acceptance US4**: open a book → chapter outline → open a chapter → open a section.

---

## Phase 7: User Story 5 — Textbook diagrams are displayed (P2)

- [ ] T061 [TDD] [US5] [SUBAGENT] Write failing tests for `GET /api/textbooks/{id}/diagrams` and `GET /api/textbooks/{id}/diagrams/{n}/image` (`contracts/textbooks-api.md`): the list carries `{index, page,
      caption|null, quality, width, height, redraw: "vector_source_available"|"none_available"|"undetermined"}` and no file path; the image route resolves the file **only** from the catalogue
      entry for `(id, n)` (never from user text), serves `image/png` with `X-Content-Type-Options: nosniff`, `Content-Disposition: inline; filename="figure-<n>.png"` (a neutral name), a restrictive
      `Content-Security-Policy: default-src 'none'; sandbox`, `Cache-Control: private`; index out of range → 404; a catalogue entry whose file is missing → 404 `figure_file_missing` (a finding, listed by
      the verifier); `..`/encoded separators in `{n}` → 404; there is **no** route that serves `.svg` (404, D-SVG); a byte cap (e.g. 16 MB) refuses larger files; session required. **Oracle**: fixture
      PNG bytes hashed in the test; CSP/headers typed. → RED.
- [ ] T062 [TDD] [US5] Implement the diagram handlers (`internal/api/textbooks_diagrams.go`, NEW), reading from `-curriculum`'s `textbooks/diagrams/<id>/`; green with `-race`.
- [ ] T063 [TDD] [US5] [SUBAGENT] Write failing specs `textbook-figures.component.spec.ts`: gallery tile per diagram with caption (or "Figure on PDF page N"), page link, quality badge (high / "low resolution"),
      the redraw state in plain words ("a vector version of this page exists but is not shown" / "no automatic redraw is possible for this figure"), lazy-loaded `<img>` with `alt`, a broken image
      shows the explicit "figure file missing" state (never a blank tile), filter by quality, counts equal the list. → RED.
- [ ] T064 [TDD] [US5] Implement `features/textbooks/textbook-figures.component.ts` and the "figures on this page" strip in the page view; green.
- [ ] T065 [ORCH] [US5] Place diagram files: copy `$SCRATCH/textbooks/diagrams/<id>/` to `curriculum/textbooks/diagrams/<id>/` (git-ignored — confirm with `git check-ignore -v`), verify container visibility (`podman exec
      … ls | wc -l` via the repo's runtime resolution == host count), record total bytes. Catalogue `diagrams[]` entries reference names relative to that directory.
- [ ] T066 [P] [US5] Playwright: gallery count == catalogue count == files on disk == list endpoint count; every visible `<img>` has `naturalWidth > 0`; the low-quality tiles carry the badge; no request
      to any `.svg`.
- [ ] T067 [REVIEW] [US5] Review (Opus xhigh): image-serving security (path derivation, headers, content sniffing, third-party PNG decoding is left to the browser), disk/size bounds, honesty of the redraw wording,
      copyright posture (served only to signed-in users, no download link). Verdict file.
- [ ] T068 [US5] **UI-visible acceptance US5 (operator watches)**: open a book → Figures → see figures with captions and quality badges → open one's page → see the figure on the page.

---

## Phase 8: Polish & Cross-Cutting

- [ ] T069 [P] [POLISH] Observability (§11.4.260): boot line (T035) includes `diagrams_available=N`; handlers log duration; a boot assertion warns (not fatal) when the catalogue references a missing diagram directory.
- [ ] T070 [P] [POLISH] Coverage on `internal/textbooks`, `internal/api/textbooks*.go`, `features/textbooks` (floor ≥ 85%, §11.4.224; report states coverage is necessary, never sufficient).
- [ ] T071 [P] [POLISH] Paired mutation gates: `platform/gates/verify-textbook-citations.sh` + `prove-textbook-citations-mutation.sh` (mutants: citation page off by one; cites a suppressed pid; leaks a path key;
      cites a non-textbook pid; skips the batch limit), and `verify-textbook-figures.sh` + prove (mutants: serves `..`; serves svg; wrong content type; missing nosniff). Each must turn red.
- [ ] T072 [ORCH] [POLISH] **LIVE verification script** `evidence/020-<run>/live-020.sh` (author = subagent, runner = orchestrator, after the restart): (1) `/api/health` build == HEAD, bundle served contains the
      Textbooks route (`deploy-gate.sh --post` PASS); (2) `/api/textbooks` lists 3 books with numbers == independent counts; (3) citations for one pid per book equal the sidecar's page; (4) page view for that
      page returns the same pid; (5) sections paging union == all; (6) figures list == files on disk == container count; (7) a content-type facet query returns only textbook hits; (8) `/api/chapters` unchanged.
      Writes `result.json` and `manifest.sha256`; DONE only when all rc 0 and the paired negative (stale catalogue) yields rc ≠ 0.
- [ ] T073 [ORCH] [POLISH] **Final UI-visible acceptance (operator watches)**: the end-to-end story in `evidence/…/ui-acceptance-final.md` — Textbooks → pick a book → search a concept → citation → page → figure,
      each step with expected on-screen text; screenshots stored in the private evidence dir; operator ticks each step.
- [ ] T074 [P] [POLISH] User manual `docs/textbooks.md` (§11.4.257): what is in the library, what a citation means (PDF page index, not printed label), limits (stub pages, withheld pages, no PDF download, no SVG),
      who can see it, license basis display. No book text quoted.
- [ ] T075 [P] [POLISH] Task guide `docs/guides/textbooks-ingest-a-textbook.md` (operator): the deterministic procedure end to end with the model-free guard, rollback, and the restart cost.
- [ ] T076 [P] [POLISH] Task guide `docs/guides/textbooks-find-and-cite-a-passage.md`.
- [ ] T077 [P] [POLISH] Task guide `docs/guides/textbooks-browse-chapters-and-figures.md`.
- [ ] T078 [P] [POLISH] FAQ additions to `docs/faq.md`: why a page shows "cannot be shown", why a citation says PDF page, why some figures are marked low resolution, why the PDFs cannot be downloaded, how to add a fourth book.
- [ ] T079 [P] [POLISH] Four diagram classes (§11.4.258) as Mermaid in `docs/textbooks.md`: **architecture** (PDFs → extractors → sidecars/catalogue → registry → server endpoints → Angular feature), **data-flow**
      (page → section row → pid → catalogue join → citation), **state machine** (book state `catalogued → ingested → partial → not_ingested`; page-view load states incl. withheld), **sequence**
      (operator ingest → dry run → go/no-go → promote → restart → verify; and the reader's search → citation → page). A reviewer traces one arrow per diagram to a file:line.
- [ ] T080 [REVIEW] [POLISH] Export + validate the docs (`scripts/build-exports.sh`); a separate validator agent checks content, text and visual layers, Mermaid rendered, links resolve (§11.4.168). Verdict file.
- [ ] T081 [P] [POLISH] Claim-vs-reality ledger rows (§11.4.266): "textbooks are searchable and citable", "ingestion spends no model tokens", "every figure listed is shown", "citations name book, section and page",
      "ingestion is reversible" — each with its passing challenge (T031, T032, T066, T052, T027) and bluff type.
- [ ] T082 [REVIEW] [POLISH] Whole-feature independent review (Opus xhigh, fresh agent): diff vs `main`, FR-by-FR traceability table, only hook lines in shared files, evidence hash-matches manifests, **no book text
      or image in any file that is not inside the private submodule's gitignored/evidence locations** (grep the umbrella tree for a sample of extracted sentences by hash comparison, not by pasting them).
- [ ] T083 [ORCH] [POLISH] Full-suite retest on a clean baseline (§11.4.40), ff-only merge onto `main` (§11.4.113), gitlink + `helix-deps.yaml` together (`verify-manifest-pins.sh` rc 0), `CONTINUATION.md` synced
      (§12.10), `progress.yml` ticks by the orchestrator with pasted output.

---

## Dependencies & Execution Order

- Phase 1 → Phase 2 (catalogue) → {Phase 3 US1 (data + procedure), Phases 4-7 (code on the isolated server)} in parallel; only T029-T031 need spec 019's tools and the operator's go (T028).
- US2 → US3 → {US4, US5} for UI hooks (the nav/route hook T041 comes first); backend tasks of US4/US5 are independent of UI hooks.
- The UI-visible acceptance steps for US2-US5 need the live data (T030) and the promoted frontend bundle (spec 019 US1); until then they run on the isolated server.
- T005 and T024 must complete before T049's 410 wording is final (they say how many pages are affected).

## Implementation Strategy

1. MVP = Phase 1-2 + US1 + US2 + US3: books are live, listed, and a search hit names book, section and page. 2. Then US4 (browse) and US5 (figures). 3. Polish and the
final operator walk-through (T073).

### Subagent Dispatch Strategy

Test authors (T009, T011, T013, T017, T033, T036, T043, T045, T047, T049, T055, T057, T061, T063) never implement; implementers are separate agents; reviewers a third set. Every dispatch prompt carries the content-boundary
briefing: **no book text, no private chapter text, no image bytes leave the private submodule; evidence holds counts, hashes, page numbers and ids**.

## Task counts

Total 83 tasks (T001-T083): Setup 8 · Foundational 8 · US1 16 · US2 10 · US3 12 · US4 6 · US5 8 · Polish 15.
`[TDD]` 31 · `[REVIEW]` 7 (T016, T021, T040, T053, T067, T080, T082) · `[ORCH]` 17.
