# Free Design-Capability Tooling — Decision-Ready Research (v1.7.1)

**Date:** 2026-08-08 · RESEARCH & REPORT ONLY (nothing integrated). All license/version
facts re-verified live via npm registry + GitHub REST API on 2026-08-08. Only genuinely
FREE / OSS tooling is recommended; paywalled/hosted-gated/no-license items are excluded.

Builds on what already exists: `design-toolkit/` (11 agent recipes, generators with
material-color-utilities + style-dictionary deps, QA test-bank), `_tools/od/od-mcp-call.mjs`
(OpenDesign daemon client), `_tools/audit-hardcoding.sh`. So the question is *which free
tools to wire in first* — a "prioritized subset" call.

## Top-3 recommendation (prioritized subset, ~4–5 days total)

**#1 — Verification backbone: Chrome DevTools MCP + Playwright MCP** (Apache-2.0, v1.6.0 / v0.0.79, fully local; Chrome DevTools MCP already a plugin here).
The only bundle that *proves* a design output is correct (Lighthouse a11y/perf, screenshots, visual-regression) — feeds HelixQA + §11.4.170 anti-bluff. Effort: **Low**. Pass `--no-performance-crux --no-usage-statistics` for no-egress.

**#2 — Deterministic token engine: material-color-utilities + Style Dictionary (+ colorjs.io / culori / utopia-core)** (Apache-2.0 / MIT / ISC; already deps in design-toolkit/generators).
The unique-per-project machine: seed → HCT palette + variant → OKLCH ramps → fluid type/space → DTCG → **OpenDesign** → per-platform via Style Dictionary (which sits *behind* OpenDesign's contract, never beside it — §11.4.162). Effort: **Med** — bump Style Dictionary v4→**5.5.1** (major), material-color-utilities 0.3→**0.4.0**, colorjs.io→**0.7.1**, utopia-core→**1.6.0**; finalize DTCG hand-off.

**#3 — Aesthetic + component layer: anthropics/skills `frontend-design` & `theme-factory` + shadcn MCP** (Apache-2.0 skills, per-skill LICENSE confirmed; shadcn MCP MIT v4.16.2).
Distinctive non-templated aesthetic + font/color theming reasoning + license-clean component reuse. Effort: **Low–Med**. Must consume OpenDesign tokens, never emit raw hex/px (audit-hardcoding guards this).

## Excluded (NOT free / unsafe to vendor)
- **Official Figma Dev Mode MCP** — paid Dev/Full seat (free tier ~6 calls/mo) → use **figma-developer-mcp / Framelink** (MIT, free PAT).
- **21st.dev Magic MCP** (paid key), **LottieFiles Creator MCP** (hosted account), **GSAP** (non-OSS → use `motion` MIT).
- **storybook-mcp** (AGPL), **Vivliostyle** (AGPL → Paged.js MIT), GPL iconify servers (→ **better-icons** MIT), no-LICENSE repos (all-rights-reserved).
- **Every Layout ($69) / Refactoring UI** — paid books; encode concepts only.

## No-bluff license findings (surfaced this pass, not in existing CATALOG)
- ⚠️ **`apca-w3` (0.1.9) ships a "Limited W3 License" (NOT OSI-approved)** — restricted redistribution. Treat APCA as *advisory*; compute production contrast via colorjs.io/culori + WCAG 2.x. Review `design-toolkit/qa/lib/apca.mjs` against this.
- `chroma-js` is dual `(BSD-3-Clause AND Apache-2.0)` (both permissive).
- Chrome DevTools MCP + @antv/mcp-server-chart egress by default (opt-out flags exist).

## Agent-recipe + HelixQA outline
Reuse the 11 `design-toolkit/agents/` recipes: orchestrator derives a seed→param vector (design-dna),
fans out theming → (layout ∥ components ∥ icons ∥ motion ∥ ux ∥ brand) in parallel, then a single
serial **design-qa-auditor** gate (Chrome DevTools + Playwright MCP) must pass. HelixQA bank Challenges:
(1) token integrity / OpenDesign contract, (2) uniqueness+determinism (Delta-E/CAM16 via qa/lib),
(3) WCAG 2.2 a11y, (4) platform conformance (M3/Fluent/HIG envelopes), (5) visual regression
(Playwright toHaveScreenshot), (6) perf budget, (7) **license gate** (fail on GPL/AGPL/no-license/
"Limited W3"). Golden-bad fixtures must FAIL the bank (anti-bluff).

*(Full comparison tables + verification method are in the agent transcript / this session record.)*
