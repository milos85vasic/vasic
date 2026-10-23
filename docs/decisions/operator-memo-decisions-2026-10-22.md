# Operator memo decisions: orchestrator defaults, 2026-10-22

| Field | Value |
|---|---|
| Revision | 1 |
| Date | 2026-10-22 |
| Status | **Adopted by orchestrator under operator ruling (2026-10-22), open to overturn.** Every choice below is the memo's own recommendation, or an "orchestrator pick" (most conservative, OFF-by-default, reversible) where the memo gives none. The operator may overturn any of them. |
| Author | Claude agent (decisions-record compile task); read-only on all source trees |
| Not done | No source tree was edited, no spec/task box was ticked, nothing was committed, `:8087`, the live registry and every credential were not touched |
| Evidence limit | Task status ("tick" or "keep blocked") is stated from the cited text only. Nothing was re-run. Whether a later commit already answered an item was not re-checked unless a row says so (UNCONFIRMED otherwise). |

Source path aliases used below:

| Alias | Path |
|---|---|
| MEMO | `$TMP/reviews/decision-memos-011-015.md` |
| WT | `$WT/n7-integration/docs/decisions/` |
| ANS | `$WT/qa-candidate/docs/decision-memo-answering-primitive.md` |
| KD | `$WT/qa-candidate/evidence/qa-candidate/KNOWN-DEFECTS.md` (section "Open operator decisions", lines 175-193) |
| S | `$REPO/specs/` |
| REV | `$TMP/reviews/` |

Convention for "consequence": **TICK** means the decision removes the only stated blocker, so the task may be ticked once its own evidence exists. **KEEP BLOCKED** means the task stays unticked. "How to overturn" is one line.

Memo count: **36 decision ids (D1-D36)**, of which D18 and D35 are already decided elsewhere and recorded for completeness (34 open-to-overturn picks), plus 8 older operator-blocked items with no memo (section 6) and the non-memo blockers (section 7).

---

## 1. Specs 011, 014, 015 (source MEMO)

### D1. Spec 011 FR-011 (T022): how the active answering provider changes without a restart
* Source: MEMO:11-33; task `S/011-multi-provider-llm-providers/tasks.md:157` (T022 BLOCKED, US4); KD:180.
* Question: by what interaction surface may an operator change the provider at runtime? Today it is fixed at boot (MEMO:13-17).
* Options: A SIGHUP re-read; B authenticated admin HTTP endpoint (e.g. `PUT /api/admin/answering/provider`); C config-file watch; D settings screen as front end for B (MEMO:21-26).
* **Recommended (as written, MEMO:28): B, surfaced by the existing provider settings screen (D).** Reason given: only B records "an authenticated operator chose this, at this moment", and a failed switch keeping the old provider (FR-013) follows from construct-health-check-then-swap.
* Consequence: T022 becomes implementable (scope per MEMO:31-33: 1 route, 1 atomic holder swap, 1 audit record kind `provider_switched` with names only, FR-013 test). It depends on the spec 023 admin role gate (MEMO:24). T022 stays unticked until built; US4 stays out of the delivery path until D2 is also adopted.
* How to overturn: name option A, C or "defer" and T022/T023 return to BLOCKED.

### D2. Spec 011 FR-012 (T023): fate of an in-flight `/api/ask` job when the provider switches
* Source: MEMO:35-55; `S011.../tasks.md:158` (T023 BLOCKED); KD:181.
* Question: finish, cancel, or locality-dependent?
* Options: A finish on old provider; B cancel with a distinguishable terminal status; C locality-aware (finish when old provider is local/LAN, cancel when old provider is remote/hosted) (MEMO:47-50).
* **Recommended (MEMO:52): C.** Build constraint stated in the memo: snapshot the provider once at the start of a run (MEMO:41-43). SC-007 holds under all three (MEMO:55).
* Consequence: T023 becomes implementable together with T022; needs a new terminal status (e.g. `cancelled_provider_switched`) in the job state machine and UI vocabulary (MEMO:49). Keep unticked until built.
* How to overturn: pick A (simplest, but egress continues until `-answer-timeout`) or B.

### D3. Spec 011 T009: audit-write failure is fail-closed; keep the stricter `lan` address policy
* Source: MEMO:57-67; `S011.../tasks.md:103` (T009 already `[x]`, marked "unreviewed default pending operator confirmation"); KD:182.
* Options: (1) confirm fail-closed; (2) fail-open with a loud warning (MEMO:60-62).
* **Recommended (MEMO:62-63): confirm fail-closed**, and keep the `lan` policy (MEMO:66-67).
* Consequence: no code change (MEMO:63-64). Only the word "unreviewed" is removed from `docs/work-register.md` and `S011.../tasks.md` (not done here; those trees are read-only for this task). T009 stays ticked.
* How to overturn: choose fail-open; this reopens `pkg/answer/audit.go` behaviour and §11.4.252 posture.

### D4. Spec 015 FR-022 (T043): is per-format progress ever blended into one score
* Source: MEMO:69-86; KD:183.
* Options: A never blend (what ships); B blend with documented weights; C per-format default plus opt-in overall view with visible weights (MEMO:78-82).
* **Recommended (MEMO:84): A for now.** B/C only once real cross-format usage exists to calibrate weights against; extension point is `profile_sources.go` (MEMO:85-86).
* Consequence: T043 / FR-022 closes as "attribution only"; nothing to build. TICK on its own evidence.
* How to overturn: choose B or C; adds a weighting policy that is product policy, not derivable from code (MEMO:81).

### D5. Spec 014 FR-007/008/009: ratify the toast numbers
* Source: MEMO:90-98; KD:184.
* Numbers: `maxVisible 2`, `coalesceWindowMs 4000`, `adjustedDebounceMs 30000`, `maxCoalesceSpanMs 30000`, `maxQueued 50` (MEMO:92).
* **Recommended (MEMO:96-97): (1) ratify as they are.** They are injectable through `ACHIEVEMENT_TOAST_CONFIG`, so later change touches no state machine (MEMO:93-94).
* Consequence: only the two `[NEEDS CLARIFICATION]` markers at `spec.md` lines 87-88 of spec 014 can be removed (MEMO:98); no code waits. Nothing to tick.
* How to overturn: give different numbers; one config edit.

---

## 2. Part II security and identity (source WT, builder n7-w4-partii and X2)

### D6. FR-295 / OQ-16: shared user store
* Source: `WT/shared-user-store.md` (Status line 5: OPEN; Options table; Recommendation at line 28); `$WT/n7-integration/evidence/n7/w4-report.md:12`; KD n/a.
* Question: how do the two modules authenticate against one independently-provisionable store?
* Options: A one SQLite file both processes mount; B small identity HTTP service; C per-module stores plus a sync job.
* **Recommended (as written, `shared-user-store.md:28`): A, behind the existing `pkg/authhttp.UserStore` seam.** Do not choose C (two sources of truth, unreliable revocation).
* Consequence: FR-295 stays MISSING until A is implemented (not done by this record). It is a precondition for D7. Open sub-questions recorded in the memo (file location, canonical hash scheme bcrypt vs Argon2id, whether `authkit` is published first, FR-024..026) are **not** decided here; orchestrator pick for them: keep bcrypt `auth_user` canonical with rehash-on-login, and keep the standalone gate red on the authkit dependency. `ai_interviewing` is not touched. KEEP BLOCKED: FR-295 implementation tasks until the operator confirms A.
* How to overturn: name B or C (B is the only option that works across hosts, at the largest cost).

### D7. FR-309: should the audience gate apply to the primary session credential
* Source: `WT/audience-gate-primary-credential.md` (Status line 5: OPEN, "not implemented, because it depends on FR-295"; Recommendation line 22).
* **Recommended (as written, line 22): decide together with FR-295; if the shared store is built, add `module` (NOT NULL) to `auth_session` and have `UserByTokenHash(hash, module)` refuse a row minted for another module; keep `X-Authkit-Token` as the additive check.**
* Consequence: with D6 = A this becomes a required change; until D6 is built no code change (memo: "changing the credential semantics before the store decision would pre-empt FR-295"). KEEP BLOCKED: FR-309 implementation.
* How to overturn: choose single-sign-on across modules (`module IN (...)`, permission matrix is the authority), as the memo allows.

### D8. FR-304: CSRF protection for the session cookie
* Source: `WT/csrf-session-cookie.md` (Status line 5: "Decided by the builder ... reversible; flagged for operator confirmation"; Decision line 14); w4-report.md:9.
* Options: SameSite=Strict only; synchroniser/double-submit token; SameSite=Strict plus Origin check on POST/PUT/PATCH/DELETE.
* **Recommended / shipped: option 3 (SameSite=Strict + `withOriginCheck`).** Residual risk stated in the memo: legacy browsers omitting `Origin` UNCONFIRMED; proxies that rewrite `Host` need `X-Forwarded-Host`; `WORKSHOP_ALLOWED_ORIGINS` for dev proxies.
* Consequence: FR-304 is DONE on this default (w4-report.md:9); ratification only. TICK stays.
* How to overturn: choose option 2 (token), which needs SPA changes; option 3 does not preclude it.

### D9. FR-338 / SC-166: retention of the pre-purge registry backup
* Source: `WT/pre-purge-backup-retention.md` (Status line 5: OPEN; Options table; Recommendation line 28; "Needed from the operator" line 32).
* Options: 1 keep indefinitely (today); 2 time-boxed (e.g. 30 days) deletion by explicit operator-run command; 3 keep newest K=2; 4 encrypt at rest; 5 delete right after verified post-purge check.
* **Recommended (line 28-30): option 2 with a 30-day window, run only by an explicit operator command, never automatic**, plus 0600 files in 0700 directories, the backup directory git-ignored, and each deletion logging name and digest in the redaction log.
* Consequence: no deletion is performed by this record. Until the command exists, behaviour stays option 1 (memo line 32). KEEP BLOCKED: the deletion-command task (if any) until built; SC-166 is satisfied at purge time per the memo.
* How to overturn: pick 3 (K) or 5; both lose the undo.

### D10. FR-156 / SC-087: indexing `lesson_section` and `diagram`
* Source: `WT/lesson-section-indexing.md` (Status line 3: OPEN; Options lines 19-28; Recommendation line 30).
* Options: A derive `(area_id, ordinal)` key and index 35 heading-only rows; B resolve a lesson-section hit to the existing `doc_section` pid (no new kind); C amend SC-087/FR-156 to say lesson sections are served via `doc_section` and diagrams are out of scope until a diagram source exists.
* **Recommended (line 30): "B if the spec wording must stay, otherwise C. A is the most expensive and adds nothing."** The memo does not pick between B and C; **orchestrator pick: C** (spec edit only, no code, most conservative and reversible). `diagram` cannot be indexed under any option (no diagram source in any area document, line 9 of the memo).
* Consequence: SC-087 / FR-156 are re-worded rather than built; the two pinned tests (`TestKindVocabularyIsClosedAndExcludesLessonSection`, `TestT057_LessonSectionIsNotAdvertisedBecauseNothingIndexesIt`) stay as they are. The spec edit itself is not made here.
* How to overturn: choose B (mapping table plus resolver) or A.

---

## 3. Specs 024, 013, 021, 016 and 008 (sources KD, ANS, S)

### D11. Spec 024: replace the L4b heuristic layer with an entailment primitive
* Source: `ANS:50-60` (Recommendation lines 50-56, operator decides lines 58-62); KD:187; spec 027 NO-15 (`S027.../spec.md:214`).
* Options: keep L4b as the deterministic floor; run one offline NLI experiment (needs a weights download); replace.
* **Recommended (ANS:52-54): do not delete L4b; do not add new L4b rules; run the offline experiment only if the operator authorises the weights download (NO-15).** Decision rule for any replacement is fixed before the experiment (ANS:55-56).
* Consequence: the experiment is **not authorised** by this record (NO-15 default is "no new weights", spec 027 line 214), so it stays unrun. L4b stays as built, answering stays OFF; the residual 17/55 admitted fabrications (ANS:23) are accepted while answering is OFF (KD:187). KEEP BLOCKED: any weights or NLI-batching task (spec 008 T351/T073, spec 027 RG-26).
* How to overturn: authorise the weight download; the memo then lists the experiment (ANS:55-56).

### D12. Hosted provider enablement (D-06) and the answering gate inputs
* Source: KD:185 (finding "D-06" row 7); `S024.../tasks.md:54-55` (T015 benchmark v2 by a labeller other than the tuner, T016 independent review, both unticked).
* Question: when may a hosted provider row be un-forced?
* **Orchestrator pick (no memo recommendation): keep all hosted rows forced OFF.** Un-forcing needs benchmark v2 independent re-label (T015/T016) and thresholds; keys only by 0600 file; `ApiKey_TypeSafe` stays off-limits (also a standing user memory rule); production spend hook undecided.
* Consequence: KEEP BLOCKED: T015, T016 and any hosted-enable task. Local/LAN rows are unaffected.
* How to overturn: supply the independent labeller (D31, NO-16) and thresholds, and name the spend hook.

### D13. Spec 013 flashcard self-rating policy
* Source: KD:186 (row 8); `REV/n1-2026-10-21.md:60-84` (findings F1 quadratic first-attempt query, F2 self-rated flashcards inflating ability; recommendation lines 83-84); `REV/n8-n1-2026-10-22.md:32,56` (both reproduced RED then GREEN in the later review).
* Question: damp or exclude self-rated outcomes, stop re-serving answered flashcards, persist a `self_rated` marker.
* **Recommended (REV/n1-2026-10-21.md:83-84): do not serve an answered flashcard again; cap or damp the upward ability step of a self-rated outcome (e.g. K x 0.25 or no upward move); persist a `self_rated` marker; exclude self-rated rows from `RecalibrateBatch`.**
* Consequence: the policy is adopted as written. Whether the code fix already in the later review matches this exact policy is UNCONFIRMED (the n8-n1 report only states both findings turned GREEN). TICK nothing here; confirm against the built damping constant.
* How to overturn: keep self-rated outcomes counted at full weight (not recommended: ability rises without bound by time).

### D14. Spec 021 OD-2 / spec 027 NO-13: may an inferred preference influence server-side serving
* Source: `S021.../spec.md:343` (OD-2, default: no); `S027.../spec.md:212` (NO-13, default "No"); `S021.../tasks.md:271` (T048a, `[BLOCKED:013]` `[OD-2]`).
* **Recommended: No (spec 021's own default).** Kind-easing O-4 (013 T036b) proceeds separately (spec 027 line 212).
* Consequence: KEEP BLOCKED: T048a and US5 server routing bias.
* How to overturn: answer yes; T048a then still waits on 013 `ServeNext` options.

### D15. Spec 021 OD-3: ship engagement capture (US4) at all; default OFF
* Source: `S021.../spec.md:344` (OD-3, this spec's position: opt-in default OFF); `S021.../tasks.md:267` (T048 already `[x]`, consent toggle default off).
* **Recommended: ship with opt-in default OFF** (spec 021's own position).
* Consequence: T048 stays ticked; nothing further.
* How to overturn: remove US4 or change the default; T048 reopens.

### D16. Spec 021 OD-4 / spec 027 NO-11: retention versus erasure of the append-only response log
* Source: `S021.../spec.md:345-346`; `S027.../spec.md:210` (NO-11).
* **Recommended (spec 027 line 210, "state plainly"): the manual states that erasure covers spec 021's own rows only (021 FR-012); no erasure promise beyond that.** The legal regime for the Jordan-based client is UNCONFIRMED (spec 021 line 346).
* Consequence: KEEP BLOCKED: any task that promises erasure of the response log (013 FR-003 forbids mutation).
* How to overturn: obtain a legal ruling; then an erasure-versus-audit policy can be specified.

### D17. Spec 021 OD-5 / spec 027 NO-12: instructor or consultant visibility of participant signals
* Source: `S021.../spec.md:347-348`; `S027.../spec.md:211`.
* **Recommended: none; own-data only** (spec 027 line 211). Needs spec 023 roles and a consent model first.
* Consequence: KEEP BLOCKED: any instructor view.
* How to overturn: decide after spec 023 roles are merged and a consent model exists.

### D18. Spec 021 SC-009 power wording: confirm the reword
* Source: `S021.../spec.md:278` and `:342` (OD-1 RATIFIED 2026-10-21, option (a): power >= 80% at 120 graded answers per format; SC-009 reworded); KD:179 (row 1 asks to confirm the spec text was actually reworded).
* **Recorded outcome: already decided and visible in the spec text (lines 278, 342).** The commit `509ba74` in the umbrella log ("021 SC-009 power/null wording (option a ratified)") is consistent with it; the earlier KD:179 doubt is **answered by those lines**, not by re-running anything.
* Consequence: nothing further; counted here for completeness, not as an open memo.
* How to overturn: choose option (b) or (c) of research.md 3.1.

### D19. Spec 016 / 002: what `floor_calibrated` means, and whether the cross-reference cut-off may ship ON
* Source: definition: `S001.../contracts/http-api.md:896` ("true only when a calibrated per-kind score cut-off was applied to EVERY traversed source kind (spec 016)"); rule I7 at `:252` (an uncalibrated floor cannot support a `no_match`, so it renders with a calibration caveat); search envelope `S002.../spec.md:96` ("uncalibrated ... reports `floor_calibrated: false` and nothing is demoted"); open follow-up `S016.../tasks.md:690-703` (T045c, FR-006 / SC-004 UNTICKED; shipped quantile q=0.95 "ships OFF by operator decision"; step (4) "operator ratification of the quantile before any default changes").
* Plain meaning: `floor_calibrated: false` is the honest default; it flips to `true` only when a measured per-kind cut-off was applied to every kind traversed. It is **not** a quality score.
* **Orchestrator pick (the memo-style source gives no option set beyond step 4): keep the cut-off OFF and `floor_calibrated` false; do not ratify q=0.95.** Reason from the source: the null is wrong for a ranked list (the best of about 8,700 targets clears it about 99% of the time, 88% in a no-relationship control; `:693-697`).
* Consequence: KEEP BLOCKED: T045c / FR-006 / SC-004 until a labelled sample of at least 385 and a ranked-selection null exist.
* How to overturn: ratify a quantile after the evidence in T045c items (1)-(3) exists.

### D20. Spec 008 OR-04 versus the OCR-over-video chain (T449-T465), NO-1b
* Source: `S027.../spec.md:200` (NO-1b); `S027.../contracts/requirement-register.md:23` (RG-48); KD:190 (row 12); OR-04 text at `$REPO/docs/OPERATOR-DECISIONS-2026-10-20.md:51`.
* **Recommended (spec 027 line 200): keep unbuilt, because it processes recordings, which OR-04 names.**
* Consequence: KEEP BLOCKED: spec 008 T449-T465 and the `screen_text` kind.
* How to overturn: rule that frame sampling plus tesseract is not a "vision pass".

### D21. Spec 008/002 U6: on-screen sampling period (T447 = 002/T124)
* Source: `S008.../tasks.md:2927`; `S002.../tasks.md:1746` ("operator decision, purely"; inputs recorded: segment median 6.74 s, p95 10.78 s, max 20.22 s; "the task forbids rounding to a convenient number").
* No option set in the source. **Orchestrator pick: do not choose a value; leave U6 open and the OCR chain unbuilt** (follows D20; a value chosen now would be the guess the task forbids).
* Consequence: KEEP BLOCKED: T124/T447, and downstream T126-T129 (002) / T449 onward (008).
* How to overturn: state a sampling period no coarser than the segment precision.

### D22. Spec 008/002 U7: corroboration window (T453 = 002/T130)
* Source: `S008.../tasks.md:3083`; `S002.../tasks.md:1902` ("operator decision"; "T126 must run first").
* **Orchestrator pick: leave open**; it cannot be measured until T126 (OCR output) exists, which D20 keeps unbuilt.
* Consequence: KEEP BLOCKED: T130/T453, T131.
* How to overturn: set a window after the lead/lag distribution is measured.

---

## 4. Spec 027 operator answers (source `S027-research-gap-closure/spec.md:199-220`; every default below is the spec's own stated default)

| # | Question (short) | Adopted default as written | Consequence | How to overturn |
|---|---|---|---|---|
| D23 NO-1 (`:199`) | Is local tesseract OCR over a scanned PDF a forbidden "vision pass" (OR-04)? | Allowed only per book, by explicit opt-in (flag plus per-book config key), local only, disclosed, **default OFF**. Installed packs: `eng`, `osd` only (re-measured here: `tesseract --list-langs` lists `eng osd`). | Unblocks the OCR path T031-T034 of spec 027 and the second half of 012 FR-018 (`S012.../tasks.md:253` T047); the build refuses a language whose pack is missing. Install of extra packs is a host action (section 5). | Rule OCR forbidden; scanned PDFs stay refused (exit 2). |
| D24 NO-2 (`:201`) | May a model draft questions from textbook text under an OR-04 exception? | No; deterministic TOC drafts only (FR-016, FR-017). | KEEP BLOCKED: any model question-drafting task. | Carve an OR-04 exception. |
| D25 NO-3 (`:202`) | 012 FR-020 promote: never / draft-then-accept / new kind | Draft-then-accept; nothing minted without a human accept; no new Kind. | Spec 027 T040 (accept path) proceeds. | Choose never-promote or a new kind. |
| D26 NO-4 (`:203`) | IRT shadow fit thresholds and promotion rule | Shadow-only until the operator sets numbers. | KEEP BLOCKED: any IRT promotion task (013 T052 stays shadow-only unless `Config.IRTApply`). | Supply minimum responses, tolerance and rule. |
| D27 NO-5 (`:204`) | Repeat-attempt policy `record-only` or `no-upward-change` | Spec 027 line 204 says `no-upward-change`, disclosed; FR-007 (`:138`) says the shipped default is `record-only` until the operator selects. **These two lines disagree; orchestrator pick: `record-only` for the shipped default** (FR-007, changes nothing a learner sees, most conservative), `no-upward-change` selectable. | Detector and report build regardless; switching the default stays a separate step. | Select `no-upward-change` as default. |
| D28 NO-6 (`:205`) | Who produces human-reference labels (WER strata, DER, seek error) | None assumed; gates report UNDETERMINED (exit 2); report says "no DER claim". | KEEP BLOCKED: FR-023, FR-025, FR-026 reference-dependent checks. See also human checkpoint spec 008 T207. | Nominate a labeller. |
| D29 NO-7 (`:206`) | REQ-1 exposure window | Same area, same session, event precedes the attempt; no time constant. | FR-019 tuning only; nothing blocked. | Give a time constant. |
| D30 NO-8 / NO-13 / NO-9 / NO-14 (`:207,212,208,213`) | Meaning of per-client generation; routing bias; residency copy; trust comparison author | NO-8: "audience brief" (saved topic list feeding spec 022), no tenant separation. NO-13: No (see D14). NO-9: ship the absent state (024 T072-T074 already do); 024 T078 stays forbidden to agents. NO-14: operator-authored, advisory-only. | KEEP BLOCKED: any per-client generation task (none exists), `S024` T078, any in-product comparison. | Answer each individually. |
| D31 NO-16 (`:215`) | Who labels out-of-corpus unanswerable rows | Someone other than the tuner; count not below the D-05 trial minimum. | KEEP BLOCKED: spec 027 FR-031 stratum and `S024` T015/T016 (see D12). | Name the labeller. |
| D32 NO-10 / NO-15 (`:209,214`) | Third-party skill licences; ONNX NLI weights | NO-10: adopt nothing new, adopt only items already enabled. NO-15: no new weights, keep the lexical floor plus the existing judge. | KEEP BLOCKED: tooling rows marked ADOPT-pending; any weights task (links to D11). | Authorise a licence or a download. |
| D33 NO-J1..J5 (`:216-220`) | Unresolved facts in the Jordan client document (trailing clause; Valaeon; ACS consulting; Drall platform) | J1: treat 1(c) as complete as quoted. J2: keep REQ-5 as written. J3/J4: verify from the internal record. J5: keep the generic inference labelled as inference. | No new requirement is created; J3/J4 need a human lookup (section 5). | Supply the facts. |


---

## 5. Remaining decisions with a source but a different shape

### D34. Governor anchor 279: F9 (load-aware backoff degenerating to one slot) and F12 (20-agent baseline versus 6-agent cap)
* Source: KD:193 (row 15); `REV/governor-279-2026-10-22.md` (F9, F12; not re-read for this record, UNCONFIRMED beyond the KD row).
* **Orchestrator pick: keep the existing 6-agent cap and the current backoff unchanged** (most conservative; host-safety §12). No governor edit is made.
* Consequence: `docs/heavy-work-governor.md` (currently modified in the working tree, per git status) is not touched by this record. KEEP BLOCKED: any change to the cap.
* How to overturn: choose the 20-agent baseline or a different backoff.

### D35. Release cadence (row 14)
* Source: KD:192 (row 14): "0.0.5 not cut; reports say cut when S11+S12+S16 are merged (already decided 2026-10-21)"; user memory index entry "release cadence".
* **Recorded outcome: already decided 2026-10-21; this record adds nothing.** The remaining items in that row (waivers carried from 0.0.3/0.0.4, the flaky ingest-textbooks test) are not decisions; they are work.

### D36. Spec 022 materials attach and compose turn-on (row 11)
* Source: KD:191 (row 11): attach the pipeline in `main.go`, mount the route, decide the compose turn-on path.
* **Orchestrator pick: attach and mount the route, but keep the compose turn-on OFF by default** (OFF-by-default rule), so materials are not shown until the operator sets the flag.
* Consequence: the attach and mount work may proceed; the turn-on stays off. Harness repair for the enabled e2e is work, not a decision.
* How to overturn: choose a default-on compose flag.

---

## 6. Older operator-blocked items with no memo (kept blocked; no pick is made)

These carry a BLOCKED marker in a tasks file and give no option set. Each is a content, credential or storage judgement that cannot be defaulted without guessing, so **none is adopted and all stay blocked**. Whether a later decision (for example the 2026-09-26 and 2026-10-14 operator answers) already closed any of them was not re-checked (UNCONFIRMED).

| Item | Source | Why no pick |
|---|---|---|
| Spec 005 T012, T057: documented step to fetch recorded material from outside storage; retryability check | `S005-clone-and-clear-red/tasks.md:67,71` | Needs a storage-backend choice |
| Spec 005 T020: provider verdicts for gitflic / gitverse | `S005.../tasks.md:88` | Needs `GITFLIC_TOKEN` / `GITVERSE_TOKEN` (credential) |
| Spec 005 T041 = spec 006 T060: publish or not 3 documents failing review on 62, 54, 58 uncited claims | `S005.../tasks.md:121` | Content judgement; one decision in two specs |
| Spec 006 T019: `GET /api/chapters/{id}/meeting-notes` withholding rule | `S006.../tasks.md:80` | FR-005a: "may not be guessed" |
| Spec 002 T031: prose authorship (extractive vs build-time vs run-time) | `S002.../tasks.md:321` | Human authorship |
| Spec 002 T101: where a diagram lives in the seven-section skeleton | `S002.../tasks.md:1298` | `mmdc` renders no SVG; placement undecided |
| Spec 003 T025, T033 `[BLOCKED: ordinal type]` (T006 note says the T001 decision was made in code) | `S003.../tasks.md:314,374,146` | Whether the record now exists and unblocks them was not verified |
| Spec 004 T053 (curriculum-kit as a gitlink) | `S004.../tasks.md:193` | Marked `[x]`; the umbrella `CLAUDE.md` lists `submodules/curriculum-kit` as an owned gitlink, so treated as resolved |

---

## 7. Blockers that are NOT memos (need a human act)

| Blocker | Exact command or action | Source |
|---|---|---|
| Webkit for gate 6 preflight: missing `libmanette-0.2-0`, `libwoff1` | `sudo apt-get install -y libmanette-0.2-0 libwoff1` | `$REPO/CLAUDE.md` (gate 6 section, re-measured 2026-09-22) |
| Extra tesseract language packs (needed only if a non-English scanned book is opted in under D23) | Not measured; host currently has `eng osd` only. Install of a language pack is a host package action (UNCONFIRMED package name for the chosen language) | measured here via `tesseract --list-langs` |
| Provider tokens for gitflic.ru / gitverse.ru (spec 005 T020) | Operator must issue `GITFLIC_TOKEN` and `GITVERSE_TOKEN`; none configured | `S005.../tasks.md:88` |
| `ebooklib` / `defusedxml` not in `workshop/pipeline/venv` (spec 012 T001) | A pinned install needs network, forbidden for that stream; command not recorded in the source (UNCONFIRMED) | `S012.../tasks.md:39,42` |
| Hand-truthing a transcript sample (spec 002 T132) | Human labour over a private recording; no agent can substitute | `S002.../tasks.md:1927-1929` |
| Independent re-label of benchmark v2 (spec 024 T015/T016) | A labeller agent other than the tuner, distinct agent id recorded | `S024.../tasks.md:54-55` |
| Raised WebSearch cap for R21 deep research | Raise `CLAUDE_CODE_MAX_WEB_SEARCHES_PER_SESSION` or start a new session | `$WT/qa-candidate/docs/work-register.md:208-212` |
| Suppressed-residue G5 findings (redacted passages whose words survive in other served rows) | Operator direction on triage; LAN access was already reverted to loopback | `qa-candidate/docs/work-register.md:215-222` |
| Zero-gap operator queue: timer installation, `.claude/settings.json` changes, deploys | Queued as `Operator-blocked` with exact commands in spec 010 | `S010.../tasks.md:256,434` |
| Spec 027 NO-J3 / NO-J4: identify "ACS consulting" and "Valaeon" | Look up in the internal client record | `S027.../spec.md:218-219` |
| Review gap: streams n4, n6, n7, n8, s11, s15, s18, cat-authors merged in the candidate but without an independent review report | Run independent reviews before treating any GO as current | KD:194 (row 16) |
| Stray local commit `947d402` "base" in the vasic repo (row 15) | The reviewer's suggested `git reset --mixed 0748291` was denied; any history action is an operator decision | KD:193 |
