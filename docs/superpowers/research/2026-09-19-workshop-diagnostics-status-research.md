# Research: Workshop Diagnostics / Status Surface (for future HelixQA brainstorming)

Read-only investigation, 2026-09-19. Input for the "Diagnostics / Status"
sub-project of the exhaustive-HelixQA-coverage effort (5th of 8 — matches the
depth of the 2026-09-18 auth/search/ask research docs in this directory). Live
facts captured against the running `workshop-curriculum_platform_1` container
at `http://127.0.0.1:8087`. All paths relative to `workshop/`.

## 1. There are TWO distinct diagnostics surfaces, not one — the prior docs'
   passing mentions conflate them

The auth/search/ask research docs each mention "`core/status.component.ts`"
and "`/api/index/status`" together, in a way that reads as one diagnostics
feature. **Independently verified: they are two separate frontend
components, wired to two different backend endpoints, and one of them does
not call the other's endpoint at all.**

| Surface | Frontend route | Component | Backend endpoint(s) it calls |
|---|---|---|---|
| **The honesty page** | `/status` | `core/status.component.ts` (`StatusComponent`), `app.routes.ts:165-167` | `GET /api/health`, plus a live probe each of `/api/chapters` (+ `/api/chapters/{slug}`, `/api/chapters/{slug}/transcript`), `/api/suggest`, `/api/search`, `/api/passages/{pid}/crossrefs` |
| **The curriculum page's index panel** | `/` (home) | `features/curriculum/curriculum.component.ts` (`CurriculumComponent`), "What is indexed" section, template lines 108-159 | `GET /api/index/status` only (`loadIndex()`, lines 430-433) |

**`StatusComponent` never calls `/api/index/status`, and `CurriculumComponent`
never calls the six-probe table.** The search-research doc's route table
lists `GET /api/index/status` → `IndexStatusHandler` as a backend fact (true),
but does not claim a frontend caller; this doc corrects any reading that
would place it on `/status`. A future HelixQA bank that wants to exercise
generation transparency (`/api/index/status`) must target the **curriculum
home page**, not the diagnostics page — and a bank exercising the six-probe
table must target `/status`.

## 2. `GET /api/health` — full handler and response shape

`platform/backend/cmd/workshop-server/main.go:2763-2781` (`healthHandler`).
Registered twice on purpose: `mux.HandleFunc("GET /api/health", ...)` at
`main.go:796` (the content mux) and `authMux.Handle("GET /api/health",
content)` at `main.go:3345` (the exemption from `wrapWithAuth` — see §5).

Response body, live-measured 2026-09-19 (`curl -i http://127.0.0.1:8087/api/health`):

```json
{
  "status": "ok",
  "http": "http://127.0.0.1:8087",
  "pid": 1,
  "chapters": 4,
  "web": true,
  "index": "/var/lib/workshop",
  "build": "fae0a71-20260919T001600Z-dirty",
  "source_commit": "fae0a71a32d3765e55f48ed866ad3fed4175c9a0",
  "source_dirty": true,
  "built_at": "2026-09-19T00:16:00Z",
  "identity_source": "ldflags",
  "ollama": {
    "url": "",
    "configured": false,
    "reachable": false,
    "detail": "no -ollama endpoint configured"
  }
}
```

The prior research docs only ever grepped `source_commit` and a chapter
count off this endpoint; the FULL shape (`healthResponse`, `main.go:2735-2748`,
embedding `buildIdentity` from `build_identity.go` and `ollamaStatus` from
`main.go:2750-2755`) is:

- `status` — always the literal `"ok"` (see the doc comment at `main.go:2757-2762`:
  this is **PROCESS LIVENESS ONLY**, not a composite health signal — nothing
  else this handler measures can flip it).
- `http` — `"http://" + r.Host`, i.e. what the server thinks its own address is,
  derived per-request from the `Host` header, not configuration.
- `pid` — `os.Getpid()`. Live value `1` because the process is PID 1 inside its
  container.
- `chapters` — `len(listChapters(cfg.chaptersDir).Chapters)`, resolved fresh
  every request (comment at `main.go:2765`: not cached).
- `web` — `webServable(cfg.webDir)`, **the same predicate `GET /` itself
  uses** (`main.go:2770-2772`, cross-referenced at `main.go:2521`), so this
  flag cannot report a UI that is not actually being served. This is the
  subject of its own paired-mutation gate (§4).
- `index` — `cfg.indexDir`, a bare path string, not a liveness check of the
  index (that is `/api/index/status`'s job, §3).
- `buildIdentity` (inlined, not nested under a key) — `build`, `source_commit`,
  `source_dirty`, `built_at`, `identity_source` (`"ldflags"` when the
  release-build linker stamps it, `"vcs-stamp"` when the Go toolchain's own
  `debug.ReadBuildInfo()` fallback fired, `"none"` when neither could produce
  anything) — see `build_identity.go:52-64`. **Dirty is measured, and the live
  container IS dirty** (`source_dirty: true` above) — a fact worth noting for
  any bank that wants to assert a clean-build precondition before trusting
  other live readings from this container.
- `ollama` — `probeOllama(cfg.ollamaURL)` (`main.go:2783-2802`): three
  distinguishable states, `configured:false` (no `-ollama` flag given, no
  network call attempted), `configured:true, reachable:false` (the `GET
  {url}/api/tags` call failed or returned non-200, `detail` carries the Go
  error string or `"status " + resp.Status`), `configured:true,
  reachable:true`. **Live today: `configured:false`** — this container has no
  `-ollama` endpoint wired at all, independent of the ask-research doc's
  separate finding that the answer *provider* is `none`.

## 3. `GET /api/index/status` — three-valued generation transparency

`internal/api/router.go:195-238` (`IndexStatusHandler`), registered
unconditionally at `router.go:64` inside `api.Register` (called from
`main.go:1100`, i.e. through the SAME `wrapWithAuth`-gated content mux as
search/passages — see §5, this route is NOT exempt).

Three states, matching the module's `0/1/2` exit-contract idiom at the HTTP
layer:

| Condition | HTTP | Body |
|---|---|---|
| `db == nil` | 503 | `{"status":"unavailable","reason":{"code":"lexical_index_unavailable","leg":"index","message":"no index database is configured","retry_after_s":null}}` |
| `index.Live` returns an error | 503 | `{"status":"unavailable","reason":{"code":"lexical_index_unavailable","leg":"index","message":"the index database could not be read","evidence":"<err>","retry_after_s":null}}` |
| `index.Live` returns `ok=false` (readable, nothing live) | 503 | `{"status":"unavailable","reason":{"code":"index_no_verified_generation","leg":"index","message":"no verified index generation is live","retry_after_s":null}}` |
| live generation found | 200 | `{"status":"ok","generation":<int>,"state":"<enum>","pid_count":<int>,"built_at":"<ts>","root_hash":"<hash>"}` (also sets `X-Workshop-Index-Generation`, per `router.go:232`) |

**The two `unavailable` reasons ARE the "genuinely down vs. not-yet-configured"
distinction the task asked about**, and they are already deliberately kept
apart (`router.go:199-229` comments: "readable, and nothing is live. A
DETERMINED negative … which is a different fact from 'could not read it'").
`lexical_index_unavailable` (label "keyword index unreadable" in
`core/vocabulary.ts:265-268`) vs. `index_no_verified_generation` (label "no
verified index yet", `vocabulary.ts:273-276`) render as different sentences to
the reader, not just different codes.

**`state`, on the `ok` branch, is its own closed five-member vocabulary**
(`INDEX_STATE`, `core/vocabulary.ts:797-806`): `building`, `verified`, `live`,
`degraded` ("live, flagged degraded" — see §6(a) below), `superseded`. This is
the finer-grained "not-yet-configured/not-implemented vs. genuinely degraded"
distinction living one level deeper than the `unavailable` reason codes — a
generation can be `ok` at the transport level while its `state` says
`degraded`.

**Live-measured 2026-09-19**: `curl http://127.0.0.1:8087/api/index/status`
(unauthenticated) → `401 {"error":"unauthorized","message":"authentication
required"}` — confirms §5's static reading directly.

Frontend consumer: `WorkshopApi.indexStatus()` (`core/api.ts:593-601`) — used
ONLY by `CurriculumComponent.loadIndex()` (§1). It renders `pid_count`,
`generation`, `root_hash` (truncated to 12 hex chars,
`curriculum.component.ts:566-571`) and `state` (through the vocabulary,
`indexStateLabel()`/`indexStateTitle()`, lines 577-590) in a "What is indexed"
figures panel, and a generic `<app-state state="unavailable" [code]="indexReason()">`
fallback (lines 147-157) for either `unavailable` reason — the panel does not
visually distinguish the two `unavailable` codes from each other, only the
`code` attribute/title text does (via the vocabulary lookup `indexReason()`
feeds).

## 4. `core/status.component.ts` — the six-probe table, and the fix behind it

This is the "platform's own honesty page" (the component's own header
comment, lines 16-31): one real request per contract endpoint, reported as
`served` / `not built` (`absent`) / `failed` (`error`) / `probing…`, with the
explicit design goal that "an empty list would claim the curriculum contains
nothing; it does not" (line 115).

Probes registered (`status.component.ts:165-172`): `chapters`
(`/api/chapters`), `chapter` (`/api/chapters/{slug}`), `transcript`
(`/api/chapters/{slug}/transcript`), `suggest` (`/api/suggest`), `search`
(`/api/search`), `crossrefs` (`/api/passages/{pid}/crossrefs`). All six reuse
`WorkshopApi`, "the SAME client the features use, so a row cannot report
'served' through a code path no feature exercises" (line 182-183).

**The historical bug the ask-research doc referenced, read in full.** Before
the 2026-09-18 fix, `envDetail()` (the helper for the three Envelope-based
probes — suggest/search/crossrefs) took only the coarse `status` string and
hardcoded `"route is not registered on this server"` for EVERY `unavailable`
outcome — so a crossrefs route genuinely erroring with 503
`index_rebuilding_no_fallback` was reported on this self-diagnostic page as
though the route did not exist at all (component doc comment,
`status.component.ts:286-296`). The LoadStatus-based probes
(chapters/chapter/transcript, via `record()`, lines 219-227) already got this
right — only `s.reason === 'endpoint_not_implemented'` renders "not
registered"; every other reason gets its real wording via
`hintOf('reason', s.reason)`. The fix (current `envDetail`,
`status.component.ts:297-307`) brings the Envelope-based probes to the same
standard: only `reason.code === 'endpoint_not_implemented'` says "not
registered"; everything else renders `${hintOf('reason', code)} (${code})`.

**Is this HelixQA-bank-testable?** Yes, and cheaply, without needing to
manufacture a genuine index outage: `envDetail` and `record()` both branch
purely on the `reason.code` string a probe's response carries, and the router
already has a real, reachable way to produce a non-`endpoint_not_implemented`
`unavailable` on the crossrefs leg — a malformed/nonexistent `pid` on
`/api/passages/{pid}/crossrefs` or a search query hitting a filter edge (see
the search-research doc §3) will do it live. A bank case does not need to
reproduce the ORIGINAL trigger (`index_rebuilding_no_fallback`, which needs a
mid-rebuild corpus); any genuinely-erroring-but-registered outcome on one of
the three Envelope routes exercises the same code path. The existing unit
test (`status.component.spec.ts`, whole file, 37 lines) covers `envDetail`
alone, at the pure-function level with hand-built `{status, reason}` objects
— it does **not** exercise the live HTTP round trip or the sibling `record()`
function, both real gaps (§7).

## 5. Authentication

**Confirmed both statically and live: `/api/health` is the only unauthenticated
`GET` under `/api/`, and the fuller diagnostics page requires auth at BOTH
layers — frontend route guard and backend bearer token.**

- **`/api/health`**: exempted from `authhttp.Middleware` by name in
  `wrapWithAuth` (`main.go:3339-3346`): `authMux.Handle("GET /api/health",
  content)`, alongside the `/api/auth/*` routes. Everything else routes
  through `apiPathsOnly(authhttp.Middleware(authDB), content)`
  (`main.go:3346`, `apiPathsOnly` at `main.go:3365-3374`) — gated ONLY for
  `/api/` prefixes, so the SPA shell (including `/status` itself as an
  Angular deep link) is served regardless. Live-confirmed: `curl -i
  http://127.0.0.1:8087/api/health` → `200`, no `Authorization` header sent.
- **`/api/index/status`**: NOT in the exemption list. Live-confirmed: `curl -i
  http://127.0.0.1:8087/api/index/status` → `401
  {"error":"unauthorized","message":"authentication required"}`. Every other
  probe `StatusComponent` makes (`/api/chapters`, `/api/suggest`,
  `/api/search`, `/api/passages/{pid}/crossrefs`) is likewise gated — same
  `authhttp.Middleware` as every other content route, no special-casing
  (matching the search/ask docs' own findings for those routes).
- **The `/status` frontend ROUTE itself is client-side-guarded.**
  `app.routes.ts:47-51`: `path: 'status'` sits inside the pathless `path: ''`
  parent carrying `canActivate: [authGuard]` (`app.routes.ts:44-51` for the
  guard wiring, `165-167` for the status route itself). An unauthenticated
  visitor is redirected to `/login?returnUrl=/status` before `StatusComponent`
  ever constructs — it never gets a chance to fire its health probe from an
  unauthenticated tab.
- **A real, currently-unhandled edge case this creates**: if a session
  **expires while `/status` is already open** (the guard only checks at
  navigation time, not continuously), `health()` still succeeds (unauthenticated
  route) but the five other probes now receive 401. Tracing this through
  `httpToLoadStatus` (`core/api.ts:831-882`): a 401 has no `reason`/`error`
  object in its body (`{"error":"unauthorized","message":"authentication
  required"}` has an `error` **string**, not an object, so `contractShaped`
  at line 872-873 is false), so it falls through to
  `parseEnvelope(401, e.error, 'results')` and, finding no envelope shape
  either, resolves to `loadUnavailable('http_401')` (line 881). `record()`
  and `envDetail()` both then render this through the generic HTTP-class
  fallback in `vocabulary.ts` (`describe()`, `~line 992-998`): **"the server
  refused the request … a fault in the asking, not a finding about the
  curriculum"** — displayed identically to any other unrecognized 4xx, with
  no wording that names session expiry specifically. This is NOT the same bug
  as §4's fixed one (that was about `endpoint_not_implemented` masking a real
  route error; this is about an auth failure being indistinguishable from any
  other unrecognized client-side fault) — it is a real, currently-untested,
  and currently-unfixed ambiguity worth a bank case or an explicit
  accepted-gap note.

## 6. Real edge cases

- **(a) `index.State == "degraded"` is unit-tested at the `pkg/index` layer,
  never at the `IndexStatusHandler` HTTP layer.** `pkg/index/degraded_test.go`
  (T331, spec 008, R5) proves `index.Live()` correctly reports `degraded` when
  a redaction is recorded against the currently-live generation after it was
  built (`TestGateR5_RedactionAfterBuildReportsDegraded`,
  `degraded_test.go:73`), and that a rebuild clears it
  (`TestGateR5_RebuiltGenerationIsNoLongerDegraded`, line 126). **No test
  exercises `GET /api/index/status` itself returning `"state":"degraded"`
  over real HTTP** — a real, currently-open gap between a well-tested Go
  function and its one HTTP caller.
- **(b) `probeOllama`'s three states (`configured:false` /
  `configured:true,reachable:false` / `configured:true,reachable:true`) have
  NO Go test at all.** `grep`-confirmed: no `TestProbeOllama`/`TestOllama*`
  exists anywhere under `platform/backend/cmd/workshop-server/*_test.go`.
  Only the FIRST of the three states is exercised, indirectly, by whatever
  the live container happens to be running (today: `configured:false`).
- **(c) `web:true` on `/api/health` has a real paired-mutation proof, and it
  is a good model for how a bank case for (a)/(b) could be structured.**
  `TestHealthWebFlagAgreesWithWhatIsServed` (`web_test.go:123-143`, G-WEB-1)
  asserts the flag agrees with what `GET /` actually serves in BOTH
  directions (bundle present / bundle absent).
  `TestPairedMutation_StartupTimeDecisionDisagreesWithHealth`
  (`web_test.go:179-...`, G-WEB-2's own proof) rebuilds the PRE-FIX behavior
  (decide once at startup rather than per request) as a literal mutant and
  asserts it visibly disagrees with the health flag — i.e. the test suite
  itself proves the regression it guards against would be caught. No
  equivalent mutation-proof exists for the `chapters` count, the `index` path
  string, or either of the two live-untested probes above.
- **(d) `chapters` count on `/api/health` is a live, un-cached count of the
  same directory `GET /api/chapters` enumerates** — the two numbers (health's
  `chapters: 4` and a `chapters()` call's array length) should always agree on
  a quiescent corpus, and a bank asserting that agreement would catch a
  divergence between the two independent code paths that produce them
  (`listChapters` is called directly by `healthHandler`, `main.go:2765`,
  versus whatever `GET /api/chapters`'s own handler does — not traced further
  in this pass).
- **(e) `/status`'s six probes each independently touch a chapter slug**
  (`chapter`/`transcript` probes use `s.data[0]?.slug` from the live
  `chapters` response, `status.component.ts:186-190`) and a hardcoded
  crossrefs test pid (`'01JBX7QK3M8V2ZC4YT5N6RWDPA'`, line 213) — **on a
  corpus with zero chapters**, the `chapter`/`transcript` sub-probes never
  fire at all (the `if (slug)` guard at line 188 short-circuits), leaving
  those two rows permanently `probing…` rather than resolving to any of the
  four defined states. Worth a dedicated case: an empty-corpus visit to
  `/status` should either resolve every row or explicitly document why two
  rows stay in a non-terminal visual state forever.
- **(f) The `unavailable.component.ts` "did not answer" panel used for
  `/api/health` itself is a DIFFERENT rendering path than the six-probe
  table's badges** (`app-unavailable` vs. inline `<span class="badge">`,
  `status.component.ts:49-52` vs. `94-109`) — a bank asserting "the page
  renders SOMETHING sensible when health itself is unreachable" needs to
  target the `app-unavailable` component's `[role=alert]` output specifically,
  not the badge table.
- **(g) `status_dirty`/build identity is genuinely live-dirty today**
  (§2) — any bank that treats `/api/health`'s `build`/`source_commit` as a
  stable fixture across a test run should account for the possibility that
  the container is serving an uncommitted build, and should not assert
  `source_dirty:false` as a live expectation without first checking.

## 7. Existing coverage — do not duplicate

**Go, `cmd/workshop-server`:**
- `build_identity_test.go` — `TestHealthCarriesBuildIdentity` (line 70):
  grades the full `build`/`source_commit`/`source_dirty`/`built_at` contract
  reaching the wire, over a real in-process `httptest.Server`, including the
  dirty-tree-must-be-marked invariant. Explicitly does NOT grade whether the
  actual shipped binary is stamped (that is `verify-build-identity.sh`'s job,
  a shell gate with its own paired proof `prove-build-identity.sh`).
- `web_test.go` — `TestHealthWebFlagAgreesWithWhatIsServed` (G-WEB-1, line
  123), `TestBundleAppearingAfterStartupIsPickedUp` (G-WEB-2, line 152),
  `TestPairedMutation_StartupTimeDecisionDisagreesWithHealth` (line 179) — see
  §6(c).
- `auth_wire_test.go` — `TestAuthedServerHealthStaysPublic` (line 34, asserts
  200 through the REAL `wrapWithAuth`-wired mux), `TestAuthedServerSPAStaysPublic`
  (line 51, `/status` itself is in the tested path list as a plain SPA deep
  link), `TestAuthedServerRefusesUnauthenticatedContent` (line 18 — notably
  does **not** include `/api/index/status` in its probed path list, only
  `/api/chapters`, `/api/areas`, `/api/search?q=x`, `/api/progress`).

**Go, `internal/api`:**
- `gates_test.go` — `TestUnknownAPIPathDoesNotFallThroughToTheSPA` (~line
  527): the comment names `/api/index/status` as one of the four routes that
  used to fall through to the SPA (200 text/html on an unimplemented path),
  but the test body's own probed-path list (`/api/nonexistent`,
  `/api/search/deep`, `/api/answer`) does NOT literally include
  `/api/index/status` — the regression is covered by the ROUTING PRINCIPLE
  being asserted generically, not by a case naming that exact path.

**Go, `pkg/index`:**
- `degraded_test.go` — the R5 `degraded` state machine at the `index.Live()`
  level (§6(a)). No HTTP-layer equivalent.

**Frontend Karma:**
- `core/status.component.spec.ts` (37 lines) — `envDetail()` only, pure
  function, hand-built inputs. No `TestBed`-rendered component test exists for
  `StatusComponent` (no test drives the six-probe `load()` flow, the
  `health()` signal, or the template's badge rendering).
- No spec file exists at all for `CurriculumComponent` (confirmed:
  `find platform/frontend/src/app/features/curriculum -iname '*.spec.ts'`
  returns nothing) — the "What is indexed" panel driving `/api/index/status`
  is entirely untested on the frontend.

**Shell gates (`platform/gates/`) — liveness consumers of `/api/health`, not
tests of `/api/health` itself:** `verify-server-unity.sh`,
`verify-platform-reachable.sh` (T146, three-valued REACHABLE/NOT
REACHABLE/UNDETERMINED precondition gate for manual QA), `verify-g-live-1-workshop.sh`
/ `verify-g-live-2-workshop.sh` (boot-and-smoke against a live container,
exercising `GET /api/health` and `POST /api/auth/login` together). None of
these assert anything about the RESPONSE BODY beyond "200 and it looks like
JSON" — they use health as an up/down precondition, not as a contract under
test. `verify-build-identity.sh` / `prove-build-identity.sh` are the one gate
pair that reads `/api/health`'s body content specifically (the build-identity
fields), with a B1 (binary, in isolation) and B2 (deployed container) arm.

**`verify-status-*.sh` and `prove-status-*.sh` in `platform/gates/` are a
false-friend name match — read them before assuming they cover this
surface.** `verify-status-exit-contract.sh` (G-CLI-17) and
`verify-status-port-identity.sh` (G-CLI-12) are about `scripts/status.sh`,
the CONTAINER LIFECYCLE CLI script (`RUNNING`/`STOPPED`/`DEGRADED`/`UNKNOWN`
exit-code contract for `podman`/`docker compose`), entirely unrelated to
either `/status` (the Angular route) or `/api/index/status` (the HTTP route).
A bank author searching gate names for "status" will find these first and
should not mistake them for coverage of this sub-project's surface.

**HelixQA banks**: no bank exists yet for either diagnostics surface.
`submodules/qa/banks/workshop/` holds only `chapter-detail-content.yaml`,
`chapter-detail-recording.yaml`, `chapter-list.yaml`,
`chapter-transcript-route.yaml`, `spa-routing.yaml` — the last of these
asserts `expect_status: 200`/`404` for a few SPA routes but does not name
`/status`, `/api/health`, or `/api/index/status` anywhere in its body.

## Files most relevant for the future brainstorm

- `platform/frontend/src/app/core/status.component.ts` (whole file, 308
  lines — read the header comment in full)
- `platform/frontend/src/app/core/status.component.spec.ts` (the fixed bug's
  regression test, and the gap: pure-function only)
- `platform/frontend/src/app/features/curriculum/curriculum.component.ts`
  lines 108-159 (template) and 430-433, 539-618 (index-status logic)
- `platform/frontend/src/app/core/api.ts` lines 536-543 (`health()`),
  593-601 (`indexStatus()`), 831-882 (`httpToLoadStatus`)
- `platform/frontend/src/app/core/load-status.ts` (the three-valued contract
  itself, `fromHttpStatus` at lines 78-84)
- `platform/frontend/src/app/core/vocabulary.ts` — `INDEX_STATE`
  (797-806), the two index-`unavailable` reason entries (265-276)
- `platform/backend/cmd/workshop-server/main.go` — `healthHandler`
  (2757-2781), `probeOllama` (2783-2802), `healthResponse`/`ollamaStatus`
  structs (2735-2755), `wrapWithAuth` (3315-3348), `apiPathsOnly`
  (3365-3374)
- `platform/backend/cmd/workshop-server/build_identity.go` (whole file)
- `platform/backend/internal/api/router.go` lines 39-129 (`Register`),
  195-238 (`IndexStatusHandler`)
- `platform/backend/pkg/index/degraded_test.go` (the R5 state machine this
  surface's `state` field exposes but does not itself test at the HTTP layer)
- `platform/backend/cmd/workshop-server/web_test.go` lines 118-210 (the
  paired-mutation model worth imitating for (a)/(b) in §6)

## Suggested focus for the brainstorming session

1. **The two surfaces are genuinely separate** (§1) — a bank plan naming
   "diagnostics/status" needs to decide up front whether it covers `/status`,
   the curriculum page's index panel, or both, and scope cases accordingly
   rather than assuming one page for both endpoints.
2. **`GET /api/index/status`'s `state:"degraded"` branch has zero HTTP-level
   coverage** (§6a) despite being fully unit-tested one layer down — the
   highest-value gap in this surface, and it has a real, already-proven
   trigger mechanism (`index.MarkDegraded`) to build a live fixture from.
3. **`probeOllama`'s three states have zero test coverage anywhere** (§6b) —
   cheap to add (it is a pure function of an HTTP response), currently
   verified only by whatever the live deployment happens to be running.
4. **The session-expires-mid-page ambiguity on `/status`** (§5) — a real,
   currently-unhandled case distinct from the already-fixed `envDetail` bug;
   decide whether "the server refused the request" is acceptable wording for
   an expired session or whether it should be distinguishable.
5. **Empty-corpus visit to `/status`** (§6e) — two of six probe rows never
   resolve past `probing…`; confirm whether that is acceptable or a bug.
6. **The `verify-status-*.sh` name collision** (§7) — flag this early in any
   bank-writing kickoff so nobody double-counts CLI-lifecycle coverage as
   diagnostics-page coverage.
7. **`/api/health`'s `chapters` count vs. `GET /api/chapters`'s row count**
   (§6d) — an easy, high-signal cross-check between two independently
   computed numbers that should never disagree on a quiescent corpus.
