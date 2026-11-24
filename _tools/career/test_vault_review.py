#!/usr/bin/env python3
"""Regression tests for the independent-review findings on vault.py (each was written RED first).

Run: python3 -m unittest _tools/career/test_vault_review.py   (throwaway random passphrases only)
"""
from __future__ import annotations

import errno
import json
import os
import secrets
import shutil
import subprocess
import sys
import tempfile
import unicodedata
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from career import vault  # noqa: E402

HERE = Path(__file__).resolve().parent
NODE = shutil.which("node")
# vault.js is operator-private and git-ignored in the milosvasic.ru submodule by design (14b2d8b); absent => cross-language tests CANNOT run (skip, never a pass).
VAULT_JS = Path(__file__).resolve().parents[2] / "milosvasic.ru" / "assets" / "js" / "vault.js"
HAVE_VAULT_JS = bool(NODE) and VAULT_JS.is_file()


def pw() -> str:
    letters = "abcdefghijklmnopqrstuvwxyz"
    return " ".join("".join(secrets.choice(letters) for _ in range(7)) for _ in range(7))


def item(slot="a/en/cv", data=b"x" * 300):
    return (slot, slot.replace("/", "-") + ".pdf", "application/pdf", data)


class Base(unittest.TestCase):
    def setUp(self):
        self.td = tempfile.TemporaryDirectory(); self.addCleanup(self.td.cleanup)
        self.root = Path(self.td.name) / "v"
        self.pw = pw()


class PostCommitFailure(Base):
    def test_fsync_eio_after_commit_does_not_destroy_committed_vault(self):
        vault.seal_items([item("a/en/cv")], passphrase=self.pw, out_root=self.root)
        committed = {"v": False}
        real_replace, real_fsync = vault.os.replace, vault._fsync_path

        def replace(a, b):
            r = real_replace(a, b)
            if str(b).endswith("manifest.json"):
                committed["v"] = True
            return r

        def fsync(path, **kw):
            if committed["v"]:
                raise OSError(errno.EIO, "injected EIO after commit")
            return real_fsync(path, **kw)

        vault.os.replace, vault._fsync_path = replace, fsync
        try:
            vault.seal_items([item("b/en/cv", b"y" * 300)], passphrase=self.pw,
                             out_root=self.root, merge=True)
        finally:
            vault.os.replace, vault._fsync_path = real_replace, real_fsync
        self.assertTrue(committed["v"])
        res = vault.verify_vault(self.pw, self.root)
        self.assertEqual([r["slot"] for r in res], ["a/en/cv", "b/en/cv"])


class SweepScope(Base):
    def test_sweep_leaves_unrelated_bin_files_alone(self):
        vault.seal_items([item("a/en/cv")], passphrase=self.pw, out_root=self.root)
        (self.root / "keep.bin").write_bytes(b"unrelated")
        (self.root / "a" / "en" / "notes.bin").write_bytes(b"unrelated2")
        vault.seal_items([item("a/en/cv", b"z" * 300)], passphrase=self.pw, out_root=self.root, merge=True)
        self.assertTrue((self.root / "keep.bin").exists())
        self.assertTrue((self.root / "a" / "en" / "notes.bin").exists())
        self.assertEqual(len(vault.verify_vault(self.pw, self.root)), 1)

    def test_refuses_non_empty_out_without_manifest(self):
        self.root.mkdir()
        (self.root / "keep.bin").write_bytes(b"precious")
        with self.assertRaises(vault.VaultError):
            vault.seal_items([item()], passphrase=self.pw, out_root=self.root)
        self.assertEqual((self.root / "keep.bin").read_bytes(), b"precious")

    def test_failed_deletions_are_reported(self):
        vault.seal_items([item("a/en/cv")], passphrase=self.pw, out_root=self.root)
        real = Path.unlink

        def unlink(self_, missing_ok=False):
            if self_.suffix == ".bin":
                raise PermissionError(errno.EACCES, "injected")
            return real(self_, missing_ok=missing_ok)

        Path.unlink = unlink
        try:
            res = vault.seal_items([item("a/en/cv", b"q" * 300)], passphrase=self.pw,
                                   out_root=self.root, merge=True)
        finally:
            Path.unlink = real
        self.assertEqual(len(res.failed_deletions), 1)


class MergeProof(Base):
    def test_merge_with_wrong_passphrase_fails_even_if_all_blobs_missing(self):
        vault.seal_items([item("a/en/cv")], passphrase=self.pw, out_root=self.root)
        for f in self.root.rglob("*.bin"):
            f.unlink()
        with self.assertRaises(vault.VaultError):
            vault.seal_items([item("b/en/cv")], passphrase=pw(), out_root=self.root, merge=True)

    def test_merge_into_empty_slots_vault_is_allowed(self):
        self.root.mkdir()
        salt = vault.b64(secrets.token_bytes(16))
        (self.root / "manifest.json").write_text(json.dumps(
            {"v": 1, "alg": vault.ALGORITHM, "kdf": vault.KDF, "iters": vault.PBKDF2_ITERS,
             "salt": salt, "slots": {}}))
        vault.seal_items([item()], passphrase=self.pw, out_root=self.root, merge=True)
        self.assertEqual(len(vault.verify_vault(self.pw, self.root)), 1)


class SweepGrammar(Base):
    """Only exactly-formed blob names (<slot>.<16-char nonce tag>.bin) are ever swept."""
    SURVIVORS = ("cv.2024.bin", "a/en/report.final.bin", "backup.v2.bin", "x.abcdefghijklmnop.bin.bak",
                 "a/en/cv.ABCDEFGHIJKLMNOPQ.bin")   # 17-char tag: not ours

    def test_lookalike_bin_files_survive_a_seal(self):
        vault.seal_items([item("a/en/cv")], passphrase=self.pw, out_root=self.root)
        for rel in self.SURVIVORS:
            f = self.root / rel
            f.parent.mkdir(parents=True, exist_ok=True)
            f.write_bytes(b"mine")
        vault.seal_items([item("a/en/cv", b"q" * 300)], passphrase=self.pw, out_root=self.root, merge=True)
        for rel in self.SURVIVORS:
            self.assertEqual((self.root / rel).read_bytes(), b"mine", rel)

    def test_strict_grammar_orphans_are_swept(self):
        vault.seal_items([item("a/en/cv")], passphrase=self.pw, out_root=self.root)
        orphan = self.root / "a" / "en" / ("cv." + vault.b64(secrets.token_bytes(12)) + ".bin")
        orphan.write_bytes(b"orphan")
        vault.seal_items([item("a/en/cv", b"q" * 300)], passphrase=self.pw, out_root=self.root, merge=True)
        self.assertFalse(orphan.exists())

    def test_first_seal_killed_before_commit_self_heals(self):
        self.root.mkdir()
        (self.root / "a" / "en").mkdir(parents=True)
        orphan = self.root / "a" / "en" / ("cv." + vault.b64(secrets.token_bytes(12)) + ".bin")
        orphan.write_bytes(b"orphan")
        tmp = self.root / (".manifest." + secrets.token_hex(8) + ".tmp")
        tmp.write_text("{}")
        vault.seal_items([item("a/en/cv")], passphrase=self.pw, out_root=self.root)
        self.assertEqual(len(vault.verify_vault(self.pw, self.root)), 1)
        self.assertFalse(orphan.exists()); self.assertFalse(tmp.exists())

    def test_any_other_content_still_refuses_first_seal(self):
        for rel in ("cv.2024.bin", "notes.txt", "a/en/report.final.bin"):
            root = Path(self.td.name) / ("r" + str(abs(hash(rel))))
            (root / "a" / "en").mkdir(parents=True)
            good = root / "a" / "en" / ("cv." + vault.b64(secrets.token_bytes(12)) + ".bin")
            good.write_bytes(b"orphan")
            (root / rel).parent.mkdir(parents=True, exist_ok=True)
            (root / rel).write_bytes(b"precious")
            with self.assertRaises(vault.VaultError, msg=rel):
                vault.seal_items([item("a/en/cv")], passphrase=self.pw, out_root=root)
            self.assertEqual((root / rel).read_bytes(), b"precious")
            self.assertTrue(good.exists())


class Strength(unittest.TestCase):
    def test_real_diceware_short_words_accepted(self):
        vault.check_strength("fed all did add eel too")
        vault.check_strength("too eel add did all fed")
    def test_vacuous_inputs_rejected(self):
        for weak in ("abc def ghi jkl mno pqr", "qwe asd zxc rty fgh vbn", "aaa bbb ccc ddd eee fff",
                     "a1B2c3D4e5F6g7H8", "abcdefghijklmnop", "qwertyuiopasdfghjkl", "1q2w3e4r5t6y7u8i9o0p",
                     "AaAaAaAaAaAaAaAaAaAaAaAa", "ab cd ef gh ij kl", "the the the the the the"):
            with self.assertRaises(vault.VaultError, msg=weak):
                vault.check_strength(weak)

    def test_good_inputs_accepted(self):
        vault.check_strength(pw())
        vault.check_strength("Xk9#mQ2$vL7@pR4!tZ8&wN3^")
        vault.check_strength("xqz wkv jfp bgd hty nrm")

    def test_charset_bits_capped_per_char(self):
        bits, _ = vault.estimate_bits("Xk9#mQ2$vL7@pR4!tZ8&wN3^")
        self.assertLessEqual(bits, 24 * 4.0 + 1e-9)


class Codec(Base):
    def test_trailing_newline_rejected(self):
        for bad in ("abc\n", "abc-_\n"):
            with self.assertRaises(vault.VaultError):
                vault.unb64(bad)
        with self.assertRaises(vault.VaultError):
            vault._check_slot("a/en/cv\n")

    def test_noncanonical_base64_rejected(self):
        good = vault.b64(b"\x01")           # 'AQ'
        self.assertEqual(vault.unb64(good), b"\x01")
        with self.assertRaises(vault.VaultError):
            vault.unb64("AR")                 # same byte, non-zero padding bits

    def test_blob_rel_trailing_newline_rejected(self):
        with self.assertRaises(vault.VaultError):
            vault.blob_rel({"file": "a/en/cv.abc.bin\n"}, "a/en/cv")
        with self.assertRaises(vault.VaultError):
            vault.blob_rel({"file": "a/en/cv.ab\n.bin"}, "a/en/cv")


class Unseal(Base):
    def run_cli(self, args, env_pw):
        env = {k: v for k, v in os.environ.items() if k != vault.ENV_PASSPHRASE}
        env[vault.ENV_PASSPHRASE] = env_pw
        return subprocess.run([sys.executable, str(HERE / "vault.py"), "--out", str(self.root)] + args,
                              env=env, capture_output=True, text=True, timeout=120)

    def test_unseal_refuses_existing_dest_and_symlink(self):
        vault.seal_items([item()], passphrase=self.pw, out_root=self.root)
        victim = Path(self.td.name) / "victim"; victim.write_bytes(b"keep")
        link = Path(self.td.name) / "link"; link.symlink_to(victim)
        for dest in (victim, link):
            r = self.run_cli(["unseal", "--slot", "a/en/cv", "--to", str(dest)], self.pw)
            self.assertEqual(r.returncode, 1, r.stderr)
        self.assertEqual(victim.read_bytes(), b"keep")
        self.assertTrue(link.is_symlink())


class Normalisation(Base):
    def test_nfd_and_nfc_passphrases_open_the_same_vault(self):
        base = "Ünïcödé-ñ-Xk9#mQ2$vL7@pR4!"
        nfc, nfd = unicodedata.normalize("NFC", base), unicodedata.normalize("NFD", base)
        self.assertNotEqual(nfc, nfd)
        vault.seal_items([item()], passphrase=nfd, out_root=self.root)
        self.assertEqual(len(vault.verify_vault(nfc, self.root)), 1)

    @unittest.skipUnless(HAVE_VAULT_JS, "node or vault.js (operator-private, git-ignored) absent -- CANNOT run (not a pass)")
    def test_node_opens_with_other_normalisation_form(self):
        base = "Ünïcödé-ñ-Xk9#mQ2$vL7@pR4!"
        nfd = unicodedata.normalize("NFD", base)
        vault.seal_items([item()], passphrase=nfd, out_root=self.root)
        js = """
const V=require(process.argv[1]);const fs=require('fs'),path=require('path');
const root=process.argv[2];
const f=async(u)=>{const p=path.join(root,decodeURIComponent(new URL(u).pathname.replace(/^\\/downloads\\/vault\\//,'')));
 if(!fs.existsSync(p))return{ok:false,status:404,headers:new Map()};const b=fs.readFileSync(p);
 return{ok:true,status:200,headers:new Map(),text:async()=>b.toString('utf8'),arrayBuffer:async()=>b.buffer.slice(b.byteOffset,b.byteOffset+b.byteLength)}};
V.unlockAll(process.env.PW,{fetch:f,base:'https://x.test/a.html'}).then(r=>console.log('OK '+r.length),e=>{console.log('ERR '+e.code);process.exit(1)});
"""
        for form in ("NFC", "NFD"):
            env = dict(os.environ, PW=unicodedata.normalize(form, base))
            r = subprocess.run([NODE, "-e", js, str(HERE.parents[1] / "milosvasic.ru/assets/js/vault.js"), str(self.root)],
                               env=env, capture_output=True, text=True, timeout=120)
            self.assertEqual(r.stdout.strip(), "OK 1", (form, r.stdout, r.stderr))


if __name__ == "__main__":
    unittest.main(verbosity=2)
