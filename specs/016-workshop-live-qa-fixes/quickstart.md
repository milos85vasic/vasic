# Quickstart: Validating the Workshop Live-QA Fix Batch

This is a validation/run guide — how to prove each of the 8 user stories actually works, end to
end, against the real running platform. It does not contain implementation code; see
`data-model.md` and `contracts/` for the expected shapes each fix must satisfy, and `tasks.md`
(generated separately) for the implementation breakdown.

## Prerequisites

1. The `workshop` service MUST be running the code under test. Per the constitution's *A Restart
   Runs What Was Built*: run `bash scripts/restart.sh` (never a bare container restart) after any
   fix lands, then confirm with `bash scripts/status.sh` (expect `RUNNING`, healthy) and quote the
   `build` field from an authenticated `GET /api/health` call in every validation note below — a
   validation against a stale build proves nothing.
2. Authenticate using this project's existing seed test-account convention (the same one used for
   every other live verification in this project today) before calling any authenticated route.
3. `GET /api/index/status` to confirm the current live generation and whether crossref derivation
   has completed for it — several scenarios below (US6 specifically) need to know this first.

## US1 — Practice answer selection and submission

1. Open `/practice/01M1GWW49GNKYBEXFFCNRWM1T0` (the exact area reported, not a substitute).
2. Click/tap an answer option on a multiple-choice question. **Expected**: the option visibly
   becomes selected (see `contracts/practice-answer-interaction.md`).
3. Submit the answer. **Expected**: the response is the learner's actual result (`correct` /
   `incorrect` / `withheld`), not "An answer was not recorded".
4. If step 3 fails anyway (genuine environmental condition), click "Send again". **Expected**: the
   retry succeeds under normal operating conditions.
5. Reload the page. **Expected**: the previously recorded result for that question is still shown.

## US2 — Completed lessons/sections checked on area-page return

1. On an area page, mark one lesson/section complete.
2. Confirm the write persisted via the already-working dedicated `/progress` page.
3. Reload the SAME area page (`/areas/{area-id}`). **Expected**: the completed lesson/section
   renders checked immediately, no interaction required (see
   `contracts/lesson-completion-state.md`).
4. Confirm a not-yet-completed lesson/section on the same page does NOT render checked (no false
   positive).

## US3 — Chapter recordings visible where they exist

1. Load the landing screen's recordings section.
2. For each chapter known to have a real recording (02, 02.01, 02.02, 03 — confirmed archived and
   extracted earlier the same day), confirm a working recording entry renders (see
   `contracts/chapter-recordings-listing.md`).
3. For chapter 04 (text-only, no recording by design), confirm the designed "no recording"
   indicator renders — not an empty gap.
4. Click through from the listing into at least one `available` chapter's recording route to
   confirm it actually resolves (the *Published Means Served* cross-check in the contract) — do not
   stop at the listing level.

## US4 — No "Not in this build" placeholders

1. Walk every transcript page, every chapter, end to end (or run the automated equivalent once the
   fix's own test exists).
2. **Expected**: zero occurrences of the literal string "Not in this build" anywhere in rendered
   transcript content.
3. For any segment that is genuinely unavailable, confirm it uses the platform's existing honest
   "content unavailable" presentation instead.

## US5 — Reduced transcription uncertainty

1. Record the current per-chapter "flagged uncertain" segment count/rate as the baseline (if not
   already captured during Phase 0 research).
2. After reprocessing, re-measure the same per-chapter rate.
3. **Expected**: at least a 50% reduction per chapter (SC-003), with the chapter's total segment
   count unchanged.
4. Spot-check a sample of segments still flagged uncertain after reprocessing by listening to the
   underlying audio — confirm they are genuinely hard to transcribe, not borderline-clear cases.

## US6 — Relevant cross-references

1. Confirm crossref derivation has completed for the current live generation (prerequisite step
   above) — if not, this is likely sufficient explanation on its own; re-check once it completes.
2. Sample cross-reference lists across multiple chapters, INCLUDING chapter 03 and chapter 04
   content specifically (new since the original same-day scoping fix).
3. For each sampled passage, tally target kind and confirm every listed entry is genuinely
   topically related — zero bare glossary terms, zero internal bookkeeping rows (SC-004).
4. Use a sample large enough to speak to recall, not only precision, per the constitution's *A
   Screen's Precision Is Not Its Recall* — a small clean-looking sample is not sufficient evidence
   on its own.

## US7 — No truncated progress-screen labels

1. Load the progress screen at a range of realistic viewport widths (desktop and mobile).
2. **Expected**: every first-column label renders as a complete word/phrase — no mid-word cutoff
   (e.g. the reported "ched this").

## US8 — Clear, third-person chapter 4 content

1. Read every section of chapter 4 end to end.
2. **Expected**: each section is a clear, concluded statement traceable to something actually
   discussed in chapter 4's source conversation (no disjointed/truncated fragments), written in
   third person with no remaining first-person "I ..." phrasing (SC-009).
3. This scenario's final acceptance is a human readability/accuracy pass (plan's Human Checkpoint
   4) — an automated first-person-phrasing scan is a useful mechanical pre-check but is not
   sufficient on its own to call this story done.

## Full-batch regression check

After all 8 stories pass individually, run the project's existing full suites before considering
this branch done (plan's Human Checkpoint 3):

```bash
cd workshop/platform/backend && go build ./... && go vet ./... && go test ./...
cd workshop/platform/frontend && npm run test:unit
cd workshop && PYTHONPATH=$PWD/pipeline/extract pipeline/venv/bin/pytest pipeline/extract -q
bash workshop/scripts/restart.sh && bash workshop/scripts/status.sh
```

Quote the real pass/fail counts and the post-restart `build` stamp from `/api/health` in the final
report — per *Evidence-Based Claims*, a claim of "done" without this pasted evidence is not
accepted.
