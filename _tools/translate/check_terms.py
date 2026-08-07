#!/usr/bin/env python3
"""Deterministic non-translatable term-preservation spot-check.

For each glossary term present in the English SOURCE body, count whole-token
verbatim occurrences in the SOURCE and in the TRANSLATED output body. A term is
OK if it survives verbatim at least as many times as it must (we flag any term
that occurs in source but drops to zero — a hard leak — and report count deltas).

Usage: check_terms.py <lang> <rel.md> [<rel.md> ...]
       check_terms.py <lang>            # all docs for that lang that exist
Reads glossary from _tools/translate/glossary.json.
"""
import json, os, re, sys, glob

REPO = "/Volumes/T7/Projects/vasic"
CONTENT = os.path.join(REPO, "_content")
GLOSSARY = os.path.join(REPO, "_tools/translate/glossary.json")


def load_terms():
    g = json.load(open(GLOSSARY, encoding="utf-8"))
    terms, seen = [], set()
    for v in g.values():
        if isinstance(v, list):
            for t in v:
                if isinstance(t, str) and t and t not in seen:
                    seen.add(t); terms.append(t)
    terms.sort(key=lambda s: (-len(s), s))
    return terms


def strip_fm(t):
    if t.startswith("---"):
        L = t.split("\n"); f = [i for i, l in enumerate(L) if l.strip() == "---"]
        if len(f) >= 2:
            return "\n".join(L[f[1] + 1:])
    return t


def count(term, text):
    return len(re.findall(r"(?<![A-Za-z0-9])" + re.escape(term) + r"(?![A-Za-z0-9])", text))


def main():
    lang = sys.argv[1]
    rels = sys.argv[2:]
    if not rels:
        rels = sorted(os.path.relpath(p, os.path.join(REPO, f"_content_{lang}"))
                      for sub in ("products", "sites", "docs")
                      for p in glob.glob(os.path.join(REPO, f"_content_{lang}", sub, "*.md")))
    terms = load_terms()
    total_leaks = 0
    for rel in rels:
        src = os.path.join(CONTENT, rel)
        out = os.path.join(REPO, f"_content_{lang}", rel)
        if not (os.path.isfile(src) and os.path.isfile(out)):
            print(f"!! missing src or out for {rel}"); continue
        s = strip_fm(open(src, encoding="utf-8").read())
        o = strip_fm(open(out, encoding="utf-8").read())
        print(f"================ _content_{lang}/{rel} ================")
        print(f"{'TERM':<26}{'src#':>6}{'out#':>6}  verdict")
        for t in terms:
            cs = count(t, s)
            if cs == 0:
                continue
            co = count(t, o)
            if co >= cs:
                verdict = "OK verbatim"
            elif co > 0:
                verdict = f"OK (reduced {cs}->{co})"
            else:
                verdict = "!! LEAKED/MISSING"; total_leaks += 1
            print(f"{t:<26}{cs:>6}{co:>6}  {verdict}")
    print(f"\nTOTAL HARD LEAKS (term in src, 0 in out): {total_leaks}")


if __name__ == "__main__":
    main()
