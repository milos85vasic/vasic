# milosvasic.ru private vault repository

| | |
|---|---|
| Purpose | Record where the operator-sensitive milosvasic.ru console and vault material lives, how GitHub Actions can read it, and what is still an operator decision |
| Constitution | 11.4.10 (credentials), 11.4.6 (no guessing), 11.4.297 (PR delivery), 11.4.44 (revision header), 11.4.61 (metadata table + contents) |
| Revision | 1 (2026-11-25). First version |
| Status | Draft for independent review (11.4.142) |
| Operator decision | 2026-11-25: "milosvasic.ru shall be safe so no sensitive files are there, however it can have PRIVATE Submodule inside with sensitive data which can be cloned only by the GitHub Pages System and US!" Chosen: NEW PRIVATE SUBMODULE |

## Contents

1. [State](#1-state)
2. [Access proof](#2-access-proof)
3. [Options needing the operator](#3-options-needing-the-operator)

## 1. State

- Public site repo `milos85vasic/milosvasic.ru` main already ignores (`.gitignore`) and Jekyll-excludes (`_config.yml` `exclude:`) the seven sensitive paths: `admin/`, `_layouts/admin_console.html`, `assets/css/admin-console.css`, `assets/js/vault-console.js`, `assets/js/vault.js`, `downloads/vault/`, `matrix.tsv`. Landed earlier in site commit `14b2d8b`; the local shared working tree was simply behind origin.
- New PRIVATE repo `vasic-digital/milosvasic_ru_private` (main at `8abff3d`) holds those paths plus a README, imported from the backup taken 2026-11-25. Merge commits only (squash and rebase disabled). `rnabulsi` has `read`. `MarkoLazovicCode` also shows `read` in the collaborator list (UNCONFIRMED whether inherited from an organisation base permission; not changed here).
- The site repo does NOT reference the private repo. `milosvasic.ru/.github/workflows/pages.yml` is unchanged and `submodules: false` stays.
- Note: the vault PDFs in the private repo are plain `.pdf` files, not the sealed `.bin` format of `docs/career/vault-guide.md`.

## 2. Access proof

A read-only deploy key (id `171079854`, repo `milosvasic_ru_private`, `read_only=true`) is stored as Actions secret `PRIVATE_VAULT_DEPLOY_KEY` on the site repo (the private half only there; the scratch copy was kept outside git). A branch-only workflow (run `45600890856`, success, branch `pr/private-vault-access-proof`, workflow file never merged to main) showed: clone of the private repo succeeded (28 files), a push attempt was refused, a production Jekyll build with the private paths copied into the tree produced 1009 files and none of the seven paths appeared in `_site/` (the `_config.yml` excludes hold). Only counts were logged.

## 3. Options needing the operator

1. Wire into the build or keep dormant. Wiring means a pages.yml step that clones the private repo with the key. Today nothing in the site build needs it, since all seven paths are excluded from publication; the key and secret can stay unused.
2. Whether any private content is to be published. The PDFs are unencrypted, so publishing them would make them public. Only sealed `.bin` output should ever reach `_site/`.
3. Cleanup: the proof branch `pr/private-vault-access-proof` remains on the site repo (remote branch deletion was not performed by the agent) and can be deleted by the operator.
4. Secret scope: a repository secret is readable by any workflow on a branch in the site repo, so write access to the site repo equals read access to the vault. An environment-scoped secret restricted to `main` is the tighter option.
