# Feature Specification: Document Ingestion for Textbooks (EPUB / PDF / FB2 / Other Formats)

**Feature Branch**: `012-document-ingestion-textbooks`

**Created**: 2026-09-30

**Status**: Draft

**Input**: User description: "Formalize `workshop/docs/research/education-platform/document-ingestion-architecture.md` (research wave, not yet a SpecKit spec) into a real feature specification. The research covers ingesting textbooks and other standalone documents (EPUB, PDF, FB2, and a bounded list of other realistically-relevant formats) into the workshop curriculum platform's existing chapter/passage/search pipeline — the same downstream mechanism (`ingest-transcript -docs` → `index-embed` → FTS5/semantic search → `/passage/{pid}`) that already serves Markdown `doc_section` content today. A working proof-of-concept (`epub_extract_poc.py`) demonstrates EPUB spine-order detection and heading-delimited section extraction using only the Python standard library, with real captured output. Phase 1 is EPUB-only (most textbook-relevant, most mature tooling); Phase 2 adds PDF/FB2/DOCX/HTML; Phase 3 adds OCR, extraction-failure self-reporting, and resolves the open question of whether textbook structure should ever be promoted into the curated `kg_area`/`kg_lesson_section` knowledge layer. Copyright/licensing is flagged as the single largest operational risk and needs a mandatory pre-ingestion gate. This spec is the full multi-format textbook capability, distinct from but built on the same `doc_section` mechanism a separate, concurrent effort is using to ingest chapter 04 as a first text-only (Markdown, no video/PDF) chapter."

## User Scenarios & Testing *(mandatory)*

<!--
  IMPORTANT: User stories should be PRIORITIZED as user journeys ordered by importance.
  Each user story/journey must be INDEPENDENTLY TESTABLE - meaning if you implement just ONE of them,
  you should still have a viable MVP (Minimum Viable Product) that delivers value.
-->

### User Story 1 - Ingest a licensed EPUB textbook into searchable curriculum content (Priority: P1)

An operator has a well-formed EPUB textbook with a recorded license/permission basis (public domain, an openly-licensed OER work, or a work the operator holds explicit rights to). They want its chapters and sections to become searchable, citable content in the platform — reachable by the same lexical and semantic search paths that already serve recorded video chapters and authored documents — without inventing a parallel pipeline or writing any new backend code.

**Why this priority**: This is the literal MVP the research identifies: EPUB is the most textbook-relevant format, has the most mature parsing ecosystem, and — per the research's own architecture analysis (§3.1) — needs **zero new code** below the extraction stage, because `ingest-transcript -docs`, `index-embed`, the passage registry, the FTS5 index and the `/api/suggest` catalog are already format-agnostic. The POC (`epub_extract_poc.py`) proves the extraction mechanism concretely: real spine-order detection, real heading-delimited sectioning, real output in the exact shape the ingest binary already consumes.

**Independent Test**: Ingest a real, well-formed EPUB textbook with a recorded license basis. Confirm every heading-delimited section becomes a searchable `doc_section` passage, reachable at `/passage/{pid}`, findable via both lexical (FTS5) and semantic search, and that `/api/chapters` does not list the textbook as a chapter.

**Acceptance Scenarios**:

1. **Given** a well-formed EPUB textbook file with an operator-recorded license basis, **When** the ingestion pipeline runs against it, **Then** every heading-delimited section of every spine document is minted as a `doc_section` passage, in the exact reading order given by the EPUB's own OPF `<spine>` element (not directory or filename order).
2. **Given** the same ingested textbook, **When** a search query matches text unique to one of its sections, **Then** that section is returned by both the lexical (FTS5) search path and the semantic (embedding) search path, with no source-format-specific code change required in either.
3. **Given** the same ingested textbook, **When** an operator or reader follows a citation to one of its sections, **Then** the section is servable at the existing `/passage/{pid}` route with no new frontend route added.
4. **Given** an EPUB textbook file with no operator-recorded license basis, **When** ingestion is attempted, **Then** the ingestion run is refused outright, with no passages minted, before any content is written to the registry.
5. **Given** the same textbook ingested once, **When** ingestion is re-run against the same, unchanged file, **Then** zero duplicate passages are created (the second run mints nothing new), matching the idempotency guarantee `pipeline/md_sections.py` already provides for Markdown documents.
6. **Given** the ingested textbook, **When** its registry scope is inspected, **Then** it is a non-chapter-shaped scope (e.g. `textbook-<slug>`) that `/api/chapters` correctly excludes from the chapter listing, because a textbook is not a recorded teaching session and must not be misrepresented as one.

---

### User Story 2 - Expand ingestion to PDF, FB2, DOCX and HTML textbooks (Priority: P2)

An operator has textbook material in formats other than EPUB — a PDF with a text layer, a Russian/Eastern-European FB2 ebook, a DOCX manuscript, or a standalone HTML document — and wants the same searchable, citable outcome User Story 1 delivers for EPUB, using each format's own best-fit extraction approach rather than forcing every format through one brittle converter.

**Why this priority**: The research explicitly sequences this after the EPUB MVP (§6 Phase 2): each additional format reuses the architecture User Story 1 establishes (same `{text, path, line_start, line_end, kind}` output shape, same downstream pipeline, same licensing gate) and adds only a format-specific extraction stage. It depends on User Story 1's shape being proven first.

**Independent Test**: Ingest one real fixture document per newly-supported format (a text-layer PDF, an FB2 file, a DOCX file, a standalone HTML file), each with a recorded license basis, and confirm each produces searchable `doc_section` passages through the same downstream path User Story 1 verified, with per-format extraction quality documented rather than assumed uniform.

**Acceptance Scenarios**:

1. **Given** a text-layer PDF textbook (not scanned/image-only) with a recorded license basis, **When** ingestion runs, **Then** its text is extracted using the existing `pdftotext -layout` convention already in production use elsewhere in this pipeline, and sectioned into `doc_section` passages.
2. **Given** an FB2 textbook file with a recorded license basis, **When** ingestion runs, **Then** its native `<section>`/`<title>` XML hierarchy is used directly to determine section boundaries, with no heading-inference heuristic applied (the format's own structure is authoritative).
3. **Given** a standalone HTML textbook document with a recorded license basis, **When** ingestion runs, **Then** its DOM heading elements determine section boundaries, and inline `<!-- pid: ... -->` anchor writing is used (because `.html`/`.htm` are already recognized syntax for inline anchoring), unlike EPUB's `.xhtml` sources.
4. **Given** a DOCX textbook manuscript with a recorded license basis, **When** ingestion runs, **Then** paragraph style information (e.g. "Heading 1"/"Heading 2") determines section boundaries, preserving structure rather than discarding it.
5. **Given** any of the above formats ingested, **When** its sections are inspected in the passage registry, **Then** each is indistinguishable in kind, search behavior, and citation route from an EPUB-sourced or hand-authored `doc_section` passage.

---

### User Story 3 - Operators can trust extraction completeness and quality signals (Priority: P3)

An operator ingesting real-world textbook material — which, unlike the POC's synthetic, well-formed sample, includes malformed markup, scanned pages, multi-column layouts and encoding inconsistencies — wants to know what was **not** successfully extracted, not just how many sections were. They also want scanned/image-only material to become ingestible via OCR once that capability is provisioned, rather than remaining permanently out of reach.

**Why this priority**: The research names this explicitly (§5.3) as closing a real gap: a pipeline reporting "ingested N sections" without reporting what it could not parse repeats a failure class this repository's own transcript and PDF-notes pipelines already refuse to repeat (uncertainty is marked, never silently dropped). It is Phase 3 because it is a quality/scale hardening concern layered on top of Phase 1/2's working extraction paths, not a blocker to shipping them.

**Independent Test**: Ingest a deliberately imperfect fixture set (a malformed-XHTML EPUB, a scanned-image PDF, an FB2 file with non-UTF-8 encoding) and confirm the ingestion run reports an explicit extraction-failure list naming what could not be parsed, rather than a bare success count or a silent partial result.

**Acceptance Scenarios**:

1. **Given** an EPUB whose XHTML is not strict, well-formed XML, **When** ingestion runs, **Then** the well-formed spine documents are still processed, and the malformed one is reported by name in an explicit extraction-failure list rather than either crashing the whole run or being silently dropped.
2. **Given** a scanned, image-only PDF with no extractable text layer, **When** ingestion is attempted without an OCR toolchain provisioned, **Then** ingestion is refused for that file with an explicit "no text layer, OCR not available" reason, never silently producing an empty or near-empty textbook.
3. **Given** the same scanned PDF, **When** an OCR toolchain has been explicitly provisioned by the operator, **Then** ingestion proceeds via OCR and the resulting sections are marked as OCR-derived so their lower expected fidelity is visible to anyone reviewing search results.
4. **Given** any ingestion run (any format, any completeness), **When** it finishes, **Then** it reports both the count of successfully ingested sections and an explicit list of sections/pages/documents that produced no usable text, every time — never reporting completion with the failure list silently omitted.

---

### Edge Cases

- What happens when an EPUB is DRM-wrapped (Adobe ADEPT, Kindle proprietary scheme)? → Ingestion MUST detect it cannot parse the content and refuse with an explicit reason, never attempting or implying a decryption step.
- What happens when a PDF has a genuine multi-column layout that `pdftotext -layout`'s whitespace-based reconstruction interleaves incorrectly? → Out of scope for the Phase 2 baseline (`pdftotext`); flagged as a known extraction-quality risk to be spiked against real sample material before deciding whether a stronger library is warranted (see research §2.2).
- What happens when the same textbook is re-ingested after a corrected, re-published edition changes some section text but not its position? → The same tiered idempotency strategy `pipeline/md_sections.py` already uses (inline anchor match, then exact text match, then position-range match) MUST be reused so identity survives an edit, not merely an unchanged re-run.
- What happens when an EPUB's `nav.xhtml`/`toc.ncx`-declared chapter titles don't align one-to-one with spine document boundaries (one spine file holds several TOC entries, or one TOC entry spans several spine files)? → Section boundaries follow the spine document and its internal headings; TOC entries are not treated as authoritative section boundaries.
- What happens when a textbook section is shorter than the minimum-length threshold used to filter stub sections (mirroring `MIN_CHARS` in `md_sections.py`)? → It is dropped as a stub, exactly as already happens for Markdown documents.
- What happens when an EPUB/OPF/XHTML/FB2 file comes from outside operator-curated, pre-vetted content (e.g. a future upload flow)? → It MUST be parsed with a hardened, untrusted-input-safe XML parser (not bare `xml.etree.ElementTree`), per the security concern this research's own tooling flagged (§5.6).
- What happens when a textbook's images, diagrams or tables are encountered during extraction? → Alt text (if present) is captured; image bytes and table column alignment are not preserved beyond flattened prose — a known, named Phase 1/2 limitation, not silently pretended away.
- What happens when a textbook file has an extension (`.xhtml`) that the shared anchor-writing module does not yet recognize for inline anchors? → Identity is carried via sidecar-only anchoring (`AnchorSidecar`), exactly the mode transcript segments already use in production — this is a known-good path, not a degraded one, even though it means the source file itself carries no human-visible `<!-- pid: ... -->` marker.
- What happens when an operator attempts to ingest a textbook whose license field says something other than an accepted basis (e.g. "unknown", empty, or a value that isn't public-domain/openly-licensed/explicit-rights-holder-permission)? → Ingestion is refused, identically to a missing license field — see [NEEDS CLARIFICATION: FR-005].

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST extract a Phase-1 EPUB textbook's content into `doc_section` records shaped identically to the `{text, path, line_start, line_end, kind}` sidecar contract `pipeline/md_sections.py` already produces and `ingest-transcript -docs` already consumes, requiring no new fields for ingestion to succeed.
- **FR-002**: System MUST determine an EPUB's section reading order from its OPF `<spine>` element (manifest-id order), never from directory listing order or filename sort order.
- **FR-003**: System MUST split each EPUB spine content document into sections at heading-tag boundaries (`h1`-`h6`), applying the same minimum-length stub-filtering threshold `pipeline/md_sections.py` already applies to Markdown headings.
- **FR-004**: System MUST mint every extracted textbook section through the existing `ingest-transcript -docs` invocation, requiring no new CLI flag and no `-segments` payload for a docs-only, video-free textbook ingestion run.
- **FR-005**: System MUST refuse to ingest any document whose license/permission status has not been explicitly recorded by the operator, refusing the entire ingestion run (minting nothing) rather than ingesting under an implicit or unknown license. [NEEDS CLARIFICATION: which license/permission values are accepted as a valid recorded basis — the research names public-domain works, openly-licensed OER material (e.g. CC-BY), and material the operator holds explicit rights to, as examples, but does not finalize a canonical accepted-value list or a verification mechanism]
- **FR-006**: System MUST scope all textbook-ingested content under a registry `Scope` value that does not conform to the recorded-chapter `ChapterID` grammar (e.g. a `textbook-<slug>` prefix), so that `/api/chapters` — which lists only true `ChapterID`-shaped scopes — correctly continues to exclude textbook content from the chapter listing.
- **FR-007**: System MUST preserve passage identity across re-ingestion of an updated or re-published edition of the same textbook, using the same tiered strategy `pipeline/md_sections.py` already implements — an inline pid anchor when present, then exact text match, then unambiguous position-range match — so that an edit that changes text but not a section's identity does not mint a duplicate passage.
- **FR-008**: System MUST parse any EPUB/OPF/XHTML/FB2 content that did not originate from operator-curated, pre-vetted files using a hardened, untrusted-input-safe XML parser (e.g. `defusedxml`, or an equivalently configured parser), not the bare stdlib default.
- **FR-009**: System MUST detect a DRM-protected EPUB it cannot parse and refuse ingestion for that file with an explicit reason, never attempting, implying, or silently falling through to a decryption step.
- **FR-010**: System MUST continue processing a textbook's remaining well-formed spine/section documents when one individual document fails to parse (e.g. malformed XHTML), reporting the failure explicitly rather than aborting the entire ingestion run or silently dropping the failed document with no record.
- **FR-011**: System MUST make every ingested textbook section servable at the existing `/passage/{pid}` deep-link route, requiring no new frontend route.
- **FR-012**: System MUST make every ingested textbook section searchable via the existing lexical (FTS5) and semantic (embedding) index paths (`index-embed`), requiring no format-specific code change to either index path.
- **FR-013** (Phase 2): System MUST extract text-layer PDF textbook content using the existing `pdftotext -layout` convention already in production use elsewhere in this pipeline as the default mechanism, rather than introducing a new PDF library for the common case.
- **FR-014** (Phase 2): System MUST extract FB2 textbook content by walking the format's native `<section>`/`<title>` XML hierarchy directly, using the format's own explicit structure rather than a heading-inference heuristic.
- **FR-015** (Phase 2): System MUST extract standalone HTML textbook content by walking real DOM heading elements, and MUST write inline `<!-- pid: ... -->` anchors into `.html`/`.htm` source files (already-recognized inline-anchor syntax), unlike EPUB's `.xhtml` sources.
- **FR-016** (Phase 2): System MUST extract DOCX textbook content using paragraph style information (e.g. "Heading 1") to determine section boundaries, preserving structure rather than discarding it as the pre-existing structure-discarding `_read_ooxml` regex-strip pattern does.
- **FR-017** (Phase 3): System MUST report, for every ingestion run regardless of format, both the count of successfully extracted sections and an explicit list of sections/pages/documents that produced no usable text — never reporting a bare success count with extraction failures silently omitted.
- **FR-018** (Phase 3): System MUST refuse to ingest a scanned/image-only PDF with no extractable text layer when no OCR toolchain is provisioned, reporting an explicit "no text layer, OCR unavailable" reason rather than silently producing an empty or near-empty textbook.
- **FR-019** (Phase 3): System MUST mark any section extracted via OCR as OCR-derived in a way visible to a reviewer of search results, so its lower expected extraction fidelity is not indistinguishable from directly-extracted text.
- **FR-020**: System MUST NOT automatically promote any textbook-ingested `doc_section` content into the curated `kg_area`/`kg_lesson_section` knowledge layer as part of this feature. [NEEDS CLARIFICATION: whether, and how, a textbook's own chapter/section structure should ever become eligible for promotion into `kg_area`/`kg_lesson_section` — the research (§5.5) names three live options (never automatic; semi-automatic human-reviewed promotion preserving the `authorship: assembled` marker's honest meaning; or a new, honestly-labeled parallel kind such as `kg_textbook_section`) and explicitly defers the decision to Phase 3+, not resolving it here]
- **FR-021**: The Extraction Sidecar payload's `sections[]` entries MAY carry an optional `attrs: map[string]string` field; when present, `ingest-transcript -docs` MUST pass it through unchanged into the resulting passage's `Observation.Attrs` (`passagestore.DocumentObservation`), with no key renaming, filtering or transformation. When the field is absent — true for every Phase 1 EPUB section, and for every existing `pipeline/md_sections.py` producer — `DocumentObservation` MUST continue to produce a passage exactly as it does today (zero-value `Attrs`), so this is a strictly additive passthrough with zero behavior change for any producer that does not supply it. This is the sole data channel spec 015's Location Anchor design (`specs/015-universal-content-model-profile/data-model.md`) depends on for carrying format-specific location metadata (a page number, an EPUB CFI, a heading); this feature does not choose or validate the `attrs` key names a downstream consumer writes there — only Phase 2's PDF/FB2/DOCX/HTML extractors, or a future EPUB CFI enhancement, are expected to actually populate it, so Phase 1's own EPUB extractor is not required to supply it to satisfy this FR.

### Key Entities *(include if feature involves data)*

- **Textbook Source Document**: The input file being ingested (EPUB in Phase 1; PDF, FB2, DOCX, HTML added in Phase 2). Carries a title, a derived slug, a format, and a License Record that gates whether it may be ingested at all.
- **License Record**: An explicit, operator-recorded statement of a textbook's license or permission basis (e.g. public domain, openly-licensed OER, explicit rights-holder permission). Required before ingestion; its absence refuses the entire ingestion run. Distinct from, and not served by, the existing privacy-redaction mechanism (`redactions.jsonl`), which is a content-removal tool built for a different purpose and is not repurposed as a copyright-compliance tool by this feature.
- **Extraction Sidecar**: The per-format extractor's JSON output, in the exact `{chapter_slug, source_file, sections[]}` shape `pipeline/md_sections.py` already produces — the single, format-agnostic interface every downstream pipeline stage (`ingest-transcript -docs`, `index-embed`, search, `/passage/{pid}`) consumes unmodified. Each `sections[]` entry MAY additionally carry an optional `attrs: map[string]string` field (FR-021), passed through unchanged into the minted passage's `Observation.Attrs` — the channel spec 015's Location Anchor design depends on, but not itself populated by Phase 1's EPUB extractor.
- **doc_section passage**: The existing passage kind textbook sections mint into. Carries no timespan, already serves from `/passage/{pid}`, and already indexes into FTS5/semantic search identically regardless of source — no new passage kind is introduced by this feature.
- **Registry Scope**: The citable corpus partition a textbook's sections are minted under (e.g. `textbook-<slug>`), validated by the existing generic slug allowlist rather than the stricter numeric `ChapterID` grammar, so a textbook is never mistaken for a recorded chapter.
- **Extraction Failure Report** (Phase 3): A per-run, explicit list of sections/pages/documents that produced no usable text during ingestion, reported alongside (never instead of) the count of successfully ingested sections.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: An operator can ingest a real, well-formed EPUB textbook with a recorded license basis and have 100% of its heading-delimited sections appear as searchable `doc_section` passages after a single ingestion run, using zero new backend (Go) code beyond the format-specific extraction stage.
- **SC-002**: Reading order of ingested sections matches the source EPUB's own OPF spine order in 100% of cases, verified against at least one fixture whose spine order differs from its directory/filename order.
- **SC-003**: 100% of ingestion attempts against a document with no recorded license basis are refused with zero passages minted, verified against a fixture with a missing license field.
- **SC-004**: Re-ingesting an unchanged textbook source across two consecutive runs produces zero duplicate passages (100% idempotency), and re-ingesting a source whose text changed but whose section identity did not (e.g. a typo fix) also produces zero duplicate passages.
- **SC-005**: Zero textbook-ingested registry scopes appear in the `/api/chapters` listing, while 100% of their sections remain reachable via `/passage/{pid}`.
- **SC-006**: A search query matching text unique to an ingested textbook section returns that section via both the lexical and the semantic search path, in 100% of tested cases, with no measurable search-latency regression attributable to the addition of textbook content.
- **SC-007** (Phase 2): For each of PDF (text-layer), FB2, DOCX and HTML, at least one real fixture document per format is ingested end-to-end and its sections are indistinguishable in search behavior and citation route from Phase 1's EPUB-sourced sections.
- **SC-008** (Phase 3): 100% of ingestion runs report an explicit extraction-failure list (even when empty), never a bare success count with failures silently omitted.
- **SC-009** (Phase 3): A scanned/image-only PDF is refused with an explicit reason in 100% of attempts made before an OCR toolchain is provisioned, and successfully ingested with sections visibly marked OCR-derived in 100% of attempts made after one is provisioned.

## Assumptions

- EPUB is Phase 1's sole format because it has the most mature parsing ecosystem, the clearest reading-order model (OPF spine), and is the most textbook-relevant format surveyed — and because the research's own proof-of-concept already demonstrates the extraction mechanism concretely, end to end, with real captured output.
- The per-format extraction stage (an `epub_sections.py`-equivalent script, following `pipeline/md_sections.py`'s exact contract) runs as a Python pipeline stage outside the Go backend, mirroring the role `md_sections.py` already plays for Markdown documents — not as new Go code.
- Everything at or below the existing `ingest-transcript -docs` stage (identity minting, semantic embedding, the passage registry, the FTS5 lexical index, the `/api/suggest` catalog, and the `/passage/{pid}` route) is already format-agnostic and requires no modification to serve textbook content, per the research's own file:line-cited architecture analysis.
- Image, diagram, and table content within a textbook section is not preserved at extraction fidelity beyond available alt text; this is an accepted, explicitly-named Phase 1/2 limitation rather than something this feature solves.
- Operators, not end-readers, select and curate which textbook files are ingested. There is no self-serve upload flow in this feature's scope; "untrusted input" in FR-008/edge cases refers to content an operator has sourced externally (e.g. a fetched public-domain text), not to an anonymous upload surface.
- The existing `redactions.jsonl` / disclosure-judgement suppression mechanism, built for withholding named third parties' private speech, is not reused as a copyright-compliance or takedown tool by this feature; the License Record gate (FR-005) is the sole licensing control this feature introduces.
- This feature is a sibling of, not a dependency on, the concurrent chapter-04 text-only-chapter effort (`workshop/chapters/04/rami_milos_slack_conversation.md`, referenced here by path only per this repository's content-boundary rules). Both target the same `doc_section`-based downstream mechanism; if that effort establishes conventions for a "text-only" registry scope naming pattern or a new `docSection.Kind` variant before this feature's Phase 1 implementation begins, this feature's scope-naming choice (FR-006) should follow those conventions rather than diverging, as a coordination note rather than a blocker.
- Per-format extraction-quality variance (malformed XHTML frequency, multi-column PDF prevalence, FB2 encoding variance) is currently unconfirmed against real corpus material in this project's actual scope; Phase 2/3 format work may require a small spike against real sample material before implementation commitments are finalized, per the research's own explicit `UNCONFIRMED` markers.
- The "best learning medium per student" interaction named in the research (§5.4) — once both video and textbook content exist for the same subject, whether a ranking/suggestion layer should prefer one medium per learner — is an explicitly out-of-scope product question for this feature, deferred to a joined-up design pass with that parallel research effort.
