#!/usr/bin/env python3
"""Build the honest PASS/FAIL/ERROR matrix from review JSONs under
_tests/evidence/translate-new/<lang>/. Prints per-language counts and lists any
doc that is not PASS with the recorded reason."""
import json, os, glob, sys

BASE = "/Volumes/T7/Projects/vasic/_tests/evidence/translate-new"
CONTENT = "/Volumes/T7/Projects/vasic/_content"
LANGS = "ru sr de es fr be zh kk hi ja ko ar tr fa".split()
DOCS = sorted(
    os.path.relpath(p, CONTENT)
    for sub in ("products", "sites", "docs")
    for p in glob.glob(os.path.join(CONTENT, sub, "*.md"))
)
NDOCS = len(DOCS)


def rj(lang, rel):
    return os.path.join(BASE, lang, rel.replace("/", "_") + ".review.json")


def load(lang, rel):
    p = rj(lang, rel)
    if not os.path.isfile(p):
        return None
    try:
        return json.load(open(p, encoding="utf-8"))
    except Exception:
        return {"verdict": "ERROR", "error": "unparseable json"}


print("MATRIX  (docs=%d, langs=%d, pairs=%d)" % (NDOCS, len(LANGS), NDOCS * len(LANGS)))
print("%-4s %6s %6s %6s %8s %8s" % ("lang", "PASS", "FAIL", "ERROR", "PENDING", "DONE%"))
tot = {"PASS": 0, "FAIL": 0, "ERROR": 0, "PENDING": 0}
notpass = {}
for lang in LANGS:
    c = {"PASS": 0, "FAIL": 0, "ERROR": 0, "PENDING": 0}
    bad = []
    for rel in DOCS:
        d = load(lang, rel)
        if d is None:
            c["PENDING"] += 1; bad.append((rel, "PENDING", "not yet run"))
            continue
        v = d.get("verdict", "ERROR")
        outok = os.path.isfile(d.get("_translated", "")) if d.get("_translated") else False
        if v == "PASS" and outok:
            c["PASS"] += 1
        elif v == "FAIL":
            c["FAIL"] += 1
            bad.append((rel, "FAIL", "; ".join(d.get("issues", []) or []) or
                        ("acc=%s flu=%s comp=%s nat=%s script_ok=%s left=%s terms=%s" % (
                            d.get("accuracy"), d.get("fluency"), d.get("completeness"),
                            d.get("naturalness"), d.get("script_ok"),
                            d.get("untranslated_leftovers"), d.get("terms_preserved")))))
        else:
            c["ERROR"] += 1
            bad.append((rel, "ERROR", str(d.get("error", ""))[:80]))
    for k in tot:
        tot[k] += c[k]
    done = c["PASS"] + c["FAIL"] + c["ERROR"]
    pct = 100.0 * c["PASS"] / NDOCS
    print("%-4s %6d %6d %6d %8d %7.0f%%" % (lang, c["PASS"], c["FAIL"], c["ERROR"], c["PENDING"], pct))
    if bad:
        notpass[lang] = bad
print("-" * 44)
print("%-4s %6d %6d %6d %8d" % ("ALL", tot["PASS"], tot["FAIL"], tot["ERROR"], tot["PENDING"]))

if "--detail" in sys.argv and notpass:
    print("\nNON-PASS DETAIL:")
    for lang, bad in notpass.items():
        for rel, v, why in bad:
            if v != "PENDING":
                print("  %-3s %-8s %-34s %s" % (lang, v, rel, why))
