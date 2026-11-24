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

    def test_hyphenation_auto_vs_source_hyphen(self):
        src = r"\section{Skills} multi-provider routing, evaluation and PostgreSQL \textbf{Anti-Bluff}"
        auto = ["we run evalua-\ntion and Post-\ngreSQL daily"]
        self.assertEqual(len(g.hyphen_breaks(auto, src)["auto"]), 2)
        self.assertTrue(g.check_hyphenation(auto, src))
        explicit = ["a multi-\nprovider setup and anti-\nbluff checks"]
        b = g.hyphen_breaks(explicit, src)
        self.assertEqual((len(b["auto"]), len(b["explicit"])), (0, 2))
        self.assertEqual(g.check_hyphenation(explicit, src), [])
        self.assertTrue(g.check_hyphenation(explicit, src, explicit_budget=1))      # budget enforced
        self.assertTrue(g.check_hyphenation(explicit, None))                         # no source => cannot excuse
        self.assertEqual(g.check_hyphenation(["whole words only"], src), [])

    def test_unspaced_cjk_line_end_hyphen_is_judged_by_its_own_word(self):
        """zh/ja have no spaces, so the text before a line-end hyphen is a whole clause with full-width punctuation.
        A break at the SOURCE hyphen of ``tree-of-thoughts`` is explicit; a cut inside a word is still automatic."""
        src = "規划（hiplan／mcts／tree-of-thoughts）、llmops、基准测试（swe-bench"
        explicit = ["规划（hiplan／mcts／tree-\nof-thoughts）、llmops、基准测试（swe-bench"]
        b = g.hyphen_breaks(explicit, src)
        self.assertEqual((len(b["auto"]), len(b["explicit"])), (0, 1), b)
        auto = ["规划（hiplan／mcts／tree-of-thoughts）、基准测试（evalua-\ntion、llmops"]
        b = g.hyphen_breaks(auto, src)
        self.assertEqual((len(b["auto"]), len(b["explicit"])), (1, 0), b)
        self.assertTrue(g.check_hyphenation(auto, src))


class WordBoundaryPure(unittest.TestCase):
    """JSK-T168: tokens per extractor must agree (min/max >= 0.9) outside the unspaced CJK scripts."""

    def _with(self, mupdf, poppler, pypdf_text, lang):
        saved = (g.extract_mupdf, g.extract_poppler_raw, g.extract_pypdf)
        g.extract_mupdf, g.extract_poppler_raw, g.extract_pypdf = (lambda p: mupdf, lambda p: poppler, lambda p: pypdf_text)
        try:
            return g.check_word_boundaries(Path("x.pdf"), lang)
        finally:
            g.extract_mupdf, g.extract_poppler_raw, g.extract_pypdf = saved

    def test_agreeing_extractors_pass(self):
        t = " ".join(["word"] * 100)
        self.assertEqual(self._with(t, t, t, "hi"), [])

    def test_one_extractor_merging_words_fails(self):
        good, merged = " ".join(["word"] * 100), " ".join(["wordword"] * 55)
        for lang in ("hi", "ko", "en", "ar"):
            r = self._with(merged, good, good, lang)
            self.assertTrue(r and "word boundaries" in r[0], (lang, r))
        # the ratio is min/max across ALL extractors, not mupdf-vs-poppler only
        r = self._with(good, good, merged, "ru")
        self.assertTrue(r, r)

    def test_threshold_is_point_nine(self):
        a, b = " ".join(["w"] * 100), " ".join(["w"] * 91)
        self.assertEqual(self._with(a, a, b, "en"), [])
        b = " ".join(["w"] * 89)
        self.assertTrue(self._with(a, a, b, "en"))

    def test_unspaced_cjk_scripts_are_exempt(self):
        a, b = " ".join(["w"] * 100), " ".join(["w"] * 60)
        self.assertEqual(self._with(a, a, b, "zh"), [])
        self.assertEqual(self._with(a, a, b, "ja"), [])

    def test_pypdf_is_not_a_voter_for_rtl_scripts(self):
        good, fused = " ".join(["w"] * 100), " ".join(["w"] * 85)
        self.assertEqual(self._with(good, good, fused, "ar"), [])
        self.assertEqual(self._with(good, good, fused, "fa"), [])
        self.assertTrue(self._with(good, good, fused, "hi"))          # but it votes everywhere else
        self.assertTrue(self._with(fused, good, good, "ar"))          # and MuPDF/poppler still catch an RTL defect

    def test_ocr_applicability_is_explicit(self):
        for l in ("en", "ru", "sr", "de", "fr"):
            self.assertTrue(g.ocr_applicable(l), l)
        for l in ("hi", "ko", "ar", "zh", "ja", "es", None):
            self.assertFalse(g.ocr_applicable(l), l)

    def test_ocr_cannot_determine_is_none_not_a_pass(self):
        saved = g.shutil.which
        g.shutil.which = lambda n: None if n == "tesseract" else saved(n)
        try:
            self.assertIsNone(g.check_ocr_consistency(Path("x.pdf"), "ru"))
        finally:
            g.shutil.which = saved

    def test_missing_extractors_cannot_determine(self):
        self.assertIsNone(self._with(None, None, "a b c", "en"))


@unittest.skipUnless(TOOLS, "lualatex or pdftotext missing: cannot determine")
class RealSample(unittest.TestCase):
    LANGS = ("en", "ru", "ar", "hi", "ko")

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
        for lang in ("en", "ru", "hi", "ko", "ar"):
            r = g.check_word_boundaries(self.out / f"cv-ai-engineering-{lang}.pdf", lang)
            if r is None:
                self.skipTest("fewer than two extractors: cannot determine")
            self.assertEqual(r, [], lang)

    def test_ocr_agrees_with_text_layer_per_script(self):
        for lang in ("en", "ru"):
            pdf = self.out / f"cv-ai-engineering-{lang}.pdf"
            r = g.ocr_recall(pdf, lang)
            if r is None:
                self.skipTest("tesseract language pack missing: cannot determine")
            self.assertGreaterEqual(r, g.MIN_OCR_RECALL, lang)
            self.assertEqual(g.check_ocr_consistency(pdf, lang), [], lang)

    def test_single_language_ocr_is_the_g20_measurement_artefact(self):
        """ru read with `rus` alone mis-reads the Latin technology names: ~0.73; `rus+eng` reads 0.96 (the root cause of G-20)."""
        pdf = self.out / "cv-ai-engineering-ru.pdf"
        one, both = g.ocr_recall(pdf, "ru", spec="rus"), g.ocr_recall(pdf, "ru")
        if one is None or both is None:
            self.skipTest("tesseract rus pack missing: cannot determine")
        self.assertLess(one, g.MIN_OCR_RECALL)
        self.assertGreaterEqual(both, g.MIN_OCR_RECALL)

    def test_text_layer_that_disagrees_with_the_page_is_refused(self):
        import tempfile
        pdf = self.out / "cv-ai-engineering-en.pdf"
        self.assertEqual(gates.validate_pdf(pdf, "cv", "en")[0], 0)
        with tempfile.TemporaryDirectory() as td:
            __import__("shutil").copy(pdf.with_suffix(".tex"), Path(td) / "cv-ai-engineering-en.tex")
            bad = sample_build.scramble_text_layer(pdf, Path(td) / "cv-ai-engineering-en.pdf")
            rc, msg = gates.validate_pdf(bad, "cv", "en")
            self.assertEqual(rc, 1, msg)
            self.assertIn("OCR recall", msg)

    def test_merged_boundaries_in_one_real_extractor_fail_the_gate(self):
        """Golden-bad on the REAL text of the good hi/ko PDFs: drop 45% of MuPDF's spaces (the G-06 defect)."""
        for lang in ("hi", "ko"):
            pdf = self.out / f"cv-ai-engineering-{lang}.pdf"
            self.assertEqual(gates.validate_pdf(pdf, "cv", lang)[0], 0, lang)
            real = g.extract_mupdf(pdf)
            seen = [0]

            def lossy(_p, real=real, seen=seen):
                out = []
                for ch in real:
                    if ch == " ":
                        seen[0] += 1
                        if seen[0] % 20 < 9:  # 45%
                            continue
                    out.append(ch)
                return "".join(out)
            orig = g.extract_mupdf
            g.extract_mupdf = lossy
            try:
                rc, msg = gates.validate_pdf(pdf, "cv", lang)
            finally:
                g.extract_mupdf = orig
            self.assertEqual(rc, 1, (lang, msg))
            self.assertIn("word boundaries differ", msg)


@unittest.skipUnless(TOOLS and __import__("shutil").which("mutool"), "lualatex, pdftotext or mutool missing: cannot determine")
class BrokenArtifactWordBoundaries(unittest.TestCase):
    """RED-on-the-broken-artifact (11.4.115): the pre-T170 build (no tagging => no interword space glyphs)."""

    def test_untagged_build_of_hindi_and_korean_is_refused(self):
        import tempfile
        from career import model as cmodel, overlay, resolve
        from career.render import latex
        orig = latex.render_document
        latex.render_document = lambda d: orig(d).replace("tagging=on", "tagging=off")
        try:
            with tempfile.TemporaryDirectory(prefix="career-broken-") as td:
                for lang in ("hi", "ko"):
                    doc = resolve.resolve(cmodel.load_model(), "ai-engineering", lang, kind="cv",
                                          epoch=sample_build.EPOCH, overlay=overlay.load_overlay())
                    paths = latex.build(doc, Path(td), f"broken-{lang}", epoch=sample_build.EPOCH)
                    counts = g.boundary_counts(paths["pdf"])
                    rc, msg = gates.validate_pdf(paths["pdf"], "cv", lang)
                    self.assertEqual(rc, 1, (lang, counts, msg))
                    self.assertIn("word boundaries differ", msg, (lang, counts))
        finally:
            latex.render_document = orig


@unittest.skipUnless(TOOLS, "lualatex or pdftotext missing: cannot determine")
class BrokenArtifactHyphenation(unittest.TestCase):
    """RED-on-the-broken-artifact: the pre-T178 class (hyphenpenalty=600) cuts words at line ends."""

    def _build(self, td, lang, penalty):
        from career import model as cmodel, overlay, resolve
        from career.render import latex
        orig = latex.class_source()
        src = orig if penalty is None else orig.replace("\\hyphenpenalty=10000", f"\\hyphenpenalty={penalty}")
        latex._CLASS_CACHE["src"] = src
        try:
            doc = resolve.resolve(cmodel.load_model(), "ai-engineering", lang, kind="cv",
                                  epoch=sample_build.EPOCH, overlay=overlay.load_overlay())
            return latex.build(doc, Path(td), f"hy-{lang}-{penalty}", epoch=sample_build.EPOCH)["pdf"]
        finally:
            latex._CLASS_CACHE["src"] = orig

    def test_html_engine_source_classifies_hyphens(self):
        import tempfile
        with tempfile.TemporaryDirectory() as td:
            pdf = Path(td) / "x.pdf"
            pdf.with_suffix(".html").write_text("<html><style>a{}</style><p>a <b>multi-provider</b> and evaluation &amp; more</p>", encoding="utf-8")
            src = g.sibling_source_text(pdf)
            self.assertIn("multi-provider", src)
            self.assertNotIn("a{}", src)
            self.assertEqual(len(g.hyphen_breaks(["a multi-\nprovider"], src)["explicit"]), 1)
            self.assertEqual(len(g.hyphen_breaks(["an evalua-\ntion"], src)["auto"]), 1)
            self.assertIsNone(g.sibling_source_text(Path(td) / "none.pdf"))

    def test_old_penalty_is_refused_and_current_class_is_clean(self):
        import tempfile
        with tempfile.TemporaryDirectory(prefix="career-hyph-") as td:
            for lang in ("en", "de"):
                bad = self._build(td, lang, 600)
                src = g.sibling_source_text(bad)
                self.assertTrue(g.hyphen_breaks(g.pages_of(bad), src)["auto"], lang)
                rc, msg = gates.validate_pdf(bad, "cv", lang)
                self.assertEqual(rc, 1, (lang, msg))
                self.assertIn("automatic hyphenation", msg)
                good = self._build(td, lang, None)
                self.assertEqual(g.hyphen_breaks(g.pages_of(good), g.sibling_source_text(good))["auto"], [], lang)
                self.assertEqual(gates.validate_pdf(good, "cv", lang)[0], 0, lang)


class RtlLogicalOrderPure(unittest.TestCase):
    """JSK-T169: supported readers are MuPDF and pdftotext -layout; both must read ar/fa words in logical order."""

    HTML = ("<html><head><title>\u0647\u0646\u062f\u0633\u0629 \u0627\u0644\u0630\u0643\u0627\u0621 \u0627\u0644\u0627\u0635\u0637\u0646\u0627\u0639\u064a</title></head>"
            "<body><p>\u0623\u0635\u0645\u0645 \u0623\u0633\u0627\u0637\u064a\u0644 \u0644\u0627 \u0643\u062a\u0644\u0627\u064b \u0645\u062a\u0631\u0627\u0635\u0629 LLM 2026, \u0628\u0644</p></body></html>")

    def test_phrases_come_from_body_text_only_and_stop_at_latin_digits_punctuation(self):
        ph = g.rtl_phrases_from_source(self.HTML)
        self.assertEqual(ph, ["\u0623\u0635\u0645\u0645 \u0623\u0633\u0627\u0637\u064a\u0644 \u0644\u0627"])   # head/title excluded; non-overlapping 3-word windows; the Latin/digit tail is never part of a phrase

    def _with(self, layout, mupdf):
        saved = g._rtl_extractions
        g._rtl_extractions = lambda p: {"pdftotext-layout": layout, "mupdf": mupdf}
        try:
            return g.check_rtl_logical_order(Path("x.pdf"), ["\u0623\u0635\u0645\u0645 \u0623\u0633\u0627\u0637\u064a\u0644 \u0644\u0627"] * 1 + ["\u0645\u0647\u0646\u062f\u0633 \u0630\u0643\u0627\u0621 \u0627\u0635\u0637\u0646\u0627\u0639\u064a"])
        finally:
            g._rtl_extractions = saved

    def test_forward_passes_reversed_fails_in_either_reader(self):
        fwd = "\u0623\u0635\u0645\u0645 \u0623\u0633\u0627\u0637\u064a\u0644 \u0644\u0627 \u0645\u0647\u0646\u062f\u0633 \u0630\u0643\u0627\u0621 \u0627\u0635\u0637\u0646\u0627\u0639\u064a"
        rev = "\u0627\u0635\u0637\u0646\u0627\u0639\u064a \u0630\u0643\u0627\u0621 \u0645\u0647\u0646\u062f\u0633 \u0644\u0627 \u0623\u0633\u0627\u0637\u064a\u0644 \u0623\u0635\u0645\u0645"
        self.assertEqual(self._with(fwd, fwd), [])
        for a, b, who in ((rev, fwd, "pdftotext-layout"), (fwd, rev, "mupdf")):
            r = self._with(a, b)
            self.assertEqual(len(r), 1, r)
            self.assertIn(who, r[0])

    def test_absent_reader_or_no_phrases_cannot_determine(self):
        fwd = "\u0623\u0635\u0645\u0645 \u0623\u0633\u0627\u0637\u064a\u0644 \u0644\u0627"
        self.assertIsNone(self._with(None, fwd))
        self.assertIsNone(g.check_rtl_logical_order(Path("x.pdf"), []))

    def test_left_to_right_locale_is_not_judged(self):
        self.assertEqual(g.check_rtl_document(Path("x.pdf"), "en"), [])

    def test_raw_reader_is_not_a_target(self):
        self.assertNotIn("pdftotext-raw", g.RTL_TARGET_EXTRACTORS)
        self.assertNotIn("pypdf", g.RTL_TARGET_EXTRACTORS)


@unittest.skipUnless(TOOLS and g.shutil.which("mutool"), "lualatex, pdftotext or mutool missing: cannot determine")
class RtlRealPdfs(unittest.TestCase):
    """Fresh ar/fa PDFs from the real renderer pass; a real visually-mirrored PDF is refused with the T169 message."""

    @classmethod
    def setUpClass(cls):
        cls.td, cls.out, cls.priv = sample_build.scratch_pair()
        sample_build.build_sample(cls.out, cls.priv, langs=("ar", "fa"), write=False)

    @classmethod
    def tearDownClass(cls):
        cls.td.cleanup()

    def test_fresh_pdfs_pass_and_mirrored_pdfs_are_refused(self):
        for kind, lang in (("cv", "ar"), ("cv", "fa"), ("cover", "ar")):
            pdf = self.out / f"{kind}-ai-engineering-{lang}.pdf"
            self.assertEqual(g.check_rtl_document(pdf, lang), [], pdf.name)
            self.assertEqual(gates.validate_pdf(pdf, kind, lang)[0], 0, pdf.name)
            bad = sample_build.visual_order_pdf(pdf.with_suffix(".html"), self.out / f"bad-{pdf.name}", lang)
            (self.out / f"bad-{pdf.stem}.html").write_text(pdf.with_suffix(".html").read_text(encoding="utf-8"), encoding="utf-8")
            r = g.check_rtl_document(bad, lang)
            self.assertEqual(len(r), 2, (pdf.name, r))
            rc, msg = gates.validate_pdf(bad, kind, lang)
            self.assertEqual(rc, 1, msg)
            self.assertIn("RTL words not in logical order", msg)

    def test_missing_html_source_cannot_determine(self):
        pdf = self.out / "cv-ai-engineering-ar.pdf"
        hidden = pdf.with_suffix(".html").rename(self.out / "hidden.html")
        try:
            self.assertIsNone(g.check_rtl_document(pdf, "ar"))
            self.assertEqual(gates.validate_pdf(pdf, "cv", "ar")[0], 2)
        finally:
            hidden.rename(pdf.with_suffix(".html"))


if __name__ == "__main__":
    unittest.main()
