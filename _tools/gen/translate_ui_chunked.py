#!/usr/bin/env python3
"""Serial, char-budgeted, resumable UI translator.

Provider and model come from UI_TRANSLATOR_PROVIDER / UI_TRANSLATOR_MODEL and
default to zhipu / glm-4.5-flash, which is what the notes below describe.

Why this shape:
  - zhipu rate-limits (HTTP 429 / code 1302) under concurrency or rapid-fire and
    then returns EMPTY documents, so calls are STRICTLY SERIAL with a gap.
  - glm-4.5-flash truncates long batched outputs, so keys are packed into chunks
    under a CHAR BUDGET (long strings land in their own small chunk).
  - A chunk that returns empty/partial is retried; on persistent failure it is
    SPLIT in half (down to a single key) so one bad long string can't strand a
    whole language.
Constitution: HelixTranslate engine, provider zhipu (distinct from the doc-batch
mistral translator + cohere reviewer). Independent review runs separately (groq).
Glossary terms are kept verbatim by the model and enforced by audit_ui_glossary.py
(sentinel protection makes this engine return empty output, so it is not used).
Resumable: only missing/empty keys are (re)translated.
"""
import json, os, re, subprocess, sys, tempfile, time

GEN = os.path.dirname(os.path.abspath(__file__))
# Repo root DERIVED from this script's own location (…/_tools/gen/…), never
# hardcoded, so paths reproduce from a clean clone (§11.4.77).
REPO = os.path.dirname(os.path.dirname(GEN))
# HelixTranslate engine: default to the REPO-RELATIVE committed entrypoint
# (_tools/helixtranslate-container.sh), NEVER an ephemeral /tmp path (§11.4.77).
# Override with HELIX_BIN=<path> for a local engine binary.
ENGINE = os.environ.get("HELIX_BIN", os.path.join(REPO, "_tools", "helixtranslate-container.sh"))
# UI_KEY/UI_BASEURL let two instances target INDEPENDENT zhipu-family accounts
# (open.bigmodel.cn via ZHIPU_API_KEY, api.z.ai via ZAI_API_KEY) so concurrency
# across them does not hit a shared rate limit.
ZHIPU_KEY = os.environ.get("UI_KEY") or os.environ.get("ZHIPU_API_KEY", "")
BASEURL = os.environ.get("UI_BASEURL", "")
# Engine provider/model DERIVED from the environment (AUDIT.md F15). The
# defaults are the exact literals this pipeline has always used, so an unset
# environment reproduces the previous behaviour byte for byte; a retired or
# rate-capped model is then swapped without editing this file.
PROVIDER = os.environ.get("UI_TRANSLATOR_PROVIDER", "zhipu")
MODEL = os.environ.get("UI_TRANSLATOR_MODEL", "glm-4.5-flash")
LANGS = sys.argv[1:] or ["ru", "kk", "hi", "ja", "ko", "tr", "fa", "ar"]
GAP = float(os.environ.get("UI_GAP", "14"))
BUDGET = int(os.environ.get("UI_BUDGET", "420"))
MARK = re.compile(r"^\s*\[\[(\d+)\]\]\s*(.*)$")
ARTIFACTS = {"contents","содержание","мазмұн","мазмұны","内容","目录","목차","फ़हरिस्त","विषय-सूची",
             "المحتوى","المحتويات","فهرست","içindekiler","içerik","змест","contenido","índice","목 차"}

def script_for(lang):
    if lang in ("ru", "be", "kk"): return "cyrillic"
    if lang in ("ar", "fa"): return "arabic"
    return "default" if lang in ("zh", "ja", "ko", "hi") else "latin"

def parse(raw):
    out, cur = {}, None
    for line in raw.splitlines():
        m = MARK.match(line)
        if m:
            cur = int(m.group(1)); out[cur] = m.group(2).strip()
        elif cur is not None and line.strip():
            out[cur] = (out[cur] + " " + line.strip()).strip()
    return out

def call_engine(doc, lang):
    with tempfile.TemporaryDirectory() as d:
        inp, outp = f"{d}/in.md", f"{d}/out.md"
        open(inp, "w").write(doc + "\n")
        cmd = [ENGINE, "-i", inp, "-o", outp, "-provider", PROVIDER,
               "-model", MODEL, "-api-key", ZHIPU_KEY,
               "-source-lang", "en", "-target-lang", lang,
               "-script", script_for(lang), "-verify=false", "-timeout", "120s"]
        if BASEURL:
            cmd += ["-base-url", BASEURL]
        p = subprocess.run(cmd, capture_output=True, text=True)
        if p.returncode == 0 and os.path.exists(outp) and os.path.getsize(outp) > 1:
            return open(outp).read()
        return ""

def translate_chunk(keys, en, lang, depth=0):
    """Return {key: translation} for the chunk; split-and-retry on failure."""
    doc = "\n".join(f"[[{i}]] {en[k]}" for i, k in enumerate(keys))
    for attempt in range(3):
        raw = call_engine(doc, lang)
        idx = parse(raw)
        got = {}
        for i, k in enumerate(keys):
            if i in idx:
                v = idx[i].strip()
                if v and v.lower() not in ARTIFACTS:
                    got[k] = v
        if len(got) == len(keys):
            return got
        time.sleep(GAP + 6 * attempt)
    # persistent partial/empty: keep whatever parsed, split the rest
    doc_got = got if 'got' in dir() else {}
    remaining = [k for k in keys if k not in doc_got]
    if len(keys) > 1 and remaining:
        mid = len(remaining) // 2 or 1
        for half in (remaining[:mid], remaining[mid:]):
            if half:
                time.sleep(GAP)
                doc_got.update(translate_chunk(half, en, lang, depth + 1))
    return doc_got

def chunks_for(keys, en):
    out, cur, tot = [], [], 0
    for k in keys:
        l = len(en[k])
        if cur and tot + l > BUDGET:
            out.append(cur); cur, tot = [], 0
        cur.append(k); tot += l
    if cur: out.append(cur)
    return out

def main():
    if not ZHIPU_KEY:
        print("FATAL: ZHIPU_API_KEY missing", file=sys.stderr); sys.exit(2)
    en = json.load(open(f"{GEN}/ui-i18n.en.json"))
    keys = list(en.keys())
    for lang in LANGS:
        f = f"{GEN}/ui-i18n.{lang}.json"
        cur = json.load(open(f)) if os.path.exists(f) else {}
        missing = [k for k in keys if not str(cur.get(k, "")).strip()]
        if not missing:
            print(f"[{lang}] complete", flush=True); continue
        print(f"[{lang}] {len(missing)} missing in {len(chunks_for(missing, en))} chunks", flush=True)
        for ch in chunks_for(missing, en):
            got = translate_chunk(ch, en, lang)
            cur.update({k: v for k, v in got.items() if str(v).strip()})
            ordered = {k: cur[k] for k in keys if str(cur.get(k, "")).strip()}
            json.dump(ordered, open(f, "w"), ensure_ascii=False, indent=2)
            print(f"  [{lang}] chunk {len(ch)} -> +{len(got)} (total {len(ordered)}/{len(keys)})", flush=True)
            time.sleep(GAP)
        still = [k for k in keys if not str(cur.get(k, "")).strip()]
        print(f"[{lang}] DONE {len(keys)-len(still)}/{len(keys)} still={still}", flush=True)
    print("CHUNKED-DONE", flush=True)

if __name__ == "__main__":
    main()
