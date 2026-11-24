# i18n review — ar (Arabic (RTL))

| Field | Value |
|---|---|
| Reviewer | independent per-language reviewer (not the generator; HelixTranslate output was the subject) |
| Date | 2026-11-24 |
| Roadmap-Item | VSC-423 |
| Initial verdict | **FIX** (107 rows reviewed; 23 generator-dictionary FIX, 3 milosvasic.ru FIX) |
| Disposition | generator-dictionary fixes APPLIED in umbrella source (`_tools/gen/ui-i18n.ar.json`); milosvasic.ru fixes (3) staged as a patch awaiting operator authorisation |
| Verdict after corrections | **GO** for the generator sources (rebuilt; footer/version/link-integrity checks green); milosvasic.ru strings GO once the patch is authorised |

## Summary

Mostly sound Modern Standard Arabic in a professional register, but pf.summary is broken (a stray Chinese character '反', a non-word 'محبز', a changed meaning for 'independently-tested', and no verbatim 'Constitution'). 'Portfolio' was rendered as 'المحفظة' (wallet), 'Work' as 'العمل' (employment), and the 'Primary' nav landmark as 'الرئيسية' (which Arabic users read as 'Home'). The footer leaves 'Belgrade · Dubna' in English, and the desc.fallback attaches 'product' to the wrong placeholder.

## Checks

- **meaning_idiom_register**: MSA professional-neutral register throughout. Real meaning defects: المحفظة (wallet) for portfolio, العمل (job) for Work, الحداثة (modernity) for novelty, التراث (folklore) for heritage tier, a literal 'itch to scratch' calque, and 'fleet' rendered as أسطول. pf.summary is mistranslated in three places.
- **script**: There is one real defect: U+53CD '反' (CJK) inside pf.summary. Apart from that every string is in Arabic script, with harakat (shadda, damma) used sparingly and correctly. There is no Persian ی/ک contamination.
- **rtl**: With page-level dir=rtl, the strings that start with a Latin run ('%s — ...', footer.text 'Belgrade · Dubna.') resolve correctly, because the paragraph direction is set by dir and not inferred. The '—' between Latin and Arabic runs takes the paragraph direction, so it is safe. The 'footer.version' colon is the plain ':' (Arabic has no separate colon glyph), and the LTR 'v2.0.0' link that follows renders on the left of the colon as expected, so no RLM/LRM is needed. In prod.desc.fallback the two %s stay in source order. Under RTL they display right-to-left (name on the right), which is the correct Arabic reading order. If both values are Latin and are adjacent through '—', they may be visually reordered: the proposed form keeps Arabic 'منتج' between them, which anchors the order. tier.* slugs with hyphens display as isolated LTR runs, which is OK.
- **plural**: No string carries a count or plural form. If counts are ever added (e.g. 'N products'), Arabic needs the full CLDR set: zero/one/two (dual)/few/many/other.
- **date_number**: There are no dates. The only numerals are the tier ordinals 1/2/3 in Western digits, which is acceptable for a tech site (Maghreb and most web UIs use Western digits). Using Arabic-Indic ١/٢/٣ would be a site-wide policy decision, not a defect here.
- **glossary**: Brand and product names are kept Latin. Real violations: 'Constitution' (pf.summary), 'AI' (kw.vasic) and 'Miloš Vasić' (alt.portrait). Fixes keep the Arabic term and add the protected term verbatim where natural.
- **footer_length**: mv footer.text is about 66 characters in English and about 55 in the proposed Arabic. It exceeds about 45 characters, but it is shorter than its source, so it is not a regression. footer.suffix (about 23) and footer.version (about 13) are fine.

## Corrections

| Source | Key | Before | After | Rationale |
|---|---|---|---|---|
| generator | `skip` | تخطى إلى المحتوى | انتقل إلى المحتوى | 'تخطى' is past tense (imperative would be 'تخطَّ'); a skip link needs an imperative, aligned with a11y.skip wording. |
| generator | `nav.portfolio` | المحفظة | معرض الأعمال | Arabic 'المحفظة' means a wallet / investment portfolio; a professional work portfolio is 'معرض الأعمال'. |
| generator | `toggle` | تبديل الشكل | تبديل السمة | 'الشكل' (shape/form) is not 'theme'; aria.toggleTheme and title.theme already use 'السمة'. |
| generator | `pf.eyebrow` | محفظة موحدة | معرض أعمال موحّد | Arabic 'المحفظة' means a wallet / investment portfolio; a professional work portfolio is 'معرض الأعمال'. |
| generator | `pf.title` | المحفظة | معرض الأعمال | Arabic 'المحفظة' means a wallet / investment portfolio; a professional work portfolio is 'معرض الأعمال'. |
| generator | `pf.download` | تنزيل المحفظة (PDF) | تنزيل معرض الأعمال (PDF) | Arabic 'المحفظة' means a wallet / investment portfolio; a professional work portfolio is 'معرض الأعمال'. |
| generator | `pf.overview.title` | أسطول واحد، منهج واحد | منظومة واحدة، منهج واحد | 'أسطول' (naval/vehicle fleet) is a calque for a set of software modules; 'منظومة' is the natural term, used consistently. |
| generator | `pf.lede` | محفظة موحدة، قائمة على الأدلة، من عائلة Helix، أدوات Vasic Digital، وسلسلة أدوات Server Factory. | معرض أعمال موحّد قائم على الأدلة لعائلة Helix وأدوات Vasic Digital وسلسلة أدوات Server Factory. | Arabic 'المحفظة' means a wallet / investment portfolio; a professional work portfolio is 'معرض الأعمال'. Also the comma-chained list without 'و' read as apposition rather than a list; 'من' should be the genitive 'لـ'. |
| generator | `pf.summary` | أسطول واحد: تطبيقات المنتج الكبيرة على رأس عشرات من الوحدات الصغيرة المنفصلة والمنفردة والمتحكمة بشكل مستقل — الخاضعة لدستور هندسي مشترك والمدققة بواسطة QA反 الخداع. اللغة السائدة هي Go، مع Kotlin/KMP وTypeScript/React وPython وSwift وShell حيث تناسب بشكل أفضل. الأطروحة الموحدة: الميزة لم تكتمل إلا عندما يمكن لمستخدم حقيقي استخدامها وهناك دليل محبز لبرهنتها. | منظومة واحدة: تطبيقات منتجات كبيرة مبنية فوق عشرات الوحدات الصغيرة المنفصلة والمختبَرة كلٌّ منها على حدة — يحكمها دستور هندسي مشترك (Constitution) ويتحقق منها ضمان جودة (QA) لا يقبل النتائج الزائفة. اللغة السائدة هي Go، إلى جانب Kotlin/KMP وTypeScript/React وPython وSwift وShell حيثما كانت الأنسب. الفكرة الجامعة: لا تُعدّ الميزة مكتملة إلا عندما يستطيع مستخدم حقيقي استخدامها ويوجد دليل مُسجَّل يثبت ذلك. | Stray Chinese '反' inside 'QA反 الخداع'; non-word 'محبز' for 'captured'; 'المنفردة والمتحكمة بشكل مستقل' means 'independently controlled', not 'independently tested'; 'على رأس' means 'at the head of'; 'Constitution' must stay verbatim per glossary; 'anti-bluff QA' rendered by meaning. |
| generator | `tier1.title` | عائلة Helix وبنية LLM | عائلة Helix والبنية التحتية لـ LLM | 'بنية' alone means 'structure'; infrastructure is 'البنية التحتية'. |
| generator | `tier3.eyebrow` | الدرجة 3 — التراث | الدرجة 3 — الإرث | 'التراث' is cultural/folk heritage; a legacy product line is 'الإرث'. |
| generator | `kw.vasic` | هندسة البرمجيات، منصات تطوير الذكاء الاصطناعي، تنسيق LLM، مفتوح المصدر، أدوات المطور، SDK | هندسة البرمجيات، منصات تطوير الذكاء الاصطناعي (AI)، تنسيق LLM، مفتوح المصدر، أدوات المطور، SDK | Glossary requires 'AI' verbatim; kept the Arabic term for search and added AI in parentheses. |
| generator | `aria.primaryNav` | الرئيسية | القائمة الرئيسية | 'الرئيسية' alone is the standard Arabic word for the Home page, so the nav landmark is announced as 'Home'; 'القائمة الرئيسية' = main navigation. |
| generator | `nav.work` | العمل | الأعمال | 'العمل' means job/labour/employment; portfolio 'Work' (projects) is 'الأعمال'. |
| generator | `prod.head.whywebuilt.3` | الحكّة التي كان علينا حكّها | الحاجة التي كان لا بدّ من تلبيتها | Literal 'the itch we had to scratch' is a calque with no meaning in Arabic (reads as a physical itch). |
| generator | `prod.head.innovative.0` | أين تكمن الحداثة | أين يكمن الجديد | 'الحداثة' means modernity/modernism, not novelty. |
| generator | `prod.head.powers.1` | ما يفتحه عبر الأسطول | ما يتيحه عبر المنظومة | 'أسطول' (naval/vehicle fleet) is a calque for a set of software modules; 'منظومة' is the natural term, used consistently. 'يفتحه' is a literal 'unlocks'. |
| generator | `prod.head.powers.2` | كيف يعتمد عليه الأسطول | كيف تعتمد عليه المنظومة | 'أسطول' (naval/vehicle fleet) is a calque for a set of software modules; 'منظومة' is the natural term, used consistently. |
| generator | `prod.head.status.name` | ملاحظات الحالة والصّدق | الحالة وملاحظات الصراحة | 'ملاحظات الحالة والصّدق' (notes of status and truthfulness) is awkward; heading should read 'Status & candour notes'. |
| generator | `prod.desc.fallback` | منتج %s — %s. | %s — منتج %s. | Current 'منتج %s — %s.' attaches 'product' to the FIRST placeholder (the name) instead of the second (the category); order of %s preserved, the noun moved to where English has it. |
| generator | `alt.portrait` | صورة شخصية لميلوش فاسيتش | صورة شخصية لـ Miloš Vasić | Glossary requires the person name verbatim (Latin); transliteration removed. |
| generator | `status.production` | إنتاج | في الإنتاج | Bare 'إنتاج' reads as 'manufacturing/output'; the badge means 'in production'. |
| generator | `status.shipped` | مُطلَق | تم إطلاقه | 'مُطلَق' is ambiguous (most commonly 'absolute', also 'divorced/released'); 'تم إطلاقه' = has been launched/shipped. |
| milosvasic.ru | `nav.work` | العمل | الأعمال | 'العمل' means job/labour; portfolio 'Work' is 'الأعمال' (same fix as gen nav.work). |
| milosvasic.ru | `footer.text` | Belgrade · Dubna. تم بناؤه كموقع ثابت، تم نشره على GitHub Pages. | بلغراد · دوبنا. بُني كموقع ثابت ونُشر على GitHub Pages. | City names were left in English mid-Arabic sentence (not glossary terms) and create a leading Latin run in an RTL footer; double passive 'تم ... تم' is clumsy. |
| milosvasic.ru | `aria.primaryNav` | الرئيسية | القائمة الرئيسية | 'الرئيسية' alone is announced as 'Home page'; same fix as gen aria.primaryNav. |

## Glossary audit judgements (`_tools/gen/audit_ui_glossary.py`)

- `pf.summary` / Constitution: REAL defect, fixed — Rendered only as 'دستور'; the glossary requires the governance-document name verbatim. Fixed as 'دستور هندسي مشترك (Constitution)'.
- `kw.vasic` / AI: REAL defect, fixed — Rendered only as 'الذكاء الاصطناعي'. AI is a protected term, so the fix keeps the Arabic term for search and adds '(AI)'.
- `alt.portrait` / Miloš Vasić: REAL defect, fixed — The name was transliterated as 'ميلوش فاسيتش'. The glossary requires it in Latin form, and the fix uses 'لـ Miloš Vasić'.

## Items for native-speaker spot-check (non-blocking)

- Confirm 'معرض الأعمال' as the site-wide term for Portfolio (alternative: 'ملف الأعمال'). It must be used consistently in nav, title, eyebrow, download and lede.
- Confirm 'منظومة' for 'fleet' across pf.overview.title, pf.summary and prod.head.powers.1/2.
- Confirm that the 'المكدس التقني' (tech stack) and 'تحت الغطاء' (under the hood) calques are acceptable to a native developer audience. Alternatives: 'التقنيات المستخدمة' and 'من الداخل'.
- Check how the pf.summary rendering of 'anti-bluff QA' ('ضمان جودة (QA) لا يقبل النتائج الزائفة') reads.
- Check that the footer line '© 2026 Vasic Digital — مبني على نظام OpenDesign' renders in the intended order in the live RTL page.
- Check the length of the 'تم إطلاقه' and 'في الإنتاج' badges in the status pill.

## Evidence

Footer screenshots (local build from the fixed sources, Playwright chromium, not deployed):

- vasic.digital: [375px](screenshots/ar-vd-375.png), [768px](screenshots/ar-vd-768.png), [1280px](screenshots/ar-vd-1280.png)
- milosvasic.ru: [375px](screenshots/ar-mv-375.png), [768px](screenshots/ar-mv-768.png), [1280px](screenshots/ar-mv-1280.png)

Render results: [render-results.json](render-results.json). Run log: [RUN-LOG.md](RUN-LOG.md).
