# milosvasic.ru private vault repository

| | |
|---|---|
| Purpose | Record where the operator-sensitive milosvasic.ru console and vault material lives, how GitHub Actions can read it, and what is still an operator decision |
| Constitution | 11.4.10 (credentials), 11.4.6 (no guessing), 11.4.297 (PR delivery), 11.4.44 (revision header), 11.4.61 (metadata table + contents) |
| Revision | 2 (2026-11-25). Wired as submodule per operator decisions; revision 1 recorded the dormant state |
| Status | Draft for independent review (11.4.142) |
| Operator decision | 2026-11-25: "milosvasic.ru shall be safe so no sensitive files are there, however it can have PRIVATE Submodule inside with sensitive data which can be cloned only by the GitHub Pages System and US!" Chosen: NEW PRIVATE SUBMODULE |

## Contents

1. [State](#1-state)
4. [Wiring (revision 2)](#4-wiring-revision-2)
2. [Access proof](#2-access-proof)
3. [Options needing the operator](#3-options-needing-the-operator)

## 1. State

- Public site repo `milos85vasic/milosvasic.ru` main already ignores (`.gitignore`) and Jekyll-excludes (`_config.yml` `exclude:`) the seven sensitive paths: `admin/`, `_layouts/admin_console.html`, `assets/css/admin-console.css`, `assets/js/vault-console.js`, `assets/js/vault.js`, `downloads/vault/`, `matrix.tsv`. Landed earlier in site commit `14b2d8b`; the local shared working tree was simply behind origin.
- New PRIVATE repo `vasic-digital/milosvasic_ru_private` (main at `8abff3d`) holds those paths plus a README, imported from the backup taken 2026-11-25. Merge commits only (squash and rebase disabled). `rnabulsi` has `read`. `MarkoLazovicCode` also has `read`: operator decision 2026-11-25, intended, kept.
- The site repo does NOT reference the private repo. `milosvasic.ru/.github/workflows/pages.yml` is unchanged and `submodules: false` stays.
- Note: the vault PDFs in the private repo are plain `.pdf` files, not the sealed `.bin` format of `docs/career/vault-guide.md`.

## 2. Access proof

A read-only deploy key (id `171079854`, repo `milosvasic_ru_private`, `read_only=true`) is stored as Actions secret `PRIVATE_VAULT_DEPLOY_KEY` on the site repo (the private half only there; the scratch copy was kept outside git). A branch-only workflow (run `45600890856`, success, branch `pr/private-vault-access-proof`, workflow file never merged to main) showed: clone of the private repo succeeded (28 files), a push attempt was refused, a production Jekyll build with the private paths copied into the tree produced 1009 files and none of the seven paths appeared in `_site/` (the `_config.yml` excludes hold). Only counts were logged.

## 3. Options (decided, see section 4)

Wire-or-dormant, secret scope and the Marko access were decided by the operator on 2026-11-25. Whether to publish any private content remains NO: the PDFs are unsealed and nothing private is published.

## 4. Wiring (revision 2)

- Site PR `milos85vasic/milosvasic.ru#6`, merge commit `c03a86fa8c23`: submodule `_private` -> `vasic-digital/milosvasic_ru_private` (pinned `8abff3de`), `_private` added to Jekyll `exclude`, and `pages.yml` gained only `environment: private-vault` on the build job plus a "Check out private submodule" step (read-only deploy key, written 0600, removed after use). Build and deploy are otherwise unchanged.
- Secret scope: environment `private-vault` with a custom branch policy for `main` only holds `PRIVATE_VAULT_DEPLOY_KEY`; the repo-level secret was deleted.
- Proof sequence, each step recorded: (1) policy temporarily also allowed `pr/private-vault-wire`; (2) branch-only proof workflow run `45602267441` succeeded (site 1009 files, submodule 28 files, none of the private paths in `_site/`); (3) the temporary branch policy and the repo-level secret were removed and the proof workflow deleted before merge.
- First real run on main, `45603119180`: success. Live check: `https://milosvasic.ru/` answers 200; `/admin/console.html`, `/downloads/vault/manifest.json`, `/matrix.tsv`, `/assets/js/vault.js`, `/_private/README.md` answer 404.
- Exports (11.4.65): per `OPERATOR-DECISION-DROP-NONMD-EXPORTS-2026-11-24.md`, agents work with Markdown only; no non-Markdown export was generated for this document.
- Remaining: the proof branch `pr/private-vault-access-proof` on the site repo.
