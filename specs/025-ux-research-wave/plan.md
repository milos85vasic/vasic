# Implementation Plan: UX Research Wave

**Branch**: `025-ux-research-wave` | **Date**: 2026-10-20 | **Spec**: [spec.md](./spec.md)

## Summary

Frontend-only wave on the Angular app in the private `workshop` submodule. US1 (P1) puts the existing
backend stream on screen as honest stages. US2-US5 (P2) are the cheap wins: confidence before reveal,
motion/contrast/view-transition policy with `content-visibility`, Media Session, durable links. US6-US8
(P3) are the larger interaction items: palette, peek, rail relevance. Everything else in the research
round is recorded as deferred/out with reasons (spec table). No backend change, no new dependency,
every story behind a default-OFF runtime flag until its live acceptance passes.

## Technical Context

**Language/Version**: TypeScript 5.x / Angular 19.2 standalone, signals, OnPush (`package.json`);
Playwright 1.62 + `@axe-core/playwright` 4.13; Karma ChromeHeadless for unit. Shell/Node for the motion gate.
**Dependencies**: none new (SC-008). Backend contract consumed read-only.
**Storage**: none (session memory; localStorage only for per-viewer flags/shortcut preference, wrapped
in try/catch).
**Testing**: Karma specs, Playwright e2e (desktop + mobile chromium) against a RUNNING stack (config has
no `webServer`; worktree streams point `WORKSHOP_BASE_URL` at a scratch server, architecture §2.2 rule 6),
paired-mutation provers under `platform/gates/` and `frontend/scripts/`.
**Target**: modern evergreen browsers; WCAG 2.1 AA + tracked 2.2 findings; 390 px to desktop.
**Performance**: no regression budget invented before the baseline; D3 sets targets after T005.
**Constraints**: new code in new files; hooks only in `inquiry.component.ts`, `transcript.component.ts`,
`practice.component.ts`, `recording-player.component.ts`, `rail.component.ts`, `app.config.ts`,
`styles.scss`, `app.component.ts`; `core/vocabulary.ts` and `app.routes.ts` are orchestrator-owned.

## Constitution check

| Anchor | Application |
|---|---|
| §11.4.224/245 | RED task before every implementation task, oracle named (WHATWG SSE examples, recorded real streams, WCAG 1.4.13/2.1.4 clauses, performance baseline JSON) |
| §11.4.240/249 | test author != implementer != reviewer; reducer expectations hand-derived from raw frames |
| §11.4.230 | vertical stories, each independently shippable, latent behind `ux-flags` (D.2); US1 first |
| §11.4.142/209 | `[REVIEW]` per story, Opus xhigh |
| §11.4.257/258/65/168 | manual/guide/FAQ + four diagrams + exports + independent validation |
| §11.4.262/266 | machine evidence (result.json + sha256 manifest) per story; ledger rows for each advertised UX capability |
| §11.4.221 (cited by spec 014 plan) | motion policy document + gate (US3) |
| §11.4.6 | UNCONFIRMED markers; baselines measured before targets |
| §11.4.40/151 | one full-suite retest before any tag |

## Project structure (all NEW unless marked hook)

```text
workshop/platform/frontend/src/app/
  core/{sse-parser,ask-stages,ask-stream,confidence-store,ux-flags,moment-link,palette-commands,
        palette-model,peek-model,rail-relevance,media-session}.ts (+specs)
  features/inquiry/{answer-stages.component.ts, draft-preview.component.ts}           (+specs)  hook: inquiry.component.ts
  features/practice/confidence-prompt.component.ts, calibration-note.component.ts      (+specs)  hook: practice.component.ts
  features/transcript/copy-link.component.ts                                           (+specs)  hook: transcript.component.ts
  features/palette/{palette.component.ts,palette.routes? none (global overlay)}        (+specs)  hook: app.component.ts
  features/peek/peek.directive.ts, peek-popup.component.ts                             (+specs)  hooks: cite/crossrefs/inquiry templates
  features/*/<x>-vocabulary.ts                                                         orchestrator merges into core/vocabulary.ts
  app.config.ts (hook: withViewTransitions), styles.scss (hook: motion/contrast blocks)
workshop/platform/frontend/e2e/{ask-stream,practice-confidence,comfort-motion,media-session,moment-links,palette,peek,rail-relevance}.spec.ts
workshop/platform/frontend/e2e/perf/transcript-baseline.spec.ts
workshop/platform/frontend/scripts/check-motion-policy.mjs ; workshop/platform/gates/prove-motion-policy-mutation.sh
workshop/platform/frontend/testdata/streams/*.sse   (recorded real streams, private)
workshop/docs/design-system/motion-policy.md ; workshop/docs/guides/{ask-stages,practice-confidence,moment-links,palette,peek}-guide.md
workshop/evidence/025-ux-research-wave/**
```

## Order and parallelism

1. Setup + Foundational (flags, SSE parser, baselines) - serial, small.
2. US1 alone first (the cheap, highest-value item; own stream). In parallel only the baseline tasks.
3. Then US2 || US3 || US4 || US5 (disjoint files: practice, global CSS/config/transcript rows,
   recording-player, transcript copy-link) - four streams; US3 and US5 both touch the transcript
   component: US3 only through CSS on rows (`transcript.component.ts` style block hook) and US5 through
   one template tag - serialised by the orchestrator, US5 after US3.
4. Then US6, US7, US8 (P3), one stream each; US7 and US8 touch cite/crossrefs/rail - disjoint.
5. Orchestrator: hooks, flag flips, restarts, live evidence, gitlink bump + `helix-deps.yaml` in one change.

## Shared-file protocol

Same rules as spec 024 and architecture §2: hook lines recorded in
`workshop/evidence/025-ux-research-wave/hook-lines.md`; spec 024's banner tag in `inquiry.component.ts`
lands AFTER this spec's US1 change (the stage panel restructures that template region).

## Risks

1. Streams unobservable on the live stack until spec 024 enables answering: mitigated by scratch
   verification and an explicit operator note.
2. `content-visibility` anchor regressions: measured, conditional (FR-011).
3. Palette shortcut and keyboard-trap a11y: dedicated keyboard-only journey.
4. Hot-spot component edits: single-tag hooks only; any larger change needs the orchestrator.
5. Webkit not testable locally: recorded limitation; no webkit-only claims made.

## Complexity tracking

None. Deliberate non-actions: no EventSource, no new dependency, no backend event fields, no MMR, no
client-side corpus.
