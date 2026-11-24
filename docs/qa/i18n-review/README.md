# Per-language footer / shared-UI-string review (VSC-423)

| Field | Value |
|---|---|
| Date | 2026-11-24 |
| Roadmap-Item | VSC-423 |
| Subject | footer labels (`footer.version`, `footer.suffix`, `footer.text`) and every shared UI string of the two sites: generator dictionary `_tools/gen/ui-i18n.<lang>.json` (89 keys; vasic.digital and the localized pages) and milosvasic.ru `_data/ui.json` + `assets/js/i18n.js` (18 shared keys) |
| Method | each language reviewed by an INDEPENDENT reviewer agent (context-and-spirit, 11.4.237/11.4.256); the generator (HelixTranslate) output was the subject. Raw reviewer output: `raw/<lang>.json` |
| Fixes | applied through the translation source of truth (`ui-i18n.<lang>.json`, merged by `merge_ui.py` into `ui-i18n.json`); no generated output edited by hand |

## Verdicts

| Lang | Name | Initial verdict | Generator FIX (applied) | milosvasic.ru FIX (patch, needs authorisation) | File |
|---|---|---|---|---|---|
| en | English (source) | FIX | 3 | 0 | [en.md](en.md) |
| ru | Russian | FIX | 13 | 2 | [ru.md](ru.md) |
| sr | Serbian (Cyrillic) | FIX | 22 | 1 | [sr.md](sr.md) |
| de | German | FIX | 22 | 3 | [de.md](de.md) |
| es | Spanish | FIX | 8 | 1 | [es.md](es.md) |
| fr | French | FIX | 6 | 0 | [fr.md](fr.md) |
| be | Belarusian | FIX | 19 | 4 | [be.md](be.md) |
| zh | Chinese (Simplified) | FIX | 7 | 1 | [zh.md](zh.md) |
| kk | Kazakh | FIX | 19 | 2 | [kk.md](kk.md) |
| hi | Hindi | FIX | 16 | 1 | [hi.md](hi.md) |
| ja | Japanese | FIX | 13 | 2 | [ja.md](ja.md) |
| ko | Korean | FIX | 11 | 1 | [ko.md](ko.md) |
| ar | Arabic (RTL) | FIX | 23 | 3 | [ar.md](ar.md) |
| tr | Turkish | FIX | 13 | 1 | [tr.md](tr.md) |
| fa | Persian (RTL) | FIX | 16 | 1 | [fa.md](fa.md) |

All 15 initial verdicts are FIX with exact corrections. After corrections each language is GO for the generator sources. The milosvasic.ru strings are GO only once `submodule-patches/milosvasic.ru-e8ea2b1-SOURCE-ONLY.patch` is authorised (that site deploys on push; nothing was pushed to either site).

## Glossary audit (28 violations): root cause

The glossary audit (`_tools/gen/audit_ui_glossary.py`) reported 28 violations and all 28 were real: the generator translated glossary terms that must stay verbatim ('Constitution' became Конституция/Anayasa/宪法 etc., 'AI' became ИИ/IA/KI, and 'Miloš Vasić' / 'Vasic Digital' were transliterated or garbled in alt texts). Machine translation ran without term protection (documented in the audit header), so the audit is the only gate. All were fixed in the translations and the audit now exits 0 ("clean"). The audit was not weakened. Decision for the operator: the person name in the portrait alt text stays Latin per the glossary (the native-script forms are natural orthography; to change that, change the glossary, not the strings).

## Submodule patches (NOT applied, NOT pushed)

In `submodule-patches/` (apply with `git apply -p2` at the submodule root):

- `milosvasic.ru-e8ea2b1-SOURCE-ONLY.patch`: `_data/ui.json` and `assets/js/i18n.js` (the tiny diff; both carry the same shared keys and must change together).
- `milosvasic.ru-e8ea2b1.patch`: the above plus the regenerated localized pages (generator output is tracked in the submodule).
- `vasic.digital-3e86312.patch`: regenerated pages of vasic.digital.
- `umbrella-spec-aria-footer-AFTER-SUBMODULE-BUMP.patch`: `_tests/tests/aria-footer-l10n-runtime.spec.js` pins the old RU footer.text; apply only after the milosvasic.ru patch lands.

Base commits: milosvasic.ru e8ea2b1 (origin/main, v2.0.0; the umbrella gitlink 9b5bf27 is older and predates the version footer) and vasic.digital 3e86312.

Evidence: `screenshots/<lang>-<vd|mv>-<375|768|1280>.png`, `render-results.json`, `RUN-LOG.md`.
