#!/usr/bin/env python3
"""Rate-limit-respecting UI translator: ONE request at a time, ALTERNATING between
two independent zhipu-family accounts (open.bigmodel.cn via ZHIPU_API_KEY and
api.z.ai via ZAI_API_KEY) so each account is hit at half the global rate and
stays under its RPM cap. No inner retry storms (they trip 1302); reliability comes
from a slow OUTER convergence loop that re-does only still-missing keys.

Keys are packed into char-budget chunks so glm-4.5-flash does not truncate long
batches. Resumable + glossary terms kept verbatim by the model (enforced later by
audit_ui_glossary.py / repaired by repair_ui_terms.py). Serial, gapped, boring —
which is exactly what the free tier tolerates."""
import json, os, re, subprocess, sys, tempfile, time

GEN = os.path.dirname(os.path.abspath(__file__))
ENGINE = "/tmp/helixtranslate"
LANGS = sys.argv[1:] or ["ru", "kk", "hi", "ja", "ko", "tr", "fa", "ar"]
GAP = float(os.environ.get("UI_GAP", "20"))
BUDGET = int(os.environ.get("UI_BUDGET", "480"))
PASSES = int(os.environ.get("UI_PASSES", "6"))
MARK = re.compile(r"^\s*\[\[(\d+)\]\]\s*(.*)$")

# Rotating pool of (api_key, base_url) across independent accounts.
ACCOUNTS = []
if os.environ.get("ZAI_API_KEY"):
    ACCOUNTS.append((os.environ["ZAI_API_KEY"], "https://api.z.ai/api/paas/v4"))
if os.environ.get("ZHIPU_API_KEY"):
    ACCOUNTS.append((os.environ["ZHIPU_API_KEY"], ""))
_rot = {"i": 0}

def script_for(lang):
    if lang in ("ru", "be", "kk"): return "cyrillic"
    if lang in ("ar", "fa"): return "arabic"
    return "default" if lang in ("zh", "ja", "ko", "hi") else "latin"

def call(doc, lang):
    key, base = ACCOUNTS[_rot["i"] % len(ACCOUNTS)]
    _rot["i"] += 1
    with tempfile.TemporaryDirectory() as d:
        inp, outp = f"{d}/in.md", f"{d}/out.md"
        open(inp, "w").write(doc + "\n")
        cmd = [ENGINE, "-i", inp, "-o", outp, "-provider", "zhipu", "-model", "glm-4.5-flash",
               "-api-key", key, "-source-lang", "en", "-target-lang", lang,
               "-script", script_for(lang), "-verify=false", "-timeout", "120s"]
        if base: cmd += ["-base-url", base]
        p = subprocess.run(cmd, capture_output=True, text=True)
        if p.returncode == 0 and os.path.exists(outp) and os.path.getsize(outp) > 1:
            return open(outp).read()
        return ""

def parse(raw):
    out, cur = {}, None
    for line in raw.splitlines():
        m = MARK.match(line)
        if m:
            cur = int(m.group(1)); out[cur] = m.group(2).strip()
        elif cur is not None and line.strip():
            out[cur] = (out[cur] + " " + line.strip()).strip()
    return out

def chunks(keys, en):
    out, cur, tot = [], [], 0
    for k in keys:
        if cur and tot + len(en[k]) > BUDGET:
            out.append(cur); cur, tot = [], 0
        cur.append(k); tot += len(en[k])
    if cur: out.append(cur)
    return out

def main():
    if not ACCOUNTS:
        print("FATAL: no account keys", file=sys.stderr); sys.exit(2)
    en = json.load(open(f"{GEN}/ui-i18n.en.json"))
    keys = list(en.keys())
    for p in range(PASSES):
        anymissing = False
        for lang in LANGS:
            f = f"{GEN}/ui-i18n.{lang}.json"
            cur = json.load(open(f)) if os.path.exists(f) else {}
            missing = [k for k in keys if not str(cur.get(k, "")).strip()]
            if not missing:
                continue
            anymissing = True
            for ch in chunks(missing, en):
                doc = "\n".join(f"[[{i}]] {en[k]}" for i, k in enumerate(ch))
                raw = call(doc, lang)
                idx = parse(raw)
                got = 0
                for i, k in enumerate(ch):
                    if i in idx and idx[i].strip():
                        cur[k] = idx[i].strip(); got += 1
                ordered = {k: cur[k] for k in keys if str(cur.get(k, "")).strip()}
                json.dump(ordered, open(f, "w"), ensure_ascii=False, indent=2)
                print(f"[p{p}][{lang}] chunk{len(ch)} +{got} -> {len(ordered)}/{len(keys)}", flush=True)
                time.sleep(GAP)
        if not anymissing:
            print(f"ALL FULL after pass {p}", flush=True); break
    print("SLOW-DONE", flush=True)

if __name__ == "__main__":
    main()
