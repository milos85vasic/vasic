# Hardcoded-content audit — build/scripts/tooling + Jekyll layer

Read-only, multi-pass audit. Mandate: visitor-facing content must be DATA-DRIVEN
(sourced from `_data/ui.json`, `MV_I18N`, `ui-i18n.json`, `pdf-i18n.json`,
`_content/**`), never baked into scripts or layouts.

VIOLATION = visitor-facing prose/copy/labels/metrics/alt-text hardcoded in a
script/layout instead of a data/i18n source. NOT a violation = HTML/CSS
structure, Liquid/JS control flow, config keys, build logic, brand names, URLs,
email/handle identifiers, schema.org enum values, endonym language names, or text
already sourced via `{{ site.data.ui[...] }}` / `data-i18n` / `T()` / `t()`.

Scope covered: `_tools/pdf/build-pdfs.sh` (+ `pdf-i18n.json`),
`_tools/gen/build.sh`, `_tools/deploy-langs.sh`, `_tools/translate/*`,
`_tools/od/*`, milosvasic.ru Jekyll (`_config.yml`, `_layouts/*.html`,
`_includes/*` [none exist], `_data/*`, `assets/js/*.js`), vasic.digital shells.
Cross-referenced against the i18n/data sources. The Go generator under
`_tools/gen/*.go` is the tooling that renders the sites, so it is included where
it bakes content (flagged as "generator" — beyond the literal shell list but
central to the mandate).

---

## Summary counts

| Severity | Count |
|---|---|
| HIGH | 2 |
| MED  | 5 |
| LOW  | 6 |

Clean (no violations): `_tools/gen/build.sh`, `_tools/deploy-langs.sh`,
`_tools/gen/shells.go`, `_tools/gen/seo.go`, `_tools/gen/i18n.go`,
`_layouts/default.html`, `_data/ui.json` (fully localized ×15),
`assets/js/i18n.js`, `assets/js/main.js`, `_tools/translate/*`, most of
`_tools/od/*`, vasic.digital generated shells.

---

## Prioritized fix list

1. **[HIGH]** Populate `_tools/pdf/pdf-i18n.json` for all 14 non-EN languages (F-1).
2. **[HIGH]** Localize the article "Read more" modal strings in `articles.js` (F-6).
3. **[MED]** Localize PDF figure `alt` text (F-2).
4. **[MED]** Move PDF metric values out of the script into data (F-3).
5. **[MED]** Move `creativeHeadings` editorial section-heading copy out of the generator (F-7).
6. **[MED]** Localize the two hero `alt` texts in `home.go` (F-8).
7. **[LOW]** F-4, F-5, F-9, F-10, F-11, F-12.

---

## PASS 1 — shell scripts emitting content

### F-1 [HIGH] `pdf-i18n.json` holds ONLY `en`; every non-EN PDF renders English chrome
- File: `_tools/pdf/pdf-i18n.json:1-28` (top-level keys = `["en"]` only)
- Consumer: `_tools/pdf/build-pdfs.sh:164-175` `t()` — on a missing lang/key it
  returns the EN value + prints `WARN … EN fallback`.
- The script header (lines 154-161) claims the strings live in `pdf-i18n.json`
  "EN populated … 14 langs via the HelixTranslate pipeline + reviewer." **The 14
  translations were never added** — only `en` exists. So `build-pdfs.sh <lang>`
  for ru/sr/de/es/fr/be/zh/kk/hi/ja/ko/ar/tr/fa emits English for EVERY chrome
  string: cover eyebrow/role/tagline (`t cv.* / cover.* / pf.*`, lines 474-498),
  the "At a glance" metric labels (478, 500), the "Selected architecture"
  heading (`t pf.figures.heading`, 506) and all three figure captions (512-514)
  — in the personal CV/Cover-Letter/Portfolio AND the vasic.digital company
  Portfolio (569).
- Why a violation: visitor-facing PDF copy is untranslated in 14 languages. The
  externalization is HALF-DONE — mechanism is data-driven (good), data is
  missing (the leak).
- Remediation: add the 14 language blocks to `pdf-i18n.json` (same keys as `en`)
  via the translation + review pipeline. Until then non-EN PDFs are English-chrome.

### F-2 [MED] PDF figure `alt` text hardcoded in English
- File: `_tools/pdf/build-pdfs.sh:512-514`
- Literals: `alt="HelixAgent ensemble debate flow"`,
  `alt="HelixCluster distributed compute control plane"`,
  `alt="LLMsVerifier verification source of truth"`
- Only the figure *captions* are localized (`t pf.figure.*`); the `alt`
  descriptions are literal English and are embedded in every non-EN PDF (PDF/UA
  alt). Product names are legit glossary brands; the descriptive tail is prose.
- Remediation: add `pf.figure.helixagent.alt` / `.helixcluster.alt` /
  `.llmsverifier.alt` to `pdf-i18n.json` and render via `t`.

### F-3 [MED] PDF "At a glance" metric VALUES baked into the script
- File: `_tools/pdf/build-pdfs.sh:478` (`2009`, `140+`, `43`, `6+`) and
  `:500` (`140+`, `43`, `25`, `439`)
- Factual metrics (repos governed, providers unified, distros provisioned,
  passing tests) hardcoded as literals in the tooling. Language-neutral, but the
  audit mandate explicitly names "metrics" as content that must be data-driven.
- Remediation: source from a data file (e.g. a non-translatable `metrics` block
  in `pdf-i18n.json`, or `_content` data) so the figures have one source of truth.

### F-4 [LOW] PDF unknown-document fallback branch hardcodes English
- File: `_tools/pdf/build-pdfs.sh:520`
- Literal: `role="AI Engineer"; hright="Document"; eyebrow="Document"; tagline=""; contact="milosvasic.ru"`
- Dead in normal runs (only reached for a doc basename other than
  cv/cover-letter/portfolio) but is an un-localized English literal.
- Remediation: route through `t()` or drop the branch.

### F-5 [LOW] PDF contact lines hardcoded in the script
- File: `_tools/pdf/build-pdfs.sh:477, 484, 492, 498`
- Literals: `<b>milos85vasic@gmail.com</b> … milosvasic.ru … vasic.digital … GitHub: …`
- Borderline: these are language-neutral identifiers (email/URLs/GitHub org
  handles), not translatable prose — not a strict violation, but they are
  content baked into the script rather than a data file.
- Remediation (optional): move to a data file for single-source maintenance.
- NOTE (not a violation): `build-pdfs.sh:244` `@bottom-left content:"milosvasic.ru · vasic.digital"`
  is a brand/URL footer (identifier), legitimately in the print stylesheet.

### deploy-langs.sh / gen build.sh — CLEAN
- `_tools/deploy-langs.sh` and `_tools/gen/build.sh`: only build/deploy logic and
  operational `echo`/commit-message strings (not visitor-facing). No content.

---

## PASS 2 — Jekyll layout/include hardcoded text

### `_layouts/default.html` — CLEAN (exemplary)
- Every chrome string (skip link, primary nav, lang/theme/menu aria+title,
  footer text, download-modal heading/choose/close) is rendered from
  `site.data.ui[page.lang]` with an explicit per-key `… | default: site.data.ui['en'][…]`
  and carries `data-i18n*` so `i18n.js` re-localizes at runtime (lines 39-99).
- `_data/ui.json` is fully populated for all 15 languages (verified) — the
  server-side fallback chain is genuinely localized, not English-masquerading.
- `_includes/` does not exist (nothing to audit).

### F-9 [LOW] Download-modal static placeholders (no-JS only)
- File: `_layouts/default.html:88` `<h3 id="dl-title" class="dl-doc-name">CV</h3>`
  and `:91-93` the static `EN / SR / RU` `dl-lang` rows.
- These are overwritten at runtime by `downloads.js` (`nameEl.textContent`,
  `render()`), so JS users never see them; the language names shown are endonyms.
  With JS disabled a no-op English-ish placeholder shows. Low impact.
- Remediation (optional): make the placeholder `dl-doc-name` use `data-i18n="dl.cv"`.

### F-10 [LOW] `_config.yml` site tagline/description are English-only
- File: `milosvasic.ru/_config.yml:2` (`tagline`) and `:3-7` (`description`)
- Feed `{% seo %}`. These are the site-level source-of-truth defaults; the
  Go-generated localized pages carry their own localized SEO (`seo.go` + `T()`),
  so impact is limited to any Jekyll-rendered localized page, which would emit
  English `<meta description>`. Legitimate as EN source, flagged for awareness.
- Remediation: if Jekyll ever renders non-EN standalone pages, override
  `description` per-page/lang; otherwise acceptable.

---

## PASS 3 — `_config.yml` visitor-facing values

Covered under F-10. All other keys (title, url, author, social links, logo,
plugins, exclude, sass) are legitimate config / identifiers, not violations.

---

## PASS 4 — JS hardcoded user-facing strings (not from MV_I18N / _data)

### F-6 [HIGH] `articles.js` article-modal strings hardcoded in English
- File: `milosvasic.ru/assets/js/articles.js:27-33`
- Literals (`I18N_DEFAULTS`): `loading: "Loading…"`, `close: "Close"`,
  `error: "Sorry, this article could not be loaded."`, `retry: "Retry"`,
  `dialog: "Article"`.
- `articles.js` does **not** read `window.MV_I18N`. Its `i18n()` (lines 46-52)
  only checks a `data-i18n-<key>` attr on the trigger or `<html>`, then falls
  back to these English literals. Cross-ref: those `data-i18n-*` attributes are
  set NOWHERE in the repo (the only grep hit is the comment on `articles.js:10`).
  So the "Read more" modal shows English `Loading…` (every open), the error
  message, `Retry`, the close aria-label, and the `Article` dialog aria-label in
  ALL 14 non-EN languages.
- Severity: `Loading…` is shown on every article open → HIGH; error/retry/close/
  dialog are MED (error/transient/a11y) but share the same root cause.
- Remediation: add `article.loading` / `article.close` / `article.error` /
  `article.retry` / `article.dialog` to `MV_I18N` (and `_data/ui.json`) and have
  `articles.js` read `window.MV_I18N[lang]`; OR emit those `data-i18n-*`
  attributes on `<html>` from `default.html` using `site.data.ui`.

### `assets/js/i18n.js` — CLEAN
- Lines 22-777 are `MV_I18N`, the accepted i18n DATA source (15 langs, source
  copy). The apply logic (783-817) only copies dictionary values into
  `data-i18n*` nodes — no literals. `MV_LANGS` names (4-20) are endonyms.

### `assets/js/main.js` — CLEAN
- Reads `MV_I18N`/`MV_LANGS`; theme glyphs `☀`/`◐` (13) and `code.toUpperCase()`
  (46) are non-prose UI symbols. No hardcoded copy.

### F-11 [LOW] `downloads.js` missing `dl.portfolio` key → English fallback
- File: `milosvasic.ru/assets/js/downloads.js:79` `t('dl.portfolio', 'Portfolio')`
- `dl.portfolio` is absent from `MV_I18N`, so the English literal `Portfolio`
  is always used for the portfolio modal title. `dl.cv`/`dl.cl` DO resolve.
  "Portfolio" is near-universal, hence LOW.
- `LANG_NAMES` (32-36) are endonyms — not a violation.
- Remediation: add `dl.portfolio` to each `MV_I18N` language.

---

## PASS 5 — generator baked content (tooling)

### F-7 [MED] `markdown.go` bakes ~40 English editorial section headings
- File: `_tools/gen/markdown.go:210-271` (`creativeHeadings`) + `275-284`
  (`editorialHeading`)
- Literals emitted as visible product-page `<h2>` on the EN site, e.g.
  "The problem we set out to solve", "Why this exists", "The itch we had to
  scratch", "Why it changes the game", "Hard problems, honest solutions",
  "Under the hood", "Status, told straight". A per-slug hash swaps the canonical
  brief heading (e.g. `## Why we built it`) for one of these variants.
- Why a violation: visitor-facing heading copy invented by the tooling, not
  sourced from `_content`. Cross-ref: non-EN product `.md` translate their
  headings (verified — DE uses `## Warum wir es entwickelt haben`), so they do
  NOT match the English keys and pass through verbatim (no leak *today*); but
  the editorial layer is EN-only, so non-EN pages show plain brief headings
  while EN shows polished variants, and any future localized doc that retained
  an English heading would emit an English editorial variant.
- Remediation: move the heading copy into per-language `_content`/data (or drop
  the editorializer so headings come straight from the localized markdown).
- Related observation (MED, i18n bug, not strictly baked *content*):
  `markdown.go:286-290` `specialProductSections` and `renderProductBody`'s
  `find("short description"/"summary"/"long description")` (293-317) use
  English-only keys, so on non-EN product pages the hero-lede / opening-narrative
  framing is not applied (those sections render as ordinary labeled sections).

### F-8 [MED] `home.go` hardcodes hero `alt` text in English
- File: `_tools/gen/home.go:196` `alt="Portrait of Miloš Vasić"` and
  `:206` `alt="Vasic Digital logo"`
- Emitted on every localized home; the a11y `alt` stays English for all 15
  languages. ("Vasic Digital logo" is mostly brand; "Portrait of Miloš Vasić"
  is descriptive prose.)
- Remediation: source via `T(lang, "alt.portrait")` / `T(lang, "alt.logo")`.

### Generator otherwise CLEAN
- `home.go`, `product.go`, `portfolio.go` render all visible text from data
  structures via `.render()` / `esc()` + `i18nAttr` (data-i18n) — content comes
  from `_content`. `seo.go` builds title/description/keywords from data / `T()`;
  its only string literals are schema.org enum values (`"DeveloperApplication"`,
  `"Cross-platform"`, `markdown.go` line ~246) which are language-neutral by
  spec. `shells.go` is CSS/SVG symbols + a single `T()`-sourced aria-label.
  `i18n.go` is the localization machinery (endonyms + og:locale maps are data).

---

## PASS 6 — od / translate tooling

### F-12 [LOW] `od/build-preview.mjs` form labels hardcoded
- File: `_tools/od/build-preview.mjs:93-94` — `Name`, `Your name`, `Message`,
  `Say hello`.
- This is an OpenDesign COMPONENT-PREVIEW harness (design-system showcase), not
  shipped visitor content. Noted for completeness; not a production violation.

### `_tools/translate/*`, other `_tools/od/*` — CLEAN
- Pipeline processors (`translate-content.sh`, `finalize-review.sh`,
  `glossary_protect.py`, `cyrillize_sr.py`, `check_terms.py`, `matrix.py`,
  `run-batch.sh`; `od/generate.sh`, `inject-diagrams.mjs`, `od-mcp-call.mjs`,
  `render-diagram.cjs`, `shoot.cjs`, `start-daemon.sh`). Literals present are LLM
  prompt instructions / log lines / config, not visitor-facing output content.

---

## vasic.digital shells
- `vasic.digital/index.html` is Go-generator BUILD OUTPUT (content from
  `_content`), not a hand-authored shell; the shell scaffolding (`shells.go`) is
  clean. No hardcoded content in the shells themselves.
