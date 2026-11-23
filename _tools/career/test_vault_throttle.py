#!/usr/bin/env python3
"""Load / DDoS note + test for the vault console (constitution 11.4.85 / 11.4.169 'DDoS / load').

DDoS N/A RATIONALE.  The vault is a static artifact: ``milosvasic.ru/downloads/vault/*.bin`` + ``manifest.json`` served by
GitHub Pages (a CDN) and ``admin/console.html`` + two JS files.  There is NO application server, no login endpoint,
no database and no per-request computation on the operator's side: a flood of requests is absorbed (or rate-limited)
by the hosting provider and cannot exhaust anything the operator runs, so a server-side DDoS / load test has no
subject (N/A).  The residual online-guessing surface is the *client-side* console throttle, which the vault threat
model (vault.py docstring) states is UX, not defence -- the real defence is passphrase entropy + PBKDF2 600k, because
blobs/manifest are public and can be attacked offline at will.  What CAN be tested, and is tested here in a REAL
Chromium: that 200 rapid wrong-passphrase submissions neither crash the page, nor produce network traffic once the
throttle is armed, nor leak, nor lock the legitimate operator out permanently, and that back-off is 1,2,4,8,16,30,30 s.

Reuses the existing browser infrastructure by IMPORT of its Python constants (PW_LIB / skip guard from
test_vault_browser.py); the node side shares only the new vault_browser_harness.js (test_vault_browser.js
self-executes on require, so it is not edited and not imported).  Throwaway passphrase, temp dirs only.
"""
from __future__ import annotations

import json
import os
import secrets
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from career import vault  # noqa: E402
from career.test_vault_browser import HERE, PW_LIB  # noqa: E402  (imported, not edited)


@unittest.skipUnless(shutil.which("node") and PW_LIB.is_dir(),
                     "node/playwright missing -- browser throttle proof CANNOT run (not a pass)")
class Throttle(unittest.TestCase):
    res = None
    out = ""

    @classmethod
    def setUpClass(cls):
        letters = "abcdefghijklmnopqrstuvwxyz"
        cls.pw = " ".join("".join(secrets.choice(letters) for _ in range(7)) for _ in range(7))
        cls.td = tempfile.TemporaryDirectory()
        root = Path(cls.td.name) / "v"
        vault.seal_items([("android/en/cv", "cv.pdf", "application/pdf", secrets.token_bytes(2000))],
                         passphrase=cls.pw, out_root=root)
        env = dict(os.environ, VAULT_DIR=str(root), VAULT_PW=cls.pw)
        r = subprocess.run(["node", str(HERE / "test_vault_throttle_browser.js")], env=env,
                           capture_output=True, text=True, timeout=600)
        cls.rc, cls.stderr, cls.out = r.returncode, r.stderr, r.stdout
        cls.payload = json.loads(r.stdout.strip().splitlines()[-1]) if r.stdout.strip() else {"results": [], "metrics": {}}

    @classmethod
    def tearDownClass(cls):
        cls.td.cleanup()

    def test_node_ran(self):
        self.assertEqual(self.rc, 0, self.stderr[-1500:])
        self.assertTrue(self.payload["results"], "no results produced")

    def test_each_check(self):
        for x in self.payload["results"]:
            print(f"  browser {'PASS' if x['ok'] else 'FAIL'} {x['name']}: {x['detail'][:150]}")
        bad = [x for x in self.payload["results"] if not x["ok"]]
        self.assertFalse(bad, bad)

    def test_metrics_recorded(self):
        m = self.payload["metrics"]
        print("  metrics:", json.dumps(m))
        self.assertEqual(m.get("burst200_manifest_fetches_added"), 0)
        self.assertEqual(m.get("backoff_seconds"), [1, 2, 4, 8, 16, 30, 30])

    def test_passphrase_never_in_output(self):
        self.assertNotIn(self.pw, self.out + self.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=2)
