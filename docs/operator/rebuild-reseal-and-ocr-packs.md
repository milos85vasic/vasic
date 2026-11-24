# Operator hand-off: rebuilt career cache, vault re-seal, OCR language packs

| | |
|---|---|
| Purpose | The two steps only the operator can take after the JSK-T178 hyphenation change and the JSK-T169 RTL gate: re-seal the vault (needs the passphrase) and install the OCR packs (needs sudo) |
| Constitution | 11.4.6 (no guessing), 11.4.10 (credentials), 11.4.142 (review) |
| Revision | 1 (2026-11-24) |
| Source of truth | `_tools/career/career.py`, `_tools/career/vault.py`, `_tools/career/extract_gates.py`, `docs/career/vault-guide.md` |

## Contents

1. [What was done for you](#1-what-was-done-for-you)
2. [Step A: re-seal the vault (passphrase)](#2-step-a-re-seal-the-vault-passphrase)
3. [Step B: install the OCR packs (sudo)](#3-step-b-install-the-ocr-packs-sudo)
4. [Step C: rerun the OCR check for the new locales](#4-step-c-rerun-the-ocr-check-for-the-new-locales)

## 1. What was done for you

The T178 change (no automatic hyphenation of words) alters every LuaLaTeX PDF, so every sealed blob is out of date. Everything that needs no passphrase was rebuilt:

* `python3 _tools/career/career.py build` rendered and gated the whole matrix (10 areas x 2 kinds x 15 locales = 300 PDFs) into the non-vault cache `.cache-career/` at the repository root (gitignored, not under `milosvasic.ru/`). No private overlay was set, matching the previously shipped set (its manifest carries no `overlay_sha`).
* `python3 _tools/career/career.py verify` then re-gated all 300 and checked `manifest.json` against the files on disk. The recorded output is in `docs/qa/career/verify-2026-11-24-t169-rebuild.txt` and `build-2026-11-24-t169-rebuild.txt`.
* The vault itself (`milosvasic.ru/downloads/vault`) was NOT touched: sealing needs your passphrase, and no secret was read, printed or asked for.

## 2. Step A: re-seal the vault (passphrase)

Run from the repository root of the main checkout (the one that holds `.cache-career/` and `_secure/`). The passphrase comes from `_secure/cv-vault.passphrase` (mode 0600) or from the environment variable `CV_VAULT_PASSPHRASE`; never put it on the command line.

```bash
python3 _tools/career/vault.py seal-all && python3 _tools/career/vault.py verify
```

`seal-all` is replace mode: it makes a new salt, re-encrypts every slot from `.cache-career/` and prunes slots no longer present. Expected last line of `verify`: `verified 300 slot(s)` (the number of sealable PDFs; a smaller number means some PDFs were skipped, and the `SKIP` lines on stderr name them).

Afterwards the changed files under `milosvasic.ru/downloads/vault/` are published through the usual site pull request (`docs/career/deploy-guide.md`); nothing in this hand-off pushes them.

## 3. Step B: install the OCR packs (sudo)

Today the OCR consistency gate (T179) judges en, ru, sr, de and fr. For the other ten locales it reports NOT APPLICABLE because no tesseract language pack is installed (`tesseract --list-langs` lists deu eng fra osd rus srp srp_latn). All ten packages exist on this host's apt (Ubuntu 26.04), read-only check with `apt-cache policy` on 2026-11-24, candidate `1:4.1.0-2build1` for every one, the same version line as the packs already installed:

| Locale | Package | Tesseract code | Installed size |
|---|---|---|---|
| hi | `tesseract-ocr-hin` | `hin` | 1109 KiB |
| ko | `tesseract-ocr-kor` | `kor` | 1651 KiB |
| ar | `tesseract-ocr-ara` | `ara` | 1411 KiB |
| fa | `tesseract-ocr-fas` | `fas` | 434 KiB |
| zh | `tesseract-ocr-chi-sim` | `chi_sim` | 2424 KiB |
| ja | `tesseract-ocr-jpn` | `jpn` | 2426 KiB |
| es | `tesseract-ocr-spa` | `spa` | 2253 KiB |
| tr | `tesseract-ocr-tur` | `tur` | 4456 KiB |
| be | `tesseract-ocr-bel` | `bel` | 3618 KiB |
| kk | `tesseract-ocr-kaz` | `kaz` | 4636 KiB |

One command:

```bash
sudo apt-get install -y tesseract-ocr-hin tesseract-ocr-kor tesseract-ocr-ara tesseract-ocr-fas \
  tesseract-ocr-chi-sim tesseract-ocr-jpn tesseract-ocr-spa tesseract-ocr-tur tesseract-ocr-bel tesseract-ocr-kaz
tesseract --list-langs
```

`zh` is Simplified Chinese (`chi-sim`); the product's `zh` documents are Simplified. The package names for traditional script (`tesseract-ocr-chi-tra`) also exist but are not needed.

## 4. Step C: rerun the OCR check for the new locales

Installing the packs does not by itself switch the gate on: the gate's locale table (`extract_gates.OCR_LANG`) still lists only the five locales, so `validate_pdf` keeps reporting the new ones as NOT APPLICABLE. That is deliberate: how well tesseract reads hi, ko, ar, fa, zh, ja is unmeasured, and making an unmeasured check blocking would fail the whole build on a guess. Measure first with the existing recall function, which takes an explicit language set (the Latin technology names make `+eng` mandatory, see the G-20 note in `extract_gates.py`):

```bash
cd _tools && python3 - <<'PY'
from pathlib import Path
from career import extract_gates as g
SPEC = {"hi": "hin+eng", "ko": "kor+eng", "ar": "ara+eng", "fa": "fas+eng", "zh": "chi_sim+eng",
        "ja": "jpn+eng", "es": "spa+eng", "tr": "tur+eng", "be": "bel+eng", "kk": "kaz+eng"}
for lang, spec in SPEC.items():
    for kind in ("cv", "cover"):
        pdf = Path("..") / ".cache-career" / f"{kind}-ai-engineering-{lang}.pdf"
        r = g.ocr_recall(pdf, lang, spec=spec)
        print(f"{kind}-ai-engineering-{lang}: recall={'cannot determine (pack missing)' if r is None else f'{r:.0%}'}  (bar {g.MIN_OCR_RECALL:.0%})")
PY
```

A `None` line means the pack is still missing (rc 2 territory, never a pass). Report the numbers; the follow-up change adds each locale whose recall clears the bar to `OCR_LANG`, which makes the existing gate (`validate_pdf`, `career.py build`, `verify`) apply to it, with a paired mutation proof, as was done for ru/sr/de/fr. Locales that do not clear it need their own root-cause investigation before any threshold is touched.
