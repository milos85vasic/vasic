#!/usr/bin/env python3
"""Independent review of every UI-dictionary language (§11.4.141 independence).
Reviewer: groq/llama-3.3-70b (distinct from the zhipu translator and from the
doc-batch's cohere reviewer). Builds line-parallel EN-source / translation files
from the per-lang JSONs and runs review_translation.py, saving each verdict to
_tests/evidence/ui-l10n/reviews/<lang>.review.json. Prints a PASS/FAIL summary."""
import json, os, subprocess, sys, tempfile

REPO = "/Volumes/T7/Projects/vasic"
GEN = f"{REPO}/_tools/gen"
REVIEWER = f"{REPO}/_tools/review_translation.py"
GLOSSARY = f"{REPO}/_tools/translate/glossary.json"
REVDIR = f"{REPO}/_tests/evidence/ui-l10n/reviews"
LANGS = sys.argv[1:] or ["ru", "sr", "de", "es", "fr", "be", "zh", "kk", "hi", "ja", "ko", "ar", "tr", "fa"]

def main():
    os.makedirs(REVDIR, exist_ok=True)
    en = json.load(open(f"{GEN}/ui-i18n.en.json"))
    summary = {}
    for lang in LANGS:
        f = f"{GEN}/ui-i18n.{lang}.json"
        if not os.path.exists(f):
            summary[lang] = "NO-FILE"; continue
        d = json.load(open(f))
        keys = [k for k in en if str(d.get(k, "")).strip()]
        with tempfile.TemporaryDirectory() as t:
            sp, tp = f"{t}/src.md", f"{t}/tr.md"
            open(sp, "w").write("\n".join(en[k] for k in keys))
            open(tp, "w").write("\n".join(d[k] for k in keys))
            out = f"{REVDIR}/{lang}.review.json"
            r = subprocess.run(["python3", REVIEWER, "--src", sp, "--translated", tp,
                                "--lang", lang, "--provider", "groq",
                                "--glossary", GLOSSARY, "--out", out],
                               capture_output=True, text=True)
        v = "ERROR"
        try:
            j = json.load(open(out))
            v = f"{j.get('verdict')} a={j.get('accuracy')} f={j.get('fluency')} c={j.get('completeness')} n={j.get('naturalness')} terms={j.get('terms_verified')}/{j.get('terms_required')}"
        except Exception as e:
            v = f"ERROR ({e}) rc={r.returncode}"
        summary[lang] = v
        print(f"[{lang}] {v}  ({len(keys)} keys)", flush=True)
    print("\n=== REVIEW SUMMARY ===")
    for l in LANGS:
        print(f"  {l}: {summary.get(l)}")

if __name__ == "__main__":
    main()
