#!/usr/bin/env python3
"""Programmatic per-value gate for the translated PDF chrome strings, reusing the
project reviewer's OBJECTIVE checks:
  * target_script_ok  (Cyrillic/Arabic/CJK/Devanagari ratio threshold)
  * glossary term preservation (every non-translatable term in the EN value is
    present VERBATIM in the translation)
  * no untranslated-English leftover (the EN value's translatable words don't
    survive; brand/glossary terms are allowed)
Emits a per-lang verdict JSON + a compact matrix line. No network; deterministic."""
import json, os, re, sys

sys.path.insert(0, os.path.join("/Volumes/T7/Projects/vasic", "_tools"))
import review_translation as R

REPO = "/Volumes/T7/Projects/vasic"
GLOSSARY = os.path.join(REPO, "_tools/translate/glossary.json")
ALL_TERMS = R.load_glossary_terms(GLOSSARY)

# Latin-script languages: no objective script gate (indistinguishable from EN).
LATIN_LANGS = {"de", "es", "fr", "tr"}

# Proper nouns / brands that MUST stay Latin verbatim but are ABSENT from
# glossary.json (the task's preserve-list names them; glossary is not editable
# here). Treated as non-translatable for both the leftover and the script gate.
EXTRA_NONTRANS = ["vasic-digital", "Server Factory", "Mail Server Factory",
                  "Vasic Digital", "Linux", "Constitution", "Helix"]

_SCRIPT_FAM = {
    "ru": "cyrillic", "be": "cyrillic", "kk": "cyrillic", "sr": "cyrillic",
    "ar": "arabic", "fa": "arabic", "zh": "cjk", "ja": "cjk", "ko": "cjk",
    "hi": "devanagari",
}


def review_lang(lang, en, values):
    keys = list(en.keys())
    per_key = {}
    all_ok = True
    for k in keys:
        src, tr = en[k], values.get(k, "")
        req = R.terms_in_source(src, ALL_TERMS)
        missing = [t for t in req if not R.term_present(tr, t)]
        terms_ok = not missing

        # Script gate over TRANSLATABLE RESIDUE: strip every non-translatable
        # term (glossary + EXTRA) from the target, then measure target-script
        # chars vs the Latin letters that remain (genuine prose only). This stops
        # brand-dense short labels (e.g. "Helix · vasic-digital · Server Factory")
        # from failing a gate meant for prose.
        residue = tr
        for t in sorted(req + EXTRA_NONTRANS, key=len, reverse=True):
            residue = residue.replace(t, " ")
        fam = _SCRIPT_FAM.get(lang)
        if fam:
            tgt = len(R._SCRIPT_RE[fam].findall(residue))
            lat = len(re.findall(r"[A-Za-z]", residue))
            ratio = tgt / (tgt + lat) if (tgt + lat) else None
            # pass if residue has no translatable prose (ratio None) or is
            # dominated by target script.
            script_ok = (ratio is None) or (ratio >= R._SCRIPT_MIN[fam])
        else:
            script_ok, ratio = True, None

        # English-leftover check: strip glossary terms + non-letters, then look
        # for any surviving EN word (len>=4) from the source inside the target.
        tr_stripped = tr
        for t in req + EXTRA_NONTRANS:
            tr_stripped = tr_stripped.replace(t, " ")
        src_stripped = src
        for t in req + EXTRA_NONTRANS:
            src_stripped = src_stripped.replace(t, " ")
        src_words = {w.lower() for w in re.findall(r"[A-Za-z]{4,}", src_stripped)}
        # allow internationalized words that legitimately stay latin
        ALLOW = {"portfolio", "portfolio."}
        leftover = sorted(w for w in re.findall(r"[A-Za-z]{4,}", tr_stripped)
                          if w.lower() in src_words and w.lower() not in ALLOW)
        # For Latin-script targets, EN words legitimately share roots; only flag
        # leftover for non-Latin scripts where any EN content word is suspect.
        leftover_bad = leftover if lang not in LATIN_LANGS else []

        ok = terms_ok and script_ok and not leftover_bad
        if not ok:
            all_ok = False
        per_key[k] = {
            "ok": ok, "terms_ok": terms_ok, "missing_terms": missing,
            "script_ok": script_ok, "script_ratio": round(ratio, 3) if ratio is not None else None,
            "leftover": leftover_bad,
        }
    return {"lang": lang, "all_ok": all_ok, "keys": per_key}


def main():
    sp = sys.argv[1]  # langs dir
    en = json.load(open(os.path.join(REPO, "_tools/pdf/pdf-i18n.json"), encoding="utf-8"))["en"]
    langs = ["ru", "sr", "de", "es", "fr", "be", "zh", "kk", "hi", "ja", "ko", "ar", "tr", "fa"]
    out = {}
    print("%-4s %-6s %-9s %s" % ("lang", "all_ok", "script", "issues"))
    for lang in langs:
        path = os.path.join(sp, lang + ".json")
        if not os.path.exists(path) or os.path.getsize(path) == 0:
            print("%-4s MISSING" % lang)
            continue
        values = json.load(open(path, encoding="utf-8"))["values"]
        v = review_lang(lang, en, values)
        out[lang] = v
        issues = []
        for k, r in v["keys"].items():
            if not r["ok"]:
                bits = []
                if r["missing_terms"]:
                    bits.append("missing_terms=%s" % r["missing_terms"])
                if not r["script_ok"]:
                    bits.append("script_ratio=%s" % r["script_ratio"])
                if r["leftover"]:
                    bits.append("leftover=%s" % r["leftover"])
                issues.append("%s(%s)" % (k, ";".join(bits)))
        ratios = [r["script_ratio"] for r in v["keys"].values() if r["script_ratio"] is not None]
        smin = min(ratios) if ratios else None
        print("%-4s %-6s min=%-5s %s" % (lang, v["all_ok"], smin, "; ".join(issues) if issues else "clean"))
    json.dump(out, open(os.path.join(sp, "review.json"), "w", encoding="utf-8"),
              ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main()
