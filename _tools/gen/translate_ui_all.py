#!/usr/bin/env python3
"""Efficient, resumable UI-dictionary translator for ALL 15 languages.

Constitution-compliant (§11.4.140/§11.4.141/§11.4.236):
  - Translator: HelixTranslate engine (/tmp/helixtranslate), provider=zhipu
    (glm-4.5-flash) — distinct from the running doc-batch translator (mistral).
  - Glossary terms preserved verbatim via glossary_protect.py sentinels.
  - Independent review is run separately (review step) with a DIFFERENT provider.
  - Per-lang output: ui-i18n.<lang>.json (resumable: existing non-empty keys skipped).
  - FAIL LOUD: an engine failure leaves the key absent (Go falls back to EN
    explicitly); it is never silently replaced by English.

Parallelizes the 30 keys WITHIN each language (thread pool) for speed while
keeping per-language files independent (no shared-file write races).
"""
import json, os, subprocess, sys, tempfile, re
from concurrent.futures import ThreadPoolExecutor, as_completed

REPO = "/Volumes/T7/Projects/vasic"
GEN = f"{REPO}/_tools/gen"
TOOLS = f"{REPO}/_tools"
ENGINE = "/tmp/helixtranslate"
PROTECT = f"{TOOLS}/translate/glossary_protect.py"
GLOSSARY = f"{TOOLS}/translate/glossary.json"
ZHIPU_KEY = os.environ.get("ZHIPU_API_KEY", "")

# de + ar already exist (resumable fills any gaps). 13 target langs to complete:
LANGS = sys.argv[1:] or ["ru", "sr", "es", "fr", "be", "zh", "kk", "hi", "ja", "ko", "ar", "tr", "fa", "de"]
MAX_WORKERS = int(os.environ.get("UI_WORKERS", "5"))

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

ARTIFACTS = {"Contents","Content","Inhalt","Inhaltsverzeichnis","Содержание","Контент","Sadržaj","Sadrzaj",
             "Table des matières","Table des matieres","Contenido","목차","目次","目录","फ़हरिस्त","内容","内容提要",
             "İçerik","İçindekiler","Contenu","Índice","Indice","Съдържание","المحتوى","المحتويات","فهرست","المحتوى الرئيسي"}
_ART_PREFIX = re.compile(
    r"^(?:" + "|".join(re.escape(a) for a in sorted(ARTIFACTS, key=len, reverse=True)) + r")\b[\s:：\-—–]*",
    re.IGNORECASE)

def clean(text):
    lines = [l for l in text.splitlines()]
    while lines and (lines[0].strip() == "" or lines[0].strip() in ARTIFACTS):
        lines.pop(0)
    out = " ".join(l.strip() for l in lines if l.strip() != "").strip()
    new = _ART_PREFIX.sub("", out, count=1).strip()
    return new if new else out

def engine_translate(text, lang):
    prot, mappath = protect(text)
    try:
        with tempfile.TemporaryDirectory() as d:
            inp, outp = f"{d}/in.md", f"{d}/out.md"
            with open(inp, "w") as f: f.write(prot + "\n")
            last = ""
            for _ in range(3):
                if os.path.exists(outp): os.remove(outp)
                p = run([ENGINE, "-i", inp, "-o", outp,
                         "-provider", "zhipu", "-model", "glm-4.5-flash", "-api-key", ZHIPU_KEY,
                         "-source-lang", "en", "-target-lang", lang, "-script", script_for(lang),
                         "-verify=false", "-timeout", "90s"])
                if p.returncode == 0 and os.path.exists(outp) and os.path.getsize(outp) > 0:
                    with open(outp) as f: raw = f.read()
                    return clean(restore(raw, mappath))
                last = (p.stderr or p.stdout)[-300:]
            raise RuntimeError(f"engine failed for {lang!r} on {text[:40]!r}: {last}")
    finally:
        if os.path.exists(mappath): os.unlink(mappath)

def do_lang(lang, en, keys):
    outjson = f"{GEN}/ui-i18n.{lang}.json"
    cur = {}
    if os.path.exists(outjson):
        try: cur = json.load(open(outjson))
        except Exception: cur = {}
    todo = [k for k in keys if not (k in cur and str(cur.get(k, "")).strip())]
    if not todo:
        print(f"[{lang}] complete ({len(cur)} keys), skipping", flush=True)
        return lang, cur
    print(f"[{lang}] translating {len(todo)} keys...", flush=True)
    results = {}
    with ThreadPoolExecutor(max_workers=MAX_WORKERS) as ex:
        futs = {ex.submit(engine_translate, en[k], lang): k for k in todo}
        for fut in as_completed(futs):
            k = futs[fut]
            try:
                results[k] = fut.result()
                print(f"  [{lang}] {k}: {results[k][:50]}", flush=True)
            except Exception as e:
                print(f"  !! [{lang}] {k}: {e}", file=sys.stderr, flush=True)
    cur.update(results)
    # preserve source key order
    ordered = {k: cur[k] for k in keys if k in cur and str(cur[k]).strip()}
    json.dump(ordered, open(outjson, "w"), ensure_ascii=False, indent=2)
    print(f"[{lang}] wrote {len(ordered)}/{len(keys)} keys -> {outjson}", flush=True)
    return lang, ordered

def main():
    if not ZHIPU_KEY:
        print("FATAL: ZHIPU_API_KEY missing", file=sys.stderr); sys.exit(2)
    en = json.load(open(f"{GEN}/ui-i18n.en.json"))
    keys = list(en.keys())
    for lang in LANGS:
        do_lang(lang, en, keys)
    print("TRANSLATE-DONE", flush=True)

if __name__ == "__main__":
    main()
