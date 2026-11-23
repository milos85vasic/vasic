#!/usr/bin/env python3
"""Tests for the localized expertise pages (10 areas x 15 locales).

Run:  python3 -m unittest discover -s _tools/career -p 'test_expertise_localized.py'
Requires the pages to be generated (``python3 _tools/career/expertise_pages.py``).
"""
from __future__ import annotations

import re
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from career import expertise_pages as ep, model  # noqa: E402
from career.catalog import LOCALES  # noqa: E402

SITE = ep.SITE
AREAS = [a.id for a in sorted(model.load_model().areas, key=lambda a: a.order)]
OVERLAYS = [l for l in LOCALES if l != "en"]


def fm(path: Path) -> dict[str, str]:
    text = path.read_text(encoding="utf-8")
    block = text.split("---", 2)[1]
    return dict(re.findall(r'^(\w+): "(.*)"$', block, re.M))


def _localized():
    import json
    return json.loads((SITE / "expertise_localized.json").read_text(encoding="utf-8"))


class LocalizedPages(unittest.TestCase):
    def test_counts(self):
        self.assertEqual(len(AREAS), 10)
        self.assertEqual(len(LOCALES), 15)

    def test_every_page_exists(self):
        missing = [f"{a}/{l}" for a in AREAS for l in OVERLAYS
                   if not (SITE / "expertise" / a / l / "index.html").is_file()]
        self.assertEqual(missing, [])

    def test_hreflang_15_plus_xdefault_and_reciprocal(self):
        for a in AREAS:
            for l in LOCALES:
                p = SITE / "expertise" / a / ("" if l == "en" else l) / "index.html"
                links = re.findall(r'hreflang=\\"([\w-]+)\\" href=\\"([^"\\]+)\\"',
                                   p.read_text(encoding="utf-8").split("---", 2)[1])
                self.assertEqual(len(links), 16, p)
                self.assertEqual(sorted(k for k, _ in links), sorted(list(LOCALES) + ["x-default"]), p)
                d = dict(links)
                self.assertEqual(d["x-default"], f"{ep.SITE_URL}/expertise/{a}/")
                self.assertEqual(d["en"], f"{ep.SITE_URL}/expertise/{a}/")
                if l != "en":
                    self.assertEqual(d[l], f"{ep.SITE_URL}/expertise/{a}/{l}/")  # self-reference

    def test_direction_and_lang(self):
        for a in AREAS:
            for l in OVERLAYS:
                f = fm(SITE / "expertise" / a / l / "index.html")
                self.assertEqual(f["lang"], l)
                self.assertEqual(f["dir"], "rtl" if l in ("ar", "fa") else "ltr", f"{a}/{l}")

    def test_headings_localized_not_english(self):
        for l in OVERLAYS:
            html = (SITE / "expertise" / "go" / l / "index.html").read_text(encoding="utf-8")
            self.assertNotIn("<h2>Experience</h2>", html, l)
            self.assertNotIn("<h2>Overview</h2>", html, l)
            self.assertNotIn("Narrow the angle", html, l)

    def test_titles_localized_for_non_latin_locales(self):
        """h1 and <title> must be localized in non-Latin-script locales; only
        proper-noun technology names may stay Latin-only."""
        tech_names = {"android-aosp", "android-tv", "flutter", "react-native"}
        bad = []
        for a in AREAS:
            if a in tech_names:
                continue
            for l in ("ar", "be", "fa", "hi", "ja", "kk", "ko", "ru", "zh"):
                html = (SITE / "expertise" / a / l / "index.html").read_text(encoding="utf-8")
                h1 = re.search(r'<h1[^>]*>(.*?)</h1>', html, re.S).group(1)
                title = re.search(r'^title: "(.*)"', html, re.M).group(1)
                for what, text in (("h1", h1), ("title", title.split(" — ")[0])):
                    if not re.search(r"[^\x00-\x7f]", text):
                        bad.append(f"{a}/{l} {what}={text!r}")
        self.assertEqual(bad, [])

    def test_jsonld_localized_url(self):
        html = (SITE / "expertise" / "go" / "de" / "index.html").read_text(encoding="utf-8")
        self.assertIn('"url": "https://milosvasic.ru/expertise/go/de/"', html)
        self.assertIn('"inLanguage": "de"', html)

    def test_translated_body_has_locale_lang_not_english_fallback(self):
        """Every overlay locale ships a translated narrative (expertise_localized.json):
        the page lang is the locale and the body carries no lang="en" fallback marker."""
        for a in AREAS:
            for l in OVERLAYS:
                p = SITE / "expertise" / a / l / "index.html"
                self.assertEqual(fm(p)["lang"], l, p)
                body = p.read_text(encoding="utf-8").split("---", 2)[2]
                self.assertNotIn('lang="en" dir="ltr"', body, p)

    def test_expertise_url_list(self):
        # sitemap.xml itself is written only by the Go generator.
        urls = ep.sitemap_expertise_urls(AREAS)
        self.assertEqual(len(urls), 1 + 10 + 14 + 140)
        self.assertEqual(len(set(urls)), len(urls))
        self.assertFalse(hasattr(ep, "update_sitemap"))


def _blocks(html: str) -> list[dict]:
    import json
    return [json.loads(b) for b in re.findall(r'<script type="application/ld\+json">(.*?)</script>', html, re.S)]


class MetadataAndStructuredData(unittest.TestCase):
    """Audit site-seo-i18n: localized pages must not carry English metadata,
    hubs need their own JSON-LD, and no literal placeholder may reach a page."""

    ENGLISH_META = ("Verified career", "Expertise \u2014", "Each area links")

    def test_localized_meta_has_no_english_template(self):
        bad = []
        paths = [SITE / "expertise" / l / "index.html" for l in OVERLAYS]
        paths += [SITE / "expertise" / a / l / "index.html" for a in AREAS for l in OVERLAYS]
        for p in paths:
            f = fm(p)
            lang = p.parent.name
            hub_title = (_localized().get(lang, {}).get("_hub") or {}).get("title")
            for k in ("title", "description"):
                for e in self.ENGLISH_META:
                    # "Expertise" is also the genuine German/French word: when the
                    # translated hub title IS "Expertise", that marker is not an
                    # English-template leak. All other markers stay enforced.
                    if e.startswith("Expertise") and hub_title == "Expertise":
                        continue
                    if e in f[k]:
                        bad.append(f"{p.relative_to(SITE)} {k}")
        self.assertEqual(bad, [])

    def test_localized_hub_jsonld(self):
        for l in OVERLAYS:
            html = (SITE / "expertise" / l / "index.html").read_text(encoding="utf-8")
            blocks = _blocks(html)
            self.assertEqual(len(blocks), 1, l)
            b = blocks[0]
            self.assertEqual(b["@type"], "ProfilePage")
            self.assertEqual(b["inLanguage"], l)
            self.assertEqual(b["url"], f"{ep.SITE_URL}/expertise/{l}/")
            urls = [o["mainEntityOfPage"]["@id"] for o in b["mainEntity"]["hasOccupation"]]
            self.assertEqual(urls, [f"{ep.SITE_URL}/expertise/{a}/{l}/" for a in AREAS], l)

    def test_en_hub_jsonld_has_language(self):
        b = _blocks((SITE / "expertise" / "index.html").read_text(encoding="utf-8"))[0]
        self.assertEqual(b["inLanguage"], "en")

    def test_jsonld_valid_and_no_self_employer(self):
        for p in SITE.glob("expertise/**/index.html"):
            for b in _blocks(p.read_text(encoding="utf-8")):
                self.assertEqual(b["@context"], "https://schema.org", p)
                self.assertNotIn("worksFor", b["mainEntity"], p)

    def test_hub_hreflang_cluster(self):
        for l in LOCALES:
            p = SITE / "expertise" / ("" if l == "en" else l) / "index.html"
            links = dict(re.findall(r'hreflang=\\"([\w-]+)\\" href=\\"([^"\\]+)\\"',
                                    p.read_text(encoding="utf-8").split("---", 2)[1]))
            self.assertEqual(sorted(links), sorted(list(LOCALES) + ["x-default"]), p)
            if l != "en":
                self.assertEqual(links[l], f"{ep.SITE_URL}/expertise/{l}/")
            self.assertEqual(links["x-default"], f"{ep.SITE_URL}/expertise/")

    def test_no_hreflang_code_mismatch_with_lang(self):
        for p in SITE.glob("expertise/**/index.html"):
            f = fm(p)
            if f["lang"] != "en":
                self.assertIn(f'hreflang=\\"{f["lang"]}\\"', p.read_text(encoding="utf-8"), p)

    def test_english_hero_marked_when_hub_not_translated(self):
        for l in OVERLAYS:
            html = (SITE / "expertise" / l / "index.html").read_text(encoding="utf-8")
            hero = html.split('class="mv-expertise-hero', 1)[1].split("</section>", 1)[0]
            translated = bool((_localized().get(l) or {}).get("_hub"))
            # Marked English exactly when the hub copy is not translated.
            self.assertEqual('lang="en" dir="ltr"' in hero, not translated, l)

    def test_no_unformatted_placeholder_in_bodies(self):
        bad = [str(p.relative_to(SITE)) for p in SITE.glob("expertise/**/index.html")
               if re.search(r"\{(area|year|month)\}", p.read_text(encoding="utf-8").split("---", 2)[2])]
        self.assertEqual(bad, [])

    def test_headings_substitute_area_placeholder(self):
        doc = {"area": {"title": "Go"}, "labels": {"label.cover.subject": "X \u2014 {area}"}}
        self.assertEqual(ep.headings(doc, "zh")["cover"], "X \u2014 Go")


if __name__ == "__main__":
    unittest.main()
