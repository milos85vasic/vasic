#!/usr/bin/env python3
"""Static CSS guard: the expertise block uses logical properties.

No physical left/right properties may remain in the expertise/area block of
the brand CSS, except the intentional exceptions listed below.  Also asserts
the RTL overrides for the back-arrow and tile-arrow exist.  No browser needed.
CSS_UNDER_TEST overrides the file (used to prove the test is red on old CSS).
"""
from __future__ import annotations
import os, re, unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CSS = Path(os.environ.get("CSS_UNDER_TEST") or ROOT / "design-system/brand-milosvasic/milosvasic.css")
START = "(expertise hub + area pages"
PHYS = re.compile(r"(?<![\w-])(margin|padding|border)-(left|right)\s*:|(?<![\w-])(left|right)\s*:"
                  r"|text-align\s*:\s*(left|right)")
# Intentional: RTL text-align overrides, and env(safe-area-inset-*) values.
def _allowed(line: str) -> bool:
    return line.lstrip().startswith('[dir="rtl"]') or "safe-area-inset" in line


def _block() -> list[str]:
    text = CSS.read_text(encoding="utf-8")
    i = text.index(START)
    return text[i:].splitlines()


class ExpertiseCssLogical(unittest.TestCase):
    def test_no_physical_properties(self):
        bad = [l for l in _block() if PHYS.search(l) and not _allowed(l)]
        self.assertEqual(bad, [], "physical left/right in expertise block")

    def test_rtl_arrows_mirrored(self):
        t = "\n".join(_block())
        self.assertRegex(t, r'\[dir="rtl"\] \.mv-area-back:hover::before \{ transform: translateX\(\.25rem\)')
        self.assertRegex(t, r'\[dir="rtl"\] \.mv-expertise-tile__arrow \{ transform: scaleX\(-1\)')
        self.assertRegex(t, r'\[dir="rtl"\] \.mv-expertise-tile:hover \.mv-expertise-tile__arrow \{ transform: translateX\(-\.25rem\) scaleX\(-1\)')

    def test_no_opacity_animation(self):
        for l in _block():
            if "transition" in l:
                self.assertNotIn("opacity", l)


if __name__ == "__main__":
    unittest.main()
