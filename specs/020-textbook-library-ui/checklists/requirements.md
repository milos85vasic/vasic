# Specification Quality Checklist: Textbook Library UI and Deterministic Textbook Ingestion

**Purpose**: validate completeness before execution | **Created**: 2026-10-20 | **Feature**: [spec.md](../spec.md)

## Content Quality
- [x] Anchored on the operator's observed gap (books not in corpus, not visible, citations unusable), with measured baseline rows (B1-B14)
- [x] Mandatory sections complete; no book text or private content quoted (paths, counts, hashes, page numbers only)

## Requirement Completeness
- [x] No `[NEEDS CLARIFICATION]`; D-LIC is operator-given; D-PDF, D-DIAG, D-EMB, D-SVG, D-TITLES carry stated defaults and `OPEN` markers
- [x] Every FR maps to tasks with named, independent oracles (Python golden, kernel trace, listener log, sidecar page numbers)
- [x] Success criteria are measurable (counts, difference = 0, rc, 6/6 mutants)
- [x] Edge cases: scanned PDFs, stub pages, printed-vs-PDF page labels, filename-shape 410, missing figure file, embed-length truncation, duplicate titles
- [x] Scope bounded: no EPUB/FB2/DOCX, no OCR, no PDF/SVG serving, no searchable captions, no retrieval tuning, no 012/017 vocabulary reconciliation

## Feature Readiness
- [x] Ingestion procedure with licence basis `operator-directed 2026-10-20`, backup (§9), restamp, count verification, rollback rehearsal
- [x] **Hard guard** for zero LLM/ASR spend: three independent arms + six seeded mutants + rc 2 when unobservable (T019-T021, T032)
- [x] `/textbooks` list, citations (book, section, PDF page, opens the page), section browsing, figures — each with UI-visible acceptance (T042, T054, T060, T068, T073)
- [x] Live verification scripts with `result.json` + sha256 manifest and a paired negative (T031, T072); reviews (T016, T021, T040, T053, T067, T080, T082); manual + 3 guides + FAQ + 4 diagram classes
- [x] Shared-file edits limited to orchestrator hook lines; no `domain.go`, `service.go`, `main.go` body edits

## Notes
- UNCONFIRMED carried as tasks: hook-split state (T002), tool classification incl. `bench-retrieval.sh` (T003), filename-shape page count under the extractor's own per-page text (T005), isolation mechanism (T006),
  diagram counts for two books (T023), slug names of 017's scratch run (T004), whether a search-page facet for `content_type` exists (T045).
