"""Build orchestration: matrix, lock, bounded parallelism, manifest, verify.

Kept out of ``career.py`` so it is testable without the profile (every function
takes its inputs).  Exit-code contract everywhere: 0 clean, 1 real failure,
2 could not determine / could not run (missing font or tool, build lock held).
"""

from __future__ import annotations

import fcntl
import hashlib
import json
import os
import re
from concurrent.futures import ProcessPoolExecutor, ThreadPoolExecutor
from contextlib import contextmanager
from pathlib import Path
from typing import Iterable, Iterator

KINDS = ("cv", "cover")
MANIFEST_NAME = "manifest.json"
LOCK_NAME = ".build.lock"
MANIFEST_SCHEMA = "career.manifest.v1"

#: Resident memory one LuaLaTeX run needs.  Measured peak is a few hundred MiB;
#: 1.2 GiB per job is a deliberately generous bound for a host shared with
#: other agents.
MEM_PER_JOB_MIB = 1200
MEM_RESERVE_MIB = 6144
MAX_JOBS = 6


#: Lock fds held by THIS process.  A forked pool worker gets a copy of each; if
#: the parent dies while a worker outlives it, the inherited copy would keep
#: the flock held.  The child closes its copies at fork (closing a duplicate
#: does not release the parent's lock: they share one open file description).
_HELD_FDS: set[int] = set()


def _close_inherited_lock_fds() -> None:
    for fd in list(_HELD_FDS):
        try:
            os.close(fd)
        except OSError:
            pass
    _HELD_FDS.clear()


os.register_at_fork(after_in_child=_close_inherited_lock_fds)


class BuildLocked(RuntimeError):
    """Another build holds the lock on this output directory."""


@contextmanager
def build_lock(outdir: Path) -> Iterator[Path]:
    """Exclusive, non-blocking ``flock`` on ``<outdir>/.build.lock``.

    Two builds writing one directory raced before (a stale run overwrote fresh
    artifacts), so a second build FAILS FAST instead of waiting or sharing.
    The kernel drops the lock if the holder dies, so there is no stale lock.
    """
    outdir.mkdir(parents=True, exist_ok=True)
    path = outdir / LOCK_NAME
    fd = os.open(path, os.O_RDWR | os.O_CREAT | os.O_CLOEXEC, 0o600)
    _HELD_FDS.add(fd)
    try:
        try:
            fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except OSError as exc:
            raise BuildLocked(f"another build holds {path}") from exc
        os.ftruncate(fd, 0)
        os.write(fd, f"{os.getpid()}\n".encode())
        yield path
    finally:
        if fd in _HELD_FDS:
            _HELD_FDS.discard(fd)
            os.close(fd)  # closing releases the flock


def build_in_progress(outdir: Path) -> bool:
    """True while another process holds the build lock on ``outdir``."""
    path = Path(outdir) / LOCK_NAME
    if not path.is_file():
        return False
    fd = os.open(path, os.O_RDONLY | os.O_CLOEXEC)
    try:
        try:
            fcntl.flock(fd, fcntl.LOCK_SH | fcntl.LOCK_NB)
        except OSError:
            return True
        return False
    finally:
        os.close(fd)


_HASH_RE = re.compile(r'(?:^%\s*model_hash=|<meta name="model-hash" content=")([0-9a-f]*)', re.M)


def source_model_hash(path: Path) -> str | None:
    """The ``model_hash`` a rendered source (.tex / .html) was generated from."""
    try:
        head = Path(path).read_text(encoding="utf-8")[:2000]
    except OSError:
        return None
    m = _HASH_RE.search(head)
    return m.group(1) if m else None


def available_mib() -> int:
    """MemAvailable from /proc/meminfo, in MiB (0 when unreadable)."""
    try:
        for line in Path("/proc/meminfo").read_text().splitlines():
            if line.startswith("MemAvailable:"):
                return int(line.split()[1]) // 1024
    except (OSError, ValueError):
        pass
    return 0


def effective_jobs(requested: int, avail_mib: int | None = None) -> int:
    """``requested`` capped by free RAM; always at least 1, at most MAX_JOBS."""
    avail = available_mib() if avail_mib is None else avail_mib
    cap = max(1, (avail - MEM_RESERVE_MIB) // MEM_PER_JOB_MIB) if avail else 1
    return max(1, min(int(requested), cap, MAX_JOBS))


def matrix(area_ids: Iterable[str], locales: Iterable[str], kinds: Iterable[str] = KINDS,
           *, area: str | None = None, lang: str | None = None,
           kind: str | None = None) -> list[tuple[str, str, str]]:
    """(area, kind, lang) triples, filtered, in a stable order."""
    out = []
    for a in area_ids:
        if area and a != area:
            continue
        for k in kinds:
            if kind and k != kind:
                continue
            for l in locales:
                if lang and l != lang:
                    continue
                out.append((a, k, l))
    return out


def stem(area: str, kind: str, lang: str) -> str:
    return f"{kind}-{area}-{lang}"


def expected_files(triples: Iterable[tuple[str, str, str]], source_suffix) -> list[str]:
    """Every file name the full matrix must produce (sorted)."""
    names = []
    for a, k, l in triples:
        s = stem(a, k, l)
        names += [f"{s}.{source_suffix(l)}", f"{s}.pdf"]
    return sorted(names)


_ARTIFACT_RE = re.compile(r"^(cv|cover)-.+-[a-z]{2,3}\.(tex|html|pdf)$")


def unexpected_files(outdir: Path, expected: Iterable[str]) -> list[str]:
    """Artifact-shaped files in ``outdir`` that no matrix cell produces."""
    want = set(expected)
    return sorted(p.name for p in outdir.iterdir()
                  if p.is_file() and _ARTIFACT_RE.match(p.name) and p.name not in want)


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def manifest_bytes(outdir: Path, names: Iterable[str], epoch: int) -> bytes:
    """Deterministic manifest: sorted keys, no wall-clock, one trailing newline."""
    files = {n: {"sha256": sha256_file(outdir / n), "bytes": (outdir / n).stat().st_size}
             for n in sorted(names) if (outdir / n).is_file()}
    doc = {"schema": MANIFEST_SCHEMA, "epoch": int(epoch), "count": len(files), "files": files}
    return (json.dumps(doc, ensure_ascii=False, sort_keys=True, indent=1) + "\n").encode("utf-8")


def write_manifest(outdir: Path, names: Iterable[str], epoch: int) -> Path:
    path = outdir / MANIFEST_NAME
    tmp = path.with_name(f".{MANIFEST_NAME}.{os.getpid()}.tmp")
    tmp.write_bytes(manifest_bytes(outdir, names, epoch))
    os.replace(tmp, path)
    return path


def key_phrases(doc: dict) -> list[str]:
    """Known source strings that must survive extraction contiguous, in order.

    The person's name, the section headings the document actually has, and the
    longest run of the headline that holds no ASCII letters/digits (a mixed
    Arabic/Latin run legitimately interleaves under bidi, a pure run must not).
    """
    lab, out = doc.get("labels", {}), []
    out.append(doc["identity"]["name"])
    if doc["kind"] == "cv":
        for key, field in (("label.summary", "summary"), ("label.competencies", "competencies"),
                           ("label.experience", "experience"), ("label.projects", "projects"),
                           ("label.skills", "skills"), ("label.education", "education"),
                           ("label.languages", "languages")):
            if doc.get(field) and lab.get(key):
                out.append(lab[key])
    if doc["kind"] != "cv":  # a cover letter has no headline/section headings
        sal = str(doc.get("cover", {}).get("salutation", "")).strip(" ,.:;!，。：！")
        return list(dict.fromkeys(out + ([sal] if len(sal) >= 4 else [])))
    runs = [r.strip(" ,.;:-—·()") for r in re.split(r"[A-Za-z0-9/+#.]+", doc["identity"]["headline"])]
    runs = [r for r in runs if len(r) >= 8]
    if runs:
        out.append(max(runs, key=len))
    return list(dict.fromkeys(out))


def run_pool(fn, items: list, jobs: int, *, processes: bool) -> list:
    """Map ``fn`` over ``items`` with ``jobs`` workers, preserving item order."""
    if jobs <= 1:
        return [fn(i) for i in items]
    pool = ProcessPoolExecutor if processes else ThreadPoolExecutor
    with pool(max_workers=jobs) as ex:
        return list(ex.map(fn, items))
