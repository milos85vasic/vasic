# Phase 0 Research: Research Library and Research-Document Re-ingestion

**Feature**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | Date: 2026-10-20

Method: read of the tree (`workshop/` at commit `33e9760`), count-only scans of `curriculum/passages.jsonl` and
the sidecars, and the analysis inputs. No authenticated live call was made; anything that needs one is marked
`UNCONFIRMED` and given a verification task. **Content boundary**: this file names paths and numbers only.

## R-1 Reuse the section browser, or build a Library?

**Finding.** `GET /api/sections/{section}` (`internal/api/sections.go:154`) and `/section/:section`
(`app.routes.ts:171`) already enumerate a docs sub-tree and render markdown. They enumerate **only `.md`** (the
walk skips every other extension, `sections.go:225-227`), so `html`/`pdf` siblings and the 5 `poc/` supporting
files are invisible to it, and the header has no link to it.

**Decision.** New `GET /api/library` + `features/library/`, **reusing** `documentTitle` / `docsHref` (same Go
package, no edit to `sections.go`) and `wk-document-view` / `parseMarkdown` (no new renderer). The section
browser is left untouched; the Library is the research-specific, format-aware door.

**Rejected.** (a) Extending `sections.go` to include other extensions — it deliberately excludes them to make a
filename-disclosure class impossible (its own header); widening it widens that class. (b) Linking the nav to
`/section/research` — lists `.md` only, misses the 5 supporting files and every html/pdf sibling, and gives no searchable-state column.

## R-2 Where do research documents come from at ingest time?

**Finding.** The 5 missing documents already have `.sections.json` sidecars on disk, but those lack `content_type`
and pids (spec.md B3), and `ingest-transcript` rejects a row with no `content_type` (`content_type.go:63-66`). The
sidecars are therefore stale artefacts of an older `md_sections.py` run, not ingest-ready.

**Decision.** Regenerate each sidecar with the standing convention used by `scripts/ingest.sh:886`:
`md_sections.py <md> <sidecar> --chapter docs --path docs/research/<rel> --content-type authored_lesson
--code-content-type code`. Pids stay in the sidecar (the four already-ingested documents carry no markdown
anchors, spec.md B4), so `-no-write-anchors` is mandatory: anchors would rewrite the `.md` files and make their
`.html`/`.pdf` exports stale.

**Rejected.** `ingest.sh --corpus` — sweeps all of `docs/**` + `curriculum/**` (`ingest.sh:1017-1073`); a blast
radius of hundreds of files to add 5.

## R-3 Route shape

**Decision.** `/library` (list) and `/library/read?doc=<id>` (reader) — `doc` is the percent-encoded relative path
without extension. A path segment would need a custom `UrlMatcher` for variable depth (root docs have 1 segment,
`clients/jordan/x` has 3), and encoded `/` inside a path segment is rewritten by some reverse proxies. A query
parameter is transport-safe and still deep-linkable.

## R-4 `content_type` for research

**Finding.** `doc_section` allows `{meeting_notes, authored_lesson}` (`content_type.go:19-22`). The already-ingested
research rows are `authored_lesson` (118 rows). Staying consistent keeps one population for the 9 documents.

**Decision.** `authored_lesson` (spec.md Q1, default). Changing the closed vocabulary is a domain.go change owned
by spec 012 and is not smuggled into this feature.

## R-5 Redaction

**Finding.** `retrieval-and-grounding.md` has four literal `## [REDACTED]` headings. The 9 rows already ingested
for that document are fewer than a full section set, consistent with the headings being withheld (UNCONFIRMED
which pids are suppressed; counts only are read).

**Decision.** A new pre-ingest filter (`pipeline/research_redaction_filter.py`) drops any sidecar row whose text,
after stripping heading markers and whitespace, equals the literal `[REDACTED]`, and exits 2 if a row's text
cannot be classified (unreadable encoding). Existing suppression records are untouched. The ingest uses
`-skip-suppressed` so a suppressed pid is never offered. The Library reports `withheld_sections` from the
registry's suppressed rows plus the literal-heading count, as a number.

## R-6 Binary and rendered siblings under `/docs/`

**Finding.** `guardStatic` is a suppression guard over a file server; its handling of non-text files is not read
in this plan (`main.go:3616-3623` shows only the composition). The `.html` and `.pdf` exports of a document are
produced from the same markdown, so they contain the same literal `[REDACTED]` headings and no more.

**Decision / verification.** T003 fetches one `.pdf`, one `.html`, one `.md` and one `.epub` under a session and
records status, content-type, byte length; a test asserts the PDF/HTML of the redacted document do not contain
any text beyond the markdown's own (compare extracted text to the markdown stem for the redacted headings).
`UNCONFIRMED` until then.

## R-7 How does the UI know a search hit is a research document? *(CORRECTED 2026-10-20 during authoring)*

**Finding (verified in source).** The first draft assumed `locus.unit` carries the source path for a `doc_section`
(`pkg/search/service.go:1986-1994`). That is true inside the process but **not on the wire**: since operator decision
2026-10-14 #23 the response is rewritten by `sourceref.RedactJSON` — `source_ref.path` is dropped and a `locus.unit`/`title`
equal to a removed path becomes a vetted-token label (`internal/sourceref/sourceref.go:1-100`, `Label` at `:141`). A research
hit arrives as a line-span label such as "lines a–b" with no document identity.

**Decision.** A server-side resolver `GET /api/library/sources?pids=` (contracts/library-api.md): the registry still holds
`source_ref.path`, the server maps pid → listed document and returns only `{id,title}` of documents the Library already
lists. The UI batch-resolves the hit pids it has on screen (≤ 50) and renders the document link. Search-within-library calls
`/api/search?chapter=docs` and keeps the hits the resolver attributes to research, reporting "N of M kept".

**Rejected.** (a) Parsing the label — it is built to carry no identity. (b) Re-adding a path to search hits — reverses operator
decision #23. (c) A client-side map from titles to documents — fragile and a disclosure of the title-to-path relationship.

## R-8 Listing performance and caching

**Decision.** Walk the research tree per request (cheap: ~15 files) but cache the registry-derived passage counts
per path keyed by the registry's loaded content hash, invalidated at the next boot (the registry is not reloaded
live, `router.go` R5 comment). A benchmark asserts < 50 ms for a 500-file synthetic tree.

## R-9 Deep-web research

Operator rule §11.4.150 asks for multi-angle research per change. For this feature the questions were: how do
mature docs UIs list heterogeneous-format documents (format badges, per-format links), and how is path
traversal prevented in file-listing APIs (allow-list of extensions, `filepath.EvalSymlinks` + prefix check after
cleaning, reject encoded separators). No network research tool was used in this authoring pass; the T001 task
records an operator-visible research note with sources fetched at execution time. `UNCONFIRMED` until then.
