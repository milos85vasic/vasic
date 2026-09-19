# Design: Exhaustive HelixQA Coverage — Workshop Meeting-Notes Pipeline

**Status**: Approved in chat 2026-09-19 (operator: "all, one by one, subagents
driven"). Eighth and final of 8 planned sub-projects.

## This sub-project is architecturally different from the other 7

Every other sub-project targets an HTTP surface via `helixqa http`. This
pipeline (`pipeline/extract/meeting_notes.py`, `meeting_notes_pdf.py`) has
**no HTTP entry point at all** — confirmed by the research (grep across
`internal/api/*.go`/`main.go` for `ingest|reindex|rebuild|admin` finds
nothing). It is a batch, CLI-invoked Python stage. `helixqa http` cannot
exercise it directly. This design follows the research's own explicit
recommendation rather than forcing a fit: a **scratch-registry
pipeline-invocation harness**, not a `helixqa http` bank — the deliverable
for this sub-project is a shell/pytest-adjacent script, not a `.yaml` bank
file, and that is a deliberate, documented departure from the other 7's
shape, not an oversight.

## The research's headline finding is now RESOLVED, not merely flagged

The research (written before this session's own meeting-notes fix) found
that chapter 01's served corpus had never been regenerated with the
PDF-sourced extraction, despite the feature being real, committed, and
unit-tested. **This was independently investigated, fixed, and verified
earlier in this session** (workshop commit `6a33a7f`, closing a false-"DONE"
claim in `docs/work-register.md` R26) — chapter 01 now has 9 real,
PDF-sourced rows, live-verified via the API. This design does not need to
re-fix that; it needs to build the STANDING REGRESSION GUARD that would
have caught the gap being introduced in the first place, and would catch it
recurring (e.g., if the pipeline is re-run with a code regression that
silently reverts to transcript-sourcing, or a future chapter's PDF is added
but never processed against the real registry).

## Scope of this sub-project

A scratch-registry test harness, `scripts/prove-meeting-notes-pipeline.sh`
(or `pipeline/extract/`-local equivalent — decide the exact location during
Task 1 based on where this codebase's own established scratch-registry
convention lives, per `quickstart.md`'s Scenario 1/2/3 pattern), that:

1. Runs the real `meeting_notes.run_chapter_meeting_notes` against a
   **scratch copy** of `curriculum/passages.jsonl` (never the live one) for
   a real chapter with a real notes PDF (chapter 01).
2. Asserts the scratch output's citations are `pdf_notes_section`-prefixed
   and `segments_processed == 0` (confirms the PDF path was taken, not the
   transcript fallback).
3. Confirms determinism: a second run against the same scratch state
   produces `minted_new == 0` and a byte-identical scratch registry.
4. **Asserts all THREE `apply_redaction_gate` call sites are still wired**
   (research §3/§4's own flagged regression class — the transcript path,
   the PDF path with `check_pii=True`, and the merged-question second pass)
   — not just that the gate function itself works in isolation, which the
   existing pytest suite already proves. This is the single highest-value
   case in this harness: a regression removing any ONE of the three
   call-sites has already happened once (the Phase 5 review fix closed
   exactly this class of gap) and none of the existing tests assert "all
   three sites are still called," only that the function works when called.
5. Diffs the scratch registry's OTHER chapters against the pre-run copy to
   prove zero regression (mirrors SC-003/SC-006 — a chapter-01 PDF run must
   not touch chapter 02/02.01/02.02's rows).
6. A synthetic-roster regression case: add a fake name to a SCRATCH COPY of
   `curriculum/non-owner-participants.txt` (never the real file), confirm
   the matcher withholds content containing it, remove it, confirm restored
   — a standing regression guard distinct from the real roster's own
   (currently zero-match) content, per the research's own suggestion.

## Explicitly NOT built by this sub-project (a real decision, not an oversight)

**The research names a second, more ambitious option (its own "option 3"):
a two-stage design where a real pipeline run against the LIVE registry is
immediately followed by a `helixqa http` check against the existing
`chapter-detail-content.yaml` bank's routes, proving producer-to-API
propagation end-to-end.** This would be the FIRST state-mutating bank in
this entire fleet (every other sub-project's bank is read-only against a
stable, already-seeded corpus) and the research itself says this deserves
its own explicit go/no-go, not silent inclusion. This design does NOT build
it — it is named here as a recommended FUTURE decision for the operator,
separate from this sub-project's completion. This sub-project's own scratch-
registry harness (above) is the complete, safe deliverable.

## The `extraction_failed` wire-visibility gap (research §5)

The research found `extraction_failed_pdfs` (a real, honest failure signal
inside the Python pipeline result) does not appear to reach any served HTTP
response — a chapter with a corrupt PDF would report identically to a
chapter with no PDF at all (`unwritten`), losing FR-009's own "never
silently downgrades to unwritten" guarantee at the point a real user could
observe it. **Task 3 of this sub-project's implementation plan must
investigate this as a real candidate finding** (confirm with the Go side
whether this is intentional or a genuine gap) with the same
systematic-debugging rigor the T508 finding received — not simply restated
as a research note.

## Testing discipline

Every assertion in the harness needs a golden-bad control: temporarily
comment out one of the three redaction-gate call sites, confirm the harness
genuinely catches it (a withheld item that should have `[REDACTED]` text
instead shows real content), restore, confirm clean again. This mirrors the
Phase 5 review fix's own real regression, made into a standing, automated
guard.

## Assumptions

- This harness operates ONLY against scratch copies of `curriculum/passages.jsonl`
  and `curriculum/non-owner-participants.txt` — it NEVER mutates the real,
  live-served registry (unlike this session's earlier meeting-notes fix,
  which was a deliberate, one-time, independently-verified, operator-scale
  correction — this harness is a repeatable regression GUARD, a different
  kind of artifact, and must never repeat that kind of mutation
  automatically).
- `PYTHONPATH=".:pipeline/extract" pipeline/venv/bin/python` is required for
  this pipeline's own tests/scripts to run, per the established convention.
- This sub-project's harness is wired into `workshop`'s own test/gate
  aggregation (`scripts/verify.sh` or the pytest suite itself, whichever the
  implementer determines is the established pattern for a new
  pipeline-level proof — read `platform/gates/`'s existing `verify-*.sh`
  naming convention before deciding) — NOT into `verify-helixqa-web.sh`,
  since this harness never invokes `helixqa` at all.
