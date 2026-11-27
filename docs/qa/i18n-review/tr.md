# i18n review — tr (Turkish)

| Field | Value |
|---|---|
| Reviewer | independent per-language reviewer (not the generator; HelixTranslate output was the subject) |
| Date | 2026-11-24 |
| Roadmap-Item | VSC-423 |
| Initial verdict | **FIX** (107 rows reviewed; 13 generator-dictionary FIX, 1 milosvasic.ru FIX) |
| Disposition | generator-dictionary fixes APPLIED in umbrella source (`_tools/gen/ui-i18n.tr.json`); milosvasic.ru fixes (1) staged as a patch awaiting operator authorisation |
| Verdict after corrections | **GO** for the generator sources (rebuilt; footer/version/link-integrity checks green); milosvasic.ru strings GO once the patch is authorised |

## Summary

Most navigation, aria, badge and section labels are correct, natural Turkish with correct vowel harmony and apostrophe suffixation (Miloš Vasić'in, Go'dur). Real defects: pf.summary leaves 'shared engineering' in English, translates 'Constitution' (glossary violation) and has a case error; 'order' was mistranslated as a purchase order; 'fleet' is calqued as 'filo'; several rotating headings are literal idiom calques or change meaning (how vs why); 'Belgrade' kept in its English form.

## Checks

- **meaning_idiom_register**: Professional-neutral register throughout. FIX: idiom calques in prod.head.whywebuilt.3, gamechanger.0/.name, techstack.2; meaning error prod.order; incomplete/ambiguous headings whywebuilt.1/.2, status.2; fleet calque in pf.overview.title, pf.summary, powers.1/.2; status.scaffold.
- **script**: Latin Turkish alphabet with correct ç ğ ı İ ö ş ü; no foreign-script garbage.
- **rtl**: n/a
- **plural**: No plural-form strings; confirmed none carry plural variants.
- **date_number**: No dates or numbers inside strings (version number and year are injected outside the translated text); confirmed.
- **glossary**: One real violation: pf.summary 'Anayasası' for Constitution (fixed as 'anayasası (Constitution)'). Brands/products (Helix, Vasic Digital, Server Factory, OpenDesign, GitHub Pages, Miloš Vasić, AI, LLM, SDK) are verbatim elsewhere.
- **footer_length**: footer.suffix 42 chars, footer.version 18 chars: fine. footer.text (mv) is ~85 chars vs 66 in English; it is a full sentence line, not a narrow label, but flag for a narrow-viewport visual check.

## Corrections

| Source | Key | Before | After | Rationale |
|---|---|---|---|---|
| generator | `pf.overview.title` | Tek filo, tek disiplin | Tek ekosistem, tek disiplin | 'filo' (ship/vehicle fleet) is a calque for a family of software modules; 'ekosistem' is the natural Turkish tech term. Applied consistently to pf.summary and prod.head.powers.1/.2. |
| generator | `pf.summary` | Tek bir filo: shared engineering Anayasası tarafından yönetilen ve anti-bluff QA tarafından doğrulanan düzinelerce küçük, ayrıştırılmış, bağımsız olarak test edilmiş modüllerin üzerine inşa edilmiş büyük ürün uygulamaları. Baskın dil Go'dur, Kotlin/KMP, TypeScript/React, Python, Swift ve Shell en uygun yerlerde kullanılır. Birleştirici tezin: bir özellik, yalnızca gerçek bir kullanıcı tarafından kullanılabildiğinde ve bunu kanıtlamak için somut kanıt olduğunda tamamlanmış sayılır. | Tek bir ekosistem: düzinelerce küçük, birbirinden bağımsız ve ayrı ayrı test edilmiş modülün üzerine kurulu büyük ürün uygulamaları — ortak bir mühendislik anayasası (Constitution) ile yönetilir ve blöfe yer vermeyen kalite güvencesiyle (QA) doğrulanır. Baskın dil Go'dur; Kotlin/KMP, TypeScript/React, Python, Swift ve Shell en uygun oldukları yerlerde kullanılır. Birleştirici tez: bir özellik ancak gerçek bir kullanıcı onu kullanabildiğinde ve bunu gösteren kayıt altına alınmış kanıt bulunduğunda tamamlanmış sayılır. | Current leaves 'shared engineering' in English, translates the glossary term Constitution as 'Anayasası' (glossary violation), keeps 'anti-bluff QA' as an opaque calque, has a case error 'Birleştirici tezin' (should be 'tez:'), and the tautology 'kanıtlamak için somut kanıt'. |
| generator | `prod.order` | sipariş | sıra | Rendered next to a sort-position number (e.Order); 'sipariş' means a purchase order: mistranslation. |
| generator | `prod.head.whywebuilt.1` | Neden var | Varlık nedeni | 'Neden var' reads as 'why is there [something]' — ambiguous as a heading; 'Varlık nedeni' (raison d'être) is the natural heading. |
| generator | `prod.head.whywebuilt.2` | Onu inşa etmeye iten şey | Bizi bunu geliştirmeye iten şey | Missing the object 'bizi' (us): 'Onu inşa etmeye iten şey' is an incomplete clause. |
| generator | `prod.head.whywebuilt.3` | Gidermek zorunda hissettiğimiz kaşıntı | Bizi rahat bırakmayan ihtiyaç | Literal calque of the English idiom 'itch to scratch' plus a grammar error ('zorunda hissettiğimiz'); replaced with an idiomatic equivalent. |
| generator | `prod.head.gamechanger.0` | Oyunu nasıl değiştiriyor | Oyunun kurallarını neden değiştiriyor | Current says 'how' (nasıl) instead of 'why'; the Turkish idiom is 'oyunun kurallarını değiştirmek'. |
| generator | `prod.head.techstack.2` | Motor bölümü | Perde arkası | 'Motor bölümü' (engine compartment) is a literal rendering of 'under the hood' and reads oddly; 'Perde arkası' is the idiomatic heading. |
| generator | `prod.head.status.2` | Dürüst durum | Durumun dürüst değerlendirmesi | 'Dürüst durum' ('an honest situation') is unnatural; honesty applies to the assessment, not the state. |
| generator | `prod.head.powers.1` | Tüm filoya neyi açtığı | Tüm ekosisteme neler kazandırdığı | Consistency with the 'fleet' -> 'ekosistem' fix; 'neyi açtığı' for 'unlocks' is literal. |
| generator | `prod.head.powers.2` | Filonun ona nasıl dayandığı | Ekosistemin ona nasıl dayandığı | Consistency with the 'fleet' -> 'ekosistem' fix. |
| generator | `prod.head.gamechanger.name` | Neden bir oyun değiştirici | Neden çığır açıcı | 'oyun değiştirici' is an English calque; 'çığır açıcı' is the established Turkish equivalent of game-changer. |
| generator | `status.scaffold` | çatı | iskelet | Standard Turkish term for a project scaffold is 'iskelet'; 'çatı' (roof) is misleading. |
| milosvasic.ru | `footer.text` | Belgrade · Dubna. Statik bir site olarak oluşturuldu, GitHub Pages üzerinde dağıtıldı. | Belgrad · Dubna. Statik bir site olarak oluşturuldu, GitHub Pages üzerinde dağıtıldı. | City name must use the Turkish exonym 'Belgrad' (as already used in _content_tr/docs/cv.md); 'Belgrade' is the English form. |

## Glossary audit judgements (`_tools/gen/audit_ui_glossary.py`)

- `pf.summary` / Constitution: REAL defect, fixed — The governance document name was translated to 'Anayasası' and preceded by untranslated English 'shared engineering'; the glossary requires the verbatim term — fixed as 'ortak bir mühendislik anayasası (Constitution)'.

## Items for native-speaker spot-check (non-blocking)

- pf.summary rewrite: does 'blöfe yer vermeyen kalite güvencesi (QA)' carry the intended 'anti-bluff QA' meaning naturally?
- 'ekosistem' as the rendering of the author's 'fleet' metaphor across pf.overview.title, pf.summary, prod.head.powers.1/.2.
- Rotating headings prod.head.* (nominalised forms like 'Yeniliğin nerede yattığı', 'Gerçekte nerede olduğu') read naturally as headings.
- status.shipped 'dağıtıldı' vs 'yayınlandı' for a 'shipped' badge.
- prod.source 'Kaynak' over a repository list (vs 'Kaynak kod').
- pf.eyebrow 'birleştirilmiş portföy' vs the more natural 'birleşik portföy'.

## Evidence

Footer screenshots (local build from the fixed sources, Playwright chromium, not deployed):

- vasic.digital: [375px](screenshots/tr-vd-375.png), [768px](screenshots/tr-vd-768.png), [1280px](screenshots/tr-vd-1280.png)
- milosvasic.ru: [375px](screenshots/tr-mv-375.png), [768px](screenshots/tr-mv-768.png), [1280px](screenshots/tr-mv-1280.png)

Render results: [render-results.json](render-results.json). Run log: [RUN-LOG.md](RUN-LOG.md).
