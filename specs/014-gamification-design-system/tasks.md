---
description: "Task list for feature 014: Gamification Feedback on the OpenDesign System"
---

# Tasks: Gamification Feedback on the OpenDesign System

**Input**: Design documents from `specs/014-gamification-design-system/`
**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [data-model.md](data-model.md), [contracts/achievement-components.md](contracts/achievement-components.md), [quickstart.md](quickstart.md)

## Format: `[ID] [P?] [TDD?] [REVIEW?] [SUBAGENT?] [BLOCKED?] [Story] Description`

`[P]` parallelizable (different files, no dependency) · `[TDD]` write the test
first, confirm RED, then implement to GREEN · `[REVIEW]` requires a reviewer
other than the feature's own implementer before the task is considered done ·
`[SUBAGENT]` delegable to a subagent as a self-contained unit · `[BLOCKED]`
waiting on a named external dependency (a cross-spec contract, an operator
decision) rather than on engineering capacity within this feature.

**Global Constraints** (from plan.md's Technical Context / Constitution Check
and data-model.md — every task's requirements implicitly include these):

- All new production code lands in `workshop/platform/frontend` (Angular 19,
  standalone components, `input()`/`output()`/`signal()`/`computed()` — never
  the decorator-based `@Input()`/`@Output()` style). Tests are colocated
  `*.spec.ts` files (Karma/Jasmine), matching every existing file under
  `core/*.spec.ts` and `features/*/*.spec.ts`.
- FR-003/FR-016 is the one hard constraint every phase touching a toast or
  modal must re-verify, not just the task that first implements it: an
  `adjusted`-kind (downgrade) render output MUST carry no `--od-danger`/
  `--od-warning` token and no `.lk-toast--danger`/`.lk-toast--warning` (or
  equivalent) class, on any code path.
- Zero un-tokenized literal color/spacing/radius/duration values (FR-010,
  SC-005) — every new style resolves through an already-vendored or
  newly-vendored (via the existing `sync-*.sh` mechanism, never hand-typed)
  `var(--od-*)`/`var(--lk-*)` custom property.
- No forked/duplicated `.lk-toast`/`.lk-badge` CSS class family (FR-002) —
  new component-specific styling composes on top of the vendored classes,
  and any genuinely new shared rule (the `.lk-badge--achievement` class, the
  toast-exit keyframe) lands upstream in `design-system/learning-kit/learning-kit.css`
  first (FR-018), then is pulled down through `sync-learning-kit.sh`.
- No `<app-achievement-toast>`/`<app-achievement-badge>` render while the
  learner's score/ability state is `null`/loading/unavailable (FR-012) — gate
  on the SAME `LoadStatus<T>` discipline (`core/load-status.ts`) every other
  data-fetching component in this app already uses; never a bare
  `| null` check.
- Every "this was verified" claim in a task's completion note MUST be backed
  by real, pasted command/test output — per this repository's anti-bluff
  discipline (constitution §11.4 — "verified", "tested", "working" are
  forbidden words without pasted output from the session that did the work).
- This plan does not create a feature branch (spec.md's header, operator
  simplification decision) — work happens directly against `main`.

## Cross-spec dependency — read before starting Phase A's event-wiring tasks (T017)

**Spec 013 (`specs/013-adaptive-assessment-scoring/`, status: Draft) does not
yet define an `AchievementEvent`-shaped stream.** Confirmed by reading its
`data-model.md`: it defines `ResponseLogEntry.DowngradeTriggered bool` (a
per-response log field) and an `AbilityScore` struct (a fast-read 0-10
number), but no event type, no endpoint, and no notification contract
resembling this feature's `AchievementEvent` (`kind`/`title`/`message`/
`coalesceKey`/`occurredAt`/`modalWorthy`). Confirmed by directory search: `workshop/platform/backend` has no
`ability.go`/`downgrade.go` implementation file, and no `AchievementEvent`-shaped
stream, anywhere in the tree. It does already contain a real, pre-existing
`pkg/assessment` package — `boundary.go`, `coverage.go`, `progress.go`,
`question.go`, `serve.go`, `store.go`, `doc.go`, `proofs_test.go`, and each of
their `_test.go` siblings (14 files) — plus
`internal/api/assessment_disclosure.go`,
`internal/api/assessment_submit_body.go`, and three further
`assessment_*_test.go` files under `internal/api/` (roughly 19 items total
referencing "assessment" by filename). That package is a separate,
pre-existing quiz/grading subsystem, unrelated to spec 013's forthcoming
adaptive-scoring work — none of its files implement `ability.go`,
`downgrade.go`, or anything resembling this feature's `AchievementEvent`
shape. The core conclusion is therefore unchanged: this is not a gap in this
feature's own design; it is a genuinely unbuilt upstream
dependency, and spec 014's own `spec.md` Assumptions section and
`contracts/achievement-components.md`'s closing section already say so
explicitly. Task T017 below is the single task that depends on this; every
other Phase A task uses the manual `AchievementToastService.push()` seam
(quickstart.md Step 2) and is not blocked by it.

---

## Phase 1: Setup & Foundational (Shared Infrastructure)

**Purpose**: The shared types and vendored tokens every user story depends on.

**⚠️ CRITICAL**: No user-story work can begin until this phase is complete.

- [ ] **T001 [P]** Create `workshop/platform/frontend/src/app/core/achievement-types.ts` with the shapes from [data-model.md](data-model.md): `AchievementKind`, `AchievementEvent`, `AchievementToastData` (kept identical to the prototype's shape — see the note below), `QueuedAchievementToast`, `AchievementBadgeMeta`, and `BadgeListStatus` (a `LoadStatus<readonly AchievementBadgeMeta[]>` type alias, importing `LoadStatus` from `./load-status`, never redefining it). This is the single source every other Phase A/B/C task imports from — no component or service below should restate any of these shapes locally.

- [ ] **T002 [P]** Extend `workshop/platform/frontend/scripts/sync-brand-tokens.sh` to also copy `--od-ease-bounce` (and, for Phase B's later use, the overlay scrim/blur tokens) from `design-system/motion/overlays.css` into `workshop/platform/frontend/src/styles/brand/brand-tokens.css`, preserving the script's existing three-valued `--check` exit contract (0/1/2) unchanged. Run `bash scripts/sync-brand-tokens.sh` (real mode, not `--check`) once to perform the vendoring, then run `bash scripts/sync-brand-tokens.sh --check` and paste the real exit code and output confirming it now reports the vendored copy byte-identical to source, with `--od-ease-bounce` present in `brand-tokens.css`.

- [ ] **T003 [P]** Land `.lk-badge--achievement` (a namespace distinct from the existing `.pf-badge--*` family per FR-019 — confirm no shared class name by grepping `design-system/learning-kit/learning-kit.css` for `pf-badge` first) plus its `.is-new` decorative pulse keyframe (using the now-vendored `--od-ease-bounce`, gated by `@media (prefers-reduced-motion: reduce)` per FR-013) and a toast-exit keyframe (currently absent — `.lk-toast` has entrance-only animation today, per plan.md's Project Structure note) upstream in `design-system/learning-kit/learning-kit.css`. Then run `bash workshop/platform/frontend/scripts/sync-learning-kit.sh --check`, confirm it now reports drift (the upstream file changed but the vendored copy has not been refreshed), then run it in real mode, then `--check` again to confirm it now exits 0. Paste all three real outputs.

**Checkpoint**: Types and tokens exist and are vendored — every user story below may now begin.

---

## Phase A: User Story 1 — Toast + badge MVP (Priority: P1) 🎯 MVP

**Goal**: The three real event kinds (`level-up`, `chapter-complete`,
`adjusted`) each produce a toast; milestone events produce a persistent
badge; the downgrade-framing constraint (FR-003) and accessibility parity
(FR-004) are enforced by a real test, not by review.

**Independent Test**: quickstart.md Steps 1-5 against a running dev server,
plus the full new Karma/Jasmine suite.

### Queue service (core infrastructure for this story)

- [ ] **T004 [TDD] [US1]** Write a failing test in `workshop/platform/frontend/src/app/core/achievement-toast-queue.spec.ts` asserting `AchievementToastService`'s cap-and-coalesce behavior from data-model.md's state-transition diagram: pushing more same-kind/same-`coalesceKey` events than the configured concurrent-visible cap within the coalescing window results in (a) same-kind+same-`coalesceKey` events merging into one toast with `coalescedCount` incremented, and (b) the visible stack never exceeding the cap, with excess toasts queued rather than dropped (assert on `service.visible().length` and on a still-pending queued item's presence after cap is reached). Run it; confirm it fails with `Cannot find module './achievement-toast-queue'` (module does not exist yet) — paste the real failure output.

- [ ] **T005 [US1]** Implement `AchievementToastService` (`core/achievement-toast-queue.ts`, `@Injectable({ providedIn: 'root' })`) per contracts/achievement-components.md's public surface (`visible: Signal<readonly QueuedAchievementToast[]>`, `push(event)`, `dismiss(queueId)`), implementing only the cap-and-coalesce half of the state machine for now. Run T004; confirm GREEN, paste real output.

- [ ] **T006 [TDD] [US1]** Add a failing test (same spec file) for the `adjusted`-kind debounce (FR-009): two `adjusted` events arriving within the (longer) adjusted-debounce window merge into a single session-summary toast even when their `coalesceKey`s differ — distinct from T004's same-`coalesceKey` merge rule, since FR-009 requires more aggressive debouncing specifically for downgrades regardless of what the event is "about." Confirm RED.

- [ ] **T007 [US1]** Implement the adjusted-kind debounce branch in `AchievementToastService.push()`. Run T006; confirm GREEN, paste real output. Run the full `achievement-toast-queue.spec.ts` file; confirm all tests pass.

### Toast component — the two required TDD gates (FR-003, FR-004)

- [ ] **T008 [TDD] [US1]** Write a failing test in `workshop/platform/frontend/src/app/features/gamification/achievement-toast.component.spec.ts` for **FR-003's danger/warning absence** — this is the RED assertion the task explicitly calls for, written before the production component exists:

  ```typescript
  import { ComponentFixture, TestBed } from '@angular/core/testing';
  import { By } from '@angular/platform-browser';
  import { AchievementToastComponent } from './achievement-toast.component';
  import type { AchievementToastData } from '../../core/achievement-types';

  describe('AchievementToastComponent — FR-003 downgrade framing', () => {
    let fixture: ComponentFixture<AchievementToastComponent>;

    function render(achievement: AchievementToastData): void {
      fixture = TestBed.createComponent(AchievementToastComponent);
      fixture.componentRef.setInput('achievement', achievement);
      fixture.detectChanges();
    }

    beforeEach(() => TestBed.configureTestingModule({ imports: [AchievementToastComponent] }));

    it('renders an adjusted-kind achievement with no danger/warning class', () => {
      render({ kind: 'adjusted', title: 'Path adjusted', message: 'We moved your next chapter back one level.' });
      const root = fixture.debugElement.query(By.css('.lk-toast')).nativeElement as HTMLElement;
      expect(root.classList.contains('lk-toast--danger')).toBeFalse();
      expect(root.classList.contains('lk-toast--warning')).toBeFalse();
      expect(root.classList.contains('lk-toast--success')).toBeFalse();
    });

    it('resolves the adjusted-kind border color to --od-accent, never --od-danger/--od-warning', () => {
      render({ kind: 'adjusted', title: 'Path adjusted', message: 'We moved your next chapter back one level.' });
      const root = fixture.debugElement.query(By.css('.lk-toast')).nativeElement as HTMLElement;
      const rootStyle = getComputedStyle(document.documentElement);
      const dangerHex = rootStyle.getPropertyValue('--od-danger').trim();
      const warningHex = rootStyle.getPropertyValue('--od-warning').trim();
      const accentHex = rootStyle.getPropertyValue('--od-accent').trim();
      const resolvedBorder = getComputedStyle(root).borderInlineStartColor;
      // Resolve each custom-property hex through the same element so the
      // comparison is computed-value-to-computed-value, not hex-to-computed.
      const probe = document.createElement('div');
      root.appendChild(probe);
      probe.style.color = accentHex;
      const accentComputed = getComputedStyle(probe).color;
      probe.style.color = dangerHex;
      const dangerComputed = getComputedStyle(probe).color;
      probe.style.color = warningHex;
      const warningComputed = getComputedStyle(probe).color;
      probe.remove();
      expect(resolvedBorder).toBe(accentComputed);
      expect(resolvedBorder).not.toBe(dangerComputed);
      expect(resolvedBorder).not.toBe(warningComputed);
    });
  });
  ```

  Run `ng test --include='**/achievement-toast.component.spec.ts'` (or this app's real equivalent test command — confirm the exact script name in `package.json` before running, per quickstart.md's own instruction not to assume). Confirm it fails because `./achievement-toast.component` does not exist yet. Paste the real failure output.

- [ ] **T009 [TDD] [US1]** Add a failing test to the same spec file for **FR-004's live-region accessibility parity** and **FR-005's `polite`-only constraint**:

  ```typescript
  describe('AchievementToastComponent — FR-004/FR-005 live-region parity', () => {
    it.each all three kinds ['level-up', 'chapter-complete', 'adjusted'] as const)(
      'exposes a role=status/aria-live=polite region with non-empty sr text for kind=%s',
      (kind) => {
        render({ kind, title: 'x', message: 'y' });
        const region = fixture.debugElement.query(By.css('[role="status"]'));
        expect(region).not.toBeNull();
        expect(region!.attributes['aria-live']).toBe('polite');
        const srText = fixture.debugElement.query(By.css('.sr-only')).nativeElement.textContent.trim();
        expect(srText.length).toBeGreaterThan(0);
      },
    );

    it('never uses aria-live=assertive for an adjusted-kind toast', () => {
      render({ kind: 'adjusted', title: 'Path adjusted', message: 'We moved your next chapter back.' });
      const region = fixture.debugElement.query(By.css('[role="status"]'));
      expect(region!.attributes['aria-live']).toBe('polite');
    });
  });
  ```

  (Adjust the `it.each`/parameterization syntax to this codebase's actual Jasmine convention — confirm by reading one existing parameterized test in `core/*.spec.ts` first, per T-none below; do not assume Jasmine 5's `it.each` exists without checking `package.json`'s pinned Jasmine version.) Confirm RED for the same reason as T008 — component does not exist yet.

- [ ] **T010 [SUBAGENT] [US1]** Promote the prototype (`workshop/docs/research/education-platform/poc/achievement-toast.component.ts`) into `workshop/platform/frontend/src/app/features/gamification/achievement-toast.component.ts`: same selector shape, template, inputs (`achievement = input.required<AchievementToastData>()`), outputs (`dismissed = output<void>()`), and internal signals, importing `AchievementToastData`/`AchievementKind` from `core/achievement-types.ts` (T001) rather than redefining them. Apply the prototype's own two mandated real-implementation changes (per contracts/achievement-components.md): (1) delete `prefersReducedMotionLocalCopy()` and import the real `prefersReducedMotion()` from `core/follow.ts` instead; (2) keep the count-up tween's quadratic easing unchanged for Phase 1 (Phase C/User Story 3 owns any retuning). Run T008 and T009; confirm both now pass GREEN. Paste real test output.

### Badge component

- [ ] **T011 [TDD] [P] [US1]** Write a failing test in `features/gamification/achievement-badge.component.spec.ts` for **FR-011**: render `AchievementBadgeComponent` once with `{ ..., seen: false }` and once with `{ ..., seen: true }`, asserting `aria-label` on the root element equals `badge.label` in BOTH cases (the accessible name must not depend on `seen`), and that the glyph/number content element carries `aria-hidden="true"`. Confirm RED.

- [ ] **T012 [US1]** Implement `AchievementBadgeComponent` (`features/gamification/achievement-badge.component.ts`) per contracts/achievement-components.md: `badge = input.required<AchievementBadgeMeta>()`, `viewed = output<void>()`, `[attr.aria-label]="badge().label"` on root, `[class.is-new]="!badge().seen"` alongside `.lk-badge--achievement`, glyph content `aria-hidden="true"`. Run T011; confirm GREEN.

### Region mount, composition, and the null-state gate

- [ ] **T013 [US1]** Implement `AchievementToastRegionComponent` (`features/gamification/achievement-toast-region.component.ts`) per contracts/achievement-components.md: injects `AchievementToastService`, renders `.lk-toast-region` + one `<app-achievement-toast>` per `visible()` entry, `(dismissed)` calls `queue.dismiss(t.queueId)`. Mount it once in `app.component.ts`'s shell template, analogous to the existing `<router-outlet>`/footer composition. Depends on T005/T007 (service) and T010 (toast component).

- [ ] **T014 [P] [US1]** Compose `<app-achievement-badge>` into `features/chapters/chapter-list.component.ts`'s existing `.facts` `.lk-pill` row (around lines 106-131, the same inline-composition pattern already used for `durationOf`/transcript pills), gated on a `BadgeListStatus` input per FR-012: render nothing for `idle`/`loading`/`unavailable`, iterate the badge list only for `ready`.

- [ ] **T015 [TDD] [US1]** Write a failing test asserting **FR-012**: with `BadgeListStatus` in `loading` and in `unavailable` state, `chapter-list.component`'s rendered output contains zero `<app-achievement-badge>` elements (no skeleton, no placeholder). Confirm RED against T014's implementation if it does not yet gate correctly, or confirm it is already GREEN if T014 gated correctly on first pass — state explicitly which occurred in the completion note (per this repository's anti-bluff discipline, do not claim RED-then-GREEN if the gate was correct on the first implementation).

### Cross-spec wiring (the one task genuinely blocked by another feature)

- [ ] **T016 [BLOCKED] [US1]** Wire spec 013's adaptive-scoring event stream to `AchievementToastService.push()`. **Do not start this task until spec 013 (`specs/013-adaptive-assessment-scoring/`) ships both an implemented backend surface (confirmed absent today — no `ability.go`/`downgrade.go` under `workshop/platform/backend`) and an explicit mapping from its `ResponseLogEntry.DowngradeTriggered`/`AbilityScore` shapes into this feature's `AchievementEvent` shape** (`kind`/`coalesceKey`/`occurredAt` — none of which spec 013's current `data-model.md` defines). This is a real, named external dependency, not an estimate of effort — see "Cross-spec dependency" above. User Story 1 is independently complete and demonstrable without this task, via the manual `push()` seam quickstart.md Step 2 already documents; this task exists so the dependency is tracked rather than silently assumed resolved. **Revisit this tasks.md once spec 013 lands its event-emission contract.**

### Verification

- [ ] **T017 [US1]** Run `quickstart.md` Steps 1-4 for real against a running dev server: level-up toast render + class inspection, downgrade toast's four explicit checks (class attribute, computed border-color in both light and dark theme, copy wording, muted (not alarm-colored) delta). Paste the real classList strings and the real computed color values for both themes — quickstart.md's own instruction: "a visual 'looks fine' is not the check; the computed value is."

- [ ] **T018 [US1]** Run `quickstart.md` Step 5 (`prefers-reduced-motion: reduce`) for real; confirm and paste evidence that the toast renders without an entrance animation and the score-delta jumps directly to its final value.

- [ ] **T019 [P] [US1]** Run the full new Karma/Jasmine suite (`achievement-toast-queue.spec.ts`, `achievement-toast.component.spec.ts`, `achievement-badge.component.spec.ts`, plus any `chapter-list.component.spec.ts` additions from T015) and paste the real pass/fail summary.

**Checkpoint**: User Story 1 is independently complete, tested, and
demonstrable — this is the MVP. T016 remains open, tracked, and does not
block this checkpoint.

---

## Phase B: User Story 2 — Level-up / path-adjusted modal (Priority: P2)

**Goal**: A deliberate, dismiss-to-continue `<dialog>` moment for bigger
events, with the same downgrade-framing and motion-parity constraints as
Phase A's toast.

**Decision on how to handle FR-014's open routing question (the instruction's
"your call, but say which"): this phase is scoped as BLOCKED on a
contract-definition sub-task (T020) rather than as a guessed minimal
implementation.** `contracts/achievement-components.md` itself explicitly
declines to specify `LevelUpModalComponent`'s input/output surface, stating
that doing so "would invent an answer to [FR-014's NEEDS CLARIFICATION]
rather than defer it honestly." Writing an implementation task now that
silently picks an event-routing map would violate the same no-guessing
discipline (constitution §11.4.6) this repository's spec docs apply
everywhere else. T020 is therefore the actual first task of this phase — a
real, completable piece of work (producing a decision, not an estimate) — and
every implementation task below it names T020 as a hard dependency rather
than assuming a routing map that does not exist yet.

**Independent Test**: Once T020-T024 land, trigger a modal-worthy event and a
toast-worthy event side by side and confirm only the modal-worthy one opens a
`<dialog>`.

- [ ] **T020 [US2]** Resolve FR-014's NEEDS CLARIFICATION: produce the exact event-type-to-routing map (which `AchievementKind`/event-classification values are `modalWorthy`) as an operator-confirmed decision, recorded in a short addendum to `data-model.md`'s `AchievementEvent.modalWorthy` field comment. This is a product decision requiring operator input, not an engineering estimate — do not proceed past this task by picking a plausible-looking default.

- [ ] **T021 [SUBAGENT] [US2]** Once T020 resolves, write `LevelUpModalComponent`'s contract in a new `specs/014-gamification-design-system/contracts/level-up-modal.md`, mirroring `achievement-components.md`'s format (inputs/outputs/signals, template contract, the FR-016 downgrade-framing restatement for the "path adjusted" variant).

- [ ] **T022 [TDD] [US2]** Write a failing test in `features/gamification/level-up-modal.component.spec.ts` for FR-016 (the modal's own downgrade-framing constraint — the same danger/warning-absence assertion pattern as T008, applied to the "path adjusted" variant's rendered `<dialog>` content) and for FR-015 (the dialog is a native `<dialog>` element, opened via `.showModal()`, closes on Escape). Confirm RED.

- [ ] **T023 [TDD] [US2]** Write a failing test for **FR-017's motion parity**: render a level-up modal and a path-adjusted modal in turn, read each's resolved `animation-duration`/`animation-timing-function` via `getComputedStyle` on the entrance/exit-animated element, and assert they are identical between the two variants. Confirm RED.

- [ ] **T024 [US2]** Implement `LevelUpModalComponent` per T021's contract: native `<dialog>` + `.showModal()` (FR-015, relying on native focus-trap/Escape/background-inert rather than a hand-rolled overlay), the overlay scrim/blur tokens vendored in T002, identical motion tokens for both variants (FR-017). Run T022 and T023; confirm both GREEN.

- [ ] **T025 [US2] [BLOCKED]** Wire modal-worthy events from the same event stream the toast queue consumes (plan.md Summary: "the toast queue's event stream is the same stream a modal would listen to"). Blocked on BOTH T016 (spec 013's event source, Phase A) and T020 (the routing map) — do not start until both are resolved.

- [ ] **T026 [US2]** Add the modal verification steps quickstart.md explicitly says do not yet exist ("The modal (Phase 2) — no `<dialog>`/`.showModal()` component exists yet to verify") as a new quickstart.md section, then run them for real and paste output.

**Checkpoint**: User Story 2 complete, conditional on T020's operator
decision landing.

---

## Phase C: User Story 3 — Motion polish + independent QA gate (Priority: P3)

**Goal**: The badge's "unseen" attention animation ships, the count-up
tween's easing choice is a recorded decision rather than an unexamined
holdover, and the complete component set passes an independent QA review.

**Independent Test**: `design-toolkit/qa/design-qa-testbank.md`'s challenge
skeleton run by a reviewer other than this feature's own implementer, with
zero unresolved findings.

- [ ] **T027 [P] [US3]** Wire the `.is-new` pulse keyframe (landed upstream in T003, using `--od-ease-bounce`) into `AchievementBadgeComponent`'s already-bound `[class.is-new]` (T012) — confirm the CSS keyframe actually plays for an unseen badge and is suppressed under `prefers-reduced-motion: reduce` (the keyframe's own `@media` guard from T003), by inspecting the rendered computed `animation-name` in both states.

- [ ] **T028 [US3]** Record the count-up tween judgment call (spec.md Acceptance Scenario 2 / contracts.md: "a judgment call to be recorded, not assumed"): compare the prototype's quadratic `1 - Math.pow(1 - t, 2)` tween against `--od-ease-standard`'s `cubic-bezier(0.4, 0, 0.2, 1)`. Either retune `AchievementToastComponent`'s tween to the token-matched easing, or explicitly record in this task's completion note why the quadratic approximation is being kept (e.g., a stated computation-cost tradeoff) — either outcome is acceptable per the spec; silently leaving it unexamined is not.

- [ ] **T029 [TDD] [US3]** Write a failing test asserting `prefers-reduced-motion: reduce` (mocked via a `matchMedia` stub in the spec, matching this codebase's real convention for testing `core/follow.ts` consumers) suppresses BOTH the badge's `.is-new` pulse and the toast's count-up tween — the score-delta figure must render its final value directly with no intermediate animated frames. Confirm RED, then confirm GREEN once T027/T028 satisfy it (implement any remaining gate if not already covered).

- [ ] **T030 [REVIEW] [US3]** Run the complete gamification component set (badge, toast, and the modal if Phase B's T020-T026 landed by this point — state explicitly which components were actually in scope for this run if the modal was not yet built) through `design-toolkit/qa/design-qa-testbank.md`'s challenge skeleton (confirmed present at that path). **This review MUST be performed by someone other than this feature's own implementer**, per spec.md's explicit Acceptance Scenario 3 requirement and FR-020. Record the reviewer's identity, the exact findings (token validity, contrast/WCAG, responsive behavior, motion performance), and for each finding either a fix landed in a follow-up commit or an explicit, stated reason for deferral. Zero unresolved findings with no stated reason is the completion bar (FR-020/SC-009) — a self-review by the implementer does not satisfy this task regardless of thoroughness.

- [ ] **T031 [P] [US3]** *(stretch, non-blocking — explicitly out of this plan's committed scope per plan.md's own Constitution Check §11.4.218 row: "closing it for the entire learning-kit component family is out of this plan's scope")* Add a living-catalogue entry for `.lk-badge--achievement` and the gamification `.lk-toast` variant to `design-system/preview/components.html`, alongside the existing `.od-toast--*`/`.od-popover` entries. Include only if time permits after T030; do not let it block Phase C's checkpoint.

**Checkpoint**: All in-scope user stories independently functional and
verified. User Story 2 remains conditional on its own T020 decision; User
Story 1's T016 cross-spec wiring remains tracked-but-open per the Cross-spec
dependency section above.

---

## Phase: Polish

- [ ] **T032 [P]** Run the full `workshop/platform/frontend` Karma/Jasmine suite (not just the new spec files) to confirm zero regression in existing components touched by this feature (`app.component.ts`, `chapter-list.component.ts`). Paste the real pass/fail summary.
- [ ] **T033** Re-run `bash scripts/sync-brand-tokens.sh --check` and `bash scripts/sync-learning-kit.sh --check` one final time to confirm both still exit 0 after every implementation task above — a drifted vendored copy at the end of this feature would silently reopen the FR-010/FR-018 constraints every earlier task closed.
- [ ] **T034** Update this project's own doc-sync artifacts (per the umbrella's documentation-sync discipline) noting this feature's real completion state — explicitly distinguishing "User Story 1 shipped and verified," "User Story 2 blocked on T020," and "User Story 3's T030 independent-review outcome" rather than a single blanket "done."

---

## Dependencies & Execution Order

- **Phase 1 (Setup/Foundational)**: No dependencies. T001/T002/T003 are
  mutually independent (`[P]`) and block every later phase.
- **Phase A (US1)**: Depends on Phase 1. T004→T005→T006→T007 (queue service)
  is a strict sequence within one file. T008/T009 (toast component tests) may
  be written in parallel with each other and with T011 (badge test), but T010
  (toast implementation) must follow both T008 and T009. T013 depends on
  T005/T007 and T010. T014/T015 depend on T012. **T016 is the only task in
  this phase blocked on work outside this feature** and does not gate the
  Phase A checkpoint.
- **Phase B (US2)**: Depends on Phase 1. **T020 is the actual first task** —
  every other task in this phase (T021-T026) depends on it. T025 additionally
  depends on T016 (Phase A). This phase may be worked in parallel with Phase A
  once Phase 1 is done, but its own checkpoint cannot close until T020 is
  resolved.
- **Phase C (US3)**: Depends on Phase A's T010/T012 (the toast/badge
  components it polishes) and T003 (the upstream `.is-new` keyframe). T030
  (the independent QA gate) should run last within this phase, after T027-T029
  land, and may optionally include Phase B's modal if it is ready by then.
- **Polish**: Depends on all phases the operator has chosen to complete.

## Parallel Execution Notes

Phase A and Phase B touch disjoint new files (`achievement-toast*`/
`achievement-badge*` vs. `level-up-modal*`) and may be dispatched to separate
subagents once Phase 1 lands, **except** that both eventually touch the same
event-stream wiring seam (T016/T025) — sequence those two specifically rather
than parallelizing them. Within Phase A, T008 and T009 write to the same new
spec file (`achievement-toast.component.spec.ts`) — dispatch them as a single
sequential pair (or one subagent doing both), not two parallel subagents
writing to the same file, per this repository's own established convention
for same-file task pairs (see specs/009's Parallel Execution Notes for the
identical reasoning applied to `meeting_notes.py`).
