# Contract: EPUB Textbook Ingestion Stage (Phase 1)

This pipeline has no HTTP/RPC surface for this feature — it is a batch,
operator-triggered CLI stage, the same shape as `pipeline/md_sections.py`
(and, for structural precedent, spec 009's `meeting_notes_pdf.py`). This
document is the stage's own input/output contract.

## Invocation

```text
pipeline/venv/bin/python pipeline/epub_sections.py <textbook.epub> <out.json> \
    --chapter-slug textbook-<slug> [--path <as-recorded>] --license-basis <basis>
```

Mirrors `md_sections.py`'s own CLI shape (`<doc.md> <out.json> --chapter
<slug> [--path <as-recorded>]`) with one addition: `--license-basis` is
**mandatory**, not optional (FR-005) — the tool refuses to run without it,
before reading a single byte of the EPUB.

Exit codes (same three-valued convention `md_sections.py` already uses):
`0` written · `1` nothing ingestable (includes: no license basis recorded,
DRM-protected, every spine document malformed) · `2` unreadable (the file is
not a valid ZIP, or carries no `mimetype` entry).

## Input

- One EPUB file (`.epub`), Phase 1 scope.
- `--license-basis`, an operator-supplied string recording the textbook's
  License Record (FR-005). **Required.** Its absence is a hard refusal —
  exit 1, zero bytes written to `<out.json>`, zero passages minted.
- `--chapter-slug`, a `textbook-<slug>`-shaped value (FR-006) — validated
  against the existing generic `SafeSlug` allowlist, not `ChapterIDGrammar`.

## Processing (per `document-ingestion-architecture.md` §4, and the POC it formalizes)

1. Open the EPUB as a ZIP archive; confirm the `mimetype` entry declares
   `application/epub+zip` (exit 2 if not a valid EPUB container).
2. Parse `META-INF/container.xml` to locate the OPF package document.
3. Parse the OPF with `ebooklib` (or `defusedxml.ElementTree` for any raw
   XML step not delegated to `ebooklib`) to read the `<manifest>` and,
   critically, the `<spine>` — **reading order is spine order, never
   manifest order and never directory/filename order** (FR-002, SC-002).
4. For each spine `<itemref>` whose manifest entry is an XHTML content
   document: walk its DOM in document order, splitting into sections at
   every `h1`-`h6` boundary (FR-003), applying the `MIN_CHARS = 120`
   stub-filter threshold `md_sections.py` already applies.
5. Emit each section in the Extraction Sidecar shape (see
   [`data-model.md`](../data-model.md)): `{text, path, line_start, line_end,
   kind: "doc_section"}`, with `line_start`/`line_end` as block ordinals
   within that spine document (FR-001).
6. Apply the three-tier idempotent anchor-carry-forward strategy
   `md_sections.py` already implements (inline `pid` anchor → exact text
   match → unambiguous position-range match) against any prior sidecar for
   the same textbook, so re-ingesting an updated edition does not duplicate
   passages whose identity did not change (FR-007).
7. Write the sidecar JSON to `<out.json>`.

Untrusted-input handling (FR-008, edge case list): any EPUB/OPF/XHTML that
did not originate from operator-curated, pre-vetted files is parsed with
`defusedxml`, never bare `xml.etree.ElementTree`.

DRM detection (FR-009): if the EPUB cannot be parsed because it is
DRM-wrapped (Adobe ADEPT or a Kindle proprietary scheme), the tool refuses
with an explicit reason naming DRM, never attempting or implying a
decryption step.

Partial-failure handling (FR-010): if one spine document fails to parse
(e.g. malformed XHTML) while others succeed, the well-formed documents are
still processed and the failed one is named in the output, rather than
aborting the whole run or silently dropping it.

## Output

`<out.json>` — the Extraction Sidecar (see `data-model.md`), in the exact
shape `platform/backend/cmd/ingest-transcript`'s `-docs` flag already
decodes. This file is the stage's complete output; the caller is expected to
invoke `ingest-transcript -docs <out.json>` as a separate step (this tool
mints no passages itself and calls no Go binary), exactly mirroring how
`md_sections.py` and `ingest-transcript` are two separately-invoked stages
today.

## Downstream wiring (unchanged, reused verbatim — no contract of its own needed)

```text
pipeline/venv/bin/python pipeline/epub_sections.py textbook.epub \
    curriculum/textbook-<slug>/sections.json \
    --chapter-slug textbook-<slug> --license-basis "CC-BY-4.0"

go run ./platform/backend/cmd/ingest-transcript \
    -docs curriculum/textbook-<slug>/sections.json \
    -db curriculum/passages.jsonl

go run ./platform/backend/cmd/index-embed -db curriculum/passages.jsonl
```

No new Go code, no new CLI flag on either existing binary (FR-004, FR-012;
research §1.4, §1.5).

## Invariants (MUST hold on every run)

- **License gate precedence**: the `--license-basis` check runs BEFORE any
  EPUB byte is read. An ingestion attempt with no recorded basis mints
  **zero** passages, regardless of how well-formed the EPUB is (FR-005,
  SC-003).
- **Spine order, not directory order**: reading order is determined
  exclusively by the OPF `<spine>`, verified against at least one fixture
  whose spine order differs from its directory/filename order (FR-002,
  SC-002).
- **Idempotency**: re-running against an unchanged textbook source produces
  zero duplicate passages; re-running against a source whose text changed
  but whose section identity did not (e.g. a typo fix in a later edition)
  also produces zero duplicate passages (FR-007, SC-004).
- **Non-chapter scope**: every textbook mints under a `textbook-<slug>`
  scope that `/api/chapters` — which lists only `ChapterID`-shaped scopes —
  correctly excludes (FR-006, SC-005).
- **Format-agnostic downstream, verified**: a search query matching text
  unique to an ingested textbook section is returned by both the lexical
  (FTS5) and semantic (embedding) search paths, with no source-format-
  specific code change in either path (FR-012, SC-006).
- **No silent DRM bypass**: a DRM-protected EPUB is refused with an explicit
  reason, never silently producing empty or partial output (FR-009).
- **No silent partial-failure loss**: a malformed spine document is named
  explicitly in the run's output, never silently dropped and never causing
  the whole run to abort (FR-010).

## Backward Compatibility

This is new functionality with no prior behavior to preserve. The one
compatibility invariant that matters: `md_sections.py`'s own existing
behavior (Markdown document ingestion) is **untouched** — `epub_sections.py`
is an independent, additive sibling module, not a modification to
`md_sections.py`, and every existing Markdown-sourced `doc_section` passage
is unaffected by this feature shipping.
