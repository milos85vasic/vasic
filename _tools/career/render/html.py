"""HTML -> PDF renderer (WeasyPrint/Pango) for the right-to-left locales.

Why this engine exists
----------------------
Measured on this host (2026-11-23), LuaLaTeX output for Arabic extracts as
Arabic *presentation forms* (U+FExx) with the glyph order of the visual line,
because LuaTeX writes the shaped glyphs' own code points into ToUnicode.  An
ATS that does not NFKC-normalise then cannot match a single Arabic keyword.
WeasyPrint (Pango/HarfBuzz) maps shaped glyphs back to the *base* code points,
and the extracted text is in logical order.  ``bidi.sty``/``luabidi.sty`` are
absent on this host, so there is no LaTeX route to fix it either.

The renderer takes the same ``career.document.v1`` dict as ``latex.py`` and
must stay a pure function of it: no profile access, no locale lookup.
"""

from __future__ import annotations

import datetime as _dt
import html as _html
import os
from pathlib import Path
from typing import Any

from .fonts import FontMissing, missing_families, require_fonts  # noqa: E402


_CSS = """
@page { size: A4; margin: 12mm 24mm 14mm 24mm;
  @bottom-center { content: counter(page) " / " counter(pages);
    font-size: 8pt; color: #4A5361; } }
html { font-family: %(fonts)s; font-size: 10.5pt; line-height: 1.32; color: #111418; }
body { margin: 0; }
h1 { font-size: 22pt; margin: 0 0 2pt 0; line-height: 1.15; }
h2 { font-size: 12.5pt; color: #%(accent)s; border-top: 1pt solid #%(accent)s;
  margin: 9pt 0 3pt 0; padding-top: 3pt; break-after: avoid; }
p { margin: 1.5pt 0; }
.muted { color: #4A5361; }
.small { font-size: 9pt; }
.contact { font-size: 9pt; color: #4A5361; }
.u { direction: ltr; unicode-bidi: isolate; white-space: nowrap; }
.metrics { font-size: 9pt; color: #%(accent)s; }
ul { margin: 1pt 0 2pt 0; padding-inline-start: 4.5mm; }
li { margin: 0.5pt 0; }
.entry { margin-top: 4pt; break-after: avoid; }
a { color: inherit; text-decoration: none; }
"""


def _fonts(lang: str) -> str:
    return '"Noto Naskh Arabic", "Noto Sans", "DejaVu Sans", sans-serif'


def _e(text: Any) -> str:
    return _html.escape("" if text is None else str(text), quote=True)


def _link(label: str, href: str) -> str:
    return f'<span class="u"><a href="{_e(href)}">{_e(label)}</a></span>'


def _join(parts: list[str], sep: str = " &#183; ") -> str:
    return sep.join(p for p in parts if p)


def _bullets(items: list[str]) -> str:
    if not items:
        return ""
    return "<ul>" + "".join(f"<li>{_e(i)}</li>" for i in items) + "</ul>"


def _entry(a: str, b: str = "", c: str = "", d: str = "") -> str:
    tail = _join([_e(b), _e(c), _e(d)])
    return f'<p class="entry"><strong>{_e(a)}</strong>' + (f' <span class="muted">&#183; {tail}</span>' if tail else "") + "</p>"


def _head(doc: dict[str, Any]) -> str:
    ident = doc["identity"]
    contact = [_e(ident["location"])] + [_link(c["label"], c["href"]) for c in ident["contact"]]
    out = [f"<h1>{_e(ident['name'])}</h1>",
           f'<p class="muted small">{_e(ident["headline"])}</p>',
           f'<p class="contact">{_join(contact)}</p>']
    if doc.get("metrics"):
        out.append('<p class="metrics">' + _join(
            [f"<strong>{_e(m['value'])}</strong> {_e(m['label'])}" for m in doc["metrics"]], " | ") + "</p>")
    return "\n".join(out)


def _cv_body(doc: dict[str, Any]) -> str:
    lab = doc["labels"]
    o = [_head(doc)]
    if doc.get("summary"):
        o.append(f"<h2>{_e(lab['label.summary'])}</h2>")
        o += [f"<p>{_e(p)}</p>" for p in doc["summary"]]
    if doc.get("competencies"):
        o.append(f"<h2>{_e(lab['label.competencies'])}</h2>")
        for c in doc["competencies"]:
            o.append(f"<p><strong>{_e(c['label'])}</strong></p>" + _bullets(c["items"]))
    if doc.get("experience"):
        o.append(f"<h2>{_e(lab['label.experience'])}</h2>")
        for j in doc["experience"]:
            o.append(_entry(j["role"], j["company"], j.get("location", ""), j.get("period", "")))
            if j.get("summary"):
                o.append(f"<p>{_e(j['summary'])}</p>")
            o.append(_bullets(j.get("bullets", [])))
            if j.get("tech"):
                o.append(f'<p class="muted small">{_e(", ".join(j["tech"]))}</p>')
    if doc.get("projects"):
        o.append(f"<h2>{_e(lab['label.projects'])}</h2>")
        for p in doc["projects"]:
            o.append(_entry(p["name"], ", ".join(p.get("tech", []))))
            o.append(f'<p class="small">{_e(p.get("blurb_lead") or p.get("blurb", ""))}</p>')
    if doc.get("skills"):
        o.append(f"<h2>{_e(lab['label.skills'])}</h2>")
        for g in doc["skills"]:
            o.append(f"<p><strong>{_e(g['label'])}</strong> &#183; {_e(', '.join(g['items']))}</p>")
    if doc.get("education"):
        o.append(f"<h2>{_e(lab['label.education'])}</h2>")
        for e in doc["education"]:
            o.append(_entry(e["degree"], e["institution"], e.get("location", ""), e.get("year", "")))
    if doc.get("publications"):
        o.append(f"<h2>{_e(lab['label.publications'])}</h2>")
        for p in doc["publications"]:
            o.append(_entry(p["title"]) + f'<p class="small">{_e(p.get("detail", ""))}</p>')
    if doc.get("languages"):
        o.append(f"<h2>{_e(lab['label.languages'])}</h2>")
        o.append("<p>" + _join([f"<strong>{_e(l['name'])}</strong> {_e(l['level'])}" for l in doc["languages"]],
                               " &#8195; ") + "</p>")
    if doc.get("ats", {}).get("keywords"):
        o.append(f"<h2>{_e(lab['label.keywords'])}</h2><p>{_e(', '.join(doc['ats']['keywords']))}</p>")
    return "\n".join(x for x in o if x)


def _cover_body(doc: dict[str, Any]) -> str:
    lab, c = doc["labels"], doc["cover"]
    ident = doc["identity"]
    o = [f"<h1>{_e(ident['name'])}</h1>",
         '<p class="contact">' + _join([_e(ident["location"])]
                                       + [_link(c["label"], c["href"]) for c in ident["contact"]]) + "</p>"]
    o.append(f'<p class="muted small">{_e(lab["label.cover.date"])}: {_e(doc["meta"]["date"])}</p>')
    o.append(f"<h2>{_e(c['subject'])}</h2>")
    o.append(f"<p>{_e(c['salutation'])}</p>")
    if c.get("opening"):
        o.append(f"<p>{_e(c['opening'])}</p>")
    for p in c.get("paragraphs", []):
        t = f"<strong>{_e(p['title'])}</strong> " if p.get("title") else ""
        o.append(f"<p>{t}{_e(p['body'])}</p>")
    if c.get("closing"):
        o.append(f"<p>{_e(c['closing'])}</p>")
    o.append(f"<p>{_e(c.get('regards') or lab['label.cover.regards'])}</p>")
    o.append(f"<p><strong>{_e(doc['identity']['name'])}</strong></p>")
    return "\n".join(o)


def _accent(doc: dict[str, Any]) -> str:
    raw = str(doc.get("area", {}).get("accent") or "#1F6FEB").lstrip("#").upper()
    if len(raw) != 6 or any(ch not in "0123456789ABCDEF" for ch in raw):
        raise ValueError(f"area accent {raw!r} is not a 6-digit hex colour")
    return raw


def render_document(doc: dict[str, Any]) -> str:
    """Complete, self-contained HTML source for ``doc``."""
    kind = doc["kind"]
    if kind not in ("cv", "cover"):
        raise ValueError(f"unknown document kind {kind!r}")
    ident, lang = doc["identity"], doc["lang"]
    epoch = int(doc.get("meta", {}).get("epoch", 0))
    created = _dt.datetime.fromtimestamp(epoch, _dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    body = _cv_body(doc) if kind == "cv" else _cover_body(doc)
    css = _CSS % {"fonts": _fonts(lang), "accent": _accent(doc)}
    return (
        f'<!doctype html>\n<html lang="{_e(lang)}" dir="{_e(doc.get("dir", "rtl"))}">\n<head>\n'
        '<meta charset="utf-8">\n'
        f"<title>{_e(doc['ats']['title'])}</title>\n"
        f'<meta name="model-hash" content="{_e(str(doc.get("meta", {}).get("model_hash", "")))}">\n'
        f'<meta name="author" content="{_e(ident["name"])}">\n'
        f'<meta name="description" content="{_e(doc["area"]["title"] + ": " + doc["area"]["tagline"])}">\n'
        f'<meta name="keywords" content="{_e(", ".join(doc["ats"]["keywords"]))}">\n'
        f'<meta name="dcterms.created" content="{created}">\n'
        f'<meta name="dcterms.modified" content="{created}">\n'
        f"<style>{css}</style>\n</head>\n<body>\n{body}\n</body>\n</html>\n"
    )


def build(doc: dict[str, Any], outdir: Path, stem: str, *, epoch: int,
          workdir: Path | None = None) -> dict[str, Path]:
    """Write ``<stem>.html`` and ``<stem>.pdf`` into ``outdir`` (atomically)."""
    outdir = Path(outdir)
    outdir.mkdir(parents=True, exist_ok=True)
    src = render_document(doc)
    html_path = outdir / f"{stem}.html"
    # Invalidate first: a failed render must not leave the previous build's files.
    (outdir / f"{stem}.pdf").unlink(missing_ok=True)
    html_path.unlink(missing_ok=True)
    pdf = compile_pdf(src, outdir / f"{stem}.pdf", lang=doc["lang"])
    tmp = html_path.with_name(f".{html_path.name}.{os.getpid()}.tmp")
    tmp.write_text(src, encoding="utf-8")
    os.replace(tmp, html_path)
    return {"html": html_path, "pdf": pdf}


def compile_pdf(html_source: str, out_pdf: Path, *, lang: str) -> Path:
    require_fonts(lang)
    from weasyprint import HTML  # imported lazily: only RTL locales need it
    out_pdf = Path(out_pdf)
    out_pdf.parent.mkdir(parents=True, exist_ok=True)
    tmp = out_pdf.with_name(f".{out_pdf.name}.{os.getpid()}.tmp")
    try:
        # pdf_variant="pdf/ua-1" is the only WeasyPrint mode that writes the
        # tag tree AND the XMP packet (T170).  It also stamps pdfuaid:part=1 in
        # the XMP; that is the library's declaration, NOT a measured result --
        # no PDF/UA validator is installed here.  Do not cite it as compliance.
        HTML(string=html_source).write_pdf(str(tmp), pdf_identifier=b"milos-career",
                                           pdf_variant="pdf/ua-1")
        os.replace(tmp, out_pdf)  # atomic: a reader never sees a half-written PDF
    finally:
        tmp.unlink(missing_ok=True)
    return out_pdf


__all__ = ["render_document", "compile_pdf", "build", "FontMissing"]
