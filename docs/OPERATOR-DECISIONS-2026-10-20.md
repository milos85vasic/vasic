# Operator decisions and requests: 2026-10-20

| | |
|---|---|
| Document | Operator-request-history record for 2026-10-20, in the style of `OPERATOR-DECISIONS-2026-09-07.md`, `-09-08.md` and `-09-09.md` |
| Constitution | 11.4.208 (request-history ledger), 11.4.210 (zero-loss intake), 11.4.61 (metadata table and table of contents), 11.4.6 (no guessing) |
| Revision | 3 (2026-10-21). Revision 1 presented O-2 to O-7 and the crossref floor as taken decisions; the repository record did not show them as taken (part 3); corrected in revision 2. Revision 2 was reviewed NO-GO on two points and revision 3 fixes both: OR-03 and X-04 said things that were false by 2026-10-21 (the ingest and restart happened; releases 0.0.3 and 0.0.4 are tagged), and the operator's decisions of 2026-10-21 were missing. They are in `OPERATOR-DECISIONS-2026-10-21.md` and cross-referenced below as "Amended 2026-10-21" |
| Author | Documentation stream D1 (a Claude agent), from the session record named below |
| Status | Draft for independent review (11.4.142). Revision 2 was reviewed NO-GO (documentation only); revision 3 is not yet re-reviewed. Parts 2 to 8 describe the state **as of 2026-10-20** unless an "Amended 2026-10-21" note says otherwise |
| Timezone | Dates are calendar dates. Clock times appear only where a git tag object carries one (`+0200`); elsewhere no time is invented (`UNDETERMINED`) |
| Baseline | Tag `vasic-1.0.0-dev-0.0.1`: `workshop` commit `ce62bcb`, umbrella commit `a55e878` |
| 11.4.208 fields | Track: documentation (stream D1). Alias: `claude3` (inferred from the user-scope configuration directory this session loaded, `UNCONFIRMED` by the operator). Model and effort of the author: Sonnet 5.5; effort `UNDETERMINED` (not stated in the brief). Model and effort of the other participants named below: `UNDETERMINED` (not in any file read) |
| Sources read | `specs/026-spec-reconciliation/spec.md` (O-1 to O-7, D1 to D11) and `tasks.md`; `specs/020-textbook-library-ui/spec.md` (D-LIC); the constitution text for the four delivery anchors; `specs/013-*/tasks.md` and `contracts/achievement-events.md`; `specs/014-*/spec.md`; `specs/016-*/tasks.md`; `specs/011-*/tasks.md`; `workshop` `pkg/answer/locality.go`; `workshop` `evidence/release/0.0.2/` and the git tag objects of both repositories; the stream-D1 task brief relayed by the orchestrator |

## Contents

1. [How to read this record, and its limits](#1-how-to-read-this-record-and-its-limits)
2. [Operator requests and standing approvals](#2-operator-requests-and-standing-approvals)
3. [Open decisions O-1 to O-8 and what was taken](#3-open-decisions-o-1-to-o-8-and-what-was-taken)
4. [Floor choice for crossref](#4-floor-choice-for-crossref)
5. [Answering, MMR, resources and delivery principles](#5-answering-mmr-resources-and-delivery-principles)
6. [Reconciliation decisions D1 to D11](#6-reconciliation-decisions-d1-to-d11)
7. [Still open, with the default being implemented](#7-still-open-with-the-default-being-implemented)
8. [Further records for 2026-10-20](#8-further-records-for-2026-10-20)

## 1. How to read this record, and its limits

* **Wording.** The operator's own typed words for this session are **not visible** to the agent that
  wrote this record. Every entry below is therefore marked **paraphrased** (taken from the task brief
  that the orchestrator relayed, and from the spec files) unless it says **verbatim from a file**, in
  which case the quoted text is in the cited file. No quotation has been invented.
* **Who decided.** "Operator" means the operator personally. "Delegate" means the orchestrating agent
  acting for the operator under the standing approval; a delegate decision is **amendable by the
  operator** and is marked as such. This distinction is kept because spec 026 itself makes it (O-1 is
  "RESOLVED ... by the operator's delegate (not an operator-typed decision; the operator may amend)").
* **Status vocabulary.** DECIDED (operator), DELEGATE-DEFAULT, UNRATIFIED (a default taken by the
  delegate and implemented; **the operator has not ratified it** and the repository record may still list
  the question as open), ACCEPTED (not contested, per the cited source), IN EFFECT (a standing rule),
  OPEN (not decided; the default shown is what is being implemented). A row says which file shows the
  status; where the files and the brief disagree, both are named and the repository file is the record.
* **Content boundary.** This is a public repository. Textbooks and recordings are named by path or
  count only. No title, no text and no credential appears here.

## 2. Operator requests and standing approvals

| ID | Date | Request or approval | Wording | Status |
|---|---|---|---|---|
| OR-01 | 2026-10-20 | Establish a baseline release: tag `vasic-1.0.0-dev-0.0.1` at `workshop` `ce62bcb` and umbrella `a55e878` | paraphrased | IN EFFECT; the tag exists on both repositories |
| OR-02 | 2026-10-20 | **Standing approval** to execute specs 011 to 017 and the new specs 018 to 026, in order, with fan-out (parallel streams, independent review per stream) | paraphrased | IN EFFECT |
| OR-03 | 2026-10-20 | Approve the **textbook ingest** and the **live restart** that makes it visible, with the licence basis recorded as the exact string `operator-directed 2026-10-20` (class `operator-directed`) for the three books | paraphrased; the exact string `operator-directed 2026-10-20` is **verbatim from a file** (`specs/020-textbook-library-ui/spec.md`, D-LIC, marked "operator-given") | DECIDED. **Amended 2026-10-21: executed.** The ingest ran on 2026-10-21: `workshop` commit `576f8d6` (+1,675 `textbook_section` rows, registry 34,817 to 36,492 rows, registry sha256 `d7b4a386...`, checked in `evidence/textbooks/textbooks-c8adbd3ca35d/registry-summary.live.json`) and the catalogue data commit `827e79e` (`books=3 sections=1675`). The live restarts booted `books=3 sections=1675 state=present` and all 35,384 embeddable passages were embedded (those last two facts are from the orchestrator's brief, not re-read by D1: UNCONFIRMED here). Details: `OPERATOR-DECISIONS-2026-10-21.md` DC-01, DC-02, LV-01 |
| OR-04 | 2026-10-20 | **Token rule**: nothing may re-process videos, audio, transcripts or textbooks with models. No LLM, remote model, generation, ASR or vision pass over that material; extraction and ingest are deterministic and bash-driven, and tests use fixtures | paraphrased | IN EFFECT (also stream rule "TOKEN RULE"; spec 020 requires a hard guard that proves zero model spend) |
| OR-05 | 2026-10-20 | Raise the host's **heavy-work slots from 2 to 4** | paraphrased | IN EFFECT. Heavy commands run under `scripts/agent-admit.sh --slots 4` |
| OR-06 | 2026-10-20 | Invoke the constitutional **delivery principles**: ship each proven increment and cut regular numbered releases and tags (see part 5) | paraphrased | IN EFFECT |
| OR-07 | 2026-10-20 | Reconcile specs 011 to 017 against each other and against the code before implementing any of them | paraphrased; the spec file calls it "Operator directive of 2026-10-20" | DONE (spec 026, documentation only); at the time `tasks.md` was read, the independent review T016 was still unticked |

## 3. Open decisions O-1 to O-8 and what was taken

The seven decisions O-1 to O-7 are listed in `specs/026-spec-reconciliation/spec.md` ("Open Decisions",
the O-1 to O-7 rows at lines 92 to 98 (O-2 to O-7 at 93 to 98) as of this revision). O-8 was added after that spec was written and is recorded here from
the task brief. **The choices below are the defaults that the operator's delegate (the orchestrating
agent) is implementing under OR-02. None of O-2 to O-8 is shown as an operator-typed decision anywhere in
the files read.** Each is amendable by the operator. **Amended 2026-10-21: the operator ratified O-2 to O-8 as taken, and the crossref floor of part 4 (`OPERATOR-DECISIONS-2026-10-21.md` D-08). Read every "UNRATIFIED" in parts 3 and 4 below as "UNRATIFIED when this record was written; RATIFIED 2026-10-21".** Ratified 2026-10-21: O-2, O-3, O-4, O-5, O-6, O-7, O-8.

| ID | Question | Default being implemented | Status, and the file that shows it |
|---|---|---|---|
| O-1 | Licence `basis` vocabulary | Closed vocabulary `public-domain` or `open-license` or `rights-holder-permission` or `operator-directed`, written `<class>[: detail]`; a bare Creative Commons id such as `CC-BY-4.0` reads as `open-license`. `UNVERIFIED`, `unknown`, empty and typos are **refused for EPUB** (`pipeline/textbook_license.py`). The PDF path stays non-enforcing for its legacy callers. `operator-directed` is the class the three current books use | DELEGATE-DEFAULT, amendable. Spec 026 `spec.md` O-1 row says "RESOLVED 2026-10-20 by the operator's delegate (not an operator-typed decision; the operator may amend)" |
| O-2 | Ability score: per area or cross-curriculum | Per-area ability score | DELEGATE-DEFAULT, **UNRATIFIED by the operator**. Spec 026 `spec.md` O-2 row lists it as open; spec 013 "Clarifications Needed" and T049 carry it. The choice comes from the task brief only |
| O-3 | Which achievement events are modal-worthy | A modal only for level-up and chapter-complete; everything else is a toast | DELEGATE-DEFAULT, **UNRATIFIED by the operator**. Spec 026 O-3 row lists it as open (spec 014 T020). The modal is not built on `main` |
| O-4 | Kind-easing (route a struggling learner to an easier question kind) | Build it (server-side, owner spec 013, task T036b) | DELEGATE-DEFAULT, **UNRATIFIED by the operator**. Spec 026 O-4 row says "deferred"; spec 013 `tasks.md` T036b still reads "[DEFERRED] ... No implementation in this feature's first cut ... needs operator decision O-4". The files do not show the reversal to "build it" |
| O-5 | Meaning of `chapter-complete` | All lessons in an area completed (area lesson-completion), not recorded-chapter reading completion | DELEGATE-DEFAULT, **UNRATIFIED by the operator**. Spec 013 `contracts/achievement-events.md` line 53 says "Granularity of `chapter-complete` is an open operator decision (O-5)" |
| O-6 | Live merge of the 1,675 textbook passages into the live registry, and the reranker | Textbook merge approved; the reranker stays off until a two-sided regression (recall and fabrication) passes | The merge follows OR-03 (operator-given licence basis string). The reranker condition is DELEGATE-DEFAULT, **UNRATIFIED**. Spec 026 O-6 row lists the question as open. **Amended 2026-10-21: the merge was executed (OR-03) and the whole choice is RATIFIED (D-08)** |
| O-7 | Whether spec 011 FR-005's stale NEEDS CLARIFICATION (audit schema) counts as resolved by `data-model.md` part 4 | Accepted | DELEGATE-DEFAULT, **UNRATIFIED**. Spec 026 O-7 row says "the operator confirms"; no confirmation is recorded in the files read |
| O-8 | How graded questions join adaptive practice | Per question, after the session has attempted them in the assessment | DELEGATE-DEFAULT, **UNRATIFIED**. Source: the task brief only; not written into any spec file read, so where it is recorded is **UNCONFIRMED** |

The learner guide's statements about modal routing and the definition of `chapter-complete` repeat O-3
and O-5 as defaults and say so.

## 4. Floor choice for crossref

| Item | Choice | Status, and the file that shows it |
|---|---|---|
| Floor design | A single noise floor at quantile 0.90, value 0.6391, applied at the next crossref derivation | DELEGATE-DEFAULT, **UNRATIFIED by the operator** (**Amended 2026-10-21: RATIFIED, D-08**). There is **no repository record of a decision**: spec 016 `tasks.md` (line 430, the S6 note) says "Operator decides quantile and regeneration", records the **recommended design** as per-source-kind floors at q=0.95 and the single floor 0.6391 (q=0.90) as the **interim** option. The choice of the interim option comes from the task brief only |
| Later option | A per-source-kind floor at quantile 0.95 | OPEN (a later decision); this is what the S6 note recommends |
| Rollout state | Not rolled out. The shipped `min_score` is still 0; no default changed | The same note: "mechanism + tests done, ROLLOUT NOT DONE" |
| Basis | `evidence/s6/t045b-floor-measured-v2.txt` and `t045b-floor-impact-v2.txt` in `workshop`: at q=0.90 the single floor keeps 95.5% of edges and leaves 236 of 34,623 sources empty (0.7%) | measured by stream S6, not re-measured here |

## 5. Answering, MMR, resources and delivery principles

| ID | Decision | Status |
|---|---|---|
| RD-01 | **Answering stays OFF** unless a measured two-sided gate (recall and fabrication) **PASSES**. The last measured deployed configuration answered 14 of 72 answerable trials (19%) and fabricated on 4 of 87 unanswerable trials (4.6%) (`MEASUREMENT-generation-15-2026-09-24.md`). Raising the score threshold until a benchmark goes green is not an accepted route | IN EFFECT. The 2026-09-25 operator decision "Turn answering OFF, keep semantic search" is recorded in the umbrella carriers; this entry restates the condition for turning it on. **Amended 2026-10-21:** the two-sided gate now has ratified numbers (recall lower bound at least 0.4, fabrication upper bound at most 0.02, at least 60 recall and 189 fabrication trials), and hosted providers are allowed for the measurement under conditions: `OPERATOR-DECISIONS-2026-10-21.md` D-05 and D-06 |
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
| D-TITLES | Display titles for the three books | Draft titles from the PDF metadata title field, confirmed by the operator in `books.json`; file names are never shown. **Amended 2026-10-21 (`OPERATOR-DECISIONS-2026-10-21.md` D-03): blank ONLY the titles that look like file names (those sections show no title)** (implemented on the branch `cat-titles`, pending review) |
| Audit failure mode | Spec 011: should an audit-write failure fail closed or fail open? | Fail closed is implemented as an unreviewed default pending operator confirmation (`docs/providers.md` in `workshop`) |

## 8. Further records for 2026-10-20

Items found in the repository or relayed in the brief that the first revision omitted. "Brief" means the
task brief the orchestrator relayed; nothing marked "brief only" has a repository record in the files read.

| ID | Item | Source | Status |
|---|---|---|---|
| X-01 | **LAN provider refuses public and link-local addresses.** A `lan` row requires every resolved address to be loopback, private (RFC 1918 or RFC 4193) or shared (RFC 6598); public addresses are refused, and so are link-local ones (169.254/16, which holds the cloud metadata endpoint, and fe80::/10). No `-answer-allow-remote` exists on this path | `workshop` `pkg/answer/locality.go` lines 143 to 190 (the `isLANAddr` and `verifyLAN` text names the decision "an UNCONFIRMED operator decision"); spec 011 `tasks.md` T015-T018 note (line 253) | Implemented as a stricter-than-spec default, **UNRATIFIED**. **The two sources disagree on link-local:** the T015-T018 note lists "loopback/private/link-local/RFC 6598" as accepted, the code does not accept link-local. The code governs and the operator guide follows it |
| X-02 | **Spec 014 FR-007 amended:** the waiting queue is capped at 50; beyond that the oldest waiting toast without a study link is dropped (the oldest overall if all carry one), counted and observable. This replaces "never dropped" for the extreme case | spec 014 `spec.md` FR-007 note "Reconciled by S3 review fix L2, 2026-10-20"; `contracts/achievement-components.md` | Applied by stream S3 after review; **UNRATIFIED** by the operator |
| X-03 | **Release 0.0.2 was cut and deployed.** Tags `vasic-1.0.0-dev-0.0.2`: `workshop` at `30e61ad` (an evidence-and-notes commit on top of the released source `e16a196`; tag object dated 2026-10-20 22:17:17 +0200) and the umbrella tag, whose object resolves to the umbrella commit `368ab84` (tag object dated 22:41:39 +0200). Build id `e16a196-20261020T165046Z`, binary sha256 `f0018b012ba25fd1796330078e025da3e9586bb2859b293c6d0baa89950e0022`, bundle hash `2e9831ed...` (181 files). Deployed to the live stack on 2026-10-20 at 22:16 CEST (time from the brief only; consistent with, not proven by, the workshop tag time). Verdict: 26 PASS, 3 FAIL (baseline-identical, waived with evidence), 5 UNDETERMINED | `workshop` `evidence/release/0.0.2/MANIFEST.json`, `verdict.json`, `docs/releases/0.0.2.md`; `git for-each-ref refs/tags` in both repositories | IN EFFECT. Procedure: `docs/releases/ADDING-A-RELEASE.md` (revision 2). Whether the live container is serving that build now was not re-read here; it was superseded by 0.0.3 and 0.0.4 (X-04) |
| X-04 | **Release 0.0.3 was cut and deployed, then release 0.0.4.** *As first written (2026-10-20) this row said 0.0.3 was pending with no tag; that is false by 2026-10-21 and is replaced.* Tags (checked with `git for-each-ref` on 2026-10-21; both on both remotes per the brief): `vasic-1.0.0-dev-0.0.3` at `workshop` `1cf59de` (build commit `d6b988e`) and umbrella `4c7a1d2`; `vasic-1.0.0-dev-0.0.4` at `workshop` `675ca48` (build commit `cbe4628`) and umbrella `de2761b`. 0.0.3's verdict says `BLOCKED` (two non-server findings N1, N2); it shipped on a **delegate waiver, not an operator decision** (`OPERATOR-DECISIONS-2026-10-21.md` W-01), and N1 and N2 were fixed in 0.0.4 | `workshop` `evidence/release/0.0.3` and `0.0.4` (`verdict.json`, `MANIFEST.json`), `docs/releases/0.0.3.md`, `0.0.4.md`; tag objects | IN EFFECT (done). Whether the live container serves 0.0.4 now was not re-read by D1 |
| X-05 | **Practice-answer restart pass moved server-side** (so the restart decision is not made in the browser), citing 11.4.250 (a primitive defect behind a tower of heuristics) | brief only; spec 016 `tasks.md` records stream S2's practice-answer work (server-side read-back across a reload) but the 11.4.250 citation was not found there | DELEGATE-DEFAULT, **UNRATIFIED**; where it is recorded is **UNCONFIRMED** |
| X-06 | **The practice question bank has 0 `easy` items** (292 questions: 113 medium, 179 hard). What to do about cold-start content is an open content decision | spec 013 `spec.md` cold-start edge case and the D5 note (measured at `workshop` `33e9760`) | OPEN when written; spec 013 says cold-start must not serve a medium-or-harder item as if it were easy. **Amended 2026-10-21: ACCEPTED as it is (`OPERATOR-DECISIONS-2026-10-21.md` D-07)** |
| X-07 | **The S12 promotion scripts are the canonical promoter; the registry lock is shared through the H2 hardening branch** | brief only; spec 019 `tasks.md` records stream S12's promotion work on branch `s12-019-promotion` (`scripts/promote-web.sh`, 13/13 mutants caught). Neither "canonical" nor the H2 lock sharing was found as a decision in the files read | DELEGATE-DEFAULT, **UNRATIFIED**; **UNCONFIRMED** where recorded. The promotion scripts are not on `main`, so the release procedure does not use them |

Further records of 2026-10-21 (decisions D-01 to D-09, the 0.0.3 waiver W-01, the releases and the two data commits) are in `OPERATOR-DECISIONS-2026-10-21.md`.

Participants (11.4.104): the operator; the orchestrating agent acting as delegate; streams S1, S2, S3,
S4, S6, S10, S12, H1 to H4 and D1 by the names the task briefs use. Track, alias and model/effort of each
stream: `UNDETERMINED` beyond D1 (above).
