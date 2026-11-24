# i18n review — fr (French)

| Field | Value |
|---|---|
| Reviewer | independent per-language reviewer (not the generator; HelixTranslate output was the subject) |
| Date | 2026-11-24 |
| Roadmap-Item | VSC-423 |
| Initial verdict | **FIX** (107 rows reviewed; 6 generator-dictionary FIX, 0 milosvasic.ru FIX) |
| Disposition | generator-dictionary fixes APPLIED in umbrella source (`_tools/gen/ui-i18n.fr.json`); no milosvasic.ru change needed |
| Verdict after corrections | **GO** for the generator sources (rebuilt; footer/version/link-integrity checks green); milosvasic.ru strings GO once the patch is authorised |

## Summary

French is good overall, with correct NBSP before ':' in footer.version. Real defects: pf.summary lacks mandatory elision (lorsqu'un) and NBSP before colons and uses 'un QA'; 'commande' mistranslates order; wrong word order in the %s fallback and logo alt; 'IA' instead of verbatim 'AI'; a calque heading.

## Checks

- **meaning_idiom_register**: Professional, vous consistent. Defects: 'commande', calque heading, word order in two keys.
- **script**: Latin, accents correct; straight and curly apostrophes mixed (typographic, not blocking).
- **rtl**: n/a
- **plural**: No plural-bearing keys. Confirmed.
- **date_number**: None present. Confirmed. footer.version uses U+00A0 before ':', correct.
- **glossary**: One real violation (IA → AI). Constitution, brands and products verbatim.
- **footer_length**: footer.suffix 35 chars OK; mv footer.text about 75 chars (EN 66), wraps like EN.

## Corrections

| Source | Key | Before | After | Rationale |
|---|---|---|---|---|
| generator | `pf.summary` | Une flotte : de grandes applications de produits basées sur des dizaines de petits modules découplés, indépendamment testés — gouvernés par une Constitution d'ingénierie partagée et vérifiés par un QA anti-bluff. Le langage dominant est Go, avec Kotlin/KMP, TypeScript/React, Python, Swift et Shell là où ils conviennent le mieux. La thèse unificatrice : une fonctionnalité n'est terminée que lorsque un utilisateur réel peut l'utiliser et qu'il existe des preuves capturées pour le prouver. | Une flotte : de grandes applications produit reposant sur des dizaines de petits modules découplés et testés indépendamment — le tout régi par une Constitution d'ingénierie commune et vérifié par une QA anti-bluff. Le langage dominant est Go, avec Kotlin/KMP, TypeScript/React, Python, Swift et Shell là où ils conviennent le mieux. La thèse unificatrice : une fonctionnalité n'est terminée que lorsqu'un utilisateur réel peut l'utiliser et que des preuves recueillies l'attestent. | Missing mandatory elision 'lorsque un' → 'lorsqu'un'; regular spaces before ':' (needs NBSP); 'un QA' (QA is feminine); redundant 'preuves ... prouver'; agreement of 'gouvernés'. |
| generator | `prod.order` | commande | ordre | 'commande' means a purchase order; sort/sequence order is 'ordre'. |
| generator | `kw.vasic` | ingénierie logicielle, plateformes de développement d'IA, orchestration LLM, open source, outils de développement, SDK | ingénierie logicielle, plateformes de développement AI, orchestration LLM, open source, outils de développement, SDK | Glossary: 'AI' must appear verbatim (was localized to 'IA'). |
| generator | `prod.head.whywebuilt.3` | La démangeaison qu’il nous fallait gratter | Le besoin qu'il nous fallait combler | Literal calque of 'itch to scratch' ('démangeaison ... gratter') is not idiomatic French. |
| generator | `prod.desc.fallback` | %s — %s produit. | %s — produit %s. | French word order: noun before its modifier ('produit Helix'), not '%s produit'; placeholders kept in order. |
| generator | `alt.brandLogo` | Vasic Digital logo | Logo de Vasic Digital | English word order; French is 'Logo de Vasic Digital'. |

## Glossary audit judgements (`_tools/gen/audit_ui_glossary.py`)

- `kw.vasic` / AI: REAL defect, fixed — Localized to 'IA'; glossary requires 'AI' verbatim. A French searcher types 'IA', so the owner may want to exempt kw.* (policy decision, not a linguistic error).

## Items for native-speaker spot-check (non-blocking)

- Mixed straight (') and curly (’) apostrophes across keys: normalize.
- Dubna: French spelling is usually 'Doubna'.
- gen footer.version 'Version du site web :' vs mv 'Version du site :': harmonize if wanted.
- 'stack technique' anglicism (vs 'pile technologique'), common in French tech.
- kw.vasic: confirm the policy of 'AI' vs 'IA' in SEO keywords.

## Evidence

Footer screenshots (local build from the fixed sources, Playwright chromium, not deployed):

- vasic.digital: [375px](screenshots/fr-vd-375.png), [768px](screenshots/fr-vd-768.png), [1280px](screenshots/fr-vd-1280.png)
- milosvasic.ru: [375px](screenshots/fr-mv-375.png), [768px](screenshots/fr-mv-768.png), [1280px](screenshots/fr-mv-1280.png)

Render results: [render-results.json](render-results.json). Run log: [RUN-LOG.md](RUN-LOG.md).
