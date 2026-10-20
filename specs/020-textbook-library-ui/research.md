# Phase 0 Research: Textbook Library UI and Deterministic Textbook Ingestion

**Feature**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | Date: 2026-10-20

Method: read of `workshop/` at commit `33e9760` (extractors, `ingest-transcript`, `search`, `sourceref`, `api`, compose, frontend routes/models/vocabulary), count-only scans of the registry and
of the three PDFs (`pdftotext -layout`, form-feed split; counts and page numbers only — no text retained). No book content is reproduced here.

## R-1 Why a catalogue at all? (instead of reading the registry)

**Finding.** Everything the `/textbooks` page needs is either absent from the registry or deliberately hidden from the wire: the **license basis** is written only to the companion report file
(`pdf_textbook_sections.py:300-312`; the main sidecar rejects unknown fields), the **section title** per page lives only in the report (`_section_title`), the book's **display title** exists nowhere,
**diagram** data lives in a separate sidecar not wired to ingestion, and `source_ref.path` is stripped from every response (B8).

**Decision.** A small, deterministic, tracked `catalogue.json` built from `books.json` (operator input) + sidecars + reports + diagram sidecar, joined to the registry at runtime by `scope` (the
`--chapter` slug) and pid. The server loads it once (strict decode, invariants checked), the registry join supplies live counts and state, and nothing path-shaped ever enters it.

**Rejected.** (a) Extending `Passage.Attrs` with title/licence — the closed vocabulary and `DisallowUnknownFields` decode belong to spec 012/017; widening them is a cross-spec change. (b) Reading
sidecars at request time — the server mounts `curriculum` read-only but sidecars hold full text (large) and pids change on re-ingest; one derived file is cheaper and testable. (c) Client-side joins —
the client cannot see the path (B8).

## R-2 The by-page join (report ↔ main sidecar)

**Finding.** The extractor's unit is one page and it emits at most one section per page (`pdf_textbook_sections.py:195-215`). The report is written **before** ingestion with `pid` only if carried
forward (`:236-312`), and `ingest-transcript` writes assigned pids back into the **main** sidecar. After a first ingest the only complete pid list is in the main sidecar.

**Decision.** `textbook_catalogue.py --final` joins `report.sections[].line` (page) to `main.sections[].line_start` (page) to obtain `(page, pid, section_title)`; two sections on one page, a missing pid,
or a page present in one file only is a hard error (rc 1) — never a silent drop. `--draft` (before ingest) allows null pids so the dry run can produce a catalogue for review.

## R-3 Citation resolution must be server-side and by pid

**Finding.** `resolveLocus` has no textbook case (`service.go:2024-2033`) and the redactor rewrites whatever it derives into "line N" (`sourceref.go:176-182`). A page cited as "line 57" is a wrong citation
(a PDF page is not a line) and names no book.

**Decision.** `GET /api/textbooks/citations?pids=` returns `{book_id, book_title, section_title, page}` for live textbook pids. It does not reveal whether a `null` pid is unknown, suppressed or another
kind. The UI batches the pids on screen (≤ 50). Editing `resolveLocus` is not needed and would touch a shared search file; recorded as an optional follow-up (a `textbook_section` case with position `p.N`).

**Why "PDF page".** The extractor's page is the PDF page index. Printed page labels differ in front matter; claiming a printed page would be a guess (§11.4.6). The UI says "PDF page N".

## R-4 What "chapter/section" can honestly mean

The extractor resolves **one title per page** through TOC → heading → metadata → filename (`:20-60`). It has no second hierarchy level. The catalogue therefore exposes **section title** (that resolved title)
and derives **chapters** as maximal runs of consecutive pages with the same title. The UI labels them as such. A real two-level TOC would need extractor work (out of scope) and is recorded as a follow-up.

## R-5 The model-free guard — three independent arms

The claim "no LLM/ASR spend" is a negative claim, which a single check cannot establish. Arms: **(A) static** — deny-list of tokens and an allow-list of external commands over the procedure's sources
(cheap, catches the obvious); **(B) kernel-level** — run the fixture procedure under `strace -f -e trace=network` (or an empty network namespace where every connect fails and the procedure must still
succeed), counting `connect()`/`sendto()` — catches anything that actually tries to talk, including children and libraries; **(C) environmental** — recording stand-ins on the Ollama and answering endpoints
saw 0 requests. A guard that cannot observe (no tracer, no namespace) returns **2**, not 0 (§11.4.201: a gate must assert the real condition). Six seeded mutants prove each arm can fail.
**Honest boundary.** The guard covers the procedure's commands, not the server's later boot-time embedding pass (B12) — that is disclosed separately (D-EMB), with the request count measured on the isolated
server through a recording proxy and the "only embedding endpoints" rule asserted.

## R-6 Filename-shape guard collision (B11)

**Finding.** The boundary guard `writeJSON` → `HasSourceFilenameShape` makes any body containing e.g. a `.wav`/`.zip`/`.mp3` token a 410. A technical book legitimately mentions such file names.
Measured: 3 of 184 pages in the smallest book, 0 in the other two (whole-document text; per-page extractor text may differ — T005 re-measures).

**Decision.** Do **not** weaken the guard (it protects private recordings). Treat the affected pages as "cannot be shown here": the catalogue lists them (metadata is safe), the citation works, the page view
shows a plain sentence. The count is reported to the operator in the dry run (T024). A masking alternative (replace the token inside textbook snippets only) would be a change to the guarded serializer and is
**not** proposed here.

## R-7 Image serving

Diagrams are third-party raster PNGs extracted by `pdfimages`. Serving risk is content sniffing and path derivation, not execution. Decisions: file path comes only from the catalogue entry for `(id, index)`;
fixed `Content-Type: image/png`, `X-Content-Type-Options: nosniff`, `Content-Security-Policy: default-src 'none'; sandbox`, `Cache-Control: private`, neutral `Content-Disposition` filename (never the
original), size cap, session required. SVG is not served (a `pdftocairo -svg` page is active-content-capable markup derived from a third-party file; D-SVG).

## R-8 Disk and the container

`curriculum` is a read-only directory bind (`compose.yml:668`); anything under `curriculum/textbooks/` is visible after the host copy without a mount change. PNG volume is unknown until T023 (the cookbook
alone has 94 candidates). The tree is git-ignored for diagrams; the catalogue records sizes and a content hash per figure so a missing/changed file is detectable.

## R-9 Retrieval impact

Adding 1 675 long prose passages to a corpus of 34 817 mostly short rows can displace results. 017 added a `content_type` filter but left the default search unscoped. The merge is gated on a
retrieval-only before/after run (T025-T026); any previously-hit question that now misses goes to the operator. Reranker/answering configuration is not touched (the compose comment records that
turning the window reranker on regressed top-5 15/22 → 11/22 — a claim to re-measure, not rely on).

## R-10 Deep research (§11.4.150)

Planned in T008 and executed at implementation time (sources recorded): page-anchored citation conventions in RAG UIs, deterministic PDF text extraction (poppler version pinning, layout mode),
safe image delivery. The design above does not depend on any unverified external claim.
