#!/usr/bin/env python3
"""Glossary-term repair pass for the UI dictionary.

The base translation runs WITHOUT Z9TERM glossary sentinels (those make the
zhipu/glm engine emit an empty document). The model keeps most Latin terms but
transliterates a few (e.g. "Server Factory", "Vasic Digital", language names),
which the independent reviewer correctly flags as terms_preserved violations.

This pass RE-TRANSLATES only the term-dense keys, protecting each glossary term
with a `[[T<n>]]` sentinel — the SAME bracket form the model already preserves
verbatim for the `[[<i>]]` line markers (unlike Z9TERM, which it drops). After
translation the sentinels are restored to the exact glossary term, GUARANTEEING
verbatim preservation. A key is only overwritten when every required term ends
up present; otherwise the prior value is kept (fail loud, never worse).

One engine call per language (all term-dense keys batched). UI_KEY/UI_BASEURL
select the zhipu-family account (bigmodel or z.ai)."""
import json, os, re, subprocess, sys, tempfile

GEN = os.path.dirname(os.path.abspath(__file__))
# Repo root DERIVED from this script's own location (…/_tools/gen/…), never
# hardcoded, so paths reproduce from a clean clone (§11.4.77).
REPO = os.path.dirname(os.path.dirname(GEN))
GLOSSARY = f"{GEN}/../translate/glossary.json"
# HelixTranslate engine: default to the REPO-RELATIVE committed entrypoint
# (_tools/helixtranslate-container.sh), NEVER an ephemeral /tmp path (§11.4.77).
# Override with HELIX_BIN=<path> for a local engine binary.
ENGINE = os.environ.get("HELIX_BIN", os.path.join(REPO, "_tools", "helixtranslate-container.sh"))
KEY = os.environ.get("UI_KEY") or os.environ.get("ZHIPU_API_KEY", "")
BASEURL = os.environ.get("UI_BASEURL", "")
LANGS = sys.argv[1:] or ["ru", "sr", "de", "es", "fr", "be", "zh", "kk", "hi", "ja", "ko", "ar", "tr", "fa"]
LINE = re.compile(r"^\s*\[\[(\d+)\]\]\s*(.*)$")
TERMSENT = re.compile(r"\[\[T(\d+)\]\]")

def script_for(lang):
    if lang in ("ru", "be", "kk"): return "cyrillic"
    if lang in ("ar", "fa"): return "arabic"
    return "default" if lang in ("zh", "ja", "ko", "hi") else "latin"

def load_terms():
    g = json.load(open(GLOSSARY)); terms = []
    for v in g.values():
        if isinstance(v, list): terms += [t for t in v if isinstance(t, str) and t]
    terms.sort(key=lambda s: (-len(s), s))
    return terms

def occurs(term, text):
    return re.search(r"(?<![A-Za-z0-9])" + re.escape(term) + r"(?![A-Za-z0-9])", text) is not None

def protect_terms(text, terms, term2id):
    for t in terms:
        if occurs(t, text):
            if t not in term2id:
                term2id[t] = len(term2id)
            text = re.sub(r"(?<![A-Za-z0-9])" + re.escape(t) + r"(?![A-Za-z0-9])",
                          f"[[T{term2id[t]}]]", text)
    return text

def call(doc, lang):
    with tempfile.TemporaryDirectory() as d:
        inp, outp = f"{d}/in.md", f"{d}/out.md"
        open(inp, "w").write(doc + "\n")
        cmd = [ENGINE, "-i", inp, "-o", outp, "-provider", "zhipu", "-model", "glm-4.5-flash",
               "-api-key", KEY, "-source-lang", "en", "-target-lang", lang,
               "-script", script_for(lang), "-verify=false", "-timeout", "120s"]
        if BASEURL: cmd += ["-base-url", BASEURL]
        p = subprocess.run(cmd, capture_output=True, text=True)
        if p.returncode == 0 and os.path.exists(outp) and os.path.getsize(outp) > 1:
            return open(outp).read()
        return ""

def main():
    if not KEY:
        print("FATAL: no key", file=sys.stderr); sys.exit(2)
    terms = load_terms()
    en = json.load(open(f"{GEN}/ui-i18n.en.json"))
    # term-dense keys: any EN string containing a glossary term
    term_keys = [k for k in en if any(occurs(t, en[k]) for t in terms)]
    for lang in LANGS:
        f = f"{GEN}/ui-i18n.{lang}.json"
        if not os.path.exists(f):
            print(f"[{lang}] no file, skip", flush=True); continue
        cur = json.load(open(f))
        # which of the term-dense keys currently violate (a required term missing)?
        need = []
        for k in term_keys:
            req = [t for t in terms if occurs(t, en[k])]
            tr = cur.get(k, "")
            if tr and any(not occurs(t, tr) for t in req):
                need.append(k)
        if not need:
            print(f"[{lang}] no term violations", flush=True); continue
        term2id = {}
        lines = [f"[[{i}]] {protect_terms(en[k], terms, term2id)}" for i, k in enumerate(need)]
        id2term = {v: k for k, v in term2id.items()}
        raw = call("\n".join(lines), lang)
        # parse
        idx, curline = {}, None
        for ln in raw.splitlines():
            m = LINE.match(ln)
            if m:
                curline = int(m.group(1)); idx[curline] = m.group(2)
            elif curline is not None and ln.strip():
                idx[curline] += " " + ln.strip()
        fixed = 0
        for i, k in enumerate(need):
            if i not in idx: continue
            val = TERMSENT.sub(lambda mm: id2term.get(int(mm.group(1)), mm.group(0)), idx[i]).strip()
            req = [t for t in terms if occurs(t, en[k])]
            if val and all(occurs(t, val) for t in req):
                cur[k] = val; fixed += 1
        keys = list(en.keys())
        ordered = {k: cur[k] for k in keys if str(cur.get(k, "")).strip()}
        json.dump(ordered, open(f, "w"), ensure_ascii=False, indent=2)
        print(f"[{lang}] repaired {fixed}/{len(need)} term-dense keys", flush=True)
    print("REPAIR-DONE", flush=True)

if __name__ == "__main__":
    main()
