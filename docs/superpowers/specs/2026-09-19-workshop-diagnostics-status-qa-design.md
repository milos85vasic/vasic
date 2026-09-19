# Design: Exhaustive HelixQA Coverage — Workshop Diagnostics / Status

**Status**: Approved in chat 2026-09-19 (operator: "all, one by one, subagents
driven"). Seventh of 8 planned sub-projects.

## Scope of this sub-project

Two genuinely separate surfaces, confirmed distinct by the research (not one
page calling both endpoints):

1. **`GET /api/health`** — process-liveness, unauthenticated, full field set.
2. **`GET /api/index/status`** — three-valued generation transparency,
   authenticated, consumed only by the curriculum home page's "What is
   indexed" panel (NOT by `/status`).

`core/status.component.ts`'s six-probe table (`/status` route) reuses
`/api/chapters`, `/api/suggest`, `/api/search`, `/api/passages/{pid}/crossrefs`
— all already covered as REAL FEATURE ROUTES by the chapter-browsing and
search sub-projects' own banks. This design does NOT re-test those routes'
contracts; it targets what is UNIQUE to the diagnostics surface itself: the
health/index-status contracts, and the two real, HTTP-observable gaps named
below.

Out of scope: `scripts/status.sh`'s CLI lifecycle contract and its
`verify-status-*.sh` gates — a confirmed false-friend name collision, unrelated
to either diagnostics surface. Named explicitly so no case in this bank is
ever mistaken for, or duplicates, that coverage.

## The two highest-value, currently-untested gaps this design targets

1. **`GET /api/index/status`'s `state: "degraded"` branch has zero HTTP-level
   coverage**, despite being fully unit-tested one layer down
   (`pkg/index/degraded_test.go`'s R5 state machine). This is the single
   highest-value target — it has a real, already-proven trigger mechanism
   (`index.MarkDegraded` / recording a redaction against the currently-live
   generation) to build a live case from, per the research's own model
   (`TestGateR5_RedactionAfterBuildReportsDegraded`).
2. **`probeOllama`'s three states have zero test coverage anywhere** — a
   pure function of an HTTP response, cheap to test at least for the state
   the live deployment actually exhibits today (`configured: false`), with
   the other two states named as a documented gap if the live Ollama
   endpoint isn't reachable/configurable within this bank's scope.

## Two real, currently-unhandled edge cases named for triage

1. **Session-expires-while-`/status`-is-open ambiguity.** A 401 from any of
   the five gated probes renders as generic "the server refused the request"
   wording, indistinguishable from any other unrecognized 4xx — not the same
   bug as the already-fixed `envDetail` masking, a genuinely different,
   currently-open gap. Task 3 must assess whether this is worth a fix
   (distinguishable wording) or an accepted, documented limitation — not
   silently ignored either way.
2. **Empty-corpus visit to `/status` leaves two of six probe rows stuck at
   `probing…` forever** (the `chapter`/`transcript` probes never fire without
   a real chapter slug to seed them). Workshop's corpus currently has 4 real
   chapters, so this can't be reproduced against the live shared instance
   without removing them (unacceptable) — name this as an OUT-OF-SCOPE,
   documented gap for this bank (no safe way to construct the triggering
   condition against shared, real content), not a case to force.

## Architecture

One `helixqa http` bank file, at `submodules/qa/banks/workshop/`:

- `diagnostics-status.yaml`

`auth: admin` for the authenticated cases; `/api/health` cases run
unauthenticated by design (it's the one exempt route).

## Data flow / cases to encode

**`/api/health`:**
1. Unauthenticated `GET /api/health` → 200 with the full documented field
   set (`status`, `http`, `pid`, `chapters`, `web`, `index`, `build`,
   `source_commit`, `source_dirty`, `built_at`, `identity_source`, `ollama`
   sub-object) — assert field PRESENCE and type, not brittle exact values
   for fields like `pid`/`built_at` that change across restarts.
2. `chapters` count on `/api/health` agrees with `GET /api/chapters`'s real
   row count (cross-check between two independently-computed numbers that
   should never disagree on a quiescent corpus — read both live, assert
   equality).
3. `web: true` agrees with `GET /` actually serving the bundle (the
   research's §6c model, `TestHealthWebFlagAgreesWithWhatIsServed`,
   ported to an HTTP-level assertion: `GET /` returns real HTML when
   `web: true`).
4. `ollama.configured` reflects the live, real state (today: `false`) —
   assert whatever the CURRENT live state actually is, confirmed live
   first, not assumed from this document.

**`/api/index/status`:**
5. Authenticated `GET /api/index/status` returns either the `ok` shape
   (`generation`, `state`, `pid_count`, `built_at`, `root_hash`, plus the
   `X-Workshop-Index-Generation` header) or a determined `unavailable`
   reason — confirm live which one the current corpus produces, don't
   assume `ok`.
6. If the live state is `ok`, `state` is one of the 5 real enum values
   (`building`/`verified`/`live`/`degraded`/`superseded`) — assert
   membership in the closed vocabulary, not a specific value.
7. Unauthenticated `GET /api/index/status` → 401 (distinct from
   `/api/health`'s exemption — the contrast case).
8. **The `degraded` state, live-triggered**: read `pkg/index/degraded_test.go`'s
   real mechanism (recording a redaction against the currently-live
   generation) and construct the HTTP-level equivalent — a case that
   confirms `GET /api/index/status` genuinely reports `state: "degraded"`
   after a real redaction is recorded, not merely that the Go function
   does. This is the highest-value case in this bank; if no safe, real,
   revertible way to trigger this against the shared live corpus exists,
   say so precisely with the specific blocker (not "too hard") and treat it
   as Task 3 triage material rather than silently dropping it.
9. The two `unavailable` reason codes (`lexical_index_unavailable` vs
   `index_no_verified_generation`) are distinguishable — if the live corpus
   can only produce one of them today, document which and treat the other
   as `_skip`'d with a precise reason (cannot safely construct the
   triggering condition against shared real state) rather than forced.

**Cross-cutting:**
10. `probeOllama`'s live state (today `configured: false`) is asserted
    directly via case 4; the other two states (`configured: true,
    reachable: false/true`) are named as an explicit, documented gap in the
    bank's own header — NOT tested, because doing so would require
    configuring a real or fake Ollama endpoint on the shared live
    deployment, an environment change outside this bank's scope.

## Testing discipline

Every case gets a golden-bad control where safely possible. Case 8
(degraded state) is the highest-value golden-bad target if achievable
safely; cases 2/3 (cross-checks between independently-computed values) are
naturally strong regression pins even without an explicit mutation, since
they'd catch either code path silently drifting from the other.

## Assumptions

- The live workshop server stays rebuilt and current for the duration of
  this sub-project.
- `helixqa http` (never `run`) only.
- Wired into `verify-helixqa-web.sh` via the same directory glob.
- This bank does NOT re-test `/api/chapters`, `/api/suggest`, `/api/search`,
  or `/api/passages/{pid}/crossrefs` themselves (already covered by other
  sub-projects' banks) — it tests only what `/status`'s probe TABLE and
  `/api/health`/`/api/index/status` uniquely contribute.
