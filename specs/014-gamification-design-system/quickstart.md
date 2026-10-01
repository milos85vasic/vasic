# Quickstart: Verify a Level-Up Toast and a Downgrade Toast, Visually

Manual, runnable validation steps for the two Acceptance Scenarios that
matter most for this feature's single hard constraint (FR-003/FR-016): a
downgrade (`adjusted`-kind) toast must NEVER carry `--od-danger`/
`--od-warning` styling. Every command below is expected to be run for real,
with real output/screenshots captured into the implementing task's report —
per this repository's anti-bluff discipline, "should render correctly" is
not evidence; what actually rendered is.

Run from `$VASIC_ROOT/workshop/platform/frontend` unless noted.

## Prerequisites

```bash
node --version                     # this app's pinned Angular 19 toolchain
npm ci                             # or: confirm node_modules/ already installed
bash scripts/sync-learning-kit.sh --check   # MUST exit 0 before starting — a
                                             # drifted vendored copy would make
                                             # every check below meaningless
bash scripts/sync-brand-tokens.sh --check   # same — confirms --od-ease-bounce
                                             # (once vendored, Phase 1 task) is
                                             # present and undrifted
```

## Step 1 — Start the dev server

```bash
npm start   # or: ng serve — confirm the real script name in package.json
            # before running; do not assume "npm start" without checking
```

Open the served app in a browser. Any authenticated route works, since the
toast region (`<app-achievement-toast-region>`) is mounted once in the shell
(`app.component.ts`), not per-route.

## Step 2 — Trigger a level-up toast from the DevTools console

Until spec 013's real adaptive-scoring event stream is wired in, trigger the
queue service directly — this is the same seam a real event-stream consumer
calls through (`AchievementToastService.push()`, per
contracts/achievement-components.md), so exercising it this way is a real
test of the rendering path, not a bypass of it:

```js
// In the browser DevTools console, on a page with the Angular app running:
const injector = ng.getInjector(document.querySelector('app-root'));
const svc = injector.get(await import('/* path to */core/achievement-toast-queue.ts').then(m => m.AchievementToastService));
svc.push({
  id: 'manual-1', kind: 'level-up', title: 'Ability level up',
  message: 'You reached ability level 7 in Retrieval & RAG.',
  scoreDelta: 1, occurredAt: new Date().toISOString(), coalesceKey: 'manual-test',
});
```

(The exact `ng.getInjector` incantation depends on the Angular DevTools
build; if unavailable, a temporary `console.log`-exposed reference on
`window` from a debug build is an acceptable substitute — record which
method was actually used.)

**Confirm, by eye and by DOM inspection**:

1. A toast renders in the toast region, bottom-corner-anchored per
   `.lk-toast-region`'s existing CSS.
2. It carries the `.lk-toast--success` class (inspect via DevTools Elements
   panel) — confirms the level-up path takes the success modifier.
3. The score delta animates from `0` to `+1` over roughly 350ms
   (`--od-dur-slow`).
4. Hover the toast: the auto-dismiss timer visibly does not fire while
   hovered (wait past the default 6000ms with the pointer still over it).
5. Move the pointer away: the toast dismisses shortly after (timer resumed).

## Step 3 — Trigger a downgrade (`adjusted`) toast, and inspect its render output directly — this is the constraint that matters

```js
svc.push({
  id: 'manual-2', kind: 'adjusted', title: 'Path adjusted',
  message: 'We moved your next chapter back one level because the last three answers took longer than expected.',
  scoreDelta: -1, occurredAt: new Date().toISOString(), coalesceKey: 'manual-test-2',
});
```

**The explicit visual check FR-003 exists for** — do all four, not just a
glance:

1. **Open DevTools → Elements, select the rendered toast's root `<div>`,
   read its full `class` attribute.** It MUST read `lk-toast ach-toast
   ach-toast--adjusted` — it MUST NOT contain `lk-toast--danger`,
   `lk-toast--warning`, or `lk-toast--success`. If `--success` is present,
   the component's `[class.lk-toast--success]="achievement().kind !==
   'adjusted'"` binding has a defect; stop and file it before proceeding.
2. **Open DevTools → Elements → Computed styles on that same root element,
   read the resolved `border-left-color` (or equivalent accent-border
   property).** It MUST resolve to the SAME computed color as a level-up
   toast's border (both ultimately `var(--od-accent)`), and MUST NOT
   resolve to the page's `--od-danger` (`#ba1a1a` light theme) or
   `--od-warning` (`#d97706`) computed value. Paste both resolved hex
   values into the task report — a visual "looks fine" is not the check;
   the computed value is.
3. **Read the rendered text.** It MUST lead with the benefit ("We moved
   your next chapter back one level...") rather than a bare verdict
   ("Level decreased"), and MUST carry no exclamation punctuation (spec
   §2.4 point 4).
4. **Confirm the `-1` score delta is NOT rendered in a danger/warning
   color** — per the prototype's own rule
   (`.ach-toast__delta--down { color: var(--od-text-muted); }`), it should
   read as muted body text, not as alarm-red.

## Step 4 — Toggle dark mode and repeat Step 3's class/computed-style check

Use the shell's theme toggle button (`app.component.ts`'s
`(click)="toggleTheme()"`). Repeat Step 3's checks 1 and 2 in dark mode —
the `class` attribute must be identical (no theme-conditional class logic
exists anywhere in this component per its contract), and the computed
`--od-accent`/`--od-danger`/`--od-warning` values will differ numerically
from light mode but the SAME non-equality relationship (accent ≠ danger,
accent ≠ warning) must hold.

## Step 5 — `prefers-reduced-motion` check

In DevTools → Rendering panel (Chrome) or `about:config`
(`ui.prefersReducedMotion`, Firefox), force `prefers-reduced-motion:
reduce`, reload, and repeat Step 2. **Confirm**: the toast appears without
an entrance slide/fade (renders directly in final position/opacity), and
the score-delta figure jumps straight from unset to `+1` with no visible
count-up tween (FR-013). The toast's text content and live-region
announcement are unaffected — only the motion is suppressed.

## Step 6 — Badge (once `<app-achievement-badge>` is composed into
`chapter-list.component.ts`, per plan.md)

```js
// Render a chapter list with at least one chapter whose badge data
// includes `seen: false`.
```

**Confirm**:

1. The badge's `aria-label` (DevTools Accessibility panel, "Computed
   Properties" for the element) reads the full achievement label — not
   just a glyph or a number.
2. The `.is-new` pulse plays once on first render (or is absent, per Step
   5's reduced-motion setting).
3. Reload the page: the SAME badge (if the backing data still reports
   `seen: false`) still shows its `aria-label`/glyph — confirming FR-004
   Acceptance Scenario 4's "survives a page reload" claim is about the
   BADGE'S DATA SOURCE, not about this component fabricating persistence
   of its own (this feature has none — see data-model.md's badge section).

## What this quickstart deliberately does NOT cover

- **Real screen-reader validation** (FR-021) — genuinely different from a
  DevTools Accessibility-panel read of the computed `aria-label`/`aria-live`
  tree above; this quickstart's Accessibility-panel checks are a necessary
  but not sufficient proxy, and FR-021 is explicit that a real
  assistive-technology pass is a separate, UNCONFIRMED-until-run gate.
- **The modal** (Phase 2) — no `<dialog>`/`.showModal()` component exists
  yet to verify.
- **The design-toolkit QA test-bank run** (FR-020/SC-009, Phase 3) — a
  separate, independent-reviewer-run gate, not a self-run quickstart step.
