# i18n review — de (German)

| Field | Value |
|---|---|
| Reviewer | independent per-language reviewer (not the generator; HelixTranslate output was the subject) |
| Date | 2026-11-24 |
| Roadmap-Item | VSC-423 |
| Initial verdict | **FIX** (107 rows reviewed; 22 generator-dictionary FIX, 3 milosvasic.ru FIX) |
| Disposition | generator-dictionary fixes APPLIED in umbrella source (`_tools/gen/ui-i18n.de.json`); milosvasic.ru fixes (3) staged as a patch awaiting operator authorisation |
| Verdict after corrections | **GO** for the generator sources (rebuilt; footer/version/link-integrity checks green); milosvasic.ru strings GO once the patch is authorised |

## Summary

German needs real fixes: missing compound hyphens throughout (Helix-Produkte, LLM-Infrastruktur, OpenDesign-System), 'Thema' used for UI theme (means topic), garbage 'Inhalte tier 1', garbled 'vasic-digitalen Dienstprogramme', grammar errors in pf.summary, and a comma-less keyword list. Terminology for tier (Stufe/Level/Inhaltsstufen) and fleet (Flotte/System) was inconsistent. Register is impersonal and consistent; headings otherwise read naturally.

## Checks

- **meaning_idiom_register**: Impersonal register consistent (no du/Sie conflict; imperatives avoided). Defects: Thema/Design, Nützlichkeiten, Inhaltsstufen, calque 'Juckreiz', incomplete verb in challenges.1, case agreement in pf.summary.
- **script**: Latin, umlauts/ß correct; no foreign-script garbage, but stray 'Inhalte tier 1'.
- **rtl**: n/a
- **plural**: No plural-bearing keys; lists only. Confirmed.
- **date_number**: None present (version string v2.0.0 is appended, unaffected). Confirmed.
- **glossary**: Constitution, AI, Miloš Vasić, Vasic Digital, Server Factory, OpenDesign, Helix kept verbatim; open compounds with brands corrected via 'von'/hyphen.
- **footer_length**: footer.suffix 'basierend auf dem OpenDesign-System' is 35 chars; mv footer.text is about 80 chars (EN is 66) and wraps, as the English one does.

## Corrections

| Source | Key | Before | After | Rationale |
|---|---|---|---|---|
| generator | `toggle` | Thema umschalten | Design umschalten | 'Thema' means topic in German; the UI colour theme is 'Design' (or 'Farbschema'). |
| generator | `footer.suffix` | aufgebaut auf dem OpenDesign System | basierend auf dem OpenDesign-System | German compound needs a hyphen (OpenDesign-System); 'aufgebaut auf' is stiff. |
| generator | `pf.download` | Herunterladen Portfolio (PDF) | Portfolio herunterladen (PDF) | Word order: German infinitive goes last ('Portfolio herunterladen'), not 'Herunterladen Portfolio'. |
| generator | `pf.stat.tiers` | Inhaltsstufen | Stufen | 'Inhaltsstufen' (content levels) is wrong meaning; align with 'Stufe' used in tier2/tier3 eyebrows. |
| generator | `pf.stat.helix` | Helix Produkte | Helix-Produkte | Missing compound hyphen (brand + noun). |
| generator | `pf.lede` | Ein einheitliches, evidenzbasiertes Portfolio der Helix-Familie, vasic-digitalen Dienstprogramme und der Server Factory-Toolchain. | Ein einheitliches, evidenzbasiertes Portfolio der Helix-Familie, der Dienstprogramme von Vasic Digital und der Toolchain Server Factory. | 'vasic-digitalen Dienstprogramme' is a garbled adjectivised brand; brand and product names must stay verbatim. |
| generator | `pf.summary` | Eine Flotte: Große Produktanwendungen auf Basis von Dutzenden kleinen, entkoppelten, unabhängig getesteten Modulen — gesteuert von einer gemeinsamen Engineering-Constitution und verifiziert durch Anti-Bluff-QA. Die dominante Sprache ist Go, sowie Kotlin/KMP, TypeScript/React, Python, Swift und Shell an den passenden Stellen. Die einheitliche These lautet: Eine Funktion ist erst dann fertig, wenn ein realer Nutzer sie nutzen kann und es erfasste Beweise gibt, die dies belegen. | Eine Flotte: große Produktanwendungen auf Basis Dutzender kleiner, entkoppelter, unabhängig getesteter Module — gesteuert durch eine gemeinsame Engineering-Constitution und verifiziert durch Anti-Bluff-QA. Die vorherrschende Sprache ist Go, ergänzt durch Kotlin/KMP, TypeScript/React, Python, Swift und Shell dort, wo sie am besten passen. Die verbindende These: Eine Funktion ist erst dann fertig, wenn ein realer Nutzer sie verwenden kann und erfasste Belege dies beweisen. | Case agreement errors ('von Dutzenden kleinen'), ungrammatical 'ist Go, sowie ...', lowercase after colon for a fragment; Constitution kept verbatim. |
| generator | `tier1.eyebrow` | Inhalte tier 1 — Flaggschiff | Stufe 1 — Flaggschiff | Garbage 'Inhalte tier 1' (stray 'Inhalte' + untranslated 'tier'); align with 'Stufe 2/3'. |
| generator | `tier1.title` | Helix Familie & LLM Infrastruktur | Helix-Familie & LLM-Infrastruktur | Missing compound hyphens. |
| generator | `tier2.eyebrow` | Stufe 2 — Nützlichkeiten | Stufe 2 — Dienstprogramme | 'Nützlichkeiten' (usefulnesses) is wrong meaning; use the same term as tier2.title. |
| generator | `tier2.title` | Vasic Digital Dienstprogramme | Dienstprogramme von Vasic Digital | Open compound 'Vasic Digital Dienstprogramme' is ungrammatical; this phrasing keeps the brand verbatim. |
| generator | `prod.tier` | Level | Stufe | Inconsistent terminology: tier is 'Stufe' everywhere else. |
| generator | `kw.vasic` | Softwareentwicklung, AI Entwicklungsplattformen, LLM Orchestrierung, Open Source, Entwicklerwerkzeuge, SDK | Softwareentwicklung, AI-Entwicklungsplattformen, LLM-Orchestrierung, Open Source, Entwicklerwerkzeuge, SDK | Missing compound hyphens (AI-/LLM-); AI kept verbatim. |
| generator | `kw.milos` | Plattform-Ingenieur SDK Spezialist Kotlin Go Softwarearchitektur Verteilte Systeme Open Source | Plattform-Ingenieur, SDK-Spezialist, Kotlin, Go, Softwarearchitektur, verteilte Systeme, Open Source | Keyword list lost all commas (one run-on phrase); 'verteilte' must be lowercase; SDK-Spezialist hyphen. |
| generator | `aria.toggleTheme` | Dunkles / helles Thema umschalten | Zwischen dunklem und hellem Design wechseln | 'Thema' means topic; colour theme is 'Design'. |
| generator | `prod.head.whywebuilt.3` | Der Juckreiz, den wir kratzen mussten | Das Problem, das uns keine Ruhe ließ | Literal calque of 'itch to scratch' is not idiomatic German and reads oddly as a heading. |
| generator | `prod.head.challenges.1` | Die kniffligen Stellen – und wie wir sie behoben | Die kniffligen Stellen – und wie wir sie gelöst haben | Incomplete verb phrase ('wie wir sie behoben' lacks auxiliary 'haben'). |
| generator | `prod.head.powers.1` | Was es im gesamten System freischaltet | Was es in der gesamten Flotte ermöglicht | Terminology: 'fleet' is 'Flotte' elsewhere (pf.summary, overview title), not 'System'. |
| generator | `prod.head.powers.2` | Wie sich das System darauf stützt | Wie sich die Flotte darauf stützt | Terminology: 'fleet' is 'Flotte' elsewhere, not 'System'. |
| generator | `prod.desc.fallback` | %s – %s Produkt. | %s – %s-Produkt. | German compound needs a hyphen after the brand placeholder (e.g. 'Helix-Produkt'); placeholders kept in order. |
| generator | `alt.brandLogo` | Vasic Digital Logo | Logo von Vasic Digital | Open compound 'Vasic Digital Logo' is ungrammatical German. |
| generator | `status.roadmap` | Im Roadmap | Geplant | 'Im Roadmap' has wrong gender (die Roadmap) and is not a natural badge; 'Geplant' matches the other status badges. |
| milosvasic.ru | `footer.text` | Belgrade · Dubna. Als statische Website erstellt, auf GitHub Pages bereitgestellt. | Belgrad · Dubna. Als statische Website erstellt, auf GitHub Pages bereitgestellt. | English exonym 'Belgrade' left untranslated; German is 'Belgrad'. |
| milosvasic.ru | `aria.toggleTheme` | Dunkles / helles Thema umschalten | Zwischen dunklem und hellem Design wechseln | 'Thema' means topic; colour theme is 'Design'. Keep identical to the gen key. |
| milosvasic.ru | `title.theme` | Thema | Design | 'Thema' means topic; the colour theme is 'Design'. |

## Items for native-speaker spot-check (non-blocking)

- tier3.eyebrow 'Erbe' for 'heritage': is 'Vermächtnis' or 'Altbestand' a better fit for the legacy product line?
- nav.skills left as 'Skills' (common in German CVs) vs 'Kenntnisse'.
- prod.desc.fallback renders as e.g. 'HelixCode – Helix-Produkt.': confirm what the 2nd %s is, so the hyphen compound reads right.
- status.production 'Produktiv' vs 'Im Produktivbetrieb' on the badge.
- 'Game-Changer' anglicism in gamechanger.name: acceptable or replace?

## Evidence

Footer screenshots (local build from the fixed sources, Playwright chromium, not deployed):

- vasic.digital: [375px](screenshots/de-vd-375.png), [768px](screenshots/de-vd-768.png), [1280px](screenshots/de-vd-1280.png)
- milosvasic.ru: [375px](screenshots/de-mv-375.png), [768px](screenshots/de-mv-768.png), [1280px](screenshots/de-mv-1280.png)

Render results: [render-results.json](render-results.json). Run log: [RUN-LOG.md](RUN-LOG.md).
