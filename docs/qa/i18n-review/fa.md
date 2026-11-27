# i18n review — fa (Persian (RTL))

| Field | Value |
|---|---|
| Reviewer | independent per-language reviewer (not the generator; HelixTranslate output was the subject) |
| Date | 2026-11-24 |
| Roadmap-Item | VSC-423 |
| Initial verdict | **FIX** (107 rows reviewed; 16 generator-dictionary FIX, 1 milosvasic.ru FIX) |
| Disposition | generator-dictionary fixes APPLIED in umbrella source (`_tools/gen/ui-i18n.fa.json`); milosvasic.ru fixes (1) staged as a patch awaiting operator authorisation |
| Verdict after corrections | **GO** for the generator sources (rebuilt; footer/version/link-integrity checks green); milosvasic.ru strings GO once the patch is authorised |

## Summary

Good, idiomatic Persian with correct ZWNJ usage almost everywhere (وب‌سایت, سطح‌ها) and no Arabic ي/ك contamination. Real defects: a garbled brand in alt.brandLogo ('واسیجیتال دیجیتال'), 'سفارش' (purchase order) for sort order, 'اجازه‌نامه' for license, and a pf.summary that changes meaning and drops verbatim 'Constitution'. The 'fleet' calque (ناوگان) and some literal idioms ('worth stealing', 'changes the game') also need fixing.

## Checks

- **meaning_idiom_register**: Professional-neutral register. Some idioms are adapted well (e.g. 'خاری که باید از پا درمی‌آوردیم'). Others are literal: ناوگان (fleet), 'بازی را تغییر می‌دهد' (changes the game), 'ارزش دزدیدن' (worth stealing), لف‌و‌تکلف. There are lexical errors in prod.order (سفارش) and prod.license (اجازه‌نامه).
- **script**: Persian script is correct, with Persian ی/ک throughout (no Arabic ي/ك). ZWNJ (U+200C) is present in compounds (وب‌سایت, سطح‌ها, مهارت‌ها, پرچم‌دار). One misuse: ZWNJ around 'و' in 'لف‌و‌تکلف'. The ezafe is inconsistent: gen footer.version has 'نسخه وب‌سایت:' while mv has 'نسخهٔ وب‌سایت:'. Both are acceptable, so this is a spot-check item, not a defect.
- **rtl**: Page dir=rtl. 'نسخه وب‌سایت:' followed by the LTR 'v2.0.0' renders correctly, with the colon immediately after the Persian label and the version to its left, so no bidi marks are needed. The Persian colon is the Latin ':'. In prod.desc.fallback the %s order is preserved. The proposed '%s — محصول %s.' keeps Persian text between the two Latin values, which prevents adjacent-LTR reordering. In footer.text, a leading Latin run 'Belgrade · Dubna.' would also be safe under dir=rtl, but it is translated anyway.
- **plural**: No counted strings, so no plural forms are needed (Persian CLDR has only one/other).
- **date_number**: There are no dates. Tier ordinals use Western 1/2/3. Native Persian typography normally uses ۱/۲/۳. This is a site-wide digit policy decision (and could be applied at render time), so it is noted, not FIXed.
- **glossary**: Real violations: Constitution (pf.summary), Miloš Vasić (alt.portrait) and Vasic Digital (alt.brandLogo, which is also garbled). AI and the product names are kept Latin correctly.
- **footer_length**: mv footer.text is longer than 45 characters (about 75 proposed vs 66 in English). It is a full-width footer line in the source too, so this is acceptable. footer.suffix is about 34 characters and fine.

## Corrections

| Source | Key | Before | After | Rationale |
|---|---|---|---|---|
| generator | `pf.overview.title` | یک ناوگان، یک رشته | یک مجموعه، یک انضباط | 'ناوگان' (naval/vehicle fleet) is a calque for a set of software modules; 'مجموعه' used consistently. 'یک رشته' reads as 'one field / one thread', not 'one discipline'. |
| generator | `pf.summary` | یک ناوگان: برنامه‌های محصول بزرگ بر روی ده‌ها ماژول کوچک، جداشده و مستقل-آزمون شده — تحت نظارت یک قانون اساسی مهندسی مشترک و تأیید شده توسط QA ضد-خدعه. زبان غالب Go است، با Kotlin/KMP، TypeScript/React، Python، Swift و Shell در جایی که بهترین‌ها هستند. تز یکپارچه: یک ویژگی تنها زمانی انجام شده است که یک کاربر واقعی بتواند از آن استفاده کند و شواهدی برای اثبات آن وجود داشته باشد. | یک مجموعهٔ واحد: برنامه‌های بزرگ محصول که بر پایهٔ ده‌ها ماژول کوچک، جدا از هم و مستقلاً آزمون‌شده ساخته شده‌اند — تحت حاکمیت یک قانون اساسی مهندسی مشترک (Constitution) و تأییدشده با QA که هیچ ادعای بی‌پشتوانه‌ای را نمی‌پذیرد. زبان غالب Go است و Kotlin/KMP، TypeScript/React، Python، Swift و Shell هر جا که مناسب‌ترند به کار می‌روند. اصل وحدت‌بخش: یک قابلیت تنها زمانی کامل است که یک کاربر واقعی بتواند از آن استفاده کند و شواهد ثبت‌شده‌ای برای اثبات آن وجود داشته باشد. | 'Constitution' must stay verbatim per glossary; 'ضد-خدعه' is an ungrammatical calque; 'مستقل-آزمون شده' uses a stray hyphen; 'در جایی که بهترین‌ها هستند' means 'where they are the best ones' (meaning change); 'انجام شده است' (has been performed) for 'done'; 'captured' evidence was dropped. |
| generator | `prod.order` | سفارش | ترتیب | 'سفارش' means a purchase/commercial order; the field is sort order. |
| generator | `prod.license` | اجازه‌نامه | مجوز | 'اجازه‌نامه' is a permit letter; a software license is 'مجوز' (or 'لایسنس'). |
| generator | `kw.vasic` | مهندسی نرم‌افزار، پلتفرم‌های توسعه AI، هماهنگی LLM، منبع باز، ابزارهای توسعه‌دهنده، SDK | مهندسی نرم‌افزار، پلتفرم‌های توسعه AI، هماهنگی LLM، متن‌باز، ابزارهای توسعه‌دهنده، SDK | 'منبع باز' is a literal calque; the established Persian term (and search keyword) is 'متن‌باز'. |
| generator | `kw.milos` | مهندس پلتفرم، متخصص SDK، Kotlin، Go، معماری نرم‌افزار، سیستم‌های توزیعی، منبع باز | مهندس پلتفرم، متخصص SDK، Kotlin، Go، معماری نرم‌افزار، سیستم‌های توزیع‌شده، متن‌باز | Standard terms are 'سیستم‌های توزیع‌شده' (distributed systems) and 'متن‌باز' (open source). |
| generator | `prod.head.gamechanger.0` | چرا بازی را تغییر می‌دهد | چرا قواعد بازی را تغییر می‌دهد | 'بازی را تغییر می‌دهد' literally 'changes the game (being played)'; the established Persian idiom is 'قواعد بازی را تغییر می‌دهد'. |
| generator | `prod.head.innovative.3` | ایده‌هایی که ارزش دزدیدن دارند | ایده‌هایی که ارزش الگوبرداری دارند | 'ارزش دزدیدن' (worth stealing) reads as literal theft in Persian; the playful English idiom is conveyed by 'الگوبرداری'. |
| generator | `prod.head.status.3` | وضعیت بدون لف‌و‌تکلف | وضعیت، بی‌پرده | 'لف‌و‌تکلف' is not an established expression (mixes 'لفت و لعاب' and 'تکلف') and wrongly puts ZWNJ around 'و'; 'بی‌پرده' = candid, no spin. |
| generator | `prod.head.powers.1` | چه چیزی را در سراسر ناوگان باز می‌کند | چه چیزی را در سراسر مجموعه ممکن می‌سازد | 'ناوگان' (naval/vehicle fleet) is a calque for a set of software modules; 'مجموعه' used consistently. 'باز می‌کند' is a literal 'unlocks'. |
| generator | `prod.head.powers.2` | ناوگان چگونه به آن تکیه می‌کند | مجموعه چگونه به آن تکیه می‌کند | 'ناوگان' (naval/vehicle fleet) is a calque for a set of software modules; 'مجموعه' used consistently. |
| generator | `prod.head.gamechanger.name` | چرا بازی را تغییر می‌دهد | چرا قواعد بازی را تغییر می‌دهد | Same literal-calque issue as gamechanger.0; also keeps the two consistent. |
| generator | `prod.desc.fallback` | محصول %s — %s | %s — محصول %s. | Current form attaches 'محصول' to the first placeholder (the name) instead of the second, and drops the source's trailing period; %s order preserved. |
| generator | `alt.portrait` | پورتره میلوش واسیچ | پرترهٔ Miloš Vasić | Glossary requires the person name verbatim (Latin). |
| generator | `alt.brandLogo` | لوگو واسیجیتال دیجیتال | لوگوی Vasic Digital | Garbled brand transliteration 'واسیجیتال دیجیتال' (duplicates 'Digital'); brand must stay Latin verbatim; ezafe 'لوگوی' needed. |
| generator | `status.production` | تولید | عملیاتی | 'تولید' reads as manufacturing/production output; the badge means the product is live/operational. |
| milosvasic.ru | `footer.text` | Belgrade · Dubna. ساخته شده به عنوان یک سایت استاتیک، مستقر شده روی GitHub Pages. | بلگراد · دوبنا. ساخته‌شده به‌صورت سایت استاتیک و منتشرشده روی GitHub Pages. | City names left in English mid-Persian sentence; 'به عنوان یک ... مستقر شده' is a stiff calque; compound participles take ZWNJ. |

## Glossary audit judgements (`_tools/gen/audit_ui_glossary.py`)

- `pf.summary` / Constitution: REAL defect, fixed — Rendered only as 'قانون اساسی'. Fixed with '(Constitution)' added.
- `alt.portrait` / Miloš Vasić: REAL defect, fixed — Transliterated as 'میلوش واسیچ'. Fixed with the Latin name.
- `alt.brandLogo` / Vasic Digital: REAL defect, fixed — The transliteration is both a glossary violation and garbled ('واسیجیتال دیجیتال'). Fixed as 'لوگوی Vasic Digital'.

## Items for native-speaker spot-check (non-blocking)

- Confirm 'مجموعه' for 'fleet' (alternative: 'اکوسیستم').
- Confirm 'انضباط' for 'discipline' in pf.overview.title.
- Decide on a single footer.version spelling, 'نسخه' or 'نسخهٔ', across both sites.
- Decide the Persian-digit policy for '۱/۲/۳' vs '1/2/3' in the tier labels.
- Check whether 'پورتفولیو' or 'نمونه‌کارها' is preferred for Portfolio.
- Check the 'تعویض تم' (toggle) vs 'تغییر تم' (aria) wording difference. Both are fine, but one could be unified.
- Check how the pf.summary rendering of 'anti-bluff QA' ('QA که هیچ ادعای بی‌پشتوانه‌ای را نمی‌پذیرد') reads.

## Evidence

Footer screenshots (local build from the fixed sources, Playwright chromium, not deployed):

- vasic.digital: [375px](screenshots/fa-vd-375.png), [768px](screenshots/fa-vd-768.png), [1280px](screenshots/fa-vd-1280.png)
- milosvasic.ru: [375px](screenshots/fa-mv-375.png), [768px](screenshots/fa-mv-768.png), [1280px](screenshots/fa-mv-1280.png)

Render results: [render-results.json](render-results.json). Run log: [RUN-LOG.md](RUN-LOG.md).
