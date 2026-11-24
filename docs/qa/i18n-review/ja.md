# i18n review — ja (Japanese)

| Field | Value |
|---|---|
| Reviewer | independent per-language reviewer (not the generator; HelixTranslate output was the subject) |
| Date | 2026-11-24 |
| Roadmap-Item | VSC-423 |
| Initial verdict | **FIX** (107 rows reviewed; 13 generator-dictionary FIX, 2 milosvasic.ru FIX) |
| Disposition | generator-dictionary fixes APPLIED in umbrella source (`_tools/gen/ui-i18n.ja.json`); milosvasic.ru fixes (2) staged as a patch awaiting operator authorisation |
| Verdict after corrections | **GO** for the generator sources (rebuilt; footer/version/link-integrity checks green); milosvasic.ru strings GO once the patch is authorised |

## Summary

Navigation and headings are mostly natural Japanese, but pf.summary is seriously broken (meaning inverted 'not anti-bluff', 憲章 for Constitution, 捕獲 for 'captured', register switch to だ/である). Also: 'order' as 注文 (purchase order), 'shipped' as 出荷, 'Work' as 業績, passive 与えられる力, katakana name violating the glossary, and untranslated footer city names.

## Checks

- **meaning_idiom_register**: です/ます intended (pf.lede); pf.summary switched to である - unified to です/ます. Fixed meaning errors in summary, prod.order, status.shipped, powers headings.
- **script**: Japanese only; no Chinese-only characters; stray ASCII space removed in summary.
- **rtl**: n/a
- **plural**: No plural forms (confirmed).
- **date_number**: None present beyond 'ティア 1' ordinals (fine).
- **glossary**: Constitution and Miloš Vasić violations real and fixed; Helix/HelixCode/Vasic Digital/OpenDesign/AI kept verbatim.
- **footer_length**: footer.version 'ウェブサイトのバージョン：' 13 chars OK; footer.suffix OK; mv footer.text ~40 chars after fix exceeds ~25 CJK - consider shortening to 'ベオグラード · ドゥブナ。静的サイト、GitHub Pages で公開。'.

## Corrections

| Source | Key | Before | After | Rationale |
|---|---|---|---|---|
| generator | `skip` | コンテンツへ | コンテンツへスキップ | 'コンテンツへ' drops the verb 'skip'; aligns with a11y.skip 'メインコンテンツへスキップ'. |
| generator | `pf.overview.title` | 1 つの艦隊、1 つの規律 | ひとつの製品群、ひとつの規律 | 'fleet' rendered as a naval/ship fleet; here it means a portfolio of software modules/products. |
| generator | `pf.summary` | 1つのフリート：数十の小さな、切り離された、独立してテストされたモジュールの上に大きな製品アプリケーション — 共有されたエンジニアリング憲章によって管理され、反ブルフではないQAによって検証される。主な言語はGoで、Kotlin/KMP、TypeScript/React、Python、Swift、Shellはそれぞれ最も適切な場所で使用される。統一的なテーゼ：機能は、実際のユーザーが使用できるようになり、証明するための 捕獲された証拠がある場合にのみ完了する。 | ひとつの製品群：数十の小さく疎結合で、個別にテストされたモジュールの上に大規模な製品アプリケーションを構築しています。共通のエンジニアリング Constitution によって統制され、アンチブラフ QA（見せかけの合格を許さない品質保証）によって検証されます。主要言語は Go で、Kotlin/KMP、TypeScript/React、Python、Swift、Shell をそれぞれ最適な場面で使用しています。全体を貫く考え方：機能は、実際のユーザーが使用でき、それを証明する記録済みの証拠がある場合にのみ完了とみなします。 | '反ブルフではないQA' inverts the meaning ('QA that is NOT anti-bluff'); '憲章' must be verbatim 'Constitution'; '捕獲された' (animal capture) wrong for captured evidence; stray space; だ/である mixed with です/ます used in pf.lede; 'fleet' rendered as a naval/ship fleet; here it means a portfolio of software modules/products. |
| generator | `prod.order` | 注文 | 順序 | '注文' means a purchase order; the field is display/sequence order. |
| generator | `nav.work` | 業績 | 実績 | '業績' means business/academic performance results; a portfolio 'Work' section is 実績 (or 作品). |
| generator | `prod.head.challenges.3` | 苦戦したところと勝利の方法 | 苦戦した点と、その乗り越え方 | '勝利の方法' ('method of victory') is an unnatural calque of 'how we won'. |
| generator | `prod.head.powers.0` | 与えられる力 | もたらす力 | '与えられる力' is passive ('power given to it'), reversing who gives the power. |
| generator | `prod.head.powers.1` | 全体に解き放たれる可能性 | 製品群全体で解き放たれる可能性 | '全体' alone is vague (whole of what?); 'across the fleet' = across the product family, consistent with 製品群. |
| generator | `prod.head.powers.2` | 全体がどのように依存しているか | 製品群全体がどのように頼っているか | '全体' alone is vague; consistent fleet rendering 製品群. |
| generator | `prod.head.powers.name` | 全製品でどのように活用されるか（与えられる力） | 全製品でどのように活用されるか（もたらす力） | Same passive-voice error as prod.head.powers.0. |
| generator | `prod.desc.fallback` | %s — %s プロダクト | %s — %s 製品。 | Missing sentence-final '。' (source has a period); 'プロダクト' inconsistent with 製品 used everywhere else. Placeholders unchanged. |
| generator | `alt.portrait` | ミロシュ・ヴァシッチの肖像 | Miloš Vasić の肖像写真 | Glossary requires 'Miloš Vasić' verbatim (katakana transliteration violates it); 写真 clarifies it is a photo. |
| generator | `status.shipped` | 出荷 | リリース済み | '出荷' is physical goods shipping; for software 'shipped' = released. |
| milosvasic.ru | `nav.work` | 業績 | 実績 | Same as gen nav.work; keep both dictionaries consistent. |
| milosvasic.ru | `footer.text` | Belgrade · Dubna. 静的サイトとして構築され、GitHub Pagesにデプロイされています。 | ベオグラード · ドゥブナ。静的サイトとして構築し、GitHub Pages で公開しています。 | City names were left in English (not glossary terms) with an ASCII period; also Latin-CJK spacing before 'GitHub Pages'. |

## Glossary audit judgements (`_tools/gen/audit_ui_glossary.py`)

- `pf.summary` / Constitution: REAL defect, fixed — Rendered as 憲章; glossary requires verbatim 'Constitution'. Fixed.
- `alt.portrait` / Miloš Vasić: REAL defect, fixed — Transliterated to ミロシュ・ヴァシッチ; glossary requires the Latin name verbatim. Fixed.

## Items for native-speaker spot-check (non-blocking)

- アンチブラフ QA gloss in parentheses - acceptable length/term?
- 製品群 as the rendering of 'fleet' across pf.overview.title, pf.summary and powers headings
- 実績 vs 作品 for nav.work
- ティア 1 — 旗艦 vs フラッグシップ
- footer.text length on narrow screens

## Evidence

Footer screenshots (local build from the fixed sources, Playwright chromium, not deployed):

- vasic.digital: [375px](screenshots/ja-vd-375.png), [768px](screenshots/ja-vd-768.png), [1280px](screenshots/ja-vd-1280.png)
- milosvasic.ru: [375px](screenshots/ja-mv-375.png), [768px](screenshots/ja-mv-768.png), [1280px](screenshots/ja-mv-1280.png)

Render results: [render-results.json](render-results.json). Run log: [RUN-LOG.md](RUN-LOG.md).
