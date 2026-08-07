#!/usr/bin/env python3
"""Translate the 24 PDF chrome strings EN -> target lang via the real
HelixTranslate engine (mistral), glossary-protected, in ONE call per language.

Robustness:
  * values are joined with a protected separator sentinel (Z9SEPnnnZ9) so the
    24 strings are recoverable regardless of how the engine reflows paragraphs;
  * the translated blob is normalized (Arabic-Indic/Persian digits -> ASCII,
    bidi control chars stripped) before sentinel restore, so RTL mangling of the
    Z9TERM/Z9SEP sentinels does not break recovery;
  * Serbian is translated in Latin then transliterated to Cyrillic via
    cyrillize_sr.py (the established pipeline path).
Prints JSON {lang, method, values}."""
import json, os, re, subprocess, sys, tempfile, time

REPO = "/Volumes/T7/Projects/vasic"
TDIR = os.path.join(REPO, "_tools", "translate")
GLOSSARY = os.path.join(TDIR, "glossary.json")
PROTECT = os.path.join(TDIR, "glossary_protect.py")
CYR = os.path.join(TDIR, "cyrillize_sr.py")
HELIX = "/tmp/helixtranslate"
MISTRAL_KEY = os.environ["MISTRAL_API_KEY"]

TOC_WORDS = {
    "Contents", "Inhalt", "Inhaltsverzeichnis", "Содержание", "Sadržaj", "Sadrzaj",
    "Table des matières", "Contenido", "Índice", "İçindekiler", "Icindekiler",
    "内容", "目录", "目次", "コンテンツ", "내용", "목차", "المحتويات", "المحتوى",
    "फ़िहरिस्त", "विषय-सूची", "विषय सूची", "सामग्री", "Мазмұны", "Змест", "فهرست",
    "فهرست مطالب", "Мазмуны", "Содржина",
}

# Arabic-Indic (٠-٩) and Persian (۰-۹) digit -> ASCII
_DIGIT_MAP = {ord("٠") + i: str(i) for i in range(10)}
_DIGIT_MAP.update({ord("۰") + i: str(i) for i in range(10)})
_BIDI = "".join(chr(c) for c in
                (0x200E, 0x200F, 0x202A, 0x202B, 0x202C, 0x202D, 0x202E,
                 0x2066, 0x2067, 0x2068, 0x2069, 0x061C))
_BIDI_RE = re.compile("[" + re.escape(_BIDI) + "]")


def script_for(lang):
    if lang in ("ru", "be", "kk", "bg", "mk", "sr_cyrl"):
        return "cyrillic"
    if lang in ("ar", "fa"):
        return "arabic"
    if lang in ("zh", "ja", "ko", "hi"):
        return "default"
    return "latin"


def helix(text, lang, script, retries=6):
    with tempfile.TemporaryDirectory() as w:
        inp, out = os.path.join(w, "in.md"), os.path.join(w, "out.md")
        open(inp, "w", encoding="utf-8").write(text)
        last = ""
        for attempt in range(retries + 1):
            if os.path.exists(out):
                os.remove(out)
            p = subprocess.run(
                [HELIX, "-i", inp, "-o", out, "-provider", "mistral",
                 "-model", "mistral-large-latest", "-api-key", MISTRAL_KEY,
                 "-source-lang", "en", "-target-lang", ("sr" if lang == "sr" else lang),
                 "-script", script, "-verify=false", "-timeout", "120s"],
                capture_output=True, text=True)
            if p.returncode == 0 and os.path.exists(out) and os.path.getsize(out) > 0:
                return open(out, encoding="utf-8").read()
            last = p.stderr[-400:]
            time.sleep(min(60, (attempt + 1) ** 2 * 5))
        raise RuntimeError("HelixTranslate failed lang=%s: %s" % (lang, last))


def protect(text):
    with tempfile.TemporaryDirectory() as w:
        m = os.path.join(w, "map.json")
        p = subprocess.run(["python3", PROTECT, "protect", "--glossary", GLOSSARY,
                            "--map", m], input=text, capture_output=True, text=True)
        p.check_returncode()
        return p.stdout, json.load(open(m, encoding="utf-8"))


def normalize(text):
    text = text.translate(_DIGIT_MAP)
    text = _BIDI_RE.sub("", text)
    return text


def restore_local(text, mapping):
    """Tolerant restore: match Z9TERM<num>Z9 case-insensitively, allowing stray
    spaces the engine may inject. Falls back to glossary_protect for the strict
    leftover check."""
    num2term = mapping.get("num2term", mapping)
    def sub(m):
        return num2term.get(str(int(m.group(1))), m.group(0))
    pat = re.compile(r"[Zz]\s*9\s*[Tt][Ee][Rr][Mm]\s*(\d{1,4})\s*[Zz]\s*9")
    return pat.sub(sub, text)


def strip_toc(text):
    lines = text.split("\n")
    i = 0
    while i < len(lines) and lines[i].strip() == "":
        i += 1
    if i < len(lines) and lines[i].strip() in TOC_WORDS:
        i += 1
    return "\n".join(lines[i:])


def one_line(s):
    return " ".join(l.strip() for l in s.split("\n") if l.strip()).strip()


def cyrillize(text):
    p = subprocess.run(["python3", CYR, "text"], input=text, capture_output=True, text=True)
    p.check_returncode()
    return p.stdout.rstrip("\n")


SEP_RE = re.compile(r"[Zz]\s*9\s*[Ss][Ee][Pp]\s*(\d{1,4})\s*[Zz]\s*9")


def main():
    lang = sys.argv[1]
    en = json.load(open(os.path.join(REPO, "_tools/pdf/pdf-i18n.json"), encoding="utf-8"))["en"]
    keys = list(en.keys())
    script = script_for(lang)

    # Join with protected separators. Each value on its own; separators are
    # sentinel-shaped so the engine preserves them, and recoverable if mangled.
    sep = lambda i: "\n\nZ9SEP%03dZ9\n\n" % i
    blob = ""
    for i, k in enumerate(keys):
        if i:
            blob += sep(i)
        blob += en[k]

    prot, mapping = protect(blob)
    tr = helix(prot, lang, script)
    tr = normalize(tr)
    tr = restore_local(tr, mapping)
    parts = SEP_RE.split(tr)
    # SEP_RE.split yields [text, num, text, num, ...]; keep the text segments.
    segs = [parts[j] for j in range(0, len(parts), 2)]
    segs = [one_line(strip_toc(s)) for s in segs]
    segs = [s for s in segs if s != ""]

    method = "blob-sep"
    if len(segs) != len(keys):
        sys.stderr.write("SEP split mismatch (%d != %d) for %s\n" % (len(segs), len(keys), lang))
        # last-resort: paragraph split
        para = [one_line(p) for p in re.split(r"\n\s*\n", strip_toc(tr)) if one_line(p)]
        if len(para) == len(keys):
            segs, method = para, "blob-para"
        else:
            raise SystemExit("cannot recover %d segments for %s (sep=%d para=%d)"
                             % (len(keys), lang, len(segs), len(para)))

    # FAIL LOUD if any sentinel survived (never leak a Z9TERM/Z9SEP into a PDF).
    leaked = re.search(r"[Zz]\s*9\s*([Tt][Ee][Rr][Mm]|[Ss][Ee][Pp])", " ".join(segs))
    if leaked:
        raise SystemExit("leftover sentinel after restore for %s: %r" % (lang, leaked.group(0)))

    result = dict(zip(keys, segs))
    if lang == "sr":
        result = {k: cyrillize(v) for k, v in result.items()}
    print(json.dumps({"lang": lang, "method": method, "values": result}, ensure_ascii=False))


if __name__ == "__main__":
    main()
