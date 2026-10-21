# Feature Specification: UX Research Wave (staged streaming answers first, then the cheap wins)

**Feature Branch**: `025-ux-research-wave`

**Created**: 2026-10-20

**Status**: Draft

**Input**: Operator brief (2026-10-20): "the ~20 UX-research proposals in
`workshop/docs/research/ux-research-2026-09-01.md` that no spec covers; prioritise by cost/benefit,
FIRST the cheap one: streaming answer stages in the frontend (backend already streams,
`pkg/answer/http.go:361-470`, frontend uses `wait=1`). Group into user stories with independent
tests, mark which are in scope now vs deferred with reasons, and keep MMR out per the 017 decision
(library MMR banned) unless the spec reconciliation (spec 026) says otherwise."

**Builds on**: `specs/001-workshop-curriculum-platform` (answering pipeline, accessibility FRs
FR-041/FR-042/FR-044b), `specs/008-*` (follow mode, deep-link arrival), `specs/017-exhaustive-rag-expansion`
(MMR decision, `research.md` §0), `specs/024-answering-enablement-and-provider-ui` (answering ON/OFF -
the staged answer is only observable on a deployment where answering is ON, see Dependencies).

**Content boundary**: the UX research document lives in the private `workshop/` submodule. This public
spec paraphrases proposals by id (P1..P16 in the document, U1..U39 in the gap analysis) and cites
platform files; it quotes no private chapter or transcript content.

## Proposal disposition (the whole research round, one table; evidence is repeated per story below)

Document ids: P1..P16 (ranked proposals, `ux-research-2026-09-01.md` §2), §3 rejected list, §4/§5
implications. Cost labels are the document's own (XS < S < M < L); "in scope" = has a story below.

| Id | Proposal | Doc cost | Platform state today (file:line) | Disposition | Reason |
|---|---|---|---|---|---|
| P1 | Staged honest streaming answer | XS-S | backend SSE ready `pkg/answer/http.go:361-470`; frontend sync `core/api.ts:561` (`wait=1`), elapsed counter `inquiry.component.ts:336,996,1210-1217` | **IN: US1 (P1)** | worst measured surface (11.7-58.3 s wait in the doc), backend already done, fixes a defect of the largest size, zero latency change |
| P2 | Self-explanation + confidence before reveal | XS | absent; explanation shown after pick `features/practice/practice.component.ts:351` | **IN: US2 (P2)**, UI + local state; server persistence deferred to the spec 013 contract | best learning evidence per line (doc: g = 0.55), retrofit cost rises as the quiz UI hardens; persistence belongs to the attempt record that 013 owns (0/52 done) |
| P3 | MMR-diversify crossrefs | XS | deliberately not done: 017 `research.md` §0 bans library MMR (non-deterministic, score-corrupting); `pkg/crossref` declines it; diversity bounded structurally (`MaxPerPassage`) | **OUT (kept out)** | per the operator brief and 017; revisit only if spec 026 says so (own-implementation MMR over stored embeddings is not covered by the 017 defect but has no spec) |
| P4 | `content-visibility:auto` on transcript rows | XS | absent (no hits in `src/app`); `features/transcript/transcript.component.ts` is 1,204 lines | **IN: US3 (P2)** | cheap; must be measured before/after, may regress anchors/find-in-page (see risks) |
| P5 | Durable deep link `?pid=&t=`, copy-link, Web Annotation | S | `?t=` and `#p-<pid>` implemented (`transcript.component.ts:106`, `anchor-a11y.spec.ts`), `/passage/:pid` route exists; no copy-link control (only code-block copy `core/code-block.component.ts:51`) | **IN (partial): US5 (P2)** copy-link + combined resolver + vanished-pid state; Web Annotation emitter **deferred** | no consumer of the annotation JSON exists; links are used today |
| P6 | Accessible passage peek (hover/focus) | S-M | absent | **IN: US7 (P3)** | useful, but SC 1.4.13 correctness cost; after P1/P2 land |
| P7 | Command palette (Ctrl/Cmd+K) | M | absent | **IN: US6 (P3)** | highest reach after the two P1/P2 items; M cost, keyboard-conflict risk (SC 2.1.4) |
| P8 | Storyboard thumbnails on the rail | S | absent; needs an ffmpeg tile-sprite + WebVTT asset pipeline per recording | **DEFERRED** | needs a new asset-generation pipeline and storage for private recordings; benefit small relative to cost; revisit after the media pipeline (spec 012/019 area) is settled |
| P9 | Paint the rail with query relevance | S-M | rail has uncertainty/gap/citation layers + sr-only summary `core/rail.component.ts:26-50,108,122-129` (559 lines) | **IN: US8 (P3)** | builds on an existing, tested component; needs the search state plumbed to the rail |
| P10 | FSRS stock parameters for quiz scheduling | M | absent; spec 013 chose Elo-style ability scoring (FR-004/005) and spec 004 declined spaced repetition (`plan.md:192`) | **DEFERRED** | contradicts the in-flight scoring model; needs the 013 attempt log; decision belongs to 013 owner |
| P11 | Media Session API | XS | absent; native `<video>` in `features/chapters/recording-player.component.ts:51` | **IN: US4 (P2)** | tiny, feature-detected, no a11y regression |
| P12 | Motion policy: substitute not delete; prefers-contrast / reduced-transparency | XS | blanket `.01ms` rule at `src/styles.scss:232-238` (final state preserved, no opacity-fade substitution); other queries absent; spec 014 FR-013 covers gamification motion only | **IN: US3 (P2)** | cheap, global, testable |
| P13 | `withViewTransitions()` on the router | XS-S | absent (`app.config.ts:12` uses `withInMemoryScrolling` only) | **IN: US3 (P2)**, scoped & bounded | must exclude transcript load and `/api/ask`; skipped under reduced motion |
| P14 | Auditable export: xAPI / cmi5 / CSV | M-L | `/api/progress` exists; no xAPI; area export (FR-045) is documents only | **DEFERRED** | no consumer (no LRS in this deployment); controlled vocabulary must come first (doc itself says so); revisit when a Jordan-client or LMS consumer exists |
| P15 | Ship corpus + embeddings to the client | M | absent; `/api/index/status` gives generation/hash | **REJECTED for now** | the corpus is private and passages can be withheld/suppressed server-side (`/passage/:pid` 410 branch `passage.component.ts:177,258`); a client copy bypasses that control. Needs a redaction-safe design first |
| P16 | Auto-chaptering from transcript | M | absent | **DEFERRED** | needs generative titling (spec 011 providers + spec 024 gate) and a merge-not-overwrite policy for hand edits |
| §3.13 / U27 | Offline subset (transcript + passages + quizzes) | - | no service worker | **DEFERRED** | puts private content on the device cache: a privacy decision for the operator |
| Tooling S4, S16, S17, S19, S20, S23 | operator tooling items from the skills-and-plugins research | - | n/a | **OUT** | not UX; belong to a tooling spec *(Reconciled by 027 on 2026-10-21: that spec is `specs/027-research-gap-closure`, tooling decisions in its `contracts/tooling-decisions.md`)*; details not read for this spec (UNCONFIRMED) |
| §3 rejects (skeleton screens, per-word underline, force graph, streaks, LLM auto-grade, DKT, speculation rules, parallax, local-first sync, stacked columns, generated overviews) | - | - | compliant today (gap analysis U17-U26, U28-U29) | **NO WORK** | kept as constraints on this spec (see FR-018) |
| §4/§5 verification items U32 (transcript pane keyboard scroll), U35 (target size 2.5.8), U36 (INP baseline) | - | UNCONFIRMED today | **IN: Foundational baseline tasks** | needed as before/after evidence for US3 and as tracked findings |

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A learner watches the answer being built, honestly (Priority: P1)

A learner asks a question on `/ask`. Instead of a spinner and a count-up timer for 12-60 seconds,
they see the real pipeline stages as the server reports them (queued, retrieving, generating,
verifying), with the elapsed time at which each stage began, a polite screen-reader announcement per
stage change, and then the final three-state outcome (answered with verified citations, declined with
its reason, or unavailable). Stages remain visible (collapsed) after the answer. No stage is ever
shown that the server did not report.

**Why this priority**: the research names it the worst-measured surface (answers take 11.7-58.3 s with
no feedback) and the cheapest item with direct evidence; the backend work is already done
(`pkg/answer/http.go:361-470` streams `phase`, `progress`, `result`, and optionally `token` events).

**Independent Test**: against a scratch server with the `extractive` or `ollama` provider
(answering ON), submit a question; the DOM stage list receives exactly the phase events the server
sent, in order, each with the server's `elapsed_s`; a recorded-stream fake with a deliberately
injected phantom stage is NOT displayed. Against the live stack as deployed (answering OFF) the page
shows the existing honest unavailable state (no stream exists).

**Acceptance Scenarios**:

1. **Given** answering is ON, **When** the learner submits a question, **Then** a stage list appears
   within one animation frame of the first received event and shows each reported phase with its
   server-reported elapsed time.
2. **Given** the stream delivers `phase: retrieving` then `generating` then `verifying` then
   `result`, **When** the result arrives, **Then** the stages collapse into a summary line
   ("retrieving 0.4 s, generating 28 s, verifying 3 s" using the real values) that can be expanded
   again, and the outcome renders exactly as today's `wait=1` path would.
3. **Given** the outcome is `declined`, **When** it arrives on the stream, **Then** it renders the
   explicit decline with its reason and retrieval numbers, not an empty answer and not an error.
4. **Given** a `withheld` event (the suppression filter could not check an event), **When** it is
   received, **Then** the UI shows the withheld state and discards any draft text, never rendering
   the unchecked payload.
5. **Given** the connection drops before `result`, **When** the reader ends, **Then** the UI
   reconnects once via the job id (`/api/ask/{job_id}/stream` replays buffered events, per
   `pkg/answer/http.go:360-368,505-510`) or shows an explicit "connection lost, answer may still
   complete; retry" state - never a perpetual spinner and never a fabricated completion.
6. **Given** a screen-reader user, **When** stages change, **Then** exactly one polite live region
   announces the new stage (not assertive, not per token), and the answer body is not a live region.
7. **Given** `prefers-reduced-motion: reduce`, **When** stages change, **Then** no movement is used
   (opacity-only or none), and the information is unchanged.
8. **Given** the optional draft preview is enabled by the user (default OFF, decision D1), **When**
   raw text deltas arrive (`tokens=1`), **Then** they are shown under a permanent "unverified draft"
   label and are replaced or removed when the verified `result` arrives (including removal with an
   explicit message when the answer is refused).

---

### User Story 2 - Learners commit to an answer and a confidence before the explanation (Priority: P2)

On a practice question, before the correct answer and explanation are shown, the learner is asked
for a one-line self-explanation (optional to submit, but prompted) and a confidence rating
(three-step scale). After reveal, a high-confidence-wrong answer is called out as a distinct,
neutrally worded outcome; a correct low-confidence answer is also distinguished.

**Why this priority**: best learning evidence per line of code in the research round, and the cost
rises once the quiz UI is frozen. It is P2 because the server-side persistence of the two new fields
belongs to the attempt record spec 013 owns (0 of 52 tasks done).

**Independent Test**: component test on `features/practice/` with a fixture question: reveal is not
reachable before a confidence is chosen (skipping the text is allowed, skipping confidence is not -
decision D2); after reveal the confidence/result pairing text matches the oracle table.

**Acceptance Scenarios**:

1. **Given** a question is shown, **When** the learner selects an option, **Then** the explanation
   and correct-answer marking are NOT shown until a confidence rating is chosen.
2. **Given** a wrong answer chosen with high confidence, **When** the reveal happens, **Then** the
   outcome uses neutral wording (no danger colour tokens, no shaming copy), is announced politely,
   and is recorded locally as `high_confidence_wrong`.
3. **Given** the learner leaves the self-explanation empty, **When** they continue, **Then** reveal
   proceeds (the field is encouraged, not forced) and `self_explanation` is recorded as empty.
4. **Given** a new client-side `core/confidence-store.ts` (same in-memory-service pattern as
   `core/practice-store.ts`, which today stores only deck position), **When** the learner leaves and
   returns to the deck within the session, **Then** already-committed confidences are retained and
   the reveal state is not lost.
5. **Given** spec 013's attempt record is not yet built, **When** the feature runs, **Then** the two
   fields are kept client-side only and the UI states nothing about server tracking.

---

### User Story 3 - Reading and motion feel right, measurably (Priority: P2)

Long transcripts render and scroll smoothly; the platform's motion is governed by one written policy
under which reduced-motion users get a substitution (a short opacity change instead of nothing, no
transform/slide) and users who ask for higher contrast or reduced transparency get that honoured;
route changes use a short view transition that is skipped when reduced motion is requested and is
never applied to the transcript load or to the answer wait.

**Why this priority**: three XS-S items whose evidence is mostly standards-based; together they raise
perceived quality cheaply. Each must be measured, not assumed.

**Independent Test**: Playwright performance trace on a long transcript before/after
`content-visibility`; media-query emulation tests for reduced-motion, contrast and transparency; a
route-change test asserting the view-transition API is invoked only on the allowed routes.

**Acceptance Scenarios**:

1. **Given** a transcript with at least 1,000 passage rows, **When** it loads and the user scrolls,
   **Then** the measured layout/scripting time and INP are not worse than the recorded baseline and
   improve by at least the target recorded after the baseline (decision D3), and deep links to a
   passage anchor (`#p-<pid>`, `?t=`) still land on the correct row.
2. **Given** `prefers-reduced-motion: reduce`, **When** any component that animates runs, **Then**
   transform/slide movement is removed and a short opacity transition remains (a substitution, not a
   deletion); final states are unchanged (the existing e2e proof `reduced-motion.spec.ts` stays green).
3. **Given** `prefers-contrast: more` or `prefers-reduced-transparency: reduce`, **When** the page
   renders, **Then** tokens switch to the high-contrast/opaque set and axe contrast checks pass on
   the four main pages.
4. **Given** view transitions are supported and reduced motion is not requested, **When** the user
   navigates between top-level routes, **Then** a transition of at most 200 ms runs; **When** the
   target is a transcript load or `/ask` in flight, **Then** none runs.
5. **Given** a browser without the View Transitions API, **When** navigating, **Then** behaviour is
   identical to today (feature detection, no error).

---

### User Story 4 - The operating system shows chapters and responds to media keys (Priority: P2)

While a recording plays, the lock-screen/media-control UI shows the recording title and current
chapter, and the previous/next/seek media keys work.

**Independent Test**: unit test with a stubbed `navigator.mediaSession` asserting metadata and handler
registration, plus the no-op path when the API is absent.

**Acceptance Scenarios**: (1) metadata set on play with title and current chapter name; (2) seek
handlers move `currentTime` by the documented step; (3) previous/next track handlers jump to chapter
boundaries when chapters exist, otherwise are not registered; (4) API absent: nothing thrown, no
console error; (5) metadata cleared on leaving the page.

---

### User Story 5 - A moment in a recording can be shared as a durable link (Priority: P2)

A learner on a transcript or passage page can copy a link that opens the same moment later. The link
carries the stable passage id and a time offset; if the passage no longer resolves (withheld or
removed), the arrival page says so explicitly instead of landing at the top.

**Independent Test**: e2e: copy-link produces a URL; opening it in a fresh context lands on the
passage with the arrival announcement; a URL with an unknown pid shows the explicit vanished-pid
state (existing `unresolvable-target.spec.ts` pattern).

**Acceptance Scenarios**: (1) a "Copy link" control with an accessible name and a polite "link
copied" confirmation exists for a passage and for the current playback moment; (2) the produced URL
round-trips through the router and resolves to the same passage and time; (3) existing `?t=` and
`#p-<pid>` links keep working unchanged; (4) a withheld pid yields the existing 410-style explanation,
not a redirect; (5) clipboard API unavailable: the URL is shown selected in a field instead.

---

### User Story 6 - A command palette gets keyboard users anywhere (Priority: P3)

Pressing Ctrl/Cmd+K opens an accessible palette (ARIA combobox/listbox with active-descendant) that
searches chapters, areas, passages and navigation commands, and navigates on Enter.

**Independent Test**: keyboard-only Playwright journey (open, type, arrow, enter, escape) with axe,
asserting the SC 2.1.4 escape (the shortcut can be turned off in the UI), focus return to the
invoker, and no focus trap after close.

**Acceptance Scenarios**: (1) opens on Ctrl/Cmd+K, closes on Escape with focus restored; (2) results
group by type with text labels; (3) the active result scrolls into view; (4) results come from the
existing search API (no new corpus endpoint); (5) when the user disables shortcuts in settings, the
shortcut does nothing but a visible button still opens the palette.

---

### User Story 7 - Quick look at a passage without leaving the page (Priority: P3)

Hovering or focusing a citation chip, cross-reference or search hit shows a small preview of the
passage text and source, dismissible with Escape, hoverable, and persistent until dismissed (WCAG
1.4.13), never relying on `title`.

**Independent Test**: component + Playwright tests for dismiss (Escape), hover-over-the-popup keeps it
open, focus-in opens it, touch long-press alternative or tap-through to `/passage/:pid`.

**Acceptance Scenarios**: (1) keyboard focus opens and Escape closes without moving focus;
(2) pointer can move onto the popup without it closing; (3) text comes from the already-loaded hit or a
single `GET /api/passages/{pid}` and a withheld passage shows the withheld state; (4) content is plain
text; (5) no popup on touch hover emulation, tap navigates.

---

### User Story 8 - The rail shows where the query is answered (Priority: P3)

While a search query is active, the timeline rail paints per-bucket relevance for that query in place
of the uncertainty layer, with the screen-reader summary and legend updated in lockstep, and restores
the original layer when the query clears.

**Independent Test**: `core/rail.component.spec.ts` extension with a fixture of per-bucket relevance;
sr-only summary text and legend change together; axe passes; clearing the query restores the layers.

**Acceptance Scenarios**: (1) relevance layer replaces (not stacks on) the uncertainty layer while
active; (2) `aria-valuetext`/summary mention the query-relevance mode; (3) legend toggles; (4) no new
animation of non-compositor properties; (5) empty relevance (no hits in this recording) shows an
explicit "no matches in this recording" note rather than a blank rail.

---

### Edge Cases

- Stream `result` arrives with `verified:true`, but earlier `token` deltas were shown: the final text
  replaces the draft atomically; if the final answer is declined, the draft is removed (US1 #8).
- Proxy buffering delays events: heartbeat `progress` frames every 10 s (`http.go` ticker) keep the
  stage panel's "still working" line current; the UI does not claim a stage that has not been reported.
- Bearer-token auth: the browser `EventSource` cannot set an `Authorization` header, so the stream
  reader MUST be a `fetch` + `ReadableStream` reader that passes the token through the same interceptor
  logic as `HttpClient` (research R2).
- A 401 mid-stream follows the global session-expiry path (`core/auth-interceptor.ts`).
- Two questions in quick succession: the first stream is aborted (`AbortController`), only the latest
  renders.
- `content-visibility:auto` + find-in-page / anchor scroll: anchors must still resolve (US3 #1 test).
- Command palette shortcut collides with browser/extension shortcuts: user-disable control (US6 #5).
- View transitions with the Angular router `withViewTransitions` and `prefers-reduced-motion`: callback
  `skipTransition` (US3 #4).
- Media Session metadata for a text-only chapter (no recording): not set.
- Copy-link on a suppressed/withheld passage: the control is absent or says why; never copies a link
  that would expose content.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The answer UI MUST consume the server stream (`GET /api/ask?stream=1` or POST then
  `GET /api/ask/{job_id}/stream`) with a `fetch`-based reader that attaches the bearer token, parses
  SSE frames (`event:` + single-line `data:`), and handles event kinds `phase`, `progress`, `token`,
  `result` and `withheld`.
- **FR-002**: Every displayed stage MUST correspond to a received event; stage names come from the
  closed `Phase` set (`queued`, `retrieving`, `generating`, `verifying`, `done`,
  `pkg/answer/outcome.go:101-105`); elapsed times are the server's `elapsed_s`, not client guesses.
  No percentage bar is shown (the backend cannot compute one honestly; research doc P1 risk 2).
- **FR-003**: The stage list MUST be exposed through exactly one `aria-live="polite"` region updating
  on stage transitions only; the answer body MUST NOT be a live region; assertive live regions are
  forbidden.
- **FR-004**: The terminal `result` MUST render through the existing outcome renderer so declines,
  unavailables and citations behave exactly as the synchronous path does; the synchronous path
  (`wait=1`) MUST remain as the fallback when streaming fails to start.
- **FR-005**: Raw text deltas MUST NOT be requested unless the user opts in to the draft preview
  (decision D1); when shown they carry a permanent "unverified draft" label and are never presented
  as final (`pkg/answer/http.go:370-383`).
- **FR-006**: A dropped stream MUST trigger at most one reconnect to the job's stream; after that an
  explicit retry state is shown. No infinite spinner.
- **FR-007**: The practice flow MUST require a confidence choice before reveal and MUST allow an empty
  self-explanation; wording for high-confidence-wrong outcomes MUST be neutral (spec 014 FR-003/005/016
  vocabulary, no danger tokens).
- **FR-008**: Self-explanation text and confidence MUST stay client-side until spec 013's attempt
  record accepts them; this feature defines the field names (`self_explanation`, `confidence` with
  values `low|medium|high`) in `contracts/practice-confidence-fields.md` so 013 can adopt them.
- **FR-009**: A written motion policy (`workshop/docs/design-system/motion-policy.md`) MUST define the
  duration band (150-200 ms, at most 500 ms for data-dense views), the reduced-motion substitution
  rule, and the ban on animating non-compositor properties; a gate MUST fail on a transition/animation
  using `top/left/width/height/box-shadow` in `src/` styles and on wildcard `will-change`.
- **FR-010**: The blanket reduced-motion rule (`src/styles.scss:232-238`) MUST be replaced by a
  substitution rule (opacity-only short fade preserved, transform/scroll-behaviour removed) without
  changing final visual states; plus `prefers-contrast: more` and `prefers-reduced-transparency: reduce`
  token overrides; `backdrop-filter` MUST NOT be animated.
- **FR-011**: `content-visibility:auto` with `contain-intrinsic-size` MAY be applied to transcript rows
  only if the baseline-versus-after measurement shows no regression and anchors/find-in-page still
  work; otherwise the change is reverted and the finding recorded.
- **FR-012**: View transitions MUST be enabled through the router feature, skipped under reduced
  motion, excluded for the transcript-load route and any route with an in-flight `/api/ask`, and
  feature-detected.
- **FR-013**: Media Session MUST be feature-detected, MUST set metadata only for a recording with a
  title, and MUST register only handlers it can honour.
- **FR-014**: Copy-link MUST produce a URL that round-trips; existing `?t=` and `#p-<pid>` grammars
  (spec 004 `research.md:137`, spec 015 `data-model.md:236`) stay valid; a combined `?pid=&t=` form is
  added only if the router test proves it does not change the existing forms; vanished pids show an
  explicit state.
- **FR-015**: The palette MUST be an ARIA combobox pattern with active-descendant, documented keyboard
  contract, escape from the shortcut (SC 2.1.4), focus return, and results only from existing search
  endpoints.
- **FR-016**: Previews MUST satisfy WCAG 1.4.13 (dismissible, hoverable, persistent), MUST NOT rely on
  `title`, and MUST show the withheld state for suppressed passages.
- **FR-017**: Rail relevance MUST replace, not overlay, the uncertainty layer while active and MUST
  update `aria-valuetext`, the sr-only summary and the legend together.
- **FR-018**: The rejected patterns in the research (§3) MUST NOT be introduced: no skeleton screens
  for the answer wait, no per-word ASR underlining, no force-directed global graph, no streaks/hearts,
  no LLM auto-grading, no parallax, no generated audio/video overviews.
- **FR-019**: Every new component is standalone/OnPush, in a NEW file, keyboard-operable, WCAG 2.1 AA
  (the platform's level), 390 px responsive, text-plus-icon (not colour alone). New UI strings go in
  `features/<x>/<x>-vocabulary.ts` and are merged into `core/vocabulary.ts` by the orchestrator.
- **FR-020**: Unfinished surfaces MUST be latent: each story's UI is behind a runtime flag
  (`core/ux-flags.ts`) default OFF until its live acceptance passes (§11.4.230(D.2)); US1 is the first
  flag turned ON.
- **FR-021**: Documentation: user manual sections, task guides and FAQ for each shipped story, plus the
  four diagram classes at point of use, exported and independently validated (§11.4.257/258/65/168).

### Key Entities

`AskStreamEvent` (kind, phase, elapsed_s, tokens, note, delta?, verified, outcome?), `StageRecord`
(phase, started_at_s, ended_at_s?), `ConfidenceRecord` (question id, choice, self-explanation,
committed_at), `MomentLink` (pid, t seconds), `PaletteItem` (kind, label, target), `PeekModel`
(pid, text excerpt, source, withheld?), `RailRelevance` (bucket -> score). See `data-model.md`.

## Success Criteria *(mandatory)*

- **SC-001**: Stage honesty: over a recorded-stream corpus of at least 12 streams (incl. decline,
  unavailable, withheld, dropped, heartbeat-only, token-opt-in) 100% of displayed stages equal the
  set of received phase events in order; a mutation that injects a phantom stage is caught (paired
  mutation).
- **SC-002**: Time to first visible stage after submit is at most one render frame after the first
  event is parsed (unit-measured with a fake clock), and the first server event arrives before any
  model token (live measurement on a scratch server, recorded; no numeric target for server latency).
- **SC-003**: axe-core reports zero serious/critical violations on `/ask` (idle, streaming, answered,
  declined), `/practice/:slug` (pre-reveal, post-reveal), and each new component's states.
- **SC-004**: With `prefers-reduced-motion: reduce`, an automated check finds no transform/slide
  animation in the app's computed styles for the touched components and at least the substituted
  opacity transition; `reduced-motion.spec.ts` stays green.
- **SC-005**: Transcript baseline (>= 1,000 rows): INP and scripting/layout time recorded before and
  after US3; "after" is not worse; the improvement target is set in decision D3 after the baseline.
- **SC-006**: Copy-link round-trips for 100% of 20 fixture passages; existing deep-link specs
  (`anchor-a11y.spec.ts`, `unresolvable-target.spec.ts`, `seek.spec.ts`) stay green unmodified.
- **SC-007**: Palette: keyboard-only journey passes in Chromium desktop and mobile emulation; shortcut
  disable works; focus returns.
- **SC-008**: No new third-party runtime dependency is added to `package.json` (Angular CDK is not a
  dependency today; palette/peek are built without it unless decision D6 approves it).
- **SC-009**: Each shipped story has manual + guide + FAQ coverage and the four diagram classes; the
  exported documents pass the independent validator.
- **SC-010**: Operator-visible acceptance: for each shipped story the operator can perform the listed
  UI check in `quickstart.md` and sign off; US1's check requires an answering-enabled deployment.

## Assumptions

- Server stream behaviour is as documented in `pkg/answer/http.go` today; richer stage detail
  ("N candidate passages scored", per-claim citation attach) from the research document is NOT in the
  backend events (phases + note only); adding backend event fields is out of scope here (FR-002).
- Angular 19.2 standalone app, no `@angular/cdk` (research doc and `package.json`); browser support
  facts in the research document are dated and re-checked in the baseline task before use.
- The platform's accessibility level remains WCAG 2.1 AA with 2.2 additions tracked as findings
  (U35), not required.
- Spec 026 (reconciliation) is not yet written; the MMR item stays OUT until it says otherwise.

## Dependencies

- **US1 needs answering ON to be observable end to end** (spec 024). Tests and scratch verification use
  an answering-enabled scratch server (extractive provider: fast phases; ollama: realistic phases). On
  the live stack with answering OFF, US1's visible change is limited to the honest off state; the
  operator therefore sees the staged answer only after spec 024 clears a configuration (this is stated
  in `quickstart.md`).
- US2 persistence: spec 013 (`FR-001/002/016` attempt record) - fields defined here; adoption there.
- Shared files: `features/inquiry/inquiry.component.ts` (1,826 lines) and
  `features/transcript/transcript.component.ts` (1,204 lines) are hot spots; this spec adds ONLY
  single-tag hooks to them and owns the order described in `plan.md`.

## Open operator decisions (carried to the final report)

- **D1** Draft token preview: offer an opt-in "show draft while verifying" (default OFF, spec default)
  vs never show unverified text.
- **D2** Is confidence mandatory before reveal (spec default) or optional?
- **D3** Performance targets for US3 after the baseline (percentage improvement vs non-regression only).
- **D4** MMR: stays OUT (spec default) pending spec 026.
- **D5** Offline subset (U27) and client-side corpus (P15): confirm DEFER/REJECT on privacy grounds.
- **D6** Allow `@angular/cdk` for palette/peek focus management (spec default: no new dependency).
- **D7** Should the self-explanation prompt be shown for every question kind or only MCQ/short?
