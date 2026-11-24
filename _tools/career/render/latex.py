"""LuaLaTeX renderer -> ``.tex`` source and byte-reproducible ``.pdf``.

Why LuaLaTeX and not XeLaTeX
----------------------------
Measured on this host: LuaHBTeX 1.22.0 extracts Devanagari correctly in **6 of
6** ``pdftotext`` mode/font combinations, where XeLaTeX scores 1 of 6 and
corrupts logical order (``वर्षों`` -> ``वर्षंो``, dropped matras, spurious
intra-word spaces).  LuaLaTeX is the LTR engine of record.

Reproducibility
---------------
Two runs of the same source differ in the PDF ``/ID`` array unless suppressed.
``\\pdfvariable suppressoptionalinfo 512`` removes it; measured 512/768/1023
work and 0/32/64/96/256 do not.  The caller must also pin ``SOURCE_DATE_EPOCH``
and set ``FORCE_SOURCE_DATE=1`` so the date fields agree.

Escaping
--------
LaTeX specials are escaped before any structural command is emitted, so a
bullet that mentions ``C++ & Rust`` or a metric that says ``70%`` cannot break
the build.  ``\\hspace{0pt}`` is then injected *between* CJK codepoints to give
LuaTeX the break opportunities it has no native algorithm for (measured: bare
CJK overflows with 51 of 132 characters rendered on one line; with the
insertions the same text wraps to 3 lines, 132/132 characters).

What this module deliberately does NOT do
-----------------------------------------
* No ligatures (``Ligatures=NoCommon`` in the class).  A PDF whose text layer
  holds U+FB00 instead of "ff" fails keyword matching in real parsers.
* No icon fonts.  A fontawesome glyph extracts as a private-use codepoint, so
  the phone number silently loses its label.
* No letter-spaced headings.  1.5--2 pt of tracking makes ``pdftotext`` emit
  ``E X P E R I E N C E``, and headings are exactly what parsers segment on.
* No ``\\hfill`` before the date.  Any gap wider than a few millimetres makes
  ``pdftotext`` emit the date as a separate block, reordering role/date/employer
  so a line-by-line parser attaches the dates to the wrong record.
"""

from __future__ import annotations

import hashlib
import os
import re
import shutil
import subprocess
import tempfile
from pathlib import Path
from typing import Any

from .fonts import FontMissing, require_fonts

# --------------------------------------------------------------------------- #
# Text handling
# --------------------------------------------------------------------------- #

_ESCAPE_MAP = {
    "\\": r"\textbackslash{}",
    "{": r"\{",
    "}": r"\}",
    "$": r"\$",
    "&": r"\&",
    "#": r"\#",
    "_": r"\_",
    "%": r"\%",
    "~": r"\textasciitilde{}",
    "^": r"\textasciicircum{}",
}
_ESCAPE_RE = re.compile("[" + re.escape("".join(_ESCAPE_MAP)) + "]")

#: Ranges that need an explicit break opportunity in an unshaped paragraph.
_CJK_RANGES = (
    (0x1100, 0x115F), (0x2E80, 0x303E), (0x3041, 0x33FF),
    (0x3400, 0x4DBF), (0x4E00, 0x9FFF), (0xA000, 0xA4CF),
    (0xAC00, 0xD7A3), (0xF900, 0xFAFF), (0xFE30, 0xFE4F),
    (0xFF00, 0xFF60), (0xFFE0, 0xFFE6),
)

#: Tick characters that are break opportunities in Japanese/Korean but must
#: never start a line.  U+3001/U+3002/U+FF0C are followed by a break too.
_CJK_NO_BREAK_BEFORE = set("、。，．・：；！？（）「」『』【】")

_BREAK = r"\hspace{0pt}"


def _is_cjk(ch: str) -> bool:
    o = ord(ch)
    return any(lo <= o <= hi for lo, hi in _CJK_RANGES)


def escape(text: str) -> str:
    """Escape LaTeX specials.  Unicode is passed through untouched."""
    # Single pass: sequential replace would re-escape the braces that the
    # backslash replacement itself introduces (``\\{}`` -> ``\\\{\\}``).
    return _ESCAPE_RE.sub(lambda m: _ESCAPE_MAP[m.group(0)], str(text))


def cjk_break(text: str) -> str:
    """Insert ``\\hspace{0pt}`` between adjacent CJK codepoints.

    Only *between* two CJK characters is it inserted: a break before a full
    stop or after an opening bracket would produce a visible orphan, and a
    break between CJK and Latin would split a mixed token such as ``Kotlin``.
    """
    if not any(_is_cjk(c) for c in text):
        return text
    out: list[str] = []
    for i, ch in enumerate(text):
        out.append(ch)
        nxt = text[i + 1] if i + 1 < len(text) else ""
        if not nxt:
            continue
        if _is_cjk(ch) and _is_cjk(nxt) and nxt not in _CJK_NO_BREAK_BEFORE:
            out.append(_BREAK)
    return "".join(out)


def tex_text(text: str) -> str:
    """Escape then add CJK break opportunities.  The only safe entry point."""
    if text is None:
        return ""
    return cjk_break(escape(str(text)))


def _join(parts: list[str], sep: str = r"\ \textperiodcentered\ ") -> str:
    return sep.join(p for p in parts if p)


def _url(text: str, href: str | None = None) -> str:
    """A visible link: ``text`` is shown, ``href`` is what a click follows.

    ``href`` MUST carry a scheme (``mailto:``/``https:``).  Measured on 260 of
    300 PDFs: ``\\href{github.com/x}{...}`` makes hyperref write a ``GoToR``
    remote-file action to ``github.com/x.pdf``, and ``\\href{a@b.c}{...}`` a
    scheme-less URI.  ``href=None`` keeps the old label-as-target behaviour for
    callers that already pass a full URI as the label.

    Measured: a mismatched ``\\href{mailto:...}{short}`` label is what makes an
    extracted contact line unreadable to a parser.  The full address is shown.
    """
    safe = escape(text)  # already carries \% and \# -- do not escape twice
    target = escape(href) if href is not None else safe
    # \mbox: an hbox has no break points at all, so no engine/script/fallback
    # font combination (measured: Devanagari builds) can split the URL.
    return r"\mbox{\href{" + target + "}{" + safe + "}}"


# --------------------------------------------------------------------------- #
# Document assembly
# --------------------------------------------------------------------------- #

_SCRIPT_BY_LANG = {"zh": "cjk", "ja": "cjk", "ko": "cjk", "hi": "deva"}
_ACCENT_DEFAULT = "1F6FEB"


def _script(lang: str) -> str:
    return _SCRIPT_BY_LANG.get(lang, "latin")


def _accent(doc: dict[str, Any]) -> str:
    raw = str(doc.get("area", {}).get("accent") or f"#{_ACCENT_DEFAULT}")
    hexpart = raw.lstrip("#").upper()
    if not re.fullmatch(r"[0-9A-F]{6}", hexpart):
        raise ValueError(f"area accent {raw!r} is not a 6-digit hex colour")
    return hexpart


def _preamble(doc: dict[str, Any], *, cover: bool) -> str:
    ident = doc["identity"]
    meta = doc.get("meta", {})
    lines = [
        "% Generated by _tools/career/render/latex.py -- do not edit.",
        # T170: tagged PDF (/MarkInfo, /StructTreeRoot), XMP packet and /Lang.
        # Must precede \documentclass.  Deliberately NO ``pdfstandard=ua-*``:
        # no PDF/UA validator is installed on the host, so the file must not
        # declare a conformance nobody has measured.
        rf"\DocumentMetadata{{lang={doc['lang']},pdfversion=1.7,tagging=on}}",
        f"% model_hash={meta.get('model_hash', '')} lang={doc['lang']} area={doc['area']['id']}",
        rf"\def\milosscript{{{_script(doc['lang'])}}}",
        rf"\def\milosaccent{{{_accent(doc)}}}",
        rf"\def\miloslang{{{doc['lang']}}}",
        r"\documentclass" + ("[cover]" if cover else "") + "{miloscv}",
        # The footer label is the human title: it repeats the three facts a
        # reader (and a parser) needs to identify the sheet after printing.
        rf"\milosdoclabel{{{tex_text(doc['ats']['title'])}}}",
        rf"\milosdoctitle{{{tex_text(doc['ats']['title'])}}}",
        rf"\milosdocsubject{{{tex_text(doc['area']['title'] + ': ' + doc['area']['tagline'])}}}",
        rf"\milosdockeywords{{{tex_text(', '.join(doc['ats']['keywords']))}}}",
        rf"\milosdocauthor{{{tex_text(ident['name'])}}}",
        rf"\milospdflang{{{doc['lang']}}}",
        r"\begin{document}",
    ]
    return "\n".join(lines)


def _header(doc: dict[str, Any]) -> str:
    ident = doc["identity"]
    lab = doc["labels"]
    out = [r"{\Huge\bfseries " + tex_text(ident["name"]) + r"}\par", r"\vspace{1.4pt}"]
    out.append(r"{\small\color{milosmuted}" + tex_text(ident["headline"]) + r"}\par")
    contact = ident["contact"]
    pieces = [tex_text(ident["location"])]
    for c in contact:
        pieces.append(_url(c["label"], c["href"]))
    out.append(r"\vspace{1.2pt}")
    out.append(r"{\footnotesize\color{milosmuted}\milosnohyphens " + _join(pieces) + r"\par}")
    if doc.get("metrics"):
        band = _join(
            [r"\textbf{" + tex_text(m["value"]) + r"}\ " + tex_text(m["label"])
             for m in doc["metrics"]],
            r"\ \textbar\ ",
        )
        out.append(r"\vspace{3.2pt}")
        out.append(r"{\footnotesize\color{milosaccent}" + band + r"}\par")
    return "\n".join(out)


def _section(title: str) -> str:
    return r"\milossection{" + tex_text(title) + "}"


def _bullets(items: list[str]) -> str:
    if not items:
        return ""
    body = "\n".join(r"  \item " + tex_text(i) for i in items)
    return "\\begin{milosbullets}\n" + body + "\n\\end{milosbullets}"


def render_cv(doc: dict[str, Any]) -> str:
    lab = doc["labels"]
    out = [_preamble(doc, cover=False), _header(doc)]

    if doc.get("summary"):
        out.append(_section(lab["label.summary"]))
        out.append("\n\n".join(tex_text(p) for p in doc["summary"]))

    if doc.get("competencies"):
        out.append(_section(lab["label.competencies"]))
        for comp in doc["competencies"]:
            out.append(r"\miloskv{" + tex_text(comp["label"]) + "}{}")
            out.append(_bullets(comp["items"]))

    if doc.get("experience"):
        out.append(_section(lab["label.experience"]))
        for job in doc["experience"]:
            out.append(
                r"\milosentry{"
                + tex_text(job["role"])
                + "}{"
                + tex_text(job["company"])
                + "}{"
                + tex_text(job.get("location", ""))
                + "}{"
                + tex_text(job.get("period", ""))
                + "}"
            )
            if job.get("summary"):
                out.append(tex_text(job["summary"]))
            out.append(_bullets(job.get("bullets", [])))
            if job.get("tech"):
                out.append(r"\milostags{" + tex_text(", ".join(job["tech"])) + "}")

    if doc.get("projects"):
        out.append(_section(lab["label.projects"]))
        for proj in doc["projects"]:
            out.append(
                r"\milosproject{"
                + tex_text(proj["name"])
                + "}{"
                + tex_text(proj.get("blurb_lead") or proj.get("blurb", ""))
                + "}{"
                + tex_text(", ".join(proj.get("tech", [])))
                + "}"
            )

    if doc.get("skills"):
        out.append(_section(lab["label.skills"]))
        for group in doc["skills"]:
            out.append(r"\miloskv{" + tex_text(group["label"]) + "}{"
                       + tex_text(", ".join(group["items"])) + "}")

    if doc.get("education"):
        out.append(_section(lab["label.education"]))
        for ed in doc["education"]:
            out.append(
                r"\milosentry{"
                + tex_text(ed["degree"])
                + "}{"
                + tex_text(ed["institution"])
                + "}{"
                + tex_text(ed.get("location", ""))
                + "}{"
                + tex_text(ed.get("year", ""))
                + "}"
            )

    if doc.get("publications"):
        out.append(_section(lab["label.publications"]))
        for pub in doc["publications"]:
            out.append(r"\milosproject{" + tex_text(pub["title"]) + "}{"
                       + tex_text(pub.get("detail", "")) + "}{}")

    if doc.get("languages"):
        out.append(_section(lab["label.languages"]))
        out.append(
            _join(
                [r"\textbf{" + tex_text(l["name"]) + r"}\ " + tex_text(l["level"])
                 for l in doc["languages"]],
                r"\quad ",
            )
        )

    # A "Keywords" line at the foot of the CV.  It is not keyword stuffing:
    # it lists the terms the area is hired for, and each is also present in
    # the body wherever it applies.  The ATS screen gates that every keyword
    # in ``ats.keywords`` appears in the extracted text; the line is what
    # makes "prompt engineering", "model evaluation", "CI/CD" and friends
    # appear where a recruiter's parser will see them.
    if doc.get("ats", {}).get("keywords"):
        out.append(_section(lab["label.keywords"]))
        out.append(tex_text(", ".join(doc["ats"]["keywords"])))

    out.append(r"\end{document}")
    return "\n\n".join(o for o in out if o) + "\n"


def _cover_body(doc: dict[str, Any]) -> str:
    lab = doc["labels"]
    ident = doc["identity"]
    cover = doc["cover"]
    out = [_preamble(doc, cover=True)]
    out.append(
        r"\milosletterhead{" + tex_text(ident["name"]) + "}{"
        + _join([tex_text(ident["location"])] + [_url(c["label"], c["href"]) for c in ident["contact"]])
        + "}"
    )
    out.append(r"\vspace{2pt}{\footnotesize\color{milosmuted}"
               + tex_text(lab["label.cover.date"]) + r": " + tex_text(doc["meta"]["date"])
               + r"}\par")
    out.append(r"\milossubject{" + tex_text(cover["subject"]) + "}")
    out.append(r"\milossalutation{" + tex_text(cover["salutation"]) + "}")
    if cover.get("opening"):
        out.append(tex_text(cover["opening"]))
    for para in cover.get("paragraphs", []):
        body = tex_text(para["body"])
        if para.get("title"):
            body = r"\textbf{" + tex_text(para["title"]) + r"}\ " + body
        out.append(body)
    if cover.get("closing"):
        out.append(tex_text(cover["closing"]))
    out.append(r"\milosclosing{" + tex_text(cover.get("regards") or lab["label.cover.regards"])
               + r"}\par\vspace{2pt}")
    out.append(r"{\bfseries " + tex_text(ident["name"]) + r"}\par")
    out.append(r"\end{document}")
    return "\n\n".join(o for o in out if o) + "\n"


def render_document(doc: dict[str, Any]) -> str:
    """Render a DocumentModel to complete ``.tex`` source."""
    kind = doc["kind"]
    if kind == "cv":
        return render_cv(doc)
    if kind == "cover":
        return _cover_body(doc)
    raise ValueError(f"unknown document kind {kind!r}")


# --------------------------------------------------------------------------- #
# Compilation
# --------------------------------------------------------------------------- #

_CLASS_CACHE: dict[str, str] = {}


def class_source() -> str:
    """The ``miloscv.cls`` source, read from disk (single source of truth)."""
    if "src" not in _CLASS_CACHE:
        path = Path(__file__).resolve().parent.parent / "latex" / "miloscv.cls"
        _CLASS_CACHE["src"] = path.read_text(encoding="utf-8")
    return _CLASS_CACHE["src"]


_MISSING_RE = re.compile(r"Missing character: There is no .*? \(U\+([0-9A-Fa-f]{4,6})\)")


def missing_characters(log: str) -> set[int]:
    """Code points LuaTeX reported as absent from the selected font."""
    return {int(m.group(1), 16) for m in _MISSING_RE.finditer(log)}


def compile_pdf(tex_source: str, out_pdf: Path, *, workdir: Path, epoch: int,
                lang: str = "en") -> Path:
    """Compile ``tex_source`` and return the produced PDF path.

    The build directory is private (``tempfile.mkdtemp``) so a failed run can
    never leave a half-written artifact next to the manifests.
    """
    lualatex = shutil.which("lualatex")
    if lualatex is None:
        raise FontMissing("lualatex not found on PATH: cannot determine")
    require_fonts(lang)

    out_pdf = Path(out_pdf)
    out_pdf.parent.mkdir(parents=True, exist_ok=True)

    tmp = Path(tempfile.mkdtemp(prefix="miloscv-", dir=str(workdir)))
    try:
        (tmp / "miloscv.cls").write_text(class_source(), encoding="utf-8")
        (tmp / "doc.tex").write_text(tex_source, encoding="utf-8")
        env = dict(os.environ)
        env["SOURCE_DATE_EPOCH"] = str(int(epoch))
        env["FORCE_SOURCE_DATE"] = "1"
        env["TEXMFVAR"] = str(tmp / "texmfvar")
        env["openout_any"] = "p"
        cmd = [
            lualatex,
            "-interaction=nonstopmode",
            "-halt-on-error",
            "-output-directory=" + str(tmp),
            "doc.tex",
        ]
        # Two passes: page totals and LastPage need the first pass' .aux.
        for _ in range(2):
            proc = subprocess.run(
                cmd, cwd=str(tmp), env=env, capture_output=True, text=True, timeout=300
            )
            if proc.returncode != 0:
                tail = (proc.stdout or "")[-4000:]
                raise RuntimeError(f"lualatex failed (rc {proc.returncode}):\n{tail}")
        produced = tmp / "doc.pdf"
        if not produced.is_file():
            raise RuntimeError("lualatex reported success but produced no PDF")
        # \"Missing character\" is TeX's .notdef: the glyph is dropped or boxed
        # and the text layer loses it, while the run still exits 0.
        missing = missing_characters((tmp / "doc.log").read_text(encoding="utf-8", errors="replace"))
        if missing:
            raise RuntimeError("missing glyphs (.notdef): "
                               + ", ".join(f"U+{c:04X}" for c in sorted(missing)[:12]))
        stage = out_pdf.with_name(f".{out_pdf.name}.{os.getpid()}.tmp")
        try:
            shutil.copyfile(produced, stage)
            os.replace(stage, out_pdf)  # atomic: no reader sees a half-written PDF
        finally:
            stage.unlink(missing_ok=True)
        return out_pdf
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def build(doc: dict[str, Any], outdir: Path, stem: str, *, epoch: int,
          workdir: Path | None = None) -> dict[str, Path]:
    """Write ``<stem>.tex`` and ``<stem>.pdf`` into ``outdir``."""
    outdir = Path(outdir)
    outdir.mkdir(parents=True, exist_ok=True)
    work = Path(workdir) if workdir else outdir / ".work"
    work.mkdir(parents=True, exist_ok=True)
    src = render_document(doc)
    tex_path = outdir / f"{stem}.tex"
    # Invalidate first: if this render fails (FontMissing, TeX error) nothing
    # from the previous build may remain to be mistaken for a fresh artifact.
    (outdir / f"{stem}.pdf").unlink(missing_ok=True)
    tex_path.unlink(missing_ok=True)
    stage = tex_path.with_name(f".{tex_path.name}.{os.getpid()}.tmp")
    stage.write_text(src, encoding="utf-8")
    os.replace(stage, tex_path)
    pdf_path = compile_pdf(src, outdir / f"{stem}.pdf", workdir=work, epoch=epoch, lang=doc["lang"])
    return {"tex": tex_path, "pdf": pdf_path}


def source_hash(tex_source: str) -> str:
    return hashlib.sha256(tex_source.encode("utf-8")).hexdigest()


__all__ = [
    "escape",
    "cjk_break",
    "tex_text",
    "render_cv",
    "render_document",
    "compile_pdf",
    "missing_characters",
    "build",
    "class_source",
    "source_hash",
]
