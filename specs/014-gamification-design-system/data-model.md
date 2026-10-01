# Data Model: Gamification Feedback on the OpenDesign System

Derived from [spec.md](spec.md)'s Key Entities section and the prototype's
real, compiling shape at
`workshop/docs/research/education-platform/poc/achievement-toast.component.ts`.
No backend storage is introduced by this feature — every shape below is a
client-side (in-memory, `signal`-held) type the presentation layer consumes
from an event stream spec 013 owns, not a shape this feature persists.

## Achievement Event (consumed, not produced)

The unit spec 013's adaptive-scoring system is expected to emit. This
feature is a **consumer** of this shape — it specifies neither the scoring
algorithm nor the transport (see spec.md Assumptions). Shape below extends
the prototype's real `AchievementKind`/`AchievementToastData` (file header
comment, `poc/achievement-toast.component.ts:52-72`) with the two fields a
production event stream needs that a hand-instantiated prototype fixture did
not: a stable identity for coalescing (FR-008/FR-009) and an explicit
timestamp (the coalescing window is measured against wall-clock arrival, not
inferred from render order).

```typescript
/** Kept identical to the prototype's real, compiling type — not redefined. */
export type AchievementKind = 'level-up' | 'chapter-complete' | 'adjusted';

export interface AchievementEvent {
  /** Stable id for this specific occurrence, as assigned by the producing
   *  event stream (spec 013). Used for idempotent re-delivery handling —
   *  NOT used for coalescing identity (see `coalesceKey` below). */
  readonly id: string;
  readonly kind: AchievementKind;
  /** Short headline, e.g. "Ability level up" or "Path adjusted". Matches
   *  the prototype's `AchievementToastData.title` (poc file, line 60). */
  readonly title: string;
  /** One or two sentences. For `kind: 'adjusted'`, this is where the
   *  benefit-first, mechanism-naming copy (FR-016, spec §2.4) lives.
   *  Matches the prototype's `message` field (poc file, line 63). */
  readonly message: string;
  /** Signed score change to animate as a count-up/count-down. Matches the
   *  prototype's `scoreDelta` field (poc file, line 68) exactly — optional,
   *  omitted for a milestone event with no numeric component (e.g. a
   *  one-off chapter badge with nothing to count). */
  readonly scoreDelta?: number;
  /** ISO 8601 wall-clock arrival time. Required (not optional, unlike the
   *  prototype's fixture-only shape) because FR-008's coalescing window is
   *  measured against this, not against when the component happened to
   *  render. */
  readonly occurredAt: string;
  /** What this event is "about" for coalescing purposes (FR-008/FR-009) —
   *  e.g. the chapter id for a `chapter-complete` event, the learner's
   *  subject/area id for an `adjusted` event. Two events with the same
   *  `kind` AND the same `coalesceKey`, arriving within the configured
   *  window, merge into one toast (FR-008); events with the same `kind`
   *  but a DIFFERENT `coalesceKey` never merge — completing two different
   *  chapters seconds apart is two real achievements, not one. The exact
   *  window length is [NEEDS CLARIFICATION: FR-008] and is a queue-service
   *  configuration value, not part of this type. */
  readonly coalesceKey: string;
  /** Whether this event's kind is classified as modal-worthy (Phase 2,
   *  FR-014) as opposed to toast/badge-only. Carried on the event itself
   *  (producer-classified) rather than inferred client-side, so the
   *  toast-vs-modal routing decision has one source of truth. Optional and
   *  ignored entirely by Phase 1, which has no modal to route to.
   *  [NEEDS CLARIFICATION: FR-014 — the exact event-type-to-routing map is
   *  not fully enumerated by the source research beyond "ability-level-up,
   *  not per-chapter".] */
  readonly modalWorthy?: boolean;
}
```

## Toast

A transient, auto-dismissing notification rendered from a queued Achievement
Event, composed on top of `.lk-toast`/`.lk-toast-region` (already-vendored,
unmodified). This is the prototype's `AchievementToastData` shape, kept
**unchanged** in the production component's own input — the service layer
(`AchievementToastService`, below) is what's new, not the toast's rendering
contract:

```typescript
/** Unchanged from poc/achievement-toast.component.ts:52-72 — the production
 *  AchievementToastComponent's `achievement` input keeps this exact shape,
 *  per the task's "don't invent a different one" instruction. */
export interface AchievementToastData {
  readonly kind: AchievementKind;
  readonly title: string;
  readonly message: string;
  readonly scoreDelta?: number;
  /** Defaults to 6000ms, unchanged from the prototype (poc file, line 76). */
  readonly autoDismissMs?: number;
}

/** What the queue service actually holds — a `AchievementToastData` plus the
 *  queue-management fields the presentational component never sees directly
 *  (it receives only the `AchievementToastData` slice via its `achievement`
 *  input, per contracts/achievement-components.md). */
export interface QueuedAchievementToast extends AchievementToastData {
  /** Locally-assigned queue id (NOT the same as AchievementEvent.id — a
   *  coalesced toast summarizes N events under one queue id). */
  readonly queueId: string;
  /** Count of underlying events this toast summarizes, for the case
   *  described in FR-008/FR-009 (e.g. "2 chapters completed"). `1` for an
   *  un-coalesced event. Not rendered as a number in an `adjusted`-kind
   *  toast (spec §5.2 point 3 — the count itself is deliberately never
   *  shown to the learner for a downgrade summary). */
  readonly coalescedCount: number;
  readonly enqueuedAt: string;
}
```

## Achievement Badge

A persistent, inline marker of a milestone, shown on relevant surfaces
(chapter cards today, per `chapter-list.component.ts`'s existing `.lk-pill`
row — see plan.md's Project Structure) rather than as a transient
notification.

```typescript
export interface AchievementBadgeMeta {
  readonly id: string;
  /** Distinct from AchievementKind — a badge can represent a milestone that
   *  is not itself one of the three toast kinds (e.g. "first chapter",
   *  which is a `chapter-complete`-triggered badge, vs. "ability level 7",
   *  a `level-up`-triggered one). Kept as a free-form glyph/label pair
   *  (not a closed enum) because badge taxonomy is an adaptive-scoring
   *  concern (spec 013), not this presentation layer's to enumerate. */
  readonly glyph: string;
  /** Accessible name — REQUIRED independent of `seen`, per FR-011: "a
   *  screen-reader user MUST NOT depend on a CSS-only affordance to know
   *  what a badge means." Bound to the badge element's `aria-label`, never
   *  to the decorative `.is-new` ring. */
  readonly label: string;
  readonly earnedAtIso: string;
  /** Drives the `.lk-badge--achievement.is-new` decorative pulse (Phase 3,
   *  FR-011/spec §2.1) — purely visual; `label` above carries the meaning
   *  regardless of this value. */
  readonly seen: boolean;
}
```

## Loading/Unavailable State (FR-012 — reused, not reinvented)

Every component that consumes an `AchievementBadgeMeta` or an
`AchievementEvent`-derived toast MUST gate rendering on the SAME
`LoadStatus<T>` discipline already used by every other data-fetching
component in this app (`core/load-status.ts`, unmodified, imported not
redefined):

```typescript
import type { LoadStatus } from '../../core/load-status';

/** What a badge-displaying surface (e.g. chapter-list) actually holds per
 *  chapter — never a bare `AchievementBadgeMeta | null`, because `null`
 *  conflates "no badge earned" (a determined `ready` with an empty list)
 *  with "don't know yet" (`loading`/`unavailable`) — exactly the defect
 *  class `core/load-status.ts`'s own header comment documents and this
 *  feature must not reintroduce. FR-012's "no fabricated placeholder
 *  achievement, no default level number" is this type-level guarantee,
 *  not a runtime check layered on top of a looser type. */
export type BadgeListStatus = LoadStatus<readonly AchievementBadgeMeta[]>;
```

`AchievementBadgeComponent`/`AchievementToastRegionComponent` render nothing
(not a skeleton, not a zero-state) for `idle`/`loading`/`unavailable` —
see contracts/achievement-components.md for the exact input contract this
produces.

## State Transitions (toast lifecycle, service-owned)

```text
AchievementEvent arrives
        │
        ▼
  same kind + coalesceKey as an already-queued, not-yet-visible toast,
  within the coalescing window (FR-008)?  ── yes ──▶ merge into it,
        │                                            coalescedCount += 1
        no
        │
        ▼
  kind === 'adjusted' AND another 'adjusted' toast already shown/queued
  this session, within the (longer) adjusted-debounce window (FR-009)?
        │                                            ── yes ──▶ merge into
        no                                                      session summary
        │
        ▼
  visible-toast count < cap (FR-007)?
        │
   yes  │  no
        │   └──▶ enqueue, wait for a slot to free
        ▼
   render <app-achievement-toast>, start autoDismissMs timer
        │
        ├── hover or keyboard focus arrives ──▶ pause timer (FR-006)
        ├── both clear ──▶ resume timer
        ├── close button clicked ──▶ dismiss immediately
        └── timer elapses (unpaused) ──▶ dismiss
                │
                ▼
        remove from visible stack; if queue non-empty, promote next
```

This is the queue-service's (`AchievementToastService`,
`core/achievement-toast-queue.ts`) internal state machine — not exposed as a
type of its own, described here because FR-007/FR-008/FR-009/FR-006 are all
properties OF this machine and SC-004/SC-006/SC-007 are all claims ABOUT it,
so the machine itself is load-bearing enough to document before tasks.md
breaks it into unit-testable steps (the research brief §6 Phase 1 gate: "the
rate-limiting logic in §5.2 covered by a unit test the way
`core/load-status.spec.ts` covers its own state machine").
