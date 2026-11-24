"""ATS artifact gate.

The gate reads the *rendered PDF* and validates what it can prove about the
artifact itself: the text layer is present, extractable and free of the
classic parser-poisoning codepoints, the layout is single-column, the page
count is in budget, and the fonts are embedded and subsetted.

It deliberately does NOT duplicate ``screen.py``'s HR criteria (expected
sections, counts, keyword coverage, standards) -- those validate the
DocumentModel against recruiter expectations, a different question from
"can a machine read this file?".

Output: exit code 0 if valid, 1 if invalid, 2 if indeterminate (missing PDF,
unparseable text, missing tool).  ``validate_document`` accepts a text string
directly so tests can drive it without PDFs.
"""

from __future__ import annotations

import re
import subprocess
from pathlib import Path
from typing import List, Tuple

try:
    from . import extract_gates
except ImportError:  # run as a script
    import extract_gates  # type: ignore

#: Classified as extraction garbage by every ATS we have a reading of.
#: ZWNJ/ZWJ/LRM/RLM (U+200C-200F) are deliberately absent: Persian/Arabic
#: typography needs them and extractors drop them.
_NO_ARTIFACT_RANGES = (
    (0xFB00, 0xFB06),   # Latin ligatures ff..st (incl. long-s t, st) -- THE classic ATS poison
    (0xF900, 0xFAFF),   # CJK compatibility ideographs -- a font mapping unified ideographs here breaks keyword match
    (0xFF10, 0xFF19),   # fullwidth digits -- "17" becomes １７
    (0xFF01, 0xFF5E),   # fullwidth ASCII punctuation and brackets
    (0xE000, 0xF8FF),   # private-use area: icon-font glyphs, bullets mapped to PUA
    (0x200B, 0x200B),   # zero-width space: splits keywords invisibly
    (0x00AD, 0x00AD),   # soft hyphen: splits keywords when extracted
    (0x0000, 0x0008), (0x000B, 0x000B), (0x000E, 0x001F),  # C0 controls (TAB/LF/FF/CR allowed)
    (0x007F, 0x009F),   # DEL and C1 controls
)
# Deliberately NOT forbidden: U+2013/U+2014.  Em and en dashes extract as
# themselves in every parser we can test, and forbidding them would flag a
# perfectly readable "Mar 2020 – Dec 2024" -- the ATS-poison range is
# ligatures and fullwidth forms, not punctuation.

#: No tool call may produce these: they are the artifacts of moving text
#: into or out of binary form in the wrong order.
_FORBIDDEN_CODEPOINTS = {0xFFFD, 0x202A, 0x202B, 0x202C, 0x202D, 0x202E, 0x2066, 0x2067, 0x2068, 0x2069}

#: Arabic presentation forms.  A text layer holding these (what LuaTeX writes
#: into ToUnicode for shaped Arabic) never matches a keyword typed with the base
#: letters, so it is as fatal to an ATS as a ligature.
_PRESENTATION_FORMS = ((0xFB50, 0xFDFF), (0xFE70, 0xFEFF))

#: Locales whose own typography uses fullwidth punctuation.  Measured on the
#: built PDFs: zh uses （ ） ， ； ： and ja uses （ ） ： ／ ＋; ko output contains
#: none (Korean uses ASCII punctuation), so ko gets NO exemption.  Fullwidth
#: digits and Latin letters stay forbidden everywhere (``17`` -> ``１７``), and
#: ＠ ． ＼ stay forbidden even here: they only ever appear when an e-mail
#: address or URL was mangled.
_CJK_LANGS = frozenset({"zh", "ja"})
_FULLWIDTH_PUNCT = frozenset(map(ord, "（），；！？：／＋"))
#: ``http：／／`` and ``a／／b``: a URL scheme rewritten with fullwidth marks.
_FULLWIDTH_URL_RE = re.compile("[：／]／|：／")
#: Script a locale's document body must actually contain.  A build that fell
#: back to the Latin font would otherwise emit a well-formed, "valid" PDF
#: whose text layer has no Hindi, Chinese, ... in it at all.
_SCRIPT_RANGES = {
    "hi": ((0x0900, 0x097F),),
    "ar": ((0x0600, 0x06FF),),
    "fa": ((0x0600, 0x06FF),),
    "ja": ((0x3040, 0x30FF), (0x4E00, 0x9FFF)),
    "zh": ((0x4E00, 0x9FFF),),
    "ko": ((0xAC00, 0xD7A3),),
    "ru": ((0x0400, 0x04FF),),
    "be": ((0x0400, 0x04FF),),
    "kk": ((0x0400, 0x04FF),),
    "sr": ((0x0400, 0x04FF),),
}
_RTL_LANGS = frozenset({"ar", "fa"})
_MIN_SCRIPT_CHARS = 200

_PAGE_LIMITS = {"cv": 3, "cover": 2}


def _check_extractable(text: str) -> List[str]:
    problems: List[str] = []
    if not text or not text.strip():
        return ["text layer is empty or missing"]
    bad = sorted({ch for ch in text if ord(ch) in _FORBIDDEN_CODEPOINTS})
    if bad:
        names = ", ".join(f"U+{ord(c):04X}" for c in bad)
        problems.append(f"text layer contains forbidden codepoints: {names}")
    return problems


def _check_no_artifacts(text: str, lang: str | None = None) -> List[str]:
    problems: List[str] = []
    for start, end in _NO_ARTIFACT_RANGES:
        hits = sorted({ch for ch in text if start <= ord(ch) <= end})
        if lang in _CJK_LANGS and start == 0xFF01 and end == 0xFF5E:
            hits = [c for c in hits if ord(c) not in _FULLWIDTH_PUNCT]
        if hits:
            names = ", ".join(f"U+{ord(c):04X}" for c in hits)
            problems.append(f"text layer contains non-ATS codepoints: {names}")
    if lang in _CJK_LANGS and _FULLWIDTH_URL_RE.search(text):
        problems.append("text layer holds a fullwidth URL scheme (：／ or ／／)")
    forms = sorted({ch for ch in text for lo, hi in _PRESENTATION_FORMS if lo <= ord(ch) <= hi})
    if forms:
        problems.append("text layer holds Arabic presentation forms instead of base letters: "
                        + ", ".join(f"U+{ord(c):04X}" for c in forms[:6]))
    return problems


def _norm(s: str) -> str:
    import unicodedata
    # ZWNJ/ZWJ/LRM/RLM: Pango (and every extractor) drops them from the text
    # layer, so a source phrase carrying them must be compared without them.
    s = "".join(ch for ch in s if ch not in "\u200c\u200d\u200e\u200f")
    return " ".join(unicodedata.normalize("NFC", s).split())


def _strip_bidi_controls(text: str) -> str:
    return "".join(ch for ch in text if ord(ch) not in _BIDI_CONTROLS)


_BIDI_CONTROLS = frozenset({0x202A, 0x202B, 0x202C, 0x202D, 0x202E, 0x2066, 0x2067, 0x2068, 0x2069})


def _check_script_coverage(text: str, lang: str | None) -> List[str]:
    """The locale's own script must be present in volume, with no tofu."""
    ranges = _SCRIPT_RANGES.get(lang or "")
    if not ranges:
        return []
    n = sum(1 for ch in text if any(lo <= ord(ch) <= hi for lo, hi in ranges))
    if n < _MIN_SCRIPT_CHARS:
        return [f"locale {lang!r} text layer holds only {n} characters of its own script "
                f"(< {_MIN_SCRIPT_CHARS}): wrong or missing font"]
    return []


def _check_phrases(texts: List[str], phrases: List[str]) -> List[str]:
    """Each known source phrase must appear as ONE contiguous string, in logical order.

    ``texts`` are the independent extractions; a phrase found in any of them
    counts.  Reversed or fragmented RTL runs are exactly what fails this.
    """
    # Whitespace is dropped on both sides: CJK has no inter-word spaces, so a
    # line wrap inside a word surfaces as a space/newline that is not in the
    # source.  Order and contiguity of the characters are still enforced.
    squash = lambda x: "".join(_norm(x).split())  # noqa: E731
    normed = [squash(t) for t in texts if t]
    return [f"known phrase not contiguous/in logical order in text layer: {p!r}"
            for p in phrases if squash(p) and not any(squash(p) in t for t in normed)]


def _check_single_column(source: str) -> List[str]:
    """Source-level check: the LaTeX *source* must not declare columns.

    This is only meaningful on ``.tex`` text -- ``pdftotext`` output never
    contains LaTeX commands.  The artifact-level check is
    :func:`_check_single_column_pdf`.
    """
    if "\\begin{paracol" in source or "\\begin{multicols" in source:
        return ["document declares a two-column layout"]
    return []


_BBOX_WORD = re.compile(
    r'<word xMin="([\d.]+)" yMin="([\d.]+)" xMax="([\d.]+)" yMax="([\d.]+)">')
_BBOX_PAGE = re.compile(r'<page width="([\d.]+)" height="([\d.]+)"')


def _gutter_pages(bbox_html: str) -> List[int]:
    """Pages (1-based) whose word boxes show a central gutter on most lines.

    A line is "two-sided" when it has words left of 45% and right of 55% of the
    page width.  It shows a gutter when two consecutive words are separated by
    a gap wider than 1.2% of the page width inside the 35-65% band (a normal
    inter-word space is ~0.5%).  A page is two-column when it has >= 5 gutter
    lines and they are >= 40% of its two-sided lines.
    """
    flagged: List[int] = []
    for pno, chunk in enumerate(bbox_html.split("<page ")[1:], start=1):
        m = _BBOX_PAGE.match("<page " + chunk)
        if not m:
            continue
        width = float(m.group(1))
        # Words of one visual line differ in yMin when the line mixes fonts
        # (measured: a CJK box starts 4 pt above the Latin box beside it, and
        # 0.56 pt on Korean).  Grouping by integer yMin split such a line into
        # fragments, each looking like a line with a hole in the middle -- a
        # false "gutter".  Group by vertical CENTRE within 4 pt (line pitch of
        # any CV here is >= 12 pt, so distinct lines never merge).
        found = sorted(((float(y0) + float(y1)) / 2.0, float(x0), float(x1))
                       for x0, y0, x1, y1 in _BBOX_WORD.findall(chunk))
        lines: dict = {}
        anchor = None
        for yc, x0, x1 in found:
            if anchor is None or yc - anchor > 4.0:
                anchor = yc
            lines.setdefault(anchor, []).append((x0, x1))
        two_sided = gutter = 0
        for words in lines.values():
            words.sort()
            if not (words[0][0] < 0.45 * width and max(w[1] for w in words) > 0.55 * width):
                continue
            two_sided += 1
            for (_a0, a1), (b0, _b1) in zip(words, words[1:]):
                if b0 - a1 > 0.012 * width and a1 >= 0.35 * width and b0 <= 0.65 * width:
                    gutter += 1
                    break
        if gutter >= 5 and gutter >= 0.4 * two_sided:
            flagged.append(pno)
    return flagged


def _check_single_column_pdf(pdf_path: Path) -> List[str]:
    """Artifact-level single-column check from ``pdftotext -bbox`` geometry."""
    out = subprocess.run(
        ["pdftotext", "-bbox", str(pdf_path), "-"], capture_output=True, text=True, timeout=60
    )
    if out.returncode != 0:
        return ["pdftotext -bbox could not read the PDF"]
    pages = _gutter_pages(out.stdout)
    if pages:
        return ["layout is multi-column (central gutter on page(s) " + ", ".join(map(str, pages)) + ")"]
    return []


def _check_contact_urls(text: str, urls: List[str]) -> List[str]:
    """Every contact URL must appear intact (one unbroken string) in the text."""
    wanted = [u for u in urls if u]
    if not wanted:
        return ["no contact URLs to check: the source/doc lists none, so intactness is unproven"]
    return [f"contact URL not intact in text layer: {u}" for u in wanted if u not in text]


def _expected_contacts(pdf_path: Path, contacts: List[str] | None) -> List[str]:
    """Contacts the PDF must carry: the resolved doc's when given, else the source's."""
    given = [c for c in (contacts or []) if c]
    if given:
        return given
    return _tex_contact_urls(Path(pdf_path).with_suffix(".tex"))


#: ``\href{target}{label}``: the visible label is what the text layer carries.
_HREF_RE = re.compile(r"\\href\{([^}]*)\}\{([^}]*)\}")


_HTML_LABEL_RE = re.compile(r'<span class="u"><a href="[^"]*">([^<]*)</a></span>')


def _tex_contact_urls(tex_path: Path) -> List[str]:
    """Contact URLs the renderer wrote into the sibling source.

    ``.tex``: ``\\href`` visible labels.  ``.html`` (RTL engine): the visible link labels.
    """
    html_path = tex_path.with_suffix(".html")
    if not tex_path.is_file() and html_path.is_file():
        import html as _h
        return [_h.unescape(x) for x in _HTML_LABEL_RE.findall(html_path.read_text(encoding="utf-8"))]
    if not tex_path.is_file():
        return []
    urls = []
    for _target, t in _HREF_RE.findall(tex_path.read_text(encoding="utf-8")):
        u = t.replace("\\%", "%").replace("\\#", "#").replace("\\_", "_")
        if u not in urls:
            urls.append(u)
    return urls


def _link_annotations(pdf_path: Path) -> List[Tuple[str, str]]:
    """Every ``/Link`` annotation as ``(action kind, target)``.

    ``kind`` is the action subtype without the slash (``URI``, ``GoToR``,
    ``Launch``, ``GoTo``, or ``none`` for a link without an action).  For
    ``URI`` the target is the URI string; otherwise it is empty.  Raises
    ``RuntimeError`` when the file cannot be parsed (callers map that to 2).
    """
    try:
        import pypdf  # type: ignore
        out: List[Tuple[str, str]] = []
        for page in pypdf.PdfReader(str(pdf_path)).pages:
            for ref in page.get("/Annots") or []:
                annot = ref.get_object()
                if annot.get("/Subtype") != "/Link":
                    continue
                act = annot.get("/A")
                act = act.get_object() if act is not None else {}
                kind = str(act.get("/S") or "/none").lstrip("/")
                out.append((kind, str(act.get("/URI", "")) if kind == "URI" else ""))
        return out
    except Exception as exc:  # noqa: BLE001 -- unparseable means "cannot determine"
        raise RuntimeError(f"cannot read link annotations: {exc}") from exc


_ALLOWED_LINK_SCHEMES = ("mailto:", "https:")


def _link_label(uri: str) -> str:
    """The visible label a URI must correspond to: no scheme, no trailing slash."""
    for scheme in ("mailto:", "https://", "http://"):
        if uri.startswith(scheme):
            uri = uri[len(scheme):]
            break
    return uri.rstrip("/")


def _check_link_annotations(pdf_path: Path, labels: List[str]) -> List[str]:
    """What a click follows, not what the page shows (T162, G-02, F-08).

    Every ``/Link`` must be a ``/URI`` action whose scheme is ``mailto:`` or
    ``https:`` -- never ``GoToR`` (a remote *file* link, measured on 260 of 300
    PDFs), ``Launch``, or a scheme-less URI -- and every expected visible
    contact label must be the target of at least one such link.
    """
    problems: List[str] = []
    anns = _link_annotations(pdf_path)
    for kind, target in anns:
        if kind != "URI":
            problems.append(f"link annotation is a {kind} action, not a URI")
        elif not target.startswith(_ALLOWED_LINK_SCHEMES):
            problems.append(f"link annotation URI has no mailto:/https: scheme: {target!r}")
    reached = {_link_label(t) for k, t in anns if k == "URI" and t.startswith(_ALLOWED_LINK_SCHEMES)}
    for label in (u for u in labels if u):
        if label.rstrip("/") not in reached:
            problems.append(f"no mailto:/https: link annotation targets the visible contact: {label}")
    return problems


def _pdf_structure(pdf_path: Path) -> dict:
    """The document-level structure facts T170 gates (empty dict = none found)."""
    try:
        import pypdf  # type: ignore
        rd = pypdf.PdfReader(str(pdf_path))
        root = rd.trailer["/Root"]
        mark = root.get("/MarkInfo")
        mark = mark.get_object() if mark is not None else {}
        vp = root.get("/ViewerPreferences")
        vp = vp.get_object() if vp is not None else {}
        info = rd.metadata
        return {
            "marked": bool(mark.get("/Marked")),
            "struct": "/StructTreeRoot" in root,
            "xmp": "/Metadata" in root,
            "lang": str(root.get("/Lang") or ""),
            "display_title": bool(vp.get("/DisplayDocTitle")),
            "title": str((info.title if info else "") or ""),
        }
    except Exception as exc:  # noqa: BLE001 -- unparseable means "cannot determine"
        raise RuntimeError(f"cannot read PDF structure: {exc}") from exc


def _check_structure(pdf_path: Path) -> List[str]:
    """Tagged-PDF facts (T170, G-08, G-22, F-26).

    Checks PRESENCE of the structures a tag-following parser or screen reader
    needs.  It does NOT validate PDF/UA conformance; that needs veraPDF, which
    is not installed on the development host.
    """
    f = _pdf_structure(pdf_path)
    problems: List[str] = []
    if not f.get("marked"):
        problems.append("PDF is not tagged: /MarkInfo /Marked is not true")
    if not f.get("struct"):
        problems.append("PDF has no /StructTreeRoot (no tag tree)")
    if not f.get("xmp"):
        problems.append("PDF has no /Metadata XMP packet")
    if not f.get("lang"):
        problems.append("PDF catalog has no /Lang")
    if not f.get("title"):
        problems.append("PDF has an empty document title")
    if not f.get("display_title"):
        problems.append("PDF does not set /ViewerPreferences /DisplayDocTitle")
    return problems


def _check_page_count(pdf_path: Path, kind: str) -> List[str]:
    out = subprocess.run(
        ["pdfinfo", str(pdf_path)], capture_output=True, text=True, timeout=30
    )
    if out.returncode != 0:
        return ["pdfinfo could not read the PDF"]
    pages_line = next((l for l in out.stdout.splitlines() if l.startswith("Pages:")), "")
    if not pages_line:
        return ["pdfinfo returned no page count"]
    pages = int(pages_line.split(":", 1)[1].strip())
    limit = _PAGE_LIMITS.get(kind, 3)
    if pages > limit:
        return [f"document is {pages} pages, over the {limit}-page budget"]
    return []


def _check_fonts_embedded(pdf_path: Path) -> List[str]:
    out = subprocess.run(
        ["pdffonts", str(pdf_path)], capture_output=True, text=True, timeout=30
    )
    if out.returncode != 0:
        return ["pdffonts could not read the PDF"]
    lines = out.stdout.splitlines()
    if len(lines) < 2 or not set(lines[1].strip()) <= {"-", " "}:
        return ["pdffonts output has no dashed header line"]
    # Column offsets come from the dashed header: each run of dashes is one
    # column.  Whitespace splitting is wrong because types are multi-word
    # ("CID TrueType", "Type 3").
    cols = [(m.start(), m.end()) for m in re.finditer(r"-+", lines[1])]
    if len(cols) < 6:
        return ["pdffonts header has unexpected column count"]

    def cell(line: str, i: int) -> str:
        start = cols[i][0]
        end = cols[i + 1][0] if i + 1 < len(cols) else len(line)
        return line[start:end].strip()

    problems: List[str] = []
    for line in lines[2:]:
        if not line.strip():
            continue
        # name is a column of its own; a long name may overflow into the
        # type column's offset, so cut the name at the first run of 2+ spaces.
        name = cell(line, 0)
        type_, emb, sub = cell(line, 1), cell(line, 3), cell(line, 4)
        norm = type_.replace(" ", "").lower()
        if emb.lower() != "yes":
            problems.append(f"font not embedded: {name}")
        if norm == "type3":
            problems.append(f"unembeddable Type3 font: {name}")
        elif sub.lower() != "yes":
            problems.append(f"font not subset: {name}")
    return problems


def validate_document(text: str, kind: str = "cv") -> Tuple[int, str]:
    """Validate extracted text.  ``0`` valid, ``1`` invalid, ``2`` indeterminate."""
    if not text:
        return 2, "no text extracted from the PDF"
    for problems in (_check_extractable(text), _check_no_artifacts(text), _check_single_column(text)):
        if problems:
            return 1, "; ".join(problems)
    return 0, "text layer is extractable and free of parser-poisoning artifacts"


def _infer_lang(pdf_path: Path) -> str | None:
    """Locale from the sibling source's header, else from ``<stem>-<lang>``."""
    for suffix in (".tex", ".html"):
        src = pdf_path.with_suffix(suffix)
        if src.is_file():
            head = src.read_text(encoding="utf-8")[:600]
            m = re.search(r'\blang="?([a-z]{2,3})\b', head) or re.search(r"\blang=([a-z]{2,3})\b", head)
            if m:
                return m.group(1)
    m = re.search(r"-([a-z]{2,3})$", pdf_path.stem)
    return m.group(1) if m else None


def _extract_independent(pdf_path: Path) -> str | None:
    """Text via a SECOND extractor (MuPDF, else pypdf): what a non-poppler ATS sees.

    ``pdftotext`` injects U+202A/B/C around right-to-left runs *itself*, even
    for a flawless PDF (measured on a WeasyPrint Arabic file: PDF has none,
    pdftotext emits them), so a bidi-control check against pdftotext alone
    accuses the artifact of the tool's own output.  This extractor reads the
    ToUnicode mapping directly; it is the authority for control codepoints.
    """
    import shutil
    if shutil.which("mutool"):
        r = subprocess.run(["mutool", "draw", "-q", "-F", "txt", str(pdf_path)],
                           capture_output=True, text=True, timeout=120)
        if r.returncode == 0 and r.stdout.strip():
            return r.stdout
    try:
        import pypdf  # type: ignore
        return "\n".join((p.extract_text() or "") for p in pypdf.PdfReader(str(pdf_path)).pages)
    except Exception:  # noqa: BLE001 -- any failure means "cannot determine"
        return None


def validate_pdf(pdf_path: Path, kind: str = "cv", lang: str | None = None,
                 phrases: List[str] | None = None,
                 contacts: List[str] | None = None) -> Tuple[int, str]:
    """Validate a PDF artifact end to end.

    ``lang`` defaults to the locale recorded in the sibling source.  ``phrases``
    are known source strings (name, section headings, a headline run) that must
    each survive extraction as one contiguous string in logical order.
    ``contacts`` are the resolved document's contact labels; when given they are
    the authority (a renderer that drops one is caught), otherwise the sibling
    source's links are used.  An empty list is a failure, never a vacuous pass.
    """
    pdf_path = Path(pdf_path)
    if not pdf_path.is_file():
        return 2, f"PDF not found: {pdf_path}"
    lang = lang or _infer_lang(pdf_path)
    problems: List[str] = []
    text = _extract(pdf_path)
    if text is None:
        return 2, "could not extract text from the PDF"
    raw = _extract_independent(pdf_path)
    if raw is None:
        return 2, "no independent text extractor (mutool/pypdf): cannot determine the text layer"
    # Control codepoints and tofu are judged on the independent extraction;
    # pdftotext's own RLE/LRE/PDF wrappers are dropped before the other checks.
    problems.extend(_check_extractable(raw))
    clean = _strip_bidi_controls(text)
    if "\ufffd" in clean:
        problems.append("text layer contains forbidden codepoints: U+FFFD")
    if not clean.strip():
        problems.append("text layer is empty or missing")
    problems.extend(_check_no_artifacts(clean, lang))
    problems.extend(_check_no_artifacts(raw, lang))
    problems.extend(_check_script_coverage(clean, lang))
    problems.extend(_check_phrases([clean, raw], list(phrases or [])))
    problems.extend(_check_single_column_pdf(pdf_path))
    urls = _expected_contacts(pdf_path, contacts)
    problems.extend(_check_contact_urls(clean, urls) if all(u in clean for u in urls)
                    else _check_contact_urls(_norm(clean) + "\n" + raw, urls))
    try:
        problems.extend(_check_link_annotations(pdf_path, urls))
    except RuntimeError as exc:
        return 2, str(exc)
    try:
        problems.extend(_check_structure(pdf_path))
    except RuntimeError as exc:
        return 2, str(exc)
    # Extraction-side ATS gates (JSK-T163 placeholder leakage, T174 heading recognition, T178 running header).
    problems.extend(extract_gates.check_placeholder_leak(clean, lang))
    if kind == "cv":
        problems.extend(extract_gates.check_headings(clean, lang))
    # JSK-T168 / G-06 / F-25: every independent extractor must see the same word boundaries.
    wb = extract_gates.check_word_boundaries(pdf_path, lang)
    if wb is None:
        return 2, "cannot determine word boundaries: fewer than two independent extractors available"
    problems.extend(wb)
    layout = extract_gates.pages_of(pdf_path)
    if layout is not None:
        problems.extend(extract_gates.check_running_headers(layout))
        # JSK-T178 / G-19: no word cut by automatic hyphenation; source-hyphen breaks are budgeted.
        src = extract_gates.sibling_source_text(pdf_path)
        if src is None and extract_gates.hyphen_breaks(layout, None)["auto"]:
            return 2, "cannot classify line-end hyphens: the sibling .tex source is missing"
        problems.extend(extract_gates.check_hyphenation(layout, src))
    # JSK-T179 / G-20: the rendered page and the text layer must say the same thing (needs the locale's OCR pack).
    if extract_gates.ocr_applicable(lang):
        ocr = extract_gates.check_ocr_consistency(pdf_path, lang)
        if ocr is None:
            return 2, f"cannot determine OCR consistency for '{lang}': tesseract, pdftoppm or its language pack is missing"
        problems.extend(ocr)
    problems.extend(_check_page_count(pdf_path, kind))
    problems.extend(_check_fonts_embedded(pdf_path))
    problems = list(dict.fromkeys(problems))
    if problems:
        return 1, "; ".join(problems)
    return 0, f"PDF is extractable, single-column, embedded, within budget ({kind})"


def _extract(pdf_path: Path) -> str | None:
    result = subprocess.run(
        ["pdftotext", "-layout", str(pdf_path), "-"],
        capture_output=True, text=True, timeout=30,
    )
    if result.returncode != 0:
        return None
    return result.stdout


def _main(argv: List[str] | None = None) -> None:
    import argparse
    import sys
    ap = argparse.ArgumentParser(prog="gates")
    ap.add_argument("pdf")
    ap.add_argument("--kind", choices=sorted(_PAGE_LIMITS), default="cv")
    ap.add_argument("--lang", default=None)
    ap.add_argument("--phrase", action="append", default=[])
    try:
        ns = ap.parse_args(argv if argv is not None else sys.argv[1:])
    except SystemExit as e:  # argparse exits 2 on usage errors == indeterminate
        raise SystemExit(2 if e.code else 0)
    rc, msg = validate_pdf(Path(ns.pdf), ns.kind, ns.lang, ns.phrase)
    print(f"rc={rc} {msg}")
    sys.exit(rc)


if __name__ == "__main__":
    _main()
