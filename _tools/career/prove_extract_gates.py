#!/usr/bin/env python3
"""Paired mutation proof of the extraction-side ATS gates (JSK-T168, T178, T179).

Run:  python3 -m career.prove_extract_gates        (from ``_tools``; builds a small REAL sample, ~3 min)

Every case builds on REAL renderer output judged by the REAL gates.  A *control* shows the unmutated
artifact passes; each *mutation* breaks exactly one thing and the gate must flip to a failure.  A gate
that passes a mutation is a hollow gate (11.4.201) and this exits 1.  Exit 0 only when every control
passes and every mutation is caught; exit 2 when the toolchain is absent (never a pass).
"""
from __future__ import annotations

import shutil
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from career import extract_gates as g, gates, sample_build  # noqa: E402

LANGS = ("en", "de", "ru", "hi", "ko")
RESULTS: list[tuple[str, bool, str]] = []


def case(name: str, ok: bool, detail: str = "") -> None:
    RESULTS.append((name, ok, detail))
    print(f"{'PASS' if ok else 'FAIL'} {name}{(' - ' + detail) if detail else ''}", flush=True)


def _lossy(text: str, keep_every: int = 20, drop: int = 9) -> str:
    n, out = 0, []
    for ch in text:
        if ch == " ":
            n += 1
            if n % keep_every < drop:
                continue
        out.append(ch)
    return "".join(out)


class Patch:
    def __init__(self, **kw):
        self.kw, self.saved = kw, {}

    def __enter__(self):
        for k, v in self.kw.items():
            self.saved[k] = getattr(g, k)
            setattr(g, k, v)

    def __exit__(self, *a):
        for k, v in self.saved.items():
            setattr(g, k, v)


def prove_t168(out: Path) -> None:
    pdf = {l: out / f"cv-ai-engineering-{l}.pdf" for l in LANGS}
    for l in LANGS:
        case(f"T168 control {l}: real PDF passes the boundary gate", g.check_word_boundaries(pdf[l], l) == [],
             str(g.boundary_counts(pdf[l])))
        case(f"T168 control {l}: real PDF passes validate_pdf", gates.validate_pdf(pdf[l], "cv", l)[0] == 0)
    for l in ("hi", "ko"):
        real = g.extract_mupdf(pdf[l])
        with Patch(extract_mupdf=lambda p, real=real: _lossy(real)):
            r = g.check_word_boundaries(pdf[l], l)
            rc, msg = gates.validate_pdf(pdf[l], "cv", l)
        case(f"T168 M-mupdf-{l}: MuPDF loses 45% of the spaces -> blocked", bool(r) and rc == 1 and "word boundaries" in msg,
             str(r))
    real = g.extract_poppler_raw(pdf["en"])
    with Patch(extract_poppler_raw=lambda p: _lossy(real)):
        r = g.check_word_boundaries(pdf["en"], "en")
    case("T168 M-poppler-en: poppler loses 45% of the spaces -> blocked (any extractor, not only MuPDF)", bool(r), str(r))
    real = g.extract_pypdf(pdf["en"])
    with Patch(extract_pypdf=lambda p: real.replace(" ", "")):
        r = g.check_word_boundaries(pdf["en"], "en")
    case("T168 M-pypdf-en: pypdf with no spaces at all -> blocked", bool(r), str(r))
    with Patch(extract_mupdf=lambda p: None, extract_pypdf=lambda p: None):
        r = g.check_word_boundaries(pdf["en"], "en")
    case("T168 M-one-extractor: fewer than two extractors -> CANNOT DETERMINE (None, never a pass)", r is None, str(r))
    real = g.extract_mupdf(pdf["en"])
    with Patch(extract_mupdf=lambda p: _lossy(real)):
        r = g.check_word_boundaries(pdf["en"], "zh")
    case("T168 exemption: unspaced scripts (zh) are not judged by token count (control for the exemption)", r == [], str(r))


def prove_t178(out: Path) -> None:
    for l in ("en", "de"):
        pdf = out / f"cv-ai-engineering-{l}.pdf"
        src = g.sibling_source_text(pdf)
        pages = g.pages_of(pdf)
        b = g.hyphen_breaks(pages, src)
        case(f"T178 control {l}: real CV has no automatic-hyphenation break", b["auto"] == [] and gates.validate_pdf(pdf, "cv", l)[0] == 0,
             f"explicit={len(b['explicit'])}")
        cut = [pages[0] + "\nwe evalua-\ntion and Post-\ngreSQL"] + list(pages[1:])
        r = g.check_hyphenation(cut, src)
        case(f"T178 M-auto-{l}: injected 'evalua-/tion' (renderer cut a word) -> blocked", bool(r), str(r))
        many = [pages[0] + "\n" + "\n".join("multi-\nprovider" for _ in range(g.EXPLICIT_HYPHEN_BUDGET + 1))] + list(pages[1:])
        r = g.check_hyphenation(many, src + " multi-provider")
        case(f"T178 M-budget-{l}: {g.EXPLICIT_HYPHEN_BUDGET + 1} source-hyphen breaks -> blocked by the budget", bool(r), str(r))
        r = g.check_hyphenation(cut, None)
        case(f"T178 M-nosource-{l}: no source => an auto break cannot be excused", bool(r), str(r))


def prove_t179(out: Path) -> None:
    import tempfile
    for l in ("en", "ru"):
        pdf = out / f"cv-ai-engineering-{l}.pdf"
        r = g.ocr_recall(pdf, l)
        case(f"T179 control {l}: page-1 OCR recall >= {g.MIN_OCR_RECALL:.0%} and validate_pdf rc 0",
             r is not None and r >= g.MIN_OCR_RECALL and gates.validate_pdf(pdf, "cv", l)[0] == 0, f"recall={r}")
    with tempfile.TemporaryDirectory() as td:
        for l in ("en", "ru"):
            shutil.copy(out / f"cv-ai-engineering-{l}.tex", Path(td) / f"cv-ai-engineering-{l}.tex")
            bad = sample_build.scramble_text_layer(out / f"cv-ai-engineering-{l}.pdf", Path(td) / f"cv-ai-engineering-{l}.pdf")
            rc, msg = gates.validate_pdf(bad, "cv", l)
            case(f"T179 M-scramble-{l}: real PDF whose text layer no longer matches the page -> blocked",
                 rc == 1 and "OCR recall" in msg, msg[:120])
    one = g.ocr_recall(out / "cv-ai-engineering-ru.pdf", "ru", spec="rus")
    case("T179 root cause of G-20: Cyrillic CV read with `rus` alone is below the bar (Latin names mis-read), `rus+eng` clears it",
         one is not None and one < g.MIN_OCR_RECALL, f"rus-only={one}")
    saved = g.shutil.which
    g.shutil.which = lambda n: None if n == "tesseract" else saved(n)
    try:
        r = g.check_ocr_consistency(out / "cv-ai-engineering-ru.pdf", "ru")
        rc = gates.validate_pdf(out / "cv-ai-engineering-ru.pdf", "cv", "ru")[0]
    finally:
        g.shutil.which = saved
    case("T179 M-no-tesseract: engine absent -> CANNOT DETERMINE (None / rc 2), never a pass", r is None and rc == 2, f"rc={rc}")
    case("T179 scope: locales without an OCR pack (hi, ko, ar, es...) are reported not-applicable, not silently passed",
         not any(g.ocr_applicable(l) for l in ("hi", "ko", "ar", "es")))


def main() -> int:
    if not sample_build.have_toolchain() or not shutil.which("mutool"):
        print("CANNOT DETERMINE: lualatex, pdftotext or mutool missing")
        return 2
    td, out, priv = sample_build.scratch_pair()
    try:
        sample_build.build_sample(out, priv, langs=LANGS, write=False)
        prove_t168(out)
        prove_t178(out)
        prove_t179(out)
    finally:
        td.cleanup()
    bad = [n for n, ok, _ in RESULTS if not ok]
    print(f"\n{len(RESULTS) - len(bad)} passed, {len(bad)} failed of {len(RESULTS)} cases")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
