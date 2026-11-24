"""Extraction-side ATS gates over what a parser actually reads out of the PDF.

JSK-T163 placeholder leakage, JSK-T168 word-boundary variance, JSK-T169 RTL
logical order, JSK-T174 heading recognition, JSK-T178 running header/footer and
hyphenation hygiene, JSK-T179 OCR consistency.  Each check returns a list of
problem strings (empty = clean) and every extractor-dependent check returns
``None`` from its probe when the tool is absent, so the caller can distinguish
"clean" from "could not determine" (rc 2 is never a pass).
"""
from __future__ import annotations

import html as _html
import re
import shutil
import subprocess
import unicodedata
from pathlib import Path
from typing import Callable, Dict, Iterable, List, Optional, Sequence

# --------------------------------------------------------------------------- T163
#: Placeholder tokens that must never survive into a finished document.  The
#: pattern is the SAME expression job_seeker's ``internal/templates/slots.go``
#: refuses at live approval (``reReserved``); ``test_manifest_contract`` asserts
#: the two sources are textually identical, so the registries cannot drift.
RESERVED_PATTERN = (r"(?i)\{\{|\}\}|\[(?:company|role|date|name|position|your[ _a-z]*)\]"
                    r"|<(?:company|role|date|name|position)>|\bTODO\b|\bXXX+\b|\blorem ipsum\b|\bFIXME\b|\bTBD\b")
#: Human-readable registry of what the pattern covers (documentation, mirrors slots.go ``ReservedTokens``).
RESERVED_TOKENS = ("{{", "}}", "[Company]", "[Role]", "[Date]", "<company>", "<role>", "<date>",
                   "TODO", "XXX", "FIXME", "TBD", "lorem ipsum")
_RESERVED = re.compile(RESERVED_PATTERN)


def check_placeholder_leak(text: str, lang: str | None = None) -> List[str]:
    """Reserved placeholder tokens in the extracted text (any locale: the tokens are ASCII)."""
    hits = sorted({m.group(0).lower() for m in _RESERVED.finditer(text)})
    return [f"placeholder token left in the text layer: {', '.join(hits[:5])}"] if hits else []


# --------------------------------------------------------------------------- T174
#: Section -> locale -> headings an ATS section parser recognises (the document's own label first,
#: then the common synonyms).  Matching is case-, accent- and punctuation-insensitive.
HEADING_ALIASES: Dict[str, Dict[str, tuple]] = {
    "experience": {
        "en": ("Experience", "Work experience", "Professional experience", "Employment history"),
        "sr": ("Искуство", "Радно искуство"), "ru": ("Опыт работы", "Профессиональный опыт"),
        "de": ("Erfahrung", "Berufserfahrung"), "es": ("Experiencia", "Experiencia laboral"),
        "fr": ("Expérience", "Expérience professionnelle"), "be": ("Досвед працы",),
        "zh": ("工作经历", "工作经验"), "kk": ("Жұмыс тәжірибесі",), "hi": ("अनुभव", "कार्य अनुभव"),
        "ja": ("職務経歴", "職歴"), "ko": ("경력",), "ar": ("الخبرة العملية", "الخبرة"),
        "tr": ("Deneyim", "İş deneyimi"), "fa": ("سوابق کاری",),
    },
    "education": {
        "en": ("Education",), "sr": ("Образовање",), "ru": ("Образование",), "de": ("Ausbildung", "Bildung"),
        "es": ("Educación", "Formación"), "fr": ("Formation", "Éducation"), "be": ("Адукацыя",),
        "zh": ("教育背景", "教育经历"), "kk": ("Білімі", "Білім"), "hi": ("शिक्षा",), "ja": ("学歴",),
        "ko": ("학력",), "ar": ("التعليم",), "tr": ("Eğitim",), "fa": ("تحصیلات",),
    },
    "skills": {
        "en": ("Technical skills", "Skills"), "sr": ("Техничке вештине", "Вештине"),
        "ru": ("Технические навыки", "Навыки"), "de": ("Technische Kenntnisse", "Kenntnisse", "Fähigkeiten"),
        "es": ("Habilidades técnicas", "Habilidades"), "fr": ("Compétences techniques", "Compétences"),
        "be": ("Тэхнічныя навыкі", "Навыкі"), "zh": ("技术技能", "技能"), "kk": ("Техникалық дағдылар", "Дағдылар"),
        "hi": ("तकनीकी कौशल", "कौशल"), "ja": ("技術スキル", "スキル"), "ko": ("보유 기술", "기술"),
        "ar": ("المهارات التقنية", "المهارات"), "tr": ("Teknik beceriler", "Beceriler"),
        "fa": ("مهارت‌های فنی", "مهارت‌ها"),
    },
}
#: Sections whose heading a CV must expose in recognisable form.
REQUIRED_HEADINGS = ("experience", "education", "skills")


def _hnorm(s: str) -> str:
    s = unicodedata.normalize("NFKC", s).replace("‌", "").replace("‍", "")
    s = "".join(c for c in unicodedata.normalize("NFD", s) if unicodedata.category(c) != "Mn" or ord(c) > 0x0900)
    return re.sub(r"[\W_]+", " ", s.casefold()).strip()


def recognise_heading(line: str, lang: str) -> Optional[str]:
    """The canonical section a line is a heading for in ``lang`` (exact alias match), else None."""
    n = _hnorm(line)
    for section, by_lang in HEADING_ALIASES.items():
        if any(_hnorm(a) == n for a in by_lang.get(lang, ())):
            return section
    return None


def check_headings(text: str, lang: str | None) -> List[str]:
    """Every required section heading appears as its own line and is recognised for ``lang``."""
    if lang is None:
        return ["heading recognition: locale unknown"]
    seen = {recognise_heading(l, lang) for l in text.splitlines() if l.strip()}
    missing = [s for s in REQUIRED_HEADINGS if s not in seen]
    return [f"section heading(s) not recognisable as a standalone line in '{lang}': {', '.join(missing)}"] if missing else []


# --------------------------------------------------------------------------- T178


def check_running_headers(pages: Sequence[str]) -> List[str]:
    """A line repeated at the top or bottom of every page (running header/footer) pollutes the parsed body.

    ``pages`` is the text of each page (``pdftotext`` form-feed split).  A single page cannot have one.
    """
    pages = [p for p in pages if p.strip()]
    if len(pages) < 2:
        return []

    def edge(p: str) -> set:
        ls = [l.strip() for l in p.splitlines() if l.strip()]
        return {ls[0], ls[-1]} if ls else set()
    # page numbers differ per page, so digits are folded before comparing
    folded = [{re.sub(r"\d+", "#", e) for e in edge(p)} for p in pages]
    common = {c for c in set.intersection(*folded) if len(c) > 3 and c != "#"}
    return ["running header/footer repeated on every page: " + ", ".join(sorted(common)[:3])] if common else []


#: A line-end hyphen followed by the next line's first word.  Left/right tokens keep their neighbours so a
#: compound such as ``Echtzeit-Bluetooth-`` / ``Kommunikation`` is reassembled whole.
_EOL_HYPHEN = re.compile(r"(\S*[^\W\d_])-[ \t]*\n[ \t]*([^\W\d_]\S*)")
#: Hyphens that exist in the SOURCE and merely sit at a line end are benign for the word they split (the
#: extracted tokens keep their own hyphen); they are only budgeted.  Measured on 22 fresh LuaLaTeX CVs/covers: max 4.
EXPLICIT_HYPHEN_BUDGET = 8


def plain_source_text(source: str) -> str:
    """The visible words of a ``.tex`` source: commands and braces removed, escapes undone, case folded."""
    t = re.sub(r"\\[A-Za-z@]+\*?", " ", source)
    t = re.sub(r"\\(.)", r"\1", t)
    t = re.sub(r"[{}]", " ", t)
    return " ".join(t.casefold().split())


def sibling_source_text(pdf: Path) -> Optional[str]:
    """The visible source next to a PDF: the ``.tex`` (LuaLaTeX engine) or the tag-stripped ``.html`` (WeasyPrint
    engine, ar/fa).  None when neither exists."""
    base = Path(pdf)
    tex, html = base.with_suffix(".tex"), base.with_suffix(".html")
    if tex.is_file():
        return tex.read_text(encoding="utf-8")
    if html.is_file():
        import html as _h
        body = re.sub(r"(?is)<(script|style)\b.*?</\1>", " ", html.read_text(encoding="utf-8"))
        return _h.unescape(re.sub(r"<[^>]+>", " ", body))
    return None


def hyphen_breaks(pages: Sequence[str], source: str | None) -> Dict[str, List[str]]:
    """Split every line-end hyphen into ``auto`` (a word the renderer cut: the source holds it unhyphenated) and
    ``explicit`` (the source itself has that hyphen).  ``source`` None => everything is ``auto`` (cannot excuse)."""
    plain = plain_source_text(source) if source is not None else None
    out: Dict[str, List[str]] = {"auto": [], "explicit": []}
    for i, p in enumerate((p for p in pages if p.strip()), 1):
        for m in _EOL_HYPHEN.finditer(p):
            left = re.sub(r"^\W+", "", m.group(1)).casefold()
            right = re.sub(r"[^\w/-]+$", "", m.group(2)).casefold()
            whole = f"{left}-{right}"
            kind = "explicit" if plain is not None and whole in plain else "auto"
            out[kind].append(f"p{i}:{whole}")
    return out


def check_hyphenation(pages: Sequence[str], source: str | None = None,
                      explicit_budget: int = EXPLICIT_HYPHEN_BUDGET) -> List[str]:
    """No word cut by automatic hyphenation (G-19: an extractor that joins lines literally reads ``Post- greSQL``);
    breaks at hyphens the source itself carries are budgeted, not forbidden."""
    b = hyphen_breaks(pages, source)
    problems: List[str] = []
    if b["auto"]:
        problems.append(f"{len(b['auto'])} word(s) split by automatic hyphenation at a line end: "
                        + ", ".join(b["auto"][:4]))
    if len(b["explicit"]) > explicit_budget:
        problems.append(f"{len(b['explicit'])} line-end breaks at source hyphens exceed the budget {explicit_budget}")
    return problems


def check_extraction_hygiene(pages: Sequence[str], source: str | None = None) -> List[str]:
    return check_running_headers(pages) + check_hyphenation(pages, source)


# --------------------------------------------------------------------------- extractors
def _run(cmd: list, timeout: int = 120) -> Optional[str]:
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
    except (OSError, subprocess.SubprocessError):
        return None
    return r.stdout if r.returncode == 0 else None


def extract_poppler_raw(pdf: Path) -> Optional[str]:
    return _run(["pdftotext", "-raw", str(pdf), "-"]) if shutil.which("pdftotext") else None


def extract_poppler_layout(pdf: Path) -> Optional[str]:
    return _run(["pdftotext", "-layout", str(pdf), "-"]) if shutil.which("pdftotext") else None


def extract_mupdf(pdf: Path) -> Optional[str]:
    return _run(["mutool", "draw", "-q", "-F", "txt", str(pdf)]) if shutil.which("mutool") else None


def extract_pypdf(pdf: Path) -> Optional[str]:
    try:
        import pypdf  # type: ignore
        return "\n".join((p.extract_text() or "") for p in pypdf.PdfReader(str(pdf)).pages)
    except Exception:  # noqa: BLE001
        return None


def pages_of(pdf: Path) -> Optional[List[str]]:
    t = extract_poppler_layout(pdf)
    return None if t is None else t.split("\f")


# --------------------------------------------------------------------------- T168
_TOK = re.compile(r"[^\s]+")
#: min/max token count across the independent extractors.  Measured pre-fix: hi 530/1004 (0.53), ko 515/929 (0.55).
MIN_BOUNDARY_RATIO = 0.90
#: Scripts written without inter-word spaces: a "token" there is a line fragment, so the counts legitimately differ.
UNSPACED_LANGS = frozenset({"zh", "ja"})
#: pypdf assembles a right-to-left line from visually ordered runs and fuses the words around every embedded
#: Latin/number run (measured on a fresh ai-engineering CV: ar 891 vs 1007/1053, fa 918 vs 1012/1069, min/max 0.85/0.86
#: with the same space glyphs present in the stream).  That is the logical-order problem (T169), not a missing
#: interword glyph, so for ar/fa the boundary vote is MuPDF vs poppler; pypdf is still counted everywhere else.
RTL_LANGS = frozenset({"ar", "fa"})


def boundary_counts(pdf: Path) -> Dict[str, int]:
    """Whitespace-token count per available independent extractor (MuPDF, poppler -raw, pypdf)."""
    outs = {"mupdf": extract_mupdf(pdf), "poppler-raw": extract_poppler_raw(pdf), "pypdf": extract_pypdf(pdf)}
    return {n: len(_TOK.findall(t)) for n, t in outs.items() if t and t.strip()}


def check_word_boundaries(pdf: Path, lang: str | None = None) -> Optional[List[str]]:
    """Token counts of every independent extractor must agree (a missing interword glyph merges words in one).

    ``min/max >= 0.9`` over MuPDF, poppler and pypdf.  zh/ja are exempt (no inter-word spaces by nature).
    Returns None when fewer than two extractors exist (cannot determine; rc 2 is never a pass).
    """
    if lang in UNSPACED_LANGS:
        return []
    c = boundary_counts(pdf)
    if lang in RTL_LANGS:
        c.pop("pypdf", None)
    if len(c) < 2:
        return None
    lo, hi = min(c.values()), max(c.values())
    if hi and lo / hi < MIN_BOUNDARY_RATIO:
        return ["word boundaries differ between extractors (min/max %.2f < %.2f): %s"
                % (lo / hi, MIN_BOUNDARY_RATIO, ", ".join(f"{n} {v}" for n, v in sorted(c.items())))]
    return []


# --------------------------------------------------------------------------- T169
def _squash(s: str) -> str:
    t = re.sub(r"[\s‌‍‎‏‪-‮⁦-⁩ـ]+", "", unicodedata.normalize("NFKC", s))
    return "".join(c for c in t if unicodedata.category(c) != "Mn")


#: Pure right-to-left-script words: Arabic-script letters, marks and the zero-width joiners Persian uses; a token that
#: carries a Latin letter or a digit is not one (the extractors disagree on where an embedded Latin run goes).
def _is_rtl_word(tok: str) -> bool:
    """Arabic-script letters and marks only (plus the zero-width joiners Persian uses): no punctuation, digit or
    Latin character, because the extractors disagree on where those go relative to a word."""
    return bool(tok) and all(ch in "\u200c\u200d" or (unicodedata.category(ch)[0] in "LM"
                                                     and unicodedata.name(ch, "").startswith("ARABIC")) for ch in tok)


#: Words per phrase.  Three keeps the probe sensitive to word ORDER (one word cannot be reversed) while a phrase
#: of pure Arabic-script words survives every position-aware extractor unchanged.
RTL_PHRASE_WORDS = 3
#: Supported ATS readers of right-to-left documents (JSK-T169, operator decision 2026-11-24): poppler
#: ``pdftotext -layout`` and MuPDF, both of which read a line in LOGICAL order.  NOT supported, by design:
#: ``pdftotext -raw`` (dumps content-stream order and re-applies its own RTL reversal, so it returns the words of
#: every Arabic/Persian line reversed for any renderer; measured forward 1 / reversed 6 on a fresh ar CV) and
#: position-less readers.  A PDF cannot be in visual order for ``-raw`` and logical order for MuPDF at once, and
#: marking the text up with /ActualText did not help (poppler reverses it again), so the target set is a choice.
#: Share of the known phrases that must read forward in each supported reader (measured 87-97% on fresh builds).
MIN_RTL_FORWARD = 0.80
RTL_TARGET_EXTRACTORS = ("pdftotext-layout", "mupdf")


def rtl_phrases_from_source(source: str, words: int = RTL_PHRASE_WORDS) -> List[str]:
    """Known-logical phrases from the document's own source: every ``words`` consecutive pure RTL-script words that
    sit in ONE text node (tags and punctuation end a run).  The source is written in logical order by construction."""
    out: List[str] = []
    body = re.sub(r"(?is)<(head|script|style)\b.*?</\1>", " ", source)
    body = _html.unescape(re.sub(r"<[^>]+>", "\n", body))
    for node in body.split("\n"):
        run: List[str] = []
        for tok in re.split(r"\s+", node) + [""]:
            if _is_rtl_word(tok):
                run.append(tok)
                continue
            for i in range(0, len(run) - words + 1, words):
                out.append(" ".join(run[i:i + words]))
            run = []
    return list(dict.fromkeys(out))


def _rtl_extractions(pdf: Path) -> Dict[str, Optional[str]]:
    return {"pdftotext-layout": extract_poppler_layout(pdf), "mupdf": extract_mupdf(pdf)}


def rtl_order_counts(pdf: Path, phrases: Iterable[str]) -> Optional[Dict[str, Dict[str, int]]]:
    """Per supported reader: how many known phrases appear forward (logical order), how many only word-reversed."""
    fwd = list(dict.fromkeys(q for q in (_squash(p) for p in phrases if p) if len(q) >= 4))
    outs = _rtl_extractions(pdf)
    if not fwd or any(not t for t in outs.values()):
        return None
    res: Dict[str, Dict[str, int]] = {}
    for name, text in outs.items():
        flat = _squash(text)
        res[name] = {"phrases": len(fwd), "forward": sum(q in flat for q in fwd), "reversed": 0}
    rev = {p: _squash(" ".join(reversed(p.split()))) for p in phrases if p and len(_squash(p)) >= 4}
    for name, text in outs.items():
        flat = _squash(text)
        res[name]["reversed"] = sum(1 for p, r in rev.items() if r in flat and _squash(p) not in flat)
    return res


def check_rtl_logical_order(pdf: Path, phrases: Iterable[str]) -> Optional[List[str]]:
    """In BOTH supported readers (``RTL_TARGET_EXTRACTORS``) at least ``MIN_RTL_FORWARD`` of the known phrases are
    present in logical order.

    Not 100%: a phrase that wraps onto the next line next to an embedded Latin run is legitimately split by both
    readers (measured 4-12% of phrases on fresh ar/fa CVs and covers), whereas a renderer that writes the words
    visually leaves almost none forward.  ``pdftotext -raw`` is excluded by design (see ``RTL_TARGET_EXTRACTORS``).
    None = cannot determine: a target extractor is absent or no phrase exists (rc 2 is never a pass).
    """
    counts = rtl_order_counts(pdf, phrases)
    if counts is None:
        return None
    problems: List[str] = []
    for name, c in counts.items():
        share = c["forward"] / c["phrases"]
        if share < MIN_RTL_FORWARD:
            problems.append(f"RTL words not in logical order in {name}: {c['forward']}/{c['phrases']} phrases forward "
                            f"({share:.0%} < {MIN_RTL_FORWARD:.0%}), {c['reversed']} word-reversed; supported readers: "
                            + ", ".join(RTL_TARGET_EXTRACTORS))
    return problems


def check_rtl_document(pdf: Path, lang: str | None) -> Optional[List[str]]:
    """T169 for one document: the phrases come from its sibling source.  [] for left-to-right locales."""
    if lang not in RTL_LANGS:
        return []
    html = Path(pdf).with_suffix(".html")
    if not html.is_file():
        return None
    return check_rtl_logical_order(pdf, rtl_phrases_from_source(html.read_text(encoding="utf-8")))


# --------------------------------------------------------------------------- T179
#: tesseract language packs per locale; always combined with ``eng`` because every document holds Latin
#: technology names and URLs (a single-language run reads 3.6% of them: 60% overall recall measured).
OCR_LANG = {"en": "eng", "ru": "rus+eng", "sr": "srp+eng", "de": "deu+eng", "fr": "fra+eng"}
MIN_OCR_RECALL = 0.90


def _words(s: str) -> List[str]:
    return [w for w in re.findall(r"[^\W\d_]{3,}", s.casefold())]


def ocr_applicable(lang: str | None) -> bool:
    """Locales with a configured tesseract language set.  The others (hi, ko, ar, ...) need an operator-installed
    model (Q-ATS-6); for them OCR is NOT APPLICABLE, which is stated, not a pass of the OCR check."""
    return lang in OCR_LANG


def ocr_recall(pdf: Path, lang: str, dpi: int = 200, first_page_only: bool = True,
               spec: str | None = None) -> Optional[float]:
    """Share of the text layer's words (>= 3 letters) that OCR of the rendered page also reads.

    ``first_page_only`` keeps the per-document cost at a few seconds (measured 3-9 s a page).  ``spec`` overrides
    the tesseract language set (tests use it to show that a single-language run mis-reads the Latin words).
    None when tesseract, pdftoppm or the locale's language pack is missing (cannot determine).
    """
    spec = spec or OCR_LANG.get(lang)
    if not spec or not shutil.which("tesseract") or not shutil.which("pdftoppm"):
        return None
    have = _run(["tesseract", "--list-langs"]) or ""
    if any(p not in have.split() for p in spec.split("+")):
        return None
    layer_pages = pages_of(pdf)
    if not layer_pages or not any(p.strip() for p in layer_pages):
        return None
    layer = layer_pages[0] if first_page_only else "\n".join(layer_pages)
    import tempfile
    with tempfile.TemporaryDirectory(prefix="ocr-") as td:
        cmd = ["pdftoppm", "-r", str(dpi), "-png"] + (["-f", "1", "-l", "1"] if first_page_only else []) + [str(pdf), f"{td}/p"]
        subprocess.run(cmd, capture_output=True, timeout=300)
        pngs = sorted(Path(td).glob("p*.png"))
        if not pngs:
            return None
        ocr = ""
        for png in pngs:
            out = _run(["tesseract", str(png), "-", "-l", spec], 300)
            if out is None:
                return None
            ocr += out + "\n"
    want = _words(layer)
    got = set(_words(ocr))
    return (sum(1 for w in want if w in got) / len(want)) if want else None


def check_ocr_consistency(pdf: Path, lang: str) -> Optional[List[str]]:
    """The visible page (OCR) and the text layer must agree: recall >= MIN_OCR_RECALL.  None = cannot determine."""
    r = ocr_recall(pdf, lang)
    if r is None:
        return None
    return [] if r >= MIN_OCR_RECALL else [f"OCR recall {r:.0%} below {MIN_OCR_RECALL:.0%} for '{lang}' ({OCR_LANG[lang]})"]
