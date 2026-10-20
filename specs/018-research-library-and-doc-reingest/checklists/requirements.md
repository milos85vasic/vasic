# Specification Quality Checklist: Research Library and Research-Document Re-ingestion

**Purpose**: validate completeness before execution | **Created**: 2026-10-20 | **Feature**: [spec.md](../spec.md)

## Content Quality
- [x] Written around the operator's observed gap (cannot see research), not around a framework
- [x] Mandatory sections completed (stories, FRs, SCs, assumptions)
- [x] No private content quoted (paths and counts only)

## Requirement Completeness
- [x] No `[NEEDS CLARIFICATION]` markers; three operator decisions carry a stated default and are marked `OPEN`
- [x] Every FR is testable and has a task with a named oracle in `tasks.md`
- [x] Success criteria are measurable (counts, rc, HTTP status) and tied to a verifying task
- [x] Edge cases cover traversal, symlinks, binary files, stale sidecars, redaction, empty files
- [x] Scope bounded: library for `docs/research` only; textbooks (020), promotion (019), answering out of scope

## Feature Readiness
- [x] Acceptance scenarios per story; UI-visible acceptance step T045 present
- [x] Test-first, mutation proof, live evidence (result.json + sha256), review and docs tasks present
- [x] Hooks into shared files are named and orchestrator-owned (architecture.md §2.2)
- [x] §11.4.257 manual + guides + FAQ and §11.4.258 four diagram classes are tasks, not intentions

## Notes
- UNCONFIRMED items carried as tasks: hook-split landing state (T002), `guardStatic` on binary/HTML/PDF (T003),
  `/section/research` live behaviour (T003), which `pid:` occurrences in the ingestion-architecture doc are anchors (T001).
