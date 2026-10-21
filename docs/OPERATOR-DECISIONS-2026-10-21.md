# Operator decisions and requests: 2026-10-21

| | |
|---|---|
| Document | Operator-request-history record for 2026-10-21, continuing `OPERATOR-DECISIONS-2026-10-20.md` (which it amends, see part 6) |
| Constitution | 11.4.208 (request-history ledger), 11.4.210 (zero-loss intake), 11.4.61 (metadata table and table of contents), 11.4.6 (no guessing), 11.4.104 (participant attribution) |
| Revision | 1 (2026-10-21) |
| Author | Documentation stream D1 (a Claude agent), from the task brief relayed by the orchestrator and from the repository facts named in each row |
| Status | Draft for independent review (11.4.142). Not reviewed |
| Timezone | Clock times are `+0200` and appear only where a git object carries them (tag objects, commits) or where the brief gives one; otherwise no time is invented |
| 11.4.208 fields | Track: documentation (stream D1). Alias: `claude3` (inferred from the user-scope configuration directory this session loaded, `UNCONFIRMED` by the operator). Model of the author: Sonnet 5.5; effort `UNDETERMINED` (not stated in the brief). Model and effort of the orchestrator and of the other participants named below: `UNDETERMINED` (not in any file read) |
| Sources | The task brief (every row marked "brief"); `workshop` tag objects and commits; `workshop` `evidence/release/0.0.3` and `0.0.4` (`verdict.json`, `MANIFEST.json`, `logs/`); `workshop` `evidence/textbooks/textbooks-c8adbd3ca35d/registry-summary.live.json`; `docs/releases/0.0.3.md` and `0.0.4.md`; `specs/026-spec-reconciliation/spec.md`; `workshop` `main` flag definitions |
| Content boundary | Public repository. No credential, no key value, no textbook or recording text. Variable **names** appear where a decision names them; no value does |

## Contents

1. [How to read this record](#1-how-to-read-this-record)
2. [Operator decisions D-01 to D-09](#2-operator-decisions-d-01-to-d-09)
3. [Waiver record W-01: release 0.0.3 shipped over a BLOCKED verdict](#3-waiver-record-w-01-release-003-shipped-over-a-blocked-verdict)
4. [Releases and data commits of the day](#4-releases-and-data-commits-of-the-day)
5. [Standing exclusion](#5-standing-exclusion)
6. [Amendments to the 2026-10-20 record](#6-amendments-to-the-2026-10-20-record)
7. [Participants and what is not known](#7-participants-and-what-is-not-known)

## 1. How to read this record

* **Wording.** The operator's own typed words are not visible to the agent that wrote this record. Each
  decision below is **paraphrased from the brief** unless a row says it quotes a file. No quotation
  has been invented.
* **Who decided.** *Operator* means the operator personally. *Delegate* means the orchestrating agent
  acting under the standing approval (OR-02 of the 2026-10-20 record); a delegate decision is amendable
  by the operator. Section 3 is a **delegate waiver, not an operator decision**, and is kept apart from
  the decisions for that reason.
* **Status vocabulary.** DECIDED (operator), RATIFIED (an earlier delegate default the operator has now
  confirmed), DEFERRED (the operator put it off), APPROVED-NOT-EXECUTED (the operator approved an action
  that had not been carried out when this was written), OPEN (investigation or decision continues),
  IN EFFECT (a standing rule).
* **Verification.** "Checked" means the cited file or git object was read by the author of this record
  on 2026-10-21. "Brief" means the statement comes from the brief only and was not re-read from a
  repository file or the live stack; the **live-stack facts of this day (restarts, embedding totals,
  the state of the live registry) are all brief-only here: UNCONFIRMED by this record.**

## 2. Operator decisions D-01 to D-09

| ID | Date | Decision | Wording | Status |
|---|---|---|---|---|
| D-01 | 2026-10-21 | **Push of the registry data to the private `workshop` remote: approved, and done.** The two data commits (part 4) are on the remote `main`. After the push the remote `main` is `827e79e` | paraphrased (brief). The remote head `827e79e7fbd1cfcb6a54e3462327d154d4cf5b20` was **checked** with `git ls-remote origin refs/heads/main` | DECIDED; executed |
| D-02 | 2026-10-21 | **Rotation of the `milosvasic` account password: deferred.** The live account still carries the tracked example password hash. A production-mode boot (`WORKSHOP_ENV=production`) would therefore refuse; under the live configuration (no `WORKSHOP_ENV`) it boots. The rotation is listed as an operator action in the 0.0.3 and 0.0.4 verdicts | paraphrased (brief). The refusal under production mode and the operator-action wording are **checked** in `docs/releases/0.0.3.md` ("Pre-deploy safety") and `evidence/release/0.0.4/verdict.json` (`operator_actions`; the check `pre-deploy: H3 production boot guard vs live auth store` is `UNDETERMINED`, "operator action carried over: rotate with workshop-passwd") | DEFERRED. Until it is done the credential is publicly derivable (the release notes say so) |
| D-03 | 2026-10-21 | **Blank only the filename-shaped textbook section titles.** Amends D-TITLES of spec 020: where a section's title is shaped like a file name, it is shown blank; titles that are real words are kept. Implemented on the branch `cat-titles`, **pending independent review** | paraphrased (brief). The branch was not read by the author | DECIDED; implementation pending review. Amends D-TITLES (part 6) |
| D-04 | 2026-10-21 | **Delete the untracked directory `submodules/constitution/submodules/kedge`.** Approved; **not yet executed** when this was written. It is untracked inside the constitution submodule (`git status --short` in `submodules/constitution` prints `?? submodules/kedge/`, **checked**); deleting it does not touch tracked content, and nothing is pushed to the constitution repository | paraphrased (brief) | APPROVED-NOT-EXECUTED. Carried out by the orchestrator |
| D-05 | 2026-10-21 | **Answer-gate thresholds ratified.** Answering may be turned on only when a two-sided measurement meets all of: **recall lower bound at least 0.4**, **fabrication upper bound at most 0.02**, with **at least 60 trials for recall and at least 189 for fabrication**. These are the numeric form of RD-01 of the 2026-10-20 record | paraphrased (brief) | RATIFIED. Answering stays OFF until a measurement meets them |
| D-06 | 2026-10-21 | **Hosted providers OpenAI and Anthropic are allowed** for (a) the answer-gate measurement of D-05 (spend cap about **20 US dollars per provider**) and (b) the spec 022 on-demand material generation. Conditions: **default OFF**; enabled only through the explicit remote opt-ins (`-answer-allow-remote`, and `-material-allow-remote` for spec 022); a **per-request acknowledgement** by the learner or operator; a **writable audit log**. The keys come from the operator's own environment file, through the variable names **`ApiKey_OpenAI`** and **`ApiKey_Anthropic`**, which the operator must add: neither name is present in that file today (**checked** by name only: a count of lines defining each name returned 0; no value was read). No key is read, printed or stored by any document or test | paraphrased (brief). `-answer-allow-remote` is **checked** on `workshop` `main` (`cmd/workshop-server/main.go`, default `false`, env `WORKSHOP_ANSWER_ALLOW_REMOTE`). `-material-allow-remote` exists on the in-flight branch `s17-022-material` and **not** on `main` (checked by name search); the audit log, the acknowledgement and the spend cap are brief-only, **UNCONFIRMED** in code | DECIDED. Supersedes the 2026-10-20 default that no hosted provider is used. The token rule (OR-04) still bars any model over recordings, transcripts or textbooks. Standing exclusion in part 5 |
| D-07 | 2026-10-21 | **Question-bank cold start accepted.** The bank has 0 `easy` items (292 questions: 113 medium, 179 hard); the cold-start behaviour of spec 013 (never serve a medium-or-harder item as if it were easy) is accepted as it is, and no easy items are authored now | paraphrased (brief). The counts are those of D5 in the 2026-10-20 record (measured at `workshop` `33e9760`) | DECIDED. Closes X-06 of the 2026-10-20 record |
| D-08 | 2026-10-21 | **The delegate decisions of spec 026 are ratified as taken:** O-2 (ability score per area), O-3 (a modal only for level-up and chapter-complete), O-4 (build kind-easing, server-side, owner spec 013), O-5 (`chapter-complete` means all lessons in an area completed), O-6 (textbook merge approved, reranker off until a two-sided regression passes), O-7 (the spec 011 FR-005 audit-schema clarification counts as resolved), O-8 (graded questions join adaptive practice per question after the session attempted them in the assessment), **and the crossref floor** (a single noise floor at quantile 0.90, value 0.6391, applied at the next crossref derivation). Each is marked **ratified 2026-10-21** | paraphrased (brief). The text of each choice is as recorded in parts 3 and 4 of the 2026-10-20 record | RATIFIED for O-2 to O-8 and the crossref floor. **Not** covered by this ratification: X-01 (LAN link-local), X-02 (spec 014 FR-007 queue cap), X-05, X-07 and the open items D-PDF, D-DIAG, D-EMB, D-SVG and the audit failure mode: they stay as the 2026-10-20 record has them |
| D-09 | 2026-10-21 | **Redacted rows blanked in the tracked live registry: investigate first and leave the tree dirty.** At 04:45 on 2026-10-21, 1,108 redacted registry rows were found blanked in the tracked live registry (`curriculum/passages.jsonl`). The cause is **unexplained**. The row count is unchanged. A preserved copy exists in the operator's backup directory. The operator's choice: **investigate first, and leave the working tree dirty** (no restore, no commit) until the investigation concludes | paraphrased (brief). The 04:45 time, the count of 1,108, the unchanged row count and the preserved copy are all brief-only: **UNCONFIRMED** by this record | OPEN. Investigation in progress. **This record names no culprit and offers no cause**; any statement of cause belongs in the investigation's own record |

## 3. Waiver record W-01: release 0.0.3 shipped over a BLOCKED verdict

| Field | Value |
|---|---|
| ID | W-01 |
| Kind | **Orchestrator (delegate) waiver. Not an operator decision.** Amendable by the operator |
| What | Release `vasic-1.0.0-dev-0.0.3` was tagged and deployed (the deployment is brief-only; the tags are checked in part 4) although its machine verdict (`evidence/release/0.0.3/verdict.json`) says `overall: BLOCKED` |
| Blocking findings | **N1**, a test-isolation defect; **N2**, six exempt registry rows missing (the verdict's words: "a test-isolation defect and six missing registry rows"). **Checked** in `verdict.json` `blocking_assessment`: "Neither touches the server binary or web bundle", both in non-server files of stream S4 |
| Reasoning for the waiver | Both findings are in files that are not part of the deployed server binary or web bundle, so the built artifacts stayed the candidate (the `blocking_assessment` text says so). The verdict also lists 3 baseline-identical `FAIL`s needing explicit waivers and `UNDETERMINED` checks that are environment-only (**checked**: 29 `PASS`, 5 `FAIL`, 4 `UNDETERMINED`) |
| Resolution | N1 and N2 were fixed on the integration branch and release **0.0.4** was cut (part 4). 0.0.4's own verdict is `RELEASABLE_WITH_WAIVERS_PENDING_ORCHESTRATOR_DECISION_ON_ingest-textbooks-test_FLAKE` (**checked**): 27 `PASS`, 2 `FAIL` (both under baseline waivers), 7 `UNDETERMINED`, 1 `FLAKY` |
| Why it is recorded here | `verdict.json` is **not edited**: it keeps saying `BLOCKED`, so a later reader can see the tool's verdict and the waiver separately. The rule for shipping over a verdict is now in `docs/releases/ADDING-A-RELEASE.md` revision 3 (part 4, step 3) |
| Who/when | The orchestrating agent, 2026-10-21, before the 0.0.3 tags at 00:51 (`+0200`; the tag object times in part 4). The exact moment of the waiver is not in any file read: `UNDETERMINED` |

## 4. Releases and data commits of the day

All rows **checked** against the git objects on 2026-10-21 unless marked brief.

| ID | Event | Detail |
|---|---|---|
| R-01 | Release `vasic-1.0.0-dev-0.0.3` | Tag objects on both repositories, annotated. `workshop`: object `4e5a231` peeling to `1cf59de` (tag time 00:51:23 `+0200`). Umbrella: object `05322da` peeling to `4c7a1d2` (00:51:40). Build commit `d6b988e` (MANIFEST). The tag commit differs from the build commit by evidence and notes only (`git diff --stat d6b988e 1cf59de` outside `evidence/release/` and `docs/` is empty). Pushed to both remotes (brief) |
| R-02 | Release `vasic-1.0.0-dev-0.0.4` | `workshop`: object `21d1e16` peeling to `675ca48` (03:13:20). Umbrella: object `5f6ac84` peeling to `de2761b` (03:13:43). Build commit `cbe4628`. Between the build and the tag commit three non-product files differ (`wire_hooks_test.go`, `platform/gates/.cross-registry-attribution-allow`, `scripts/prove-wire-hooks.sh`); `platform/frontend` and every non-test backend file are identical (**checked**). Contents, from `docs/releases/0.0.4.md` (**checked**): the S13 textbook library UI (`/textbooks`, `GET /api/textbooks*`), the S7 ingest script (script level, not part of the served artifact), and the fixes for N1 and N2 of W-01 |
| R-03 | Tags on remotes | Both releases are tagged on both remotes (brief). The tag objects above exist locally (**checked**); the remote tag lists were not re-read by this record |
| DC-01 | Data commit `576f8d6` (`workshop`, 03:29:06 `+0200`) | Ingest of the 3 licensed textbooks into the registry: **+1,675** `textbook_section` rows, **34,817 to 36,492** rows, applied to the live registry with `scripts/ingest-textbooks.sh apply`. Licence basis `operator-directed 2026-10-20`. Evidence under `evidence/textbooks/textbooks-c8adbd3ca35d` (counts only). **Checked** in `registry-summary.live.json`: `rows 36492`, `scoped_textbook_rows 1675`, registry sha256 `d7b4a38662c2dfa0bcde7d743b859e89f4ca284f36c51644fb733d3597fa9bb1` |
| DC-02 | Data commit `827e79e` (`workshop`, 03:51:28 `+0200`) | Textbook catalogue in the server's shape: `curriculum/textbooks/books.json` (schema 1), `books.expected.json`, generated `catalogue.json`; `books=3 sections=1675`. This is the commit that is the remote `main` (D-01) |
| LV-01 | Live restarts after the data commits | Brief-only: the live server was restarted and booted `books=3 sections=1675 state=present`, and all **35,384** embeddable passages were embedded. **UNCONFIRMED** by this record (no live probe was made) |

The 2026-10-20 record's OR-03 ("whether the ingest and restart have been executed is UNCONFIRMED") and
X-04 ("release 0.0.3 is pending, no tag") are **superseded** by DC-01, DC-02, LV-01 and R-01 (part 6).

## 5. Standing exclusion

**`ApiKey_TypeSafe` is never touched or used** by any agent, script or document of this project, **until
the operator says that the decisions model is fully incorporated.** This holds for D-06 and for
everything else: the hosted-provider keys of D-06 are only `ApiKey_OpenAI` and `ApiKey_Anthropic`, and
only once the operator has added them. The variable is named here so that the exclusion is
unambiguous; its value was not read by the author and is not recorded anywhere. Status: IN EFFECT.

## 6. Amendments to the 2026-10-20 record

Cross-links added to `OPERATOR-DECISIONS-2026-10-20.md` (revision 3):

| 2026-10-20 item | Amendment |
|---|---|
| RD-01 (answering stays OFF unless a two-sided gate passes) | The gate now has ratified numbers: D-05 |
| O-2 to O-8, crossref floor | Ratified 2026-10-21: D-08 |
| O-6 (textbook merge) | The merge is executed: DC-01, DC-02; the live effect is LV-01 (brief-only) |
| OR-03 (ingest and restart) | Executed: DC-01, DC-02, LV-01 |
| X-04 (release 0.0.3 pending) | Superseded: R-01 and R-02; 0.0.3 shipped over a `BLOCKED` verdict under W-01 |
| X-06 (0 easy items) | Accepted: D-07 |
| D-TITLES (display titles) | Amended: D-03 (blank only the filename-shaped titles) |

## 7. Participants and what is not known

Participants (11.4.104): the operator; the orchestrating agent acting as delegate (it granted W-01);
documentation stream D1 (author); the streams that produced the releases (S4, S7, S10, S13 and the
hardening streams) by the names the task briefs use. Model and effort of every participant other than the
author: `UNDETERMINED`.

Not known to this record, stated rather than guessed: the cause of D-09; whether D-04 has been carried
out; the live stack's present state (LV-01); how the `cat-titles` branch (D-03) decides that a title is
"filename-shaped"; whether the audit log, per-request acknowledgement and spend cap of D-06 exist in code.
