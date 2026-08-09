#!/usr/bin/env bash
# One incremental-deploy cycle: regenerate EN + every COMPLETE language into the
# live site dirs and push both sites ONLY if something changed. Safe to run
# repeatedly (idempotent) while the translation batch is still writing
# _content_<lang>. A language counts as COMPLETE when every source doc has a
# PASS review verdict. Additive: never removes EN; never pushes with no change.
set -uo pipefail
ROOT="/Volumes/T7/Projects/vasic"
cd "$ROOT"
GEN="$ROOT/_tools/gen"
PDF="$ROOT/_tools/pdf/build-pdfs.sh"
LANGS="ru sr de es fr be zh kk hi ja ko ar tr fa"

# DRY_RUN=1 (or --dry-run/-n): do everything EXCEPT git commit/push. Pages are
# regenerated and per-language PDFs are (re)built into the live dirs so they can
# be inspected, but nothing is committed or pushed. Safe for verification while
# the translation batch is still writing _content_<lang>.
DRY_RUN="${DRY_RUN:-0}"
for a in "$@"; do case "$a" in --dry-run|-n) DRY_RUN=1 ;; esac; done

NDOCS=$(find _content/products _content/sites _content/docs -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
COMPLETE=()
for l in $LANGS; do
  pass=$(grep -rl '"verdict": "PASS"' "_tests/evidence/translate-new/$l" 2>/dev/null | wc -l | tr -d ' ')
  [ "${pass:-0}" -ge "$NDOCS" ] && [ "$NDOCS" -gt 0 ] && COMPLETE+=("$l")
done
echo "[deploy-langs] NDOCS=$NDOCS complete=[${COMPLETE[*]:-none}]"

# build once — pin the deterministic footer © year (§11.4.65) via ldflags:
# caller's SOURCE_DATE_EPOCH → last git commit year → current year.
if [ -n "${SOURCE_DATE_EPOCH:-}" ]; then
  BUILD_YEAR="$(date -u -r "$SOURCE_DATE_EPOCH" +%Y 2>/dev/null || date -u -d "@$SOURCE_DATE_EPOCH" +%Y 2>/dev/null || date -u +%Y)"
else
  BUILD_YEAR="$(git -C "$ROOT" log -1 --format=%cd --date=format:%Y 2>/dev/null || date -u +%Y)"
fi
( cd "$GEN" && go build -ldflags "-X main.buildYear=$BUILD_YEAR" -o "$GEN/gen" . ) || { echo "gen build failed"; exit 1; }
# sync assets + regenerate EN (updates hreflang/sitemap to include complete langs)
bash "$GEN/build.sh" --lang en --no-jekyll >/dev/null 2>&1 || echo "en gen warn"
# regenerate each COMPLETE language into the live dirs (both sites)
for l in "${COMPLETE[@]:-}"; do
  [ -z "$l" ] && continue
  "$GEN/gen" -site vasic.digital -lang "$l" -root "$ROOT" >/dev/null 2>&1 || echo "gen $l vasic warn"
  "$GEN/gen" -site milosvasic.ru -lang "$l" -root "$ROOT" >/dev/null 2>&1 || echo "gen $l milos warn"
done
# build downloadable PDFs: EN masters + each COMPLETE language, themed with the
# correct per-language lang/dir. build-pdfs.sh pins SOURCE_DATE_EPOCH from the
# source-doc mtime, so re-runs with unchanged content are byte-identical (git
# no-op) — keeping this whole cycle idempotent. Missing pandoc/weasyprint just
# warns and skips (never a faked artifact).
if [ -x "$PDF" ] && command -v weasyprint >/dev/null 2>&1 && command -v pandoc >/dev/null 2>&1; then
  bash "$PDF" en >/dev/null 2>&1 || echo "[deploy-langs] pdf en warn"
  for l in "${COMPLETE[@]:-}"; do
    [ -z "$l" ] && continue
    bash "$PDF" "$l" >/dev/null 2>&1 || echo "[deploy-langs] pdf $l warn"
    echo "[deploy-langs] pdf built: $l"
  done
else
  echo "[deploy-langs] pdf tooling missing (weasyprint/pandoc) — skipping PDF build"
fi

# rebuild jekyll _site for milosvasic (picks up freshly built PDFs)
printf 'build_year: %s\n' "$BUILD_YEAR" > milosvasic.ru/_config.deploy.yml
( cd milosvasic.ru && jekyll build --quiet --config _config.yml,_config.deploy.yml ) >/dev/null 2>&1 || echo "jekyll warn"
rm -f milosvasic.ru/_config.deploy.yml

if [ "$DRY_RUN" = "1" ]; then
  echo "[deploy-langs] DRY-RUN: pages regenerated + PDFs built; SKIPPING commit/push."
  for s in vasic.digital milosvasic.ru; do
    git -C "$s" add -A 2>/dev/null
    git -C "$s" reset -q -- index.legacy.html 2>/dev/null
    if git -C "$s" diff --cached --quiet 2>/dev/null; then
      echo "[deploy-langs] $s: no change (would not push)"
    else
      echo "[deploy-langs] $s: WOULD commit+push the following:"
      git -C "$s" diff --cached --name-status 2>/dev/null | sed "s/^/[deploy-langs]   $s: /"
    fi
    git -C "$s" reset -q 2>/dev/null   # unstage — in dry mode we never commit
  done
  echo "[deploy-langs] DRY-RUN cycle done: ${COMPLETE[*]:-none}"
  exit 0
fi

# commit + push each site only if changed
for s in vasic.digital milosvasic.ru; do
  git -C "$s" add -A 2>/dev/null
  git -C "$s" reset -q -- index.legacy.html 2>/dev/null
  if git -C "$s" diff --cached --quiet 2>/dev/null; then
    echo "[deploy-langs] $s: no change"
  else
    git -C "$s" commit -q \
      -m "i18n: localized pages + PDFs — languages [${COMPLETE[*]:-}]" \
      -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>" 2>/dev/null
    for r in $(git -C "$s" remote 2>/dev/null | grep -vxE 'upstream'); do
      git -C "$s" push "$r" main 2>&1 | tail -1 | sed "s/^/[deploy-langs] $s push $r: /"
    done
  fi
done

# Post-deploy LIVE validation smoke (§11.4.185 / §11.4.236 readiness): AFTER the real
# push — so it NEVER blocks the commit/push mechanism (§11.4.234) — and after GitHub
# Pages has had time to rebuild, run the exhaustive all-language link/sitemap validator
# against the LIVE sites. A broken-link FAIL surfaces loudly (non-zero exit). Skip with
# SKIP_LIVE_VALIDATE=1; naturally N/A in dry-run (the DRY_RUN branch already exited).
# The validator retries transient GitHub-Pages drops itself; LIVE_VALIDATE_GRACE (default
# 120s) covers Pages rebuild latency before the crawl starts. Live domains are read from
# the deployed CNAMEs (decoupled — no hardcoded host), falling back to the known domains.
LIVE_FAIL=0
if [ "${SKIP_LIVE_VALIDATE:-0}" = "1" ]; then
  echo "[deploy-langs] live validation SKIPPED (SKIP_LIVE_VALIDATE=1)"
else
  VD_DOMAIN="$(tr -d '[:space:]' < "$ROOT/vasic.digital/CNAME" 2>/dev/null)"; VD_DOMAIN="${VD_DOMAIN:-vasic.digital}"
  MV_DOMAIN="$(tr -d '[:space:]' < "$ROOT/milosvasic.ru/_site/CNAME" 2>/dev/null || tr -d '[:space:]' < "$ROOT/milosvasic.ru/CNAME" 2>/dev/null)"; MV_DOMAIN="${MV_DOMAIN:-milosvasic.ru}"
  GRACE="${LIVE_VALIDATE_GRACE:-120}"
  echo "[deploy-langs] waiting ${GRACE}s for GitHub Pages to rebuild before live validation..."
  sleep "$GRACE"
  echo "[deploy-langs] running exhaustive LIVE validator (all languages, both sites: $VD_DOMAIN + $MV_DOMAIN)..."
  if ( cd "$ROOT/_tests" && VD_BASE="https://$VD_DOMAIN" MV_BASE="https://$MV_DOMAIN" \
        npx playwright test --config=playwright.live.config.js all-languages-link-integrity.spec.js --reporter=line ); then
    echo "[deploy-langs] LIVE validation: PASS (0 broken links, all languages, both sites)"
  else
    echo "[deploy-langs] LIVE validation: FAIL — broken links on live (see output above)"
    LIVE_FAIL=1
  fi
fi

echo "[deploy-langs] cycle done: ${COMPLETE[*]:-none}"
[ "$LIVE_FAIL" = "1" ] && exit 1 || exit 0
