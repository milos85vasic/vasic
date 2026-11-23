#!/usr/bin/env python3
"""Locale guards: placeholder parity, short-untranslated detection, validated
``identical_ok`` bound to the English text, technology-only bullets.

Run:  python3 -m unittest _tools/career/test_locale_guards.py  (from repo root,
with ``_tools`` importable) -- see test_locale_comp_items.py for the pattern.
All mutation work happens on in-memory bundles; nothing under _content changes.
"""
from __future__ import annotations

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from career import catalog as cat_mod  # noqa: E402
from career.catalog import LOCALES, extract, load_locale, validate_locale  # noqa: E402
from career.model import load_areas, load_model  # noqa: E402

REPO = Path(__file__).resolve().parents[2]
MODEL = load_model()
CATALOG = extract(MODEL.profile, load_areas())
EN = {e.key: e.en for e in CATALOG}


def _sha(text: str) -> str:
    return cat_mod.en_sha(text)


def _bundle(lang="de"):
    b = load_locale(lang, REPO)
    b.strings = dict(b.strings)
    b.identical_ok = copy.deepcopy(b.identical_ok)
    return b


def _errs(b, lang="de"):
    return validate_locale(lang, b, CATALOG)


class PlaceholderParity(unittest.TestCase):
    def test_extra_placeholder_rejected(self):
        b = _bundle()
        b.strings["label.cover.subject"] = "Bewerbung {area}"
        self.assertTrue(any("label.cover.subject" in e and "placeholder" in e for e in _errs(b)))

    def test_missing_placeholder_rejected(self):
        b = _bundle()
        b.strings["tmpl.cl.subject"] = "Bewerbung"
        self.assertTrue(any("tmpl.cl.subject" in e and "placeholder" in e for e in _errs(b)))

    def test_unknown_or_positional_brace_rejected(self):
        for bad in ("Bewerbung — {unknown}", "Bewerbung — {}", "Bewerbung — {0}", "Bewerbung — {area"):
            b = _bundle()
            b.strings["tmpl.cl.subject"] = bad
            self.assertTrue(any("tmpl.cl.subject" in e and "placeholder" in e for e in _errs(b)), bad)

    def test_matching_placeholders_pass(self):
        b = _bundle()
        b.strings["tmpl.cl.subject"] = "Bewerbung — {area}"
        self.assertFalse([e for e in _errs(b) if "tmpl.cl.subject" in e])

    def test_every_shipped_template_formats(self):
        for lang in LOCALES[1:]:
            b = load_locale(lang, REPO)
            for key in ("tmpl.cv.title", "tmpl.cl.title", "tmpl.cl.subject",
                        "tmpl.cl.project", "tmpl.cl.emphasis", "tmpl.cv.tech", "tmpl.cv.keywords"):
                b.strings[key].format(name="n", area="a", blurb="b", tech="t", list="l")


class IdenticalOk(unittest.TestCase):
    KEY = "area.flutter.title"

    def _identical(self, reason="canonical product name", sha=None):
        b = _bundle()
        b.strings[self.KEY] = EN[self.KEY]
        b.identical_ok = {self.KEY: {"reason": reason, "en_sha": sha or _sha(EN[self.KEY])}}
        return b

    def test_valid_entry_passes(self):
        self.assertFalse([e for e in _errs(self._identical()) if self.KEY in e])

    def test_short_identical_without_entry_fails(self):
        b = self._identical()
        b.identical_ok = {}
        self.assertTrue(any(self.KEY in e and "identical" in e for e in _errs(b)))

    def test_empty_reason_rejected(self):
        for reason in ("", "   "):
            self.assertTrue(any("identical_ok" in e and "reason" in e
                                for e in _errs(self._identical(reason=reason))))

    def test_stale_sha_rejected(self):
        self.assertTrue(any("identical_ok" in e and "changed" in e
                            for e in _errs(self._identical(sha="0" * 16))))

    def test_legacy_string_form_rejected(self):
        b = self._identical()
        b.identical_ok = {self.KEY: {"reason": "legacy", "en_sha": ""}}
        self.assertTrue(any("identical_ok" in e and "en_sha" in e for e in _errs(b)))

    def test_unknown_key_rejected(self):
        b = self._identical()
        b.identical_ok["no.such.key"] = {"reason": "x", "en_sha": "0" * 16}
        self.assertTrue(any("identical_ok" in e and "no.such.key" in e for e in _errs(b)))

    def test_entry_for_translated_value_rejected(self):
        b = self._identical()
        b.strings[self.KEY] = "Etwas anderes"
        self.assertTrue(any("identical_ok" in e and self.KEY in e and "differs" in e for e in _errs(b)))

    def test_prose_bullet_cannot_hide_behind_identical_ok(self):
        key = "comp.ai.item1"
        b = _bundle()
        b.strings[key] = EN[key]
        b.identical_ok = {key: {"reason": "names", "en_sha": _sha(EN[key])}}
        self.assertTrue(any(key in e and "technology names" in e for e in _errs(b)))

    def test_tech_only_bullet_passes_and_prose_variant_fails(self):
        key = "comp.backend.item1"
        b = _bundle()
        b.strings[key] = EN[key]
        b.identical_ok = {key: {"reason": "names", "en_sha": _sha(EN[key])}}
        self.assertFalse([e for e in _errs(b) if key in e])
        self.assertFalse(cat_mod.is_tech_only("Go (Gin) and some prose words"))
        self.assertTrue(cat_mod.is_tech_only("Go (Gin), gRPC + Protobuf"))


class ShippedLocales(unittest.TestCase):
    def test_all_locales_valid(self):
        for lang in LOCALES[1:]:
            self.assertEqual(validate_locale(lang, load_locale(lang, REPO), CATALOG), [], lang)


if __name__ == "__main__":
    unittest.main()
