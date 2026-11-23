# Vault guide: sealed CV and cover-letter downloads

| | |
|---|---|
| Purpose | Operator manual, guide and FAQ for the admin-only vault that delivers CV and cover-letter PDFs as encrypted static files |
| Constitution | 11.4.257 (user manual + guide + FAQ), 11.4.61 (metadata table + contents), 11.4.44 (revision header), 11.4.6 (no guessing), 11.4.10 (credentials) |
| Revision | 1 (2026-11-23). First version |
| Status | Draft for independent review (11.4.142) |
| Source of truth | `_tools/career/vault.py` (CLI and format), `milosvasic.ru/assets/js/vault.js` (browser decryption), `milosvasic.ru/assets/js/vault-console.js` and `milosvasic.ru/admin/console.html` (console) |
| Not covered | Building the PDFs (being reworked, see `site-build-guide.md`), and publishing the vault (see `deploy-guide.md`) |

## Contents

1. [What the vault is](#1-what-the-vault-is)
2. [What the vault is NOT (threat model)](#2-what-the-vault-is-not-threat-model)
3. [Provisioning the passphrase](#3-provisioning-the-passphrase)
4. [Command line usage](#4-command-line-usage)
5. [The admin console](#5-the-admin-console)
6. [Rotation](#6-rotation)
7. [Recovery](#7-recovery)
8. [Exit codes and troubleshooting](#8-exit-codes-and-troubleshooting)
9. [FAQ](#9-faq)
10. [Verification record](#10-verification-record)

## 1. What the vault is

The vault is a set of encrypted files that live on the public static site, plus a browser page that decrypts them after you type a passphrase.

* Each sealed PDF is one file `downloads/vault/<area>/<lang>/<kind>.bin`, where `<kind>` is `cv` or `cover`. A single `downloads/vault/manifest.json` lists the slots.
* Encryption is AES-256-GCM. The key comes from the passphrase through PBKDF2-HMAC-SHA-256 with exactly 600,000 iterations and one random 16-byte salt per vault. Every file gets its own random 12-byte nonce.
* The console is `milosvasic.ru/admin/console.html`. It fetches the manifest and the chosen `.bin`, derives the key in the browser, decrypts, and offers a download.
* The CLI is `python3 _tools/career/vault.py`. It seals PDFs from `.cache-career/`, verifies the vault, and unseals one slot to a file.

## 2. What the vault is NOT (threat model)

These statements are taken from the docstring of `_tools/career/vault.py`. Read them before trusting the vault with anything.

* **It protects only the bytes of the sealed PDFs** against a reader who has the public site and does not have the passphrase. The blobs, the salt and the manifest are public, so an attacker can run an offline brute force at will. The only real defence is passphrase entropy plus the 600,000 PBKDF2 iterations. The console's client-side throttle is convenience, not defence.
* **Public build inputs can be rebuilt by anyone.** The CV source inputs are slated to be public. With a deterministic build (fixed epoch) an attacker can regenerate the identical PDF without touching the vault. For that content the vault is a delivery gate (it hides the artifact, not the facts), not a secret.
* **What is in the public build input today, and therefore NOT secret:** `_content/career/profile.yaml` (identity, contact, experience, skills, projects, metrics, education, languages), `_content/career/areas/*.yaml` (recipes), `_content/career/locales/*.yaml`, and the renderers under `_tools/career/`. The source docstring marks this list as UNCONFIRMED against a future tracked tree.
* **What would need a gitignored private overlay to be secret:** any field you want hidden from the public (for example phone, home address, salary expectations, referees, unpublished employers). Such a field must be absent from every tracked file and supplied at build time from an ignored overlay. If it is in the tracked profile, sealing the PDF does not hide it. Whether to introduce that overlay is your decision; this guide does not make it.
* **Public metadata.** The manifest lists every slot (area, language, kind), the download file name, the MIME type and the ciphertext length. The ciphertext length is the plaintext length plus 16, so file size leaks. Padding is not implemented. The plaintext SHA-256 is deliberately not published, because it would be a confirmation oracle; the GCM tag authenticates integrity.
* **Same-origin code trust.** `vault.js` is served from the same origin as the blobs. Whoever can change the site can change the script and capture the passphrase as it is typed. No SRI or CSP fixes that for same-origin code.
* **No rollback / replay protection.** The manifest is unsigned public data. Whoever can write the site can republish an older valid vault (same passphrase) and the console will accept it; there is no freshness proof.
* **Page CSP is a `<meta>` tag.** It restricts scripts, styles and connections to the same origin, but `frame-ancestors` is ignored in a meta CSP, so framing/clickjacking protection for the console is NOT provided. It needs a real `Content-Security-Policy: frame-ancestors 'none'` response header from the host or CDN.
* **The console's lockout delay is a convenience, not a security control**; an attacker brute-forces the public blobs offline.
* **"Admin-only" means "holds the passphrase".** It is not an identity check. Anyone who learns the passphrase has full access, and there is no per-person revocation.

## 3. Provisioning the passphrase

The passphrase must reach the tool through one of two channels, and never through the command line:

1. The environment variable `CV_VAULT_PASSPHRASE`.
2. The file `_secure/cv-vault.passphrase` at the repository root. It must be a regular file, owned by you, mode `0600` (no group or world bits). A trailing newline is stripped. An empty file counts as "no passphrase".

The environment variable wins when both exist. The CLI never accepts the passphrase as an argument and never prints it.

Strength rule (sealing only): at least 77 bits by the tool's own upper-bound estimate, which means at least six random Diceware words. Rules from `estimate_bits`:

* Words separated by spaces or hyphens, each 3 to 9 ASCII letters, with at least 3 distinct letters and no run or keyboard/alphabet sequence, count 12.92 bits per distinct word (repeated words are credited once).
* Anything else is `length x min(log2(character pool), 4.0)` (so a character is never credited more than 4 bits), but only if it has at least 12 distinct characters, no character makes up more than a third of it, and it contains no run of three equal characters and no 4-long alphabet, keyboard-row or digit sequence (also checked on alternating characters). Otherwise it scores 0.

This is a **heuristic**: no wordlist is bundled, so six arbitrary short letter strings that look random pass even if you made them up. Only truly random generation makes the estimate true. Passphrases are Unicode NFC-normalised (identically in the CLI and the browser) before key derivation. Because the estimate is an upper bound, a passphrase you chose yourself can pass the check and still be weak. Generate the words with dice or a real random source; do not pick them. Never commit the file: `_secure/` must stay ignored (check with `git check-ignore -v _secure/cv-vault.passphrase`; not executed here because the file does not exist on this host).

Example (the file route, so the passphrase never appears in shell history):

```bash
mkdir -p _secure && chmod 700 _secure
umask 077
$EDITOR _secure/cv-vault.passphrase      # one line, six or more random words
chmod 600 _secure/cv-vault.passphrase
```

Not executed here: this host has no `_secure/cv-vault.passphrase`, and creating a real secret is your action. The refusal paths of the file route (wrong mode, wrong owner, not a regular file) are read from the code, not exercised.

## 4. Command line usage

Run from the repository root. Global options come before the subcommand.

```text
$ python3 _tools/career/vault.py --help
usage: vault [-h] [--out OUT] [--cache CACHE]
             {seal,seal-all,verify,unseal} ...

The admin-only vault -- encrypted static delivery of CV/cover PDFs.

options:
  --out OUT      vault directory (default milosvasic.ru/downloads/vault)
  --cache CACHE  (default .cache-career)
```

| Subcommand | Options | What it does |
|---|---|---|
| `seal` | `--area AREA` (repeatable, required), `--lang LANG` (repeatable, required), `--kind {cv,cover}` (repeatable) | Seals the matching PDFs from the cache and **merges** them into the existing vault. It reuses the vault salt and first proves your passphrase matches by decrypting one existing blob |
| `seal-all` | none | Seals every sealable PDF in the cache and **replaces** the whole vault. Slots absent from the new set are deleted from disk |
| `verify` | none | Decrypts every blob and checks it. Prints `verified N slot(s)` |
| `unseal` | `--slot SLOT`, `--to TO` (both required) | Decrypts one slot to a file with mode `0600`. Refuses any destination under `milosvasic.ru/` |

Only artifacts whose file name matches `cv-<area>-<lang>.pdf` or `cover-<area>-<lang>.pdf` are considered, and only those that pass the read-only PDF gate (`career.gates.validate_pdf`). Failing files are printed as `SKIP` lines on stderr and counted as skipped.

### 4.1 Real session

Executed on 2026-11-23 against copies of three real PDFs in a throwaway directory, with a throwaway passphrase, writing only to a scratch output directory (`$OUT` below). Nothing was written to `milosvasic.ru/downloads/vault`. The passphrase below is a disposable example; do not reuse it.

```text
$ export CV_VAULT_PASSPHRASE='<six random Diceware words>'
$ V="python3 _tools/career/vault.py --cache $OUT/cache --out $OUT/vault"

$ $V seal-all
sealed 3 slot(s); skipped 0            # rc 0
$ find $OUT/vault -type f
vault/manifest.json
vault/android/en/cover.bin
vault/android/en/cv.bin
vault/go/en/cv.bin

$ $V verify
verified 3 slot(s)                     # rc 0

$ $V seal --area go --lang en --kind cv
sealed 1 slot(s); skipped 0            # rc 0 (merge: other slots kept)

$ $V unseal --slot go/en/cv --to $OUT/go-en-cv.pdf
wrote 38507 bytes                      # rc 0; file mode -rw-------
$ cmp $OUT/go-en-cv.pdf $OUT/cache/cv-go-en.pdf && echo IDENTICAL
IDENTICAL
```

Size leak, measured: the source PDF is 38507 bytes and `go/en/cv.bin` is 38523 bytes (plaintext plus 16).

Manifest header and per-slot keys, read back from the generated manifest:

```text
{'alg': 'AES-256-GCM', 'iters': 600000, 'kdf': 'sha256', 'salt': '<22 chars>', 'v': 1}
['android/en/cover', 'android/en/cv', 'go/en/cv']
slot record keys: aad, mime, name, nonce
```

Replace mode prunes (the cover PDF was removed from the cache, then `seal-all` was run again):

```text
$ rm $OUT/cache/cover-android-en.pdf
$ $V seal-all
sealed 2 slot(s); skipped 0            # rc 0
$ find $OUT/vault -type f
vault/manifest.json
vault/android/en/cv.bin
vault/go/en/cv.bin                     # android/en/cover.bin is gone
```

Failure cases, all executed:

```text
$ CV_VAULT_PASSPHRASE='wrong horse battery staple lamp cable' $V verify
FAIL: authentication failed: not the published document      # rc 1
$ CV_VAULT_PASSPHRASE='amber falcon mosaic thunder pebble ribbon' $V seal --area go --lang en --kind cv
FAIL: authentication failed: not the published document      # rc 1 (merge refuses a different passphrase)
$ CV_VAULT_PASSPHRASE='short' $V seal-all
FAIL: passphrase too weak (0.0 bits < 77; low character diversity); use at least 6 random Diceware words   # rc 1
$ env -u CV_VAULT_PASSPHRASE $V verify
CANNOT DETERMINE: no passphrase: set CV_VAULT_PASSPHRASE or create <repo>/_secure/cv-vault.passphrase (mode 0600)   # rc 2
$ $V unseal --slot nope/en/cv --to $OUT/x.pdf
FAIL: unknown slot nope/en/cv                                 # rc 1
$ $V unseal --slot go/en/cv --to milosvasic.ru/should-not-exist.pdf
FAIL: refusing to write plaintext under milosvasic.ru/        # rc 1; no file created
$ $V
vault: error: the following arguments are required: cmd       # rc 2 (usage error)
```

### 4.2 Using it for real

Only after the PDFs are final (see `site-build-guide.md`; the PDF pipeline is being reworked). Not executed here, because it writes into the live tree:

```bash
# passphrase already provisioned (section 3)
python3 _tools/career/vault.py seal-all      # writes milosvasic.ru/downloads/vault/
python3 _tools/career/vault.py verify
```

`downloads/vault/` is excluded from deploys unless you set `DEPLOY_INCLUDE_ADMIN=1` (see `deploy-guide.md`).

## 5. The admin console

Page: `milosvasic.ru/admin/console.html`, front matter `layout: admin_console`, `sitemap: false`, `robots: noindex`. It is not linked from the site and is marked `noindex,nofollow`. Hiding it is not a security control.

How it works, read from `assets/js/vault-console.js`:

1. You type the passphrase and press **Unlock**. The page shows "Fetching manifest...", "Deriving key (about a second)...", "Verifying...", then "Ready".
2. On success two selectors appear (Area, Language) and one **Download CV** or **Download COVER** button per matching slot. Decryption happens when you press a button; the file is offered through a temporary object URL that is revoked after 30 seconds.
3. **Throttle.** Each failed unlock adds `min(30 s, 2^(failures-1) s)` of waiting: 1 s, 2 s, 4 s, 8 s, 16 s, then 30 s each time. During the wait the page says "Too many failures; wait N s." A page reload resets the counter, so this is UX only.
4. **Lock.** The **Lock** button, and leaving the page (`pagehide`), clear the key, the slot list and all object URLs.
5. A tampered or substituted file fails authentication and the page says so; it does not hand out unauthenticated bytes.

Not executed here: the console was not driven in a browser by this document's author. The Node and browser-side vault tests listed in section 10 exercise the same library (`vault.js`), not the DOM page.

## 6. Rotation

Use rotation when the passphrase is suspected leaked, or on a schedule you choose.

1. Generate a new passphrase of six or more random Diceware words (section 3).
2. Put it in `CV_VAULT_PASSPHRASE` (or the 0600 file).
3. Run `python3 _tools/career/vault.py seal-all`. **Do not use `seal`.** `seal` merges, reuses the old salt, and first tries to decrypt an existing blob with the new passphrase, which fails. `seal-all` is replace mode: it makes a new random salt, re-encrypts every slot, and deletes blobs that are no longer in the set.
4. Run `python3 _tools/career/vault.py verify`.
5. Publish (`deploy-guide.md`, with `DEPLOY_INCLUDE_ADMIN=1`).

Honest limit: the old ciphertext remains in git history and in any copy someone already downloaded. Rotation protects future publishes only. Anyone holding the old passphrase can still decrypt the old blobs they kept. Changing the passphrase does not un-publish old PDFs. If the PDF contents themselves must be secret, see section 2.

## 7. Recovery

* **Lost passphrase.** There is no recovery and no back door. Re-seal from the PDFs in `.cache-career/` under a new passphrase (`seal-all`). If the PDFs are gone too, rebuild them from the public inputs (`site-build-guide.md`).
* **Lost plaintext PDFs but vault and passphrase intact.** `unseal --slot <area>/<lang>/<kind> --to <path outside milosvasic.ru/>` recovers each one.
* **Corrupt or half-written vault.** New blobs get fresh names and the manifest is written to a unique temp file and renamed (the single commit point), so a crash leaves the old, complete vault in place. Superseded blobs are deleted only after the commit, and only files matching `<slot>.<b64>.bin` are ever deleted; a non-empty `--out` directory without `manifest.json` is refused, and any deletion that fails is reported as `WARN`. A browser holding the previous manifest while a seal lands may see a clean "missing" error and recovers by reloading. Run `verify`; if it fails, run `seal-all` again.
* **Wrong passphrase typed.** `verify` and the console say "authentication failed". Nothing is damaged.

## 8. Exit codes and troubleshooting

Exit codes of `vault.py` (read from `main()` and confirmed by the session above):

| Code | Meaning | Seen when |
|---|---|---|
| 0 | Success | `sealed N slot(s)`, `verified N slot(s)`, `wrote N bytes` |
| 1 | A real failure | Wrong passphrase or tampered blob ("authentication failed: not the published document"), weak passphrase, unknown slot, refusing to write under `milosvasic.ru/`, passphrase file with group/world bits or wrong owner, OS error |
| 2 | Could not determine, never a pass | No passphrase source; no sealable artifacts found in the cache; command line usage error |

| Symptom | Cause and action |
|---|---|
| `CANNOT DETERMINE: no passphrase` | Neither the environment variable nor the 0600 file exists. Section 3 |
| `FAIL: ... is group/world accessible (mode 0644); chmod 600` | `chmod 600 _secure/cv-vault.passphrase`. The mode text is from the code; not reproduced here |
| `FAIL: passphrase too weak` | Use six or more random Diceware words |
| `CANNOT DETERMINE: no sealable artifacts found` | The cache has no `cv-<area>-<lang>.pdf` or `cover-<area>-<lang>.pdf` that passes the gate. Check the `SKIP` lines on stderr, the `--cache` path, and the `--area` and `--lang` filters |
| `SKIP cv-x-en.pdf: gate rc=N: ...` | The read-only PDF gate rejected that file. Fix the PDF; it is not sealed |
| `FAIL: authentication failed` on `seal` | You are merging into a vault sealed under another passphrase. Use the original passphrase, or rotate with `seal-all` (section 6) |
| `FAIL: no manifest.json` | `--out` points at a directory with no vault |
| Console says wrong passphrase | The file at `/downloads/vault/` on the live site may not match; check it was deployed with `DEPLOY_INCLUDE_ADMIN=1`, then compare the live `manifest.json` salt to the local one |

## 9. FAQ

**Is the vault secure?** For the PDF bytes against someone without the passphrase, yes, up to the passphrase's entropy. For the facts in the PDFs, no, if those facts are in the public build inputs (section 2).

**Can I use a short passphrase?** Sealing refuses anything under 77 estimated bits. Verifying and unsealing do not check strength; that does not make a weak passphrase safe.

**Why one salt for the whole vault?** One 600,000-iteration derivation per vault instead of one per blob in the browser (hundreds of blobs would take minutes). Each blob still has a unique random nonce and an AAD binding its slot, name and MIME type.

**Does the manifest reveal anything?** Yes: which areas, languages and kinds exist, file names, MIME types and sizes (plus 16).

**Can two people use it?** Both need the same passphrase. There is no per-person access or revocation.

**Why can `unseal` not write under `milosvasic.ru/`?** To make sure a plaintext PDF never lands in a tree that is later published.

**Where do the PDFs come from?** `.cache-career/`, built by `career.py build`. The PDF build is being reworked by another agent; see `site-build-guide.md`.

## 10. Verification record

Executed on 2026-11-23 in this repository. Results are the real output.

| Command | Result |
|---|---|
| `python3 _tools/career/vault.py --help` and `seal`, `seal-all`, `verify`, `unseal` with `--help` | printed usage as quoted in section 4 |
| Session in section 4.1 (seal-all, verify, seal, unseal, prune, 7 failure cases) | outputs as quoted, scratch output directory only |
| `python3 _tools/career/test_vault.py` | rc 0; 15 Python tests OK (7.9 s) and 19 `node PASS` lines |

Not executed here:

| Item | Reason |
|---|---|
| `_secure/cv-vault.passphrase` creation and its mode/owner refusal messages | Creates or needs a real secret in the repository; text read from `load_passphrase` only |
| Sealing into `milosvasic.ru/downloads/vault/` | Writes into the live tree; the task forbade it |
| Driving `admin/console.html` in a browser; `test_vault_browser.py`, `test_vault_cross.js` | Not run for this document |
