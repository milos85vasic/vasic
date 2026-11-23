#!/usr/bin/env python3
"""Real-browser (playwright chromium) proof for the vault console. Throwaway passphrase, temp dirs only."""
from __future__ import annotations

import hashlib
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

HERE = Path(__file__).resolve().parent
PW_LIB = HERE.parents[1] / "_tests" / "node_modules" / "playwright-core"


@unittest.skipUnless(shutil.which("node") and PW_LIB.is_dir(),
                     "node/playwright missing -- browser proof CANNOT run (not a pass)")
class Browser(unittest.TestCase):
    def test_console_unlock_and_download(self):
        letters = "abcdefghijklmnopqrstuvwxyz"
        p = " ".join("".join(secrets.choice(letters) for _ in range(7)) for _ in range(7))
        its = [("android/en/cv", "cv-android-en.pdf", "application/pdf", b"%PDF-1.4 " + secrets.token_bytes(3000)),
               ("android/en/cover", "cover-android-en.pdf", "application/pdf", secrets.token_bytes(900)),
               ("go/ru/cv", "résumé-日本.pdf", "application/pdf", secrets.token_bytes(2000))]
        with tempfile.TemporaryDirectory() as d:
            root = Path(d) / "v"; vault.seal_items(its, passphrase=p, out_root=root)
            ex = Path(d) / "expect.json"
            ex.write_text(json.dumps({s: hashlib.sha256(b).hexdigest() for s, _, _, b in its}))
            env = dict(os.environ, VAULT_DIR=str(root), VAULT_PW=p, EXPECT=str(ex))
            r = subprocess.run(["node", str(HERE / "test_vault_browser.js")], env=env,
                               capture_output=True, text=True, timeout=300)
            self.assertEqual(r.returncode, 0, r.stderr[-2000:])
            res = json.loads(r.stdout.strip().splitlines()[-1])["results"]
            for x in res:
                print(f"  browser {'PASS' if x['ok'] else 'FAIL'} {x['name']}: {x['detail'][:90]}")
            self.assertFalse([x for x in res if not x["ok"]], res)
            self.assertNotIn(p, r.stdout + r.stderr)


if __name__ == "__main__":
    unittest.main()
