# i18n review — es (Spanish)

| Field | Value |
|---|---|
| Reviewer | independent per-language reviewer (not the generator; HelixTranslate output was the subject) |
| Date | 2026-11-24 |
| Roadmap-Item | VSC-423 |
| Initial verdict | **FIX** (107 rows reviewed; 8 generator-dictionary FIX, 1 milosvasic.ru FIX) |
| Disposition | generator-dictionary fixes APPLIED in umbrella source (`_tools/gen/ui-i18n.es.json`); milosvasic.ru fixes (1) staged as a patch awaiting operator authorisation |
| Verdict after corrections | **GO** for the generator sources (rebuilt; footer/version/link-integrity checks green); milosvasic.ru strings GO once the patch is authorised |

## Summary

Spanish is mostly sound and natural. Real defects: glossary violations ('Constitución', 'inteligencia artificial'), calques ('comezón que rascar', 'cambio de juego'), 'herencia' for heritage, a wrong capital in the %s fallback, and the untranslated exonym 'Belgrade'. Register (tú) is consistent.

## Checks

- **meaning_idiom_register**: Professional-neutral, tú consistent. Defects: calques in two headings, herencia, notas de honestidad.
- **script**: Latin, accents correct.
- **rtl**: n/a
- **plural**: No plural-bearing keys. Confirmed.
- **date_number**: None present. Confirmed.
- **glossary**: Two real violations (Constitution, AI). Brands and products otherwise verbatim.
- **footer_length**: footer.suffix 37 chars OK; mv footer.text about 77 chars (EN 66), wraps like EN.

## Corrections

| Source | Key | Before | After | Rationale |
|---|---|---|---|---|
| generator | `pf.download` | Descargar Portafolio (PDF) | Descargar portafolio (PDF) | Spanish does not title-case common nouns mid-label. |
| generator | `pf.summary` | Una flota: grandes aplicaciones de productos sobre decenas de módulos pequeños, desacoplados, probados de forma independiente — gobernados por una Constitución de ingeniería compartida y verificados por QA anti-engaño. El lenguaje dominante es Go, con Kotlin/KMP, TypeScript/React, Python, Swift y Shell donde mejor se adapten. La tesis unificadora: una característica está terminada solo cuando un usuario real puede usarla y hay evidencia capturada para probarlo. | Una flota: grandes aplicaciones de producto sobre decenas de módulos pequeños, desacoplados y probados de forma independiente, todo ello regido por una Constitution de ingeniería compartida y verificado mediante QA anti-engaño. El lenguaje dominante es Go, con Kotlin/KMP, TypeScript/React, Python, Swift y Shell donde mejor encajan. La tesis unificadora: una funcionalidad está terminada solo cuando un usuario real puede usarla y hay evidencia capturada que lo demuestra. | Glossary violation: 'Constitución' must stay 'Constitution'; 'gobernados' wrongly agrees with 'módulos'; 'funcionalidad' is the standard software term for feature. |
| generator | `tier3.eyebrow` | nivel 3 — herencia | nivel 3 — legado | 'herencia' means inheritance; 'heritage' (legacy line) is 'legado'. |
| generator | `kw.vasic` | ingeniería de software, plataformas de desarrollo de inteligencia artificial, orquestación LLM, código abierto, herramientas para desarrolladores, SDK | ingeniería de software, plataformas de desarrollo de AI, orquestación LLM, código abierto, herramientas para desarrolladores, SDK | Glossary: 'AI' must appear verbatim ('inteligencia artificial' replaced it). |
| generator | `prod.head.whywebuilt.3` | La comezón que teníamos que rascar | El problema que nos quitaba el sueño | Literal calque of 'itch to scratch' ('comezón ... rascar') is not idiomatic Spanish. |
| generator | `prod.head.gamechanger.name` | Por qué es un cambio de juego | Por qué marca un antes y un después | 'cambio de juego' is a calque; idiomatic equivalent (not reusing gamechanger.0). |
| generator | `prod.head.status.name` | Estado y notas de honestidad | Estado y notas de transparencia | 'notas de honestidad' is awkward; 'transparencia' is the natural register. |
| generator | `prod.desc.fallback` | %s — Producto %s. | %s — producto %s. | Capital 'Producto' mid-sentence after a dash is wrong; placeholders kept in order. |
| milosvasic.ru | `footer.text` | Belgrade · Dubna. Construido como sitio estático, desplegado en GitHub Pages. | Belgrado · Dubna. Construido como sitio estático, desplegado en GitHub Pages. | English exonym 'Belgrade' left untranslated; Spanish is 'Belgrado'. |

## Glossary audit judgements (`_tools/gen/audit_ui_glossary.py`)

- `pf.summary` / Constitution: REAL defect, fixed — Localized to 'Constitución'; glossary requires 'Constitution' verbatim (fixed in proposal).
- `kw.vasic` / AI: REAL defect, fixed — Replaced by 'inteligencia artificial'; glossary requires 'AI' verbatim. Whether SEO keywords should also add 'IA' is a policy call for the owner.

## Items for native-speaker spot-check (non-blocking)

- Portafolio (LatAm) vs Portfolio (Spain): pick the target variant.
- prod.source 'Fuente': if it links to a repo, 'Código fuente' is clearer.
- 'QA anti-engaño' as the rendering of 'anti-bluff QA'.
- 'Ideas dignas de robar': is the playful tone acceptable?
- Dubna: Spanish sources also spell it 'Dubná'.

## Evidence

Footer screenshots (local build from the fixed sources, Playwright chromium, not deployed):

- vasic.digital: [375px](screenshots/es-vd-375.png), [768px](screenshots/es-vd-768.png), [1280px](screenshots/es-vd-1280.png)
- milosvasic.ru: [375px](screenshots/es-mv-375.png), [768px](screenshots/es-mv-768.png), [1280px](screenshots/es-mv-1280.png)

Render results: [render-results.json](render-results.json). Run log: [RUN-LOG.md](RUN-LOG.md).
