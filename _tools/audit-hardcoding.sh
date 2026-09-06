#!/usr/bin/env bash
# =============================================================================
# no-hardcoding gate (#67, §11.4.6 anti-bluff / §11.4.140-141 / §11.4.216)
# -----------------------------------------------------------------------------
# Builds the generator output into a throwaway dir and fails (exit 1) on any
# hardcoded-content regression, BEFORE deploy. Complements the live Playwright
# v171-hardcoding suite (which guards production). Checks:
#   1. Footer © year is GENERATED, not hardcoded — build with buildYear=2099 and
#      assert every footer reads "© 2099"; a stray "© <other year>" in a footer
#      means the year was hardcoded somewhere (regression of the v1.7.1 fix).
#   2. No English product summary/tagline phrases leak onto non-EN product pages.
#   3. No English creative section headings on non-EN product pages.
#   4. "Linux" stays Latin in localized content (no transliteration).
#
# Check 0 (build produced real output) runs BEFORE all of the above and is what
# stops this gate from being vacuous: checks 1-4 are all "grep finds nothing"
# assertions, so an empty $OUT would make every one of them report ✅ and the
# script exit 0 while having verified precisely nothing. The generator's exit
# status is checked per language and the output is asserted non-empty, so a
# gate that finds no violations because there is no content to violate does NOT
# pass.
#
# ── THREE-VALUED EXIT (this fleet's convention; 2 is NEVER a pass) ───────────
#   0  clean — every check was EVALUATED and every one holds
#   1  a real finding — the checks ran and at least one content violation stands
#   2  COULD NOT DETERMINE — the gate had no usable input, so ZERO content
#      assertions were evaluated (toolchain absent, generator failed, output
#      empty or too small, or an anti-vacuity positive control found no subject)
# Precedence: a confirmed finding (1) outranks could-not-determine (2).
#
# WHY die() NOW EXITS 2 AND NOT 1 — a correction, measured 2026-09-06.
# Every die() call site is an "the audit had no input" condition and the
# message said so in its own words ("gate could not run"), yet the script
# exited 1. Driven with a stub `go` that built a generator emitting nothing,
# this gate printed "❌ FAIL — gate could not run: generator wrote no output
# directory for lang 'en'" and returned **1** — an unusable build reported as a
# confirmed hardcoding violation. That is a manufactured accusation, the mirror
# image of a bluffed pass, and it is now rc 2. A MISSING GO TOOLCHAIN already
# returned 2 (measured: PATH-stubbed `go` -> rc 2), so the two halves of the
# same condition disagreed with each other.
#
# Usage:
#   bash _tools/audit-hardcoding.sh                 build, then audit (default)
#   bash _tools/audit-hardcoding.sh --root DIR      audit another checkout
#   bash _tools/audit-hardcoding.sh --audit-only D  audit an EXISTING output
#                                                   tree; performs no build
#   bash _tools/audit-hardcoding.sh --prove-failure this gate's §1.1 proof
#
# §1.1 PAIRED MUTATION PROOF: `--prove-failure`. Every mutation is DATA — a
# synthetic generator-output tree written under mktemp — and NOT an edit to
# this script. A proof that edits the program it proves is testing a program
# that will never ship.
# =============================================================================
# NOTE: deliberately NOT `set -e`. Every failure path below is made explicit
# instead, so no check can be skipped or masked by implicit control flow.
set -uo pipefail

SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
AUDIT_ONLY=""
PROVE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root)          shift; ROOT="${1:-}" ;;
    --audit-only)    shift; AUDIT_ONLY="${1:-}" ;;
    --prove-failure) PROVE=1 ;;
    -h|--help)       sed -n '/^# Usage:/,/^# =====/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "audit-hardcoding.sh: unknown option '$1'" >&2; exit 2 ;;
  esac
  shift
done

FAILS=0
fail(){ echo "  ❌ $1"; FAILS=$((FAILS+1)); }
ok(){   echo "  ✅ $1"; }
# Hard stop: the gate has no usable input, so ZERO content assertions were
# evaluated. That is COULD NOT DETERMINE (rc 2), never a pass and never a
# finding about the content.
die(){  echo "  ◍ $1"; echo ""; echo "[audit] ◍ UNDETERMINED — gate could not run: $1"; exit 2; }

# EN + representative non-EN langs (Latin, Cyrillic, RTL, Devanagari, Hangul).
LANGS=(en de ru ar hi ko)
# The langs whose LOCALIZED product pages checks 2 and 3 actually read.
NONEN_LANGS=(de ru ar hi ko)
# Floors for the non-empty assertion. A real build currently emits 35 HTML files
# per language, 33 of them localized product pages; these bounds are slack on
# purpose — they exist to catch "emitted nothing" / "emitted a stub", not to
# pin an exact page count that ordinary content changes would break.
MIN_HTML_PER_LANG=20
MIN_PRODUCT_PAGES=10

EN_PHRASES=('self-hostable media collection' 'for the free world')
EN_HEADS=('Why we built it' 'Short description' 'Long description' 'The problem we set out to solve')
declare -A TRANSLIT=([hi]='लिनक्स' [ko]='리눅스' [ar]='لينكس')

# -----------------------------------------------------------------------------
# run_checks <output-dir>
# Checks 0-4 against an ALREADY-PRODUCED generator output tree. Returns 0 when
# every check holds and 1 when a content violation stands; exits 2 via die()
# when the tree cannot be audited at all.
# -----------------------------------------------------------------------------
run_checks() {
  local OUT="$1" l f p h n_html n_index n_prod FOOTERS STRAY leak2 leak3 leak4

  echo "[audit] 0. build produced real output (asserted BEFORE any content check)"
  for l in "${LANGS[@]}"; do
    [ -d "$OUT/$l" ] || die "generator wrote no output directory for lang '$l'"
    n_html=$(find "$OUT/$l" -type f -name '*.html' | wc -l | tr -d '[:space:]')
    [ "$n_html" -ge "$MIN_HTML_PER_LANG" ] \
      || die "lang '$l' produced $n_html HTML file(s), expected >= $MIN_HTML_PER_LANG"
    [ -s "$OUT/$l/sitemap.xml" ] || die "lang '$l' produced no non-empty sitemap.xml"
    n_index=$(find "$OUT/$l" -type f -name 'index.html' -size +0c | wc -l | tr -d '[:space:]')
    [ "$n_index" -ge 1 ] || die "lang '$l' produced no non-empty index.html"
  done
  for l in "${NONEN_LANGS[@]}"; do
    n_prod=$(find "$OUT/$l/products/$l" -maxdepth 1 -type f -name '*.html' 2>/dev/null \
               | wc -l | tr -d '[:space:]')
    [ "$n_prod" -ge "$MIN_PRODUCT_PAGES" ] \
      || die "lang '$l' produced $n_prod localized product page(s) under products/$l/, expected >= $MIN_PRODUCT_PAGES — checks 2 and 3 would have had nothing to read"
  done
  ok "all ${#LANGS[@]} language builds non-empty (>= $MIN_HTML_PER_LANG HTML each; >= $MIN_PRODUCT_PAGES localized product pages per non-EN lang)"

  echo "[audit] 1. footer © year is generated (2099 sentinel), never hardcoded"
  # Positive control: the pattern this check asserts on must appear at all,
  # otherwise "no stray years" would be true only because there are no footers.
  FOOTERS=$(grep -rhoE '<footer[^>]*>© [0-9]{4}' "$OUT" 2>/dev/null | wc -l | tr -d '[:space:]')
  [ "$FOOTERS" -ge 1 ] \
    || die "check 1 matched no '<footer ...>© YYYY' anywhere in the build — the assertion has no subject"
  STRAY=$(grep -rhoE '<footer[^>]*>© [0-9]{4}' "$OUT" 2>/dev/null | grep -oE '© [0-9]{4}' | grep -v '© 2099' | sort -u)
  if [ -n "$STRAY" ]; then fail "hardcoded footer year(s) found in a 2099 build: $STRAY"; else ok "all footers render the generated year (© 2099)"; fi

  echo "[audit] 2. no English product summary/tagline leak on non-EN product pages"
  leak2=0
  for l in "${NONEN_LANGS[@]}"; do
    for f in "$OUT/$l/products/$l/"*.html; do
      [ -f "$f" ] || continue
      for p in "${EN_PHRASES[@]}"; do
        if grep -qF "$p" "$f"; then fail "EN summary '$p' leaked into ${f#$OUT/}"; leak2=1; fi
      done
    done
  done
  [ "$leak2" -eq 0 ] && ok "no English product summary/tagline leak on non-EN pages"

  echo "[audit] 3. no English creative section headings on non-EN product pages"
  leak3=0
  for l in "${NONEN_LANGS[@]}"; do
    for f in "$OUT/$l/products/$l/"*.html; do
      [ -f "$f" ] || continue
      for h in "${EN_HEADS[@]}"; do
        if grep -qF "$h" "$f"; then fail "EN heading '$h' on ${f#$OUT/}"; leak3=1; fi
      done
    done
  done
  [ "$leak3" -eq 0 ] && ok "no English creative headings on non-EN pages"

  echo "[audit] 4. 'Linux' stays Latin in localized content (no transliteration)"
  leak4=0
  for l in hi ko ar; do
    if grep -rqF "${TRANSLIT[$l]}" "$OUT/$l" 2>/dev/null; then fail "transliterated Linux (${TRANSLIT[$l]}) in $l output"; leak4=1; fi
  done
  [ "$leak4" -eq 0 ] && ok "no transliterated Linux in localized output"

  echo ""
  if [ "$FAILS" -eq 0 ]; then
    echo "[audit] ✅ PASS — no hardcoded-content violations"
    return 0
  fi
  echo "[audit] ❌ FAIL — $FAILS violation(s)"
  return 1
}

# ─────────────────────────────────────────────────────────────────────────────
# §1.1 PAIRED MUTATION PROOF  —  --prove-failure
#
# The control is a SYNTHETIC output tree that is green BY CONSTRUCTION, so a red
# live tree can never silently disable the battery. Every mutation is a change
# to that FIXTURE TREE — data — and this script's own source is never touched.
# Each case re-invokes the REAL entry point as `--audit-only <fixture>`, so the
# code under test is the shipped code path and not a copy.
#
#   0  every mutation produced the required verdict
#   1  a mutation was NOT caught, or was caught with the wrong verdict
#   2  the proof could not be carried out (no sandbox) — never a pass
# ─────────────────────────────────────────────────────────────────────────────
if [ "$PROVE" -eq 1 ]; then
  echo "AUDIT-HARDCODING §1.1 PAIRED MUTATION PROOF"
  echo "----------------------------------------------------------------------"
  P_PASS=0; P_FAIL=0
  p_ok(){  P_PASS=$((P_PASS+1)); printf '✅ %-30s %s\n' "$1" "$2"; }
  p_bad(){ P_FAIL=$((P_FAIL+1)); printf '❌ %-30s %s\n' "$1" "$2"; }

  SB="$(mktemp -d "${TMPDIR:-/tmp}/audithc-proof.XXXXXX")" || {
    echo "UNDETERMINED: cannot create a sandbox, so nothing was proved." >&2; exit 2; }
  trap 'rm -rf "$SB"' EXIT INT TERM

  # Build the green-by-construction fixture tree. 23 HTML per lang (12 localized
  # product pages + index + 10 others), a sitemap, and one sentinel-year footer
  # per page — comfortably over every floor check 0 asserts.
  # $2, when given, replaces the footer markup — that is how the "no footer
  # subject at all" mutation is expressed as DATA rather than as an edit.
  mk_fixture() {
    local base="$1" foot="${2-<footer class=\"c\">© 2099</footer>}" l i body
    body="<html><body>Linux${foot}</body></html>"
    rm -rf "$base"
    for l in "${LANGS[@]}"; do
      mkdir -p "$base/$l/products/$l"
      printf '<url>%s</url>\n' "$l" >"$base/$l/sitemap.xml"
      printf '%s\n' "$body" >"$base/$l/index.html"
      # 25 non-product pages, so that removing every localized product page
      # still leaves the per-lang HTML floor satisfied — that is what lets M7
      # exercise the MIN_PRODUCT_PAGES control on its own rather than tripping
      # the MIN_HTML_PER_LANG one first.
      i=1; while [ "$i" -le 25 ]; do
        printf '%s\n' "$body" >"$base/$l/page$i.html"; i=$((i+1))
      done
      i=1; while [ "$i" -le 12 ]; do
        printf '%s\n' "$body" >"$base/$l/products/$l/p$i.html"; i=$((i+1))
      done
    done
  }

  # Run the REAL entry point against a fixture and compare the exit code.
  expect() {
    local label="$1" want="$2" dir="$3" out rc
    out="$(bash "$SELF" --audit-only "$dir" 2>&1)"; rc=$?
    if [ "$rc" -eq "$want" ]; then
      p_ok "$label" "rc=$rc as required"
    else
      p_bad "$label" "expected rc=$want, got rc=$rc — $(printf '%s' "$out" | grep -m1 -E '❌|◍' | head -c 120)"
    fi
  }

  F="$SB/tree"

  mk_fixture "$F"
  expect "CONTROL clean fixture" 0 "$F"

  mk_fixture "$F"
  printf '<footer class="c">© 2024</footer>\n' >>"$F/de/page3.html"
  expect "M1 hardcoded footer year" 1 "$F"

  mk_fixture "$F"
  printf '%s\n' "${EN_PHRASES[0]}" >>"$F/de/products/de/p1.html"
  expect "M2 EN summary on non-EN page" 1 "$F"

  mk_fixture "$F"
  printf '%s\n' "${EN_HEADS[0]}" >>"$F/ru/products/ru/p2.html"
  expect "M3 EN heading on non-EN page" 1 "$F"

  mk_fixture "$F"
  printf '%s\n' "${TRANSLIT[hi]}" >>"$F/hi/products/hi/p1.html"
  expect "M4 transliterated Linux" 1 "$F"

  # --- the anti-vacuity half: a tree that cannot be audited must NOT pass ----
  mk_fixture "$F" ""
  expect "M5 no footer subject at all" 2 "$F"

  rm -rf "$F"; mkdir -p "$F"
  expect "M6 empty output tree" 2 "$F"

  mk_fixture "$F"
  rm -f "$F/ko/products/ko/"*.html
  expect "M7 no localized product page" 2 "$F"

  mk_fixture "$F"
  : >"$F/ar/sitemap.xml"
  expect "M8 empty sitemap" 2 "$F"

  expect "M9 output tree absent" 2 "$SB/never-created"

  mk_fixture "$F"
  expect "CONTROL restored" 0 "$F"

  echo "----------------------------------------------------------------------"
  if [ "$P_FAIL" -gt 0 ]; then
    echo "❌ AUDIT-HARDCODING §1.1 PROOF: FAIL — $P_FAIL of $((P_PASS + P_FAIL)) case(s) did not behave as required."
    exit 1
  fi
  echo "✅ AUDIT-HARDCODING §1.1 MUTATION PROOF: PASS — a synthetic control passed twice and"
  echo "   9 mutations were each caught with the right THREE-VALUED verdict: a content"
  echo "   violation as rc 1, and an unauditable tree as rc 2 — never as a pass, and never"
  echo "   as an accusation about the content."
  exit 0
fi

# ─────────────────────────────────────────────────────────────────────────────
# Normal operation
# ─────────────────────────────────────────────────────────────────────────────
if [ -n "$AUDIT_ONLY" ]; then
  [ -d "$AUDIT_ONLY" ] || die "--audit-only target is not a directory: $AUDIT_ONLY"
  echo "[audit] auditing an existing output tree (no build): $AUDIT_ONLY"
  run_checks "$AUDIT_ONLY"
  exit $?
fi

GEN="$ROOT/_tools/gen"
OUT="$(mktemp -d)"
BIN="$(mktemp)"
LOG="$(mktemp)"
trap 'rm -rf "$OUT" "$BIN" "$LOG"' EXIT

echo "[audit] building generator with buildYear=2099 (sentinel year) ..."
( cd "$GEN" && go build -ldflags "-X main.buildYear=2099" -o "$BIN" . ) || {
  echo "  ◍ generator build failed (toolchain absent or source unbuildable)"
  echo ""
  echo "[audit] ◍ UNDETERMINED — gate could not run: the generator did not build"
  exit 2; }

echo "[audit] generating ${#LANGS[@]} language builds into a throwaway dir ..."
for l in "${LANGS[@]}"; do
  "$BIN" -site vasic.digital -lang "$l" -root "$ROOT" -out "$OUT/$l" >"$LOG" 2>&1
  rc=$?
  if [ "$rc" -ne 0 ]; then
    echo "  generator output for lang '$l':"
    sed 's/^/    | /' "$LOG"
    die "generator exited $rc for lang '$l' — nothing to audit"
  fi
done

run_checks "$OUT"
exit $?
