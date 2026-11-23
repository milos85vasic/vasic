#!/usr/bin/env python3
"""The admin-only vault -- encrypted static delivery of CV/cover PDFs.

THREAT MODEL (read this before trusting the vault with anything)
================================================================
What the vault protects: the *bytes of the sealed PDFs* against a reader who
has the public site and does NOT have the passphrase.  Blobs, salt and
manifest are public; an attacker can run an offline brute-force against them
at will, so the ONLY real defence is passphrase entropy (see
``check_strength``) plus PBKDF2-HMAC-SHA-256 at 600,000 iterations.
Client-side throttling in the console is UX, not defence.

What the vault does NOT protect -- stated plainly, and NOT decided here:

* The CV source inputs are slated to be PUBLIC.  Anything derivable from the
  public build inputs can be rebuilt by anyone: with a deterministic build
  (fixed epoch) the attacker regenerates the identical PDF without ever
  touching the vault.  For such content the vault is a delivery gate (it
  hides the artifact, not the facts), not a secret.
* IN the public build input today (so NOT secret, rebuildable by anyone who
  has the repo): ``_content/career/profile.yaml`` (identity, contact,
  experience, skills, projects, metrics, education, languages),
  ``_content/career/areas/*.yaml`` (recipes), ``_content/career/locales/*.yaml``,
  and the renderers under ``_tools/career/``.  This list reflects the plan
  (``docs/plans/2026-11-19-milosvasic-ru-rework/PLAN.md`` section 4) and the
  untracked-but-to-be-tracked state of those paths; UNCONFIRMED against a
  future tracked tree.
* WHAT WOULD NEED a gitignored private overlay to be secret: any field the
  operator wants hidden from the public (for example phone, home address,
  salary expectations, referees, unpublished employers).  Such fields must be
  absent from every tracked file and supplied at build time from an ignored
  overlay; if they are in the tracked profile, sealing the PDF does not hide
  them.  Whether to introduce that overlay is the operator's decision.
* Public metadata: the manifest lists every slot (area/lang/kind), the
  download file name, MIME type and the ciphertext length (which is plaintext
  length + 16, so size leaks; padding is NOT implemented).  The plaintext
  SHA-256 is deliberately NOT published (it would be a confirmation oracle);
  the GCM tag authenticates integrity.
* Code-delivery trust: ``vault.js`` is served from the same origin as the
  blobs.  Whoever can change the site can change the script and capture the
  passphrase as it is typed.  No SRI/CSP can fix that for same-origin code.
* "Admin-only" means "holds the passphrase", not an identity check.

Cryptography
------------
* AES-256-GCM, fresh 12-byte CSPRNG nonce per blob, one key per vault.
* KDF: PBKDF2-HMAC-SHA-256, EXACTLY 600,000 iterations (OWASP floor), 16-byte
  random salt **per vault** (format v1).  Per-blob salts would force one
  600k-iteration derivation per blob in the browser (hundreds of blobs ->
  minutes); a per-vault salt costs one derivation and loses nothing because
  every blob gets a unique random nonce and an AAD binding its slot.  Nonce
  collision risk at 96 bits across a few hundred blobs is negligible.
  Nothing had shipped, so v1 was redefined rather than versioned up.
* ``<slot>.bin`` is ``ciphertext || 16-byte tag`` -- the exact framing of both
  ``cryptography``'s ``AESGCM.encrypt`` and WebCrypto ``subtle.decrypt``.  The
  tag is NOT stored in the manifest.
* AAD: the canonical JSON (see ``canonical_json``) of
  ``{v, alg, kdf, iters, salt, slot, name, mime}``.  The manifest stores the
  AAD string per slot; both languages RECOMPUTE it from the record fields and
  require byte equality with the stored string before decrypting, so a
  tampered name/slot/mime/header fails on both sides.
* Canonical JSON: keys sorted, compact separators, every non-ASCII code unit
  escaped as lower-case ``\\uXXXX`` (UTF-16 surrogate pairs for astral), the
  short escapes ``\\" \\\\ \\b \\f \\n \\r \\t`` and ``\\u00XX`` for other
  controls.  Identical bytes from Python ``ensure_ascii`` and JS
  ``JSON.stringify`` + a non-ASCII escaper (``vault.js``).

Files under ``<out_root>`` (default ``milosvasic.ru/downloads/vault/``):
``<area>/<lang>/<kind>.<nonce>.bin`` and ``manifest.json``.  No plaintext is
ever written there.  Each record carries ``file`` (its blob path relative to
the manifest); a record without ``file`` means the legacy ``<slot>.bin``.

Atomicity (single commit point).  A seal writes every new blob under a fresh
nonce-suffixed name (never over a live blob), fsyncs files, new directories and
``out_root``, and only then ``os.replace``s a uniquely-named, fsynced temp
manifest over ``manifest.json``.  That ``os.replace`` is THE commit point: after
it nothing is rolled back (the post-commit directory fsync is best effort), so
a SIGKILL, ENOSPC, EIO, read-only directory or concurrent reader always sees one
complete, verifiable vault (the old one or the new one).  Writers are serialised
with ``fcntl.flock`` on a descriptor of ``out_root`` itself -- no lock file
exists, so nothing extra can be published or deployed.

Reader limit, stated honestly: superseded blobs are deleted right after the
commit (so a replaced passphrase never leaves old-key blobs on the public site).
A browser that fetched the OLD manifest just before a seal and fetches its blob
just after gets a clean "missing/failed" error (never torn or wrong plaintext)
and recovers by reloading.  Cleanup only ever touches files matching the blob
grammar ``<slot>.<b64>.bin`` / own ``.manifest.*.tmp``; a non-empty directory
without ``manifest.json`` is refused, and deletions that fail are reported
(``SealResult.failed_deletions`` / CLI ``WARN``).

Not defended: rollback / replay.  The manifest is unsigned public data, so
whoever can write the site can republish an OLDER valid vault (same passphrase)
and the browser will accept it; there is no freshness proof.  Passphrases are
Unicode-NFC-normalised on both sides before key derivation (so NFC/NFD typing
differences open the same vault).  ``check_strength`` is a heuristic: without a
bundled wordlist it cannot verify a phrase is truly random (see ``estimate_bits``).

CLI exit codes: 0 ok; 1 failure (wrong passphrase, corrupt/unsupported
manifest or blob, I/O error, weak passphrase); 2 cannot determine (no
passphrase source, nothing sealable, bad usage).  A corrupt manifest is a
determinate failure, hence 1.

Passphrase: ``CV_VAULT_PASSPHRASE`` env, else ``_secure/cv-vault.passphrase``
(mode 0600, owned by the user, not group/world readable).  Never argv, never
printed.  With neither the CLI exits 2 (cannot determine) and invents nothing.
"""

from __future__ import annotations

import base64
import fcntl
import hashlib
import json
import math
import os
import re
import secrets
import stat
import sys
import unicodedata
from pathlib import Path
from typing import Any, Dict, Iterable, List, Mapping, Optional, Tuple

from cryptography.exceptions import InvalidTag
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

PBKDF2_ITERS = 600_000
SALT_BYTES = 16
NONCE_BYTES = 12
TAG_BYTES = 16
VAULT_VERSION = 1
ALGORITHM = "AES-256-GCM"
KDF = "sha256"

REPO_ROOT = Path(__file__).resolve().parents[2]
SITE_ROOT = REPO_ROOT / "milosvasic.ru"
VAULT_DIR = SITE_ROOT / "downloads" / "vault"
CACHE_DIR = REPO_ROOT / ".cache-career"
PASSPHRASE_FILE = REPO_ROOT / "_secure" / "cv-vault.passphrase"
ENV_PASSPHRASE = "CV_VAULT_PASSPHRASE"

#: Fields of the AAD (header fields + the per-slot identity fields).
AAD_FIELDS = ("v", "alg", "kdf", "iters", "salt", "slot", "name", "mime")
_SLOT_RE = re.compile(r"[a-z0-9][a-z0-9-]*(/[a-z0-9][a-z0-9-]*){0,3}")      # used with fullmatch
_B64_RE = re.compile(r"[A-Za-z0-9_-]+")                                       # used with fullmatch
_NONCE_TAG_RE = re.compile(r"[A-Za-z0-9_-]{16}")    # b64url of a 12-byte nonce: exactly what the sealer writes
_TMP_MANIFEST_RE = re.compile(r"\.manifest\.[0-9a-f]{16}\.tmp")   # secrets.token_hex(8)
_REC_KEYS = {"name", "mime", "nonce", "aad"}
_REC_KEYS_FILE = _REC_KEYS | {"file"}
_MIN_BITS = 77.0


class VaultError(ValueError):
    """Any format/authentication failure; message never contains secrets."""


class PassphraseUnavailable(Exception):
    """No passphrase source exists (CLI maps this to exit 2)."""


# --------------------------------------------------------------------- codec
def canonical_json(obj: Mapping[str, Any]) -> str:
    return json.dumps(obj, sort_keys=True, separators=(",", ":"), ensure_ascii=True)


def b64(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).decode("ascii").rstrip("=")


def unb64(s: str) -> bytes:
    if not isinstance(s, str) or not _B64_RE.fullmatch(s) or len(s) % 4 == 1:
        raise VaultError("malformed base64")
    try:
        raw = base64.b64decode(s.replace("-", "+").replace("_", "/") + "=" * (-len(s) % 4), validate=True)
    except ValueError as exc:
        raise VaultError("malformed base64") from exc
    if b64(raw) != s:                                   # canonical encodings only (no stray padding bits)
        raise VaultError("non-canonical base64")
    return raw


def derive_key(passphrase: str, salt: bytes) -> bytes:
    """PBKDF2-HMAC-SHA-256, 600,000 iterations (fixed, not configurable).

    The passphrase is NFC-normalised first (the browser does the same with
    ``String.prototype.normalize("NFC")``) so a passphrase typed on a keyboard/IME that
    produces decomposed forms opens the same vault.
    """
    return hashlib.pbkdf2_hmac(KDF, unicodedata.normalize("NFC", passphrase).encode("utf-8"),
                               salt, PBKDF2_ITERS, dklen=32)


def aad_for(*, salt: str, slot: str, name: str, mime: str) -> str:
    return canonical_json({"v": VAULT_VERSION, "alg": ALGORITHM, "kdf": KDF,
                           "iters": PBKDF2_ITERS, "salt": salt, "slot": slot,
                           "name": name, "mime": mime})


def _check_slot(slot: str) -> None:
    if not isinstance(slot, str) or not _SLOT_RE.fullmatch(slot):
        raise VaultError(f"invalid slot id: {slot!r}")


def _check_name(name: str, mime: str) -> None:
    if (not isinstance(name, str) or not name or len(name) > 200
            or any(c in name for c in "/\\") or any(ord(c) < 32 or ord(c) == 127 for c in name)):
        raise VaultError("invalid name")
    if (not isinstance(mime, str) or not mime or len(mime) > 100
            or any(ord(c) < 32 or ord(c) == 127 for c in mime)):
        raise VaultError("invalid mime")


def check_header(manifest: Mapping[str, Any]) -> bytes:
    """Enforce v/alg/kdf/iters EXACTLY before any derivation; returns the salt."""
    if (manifest.get("v") != VAULT_VERSION or manifest.get("alg") != ALGORITHM
            or manifest.get("kdf") != KDF or manifest.get("iters") != PBKDF2_ITERS
            or isinstance(manifest.get("iters"), bool) or isinstance(manifest.get("v"), bool)):
        raise VaultError("unsupported vault header (v/alg/kdf/iters)")
    salt = unb64(manifest.get("salt", ""))
    if len(salt) != SALT_BYTES:
        raise VaultError("bad salt length")
    if not isinstance(manifest.get("slots"), dict):
        raise VaultError("manifest has no slots")
    return salt


# --------------------------------------------------------------- seal/unseal
def seal_blob(plaintext: bytes, *, key: bytes, salt: str, slot: str, name: str,
              mime: str) -> Tuple[Dict[str, str], bytes]:
    """Return ``(manifest_record, blob)``; blob = ciphertext || tag."""
    _check_slot(slot)
    _check_name(name, mime)
    nonce = secrets.token_bytes(NONCE_BYTES)
    aad = aad_for(salt=salt, slot=slot, name=name, mime=mime)
    blob = AESGCM(key).encrypt(nonce, plaintext, aad.encode("ascii"))
    return {"name": name, "mime": mime, "nonce": b64(nonce), "aad": aad}, blob


def unseal_blob(blob: bytes, rec: Mapping[str, Any], *, key: bytes, salt: str,
                slot: str) -> bytes:
    """Authenticate + decrypt.  AAD is RECOMPUTED from fields and must equal rec['aad']."""
    _check_slot(slot)
    if not isinstance(rec, Mapping) or set(rec) not in (_REC_KEYS, _REC_KEYS_FILE):
        raise VaultError("malformed record")
    blob_rel(rec, slot)
    _check_name(rec["name"], rec["mime"])
    aad = aad_for(salt=salt, slot=slot, name=rec["name"], mime=rec["mime"])
    if rec["aad"] != aad:
        raise VaultError("record does not match its authenticated data")
    if len(blob) < TAG_BYTES:
        raise VaultError("blob too short")
    nonce = unb64(rec["nonce"])
    if len(nonce) != NONCE_BYTES:
        raise VaultError("bad nonce length")
    try:
        return AESGCM(key).decrypt(nonce, blob, aad.encode("ascii"))
    except InvalidTag as exc:
        raise VaultError("authentication failed: not the published document") from exc


# ------------------------------------------------------------- passphrases
_KEY_ROWS = ("qwertyuiop", "asdfghjkl", "zxcvbnm", "1234567890", "abcdefghijklmnopqrstuvwxyz")
_MAX_BITS_PER_CHAR = 4.0      # a human-typed character is never credited more than this
_WORD_BITS = math.log2(7776)  # Diceware credit per word, ONLY under the shape rules below


def _has_sequence(text: str, n: int = 4) -> bool:
    """True if ``text`` holds a run of >= n identical chars (3 for repeats) or an n-long
    alphabet / keyboard-row / digit sequence in either direction."""
    low = text.lower()
    if re.search(r"(.)\1\1", low):
        return True
    for row in _KEY_ROWS:
        for i in range(len(row) - n + 1):
            seg = row[i:i + n]
            if seg in low or seg[::-1] in low:
                return True
    return False


_DICT_WORDS: Optional[frozenset] = None


def _dictionary() -> frozenset:
    """Lowercase 3-9 letter words of the system dictionary (empty set if none)."""
    global _DICT_WORDS
    if _DICT_WORDS is None:
        words: set = set()
        for cand in ("/usr/share/dict/words", "/usr/share/dict/american-english"):
            try:
                with open(cand, encoding="utf-8", errors="ignore") as fh:
                    words = {w for w in (l.strip() for l in fh) if re.fullmatch(r"[a-z]{3,9}", w)}
                break
            except OSError:
                continue
        _DICT_WORDS = frozenset(words)
    return _DICT_WORDS


def _word_acceptable(w: str, dictionary: frozenset) -> bool:
    low = w.lower()
    if low in dictionary:                   # a real word: only a run of 3+ equal chars is rejected
        return not re.search(r"(.)\1\1", low)
    if dictionary:                          # unknown word: keep the strict shape rules
        return len(set(low)) >= 3 and not _has_sequence(w, min(4, len(w)))
    return not _has_sequence(w, 4)          # no dictionary: run of 3+ equal / 4+ sequence only


def estimate_bits(passphrase: str) -> Tuple[float, str]:
    """Upper-bound entropy HEURISTIC and the rule used.

    No wordlist is bundled, so this cannot know whether words are really from a
    Diceware list or whether characters were really random; it only rejects
    shapes that are provably low-entropy and caps what it credits:

    (a) Diceware-style: >= 2 whitespace/hyphen separated words, each 3-9 ASCII
        letters; a word found in the system dictionary is rejected only for a run of 3+
        equal chars, any other word needs >= 3 distinct letters and no run / keyboard /
        alphabet sequence (with no dictionary: only a run of 3+ equal chars or a 4+ sequence); REPEATED words are credited once; each credited word is
        worth at most log2(7776)=12.92 bits (so 6 distinct words = 77.5 bits).
        Six arbitrary short strings of that shape DO pass -- the vault cannot
        tell "xqz wkv jfp" from a real draw; the operator must generate the
        phrase randomly (e.g. ``diceware``/password-manager), which is the
        documented requirement.
    (b) otherwise: per-character credit = min(log2(charset pool), 4.0) bits
        (so a 94-symbol pool is worth 4.0 bits per char, not 6.55), and only
        if the string has >= 12 distinct characters, no character is more than
        a third of it, and it contains no run of 3 equal characters and no
        4-long alphabet/keyboard/digit sequence.
    """
    passphrase = unicodedata.normalize("NFC", passphrase)
    words = [w for w in re.split(r"[\s-]+", passphrase.strip()) if w]
    if len(words) >= 2 and all(re.fullmatch(r"[A-Za-z]{3,9}", w) for w in words):
        dictionary = _dictionary()
        good = {w.lower() for w in words if _word_acceptable(w, dictionary)}
        return len(good) * _WORD_BITS, f"diceware: {len(good)} distinct acceptable words x {_WORD_BITS:.2f} bits (heuristic)"
    if len(set(passphrase)) < 12 or max(passphrase.count(c) for c in set(passphrase)) > len(passphrase) / 3:
        return 0.0, "low character diversity"
    if (_has_sequence(passphrase) or _has_sequence(passphrase[::2]) or _has_sequence(passphrase[1::2])):
        return 0.0, "contains a run or an alphabet/keyboard/digit sequence"
    pool = 0
    pool += 26 if re.search(r"[a-z]", passphrase) else 0
    pool += 26 if re.search(r"[A-Z]", passphrase) else 0
    pool += 10 if re.search(r"[0-9]", passphrase) else 0
    pool += 33 if re.search(r"[^A-Za-z0-9]", passphrase) else 0
    if not pool:
        return 0.0, "no recognised character class"
    per = min(math.log2(pool), _MAX_BITS_PER_CHAR)
    return len(passphrase) * per, f"charset estimate: {len(passphrase)} chars x {per:.2f} bits (capped)"


def check_strength(passphrase: str) -> None:
    """Raise VaultError unless >= 77 bits (six Diceware words) by ``estimate_bits``."""
    bits, how = estimate_bits(passphrase)
    if bits < _MIN_BITS:
        raise VaultError(f"passphrase too weak ({bits:.1f} bits < {_MIN_BITS:.0f}; {how}); "
                         "use at least 6 random Diceware words")


def load_passphrase(env: Optional[Mapping[str, str]] = None,
                    path: Optional[Path] = None) -> str:
    """Env var first, else a 0600 file.  Raises PassphraseUnavailable if neither."""
    env = os.environ if env is None else env
    value = env.get(ENV_PASSPHRASE)
    if value:
        return value
    path = PASSPHRASE_FILE if path is None else Path(path)
    try:
        st = os.lstat(path)
    except FileNotFoundError:
        raise PassphraseUnavailable(
            f"no passphrase: set {ENV_PASSPHRASE} or create {path} (mode 0600)") from None
    if not stat.S_ISREG(st.st_mode):
        raise VaultError(f"{path} is not a regular file")
    if st.st_mode & 0o077:
        raise VaultError(f"{path} is group/world accessible (mode {stat.S_IMODE(st.st_mode):04o}); chmod 600")
    if st.st_uid != os.getuid():
        raise VaultError(f"{path} is not owned by the current user")
    text = path.read_text(encoding="utf-8").rstrip("\r\n")
    if not text:
        raise PassphraseUnavailable(f"{path} is empty")
    return text


# ------------------------------------------------------------------- vault
Item = Tuple[str, str, str, bytes]   # (slot, name, mime, plaintext)


def blob_rel(rec: Any, slot: str) -> str:
    """Relative blob path of a record: its ``file`` field, else legacy ``<slot>.bin``.

    ``file`` must be ``<slot>.<b64 chars>.bin`` so a manifest can never point
    outside its own slot's namespace.
    """
    _check_slot(slot)
    if not isinstance(rec, Mapping):
        raise VaultError("malformed record")
    if "file" not in rec:
        return slot + ".bin"
    f = rec["file"]
    if (not isinstance(f, str) or not f.startswith(slot + ".") or not f.endswith(".bin")
            or not _B64_RE.fullmatch(f[len(slot) + 1:-4])):
        raise VaultError("invalid blob file name")
    return f


def _read_manifest(out_root: Path) -> Optional[Dict[str, Any]]:
    """Parse manifest.json; None if absent; VaultError (never a traceback) if unusable."""
    p = out_root / "manifest.json"
    if not p.is_file():
        return None
    try:
        data = json.loads(p.read_text(encoding="utf-8"))
    except (ValueError, RecursionError) as exc:      # JSONDecodeError, UnicodeDecodeError are ValueErrors
        raise VaultError("manifest.json is corrupt or not valid UTF-8 JSON") from exc
    if not isinstance(data, dict):
        raise VaultError("manifest.json is not a JSON object")
    return data


def _fsync_path(path: Path, *, directory: bool = False) -> None:
    fd = os.open(path, os.O_RDONLY | (os.O_DIRECTORY if directory else 0))
    try:
        os.fsync(fd)
    finally:
        os.close(fd)


def seal_items(items: Iterable[Item], *, passphrase: str, out_root: Optional[Path] = None,
               merge: bool = False, _weak_ok: bool = False) -> SealResult:
    """Seal ``items`` into ``out_root``.

    merge=False replaces the whole vault (stale blobs of the previous manifest
    are deleted).  merge=True keeps other slots and replaces the given ones; it
    reuses the existing vault salt and first proves the passphrase matches by
    decrypting one existing blob.  ``_weak_ok`` is a TEST-ONLY override of the
    strength gate.
    """
    out_root = Path(out_root) if out_root else VAULT_DIR
    if not _weak_ok:
        check_strength(passphrase)
    items = list(items)
    seen = set()
    for slot, name, mime, _ in items:
        _check_slot(slot); _check_name(name, mime)
        if slot in seen:
            raise VaultError(f"duplicate slot {slot}")
        seen.add(slot)
    out_root.mkdir(parents=True, exist_ok=True)
    lock_fd = os.open(out_root, os.O_RDONLY | os.O_DIRECTORY)
    try:
        fcntl.flock(lock_fd, fcntl.LOCK_EX)           # serialises writers; released on close
        return _seal_locked(items, passphrase, out_root, merge)
    finally:
        os.close(lock_fd)


class SealResult(list):
    """List of sealed slot ids; ``failed_deletions`` names superseded blobs that could
    not be removed AFTER the commit (the vault is still valid; remove them by hand)."""
    failed_deletions: List[str]

    def __init__(self, it=()):
        super().__init__(it)
        self.failed_deletions = []


def _is_blob_path(rel: str) -> bool:
    """True iff ``rel`` (posix, relative to out_root) fits the blob grammar this
    module writes: ``<slot>.<b64>.bin`` with every directory component
    slot-shaped (a legacy ``<slot>.bin`` is swept only if the OLD manifest
    referenced it).  Nothing else under out_root is ever swept."""
    if not rel.endswith(".bin"):
        return False
    stem = rel[:-4]
    slot, _, tag = stem.rpartition(".")
    return bool(slot) and bool(_SLOT_RE.fullmatch(slot)) and bool(_NONCE_TAG_RE.fullmatch(tag))


def _fsync_ancestors(path: Path, out_root: Path) -> None:
    """fsync ``path`` and every directory up to and including ``out_root``."""
    d = path
    while True:
        _fsync_path(d, directory=True)
        if d == out_root:
            return
        d = d.parent


def _seal_locked(items: List[Item], passphrase: str, out_root: Path, merge: bool) -> SealResult:
    old = _read_manifest(out_root)
    if old is None and any(
            (p.is_file() or p.is_symlink())
            and not ((p.parent == out_root and _TMP_MANIFEST_RE.fullmatch(p.name) and not p.is_symlink())
                     or (p.is_file() and not p.is_symlink()
                         and _is_blob_path(p.relative_to(out_root).as_posix())))
            for p in out_root.rglob("*")):
        raise VaultError(f"{out_root} is not empty and has no manifest.json: refusing to seal "
                         "into a directory that is not a vault (nothing was changed)")
    slots: Dict[str, Any] = {}
    if merge and old is not None:
        salt_b = check_header(old)
        salt = old["salt"]
        key = derive_key(passphrase, salt_b)
        proved = None
        for s, rec in sorted(old["slots"].items()):
            f = out_root / blob_rel(rec, s)
            if f.is_file():
                unseal_blob(f.read_bytes(), rec, key=key, salt=salt, slot=s)  # wrong passphrase -> raises
                proved = s
                break
        if proved is None and old["slots"]:
            raise VaultError("cannot prove the passphrase: no existing blob is present to decrypt "
                             "(refusing to merge into a damaged vault)")
        slots = dict(old["slots"])
    else:
        salt_b = secrets.token_bytes(SALT_BYTES)
        salt = b64(salt_b)
        key = derive_key(passphrase, salt_b)
    result = SealResult()
    new_files: List[Path] = []
    tmp: Optional[Path] = None
    committed = False
    try:
        # 1. new blobs under fresh names; live blobs are never touched
        for slot, name, mime, data in items:
            rec, blob = seal_blob(data, key=key, salt=salt, slot=slot, name=name, mime=mime)
            rec["file"] = f"{slot}.{rec['nonce']}.bin"
            f = out_root / rec["file"]
            f.parent.mkdir(parents=True, exist_ok=True)
            new_files.append(f)
            f.write_bytes(blob)
            slots[slot] = rec
            result.append(slot)
        for f in new_files:
            _fsync_path(f)
        for d in {f.parent for f in new_files} | {out_root}:
            _fsync_ancestors(d, out_root)                # newly created ancestor dirs + out_root
        manifest = {"v": VAULT_VERSION, "alg": ALGORITHM, "kdf": KDF, "iters": PBKDF2_ITERS,
                    "salt": salt, "slots": dict(sorted(slots.items()))}
        # 2. unique temp manifest, fsynced; 3. the atomic swap is THE commit point
        tmp = out_root / (".manifest." + secrets.token_hex(8) + ".tmp")
        with open(tmp, "w", encoding="utf-8") as fh:
            fh.write(json.dumps(manifest, sort_keys=True, indent=1))
            fh.flush()
            os.fsync(fh.fileno())
        os.replace(tmp, out_root / "manifest.json")
        committed = True                                 # from here NOTHING may roll back
        tmp = None
    except BaseException:
        if not committed:
            for f in new_files:                          # roll back only what THIS run created
                try:
                    f.unlink()
                except OSError:
                    pass
            if tmp is not None:
                try:
                    tmp.unlink()
                except OSError:
                    pass
        raise
    try:                                                 # post-commit durability: best effort
        _fsync_path(out_root, directory=True)
    except OSError:
        pass
    # 4. only now delete what the committed manifest no longer references -- and only
    #    files that match the blob grammar or are our own temp manifests.
    live = {(out_root / blob_rel(r, s)) for s, r in manifest["slots"].items()}
    prior = set()
    old_slots = (old or {}).get("slots")
    for s_, r_ in (old_slots.items() if isinstance(old_slots, dict) else ()):
        try:
            prior.add(out_root / blob_rel(r_, s_))
        except VaultError:
            pass
    candidates = [f for f in sorted(out_root.rglob("*.bin"))
                  if f.is_file() and not f.is_symlink()
                  and (_is_blob_path(f.relative_to(out_root).as_posix()) or f in prior)]
    candidates += [f for f in sorted(out_root.glob(".manifest.*.tmp"))
                   if f.is_file() and not f.is_symlink() and _TMP_MANIFEST_RE.fullmatch(f.name)]
    for f in candidates:
        if f not in live:
            try:
                f.unlink(missing_ok=True)       # best effort: the commit already happened
            except OSError:
                result.failed_deletions.append(f.relative_to(out_root).as_posix())
    return result


def open_vault(passphrase: str, out_root: Optional[Path] = None) -> Tuple[Dict[str, Any], bytes]:
    out_root = Path(out_root) if out_root else VAULT_DIR
    manifest = _read_manifest(out_root)
    if manifest is None:
        raise VaultError("no manifest.json")
    return manifest, derive_key(passphrase, check_header(manifest))


def unseal_slot(manifest: Mapping[str, Any], key: bytes, slot: str,
                out_root: Optional[Path] = None) -> Tuple[Dict[str, Any], bytes]:
    out_root = Path(out_root) if out_root else VAULT_DIR
    if slot not in manifest["slots"]:
        raise VaultError(f"unknown slot {slot}")
    rec = manifest["slots"][slot]
    try:
        blob = (out_root / blob_rel(rec, slot)).read_bytes()
    except FileNotFoundError as exc:
        raise VaultError(f"blob for {slot} is missing (vault replaced or damaged)") from exc
    return rec, unseal_blob(blob, rec, key=key, salt=manifest["salt"], slot=slot)


def verify_vault(passphrase: str, out_root: Optional[Path] = None) -> List[Dict[str, Any]]:
    """Decrypt every blob; raises VaultError on the first failure."""
    manifest, key = open_vault(passphrase, out_root)
    results = []
    for slot in sorted(manifest["slots"]):
        rec, pt = unseal_slot(manifest, key, slot, out_root)
        results.append({"slot": slot, "name": rec["name"], "bytes": len(pt)})
    return results


# --------------------------------------------------------------------- CLI
def _split_artifact(stem: str) -> Optional[Tuple[str, str, str]]:
    m = re.fullmatch(r"(cv|cover)-([a-z0-9][a-z0-9-]*)-([a-z]{2})", stem)
    return (m.group(1), m.group(2), m.group(3)) if m else None


def collect_artifacts(cache: Path, *, areas: Optional[List[str]] = None,
                      langs: Optional[List[str]] = None, kinds: Optional[List[str]] = None,
                      validate=None) -> Tuple[List[Item], List[str]]:
    """Gather sealable PDFs from ``cache``; returns (items, skipped reasons).

    ``validate(pdf, kind) -> (rc, msg)``; default is gates.validate_pdf
    (read-only).  Only rc == 0 artifacts are sealed.
    """
    if validate is None:
        sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
        import importlib
        gates = importlib.import_module("career.gates")
        validate = gates.validate_pdf
    items: List[Item] = []
    skipped: List[str] = []
    for pdf in sorted(Path(cache).glob("*.pdf")):
        parts = _split_artifact(pdf.stem)
        if not parts:
            continue
        kind, area, lang = parts
        if (areas and area not in areas) or (langs and lang not in langs) or (kinds and kind not in kinds):
            continue
        rc, msg = validate(pdf, kind)
        if rc != 0:
            skipped.append(f"{pdf.name}: gate rc={rc}: {msg}")
            continue
        items.append((f"{area}/{lang}/{kind}", pdf.name, "application/pdf", pdf.read_bytes()))
    return items, skipped


def main(argv: Optional[List[str]] = None) -> int:
    import argparse
    ap = argparse.ArgumentParser(prog="vault", description=(__doc__ or "vault").split("\n")[0])
    ap.add_argument("--out", type=Path, default=None, help="vault directory (default milosvasic.ru/downloads/vault)")
    ap.add_argument("--cache", type=Path, default=CACHE_DIR)
    sub = ap.add_subparsers(dest="cmd", required=True)
    s = sub.add_parser("seal"); s.add_argument("--area", action="append", required=True)
    s.add_argument("--lang", action="append", required=True); s.add_argument("--kind", action="append", choices=["cv", "cover"])
    sa = sub.add_parser("seal-all")
    sa.add_argument("--to-private", action="store_true", help="write the vault into $CAREER_PRIVATE_DIR/vault")
    sub.add_parser("verify")
    u = sub.add_parser("unseal"); u.add_argument("--slot", required=True); u.add_argument("--to", type=Path, required=True)
    try:
        ns = ap.parse_args(argv)
    except SystemExit as e:
        return 2 if e.code else 0
    if getattr(ns, "to_private", False):
        import importlib.util as _ilu  # load by path: `career` may resolve to career.py when run as a script
        _spec = _ilu.spec_from_file_location("_career_overlay", Path(__file__).with_name("overlay.py"))
        _ov = _ilu.module_from_spec(_spec); _spec.loader.exec_module(_ov)
        try:
            ns.out = _ov.vault_out_dir()
        except _ov.OverlayError as e:
            print(f"CANNOT DETERMINE: {e}", file=sys.stderr); return 2
    try:
        pw = load_passphrase()
        if ns.cmd in ("seal", "seal-all"):
            check_strength(pw)
    except PassphraseUnavailable as e:
        print(f"CANNOT DETERMINE: {e}", file=sys.stderr); return 2
    except VaultError as e:
        print(f"FAIL: {e}", file=sys.stderr); return 1
    try:
        if ns.cmd in ("seal", "seal-all"):
            sel = ns.cmd == "seal"
            items, skipped = collect_artifacts(
                ns.cache, areas=ns.area if sel else None, langs=ns.lang if sel else None,
                kinds=(ns.kind if sel else None))
            for line in skipped:
                print("SKIP", line, file=sys.stderr)
            if not items:
                print("CANNOT DETERMINE: no sealable artifacts found", file=sys.stderr); return 2
            done = seal_items(items, passphrase=pw, out_root=ns.out, merge=sel)
            for rel in getattr(done, "failed_deletions", []):
                print(f"WARN could not delete superseded blob {rel}", file=sys.stderr)
            print(f"sealed {len(done)} slot(s); skipped {len(skipped)}")
            return 0
        if ns.cmd == "verify":
            res = verify_vault(pw, ns.out)
            print(f"verified {len(res)} slot(s)")
            return 0
        root = (ns.out or VAULT_DIR).resolve()
        dest = ns.to.resolve()
        if SITE_ROOT.resolve() in dest.parents:
            print("FAIL: refusing to write plaintext under milosvasic.ru/", file=sys.stderr); return 1
        manifest, key = open_vault(pw, root)
        _, pt = unseal_slot(manifest, key, ns.slot, root)
        fd = os.open(dest, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
        with os.fdopen(fd, "wb") as fh:                  # never overwrites, never follows a symlink
            fh.write(pt)
        print(f"wrote {len(pt)} bytes")
        return 0
    except (VaultError, OSError) as e:
        print(f"FAIL: {e}", file=sys.stderr); return 1


if __name__ == "__main__":
    sys.exit(main())
