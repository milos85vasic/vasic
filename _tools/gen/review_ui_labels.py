#!/usr/bin/env python3
"""Independent review (§11.4.141) of the machine-translated UI status labels by a
DIFFERENT provider/model than the translator (translator=zhipu/glm-4.5-flash;
reviewer=groq/llama-3.3-70b-versatile). For each language the reviewer is shown
the EN term + its current translation and asked to CORRECT only clearly-wrong or
awkward ones (software-lifecycle sense), returning JSON. Conservative: unchanged
unless the reviewer supplies a different, non-empty value. Writes corrections back
to ui-i18n.json and prints an audit of every change.

  GROQ_API_KEY=... python3 _tools/gen/review_ui_labels.py [lang ...]
"""
import json, os, sys, urllib.request

GEN = os.path.dirname(os.path.abspath(__file__))
MASTER = f"{GEN}/ui-i18n.json"
GROQ_KEY = os.environ.get("GROQ_API_KEY", "")
MODEL = os.environ.get("REVIEW_MODEL", "llama-3.3-70b-versatile")
STATUS = ["active", "beta", "in-development", "mixed", "production",
          "roadmap", "scaffold", "shipped", "stable"]
SENSE = {"active": "actively worked on", "beta": "beta test stage",
         "in-development": "under development", "mixed": "mixed status",
         "production": "running in production", "roadmap": "planned on the roadmap",
         "scaffold": "initial scaffold/skeleton", "shipped": "released/shipped to users",
         "stable": "stable release"}
LANG_NAMES = {"ru": "Russian", "sr": "Serbian", "de": "German", "es": "Spanish",
              "fr": "French", "be": "Belarusian", "zh": "Chinese", "kk": "Kazakh",
              "hi": "Hindi", "ja": "Japanese", "ko": "Korean", "ar": "Arabic",
              "tr": "Turkish", "fa": "Persian"}
LANGS = sys.argv[1:] or list(LANG_NAMES)


def groq(prompt):
    body = json.dumps({
        "model": MODEL, "temperature": 0,
        "messages": [{"role": "user", "content": prompt}],
        "response_format": {"type": "json_object"},
    }).encode()
    req = urllib.request.Request(
        "https://api.groq.com/openai/v1/chat/completions", data=body,
        headers={"Authorization": f"Bearer {GROQ_KEY}", "Content-Type": "application/json",
                 "User-Agent": "curl/8.4.0"})  # Cloudflare 403s the default urllib UA
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read())["choices"][0]["message"]["content"]


def review_lang(lang, block):
    cur = {s: block.get(f"status.{s}", "") for s in STATUS}
    lines = "\n".join(f'- "{s}" ({SENSE[s]}) currently: "{cur[s]}"' for s in STATUS)
    prompt = (
        f"You are a senior {LANG_NAMES.get(lang, lang)} software-localization reviewer. "
        f"Below are English software project status labels with their current "
        f"{LANG_NAMES.get(lang, lang)} translations. For EACH, if the current translation is "
        f"WRONG, awkward, or the wrong sense for software, give the correct concise "
        f"{LANG_NAMES.get(lang, lang)} term; otherwise repeat the current value unchanged. "
        f'Return ONLY a JSON object mapping each english key to the final {LANG_NAMES.get(lang, lang)} '
        f"value (keys exactly: {', '.join(STATUS)}).\n\n{lines}")
    try:
        out = json.loads(groq(prompt))
    except Exception as e:
        print(f"  [{lang}] review error: {e}", flush=True)
        return 0
    changed = 0
    for s in STATUS:
        new = str(out.get(s, "")).strip()
        old = str(cur[s]).strip()
        if new and new != old:
            block[f"status.{s}"] = new
            print(f"    {lang} status.{s}: {old!r} -> {new!r}", flush=True)
            changed += 1
    return changed


def main():
    if not GROQ_KEY:
        print("GROQ_API_KEY not set", file=sys.stderr); sys.exit(2)
    d = json.load(open(MASTER, encoding="utf-8"))
    en_order = list(d["en"].keys())
    total = 0
    for lang in LANGS:
        block = d.get(lang)
        if not block:
            continue
        c = review_lang(lang, block)
        d[lang] = {k: block[k] for k in en_order if k in block and str(block[k]).strip()}
        print(f"  [{lang}] reviewed: {c} correction(s)", flush=True)
        total += c
        json.dump(d, open(MASTER, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
    print(f"DONE: {total} corrections by {MODEL} (reviewer != translator zhipu)", flush=True)


if __name__ == "__main__":
    main()
