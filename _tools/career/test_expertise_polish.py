#!/usr/bin/env python3
"""Polish tests: PNG og cards, og:locale, Person.sameAs, localized hub hero."""
from __future__ import annotations

import json
import re
import struct
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from career import expertise_pages as ep  # noqa: E402
from career.catalog import LOCALES  # noqa: E402
import yaml  # noqa: E402

PROFILE = Path(__file__).resolve().parents[2] / "_content" / "career" / "profile.yaml"
_files: dict | None = None


def files() -> dict:
    global _files
    if _files is None:
        _files = ep.generate()
    return _files


def fm(text: str) -> dict:
    block = text.split("---", 2)[1]
    return yaml.safe_load(block)


def png_dims(b: bytes):
    assert b[:8] == b"\x89PNG\r\n\x1a\n", "bad magic"
    return struct.unpack(">II", b[16:24])


class PngCards(unittest.TestCase):
    def test_every_card_has_valid_png(self):
        f = files()
        svgs = [k for k in f if k.startswith("assets/og/") and k.endswith(".svg")]
        self.assertEqual(len(svgs), 11)
        for s in svgs:
            png = f[s[:-4] + ".png"]
            self.assertIsInstance(png, bytes)
            self.assertEqual(png_dims(png), (1200, 630), s)
            self.assertLess(len(png), 300 * 1024, s)

    def test_regeneration_byte_identical(self):
        a = {k: v for k, v in ep.generate().items() if k.endswith(".png")}
        b = {k: v for k, v in ep.generate().items() if k.endswith(".png")}
        self.assertEqual(len(a), 11)
        self.assertEqual(a, b)

    def test_pages_point_at_png_with_dimensions(self):
        for rel, text in files().items():
            if not rel.endswith("index.html"):
                continue
            img = fm(text)["image"]
            self.assertIsInstance(img, dict, rel)
            self.assertTrue(img["path"].endswith(".png"), rel)
            self.assertEqual((img["width"], img["height"]), (1200, 630), rel)
            self.assertTrue(img["alt"].strip(), rel)
            self.assertIn(img["path"].lstrip("/"), files(), rel)

    def test_no_renderer_is_rc2(self):
        with mock.patch.object(ep.shutil, "which", return_value=None):
            ep._render_png.cache_clear()
            with self.assertRaises(RuntimeError) as c:
                ep._render_png("<svg xmlns='http://www.w3.org/2000/svg' width='1' height='1'/>")
            self.assertIn("cannot determine", str(c.exception))
        ep._render_png.cache_clear()


class OgLocale(unittest.TestCase):
    EXPECT = {"en": "en_US", "ru": "ru_RU", "de": "de_DE", "es": "es_ES", "fr": "fr_FR",
              "ar": "ar_AR", "fa": "fa_IR", "hi": "hi_IN", "ja": "ja_JP", "ko": "ko_KR",
              "kk": "kk_KZ", "be": "be_BY", "sr": "sr_RS", "tr": "tr_TR", "zh": "zh_CN"}

    def test_map_covers_every_locale_in_territory_form(self):
        self.assertEqual(set(LOCALES), set(self.EXPECT))
        for l in LOCALES:
            self.assertEqual(ep.og_locale(l), self.EXPECT[l])
            self.assertRegex(ep.og_locale(l), r"^[a-z]{2}_[A-Z]{2}$")

    def test_every_page_front_matter(self):
        n = 0
        for rel, text in files().items():
            if not rel.endswith("index.html"):
                continue
            n += 1
            d = fm(text)
            self.assertEqual(d["locale"], self.EXPECT[d["lang"]], rel)
            alts = re.findall(r'og:locale:alternate" content="([^"]+)"', d["seo_og_alternates"])
            self.assertEqual(len(alts), 14, rel)
            self.assertNotIn(d["locale"], alts, rel)
            self.assertNotIn("zh", alts)
        self.assertEqual(n, 165)

    def test_layout_rewrites_seo_tag_locale(self):
        lay = (ep.SITE / "_layouts" / "default.html").read_text(encoding="utf-8")
        self.assertIn("og:locale", lay)
        self.assertIn("zh_CN", lay)
        self.assertIn("seo_og_alternates", lay)
        for v in OgLocale.EXPECT.values():
            self.assertIn(v, lay)


class SameAs(unittest.TestCase):
    def profile_urls(self) -> set[str]:
        ident = yaml.safe_load(PROFILE.read_text(encoding="utf-8"))["identity"]
        out: set[str] = set()
        for v in ident.values():
            for x in (v if isinstance(v, list) else [v]):
                if isinstance(x, str) and x.startswith("https://"):
                    out.add(x)
        return out

    def test_every_page_person_has_sameas_from_profile_only(self):
        allowed = self.profile_urls()
        seen = 0
        for rel, text in files().items():
            if not rel.endswith("index.html"):
                continue
            blocks = re.findall(r'<script type="application/ld\+json">(.*?)</script>', text, re.S)
            for b in blocks:
                j = json.loads(b)
                p = j.get("mainEntity")
                if p and p.get("@type") == "Person":
                    seen += 1
                    self.assertTrue(p["sameAs"], rel)
                    self.assertTrue(set(p["sameAs"]) <= allowed, (rel, set(p["sameAs"]) - allowed))
                    self.assertEqual(len(p["sameAs"]), len(set(p["sameAs"])))
                    self.assertIn("knowsAbout", p)
        self.assertEqual(seen, 165)

    def test_site_urls_not_in_sameas(self):
        for u in ep.same_as():
            self.assertNotIn("milosvasic.ru", u)


class JsonLdAndLayout(unittest.TestCase):
    def test_every_generated_typed_object_has_matching_inlanguage(self):
        hubs = 0
        for rel, text in files().items():
            if not rel.endswith("index.html"):
                continue
            lang = fm(text)["lang"]
            types = []
            for b in re.findall(r'<script type="application/ld\+json">(.*?)</script>', text, re.S):
                j = json.loads(b)
                types.append(j["@type"])
                self.assertEqual(j.get("inLanguage"), lang, rel)
            self.assertIn("ProfilePage", types, rel)
            hubs += rel == "expertise/index.html" or (rel.count("/") == 2 and rel.split("/")[1] in LOCALES)
        self.assertEqual(hubs, 15)

    def test_layout_adds_inlanguage_to_seo_webpage(self):
        lay = (ep.SITE / "_layouts" / "default.html").read_text(encoding="utf-8")
        self.assertIn('"inLanguage":"{{ _pl }}"', lay)

    def test_exactly_one_od_stylesheet_link_in_layout_output_path(self):
        lay = (ep.SITE / "_layouts" / "default.html").read_text(encoding="utf-8")
        head = lay.split("</head>")[0]
        self.assertEqual(len(re.findall(r'<link rel="stylesheet" href="[^"]*assets/od/milosvasic\.css', head)), 1)
        # pages that self-link the bundle: the layout strips that copy from content
        self.assertIn("content | replace: _od_dup", lay)
        for rel in ("index.html", "portfolio/index.html"):
            self.assertEqual((ep.SITE / rel).read_text(encoding="utf-8").count("assets/od/milosvasic.css"), 1, rel)


HUB_KEYS = ("eyebrow", "title", "lede", "stat_label")


class HubI18n(unittest.TestCase):
    def gen_with(self, data: dict) -> dict:
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "loc.json"
            p.write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")
            with mock.patch.object(ep, "LOC_NARRATIVE_PATH", p):
                return ep.generate()

    def test_hub_key_not_treated_as_area(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "l.json"
            p.write_text(json.dumps({"de": {"_hub": {k: "x" for k in HUB_KEYS}, "go": {"story": "s"}}}))
            with mock.patch.object(ep, "LOC_NARRATIVE_PATH", p):
                n = ep._load_loc_narrative()
        self.assertEqual(set(n["de"]), {"go"})

    def test_en_source_defined_in_code(self):
        self.assertEqual(set(ep.HUB_EN), set(HUB_KEYS))
        self.assertTrue(all(isinstance(v, str) and v for v in ep.HUB_EN.values()))

    def test_provided_block_replaces_english_and_drops_marker(self):
        blk = {"eyebrow": "EYE-DE", "title": "Expertise-DE", "lede": "Lede-DE — ", "stat_label": "STAT-DE"}
        f = self.gen_with({"de": {"_hub": blk}})
        de = f["expertise/de/index.html"]
        body = de.split("---", 2)[2]
        for v in ("EYE-DE", "Expertise-DE", "Lede-DE", "STAT-DE"):
            self.assertIn(v, body)
        self.assertNotIn("10 technology areas", body)
        hero = re.search(r'<section class="mv-expertise-hero[^>]*>', body).group(0)
        self.assertNotIn('lang="en"', hero)
        # a language without a block keeps the marker
        fr = f["expertise/fr/index.html"].split("---", 2)[2]
        self.assertIn('lang="en" dir="ltr"', re.search(r'<section class="mv-expertise-hero[^>]*>', fr).group(0))

    def test_incomplete_block_is_an_error(self):
        with self.assertRaises(Exception):
            self.gen_with({"de": {"_hub": {"title": "x"}}})

    def test_real_json_has_no_hub_yet_or_complete(self):
        data = json.loads(ep.LOC_NARRATIVE_PATH.read_text(encoding="utf-8"))
        for lang, blob in data.items():
            if "_hub" in blob:
                self.assertEqual(set(blob["_hub"]), set(HUB_KEYS), lang)


if __name__ == "__main__":
    unittest.main()
