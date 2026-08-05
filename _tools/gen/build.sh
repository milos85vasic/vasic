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
