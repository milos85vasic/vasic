# Motion & Interactive-Widget Functional Audit

Generated: 2026-08-05T18:40:42.137Z

Read-only. Both already-generated static sites were served locally and driven with real
browser automation (Playwright: chromium + firefox + webkit). No site source was edited and
the Go generator was not run. Every verdict below is backed by a live DOM measurement and, for
state-changing interactions, a before/after screenshot pair under `screenshots/`.

- milosvasic.ru served from `milosvasic.ru/_site/` (port 8482)
- vasic.digital served from `vasic.digital/` (port 8481)
- Pages per site: landing (`/`), a product page, the portfolio page.

## Functional matrix (widget x site x page — chromium deep run)

| Interaction | Site | landing | product | portfolio |
|---|---|---|---|---|
| Scroll-reveal | milosvasic.ru | WORKS | WORKS | WORKS |
| Scroll-reveal | vasic.digital | WORKS | WORKS | WORKS |
| Sticky header | milosvasic.ru | WORKS | WORKS | WORKS |
| Sticky header | vasic.digital | WORKS | WORKS | WORKS |
| Accordion/disclosure | milosvasic.ru | absent | absent | absent |
| Accordion/disclosure | vasic.digital | absent | absent | absent |
| Theme toggle | milosvasic.ru | WORKS | WORKS | WORKS |
| Theme toggle | vasic.digital | WORKS | WORKS | WORKS |
| Language switcher | milosvasic.ru | WORKS | WORKS | WORKS |
| Language switcher | vasic.digital | absent | absent | absent |
| Dialog/modal | milosvasic.ru | WORKS | absent | absent |
| Dialog/modal | vasic.digital | absent | absent | absent |
| Lottie | milosvasic.ru | absent | absent | absent |
| Lottie | vasic.digital | absent | absent | absent |
| Bounce/blink/highlight | milosvasic.ru | absent | absent | absent |
| Bounce/blink/highlight | vasic.digital | absent | absent | absent |

## Theme toggle — switch + persistence (chromium)

| Site | page | button id | before | after | bg changed | persists on reload |
|---|---|---|---|---|---|---|
| milosvasic.ru | landing | `#theme-btn` | light | dark | yes | yes |
| milosvasic.ru | product | `#theme-btn` | light | dark | yes | yes |
| milosvasic.ru | portfolio | `#theme-btn` | light | dark | yes | yes |
| vasic.digital | landing | `#od-theme-toggle` | null | dark | yes | yes |
| vasic.digital | product | `#od-theme-toggle` | null | dark | yes | yes |
| vasic.digital | portfolio | `#pf-theme-toggle` | null | dark | yes | yes |

> Note: vasic.digital uses button id `#od-theme-toggle` on landing/product but `#pf-theme-toggle`
> on portfolio (each with its own inline handler). Both function; the id is merely inconsistent.

## Scroll-reveal — before/after state change (chromium)

| Site | page | below-fold reveal targets | before transform/opacity | after transform/opacity | verdict |
|---|---|---|---|---|---|
| milosvasic.ru | landing | 9 | matrix(1, 0, 0, 1, 0, 16) / 1 | matrix(1, 0, 0, 1, 0, 0) / 1 | WORKS |
| milosvasic.ru | product | 0 | matrix(1, 0, 0, 1, 0, 0) / 1 | matrix(1, 0, 0, 1, 0, 0) / 1 | WORKS |
| milosvasic.ru | portfolio | 6 | matrix(1, 0, 0, 1, 0, 16) / 1 | matrix(1, 0, 0, 1, 0, 0) / 1 | WORKS |
| vasic.digital | landing | 14 | matrix(1, 0, 0, 1, 0, 16) / 1 | matrix(1, 0, 0, 1, 0, 0) / 1 | WORKS |
| vasic.digital | product | 0 | matrix(1, 0, 0, 1, 0, 1.16044e-07) / 1 | matrix(1, 0, 0, 1, 0, 0) / 1 | WORKS |
| vasic.digital | portfolio | 6 | matrix(1, 0, 0, 1, 0, 16) / 1 | matrix(1, 0, 0, 1, 0, 0) / 1 | WORKS |

- Note (milosvasic.ru / product): only reveal target sits above the fold; revealed at load (is-visible set) — no scroll delta to capture.

## Language switcher (chromium, landing)

- **milosvasic.ru**: WORKS — 15 languages listed; aria-expanded false -> true; Escape closes: true; opens via keyboard (Enter): true.
- **vasic.digital**: absent — site has no language switcher control (lang-like elements found: 0).

## Dialog / modal + backdrop (chromium, landing)

- **milosvasic.ru**: WORKS — opens on trigger click (opacity 1), backdrop backdrop-filter: `blur(4px)`; Escape closes: true.
- **vasic.digital**: absent — no reachable modal trigger on landing.

## Long-task / jank summary (chromium, scripted full-page scroll)

PerformanceObserver `longtask` entries recorded while scripting a full scroll through each page.
A task > 50ms blocks the main thread noticeably; > 200ms is a jank concern.

| Site | page | longtask API | count | max ms | total ms | tasks>50ms |
|---|---|---|---|---|---|---|
| milosvasic.ru | landing | yes | 0 | 0 | 0 | 0 |
| milosvasic.ru | product | yes | 0 | 0 | 0 | 0 |
| milosvasic.ru | portfolio | yes | 0 | 0 | 0 | 0 |
| vasic.digital | landing | yes | 0 | 0 | 0 | 0 |
| vasic.digital | product | yes | 0 | 0 | 0 | 0 |
| vasic.digital | portfolio | yes | 0 | 0 | 0 | 0 |

## Reduced-motion re-render (prefers-reduced-motion: reduce)

Each page re-loaded under emulated reduced-motion. PASS = reveal content is in its final state
immediately (no scroll needed) and CSS transitions are neutralised.

| Site | page | browser | reveal shown immediately | transitions neutralised |
|---|---|---|---|---|
| milosvasic.ru | landing | chromium | PASS | PASS |
| milosvasic.ru | product | chromium | PASS | PASS |
| milosvasic.ru | portfolio | chromium | PASS | PASS |
| milosvasic.ru | landing | firefox | PASS | PASS |
| milosvasic.ru | landing | webkit | PASS | PASS |
| vasic.digital | landing | chromium | PASS | PASS |
| vasic.digital | product | chromium | PASS | PASS |
| vasic.digital | portfolio | chromium | PASS | PASS |
| vasic.digital | landing | firefox | PASS | PASS |
| vasic.digital | landing | webkit | PASS | PASS |

## Cross-browser sanity (landing — key interactions)

| Site | interaction | chromium | firefox | webkit |
|---|---|---|---|---|
| milosvasic.ru | Theme toggle | WORKS | WORKS | WORKS |
| milosvasic.ru | Scroll-reveal | WORKS | WORKS | WORKS |
| milosvasic.ru | Language switcher | WORKS | WORKS | WORKS |
| vasic.digital | Theme toggle | WORKS | WORKS | WORKS |
| vasic.digital | Scroll-reveal | WORKS | WORKS | WORKS |
| vasic.digital | Language switcher | absent | absent | absent |

## Broken or absent interactions (page + selector)

- [ABSENT] milosvasic.ru — landing — Accordion/disclosure — selector `.od-accordion__trigger` — no .od-accordion elements on page
- [ABSENT] milosvasic.ru — landing — Lottie — selector `.od-lottie[data-src]` — no .od-lottie hosts — motion.js Lottie path never engages on this page
- [ABSENT] milosvasic.ru — landing — Bounce/blink/highlight — selector `.od-bounce / .od-blink / .od-highlight`
- [ABSENT] milosvasic.ru — product — Accordion/disclosure — selector `.od-accordion__trigger` — no .od-accordion elements on page
- [ABSENT] milosvasic.ru — product — Dialog/modal — selector `[data-dl] -> #dl-modal`
- [ABSENT] milosvasic.ru — product — Lottie — selector `.od-lottie[data-src]` — no .od-lottie hosts — motion.js Lottie path never engages on this page
- [ABSENT] milosvasic.ru — product — Bounce/blink/highlight — selector `.od-bounce / .od-blink / .od-highlight`
- [ABSENT] milosvasic.ru — portfolio — Accordion/disclosure — selector `.od-accordion__trigger` — no .od-accordion elements on page
- [ABSENT] milosvasic.ru — portfolio — Dialog/modal — selector `[data-dl] -> #dl-modal`
- [ABSENT] milosvasic.ru — portfolio — Lottie — selector `.od-lottie[data-src]` — no .od-lottie hosts — motion.js Lottie path never engages on this page
- [ABSENT] milosvasic.ru — portfolio — Bounce/blink/highlight — selector `.od-bounce / .od-blink / .od-highlight`
- [ABSENT] vasic.digital — landing — Accordion/disclosure — selector `.od-accordion__trigger` — no .od-accordion elements on page
- [ABSENT] vasic.digital — landing — Language switcher — selector `#lang-btn / #lang-menu` — site has no language switcher control
- [ABSENT] vasic.digital — landing — Dialog/modal — selector `[data-dl] -> #dl-modal`
- [ABSENT] vasic.digital — landing — Lottie — selector `.od-lottie[data-src]` — no .od-lottie hosts — motion.js Lottie path never engages on this page
- [ABSENT] vasic.digital — landing — Bounce/blink/highlight — selector `.od-bounce / .od-blink / .od-highlight`
- [ABSENT] vasic.digital — product — Accordion/disclosure — selector `.od-accordion__trigger` — no .od-accordion elements on page
- [ABSENT] vasic.digital — product — Language switcher — selector `#lang-btn / #lang-menu` — site has no language switcher control
- [ABSENT] vasic.digital — product — Dialog/modal — selector `[data-dl] -> #dl-modal`
- [ABSENT] vasic.digital — product — Lottie — selector `.od-lottie[data-src]` — no .od-lottie hosts — motion.js Lottie path never engages on this page
- [ABSENT] vasic.digital — product — Bounce/blink/highlight — selector `.od-bounce / .od-blink / .od-highlight`
- [ABSENT] vasic.digital — portfolio — Accordion/disclosure — selector `.od-accordion__trigger` — no .od-accordion elements on page
- [ABSENT] vasic.digital — portfolio — Language switcher — selector `#lang-btn / #lang-menu` — site has no language switcher control
- [ABSENT] vasic.digital — portfolio — Dialog/modal — selector `[data-dl] -> #dl-modal`
- [ABSENT] vasic.digital — portfolio — Lottie — selector `.od-lottie[data-src]` — no .od-lottie hosts — motion.js Lottie path never engages on this page
- [ABSENT] vasic.digital — portfolio — Bounce/blink/highlight — selector `.od-bounce / .od-blink / .od-highlight`

> "Absent" means the effect the brief asked about does not exist on that page (nothing to break),
> not that it failed. See the matrix for the works/broken/absent split.