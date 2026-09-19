# Design: Exhaustive HelixQA Coverage — Workshop Areas & Practice

**Status**: Approved in chat 2026-09-19 (operator: "all, one by one, subagents
driven"). Sixth of 8 planned sub-projects.

## Scope of this sub-project

The research confirms this is not one feature but three genuinely distinct
contract surfaces sharing one taxonomy. This design covers all three, as
three separate case groups within one bank, per the research's own
recommendation not to flatten them:

1. **Taxonomy** — `GET /api/areas`, `GET /api/areas/{area}`.
2. **Learning path** — `GET /api/areas/{area}/lessons`,
   `GET /api/areas/{area}/assessment`, `POST .../assessment/submit`.
3. **Practice deck** — `GET /api/areas/{area}/questions`.

Out of scope: `GET /api/areas/{area}/lessons/{lesson}` (single-lesson route,
no frontend caller), `GET /api/areas/{area}/materials`,
`GET /api/areas/{area}/coverage`, `GET /api/areas/{area}/export`,
`GET /api/areas/{area}/evidence` — all real, but reached by no frontend
route and already covered by dedicated existing gates
(`verify-assessment-reach.sh`, `coverage_wire_test.go`, `export_wire_test.go`
etc. per the research's §8). Naming these explicitly as out of scope rather
than silently omitting them.

## The two highest-value targets, per the research's own ranking

1. **The list-vs-detail publication asymmetry.** `GET /api/areas` and
   `GET /api/areas/{area}` apply the same publication function but a
   measured historical gap (819 listed, 817 404 on detail) is exactly what
   `verify-area-publication-consistency.sh` now guards at the shell-gate
   level. This bank adds the HTTP-CONTRACT-level complement: a sample of
   real ids across published / held-back-no-review / held-back-stale-review
   / unknown states, confirmed live (not assumed) before writing cases.
2. **The three DISTINCT withholding mechanisms on the practice-deck route**
   (citation-resolvability, answer-key disclosure, D11/D12 leak
   suppression). These must produce three separate case groups, never one
   flattened "redaction" case — conflating them would hide which mechanism
   a future regression actually broke.

## A genuine cross-session security property named by the research

**Session-scoped choice-token isolation on assessment submit
(`unknown_choice`).** Choice ids on the assessment-submit route are
per-session shuffle tokens, not stable catalog ids — a token obtained from a
DIFFERENT session's `GET .../assessment` response must not resolve. This is
not currently named in any HTTP-level bank. Given this session's own
standing precedent (the T508 `/switch` rate-limit bypass was found via
exactly this kind of "is this cross-session isolation actually enforced at
the HTTP boundary, not just assumed" question), this case gets a genuine,
live, two-session test — obtain a real choice token under one session,
attempt to submit it under a different session, confirm 400
`unknown_choice`, not a misgrade.

## Architecture

One `helixqa http` bank file, at `submodules/qa/banks/workshop/`:

- `areas-practice.yaml`

Structured with three clearly-labeled sections in its own header/tags
(`taxonomy`, `learning-path`, `practice-deck`) matching the research's own
three-way split. `auth: admin` for authenticated cases; the cross-session
choice-token case needs two independently-addressable sessions — read the
auth-session sub-project's own investigation of this framework's
single-slot credential cache before assuming a mechanism exists; if it
doesn't, `_skip` with a precise reason exactly as that sub-project already
established the convention for, and name the underlying property as
verified-live-via-curl-in-the-implementer's-own-session instead (matching
that sub-project's own resolution for its analogous WK-AUTH-005 case).

## Data flow / cases to encode

**Taxonomy:**
1. `GET /api/areas` returns real areas with the documented `AreaCard` fields.
2. A real PUBLISHED area's detail route returns 200 with the full `Area`
   shape including `published: true`.
3. A real area the list advertises but that is HELD BACK returns 404
   `area_not_found` on detail — confirmed live which real area (if any)
   currently exhibits this, per the measured 819/817 asymmetry; if the
   current corpus no longer has any held-back area, say so precisely and
   use the closest available real case, or `_skip` with a reason.
4. Malformed area id (not a 26-char ULID) → 400 `malformed_pid`.
5. Unknown but well-formed area id → 404 `area_not_found`.
6. `?include=held_back` is the only accepted list-route filter value; any
   other value → 400 `unknown_parameter`.
7. Unauthenticated access → 401.

**Learning path:**
8. `GET /api/areas/{area}/lessons` for a real published area with lessons.
9. `GET /api/areas/{area}/assessment` for a LOCKED gate (missing required
   lessons) — 200 with `availability.available: false`,
   `missing_lessons[]` populated, `questions: null` (never an empty array).
10. `GET /api/areas/{area}/assessment` for an UNLOCKED gate (if a real area
    with completed lessons exists — confirm live, don't assume) — 200 with
    real `questions`.
11. `POST .../assessment/submit` while locked → 403, no `result` key, but
    `availability`/`completion` still present.
12. `POST .../assessment/submit` with `unknown_choice` (a token not issued
    to this session) → 400 `unknown_choice` — the cross-session isolation
    case described above.
13. `POST .../lessons/{lesson}/state` with a valid state transition, and
    confirm the SAME response's `completion`/`assessment` reflects the new
    gate answer without a second round trip.

**Practice deck:**
14. `GET /api/areas/{area}/questions` — sessionless (confirm live: does this
    route genuinely answer without `auth: admin`, per the research's
    "a practice deck needs no login" claim — verify, don't assume).
15. A withheld-by-citation-resolvability question appears in the `withheld`
    block, never in `short`/`long`, with a real `WithholdReason` value.
16. An assessment-mode question with `answer_key_disclosure: withheld_graded`
    (or `withheld_undetermined`) carries `citations: null` +
    `citations_withheld: true` (never `citations: []`) — the D11/D12
    suppression, kept distinct from case 15's mechanism.
17. A disclosed (non-withheld) question DOES carry its real citations —
    the contrasting positive case, so 15/16 aren't trivially always-true.

## Testing discipline

Every case gets a golden-bad control. Case 12 (cross-session choice-token
isolation) and case 3 (publication asymmetry) are the highest-value golden-
bad targets — for case 12, using a genuinely different session's real token
against the wrong session IS the live proof; for case 3, if a real
held-back area doesn't currently exist, the golden-bad direction (publish
an area then confirm 404→200, or the reverse) needs a real, revertible
mutation identified by reading `pipeline/extract/review_store.py` first.

## Assumptions

- The live workshop server stays rebuilt and current for the duration of
  this sub-project.
- `helixqa http` (never `run`) only.
- Wired into `verify-helixqa-web.sh` via the same directory glob.
- This is the SECOND sub-project (after progress-plan) whose cases may
  write server-side state (lesson-state POSTs, assessment submissions).
  Implementers must confirm idempotency/cleanup implications the same way
  the progress-plan sub-project's design already flags.
- The three-valued staleness mechanism (§4 of the research — Fresh/NoSource/
  Stale/StalenessUnknown) requires a server restart mid-run to exercise
  live and is explicitly OUT OF SCOPE for this bank (the research already
  flags this as PENDING_FORENSICS, needing a disposable test binary rather
  than the shared dev instance) — named here as a documented, deliberate
  gap, not a silent omission.
