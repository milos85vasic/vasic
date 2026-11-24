#!/usr/bin/env python3
"""Tests for gates.py / render/latex.py defects I6-I9 and the escape latents.

Run:  python3 -m unittest discover -s _tools/career -p 'test_gates_render.py'
"""
from __future__ import annotations

import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from career import gates  # noqa: E402
from career.render import latex  # noqa: E402

CLS = Path(__file__).resolve().parent / "latex" / "miloscv.cls"
HAVE_TEX = shutil.which("lualatex") and shutil.which("pdftotext")


def _compile(body: str, tmp: Path) -> Path:
    (tmp / "miloscv.cls").write_text(CLS.read_text(encoding="utf-8"), encoding="utf-8")
    (tmp / "doc.tex").write_text(body, encoding="utf-8")
    subprocess.run(["lualatex", "-interaction=nonstopmode", "-halt-on-error", "doc.tex"],
                   cwd=tmp, capture_output=True, check=True, timeout=300)
    return tmp / "doc.pdf"


def _pdffonts(rows: list[str]) -> str:
    head = ("name                                 type              encoding         emb sub uni object ID\n"
            "------------------------------------ ----------------- ---------------- --- --- --- ---------\n")
    return head + "\n".join(rows) + "\n"


def _row(name, typ, enc, emb, sub, uni="yes"):
    return f"{name:<36} {typ:<17} {enc:<16} {emb:<3} {sub:<3} {uni:<3} {13:>6}  0"


class FontParsing(unittest.TestCase):
    def _run(self, rows):
        fake = mock.Mock(returncode=0, stdout=_pdffonts(rows))
        with mock.patch.object(gates.subprocess, "run", return_value=fake):
            return gates._check_fonts_embedded(Path("x.pdf"))

    def test_type3_detected(self):
        p = self._run([_row("Foo", "Type 3", "Custom", "no", "no")])
        self.assertTrue(any("Type3" in x or "Type 3" in x for x in p), p)

    def test_cid_truetype_good_is_clean(self):
        self.assertEqual(self._run([_row("NK+Noto", "CID TrueType", "Identity-H", "yes", "yes")]), [])

    def test_cid_truetype_not_subset_flagged(self):
        p = self._run([_row("Noto", "CID TrueType", "Identity-H", "yes", "no")])
        self.assertTrue(any("not subset" in x for x in p), p)

    def test_unembedded_flagged(self):
        p = self._run([_row("Arial", "TrueType", "WinAnsi", "no", "no")])
        self.assertTrue(any("not embedded" in x for x in p), p)


class SingleColumn(unittest.TestCase):
    @unittest.skipUnless(HAVE_TEX, "lualatex/pdftotext missing")
    def test_two_column_pdf_rejected_single_accepted(self):
        words = " ".join(["lorem ipsum dolor sit amet consectetur"] * 120)
        with tempfile.TemporaryDirectory() as d:
            d = Path(d)
            two = d / "two"; two.mkdir()
            pdf2 = _compile("\\documentclass{article}\\usepackage{multicol}\\begin{document}"
                            "\\begin{multicols}{2}" + words + "\\end{multicols}\\end{document}", two)
            one = d / "one"; one.mkdir()
            pdf1 = _compile("\\documentclass{article}\\begin{document}" + words + "\\end{document}", one)
            self.assertTrue(gates._check_single_column_pdf(pdf2), "two-column PDF must be flagged")
            self.assertEqual(gates._check_single_column_pdf(pdf1), [])

    def test_source_check(self):
        self.assertTrue(gates._check_single_column(r"\begin{multicols}{2}"))


class KindCli(unittest.TestCase):
    def test_cli_passes_kind(self):
        with mock.patch.object(gates, "validate_pdf", return_value=(0, "ok")) as v, \
                mock.patch.object(sys, "argv", ["gates", "a.pdf", "--kind", "cover"]):
            with self.assertRaises(SystemExit):
                gates._main()
        self.assertEqual(v.call_args[0][1], "cover")

    def test_cli_bad_kind(self):
        with mock.patch.object(sys, "argv", ["gates", "a.pdf", "--kind", "bogus"]):
            with self.assertRaises(SystemExit) as e:
                gates._main()
        self.assertEqual(e.exception.code, 2)


class ContactUrls(unittest.TestCase):
    def test_broken_url_flagged(self):
        txt = "x gitlab.com/milos85va-\nsic y"
        self.assertTrue(gates._check_contact_urls(txt, ["gitlab.com/milos85vasic"]))

    def test_intact_url_ok(self):
        self.assertEqual(gates._check_contact_urls("a gitlab.com/milos85vasic b", ["gitlab.com/milos85vasic"]), [])

    @unittest.skipUnless(HAVE_TEX, "lualatex/pdftotext missing")
    def test_header_never_hyphenates_url(self):
        # Force a break point right at the url: long location pushes it to line end.
        url = "gitlab.com/milos85vasic"
        pieces = latex._join([latex.tex_text("Belgrade " * 9), latex._url(url)])
        body = ("\\documentclass{miloscv}\n\\begin{document}\n"
                "\\milosletterhead{N}{" + pieces + "}\n\\end{document}\n")
        with tempfile.TemporaryDirectory() as d:
            pdf = _compile(body, Path(d))
            text = subprocess.run(["pdftotext", "-layout", str(pdf), "-"],
                                  capture_output=True, text=True).stdout
        self.assertEqual(gates._check_contact_urls(text, [url]), [], text)


class UrlBox(unittest.TestCase):
    def test_url_is_unbreakable_box(self):
        self.assertTrue(latex._url("a.com/x").startswith(r"\mbox{\href{"))

    @unittest.skipUnless(HAVE_TEX, "lualatex/pdftotext missing")
    def test_hindi_header_url_intact(self):
        # Regression: cv-mobile-hi broke "gitlab.com/mi-/los85vasic".
        import json
        from career import resolve, model as cmodel
        m = cmodel.load_model()
        doc = resolve.resolve(m, "mobile", "hi", kind="cv", epoch=1700000000)
        with tempfile.TemporaryDirectory() as d:
            paths = latex.build(doc, Path(d), "t", epoch=1700000000)
            text = subprocess.run(["pdftotext", "-layout", str(paths["pdf"]), "-"],
                                  capture_output=True, text=True).stdout
        urls = [c["label"] for c in doc["identity"]["contact"]]
        self.assertEqual(gates._check_contact_urls(text, urls), [], text[:400])


class LinkAnnotations(unittest.TestCase):
    """T162 / G-02 / F-08: the /Annots dictionary, not the visible text, is what a click follows."""

    CONTACT = [
        {"kind": "email", "label": "a@example.org", "href": "mailto:a@example.org"},
        {"kind": "url", "label": "example.org", "href": "https://example.org"},
        {"kind": "url", "label": "github.com/someone", "href": "https://github.com/someone"},
    ]

    def _pdf(self, contacts, tmp):
        pieces = latex._join([latex._url(c["label"], c["href"]) for c in contacts])
        body = ("\\documentclass{miloscv}\n\\begin{document}\n"
                "\\milosletterhead{N}{" + pieces + "}\n\\end{document}\n")
        return _compile(body, tmp)

    def test_url_helper_takes_explicit_target(self):
        out = latex._url("github.com/x", "https://github.com/x")
        self.assertIn(r"\href{https://github.com/x}{github.com/x}", out)

    @unittest.skipUnless(HAVE_TEX, "lualatex missing")
    def test_rebuilt_links_are_real_uris(self):
        with tempfile.TemporaryDirectory() as d:
            pdf = self._pdf(self.CONTACT, Path(d))
            self.assertEqual(gates._check_link_annotations(pdf, [c["label"] for c in self.CONTACT]), [])
            uris = sorted(u for _, u in gates._link_annotations(pdf))
        self.assertEqual(uris, ["https://example.org", "https://github.com/someone", "mailto:a@example.org"])

    @unittest.skipUnless(HAVE_TEX, "lualatex missing")
    def test_golden_bad_schemeless_href_is_flagged(self):
        # Exactly what the renderer emitted before the fix: target == label.
        bad = [{"kind": "url", "label": c["label"], "href": c["label"]} for c in self.CONTACT]
        with tempfile.TemporaryDirectory() as d:
            pdf = self._pdf(bad, Path(d))
            problems = gates._check_link_annotations(pdf, [c["label"] for c in self.CONTACT])
        self.assertTrue(problems, "a GoToR / scheme-less link must fail the gate")
        self.assertTrue(any("GoToR" in p or "scheme" in p for p in problems), problems)

    def test_link_must_match_visible_label(self):
        with mock.patch.object(gates, "_link_annotations",
                               return_value=[("URI", "https://evil.example/x")]):
            problems = gates._check_link_annotations(Path("x.pdf"), ["github.com/someone"])
        self.assertTrue(any("github.com/someone" in p for p in problems), problems)

    def test_non_uri_actions_rejected(self):
        for kind in ("GoToR", "Launch", "GoTo"):
            with mock.patch.object(gates, "_link_annotations", return_value=[(kind, "")]):
                self.assertTrue(gates._check_link_annotations(Path("x.pdf"), []), kind)

    def test_good_annotations_pass(self):
        ann = [("URI", "mailto:a@example.org"), ("URI", "https://example.org")]
        with mock.patch.object(gates, "_link_annotations", return_value=ann):
            self.assertEqual(gates._check_link_annotations(Path("x.pdf"), ["a@example.org", "example.org"]), [])

    def test_validate_pdf_runs_the_link_gate(self):
        src = Path(gates.__file__).read_text(encoding="utf-8")
        self.assertTrue("_check_link_annotations(pdf_path" in src)

    def test_tex_contact_urls_return_labels_not_targets(self):
        with tempfile.TemporaryDirectory() as d:
            t = Path(d) / "x.tex"
            t.write_text("\\mbox{\\href{https://github.com/x}{github.com/x}}\n", encoding="utf-8")
            self.assertEqual(gates._tex_contact_urls(t), ["github.com/x"])


class Escaping(unittest.TestCase):
    def test_braces_not_double_escaped(self):
        self.assertEqual(latex.escape("a\\b"), r"a\textbackslash{}b")
        self.assertEqual(latex.escape("{x}"), r"\{x\}")

    def test_url_no_double_escape(self):
        out = latex._url("a.com/x?y=1%20#frag")
        target = out.split("}{")[0]
        self.assertNotIn(r"\\%", target)
        self.assertNotIn(r"\\#", target)
        self.assertIn(r"\%", target)


if __name__ == "__main__":
    unittest.main()
