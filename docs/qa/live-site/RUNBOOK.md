# Live-site QA runbook (milosvasic.ru, vasic.digital)

All commands run from the umbrella root unless stated. Nothing here commits or
pushes by itself; the push step is an explicit operator action.
Exit convention everywhere: 0 clean, 1 real finding, 2 could not determine (never a pass).

## 0. Known limits of pointing the specs at a local server (audited)

The four specs in `_tests/tests/` are driven by `_tests/playwright.live.config.js`.
The first three read `VASIC_BASE` / `MILOS_BASE`; `all-languages-link-integrity`
reads `VD_BASE` / `MV_BASE`. All four must be set together.

Hardcoded absolute origins that make a local run test the wrong thing:

- `_tests/tests/restyle-seo-regression.spec.js:102` (`const expected = origin(c.base) + c.path`, asserted at 103-104):
  the canonical-link test (`2. Self-referential canonical`, cases defined at :84-92)
  expects the canonical to equal the BASE origin. Locally the base is
  `http://127.0.0.1:PORT` while the site correctly emits `https://milosvasic.ru/...`
  / `https://vasic.digital/...`, so these tests FAIL locally although the site is
  right. Treat those canonical tests as "expected local failure"; they are only
  meaningful in the live run (step 9). Do not "fix" the site to satisfy them.
- `_tests/tests/all-languages-link-integrity.spec.js:42,48` hardcode `canonical:
  'https://vasic.digital'` / `'https://milosvasic.ru'`, but this is deliberate:
  `canonicalToBase()` (:63-66) rewrites canonical URLs onto `*_BASE`, and the
  sitemap-derived checks (:113,:116 `startsWith(site.canonical + '/expertise/')`) rely on the
  sitemap carrying the canonical origin. This is correct locally. Note `isLive`
  (:73) is `!/localhost|127\.0\.0\.1/`, so use `127.0.0.1` or `localhost` in the
  base (not `0.0.0.0` or a LAN name) to get the local pool/timeout profile.
- `restyle-seo-regression.spec.js:31-32`, `v170-fixes.spec.js:32-33`,
  `v171-hardcoding.spec.js:29-30`: defaults only (`|| 'https://...'`); an exported
  env var wins, so these are safe. `playwright.live.config.js` also fills the
  four vars with deployed origins only when unset, so exported local values win.
- Everything else in those three specs builds URLs from `VASIC` / `MILOS`
  (e.g. `v170-fixes.spec.js:310-311,350-351`); no other absolute-origin literal exists
  (grep for `https?://` finds only the lines above).
- A local python `http.server` is not GitHub Pages: no custom 404.html, no
  redirects, directory index only. A failure about 404 body or redirects that
  appears only locally must be re-checked live before it is called a defect.

## 1. Build

```bash
# milosvasic.ru (Jekyll, built in a container; host has no bundle/jekyll)
_tools/containers/bin/site-build -workload jekyll -build-year 2026   # rc 0 -> milosvasic.ru/_site
# vasic.digital is committed static HTML: no build. Regenerate localized pages only if sources changed:
#   bash _tools/deploy-langs.sh --dry-run
```
If `_tools/containers/bin/site-build` is missing:
`( cd _tools/containers && go build -o bin/site-build ./cmd/site-build )`.

## 2. Local serve (two terminals or background; pick free ports)

```bash
MV_PORT=9082; VD_PORT=9401   # change if taken: ss -ltn | grep -E ":($MV_PORT|$VD_PORT) "
python3 -m http.server $MV_PORT --bind 127.0.0.1 --directory milosvasic.ru/_site &
python3 -m http.server $VD_PORT --bind 127.0.0.1 --directory vasic.digital &
curl -sI http://127.0.0.1:$MV_PORT/ | head -1; curl -sI http://127.0.0.1:$VD_PORT/ | head -1
```
Stop with `kill %1 %2` (only the jobs you started).

## 3. verify-live-site.py against local

```bash
mkdir -p docs/qa/live-site/local
python3 scripts/verify-live-site.py --base http://127.0.0.1:$MV_PORT \
  --sitemap-from-dir milosvasic.ru/_site \
  --evidence-dir docs/qa/live-site/local --report-json docs/qa/live-site/local/mv-local.json
echo rc=$?
```
The sitemap holds canonical https URLs; the tool maps them onto `--base`.
Compare to the baseline too if desired (`--baseline docs/qa/live-site/baseline-live-2026-11-23.json`);
page-level regressions (page 200 -> gone) are real even locally.

## 4. Playwright specs against local

```bash
cd _tests
VASIC_BASE=http://127.0.0.1:$VD_PORT  VD_BASE=http://127.0.0.1:$VD_PORT \
MILOS_BASE=http://127.0.0.1:$MV_PORT  MV_BASE=http://127.0.0.1:$MV_PORT \
  npx playwright test -c playwright.live.config.js
cd -
```
Expected local-only failures: the restyle spec's "2. Self-referential canonical"
cases (section 0). Anything else failing is a real finding.
(`retries: 1` is set in the config; do not raise it to hide flakes.)

## 5. Push (operator action; no force, ever)

Push milosvasic.ru first from its own checkout (its `pages.yml` is the sole publish
path; never disable or rename it), then the umbrella gitlink bump:

```bash
git -C milosvasic.ru status --short && git -C milosvasic.ru push origin main
git -C vasic.digital push origin main        # legacy Pages build, no workflow file
```

## 6. Wait for the Pages workflow

```bash
gh run list -R milos85vasic/milosvasic.ru --workflow pages.yml --limit 3
gh run watch -R milos85vasic/milosvasic.ru "$(gh run list -R milos85vasic/milosvasic.ru --workflow pages.yml --limit 1 --json databaseId --jq '.[0].databaseId')" --exit-status
# vasic.digital (provider-generated "pages build and deployment"):
gh run list -R vasic-digital/vasic-digital.github.io --limit 3
```
Do not start step 7 until the run is `completed` / `success` for the pushed SHA
(`gh run list ... --json headSha,conclusion`). Pages CDN can lag a minute after success.

## 7. verify-live-site.py against live, with baseline (read-only GETs, <= 6 concurrent)

```bash
python3 scripts/verify-live-site.py --base https://milosvasic.ru \
  --baseline docs/qa/live-site/baseline-live-2026-11-23.json \
  --evidence-dir docs/qa/live-site --report-json docs/qa/live-site/after-push.json
echo rc=$?     # 0 ok | 1 failure or REGRESSION | 2 undetermined (not a pass)
```

## 8. Playwright live

```bash
cd _tests && npx playwright test -c playwright.live.config.js   # no env: defaults to deployed origins
```
Here the canonical tests are meaningful and must pass.

## 9. Rollback (forward only)

If step 7 reports a REGRESSION or step 8 fails on something the push caused:

```bash
git -C milosvasic.ru log --oneline -5
git -C milosvasic.ru revert --no-edit <bad_sha>      # a new forward commit
git -C milosvasic.ru push origin main                # fast-forward, triggers pages.yml
```
Repeat steps 6-8. For a merge commit use `git revert -m 1 <sha>`. Then bump the
umbrella gitlink with the usual commit wrapper. Never `--force`,
`--force-with-lease`, reset-and-push or history rewrite (section 11.4.113); never
disable `pages.yml`. If a revert is not enough, fix forward in a new commit.

## vasic.digital must be unaffected (live address: https://digital.vasic.dev)

The static site (submodule `vasic.digital/`, GitHub Pages legacy, `CNAME` = `digital.vasic.dev`)
must stay byte-identical while milosvasic.ru ships. Reference state measured 2026-11-23:
`vasic-digital-tree-fingerprint.txt` (HEAD `aa29b64be5f5...`, clean porcelain, fingerprint `6d157cc9...fbe3f`).
The old host `vasic.digital` answers DNS (31.177.76.32, 31.177.80.32) but nothing on HTTPS 443 (curl code 000);
`digital.vasic.dev` CNAMEs to GitHub Pages and returns HTTP 200.

**Deploy restriction.** `_tools/deploy-langs.sh` CANNOT be restricted to milosvasic.ru: its only flags
are `--dry-run/-n`, `--help` and `--prove-*`; the site list is hard-coded (`for s in vasic.digital milosvasic.ru`
at the regenerate, commit and push loops) and no env var (DEPLOY_ALLOW_UNRELATED, DEPLOY_INCLUDE_ADMIN,
DEPLOY_SCOPE, DEPLOY_PUSH_REMOTES...) selects a site. A real run regenerates and may commit/push
vasic.digital. So: do NOT run it for real. `--dry-run` is safe to preview (it stages/commits/pushes nothing, but it
does regenerate files in the working trees, so re-check the fingerprint afterwards). The milosvasic.ru push is done
by hand: `git -C milosvasic.ru add <explicit paths>; git -C milosvasic.ru commit; git -C milosvasic.ru push`
(its `pages.yml` publishes), then bump only the milosvasic.ru gitlink in the umbrella.

**Before push** (baseline for comparison):
```bash
git ls-files -s vasic.digital; git -C vasic.digital status --porcelain   # gitlink aa29b64b..., empty
( cd vasic.digital && git ls-files | sort | xargs -d '\n' sha256sum | sha256sum )  # 6d157cc9...
gh run list -R vasic-digital/vasic-digital.github.io --limit 5            # note newest run id
```
**After push** (all must hold):
1. `git ls-files -s vasic.digital` unchanged (same gitlink SHA as before).
2. `git -C vasic.digital rev-parse HEAD` unchanged, `status --porcelain` empty, tree fingerprint identical.
3. `python3 scripts/verify-live-site.py --base https://digital.vasic.dev --crawl --legacy-host vasic.digital --baseline docs/qa/live-site/baseline-live-digital-vasic-dev-2026-11-23.json` -> rc 0
   (baseline compare = zero regressions; pre-existing old-host references are reported, not failures).
4. `gh run list -R vasic-digital/vasic-digital.github.io --limit 5` shows no run newer than the one noted before the push.

**Pre-existing finding (not fixed, recorded 2026-11-23):** the site still declares the old domain `vasic.digital`
in canonical, og:url/og:image/twitter:image, hreflang (16 per page), icons, `sitemap.xml` (525 lines) and
`robots.txt` (1 line); 532 tracked files contain the string (e.g. `vasic.digital/index.html:15,16,17,23,24,29,30-45`).
The crawl reports 9994 such references over 527 pages, none counted as failure.
