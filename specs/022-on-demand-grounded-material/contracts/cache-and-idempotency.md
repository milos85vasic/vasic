# Contract: Cache, Single-Flight and Idempotency (FR-017 – FR-019, §11.4.253)

## Key and value
See `data-model.md` §5. Key = SHA-256 over (form, case-folded normalised topic, canonical params, **corpus
generation**, template version). Corpus generation is read from the live pipeline (`Pipeline.Generation`,
`pkg/answer/pipeline.go:92-95`); T006 confirms it changes on every index swap that can alter retrieval results.

## Lookup (stage 4)
1. Compute key; `SELECT` the entry. Miss ⇒ continue the pipeline.
2. Hit with `status='generated'` ⇒ **re-validate without any model call**: every cited pid is still live in the
   registry (`LiveRegistry`, `pkg/answer/verify.go:33`) and not suppressed (suppression index). Any failure ⇒ treat
   as a miss for *this* request (the entry is not deleted here; a newer-generation entry would have a different key
   anyway) or, if the cause is suppression, return `declined redacted_evidence` (FR-010).
3. Hit with `status='declined'` ⇒ return the decline (200), `served_from='cache'`.
4. `served_from='cache'` is shown to the learner; a cache hit never enters the budget ledger (B-6).

## Single-flight
An in-process map `cache_key → *flight` ensures concurrent identical requests share one generation: followers wait
on the leader and then read the persisted result. Across processes (not expected: single instance) the
`INSERT … ON CONFLICT(cache_key) DO NOTHING` plus re-read provides the correctness backstop, never a second
provider call by design.

## Idempotency
`Idempotency-Key` header (8–64 chars). `UNIQUE(session, idem_key)` on `material_job`; a repeat returns the existing
job (`200`, same id, current status) and performs no work. A repeat with the same key but a *different* request body
is `409 idempotency_conflict`.

## Properties

| ID | Property | Oracle | Paired mutation |
|---|---|---|---|
| C-1 | identical second request: 0 provider calls, byte-identical material | stub counter + sha256 of body | include a timestamp in the cached body ⇒ FAIL |
| C-2 | corpus generation change ⇒ miss | injected generation | omit generation from the key ⇒ FAIL |
| C-3 | 20 concurrent identical requests ⇒ 1 provider call, 1 audit line, 1 `material_cache` row | counters + row count | remove single-flight ⇒ FAIL |
| C-4 | 20 retries with one `Idempotency-Key` ⇒ 1 job | row count | drop the UNIQUE constraint ⇒ FAIL |
| C-5 | same key, different body ⇒ 409 | response code | ignore body difference ⇒ FAIL |
| C-6 | cached item later suppressed ⇒ withheld at serve time | canary pid | skip re-validation ⇒ FAIL |
| C-7 | `unavailable` never cached | row count | cache errors ⇒ FAIL |
| C-8 | golden key vectors equal the independent oracle's | `pipeline/materialgen_oracle.py` | change the separator ⇒ FAIL |
| C-9 | topic normalisation: NFC/whitespace variants map to one key; different topics never collide in the golden set | oracle vectors | skip NFC ⇒ FAIL |

## Eviction
No eviction in this feature (rows are small JSON). A size alarm (row count / bytes) is exposed as a counter; a
retention policy is an operator decision tracked with OD-3 (personal-data linkage lives only in `material`, never
in `material_cache`).
