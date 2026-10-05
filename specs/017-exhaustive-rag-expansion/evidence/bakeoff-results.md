# Embedding model bake-off results (FR-016, T045)

**Date**: 2026-10-05. **Mechanism**: `search.IndexVectors`/`cmd/index-embed`'s existing code path
(`embed.NewOllama` + `search.NewSemantic`), driven from a temporary scratch Go program
(`cmd/zzscratchbakeoff`, deleted after this run — not committed) rather than hand-invoking
`cmd/index-embed` four times, because the evaluation harness (query set + recall/MRR scoring)
needed to run inside the same process as retrieval. No change to any live/served generation: each
candidate was embedded into its own throwaway SQLite file under a scratch directory, since
deleted.

**`evaluated_on`** (every row below, per data-model.md §5's non-empty-population requirement):
692 real `textbook_section` passages from two real files in `workshop/textbooks/ai_001/`
(`OpenAI_API_Cookbook_-_Henry_Habib.pdf`, 179 sections; `LLM Engineers's Handbook.pdf`, 513
sections), extracted via the real `pdf_textbook_sections.py` and ingested via the real
`ingest-transcript` binary — no synthetic or mocked content.

**Evaluation query set and metric** (defined here, as `plan.md`'s Procedure contract leaves to
task-breakdown time): 12 real "known-item search" queries. Each query is an 8-word window drawn
from the middle of one deterministically-sampled real section's own text (seeded random sample,
`seed=42`, over the 623 candidate sections with 600–3000 chars); the query's ground truth is that
specific section's own minted pid. This is a REAL, defensible IR technique (the query shares
vocabulary with its target passage but is not the passage's full text), but it is NOT a
substitute for real user-query evaluation — see Honest Limitations below. Metric: **recall@5**
(fraction of the 12 queries whose expected pid appears in the top 5 results) and **MRR**
(mean reciprocal rank of the expected pid, 0 if absent from the top 5).

## BakeoffResult rows (data-model.md §5)

| model_name | generation | evaluated_on | metric_name | metric_value | license | calibrated |
|---|---|---|---|---|---|---|
| `nomic-embed-text` | 1 (scratch) | 692 textbook_section passages, 2 real files | recall@5 | **0.500** (6/12) | Apache 2.0 — verified via `ollama show nomic-embed-text --license` | false |
| `BGE-M3` (`bge-m3:latest`) | 1 (scratch) | 692 textbook_section passages, 2 real files | recall@5 | **0.500** (6/12) | MIT — verified via `ollama show bge-m3:latest --license` | false |
| `jina-embeddings-code-cpu` (`ordis/jina-embeddings-v2-base-code`, **current live default**) | 1 (scratch) | 692 textbook_section passages, 2 real files | recall@5 | **0.417** (5/12) | Apache 2.0 — verified via `ollama show ordis/jina-embeddings-v2-base-code --license` | false |
| `Qwen3-Embedding-0.6B` (`qwen3-embedding:0.6b`) | 1 (scratch) | 692 textbook_section passages, 2 real files | recall@5 | **0.417** (5/12) | Apache 2.0 — verified via a fresh web search against the upstream Hugging Face model card (`Qwen/Qwen3-Embedding-0.6B`); **NOT** present in this Ollama tag's own Modelfile (`ollama show qwen3-embedding:0.6b --license` returns empty — the pull carries no embedded LICENSE block, unlike the other three candidates where the local Ollama metadata itself carries the license text) | false |

Secondary metric (MRR, not in data-model.md's schema but recorded for context since it
differentiates two models tied on recall@5):

| model | MRR |
|---|---|
| `BGE-M3` | 0.403 |
| `nomic-embed-text` | 0.392 |
| `Qwen3-Embedding-0.6B` | 0.264 |
| `jina-embeddings-code-cpu` (current default) | 0.183 |

## Honest limitations (§11.4.6) — read before acting on this table

1. **N=12 is small.** This is enough to rank-order four candidates under one fixed methodology,
   not enough to bound a confidence interval or detect a difference smaller than roughly one
   query's weight (±8 percentage points of recall@5 per query). Do not quote these absolute
   numbers outside this document.
2. **The query-construction method likely inflates every model's score roughly uniformly**,
   because each query shares literal vocabulary with its target passage (a window of the
   passage's own words) rather than being an independently-phrased user question. This makes the
   RELATIVE ranking between models (all evaluated under the identical method) more trustworthy
   than the ABSOLUTE recall@5/MRR values, which should not be read as "a real user would find the
   right passage half the time."
3. **One candidate's query set overlaps its own live default more than the others by
   construction**: none — all four were scored against the IDENTICAL 12-query set, so this
   limitation does not apply differentially; noted only to rule it out explicitly.
4. **This is a single run, not repeated.** `nomic-embed-text` and `BGE-M3` tie exactly on
   recall@5 (0.500) and differ only on the secondary MRR metric; a second independent query
   sample could plausibly reorder them. The result that is NOT fragile to this: both clearly
   outperform the current live default (`jina-embeddings-code-cpu`) on both metrics in this run.

## Decision contract (per `contracts/embedding-bakeoff-contract.md`)

**No default-model switch is approved by this bake-off**, and none is being proposed as an
automatic consequence of this result — the contract is explicit that a switch is a separate,
human-approved decision requiring its own `calibratedFloor` recalibration (`cmd/workshop-server`'s
existing floor of 0.655 is hardcoded to `nomic-embed-text` at a specific historical corpus size
and does not transfer by inference to a different model or corpus size). **The measured signal
worth recording for that future decision**: both `nomic-embed-text` and `BGE-M3` measured ahead of
the current default on this small real sample, on both metrics. Per `§11.4.6`'s no-guessing
discipline, "we measured a signal favoring two alternatives and did not switch" is itself the
reportable outcome of T046 — not a null result to omit.
