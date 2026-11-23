# Website release process (milosvasic.ru)

| Field | Value |
|---|---|
| Scope | `milosvasic.ru` site repository (`milos85vasic/milosvasic.ru`, submodule `milosvasic.ru/`) |
| Source of truth | `milosvasic.ru/VERSION` (semver `MAJOR.MINOR.PATCH`, one line) |
| Footer | `Website version: v<VERSION>` on every page, linked to `https://github.com/milos85vasic/milosvasic.ru/releases/tag/v<VERSION>` |
| Revision | 2026-11-24 |

The version is shown in the footer of every page. The footer link target is the
GitHub release page of the tag `v<VERSION>`, so the tag and release MUST exist
before (or at the moment) the deploy that shows the link goes live, or the link
404s. `vasic.digital` is handled separately and is not covered here.

## How the version reaches the pages

* `VERSION` is read once by `_plugins/mv_version.rb` (Jekyll `:site, :after_init`),
  which exposes `site.mv_version` and `site.mv_release_url_prefix`. A missing or
  non-semver `VERSION` fails the build.
* `_layouts/default.html` renders the footer for every page type (home, localized
  homes, products, expertise, portfolio): label from `_data/ui.json`
  (`footer.version`, 15 languages; mirrored in `assets/js/i18n.js` for the runtime
  language switcher) plus the `v<VERSION>` link.
* Styles: `.mv-ver*` in `design-system/brand-milosvasic/milosvasic.css`, with the
  byte-identical copy `milosvasic.ru/assets/od/milosvasic.css`
  (`python3 _tools/career/check_a2_contrast.py <both paths>` must stay green).

## Procedure (every release)

1. Branch in the site repo: `git -C milosvasic.ru switch -c release/vX.Y.Z`.
2. Bump `milosvasic.ru/VERSION` (and nothing else is needed for the footer).
3. Open a PR (`env -u GITHUB_TOKEN gh pr create -R milos85vasic/milosvasic.ru`),
   get an independent review, merge with `gh pr merge --merge` (never force-push).
4. On the merged `main` HEAD of the site repo, create the annotated tag and push it:
   `git tag -a vX.Y.Z -m "milosvasic.ru vX.Y.Z" && git push origin vX.Y.Z`.
5. Create the release with honest notes:
   `env -u GITHUB_TOKEN gh release create vX.Y.Z -R milos85vasic/milosvasic.ru --title "milosvasic.ru vX.Y.Z" --notes-file NOTES.md`.
6. Watch the Pages deploy: `env -u GITHUB_TOKEN gh run list -R milos85vasic/milosvasic.ru`
   then `gh run watch <id>`.
7. Bump the umbrella gitlink and `helix-deps.yaml` ref together
   (`bash scripts/verify-manifest-pins.sh`), PR, review, merge.

## Gates (version cannot drift)

```bash
# a build exists (container build, never the host): 
_tools/containers/bin/site-build -workload jekyll -build-year 2026

# (a)+(b): every built page shows v<VERSION> with the exact release link, and
# VERSION == newest v* git tag.  Pre-release PR state: add --allow-unreleased.
python3 _tools/career/check_version_footer.py --site-dir milosvasic.ru/_site --repo milosvasic.ru
# (c) additionally the release page answers HTTP 200:
python3 _tools/career/check_version_footer.py --site-dir milosvasic.ru/_site --repo milosvasic.ru --online
# (d) mutation proof (wrong link / text / label / missing footer / unreleased / stale / bad semver):
python3 _tools/career/check_version_footer.py --prove-failure

# live (or local-served) crawl: every HTML page + release URL 200
python3 scripts/verify-live-site.py --base https://milosvasic.ru \
  --baseline docs/qa/live-site/baseline-live-2026-11-23.json \
  --expect-version X.Y.Z \
  --version-url-prefix https://github.com/milos85vasic/milosvasic.ru/releases/tag/v
python3 scripts/verify-live-site.py --prove-failure   # includes the version-footer seeded defects

# browser: footer per language, runtime switch, RTL no-overflow
cd _tests && npx playwright test tests/milosvasic-ru-version-footer.spec.js
```

Exit convention: 0 held, 1 violation, 2 could not determine (never a pass).
