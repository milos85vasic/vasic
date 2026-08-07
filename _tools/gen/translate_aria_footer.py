#!/usr/bin/env python3
"""Translate the remaining chrome strings (footer suffix + aria-labels/titles)
into all languages on a HEADROOM provider (Groq translate + Cerebras review),
mirroring translate_ui_headroom.py. Self-contained: does NOT touch _content*/
nor _tools/translate/. Writes a combined translations file + per-lang review
verdicts under _tests/evidence/aria-footer-l10n/. A separate merge step wires
the values into the three destinations.
"""
import json, os, re, time, urllib.request, urllib.error

HERE = os.path.dirname(os.path.abspath(__file__))
EV = os.path.abspath(os.path.join(HERE, "..", "..", "_tests", "evidence", "aria-footer-l10n"))
REV = os.path.join(EV, "reviews")
os.makedirs(REV, exist_ok=True)

GROQ = os.environ["GROQ_API_KEY"]
CEREBRAS = os.environ["CEREBRAS_API_KEY"]
GROQ_URL = "https://api.groq.com/openai/v1/chat/completions"
CEREBRAS_URL = "https://api.cerebras.ai/v1/chat/completions"
# Groq's llama-3.3-70b hit its per-day token cap (exhausted by the prior UI
# runs), so translation falls back to the next headroom provider: Cerebras.
# Reviewer stays a DIFFERENT model (gpt-oss-120b) on the same headroom provider.
TRANSLATOR = "zai-glm-4.7"               # Cerebras (Groq 70b hit its per-day cap)
TRANSLATOR_PROVIDER = "cerebras"
REVIEWER = "gpt-oss-120b"               # Cerebras (different model)

# en source of truth for the 9 remaining chrome keys
EN = {
    "footer.text": "Belgrade · Dubna. Built as a static site, deployed on GitHub Pages.",
    "aria.changeLang": "Change language",
    "aria.toggleTheme": "Toggle dark / light theme",
    "aria.menu": "Menu",
    "aria.close": "Close",
    "aria.backToTop": "Back to top",
    "aria.primaryNav": "Primary",
    "title.language": "Language",
    "title.theme": "Theme",
}
KEYS = list(EN.keys())

# de is included (destinations lack these keys for de too), en is the source.
LANGS = {
    "de": "German",
    "ru": "Russian", "sr": "Serbian (Cyrillic script)", "es": "Spanish",
    "fr": "French", "be": "Belarusian", "zh": "Simplified Chinese",
    "kk": "Kazakh (Cyrillic script)", "hi": "Hindi", "ja": "Japanese",
    "ko": "Korean", "ar": "Arabic", "tr": "Turkish", "fa": "Persian (Farsi)",
}

PRESERVE = ["Belgrade", "Dubna", "GitHub Pages", "GitHub", "OpenDesign",
            "Vasic Digital", "Miloš Vasić", "PDF", "SDK"]

SCRIPTS = {
    "cyr": (0x0400, 0x04FF), "cjk": (0x4E00, 0x9FFF),
    "hira": (0x3040, 0x309F), "kata": (0x30A0, 0x30FF),
    "hang": (0xAC00, 0xD7A3), "arab": (0x0600, 0x06FF), "deva": (0x0900, 0x097F),
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
        "max_tokens": 4000,
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


def translate(name):
    preserve = ", ".join(PRESERVE)
    system = (
        "You are a professional software-UI localizer. You translate short website "
        "chrome / accessibility label strings accurately and idiomatically. You "
        "ALWAYS return a single valid JSON object and nothing else."
    )
    user = (
        "Translate the VALUES of the following JSON object from English into %s.\n"
        "Return ONLY a JSON object with EXACTLY the same keys (all %d of them), each "
        "value translated.\n\n"
        "Context of the keys:\n"
        "- 'footer.text' is a website footer sentence.\n"
        "- 'aria.*' are ARIA accessibility labels for interactive controls "
        "(a language switcher, a theme toggle, a menu button, a close button, a "
        "back-to-top button, and the primary navigation landmark). 'aria.primaryNav' "
        "labels the main navigation region; translate it as the adjective/noun a "
        "screen reader would announce (e.g. 'Primary').\n"
        "- 'title.*' are short tooltip/title attributes.\n\n"
        "Rules:\n"
        "- PRESERVE these proper nouns / tech terms VERBATIM (do NOT translate or "
        "transliterate): %s.\n"
        "- Keep the punctuation and structure of 'footer.text' (the middle dot "
        "'·' and the two sentences); only translate the non-proper-noun words.\n"
        "- Keep it concise and natural for UI. No explanations. Output valid JSON only.\n\n"
        "JSON to translate:\n%s"
        % (name, len(KEYS), preserve, json.dumps(EN, ensure_ascii=False, indent=2))
    )
    return parse_json(call(TRANSLATOR, system, user, provider=TRANSLATOR_PROVIDER))


def review(name, tr):
    system = (
        "You are a strict bilingual localization reviewer. Verify a machine "
        "translation for accuracy, naturalness, completeness, correct target script, "
        "and that proper nouns / tech terms were preserved. Return ONLY a JSON object: "
        '{"verdict":"PASS"|"FAIL", "bad_keys":[...], "notes":"..."}. '
        "List in bad_keys any key whose value is wrong, left in English (except the "
        "preserved proper nouns), empty, in the wrong script, or unnatural."
    )
    pairs = {k: {"en": EN[k], "tr": tr.get(k, "")} for k in KEYS}
    user = (
        "Target language: %s. Preserved-verbatim terms allowed to remain in Latin "
        "script: %s.\nReview these EN -> translation pairs and return the JSON verdict.\n\n%s"
        % (name, ", ".join(PRESERVE), json.dumps(pairs, ensure_ascii=False, indent=2))
    )
    txt = call(REVIEWER, system, user, temperature=0.0, provider="cerebras")
    try:
        return parse_json(txt)
    except Exception:
        return {"verdict": "UNKNOWN", "bad_keys": [], "notes": txt[:300]}


def retry_key(name, key, guidance=""):
    system = "You are a professional UI localizer. Return ONLY a JSON object {\"value\": \"...\"}."
    g = ("\nReviewer feedback to address: " + guidance) if guidance else ""
    user = (
        "Translate this single UI/accessibility string from English to %s. Preserve "
        "proper nouns / tech terms verbatim (%s). Natural, concise wording.%s\n"
        "Return {\"value\": \"<translation>\"} only.\n\nEnglish: %s"
        % (name, ", ".join(PRESERVE), g, json.dumps(EN[key], ensure_ascii=False))
    )
    try:
        return parse_json(call(TRANSLATOR, system, user, temperature=0.2, provider=TRANSLATOR_PROVIDER)).get("value", "")
    except Exception:
        return ""


def main():
    TRANS_PATH = os.path.join(EV, "translations.json")
    SUM_PATH = os.path.join(EV, "summary.json")
    # resume: keep any langs already translated in a prior (partial) run
    out = {"en": dict(EN)}
    summary = {}
    if os.path.exists(TRANS_PATH):
        try:
            out.update(json.load(open(TRANS_PATH, encoding="utf-8")))
        except Exception:
            pass
    if os.path.exists(SUM_PATH):
        try:
            summary.update(json.load(open(SUM_PATH, encoding="utf-8")))
        except Exception:
            pass
    for lang, name in LANGS.items():
        if lang in out and all(k in out[lang] and out[lang][k] for k in KEYS):
            print("=== %s (%s) — already done, skipping ===" % (lang, name), flush=True)
            continue
        print("=== %s (%s) ===" % (lang, name), flush=True)
        tr = translate(name)
        for k in KEYS:
            v = tr.get(k, "")
            if not isinstance(v, str) or not v.strip():
                tr[k] = retry_key(name, k) or EN[k]
        # script sanity
        sk = SCRIPT_FOR.get(lang)
        script_bad = []
        if sk:
            for k in KEYS:
                v = tr[k]
                stripped = v
                for p in PRESERVE:
                    stripped = stripped.replace(p, "")
                if [c for c in stripped if c.isalpha()] and not has_script(v, sk):
                    script_bad.append(k)
        verdict = review(name, tr)
        bad = [k for k in (set(verdict.get("bad_keys", []) or []) | set(script_bad)) if k in KEYS]
        guidance = verdict.get("notes", "") or ""
        retried = {}
        for k in bad:
            nv = retry_key(name, k, guidance)
            if nv and nv.strip():
                tr[k] = nv
                retried[k] = nv
        still_bad = []
        if sk:
            for k in bad:
                if not has_script(tr[k], sk):
                    still_bad.append(k)
        rec = {
            "lang": lang, "name": name, "translator": TRANSLATOR, "reviewer": REVIEWER,
            "verdict": verdict.get("verdict", "UNKNOWN"),
            "reviewer_bad_keys": verdict.get("bad_keys", []),
            "script_flagged": script_bad, "retried_keys": list(retried.keys()),
            "still_bad_after_retry": still_bad, "notes": verdict.get("notes", ""),
        }
        json.dump(rec, open(os.path.join(REV, lang + ".json"), "w", encoding="utf-8"),
                  ensure_ascii=False, indent=2)
        out[lang] = {k: tr[k] for k in KEYS}
        summary[lang] = {"verdict": rec["verdict"], "script_flagged": script_bad,
                         "retried": list(retried.keys()), "still_bad": still_bad}
        # write incrementally so a mid-run provider cap never loses finished langs
        json.dump(out, open(TRANS_PATH, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
        json.dump(summary, open(SUM_PATH, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
        print("   verdict=%s script_flagged=%s retried=%s still_bad=%s"
              % (rec["verdict"], script_bad, list(retried.keys()), still_bad), flush=True)

    print("\nWROTE", TRANS_PATH, "langs:", list(out.keys()))
    print("SUMMARY:", json.dumps(summary, ensure_ascii=False))


if __name__ == "__main__":
    main()
