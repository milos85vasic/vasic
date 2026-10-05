# Contract: Embedding Model Bake-off

**Implements**: FR-016 | **Mechanism**: `cmd/index-embed`, existing and unchanged
(research.md §3, §4)

## Procedure contract

```text
For each candidate model in {jina-embeddings-code-cpu, nomic-embed-text, Qwen3-Embedding-0.6B, BGE-M3}:

  1. index-embed -db <db> -generation -1 -ollama <url> -embed-model <candidate>
       -embed-doc-prefix <candidate-appropriate prefix>
     -> produces a NEW generation, isolated from every other candidate's generation and from the
        live-serving generation. NO candidate's embedding run is permitted to touch the generation
        `cmd/workshop-server` currently reads for live queries (plan.md's "zero live-service risk"
        framing from research.md §3).

  2. Run the fixed textbook/prose evaluation query set (defined at task-breakdown time, not here)
     against each candidate's generation, computing the metric recorded in
     data-model.md §5's BakeoffResult.metric_name/value.

  3. Record one BakeoffResult row per candidate, with evaluated_on stating the exact population
     (e.g. "N textbook_section passages from workshop/textbooks/ai_001/") — never left implicit.
```

## Decision contract

A model switch (changing `cmd/workshop-server`'s `-embed-model` default) is a **separate,
explicit, human-approved decision** following the bake-off, never an automatic consequence of a
BakeoffResult showing a higher metric for a non-default candidate. This contract does not grant
authority to switch the default — it only produces the evidence a human decision would use. If a
switch is approved, it requires its OWN calibration pass for `calibratedFloor`
(`cmd/workshop-server/main.go`), because that function's existing calibration (floor 0.655) is
hardcoded to `nomic-embed-text` at an exact historical corpus size (2478 PIDs) and does not
transfer to a different model or a different corpus size by inference.

## License contract

Every candidate's `license` field (data-model.md §5) MUST be independently re-verified at
bake-off time, not assumed from this document's table in `research.md` §3 — license terms for a
hosted model can change between when research recorded them and when the bake-off actually runs.
