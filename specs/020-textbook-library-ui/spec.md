# Feature Specification: Textbook Library UI and Deterministic Textbook Ingestion

**Feature Branch**: `020-textbook-library-ui`

**Created**: 2026-10-20

**Status**: Draft

**Input**: Operator (2026-10-20): the three textbooks under `workshop/textbooks/ai_001/` must be in the live corpus and visible. Required: a `/textbooks`
page listing each ingested book (title, license basis, section count, diagram count); browsing a book's sections; search results whose citations are
page/location-anchored and usable (book, chapter/section, page) and open the source location; display of textbook diagrams; and a deterministic,
bash-driven ingestion procedure (extract with `pipeline/pdf_textbook_sections.py` + `pdf_textbook_diagrams.py`, `ingest-transcript -docs`, backup,
restamp, verify counts) with the license basis recorded as `operator-directed 2026-10-20` and **zero LLM / ASR token spend, proven by a hard guard**.
Gap analysis: `gap-analysis.md` §0.2, §4 item 3, §5.

**Builds on**: `specs/017-exhaustive-rag-expansion` (extractors, `textbook_section` kind, `content_type=textbook`, scratch proof of 1 675 sections),
`specs/012-document-ingestion-textbooks` (license-record intent; its PDF tasks are superseded by 017's script — reconciliation is spec 026's, not this one's),
`specs/015-universal-content-model-profile` (page-anchored citation intent — **this feature builds the textbook-specific resolver; it does not wait for 015**),
`specs/019-live-corpus-promotion-and-deploy-gate` (promotion, gate, restart procedure) and `specs/018-research-library-and-doc-reingest` (the Library UI conventions).

**Content boundary**: `workshop/` is PRIVATE; this spec is in the PUBLIC umbrella. Paths, counts, hashes and page numbers only. No book text, no figure,
no sentence from a private chapter or transcript is quoted in any file this feature creates in the umbrella.

## Verified Baseline *(read on 2026-10-20 — re-measure; do not trust)*

| # | Fact | Evidence |
|---|---|---|
| B1 | Three PDFs sit in `workshop/textbooks/ai_001/`, **git-ignored**: one of 991 pages (31.3 MB), one of 523 pages (20.6 MB), one of 183 pages (12.9 MB). | `git check-ignore -v textbooks`; 017 `progress.yml` T003 |
| B2 | The live registry holds **0** `textbook_section` rows and 0 `diagram` rows (34 817 rows: `kg_term` 24 156, `doc_section` 3 823, `transcript_segment` 3 605, `kg_area` 1 511, `code` 1 435, small `kg_*`). No Angular code mentions textbooks except one label row. | python count of `curriculum/passages.jsonl`; `grep -il textbook frontend/src/app` → `core/vocabulary.ts` only (`vocabulary.ts:102`) |
| B3 | 017 proved the extractors on a **scratch** registry: 179 + 513 + 983 = **1 675** `textbook_section` rows, `content_type=textbook`, zero extraction errors; the scratch run was deleted and **never merged** (explicit open operator decision). The slug names used then are `UNCONFIRMED`. | 017 `progress.yml` T017/T040 |
| B4 | `pdf_textbook_sections.py <doc> <out> --chapter <scope> --license-basis <text> [--path] [--min-chars]` — positional `doc`/`out` (the 017 quickstart text with `--out` is wrong). **One section per page** (stub pages < 120 chars skipped); location = degenerate range `line_start == line_end == page` (PDF page index, not printed label); title chain TOC → in-body heading → PDF metadata → filename; image-only PDFs refused (rc 2). `license_basis` is written to the **companion `*.report.json` only** (the main sidecar is decoded with `DisallowUnknownFields`). | `pipeline/pdf_textbook_sections.py:20-60, 167-175, 195-235, 300-312` |
| B5 | Pids are written back to the **main sidecar** by `ingest-transcript`; the report file carries `pid: null` for first-run sections. Anything joining the two must join by page. | `pdf_textbook_sections.py:236-312` (report built before ingest); 017 `progress.yml` |
| B6 | `pdf_textbook_diagrams.py <doc> <out> [--extract-dir]` extracts raster candidates (`page`, `width`, `height`, `quality`, `caption`, `raster_path` as an **absolute scratch path**, `vector_redraw`) into its own sidecar and directory; it is not wired into ingestion. The cookbook run found 94 candidates (87 high / 7 low quality); counts for the other two books are `UNCONFIRMED`. No raster→vector tracer exists on this host. | `pipeline/pdf_textbook_diagrams.py:244-290`; 017 `progress.yml` phase 5.5 |
| B7 | `resolveLocus` has **no** `textbook_section` case — the default branch returns the source path as `Locus.Unit` with no position. | `pkg/search/service.go:1956-2033` |
| B8 | Since operator decision 2026-10-14 #23 every JSON body passes `sourceref.RedactJSON`: `source_ref.path` is removed and a `title`/`locus.unit` equal to a removed path becomes a vetted-token label. For a textbook row (`line_start == line_end == page`) the label is **"line N"** — a page presented as a line, with no book identity. A usable citation therefore cannot be derived on the client; it needs a server-side resolver keyed by pid. | `internal/sourceref/sourceref.go:138-187` |
| B9 | `GET /api/search` already accepts `content_type` (`internal/api/search.go:31`, `:121-139`); there is no UI facet for it (UNCONFIRMED — no search-page code was read for a facet). | file named |
| B10 | The live stack mounts `../curriculum:/opt/workshop/curriculum:ro` (a directory), so files placed under `curriculum/textbooks/` are visible to the server after the next start; the registry is loaded once at boot. | `platform/compose.yml:668`; `main.go:967-977` |
| B11 | `writeJSON` answers HTTP 410 `withheld` for any body containing a source-filename-shaped token (extensions `mp4 mov mkv webm m4v avi mp3 wav tar.gz tgz zip 7z sha256`, `.part<N>`). Measured over whole-document `pdftotext -layout` page text (counts only): **3 of 184** pages of the cookbook match, 0 of 992 and 0 of 524 for the other two. So ~3 of 1 675 passages are expected to answer 410 on `/api/passages/{pid}`. (Whole-document split on form feed; the extractor's per-page text may differ — `UNCONFIRMED`, T005 re-measures.) | `internal/api/api.go:361-380`; `pkg/search/catalog.go:320-355` |
| B12 | Vector indexing at boot is a model call per passage: the compose comment records 24 929 model calls for generation 7 (embedding model, local). Carry-forward (`-embed-carry-forward=true`, live) copies unchanged vectors, so the textbook merge is expected to embed only the new passages (017 measured exactly 983 for the largest book). | `compose.yml:~678-690`; 017 `progress.yml` T040 |
| B13 | No `wire_*.go` file or `// hook:` marker exists in `cmd/workshop-server` at commit `33e9760`; the hook split is a Wave-0 orchestrator task. | `ls cmd/workshop-server` |
| B14 | `scripts/ingest.sh` has **no** textbook support (0 hits); chapter mode runs `build_transcript.py` (it can regenerate a redacted transcript) and must not be used for textbooks. | `architecture.md` §3.0 |

## Clarifications

### Session 2026-10-20 *(decisions still `OPEN` carry the default this spec implements)*

- D-LIC *(operator-given)*: the license basis is recorded as exactly **`operator-directed 2026-10-20`** for all three books, in `books.json`, in every `*.report.json`
  (`--license-basis`), in the catalogue, and on the `/textbooks` page. The value `UNVERIFIED` (017's provisional) is refused by the apply step. Note recorded for the operator:
  the textbook text enters tracked files of the private repository (`curriculum/passages.jsonl`, `curriculum/textbooks/*.sections.json`); the directive is the recorded basis.
- D-PDF `OPEN`: may the original PDFs be served in the app? → **Default: no.** "Opens the source location" means the in-app page view (the page's extracted text through the existing passage
  path) — there is no PDF route and no download link.
- D-DIAG `OPEN`: do diagram captions become searchable passages? → **Default: no** (017 left this undecided; it needs a `diagram`-kind ingestion and a retrieval-quality check). Figures are
  displayed, not searched.
- D-EMB `OPEN`: does the server's boot-time **local embedding** pass count as a "model call"? → **Default: allowed and disclosed.** It is a local embedding model, produces no generated
  text, bills no tokens and is not part of the ingestion procedure; the procedure itself (extraction, ingest, catalogue, promotion) must make **zero** network or model calls, which the guard proves.
  If the operator rules that even local embedding is forbidden, the books cannot become semantically searchable in this feature (lexical search still works).
- D-SVG `OPEN`: serve vector (SVG) page renders? → **Default: no** (third-party SVG is an active-content risk; raster PNG only).
- D-TITLES `OPEN`: display titles (and optional authors) for the three books → **Default: draft titles from the PDF metadata `Title:` field**, confirmed by the operator in `books.json`; file names are never shown. *(Reconciled by 027 on 2026-10-21: AMENDED by `docs/OPERATOR-DECISIONS-2026-10-21.md` D-03: only filename-shaped section titles are blanked, titles that are real words are kept; implemented on branch `cat-titles`, pending independent review.)*

## User Scenarios & Testing *(mandatory)*

### User Story 1 — The three books enter the live corpus deterministically (Priority: P1)

The operator runs one documented, bash-driven procedure that extracts the three PDFs, ingests their sections as `textbook_section` passages, backs up the registry, checks the
content types, verifies the counts, and goes live through the 019 promotion — with the license basis recorded as `operator-directed 2026-10-20` and with **no language-model call and no
speech-recognition run anywhere in the procedure**, proven by a guard that can fail.

**Why this priority**: nothing in the UI has anything to show until the books are in the corpus (B2).

**Independent Test**: run the procedure's dry run; compare the registry before/after with an independent line-hash diff; run the guard.

**Acceptance Scenarios**:

1. **Given** the three PDFs and `books.json`, **When** `--extract` runs twice, **Then** the sidecars are byte-identical and the per-book section counts are reported (expected 179 / 513 / 983).
2. **Given** a copy of the live registry, **When** `--dry-run` runs, **Then** the copy gains exactly the sidecar sections as `textbook_section` rows with `content_type=textbook`, no pre-existing line
   changes, and a second run reports 0 new / 0 changed.
3. **Given** `--license-basis` is missing or `UNVERIFIED`, **When** the procedure runs, **Then** it stops with exit 2 before any write.
4. **Given** the guard test, **When** it runs, **Then** it reports `model_calls: 0` from three independent arms (static deny-list and allow-list, kernel-level network trace or empty network namespace,
   a recording stand-in for the model endpoints that saw 0 requests) — and each of six seeded mutants (a `curl`, a Python HTTP import, a call to the stand-in, removed isolation, an `index-embed`
   call, a weakened deny-list) makes the guard gate fail.
5. **Given** the live merge is approved, **When** it runs through `promote-registry.sh`, **Then** a real-copy backup with a pre-write digest exists, the swap is atomic, `registry-restamp-content-type
   -check` passes, and rollback restores the pre-merge digest.
6. **Given** the restart completed, **When** the live verification runs, **Then** `by_kind.textbook_section` equals the extracted total, `/api/chapters` is unchanged, a book-unique term returns a
   textbook hit, the same term filtered to another content type returns none of them, and a nonsense term returns nothing.
7. **Given** the retrieval-only benchmark, **When** run before and after on the isolated server, **Then** no previously-hit question regresses (otherwise the operator is asked; retrieval is not tuned here).

---

### User Story 2 — `/textbooks` lists each ingested book (Priority: P1)

A signed-in user opens **Textbooks** and sees one entry per catalogued book: display title, license basis, section count, diagram count and page count, plus whether the book is live.

**Why this priority**: the operator's first question is "which books are in there and under what basis".

**Independent Test**: open the page; compare numbers to the catalogue file and to an independent registry count.

**Acceptance Scenarios**:

1. **Given** the live corpus, **When** `/textbooks` loads, **Then** three books appear with title, "License basis: operator-directed 2026-10-20", section count, diagram count, page count.
2. **Given** a book is in the catalogue but its rows are not in the running registry (merged but not restarted), **When** the page loads, **Then** it reads "catalogued, not yet live" — never a count of 0.
3. **Given** no catalogue exists yet, **When** the page loads, **Then** it says no textbooks have been ingested (a determined empty state), distinct from "could not load" (with the cause).
4. **Given** the response, **When** inspected, **Then** it contains no file name, path or `source_ref`.

---

### User Story 3 — Search results carry a usable citation (Priority: P1)

A search hit from a textbook shows **book · section title · PDF page N**. Clicking it opens that page in the app (the page's text and neighbouring pages). A "Search textbooks" box restricts search to textbook content.

**Why this priority**: a citation the reader cannot follow is not a citation (the wire currently says only "line N", B8).

**Independent Test**: search a book-unique concept; the hit names the book, section and page; the page view shows that page number and its text.

**Acceptance Scenarios**:

1. **Given** a search returning textbook hits, **When** displayed, **Then** each shows book title, section title and PDF page, and the page number equals the sidecar's `line_start` for that pid.
2. **Given** the citation, **When** clicked, **Then** `/textbooks/<id>/page/<N>` opens with the page text loaded through the existing passage path, and previous/next page controls work across gaps left by skipped stub pages.
3. **Given** a page whose text trips the server's filename-shape guard (B11), **When** its page view opens, **Then** it says in plain words that this page cannot be shown here (not an error code), and the citation and navigation still work.
4. **Given** a pid that is not a live textbook row, is unknown or is suppressed, **When** the citation resolver is asked, **Then** it returns `null` — the same bytes for all three cases.
5. **Given** the "Search textbooks" box, **When** used, **Then** only `content_type=textbook` hits are returned and the facet is described in plain words.

---

### User Story 4 — Browse the sections of a book (Priority: P2)

A book page shows the chapter outline (runs of pages sharing a resolved title) with page ranges and section counts, and a paged list of sections; each section opens its page.

**Acceptance Scenarios**: (1) the outline's section counts sum to the book's total; (2) paging visits every section exactly once; (3) a chapter link filters the list; (4) a section opens its page view.

---

### User Story 5 — Textbook diagrams are displayed (Priority: P2)

A book's **Figures** view shows the extracted diagrams: image, caption (or "Figure on PDF page N"), page link, a quality badge (high / low resolution) and an honest note on redraw
("a vector version of this page exists but is not shown" / "no automatic redraw is possible for this figure"). A page view shows the figures on that page.

**Acceptance Scenarios**: (1) the number of figures shown equals the catalogue's and the files on disk; (2) every image loads; (3) a figure whose file is missing shows an explicit missing state, never a blank
tile; (4) no route serves SVG; (5) the image response carries a neutral file name, `nosniff` and a restrictive CSP.

---

### Edge Cases

- A scanned (image-only) PDF is refused (rc 2); a book with extraction failures lists them in its report and the catalogue shows `extraction_failures > 0` — never silently fewer sections.
- Stub pages (cover, part divider) are absent from the sections; page numbers have gaps; the page view for a gap says "no extractable text on this page".
- PDF page index vs printed page label differ for front matter; the UI always says "PDF page".
- Two books with the same display title: ids differ (catalogue slug); the list shows both.
- A page longer than the embedding limit (`-embed-max-chars 6000`) is truncated for embedding only; lexical search holds the full text; the count of such pages is reported (not hidden).
- The catalogue references a diagram file that is not on disk: boot logs a warning; the figures API answers `figure_file_missing`; the verifier lists it.
- A title or section title that trips the filename-shape guard would turn a list into a 410: measured in T005 and asserted by tests; if any occurs the catalogue builder reports it for the operator to rename in `books.json` (section titles come from the PDF and are not edited).
- The books enter a 34 MB tracked registry: the registry diff is reviewed as a pure addition; textbook sidecars are tracked (they carry pids); diagram PNGs are git-ignored.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The ingestion procedure MUST be a deterministic bash-driven script (`scripts/ingest-textbooks.sh`) that runs `pdf_textbook_sections.py` and `pdf_textbook_diagrams.py`, then `ingest-transcript -docs … -kinds
  textbook_section -skip-suppressed -no-write-anchors`, builds the catalogue, backs up, restamps and verifies counts; identical inputs MUST yield byte-identical sidecars.
- **FR-002**: The license basis MUST be recorded as `operator-directed 2026-10-20` in `books.json`, passed verbatim as `--license-basis`, present in every report file and catalogue entry and shown on `/textbooks`;
  `UNVERIFIED`, empty or missing MUST stop the procedure with exit 2 before any write.
- **FR-003**: The procedure MUST make zero language-model calls and zero speech-recognition runs. A guard MUST prove it with three independent arms (static scan, kernel-level network trace or empty network
  namespace, recording stand-ins for the model endpoints) and MUST fail on seeded mutants; an arm that cannot run MUST yield exit 2, never a pass.
- **FR-004**: The registry change MUST be a pure addition (pre-existing lines byte-identical), idempotent (second run 0 new / 0 changed), content-type-valid (`registry-restamp-content-type -check` rc 0), and
  promoted only through spec 019's procedure with a real-copy backup, pre-write digest and rollback (§9).
- **FR-005**: `curriculum/textbooks/catalogue.json` MUST be generated deterministically from `books.json`, the sidecars, the reports (joined **by page** to the main sidecar's pids) and the diagram sidecars; it MUST
  contain no absolute path, username or file name.
- **FR-006**: `GET /api/textbooks` and `GET /api/textbooks/{id}` (session required) MUST return per book: id, display title, license basis, page count, section count, chapter count, diagram counts by quality, and
  `state` (`ingested|partial|not_ingested`) computed by joining the catalogue with the loaded registry; no path, file name or `source_ref`.
- **FR-007**: `GET /api/textbooks/citations?pids=` MUST return `{book_id, book_title, section_title, page}` for live, unsuppressed textbook pids and `null` otherwise (≤ 50 pids), identical bodies for
  unknown / non-textbook / suppressed, and MUST NOT contain a `path` or `source_ref` key.
- **FR-008**: `GET /api/textbooks/{id}/sections` (paged, ≤ 100) and `GET /api/textbooks/{id}/pages/{n}` MUST return metadata and neighbours only; page text MUST be loaded through the existing
  `/api/passages/{pid}` path so the suppression and publication guards stay the single gate.
- **FR-009**: `GET /api/textbooks/{id}/diagrams` and `/diagrams/{n}/image` MUST derive the file only from the catalogue entry, serve PNG only with `nosniff`, a restrictive CSP and a neutral file name, cap size,
  and 404 on any traversal or missing file; no route serves SVG.
- **FR-010**: Every new JSON body MUST be unchanged by `sourceref.RedactJSON` and MUST NOT match `search.HasSourceFilenameShape` (otherwise `writeJSON` would answer 410 `withheld`); tests assert both.
- **FR-011**: The Angular feature `features/textbooks/` (routes `/textbooks`, `/textbooks/:id`, `/textbooks/:id/page/:n`, `/textbooks/:id/figures`) MUST be added through its own `textbooks.routes.ts` and orchestrator hook
  lines (nav, route entry, vocabulary rows, citation component in the hit card and passage page); `main.go`, `app.routes.ts`, `vocabulary.ts` bodies are not edited otherwise.
- **FR-012**: The citation text MUST say "PDF page N" (the PDF page index), MUST name the book and the resolved section title, and MUST degrade to an explicit "source not available" rather than a guessed value.
- **FR-013**: UI states MUST distinguish ready / empty (determined) / unavailable (could not determine, with cause) / not-yet-live, and MUST NOT show raw status or error codes.
- **FR-014**: The feature MUST ship a user manual, three task guides, an FAQ and the four diagram classes (§11.4.257, §11.4.258), exported (§11.4.65) and validated by a separate agent (§11.4.168).
- **FR-015**: The feature MUST ship live-verification scripts writing `result.json` and a sha256 manifest (ingest: T031; whole feature: T072), with a paired negative, and an operator-visible acceptance
  walk-through per story (§11.4.262, §11.4.266).
- **FR-016**: No book text, figure or private chapter text MAY appear in any file this feature adds to the public umbrella; evidence holds counts, hashes, page numbers and ids.

### Key Entities

- **Book** — `{id, display_title, author?, scope_slug, license_basis, pdf_sha256, pages, sections, chapters, diagrams, order}`.
- **Section** — one page's extracted text: `{pid, page, section_title}`; identity = registry pid; location = PDF page.
- **Chapter** — maximal run of consecutive pages with the same resolved title: `{index, title, first_page, last_page, sections}`.
- **Diagram** — `{index, page, caption|null, width, height, quality, redraw, file}`; `file` is relative to `curriculum/textbooks/diagrams/<id>/`.
- **Catalogue** — the generated JSON of all Books; the single description the server and the UI consume.
- **Citation** — `{book_id, book_title, section_title, page}` resolved by pid.
- **IngestionRun** — one execution of `ingest-textbooks.sh`: run id, per-book counts, before/after row counts, `changed_existing_rows`, `model_calls`, backup, exit class.

## Success Criteria *(mandatory)*

- **SC-001**: After the merge the live registry holds `+N` `textbook_section` rows with `N` = the extracted section total (expected 1 675; re-derived), `content_type=textbook` on all of them, 0 pre-existing lines changed;
  second run 0 new / 0 changed.
- **SC-002**: Procedure `model_calls` = 0 on all three guard arms and on the real run's trace; every seeded mutant (6/6) turns the guard gate red.
- **SC-003**: `/textbooks` shows 3 books whose section, diagram and page counts equal an independent computation (difference = 0) and whose license basis equals the recorded string.
- **SC-004**: For a sample of ≥ 1 term per book, the search hit's citation page equals the sidecar's `line_start` for that pid and the opened page view shows that page (100% of samples).
- **SC-005**: Figures shown = catalogue figures = files on disk = files visible in the container (difference = 0); all images load.
- **SC-006**: Retrieval-only benchmark: previously-hit questions that now miss = 0, or the operator has been asked and decided.
- **SC-007**: New JSON bodies: leak/redactor/filename-shape invariance tests all green; 0 occurrences of a path or file name.
- **SC-008**: An operator completes the final UI walk-through (T073) — Textbooks → book → search → citation → page → figure — and signs each step.

## Assumptions

- Spec 019's `promote-registry.sh`, `deploy-gate.sh` and `restart.sh --require-verdict` exist when the live steps (T029-T031) run; code tasks do not need them.
- The 017 extractors are correct enough to use unchanged; defects found by the guard or by the real run are reported, not silently patched here.
- Answering stays OFF; the reranker stays OFF; nothing here changes retrieval configuration.
- The live restart costs about 45 minutes of cross-reference derivation (restart header); the operator schedules it (T028).

## Out of Scope

- EPUB / FB2 / DOCX / HTML ingestion (spec 012 residual); OCR of scanned PDFs; "generate a class/session from a textbook" (stub 022); searchable diagram captions (D-DIAG); serving original PDFs (D-PDF) or SVG (D-SVG);
  changing the filename-shape guard; tuning retrieval; reconciling 012 vs 017 vocabularies (stub 026).
