#!/usr/bin/env bash
# Build the content generator and render ALL site content dynamically from
# _content/** + design-system/**. No page is hardcoded.
#
#   build.sh                 # build + generate both sites into the live dirs, rebuild _site
#   build.sh --out DIR       # generate both sites under DIR/<site> (temp validation)
#   build.sh --no-jekyll     # skip the milosvasic.ru Jekyll _site rebuild
#   build.sh --lang xx       # language (default en)
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
BIN="$HERE/gen"

OUT=""
LANG_CODE="en"
DO_JEKYLL=1
while [ $# -gt 0 ]; do
  case "$1" in
    --out) OUT="$2"; shift 2 ;;
    --lang) LANG_CODE="$2"; shift 2 ;;
    --no-jekyll) DO_JEKYLL=0; shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

echo "[build] go build ..."
( cd "$HERE" && go build -o "$BIN" . )
echo "[build] built $BIN"

DS="$ROOT/design-system"

# sync_assets: COPY every design-system asset a deployed page needs into
# <site>/assets/od/ so pages are self-contained and never link back into the
# repo (fixes the stale-copy bug class). Paths resolve from the site root:
#   assets/od/fonts.css          + assets/od/<family>/*.woff2 (+ OFL)
#   assets/od/<brand>.css        (brand tokens/components)
#   assets/od/components-extended.css
#   assets/od/animations.css     (design-system/motion/animations.css)
#   assets/od/overlays.css       (blur/layered overlay entrances)
#   assets/od/motion.js          (+ assets/od/vendor/*  + assets/od/lottie/*)
#   assets/od/icons.svg
sync_assets() {
  local site="$1" brand="$2"
  local od="$ROOT/$site/assets/od"
  mkdir -p "$od" "$od/vendor" "$od/lottie"

  cp "$DS/brand-$brand/$brand.css"          "$od/$brand.css"
  cp "$DS/components-extended.css"           "$od/components-extended.css"
  cp "$DS/motion/animations.css"            "$od/animations.css"
  cp "$DS/motion/overlays.css"              "$od/overlays.css"
  cp "$DS/motion/motion.js"                 "$od/motion.js"
  cp "$DS/icons/icons.svg"                  "$od/icons.svg"
  cp "$DS/motion/vendor/"* "$od/vendor/" 2>/dev/null || true
  cp "$DS/motion/lottie/"* "$od/lottie/" 2>/dev/null || true

  # Fonts: fonts.css references '<family>/<file>.woff2' relative to itself, so
  # the family dirs must sit next to the copied fonts.css.
  cp "$DS/fonts/fonts.css" "$od/fonts.css"
  local fam
  for fam in inter space-grotesk jetbrains-mono; do
    mkdir -p "$od/$fam"
    cp "$DS/fonts/$fam/"*.woff2 "$od/$fam/" 2>/dev/null || true
    cp "$DS/fonts/$fam/OFL.txt" "$od/$fam/OFL.txt" 2>/dev/null || true
  done

  # Brand-scoped display faces (e.g. vasic.digital's bold display typeface).
  # The brand CSS @font-face references them relative to itself as
  # 'display/<file>.woff2', so they land in <site>/assets/od/display/. No-op for
  # brands without a brand-<brand>/fonts/ directory (e.g. milosvasic).
  if [ -d "$DS/brand-$brand/fonts" ]; then
    mkdir -p "$od/display"
    cp "$DS/brand-$brand/fonts/"*.woff2 "$od/display/" 2>/dev/null || true
    cp "$DS/brand-$brand/fonts/"OFL-*.txt "$od/display/" 2>/dev/null || true
  fi
  echo "[build] synced design-system assets -> $od"
}

sync_assets vasic.digital vasic-digital
sync_assets milosvasic.ru  milosvasic

gen_site() {
  local site="$1"
  if [ -n "$OUT" ]; then
    "$BIN" -site "$site" -lang "$LANG_CODE" -root "$ROOT" -out "$OUT/$site"
  else
    "$BIN" -site "$site" -lang "$LANG_CODE" -root "$ROOT"
  fi
}

gen_site vasic.digital
gen_site milosvasic.ru

if [ -z "$OUT" ] && [ "$DO_JEKYLL" -eq 1 ]; then
  echo "[build] rebuilding milosvasic.ru/_site (jekyll) ..."
  ( cd "$ROOT/milosvasic.ru" && jekyll build --quiet )
  echo "[build] _site rebuilt"
fi

echo "[build] done"
