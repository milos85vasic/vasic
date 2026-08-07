#!/usr/bin/env python3
"""14x3 PDF chrome verification matrix, from the extracted pdftotext.
Per (lang, doc): counts English chrome-string LEAKS and confirms the localized
chrome is present. A leak = an EN chrome value (whose translation for this lang
DIFFERS from EN) appearing in the extracted text. Also reports target-script
presence for non-Latin langs."""
import json, os, re, sys

REPO = "/Volumes/T7/Projects/vasic"
EV = os.path.join(REPO, "_tests/evidence/fix-pdf-chrome")
TXT = os.path.join(EV, "pdftotext")

I18N = json.load(open(os.path.join(REPO, "_tools/pdf/pdf-i18n.json"), encoding="utf-8"))
EN = I18N["en"]

# distinctive, translatable chrome values to test for leakage, grouped by doc
DOC_KEYS = {
    "CV": ["cv.eyebrow", "cv.metric.since", "cv.metric.repos", "cv.metric.providers",
           "cv.metric.langs"],
    "Cover_Letter": ["cover.eyebrow"],
    "Portfolio": ["pf.eyebrow", "pf.figures.heading", "pf.metric.fleet",
                  "pf.metric.distros", "pf.metric.tests",
                  "pf.figure.helixagent", "pf.figure.helixcluster", "pf.figure.llmsverifier"],
}
# key used to PROVE localized chrome is present per doc
PRESENT_KEY = {"CV": "cv.eyebrow", "Cover_Letter": "cover.eyebrow", "Portfolio": "pf.figures.heading"}

SCRIPT_RE = {
    "cyrillic": re.compile(r"[Ѐ-ӿ]"),
    "arabic": re.compile(r"[؀-ۿ]"),
    "cjk": re.compile(r"[぀-ヿ㐀-鿿가-힯]"),
    "devanagari": re.compile(r"[ऀ-ॿ]"),
}
FAM = {"ru": "cyrillic", "be": "cyrillic", "kk": "cyrillic", "sr": "cyrillic",
       "ar": "arabic", "fa": "arabic", "zh": "cjk", "ja": "cjk", "ko": "cjk",
       "hi": "devanagari"}

UP = lambda l: l.upper()


def norm(s):
    return re.sub(r"\s+", " ", s).lower().strip()


_STRIP = re.compile(r"[\s​-‏‪-‮⁦-⁩؜]")


def norm_tight(s):
    """Remove ALL whitespace + ZWNJ/ZWJ/bidi marks — pdftotext letter-spaces and
    drops joiners for Arabic/Devanagari, so tight matching is the fair presence
    test for complex-script chrome."""
    return _STRIP.sub("", s).lower()


def read_txt(lang, docbase):
    p = os.path.join(TXT, "%s_%s.txt" % (docbase, UP(lang)))
    return open(p, encoding="utf-8").read() if os.path.exists(p) else None


DOC_FILE = {"CV": "Milos_Vasic_CV", "Cover_Letter": "Milos_Vasic_Cover_Letter",
            "Portfolio": "Portfolio"}


def main():
    langs = ["ru", "sr", "de", "es", "fr", "be", "zh", "kk", "hi", "ja", "ko", "ar", "tr", "fa"]
    rows = []
    total_leaks = 0
    print("%-4s %-13s %-6s %-6s %-9s %s" % ("lang", "doc", "leaks", "loc?", "tgt-scr", "leaked_keys"))
    for lang in langs:
        for doc, base in DOC_FILE.items():
            txt = read_txt(lang, base)
            if txt is None:
                print("%-4s %-13s MISSING" % (lang, doc))
                rows.append((lang, doc, None, None, None, ["MISSING_PDF"]))
                continue
            ntxt = norm(txt)
            leaked = []
            for k in DOC_KEYS[doc]:
                en_v, tgt_v = EN[k], I18N[lang][k]
                if norm(en_v) == norm(tgt_v):
                    continue  # legit identical (e.g. fr "Curriculum Vitae")
                if norm(en_v) in ntxt:
                    leaked.append(k)
            total_leaks += len(leaked)
            # localized chrome present? (tight match tolerates complex-script
            # pdftotext letter-spacing / joiner loss)
            pk = PRESENT_KEY[doc]
            loc = (norm(I18N[lang][pk]) in ntxt) or \
                  (norm_tight(I18N[lang][pk]) in norm_tight(txt))
            # target script present in chrome region? (whole doc proxy)
            fam = FAM.get(lang)
            tgt = "n/a" if not fam else ("yes" if SCRIPT_RE[fam].search(txt) else "NO")
            rows.append((lang, doc, len(leaked), loc, tgt, leaked))
            print("%-4s %-13s %-6d %-6s %-9s %s" % (lang, doc, len(leaked),
                  "yes" if loc else "NO", tgt, ",".join(leaked) if leaked else "-"))
    print("\nTOTAL EN chrome leaks across 14x3 =", total_leaks)
    json.dump([{"lang": r[0], "doc": r[1], "leaks": r[2], "localized_present": r[3],
                "target_script": r[4], "leaked_keys": r[5]} for r in rows],
              open(os.path.join(EV, "leak_matrix.json"), "w", encoding="utf-8"),
              ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main()
