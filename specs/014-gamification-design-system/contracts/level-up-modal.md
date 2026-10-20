# Contract: Achievement Modal (Phase 2, spec 014 US2)

*(Written by stream S9, 2026-10-21, after operator-delegate decision O-3: `level-up` and `chapter-complete` are modal-worthy; every other kind, today `adjusted`, is a toast. Implemented in workshop commit 027ad05 on branch `s9-014-modal-polish`.)*

## Routing (`core/achievement-router.ts`)
`AchievementEventRouter.route(event) -> 'modal' | 'toast' | 'dropped'`. Routing is by KIND (`ACHIEVEMENT_MODAL_KINDS`, default `['level-up','chapter-complete']`); the producer's `modal_worthy` flag is advisory and not consulted. A modal is chosen only while a modal host is mounted (`registerHost()`); otherwise every kind is a toast, so no event parks in a queue nothing renders. `dropped` = already acknowledged or already seen this session.

## Queue (`core/achievement-modal-queue.ts`, `AchievementModalService`)
`current`, `pending`, `droppedOverflow` signals; `push`, `markShown(queueId)`, `acknowledge(queueId)`, `reset()`.
1. At most one `current`; it never stacks over another.
2. Events of one area (else coalesce key) delivered before the dialog opens merge into it; once `markShown` has run, later events for that area wait as a new pending modal (the current modal is never rewritten).
3. Waiting modals coalesce per area: one item per kind, level-up first; same-kind items count and sum `scoreDelta` (an `adjusted` delta is never summed).
4. `acknowledge` persists every event id behind the modal via `AchievementAckStore` (`localStorage` key `workshop-achievement-modal-ack:<user>`, newest 500 ids, every access in try/catch, signed-out = memory only). An acknowledged id is never shown again.
5. Pending list bounded at 20 (oldest dropped, counted).
`AchievementModalGate.open` (root signal) is true while a modal is current; toasts hold their auto-dismiss clock while it is.

## Components
`AchievementModalComponent` (`app-achievement-modal`): `modal = input.required<QueuedAchievementModal>()`, outputs `opened` (once) and `closed` (once, however it closed; not on destroy). Native `<dialog>` + `showModal()`; `aria-modal="true"`, `aria-labelledby` (h2 = lead title), `aria-describedby` (body); initial focus on the single Continue control; focus returns to the opener (else `#main`). Escape/Continue/study-link all close through the dialog. FR-022: an `adjusted` item with a mappable `remedialHref` renders one link, closing the dialog when followed. FR-016/FR-003: no danger/warning class for any kind. FR-017: one entrance animation `ach-modal-in` (`--od-dur-base`, `--od-ease-emphasized`), no exit animation, identical for every kind; removed under `prefers-reduced-motion`. Logical properties only (RTL). The template reads only `ModalItem` display fields (title, message, count, scoreDelta, remedialHref): no graded-answer data can reach it.
`AchievementModalHostComponent` (`app-achievement-modal-host`) renders at most one modal and registers itself with the router; it is included by `AchievementToastRegionComponent` (outside the notifications landmark), so the shell needs no further edit.

## Deliberately not in this contract
Wiring the real 013 event source (a later integration step). Styling lives in the component (tokens only); landing `.lk-modal*` upstream in `design-system/learning-kit/learning-kit.css` (FR-018) is NOT done: that file is being edited by another stream.
