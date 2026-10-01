# Phase 0 Research: Workshop Live-QA Fix Batch

No `NEEDS CLARIFICATION` markers remain in the plan's Technical Context — this is a fix batch
against an existing, fully-identified stack, not a new-technology choice. Research here instead
establishes, for each of the 8 user stories, the best-evidence hypothesis for root cause before any
fix is written, per the constitution's *Reproduce Before Repairing* principle. Each entry states
what is already known with real evidence (from live verification work carried out against this same
server earlier the same day), what is genuinely unknown, and the investigation approach to pursue
first.

## US1 — Practice question selection and answer submission

**Decision**: Investigate the "can't select an answer" symptom FIRST, as a single root cause, before
treating "answer not recorded" as a separate defect.

**Rationale**: Earlier the same day, a live-verification pass against a different area
(`01M1GWW49GNKYBEXFFCNRWM1T0`'s sibling area) exercised this exact flow and found: (a) selecting and
submitting an answer worked, and (b) a "the answer was not recorded" banner appeared *specifically
because no answer text had been typed/selected before advancing* — noted at the time as "a
separate, unrelated... different code path, not the bug under test." If the newly reported "can't
select anything" symptom (US1, area `01M1GWW49GNKYBEXFFCNRWM1T0`) is real and reproducible, it would
produce exactly this same "not recorded" banner as a downstream SYMPTOM, not a second, independent
backend failure — matching the constitution's own worked example ("Fixing the stated mechanism
would have shipped a green gate over an unfixed product"). The reported "Send again does not help"
detail is also consistent with this: retrying a submission with nothing selected cannot succeed
regardless of backend health.

**Alternatives considered**:
- Treat selection-failure and submission-failure as two independent defects from the start —
  rejected as the default path because it risks fixing a backend acknowledgment issue that may not
  exist, while leaving the actual frontend selection bug (which would make ANY fix to the backend
  unobservable to a QA session) untouched.
- Assume the earlier-same-day verification is stale and no longer representative — a live
  reproduction against the SAME area reported in this new QA pass is required regardless, since the
  server has restarted and reindexed multiple times since that verification; the hypothesis above is
  a starting point, not a substitute for reproducing against the actual reported area.

**Investigation approach**: Reproduce live against area `01M1GWW49GNKYBEXFFCNRWM1T0` specifically
(not a different area) with browser dev tools / network inspection open. Confirm whether a click on
an answer option updates any client-side state at all (a pure frontend event-binding/CSS issue) or
reaches a network call. Only if selection is confirmed genuinely working and a real submission is
rejected by the server should the backend acknowledgment path be investigated as a second, distinct
defect.

---

## US2 — Completed lessons/sections not shown as checked on return

**Decision**: Investigate this as a DIFFERENT code path than the progress-page fix shipped earlier
the same day, not a regression of it.

**Rationale**: Earlier the same day, a fix shipped and was live-verified for "progress page staying
empty after marking a lesson complete" — specifically, navigating to the dedicated `/progress` page
after marking a lesson complete was confirmed to correctly show the update, persisted across reload.
The newly reported symptom is about a different surface: the AREA page itself
(`/areas/{area-id}`) not rendering its own lesson/section list with completion checkmarks on load.
These are plausibly two different read paths (one dedicated progress view, one inline per-area
list) that could independently read from — or fail to read from — the same underlying
completion-state store.

**Alternatives considered**: Assume it's the same bug reopened — rejected without reproduction,
since the two UI surfaces are not necessarily backed by the same code path, and conflating them
risks "fixing" the already-fixed progress page a second time while leaving the actually-broken
area-page list untouched.

**Investigation approach**: Reproduce live: mark a lesson complete on the exact area referenced
(`01M1GWW49GNKYBEXFFCNRWM1T0`), confirm the completion write succeeds (e.g. via the dedicated
progress page, known-working), then reload the SAME area page and confirm whether the checkmark is
actually missing. Trace the area page's own data-loading code to determine whether it reads
completion state at all, reads it from a stale/cached source, or has a rendering bug that discards a
correctly-fetched completion flag.

---

## US3 — Chapter recordings empty on the landing page except Chapter 01

**Decision**: Treat chapters with a confirmed real recording (chapters 02, 02.01, 02.02, 03) as a
display/wiring defect to investigate first; treat the text-only chapter (04, which has no video by
design) as a separate, simpler "needs the designed no-recording indicator" task — not a display bug.

**Rationale**: This session's own work today confirmed, with real evidence, that chapters 02,
02.01, 02.02, and 03 each have an actual archived, extracted, SHA-256-verified video recording —
these are not missing data. Chapter 04 is explicitly a text-only chapter type (a Slack conversation
as source material) with no video by design, introduced the same day. A landing page that shows
every chapter but 01 as empty, when 4 of those chapters genuinely have recordings, is far more
consistent with a carousel/list component only rendering (or only being wired to) the first item,
or a query that only fetches chapter 01's recording metadata, than with the recordings themselves
being absent.

**Alternatives considered**: Assume the recordings genuinely failed to process and are absent from
the served index — considered and deprioritized as the primary hypothesis, specifically because this
session's own archive/extract verification work earlier confirmed their presence with real
SHA-256-checked evidence; this alternative is not ruled out, but the display-layer hypothesis is
checked first since it is cheaper to falsify and matches the "all except the first" shape of the
symptom (consistent with an off-by-one, a `[0]`-only binding, or a filter that only lets through
one item).

**Investigation approach**: Check the recordings carousel's data source directly (a network request
inspection of whatever endpoint the landing page calls) to see whether it returns all chapters'
recording metadata and the FRONTEND fails to render all but the first, or whether the endpoint
itself only returns chapter 01. Cross-check against the server's own index/session-record state for
each chapter to confirm recordings are genuinely indexed as present before concluding a backend
defect.

---

## US4 — "Not in this build" placeholder in transcript pages

**Decision**: Treat as a literal leftover placeholder string in either the frontend's content-state
rendering branch or a pipeline-generated field, not yet traced to either side — flag as the least
pre-characterized symptom in this batch and start from a plain text search across both layers.

**Rationale**: No prior work earlier the same day specifically investigated or encountered this
string. "Not in this build" reads as an internal build/feature-flag message that leaked into
user-facing content — the kind of string a developer writes as a stub during active development and
never removes — but there is no existing evidence pinning it to a specific file or layer.

**Alternatives considered**: None preferred over a plain investigation; no shortcut is available
here given the lack of prior same-day evidence.

**Investigation approach**: `grep`/search both `platform/frontend/src/` and `platform/backend/`
(and `pipeline/` if the string could originate from a generated sidecar file) for the literal string
"Not in this build" to find its source directly, then trace what condition causes it to render
instead of real content, and on which chapters/segments it currently appears (a full sweep, per
FR-003's "nothing can be missed" / zero-tolerance framing).

---

## US5 — Excessive "Transcriber unsure" flags

**Decision**: Investigate current per-chapter uncertainty rates as a baseline measurement task
before deciding whether the fix is a reprocessing run, a calibration-threshold change, or an
ASR-engine/settings change.

**Rationale**: This project's existing pipeline already has a documented "calibrated confidence
threshold" concept (seen in this session's own prior work referencing a per-chapter calibrated
threshold for flagging uncertain segments). The reported excess could stem from: the threshold being
tuned too conservatively (flagging segments a human would consider clear), the underlying ASR run
genuinely underperforming on specific chapters' audio quality, or — given today's broader session
activity — a stale/pre-reprocessing transcript being served for some chapters. All three have
different fixes, and the quantified target (SC-003: ≥50% reduction per chapter, from this feature's
own clarification session) requires a real per-chapter baseline measurement to even know if a given
intervention is sufficient.

**Alternatives considered**: Jump directly to lowering the confidence threshold — rejected as a
first move, since the constitution's *A Statistic a Fix Can Overshoot Requires a Two-Sided Check*
principle applies directly here: blindly lowering the threshold could reduce flagged-uncertain
count while increasing genuinely-wrong transcript content silently accepted as confident, which is
the opposite of FR-005's actual intent ("remaining flags corresponding only to genuinely
hard-to-transcribe audio").

**Investigation approach**: Measure the current flagged-uncertain rate per chapter as a baseline.
For a sample of currently-flagged segments, listen to the underlying audio and judge whether a
reasonable listener would consider the segment genuinely hard to transcribe or whether the engine's
output was actually correct/clear despite the flag — this determines whether the fix is a threshold
tuning (cheap) or requires an actual re-transcription pass (expensive, as seen with today's
chapter-by-chapter ASR work).

---

## US6 — "Where else this points" cross-reference noise

**Decision**: Re-measure crossref quality against whatever index generation is CURRENTLY live before
assuming the earlier-same-day fix regressed or was insufficient.

**Rationale**: Earlier the same day, a scoping fix for exactly this symptom (unscoped candidate
population picking up bare glossary terms and bookkeeping rows) was implemented, and live-verified
clean — 0 bogus targets across 80 sampled edges — against a specific index generation. Since then,
the server has restarted and reindexed multiple additional times (chapter-03 finalization, G5
remediation work), producing at least one newer generation. The constitution's own *Source Is Not
Served* and *A Snapshot Licenses Only Itself* principles apply directly: that earlier clean result
describes a specific past generation, not a standing guarantee about whatever generation is live
now. It is plausible the newly reported noise is: a genuine regression, the SAME scoping gap
re-appearing for chapter 03/04's newly reintegrated content specifically (which did not exist in the
corpus at the time of the original fix), or crossrefs being temporarily unavailable/partially
computed for a mid-derivation generation and some other noisy fallback being shown instead.

**Alternatives considered**: Assume the original fix is insufficient and re-derive the scoping logic
from scratch — rejected as premature; re-measuring against the current live state first is cheaper
and will show whether this is a genuinely new gap (e.g. specific to chapter 03/04 content) or a
reindexing-timing artifact that self-resolves once crossref derivation for the current generation
completes.

**Investigation approach**: Check `/api/index/status` for the current live generation and whether
crossref derivation has completed for it. If complete, sample cross-reference lists for a range of
passages — including specifically chapter 03/04 passages, since those are new since the original
fix — using the same methodology as the earlier verification (tally target kind, score range, and
flag any bare glossary/bookkeeping target), with a sample large enough to speak to recall, not only
precision (per *A Screen's Precision Is Not Its Recall*). If derivation is incomplete, that is very
likely sufficient explanation on its own and the fix is operational (trigger/await derivation), not
a code change.

---

## US7 — Progress-screen first-column label truncation

**Decision**: Treat as a straightforward CSS/layout defect; no deep investigation needed beyond
locating the specific element and its current overflow/truncation handling.

**Rationale**: This is a narrowly-scoped, purely visual defect with a concrete, literal reproduction
(`"ched this"` instead of a complete word) — the lowest-ambiguity item in this batch.

**Alternatives considered**: N/A — no competing hypotheses for a layout bug of this shape.

**Investigation approach**: Locate the progress screen's first-column component, inspect its current
CSS (fixed width with `overflow: hidden` and no responsive wrapping is the most likely culprit shape
given the described symptom), and confirm the fix (wrap, responsive width, or
truncate-with-full-text-available) against the acceptance scenario's viewport range.

---

## US8 — Chapter 4 content quality and voice

**Decision**: Treat as a content-generation/rewrite task scoped per-section, using chapter 4's
already-ingested transcript as the only source of truth, with human review as the actual acceptance
gate (per the plan's Human Checkpoint 4) rather than a fully automatable success criterion.

**Rationale**: Chapter 4 is a text-only chapter (its own source document IS the chapter material, no
ASR involved) onboarded the same day. "Clear, concluded, third-person" is a content-quality bar that
automated checks can partially verify (e.g., a check for remaining first-person "I " phrasing is
mechanical) but cannot fully verify for "clear" and "concluded" without human judgment, consistent
with this spec's own SC-009 being judged by reading, and with the plan's Constitution Check noting
this feature introduces no new public-facing artifact (keeping the rewrite inside the existing
private-module content-boundary discipline).

**Alternatives considered**: Attempt a fully automated, unreviewed rewrite — rejected; the
constitution's content-boundary and evidence-based-claims principles, plus this project's own
established practice for chapter-content work today, require a human-reviewed pass before
content-quality work is called done.

**Investigation approach**: Read chapter 4's current section content and its full source transcript
side by side to identify which specific sections are the clearest instances of "thrashy"/first-person
fragments (to scope the rewrite precisely rather than touching sections that are already acceptable),
and confirm the existing text-only-chapter section-generation code path (introduced the same day) so
the rewrite can be produced consistently with how other sections are structured, rather than as a
one-off hand edit.
