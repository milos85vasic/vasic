# Quickstart: Textbook Library UI and Deterministic Textbook Ingestion

**Feature**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)

Validation scenarios, not the test suite. Run from `workshop/` of the **primary** checkout; real-PDF and live steps are orchestrator-only. Token via `scripts/_live_auth.sh`; never printed. **No scenario prints
book text; checks print counts, page numbers, hashes and ids.**

## Prerequisites

`books.json` written with the operator's display titles and the licence string `operator-directed 2026-10-20`; spec 019 tools present for live steps; isolation tool chosen (T006).

## Scenario 1 — extract and prove determinism (US1)

```bash
bash scripts/ingest-textbooks.sh --extract            # 3 books, run twice; prints {pages, sections, failures, sha256 equal?}
# expected sections 179 / 513 / 983 (re-derive); rc 0; "determinism: equal"
```

## Scenario 2 — dry run on a copy, rows only (US1)

```bash
bash scripts/ingest-textbooks.sh --dry-run            # rows +N, changed_existing_rows 0, second run 0/0, filename_shape_rows 3?, pages_over_embed_limit …
```

## Scenario 3 — the model-free guard (US1)

```bash
bash scripts/ingest-textbooks.guard.test.sh           # arms A/B/C -> model_calls=0 ; rc 2 if no tracer/namespace
bash platform/gates/prove-textbook-ingest-model-free-mutation.sh   # 6 mutants -> all caught
```

## Scenario 4 — go live (US1, orchestrator, after the operator's go)

`deploy-gate.sh --pre` → `ingest-textbooks.sh --apply` → `restart.sh --require-verdict` → `deploy-gate.sh --post` → `evidence/020-<run>/live-ingest.sh` (result.json + manifest).

## Scenario 5 — what the operator sees (US2-US5)

1. Sign in → **Textbooks**: three books, "License basis: operator-directed 2026-10-20", sections, figures, pages.
2. Search a concept from one book → the hit reads **book · section · PDF page N** → click → the page opens with its text and previous/next.
3. Open a book → chapter outline → open a chapter → open a section.
4. Open **Figures** → captions, quality badges, honest redraw notes → open a figure's page.
5. A page whose text trips the file-name guard says so in plain words and still navigates.

## Scenario 6 — reversibility

`promote-registry.sh --rollback <run>` (isolated server first, then live only on the operator's say) → textbook hits vanish after restart; `deploy-gate.sh --post` still PASS for the restored state.
