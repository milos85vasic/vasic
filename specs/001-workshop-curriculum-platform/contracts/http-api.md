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
| G-HTTP-5 | With ollama stopped: `GET /api/search` returns **200** with real lexical results **and** `POST /api/ask` returns **503** `state:"unavailable"`. | Wire `/api/search` through the answering provider's health check. Gate must FAIL. (FR-025; mirrors research llm-bridging §3 item 5.) |
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
      "title": "Chapter 1 — Session Recording",
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
rules). `404` `chapter_not_found` when the slug names no chapter; `404` `material_not_found` when the
chapter is real and holds no material under that id; `503` when the file is listed in the chapter
manifest but missing on disk — again, absent-but-expected is state 2.

**That `503` carries `reason.code = "curriculum_unreadable"` (§5.3), and every `503` this route can
produce carries the same one.** The clause above used to specify the condition and name no code at
all, which left the one field a client is contractually required to branch on (§6) unstated for a
response this contract says is reachable — measured and named 2026-09-03, and the omission is
**WITHDRAWN**. There are four such paths and they are one code because they are one remedy — the
chapter tree could not be read — while `reason.message` and the diagnostic `reason.evidence` string
distinguish them:

| Condition | `reason.code` | `reason.leg` |
|---|---|---|
| The chapter tree could not be listed, so no slug can be resolved | `curriculum_unreadable` | `curriculum` |
| The chapter's own directory could not be listed | `curriculum_unreadable` | `curriculum` |
| The material is listed in the chapter and could not be **opened** | `curriculum_unreadable` | `curriculum` |
| The material was opened and could not be **measured** (`stat`) | `curriculum_unreadable` | `curriculum` |

Read from the four non-test raise sites in
`workshop/platform/backend/internal/api/chapters.go` (cited **by path only**), each calling the single
`writeUnavailable` helper in that same file. That helper is the only way a `503` leaves this handler,
and it emits `status: "unavailable"` plus a `reason` object with `code`, `leg`, `message` and
`retry_after_s`, together with the `X-Workshop-Search-Status: unavailable` header — the §4 shape
exactly. `curriculum_unreadable` is an existing §5.3 member and no code was invented to fill this gap.

**Honest boundary (§11.4.6): this is read from source, not from a live probe.** All four conditions
require the chapter tree to be unreadable underneath a running server, which was not induced on the
live deployment. What was measured live is the negative half — `GET /api/chapters` answers `200` with
chapter `01` present — so the `503` branch is established from the raise sites and the single
`writeUnavailable` choke point, and is recorded as that.

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

**Ordering of `results` — normative. `score` is NOT the sort key, and a client MUST NOT re-sort by
it.**

This clause is new on 2026-09-03. Until today §3.7 stated **no** ordering rule at all, and the served
order happened to be descending `score`. It no longer is. **No written contract was violated by that
change** — there was nothing here to violate — and that is precisely the argument for writing one:
an unstated invariant that clients depend on is a contract the server never agreed to and can break
without notice, which is what just happened.

Measured live 2026-09-03 against the running deployment at generation 67, `GET
/api/search?q=silence&limit=8`, ranks 1→8:

```
0.0273  0.0149  0.0143  0.0318  0.0156  0.0149  0.0145  0.0143
                        ^^^^^^ rank 4 outscores rank 1
```

Two further queries at the same limit and generation behave the same way: `q=chunk` reads
`0.0164 0.0323 0.0161 …` and `q=spec` reads `0.0320 0.0307 0.0118 0.0310 …`. **The scores themselves
did not move; only the order did.**

The ordering that actually applies, in the order it is applied:

1. Candidates are sorted **descending by `score`**, stably.
2. Hits are withheld and demoted: a hit whose locus does not resolve is dropped entirely (FR-030); a
   snippet carrying a source-filename shape is dropped by §2.4's disclosure guard; a semantic hit at or below the
   relevance floor is moved to the near-miss list and is **not** a result. The survivors are
   truncated to `limit`. **This is the window.**
3. **The window is then replaced by a permutation of itself.** The permutation is a reciprocal-rank
   fusion (k=60, the same constant used across legs) of two orderings over the same positions: the
   incoming score order from step 1, and an Okapi BM25 OR-ranking computed over the window **as its
   own mini-corpus** — so `idf` and length normalisation are relative to the window, which is what
   lets a short exact-title row compete with a long transcript segment. The final sort is stable and
   tie-broken by incoming position, so two equally-fused documents keep their relative order and an
   identical request returns an identical order.
4. `score` is **not** rewritten by step 3. It still means what the leg measured — cosine for
   semantic, bm25 for lexical, RRF-across-legs for fused. That is why `score` and position disagree:
   the number is preserved deliberately, and preserving it is what breaks the correspondence.

**What step 3 cannot do, and these are structural properties rather than promises.** It is a
permutation of the served window: it cannot add a hit, cannot remove one, and cannot change a score.
So `no_match` (reached from an **empty** hit list) is unreachable through it — a permutation of the
empty list is the empty list — the relevance floor is neither read nor widened, and no near-miss can
be promoted. It runs on the already-floor-filtered list for exactly that reason.

**The near-miss list is deliberately NOT reordered**, and stays in descending `score`. It is evidence
about what the floor rejected, and its order is the order that produced the rejection.

**This is switchable and the switch is part of the contract.** The permutation is applied when the
server's window-rerank option is on. It is on by default and is on in the deployment measured above
(the server logs `search window rerank=true` at boot and the running container's argv carries
`-search-window-rerank=true`). Turning it off restores step 1's descending-`score` order exactly,
because steps 1 and 2 are unchanged by it. **A client must therefore treat the served order as
authoritative and `score` as a displayable measurement, under either setting** — that rule is the same
in both configurations, which is what makes it safe to state.

**Honest boundary (§11.4.6).** Three things above are read from
`workshop/platform/backend/pkg/search/` (cited **by path only**) and not from a live probe: the
near-miss list's ordering — the three queries measured returned zero near-misses, so no live response
exercised it; the determinism of step 3; and the claim that disabling the option restores descending
`score`. On determinism the live evidence is real but thin and is not more than it is: two identical
`q=silence&limit=8` requests returned an identical order and identical scores. **Two calls do not
establish a determinism property** — they are consistent with it and would have refuted it had they
disagreed. The rerank-off configuration was **not** measured, because doing so requires restarting the
running deployment. What was measured live is the fact this clause exists to record: the served order
is not descending `score`.

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

### 3.10 `POST /api/ask` and `GET /api/ask/{job_id}` — ask a question, **asynchronously**

**Traces**: FR-021, FR-022, FR-023, FR-024, FR-025, SC-009, SC-010.

> #### ROUTE NAMES CORRECTED 2026-09-01 — `/api/answer` → `/api/ask`
>
> ~~This section named `POST /api/answer`, `GET /api/answer/{job_id}` and
> `GET /api/answering/status`.~~ Those three names are **withdrawn**, struck through rather than
> deleted so a reader can tell a corrected name from one that was never wrong. Nothing else in this
> section changed: every request shape, response shape, status code, normative point A1–A8 and the
> FR-025 route-separation rule below are unaltered. **Only the spelling of the paths moved.**
>
> - *Believed when written (2026-08-31)*: the contract was authored before the answering tree
>   existed, and `/api/answer` was chosen on paper with nothing to measure it against.
> - *Measured 2026-09-01*, against the live stack on port 8087, and re-derivable in one line each:
>
>   ```bash
>   curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8087/api/ask/status        # 200
>   curl -s -o /dev/null -w '%{http_code}\n' 'http://127.0.0.1:8087/api/ask?q=ping'      # 202
>   curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8087/api/ask/nosuchjob     # 404 job_not_found
>   curl -s -o /dev/null -w '%{http_code}\n' -X POST http://127.0.0.1:8087/api/answer    # 404
>   curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8087/api/answering/status  # 404
>   ```
>
>   `platform/backend/pkg/answer/http.go` mounts five routes and every one of them is spelled
>   `/api/ask`. `/api/answer` and `/api/answering/status` answer `404 page not found` — a plain
>   404, no contract body.
>
> - *Why the CONTRACT moved and not the code*: `/api/ask` is the name that exists. It is served by
>   five mounted routes, exercised by `pkg/answer/http_test.go` and
>   `pkg/answer/citations_verified_test.go`, probed by `platform/gates/route-manifest.tsv`, and
>   documented in the workshop's own user-facing pages and training material. `/api/answer` existed
>   **only on paper**, and its only appearance in executable code was a *negative* assertion — that
>   it must 404. Renaming five working routes would invalidate every measurement taken against them
>   and break documentation that was verified against reality, in exchange for a name whose sole
>   claim is that this file wrote it down first. A contract earns authority by being the thing the
>   system is measured against; it does not earn it by being older than the system.
> - *When it changed*: the answering tree was built at `/api/ask` by a second author as the
>   standalone `cmd/workshop-ask` binary and later folded into `cmd/workshop-server`. The
>   divergence was recorded — never hidden — in `platform/gates/route-manifest.tsv`, which held the
>   three `/api/answer` rows at `NOT_BUILT` specifically so the gap would print as DEBT on every
>   run until somebody decided it. This is that decision.
> - *What still holds, unchanged*: `POST /api/answer` and `GET /api/answering/status` MUST still
>   answer a **plain 404**, never a 405. A retired name must not start aliasing the live one — two
>   spellings for one resource is the same one-fact-in-two-places defect this correction removes.
>   That assertion did not move into this contract; it already lives in
>   `cmd/workshop-server/web_test.go` (`TestUnimplementedApiRoutesAre404OnEveryVerb`) and
>   `internal/api/gates_test.go`, which is why the manifest rows could be retired without losing
>   the guard.
> - *Recorded, NOT resolved by this correction*: the implementation also mounts
>   `GET /api/ask/{job_id}/stream`, which answers (`404 job_not_found` for an unknown id, measured
>   2026-09-01). **This contract still defers streaming** — see *"Streaming is deferred, not
>   offered"* below, and the verification argument there is untouched by the rename. A route that
>   the contract declines to offer is a **separate, open divergence**, and it is written down here
>   rather than swept in under a renaming decision it has nothing to do with.

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

#### `POST /api/ask`

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
  "poll": "/api/ask/ans_01JBX7R2…",
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

#### `GET /api/ask/{job_id}`

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
  "reason": "margin_too_small",     // §5.5, closed: below_threshold | margin_too_small
                                    // | unsupported | no_citations | redacted_evidence
                                    // NEVER an §5.3 code — the two sets are disjoint (§5.6)
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
| A7 | `unavailable` is a first-class third state, distinct from `declined`. Conflating them would make a missing provider look like a content gap. Enforced mechanically by §5.6: the decline vocabulary (§5.5) and the answering `reason.code` vocabulary (§5.3) are **disjoint**, so `no_provider` and its siblings cannot be filed as refusal reasons. | FR-025, FR-033, SC-013 |
| A8 | Jobs are in-memory and single-machine. A job id is not durable across a restart; an unknown id ⇒ `404 job_not_found`. Claiming durability would be invented capability. | D1 |

**Streaming is deferred, not offered.** A first token can be tens of seconds away, so streaming
would materially improve perceived latency — but verification (L3/L4) can only run on a *complete*
answer, so streaming would display unverified claims for seconds. If added later, the
verified/unverified state must be visible throughout and the answer must not be presentable as
final until verification completes.

#### `GET /api/ask/status`

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
answering package**; `/api/ask` and `/api/ask/status` are the only routes that construct a
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

**That `503` carries `status: "unavailable"` plus `reason.code = "progress_store_unreadable"` and
`reason.leg = "progress"` — §4's ordinary `503` row, with no exception.** Measured in-process on
2026-09-03 by seeding a torn `progress.json` under an `httptest` server built from the real handler:

```jsonc
// HTTP 503        X-Workshop-Search-Status: unavailable
{
  "status": "unavailable",
  "generation": null,
  "reason": {
    "code": "progress_store_unreadable",   // closed enum, §5.3
    "leg": "progress",
    "message": "the reading-position store could not be read; this is NOT the same as this session having no stored position",
    "retry_after_s": null                  // §2.5: null is UNKNOWN, never 0
  }
}
```

Both `503` paths on this route emit that shape — `GET` when the store cannot be read, `POST` when the
position cannot be stored — from the two non-test raise sites in
`workshop/platform/backend/internal/api/progress.go` (cited **by path only**), each calling the
`writeUnavailable` helper. They share one code because they share one failure: `Put` reads the store
before it writes, so both faults are the same file, and two codes would name one fault twice.

**THE PREVIOUS REVISION OF THIS CLAUSE IS WITHDRAWN, NOT RESTATED — but what it recorded was true
when written.** It documented this route as **the one documented exception to §4's `503` row**,
because both raise sites called `writeError` and emitted §1.5's fourth-thing shape instead:

```jsonc
// HTTP 503 — PRE-FIX, 2026-09-03. No `status`, no `reason`,
//            and no X-Workshop-Search-Status header at all.
{ "error": { "code": "internal_error", "message": "the reading-position store could not be read; …" } }
```

That capture is kept because it is the evidence, and because the deviation is the kind that hides:
the property this route actually turns on — that an unreadable store is never reported as "you have
never read anything here" — **held throughout**, so the endpoint's own gate was green the whole
time. A `503` was a `503` and a `404` was a `404`. What was broken was that this `503` did not
*parse* like any other `503`, which §6 depends on and no status-code assertion can see.

**Which of the two remedies was taken, and why.** The previous revision named two — teach the route
`writeUnavailable` and add a `reason.code` member, or amend §4 to admit an `error.code`-shaped
`503` — and made neither. **The first is now applied.** The second was refused: it would spend a
contract-wide guarantee, on which every other route and §6's client obligation depend, to
accommodate one local convenience store. A new `reason.code` member was required because nothing in
§5.3 fits — `registry_unreadable` is `passages.db` and `curriculum_unreadable` is the chapter's
pipeline output, and each would send an operator to the wrong file. See §5.3 for the member and
§5.6 for its disjointness.

**Gated.** Two tests in `internal/api/progress_test.go` (cited **by path only** — see the note at the
end of this clause) carry it: the older one seeds a corrupt store, requires `503`, and fails if the
body carries a `not_found` verdict; the new one asserts the envelope above on **both** methods —
`status`, an object-shaped `reason`, membership of `reason.code` in the closed §5.3 enum, the leg,
an explicit null `retry_after_s`, and the `X-Workshop-Search-Status` header. Its paired mutation
reverts either raise site to `writeError`, which compiles and turns it red. **A client may now
assume a `503` from `/api/progress` parses like a `503` from any other route.**

> **Why the two tests cited in this clause and in §3.7 are named by PATH and never by gate id — the
> closure check caught this edit, and the catch is worth more than the citation was.** The first
> draft of both clauses cited the implementation's own gate identifiers: the progress-store one here,
> the search-disclosure one in §3.7. `tasks.md`'s gate-attachment closure check enumerates gate ids
> by grepping `contracts/` and requires each to be carried by a task line; writing those two into
> this file moved its population from **31 to 33** and it immediately reported **`unattached: 2`**,
> naming both. **The instrument was right.** An id written into `contracts/` is a contract-level
> obligation that some task must build, and neither of these is one: both name tests that already
> exist in the backend, cited here as evidence, not commissioned here as work. **The fix was to drop
> the identifiers — not to widen the check, not to attach them to a task line, and not to touch a
> single checkbox.** Everything they carried survives as a path, which is what a reader needs in
> order to go and look. Re-measured after the correction: **31 ids, `unattached: 0`**.
>
> **The second half of that lesson is a limitation of the instrument, and it is why this note spells
> no identifier either.** Because the population is a grep over `contracts/`, a contract document
> **cannot discuss a gate id without enlisting it** — including in a note explaining why it should
> not be enlisted. The first attempt at this very paragraph named both ids and left the check at
> **33 / `unattached: 2`**. There is no way to write "this id is deliberately not a contract gate"
> inside `contracts/` and have the check agree. The resolution here is to describe the gates and let
> the cited test files carry their own names; **deliberately misspelling an id to slip past the
> extractor was considered and refused**, because an instrument that can be evaded by spelling is
> worth nothing, and the next reader would have no way to tell a dodge from a typo.

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

**The `503` row above has NO exception, and the sentence that used to record one is WITHDRAWN.**
An earlier revision named `/api/progress` (§3.11) as the single documented deviation: it answered
`503` with an `error.code` of `internal_error` and no `status` and no `reason.code`. That was a
correct measurement of the implementation on 2026-09-03, and it has since been **fixed in the
backend rather than accommodated here** — both of that route's raise sites now emit
`status: "unavailable"` plus `reason.code = "progress_store_unreadable"` (a new §5.3 member) and
`reason.leg = "progress"`, re-measured in-process the same day and gated with a paired mutation.
See §3.11 for both captures, before and after.

**The direction of that fix is the point, and it is worth stating once for the next deviation.** The
two remedies were to change the code or to widen this row. Widening the row was refused: this row is
what lets a client write ONE `503` parser, and §6's branch-on-`reason.code` obligation is quantified
over every route. A contract-wide guarantee is not the right currency for a single endpoint's
convenience store. **A documented exception here is a debt to be paid, not a shape to be matched.**

## 5. Closed enums

**5.1 Inventory.** **Six** closed enums govern every discriminated field:

| Enum | Members | Where |
|---|---|---|
| `status` — search/browse envelope | `ok` \| `no_match` \| `unavailable` | §2.5 |
| `status` — answer job | `pending` \| `answered` \| `declined` \| `unavailable` | §3.10 |
| `error.code` | request faults (4xx/5xx) | §5.2 |
| `reason.code` | state 2, *could not determine* | §5.3 |
| `degraded.*` | state 0 with a caveat | §5.4 |
| **decline `reason`** | state 1 negative, *determined* | **§5.5** |

**"Five closed enums" is WITHDRAWN as the count of this table, corrected 2026-09-03 by counting the
rows.** The table has six and has had six for as long as this document has existed; the word was
never re-derived after the sixth row was written. The count is the load-bearing part of the sentence
— a reader validating a client against "five" has one closed vocabulary they were never told to
implement.

**The sixth row was checked for the obvious alternative explanation — that a non-enum had been
pasted into an enum table — and it is NOT that.** The `decline reason` row is a genuine closed enum
of the same class as the other five: §5.5 enumerates its members exhaustively, it discriminates a
single wire field (`reason` on a `status: "declined"` body), and §5.6 makes its disjointness from
§5.3 normative rather than advisory. The backend carries it as a distinct closed type with its own
validity predicate and its own `reason` JSON tag, in
`workshop/platform/backend/pkg/answer/outcome.go` (cited **by path only**), where an out-of-set value
is rejected rather than serialised. So the row belongs and the number was stale.

**What the miscount actually is a symptom of is visible in the table itself: that row is the only one
in bold.** Every other row is plain; this one bolds both its `Enum` cell and its `§` cell. Bold on
exactly the newest row is the trace of an append that updated the table and not the sentence above
it. **Honest boundary (§11.4.6): git cannot separate the two.** `git log -S'Five closed enums'` and
`git log -S'decline \`reason\`'` over this path both terminate at the same single commit `695c22d`,
so the ordering above is read from the formatting, and the formatting is evidence of a late edit, not
proof of one. It is recorded as the reading it is.

`status` carries two vocabularies because it discriminates two different resources; both are closed,
and the resource decides which applies. Closed means a value outside the enum is a contract
violation, not an extension point. A new failure mode gets a new enum member and a new gate — never
a free-text string.

**5.2 `error.code` (4xx/5xx request faults)**
`empty_query`, `query_too_long`, `malformed_pid`, `unknown_parameter`, `invalid_range`,
`multi_range_unsupported`, `chapter_not_found`, `material_not_found`, `job_not_found`,
`internal_error`, `transcript_not_produced`, `area_not_found`, `area_not_published`,
`term_withdrawn`, `term_not_found`.

**The last five were added on 2026-09-03 by measurement, not by design, and — as in §5.3 — the
direction of the gap was implementation-ahead-of-contract, not the reverse.** All five are emitted on
the wire today by a deployment this contract governs; none of them was listed here. §5.1's rule cuts
the same way it does for `reason.code`: while a row was missing, a conforming client validating
against the printed contract had to reject a response the server legitimately produced. Every raise
site is in `workshop/platform/backend/internal/api/` and is cited **by path only**.

| Code | HTTP | Raised when | Evidence it reaches the wire |
|---|---|---|---|
| `transcript_not_produced` | `404` | §3.4's SECOND determined negative: the chapter **exists** and nothing has transcribed it. Deliberately not `chapter_not_found` — "no such chapter" sends a reader to the chapter list, "not transcribed yet" sends them to the pipeline. | Non-test raise site in `internal/api/chapters.go`; asserted on the response body by `internal/api/chapters_test.go`, which requires `error.code == "transcript_not_produced"` and states in its own failure message that `chapter_not_found` is the wrong answer. `go test ./internal/api/` PASS, 2026-09-03. |
| `area_not_found` | `404` | The area id names no area at all — either absent from the taxonomy, or 002 A3.1.1 applies (zero live evidencing mentions, which that contract treats as never having been returned). | Live probe 2026-09-03 against the running deployment: `GET /api/areas/00000000000000000000000000` ⇒ `404`, body `{"error":{"code":"area_not_found","message":"no such area","field":"area"}}`. Ten non-test raise sites, two each in `areas.go`, `questions.go`, `evidence.go`, `coverage.go` and `export.go`. |
| `area_not_published` | `404` | 002 A3.2.2: the area is **real** and has live evidence, but carries no recorded publication review, and A3.2.2 says plainly that the area is then not served. Distinct from `area_not_found` — what is missing is a different fact than "no such area". | Live probe 2026-09-03: `GET /api/areas/01M1GWQYWSKZA7A2S59MNV0Z2Q` (an id returned by `GET /api/areas` on that same deployment) ⇒ `404`, body `{"error":{"code":"area_not_published","message":"this area has no recorded publication review; FR-016/FR-048 make a review mandatory to serve an area's materials","field":"area"}}`. |
| `term_withdrawn` | `404` | 002 A3.4.2: the term is withdrawn from the taxonomy rather than merely unlinked. Two causes, one code, each naming its own `reason` in the message: `all_evidence_redacted` (evidence existed at build time and was redacted or removed) and `no_evidence_at_build` (the taxonomy build never recorded any — an FR-008 build defect, not a redaction). | Two non-test raise sites in `internal/api/terms.go`; asserted on the response body twice by `internal/api/terms_test.go`, both requiring `error.code == "term_withdrawn"`. `go test ./internal/api/` PASS, 2026-09-03. **Not live-probeable on this deployment**: `GET /api/terms` reports `withdrawn: {"count": 0, "terms": []}` over 8,537 terms at generation 67, so no served term is in that state today. |
| `term_not_found` | `404` | The taxonomy never carried a term of that name at all — as opposed to one withdrawn (above). | Live probe 2026-09-03: `GET /api/terms/knowledge-route-manifest-probe` ⇒ `404`, body `{"error":{"code":"term_not_found","message":"no such term","field":"term"}}`. |

**`transcript_not_produced` closes an inconsistency the implementation had already recorded against
this document.** `internal/api/api.go`'s declaration of that constant carries an in-source
`HONEST BOUNDARY (§11.4.6)` note saying §3.4's prose names the code while §5.2's printed inventory
does not, and resolving it in favour of the endpoint clause that actually describes the response.
That note was correct and is now discharged from this side: §3.4 and §5.2 agree.

**Honest boundary (§11.4.6) — what these five rows do NOT claim.** They are a statement about the
codes named here, established one at a time; they are not a re-audit of §5.2 as a whole. `job_not_found`
and `invalid_range` were carried by this list before today and were **not** re-verified against the
wire on 2026-09-03, so nothing above should be read as evidence that the remaining ten members are
each implemented. `term_withdrawn` in particular is established from its raise sites and its passing
wire-level test, **not** from a live response — the running deployment holds no withdrawn term to
produce one.

**5.3 `reason.code` (state 2 — could not determine)**

| Code | Leg | Raised when |
|---|---|---|
| `embedding_timeout` | semantic | `timeout_ms` elapsed on the query embed. The direct fix for the recorded unbounded stall. |
| `embedding_backend_exhausted` | semantic | Upstream reported `all embedding servers exhausted`. |
| `embedding_degenerate_vectors` | semantic | Background distinct-vector probe failed — the mode that returns HTTP 200 with a repeated stale vector: well-formed, non-NaN, correct L2 norm, and completely wrong. It put 758 duplicate vectors into this index on 2026-08-26. |
| `partial_failure_zero_results` | mixed | Invariant I5: a leg failed and the survivors found nothing. |
| `lexical_index_unavailable` | lexical | FTS5 database missing, locked or corrupt. |
| `code_index_unavailable` | lumen | The code-semantics leg's own backend could not be reached. A separate member from `lexical_index_unavailable`, not a reuse of it: a client that retries, or an operator who reports, has to be told **which** backend went down, and borrowing the other leg's code sends both to the wrong one. |
| `index_no_verified_generation` | index | Nothing is live. |
| `index_rebuilding_no_fallback` | index | Upstream rebuilding **and** the lexical leg is also down. |
| `suggest_timeout` | lexical | `suggest_budget_ms` elapsed with zero rows. |
| `registry_unreadable` | registry | `passages.db` cannot be opened. |
| `curriculum_unreadable` | curriculum | The chapter's own committed pipeline output — the transcript sidecar carrying the engine, the duration and the segment spans — could not be read (§3.3, §3.4). Not a reuse of `registry_unreadable`, because the two remedies point at different files: an unreadable registry is fixed by re-ingesting, an unreadable curriculum tree by repairing the mount or re-running transcription. |
| `progress_store_unreadable` | progress | The local reading-position store (`progress.json`) exists and could not be used (§3.11), on either the `GET` read path or the `POST` write path — `Put` reads before it writes, so both are the same file and the same fault. Not a reuse of `registry_unreadable` or `curriculum_unreadable`: this is a **third** file with a **third** remedy — repair or delete one local convenience file, costing a reader their saved positions and nothing else — and borrowing either existing code would send an operator to the wrong one. `progress` is likewise a leg of its own and never appears in a search envelope's `legs` map, because §3.11 is not a retrieval route. |
| `recording_not_reassembled` | — | 36 parts present, no reassembled file. |
| `recording_integrity_unverified` / `_stale` / `_mismatch` | — | FR-007 states. |
| `too_many_readers` | — | Concurrent range readers exceeded. |
| `no_provider` / `provider_disabled` / `provider_unreachable` / `model_not_generative` | answering | FR-025 states. |
| `verification_unavailable` | answering | Citation verification itself could not run — never treated as "verified". Names the **passage-facing** layers (L3 citation identity, L4 support); the fix, when there is one, is on the passage side. |
| `question_verification_unavailable` | answering | The **answer-against-question** layer (L5) was configured, was consulted, and **could not decide** — the model endpoint went away, the deadline elapsed, or the question's demand could not be classified. |
| `thresholds_uncalibrated` | answering | `min_score` / `min_margin` are still `0.0`, so the admission gate cannot separate answerable from unanswerable. It refuses **as state 2**, never as a decline: an uncalibrated instrument has judged nothing, and filing its refusal under §5.5 would blame the corpus for a missing calibration (A6, D-LLM-1, §8 U5). |
| `ingest_in_progress` | answering | An exclusive ingest lock is held, so answering is suspended while search keeps serving the existing live generation (D-LLM-10). |
| `request_cancelled` | answering | The caller went away, or the deadline elapsed, before any verdict existed. No verdict was reached, so none may be reported. |
| `locality_unverified` | answering | The declared `locality` disagreed with the endpoint's resolved addresses (§3.10 `GET /api/ask/status`). A fault that blocks answering outright — never a warning served alongside an answer. |
| `generation_gated_pending_clarification` | answering | Retrieval admitted material flagged as requiring answer-against-question verification while that layer is **not built in this deployment**. Distinct from `verification_unavailable`, which is transient and may succeed on the next call, and from `question_verification_unavailable`, which names a layer that exists and did not decide: this one is **standing**, and no restart, provider change or configuration clears it. |

**An EIGHTH row, `progress_store_unreadable`, was added on 2026-09-03 for the opposite reason to the
seven below — it is the only member here that the implementation did NOT already emit.** It was
minted to close §4's one documented `503` deviation (§3.11), and it was minted only after the
existing members were checked against the fault and found to misdescribe it. It is therefore *not*
a counter-example to the rule stated below: the code and the contract row landed **together**, in
the same change, with a paired-mutation gate, so there was never an interval in which a conforming
client would have rejected a legitimate response.

**Seven rows above were added on 2026-09-03 by measurement, not by design, and the direction of the
gap was the opposite of the one assumed.** They are `code_index_unavailable`,
`curriculum_unreadable`, `thresholds_uncalibrated`, `ingest_in_progress`, `request_cancelled`,
`locality_unverified` and `generation_gated_pending_clarification` — seven codes that the
implementation **already emits on the wire** and that this printed table did not list. The
enumeration was taken from the two closed vocabularies the backend declares against this section by
name, in `workshop/platform/backend/pkg/search/envelope.go` and
`workshop/platform/backend/pkg/answer/outcome.go`, each cited **by path only**; every one of the
seven has at least one non-test raise site. Two of them carry an in-source note saying this table
lacks the row and asking for it.

**This matters because §5.3 is closed.** "A value outside the enum is a contract violation, not an
extension point" (§5.1) cuts both ways: while the row was missing, a conforming client validating
against the printed contract would have had to reject a response the server legitimately produced.
A code that is implemented therefore belongs here **more** urgently than one that is not — the
reverse reading, that this section is a register of unbuilt codes, is **withdrawn**; `registry_unreadable`,
`suggest_timeout` and `embedding_timeout` have all been implemented since before it was written.
Codes that are contracted and unbuilt are tracked in §8 and in `tasks.md`, never by omission here.

**`question_verification_unavailable` is a third code, not a reuse of `verification_unavailable`, and
the difference is operational.** `verification_unavailable` says the machinery that checks a claim
*against its passages* did not run. This one says the machinery that checks a claim *against the
question* did not run. An operator reading them needs to know which side to look at, and one code
covering both would not tell them.

**It is never a degrade.** Where a layer was asked for and then produced no verdict, its verdict may
not be supplied by some other layer that happens to have completed
([specs/002-knowledge-areas-deep-linking](../../002-knowledge-areas-deep-linking/contracts/http-api-delta.md)
C4.3.4, FR-052). Serving `answered` on the strength of the four passage-facing layers, because the
question-facing one was silent, is exactly the substitution that requirement forbids. This code is
what refusing that substitution looks like on the wire: state 2, `503`, and no answer.

**5.4 `degraded.*` (state 0 with a caveat)**
`semantic`: `reindexing` \| `partial` \| `stale_generation`. `lexical`: `stale_generation`.

**5.5 decline `reason` (state 1 — determined, negative)**

Carried as a **bare enum string** on `status: "declined"` bodies (§3.10), never as an object. This
is the only registry of these members; a document that lists them elsewhere is quoting, not
defining.

| Member | Raised when |
|---|---|
| `below_threshold` | Top retrieval score is under `min_score`. The model was never called (L1). |
| `margin_too_small` | Top-1 to top-2 margin is under `min_margin` — retrieval could not discriminate. |
| `unsupported` | Support verification (L4) found a claim the cited passages do not entail. |
| `no_citations` | A citation pid is outside the live generation's member set (A3), so the whole answer is declined rather than silently stripped. |
| `redacted_evidence` | A cited passage was redacted between generation and delivery (A4). |
| `does_not_answer` | Answer-against-question verification (L5) found a claim that its cited passages **do** support and that answers a **different question** than the one asked. |

**Why `does_not_answer` is not `unsupported`, and may never be folded into it — normative.** The two
sound adjacent and are opposites. `unsupported` means *the cited passages do not state the claim*:
the generator produced content the corpus does not carry. `does_not_answer` means *the citation is
exact and the claim is still off-target* — typically a fragment lifted out of a passage on a related
topic, which clears every passage-facing layer by construction, and a verbatim fragment clears them
by identity.

**Their remedies point in opposite directions.** An `unsupported` claim needs better evidence — the
answer is about the right thing and rests on nothing. A `does_not_answer` claim needs a different
answer — the evidence is impeccable and the answer is about the wrong thing. Reporting the second
under the first would tell a maintainer to go fix retrieval when the retrieval was fine, and it would
make the two rates indistinguishable in aggregate, so a system trading one failure for the other
would look unchanged. Reporting it under the first was considered and **refused** for exactly that
reason; the member exists so the distinction survives to the wire.

This is the layer that closes the gap the earlier four could not see:
[specs/002-knowledge-areas-deep-linking](../../002-knowledge-areas-deep-linking/contracts/http-api-delta.md)
C4.3.3 (FR-051) records that the four existing layers all verify the claim against the **passage**
and none verifies it against the **question**, which is how a topically related fragment passes all
four. A claim that fails L5 refuses the **whole** answer — no claim is stripped and the remainder
served — on the same rule as `no_citations` above.

**5.6 The two answering vocabularies are disjoint — normative**

§5.5 and the answering-leg rows of §5.3 (`no_provider`, `provider_disabled`,
`provider_unreachable`, `model_not_generative`, `verification_unavailable`,
`question_verification_unavailable`, `thresholds_uncalibrated`, `ingest_in_progress`,
`request_cancelled`, `locality_unverified`, `generation_gated_pending_clarification`) **share no
member, and no member may be added to both.** A
decline is a judgement about the *content*; `unavailable` is the
absence of the instrument that would have made that judgement. Filing `no_provider` as a decline
reason would report a thing that could not run as a thing that was judged — state 2 rendered as
state 1, which is the precise failure the three-state contract exists to prevent. This rule is what
makes A7 checkable rather than merely stated: the disjointness is mechanical, so a violation is a
schema error and not a matter of interpretation.

**`progress_store_unreadable` is disjoint from §5.5 too, and is deliberately NOT added to the
enumeration above.** That list is scoped, by its own opening words, to the **answering-leg** rows of
§5.3, and this member's leg is `progress` — appending it would misstate the section's own scope and
quietly imply `/api/progress` has an answering path, which it does not. The disjointness it needs is
satisfied on stronger grounds than membership of a list: §5.5's vocabulary describes a judgement
about *content* reached by the answering pipeline, and §3.11 neither judges content nor has a
pipeline, so no decline reason can name this fault and this code can never name a decline. Recorded
here rather than left inferred, because "it is not in the list" and "it is not disjoint" are
different facts and only the first is true.

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
| FR-023 local and external providers | §3.10 `/api/ask/status` |
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
