#!/usr/bin/env python3
"""Real-browser geometry test for the expertise hub tiles (EN + a localized hub).

Builds a harness page from the generator's own hub functions plus the real
design-system CSS, serves it from a temp dir on a free 127.0.0.1 port, and
asserts title / tagline / metric / projects boxes never intersect and stay
inside their tile, at 1280 and 400 px, light and dark.  Skips (never passes)
when node/playwright/chromium is unavailable.
"""
from __future__ import annotations

import functools, http.server, json, shutil, subprocess, sys, tempfile, threading, unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "_tools"))
from career import expertise_pages as ep, model, resolve  # noqa: E402

CSS = ROOT / "design-system/brand-milosvasic/milosvasic.css"
PROBE = Path(__file__).with_name("tile_geometry_probe.js")
PW = ROOT / "_tests/node_modules/playwright"


def _harness(body: str) -> str:
    return ('<!doctype html><html lang="en" data-theme="light"><head><meta charset="utf-8">'
            '<meta name="viewport" content="width=device-width,initial-scale=1">'
            '<link rel="stylesheet" href="/milosvasic.css"></head><body><main>'
            + body + '</main></body></html>')


def _inter(a, b) -> bool:
    return a[0] < b[2] - 0.5 and b[0] < a[2] - 0.5 and a[1] < b[3] - 0.5 and b[1] < a[3] - 0.5


def _inside(inner, outer) -> bool:
    return (inner[0] >= outer[0] - 1 and inner[1] >= outer[1] - 1
            and inner[2] <= outer[2] + 1 and inner[3] <= outer[3] + 1)


class _Quiet(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *a, **k):
        pass


class TileGeometry(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if not shutil.which("node") or not PW.is_dir():
            raise unittest.SkipTest("node/playwright unavailable (rc 2, not a pass)")
        m = model.load_model()
        areas = sorted(m.areas, key=lambda a: a.order)
        docs = {a.id: resolve.resolve(m, a.id, "en", kind="cv", epoch=ep.EPOCH) for a in areas}
        titles = [{"title": a.title, "tagline": a.tagline, "url": ""} for a in areas]
        en = ep.hub_page_body(titles, areas, docs, 17)
        tiles = [ep.hub_tile_localized(a.id, docs[a.id], a.title, a.tagline,
                                       ", ".join(p["name"] for p in docs[a.id]["projects"][:3]),
                                       url="/x/", index=str(a.order).zfill(2)) for a in areas]
        loc = ep.hub_page_body_localized(tiles, {"eyebrow": "e", "title": "t", "lede": "l ",
                                                 "stat": "s", "area_list": "a"}, areas)
        cls.tmp = Path(tempfile.mkdtemp())
        (cls.tmp / "en.html").write_text(_harness(en), encoding="utf-8")
        (cls.tmp / "loc.html").write_text(_harness(loc), encoding="utf-8")
        shutil.copy(CSS, cls.tmp / "milosvasic.css")
        handler = functools.partial(_Quiet, directory=str(cls.tmp))
        cls.srv = http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler)
        cls.base = f"http://127.0.0.1:{cls.srv.server_address[1]}"
        threading.Thread(target=cls.srv.serve_forever, daemon=True).start()

    @classmethod
    def tearDownClass(cls):
        cls.srv.shutdown(); cls.srv.server_close(); shutil.rmtree(cls.tmp, ignore_errors=True)

    def _run(self, page):
        r = subprocess.run(["node", str(PROBE), self.base, page], capture_output=True, text=True, timeout=120)
        if r.returncode != 0:
            self.skipTest("browser could not run: " + r.stderr[-300:])
        return json.loads(r.stdout)

    def _check(self, page):
        runs = self._run(page)
        self.assertEqual(len(runs), 4)
        bad = []
        for run in runs:
            self.assertEqual(len(run["tiles"]), 10)
            for t in run["tiles"]:
                parts = {k: t[k] for k in ("title", "tagline", "metric", "projects") if t[k]}
                self.assertIn("title", parts); self.assertIn("tagline", parts)
                tw = t["tile"][2] - t["tile"][0]
                for x in ("title", "tagline"):
                    w = parts[x][2] - parts[x][0]
                    if w < min(120, tw * 0.4):
                        bad.append((run["width"], run["theme"], t["area"], x, f"squeezed to {w:.0f}px"))
                if parts["tagline"][1] < parts["title"][3] - 0.5:
                    bad.append((run["width"], run["theme"], t["area"], "tagline above title bottom"))
                names = list(parts)
                for i, x in enumerate(names):
                    if not _inside(parts[x], t["tile"]):
                        bad.append((run["width"], run["theme"], t["area"], x, "outside tile"))
                    for y in names[i + 1:]:
                        if _inter(parts[x], parts[y]):
                            bad.append((run["width"], run["theme"], t["area"], x, y))
        self.assertEqual(bad, [])

    def test_en_hub(self):
        self._check("/en.html")

    def test_localized_hub(self):
        self._check("/loc.html")


if __name__ == "__main__":
    unittest.main()
