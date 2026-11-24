# i18n review — ko (Korean)

| Field | Value |
|---|---|
| Reviewer | independent per-language reviewer (not the generator; HelixTranslate output was the subject) |
| Date | 2026-11-24 |
| Roadmap-Item | VSC-423 |
| Initial verdict | **FIX** (107 rows reviewed; 11 generator-dictionary FIX, 1 milosvasic.ru FIX) |
| Disposition | generator-dictionary fixes APPLIED in umbrella source (`_tools/gen/ui-i18n.ko.json`); milosvasic.ru fixes (1) staged as a patch awaiting operator authorisation |
| Verdict after corrections | **GO** for the generator sources (rebuilt; footer/version/link-integrity checks green); milosvasic.ru strings GO once the patch is authorised |

## Summary

Short UI labels are fine, but pf.summary contains foreign-script garbage (艦隊, Simplified 捕获), 헌장 for Constitution, a meaning-changing calque (반부정 QA) and mixed register. Several headings are wrong or unnatural (무엇이 우리를 만들어냈는가 reverses meaning, itch calque, 구조 방식), plus 주문 for 'order', badge states 활성화/배포, a transliterated name in alt text and untranslated city names.

## Checks

- **meaning_idiom_register**: 합쇼체 (입니다) in body text; summary unified to it; badges in noun/됨 form. Several heading meaning fixes.
- **script**: FIX: Hanja/Japanese '艦隊' and Simplified Chinese '捕获' in pf.summary removed; rest is clean Hangul.
- **rtl**: n/a
- **plural**: No plural forms (confirmed).
- **date_number**: None present beyond 'tier 1' ordinals (fine).
- **glossary**: Constitution and Miloš Vasić violations real and fixed; brand names, OpenDesign, AI kept verbatim.
- **footer_length**: footer.version '웹사이트 버전:' (ASCII colon is correct Korean convention) OK; footer.suffix OK; mv footer.text ~42 chars after fix, near the ~45 limit.

## Corrections

| Source | Key | Before | After | Rationale |
|---|---|---|---|---|
| generator | `pf.overview.title` | 하나의 함대, 하나의 규율 | 하나의 제품 체계, 하나의 규율 | 'fleet' rendered as a naval/ship fleet; here it means a portfolio of software modules/products. (제품군 is already used for 'family', so 제품 체계 avoids a clash). |
| generator | `pf.lede` | Helix 제품군, Vasic Digital 유틸리티, Server Factory 툴체인에 대한 통합된, 증거 기반 포트폴리오입니다. | Helix 제품군, Vasic Digital 유틸리티, Server Factory 툴체인을 아우르는 통합적이고 증거에 기반한 포트폴리오입니다. | Comma between stacked adjectives ('통합된, 증거 기반') is unnatural in Korean. |
| generator | `pf.summary` | 하나의艦隊: 수십개의 작은 독립된 모듈 위에 구축된 대규모 제품 어플리케이션 — 공유 엔지니어링 헌장에 의해 관리되고 반부정 QA에 의해 검증됨. 주도적인 언어는 Go이며, Kotlin/KMP, TypeScript/React, Python, Swift, Shell은 각각 가장 적합한 곳에서 사용됨. 통일된 제안: 기능은 실제 사용자가 사용할 수 있을 때만 완료되며, 이를 증명하는 捕获된 증거가 있을 때에만 완료된다. | 하나의 제품 체계: 수십 개의 작고 서로 분리되어 독립적으로 테스트되는 모듈 위에 대규모 제품 애플리케이션을 구축합니다. 공유 엔지니어링 Constitution이 이를 관리하고, 안티블러프(anti-bluff) QA가 검증합니다. 주 언어는 Go이며, Kotlin/KMP, TypeScript/React, Python, Swift, Shell을 각각 가장 적합한 곳에 사용합니다. 핵심 원칙: 기능은 실제 사용자가 사용할 수 있고, 이를 증명할 수집된 증거가 있을 때에만 완료된 것입니다. | Foreign-script garbage ('艦隊' Hanja/Japanese, '捕获' Simplified Chinese); '헌장' must be verbatim 'Constitution'; '반부정 QA' ('anti-corruption QA') is a meaning-changing calque; 됨/된다 register mixed with 합쇼체 of pf.lede; '수십개' spacing; '어플리케이션' non-standard spelling. |
| generator | `prod.order` | 주문 | 순서 | '주문' means a purchase order; the field is display/sequence order. |
| generator | `prod.head.whywebuilt.2` | 무엇이 우리를 만들어냈는가 | 우리가 이것을 만들게 된 동기 | '무엇이 우리를 만들어냈는가' means 'what created us' - meaning reversed. |
| generator | `prod.head.whywebuilt.3` | 우리가 긁어야 했던 가려움증 | 우리를 괴롭히던 문제 | Literal 'itch to scratch' calque ('가려움증') is not a Korean idiom and reads as a medical symptom. |
| generator | `prod.head.gamechanger.0` | 게임을 바꾸는 이유 | 판도를 바꾸는 이유 | '게임을 바꾸다' is a calque; the Korean idiom is '판도를 바꾸다'. |
| generator | `prod.head.techstack.1` | 구조 방식 | 구축 방식 | '구조 방식' (structural method) does not render 'How it's built'. |
| generator | `alt.portrait` | 밀로시 바시치 초상화 | Miloš Vasić의 초상 사진 | Glossary requires 'Miloš Vasić' verbatim (Hangul transliteration violates it); '초상화' means a painted portrait. |
| generator | `status.active` | 활성화 | 활성 | '활성화' means 'activation' (an action); a status badge needs the state '활성'. |
| generator | `status.shipped` | 배포 | 출시됨 | '배포' is 'deployment/distribution' as a noun; 'shipped' status = released (출시됨). |
| milosvasic.ru | `footer.text` | Belgrade · Dubna. 정적 사이트로 구축, GitHub Pages에 배포됨. | 베오그라드 · 두브나. 정적 사이트로 구축되어 GitHub Pages에 배포됨. | City names left in English (not glossary terms); connective fixed for a natural note style. |

## Glossary audit judgements (`_tools/gen/audit_ui_glossary.py`)

- `pf.summary` / Constitution: REAL defect, fixed — Rendered as 헌장; glossary requires verbatim 'Constitution'. Fixed.
- `alt.portrait` / Miloš Vasić: REAL defect, fixed — Transliterated to 밀로시 바시치; glossary requires the Latin name verbatim. Fixed.

## Items for native-speaker spot-check (non-blocking)

- 안티블러프(anti-bluff) QA - is a Korean gloss preferred?
- 제품 체계 for 'fleet' vs 제품군 already used for 'family'
- aria.primaryNav '주요' (screen reader reads with role) vs '주 메뉴'
- nav.work '작업' vs '프로젝트'/'작품'
- nav.skills '기술' collides with 기술 스택

## Evidence

Footer screenshots (local build from the fixed sources, Playwright chromium, not deployed):

- vasic.digital: [375px](screenshots/ko-vd-375.png), [768px](screenshots/ko-vd-768.png), [1280px](screenshots/ko-vd-1280.png)
- milosvasic.ru: [375px](screenshots/ko-mv-375.png), [768px](screenshots/ko-mv-768.png), [1280px](screenshots/ko-mv-1280.png)

Render results: [render-results.json](render-results.json). Run log: [RUN-LOG.md](RUN-LOG.md).
