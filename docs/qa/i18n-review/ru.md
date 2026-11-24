# i18n review — ru (Russian)

| Field | Value |
|---|---|
| Reviewer | independent per-language reviewer (not the generator; HelixTranslate output was the subject) |
| Date | 2026-11-24 |
| Roadmap-Item | VSC-423 |
| Initial verdict | **FIX** (107 rows reviewed; 13 generator-dictionary FIX, 2 milosvasic.ru FIX) |
| Disposition | generator-dictionary fixes APPLIED in umbrella source (`_tools/gen/ui-i18n.ru.json`); milosvasic.ru fixes (2) staged as a patch awaiting operator authorisation |
| Verdict after corrections | **GO** for the generator sources (rebuilt; footer/version/link-integrity checks green); milosvasic.ru strings GO once the patch is authorised |

## Summary

Mostly solid professional Russian, but there are real defects: a grammatical gender error and calques in pf.summary, two meaning errors in product-page labels ('заказ' for sort order, 'в производстве' for production status), ungrammatical/literal headings, 'Экспертиза' for Expertise, English city names in the footer, and three glossary-verbatim violations (Constitution, AI, Miloš Vasić).

## Checks

- **meaning_idiom_register**: Register is professional-neutral overall; FIX for meaning errors (prod.order, status.production, nav.expertise, prod.source) and broken idiom headings (whywebuilt.0/.3, challenges.2, gamechanger.name).
- **script**: Cyrillic throughout except protected Latin terms; defect: 'Belgrade · Dubna' left in English in mv footer.text.
- **rtl**: n/a
- **plural**: No plural-bearing keys; lists only (kw.*, pf.summary enumeration) — confirmed none.
- **date_number**: No dates or numbers in these strings (version number v2.0.0 is appended outside); confirmed none. 'Версия сайта: v2.0.0' — no space before colon, correct for Russian.
- **glossary**: Constitution, AI and Miloš Vasić were localized; fixed with verbatim term. Brand/product names (Helix, Vasic Digital, Server Factory, OpenDesign, GitHub Pages) preserved. Mixed ё usage (даёт/развёрнутое vs темную/распределенные) is optional in Russian and not churned.
- **footer_length**: footer.suffix 37 chars, footer.version 13 — OK. mv footer.text ~70 chars (source is 68) — long by nature; acceptable if the footer wraps.

## Corrections

| Source | Key | Before | After | Rationale |
|---|---|---|---|---|
| generator | `pf.download` | Скачать Портфолио (PDF) | Скачать портфолио (PDF) | Common noun must be lowercase mid-phrase in Russian; capitalised 'Портфолио' is English title-case carried over. |
| generator | `pf.summary` | Один флот: крупные приложения на основе десятков небольших, декуплированных, независимо протестированных модулей — управляемых общей инженерной Конституцией и подтвержденных анти-блеф QA. Основным языком является Go, с Kotlin/KMP, TypeScript/React, Python, Swift и Shell там, где они лучше всего подходят. Объединяющая тезис: функция считается выполненной только тогда, когда ее может использовать реальный пользователь и есть доказательства, подтверждающие это. | Один флот: крупные продуктовые приложения поверх десятков небольших, слабосвязанных, независимо протестированных модулей — под управлением общей инженерной конституции (Constitution) и с проверкой через анти-блеф QA. Основной язык — Go; Kotlin/KMP, TypeScript/React, Python, Swift и Shell применяются там, где они подходят лучше всего. Объединяющий тезис: функция считается готовой только тогда, когда ею может воспользоваться реальный пользователь и есть зафиксированные доказательства этого. | Gender error 'Объединяющая тезис' (тезис is masculine); calque 'декуплированных'; glossary term Constitution must stay verbatim; 'captured evidence' lost ('зафиксированные'). |
| generator | `prod.order` | заказ | порядок | 'заказ' means a purchase order; the field is the sort/sequence order (sr/be correctly use редослед/парадак). |
| generator | `prod.source` | Источник | Исходный код | Heading over the list of source repositories; 'Источник' reads as 'reference/origin of information'. |
| generator | `kw.vasic` | инженерия программного обеспечения, платформы разработки ИИ, оркестровка LLM, открытый исходный код, инструменты для разработчиков, SDK | программная инженерия, платформы для разработки AI, оркестрация LLM, открытый исходный код, инструменты для разработчиков, SDK | Glossary: AI verbatim; 'оркестровка' is the musical term (IT uses 'оркестрация'); 'инженерия программного обеспечения' is a calque of 'программная инженерия'. |
| generator | `kw.milos` | инженер платформы, специалист по SDK, Kotlin, Go, архитектура программного обеспечения, распределенные системы, открытый исходный код | платформенный инженер, специалист по SDK, Kotlin, Go, архитектура программного обеспечения, распределённые системы, открытый исходный код | 'инженер платформы' reads as 'engineer of a (specific) platform'; the established job title/search term is 'платформенный инженер'. |
| generator | `prod.head.whywebuilt.0` | Проблема, которую мы решили взяться решить | Проблема, которую мы взялись решить | 'решили взяться решить' is ungrammatical (double verb, tautology). |
| generator | `prod.head.whywebuilt.3` | Зуд, который требовал почесать | Задача, которая не давала нам покоя | Literal idiom 'Зуд, который требовал почесать' is ungrammatical and odd; natural Russian equivalent of 'the itch we had to scratch'. |
| generator | `prod.head.challenges.2` | Инженерия сложных моментов | Инженерные решения трудных задач | 'Инженерия сложных моментов' is a meaningless calque. |
| generator | `prod.head.gamechanger.name` | Почему это меняет игру | Почему это прорыв | 'меняет игру' is a broken half-idiom (the idiom is 'меняет правила игры', already used by gamechanger.0). |
| generator | `prod.desc.fallback` | %s — %s продукт. | %s — продукт %s. | 'HelixCode — Vasic Digital продукт.' is English word order; Russian needs 'продукт <brand>'. Placeholder order (name, brand) preserved. |
| generator | `alt.portrait` | Портрет Милоша Васича | Miloš Vasić — портрет | Glossary requires the name verbatim (Latin); this phrasing avoids declining a Latin name. |
| generator | `status.production` | в производстве | в эксплуатации | 'в производстве' means 'being manufactured'; for software in production the neutral professional term is 'в эксплуатации'. |
| milosvasic.ru | `nav.expertise` | Экспертиза | Компетенции | 'Экспертиза' in Russian means an expert examination/appraisal, not a person's expertise. |
| milosvasic.ru | `footer.text` | Belgrade · Dubna. Создан как статический сайт, развернут на GitHub Pages. | Белград · Дубна. Создан как статический сайт, размещён на GitHub Pages. | City names were left in English (Latin) inside a Cyrillic sentence; they are not glossary terms. |

## Glossary audit judgements (`_tools/gen/audit_ui_glossary.py`)

- `pf.summary` / Constitution: REAL defect, fixed — Rendered as 'Конституцией'; glossary requires verbatim — fixed as 'конституции (Constitution)'.
- `kw.vasic` / AI: REAL defect, fixed — Rendered as 'ИИ'; glossary binding — fixed. (SEO note in spotcheck.)
- `alt.portrait` / Miloš Vasić: REAL defect, fixed — Transliterated 'Милоша Васича'; glossary requires verbatim Latin — fixed as 'Miloš Vasić — портрет'.

## Items for native-speaker spot-check (non-blocking)

- pf.summary: confirm 'анти-блеф QA' (vs 'QA без блефа') and 'конституции (Constitution)' read naturally to you.
- status.production: 'в эксплуатации' vs dev slang 'в продакшене' — owner preference.
- alt.portrait: glossary forces 'Miloš Vasić' in Latin; if you prefer 'Портрет Милоша Васича' for Russian readers, amend the glossary rule rather than the string.
- kw.vasic: SEO — consider whether to also include 'ИИ' alongside 'AI' (glossary currently forbids localizing).
- pf.eyebrow 'унифицированное портфолио' (kept) — 'единое портфолио' is more natural if you want to polish.
- nav.expertise 'Компетенции' vs 'Специализация'.
- prod.head.* 'флот' metaphor (fleet) used throughout — confirm you want it rather than 'экосистема'.

## Evidence

Footer screenshots (local build from the fixed sources, Playwright chromium, not deployed):

- vasic.digital: [375px](screenshots/ru-vd-375.png), [768px](screenshots/ru-vd-768.png), [1280px](screenshots/ru-vd-1280.png)
- milosvasic.ru: [375px](screenshots/ru-mv-375.png), [768px](screenshots/ru-mv-768.png), [1280px](screenshots/ru-mv-1280.png)

Render results: [render-results.json](render-results.json). Run log: [RUN-LOG.md](RUN-LOG.md).
