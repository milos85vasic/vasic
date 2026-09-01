# Data Model — Workshop Curriculum Platform

**Feature**: `specs/001-workshop-curriculum-platform` | **Date**: 2026-09-01
**Derived from**: [spec.md](./spec.md) Key Entities, constrained by [research.md](./research.md)

## Scope, and what is authoritative

**This document is a deliberate abstraction. It is NOT the full schema, and a field's absence here
is not evidence that the field does not exist.** It carries the entities, their relationships, the
identity decision they all hang on, and the state machines. Storage columns, wire fields, DDL,
closed enums and gate definitions live in the contracts, which are normative:

| Layer | Authoritative document |
|---|---|
| Registry records, SQLite DDL, ingest matching, resolution, redaction log | [contracts/passage-contract.md](./contracts/passage-contract.md) |
| HTTP request/response bodies, status envelopes, **all closed enums** | [contracts/http-api.md](./contracts/http-api.md) |
| CLI surface, exit codes, pipeline stages | [contracts/pipeline-cli.md](./contracts/pipeline-cli.md) |

Where this document and a contract disagree, **the contract wins and this document is the defect**.
Section [Not modelled here](#not-modelled-here--and-where-it-does-live) names the specific fields
this abstraction omits, so a reader is pointed rather than left to infer absence.

## The one decision everything hangs on

`Passage.pid` is a **ULID minted once at ingest**. It is not derived from content and not derived
from position.

This is not a style preference. Both alternatives were measured and both fail (D-SEARCH-1):

| Candidate identity | Behaviour measured | Consequence |
|---|---|---|
| Lumen chunk ID (content-derived) | typo fix changed `4b98e295c112a429` → `610e608a50f273a6` | every human correction (FR-038) silently breaks every citation to that passage |
| Positional key (file + line range) | prepending a section moved every later range | every edit above a passage breaks its links |

Under either, **SC-016 scores 0% on corrected passages while the UI keeps rendering links that
now point somewhere else** — a failure with no visible symptom. A minted identifier is the only
form that survives both operations, which is why it is the root of this model.

## Entities

### Chapter

| Field | Type | Notes |
|---|---|---|
| `ordinal` | int | zero-padded on disk (`chapters/01/`), matching existing convention |
| `slug` | string | stable, URL-safe; never reused |
| `title` | string | human title |
| `summary` | string | shown in the chapter list (FR-008) |
| `recording` | Recording | exactly one today; the model permits several |
| `materials` | []SupportingMaterial | notes, diagrams, code |
| `transcript` | Transcript | absent until produced |
| `status` | enum | `draft` \| `transcribed` \| `published` |

**Rules**: a chapter MUST NOT reach `published` with an incomplete material set (FR-028).
`ordinal` and `slug` are immutable once published — cross-references resolve through them.

### Recording

| Field | Type | Notes |
|---|---|---|
| `path` | string | git-ignored; the whole file is never committed |
| `parts` | []string | the 36 × 50 MB `tar.gz` parts that *are* committed |
| `sha256` | string | verified before use (FR-007) |
| `duration_s` | float | measured, not assumed — Chapter 1 is `6928.75` |
| `audio` | AudioProps | codec, sample rate, channel layout |

**Rules**: reassembly MUST verify `sha256` and fail loudly on mismatch. `duration_s` is the
denominator for SC-001 coverage, so it is stored, not recomputed per query.

`AudioProps` records `dual_mono: true` for Chapter 1 — measured L−R difference −90.3 dB. This is
data, not trivia: it is why `Passage.speaker` cannot be machine-derived (D-TRANS-2).

### Transcript

Two layers, because the machine output is *evidence* and must survive correction (FR-038).

| Field | Type | Notes |
|---|---|---|
| `chapter_slug` | string | owner |
| `engine` | string | e.g. `faster-whisper/large-v3-turbo` |
| `engine_params` | map | including the frozen normaliser hash |
| `machine_passages` | []Passage | **immutable** once written |
| `corrections` | []Correction | append-only overlay |
| `accuracy` | AccuracyReport | absent until measured |

**Rules**: `machine_passages` is never mutated — a correction is a new `Correction` row. Deleting
it would destroy the ability to re-measure accuracy later (SC-002).

### Passage — the addressable unit

| Field | Type | Notes |
|---|---|---|
| `pid` | ULID | **minted at ingest**; the only citable identity |
| `kind` | enum | `transcript` \| `doc_section` \| `code` \| `diagram` |
| `source_ref` | SourceRef | where it came from; may move without changing `pid` |
| `text` | string | current text: machine, or corrected if a `Correction` applies |
| `provenance` | enum | `machine` \| `human_corrected` (FR-038) |
| `confidence` | float? | `avg_logprob`-derived; null for non-transcript kinds |
| `uncertain` | bool | drives the FR-003 "unclear, not guessed" marking |
| `t_start_s`, `t_end_s` | float? | transcript kinds only; the SC-003 5 s bound applies |
| `speaker` | string? | human-attributed or null — never machine-guessed (D-TRANS-2) |
| `redacted` | bool | FR-039; suppresses from index, answers and export |
| `content_hash` | string | **change detection only — deliberately NOT identity** |

**Rules**:
- `pid` is written back into the source artifact as `<!-- pid: … -->` so the anchor travels with
  the text.
- For a chapter's transcript passages: `⋃ [t_start_s, t_end_s] ∪ VAD_silence == [0, duration_s]`
  **exactly**. This makes SC-001 an arithmetic identity rather than a judgement (D-TRANS-4).
- `content_hash` is named to prevent the exact mistake this model exists to avoid. Any code
  treating it as identity is a defect.
- A redacted passage MUST propagate to the index and to any stored answers, not merely to the
  rendered transcript.

### Correction

| Field | Type |
|---|---|
| `pid` | ULID (the passage corrected) |
| `text` | string (replacement) |
| `author`, `at`, `reason` | provenance |

**Rule**: corrections never change `pid`. That is the whole point of the layer.

### CrossReference

| Field | Type | Notes |
|---|---|---|
| `from_pid`, `to_pid` | ULID | directed |
| `relation` | enum | `explains` \| `demonstrates` \| `continues` \| `related` |
| `origin` | enum | `derived` \| `authored` |
| `score` | float? | for `derived` |

**Rules**: self-references rejected. Traversal must be cycle-safe (spec edge case: "cross-
references must not create loops that trap a reader"). `derived` links are rebuildable; `authored`
links are content and survive re-index.

### Index (derived, never authoritative)

Two paths, because one cannot meet both latency targets (D-SEARCH-2).

| Path | Backing | Measured |
|---|---|---|
| `lexical` | SQLite FTS5 prefix index over symbols/titles | p95 **9.58 ms** |
| `semantic` | embedding vectors, 768-dim | query embed **18.2–21.0 s** under load |

| Field | Type | Notes |
|---|---|---|
| `generation` | int | monotonic |
| `state` | enum | `building` \| `verified` \| `live` \| `superseded` \| `discarded` (passage-contract.md §4.4 `generations`) |
| `pid_count` | int | verification gate input |

**Rules**: only a `verified` generation may become `live`, by atomic swap. Readers never see
`building` — measured necessity: during the live rebuild, `chunks` moved while
`last_indexed_at` still advertised the previous generation, i.e. a half-written readable index.

### Answer

**Authoritative schema**: [contracts/http-api.md](./contracts/http-api.md) §3.10 and §5. The table
below is the entity view of that contract. It uses the contract's field names and the contract's
enum members exactly — see [Arbitration](#arbitration-2026-09-01--one-answer-shape) for why.

| Field | Type | Notes |
|---|---|---|
| `question` | string | |
| `status` | enum | `answered` \| `declined` \| `unavailable` — the three **terminal** states. (`pending` is a state of the answer *job* resource, not of an answer; http-api.md §3.10.) |
| `text` | string? | present only when `answered` |
| `citations` | []ULID | **≥1 when `answered`**, enforced by schema (`minItems: 1`) |
| `reason` | discriminated | absent when `answered`; shape and vocabulary determined by `status` — table below |
| `retrieval` | RetrievalTrace | top score and margin, recorded even on success |

**`reason` is discriminated by `status`, and the two reason vocabularies are disjoint:**

| `status` | HTTP | `reason` shape | Closed vocabulary |
|---|---|---|---|
| `answered` | `200` | absent | — |
| `declined` | **`200`** — a correct result, not an error | bare enum string | `below_threshold` \| `margin_too_small` \| `unsupported` \| `no_citations` \| `redacted_evidence` (http-api.md §5.5) |
| `unavailable` | **`503`** | object `{ code, message, retry_after_s }` | the answering-leg codes of http-api.md §5.3: `no_provider` \| `provider_disabled` \| `provider_unreachable` \| `model_not_generative` \| `verification_unavailable` |

**Rules**: `answered` with zero citations is structurally undecodable (`minItems: 1`). Every
citation MUST be a member of the live generation's PID set (`generation_members`) — a deterministic
check, and the reason SC-009 is reachable at all. A citation outside the set makes the whole answer
`declined{no_citations}`; a citation that resolves to a redacted passage makes it
`declined{redacted_evidence}`; a citation whose verification *could not run* makes it
`unavailable{verification_unavailable}`, never `declined` — verification that could not run is not
verification that failed (passage-contract.md §7.2 C3–C5). Claims are never silently stripped.
`retrieval` is stored even on success so a 0.002-margin pass is visible as *fragile* rather than
indistinguishable from a confident one.

`unavailable` is a first-class third state, distinct from `declined`. Conflating them would make a
missing provider look like a content gap — the Honest Instruments principle applied to the domain.

**Why `no_provider` is not a decline reason.** A decline is a *judgement about the content*: the
system retrieved, evaluated, and determined the corpus does not support an answer. `unavailable` is
the absence of the instrument that would have made that judgement. "No generative model is
installed" is not a fact about the curriculum, and filing it as a refusal reason would report a
thing that could not run as a thing that was judged — the exact failure the three-state contract
exists to prevent. `no_provider` therefore lives only in the `unavailable` vocabulary
(http-api.md §5.3), and the two vocabularies above share no member.

#### Arbitration (2026-09-01) — one Answer shape

This entity previously carried a second, incompatible shape: `verdict` / `refused` /
`refusal_reason`, with `no_provider` filed among the refusal reasons. That fork is **withdrawn, not
silently replaced**, and the record is kept here so a reader of an older draft can see what changed:

| | withdrawn (this document) | adopted (http-api.md) |
|---|---|---|
| field name | `verdict` | **`status`** |
| refusal member | `refused` | **`declined`** |
| reason field | `refusal_reason` | **`reason`** |
| reason members | `below_threshold, margin_too_small, unsupported, no_provider` | **`below_threshold, margin_too_small, unsupported, no_citations, redacted_evidence`** — and `no_provider` moved to the `unavailable` vocabulary, where its meaning belongs |

Three reasons the API contract's shape won:

1. **It is the shape the tests will be written against.** T057–T068 cite `http-api.md`; no task
   cites this document for the Answer shape. `plan.md` marks refusal behaviour and citation
   verification `[TDD]`, so those tests land *before* the implementation — against whichever
   document they name.
2. **`verdict` was already taken.** `submodules/verdict/pkg/verdict/` is this project's 0/1/2
   three-valued *instrument* result, used by every command and endpoint (T018). Naming the answer's
   domain outcome `verdict` too would put two different meanings on one word in one codebase, which
   is the conflation this feature is built to avoid.

   > Two corrections here, both 2026-09-01, both path/reference only — the naming argument itself is
   > untouched. ~~`pkg/verdict/`~~ was an unqualified path written when the package lived under the
   > backend module; `verdict` is now a separately published module mounted at
   > `submodules/verdict` (see [tasks.md](./tasks.md)'s File Structure correction). ~~`(T012)`~~ was
   > simply the wrong task number — T012 is the append-only redaction log; the verdict helpers are
   > **T018**. Found while correcting the paths, and fixed by editing the *citation*, never by
   > renumbering the task: other documents and agent reports cite these T-numbers, so moving one to
   > make a stale reference true would break every correct reference to it.
3. **`status` is already the discriminator everywhere else.** The search envelope keys on
   `status` (§2.5), and `declined` is the term already used by `passage-contract.md` §7.2 (C3–C5),
   `research/llm-bridging.md` ("Behaviour when the provider is unreachable") and the SC-010 gate.
   Choosing `status`/`declined` moved four documents into agreement instead of two.

## Relationships

```
Chapter 1──1 Recording
   │  1──0..1 Transcript ──1──* Passage ──0..* Correction
   │  1──*    SupportingMaterial ──1──* Passage
   ▼
Passage *──* Passage   (CrossReference, directed, cycle-safe)
Passage *──1 Index generation   (membership; rebuildable)
Answer  *──* Passage   (citations; membership checked against the LIVE generation)
```

## State transitions

**Chapter**: `draft → transcribed → published`. Regression to `draft` is permitted (a recording is
replaced); `published → published` must be idempotent (FR-027).

**Index generation**: `building → verified → live`, and `live → superseded` on swap.
`building → discarded` on failed verification — a generation that fails its gate is never served,
which is what keeps FR-020 honest.

**Passage provenance**: `machine → human_corrected` only. There is no path back, because the
machine text is retained separately rather than overwritten.

## Validation rules traced to requirements

| Rule | Requirement |
|---|---|
| `pid` minted, never derived | FR-037, SC-016 |
| machine passages immutable; corrections layered | FR-038, SC-002 |
| span union equals full duration | FR-001, SC-001 |
| timestamp within 5 s | FR-002, SC-003 |
| `uncertain` set from engine confidence, never inferred | FR-003 |
| `speaker` null unless human-attributed | FR-005 |
| sha256 verified before reassembly | FR-007 |
| `redacted` propagates to index and stored answers | FR-039 |
| `answered` ⇒ ≥1 citation, all in live PID set | FR-021, SC-009 |
| `declined` ≠ `unavailable`; their reason vocabularies are disjoint | FR-022, FR-025, SC-010, SC-013 |
| code passage identity keyed on `(path, symbol)` + `symbol_aliases`; unaliased rename fails loudly | FR-037, **SC-016a** |
| only `verified` generations serve | FR-020 |
| re-ingest is idempotent on `pid` | FR-027 |

## Not modelled here — and where it does live

The contracts specify fields this document deliberately does not repeat. They are **named** here so
that absence above reads as *abstraction*, not as *nonexistence*. Duplicating them would create a
fourth place to drift, which is precisely how the Answer fork above happened.

| Field / table | What it carries | Authoritative location |
|---|---|---|
| `machine_text` | the immutable machine layer that makes SC-002 re-measurable | passage-contract.md §4.2 (F1, F2), §4.3 DDL |
| `source_ref.anchor` | `inline` \| `sidecar` \| `registry_only` — how the identifier travels | passage-contract.md §4.2, §8 R5/R6 |
| `uncertain_reason` | `low_confidence` \| `inaudible` \| `overlapping_speech` \| `language_uncertain`; non-null **iff** `uncertain` | passage-contract.md §4.2 F3; http-api.md §3.4 |
| `speaker_source` | `human` \| `unattributed` — never `machine` (D-TRANS-2). This is the FR-005 "state where it cannot" half. | passage-contract.md §4.2 F4; http-api.md §3.4 |
| `symbol_aliases` | the code-passage rename alias table SC-016a rests on | passage-contract.md §4.3 DDL, §6.2–6.6, §8 R3/R4 |
| `redactions` | append-only redaction log — `Passage.redacted` above is the *materialisation*, not the record | passage-contract.md §4.3 DDL, §7.3 |
| `generation_members` | the pid set citation verification checks membership against | passage-contract.md §4.3 DDL, §7.2 C2 |
| `sections[]` | FR-011 navigable chapter structure (`id`, `title`, `first_pid`, `t_start_s`) | http-api.md §3.3 |
| `content_hash`, `minted_at`, `ingest_run` | change detection and identifier provenance | passage-contract.md §4.2 |

## Deliberately out of the model

Unlike the section above, these have **no** authoritative location — they are absent by decision.

- **User accounts and permissions** — decision D1 makes this single-user and local.
- **Direct audio/video embeddings** — Lumen cannot index media (D-SEARCH-3); media is reached
  through transcripts. Stated rather than implied.
- **Distributed or multi-writer state** — single machine, single writer.
