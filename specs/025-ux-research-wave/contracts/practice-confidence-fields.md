# Contract: Practice Confidence Fields (offered to spec 013)

**Implements**: FR-007, FR-008 | **Client files**: `core/confidence-store.ts`, `features/practice/confidence-prompt.component.ts` (new)
**Server adoption**: spec 013 attempt record (`specs/013-adaptive-assessment-scoring`, FR-001/002/016) - NOT built by this spec.

## Fields

| Field | Type | Values | Notes |
|---|---|---|---|
| `confidence` | enum | `low`, `medium`, `high` | chosen BEFORE reveal; required (decision D2 default) |
| `self_explanation` | string | 0..500 chars | optional; plain text; never rendered as HTML |
| `committed_at` | RFC 3339 | | client clock; server will re-stamp |

Derived client-side after reveal (not stored as fields): `calibration` in
{`high_confidence_wrong`, `low_confidence_correct`, `aligned`}.

## Behavioural contract

1. Reveal (explanation, correct-answer marking) is unreachable until `confidence` is set
   (the `Reveal` button / auto-reveal is disabled with a visible reason sentence).
2. Empty `self_explanation` is allowed.
3. Wording for `high_confidence_wrong` is neutral: no danger colour tokens, polite announcement, same
   motion as a correct reveal (spec 014 FR-003/005/016 convention).
4. Until server adoption, data lives in an in-memory service for the session only; the UI never says
   it is "tracked" or "saved to your profile".

## Proposed server shape (for 013's `contracts/`, informational)

`POST` of an attempt gains optional `confidence` and `self_explanation`; the stored attempt row gains
two nullable columns; scoring (013 Elo-style) MAY use `confidence` as a calibration signal but this
spec states no scoring rule.

## Collision note

The practice submit path is also touched by spec 016-US1 and 013-US1 (architecture §2.2 rule 5). This
spec touches only `features/practice/` presentation and hooks one tag into `practice.component.ts`;
it does not change the submit call.
