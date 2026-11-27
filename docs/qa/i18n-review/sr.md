# i18n review — sr (Serbian (Cyrillic))

| Field | Value |
|---|---|
| Reviewer | independent per-language reviewer (not the generator; HelixTranslate output was the subject) |
| Date | 2026-11-24 |
| Roadmap-Item | VSC-423 |
| Initial verdict | **FIX** (107 rows reviewed; 22 generator-dictionary FIX, 1 milosvasic.ru FIX) |
| Disposition | generator-dictionary fixes APPLIED in umbrella source (`_tools/gen/ui-i18n.sr.json`); milosvasic.ru fixes (1) staged as a patch awaiting operator authorisation |
| Verdict after corrections | **GO** for the generator sources (rebuilt; footer/version/link-integrity checks green); milosvasic.ru strings GO once the patch is authorised |

## Summary

Cyrillic script is correct, but the Serbian set has the most defects: gender errors with 'портфолио' (masculine), a mistransliterated Cyrillic brand name ('Васиц Дигитал'), a broken pf.summary, several literal or ungrammatical headings, 'отворени извор' calques in keywords, inconsistent 'продукт'/'производ' terminology, and English city names in the footer.

## Checks

- **meaning_idiom_register**: Many headings are word-for-word calques (whywebuilt.0/.3, gamechanger.1, innovative.0, challenges.1/.2, status.0/.1/.name); pf.lede 'доказано' changes the meaning (proven, not evidence-based). Register otherwise professional.
- **script**: Cyrillic only, as required, apart from protected Latin terms. Defects: 'Belgrade · Dubna' left in Latin English; 'Vasic Digital' wrongly transliterated to Cyrillic in alt.brandLogo (it must stay Latin).
- **rtl**: n/a
- **plural**: No plural-bearing keys; confirmed none.
- **date_number**: None present; confirmed. 'Верзија сајта: v2.0.0' — correct colon spacing.
- **glossary**: Constitution (Устав), Miloš Vasić (Милоша Васића) and Vasic Digital (Васиц Дигитал) were localized; Vasic Digital is a clear defect, the other two are fixed per the binding glossary (see spotcheck for the name).
- **footer_length**: footer.suffix 30 chars, footer.version 14 — OK. mv footer.text ~72 chars — long by nature (source 68).

## Corrections

| Source | Key | Before | After | Rationale |
|---|---|---|---|---|
| generator | `nav.products` | Продукти | Производи | Terminology consistency: the same dictionary uses 'производ' (prod.desc.fallback, prod.head.powers.name); 'Производи' is the standard Serbian form. |
| generator | `pf.eyebrow` | уједињено портфолио | обједињени портфолио | 'портфолио' is masculine in Serbian (neuter 'уједињено' is a gender error); 'уједињен' means 'united' (as of nations), 'обједињен' is 'unified'. |
| generator | `pf.download` | Преузми Портфолио (PDF) | Преузми портфолио (PDF) | Common noun must be lowercase mid-phrase; title-case carried over from English. |
| generator | `pf.stat.products` | Продукти | Производи | Consistency with nav.products / 'производ' elsewhere. |
| generator | `pf.stat.helix` | Helix продукти | Helix производи | Consistency with 'производ' elsewhere. |
| generator | `pf.lede` | Уједињено, доказано портфолио Helix породице, Vasic Digital алатки и Server Factory алатног ланца. | Обједињени портфолио, заснован на доказима, који обухвата Helix породицу, Vasic Digital алатке и Server Factory скуп алата. | Gender error (портфолио is masculine); 'доказано' means 'proven', not 'evidence-based'; 'алатног ланца' is a calque. |
| generator | `pf.summary` | Једна флота: велике апликације на врху десетина малих, одвојених, независно тестираних модула — управљаних заједничким инжењерским Уставом и провереним анти-блеф QA. Доминантни језик је Go, са Kotlin/KMP, TypeScript/React, Python, Swift, и Shell где најбоље одговарају. Уједињујућа теза: функција је завршена само када је стварни корисник може да је користи и постоји ухваћен доказ да је то тако. | Једна флота: велике производне апликације изграђене над десетинама малих, раздвојених, независно тестираних модула — којима управља заједнички инжењерски устав (Constitution) и које проверава анти-блеф QA. Доминантни језик је Go, уз Kotlin/KMP, TypeScript/React, Python, Swift и Shell тамо где најбоље одговарају. Обједињујућа теза: функционалност је завршена тек када стварни корисник може да је користи и када постоји забележен доказ за то. | 'на врху' = 'at the summit' (calque of 'on top of'); case error 'провереним анти-блеф QA'; broken clause 'када је стварни корисник може да је користи'; 'ухваћен доказ' calque; glossary Constitution verbatim. |
| generator | `kw.vasic` | инжењеринг софтвера, платформе за развој AI, LLM оркестрација, отворени извор, алатке за програмере, SDK | софтверски инжењеринг, платформе за развој AI, LLM оркестрација, отворени код, алати за програмере, SDK | 'отворени извор' is a calque of 'open source' (Serbian: 'отворени код'); 'софтверски инжењеринг' is the standard search term. |
| generator | `kw.milos` | инжењер платформе, специјалиста за SDK, Kotlin, Go, архитектура софтвера, дистрибуирани системи, отворени извор | платформски инжењер, специјалиста за SDK, Kotlin, Go, софтверска архитектура, дистрибуирани системи, отворени код | 'отворени извор' calque; 'платформски инжењер' / 'софтверска архитектура' are the natural terms. |
| generator | `prod.head.whywebuilt.0` | Проблем који смо се латили да решимо | Проблем који смо кренули да решимо | 'латити се' governs the genitive, so 'који смо се латили' is ungrammatical. |
| generator | `prod.head.whywebuilt.3` | Сврбеж који смо морали да огребемо | Проблем који нам није давао мира | 'Сврбеж који смо морали да огребемо' is a literal, unnatural rendering of the English idiom. |
| generator | `prod.head.gamechanger.1` | Скок који пружа | Искорак који доноси | 'Скок који пружа' is awkward ('a jump that it provides'). |
| generator | `prod.head.innovative.0` | Где живи новина | У чему је новина | 'Где живи новина' is a calque; not idiomatic as a heading. |
| generator | `prod.head.challenges.1` | Тешки делови — и поправке | Тешкоће — и како смо их решили | 'Тешки делови — и поправке' is a literal calque, reads like a repair list. |
| generator | `prod.head.challenges.2` | Инжењеринг тешких сегмената | Инжењерска решења тешких задатака | 'Инжењеринг тешких сегмената' is a calque with no clear meaning. |
| generator | `prod.head.status.0` | Статус, речено отворено | Статус без увијања | 'Статус, речено отворено' is a word-for-word rendering; unnatural as a heading. |
| generator | `prod.head.status.1` | Где стварно стоји | Право стање ствари | 'Где стварно стоји' reads as 'where it physically stands'. |
| generator | `prod.head.status.name` | Статус и белешке о искрености | Статус и искрене напомене | 'белешке о искрености' means 'notes about honesty' (meaning shift). |
| generator | `prod.desc.fallback` | %s — %s производ. | %s — производ %s. | English word order ('Vasic Digital производ'); Serbian needs 'производ <brand>'. Placeholder order preserved. |
| generator | `alt.portrait` | Портрет Милоша Васића | Miloš Vasić — портрет | Glossary requires the name verbatim (Latin). Owner decision: see spotcheck — 'Портрет Милоша Васића' is the natural Serbian Cyrillic form. |
| generator | `alt.brandLogo` | Логотип Васиц Дигитал | Логотип Vasic Digital | Brand name must stay Latin verbatim; 'Васиц Дигитал' is also a wrong transliteration (c→ц). |
| generator | `status.roadmap` | На плану | У плану | The idiom for 'planned' is 'у плану'; 'на плану' means 'on the (drawn) plan/map'. |
| milosvasic.ru | `footer.text` | Belgrade · Dubna. Изграђено као статички сајт, објављено на GitHub Pages. | Београд · Дубна. Изграђено као статички сајт, објављено на GitHub Pages. | City names left in English Latin inside the Cyrillic-only Serbian site; not glossary terms. |

## Glossary audit judgements (`_tools/gen/audit_ui_glossary.py`)

- `pf.summary` / Constitution: REAL defect, fixed — Rendered as 'Уставом' (which also means state constitution); fixed with verbatim term in parentheses.
- `alt.portrait` / Miloš Vasić: REAL defect, fixed — Per the binding glossary it is a violation, though 'Милоша Васића' is the correct native Serbian form of the owner's own name — owner decision flagged.
- `alt.brandLogo` / Vasic Digital: REAL defect, fixed — Brand transliterated (and mis-transliterated, c→ц) as 'Васиц Дигитал'; must stay Latin.

## Items for native-speaker spot-check (non-blocking)

- alt.portrait: your own name — the glossary forces Latin 'Miloš Vasić'; the natural Serbian Cyrillic is 'Портрет Милоша Васића'. Decide and amend the glossary if you prefer Cyrillic.
- nav.products: 'Производи' (proposed, standard) vs 'Продукти' (original) — pick one and keep prod.desc.fallback / powers.name consistent.
- status.production 'У продукцији' kept as accepted IT jargon — confirm, or use 'У употреби'.
- tier1.eyebrow 'заставни брод' (kept) vs 'водећи производи'.
- pf.summary: 'устав (Constitution)' — 'устав' collides with the state constitution; consider 'правилник'/'кодекс' + (Constitution) if you prefer.
- skip 'Прескочи до садржаја' vs mv a11y.skip 'Пређи на садржај' — two different wordings across the two sites; harmonise if you like.
- tier1.title uses '&' ('Helix породица & LLM инфраструктура') — 'и' would match ru/be.

## Evidence

Footer screenshots (local build from the fixed sources, Playwright chromium, not deployed):

- vasic.digital: [375px](screenshots/sr-vd-375.png), [768px](screenshots/sr-vd-768.png), [1280px](screenshots/sr-vd-1280.png)
- milosvasic.ru: [375px](screenshots/sr-mv-375.png), [768px](screenshots/sr-mv-768.png), [1280px](screenshots/sr-mv-1280.png)

Render results: [render-results.json](render-results.json). Run log: [RUN-LOG.md](RUN-LOG.md).
