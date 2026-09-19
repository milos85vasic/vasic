# Workshop Meeting-Notes Pipeline — Exhaustive QA Coverage Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A standing, repeatable, scratch-registry regression guard for the meeting-notes PDF-sourcing pipeline's three redaction-gate call sites and its determinism/regression-safety properties — NOT a `helixqa http` bank (this pipeline has no HTTP surface) — plus a real investigation of the `extraction_failed` wire-visibility gap, with any real bug found root-caused and TDD-fixed.

**Architecture:** A shell/pytest-adjacent script that runs the real `meeting_notes.run_chapter_meeting_notes` against SCRATCH copies of `curriculum/passages.jsonl` and `curriculum/non-owner-participants.txt` — never the live, served registry. This is the 8th and final sub-project, and it is architecturally different from the other 7 by design (see the spec's own explanation).

**Tech Stack:** Python (`pipeline/extract/`, via `PYTHONPATH=".:pipeline/extract" pipeline/venv/bin/python`), pytest, shell.

**Spec:** [docs/superpowers/specs/2026-09-19-workshop-meeting-notes-pipeline-qa-design.md](../specs/2026-09-19-workshop-meeting-notes-pipeline-qa-design.md)

## Global Constraints

- **This harness NEVER mutates the real, live-served `curriculum/passages.jsonl` or `curriculum/non-owner-participants.txt`.** Every assertion operates against a scratch copy, per `quickstart.md`'s own established convention (already used by this session's earlier, deliberate, one-time, operator-scale chapter-01 fix — this harness is a different, repeatable-by-design artifact and must not repeat that kind of live mutation automatically).
- **Do NOT build the "option 3" two-stage live-mutating end-to-end design** the research names (real pipeline run against the live registry, immediately followed by a `helixqa http` check) — the research and design doc both explicitly flag this as a separate, future, operator-level go/no-go decision, not part of this sub-project's scope. If you find yourself wanting to build it, stop and report the recommendation instead of building it.
- This pipeline's tests require `PYTHONPATH=".:pipeline/extract" pipeline/venv/bin/python -m pytest ...` to even collect.
- Every assertion needs a real golden-bad control (temporarily break one of the three redaction-gate call sites or the roster matcher, confirm the harness catches it, restore, confirm clean).
- Any real bug found triggers a full `systematic-debugging` root-cause pass and a TDD fix.
- workshop is a private repo; implementers commit locally, never push.
- **Priority mandatory investigation**: the `extraction_failed` state (a real, honest Python-side failure signal) appears not to reach any served HTTP response — Task 2 MUST investigate this with the Go side (read `session_sections.go`/`sessionrecord.go` again) and determine whether this is intentional or a genuine gap, not merely restate the research's finding.

---

### Task 1: Write the scratch-registry pipeline-invocation harness

**Files:**
- Create: the harness itself — decide the exact location/name during this task (a candidate: `pipeline/extract/test_meeting_notes_pipeline_integrity.py`, if this codebase's convention favors a pytest-based regression guard over a standalone `platform/gates/verify-*.sh` shell script, given this is a Python-only, non-HTTP surface unlike every other `verify-*.sh` gate in that directory which targets the Go server; read a few of `pipeline/extract/`'s existing `test_*.py` files' own conventions for scratch-registry setup/teardown before deciding, and state your reasoning in your report rather than guessing).

- [ ] **Step 1: Confirm your understanding of the real invocation signature** — `meeting_notes.run_chapter_meeting_notes(chapter, passages, out_dir, sync_fn, registry_path, chapters_root=...)`, per `quickstart.md`'s own corrected note (an earlier revision of that doc had a wrong invocation pattern — read the "Correction history" note in it before trusting any example there at face value). Confirm this signature against the real function definition in `meeting_notes.py`.

- [ ] **Step 2: Build the scratch-registry setup** — copy `curriculum/passages.jsonl` to a scratch location (mirroring `quickstart.md`'s Scenario 1/2's own established scratch-copy convention — read exactly how the existing tests/quickstart do this and reuse the same mechanism, don't invent a new one).

- [ ] **Step 3: Write the PDF-sourcing determinism + citation-format assertions** — run `run_chapter_meeting_notes` for chapter 01 (which has a real notes PDF) against the scratch copy; assert citations are `pdf_notes_section`-prefixed and `segments_processed == 0`; run it again against the same scratch state and assert `minted_new == 0` and a byte-identical scratch registry.

- [ ] **Step 4: Write the three-redaction-gate-call-sites assertion** — this is the highest-value case in this harness. Read `meeting_notes.py:632-694`/`846-902`/`899-902`/`923` (the three real call sites named in the spec) and construct a test that would FAIL if any ONE of the three were removed — e.g., inject a synthetic roster name into a scratch copy of `curriculum/non-owner-participants.txt`, construct or use fixture content that would trigger each of the three paths (transcript-direct, PDF-with-PII-check, merged-question second-pass) containing that name, run the real extraction, and assert all three paths correctly withhold it. This likely needs synthetic/fixture chapter content rather than the real chapter 01 PDF (which the research found the real roster currently has zero matches against) — read `test_meeting_notes.py`'s own existing `TestRedactionGateAnswerTextRegression` (the Phase 5 review fix's own regression test) for the established fixture-construction pattern and reuse it rather than inventing one.

- [ ] **Step 5: Write the cross-chapter-regression-safety assertion** — running the chapter-01 PDF extraction against the scratch registry must not change any OTHER chapter's rows; diff the scratch registry's other chapters against the pre-run copy and assert zero difference.

- [ ] **Step 6: Write the synthetic-roster golden-bad regression guard** (design doc case 6) — add a fake name to a SCRATCH COPY of the roster file, confirm content containing it is withheld, remove it, confirm restored (and confirm the harness's own earlier assertions, run again, are unaffected — proving this addition didn't leave scratch-file state bleeding between cases).

- [ ] **Step 7: Run the full harness, capture real output for every assertion**, including at least one deliberately-broken run per assertion (comment out one redaction-gate call site, confirm the harness genuinely fails; restore, confirm clean) as the golden-bad evidence.

- [ ] **Step 8: Commit** (own files only, never pushed; never touching the real `curriculum/passages.jsonl` or `curriculum/non-owner-participants.txt`).

---

### Task 2: Wire the harness into workshop's test/gate aggregation, and investigate `extraction_failed`

**Files:**
- Modify: wherever the implementer determines is the established entry point (read `scripts/verify.sh` and the `pipeline/extract/` test-running convention first — this may already be covered if the harness is a `test_*.py` file picked up by the existing `pytest pipeline/extract/` sweep, in which case "wiring" may require zero changes; state this explicitly either way).

- [ ] **Step 1: Confirm the harness runs as part of the existing `PYTHONPATH=".:pipeline/extract" pipeline/venv/bin/python -m pytest pipeline/extract/ -q` sweep**, or explicitly wire it in if it doesn't (e.g., a new named target, or documentation of how to invoke it, matching this codebase's own conventions).

- [ ] **Step 2: Investigate the `extraction_failed` wire-visibility gap.** Read `platform/backend/internal/api/session_sections.go` and `pkg/sessionrecord/sessionrecord.go`'s `finish()` (the three-state description the existing `chapter-detail-content.yaml` bank's own header already documents) to confirm whether a fourth state genuinely cannot be represented, or whether there's an existing-but-unused mechanism. Determine: is this intentional (an operator-only diagnostic surfaced elsewhere, e.g. in logs or a separate admin view) or a genuine, unaddressed gap between the pipeline's own honest failure reporting and what a reader of the live site can observe?

- [ ] **Step 3: If a genuine gap, propose and implement a minimal fix with TDD** — likely surfacing `extraction_failed` as a real, distinguishable state at the API layer (a new enum member, or a distinguishing field alongside the existing `unwritten`) rather than silently collapsing it. If this would require a larger architectural change than fits this plan's scope, STOP and report the finding with a proposed design instead of forcing an invasive change — matching this session's own established discipline for exactly this kind of decision (see the G5 fix's own precedent, where the implementer correctly stopped rather than forcing a larger fix).

- [ ] **Step 4: If intentional, document why explicitly** (with evidence — e.g., a log line, an admin-only surface) rather than merely asserting it's fine.

- [ ] **Step 5: Commit** (own files only, never pushed).

---

### Task 3: Triage and root-cause any other real findings

- [ ] **Step 1: Collect every assertion that did not behave as expected during Task 1/2's own real runs.**
- [ ] **Step 2: For each real finding, invoke `systematic-debugging`'s full Phase 1-4 process.**
- [ ] **Step 3: Fix each real finding with TDD.**
- [ ] **Step 4: Re-run the full harness** after each fix.
- [ ] **Step 5: If zero real findings surfaced beyond Task 2's `extraction_failed` investigation**, state that explicitly.
- [ ] **Step 6: Commit each fix separately**, never pushed.
