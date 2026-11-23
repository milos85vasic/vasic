"""Installed-font preflight shared by both PDF engines.

A missing family does not fail loudly: LuaTeX substitutes a face with no glyphs
for the script and emits ``.notdef`` boxes, WeasyPrint falls through to
whatever Pango finds.  Either way the PDF *looks* built and the text layer is
U+FFFD.  So the family list a locale needs is checked against ``fc-list``
BEFORE rendering and a gap is reported as "cannot determine" (exit 2), never
rendered around.
"""

from __future__ import annotations

import shutil
import subprocess
from functools import lru_cache

#: Families each locale's PDF needs, beyond the Latin base that every locale
#: uses.  (The class also names these; this table is what the preflight checks.)
BASE = ("Noto Sans", "DejaVu Sans", "DejaVu Sans Mono")
EXTRA = {
    "hi": ("Noto Sans Devanagari",),
    "ja": ("Noto Sans CJK JP",),
    "zh": ("Noto Sans CJK SC",),
    "ko": ("Noto Sans CJK KR",),
    "ar": ("Noto Naskh Arabic",),
    "fa": ("Noto Naskh Arabic",),
}


class FontMissing(RuntimeError):
    """A needed font family is not installed.  Maps to exit code 2."""


@lru_cache(maxsize=1)
def installed_families() -> frozenset[str]:
    fc = shutil.which("fc-list")
    if fc is None:
        raise FontMissing("fc-list not found: cannot determine installed fonts")
    out = subprocess.run([fc, ":", "family"], capture_output=True, text=True, timeout=60)
    if out.returncode != 0:
        raise FontMissing("fc-list failed: cannot determine installed fonts")
    return frozenset(n.strip() for line in out.stdout.splitlines() for n in line.split(","))


def required_families(lang: str) -> tuple[str, ...]:
    return BASE + EXTRA.get(lang, ())


def missing_families(lang: str, have: frozenset[str] | None = None) -> list[str]:
    have = installed_families() if have is None else have
    return [f for f in required_families(lang) if f not in have]


def require_fonts(lang: str, have: frozenset[str] | None = None) -> None:
    miss = missing_families(lang, have)
    if miss:
        raise FontMissing(f"locale {lang!r} needs font famil{'y' if len(miss) == 1 else 'ies'} "
                          f"not installed: {', '.join(miss)}")
