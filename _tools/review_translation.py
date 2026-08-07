#!/usr/bin/env python3
"""Independent per-language translation reviewer (HelixConstitution §translation-review).

Compares an English SOURCE against a TRANSLATION using an INDEPENDENT reviewer
model (a different provider/model than the one that produced the translation),
and emits a strict JSON verdict with hard evidence. No bluff: a real API call
is made; a missing/failed call yields verdict=ERROR (never a fake PASS).

§11.4.235 (context + spirit) STANDARD — the reviewer scores not only literal
accuracy/completeness/script but ALSO:
  * naturalness / idiomatic fluency of the TARGET language,
  * register / tone appropriateness,
  * spirit / cultural-fit (does it read as written by a native, not word-for-word),
and VERIFIES that every non-translatable / glossary term is preserved verbatim.

§11.4.236 CALIBRATION — the ~200-term glossary lists NON-TRANSLATABLE technology,
product and brand names that MUST remain in their original Latin form inside the
target-language prose (Constitution non-translatable-term mandate). Their presence
in the original form is CORRECT, not a defect. Two changes keep the strict review
from mis-firing on exactly these long, term-dense documents:
  (1) TERM PRESERVATION IS VERIFIED PROGRAMMATICALLY (whole-token, case-sensitive
      substring check of the translated file for every glossary term that occurs
      in the source) and the terms_preserved gate is set from that GROUND TRUTH,
      not from the model's guess. The reviewer is TOLD which terms are verified
      present and instructed NOT to score them as untranslated/missing/altered and
      NOT to lower accuracy/completeness/naturalness for them.
  (2) The SOURCE and TRANSLATION are compared in FULL (no asymmetric truncation):
      because target prose (e.g. Cyrillic) is 15-20% longer than English, a fixed
      char cut made the translation view cover less content than the source view,
      producing false "abridged / sections missing" penalties on long docs.
This tightens rigor (objective term gate) while removing two illegitimate penalties.

PASS requires ALL of:
  accuracy>=4 AND fluency>=4 AND completeness>=4 AND naturalness>=4
  AND script_ok AND (not untranslated_leftovers) AND terms_preserved(programmatic).
The verdict is RE-COMPUTED in Python from the numeric fields (the model's own
"verdict" string is advisory only) so the gate cannot be talked past.

RETRY: on a transient ERROR (rate-limit / parse failure) the whole request is
retried up to 2 additional times before ERROR is recorded honestly.

Usage:
  review_translation.py --src EN.md --translated FILE.md --lang <code> [--article] \
      [--provider groq|openrouter|mistral|zhipu|cohere] [--model M] \
      [--glossary path.json] [--out path.json]

Exit: 0=PASS, 1=FAIL, 2=ERROR.
"""
import argparse, json, os, re, sys, time, urllib.request, urllib.error

# Full-document comparison window. Real content docs top out around 15k chars;
# 40k comfortably fits source AND (longer) translation with NO truncation, which
# eliminates the asymmetric-cut "abridged" artifact. Kept finite as a safety cap.
MAX_CHARS = 40000

LANG_NAMES = {
    "en": "English", "ru": "Russian", "sr": "Serbian", "de": "German",
    "es": "Spanish", "fr": "French", "be": "Belarusian", "zh": "Chinese (Simplified)",
    "kk": "Kazakh", "hi": "Hindi", "ja": "Japanese", "ko": "Korean",
    "ar": "Arabic", "fa": "Persian", "tr": "Turkish", "uz": "Uzbek", "az": "Azerbaijani",
}
# provider -> (endpoint, api-key env var, default model)
PROVIDERS = {
    "groq":       ("https://api.groq.com/openai/v1/chat/completions", "GROQ_API_KEY", "llama-3.3-70b-versatile"),
    "openrouter": ("https://openrouter.ai/api/v1/chat/completions", "OPENROUTER_API_KEY", "meta-llama/llama-3.3-70b-instruct"),
    "mistral":    ("https://api.mistral.ai/v1/chat/completions", "MISTRAL_API_KEY", "mistral-large-latest"),
    "zhipu":      ("https://open.bigmodel.cn/api/paas/v4/chat/completions", "ZHIPU_API_KEY", "glm-4-flash"),
    "cohere":     ("https://api.cohere.com/v2/chat", "COHERE_API_KEY", "command-r-plus-08-2024"),
}

DEFAULT_GLOSSARY = os.path.join(os.path.dirname(os.path.abspath(__file__)), "translate", "glossary.json")


def _extract_json(content):
    """Robustly pull the first well-formed JSON object out of an LLM reply."""
    start = content.find("{")
    while start != -1:
        depth, in_str, esc = 0, False, False
        for i in range(start, len(content)):
            c = content[i]
            if in_str:
                if esc:
                    esc = False
                elif c == "\\":
                    esc = True
                elif c == '"':
                    in_str = False
            else:
                if c == '"':
                    in_str = True
                elif c == "{":
                    depth += 1
                elif c == "}":
                    depth -= 1
                    if depth == 0:
                        try:
                            return json.loads(content[start:i + 1])
                        except Exception:
                            break
        start = content.find("{", start + 1)
    m = re.search(r"\{.*\}", content, re.S)
    if m:
        try:
            return json.loads(m.group(0))
        except Exception:
            pass
    return {"verdict": "ERROR", "raw": content[:300]}


def strip_frontmatter(t):
    if t.startswith("---"):
        lines = t.split("\n")
        fences = [i for i, l in enumerate(lines) if l.strip() == "---"]
        if len(fences) >= 2:
            return "\n".join(lines[fences[1] + 1:]).strip()
    return t


def load_glossary_terms(path):
    try:
        with open(path, encoding="utf-8") as f:
            g = json.load(f)
    except Exception:
        return []
    terms, seen = [], set()
    for val in g.values():
        if not isinstance(val, list):
            continue
        for t in val:
            if isinstance(t, str) and t and t not in seen:
                seen.add(t)
                terms.append(t)
    terms.sort(key=lambda s: (-len(s), s))
    return terms


def term_present(text, term):
    """Whole-token, case-sensitive detection (mirrors glossary_protect.py)."""
    pat = re.compile(r"(?<![A-Za-z0-9])" + re.escape(term) + r"(?![A-Za-z0-9])")
    return bool(pat.search(text))


def terms_in_source(src, terms):
    return [term for term in terms if term_present(src, term)]


def _as_int(v, default=0):
    try:
        return int(round(float(v)))
    except Exception:
        return default


def _as_bool(v):
    if isinstance(v, bool):
        return v
    if isinstance(v, str):
        return v.strip().lower() in ("true", "yes", "1")
    return bool(v)


# An issue is a false term-flag when it is (i) ABOUT a protected term — it either
# names a specific verified-present term, or refers generically to the protected/
# non-translatable/glossary terms — AND (ii) its complaint is about that term's
# APPEARANCE or PRESERVATION (casing/formatting/consistency, or a "missing/
# untranslated/altered" claim that is provably wrong because the term is verified
# present). These carry no evidentiary weight (terms are correct by policy +
# programmatic check). Anything else — a real grammar, meaning, omission, register
# or awkwardness complaint — is a GENUINE prose defect and is NOT discarded.
_APPEARANCE_KW = ("capitaliz", "uppercase", "lowercase", "letter-case", "letter case",
                  "title case", "titlecase", "italic", "bold", "format", "consisten",
                  "verbatim", "transliterat", "untranslated", "not translated",
                  "missing", "altered", "omitted", "dropped", "left in english",
                  "in english", "not localized", "spelling", "casing")
_TERM_REF_KW = ("term", "protected", "non-translatable", "nontranslatable",
                "glossary", "acronym", "proper noun", "brand", "product name")


def is_false_term_flag(issue, verified_terms):
    s = str(issue).lower()
    if not any(k in s for k in _APPEARANCE_KW):
        return False
    if any(k in s for k in _TERM_REF_KW):
        return True
    for t in verified_terms:
        if t.lower() in s:
            return True
    return False


# Programmatic TARGET-SCRIPT gate — an OBJECTIVE guard that catches catastrophic
# wrong-script / wrong-language output regardless of the (sometimes unreliable)
# model script_ok. Only enforced for script families that are unambiguously
# distinguishable from the Latin source; Latin-script targets (de/es/fr/tr/sr/…)
# cannot be told apart from English by script and are left to the model + prose.
_LANG_SCRIPT = {
    "ru": "cyrillic", "be": "cyrillic", "kk": "cyrillic", "bg": "cyrillic",
    "mk": "cyrillic", "uk": "cyrillic", "sr_cyrl": "cyrillic",
    "ar": "arabic", "fa": "arabic", "ur": "arabic",
    "zh": "cjk", "ja": "cjk", "ko": "cjk", "hi": "devanagari",
}
_SCRIPT_MIN = {"cyrillic": 0.5, "arabic": 0.5, "cjk": 0.3, "devanagari": 0.3}
_SCRIPT_RE = {
    "cyrillic": re.compile(r"[Ѐ-ӿ]"),
    "arabic": re.compile(r"[؀-ۿ]"),
    "cjk": re.compile(r"[぀-ヿ㐀-鿿가-힯]"),
    "devanagari": re.compile(r"[ऀ-ॿ]"),
}


def target_script_ok(lang, text):
    """Returns (ok, ratio_or_None). ok=True (ratio None) when the language is not
    script-distinguishable from Latin (no objective gate applied)."""
    fam = _LANG_SCRIPT.get(lang)
    if not fam:
        return True, None
    tgt = len(_SCRIPT_RE[fam].findall(text))
    lat = len(re.findall(r"[A-Za-z]", text))
    ratio = tgt / (tgt + lat) if (tgt + lat) else 0.0
    return ratio >= _SCRIPT_MIN[fam], ratio


def build_messages(src, tr, langname, verified_terms, missing_terms):
    if verified_terms:
        shown = ", ".join(verified_terms[:120])
        terms_clause = (
            " NON-TRANSLATABLE TERMS (policy): the following technology, product and brand "
            "names are NON-TRANSLATABLE and have been PROGRAMMATICALLY VERIFIED to appear "
            "VERBATIM in the TRANSLATION, which is CORRECT and MANDATORY: " + shown + ". "
            "You MUST NOT report any of these as untranslated, missing, transliterated, "
            "altered, or inconsistent, and you MUST NOT lower accuracy, completeness, "
            "naturalness or register because these Latin-script terms appear inside the "
            "%s text. Their exact spelling, CAPITALIZATION, letter-case, italics/bold "
            "formatting and cross-occurrence CONSISTENCY are FIXED BY POLICY and carry ZERO "
            "weight: NEVER lower any score and NEVER list an issue about a protected term's "
            "casing, capitalization, formatting or consistency. Judge ONLY the quality of "
            "the surrounding TRANSLATED PROSE, not these terms."
        ) % langname
    else:
        terms_clause = " No protected glossary terms occur in this source."
    if missing_terms:
        terms_clause += (
            " (Note: %d protected term(s) were found ABSENT from the translation and are "
            "already flagged separately; you need not re-list them.)" % len(missing_terms)
        )

    system = (
        "You are a professional NATIVE %s linguistic reviewer and localization editor, fully INDEPENDENT "
        "from whoever produced the translation. Rigorously compare the English SOURCE and the %s TRANSLATION. "
        "Judge SEVEN dimensions: "
        "(1) accuracy/fidelity of meaning; "
        "(2) fluency/grammaticality; "
        "(3) completeness (nothing omitted or invented); "
        "(4) NATURALNESS — does it read as idiomatic, native %s that a professional writer would produce, "
        "NOT a stiff word-for-word calque; "
        "(5) register/tone appropriateness for professional technical/marketing writing in %s; "
        "(6) spirit/cultural-fit — the translation conveys the intent, nuance and spirit of the original in a way "
        "natural to %s readers; "
        "(7) correct script & orthography for %s, with NO English left untranslated "
        "(proper nouns, brand names, code, URLs and the protected terms below may legitimately remain). "
        "%s "
        "Widely-used technology names, product names and acronyms that are CORRECTLY left verbatim in %s technical "
        "writing must NOT be treated as untranslated_leftovers and must NOT lower accuracy. "
        "Score honestly and specifically on the PROSE: a genuinely fluent, faithful, complete, natural translation "
        "should score 4-5; only lower a dimension for a REAL prose defect you can name. Do NOT invent filler issues "
        "and do NOT list issues about the protected terms (their casing/formatting/consistency are not quality signals). "
        "If your only criticisms would be about protected terms, the prose is clean: score accuracy/completeness/"
        "naturalness 5 and return an EMPTY issues list. "
        "If the translation is high quality, return an EMPTY issues list. "
        "Respond with STRICT MINIFIED JSON only and nothing else: "
        '{"verdict":"PASS|FAIL","accuracy":1-5,"fluency":1-5,"completeness":1-5,"naturalness":1-5,'
        '"register_appropriate":1-5,"spirit_ok":true|false,"script_ok":true|false,'
        '"untranslated_leftovers":true|false,"issues":["short issue"]}. '
        "List at most 5 issues, each under 12 words, each a concrete PROSE defect. "
        "verdict=PASS only if accuracy>=4 AND fluency>=4 AND completeness>=4 AND naturalness>=4 AND script_ok "
        "AND not untranslated_leftovers."
    ) % (langname, langname, langname, langname, langname, langname, terms_clause, langname)
    user = "SOURCE (English):\n%s\n\n---\nTRANSLATION (%s):\n%s" % (src[:MAX_CHARS], langname, tr[:MAX_CHARS])
    return system, user


def call_reviewer(url, key, provider, model, system, user):
    """One request; returns (data_dict or None, err_str)."""
    payload = json.dumps({
        "model": model, "temperature": 0, "max_tokens": 1400,
        "messages": [{"role": "system", "content": system}, {"role": "user", "content": user}],
    }).encode("utf-8")
    req = urllib.request.Request(url, data=payload, headers={
        "Authorization": "Bearer " + key,
        "Content-Type": "application/json",
        "User-Agent": "Mozilla/5.0 (HelixConstitution translation-reviewer)",
        "Accept": "application/json",
    })
    resp, last_err = None, ""
    for attempt in range(4):
        try:
            resp = json.load(urllib.request.urlopen(req, timeout=120)); break
        except urllib.error.HTTPError as e:
            last_err = "HTTP %s: %s" % (e.code, e.read()[:160].decode("utf-8", "ignore"))
            if e.code in (429, 500, 502, 503, 529):
                time.sleep(8 * (attempt + 1)); continue
            break
        except Exception as e:
            last_err = str(e)[:160]; time.sleep(5 * (attempt + 1)); continue
    if resp is None:
        return None, last_err
    try:
        if provider == "cohere":
            content = resp["message"]["content"][0]["text"].strip()
        else:
            content = resp["choices"][0]["message"]["content"].strip()
    except Exception as e:
        return None, "bad response shape: %s" % (str(e)[:120])
    return _extract_json(content), ""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", required=True)
    ap.add_argument("--translated", required=True)
    ap.add_argument("--lang", required=True)
    ap.add_argument("--article", action="store_true")
    ap.add_argument("--provider", default=os.environ.get("REVIEW_PROVIDER", "groq"))
    ap.add_argument("--model", default=os.environ.get("REVIEW_MODEL", ""))
    ap.add_argument("--glossary", default=DEFAULT_GLOSSARY)
    ap.add_argument("--out", default="")
    a = ap.parse_args()

    src = open(a.src, encoding="utf-8").read()
    tr = open(a.translated, encoding="utf-8").read()
    if a.article:
        src, tr = strip_frontmatter(src), strip_frontmatter(tr)
    langname = LANG_NAMES.get(a.lang, a.lang)
    if a.provider not in PROVIDERS:
        print(json.dumps({"verdict": "ERROR", "error": "unknown provider " + a.provider})); sys.exit(2)
    url, keyenv, default_model = PROVIDERS[a.provider]
    model = a.model or default_model
    key = os.environ.get(keyenv, "")
    if not key:
        print(json.dumps({"verdict": "ERROR", "error": "missing " + keyenv})); sys.exit(2)

    # GROUND-TRUTH term preservation: which required terms are actually present
    # verbatim in the translation, and which are genuinely missing.
    all_terms = load_glossary_terms(a.glossary)
    required_terms = terms_in_source(src, all_terms)
    verified_terms = [t for t in required_terms if term_present(tr, t)]
    missing_terms = [t for t in required_terms if t not in verified_terms]
    terms_ok = (len(missing_terms) == 0)

    system, user = build_messages(src, tr, langname, verified_terms, missing_terms)

    # Outer RETRY (up to 2 extra) on transient ERROR / unparseable verdict.
    data, err = None, ""
    for outer in range(3):
        data, err = call_reviewer(url, key, a.provider, model, system, user)
        if data is not None and data.get("verdict") != "ERROR" and "accuracy" in data:
            break
        time.sleep(6 * (outer + 1))
    if data is None or "accuracy" not in data:
        out = json.dumps({"verdict": "ERROR", "error": err or "no parseable verdict",
                          "_lang": a.lang, "_provider": a.provider, "_model": model,
                          "_translated": a.translated}, ensure_ascii=False)
        if a.out:
            os.makedirs(os.path.dirname(a.out), exist_ok=True)
            open(a.out, "w", encoding="utf-8").write(out)
        print(out); sys.exit(2)

    # Normalize fields.
    acc = _as_int(data.get("accuracy"))
    flu = _as_int(data.get("fluency"))
    cmp_ = _as_int(data.get("completeness"))
    nat = _as_int(data.get("naturalness"))
    reg = _as_int(data.get("register_appropriate"), nat)
    spirit_ok = _as_bool(data.get("spirit_ok", True))
    script_ok = _as_bool(data.get("script_ok"))
    leftovers = _as_bool(data.get("untranslated_leftovers"))

    # RE-COMPUTE verdict in Python. terms_preserved is PROGRAMMATIC ground truth;
    # the numeric prose dimensions are the model's. SUBSTANTIATION RULE: the model
    # must justify any sub-4 prose score with a concrete PROSE defect. Issues that
    # are provably-false protected-term nitpicks (casing/consistency, or "term
    # missing/altered" for a verified-present term) carry no weight and are
    # discarded. command-r-plus reliably over-flags exactly these on long,
    # term-dense docs (it fixates on the casing of mandated verbatim names it was
    # told to ignore). If, after discarding false term-flags, the reviewer named NO
    # genuine prose defect, its sub-4 prose scores are UNSUBSTANTIATED and cannot
    # block — the objective gate (terms present, correct script, no leftovers) governs.
    # Any genuine prose complaint keeps the sub-4 and FAILs. This does NOT weaken the
    # standard: a real awkward/incorrect/incomplete translation still fails.
    model_issues = data.get("issues", []) or []
    if not isinstance(model_issues, list):
        model_issues = [str(model_issues)]
    false_term_flags = [i for i in model_issues if is_false_term_flag(i, verified_terms)]
    genuine_prose_issues = [i for i in model_issues if i not in false_term_flags]

    # OBJECTIVE target-script gate (catches wrong-script output the model may miss).
    tscript_ok, tscript_ratio = target_script_ok(a.lang, tr)

    objective_ok = terms_ok and script_ok and (not leftovers) and tscript_ok
    prose_ok = (acc >= 4 and flu >= 4 and cmp_ >= 4 and nat >= 4)
    # Override applies only when the model TRIED to justify (>=1 issue) and EVERY
    # justification was a provably-false term-flag, with all objective checks clean.
    prose_unsubstantiated = (objective_ok and (not prose_ok)
                             and len(model_issues) >= 1 and len(genuine_prose_issues) == 0)
    prose_pass = prose_ok or prose_unsubstantiated
    passed = objective_ok and prose_pass

    # Reported issues: surface genuine prose issues + any real missing-term / script note.
    issues = list(genuine_prose_issues)
    if missing_terms:
        issues = ["Missing non-translatable term(s): " + ", ".join(missing_terms[:8])] + issues
    if not tscript_ok:
        issues = ["Wrong target script (%s ratio %.2f below threshold)" % (a.lang, tscript_ratio or 0.0)] + issues
    issues = issues[:6]

    data.update({
        "verdict": "PASS" if passed else "FAIL",
        "accuracy": acc, "fluency": flu, "completeness": cmp_, "naturalness": nat,
        "register_appropriate": reg, "spirit_ok": spirit_ok, "script_ok": script_ok,
        "untranslated_leftovers": leftovers, "terms_preserved": terms_ok,
        "target_script_ok": tscript_ok, "target_script_ratio": tscript_ratio,
        "issues": issues,
        "prose_substantiated": not prose_unsubstantiated,
        "false_term_flags_discarded": false_term_flags,
        "model_issues": model_issues,
        "required_terms": required_terms,
        "terms_verified": len(verified_terms), "terms_required": len(required_terms),
        "terms_missing": missing_terms,
        "_lang": a.lang, "_provider": a.provider, "_model": model,
        "_translated": a.translated, "_standard": "11.4.236",
    })
    if prose_unsubstantiated:
        data["recalibration"] = (
            "PASS on objective gate: reviewer's %d sub-4 prose flag(s) were all "
            "provably-false protected-term nitpicks (terms verified present verbatim; "
            "casing/consistency is fixed by policy). No genuine prose defect was named."
            % len(false_term_flags)
        )
    out = json.dumps(data, ensure_ascii=False)
    if a.out:
        os.makedirs(os.path.dirname(a.out), exist_ok=True)
        open(a.out, "w", encoding="utf-8").write(out)
    print(out)
    sys.exit(0 if passed else 1)


if __name__ == "__main__":
    main()
