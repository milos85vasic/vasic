# Feature Specification: Gamification Feedback on the OpenDesign System

**Feature Branch**: N/A — written directly into the reserved `specs/014-gamification-design-system/` directory per an explicit operator simplification decision; no feature branch was created for this spec.

**Created**: 2026-09-30

**Status**: Draft

**Input**: User description: "Formalize the completed research brief `workshop/docs/research/education-platform/gamification-and-design-system.md` (and its working prototype, `poc/achievement-toast.component.ts`) into a real SpecKit feature specification: badges, toasts, and popups tied to the (separately-specced) adaptive scoring system's progress/downgrade events, built on this project's real OpenDesign design system (`design-system/`, not the `design-toolkit` submodule). Phase 1 = toast + badge production components descended from the real prototype; Phase 2 = modal/dialog level-up/path-adjusted moments; Phase 3 = motion polish plus an independent QA gate against design-toolkit's own test-bank. Downgrades must read as supportive, never punitive — enforced as a real, testable constraint, not just prose — and accessibility (screen-reader-equivalent information) must be a first-class, testable requirement."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A learner sees a toast and earns a badge for real-time scoring events (Priority: P1)

A learner is working through the curriculum. The adaptive scoring system (a separate, already-researched capability — see Assumptions) emits an event when the learner's ability level changes: a level-up, a chapter-completion milestone, or a downgrade where the system recalibrates the learner's next item to an easier difficulty after a run of wrong answers. Today, none of these events produce any visible feedback anywhere in the app — no toast, no badge, no notification component of any kind exists in the codebase. The learner wants confirmation that progress is being tracked and, for a downgrade specifically, wants that recalibration to read as help rather than as a penalty.

**Why this priority**: This is the literal, explicit request and the only phase with a real, evidence-backed starting point already sitting in the repository: a compiling Angular prototype (`achievement-toast.component.ts`) that composes this app's real, already-vendored `.lk-toast` classes, plus a real, already-vendored-but-unused `.lk-badge` class family. It is independently valuable — a learner gets visible feedback for their progress — with zero dependency on Phase 2 or Phase 3, and it is the MVP.

**Independent Test**: Trigger each of the three event kinds (level-up, chapter-complete, adjusted/downgrade) against a running instance of the app with the feature installed. Confirm: a toast renders for each, composed from `.lk-toast`/`.lk-toast-region` (not a forked/duplicated CSS class family); the downgrade toast carries no `--od-danger`/`--od-warning` styling; a persistent achievement badge appears on the relevant surface (e.g. a chapter card) for a milestone event and survives a page reload; and a screen reader announces text equivalent to what a sighted user sees for every event kind.

**Acceptance Scenarios**:

1. **Given** the adaptive scoring system emits a `level-up` or `chapter-complete` event for the current learner, **When** the event reaches the toast queue, **Then** a toast renders using the `.lk-toast`/`.lk-toast--success` classes already vendored in this app, with an accessible live-region announcement carrying the same information a sighted user gets from the toast's glyph, headline and color.
2. **Given** the adaptive scoring system emits an `adjusted` (downgrade) event, **When** the event reaches the toast queue, **Then** a toast renders with no `--od-danger` or `--od-warning` token and no `.lk-toast--danger`/`.lk-toast--warning` (or equivalent semantic-negative) modifier class applied anywhere in its render output, and its copy leads with the benefit to the learner rather than naming the change as a loss.
3. **Given** a toast is currently visible and the learner hovers it with a pointer or moves keyboard focus into it, **When** the auto-dismiss timer would otherwise have expired, **Then** the toast remains visible until the pointer leaves and focus moves away, after which the timer resumes.
4. **Given** a learner completes a milestone (e.g. a chapter, or reaching a new ability level) that the system marks as badge-worthy, **When** the learner next views a surface that displays that badge (e.g. a chapter card), **Then** the badge is visible, carries an accessible name describing the achievement, and remains visible on a subsequent page load without needing the triggering event to re-fire.
5. **Given** the learner's score/ability state is still loading or unavailable, **When** a toast or badge component would otherwise render, **Then** no toast or badge renders (no fabricated placeholder achievement, no default level number).

---

### User Story 2 - A learner sees a deliberate "level-up" / "path adjusted" moment for bigger events (Priority: P2)

A toast is a brief, glanceable notification, but reaching a new ability level — or having a learner's path meaningfully recalibrated — is a bigger moment that some learners will want to read about in a sentence or two of "why," not just a headline. The learner wants a deliberate, dismiss-to-continue moment for these larger events, distinct from the routine toast traffic of Phase 1, and it must apply the same supportive framing to a "path adjusted" variant that a downgrade toast already applies.

**Why this priority**: This is real, additional value on top of Phase 1's MVP, but it depends on Phase 1's event-consumption plumbing already existing (the toast queue's event stream is the same stream a modal would listen to), and no modal/dialog component of any kind exists anywhere in this app today to build from — Phase 1 ships value with zero modal work.

**Independent Test**: Trigger an ability-level-up event and a path-adjustment event judged "big enough" for a modal. Confirm a modal opens using the native `<dialog>` element (`.showModal()`), traps focus, closes on Escape, and that the "path adjusted" variant carries no danger/warning token and uses the same entrance/exit motion timing as the level-up variant.

**Acceptance Scenarios**:

1. **Given** the adaptive scoring system emits an event classified as modal-worthy (e.g. an ability-level-up, as distinct from a per-chapter milestone), **When** the event reaches the app, **Then** a modal dialog opens, built on the native `<dialog>` element, explaining the change in a sentence or two.
2. **Given** the modal is open, **When** the learner presses Escape or activates a dismiss control, **Then** the modal closes and focus returns to the point in the page it was opened from.
3. **Given** a "path adjusted" (downgrade) modal is shown, **When** its render output is inspected, **Then** it carries no `--od-danger`/`--od-warning` token or equivalent semantic-negative styling, and its copy follows the same benefit-first, mechanism-naming pattern as the downgrade toast in User Story 1.
4. **Given** a level-up modal and a path-adjusted modal are each triggered in turn, **When** their entrance and exit animations are compared, **Then** both use identical duration and easing tokens — no faster, harsher, or otherwise distinguishable motion is applied based on event kind.

---

### User Story 3 - Motion is polished and the whole feature is independently QA-validated (Priority: P3)

Phase 1 and Phase 2 ship working components, but the count-up/count-down numeric animation in the toast is a hand-rolled quadratic approximation rather than one tuned against this app's real easing tokens, and the badge's "unseen" attention state (a pulse/ring drawing a learner's eye to a new, undiscovered badge) has not been built. Beyond that, nothing in this feature has been checked by anyone other than its own author. The operator wants the whole gamification surface — tokens, contrast, responsiveness, motion performance — validated as a real, independent gate rather than a self-review.

**Why this priority**: Polish and independent validation matter, but they are not blocking — Phase 1 and Phase 2 are fully usable and already accessible without this phase's refinements. This phase closes the gap between "working" and "verified independently to the standard the rest of this design system is held to."

**Independent Test**: Run the gamification components (badge, toast, modal) through `design-toolkit`'s own QA test-bank (`design-toolkit/qa/design-qa-testbank.md`) as an independent reviewer, not the feature's own author, and confirm a pass with zero unresolved findings across the test-bank's token-validity, contrast/WCAG, responsive, and motion-performance checks.

**Acceptance Scenarios**:

1. **Given** the badge's "unseen" (`is-new`) state, **When** a learner views a badge they have not yet seen, **Then** a decorative attention animation plays using existing motion tokens, and the badge's accessible name is unaffected by whether the animation is present.
2. **Given** the toast's numeric count-up/count-down animation, **When** it is compared against this app's real `--od-ease-*` cubic-bezier tokens, **Then** its tween is tuned to match one of those tokens rather than the prototype's hand-rolled quadratic approximation, unless a closer match is judged not worth its extra computation cost (a judgment call to be recorded, not assumed).
3. **Given** the complete gamification component set (badge, toast, modal), **When** it is run through `design-toolkit/qa/design-qa-testbank.md`'s challenge skeleton by a reviewer other than the feature's author, **Then** the review reports zero unresolved findings across token validity, contrast/WCAG, responsive behavior, and motion performance.

---

### Edge Cases

- What happens when two or more events of the same kind (e.g. two `chapter-complete` events) arrive within a short window of each other? → They are coalesced into a single toast rather than each producing its own toast [NEEDS CLARIFICATION: exact coalescing window — the research proposes an illustrative "~4 seconds" but this has not been validated against real event cadence].
- What happens when the toast queue already holds the maximum number of concurrently visible toasts and another event arrives? → The new toast waits in a queue and renders only once a visible slot frees up; it is never dropped silently [NEEDS CLARIFICATION: exact concurrent-visible cap — the research proposes "2" as a measured common UX ceiling, not a validated number for this product].
- What happens when several downgrade (`adjusted`) events fire in quick succession, as can happen while the adaptive scorer is still calibrating against a learner's first few answers? → Downgrade events are debounced/coalesced more aggressively than level-up events specifically, summarizing into a single, matter-of-fact toast per session rather than surfacing each individual recalibration.
- What happens when a learner is a screen-reader user and a toast auto-dismisses while they are still reading it via assistive technology rather than hovering or tabbing to it? → The pause-on-hover/keyboard-focus mechanism covers a sighted keyboard user and a screen-reader user who tabs to the toast, but this has not been validated with an actual screen reader [NEEDS CLARIFICATION: real assistive-technology behavior during auto-dismiss is UNCONFIRMED per the source research and needs a genuine screen-reader test pass, not an assumption from the ARIA contract alone].
- What happens when a badge-worthy milestone and a modal-worthy event occur at effectively the same moment (e.g. completing the chapter that also triggers an ability-level-up)? → Both the badge and the modal may result from the same underlying event; the modal renders above the toast region (its stacking order is higher), and a toast queued behind an open modal still becomes visible once the modal is dismissed, rather than being dropped.
- What happens when the learner's score/ability state is `null` or still loading? → No toast, badge, or modal renders for that state; the components have no "fabricated achievement" or default-to-zero/default-to-level-1 behavior (see User Story 1, Acceptance Scenario 5).
- What happens when a user has `prefers-reduced-motion: reduce` set? → Every entrance/exit animation and the numeric count-up/count-down tween is skipped in favor of jumping directly to final state; the live-region announcement and final rendered content are unaffected.
- What happens when a routine, per-answer scoring delta occurs that is not itself a milestone (not a level-up, not a chapter-complete, not a downgrade)? → It does not produce a toast or a badge at all; routine deltas surface only through existing figure/stat components already in the app, never as a new notification.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST render a toast notification when the adaptive scoring system emits a `level-up`, `chapter-complete`, or `adjusted` (downgrade) event for the current learner.
- **FR-002**: The toast component MUST be built by composing this app's already-vendored `.lk-toast` / `.lk-toast-region` classes (from `learning-kit.css`) rather than forking or duplicating an equivalent CSS class family local to this feature.
- **FR-003**: System MUST NOT render a downgrade (`adjusted`-kind) notification — toast or modal — using the `--od-danger` or `--od-warning` design tokens, nor any semantic-negative modifier class (e.g. `.lk-toast--danger`, `.lk-toast--warning`) that resolves to those tokens. There MUST be no code path by which an `adjusted`-kind event can reach a danger/warning-styled render output.
- **FR-004**: Every toast and modal MUST expose the same information available to a sighted user (achievement kind, headline, and outcome) as screen-reader-equivalent text within a live region (`role="status"` with `aria-live`), so a non-visual user receives the same information a glyph, border color, and headline communicate visually — not merely a notice that "something appeared."
- **FR-005**: A downgrade (`adjusted`-kind) toast or modal MUST use `aria-live="polite"`, never `assertive` — an interrupting announcement would itself read as alarming and contradict the supportive framing requirement.
- **FR-006**: A toast's auto-dismiss timer MUST pause for as long as the toast is hovered by a pointer or holds keyboard focus (including focus arriving via Tab navigation), and MUST resume only after both conditions clear.
- **FR-007**: System MUST cap the number of concurrently visible toasts at [NEEDS CLARIFICATION: exact cap — proposed as 2 in the source research, not validated]; additional pending toasts MUST queue rather than stack unboundedly or be dropped.
- **FR-008**: System MUST coalesce multiple same-kind events arriving within a short window into a single toast rather than rendering one toast per event [NEEDS CLARIFICATION: exact coalescing window — the source research's "~4 seconds" is illustrative, not validated against real adaptive-scoring event cadence].
- **FR-009**: Downgrade (`adjusted`-kind) events specifically MUST be coalesced/debounced more aggressively than level-up or chapter-complete events, reflecting that a downgrade can trigger after as few as three consecutive wrong answers and that repeated downgrade toasts would undermine the supportive framing goal.
- **FR-010**: The achievement badge component MUST render using only design tokens already vendored into this app (`brand-tokens.css`, `kit-tokens.css`) or tokens newly vendored as part of this feature through the existing `sync-*.sh` vendoring mechanism — no literal, un-tokenized color, spacing, radius, or duration value.
- **FR-011**: An achievement badge MUST carry an accessible name (e.g. via `aria-label`) describing the achievement it represents, independent of its visual "seen" vs. "unseen" (`is-new`) state — a screen-reader user MUST NOT depend on a CSS-only affordance to know what a badge means.
- **FR-012**: No toast, badge, or modal MUST render for a `null`, unavailable, or still-loading score/ability state — mirroring this app's existing `LoadStatus<T>` discipline — and none MUST default to a fabricated zero or level-1 value while the real state is unresolved.
- **FR-013**: Every gamification component's motion (entrance/exit animation, and the toast's numeric count-up/count-down tween) MUST honor `prefers-reduced-motion: reduce` by skipping the animated transition and rendering the final state directly, while the live-region announcement and rendered content remain unaffected.
- **FR-014**: System MUST present a modal dialog (distinct from a toast) for adaptive-scoring events classified as significant enough to warrant a deliberate, dismiss-to-continue moment (e.g. an ability-level-up), as opposed to routine per-chapter milestones [NEEDS CLARIFICATION: the exact set of event types routed to a modal vs. a toast is not fully enumerated by the source research beyond "ability-level-up, not per-chapter"].
- **FR-015**: The level-up / path-adjusted modal MUST use the native `<dialog>` element invoked via `.showModal()`, relying on native focus-trap, Escape-to-close, and background-inert behavior rather than a hand-rolled overlay/focus-trap implementation.
- **FR-016**: A "path adjusted" modal variant MUST satisfy the same downgrade-framing constraint as FR-003 (no danger/warning tokens) and MUST follow a benefit-first, mechanism-naming copy pattern (e.g. naming the concrete reason for the adjustment) rather than asserting a bare verdict about the change.
- **FR-017**: Motion (duration and easing) for a downgrade/`adjusted` event MUST be identical to the motion used for a level-up/progress event of the same component type (toast-to-toast, modal-to-modal) — no code path may apply a different, "harsher," or faster motion profile based on event kind.
- **FR-018**: Gamification badge, toast, and modal styling proposals MUST land upstream in `design-system/learning-kit/learning-kit.css` (the canonical shared kit) and be pulled into this app through the existing `sync-learning-kit.sh` vendoring/drift-check mechanism, rather than forking a workshop-local-only copy of the component CSS.
- **FR-019**: The gamification achievement badge MUST use a class namespace distinct from, and never shared with, the existing `.pf-badge--*` provenance/claim-confidence badge family — the two represent different concerns (a learner's achievement vs. a claim's epistemic status) and must remain visually and structurally distinguishable in code.
- **FR-020**: Before Phase 3 is considered complete, the full gamification component set MUST be validated against `design-toolkit/qa/design-qa-testbank.md`'s challenge skeleton (token validity, contrast/WCAG, responsive behavior, motion performance) by a reviewer other than the feature's own author, with all findings resolved or explicitly deferred with a stated reason.
- **FR-021**: The real-time auto-dismiss pause behavior (FR-006) and live-region announcement (FR-004) MUST be validated with an actual screen reader before Phase 1 is considered complete [NEEDS CLARIFICATION: this is currently UNCONFIRMED per the source research — reasoned about via the ARIA/focus contract but never exercised with real assistive technology].

### Key Entities

- **Achievement Event**: An event describing a change in a learner's adaptive-scoring state — kind (`level-up`, `chapter-complete`, or `adjusted`), a headline, a supportive message, and an optional signed score delta. Produced by the separately-specced adaptive scoring system's event stream (see Assumptions); this feature is a consumer of that stream, not its producer.
- **Toast**: A transient, auto-dismissing notification rendered from a queued Achievement Event, composed on top of this app's already-vendored `.lk-toast` component. Has a pause-on-hover/focus auto-dismiss timer and a screen-reader-equivalent announcement.
- **Achievement Badge**: A persistent, inline marker of a milestone (e.g. "completed your first chapter," "reached ability level 7"), shown on relevant surfaces (chapter cards, a profile strip) rather than as a transient notification. Carries a "seen"/"unseen" state and an accessible name independent of that state.
- **Level-Up / Path-Adjusted Modal**: A deliberate, dismiss-to-continue dialog for a bigger adaptive-scoring event, built on the native `<dialog>` element, explaining the event in a sentence or two. Has a "level-up" variant and a "path adjusted" (downgrade) variant, the latter bound by the same framing constraints as the downgrade toast.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A learner receives visible feedback (a toast) for 100% of `level-up`, `chapter-complete`, and `adjusted` adaptive-scoring events reaching the app, with no page reload required.
- **SC-002**: 100% of downgrade (`adjusted`-kind) toasts and modals render with zero danger- or warning-token-derived styling, verified by inspecting rendered output across every event kind the feature handles.
- **SC-003**: 100% of the information a sighted user receives from a toast or modal's glyph, color, and headline is also present as screen-reader-announced text, verified by an accessibility audit (automated check plus a manual screen-reader pass) with zero gaps found.
- **SC-004**: A toast's auto-dismiss timer never fires while the toast is hovered or keyboard-focused, verified across 100% of interaction test runs covering both pointer and keyboard paths.
- **SC-005**: Zero un-tokenized (literal) color, spacing, radius, or duration values appear anywhere in the shipped gamification component styles, verified by static review of the component source against the vendored token set.
- **SC-006**: No more than the configured concurrent-visible-toast cap is ever rendered simultaneously, verified under a simulated burst of same- and mixed-kind events exceeding that cap.
- **SC-007**: A rapid burst of same-kind events (e.g. several `chapter-complete` events within the coalescing window) produces measurably fewer toasts than raw events received, verified by comparing toast-render count to underlying event count in a burst test.
- **SC-008**: Level-up and path-adjusted motion (toast and modal, entrance and exit) are timing- and easing-identical, verified by comparing the animation tokens applied to each event kind.
- **SC-009**: The full gamification component set passes an independent design-toolkit QA test-bank review with zero unresolved findings before Phase 3 sign-off.
- **SC-010**: Zero toasts, badges, or modals render while the learner's score/ability state is `null`, unavailable, or loading, verified against a fixture that exercises that state explicitly.

## Assumptions

- The adaptive scoring system that produces Achievement Events is a separate, already-researched capability (its progress/downgrade event model is referenced in the source research via `workshop/docs/research/education-platform/poc/adaptive_scoring_poc.py`, including its `downgrade_triggered` event fired after three consecutive wrong answers) and is expected to be formally specified under `specs/013-adaptive-assessment-scoring/`. This feature specifies the presentation layer that consumes that event stream; it does not specify the scoring algorithm, its thresholds, or its own event-emission contract.
- The canonical design-token and component source for this work is the umbrella-tracked `design-system/` directory (brand stylesheets, `components-extended.css`, `motion/overlays.css`, and the `learning-kit/` component set), not the `design-toolkit` submodule — the latter is a generator/agent-recipe scaffold that ships no importable component CSS of its own (per the source research's read of `design-toolkit/README.md`), though its `knowledge/` cheat-sheets and `qa/design-qa-testbank.md` are legitimate secondary references and the QA gate this spec's Phase 3 depends on.
- This app already vendors a drift-checked subset of `design-system/` (brand tokens and `learning-kit.css`, including the already-real-but-unused `.lk-badge` and `.lk-toast` classes) via `sync-brand-tokens.sh` / `sync-learning-kit.sh --check`; this feature extends that existing vendoring mechanism rather than introducing a new one.
- Two motion tokens this feature depends on — `--od-ease-bounce` and the overlay scrim/blur tokens used by `.lk-dialog`'s backdrop — exist in `design-system/motion/overlays.css` but are not yet vendored into this app's token set; vendoring them is in scope for Phase 1 (for `--od-ease-bounce`, used by the badge award animation) and Phase 2 (for the modal backdrop), not a separate prerequisite feature.
- No toast/notification queueing service exists anywhere in this app's `core/` layer today; the toast queue (coalescing, capping, debouncing) is new infrastructure built by this feature, not an extension of an existing service.
- "Big enough for a modal" is judged per adaptive-scoring event type (an ability-level-up is modal-worthy; a routine per-chapter milestone is toast-only or badge-only), but the complete, final list of which event types route to a modal versus a toast is an open design decision — see FR-014's NEEDS CLARIFICATION.
- The exact numeric thresholds proposed in the source research (a cap of 2 concurrent toasts, a same-kind coalescing window on the order of seconds) are design proposals grounded in general UX guidance and the adaptive scorer's measured event cadence, not values validated against this product's own learners — see FR-007/FR-008's NEEDS CLARIFICATION markers.
- Real screen-reader validation of the live-region and pause-on-hover/focus behavior has not been performed; it is treated as a Phase 1 completion gate (FR-021) rather than an assumption of correctness.
