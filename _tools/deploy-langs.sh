#!/usr/bin/env bash
# One incremental-deploy cycle: regenerate EN + every COMPLETE language into the
# live site dirs and push both sites ONLY if something changed. Safe to run
# repeatedly (idempotent) while the translation batch is still writing
# _content_<lang>. A language counts as COMPLETE when every source doc has a
# PASS review verdict. Additive: never removes EN; never pushes with no change.
#
# EXIT CONTRACT (mirrors scripts/lumen-index-doctor.sh "0 healthy · 1 corruption
# · 2 could not inspect" and the PASS/FAIL/ERROR split in
# scripts/verify-all-constitution-rules.sh — an unrunnable check is never a pass):
#   0  deploy cycle completed; live validation PASSed (or was explicitly skipped)
#   1  deploy completed BUT the live validator ran and found broken links
#      -> a real content/site failure; act on the sites.
#   2  deploy completed BUT the live validator COULD NOT RUN (missing
#      node_modules / browser binary / spec / npx). NOT a broken-site report;
#      nothing observed the sites. Act on the toolchain, then re-validate.
#   3  refused to deploy: unrelated changes present in a site submodule.
#      Nothing was built, staged, committed, pushed, or un-staged.
#   4  the publish itself failed (commit rejected, no remote, push rejected).
#      Live validation is deliberately skipped: crawling live would report on
#      content this run did not publish.
set -uo pipefail
# ROOT was hardcoded to "/Volumes/T7/Projects/vasic" - a macOS path. On any other
# checkout the `cd` below failed, and because this script sets -u and pipefail
# but NOT -e, the failure was SILENT: the script carried on in the caller's
# working directory with GEN and PDF pointing at paths that do not exist, then
# went on to commit and push both site submodules. Derive it from the script's
# own location instead, and make the cd fatal.
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || { echo "FATAL: cannot cd to repository root '$ROOT'" >&2; exit 1; }
GEN="$ROOT/_tools/gen"
PDF="$ROOT/_tools/pdf/build-pdfs.sh"
LANGS="ru sr de es fr be zh kk hi ja ko ar tr fa"

# DRY_RUN=1 (or --dry-run/-n): do everything EXCEPT git commit/push. Pages are
# regenerated and per-language PDFs are (re)built into the live dirs so they can
# be inspected, but nothing is committed or pushed. Safe for verification while
# the translation batch is still writing _content_<lang>.
DRY_RUN="${DRY_RUN:-0}"
for a in "$@"; do case "$a" in --dry-run|-n) DRY_RUN=1 ;; esac; done

# ── DEFECT A3: indiscriminate staging coupled unrelated work to a publish ────
# The commit loop used a bare `git add -A` in each site submodule, so ANY dirty
# path in that tree — whatever workstream it came from — was staged, committed
# under an "i18n: localized pages + PDFs" message, and pushed to every remote.
# A nested `Upstreamable` gitlink bump from a separate repair workstream was one
# run away from exactly that. Two mechanisms replace it:
#
#   1. deploy_pathspecs — the exhaustive list of site-relative paths this script
#      writes. Staging is scoped to precisely these (see the commit loop).
#   2. deploy_unrelated_dirty — a PRE-FLIGHT check that runs before the build and
#      before anything is staged, naming every dirty path OUTSIDE that list.
#
# Both are needed. Scoped staging alone does not fix the live case: a path
# ALREADY in the index (`M  Upstreamable`) is committed by `git commit` no matter
# how narrow the preceding `git add` was. Only refusing to run stops that.
#
# The guard ABORTS instead of un-staging. Rewriting the operator's index behind
# their back is the same class of harm as publishing it behind their back.

# deploy_pathspecs <site> — site-relative paths this deploy actually produces:
#   gen         index.html, <lang>/index.html, products/[<lang>/]*.html,
#               portfolio/[<lang>/]index.html, sitemap.xml, robots.txt
#   build.sh    assets/od/**                       (sync_assets)
#   build-pdfs  downloads/**
#   jekyll      _site/**                           (milosvasic.ru only)
# Deliberately NOT produced here, so never staged: articles/ (the generator
# excludes it explicitly — see _tools/gen/seo.go), _article_src/, pages/, _data/,
# _layouts/, Gemfile*, CNAME, the governance carriers, and every nested submodule.
# A candidate is emitted only if it exists on disk or is known to the index, so
# `git add` never aborts the whole pathspec set on one unmatched entry.
deploy_pathspecs() {
  local site="$1" l p
  local cands=(index.html sitemap.xml robots.txt products portfolio assets/od downloads)
  for l in $LANGS; do cands+=("$l"); done
  [ "$site" = "milosvasic.ru" ] && cands+=(_site)
  for p in "${cands[@]}"; do
    if [ -e "$ROOT/$site/$p" ] || [ -n "$(git -C "$ROOT/$site" ls-files -- "$p" 2>/dev/null)" ]; then
      printf '%s\n' "$p"
    fi
  done
  return 0
}

# deploy_unrelated_dirty <site> — every dirty (staged OR unstaged OR untracked)
# path in <site> that this deploy does not produce. A nested submodule gitlink is
# NEVER deploy output and is reported even if it sits under a deploy-owned prefix.
deploy_unrelated_dirty() {
  local site="$1" specs gitlinks line p spec owned
  specs="$(deploy_pathspecs "$site")"
  gitlinks="$(git -C "$ROOT/$site" ls-files --stage 2>/dev/null | awk -F'\t' '$1 ~ /^160000/ { print $2 }')"
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    p="${line:3}"
    case "$p" in *' -> '*) p="${p##* -> }" ;; esac   # renames: the destination lands in the commit
    p="${p%\"}"; p="${p#\"}"
    if [ -n "$gitlinks" ] && printf '%s\n' "$gitlinks" | grep -qxF -- "$p"; then
      printf '%s\n' "$p (nested submodule gitlink — never a deploy artifact)"
      continue
    fi
    owned=0
    while IFS= read -r spec; do
      [ -n "$spec" ] || continue
      case "$p" in "$spec"|"$spec"/*) owned=1; break ;; esac
    done <<EOF
$specs
EOF
    [ "$owned" = "1" ] || printf '%s\n' "$p"
  done <<EOF
$(git -C "$ROOT/$site" status --porcelain=v1 --untracked-files=all 2>/dev/null)
EOF
  return 0
}

PREFLIGHT_BLOCKED=0
for s in vasic.digital milosvasic.ru; do
  EXTRA="$(deploy_unrelated_dirty "$s")"
  [ -n "$EXTRA" ] || continue
  PREFLIGHT_BLOCKED=1
  echo "[deploy-langs] $s: dirty paths that this deploy does NOT produce:" >&2
  printf '%s\n' "$EXTRA" | sed "s|^|[deploy-langs]   $s: |" >&2
done
if [ "$PREFLIGHT_BLOCKED" = "1" ]; then
  if [ "${DEPLOY_ALLOW_UNRELATED:-0}" = "1" ]; then
    echo "[deploy-langs] OVERRIDE DEPLOY_ALLOW_UNRELATED=1 — proceeding. Staging stays scoped," >&2
    echo "[deploy-langs] but any path above that is ALREADY STAGED will be committed and pushed." >&2
  elif [ "$DRY_RUN" = "1" ]; then
    echo "[deploy-langs] DRY-RUN: a real deploy WOULD ABORT here (exit 3); continuing preview only." >&2
  else
    echo "[deploy-langs] ABORTED (exit 3). Nothing was built, staged, committed, pushed or un-staged;" >&2
    echo "[deploy-langs] your index is exactly as you left it." >&2
    echo "[deploy-langs] Commit, stash or revert the paths above inside that submodule, then re-run." >&2
    echo "[deploy-langs] Deliberate override (only after reading every path): DEPLOY_ALLOW_UNRELATED=1" >&2
    exit 3
  fi
fi

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
# Build steps below stay non-fatal ON PURPOSE: this cycle is designed to be re-run
# while the translation batch is still writing _content_<lang>, so a half-written
# language must not abort the whole deploy. But a swallowed `|| echo ... warn` also
# meant the operator could not tell a clean publish from one built out of a failed
# render. Tally them and say so in the summary — no control-flow change, just the
# truth about what was published.
BUILD_WARN=0
BUILD_WARN_NAMES=""
build_warn() { BUILD_WARN=$((BUILD_WARN + 1)); BUILD_WARN_NAMES="${BUILD_WARN_NAMES}  $1"$'\n'; echo "[deploy-langs] $1 warn"; }
report_build_warns() {
  [ "$BUILD_WARN" -gt 0 ] || return 0
  echo "[deploy-langs] NOTE: ${BUILD_WARN} build step(s) failed and were tolerated; the content"
  echo "[deploy-langs] below was rendered from a run that did NOT fully succeed:"
  printf '%s' "$BUILD_WARN_NAMES" | sed 's|^|[deploy-langs] |'
}

bash "$GEN/build.sh" --lang en --no-jekyll >/dev/null 2>&1 || build_warn "en gen"
# regenerate each COMPLETE language into the live dirs (both sites)
for l in "${COMPLETE[@]:-}"; do
  [ -z "$l" ] && continue
  "$GEN/gen" -site vasic.digital -lang "$l" -root "$ROOT" >/dev/null 2>&1 || build_warn "gen $l vasic"
  "$GEN/gen" -site milosvasic.ru -lang "$l" -root "$ROOT" >/dev/null 2>&1 || build_warn "gen $l milos"
done
# build downloadable PDFs: EN masters + each COMPLETE language, themed with the
# correct per-language lang/dir. build-pdfs.sh pins SOURCE_DATE_EPOCH from the
# source-doc mtime, so re-runs with unchanged content are byte-identical (git
# no-op) — keeping this whole cycle idempotent. Missing pandoc/weasyprint just
# warns and skips (never a faked artifact).
if [ -x "$PDF" ] && command -v weasyprint >/dev/null 2>&1 && command -v pandoc >/dev/null 2>&1; then
  bash "$PDF" en >/dev/null 2>&1 || build_warn "pdf en"
  for l in "${COMPLETE[@]:-}"; do
    [ -z "$l" ] && continue
    bash "$PDF" "$l" >/dev/null 2>&1 || build_warn "pdf $l"
    echo "[deploy-langs] pdf built: $l"
  done
else
  echo "[deploy-langs] pdf tooling missing (weasyprint/pandoc) — skipping PDF build"
fi

# rebuild jekyll _site for milosvasic (picks up freshly built PDFs)
printf 'build_year: %s\n' "$BUILD_YEAR" > milosvasic.ru/_config.deploy.yml
( cd milosvasic.ru && jekyll build --quiet --config _config.yml,_config.deploy.yml ) >/dev/null 2>&1 || build_warn "jekyll _site rebuild"
rm -f milosvasic.ru/_config.deploy.yml

if [ "$DRY_RUN" = "1" ]; then
  echo "[deploy-langs] DRY-RUN: pages regenerated + PDFs built; SKIPPING commit/push."
  for s in vasic.digital milosvasic.ru; do
    # Preview WITHOUT touching the index (A3). The old dry-run staged everything
    # with `git add -A` and then ran a bare `git reset`, which silently DISCARDED
    # whatever the operator had already staged — a "dry" run that mutated state.
    mapfile -t SPECS < <(deploy_pathspecs "$s")
    if [ "${#SPECS[@]}" -eq 0 ]; then
      echo "[deploy-langs] $s: no deploy-owned paths present (would not push)"
      continue
    fi
    PREVIEW="$(git -C "$s" status --porcelain=v1 -- "${SPECS[@]}" 2>/dev/null)"
    if [ -z "$PREVIEW" ]; then
      echo "[deploy-langs] $s: no change (would not push)"
    else
      echo "[deploy-langs] $s: WOULD commit+push the following:"
      printf '%s\n' "$PREVIEW" | sed "s|^|[deploy-langs]   $s: |"
    fi
  done
  report_build_warns
  echo "[deploy-langs] DRY-RUN cycle done: ${COMPLETE[*]:-none}"
  exit 0
fi

# commit + push each site only if changed
PUBLISH_FAIL=0
for s in vasic.digital milosvasic.ru; do
  # SCOPED staging (A3) — only the paths this deploy produces, never `git add -A`.
  # `index.legacy.html` is simply absent from the pathspec list, which is why the
  # old `git reset -- index.legacy.html` is gone: it no longer needs un-staging
  # because it is never staged. (That file no longer exists in either site, so the
  # old reset was dead code whose error was swallowed by 2>/dev/null.)
  mapfile -t SPECS < <(deploy_pathspecs "$s")
  if [ "${#SPECS[@]}" -eq 0 ]; then
    echo "[deploy-langs] $s: no deploy-owned paths present — nothing to stage"
    continue
  fi
  # Do NOT swallow a staging failure: an unstageable tree that silently reports
  # "no change" is a publish that never happened while claiming success.
  if ! ADD_ERR="$(git -C "$s" add -A -- "${SPECS[@]}" 2>&1)"; then
    echo "[deploy-langs] $s: ERROR — could not stage deploy output; NOT committing." >&2
    printf '%s\n' "$ADD_ERR" | sed "s|^|[deploy-langs]   $s: |" >&2
    PUBLISH_FAIL=1
    continue
  fi
  if git -C "$s" diff --cached --quiet 2>/dev/null; then
    echo "[deploy-langs] $s: no change"
  else
    # A commit failure was silenced by `2>/dev/null` and execution fell straight
    # through to `git push`, publishing whatever HEAD already happened to be.
    if ! COMMIT_ERR="$(git -C "$s" commit -q \
          -m "i18n: localized pages + PDFs — languages [${COMPLETE[*]:-}]" \
          -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>" 2>&1)"; then
      echo "[deploy-langs] $s: ERROR — commit FAILED; NOT pushing." >&2
      printf '%s\n' "$COMMIT_ERR" | sed "s|^|[deploy-langs]   $s: |" >&2
      PUBLISH_FAIL=1
      continue
    fi
    mapfile -t REMOTES < <(git -C "$s" remote 2>/dev/null | grep -vxE 'upstream')
    if [ "${#REMOTES[@]}" -eq 0 ]; then
      # Committed with nowhere to send it: the old `for r in $(...)` simply did
      # not iterate, and the cycle still reported success.
      echo "[deploy-langs] $s: ERROR — committed but NO push remote configured; nothing published." >&2
      PUBLISH_FAIL=1
      continue
    fi
    for r in "${REMOTES[@]}"; do
      # `git push ... | tail -1` threw the push's exit status away, so a rejected
      # push read as an ordinary log line, the cycle exited 0, and the live
      # validator then PASSed against the OLD, still-deployed content.
      PUSH_OUT="$(git -C "$s" push "$r" main 2>&1)"; PUSH_RC=$?
      printf '%s\n' "$PUSH_OUT" | tail -1 | sed "s|^|[deploy-langs] $s push $r: |"
      if [ "$PUSH_RC" != "0" ]; then
        echo "[deploy-langs] $s: ERROR — push to '$r' FAILED (rc=$PUSH_RC); this site is NOT updated." >&2
        PUBLISH_FAIL=1
      fi
    done
  fi
done

# A deploy that never landed must not be validated as if it had: the live crawl
# would PASS against the previous content and the cycle would exit 0.
if [ "$PUBLISH_FAIL" = "1" ]; then
  echo "[deploy-langs] PUBLISH FAILED — see the errors above. Live validation SKIPPED:" >&2
  echo "[deploy-langs] crawling live now would report on content this run did not publish." >&2
  report_build_warns
  echo "[deploy-langs] cycle done (not published): ${COMPLETE[*]:-none}"
  exit 4
fi

# Post-deploy LIVE validation smoke (§11.4.185 / §11.4.236 readiness): AFTER the real
# push — so it NEVER blocks the commit/push mechanism (§11.4.234) — and after GitHub
# Pages has had time to rebuild, run the exhaustive all-language link/sitemap validator
# against the LIVE sites. A broken-link FAIL exits 1; a validator that could not run at
# all exits 2 and says so in those words — it never claims the sites are broken. Skip with
# SKIP_LIVE_VALIDATE=1; naturally N/A in dry-run (the DRY_RUN branch already exited).
# The validator retries transient GitHub-Pages drops itself; LIVE_VALIDATE_GRACE (default
# 120s) covers Pages rebuild latency before the crawl starts. Live domains are read from
# the deployed CNAMEs (decoupled — no hardcoded host), falling back to the known domains.
# ── DEFECT A1: "could not run the check" is NOT "the site is broken" ────────
# Any non-zero exit from the validator used to set LIVE_FAIL=1 and print
# "broken links on live". An absent `_tests/node_modules` therefore reported the
# PRODUCTION SITE as broken. Those are different facts and need different
# signals — the same distinction this project already draws in
# scripts/lumen-index-doctor.sh ("0 = healthy · 1 = corruption found · 2 = could
# not inspect") and in scripts/verify-all-constitution-rules.sh (rc=1 FAIL vs
# rc!=0,1 ERROR — "a blind instrument is never a pass", §11.4.201(7)(b)).
#
# WHY "could not verify" STILL EXITS NON-ZERO (exit 2), even though this runs
# AFTER the push and so cannot block anything: the exit code's only remaining job
# is to tell the operator what is true of a site that is ALREADY live. Exit 0
# would assert "published and verified" — a state nothing here observed, i.e. a
# bluff (§11.4.6). Exit 1 would send them hunting broken links that were never
# observed, and in CI would brand the deploy content-broken. So: non-zero,
# because an unrunnable check is never a pass; but a DISTINCT code, because the
# remedy is the toolchain, not the sites. Same ERROR-vs-FAIL split, same reason.

# live_missing_deps — echo each validator dependency that is absent. Checked
# BEFORE running anything, so these can never masquerade as a broken-link result.
live_missing_deps() {
  local t="$1"
  [ -d "$t" ]                                             || printf '%s\n' "$t/ (test harness directory)"
  [ -d "$t/node_modules" ]                                || printf '%s\n' "$t/node_modules  — run: npm ci"
  [ -f "$t/playwright.live.config.js" ]                   || printf '%s\n' "$t/playwright.live.config.js"
  [ -f "$t/tests/all-languages-link-integrity.spec.js" ]  || printf '%s\n' "$t/tests/all-languages-link-integrity.spec.js"
  command -v npx >/dev/null 2>&1                          || printf '%s\n' "npx (Node.js toolchain not on PATH)"
  return 0
}

# classify_live_result <rc> <logfile> — echo pass | fail | unverified.
# Playwright exits 1 for a MISSING BROWSER BINARY exactly as it does for a failing
# assertion, so the return code alone cannot separate them; the startup signature
# in its output is the only thing that can. 97 is our own marker for a failed cd,
# and 126/127+ mean the interpreter never got as far as running a test.
classify_live_result() {
  local rc="$1" log="$2"
  if [ "$rc" = "0" ]; then printf 'pass\n'; return 0; fi
  if [ "$rc" = "97" ]; then printf 'unverified\n'; return 0; fi
  if [ -f "$log" ] && grep -qE "Executable doesn't exist|Please run the following command to download|npx playwright install|Cannot find module|MODULE_NOT_FOUND|No tests found|command not found" "$log"; then
    printf 'unverified\n'; return 0
  fi
  if [ "$rc" -ge 126 ] 2>/dev/null; then printf 'unverified\n'; return 0; fi
  printf 'fail\n'
}

LIVE_STATE="pass"        # pass | fail | unverified | skipped
LIVE_REASON=""
if [ "${SKIP_LIVE_VALIDATE:-0}" = "1" ]; then
  LIVE_STATE="skipped"
  LIVE_REASON="SKIP_LIVE_VALIDATE=1 (explicit operator opt-out — a reasoned skip, §11.4.3)"
else
  VD_DOMAIN="$(tr -d '[:space:]' < "$ROOT/vasic.digital/CNAME" 2>/dev/null)"; VD_DOMAIN="${VD_DOMAIN:-vasic.digital}"
  MV_DOMAIN="$(tr -d '[:space:]' < "$ROOT/milosvasic.ru/_site/CNAME" 2>/dev/null || tr -d '[:space:]' < "$ROOT/milosvasic.ru/CNAME" 2>/dev/null)"; MV_DOMAIN="${MV_DOMAIN:-milosvasic.ru}"
  MISSING="$(live_missing_deps "$ROOT/_tests")"
  if [ -n "$MISSING" ]; then
    # Bail out BEFORE the grace sleep and before pretending to crawl anything.
    LIVE_STATE="unverified"
    LIVE_REASON="validator dependencies absent:"$'\n'"$(printf '%s\n' "$MISSING" | sed 's|^|                     |')"
  else
    GRACE="${LIVE_VALIDATE_GRACE:-120}"
    echo "[deploy-langs] waiting ${GRACE}s for GitHub Pages to rebuild before live validation..."
    sleep "$GRACE"
    echo "[deploy-langs] running exhaustive LIVE validator (all languages, both sites: $VD_DOMAIN + $MV_DOMAIN)..."
    LIVE_LOG="$(mktemp "${TMPDIR:-/tmp}/deploy-langs-live.XXXXXX")" || LIVE_LOG=""
    ( cd "$ROOT/_tests" || exit 97
      VD_BASE="https://$VD_DOMAIN" MV_BASE="https://$MV_DOMAIN" \
        npx playwright test --config=playwright.live.config.js all-languages-link-integrity.spec.js --reporter=line
    ) 2>&1 | tee ${LIVE_LOG:+"$LIVE_LOG"}
    LIVE_RC="${PIPESTATUS[0]}"
    LIVE_STATE="$(classify_live_result "$LIVE_RC" "$LIVE_LOG")"
    [ "$LIVE_STATE" = "unverified" ] && LIVE_REASON="the validator never reached a verdict (rc=${LIVE_RC}) — missing browser binary, unresolvable module, or no matching spec. See its output above."
    [ -n "$LIVE_LOG" ] && rm -f "$LIVE_LOG"
  fi
fi

case "$LIVE_STATE" in
  pass)
    echo "[deploy-langs] LIVE validation: PASS (0 broken links, all languages, both sites)" ;;
  fail)
    echo "[deploy-langs] LIVE validation: FAIL — broken links on live (see output above)" ;;
  skipped)
    echo "[deploy-langs] LIVE validation: SKIPPED — $LIVE_REASON"
    echo "[deploy-langs]   The live sites were NOT checked. This is not a PASS." ;;
  unverified)
    echo "[deploy-langs] LIVE validation: COULD NOT VERIFY — the check did not run."
    printf '[deploy-langs]   reason: %s\n' "$LIVE_REASON"
    echo "[deploy-langs]   This says NOTHING about the live sites. They were pushed and are"
    echo "[deploy-langs]   serving; nothing here observed them. It is NOT a broken-link report."
    echo "[deploy-langs]   Remedy is the toolchain, not the sites:"
    echo "[deploy-langs]     (cd _tests && npm ci && npx playwright install chromium)"
    echo "[deploy-langs]   then re-run validation alone (no deploy needed)." ;;
esac

report_build_warns
echo "[deploy-langs] cycle done: ${COMPLETE[*]:-none}"
case "$LIVE_STATE" in
  fail)       exit 1 ;;   # verified broken  -> act on the sites
  unverified) exit 2 ;;   # never verified   -> act on the toolchain
  *)          exit 0 ;;   # pass, or explicit operator skip
esac
