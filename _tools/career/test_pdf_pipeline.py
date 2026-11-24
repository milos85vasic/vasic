#!/usr/bin/env python3
"""Tests for the multi-script PDF pipeline, the build lock/manifest and the new gates.

Run:  python3 -m unittest discover -s _tools/career -p 'test_pdf_pipeline.py'

Each defect below was observed RED before its fix (2026-11-23):
  * ja/zh/ko/hi built with the Latin font: text layer U+FFFD  (class ``\\ifx`` on macro bodies)
  * ar/fa: presentation forms + U+202x                       (LuaLaTeX RTL path)
  * ko: false "multi-column" from 0.56 pt baseline jitter    (integer-rounded line grouping)
  * two builds racing one output directory
"""
from __future__ import annotations

import hashlib
import os
import shutil
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from career import buildlib, gates, render  # noqa: E402
from career.render import fonts, latex  # noqa: E402

HAVE_TEX = bool(shutil.which("lualatex") and shutil.which("pdftotext"))
HAVE_RTL = False
try:  # WeasyPrint is optional on a dev host; real-PDF RTL tests skip without it
    import weasyprint  # noqa: F401
    HAVE_RTL = bool(shutil.which("pdftotext")) and not fonts.missing_families("ar")
except Exception:  # noqa: BLE001
    pass


def _doc(lang: str, kind: str = "cv") -> dict:
    """A minimal but complete DocumentModel for a locale (no profile needed)."""
    heads = {
        "ar": ("مهندس ذكاء اصطناعي", "ملخص", "rtl"), "fa": ("مهندس هوش مصنوعی", "خلاصه", "rtl"),
        "ja": ("AIエンジニア・基盤", "概要", "ltr"), "zh": ("AI工程师与基础设施", "简介", "ltr"),
        "ko": ("AI 엔지니어 인프라", "프로필", "ltr"), "hi": ("एआई इंजीनियर आधारभूत", "प्रोफ़ाइल", "ltr"),
    }
    head, summary_label, direction = heads.get(lang, ("AI engineer", "Profile", "ltr"))
    body = " ".join([head] * 40)
    return {
        "schema": "career.document.v1", "kind": kind, "lang": lang, "dir": direction,
        "locale_name": lang, "area": {"id": "x", "title": "T", "tagline": "t", "accent": "#7C5CFF"},
        "identity": {"name": "Miloš Vasić", "headline": head, "location": "Beograd",
                     "contact": [{"kind": "url", "label": "gitlab.com/milos85vasic",
                                  "href": "https://gitlab.com/milos85vasic"}]},
        "labels": {"label.summary": summary_label, "label.competencies": "c", "label.experience": "e",
                   "label.projects": "p", "label.skills": "s", "label.education": "d",
                   "label.publications": "u", "label.languages": "l", "label.keywords": "k",
                   "label.cover.date": "d", "label.cover.regards": "r"},
        "templates": {}, "summary": [body], "competencies": [], "skills": [], "experience": [],
        "projects": [], "education": [], "publications": [], "languages": [], "metrics": [],
        "ats": {"title": "Miloš Vasić", "keywords": ["k"]},
        "meta": {"version": "2", "model_hash": "0", "date": "d", "epoch": 1700000000},
        "cover": {"subject": "s", "salutation": "x", "paragraphs": [], "regards": "r"},
    }


class GateUnits(unittest.TestCase):
    def test_cjk_fullwidth_punctuation_is_content_not_poison(self):
        self.assertEqual(gates._check_no_artifacts("概要（AI）：本文", "ja"), [])

    def test_fullwidth_punctuation_still_flagged_outside_cjk(self):
        self.assertTrue(gates._check_no_artifacts("a（b）", "en"))

    def test_fullwidth_digits_flagged_even_in_cjk(self):
        self.assertTrue(gates._check_no_artifacts("経験１７年", "ja"))

    def test_arabic_presentation_forms_flagged(self):
        p = gates._check_no_artifacts("ﺍﻟ", "ar")
        self.assertTrue(any("presentation" in x for x in p), p)

    def test_strip_bidi_controls(self):
        self.assertEqual(gates._strip_bidi_controls("‫مرحبا‬ x‪"), "مرحبا x")

    def test_script_coverage_catches_latin_fallback(self):
        self.assertTrue(gates._check_script_coverage("Latin only " * 50, "hi"))
        self.assertEqual(gates._check_script_coverage("क" * 300, "hi"), [])
        self.assertEqual(gates._check_script_coverage("anything", "en"), [])

    def test_phrase_must_be_contiguous_logical(self):
        good = "مهندس ذكاء اصطناعي — LLM"
        reversed_ = "اعانطصا ءاكذ سدنهم"
        self.assertEqual(gates._check_phrases([good], ["مهندس ذكاء اصطناعي"]), [])
        self.assertTrue(gates._check_phrases([reversed_], ["مهندس ذكاء اصطناعي"]))

    def test_phrase_survives_line_wrap_whitespace(self):
        self.assertEqual(gates._check_phrases(["مهندس ذكاء\n   اصطناعي"], ["مهندس ذكاء اصطناعي"]), [])

    def test_cjk_wrap_inside_word_still_matches_but_reorder_does_not(self):
        self.assertEqual(gates._check_phrases(["ガバナ\nンスを"], ["ガバナンス"]), [])
        self.assertTrue(gates._check_phrases(["スンナバガ"], ["ガバナンス"]))

    def _bbox(self, rows):
        words = "".join(f'<word xMin="{x0}" yMin="{y0}" xMax="{x1}" yMax="{y1}">w</word>'
                        for y0, y1, spans in rows for x0, x1 in spans)
        return f'<page width="595" height="842">{words}</page>'

    def test_mixed_font_line_is_not_a_gutter(self):
        # One visual line: CJK boxes span y 162-177, Latin boxes y 166-176 (measured on
        # zh/ja covers).  Integer-yMin grouping split it in two, each half with a
        # ~120 pt hole in the central band -> false "multi-column".
        rows = []
        for i in range(10):
            y = 100 + i * 15
            rows += [(y, y + 15, [(74, 96), (215, 226), (295, 405)]),
                     (y + 4, y + 14, [(98, 212), (229, 293), (406, 520)])]
        self.assertEqual(gates._gutter_pages(self._bbox(rows)), [])

    def test_real_two_column_still_detected(self):
        rows = [(100 + i * 14, 112 + i * 14, [(70, 270), (330, 520)]) for i in range(10)]
        self.assertEqual(gates._gutter_pages(self._bbox(rows)), [1])

    def test_infer_lang_from_sibling_source(self):
        with tempfile.TemporaryDirectory() as d:
            d = Path(d)
            (d / "cv-x-hi.tex").write_text("% m\n% model_hash=1 lang=hi area=x\n", encoding="utf-8")
            (d / "cv-x-hi.pdf").write_bytes(b"")
            self.assertEqual(gates._infer_lang(d / "cv-x-hi.pdf"), "hi")
            (d / "cv-x-ar.html").write_text('<!doctype html>\n<html lang="ar" dir="rtl">', encoding="utf-8")
            self.assertEqual(gates._infer_lang(d / "cv-x-ar.pdf"), "ar")

    def test_html_sibling_urls_read(self):
        with tempfile.TemporaryDirectory() as d:
            d = Path(d)
            (d / "a.html").write_text('<span class="u"><a href="https://x">gitlab.com/milos85vasic</a></span>',
                                      encoding="utf-8")
            self.assertEqual(gates._tex_contact_urls(d / "a.tex"), ["gitlab.com/milos85vasic"])


class BuildLib(unittest.TestCase):
    def test_second_lock_fails_fast(self):
        with tempfile.TemporaryDirectory() as d:
            with buildlib.build_lock(Path(d)):
                with self.assertRaises(buildlib.BuildLocked):
                    with buildlib.build_lock(Path(d)):
                        pass
            with buildlib.build_lock(Path(d)):  # released on exit
                pass

    def test_lock_released_when_holder_dies(self):
        with tempfile.TemporaryDirectory() as d:
            pid = os.fork()
            if pid == 0:
                with buildlib.build_lock(Path(d)):
                    os._exit(0)  # dies holding it
            os.waitpid(pid, 0)
            with buildlib.build_lock(Path(d)):
                pass

    def test_jobs_capped_by_memory_and_bounds(self):
        self.assertEqual(buildlib.effective_jobs(4, avail_mib=7000), 1)
        self.assertEqual(buildlib.effective_jobs(4, avail_mib=64000), 4)
        self.assertEqual(buildlib.effective_jobs(50, avail_mib=64000), buildlib.MAX_JOBS)
        self.assertEqual(buildlib.effective_jobs(0, avail_mib=64000), 1)
        self.assertEqual(buildlib.effective_jobs(3, avail_mib=0), 1)

    def test_matrix_and_expected_files(self):
        from career.catalog import LOCALES
        areas = [f"a{i}" for i in range(10)]
        t = buildlib.matrix(areas, LOCALES)
        self.assertEqual(len(t), 300)
        names = buildlib.expected_files(t, render.source_suffix)
        self.assertEqual(len(names), 600)
        self.assertEqual(sum(n.endswith(".pdf") for n in names), 300)
        self.assertIn("cv-a0-ar.html", names)
        self.assertIn("cover-a9-ja.tex", names)
        self.assertNotIn("cv-a0-ar.tex", names)
        self.assertEqual(len(buildlib.matrix(areas, LOCALES, area="a1", lang="hi")), 2)

    def test_manifest_is_deterministic_and_sorted(self):
        with tempfile.TemporaryDirectory() as d:
            d = Path(d)
            (d / "b.pdf").write_bytes(b"B")
            (d / "a.pdf").write_bytes(b"A")
            m1 = buildlib.manifest_bytes(d, ["b.pdf", "a.pdf"], 5)
            m2 = buildlib.manifest_bytes(d, ["a.pdf", "b.pdf"], 5)
            self.assertEqual(m1, m2)
            self.assertIn(hashlib.sha256(b"A").hexdigest().encode(), m1)
            self.assertLess(m1.index(b"a.pdf"), m1.index(b"b.pdf"))
            (d / "a.pdf").write_bytes(b"changed")
            self.assertNotEqual(buildlib.manifest_bytes(d, ["a.pdf", "b.pdf"], 5), m1)

    def test_unexpected_files_detected(self):
        with tempfile.TemporaryDirectory() as d:
            d = Path(d)
            for n in ("cv-a-ar.tex", "cv-a-ar.html", "cv-a-ar.pdf", "notes.txt", "manifest.json"):
                (d / n).write_text("x")
            self.assertEqual(buildlib.unexpected_files(d, ["cv-a-ar.html", "cv-a-ar.pdf"]), ["cv-a-ar.tex"])

    def test_key_phrases_use_headline_pure_run(self):
        doc = _doc("ar")
        doc["identity"]["headline"] = "مهندس ذكاء اصطناعي — LLM والوكلاء"
        doc["summary"] = ["x"]
        ph = buildlib.key_phrases(doc)
        self.assertIn("Miloš Vasić", ph)
        self.assertIn("ملخص", ph)
        self.assertIn("مهندس ذكاء اصطناعي", ph)

    def test_atomic_manifest_write_leaves_no_temp(self):
        with tempfile.TemporaryDirectory() as d:
            d = Path(d)
            (d / "a.pdf").write_bytes(b"A")
            buildlib.write_manifest(d, ["a.pdf"], 1)
            self.assertEqual(sorted(p.name for p in d.iterdir()), ["a.pdf", "manifest.json"])


class RenderRegistry(unittest.TestCase):
    def test_engine_for_is_live_and_honest(self):
        self.assertEqual(render.engine_for("ar"), "html")
        self.assertEqual(render.engine_for("fa"), "html")
        for l in ("en", "ja", "zh", "ko", "hi", "ru", "tr"):
            self.assertEqual(render.engine_for(l), "latex")
        self.assertEqual(render.source_suffix("ar"), "html")
        self.assertEqual(render.source_suffix("hi"), "tex")

    def test_formats_only_claim_what_is_produced(self):
        produced = {s for fmts in render.ENGINE_FORMATS.values() for s in fmts}
        self.assertEqual(set(render.FORMATS), produced)
        for dead in ("md", "docx", "json"):
            self.assertNotIn(dead, render.FORMATS)

    def test_build_dispatches_by_engine(self):
        with mock.patch("career.render.html.build", return_value={"html": 1}) as h, \
             mock.patch("career.render.latex.build", return_value={"tex": 1}) as l:
            render.build(_doc("ar"), Path("."), "s", epoch=1)
            render.build(_doc("ja"), Path("."), "s", epoch=1)
        self.assertEqual((h.call_count, l.call_count), (1, 1))

    def test_missing_character_log_parsed(self):
        log = 'Missing character: There is no व (U+0935) in font [NotoSans-Regular.ttf]:mode\n'
        self.assertEqual(latex.missing_characters(log), {0x935})
        self.assertEqual(latex.missing_characters("all fine"), set())


class FontPreflight(unittest.TestCase):
    def test_absent_family_is_rc2_not_silent_tofu(self):
        have = frozenset({"Noto Sans", "DejaVu Sans", "DejaVu Sans Mono"})
        with self.assertRaises(fonts.FontMissing) as cm:
            fonts.require_fonts("ja", have)
        self.assertIn("Noto Sans CJK JP", str(cm.exception))
        fonts.require_fonts("en", have)  # Latin needs only the base

    def test_every_non_latin_locale_declares_its_family(self):
        for lang in ("hi", "ja", "zh", "ko", "ar", "fa"):
            self.assertTrue(fonts.EXTRA[lang])


@unittest.skipUnless(HAVE_TEX, "lualatex/pdftotext not installed")
class RealLatexScripts(unittest.TestCase):
    """The ja/zh/ko/hi defect, on real compiled PDFs."""

    def _build(self, lang):
        d = Path(tempfile.mkdtemp(prefix="pp-"))
        self.addCleanup(shutil.rmtree, d, True)
        try:
            paths = latex.build(_doc(lang), d, f"cv-x-{lang}", epoch=1700000000)
        except fonts.FontMissing as e:
            self.skipTest(str(e))
        return paths

    def _check(self, lang, needle):
        p = self._build(lang)
        text = gates._extract(p["pdf"])
        self.assertNotIn("�", text, "tofu in text layer")
        self.assertIn(needle, text)
        rc, msg = gates.validate_pdf(p["pdf"], "cv", lang, ["Miloš Vasić", needle])
        self.assertEqual(rc, 0, msg)

    def test_japanese(self):
        self._check("ja", "AIエンジニア")

    def test_chinese(self):
        self._check("zh", "AI工程师")

    def test_korean(self):
        self._check("ko", "엔지니어")

    def test_hindi(self):
        self._check("hi", "इंजीनियर")

    def test_cjk_font_actually_embedded(self):
        import subprocess
        p = self._build("ja")
        out = subprocess.run(["pdffonts", str(p["pdf"])], capture_output=True, text=True).stdout
        self.assertIn("NotoSansCJK", out)

    def test_latex_rebuild_is_byte_identical(self):
        a, b = self._build("hi"), self._build("hi")
        self.assertEqual(hashlib.sha256(a["pdf"].read_bytes()).hexdigest(),
                         hashlib.sha256(b["pdf"].read_bytes()).hexdigest())

    def test_atomic_no_temp_left(self):
        p = self._build("en")
        left = [x.name for x in p["pdf"].parent.iterdir() if x.name.endswith(".tmp")]
        self.assertEqual(left, [])


@unittest.skipUnless(HAVE_RTL, "weasyprint/pdftotext/Noto Naskh Arabic not available")
class RealRtl(unittest.TestCase):
    def _build(self, lang):
        d = Path(tempfile.mkdtemp(prefix="pp-"))
        self.addCleanup(shutil.rmtree, d, True)
        return render.build(_doc(lang), d, f"cv-x-{lang}", epoch=1700000000)

    def test_arabic_logical_order_no_controls_no_presentation_forms(self):
        p = self._build("ar")
        raw = gates._extract_independent(p["pdf"])
        self.assertIsNotNone(raw)
        self.assertFalse({c for c in raw if ord(c) in gates._BIDI_CONTROLS})
        self.assertFalse([c for c in raw if 0xFB50 <= ord(c) <= 0xFEFF], "presentation forms")
        self.assertIn("مهندس ذكاء اصطناعي", gates._norm(raw))
        rc, msg = gates.validate_pdf(p["pdf"], "cv", "ar",
                                     ["Miloš Vasić", "ملخص", "مهندس ذكاء اصطناعي"])
        self.assertEqual(rc, 0, msg)

    def test_persian_passes(self):
        p = self._build("fa")
        rc, msg = gates.validate_pdf(p["pdf"], "cv", "fa", ["Miloš Vasić", "مهندس هوش مصنوعی"])
        self.assertEqual(rc, 0, msg)

    def test_reversed_text_would_fail_phrase_gate(self):
        p = self._build("ar")
        rc, msg = gates.validate_pdf(p["pdf"], "cv", "ar", ["اعانطصا ءاكذ سدنهم"])
        self.assertEqual(rc, 1)
        self.assertIn("logical order", msg)

    def test_rtl_rebuild_byte_identical_and_url_intact(self):
        a, b = self._build("ar"), self._build("ar")
        self.assertEqual(a["pdf"].read_bytes(), b["pdf"].read_bytes())
        self.assertIn("gitlab.com/milos85vasic", gates._extract(a["pdf"]))


class GateHardening(unittest.TestCase):
    """Review round 2: narrower CJK exemption, wider poison classes."""

    def test_real_cjk_punctuation_passes_zh_ja(self):
        # Every fullwidth mark that appears in the built ja/zh PDFs.
        txt = "概要（AI）：ネイティブ／クロス＋本文，要点；注意！何？"
        for lang in ("zh", "ja"):
            self.assertEqual(gates._check_no_artifacts(txt, lang), [], lang)

    def test_email_and_url_breakers_rejected_in_every_cjk_locale(self):
        for lang in ("zh", "ja", "ko"):
            for ch in "\uff20\uff0e\uff3c":
                p = gates._check_no_artifacts(f"i{ch}mvasic", lang)
                self.assertTrue(p, f"U+{ord(ch):04X} must be rejected in {lang}")

    def test_fullwidth_url_scheme_rejected(self):
        self.assertTrue(gates._check_no_artifacts("http：／／milosvasic", "ja"))
        self.assertTrue(gates._check_no_artifacts("a／／b", "zh"))

    def test_korean_ascii_punct_passes_fullwidth_at_rejected(self):
        self.assertEqual(gates._check_no_artifacts("프로필 (AI): 본문, 요점; 끝!", "ko"), [])
        self.assertTrue(gates._check_no_artifacts("i＠mvasic.ru", "ko"))

    def test_each_poison_class_detected(self):
        for cp in (0xE000, 0xF8FF, 0xF0B7, 0x200B, 0x00AD, 0xFB05, 0xFB06, 0x01, 0x08, 0x0B,
                   0x1F, 0x7F, 0x85, 0x9F):
            p = gates._check_no_artifacts("a" + chr(cp) + "b", "en")
            self.assertTrue(p, f"U+{cp:04X} must be flagged")

    def test_legitimate_controls_still_allowed(self):
        txt = "a\u200cb\u200dc\u200ed\u200fe\nf\tg\x0ch"
        self.assertEqual(gates._check_no_artifacts(txt, "fa"), [])

    def test_cyrillic_locales_need_cyrillic(self):
        for lang in ("ru", "be", "kk", "sr"):
            self.assertTrue(gates._check_script_coverage("latin " * 100, lang), lang)
            self.assertEqual(gates._check_script_coverage("Привіт " * 100, lang), [], lang)

    def test_empty_contact_list_fails(self):
        self.assertTrue(gates._check_contact_urls("anything", []))
        self.assertTrue(gates._check_contact_urls("anything", ["", ""]))

    def test_expected_contacts_from_doc_override_source(self):
        with tempfile.TemporaryDirectory() as d:
            pdf = Path(d) / "cv-x-en.pdf"
            tex = pdf.with_suffix(".tex")
            tex.write_text(r"\href{https://a.com}{a.com}", encoding="utf-8")
            got = gates._expected_contacts(pdf, ["i@mvasic.ru", "a.com"])
            self.assertIn("i@mvasic.ru", got)
            # the sibling source yields the VISIBLE label (what the text layer
            # carries); the \href target is judged by the link-annotation gate
            self.assertEqual(gates._expected_contacts(pdf, None), ["a.com"])


class BuildFreshness(unittest.TestCase):
    def test_lock_fd_cloexec_and_closed_in_forked_child(self):
        with tempfile.TemporaryDirectory() as d:
            with buildlib.build_lock(Path(d)) as path:
                fds = [int(n) for n in os.listdir("/proc/self/fd")
                       if os.path.exists(f"/proc/self/fd/{n}")
                       and os.path.realpath(f"/proc/self/fd/{n}") == os.path.realpath(path)]
                self.assertTrue(fds)
                import fcntl
                for fd in fds:
                    self.assertTrue(fcntl.fcntl(fd, fcntl.F_GETFD) & fcntl.FD_CLOEXEC)
                pid = os.fork()
                if pid == 0:
                    code = 1
                    for fd in fds:
                        try:
                            os.fstat(fd)
                        except OSError:
                            code = 0
                    os._exit(code)
                _, st = os.waitpid(pid, 0)
                self.assertEqual(os.WEXITSTATUS(st), 0, "child inherited the lock fd")

    def test_latex_failed_rebuild_leaves_no_stale_artifacts(self):
        with tempfile.TemporaryDirectory() as d:
            d = Path(d)
            (d / "cv-x-en.pdf").write_bytes(b"%PDF-old")
            (d / "cv-x-en.tex").write_text("old", encoding="utf-8")
            with mock.patch.object(latex, "compile_pdf", side_effect=fonts.FontMissing("x")):
                with self.assertRaises(fonts.FontMissing):
                    latex.build(_doc("en"), d, "cv-x-en", epoch=1700000000)
            self.assertFalse((d / "cv-x-en.pdf").exists(), "stale PDF survived a failed rebuild")
            self.assertNotEqual((d / "cv-x-en.tex").read_text(encoding="utf-8") if (d / "cv-x-en.tex").exists() else "", "old")

    def test_html_failed_rebuild_leaves_no_stale_artifacts(self):
        from career.render import html
        with tempfile.TemporaryDirectory() as d:
            d = Path(d)
            (d / "cv-x-ar.pdf").write_bytes(b"%PDF-old")
            (d / "cv-x-ar.html").write_text("old", encoding="utf-8")
            with mock.patch.object(html, "compile_pdf", side_effect=fonts.FontMissing("x")):
                with self.assertRaises(fonts.FontMissing):
                    html.build(_doc("ar"), d, "cv-x-ar", epoch=1700000000)
            self.assertFalse((d / "cv-x-ar.pdf").exists())
            self.assertFalse((d / "cv-x-ar.html").exists())

    def test_source_model_hash_parsed_from_tex_and_html(self):
        with tempfile.TemporaryDirectory() as d:
            d = Path(d)
            (d / "a.tex").write_text("% x\n% model_hash=abc123 lang=en area=x\n", encoding="utf-8")
            (d / "b.html").write_text('<html><head><meta name="model-hash" content="def456"></head>', encoding="utf-8")
            self.assertEqual(buildlib.source_model_hash(d / "a.tex"), "abc123")
            self.assertEqual(buildlib.source_model_hash(d / "b.html"), "def456")
            self.assertIsNone(buildlib.source_model_hash(d / "none.tex"))

    def test_html_source_carries_model_hash(self):
        from career.render import html
        doc = _doc("ar")
        doc["meta"]["model_hash"] = "feedbeef"
        self.assertIn("feedbeef", html.render_document(doc))

    def test_lock_state_probe(self):
        with tempfile.TemporaryDirectory() as d:
            self.assertFalse(buildlib.build_in_progress(Path(d)))
            with buildlib.build_lock(Path(d)):
                self.assertTrue(buildlib.build_in_progress(Path(d)))
            self.assertFalse(buildlib.build_in_progress(Path(d)))


class CareerCli(unittest.TestCase):
    def setUp(self):
        from career import career as cli
        self.cli = cli

    def test_epoch_pinned_wins_then_env_then_git(self):
        ns = mock.Mock(epoch=5)
        self.assertEqual(self.cli._epoch(ns), 5)
        with mock.patch.dict(os.environ, {"SOURCE_DATE_EPOCH": "77"}):
            self.assertEqual(self.cli._epoch(mock.Mock(epoch=None)), 77)
        with mock.patch.dict(os.environ, {}, clear=False):
            os.environ.pop("SOURCE_DATE_EPOCH", None)
            with mock.patch.object(self.cli, "_git_commit_epoch", return_value=1234):
                self.assertEqual(self.cli._epoch(mock.Mock(epoch=None)), 1234)

    def test_epoch_never_wall_clock(self):
        with mock.patch.dict(os.environ, {}, clear=False):
            os.environ.pop("SOURCE_DATE_EPOCH", None)
            with mock.patch.object(self.cli, "_git_commit_epoch", return_value=None):
                with self.assertRaises(SystemExit) as e:
                    self.cli._epoch(mock.Mock(epoch=None))
                self.assertEqual(e.exception.code, 2)

    def _run_build(self, results, **argv):
        outdir = Path(tempfile.mkdtemp(prefix="cb-"))
        self.addCleanup(shutil.rmtree, outdir, True)
        args = mock.Mock(area=argv.get("area"), lang=argv.get("lang"), kind=argv.get("kind"),
                         epoch=1700000000, jobs=1)
        with mock.patch.object(self.cli, "_plaintext_dir", return_value=outdir), \
                mock.patch.object(self.cli.buildlib, "run_pool", return_value=results), \
                mock.patch.object(self.cli.overlay_mod, "load_overlay", return_value=None):
            rc = self.cli.cmd_build(args)
        return rc, outdir

    def test_failed_cell_means_no_success_manifest(self):
        rc, outdir = self._run_build([{"stem": "cv-a-en", "lang": "en", "rc": 1, "msg": "boom"}])
        self.assertEqual(rc, 1)
        self.assertFalse((outdir / buildlib.MANIFEST_NAME).exists())

    def test_filtered_build_never_rewrites_manifest(self):
        outdir = Path(tempfile.mkdtemp(prefix="cb-"))
        self.addCleanup(shutil.rmtree, outdir, True)
        (outdir / buildlib.MANIFEST_NAME).write_text("SENTINEL", encoding="utf-8")
        args = mock.Mock(area=None, lang="en", kind=None, epoch=1700000000, jobs=1)
        with mock.patch.object(self.cli, "_plaintext_dir", return_value=outdir), \
                mock.patch.object(self.cli.buildlib, "run_pool",
                                  return_value=[{"stem": "cv-a-en", "lang": "en", "rc": 0, "msg": ""}]), \
                mock.patch.object(self.cli.overlay_mod, "load_overlay", return_value=None):
            self.cli.cmd_build(args)
        self.assertEqual((outdir / buildlib.MANIFEST_NAME).read_text(encoding="utf-8"), "SENTINEL")

    def test_verify_refuses_while_build_running(self):
        outdir = Path(tempfile.mkdtemp(prefix="cv-"))
        self.addCleanup(shutil.rmtree, outdir, True)
        with mock.patch.object(self.cli, "_plaintext_dir", return_value=outdir):
            with buildlib.build_lock(outdir):
                rc = self.cli.cmd_verify(mock.Mock(jobs=1))
        self.assertEqual(rc, 2)

    def test_verify_one_flags_stale_source(self):
        outdir = Path(tempfile.mkdtemp(prefix="cv-"))
        self.addCleanup(shutil.rmtree, outdir, True)
        (outdir / "cv-a-en.pdf").write_bytes(b"x")
        (outdir / "cv-a-en.tex").write_text("% model_hash=OLD lang=en area=a\n", encoding="utf-8")
        doc = _doc("en")
        doc["meta"]["model_hash"] = "NEW"
        with mock.patch.object(self.cli.resolve, "resolve", return_value=doc), \
                mock.patch.object(self.cli, "_worker_model", return_value=None), \
                mock.patch.object(self.cli.overlay_mod, "load_overlay", return_value=None), \
                mock.patch.object(self.cli.gates, "validate_pdf", return_value=(0, "ok")):
            r = self.cli._verify_one(("a", "cv", "en", str(outdir), 1))
        self.assertEqual(r["rc"], 1)
        self.assertIn("stale", r["msg"])


if __name__ == "__main__":
    unittest.main()
