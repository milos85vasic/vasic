# Run log (2026-11-24): scratch build, nothing deployed

Scratch root outside the repository. milosvasic.ru at e8ea2b1 and vasic.digital at 3e86312 were extracted with `git archive`; the submodule working trees were not touched (the main checkout has another session's untracked WIP in milosvasic.ru).

- Baseline determinism: regenerating all 15 languages with the UNMODIFIED dictionary reproduced the committed submodule output byte for byte for both sites (excluding sitemap/robots/feed dates). Every diff below is therefore attributable to the string fixes only.
- Glossary audit (`_tools/gen/audit_ui_glossary.py`): before 28 violations; after "GLOSSARY AUDIT: clean".
- `merge_ui.py`: 14/14 languages at 89/89 keys. `go test ./...` in `_tools/gen`: ok (in the scratch root; in a bare worktree one test needs the milosvasic.ru submodule files).
- Output diff vs committed: vasic.digital 493 files (en pages, portfolio and product pages, per-language homes); milosvasic.ru 440 files including the 2 source files. Only translated strings differ.
- Version footer, milosvasic.ru (site rebuilt with Jekyll via `site-build -workload jekyll -build-year 2026`): `_tools/career/check_version_footer.py` PASS, 690 pages carry v2.0.0.
- Version footer, vasic.digital: `scripts/check-site-version-footer.py --version 1.9.0` RESULT PASS, 525 pages, 15 languages.
- Playwright chromium on the scratch build: `all-languages-link-integrity`, `ui-l10n-chrome`, `i18n-completeness`, both `*-version-footer` specs and `aria-footer-l10n-runtime`: 49 passed, 1 failed. The failure is `aria-footer-l10n-runtime` pinning the OLD RU footer.text ('Belgrade · Dubna...'); with the expectation updated it passes 2/2 (patch in `submodule-patches/`, not applied here because the umbrella would go red until the submodule patch lands). The link-integrity spec alone: 2 passed.
- Footer render, 15 languages x 2 sites x 3 widths (375/768/1280): 90 renders in `screenshots/`. dir=rtl for ar and fa, the version label is present in every render, and no footer element overflows the viewport. One page-level horizontal scroll: vasic.digital /de/ at 375px, caused by the decorative `.vd-hero__aurora` span (right edge 458px); it is identical on the baseline build, outside the footer, and not changed here.
