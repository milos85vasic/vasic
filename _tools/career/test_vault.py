#!/usr/bin/env python3
"""Vault tests (TDD for the review defects C1-C4 + crypto-vault findings).

Run: python3 -m unittest discover -s _tools/career -p 'test_vault*.py'
Throwaway random passphrases only; all output goes to TemporaryDirectory.
"""
from __future__ import annotations

import json
import os
import secrets
import shutil
import stat
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from career import vault  # noqa: E402

HERE = Path(__file__).resolve().parent
NODE = shutil.which("node")
WORDS = "abacus bridge candle dragon engine forest garden harbor island jungle".split()
NONASCII_NAME = "résumé-日本語-\U0001F600-\"q\".pdf"


def pw() -> str:
    # 7 distinct all-letter words of 3-9 letters, random per run
    letters = "abcdefghijklmnopqrstuvwxyz"
    return " ".join("".join(secrets.choice(letters) for _ in range(7)) for _ in range(7))


def items():
    return [
        ("android/en/cv", "cv-android-en.pdf", "application/pdf", secrets.token_bytes(5000)),
        ("android/en/cover", "cover-android-en.pdf", "application/pdf", secrets.token_bytes(777)),
        ("go/ru/cv", NONASCII_NAME, "application/pdf", secrets.token_bytes(1234)),
    ]


class Fmt(unittest.TestCase):
    def setUp(self):
        self.td = tempfile.TemporaryDirectory(); self.addCleanup(self.td.cleanup)
        self.root = Path(self.td.name) / "v"
        self.pw = pw(); self.items = items()
        vault.seal_items(self.items, passphrase=self.pw, out_root=self.root)
        self.m = json.loads((self.root / "manifest.json").read_text())

    def test_blob_is_ciphertext_plus_tag_and_manifest_has_no_tag_or_hash(self):
        for slot, _, _, data in self.items:
            rec = self.m["slots"][slot]
            self.assertEqual((self.root / rec["file"]).stat().st_size, len(data) + 16)
            self.assertEqual(rec["file"], f"{slot}.{rec['nonce']}.bin")
            self.assertEqual(set(rec), {"name", "mime", "nonce", "aad", "file"})
        import hashlib
        for slot, _, _, data in self.items:
            self.assertNotIn(hashlib.sha256(data).hexdigest(), json.dumps(self.m))
            self.assertEqual(set(self.m["slots"][slot]), {"name", "mime", "nonce", "aad", "file"})

    def test_roundtrip_and_verify(self):
        res = vault.verify_vault(self.pw, self.root)
        self.assertEqual(len(res), 3)

    def test_wrong_passphrase(self):
        with self.assertRaises(vault.VaultError):
            vault.verify_vault(self.pw + "x", self.root)

    def test_tampered_name_slot_mime_fail_in_python(self):
        manifest, key = vault.open_vault(self.pw, self.root)
        slot = "android/en/cv"; rec = dict(manifest["slots"][slot])
        blob = (self.root / rec["file"]).read_bytes()
        for field, val in (("name", "evil.pdf"), ("mime", "text/html")):
            r = dict(rec); r[field] = val
            with self.assertRaises(vault.VaultError, msg=field):
                vault.unseal_blob(blob, r, key=key, salt=manifest["salt"], slot=slot)
        with self.assertRaises(vault.VaultError):
            vault.unseal_blob(blob, rec, key=key, salt=manifest["salt"], slot="android/en/cover")
        # recomputed aad but wrong fields must still fail the tag
        r = dict(rec); r["name"] = "evil.pdf"
        r["aad"] = vault.aad_for(salt=manifest["salt"], slot=slot, name="evil.pdf", mime=rec["mime"])
        with self.assertRaises(vault.VaultError):
            vault.unseal_blob(blob, r, key=key, salt=manifest["salt"], slot=slot)

    def test_bitflip_and_truncation(self):
        manifest, key = vault.open_vault(self.pw, self.root)
        slot = "go/ru/cv"; rec = manifest["slots"][slot]
        blob = bytearray((self.root / rec["file"]).read_bytes())
        for bad in (bytes(blob[:-3]), bytes(blob[:5])):
            with self.assertRaises(vault.VaultError):
                vault.unseal_blob(bad, rec, key=key, salt=manifest["salt"], slot=slot)
        blob[3] ^= 1
        with self.assertRaises(vault.VaultError):
            vault.unseal_blob(bytes(blob), rec, key=key, salt=manifest["salt"], slot=slot)

    def test_header_enforced_exactly_before_derivation(self):
        for field, val in (("v", 2), ("alg", "AES-128-GCM"), ("kdf", "sha1"), ("iters", 1),
                           ("iters", 2_000_000_000), ("iters", True), ("salt", "AAAA")):
            m = dict(self.m); m[field] = val
            with self.assertRaises(vault.VaultError, msg=field):
                vault.check_header(m)

    def test_slot_and_name_validation(self):
        key = b"k" * 32
        for slot in ("../x", "A/b", "a//b", "/a", "a/b/c/d/e", ""):
            with self.assertRaises(vault.VaultError, msg=slot):
                vault.seal_blob(b"x", key=key, salt="s", slot=slot, name="n", mime="m")
        for name in ("a/b", "a\\b", "a\nb", ""):
            with self.assertRaises(vault.VaultError, msg=repr(name)):
                vault.seal_blob(b"x", key=key, salt="s", slot="a/b", name=name, mime="m")

    def test_mime_control_characters_rejected(self):
        for mime in ("a\x7fb", "a\nb", "a\x00b", ""):
            with self.assertRaises(vault.VaultError, msg=repr(mime)):
                vault.seal_blob(b"x", key=b"k" * 32, salt="s", slot="a/b", name="n", mime=mime)

    def test_merge_keeps_others_replace_mode_prunes_stale(self):
        more = [("android/en/cv", "cv-android-en.pdf", "application/pdf", b"new" * 10)]
        vault.seal_items(more, passphrase=self.pw, out_root=self.root, merge=True)
        m = json.loads((self.root / "manifest.json").read_text())
        self.assertEqual(sorted(m["slots"]), sorted(s for s, *_ in self.items))
        self.assertEqual(m["salt"], self.m["salt"])
        # merge with the wrong passphrase must refuse
        with self.assertRaises(vault.VaultError):
            vault.seal_items(more, passphrase=pw(), out_root=self.root, merge=True)
        # replace mode: stale slots and files are removed
        vault.seal_items(more, passphrase=self.pw, out_root=self.root, merge=False)
        m = json.loads((self.root / "manifest.json").read_text())
        self.assertEqual(list(m["slots"]), ["android/en/cv"])
        self.assertEqual(sorted(p.relative_to(self.root).as_posix() for p in self.root.rglob("*.bin")),
                         [m["slots"]["android/en/cv"]["file"]])    # stale blobs gone, no orphans, no lock/temp files
        self.assertEqual(sorted(p.name for p in self.root.iterdir() if p.is_file()), ["manifest.json"])

    def test_weak_passphrase_rejected_unless_test_override(self):
        for weak in ("a", "correct horse battery", "Password123!", "aaaaaaaaaaaaaaaaaaaaaaaa"):
            with self.assertRaises(vault.VaultError, msg=weak):
                vault.seal_items(self.items[:1], passphrase=weak, out_root=self.root / "w")
        vault.seal_items(self.items[:1], passphrase="a", out_root=self.root / "w", _weak_ok=True)
        vault.check_strength(pw())
        vault.check_strength("Xk9#mQ2$vL7@pR4!tZ8&wN3^")

    def test_canonical_json_nonascii_vector(self):
        a = vault.aad_for(salt="s", slot="a/b", name="né\U0001F600\u0001\"", mime="m")
        self.assertIn("\\u00e9", a); self.assertIn("\\ud83d\\ude00", a); self.assertIn("\\u0001", a)
        self.assertTrue(a.isascii())


class Passphrase(unittest.TestCase):
    def test_env_wins_and_missing_is_unavailable(self):
        self.assertEqual(vault.load_passphrase({"CV_VAULT_PASSPHRASE": "x y"}, Path("/nonexistent")), "x y")
        with self.assertRaises(vault.PassphraseUnavailable):
            vault.load_passphrase({}, Path("/nonexistent/none"))

    def test_file_mode_enforced(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "pp"; p.write_text("some words here\n")
            for mode, ok in ((0o600, True), (0o640, False), (0o644, False), (0o604, False)):
                os.chmod(p, mode)
                if ok:
                    self.assertEqual(vault.load_passphrase({}, p), "some words here")
                else:
                    with self.assertRaises(vault.VaultError, msg=oct(mode)):
                        vault.load_passphrase({}, p)
            link = Path(d) / "ln"; link.symlink_to(p); os.chmod(p, 0o600)
            with self.assertRaises(vault.VaultError):
                vault.load_passphrase({}, link)


class Cli(unittest.TestCase):
    def run_cli(self, args, env_pw=None):
        env = {k: v for k, v in os.environ.items() if k != "CV_VAULT_PASSPHRASE"}
        if env_pw:
            env["CV_VAULT_PASSPHRASE"] = env_pw
        return subprocess.run([sys.executable, str(HERE / "vault.py"), *args],
                              capture_output=True, text=True, env=env)

    def test_exit_2_without_passphrase_and_never_prints_it(self):
        if (vault.PASSPHRASE_FILE).exists():
            self.skipTest("a real passphrase file exists on this host")
        r = self.run_cli(["verify"])
        self.assertEqual(r.returncode, 2, r.stderr)

    def test_seal_all_with_injected_cache_and_verify(self):
        with tempfile.TemporaryDirectory() as d:
            cache = Path(d) / "cache"; cache.mkdir(); out = Path(d) / "out"
            (cache / "cv-go-en.pdf").write_bytes(b"%PDF-fake" * 50)
            p = pw()
            items, skipped = vault.collect_artifacts(cache, validate=lambda f, k: (0, "ok"))
            self.assertEqual([i[0] for i in items], ["go/en/cv"])
            items, skipped = vault.collect_artifacts(cache, validate=lambda f, k: (1, "bad"))
            self.assertEqual((items, len(skipped)), ([], 1))
            vault.seal_items(vault.collect_artifacts(cache, validate=lambda f, k: (0, ""))[0],
                             passphrase=p, out_root=out)
            r = self.run_cli(["--out", str(out), "verify"], env_pw=p)
            self.assertEqual(r.returncode, 0, r.stderr)
            self.assertNotIn(p, r.stdout + r.stderr)
            r = self.run_cli(["--out", str(out), "verify"], env_pw=pw())
            self.assertEqual(r.returncode, 1)
            to = Path(d) / "plain.pdf"
            r = self.run_cli(["--out", str(out), "unseal", "--slot", "go/en/cv", "--to", str(to)], env_pw=p)
            self.assertEqual(r.returncode, 0, r.stderr)
            self.assertEqual(to.read_bytes(), b"%PDF-fake" * 50)
            self.assertEqual(stat.S_IMODE(to.stat().st_mode), 0o600)


@unittest.skipUnless(NODE, "node not installed -- cross-language proof CANNOT run (not a pass)")
class CrossLanguage(unittest.TestCase):
    def test_node_decrypts_python_sealed_vault_and_rejects_tampering(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d) / "v"; p = pw(); its = items()
            vault.seal_items(its, passphrase=p, out_root=root)
            import hashlib
            expect = {s: hashlib.sha256(b).hexdigest() for s, _, _, b in its}
            (Path(d) / "expect.json").write_text(json.dumps(expect))
            fields = dict(salt="c2FsdA", slot="go/ru/cv", name=NONASCII_NAME, mime="application/pdf")
            (Path(d) / "vector.json").write_text(json.dumps({"fields": fields, "aad": vault.aad_for(**fields)}))
            env = dict(os.environ, VAULT_DIR=str(root), VAULT_PW=p,
                       EXPECT=str(Path(d) / "expect.json"), VECTOR=str(Path(d) / "vector.json"))
            r = subprocess.run([NODE, str(HERE / "test_vault_cross.js")], env=env, capture_output=True, text=True, timeout=300)
            self.assertEqual(r.returncode, 0, r.stderr)
            results = json.loads(r.stdout.strip().splitlines()[-1])["results"]
            for res in results:
                print(f"  node {'PASS' if res['ok'] else 'FAIL'} {res['name']}: {res['detail'][:80]}")
            failed = [x for x in results if not x["ok"]]
            self.assertFalse(failed, failed)
            self.assertGreaterEqual(len(results), 17)


if __name__ == "__main__":
    unittest.main()
