"""Test support: build a SMALL real sample of the career matrix into a scratch directory.

Nothing here is a fixture: every PDF is rendered by the real renderer from the real
profile and judged by the real gates (``career._build_one``), and the manifest is
written by the real writer (``buildlib.write_manifest``).  The private overlay is a
throw-away directory holding a minimal valid ``overlay.yaml`` with no personal data.
"""
from __future__ import annotations

import os
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from career import buildlib, overlay as overlay_mod  # noqa: E402
from career import render as render_pkg  # noqa: E402

#: 3 locales x cv/cover on one area: LuaLaTeX Latin, LuaLaTeX Cyrillic and the WeasyPrint RTL engine.
SAMPLE_AREA = "ai-engineering"
SAMPLE_LANGS = ("en", "ru", "ar")
OVERLAY_TEXT = 'schema: career.overlay.v1\nblocked_companies:\n  - "Zqx Blocked Company"\n'
EPOCH = 1_795_000_000   # 2026-11-18; any pinned epoch (builds never read the wall clock)


def have_toolchain() -> bool:
    import shutil
    return bool(shutil.which("lualatex") and shutil.which("pdftotext"))


def build_sample(outdir: Path, private_dir: Path, *, epoch: int = EPOCH, area: str = SAMPLE_AREA,
                 langs=SAMPLE_LANGS, write: bool = True) -> dict:
    """Render + gate the sample, and (``write``) emit ``manifest.json`` with the real writer.

    Returns ``{"results": [...], "names": [...], "overlay_sha": str}``.  Raises when the
    environment cannot build (callers skip: an undetermined build is never a pass).
    """
    from career import career as cli
    (private_dir / "overlay.yaml").write_text(OVERLAY_TEXT, encoding="utf-8")
    old = os.environ.get(overlay_mod.ENV)
    os.environ[overlay_mod.ENV] = str(private_dir)
    try:
        triples = buildlib.matrix([area], list(langs))
        results = [cli._build_one((a, k, l, epoch, str(outdir))) for a, k, l in triples]
        names = buildlib.expected_files(triples, render_pkg.source_suffix)
        sha = overlay_mod.overlay_sha()
        if write:
            buildlib.write_manifest(outdir, names, epoch, overlay_sha=sha,
                                    gate_rc={r["stem"]: r["rc"] for r in results})
        return {"results": results, "names": names, "overlay_sha": sha}
    finally:
        if old is None:
            os.environ.pop(overlay_mod.ENV, None)
        else:
            os.environ[overlay_mod.ENV] = old


def scratch_pair() -> tuple[tempfile.TemporaryDirectory, Path, Path]:
    td = tempfile.TemporaryDirectory(prefix="career-sample-")
    out, priv = Path(td.name) / "out", Path(td.name) / "private"
    out.mkdir(); priv.mkdir(mode=0o700)
    return td, out, priv


def scramble_text_layer(src: Path, dst: Path) -> Path:
    """A REAL glyph/text-layer mismatch artifact: same page content (the glyphs a reader sees), but every font's
    ToUnicode maps the letters a-z / A-Z one letter on, so the extracted text no longer says what the page shows."""
    import re
    import pypdf
    from pypdf.generic import DecodedStreamObject, NameObject
    w = pypdf.PdfWriter(clone_from=str(src))

    seen = set()
    for page in w.pages:
        for font in (page["/Resources"].get("/Font") or {}).values():
            fo = font.get_object()
            tu = fo.get("/ToUnicode")
            if tu is None or id(tu.get_object()) in seen:
                continue
            seen.add(id(tu.get_object()))
            data = tu.get_object().get_data().decode("latin1")
            head, _, tail = data.partition("beginbfchar")
            body, sep, rest = tail.partition("endbfchar")
            body = re.sub(r"(<[0-9A-Fa-f]{4}>\s*)<([0-9A-Fa-f]{4})>", lambda m: f"{m.group(1)}<{_rot(int(m.group(2), 16)):04X}>", body)
            new = DecodedStreamObject()
            new.set_data((head + "beginbfchar" + body + sep + rest).encode("latin1"))
            fo[NameObject("/ToUnicode")] = w._add_object(new)
    w.write(str(dst))
    return dst


def _rot(cp: int) -> int:
    if 0x61 <= cp <= 0x7A:
        return 0x61 + (cp - 0x61 + 1) % 26
    if 0x41 <= cp <= 0x5A:
        return 0x41 + (cp - 0x41 + 1) % 26
    return cp


def visual_order_pdf(html_src: Path, dst: Path, lang: str) -> Path:
    """A REAL visually-mirrored RTL artifact (JSK-T169 RED), rendered by the real WeasyPrint engine from the real
    document HTML: the paragraph is forced ``ltr`` and every word is an isolated span in LOGICAL order, so the words
    sit left to right in the order a reader should meet them right to left.  Both supported readers (MuPDF and
    ``pdftotext -layout``) then return the words of each line last-first: the visual order is wrong, which is the
    defect a renderer that lays RTL runs out left to right produces."""
    import html as _h
    import re
    from career.render import html as html_engine
    from career.extract_gates import _is_rtl_word

    src = Path(html_src).read_text(encoding="utf-8")
    head, sep, body = src.partition("</head>")

    def node(m: "re.Match[str]") -> str:
        toks = _h.unescape(m.group(1)).split()
        if sum(1 for t in toks if _is_rtl_word(t)) < 2:
            return m.group(0)
        spans = [f'<span dir="{"rtl" if _is_rtl_word(t) else "ltr"}" style="unicode-bidi:isolate">{_h.escape(t)}</span>'
                 for t in toks]
        return ">" + " ".join(spans) + "<"

    body = re.sub(r">([^<>]+)<", node, body)
    out = (head + '<style>html,body{direction:ltr;text-align:right}</style>' + sep + body).replace('dir="rtl"', 'dir="ltr"', 1)
    return html_engine.compile_pdf(out, Path(dst), lang=lang)
