# i18n review — hi (Hindi)

| Field | Value |
|---|---|
| Reviewer | independent per-language reviewer (not the generator; HelixTranslate output was the subject) |
| Date | 2026-11-24 |
| Roadmap-Item | VSC-423 |
| Initial verdict | **FIX** (107 rows reviewed; 16 generator-dictionary FIX, 1 milosvasic.ru FIX) |
| Disposition | generator-dictionary fixes APPLIED in umbrella source (`_tools/gen/ui-i18n.hi.json`); milosvasic.ru fixes (1) staged as a patch awaiting operator authorisation |
| Verdict after corrections | **GO** for the generator sources (rebuilt; footer/version/link-integrity checks green); milosvasic.ru strings GO once the patch is authorised |

## Summary

Clean Devanagari, natural headings and correct danda use. Real defects: pf.summary ends in a garbled clause ('कब्जा किया गया है', which means 'seized') and drops verbatim 'Constitution'. alt.brandLogo has a garbled brand ('वासिडिजिटल'), and the glossary violations AI/Miloš Vasić need fixing. Several status badges are ambiguous or wrong: 'जारी' reads as 'ongoing', 'खांचा' means groove, and 'उत्पादन में' means manufacturing. 'fleet' is inconsistently 'बेड़ा' and 'नेटवर्क'.

## Checks

- **meaning_idiom_register**: Professional-neutral register, and most headings are idiomatic (e.g. 'बिना लाग-लपेट की स्थिति', 'वह छलांग जो यह दिलाता है'). Defects: the literal 'itch' and 'game' calques, gamechanger.0 changing 'why' to 'how', विवरण used for overview, वास्तुकला for software architecture, and the inconsistent 'fleet' rendering (बेड़ा vs नेटवर्क).
- **script**: Devanagari is correct throughout, and Latin is used only for brands, technologies and glossary terms. The nukta (फ़, ज़) is mostly present. There is a minor inconsistency between 'जाएं' (gen skip) and 'जाएँ' (mv a11y.skip): both spellings are accepted, so it is not a FIX.
- **rtl**: Not applicable (LTR).
- **plural**: No counted strings. Hindi CLDR has one/other, and noun plural agreement is handled inline: kw.milos now uses the plural 'प्रणालियाँ'.
- **date_number**: There are no dates. Western digits 1/2/3 are standard for Hindi web UIs; Devanagari digits are not expected.
- **glossary**: Real violations: Constitution (pf.summary), AI (kw.vasic 'एआई'), Miloš Vasić (alt.portrait) and Vasic Digital (alt.brandLogo, which is also garbled). All are fixed with the term kept verbatim.
- **footer_length**: mv footer.text is about 65 characters, similar to the English (66). It is over 45 characters but matches the source. Other footer strings are under 25 characters.

## Corrections

| Source | Key | Before | After | Rationale |
|---|---|---|---|---|
| generator | `pf.overview.eyebrow` | विवरण | अवलोकन | 'विवरण' means description/details; overview is 'अवलोकन'. |
| generator | `pf.overview.title` | एक बेड़ा, एक अनुशासन | एक इकोसिस्टम, एक अनुशासन | 'बेड़ा' (fleet of ships) is a calque; prod.head.powers.* used 'नेटवर्क' instead (inconsistent). 'इकोसिस्टम' used consistently. |
| generator | `pf.summary` | एक बेड़ा: दर्जनों छोटे, अलग, स्वतंत्र रूप से परीक्षण किए गए मॉड्यूल के ऊपर बड़े उत्पाद अनुप्रयोग — एक साझा इंजीनियरिंग संविधान द्वारा शासित और एंटी-ब्लफ़ QA द्वारा सत्यापित। प्रमुख भाषा Go है, Kotlin/KMP, TypeScript/React, Python, Swift, और Shell जहां वे सबसे अच्छे लगते हैं। एकत्रीकरण का सिद्धांत: एक विशेषता तभी पूरी होती है जब एक वास्तविक उपयोगकर्ता इसका उपयोग कर सकता है और इसका प्रमाण देने के लिए कब्जा किया गया है। | एक इकोसिस्टम: दर्जनों छोटे, अलग-अलग और स्वतंत्र रूप से परीक्षण किए गए मॉड्यूलों पर बने बड़े उत्पाद एप्लिकेशन — एक साझा इंजीनियरिंग संविधान (Constitution) द्वारा शासित और झूठे दावों को स्वीकार न करने वाले QA द्वारा सत्यापित। प्रमुख भाषा Go है, और जहाँ उपयुक्त हो वहाँ Kotlin/KMP, TypeScript/React, Python, Swift और Shell का उपयोग होता है। मूल सिद्धांत: कोई फ़ीचर तभी पूरा माना जाता है जब कोई वास्तविक उपयोगकर्ता उसका उपयोग कर सके और इसे साबित करने के लिए दर्ज किया गया प्रमाण मौजूद हो। | Last clause is garbled: 'कब्जा किया गया है' = 'has been seized/occupied' and the sentence lacks its subject (evidence); 'एकत्रीकरण का सिद्धांत' = 'aggregation principle'; 'जहां वे सबसे अच्छे लगते हैं' = 'where they look best'; 'विशेषता' = trait, not product feature; 'Constitution' must stay verbatim; 'एंटी-ब्लफ़' is a transliteration calque. |
| generator | `prod.architecture` | वास्तुकला | आर्किटेक्चर | 'वास्तुकला' is building architecture; software architecture is 'आर्किटेक्चर' in Hindi tech usage. |
| generator | `kw.vasic` | सॉफ्टवेयर इंजीनियरिंग, एआई विकास मंच, LLM ऑर्केस्ट्रेशन, ओपन सोर्स, डेवलपर टूल्स, SDK | सॉफ्टवेयर इंजीनियरिंग, AI डेवलपमेंट प्लेटफ़ॉर्म, LLM ऑर्केस्ट्रेशन, ओपन सोर्स, डेवलपर टूल्स, SDK | Glossary requires 'AI' verbatim (was 'एआई'); 'विकास मंच' is a literal calque rarely searched. |
| generator | `kw.milos` | प्लेटफ़ॉर्म इंजीनियर, SDK विशेषज्ञ, Kotlin, Go, सॉफ्टवेयर वास्तुकला, वितरित प्रणाली, ओपन सोर्स | प्लेटफ़ॉर्म इंजीनियर, SDK विशेषज्ञ, Kotlin, Go, सॉफ्टवेयर आर्किटेक्चर, वितरित प्रणालियाँ, ओपन सोर्स | 'सॉफ्टवेयर वास्तुकला' is building-architecture wording; 'distributed systems' is plural. |
| generator | `prod.head.whywebuilt.3` | वह खुजली जिसे हमें खुजलाना था | वह ज़रूरत जिसे पूरा करना ही था | 'वह खुजली जिसे हमें खुजलाना था' is a literal calque of 'itch to scratch' and reads as a physical itch. |
| generator | `prod.head.gamechanger.0` | यह खेल को कैसे बदल देता है | यह पूरी तस्वीर क्यों बदल देता है | Current text asks 'how' (कैसे) where source says 'why', and 'खेल को बदल देता है' is a literal calque. |
| generator | `prod.head.innovative.3` | ऐसे विचार जिन्हें अपनाने लायक है | ऐसे विचार जो अपनाने लायक हैं | 'ऐसे विचार जिन्हें अपनाने लायक है' is ungrammatical (agreement). |
| generator | `prod.head.powers.1` | पूरे नेटवर्क में यह क्या अनलॉक करता है | पूरे इकोसिस्टम में यह क्या संभव बनाता है | 'बेड़ा' (fleet of ships) is a calque; prod.head.powers.* used 'नेटवर्क' instead (inconsistent). 'इकोसिस्टम' used consistently. 'अनलॉक करता है' is a literal 'unlocks'. |
| generator | `prod.head.powers.2` | नेटवर्क इस पर कैसे निर्भर है | इकोसिस्टम इस पर कैसे निर्भर है | 'बेड़ा' (fleet of ships) is a calque; prod.head.powers.* used 'नेटवर्क' instead (inconsistent). 'इकोसिस्टम' used consistently. |
| generator | `alt.portrait` | मिलोश वासिच का पोट्रेट | Miloš Vasić का पोर्ट्रेट | Glossary requires the person name verbatim; 'पोट्रेट' is also misspelled (पोर्ट्रेट). |
| generator | `alt.brandLogo` | वासिडिजिटल का लोगो | Vasic Digital का लोगो | Garbled brand transliteration 'वासिडिजिटल'; brand must stay Latin verbatim. |
| generator | `status.production` | उत्पादन में | प्रोडक्शन में | 'उत्पादन में' means 'in manufacturing'; software 'production' is 'प्रोडक्शन'. |
| generator | `status.shipped` | जारी | रिलीज़ हो चुका | 'जारी' is ambiguous: it most often means 'ongoing/continuing', the opposite of shipped. |
| generator | `status.scaffold` | खांचा | प्रारंभिक ढाँचा | 'खांचा' means groove/slot/mould; a code scaffold is an initial skeleton. |
| milosvasic.ru | `footer.text` | Belgrade · Dubna. एक स्थिर साइट के रूप में बनाया गया, GitHub Pages पर तैनात। | बेलग्रेड · दुब्ना। स्थिर साइट के रूप में बनाया गया, GitHub Pages पर तैनात। | City names left in English and a Latin period mid-Hindi; Hindi sentence terminator is the danda '।'. |

## Glossary audit judgements (`_tools/gen/audit_ui_glossary.py`)

- `pf.summary` / Constitution: REAL defect, fixed — Rendered only as 'संविधान'. Fixed with '(Constitution)' added.
- `kw.vasic` / AI: REAL defect, fixed — Transliterated as 'एआई'. Fixed with the verbatim 'AI'.
- `alt.portrait` / Miloš Vasić: REAL defect, fixed — Transliterated as 'मिलोश वासिच'. Fixed with the Latin name.
- `alt.brandLogo` / Vasic Digital: REAL defect, fixed — The transliteration is garbled ('वासिडिजिटल'). Fixed as 'Vasic Digital का लोगो'.

## Items for native-speaker spot-check (non-blocking)

- Confirm 'इकोसिस्टम' for 'fleet' (alternatives: 'तंत्र' or 'समूह').
- Check how the pf.summary rendering of 'anti-bluff QA' ('झूठे दावों को स्वीकार न करने वाले QA') reads.
- Check the 'रिलीज़ हो चुका' and 'प्रारंभिक ढाँचा' badge lengths.
- Decide between 'जाएं' and 'जाएँ' (anusvara vs chandrabindu) for site-wide consistency.
- Check 'उत्पाद' vs 'प्रोडक्ट' for Products. 'उत्पाद' is fine, but a native speaker should confirm the tone.

## Evidence

Footer screenshots (local build from the fixed sources, Playwright chromium, not deployed):

- vasic.digital: [375px](screenshots/hi-vd-375.png), [768px](screenshots/hi-vd-768.png), [1280px](screenshots/hi-vd-1280.png)
- milosvasic.ru: [375px](screenshots/hi-mv-375.png), [768px](screenshots/hi-mv-768.png), [1280px](screenshots/hi-mv-1280.png)

Render results: [render-results.json](render-results.json). Run log: [RUN-LOG.md](RUN-LOG.md).
