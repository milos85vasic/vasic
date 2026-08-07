#!/usr/bin/env python3
"""One batched translation call per language on a HEADROOM provider (Groq),
plus an independent review pass on a DIFFERENT model. Self-contained; does NOT
touch mistral/cohere (the running _content batch) nor the chunked pipeline.

Translator : llama-3.3-70b-versatile  (Groq)
Reviewer   : openai/gpt-oss-120b      (Groq, different model)
"""
import json, os, re, sys, time, urllib.request, urllib.error

HERE = os.path.dirname(os.path.abspath(__file__))
UI = os.path.join(HERE, "ui-i18n.json")
EV = os.path.abspath(os.path.join(HERE, "..", "..", "_tests", "evidence", "ui-l10n2"))
REV = os.path.join(EV, "reviews")
os.makedirs(REV, exist_ok=True)

GROQ = os.environ["GROQ_API_KEY"]
CEREBRAS = os.environ["CEREBRAS_API_KEY"]
GROQ_URL = "https://api.groq.com/openai/v1/chat/completions"
CEREBRAS_URL = "https://api.cerebras.ai/v1/chat/completions"
TRANSLATOR = "llama-3.3-70b-versatile"        # Groq
REVIEWER = "gpt-oss-120b"                       # Cerebras (different model + provider)

LANGS = {
    "ru": "Russian", "sr": "Serbian (Cyrillic script)", "es": "Spanish",
    "fr": "French", "be": "Belarusian", "zh": "Simplified Chinese",
    "kk": "Kazakh (Cyrillic script)", "hi": "Hindi", "ja": "Japanese",
    "ko": "Korean", "ar": "Arabic", "tr": "Turkish", "fa": "Persian (Farsi)",
}

PRESERVE = [
    "HelixCode", "HelixTrack", "HelixAgent", "HelixLLM", "HelixMemory",
    "HelixQA", "Helix", "Vasic Digital", "Miloš Vasić", "Server Factory",
    "OpenDesign", "PDF", "SDK", "LLM", "KMP", "Go", "Kotlin", "TypeScript",
    "React", "Python", "Swift", "Shell", "QA",
]

# target-script sanity ranges
SCRIPTS = {
    "cyr": (0x0400, 0x04FF),
    "cjk": (0x4E00, 0x9FFF),
    "hira": (0x3040, 0x309F), "kata": (0x30A0, 0x30FF),
    "hang": (0xAC00, 0xD7A3),
    "arab": (0x0600, 0x06FF),
    "deva": (0x0900, 0x097F),
}
SCRIPT_FOR = {
    "ru": ["cyr"], "sr": ["cyr"], "be": ["cyr"], "kk": ["cyr"],
    "zh": ["cjk"], "ja": ["cjk", "hira", "kata"], "ko": ["hang"],
    "ar": ["arab"], "fa": ["arab"], "hi": ["deva"],
}


def has_script(s, keys):
    lo_hi = [SCRIPTS[k] for k in keys]
    for ch in s:
        o = ord(ch)
        for lo, hi in lo_hi:
            if lo <= o <= hi:
                return True
    return False


def call(model, system, user, temperature=0.2, retries=5, provider="groq"):
    url = GROQ_URL if provider == "groq" else CEREBRAS_URL
    key = GROQ if provider == "groq" else CEREBRAS
    payload = {
        "model": model,
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ],
        "temperature": temperature,
        "response_format": {"type": "json_object"},
        "max_tokens": 8000,
    }
    if model == "gpt-oss-120b":
        payload["reasoning_effort"] = "low"
    body = json.dumps(payload).encode()
    last = None
    for a in range(retries):
        req = urllib.request.Request(url, data=body, headers={
            "Authorization": "Bearer " + key,
            "Content-Type": "application/json",
            "User-Agent": "curl/8.4.0",
            "Accept": "application/json",
        })
        try:
            with urllib.request.urlopen(req, timeout=120) as r:
                d = json.load(r)
            msg = d["choices"][0]["message"]
            content = msg.get("content") or ""
            if not content.strip():
                last = "empty content (finish=%s)" % d["choices"][0].get("finish_reason")
                time.sleep(3 * (a + 1))
                continue
            return content
        except urllib.error.HTTPError as e:
            last = "%s: %s" % (e.code, e.read().decode()[:200])
            time.sleep((20 if e.code == 429 else 3) * (a + 1))
        except Exception as e:
            last = str(e)
            time.sleep(3 * (a + 1))
    raise RuntimeError("call failed for %s: %s" % (model, last))


def parse_json(txt):
    txt = txt.strip()
    m = re.search(r"\{.*\}", txt, re.S)
    if m:
        txt = m.group(0)
    return json.loads(txt)


def translate(lang, name, en, keys):
    preserve = ", ".join(PRESERVE)
    system = (
        "You are a professional software-UI localizer. You translate short website "
        "chrome/UI strings accurately and idiomatically. You ALWAYS return a single "
        "valid JSON object and nothing else."
    )
    user = (
        "Translate the VALUES of the following JSON object from English into %s.\n"
        "Return ONLY a JSON object with EXACTLY the same keys (all %d of them), "
        "each value translated.\n\n"
        "Rules:\n"
        "- PRESERVE these brand/product names and tech acronyms VERBATIM (do not "
        "translate or transliterate them): %s.\n"
        "- Keys 'kw.vasic' and 'kw.milos' are SEO keyword lists: translate them into "
        "natural, comma-separated %s search keywords (keep tech acronyms/brands as-is).\n"
        "- Keep any punctuation like em dashes, parentheses, and '(PDF)'.\n"
        "- Do not add explanations. Output must be valid JSON.\n\n"
        "JSON to translate:\n%s"
        % (name, len(keys), preserve, name, json.dumps(en, ensure_ascii=False, indent=2))
    )
    txt = call(TRANSLATOR, system, user)
    return parse_json(txt)


def review(lang, name, en, tr, keys):
    system = (
        "You are a strict bilingual localization reviewer. Verify a machine translation "
        "for accuracy, naturalness, completeness, correct target script, and that brand/"
        "product names were preserved. Return ONLY a JSON object: "
        '{"verdict":"PASS"|"FAIL", "bad_keys":[...], "notes":"..."}. '
        "List in bad_keys any key whose value is wrong, left in English (except preserved "
        "brand terms), empty, in the wrong script, or unnatural."
    )
    pairs = {k: {"en": en[k], name.split()[0]: tr.get(k, "")} for k in keys}
    user = (
        "Target language: %s. Preserved-verbatim terms are allowed to remain in Latin "
        "script: %s.\nReview these EN -> translation pairs and return the JSON verdict.\n\n%s"
        % (name, ", ".join(PRESERVE), json.dumps(pairs, ensure_ascii=False, indent=2))
    )
    txt = call(REVIEWER, system, user, temperature=0.0, provider="cerebras")
    try:
        return parse_json(txt)
    except Exception:
        return {"verdict": "UNKNOWN", "bad_keys": [], "notes": txt[:300]}


def retry_key(lang, name, key, en_val, guidance=""):
    system = "You are a professional UI localizer. Return ONLY a JSON object {\"value\": \"...\"}."
    g = ("\nReviewer feedback to address: " + guidance) if guidance else ""
    user = (
        "Translate this single UI string from English to %s. Preserve brand/tech terms "
        "verbatim (%s). Use natural, idiomatic wording.%s\n"
        "Return {\"value\": \"<translation>\"} only.\n\nEnglish: %s"
        % (name, ", ".join(PRESERVE), g, json.dumps(en_val, ensure_ascii=False))
    )
    try:
        d = parse_json(call(TRANSLATOR, system, user, temperature=0.2))
        return d.get("value", "")
    except Exception:
        return ""


def main():
    data = json.load(open(UI, encoding="utf-8"))
    en = data["en"]
    keys = list(en.keys())
    out = {}
    summary = {}

    for lang, name in LANGS.items():
        print("=== %s (%s) ===" % (lang, name), flush=True)
        tr = translate(lang, name, en, keys)
        # ensure all keys present & non-empty
        for k in keys:
            v = tr.get(k, "")
            if not isinstance(v, str) or not v.strip():
                tr[k] = retry_key(lang, name, k, en[k]) or en[k]
        # script sanity check -> auto-flag
        script_keys = SCRIPT_FOR.get(lang)
        script_bad = []
        if script_keys:
            for k in keys:
                if k.startswith("kw."):
                    continue  # keyword lists legitimately mix latin brand terms
                v = tr[k]
                # strip preserved terms then check remaining chars
                stripped = v
                for p in PRESERVE:
                    stripped = stripped.replace(p, "")
                letters = [c for c in stripped if c.isalpha()]
                if letters and not has_script(v, script_keys):
                    script_bad.append(k)
        # LLM review
        verdict = review(lang, name, en, tr, keys)
        bad = set(verdict.get("bad_keys", []) or []) | set(script_bad)
        bad = [k for k in bad if k in keys]
        # retry bad keys once (pass reviewer notes as guidance)
        guidance = verdict.get("notes", "") or ""
        retried = {}
        for k in bad:
            nv = retry_key(lang, name, k, en[k], guidance)
            if nv and nv.strip():
                tr[k] = nv
                retried[k] = nv
        # re-check script after retry
        still_bad = []
        if script_keys:
            for k in bad:
                if k.startswith("kw."):
                    continue
                if not has_script(tr[k], script_keys):
                    still_bad.append(k)
        rec = {
            "lang": lang, "name": name,
            "translator": TRANSLATOR, "reviewer": REVIEWER,
            "verdict": verdict.get("verdict", "UNKNOWN"),
            "reviewer_bad_keys": verdict.get("bad_keys", []),
            "script_flagged": script_bad,
            "retried_keys": list(retried.keys()),
            "still_bad_after_retry": still_bad,
            "notes": verdict.get("notes", ""),
        }
        json.dump(rec, open(os.path.join(REV, lang + ".json"), "w", encoding="utf-8"),
                  ensure_ascii=False, indent=2)
        out[lang] = tr
        summary[lang] = {"verdict": rec["verdict"], "script_flagged": script_bad,
                         "retried": list(retried.keys()), "still_bad": still_bad}
        print("   verdict=%s script_flagged=%s retried=%s still_bad=%s"
              % (rec["verdict"], script_bad, list(retried.keys()), still_bad), flush=True)

    # merge: keep en + de, add 13, preserve en key order for each lang
    merged = {"en": en}
    if "de" in data:
        merged["de"] = data["de"]
    for lang in LANGS:
        merged[lang] = {k: out[lang][k] for k in keys}

    json.dump(merged, open(UI, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
    open(os.path.join(EV, "summary.json"), "w", encoding="utf-8").write(
        json.dumps(summary, ensure_ascii=False, indent=2))
    print("\nWROTE", UI, "langs:", list(merged.keys()))
    print("SUMMARY:", json.dumps(summary, ensure_ascii=False))


if __name__ == "__main__":
    main()
