# PDF translation audit (#65) — 15 langs × {CV, Cover-Letter, Portfolio}

Method: `pdftotext -enc UTF-8` on every committed PDF, measuring (a) target-script
ratio for non-Latin languages and (b) presence of hardcoded-English chrome strings.
Full per-file table: `pdf-audit-matrix.txt`.

## PASS / GAP matrix (45 personal PDFs; company Portfolio mirrors personal Portfolio)

| Lang | script | CV | Cover-Letter | Portfolio |
|------|--------|----|----|----|
| EN | latin | PASS | PASS | PASS |
| DE ES FR TR | latin | GAP-chrome | GAP-chrome | GAP-chrome |
| RU BE KK | cyrillic (body 0.71–0.78) | GAP-chrome | GAP-chrome | GAP-chrome |
| AR FA | arabic (body 0.69–0.75) | GAP-chrome | GAP-chrome | GAP-chrome |
| HI | devanagari (0.70–0.78) | GAP-chrome | GAP-chrome | GAP-chrome |
| JA KO ZH | cjk (0.44–0.66) | GAP-chrome | GAP-chrome | GAP-chrome |
| SR (committed, stale) | cyrillic 0.000 | FAIL→FIXED | FAIL→FIXED | FAIL→FIXED |

- **Document BODY** is correctly translated + correct-script for ALL 14 non-EN
  languages (every `_content_<lang>/docs/{cv,cover-letter,portfolio}.md` exists —
  no EN fallback is triggered). Body script ratios clear their thresholds.
- **SR** was the only script FAILURE: the committed SR PDFs were built from the old
  Latin content (cyrillic ratio 0.000). After this task's content fix, a rebuild
  yields 0.72 / 0.77 / 0.74 (see `sr-pdf-rebuild-verification.txt`). The maintainer's
  regen will ship correct Cyrillic SR PDFs. **No further SR PDF action needed.**
- **GAP-chrome** = the ONLY remaining leak for the 13 other non-EN languages. It is
  NOT in the translated body — it is the PDF "chrome" hardcoded in
  `_tools/pdf/build-pdfs.sh` (cover page + metrics strip + Portfolio figures), which
  is emitted in English for every language.

## Genuine content gap: hardcoded English chrome in build-pdfs.sh (#65)

These strings are literal English in the script and appear on every language's PDF.
They are NOT sourced from `_content_<lang>` nor from `ui-i18n.*.json` (verified: the
UI i18n set has no equivalent keys), so localizing them requires NEW translations.

CV cover/header/metrics:
- eyebrow / running header: `Curriculum Vitae`
- role: `AI Engineer · Software Engineer`
- tagline: `LLM infrastructure, autonomous agents, and the governance that makes them trustworthy. Fleets over monoliths; anti-bluff, evidence-gated quality.`
- metric labels: `Engineering since`, `Repositories governed`, `LLM providers unified`, `Core languages`

Cover-Letter cover/header:
- eyebrow / running header: `Cover Letter`
- role: `Cover Letter · AI Engineer`
- tagline: `Deep AI-systems engineering paired with a genuine, verifiable quality discipline.`

Portfolio cover/header/metrics/figures:
- eyebrow: `Vasic Digital · Evidence-Based Portfolio`
- role (personal): `Portfolio · Helix family · vasic-digital · Server Factory`
- role (company): `AI-native software engineering · Evidence-based portfolio`
- running header: `Portfolio`
- taglines (personal + company variants) — 2 long marketing sentences
- metric labels: `Repository fleet`, `LLM providers`, `Linux distros provisioned`, `Passing tests · Mail Server Factory`
- figures heading: `Selected architecture`
- 3 figure captions (HelixAgent / HelixCluster / LLMsVerifier) — dense technical prose

Also emitted in a Latin-safe font regardless of language.

## Recommended fix (flagged for the translation pipeline — NOT fabricated here)

Per the Constitution translation mandate (container-only HelixTranslate + independent
review; anti-bluff §11.4.6), these ~20 bespoke marketing/technical strings must be
translated through the pipeline, not hand-invented. Suggested structural change for
the maintainer:

1. Externalize the chrome strings from `build-pdfs.sh` into a per-language table
   (e.g. `_tools/pdf/pdf-i18n.json`, keyed `<lang>.<field>`), EN populated from the
   current literals.
2. Run the strings through HelixTranslate (protected terms already covered by
   `glossary.json`) + `review_translation.py` per language.
3. Have `build_html`/`build()` look up `<lang>` with EN fallback.

Scope note: fixing this correctly is a translation-pipeline deliverable spanning 13
languages; it is out of scope for a no-fabrication content pass and is flagged here
with the exact string inventory so it can be executed cleanly.
