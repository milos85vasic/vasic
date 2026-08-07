#!/usr/bin/env python3
"""Merge per-language ui-i18n.<lang>.json files into the embedded ui-i18n.json.
EN (ui-i18n.en.json) is the untouched source of truth and is written first.
Only non-empty keys are emitted, in EN key order. Prints a coverage matrix."""
import json, os, sys

GEN = os.path.dirname(os.path.abspath(__file__))
LANGS = ["ru", "sr", "de", "es", "fr", "be", "zh", "kk", "hi", "ja", "ko", "ar", "tr", "fa"]

def main():
    en = json.load(open(f"{GEN}/ui-i18n.en.json"))
    keys = list(en.keys())
    merged = {"en": en}
    print(f"EN source: {len(keys)} keys")
    for lang in LANGS:
        f = f"{GEN}/ui-i18n.{lang}.json"
        d = json.load(open(f)) if os.path.exists(f) else {}
        ordered = {k: d[k] for k in keys if str(d.get(k, "")).strip()}
        merged[lang] = ordered
        missing = [k for k in keys if k not in ordered]
        flag = "OK" if not missing else f"MISSING {missing}"
        print(f"  {lang}: {len(ordered)}/{len(keys)}  {flag}")
    json.dump(merged, open(f"{GEN}/ui-i18n.json", "w"), ensure_ascii=False, indent=2)
    total = len(merged) - 1
    full = sum(1 for l in LANGS if len(merged[l]) == len(keys))
    print(f"WROTE ui-i18n.json: en + {total} langs ({full}/{len(LANGS)} at full {len(keys)}/{len(keys)})")

if __name__ == "__main__":
    main()
