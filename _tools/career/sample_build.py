"""Test support: build a SMALL real sample of the career matrix into a scratch directory.

Nothing here is a fixture: every PDF is rendered by the real renderer from the real
profile and judged by the real gates (``career._build_one``), and the manifest is
written by the real writer (``buildlib.write_manifest``).  The private overlay is a
throw-away directory holding a minimal valid ``overlay.yaml`` with no personal data.
"""
from __future__ import annotations

import os
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from career import buildlib, overlay as overlay_mod  # noqa: E402
from career import render as render_pkg  # noqa: E402

#: 3 locales x cv/cover on one area: LuaLaTeX Latin, LuaLaTeX Cyrillic and the WeasyPrint RTL engine.
SAMPLE_AREA = "ai-engineering"
SAMPLE_LANGS = ("en", "ru", "ar")
OVERLAY_TEXT = 'schema: career.overlay.v1\nblocked_companies:\n  - "Zqx Blocked Company"\n'
EPOCH = 1_795_000_000   # 2026-11-18; any pinned epoch (builds never read the wall clock)


def have_toolchain() -> bool:
    import shutil
    return bool(shutil.which("lualatex") and shutil.which("pdftotext"))


def build_sample(outdir: Path, private_dir: Path, *, epoch: int = EPOCH, area: str = SAMPLE_AREA,
                 langs=SAMPLE_LANGS, write: bool = True) -> dict:
    """Render + gate the sample, and (``write``) emit ``manifest.json`` with the real writer.

    Returns ``{"results": [...], "names": [...], "overlay_sha": str}``.  Raises when the
    environment cannot build (callers skip: an undetermined build is never a pass).
    """
    from career import career as cli
    (private_dir / "overlay.yaml").write_text(OVERLAY_TEXT, encoding="utf-8")
    old = os.environ.get(overlay_mod.ENV)
    os.environ[overlay_mod.ENV] = str(private_dir)
    try:
        triples = buildlib.matrix([area], list(langs))
        results = [cli._build_one((a, k, l, epoch, str(outdir))) for a, k, l in triples]
        names = buildlib.expected_files(triples, render_pkg.source_suffix)
        sha = overlay_mod.overlay_sha()
        if write:
            buildlib.write_manifest(outdir, names, epoch, overlay_sha=sha,
                                    gate_rc={r["stem"]: r["rc"] for r in results})
        return {"results": results, "names": names, "overlay_sha": sha}
    finally:
        if old is None:
            os.environ.pop(overlay_mod.ENV, None)
        else:
            os.environ[overlay_mod.ENV] = old


def scratch_pair() -> tuple[tempfile.TemporaryDirectory, Path, Path]:
    td = tempfile.TemporaryDirectory(prefix="career-sample-")
    out, priv = Path(td.name) / "out", Path(td.name) / "private"
    out.mkdir(); priv.mkdir(mode=0o700)
    return td, out, priv
