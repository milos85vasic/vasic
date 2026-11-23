#!/usr/bin/env python3
"""Generate the milosvasic.ru expertise hub + area pages (EN first).

Uses the career engine (``_tools/career/resolve.py`` — DocumentModel) for the
CV/CL context of every area and emits:

* ``milosvasic.ru/expertise/index.html``                — the technology hub
* ``milosvasic.ru/expertise/<area>/index.html``         — 10 area pages (EN)
* ``milosvasic.ru/assets/og/expertise.svg``             — hub OG card
* ``milosvasic.ru/assets/og/<area>.svg``                — per-area OG cards (10)
* ``milosvasic.ru/assets/og/*.png``                     — 1200x630 PNG twins of the cards
                                                          (Facebook/LinkedIn/X do not render SVG og:image)

Hand-written narrative lives in :data:`NARRATIVE` (area stories, cover-letter
angles, project blurbs).  Generated pages are idempotent: running the script
twice produces byte-identical output.

Run from the repository root:

    python3 _tools/career/expertise_pages.py
"""

from __future__ import annotations

import argparse
import functools
import json
import re
import shutil
import subprocess
import sys
import tempfile
from html import escape
from typing import Any
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))  # → _tools

from career import model, resolve  # noqa: E402
from career.catalog import LOCALES, locale_dir  # noqa: E402

SITE = Path(__file__).resolve().parents[2] / "milosvasic.ru"
SITE_URL = "https://milosvasic.ru"
EPOCH = 1795129352  # SOURCE_DATE_EPOCH-style pin for the resolve() doc meta


# ---------------------------------------------------------------------------
# Hand-written narrative (EN). Everything else on the pages is engine data.
# ---------------------------------------------------------------------------

#: Localized copies of the hand-written narrative, per language, per area:
#: ``LOC_NARRATIVE[lang][area_id] = {"story": ..., "blurbs": [{name, text}, ...]}``.
#: Written by the translator fleet into ``expertise_localized.json``.
LOC_NARRATIVE_PATH = SITE / "expertise_localized.json"


#: Reserved per-language key inside ``expertise_localized.json`` that holds the
#: localized HUB hero copy (it is NOT an area id):
#:     {"de": {"_hub": {"eyebrow": ..., "title": ..., "lede": ..., "stat_label": ...},
#:             "go": {...area narrative...}, ...}}
HUB_KEY = "_hub"

#: Canonical English source of the hub hero copy (single source of truth; a
#: translation workflow fills the same keys per language).  ``lede`` is followed
#: by the comma-joined area titles; ``stat_label`` is the whole stat line.
HUB_EN: dict[str, str] = {
    "eyebrow": "10 technology areas — 15 languages",
    "title": "Expertise",
    "lede": "Verified career paths by technology area — ",
    "stat_label": "15 languages · 10 areas · 16 years shipping",
}


def _read_loc() -> dict:
    if not LOC_NARRATIVE_PATH.is_file():
        return {}
    return json.loads(LOC_NARRATIVE_PATH.read_text(encoding="utf-8")) or {}


def _load_loc_narrative() -> dict[str, dict[str, dict[str, Any]]]:
    """``{lang: {area_id: narrative}}`` — the reserved ``_hub`` key is skipped."""
    out: dict[str, dict[str, dict[str, Any]]] = {}
    for lang, areas in _read_loc().items():
        for area_id, blob in (areas or {}).items():
            if area_id == HUB_KEY:
                continue
            out.setdefault(lang, {})[area_id] = blob
    return out


def _load_hub_blocks() -> dict[str, dict[str, str]]:
    """``{lang: hub block}``; a present block must carry every HUB_EN key as a
    non-empty string, otherwise ValueError (never a half-translated hero)."""
    out: dict[str, dict[str, str]] = {}
    for lang, areas in _read_loc().items():
        blk = (areas or {}).get(HUB_KEY)
        if blk is None:
            continue
        bad = [k for k in HUB_EN if not isinstance(blk.get(k), str) or not blk[k].strip()]
        if bad:
            raise ValueError(f"{LOC_NARRATIVE_PATH.name}: {lang}.{HUB_KEY} missing/empty keys {bad}")
        out[lang] = {k: blk[k] for k in HUB_EN}
    return out


NARRATIVE: dict[str, dict[str, object]] = {
    "ai-engineering": {
        "story": (
            "Production AI systems are only as trustworthy as the parts they refuse to trust themselves: "
            "a single-provider abstraction is a bet, an autonomous agent is a control plane, and governance "
            "is the only thing that keeps a fleet of them from drifting. In this area I build all three — "
            "the LLM layer that fronts 43 providers without hardcoding a fallback, the autonomous control "
            "plane that spawns and drives headless CLI agents, and the verification layer whose "
            "'Do you see my code?' gate means only models proven to actually work are ever marked usable "
            "or exported."
        ),
        "blurbs": [
            {"name": "HelixAgent", "text": "A production-grade ensemble LLM service that refuses to trust a single model; AI/LLM, Go, Gin, PostgreSQL, Redis, circuit breakers, health monitoring."},
            {"name": "LLMProvider", "text": "One interface over the 43 providers, with jittered-backoff retries and honest, no-hardcoded-fallback model discovery."},
            {"name": "HelixLLM", "text": "One binary, six deployment modes: OpenAI- and Anthropic-compatible inference over HTTP/3, scaling from a laptop to a multi-host cluster."},
        ],
    },
    "android": {
        "story": (
            "Kotlin and Java at product scale: SDKs, hardware integration, and release engineering. "
            "HelixTrack is the flagship proof — a free-world JIRA + Confluence alternative, "
            "Go microservices behind a unified action-routed API over HTTP/3, SQLCipher encryption at "
            "rest — showing what Android engineering looks like when the stack is built for the product "
            "rather than against it."
        ),
        "blurbs": [
            {"name": "HelixTrack", "text": "A free-world JIRA + Confluence alternative: Go microservices behind a unified action-routed API; HTTP/3, SQLCipher at rest."},
            {"name": "HelixQA", "text": "Anti-bluff QA orchestration: the bar is not 'tests pass' but 'users can use the feature'."},
        ],
    },
    "android-tv": {
        "story": (
            "Ten-foot interfaces, Leanback, media pipelines, and device-farm verification. "
            "Android TV experiences that survive real devices — verified against the thing users have, "
            "not the emulator, using the same HelixQA orchestration the mobile surface depends on."
        ),
        "blurbs": [
            {"name": "HelixQA", "text": "The anti-bluff QA orchestration that also drives Android TV verification."},
            {"name": "HelixTrack", "text": "The action-routed API that powers device-farm verification over HTTP/3."},
        ],
    },
    "android-aosp": {
        "story": (
            "Platform-level Android: system services, device bring-up, and hardware integration. "
            "AOSP work where the hardware is the requirement — and the platform has to bend to it, "
            "not the other way around."
        ),
        "blurbs": [
            {"name": "HelixQA", "text": "CI and device-farm verification at AOSP scale."},
            {"name": "VisionEngine", "text": "Computer-vision plus multi-provider LLM-vision UI perception with navigation graphs."},
        ],
    },
    "flutter": {
        "story": (
            "Dart at SDK level — plugin architecture, platform channels, and shipped packages. "
            "The surface AWS, Google and banks consume as SDKs: Courses-Creator turns a markdown "
            "document into a video course, on desktop, mobile and web, with TTS and two playable "
            "players, showing how an SDK crosses three surfaces at once."
        ),
        "blurbs": [
            {"name": "Courses-Creator", "text": "A markdown-to-video AI course pipeline with TTS and desktop, mobile and web players."},
            {"name": "HelixQA", "text": "The QA orchestration any SDK crossing platforms inherits."},
        ],
    },
    "react-native": {
        "story": (
            "TypeScript across the bridge — native modules, SDK packages, and release automation. "
            "The React Native bridge where the product is the product, not the platform: Catalogizer "
            "is a multi-protocol, encrypted, self-hostable media-collection manager consumed as a "
            "React app by AWS, Google and banks."
        ),
        "blurbs": [
            {"name": "Catalogizer", "text": "Multi-protocol, encrypted, self-hostable media collection management (Go/Gin + React), 21 modules."},
            {"name": "Courses-Creator", "text": "The markdown-to-video AI pipeline, with the desktop player."},
        ],
    },
    "mobile": {
        "story": (
            "Native and cross-platform delivery across Android, iOS, Flutter and React Native — as "
            "one engineer owning the whole mobile surface: SDK boundaries, platform channels, CI and "
            "release automation, and the hardware trust that holds it together. What AI means here "
            "is that the platform layer itself is already an orchestration product."
        ),
        "blurbs": [
            {"name": "HelixTrack", "text": "The flagship mobile-surface tool: a JIRA/Confluence alternative built at SDK scale."},
            {"name": "VisionEngine", "text": "Computer-vision plus multi-provider LLM-vision UI perception with navigation graphs."},
        ],
    },
    "go": {
        "story": (
            "High-throughput services, distributed systems, and the libraries they are built from. "
            "Go built to be operated, not just compiled: HelixTrack, the free-world JIRA + Confluence "
            "alternative, and HelixMemory — a unified cognitive-memory engine fusing four best-in-class "
            "backends (Mem0, Cognee, Letta, Graphiti)."
        ),
        "blurbs": [
            {"name": "HelixTrack", "text": "A free-world JIRA + Confluence alternative: Go microservices behind a unified action-routed API over HTTP/3, SQLCipher at rest."},
            {"name": "HelixMemory", "text": "A unified cognitive-memory engine fusing Mem0, Cognee, Letta and Graphiti."},
        ],
    },
    "web-frontend": {
        "story": (
            "TypeScript, React and Angular — design systems, accessibility, and performance budgets. "
            "Frontends that are fast, accessible and translated by construction: Catalogizer's React "
            "shell over the Go/Gin core, Courses-Creator's players, and HelixTrack's UI on the same "
            "stack — translated into 15 languages by the site's own generation pipeline."
        ),
        "blurbs": [
            {"name": "Catalogizer", "text": "The React shell of a multi-protocol, encrypted, self-hostable media-collection manager."},
            {"name": "Courses-Creator", "text": "The markdown-to-video AI course pipeline, with three playback surfaces (desktop, mobile, web)."},
        ],
    },
    "desktop": {
        "story": (
            "Electron and Tauri, native bridges, and offline-first desktop products — that ship, "
            "update and stay signed. The desktop surface: HelixTrack's JIRA alternative and "
            "Courses-Creator, both meeting the user on a machine, offline included."
        ),
        "blurbs": [
            {"name": "HelixTrack", "text": "The free-world JIRA + Confluence alternative, with its desktop surface."},
            {"name": "Courses-Creator", "text": "The AI course pipeline with its desktop player."},
        ],
    },
}


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def hreflang_links(paths: dict[str, str]) -> str:
    """Build the `seo_hreflang` front-matter value: one <link> per locale."""
    parts = []
    for lang in LOCALES:
        parts.append(
            f'<link rel="alternate" hreflang="{lang}" href="{SITE_URL}{paths[lang]}"/>'
        )
    xd = paths["x-default"]
    parts.append(f'<link rel="alternate" hreflang="x-default" href="{SITE_URL}{xd}"/>')
    return "".join(parts)


def hub_paths(slug: str | None = None) -> dict[str, str]:
    """hreflang path map: en hub (or area page), per-locale variants, x-default."""
    prefix = f"/expertise/{slug}/" if slug else "/expertise/"
    return {
        **{lang: f"{prefix}{lang}/" for lang in LOCALES if lang != "en"},
        "en": prefix,
        "x-default": prefix,
    }


#: Open Graph wants language_TERRITORY, never a bare language code.
OG_LOCALES: dict[str, str] = {
    "en": "en_US", "ru": "ru_RU", "de": "de_DE", "es": "es_ES", "fr": "fr_FR",
    "ar": "ar_AR", "fa": "fa_IR", "hi": "hi_IN", "ja": "ja_JP", "ko": "ko_KR",
    "kk": "kk_KZ", "be": "be_BY", "sr": "sr_RS", "tr": "tr_TR", "zh": "zh_CN",
}


def og_locale(lang: str) -> str:
    return OG_LOCALES[lang]


def og_alternates(lang: str) -> str:
    return "".join(
        f'<meta property="og:locale:alternate" content="{og_locale(l)}"/>'
        for l in LOCALES if l != lang
    )


def og_image(slug: str, alt: str) -> dict:
    """jekyll-seo-tag image hash -> og:image/twitter:image + width/height/alt."""
    return {"path": f"/assets/og/{slug}.png", "width": OG_W, "height": OG_H, "alt": alt}


def page_social(lang: str, slug: str, alt: str) -> dict:
    return {
        "locale": og_locale(lang),
        "image": og_image(slug, alt),
        "seo_og_alternates": og_alternates(lang),
    }


def hub_dir(lang: str) -> str:
    """Text direction of a locale, from the locale bundle (single source)."""
    return locale_dir(lang)


def front_matter(fields: dict[str, Any]) -> str:
    """Emit Jekyll front matter as a block of JSON-quoted scalars (valid YAML)."""
    lines = ["---"]
    for key, value in fields.items():
        lines.append(f"{key}: {json.dumps(value, ensure_ascii=False)}")
    lines.append("---")
    return "\n".join(lines) + "\n\n"


#: Collector for the current generation run: rel path -> text. Nothing touches
#: disk during generation; ``emit_files`` / ``check_files`` do that afterwards.
_COLLECT: dict[str, "str | bytes"] = {}


def write_file(rel: str, text: "str | bytes") -> Path:
    _COLLECT[rel] = text
    return SITE / rel


# ---------------------------------------------------------------------------
# JSON-LD
# ---------------------------------------------------------------------------

PERSON_ID = f"{SITE_URL}/expertise/#person"
PERSON_NAME = "Miloš Vasić"
PERSON_JOB_TITLE = "AI Engineer — LLM infrastructure, autonomous agents, and the governance that makes them trustworthy"
PERSON_DESCRIPTION = (
    "AI engineer building verifiable AI-development systems: autonomous coding agents, "
    "LLM orchestration, and constitution-governed tooling. 16+ years shipping production "
    "software across mobile SDKs, real-time hardware integration, and distributed backends."
)


#: identity.* keys of profile.yaml whose values are the person's own profiles
#: elsewhere on the web.  Only links PRESENT in profile.yaml are ever emitted.
SAME_AS_KEYS = ("github", "gitlab", "gitflic", "linkedin", "telegram", "orcid",
                "twitter", "mastodon", "stackoverflow", "habr")


@functools.lru_cache(maxsize=1)
def same_as() -> tuple[str, ...]:
    ident = model.load_model().profile.raw.get("identity", {}) or {}
    out: list[str] = []
    for key in SAME_AS_KEYS:
        v = ident.get(key)
        for u in (v if isinstance(v, list) else [v]):
            if isinstance(u, str) and u.startswith("https://") and u not in out:
                out.append(u)
    return tuple(out)


def person_json(*, job_title: str, knows_about: list[str], description: str) -> dict:
    return {
        "@type": "Person",
        "@id": PERSON_ID,
        "name": PERSON_NAME,
        "givenName": "Miloš",
        "familyName": "Vasić",
        "jobTitle": job_title,
        "url": f"{SITE_URL}/",
        "description": description,
        "knowsAbout": knows_about,
        "sameAs": list(same_as()),
    }


def hub_page_json(titles: list[dict[str, str]], lang: str = "en") -> dict:
    suffix = "" if lang == "en" else f"{lang}/"
    hub_url = f"{SITE_URL}/expertise/{suffix}"
    person = person_json(
        job_title=PERSON_JOB_TITLE,
        knows_about=[t["title"] for t in titles],
        description=PERSON_DESCRIPTION,
    )
    person["hasOccupation"] = [
        {
            "@type": "Occupation",
            "name": t["title"],
            "mainEntityOfPage": {"@id": t["url"]},
            "description": t["tagline"],
        }
        for t in titles
    ]
    return {
        "@context": "https://schema.org",
        "@type": "ProfilePage",
        "@id": hub_url,
        "url": hub_url,
        "inLanguage": lang,
        "name": f"{PERSON_NAME} — Expertise",
        "mainEntity": person,
    }


def area_page_json(area: model.Area, doc: dict, lang: str = "en") -> dict:
    suffix = "" if lang == "en" else f"{lang}/"
    url = f"{SITE_URL}/expertise/{area.id}/{suffix}"
    title = doc["area"]["title"] if lang != "en" else area.title
    tagline = doc["area"]["tagline"] if lang != "en" else area.tagline
    person = person_json(
        job_title=title,
        knows_about=doc["area"]["keywords"],
        description=tagline,
    )
    person["hasOccupation"] = [
        {
            "@type": "Occupation",
            "name": title,
            "mainEntityOfPage": {"@id": url},
            "description": tagline,
        }
    ]
    return {
        "@context": "https://schema.org",
        "@type": "ProfilePage",
        "@id": url,
        "url": url,
        "inLanguage": lang,
        "name": f"{title} — {PERSON_NAME}",
        "isPartOf": {"@id": f"{SITE_URL}/expertise/{suffix}"},
        "mainEntity": person,
    }


# ---------------------------------------------------------------------------
# HTML rendering
# ---------------------------------------------------------------------------

#: English defaults for every section heading.  Localized pages take the same
#: keys from ``doc["labels"]`` (profile.yaml ``labels:`` block, per locale).
DEFAULT_HEADINGS = {
    "overview": "Overview",
    "experience": "Experience",
    "projects": "Projects",
    "timeline": "Timeline",
    "metrics": "Metrics",
    "skills": "Skills &amp; competencies",
    "education": "Education &amp; publications",
    "cover": "Cover letter context",
    "back": "Expertise",
    "angle": "Narrow the angle:",
}

#: heading id -> profile.yaml label key used on localized pages.
HEADING_LABEL_KEYS = {
    "overview": "label.summary",
    "experience": "label.experience",
    "projects": "label.projects",
    "timeline": "label.experience",
    "skills": "label.skills",
    "education": "label.education",
    "cover": "label.cover.subject",
    "back": "label.experience",
}


def headings(doc: dict, lang: str) -> dict[str, str]:
    """Section headings for one page.  English keeps the original copy; every
    other locale reads the translated label from the resolved document."""
    if lang == "en":
        return dict(DEFAULT_HEADINGS)
    labels = doc.get("labels") or {}
    out = dict(DEFAULT_HEADINGS)
    for hid, key in HEADING_LABEL_KEYS.items():
        if labels.get(key):
            out[hid] = escape(labels[key].replace("{area}", doc["area"]["title"]))
    out["metrics"] = ""  # no translated label exists; the section is unlabeled
    out["angle"] = ""  # the angle sentence is already localized data
    return out

def render_experience(doc: dict, h: dict[str, str] | None = None) -> str:
    h = h or DEFAULT_HEADINGS
    items = []
    for job in doc["experience"]:
        bullets = "".join(
            f'<li class="mv-area-exp__bullet">{escape(b)}</li>' for b in job["bullets"]
        )
        tech = ", ".join(job["tech"])
        location = (
            f'<p class="mv-area-exp__location">{escape(job["location"])}</p>'
            if job["location"]
            else ""
        )
        items.append(
            f"""
    <li class="mv-area-exp">
      <header class="mv-area-exp__head">
        <h3 class="mv-area-exp__company">{escape(job["company"])}</h3>
        <p class="mv-area-exp__role">{escape(job["role"])} — {escape(job["period"])}</p>
        {location}
      </header>
      <p class="mv-area-exp__summary">{escape(job["summary"])}</p>
      <ul class="mv-area-exp__bullets">{bullets}</ul>
      {f'<p class="mv-area-exp__tech">{escape(tech)}</p>' if tech else ''}
    </li>"""
        )
    return (
        '<section class="mv-area-section mv-area-experience">'
        f"<h2>{h['experience']}</h2>"
        '<ol class="mv-area-experience-list">'
        + "".join(items)
        + "</ol></section>"
    )


def render_projects(projects: list[dict], h: dict[str, str] | None = None) -> str:
    h = h or DEFAULT_HEADINGS
    items = []
    for p in projects:
        tech = ", ".join(p["tech"])
        items.append(
            f"""
    <li>
      <a class="mv-area-project" href="{escape(p["url"])}">
        <span class="mv-area-project__name"><strong>{escape(p["name"])}</strong></span>
        <span class="mv-area-project__tier">{escape(p["tier"])}</span>
        {f'<span class="mv-area-project__tech">{escape(tech)}</span>' if tech else ''}
      </a>
      {f'<p class="mv-area-project__lead">{escape(p["blurb_lead"])}</p>' if p["blurb_lead"] else ''}
    </li>"""
        )
    return (
        '<section class="mv-area-section mv-area-projects">'
        f"<h2>{h['projects']}</h2>"
        f"<ul class=\"mv-area-projects-list\">{''.join(items)}</ul></section>"
    )


def render_timeline(doc: dict, h: dict[str, str] | None = None) -> str:
    h = h or DEFAULT_HEADINGS
    events = []
    for job in doc["experience"]:
        years = re.findall(r"\d{4}", job["period"])
        year = years[0] if years else "—"
        label = f"{job['company']} — {job['role']}"
        events.append(
            f"""
    <div class="mv-area-timeline__entry">
      <span class="mv-area-timeline__marker" aria-hidden="true"></span>
      <span class="mv-area-timeline__event">{escape(label)}</span>
      <span class="mv-area-timeline__year">{escape(year)}</span>
    </div>"""
        )
    return (
        '<section class="mv-area-section mv-area-timeline a2-timeline">'
        f"<h2>{h['timeline']}</h2>"
        '<div class="mv-area-timeline__line">'
        + "".join(events)
        + "</div></section>"
    )


def render_metrics(doc: dict, h: dict[str, str] | None = None) -> str:
    h = h or DEFAULT_HEADINGS
    items = []
    for m in doc["metrics"]:
        items.append(
            f'<div class="mv-area-metric">'
            f'<dt class="mv-area-metric__value">{escape(m["value"])}</dt>'
            f'<dd class="mv-area-metric__label">{escape(m["label"])}</dd>'
            f"</div>"
        )
    return (
        '<section class="mv-area-section mv-area-metrics">'
        + (f"<h2>{h['metrics']}</h2>" if h.get("metrics") else "")
        +
        f'<dl class="mv-area-metrics-list">{"".join(items)}</dl></section>'
    )


def render_skills(doc: dict, h: dict[str, str] | None = None) -> str:
    h = h or DEFAULT_HEADINGS
    comps = "".join(
        f"""
    <div class="mv-area-competency">
      <h3 class="mv-area-competency__label">{escape(c["label"])}</h3>
      <ul class="mv-area-competency__items">
        {''.join(f'<li>{escape(i)}</li>' for i in c['items'])}
      </ul>
    </div>"""
        for c in doc["competencies"]
    )
    skills = "".join(
        f"""
    <div class="mv-area-skill-group">
      <h3 class="mv-area-skill-group__label">{escape(s["label"])}</h3>
      <ul class="mv-area-skill-group__items">
        {''.join(f'<li>{escape(i)}</li>' for i in s["items"])}
      </ul>
    </div>"""
        for s in doc["skills"]
    )
    return (
        '<section class="mv-area-section mv-area-skills">'
        f"<h2>{h['skills']}</h2>"
        '<div class="mv-area-skills__grid">'
        + comps
        + skills
        + "</div></section>"
    )


def render_cover(doc: dict, h: dict[str, str] | None = None) -> str:
    h = h or DEFAULT_HEADINGS
    cover = doc.get("cover")
    if not cover:
        return ""
    paras = "".join(
        f"""
      <div class="mv-area-cover__paragraph">
        {f'<h3 class="mv-area-cover__paragraph-title">{escape(p["title"])}</h3>' if p["title"] else ''}
        <p>{escape(p["body"])}</p>
      </div>"""
        for p in cover["paragraphs"]
    )
    return (
        '<section class="mv-area-section mv-area-cover">'
        f"<h2>{h['cover']}</h2>"
        f"<p class=\"mv-area-cover__opening\">{escape(cover['opening'])}</p>"
        f"<p class=\"mv-area-cover__angle\"><strong>{escape(cover['angle'])}</strong></p>"
        + paras
        + "</section>"
    )


def render_education(doc: dict, h: dict[str, str] | None = None) -> str:
    h = h or DEFAULT_HEADINGS
    if not doc["education"] and not doc["publications"]:
        return ""
    items = "".join(
        f"""
    <li class="mv-area-education__item">
      <strong>{escape(e["degree"])}</strong> — {escape(e["institution"])}, {escape(e["location"])} ({escape(e["year"])})
    </li>"""
        for e in doc["education"]
    )
    pubs = "".join(
        f"<li class=\"mv-area-education__item\">{escape(p['title'])} — {escape(p['detail'])}</li>"
        for p in doc["publications"]
    )
    return (
        '<section class="mv-area-section mv-area-education">'
        f"<h2>{h['education']}</h2>"
        f"<ul class=\"mv-area-education-list\">{items}{pubs}</ul></section>"
    )


def area_page_body(area: model.Area, doc: dict, cover: dict, narrative: dict,
                   lang: str = "en") -> str:
    h = headings(doc, lang)
    # Hand-written narrative exists in English only unless the translator fleet
    # supplied expertise_localized.json.  A fallback is marked lang="en" so the
    # page never claims a language it is not written in.
    fallback = bool(narrative.get("_fallback"))
    en_attr = ' lang="en" dir="ltr"' if fallback and lang != "en" else ""
    blurb_items = narrative["blurbs"]
    assert isinstance(blurb_items, list)
    blurbs = "".join(
        f"""
        <article class="mv-area-project-blurb"{en_attr}>
          <h3 class="mv-area-project-blurb__name">{escape(b["name"])}</h3>
          <p class="mv-area-project-blurb__text">{escape(b["text"])}</p>
        </article>"""
        for b in blurb_items[:3]
    )
    back_href = f"/expertise/{lang}/" if lang != "en" else "/expertise/"
    title = doc["area"]["title"] if lang != "en" else area.title
    tagline = doc["area"]["tagline"] if lang != "en" else area.tagline
    angle_prefix = f"<strong>{h['angle']}</strong> " if h["angle"] else ""
    return f"""
  <header class="mv-area-header">
    <a class="mv-area-back" href="{back_href}">{h['back']}</a>
    <p class="mv-area-index">{escape(str(area.order).zfill(2))} — {escape(title)}</p>
    <h1 class="mv-area-title">{escape(title)}</h1>
    <p class="mv-area-tagline">{escape(tagline)}</p>
    <p class="mv-area-angle">{angle_prefix}{escape(doc["area"]["angle"])}</p>
  </header>

  <section class="mv-area-section mv-area-story">
    <h2>{h['overview']}</h2>
    <p class="mv-area-story__text"{en_attr}>{escape(narrative["story"])}</p>
    <div class="mv-area-project-blurbs">{blurbs}</div>
  </section>

  {render_experience(doc, h)}
  {render_projects(doc["projects"], h)}
  {render_timeline(doc, h)}
  {render_metrics(doc, h)}
  {render_skills(doc, h)}
  {render_education(doc, h)}
  {render_cover(cover, h)}
  <script type="application/ld+json">{json.dumps(area_page_json(area, doc, lang), ensure_ascii=False)}</script>
"""


def _tile_markup(area_id: str, href: str, index: str, title: str, tagline: str,
                 projects: str, metric: dict | None) -> str:
    """One hub tile: index | body(head, tagline, projects) | arrow.  The grid in
    milosvasic.css has three columns, so the text lives in ONE body child."""
    metric_html = (
        f'<span class="mv-expertise-tile__metric">{escape(metric["value"])} {escape(metric["label"])}</span>'
        if metric else ""
    )
    return f"""
    <a class="mv-expertise-tile" data-area="{escape(area_id)}" href="{escape(href)}">
      <span class="mv-expertise-tile__index">{escape(index)}</span>
      <span class="mv-expertise-tile__body">
        <span class="mv-expertise-tile__head">
          <span class="mv-expertise-tile__title">{escape(title)}</span>
          {metric_html}
        </span>
        <span class="mv-expertise-tile__tagline">{escape(tagline)}</span>
        <span class="mv-expertise-tile__projects">{escape(projects)}</span>
      </span>
      <span class="mv-expertise-tile__arrow" aria-hidden="true">→</span>
    </a>"""


def hub_tile(area: model.Area, doc: dict) -> str:
    metric = doc["metrics"][0] if doc["metrics"] else None
    projects = ", ".join(p["name"] for p in doc["projects"][:3])
    return _tile_markup(area.id, f"/expertise/{area.id}/", str(area.order).zfill(2),
                        area.title, area.tagline, projects, metric)


def hub_page_body(titles: list[dict], areas: list[model.Area], docs: dict[str, dict],
                  years_experience: int) -> str:
    tiles = "".join(hub_tile(a, docs[a.id]) for a in areas)
    area_list = ", ".join(a.title for a in areas)
    return f"""
  <section class="mv-expertise-hero a2-intro">
    <p class="mv-expertise-eyebrow"><span class="od-chip">10 technology areas — 15 languages</span></p>
    <h1 class="mv-expertise-title">Expertise</h1>
    <p class="mv-expertise-lede">Verified career paths by technology area — {escape(area_list)}. Each area links to the full experience behind it.</p>
    <p class="mv-expertise-stat">15 languages · 10 areas · {years_experience} years shipping</p>
  </section>

  <div class="mv-expertise-tiles">{tiles}</div>

  <script type="application/ld+json">{json.dumps(hub_page_json(titles), ensure_ascii=False)}</script>
"""


# ---------------------------------------------------------------------------
# Sitemap
# ---------------------------------------------------------------------------

def sitemap_expertise_urls(area_ids: list[str]) -> list[str]:
    """Every expertise URL in a stable order: hub, areas, then localized hubs
    and localized area pages (15 locales = EN + 14 overlays)."""
    langs = [l for l in LOCALES if l != "en"]
    urls = [f"{SITE_URL}/expertise/"]
    urls += [f"{SITE_URL}/expertise/{a}/" for a in area_ids]
    urls += [f"{SITE_URL}/expertise/{l}/" for l in langs]
    urls += [f"{SITE_URL}/expertise/{a}/{l}/" for a in area_ids for l in langs]
    return urls


# ---------------------------------------------------------------------------
# OG cards (deterministic SVG, 1200×630)
# ---------------------------------------------------------------------------

OG_W, OG_H = 1200, 630


@functools.lru_cache(maxsize=None)
def _render_png(svg: str) -> bytes:
    """SVG -> 1200x630 PNG with Inkscape (deterministic: no timestamp chunks).
    RuntimeError('cannot determine ...') when no renderer is installed."""
    exe = shutil.which("inkscape")
    if not exe:
        raise RuntimeError("cannot determine: no SVG renderer (inkscape) installed")
    with tempfile.TemporaryDirectory() as d:
        src, dst = Path(d) / "c.svg", Path(d) / "c.png"
        src.write_text(svg, encoding="utf-8")
        r = subprocess.run([exe, str(src), "-o", str(dst), "-w", str(OG_W), "-h", str(OG_H)],
                           capture_output=True, text=True, timeout=120)
        if r.returncode != 0 or not dst.is_file():
            raise RuntimeError(f"cannot determine: inkscape failed rc={r.returncode}: {r.stderr[-200:]}")
        return dst.read_bytes()


def og_svg(accent: str, title: str, tagline: str, footer_lines: list[str]) -> str:
    accent_rgb = f"rgb({int(accent[1:3], 16)},{int(accent[3:5], 16)},{int(accent[5:7], 16)})"

    def text_el(x: int, y: int, size: int, weight: int, fill: str, text: str) -> str:
        safe = escape(text)
        return (
            f'<text x="{x}" y="{y}" font-family="Space Grotesk, system-ui, sans-serif" '
            f'font-size="{size}" font-weight="{weight}" fill="{fill}">{safe}</text>'
        )

    lines = ["<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"1200\" height=\"630\" viewBox=\"0 0 1200 630\">"]
    lines.append(f'<rect width="1200" height="630" fill="#050404"/>')
    lines.append(f'<rect x="0" y="0" width="1200" height="12" fill="{accent}"/>')
    lines.append(
        f'<rect x="0" y="0" width="1200" height="630" fill="url(#g)" opacity="0.06"/>'
        f'<defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1">'
        f'<stop offset="0" stop-color="{accent}"/>'
        f'<stop offset="1" stop-color="#0b0a09"/>'
        f'</linearGradient></defs>'
    )
    lines.append(text_el(78, 152, 78, 700, "#ffffff", title))
    lines.append(text_el(78, 238, 30, 400, "rgba(215,211,203,.72)", tagline))
    x, y = 78, 470
    for footer in footer_lines:
        lines.append(text_el(x, y, 26, 400, "rgba(215,211,203,.6)", footer))
        y += 48
    lines.append(
        text_el(1160, 595, 16, 400, "rgba(215,211,203,.55)", "milosvasic.ru")
    )
    lines.append("</svg>")
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def hub_tile_localized(area_id: str, doc: dict, narrative_title: str,
                       narrative_tagline: str, narrative_projects: str,
                       url: str, index: str) -> str:
    """Hub tile with the localized area title/tagline/project names."""
    metric = doc["metrics"][0] if doc["metrics"] else None
    return _tile_markup(area_id, url, index, narrative_title, narrative_tagline,
                        narrative_projects, metric)


def hub_page_body_localized(tiles: list[str], hero: dict, areas: list[model.Area],
                            lang: str = "en", titles: list[dict[str, str]] | None = None) -> str:
    area_list = hero["area_list"]
    # Hero copy is English unless the translator fleet supplied hub copy; an
    # untranslated hero is marked lang="en" so the page never claims a language
    # it is not written in.
    hero_attr = ' lang="en" dir="ltr"' if hero.get("_fallback") else ""
    ld = (
        f'\n  <script type="application/ld+json">{json.dumps(hub_page_json(titles, lang), ensure_ascii=False)}</script>\n'
        if titles else ""
    )
    return f"""
  <section class="mv-expertise-hero a2-intro"{hero_attr}>
    <p class="mv-expertise-eyebrow"><span class="od-chip">{escape(hero['eyebrow'])}</span></p>
    <h1 class="mv-expertise-title">{escape(hero['title'])}</h1>
    <p class="mv-expertise-lede">{escape(hero['lede'])} {escape(area_list)}.</p>
    <p class="mv-expertise-stat">{escape(hero['stat'])}</p>
  </section>

  <div class="mv-expertise-tiles">{"".join(tiles)}</div>
{ld}"""


def _localized_hub_copy(lang: str) -> dict[str, str]:
    return {
        "eyebrow": HUB_EN["eyebrow"],
        "title": HUB_EN["title"],
        "lede": HUB_EN["lede"],
        "stat": HUB_EN["stat_label"],
        "area_list": ", ".join(a.title for a in model.load_areas()),
        "_fallback": True,
    }


def generate() -> dict[str, str]:
    """Render every generated file in memory: ``{relative path: text}``.

    Reads the live site only as INPUT (localized narrative, sitemap lastmod).
    Raises RuntimeError when the career model is not ok.
    """
    _COLLECT.clear()
    m = model.load_model()
    if not m.ok:
        raise RuntimeError(f"model errors: {m.errors}")

    areas = sorted(m.areas, key=lambda a: a.order)
    docs: dict[str, dict] = {}
    cover_docs: dict[str, dict] = {}
    for a in areas:
        docs[a.id] = resolve.resolve(m, a.id, "en", kind="cv", epoch=EPOCH)
        cover_docs[a.id] = resolve.resolve(m, a.id, "en", kind="cover", epoch=EPOCH)
    years_experience = int(
        m.profile.raw.get("identity", {}).get("years_experience", 16) or 16
    )

    loc_narrative = _load_loc_narrative()
    hub_blocks = _load_hub_blocks()

    def write_hub(lang: str) -> None:
        """Localized hub + localized area pages for one overlay language."""
        path_prefix = f"/expertise/{lang}/"
        # Localized hub
        hero = _localized_hub_copy(lang)
        translated_hub = lang in hub_blocks
        if translated_hub:
            blk = hub_blocks[lang]
            hero.update({"eyebrow": blk["eyebrow"], "title": blk["title"],
                         "lede": blk["lede"], "stat": blk["stat_label"]})
            hero.pop("_fallback", None)
        tiles = []
        local_titles: list[str] = []
        local_ld: list[dict[str, str]] = []
        for a in areas:
            doc = docs[a.id]
            tile_doc = resolve.resolve(m, a.id, lang, kind="cv", epoch=EPOCH)
            loc_nar = loc_narrative.get(lang, {}).get(a.id)
            nar = loc_nar if loc_nar else {**NARRATIVE[a.id], "_fallback": True}
            # Localized area page
            write_file(
                f"expertise/{a.id}/{lang}/index.html",
                front_matter(
                    {
                        "layout": "default",
                        "lang": lang,
                        "dir": tile_doc["dir"],
                        "area": a.id,
                        "title": f"{tile_doc['area']['title']} — Miloš Vasić",
                        # Localized tagline only: the English template tail would
                        # make a localized page advertise English metadata.
                        "description": f"{tile_doc['area']['tagline']} — Miloš Vasić",
                        **page_social(lang, a.id, tile_doc["area"]["title"]),
                        "seo_hreflang": hreflang_links(hub_paths(a.id)),
                    }
                )
                + area_page_body(a, tile_doc, cover_docs[a.id], nar, lang=lang),
            )
            local_titles.append(tile_doc["area"]["title"])
            local_ld.append({"title": tile_doc["area"]["title"], "tagline": tile_doc["area"]["tagline"],
                             "url": f"{SITE_URL}/expertise/{a.id}/{lang}/"})
            tiles.append(
                hub_tile_localized(
                    a.id, tile_doc,
                    tile_doc["area"]["title"], tile_doc["area"]["tagline"],
                    ", ".join(p["name"] for p in tile_doc["projects"][:3]),
                    url=f"{SITE_URL}/expertise/{a.id}/{lang}/",
                    index=str(a.order).zfill(2),
                )
            )
        if translated_hub:
            hero["area_list"] = ", ".join(local_titles)
        write_file(
            f"expertise/{lang}/index.html",
            front_matter(
                {
                    "layout": "default",
                    "lang": lang,
                    "dir": hub_dir(lang),
                    "title": (
                        f"{hero['title']} — Miloš Vasić" if not hero.get("_fallback")
                        else f"Miloš Vasić — {', '.join(local_titles[:3])}"
                    ),
                    "description": (
                        f"{hero['lede']}{hero['area_list']}. {hero['stat']} — Miloš Vasić"
                        if not hero.get("_fallback")
                        else f"{', '.join(local_titles)} — Miloš Vasić"
                    ),
                    **page_social(lang, "expertise", f"{hero['title']} — Miloš Vasić"),
                    "seo_hreflang": hreflang_links(hub_paths()),
                }
            )
            + hub_page_body_localized(tiles, hero, areas, lang, local_ld),
        )

    # Localized hubs + area pages for every overlay language.
    for lang in LOCALES:
        if lang != "en":
            write_hub(lang)

    # Hub page (EN).
    titles = [
        {"title": a.title, "tagline": a.tagline, "url": f"{SITE_URL}/expertise/{a.id}/"}
        for a in areas
    ]
    hub_description = (
        "Verified career paths by technology area — "
        + ", ".join(a.title for a in areas)
        + f". Each area links to the full experience behind it. — Miloš Vasić"
    )
    write_file(
        "expertise/index.html",
        front_matter(
            {
                "layout": "default",
                "lang": "en",
                "title": "Expertise — Miloš Vasić",
                "description": hub_description,
                **page_social("en", "expertise", "Expertise — Miloš Vasić"),
                "seo_hreflang": hreflang_links(hub_paths()),
            }
        )
        + hub_page_body(titles, areas, docs, years_experience),
    )

    # Area pages (EN first — localized variants come in later phases).
    for a in areas:
        doc = docs[a.id]
        narrative = NARRATIVE[a.id]
        write_file(
            f"expertise/{a.id}/index.html",
            front_matter(
                {
                    "layout": "default",
                    "lang": "en",
                    "area": a.id,
                    "title": f"{a.title} — Miloš Vasić",
                    "description": (
                        f"{a.tagline} — Verified career work and experience for {a.title}: "
                        f"experience, projects, skills and metrics — Miloš Vasić"
                    ),
                    **page_social("en", a.id, f"{a.title} — Miloš Vasić"),
                    "seo_hreflang": hreflang_links(hub_paths(a.id)),
                }
            )
            + area_page_body(a, doc, cover_docs[a.id], narrative),
        )

    # OG cards.
    area_names = ", ".join(a.title for a in areas)
    hub_svg = (
        og_svg(
            "#050404",
            "Expertise",
            f"{len(areas)} technology areas — Miloš Vasić",
            ["AI Engineering, Android, Android TV, Android AOSP, Flutter,", "React Native, Mobile, Go, Web & Frontend, Desktop.", "15 languages"],
        )
    )
    write_file("assets/og/expertise.svg", hub_svg)
    write_file("assets/og/expertise.png", _render_png(hub_svg))
    for a in areas:
        svg = og_svg(a.accent, a.title, a.tagline, [area_names, "milosvasic.ru"])
        write_file(f"assets/og/{a.id}.svg", svg)
        write_file(f"assets/og/{a.id}.png", _render_png(svg))

    # sitemap.xml is NOT generated here: the Go generator (_tools/gen/seo.go) is its
    # only writer (it emits the xhtml hreflang alternates). `--urls` exposes the
    # expertise URL list for it to check against.
    return dict(_COLLECT)


def _b(v: "str | bytes") -> bytes:
    return v if isinstance(v, bytes) else v.encode("utf-8")


def emit_files(files: dict[str, str], out: Path) -> tuple[int, int]:
    """Write files under ``out``; skip byte-identical ones (mtime-stable).

    Returns (written, unchanged).
    """
    written = unchanged = 0
    for rel in sorted(files):
        path = out / rel
        data = _b(files[rel])
        if path.is_file() and path.read_bytes() == data:
            unchanged += 1
            continue
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
        written += 1
    return written, unchanged


def check_files(files: dict[str, str], out: Path) -> list[str]:
    """Relative paths whose on-disk bytes under ``out`` differ from ``files``."""
    return [
        rel for rel in sorted(files)
        if not (out / rel).is_file() or (out / rel).read_bytes() != _b(files[rel])
    ]


class _Parser(argparse.ArgumentParser):
    def error(self, message: str) -> None:  # unknown args -> rc 2, nothing written
        self.print_usage(sys.stderr)
        print(f"{self.prog}: error: {message}", file=sys.stderr)
        raise SystemExit(2)


def main(argv: list[str] | None = None) -> int:
    ap = _Parser(
        prog="expertise_pages.py",
        description="Generate the expertise hub/area pages, OG cards and sitemap. "
        "Default writes into the LIVE site (milosvasic.ru).",
    )
    ap.add_argument("--out-dir", metavar="DIR", help="write the generated tree into DIR instead of the live site")
    ap.add_argument("--check", action="store_true",
                    help="compare a fresh generation byte-for-byte to disk (live site or --out-dir); "
                    "rc 0 identical, 1 differs, 2 cannot determine; writes nothing")
    ap.add_argument("--urls", action="store_true", help="print every expertise URL (for the Go sitemap generator to cross-check); writes nothing")
    ap.add_argument("--list", action="store_true", help="print the relative paths that would be generated; writes nothing")
    args = ap.parse_args(argv)
    if args.urls:
        try:
            ids = [a.id for a in sorted(model.load_model().areas, key=lambda a: a.order)]
        except Exception as exc:
            print(f"cannot determine: {exc}", file=sys.stderr)
            return 2
        print("\n".join(sitemap_expertise_urls(ids)))
        return 0
    out = Path(args.out_dir) if args.out_dir else SITE
    try:
        files = generate()
    except Exception as exc:  # cannot determine / cannot generate
        print(f"cannot generate: {exc}", file=sys.stderr)
        return 2
    if args.list:
        for rel in sorted(files):
            print(rel)
        return 0
    if args.check:
        diff = check_files(files, out)
        if diff:
            print(f"DIFFERS: {len(diff)} of {len(files)} file(s) under {out}:")
            for rel in diff:
                print(f"  {rel}")
            return 1
        print(f"IDENTICAL: {len(files)} file(s) under {out}")
        return 0
    written, unchanged = emit_files(files, out)
    print(f"generated {len(files)} files into {out}: {written} written, {unchanged} unchanged")
    return 0


if __name__ == "__main__":
    sys.exit(main())
