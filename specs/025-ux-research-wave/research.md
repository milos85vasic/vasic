# Research: UX Research Wave

**Feature**: [spec.md](./spec.md) | Date 2026-10-20. Sources: the platform code (cited), the gap analysis
of 2026-10-20, and the private research document `workshop/docs/research/ux-research-2026-09-01.md`
(paraphrased by id; its external citations are NOT re-verified here - UNCONFIRMED until the baseline
task T004 re-checks browser support, which the document itself says is dated).

## R1. Prioritisation: cost/benefit with the platform facts

Scoring is ordinal, my judgement from the document's own cost labels and the platform state; no
numeric ROI is claimed.

| Rank | Item | Benefit | Cost | Risk | Notes |
|---|---|---|---|---|---|
| 1 | P1 staged stream | very high (largest defect) | XS-S: backend done, one reader + one component | live observation needs answering ON (spec 024) | doc: tolerance 9 s -> 22.6 s with progress; labour illusion; TTFT |
| 2 | P2 confidence before reveal | high (learning) | XS UI; persistence deferred | collides with practice submit path (013/016) | retrofit cost rising |
| 3 | P12 motion policy | medium | XS | low | global CSS; existing e2e proves final-state preservation |
| 4 | P11 Media Session | low-medium | XS | very low | feature-detected |
| 5 | P13 view transitions | low-medium | XS-S | medium: must exclude transcript load and ask | feature-detected |
| 6 | P4 content-visibility | medium on long pages | XS | medium: anchors/find-in-page | measure, revert if worse |
| 7 | P5 copy-link | medium | S | low | builds on existing anchors |
| 8 | P7 palette | medium-high reach | M | medium: shortcut conflicts, a11y | after the cheap items |
| 9 | P6 peek | medium | S-M | medium: 1.4.13 correctness | |
| 10 | P9 rail relevance | medium | S-M | low | extends tested component |
| - | P8, P10, P14, P15, P16, offline | see spec table | M+ or contradictory | privacy/contradiction | deferred or rejected with reasons |

## R2. Why `fetch` + `ReadableStream`, not `EventSource`

Auth is a bearer token attached by `core/auth-interceptor.ts` to every `/api/*` request; `EventSource`
cannot set request headers. Alternatives rejected: token in query string (leaks into logs/history and
the server middleware reads the header), cookie auth (a different auth model than the app has).
`fetch` streaming is supported by the Chromium/Firefox/WebKit builds Playwright uses here
(UNCONFIRMED for the webkit build the umbrella carrier says cannot launch on this host: the
preflight blocks webkit, so webkit is not part of local gates).

## R3. What the backend stream actually carries (so the UI does not promise more)

From `pkg/answer/http.go:370-525` and `provider.go:120-137`: `phase` events (queued, retrieving,
generating, verifying, done), `progress` events (token counters + `note`, plus a 10-second heartbeat),
`token` events only with `tokens=1` (always `verified:false`; text is held back across events by the
suppression filter), terminal `result`, and `withheld` when the suppression filter cannot check an
event. There is NO "N candidates scored" or per-claim citation event. The document's richest stage
wording therefore needs backend events that do not exist; this spec stays within the real events and
shows the server's `note` text instead (research doc risk 1: "every emitted stage must be a real
transition").

## R4. Draft preview is a product-honesty question, not a technical one

Verification (L3/L4/L5) only runs on a COMPLETE answer (`http.go:376-383`), so streamed text can be
refused entirely. Showing it risks a learner reading a fabrication the pipeline then declines. Hence
default OFF, permanent label, removal on refusal (D1). The measured fabrications (spec 024 baseline)
are the concrete reason for caution.

## R5. Motion policy facts

`src/styles.scss:232-238` zeroes durations (`.01ms !important`), so final states are preserved
(`e2e/reduced-motion.spec.ts`) but nothing is substituted; the research argues for substitution
(opacity retained). `prefers-contrast` and `prefers-reduced-transparency` have no hits in `src`.
`app.config.ts:12` configures `withInMemoryScrolling` only. Motion tokens exist (`kit-tokens.css`
lines cited in the gap analysis). Spec 014 covers gamification motion only (its plan cites
§11.4.221) and is 0 of 34 done; this spec's policy is global and written so 014 can reference it.

## R6. `content-visibility:auto` risks

Known interaction hazards (must be tested, not assumed): in-page anchor scroll to a skipped row,
browser find-in-page, `scrollIntoView` for the follow mode (`core/follow.ts`, spec 008), and
intrinsic-size estimation causing scroll-bar jumps. Therefore FR-011 makes the change conditional on
the measurement and the anchor tests, and records a revert path.

## R7. Why P15 (client-side corpus) is rejected and offline deferred

The platform's passages can be withheld or suppressed after the fact (`/passage/:pid` 410 branch;
suppression filter in the stream path). A full client copy cannot be recalled. A design that carries
the suppression generation and refuses stale copies would be a spec of its own. Offline caching has
the same property for the device cache.

## R8. MMR

Out, per the operator brief and spec 017 `research.md` §0 (library MMR measured non-deterministic and
score-corrupting; `pkg/crossref` declines it; diversity is bounded structurally). A self-written MMR
over stored embeddings does not contradict the cited defect but is unspecced; it waits for spec 026.

## R9. Reuse inventory (§11.4.74)

`LoadStatus`/`httpToLoadStatus`/`ready`/`loadUnavailable` (`core/load-status.ts`, `core/api.ts`),
`normaliseAnswer`, `UnavailableComponent`, `app-state`, `FollowMachine` (`core/follow.ts:190`), rail
component, `CiteComponent`, `CrossrefsComponent`, e2e helpers in `platform/frontend/e2e`. No new npm
dependency; `@angular/cdk` absent (D6).

## R10. UNCONFIRMED register

* Transcript row count and DOM weight of the largest real chapter (T005 measures).
* Whether the transcript pane scrolls internally (U32) and the 24x24 target size (U35) - T006.
* Webkit behaviour (not runnable on this host).
* Whether a `withheld` event can be provoked on demand in a scratch server (T003 tries; otherwise the
  fixture is synthetic and labelled so).
* Real-world stream proxy buffering in the deployment path (the compose stack serves directly; no
  proxy is documented in this tree).
