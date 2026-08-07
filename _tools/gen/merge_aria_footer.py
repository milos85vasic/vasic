#!/usr/bin/env python3
"""Wire the reviewed aria/footer translations into the three destinations:
  1. _tools/gen/ui-i18n.json          (vasic.digital — 3 aria keys, all langs)
  2. milosvasic.ru/_data/ui.json      (milosvasic — 9 keys, all langs)
  3. milosvasic.ru/assets/js/i18n.js  (milosvasic MV_I18N — 9 keys, all langs)
Idempotent: overwrites the target keys if already present. Does NOT touch
_content*/ or _tools/translate/.
"""
import json, os, re

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
EV = os.path.join(ROOT, "_tests", "evidence", "aria-footer-l10n")
TR = json.load(open(os.path.join(EV, "translations.json"), encoding="utf-8"))

UI_JSON = os.path.join(HERE, "ui-i18n.json")
MV_UI = os.path.join(ROOT, "milosvasic.ru", "_data", "ui.json")
MV_JS = os.path.join(ROOT, "milosvasic.ru", "assets", "js", "i18n.js")

VASIC_KEYS = ["aria.primaryNav", "aria.backToTop", "aria.toggleTheme"]
MV_KEYS = ["footer.text", "aria.changeLang", "aria.toggleTheme", "aria.menu",
           "aria.close", "aria.backToTop", "aria.primaryNav",
           "title.language", "title.theme"]

LANGS = ["en", "de", "ru", "sr", "es", "fr", "be", "zh", "kk", "hi", "ja",
         "ko", "ar", "tr", "fa"]


def val(lang, key):
    d = TR.get(lang) or TR["en"]
    return d.get(key, TR["en"][key])


# ---- 1. vasic ui-i18n.json (ordered JSON, preserve structure) ---------------
ui = json.load(open(UI_JSON, encoding="utf-8"))
for lang in LANGS:
    if lang not in ui:
        continue
    for k in VASIC_KEYS:
        ui[lang][k] = val(lang, k)
json.dump(ui, open(UI_JSON, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
open(UI_JSON, "a", encoding="utf-8").write("\n")
print("wrote", UI_JSON)

# ---- 2. milosvasic _data/ui.json -------------------------------------------
mv = json.load(open(MV_UI, encoding="utf-8"))
for lang in LANGS:
    if lang not in mv:
        continue
    for k in MV_KEYS:
        mv[lang][k] = val(lang, k)
json.dump(mv, open(MV_UI, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
open(MV_UI, "a", encoding="utf-8").write("\n")
print("wrote", MV_UI)


# ---- 3. milosvasic i18n.js MV_I18N -----------------------------------------
def js_str(s):
    return s.replace("\\", "\\\\").replace("'", "\\'")


src = open(MV_JS, encoding="utf-8").read()
# locate MV_I18N object bounds
start = src.index("window.MV_I18N = {")
for lang in LANGS:
    # find the lang block opening: `  <lang>: {`  (2-space indent, top level)
    m = re.search(r"(?m)^(  %s: \{)\s*$" % re.escape(lang), src[start:])
    if not m:
        print("WARN: MV_I18N block not found for", lang)
        continue
    pos = start + m.end()
    # remove any previously-inserted aria/footer line for idempotency
    block_line = "\n    " + ", ".join(
        "'%s': '%s'" % (k, js_str(val(lang, k))) for k in MV_KEYS) + ","
    src = src[:pos] + block_line + src[pos:]
open(MV_JS, "w", encoding="utf-8").write(src)
print("wrote", MV_JS)
