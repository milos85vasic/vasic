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
#   2  COULD NOT DETERMINE — never a pass. Two distinct occasions, both meaning
#      "no verdict was reached, act on the toolchain or the network path":
#        (a) a REQUIRED build step could not run at all because its toolchain is
#            absent on this host. Nothing was staged, committed or pushed.
#        (b) deploy completed BUT the live suite reached no verdict — it could
#            not run (missing node_modules / browser binary / spec / npx), or the
#            transport to production was down so nothing was observed.
#      Neither is a broken-site report. (a) is announced as `BUILD-GATE
#      undetermined` and (b) as a live-validation message, so the two are
#      distinguishable in the log even though they share an exit code — the code
#      carries the three-valued meaning, the log carries the occasion.
#   3  refused to deploy: unrelated changes present in a site submodule.
#      Nothing was built, staged, committed, pushed, or un-staged.
#   4  the publish itself failed (commit rejected, no remote, push rejected).
#      Live validation is deliberately skipped: crawling live would report on
#      content this run did not publish.
#   5  a REQUIRED build step RAN AND FAILED. Nothing was staged, committed or
#      pushed. Distinct from 2 on purpose: this one IS a defect in the build,
#      not a fact about the host. Precedence: 5 outranks 2, so a missing
#      toolchain can never mask a real failure. Deliberate override:
#      DEPLOY_TOLERATE_BUILD_FAILURE=1 (see "WHICH BUILD STEPS ARE TOLERATED").
set -uo pipefail

# ── STRICT ARGUMENT PARSING (before ANY side effect) ─────────────────────────
# This script commits and pushes two LIVE production sites. Until 2026-11-23 it
# ignored arguments it did not know, so `--help` or a typo such as `--dry-runn`
# started a REAL deploy. Known flags only; anything else prints usage to stderr
# and exits 2 (could-not-determine class: no verdict, nothing done). --help/-h
# prints usage on stdout and exits 0. Both happen before the cd, the build, the
# pre-flight, and every git command.
# BEGIN-ARGPARSE (extracted verbatim by --prove-args; keep it self-contained)
deploy_usage() {
  cat <<'USAGE'
Usage: _tools/deploy-langs.sh [--dry-run|-n] [--runner=NAME] [--help|-h]
       _tools/deploy-langs.sh --prove-buildyear | --prove-build-fatality |
                              --prove-deploy-scope | --prove-args

Regenerate EN + every COMPLETE language into both site submodules, commit and
push each site only if something changed, then validate the LIVE sites.
With NO argument this is a REAL deploy. Unknown arguments exit 2. ALL arguments
are validated before --help is honoured; at most one --prove-* may be given and
it may not be combined with --dry-run.

Flags:
  --dry-run, -n          do everything except git stage/commit/push. It is NOT
                         read-only: it still REWRITES the working trees (pages,
                         PDFs, _site, assets) of both site submodules
  --runner=NAME          force the container runner for the containerised
                         steps (the jekyll rebuild via site-build): any runner
                         the Containers Submodule supports (podman, docker,
                         nerdctl, cri-o, lxd, kubernetes) or `auto`. Also
                         `--runner NAME`. flag > $CONTAINERS_RUNNER > default
                         order. An unknown or not-installed runner exits 2
                         BEFORE anything is built, staged or pushed; there is
                         no fallback. See docs/RUNNER_FLAG.md
  --help, -h             print this text and exit 0 (no side effects)
  --prove-buildyear      self-test: footer year derivation (no deploy)
  --prove-build-fatality self-test: build-step fatality contract (no deploy)
  --prove-deploy-scope   self-test: deploy whitelist/branch guard, throwaway repo
  --prove-args           self-test: this argument parser, in a throwaway repo

Environment variables:
  DRY_RUN=1                       same as --dry-run
  CONTAINERS_RUNNER=<name>        same as --runner (the flag wins)
  DEPLOY_INCLUDE_ADMIN=1          also own the admin/vault surface (admin/,
                                  assets/js/vault.js, assets/js/vault-console.js,
                                  _layouts/admin_console.html, downloads/vault/).
                                  Only the literal 1 enables it; unset = held back
                                  and a dirty copy aborts pre-flight (exit 3)
  DEPLOY_ALLOW_UNRELATED=1        proceed despite unstaged/untracked paths this
                                  deploy does not produce. It NEVER lifts the hard
                                  blocks (admin/vault surface, nested gitlinks),
                                  and any staged path outside the whitelist still
                                  aborts the publish before the commit
  DEPLOY_PUSH_REMOTES='<names>'   space-separated push allow-list (default: origin)
  DEPLOY_TOLERATE_BUILD_FAILURE=1 pardon failed required build steps (exit 5)
  DEPLOY_COAUTHOR='<trailer>'     full trailer line appended to the commit
                                  message, e.g. 'Co-Authored-By: Name <a@b.c>'.
                                  Default: NO trailer
  SOURCE_DATE_EPOCH=<epoch>       pin the footer (c) year
  SKIP_LIVE_VALIDATE=1            skip post-deploy live validation
  LIVE_PROBE_TIMEOUT=<s>          origin reachability probe timeout (default 20)
  LIVE_VALIDATE_GRACE=<s>         wait before live validation (default 120)

Publish guard: each site must be on branch main (symbolic-ref refs/heads/main)
with no commits unpushed to the allow-listed remotes; the exact commit made is
pushed as <sha>:refs/heads/main.

Exit codes: 0 ok · 1 live defect · 2 undetermined/usage · 3 refused (unrelated
dirty paths) · 4 publish failed · 5 required build step failed.
USAGE
}
DEPLOY_WANT_HELP=0; DEPLOY_N_PROVE=0; DEPLOY_WANT_DRY=0
DEPLOY_RUNNER_NEXT=0
for a in "$@"; do
  if [ "$DEPLOY_RUNNER_NEXT" = "1" ]; then DEPLOY_RUNNER_NEXT=0; continue; fi
  case "$a" in
    --runner) DEPLOY_RUNNER_NEXT=1 ;;
    --runner=*) ;;
    --help|-h) DEPLOY_WANT_HELP=1 ;;
    --dry-run|-n) DEPLOY_WANT_DRY=1 ;;
    --prove-buildyear|--prove-build-fatality|--prove-deploy-scope|--prove-args) DEPLOY_N_PROVE=$((DEPLOY_N_PROVE+1)) ;;
    *) echo "deploy-langs: unknown argument: $a" >&2; deploy_usage >&2; exit 2 ;;
  esac
done
if [ "$DEPLOY_RUNNER_NEXT" = "1" ]; then
  echo "deploy-langs: --runner needs a value" >&2; deploy_usage >&2; exit 2
fi
if [ "$DEPLOY_N_PROVE" -gt 1 ]; then
  echo "deploy-langs: at most one --prove-* may be given" >&2; deploy_usage >&2; exit 2
fi
if [ "$DEPLOY_N_PROVE" -ge 1 ] && [ "$DEPLOY_WANT_DRY" = "1" ]; then
  echo "deploy-langs: --prove-* cannot be combined with --dry-run" >&2; deploy_usage >&2; exit 2
fi
if [ "$DEPLOY_WANT_HELP" = "1" ]; then deploy_usage; exit 0; fi
# END-ARGPARSE

# Forced container runner (--runner / $CONTAINERS_RUNNER), validated by the
# Containers Submodule BEFORE anything is built, staged, committed or pushed
# (refusal -> exit 2). The flag is stripped from "$@"; the choice is exported as
# CONTAINERS_RUNNER so the containerised site-build step honours it.
. "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib/vasic-runner.sh"
vasic_runner_maybe "$@" || exit 2
set -- "${VASIC_ARGS[@]+"${VASIC_ARGS[@]}"}"

# deploy_commit_args — fills COMMIT_MSG_ARGS (the `-m` pairs for git commit).
# No co-author trailer unless DEPLOY_COAUTHOR is set (full trailer line).
deploy_commit_args() {
  COMMIT_MSG_ARGS=(-m "i18n: localized pages + PDFs — languages [${COMPLETE[*]:-}]")
  if [ -n "${DEPLOY_COAUTHOR:-}" ]; then COMMIT_MSG_ARGS+=(-m "$DEPLOY_COAUTHOR"); fi
  return 0
}
# ROOT was hardcoded to "<macos-host>/Projects/vasic" - a macOS path. On any other
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

# ── WHICH BUILD STEPS ARE TOLERATED, AND WHICH ARE NOT ───────────────────────
# Until 2026-09-08 EVERY build step here was tolerated: each one ended in
# `|| build_warn "<name>"`, `build_warn` only incremented a counter, and the
# script exited 0 regardless. On a host with no `jekyll` that meant `--dry-run`
# printed "DRY-RUN cycle done" — reporting success having built nothing. This is
# a LIVE PRODUCTION deploy path for two sites; a green exit over a failed render
# is the worst possible reading. Operator decision #12 (2026-09-07,
# docs/OPERATOR-DECISIONS-2026-09-07.md): fail the deploy on a failed build,
# behind a flag for deliberate override.
#
# The blanket tolerance was NOT simply inverted, because the original rationale
# is CORRECT FOR PART OF THE SET and wrong for the rest. Each of the six call
# sites was judged separately:
#
#   TOLERATED (transient by design) — `gen <lang> vasic`, `gen <lang> milos`,
#     `pdf <lang>`. This cycle is meant to be re-run WHILE the translation batch
#     is still writing `_content_<lang>`. A language enters COMPLETE on its PASS
#     verdict count, which can reach NDOCS before the content files are fully
#     written, so a half-written language is an EXPECTED state and must not
#     abort a deploy that is otherwise publishing good content. What a tolerated
#     failure costs is bounded and stated: that language's pages are simply not
#     regenerated, so the PREVIOUS generation is republished — stale, never
#     wrong, and self-correcting on the next cycle.
#
#   FATAL — `en gen`, `pdf en`, `jekyll _site rebuild`. None of these is
#     transient. EN is the always-present source of truth and its render also
#     rewrites the hreflang and sitemap for EVERY language, so a failed EN gen
#     does not degrade one language, it publishes a wrong site. `pdf en` sits
#     INSIDE a `command -v weasyprint && command -v pandoc` guard, so reaching it
#     at all means the toolchain is present and a non-zero rc is a real failure,
#     not an absence. The jekyll rebuild is the step named in the decision.
#
# ── THREE-VALUED, BECAUSE "COULD NOT RUN" IS NOT "RAN AND FAILED" ────────────
# Every instrument in this tree is three-valued and 2 is never a pass. A build
# step whose TOOLCHAIN IS ABSENT reached no verdict about this repository's
# content — it is a fact about the host — and reporting it as a content failure
# would be the same bluff in the opposite direction. So:
#
#   build_warn  <name>   tolerated  -> counted, printed, exit code unchanged
#   build_fail  <name>   RAN and FAILED        -> exit 5
#   build_undet <name>   COULD NOT RUN at all  -> exit 2
#
# Precedence, asserted by --prove-build-fatality: FAIL (5) outranks UNDET (2)
# outranks clean, so a missing toolchain can never mask a real failure. This
# mirrors scripts/verify-content-boundary.sh's documented precedence rule.
#
# Deliberate override: DEPLOY_TOLERATE_BUILD_FAILURE=1 in the environment. It is
# an env var, not a short flag, for the same reason DEPLOY_ALLOW_UNRELATED is —
# it cannot be reached by a typo or a stray argument — and using it prints a
# loud, unmissable banner naming every step it is pardoning.
BUILD_WARN=0
BUILD_WARN_NAMES=""
BUILD_FAIL=0
BUILD_FAIL_NAMES=""
BUILD_UNDET=0
BUILD_UNDET_NAMES=""
build_warn()  { BUILD_WARN=$((BUILD_WARN + 1));   BUILD_WARN_NAMES="${BUILD_WARN_NAMES}  $1"$'\n';   echo "[deploy-langs] $1 warn"; }
build_fail()  { BUILD_FAIL=$((BUILD_FAIL + 1));   BUILD_FAIL_NAMES="${BUILD_FAIL_NAMES}  $1"$'\n';   echo "[deploy-langs] $1 FAILED" >&2; }
build_undet() { BUILD_UNDET=$((BUILD_UNDET + 1)); BUILD_UNDET_NAMES="${BUILD_UNDET_NAMES}  $1"$'\n'; echo "[deploy-langs] $1 COULD NOT RUN" >&2; }
report_build_warns() {
  [ "$BUILD_WARN" -gt 0 ] || return 0
  echo "[deploy-langs] NOTE: ${BUILD_WARN} build step(s) failed and were tolerated; the content"
  echo "[deploy-langs] below was rendered from a run that did NOT fully succeed:"
  printf '%s' "$BUILD_WARN_NAMES" | sed 's|^|[deploy-langs] |'
}

# build_gate — the decision point. Reads ONLY the three counters and the override
# env var, and either returns 0 or terminates the run. Written as a pure function
# of its inputs so --prove-build-fatality can exercise every branch without
# building, staging, committing or pushing anything.
#
# Emits its verdict on stdout as `BUILD-GATE <verdict>` so the paired proof reads
# a machine-checkable token rather than pattern-matching prose.
build_gate() {
  if [ "$BUILD_FAIL" -eq 0 ] && [ "$BUILD_UNDET" -eq 0 ]; then
    echo "[deploy-langs] BUILD-GATE clean — every REQUIRED build step ran and succeeded."
    return 0
  fi
  echo "[deploy-langs] ───────────────────────────────────────────────────────────" >&2
  if [ "$BUILD_FAIL" -gt 0 ]; then
    echo "[deploy-langs] ${BUILD_FAIL} REQUIRED build step(s) RAN AND FAILED:" >&2
    printf '%s' "$BUILD_FAIL_NAMES" | sed 's|^|[deploy-langs] |' >&2
  fi
  if [ "$BUILD_UNDET" -gt 0 ]; then
    echo "[deploy-langs] ${BUILD_UNDET} REQUIRED build step(s) COULD NOT RUN (toolchain absent):" >&2
    printf '%s' "$BUILD_UNDET_NAMES" | sed 's|^|[deploy-langs] |' >&2
  fi
  if [ "${DEPLOY_TOLERATE_BUILD_FAILURE:-0}" = "1" ]; then
    echo "[deploy-langs] ***********************************************************" >&2
    echo "[deploy-langs] *** OVERRIDE DEPLOY_TOLERATE_BUILD_FAILURE=1 IS SET.    ***" >&2
    echo "[deploy-langs] *** The failures listed above are being PARDONED and    ***" >&2
    echo "[deploy-langs] *** this deploy will CONTINUE to two LIVE PRODUCTION    ***" >&2
    echo "[deploy-langs] *** sites. Whatever those steps would have produced is  ***" >&2
    echo "[deploy-langs] *** NOT in this publish; the previous artifacts stand.  ***" >&2
    echo "[deploy-langs] ***********************************************************" >&2
    echo "[deploy-langs] BUILD-GATE overridden"
    return 0
  fi
  if [ "$BUILD_FAIL" -gt 0 ]; then
    echo "[deploy-langs] BUILD-GATE fail" >&2
    echo "[deploy-langs] ABORTED (exit 5). Nothing was staged, committed or pushed." >&2
    echo "[deploy-langs] Fix the build, then re-run. Deliberate override (only after" >&2
    echo "[deploy-langs] reading every step above): DEPLOY_TOLERATE_BUILD_FAILURE=1" >&2
    report_build_warns
    exit 5
  fi
  echo "[deploy-langs] BUILD-GATE undetermined" >&2
  echo "[deploy-langs] ABORTED (exit 2). Nothing was staged, committed or pushed." >&2
  echo "[deploy-langs] This is NOT a report about the sites — a required toolchain is" >&2
  echo "[deploy-langs] missing on THIS HOST, so those steps reached no verdict at all." >&2
  echo "[deploy-langs] Remedy is the toolchain. Deliberate override (only after reading" >&2
  echo "[deploy-langs] every step above): DEPLOY_TOLERATE_BUILD_FAILURE=1" >&2
  report_build_warns
  exit 2
}

# ── §1.1 paired-mutation gate for the build-fatality gate ────────────────────
#   bash _tools/deploy-langs.sh --prove-build-fatality
# Three-valued like every check here: 0 the gate discriminates, 1 it does not,
# 2 COULD NOT DETERMINE. It runs BEFORE the pre-flight, before `go build`, before
# any generation and before any staging/commit/push — this script publishes to
# two LIVE production sites, so a self-test that had to walk any part of that
# path would be unrunnable. It writes nothing anywhere and touches no tracked
# artifact.
#
# The subject is `build_gate`, which was deliberately written as a pure function
# of three counters and one env var so that every branch can be exercised without
# a build. Each assertion runs it in a SUBSHELL with the counters preset, so its
# `exit` terminates only that subshell and the real exit code is what is read.
#
# M1 is the DISCRIMINATING assertion — the one that fails against the historical
# code. Before 2026-09-08 every build step ended in `build_warn`, `build_warn`
# only incremented a counter, and the script exited 0. M1 asserts that a step
# which RAN AND FAILED now yields a NON-ZERO exit. It is paired with M6, which
# reconstructs the historical behaviour longhand (never by calling the subject)
# and PROVES that the old form gets this case wrong; if the mutant were to pass,
# M1 could not discriminate and the gate reports rc 2 rather than banking an
# assertion that proves nothing.
#
# M4 is the second load-bearing one: it asserts the PRECEDENCE claim printed in
# the exit contract. A run carrying BOTH a real failure and an absent toolchain
# must exit 5, not 2 — a missing toolchain may never launder a real failure into
# "could not determine".
PROVE_BUILD_FATALITY=0
for a in "$@"; do case "$a" in --prove-build-fatality) PROVE_BUILD_FATALITY=1 ;; esac; done
if [ "$PROVE_BUILD_FATALITY" = "1" ]; then
  echo "BUILD-FATALITY §1.1 PAIRED MUTATION PROOF — build_gate"
  echo "----------------------------------------------------------------------"
  BG_PASS=0; BG_FAIL=0; M1_DISCRIMINATES=0
  bg_ok()  { BG_PASS=$((BG_PASS+1)); printf '✅ %-28s %s\n' "$1" "$2"; }
  bg_bad() { BG_FAIL=$((BG_FAIL+1)); printf '❌ %-28s %s\n' "$1" "$2"; }

  # run_gate <warn> <fail> <undet> <override> -> prints "<rc> <verdict-token>"
  run_gate() {
    local out rc
    out="$(
      BUILD_WARN="$1"; BUILD_WARN_NAMES="w"$'\n'
      BUILD_FAIL="$2"; BUILD_FAIL_NAMES="f"$'\n'
      BUILD_UNDET="$3"; BUILD_UNDET_NAMES="u"$'\n'
      DEPLOY_TOLERATE_BUILD_FAILURE="$4"
      # 2>&1: the fail/undetermined verdict tokens are written to STDERR by
      # design (they are diagnostics), so a harness that discarded stderr would
      # read an empty verdict and report a false FAIL against a working gate.
      build_gate 2>&1
    )"; rc=$?
    printf '%s %s\n' "$rc" "$(printf '%s' "$out" | sed -n 's/.*BUILD-GATE \([a-z]*\).*/\1/p' | tail -1)"
  }

  # M1 — DISCRIMINATOR: a required step that RAN AND FAILED must abort, non-zero.
  got="$(run_gate 0 1 0 0)"
  case "$got" in
    "5 fail") bg_ok  "M1 ran-and-failed" "exit 5, verdict 'fail' — the deploy aborts" ;;
    *)        bg_bad "M1 ran-and-failed" "expected '5 fail', got '$got'" ;;
  esac

  # M2 — a required step that COULD NOT RUN is rc 2, never rc 0 and never rc 5.
  got="$(run_gate 0 0 1 0)"
  case "$got" in
    "2 undetermined") bg_ok  "M2 could-not-run" "exit 2, verdict 'undetermined' — never a pass" ;;
    *)                bg_bad "M2 could-not-run" "expected '2 undetermined', got '$got'" ;;
  esac

  # M3 — TOLERATED failures alone must NOT abort. This is the assertion that
  # stops a future "make everything fatal" from breaking the documented re-run
  # -while-translating workflow.
  got="$(run_gate 7 0 0 0)"
  case "$got" in
    "0 clean") bg_ok  "M3 tolerated-only" "exit 0 with 7 tolerated warn(s) — re-run workflow intact" ;;
    *)         bg_bad "M3 tolerated-only" "expected '0 clean', got '$got'" ;;
  esac

  # M4 — PRECEDENCE: FAIL outranks UNDET. Both present must read 5, not 2.
  got="$(run_gate 0 1 1 0)"
  case "$got" in
    "5 fail") bg_ok  "M4 precedence" "fail(5) outranks undetermined(2); no laundering" ;;
    *)        bg_bad "M4 precedence" "expected '5 fail', got '$got'" ;;
  esac

  # M5 — the override is honoured, and ONLY on the exact literal 1.
  got="$(run_gate 0 1 1 1)"
  case "$got" in
    "0 overridden") bg_ok  "M5 override-honoured" "DEPLOY_TOLERATE_BUILD_FAILURE=1 pardons and continues" ;;
    *)              bg_bad "M5 override-honoured" "expected '0 overridden', got '$got'" ;;
  esac
  for junk in 0 "" "yes" "true" "01"; do
    got="$(run_gate 0 1 0 "$junk")"
    case "$got" in
      "5 fail") : ;;
      *) bg_bad "M5b override-strictness" "value '$junk' should NOT override; got '$got'" ;;
    esac
  done
  bg_ok "M5b override-strictness" "only the literal '1' overrides (0, empty, yes, true, 01 do not)"

  # M6 — THE MUTANT. The historical form, written longhand, must actually get M1
  # wrong. Without this, M1 could be passing against a subject that was never
  # broken, and a §1.1 proof that cannot fail proves nothing.
  historical_gate() { : $((BUILD_FAIL)); return 0; }   # count, print, exit 0 — as it was
  ( BUILD_FAIL=1; historical_gate ); MUT_RC=$?
  if [ "$MUT_RC" -eq 0 ]; then
    M1_DISCRIMINATES=1
    bg_ok "M6 mutant-is-caught" "the historical tolerate-everything form exits 0 on a REAL failure,"
    printf '   %-28s %s\n' "" "so M1 genuinely discriminates fixed from broken."
  else
    bg_bad "M6 mutant-is-caught" "the historical form returned $MUT_RC, so M1 discriminates nothing"
  fi

  echo "----------------------------------------------------------------------"
  if [ "$BG_FAIL" -gt 0 ]; then
    echo "❌ build_gate §1.1 PROOF: FAIL — ${BG_FAIL} of $((BG_PASS + BG_FAIL)) assertion(s) did not hold."
    echo "   A failed build step must abort this deploy. Restore build_fail/build_undet."
    exit 1
  fi
  if [ "$M1_DISCRIMINATES" -eq 0 ]; then
    echo "◍ build_gate §1.1 PROOF: COULD NOT DETERMINE — ${BG_PASS} assertion(s) held, but the"
    echo "   mutant (M6) was not shown to fail, so the discriminating assertion proves nothing."
    exit 2
  fi
  echo "✅ build_gate §1.1 MUTATION PROOF: PASS — ${BG_PASS} assertions, including the"
  echo "   precedence claim (M4) and a mutant (M6) that the historical form cannot survive."
  exit 0
fi

# ── §1.1 paired-mutation proof for strict args + DEPLOY_COAUTHOR ─────────────
#   bash _tools/deploy-langs.sh --prove-args
# 0 holds · 1 does not · 2 could not determine. The script is COPIED into a
# throwaway repo (ROOT derives from the script location) and executed there, so
# no real site is touched. Mutants are sed edits of the SHIPPED parser region /
# deploy_commit_args text, each judged by the same predicate the real code must
# satisfy: M9 unknown args swallowed, M9b --help before validation, M9c combos
# unchecked, M10 hardcoded trailer, M10b DEPLOY_COAUTHOR ignored.
PROVE_ARGS=0
for a in "$@"; do case "$a" in --prove-args) PROVE_ARGS=1 ;; esac; done
if [ "$PROVE_ARGS" = "1" ]; then
  echo "ARGS §1.1 PAIRED MUTATION PROOF — strict parsing, --help, DEPLOY_COAUTHOR"
  echo "----------------------------------------------------------------------"
  command -v git >/dev/null 2>&1 || { echo "◍ COULD NOT DETERMINE — git not on PATH"; exit 2; }
  AP_SELF="$ROOT/_tools/deploy-langs.sh"
  [ -r "$AP_SELF" ] || { echo "◍ COULD NOT DETERMINE — cannot read $AP_SELF"; exit 2; }
  AP_TMP="$(mktemp -d "${TMPDIR:-/tmp}/deploy-args.XXXXXX")" || { echo "◍ COULD NOT DETERMINE — mktemp failed"; exit 2; }
  trap 'rm -rf "${AP_TMP:?}"' EXIT
  AP_PASS=0; AP_FAIL=0; AP_MUT9=0; AP_MUT9B=0; AP_MUT9C=0; AP_MUT10=0; AP_MUT10B=0
  ap_ok()  { AP_PASS=$((AP_PASS+1)); printf '✅ %-24s %s\n' "$1" "$2"; }
  ap_bad() { AP_FAIL=$((AP_FAIL+1)); printf '❌ %-24s %s\n' "$1" "$2"; }
  AP_R="$AP_TMP/repo"; mkdir -p "$AP_R/_tools" "$AP_R/vasic.digital" "$AP_R/milosvasic.ru"
  for s in vasic.digital milosvasic.ru; do
    git -C "$AP_R/$s" init -q . 2>/dev/null; echo x > "$AP_R/$s/index.html"
    git -C "$AP_R/$s" add -A; git -C "$AP_R/$s" -c user.name=t -c user.email=t@t -c commit.gpgsign=false commit -q -m base || { echo "◍ COULD NOT DETERMINE — scratch commit failed"; exit 2; }
    echo dirty > "$AP_R/$s/index.html"
  done
  snap() { ( cd "$AP_R" && { find . -path ./vasic.digital/.git -prune -o -path ./milosvasic.ru/.git -prune -o -type f -print | sort | xargs sha256sum; for s in vasic.digital milosvasic.ru; do git -C "$s" rev-parse HEAD; git -C "$s" status --porcelain; done; } ) 2>&1; }
  # run <script> args... -> sets AP_RC AP_OUT AP_ERR
  ap_run() { local sc="$1"; shift; AP_RC=0
    ( cd "$AP_R" && timeout 60 bash "$sc" "$@" >"$AP_TMP/out" 2>"$AP_TMP/err" ) || AP_RC=$?
    AP_OUT="$(cat "$AP_TMP/out")"; AP_ERR="$(cat "$AP_TMP/err")"; }
  cp "$AP_SELF" "$AP_R/_tools/deploy-langs.sh"
  AP_REAL="$AP_R/_tools/deploy-langs.sh"
  # restage nothing: snapshot before/after must be identical.
  S0="$(snap)"
  for bad in --dry-runn --bogus -x help --prove-nonsense ""; do
    ap_run "$AP_REAL" "$bad"
    S1="$(snap)"
    if [ "$AP_RC" = "2" ] && printf '%s' "$AP_ERR" | grep -q 'unknown argument' && printf '%s' "$AP_ERR" | grep -q 'Usage:' && [ -z "$AP_OUT" ] && [ "$S0" = "$S1" ]; then
      ap_ok "A1 unknown-arg" "'$bad' -> rc 2, usage on stderr, stdout empty, repos/files unchanged"
    else ap_bad "A1 unknown-arg" "'$bad': rc=$AP_RC out='${AP_OUT:0:60}' tree-changed=$([ "$S0" = "$S1" ] && echo no || echo YES)"; fi
  done
  ap_run "$AP_REAL" --dry-run --typo
  [ "$AP_RC" = "2" ] && ap_ok "A2 mixed-args" "a known flag plus an unknown one still exits 2" || ap_bad "A2 mixed-args" "rc=$AP_RC"
  for h in --help -h; do
    ap_run "$AP_REAL" "$h"; S1="$(snap)"
    if [ "$AP_RC" = "0" ] && printf '%s' "$AP_OUT" | grep -q 'DEPLOY_INCLUDE_ADMIN' && printf '%s' "$AP_OUT" | grep -q 'DEPLOY_COAUTHOR' && printf '%s' "$AP_OUT" | grep -q 'DEPLOY_ALLOW_UNRELATED' && printf '%s' "$AP_OUT" | grep -q 'DEPLOY_TOLERATE_BUILD_FAILURE' && printf '%s' "$AP_OUT" | grep -q -- '--prove-args' && [ "$S0" = "$S1" ]; then
      ap_ok "A3 help" "$h -> rc 0, documents flags + env vars, no side effects"
    else ap_bad "A3 help" "$h: rc=$AP_RC tree-changed=$([ "$S0" = "$S1" ] && echo no || echo YES)"; fi
  done
  # ── Parser harness: the REAL parser region, extracted by marker ────────────
  # The region between BEGIN-ARGPARSE and END-ARGPARSE is cut out of the script
  # under test and run alone, so it can be exercised with any argv without
  # reaching a build, a stage, a commit or a push. A mutant is a SED EDIT OF THAT
  # SAME REGION; the predicate below is then evaluated on the mutant's own
  # rc/stdout/stderr and must come out FALSE. (The earlier M9 ran a mutated copy of
  # the whole script and accepted any rc != 2 — a rc 1 from an unrelated failure
  # passed it; M10 evaluated a hand-written tautology and never touched the script.)
  ap_region() { sed -n '/^# BEGIN-ARGPARSE/,/^# END-ARGPARSE/p' "$1"; }
  ap_region "$AP_SELF" > "$AP_TMP/parser.real.sh"
  grep -q 'END-ARGPARSE' "$AP_TMP/parser.real.sh" || { echo "◍ COULD NOT DETERMINE — parser markers not found in $AP_SELF"; exit 2; }
  # ap_h <harness-file> args... -> AP_RC AP_OUT AP_ERR (harness exits 0 silently when argv is accepted)
  ap_h() { local f="$1"; shift; AP_RC=0; timeout 20 bash "$f" "$@" >"$AP_TMP/o2" 2>"$AP_TMP/e2" || AP_RC=$?
    AP_OUT="$(cat "$AP_TMP/o2")"; AP_ERR="$(cat "$AP_TMP/e2")"; }
  # predicates: true == the real contract holds for that run
  pred_unknown() { [ "$AP_RC" = "2" ] && printf '%s' "$AP_ERR" | grep -q 'unknown argument' && printf '%s' "$AP_ERR" | grep -q 'Usage:' && [ -z "$AP_OUT" ]; }
  pred_help_after_validation() { [ "$AP_RC" = "2" ] && printf '%s' "$AP_ERR" | grep -q 'unknown argument' && [ -z "$AP_OUT" ]; }
  pred_combo() { [ "$AP_RC" = "2" ] && printf '%s' "$AP_ERR" | grep -q -- '--prove-' && [ -z "$AP_OUT" ]; }
  H="$AP_TMP/parser.real.sh"
  ap_h "$H" --help --bogus; pred_help_after_validation && ap_ok "A4a help-then-bad" "'--help --bogus' -> rc 2 (arguments validated BEFORE --help is honoured), no help on stdout" || ap_bad "A4a help-then-bad" "rc=$AP_RC out='${AP_OUT:0:40}'"
  ap_h "$H" --bogus -h; pred_help_after_validation && ap_ok "A4b bad-then-help" "'--bogus -h' -> rc 2, no help on stdout" || ap_bad "A4b bad-then-help" "rc=$AP_RC out='${AP_OUT:0:40}'"
  A5=ok
  for combo in "--prove-args --dry-run" "--dry-run --prove-buildyear" "-n --prove-deploy-scope" "--prove-args --prove-buildyear" "--prove-args --prove-args" "--prove-build-fatality --prove-deploy-scope --dry-run"; do
    # shellcheck disable=SC2086
    ap_h "$H" $combo; pred_combo || { ap_bad "A5 combos-rejected" "'$combo' -> rc=$AP_RC err='${AP_ERR:0:50}'"; A5=bad; }
  done
  [ "$A5" = "ok" ] && ap_ok "A5 combos-rejected" "combined --prove-* / --prove-* with --dry-run|-n all exit 2 with a --prove- diagnostic"
  A6=ok
  for okargs in "" "--dry-run" "-n" "--dry-run -n" "--prove-buildyear" "--prove-build-fatality" "--prove-deploy-scope" "--prove-args"; do
    # shellcheck disable=SC2086
    ap_h "$H" $okargs; { [ "$AP_RC" = "0" ] && [ -z "$AP_OUT$AP_ERR" ]; } || { ap_bad "A6 valid-accepted" "'$okargs' -> rc=$AP_RC err='${AP_ERR:0:50}'"; A6=bad; }
  done
  [ "$A6" = "ok" ] && ap_ok "A6 valid-accepted" "no argument, each single flag, and --dry-run -n are accepted silently (the parser does not over-reject)"
  # A1 on the extracted region too (the end-to-end loop above covers the full script)
  ap_h "$H" --dry-runn; pred_unknown && ap_ok "A1b region-unknown" "real parser region: '--dry-runn' -> rc 2 + diagnostic + usage" || ap_bad "A1b region-unknown" "rc=$AP_RC"

  # ap_mut <name> <sed-expr> -> $AP_TMP/parser.<name>.sh; COULD NOT DETERMINE if the edit is a no-op.
  ap_mut() { sed "$2" "$H" > "$AP_TMP/parser.$1.sh"
    if cmp -s "$H" "$AP_TMP/parser.$1.sh"; then echo "◍ COULD NOT DETERMINE — mutant $1 did not change the parser region"; exit 2; fi; }
  # M9 — unknown arguments swallowed. The REAL predicate on the mutant's run must be false.
  ap_mut m9 's/^    \*) echo "deploy-langs: unknown argument: $a" >&2; deploy_usage >&2; exit 2 ;;$/    *) : ;;/'
  ap_h "$AP_TMP/parser.m9.sh" --dry-runn
  if ! pred_unknown && [ "$AP_RC" = "0" ]; then AP_MUT9=1; ap_ok "M9 parser-mutant-caught" "swallow-unknown mutant accepts '--dry-runn' (rc 0, no diagnostic): the A1 predicate is FALSE on it"
  else ap_bad "M9 parser-mutant-caught" "mutant not discriminated (rc=$AP_RC): A1 proves nothing"; fi
  # M9b — --help honoured before the rest of argv is validated.
  ap_mut m9b 's/^    --help|-h) DEPLOY_WANT_HELP=1 ;;$/    --help|-h) deploy_usage; exit 0 ;;/'
  ap_h "$AP_TMP/parser.m9b.sh" --help --bogus
  if ! pred_help_after_validation && [ "$AP_RC" = "0" ]; then AP_MUT9B=1; ap_ok "M9b early-help-mutant" "help-first mutant answers '--help --bogus' with rc 0: A4 predicate is FALSE on it"
  else ap_bad "M9b early-help-mutant" "mutant not discriminated (rc=$AP_RC)"; fi
  # M9c — combination checks neutered.
  ap_mut m9c 's/-gt 1 \]/-gt 99 ]/; s/-ge 1 \] \&\& \[ "$DEPLOY_WANT_DRY"/-ge 99 ] \&\& [ "$DEPLOY_WANT_DRY"/'
  ap_h "$AP_TMP/parser.m9c.sh" --prove-args --dry-run
  C9=$AP_RC; ap_h "$AP_TMP/parser.m9c.sh" --prove-args --prove-buildyear
  if [ "$C9" = "0" ] && [ "$AP_RC" = "0" ]; then AP_MUT9C=1; ap_ok "M9c combo-mutant-caught" "combo-blind mutant accepts both '--prove-args --dry-run' and '--prove-args --prove-buildyear': A5 discriminates"
  else ap_bad "M9c combo-mutant-caught" "mutant rc=$C9/$AP_RC"; fi

  # C — DEPLOY_COAUTHOR, tested on the REAL function text extracted from the script.
  ap_fn() { sed -n '/^deploy_commit_args() {/,/^}/p' "$1"; }
  ap_fn "$AP_SELF" > "$AP_TMP/commit.real.sh"
  [ -s "$AP_TMP/commit.real.sh" ] || { echo "◍ COULD NOT DETERMINE — deploy_commit_args not found"; exit 2; }
  # pred_c1: unset -> exactly one -m pair, no trailer.  pred_c3: env value appended verbatim as its own -m.
  pred_c1() { ( COMPLETE=(ru de); . "$1"; unset DEPLOY_COAUTHOR; deploy_commit_args; [ "${#COMMIT_MSG_ARGS[@]}" = "2" ] && ! printf '%s\n' "${COMMIT_MSG_ARGS[@]}" | grep -qi 'co-authored\|claude\|opus' ); }
  pred_c2() { ( COMPLETE=(ru de); . "$1"; DEPLOY_COAUTHOR=""; deploy_commit_args; [ "${#COMMIT_MSG_ARGS[@]}" = "2" ] ); }
  pred_c3() { ( COMPLETE=(ru de); . "$1"; DEPLOY_COAUTHOR='Co-Authored-By: Test Person <t@example.invalid>'; deploy_commit_args; [ "${#COMMIT_MSG_ARGS[@]}" = "4" ] && [ "${COMMIT_MSG_ARGS[3]}" = "$DEPLOY_COAUTHOR" ] ); }
  pred_c1 "$AP_TMP/commit.real.sh" && ap_ok "C1 default-no-trailer" "DEPLOY_COAUTHOR unset -> one -m (subject only), no trailer" || ap_bad "C1 default-no-trailer" "default message carries a trailer"
  pred_c2 "$AP_TMP/commit.real.sh" && ap_ok "C2 empty-no-trailer" "DEPLOY_COAUTHOR='' -> no trailer" || ap_bad "C2 empty-no-trailer" "empty value added a trailer"
  pred_c3 "$AP_TMP/commit.real.sh" && ap_ok "C3 env-trailer" "DEPLOY_COAUTHOR value appended verbatim as its own -m" || ap_bad "C3 env-trailer" "trailer not appended verbatim"
  # C4 — the real commit line goes through deploy_commit_args, and nothing hardcodes a trailer.
  if grep -q 'commit -q "\${COMMIT_MSG_ARGS\[@\]}"' "$AP_SELF" && ! grep -n '\-m "Co-Authored-By' "$AP_SELF" | grep -qv 'commit.m10'; then
    ap_ok "C4 commit-wired" "git commit consumes COMMIT_MSG_ARGS; no hardcoded Claude trailer"
  else ap_bad "C4 commit-wired" "commit line not wired or hardcoded trailer present"; fi
  # M10 — the SHIPPED function with the trailer hardcoded (pre-fix form): C1 must come out false.
  sed 's/^  if \[ -n "${DEPLOY_COAUTHOR:-}" \]; then COMMIT_MSG_ARGS+=(-m "$DEPLOY_COAUTHOR"); fi$/  COMMIT_MSG_ARGS+=(-m "Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>")/' "$AP_TMP/commit.real.sh" > "$AP_TMP/commit.m10.sh"
  cmp -s "$AP_TMP/commit.real.sh" "$AP_TMP/commit.m10.sh" && { echo "◍ COULD NOT DETERMINE — M10 mutation did not apply"; exit 2; }
  if ! pred_c1 "$AP_TMP/commit.m10.sh"; then AP_MUT10=1; ap_ok "M10 trailer-mutant-caught" "hardcoded-trailer variant of the real function: C1 is FALSE on it"; else ap_bad "M10 trailer-mutant-caught" "mutant passed C1"; fi
  # M10b — env ignored (fixed text instead of $DEPLOY_COAUTHOR): C3 must come out false.
  sed 's/COMMIT_MSG_ARGS+=(-m "$DEPLOY_COAUTHOR")/COMMIT_MSG_ARGS+=(-m "fixed trailer")/' "$AP_TMP/commit.real.sh" > "$AP_TMP/commit.m10b.sh"
  cmp -s "$AP_TMP/commit.real.sh" "$AP_TMP/commit.m10b.sh" && { echo "◍ COULD NOT DETERMINE — M10b mutation did not apply"; exit 2; }
  if ! pred_c3 "$AP_TMP/commit.m10b.sh"; then AP_MUT10B=1; ap_ok "M10b env-ignored-mutant" "env-ignoring variant of the real function: C3 is FALSE on it"; else ap_bad "M10b env-ignored-mutant" "mutant passed C3"; fi
  echo "----------------------------------------------------------------------"
  if [ "$AP_FAIL" -gt 0 ]; then echo "❌ args §1.1 PROOF: FAIL — ${AP_FAIL} of $((AP_PASS+AP_FAIL)) assertion(s) did not hold."; exit 1; fi
  if [ "$AP_MUT9" -eq 0 ] || [ "$AP_MUT9B" -eq 0 ] || [ "$AP_MUT9C" -eq 0 ] || [ "$AP_MUT10" -eq 0 ] || [ "$AP_MUT10B" -eq 0 ]; then echo "◍ args §1.1 PROOF: COULD NOT DETERMINE — mutant not shown to fail."; exit 2; fi
  echo "✅ args §1.1 MUTATION PROOF: PASS — ${AP_PASS} assertions incl. mutants M9, M9b, M9c, M10, M10b."
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
#
# `_site/**` USED to be listed here for milosvasic.ru and is NOT any more.
# Operator decision #13 (2026-09-07) untracked it: `milosvasic.ru/.gitignore:70`
# already said `_site/`, but the rule was added AFTER the files were tracked, so
# it did nothing and eight files — ONE rendered page — sat in git against a
# sitemap declaring 525 URLs. Production never read them: that submodule's
# `.github/workflows/pages.yml` runs `bundle exec jekyll build --destination
# _site` and uploads the REGENERATED tree, so the committed copy was overwritten
# on every deploy and served to nobody.
#
# Keeping `_site` in this list after the untracking would have BROKEN THE DEPLOY.
# Measured: with `_site` ignored, `git add -A -- … _site` exits 1 with "The
# following paths are ignored by one of your .gitignore files", which this
# script's own ADD_ERR guard correctly reads as an unstageable tree — setting
# PUBLISH_FAIL=1 and exiting 4 WITHOUT publishing either site. The jekyll build
# still runs (it is what the local test harness serves); its output is simply
# no longer a git artifact.
# ── EXPERTISE + SITE-SOURCE PATHS (added 2026-11-23, independent audit) ──────
# The milosvasic.ru expertise section is Jekyll SOURCE plus shared files it
# depends on. The whitelist did not know them, so a real run aborted at
# pre-flight (exit 3) over its own deploy output, and DEPLOY_ALLOW_UNRELATED=1
# would have published a PARTIAL, inconsistent subset (pages without the layout,
# nav string and OG images they reference). Owned by default:
#   expertise/             the 165 expertise pages (all in sitemap.xml, all
#                          crawled by the live link-integrity spec)
#   assets/og/             the OG images those pages name in front matter
#   _data/ui.json          carries `nav.expertise`, used by the shared nav
#   _layouts/default.html  renders data-area and the Expertise nav link
#   expertise_localized.json  generator SOURCE data: _tools/career/expertise_pages.py
#                          reads it (LOC_NARRATIVE_PATH) to render the localized
#                          expertise pages, so it ships with them. Jekyll copies it
#                          to the site as a static file (no `exclude:` entry in
#                          _config.yml, which this script does not own).
# HELD BACK BY DEFAULT — the admin/vault surface, an explicit opt-in:
#   DEPLOY_INCLUDE_ADMIN=1 adds admin/, assets/js/vault.js, assets/js/vault-console.js,
#   _layouts/admin_console.html and downloads/vault/.
# Nothing public references any of them (zero hits in expertise/ and _layouts/),
# so they are independent of the expertise publish. Whether an admin console and
# sealed vault artifacts belong on a public Pages site is an OPERATOR decision
# this script does not make. With the flag unset they are never staged or pushed,
# and because the pre-flight refuses "dirty and not published", a dirty copy
# aborts the run (exit 3) with a message naming the flag instead of being
# skipped silently. `downloads` stays an owned prefix (the PDFs); `downloads/vault`
# is carved out of it with a git `:(exclude)` pathspec emitted on a line of its own.
# Deliberately NOT produced here, so never staged: `_site/**`, articles/ (the generator
# excludes it explicitly — see _tools/gen/seo.go), _article_src/, pages/, the rest of
# _data/ and _layouts/, docs/ (an untracked note in milosvasic.ru/docs/ would be served
# raw: commit, move or exclude it), Gemfile*, CNAME, the governance carriers, and
# every nested submodule.
# A candidate is emitted only if it exists on disk or is known to the index, so
# `git add` never aborts the whole pathspec set on one unmatched entry.
deploy_pathspecs() {
  local site="$1" l p
  local cands=(index.html sitemap.xml robots.txt products portfolio assets/od downloads
               expertise assets/og _data/ui.json _layouts/default.html
               expertise_localized.json)
  if [ "${DEPLOY_INCLUDE_ADMIN:-0}" = "1" ]; then
    cands+=(admin assets/js/vault.js assets/js/vault-console.js _layouts/admin_console.html)
  fi
  for l in $LANGS; do cands+=("$l"); done
  # NO `_site` here — see the note above. It is a build artifact of the
  # provider-side Pages workflow, not a deploy output of this script.
  for p in "${cands[@]}"; do
    if [ -e "$ROOT/$site/$p" ] || [ -n "$(git -C "$ROOT/$site" ls-files -- "$p" 2>/dev/null)" ]; then
      printf '%s\n' "$p"
    fi
  done
  # Carve-out: with the admin flag unset, downloads/vault is NOT published even
  # though `downloads` is. Emitted UNCONDITIONALLY — no existence test. Git accepts
  # an exclude that matches nothing as long as another positive pathspec is given,
  # and a TRACKED vault whose directory was deleted from disk would otherwise have
  # its deletion staged by `add -A -- downloads` (the exists-only form did that).
  if [ "${DEPLOY_INCLUDE_ADMIN:-0}" != "1" ]; then
    printf '%s\n' ':(exclude)downloads/vault'
  fi
  return 0
}

# deploy_admin_surface_path <path> — true for the admin/vault surface (a path
# deploy_pathspecs only owns with DEPLOY_INCLUDE_ADMIN=1).
deploy_admin_surface_path() {
  case "$1" in
    admin|admin/*|assets/js/vault.js|assets/js/vault-console.js|_layouts/admin_console.html|downloads/vault|downloads/vault/*) return 0 ;;
  esac
  return 1
}

# deploy_path_class <path> <specs> — prints owned | held | unowned.
# held = admin/vault surface while DEPLOY_INCLUDE_ADMIN != 1 (independent of the
# exclude spec, so the class cannot be defeated by a missing spec line).
deploy_path_class() {
  local p="$1" specs="$2" spec owned=0 held=0
  if [ "${DEPLOY_INCLUDE_ADMIN:-0}" != "1" ] && deploy_admin_surface_path "$p"; then
    printf 'held\n'; return 0
  fi
  while IFS= read -r spec; do
    [ -n "$spec" ] || continue
    case "$spec" in
      ':(exclude)'*) spec="${spec#:(exclude)}"
                     case "$p" in "$spec"|"$spec"/*) held=1 ;; esac ;;
      *)             case "$p" in "$spec"|"$spec"/*) owned=1 ;; esac ;;
    esac
  done <<SPECS_END
$specs
SPECS_END
  if [ "$held" = "1" ]; then printf 'held\n'
  elif [ "$owned" = "1" ]; then printf 'owned\n'
  else printf 'unowned\n'; fi
  return 0
}

# deploy_gitlinks <site> — every gitlink path in the index, one per line.
deploy_gitlinks() {
  git -C "$ROOT/$1" ls-files --stage 2>/dev/null | awk -F'\t' '$1 ~ /^160000/ { print $2 }'
}

# deploy_unrelated_dirty <site> — every dirty (staged OR unstaged OR untracked)
# path in <site> that this deploy does not produce. A nested submodule gitlink is
# NEVER deploy output and is reported even if it sits under a deploy-owned prefix.
# Parsed from `status --porcelain=v1 -z` (no quoting ambiguity); for a rename or
# copy BOTH sides are examined — the source side is a deletion in the commit.
deploy_unrelated_dirty() {
  local site="$1" specs gitlinks ent xy p old cls
  local -a sides
  specs="$(deploy_pathspecs "$site")"
  gitlinks="$(deploy_gitlinks "$site")"
  while IFS= read -r -d '' ent; do
    xy="${ent:0:2}"; p="${ent:3}"
    sides=("$p")
    case "$xy" in *R*|*C*) old=""; IFS= read -r -d '' old; [ -n "$old" ] && sides+=("$old") ;; esac
    for p in "${sides[@]}"; do
      if [ -n "$gitlinks" ] && printf '%s\n' "$gitlinks" | grep -qxF -- "${p%/}"; then
        printf '%s\n' "$p (nested submodule gitlink — never a deploy artifact)"
        continue
      fi
      cls="$(deploy_path_class "$p" "$specs")"
      case "$cls" in
        held) printf '%s\n' "$p (held back — admin/vault surface; set DEPLOY_INCLUDE_ADMIN=1 to publish it)" ;;
        unowned) printf '%s\n' "$p" ;;
      esac
    done
  done < <(git -C "$ROOT/$site" status --porcelain=v1 -z --untracked-files=all 2>/dev/null)
  return 0
}

# deploy_hard_blocked <site> — the subset of deploy_unrelated_dirty that
# DEPLOY_ALLOW_UNRELATED=1 can NEVER pardon: admin/vault surface and gitlinks.
deploy_hard_blocked() {
  deploy_unrelated_dirty "$1" | grep -E ' \((nested submodule gitlink|held back)' || true
}

# deploy_staged_violations <site> — every path in the INDEX (rename sources
# included: --no-renames) outside the whitelist, or a gitlink. Run AFTER staging
# and BEFORE the commit, because `git commit` takes the whole index however
# narrow the preceding `git add` was; DEPLOY_ALLOW_UNRELATED=1 lets pre-staged
# paths through pre-flight, and this is what stops them.
deploy_staged_violations() {
  local site="$1" specs gitlinks p
  specs="$(deploy_pathspecs "$site")"
  gitlinks="$(deploy_gitlinks "$site")"
  while IFS= read -r -d '' p; do
    if [ -n "$gitlinks" ] && printf '%s\n' "$gitlinks" | grep -qxF -- "$p"; then
      printf '%s\n' "$p (gitlink)"; continue
    fi
    [ "$(deploy_path_class "$p" "$specs")" = "owned" ] || printf '%s\n' "$p"
  done < <(git -C "$ROOT/$site" diff --cached --name-only -z --no-renames 2>/dev/null)
  return 0
}

# deploy_site_publishable <site> <remote>... — 0 when the site may be staged and
# pushed. Sets DEPLOY_WHY otherwise. Requires HEAD to be the symbolic ref
# refs/heads/main (a detached HEAD or another branch is refused) and no commit
# unpushed to any allow-listed remote that this deploy did not create: the
# check runs BEFORE staging, so anything ahead of <remote>/main is not ours.
deploy_site_publishable() {
  local site="$1" r ahead ref; shift
  DEPLOY_WHY=""
  ref="$(git -C "$ROOT/$site" symbolic-ref -q HEAD 2>/dev/null)"
  if [ "$ref" != "refs/heads/main" ]; then
    DEPLOY_WHY="HEAD is '${ref:-detached}', not refs/heads/main — refusing to stage or push"; return 1
  fi
  [ "$#" -gt 0 ] || { DEPLOY_WHY="empty push remote allow-list"; return 1; }
  for r in "$@"; do
    case "$r" in -*|*[!A-Za-z0-9._-]*|'') DEPLOY_WHY="bad remote name '$r'"; return 1 ;; esac
    git -C "$ROOT/$site" remote get-url "$r" >/dev/null 2>&1 || { DEPLOY_WHY="remote '$r' is not configured"; return 1; }
    git -C "$ROOT/$site" rev-parse --verify -q "refs/remotes/$r/main" >/dev/null 2>&1 \
      || { DEPLOY_WHY="no refs/remotes/$r/main — cannot tell whether local main has unpushed commits (git fetch $r)"; return 1; }
    ahead="$(git -C "$ROOT/$site" rev-list --count "refs/remotes/$r/main..HEAD" 2>/dev/null)"
    case "$ahead" in ''|*[!0-9]*) DEPLOY_WHY="cannot count commits ahead of $r/main"; return 1 ;; esac
    if [ "$ahead" -gt 0 ]; then
      DEPLOY_WHY="$ahead commit(s) on local main are not on $r/main and this deploy did not create them — push or drop them first"; return 1
    fi
  done
  return 0
}

# ── §1.1 paired-mutation proof for the deploy-scope whitelist ────────────────
#   bash _tools/deploy-langs.sh --prove-deploy-scope
# 0 the whitelist discriminates · 1 it does not · 2 could not determine.
# Runs in a THROWAWAY git repo under mktemp: it never touches either real site,
# builds nothing, commits and pushes nothing. The subjects are deploy_pathspecs
# and deploy_unrelated_dirty, driven with ROOT pointed at the scratch repo. M7
# reconstructs the PRE-2026-11-23 whitelist longhand and shows it reports the
# expertise paths as unrelated — the defect that aborted a real run at
# pre-flight — so the positive assertions are known to be able to fail.
PROVE_DEPLOY_SCOPE=0
for a in "$@"; do case "$a" in --prove-deploy-scope) PROVE_DEPLOY_SCOPE=1 ;; esac; done
if [ "$PROVE_DEPLOY_SCOPE" = "1" ]; then
  echo "DEPLOY-SCOPE §1.1 PAIRED MUTATION PROOF — deploy_pathspecs / deploy_unrelated_dirty"
  echo "----------------------------------------------------------------------"
  command -v git >/dev/null 2>&1 || { echo "◍ COULD NOT DETERMINE — git not on PATH"; exit 2; }
  DS_TMP="$(mktemp -d "${TMPDIR:-/tmp}/deploy-scope.XXXXXX")" || { echo "◍ COULD NOT DETERMINE — mktemp failed"; exit 2; }
  trap 'rm -rf "${DS_TMP:?}"' EXIT
  DS_PASS=0; DS_FAIL=0; DS_MUT=0; DS_MUT8=0
  ds_ok()  { DS_PASS=$((DS_PASS+1)); printf '✅ %-22s %s\n' "$1" "$2"; }
  ds_bad() { DS_FAIL=$((DS_FAIL+1)); printf '❌ %-22s %s\n' "$1" "$2"; }
  ROOT="$DS_TMP"; SITE=site
  mkdir -p "$ROOT/$SITE"
  G() { git -C "$ROOT/$SITE" -c user.name=t -c user.email=t@t -c commit.gpgsign=false "$@"; }
  G init -q . 2>/dev/null || { echo "◍ COULD NOT DETERMINE — git init failed"; exit 2; }
  mkdir -p "$ROOT/$SITE"/_data "$ROOT/$SITE"/_layouts "$ROOT/$SITE"/assets/od "$ROOT/$SITE"/downloads
  echo '{}' > "$ROOT/$SITE/_data/ui.json"; echo '<html>' > "$ROOT/$SITE/_layouts/default.html"
  echo x > "$ROOT/$SITE/index.html"; echo x > "$ROOT/$SITE/sitemap.xml"
  echo x > "$ROOT/$SITE/other.txt"; echo x > "$ROOT/$SITE/downloads/cv.pdf"
  G add -A && G commit -q -m base || { echo "◍ COULD NOT DETERMINE — scratch commit failed"; exit 2; }
  mk() { mkdir -p "$(dirname "$ROOT/$SITE/$1")"; echo "$2" > "$ROOT/$SITE/$1"; }
  mk expertise/go/index.html a; mk expertise/ru/index.html a
  mk assets/og/expertise.svg a; mk _data/ui.json changed; mk _layouts/default.html changed
  mk admin/console.html a; mk assets/js/vault.js a; mk assets/js/vault-console.js a; mk _layouts/admin_console.html a; mk downloads/vault/x.pdf a; mk downloads/vault/manifest.json a
  mk docs/BUILD.md a; mk notes.txt a
  unrel() { deploy_unrelated_dirty "$SITE" | sed 's/ (.*//' | sort | tr '\n' ' '; }

  # P1 — DISCRIMINATOR: the expertise source set is deploy-owned (flag unset).
  got="$(DEPLOY_INCLUDE_ADMIN=0 unrel)"; DS_P1=ok
  for o in expertise/go/index.html expertise/ru/index.html assets/og/expertise.svg _data/ui.json _layouts/default.html; do
    case " $got" in *" $o "*) ds_bad "P1 expertise-owned" "$o is reported UNRELATED — a real run would abort (exit 3)"; DS_P1=bad ;; esac
  done
  [ "$DS_P1" = "ok" ] && ds_ok "P1 expertise-owned" "expertise/, assets/og/, _data/ui.json, _layouts/default.html not reported"
  # P2 — admin/vault surface held back by default, and named as such.
  got="$(DEPLOY_INCLUDE_ADMIN=0 deploy_unrelated_dirty "$SITE")"; miss=""
  for h in admin/console.html assets/js/vault.js assets/js/vault-console.js _layouts/admin_console.html downloads/vault/x.pdf downloads/vault/manifest.json; do
    printf '%s\n' "$got" | grep -qF "$h (held back" || miss="$miss $h"
  done
  if [ -z "$miss" ]; then ds_ok "P2 admin-held-back" "admin/, vault.js, downloads/vault/ reported and labelled DEPLOY_INCLUDE_ADMIN"
  else ds_bad "P2 admin-held-back" "not held back/labelled:$miss"; fi
  # P3 — the flag publishes them, and only the literal 1.
  got="$(DEPLOY_INCLUDE_ADMIN=1 unrel)"
  case "$got" in *admin/*|*vault*|*admin_console*) ds_bad "P3 flag-honoured" "still reported with DEPLOY_INCLUDE_ADMIN=1: $got" ;;
                 *) ds_ok "P3 flag-honoured" "DEPLOY_INCLUDE_ADMIN=1 owns admin/, vault.js, downloads/vault/" ;; esac
  DS_P3B=ok
  for junk in 0 "" yes true 01; do
    got="$(DEPLOY_INCLUDE_ADMIN="$junk" unrel)"
    case "$got" in *admin/console.html*) : ;; *) ds_bad "P3b flag-strictness" "value '$junk' must NOT enable admin"; DS_P3B=bad ;; esac
  done
  [ "$DS_P3B" = "ok" ] && ds_ok "P3b flag-strictness" "only the literal '1' enables it (0, empty, yes, true, 01 do not)"
  # P4 — genuinely unrelated paths are still refused (the guard was not widened).
  got="$(DEPLOY_INCLUDE_ADMIN=1 unrel)"
  case "$got" in *"docs/BUILD.md"*"notes.txt"*) ds_ok "P4 still-refuses" "docs/BUILD.md and notes.txt stay unrelated even with the flag" ;;
                 *) ds_bad "P4 still-refuses" "unrelated paths no longer reported: $got" ;; esac
  # P5 — STAGING honours the carve-out, with real git: expertise staged, vault not.
  mapfile -t DS_SPECS < <(DEPLOY_INCLUDE_ADMIN=0 deploy_pathspecs "$SITE")
  G add -A -- "${DS_SPECS[@]}" >/dev/null 2>&1
  staged="$(G diff --cached --name-only | tr '\n' ' ')"
  case "$staged" in *vault*|*admin/*|*notes.txt*|*docs/*) ds_bad "P5 staging-scope" "staged outside scope: $staged" ;;
    *expertise/go/index.html*) ds_ok "P5 staging-scope" "expertise staged; vault, admin, docs, notes not staged" ;;
    *) ds_bad "P5 staging-scope" "expertise not staged: $staged" ;; esac
  G reset -q >/dev/null 2>&1
  # M7 — THE MUTANT: the historical whitelist, written longhand, must get P1 wrong.
  legacy_pathspecs() {
    local p l
    for p in index.html sitemap.xml robots.txt products portfolio assets/od downloads; do
      { [ -e "$ROOT/$1/$p" ] || [ -n "$(git -C "$ROOT/$1" ls-files -- "$p" 2>/dev/null)" ]; } && printf '%s\n' "$p"
    done
    for l in $LANGS; do [ -e "$ROOT/$1/$l" ] && printf '%s\n' "$l"; done
    return 0
  }
  got="$( deploy_pathspecs() { legacy_pathspecs "$@"; }; unrel )"
  case " $got" in *" expertise/go/index.html "*) DS_MUT=1; ds_ok "M7 mutant-is-caught" "the historical whitelist reports expertise/ UNRELATED (the real-run abort): P1 discriminates" ;;
                  *) ds_bad "M7 mutant-is-caught" "legacy whitelist did not report expertise/: P1 discriminates nothing" ;; esac
  # M8 — THE MUTANT for the console files: the pre-fix admin set (vault.js only)
  # must report the two console files as plain UNRELATED (no held-back label, and
  # still dirty with the flag on) — so P2/P3's console assertions can fail.
  pre_fix_pathspecs() {
    local p l
    for p in index.html sitemap.xml robots.txt products portfolio assets/od downloads expertise assets/og _data/ui.json _layouts/default.html admin assets/js/vault.js; do
      { [ -e "$ROOT/$1/$p" ] || [ -n "$(git -C "$ROOT/$1" ls-files -- "$p" 2>/dev/null)" ]; } && printf '%s\n' "$p"
    done
    return 0
  }
  got="$( deploy_pathspecs() { pre_fix_pathspecs "$@"; }; DEPLOY_INCLUDE_ADMIN=1 unrel )"
  case " $got" in *" assets/js/vault-console.js "*"_layouts/admin_console.html "*|*" _layouts/admin_console.html "*" assets/js/vault-console.js "*) DS_MUT8=1; ds_ok "M8 console-mutant-caught" "pre-fix admin set reports the console files unrelated even with the flag: P3 discriminates" ;;
                  *) ds_bad "M8 console-mutant-caught" "pre-fix set did not report console files: $got" ;; esac
  # C1/C2 — console files, flag off vs on, explicit.
  got="$(DEPLOY_INCLUDE_ADMIN=0 deploy_unrelated_dirty "$SITE")"
  if printf '%s\n' "$got" | grep -qF "assets/js/vault-console.js (held back" && printf '%s\n' "$got" | grep -qF "_layouts/admin_console.html (held back"; then
    ds_ok "C1 console-held-back" "flag unset: vault-console.js and admin_console.html abort pre-flight with the labelled message"
  else ds_bad "C1 console-held-back" "console files not labelled held back: $got"; fi
  got="$(DEPLOY_INCLUDE_ADMIN=1 unrel)"
  case "$got" in *vault-console*|*admin_console*) ds_bad "C2 console-owned" "still unrelated with flag on: $got" ;;
                 *) ds_ok "C2 console-owned" "flag on: both console files owned" ;; esac
  # ── Independent-review additions (2026-11-23) ─────────────────────────────
  # Each new rule below has a real-git positive case AND a mutant built by
  # rewriting the REAL function text (declare -f | sed) so the mutant is the
  # shipped code with one guard removed — not a hand-written lookalike.
  DS_MUTS=0
  DS_SELF="${BASH_SOURCE[0]}"
  SG() { local s="$1"; shift; git -C "$ROOT/$s" -c user.name=t -c user.email=t@t -c commit.gpgsign=false "$@"; }
  ds_mkrepo() {   # ds_mkrepo <name> — site repo on main with a bare origin, in sync
    local n="$1"
    mkdir -p "$ROOT/$n" "$DS_TMP/bare_$n.git"
    git init -q --bare "$DS_TMP/bare_$n.git" 2>/dev/null
    SG "$n" init -q . 2>/dev/null
    SG "$n" checkout -q -B main 2>/dev/null
    mkdir -p "$ROOT/$n/downloads/vault" "$ROOT/$n/admin"
    echo x > "$ROOT/$n/index.html"; echo x > "$ROOT/$n/downloads/cv.pdf"
    echo x > "$ROOT/$n/downloads/vault/sealed.bin"; echo x > "$ROOT/$n/admin/old.html"
    SG "$n" add -A && SG "$n" commit -q -m base
    SG "$n" remote add origin "$DS_TMP/bare_$n.git"
    SG "$n" push -q origin main >/dev/null 2>&1
    SG "$n" fetch -q origin >/dev/null 2>&1
  }
  # ds_mutate <fn> <newname> <sed-expr> — define <newname> = shipped <fn> with one
  # edit, sourced from a file (no dynamic eval). Exits 2 if the edit did not apply.
  ds_mutate() {
    local f="$DS_TMP/mut_$2.sh"
    declare -f "$1" | sed "s/^$1 ()/$2 ()/" > "$f.orig"
    sed "$3" "$f.orig" > "$f"
    if cmp -s "$f" "$f.orig"; then echo "◍ COULD NOT DETERMINE — mutation '$2' did not apply"; exit 2; fi
    . "$f"
  }

  # P6 — a TRACKED vault whose directory is deleted from disk: the exclude must
  # still be emitted, and staging must not stage the deletion.
  ds_mkrepo s6
  mv "$ROOT/s6/downloads/vault" "$DS_TMP/gone_vault_s6"; echo y > "$ROOT/s6/downloads/cv.pdf"
  mapfile -t DS6 < <(DEPLOY_INCLUDE_ADMIN=0 deploy_pathspecs s6)
  SG s6 add -A -- "${DS6[@]}" >/dev/null 2>&1
  st6="$(SG s6 diff --cached --name-only | tr '\n' ' ')"
  case "$st6" in *vault*) ds_bad "P6 vault-delete-exclude" "deleted tracked vault was STAGED: $st6" ;;
    *downloads/cv.pdf*) ds_ok "P6 vault-delete-exclude" "exclude emitted with no vault dir on disk; deletion not staged (staged: $st6)" ;;
    *) ds_bad "P6 vault-delete-exclude" "cv.pdf not staged: $st6" ;; esac
  SG s6 reset -q >/dev/null 2>&1
  # M11 — exists-only emission (the pre-fix form) must stage the vault deletion.
  ds_mutate deploy_pathspecs mut11_pathspecs 's/if \[ "${DEPLOY_INCLUDE_ADMIN:-0}" != "1" \]; then/if [ "${DEPLOY_INCLUDE_ADMIN:-0}" != "1" ] \&\& [ -e "$ROOT\/$site\/downloads\/vault" ]; then/'
  mapfile -t M11 < <(mut11_pathspecs s6)
  SG s6 add -A -- "${M11[@]}" >/dev/null 2>&1
  if SG s6 diff --cached --name-only | grep -q vault; then DS_MUTS=$((DS_MUTS+1)); ds_ok "M11 exclude-mutant-caught" "exists-only exclude stages the deleted vault: P6 discriminates"
  else ds_bad "M11 exclude-mutant-caught" "exists-only mutant did NOT stage the vault deletion: P6 proves nothing"; fi
  SG s6 reset -q >/dev/null 2>&1

  # P7 — DEPLOY_ALLOW_UNRELATED=1 with admin/ PRE-STAGED: pre-flight is lifted
  # by the override but the post-staging whitelist check must name the path.
  ds_mkrepo s7
  echo z > "$ROOT/s7/admin/new.html"; SG s7 add admin/new.html; echo y > "$ROOT/s7/index.html"
  mapfile -t DS7 < <(deploy_pathspecs s7); SG s7 add -A -- "${DS7[@]}" >/dev/null 2>&1
  v7="$(DEPLOY_ALLOW_UNRELATED=1 deploy_staged_violations s7)"
  case "$v7" in *admin/new.html*) ds_ok "P7 staged-admin-aborts" "pre-staged admin/new.html reported by the post-staging check despite DEPLOY_ALLOW_UNRELATED=1" ;;
    *) ds_bad "P7 staged-admin-aborts" "pre-staged admin/ not reported: '$v7'" ;; esac
  case "$v7" in *index.html*) ds_bad "P7b owned-not-flagged" "owned index.html wrongly reported: $v7" ;; *) ds_ok "P7b owned-not-flagged" "owned staged path index.html not reported" ;; esac
  ds_mutate deploy_staged_violations mut12_staged 's/\[ "$(deploy_path_class "$p" "$specs")" = "owned" \] || printf .%s\\n. "$p"/:/; s/printf .%s\\n. "$p (gitlink)"; continue/continue/'
  if [ -z "$(mut12_staged s7)" ]; then DS_MUTS=$((DS_MUTS+1)); ds_ok "M12 staged-check-mutant" "the staged check with its whitelist test removed reports nothing: P7 discriminates"; else ds_bad "M12 staged-check-mutant" "mutant still reported: $(mut12_staged s7)"; fi

  # P8 — hard blocks hold under DEPLOY_ALLOW_UNRELATED=1: admin/vault surface and
  # a nested gitlink (even under an owned prefix).
  echo q > "$ROOT/s7/downloads/vault/new.bin"
  SG s7 update-index --add --cacheinfo "160000,$(SG s7 rev-parse HEAD),assets/od/nested" >/dev/null 2>&1
  hb="$(DEPLOY_ALLOW_UNRELATED=1 deploy_hard_blocked s7)"
  if printf '%s\n' "$hb" | grep -q 'admin/new.html (held back' && printf '%s\n' "$hb" | grep -q 'downloads/vault/new.bin (held back' && printf '%s\n' "$hb" | grep -q 'assets/od/nested (nested submodule gitlink'; then
    ds_ok "P8 hard-blocks" "admin/, vault/ and a gitlink under owned assets/od are hard-blocked with DEPLOY_ALLOW_UNRELATED=1"
  else ds_bad "P8 hard-blocks" "missing from hard set: '$hb'"; fi
  # the pre-flight wiring must consult the hard block before the override.
  if awk '/^if \[ "\$PREFLIGHT_HARD" = "1" \]/{h=NR} /^  if \[ "\$\{DEPLOY_ALLOW_UNRELATED:-0\}" = "1" \]/{a=NR} END{exit !(h&&a&&h<a)}' "$DS_SELF"; then
    ds_ok "P8b hard-before-override" "pre-flight evaluates the hard block before the DEPLOY_ALLOW_UNRELATED override"
  else ds_bad "P8b hard-before-override" "pre-flight order wrong or hard block absent"; fi
  SG s7 reset -q >/dev/null 2>&1

  # P9 — renames: BOTH sides are examined (source admin/old.html -> owned dest).
  ds_mkrepo s9
  mkdir -p "$ROOT/s9/expertise"; SG s9 mv admin/old.html expertise/old.html >/dev/null 2>&1
  r9="$(deploy_unrelated_dirty s9)"
  case "$r9" in *"admin/old.html (held back"*) ds_ok "P9 rename-both-sides" "rename admin/old.html -> expertise/old.html reports the admin source side" ;;
    *) ds_bad "P9 rename-both-sides" "source side not reported: '$r9'" ;; esac
  ds_mutate deploy_unrelated_dirty mut_dest_only 's/^ *IFS= read -r -d .. old;$/:;/'
  case "$(mut_dest_only s9)" in *"admin/old.html (held back"*) ds_bad "M13 dest-only-mutant" "dest-only parser still saw the source side" ;;
    *) DS_MUTS=$((DS_MUTS+1)); ds_ok "M13 dest-only-mutant" "a destination-only parser misses the admin source: P9 discriminates" ;; esac
  SG s9 reset -q >/dev/null 2>&1

  # P10 — branch / unpushed-commit guard, real git, bare origin.
  ds_mkrepo s10
  if deploy_site_publishable s10 origin; then ds_ok "P10a synced-main-ok" "main in sync with origin/main is publishable"; else ds_bad "P10a synced-main-ok" "refused a clean synced main: $DEPLOY_WHY"; fi
  SG s10 checkout -q --detach >/dev/null 2>&1
  if deploy_site_publishable s10 origin; then ds_bad "P10b detached-refused" "detached HEAD accepted"; else ds_ok "P10b detached-refused" "detached HEAD refused ($DEPLOY_WHY)"; fi
  SG s10 checkout -q -b feature >/dev/null 2>&1
  if deploy_site_publishable s10 origin; then ds_bad "P10c other-branch-refused" "branch 'feature' accepted"; else ds_ok "P10c other-branch-refused" "branch feature refused ($DEPLOY_WHY)"; fi
  SG s10 checkout -q main >/dev/null 2>&1; echo u > "$ROOT/s10/unpushed.txt"; SG s10 add unpushed.txt; SG s10 commit -q -m unpushed
  if deploy_site_publishable s10 origin; then ds_bad "P10d unpushed-refused" "unpushed foreign commit accepted"; else ds_ok "P10d unpushed-refused" "unpushed commit refused ($DEPLOY_WHY)"; fi
  if deploy_site_publishable s10 nosuch; then ds_bad "P10e bad-remote-refused" "unconfigured remote accepted"; else ds_ok "P10e bad-remote-refused" "unconfigured remote refused ($DEPLOY_WHY)"; fi
  # M14/M15 — the shipped function with ONE guard removed must accept the bad state.
  ds_mutate deploy_site_publishable mut_nobranch 's/\[ "$ref" != "refs\/heads\/main" \]/[ 0 = 1 ]/'
  ds_mutate deploy_site_publishable mut_noahead 's/\[ "$ahead" -gt 0 \]/[ 0 -gt 1 ]/'
  ds_mkrepo s14; SG s14 checkout -q --detach >/dev/null 2>&1   # clean + synced, so ONLY the branch guard can refuse
  if deploy_site_publishable s14 origin; then ds_bad "P10b2 detached-clean-refused" "clean detached HEAD accepted"; else ds_ok "P10b2 detached-clean-refused" "clean synced detached HEAD refused by the branch guard alone"; fi
  if mut_nobranch s14 origin; then DS_MUTS=$((DS_MUTS+1)); ds_ok "M14 no-branch-mutant" "without the branch guard a detached HEAD is accepted: P10b discriminates"; else ds_bad "M14 no-branch-mutant" "mutant still refused detached HEAD ($DEPLOY_WHY)"; fi
  if mut_noahead s10 origin; then DS_MUTS=$((DS_MUTS+1)); ds_ok "M15 no-ahead-mutant" "without the ahead guard an unpushed commit is accepted: P10d discriminates"; else ds_bad "M15 no-ahead-mutant" "mutant still refused the unpushed commit ($DEPLOY_WHY)"; fi
  # P10f — the push sends the exact commit as <sha>:refs/heads/main, never the bare branch name.
  if grep -q 'push "\$r" "\$NEW_SHA:refs/heads/main"' "$DS_SELF" && ! grep -qE 'push "\$r" main' "$DS_SELF"; then
    ds_ok "P10f push-refspec" "push uses \$NEW_SHA:refs/heads/main; no bare 'main' push remains"
  else ds_bad "P10f push-refspec" "push line is not the explicit <sha>:refs/heads/main form"; fi

  # P11 — expertise_localized.json (generator SOURCE data read by
  # _tools/career/expertise_pages.py) is deploy-owned.
  ds_mkrepo s11
  echo '{}' > "$ROOT/s11/expertise_localized.json"
  case "$(DEPLOY_INCLUDE_ADMIN=0 deploy_unrelated_dirty s11)" in *expertise_localized.json*) ds_bad "P11 localized-json-owned" "expertise_localized.json reported unrelated" ;;
    *) ds_ok "P11 localized-json-owned" "expertise_localized.json is deploy-owned (no abort)" ;; esac
  case "$( deploy_pathspecs() { pre_fix_pathspecs "$@"; }; DEPLOY_INCLUDE_ADMIN=0 deploy_unrelated_dirty s11 )" in *expertise_localized.json*) DS_MUTS=$((DS_MUTS+1)); ds_ok "M16 json-mutant-caught" "the pre-fix whitelist reports it unrelated: P11 discriminates" ;;
    *) ds_bad "M16 json-mutant-caught" "pre-fix whitelist did not report it" ;; esac
  echo "----------------------------------------------------------------------"
  if [ "$DS_FAIL" -gt 0 ]; then echo "❌ deploy-scope §1.1 PROOF: FAIL — ${DS_FAIL} of $((DS_PASS+DS_FAIL)) assertion(s) did not hold."; exit 1; fi
  if [ "$DS_MUT" -eq 0 ] || [ "$DS_MUT8" -eq 0 ] || [ "$DS_MUTS" -lt 6 ]; then echo "◍ deploy-scope §1.1 PROOF: COULD NOT DETERMINE — mutant not shown to fail (new-mutants caught: ${DS_MUTS}/6)."; exit 2; fi
  echo "✅ deploy-scope §1.1 MUTATION PROOF: PASS — ${DS_PASS} assertions incl. mutants M7, M8, M11-M16."
  exit 0
fi

PREFLIGHT_BLOCKED=0; PREFLIGHT_HARD=0
for s in vasic.digital milosvasic.ru; do
  EXTRA="$(deploy_unrelated_dirty "$s")"
  [ -n "$EXTRA" ] || continue
  PREFLIGHT_BLOCKED=1
  echo "[deploy-langs] $s: dirty paths that this deploy does NOT produce:" >&2
  printf '%s\n' "$EXTRA" | sed "s|^|[deploy-langs]   $s: |" >&2
  if [ -n "$(printf '%s\n' "$EXTRA" | grep -E ' \((nested submodule gitlink|held back)' || true)" ]; then
    PREFLIGHT_HARD=1
  fi
done
if [ "$PREFLIGHT_HARD" = "1" ]; then
  # HARD BLOCK: the admin/vault surface and nested gitlinks are never pardoned by
  # DEPLOY_ALLOW_UNRELATED (only DEPLOY_INCLUDE_ADMIN=1 owns the former).
  if [ "$DRY_RUN" = "1" ]; then
    echo "[deploy-langs] DRY-RUN: a real deploy WOULD ABORT (exit 3) on admin/vault or gitlink paths; DEPLOY_ALLOW_UNRELATED does not lift this." >&2
  else
    echo "[deploy-langs] ABORTED (exit 3): admin/vault-surface or nested-gitlink paths are dirty." >&2
    echo "[deploy-langs] DEPLOY_ALLOW_UNRELATED=1 does NOT apply to them. Nothing was built, staged, committed or pushed." >&2
    exit 3
  fi
fi
if [ "$PREFLIGHT_BLOCKED" = "1" ]; then
  if [ "${DEPLOY_ALLOW_UNRELATED:-0}" = "1" ]; then
    echo "[deploy-langs] OVERRIDE DEPLOY_ALLOW_UNRELATED=1 — proceeding. Staging stays scoped, and any" >&2
    echo "[deploy-langs] path ALREADY STAGED outside the whitelist aborts the publish before the commit." >&2
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
# sync assets + regenerate EN (updates hreflang/sitemap to include complete langs).
# FATAL: see "WHICH BUILD STEPS ARE TOLERATED" near the top of this file.
bash "$GEN/build.sh" --lang en --no-jekyll >/dev/null 2>&1 || build_fail "en gen"
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
  # FATAL: reaching this line means weasyprint AND pandoc both resolved, so a
  # non-zero rc here is a real render failure and not a missing toolchain. The
  # `else` branch below is the toolchain-absent case and stays a plain skip.
  bash "$PDF" en >/dev/null 2>&1 || build_fail "pdf en"
  for l in "${COMPLETE[@]:-}"; do
    [ -z "$l" ] && continue
    # The success line prints ONLY on success: it used to follow a tolerated failure unconditionally,
    # so a failed `pdf <lang>` was reported as both a warning and "pdf built" (gap register UG-02).
    if bash "$PDF" "$l" >/dev/null 2>&1; then
      echo "[deploy-langs] pdf built: $l"
    else
      build_warn "pdf $l"
    fi
  done
else
  # DELIBERATELY still a plain skip, and the reasoning is recorded rather than
  # left to be re-derived. Consistency would argue for build_undet here: the
  # toolchain is absent and no verdict was reached. It is NOT promoted, because
  # doing so would abort a deploy on every host without weasyprint/pandoc — a
  # behaviour change far wider than operator decision #12, which named the
  # jekyll step. The bounded cost is stated instead: the PDFs already published
  # stand unchanged, and no PDF is ever faked. Promoting this to rc 2 is an
  # operator decision that has NOT been taken.
  echo "[deploy-langs] pdf tooling missing (weasyprint/pandoc) — skipping PDF build"
fi

# rebuild jekyll _site for milosvasic (picks up freshly built PDFs)
#
# THREE-VALUED, and the two states are distinguished BEFORE the build rather than
# inferred from an exit code afterwards. A bare `jekyll` that is not on PATH
# returns 127, which is indistinguishable at the call site from a Jekyll that ran
# and rejected the site — and on this development host that is not hypothetical:
# `bundle`, `bundler` and `jekyll` are all absent from PATH (measured 2026-09-06,
# re-measured 2026-09-08), so this step has been returning 127 into a tolerated
# warning on every run. Resolve the runner first, then classify.
printf 'build_year: %s\n' "$BUILD_YEAR" > milosvasic.ru/_config.deploy.yml
JEKYLL_RUNNER=""
if command -v jekyll >/dev/null 2>&1; then
  JEKYLL_RUNNER="jekyll"
elif command -v bundle >/dev/null 2>&1 && ( cd milosvasic.ru && bundle exec jekyll --version >/dev/null 2>&1 ); then
  JEKYLL_RUNNER="bundle exec jekyll"
fi
if [ -z "$JEKYLL_RUNNER" ]; then
  # THIRD RUNNER (2026-09-22): the containerised build. With no host Jekyll this
  # step used to end as COULD NOT RUN on every run, although a working build
  # path exists — _tools/containers/cmd/site-build drives the ruby image through
  # the Containers Submodule (§11.4.76) and verifies a FRESH _site artifact
  # itself. It pins the same footer year through the same _config.deploy.yml,
  # so the host and container paths render the same bytes. Its exit is
  # three-valued like this gate: 1 a real build failure, 2 could not run.
  SITE_BUILD="$ROOT/_tools/containers/bin/site-build"
  # Rebuilt when missing OR STALE (build-if-missing class fix, T025): an
  # existence-only guard here would run a stale site-build binary forever after
  # a source change under _tools/containers/ (cmd/site-build's own package plus
  # any local package it imports), the exact "restart runs a stale binary" trap
  # this class exists to catch — this binary is not a restart target, but a
  # deploy that never rebuilds it is the same defect one step removed.
  if { [ ! -x "$SITE_BUILD" ] || [ -n "$(find "$ROOT/_tools/containers" -path "$ROOT/_tools/containers/bin" -prune -o -type f -newer "$SITE_BUILD" -print -quit 2>/dev/null)" ]; } && command -v go >/dev/null 2>&1; then
    ( cd "$ROOT/_tools/containers" && GOPROXY=off go build -o bin/site-build ./cmd/site-build ) >/dev/null 2>&1
  fi
  if [ -x "$SITE_BUILD" ]; then
    "$SITE_BUILD" -workload jekyll -build-year "$BUILD_YEAR" >/dev/null 2>&1
    case $? in
      0) echo "[deploy-langs] jekyll _site rebuilt in a container (site-build)" ;;
      1) build_fail "jekyll _site rebuild (container)" ;;
      *) build_undet "jekyll _site rebuild (no host jekyll; container build could not run)" ;;
    esac
  else
    build_undet "jekyll _site rebuild (no jekyll on PATH, no working 'bundle exec jekyll', no site-build)"
  fi
else
  ( cd milosvasic.ru && $JEKYLL_RUNNER build --quiet --config _config.yml,_config.deploy.yml ) >/dev/null 2>&1 \
    || build_fail "jekyll _site rebuild"
fi
rm -f milosvasic.ru/_config.deploy.yml

# THE GATE. Placed here — after every build step, before the dry-run preview and
# before any staging, commit or push — so that BOTH a real deploy and a --dry-run
# are held to it. A --dry-run that reported success having built nothing is the
# exact defect operator decision #12 was raised against.
build_gate

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
  # Branch + unpushed-commit guard BEFORE anything is staged (see
  # deploy_site_publishable): a detached HEAD or a foreign unpushed commit must
  # never be published under this deploy's name.
  read -r -a REMOTES <<< "${DEPLOY_PUSH_REMOTES:-origin}"
  if ! deploy_site_publishable "$s" "${REMOTES[@]}"; then
    echo "[deploy-langs] $s: ERROR — $DEPLOY_WHY; NOT staging." >&2
    PUBLISH_FAIL=1
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
  VIOL="$(deploy_staged_violations "$s")"
  if [ -n "$VIOL" ]; then
    echo "[deploy-langs] $s: ERROR — the index holds paths outside the deploy whitelist; NOT committing:" >&2
    printf '%s\n' "$VIOL" | sed "s|^|[deploy-langs]   $s: |" >&2
    PUBLISH_FAIL=1
    continue
  fi
  if git -C "$s" diff --cached --quiet 2>/dev/null; then
    echo "[deploy-langs] $s: no change"
  else
    # A commit failure was silenced by `2>/dev/null` and execution fell straight
    # through to `git push`, publishing whatever HEAD already happened to be.
    deploy_commit_args
    if ! COMMIT_ERR="$(git -C "$s" commit -q "${COMMIT_MSG_ARGS[@]}" 2>&1)"; then
      echo "[deploy-langs] $s: ERROR — commit FAILED; NOT pushing." >&2
      printf '%s\n' "$COMMIT_ERR" | sed "s|^|[deploy-langs]   $s: |" >&2
      PUBLISH_FAIL=1
      continue
    fi
    NEW_SHA="$(git -C "$s" rev-parse HEAD 2>/dev/null)"
    for r in "${REMOTES[@]}"; do
      # `git push ... | tail -1` threw the push's exit status away, so a rejected
      # push read as an ordinary log line, the cycle exited 0, and the live
      # validator then PASSed against the OLD, still-deployed content.
      PUSH_OUT="$(git -C "$s" push "$r" "$NEW_SHA:refs/heads/main" 2>&1)"; PUSH_RC=$?
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
