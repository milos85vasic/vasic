# i18n review — en (English (source))

| Field | Value |
|---|---|
| Reviewer | independent per-language reviewer (not the generator; HelixTranslate output was the subject) |
| Date | 2026-11-24 |
| Roadmap-Item | VSC-423 |
| Initial verdict | **FIX** (107 rows reviewed; 3 generator-dictionary FIX, 0 milosvasic.ru FIX) |
| Disposition | source fixes applied in `_tools/gen/ui-i18n.en.json` (changes English pages) |
| Verdict after corrections | **GO** for the generator sources (rebuilt; footer/version/link-integrity checks green); milosvasic.ru strings GO once the patch is authorised |

## Summary

The English source is clear, consistent in tone and free of typos. Three real defects: the fallback description template lacks an article, pf.lede uses the slug 'vasic-digital' instead of the brand, and the bare label 'order' is ambiguous (both tr and kk translated it as a purchase order).

## Checks

- **meaning_idiom_register**: Confident, informal-professional register; rotating headings are deliberately idiomatic ('the itch we had to scratch', 'under the hood', 'ideas worth stealing') — valid English, but they drive calques in translation (see spotcheck).
- **script**: Latin; 'Miloš Vasić' diacritics correct.
- **rtl**: n/a
- **plural**: No plural-form strings.
- **date_number**: None present.
- **glossary**: Brands verbatim; pf.lede 'vasic-digital' is the GitHub org slug, inconsistent with 'Vasic Digital' in tier2.title (FIX).
- **footer_length**: footer.suffix 30 chars, footer.version 16 chars; mv footer.text 66 chars (full sentence line).

## Corrections

| Source | Key | Before | After | Rationale |
|---|---|---|---|---|
| generator | `pf.lede` | A unified, evidence-based portfolio of the Helix family, vasic-digital utilities, and the Server Factory toolchain. | A unified, evidence-based portfolio of the Helix family, Vasic Digital utilities, and the Server Factory toolchain. | Uses the slug 'vasic-digital' while tier2.title and the glossary use the brand 'Vasic Digital'; translators diverged (tr used the brand, kk the slug). |
| generator | `prod.order` | order | position | Shown before a numeric sort position (e.Order); bare 'order' is ambiguous and was mistranslated as 'purchase order' in both tr (sipariş) and kk (тапсырыс). If 'order' is kept, add a translator note instead. |
| generator | `prod.desc.fallback` | %s — %s product. | %s — a %s product. | Renders as 'HelixCode — Vasic Digital product.' (Name, Brand): the indefinite article is missing. Placeholders unchanged and in the same order. |

## Items for native-speaker spot-check (non-blocking)

- Coined jargon 'anti-bluff QA', 'captured evidence' and the 'fleet' metaphor in pf.summary / pf.overview.title / prod.head.powers.* need a translator note — both tr and kk calqued them.
- Idiomatic headings (prod.head.whywebuilt.3, gamechanger.*, techstack.2) benefit from a translator note on intended meaning.
- aria.primaryNav 'Primary' relies on the screen reader appending 'navigation'; fine in English, confirm translations read sensibly the same way.

## Evidence

Footer screenshots (local build from the fixed sources, Playwright chromium, not deployed):

- vasic.digital: [375px](screenshots/en-vd-375.png), [768px](screenshots/en-vd-768.png), [1280px](screenshots/en-vd-1280.png)
- milosvasic.ru: [375px](screenshots/en-mv-375.png), [768px](screenshots/en-mv-768.png), [1280px](screenshots/en-mv-1280.png)

Render results: [render-results.json](render-results.json). Run log: [RUN-LOG.md](RUN-LOG.md).
