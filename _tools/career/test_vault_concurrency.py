#!/usr/bin/env python3
"""Concurrency / race tests for the vault (constitution 11.4.85 / 11.4.169).

Races are made DETERMINISTIC with file-based barriers injected into child processes (no sleeps, no
wall-clock assertions; the only timeout is a deadlock guard).  Writers are serialised by
``fcntl.flock`` on ``out_root``; the tests produce direct CONTENTION EVIDENCE for that lock:

  1. both children signal ``<name>.ready`` (just before calling seal_items) and the test waits for BOTH
     before releasing anyone;
  2. a child that acquired the lock is paused inside ``_read_manifest`` (first thing under the lock) or
     just before ``os.replace`` until the test touches ``<name>.go``;
  3. while the holder is paused the test asserts (a) a non-blocking ``flock`` on out_root from the test
     process raises BlockingIOError, and (b) ``/proc/locks`` lists the peer's PID as a BLOCKED waiter
     and the peer has NOT reached its post-lock point.  Without the lock the peer reaches that point
     immediately and (b) fails; the tests were mutation-checked against a lock-less copy of vault.py.

The previously recorded defects (D4 no lock / shared temp name, D1 blobs published before the manifest)
are FIXED in vault.py (flock, unique temp manifest, nonce-named blobs, manifest swap as the single commit
point), so these are plain assertions, not ``known_defect`` expected failures.
"""
from __future__ import annotations

import fcntl
import json
import os
import secrets
import subprocess
import sys
import tempfile
import textwrap
import time
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from career import vault  # noqa: E402

PARENT = str(Path(__file__).resolve().parents[1])
BARRIER_TIMEOUT = 90  # seconds; only a deadlock guard, never a timing assertion

CHILD = """
import os, sys, time
from pathlib import Path
from career import vault
sync = Path(os.environ["SYNC"]); name = os.environ["NAME"]
def pause(tag):
    (sync / (name + "." + tag)).touch()
    end = time.monotonic() + %d                  # deadlock guard only
    while not (sync / (name + ".go")).exists():
        if time.monotonic() > end:
            os._exit(3)
        time.sleep(0.005)
point = os.environ.get("POINT", "")
if point == "after-lock":                    # first thing done UNDER the lock: manifest read
    real = vault._read_manifest
    def rm(root):
        pause("locked"); return real(root)
    vault._read_manifest = rm
elif point == "before-replace":              # blobs written, manifest NOT yet swapped (lock held)
    real = vault.os.replace
    def rp(a, b):
        pause("locked"); return real(a, b)
    vault.os.replace = rp
items = [(s, s.replace("/", "-") + ".pdf", "application/pdf", os.environ["TAG"].encode() * 700)
         for s in os.environ["SLOTS"].split(",")]
(sync / (name + ".ready")).touch()
try:
    vault.seal_items(items, passphrase=os.environ["PW"], out_root=Path(os.environ["ROOT"]),
                     merge=os.environ["MERGE"] == "1")
    (sync / (name + ".done")).touch()
    print("OK")
except Exception as e:
    print("EXC", type(e).__name__, e); sys.exit(4)
""" % BARRIER_TIMEOUT


def pw() -> str:
    letters = "abcdefghijklmnopqrstuvwxyz"
    return " ".join("".join(secrets.choice(letters) for _ in range(7)) for _ in range(7))


class Base(unittest.TestCase):
    def setUp(self):
        self.td = tempfile.TemporaryDirectory(); self.addCleanup(self.td.cleanup)
        self.root = Path(self.td.name) / "v"
        self.sync = Path(self.td.name) / "sync"; self.sync.mkdir()
        self.pw = pw()
        vault.seal_items([("base/en/cv", "base.pdf", "application/pdf", b"Z" * 1000)],
                         passphrase=self.pw, out_root=self.root)
        self.procs = []
        self.addCleanup(self._reap)

    def _reap(self):
        for p in self.procs:                   # only OUR children
            if p.poll() is None:
                p.kill(); p.wait()

    def start(self, name, *, slots, tag, merge, point="", peer=""):
        env = dict(os.environ, PYTHONPATH=PARENT, SYNC=str(self.sync), NAME=name, POINT=point, PEER=peer,
                   SLOTS=slots, TAG=tag, PW=self.pw, ROOT=str(self.root), MERGE="1" if merge else "0")
        p = subprocess.Popen([sys.executable, "-c", textwrap.dedent(CHILD)], env=env,
                             stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        self.procs.append(p)
        return p

    def wait_reached(self, name):
        end = time.monotonic() + BARRIER_TIMEOUT
        while not (self.sync / (name + ".reached")).exists():
            self.assertLess(time.monotonic(), end, f"{name} never reached its barrier")
            time.sleep(0.005)

    def reached(self, name, tag):
        return (self.sync / f"{name}.{tag}").exists()

    def wait_for(self, pred, what):
        end = time.monotonic() + BARRIER_TIMEOUT
        while not pred():
            self.assertLess(time.monotonic(), end, f"timed out waiting for {what}")
            time.sleep(0.005)

    @staticmethod
    def blocked_pids():
        """PIDs listed as BLOCKED waiters ('->') in /proc/locks, or None if unreadable."""
        try:
            txt = Path("/proc/locks").read_text()
        except OSError:
            return None
        pids = set()
        for ln in txt.splitlines():
            f = ln.split()
            if len(f) > 5 and f[1] == "->":
                pids.add(int(f[5]))
        return pids

    def lock_held_by_someone(self):
        fd = os.open(self.root, os.O_RDONLY | os.O_DIRECTORY)
        try:
            try:
                fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError:
                return True
            fcntl.flock(fd, fcntl.LOCK_UN)
            return False
        finally:
            os.close(fd)

    def race(self, pa, pb, name_a="A", name_b="B"):
        """Both children READY before anyone is released; exactly one wins the lock and pauses under it.
        Asserts flock contention evidence, then releases holder, then peer.  Returns (holder, peer)."""
        self.wait_for(lambda: self.reached(name_a, "ready") and self.reached(name_b, "ready"), "both children ready")
        self.wait_for(lambda: self.reached(name_a, "locked") or self.reached(name_b, "locked")
                      or {pa.pid, pb.pid} <= (self.blocked_pids() or set()), "a lock holder")
        locked = [n for n in (name_a, name_b) if self.reached(n, "locked")]
        self.assertEqual(len(locked), 1, f"both writers are inside the critical section at once: {locked}")
        holder = locked[0]
        peer_name, peer = (name_b, pb) if holder == name_a else (name_a, pa)
        blocked = self.blocked_pids()
        if blocked is None:
            self.skipTest("/proc/locks unreadable: cannot obtain lock-contention evidence (NOT a pass)")
        self.wait_for(lambda: peer.pid in (self.blocked_pids() or set()) or self.reached(peer_name, "locked"),
                      "peer blocked in flock")
        self.assertIn(peer.pid, self.blocked_pids(), "peer is not blocked on the vault lock")
        self.assertFalse(self.reached(peer_name, "locked"), "peer passed its post-lock point while holder held the lock")
        self.assertTrue(self.lock_held_by_someone(), "out_root flock is not held while the holder is paused")
        self.go(holder)
        self.wait_for(lambda: self.reached(peer_name, "locked"), "peer to acquire lock after release")
        self.go(peer_name)
        return holder, peer_name

    def go(self, name):
        (self.sync / (name + ".go")).touch()

    def finish(self, p):
        out, err = p.communicate(timeout=BARRIER_TIMEOUT + 60)
        return p.returncode, out.strip(), err.strip()


class WriterWriter(Base):
    def test_two_merge_sealers_same_vault_no_lost_update(self):
        """A adds a/en/cv, B adds b/en/cv, both started and READY before either proceeds.  One holds the
        lock paused under it; the other is provably blocked in flock; after release both finish.
        Correct behaviour: no lost update -- base + a + b, final manifest complete JSON, vault verifies."""
        a = self.start("A", slots="a/en/cv", tag="a", merge=True, point="after-lock")
        b = self.start("B", slots="b/en/cv", tag="b", merge=True, point="after-lock")
        self.race(a, b)
        ra, rb = self.finish(a), self.finish(b)
        self.assertEqual((ra[0], rb[0]), (0, 0), (ra, rb))
        m = json.loads((self.root / "manifest.json").read_text())
        self.assertEqual(set(m["slots"]), {"base/en/cv", "a/en/cv", "b/en/cv"}, "lost update")
        self.assertEqual(len(vault.verify_vault(self.pw, self.root)), 3)

    def test_two_replace_sealers_serialise_and_leave_consistent_vault(self):
        """Replace mode, different salts: the second sealer must wait for the first's COMMIT (pause is
        before os.replace, lock held), never interleave its blobs/manifest with the first's."""
        a = self.start("A", slots="x/en/cv,y/en/cv", tag="a", merge=False, point="before-replace")
        b = self.start("B", slots="x/en/cv,y/en/cv", tag="b", merge=False, point="before-replace")
        self.race(a, b)
        ra, rb = self.finish(a), self.finish(b)
        self.assertEqual((ra[0], rb[0]), (0, 0), (ra, rb))
        self.assertEqual(len(vault.verify_vault(self.pw, self.root)), 2)
        files = {p.relative_to(self.root).as_posix() for p in self.root.rglob("*.bin")}
        m = json.loads((self.root / "manifest.json").read_text())
        self.assertEqual(files, {r["file"] for r in m["slots"].values()}, "orphan blobs from the loser")

    def test_unique_temp_manifest_names_and_writers_serialise(self):
        """No shared 'manifest.json.tmp': while A is paused with its temp manifest already written, B (blocked
        on the lock) has not created one; both exit 0 and the vault is complete JSON that verifies."""
        a = self.start("A", slots="x/en/cv", tag="a", merge=False, point="before-replace")
        b = self.start("B", slots="y/en/cv", tag="b", merge=False, point="before-replace")
        self.race(a, b)
        ra, rb = self.finish(a), self.finish(b)
        self.assertEqual((ra[0], rb[0]), (0, 0), (ra, rb))
        self.assertFalse((self.root / "manifest.json.tmp").exists())
        self.assertEqual(list(self.root.glob(".manifest.*.tmp")), [])
        self.assertEqual(len(vault.verify_vault(self.pw, self.root)), 1)
        json.loads((self.root / "manifest.json").read_text())


class ReaderWriter(Base):
    def test_verify_during_seal_sees_a_consistent_vault(self):
        """Writer paused after publishing new blobs but before the manifest swap; a concurrent verify of the
        PREVIOUS vault must still pass (a reader must never observe a torn state)."""
        a = self.start("A", slots="base/en/cv", tag="n", merge=True, point="before-replace")
        self.wait_for(lambda: self.reached("A", "locked"), "A paused under the lock")
        try:
            res = vault.verify_vault(self.pw, self.root)       # reader in the window
            self.assertEqual(len(res), 1)
        finally:
            self.go("A"); self.finish(a)

    def test_verify_after_seal_completes_sees_new_vault(self):
        a = self.start("A", slots="base/en/cv", tag="n", merge=True)
        self.assertEqual(self.finish(a)[0], 0)
        m, key = vault.open_vault(self.pw, self.root)
        self.assertEqual(vault.unseal_slot(m, key, "base/en/cv", self.root)[1], b"n" * 700)

    def test_unseal_with_stale_manifest_while_merge_replaces_blob_fails_cleanly(self):
        """Reader opened the vault (old manifest in memory); a merge then replaces that slot's blob.  The
        reader's later unseal_slot must raise VaultError (authentication) -- never return wrong/garbage
        plaintext.  The window itself is inherent to fixed blob names (see module docstring fix)."""
        m_old, key = vault.open_vault(self.pw, self.root)
        a = self.start("A", slots="base/en/cv", tag="n", merge=True)
        self.assertEqual(self.finish(a)[0], 0)
        with self.assertRaises(vault.VaultError):
            vault.unseal_slot(m_old, key, "base/en/cv", self.root)
        m_new, key2 = vault.open_vault(self.pw, self.root)       # re-open recovers
        self.assertEqual(vault.unseal_slot(m_new, key2, "base/en/cv", self.root)[1], b"n" * 700)

    def test_unseal_during_blob_replace_window_never_returns_garbage(self):
        """Writer paused between blob write and manifest swap in merge mode (new blob, old record): every
        reader outcome must be a clean VaultError or the OLD plaintext -- never other bytes."""
        a = self.start("A", slots="base/en/cv", tag="n", merge=True, point="before-replace")
        self.wait_for(lambda: self.reached("A", "locked"), "A paused under the lock")
        try:
            m, key = vault.open_vault(self.pw, self.root)
            try:
                _, pt = vault.unseal_slot(m, key, "base/en/cv", self.root)
                self.assertEqual(pt, b"Z" * 1000)
            except vault.VaultError:
                pass
        finally:
            self.go("A"); self.finish(a)


if __name__ == "__main__":
    unittest.main(verbosity=2)
