"""Extraction-side ATS gates over what a parser actually reads out of the PDF.

JSK-T163 placeholder leakage, JSK-T168 word-boundary variance, JSK-T169 RTL
logical order, JSK-T174 heading recognition, JSK-T178 running header/footer and
hyphenation hygiene, JSK-T179 OCR consistency.  Each check returns a list of
problem strings (empty = clean) and every extractor-dependent check returns
``None`` from its probe when the tool is absent, so the caller can distinguish
"clean" from "could not determine" (rc 2 is never a pass).
"""
from __future__ import annotations

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
_SOFT_BREAK = re.compile(r"[^\W\d_]-\n[^\W\d_]")  # letter, hyphen at end of line, letter: a word split across lines


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


def check_hyphenation(pages: Sequence[str]) -> List[str]:
    """Words split by a line-end hyphen.  MEASURED, NOT A BLOCKING GATE: the renderer hyphenates (G-19)."""
    for i, p in enumerate((p for p in pages if p.strip()), 1):
        m = _SOFT_BREAK.search(p)
        if m:
            return [f"word split by a line-end hyphen on page {i}: {m.group(0).replace(chr(10), '⏎')!r}"]
    return []


def check_extraction_hygiene(pages: Sequence[str]) -> List[str]:
    return check_running_headers(pages) + check_hyphenation(pages)


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
    return re.sub(r"[\s‌‍‎‏‪-‮⁦-⁩]+", "", unicodedata.normalize("NFKC", s))


def check_rtl_logical_order(pdf: Path, phrases: Iterable[str], min_extractors: int = 2) -> Optional[List[str]]:
    """In at least ``min_extractors`` independent extractors every known phrase is present in logical order.

    ``pdftotext -raw`` is excluded by design: it dumps content-stream order, which is visual for any
    RTL renderer that writes runs left to right (docs/qa/career/career-engine-wave1-2026-11-24.md, T169).
    Returns None when fewer than ``min_extractors`` extractors exist (cannot determine).
    """
    phrases = [_squash(p) for p in phrases if p and len(_squash(p)) >= 4]
    outs = [("pdftotext-layout", extract_poppler_layout(pdf)), ("mupdf", extract_mupdf(pdf)),
            ("pypdf", extract_pypdf(pdf))]
    outs = [(n, _squash(t)) for n, t in outs if t]
    if len(outs) < min_extractors or not phrases:
        return None
    good = [n for n, t in outs if all(p in t for p in phrases)]
    if len(good) < min_extractors:
        return [f"RTL logical order holds in {len(good)} of {len(outs)} extractors (need {min_extractors}); "
                f"ok: {', '.join(good) or 'none'}"]
    return []


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
