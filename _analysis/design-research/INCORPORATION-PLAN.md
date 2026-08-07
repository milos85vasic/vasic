# Incorporation Plan — Design Toolkit around OpenDesign

**Date:** 2026-08-06 · **Companion to:** `CATALOG.md` (the verified inventory) · **Builds on:** `OPENDESIGN-ADOPTION-PLAN.md`, `design-research.md`, `design-system/` (already built), `submodules/constitution` (staged).

**Goal:** turn the catalog into a concrete plan for a reusable **design toolkit** — nested under the HelixConstitution submodule where it belongs, wired into `vasic` and reusable across all future projects — that combines with OpenDesign to produce **unique, enterprise-grade, non-repeatable UI/UX across every platform, OS, and app type**.

**Decision rule used throughout:** does the thing produce *artifacts we vendor* (code/tokens/knowledge that must be version-pinned and license-clean) → **git submodule**; is it a *tool an agent calls at runtime* (no vendored code, works over stdio) → **MCP install**; is it *knowledge an agent should reason with* → **encoded skill** (distilled rules, not copied prose).

---

## 0. Guardrails this plan must honor (from governance + existing state)

1. **§11.4.162 — OpenDesign is the token source of truth.** No raw hex/px/rem literals, no hand-authored CSS custom properties or inline styles in site stylesheets. **Consequence for this plan:** the parametric-uniqueness layer (Category 4) does NOT hand-write `var(--*)`. It generates a **DTCG token document** that OpenDesign consumes/emits, OR — where OpenDesign cannot yet emit a construct — it is an **upstream PR to OpenDesign (§11.4.74)**, never a local escape hatch. Style Dictionary is used only as the emitter *inside/behind* OpenDesign's contract, not as a parallel token system.
2. **§11.4.170 / §11.4.168 — every surface proven by host-rendered pixels + PDF validation.** New tools (Chrome DevTools MCP, Playwright MCP, Image-Compare MCP) feed this harness (`anti-bluff-web-harness`), they don't bypass it.
3. **Container-only pipelines** (per `project-translation-pipeline` / HelixTranslate). The token-generator and any image-gen run in a container, keys from `~/api_keys.sh`, never in repo/config.
4. **Reduced-motion / GPU-only / cross-browser progressive-enhancement** (from `design-research.md`) remain hard constraints on anything the design agents emit.
5. **License hygiene (§ anti-bluff):** only vendor MIT/Apache/BSD. GPL tools stay as *external MCP processes* (not vendored source). No-license items are **not** incorporated until relicensed/cleared.

---

## 1. Proposed repository structure

A single toolkit repo, nested as a submodule of HelixConstitution (mirrors the existing "decouple then nest under constitution" plan in `project-vasic-monorepo`), so every Helix project inherits it:

```
HelixConstitution/
└── design-toolkit/                      # NEW submodule (this plan's deliverable)
    ├── README.md
    ├── skills/                          # Claude skills (vendored, Apache/MIT only)
    │   ├── _vendor/                     # nested submodules of upstream skill repos (pinned)
    │   │   ├── anthropics-skills/       # submodule → anthropics/skills (Apache-2.0)
    │   │   ├── designer-skills/         # submodule → Owl-Listener/designer-skills (MIT)
    │   │   ├── ui-ux-pro-max/           # submodule → nextlevelbuilder/ui-ux-pro-max-skill (MIT)
    │   │   ├── jezweb-skills/           # submodule → jezweb/claude-skills (MIT)
    │   │   └── anydesign/               # submodule → uxKero/anydesign (MIT)
    │   └── recipes/                     # OUR design-specialist agent recipes (§4) — the value-add
    │       ├── theming-designer/
    │       ├── layout-architect/
    │       ├── animation-designer/
    │       ├── iconographer/
    │       ├── ux-flow-designer/
    │       └── design-qa-auditor/
    ├── knowledge/                       # distilled, vendorable references (§3 encode) — rules not prose
    │   ├── a11y/         (WCAG 2.2 gate + WAI-ARIA APG patterns)
    │   ├── platforms/   (HIG rules-only checklist, Material 3, Fluent 2, GNOME)
    │   ├── color/        (OKLCH model, WCAG contrast gate, Radix/Open Color scales)
    │   ├── type/         (Utopia fluid formulas, variable-font axes, MD3 scale roles)
    │   ├── layout/       (Every Layout primitives, container-query method, 8pt grid)
    │   └── motion/       (MD3 motion tokens, easings.net table, reduced-motion gate)
    ├── generators/                      # the parametric uniqueness layer (§5)
    │   ├── package.json                 # deps: material-color-utilities, colorjs.io, chroma-js,
    │   │                                #        utopia-core, style-dictionary, @svgdotjs/svg.js
    │   ├── design-dna.mjs               # seed → parameter vector
    │   ├── gen-tokens.mjs               # vector → DTCG token doc (→ OpenDesign consumes/emits)
    │   ├── gen-marks.mjs                # seed → build-time static SVG marks/backgrounds (svg.js)
    │   └── lib/_vendor/                 # OPTIONAL submodules if we want source-pinned instead of npm
    ├── mcp/
    │   └── mcp.design.json              # ready-to-merge MCP server definitions (§2)
    └── docs/
        └── DESIGN-TOOLKIT.md            # how OpenDesign + generators + skills + MCP combine
```

Then, exactly as the existing decoupled-libs plan does: `HelixConstitution` is a submodule of `vasic`, so `vasic` gets `design-toolkit/` transitively. Sites consume only the **emitted OpenDesign tokens** — never reach into `generators/` at runtime.

---

## 2. What becomes an MCP install (runtime tools — NOT vendored)

Add via `claude mcp add` (project scope for `vasic`, or a shipped `mcp.design.json` teams merge). None require a paid subscription. GPL/no-license items are kept out entirely; the ones below are all local + permissive.

| MCP server | Command | License | Role in the toolkit |
|-----------|---------|---------|--------------------|
| **Chrome DevTools MCP** | `claude mcp add chrome-devtools --scope user npx chrome-devtools-mcp@latest` | Apache-2.0 | Design QA: Lighthouse a11y/perf, screenshots → feeds §11.4.170 proof (already a plugin here) |
| **Playwright MCP** | `claude mcp add playwright npx @playwright/mcp@latest` | Apache-2.0 | Screenshot / visual-regression backbone for the proof harness |
| **shadcn MCP** (official) | `npx shadcn@latest mcp init --client claude` | MIT | Component discovery/reuse before building custom |
| **shadcn-ui-mcp-server** (Jpisnice) | `claude mcp add shadcn -- npx -y @jpisnice/shadcn-ui-mcp-server` | MIT | Multi-framework (React/Vue/Svelte/RN) component source |
| **Framelink Figma MCP** | `claude mcp add framelink-figma -- npx -y figma-developer-mcp --figma-api-key=$FIGMA_PAT --stdio` | MIT | Design *ingestion* from Figma (free PAT) when a project starts from Figma |
| **draw.io MCP** (lgazo) | `npx -y drawio-mcp-server --editor` | MIT | Architecture/diagram authoring (case-study spine in design-research.md) |
| **Mermaid MCP** (peng-shawn) | `claude mcp add mermaid -- npx -y @peng-shawn/mermaid-mcp-server` | MIT | Agent Mermaid → rendered PNG/SVG diagram assets |
| **google-fonts-mcp** | `claude mcp add google-fonts -- uvx google-fonts-mcp` | MIT | Font pairing → CSS/Tailwind type systems (feeds theming-designer) |
| **sharp-mcp** | `npx -y sharp-mcp` | MIT | Local AVIF/WebP/resize (the responsive-image work in design-research.md §5) |

**Pilot-then-standardize (low stars — evaluate before committing):** `x51xxx/coolors-mcp` (MD3/OKLCH color ops), `kenneives/design-token-bridge-mcp` (DTCG→Material3/SwiftUI/CSS), `leky90/mcp-image-compare-server` (visual diff — but Playwright's `toHaveScreenshot` is the safer default).

**Explicitly NOT installed:** Official Figma Dev Mode MCP (paid seat), 21st.dev Magic MCP (paid/keyed), LottieFiles Creator MCP (hosted account). Iconify MCPs are GPL/no-license → prefer the **iconographer skill + local Iconify data** over an MCP (see §4).

---

## 3. What becomes a vendored submodule (pinned source we ship)

**3a. Skill repos** (nested submodules under `design-toolkit/skills/_vendor/`, pinned to a reviewed SHA):
- `anthropics/skills` (Apache-2.0) — take `frontend-design`, `theme-factory`, `web-artifacts-builder`, `brand-guidelines`, `canvas-design`, `algorithmic-art`. **Foundation.**
- `Owl-Listener/designer-skills` (MIT) — vendor the *subset* that complements OpenDesign (design-research, ux-strategy, visual-critique); skip anything duplicating our recipes.
- `nextlevelbuilder/ui-ux-pro-max-skill` (MIT) — for cross-platform stack coverage (Compose/Flutter/SwiftUI/WinUI/Avalonia). Use as a *reference the recipes cite*, gated by OpenDesign tokens so it doesn't drift generic.
- `jezweb/claude-skills` (MIT) — `frontend` + `design-assets` (palette/favicon/icon/image).
- `uxKero/anydesign` (MIT) — design→token extraction (ingestion counterpart to OpenDesign).

**3b. Generator libraries** (npm deps by default; optionally source-pinned submodules under `generators/lib/_vendor/`): `material-color-utilities` (Apache-2.0), `colorjs.io` (MIT), `chroma-js` (BSD-3), `style-dictionary` (Apache-2.0), `@svgdotjs/svg.js` (MIT), `utopia-core` (**confirm LICENSE first** — sibling is MIT). Optional: `@adobe/leonardo-contrast-colors` (Apache-2.0) for contrast-driven theme modes.

**3c. Knowledge** (`design-toolkit/knowledge/` — *distilled rules we author*, citing sources; we do NOT copy copyrighted prose): encode WCAG 2.2 + WAI-ARIA APG (open), Material 3 (open, richest), DTCG spec (open), easings.net table (MIT), Radix/Open Color scales (MIT); paraphrase Apple HIG / Fluent 2 / Atomic Design / Every Layout primitives into checklists. Each file: source URL, license note, and the machine-usable rules.

---

## 4. Design-specialist agent recipes (the toolkit's core value-add)

Each recipe = a skill (`SKILL.md` + supporting refs) defining what the specialist **knows** (which vendored knowledge/skills it draws on), **the tools it uses** (which MCP servers), **what it does** (procedure), and **how it respects the guardrails**. All emit through OpenDesign; none hand-author tokens.

### 4.1 `theming-designer` — the uniqueness engine
- **Knows:** color science (`knowledge/color/` — OKLCH model, WCAG contrast gate, Radix/Open Color), Material 3 color roles, the parametric method (Category 4), font-pairing→personality matrix, DTCG.
- **Uses:** `generators/` (material-color-utilities + colorjs.io/chroma-js + utopia-core → Style Dictionary → OpenDesign), `google-fonts-mcp`, `coolors-mcp` (pilot).
- **Does:** takes a project **design-DNA seed + brand adjectives** → picks `{seedHue, mcuVariant, typeRatio, spaceMultiplier, radiusBase, fontPairId, contrastMode}` from bounded ranges (constrained selection, justified — per the CPT research finding) → generates a full accessible token set → hands DTCG to OpenDesign to emit → verifies WCAG contrast on every semantic pair. **This is what makes each project distinct-but-on-brand and reproducible.**
- **Guardrail:** never writes `var(--*)` into site CSS; if OpenDesign can't emit a needed construct → upstream PR.

### 4.2 `layout-architect`
- **Knows:** Every Layout primitives (Stack/Cluster/Sidebar/Switcher/Cover/Grid — concepts), container-query-first responsiveness, 8pt grid, Apple HIG platform-adaptation rules (safe areas, ≥44pt targets, native nav), Material 3 layout regions.
- **Uses:** `shadcn` MCPs (component reuse), Chrome DevTools MCP (responsive checks at real viewports).
- **Does:** designs page/screen structure from composable primitives + container queries (not viewport-only breakpoints); applies per-platform adaptation checklist for cross-platform nativeness; expresses breakpoints/regions as OpenDesign layout tokens.
- **Guardrail:** progressive-enhancement base must render without JS; verify by rendering+clicking at phone/tablet/desktop (the lesson already learned in `project-design-state`).

### 4.3 `animation-designer`
- **Knows:** MD3 motion tokens, easings.net table, Disney principles (CC-BY-SA summary), the GPU-only / reduced-motion / deterministic-end-state rules from `design-research.md`.
- **Uses:** Chrome DevTools MCP (perf trace / smoothness), Playwright MCP (force deterministic end-state for golden capture).
- **Does:** specifies micro-interactions and scroll/view-transition motion as tokenized CSS/SVG (drop Lottie for simple motion); animates only `transform/opacity/compositor-safe filter`; every motion gated on `prefers-reduced-motion: no-preference`; provides the reduced-motion capture variant for §11.4.170.
- **Guardrail:** CI greps emitted CSS to fail on animated `width/height/top/left/box-shadow`.

### 4.4 `iconographer`
- **Knows:** icon-system theory (stroke/weight/grid consistency, optical sizing), the self-hosted sprite approach already in `design-system/icons/icons.svg`.
- **Uses:** local **Iconify data** + `jezweb design-assets` skill for SVG icon sets (prefer this over the GPL/no-license icon MCPs); `sharp-mcp`/SVGO for optimization.
- **Does:** selects/uses a consistent icon set per project personality, generates a self-hosted subset sprite (no remote requests, no CLS), colors from tokens, ensures a11y labels.
- **Guardrail:** no remote icon CDNs (matches the self-hosted-fonts/no-Google-Fonts discipline already enforced).

### 4.5 `ux-flow-designer`
- **Knows:** UX-strategy frameworks (from `designer-skills` + the *concepts* of `awesome-ux-skills`, once its license is cleared), the case-study spine (Problem→Approach→Architecture→Outcome→Artifact) and trust/proof devices from `design-research.md`, WAI-ARIA APG interaction models.
- **Uses:** `draw.io`/`Mermaid` MCP (flow + architecture diagrams), Framelink Figma MCP (ingest existing flows), `anydesign` skill (extract structure from references).
- **Does:** designs information architecture, navigation, and page/flow templates; produces the repeatable portfolio/product spine; specifies keyboard-interaction patterns per APG.
- **Guardrail:** every interactive element gets a real behavior + a11y semantics (the "behavior not href" lesson from `interactive-behavior.spec.js`).

### 4.6 `design-qa-auditor`
- **Knows:** WCAG 2.2 success criteria as a hard gate, §11.4.170/.168 proof requirements, CWV thresholds.
- **Uses:** Chrome DevTools MCP (Lighthouse a11y/perf), Playwright MCP + Image-Compare (visual regression), the existing `anti-bluff-web-harness`.
- **Does:** audits each `screen × state × {light,dark}` by rendered pixels + a11y + contrast + CWV; fails the build on regressions; produces the evidence bundle.
- **Guardrail:** verify by rendering+clicking at real viewports, not structural/heuristic checks (institutionalized lesson).

**Shared substrate:** all recipes read `design-toolkit/knowledge/` and defer token authority to OpenDesign. `anthropics/skills:frontend-design` + `theme-factory` are the aesthetic/theming base the recipes build on; `ui-ux-pro-max` supplies cross-platform stack specifics on demand.

---

## 5. The parametric uniqueness layer + OpenDesign — how they combine

**Pipeline (all container-only, keys from `~/api_keys.sh`):**

```
project seed (= hash(project-name+domain) or chosen brand hue)
        │  design-dna.mjs
        ▼
parameter vector {seedHue, mcuVariant, typeRatio, spaceMultiplier, radiusBase, fontPairId, contrastMode}
        │  gen-tokens.mjs
        ├─ material-color-utilities → HCT tonal palettes + role-mapped light/dark scheme (variant = personality)
        ├─ colorjs.io / chroma-js  → custom OKLCH harmony ramps, gamut-safe P3 (+ sRGB fallback)
        ├─ utopia-core             → fluid type/space clamp() scales from ratio + multiplier
        └─ radius + density tokens
        ▼
   DTCG token document  ──►  OpenDesign (consumes/emits)  ──►  tokens.css / per-platform output
        │                         (§11.4.162 source of truth; Style Dictionary sits behind it)
        ▼
   sites/PDFs consume ONLY the emitted OpenDesign tokens
        +
gen-marks.mjs (svg.js, seeded RNG, BUILD TIME) → static per-project SVG marks/backgrounds/dividers (colors from tokens)
```

**Why this yields uniqueness without chaos:** OpenDesign owns *structure and semantics* (component set, token names, light/dark, a11y); the generator supplies *values* from a different point in the parameter space per project; the seeded SVG layer adds a *visual signature*. Two Vasic projects can share the exact component library and still read as unmistakably different brands — and re-running the same seed reproduces the same design exactly (deterministic). This is the Material-3-dynamic-color pattern (proven, Apache-2.0) generalized to type/space/shape/marks.

**§11.4.162 reconciliation (critical):** the generator's output is a **DTCG document fed into OpenDesign**, not hand-written CSS. If OpenDesign cannot yet ingest generator-produced tokens or emit a construct (e.g. `light-dark()`, a specific `clamp()` shape), that gap is an **upstream OpenDesign PR (§11.4.74)** — the generator never writes `var(--*)` or literals into a site stylesheet. Confirm during Phase A that OpenDesign's token-ingestion contract accepts an external DTCG doc; if not, that's the first upstream PR.

---

## 6. Sequenced rollout (small, verifiable increments)

- **Phase A — Scaffold + prove the pipeline (vertical slice).** Create `design-toolkit/` skeleton; add the 2 highest-value MCP installs (Chrome DevTools already present; add Playwright, shadcn). Build `generators/` with material-color-utilities + colorjs.io + utopia-core + Style Dictionary; produce ONE token set from a seed and prove OpenDesign can emit it (or file the upstream PR). Confirm `utopia-core` LICENSE before pinning. Verify with §11.4.170 render of the existing button slice under a generated theme.
- **Phase B — Vendor the skill foundation.** Nest `anthropics/skills` + `Owl-Listener/designer-skills` as pinned submodules; author the `theming-designer` and `design-qa-auditor` recipes (the two with immediate leverage). Wire `google-fonts-mcp`, `sharp-mcp`.
- **Phase C — Cross-platform + remaining recipes.** Add `ui-ux-pro-max` + `jezweb` + `anydesign` submodules; author `layout-architect`, `animation-designer`, `iconographer`, `ux-flow-designer`. Add draw.io/Mermaid/Framelink MCPs. Encode the `knowledge/` reference set.
- **Phase D — Generative marks + distinctness proof.** Add `gen-marks.mjs` (svg.js) build-time signature layer; generate a *distinct* theme+mark set for `milosvasic.ru` vs `vasic.digital` from different seeds and prove via §11.4.170 that they render as different brands on the shared component library.
- **Phase E — Nest under HelixConstitution + wire into vasic.** Move `design-toolkit/` under the `constitution` submodule, wire back into `vasic` (mirrors the held "nest decoupled libs under constitution" step); gate CI on `design-qa-auditor`.

**Blocked/held dependencies (from existing state):** nesting under HelixConstitution is entangled with the un-pushed §11.4.236 amendment + umbrella push (held for user GO in `project-design-state`/`project-vasic-monorepo`). Phases A–D can proceed in-tree under `_analysis`/`design-system` without that GO; Phase E waits on it.

---

## 7. Honesty summary (what NOT to rely on)

- **No single OSS "brand-in-a-box"** does color+type+space+shape+marks end-to-end — §5 assembly is our work (well-scoped, all deps MIT/Apache/BSD).
- **Low-star MCPs** (coolors, design-token-bridge, image-compare) must be **piloted** before standardizing; don't gate CI on them until proven.
- **License blockers to clear before vendoring:** `utopia-core` (confirm), `awesome-ux-skills`/awesome-list indexes/`mcp-universal-icons`/several color+icon MCPs (no license — do not vendor). Iconify MCPs are GPL → keep external or use local Iconify data via the iconographer skill instead.
- **Paid/excluded, do not add:** Official Figma Dev Mode MCP, 21st.dev Magic MCP, LottieFiles Creator MCP, Refactoring UI, Every Layout (buy for reference; encode concepts only), APCA as an authoritative gate (advisory only — enforce WCAG 2.2 ratios).
- **Copyrighted knowledge** (Apple HIG, Fluent 2, Atomic Design): encode paraphrased rules, never vendor the prose.
