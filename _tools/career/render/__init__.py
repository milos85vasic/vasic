"""Renderers: one DocumentModel in, byte-reproducible artifacts out.

Every module in this package takes a ``career.document.v1`` dict and returns
either a string or a path.  None of them may import ``model``/``resolve`` and
none of them may read ``profile.yaml``.

What is actually produced (and nothing else is claimed)
-------------------------------------------------------
* ``latex`` engine -> ``<stem>.tex`` + ``<stem>.pdf``   (LuaLaTeX)
* ``html``  engine -> ``<stem>.html`` + ``<stem>.pdf``  (WeasyPrint; RTL only)

The earlier ``FORMATS = (tex, pdf, html, md, docx, json)`` declared four formats
no code path produced; it is replaced by the table below.
"""

from __future__ import annotations

from pathlib import Path
from typing import Any

#: engine -> artifact suffixes it writes, source first, PDF last.
ENGINE_FORMATS = {"latex": ("tex", "pdf"), "html": ("html", "pdf")}

#: Every format some engine produces, in write order.
FORMATS = ("tex", "html", "pdf")

#: Locales rendered by WeasyPrint.  Arabic and Persian need bidi shaping that
#: LuaLaTeX cannot deliver here: ``bidi.sty``/``luabidi.sty`` are absent, and
#: LuaTeX's own RTL output extracts as presentation forms (U+FExx) in visual
#: order.  CJK is NOT here: it renders correctly in LuaLaTeX once the class
#: selects the right font (see ``latex/miloscv.cls``).
HTML_LOCALES = frozenset({"ar", "fa"})


def engine_for(lang: str) -> str:
    """The PDF engine that renders ``lang`` (``"html"`` for RTL, else ``"latex"``)."""
    return "html" if lang in HTML_LOCALES else "latex"


def source_suffix(lang: str) -> str:
    return ENGINE_FORMATS[engine_for(lang)][0]


def build(doc: dict[str, Any], outdir: Path, stem: str, *, epoch: int,
          workdir: Path | None = None) -> dict[str, Path]:
    """Render ``doc`` with the engine registered for its locale."""
    if engine_for(doc["lang"]) == "html":
        from . import html
        return html.build(doc, outdir, stem, epoch=epoch, workdir=workdir)
    from . import latex
    return latex.build(doc, outdir, stem, epoch=epoch, workdir=workdir)


__all__ = ["ENGINE_FORMATS", "FORMATS", "HTML_LOCALES", "engine_for", "source_suffix", "build"]
