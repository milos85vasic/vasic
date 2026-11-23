#!/usr/bin/env python3
"""Translated competency bullets (``comp.<id>.itemN``) must be catalogued,
validated and resolved for non-English locales.

Run:  python3 -m unittest discover -s _tools/career -p 'test_locale_comp_items.py'

Regression: ``catalog._iter_i18n_nodes`` returned right after yielding a
structured ``{i18n, label}`` competency group, so its nested ``items`` were never
extracted and every ``comp.*.itemN`` translation was rejected as an unknown key.
All work happens in a temp copy; nothing under ``_content`` is touched.
"""
from __future__ import annotations

import shutil
import sys
import tempfile
import unittest
from pathlib import Path

import yaml

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from career import resolve as resolve_mod  # noqa: E402
from career.catalog import extract, load_locale, validate_locale  # noqa: E402
from career.model import load_areas, load_model  # noqa: E402

REPO = Path(__file__).resolve().parents[2]
KEY = "comp.ai.item1"
TRANSLATED = "Mehrere LLM-Anbieter hinter einer Abstraktion, MCP-Werkzeuge, RAG und Vektordatenbanken"


class CompItemLocale(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.tmp, ignore_errors=True)
        dst = self.tmp / "_content" / "career" / "locales"
        dst.mkdir(parents=True)
        shutil.copy(REPO / "_content" / "career" / "locales" / "de.yaml", dst / "de.yaml")
        self.path = dst / "de.yaml"
        self.model = load_model()
        self.catalog = extract(self.model.profile, load_areas())

    def _set(self, value):
        raw = yaml.safe_load(self.path.read_text(encoding="utf-8"))
        raw.setdefault("strings", {})
        if value is None:
            raw["strings"].pop(KEY, None)
        else:
            raw["strings"][KEY] = value
        self.path.write_text(yaml.safe_dump(raw, allow_unicode=True), encoding="utf-8")
        return load_locale("de", self.tmp)

    def test_item_keys_are_in_catalog(self):
        keys = {e.key for e in self.catalog}
        self.assertIn(KEY, keys)
        self.assertTrue(any(k.startswith("comp.") and ".item" in k for k in keys))

    def test_translated_item_validates_and_resolves(self):
        bundle = self._set(TRANSLATED)
        errs = [e for e in validate_locale("de", bundle, self.catalog) if KEY in e]
        self.assertEqual(errs, [])
        doc = resolve_mod.resolve(self.model, "ai-engineering", "de", root=self.tmp, epoch=0)
        items = [i for c in doc["competencies"] if c["id"] == "comp.ai" for i in c["items"]]
        self.assertIn(TRANSLATED, items)

    def test_untranslated_item_still_fails(self):
        en = next(e.en for e in self.catalog if e.key == KEY)
        bundle = self._set(en)
        errs = validate_locale("de", bundle, self.catalog)
        self.assertTrue(any(KEY in e and "identical to the English master" in e for e in errs), errs)

    def test_missing_item_still_fails(self):
        bundle = self._set(None)
        errs = validate_locale("de", bundle, self.catalog)
        self.assertTrue(any(KEY in e and "missing string" in e for e in errs), errs)

    def test_unknown_key_still_rejected(self):
        bundle = self._set(TRANSLATED)
        bundle.strings["comp.ai.item99"] = "x y z"
        errs = validate_locale("de", bundle, self.catalog)
        self.assertTrue(any("unknown string key 'comp.ai.item99'" in e for e in errs), errs)


if __name__ == "__main__":
    unittest.main()
