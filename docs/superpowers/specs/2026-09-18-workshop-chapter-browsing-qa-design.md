# Design: Exhaustive HelixQA Coverage — Workshop Chapter Browsing & Content

**Status**: Approved in chat 2026-09-18. First of 8 planned sub-projects
covering exhaustive HelixQA test-bank coverage of the `workshop` application's
full surface (per the operator's standing instruction: "Write exhaustive fully
deterministic Helix QA test suites (banks) which will cover everything in
workshop and validate and verify all flows, all screens, all components,
every single use and edge case").

## Scope of this sub-project

The **Chapter Browsing & Content** surface only:

- `GET /chapters` (list) — `chapter-list.component.ts`
- `GET /chapters/:slug` (detail) — `chapter-detail.component.ts`, composing
  the recording/watch section, the transcript/read section, and the four
  knowledge sub-components (`next-meeting`, `open-questions`,
  `meeting-notes`, `todo`)
- `GET /chapters/:slug/transcript` (dedicated transcript route)

Across all 4 real, currently-committed chapters: `01`, `02`, `02.01`, `02.02`.

Out of scope for this sub-project (each is one of the other 7 sub-projects,
brainstormed separately later): auth/session mechanics themselves (reused
here only as a prerequisite, not tested here), search, ask/Q&A, progress/plan,
areas/practice, diagnostics/status.

## Why these 4 chapters are a real edge-case matrix, not a synthetic one

Confirmed live against the rebuilt server (`source_commit` matches HEAD
`9a319209eeaee4476321e27761f70998e874185e`) immediately before this design was
written:

| Chapter | Notes-PDF source (feature 009) | Transcript | Meeting-notes state |
|---|---|---|---|
| 01 | Yes (authoritative) | Yes (pre-existing, now bypassed per FR-002) | Populated, PDF-sourced |
| 02 | Yes (authoritative) | Yes (pre-existing, now bypassed) | Populated, PDF-sourced |
| 02.01 | No | Yes | Populated, transcript-sourced (unchanged by feature 009) |
| 02.02 | No | Yes (freshly ASR-transcribed today) | Populated, transcript-sourced (new today) |

No chapter currently has a real "unwritten" state for meeting-notes (all four
were populated by earlier work this session), so that state needs a
**synthetic fixture chapter** in the bank rather than a real one — the one
deliberate gap in "use real data everywhere," stated here rather than
discovered silently later.

## Architecture

One `helixqa http` bank file per concern, at
`submodules/qa/banks/workshop/`:

- `chapter-list.yaml`
- `chapter-detail-recording.yaml`
- `chapter-detail-content.yaml`
- `chapter-transcript-route.yaml`

Every bank uses the structured `http:` action type exclusively (never a prose
`action:` string — the vacuous/bluff-gate trap this session already found and
fixed twice today). Authenticated cases reuse the proven `auth:` credential-
slot mechanism from `rbac.yaml` (`--login-path`, `--admin-user`/
`--admin-pass` carrying real workshop credentials at invocation time only,
never written into a bank file).

## Data flow

Each case targets a specific real chapter slug and asserts against that
chapter's actual, current, live-verified state (the table above) — a
regression pin, not a guess. The one synthetic-state case (meeting-notes
"unwritten") is clearly labeled as synthetic in its own bank comment, with
the real mechanism it exercises (a temporary fixture chapter directory,
cleaned up after) documented inline.

## Error handling / edge cases to encode

From reading `chapter-detail.component.ts` directly:

- No-recording state (`data-testid="no-recording"`)
- `transcript.present === false` vs `true`, plus the `uncertain_count`
  low-confidence-passage display when present
- A nonexistent chapter slug (expect a genuine 404, not a masked 200/500)
- Each of the four knowledge sub-sections' `state` value, per chapter,
  matching the real current state (some `authored`, one synthetic
  `unwritten` fixture)
- Unauthenticated access to any of the four routes (expect 401, not a
  silent empty-content 200 — mirrors the RBAC bank's own "a denial must be
  a genuine, unambiguous status" discipline)

## Testing discipline

Every case gets a golden-bad control: revert or otherwise invert the real
code path the case pins (matching `spa-routing.yaml`'s and `rbac.yaml`'s
established pattern this session), confirm the bank genuinely FAILs, restore,
confirm PASS again. Anything HelixQA finds that is not already a known,
already-fixed behavior is a fresh bug: full `systematic-debugging` root-cause
investigation, a TDD fix, and live re-verification against the rebuilt,
restarted server — no exceptions, per the operator's explicit "no bluff of
any kind" instruction.

## Assumptions

- The live workshop server stays rebuilt and current (`source_commit` ==
  `HEAD`) for the duration of this sub-project's live-verification work;
  re-confirm before any live run if time has passed.
- `submodules/qa`'s `helixqa http` subcommand (not `run`) is the only
  execution path used, per the vacuous-bank-bluff finding from earlier today
  — any new gate wiring this sub-project produces must include the
  case-count-accounting fix from that finding, not the pre-fix pattern.
- The synthetic "unwritten" fixture chapter is created and torn down by the
  bank's own test harness (or a documented manual setup step), never left as
  permanent test pollution in the real `chapters/`/`curriculum/` trees.
