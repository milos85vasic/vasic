# HTTP API Contract — Workshop Curriculum Platform

**Feature**: `specs/001-workshop-curriculum-platform` | **Phase**: 1 (Design & Contracts) | **Date**: 2026-09-01

**Governs**: the backend HTTP surface consumed by the Angular client.
**Derived from**: [spec.md](../spec.md) (FR/SC), [plan.md](../plan.md) (five corrected premises),
[research.md](../research.md) (D-SEARCH-\*, D-LLM-\*), [data-model.md](../data-model.md).
**Companion contracts**: [passage-contract.md](./passage-contract.md) (what a `pid` is),
[pipeline-cli.md](./pipeline-cli.md) (how the data this API serves is produced).

This document specifies **interfaces and behavioural guarantees**. It contains no handler bodies,
no business logic and no migrations. Where a guarantee cannot be offered because something is
unverified, it is marked and the settling measurement is named (§8) rather than assumed away.

---

## 1. Conventions

### 1.1 Base, transport, scope

| Property | Value | Basis |
|---|---|---|
| Base path | `/api` | FR-013 — matches `ai_interviewing/platform/backend/internal/api/api.go:36` |
| Bind address | loopback by default | D1 (local/internal only) |
| Authentication | **none** | D1 — single machine, single user; no accounts are in the data model |
| Request encoding | `application/json` for bodies; query string for reads | |
| Response encoding | `application/json; charset=utf-8`, except recording/material bytes | |
| Versioning | none in the path. The contract is versioned with the repository. Breaking changes bump `X-Workshop-Api-Contract`. | |

There is **no** rate limiting, quota, or tenancy. Adding any would imply a multi-user deployment,
which D1 excludes.

### 1.2 Response headers required on every `/api` response

| Header | Meaning |
|---|---|
| `X-Workshop-Api-Contract` | Contract revision this build implements (e.g. `1`). |
| `Cache-Control` | `no-store` on every three-state endpoint (§2). Only recording and material bytes are cacheable. |

Additionally, on every endpoint that reads the index or the passage registry:

| Header | Meaning |
|---|---|
| `X-Workshop-Index-Generation` | Integer generation the response was served from (data-model `Index.generation`). Lets the client detect an atomic swap mid-session and re-fetch. |
| `X-Workshop-Search-Status` | Mirrors the body's `status` verbatim. **Convenience mirror only.** It MUST equal `body.status`; a gate asserts agreement (§2.7). |

`X-Workshop-Search-Status` exists so that a proxy, a log line or a curl `-I` can distinguish the
three states without parsing a body. It is never the authority — the body is.

### 1.3 Why `Cache-Control: no-store` is mandatory on the three-state endpoints

A cached `200 ok` outliving an index swap or a backend failure would let an intermediary serve a
successful-looking response while the backend is unavailable. That is precisely the FR-020
violation this contract exists to make impossible, so caching is removed rather than tuned.

### 1.4 Path parameters

| Parameter | Form | Notes |
|---|---|---|
| `{chapter}` | chapter `slug` (data-model `Chapter.slug`) | Immutable once published. The zero-padded `ordinal` is **not** accepted as a path key — one key, one meaning. |
| `{pid}` | canonical uppercase ULID, 26 chars | See [passage-contract.md §2](./passage-contract.md). Lowercase input is accepted and canonicalised; responses always carry uppercase. |
| `{job_id}` | opaque string | Answer job handle. Not a ULID; carries no meaning. |

### 1.5 Malformed-request errors (`4xx`) are a fourth thing, not a fourth state

A `4xx` says *the request was wrong*. It is outside the three-state contract of §2, which describes
outcomes of well-formed requests. The client must not render a `4xx` through any of the three
result branches.

```jsonc
// 4xx body — the only shape a 4xx ever has
{
  "error": {
    "code": "empty_query",              // closed enum, see §5.2
    "message": "q is required and must be non-empty after trimming",
    "field": "q"                        // optional
  }
}
```

---

## 2. The three-state contract (FR-019, FR-020, FR-033, SC-013, D-SEARCH-4)

**This is the load-bearing section of this document.** Everything else is plumbing.

### 2.1 The requirement, restated exactly

There are **three** distinguishable outcomes, never two:

| State | Meaning | Constitution analogue |
|---|---|---|
| `ok` | The question was answered and there is something to show. | exit `0` |
| `no_match` | The question was answered and the answer is *nothing matches*. | exit `1` — checked, negative |
| `unavailable` | **The question could not be answered.** | exit `2` — COULD NOT DETERMINE |

The `.specify/memory/constitution.md` **Honest Instruments** principle is binding here: collapsing
state 2 into state 0 makes a broken system certify content nobody searched; collapsing it into
state 1 makes a broken backend assert that the curriculum contains nothing. Both are release
blockers.

### 2.2 The anti-pattern this repository already ships

`ai_interviewing/platform/frontend/src/app/features/search.component.ts` is the concrete failure
the contract is designed against. Measured, at the lines quoted:

```ts
// line 19 — the only negative branch in the template
@else if (q().length >= 2 && !hits().length) { <p class="muted">No results for "{{ q() }}".</p> }

// line 58 — the error branch sets no error state at all
).subscribe({ next: h => { this.hits.set(h || []); this.loading.set(false); },
              error: () => this.loading.set(false) });
```

A backend failure clears `loading`, leaves `hits` empty, and the template renders **"No results
for …"**. The component has two states where three are required. Its backend compounds this by
returning `[]` for queries shorter than two characters. This defect exists independently of this
feature and must not be inherited.

### 2.3 Why liveness cannot gate the third state

Measured in one MCP session, seconds apart (research.md D-SEARCH-4):

```
== health_check   2 ms ==            == semantic_search 20013 ms ==
Status: OK                            embed query: all embedding servers exhausted after
Message: service is healthy           failover: … context deadline exceeded  [isError=True]
```

`health_check` reported healthy **2 ms before** the search path failed hard. It is a liveness
probe, not a saturation probe.

**Normative**: the `status` field MUST be derived from the outcome of the search call actually
performed for this request. It MUST NOT be derived, in whole or in part, from `/api/health`, from
Lumen's `health_check`, from a cached liveness flag, or from any probe that did not execute this
query. `/api/health` (§3.1) exists for process supervision only and carries an explicit
non-guarantee in its own response.

### 2.4 Why upstream text is quarantined

Lumen returns, as **one unstructured string** (research.md D-SEARCH-4):

```
"No results found. | Warning: Index is being updated in the background.
 Results may be incomplete or outdated. Us…"
```

A client that reads the first line, or renders the blob, displays "No results found." while the
index is provably incomplete.

**Normative**:

- The backend MUST parse upstream result text for degradation markers, and MUST promote a match to
  `degraded.semantic = "reindexing"`.
- Upstream free text MUST NEVER appear in `results[]`, in `suggestions[]`, or in any field the
  client renders as primary copy.
- Upstream text may appear **only** in `reason.evidence` or `degraded.evidence`, both of which are
  declared **diagnostic-only** fields. The client contract forbids rendering them outside a
  diagnostics disclosure.

### 2.5 The response envelope

Returned by `/api/search`, `/api/suggest`, and `/api/passages/{pid}/crossrefs`, with the payload
array named per endpoint.

```jsonc
{
  "status": "ok",                  // "ok" | "no_match" | "unavailable" — exhaustive, closed
  "query": "how do we cut chunks at silence",
  "generation": 7,                 // index generation; null iff status=="unavailable"
  "floor_calibrated": false,       // §8 U5 — see 2.6 rule I7
  "legs": {                        // per-leg outcome; keys present iff the leg was enabled
    "lexical":  "ok",              // "ok" | "failed" | "skipped"
    "semantic": "failed"
  },
  "results": [ /* Hit — §3.7 */ ], // PRESENT AND NON-EMPTY IFF status=="ok". ABSENT otherwise.
  "near_misses": [ /* Hit */ ],    // present only when status=="no_match"; see I6
  "degraded": {                    // present only alongside status=="ok". Never with the others.
    "semantic": "reindexing",      // closed enum, §5.3
    "message": "Meaning-based search is unavailable right now — showing keyword matches only.",
    "evidence": "No results found. | Warning: Index is being updated…"   // DIAGNOSTIC ONLY
  },
  "reason": null,                  // present IFF status=="unavailable"; shape in §2.6
  "took_ms": 41
}
```

`unavailable` bodies additionally carry:

```jsonc
{
  "status": "unavailable",
  "reason": {
    "code": "embedding_backend_exhausted",   // closed enum, §5.3
    "leg": "semantic",                       // "lexical" | "semantic" | "index" | "registry"
    "message": "Search cannot answer right now: the embedding backend is saturated.",
    "retry_after_s": 30,                     // nullable — null means UNKNOWN, never 0
    "evidence": "all embedding servers exhausted after failover: … context deadline exceeded"
  }
}
```

### 2.6 Invariants — these are what make the anti-pattern physically impossible

| # | Invariant | Consequence for a naive client |
|---|---|---|
| **I1** | `results` is present **iff** `status == "ok"`, and when present it is **non-empty**. It is never `[]`. | `hits.length === 0` can no longer mean "no results" — on any non-`ok` outcome there is no array to measure. |
| **I2** | `status == "unavailable"` **iff** HTTP `503`. Never `200`. | A client that only branches on HTTP status still cannot render "nothing found" for a backend failure. |
| **I3** | `status == "no_match"` ⇒ HTTP `200`. `status == "ok"` ⇒ HTTP `200`. | Determined negatives are successes, so `no_match` stays measurable (it is a real result, not an error). |
| **I4** | `reason` is present **iff** `status == "unavailable"`, and its `code` is from the closed enum in §5.3. | No free-form failure strings reach the UI. |
| **I5** | **`no_match` requires every *enabled* leg to have returned successfully.** If any leg failed **and** the surviving legs produced zero results, the outcome is `unavailable` with `reason.code = "partial_failure_zero_results"`. | The single most-missed case: a degraded search may report `ok`; it may **never** report `no_match`. "The leg that ran found nothing" is not "nothing matches". |
| **I6** | `near_misses` may only appear with `no_match`, every entry carries `"above_floor": false`, and the client contract requires them to be rendered in a visually distinct, explicitly labelled region. | FR-019 — below-threshold items are shown as context, never as answers. |
| **I7** | When `floor_calibrated == false`, a `no_match` MUST be rendered with the calibration caveat, because an uncalibrated relevance floor cannot support the claim "nothing matches". | §8 U5. Honest until measured. |
| **I8** | `degraded` may accompany `ok` only. It is never present with `no_match` (excluded by I5) nor with `unavailable` (which is total, not partial). | One banner, one meaning. |
| **I9** | The envelope is constructed in exactly **one** function in the search service. No handler assembles it field-by-field. | Makes I1–I8 enforceable at a single point rather than per-endpoint. |

### 2.7 Gates and their paired mutations (FR-032, SC-012)

Every guarantee above is a claim, so each carries a gate and a mutation proving the gate fails when
the guarantee is broken. Constitution §1.1: *a gate that has never been observed failing is not
known to work.*

| Gate | Assertion (executes the behaviour, does not grep for it) | Paired mutation that MUST turn it red |
|---|---|---|
| G-HTTP-1 | Point the embedding endpoint at a closed port; `GET /api/search?q=x` returns **503** with `status:"unavailable"` and a `reason.code`. | Make the handler return `200 {"results":[]}` on backend error. Gate must FAIL. |
| G-HTTP-2 | Same failure; assert the response body has **no** `results` key at all. | Add `"results": []` to the unavailable branch. Gate must FAIL. |
| G-HTTP-3 | Fail the semantic leg, let lexical return zero rows; assert `status == "unavailable"`, `reason.code == "partial_failure_zero_results"`. | Change the rule to emit `no_match` when any leg succeeded. Gate must FAIL. (This is invariant I5, the one most likely to be "simplified" later.) |
| G-HTTP-4 | Feed the search service Lumen's literal `"No results found. \| Warning: Index is being updated…"` string; assert `status=="ok"` with `degraded.semantic=="reindexing"` when lexical has rows, and that the raw string appears **only** under `degraded.evidence`. | Forward the upstream string into `results[0].snippet`. Gate must FAIL. |
| G-HTTP-5 | With ollama stopped: `GET /api/search` returns **200** with real lexical results **and** `POST /api/answer` returns **503** `state:"unavailable"`. | Wire `/api/search` through the answering provider's health check. Gate must FAIL. (FR-025; mirrors research llm-bridging §3 item 5.) |
| G-HTTP-6 | For 100 randomised outcomes, assert `X-Workshop-Search-Status` header equals `body.status`. | Hardcode the header to `ok`. Gate must FAIL. |
| G-HTTP-7 | Frontend: render each of the three envelopes; assert the no-results copy does **not** appear for the `unavailable` envelope and the unavailable copy does **not** appear for `no_match`. | Restore the `ai_interviewing` error handler (`error: () => loading.set(false)`). Gate must FAIL. |
| G-HTTP-8 | Packet/socket assertion: during 200 `/api/suggest` calls, zero requests reach the embedding endpoint. | Add an embedding call to the suggest path. Gate must FAIL. (§3.6, SC-005.) |

Evidence for every gate is written to the versioned evidence location per FR-040 — see
[pipeline-cli.md §2.5](./pipeline-cli.md).

---

## 3. Endpoint catalogue

Legend: **Traces** names the requirement each endpoint exists to satisfy. An endpoint with no
trace would be unrequested capability and is not in this contract.

### 3.1 `GET /api/health` — process liveness only

**Traces**: none (operational). Present because `ai_interviewing` has it (FR-013) and the control
plane's `status.sh` needs it ([pipeline-cli.md §4.8](./pipeline-cli.md)).

**Response 200**

```jsonc
{
  "ok": true,
  "version": "…",
  "contract": 1,
  "index_generation": 7,
  "not_a_search_availability_signal": true
}
```

The last field is not decoration. It is the contract's explicit non-guarantee, carried in-band so
that a reader of a captured response cannot mistake this endpoint's meaning:

> **This endpoint reports that the HTTP process is up. It says nothing about whether search can
> answer.** Using it to gate search availability reproduces the measured `health_check` failure in
> §2.3. Search availability is only ever the `status` field of a search response.

`/api/health` never returns 503 for a degraded backend; if the process can answer, it answers 200.

---

### 3.2 `GET /api/chapters` — list chapters

**Traces**: FR-008, FR-013, SC-004 (the first screen a new user reaches).

**Request**: no parameters. (Scale is "one chapter, growing to tens" — spec Assumptions — so no
pagination is specified. Adding pagination would be unrequested capability.)

**Response 200**

```jsonc
{
  "chapters": [
    {
      "slug": "01-ai-workflows",
      "ordinal": 1,
      "title": "Milos teaching … AI workflows",
      "summary": "…",
      "status": "published",            // "draft" | "transcribed" | "published"
      "recording": {
        "available": true,              // false ⇒ parts present but not reassembled
        "duration_s": 6928.75,          // measured, from the Recording entity
        "size_bytes": 1871981557
      },
      "transcript": {
        "present": true,
        "passage_count": 1421,
        "uncertain_count": 37,          // FR-003 — visible before opening the chapter
        "coverage_complete": true,      // SC-001 arithmetic identity, computed at ingest
        "accuracy": { "measured": false, "wer": null }   // FR-004 / SC-002; null until measured
      },
      "material_count": 1
    }
  ],
  "generation": 7
}
```

`accuracy.wer` is `null`, never a placeholder number, until
[`verify-accuracy.sh`](./pipeline-cli.md) has run. `measured: false` with `wer: null` is the
"unable to verify" state (FR-033) expressed in data.

**Errors**: `503` `{"status":"unavailable","reason":{"code":"registry_unreadable"}}` if the passage
registry cannot be opened. Never an empty `chapters` array for a storage fault — that is I1 applied
to browsing.

---

### 3.3 `GET /api/chapters/{chapter}` — one chapter with its materials

**Traces**: FR-008, FR-009, FR-011.

**Response 200**

```jsonc
{
  "slug": "01-ai-workflows",
  "ordinal": 1,
  "title": "…",
  "summary": "…",
  "status": "published",
  "sections": [                          // FR-011 — navigable, never one undifferentiated block
    { "id": "s-03", "title": "Cutting chunks at silence", "first_pid": "01JBX…", "t_start_s": 512.4 }
  ],
  "materials": [
    {
      "id": "notes-gemini",
      "kind": "pdf",                     // "pdf" | "markdown" | "image" | "diagram" | "code"
      "title": "Notes by Gemini",
      "bytes": 421888,
      "href": "/api/chapters/01-ai-workflows/materials/notes-gemini",
      "authority": "secondary"           // D-TRANS-5 — the recording is authoritative
    }
  ],
  "recording": { "href": "/api/chapters/01-ai-workflows/recording",
                 "probe": "/api/chapters/01-ai-workflows/recording/probe" },
  "transcript": { "href": "/api/chapters/01-ai-workflows/transcript" },
  "accuracy":   { "href": "/api/chapters/01-ai-workflows/accuracy" }
}
```

`authority: "secondary"` is contractual, not cosmetic: the notes PDF is a ~26-words-per-minute
summary that demonstrably errs ("Spatkit" for SpecKit). The client must present it as supporting
material, never as the record of what was said (spec edge case: *"The notes PDF and the transcript
disagree — the recording is the authority"*).

**Errors**: `404` `chapter_not_found` (determined negative); `503` `registry_unreadable`.

---

### 3.4 `GET /api/chapters/{chapter}/transcript` — passages, timestamps, provenance, uncertainty

**Traces**: FR-001, FR-002, FR-003, FR-005, FR-011, FR-038, SC-001, SC-003.

**Request**

| Parameter | Type | Default | Notes |
|---|---|---|---|
| `from_pid` | ULID | — | Window start; omit for the beginning. |
| `limit` | int | `500` | Max `2000`. A 1,400-passage chapter is servable whole; the window exists so a client need not hold it all. |
| `section` | string | — | Restrict to one `sections[].id`. |
| `include_redacted_markers` | bool | `true` | Redacted passages appear as markers, never as content (FR-039). |

**Response 200**

```jsonc
{
  "chapter_slug": "01-ai-workflows",
  "engine": "faster-whisper/large-v3-turbo",       // Transcript.engine
  "engine_params": { "beam_size": 5, "condition_on_previous_text": false,
                     "normaliser_sha256": "sha256:…" },   // frozen before first measurement
  "duration_s": 6928.75,
  "coverage": {                                     // SC-001 as an arithmetic identity, D-TRANS-4
    "complete": true,
    "speech_span_s": 6887.42,
    "accounted_silence_s": 41.33,
    "unexplained_gap_s": 0.0,                       // MUST be exactly 0 for a published chapter
    "gaps": []                                      // each gap: {start_s, end_s, reason}
  },
  "passages": [
    {
      "pid": "01JBX7QK3M8V2ZC4YT5N6RWDPA",
      "kind": "transcript",
      "text": "we always cut inside a measured silence, never mid-word",
      "t_start_s": 512.4,
      "t_end_s": 519.1,
      "speaker": "Milos",                // null when not human-attributed — never machine-guessed
      "speaker_source": "human",         // "human" | "unattributed" — D-TRANS-2, dual-mono audio
      "provenance": "human_corrected",   // "machine" | "human_corrected"  (FR-038)
      "confidence": -0.31,               // avg_logprob-derived; null for non-transcript kinds
      "uncertain": false,                // FR-003
      "uncertain_reason": null,          // "low_confidence" | "inaudible" | "overlapping_speech"
                                         //  | "language_uncertain"  — null iff uncertain==false
      "redacted": false,
      "content_hash": "sha256:…",        // CHANGE DETECTION ONLY — never identity. See passage-contract §6.
      "machine_text": "we always cut inside a measured silence never mid word"
                                         // present iff provenance=="human_corrected"; the
                                         // immutable recogniser output, retained as evidence
    },
    {
      "pid": "01JBX7QK55T0N9E1XJ2H3KFMQR",
      "kind": "transcript",
      "text": null,                      // redacted passages carry no text, at any layer
      "t_start_s": 1204.0, "t_end_s": 1211.6,
      "redacted": true,
      "redaction": { "reason_code": "third_party_pii", "at": "2026-09-01T10:02:11Z" }
    }
  ],
  "next_from_pid": "01JBX7QK9…"          // null at the end of the chapter
}
```

**Contractual points**

- `speaker` is `null` unless a human attributed it. The recording's "stereo" is **dual-mono**
  (L−R = −90.3 dB) and uniformly AGC-compressed, so channel- and loudness-based separation are
  measurably impossible (D-TRANS-2). FR-005 explicitly permits stating inability; the API states it
  through `speaker_source: "unattributed"` rather than by guessing.
- `uncertain` is set from the engine's own confidence signal, never inferred downstream. A passage
  with `uncertain: true` MUST carry a non-null `uncertain_reason`.
- `machine_text` is served alongside corrected text so a reader can see both layers. Deleting it
  would destroy the ability to re-measure accuracy later (SC-002); the API therefore exposes it
  rather than only the current text.
- `coverage.unexplained_gap_s > 0` on a chapter with `status: "published"` is a contract violation;
  the publish step refuses it ([pipeline-cli.md §4.7](./pipeline-cli.md)).

**Errors**: `404` `chapter_not_found`; `404` `transcript_not_produced` (determined: the chapter
exists and has no transcript — distinct from the chapter not existing); `503`
`registry_unreadable`.

---

### 3.5 Recording: serve and seek a **local file** (D1, D3)

There is no streaming service here. The 1.8 GB file is reassembled locally from 36 × 50 MB parts,
checksum-verified, and byte-served. **No transcoding, no HLS/DASH, no adaptive bitrate ladder, no
CDN** — D3 excludes all of it.

#### 3.5.1 `GET /api/chapters/{chapter}/recording/probe`

**Traces**: FR-007, FR-009, SC-003.

```jsonc
{
  "available": true,
  "duration_s": 6928.75,
  "size_bytes": 1871981557,
  "sha256": "…",
  "verified_at": "2026-09-01T09:12:44Z",
  "container": "mp4", "video": "h264 1920x1080 24fps", "audio": "aac-lc 48000 stereo(dual-mono)",
  "etag": "\"sha256-1f4c9ab0e7d2…-1871981557\""
}
```

When not available, `probe` returns **503**, not 200-with-`available:false`, for the same reason
searches do (§2.6 I2):

```jsonc
{
  "status": "unavailable",
  "reason": {
    "code": "recording_not_reassembled",
    "message": "The recording has not been reassembled from its 36 archive parts.",
    "remedy": "bash workshop/scripts/extract-videos.sh",
    "parts_present": 36, "parts_expected": 36
  }
}
```

#### 3.5.2 `GET|HEAD /api/chapters/{chapter}/recording`

**Traces**: FR-009, FR-007, SC-003, D3.

**Range support (mandatory)**

| Aspect | Contract |
|---|---|
| `Accept-Ranges: bytes` | Sent on `GET` and `HEAD`, always. |
| Accepted forms | `bytes=N-`, `bytes=N-M`, `bytes=-N` (suffix). |
| Multi-range | **Not supported.** `bytes=0-99,200-299` ⇒ `416` with `error.code = "multi_range_unsupported"`. Returning the full entity instead (also RFC-permitted) would push 1.8 GB down a link that asked for 200 bytes, so the contract refuses explicitly. |
| Success | `206 Partial Content` with `Content-Range: bytes a-b/total` and `Content-Length` = part length. |
| Unsatisfiable | `416 Range Not Satisfiable` with `Content-Range: bytes */<total>`. |
| No `Range` header | `200` with the full entity and `Content-Length`. Never chunked-with-206. |
| `If-Range` | Honoured against the strong `ETag`: match ⇒ `206`; mismatch ⇒ `200` full entity. |
| `ETag` | Strong, content-addressed: `"sha256-<first 16 hex of the verified digest>-<size>"`. Stable across a re-extraction on another machine, because it is derived from the manifest digest, not from inode metadata. |
| Concurrency | Bounded by `WORKSHOP_RECORDING_MAX_READERS` (derived from host CPU count, overridable). Exceeded ⇒ `503` `too_many_readers` with `Retry-After`. |

**Integrity (FR-007) without hashing 1.8 GB per request**

The extraction step writes a sidecar recording the verified `sha256` together with the `size` and
`mtime` of the file it verified. On each request the server compares the current file's `size` and
`mtime` against the sidecar:

| Condition | Response |
|---|---|
| Sidecar matches the file | Serve. |
| Sidecar absent | `503` `recording_integrity_unverified` — bytes are never served unverified. |
| Sidecar present, `size`/`mtime` differ | `503` `recording_integrity_stale`, remedy: re-run extraction. |
| Extraction recorded a digest mismatch | `503` `recording_integrity_mismatch` — "fail loudly" (FR-007). |

All four are **state 2**, not 404 and not a partial serve. The distinction matters: `404` on this
route means *this chapter has no recording at all* (a determined negative); "the file has not been
reassembled yet" is *could not determine*, and a fresh clone is in exactly that state.

**Seeking (SC-003)**

The client seeks by setting `currentTime` on the media element from a passage's `t_start_s`; the
browser then issues its own `Range` requests using the MP4's internal index. The API's only
obligation is honest range support.

**Normative non-capability**: the server MUST NOT expose a "seek to N seconds" endpoint. Mapping a
timestamp to a byte offset requires an index the container already holds and the browser already
uses; re-deriving it server-side would be invented capability with a new failure mode and no
requirement behind it.

**Caching**: `Cache-Control: private, max-age=31536000, immutable` plus the strong `ETag`. This is
the one route where caching is correct, because the entity is content-addressed and immutable
(FR-006 — source material is never modified).

#### 3.5.3 `GET /api/chapters/{chapter}/materials/{material_id}`

**Traces**: FR-009, FR-016. Byte-serves a supporting material with its declared `Content-Type`.
Same `ETag`/range rules as §3.5.2 (the 412 KB notes PDF does not need them, but one rule is fewer
rules). `404` when the material id is unknown; `503` when the file is listed in the chapter
manifest but missing on disk — again, absent-but-expected is state 2.

---

### 3.6 `GET /api/suggest` — lexical type-ahead. **Never embeds.**

**Traces**: FR-015, FR-042, SC-005.

**The measured constraint that shapes this endpoint** (D-SEARCH-2): a semantic query embedding was
measured at **18.2–21.0 s** under load, plus ~2,202 ms fixed indexer setup per CLI process. The
FTS5 prefix index over 58,726 real symbols builds in 0.93 s / 15.9 MB and answers at
**p50 0.25 ms, p95 9.58 ms, p99 19.2 ms** — measured under load average ~9 while a full re-index
was running. SC-005's 200 ms budget is unreachable semantically and comfortable lexically.

**Normative**:

> `/api/suggest` MUST NOT call the embedding backend, MUST NOT call Lumen, and MUST NOT fall back
> to a semantic path under any condition, including when the lexical index is unavailable. Its
> `legs` object is always exactly `{"lexical": …}`. Gate G-HTTP-8 asserts zero embedding requests
> during suggest traffic.

**Request**

| Parameter | Type | Default | Rules |
|---|---|---|---|
| `q` | string | required | Trimmed. Empty ⇒ `400 empty_query`. **A single character MUST be executed, not short-circuited** — the `ai_interviewing` backend's "return `[]` below 2 chars" behaviour is a defect and is forbidden here. Longer than 1024 bytes ⇒ `400 query_too_long` (a type-ahead query that long is a client bug). |
| `limit` | int | `10` | Max `25`. |
| `chapter` | string | — | Optional scope. |

**Response 200** (envelope of §2.5, payload `suggestions`)

```jsonc
{
  "status": "ok",
  "q": "spec",
  "legs": { "lexical": "ok" },
  "suggestions": [
    { "id": "sg-1",                        // stable within this response — needed for aria-activedescendant (FR-042)
      "text": "SpecKit",
      "kind": "symbol",                    // "symbol"|"heading"|"chapter"|"speaker"|"term"
      "target": { "pid": "01JBX…", "chapter_slug": "01-ai-workflows", "t_start_s": 512.4 },
      "score": 12.4 }
  ],
  "total": 1,                              // for the screen-reader announcement (FR-041/042)
  "took_ms": 3
}
```

**Suggestions are navigational targets, not search results** (D-SEARCH-2). Selecting one navigates
to a `pid`; it does not run a semantic query.

**Server-side budget**: `suggest_budget_ms` (default 50, derived/overridable). If the budget
elapses with zero rows retrieved, the response is `503` `suggest_timeout` — **not** an empty
dropdown. If rows were retrieved, a truncated list is a legitimate `ok`.

**Unavailable causes**: `lexical_index_unavailable` (FTS5 database missing, locked or corrupt),
`index_no_verified_generation`, `suggest_timeout`.

**Accessibility obligations this endpoint carries** (the rest is a frontend contract):
stable per-response `id`s so `aria-activedescendant` can reference them; a `total` count so the
live region can announce "N suggestions"; deterministic ordering so keyboard traversal is
reproducible.

---

### 3.7 `GET /api/search` — on submit

**Traces**: FR-014, FR-016, FR-017, FR-019, FR-020, SC-006, SC-007, SC-008.

**Request**

| Parameter | Type | Default | Rules |
|---|---|---|---|
| `q` | string | required | Trimmed. Empty ⇒ `400 empty_query`. A multi-paragraph query is legitimate; over 8192 bytes ⇒ `413 query_too_long` (spec edge case: empty, one-character and multi-paragraph queries must all behave predictably). |
| `limit` | int | `20` | Max `100`. |
| `kinds` | csv | all | Subset of `transcript,doc_section,code,diagram`. |
| `chapter` | string | — | Scope to one chapter. |
| `mode` | enum | `fused` | `fused` \| `lexical` \| `semantic`. `lexical` is the honest escape hatch when the operator knows the embedding backend is saturated. |
| `timeout_ms` | int | `5000` | Clamped to `[500, 15000]`. This is the bounded timeout D-SEARCH-4 requires; exceeding it ⇒ `unavailable{embedding_timeout}`, never an unbounded wait. |

**`Hit` shape**

```jsonc
{
  "pid": "01JBX7QK3M8V2ZC4YT5N6RWDPA",
  "kind": "transcript",
  "chapter_slug": "01-ai-workflows",
  "title": "Cutting chunks at silence",
  "snippet": "…never mid-word…",          // built from OUR store; never upstream free text (§2.4)
  "highlights": [[12, 21]],               // byte offsets into snippet; empty for semantic-only hits
  "t_start_s": 512.4, "t_end_s": 519.1,   // transcript kinds only; null otherwise
  "source_ref": { "path": "chapters/01/transcript/transcript.md",
                  "line_start": 812, "line_end": 815, "symbol": null },
  "score": 0.71,
  "above_floor": true,
  "leg": "fused",                         // "lexical" | "semantic" | "fused"
  "provenance": "human_corrected",
  "uncertain": false,
  "href": "/api/passages/01JBX7QK3M8V2ZC4YT5N6RWDPA?context=2",
  "deep_link": "/chapters/01-ai-workflows/transcript#p-01JBX7QK3M8V2ZC4YT5N6RWDPA"
}
```

**Boundary that must not be implied away** (D-SEARCH-3, FR-031): `kind` has **no** `audio` or
`video` value, by design. Lumen's extension allowlist is a compile-time `var` with no override —
25 code and doc extensions, and **no** image, audio, video, PDF, HTML or SVG. Measured: zero
indexed files for `.sh .html .css .txt .svg .mmd .puml .vtt .srt .pdf`, against 55 tracked `.sh`,
146 `.html` and 32 `.css` in the root module. That is exclusion, not absence. Audio and video are
searchable **through their transcripts and captions**; diagrams through their descriptions. FR-016
is satisfied by reduction to text, and the API states the boundary rather than pretending to a
capability it does not have. The response carries it in-band:

```jsonc
"corpus": {
  "indexed_kinds": ["transcript", "doc_section", "code", "diagram"],
  "media_reached_via": "transcripts and captions only"
}
```

**SC-006 note**: 2 s p95 is achievable only with a long-lived index child process (avoiding the
measured 2.2 s per-process warm-up) **and** embedding capacity reserved from indexing. During a
chapter ingest without reservation, 9–50 s was measured. The `unavailable` state exists for exactly
that window, and `reason.retry_after_s` carries the operator's expectation when known.

---

### 3.8 `GET /api/passages/{pid}` — result → exact passage with context

**Traces**: FR-017, FR-037, FR-038, FR-039, SC-003, SC-016.

**Request**: `context` (int, default `2`, max `10`) — passages either side.

**Response 200**

```jsonc
{
  "passage": { /* the passage object of §3.4 */ },
  "context_before": [ /* up to `context` passages */ ],
  "context_after":  [ /* … */ ],
  "chapter": { "slug": "01-ai-workflows", "title": "…" },
  "recording_seek": { "href": "/api/chapters/01-ai-workflows/recording", "t_start_s": 512.4 },
  "generation": 7
}
```

**Resolution outcomes — four, and each maps to a distinct HTTP status**

| Registry outcome | HTTP | Body `status` | Meaning |
|---|---|---|---|
| `found` | `200` | — | The passage exists and is servable. |
| `redacted` | **`410 Gone`** | `"redacted"` | The pid is real; its content is suppressed (FR-039). A citation to a redacted passage must land on an explicit redaction notice — never on a 404, which reads as a broken link, and never on the content. |
| `not_in_registry` | `404` | `"not_found"` | Determined negative: the registry is readable and this pid is not in it. |
| `undetermined` | `503` | `"unavailable"` | The registry could not be read, or no verified generation is live. |
| malformed pid | `400` | — | `error.code = "malformed_pid"`. Not a ULID. |

**Normative**: resolution NEVER falls back to fuzzy text matching or nearest-neighbour lookup. An
unknown pid is not "probably this one". Full rules in
[passage-contract.md §7](./passage-contract.md).

---

### 3.9 `GET /api/passages/{pid}/crossrefs` — cross-references

**Traces**: FR-018, SC-016, spec edge case *"cross-references must not create loops that trap a reader"*.

**Request**

| Parameter | Type | Default | Max |
|---|---|---|---|
| `relation` | csv of `explains,demonstrates,continues,related` | all | — |
| `origin` | `derived` \| `authored` \| both | both | — |
| `depth` | int | `1` | `3` |
| `limit` | int | `20` | `100` |

**Response 200** (envelope of §2.5, payload `crossrefs`)

```jsonc
{
  "status": "ok",
  "from_pid": "01JBX7QK3M8V2ZC4YT5N6RWDPA",
  "generation": 7,
  "crossrefs": [
    { "to_pid": "01JBX7QM…", "relation": "explains", "origin": "derived", "score": 0.62,
      "depth": 1, "preview": { "kind": "doc_section", "title": "…", "snippet": "…" },
      "href": "/api/passages/01JBX7QM…" }
  ],
  "truncated_by": null,          // null | "cycle" | "limit" | "depth"
  "redacted_omitted": 1,         // count only — never the pids, never the content
  "took_ms": 6
}
```

**Cycle safety (normative)**: traversal maintains a visited set; no returned path revisits a pid;
`from_pid` never appears in `crossrefs`; self-references are rejected at write time. When traversal
stopped because a cycle was detected, `truncated_by: "cycle"` says so rather than silently
returning a shorter list.

**Redaction**: redacted endpoints are excluded from results, and the *count* is reported. Reporting
the count is honest (the reader learns something was suppressed) without leaking what.

**Three states apply**: `ok` (≥1 edge), `no_match` (registry read fine, zero neighbours),
`unavailable` (registry/index unreadable, or the `derived` edges belong to a generation that is not
live).

---

### 3.10 `POST /api/answer` and `GET /api/answer/{job_id}` — ask a question, **asynchronously**

**Traces**: FR-021, FR-022, FR-023, FR-024, FR-025, SC-009, SC-010.

#### The measurements this contract is built on

- **There is no generative model installed at all.** ollama serves exactly two models and they are
  the *same* embedding model (`jina-bert-v2`, 160.28M, an encoder with no LM head); the whole model
  store is 309 MB across 7 blobs — too small to hold a decoder (plan.md premise 5).
- **"Instant" is off by two orders of magnitude.** Three identical two-word embed calls, model
  resident, minutes apart: **20.16 s / 11.05 s / 0.10 s** at load 8.25. Estimated CPU-only
  generation (**UNVERIFIED**, §8): ~21 s (1.5B) / ~42 s (3B) / ~95 s (7B) idle, ×1.4 with
  verification (D-LLM-5).
- Therefore answering is **asynchronous by contract**, and the `extractive` adapter — which answers
  in ~0.3 s, is genuinely grounded and **cannot fabricate** — is the default *working* path.

#### `POST /api/answer`

**Request**

```jsonc
{ "question": "why do we cut chunks inside silence?",
  "chapter": "01-ai-workflows",     // optional scope
  "top_k": 8 }                      // optional, clamped to the configured maximum
```

**Response 202 Accepted** — a job was created:

```jsonc
{
  "job_id": "ans_01JBX7R2…",
  "poll": "/api/answer/ans_01JBX7R2…",
  "poll_after_ms": 0,                 // 0 for the extractive adapter; ≥2000 for generative
  "estimated_seconds": null,          // NULL while unmeasured — see §8. Never a guessed number.
  "provider": { "name": "extractive", "locality": "local", "model": null }
}
```

**Response 503** — answering cannot run. Returned **immediately**; no job is created:

```jsonc
{
  "status": "unavailable",
  "reason": {
    "code": "no_provider",            // §5.3: no_provider | provider_unreachable
                                      //       | model_not_generative | provider_disabled
    "message": "Answering is not configured. Search and browsing are unaffected.",
    "retry_after_s": null
  }
}
```

`model_not_generative` is a named code because this environment invites exactly that bug: model
resolution on this machine lands on an embedding model, and the ollama adapter **must fail
construction** with *"model X is an embedding model, not a generative model"* rather than posting
`/api/chat` and rendering the nonsense that comes back.

**Default state**: `enabled: false`, `provider: none`. A fresh clone therefore returns `503` here
and `200` from `/api/search` — which is FR-025's acceptance criterion, satisfied out of the box
rather than by a runtime check.

#### `GET /api/answer/{job_id}`

Exactly four terminal-or-pending shapes:

```jsonc
// 200 — still running
{ "status": "pending", "phase": "retrieving",   // "retrieving"|"generating"|"verifying"
  "elapsed_s": 12.4, "poll_after_ms": 2000 }

// 200 — answered. Every citation verified against the LIVE generation's pid set.
{ "status": "answered",
  "text": "Chunks are cut inside measured silence so no word straddles a boundary…",
  "citations": [
    { "pid": "01JBX7QK3M8V2ZC4YT5N6RWDPA", "quote": "never mid-word",
      "chapter_slug": "01-ai-workflows", "t_start_s": 512.4,
      "href": "/api/passages/01JBX7QK3M8V2ZC4YT5N6RWDPA" }
  ],
  "retrieval": { "top_score": 0.74, "margin": 0.19, "min_score": 0.55, "min_margin": 0.08 },
  "provider": { "name": "ollama", "model": "…", "locality": "local" },
  "generation": 7, "elapsed_s": 38.2 }

// 200 — declined. A CORRECT RESULT, not an error.
{ "status": "declined",
  "reason": "margin_too_small",     // below_threshold | margin_too_small | unsupported
                                    // | no_citations | redacted_evidence
  "message": "The indexed content does not support an answer to this question.",
  "closest": [ /* Hit[] — what was retrieved, shown as context, never as an answer */ ],
  "retrieval": { "top_score": 0.61, "margin": 0.02, "min_score": 0.55, "min_margin": 0.08 } }

// 503 — could not determine
{ "status": "unavailable",
  "reason": { "code": "provider_unreachable", "message": "…", "retry_after_s": 30 } }
```

**Normative points**

| # | Rule | Basis |
|---|---|---|
| A1 | `declined` returns **200**. Conflating a decline with a failure would make SC-010 unmeasurable — you cannot count refusals if refusals look like outages. | FR-022, SC-010 |
| A2 | `answered` with zero citations is **structurally impossible**: the generation schema carries `"minItems": 1`, so an uncited claim is undecodable, and the API rejects any answer object failing it. | FR-021, SC-009, D-LLM-2 L2 |
| A3 | Every citation pid MUST be a member of the **live** generation's pid set — a deterministic set check, and the reason SC-009 is reachable at all. A citation outside the set ⇒ the whole answer is `declined{no_citations}`. Claims are never silently stripped. | SC-009, D-LLM-2 L3 |
| A4 | If a cited passage is redacted between generation and delivery, the answer becomes `declined{redacted_evidence}`. Redaction propagates to stored answers, not only to the rendered transcript. | FR-039 |
| A5 | `retrieval` is returned **even on success**, so a 0.002-margin pass is visible as *fragile* rather than indistinguishable from a confident one. | data-model `Answer.retrieval` |
| A6 | `min_score`/`min_margin` shipping at `0.0` means *uncalibrated*, and an uncalibrated threshold **refuses everything**. "We never calibrated" fails loudly instead of degrading into "answer everything". | D-LLM-1 |
| A7 | `unavailable` is a first-class third state, distinct from `declined`. Conflating them would make a missing provider look like a content gap. | FR-025, FR-033, SC-013 |
| A8 | Jobs are in-memory and single-machine. A job id is not durable across a restart; an unknown id ⇒ `404 job_not_found`. Claiming durability would be invented capability. | D1 |

**Streaming is deferred, not offered.** A first token can be tens of seconds away, so streaming
would materially improve perceived latency — but verification (L3/L4) can only run on a *complete*
answer, so streaming would display unverified claims for seconds. If added later, the
verified/unverified state must be visible throughout and the answer must not be presentable as
final until verification completes.

#### `GET /api/answering/status`

**Traces**: FR-023, FR-024, FR-031.

```jsonc
{
  "enabled": false,
  "provider": "none",                 // none | extractive | ollama | openai_compatible
  "model": null,
  "endpoint": "http://127.0.0.1:11434",
  "locality": "local",                // DECLARED, never inferred from the endpoint string
  "locality_verified": true,          // resolved-address check agreed with the declaration
  "calibrated": false,                // min_score/min_margin are still 0.0 ⇒ refuses everything
  "reason": { "code": "no_provider", "message": "No generative model is installed on this host." }
}
```

**`api_key_env` is never echoed here, never logged, and never included in provider descriptions.**
The config holds the *name* of an environment variable, never a value and never a file path.

`locality` is declared rather than inferred because inferring "`127.0.0.1` means local" is a string
comparison a typo defeats (`localhost.example.com`). `locality_verified` is the result of resolving
the endpoint's addresses and requiring every one to be a loopback address when `locality: local`.
A divergence between declaration and resolved reality is a **fault**, reported as
`locality_verified: false` and blocking answering — not a warning.

**FR-025 is enforced architecturally, not by a runtime check**: `/api/search`, `/api/suggest`,
`/api/chapters`, `/api/passages` are registered on a router group with **no reference to the
answering package**; `/api/answer` and `/api/answering/status` are the only routes that construct a
provider. Provider construction failure must not abort server startup. There is no shared goroutine
pool or connection pool between the answering client and the search path, so a hung 240 s
generation cannot starve search and break SC-006 for a reason unrelated to search. Gate G-HTTP-5
proves it; its paired mutation wires search through the provider health check and must turn the
gate red.

---

### 3.11 `GET|POST /api/progress` — reading position

**Traces**: FR-010.

`POST` body `{ "chapter_slug": "…", "pid": "01JBX…", "t_seconds": 512.4 }`; identity is the
`X-Session` header (the same header `ai_interviewing` already uses — FR-013). `GET` returns the
stored position per chapter. Storage is local and single-user (D1); this is a convenience record,
not an account.

`404` when `X-Session` has no stored progress (determined negative). `503` when the store is
unreadable.

---

### 3.12 `GET /api/chapters/{chapter}/accuracy` — the measured transcript accuracy

**Traces**: FR-004, FR-033, SC-002.

```jsonc
{
  "measured": true,
  "method": "WER against a blind human reference over 30 seeded, stratified 30-second audio windows",
  "windows": 30,
  "seed": 1724,
  "wer": 0.061,
  "normaliser_sha256": "sha256:…",       // frozen BEFORE the first measurement
  "companion": { "coverage_gap_rate": 0.0, "timestamp_error_median_s": 0.4,
                 "timestamp_error_p95_s": 1.9, "speaker_accuracy": null },
  "evidence_href": "…/_evidence/verify-accuracy/2026-09-01T09-40Z-…/result.json",
  "measured_at": "2026-09-01T09:40:12Z"
}
```

When the measurement has not been run:

```jsonc
{ "measured": false, "wer": null,
  "reason": "verify-accuracy has not been run for this chapter",
  "remedy": "bash workshop/scripts/verify-accuracy.sh 01-ai-workflows --reference <path>" }
```

`measured: false` with `wer: null` is the third state expressed in data: not "0% error", not "we
failed" — *not measured*. Sampling is on the **audio timeline**, not on machine passages, because
sampling passages makes whole-region deletions structurally invisible (a dropped span produces no
passage to sample), biasing accuracy upward exactly where the transcript is worst (D-TRANS-3).

---

### 3.13 `GET /api/index/status` — generation transparency

**Traces**: FR-020, FR-027, FR-033.

```jsonc
{
  "live": { "generation": 7, "state": "live", "pid_count": 1421,
            "built_at": "2026-09-01T08:02:00Z" },
  "building": { "generation": 8, "state": "building", "progress": 0.42 },  // null when idle
  "legs": { "lexical": "ok", "semantic": "degraded" },
  "semantic_note": "Upstream index is rebuilding; semantic results may be incomplete.",
  "floor_calibrated": false
}
```

`503` when there is no verified generation at all — a system with nothing live must say so, not
serve zero results from an empty index. Only a `verified` generation may become `live`, by atomic
swap; readers never see `building`. This is a measured necessity: during the live rebuild, `chunks`
moved 58,734 → 58,744 while `last_indexed_at`/`root_hash` still advertised the previous generation
— a half-written, readable index (D-SEARCH-5).

Freshness polling (`index_status`, measured at **2.6–5.1 s** per call) is a **background** poll and
MUST NOT be on any request path.

---

## 4. Error and status taxonomy

| HTTP | Body discriminator | Category | Meaning |
|---|---|---|---|
| `200` | `status: "ok"` | determined, positive | State 0. |
| `200` | `status: "no_match"` / `"declined"` | determined, negative | State 1. A real, measurable result. |
| `200` | `status: "pending"` | in progress | Answer jobs only. |
| `202` | — | accepted | Answer job created. |
| `206` | — | partial content | Recording range. |
| `400` | `error.code` | request fault | Malformed query, malformed pid, empty query. Outside the three states (§1.5). |
| `404` | `status: "not_found"` or `error.code` | determined, negative | The thing genuinely does not exist. |
| `410` | `status: "redacted"` | determined, suppressed | The pid is real; content withheld (FR-039). |
| `413` | `error.code: "query_too_long"` | request fault | |
| `416` | `error.code` | request fault | Unsatisfiable or multi-range. |
| `503` | `status: "unavailable"` + `reason.code` | **could not determine** | State 2. Always. |
| `500` | `error.code: "internal_error"` | could not determine | Treated as state 2 by the client; a bug, not a result. |

There is deliberately **no** response in this contract that pairs HTTP `200` with an empty result
set and no discriminator. That combination is the failure mode FR-020 exists to prevent.

## 5. Closed enums

**5.1 Inventory.** Four closed enums govern every discriminated field: `status` (§2.5 — `ok` /
`no_match` / `unavailable`), `error.code` (§5.2), `reason.code` (§5.3) and `degraded.*` (§5.4).
Closed means a value outside the enum is a contract violation, not an extension point. A new
failure mode gets a new enum member and a new gate — never a free-text string.

**5.2 `error.code` (4xx/5xx request faults)**
`empty_query`, `query_too_long`, `malformed_pid`, `unknown_parameter`, `invalid_range`,
`multi_range_unsupported`, `chapter_not_found`, `material_not_found`, `job_not_found`,
`internal_error`.

**5.3 `reason.code` (state 2 — could not determine)**

| Code | Leg | Raised when |
|---|---|---|
| `embedding_timeout` | semantic | `timeout_ms` elapsed on the query embed. The direct fix for the recorded unbounded stall. |
| `embedding_backend_exhausted` | semantic | Upstream reported `all embedding servers exhausted`. |
| `embedding_degenerate_vectors` | semantic | Background distinct-vector probe failed — the mode that returns HTTP 200 with a repeated stale vector: well-formed, non-NaN, correct L2 norm, and completely wrong. It put 758 duplicate vectors into this index on 2026-08-26. |
| `partial_failure_zero_results` | mixed | Invariant I5: a leg failed and the survivors found nothing. |
| `lexical_index_unavailable` | lexical | FTS5 database missing, locked or corrupt. |
| `index_no_verified_generation` | index | Nothing is live. |
| `index_rebuilding_no_fallback` | index | Upstream rebuilding **and** the lexical leg is also down. |
| `suggest_timeout` | lexical | `suggest_budget_ms` elapsed with zero rows. |
| `registry_unreadable` | registry | `passages.db` cannot be opened. |
| `recording_not_reassembled` | — | 36 parts present, no reassembled file. |
| `recording_integrity_unverified` / `_stale` / `_mismatch` | — | FR-007 states. |
| `too_many_readers` | — | Concurrent range readers exceeded. |
| `no_provider` / `provider_disabled` / `provider_unreachable` / `model_not_generative` | answering | FR-025 states. |
| `verification_unavailable` | answering | Citation verification itself could not run — never treated as "verified". |

**5.4 `degraded.*` (state 0 with a caveat)**
`semantic`: `reindexing` \| `partial` \| `stale_generation`. `lexical`: `stale_generation`.

---

## 6. What the client is contractually required to do

The API cannot enforce rendering, so these obligations are stated here and tested by G-HTTP-7.

1. **Three render branches, minimum**, keyed on `body.status` — never on `results.length`.
2. **Never render the no-results copy on a non-200 response**, and never on `status != "no_match"`.
3. `reason.evidence` and `degraded.evidence` are diagnostics; render them only inside an explicit
   disclosure, never as primary copy.
4. `near_misses` render in a distinct, labelled region: *below the relevance threshold*.
5. When `floor_calibrated == false`, a `no_match` renders with the calibration caveat (I7).
6. When `degraded` is present, a persistent banner is shown for the whole result set — not a
   dismissible toast that leaves the reader believing they saw everything.
7. Suggestions are announced through a live region using `total`, and are keyboard-traversable via
   the per-response `id`s (FR-041, FR-042).
8. `410 redacted` renders as an explicit redaction notice, never as a broken link.

---

## 7. Traceability

### 7.1 Requirements this contract covers

| Requirement | Where |
|---|---|
| FR-001 complete transcript | §3.4 `coverage` block |
| FR-002 timestamps | §3.4 `t_start_s`/`t_end_s`; §3.5.2 seek |
| FR-003 uncertainty marked | §3.4 `uncertain`, `uncertain_reason` |
| FR-004 accuracy report | §3.12 |
| FR-005 speaker attribution / stated inability | §3.4 `speaker`, `speaker_source` |
| FR-007 integrity verified, fail loudly | §3.5.2 integrity table |
| FR-008 browsable chapters | §3.2 |
| FR-009 read + play in place | §3.3, §3.4, §3.5, §3.5.3 |
| FR-010 progress preserved | §3.11 |
| FR-011 navigable sections | §3.3 `sections`, §3.4 `section` filter |
| FR-013 conventions of the reference module | §1.1 base path, `X-Session` in §3.11 |
| FR-014 meaning-based results | §3.7 `mode=fused/semantic` |
| FR-015 suggestions while typing | §3.6 |
| FR-016 all content types indexed | §3.7 `kinds` + `corpus` boundary |
| FR-017 result → exact passage with context | §3.8 |
| FR-018 cross-references | §3.9 |
| FR-019 plain no-match, no unrelated answers | §2.6 I1/I3/I6 |
| FR-020 honest unavailability | §2 in full; §5.3 |
| FR-021 answers with citations | §3.10 A2, A3 |
| FR-022 decline rather than fabricate | §3.10 `declined`, A1 |
| FR-023 local and external providers | §3.10 `/api/answering/status` |
| FR-024 no external transmission when local | §3.10 `locality`, `locality_verified` |
| FR-025 search survives answering outage | §3.10 route separation; G-HTTP-5 |
| FR-027 idempotent extension (observable) | §1.2 `X-Workshop-Index-Generation`; §3.13 |
| FR-031 honest statement of limits | §3.7 `corpus`; §3.10 `reason`; §3.12 `measured:false` |
| FR-032 every check has a paired mutation | §2.7 |
| FR-033 unable-to-verify distinguishable | §2.1, §4, §3.12, §3.10 A7 |
| FR-037 stable identifiers | §1.4, §3.8 (contract in passage-contract.md) |
| FR-038 immutable machine layer + provenance | §3.4 `provenance`, `machine_text` |
| FR-039 redaction propagates | §3.4 markers, §3.8 `410`, §3.9 `redacted_omitted`, §3.10 A4 |
| FR-041 / FR-042 accessibility | §3.6 `id`/`total`/ordering; §6 client obligations |
| SC-001 100% coverage accounted | §3.4 `coverage.unexplained_gap_s` |
| SC-002 measured accuracy published | §3.12 |
| SC-003 land within 5 s | §3.4 timestamps + §3.5.2 range support |
| SC-005 suggestions ≤200 ms p95 | §3.6 lexical-only, `suggest_budget_ms` |
| SC-006 results ≤2 s p95 | §3.7 `timeout_ms`; §3.13 generation transparency |
| SC-007 / SC-008 retrieval quality | §3.7 `mode`, `score`, `above_floor` — **quality itself is unverified, §8 U5** |
| SC-009 citations resolve and support | §3.10 A2/A3 |
| SC-010 declines, never fabricates | §3.10 A1/A6 |
| SC-013 three states in 100% of checks | §2.1, §4 |
| SC-016 references survive correction | §3.8 resolution table; contract in passage-contract.md |
| SC-017 WCAG AA + keyboard | §3.6, §6 (API obligations only) |

### 7.2 Requirements **not** covered by this contract, and where they live

| Requirement | Owner |
|---|---|
| FR-006 preserve source material unmodified | [pipeline-cli.md §4.1](./pipeline-cli.md) — read-only guarantee at ingest |
| FR-012 documented start/stop | [pipeline-cli.md §4.8](./pipeline-cli.md) |
| FR-026 / FR-028 / FR-029 extension procedure | [pipeline-cli.md §4.7, §4.1](./pipeline-cli.md) |
| FR-030 documentation set | Not a contract. `docs/` deliverable + `quickstart.md`. |
| FR-034 no server-side CI | [pipeline-cli.md §2.7](./pipeline-cli.md) |
| **FR-035 governance carriers in lockstep** | **No interface contract can cover this.** It is a repository governance task (`scripts/verify-governance-cascade.sh`). Flagged, not silently dropped. |
| **FR-036 clean tree across repo and submodules** | **No interface contract can cover this.** Operator/commit-wrapper task. Flagged. |
| FR-040 evidence to a versioned location | [pipeline-cli.md §2.5](./pipeline-cli.md) |
| FR-041 / FR-042 full WCAG conformance | Frontend contract + `SC-017` audit. This document specifies only the API affordances that make them attainable. |

---

## 8. Unverified register — what this contract depends on that has not been measured

Marked so no reader mistakes a design intent for a measurement. Each names what settles it.

| # | Depends on | Status | Settled by |
|---|---|---|---|
| **U4** (research.md) | Idle embedding latency. `/api/search`'s SC-006 budget and the default `timeout_ms: 5000` assume the semantic leg can answer in seconds when idle. Only loaded figures exist (**18.2–21.0 s**, and 20.16/11.05/0.10 s across three identical calls). | **UNVERIFIED** | Time ten consecutive `semantic_search` calls in one warm session against an idle backend, **after** the running `lumen index --force` rebuild completes. |
| **C-3** (research/search-architecture.md) | Whether the ~2.2 s per-process indexer setup amortises across calls in one long-lived session. If it does not, every semantic query carries a multi-second fixed cost and SC-006 is unreachable regardless of U4. | **UNVERIFIED** | Same ten-call timing run; inspect the spread, not just the mean. |
| **U5** (research.md) | The relevance floor separating `ok` from `no_match`. No corpus exists yet, so no floor has been calibrated. | **UNVERIFIED** | Build the SC-007/SC-008 benchmark set (≥20 labelled queries) after Chapter 1 is indexed; calibrate, then flip `floor_calibrated` to `true`. Until then invariant **I7** applies and the API reports `floor_calibrated: false` on every response. |
| **D-LLM-5 estimate** | Generation latency (~21 s / ~42 s / ~95 s idle by model size). No generative model is installed, so nothing was timed. | **UNVERIFIED** | An operator `ollama pull` of a generative model, then a timed run. **Until then `estimated_seconds` MUST be `null`** — the API does not publish an estimate it has not measured. |
| **HelixLLM behaviour** | The `openai_compatible` adapter is claimed to cover HelixLLM. No HelixLLM server is running and no checkout exists on this disk; nothing about it was tested. | **UNVERIFIED** | Start a HelixLLM instance and run the adapter's conformance check against it. |
| **U3** (research.md) | That the recording contains intelligible speech in a known language. Nobody has listened and no ASR has run. Every transcript-serving endpoint here presumes a transcript exists and is meaningful. | **UNVERIFIED** | The 5-minute calibration run on the already-extracted 300 s sample (also closes U1 and U2). |

**Not marked unverified, because they were measured**: FTS5 prefix latency (p95 9.58 ms),
`health_check` lying about saturation, Lumen's glued no-results/warning string, Lumen's
content-derived chunk ids, the half-written readable index during rebuild, the recording's duration
and dual-mono audio, and the `search.component.ts` anti-pattern.
