"""Translation catalog: extract, load, and validate locale overlays.

Every string a reader can see carries a stable key. The English text in
``profile.yaml`` / ``areas/*.yaml`` is the master; ``locales/<lang>.yaml``
overlays it. Extraction is mechanical, so the catalog can never drift from the
content it describes: it is derived from the same files the renderers read.

Validation is deliberately hostile, because a half-translated CV is worse than
an untranslated one -- it reads as carelessness in the reader's own language.
"""

from __future__ import annotations

import hashlib
import re
from functools import lru_cache
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable

import yaml

from .model import Area, Profile, _check_placeholder

LOCALE_SCHEMA = "career.locale.v1"

#: The 15 languages this site publishes in. `en` is the master and has no
#: overlay file of its own -- it is the profile itself.
LOCALES: tuple[str, ...] = (
    "en", "sr", "ru", "de", "es", "fr", "be", "zh",
    "kk", "hi", "ja", "ko", "ar", "tr", "fa",
)

#: Locales written right-to-left. These are rendered through the HTML engine
#: (WeasyPrint) rather than XeLaTeX: see docs/plans/.../PLAN.md for the measured
#: reason -- a LaTeX RTL build produces presentation-form glyphs that no ATS
#: can read.
RTL_LOCALES: frozenset[str] = frozenset({"ar", "fa"})

LANGUAGE_NAMES: dict[str, str] = {
    "en": "English",
    "sr": "Српски",
    "ru": "Русский",
    "de": "Deutsch",
    "es": "Español",
    "fr": "Français",
    "be": "Беларуская",
    "zh": "中文",
    "kk": "Қазақша",
    "hi": "हिन्दी",
    "ja": "日本語",
    "ko": "한국어",
    "ar": "العربية",
    "tr": "Türkçe",
    "fa": "فارسی",
}

# A value identical to the English master is only legitimate when the locale
# says so under ``identical_ok`` -- {key: {reason, en_sha}} -- with a non-empty
# reason and the SHA of the English text it was approved against, so a changed
# master re-opens the decision. No length threshold hides short strings.

_PLACEHOLDER_RE = re.compile(r"\{[^{}]*\}")
_NAMED_PLACEHOLDER_RE = re.compile(r"^\{[a-z_][a-z0-9_]*\}$")
_ITEM_KEY_RE = re.compile(r"\.item\d+$")
_TECH_SPLIT_RE = re.compile(r"[\s,;()+/&·]+")

_KEY_RE = re.compile(r"^[a-z0-9][a-zA-Z0-9._-]*$")


@dataclass(frozen=True)
class CatalogEntry:
    key: str
    en: str
    where: str


@dataclass
class LocaleBundle:
    """A locale resolved against the master, ready for the resolver."""

    lang: str
    dir: str
    name: str
    strings: dict[str, str]
    months: list[str]
    date_month_year: str
    date_range: str
    identical_ok: dict[str, dict[str, str]]

    def t(self, key: str, fallback: str = "") -> str:
        value = self.strings.get(key)
        if value:
            return value
        return fallback


def _iter_i18n_nodes(node: Any, path: str) -> Iterable[tuple[str, str, str]]:
    """Yield ``(key, en_text, where)`` for every translatable value."""

    if isinstance(node, dict):
        # Parallel form: `role` + `role_i18n`.
        for key, value in node.items():
            if key.endswith("_i18n") and isinstance(value, str) and value.strip():
                base = key[: -len("_i18n")]
                text = node.get(base)
                if isinstance(text, str) and text.strip():
                    yield value, text, f"{path}.{base}"
        # Structured form: `{i18n: ..., text: ...}`.
        if isinstance(node.get("i18n"), str):
            text = node.get("text", node.get("label"))
            if isinstance(text, str) and text.strip():
                yield node["i18n"], text, path
        for key, value in node.items():
            if key.endswith("_i18n"):
                continue
            # A structured node may itself own translatable children (a
            # competency group's ``items``); only its own scalars are skipped.
            if isinstance(node.get("i18n"), str) and not isinstance(value, (dict, list)):
                continue
            yield from _iter_i18n_nodes(value, f"{path}.{key}")
    elif isinstance(node, list):
        for index, value in enumerate(node):
            yield from _iter_i18n_nodes(value, f"{path}[{index}]")


def extract(profile: Profile, areas: list[Area]) -> list[CatalogEntry]:
    """Derive the English master catalog. Deterministic ordering."""

    found: dict[str, CatalogEntry] = {}
    for key, text, where in _iter_i18n_nodes(profile.raw, "profile"):
        found.setdefault(key, CatalogEntry(key, text, where))
    for area in areas:
        prefix = f"areas/{area.path.name}"
        for key, text in (
            (area.title_i18n, area.title),
            (area.tagline_i18n, area.tagline),
            (area.cover_opening_i18n, area.cover_opening),
            (area.cover_closing_i18n, area.cover_closing),
        ):
            if key and text:
                found.setdefault(key, CatalogEntry(key, text, prefix))
    return [found[key] for key in sorted(found)]


def locale_dir(lang: str) -> str:
    return "rtl" if lang in RTL_LOCALES else "ltr"


def load_locale(lang: str, root: Path) -> LocaleBundle:
    """Load ``locales/<lang>.yaml``. ``en`` resolves to the master itself."""

    if lang == "en":
        return LocaleBundle(
            lang="en",
            dir="ltr",
            name=LANGUAGE_NAMES["en"],
            strings={},
            months=[
                "Jan", "Feb", "Mar", "Apr", "May", "Jun",
                "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
            ],
            date_month_year="{month} {year}",
            date_range="{start} \u2013 {end}",
            identical_ok={},
        )

    path = root / "_content" / "career" / "locales" / f"{lang}.yaml"
    if not path.is_file():
        raise FileNotFoundError(f"missing locale file: {path}")
    with path.open("r", encoding="utf-8") as fh:
        raw = yaml.safe_load(fh) or {}
    if not isinstance(raw, dict):
        raise ValueError(f"{path}: top level must be a mapping")

    date = raw.get("date") or {}
    months = raw.get("months") or []
    return LocaleBundle(
        lang=lang,
        dir=str(raw.get("dir") or locale_dir(lang)),
        name=str(raw.get("name") or LANGUAGE_NAMES.get(lang, lang)),
        strings={str(k): str(v) for k, v in (raw.get("strings") or {}).items()},
        months=[str(m) for m in months],
        date_month_year=str(date.get("month_year") or "{month} {year}"),
        date_range=str(date.get("range") or "{start} \u2013 {end}"),
        identical_ok=_parse_identical_ok(raw.get("identical_ok")),
    )


def en_sha(text: str) -> str:
    """Short digest of an English master string, used to bind ``identical_ok``."""

    return hashlib.sha256(text.strip().encode("utf-8")).hexdigest()[:16]


def _parse_identical_ok(raw: Any) -> dict[str, dict[str, str]]:
    """Normalise ``identical_ok``. A legacy bare-string entry parses to an
    empty ``en_sha`` so validation names it instead of silently trusting it."""

    out: dict[str, dict[str, str]] = {}
    for key, value in (raw or {}).items():
        if isinstance(value, dict):
            out[str(key)] = {
                "reason": str(value.get("reason") or ""),
                "en_sha": str(value.get("en_sha") or ""),
            }
        else:
            out[str(key)] = {"reason": str(value or ""), "en_sha": ""}
    return out


def _placeholders(text: str) -> list[str]:
    return sorted(_PLACEHOLDER_RE.findall(text))


def _placeholder_errors(where: str, key: str, en: str, value: str) -> list[str]:
    """Locale text goes to ``str.format``: tokens must equal the English ones."""

    errors: list[str] = []
    found = _placeholders(value)
    for token in found:
        if not _NAMED_PLACEHOLDER_RE.match(token):
            errors.append(f"{where}: {key!r} has positional or malformed placeholder {token!r}")
    leftover = _PLACEHOLDER_RE.sub("", value)
    if "{" in leftover or "}" in leftover:
        errors.append(f"{where}: {key!r} has an unbalanced brace in placeholder text")
    if found != _placeholders(en):
        errors.append(
            f"{where}: {key!r} placeholder set {found} must equal the English "
            f"master's {_placeholders(en)}"
        )
    return errors


@lru_cache(maxsize=1)
def _tech_words() -> frozenset[str]:
    from .model import load_model

    raw = load_model().profile.raw
    names: list[str] = []
    for group in raw.get("skills") or []:
        names += [str(i) for i in group.get("items") or []]
    for coll in ("projects", "experience"):
        for node in raw.get(coll) or []:
            names += [str(i) for i in node.get("tech") or []]
    return frozenset(
        w.casefold() for n in names for w in _TECH_SPLIT_RE.split(n) if w
    )


def is_tech_only(text: str, tech: frozenset[str] | None = None) -> bool:
    """True when ``text`` is nothing but technology names and separators."""

    known = tech if tech is not None else _tech_words()
    words = [w for w in _TECH_SPLIT_RE.split(text) if w and not w.isdigit()]
    return bool(words) and all(w.casefold() in known for w in words)


def validate_locale(
    lang: str,
    bundle: LocaleBundle,
    catalog: list[CatalogEntry],
    *,
    identical_ok: dict[str, dict[str, str]] | None = None,
) -> list[str]:
    """Return every problem with one locale. Empty list means publishable."""

    errors: list[str] = []
    where = f"locales/{lang}.yaml"
    if identical_ok is None:
        identical_ok = bundle.identical_ok
    if lang in RTL_LOCALES and bundle.dir != "rtl":
        errors.append(f"{where}: dir must be 'rtl' for {lang}")
    if lang not in RTL_LOCALES and bundle.dir != "ltr":
        errors.append(f"{where}: dir must be 'ltr' for {lang}")
    if len(bundle.months) != 12:
        errors.append(f"{where}: months must have exactly 12 entries, got {len(bundle.months)}")
    for token in ("{month}", "{year}"):
        if token not in bundle.date_month_year:
            errors.append(f"{where}: date.month_year must contain {token}")
    for token in ("{start}", "{end}"):
        if token not in bundle.date_range:
            errors.append(f"{where}: date.range must contain {token}")

    known = {entry.key for entry in catalog}
    provided = set(bundle.strings)

    for entry in catalog:
        value = bundle.strings.get(entry.key, "")
        if not value.strip():
            errors.append(f"{where}: missing string {entry.key!r} ({entry.where})")
            continue
        _check_placeholder(errors, f"{where}:{entry.key}", value)
        errors.extend(_placeholder_errors(where, entry.key, entry.en, value))
        if value.strip() == entry.en.strip() and entry.key not in identical_ok:
            errors.append(
                f"{where}: {entry.key!r} is identical to the English master; "
                "translate it or list it under identical_ok with a reason"
            )

    by_key = {entry.key: entry for entry in catalog}
    for key in sorted(identical_ok):
        info = identical_ok[key]
        entry = by_key.get(key)
        if entry is None:
            errors.append(f"{where}: identical_ok names unknown key {key!r}")
            continue
        if not str(info.get("reason") or "").strip():
            errors.append(f"{where}: identical_ok {key!r} needs a non-empty reason")
        if not info.get("en_sha"):
            errors.append(
                f"{where}: identical_ok {key!r} needs en_sha "
                f"({en_sha(entry.en)}) binding it to the English text"
            )
        elif info["en_sha"] != en_sha(entry.en):
            errors.append(
                f"{where}: identical_ok {key!r}: English master changed since this "
                "was approved (en_sha mismatch); re-review and update"
            )
        value = bundle.strings.get(key, "")
        if value.strip() != entry.en.strip():
            errors.append(
                f"{where}: identical_ok {key!r} is stale: the value differs "
                "from the English master; remove the entry"
            )
        elif _ITEM_KEY_RE.search(key) and not is_tech_only(entry.en):
            errors.append(
                f"{where}: identical_ok {key!r} is a bullet that is not made of "
                "technology names only; it must be translated"
            )

    for key in sorted(provided - known):
        errors.append(f"{where}: unknown string key {key!r} (no such i18n key in content)")

    for key, value in bundle.strings.items():
        if not _KEY_RE.match(key):
            errors.append(f"{where}: malformed key {key!r}")

    return errors


def catalog_document(catalog: list[CatalogEntry], lang: str) -> dict[str, Any]:
    """The file translators receive: every key with its English source."""

    return {
        "schema": LOCALE_SCHEMA,
        "lang": lang,
        "dir": locale_dir(lang),
        "name": LANGUAGE_NAMES.get(lang, lang),
        # CLDR month names are supplied by babel where available so a
        # translator never has to invent them; see `month_names()`.
        "months": month_names(lang),
        "date": {
            "month_year": "{month} {year}",
            "range": "{start} \u2013 {end}",
        },
        "identical_ok": {},
        "strings": {entry.key: entry.en for entry in catalog},
        "_context": {entry.key: entry.where for entry in catalog},
    }


#: Neutral fallback when babel has no data for a locale. Never silently used:
#: `month_names()` reports which source it answered from.
_MONTHS_EN = [
    "Jan", "Feb", "Mar", "Apr", "May", "Jun",
    "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
]


def month_names(lang: str) -> list[str]:
    """Authoritative abbreviated month names for one locale.

    babel ships the CLDR data, so months are never translated by hand -- a
    mistranslated month name is a factual error in a CV, not a style choice.
    """

    if lang == "en":
        return list(_MONTHS_EN)
    try:
        from babel import Locale  # type: ignore import-not-found

        loc = Locale.parse(lang)
        table = loc.months["format"]["abbreviated"]
        months = [str(table[i]) for i in range(1, 13)]
        if len(months) == 12 and all(m.strip() for m in months):
            return months
    except Exception:
        pass
    return list(_MONTHS_EN)
