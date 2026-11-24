#!/usr/bin/env python3
"""Fuzz / property tests for the vault (constitution 11.4.169 'fuzz').

``hypothesis`` is NOT installed on this host (probed at import), so this is a SEEDED random fuzzer:
every case derives from ``random.Random(SEED)`` with fixed seeds -> byte-for-byte reproducible runs.
If hypothesis becomes available the tests still run unchanged (the seeded corpus is the contract).

Properties:
  P1  Python aad_for == node vault.js buildAAD for random unicode field values (BMP, astral, lone surrogates,
      RTL/bidi controls, C0 controls, U+2028/2029, noncharacters, quotes/backslashes) -- ALL cases in ONE node call.
  P2  AAD output is pure ASCII with only lower-case \\u escapes, and round-trips through json.loads.
  P3  seal_blob/unseal_blob round trip for random plaintext/name/mime; any single-bit mutation of blob, nonce,
      aad, name, mime or slot is rejected with VaultError (never returns plaintext).
  P4  A Python-sealed vault with random unicode names is opened by the REAL vault.js and every slot's name,
      mime and plaintext hash equal Python's.
  D5  DEL (U+007F) is escaped by Python but not by vault.js -> AAD mismatch (known defect, own test).
  P5  (latent finding, documented) generic canonicalJSON key ORDER differs from Python for keys that mix
      astral and U+E000..U+FFFF characters (JS sorts UTF-16 units, Python sorts code points).  The real AAD uses
      only 8 fixed ASCII keys, so the vault is NOT affected; the test pins the divergence so a future caller
      that feeds user keys to canonicalJSON is noticed.
"""
from __future__ import annotations

import hashlib
import json
import os
import random
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
NODE = shutil.which("node")
# vault.js is operator-private and git-ignored in the milosvasic.ru submodule by design (14b2d8b); absent => cross-language tests CANNOT run (skip, never a pass).
VAULT_JS = Path(__file__).resolve().parents[2] / "milosvasic.ru" / "assets" / "js" / "vault.js"
HAVE_VAULT_JS = bool(NODE) and VAULT_JS.is_file()
known_defect = (lambda f: f) if os.environ.get("VAULT_SHOW_DEFECTS") else unittest.expectedFailure
SEEDS = (20260101, 20260102, 20260103)
N_AAD = 2000
try:
    import hypothesis  # noqa: F401
    HAVE_HYPOTHESIS = True
except ImportError:
    HAVE_HYPOTHESIS = False

SPECIAL = ["\u202e", "\u202d", "\u202a", "\u202b", "\u202c", "\u200f", "\u200e", "\u2066", "\u2067", "\u2068",
           "\u2069", "\u2028", "\u2029", "\ufeff", "\u200b", "\u200d", "\ufffe", "\uffff", "\ufffd",
           "\u0000", "\u001f", "\u0080", "\u009f", "\u00a0", "\u0085", '"', "\\", "/", "'", "<", ">",
           "\U0010ffff", "\U00010000", "\U0001f600", "\U0001f468\u200d\U0001f469\u200d\U0001f467",
           "\u05d0\u05d1", "\u0627\u0644\u0639\u0631\u0628\u064a\u0629", "\u65e5\u672c\u8a9e", "e\u0301"]


def rand_char(r: random.Random, allow_lone_surrogate: bool = True) -> str:
    k = r.random()
    if k < 0.25:
        return chr(r.randrange(0x20, 0x80))  # includes 0x7F (DEL): D5 fixed
    if k < 0.40:
        return r.choice(SPECIAL)
    if k < 0.55:
        return chr(r.randrange(0x00, 0x20))
    if k < 0.70:
        return chr(r.randrange(0x80, 0x800))
    if k < 0.82:
        while True:
            c = r.randrange(0x800, 0x10000)
            if not 0xD800 <= c <= 0xDFFF:
                return chr(c)
    if k < 0.92:
        return chr(r.randrange(0x10000, 0x110000))
    return chr(r.randrange(0xD800, 0xE000)) if allow_lone_surrogate else "x"


def rand_str(r: random.Random, maxlen: int = 24, surrogates: bool = True) -> str:
    return "".join(rand_char(r, surrogates) for _ in range(r.randrange(0, maxlen + 1)))


def node_batch(job: dict):
    with tempfile.TemporaryDirectory() as d:
        f = Path(d) / "job.json"
        f.write_text(json.dumps(job), encoding="utf-8")        # ensure_ascii: lone surrogates survive as \udXXX
        r = subprocess.run([NODE, str(HERE / "test_vault_fuzz_node.js"), str(f)],
                           capture_output=True, text=True, timeout=300)
    lines = r.stdout.rstrip("\n").split("\n")      # NOT splitlines(): U+2028/0x85/0x1c.. inside JSON would split
    if not r.stdout.strip():
        raise AssertionError(f"node produced no output rc={r.returncode}: {r.stderr[-500:]}")
    out = json.loads(lines[-1])
    if "error" in out:
        raise AssertionError(f"node failed: {out['error']} {r.stderr[-300:]}")
    return out["out"]


def pw() -> str:
    letters = "abcdefghijklmnopqrstuvwxyz"
    return " ".join("".join(secrets.choice(letters) for _ in range(7)) for _ in range(7))


@unittest.skipUnless(HAVE_VAULT_JS, "node or milosvasic.ru/assets/js/vault.js (operator-private, git-ignored) absent -- cross-language fuzz CANNOT run (not a pass)")
class AadEquality(unittest.TestCase):
    def test_aad_python_equals_node_all_seeds(self):
        total = 0
        for seed in SEEDS:
            r = random.Random(seed)
            cases = [{"salt": vault.b64(r.randbytes(16)), "slot": rand_str(r), "name": rand_str(r, 40),
                      "mime": rand_str(r, 30)} for _ in range(N_AAD)]
            want = [vault.aad_for(**c) for c in cases]
            got = node_batch({"mode": "aad", "cases": cases})
            self.assertEqual(len(got), len(want))
            bad = [(i, cases[i], want[i], got[i]) for i in range(len(want)) if want[i] != got[i]]
            self.assertFalse(bad, f"seed {seed}: {len(bad)} AAD mismatches, first: {bad[:1]}")
            total += len(cases)
        print(f"  AAD python==node on {total} random unicode cases ({len(SEEDS)} fixed seeds)")

    def test_aad_is_ascii_lowercase_escapes_and_roundtrips(self):
        r = random.Random(SEEDS[0])
        for _ in range(1500):
            c = {"salt": vault.b64(r.randbytes(16)), "slot": rand_str(r), "name": rand_str(r, 40), "mime": rand_str(r)}
            a = vault.aad_for(**c)
            self.assertTrue(a.isascii())
            self.assertNotRegex(a, r"\\u(?=[0-9a-fA-F]{4})[0-9a-f]{0,3}[A-F]")
            back = json.loads(a)
            u16 = lambda x: x.encode("utf-16-le", "surrogatepass")   # json.loads re-pairs adjacent lone surrogates
            self.assertEqual([u16(back[k]) for k in ("slot", "name", "mime")], [u16(c[k]) for k in ("slot", "name", "mime")])
            self.assertEqual(a, vault.canonical_json(back))          # idempotent canonicalisation

    def test_edge_vectors_equal(self):
        cases = [{"salt": "A" * 22, "slot": "a/b", "name": n, "mime": "m"} for n in
                 ["", "\ud800", "\udc00", "\ud83d", "\ude00", "\U0001f600", "\ude00\ud83d", "\u2028\u2029",
                  "\u0080", "\uffff", "\U0010ffff", "\u202ea\u202c", '"\\', "\x00\x1f"]]
        self.assertEqual([vault.aad_for(**c) for c in cases], node_batch({"mode": "aad", "cases": cases}))

    def test_del_0x7f_escaped_identically(self):
        """DEL (U+007F): Python json ensure_ascii escapes it (\\u007f); vault.js regex [\\u0080-\\uffff] leaves it raw.
        Reachable via a manifest 'mime' containing DEL (mime is only length-checked, not control-checked).
        Fix: vault.js canonicalJSON regex -> /[\\u007f-\\uffff]/g  (and/or reject controls in mime in _check_name)."""
        for fld in ("name", "slot", "mime"):
            c = {"salt": "A" * 22, "slot": "a/b", "name": "n", "mime": "m"}; c[fld] = "x\x7fy"
            self.assertEqual(vault.aad_for(**c), node_batch({"mode": "aad", "cases": [c]})[0], fld)

    @known_defect   # P5: latent, NOT reachable through the fixed-key AAD
    def test_generic_canonical_json_key_order_matches_python(self):
        objs = [{"\U00010000": 1, "\uffff": 2}, {"\U0001f600": 1, "\ue000": 2, "a": 3}]
        self.assertEqual([vault.canonical_json(o) for o in objs], node_batch({"mode": "canon", "cases": objs}))

    def test_aad_key_order_fixed_keys_unaffected_by_p5(self):
        c = [{"salt": "A" * 22, "slot": "s", "name": "\U00010000\uffff", "mime": "m"}]
        self.assertEqual([vault.aad_for(**c[0])], node_batch({"mode": "aad", "cases": c}))


class RoundTripProperties(unittest.TestCase):
    KEY = bytes(range(32))
    SALT = vault.b64(bytes(range(16)))

    def _valid_name(self, r):
        while True:
            n = rand_str(r, 30)
            try:
                vault._check_name(n or "x", "m"); return n or "x"
            except vault.VaultError:
                continue

    def test_roundtrip_random(self):
        r = random.Random(SEEDS[1])
        for i in range(400):
            data = r.randbytes(r.choice([0, 1, 15, 16, 17, 255, 4096, r.randrange(0, 20000)]))
            name, mime = self._valid_name(r), "application/" + "x" * r.randrange(1, 20)
            slot = f"a{i}/en/cv"
            rec, blob = vault.seal_blob(data, key=self.KEY, salt=self.SALT, slot=slot, name=name, mime=mime)
            self.assertEqual(len(blob), len(data) + 16)
            self.assertEqual(vault.unseal_blob(blob, rec, key=self.KEY, salt=self.SALT, slot=slot), data)

    def test_every_single_mutation_rejected(self):
        r = random.Random(SEEDS[2])
        accepted = 0
        for i in range(300):
            data = r.randbytes(r.randrange(1, 600))
            slot, name, mime = f"s{i}/en/cv", self._valid_name(r), "application/pdf"
            rec, blob = vault.seal_blob(data, key=self.KEY, salt=self.SALT, slot=slot, name=name, mime=mime)
            kind = r.choice(["blob", "nonce", "aad", "name", "mime", "slot", "salt"])
            rec2, blob2, slot2, salt2 = dict(rec), blob, slot, self.SALT
            if kind == "blob":
                b = bytearray(blob); j = r.randrange(len(b)); b[j] ^= 1 << r.randrange(8); blob2 = bytes(b)
            elif kind == "nonce":
                n = bytearray(vault.unb64(rec["nonce"])); n[r.randrange(12)] ^= 1 << r.randrange(8)
                rec2["nonce"] = vault.b64(bytes(n))
            elif kind == "aad":
                a = rec["aad"]; j = r.randrange(len(a)); rec2["aad"] = a[:j] + chr(ord(a[j]) ^ 1) + a[j + 1:]
            elif kind == "name":
                rec2["name"] = name + "x"
            elif kind == "mime":
                rec2["mime"] = mime + "x"
            elif kind == "slot":
                slot2 = f"t{i}/en/cv"
            else:
                salt2 = vault.b64(bytes(range(1, 17)))
            try:
                out = vault.unseal_blob(blob2, rec2, key=self.KEY, salt=salt2, slot=slot2)
                accepted += 1
                self.fail(f"mutation {kind} ACCEPTED (case {i})")
            except vault.VaultError:
                pass
        self.assertEqual(accepted, 0)

    def test_cross_wrong_key_never_decrypts(self):
        r = random.Random(11)
        rec, blob = vault.seal_blob(b"secret", key=self.KEY, salt=self.SALT, slot="a/en/cv", name="n", mime="m")
        for _ in range(50):
            k = r.randbytes(32)
            if k == self.KEY:
                continue
            with self.assertRaises(vault.VaultError):
                vault.unseal_blob(blob, rec, key=k, salt=self.SALT, slot="a/en/cv")


@unittest.skipUnless(HAVE_VAULT_JS, "node or milosvasic.ru/assets/js/vault.js (operator-private, git-ignored) absent -- cross-language fuzz CANNOT run (not a pass)")
class RandomVaultOpenedByRealJs(unittest.TestCase):
    def test_python_sealed_random_unicode_vault_opens_in_js(self):
        r = random.Random(SEEDS[0] + 99)
        p = pw()
        items, seen = [], set()
        while len(items) < 60:
            n = rand_str(r, 25)
            try:
                vault._check_name(n or "x", "m")
            except vault.VaultError:
                continue
            n = n or "x"
            mime = "application/" + "".join(r.choice("abcdefghij") for _ in range(r.randrange(1, 8)))
            slot = f"a{len(items) % 7}/{'en ru de'.split()[len(items) % 3]}/k{len(items)}"
            if slot in seen:
                continue
            seen.add(slot)
            items.append((slot, n, mime, r.randbytes(r.randrange(0, 3000))))
        with tempfile.TemporaryDirectory() as d:
            root = Path(d) / "v"
            vault.seal_items(items, passphrase=p, out_root=root)
            got = node_batch({"mode": "vault", "root": str(root), "pw": p})
        by = {g["slot"]: g for g in got}
        self.assertEqual(set(by), {s for s, *_ in items})
        for slot, name, mime, data in items:
            g = by[slot]
            self.assertEqual((g["name"], g["mime"], g["sha"]), (name, mime, hashlib.sha256(data).hexdigest()), slot)
        print(f"  {len(items)} random-unicode slots sealed in Python opened by vault.js, names/mime/bytes equal")


if __name__ == "__main__":
    print("hypothesis installed:", HAVE_HYPOTHESIS, "(seeded fuzzer used; seeds", SEEDS, ")")
    unittest.main(verbosity=2)
