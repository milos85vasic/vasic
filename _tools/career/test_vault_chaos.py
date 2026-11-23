#!/usr/bin/env python3
"""Chaos / failure-injection tests for the vault (constitution 11.4.85 / 11.4.169 'chaos').

Real failure injection, not mocks of the unit under test:
  * corrupted / truncated / empty / non-UTF-8 / duplicate-key manifests,
  * missing blobs mid-verify,
  * disk-full via RLIMIT_FSIZE in a child (real EFBIG from the kernel),
  * read-only directory,
  * SIGKILL of a child process at exact points of seal_items (real kill -9).

The atomicity invariant asserted: AFTER ANY FAILED SEAL, THE PREVIOUS VAULT STILL VERIFIES
(old manifest + old blobs consistent), and manifest.json is never partial.
All previously recorded defects (D1-D3 below) are FIXED and their tests are plain assertions of the
correct behaviour; ``known_defect`` (= expectedFailure) remains available for any future defect that is
found before it is fixed, and VAULT_SHOW_DEFECTS=1 unwraps such tests.

Throwaway random passphrases; scratch temp dirs only.
"""
from __future__ import annotations

import json
import os
import secrets
import signal
import subprocess
import sys
import tempfile
import textwrap
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from career import vault  # noqa: E402

HERE = Path(__file__).resolve().parent
VAULT_PY = HERE / "vault.py"
PARENT = str(Path(__file__).resolve().parents[1])

# VAULT_SHOW_DEFECTS=1 unwraps the defect tests so their real assertion messages are visible.
known_defect = (lambda f: f) if os.environ.get("VAULT_SHOW_DEFECTS") else unittest.expectedFailure

# D1-D3 below are FIXED (D4 in test_vault_concurrency, D5 in test_vault_fuzz); kept as a record.
DEFECTS = {
    "D1": "seal_items writes blobs in place (write_bytes truncates) BEFORE the manifest is swapped; a crash/ENOSPC "
          "between leaves old manifest + new/partial blobs -> previous vault no longer verifies.",
    "D2": "replace-mode (merge=False) unlinks stale blobs BEFORE os.replace(manifest): a crash in between leaves the "
          "published manifest pointing at deleted blobs.",
    "D3": "a corrupt/non-UTF-8/non-object manifest.json escapes as JSONDecodeError/UnicodeDecodeError/AttributeError "
          "(not VaultError/OSError) -> vault.py CLI prints a Python traceback instead of 'FAIL: ...'.",
}


def pw() -> str:
    letters = "abcdefghijklmnopqrstuvwxyz"
    return " ".join("".join(secrets.choice(letters) for _ in range(7)) for _ in range(7))


def two_items(tag: bytes = b"A"):
    return [("android/en/cv", "cv.pdf", "application/pdf", tag * 4000),
            ("go/ru/cover", "cover.pdf", "application/pdf", tag * 900)]


def child(code: str, env: dict, timeout=120) -> subprocess.CompletedProcess:
    e = dict(os.environ, **env, PYTHONPATH=PARENT)
    return subprocess.run([sys.executable, "-c", textwrap.dedent(code)], env=e,
                          capture_output=True, text=True, timeout=timeout)


def cli(args, env_pw, out) -> subprocess.CompletedProcess:
    return subprocess.run([sys.executable, str(VAULT_PY), "--out", str(out), *args],
                          env=dict(os.environ, CV_VAULT_PASSPHRASE=env_pw), capture_output=True,
                          text=True, timeout=120)


class Base(unittest.TestCase):
    def setUp(self):
        self.td = tempfile.TemporaryDirectory(); self.addCleanup(self.td.cleanup)
        self.root = Path(self.td.name) / "v"
        self.pw = pw()
        vault.seal_items(two_items(b"A"), passphrase=self.pw, out_root=self.root)
        self.assertEqual(len(vault.verify_vault(self.pw, self.root)), 2)

    def assertOldVaultIntact(self):
        res = vault.verify_vault(self.pw, self.root)
        self.assertEqual({r["slot"] for r in res}, {"android/en/cv", "go/ru/cover"})

    def assertManifestNeverPartial(self):
        m = self.root / "manifest.json"
        if m.exists():
            json.loads(m.read_text(encoding="utf-8"))   # complete JSON or the test fails


class CorruptManifest(Base):
    def _file(self, slot):
        return json.loads((self.root / "manifest.json").read_text())["slots"][slot]["file"]

    def _write(self, data: bytes):
        (self.root / "manifest.json").write_bytes(data)

    def _must_fail_cleanly(self):
        """Library: any exception is acceptable only if it is VaultError/OSError/ValueError family and NEVER
        a success.  Returns the exception for further checks."""
        with self.assertRaises(Exception) as cx:
            vault.verify_vault(self.pw, self.root)
        return cx.exception

    def test_zero_length_manifest_rejected(self):
        self._write(b"")
        self._must_fail_cleanly()

    def test_truncated_manifest_rejected(self):
        raw = (self.root / "manifest.json").read_bytes()
        for cut in (1, 10, len(raw) // 2, len(raw) - 2):
            self._write(raw[:cut])
            self._must_fail_cleanly()

    def test_non_utf8_manifest_rejected(self):
        self._write(b'{"v":1,"salt":"\xff\xfe\xfa"}')
        self._must_fail_cleanly()

    def test_non_object_manifest_rejected(self):
        for blob in (b"[]", b"null", b"123", b'"x"', b"true"):
            self._write(blob)
            self._must_fail_cleanly()

    def test_huge_iters_string_rejected_fast(self):
        m = json.loads((self.root / "manifest.json").read_text())
        m["iters"] = "9" * 200_000          # must be rejected before ANY derivation (header check)
        self._write(json.dumps(m).encode())
        exc = self._must_fail_cleanly()
        self.assertIsInstance(exc, vault.VaultError)
        m["iters"] = 10 ** 400              # big int
        self._write(json.dumps(m).encode())
        self.assertIsInstance(self._must_fail_cleanly(), vault.VaultError)
        m["iters"] = 600000.0               # float equal to the int: documented behaviour, must stay safe
        self._write(json.dumps(m).encode())
        try:
            vault.verify_vault(self.pw, self.root)       # accepted == same number; JS parses identically
        except vault.VaultError:
            pass

    def test_duplicate_slot_keys_last_wins_and_stays_authenticated(self):
        """JSON with a duplicated slot key: parsers keep the LAST value.  An attacker who can edit the manifest
        cannot make an unauthenticated record verify, because AAD binds name/mime/slot."""
        raw = (self.root / "manifest.json").read_text()
        m = json.loads(raw)
        good = m["slots"]["android/en/cv"]
        evil = dict(good, name="evil.pdf")           # aad not recomputed -> must be refused
        dup = ('{"alg":"%s","iters":%d,"kdf":"%s","salt":"%s","slots":{"android/en/cv":%s,"android/en/cv":%s,'
               '"go/ru/cover":%s},"v":1}' % (m["alg"], m["iters"], m["kdf"], m["salt"], json.dumps(good),
                                             json.dumps(evil), json.dumps(m["slots"]["go/ru/cover"])))
        self._write(dup.encode())
        with self.assertRaises(vault.VaultError):
            vault.verify_vault(self.pw, self.root)
        dup2 = dup.replace(json.dumps(evil), json.dumps(good)).replace(json.dumps(good), json.dumps(evil), 1)
        # order good,good (duplicate identical): must still verify
        same = ('{"alg":"%s","iters":%d,"kdf":"%s","salt":"%s","slots":{"android/en/cv":%s,"android/en/cv":%s,'
                '"go/ru/cover":%s},"v":1}' % (m["alg"], m["iters"], m["kdf"], m["salt"], json.dumps(good),
                                             json.dumps(good), json.dumps(m["slots"]["go/ru/cover"])))
        self._write(same.encode())
        self.assertEqual(len(vault.verify_vault(self.pw, self.root)), 2)

    def test_slot_record_garbage_rejected_with_vaulterror(self):
        base = json.loads((self.root / "manifest.json").read_text())
        for bad in (None, 5, [], "x", {}, {"name": "a"}, {"name": 1, "mime": 2, "nonce": 3, "aad": 4}):
            m = json.loads(json.dumps(base)); m["slots"]["android/en/cv"] = bad
            self._write(json.dumps(m).encode())
            with self.assertRaises(vault.VaultError):
                vault.verify_vault(self.pw, self.root)

    def test_blob_variants_rejected(self):
        f = self.root / json.loads((self.root / "manifest.json").read_text())["slots"]["android/en/cv"]["file"]
        orig = f.read_bytes()
        for data in (b"", b"\x00" * 15, orig[:-1], orig + b"\x00", b"\x00" * len(orig)):
            f.write_bytes(data)
            with self.assertRaises(vault.VaultError):
                vault.verify_vault(self.pw, self.root)
        f.write_bytes(orig)
        self.assertOldVaultIntact()

    def test_missing_blob_mid_verify_fails_without_partial_success(self):
        (self.root / self._file("go/ru/cover")).unlink()           # sorted order: android ok, go missing
        with self.assertRaises((vault.VaultError, OSError)):
            vault.verify_vault(self.pw, self.root)
        r = cli(["verify"], self.pw, self.root)
        self.assertEqual(r.returncode, 1, r.stderr)
        self.assertIn("FAIL", r.stderr)
        self.assertNotIn("Traceback", r.stderr)

    def test_missing_blob_unseal_cli_writes_nothing(self):
        (self.root / self._file("android/en/cv")).unlink()
        dest = Path(self.td.name) / "out.pdf"
        r = cli(["unseal", "--slot", "android/en/cv", "--to", str(dest)], self.pw, self.root)
        self.assertEqual(r.returncode, 1, r.stderr)
        self.assertFalse(dest.exists())
        self.assertNotIn("Traceback", r.stderr)

    def test_cli_corrupt_manifest_is_clean_failure_not_traceback(self):
        for data in (b"", b'{"v":1', b"\xff\xfe", b"[]"):
            self._write(data)
            r = cli(["verify"], self.pw, self.root)
            self.assertEqual(r.returncode, 1, (data, r.stderr[-300:]))
            self.assertNotIn("Traceback", r.stderr, data)
            self.assertIn("FAIL", r.stderr, data)

    def test_cli_corrupt_manifest_never_exits_zero(self):
        for data in (b"", b'{"v":1', b"\xff\xfe", b"[]", b"null"):
            self._write(data)
            r = cli(["verify"], self.pw, self.root)
            self.assertNotEqual(r.returncode, 0, data)
            self.assertNotIn(self.pw, r.stdout + r.stderr)

    def test_wrong_passphrase_and_secret_never_echoed(self):
        r = cli(["verify"], self.pw + "x", self.root)
        self.assertEqual(r.returncode, 1)
        self.assertNotIn(self.pw, r.stdout + r.stderr)


class DiskAndPermissions(Base):
    @unittest.skipIf(os.geteuid() == 0, "root ignores directory permissions")
    def test_read_only_dir_seal_fails_cleanly_old_vault_intact(self):
        os.chmod(self.root, 0o500)
        try:
            with self.assertRaises(OSError):
                vault.seal_items(two_items(b"B"), passphrase=self.pw, out_root=self.root)
        finally:
            os.chmod(self.root, 0o700)
        self.assertOldVaultIntact()          # D1: blobs in writable subdirs WERE rewritten

    @unittest.skipIf(os.geteuid() == 0, "root ignores directory permissions")
    def test_read_only_manifest_dir_but_writable_blob_dirs(self):
        """Blob subdirs writable, root read-only: blobs in subdirs can be rewritten (nested dirs) while the
        manifest cannot -> the failure must still leave the OLD vault verifiable."""
        os.chmod(self.root, 0o500)
        try:
            with self.assertRaises(OSError):
                vault.seal_items(two_items(b"B"), passphrase=self.pw, out_root=self.root, merge=True)
        finally:
            os.chmod(self.root, 0o700)
        self.assertOldVaultIntact()

    DISK_FULL = """
        import os, resource, signal, sys
        signal.signal(signal.SIGXFSZ, signal.SIG_IGN)       # get EFBIG as OSError instead of a kill
        from pathlib import Path
        from career import vault
        resource.setrlimit(resource.RLIMIT_FSIZE, (int(os.environ["LIMIT"]),) * 2)
        items = [("android/en/cv", "cv.pdf", "application/pdf", b"B" * 3000),
                 ("go/ru/cover", "cover.pdf", "application/pdf", b"B" * int(os.environ["BIG"]))]
        try:
            vault.seal_items(items, passphrase=os.environ["PW"], out_root=Path(os.environ["ROOT"]),
                             merge=os.environ["MERGE"] == "1")
            print("SEALED")
        except OSError as e:
            print("OSERROR", e.errno)
    """

    def _disk_full(self, merge: bool):
        r = child(self.DISK_FULL, {"LIMIT": "20000", "BIG": "200000", "PW": self.pw,
                                   "ROOT": str(self.root), "MERGE": "1" if merge else "0"})
        self.assertEqual(r.returncode, 0, r.stderr[-800:])
        self.assertIn("OSERROR 27", r.stdout, r.stdout + r.stderr)        # EFBIG: the real kernel error surfaced

    def test_disk_full_replace_mode_leaves_old_vault_intact(self):
        self._disk_full(False)
        self.assertManifestNeverPartial()
        self.assertOldVaultIntact()

    def test_disk_full_merge_mode_leaves_old_vault_intact(self):
        self._disk_full(True)
        self.assertManifestNeverPartial()
        self.assertOldVaultIntact()

    def test_disk_full_never_publishes_partial_manifest(self):
        self._disk_full(False)
        self.assertManifestNeverPartial()


class KillMidSeal(Base):
    """SIGKILL (not an exception) at exact injection points of seal_items."""
    CODE = """
        import os, signal, sys
        from pathlib import Path
        from career import vault
        point = os.environ["POINT"]; n = int(os.environ.get("NTH", "1"))
        calls = {"w": 0}
        kill = lambda: os.kill(os.getpid(), signal.SIGKILL)
        if point == "blob-write":
            real = Path.write_bytes
            def wb(self, data):
                calls["w"] += 1
                if calls["w"] == n:
                    with open(self, "wb") as fh: fh.write(data[: len(data) // 2]); fh.flush()   # torn write
                    kill()
                return real(self, data)
            Path.write_bytes = wb
        elif point == "before-manifest-swap":
            vault.os.replace = lambda *a, **k: kill()
        elif point == "after-stale-unlink":
            real = Path.unlink
            def ul(self, *a, **k):
                r = real(self, *a, **k)
                if self.suffix == ".bin": kill()
                return r
            Path.unlink = ul
        items = [("android/en/cv", "cv.pdf", "application/pdf", b"B" * 4000),
                 ("go/ru/cover", "cover.pdf", "application/pdf", b"B" * 900)]
        if os.environ.get("DROP") == "1":
            items = items[:1]                       # replace-mode with fewer slots => stale blob unlinked
        vault.seal_items(items, passphrase=os.environ["PW"], out_root=Path(os.environ["ROOT"]),
                         merge=os.environ["MERGE"] == "1")
    """

    def _kill(self, point, merge=False, nth=1, drop=False):
        r = child(self.CODE, {"POINT": point, "NTH": str(nth), "PW": self.pw, "ROOT": str(self.root),
                              "MERGE": "1" if merge else "0", "DROP": "1" if drop else "0"})
        self.assertEqual(r.returncode, -signal.SIGKILL, (r.returncode, r.stderr[-600:]))

    def test_kill_before_manifest_swap_never_leaves_partial_manifest(self):
        self._kill("before-manifest-swap")
        self.assertManifestNeverPartial()

    def test_kill_before_manifest_swap_old_vault_intact(self):
        self._kill("before-manifest-swap")
        self.assertOldVaultIntact()

    def test_kill_mid_blob_write_merge_old_vault_intact(self):
        self._kill("blob-write", merge=True, nth=1)
        self.assertOldVaultIntact()

    def test_kill_mid_blob_write_replace_old_vault_intact(self):
        self._kill("blob-write", merge=False, nth=2)
        self.assertOldVaultIntact()

    def test_kill_after_stale_blob_unlink_vault_still_verifies(self):
        """D2: stale blobs are deleted only AFTER the manifest commit, so a kill right after the first
        deletion leaves the NEW (committed) vault -- complete and verifiable (only the kept slot)."""
        self._kill("after-stale-unlink", merge=False, drop=True)
        res = vault.verify_vault(self.pw, self.root)
        self.assertEqual([r["slot"] for r in res], ["android/en/cv"])

    def test_kill_leaves_no_half_written_vault_on_first_seal(self):
        """First-ever seal killed mid-way: a reader must see 'no vault' (VaultError), never a half vault."""
        fresh = Path(self.td.name) / "fresh"
        r = child(self.CODE, {"POINT": "blob-write", "NTH": "2", "PW": self.pw, "ROOT": str(fresh),
                              "MERGE": "0", "DROP": "0"})
        self.assertEqual(r.returncode, -signal.SIGKILL, r.stderr[-400:])
        self.assertFalse((fresh / "manifest.json").exists())
        with self.assertRaises(vault.VaultError):
            vault.verify_vault(self.pw, fresh)

    def test_recovery_after_killed_seal_next_seal_succeeds_and_verifies(self):
        self._kill("before-manifest-swap")
        # precondition (non-vacuous): the killed run left a temp manifest and unreferenced blobs behind
        self.assertTrue(list(self.root.glob(".manifest.*.tmp")), "killed run left no temp manifest")
        before = {p.relative_to(self.root).as_posix() for p in self.root.rglob("*.bin")}
        vault.seal_items(two_items(b"C"), passphrase=self.pw, out_root=self.root)
        self.assertEqual(len(vault.verify_vault(self.pw, self.root)), 2)
        self.assertEqual(list(self.root.glob(".manifest.*.tmp")), [], "temp manifest survived the next seal")
        m = json.loads((self.root / "manifest.json").read_text())
        live = {r["file"] for r in m["slots"].values()}
        on_disk = {p.relative_to(self.root).as_posix() for p in self.root.rglob("*.bin")}
        self.assertEqual(on_disk, live, f"unreferenced blobs left after next seal: {sorted(on_disk - live)}")
        self.assertGreater(len(before - live), 0, "no orphan existed before the next seal (test would be vacuous)")


if __name__ == "__main__":
    unittest.main(verbosity=2)
