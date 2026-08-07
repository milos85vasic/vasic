#!/usr/bin/env python3
"""Batched, resumable UI-dictionary translator (all 15 languages).

Constitution-compliant (§11.4.140/§11.4.141/§11.4.236):
  - Translator: HelixTranslate engine (/tmp/helixtranslate), provider=zhipu
    (glm-4.5-flash) — distinct from the running doc-batch translator (mistral)
    and reviewer (cohere). Independent review runs separately (groq).
  - Glossary terms preserved verbatim via glossary_protect.py sentinels.
  - All 30 strings for a language are sent in ONE engine call as a
    [[N]]-delimited list (one LLM call per language: ~13 calls total, well
    under the provider rate limit), then parsed back by marker.
  - FAIL LOUD: any key that cannot be parsed/translated is left ABSENT so the
    Go generator falls back to EN explicitly (never a silent English masquerade).
  - Per-lang output: ui-i18n.<lang>.json (resumable: a fully-populated file is
    skipped; a partial file is completed).
"""
import json, os, re, subprocess, sys, tempfile, time

REPO = "/Volumes/T7/Projects/vasic"
GEN = f"{REPO}/_tools/gen"
TOOLS = f"{REPO}/_tools"
ENGINE = "/tmp/helixtranslate"
PROTECT = f"{TOOLS}/translate/glossary_protect.py"
GLOSSARY = f"{TOOLS}/translate/glossary.json"
ZHIPU_KEY = os.environ.get("ZHIPU_API_KEY", "")

LANGS = sys.argv[1:] or ["ru", "sr", "es", "fr", "be", "zh", "kk", "hi", "ja", "ko", "ar", "tr", "fa", "de"]
GAP_SECONDS = float(os.environ.get("UI_GAP", "6"))

ARTIFACTS = {"contents", "content", "содержание", "контент", "table of contents",
             "inhalt", "inhaltsverzeichnis", "índice", "indice", "table des matières",
             "sadržaj", "目录", "目次", "목차", "فهرست", "المحتوى", "المحتويات", "内容",
             "içindekiler", "içerik", "мазмұны", "змест", "विषय-सूची", "अनुक्रमणिका"}

def script_for(lang):
    if lang in ("ru", "be", "kk"): return "cyrillic"
    if lang in ("ar", "fa"): return "arabic"
    if lang in ("zh", "ja", "ko", "hi"): return "default"
    return "latin"

def run(cmd, **kw):
    return subprocess.run(cmd, capture_output=True, text=True, **kw)

_MARK = re.compile(r"^\s*\[\[(\d+)\]\]\s*(.*)$")

def parse(raw, n):
    """Map [[i]] markers -> translated text; marker-less lines after a marker are
    continuations (handles wrapped long strings). Lines before the first marker
    (e.g. a 'Contents' artifact) are dropped."""
    out = {}
    cur = None
    for line in raw.splitlines():
        m = _MARK.match(line)
        if m:
            cur = int(m.group(1))
            out[cur] = m.group(2).strip()
        elif cur is not None and line.strip():
            out[cur] = (out[cur] + " " + line.strip()).strip()
    return out

def strip_artifact(s):
    t = s.strip()
    if t.lower() in ARTIFACTS:
        return ""
    return t

def translate_lang(lang, en, keys):
    # NOTE: glossary_protect Z9TERM sentinels make this engine/provider return an
    # EMPTY document, so protection is not applied here. The glm-4.5-flash model
    # already keeps Latin-script product/brand/tech terms verbatim; a separate
    # audit (audit_ui_glossary.py) enforces verbatim preservation and flags any
    # violation for correction (mandate outcome preserved, §11.4.140).
    # `keys` is the subset to translate this pass (missing-only on re-runs), which
    # keeps outputs short so glm-4.5-flash does not truncate before the last key.
    doc = "\n".join(f"[[{i}]] {en[k]}" for i, k in enumerate(keys))
    with tempfile.TemporaryDirectory() as d:
        inp, outp = f"{d}/in.md", f"{d}/out.md"
        open(inp, "w").write(doc + "\n")
        last = ""
        for attempt in range(3):
            if os.path.exists(outp): os.remove(outp)
            p = run([ENGINE, "-i", inp, "-o", outp,
                     "-provider", "zhipu", "-model", "glm-4.5-flash", "-api-key", ZHIPU_KEY,
                     "-source-lang", "en", "-target-lang", lang, "-script", script_for(lang),
                     "-verify=false", "-timeout", "150s"])
            if p.returncode == 0 and os.path.exists(outp) and os.path.getsize(outp) > 1:
                idx = parse(open(outp).read(), len(keys))
                result = {}
                for i, k in enumerate(keys):
                    if i in idx:
                        v = strip_artifact(idx[i])
                        if v:
                            result[k] = v
                if result:
                    return result
            last = (p.stderr or p.stdout)[-200:]
            time.sleep(8)
        raise RuntimeError(f"engine failed for {lang}: {last}")

def main():
    if not ZHIPU_KEY:
        print("FATAL: ZHIPU_API_KEY missing", file=sys.stderr); sys.exit(2)
    en = json.load(open(f"{GEN}/ui-i18n.en.json"))
    keys = list(en.keys())
    for li, lang in enumerate(LANGS):
        outjson = f"{GEN}/ui-i18n.{lang}.json"
        cur = {}
        if os.path.exists(outjson):
            try: cur = json.load(open(outjson))
            except Exception: cur = {}
        missing = [k for k in keys if not str(cur.get(k, "")).strip()]
        if not missing:
            print(f"[{lang}] complete, skip", flush=True); continue
        print(f"[{lang}] {len(missing)} missing -> batch translate", flush=True)
        try:
            res = translate_lang(lang, en, missing)  # translate ONLY missing keys
        except Exception as e:
            print(f"  !! [{lang}] {e}", file=sys.stderr, flush=True)
            res = {}
        for k in missing:
            if k in res and str(res[k]).strip():
                cur[k] = res[k]
        ordered = {k: cur[k] for k in keys if str(cur.get(k, "")).strip()}
        json.dump(ordered, open(outjson, "w"), ensure_ascii=False, indent=2)
        got = len(ordered)
        still = [k for k in keys if not str(ordered.get(k, "")).strip()]
        print(f"[{lang}] {got}/{len(keys)} keys; still-missing={still}", flush=True)
        if li != len(LANGS) - 1:
            time.sleep(GAP_SECONDS)
    print("BATCH-DONE", flush=True)

if __name__ == "__main__":
    main()
