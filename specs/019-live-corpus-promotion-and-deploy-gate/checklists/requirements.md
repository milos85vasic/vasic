# Specification Quality Checklist: Live Corpus Promotion and Deploy Gate

**Purpose**: validate completeness before execution | **Created**: 2026-10-20 | **Feature**: [spec.md](../spec.md)

## Content Quality
- [x] Anchored on the operator's observed gap (built != served), with measured baseline rows
- [x] Mandatory sections complete; no private content quoted (hashes, paths, counts only)

## Requirement Completeness
- [x] No `[NEEDS CLARIFICATION]`; decisions D1-D5 carry stated defaults and `OPEN` markers
- [x] Every FR maps to a task with a named oracle in `tasks.md`; oracles are independent of the producer
- [x] Success criteria measurable (hash equality, 404 counts, rc, counts) and verified by named tasks
- [x] Edge cases: docs-only commits, racing promotions, pinned bind mounts, non-reproducible build, old tabs, secrets in evidence
- [x] Scope bounded: no canary (latent, §11.4.265), no `build.sh` edit, no role model

## Feature Readiness
- [x] (a) rebuild, (b) commit==HEAD, (c) bundle hash, (d) registry digest host-vs-container, (e) /status facts, (f) safe registry promotion — each has a story and tasks
- [x] RED baseline on the broken artefact (T027) before any promotion
- [x] Live verification (`result.json` + sha256 manifest), UI-visible acceptance (T020, T051), reviews (T012, T017, T026, T036, T041, T058, T060), docs + 4 diagram classes
- [x] Shared-file edits limited to orchestrator hook lines, plus one reviewed flag on `restart.sh`

## Notes
- UNCONFIRMED carried as tasks: hook-split state (T002), serving assumptions (T003), build reproducibility (T004), whether `HEAD`'s differences touch the compiled inputs (T001/T022), search availability during boot (T043).
