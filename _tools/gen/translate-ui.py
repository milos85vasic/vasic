#!/usr/bin/env python3
"""Translate generator UI/chrome strings via the HelixTranslate engine, then
independently review each language with a DIFFERENT provider (openrouter),
per HelixConstitution §11.4.140/§11.4.141/§11.4.236.

- Translator engine: _tools/helixtranslate-container.sh, provider=zhipu (distinct from the
  running doc-batch translator=mistral).
- Independent reviewer: review_translation.py, provider=openrouter
  (distinct from the doc-batch reviewer=cohere).
- Glossary terms preserved verbatim via glossary_protect.py sentinels.
- Output: ui-i18n.<lang>.json (per lang) + merged ui-i18n.json.
- Evidence: _tests/evidence/l10n-audit/reviews/<lang>.review.json
- FAIL LOUD: engine failure after retries aborts that string; never a silent
  English fallback (missing key is simply left absent so Go falls back to EN
  explicitly and visibly).
"""
import json, os, subprocess, sys, tempfile, re

# Repo root DERIVED from this script's own location (…/_tools/gen/…), never
# hardcoded, so paths reproduce from a clean clone (§11.4.77).
REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
GEN = f"{REPO}/_tools/gen"
TOOLS = f"{REPO}/_tools"
# HelixTranslate engine: default to the REPO-RELATIVE committed entrypoint
# (_tools/helixtranslate-container.sh), NEVER an ephemeral /tmp path (§11.4.77).
# Override with HELIX_BIN=<path> for a local engine binary.
ENGINE = os.environ.get("HELIX_BIN", os.path.join(TOOLS, "helixtranslate-container.sh"))
PROTECT = f"{TOOLS}/translate/glossary_protect.py"
GLOSSARY = f"{TOOLS}/translate/glossary.json"
REVIEWER = f"{TOOLS}/review_translation.py"
EVID = f"{REPO}/_tests/evidence/l10n-audit"
REVDIR = f"{EVID}/reviews"

# de + ar first (proof langs, incl. one RTL), then the rest.
LANGS = ["de", "ar", "ru", "sr", "es", "fr", "be", "zh", "kk", "hi", "ja", "ko", "tr", "fa"]

ZHIPU_KEY = os.environ.get("ZHIPU_API_KEY", "")
# Engine provider/model DERIVED from the environment (AUDIT.md F15). The
# defaults are the exact literals this pipeline has always used, so an unset
# environment reproduces the previous behaviour byte for byte; a retired or
# rate-capped model is then swapped without editing this file.
PROVIDER = os.environ.get("UI_TRANSLATOR_PROVIDER", "zhipu")
MODEL = os.environ.get("UI_TRANSLATOR_MODEL", "glm-4.5-flash")

def script_for(lang):
    if lang in ("ru", "be", "kk"): return "cyrillic"
    if lang in ("ar", "fa"): return "arabic"
    if lang in ("zh", "ja", "ko", "hi"): return "default"
    return "latin"

def run(cmd, **kw):
    return subprocess.run(cmd, capture_output=True, text=True, **kw)

def protect(text):
    fd_map, mappath = tempfile.mkstemp(suffix=".json"); os.close(fd_map)
    p = run(["python3", PROTECT, "protect", "--glossary", GLOSSARY, "--map", mappath], input=text)
    return p.stdout, mappath

def restore(text, mappath):
    p = run(["python3", PROTECT, "restore", "--map", mappath], input=text)
    if p.returncode != 0:
        raise RuntimeError(f"restore failed: {p.stderr}")
    return p.stdout

ARTIFACTS = {"Contents","Content","Inhalt","Inhaltsverzeichnis","Содержание","Sadržaj","Sadrzaj",
             "Table des matières","Table des matieres","Contenido","목차","目次","目录","फ़हरिस्त","内容",
             "İçerik","İçindekiler","Contenu","Contenido","Índice","Indice","Съдържание","المحتوى","المحتويات","فهرست"}
# leading whole-word artifact (e.g. "Inhalt Tier 1 …", "Content Stufen") + separator
_ART_PREFIX = re.compile(
    r"^(?:" + "|".join(re.escape(a) for a in sorted(ARTIFACTS, key=len, reverse=True)) + r")\b[\s:：\-—–]*",
    re.IGNORECASE)

def clean(text):
    lines = [l for l in text.splitlines()]
    # drop leading standalone translator "Contents" artifact lines
    while lines and (lines[0].strip() == "" or lines[0].strip() in ARTIFACTS):
        lines.pop(0)
    out = " ".join(l.strip() for l in lines if l.strip() != "").strip()
    # strip a leading inline artifact token the engine sometimes prepends
    new = _ART_PREFIX.sub("", out, count=1).strip()
    return new if new else out

def engine_translate(text, lang):
    prot, mappath = protect(text)
    with tempfile.TemporaryDirectory() as d:
        inp, outp = f"{d}/in.md", f"{d}/out.md"
        with open(inp, "w") as f: f.write(prot + "\n")
        last = ""
        for attempt in range(3):
            if os.path.exists(outp): os.remove(outp)
            p = run([ENGINE, "-i", inp, "-o", outp,
                     "-provider", PROVIDER, "-model", MODEL, "-api-key", ZHIPU_KEY,
                     "-source-lang", "en", "-target-lang", lang, "-script", script_for(lang),
                     "-verify=false", "-timeout", "90s"])
            if p.returncode == 0 and os.path.exists(outp) and os.path.getsize(outp) > 0:
                with open(outp) as f: raw = f.read()
                restored = restore(raw, mappath)
                os.unlink(mappath)
                return clean(restored)
            last = (p.stderr or p.stdout)[-300:]
        os.unlink(mappath)
        raise RuntimeError(f"engine failed for {lang!r} on {text[:40]!r}: {last}")

def main():
    if not ZHIPU_KEY:
        print("FATAL: ZHIPU_API_KEY missing", file=sys.stderr); sys.exit(2)
    en = json.load(open(f"{GEN}/ui-i18n.en.json"))
    keys = list(en.keys())
    os.makedirs(REVDIR, exist_ok=True)
    merged = {"en": en}
    for lang in LANGS:
        outjson = f"{GEN}/ui-i18n.{lang}.json"
        cur = {}
        if os.path.exists(outjson):
            cur = json.load(open(outjson))
        print(f"===== {lang} =====", flush=True)
        for k in keys:
            if k in cur and cur[k].strip():
                continue
            try:
                cur[k] = engine_translate(en[k], lang)
                print(f"  {k}: {cur[k][:60]}", flush=True)
            except Exception as e:
                print(f"  !! {k}: {e}", file=sys.stderr, flush=True)
            json.dump(cur, open(outjson, "w"), ensure_ascii=False, indent=2)
        merged[lang] = cur
        # ---- independent review (openrouter) over the whole per-lang set ----
        src_txt = "\n".join(en[k] for k in keys if k in cur)
        tr_txt = "\n".join(cur[k] for k in keys if k in cur)
        with tempfile.TemporaryDirectory() as d:
            sp, tp = f"{d}/src.md", f"{d}/tr.md"
            open(sp, "w").write(src_txt); open(tp, "w").write(tr_txt)
            rev = f"{REVDIR}/{lang}.review.json"
            # Independent reviewer: groq (llama-3.3-70b) — distinct from the zhipu
            # translator (§11.4.141 independence) and from the doc-batch's cohere
            # reviewer (so it does not starve that queue). openrouter was the first
            # choice but is out of credits (HTTP 402).
            env = dict(os.environ, REVIEW_PROVIDER="groq")
            r = run(["python3", REVIEWER, "--src", sp, "--translated", tp,
                     "--lang", lang, "--provider", "groq", "--out", rev], env=env)
            print(f"  review {lang}: rc={r.returncode} -> {rev}", flush=True)
        json.dump(merged, open(f"{GEN}/ui-i18n.json", "w"), ensure_ascii=False, indent=2)
    print("DONE", flush=True)

if __name__ == "__main__":
    main()
