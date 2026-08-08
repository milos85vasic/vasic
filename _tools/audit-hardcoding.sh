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
# Usage:  bash _tools/audit-hardcoding.sh
# Exit:   0 = clean, 1 = violations (printed).
# =============================================================================
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GEN="$ROOT/_tools/gen"
OUT="$(mktemp -d)"
trap 'rm -rf "$OUT" "$BIN"' EXIT
BIN="$(mktemp)"
FAILS=0
fail(){ echo "  ❌ $1"; FAILS=$((FAILS+1)); }
ok(){   echo "  ✅ $1"; }

echo "[audit] building generator with buildYear=2099 (sentinel year) ..."
( cd "$GEN" && go build -ldflags "-X main.buildYear=2099" -o "$BIN" . ) || { echo "build failed"; exit 2; }

# Generate EN + representative non-EN langs (Latin, Cyrillic, RTL, Devanagari, Hangul).
for l in en de ru ar hi ko; do
  "$BIN" -site vasic.digital -lang "$l" -root "$ROOT" -out "$OUT/$l" >/dev/null 2>&1
done

echo "[audit] 1. footer © year is generated (2099 sentinel), never hardcoded"
STRAY=$(grep -rhoE '<footer[^>]*>© [0-9]{4}' "$OUT" 2>/dev/null | grep -oE '© [0-9]{4}' | grep -v '© 2099' | sort -u)
if [ -n "$STRAY" ]; then fail "hardcoded footer year(s) found in a 2099 build: $STRAY"; else ok "all footers render the generated year (© 2099)"; fi

echo "[audit] 2. no English product summary/tagline leak on non-EN product pages"
EN_PHRASES=('self-hostable media collection' 'for the free world')
leak2=0
for l in de ru ar hi ko; do
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
for l in de ru ar hi ko; do
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
