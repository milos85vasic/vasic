# OpenDesign Adoption Plan — All Design Governed by OpenDesign

- **Status:** DRAFT for review (2026-08-05)
- **Author:** Milos Vasic + Claude Code
- **Scope:** Both sites (`milosvasic.ru`, `vasic.digital`), all documents, all PDFs, and a **fully-automatic multi-page Portfolio** (web section on both sites + downloadable PDF) — every user-facing surface.
- **Supersedes (in part):** `_analysis/DESIGN-SPEC.md` (2026-06-17), which predates the OpenDesign mandate and prescribes a bespoke CSS‑custom‑property token system now forbidden by §11.4.162. This plan reconciles it.
- **Mandate:** "make sure all design is handled and done by OpenDesign."

---

## 1. Governing mandates (the anchors)

Every decision here traces to a Helix Constitution mandate (`/Volumes/T7/Projects/constitution/Constitution.md`). This plan is the operationalization of existing law, not new policy.

| Mandate | What it requires here |
|---|---|
| **§11.4.162 — OpenDesign UI design system** | OpenDesign (github.com/nexu-io/open-design) is THE design-and-token system, consumed **as a dependency (npm/equivalent), never vendored/forked**. ALL color palettes (light+dark, from brand assets), typography scale + spacing, and component tokens (radius/shadow/hover/active/focus/animation) are defined in OpenDesign — **never in CSS custom properties or inline styles**. Extend upstream, never reimplement. Both light+dark variants mandatory. Layout-regression prohibition. Gate `CM-OPENDESIGN-UI-SYSTEM`. **No escape hatch.** |
| **§11.4.170 — Host-side rendered-UI visual proof** | Every UI surface proven by **device-independent host-rendered pixels** per `screen × state × {light,dark}`, dual oracle: (i) golden image-diff + (ii) OCR/vision layout oracle (legibility, no overlap/clip/off-screen/giant-unbounded widget). **Value/token-equality tests FORBIDDEN as proof.** Self-validated analyzer (golden-good/golden-bad). Runs every commit, zero hardware. Gate `CM-HOST-RENDERED-UI-VISUAL-PROOF`. |
| **§11.4.168 — Exported-document validation** | Every exported HTML/PDF/DOCX independently validated (validator ≠ generator) across CONTENT + TEXTUAL (no raw markup/diagram source leaking) + FULL-VISUAL (`pdftotext` + `pdfimages` + `pdftoppm`→OCR) layers. Self-validated golden-good/golden-bad. Gate `CM-EXPORTED-DOC-VISUALLY-VALIDATED`. |
| **§11.4.73 — project-wide MD/HTML/PDF/DOCX styling** | The constitution ships `styles/default-md.css` (7 KB) + `styles/default-pdf.css` (3.5 KB, A4 print). Doc/PDF styling composes OpenDesign tokens on top of these. |
| **§11.4.161 — Rootless containers** | ALL containerized work (incl. the HelixTranslate pipeline + any visual-proof containers) must run **Podman rootless**; Docker-rootful/`sudo` FORBIDDEN. Orchestrated via the `vasic-digital/containers` submodule (§11.4.76). Bites `start.sh` (`sudo`) and the `amber.local` docker host. |
| **§11.4.107 / §11.4.35 / §11.4.74** | WCAG color contrast still verified independently; brand assets + concrete token instantiation supplied per project; missing OpenDesign capability is extended upstream via PR. |
| **§11.4.169** | Visual-proof tests are part of the mandatory closed test-type set; challenges + helix_qa submodules apply. |

> **§11.4.6 (no-guessing) honesty flags** appear inline as `[UNCONFIRMED — verify in Phase 0]`. Nothing below is asserted as fact where it hasn't been verified on disk.

---

## 2. Guiding principles

1. **Single source of design truth.** One OpenDesign workspace defines every token. No `#a31e39`/`#dc3545`, no `10px`, no `2rem` literal ever appears in a site stylesheet again — only `var(--od-*)` (or the SCSS bridge) resolved from OpenDesign's compiled output.
2. **Extend, never reimplement (§11.4.74).** Missing component/token/target → upstream PR to OpenDesign, not local CSS.
3. **Light + dark are non-negotiable, both from brand assets.** Every component ships both.
4. **Pixels are the proof, tokens are the wiring.** §11.4.170 forbids "the token equals X" as UI proof; the rendered PNG + OCR is the proof.
5. **Docs and PDFs are UI too.** The CV, cover letter, README, and all exports are governed by the same design system (DESIGN.md → tokens → styled export) and validated by §11.4.168.
6. **Anti-bluff throughout.** Every analyzer self-validates with a golden-good/golden-bad pair and a paired §1.1 mutation; no silent skips.

---

## 3. Target architecture — design-system topology

```
OpenDesign workspace (source of truth, driven via `od` CLI + MCP in Claude Code + desktop app)
│
├── foundation/                      # shared, brand-neutral
│   ├── DESIGN.md                    # brand-grade spec (portable contract)
│   ├── tokens: typography scale, spacing, radius, shadow, motion, z-index, breakpoints
│   └── component tokens: button, card, dialog/modal, input, nav, table, badge/chip
│
├── brand-milosvasic/                # personal brand theme
│   ├── palette light+dark  (crimson #a31e39 family, from assets/images/milosvasic*.png)
│   └── typography binding: Space Grotesk / Inter / JetBrains Mono
│
└── brand-vasic-digital/             # company brand theme
    ├── palette light+dark  (red #dc3545 family, from Assets/Logo.*)
    └── typography binding: Inter (+ display/mono TBD)

        │ compiles to portable artifacts per brand:
        ▼
   dist/<brand>/{tokens.css, DESIGN.md, manifest.json, component fixtures}
        │
        ├── milosvasic.ru  (Jekyll)     → imports tokens.css into assets/css/style.scss; @use tokens only
        ├── vasic.digital  (static)     → <link> dist/brand-vasic-digital/tokens.css; JS/HTML use token classes
        └── docs+PDFs                    → DESIGN.md + tokens.css + constitution styles/default-*.css
                                           → pandoc → themed HTML → weasyprint → PDF  (§11.4.168 validated)
```

**Decision to confirm (§9-A): brand model.** Recommended = **one shared foundation + two brand theme packages** (above). This gives "one design system governs everything" (§11.4.162) while preserving the two distinct brands (personal crimson vs company red). Alternative = two fully independent OpenDesign packages (more duplication) or one merged brand (loses brand distinction).

**Consumption mechanics `[UNCONFIRMED — verify in Phase 0]`:** whether `od` CLI / the OpenDesign daemon is already installed on this machine; the exact schema of OpenDesign's emitted `tokens.css` and whether it exposes SCSS-consumable variables for the Jekyll `@use` path; whether its PDF/deck export or its `tokens.css` is the right feed for the weasyprint doc pipeline. Phase 0 resolves each with captured evidence before any migration.

---

## 4. Phased roadmap

Each phase lists **Deliverables → Evidence (anti-bluff) → Gate**. Phases are sequential where dependent; within a phase, both sites proceed in parallel.

### Phase 0 — Preflight & bootstrap (foundations, no site changes yet)
- **Wire the constitution as a submodule** of the `vasic` umbrella (`submodules/constitution` or `constitution/`) so `find_constitution.sh` resolves and the gates actually apply here (today it governs by reference only, NOT checked out).
- **Install OpenDesign** and wire it into Claude Code: `od mcp install claude`; stand up the local daemon (rootless per §11.4.161). Capture version + `od` command inventory.
- **Adopt the `vasic-digital/containers` submodule** as the sole rootless orchestration layer; migrate the HelixTranslate hosts off Docker-rootful/`sudo` (fixes `start.sh` `sudo`, `amber.local` docker) `[UNCONFIRMED — confirm amber.local can run Podman rootless]`.
- **Inventory brand assets (§11.4.35):** canonical logos/colors for each brand; document extracted palettes (light+dark) with contrast pre-check (§11.4.107).
- **Verify OpenDesign token/output schema** and pick the concrete consumption path for (a) Jekyll SCSS, (b) static-site CSS, (c) pandoc/weasyprint PDFs. Capture a spike PoC that imports a trivial OpenDesign token into each of the three targets.
- **Evidence:** `docs/qa/<run-id>/` capture of `od` version, MCP registration, a rendered token in all three targets, extracted palette + contrast report.
- **Gate:** OpenDesign installed as dependency + reachable; constitution submodule resolves via `find_constitution.sh`; three-target PoC renders.

### Phase 1 — Define the design system in OpenDesign
- Author the **foundation** (typography scale, spacing, radius, shadow, motion, z-index, breakpoints) + **two brand themes** (light+dark palettes from Phase-0 assets).
- Define **component tokens** for the full set both sites use: button, card, dialog/**modal** (unifying milosvasic.ru's two divergent modals + vasic.digital's `articles.css` modal), input, nav, table, chip/badge, footer.
- Produce **DESIGN.md** per brand (the portable brand-grade contract) + compiled `tokens.css` + component fixtures.
- **Evidence:** OpenDesign-rendered component fixtures per `state × {light,dark}` for both brands, captured as PNGs; contrast report per token pair (§11.4.107).
- **Gate:** every planned component has tokens in OpenDesign, both themes, contrast ≥ AA; `CM-OPENDESIGN-UI-SYSTEM` provisionally green on the fixtures.

### Phase 2 — Migrate `milosvasic.ru` (Jekyll) to OpenDesign
- Replace the bespoke token block in `assets/css/style.scss:9-41` with an `@use`/import of `dist/brand-milosvasic/tokens.css`; delete every color/space/type literal in favor of tokens.
- Rebuild components off tokens; **unify the two modal idioms** (`.mv-article-modal` vs `.dl-modal`) onto the single OpenDesign modal; keep the real WCAG features (skip link, focus-visible, reduced-motion, focus-trap).
- **Self-host fonts** via OpenDesign typography tokens (removes remote Google Fonts); wire `<picture>`+WebP (variants already exist, unused).
- Preserve the no-FOUC `data-theme` bootstrap; both themes now token-driven.
- **Evidence:** §11.4.170 host-rendered pixels for every changed screen×state×{light,dark}; before/after token-diff (§11.4.162 regression tool).
- **Gate:** `CM-OPENDESIGN-UI-SYSTEM` + `CM-HOST-RENDERED-UI-VISUAL-PROOF` green; zero non-token color/space literals remain (lint).

### Phase 3 — Migrate `vasic.digital` (static) to OpenDesign
- Replace `css/style.css` flat tokens (color/shadow only, ~20% coverage) + all magic numbers with `dist/brand-vasic-digital/tokens.css`; retire dead `css/logo.css`; fold `css/articles.css` onto the OpenDesign modal.
- Keep glassmorphism/micro-interactions but express them as OpenDesign component/motion tokens.
- **Fix the i18n coupling** so it stops fighting the design system: migrate the brittle positional `language-switcher.js` (`navLinks[0]`, `serviceCards[i]`) to `data-i18n` attributes (also fixes the 6-of-9 service-card and portfolio-coverage bugs, and the stale-stats drift). *(This is design-adjacent cleanup that Phase 3 unblocks; can be split into its own task.)*
- **Evidence:** §11.4.170 rendered pixels per screen×state×{light,dark}; token-diff; i18n completeness now testable.
- **Gate:** same two gates green; both sites now share one design system (single brand-red source, no divergence).

### Phase 4 — Docs & PDFs onto OpenDesign
- **Consolidate the three CV-PDF generations** (`downloads/`, `assets/pdf/`, `pages/` + root `README.pdf`) to a **single Markdown source per doc per language**, one pipeline: DESIGN.md + `tokens.css` + constitution `styles/default-pdf.css` → pandoc → themed HTML → weasyprint → PDF. Retire the duplicates.
- Bring README / any exported HTML/DOCX under the same OpenDesign + `styles/default-md.css` styling.
- Extend the CV/Cover-Letter language coverage to match the site language set (currently only EN/SR/RU vs 15 UI langs).
- **Evidence:** §11.4.168 three-layer validation on EVERY exported artifact (`pdftotext_body.txt` clean, `pdfimages_manifest.txt` present, `ocr_pages/` legible), validator independent of generator, self-validated golden-good/golden-bad.
- **Gate:** `CM-EXPORTED-DOC-VISUALLY-VALIDATED` green on all PDFs/exports.

### Phase 5 — Visual-proof + export-validation test harness
- Build the **§11.4.170 host-render harness** for web: Playwright/Storybook snapshots per `screen × state × {light,dark}` for both sites, dual oracle = golden image-diff **+** OCR/vision layout oracle (overlap/clip/off-screen/giant-widget detection). Self-validate the analyzer (golden-bad overlapping-label fixture MUST FAIL). Replace the a11y "CSS rule exists" checks with rendered-behavior checks.
- Build the **§11.4.168 export validator** (pdftotext/pdfimages/pdftoppm→OCR) with its golden-good/golden-bad pair.
- **Evidence:** analyzers pass golden-good, fail golden-bad; paired §1.1 mutations wired.
- **Gate:** both analyzers self-validated; suites produce captured PNG/PDF artifacts, not assertions.

### Phase 6 — CI enforcement & governance
- Add CI (currently **none** runs tests — only a Jekyll deploy workflow exists) running: OpenDesign token build → both sites build → Playwright + visual-proof + export-validation → axe/contrast → the propagation gates.
- Register gates `CM-OPENDESIGN-UI-SYSTEM`, `CM-HOST-RENDERED-UI-VISUAL-PROOF`, `CM-EXPORTED-DOC-VISUALLY-VALIDATED` (+ propagation literals `11.4.162/.168/.170`).
- **Formally supersede** `_analysis/DESIGN-SPEC.md` with this plan; leave a pointer stub.
- **Gate:** CI red on any ad-hoc CSS, light-only component, token-equality-only UI proof, or unvalidated export.

---

## 4A. Portfolio auto-generation system (both sites + PDF)

**Requirement:** a mechanism that **fully automatically generates a multi-page, stunningly-designed Portfolio** (fonts/colors/icons via OpenDesign), delivered as (1) a **separate section on both websites** and (2) a **downloadable PDF**. Web and PDF are two render targets of one generator — never hand-authored twice.

### 4A.1 One generator, three outputs, one design system
```
Verified portfolio DATA (single source of truth, no fabricated metrics — §11.4.6)
  ← _analysis/MASTER-inventory.md  (deduped, forks/mirrors removed, FEATURED curated)
  ← _analysis/github-*.json, gitlab-all.json, top20/*.readme.txt + *.langs.json  (API-harvested)
        │  normalized into a typed portfolio model:
        │  { slug, name, brand, org, summary, tech[], repos[], links[], highlights[], private? }
        ▼
  portfolio generator  (templating + OpenDesign tokens/components/icons)
        ├── WEB  → milosvasic.ru /portfolio/  (multi-page, Jekyll collection)   + i18n (15 langs)
        ├── WEB  → vasic.digital /portfolio/   (multi-page, static pages)         + i18n
        └── PDF  → Portfolio_<brand>_<lang>.pdf  (pandoc → OpenDesign-themed HTML → weasyprint)
```
The **web section and the PDF are generated from the same model + same OpenDesign design system**, so they stay visually and factually identical by construction.

### 4A.2 Content model & data integrity
- **Personal portfolio (milosvasic.ru):** Milos's featured projects (the 12 FEATURED in `MASTER-inventory.md`) — individual authorship framing.
- **Company portfolio (vasic.digital):** Vasic Digital's project set (the 18 in the article system) — company/org framing across the 5 GitHub orgs.
- **Data integrity (mandatory):** metrics come only from harvested data — **no fabricated numbers** (§11.4.6); private HelixTrack clients are described at product level and **never deep-linked** (the existing Playwright guard extends to the portfolio pages + PDF); superlative claims are verified or softened (as `MASTER-inventory.md` already flags).
- **Regeneration is a command, reproducible from clean clone (§11.4.77):** re-run harvest → re-normalize → re-render web+PDF; the generator lives in-repo (closing the current reproducibility gap where tooling lives outside the site repos).

### 4A.3 Design (OpenDesign-driven)
- Portfolio-specific **component tokens in OpenDesign**: project card, project detail page, tech-badge/chip, org/section header, hero, stat tiles, page-footer — light+dark, both brands (§11.4.162).
- **Icons:** technology + platform + link icons sourced through OpenDesign's component/asset layer (not ad-hoc Font Awesome CDN) so web and PDF share one icon set. `[UNCONFIRMED — verify OpenDesign icon/asset support in Phase 0; if absent, extend upstream per §11.4.74]`.
- **Multi-page structure:** index (grid of projects, filterable by tech/org) + one detail page per project (reuses the existing `_article_src` narratives) — for both web and the paginated PDF.

### 4A.4 Delivery
- **Web section:** `/portfolio/` on each site, linked from nav; multi-page; i18n via each site's existing mechanism (milosvasic.ru `data-i18n`; vasic.digital after its Phase-3 `data-i18n` migration); reactive to theme.
- **PDF:** `Portfolio_Milos_Vasic_<lang>.pdf` and `Portfolio_Vasic_Digital_<lang>.pdf`, offered in the same download popup as CV/Cover-Letter, generated by the Phase-4 OpenDesign-themed pandoc→weasyprint pipeline.
- **Validation:** web pages proven by §11.4.170 rendered-pixel proof (screen×state×{light,dark}); every Portfolio PDF proven by §11.4.168 three-layer export validation (content complete, no raw markup leaking, diagrams/images render, OCR-legible).

### 4A.5 Roadmap placement — Phase 4B (after site migration + doc pipeline)
Depends on: Phase 1 (OpenDesign components incl. portfolio card/detail), Phase 2/3 (sites on OpenDesign + vasic.digital `data-i18n`), Phase 4 (OpenDesign-themed PDF pipeline).
- **Deliverables:** typed portfolio model + normalizer from harvested data; the generator; `/portfolio/` sections on both sites; the per-brand/per-language Portfolio PDFs; download-popup entries.
- **Evidence:** §11.4.170 pixels for portfolio index + detail pages (both themes, both sites); §11.4.168 validation on every Portfolio PDF; a data-integrity check asserting zero fabricated metrics + zero private deep-links.
- **Gate:** `CM-OPENDESIGN-UI-SYSTEM` + `CM-HOST-RENDERED-UI-VISUAL-PROOF` (web) + `CM-EXPORTED-DOC-VISUALLY-VALIDATED` (PDF), plus a portfolio-data-integrity gate.

## 5. Per-site concrete work map (starting points)

**milosvasic.ru**
- `assets/css/style.scss:9-41` — bespoke `:root` tokens → OpenDesign import.
- `assets/css/style.scss:462-477` — legacy `.dl-modal` → unified OpenDesign modal.
- `_layouts/default.html:21-23` — remote Google Fonts → self-hosted via tokens.
- `index.html:33-36` — add `<picture>`/WebP.
- `downloads/src/build-pdfs.sh` — re-point at OpenDesign-themed pipeline; consolidate PDFs.
- `start.sh` — remove `sudo` (§11.4.161).

**vasic.digital**
- `css/style.css:2-28` + `:1021-1256` — flat tokens + glassmorphism → OpenDesign tokens.
- `css/logo.css` — delete (dead); `css/articles.css` — fold into OpenDesign modal.
- `js/language-switcher.js:133-268` — positional DOM i18n → `data-i18n` (design-unblocking cleanup).
- `js/translations.js` — reconcile stale stats/dates; complete per-lang dictionaries.
- `Assets/Logo.jpeg` — produce optimized transparent asset (feeds brand palette extraction).

---

## 6. Testing & evidence model (anti-bluff)

- **UI:** §11.4.170 rendered-pixel proof is the ONLY accepted proof of a UI change; token/value-equality tests may supplement, never substitute.
- **Docs/PDFs:** §11.4.168 three-layer independent validation on every export.
- **Every analyzer** self-validated (golden-good PASS / golden-bad FAIL) with a paired §1.1 mutation; a validator that passes its golden-bad is inadmissible.
- **No silent skips** (§11.4.3): the only permitted absence is an honest SKIP-with-reason (genuinely missing harness/topology), tracked, never silent.
- **Contrast** (§11.4.107) verified independently of OpenDesign token wiring.

---

## 7. Risks & open questions

1. **Is OpenDesign installed / how does it emit tokens?** `[UNCONFIRMED]` — Phase 0 spike resolves the exact `tokens.css`/SCSS/PDF consumption path before migration. If OpenDesign lacks a needed export target, §11.4.74 = upstream PR, not a workaround.
2. **Brand model** (§9-A): shared-foundation + two-brand-themes vs two independent packages vs one merged brand.
3. **Rootless on amber.local** (§11.4.161): the Docker host must move to Podman rootless or be documented as structurally-impossible (§11.4.112).
4. **Reproducibility gap:** render/translate/PDF tooling lives outside the site repos; Phase 6 CI forces it into a reproducible pipeline.
5. **Scope creep:** the i18n-coupling fix (vasic.digital) and PDF consolidation are design-adjacent; keep as separately-gated tasks so design migration isn't blocked by content bugs.
6. **DESIGN-SPEC reconciliation:** must be explicitly superseded to avoid two conflicting specs.

---

## 8. Suggested first increment

**Phase 0 + a Phase-1 vertical slice:** install OpenDesign + wire MCP, check out the constitution submodule, extract both brand palettes, and take **one component (the button)** all the way through — defined in OpenDesign → compiled tokens.css → consumed by both sites → proven by a §11.4.170 host-rendered PNG in light+dark on both sites. This validates the entire toolchain end-to-end on the smallest surface before scaling to every component. (Directly answers the "giant-button bluff" that motivated §11.4.170.)

---

## 9. Decisions needed before execution

> **Provisional defaults adopted 2026-08-05** (recommended options, pending explicit confirmation — flip anytime):
> §9-A = shared foundation + two brand themes · §9-B = check constitution submodule in during Phase 0 · §9-C = Phase 0 + button vertical slice · §9-D = personal 12 / company 18, Portfolio PDFs in all 15 languages.


- **§9-A Brand model:** confirm shared-foundation + two-brand-themes (recommended).
- **§9-B Constitution submodule:** check it into the `vasic` umbrella now (recommended) so gates apply, or keep governance-by-reference.
- **§9-C First increment:** confirm the Phase-0 + button-vertical-slice starting point (recommended) vs a different first surface.
- **§9-D Portfolio (§4A):** confirm one generator → web-section-on-both-sites + per-brand/per-language PDF, driven by the existing verified repo-inventory data (recommended); confirm personal (milosvasic.ru, 12 featured) vs company (vasic.digital, 18) content split; confirm PDF language coverage (match the 15-lang site set vs a smaller set).
