# i18n review — zh (Chinese (Simplified))

| Field | Value |
|---|---|
| Reviewer | independent per-language reviewer (not the generator; HelixTranslate output was the subject) |
| Date | 2026-11-24 |
| Roadmap-Item | VSC-423 |
| Initial verdict | **FIX** (107 rows reviewed; 7 generator-dictionary FIX, 1 milosvasic.ru FIX) |
| Disposition | generator-dictionary fixes APPLIED in umbrella source (`_tools/gen/ui-i18n.zh.json`); milosvasic.ru fixes (1) staged as a patch awaiting operator authorisation |
| Verdict after corrections | **GO** for the generator sources (rebuilt; footer/version/link-integrity checks green); milosvasic.ru strings GO once the patch is authorised |

## Summary

Most UI strings are natural and correct Simplified Chinese. Real defects: 'fleet' rendered as 舰队 (naval), 'Constitution' translated as 宪法, a mistranslated heading (实况直播 = live broadcast), untranslated city names in the footer, and a missing sentence-final 。 in prod.desc.fallback.

## Checks

- **meaning_idiom_register**: Neutral professional register throughout; fixes for 舰队, 实况直播, 变革者 and the 捕获的证据 calque.
- **script**: All Simplified; no Traditional characters or foreign-script garbage found.
- **rtl**: n/a
- **plural**: No plural forms in any key (confirmed).
- **date_number**: No dates/numbers besides tier ordinals '第 1 层' (correct).
- **glossary**: Brand/product names kept Latin; Constitution violation in pf.summary fixed; 'AI' and 'OpenDesign' kept verbatim.
- **footer_length**: footer.suffix 18 chars, footer.version 5 chars OK; mv footer.text ~33 chars after fix (over ~25 CJK, but this line is a separate footer text, not the © line) - watch on mobile.

## Corrections

| Source | Key | Before | After | Rationale |
|---|---|---|---|---|
| generator | `pf.overview.title` | 一个舰队，一种纪律 | 一个产品体系，一套工程准则 | 'fleet' rendered as a naval/ship fleet; here it means a portfolio of software modules/products. '纪律' also reads as conduct rules; engineering discipline = 工程准则. |
| generator | `pf.summary` | 一个舰队：在数十个小型、解耦、独立测试的模块之上构建的大型产品应用——由一个共享的工程宪法管理，并由反虚假 QA 验证。主要语言是 Go，Kotlin/KMP、TypeScript/React、Python、Swift 和 Shell 在适合的地方使用。统一的论点：一个功能只有在真正的用户可以使用它，并且有捕获的证据来证明它时才算完成。 | 一个产品体系：大型产品应用构建于数十个小型、解耦且独立测试的模块之上——由共享的工程规范 Constitution 治理，并经反虚假 QA 验证。主要语言为 Go，并在最适合之处采用 Kotlin/KMP、TypeScript/React、Python、Swift 和 Shell。统一的核心理念：只有当真实用户能够使用某项功能，并且有留存的证据加以证明时，该功能才算完成。 | 'fleet' rendered as a naval/ship fleet; here it means a portfolio of software modules/products. 'Constitution' must stay verbatim (宪法 = a state constitution); '捕获的证据' calque replaced by 留存的证据; smoother word order. |
| generator | `prod.head.status.0` | 实况直播 | 现状，如实道来 | '实况直播' means 'live broadcast' - mistranslation of 'Status, told straight'. |
| generator | `prod.head.gamechanger.name` | 为何它是变革者 | 为何它能改变游戏规则 | '变革者' denotes a person/agent; consistent with prod.head.gamechanger.0 wording. |
| generator | `prod.desc.fallback` | %s — %s 产品 | %s — %s 产品。 | Source ends with a period; Chinese sentence needs '。'. Placeholders unchanged. |
| generator | `alt.portrait` | Miloš Vasić的肖像 | Miloš Vasić 的肖像 | Add the Latin-CJK space used consistently elsewhere (e.g. 'Helix 产品'); term kept verbatim. |
| generator | `alt.brandLogo` | Vasic Digital的标志 | Vasic Digital 标志 | Latin-CJK spacing consistency; '的' unnecessary in a logo alt text. |
| milosvasic.ru | `footer.text` | Belgrade · Dubna. 构建为静态网站，部署在 GitHub Pages。 | 贝尔格莱德 · 杜布纳。以静态网站构建，部署于 GitHub Pages。 | City names are not protected glossary terms and were left in English; ASCII period after Dubna replaced with '。'. |

## Glossary audit judgements (`_tools/gen/audit_ui_glossary.py`)

- `pf.summary` / Constitution: REAL defect, fixed — Rendered as 宪法 (a national constitution); the governance document name must stay verbatim. Fixed.

## Items for native-speaker spot-check (non-blocking)

- pf.summary: whether 'Constitution' inline reads well or needs 《》/（宪章） gloss
- 反虚假 QA as the rendering of 'anti-bluff QA'
- prod.head.status.0 / status.3 headline tone (现状，如实道来; 去伪存真的进展)
- footer.suffix '建立在 OpenDesign 系统之上' vs a smoother '基于 OpenDesign 设计系统构建'
- 下载作品集 (PDF) half-width parentheses vs （PDF）

## Evidence

Footer screenshots (local build from the fixed sources, Playwright chromium, not deployed):

- vasic.digital: [375px](screenshots/zh-vd-375.png), [768px](screenshots/zh-vd-768.png), [1280px](screenshots/zh-vd-1280.png)
- milosvasic.ru: [375px](screenshots/zh-mv-375.png), [768px](screenshots/zh-mv-768.png), [1280px](screenshots/zh-mv-1280.png)

Render results: [render-results.json](render-results.json). Run log: [RUN-LOG.md](RUN-LOG.md).
