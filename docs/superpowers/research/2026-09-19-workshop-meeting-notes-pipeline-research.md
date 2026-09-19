# Research: Workshop Meeting-Notes Extraction Pipeline (for future HelixQA brainstorming)

Read-only investigation, 2026-09-19. Input for a future HelixQA sub-project
covering the meeting-notes **extraction/minting pipeline** itself — a
different layer from the already-complete "chapter browsing & content"
sub-project, whose bank (`submodules/qa/banks/workshop/chapter-detail-content.yaml`,
17 cases) already exercises the four **read/serve** endpoints
(`GET /api/chapters/{chapter}/meeting-notes|open-questions|todo|next-meeting`)
end to end and is NOT duplicated here. This document covers the Python
producer that populates those endpoints' backing files, not the Go/Angular
surface that serves them. All paths relative to `workshop/` unless stated
otherwise (spec docs are at the umbrella root under `specs/`).

## 1. The feature this pipeline layer implements

`specs/009-meeting-notes-pdf-source/` (spec.md, plan.md, data-model.md,
contracts/pipeline-stage.md, quickstart.md, tasks.md) — "PDF-Sourced Meeting
Notes with Redaction Gate," created 2026-09-18. Four user stories: (1) a
chapter with a real notes PDF sources its meeting notes from the PDF,
authoritatively; (2) a transcript-only chapter is unaffected (regression
safety); (3) a chapter with neither PDF nor transcript gets a real ASR
transcript first (chapter 02.02); (4) no item is ever minted without passing
a redaction/disclosure check, closing a pre-existing gap.

**The feature is implemented and committed, not merely planned** — three real
commits landed in `workshop`, confirmed via `git log`:

| Commit | Subject |
|---|---|
| `d4e11c9` (2026-09-02, pre-dates spec 009) | `feat(knowledge): repeatable per-chapter meeting-notes extraction (T-MEETING-NOTES)` — the original transcript-only extractor |
| `0060dfe` (2026-09-18) | `feat(meeting-notes): PDF is authoritative source when provided (Phase 3, US1)` |
| `2bdc5c5` (2026-09-18) | `feat(009-meeting-notes-pdf-source): wire redaction gate into both meeting-notes sourcing paths (Phase 5, US4)` |
| `58e9238` (2026-09-18) | `fix(meeting-notes): gate answer_text — three ungated privacy-boundary paths (Phase 5 review fix)` |

`docs/work-register.md` row R26 records this as "DONE, fully closed," including
a claim that chapter 02.02 "was transcribed for real (ASR, 202 segments) and
now has real meeting-notes content (22 items)." **Section 6 below shows this
DONE claim needs a caveat the work register does not currently carry.**
`tasks.md`'s own checkboxes are all still unchecked (`- [ ]` throughout,
`specs/009-meeting-notes-pdf-source/tasks.md`) — the checkbox state is stale
relative to the actual commits; do not trust the checkbox column over the git
log.

## 2. The module layout

`pipeline/extract/meeting_notes.py` (996 lines) — the original transcript
extractor plus the FR-007/FR-008/FR-011 redaction gate (`apply_redaction_gate`,
`meeting_notes.py:632-694`) and the PDF-vs-transcript dispatch
(`run_chapter_meeting_notes`, `meeting_notes.py:798-995`, dispatch at
`meeting_notes.py:846-902`).

`pipeline/extract/meeting_notes_pdf.py` (218 lines, new) — PDF discovery
(`discover_notes_pdfs`, line 42), deterministic `pdftotext -layout` extraction
reusing `pipeline/transcribe/pdf_notes.py`'s `resolve_pdftotext()`/
`extract_pages()` (imported at `meeting_notes_pdf.py:21`, not reimplemented),
line-granularity section mining (`mine_pdf_sections`, line 96), and the
per-PDF driver `extract_from_pdf` (line 148) that wraps each section as a
`ChapterSegment` and calls `meeting_notes.py`'s own four extractors
**unchanged** — no parallel cue-phrase heuristic exists for PDF text.

`pipeline/extract/publication_policy.py` — the redaction gate's foundation.
`load_participant_roster(path)` (line 443) reads
`curriculum/non-owner-participants.txt` (one name/alias per line, `#`
comments); `is_publishable_content(text, roster)` (line 478) is the
publish/withhold predicate; `find_named_individuals` (line 470) does
exact, case-insensitive, whole-word/phrase matching. This module is
**unchanged** by spec 009 (its docstring at line 434 predates 009 and still
says "nothing outside it is wired to call `is_publishable_content`
automatically yet" — that sentence is now stale prose left over from before
009 wired it in; `meeting_notes.py:100` and `meeting_notes_pdf.py:37` both
import from it directly).

`pipeline/extract/minting.py` — the bridge to the Go minter
(`platform/backend/cmd/knowledge-mint`). `MEETING_NOTES_KINDS` (line 40:
`kg_next_point`, `kg_open_question`, `kg_meeting_note`, `kg_todo`) mint through
the same `sync_areas()` bridge as every other knowledge kind. `pdf_notes_section`
is **not** in `minting.ALL_KINDS` — it is a citation anchor the module builds
itself as a deterministic string (`f"pdf_notes_section:{path}:{index}"`,
`meeting_notes_pdf.py:139`), never a Go-registry-minted pid; the four `kg_*`
kinds are the only things this pipeline actually mints.

`pipeline/extract/run_pipeline.py` wires `run_meeting_notes_pipeline_stage`
(line 1320) into the default pipeline sweep (called at line 1461, gated only
by `--no-meeting-notes`, line 1566) — this stage runs over **every** chapter
`discover_chapters` finds, unconditionally, on a normal `run_pipeline.py`
invocation with no flags.

## 3. Redaction gate mechanics — the part the spec calls its own most important invariant

`apply_redaction_gate(items, roster, check_pii=False)`
(`meeting_notes.py:632-694`) is called from **three** places: the transcript
path directly (`meeting_notes.py:899-902`, `check_pii=False`), the PDF path
inside `extract_from_pdf` (`meeting_notes_pdf.py:206-209`, `check_pii=True`),
and a **second pass over merged questions** after
`merge_question_answers` (`meeting_notes.py:923`) — this third call exists
specifically because the Phase 5 review fix (`58e9238`) found that a prior
run's carried-forward `answer_text` (set by `apply_external_research_answer`,
or by a pre-fix write, or a hand-edited file) could reach the served output
ungated. **Three independent gating points for the same conceptual check is
itself worth testing** — a regression that removes any one of the three
re-opens a specific, already-once-real leak path (see §6).

Withheld-not-dropped: a failing item keeps its `citation_pid` (and, for a
question, its `ordinal`/`status`/`answer_*`) but has `text` (and/or
`answer_text`, independently) replaced with `taxonomy.WITHHELD_MARKER`
(`"[REDACTED]"`, `taxonomy.py:418`) and `redacted: True` stamped
(`meeting_notes.py:688-693`). This reuses the existing
`curriculum/disclosure-judgements.jsonl` reversible-ruling mechanism
unchanged (FR-010) — confirmed real: that file holds **1** row today, a
`"serve"` ruling from 2026-09-08 for a different (pre-009) flagged run, keyed
by `pid` with `reason_code: "withheld_only_run_judged_non_private"`.

FR-011's PII check is narrow by design and PDF-path-only:
`_EMAIL_PII_RE`/`_PHONE_PII_RE` (`meeting_notes.py:618-621`), invoked only via
`extract_from_pdf`'s `check_pii=True` (`meeting_notes_pdf.py:206-209`) — the
transcript path never calls it (`check_pii=False` at every transcript-path
call site).

**The roster (`curriculum/non-owner-participants.txt`) is populated but
small**: 20 lines total including header/comments, confirmed by direct read.
Per `docs/work-register.md` R26's own follow-up note, the matcher currently
finds **zero matches** across the "42 items these four chapters currently
extract" — a genuine, disclosed zero-finding, not an untested gate (the
module's unit tests separately prove the matcher fires on synthetic roster
names — see §4).

## 4. Existing test coverage — do not duplicate

Run exactly as the task brief for this research specified (confirmed working,
real output below):

```
cd workshop
PYTHONPATH=".:pipeline/extract" pipeline/venv/bin/python -m pytest pipeline/extract/test_meeting_notes_pdf.py -q
  16 passed in 0.58s
PYTHONPATH=".:pipeline/extract" pipeline/venv/bin/python -m pytest pipeline/extract/test_meeting_notes.py -q
  43 passed in 2.12s
PYTHONPATH=".:pipeline/extract" pipeline/venv/bin/python -m pytest pipeline/extract/ -q
  416 passed in 69.90s
```

`test_meeting_notes_pdf.py` (16 cases, new): PDF discovery (one/zero/multiple
matches — `TestDiscoverNotesPdf`), deterministic `pdftotext` extraction
(`TestExtractPdfText`), corrupt-PDF failure (`TestExtractionFailure` →
`PdfExtractionError`), line-granularity section mining including the page-break
non-section case (`TestMinePdfSections`), full four-kind extraction citing
`pdf_notes_section` + determinism (`TestExtractFromPdf`), two-PDF independent
processing with disjoint citation sets (`TestExtractFromPdfTwoPdfsIndependently`
— T011a, closing a speckit-analyze-found coverage gap), the redaction gate
including roster-name/email/phone withholding and the pass-through case
(`TestRedactionGate`), and the dispatch-level "corrupt PDF reports
extraction_failed and does NOT fall back to the transcript" integration case
(`TestDispatchWiring` — closes coverage gap E2, using a real transcript
fixture whose text would trip both a todo and a next-meeting cue if the
fallback were wrongly taken).

`test_meeting_notes.py` (43 cases, existing + extended): `TestRealBridgeMinting`
(`meeting_notes.py:507-599` region) proves against the **real**
`go run ./cmd/knowledge-mint` bridge on a scratch registry copy, not a stub —
`test_all_four_new_kinds_mint_and_are_idempotent` and
`test_end_to_end_chapter_run_is_idempotent_on_a_scratch_registry`.
`TestChapterWithoutNotesPdfMatchesDirectExtraction` (line 600) is the US2
regression proof — dispatch output equals direct extraction-function calls
when no PDF is present. `TestRedactionGateUnit`, `TestRedactionGateTranscriptPathRegression`,
and `TestRedactionGateAnswerTextRegression` (lines 744-994) are the transcript-path
gate tests, including the three specific `answer_text` leak paths the Phase 5
review fix closed (`answer_text` via `resolve_answers_in_chapter`, via
`apply_external_research_answer`, and via a carried-forward prior-run row).

`test_publication_policy.py` (33 test functions) covers the roster
loader/matcher in isolation — not meeting-notes-specific, do not re-derive
roster-matching edge cases in a meeting-notes bank; that module's own gate is
here.

**None of this is a HelixQA bank.** All of it is pytest, all of it runs the
real code paths (including a real Go bridge subprocess for the minting
proofs), and none of it is HTTP-observable. A future bank should target
observable pipeline OUTPUT (the JSONL files it writes, and/or what the
already-covered read API subsequently serves), not re-derive these unit-level
assertions.

## 5. State model and CLI/script entry points

There is **no HTTP entry point for this pipeline** — confirmed by grep across
`platform/backend/internal/api/*.go` and `main.go` for
`ingest|reindex|rebuild|admin`: nothing exists beyond an unrelated test name
(`TestGateTR5_TranscriptWithNoIngestedPassagesIsUnavailable`). This is a batch,
CLI-invoked Python stage, run via `pipeline/extract/run_pipeline.py` (no
`--stage`/`--chapter` flags — only `--no-resume`/`--no-author`/
`--no-meeting-notes`/`--author`/`--review`, per `quickstart.md`'s own
corrected note) or, per-chapter, via the real function signature
`meeting_notes.run_chapter_meeting_notes(chapter, passages, out_dir, sync_fn,
registry_path, chapters_root=...)` (confirmed real by direct read, matching
`quickstart.md`'s corrected invocation pattern — an earlier revision of that
doc called it with a bare chapter-id string, which is wrong; see
`quickstart.md`'s own "Correction history" note, itself a real, disclosed
prior mistake worth knowing about before trusting anything in that file at
face value).

`contracts/pipeline-stage.md` names four possible outcomes per chapter:
PDF-sourced, transcript-sourced, `"unwritten"` (neither exists), and
`"extraction_failed"` (PDF found but unreadable, new in this feature,
data-model.md's "State Transitions" section). The Go-side `state` enum
consumed by the read API (`pkg/sessionrecord`, per the existing
`chapter-detail-content.yaml` bank's own header) is `authored`/`empty`/
`unwritten` — **`extraction_failed` is a Python-pipeline-internal state
reported only in `ChapterMeetingNotesResult.extraction_failed_pdfs`
(`meeting_notes.py:791` field, `meeting_notes.py:992-994` construction) and in
`run_meeting_notes_stage`'s own log message
(`meeting_notes.py:1041-1044`); it does not appear to reach a served HTTP
response at all.** Confirmed by reading `session_sections.go`'s docstring
(`platform/backend/internal/api/session_sections.go:1-50`) and
`pkg/sessionrecord/sessionrecord.go`'s `finish()` three-state description
(per the existing bank's own header) — there is no fourth wire-level state.
**This is a real, worth-flagging gap**: an operator who provides a corrupt
notes PDF for a chapter would see that chapter silently report `"unwritten"`
at the API layer (zero items minted, same as if no PDF/transcript existed at
all) with no way to distinguish "nothing was ever provided" from "something
was provided and extraction failed" — exactly the ambiguity FR-009's own
"never silently downgrades to unwritten" language says must not happen,
except the guarantee is honored inside the Python result object and not
carried through to what a reader of the live site can observe.

`session_sections.go`'s `deriveSessionRecord` → `pkg/sessionrecord.Store.Derive`
reads the per-chapter `knowledge/*.jsonl` files directly via `os.ReadFile`
(`sessionrecord.go:383,406,421` — no `sync.Once`/cache observed at those call
sites), meaning a freshly pipeline-regenerated JSONL file is picked up on the
**next HTTP request with no server restart required** — relevant for
designing a two-stage test (§7).

## 6. Real, verified edge case: the served corpus does not yet reflect this feature

This is the single most important finding of this research, verified by
direct inspection rather than inferred from the spec or the work register.

**`curriculum/chapter-01/knowledge/*.jsonl` — the file the live
`GET /api/chapters/01/meeting-notes` (and `/todo`, `/next-meeting`,
`/open-questions`) endpoints actually serve today — has never been
regenerated since the PDF-sourcing feature landed.**

- `git log -1 -- curriculum/chapter-01/knowledge/meeting-notes.jsonl` returns
  `d4e11c9` (2026-09-02) — the **original, pre-PDF-sourcing** commit. Commits
  `0060dfe`/`2bdc5c5`/`58e9238` (2026-09-18, the actual feature) never
  touched it.
- Every `citation_pid` in `curriculum/chapter-01/knowledge/{meeting-notes,
  todos,next-meeting-points,open-questions}.jsonl` is a ULID
  (`transcript_segment`-style), confirmed by direct JSON parse of all four
  files: **0 of 70 total rows** cite a `pdf_notes_section` anchor.
- `grep -c '"kind": *"pdf_notes_section"' curriculum/passages.jsonl` → **0** —
  no `pdf_notes_section` passage has ever been minted into the real, served
  registry, anywhere, for any chapter.
- Yet chapter 01's real notes PDF genuinely exists and is discoverable:
  `chapters/01/Milos teaching Rami AI workflows - 2026_08_27 09_57 CEST -
  Notes by Gemini.PDF` is present on disk and matches
  `discover_notes_pdfs`'s pattern.

So: the code is real, committed, and unit-tested (16+43 passing tests,
including tests that run the real chapter-01-shaped extraction path against
synthetic fixtures). But **`run_pipeline.py` (or the per-chapter function)
has not actually been re-run against the real corpus since the feature
landed** — `quickstart.md`'s own Scenario 1 ("mints real content into the
served registry... run against a scratch copy first if you want to inspect
without committing to the real registry") documents exactly this two-mode
distinction, and the evidence shows only the scratch-copy mode was ever
exercised for chapter 01, never the real one.

**Chapter 02.02 (User Story 3) is the exception — it DID get applied for
real**: `curriculum/chapter-02.02/knowledge/*.jsonl` exist and total exactly
**22** rows (7 meeting-notes + 1 next-meeting-point + 2 open-questions + 12
todos) — matching `docs/work-register.md` R26's claim precisely. So US3's
"chapter 02.02 goes from raw video to real meeting notes" is genuinely,
verifiably true; US1's "chapter 01's real, currently-unused notes PDF is
processed" (SC-001, the feature's own P1 headline scenario) is **implemented
and tested but not yet applied** to what a real user of the live API
actually sees today.

**Implication for a future bank**: a HelixQA test that hits
`GET /api/chapters/01/meeting-notes` today and asserts a `pdf_notes_section`
citation would correctly FAIL, not because the feature is broken, but because
the pipeline has not been re-run against the real corpus. This is precisely
the kind of gap a black-box, real-invocation test is suited to catch that a
pytest suite (which always constructs its own scratch fixtures) structurally
cannot — the pytest suite proves the CODE works; nothing currently proves the
SERVED CORPUS reflects it. Recommend surfacing this to the operator (running
`run_pipeline.py` for real against chapter 01 is a one-line, low-risk fix)
rather than treating it as a design defect.

## 7. Is this surface HelixQA-applicable, and how

HelixQA (per the other three research docs' own framing) is normally an
`helixqa http`-driven, HTTP black-box tool. This pipeline has **no HTTP
surface of its own** (§5) — so a bank cannot exercise "the pipeline" through
`helixqa http` alone the way the search/ask/auth sub-projects can.

Three genuinely different options, none of them a forced fit:

1. **Out of scope for `helixqa http` in isolation.** The pipeline's own
   correctness (extraction, redaction, determinism) is already covered by a
   real, passing, 416-case pytest suite that exercises real fixtures and a
   real Go-bridge subprocess — re-deriving that as HTTP assertions would add
   nothing and cannot even reach the code (there is no route to hit).
2. **A shell-invocation-based approach for the parts pytest cannot reach
   because they need the REAL corpus, not a fixture** — specifically, closing
   the §6 gap. A bank-adjacent script that (a) runs
   `run_chapter_meeting_notes` for real against chapter 01's actual PDF
   against a **scratch copy** of `curriculum/passages.jsonl` (never the live
   one, per `quickstart.md`'s own established convention), (b) asserts the
   scratch output's citations are `pdf_notes_section`-prefixed and
   `segments_processed == 0`, and (c) diffs the scratch registry's other
   chapters against the pre-run copy to prove zero regression (SC-003/SC-006)
   is the honest, low-risk way to validate this — never against the real,
   served registry inside an automated bank (mutating what real users see is
   not what a test suite should do silently).
3. **A genuine two-stage HelixQA-compatible design for the propagation
   question specifically** (does a pipeline-produced change actually reach
   the API — the question §6 exists because nobody has yet answered it for
   real): stage one is a shell/subprocess step that runs the extraction
   against a scratch registry and then, deliberately and with explicit
   operator sign-off, against the real one; stage two is `helixqa http`
   against the **already-existing** `chapter-detail-content.yaml` bank's own
   target routes (`GET /api/chapters/01/meeting-notes` etc.), asserting the
   response now contains the new content. This reuses the existing, complete
   read-side bank as the oracle for a producer-side change rather than
   inventing new HTTP assertions — but it is a two-process (Python pipeline +
   Go server), state-mutating test, structurally different from every other
   bank in this fleet (which are read-only against a stable, already-seeded
   corpus), and should be flagged to the operator as such before being built,
   since it would be the first bank in this fleet to deliberately mutate the
   served corpus as part of routine test execution.

**Recommendation, stated plainly rather than left implicit**: option 2 (a
scratch-registry pipeline-invocation harness, not an HTTP bank) is the
correct primary vehicle for this sub-project. Option 3 is a real, valuable,
but structurally novel idea that should be its own explicit decision, not
folded into "the meeting-notes bank" as though it were the same kind of
artifact as the other seven sub-projects' banks.

## Files most relevant for the future brainstorm

- `pipeline/extract/meeting_notes.py` — `apply_redaction_gate` (632-694),
  `run_chapter_meeting_notes` (798-995, dispatch at 846-902)
- `pipeline/extract/meeting_notes_pdf.py` — the whole new module (218 lines)
- `pipeline/extract/publication_policy.py` — `is_publishable_content` (478),
  `load_participant_roster` (443)
- `pipeline/extract/test_meeting_notes_pdf.py`,
  `pipeline/extract/test_meeting_notes.py` (redaction-gate test classes,
  lines 744-994)
- `specs/009-meeting-notes-pdf-source/` — spec.md, data-model.md,
  contracts/pipeline-stage.md, quickstart.md (read the "Correction history"
  note before trusting any invocation example in it)
- `platform/backend/internal/api/session_sections.go`,
  `platform/backend/pkg/sessionrecord/sessionrecord.go:511` (`Store.Derive`) —
  the read side this pipeline's output ultimately feeds, already covered by
  `submodules/qa/banks/workshop/chapter-detail-content.yaml`
- `curriculum/chapter-01/knowledge/*.jsonl`, `curriculum/passages.jsonl` — the
  real, currently-stale served state documented in §6
- `docs/work-register.md` row R26 — the "DONE, fully closed" claim that §6
  qualifies

## Suggested focus for the brainstorming session

1. **§6 is the headline finding**: the served corpus for chapter 01 has not
   been regenerated since the PDF-sourcing feature landed — decide whether to
   (a) recommend the operator re-run the pipeline for real before any bank
   work starts, or (b) design the bank's scratch-registry harness so it does
   not depend on the live registry ever being regenerated.
2. Decide between options 2 and 3 in §7 as genuinely separate work items, not
   one bank — option 3 is the first state-mutating bank design in this fleet
   and deserves its own explicit go/no-go.
3. The `extraction_failed` state (FR-009) appears not to reach the wire at
   all (§5) — confirm with the Go side whether this is intentional (an
   operator-only diagnostic, surfaced elsewhere) or a genuine gap between the
   pipeline's own honest failure reporting and what a reader of the live site
   can ever observe.
4. The three independent `apply_redaction_gate` call sites (§3) are a
   regression class that has already bitten once (the Phase 5 review fix) —
   a scratch-registry test asserting all three sites are still wired (not
   just that the gate function itself works) would catch a future silent
   removal of any one of them.
5. `curriculum/non-owner-participants.txt`'s current zero-match state (§3) is
   a real but shallow proof — the roster is genuinely tiny (single-digit real
   names). Consider whether the brainstorm wants a synthetic-roster scratch
   test (add a fake name, prove it withholds, remove it) as a standing
   regression guard, distinct from the roster's own real content.
