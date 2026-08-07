# Design-Toolkit Scaffold — Evidence Manifest

**Generated:** 2026-08-06 · **Deliverable:** FIRST INCREMENT of the design-capability toolkit,
built from `_analysis/design-research/CATALOG.md` + `INCORPORATION-PLAN.md`, as **local files**
(no remote repos, no git submodules added, no git commit/push). Non-generator work only — `_tools/gen/`,
`_content*`, and the sites are untouched.

See [`file-inventory.txt`](file-inventory.txt) for per-file sha256 + sizes.

---

## 1. File tree produced

```
design-toolkit/                         (21 files, 7 dirs, ~109 KB)
├── README.md                           what it is · OpenDesign combination · uniqueness philosophy · load out-of-the-box
├── agents/                             6 design-specialist agent recipes (frontmatter: name/description/tools + system prompt)
│   ├── theming-designer.md             the parametric uniqueness engine (seed → design-DNA vector → DTCG tokens)
│   ├── layout-architect.md
│   ├── animation-designer.md
│   ├── iconographer.md
│   ├── ux-flow-designer.md
│   └── design-qa-auditor.md
├── mcp/INSTALL.md                      exact `claude mcp add` commands + license notes + EXCLUDED paid/no-license list
├── submodules/PLAN.md                  `git submodule add` commands + HelixConstitution nesting + NEXT-checkpoint commands
├── knowledge/                          distilled, cited, open-licensed design cheat-sheets
│   ├── README.md                       index + sourcing/license discipline
│   ├── a11y-wcag22.md                  WCAG 2.2 gate (thresholds, new-in-2.2 criteria, auditor checklist)
│   ├── aria-apg.md                     keyboard + ARIA models per widget
│   ├── color.md                        OKLCH/HCT model, seed→scheme, semantic roles, WCAG contrast gate, scales
│   ├── typography.md                   Utopia fluid clamp(), type ratios, variable-font axes, MD3 roles
│   ├── layout.md                       primitives, container queries, 4/8pt grid, cross-platform checklists
│   ├── motion.md                       MD3 duration/easing tokens, reduced-motion gate, GPU-only rule
│   ├── material3.md                    color roles, tonal palette, variants, type/shape scales, adaptive layout
│   └── dtcg-tokens.md                  DTCG document shape the generator emits
├── qa/design-qa-testbank.md           HelixQA-style Challenge SKELETON (D1–D7, matrix, golden-good/bad, evidence schema, gates)
└── docs/
    ├── USER-GUIDE.md                   task-oriented: design any material/app with the agents
    └── MANUAL.md                       reference: every part, design-DNA model, all platforms/formats, roadmap
```

All 7 required deliverables present: (1) README, (2) 6 agents, (3) mcp/INSTALL.md, (4) submodules/PLAN.md,
(5) knowledge/, (6) qa/, (7) docs/USER-GUIDE.md + docs/MANUAL.md.

---

## 2. Fidelity to the research (traceability)

| Research item | Where it landed | Faithful? |
|---------------|-----------------|-----------|
| 6 agent recipes (§4 of plan) | `agents/*.md` — exact 6 names, each with knows/uses/does/guardrail | ✅ |
| Parametric uniqueness pipeline (§5) | `theming-designer.md` + `docs/MANUAL.md` §3 + `knowledge/dtcg-tokens.md` | ✅ |
| MCP install set (§2 table) | `mcp/INSTALL.md` — all 9 core/ingestion + 3 pilots + exclusions | ✅ |
| Vendored submodules (§3) | `submodules/PLAN.md` — libs §A, color scales §B, skills §C | ✅ |
| Knowledge to encode (Category 3) | `knowledge/` — 8 sheets, open-licensed only, sources cited | ✅ |
| §11.4.162 OpenDesign source-of-truth | enforced in README, every agent, MANUAL §3, dtcg-tokens | ✅ |
| Anti-bluff / §11.4.170 proof | `design-qa-auditor` + `qa/design-qa-testbank.md` | ✅ |

---

## 3. License verification performed this build

- **utopia-core → ISC** — CONFIRMED (npm registry `registry.npmjs.org/utopia-core/latest` +
  `package.json`, 2026-08-06). Resolves the research's "verify LICENSE before vendoring" flag.
  Recorded in `submodules/PLAN.md` §A and `README.md` §6.
- All other vendored items retain the CATALOG.md-verified licenses (MIT/Apache-2.0/BSD).
- **Excluded, faithfully carried forward:** Official Figma Dev Mode MCP (paid), 21st.dev Magic MCP
  (paid/keyed), LottieFiles Creator MCP (hosted), GPL/no-license icon+color MCPs, no-license skill
  repos, Every Layout/Refactoring UI (paid — concepts only), APCA as a gate (advisory only).

---

## 4. Scope compliance (what was NOT touched)

- ❌ No remote GitHub/GitLab repos created (explicitly the next checkpoint).
- ❌ No git submodules added (commands documented in `submodules/PLAN.md`, not run).
- ❌ No `git commit` / `git push`.
- ❌ No changes to `_tools/gen/`, `_content*`, `milosvasic.ru`, or `vasic.digital`.
- ✅ New files only under `design-toolkit/` and `_tests/evidence/design-toolkit/`.

---

## 5. Explicitly deferred to the NEXT checkpoint

1. Remote repo creation under `vasic-digital` on **GitHub + GitLab** (`gh repo create` / `glab repo
   create`) — exact commands in `submodules/PLAN.md` §"Next checkpoint".
2. Adding the vendored submodules (§A–§C) pinned to reviewed SHAs.
3. Nesting `design-toolkit/` under the `HelixConstitution` submodule and bumping the pointer in `vasic`.
4. Standing up `generators/` as runnable code (design-dna.mjs / gen-tokens.mjs / gen-marks.mjs) and
   proving OpenDesign ingests the generated DTCG (or filing the upstream PR).
5. Turning `qa/design-qa-testbank.md` into an executable suite + wiring the CM gates.

All held pending user GO (entangled with the un-pushed §11.4.236 amendment + umbrella push).
