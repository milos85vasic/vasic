#!/usr/bin/env python3
"""Surgically fill the 14 UI keys that leak English on non-EN pages, translating
ONLY the missing keys directly into the embedded master ui-i18n.json (no staging,
no merge_ui clobber). Constitution-compliant (§11.4.140): every value comes from
the HelixTranslate engine (HELIX_BIN), never hand-typed; glossary terms are
sentinel-protected; FAIL LOUD — an engine failure leaves the key absent (Go falls
back to EN) and is never silently replaced by English. Resumable: existing
non-empty keys are skipped.

  HELIX_BIN=_tools/helixtranslate-local.sh ZHIPU_API_KEY=... \
      python3 _tools/gen/fill_missing_ui_keys.py [lang ...]
"""
import json, os, re, subprocess, sys, tempfile

GEN = os.path.dirname(os.path.abspath(__file__))
TOOLS = os.path.dirname(GEN)
MASTER = f"{GEN}/ui-i18n.json"
ENGINE = os.environ.get("HELIX_BIN", os.path.join(TOOLS, "helixtranslate-local.sh"))
PROTECT = f"{TOOLS}/translate/glossary_protect.py"
GLOSSARY = f"{TOOLS}/translate/glossary.json"
PROVIDER = os.environ.get("UI_PROVIDER", "zhipu")
MODEL = os.environ.get("UI_MODEL", "glm-4.5-flash")
APIKEY = os.environ.get("ZHIPU_API_KEY", "")

KEYS = ["alt.brandLogo", "alt.portrait",
        "status.active", "status.beta", "status.in-development", "status.mixed",
        "status.production", "status.roadmap", "status.scaffold", "status.shipped",
        "status.stable",
        "tier.helix-primary", "tier.serverfactory-tertiary", "tier.vasic-util-secondary"]
LANGS = sys.argv[1:] or ["ru", "sr", "de", "es", "fr", "be", "zh", "kk", "hi", "ja", "ko", "ar", "tr", "fa"]


def script_for(lang):
    if lang in ("ru", "be", "kk", "sr"): return "cyrillic"
    if lang in ("ar", "fa"): return "arabic"
    return "default"


def run(cmd, **kw):
    return subprocess.run(cmd, capture_output=True, text=True, **kw)


def protect(text):
    fd, mp = tempfile.mkstemp(suffix=".json"); os.close(fd)
    p = run(["python3", PROTECT, "protect", "--glossary", GLOSSARY, "--map", mp], input=text)
    return p.stdout, mp


def restore(text, mp):
    p = run(["python3", PROTECT, "restore", "--map", mp], input=text)
    if p.returncode != 0:
        raise RuntimeError(f"restore failed: {p.stderr}")
    return p.stdout


# The engine prepends a localized "Contents"-style heading artifact; strip it
# (mirrors translate_ui_all.py so single-label output isn't polluted).
ARTIFACTS = {"Contents", "Content", "Inhalt", "Inhaltsverzeichnis", "Содержание", "Контент",
             "Sadržaj", "Sadrzaj", "Table des matières", "Table des matieres", "Table des matiere",
             "Contenido", "Contenu", "목차", "目次", "目录", "फ़हरिस्त", "内容", "内容提要",
             "İçerik", "İçindekiler", "Índice", "Indice", "Съдържание", "Мазмұны",
             "المحتوى", "المحتويات", "فهرست", "المحتوى الرئيسي", "Мазмуны"}
_ART_PREFIX = re.compile(
    r"^(?:" + "|".join(re.escape(a) for a in sorted(ARTIFACTS, key=len, reverse=True)) + r")\b[\s:：\-—–]*",
    re.IGNORECASE)


def clean(text):
    lines = list(text.splitlines())
    while lines and (lines[0].strip() == "" or lines[0].strip() in ARTIFACTS):
        lines.pop(0)
    out = " ".join(l.strip() for l in lines if l.strip()).strip()
    new = _ART_PREFIX.sub("", out, count=1).strip()
    return new if new else out


def engine_translate(text, lang):
    prot, mp = protect(text)
    try:
        with tempfile.TemporaryDirectory() as d:
            inp, outp = f"{d}/in.md", f"{d}/out.md"
            with open(inp, "w") as f:
                f.write(prot + "\n")
            last = ""
            for _ in range(3):
                if os.path.exists(outp):
                    os.remove(outp)
                args = [ENGINE, "-i", inp, "-o", outp,
                        "-provider", PROVIDER, "-model", MODEL,
                        "-source-lang", "en", "-target-lang", lang, "-script", script_for(lang)]
                if APIKEY:
                    args += ["-api-key", APIKEY]
                p = run(args)
                if p.returncode == 0 and os.path.exists(outp) and os.path.getsize(outp) > 0:
                    with open(outp) as f:
                        raw = f.read()
                    out = clean(restore(raw, mp))
                    if out:
                        return out
                last = (p.stderr or p.stdout or "")[-300:]
            raise RuntimeError(f"engine failed for {lang} on {text!r}: {last}")
    finally:
        if os.path.exists(mp):
            os.unlink(mp)


def _write(master, en_order):
    for lang in list(master.keys()):
        if lang == "en":
            continue
        b = master[lang]
        master[lang] = {k: b[k] for k in en_order if k in b and str(b[k]).strip()}
    json.dump(master, open(MASTER, "w", encoding="utf-8"), ensure_ascii=False, indent=2)


def main():
    from concurrent.futures import ThreadPoolExecutor, as_completed
    import threading
    master = json.load(open(MASTER, encoding="utf-8"))
    en = master["en"]
    en_order = list(en.keys())
    pairs = [(lang, k) for lang in LANGS for k in KEYS
             if not str(master.get(lang, {}).get(k, "")).strip() and en.get(k, "").strip()]
    print(f"{len(pairs)} missing (lang,key) pairs to translate "
          f"(workers={os.environ.get('UI_WORKERS', '5')})", flush=True)
    lock = threading.Lock()
    done = 0
    workers = int(os.environ.get("UI_WORKERS", "5"))
    with ThreadPoolExecutor(max_workers=workers) as ex:
        futs = {ex.submit(engine_translate, en[k], lang): (lang, k) for (lang, k) in pairs}
        for fut in as_completed(futs):
            lang, k = futs[fut]
            try:
                val = fut.result()
            except Exception as e:
                print(f"  FAIL {lang}/{k}: {e}", flush=True)
                continue
            with lock:
                master.setdefault(lang, {})[k] = val
                done += 1
                n = done
                if done % 10 == 0:
                    _write(master, en_order)  # periodic crash-safe checkpoint
            print(f"  [{n}/{len(pairs)}] {lang} {k} = {val!r}", flush=True)
    _write(master, en_order)
    print(f"WROTE {MASTER}: {done}/{len(pairs)} new translations", flush=True)


if __name__ == "__main__":
    main()
