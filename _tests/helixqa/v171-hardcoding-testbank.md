# HelixQA Challenge Bank — v1.7.1 Hardcoded-Content Elimination (#67)

A HelixQA-style **Challenge bank** pinning the v1.7.1 "eliminate ALL hardcoded
content" work on `vasic.digital` and `milosvasic.ru` against silent regression. It
is the **spec** (what is checked, thresholds, evidence schema, golden-good /
golden-bad mutations, executable-check column); the **runners** are:

- live: [`../tests/v171-hardcoding.spec.js`](../tests/v171-hardcoding.spec.js), wired into [`../playwright.live.config.js`](../playwright.live.config.js), read-only against LIVE production:
  ```
  cd _tests && npx playwright test v171-hardcoding.spec.js --config=playwright.live.config.js
  ```
- pre-deploy: [`../../_tools/audit-hardcoding.sh`](../../_tools/audit-hardcoding.sh) — builds the generator with a **2099 sentinel year** and greps the output; exits non-zero on any violation.
  ```
  bash _tools/audit-hardcoding.sh
  ```

**Anti-bluff contract (§11.4.5 / §11.4.6 / §11.4.170):** every PASS is backed by a
**captured POSITIVE measurement**. Golden-BAD mutations prove each detector bites —
all four gate detectors were verified to fire against injected violations (hardcoded
`© 2026` footer, EN summary leak, EN heading, transliterated `लिनक्स`).

**Localization / data mandate:** enforces Helix Constitution **§11.4.140/141**
(localized strings are DATA, no English leakage into a localized surface),
**§11.4.216** (generated values, never invented/hardcoded), **§11.4.65** (render
determinism — identical source ⇒ byte-identical output).

`feature_class = v171_hardcoding`. Evidence → `_tests/evidence/hardcoded-audit-v171/`.

**Check class legend**
- **RUN** — executed live by `v171-hardcoding.spec.js`; real pass/fail, gating.
- **GATE** — executed pre-deploy by `audit-hardcoding.sh` against a fresh build.
- **SPEC** — declared threshold/mutation, enforced by the RUN/GATE check.

**Live baseline: 14/14 PASS** (Playwright, live) · **Gate: 4/4 PASS** (fresh build).

---

## Challenge index

| ID | Fix | Surface | Gate | Class | Live/gate measured |
|----|-----|---------|------|-------|--------------------|
| C67-FOOTER | deterministic © year (not hardcoded) | both home footers | `© <year> Brand`, year ≥ 2026; 2099-sentinel build ⇒ all footers © 2099 | RUN+GATE | vasic & milos live © 2026; sentinel build 100% © 2099 |
| C67-BLK1 | localized portfolio card blurbs | vasic /portfolio/{de,ru}/ | 0 EN marketing-phrase leak; localized blurb present | RUN+GATE | de "für die freie Welt" present; 0 EN leak de/ru |
| C67-BLK2 | localized product meta/OG/JSON-LD desc | vasic /products/{de,ru,ar}/catalogizer | meta+og+JSON-LD desc present & non-EN | RUN+GATE | 0 "self-hostable" leak de/ru/ar; all 3 desc slots localized |
| C67-HEAD | creative headings localized | vasic /products/de/catalogizer | 0 EN `prod.head.*` headings | RUN+GATE | 0 of 5 EN headings on de page; 5 German headings render |
| C67-LINUX | brand "Linux" stays Latin | vasic /products/{hi,ko,ar,fa}/qemu-utils | 0 transliteration; Latin "Linux" present | RUN+GATE | 0 लिनक्स/리눅스/لينكس/لینوکس; Latin "Linux" present all 4 |
| C67-PDF | sr cover-letter term correct | milos sr Cover Letter PDF | "Пропратно писмо" present; "Пријава" absent | RUN | present; 0 "Пријава" |

Overall verdict = PASS only if **all** Challenges PASS (§11.4.134 — loop to the
responsible specialist on any FAIL; never relax the assertion).

---

## C67-FOOTER — deterministic © year (§11.4.216 / §11.4.65)

**Claim.** The footer copyright year is GENERATED (pinned via `-ldflags -X
main.buildYear` on vasic; ephemeral `_config.deploy.yml` on milos Jekyll), never a
hardcoded literal. Identical source ⇒ byte-identical rebuild.

**RUN assertion.** Served `/` on each site matches `© <4-digit> <Brand>` with year ≥ 2026.
**GATE assertion.** Build with `buildYear=2099`; **every** `<footer>…© <year>` reads `© 2099`.
**Golden-BAD.** The pre-fix state: 15 `_content/sites/vasic-digital.home.*.json` carried a hardcoded `"footer": "© 2026 …"`; in a 2099 build those rendered `© 2026` → GATE detector 1 flags any footer year ≠ 2099.

```json
{ "challenge": "C67-FOOTER", "site": "vasic.digital", "verdict": "PASS",
  "live_year": 2026, "sentinel_build_all_2099": true }
```

## C67-BLK1 — localized portfolio card blurbs (§11.4.140/141)

**Claim.** Card blurbs on `/portfolio/<lang>/` come from the localized markdown, not
the EN `portfolio.json`.
**RUN.** `/portfolio/de/` contains "für die freie Welt"; `/portfolio/{de,ru}/` contain 0 of {`self-hostable media collection`, `for the free world`}.
**Golden-BAD.** Pre-fix `portfolioCard` emitted `e.Tagline` (EN) for every lang → EN phrases present on localized pages.

## C67-BLK2 — localized product descriptions (§11.4.140/141)

**Claim.** Product `meta[name=description]`, `og:description`, and JSON-LD
`SoftwareApplication.description` are localized (sourced from the localized markdown).
**RUN.** `/products/{de,ru,ar}/catalogizer.html`: 0 EN summary leak; all three
description slots present and ≥ 20 chars.
**Golden-BAD.** Pre-fix `desc := firstNonEmpty(e.Summary, e.Tagline)` (EN) + `seo.go`
`description = e.Summary` → English meta on 462 localized pages/site.

## C67-HEAD — creative section headings localized

**Claim.** The ~40 creative headings (`prod.head.*`) are data-driven i18n, translated
to 15 langs.
**RUN.** `/products/de/catalogizer.html` contains 0 of the EN heading set.
**Golden-BAD.** Pre-fix headings were hardcoded Go string literals → English on every lang.

## C67-LINUX — brand "Linux" stays Latin

**Claim.** "Linux" (brand) is never transliterated; glossary-protected for future translations.
**RUN.** `/products/{hi,ko,ar,fa}/qemu-utils.html`: 0 transliteration, Latin "Linux" present.
**Golden-BAD.** Pre-fix: 81 transliterations (`लिनक्स`/`리눅스`/`لينكس`/`لینوکس`) across 32 content files.

## C67-PDF — sr cover-letter term

**Claim.** The Serbian cover-letter PDF uses "Пропратно писмо" (cover letter), not the
mistranslation "Пријава" (job application).
**RUN.** `Milos_Vasic_Cover_Letter_SR.pdf` pdftotext contains "Пропратно писмо", 0 "Пријава".
**Golden-BAD.** Pre-fix `sr.cover.eyebrow` = "Пријава".
