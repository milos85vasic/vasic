"""Load and validate the career content model.

The model is two kinds of data and nothing else:

  * ``_content/career/profile.yaml``  -- facts about the candidate, each one
    transcribed from the verified record. Facts are language-independent.
  * ``_content/career/areas/*.yaml``  -- *recipes*: which facts a given
    professional area surfaces, in what order, under which accent colour.

Neither file contains presentation logic. A recipe selects and orders; it never
invents. The validator below is the only gate that stands between the YAML and
every renderer, so it is deliberately strict and its messages name the exact
path that is wrong.

This module has no third-party dependency beyond PyYAML.
"""

from __future__ import annotations

import datetime as _dt
import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Iterable

import yaml

PROFILE_SCHEMA = "career.profile.v1"
AREA_SCHEMA = "career.area.v1"

#: Text that means somebody forgot to finish writing. A CV that ships one of
#: these is a defective artifact, not a stylistic choice.
PLACEHOLDER_PATTERNS = (
    "lorem ipsum",
    "todo",
    "tbd",
    "xxx",
    "placeholder",
    "fixme",
    "change me",
)

_MONTH_RE = re.compile(r"^(\d{4})-(0[1-9]|1[0-2])$")
_HEX_RE = re.compile(r"^#[0-9a-fA-F]{6}$")


class CareerModelError(Exception):
    """Raised when the model cannot be loaded at all (missing/broken YAML)."""


@dataclass
class Area:
    """One professional area recipe."""

    id: str
    order: int
    accent: str
    icon: str
    title_i18n: str
    title: str
    tagline_i18n: str
    tagline: str
    hero_metric: str
    sections: list[str]
    keywords: list[str]
    competencies: list[str]
    emphasis: list[str]
    projects: list[str]
    experience: list[str]
    cover_angle: str
    cover_opening_i18n: str
    cover_opening: str
    cover_project_ids: list[str]
    cover_closing_i18n: str
    cover_closing: str
    path: Path

    @property
    def slug(self) -> str:
        return self.id


@dataclass
class Profile:
    """The candidate record, validated and indexed."""

    raw: dict[str, Any]
    path: Path
    by_id: dict[str, dict[str, Any]] = field(default_factory=dict)

    def get(self, entity_id: str) -> dict[str, Any] | None:
        return self.by_id.get(entity_id)


@dataclass
class Model:
    profile: Profile
    areas: list[Area]
    errors: list[str]

    @property
    def ok(self) -> bool:
        return not self.errors

    def area(self, area_id: str) -> Area:
        for a in self.areas:
            if a.id == area_id:
                return a
        raise KeyError(f"unknown area: {area_id}")


# ---------------------------------------------------------------------------
# Loading
# ---------------------------------------------------------------------------


def _read_yaml(path: Path) -> Any:
    try:
        with path.open("r", encoding="utf-8") as fh:
            return yaml.safe_load(fh)
    except FileNotFoundError as exc:
        raise CareerModelError(f"missing file: {path}") from exc
    except yaml.YAMLError as exc:
        raise CareerModelError(f"{path}: invalid YAML: {exc}") from exc


def content_root(start: Path | None = None) -> Path:
    """Locate the repository root from anywhere inside it.

    Walks upward until ``_content/career/profile.yaml`` resolves, so the tool
    works from the repo root, from ``_tools/career``, or from a test sandbox
    that copied the content tree.
    """

    here = (start or Path(__file__)).resolve()
    for candidate in [here, *here.parents]:
        if (candidate / "_content" / "career" / "profile.yaml").is_file():
            return candidate
    raise CareerModelError(
        "could not locate _content/career/profile.yaml above "
        f"{here}"
    )


def load_profile(root: Path | None = None) -> Profile:
    root = root or content_root()
    path = root / "_content" / "career" / "profile.yaml"
    raw = _read_yaml(path)
    if not isinstance(raw, dict):
        raise CareerModelError(f"{path}: top level must be a mapping")

    by_id: dict[str, dict[str, Any]] = {}
    for collection in _ID_COLLECTIONS:
        for entry in raw.get(collection) or []:
            if isinstance(entry, dict) and entry.get("id"):
                by_id[str(entry["id"])] = entry
    return Profile(raw=raw, path=path, by_id=by_id)


_ID_COLLECTIONS = (
    "summary",
    "competencies",
    "experience",
    "projects",
    "skills",
    "education",
    "publications",
    "languages_spoken",
    "metrics",
    "labels",
    "templates",
)


def load_areas(root: Path | None = None) -> list[Area]:
    root = root or content_root()
    directory = root / "_content" / "career" / "areas"
    if not directory.is_dir():
        raise CareerModelError(f"missing area directory: {directory}")

    areas: list[Area] = []
    for path in sorted(directory.glob("*.yaml")):
        raw = _read_yaml(path)
        if not isinstance(raw, dict):
            raise CareerModelError(f"{path}: top level must be a mapping")
        cover = raw.get("cover_letter") or {}
        areas.append(
            Area(
                id=str(raw.get("id") or path.stem),
                order=int(raw.get("order") or 0),
                accent=str(raw.get("accent") or "#000000"),
                icon=str(raw.get("icon") or "dot"),
                title_i18n=str(raw.get("title_i18n") or f"area.{path.stem}.title"),
                title=str(raw.get("title") or ""),
                tagline_i18n=str(
                    raw.get("tagline_i18n") or f"area.{path.stem}.tagline"
                ),
                tagline=str(raw.get("tagline") or ""),
                hero_metric=str(raw.get("hero_metric") or ""),
                sections=[str(s) for s in (raw.get("sections") or [])],
                keywords=[str(s) for s in (raw.get("keywords") or [])],
                competencies=[str(s) for s in (raw.get("competencies") or [])],
                emphasis=[str(s) for s in (raw.get("emphasis") or [])],
                projects=[str(s) for s in (raw.get("projects") or [])],
                experience=[str(s) for s in (raw.get("experience") or [])],
                cover_angle=str(cover.get("angle") or ""),
                cover_opening_i18n=str(cover.get("opening_i18n") or ""),
                cover_opening=str(cover.get("opening") or ""),
                cover_project_ids=[str(s) for s in (cover.get("project_ids") or [])],
                cover_closing_i18n=str(cover.get("closing_i18n") or ""),
                cover_closing=str(cover.get("closing") or ""),
                path=path,
            )
        )
    areas.sort(key=lambda a: (a.order, a.id))
    return areas


# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------


def _iter_translatable(node: Any, path: str) -> Iterable[tuple[str, dict[str, Any]]]:
    """Yield every ``{i18n, text}``-shaped mapping with its dotted path."""

    if isinstance(node, dict):
        if "i18n" in node and ("text" in node or "label" in node):
            yield path, node
        for key, value in node.items():
            yield from _iter_translatable(value, f"{path}.{key}")
    elif isinstance(node, list):
        for index, value in enumerate(node):
            yield from _iter_translatable(value, f"{path}[{index}]")


def _check_placeholder(errors: list[str], path: str, text: str) -> None:
    lowered = text.casefold()
    for needle in PLACEHOLDER_PATTERNS:
        if needle in lowered:
            errors.append(f"{path}: contains placeholder text {needle!r}")
            return


def _check_i18n(errors: list[str], path: str, node: dict[str, Any]) -> None:
    key = node.get("i18n")
    if not isinstance(key, str) or not key.strip():
        errors.append(f"{path}: missing or empty i18n key")
    text = node.get("text", node.get("label"))
    if not isinstance(text, str) or not text.strip():
        errors.append(f"{path}: missing or empty text")
    elif isinstance(key, str):
        _check_placeholder(errors, path, text)


def validate(profile: Profile, areas: list[Area]) -> list[str]:
    """Return every problem found, not just the first. Empty list means valid."""

    errors: list[str] = []
    raw = profile.raw

    if raw.get("schema") != PROFILE_SCHEMA:
        errors.append(
            f"profile.schema: expected {PROFILE_SCHEMA!r}, got {raw.get('schema')!r}"
        )
    if not isinstance(raw.get("version"), str) or not raw.get("version"):
        errors.append("profile.version: missing")

    # --- required collections ------------------------------------------------
    for collection in ("identity", "summary", "competencies", "experience",
                       "projects", "skills", "education", "languages_spoken",
                       "metrics", "ats", "labels", "templates"):
        if not raw.get(collection):
            errors.append(f"profile.{collection}: missing or empty")

    # --- ids unique ----------------------------------------------------------
    seen: dict[str, str] = {}
    for collection in _ID_COLLECTIONS:
        for index, entry in enumerate(raw.get(collection) or []):
            if not isinstance(entry, dict):
                errors.append(f"profile.{collection}[{index}]: not a mapping")
                continue
            entity_id = entry.get("id")
            if not isinstance(entity_id, str) or not entity_id:
                errors.append(f"profile.{collection}[{index}]: missing id")
                continue
            if entity_id in seen:
                errors.append(
                    f"profile.{collection}[{index}]: duplicate id {entity_id!r} "
                    f"(already used by {seen[entity_id]})"
                )
            seen[entity_id] = f"{collection}[{index}]"

    # --- identity ------------------------------------------------------------
    identity = raw.get("identity") or {}
    for key in ("name", "name_sort", "email", "site", "photo", "years_experience"):
        if not identity.get(key):
            errors.append(f"profile.identity.{key}: missing")
    if identity.get("years_experience") is not None:
        try:
            years = int(identity["years_experience"])
        except (TypeError, ValueError):
            errors.append("profile.identity.years_experience: not an integer")
        else:
            if not 0 < years < 80:
                errors.append(
                    f"profile.identity.years_experience: implausible ({years})"
                )
    if identity.get("site") and not str(identity["site"]).startswith("https://"):
        errors.append("profile.identity.site: must be an https:// URL")

    # --- translatable text ---------------------------------------------------
    for path, node in _iter_translatable(raw, "profile"):
        _check_i18n(errors, path, node)

    # --- experience ----------------------------------------------------------
    for index, job in enumerate(raw.get("experience") or []):
        where = f"profile.experience[{index}]"
        for key in ("company", "role", "start", "areas"):
            if not job.get(key):
                errors.append(f"{where}.{key}: missing")
        for key in ("start", "end"):
            value = job.get(key)
            if value in ("", None):
                continue
            if not _MONTH_RE.match(str(value)):
                errors.append(f"{where}.{key}: expected YYYY-MM, got {value!r}")
        start, end = job.get("start"), job.get("end")
        if _MONTH_RE.match(str(start or "")) and _MONTH_RE.match(str(end or "")):
            if str(end) < str(start):
                errors.append(f"{where}: end {end} precedes start {start}")
        if job.get("current") and job.get("end"):
            errors.append(f"{where}: current job must not carry an end date")
        if not job.get("current") and not job.get("end"):
            errors.append(f"{where}: non-current job needs an end date")
        if not job.get("bullets"):
            errors.append(f"{where}.bullets: missing or empty")
        for bullet_index, bullet in enumerate(job.get("bullets") or []):
            if not isinstance(bullet, dict):
                errors.append(f"{where}.bullets[{bullet_index}]: not a mapping")

    # --- projects ------------------------------------------------------------
    for index, project in enumerate(raw.get("projects") or []):
        where = f"profile.projects[{index}]"
        for key in ("name", "url", "tier", "areas", "tech"):
            if not project.get(key):
                errors.append(f"{where}.{key}: missing")
        url = str(project.get("url") or "")
        if url and not url.startswith("https://"):
            errors.append(f"{where}.url: must be an https:// URL")
        if not project.get("blurb") and not project.get("blurb_i18n"):
            errors.append(f"{where}.blurb: missing")

    # --- metrics -------------------------------------------------------------
    for index, metric in enumerate(raw.get("metrics") or []):
        where = f"profile.metrics[{index}]"
        for key in ("value", "label", "evidence"):
            if not metric.get(key):
                errors.append(f"{where}.{key}: missing")

    # --- ats -----------------------------------------------------------------
    ats = raw.get("ats") or {}
    if not ats.get("base"):
        errors.append("profile.ats.base: missing or empty")
    for token in ats.get("forbidden") or []:
        if token != "\ufffd":
            errors.append(
                f"profile.ats.forbidden: unexpected token {token!r} "
                "(only U+FFFD is a portable ATS failure marker)"
            )

    # --- areas ---------------------------------------------------------------
    if not areas:
        errors.append("areas: no area recipes found")
    area_ids: set[str] = set()
    for area in areas:
        where = f"areas/{area.path.name}"
        if area.id in area_ids:
            errors.append(f"{where}: duplicate area id {area.id!r}")
        area_ids.add(area.id)
        if not _HEX_RE.match(area.accent):
            errors.append(f"{where}.accent: expected #rrggbb, got {area.accent!r}")
        for key in ("title", "tagline", "cover_angle", "cover_opening", "cover_closing"):
            if not str(getattr(area, key)).strip():
                errors.append(f"{where}.{key}: missing or empty")
        for key in ("title_i18n", "tagline_i18n", "cover_opening_i18n",
                    "cover_closing_i18n"):
            if not str(getattr(area, key)).strip():
                errors.append(f"{where}.{key}: missing or empty")
        if not area.keywords:
            errors.append(f"{where}.keywords: missing or empty")
        if not area.projects:
            errors.append(f"{where}.projects: missing or empty")
        if not area.experience:
            errors.append(f"{where}.experience: missing or empty")
        if not area.emphasis:
            errors.append(f"{where}.emphasis: missing or empty")
        if area.hero_metric and profile.get(area.hero_metric) is None:
            errors.append(
                f"{where}.hero_metric: unknown metric {area.hero_metric!r}"
            )
        for collection, values in (
            ("competencies", area.competencies),
            ("emphasis", area.emphasis),
            ("projects", area.projects),
            ("experience", area.experience),
            ("cover_letter.project_ids", area.cover_project_ids),
        ):
            for reference in values:
                if profile.get(reference) is None:
                    errors.append(
                        f"{where}.{collection}: unknown reference {reference!r}"
                    )
        for section in area.sections:
            if section not in _KNOWN_SECTIONS:
                errors.append(f"{where}.sections: unknown section {section!r}")

    return errors


_KNOWN_SECTIONS = {
    "summary",
    "competencies",
    "experience",
    "projects",
    "skills",
    "education",
    "publications",
    "languages",
    "metrics",
}


def load_model(root: Path | None = None) -> Model:
    root = root or content_root()
    profile = load_profile(root)
    areas = load_areas(root)
    return Model(profile=profile, areas=areas, errors=validate(profile, areas))


# ---------------------------------------------------------------------------
# Small shared helpers used by resolve/render
# ---------------------------------------------------------------------------


def parse_month(value: str) -> _dt.date:
    """Parse ``YYYY-MM`` into the first day of that month."""

    match = _MONTH_RE.match(str(value))
    if not match:
        raise ValueError(f"not a YYYY-MM date: {value!r}")
    return _dt.date(int(match.group(1)), int(match.group(2)), 1)


def month_number(value: str) -> int:
    return int(str(value).split("-")[1]) - 1


def year_number(value: str) -> int:
    return int(str(value).split("-")[0])
