#!/usr/bin/env python3
"""CLI safety tests for expertise_pages.py (--help/--out-dir/--check/--list,
idempotent + mtime-stable writes, determinism).

Run:  python3 -m unittest discover -s _tools/career -p 'test_expertise*.py'
"""
from __future__ import annotations

import hashlib
import os
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from career import expertise_pages as ep  # noqa: E402

SCRIPT = Path(ep.__file__).resolve()
SITE = ep.SITE
_cache: dict[str, dict[str, str]] = {}


def tree_hash(root: Path, subs=("expertise", "assets/og")) -> str:
    h = hashlib.sha256()
    for sub in subs:
        for p in sorted((root / sub).rglob("*")):
            if p.is_file():
                h.update(str(p.relative_to(root)).encode())
                h.update(p.read_bytes())
    sm = root / "sitemap.xml"
    if sm.is_file():
        h.update(sm.read_bytes())
    return h.hexdigest()


def run(*args: str) -> subprocess.CompletedProcess:
    return subprocess.run([sys.executable, str(SCRIPT), *args], capture_output=True, text=True, timeout=300)


def tree_files(root: Path) -> dict[str, bytes]:
    return {str(p.relative_to(root)): p.read_bytes() for p in sorted(root.rglob("*")) if p.is_file()}


class Cli(unittest.TestCase):
    def test_help_exits_0_and_writes_nothing(self):
        before = tree_hash(SITE)
        r = run("--help")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("--out-dir", r.stdout)
        self.assertEqual(tree_hash(SITE), before)

    def test_unknown_arg_exits_2_and_writes_nothing(self):
        before = tree_hash(SITE)
        r = run("--bogus")
        self.assertEqual(r.returncode, 2)
        r = run("positional")
        self.assertEqual(r.returncode, 2)
        self.assertEqual(tree_hash(SITE), before)

    def test_list_writes_nothing(self):
        before = tree_hash(SITE)
        r = run("--list")
        self.assertEqual(r.returncode, 0, r.stderr)
        lines = r.stdout.split()
        self.assertIn("expertise/index.html", lines)
        self.assertNotIn("sitemap.xml", lines)
        self.assertEqual(tree_hash(SITE), before)

    def test_out_dir_leaves_live_tree_untouched(self):
        before = tree_hash(SITE)
        with tempfile.TemporaryDirectory() as d:
            r = run("--out-dir", d)
            self.assertEqual(r.returncode, 0, r.stderr)
            self.assertTrue((Path(d) / "expertise" / "index.html").is_file())
            self.assertFalse((Path(d) / "sitemap.xml").exists())
        self.assertEqual(tree_hash(SITE), before)

    def test_check_rc0_after_generation_rc1_after_modification(self):
        with tempfile.TemporaryDirectory() as d:
            self.assertEqual(run("--out-dir", d).returncode, 0)
            r = run("--check", "--out-dir", d)
            self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
            victim = Path(d) / "expertise" / "index.html"
            victim.write_text(victim.read_text(encoding="utf-8") + "\n<!-- hand edit -->\n", encoding="utf-8")
            before = tree_files(Path(d))
            r = run("--check", "--out-dir", d)
            self.assertEqual(r.returncode, 1)
            self.assertIn("expertise/index.html", r.stdout)
            self.assertEqual(tree_files(Path(d)), before, "--check must not write")

    def test_check_missing_file_is_a_difference(self):
        with tempfile.TemporaryDirectory() as d:
            self.assertEqual(run("--out-dir", d).returncode, 0)
            (Path(d) / "assets" / "og" / "expertise.svg").unlink()
            r = run("--check", "--out-dir", d)
            self.assertEqual(r.returncode, 1)
            self.assertIn("assets/og/expertise.svg", r.stdout)

    def test_rerun_preserves_mtimes_and_rewrites_only_changed(self):
        with tempfile.TemporaryDirectory() as d:
            self.assertEqual(run("--out-dir", d).returncode, 0)
            files = [p for p in Path(d).rglob("*") if p.is_file()]
            old = time.time() - 86400
            for p in files:
                os.utime(p, (old, old))
            stamps = {p: p.stat().st_mtime_ns for p in files}
            self.assertEqual(run("--out-dir", d).returncode, 0)
            for p in files:
                self.assertEqual(p.stat().st_mtime_ns, stamps[p], f"rewritten: {p}")
            # a hand-modified file is restored; its neighbours stay untouched
            victim = Path(d) / "expertise" / "index.html"
            victim.write_text("x", encoding="utf-8")
            os.utime(victim, (old, old))
            self.assertEqual(run("--out-dir", d).returncode, 0)
            self.assertNotEqual(victim.read_text(encoding="utf-8"), "x")
            for p in files:
                if p != victim:
                    self.assertEqual(p.stat().st_mtime_ns, stamps[p])

    def test_determinism_in_process(self):
        a = ep.generate()
        b = ep.generate()
        self.assertEqual(a, b)
        self.assertGreater(len(a), 100)

    def test_determinism_across_processes(self):
        with tempfile.TemporaryDirectory() as d1, tempfile.TemporaryDirectory() as d2:
            self.assertEqual(run("--out-dir", d1).returncode, 0)
            self.assertEqual(run("--out-dir", d2).returncode, 0)
            self.assertEqual(tree_files(Path(d1)), tree_files(Path(d2)))


if __name__ == "__main__":
    unittest.main()


class SitemapNotOwned(unittest.TestCase):
    def test_never_writes_or_checks_sitemap(self):
        sm = SITE / "sitemap.xml"
        before = hashlib.sha256(sm.read_bytes()).hexdigest()
        with tempfile.TemporaryDirectory() as d:
            self.assertEqual(run("--out-dir", d).returncode, 0)
            self.assertFalse((Path(d) / "sitemap.xml").exists())
            (Path(d) / "sitemap.xml").write_text("garbage")
            self.assertEqual(run("--check", "--out-dir", d).returncode, 0)  # ignored by --check
        self.assertEqual(hashlib.sha256(sm.read_bytes()).hexdigest(), before)

    def test_urls_exposed(self):
        r = run("--urls")
        self.assertEqual(r.returncode, 0, r.stderr)
        lines = r.stdout.split()
        self.assertEqual(len(lines), 165)
        self.assertEqual(len(set(lines)), 165)
