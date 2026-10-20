# Quickstart: UX Research Wave

**Feature**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)

Run from `workshop/platform/frontend` unless noted. Worktree streams use a SCRATCH server with answering
ON (extractive for speed, ollama for realistic phases); only the orchestrator touches the live stack.

## Scenario 1 - Staged answer (US1)

```bash
# scratch server (see specs/024 quickstart / gates/answer-eval/README.md), then:
WORKSHOP_BASE_URL=http://127.0.0.1:$PORT npx playwright test e2e/ask-stream.spec.ts --project=desktop-chromium
npm run test:unit -- --include='**/ask-*.spec.ts' --include='**/sse-parser.spec.ts'
```
Expect: stage list shows only server-reported phases with server elapsed times; collapses on result.

## Scenario 2 - Confidence before reveal (US2)

`npx playwright test e2e/practice-confidence.spec.ts`: select an option, observe reveal is blocked until a
confidence is chosen; high-confidence-wrong wording is neutral.

## Scenario 3 - Comfort & motion (US3)

```bash
npx playwright test e2e/perf/transcript-baseline.spec.ts   # writes evidence JSON (before/after)
npx playwright test e2e/comfort-motion.spec.ts             # emulates reduced-motion, contrast, transparency
node scripts/check-motion-policy.mjs                       # rc 0 clean tree
```

## Scenario 4 - Media Session (US4), 5 - Moment links (US5), 6 - Palette (US6), 7 - Peek (US7), 8 - Rail (US8)

Each has `e2e/<story>.spec.ts`; run with the same pattern. Palette: press Ctrl+K, type, Enter.

## Operator acceptance (UI-visible)

IMPORTANT: the staged answer only appears where answering is ON. On the live stack as deployed
(answering OFF) `/ask` shows the honest "not configured" state; the operator sees the staged answer on
the scratch/QA server (URL provided by the orchestrator) or on the live stack once spec 024 has
cleared and enabled a configuration.

1. `/ask` (answering ON): ask a question. Watch stage names appear one at a time with seconds next to
   each, then collapse into a one-line summary you can expand. Nothing appears that the server did not
   say. Try a question the corpus cannot answer: you see the decline with its reason.
2. Turn on a screen reader or inspect the live region: one polite announcement per stage.
3. `/practice/<area>`: choose an option; the explanation stays hidden until you pick Low/Medium/High
   confidence; skip the text box and continue.
4. Toggle your OS "reduce motion": the page still changes state with a brief fade, no sliding.
5. Open a long transcript: scrolling is smooth; open a shared `?t=` link and land on the right row; use
   "Copy link" and open the copy in a private window.
6. Play a recording and check the OS media controls show the title and chapter (browsers that support it).
7. Press Ctrl/Cmd+K: palette opens; Escape closes and returns focus.
8. Hover or tab onto a citation chip: a preview appears; Escape dismisses it.
9. Search for a term on a chapter page: the rail shows where the term is answered; clear the query and
   the original uncertainty layer returns.
Each flag is OFF by default; the orchestrator flips `core/ux-flags.ts` defaults after you sign off.
