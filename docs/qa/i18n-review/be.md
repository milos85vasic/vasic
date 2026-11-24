# i18n review — be (Belarusian)

| Field | Value |
|---|---|
| Reviewer | independent per-language reviewer (not the generator; HelixTranslate output was the subject) |
| Date | 2026-11-24 |
| Roadmap-Item | VSC-423 |
| Initial verdict | **FIX** (107 rows reviewed; 19 generator-dictionary FIX, 4 milosvasic.ru FIX) |
| Disposition | generator-dictionary fixes APPLIED in umbrella source (`_tools/gen/ui-i18n.be.json`); milosvasic.ru fixes (4) staged as a patch awaiting operator authorisation |
| Verdict after corrections | **GO** for the generator sources (rebuilt; footer/version/link-integrity checks green); milosvasic.ru strings GO once the patch is authorised |

## Summary

Belarusian orthography is mostly correct (ў, і, ' used properly), but there are real defects: a wrong word in 'Часткі статус' (partial instead of honest), gender mismatches (footer.suffix, aria.primaryNav), Russianisms and a misspelt participle in pf.summary, inconsistent 'флот'/'сістэмы' terminology, 'Праца'/'Экспертыза' calques in nav, 'у вытворчасці' for production, English city names and glossary violations.

## Checks

- **meaning_idiom_register**: FIX for status.2 (meaning error), status.3 (meaning shift), whywebuilt.0/.3, gamechanger.0/.1, nav.work, nav.expertise, prod.source, status.production.
- **script**: Belarusian Cyrillic orthography respected (ў, і, apostrophe); no Russian spellings found apart from the lexical Russianism 'прыкладанні' and 'завяршана' (be: завершаны). 'Belgrade · Dubna' left in Latin English.
- **rtl**: n/a
- **plural**: No plural-bearing keys; confirmed none.
- **date_number**: None present; confirmed. 'Версія сайта: v2.0.0' correct.
- **glossary**: Constitution (Канстытуцыяй) and Miloš Vasić (Мілаша Васіча) were localized; fixed with verbatim term. AI kept verbatim in kw.vasic. Brands preserved.
- **footer_length**: footer.suffix 32 chars, footer.version 13 — OK. mv footer.text ~71 chars — long by nature.

## Corrections

| Source | Key | Before | After | Rationale |
|---|---|---|---|---|
| generator | `skip` | Прапусціце да зместу | Перайсці да зместу | 'Прапусціце да зместу' is a calque of 'skip to' and switches to plural imperative while all other labels are infinitives; matches mv a11y.skip wording. |
| generator | `footer.suffix` | пабудавана на сістэме OpenDesign | пабудаваны на сістэме OpenDesign | Feminine 'пабудавана' has no antecedent; the implied subject is the site (сайт, masculine). |
| generator | `pf.download` | Спампаваць Партфоліа (PDF) | Спампаваць партфоліа (PDF) | Common noun must be lowercase mid-phrase. |
| generator | `pf.lede` | Аб'яднанае, заснаванае на доказах партфоліа сям'і Helix, утыліт Vasic Digital, і інструментальнага ланцуга Server Factory. | Аб'яднанае, заснаванае на доказах партфоліа сям'і Helix, утыліт Vasic Digital і інструментарыю Server Factory. | Comma before 'і' in a simple enumeration is a punctuation error in Belarusian; 'інструментальнага ланцуга' is a calque. |
| generator | `pf.summary` | Адзін флот: буйныя прыкладанні прадуктаў на базе дзясяткаў малых, аддзеленых, незалежна тэставаных модуляў — кіруемых агульнай інжынернай Канстытуцыяй і верыфікаваных анты-блэфавай QA. Дамінуючая мова — Go, з Kotlin/KMP, TypeScript/React, Python, Swift, і Shell, дзе яны лепш за ўсё падыходзяць. Аб'ядноўваючая тэза: функцыя завяршана толькі тады, калі рэальны карыстальнік можа яе выкарыстоўваць, і ёсць захаваны доказ, які яе пацвярджае. | Адзін флот: буйныя прадуктовыя праграмы на базе дзясяткаў невялікіх, слаба звязаных, незалежна пратэставаных модуляў — пад кіраваннем агульнай інжынернай канстытуцыі (Constitution) і з праверкай праз анты-блеф QA. Асноўная мова — Go, а Kotlin/KMP, TypeScript/React, Python, Swift і Shell выкарыстоўваюцца там, дзе яны падыходзяць найлепш. Асноўная тэза: функцыя лічыцца гатовай толькі тады, калі рэальны карыстальнік можа ёю карыстацца і ёсць зафіксаваны доказ гэтага. | Misspelt participle 'завяршана' (be: завершаны); Russianism 'прыкладанні'; comma before 'і'; glossary Constitution verbatim. |
| generator | `prod.source` | Крыніца | Зыходны код | Heading over the source-repository list; 'Крыніца' means 'source of information'. |
| generator | `aria.primaryNav` | Асноўнае | Асноўная навігацыя | Neuter 'Асноўнае' agrees with nothing; navigation (навігацыя) is feminine. |
| generator | `nav.work` | Праца | Праекты | 'Праца' means job/labour; portfolio 'Work' = projects (ru uses 'Проекты'). |
| generator | `prod.head.whywebuilt.0` | Праблема, якую мы паставілі перад сабой вырашыць | Праблема, якую мы ўзяліся вырашыць | 'паставілі перад сабой вырашыць' is ungrammatical. |
| generator | `prod.head.whywebuilt.3` | Свёрб, які трэба было пачасаць | Задача, якая не давала нам спакою | Literal 'Свёрб, які трэба было пачасаць' is unnatural. |
| generator | `prod.head.gamechanger.0` | Чаму гэта мяняе правілы гульні | Чаму гэта змяняе правілы гульні | In Belarusian 'мяняць' primarily means 'to exchange'; the idiom uses 'змяняць'. |
| generator | `prod.head.gamechanger.1` | Які крок яно забяспечвае | Якасны скачок | 'Які крок яно забяспечвае' is awkward and weakens 'leap'. |
| generator | `prod.head.status.2` | Часткі статус | Шчыры статус | 'Часткі статус' means 'partial status' — meaning error (honest → шчыры). |
| generator | `prod.head.status.3` | Статус без лішніх слоў | Статус без прыхарошвання | 'без лішніх слоў' means 'concisely', not 'no spin'. |
| generator | `prod.head.powers.1` | Што яно дае ўсім сістэмам | Што яно дае ўсяму флоту | 'fleet' rendered as 'сістэмы' here but 'флот' in pf.overview.title/pf.summary — inconsistent terminology. |
| generator | `prod.head.powers.2` | Як сістэмы абапіраюцца на яго | Як флот абапіраецца на яго | Same terminology inconsistency (сістэмы vs флот). |
| generator | `prod.desc.fallback` | %s — %s прадукт. | %s — прадукт %s. | English word order; Belarusian needs 'прадукт <brand>'. Placeholder order preserved. |
| generator | `alt.portrait` | Партрэт Мілаша Васіча | Miloš Vasić — партрэт | Glossary requires the name verbatim (Latin). |
| generator | `status.production` | у вытворчасці | у эксплуатацыі | 'у вытворчасці' means 'being manufactured'. |
| milosvasic.ru | `nav.expertise` | Экспертыза | Кампетэнцыі | 'Экспертыза' means expert examination/appraisal, not a person's expertise. |
| milosvasic.ru | `nav.work` | Праца | Праекты | 'Праца' means job/labour; consistency with gen nav.work. |
| milosvasic.ru | `footer.text` | Belgrade · Dubna. Зроблена як статычны сайт, разгорнута на GitHub Pages. | Бялград · Дубна. Зроблена як статычны сайт, разгорнута на GitHub Pages. | City names left in English Latin inside a Cyrillic sentence; Belarusian forms are Бялград, Дубна. |
| milosvasic.ru | `aria.primaryNav` | Асноўнае | Асноўная навігацыя | Neuter 'Асноўнае' agrees with nothing; consistency with gen aria.primaryNav. |

## Glossary audit judgements (`_tools/gen/audit_ui_glossary.py`)

- `pf.summary` / Constitution: REAL defect, fixed — Rendered as 'Канстытуцыяй'; fixed with verbatim term in parentheses.
- `alt.portrait` / Miloš Vasić: REAL defect, fixed — Transliterated 'Мілаша Васіча'; glossary requires verbatim Latin.

## Items for native-speaker spot-check (non-blocking)

- A Belarusian native should confirm pf.summary wording ('слаба звязаных', 'анты-блеф QA', 'канстытуцыі (Constitution)').
- prod.head.innovative.3 'Ідэі, якія варта скрасці' kept (playful, as in English) — confirm register.
- status.roadmap 'у плане' kept; 'у планах' is arguably more natural.
- Footer: 'Бялград' is the standard Belarusian name of Belgrade — confirm.
- prod.head.gamechanger.name 'Чаму гэта пераломны момант' kept.

## Evidence

Footer screenshots (local build from the fixed sources, Playwright chromium, not deployed):

- vasic.digital: [375px](screenshots/be-vd-375.png), [768px](screenshots/be-vd-768.png), [1280px](screenshots/be-vd-1280.png)
- milosvasic.ru: [375px](screenshots/be-mv-375.png), [768px](screenshots/be-mv-768.png), [1280px](screenshots/be-mv-1280.png)

Render results: [render-results.json](render-results.json). Run log: [RUN-LOG.md](RUN-LOG.md).
