#!/usr/bin/env python3
"""Glossary preservation audit for the UI dictionary (§11.4.140 outcome check).
For every (lang,key), find glossary terms present in the EN source string and
verify each appears VERBATIM (whole-token, case-sensitive) in the translation.
Reports any violation. Since translation ran WITHOUT sentinel protection (the
engine returns empty output when Z9TERM sentinels are present), this is the gate
that enforces the non-translatable-term mandate. Exit 1 if any violation."""
import json, os, re, sys

GEN = os.path.dirname(os.path.abspath(__file__))
GLOSSARY = f"{GEN}/../translate/glossary.json"
LANGS = ["ru", "sr", "de", "es", "fr", "be", "zh", "kk", "hi", "ja", "ko", "ar", "tr", "fa"]

def load_terms():
    g = json.load(open(GLOSSARY))
    terms = []
    for v in g.values():
        if isinstance(v, list):
            terms += [t for t in v if isinstance(t, str) and t]
    terms.sort(key=lambda s: (-len(s), s))
    return terms

def occurs(term, text):
    return re.search(r"(?<![A-Za-z0-9])" + re.escape(term) + r"(?![A-Za-z0-9])", text) is not None

def main():
    terms = load_terms()
    en = json.load(open(f"{GEN}/ui-i18n.en.json"))
    violations = 0
    for lang in LANGS:
        f = f"{GEN}/ui-i18n.{lang}.json"
        if not os.path.exists(f):
            continue
        d = json.load(open(f))
        for k, src in en.items():
            tr = d.get(k, "")
            if not str(tr).strip():
                continue
            required = [t for t in terms if occurs(t, src)]
            for t in required:
                if not occurs(t, tr):
                    print(f"  VIOLATION [{lang}] {k}: term {t!r} missing in {tr!r}")
                    violations += 1
    if violations:
        print(f"GLOSSARY AUDIT: {violations} violation(s)"); sys.exit(1)
    print("GLOSSARY AUDIT: clean (all glossary terms preserved verbatim)")

if __name__ == "__main__":
    main()
