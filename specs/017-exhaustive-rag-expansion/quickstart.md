# Quickstart: Exhaustive RAG Expansion + Textbook Ingestion + Jordan Correction

**Feature**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)

Runnable validation scenarios proving each user story end-to-end. These are **validation
scenarios**, not the test suite itself — full unit/contract tests belong to `tasks.md` and the
implementation phase (see `plan.md`'s TDD Requirements).

## Prerequisites

- `workshop` submodule checked out, platform container buildable (`podman`/`compose`, as already
  documented in the umbrella root's `CLAUDE.md` "Host capability" section).
- `llama-server` built and reachable, serving `bge-reranker-v2-m3-GGUF` on its `--reranking`
  endpoint (new prerequisite this feature introduces — not previously required).
- Ollama running with the current default embedding model available, plus the three bake-off
  candidate models pulled for User Story evidence (`ollama list` should show all four before
  running Scenario 5).
- At least one real PDF present under `workshop/textbooks/ai_001/` (already true per the feature's
  own premise).

## Scenario 1 — Textbook ingestion (User Story 1, P1)

```bash
# Step 1: extract
python3 workshop/pipeline/pdf_textbook_sections.py workshop/textbooks/ai_001/<file>.pdf \
  --out /tmp/ai_001-sidecar.json
echo "exit=$?"   # expect 0

# Step 2: ingest
workshop/platform/backend/bin/ingest-transcript -docs /tmp/ai_001-sidecar.json

# Step 3: embed (new generation, isolated)
workshop/platform/backend/bin/index-embed -db <db> -generation -1 \
  -ollama http://127.0.0.1:11434 -embed-model <current-default>
```

**Expected outcome**: a query naming a concept known to appear only in the ingested textbook
returns a `textbook_section` passage citing the correct chapter/section via its `LocationAnchor`,
through the EXISTING query path (`/api/suggest`) with no new query-side code required for a
read to succeed — FR-013's uniform-retrieval contract.

**Idempotency check**: re-run steps 1–2 against the SAME PDF. Expected: zero new passages
inserted (verify via a passage-count query before/after).

## Scenario 2 — Cross-encoder reranking (User Story 2, P2)

```bash
workshop/platform/backend/bin/reranker-probe   # expect exit 0 (backend ready)
```

Run a query known, from existing manual QA, to return a relevant-but-not-top-ranked document
under today's RRF+MMR ordering. **Expected**: with reranking enabled, that document moves toward
the top of the result set, and the response/log distinguishes `backend_status=ok` from any
fallback state (contract in `contracts/reranker-service-contract.md`).

**Two-sided regression check** (plan.md's Constitution Check row on this exact risk): run the same
query set used to validate today's KNOWN-GOOD top-1 answers (not only the known-bad ones
reranking is meant to fix). **Expected**: no regression — a top-1 answer that was already correct
stays correct after reranking is enabled.

**Fallback check (UPDATED 2026-10-05 per `/speckit-clarify` — three-tier, not two-tier)**:

1. With `llama-server` running, issue a query once so it is successfully reranked (`outcome =
   reranked_fresh`) and written through to `rerank_cache`.
2. Stop `llama-server`. Repeat the SAME query. **Expected**: `outcome = served_from_cache`, and
   the returned order matches step 1's result exactly (cache hit) — no error surfaced to the end
   user.
3. Stop `llama-server` and issue a DIFFERENT query never reranked before. **Expected**:
   `outcome = fallback_no_cache`, response is the pre-rerank order from `(*Service).fuse`
   (RRF-fused — corrected 2026-10-05, see `research.md` §0: MMR is not in this path), no error
   surfaced to the end user — Honest-Instruments contract, both failure branches covered.
4. **(NEW 2026-10-05)** With `WORKSHOP_SEARCH_WINDOW_RERANK=true` AND the new cross-encoder flag
   both set, confirm startup refuses rather than silently picking one — the two window-reorder
   modes are mutually exclusive (`plan.md` Constraints, corrected).

## Scenario 3 — Content-type-aware retrieval (User Story 3, P3)

Run a query scoped with the new content-type option to `textbook` only. **Expected**: results
contain only `textbook_section` passages. Run the same query unscoped. **Expected**: results span
multiple content types (uniform retrieval, FR-013), including the `textbook` passages that the
scoped query alone returned — proving the scoping is additive, not a default exclusion.

**Floor-domain-containment regression check**: re-run the nonsense-query probe documented in
`pkg/search/semantic.go`'s own existing comment (the query that previously returned `kg_term` rows
above the relevance floor). **Expected**: still correctly excluded under the generalized
content-type dimension — this is the named non-regression requirement from `data-model.md` §2.

## Scenario 4 — Incremental re-indexing (User Story 4, P4)

```bash
# Simulate adding a second textbook chapter after Scenario 1's content already served queries
python3 workshop/pipeline/pdf_textbook_sections.py workshop/textbooks/ai_001/<second-file>.pdf \
  --out /tmp/ai_001-sidecar-2.json
workshop/platform/backend/bin/ingest-transcript -docs /tmp/ai_001-sidecar-2.json
workshop/platform/backend/bin/index-embed -db <db> -generation -1 \
  -ollama http://127.0.0.1:11434 -embed-model <current-default>
```

**Expected**: the FIRST textbook's passages remain queryable and unaffected (no re-embed of
unrelated content triggered); a query targeting content unique to the SECOND file now also
succeeds. No full-corpus re-embed occurs (verify by generation count: exactly one new generation
created, not a regeneration of all prior generations).

## Scenario 5 — Embedding bake-off evidence (FR-016)

Run `contracts/embedding-bakeoff-contract.md`'s procedure for all four candidates. **Expected
artifact**: one `BakeoffResult` row per candidate (data-model.md §5), each with a non-empty
`evaluated_on` population description, committed to the task-breakdown's designated evidence
location (to be named in `tasks.md`) — not merely printed to a terminal and discarded, per this
project's standing "Machine-created evidence at every gate" principle.

## Scenario 6 — Jordan correction (User Story 5, P5) — content-boundary-respecting validation

This scenario is validated **without** reproducing any client-identifying content here:

```bash
# Run from inside the workshop submodule's own checkout, never from this public repo's tree:
grep -ril 'germany' workshop/docs/research/clients/ 2>/dev/null
# Expected AFTER correction: no output (directory renamed, references updated)

ls workshop/docs/research/clients/jordan/
# Expected: the corrected, Wave-2-augmented research document(s) present
```

**Boundary self-check** (mandatory before any push touching this story, per plan.md's Review
Gates):

```bash
cd "$(git rev-parse --show-toplevel)"
grep -riE '<replace with the actual private client/candidate identifiers from workshop/docs/research/clients/jordan/ at review time>' \
  specs/017-exhaustive-rag-expansion/ docs/ CONTINUATION.md 2>/dev/null
# Expected: zero matches, every time this story's commits are reviewed
```

**Expected outcome (SC-008)**: every newly-recorded Jordan-specific claim in the corrected
document cites the source that supports it — spot-checked by opening the corrected document
(inside the private submodule, never pasted here) and confirming each REQ-6-relevant claim has an
attached citation.
