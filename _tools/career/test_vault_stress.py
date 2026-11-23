#!/usr/bin/env python3
"""Stress tests for the vault (constitution 11.4.85 / 11.4.169 'stress').

Large inputs (1 MiB, 50 MiB), many slots (300) and a measured memory ceiling.
Throwaway random passphrase, scratch temp dirs only, deterministic payloads
(seeded PRNG, no wall-clock assertions).  Memory is measured in a CHILD process
(ru_maxrss + tracemalloc) so the parent's footprint cannot mask it.

Run: python3 -m unittest _tools/career/test_vault_stress.py   (or run the file)
"""
from __future__ import annotations

import hashlib
import json
import os
import random
import secrets
import subprocess
import sys
import tempfile
import textwrap
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from career import vault  # noqa: E402

MIB = 1024 * 1024
# Stated ceilings (measured baseline in the report; generous margin).
# Peak RSS of a child that seals then unseals ONE 50 MiB blob: plaintext + blob +
# decrypt output + read buffer ~ 2.6x payload measured (129 MiB), ceiling ~6x payload incl. baseline.
CEILING_RSS_50MIB = 320 * MIB
# tracemalloc (Python-level allocations only) for the same operation.
CEILING_TRACED_50MIB = 220 * MIB
CEILING_RSS_300_SLOTS = 250 * MIB


def pw() -> str:
    letters = "abcdefghijklmnopqrstuvwxyz"
    return " ".join("".join(secrets.choice(letters) for _ in range(7)) for _ in range(7))


def payload(n: int, seed: int) -> bytes:
    return random.Random(seed).randbytes(n)


def run_child(code: str, env_extra: dict) -> dict:
    """Run python code in a child; it must print one JSON line last."""
    env = dict(os.environ, **env_extra, PYTHONPATH=str(Path(__file__).resolve().parents[1]))
    r = subprocess.run([sys.executable, "-I", "-c", textwrap.dedent(code)], env=env,
                       capture_output=True, text=True, timeout=600)
    if r.returncode != 0:
        raise AssertionError(f"child failed rc={r.returncode}: {r.stderr[-1500:]}")
    return json.loads(r.stdout.strip().splitlines()[-1])


CHILD_ROUNDTRIP = """
import hashlib, json, os, random, resource, tracemalloc, sys
sys.path.insert(0, os.environ["PYTHONPATH"])
from pathlib import Path
from career import vault
n = int(os.environ["N_BYTES"]); root = Path(os.environ["ROOT"])
data = random.Random(7).randbytes(n); want = hashlib.sha256(data).hexdigest()
tracemalloc.start()
vault.seal_items([("a/en/cv", "big.pdf", "application/pdf", data)], passphrase=os.environ["PW"], out_root=root)
del data
m, key = vault.open_vault(os.environ["PW"], root)
rec, pt = vault.unseal_slot(m, key, "a/en/cv", root)
got = hashlib.sha256(pt).hexdigest(); ln = len(pt)
cur, peak = tracemalloc.get_traced_memory()
print(json.dumps({"ok": got == want, "len": ln, "blob": (root/m["slots"]["a/en/cv"]["file"]).stat().st_size,
  "rss": resource.getrusage(resource.RUSAGE_SELF).ru_maxrss * 1024, "traced_peak": peak}))
"""


class LargeInput(unittest.TestCase):
    def _roundtrip(self, n: int) -> dict:
        with tempfile.TemporaryDirectory() as d:
            res = run_child(CHILD_ROUNDTRIP, {"N_BYTES": str(n), "ROOT": str(Path(d) / "v"), "PW": pw()})
        self.assertTrue(res["ok"], "plaintext sha256 differs after round trip")
        self.assertEqual(res["len"], n)
        self.assertEqual(res["blob"], n + vault.TAG_BYTES)
        return res

    def test_1mib_roundtrip(self):
        res = self._roundtrip(1 * MIB)
        print(f"  1MiB  rss={res['rss']/MIB:.0f}MiB traced_peak={res['traced_peak']/MIB:.1f}MiB")

    def test_50mib_roundtrip_and_memory_ceiling(self):
        res = self._roundtrip(50 * MIB)
        print(f"  50MiB rss={res['rss']/MIB:.0f}MiB traced_peak={res['traced_peak']/MIB:.1f}MiB "
              f"(ceilings rss<{CEILING_RSS_50MIB//MIB} traced<{CEILING_TRACED_50MIB//MIB})")
        self.assertLess(res["rss"], CEILING_RSS_50MIB)
        self.assertLess(res["traced_peak"], CEILING_TRACED_50MIB)

    def test_50mib_blob_tamper_last_byte_detected(self):
        """A single flipped bit at the very END (inside the tag) of a 50 MiB blob is caught."""
        p = pw()
        with tempfile.TemporaryDirectory() as d:
            root = Path(d) / "v"
            vault.seal_items([("a/en/cv", "big.pdf", "application/pdf", payload(50 * MIB, 3))],
                             passphrase=p, out_root=root)
            f = root / json.loads((root / "manifest.json").read_text())["slots"]["a/en/cv"]["file"]
            with open(f, "r+b") as fh:
                fh.seek(-1, os.SEEK_END); b = fh.read(1); fh.seek(-1, os.SEEK_END); fh.write(bytes([b[0] ^ 1]))
            with self.assertRaises(vault.VaultError):
                vault.verify_vault(p, root)


class ManySlots(unittest.TestCase):
    N = 300

    def test_300_slots_seal_and_verify(self):
        p = pw()
        items = [(f"area{i % 12}/{('en','ru','de','fr','ar')[i % 5]}/{'cv' if i % 2 else 'cover'}-{i}",
                  f"doc-{i}.pdf", "application/pdf", payload(512 + i, i)) for i in range(self.N)]
        self.assertEqual(len({s for s, *_ in items}), self.N)
        with tempfile.TemporaryDirectory() as d:
            root = Path(d) / "v"
            written = vault.seal_items(items, passphrase=p, out_root=root)
            self.assertEqual(len(written), self.N)
            m = json.loads((root / "manifest.json").read_text())
            self.assertEqual(len(m["slots"]), self.N)
            res = vault.verify_vault(p, root)
            self.assertEqual(len(res), self.N)
            self.assertEqual(sum(r["bytes"] for r in res), sum(512 + i for i in range(self.N)))
            # every nonce unique (96-bit CSPRNG collision would be a catastrophic GCM failure)
            self.assertEqual(len({r["nonce"] for r in m["slots"].values()}), self.N)
            # spot-check exact plaintext equality on a deterministic sample
            mm, key = vault.open_vault(p, root)
            for i in (0, 1, 149, 298, 299):
                slot = items[i][0]
                self.assertEqual(vault.unseal_slot(mm, key, slot, root)[1], items[i][3])

    def test_300_slot_merge_adds_one_and_keeps_all(self):
        p = pw()
        items = [(f"a{i}/en/cv", f"d{i}.pdf", "application/pdf", b"x" * (i + 1)) for i in range(self.N)]
        with tempfile.TemporaryDirectory() as d:
            root = Path(d) / "v"
            vault.seal_items(items, passphrase=p, out_root=root)
            vault.seal_items([("new/en/cv", "n.pdf", "application/pdf", b"n")], passphrase=p, out_root=root, merge=True)
            self.assertEqual(len(vault.verify_vault(p, root)), self.N + 1)

    def test_memory_bound_300_slots(self):
        code = """
        import json, os, resource, sys, random
        sys.path.insert(0, os.environ["PYTHONPATH"])
        from pathlib import Path
        from career import vault
        items = [(f"a{i%12}/en/cv-{i}", f"d{i}.pdf", "application/pdf", random.Random(i).randbytes(4096)) for i in range(300)]
        root = Path(os.environ["ROOT"])
        vault.seal_items(items, passphrase=os.environ["PW"], out_root=root)
        n = len(vault.verify_vault(os.environ["PW"], root))
        print(json.dumps({"n": n, "rss": resource.getrusage(resource.RUSAGE_SELF).ru_maxrss * 1024}))
        """
        with tempfile.TemporaryDirectory() as d:
            res = run_child(code, {"ROOT": str(Path(d) / "v"), "PW": pw()})
        print(f"  300 slots rss={res['rss']/MIB:.0f}MiB (ceiling {CEILING_RSS_300_SLOTS//MIB})")
        self.assertEqual(res["n"], 300)
        self.assertLess(res["rss"], CEILING_RSS_300_SLOTS)


if __name__ == "__main__":
    unittest.main(verbosity=2)
