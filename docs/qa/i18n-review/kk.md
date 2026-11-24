# i18n review — kk (Kazakh)

| Field | Value |
|---|---|
| Reviewer | independent per-language reviewer (not the generator; HelixTranslate output was the subject) |
| Date | 2026-11-24 |
| Roadmap-Item | VSC-423 |
| Initial verdict | **FIX** (107 rows reviewed; 19 generator-dictionary FIX, 2 milosvasic.ru FIX) |
| Disposition | generator-dictionary fixes APPLIED in umbrella source (`_tools/gen/ui-i18n.kk.json`); milosvasic.ru fixes (2) staged as a patch awaiting operator authorisation |
| Verdict after corrections | **GO** for the generator sources (rebuilt; footer/version/link-integrity checks green); milosvasic.ru strings GO once the patch is authorised |

## Summary

Short labels (nav, aria, menu, language/theme titles, most badges) are correct Kazakh Cyrillic. Real defects are concentrated in prose and headings: pf.summary is garbled and transliterates 'Constitution'; 'fleet' is calqued as naval 'флот'; prod.order and both kw.* keyword lists contain mistranslations; several rotating headings are literal calques or ungrammatical; city names left in Latin.

## Checks

- **meaning_idiom_register**: Register is neutral-professional. FIX: pf.summary (garbled clauses), prod.order (purchase order), kw.vasic/kw.milos (wrong terms), toggle, pf.download (case), heading calques whywebuilt.2/.3, gamechanger.0/.1/.name, challenges.2, status.0/.2, powers.1/.2, status.in-development, nav.skills.
- **script**: Cyrillic with Kazakh-specific letters used correctly (ә ғ қ ң ө ұ ү і present; һ not needed); no Russian-only substitutions spotted. Defect: Latin 'Belgrade · Dubna' in footer.text (fixed to Белград · Дубна). Latin brand/product names are correct by glossary.
- **rtl**: n/a
- **plural**: No plural-form strings; confirmed none carry plural variants.
- **date_number**: No dates or numbers inside strings; confirmed. '1-деңгей' ordinal form is correct.
- **glossary**: One real violation: pf.summary 'Конституция' (transliterated; fixed as 'конституция (Constitution)'). Other glossary terms verbatim (Helix, Vasic Digital, Server Factory, OpenDesign, GitHub Pages, Miloš Vasić, AI, LLM, SDK, QA). pf.lede also used the slug 'vasic-digital' — aligned to the brand.
- **footer_length**: footer.suffix 29 chars, footer.version 13 chars: fine. footer.text (mv) ~80 chars vs 66 English: full-sentence line, flag for a narrow-viewport visual check.

## Corrections

| Source | Key | Before | After | Rationale |
|---|---|---|---|---|
| generator | `toggle` | Темаға ауысу | Теманы ауыстыру | 'Темаға ауысу' means 'switch to a theme'; the action is to toggle the theme (consistent with aria.toggleTheme). |
| generator | `pf.download` | Портфолио жүктеу (PDF) | Портфолионы жүктеп алу (PDF) | Missing accusative case on the direct object ('Портфолионы') and the standard verb for download is 'жүктеп алу' (as in dl.heading). |
| generator | `pf.overview.title` | Бір флот, бір тәртіп | Бір экожүйе, бір тәртіп | 'флот' means a naval fleet in Kazakh — a calque for a family of software modules; 'экожүйе' is the natural term. Applied consistently to pf.summary and prod.head.powers.1/.2. |
| generator | `pf.lede` | Helix отбасының, vasic-digital құралдарының және Server Factory құралдар жиынының біртұтас, дәлелді портфолиосы. | Helix отбасының, Vasic Digital құралдарының және Server Factory құралдар тізбегінің біртұтас, дәлелдерге негізделген портфолиосы. | Use the brand 'Vasic Digital' (consistent with tier2.title) instead of the slug; 'toolchain' is 'құралдар тізбегі', and 'evidence-based' is 'дәлелдерге негізделген' ('дәлелді' = justified). |
| generator | `pf.summary` | Бір флот: ондаған кіші, бөлек, тәуелсіз сыналған модульдердің үстіне орналасқан үлкен өнімдік қосымшалар — ортақ инженерлік Конституция басқаратын және анти-блеф QA арқылы тексерілген. Басым тіл — Go, Kotlin/KMP, TypeScript/React, Python, Swift, және Shell — олардың орнына сәйкес келеді. Біртұтас тезис: бір функция тек нағыз пайдаланушы оны пайдалана алатын және дәлелді дәлелдердің бар болғанын дәлелдейтін кезде ғана аяқталады. | Бір экожүйе: ондаған шағын, бір-бірінен тәуелсіз және жеке-жеке сыналған модульдердің үстіне құрылған ірі өнімдік қосымшалар — оларды ортақ инженерлік конституция (Constitution) басқарады, ал сапасын жалған есептерге жол бермейтін QA тексереді. Негізгі тіл — Go; Kotlin/KMP, TypeScript/React, Python, Swift және Shell өздері ең қолайлы жерлерде қолданылады. Біріктіруші тезис: функция нақты пайдаланушы оны қолдана алғанда және мұны дәлелдейтін тіркелген айғақ болғанда ғана дайын саналады. | Current transliterates the glossary term (Конституция, glossary violation), keeps the calque 'анти-блеф QA', garbles the language list ('олардың орнына сәйкес келеді' = 'correspond to their place') and has a tautological, broken final clause ('дәлелді дәлелдердің ... дәлелдейтін'). |
| generator | `prod.order` | тапсырыс | реті | Rendered next to a sort-position number (e.Order); 'тапсырыс' means a purchase order: mistranslation. |
| generator | `kw.vasic` | бағдарламалық инженерия, AI құрылымдарының дамыту платформалары, LLM оркестрлеу, ашық көзі, дамыту құралдары, SDK | бағдарламалық инженерия, AI әзірлеу платформалары, LLM оркестрлеу, ашық бастапқы код, әзірлеуші құралдары, SDK | 'AI құрылымдарының дамыту платформалары' adds 'structures' (mistranslation); 'open source' is 'ашық бастапқы код' ('ашық көзі' = 'its open eye/source'); developer tools = 'әзірлеуші құралдары'. |
| generator | `kw.milos` | платформа инженері, SDK маманы, Kotlin, Go, бағдарламалық инженерия, таратылған жүйелер, ашық көзі | платформа инженері, SDK маманы, Kotlin, Go, бағдарламалық архитектура, таратылған жүйелер, ашық бастапқы код | 'software architecture' was mistranslated as 'бағдарламалық инженерия' (software engineering); 'open source' fixed as in kw.vasic. |
| generator | `prod.head.whywebuilt.2` | Оны құруға не итермеледі | Бізді мұны құруға не итермеледі | Missing the object 'бізді' (us); the clause is incomplete without it. |
| generator | `prod.head.whywebuilt.3` | Қышытатын қышымыз | Бізге тыным бермеген қажеттілік | 'Қышытатын қышымыз' is a meaningless literal calque of 'the itch we had to scratch'. |
| generator | `prod.head.gamechanger.0` | Ойынды қалай өзгертеді | Неге ол ойын ережесін өзгертеді | Current says 'how' (қалай) instead of 'why'; the Kazakh idiom is 'ойын ережесін өзгерту'. |
| generator | `prod.head.gamechanger.1` | Жеткізетін секіріс | Ол берген серпіліс | 'Жеткізетін секіріс' is a literal calque ('delivered jump'); 'серпіліс' is the idiomatic word for a leap/breakthrough. |
| generator | `prod.head.challenges.2` | Қиын бөліктерді инженерлеу | Күрделі тұстардың инженерлік шешімі | 'инженерлеу' is a non-standard calque of 'engineering' as a verb. |
| generator | `prod.head.status.0` | Күйі туралы ашық айтылған | Күйі — бүкпесіз | 'Күйі туралы ашық айтылған' is a dangling participle fragment ('openly told about the status'). |
| generator | `prod.head.status.2` | Адал күйі | Шынайы күйі | 'Адал күйі' ('an honest/faithful state') is unnatural; 'шынайы' (true, genuine) fits a status. |
| generator | `prod.head.powers.1` | Бүкіл флоты бойынша ашқан нәрселері | Бүкіл экожүйеде ашатын мүмкіндіктері | Consistency with 'fleet' -> 'экожүйе'; 'флоты бойынша ашқан нәрселері' is also past tense and vague. |
| generator | `prod.head.powers.2` | Флот оған қалай сүйенеді | Экожүйе оған қалай сүйенеді | Consistency with 'fleet' -> 'экожүйе'. |
| generator | `prod.head.gamechanger.name` | Ойынды өзгертетін нәрсе неге | Неге бұл — бетбұрыс | 'Ойынды өзгертетін нәрсе неге' is ungrammatical (question word stranded at the end). |
| generator | `status.in-development` | Жобалауда | Әзірленуде | 'Жобалауда' means 'in the design phase'; 'in development' is 'Әзірленуде'. |
| milosvasic.ru | `nav.skills` | Қабілеттер | Дағдылар | For a CV/portfolio section, 'skills' is 'Дағдылар'; 'Қабілеттер' means innate abilities/aptitudes. |
| milosvasic.ru | `footer.text` | Belgrade · Dubna. Статикалық сайт ретінде жасалған, GitHub Pages-те орналастырылған. | Белград · Дубна. Статикалық сайт ретінде жасалған, GitHub Pages-те орналастырылған. | City names were left in Latin script mid-Cyrillic text; Kazakh uses 'Белград' (as in _content_kk/docs/cv.md) and 'Дубна'. |

## Glossary audit judgements (`_tools/gen/audit_ui_glossary.py`)

- `pf.summary` / Constitution: REAL defect, fixed — Rendered as Cyrillic 'Конституция' instead of the verbatim glossary term; fixed as 'ортақ инженерлік конституция (Constitution)'.

## Items for native-speaker spot-check (non-blocking)

- pf.summary rewrite: 'жалған есептерге жол бермейтін QA' as the rendering of 'anti-bluff QA', and 'тіркелген айғақ' for 'captured evidence'.
- 'экожүйе' for the author's 'fleet' metaphor.
- status.production 'Өндірісте' (manufacturing sense) vs a software-production phrasing; status badges are capitalised in kk but lowercase in en/tr — confirm whether CSS normalises case.
- nav.expertise 'Мамандану' vs 'Біліктілік'/'Сараптама'.
- prod.sec.summary 'Қорытынды' (conclusion) vs 'Түйіндеме' for a top-of-page summary.
- prod.source 'Көзі' over a repository list (vs 'Бастапқы код').
- Heading rewrites for gamechanger.* ('ойын ережесін өзгерту', 'бетбұрыс', 'серпіліс').

## Evidence

Footer screenshots (local build from the fixed sources, Playwright chromium, not deployed):

- vasic.digital: [375px](screenshots/kk-vd-375.png), [768px](screenshots/kk-vd-768.png), [1280px](screenshots/kk-vd-1280.png)
- milosvasic.ru: [375px](screenshots/kk-mv-375.png), [768px](screenshots/kk-mv-768.png), [1280px](screenshots/kk-mv-1280.png)

Render results: [render-results.json](render-results.json). Run log: [RUN-LOG.md](RUN-LOG.md).
