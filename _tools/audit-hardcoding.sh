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
# gate that finds no violations because there is no content to violate FAILS.
#
# Usage:  bash _tools/audit-hardcoding.sh
# Exit:   0 = clean, 1 = violations or unusable build, 2 = generator build failed.
# =============================================================================
# NOTE: deliberately NOT `set -e`. Every failure path below is made explicit
# instead, so no check can be skipped or masked by implicit control flow.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GEN="$ROOT/_tools/gen"
OUT="$(mktemp -d)"
BIN="$(mktemp)"
LOG="$(mktemp)"
trap 'rm -rf "$OUT" "$BIN" "$LOG"' EXIT
FAILS=0
fail(){ echo "  ❌ $1"; FAILS=$((FAILS+1)); }
ok(){   echo "  ✅ $1"; }
# Hard stop: the gate has no usable input, so it must NOT reach the PASS branch.
die(){  echo "  ❌ $1"; echo ""; echo "[audit] ❌ FAIL — gate could not run: $1"; exit 1; }

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

echo "[audit] building generator with buildYear=2099 (sentinel year) ..."
( cd "$GEN" && go build -ldflags "-X main.buildYear=2099" -o "$BIN" . ) || { echo "build failed"; exit 2; }

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
EN_PHRASES=('self-hostable media collection' 'for the free world')
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
EN_HEADS=('Why we built it' 'Short description' 'Long description' 'The problem we set out to solve')
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
declare -A TRANSLIT=([hi]='लिनक्स' [ko]='리눅스' [ar]='لينكس')
leak4=0
for l in hi ko ar; do
  if grep -rqF "${TRANSLIT[$l]}" "$OUT/$l" 2>/dev/null; then fail "transliterated Linux (${TRANSLIT[$l]}) in $l output"; leak4=1; fi
done
[ "$leak4" -eq 0 ] && ok "no transliterated Linux in localized output"

echo ""
if [ "$FAILS" -eq 0 ]; then
  echo "[audit] ✅ PASS — no hardcoded-content violations"
  exit 0
else
  echo "[audit] ❌ FAIL — $FAILS violation(s)"
  exit 1
fi
