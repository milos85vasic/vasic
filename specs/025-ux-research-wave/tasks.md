# Tasks: UX Research Wave (staged streaming answers first, then the cheap wins)

**Input**: Design documents from `specs/025-ux-research-wave/`
**Prerequisites**: `plan.md`, `spec.md`, `research.md`, `data-model.md`, `contracts/`, `quickstart.md` (all present)

**Tests**: INCLUDED and test-first (§11.4.224). Each implementation task has a preceding RED task naming its
ORACLE (§11.4.245) with the RED run pasted. Test authors, implementers and reviewers are separate agents
(§11.4.240/§11.4.249). Tests are deterministic: recorded streams, fake clocks, stubbed browser APIs, fixed
fixtures - no test depends on a live model.

## Format: `[ID] [P?] [TDD?] [REVIEW?] [SUBAGENT?] [Story] Description`

- **[P]** parallel-safe - **[TDD]** RED then GREEN then refactor - **[REVIEW]** independent review (Opus, effort xhigh,
  §11.4.142/§11.4.209) with a verdict file carrying `finding_layer` before the next dependent task - **[SUBAGENT]** delegable
- **[Story]** `US1`..`US8`, `FOUND`, `SETUP`, `POLISH`

## Path conventions (private `workshop` submodule)

- Frontend: `workshop/platform/frontend/src/app/` (`core/`, `features/<x>/`), e2e `workshop/platform/frontend/e2e/`, scripts `workshop/platform/frontend/scripts/`
- Gates: `workshop/platform/gates/`; docs: `workshop/docs/`; evidence: `workshop/evidence/025-ux-research-wave/` (each story: `result.json` + `manifest.sha256`)
- **Architecture rules**: new code in NEW files; no direct edits of `app.routes.ts`, `core/vocabulary.ts`, `cmd/workshop-server/main.go`. Hooks into hot-spot components (`inquiry.component.ts`, `transcript.component.ts`, `practice.component.ts`, `recording-player.component.ts`, `rail.component.ts`, `app.component.ts`, `app.config.ts`, `styles.scss`) are single-tag/single-block changes recorded in `hook-lines.md` and landed by the orchestrator in the order given in `plan.md`. Worktree streams NEVER run `restart.sh`/`start.sh`/`stop.sh`/`ingest.sh` against the live stack; they verify on a scratch server (`WORKSHOP_BASE_URL`).
- **Content boundary**: recorded streams and fixtures contain private corpus text and live only under `workshop/`; nothing is copied into this public repository.

---

## Phase 1: Setup (no feature code)


- [ ] T001 [SETUP] Frontend baseline: `cd workshop/platform/frontend && npm run test:unit && npx ng build && npm run check-design-system && npm run check-platform-tokens` (wrap with `scripts/agent-admit.sh`; `-m 4G`/`6G` per architecture §4). Paste counts into `workshop/evidence/025-ux-research-wave/baseline/frontend-baseline.txt`. Pre-existing failures are listed by name, not fixed here.
- [ ] T002 [P] [SETUP] Scratch servers with answering ON on free ports against an index COPY (never the live stack): one with `-answer-provider extractive` (fast phases), one with `-answer-provider ollama -answer-model qwen2.5:3b-instruct-q4_K_M` (realistic phases), using `gates/answer-eval/eval.sh --print-cmd` flag mirroring. Record command flags (no secrets) in `baseline/scratch.txt`; confirm `/api/ask/status.enabled:true` for both.
- [ ] T003 [SETUP] Capture REAL streams from the scratch servers with `curl -N -H "Authorization: Bearer $TOKEN" '.../api/ask?q=...&stream=1'` (token via `scripts/_live_auth.sh`, never printed): answered (extractive and ollama), declined (a benchmark-v1 unanswerable question), a heartbeat-bearing slow run, and `tokens=1`. Try to provoke `withheld` (suppressed passage fixture); if it cannot be provoked, write a synthetic frame and label the fixture `synthetic`. Save as `frontend/testdata/streams/*.sse` plus `streams.index.json` (file, source, provider, sha256). Privacy: private repo only.
- [ ] T004 [P] [SETUP] Re-check the browser-support facts the research document marks as dated (§7 of the document): `fetch` streaming bodies, View Transitions (`document.startViewTransition`), Media Session, `content-visibility`, `prefers-contrast`, `prefers-reduced-transparency` against the Playwright chromium and firefox builds installed (`npx playwright --version`; webkit is blocked on this host per the umbrella preflight - record it as NOT TESTED). Output `baseline/browser-support.md` with the feature-detection snippet each story will use.
- [ ] T005 [SETUP] Performance baseline on the largest real transcript: `e2e/perf/transcript-baseline.spec.ts` (Chromium tracing via `page.context().tracing` + `PerformanceObserver` for `event` timing = INP proxy, long tasks, layout/script durations), 5 cold loads + scripted scroll + 5 anchor jumps. Write `baseline/perf.json` with row count, DOM node count, medians and spread. No target is set from it in this task (decision D3). Register the 5-run job as a long-op (§11.4.232).
- [ ] T006 [P] [SETUP] Accessibility baseline: axe-core on `/ask`, `/practice/:slug`, `/chapters/:slug/transcript`, `/passage/:pid` (desktop + 390 px); confirm UNCONFIRMED items U32 (does the transcript pane scroll internally? is it keyboard-scrollable?) and U35 (24x24 target size for passage click targets) by measurement. Output `baseline/a11y.json` + `baseline/findings.md`; each failing item becomes a TRACKED finding (§11.4.261), not a silent fix.
- [ ] T007 [SETUP] Hook map: for each hot-spot file list the exact insertion point (line, template region or style block) for this spec's single hook, with current line counts (`inquiry.component.ts` 1,826; `transcript.component.ts` 1,204; `rail.component.ts` 559 at spec time) in `hook-lines.md`; confirm the order with spec 024's banner hook (this spec's US1 first).
- [ ] T008 [SETUP] Confirm the spec 026 status for MMR: `ls specs | grep 026`; at spec time it does not exist, so P3 stays OUT. Record the check date in `baseline/mmr-status.md`; re-check at Polish.


---

## Phase 2: Foundational (blocks all stories)

**Purpose**: the flag mechanism, vocabulary files and the pure SSE parser every story depends on.

- [ ] T009 [TDD] [SUBAGENT] [FOUND] RED: `core/ux-flags.spec.ts`. **Oracle**: `data-model.md` UxFlags (default false for all eight; localStorage override wins; throwing storage -> defaults, no exception; unknown keys ignored). Paste RED.
- [ ] T010 [FOUND] GREEN: `core/ux-flags.ts` (injectable service, signals, try/catch around every storage access). Used by every story's hook (FR-020).
- [ ] T011 [P] [FOUND] Create the vocabulary files skeleton `features/{inquiry,practice,transcript,palette,peek}/<x>-vocabulary.ts` (empty typed maps) and record the merge procedure into `core/vocabulary.ts` for the orchestrator (the existing vocabulary gate `prove-ui-vocabulary-mutation.sh` stays green with the merge).
- [ ] T012 [TDD] [SUBAGENT] [FOUND] RED: `core/sse-parser.spec.ts`. **Oracle**: the HTML Standard §9.2 SSE parsing rules, encoded as table cases written by the test author - LF/CRLF/CR line endings, comments, multiple `data:` lines, field without colon, BOM at stream start, leading single space stripping, partial chunk boundaries (every split point of a sample frame), incomplete trailing frame discarded; PLUS every recorded stream from `T003` re-chunked at 1, 7 and 64 bytes must parse to identical frames. Paste RED.
- [ ] T013 [FOUND] GREEN: `core/sse-parser.ts` (`createSseParser(onFrame)` push parser over `Uint8Array`, incremental `TextDecoder`, no allocation per byte beyond the line buffer). Paste GREEN.
- [ ] T014 [FOUND] [REVIEW] Independent review (Opus xhigh) of the foundational set: flag semantics, parser conformance vs the standard (reviewer adds 5 adversarial frames), no forbidden shared-file edits. Verdict `reviews/foundation-review.json`.


---

## Phase 3: User Story 1 - Staged honest streaming answer (Priority: P1) MVP

**Goal**: the existing backend stream on screen as honest stages (spec US1). **Independent Test**: spec US1.

- [ ] T015 [TDD] [SUBAGENT] [US1] RED: `core/ask-stages.spec.ts` for the pure reducer. **Oracle**: for every recorded stream in `T003` an EXPECTED stage list written by hand by the test author from the raw frames (not produced by running the reducer) and stored beside it as `*.expected.json`; plus the nine reducer rules of `contracts/ask-stream-client.md`; plus a phantom-stage guard (no stage whose phase never appeared). Paste RED.
- [ ] T016 [P] [TDD] [SUBAGENT] [US1] RED: `core/ask-stream.spec.ts` with a fake `fetch` returning a `ReadableStream` driven by a controllable source: token header attached; `AbortController` abort on a second question; 503 JSON body routed to the existing `normaliseAnswer` unavailable path; 401 handled as in `core/auth-interceptor.ts`; drop before `result` -> exactly ONE reconnect to `/api/ask/{job_id}/stream`, second drop -> `failed`; `response.body === null` -> synchronous fallback via `WorkshopApi.ask()`; `tokens=1` only when opted in.
- [ ] T017 [P] [TDD] [SUBAGENT] [US1] RED: `features/inquiry/answer-stages.component.spec.ts` + `draft-preview.component.spec.ts`. **Oracle**: spec FR-002/FR-003/FR-005 + the WCAG rules: single polite live region updating on stage transitions only, `button[aria-expanded]` collapse, server elapsed text visible, reduced-motion = no movement, 390 px layout, draft permanently labelled "unverified draft" and removed on `result`/`withheld`, decline renders its reason.
- [ ] T018 [P] [TDD] [SUBAGENT] [US1] RED: `e2e/ask-stream.spec.ts` (desktop + mobile chromium, axe) against the scratch servers: submit a question, assert the stage list equals the server's phases (read from the network log of the same request - the oracle is the wire), collapse/expand, decline path, answering-off path shows the existing unavailable state (no stage list), second question aborts the first, axe serious/critical = 0 in four states.
- [ ] T019 [US1] GREEN: `core/ask-stages.ts` (pure reducer `reduce(state, event) -> state`, types from `data-model.md`). Run `u1red_stages` to GREEN.
- [ ] T020 [US1] GREEN: `core/ask-stream.ts` (`AskStreamService.start(question, opts): Observable<AskStreamState>`; `fetch` + `getReader`; token from the same `AuthService` the interceptor uses; aborts on unsubscribe). Run `u1red_client` to GREEN.
- [ ] T021 [US1] GREEN: `features/inquiry/answer-stages.component.ts` and `features/inquiry/draft-preview.component.ts` (standalone, OnPush); strings in `features/inquiry/inquiry-vocabulary.ts`; motion only via tokens.
- [ ] T022 [US1] Hook: in `features/inquiry/inquiry.component.ts` replace the single `this.api.ask(question)` call site (`~L1217`) with a flag-guarded call to `AskStreamService` and add ONE `<app-answer-stages>` tag where the elapsed counter (`~L336`) sits; the existing `wait=1` path remains the fallback and the flag-OFF behaviour. Recorded in `hook-lines.md`; orchestrator lands it before spec 024's banner tag.
- [ ] T023 [US1] Run the US1 RED set (T015, T016, T017, T018) to GREEN with pasted logs; `npx ng build`; `npm run check-design-system && npm run check-platform-tokens`; unit + e2e on the scratch server.
- [ ] T024 [US1] Paired mutation (§1.1): in a throwaway copy make the reducer insert a phantom `retrieving` stage when none was reported; `T015` and the e2e wire-equality check MUST fail. Evidence `us1/mutation-phantom-stage.txt`.
- [ ] T025 [US1] Keep-alive/proxy check: replay a slow stream fixture with only 10-second heartbeats through a throttled reader; the UI shows the last real stage with elapsed time and a "still working" note from the server's `note`, never a new stage.
- [ ] T026 [US1] Screen-reader pass (manual + scripted): NVDA/Orca or the Playwright accessibility tree snapshot shows ONE announcement per stage transition and none for heartbeats; document the tool used and the result in `us1/a11y-notes.md` (UNCONFIRMED which AT is available on this host).
- [ ] T027 [US1] [REVIEW] Independent review (Opus xhigh) of the US1 diff: phantom-stage impossibility, draft handling, auth header, abort leaks (subscription cleanup), reconnect bound, forbidden shared-file edits, FR-018 compliance (no skeleton screens). Verdict `reviews/us1-review.json`.
- [ ] T028 [US1] Scenario map for the honesty-critical class "UI shows a stage/draft the server did not verify" (§11.4.239): Given/When/Then for phantom stage, draft shown then refused, withheld event, drop and reconnect, wrong job id on reconnect - `us1/scenario-map.md` BEFORE closure.
- [ ] T029 [US1] LIVE-in-scratch verification: with both scratch servers run `e2e/ask-stream.spec.ts`; capture for each run the raw SSE (`curl -N`) and the DOM stage list; `us1/result.json` rows `{check, expected(from wire), observed(from DOM), rc}` and `manifest.sha256`. Record time-to-first-stage and the server's first-event latency (numbers only, no target).
- [ ] T030 [US1] UI-VISIBLE ACCEPTANCE: give the operator the scratch/QA URL and the checklist item 1-2 in `quickstart.md`; screenshots of idle/streaming/collapsed/declined at desktop and 390 px into `us1/screens/`. The live stack shows the staged answer only when spec 024 has enabled answering - state this in the hand-off message. Operator sign-off recorded by the orchestrator, then the orchestrator flips `askStream` default ON.


---

## Phase 4: User Story 2 - Confidence before reveal (Priority: P2)

**Goal**: spec US2 (UI + session state; persistence is spec 013's).

- [ ] T031 [TDD] [SUBAGENT] [US2] RED: `core/confidence-store.spec.ts`, `features/practice/confidence-prompt.component.spec.ts`, `features/practice/calibration-note.component.spec.ts`, and a `practice.component.spec.ts` extension. **Oracle**: spec US2 acceptance 1-5 and `contracts/practice-confidence-fields.md`; the calibration classification table (correct/wrong x low/medium/high -> `high_confidence_wrong`, `low_confidence_correct`, `aligned`) written by the test author; neutral-wording assertion = no class from the danger token set and no word from a banned-copy list kept in the spec test; polite announcement.
- [ ] T032 [P] [TDD] [SUBAGENT] [US2] RED: `e2e/practice-confidence.spec.ts` (axe, keyboard-only path: select option, Tab to confidence group, choose, reveal) against a scratch server; reveal button disabled with a visible reason until confidence chosen; reload within session keeps committed confidences.
- [ ] T033 [US2] GREEN: `core/confidence-store.ts` (in-memory service keyed `areaSlug+questionId`, cleared on sign-out).
- [ ] T034 [US2] GREEN: `features/practice/confidence-prompt.component.ts` (radio group with legend, optional textarea <=500 chars, plain text) and `calibration-note.component.ts`; strings in `features/practice/practice-vocabulary.ts`.
- [ ] T035 [US2] Hook: one tag in `features/practice/practice.component.ts` before the explanation block (`~L351`) behind `practiceConfidence`; do NOT change the submit call (collision note in the contract). Recorded in `hook-lines.md`; sequence with specs 013/016 on this file via the orchestrator.
- [ ] T036 [US2] Run RED set to GREEN; ng build; design-system and token checks.
- [ ] T037 [US2] Paired mutation: a copy that reveals before confidence is set -> `u2red` and e2e must fail.
- [ ] T038 [US2] [REVIEW] Independent review (Opus xhigh): the reveal gate cannot be bypassed by keyboard or by reload, wording neutrality, no claim of server tracking, no collision with the submit path. `reviews/us2-review.json`.
- [ ] T039 [US2] LIVE-in-scratch verification + `us2/result.json` + manifest (reveal-blocked row, reveal-after-confidence row, empty-explanation row, reload-retention row, mutation row).
- [ ] T040 [US2] UI-VISIBLE ACCEPTANCE: operator performs checklist item 3; screenshots `us2/screens/`; orchestrator flips `practiceConfidence` after sign-off.
- [ ] T041 [US2] Hand-off to spec 013: append a pointer to `contracts/practice-confidence-fields.md` in 013's notes via the orchestrator (this spec edits only its own directory); record 013 task ids that should adopt the fields.


---

## Phase 5: User Story 3 - Reading and motion feel right, measurably (Priority: P2)

**Goal**: motion policy + reduced-motion substitution + contrast/transparency, `content-visibility` (conditional), view transitions (scoped).

- [ ] T042 [SUBAGENT] [US3] Write `workshop/docs/design-system/motion-policy.md` from `contracts/motion-policy-gate.md` (rules table, rationale, how to add an animation). Reviewer checks it contains no rule the gate does not enforce and vice versa.
- [ ] T043 [TDD] [SUBAGENT] [US3] RED: `frontend/scripts/check-motion-policy.test.mjs` + the prover `gates/prove-motion-policy-mutation.sh`. **Oracle**: the policy table; seeded faults (animated `width`, `will-change:*`, literal `400ms`, removed reduced-motion substitution block, `backdrop-filter` transition) each rc 1; clean control rc 0; unparsable file rc 2. Run against the CURRENT tree first and record what it finds (the existing violations become TRACKED findings, not fixed in this task).
- [ ] T044 [US3] GREEN: `frontend/scripts/check-motion-policy.mjs` (three-valued) wired as an npm script `check-motion-policy`; registry rows appended through the orchestrator (`gates/check-registry-0NN.tsv`).
- [ ] T045 [TDD] [SUBAGENT] [US3] RED: `e2e/comfort-motion.spec.ts`. **Oracle**: with `page.emulateMedia({reducedMotion:'reduce'})` computed styles of the touched components have no `transform` transition/animation and still have an `opacity` transition <= 150 ms; with `forcedColors`/`contrast:'more'` and `reducedTransparency` (where the Playwright build supports the emulation; otherwise the CSS is asserted by stylesheet inspection and the gap is recorded) token values equal the high-contrast/opaque set; final-state checks of the existing `e2e/reduced-motion.spec.ts` stay green UNMODIFIED.
- [ ] T046 [US3] GREEN: replace the blanket block at `src/styles.scss:232-238` with the substitution rule + `prefers-contrast: more` and `prefers-reduced-transparency: reduce` token overrides (tokens added in a NEW file `src/styles/motion-preferences.scss` imported by one line in `styles.scss`; orchestrator lands the import). `check-platform-tokens` must stay green.
- [ ] T047 [US3] Contrast evidence: axe on the four main pages in default, `prefers-contrast: more`; record in `us3/contrast.json`.
- [ ] T048 [TDD] [SUBAGENT] [US3] RED: `e2e/perf/transcript-after.spec.ts` + anchor tests. **Oracle**: the baseline `T005` JSON; assertions: anchors (`#p-<pid>`, `?t=`), find-in-page-equivalent (`window.find` or text search via Playwright locator count) and follow-mode `scrollIntoView` (`core/follow.ts`) all still land on the right row with the rule applied; the existing `anchor-a11y.spec.ts`, `seek.spec.ts`, `follow-mode.spec.ts`, `transcript-follow.spec.ts` stay green unmodified.
- [ ] T049 [US3] GREEN-or-REVERT: apply `content-visibility:auto; contain-intrinsic-size:auto <measured>px` to transcript rows via a style block hook in `transcript.component.ts` (NOT a template rewrite). Run `u3_cvred`. Compare to the baseline; if INP/scripting/layout is not better OR any anchor/find/follow test fails, REVERT and record the finding in `us3/content-visibility.md` (FR-011). Decision D3 supplies the improvement target.
- [ ] T050 [TDD] [SUBAGENT] [US3] RED: `app-config-view-transitions.spec.ts` + `e2e/comfort-motion.spec.ts` additions. **Oracle**: spec US3 acceptance 4-5: transition runs for top-level route changes; NOT for the transcript-load route nor while an `/api/ask` stream is in flight; skipped under reduced motion; API absent -> identical behaviour (stubbed `document.startViewTransition` undefined).
- [ ] T051 [US3] GREEN: add `withViewTransitions({ onViewTransitionCreated })` to the router providers (one-line hook in `app.config.ts`, orchestrator-landed) with the skip logic in a NEW `core/view-transition-policy.ts`; global keyframes in the motion-preferences stylesheet, <= 200 ms.
- [ ] T052 [US3] Run all RED tests to GREEN; `npm run check-motion-policy`; ng build; design-system and token checks; paste logs.
- [ ] T053 [US3] Paired mutations: (a) restore the nuke rule -> `u3_red` must fail; (b) force a view transition on the transcript route -> `u3_vtred` must fail; (c) `content-visibility` without `contain-intrinsic-size` -> scroll-jump assertion must fail (if the cv change was kept).
- [ ] T054 [US3] [REVIEW] Independent review (Opus xhigh) incl. an adversarial anchor-landing run on 20 random passage ids. `reviews/us3-review.json`.
- [ ] T055 [US3] LIVE-in-scratch verification + `us3/result.json` + manifest (baseline vs after numbers, anchor rows, reduced-motion rows, contrast rows, transition rows, mutation rows).
- [ ] T056 [US3] UI-VISIBLE ACCEPTANCE: operator checklist items 4-5 (OS reduce-motion setting, long transcript scroll and shared `?t=` link); screenshots/short screen recording `us3/screens/`; orchestrator flips `comfort`.


---

## Phase 6: User Story 4 - Media Session (Priority: P2)

- [ ] T057 [TDD] [SUBAGENT] [US4] RED: `core/media-session.spec.ts`. **Oracle**: spec US4 acceptance 1-5 against a stubbed `navigator.mediaSession` (metadata fields `title`, `artist` = course name, `album` = chapter title; action handlers registered: `play`, `pause`, `seekbackward`, `seekforward`, `seekto`; `previoustrack`/`nexttrack` only when chapters exist); API absent -> no throw; cleanup on destroy; text-only chapter -> nothing set.
- [ ] T058 [US4] GREEN: `core/media-session.ts` (service taking the `HTMLVideoElement` and a chapter list) and a one-line hook in `features/chapters/recording-player.component.ts` behind `mediaSession`.
- [ ] T059 [P] [US4] `e2e/media-session.spec.ts`: in chromium, play a short fixture recording and read `navigator.mediaSession.metadata` and invoke the seek handler via `page.evaluate`; asserts `currentTime` moves by the documented step.
- [ ] T060 [US4] [REVIEW] Independent review (Opus xhigh): feature detection, no handler registered that is not honoured, privacy (metadata contains only titles already shown). `reviews/us4-review.json`.
- [ ] T061 [US4] LIVE-in-scratch verification + `us4/result.json` + manifest including the absent-API row and a paired mutation (handler registered without implementation -> test fails).
- [ ] T062 [US4] UI-VISIBLE ACCEPTANCE: operator plays a recording and checks the OS media overlay (checklist item 6); screenshot of the browser's media UI where available; flag flip after sign-off.
- [ ] T063 [US4] Run RED set to GREEN; ng build; checks.


---

## Phase 7: User Story 5 - Durable moment links (Priority: P2)

- [ ] T064 [TDD] [SUBAGENT] [US5] RED: `core/moment-link.spec.ts` + `features/transcript/copy-link.component.spec.ts`. **Oracle**: URL grammar tables from spec 004 `research.md:137` and spec 015 `data-model.md:236` (existing forms must round-trip unchanged) plus 20 fixture passages; combined `?pid=&t=` resolves after pid lookup; unknown pid -> explicit state; clipboard API absent -> readonly field fallback; accessible name and polite confirmation.
- [ ] T065 [P] [TDD] [SUBAGENT] [US5] RED: `e2e/moment-links.spec.ts`: copy link in context A, open in a fresh context B with the same session, land on the passage with the arrival announcement (reuse `anchor-a11y.spec.ts` helpers); withheld pid shows the existing 410 explanation; existing `unresolvable-target.spec.ts` unchanged and green.
- [ ] T066 [US5] GREEN: `core/moment-link.ts` (build/parse), `features/transcript/copy-link.component.ts`; one template tag hook in `transcript.component.ts` (after US3's style hook, orchestrator order) and one in `features/passage/passage.component.ts`; no change to the router config unless the combined form needs a route param (then via the orchestrator).
- [ ] T067 [US5] Record the deferral of the Web Annotation emitter (P5 part 2) with the reason and the revisit condition in `us5/deferred-annotation.md`; no code.
- [ ] T068 [US5] Run RED set to GREEN; ng build; checks.
- [ ] T069 [US5] Paired mutation: copy-link that drops `t` -> round-trip test fails; one that copies a withheld pid -> test fails.
- [ ] T070 [US5] [REVIEW] Independent review (Opus xhigh): no exposure of withheld content through links, grammar compatibility, clipboard permission handling. `reviews/us5-review.json`.
- [ ] T071 [US5] LIVE-in-scratch verification + `us5/result.json` + manifest.
- [ ] T072 [US5] UI-VISIBLE ACCEPTANCE: operator checklist item 5 (copy link, open in a private window); screenshots; flag flip.


---

## Phase 8: User Story 6 - Command palette (Priority: P3)

- [ ] T073 [TDD] [SUBAGENT] [US6] RED: `core/palette-model.spec.ts`, `features/palette/palette.component.spec.ts`. **Oracle**: ARIA Authoring Practices combobox-with-listbox pattern keyboard table (Down/Up/Home/End/Enter/Escape, active-descendant updates, wrap), WCAG 2.1.4 (user can turn the shortcut off), focus return to the invoker, grouped results with text labels, result source = existing search API (stubbed), empty-query state shows commands.
- [ ] T074 [P] [TDD] [SUBAGENT] [US6] RED: `e2e/palette.spec.ts` keyboard-only journey (Ctrl+K and Meta+K), mobile emulation via a visible button, axe, shortcut-disable setting persisted per viewer (try/catch storage), no focus trap after close.
- [ ] T075 [US6] GREEN: `core/palette-model.ts` (filter/rank, deterministic ordering), `core/palette-commands.ts` (static navigation commands from the route list, no hardcoded roster beyond routes), `features/palette/palette.component.ts` (global overlay using native `<dialog>` where available; no new dependency, D6).
- [ ] T076 [US6] Hook: one `<app-palette>` tag and one button in `app.component.ts` behind `palette`; vocabulary strings via `features/palette/palette-vocabulary.ts`.
- [ ] T077 [US6] Run RED set to GREEN; ng build; checks.
- [ ] T078 [US6] Paired mutation: palette that does not restore focus, and one whose shortcut ignores the disable setting -> tests fail.
- [ ] T079 [US6] [REVIEW] Independent review (Opus xhigh): keyboard trap analysis, SC 2.1.4, input handling of IME composition, no content in logs. `reviews/us6-review.json`.
- [ ] T080 [US6] LIVE-in-scratch verification + `us6/result.json` + manifest.
- [ ] T081 [US6] UI-VISIBLE ACCEPTANCE: operator checklist item 7; screenshots; flag flip.
- [ ] T082 [US6] Responsiveness check: palette open-to-first-result time recorded on the real corpus (numbers only, no target).


---

## Phase 9: User Story 7 - Passage peek (Priority: P3)

- [ ] T083 [TDD] [SUBAGENT] [US7] RED: `features/peek/peek.directive.spec.ts`, `peek-popup.component.spec.ts`, `core/peek-model.spec.ts`. **Oracle**: WCAG 1.4.13 clauses (dismissible with Escape without moving focus, hoverable popup, persistent until dismissed/blur), no `title` reliance, plain-text excerpt <= 280 chars, `withheld` state mirrors the 410 branch, touch: tap navigates (no hover popup).
- [ ] T084 [P] [TDD] [SUBAGENT] [US7] RED: `e2e/peek.spec.ts` on a citation chip, a crossref and a search hit; axe; keyboard path.
- [ ] T085 [US7] GREEN: `features/peek/peek.directive.ts` and `peek-popup.component.ts` (CSS anchor positioning with a documented fallback, per `baseline/browser-support.md`), `core/peek-model.ts` (single `GET /api/passages/{pid}` via a new method in `core/answering-api`-style separate service file `core/peek-api.ts`; cache per page).
- [ ] T086 [US7] Hooks: add the directive attribute to `core/cite.component.ts`, `features/transcript/crossrefs.component.ts` and the search-hit template in `inquiry.component.ts` (one attribute each) behind `peek`.
- [ ] T087 [US7] Run RED set to GREEN; ng build; checks.
- [ ] T088 [US7] Paired mutation: popup that closes when the pointer enters it; popup that cannot be dismissed with Escape -> tests fail.
- [ ] T089 [US7] [REVIEW] Independent review (Opus xhigh): leak of withheld text into the popup, request storms (rate/caching), focus management. `reviews/us7-review.json`.
- [ ] T090 [US7] LIVE-in-scratch verification + `us7/result.json` + manifest.
- [ ] T091 [US7] UI-VISIBLE ACCEPTANCE: operator checklist item 8; screenshots; flag flip.


---

## Phase 10: User Story 8 - Rail painted by query relevance (Priority: P3)

- [ ] T092 [TDD] [SUBAGENT] [US8] RED: extend `core/rail.component.spec.ts` + new `core/rail-relevance.spec.ts`. **Oracle**: the existing rail contract (layers, `role=slider`, `aria-valuetext`, sr-only summary, legend; `rail.component.ts:26-50,108,122-129`) plus spec US8 acceptance 1-5: relevance replaces uncertainty; summary/valuetext/legend change in lockstep; clearing restores; empty relevance note; fixture with 7 buckets -> expected opacity classes.
- [ ] T093 [P] [TDD] [SUBAGENT] [US8] RED: `e2e/rail-relevance.spec.ts` with a search on a chapter page, axe, `curriculum-chapter-rails.spec.ts` stays green unmodified.
- [ ] T094 [US8] GREEN: `core/rail-relevance.ts` (group search hits by bucket, normalise 0..1), mode input on `rail.component.ts` through a single input hook behind `railRelevance`; animations limited to opacity.
- [ ] T095 [US8] Run RED set to GREEN; ng build; checks.
- [ ] T096 [US8] Paired mutation: relevance overlay stacking on the uncertainty layer; summary not updated -> tests fail.
- [ ] T097 [US8] [REVIEW] Independent review (Opus xhigh).
- [ ] T098 [US8] LIVE-in-scratch verification + `us8/result.json` + manifest.
- [ ] T099 [US8] UI-VISIBLE ACCEPTANCE: operator checklist item 9; screenshots; flag flip.


---

## Phase 11: Polish and cross-cutting

- [ ] T100 [P] [POLISH] User manual sections in `workshop/docs/manual.md` for each shipped story; FAQ entries in `workshop/docs/faq.md` (why do I see stages, what does the unverified draft label mean, why is confidence asked, how do I turn off the shortcut, why does my OS setting change the page); coverage map `workshop/docs/coverage/025-docs-coverage.md` with no orphan capability (§11.4.257).
- [ ] T101 [P] [POLISH] Task guides `workshop/docs/guides/{ask-stages,practice-confidence,moment-links,palette,peek}-guide.md`, linked from `workshop/docs/README.md`.
- [ ] T102 [P] [POLISH] Diagram 1 of 4 - ARCHITECTURE (Mermaid, in the ask-stages guide): browser components (`AskStreamService`, reducer, stage component) vs server (`answer.Handler`, `Job`, `Pipeline`).
- [ ] T103 [P] [POLISH] Diagram 2 of 4 - DATA FLOW: question -> SSE frames -> parser -> reducer -> DOM; fallback `wait=1` path.
- [ ] T104 [P] [POLISH] Diagram 3 of 4 - STATE MACHINE: `connecting -> streaming -> done | dropped -> (reconnect) -> streaming | failed`.
- [ ] T105 [P] [POLISH] Diagram 4 of 4 - SEQUENCE: user, component, service, server incl. the drop/reconnect branch and the opt-in draft.
- [ ] T106 [POLISH] Exports (§11.4.65): `bash scripts/build-exports.sh`; Mermaid rendered, no raw source leakage.
- [ ] T107 [POLISH] [REVIEW] Independent export validation by a separate agent (§11.4.168): content, text and full visual layers incl. OCR on rendered pages; verdict `reviews/exports-review.json`.
- [ ] T108 [POLISH] Claim-vs-reality ledger rows (§11.4.266): "stages shown are exactly the server's", "reduced-motion keeps a fade", "copy-link round-trips", "palette is keyboard-complete" - each with a passing challenge from the stories above.
- [ ] T109 [POLISH] Full-suite retest on a clean baseline (§11.4.40): `npm run test:unit`, `npx ng build`, Playwright desktop + mobile, `npm run check-motion-policy`, vocabulary and design gates; paste counts. Once, after all desired stories.
- [ ] T110 [POLISH] [REVIEW] Whole-feature independent review (Opus xhigh, §11.4.194) incl. a bluff audit of every PASS in `evidence/025-ux-research-wave/`.
- [ ] T111 [POLISH] Discovery-pressure (§11.4.238): a non-author agent explores every shipped story with adversarial input (huge questions, rapid resubmits, RTL text, 200% zoom, forced colors); escapes are recorded with a root-cause + missing-check audit.
- [ ] T112 [POLISH] Zero-gaps sweep (§11.4.261): every TODO/stub/"for now" introduced is CLOSED with evidence or TRACKED with an item id; the deferred items table (spec) is mirrored into a tracked list with revisit conditions.
- [ ] T113 [POLISH] Re-check spec 026 existence/decision about MMR; update `baseline/mmr-status.md`; no code either way unless 026 says so.
- [ ] T114 [POLISH] Operator decisions D1-D7 recorded in `specs/025-ux-research-wave/decisions.md` when answered; flags and docs reflect them; nothing closed on an assumed answer.
- [ ] T115 [POLISH] Trackers: `progress.yml` (orchestrator-owned), `CONTINUATION.md` (§12.10), gitlink bump + `helix-deps.yaml` ref in ONE change (cascade C9).
- [ ] T116 [POLISH] Version bump after QA deploy (§11.4.235(B)); tag only after the full-suite retest with the project prefix (§11.4.151).
- [ ] T117 [POLISH] Final live verification bundle `workshop/evidence/025-ux-research-wave/live/result.json` + `manifest.sha256` indexing us1..us8 results, build id, image digest (§11.4.264), operator sign-offs.

---

## Dependencies & Execution Order

- Setup -> Foundational -> US1 (first, alone as the MVP) -> then US2 || US3 || US4 || US5 (disjoint files; US3 before US5 on `transcript.component.ts`) -> then US6, US7, US8.
- US1 is verified on scratch servers with answering ON; it is operator-visible on the live stack only after spec 024 enables answering.
- US2 persistence waits for spec 013; US5's annotation emitter, P8, P10, P14, P15, P16 and offline are deferred/rejected (spec table).
- Polish after the desired stories; the full-suite retest once.

### Parallel opportunities

T-setup tasks marked [P]; all RED test-authoring tasks inside a story; US2/US3/US4 streams in parallel after US1; documentation tasks.

### Subagent dispatch notes

Test authors and implementers are different agents; reviewers use Opus at xhigh effort. The perf baseline and any multi-minute Playwright runs are long-ops: register, detach, heartbeat (§11.4.232) and check thread headroom (`ulimit -u`, live thread count) before fan-out (§12.12).

## Implementation Strategy

MVP = Setup + Foundational + US1. Then the cheap P2 stories in any order (each is independently shippable and latent behind its flag). The P3 stories only after the P2 set is accepted. If a measured story regresses (for example `content-visibility`), it is reverted with the finding recorded; the rest are unaffected.
