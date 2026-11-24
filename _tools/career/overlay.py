"""Private overlay for the career engine.

``CAREER_PRIVATE_DIR`` (unset by default => no overlay) points at a checkout of
the private companion repository. ``<dir>/overlay.yaml`` carries sensitive
identity fields that are deep-merged over the public profile identity for
PDF/vault builds ONLY. Nothing here reads or prints values into messages:
errors name keys and paths, never values.
"""

from __future__ import annotations

import json
import os
import re
import subprocess
from pathlib import Path
from typing import Any, Mapping, Optional

import yaml

ENV = "CAREER_PRIVATE_DIR"
OVERLAY_FILE = "overlay.yaml"
SCHEMA = "career.overlay.v1"
REPO_ROOT = Path(__file__).resolve().parents[2]
CACHE_DIR = REPO_ROOT / ".cache-career"
MIN_VALUE_LEN = 4

#: key -> allowed value kind
ALLOWED: dict[str, str] = {
    "schema": "str",
    "phone": "str",
    "address": "str",
    "salary_expectation": "str",
    "referees": "list",
    "private_notes": "str",
    # job_seeker scoring keys (JSK-T011; contract overlay-and-config.md, FR-055)
    "salary_min": "int",
    "salary_currency": "iso4217",
    "salary_period": "period",
    "tz_window": "tz_window",
    "allowed_onsite_cities": "strlist",
    "blocked_companies": "strlist",
    "eligible_countries": "iso3166list",
}
#: scoring-only keys: validated and readable, never merged into PDF/vault identity
SCORING_KEYS: tuple[str, ...] = (
    "salary_min", "salary_currency", "salary_period", "tz_window",
    "allowed_onsite_cities", "blocked_companies", "eligible_countries",
)
_PERIODS = ("year", "month", "hour")
_CCY = re.compile(r"[A-Z]{3}")
_CC = re.compile(r"[A-Z]{2}")
# built by concatenation so this source file itself carries no literal repo name
_NAME = "career" + "_" + "private"


class OverlayError(Exception):
    """Overlay problem. The message never contains an overlay value."""


def private_dir(env: Optional[Mapping[str, str]] = None) -> Optional[Path]:
    e = os.environ if env is None else env
    v = e.get(ENV)
    return Path(v) if v else None


def deep_merge(base: Mapping[str, Any], over: Mapping[str, Any]) -> dict[str, Any]:
    out = dict(base)
    for k, v in over.items():
        if isinstance(v, Mapping) and isinstance(out.get(k), Mapping):
            out[k] = deep_merge(out[k], v)
        else:
            out[k] = v
    return out


def _is_int(v: Any) -> bool:
    return isinstance(v, int) and not isinstance(v, bool)


def _kind_ok(kind: str, v: Any) -> bool:
    """Type/shape check only; callers never echo ``v``."""
    if kind == "str":
        return isinstance(v, str)
    if kind == "list":
        return isinstance(v, list)
    if kind == "int":
        return _is_int(v) and v >= 0
    if kind == "iso4217":
        return isinstance(v, str) and bool(_CCY.fullmatch(v))
    if kind == "period":
        return isinstance(v, str) and v in _PERIODS
    if kind == "tz_window":
        return (isinstance(v, dict) and set(v) == {"start_utc", "end_utc"}
                and all(_is_int(x) and 0 <= x <= 24 for x in v.values()))
    if kind == "strlist":
        return isinstance(v, list) and all(isinstance(x, str) and x.strip() for x in v)
    if kind == "iso3166list":
        return isinstance(v, list) and all(isinstance(x, str) and _CC.fullmatch(x) for x in v)
    return False


_KIND_MSG = {
    "str": "must be a string", "list": "must be a list",
    "int": "must be a non-negative integer", "iso4217": "must be an ISO 4217 code",
    "period": "must be one of year, month, hour",
    "tz_window": "must be a mapping of exactly start_utc and end_utc, integers 0..24",
    "strlist": "must be a list of non-empty strings",
    "iso3166list": "must be a list of upper-case ISO 3166 alpha-2 codes",
}


def validate(raw: Any) -> dict[str, Any]:
    if not isinstance(raw, dict):
        raise OverlayError(f"{OVERLAY_FILE}: top level must be a mapping")
    errors = []
    for key in raw:
        if key not in ALLOWED:
            errors.append(f"unknown key {str(key)[:40]!r} (allowed: {', '.join(sorted(ALLOWED))})")
            continue
        kind = ALLOWED[key]
        val = raw[key]
        if not _kind_ok(kind, val):
            errors.append(f"key {key!r}: {_KIND_MSG[kind]}")
    if raw.get("schema", SCHEMA) != SCHEMA:
        errors.append("key 'schema': unsupported version")
    if errors:
        raise OverlayError(f"{OVERLAY_FILE} invalid: " + "; ".join(errors))
    return raw


def load_overlay(env: Optional[Mapping[str, str]] = None) -> Optional[dict[str, Any]]:
    d = private_dir(env)
    if d is None:
        return None
    path = d / OVERLAY_FILE
    if not path.is_file():
        raise OverlayError(f"{ENV} is set but {OVERLAY_FILE} is missing in that directory")
    try:
        raw = yaml.safe_load(path.read_text(encoding="utf-8"))
    except yaml.YAMLError:
        raise OverlayError(f"{OVERLAY_FILE}: not valid YAML") from None
    return validate(raw)


def apply_identity(identity: Mapping[str, Any], ov: Optional[Mapping[str, Any]]) -> dict[str, Any]:
    if not ov:
        return dict(identity)
    return deep_merge(identity, {k: v for k, v in ov.items()
                                       if k != "schema" and k not in SCORING_KEYS})


def vault_out_dir(env: Optional[Mapping[str, str]] = None) -> Path:
    d = private_dir(env)
    if d is None:
        raise OverlayError(f"{ENV} is not set")
    return d / "vault"


def assert_safe_outdir(outdir: Path, private_dir: Optional[Path]) -> None:
    """Overlay-derived artifacts may go only to .cache-career or the private dir."""
    out = Path(outdir).resolve()

    def under(p: Path, root: Path) -> bool:
        return out == root.resolve() or root.resolve() in out.parents

    if under(out, CACHE_DIR):
        return
    if private_dir is not None and under(out, Path(private_dir)):
        return
    raise OverlayError("refusing to write overlay-derived artifacts outside .cache-career or the private dir")


# --- private-check ---------------------------------------------------------

def _values(ov: Mapping[str, Any]) -> list[str]:
    out: list[str] = []

    def walk(x: Any) -> None:
        if isinstance(x, str):
            if len(x) >= MIN_VALUE_LEN:
                out.append(x)
        elif isinstance(x, Mapping):
            for v in x.values():
                walk(v)
        elif isinstance(x, (list, tuple)):
            for v in x:
                walk(v)

    walk({k: v for k, v in ov.items() if k != "schema"})
    return out


def _files(root: Path) -> list[str]:
    r = subprocess.run(["git", "-C", str(root), "ls-files", "-co", "--exclude-standard", "-z"],
                       capture_output=True, check=True)
    return [p for p in r.stdout.decode("utf-8", "surrogateescape").split("\0") if p]


def find_value_leaks(ov: Mapping[str, Any], root: Path = REPO_ROOT) -> list[str]:
    needles = [v.encode("utf-8") for v in _values(ov)]
    hits = []
    for rel in _files(root):
        p = Path(root) / rel
        if not p.is_file() or p.is_symlink():
            continue
        try:
            data = p.read_bytes()
        except OSError:
            continue
        if any(n in data for n in needles):
            hits.append(rel)
    return sorted(hits)


def find_private_refs(root: Path = REPO_ROOT) -> list[str]:
    needle = _NAME.encode()
    hits = []
    for rel in _files(root):
        if rel.startswith("docs/"):
            continue
        p = Path(root) / rel
        if not p.is_file() or p.is_symlink():
            continue
        try:
            if needle in p.read_bytes():
                hits.append(rel)
        except OSError:
            continue
    return sorted(hits)


def visibility_rc(vis: Optional[str]) -> int:
    if vis is None:
        return 2
    return 0 if vis == "private" else 1


def private_repo_visibility(pdir: Path) -> Optional[str]:
    """Visibility of the private checkout's origin via gh; None if undeterminable."""
    try:
        url = subprocess.run(["git", "-C", str(pdir), "remote", "get-url", "origin"],
                             capture_output=True, text=True, timeout=30).stdout.strip()
        m = re.search(r"github\.com[:/]([^/]+/[^/]+?)(?:\.git)?$", url)
        if not m:
            return None
        r = subprocess.run(["gh", "api", f"repos/{m.group(1)}", "--jq", ".visibility"],
                           capture_output=True, text=True, timeout=60)
        return r.stdout.strip() or None if r.returncode == 0 else None
    except (OSError, subprocess.SubprocessError):
        return None


def private_check(env: Optional[Mapping[str, str]] = None, root: Path = REPO_ROOT) -> int:
    """0 clean, 1 finding, 2 cannot determine. Prints paths only, never values."""
    pdir = private_dir(env)
    if pdir is None:
        print(f"CANNOT DETERMINE: {ENV} is not set")
        return 2
    try:
        ov = load_overlay(env)
    except OverlayError as exc:
        print(f"CANNOT DETERMINE: {exc}")
        return 2
    rc = 0
    leaks = find_value_leaks(ov or {}, root)
    for p in leaks:
        print(f"LEAK overlay value found in: {p}")
    refs = find_private_refs(root)
    for p in refs:
        print(f"REF private-repo reference outside docs/: {p}")
    if leaks or refs:
        rc = 1
    vis = private_repo_visibility(pdir)
    vrc = visibility_rc(vis)
    print(f"private repo visibility: {vis or 'UNDETERMINED'}")
    if vrc == 1:
        rc = 1
    elif vrc == 2 and rc == 0:
        rc = 2
    print(f"private-check rc={rc} (leaks={len(leaks)} refs={len(refs)})")
    return rc
