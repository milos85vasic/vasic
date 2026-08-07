# Localization + per-language SEO audit — generated chrome (both sites)

Scope: every **generator-emitted** user-visible string that is NOT part of the
`_content/**` docs, plus per-language SEO on generated pages. Source of truth is
the Go generator `_tools/gen/` (`shells.go`, `seo.go`, `home.go`, `portfolio.go`,
`product.go`) and the site JS i18n dictionaries
(`milosvasic.ru/assets/js/i18n.js` → `MV_I18N`; `vasic.digital/js/translations.js`).
The `_content_<lang>/` doc-translation batch and `_tests/evidence/translate-new/`
are a SEPARATE surface and are out of scope (only read, never written).

LANGS (15): en · ru sr de es fr be zh kk hi ja ko ar tr fa

---

## 1. Surfaces and how each is localized

| Surface | Renderer | Localization mechanism | State BEFORE |
|---|---|---|---|
| milosvasic.ru home | Jekyll `_layouts/default.html` + `home.go` (jekyll) | client-side `i18n.js` (`MV_I18N`, 15 langs) + language switcher | GOOD (chrome localized) |
| vasic.digital home | `home.go` (standalone) | `data-i18n` attrs present, but `translations.js` **not loaded** → inert | EN-ONLY in practice |
| Portfolio (both sites) | `portfolio.go` | none — chrome hard-coded English | EN-ONLY, all 15 |
| Product pages (both sites) | `product.go` | none — chrome hard-coded English | EN-ONLY, all 15 |

Key finding: the **server-rendered** portfolio + product pages emitted 100%
hard-coded English chrome and English-only SEO **for every language**, and no
per-language product/portfolio pages had ever been generated on disk
(`products/<lang>/`, `portfolio/<lang>/` were absent).

---

## 2. Inventory of generated non-content UI strings (the gap set)

These are the strings the generator prints. BEFORE = hard-coded English for all
14 non-EN languages (English-fallback). Each now has a key in `ui-i18n.json`.

Chrome (shells / product / portfolio):
- `skip` "Skip to content" (skip link)
- `nav.home` "Home", `nav.products` "Products", `nav.portfolio` "Portfolio"
- `toggle` "Toggle theme" (theme-toggle aria-label)
- `footer.suffix` "built on the OpenDesign system"

Portfolio body:
- `pf.eyebrow` "unified portfolio", `pf.title` "Portfolio"
- `pf.download` "Download Portfolio (PDF)"
- `pf.stat.products` "Products", `pf.stat.tiers` "Tiers", `pf.stat.helix` "Helix products"
- `pf.overview.eyebrow` "overview", `pf.overview.title` "One fleet, one discipline"
- `pf.readmore` "Read more"
- `pf.lede` (hero lede paragraph), `pf.summary` (overview paragraph)
- `tier1/2/3.eyebrow` + `tier1/2/3.title` (six tier-section headers)

Product body:
- `prod.tier` "tier", `prod.order` "order" (eyebrow "// tier: X · order N")
- `prod.source` "Source", `prod.license` "license"
- `prod.architecture` "architecture" (diagram figcaption)

SEO:
- `kw.vasic` / `kw.milos` (per-site meta keywords — previously ABSENT)

Total: 29 distinct generator UI/SEO keys × 14 non-EN languages = **406 strings**
that were English-fallback before this work.

---

## 3. Per-language SEO audit of generated pages (BEFORE)

| Signal | Before | Notes |
|---|---|---|
| `<title>` | English only | product = "<Name> — <Brand>"; portfolio = "Portfolio — <Brand>" |
| `meta description` | English only | product = EN summary; portfolio = EN lede |
| `meta keywords` | **ABSENT** | no keywords tag emitted at all |
| `link canonical` | OK | correct EN canonical per page |
| hreflang alternates | OK (reciprocal) | full 15-lang matrix + `x-default`; reciprocal by construction |
| `og:*` / `twitter:*` | present, EN | title/desc English; **`og:locale` hard-coded `en_US`** for every language |
| JSON-LD | EN | `WebSite.inLanguage` = "en", `SoftwareApplication.inLanguage` = "en" (hard-coded) |

So: hreflang + canonical were already correct; **title/description were not
translated, keywords were missing entirely, and og:locale + JSON-LD inLanguage
were hard-coded English on every localized page.**

---

## 4. JS i18n dictionary audit

- `MV_I18N` (`milosvasic.ru/assets/js/i18n.js`): 15 langs, comprehensive home
  keys (nav, hero, downloads, summary, work cards, skills, author, contact).
  Reviewer-gated per project history. GOOD.
- `translations.js` (`vasic.digital/js/translations.js`): 15 langs present, BUT
  the keys are **stale** relative to the regenerated vasic home (e.g. it has
  `hero.title` = "Excellence in Software Engineering" while the generated page
  uses `hero.title` = "AI-native software engineering, built to be trusted." and
  keys like `hero.eyebrow`, `hero.cta_products`, `stat.providers`, `about.body2`
  that translations.js does not carry). It is ALSO not loaded by the generated
  `index.html`. Net effect: the vasic home language switcher is non-functional
  and, if wired as-is, would mistranslate. (Documented gap — see §6.)
- Untranslated aria-labels on the milosvasic Jekyll layout ("Change language",
  "Toggle dark / light theme", "Close", "Language", "Theme") and the footer prose
  line have no `data-i18n`. (Minor; layout-owned, documented gap.)

---

## 5. FILL — what changed in the generator (this work)

- New `_tools/gen/i18n.go` + embedded `ui-i18n.json`: a per-language dictionary
  (`T(lang, key)` with explicit EN fallback), `htmlDir` (RTL for ar/fa/he/ur),
  `ogLocale`, `siteKeywords`. Reviewer-gated translations (see §7).
- `seo.go`: `og:locale` now per-language; `meta keywords` emitted per-language;
  JSON-LD `inLanguage` per-language via `baseGraphLang` / `softwareApplicationNodeLang`
  (original signatures preserved → non-breaking). `pageSEO` gained `lang` +
  `keywords`.
- `portfolio.go`: hero eyebrow/title/lede, download CTA, three stat labels,
  overview eyebrow/title, summary, all six tier headers, per-card "Read more",
  skip link, nav (Home/Portfolio), theme-toggle aria, footer suffix, `<html lang/dir>`,
  and the SEO head (title/desc/keywords/og:locale/inLanguage) — all localized via
  `T(lang, …)` for both the self-contained and Jekyll shells.
- `product.go`: eyebrow ("// tier: … · order …"), "Source", "license", diagram
  "architecture" caption, skip link, nav (Home/Products), theme-toggle aria,
  footer suffix, `<html lang/dir>`, and SEO head — all localized. Product BODY is
  read-only sourced from `_content_<lang>/` when a translation exists (e.g. `ru`),
  else EN (that doc surface is owned elsewhere).
- `main.go`: threads `lang` into `renderProduct`.

Glossary terms (Helix*, LLM, Vasic Digital, Server Factory, PDF, Go, Kotlin, …)
are preserved verbatim in every translation via `glossary_protect.py` sentinels.

---

## 6. Honest caveats / residual gaps (not closed here)

1. **vasic.digital home client i18n**: `translations.js` is stale + unloaded.
   The generated vasic home remains EN-only until `translations.js` is regenerated
   against the current `data-i18n` keys (a client-content task) and wired into the
   generated `index.html`. Server-rendered vasic home chrome now uses `T()` but is
   only ever generated for `en` (home content data is EN-only), so localization of
   the vasic home still depends on the client switcher. NOT closed.
2. **milosvasic home**: chrome is already localized client-side; the remaining
   gaps are a few layout aria-labels + footer prose without `data-i18n`, and
   `jekyll-seo-tag` head being English-only. Layout-owned; NOT closed here.
3. **Product/portfolio card blurbs + product body** are `_content`-derived
   (taglines/summaries). Chrome + SEO around them is localized; the prose is the
   separate `_content_<lang>` surface (used read-only where present).
4. `TestAvailableLangs` currently fails in this checkout because `_content_de/`
   and `_content_sr/` are not on disk this session (only `_content_ru/`). This is
   environmental, predates this work, and is not touched (editing `_content_*` is
   out of scope).

See `coverage-matrix.md` for the before→after numbers and `reviews/` for the
independent per-language review verdicts.
