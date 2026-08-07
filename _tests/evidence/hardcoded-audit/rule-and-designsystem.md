# Hardcoded-Content Audit — The Rule + Design-System / Data-Model

READ-ONLY audit. No source edited. Scope: (A) constitution anti-hardcoding
mandate; (B) `design-system/**`, the generator/data-loading layer, `_content/**`;
(C) the intended data-model map. Date: 2026-08-07.

---

## A. THE RULE — constitution anchors that mandate data-driven, non-hardcoded content

The Constitution (`submodules/constitution/Constitution.md`) has **no single
"website copy must not be hardcoded" clause**; the mandate is **composed** from a
small anchor family. The load-bearing anchors, quoted verbatim:

### §11.4.35 — configuration/content supplied as DATA (the core "as data" anchor)
Recurring normative phrase across dozens of universal anchors:
> "…the consuming project supplies its … **as DATA per §11.4.35**."
And e.g.:
> "consumer-bound path **as DATA per §11.4.35**"

§11.4.35 is the generalized decoupling-to-data rule: project-specific values
(paths, brand values, language sets, glossary, token values, copy) are **injected
as data**, never baked in as literals. This is the anchor to cite for "content
must live in data files, not hardcoded in templates/CSS/code."

### §11.4.216 — canonical machine-readable design-token source (anti-hardcoding for design values)
> "§11.4.216 — canonical machine-readable design-token source: ONE CSS
> custom-property file (`:root {}` + `[data-theme="dark"]` override), **every
> platform consumes GENERATED bindings never hand-copies, no invented values**
> (§11.4.6 applied to design — every color traceable to eyedrop/measured-contrast
> evidence)."

"Never hand-copies, no invented values" = no hardcoded design literals; every
value derives from the single token source.

### §11.4.162 — OpenDesign is the MANDATED token system
> "§11.4.162 (OpenDesign) … OpenDesign is the mandated token SYSTEM" (and per the
> design-system README: "no ad-hoc CSS, no other token system"). §11.4.190 is the
> "strict WEB-quality expansion of §11.4.162 … host-rendered pixel proof as the
> correctness oracle."

### §11.4.219 — real data, honesty markers, never a fake flow
> "populated with **REALISTIC product data (never lorem-ipsum for load-bearing
> content)** … where the backing backend, contract, or product decision does not
> exist, the screen MUST say so … **NEVER a designed-as-if-real fake flow**."

Load-bearing content must be REAL (from data), and gaps must be marked, not faked.

### §11.4.237 / §11.4.140 / §11.4.141 — every localized string is data + independently reviewed
Every translated artifact (UI strings, pages, PDFs, "any localized content") is
produced by the canonical pipeline and independently reviewed; the consuming
project "supplies its language set, term glossary, non-translatable token list …
**as DATA per §11.4.35**." Implies: user-facing strings are dictionary entries
(data), not literals in code.

### Anti-bluff / evidence angle
- **§11.4.6** (honest boundary / no invented values) is explicitly "applied to
  design" inside §11.4.216 — a hardcoded/invented value is a §11.4.6 bluff.
- **§11.4.223** — provenance markers `[VERIFIED]/[OPERATOR]/[DEFAULT]/[OPEN:id]`
  for design docs; open items registered + tracked (§11.4.93/§11.4.197).
- A remediation for any finding below must land the fix as a tracked workable item
  with a RED→GREEN guard, not as prose (§11.4.202/§11.4.205) — "a rule that lives
  only in prose is re-learned per session and skipped under pressure."

**Citation for remediation:** anchor the "no hardcoded content" requirement on
**§11.4.35** (content/config as data) + **§11.4.216/§11.4.162** (design values as
generated tokens, no invented values) + **§11.4.219** (real data / no fake) +
**§11.4.6** (invented value = bluff).

---

## C. DATA-MODEL MAP — how content is SUPPOSED to flow

The Go generator under `_tools/gen/` renders both sites from data. Anything
content-bearing OUTSIDE this model is a candidate violation.

| Data source | Feeds | Loader / type |
|---|---|---|
| `_content/portfolio/portfolio.json` | product metadata (name, slug, tier, status, license, tech, repos, summary, tagline) — **"single source of truth for product metadata, shared by both sites"** | `data.go` `Portfolio` / `loadPortfolio` |
| `_content/sites/<site>.home.json` (+ `.home.<lang>.json` ×15) | homepage content model — hero/section/contact blocks, prose, cards, stats, CTAs | `data.go` `HomeDoc` / `loadHome`; rendered by `home.go` |
| `_content/products/*.md` (+ `_content_<lang>/products/*.md`) | product detail pages (frontmatter + markdown body) | `data.go` `parseFrontmatter`; `product.go`, `markdown.go` |
| `_content/docs/*.md`, `_content/sites/*.md` (+ `_content_<lang>/…`) | CV / cover-letter / portfolio docs; per-site page shells | `markdown.go` |
| `_tools/gen/ui-i18n.json` (embedded via `//go:embed`) | **every generator-emitted UI/chrome + SEO string**, ×15 languages; EN is source of truth, non-EN reviewer-gated (§11.4.140/141/236) | `i18n.go` `T(lang,key)` |
| `design-system/brand-*/*.css` (`:root` tokens) | all colors/spacing/type/motion; consumed only via `var(--od-*)` | linked/imported per surface |
| `_content_<lang>/**` (15 mirrors: ar be de es fa fr hi ja kk ko ru sr tr zh) | translated content, mirroring `_content/{docs,products,sites}` structure | same loaders, lang-suffixed |

Correct pattern: **strings → `T(lang,key)` (ui-i18n.json); prose/cards/stats →
home.json; product facts → portfolio.json + product .md; design values →
`var(--od-*)` tokens.** A literal string in Go/CSS/HTML template that is
visitor-facing prose and bypasses these = violation.

---

## B. FINDINGS — design-system + generator + content

### Design-system CSS — CLEAN of hardcoded prose (decorative only)
All `content:` declarations across `design-system/**/*.css` are **decorative**,
not visitor-facing prose — NOT violations:
- `components-extended.css` — `content:''`/`content:""` on `::before/::after`
  (icons, rings, geometric marks): lines 396, 409, 458, 706, 1009.
- `brand-milosvasic/milosvasic.css:710,716` — `content:""` decorative accent bar.
- `brand-vasic-digital/vasic-digital.css:396,562` — `content:""` decorative.
- `motion/animations.css:119,154,172,277` — `content:""` decorative.
- **Borderline (LOW/none):** `components-extended.css:747` breadcrumb separator
  `content:'/'`. A structural separator glyph (chrome), not prose; standard
  practice. Note only — could be tokenized/localized if strictness demanded.

Other design-system surfaces:
- `design-system/components-extended.css` — **0 raw hex colors**; 100%
  `var(--od-*)` (satisfies §11.4.216). GOOD.
- `design-system/icons/icons.svg` — pure `<symbol>`/`<path>`, **no `<text>`**. GOOD.
- `design-system/motion/motion.js` — no hardcoded user-facing prose; the count-up
  reads/writes numeric text from `data-*`/`textContent` only. GOOD.
- `design-system/preview/*.html`, `fonts/preview.html`, `motion/preview.html` —
  contain hardcoded English demo labels, but these are the **design-library
  catalogue / rendered proof fixtures** (§11.4.218), NOT shipped visitor content.
  EXPECTED — not violations.

### Generator (`_tools/gen/**`) — content is data-driven; minor literals

**F1 — LOW — hardcoded `background:#fff` in generator-emitted CSS.**
- Location: `_tools/gen/shells.go:32` (`.od-brand__logo`) and `:35`
  (`.vd-hero__logo img`); also the personal-brand `mvHeadStyle` uses white chips.
- Literal: `background:#fff`.
- Why a violation: §11.4.216 "no invented values" — a raw color literal in
  token-governed CSS instead of a `var(--od-*)` token (e.g. a `--od-surface-inv`
  / logo-plate token). Design value, not content.
- Severity: LOW. Remediation: add a token for the logo/portrait plate color and
  reference it; or document as an intentional pure-white plate token.

**F2 — LOW — hardcoded copyright year `© 2026`.**
- Location: `_tools/gen/i18n.go:154` (switcher footer dict) and
  `_tools/gen/product.go:244` (product page footer). (The standalone home footer
  uses `HomeDoc.Footer` from home.json — data-driven, OK.)
- Literal: `"© 2026 "`.
- Why a violation: a fixed datum baked into template/code that should be
  parameterized (build-time year or a data field) — will silently go stale; mild
  §11.4.35 ("as data") + §11.4.6 (honesty/staleness) concern.
- Severity: LOW. Remediation: derive the year at generation time or source from
  site data; keep `©`/suffix in the dict (suffix already is: `footer.suffix`).

**F3 — LOW/INFO — status & tier VALUES emitted verbatim, not localized.**
- Location: `_tools/gen/product.go:162,173` — `<span class="od-badge--status
  od-badge--status--%s">%s</span>` with both `%s = esc(e.Status)`; the eyebrow
  emits `esc(e.Tier)` and `esc(e.License)` verbatim.
- Literal: none in code — values come from `portfolio.json` (`status`, `tier`,
  `license`). So they ARE data-driven (compliant with §11.4.35), BUT the visible
  status/tier label text is the raw English value, identical across all 15
  localized pages (the surrounding labels `prod.tier`/`prod.license`/`prod.order`/
  `prod.source` DO localize via `T()`).
- Why noted: a **localization-completeness** gap (§11.4.237) rather than a
  hardcoding violation — human-readable status/tier prose is not run through the
  i18n dictionary. License string is correctly non-translatable (proper token).
- Severity: LOW / INFO. Remediation (if desired): map status/tier codes to
  `T(lang, "status.<code>")` / `T(lang,"tier.<code>")` dictionary entries; keep
  `portfolio.json` as the code source.

**Not a violation — `tOr` English fallbacks (`home.go:401,404-406`).**
`tOr(lang,"skip","Skip to content")`, `nav.work→"Work"`, `nav.contact→"Contact"`
look like hardcoded copy, but `i18n.go` `tOr` returns the fallback ONLY when the
dictionary lacks the key. **Verified**: the embedded `ui-i18n.json` contains
`skip`, `nav.work`, `nav.contact`, `nav.products`, `nav.portfolio`,
`footer.suffix`, `aria.primaryNav`, `aria.backToTop`, `aria.toggleTheme` for **all
15 languages** — so the literals are honest EN-source fallbacks that never
surface, exactly the §11.4.35/§11.4.6 "degrade honestly to EN" pattern the code
comments describe. GOOD.
(Note: the sibling file `_tools/gen/ui-i18n.en.json` is MISSING nav.work/
nav.contact/aria.* — but it is NOT the embedded/compiled dictionary; the
`//go:embed ui-i18n.json` file is complete. `ui-i18n.en.json` appears stale/
secondary — worth a follow-up to reconcile or delete, low priority.)

### `_content/**` — CLEAN
Structure matches the data model: `portfolio/portfolio.json`, `products/*.md`,
`docs/*.md`, `sites/*.home[.<lang>].json` + `sites/*.md`, mirrored across 15
`_content_<lang>/` trees. No content-bearing literals outside the model observed.

---

## CONSOLIDATED VIEW

| ID | Severity | Location | Issue | Anchor |
|----|----------|----------|-------|--------|
| F1 | LOW | `_tools/gen/shells.go:32,35` (+mv style) | `background:#fff` raw color literal in token-governed CSS | §11.4.216/§11.4.6 |
| F2 | LOW | `_tools/gen/i18n.go:154`, `product.go:244` | hardcoded `© 2026` year | §11.4.35/§11.4.6 |
| F3 | LOW/INFO | `_tools/gen/product.go:162,173` | status/tier values data-driven but not localized | §11.4.237 |
| — | none | `design-system/**` CSS/JS/SVG | decorative `content:` only; 0 raw hex; no prose | (clean) |
| — | none | `home.go` `tOr` fallbacks | keys present ×15 in embedded dict; honest EN fallback | (clean) |
| note | INFO | `_tools/gen/ui-i18n.en.json` | stale/secondary, missing keys; not compiled | reconcile |

**Bottom line:** The design-system and the content pipeline are **substantially
compliant** with the data-driven mandate. The token layer is clean
(components-extended.css 0 raw hex; icons/motion no prose). All shipped visitor
copy flows through `ui-i18n.json` (strings), `*.home.json` (prose/cards), and
`portfolio.json` + product `.md` (facts). The only literals found are three
LOW-severity items in the **generator** (a `#fff` plate color, a `© 2026` year,
and un-localized status/tier values) — none are hardcoded prose in shipped
templates or CSS. Any remediation should land as tracked items with RED→GREEN
guards, not prose (§11.4.202/§11.4.205).
