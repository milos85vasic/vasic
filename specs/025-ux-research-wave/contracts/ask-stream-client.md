# Contract: Ask Stream Client (frontend side of `GET /api/ask?stream=1`)

**Implements**: FR-001..FR-006 | **New files**: `workshop/platform/frontend/src/app/core/{sse-parser,ask-stages,ask-stream}.ts`
**Server side (already implemented, not changed here)**: `workshop/platform/backend/pkg/answer/http.go`
(`ask` at the `stream=1` branch ~L281; `stream` L360; `streamJob` L370-525), event type
`pkg/answer/provider.go:120-137`, phases `pkg/answer/outcome.go:101-105`.

## Transport

* Start: `GET /api/ask?q=<question>[&chapter=<slug>]&stream=1[&tokens=1]` (stream from the start) -
  or `POST /api/ask` (returns 202 + `stream` path) then `GET /api/ask/{job_id}/stream`.
* The browser `EventSource` is NOT used: it cannot send `Authorization: Bearer`. The client uses
  `fetch()` with the same token the HTTP interceptor attaches (`core/auth-interceptor.ts`), reads
  `response.body.getReader()`, decodes UTF-8 incrementally (`TextDecoder` with `stream:true`), and
  honours `AbortController`.
* Non-stream failures arrive as ordinary JSON: HTTP 503 with `{status:'unavailable', reason:{...}}`
  is a REAL outcome (answering off, `no_provider`) and is routed to the existing `normaliseAnswer`
  path, exactly as `core/api.ts:561-576` does; 401 follows the global expiry path.

## SSE frame grammar (as emitted, `http.go:487-490`)

```
event: <kind>\n
data: <one-line JSON>\n
\n
```
`<kind>` is one of `phase`, `progress`, `token`, `result`, `withheld`. The parser MUST follow the
WHATWG SSE parsing rules: lines end with LF, CRLF or CR; a blank line dispatches; `:` starts a comment
(ignored; heartbeats are `progress` events, not comments); `data:` lines concatenate with LF; unknown
fields ignored; a trailing partial frame at EOF is discarded, never dispatched.

## Event payloads (`json` of `answer.Event`)

| field | type | notes |
|---|---|---|
| `kind` | `phase`\|`progress`\|`token`\|`result` | `withheld` has its own body `{status:'withheld',reason:'suppression_filter_unchecked'}` |
| `phase` | `queued`\|`retrieving`\|`generating`\|`verifying`\|`done` | closed set |
| `elapsed_s` | number | server-measured; the ONLY time source for stage times |
| `tokens`, `tokens_per_second` | number? | progress counters; no text |
| `delta` | string? | only with `tokens=1`; always unverified |
| `verified` | bool | `false` on every `token`; `true` only on the terminal result |
| `note` | string? | server's honest latency expectation; shown verbatim as the stage note |
| `outcome` | `Outcome`? | terminal `result` only; normalised by the existing `normaliseAnswer` |

## Reducer rules (`ask-stages.ts`, pure, no I/O)

1. State = ordered list of `StageRecord{phase, started_at_s, ended_at_s?, note?}` + `status`
   (`connecting`|`streaming`|`done`|`dropped`|`failed`) + optional `draft`.
2. A `phase` event for a phase different from the current one closes the current stage at the event's
   `elapsed_s` and opens the new one. A repeated phase event only refreshes `note`.
3. A phase that has not been reported is NEVER inserted (no inferred, skipped or decorative stages).
4. `progress` updates counters and `note` of the current stage; it never creates a stage.
5. `token` appends to `draft` only if the opt-in is set; `draft.verified` is always `false`.
6. `result` closes the open stage, sets `status=done`, DROPS `draft`, and carries the outcome.
7. `withheld` sets `status=failed` with reason `withheld`, DROPS `draft`, shows the withheld state.
8. Reader end / network error before `result`: `status=dropped`; the client performs ONE reconnect to
   `/api/ask/{job_id}/stream` (job id taken from the first frame set or the 202 body) - the server
   replays buffered events (`http.go:505-510`); a second drop yields `failed` with a retry control.
9. Unknown `kind`: ignored and counted (test asserts it does not crash and does not create stages).

## Accessibility contract

One `aria-live="polite"` region (visually hidden text allowed) whose text changes only on a stage
transition and on `done|failed|dropped`; stage elapsed times are visible text; collapse/expand is a
real `<button aria-expanded>`; the answer body and the draft are not live regions.

## Fallback

If `fetch` streaming is unavailable (`response.body` null) or the first request fails before any
frame, the component falls back to the existing synchronous path `WorkshopApi.ask()` (`wait=1`) and
shows no stage list (honestly: just the existing elapsed counter).

## Test oracles

* WHATWG SSE parsing examples (written in the HTML Standard §9.2) for the parser.
* Recorded real streams captured from a scratch server (task T003) for the reducer: the expected stage
  list is derived by hand from the raw frames by the test author, not by running the reducer.
* A deliberately wrong reducer (phantom stage injected) as the paired mutation.
