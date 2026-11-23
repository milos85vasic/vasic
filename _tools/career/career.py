#!/usr/bin/env python3
"""``career`` -- the milosvasic.ru career-document engine CLI.

Subcommands::

    career catalog [--lang L] [--langs]   dump translatable strings (for translators)
    career locales [--fix]                validate every locale file (or repair via subagents)
    career screen --area A --lang L --kind cv|cover --text FILE
                                          run the HR screening gate on a rendered document
    career build [--area A] [--lang L] [--kind cv|cover] [--epoch S] [--jobs N]
                                          resolve + render + gate artifacts (plaintext, git-ignored);
                                          single-flight (flock), atomic writes, writes manifest.json
    career verify [--jobs N]              assert exactly 10 areas x 2 kinds x 15 locales = 300 PDFs +
                                          300 sources, all gate-clean, manifest matches disk
    career model [--json]                validate the DocumentModel contract (fast)

``build`` writes artifacts to the local, git-ignored plaintext directory
``<repo>/.cache-career/``.  Nothing under ``milosvasic.ru/`` ever receives
plaintext career artifacts -- the vault seals them for the admin console.
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from career import screen  # noqa: E402
from career import gates  # noqa: E402
from career.catalog import LOCALES, extract, load_locale, validate_locale  # noqa: E402
from career.model import load_model, load_areas  # noqa: E402
from career import render as render_pkg  # noqa: E402
from career import buildlib  # noqa: E402
from career import resolve  # noqa: E402
from career import overlay as overlay_mod  # noqa: E402


def _git_commit_epoch() -> int | None:
    """Committer timestamp of the repo's last commit (None when not determinable)."""
    try:
        r = subprocess.run(["git", "-C", str(Path(__file__).resolve().parent), "log", "-1", "--format=%ct"],
                           capture_output=True, text=True, timeout=30)
        return int(r.stdout.strip()) if r.returncode == 0 and r.stdout.strip() else None
    except (OSError, ValueError, subprocess.SubprocessError):
        return None


def _epoch(args) -> int:
    """Pinned ``--epoch``, else ``SOURCE_DATE_EPOCH``, else the last commit time.

    Never the wall clock: a build must be reproducible from the source tree, and
    ``time.time()`` made every rebuild differ.  Cannot determine -> exit 2.
    """
    if args.epoch:
        return int(args.epoch)
    raw = os.environ.get("SOURCE_DATE_EPOCH")
    if raw:
        return int(raw)
    ts = _git_commit_epoch()
    if ts is None:
        print("CANNOT DETERMINE build epoch: pass --epoch, set SOURCE_DATE_EPOCH, "
              "or run inside the git checkout", file=sys.stderr)
        raise SystemExit(2)
    return ts


def cmd_catalog(args) -> int:
    from career.catalog import extract
    if args.langs:
        print("\n".join(LOCALES))
        return 0
    entries = extract(load_model().profile, load_areas())
    print(json.dumps([{"key": e.key, "en": e.en, "where": e.where} for e in entries],
                     ensure_ascii=False, indent=1))
    return 0


def cmd_screen(args) -> int:
    model = load_model()
    doc = resolve.resolve(model, args.area, args.lang, kind=args.kind, epoch=_epoch(args))
    text = args.text
    if text:
        text = Path(text).read_text(encoding="utf-8")
    else:
        pdf = _latest_pdf(args)
        if pdf is None:
            print(f"no built artifact found for {args.area}/{args.lang}/{args.kind}", file=sys.stderr)
            return 2
        text = _extract_text(pdf)
    report = screen.screen_document(doc, text, kind=args.kind)
    print(report.summary())
    for f in report.findings:
        print(f"  [{f.severity:4}] {f.family:10} {f.id:26} {f.message}")
    if report.fail():
        return 1
    return 0


def _latest_pdf(args) -> Path | None:
    d = _plaintext_dir()
    if not d.is_dir():
        return None
    candidates = sorted(d.glob(f"{args.kind}-{args.area}-{args.lang}.pdf"))
    return candidates[-1] if candidates else None


def _plaintext_dir() -> Path:
    override = os.environ.get("CAREER_OUTDIR")  # experiments/tests; the real build never sets it
    if override:
        return Path(override)
    repo = Path(__file__).resolve().parents[2]
    return repo / ".cache-career"


def _extract_text(pdf: Path) -> str:
    import subprocess
    r = subprocess.run(["pdftotext", "-layout", str(pdf), "-"], capture_output=True, text=True, timeout=60)
    if r.returncode != 0:
        raise RuntimeError(f"pdftotext failed for {pdf}: {r.stderr}")
    return gates._strip_bidi_controls(r.stdout)  # pdftotext's own RLE/LRE/PDF wrappers


_WORKER: dict = {}


def _worker_model():
    if "model" not in _WORKER:
        _WORKER["model"] = load_model()
    return _WORKER["model"]


def _contact_labels(doc: dict) -> list[str]:
    return [c["label"] for c in doc["identity"].get("contact", []) if c.get("label")]


def _build_one(task):
    """Resolve, render and gate ONE artifact.  Runs in a worker process.

    Returns a plain dict (picklable).  ``rc`` follows the repo contract:
    0 gates pass, 1 gate/build failure, 2 cannot determine (missing font/tool).
    """
    area, kind, lang, epoch, outdir = task
    from career.render import build as render_build
    from career.render.fonts import FontMissing
    st = buildlib.stem(area, kind, lang)
    try:
        doc = resolve.resolve(_worker_model(), area, lang, kind=kind, epoch=epoch,
                              overlay=overlay_mod.load_overlay())
        paths = render_build(doc, Path(outdir), st, epoch=epoch)
        rc, msg = gates.validate_pdf(paths["pdf"], kind, lang, buildlib.key_phrases(doc),
                                     _contact_labels(doc))
        return {"stem": st, "lang": lang, "rc": rc, "msg": msg}
    except FontMissing as exc:
        return {"stem": st, "lang": lang, "rc": 2, "msg": f"CANNOT DETERMINE: {exc}"}
    except Exception as exc:  # noqa: BLE001 -- a render failure is a result, not a crash
        return {"stem": st, "lang": lang, "rc": 1, "msg": f"render failed: {str(exc)[-600:]}"}


def _locale_table(results: list[dict]) -> str:
    rows: dict[str, list[int]] = {}
    for r in results:
        c = rows.setdefault(r["lang"], [0, 0, 0])
        c[min(r["rc"], 2)] += 1
    lines = ["locale  pass  fail  undetermined"]
    for lang in sorted(rows):
        p, f, u = rows[lang]
        lines.append(f"{lang:<6} {p:>5} {f:>5} {u:>6}")
    return "\n".join(lines)


def cmd_build(args) -> int:
    areas = load_areas()
    epoch = _epoch(args)
    outdir = _plaintext_dir()
    try:
        if overlay_mod.load_overlay() is not None:
            overlay_mod.assert_safe_outdir(outdir, overlay_mod.private_dir())
    except overlay_mod.OverlayError as exc:
        print(f"CANNOT BUILD: {exc}", file=sys.stderr)
        return 2
    langs = [args.lang] if args.lang else list(LOCALES)
    bad = [l for l in langs if l not in LOCALES]
    if bad:
        print(f"locale(s) not in LOCALES: {', '.join(bad)}", file=sys.stderr)
        return 2
    triples = buildlib.matrix([a.id for a in areas], langs, area=args.area, kind=args.kind)
    jobs = buildlib.effective_jobs(args.jobs)
    if jobs < args.jobs:
        print(f"jobs capped {args.jobs} -> {jobs} (free RAM {buildlib.available_mib()} MiB)")
    full = not (args.area or args.lang or args.kind)
    try:
        with buildlib.build_lock(outdir):
            tasks = [(a, k, l, epoch, str(outdir)) for a, k, l in triples]
            results = buildlib.run_pool(_build_one, tasks, jobs, processes=True)
            for r in results:
                print(f"build {r['stem']}: gates {r['rc']}")
                if r["rc"] != 0:
                    print(f"  FAIL: {r['msg']}", file=sys.stderr)
            bad_cells = sorted(r["stem"] for r in results if r["rc"] != 0)
            mpath = outdir / buildlib.MANIFEST_NAME
            if full:
                for name in buildlib.unexpected_files(outdir, buildlib.expected_files(triples, render_pkg.source_suffix)):
                    (outdir / name).unlink()
                    print(f"pruned stale artifact {name}")
                if bad_cells:
                    mpath.unlink(missing_ok=True)  # a stale manifest must not vouch for a failed set
                    print(f"manifest NOT written: {len(bad_cells)} failed/undetermined cell(s): "
                          + ", ".join(bad_cells[:8]), file=sys.stderr)
                else:
                    every = buildlib.matrix([a.id for a in areas], LOCALES)
                    buildlib.write_manifest(outdir, buildlib.expected_files(every, render_pkg.source_suffix), epoch)
            else:
                print("filtered build: manifest.json left untouched (only a full build may rewrite it)")
    except buildlib.BuildLocked as exc:
        print(f"CANNOT BUILD: {exc} -- a build is already running", file=sys.stderr)
        return 2
    failed = sum(1 for r in results if r["rc"] == 1)
    undet = sum(1 for r in results if r["rc"] == 2)
    print(_locale_table(results))
    print(f"built {len(results)} artifact(s), {failed} gate failure(s), {undet} undetermined")
    return 1 if failed else (2 if undet else 0)


def _verify_one(task):
    """Gate one PDF AND prove its source is current: the ``model_hash`` the
    source was rendered from must equal the freshly resolved document's hash
    (same overlay as the build), so a PDF built from an older profile fails."""
    area, kind, lang, outdir, epoch = task
    st = buildlib.stem(area, kind, lang)
    pdf = Path(outdir) / f"{st}.pdf"
    try:
        doc = resolve.resolve(_worker_model(), area, lang, kind=kind, epoch=epoch,
                              overlay=overlay_mod.load_overlay())
        rc, msg = gates.validate_pdf(pdf, kind, lang, buildlib.key_phrases(doc), _contact_labels(doc))
        src = Path(outdir) / f"{st}.{render_pkg.source_suffix(lang)}"
        have, want = buildlib.source_model_hash(src), doc["meta"]["model_hash"]
        if have != want:
            note = ("stale: source model_hash " + (have[:12] if have else "absent")
                    + f" != current {want[:12]}; rebuild")
            rc, msg = 1, (msg + "; " if rc else "") + note
    except Exception as exc:  # noqa: BLE001
        rc, msg = 2, f"could not verify: {exc}"
    return {"stem": st, "lang": lang, "rc": rc, "msg": msg}


def cmd_verify(args) -> int:
    """Completeness + integrity: exactly 10 x 2 x 15 PDFs and sources, every one
    passing the ATS gates, and ``manifest.json`` equal to the files on disk."""
    areas = load_areas()
    outdir = _plaintext_dir()
    if buildlib.build_in_progress(outdir):
        print("CANNOT VERIFY: a build holds the lock on this directory; the files are mid-rewrite",
              file=sys.stderr)
        return 2
    try:
        overlay_mod.load_overlay()
    except overlay_mod.OverlayError as exc:
        print(f"CANNOT VERIFY: {exc}", file=sys.stderr)
        return 2
    triples = buildlib.matrix([a.id for a in areas], LOCALES)
    expected = buildlib.expected_files(triples, render_pkg.source_suffix)
    problems: list[str] = []
    missing = [n for n in expected if not (outdir / n).is_file()]
    if len(triples) != 300:
        problems.append(f"matrix is {len(triples)} cells, expected 10 areas x 2 kinds x 15 locales = 300")
    if missing:
        problems.append(f"{len(missing)} expected artifact(s) missing, e.g. {missing[:3]}")
    extra = buildlib.unexpected_files(outdir, expected) if outdir.is_dir() else []
    if extra:
        problems.append(f"{len(extra)} unexpected artifact(s), e.g. {extra[:3]}")
    mpath = outdir / buildlib.MANIFEST_NAME
    epoch = None
    if not mpath.is_file():
        problems.append("manifest.json missing")
    else:
        man = json.loads(mpath.read_text(encoding="utf-8"))
        epoch = int(man.get("epoch", 0))
        if man.get("count") != 600 or set(man.get("files", {})) != set(expected):
            problems.append(f"manifest lists {man.get('count')} file(s), expected 600 matching the matrix")
        elif mpath.read_bytes() != buildlib.manifest_bytes(outdir, expected, epoch):
            problems.append("manifest sha256/size entries do not match the files on disk")
    jobs = buildlib.effective_jobs(args.jobs)
    tasks = [(a, k, l, str(outdir), epoch or 0) for a, k, l in triples if (outdir / f"{buildlib.stem(a, k, l)}.pdf").is_file()]
    results = buildlib.run_pool(_verify_one, tasks, jobs, processes=True)
    for r in results:
        if r["rc"] != 0:
            print(f"  [{r['rc']}] {r['stem']}: {r['msg']}", file=sys.stderr)
    for p in problems:
        print(f"PROBLEM: {p}", file=sys.stderr)
    print(_locale_table(results))
    ok = sum(1 for r in results if r["rc"] == 0)
    print(f"verified {ok}/{len(results)} artifact(s) passing; expected 300; {len(problems)} completeness problem(s)")
    if any(r["rc"] == 1 for r in results) or problems:
        return 1
    return 2 if any(r["rc"] == 2 for r in results) else 0


def cmd_model(args) -> int:
    model = load_model()
    errors = model.errors
    print(json.dumps({"ok": not errors, "errors": errors}, ensure_ascii=False, indent=1))
    return 0 if not errors else 1


def cmd_locales(args) -> int:
    from career.catalog import extract, load_locale
    root = Path(__file__).resolve().parents[2] / "_content" / "career" / "locales"
    root.mkdir(parents=True, exist_ok=True)
    status = 0
    cat = extract(load_model().profile, load_areas())
    for lang in LOCALES:
        if lang == "en":
            continue
        path = root / f"{lang}.yaml"
        if not path.is_file():
            print(f"{lang}: MISSING {path}")
            status = 1
            continue
        bundle = load_locale(lang, root.parents[2])
        problems = validate_locale(lang, bundle, cat)
        if problems:
            print(f"{lang}: {len(problems)} problem(s)")
            for p in problems[:5]:
                print(f"    {p}")
            status = 1
        else:
            print(f"{lang}: OK")
    return status


def cmd_private_check(args) -> int:
    return overlay_mod.private_check()


def main(argv=None) -> int:
    p = argparse.ArgumentParser(prog="career")
    sub = p.add_subparsers(dest="cmd", required=True)

    c = sub.add_parser("catalog", help="dump translatable strings")
    c.add_argument("--lang", default="en")
    c.add_argument("--langs", action="store_true")
    c.set_defaults(fn=cmd_catalog)

    l = sub.add_parser("locales", help="validate locale files")
    l.add_argument("--fix", action="store_true", help="re-run translators via subagents (not yet wired)")
    l.set_defaults(fn=cmd_locales)

    s = sub.add_parser("screen", help="run the HR screening gate")
    s.add_argument("--area", default="ai-engineering")
    s.add_argument("--lang", default="en")
    s.add_argument("--kind", choices=["cv", "cover"], default="cv")
    s.add_argument("--text", default=None)
    s.add_argument("--epoch", type=int, default=None)
    s.set_defaults(fn=cmd_screen)

    b = sub.add_parser("build", help="resolve + render + gate artifacts")
    b.add_argument("--area", default=None)
    b.add_argument("--lang", default=None)
    b.add_argument("--kind", choices=["cv", "cover"], default=None)
    b.add_argument("--epoch", type=int, default=None)
    b.add_argument("--jobs", type=int, default=2,
                   help="parallel renders (default 2; capped by free RAM and at %d)" % buildlib.MAX_JOBS)
    b.set_defaults(fn=cmd_build)

    v = sub.add_parser("verify", help="assert the full 10x2x15 matrix is built, gated and manifested")
    v.add_argument("--jobs", type=int, default=2)
    v.set_defaults(fn=cmd_verify)

    m = sub.add_parser("model", help="validate the DocumentModel contract")
    m.set_defaults(fn=cmd_model)

    pc = sub.add_parser("private-check", help="assert no overlay values leak into the public tree")
    pc.set_defaults(fn=cmd_private_check)

    args = p.parse_args(argv)
    return args.fn(args)


if __name__ == "__main__":
    sys.exit(main())
