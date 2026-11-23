"""Resolve (profile, area recipe, locale) into one DocumentModel.

A DocumentModel is the *only* thing a renderer ever sees. It is fully resolved:
every string is final, every list is ordered, every date is formatted. Renderers
therefore contain no selection logic, no translation lookup, and no content --
which is what makes five output formats agree by construction instead of by
diligent maintenance.

Two rules the resolver enforces:

  * A recipe selects and orders; it never invents. Every entity in the output
    came from ``profile.yaml`` by id.
  * Experience is presented reverse-chronologically even when a recipe lists it
    by relevance, because that is what every ATS and every recruiter expects.
"""

from __future__ import annotations

import datetime as _dt
import hashlib
import json
from typing import Any

from .catalog import LocaleBundle, load_locale, month_names
from .model import Area, Model, month_number, year_number

DOCUMENT_SCHEMA = "career.document.v1"

#: A CV that runs past two pages stops being read.  Recipes are ordered by
#: relevance, so the cap keeps the strongest entries and drops the tail.
#:
#: These are measured budgets, not taste.  With 8 projects at full 400-character
#: blurbs the A4 document is FOUR pages -- so the cap is 6 projects, 5 competency
#: groups, 3 competency items and 2 summary paragraphs, and a project's CV line
#: is its leading sentence capped at 150 characters.  The cover letter still
#: receives the untruncated blurb, because a letter is where the detail belongs.
MAX_PROJECTS = 6
MAX_SKILL_GROUPS = 6
MAX_COMPETENCY_GROUPS = 5
MAX_COMPETENCY_ITEMS = 3
MAX_SUMMARY_PARAGRAPHS = 2
PROJECT_LEAD_CHARS = 150
MIN_LEAD = 60

#: Which contact links appear, in order. Anything absent from identity is
#: skipped rather than rendered empty.
CONTACT_ORDER: tuple[tuple[str, str], ...] = (
    ("email_public", "mailto"),
    ("site", "url"),
    ("github", "url"),
    ("gitlab", "url"),
    ("telegram", "url"),
)


def _canonical_hash(payload: dict[str, Any]) -> str:
    encoded = json.dumps(
        payload, ensure_ascii=False, sort_keys=True, separators=(",", ":")
    ).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


def _labels(profile: Any, bundle: LocaleBundle) -> dict[str, str]:
    out: dict[str, str] = {}
    for entry in profile.raw.get("labels") or []:
        key = str(entry.get("i18n") or "")
        out[str(entry.get("id"))] = bundle.t(key, str(entry.get("text") or ""))
    return out


def _templates(profile: Any, bundle: LocaleBundle) -> dict[str, str]:
    out: dict[str, str] = {}
    for entry in profile.raw.get("templates") or []:
        key = str(entry.get("i18n") or "")
        out[str(entry.get("id"))] = bundle.t(key, str(entry.get("text") or ""))
    return out


def _fmt_month(value: str, bundle: LocaleBundle) -> str:
    month = bundle.months[month_number(value)]
    return bundle.date_month_year.format(month=month, year=year_number(value))


def _period(job: dict[str, Any], bundle: LocaleBundle, labels: dict[str, str]) -> str:
    start = _fmt_month(str(job["start"]), bundle)
    if job.get("end"):
        end = _fmt_month(str(job["end"]), bundle)
    else:
        end = labels.get("label.present", "Present")
    return bundle.date_range.format(start=start, end=end)


def _contact(identity: dict[str, Any], bundle: LocaleBundle) -> list[dict[str, str]]:
    out: list[dict[str, str]] = []
    for field, kind in CONTACT_ORDER:
        value = identity.get(field)
        if not value:
            continue
        if isinstance(value, list):
            value = value[0] if value else ""
        value = str(value)
        if not value:
            continue
        if kind == "mailto":
            out.append({"kind": "email", "label": value, "href": f"mailto:{value}"})
        else:
            label = value.replace("https://", "").replace("http://", "")
            label = label.rstrip("/")
            out.append({"kind": "url", "label": label, "href": value})
    return out


def _ats_keywords(profile: Any, area: Area) -> list[str]:
    seen: set[str] = set()
    out: list[str] = []
    for token in [*area.keywords, *(profile.raw.get("ats") or {}).get("base", [])]:
        key = str(token).casefold()
        if key in seen:
            continue
        seen.add(key)
        out.append(str(token))
    return out


def _experience(
    profile: Any,
    area: Area,
    bundle: LocaleBundle,
    labels: dict[str, str],
) -> list[dict[str, Any]]:
    selected = [profile.get(ref) for ref in area.experience]
    jobs = [job for job in selected if job]
    jobs.sort(key=lambda job: str(job.get("start") or ""), reverse=True)

    out: list[dict[str, Any]] = []
    for job in jobs:
        out.append(
            {
                "id": job.get("id", ""),
                "company": job.get("company", ""),
                "url": job.get("url", ""),
                "role": bundle.t(
                    str(job.get("role_i18n") or ""), str(job.get("role") or "")
                ),
                "location": bundle.t(
                    str(job.get("location_i18n") or ""),
                    str(job.get("location") or ""),
                ),
                "period": _period(job, bundle, labels),
                "summary": bundle.t(
                    str(job.get("summary_i18n") or ""),
                    str(job.get("summary") or ""),
                ),
                "bullets": [
                    bundle.t(str(b.get("i18n") or ""), str(b.get("text") or ""))
                    for b in (job.get("bullets") or [])
                ],
                "tech": [str(t) for t in (job.get("tech") or [])],
            }
        )
    return out


def _lead_sentence(text: str, limit: int = PROJECT_LEAD_CHARS) -> str:
    """The first self-contained claim of ``text``.

    A CV line has room for one claim, so the cut is made at a boundary a reader
    already recognises rather than at a character count, in this order:

      1. a sentence end -- ``. ``, ``! ``, ``? ``;
      2. a colon, em dash or semicolon -- ``HelixAgent`` reads far better as "an
         ensemble service that refuses to trust a single model" than as the
         first 150 characters of a 350-character sentence;
      3. a comma;
      4. nothing: the whole text is kept.

    Ellipsis truncation was the first design and was rejected by reading the
    output: three of the six project lines ended in a dangling preposition
    followed by "...", which reads as an unfinished thought rather than a
    summary.  Keeping the full text for the rare project with no boundary past
    ``MIN_LEAD`` costs at most one extra line and never misleads.
    """
    text = " ".join(str(text or "").split())
    if len(text) <= limit:
        return text

    window = text[: limit + 1]
    floor = max(MIN_LEAD, limit // 3)

    for stop, terminal in ((". ", True), ("! ", True), ("? ", True),
                           ("\u2014 ", False), (": ", False), ("; ", False),
                           (", ", False)):
        at = window.rfind(stop)
        if at >= floor:
            lead = text[: at + (1 if terminal else 0)].rstrip(",;: \u2014")
            # A caption ending in a comma looks like a typo, so a cut clause
            # always closes as a sentence.
            if not lead.endswith((".", "!", "?")):
                lead += "."
            return lead
    return text


def _projects(profile: Any, area: Area, bundle: LocaleBundle) -> list[dict[str, Any]]:
    out: list[dict[str, Any]] = []
    for ref in area.projects[:MAX_PROJECTS]:
        project = profile.get(ref)
        if not project:
            continue
        blurb = bundle.t(
            str(project.get("blurb_i18n") or ""),
            str(project.get("blurb") or ""),
        )
        out.append(
            {
                "id": project.get("id", ""),
                "name": project.get("name", ""),
                "url": project.get("url", ""),
                "tier": project.get("tier", ""),
                "blurb": blurb,
                "blurb_lead": _lead_sentence(blurb),
                "tech": [str(t) for t in (project.get("tech") or [])],
            }
        )
    return out


def _competencies(
    profile: Any, area: Area, bundle: LocaleBundle
) -> list[dict[str, Any]]:
    out: list[dict[str, Any]] = []
    for ref in area.competencies[:MAX_COMPETENCY_GROUPS]:
        comp = profile.get(ref)
        if not comp:
            continue
        out.append(
            {
                "id": comp.get("id", ""),
                "label": bundle.t(
                    str(comp.get("i18n") or ""), str(comp.get("label") or "")
                ),
                "items": [
                    bundle.t(str(item.get("i18n") or ""), str(item.get("text") or ""))
                    for item in (comp.get("items") or [])[:MAX_COMPETENCY_ITEMS]
                ],
            }
        )
    return out


def _skills(profile: Any, bundle: LocaleBundle) -> list[dict[str, Any]]:
    out: list[dict[str, Any]] = []
    for group in (profile.raw.get("skills") or [])[:MAX_SKILL_GROUPS]:
        out.append(
            {
                "id": group.get("id", ""),
                "label": bundle.t(
                    str(group.get("label_i18n") or ""),
                    str(group.get("label") or ""),
                ),
                "items": [str(item) for item in (group.get("items") or [])],
            }
        )
    return out


def _education(profile: Any, bundle: LocaleBundle) -> list[dict[str, Any]]:
    out: list[dict[str, Any]] = []
    for entry in profile.raw.get("education") or []:
        out.append(
            {
                "degree": bundle.t(
                    str(entry.get("degree_i18n") or ""), str(entry.get("degree") or "")
                ),
                "institution": entry.get("institution", ""),
                "location": bundle.t(
                    str(entry.get("location_i18n") or ""),
                    str(entry.get("location") or ""),
                ),
                "year": str(entry.get("year") or ""),
            }
        )
    return out


def _publications(profile: Any, bundle: LocaleBundle) -> list[dict[str, Any]]:
    out: list[dict[str, Any]] = []
    for entry in profile.raw.get("publications") or []:
        out.append(
            {
                "title": bundle.t(
                    str(entry.get("title_i18n") or ""), str(entry.get("title") or "")
                ),
                "detail": bundle.t(
                    str(entry.get("detail_i18n") or ""), str(entry.get("detail") or "")
                ),
            }
        )
    return out


def _languages(profile: Any, bundle: LocaleBundle) -> list[dict[str, Any]]:
    out: list[dict[str, Any]] = []
    for entry in profile.raw.get("languages_spoken") or []:
        out.append(
            {
                "code": entry.get("code", ""),
                "name": bundle.t(
                    str(entry.get("name_i18n") or ""), str(entry.get("name") or "")
                ),
                "level": bundle.t(
                    str(entry.get("level_i18n") or ""), str(entry.get("level") or "")
                ),
            }
        )
    return out


def _metrics(profile: Any, area: Area, bundle: LocaleBundle) -> list[dict[str, Any]]:
    out: list[dict[str, Any]] = []
    seen: set[str] = set()
    ordered = [area.hero_metric] + [
        str(m.get("id")) for m in (profile.raw.get("metrics") or [])
    ]
    for ref in ordered:
        if not ref or ref in seen:
            continue
        metric = profile.get(ref)
        if not metric:
            continue
        seen.add(ref)
        out.append(
            {
                "id": metric.get("id", ""),
                "value": str(metric.get("value") or ""),
                "label": bundle.t(
                    str(metric.get("i18n") or ""), str(metric.get("label") or "")
                ),
            }
        )
    return out[:4]


def resolve(
    model: Model,
    area_id: str,
    lang: str,
    *,
    kind: str = "cv",
    root=None,
    epoch: int | None = None,
    overlay: dict[str, Any] | None = None,
) -> dict[str, Any]:
    """Build the DocumentModel for one (area, language, kind) triple.

    ``epoch`` pins the document date.  It is a parameter rather than a call to
    ``datetime.now()`` so that the same triple always resolves to the same
    bytes; the build passes ``SOURCE_DATE_EPOCH`` and a caller that omits it
    gets no date rather than an uncontrolled one.
    """

    if kind not in ("cv", "cover"):
        raise ValueError(f"kind must be 'cv' or 'cover', got {kind!r}")

    profile = model.profile
    area = model.area(area_id)
    bundle = load_locale(lang, root or profile.path.parents[2])

    labels = _labels(profile, bundle)
    templates = _templates(profile, bundle)
    identity_raw = profile.raw.get("identity") or {}
    # Private overlay: explicit argument only (never read from the environment
    # here), so public pages that call resolve() without it stay overlay-free.
    extra_identity: dict[str, Any] = {}
    if overlay:
        from career.overlay import apply_identity
        merged = apply_identity(identity_raw, overlay)
        extra_identity = {k: v for k, v in merged.items() if k not in identity_raw or merged[k] != identity_raw[k]}
        identity_raw = merged

    area_title = bundle.t(area.title_i18n, area.title)
    name = str(identity_raw.get("name") or "")

    doc: dict[str, Any] = {
        "schema": DOCUMENT_SCHEMA,
        "kind": kind,
        "lang": lang,
        "dir": bundle.dir,
        "locale_name": bundle.name,
        "area": {
            "id": area.id,
            "order": area.order,
            "accent": area.accent,
            "icon": area.icon,
            "title": area_title,
            "tagline": bundle.t(area.tagline_i18n, area.tagline),
            "angle": area.cover_angle,
            "keywords": [str(k) for k in area.keywords],
        },
        "identity": {
            "name": name,
            "name_sort": identity_raw.get("name_sort", ""),
            "headline": bundle.t(
                str(identity_raw.get("headline_i18n") or ""),
                str(identity_raw.get("headline") or ""),
            ),
            "role": bundle.t(
                str(identity_raw.get("role_i18n") or ""),
                str(identity_raw.get("role") or ""),
            ),
            "location": bundle.t(
                str(identity_raw.get("location_i18n") or ""),
                str(identity_raw.get("location") or ""),
            ),
            "years_experience": identity_raw.get("years_experience"),
            "email": identity_raw.get("email", ""),
            "email_public": identity_raw.get("email_public", ""),
            "site": identity_raw.get("site", ""),
            "photo": identity_raw.get("photo", ""),
            "contact": _contact(identity_raw, bundle),
            **extra_identity,
        },
        "labels": labels,
        "templates": templates,
        "summary": [
            bundle.t(str(s.get("i18n") or ""), str(s.get("text") or ""))
            for s in (profile.raw.get("summary") or [])[:MAX_SUMMARY_PARAGRAPHS]
        ],
        "competencies": _competencies(profile, area, bundle),
        "skills": _skills(profile, bundle),
        "experience": _experience(profile, area, bundle, labels),
        "projects": _projects(profile, area, bundle),
        "education": _education(profile, bundle),
        "publications": _publications(profile, bundle),
        "languages": _languages(profile, bundle),
        "metrics": _metrics(profile, area, bundle),
        "ats": {
            "title": templates.get("tmpl.cv.title", "{name} — {area} — Curriculum Vitae")
            .format(name=name, area=area_title),
            "keywords": _ats_keywords(profile, area),
        },
    }

    if kind == "cover":
        doc["ats"]["title"] = templates.get(
            "tmpl.cl.title", "{name} — {area} — Cover letter"
        ).format(name=name, area=area_title)
        doc["cover"] = _cover(profile, area, bundle, templates, area_title)

    payload = {k: v for k, v in doc.items() if k != "meta"}
    doc["meta"] = {
        "version": str(profile.raw.get("version") or ""),
        "model_hash": _canonical_hash(payload),
        "source": "milosvasic.ru career engine",
        "date": _localized_date(lang, epoch),
        "epoch": int(epoch) if epoch is not None else None,
    }
    return doc


def _localized_date(lang: str, epoch: int | None) -> str:
    """A date a native reader would recognise, or ``""`` when unpinned.

    Uses the CLDR abbreviated month names already validated by
    :func:`career.catalog.month_names`, and the CJK/Korean numeric forms
    instead of a borrowed ``d mon y`` order, which reads as a translation.
    """
    if epoch is None:
        return ""
    d = _dt.datetime.fromtimestamp(int(epoch), tz=_dt.timezone.utc).date()
    if lang in ("zh", "ja"):
        return f"{d.year}年{d.month}月{d.day}日"
    if lang == "ko":
        return f"{d.year}년 {d.month}월 {d.day}일"
    mon = month_names(lang)[d.month - 1]
    return f"{d.day} {mon} {d.year}"


def _cover(
    profile: Any,
    area: Area,
    bundle: LocaleBundle,
    templates: dict[str, str],
    area_title: str,
) -> dict[str, Any]:
    """Compose the cover letter from facts already in the model.

    Every sentence is either a translated template or a verbatim project blurb;
    nothing is generated at render time and nothing is invented.
    """

    paragraphs: list[dict[str, str]] = []
    for ref in area.cover_project_ids:
        project = profile.get(ref)
        if not project:
            continue
        blurb = bundle.t(
            str(project.get("blurb_i18n") or ""), str(project.get("blurb") or "")
        )
        tech = ", ".join(str(t) for t in (project.get("tech") or [])[:6])
        body = templates.get("tmpl.cl.project", "{blurb}").format(
            blurb=blurb, tech=tech
        )
        paragraphs.append({"title": str(project.get("name") or ""), "body": body})

    emphasis_labels: list[str] = []
    for ref in area.emphasis:
        comp = profile.get(ref)
        if comp:
            emphasis_labels.append(
                bundle.t(
                    str(comp.get("i18n") or ""), str(comp.get("label") or "")
                )
            )
    if emphasis_labels:
        joined = ", ".join(emphasis_labels)
        paragraphs.append(
            {
                "title": "",
                "body": templates.get("tmpl.cl.emphasis", "{list}").format(list=joined),
            }
        )

    return {
        "subject": templates.get("tmpl.cl.subject", "Application — {area}").format(
            area=area_title
        ),
        "salutation": templates.get("tmpl.cl.salutation", "Dear Hiring Team,"),
        "opening": bundle.t(area.cover_opening_i18n, area.cover_opening),
        "angle": area.cover_angle,
        "paragraphs": paragraphs,
        "closing": bundle.t(area.cover_closing_i18n, area.cover_closing),
        "regards": "",
    }
