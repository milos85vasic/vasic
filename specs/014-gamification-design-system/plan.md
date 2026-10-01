# Implementation Plan: Gamification Feedback on the OpenDesign System

**Branch**: N/A — no feature branch created, per the same explicit operator
simplification decision recorded in `spec.md`'s header.
**Date**: 2026-09-30 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/014-gamification-design-system/spec.md`

## Summary

Turn the completed research brief and its prototype
(`workshop/docs/research/education-platform/gamification-and-design-system.md`,
`poc/achievement-toast.component.ts`) into production Angular components in
`workshop/platform/frontend`: a toast, an achievement badge, and (Phase 2) a
level-up/path-adjusted modal, all consuming the adaptive-scoring event stream
spec 013 will formally define and all composed strictly on top of this app's
real, already-vendored OpenDesign-descended primitives (`.lk-toast`,
`.lk-badge`, the vendored `--od-*`/`--lk-*` tokens) rather than any new,
ad-hoc CSS. The one hard behavioral constraint carried through every layer of
this plan is FR-003/FR-016: a downgrade (`adjusted`-kind) event must never
reach a `--od-danger`/`--od-warning`-styled render path, enforced as an
absence of a code path (no `.lk-toast--danger` branch exists to take) rather
than as a rule someone has to remember.

## Technical Context

**Language/Version**: TypeScript, Angular **19.2** (`@angular/core: ^19.2.0`,
confirmed in `workshop/platform/frontend/package.json`) — standalone
components, function-based `input()`/`output()`/`signal()`/`computed()` APIs,
matching the real, measured convention of every existing feature component in
this app (`core/rail.component.ts:260`, `features/chapters/chapter-rail.component.ts:126-132`),
not the decorator-based `@Input()`/`@Output()` style.

**Primary Dependencies**: None new. This feature adds zero npm packages. It
composes the already-vendored CSS in
`workshop/platform/frontend/src/styles/learning-kit/learning-kit.css`
(`.lk-toast`, `.lk-toast-region`, `.lk-badge`) and
`src/styles/brand/brand-tokens.css` (`--od-*` tokens), both loaded today via
`angular.json`'s `styles` array (lines 39-46), and extends the existing
`scripts/sync-brand-tokens.sh` / `scripts/sync-learning-kit.sh --check`
vendoring mechanism rather than introducing a new one.

**Storage**: N/A for Phase 1/2 presentational components. The achievement
badge's "seen"/"unseen" persistence (FR-004 Acceptance Scenario 4: a badge
"remains visible on a subsequent page load") is out of this plan's storage
design — it depends on however spec 013's adaptive-scoring system persists
milestone state server-side; this feature renders what that system reports
through `LoadStatus<T>`, it does not invent its own badge-earned registry.

**Testing**: Karma/Jasmine `*.spec.ts` colocated with each component,
matching every existing file in `features/chapters/*.spec.ts`,
`core/state.component.spec.ts`, `core/load-status.spec.ts` — this app's real,
only test convention for the frontend (no separate `tests/` tree exists under
`platform/frontend/src`).

**Target Platform**: Browser (the same Angular SPA), served from
`workshop/platform/frontend`; no new deployable, no new route required for
Phase 1 (toast/badge are composed into existing routed pages, not routed
pages themselves).

**Project Type**: Single-page web application — an addition to the existing
`workshop/platform/frontend` Angular project, not a new project.

**Performance Goals**: Not throughput-bound. The only quantified target
carried from the spec is motion-shaped: every entrance/exit animation and the
toast's count-up/count-down tween must honor `prefers-reduced-motion:
reduce` (FR-013) and GPU-only properties (`transform`/`opacity`) per the
research brief's §4 rule, inherited from
`design-toolkit/knowledge/motion.md:46-51`.

**Constraints**: Zero un-tokenized literal color/spacing/radius/duration
values (FR-010, SC-005); zero forked/duplicated `.lk-toast`/`.lk-badge` CSS
class families (FR-002); downgrade-kind events carry no danger/warning token
on any code path (FR-003); auto-dismiss pauses on hover or keyboard focus and
resumes only when both clear (FR-006); no `<app-achievement-toast>` /
`<app-achievement-badge>` renders while the learner's score/ability state is
`null`/loading (FR-012).

**Scale/Scope**: Phase 1 of this plan — User Story 1 only (toast + badge).
User Story 2 (modal) and User Story 3 (motion polish + independent QA gate)
are scoped by the spec but their detailed component contracts are deferred to
this plan's Phase 2/Phase 3 notes rather than fully specified now, consistent
with the spec's own phased `Why this priority` framing (each phase ships
independent value with zero dependency on the next).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

This feature is the clearest OpenDesign-anchor case in this umbrella so far —
it lands new, shipped UI components on top of the design system, not just
content. Five anchors were read verbatim from
`submodules/constitution/Constitution.md` (line numbers below) and checked
against real, measured project state, not against the anchors' own
descriptions.

| Anchor | Status | Real, specific finding |
|---|---|---|
| **§11.4.162** — OpenDesign UI design system mandate (`Constitution.md:9747`) | **PARTIAL, pre-existing, not worsened by this feature** | The literal clause ("OpenDesign… consumed as a project dependency… never vendored or forked") is not met anywhere in this app today — confirmed by `grep -rn "open-design\|opendesign\|@nexu" workshop/platform/frontend/package.json` returning zero matches. This app instead vendors a byte-identical, drift-checked CSS copy via `sync-brand-tokens.sh`/`sync-learning-kit.sh --check` (exit 0/1/2), a pre-existing, whole-module deviation this feature inherits rather than introduces (every `.lk-pill` use today already operates this way). What THIS feature does satisfy, concretely: the **"extend, never reimplement"** clause — `.lk-badge--achievement` and the toast-exit addition land upstream in `design-system/learning-kit/learning-kit.css` (FR-018) and are pulled down via the existing sync script, not forked into a workshop-local copy; and **"light+dark theme variants required"** — every proposed rule (data-model.md, contracts/) resolves exclusively through `var(--od-*)`/`var(--lk-*)` custom properties, which already flip under this app's real `[data-theme="dark"]`/`prefers-color-scheme` mechanism (`brand-tokens.css:131,146`), so no separate dark-mode ruleset is authored or needed. |
| **§11.4.216** — Canonical machine-readable design-token source (`Constitution.md:10692`) | **PASS** | `brand-tokens.css`/`kit-tokens.css` are the generated-binding copies of the canonical `design-system/` token file (§11.4.35's consuming-project instantiation), drift-checked live: `bash scripts/sync-learning-kit.sh --check` exits 0 today ("OK: vendored learning kit is byte-identical"). FR-010 commits every gamification style to `var(--od-accent)`, `var(--lk-radius-pill)`, `var(--lk-elev-2)`, `var(--od-dur-slow)`, `var(--od-ease-bounce)` — never a hand-restated hex. The one gap: `--od-ease-bounce` (`design-system/motion/overlays.css:24`) is **not yet vendored** into `brand-tokens.css`. Per §11.4.216 clause 2 ("generated bindings only… a hand-copied… token value anywhere… is a violation"), this plan vendors it through the SAME `sync-brand-tokens.sh` mechanism (extended to also copy the small motion-token subset from `design-system/motion/overlays.css`), never by hand-typing the cubic-bezier into a component's own `styles` array. |
| **§11.4.217** — OpenDesign brand contract: 9-section `DESIGN.md` + `tokens.css` twin, disjoint color roles, AA-pinned accents, locked attribution footer (`Constitution.md:10706`) | **PASS, pre-existing artifact, unmodified by this feature** | `design-system/brand-milosvasic/DESIGN.md` exists (confirmed: `# Brand — Milos Vasic (personal)` at line 1) and is the umbrella's own canonical brand contract this app's vendored tokens derive from; this feature adds no new brand color, no new accent pair, and does not touch `DESIGN.md` or its `tokens.css` twin — it consumes the existing, already-AA-pinned `--od-accent`/`--od-success`/`--wk-ok-edge` roles unchanged. FR-003/FR-016's downgrade-framing rule is a direct, concrete application of clause 3 ("semantic… is STATE and is NEVER overridden by a brand" — read here in its stricter, product-level form: a brand's accent must never be MISREAD as a semantic danger/warning signal either). No violation, no new contract obligation created. |
| **§11.4.218** — Living design-library catalogue: every component × state × theme rendered self-contained + cross-platform reusability matrix (`Constitution.md:10720`) | **NEEDS ATTENTION, pre-existing project-wide gap, honestly scoped, not fixed by this plan** | `design-system/preview/components.html` exists and DOES render `.od-toast--success/--warning/--danger/--info` (generic OpenDesign toast) and `.od-popover`, but grep confirms it contains **zero** references to `.lk-badge`, `.lk-toast` (the learning-kit variant this feature actually composes), or any dialog/modal component — i.e. no living catalogue entry exists today for ANY learning-kit component, gamification or otherwise, and no cross-platform reusability matrix file was found anywhere in `design-system/` or `design-toolkit/` (only unrelated `diagrams/catalogizer.*` files matched a "catalog" search). This is a whole-module, pre-existing §11.4.218 gap this feature does not create and does not attempt to close — closing it for the entire `learning-kit` component family is out of this plan's scope. What this plan DOES commit to, as the closest real gate available: FR-020/SC-009 require the finished component set to pass `design-toolkit/qa/design-qa-testbank.md`'s challenge skeleton (confirmed present at that path) under independent review before Phase 3 sign-off — a real, if narrower, verification gate. |
| **§11.4.221** — Motion discipline: token-bound durations/easings + machine-readable manifest + reduced-motion static fallbacks (`Constitution.md:10762`) | **PARTIAL, token-binding met; manifest clause is an honest gap** | Token-binding (clause 1) and `prefers-reduced-motion` targeting (clause 4) are directly, testably required by FR-013/FR-017/SC-008 and the prototype already demonstrates the pattern (`prefersReducedMotionLocalCopy()`, mirroring the real, tested `core/follow.ts:403-412` `prefersReducedMotion()` — which a production implementation MUST import instead of the inlined copy, per the prototype's own header comment). **No machine-readable motion manifest (clause 3: "a versioned motion manifest enumerates every animation with its id, loop mode, poster frame, reduced-motion mode, and fallback reference") exists anywhere in this project** — confirmed: no `motion-manifest*` file found under `design-system/` or `workshop/`. This is, again, a pre-existing, whole-project gap (nothing in this app's existing motion — not the toast's own current entrance keyframe, not `.lk-pill`'s transitions — is manifest-tracked either), not one this feature introduces or is positioned to close alone. Recorded here rather than silently assumed compliant. |

**Verdict**: proceed. Two PARTIAL rows (§11.4.162, §11.4.221) and one NEEDS
ATTENTION row (§11.4.218) are real, honestly-reported, **pre-existing**
conditions of this whole module that this feature inherits rather than
creates or worsens — the same posture spec 009's plan took for its own
Environment Adaptability NEEDS ATTENTION row. None blocks Phase 0 research;
none is silently asserted PASS. Re-check after Phase 1 design, specifically:
confirm the `--od-ease-bounce` vendoring lands through the sync mechanism
(not hand-typed) before any component ships using it.

**Release-blocker honesty check — the question above is "does this block
Phase 0 planning," and that is not the same question these anchors answer
about release.** §11.4.216, §11.4.217, §11.4.218 and §11.4.221 each close
with materially the same sentence, quoted verbatim rather than paraphrased:

> §11.4.216 (`Constitution.md:10704`): "Non-compliance is a release blocker
> regardless of context. No escape hatch — no `--hand-copied-palette-OK`,
> `--inline-hex-OK`, `--invent-token-value`, `--light-only-tokens`,
> `--platform-keeps-own-palette` flag exists."
>
> §11.4.217 (`Constitution.md:10718`): "Non-compliance is a release blocker
> regardless of context. No escape hatch — no `--skip-brand-contract`,
> `--prose-only-design-md`, `--brand-as-text-OK`, `--unvalidated-accent-override`,
> `--remove-attribution-footer`, `--semantic-tokens-brandable` flag exists."
>
> §11.4.218 (`Constitution.md:10732`): "Non-compliance is a release blocker
> regardless of context. No escape hatch — no `--cdn-in-catalogue`,
> `--single-theme-catalogue`, `--mocked-behaviors-OK`, `--unmarked-matrix-cell`,
> `--scaffold-claims-verified` flag exists."
>
> §11.4.221 (`Constitution.md:10774`): "Non-compliance is a release blocker
> regardless of context. No escape hatch — no `--ad-hoc-duration`,
> `--no-reduced-motion-fallback`, `--global-star-motion-kill`,
> `--manifest-optional`, `--unrendered-animation-claimed-working` flag exists."

None of these four anchors carries a "fine during planning, fix before
release" carve-out — the closing text is unconditional and names no phase.
Framing the table above around whether Phase 0 research is blocked answers a
narrower, easier question than the one these anchors actually pose, and this
paragraph exists so that gap is not left implicit.

The three flagged conditions — no `open-design`/`@nexu` npm dependency
anywhere in this app (§11.4.162 row above), no living-catalogue entry for ANY
learning-kit component under `design-system/preview/components.html` and no
cross-platform reusability matrix file anywhere in the design area
(§11.4.218), and no machine-readable motion manifest anywhere in the project
(§11.4.221) — are **PRE-EXISTING, WHOLE-MODULE conditions this feature
INHERITS, not conditions it introduces.** This feature's own new work does
not widen any of the three gaps: FR-018's upstream addition to
`design-system/learning-kit/learning-kit.css` (the `.lk-badge--achievement`
rule, its `.is-new` pulse keyframe, and the toast-exit keyframe) and every
other new style surface this plan specifies resolve exclusively through
`var(--od-*)`/`var(--lk-*)` custom properties (see the §11.4.216/§11.4.217
rows above) — no new hand-restated token value, no new undocumented
component, and no new un-manifested animation is added by this feature that
the pre-existing gaps did not already cover.

That does not make the exposure go away, and this plan does not claim it
does. §11.4.216/§11.4.217/§11.4.218/§11.4.221 are unconditional,
no-escape-hatch, release-blocking anchors for the WHOLE `learning-kit`
module — not only for whatever feature happens to touch it last — and the
module carries a **real, currently-unremediated release-blocking exposure**
on §11.4.218's living-catalogue clause and §11.4.221's motion-manifest clause
**independently of whether spec 014 ships**. Scoping this plan's own work
narrowly enough to avoid worsening those gaps is not the same act as closing
them, and this plan is not attempting to resolve them here or to hide them
by scoping around them. The correct disposition: (1) this plan proceeds,
because it demonstrably does not add to either gap; (2) the whole-module
§11.4.218 living-catalogue gap and the whole-module §11.4.221 motion-manifest
gap are real release-blocking risk for the module as a whole and MUST be
tracked as their own remediation item(s), independent of this or any other
single feature spec — not resolved by, and not something this plan is
positioned to resolve.

## Project Structure

### Documentation (this feature)

```text
specs/014-gamification-design-system/
├── plan.md              # This file
├── data-model.md         # Phase 1 output — Achievement Event / Toast / Badge shapes
├── contracts/
│   └── achievement-components.md   # Component API surface (inputs/outputs/signals)
├── quickstart.md         # Manual level-up / downgrade toast verification steps
└── tasks.md              # Phase 2 output — NOT created by this plan
```

### Source Code (repository root)

Real paths inside the already-existing `workshop/platform/frontend` Angular
project (read-only reference this session; no file below is created or
modified by this planning pass):

```text
workshop/platform/frontend/src/app/
├── core/
│   ├── achievement-toast-queue.ts        # NEW (Phase 1) — AchievementToastService: signal<AchievementToastData[]>
│   │                                      #   stack, push()/dismiss(id), cap-at-N (FR-007), same-kind coalescing
│   │                                      #   window (FR-008), harder adjusted-kind debounce (FR-009). Placed in
│   │                                      #   core/, not features/, matching this app's REAL, measured convention
│   │                                      #   that @Injectable stores live in core/ regardless of domain
│   │                                      #   specificity — see core/progress.ts (ProgressStore) and
│   │                                      #   core/practice-store.ts (PracticePosition), both domain-coupled
│   │                                      #   services that live in core/ precisely because this app's split is
│   │                                      #   "services in core/, routed/presentational components in features/",
│   │                                      #   not "domain-agnostic in core/, domain-coupled in features/".
│   └── follow.ts                         # UNCHANGED — real prefersReducedMotion(), imported (not re-inlined) by
│                                          #   the production toast/badge components, per the prototype's own
│                                          #   header instruction.
├── features/
│   └── gamification/                     # NEW (Phase 1) directory — see structure decision below
│       ├── achievement-badge.component.ts        # NEW — AchievementBadgeComponent
│       ├── achievement-badge.component.spec.ts    # NEW
│       ├── achievement-toast.component.ts         # NEW — AchievementToastComponent (real, wired, descended
│       │                                          #   from poc/achievement-toast.component.ts)
│       ├── achievement-toast.component.spec.ts     # NEW
│       ├── achievement-toast-region.component.ts   # NEW — AchievementToastRegionComponent, the single mount
│       │                                          #   point; renders `.lk-toast-region` + one
│       │                                          #   <app-achievement-toast> per queued item
│       ├── achievement-toast-region.component.spec.ts  # NEW
│       └── level-up-modal.component.ts             # Phase 2 — NOT built by this plan; contract deferred
├── app.component.ts                       # MODIFY (Phase 1) — mount <app-achievement-toast-region> once,
│                                           #   analogous position to the existing <router-outlet>/footer
│                                           #   composition already in the shell template
└── features/chapters/chapter-list.component.ts  # MODIFY (Phase 1, or a later task) — compose
                                                  #   <app-achievement-badge> into the existing `.facts` `.lk-pill`
                                                  #   row, the same inline-composition pattern already used for
                                                  #   `durationOf`/transcript pills at lines ~108-131

design-system/
├── learning-kit/learning-kit.css          # MODIFY (upstream, FR-018) — add `.lk-badge--achievement` (+ `.is-new`
│                                           #   pulse keyframe) and a toast-exit keyframe (currently absent — the
│                                           #   research brief's §4 table notes `.lk-toast` has entrance-only
│                                           #   animation today).
└── motion/overlays.css                    # UNCHANGED (source) — `--od-ease-bounce` (line 24) is read from here
                                            #   by the vendoring script; the rule itself is never forked.

workshop/platform/frontend/
├── src/styles/brand/brand-tokens.css       # MODIFY (Phase 1) — vendor `--od-ease-bounce` via the sync script,
│                                            #   never hand-typed (§11.4.216 Constitution Check row).
└── scripts/sync-brand-tokens.sh            # MODIFY (Phase 1) — extend to also copy the small motion-token
                                             #   subset it is currently missing, keeping the SAME `--check`
                                             #   three-valued-exit discipline (0/1/2) this script already has.
```

**Structure Decision — `features/gamification/` for components, `core/` for
the queue service, checked against this codebase's real pattern rather than
assumed:**

`core/state.component.ts` (the named reference point in the task) is a real
precedent for a *shared, cross-composed presentational component*, but it is
the wrong precedent for gamification's **components**: `state.component.ts`
carries zero business-domain semantics — it renders a `LoadStatus<T>`
vocabulary (`idle`/`loading`/`ready`/`empty`/`absent`/`unavailable`) that
applies identically to any data-fetching surface in the app, which is exactly
*why* it lives in `core/` alongside `rail.component.ts`, `status.component.ts`,
`code-block.component.ts` — all genuinely domain-agnostic. Gamification's
badge/toast/modal are the opposite: `AchievementKind`
(`level-up`/`chapter-complete`/`adjusted`) and the downgrade-framing
constraint (FR-003) are specific to the adaptive-scoring domain, the same way
`features/progress/progress.component.ts` is specific to the reading-position
domain rather than living in `core/` despite ALSO being composed broadly
(routed from the shell nav). **The real split this codebase draws is by
routed/presentational-vs-domain, not by "reused in many places vs. reused in
one."** So the presentational components land in a new `features/gamification/`
directory, sibling to `features/progress/`.

The **queue service** (`AchievementToastService`) is the opposite case: this
app's `@Injectable` stores — `core/progress.ts` (`ProgressStore`),
`core/practice-store.ts` (`PracticeStore`) — are BOTH domain-coupled (reading
position, practice-deck position) and BOTH live in `core/`, not inside their
matching `features/progress/`/`features/practice/` directories. That is this
app's real, measured convention for where an `@Injectable` service belongs,
independent of domain-specificity, so `AchievementToastService` follows it
into `core/achievement-toast-queue.ts` rather than `features/gamification/`.

## Complexity Tracking

*No unjustified Constitution Check violations — the three PARTIAL/NEEDS
ATTENTION rows above are pre-existing, whole-module conditions this feature
inherits and honestly reports rather than newly introduces, so no
justification-for-a-violation entry is warranted here.*
