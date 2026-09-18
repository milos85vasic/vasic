# Data Model: PDF-Sourced Meeting Notes with Redaction Gate

Derived from [spec.md](spec.md)'s Key Entities section. No new persistent
storage is introduced — every entity below is a shape appended to an
existing JSONL registry via the existing `minting.sync_areas` bridge, or a
new field on an existing shape.

## Notes PDF (discovery-time concept, not a minted entity)

A chapter-scoped file, discovered by filename pattern
`* - Notes by *.[Pp][Dd][Ff]` beside that chapter's recording. Not stored as
its own record; identified at discovery time by its path, and referenced by
path from every citation anchor below.

| Field | Type | Notes |
|---|---|---|
| `chapter_id` | string | e.g. `"01"`, matches the existing chapter-scope convention used elsewhere in this pipeline. |
| `path` | string | Relative path within `chapters/<chapter_id>/`. |
| `extracted_at` | ISO 8601 timestamp | When `pdftotext` last ran against it — recorded for the extraction-failure edge case's diagnostics, not for any business logic. |

A chapter may have zero, one, or many notes PDFs (FR-001a) — each is
discovered and processed independently.

## PDF-Section Citation Anchor (new)

Fills the role `transcript_segment` passages fill for transcript-sourced
items, per FR-004. This is a new passage kind minted into the SAME
`curriculum/passages.jsonl` registry the rest of this pipeline already uses —
not a new file, not a new registry.

| Field | Type | Notes |
|---|---|---|
| `kind` | string constant | `"pdf_notes_section"` — new kind, sibling to the existing `transcript_segment` kind. |
| `pid` | string | Minted the same way every other passage's `pid` is minted (existing `minting` bridge), so downstream code that already knows how to resolve a `pid` (e.g. `publication_policy`'s `resolve_pid`) needs no special-casing. |
| `source_path` | string | The notes-PDF's path (see above). |
| `section_index` | integer | 0-based position of the extracted section within that PDF (mirrors `ordinal`'s role for the existing entity kinds — stable, not re-derived from text). |
| `content_hash` | string (`sha256:...`) | Same convention as every other passage's `content_hash` field, computed over the section's extracted text. |

## kg_meeting_note / kg_todo / kg_open_question / kg_next_point (existing, unchanged shape)

No field is added or removed from these four existing entity kinds. What
changes is only which **kind of citation** they may point to:

- Today: every citation is a `transcript_segment` `pid`.
- After this feature: a citation MAY instead be a `pdf_notes_section` `pid`
  (mutually exclusive per item — an item is sourced from exactly one place,
  per FR-002's "MUST NOT extract... from the transcript" rule).

`external_key`'s existing format (`f"{short_kind}:{chapter_scope}:{citation_pid}:{ordinal}"`,
per `meeting_notes.py`'s own documented convention) is unchanged and works
identically for either citation kind, since it already keys on `citation_pid`
generically rather than assuming a `transcript_segment`.

## Redaction Check Result (transient, not persisted as its own record)

The output of applying `is_publishable_content` / `check_content` (existing)
plus the new PII-pattern check (FR-011, PDF-sourced items only) to an item's
final rendered text, immediately before minting. Not a new stored shape —
its only two persisted effects are:

1. **Withheld**: the item is minted with this pipeline's EXISTING withheld-item
   state convention (the same one other withheld content already uses — no
   new state value is introduced), and becomes eligible for the EXISTING
   `disclosure-judgements.jsonl` ruling mechanism, unchanged (FR-010).
2. **Publishable**: the item is minted normally, exactly as it would be
   without this check.

| Field (transient, in-memory only) | Type | Notes |
|---|---|---|
| `text` | string | The item's own final rendered text — never the source document's full text (per FR-008 / "Source Is Not Served"). |
| `roster_match` | bool | From the existing `is_publishable_content`. |
| `pii_pattern_match` | bool \| null | From the new FR-011 check; `null` for transcript-sourced items (the check does not apply there). |
| `withheld` | bool | `roster_match OR pii_pattern_match` (never a "roster match alone" special case — either signal withholds). |

## State Transitions

A chapter's meeting-notes state (the existing `state: "unwritten"` /
`state: "extracted"` / etc. convention already reported by this pipeline)
gains one new value:

- `"extraction_failed"` (FR-009): a notes PDF was discovered for this chapter
  but `pdftotext` could not extract usable text from it. Terminal for that
  PDF for that run — never silently downgrades to `"unwritten"` (which would
  misrepresent "an operator provided notes we couldn't read" as "no notes
  exist") and never silently upgrades to using the transcript instead (which
  would misrepresent "we used the wrong source" as "we used the requested
  source").

No existing state value's meaning changes.
