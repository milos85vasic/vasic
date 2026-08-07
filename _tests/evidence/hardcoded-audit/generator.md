# Hardcoded-content audit — Go generator (`_tools/gen/*.go`)

Read-only, multi-pass audit for user-facing PROSE/COPY baked into code rather
than sourced from data/content/i18n (`_content/**`, `portfolio.json`,
`ui-i18n.json`). Constitution §11.4.140/141/236 + OpenDesign data-driven mandate.

Scope: every non-test `.go` file under `_tools/gen/`
(`main.go`, `data.go`, `i18n.go`, `seo.go`, `markdown.go`, `home.go`,
`portfolio.go`, `product.go`, `shells.go`). `*_test.go` are assertions, not
emitted output → out of scope (noted below). `_tools/pdf/*` is shell/JSON, not
Go → out of scope of this file.

Date: 2026-08-07. No files were modified.

---

## Summary counts

| Severity | Count | Findings |
|---|---|---|
| HIGH | 1 | F1 (creativeHeadings — ~40 English section headings) |
| MED  | 4 | F2, F3 (untranslated `alt` text ×2), F4 (hardcoded tier stat "3"), F5 (English meta-desc fallback suffix) |
| LOW  | 3 | F6 (dead `portfolioLede`/`portfolioSummary` prose consts), F7 (hardcoded "© 2026" year ×3), F8 (JSON-LD `operatingSystem`/`applicationCategory` literals) |

Genuine violations to fix: **8**. False-positives explicitly cleared: see
"Not violations" — the `tOr(...)` English fallbacks are all backed by present
keys and never fire.

---

## HIGH

### F1 — `markdown.go:210–271` `creativeHeadings` map (+ `editorialHeading` 275–284)
Literal (truncated): `"why we built it": {"The problem we set out to solve",
"Why this exists", "What drove us to build it", "The itch we had to scratch",
"Origin story"}, "why it's a game-changer": {"Why it changes the game", …}, …`
(~40 English section-heading strings across 10 canonical keys).

Why a violation: these are visitor-facing **section headings** rendered onto
every product detail page (via `renderProductAccordion` → `editorialHeading`).
They are English prose defined entirely in Go with no data/i18n source. On the
EN pages they *replace* the author's markdown `## heading` with a reworded
English variant; on localized pages the lookup key (English, lowercased) does
not match the translated heading, so `editorialHeading` returns the author's
translated heading verbatim — meaning the reworded copy exists **only** in code
and **only** in English, and can never be translated or reviewed through the
normal pipeline. This is the single largest body of hardcoded copy in the
generator.

Severity: HIGH — substantial visitor-facing prose, code-only, untranslatable.

Remediation: move the heading-variant table out of code into a data/i18n
surface. Two viable shapes:
(a) an i18n table (e.g. `ui-i18n.json` keys `prod.head.<canonicalKey>.<n>`)
resolved via `T(lang, …)` so localized product pages also get the editorial
rewording and it goes through reviewer gating; or
(b) a `_content/`-side JSON (e.g. `_content/products/heading-variants.json`)
loaded at gen time. Per constitution the i18n route (a) is preferred because
these are translatable UI copy. Keep the deterministic per-slug hash selection.

---

## MED

### F2 — `home.go:196` `alt="Portrait of Miloš Vasić"` (inside `const mvPortrait`)
Why: `alt` text is user-facing (screen readers / image-off) and is hardcoded
English with no i18n key (confirmed: no `alt.*` key exists in `ui-i18n.json`).
Emitted on every milosvasic.ru home, all languages, always English.
Severity: MED (untranslated user-facing label).
Remediation: add key e.g. `alt.portrait` to `ui-i18n.json`; convert
`mvPortrait` from a `const` to a func taking `lang` and interpolate
`esc(T(lang,"alt.portrait"))`.

### F3 — `home.go:206` `alt="Vasic Digital logo"` (inside `func vdHeroLogo`)
Why: same class as F2 — hardcoded English `alt` on the vasic.digital hero logo,
no i18n key. Severity: MED.
Remediation: add key e.g. `alt.brandLogo`; pass `lang` into `vdHeroLogo`
(currently takes only `prefix`) and emit `esc(T(lang,"alt.brandLogo"))`.
(Note: the small header brand logo at `home.go:332` uses `alt=""` — correct,
decorative; not a finding.)

### F4 — `portfolio.go:134` hardcoded `<div class="od-stat__value">3</div>`
Literal: the middle portfolio hero stat value `3` (the "Tiers" count).
Why: a number-as-content baked in code instead of derived from data. The other
two stat values on the same block are data-driven (`p.Count`, `helixCount`);
only the tier count is a literal. It happens to equal `len(p.Tiers)` today
(portfolio.json `tiers` has 3 entries) but will silently go stale if a tier is
added/removed — contradicting the data-driven mandate.
Severity: MED (stale-risk, data-driven violation).
Remediation: interpolate `len(p.Tiers)` (p is already in scope in
`portfolioMainInner`) with a `%d`, mirroring `p.Count`/`helixCount`.

### F5 — `product.go:154` English fallback suffix in meta description
Literal: `desc := firstNonEmpty(e.Summary, e.Tagline, e.Name+" — "+site.Brand+" product.")`
Why: the third arg synthesizes an English meta description (` product.`) baked
in code; it feeds `<meta name=description>`, `og:/twitter:description`, and the
SoftwareApplication JSON-LD `description`. Currently latent — all 33
portfolio.json entries have a `summary` or `tagline`, so it never fires today —
but it is hardcoded, English-only, non-translatable copy waiting to surface.
Severity: MED (latent visitor-facing SEO prose; MED because SEO-facing, though
currently unreached).
Remediation: drop the English literal; fall back to an i18n template, e.g.
`fmt.Sprintf(T(lang,"prod.desc.fallback"), e.Name, site.Brand)` with the key in
`ui-i18n.json`, or simply fall back to the already-localized page title.

---

## LOW

### F6 — `portfolio.go:20–21` `const portfolioLede` / `const portfolioSummary`
Literals: `"A unified, evidence-based portfolio of the Helix family, …"` and
`"One fleet: large product applications on top of dozens of small, decoupled,
independently-tested modules — governed by a shared engineering Constitution …"`.
Why: full paragraphs of English marketing prose in code. **Dead**: grep shows
only the definitions — no references. The live portfolio lede/summary are
correctly sourced via `T(lang,"pf.lede")` / `T(lang,"pf.summary")`
(`portfolio.go:146,152`; keys present for 15 langs). So these consts are
vestigial hardcoded copy that predates the i18n migration.
Severity: LOW (not emitted) — but they are exactly the anti-pattern the
constitution forbids and should be removed to avoid regressions.
Remediation: delete both consts.

### F7 — Hardcoded copyright year `© 2026` (×3)
Locations: `portfolio.go:236` (`© 2026 %s — %s`), `product.go:244`
(`© 2026 %s — %s.`), `i18n.go:154` (`"footer.text": "© 2026 " + site.Brand + …`).
Why: the year is content baked in code; it will silently go stale in 2027. The
brand and suffix on the same lines ARE data-driven (`site.Brand`,
`T(lang,"footer.suffix")`), so only the literal year is the issue. Not a
translation issue (digits), but a data-driven/freshness one.
Severity: LOW.
Remediation: derive the year (`time.Now().Year()`) or source it from site
config; centralize the footer string so all three call sites share one source.

### F8 — `seo.go:246` JSON-LD `operatingSystem`/`applicationCategory` literals
Literals: `"applicationCategory": "DeveloperApplication"`,
`"operatingSystem": "Cross-platform"` (in `softwareApplicationNodeLang`).
Why: borderline. These are schema.org structured-data enumerated values, which
the audit rules classify as legit code strings (JSON-LD @types/values). They are
not rendered as visible prose. `operatingSystem: "Cross-platform"` is the only
one that reads like free text.
Severity: LOW / arguably not-a-violation. Listed for completeness.
Remediation (optional): if these ever need to vary per product, move to
per-entry fields in `portfolio.json`; otherwise leave as structured-data
constants.

---

## Not violations (false-positives explicitly cleared)

- `home.go:401,404–407` `tOr(lang,"skip","Skip to content")`,
  `tOr(lang,"nav.work","Work")`, `tOr(lang,"nav.products","Products")`,
  `tOr(lang,"nav.contact","Contact")` — the English literals are `tOr`
  *fallbacks* only. Verified all keys (`skip`, `nav.work`, `nav.products`,
  `nav.contact`, `nav.portfolio`, `nav.home`) now exist for all 15 languages in
  `ui-i18n.json`, so `T()` returns a real translation and the fallback never
  fires. Data-driven; the inline comment in `i18n.go:50–58` is stale but the
  behavior is correct. (Recommend refreshing that comment; not a content bug.)
- `portfolio.go:85,126,140`, `product.go:99,161` `// %s` eyebrow prefix — the
  `//` is a decorative monospace design motif; the text is `T(lang, …)`. OK.
- All `esc(T(lang,…))` / `data-i18n="key"` / `i18nAttr()` emissions across
  `home.go`, `portfolio.go`, `product.go`, `shells.go` — data-driven. OK.
- `product.go:161` eyebrow emits `esc(e.Tier)` (e.g. `helix-primary`) as visible
  text — it is a raw data ID shown to users (a UX nit), but it is sourced from
  `portfolio.json`, so it is NOT hardcoded-in-code. Out of scope here.
- All `const productStyle/portfolioStyle/vasicHeadExtras/mvHeadStyle/*Symbols/
  *ToggleScript` — CSS, SVG icon paths, and JS. Code, not content. OK.
- `seo.go` robots.txt / sitemap XML scaffolding, `assetLinks`, `motionScript`,
  DTCG/`--od-*` token names, class names, Jekyll `relative_url` fragments,
  `data-i18n`/`data-od-count`/`data-dl` attribute names, `ogLocales`/
  `langDisplayNames`/`ogLocale`/`htmlDir` maps (locale codes + endonyms, not
  prose). OK.
- `*_test.go` — expected-output assertions, not generator emissions. Out of
  scope (though F6's dead consts and F1's headings are indirectly asserted by
  `markdown_test.go` — worth checking those tests when fixing).

---

## Prioritized fix list

1. **F1 (HIGH)** — move `creativeHeadings` to i18n (`prod.head.*` in
   `ui-i18n.json`) so product section headings are translatable + reviewer-gated.
2. **F2 + F3 (MED)** — add `alt.portrait` / `alt.brandLogo` i18n keys; thread
   `lang` into `mvPortrait`/`vdHeroLogo` and use `T(lang,…)`.
3. **F4 (MED)** — replace literal `3` with `len(p.Tiers)`.
4. **F5 (MED)** — replace the ` product.` English meta-desc fallback with an
   i18n template or the localized title.
5. **F6 (LOW)** — delete the dead `portfolioLede`/`portfolioSummary` consts.
6. **F7 (LOW)** — derive the footer copyright year instead of literal `2026`;
   unify the three footer strings.
7. **F8 (LOW/optional)** — leave JSON-LD enums, or move to per-entry data if
   they must vary.
