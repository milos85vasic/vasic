# Feature Specification: Research Library and Research-Document Re-ingestion

**Feature Branch**: `018-research-library-and-doc-reingest`

**Created**: 2026-10-20

**Status**: Draft

**Input**: Operator observation (2026-10-20): "I can see none of the research. The research documents are
somewhere under `workshop/docs/research` but nothing in the application lets me open them, and searching for
what is in them finds only some of them." Gap analysis (`gap-analysis.md` §0.3, §4 item 1, §5): research docs
are only partly in the corpus and have no UI door.

**Builds on**: `specs/001-workshop-curriculum-platform` (passage registry, `/docs/` static route, search),
`specs/017-exhaustive-rag-expansion` (content-type classification, deterministic doc ingestion, `docs` scope),
and the existing `features/section` browser (`/section/:section`, `GET /api/sections/{section}`). This feature
**extends** those; it adds no second document server, no second renderer and no second ingestion path.

**Content boundary**: `workshop/` is a PRIVATE submodule and this spec lives in the PUBLIC umbrella. This
document names paths and counts only. No sentence from any research document, client document, transcript or
chapter is quoted here, and no task below may paste one into a spec, commit message, progress file or evidence
file that is committed to the umbrella.

## Verified Baseline *(informational; every row was read from the tree on 2026-10-20 — re-measure, do not trust)*

| # | Fact | Evidence |
|---|---|---|
| B1 | `workshop/docs/research` holds **9 research documents**, each as an `.md` source with `.html`, `.pdf` and `.sections.json` siblings: 4 at the root level of the research tree (asr-transcription-and-provenance, retrieval-and-grounding, skills-and-plugins-2026-09-01, ux-research-2026-09-01), 1 under `clients/jordan/`, and 4 under `education-platform/`. `education-platform/poc/` holds 6 files: 5 supporting files (a component `.ts`, two `.py`, a sample `.epub`, a sample output `.txt`) and one `*.sections.json` sidecar of the sample, which is internal and is not listed (contract invariant 3). | `find workshop/docs/research -type f` |
| B2 | The registry (`curriculum/passages.jsonl`) holds passages for only **4 of the 9** research documents: skills-and-plugins (59), ux-research (41), asr-transcription (12), retrieval-and-grounding (9) — 118 `doc_section` + 3 `code` rows, scope `docs`, `content_type` `authored_lesson` / `code`. **Zero** rows for the Jordan client document, the four `education-platform` documents or the `poc/` sample. | python scan of `passages.jsonl` by `source_ref.path` prefix `docs/research` |
| B3 | Sidecars for the 5 missing documents already exist on disk and carry **no pids** (jordan 17 sections, adaptive-assessment 25, document-ingestion-architecture 34, gamification 25, multi-provider 19; poc sample 6). They also carry **no `content_type` key**, and `cmd/ingest-transcript` refuses a sidecar row without one — "there is no default" (`platform/backend/cmd/ingest-transcript/content_type.go:63-66`). They cannot be ingested as they stand. | python scan of `*.sections.json`; source above |
| B4 | The 4 already-ingested documents were ingested **without** `<!-- pid: -->` anchors in the markdown (grep count 0 in each) — pids are carried by the tracked sidecar. The document-ingestion-architecture doc contains 3 `pid:` occurrences (UNCONFIRMED whether they are anchors or prose). | `grep -c 'pid:' docs/research/**/*.md` |
| B5 | `GET /docs/` is mounted from `cfg.docsDir`, requires a session (cookie `session` or bearer), serves regular files only (never a directory listing) and is wrapped by the suppression guard `guardStatic`. | `cmd/workshop-server/main.go:1669`, `:3570`, `:3616-3623` |
| B6 | `GET /api/sections/{section}` already enumerates a docs sub-tree, but **only `.md` files** and three ledger files; it never reports `.html`, `.pdf` or supporting files. `GET /api/sections/research` is therefore a partial listing; whether `/section/research` renders today is UNCONFIRMED (no live authenticated call was made). | `internal/api/sections.go:154-260`, `cmd/workshop-server/main.go:1552` |
| B7 | The Angular app has **no nav entry and no route** for research documents. `app.routes.ts` routes: login, '', chapters, chapters/:slug, chapters/:slug/transcript, areas/:slug, practice/:slug, ask, search, progress, plan, passage/:pid, term/:term, status, section/:section, `**`. The header nav links Curriculum, Chapters, Search, Progress, Status. | `platform/frontend/src/app/app.routes.ts`, `app.component.ts:53-61` |
| B8 | A reusable, `innerHTML`-free markdown path exists: `core/markdown.ts` (`parseMarkdown`) and `features/section/document-view.component.ts` (`wk-document-view`, input `doc`). | files named |
| B9 | `retrieval-and-grounding.md` contains four headings that are literally `## [REDACTED]` (lines 57, 59, 143, 145). Those sections are withheld by the document's own text. | `grep -n REDACTED` |
| B10 | The live ingestion helper `scripts/ingest.sh` has a **corpus mode** that sweeps every `docs/**/*.md` except `session-evidence`, plus all of `curriculum/`. It is the wrong tool for re-ingesting 5 documents (it would touch every doc) and is not used by this feature. Its content-type convention for `md_sections.py` is `--content-type authored_lesson --code-content-type code`. | `scripts/ingest.sh:884-892, 979-995, 1017-1073` |
| B11 | `writeJSON` refuses (HTTP 410 `withheld`) any response whose serialized body contains a *source-filename-shaped* token (extensions `mp4 mov mkv webm m4v avi mp3 wav tar.gz tgz zip 7z sha256` or `.part<N>`). A passage whose text contains such a token therefore cannot be served by `/api/passages/{pid}`. Measured (counts only, same regex): **32 of 34 817** live rows match today; of the 5 documents to be ingested, **1 sidecar row** (document-ingestion-architecture) matches; 0 of the other four. | `internal/api/api.go:361-380`; `pkg/search/catalog.go:320-355`; python scan 2026-10-20 |
| B12 | Since operator decision 2026-10-14 #23 every JSON body is passed through `sourceref.RedactJSON` at the serialisation chokepoints: `source_ref.path` is removed, and any `title` / `locus.unit` that equals a removed path is replaced by a label built from vetted tokens only (chapter number, notes-section number, line span, a fixed category word). A research-document hit therefore reaches the browser as, e.g., a bare line-span label with **no document identity**; the client can no longer recognise a research hit from `locus.unit`. | `internal/sourceref/sourceref.go:1-100, 138-187`; `internal/api/suppression.go:105-109`; `core/models.ts:640-646` |

## Clarifications

### Session 2026-10-20 *(operator decisions still OPEN are marked `OPEN`; this spec states the default it will implement unless told otherwise)*

- Q1: Which `content_type` do research documents carry? → **Default: `authored_lesson`**, the value the 4 already-ingested research documents carry (B2). `doc_section`'s allowed set is `{meeting_notes, authored_lesson}` (`internal/passagestore/domain.go`, `content_type.go:19-22`); a new `research` value would change the closed vocabulary owned by spec 012. `OPEN` — operator may ask for a distinct `research` value as a separate vocabulary change.
- Q2: Is the Jordan client document shown to every signed-in user? → **Default: yes, to any signed-in user**, exactly as `/docs/` already serves it today (B5); this feature adds no new audience. `OPEN` — the operator may want it hidden from non-operator accounts; that needs a per-document audience model that does not exist (UNCONFIRMED) and is out of scope here.
- Q3: Do `poc/` supporting files become searchable passages? → **Default: no.** The pipeline has section splitters for `.md`, `.json` and `.sh` only (`pipeline/md_sections.py`, `json_sections.py`, `sh_sections.py`); there is no `.py` or `.ts` splitter, and the `.epub`, sample `.txt` and sample `.sections.json` are binary or data. Writing a new splitter is outside this feature. They are always *listed* and *openable*; the fenced code inside the markdown documents is already ingested as `code` passages by `md_sections.py`. `OPEN` — the operator may ask for a splitter as a separate feature.

## User Scenarios & Testing *(mandatory)*

### User Story 1 — See every research document in one place (Priority: P1)

A signed-in learner or operator opens **Library** from the header and sees every document under the research
tree, grouped (root research, Jordan client, education platform, education platform proofs-of-concept), each row
showing a title, the formats that exist (Read, HTML, PDF), and whether the document is searchable.

**Why this priority**: the operator's literal complaint is that the research is not reachable. Nothing else in
this feature has value if the documents cannot be found.

**Independent Test**: sign in, click Library, count rows.

**Acceptance Scenarios**:

1. **Given** the research tree as it stands (B1), **When** the Library page loads, **Then** exactly 9 documents
   and 5 supporting files are listed, grouped as above, and the counts shown on the page equal the counts
   `find` reports on disk.
2. **Given** a document that exists only as `.md` (no `.html`/`.pdf`), **When** it is listed, **Then** the missing
   formats are shown as absent, not as dead links.
3. **Given** a new research document is added to the tree later, **When** the Library page is next loaded,
   **Then** it appears with no code change and no redeploy of the frontend (the listing is derived at request
   time, never hardcoded).
4. **Given** the docs root cannot be read, **When** the page loads, **Then** it shows an explicit "could not
   determine" state with the cause — never an empty list that looks like "no documents".

---

### User Story 2 — Open and read a research document (Priority: P1)

From the Library, the reader opens a document in-app (rendered markdown with headings, tables, code) or opens
its prepared HTML or PDF in a new tab. Supporting files open as code, text, or a download link.

**Why this priority**: a list that cannot be opened is a menu with no kitchen.

**Independent Test**: open one document of each type (md, html, pdf, `.py`, `.epub`).

**Acceptance Scenarios**:

1. **Given** a markdown document, **When** the reader opens it, **Then** it is rendered by the existing
   `wk-document-view` (no `innerHTML`), with a heading outline, and unsupported constructs are reported by the
   renderer's own `unsupported` list rather than silently dropped.
2. **Given** a document with `.html` and `.pdf` siblings, **When** the reader chooses HTML or PDF, **Then** the
   file served by `/docs/` opens in a new tab and carries the session (no 401).
3. **Given** a document whose source contains sections that are literally `[REDACTED]`, **When** it is opened,
   **Then** those sections show exactly as the document has them (the word, not a reconstruction), and no passage
   text for them is retrievable anywhere (FR-009).
4. **Given** a supporting file that is binary (the sample `.epub`), **When** it is opened, **Then** the reader
   gets a download link and an explicit "binary file, not previewed" note — never garbled text.
5. **Given** a path that does not exist or tries to leave the research tree (`..`, absolute path, encoded
   slash), **When** it is requested, **Then** the reader sees a not-found state and the server answered 404 —
   it never served a file outside the tree.

---

### User Story 3 — Research that is missing from search becomes searchable (Priority: P2)

The 5 research documents with no corpus rows (Jordan client document, four education-platform documents) are
ingested through the existing deterministic doc-ingestion path so that search,
passage pages and (when enabled) answering can cite them. No language model and no speech recognition is used.

**Why this priority**: the operator asked for "searching finds only some of them". Second only to being able to
see the documents at all.

**Independent Test**: search for a term that appears only in a Jordan or education-platform document; before:
0 hits from `docs/research`, after: a hit whose card links to that document in the Library.

**Acceptance Scenarios**:

1. **Given** the registry of B2, **When** the re-ingest completes, **Then** the registry gains the sections of
   the 5 documents (jordan 17, adaptive 25, ingestion-architecture 34, gamification 25, multi-provider 19 =
   120 sidecar rows, `doc_section` and fenced-code `code` kinds together; the `poc/` files add none, Q3), and
   **no pre-existing row changes** (line-hash comparison, FR-006).
2. **Given** the re-ingest ran, **When** it is run a second time, **Then** it reports 0 new and 0 changed rows
   (idempotent, FR-007).
3. **Given** `retrieval-and-grounding.md` has `## [REDACTED]` sections, **When** the research documents are
   (re)ingested, **Then** no passage is minted for a section whose heading or body is the literal `[REDACTED]`,
   and any pre-existing row for such a section remains suppressed (FR-009).
4. **Given** a search hit for a research passage, **When** it is displayed, **Then** the card names the source
   document and links to it in the Library (FR-011) — resolved by pid through a server-side resolver, because the
   wire no longer carries the source path (B12).
5. **Given** the ingest, **When** it runs, **Then** it spends zero language-model tokens and runs zero speech
   recognition (a hard guard test proves no model client is constructed, FR-008).

---

### User Story 4 — Find the Library and search within it (Priority: P3)

The header nav carries **Library**; the Library page has a filter box that narrows the document list by title
and, when the user submits, runs the existing search scoped to research documents.

**Independent Test**: type a title fragment (list narrows); submit a content term (hits are research passages
only).

**Acceptance Scenarios**:

1. **Given** the app shell, **When** any guarded page is open, **Then** a Library link is present and marks
   itself current on `/library*`.
2. **Given** a filter string, **When** typed, **Then** the list narrows client-side with no server request per
   keystroke, and an empty result says "no document matches", distinct from a failed load.
3. **Given** a content query submitted from the Library, **When** it runs, **Then** hits are limited to passages the
   pid resolver (`GET /api/library/sources`) attributes to a research document, the page says how many of the returned
   hits were kept, and each kept hit links to the reader.

---

### Edge Cases

- A re-ingested row whose text carries a filename-shaped token (B11: expected 1 row) is minted normally but its passage page answers
  `410 withheld`; the Library's `passages` count includes it and the reader (a `/docs/` file view) is unaffected. The wrapper reports the
  number of such rows in `reingest.json` (`filename_shape_rows`) so the operator sees it; it does not alter the text.
- A document that has `.md` but whose `.sections.json` is stale relative to the `.md` (the markdown was edited
  after the sidecar was generated): the re-ingest regenerates the sidecar (pid carry-forward) before ingesting,
  and a gate refuses to ingest a sidecar whose source hash does not match the markdown on disk (FR-010).
- Two documents with the same title in different groups: rows are keyed by relative path, never by title.
- File names with spaces or non-ASCII characters: the id is the percent-encoded relative path; round-trip test.
- The sample `.epub` is binary and large relative to prose: listed with size, never fetched into a text widget.
- A document that is empty or whitespace only: listed, opened as "empty", not as an error.
- The research tree is a symlink or contains a symlink to outside: symlinks that resolve outside the docs root
  are not listed and not served (FR-003).
- A suppressed pid exists for a research section: the library listing still lists the document (the document is
  a file, not a passage) but reports `withheld_sections` > 0; the reader never reveals suppressed text.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST expose `GET /api/library` (session required, under the existing `/api/` gate) that
  enumerates the research tree at request time and returns, per document: stable id (percent-encoded relative path
  without extension), title and title source, group, document kind (`document` | `supporting_code` |
  `supporting_data` | `supporting_binary`), per-format hrefs for `md`/`html`/`pdf` (null when absent), byte size,
  searchable state (`indexed` | `partial` | `not_indexed` | `undetermined`) with passage count, and
  `withheld_sections`.
- **FR-002**: The listing MUST be three-valued like every other route: `200` (possibly empty = determined
  negative), `404` for an unknown library name, `503` with a stated reason when the docs root is unconfigured or
  unreadable. A failure below the root MUST be reported in an `undetermined` list by path, never as a silent gap.
- **FR-003**: Path handling MUST fail closed: no path outside the research tree is ever listed or served; `..`,
  absolute paths, encoded separators and symlinks resolving outside the root are refused. The endpoint serves
  metadata only; bytes keep coming from `/docs/` (one way of serving a byte).
- **FR-004**: The Angular app MUST provide a lazy `features/library/` feature with routes `/library` (list) and
  `/library/read?doc=<id>` (reader), registered through the feature's own `library.routes.ts` and one hook line,
  and MUST NOT edit `app.routes.ts` / `vocabulary.ts` / `main.go` bodies outside the orchestrator hooks.
- **FR-005**: The reader MUST render markdown with `parseMarkdown` + `wk-document-view`, MUST NOT use
  `innerHTML` or `bypassSecurityTrust*`, and MUST show the renderer's `unsupported` report when non-empty.
- **FR-006**: The re-ingest MUST add rows only: after it, every pre-existing line of `passages.jsonl` MUST be
  byte-identical to before (line-hash comparison), and `rows_after − rows_before` MUST equal the number of sections
  the sidecars supply less the sections excluded by FR-009.
- **FR-007**: The re-ingest MUST be idempotent: a second run reports 0 new and 0 changed rows, enforced by the
  existing sidecar pid carry-forward (no markdown anchors are written, `-no-write-anchors`).
- **FR-008**: The re-ingest MUST NOT call a language model and MUST NOT run speech recognition. A guard test
  MUST prove that no HTTP request to an answer/generation endpoint is made by the ingest wrapper (a recording
  transport refuses and counts every outbound request). Local embedding by the existing server boot pass is the
  only model-adjacent step and spends no tokens.
- **FR-009**: Sections whose heading or whole body is the literal `[REDACTED]` MUST NOT be minted, and any
  existing row for such a section MUST stay suppressed. The wrapper MUST fail closed (exit 2) when it cannot tell
  whether a section is redacted. Text of a suppressed or redacted section MUST NOT appear in any evidence file.
- **FR-010**: Before ingest the wrapper MUST regenerate each research sidecar with the standing convention
  (`md_sections.py <doc.md> <sidecar> --chapter docs --path docs/research/<rel> --content-type authored_lesson
  --code-content-type code`) and MUST refuse (exit 2) a sidecar that lacks `content_type` on any row.
- **FR-011**: A search hit or passage page whose pid the resolver attributes to a research document MUST show the source
  document title and a link to `/library/read?doc=<id>`. The attribution MUST come from `GET /api/library/sources`
  (FR-016), never from `locus.unit`, `title` or any path-shaped wire value (B12).
- **FR-016**: The system MUST expose `GET /api/library/sources?pids=<csv>` (session required, ≤ 50 pids, malformed pid →
  400): for each pid it returns `{pid, document: {id, title} | null}`. A pid is attributed only when its registry
  `source_ref.path` resolves, after the FR-003 path rules, to a file the Library itself lists; every other pid, unknown pid or
  suppressed pid returns `document: null` — the resolver never reveals a path, a title of an unlisted file, or whether a
  suppressed pid exists (fail closed). The response contains no key named `path` or `source_ref` (so `RedactJSON` leaves it intact).
- **FR-012**: The Library MUST appear in the header nav through the orchestrator's nav hook, and in the
  Curriculum home as a labelled entry, so a signed-in user reaches it in at most one click from `/`.
- **FR-013**: Every listing or ingest outcome that cannot be determined MUST say so and name the cause; an
  undetermined result is never reported as success or as empty.
- **FR-014**: The feature MUST ship a user manual, three task guides and an FAQ, and the four diagram classes
  (architecture, data-flow, state machine, sequence), reachable from the workshop README and exported to
  html/pdf (constitution §11.4.257, §11.4.258, §11.4.65).
- **FR-015**: The feature MUST ship a live verification script that writes `result.json` and a sha256 manifest
  under `workshop/evidence/018-<run>/` (private submodule), and a claim-ledger row per advertised capability
  (§11.4.262, §11.4.266).

### Key Entities

- **LibraryDocument** — one logical research document (identity = relative path stem): title, group, kind,
  formats map, size, searchable state, withheld count.
- **LibraryFormat** — one physical file of a document (`md` | `html` | `pdf` | `sections_json` | `source`).
- **ResearchSidecar** — the tracked `*.sections.json` produced by `md_sections.py` and consumed by
  `ingest-transcript`; carries pids once ingested.
- **ReingestRun** — one execution of the research re-ingest wrapper: run id, before/after counts, line-hash diff
  result, excluded-section count, exit class.

## Success Criteria *(mandatory)*

- **SC-001**: The Library lists 9 documents and 5 supporting files, matching `find` on the tree (0 difference).
- **SC-002**: 100% of listed documents open: md in-app, html/pdf via `/docs/` with HTTP 200 under a session; 0
  dead links in the machine check.
- **SC-003**: Searching a term unique to a previously unindexed research document returns ≥ 1 hit from that
  document (before: 0), and that hit links to the reader.
- **SC-004**: The re-ingest adds rows only: changed pre-existing lines = 0; second run new = 0, changed = 0.
- **SC-005**: Sections that are literally `[REDACTED]`: minted passages = 0, retrievable text = 0.
- **SC-006**: Language-model calls and speech-recognition runs during re-ingest = 0 (guard test green and
  recorded in `result.json`).
- **SC-007**: A signed-in operator reaches the Library in ≤ 1 click from `/` and sees the document count on
  screen (UI-visible acceptance, task T045).
- **SC-008**: The paired mutation (library handler weakened to serve `..` paths / minting a `[REDACTED]` section)
  makes the corresponding gate fail (rc ≠ 0).

## Assumptions

- The live stack is the single compose project `workshop-curriculum`; the registry is mounted as a directory and
  loaded at boot (`main.go:967-977`), so new rows become searchable only after the orchestrator's restart
  (spec 019 owns the promotion procedure; this spec only produces the registry delta and the UI).
- Textbook content is out of scope (spec 020). Answering stays OFF (spec 024 stub).
- `docs/research` is the only library root in this iteration; the endpoint takes a library name so a second root
  can be added without a new route (not built here).
- Wave-0 `wire_<feature>.go` hook split may or may not have landed when this runs (UNCONFIRMED: the tree at
  commit `33e9760` has no `wire_*.go` and no `// hook:` markers). If not landed, the orchestrator adds the one
  call site `registerLibrary(mux, cfg)` by hand; the feature's own code stays in new files either way.

## Out of Scope

- Editing or uploading documents; per-document audience control; a distinct `research` content type (Q1/Q2
  `OPEN`); OCR; semantic re-ranking changes; answering.
