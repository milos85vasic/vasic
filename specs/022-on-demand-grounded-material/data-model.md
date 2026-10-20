# Phase 1 Data Model: On-Demand Grounded Material Generation

State lives in a **separate SQLite file `materials.db`** in the server data directory (the `pkg/authstore`
idiom, `SetMaxOpenConns(1)`), not in the index database: learner-owned history, budget accounting and the cache
must survive a corpus re-ingest (013 plan, "Storage placement decision", applies identically). The cache is
keyed by corpus generation so survival does not mean staleness.

## 1. Request (validated, normalised)

```go
// platform/backend/pkg/materialgen/request.go
type Form string // "explainer" | "flashcards" | "short_prompts"   (closed; "mcq" deliberately absent, FR-007)
type Request struct {
    Form      Form
    Topic     string  // normalised: NFC, trimmed, whitespace collapsed; 1..300 runes; no control characters
    Count     int     // items (flashcards/short_prompts) or sections (explainer); 1..Max (default Max=8)
    IdemKey   string  // 8..64 chars [A-Za-z0-9_-]; from the Idempotency-Key header
    RemoteAck *RemoteAck // required iff the configured provider is not local (FR-016)
}
type RemoteAck struct{ Provider, Locality string } // must equal what the server disclosed in the preflight
```

`Normalise(topic)` is deterministic and locale-independent. The *key form* additionally case-folds (FR-018).

## 2. Outcome vocabulary (closed, disjoint)

| Set | Members |
|---|---|
| `Status` | `generated`, `declined`, `unavailable` (plus job-only `pending`) |
| `DeclineReason` (HTTP 200) | `below_threshold`, `margin_too_small`, `insufficient_coverage`, `unsupported`, `no_citations`, `redacted_evidence`, `does_not_answer`, `no_items`, `malformed_output` |
| `UnavailableCode` (HTTP 503) | `generation_disabled`, `no_provider`, `provider_disabled`, `provider_unreachable`, `model_not_generative`, `thresholds_uncalibrated`, `retrieval_unavailable`, `verification_unavailable`, `budget_exceeded`, `budget_store_unreadable`, `audit_unwritable`, `cache_store_unreadable`, `rate_limited`, `interrupted` |

The first five decline members and `provider_*`, `model_not_generative`, `retrieval_*`, `verification_*`
deliberately reuse the **names** of `pkg/answer`'s vocabularies (`outcome.go:113-300`) so a dashboard reads one
language; they are re-declared in `pkg/materialgen/outcome.go` (`answer`'s file is not edited) and a parity test
asserts every reused name equals the corresponding `answer` constant. `DisjointVocabularies()` asserts the three
sets share no member.

## 3. Items (strict JSON from the provider; `DisallowUnknownFields`)

```json
// form = flashcards
{"items":[{"front":"…","back":"…","citations":["<pid>"],"quote":"…verbatim from the cited passage…"}]}
// form = short_prompts
{"items":[{"prompt":"…","model_answer":"…","citations":["<pid>","<pid>"],"quote":"…"}]}
// form = explainer
{"sections":[{"heading":"…","body":"…","citations":["<pid>"],"quote":"…"}]}
```

Shape limits: `len(items|sections) == Count` exactly (more or fewer ⇒ `malformed_output`; no silent trimming),
`front|prompt|heading ≤ 200` runes, `back|model_answer|body ≤ 1200` runes, `citations` 1..4 pids, `quote ≤ 400`
runes. The quote is shown to the learner as the evidence, and is checked as a whitespace-normalised substring
of the cited passage (`grounding.ValidateVerbatim`, `submodules/RAG/pkg/grounding/grounding.go:322`).

## 4. Persisted tables

```sql
CREATE TABLE IF NOT EXISTS material_job (
  id            TEXT PRIMARY KEY,
  session       TEXT NOT NULL,
  idem_key      TEXT NOT NULL,
  form          TEXT NOT NULL CHECK (form IN ('explainer','flashcards','short_prompts')),
  topic         TEXT NOT NULL,                       -- the learner's own request text; never logged
  status        TEXT NOT NULL CHECK (status IN ('pending','generated','declined','unavailable')),
  phase         TEXT NOT NULL CHECK (phase IN ('queued','retrieving','generating','verifying','done')),
  reason_code   TEXT,                                -- decline reason or unavailable code
  material_id   TEXT,
  created_at    TEXT NOT NULL,
  updated_at    TEXT NOT NULL,
  UNIQUE (session, idem_key)                         -- §11.4.253: retries converge on one job
);

CREATE TABLE IF NOT EXISTS material (
  id                TEXT PRIMARY KEY,
  job_id            TEXT NOT NULL,
  session           TEXT NOT NULL,                   -- ownership; removed on learner deletion
  cache_key         TEXT NOT NULL,
  served_from       TEXT NOT NULL CHECK (served_from IN ('fresh','cache')),
  deleted_at        TEXT,
  created_at        TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS material_session ON material(session, created_at);

CREATE TABLE IF NOT EXISTS material_cache (
  cache_key         TEXT PRIMARY KEY,               -- UNIQUE by construction (single-flight + conflict-do-nothing)
  status            TEXT NOT NULL CHECK (status IN ('generated','declined')),
  reason_code       TEXT,
  corpus_generation TEXT NOT NULL,
  template_version  TEXT NOT NULL,
  provider          TEXT NOT NULL,
  model             TEXT NOT NULL,
  locality          TEXT NOT NULL CHECK (locality IN ('local','lan','remote')),
  admitted_pids     TEXT NOT NULL,                  -- JSON array, sorted
  verification      TEXT NOT NULL,                  -- JSON: per-layer results
  content_json      TEXT,                           -- NULL when declined
  tokens_in         INTEGER NOT NULL, tokens_out INTEGER NOT NULL,
  created_at        TEXT NOT NULL,
  CHECK ((status = 'generated') = (content_json IS NOT NULL))
);

CREATE TABLE IF NOT EXISTS generation_attempt (
  id            TEXT PRIMARY KEY,
  job_id        TEXT NOT NULL,
  provider      TEXT NOT NULL,
  locality      TEXT NOT NULL,
  started_at    TEXT NOT NULL,
  settled_at    TEXT,                               -- NULL = in flight or crashed mid-flight (visible, FR-015)
  outcome       TEXT,
  req_bytes     INTEGER NOT NULL,
  tokens_in     INTEGER, tokens_out INTEGER,
  audit_written INTEGER NOT NULL DEFAULT 0 CHECK (audit_written IN (0,1))
);

CREATE TABLE IF NOT EXISTS budget_reservation (
  job_id    TEXT PRIMARY KEY,
  day       TEXT NOT NULL,                           -- UTC date at reservation time
  session   TEXT NOT NULL,
  tokens    INTEGER NOT NULL CHECK (tokens > 0),
  state     TEXT NOT NULL CHECK (state IN ('reserved','settled','released')),
  settled   INTEGER
);
CREATE INDEX IF NOT EXISTS budget_day_session ON budget_reservation(day, session, state);
```

Daily totals are **derived** by summing `budget_reservation` rows (`reserved` count their reservation, `settled`
count actual tokens, `released` count 0); there is no mutable counter that can drift from the rows. Reservation is
one `BEGIN IMMEDIATE` transaction that sums, compares to the limit, and inserts, so concurrent requests cannot
jointly exceed a budget.

## 5. Cache key

```
cache_key = hex(SHA-256( "mg1\n" + form + "\n" + key_topic + "\n" + canonical_params_json + "\n"
                         + corpus_generation + "\n" + template_version ))
key_topic = case-fold(Normalise(topic));   canonical_params_json = {"count":N} with sorted keys, no spaces
```

Provider and model are **not** in the key (they are recorded values): the cached content is the output of
verification against the corpus, and is acceptable regardless of which model produced it. Changing the prompt
template changes `template_version` and therefore the key. Golden key vectors come from the independent Python
oracle (T013).

## 6. Provenance object (stored and returned)

```json
{"provider":"ollama","model":"<name>","locality":"local","corpus_generation":"<id>",
 "template_version":"mg-explainer-v1","admitted_passages":6,"served_from":"fresh",
 "verification":{"membership":"pass","verbatim":"pass","entailment":"pass","relevance":"pass"},
 "tokens":{"in_estimated":2210,"in_actual":2188,"out":612},"elapsed_s":31.4}
```

## 7. Validation rules

- `status='generated'` ⇒ every item has ≥ 1 citation ∈ `admitted_pids`, the quote verifies, and all four layers `pass`.
- `declined` rows never carry `content_json`; `unavailable` outcomes are never written to `material_cache`.
- A `material` row exists only if its cache entry exists (transactional insert of both, or neither).
- `generation_attempt.audit_written=1` is required for every non-local attempt that reached the provider.
