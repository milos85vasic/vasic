# Data Model — Workshop Curriculum Platform

**Feature**: `specs/001-workshop-curriculum-platform` | **Date**: 2026-09-01
**Derived from**: [spec.md](./spec.md) Key Entities, constrained by [research.md](./research.md)

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
| `state` | enum | `building` \| `verified` \| `live` \| `superseded` |
| `pid_count` | int | verification gate input |

**Rules**: only a `verified` generation may become `live`, by atomic swap. Readers never see
`building` — measured necessity: during the live rebuild, `chunks` moved while
`last_indexed_at` still advertised the previous generation, i.e. a half-written readable index.

### Answer

| Field | Type | Notes |
|---|---|---|
| `question` | string | |
| `verdict` | enum | `answered` \| `refused` \| `unavailable` |
| `text` | string? | present only when `answered` |
| `citations` | []ULID | **≥1 when `answered`**, enforced by schema |
| `refusal_reason` | enum? | `below_threshold` \| `margin_too_small` \| `unsupported` \| `no_provider` |
| `retrieval` | RetrievalTrace | top score and margin, recorded even on success |

**Rules**: `answered` with zero citations is structurally undecodable (`minItems: 1`). Every
citation MUST be a member of the live generation's PID set — a deterministic check, and the reason
SC-009 is reachable at all. `retrieval` is stored even on success so a 0.002-margin pass is
visible as *fragile* rather than indistinguishable from a confident one.

`unavailable` is a first-class third state, distinct from `refused`. Conflating them would make a
missing provider look like a content gap — the Honest Instruments principle applied to the domain.

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
| `refused` ≠ `unavailable` | FR-022, FR-025, SC-010 |
| only `verified` generations serve | FR-020 |
| re-ingest is idempotent on `pid` | FR-027 |

## Deliberately out of the model

- **User accounts and permissions** — decision D1 makes this single-user and local.
- **Direct audio/video embeddings** — Lumen cannot index media (D-SEARCH-3); media is reached
  through transcripts. Stated rather than implied.
- **Distributed or multi-writer state** — single machine, single writer.
