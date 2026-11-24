#!/usr/bin/env python3
"""T170 / G-08 / G-22 / F-26: tagged PDF + XMP + title display, both engines.

What is asserted is STRUCTURE (``/MarkInfo``, ``/StructTreeRoot``,
``/Metadata``, ``/Lang``, ``DisplayDocTitle``) -- not PDF/UA conformance.  No
PDF/UA validator (veraPDF) is installed on the development host, so nothing
here may be read as a conformance claim.

Run:  python3 -m unittest discover -s _tools/career -p 'test_pdf_structure.py'
"""
from __future__ import annotations

import shutil
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from career import gates, model as cmodel, overlay, resolve  # noqa: E402
from career.render import html as html_engine, latex  # noqa: E402

HAVE_TEX = bool(shutil.which("lualatex") and shutil.which("pdftotext"))
EPOCH = 1700000000


def _doc(lang: str, kind: str = "cv"):
    return resolve.resolve(cmodel.load_model(), "mobile", lang, kind=kind, epoch=EPOCH,
                           overlay=overlay.load_overlay())


class Source(unittest.TestCase):
    def test_latex_source_enables_tagging_before_documentclass(self):
        src = latex.render_document(_doc("en"))
        self.assertTrue("\\DocumentMetadata{" in src)
        self.assertLess(src.index("\\DocumentMetadata{"), src.index("\\documentclass"))
        head = src[src.index("\\DocumentMetadata{"):].split("}", 1)[0]
        self.assertTrue("lang=en" in head and "tagging=on" in head, head)

    def test_latex_source_does_not_claim_pdfua(self):
        # No validator on the host: the artifact must not self-declare conformance.
        self.assertFalse("pdfstandard" in latex.render_document(_doc("en")))

    def test_class_turns_softhyphen_rewrite_off(self):
        # tagpdf rewrites every line-end hyphen to U+00AD, which the gate forbids.
        cls = (Path(latex.__file__).resolve().parent.parent / "latex" / "miloscv.cls").read_text("utf-8")
        self.assertTrue("activate/softhyphen=false" in cls)


class Gate(unittest.TestCase):
    def test_untagged_pdf_is_flagged(self):
        from unittest import mock
        with mock.patch.object(gates, "_pdf_structure", return_value={}):
            problems = gates._check_structure(Path("x.pdf"))
        for needle in ("MarkInfo", "StructTreeRoot", "Metadata", "Lang"):
            self.assertTrue(any(needle in p for p in problems), (needle, problems))

    def test_complete_structure_passes(self):
        from unittest import mock
        full = {"marked": True, "struct": True, "xmp": True, "lang": "en",
                "display_title": True, "title": "T"}
        with mock.patch.object(gates, "_pdf_structure", return_value=full):
            self.assertEqual(gates._check_structure(Path("x.pdf")), [])

    def test_validate_pdf_runs_the_structure_gate(self):
        src = Path(gates.__file__).read_text(encoding="utf-8")
        self.assertTrue("_check_structure(pdf_path" in src)


@unittest.skipUnless(HAVE_TEX, "lualatex/pdftotext missing")
class BuiltLatex(unittest.TestCase):
    def test_every_checked_locale_builds_tagged_and_gates_green(self):
        for lang in ("en", "ru", "hi", "zh"):
            with self.subTest(lang=lang), tempfile.TemporaryDirectory() as d:
                doc = _doc(lang)
                paths = latex.build(doc, Path(d), "t", epoch=EPOCH)
                self.assertEqual(gates._check_structure(paths["pdf"]), [], lang)
                rc, msg = gates.validate_pdf(paths["pdf"], "cv", lang, None,
                                             [c["label"] for c in doc["identity"]["contact"]])
                self.assertEqual(rc, 0, msg)

    def test_build_is_byte_reproducible_with_tagging(self):
        doc = _doc("en")
        with tempfile.TemporaryDirectory() as a, tempfile.TemporaryDirectory() as b:
            pa = latex.build(doc, Path(a), "t", epoch=EPOCH)["pdf"].read_bytes()
            pb = latex.build(doc, Path(b), "t", epoch=EPOCH)["pdf"].read_bytes()
        self.assertEqual(pa, pb)


@unittest.skipUnless(shutil.which("pdftotext"), "pdftotext missing")
class BuiltHtml(unittest.TestCase):
    def test_rtl_engine_builds_tagged_and_gates_green(self):
        try:
            import weasyprint  # noqa: F401
        except ImportError:
            self.skipTest("weasyprint missing")
        doc = _doc("ar")
        with tempfile.TemporaryDirectory() as d:
            paths = html_engine.build(doc, Path(d), "t", epoch=EPOCH)
            self.assertEqual(gates._check_structure(paths["pdf"]), [])
            rc, msg = gates.validate_pdf(paths["pdf"], "cv", "ar", None,
                                         [c["label"] for c in doc["identity"]["contact"]])
        self.assertEqual(rc, 0, msg)


if __name__ == "__main__":
    unittest.main()
