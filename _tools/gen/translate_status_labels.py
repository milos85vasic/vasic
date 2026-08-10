#!/usr/bin/env python3
"""Translate the 9 software-lifecycle STATUS labels + 2 alt phrases into the
master ui-i18n.json, using ONE contextualized engine call per language (a titled
markdown list) so the model has enough context to disambiguate short words
(e.g. 'shipped' = released, not physically sent) and to avoid per-key rate-limit
failures. Tier slugs are intentionally NOT translated (language-neutral technical
identifiers) — they are set to the EN slug verbatim so T() resolves them.

§11.4.140: values come only from the HelixTranslate engine (HELIX_BIN); FAIL LOUD.
Resumable: languages already complete are skipped.

  HELIX_BIN=_tools/helixtranslate-local.sh ZHIPU_API_KEY=... \
      python3 _tools/gen/translate_status_labels.py [lang ...]
"""
import json, os, re, subprocess, sys, tempfile, time

GEN = os.path.dirname(os.path.abspath(__file__))
TOOLS = os.path.dirname(GEN)
MASTER = f"{GEN}/ui-i18n.json"
ENGINE = os.environ.get("HELIX_BIN", os.path.join(TOOLS, "helixtranslate-local.sh"))
PROVIDER = os.environ.get("UI_PROVIDER", "zhipu")
MODEL = os.environ.get("UI_MODEL", "glm-4.5-flash")
APIKEY = os.environ.get("ZHIPU_API_KEY", "")

# order matters: we parse the numbered list back in this order
STATUS = ["active", "beta", "in-development", "mixed", "production",
          "roadmap", "scaffold", "shipped", "stable"]
STATUS_GLOSS = {  # human-readable phrasing fed to the model for disambiguation
    "active": "active", "beta": "beta", "in-development": "in development",
    "mixed": "mixed", "production": "in production", "roadmap": "on the roadmap",
    "scaffold": "scaffold", "shipped": "shipped (released)", "stable": "stable",
}
TIER = ["tier.helix-primary", "tier.serverfactory-tertiary", "tier.vasic-util-secondary"]
LANGS = sys.argv[1:] or ["ru", "sr", "de", "es", "fr", "be", "zh", "kk", "hi", "ja", "ko", "ar", "tr", "fa"]


def script_for(lang):
    if lang in ("ru", "be", "kk", "sr"): return "cyrillic"
    if lang in ("ar", "fa"): return "arabic"
    return "default"


def engine(md, lang):
    """One engine call; returns translated markdown (raw). 3 tries w/ backoff."""
    with tempfile.TemporaryDirectory() as d:
        inp, outp = f"{d}/in.md", f"{d}/out.md"
        open(inp, "w").write(md)
        last = ""
        for attempt in range(3):
            if os.path.exists(outp):
                os.remove(outp)
            args = [ENGINE, "-i", inp, "-o", outp, "-provider", PROVIDER, "-model", MODEL,
                    "-source-lang", "en", "-target-lang", lang, "-script", script_for(lang)]
            if APIKEY:
                args += ["-api-key", APIKEY]
            p = subprocess.run(args, capture_output=True, text=True)
            if p.returncode == 0 and os.path.exists(outp) and os.path.getsize(outp) > 0:
                return open(outp).read()
            last = (p.stderr or p.stdout or "")[-200:]
            time.sleep(3 * (attempt + 1))  # backoff on rate-limit
        raise RuntimeError(f"engine failed {lang}: {last}")


def parse_numbered(raw, n):
    """Extract n numbered list items ('1. x' / '1) x' / '- x') in order."""
    items = []
    for line in raw.splitlines():
        m = re.match(r"^\s*(?:\d+[.)]|[-*])\s+(.*\S)\s*$", line)
        if m:
            items.append(m.group(1).strip())
    return items if len(items) >= n else None


def translate_status(lang):
    lines = "\n".join(f"{i+1}. {STATUS_GLOSS[s]}" for i, s in enumerate(STATUS))
    md = ("Translate the following short software project lifecycle status labels "
          "into the target language. Keep them concise (one or two words each). "
          "Return them as a numbered list in the same order:\n\n" + lines + "\n")
    for _ in range(4):
        items = parse_numbered(engine(md, lang), len(STATUS))
        if items:
            return {f"status.{STATUS[i]}": items[i] for i in range(len(STATUS))}
    raise RuntimeError(f"could not parse status list for {lang}")


def translate_alt(lang):
    md = ("Translate these two image alt-text captions. Keep proper names "
          "(Miloš Vasić, Vasic Digital) unchanged. Return a numbered list:\n\n"
          "1. Portrait of Miloš Vasić\n2. Vasic Digital logo\n")
    for _ in range(4):
        items = parse_numbered(engine(md, lang), 2)
        if items:
            return {"alt.portrait": items[0], "alt.brandLogo": items[1]}
    raise RuntimeError(f"could not parse alt list for {lang}")


def main():
    master = json.load(open(MASTER, encoding="utf-8"))
    en_order = list(master["en"].keys())
    failed = []
    for lang in LANGS:
        block = master.setdefault(lang, {})
        try:
            if any(not str(block.get(f"status.{s}", "")).strip() for s in STATUS):
                block.update(translate_status(lang))
            if any(not str(block.get(k, "")).strip() for k in ("alt.portrait", "alt.brandLogo")):
                block.update(translate_alt(lang))
        except Exception as e:
            print(f"[{lang}] FAIL: {e}", flush=True)
            failed.append(lang)
            continue
        # tier slugs: language-neutral technical identifiers — set to EN slug verbatim
        for k in TIER:
            if not str(block.get(k, "")).strip():
                block[k] = master["en"].get(k, "")
        master[lang] = {k: block[k] for k in en_order if k in block and str(block[k]).strip()}
        done = [f"{s}={block.get('status.'+s)!r}" for s in ("beta", "shipped", "stable")]
        print(f"[{lang}] OK | {'; '.join(done)}", flush=True)
        json.dump(master, open(MASTER, "w", encoding="utf-8"), ensure_ascii=False, indent=2)  # checkpoint
    print(f"DONE. failed={failed or 'none'}", flush=True)
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
