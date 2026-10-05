# Contract: Content-Type Classification

**Implements**: FR-009, FR-010, FR-013 | **Touches**: `workshop/platform/backend/internal/passagestore/domain.go`,
`workshop/platform/backend/pkg/search/semantic.go`

## Extension to `KnownKinds` / `ValidateRecord`

**CORRECTED 2026-10-05, post-`/speckit-clarify`**: this section originally described
`content_type` as derived from `kind` via a fixed 1:1 mapping. That design is **wrong** and
directly contradicts the resolved clarification on `spec.md` FR-009 ("content-type MUST be
determined by the ingesting pipeline/script at the moment it writes each passage... MUST NEVER
be inferred... from the passage's existing `kind`"): a fixed 1:1 mapping IS inference from
`kind`, and it cannot distinguish "meeting notes" from "authored lesson" — FR-009's own two
separate categories — since both are stored under the same existing `doc_section` kind today.
The corrected design below replaces the fixed mapping with an explicit-stamp-plus-allowed-set
validation, matching the clarification exactly.

```text
KnownKinds (existing 10, UNCHANGED membership) + textbook_section (NEW, 11th kind)

content_type: new cross-cutting field, REQUIRED on every passage write, one of
  {transcript, meeting_notes, authored_lesson, textbook, code, diagram, screen_text, knowledge_graph}

  (expanded from the collapsed {transcript, document, code, diagram, screen_text, textbook,
  knowledge_graph} this contract originally listed — "document" is not one of FR-009's minimum
  closed-set categories; "meeting notes" and "authored lesson" are, and they need distinct values)

kind -> ALLOWED content_type set (a VALIDATION constraint the caller's explicit value must
belong to — NEVER a derivation the system computes FROM kind):
  transcript_segment      -> {transcript}                        # singleton: no ambiguity exists
  doc_section               -> {meeting_notes, authored_lesson}    # NOT a singleton — this is
  │                                                                  exactly the ambiguity FR-009's
  │                                                                  clarification exists to resolve;
  │                                                                  the caller MUST supply which one
  code                       -> {code}                              # singleton
  diagram                    -> {diagram}                           # singleton
  screen_text                 -> {screen_text}                      # singleton
  textbook_section (NEW)       -> {textbook}                        # singleton — ALL textbook
  │                                                                   ingestion routes through this
  │                                                                   new kind exclusively, so
  │                                                                   doc_section's allowed set
  │                                                                   never needs to include textbook
  kg_area, kg_term,
  kg_lesson_section,
  kg_question, kg_mention      -> {knowledge_graph} each            # singleton per kind
```

`ValidateRecord` MUST reject a record whose explicitly-supplied `content_type` is **absent**
(every passage write MUST carry one — no default, no silent omission) or is **not a member of**
its `kind`'s allowed set above. For a singleton-set kind this validation looks like a derivation
check, but the record still carries its own explicit value — `ValidateRecord` is verifying
caller-supplied data against a constraint, never computing a value the caller omitted. This is
the one uniform rule for every kind, singleton or not; there is no special-cased "auto-derive for
simple kinds, require explicit value only for `doc_section`" branch.

### `internal/passagestore/domain.go` signature change (Foundational, reviewed)

`DocumentObservation(chapterSlug, text, kind, ref)` currently has **no parameter** for this
(confirmed: its signature at `domain.go:538-548` carries no `Attrs` or similar field). This
feature extends it to `DocumentObservation(chapterSlug, text, kind, contentType, ref)` — a
**reviewed, breaking change** to a load-bearing internal API every ingestion pipeline (existing
and new) calls, hence this project's Review Gate on "Content-type classification data model
changes... review before migration." Every EXISTING caller of `DocumentObservation` (the
meeting-notes pipeline, the authored-lesson pipeline) MUST be updated in the SAME change to pass
its own correct, explicit `content_type` — leaving an existing caller passing none, or passing a
default, is not a partial migration this feature accepts; `ValidateRecord`'s new
absent-content_type rejection makes a missed caller a build-breaking/test-breaking failure, not a
silent gap, by construction.

## `Semantic.WithPopulation` generalization

**Before (existing, single-purpose)**: `WithPopulation(kinds map[string]bool)` — caller passes an
explicit kind allowlist/denylist at the `kind` granularity.

**After (this feature)**: the semantic search path gains a `content_type`-granularity scoping
option, implemented as sugar over the existing `WithPopulation` (expanding a `content_type` into
the set of passages carrying it — a runtime lookup against each passage's own stored
`content_type` value, never a kind-based inference, per the correction above) — **not** a
parallel, independent filtering mechanism. This preserves the existing floor-domain-containment
fix (`research.md`/`data-model.md` reference it) as the special case "exclude `content_type =
knowledge_graph` by default for non-knowledge-graph queries," expressed in the new vocabulary
rather than reimplemented.

## Chunking dispatch (FR-010)

Content-type determines which chunker implementation processes a document at ingestion time:

```text
content_type = textbook         -> hierarchical parent-child chunker (research.md §2, NEW)
content_type = transcript       -> existing chunker (unchanged)
content_type = meeting_notes    -> existing chunker (unchanged)
content_type = authored_lesson  -> existing chunker (unchanged)
content_type = code             -> existing chunker / Lumen's own chunking (unchanged, out of scope)
```

(Corrected from the earlier `content_type = document` row, which does not exist in the corrected
enum above — `meeting_notes` and `authored_lesson` each get their own row, even though both
currently dispatch to the same existing chunker; a future change to chunk ONE of them
differently no longer requires inventing a classification that doesn't exist yet, which is the
whole point of FR-010 treating them as distinct from the start.)

This dispatch is a plain switch in the ingestion pipeline's chunker-selection step, not a new
abstraction layer — the existing `Chunker` interface already supports swapping implementations;
this feature adds one new implementation and one new dispatch case, nothing structural.

## Uniform retrieval contract (FR-013)

A query against the hybrid retriever (`pkg/hybrid.HybridRetriever`) MUST return results spanning
every `content_type` the corpus currently holds, unless the caller explicitly scopes via the
generalized `WithPopulation`/content-type option above — i.e. content-type-awareness is additive
(an opt-in narrowing), never a default exclusion of any content type. This is what makes the
dimension "extensible to future content additions" (FR-013's own wording): a new content type
added later needs only a new `KnownKinds` entry and a mapping-table row, not a change to the
retrieval path itself.
