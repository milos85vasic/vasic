#!/usr/bin/env python3
"""Glossary sentinel protection for the translation pipeline (§11.4.140 mandate:
NON-TRANSLATABLE terms preserved verbatim).

Two modes:

  protect  --glossary G.json --map MAP.json  < body.md   > body.protected.md
      Replaces every glossary term (across ALL arrays) with a unique sentinel of
      the form Z9TERM<NNN>Z9 that survives LLM translation intact, and records a
      number->term map to MAP.json. Matching is whole-token (custom lookaround so
      terms like "C++", "PL/pgSQL", "vasic.digital", "HTTP/3" work), case-SENSITIVE
      (so the acronym "AI" never matches the letters in "email"/"available"), and
      longest-term-first (so "Docker Compose" is protected before "Docker",
      "Model Context Protocol" before "MCP").

  restore  --map MAP.json  < body.translated.md          > body.restored.md
      Replaces each sentinel back with its original term. Tolerant to case
      mutations the LLM may introduce (z9term001z9 -> HelixTrack). Exits non-zero
      (FAIL LOUD) if any Z9TERM-shaped token remains that is NOT in the map, or if
      a mapped sentinel could not be found (helps detect engine mangling).

Exit: 0 ok; 1 restore found an unknown/leftover sentinel.
"""
import argparse, json, re, sys

SENTINEL_RE = re.compile(r"[Zz]9[Tt][Ee][Rr][Mm](\d{1,4})[Zz]9")


def load_terms(glossary_path):
    with open(glossary_path, encoding="utf-8") as f:
        g = json.load(f)
    terms = []
    seen = set()
    for key, val in g.items():
        if not isinstance(val, list):
            continue  # skip _comment and any non-array metadata
        for t in val:
            if isinstance(t, str) and t and t not in seen:
                seen.add(t)
                terms.append(t)
    # Longest first so multi-word / superstring terms win; stable tiebreak.
    terms.sort(key=lambda s: (-len(s), s))
    return terms


def protect(glossary_path, map_path):
    text = sys.stdin.read()
    terms = load_terms(glossary_path)
    num2term = {}
    matched = []
    n = 0
    for term in terms:
        pat = re.compile(r"(?<![A-Za-z0-9])" + re.escape(term) + r"(?![A-Za-z0-9])")
        if not pat.search(text):
            continue
        n += 1
        sentinel = "Z9TERM%03dZ9" % n
        text = pat.sub(sentinel, text)
        num2term[str(n)] = term
        matched.append(term)
    with open(map_path, "w", encoding="utf-8") as f:
        json.dump({"num2term": num2term, "matched": matched}, f, ensure_ascii=False, indent=2)
    sys.stdout.write(text)
    sys.stderr.write("[protect] %d glossary terms protected: %s\n" % (len(matched), ", ".join(matched)))
    return 0


def restore(map_path):
    with open(map_path, encoding="utf-8") as f:
        m = json.load(f)
    num2term = m["num2term"]
    text = sys.stdin.read()
    unknown = []
    seen = set()

    def repl(match):
        num = str(int(match.group(1)))
        seen.add(num)
        if num in num2term:
            return num2term[num]
        unknown.append(match.group(0))
        return match.group(0)

    text = SENTINEL_RE.sub(repl, text)
    sys.stdout.write(text)
    # FAIL LOUD if any sentinel-shaped token was not mapped, if a leftover token
    # survives, or if a mapped sentinel NEVER appeared in the engine output
    # (i.e. the engine silently DROPPED the protected term — the #45 gap).
    remaining = SENTINEL_RE.search(text)
    dropped = [n for n in num2term if n not in seen]
    errs = []
    if unknown:
        errs.append("unknown sentinels: %s" % ", ".join(sorted(set(unknown))))
    if remaining:
        errs.append("leftover sentinel token after restore: %s" % remaining.group(0))
    if dropped:
        errs.append("dropped sentinels (engine omitted protected term): %s"
                    % ", ".join("%s=%s" % (n, num2term[n]) for n in sorted(dropped, key=int)))
    if errs:
        sys.stderr.write("[restore] ERROR: " + " | ".join(errs) + "\n")
        return 1
    sys.stderr.write("[restore] %d sentinel classes restored OK\n" % len(num2term))
    return 0


def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="mode", required=True)
    p = sub.add_parser("protect")
    p.add_argument("--glossary", required=True)
    p.add_argument("--map", required=True)
    r = sub.add_parser("restore")
    r.add_argument("--map", required=True)
    a = ap.parse_args()
    if a.mode == "protect":
        sys.exit(protect(a.glossary, a.map))
    else:
        sys.exit(restore(a.map))


if __name__ == "__main__":
    main()
