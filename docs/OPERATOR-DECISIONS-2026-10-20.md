# Operator decisions and requests: 2026-10-20

| | |
|---|---|
| Document | Operator-request-history record for 2026-10-20, in the style of `OPERATOR-DECISIONS-2026-09-07.md`, `-09-08.md` and `-09-09.md` |
| Constitution | 11.4.208 (request-history ledger), 11.4.210 (zero-loss intake), 11.4.61 (metadata table and table of contents), 11.4.6 (no guessing) |
| Revision | 1 (2026-10-20) |
| Author | Documentation stream D1 (a Claude agent), from the session record named below |
| Status | Draft for independent review (11.4.142). Not reviewed. |
| Timezone | Dates are calendar dates; no clock time or timezone was available in the record, so none is invented (`UNKNOWN`) |
| Baseline | Tag `vasic-1.0.0-dev-0.0.1`: `workshop` commit `ce62bcb`, umbrella commit `a55e878` |
| Sources read | `specs/026-spec-reconciliation/spec.md` (O-1 to O-7, D1 to D11) and `tasks.md`; `specs/020-textbook-library-ui/spec.md` (D-LIC); the constitution text for the four delivery anchors; the stream-D1 task brief relayed by the orchestrator |

## Contents

1. [How to read this record, and its limits](#1-how-to-read-this-record-and-its-limits)
2. [Operator requests and standing approvals](#2-operator-requests-and-standing-approvals)
3. [Open decisions O-1 to O-8 and what was taken](#3-open-decisions-o-1-to-o-8-and-what-was-taken)
4. [Floor choice for crossref](#4-floor-choice-for-crossref)
5. [Answering, MMR, resources and delivery principles](#5-answering-mmr-resources-and-delivery-principles)
6. [Reconciliation decisions D1 to D11](#6-reconciliation-decisions-d1-to-d11)
7. [Still open, with the default being implemented](#7-still-open-with-the-default-being-implemented)

## 1. How to read this record, and its limits

* **Wording.** The operator's own typed words for this session are **not visible** to the agent that
  wrote this record. Every entry below is therefore marked **paraphrased** (taken from the task brief
  that the orchestrator relayed, and from the spec files) unless it says **verbatim from a file**, in
  which case the quoted text is in the cited file. No quotation has been invented.
* **Who decided.** "Operator" means the operator personally. "Delegate" means the orchestrating agent
  acting for the operator under the standing approval; a delegate decision is **amendable by the
  operator** and is marked as such. This distinction is kept because spec 026 itself makes it (O-1 is
  "RESOLVED ... by the operator's delegate (not an operator-typed decision; the operator may amend)").
* **Status vocabulary.** DECIDED (operator), DELEGATE-DEFAULT (taken by the delegate, amendable),
  ACCEPTED (delegate default confirmed by the operator or not contested), IN EFFECT (a standing rule),
  OPEN (not decided; the default shown is what is being implemented).
* **Content boundary.** This is a public repository. Textbooks and recordings are named by path or
  count only. No title, no text and no credential appears here.

## 2. Operator requests and standing approvals

| ID | Date | Request or approval | Wording | Status |
|---|---|---|---|---|
| OR-01 | 2026-10-20 | Establish a baseline release: tag `vasic-1.0.0-dev-0.0.1` at `workshop` `ce62bcb` and umbrella `a55e878` | paraphrased | IN EFFECT; the tag exists on both repositories |
| OR-02 | 2026-10-20 | **Standing approval** to execute specs 011 to 017 and the new specs 018 to 026, in order, with fan-out (parallel streams, independent review per stream) | paraphrased | IN EFFECT |
| OR-03 | 2026-10-20 | Approve the **textbook ingest** and the **live restart** that makes it visible, with the licence basis recorded as the exact string `operator-directed 2026-10-20` (class `operator-directed`) for the three books | paraphrased; the exact string `operator-directed 2026-10-20` is **verbatim from a file** (`specs/020-textbook-library-ui/spec.md`, D-LIC, marked "operator-given") | DECIDED. Whether the ingest and restart have been executed is **UNCONFIRMED** by this record (the spec 020 tasks and the promotion path of spec 019 were the gate when it was written) |
| OR-04 | 2026-10-20 | **Token rule**: nothing may re-process videos, audio, transcripts or textbooks with models. No LLM, remote model, generation, ASR or vision pass over that material; extraction and ingest are deterministic and bash-driven, and tests use fixtures | paraphrased | IN EFFECT (also stream rule "TOKEN RULE"; spec 020 requires a hard guard that proves zero model spend) |
| OR-05 | 2026-10-20 | Raise the host's **heavy-work slots from 2 to 4** | paraphrased | IN EFFECT. Heavy commands run under `scripts/agent-admit.sh --slots 4` |
| OR-06 | 2026-10-20 | Invoke the constitutional **delivery principles**: ship each proven increment and cut regular numbered releases and tags (see section 5) | paraphrased | IN EFFECT |
| OR-07 | 2026-10-20 | Reconcile specs 011 to 017 against each other and against the code before implementing any of them | paraphrased; the spec file calls it "Operator directive of 2026-10-20" | DONE (spec 026, documentation only); at the time `tasks.md` was read, the independent review T016 was still unticked |

## 3. Open decisions O-1 to O-8 and what was taken

The seven decisions O-1 to O-7 are listed in `specs/026-spec-reconciliation/spec.md` ("Open
Decisions"). O-8 was added after that spec was written and is recorded here from the task brief.
For every one of them the choice below was taken by the **operator's delegate** under OR-02, as
"delegate defaults taken". Each is amendable by the operator.

| ID | Question | Choice taken | Status |
|---|---|---|---|
| O-1 | Licence `basis` vocabulary | Closed vocabulary `public-domain` or `open-license` or `rights-holder-permission` or `operator-directed`, written `<class>[: detail]`; a bare Creative Commons id such as `CC-BY-4.0` reads as `open-license`. `UNVERIFIED`, `unknown`, empty and typos are **refused for EPUB** (`pipeline/textbook_license.py`). The PDF path stays non-enforcing for its legacy callers. `operator-directed` is the class the three current books use | DELEGATE-DEFAULT, amendable. Spec 026 records it as resolved |
| O-2 | Ability score: per area or cross-curriculum | **Per-area** ability score | DELEGATE-DEFAULT |
| O-3 | Which achievement events are modal-worthy | A modal **only for level-up and chapter-complete**; everything else is a toast | DELEGATE-DEFAULT |
| O-4 | Kind-easing (route a struggling learner to an easier question kind) | **Build it** (kind-easing, server-side, owner spec 013, task T036b). It had been deferred as post-MVP | DELEGATE-DEFAULT |
| O-5 | Meaning of `chapter-complete` | **All lessons in an area completed** (area lesson-completion), not recorded-chapter reading completion | DELEGATE-DEFAULT |
| O-6 | Live merge of the 1,675 textbook passages into the live registry, and the reranker | **Textbook merge approved.** The **reranker stays off** until a two-sided regression (recall and fabrication) passes | DELEGATE-DEFAULT for the reranker condition; the merge itself follows OR-03 |
| O-7 | Whether spec 011 FR-005's stale NEEDS CLARIFICATION (audit schema) counts as resolved by `data-model.md` section 4 | **Accepted** | ACCEPTED |
| O-8 | How graded questions join adaptive practice | Graded questions join adaptive practice **per question, after the session has attempted them in the assessment** | DELEGATE-DEFAULT. Source: the task brief only; not yet written into a spec file in the files read, so **UNCONFIRMED** where it is recorded in the specs |

## 4. Floor choice for crossref

| Item | Choice | Status |
|---|---|---|
| Floor design | A **single noise floor at quantile 0.90, value 0.6391**, applied at the next crossref derivation | DELEGATE-DEFAULT, amendable |
| Later option | A per-source-kind floor at quantile 0.95 | OPEN (a later decision) |
| Basis | `evidence/s6/t045b-floor-measured-v2.txt` and `t045b-floor-impact-v2.txt` in the `workshop` repository: at q=0.90 the single floor keeps 95.5% of edges and leaves 236 of 34,623 sources empty (0.7%) | measured, not re-measured by this record |

## 5. Answering, MMR, resources and delivery principles

| ID | Decision | Status |
|---|---|---|
| RD-01 | **Answering stays OFF** unless a measured two-sided gate (recall and fabrication) **PASSES**. The last measured deployed configuration answered 14 of 72 answerable trials (19%) and fabricated on 4 of 87 unanswerable trials (4.6%) (`MEASUREMENT-generation-15-2026-09-24.md`). Raising the score threshold until a benchmark goes green is not an accepted route | IN EFFECT. The 2026-09-25 operator decision "Turn answering OFF, keep semantic search" is recorded in the umbrella carriers; this entry restates the condition for turning it on |
| RD-02 | **MMR (Maximal-Marginal-Relevance) is out** for crossrefs: cosine ranking with a minimum-score floor and a per-source cap. Diversity concerns are met by the floor and the honest empty state | DECIDED in spec 026 as D7 (FR-010); restated in the task brief as "MMR out" |
| RD-03 | **Heavy-work slots raised from 2 to 4**, 2026-10-20, by the operator | IN EFFECT (same as OR-05) |
| RD-04 | **Delivery principles invoked**: 11.4.230(D) (the delivery unit is the increment, not the spec), 11.4.235 (build and deploy the moment source fixes are proven correct), 11.4.236 (no manual-QA hand-off until the validation produced a candidate-fingerprinted PASS verdict), 11.4.264 (build once, promote one immutable content-addressed artifact; never rebuild per stage). Read together: ship each proven increment, and cut regular numbered releases and tags. The release procedure is in `docs/releases/ADDING-A-RELEASE.md` | IN EFFECT. The constitution's own verbatim operator mandate for 11.4.230(D) (2026-10-04) begins: "All work we do, especially SpecKit specs, gets incorporated right away." (verbatim from `Constitution.md`, not from this session) |

## 6. Reconciliation decisions D1 to D11

Made while authoring spec 026 (documentation only), recorded in that spec. They resolve
contradictions between specs and the code and are not operator-typed. Full text and evidence are in
`specs/026-spec-reconciliation/spec.md` (FR-001 to FR-014) and `research.md`.

| ID | Decision (summary) | Status |
|---|---|---|
| D1 | All textbook content, in every format, mints as `kind: textbook_section` with `content_type: textbook` under scope `textbook-<slug>`; every sidecar row carries `content_type` | applied to the specs |
| D2 | The licence record is two sibling files (`<out>.license.json` full record; `license` summary in `<out>.report.json`), never inside the sidecar; `attrs` retargeted to the current 5-parameter `DocumentObservation` | applied (amended after the S4 review, M5) |
| D3 | Spec 013 defines the achievement event stream that spec 014 consumes (kinds `level-up`, `chapter-complete`, `adjusted`; append-only; idempotent; replayable by `events_after`); server wire form snake_case, 014's adapter maps it | applied |
| D4 | Spec 014 owns the remedial link on `adjusted` events; kind-easing is server-side, owner 013 (now O-4) | applied |
| D5 | Practice-bank baselines cite a measurement: 292 questions, 113 medium, 179 hard, 0 easy at `workshop` `33e9760` | applied |
| D6 | Spec 015's frontend lives under `features/profile/`, one route `profile` | applied |
| D7 | No MMR for crossrefs | applied |
| D8 | Spec 012 adopts `pdf_textbook_sections.py` as the single PDF implementation | applied |
| D9 | Task checkboxes follow evidence (41 spec 016 tasks ticked with notes) | applied |
| D10 | Hot-spot ownership rules (hook files `wire_<feature>.go`, single-writer files, one branch and worktree per stream) are referenced from every plan | applied |
| D11 | Open decisions are listed once (spec 026, "Open Decisions") | applied |

## 7. Still open, with the default being implemented

From `specs/020-textbook-library-ui/spec.md` (Clarifications, session 2026-10-20). These are **OPEN**;
the default shown is what the implementation follows until the operator rules otherwise.

| ID | Question | Default being implemented |
|---|---|---|
| D-PDF | May the original PDFs be served in the app? | No. The in-app page view uses extracted text; no PDF route, no download link |
| D-DIAG | Do diagram captions become searchable passages? | No. Figures are displayed, not searched |
| D-EMB | Does the server's boot-time local embedding count as a "model call"? | Allowed and disclosed (local embedding, no generated text, no billed tokens). The ingest procedure itself makes zero model calls |
| D-SVG | Serve vector (SVG) page renders? | No. Raster PNG only |
| D-TITLES | Display titles for the three books | Draft titles from the PDF metadata title field, confirmed by the operator in `books.json`; file names are never shown |
| Audit failure mode | Spec 011: should an audit-write failure fail closed or fail open? | Fail closed is implemented as an unreviewed default pending operator confirmation (`docs/providers.md` in `workshop`) |
