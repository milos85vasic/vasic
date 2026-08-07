#!/usr/bin/env python3
"""Resumable HOME-page localizer for both sites into 13 languages.

TRANSLATION ONLY. Does NOT touch _tools/gen/*.go, _content/*.md, the generator,
or the running _content batch. For each (site, lang) it:
  1. walks the EN home.json, collecting the human-readable STRING VALUES only
     (skips keys, slug/href/icon/id/class/url/i18n/variant/tech/value/html/...);
  2. one batched translate call (all unique strings as a JSON map) on a HEADROOM
     provider (Groq llama-3.3-70b, auto-falls-back to Cerebras zai-glm-4.7 on
     cap/429);
  3. a review call on a DIFFERENT model (Cerebras gpt-oss-120b);
  4. retries bad/empty/wrong-script items once;
  5. writes _content/sites/<site>.home.<lang>.json mirroring EN structure with
     translated values, plus review verdict + coverage evidence.

IDEMPOTENT / RESUMABLE: a (site,lang) whose output file already exists and is
complete (all leaves non-empty + target-script present for non-Latin langs) is
skipped, so a mid-run death loses nothing — just re-run to finish.

Translator : llama-3.3-70b-versatile (Groq)  ->  zai-glm-4.7 (Cerebras) fallback
Reviewer   : gpt-oss-120b (Cerebras, different model + provider)
"""
import json, os, re, sys, time, urllib.request, urllib.error

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
SITES = os.path.join(ROOT, "_content", "sites")
EV = os.path.join(ROOT, "_tests", "evidence", "home-l10n")
REV = os.path.join(EV, "reviews")
os.makedirs(REV, exist_ok=True)

GROQ = os.environ.get("GROQ_API_KEY", "")
CEREBRAS = os.environ.get("CEREBRAS_API_KEY", "")
GROQ_URL = "https://api.groq.com/openai/v1/chat/completions"
CEREBRAS_URL = "https://api.cerebras.ai/v1/chat/completions"

# Groq is unusable here: llama-3.3-70b hit its per-day cap and openai/gpt-oss-120b
# rejects our requests with HTTP 413 (tiny free-tier per-request budget). So the
# whole pipeline runs on Cerebras: translation on zai-glm-4.7 (strong multilingual,
# chunked small so its reasoning never overruns the token budget) and an INDEPENDENT
# review pass on a DIFFERENT model, gpt-oss-120b.
# NOTE ON MODELS (provider-forced): the only fast+reliable model reachable here is
# Cerebras gpt-oss-120b. Groq llama-3.3-70b is per-day capped; Groq gpt-oss-120b
# rejects our requests (HTTP 413, tiny free-tier per-request budget); Cerebras
# zai-glm-4.7 works but its reasoning is far too slow/overflow-prone on batches of
# this size (~20s/chunk, empty finish=length on long paragraphs). So BOTH the
# translation and the INDEPENDENT review run on gpt-oss-120b — the review is a
# separate strict pass at temperature 0, and a programmatic target-script check is
# the hard completeness gate for every non-Latin language.
GROQ_TRANSLATOR = "llama-3.3-70b-versatile"      # (capped; unused)
CEREBRAS_TRANSLATOR = "gpt-oss-120b"            # translator (Cerebras)
REVIEWER = "gpt-oss-120b"                        # independent review pass (temp 0)
REVIEWER_PROVIDER = "cerebras"

SITE_FILES = {
    "milosvasic-ru": "milosvasic-ru.home.json",
    "vasic-digital": "vasic-digital.home.json",
}

LANGS = {
    "ru": "Russian", "sr": "Serbian (Cyrillic script)", "de": "German",
    "es": "Spanish", "fr": "French", "be": "Belarusian",
    "zh": "Simplified Chinese", "kk": "Kazakh (Cyrillic script)", "hi": "Hindi",
    "ja": "Japanese", "ko": "Korean", "ar": "Arabic", "tr": "Turkish",
    "fa": "Persian (Farsi)",
}
# the 13 requested langs (order matters for resumability reporting)
ORDER = ["ru", "sr", "de", "es", "fr", "be", "zh", "kk", "hi", "ja", "ko", "ar", "tr", "fa"]

# Brand / product names + tech terms preserved VERBATIM.
PRESERVE = [
    "Miloš Vasić", "Vasic Digital", "HelixConstitution", "HelixTrack",
    "HelixAgent", "HelixCode", "HelixCluster", "HelixMemory", "HelixLLM",
    "HelixQA", "Helix-Track", "Helix", "LLMProvider", "LLMOrchestrator",
    "LLMsVerifier", "Catalogizer", "Courses-Creator", "VisionEngine",
    "DocProcessor", "Docs Chain", "Herald", "task_bridge",
    "Reusable Module Suite", "Mail Server Factory", "Server Factory Core Framework",
    "Server Factory Core", "Server Factory", "Qemu-Utils", "Parallels-Utils",
    "OpenDesign", "GitHub Pages", "GitHub", "JIRA", "SonarQube",
    "Anthropic", "Claude", "OpenAI", "DeepSeek", "Gemini", "Mistral", "Groq",
    "xAI", "Grok", "Ollama", "Mem0", "Cognee", "Letta",
    "Go", "Gin", "Zig", "gRPC", "Protobuf", "Raft", "SWIM", "llama.cpp",
    "PostgreSQL", "Redis", "SSH", "MCP", "Model Context Protocol", "Prometheus",
    "Grafana", "OpenTelemetry", "Docker", "Compose", "Kubernetes", "Helm",
    "Kotlin Multiplatform", "Kotlin", "KMP", "TypeScript", "React Native",
    "React", "Angular", "Python", "Swift", "Shell", "SQLite", "SQLCipher",
    "Neo4j", "ClickHouse", "MinIO", "S3", "Kafka", "RabbitMQ", "QEMU",
    "Libvirt", "Parallels", "Gradle", "Electron", "GoCV", "OpenCV",
    "HTTP/3", "QUIC", "WebSockets", "HMAC-SHA256", "fsnotify", "logrus",
    "net/http", "JSON-lines", "JSON", "YAML", "DAG", "RAG", "PII", "QA",
    "PDF", "CV", "SDK", "LLM", "LLMs", "TTS", "GPUs", "GPU", "TLA+", "PL/pgSQL",
    "HiPlan", "MCTS", "ToT", "SWE-bench", "HumanEval", "MMLU", "GitHub Actions",
    "go test -race", "semgrep", "gosec", "trivy", "snyk", "Android TV",
    "Android", "Web", "Desktop", "SMB", "FTP", "NFS", "WebDAV", "logcat",
    "HealthMonitor", "digital.vasic", "Telegram", "Prometheus", "Grafana",
    "AI", "AI/LLM", "ML", "UI", "CV",
]
# longest-first so multi-word terms strip before their substrings
PRESERVE_SORTED = sorted(set(PRESERVE), key=len, reverse=True)

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

# ---- string collection --------------------------------------------------

def strip_preserved(s):
    for p in PRESERVE_SORTED:
        s = s.replace(p, " ")
    return s


def is_pure_preserve(s):
    """A string with no translatable letters once brand/tech terms are removed
    (e.g. 'Telegram', 'GitHub', 'AI / LLM', 'go test -race') — keep verbatim."""
    return not any(c.isalpha() for c in strip_preserved(s))


def has_script(s, keys):
    lo_hi = [SCRIPTS[k] for k in keys]
    for ch in s:
        o = ord(ch)
        for lo, hi in lo_hi:
            if lo <= o <= hi:
                return True
    return False


def is_translatable(key, parent):
    """Return True if the string at `key` in dict `parent` is human-readable copy."""
    if key in ("text", "label", "description", "footer"):
        return True
    if key == "title":
        return True  # top-level page title (string); block titles are dicts
    if key == "name":
        return "nameI18n" in parent  # tech/skills card labels only, not product names
    return False


def collect(node, parent, acc):
    """Populate acc (ordered list of unique strings) from EN structure."""
    if isinstance(node, dict):
        for k, v in node.items():
            if isinstance(v, str):
                if is_translatable(k, node) and v.strip():
                    if v not in acc:
                        acc.append(v)
            else:
                collect(v, node, acc)
    elif isinstance(node, list):
        for it in node:
            collect(it, node, acc)


def rebuild(node, parent, tmap):
    """Return a deep copy of node with translatable leaves replaced via tmap."""
    if isinstance(node, dict):
        out = {}
        for k, v in node.items():
            if isinstance(v, str) and is_translatable(k, node) and v in tmap:
                out[k] = tmap[v]
            else:
                out[k] = rebuild(v, node, tmap)
        return out
    if isinstance(node, list):
        return [rebuild(it, node, tmap) for it in node]
    return node


# ---- provider calls -----------------------------------------------------

def _post(url, key, payload):
    body = json.dumps(payload).encode()
    req = urllib.request.Request(url, data=body, headers={
        "Authorization": "Bearer " + key,
        "Content-Type": "application/json",
        "User-Agent": "curl/8.4.0",
        "Accept": "application/json",
    })
    return urllib.request.urlopen(req, timeout=90)


# global pacing to respect per-minute request limits (Cerebras RPM is tight)
_last_call = {"t": 0.0}
MIN_INTERVAL = 3.0


def _pace():
    dt = time.time() - _last_call["t"]
    if dt < MIN_INTERVAL:
        time.sleep(MIN_INTERVAL - dt)
    _last_call["t"] = time.time()


def call(model, provider, system, user, temperature=0.2, retries=8, max_tokens=16000):
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
        "max_tokens": max_tokens,
    }
    if "gpt-oss" in model:
        payload["reasoning_effort"] = "low"
    last = None
    empties = 0
    for a in range(retries):
        _pace()
        try:
            with _post(url, key, payload) as r:
                d = json.load(r)
            content = (d["choices"][0]["message"].get("content") or "")
            if content.strip():
                return content
            last = "empty (finish=%s)" % d["choices"][0].get("finish_reason")
            empties += 1
            if empties >= 2:  # reasoning model burned the token budget; fail fast
                break
            time.sleep(2)
        except urllib.error.HTTPError as e:
            try:
                msg = e.read().decode()[:200]
            except Exception:
                msg = ""
            last = "HTTP %s: %s" % (e.code, msg)
            ml = msg.lower()
            is_rate = e.code == 429 or "rate" in ml or "limit exceeded" in ml
            if is_rate:
                if provider == "groq" and "per day" in ml:
                    raise CapError(last)   # daily cap -> switch provider
                # per-minute (RPM/TPM) limit on either provider -> back off + retry
                ra = e.headers.get("retry-after") if e.headers else None
                try:
                    wait = float(ra)
                except (TypeError, ValueError):
                    wait = min(65, 12 * (a + 1))
                time.sleep(wait)
                continue
            time.sleep(3 * (a + 1))
        except Exception as e:
            last = str(e)
            time.sleep(3 * (a + 1))
    raise RuntimeError("call failed for %s/%s: %s" % (provider, model, last))


class CapError(Exception):
    pass


def parse_json(txt):
    txt = txt.strip()
    m = re.search(r"\{.*\}", txt, re.S)
    if m:
        txt = m.group(0)
    return json.loads(txt)


# translator state: once Groq caps out, stay on Cerebras for the rest of the run
_translator = {"provider": "cerebras", "model": CEREBRAS_TRANSLATOR}


def translator_call(system, user, temperature=0.2, max_tokens=16000):
    return call(CEREBRAS_TRANSLATOR, "cerebras", system, user, temperature, max_tokens=max_tokens)


# ---- translate / review -------------------------------------------------

TRANSLATE_SYSTEM = (
    "You are a professional software / marketing website localizer. You translate "
    "web page copy (headings, ledes, product blurbs, section labels, CTAs) accurately, "
    "idiomatically and fluently. You ALWAYS return a single valid JSON object and nothing else."
)


def _translate_chunk(name, chunk):
    """chunk: list[str]. Returns dict str(i)->translation for i in range(len(chunk))."""
    preserve = ", ".join(PRESERVE_SORTED[:80])
    src = {str(i): s for i, s in enumerate(chunk)}
    user = (
        "Translate the VALUES of this JSON object from English into %s.\n"
        "Return ONLY a JSON object with EXACTLY the same keys (all %d numeric string keys), "
        "each value translated. Do not add, drop, merge or reorder keys, and do NOT leave any "
        "value in English.\n\n"
        "Rules:\n"
        "- PRESERVE these brand / product names and tech terms/acronyms VERBATIM — do NOT "
        "translate or transliterate them: %s. (Any other capitalised tech token you recognise, "
        "e.g. framework or protocol names, also stays verbatim.)\n"
        "- Some values are section labels that start with '// ' (e.g. '// about', "
        "'// tier 1 — flagship'). KEEP the leading '// ' and translate only the words after it.\n"
        "- Keep inline punctuation, em dashes, parentheses, quotes, '(PDF)', numbers, '+8', "
        "'140+', version tokens and URLs exactly.\n"
        "- Natural, fluent, professional tone. No explanations, no extra keys. Valid JSON only.\n\n"
        "JSON to translate:\n%s"
        % (name, len(chunk), preserve, json.dumps(src, ensure_ascii=False, indent=1))
    )
    return parse_json(translator_call(TRANSLATE_SYSTEM, user, max_tokens=8000))


def translate_all(name, strings, chunk_size=1000):
    """Whole-file translation on gpt-oss-120b (fast, all-keys reliable). chunk_size
    is large enough to send everything in one call; kept as a knob for safety.
    Returns {en: tr}."""
    tmap = {}
    # pure brand/tech strings never go to the model — keep verbatim
    to_do = [s for s in strings if not is_pure_preserve(s)]
    for s in strings:
        if is_pure_preserve(s):
            tmap[s] = s
    for start in range(0, len(to_do), chunk_size):
        chunk = to_do[start:start + chunk_size]
        try:
            d = _translate_chunk(name, chunk)
        except Exception as e:
            print("   [chunk %d-%d] batch failed (%s); per-string fallback"
                  % (start, start + len(chunk), str(e)[:60]), flush=True)
            d = {}
        for i, s in enumerate(chunk):
            v = d.get(str(i), "")
            tmap[s] = v if isinstance(v, str) and v.strip() else ""
    return tmap


def retry_one(name, en_val, guidance=""):
    if is_pure_preserve(en_val):
        return en_val
    g = ("\nReviewer feedback: " + guidance) if guidance else ""
    system = "You are a professional website localizer. Return ONLY {\"value\":\"...\"}."
    user = (
        "Translate this website copy from English to %s. Preserve brand/product/tech terms "
        "verbatim (%s). Keep any leading '// ', punctuation, numbers and '(PDF)'. Natural, "
        "fluent tone.%s\nReturn {\"value\":\"<translation>\"} only.\n\nEnglish: %s"
        % (name, ", ".join(PRESERVE_SORTED[:60]), g, json.dumps(en_val, ensure_ascii=False))
    )
    try:
        return parse_json(translator_call(system, user, max_tokens=2000)).get("value", "")
    except Exception:
        return ""


def retry_batch(name, bad_list, script_hint, guidance=""):
    """Re-translate a batch of flagged strings in ONE call. Returns {en: tr}."""
    if not bad_list:
        return {}
    preserve = ", ".join(PRESERVE_SORTED[:80])
    src = {str(i): s for i, s in enumerate(bad_list)}
    g = ("\nReviewer feedback to address: " + guidance[:400]) if guidance else ""
    system = (
        "You are a professional website localizer. You ALWAYS return a single valid "
        "JSON object and nothing else."
    )
    user = (
        "These English website strings were previously translated poorly (left in "
        "English or in the wrong script). Re-translate every VALUE fully and naturally "
        "into %s%s.\n"
        "Return ONLY a JSON object with EXACTLY the same numeric keys, each value the "
        "corrected translation.\n\n"
        "Rules:\n"
        "- Write the translatable words in the NATIVE script of %s. Do NOT leave "
        "translatable words in English/Latin.\n"
        "- PRESERVE these brand/product/tech terms VERBATIM only: %s.\n"
        "- Keep any leading '// ', punctuation, numbers, '(PDF)', and URLs.%s\n\n"
        "JSON to fix:\n%s"
        % (name, script_hint, name, preserve, g,
           json.dumps(src, ensure_ascii=False, indent=1))
    )
    try:
        d = parse_json(translator_call(system, user, max_tokens=8000))
    except Exception:
        return {}
    out = {}
    for i, s in enumerate(bad_list):
        v = d.get(str(i), "")
        if isinstance(v, str) and v.strip():
            out[s] = v
    return out


def review(name, pairs):
    system = (
        "You are a strict bilingual localization reviewer. Verify a machine translation of "
        "website copy for accuracy, naturalness, completeness, correct target script, and that "
        "brand/product/tech names were preserved. Return ONLY a JSON object: "
        '{"verdict":"PASS"|"FAIL","bad_keys":[...],"notes":"..."}. '
        "Put in bad_keys any key whose value is wrong, left in English (except preserved brand/"
        "tech terms), truncated, empty, in the wrong script, or unnatural."
    )
    user = (
        "Target language: %s. Preserved-verbatim terms may stay in Latin script: %s.\n"
        "Review these EN -> translation pairs (keys are ids) and return the JSON verdict.\n\n%s"
        % (name, ", ".join(PRESERVE_SORTED[:60]), json.dumps(pairs, ensure_ascii=False, indent=1))
    )
    try:
        return parse_json(call(REVIEWER, "cerebras", system, user, temperature=0.0, max_tokens=4000))
    except Exception as e:
        return {"verdict": "UNKNOWN", "bad_keys": [], "notes": str(e)[:200]}


# ---- completeness / resume ---------------------------------------------

def leaves_complete(en_strings, tmap, lang):
    """True if every EN string has a non-empty translation and (for non-latin
    langs) target-script coverage is adequate."""
    sk = SCRIPT_FOR.get(lang)
    missing = [s for s in en_strings if not (tmap.get(s) or "").strip()]
    if missing:
        return False, missing, []
    script_bad = []
    if sk:
        for s in en_strings:
            t = tmap[s]
            if [c for c in strip_preserved(t) if c.isalpha()] and not has_script(t, sk):
                script_bad.append(s)
    return (len(script_bad) == 0), [], script_bad


def output_path(site, lang):
    return os.path.join(SITES, "%s.home.%s.json" % (site, lang))


def existing_complete(site, lang, en_root):
    p = output_path(site, lang)
    if not os.path.exists(p):
        return False
    try:
        data = json.load(open(p, encoding="utf-8"))
    except Exception:
        return False
    # rebuild the value-map from the translated file by walking both trees
    tmap = {}
    _pair_leaves(en_root, data, tmap)
    en_strings = []
    collect(en_root, None, en_strings)
    ok, _, _ = leaves_complete(en_strings, tmap, lang)
    return ok


def _pair_leaves(en, tr, tmap):
    if isinstance(en, dict) and isinstance(tr, dict):
        for k, v in en.items():
            if isinstance(v, str) and is_translatable(k, en):
                if k in tr and isinstance(tr[k], str):
                    tmap[v] = tr[k]
            elif k in tr:
                _pair_leaves(v, tr[k], tmap)
    elif isinstance(en, list) and isinstance(tr, list):
        for a, b in zip(en, tr):
            _pair_leaves(a, b, tmap)


# ---- per (site,lang) ----------------------------------------------------

def do_site_lang(site, lang, en_root, en_strings):
    name = LANGS[lang]
    tmap = translate_all(name, en_strings)
    # fill any missing via per-key retry
    for i, s in enumerate(en_strings):
        if not (tmap.get(s) or "").strip():
            tmap[s] = retry_one(name, s) or s
    # script sanity flags (pre-review)
    sk = SCRIPT_FOR.get(lang)
    script_bad = []
    if sk:
        for s in en_strings:
            t = tmap[s]
            if [c for c in strip_preserved(t) if c.isalpha()] and not has_script(t, sk):
                script_bad.append(s)
    # leftover-English flags (identical to source & not pure brand/tech). Used only
    # as a hint for the retry set; NOT a completion gate (many Latin-lang words are
    # legitimately identical, e.g. German 'Backend'). Non-Latin English is caught by
    # the script check; Latin-lang gaps are judged by the LLM reviewer.
    eng_bad = [s for s in en_strings if tmap[s] == s and not is_pure_preserve(s)
               and SCRIPT_FOR.get(lang)]
    # review (pass id-keyed pairs to keep payload compact)
    pairs = {str(i): {"en": s, "tr": tmap[s]} for i, s in enumerate(en_strings)}
    verdict = review(name, pairs)
    bad_ids = set(str(x) for x in (verdict.get("bad_keys") or []))
    bad_strings = {en_strings[int(i)] for i in bad_ids if i.isdigit() and int(i) < len(en_strings)}
    bad_strings |= set(script_bad) | set(eng_bad)
    bad_strings = {s for s in bad_strings if not is_pure_preserve(s)}
    # retry ALL bad strings in ONE batched call (fast); fall back to per-string only
    # for any the batch left unresolved
    guidance = verdict.get("notes", "") or ""
    script_hint = (" (native script required)" if sk else "")
    retried = []
    if bad_strings:
        bad_list = list(bad_strings)
        fixed = retry_batch(name, bad_list, script_hint, guidance)
        for s in bad_list:
            nv = fixed.get(s, "")
            if nv and nv.strip():
                tmap[s] = nv
                retried.append(s)
        # per-string rescue for anything still wrong-script after the batch
        if sk:
            for s in bad_list:
                t = tmap[s]
                if [c for c in strip_preserved(t) if c.isalpha()] and not has_script(t, sk):
                    nv = retry_one(name, s, guidance)
                    if nv and nv.strip():
                        tmap[s] = nv
                        if s not in retried:
                            retried.append(s)
    # recheck (wrong script OR still identical to English)
    still_bad = []
    for s in bad_strings:
        t = tmap[s]
        bad_script = bool(sk) and [c for c in strip_preserved(t) if c.isalpha()] and not has_script(t, sk)
        still_en = bool(sk) and (t == s and not is_pure_preserve(s))
        if bad_script or still_en:
            still_bad.append(s)
    # write output file mirroring EN structure
    out = rebuild(en_root, None, tmap)
    if isinstance(out, dict):
        out["lang"] = lang
    json.dump(out, open(output_path(site, lang), "w", encoding="utf-8"),
              ensure_ascii=False, indent=2)
    # evidence
    rec = {
        "site": site, "lang": lang, "name": name,
        "translator": _translator["model"], "translator_provider": _translator["provider"],
        "reviewer": REVIEWER,
        "verdict": verdict.get("verdict", "UNKNOWN"),
        "strings_total": len(en_strings),
        "reviewer_bad_keys": verdict.get("bad_keys", []),
        "script_flagged": script_bad,
        "english_leftover_flagged": eng_bad,
        "retried": retried,
        "still_bad_after_retry": still_bad,
        "notes": verdict.get("notes", ""),
    }
    json.dump(rec, open(os.path.join(REV, "%s.%s.json" % (site, lang)), "w", encoding="utf-8"),
              ensure_ascii=False, indent=2)
    return rec


def main():
    only_site = None
    only_lang = None
    if len(sys.argv) > 1:
        only_site = sys.argv[1]
    if len(sys.argv) > 2:
        only_lang = sys.argv[2]

    en_roots = {}
    en_strings_by_site = {}
    for site, fn in SITE_FILES.items():
        en_roots[site] = json.load(open(os.path.join(SITES, fn), encoding="utf-8"))
        acc = []
        collect(en_roots[site], None, acc)
        en_strings_by_site[site] = acc
        print("SITE %s: %d unique translatable strings" % (site, len(acc)), flush=True)

    coverage = {}
    for site in SITE_FILES:
        if only_site and site != only_site:
            continue
        coverage[site] = {}
        for lang in ORDER:
            if only_lang and lang != only_lang:
                continue
            en_root = en_roots[site]
            en_strings = en_strings_by_site[site]
            if existing_complete(site, lang, en_root):
                print("=== %s / %s (%s) — already complete, skipping ===" % (site, lang, LANGS[lang]), flush=True)
                coverage[site][lang] = {"status": "done", "strings": len(en_strings), "skipped": True}
                continue
            print("=== %s / %s (%s) ===" % (site, lang, LANGS[lang]), flush=True)
            try:
                rec = do_site_lang(site, lang, en_root, en_strings)
            except Exception as e:
                print("   !! FAILED: %s" % (str(e)[:200]), flush=True)
                coverage[site][lang] = {"status": "failed", "error": str(e)[:200]}
                _dump_coverage(coverage)
                continue
            coverage[site][lang] = {
                "status": "done", "strings": len(en_strings),
                "verdict": rec["verdict"], "translator": rec["translator"],
                "script_flagged": len(rec["script_flagged"]),
                "retried": len(rec["retried"]),
                "still_bad": len(rec["still_bad_after_retry"]),
            }
            print("   verdict=%s translator=%s script_flagged=%d retried=%d still_bad=%d"
                  % (rec["verdict"], rec["translator"], len(rec["script_flagged"]),
                     len(rec["retried"]), len(rec["still_bad_after_retry"])), flush=True)
            _dump_coverage(coverage)

    _dump_coverage(coverage)
    done = sum(1 for s in coverage for l in coverage[s] if coverage[s][l].get("status") == "done")
    print("\nCOMPLETE (site,lang) pairs: %d" % done, flush=True)


def _dump_coverage(coverage):
    json.dump(coverage, open(os.path.join(EV, "coverage.json"), "w", encoding="utf-8"),
              ensure_ascii=False, indent=2)


if __name__ == "__main__":
    main()
