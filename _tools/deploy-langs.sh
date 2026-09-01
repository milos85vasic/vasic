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
#   1  deploy completed BUT the live suite ran, REACHED production, and asserted
#      a real defect there (broken link and/or shipped-state regression)
#      -> a real content/site failure; act on the sites.
#   2  deploy completed BUT the live suite reached NO verdict — it could not run
#      (missing node_modules / browser binary / spec / npx), or the transport to
#      production was down so nothing was observed. NOT a broken-site report.
#      Act on the toolchain or the network path, then re-validate.
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

# --prove-buildyear is answered HERE, before the pre-flight, the build, and any
# staging/commit/push. This script publishes to two LIVE production sites; a
# self-test that had to walk any part of that path would be unrunnable.
PROVE_BUILDYEAR=0
for a in "$@"; do case "$a" in --prove-buildyear) PROVE_BUILDYEAR=1 ;; esac; done

# ── portable epoch → UTC year (Environment Adaptability) ─────────────────────
# GNU coreutils spells this `-d @EPOCH`; BSD/macOS spells it `-r EPOCH`. THE TWO
# CANNOT BE `||`-CHAINED, and the chain that stood here until 2026-09-01 --
# BSD-first, GNU second, current-year last -- was a latent defect of exactly the
# class documented at length in _tools/pdf/build-pdfs.sh:portable_mtime.
#
#   * On GNU, `-r` is --reference=FILE, so the epoch is resolved as a PATHNAME.
#     With no such file it fails cleanly and the fallback wins -- measured
#     2026-09-01, SOURCE_DATE_EPOCH=1700000000 yielded BUILD_YEAR=2023, 4 bytes,
#     which is why this never misbehaved here. But a FILE NAMED WITH THE EPOCH
#     in the current directory makes it SUCCEED with that file's mtime year.
#     Measured, same date, with a file `1700000000` whose mtime is 1999-01-01:
#     BUILD_YEAR became 1999 instead of 2023 -- rc 0, no diagnostic, and because
#     the command succeeded the `||` never fired, so the correct spelling
#     sitting on the same line was never consulted.
#   * Symmetrically, BSD/macOS `-d` sets the kernel daylight-saving flag rather
#     than parsing a date, so on that side the GNU spelling can silently print
#     TODAY's year for any epoch.
#
# Both failures return a WELL-FORMED four-digit year, so validating the SHAPE of
# the output -- the `^[0-9]+$` test that suffices for an mtime -- is not enough
# here: it accepts both wrong answers. Each spelling is therefore run SEPARATELY
# against a KNOWN-ANSWER ORACLE (1000000000 == 2001-09-09T01:46:40Z, far from
# any year boundary in any timezone) and is used only if it reproduces it.
# Validate the OUTPUT, never the exit status -- one idiom for this problem
# across the tree, not five.
#
# Returns 1 WITH NO OUTPUT when neither spelling can be trusted on this host, so
# a caller may safely write `portable_epoch_year "$E" || date -u +%Y` without
# risking the concatenation this function exists to prevent.
portable_epoch_year() {
  local _e="$1" _y=""
  if [ "$(date -u -d '@1000000000' +%Y 2>/dev/null)" = "2001" ]; then
    _y="$(date -u -d "@$_e" +%Y 2>/dev/null)"
  elif [ "$(date -u -r 1000000000 +%Y 2>/dev/null)" = "2001" ]; then
    _y="$(date -u -r "$_e" +%Y 2>/dev/null)"
  fi
  case "$_y" in ''|*[!0-9]*) return 1 ;; esac
  printf '%s\n' "$_y"
}

# ── §1.1 paired-mutation gate for the epoch→year probe ───────────────────────
#   bash _tools/deploy-langs.sh --prove-buildyear
# Three-valued, like every check in this tree: 0 the probe works, 1 the probe is
# broken, 2 COULD NOT DETERMINE (never a pass). It returns before ANY build,
# generation, commit or push happens, writes only inside a `mktemp -d`, and
# touches no tracked artifact -- safe to run at any time.
#
# B1 is the assertion that DISCRIMINATES fixed from broken. It reconstructs the
# adversarial case that makes the historical chain flip: a current directory
# containing a file NAMED with the epoch, whose mtime is a different year. Under
# the old BSD-first chain that returns the FILE's year at rc 0; under the
# oracle-checked form it returns the EPOCH's year.
#
# B1's fixture is not assumed to bite -- it is PROVEN to. The historical
# expression is written out longhand here (never a call to the subject) and must
# actually get the fixture wrong; if it does not, B1 is reported as NOT EXERCISED
# and the gate ends at rc 2 rather than banking an assertion it never made. A
# fixture established with the function under test can only ever report
# UNDETERMINED when that function breaks, which launders a real defect into
# "could not verify".
#
# B4 puts a stub `date` FIRST on PATH reproducing the BSD/macOS contract (`-d`
# consumes a daylight-saving integer and then prints TODAY, `-r` reads an epoch).
# That is a SIMULATION, not a measurement on a BSD host: none is reachable from
# this development host and none can be synthesised (measured 2026-09-01 -- no
# BSD userland, no BSD container image). It is still load-bearing: it is the
# assertion that fails if anyone later "simplifies" the known-answer oracle down
# to a bare four-digit shape test, because on that stub the GNU spelling returns
# a well-formed but WRONG year.
if [ "${PROVE_BUILDYEAR:-0}" = "1" ]; then
  echo "BUILD-YEAR-PORTABILITY §1.1 PAIRED MUTATION PROOF — portable_epoch_year"
  echo "----------------------------------------------------------------------"
  BY_PASS=0; BY_FAIL=0; B1_RAN=0
  by_ok()   { BY_PASS=$((BY_PASS+1)); printf '✅ %-24s %s\n' "$1" "$2"; }
  by_bad()  { BY_FAIL=$((BY_FAIL+1)); printf '❌ %-24s %s\n' "$1" "$2"; }
  by_note() { printf 'ℹ %-24s %s\n' "$1" "$2"; }

  BYW="$(mktemp -d "${TMPDIR:-/tmp}/buildyear-proof.XXXXXX")" || {
    echo "UNDETERMINED: cannot create a sandbox, so nothing was proved." >&2; exit 2; }
  trap 'rm -rf "$BYW"' EXIT INT TERM

  # B2 — the ordinary path: three known epochs, none of them near a year
  # boundary, checked against their UTC years.
  for pair in 1000000000:2001 946684800:2000 1700000000:2023; do
    e="${pair%%:*}"; want="${pair##*:}"
    if got="$(portable_epoch_year "$e")"; then :; else got=""; fi
    if [ "$got" = "$want" ]; then
      by_ok "B2 epoch-$e" "resolved to $want"
    else
      by_bad "B2 epoch-$e" "expected $want, got '${got}' (${#got} bytes)"
    fi
  done

  # B1 — the adversarial current directory.
  : >"$BYW/1000000000"
  touch -d '@915148800' "$BYW/1000000000" 2>/dev/null \
    || touch -t 199901010000 "$BYW/1000000000" 2>/dev/null || true
  hist="$(cd "$BYW" && { date -u -r 1000000000 +%Y 2>/dev/null \
                         || date -u -d '@1000000000' +%Y 2>/dev/null \
                         || date -u +%Y; })"
  if [ "$hist" = "2001" ]; then
    by_note "B1 adversarial-cwd" "NOT EXERCISED — the historical expression is not wrong on this"
    by_note "" "host's fixture (it returned $hist), so this sandbox cannot discriminate."
  else
    B1_RAN=1
    if got="$(cd "$BYW" && portable_epoch_year 1000000000)"; then :; else got=""; fi
    if [ "$got" = "2001" ]; then
      by_ok "B1 adversarial-cwd" "a file named 1000000000 (mtime year $hist) did NOT hijack the answer"
    else
      by_bad "B1 adversarial-cwd" "expected 2001, got '${got}' — the epoch was resolved as a PATHNAME"
    fi
  fi

  # B3 — a non-epoch argument must fail SILENTLY, so `|| date -u +%Y` at the
  # call site cannot concatenate onto a partial answer.
  if got="$(portable_epoch_year 'not-an-epoch')"; then
    by_bad "B3 garbage-input" "returned 0 with '${got}' instead of failing"
  elif [ -n "$got" ]; then
    by_bad "B3 garbage-input" "failed but still wrote ${#got} bytes to stdout: '${got}'"
  else
    by_ok "B3 garbage-input" "failed with EMPTY stdout, so a caller fallback cannot concatenate"
  fi

  # B4 — BSD/macOS contract, SIMULATED.
  mkdir -p "$BYW/bin-bsd"
  { printf '#!/usr/bin/env bash\nREAL_DATE=%q\n' "$(command -v date)"
    cat <<'BY_BSD_STUB'
# Simulates the BSD/macOS date contract: -d takes a daylight-saving integer
# (historically atoi-parsed, so a junk argument is silently accepted and the
# command then prints the CURRENT time), and -r takes SECONDS SINCE THE EPOCH.
ref=""; fmt="+%Y"
while [ $# -gt 0 ]; do
  case "$1" in
    -u) shift ;;
    -d) shift; [ $# -gt 0 ] && shift; ;;
    -r) ref="${2:-}"; shift; [ $# -gt 0 ] && shift; ;;
    +*) fmt="$1"; shift ;;
    *)  shift ;;
  esac
done
if [ -n "$ref" ]; then "$REAL_DATE" -u -d "@$ref" "$fmt"; else "$REAL_DATE" -u "$fmt"; fi
BY_BSD_STUB
  } >"$BYW/bin-bsd/date"
  chmod 755 "$BYW/bin-bsd/date"
  if got="$(PATH="$BYW/bin-bsd:$PATH"; hash -r; portable_epoch_year 1000000000)"; then :; else got=""; fi
  if [ "$got" = "2001" ]; then
    by_ok "B4 bsd-contract (SIM)" "the oracle rejected the GNU spelling and used -r (simulated BSD date)"
  else
    by_bad "B4 bsd-contract (SIM)" "expected 2001, got '${got}' — a four-digit shape test is not an oracle"
  fi

  echo "----------------------------------------------------------------------"
  if [ "$BY_FAIL" -gt 0 ]; then
    echo "❌ portable_epoch_year §1.1 PROOF: FAIL — ${BY_FAIL} of $((BY_PASS + BY_FAIL)) assertion(s) did not hold."
    echo "   Restore the oracle-checked form; an || chain over these two spellings resolves"
    echo "   the epoch as a PATHNAME on GNU and as a daylight-saving flag on BSD."
    exit 1
  fi
  if [ "$B1_RAN" -eq 0 ]; then
    echo "◍ portable_epoch_year §1.1 PROOF: COULD NOT DETERMINE — ${BY_PASS} assertion(s) held,"
    echo "   but the DISCRIMINATING one (B1) could not be exercised on this host. That is not"
    echo "   a pass; it is an unproven claim, and it is reported as one."
    exit 2
  fi
  echo "✅ portable_epoch_year §1.1 MUTATION PROOF: PASS — ${BY_PASS} assertions, including the"
  echo "   adversarial current directory (B1) that the historical || chain cannot survive."
  echo "   B4 is a SIMULATION of the BSD date contract, not a measurement on a BSD host."
  exit 0
fi

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
  BUILD_YEAR="$(portable_epoch_year "$SOURCE_DATE_EPOCH" || date -u +%Y)"
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
# Pages has had time to rebuild, run the WHOLE live suite against the LIVE sites:
# the exhaustive all-language link/sitemap crawl PLUS the three permanent
# shipped-state regression suites (restyle-seo-regression, v170-fixes,
# v171-hardcoding — 86 assertions). A verified defect exits 1; a suite that reached
# no verdict at all exits 2 and says so in those words — it never claims the sites
# are broken. Skip with SKIP_LIVE_VALIDATE=1; naturally N/A in dry-run (the DRY_RUN
# branch already exited).
#
# ── WHY ALL FOUR SPECS, NOT JUST THE CRAWL ─────────────────────────────────
# The three regression suites assert against production by construction (their
# VASIC_BASE / MILOS_BASE default to the live origins). They were removed from the
# pre-push gate because they gave a LOCAL push a hidden dependency on public DNS —
# correct, but it left them claimed by playwright.live.config.js and executed by
# NOTHING: no CI (.github/workflows/ci.yml is disabled), no schedule, no cron, and
# this step filtered them out with a positional argument. 86 assertions about the
# live sites ran nowhere. Right after the deploy that could have broken them is
# exactly where they belong, so the positional filter is gone.
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

# LIVE_SPECS — every spec the live suite is expected to execute. Named here (not
# left implicit) because a MISSING spec is not a smaller run, it is a SILENT one:
# Playwright happily exits 0 having executed fewer assertions, and this script
# would then print PASS for coverage that never happened (§11.4.6). Presence is
# therefore a hard precondition, checked before anything runs.
LIVE_SPECS="all-languages-link-integrity restyle-seo-regression v170-fixes v171-hardcoding"

# live_missing_deps — echo each validator dependency that is absent. Checked
# BEFORE running anything, so these can never masquerade as a broken-link result.
live_missing_deps() {
  local t="$1" s
  [ -d "$t" ]                                             || printf '%s\n' "$t/ (test harness directory)"
  [ -d "$t/node_modules" ]                                || printf '%s\n' "$t/node_modules  — run: npm ci"
  [ -f "$t/playwright.live.config.js" ]                   || printf '%s\n' "$t/playwright.live.config.js"
  for s in $LIVE_SPECS; do
    [ -f "$t/tests/$s.spec.js" ]                          || printf '%s\n' "$t/tests/$s.spec.js"
  done
  command -v npx >/dev/null 2>&1                          || printf '%s\n' "npx (Node.js toolchain not on PATH)"
  return 0
}

# live_origins_reachable <origin>... — transport probe, independent of Playwright.
#   rc 0  every origin answered with an HTTP status code (ANY code: a 500 from
#         the origin is a fact about the SITE, which the suite must assert on —
#         only "no answer at all" is a transport verdict).
#   rc 1  at least one origin never answered; stdout names them.
#   rc 2  curl is not on PATH — the probe is INCONCLUSIVE and says nothing.
# Three attempts with a backoff, so one dropped packet is not read as an outage.
live_origins_reachable() {
  command -v curl >/dev/null 2>&1 || return 2
  local o code attempt bad=0
  for o in "$@"; do
    code=""
    for attempt in 1 2 3; do
      code="$(curl -sS -o /dev/null -w '%{http_code}' --max-time "${LIVE_PROBE_TIMEOUT:-20}" "$o/" 2>/dev/null)"
      { [ -n "$code" ] && [ "$code" != "000" ]; } && break
      [ "$attempt" -lt 3 ] && sleep "$attempt"
    done
    if [ -z "$code" ] || [ "$code" = "000" ]; then
      printf '%s — no HTTP response after 3 attempts\n' "$o"
      bad=1
    fi
  done
  [ "$bad" = "0" ]
}

# live_failure_shape <json-report> — echo network | genuine | none | unknown.
# Reads Playwright's MACHINE-READABLE report rather than guessing from prose, and
# answers one question: of the specs that ultimately failed, is EVERY failure a
# transport fault, or is at least one a real assertion about the shipped sites?
#   network  >=1 spec failed and every failure is transport-only
#   genuine  >=1 spec failed and at least one failure is an assertion
#   none     the run exited non-zero with NO failing spec recorded (crash /
#            global-setup error) — nothing was concluded about the sites
#   unknown  no usable report; the caller falls back to output signatures
# Note the third clause: all-languages-link-integrity.spec.js launders a network
# throw into `last = 0` and asserts on it, so "Expected: 200 / Received: 0" and a
# broken-list whose entries are ALL status 0 are reachability facts, not broken
# links. A list mixing 0 with any 4xx/5xx contains a real defect and is `genuine`.
live_failure_shape() {
  local json="${1:-}" out
  [ -n "$json" ] && [ -s "$json" ] || { printf 'unknown\n'; return 0; }
  command -v node >/dev/null 2>&1 || { printf 'unknown\n'; return 0; }
  out="$(node -e '
    const fs = require("fs");
    let r; try { r = JSON.parse(fs.readFileSync(process.argv[1], "utf8")); } catch (e) { process.exit(3); }
    const NET = /net::ERR_|getaddrinfo|EAI_AGAIN|ENOTFOUND|ECONNREFUSED|ECONNRESET|ETIMEDOUT|EHOSTUNREACH|ENETUNREACH|socket hang up|Client network socket disconnected|(?:page\.goto|page\.reload|apiRequestContext\.\w+):\s*Timeout/i;
    const BARE_TIMEOUT = /^Test timeout of \d+ms exceeded\.?$/;
    const strip = (s) => String(s || "").replace(/\u001b\[[0-9;]*m/g, "").trim();
    function noResponseOnly(msg) {
      const codes = [...msg.matchAll(/(?:^|[\s"+-])(\d{1,3})\s+https?:\/\//g)].map((m) => m[1]);
      if (codes.length) return codes.every((c) => c === "0");
      return /Expected:\s*200[\s\S]*?Received:\s*0\b/.test(msg);
    }
    const failing = [];
    (function walk(node) {
      for (const s of node.suites || []) walk(s);
      for (const sp of node.specs || []) if (sp.ok === false) failing.push(sp);
    })({ suites: r.suites || [] });
    if (!failing.length) { console.log("none"); process.exit(0); }
    const allNet = failing.every((sp) => {
      const msgs = [];
      for (const t of sp.tests || []) for (const res of t.results || []) {
        if (res.status === "passed" || res.status === "skipped") continue;
        for (const e of res.errors || []) msgs.push(strip(e.message || e.value));
        if (!(res.errors || []).length && res.error) msgs.push(strip(res.error.message));
      }
      if (!msgs.length) return true;
      return msgs.every((m) => NET.test(m) || BARE_TIMEOUT.test(m) || noResponseOnly(m));
    });
    console.log(allNet ? "network" : "genuine");
  ' "$json" 2>/dev/null)"
  case "$out" in
    network|genuine|none) printf '%s\n' "$out" ;;
    *)                    printf 'unknown\n' ;;
  esac
}

# classify_live_result <rc> <logfile> [json-report] — echo "<state>|<kind>|<reason>".
#   state  pass | fail | unverified      kind  ok | assertion | toolchain | network | inconclusive
# Playwright exits 1 for a MISSING BROWSER BINARY exactly as it does for a failing
# assertion, and exits 1 again when the network dropped under it — the return code
# alone separates none of them, so each is identified by its own evidence. 97 is
# our own marker for a failed cd, and 126/127+ mean the interpreter never got as
# far as running a test. The reason field carries no "|".
classify_live_result() {
  local rc="$1" log="$2" json="${3:-}" shape
  if [ "$rc" = "0" ]; then printf 'pass|ok|\n'; return 0; fi
  if [ "$rc" = "97" ]; then
    printf 'unverified|toolchain|could not enter the test harness directory (rc=97)\n'; return 0
  fi
  if [ -f "$log" ] && grep -qE "Executable doesn't exist|Please run the following command to download|npx playwright install|Cannot find module|MODULE_NOT_FOUND|No tests found|command not found" "$log"; then
    printf 'unverified|toolchain|the validator never started (rc=%s) — missing browser binary, unresolvable module, or no matching spec. See its output above.\n' "$rc"; return 0
  fi
  if [ "$rc" -ge 126 ] 2>/dev/null; then
    printf 'unverified|toolchain|the runner never executed the validator (rc=%s)\n' "$rc"; return 0
  fi
  shape="$(live_failure_shape "$json")"
  case "$shape" in
    network)
      printf 'unverified|network|the suite ran, and EVERY failure it reported is a transport fault (no HTTP response / DNS / reset), not an assertion about the sites\n'; return 0 ;;
    none)
      printf 'unverified|inconclusive|the validator exited %s with no failing test recorded — it crashed or aborted before reaching a verdict\n' "$rc"; return 0 ;;
    unknown)
      # No machine-readable report to reason from. Fall back to the discriminator
      # this tree already used when it measured the same class of incident (see
      # the header of _tests/playwright.config.js): transport signatures present,
      # zero genuine assertion failures.
      if [ -f "$log" ] \
         && grep -qE "net::ERR_|getaddrinfo|EAI_AGAIN|ENOTFOUND|ECONNREFUSED|ECONNRESET|ETIMEDOUT|socket hang up" "$log" \
         && ! grep -qE "Error: expect\(|Expected: |Received: " "$log"; then
        printf 'unverified|network|no machine-readable report; classified from output signatures — transport faults present, zero assertion failures\n'; return 0
      fi ;;
  esac
  printf 'fail|assertion|the live suite ran and asserted at least one real defect on production (broken link or shipped-state regression)\n'
}

LIVE_STATE="pass"        # pass | fail | unverified | skipped
LIVE_KIND="ok"           # ok | assertion | toolchain | network | inconclusive | skip
LIVE_REASON=""
if [ "${SKIP_LIVE_VALIDATE:-0}" = "1" ]; then
  LIVE_STATE="skipped"; LIVE_KIND="skip"
  LIVE_REASON="SKIP_LIVE_VALIDATE=1 (explicit operator opt-out — a reasoned skip, §11.4.3)"
else
  VD_DOMAIN="$(tr -d '[:space:]' < "$ROOT/vasic.digital/CNAME" 2>/dev/null)"; VD_DOMAIN="${VD_DOMAIN:-vasic.digital}"
  MV_DOMAIN="$(tr -d '[:space:]' < "$ROOT/milosvasic.ru/_site/CNAME" 2>/dev/null || tr -d '[:space:]' < "$ROOT/milosvasic.ru/CNAME" 2>/dev/null)"; MV_DOMAIN="${MV_DOMAIN:-milosvasic.ru}"
  MISSING="$(live_missing_deps "$ROOT/_tests")"
  if [ -n "$MISSING" ]; then
    # Bail out BEFORE the grace sleep and before pretending to crawl anything.
    LIVE_STATE="unverified"; LIVE_KIND="toolchain"
    LIVE_REASON="validator dependencies absent:"$'\n'"$(printf '%s\n' "$MISSING" | sed 's|^|                     |')"
  else
    GRACE="${LIVE_VALIDATE_GRACE:-120}"
    echo "[deploy-langs] waiting ${GRACE}s for GitHub Pages to rebuild before live validation..."
    sleep "$GRACE"
    # ── Reachability PRE-PROBE ────────────────────────────────────────────────
    # A runner that cannot reach the origins can only produce failures ABOUT
    # ITSELF, and the link crawler launders a network throw into `status 0` and
    # asserts on it — so an offline runner yields "Expected: 200 / Received: 0",
    # which reads exactly like a dead production site. Probe the transport with
    # curl FIRST; if it is down, say "could not verify" and do not crawl at all.
    UNREACHABLE="$(live_origins_reachable "https://$VD_DOMAIN" "https://$MV_DOMAIN")"; PROBE_RC=$?
    if [ "$PROBE_RC" = "1" ]; then
      LIVE_STATE="unverified"; LIVE_KIND="network"
      LIVE_REASON="the deployed origins did not answer from this runner (pre-flight probe):"$'\n'"$(printf '%s\n' "$UNREACHABLE" | sed 's|^|                     |')"$'\n'"                     Nothing was crawled. This does NOT distinguish an offline runner from an offline origin."
    else
      echo "[deploy-langs] running the LIVE validation suite against $VD_DOMAIN + $MV_DOMAIN:"
      echo "[deploy-langs]   exhaustive all-language link/sitemap crawl + the v1.6.1 / v1.7.0 /"
      echo "[deploy-langs]   v1.7.1 shipped-state regression suites (chromium, read-only)."
      LIVE_LOG="$(mktemp "${TMPDIR:-/tmp}/deploy-langs-live.XXXXXX")" || LIVE_LOG=""
      LIVE_JSON="$(mktemp "${TMPDIR:-/tmp}/deploy-langs-live-json.XXXXXX")" || LIVE_JSON=""
      # `line` for the operator, `json` for classify_live_result — the return code
      # alone cannot tell a broken site from a broken network, so the classifier is
      # given the structured per-failure errors instead of guessing from prose.
      if [ -n "$LIVE_JSON" ]; then LIVE_REPORTER="line,json"; else LIVE_REPORTER="line"; fi
      # NO positional spec filter: the whole live testMatch runs. The filter used to
      # be `all-languages-link-integrity.spec.js`, which meant the three permanent
      # regression suites (86 assertions) were claimed by the live config and run by
      # nothing — deferred out of the pre-push gate, never picked up here.
      ( cd "$ROOT/_tests" || exit 97
        export VD_BASE="https://$VD_DOMAIN"    MV_BASE="https://$MV_DOMAIN"     # link-integrity
        export VASIC_BASE="https://$VD_DOMAIN" MILOS_BASE="https://$MV_DOMAIN"  # restyle/v170/v171
        [ -n "$LIVE_JSON" ] && export PLAYWRIGHT_JSON_OUTPUT_NAME="$LIVE_JSON"
        npx playwright test --config=playwright.live.config.js --reporter="$LIVE_REPORTER"
      ) 2>&1 | tee ${LIVE_LOG:+"$LIVE_LOG"}
      LIVE_RC="${PIPESTATUS[0]}"
      LIVE_VERDICT="$(classify_live_result "$LIVE_RC" "$LIVE_LOG" "$LIVE_JSON")"
      LIVE_STATE="${LIVE_VERDICT%%|*}"
      LIVE_KIND="${LIVE_VERDICT#*|}"; LIVE_KIND="${LIVE_KIND%%|*}"
      LIVE_REASON="${LIVE_VERDICT##*|}"
      # ── Reachability POST-PROBE ───────────────────────────────────────────────
      # Only reached when the suite is about to accuse the SITES. If the transport
      # has dropped since the pre-probe, those accusations are unattributable —
      # downgrade to "could not verify" rather than send the operator hunting
      # broken links that were never observed (§11.4.6).
      if [ "$LIVE_STATE" = "fail" ]; then
        UNREACHABLE="$(live_origins_reachable "https://$VD_DOMAIN" "https://$MV_DOMAIN")"; PROBE_RC=$?
        if [ "$PROBE_RC" = "1" ]; then
          LIVE_STATE="unverified"; LIVE_KIND="network"
          LIVE_REASON="reachability to the deployed origins was LOST during the run (post-run probe):"$'\n'"$(printf '%s\n' "$UNREACHABLE" | sed 's|^|                     |')"$'\n'"                     The failures above are therefore unattributable — they are not a site verdict."
        fi
      fi
      [ -n "$LIVE_LOG" ]  && rm -f "$LIVE_LOG"
      [ -n "$LIVE_JSON" ] && rm -f "$LIVE_JSON"
    fi
  fi
fi

case "$LIVE_STATE" in
  pass)
    echo "[deploy-langs] LIVE validation: PASS — the suite RAN and every assertion held:"
    echo "[deploy-langs]   0 broken links across all languages on both sites, and the v1.6.1 /"
    echo "[deploy-langs]   v1.7.0 / v1.7.1 shipped-state regressions are all still clean." ;;
  fail)
    echo "[deploy-langs] LIVE validation: FAIL — the suite RAN, reached production, and found a"
    echo "[deploy-langs]   real defect there (broken link and/or shipped-state regression)."
    printf '[deploy-langs]   basis: %s\n' "$LIVE_REASON"
    echo "[deploy-langs]   Transport was confirmed up before AND after the run, so this is a"
    echo "[deploy-langs]   statement about the SITES. Remedy is the content/generator, not the"
    echo "[deploy-langs]   toolchain. See the failing assertions above." ;;
  skipped)
    echo "[deploy-langs] LIVE validation: SKIPPED — $LIVE_REASON"
    echo "[deploy-langs]   The live sites were NOT checked. This is not a PASS." ;;
  unverified)
    echo "[deploy-langs] LIVE validation: COULD NOT VERIFY — no verdict was reached."
    printf '[deploy-langs]   reason: %s\n' "$LIVE_REASON"
    echo "[deploy-langs]   This says NOTHING about the live sites. They were pushed and are"
    echo "[deploy-langs]   serving; nothing here observed them. It is NOT a broken-link report."
    case "$LIVE_KIND" in
      network)
        echo "[deploy-langs]   Remedy is the NETWORK PATH, not the sites and not the toolchain:"
        echo "[deploy-langs]     curl -sSI https://$VD_DOMAIN/ https://$MV_DOMAIN/"
        echo "[deploy-langs]   then re-run validation alone (no deploy needed):"
        echo "[deploy-langs]     (cd _tests && npx playwright test --config=playwright.live.config.js)" ;;
      inconclusive)
        echo "[deploy-langs]   The validator aborted before recording a verdict. Read its output"
        echo "[deploy-langs]   above, then re-run validation alone (no deploy needed):"
        echo "[deploy-langs]     (cd _tests && npx playwright test --config=playwright.live.config.js)" ;;
      *)
        echo "[deploy-langs]   Remedy is the toolchain, not the sites:"
        echo "[deploy-langs]     (cd _tests && npm ci && npx playwright install chromium)"
        echo "[deploy-langs]   then re-run validation alone (no deploy needed)." ;;
    esac ;;
esac

report_build_warns
echo "[deploy-langs] cycle done: ${COMPLETE[*]:-none}"
case "$LIVE_STATE" in
  fail)       exit 1 ;;   # verified broken  -> act on the sites
  unverified) exit 2 ;;   # never verified   -> act on the toolchain
  *)          exit 0 ;;   # pass, or explicit operator skip
esac
