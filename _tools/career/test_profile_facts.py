"""Deterministic guard for operator-decided profile facts (years of experience etc.).

Counts are computed from the tree and the YAML is parsed, so neither a layout
change in profile.yaml nor a new product file can silently falsify a test.
"""
import datetime as dt
import re
import unittest
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[2]
PROFILE = ROOT / "_content/career/profile.yaml"
LOCALES = sorted((ROOT / "_content/career/locales").glob("*.yaml"))

# Eastern Arabic-Indic, Persian, Devanagari and fullwidth digits -> ASCII
_DIGITS = {}
for _base in (0x0660, 0x06F0, 0x0966):
    for _i in range(10):
        _DIGITS[_base + _i] = str(_i)
_DIGITS.update({ord(c): str(i) for i, c in enumerate("０１２３４５６７８９")})
_CJK_UNITS = {"十": 10, "一": 1, "二": 2, "三": 3, "四": 4, "五": 5,
              "六": 6, "七": 7, "八": 8, "九": 9}


def _ascii(s):
    return s.translate(_DIGITS)


def _cjk_numbers(s):
    """CJK numerals 十..十九 / 二十.. found in ``s`` as ints (generic, not 15/16 only)."""
    out = set()
    for m in re.finditer(r"[一二三四五六七八九]?十[一二三四五六七八九]?", s):
        tok = m.group(0)
        tens, _, ones = tok.partition("十")
        out.add((_CJK_UNITS[tens] if tens else 1) * 10 + (_CJK_UNITS[ones] if ones else 0))
    return out


def _prof():
    return yaml.safe_load(PROFILE.read_text(encoding="utf-8"))


def _by_id(items, key):
    return next(x for x in items if x["id"] == key)


def _as_of(profile):
    """The pinned build date, taken from the years metric's own evidence."""
    ev = _by_id(profile["metrics"], "metric.years")["evidence"]
    m = re.search(r"as of (\d{4})-(\d{2})-(\d{2})", ev)
    assert m, f"metric.years evidence names no 'as of YYYY-MM-DD' date: {ev!r}"
    return dt.date(*map(int, m.groups()))


def _earliest_start(profile):
    y, mo = min(tuple(map(int, e["start"].split("-"))) for e in profile["experience"])
    return dt.date(y, mo, 1)


def _summary_body(profile):
    return " ".join(_by_id(profile["summary"], "summary.body")["text"].split())


class ProfileFacts(unittest.TestCase):
    def test_years_floor_from_experience(self):
        """Professional basis: earliest experience start -> pinned date (whole years).
        Engineering-since basis (2009): calendar-year difference. The profile
        claim must be >= the professional floor and <= the 'since' ceiling."""
        p = _prof()
        as_of, start = _as_of(p), _earliest_start(p)
        floor = (as_of - start).days // 365.2425
        floor = int(floor)
        ceiling = as_of.year - p["identity"]["since"]
        claim = p["identity"]["years_experience"]
        self.assertGreaterEqual(claim, floor, f"claims {claim} < floor {floor} from {start}")
        self.assertLessEqual(claim, ceiling, f"claims {claim} > since-basis ceiling {ceiling}")

    def test_metric_years_matches_identity(self):
        p = _prof()
        m = _by_id(p["metrics"], "metric.years")
        self.assertEqual(int(m["value"].rstrip("+")), p["identity"]["years_experience"])
        earliest = min(p["experience"], key=lambda e: e["start"])
        self.assertIn(earliest["start"], m["evidence"])
        self.assertIn(earliest["company"].split()[0], m["evidence"])

    def test_repos_evidence_operator_attested(self):
        m = _by_id(_prof()["metrics"], "metric.repos")
        self.assertEqual(m["value"], "140+")
        self.assertIn("operator-attested", m["evidence"])

    def test_products_count_matches_tree(self):
        files = [f for f in (ROOT / "_content/products").iterdir() if f.is_file()]
        entries = {f.stem for f in files if f.suffix == ".md"}
        ev = _by_id(_prof()["metrics"], "metric.products")
        self.assertEqual(ev["value"], str(len(entries)))
        self.assertIn(f"{len(entries)} product entries ({len(files)} files", ev["evidence"])

    def test_providers_count_matches_tree(self):
        dirs = [d for d in (ROOT / "submodules/LLMProvider/pkg/providers").iterdir() if d.is_dir()]
        ev = _by_id(_prof()["metrics"], "metric.providers")
        self.assertEqual(ev["value"], str(len(dirs)))
        self.assertIn(f"({len(dirs)} directories)", ev["evidence"])

    def test_mailserverfactory_tech(self):
        proj = next(x for x in _prof()["projects"] if x["id"] == "proj.mailserverfactory")
        self.assertNotIn("Go", proj["tech"])
        self.assertIn("Kotlin", proj["tech"])
        self.assertIn("Shell", proj["tech"])

    def test_en_summary(self):
        p = _prof()
        self.assertIn(f"Over {p['identity']['years_experience']} years", _summary_body(p))

    def test_en_cv(self):
        cv = (ROOT / "_content/docs/cv.md").read_text(encoding="utf-8")
        self.assertIn(f"Over {_prof()['identity']['years_experience']} years", cv)

    def test_no_stale_strings(self):
        for f in ("_tools/career/expertise_pages.py", "_content/docs/cv.md"):
            t = (ROOT / f).read_text(encoding="utf-8")
            self.assertNotIn("15+ years", t, f)
            self.assertNotIn("17 years", t, f)
            self.assertNotIn("Over 15 years", t, f)

    def test_locales_years(self):
        years = _prof()["identity"]["years_experience"]
        for f in LOCALES:
            d = yaml.safe_load(f.read_text(encoding="utf-8"))
            body = d["strings"]["summary.body"]
            nums = {int(n) for n in re.findall(r"\d+", _ascii(body)[:80])}
            nums |= _cjk_numbers(body[:20])
            self.assertIn(years, nums, f"{f.name}: {body[:60]}")
            self.assertNotIn(years - 1, nums, f"{f.name}: {body[:60]}")


if __name__ == "__main__":
    unittest.main()
