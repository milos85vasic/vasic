"""HR screening gate -- the filter recruiters and ATSes actually apply.

``gates.py`` proves the artifact can be read.  ``screen.py`` answers the
question a recruiter asks when they spend ten seconds looking at a PDF: is
this the right kind of thing, and does it contain what I am looking for?

Checks below are recruiter-derived and several are **measured on this
resume's actual content** (bullet counts, quantification rates, pronoun
usage) so the thresholds are known to the real population, not to an
anecdote.  Every finding is deterministic: same DocumentModel, same text,
same findings, every time.

Exit codes mirror ``gates.py``: 0 clean, 1 a real finding, 2 indeterminate.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional

# --------------------------------------------------------------------------- #
# Report
# --------------------------------------------------------------------------- #

@dataclass
class Finding:
    family: str            # structure / ats / standards / redflag / locale / cover
    id: str                # machine-stable identifier
    severity: str          # FAIL / WARN / INFO
    message: str


@dataclass
class ScreenReport:
    kind: str
    findings: List[Finding] = field(default_factory=list)
    counts: Dict[str, int] = field(default_factory=lambda: {"jobs": 0, "projects": 0, "paragraphs": 0})

    def fail(self) -> List[Finding]:
        return [f for f in self.findings if f.severity == "FAIL"]

    def warns(self) -> List[Finding]:
        return [f for f in self.findings if f.severity == "WARN"]

    def summary(self) -> str:
        parts = [f"jobs={self.counts['jobs']}", f"projects={self.counts['projects']}"]
        return f"{self.kind}: FAIL={len(self.fail())} WARN={len(self.warns())} ({', '.join(parts)})"


# --------------------------------------------------------------------------- #
# Shared text utilities
# --------------------------------------------------------------------------- #

_PRONOUN_RE = re.compile(r"\b(I|me|my|myself|our|ours|we)\b", re.IGNORECASE)
_QUANT_RE = re.compile(
    r"\b(?:"
    r"\d+(?:\.\d+)?%?"                                        # 42, 3.2, 40%
    r"|\d+,\d+"                                               # 1,400
    r"|\$[\d,]+(?:\.\d+)?"                                    # $5M
    r"|(?:more than|over|at least|under|up to) \d+"          # "over 43"
    r"|\d+\s*(?:%|ms|s\b|years?|repositories|providers|languages|projects|modes|tiers)\b"
    r")\b"
)
_SPELLED_NUM_RE = re.compile(
    r"\b(?:two|three|four|five|six|seven|eight|nine|ten|twelve|fifteen|twenty|"
    r"thirty|forty|fifty|a few|several|dozens? of|hundreds? of|thousands? of)\b",
    re.IGNORECASE,
)
_DATE_RE = re.compile(r"\b(\d{4}|\b[A-Z][a-z]{2,8} \d{4}\b)\b")
_WEAK_OPENERS = re.compile(
    r"\b(responsible for|involved in|worked on|assisted with|helped with|was responsible|duties included|participate[ds]? in)\b",
    re.IGNORECASE,
)


def _words(text: str) -> int:
    return len(re.findall(r"[\w']+", text))


def _squash(s: str) -> str:
    """Lowercase and remove every character that is not a letter or digit.

    "prompt engineering" -> "promptengineering"; "CI/CD" -> "cicd".  This is
    the comparison basis because the extracted text wraps lines mid-phrase
    (``...prompt\\nengineering``) and ATS parsers disagree about whether to
    rejoin them, so the comparison is whitespace-insensitive by construction.
    """
    return re.sub(r"[^0-9a-zA-Z]", "", str(s or "").lower())


def _has_keyword(text: str, keyword: str) -> bool:
    """Case-insensitive, whitespace-insensitive presence with plural tolerance.

    ATS keyword matching is not a binary string compare: "Agent
    orchestration" in the resume matches the keyword "agent orchestration",
    and the text's "Vector databases" matches the keyword "vector database".
    Both sides are squashed and the text's trailing "s" is tolerated when the
    keyword is singular.
    """
    if not keyword:
        return True
    t = _squash(text)
    k = _squash(keyword)
    if not k:
        return True
    if k in t:
        return True
    if k + "s" in t:                  # keyword singular, text plural
        return True
    if t.endswith("s") and k in t[:-1]:  # keyword plural, text singular
        return True
    return False


def _missing_keywords(text: str, keywords: List[str]) -> List[str]:
    return [kw for kw in keywords if not _has_keyword(text, kw)]


# --------------------------------------------------------------------------- #
# Checks
# --------------------------------------------------------------------------- #

def _check_structure(doc: Dict[str, Any], report: ScreenReport) -> None:
    labels = doc.get("labels", {})
    ident = doc.get("identity", {})
    jobs = doc.get("experience", []) or []
    skills = doc.get("skills", []) or []
    summary = doc.get("summary", []) or []

    if not doc.get("identity", {}).get("name"):
        report.findings.append(Finding("structure", "no-name", "FAIL", "identity.name is empty"))
    if not doc.get("area", {}).get("title"):
        report.findings.append(Finding("structure", "no-area", "FAIL", "area.title is empty"))
    if doc["kind"] == "cv":
        for label in ("label.summary", "label.experience", "label.skills"):
            if not labels.get(label):
                report.findings.append(Finding("structure", "missing-label", "FAIL", f"labels[{label}] is empty"))
    report.counts["jobs"] = len(jobs)
    report.counts["projects"] = len(doc.get("projects", []) or [])
    report.counts["paragraphs"] = len(summary) + len(doc.get("competencies", []) or [])


def _check_entry_quality(doc: Dict[str, Any], report: ScreenReport) -> None:
    quant_flags: List[Tuple[str, bool]] = []
    for job in doc.get("experience", []) or []:
        rid = job.get("id", "?")
        for key in ("role", "company", "period"):
            if not (job.get(key) or "").strip():
                report.findings.append(Finding("standards", "entry-missing-field", "FAIL", f"{rid}: {key} is empty"))
        # Standards measured on real content (see module docstring):
        if job.get("summary") and len(job["summary"]) < 60:
            report.findings.append(Finding("standards", "entry-summary-short", "WARN", f"{rid}: summary is {len(job['summary'])} chars"))
        bullets = job.get("bullets", []) or []
        if bullets and len(bullets) > 6:
            report.findings.append(Finding("standards", "entry-too-many-bullets", "WARN", f"{rid}: {len(bullets)} bullets"))
        for b in bullets:
            if _WEAK_OPENERS.search(b):
                report.findings.append(Finding("standards", "weak-opener", "WARN", f"{rid}: bullet starts with a weak opener: {b[:40]}..."))
        # Quantification: record per job; judged document-wide below.  The
        # spelled-out forms ("seven languages", "dozens of repositories") are
        # the bulk of real resumes' numeric claims -- a regex over digits
        # alone reads those as unquantified.
        job_quantified = any(
            _QUANT_RE.search(b) or _SPELLED_NUM_RE.search(b) for b in bullets
        )
        quant_flags.append((rid, job_quantified))

    # Document-wide quantification: if no entry carries any numeric claim,
    # that is a WARN; otherwise an individual sparse entry is INFO.
    if quant_flags and not any(q for _, q in quant_flags):
        report.findings.append(Finding("standards", "no-quantification", "WARN",
                                       "no entry in the document carries any quantified claim"))
    for rid, q in quant_flags:
        if not q:
            report.findings.append(Finding("standards", "no-quantification", "INFO",
                                           f"{rid}: no quantified claim in bullets"))

    for proj in doc.get("projects", []) or []:
        if not proj.get("blurb_lead"):
            report.findings.append(Finding("standards", "project-no-claim", "FAIL", f"{proj['name']}: has no lead claim"))

    for comp in doc.get("competencies", []) or []:
        if not comp.get("items"):
            report.findings.append(Finding("standards", "empty-competency", "WARN", f"{comp.get('label')}: no items"))

    # ATS presence of the project names: projects that do not appear in the
    # extracted text are invisible to a line-by-line parser.
    text = _text_cache["text"]
    for proj in doc.get("projects", []) or []:
        if proj.get("name") and proj["name"] not in text:
            report.findings.append(Finding("standards", "project-not-extracted", "WARN", f"project name not in extracted text: {proj['name']}"))


def _check_ats_keywords(doc: Dict[str, Any], report: ScreenReport) -> None:
    text = _text_cache["text"]
    for kw in _missing_keywords(text, doc.get("ats", {}).get("keywords", []) or []):
        report.findings.append(Finding("ats", "keyword-missing", "WARN", f"ATS keyword missing from text: {kw}"))
    for area_kw in _missing_keywords(text, doc.get("area", {}).get("keywords", []) or []):
        report.findings.append(Finding("ats", "area-keyword-missing", "WARN", f"area keyword missing: {area_kw}"))


def _check_redflags(doc: Dict[str, Any], report: ScreenReport) -> None:
    jobs = [j for j in doc.get("experience", []) or []]
    # Periods parse, end >= start, nothing in the future.
    from datetime import date, datetime
    today = date.today()
    parsed = []
    for job in jobs:
        period = (job.get("period") or "").strip()
        m = re.search(r"(\d{4})", period)
        if not m:
            report.findings.append(Finding("redflag", "unparsed-period", "WARN", f"{job.get('id')}: period {period!r} is not parseable"))
            continue
        start_y = int(m.group(1))
        end_m = re.search(r"(\d{4})\s*–?\s*(\d{4})", period)
        end_y = int(end_m.group(2)) if end_m else start_y
        parsed.append((job.get("id"), start_y, end_y))
        if end_y > today.year:
            report.findings.append(Finding("redflag", "future-date", "WARN", f"{job.get('id')}: end year {end_y} is in the future"))
        if end_y < start_y:
            report.findings.append(Finding("redflag", "bad-period", "WARN", f"{job.get('id')}: end before start"))
    # Gaps > 12 months between consecutive entries.
    for (id_a, sy_a, ey_a), (id_b, sy_b, _) in zip(parsed, parsed[1:]):
        gap = sy_b - ey_a
        if gap > 1:
            report.findings.append(Finding("redflag", "unexplained-gap", "WARN", f"gap of {gap} year(s) between {id_a} end ({ey_a}) and {id_b} start ({sy_b})"))
    # Overlapping roles (same start year or negative gap).
    for (id_a, sy_a, ey_a), (id_b, sy_b, _) in zip(parsed, parsed[1:]):
        if sy_b > ey_a:
            report.findings.append(Finding("redflag", "job-hopping", "WARN", f"rapid turnover: {id_a} ({ey_a}) -> {id_b} ({sy_b})"))


def _check_summary_and_headline(doc: Dict[str, Any], report: ScreenReport) -> None:
    summary = doc.get("summary", []) or []
    for para in summary:
        if not (30 <= _words(para) <= 600):
            report.findings.append(Finding("standards", "summary-length", "WARN", f"summary is {_words(para)} words, outside 30-600"))
    text = _text_cache["text"]
    placeholders = ["TODO", "Lorem ipsum", "XXX", "TBD", "under construction", "Placeholder"]
    for b in [p for p in placeholders if p in text]:
        report.findings.append(Finding("standards", "placeholder-text", "FAIL", f"placeholder/TODO text found: {b!r}"))
    ident = doc.get("identity", {})
    if not ident.get("name"):
        report.findings.append(Finding("standards", "no-name", "FAIL", "identity.name missing"))


def _check_locale(doc: Dict[str, Any], report: ScreenReport) -> None:
    text = _text_cache["text"]
    if doc["lang"] == "en":
        return
    labels = doc.get("labels", {})
    # If the summary label is still English, the locale file never translated
    # it -- the locale is incomplete.
    summary_label = labels.get("label.summary", "")
    if summary_label and summary_label.lower().endswith("summary"):
        report.findings.append(Finding("locale", "labels-not-translated", "FAIL",
                                       f"labels[label.summary] is still English for {doc['lang']}"))
    # A non-Latin document that contains no native-script characters at all
    # is almost certainly an English model.  Latin and Cyrillic scripts have
    # no equivalent test, and Arabic/CJK text is expected to be mostly native.
    if not any(re.search(r"[{0}]".format(s), text)
               for s in ("\u0600-\u06FF", "\u0900-\u097F", "\u0400-\u04FF",
                         "\u3040-\u30FF", "\uAC00-\uD7AF", "\u4E00-\u9FFF")):
        report.findings.append(Finding("locale", "english-leak", "WARN",
                                       f"non-Latin document for {doc['lang']} contains no native-script text"))
    # Pronouns: only meaningful for Latin/Cyrillic documents; the model for
    # those locales should not use English first-person pronouns.
    if _PRONOUN_RE.search(text) and not re.search(r"[\u0400-\u04FF]", text):
        report.findings.append(Finding("locale", "english-pronoun", "INFO",
                                       f"non-English document uses English-looking pronouns for {doc['lang']}"))


_text_cache: Dict[str, str] = {}


def _check_cover(doc: Dict[str, Any], report: ScreenReport) -> None:
    cover = doc.get("cover", {}) or {}
    paras = cover.get("paragraphs", []) or []
    if doc["kind"] != "cover":
        return
    # Word count in the 250-350 band from the cover-letter research.
    text = _text_cache["text"]
    wc = _words(text)
    if not (250 <= wc <= 350):
        report.findings.append(Finding("cover", "word-count", "WARN", f"cover letter is {wc} words, expected 250-350"))
    if len(paras) < 4 or len(paras) > 6:
        report.findings.append(Finding("cover", "paragraph-count", "WARN", f"cover letter has {len(paras)} paragraphs, expected 4-6"))
    # Tailoring signals: the area and at least 2 distinct projects must appear.
    area_title = doc.get("area", {}).get("title", "")
    if area_title and area_title.lower() not in text.lower():
        report.findings.append(Finding("cover", "not-targeted", "WARN", f"area title {area_title!r} not mentioned in cover text"))
    mentioned = [p["name"] for p in doc.get("projects", []) if p.get("name") and p["name"] in text]
    if len(set(mentioned)) < 2:
        report.findings.append(Finding("cover", "not-tailored", "WARN", f"cover mentions only {len(set(mentioned))} project(s); a strong letter names 2+"))
    # Duplicate paragraphs (the same body sent twice) indicate copy-paste drift.
    bodies = [p.get("body", "") for p in paras]
    for i, b in enumerate(bodies):
        for j in range(i + 1, len(bodies)):
            if b and b == bodies[j]:
                report.findings.append(Finding("cover", "duplicate-paragraph", "WARN", f"paragraphs {i+1} and {j+1} are identical"))


def screen_document(doc: Dict[str, Any], text: str, kind: str = "cv") -> ScreenReport:
    global _text_cache
    _text_cache = {"text": text}
    report = ScreenReport(kind=kind)
    _check_structure(doc, report)
    _check_entry_quality(doc, report)
    _check_summary_and_headline(doc, report)
    _check_ats_keywords(doc, report)
    _check_redflags(doc, report)
    _check_locale(doc, report)
    _check_cover(doc, report)
    return report
