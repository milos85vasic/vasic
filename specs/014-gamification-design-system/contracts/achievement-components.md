# Contract: Gamification Components (Phase 1)

This feature has no HTTP/RPC surface — it is a set of Angular standalone
components and one injectable service consuming an in-process event stream.
This document is their contract: `input()`/`output()` signal surface for
each component, and the public method/signal surface of the queue service.
Every shape referenced here is defined in [data-model.md](../data-model.md).

All three components are `standalone: true`, inline `template`, inline
`styles` array — this app's real, measured shape for every feature
component (`chapter-rail.component.ts`, `progress.component.ts`), not a
`.html`/`.css` split.

## `AchievementBadgeComponent`

`features/gamification/achievement-badge.component.ts`
Selector: `app-achievement-badge`

```typescript
@Component({ selector: 'app-achievement-badge', standalone: true, /* … */ })
export class AchievementBadgeComponent {
  /** Required — no "empty" state of its own. The caller decides whether to
   *  instantiate one at all (FR-012: a caller holding `loading`/
   *  `unavailable`/an empty list renders NO <app-achievement-badge>,
   *  never one with a fabricated/placeholder `badge`). */
  readonly badge = input.required<AchievementBadgeMeta>();

  /** Emitted once, the first time this badge is viewed while `seen` is
   *  false — lets the caller (a chapter-card list, a profile strip) tell
   *  the backing store "mark this seen" without the component owning any
   *  persistence itself. Never emitted for an already-`seen` badge. */
  readonly viewed = output<void>();
}
```

**Template contract**:
- Root element carries `[attr.aria-label]="badge().label"` — the
  ACCESSIBLE NAME, independent of `seen` (FR-011). Never bound to the
  decorative `.is-new` ring element.
- `[class.is-new]="!badge().seen"` on the SAME element that carries
  `.lk-badge--achievement` (the class this component composes, per FR-002's
  sibling rule for badges — extend `.lk-badge`, never fork it).
- The decorative pulse (`@keyframes lk-badge-announce`, defined upstream in
  `design-system/learning-kit/learning-kit.css` per FR-018) is CSS-only,
  gated by `@media (prefers-reduced-motion: reduce)` removing the animation
  while the final (fully-opaque, un-scaled) visual state remains (FR-013).
- Glyph/number content inside the badge is `aria-hidden="true"` — the
  `aria-label` on the root carries the meaning, per the same
  glyph-is-not-equivalent-information rule the toast applies (FR-004).

## `AchievementToastComponent`

`features/gamification/achievement-toast.component.ts`
Selector: `app-achievement-toast`

Directly descended from the prototype
(`poc/achievement-toast.component.ts`) — same inputs/outputs/signals, same
template shape, with exactly two real-implementation changes the prototype's
own header comment requires:

```typescript
@Component({ selector: 'app-achievement-toast', standalone: true, /* … */ })
export class AchievementToastComponent {
  /** Unchanged from the prototype: required, no empty state. */
  readonly achievement = input.required<AchievementToastData>();

  /** Unchanged from the prototype: emitted once, by timeout or the close
   *  button. The caller (AchievementToastRegionComponent) removes it from
   *  the queue service's visible stack. */
  readonly dismissed = output<void>();

  // Internal signals — unchanged from the prototype:
  //   paused = signal(false)               — set by (mouseenter)/(focusin),
  //                                           cleared by (mouseleave)/(focusout)
  //   glyph = computed(...)                 — GLYPH[achievement().kind]
  //   kindSpokenLabel = computed(...)       — the .sr-only live-region sentence
  //   deltaLabel = computed(...)            — the count-up/count-down display
}
```

**The two real-implementation changes from the prototype**:

1. `prefersReducedMotionLocalCopy()` is DELETED; the component imports and
   calls the real `prefersReducedMotion()` from `core/follow.ts` instead —
   exactly the substitution the prototype's own file-header comment
   mandates ("A real implementation of this component MUST import the real
   helper from `core/follow.ts` instead of the inlined copy below").
2. The `scoreDelta` count-up tween's easing changes from the prototype's
   hand-rolled `1 - Math.pow(1 - t, 2)` quadratic to whichever outcome
   User Story 3 (Phase 3, FR-013/spec Acceptance Scenario 2) records — out
   of scope for this Phase 1 contract; Phase 1 ships the prototype's
   quadratic unchanged, since spec.md explicitly treats the closer-match
   tuning as "a judgment call to be recorded, not assumed," not a Phase 1
   blocker.

**Template contract** (unchanged from the prototype, restated as a contract
rather than re-derived by a future reader):
- Root: `class="lk-toast ach-toast" [class.lk-toast--success]="achievement().kind !== 'adjusted'" [class.ach-toast--adjusted]="achievement().kind === 'adjusted'"` —
  **this is FR-003's entire enforcement mechanism**: there is no
  `[class.lk-toast--danger]`/`[class.lk-toast--warning]` binding anywhere in
  this template, for any `kind`. An `adjusted`-kind toast falls through to
  the bare `.lk-toast` rule (bordered in `var(--od-accent)`,
  `learning-kit.css:1053`) precisely because no conditional in this
  component ever asks for a danger/warning class.
- `role="status"` + `[attr.aria-live]="'polite'"` — unconditionally
  `polite`, for EVERY kind including `adjusted` (FR-005 — never
  `assertive`, since an interrupting announcement would itself read as
  alarming for a downgrade).
- `.sr-only` spoken sentence (`kindSpokenLabel`) carries the same
  achievement-kind/outcome information the glyph + border color communicate
  visually (FR-004) — not a second announcement, part of the SAME live
  region.
- `(mouseenter)`/`(focusin)` set `paused.set(true)`;
  `(mouseleave)`/`(focusout)` set `paused.set(false)` — FR-006's pause
  mechanism, unchanged from the prototype, covering both a sighted
  pointer/keyboard user and (per the prototype's citation of the research
  brief §5.1) a screen-reader user who tabs to the toast, though real
  assistive-technology behavior remains UNCONFIRMED per FR-021 until a real
  screen-reader pass runs.

## `AchievementToastRegionComponent`

`features/gamification/achievement-toast-region.component.ts`
Selector: `app-achievement-toast-region`

The single mount point, composed once into `app.component.ts`'s shell
template (Project Structure in plan.md) — analogous to how the shell already
composes `<router-outlet>` once, not per-route.

```typescript
@Component({ selector: 'app-achievement-toast-region', standalone: true, /* … */ })
export class AchievementToastRegionComponent {
  private readonly queue = inject(AchievementToastService);

  /** Read-only projection of the service's visible-stack signal — this
   *  component has no inputs; it is a pure consumer of the injected
   *  service, matching the shape a `<app-state>`/`<app-rail>` host takes
   *  today (no inputs, service-driven). */
  readonly visible = this.queue.visible; // Signal<readonly QueuedAchievementToast[]>
}
```

**Template contract**:
- Root: `<div class="lk-toast-region" aria-live="polite">` — the
  already-vendored, unmodified region wrapper
  (`learning-kit.css:1034-1045`).
- `@for (t of visible(); track t.queueId) { <app-achievement-toast
  [achievement]="t" (dismissed)="queue.dismiss(t.queueId)" /> }` — each
  queued toast maps 1:1 to one `<app-achievement-toast>`, never more than
  the service's own cap (FR-007/SC-006 — enforced by the SERVICE, not
  re-checked here; this component renders exactly what `visible()` holds).

## `AchievementToastService`

`core/achievement-toast-queue.ts` — `@Injectable({ providedIn: 'root' })`

```typescript
@Injectable({ providedIn: 'root' })
export class AchievementToastService {
  /** The visible stack — never longer than the configured cap (FR-007).
   *  Consumed read-only by AchievementToastRegionComponent. */
  readonly visible: Signal<readonly QueuedAchievementToast[]>;

  /** Entry point for the adaptive-scoring event stream (spec 013's
   *  consumer wiring, out of this feature's scope to define the transport
   *  for). Applies the FULL state machine documented in data-model.md's
   *  "State Transitions" section: coalescing (FR-008), adjusted-kind
   *  debounce (FR-009), cap-and-queue (FR-007) — a caller never needs to
   *  re-implement any of that logic; it hands over one event at a time,
   *  in arrival order, and the service does the rest. */
  push(event: AchievementEvent): void;

  /** Removes a toast from the visible stack (called by
   *  AchievementToastRegionComponent on `(dismissed)`) and promotes the
   *  next queued toast, if any, into the freed slot. */
  dismiss(queueId: string): void;
}
```

**Explicitly NOT part of this service's contract, and stated so a future
reader does not assume it**: it does not itself gate on `LoadStatus` — the
CALLER (whatever wires the adaptive-scoring event stream to `push()`) is
responsible for FR-012's "no toast while score/ability state is
null/loading" by simply never calling `push()` for such a state. The queue
service has no opinion on where its events come from, only on how it
schedules what it is given — the same scope boundary spec.md's Assumptions
section draws for the whole feature ("a consumer of that stream, not its
producer").

## Phase 2 (deferred, not specified by this contract)

`LevelUpModalComponent` (`features/gamification/level-up-modal.component.ts`)
is named in plan.md's Project Structure but its `input()`/`output()` surface
is deliberately NOT specified here — per spec.md's own phasing, User Story 2
"depends on Phase 1's event-consumption plumbing already existing... Phase 1
ships value with zero modal work," and FR-014's exact event-routing set
carries an open `NEEDS CLARIFICATION`. Specifying its contract now would
invent an answer to that open question rather than defer it honestly.
