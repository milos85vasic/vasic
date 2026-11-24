#!/usr/bin/env python3
"""Extraction-side gates (JSK-T163, T174, T178, T168, T169, T179) with paired golden-bad mutations.

Run:  python3 -m unittest discover -s _tools/career -p 'test_extract_gates.py'

Positive evidence comes from a SMALL REAL sample (real renderer, real gates); golden-bad cases
mutate the extracted text of those real documents, so the same detector is shown to pass the
good document and fail the broken one.  Toolchain absent -> SKIP (undetermined, never a pass).
"""
from __future__ import annotations

import re
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from career import extract_gates as g, gates, sample_build  # noqa: E402

REPO = Path(__file__).resolve().parents[2]
TOOLS = sample_build.have_toolchain()


class PureDetectors(unittest.TestCase):
    def test_placeholder_leak_golden_bad(self):
        for bad in ("Dear {{company}},", "Hello [Company]", "to <role>", "TODO fix", "lorem ipsum dolor", "TBD"):
            self.assertTrue(g.check_placeholder_leak(bad), bad)
        self.assertEqual(g.check_placeholder_leak("Dear hiring manager, I build AI systems."), [])

    def test_reserved_pattern_equals_job_seeker(self):
        cands = [base / sub / "internal" / "templates" / "slots.go"
                 for base in (REPO, *REPO.parents) for sub in ("job_seeker", "vasic/job_seeker")]
        for src in cands:
            if src.is_file():
                m = re.search(r"reReserved\s*=\s*regexp\.MustCompile\(`([^`]*)`\)", src.read_text(encoding="utf-8"))
                self.assertIsNotNone(m)
                self.assertEqual(m.group(1), g.RESERVED_PATTERN)
                return
        self.skipTest("job_seeker checkout not found: cannot determine")

    def test_every_locale_has_every_required_alias(self):
        for sec in g.REQUIRED_HEADINGS:
            self.assertEqual(len(g.HEADING_ALIASES[sec]), 15, sec)

    def test_headings_golden_bad(self):
        good = "Experience\nEducation\nTechnical skills\n"
        self.assertEqual(g.check_headings(good, "en"), [])
        self.assertTrue(g.check_headings("Experience\nEducation\nStuff I know\n", "en"))
        self.assertTrue(g.check_headings("Experience Education Skills in one line", "en"))
        self.assertTrue(g.check_headings(good, None))

    def test_running_header_golden_bad(self):
        ok = ["Name\nbody one\nend 1", "more\nbody two\nother"]
        bad = ["Jane Doe CV\nbody one\nPage 1", "Jane Doe CV\nbody two\nPage 2"]
        self.assertEqual(g.check_running_headers(ok), [])
        self.assertTrue(g.check_running_headers(bad))
        self.assertEqual(g.check_running_headers(["Jane Doe CV\nonly page\nPage 1"]), [])

    def test_hyphenation_detector(self):
        self.assertTrue(g.check_hyphenation(["evalua-\ntion engine"]))
        self.assertEqual(g.check_hyphenation(["whole words only"]), [])


@unittest.skipUnless(TOOLS, "lualatex or pdftotext missing: cannot determine")
class RealSample(unittest.TestCase):
    LANGS = ("en", "ru", "ar", "hi")

    @classmethod
    def setUpClass(cls):
        import tempfile
        cls.td, cls.out, cls.priv = sample_build.scratch_pair()
        cls.sample = sample_build.build_sample(cls.out, cls.priv, langs=cls.LANGS)

    @classmethod
    def tearDownClass(cls):
        cls.td.cleanup()

    def test_real_gates_pass_with_new_checks_wired(self):
        self.assertEqual([r for r in self.sample["results"] if r["rc"] != 0], [])

    def test_validate_pdf_runs_new_checks_and_refuses_mutation(self):
        pdf = self.out / "cv-ai-engineering-en.pdf"
        rc, msg = gates.validate_pdf(pdf, "cv", "en")
        self.assertEqual(rc, 0, msg)
        orig = gates._extract
        try:
            gates._extract = lambda p: orig(p).replace("Experience", "Stuff I did") + "\n{{company}}"
            rc, msg = gates.validate_pdf(pdf, "cv", "en")
        finally:
            gates._extract = orig
        self.assertEqual(rc, 1, msg)
        self.assertIn("placeholder token", msg)
        self.assertIn("heading", msg)

    def test_real_cv_headings_recognised_per_locale(self):
        for lang in self.LANGS:
            text = g.extract_poppler_layout(self.out / f"cv-ai-engineering-{lang}.pdf")
            self.assertEqual(g.check_headings(text, lang), [], lang)
            self.assertEqual(g.check_placeholder_leak(text, lang), [], lang)

    def test_real_documents_have_no_running_header(self):
        for p in sorted(self.out.glob("*.pdf")):
            self.assertEqual(g.check_running_headers(g.pages_of(p)), [], p.name)

    def test_word_boundaries_real(self):
        r = g.check_word_boundaries(self.out / "cv-ai-engineering-hi.pdf")
        if r is None:
            self.skipTest("mutool/pdftotext missing")
        self.assertEqual(r, [])


if __name__ == "__main__":
    unittest.main()
