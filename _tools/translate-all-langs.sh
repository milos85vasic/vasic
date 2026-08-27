#!/usr/bin/env bash
# Generic driver: translate ALL article sources for both sites into the given
# languages via the mandated HelixTranslate pipeline, then render fragments.
# Usage: translate-all-langs.sh <tag> <lang> [<lang> ...]
#   <tag> names the summary log (evidence/translate/<tag>-summary.log)
# Resumable (skips already-translated files). No `set -e`.
set -uo pipefail
TAG="$1"; shift
LANGS="$*"
# ROOT (the repository root) is DERIVED from this script's own location
# (<repo>/_tools/translate-all-langs.sh -> "$(dirname)/.."), never hardcoded: a
# literal absolute path only resolves on the machine it was typed on, and since
# this script sets -u and pipefail but NOT -e, a wrong root fails silently — the
# per-site glob matches nothing and the batch "succeeds" having translated zero
# files. Set VASIC_ROOT only to deliberately target a different checkout.
ROOT="${VASIC_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
[ -n "$ROOT" ] && [ -d "$ROOT" ] || { echo "FATAL: cannot resolve repository root (got '$ROOT')" >&2; exit 1; }
PIPE="$ROOT/_tools/translate-pipeline.sh"
REND="$ROOT/_tools/render-articles.sh"
SUM="$ROOT/_tests/evidence/translate/${TAG}-summary.log"
mkdir -p "$(dirname "$SUM")"; : > "$SUM"
ok=0; fail=0
for site in milosvasic.ru vasic.digital; do
  root="$ROOT/$site"
  for lang in $LANGS; do
    for md in "$root/_article_src/en/"*.md; do
      slug="$(basename "$md" .md)"
      out="$root/_article_src/$lang/$slug.md"
      if [ -f "$out" ]; then echo "SKIP(exists) $site/$lang/$slug" >>"$SUM"; ok=$((ok+1)); continue; fi
      if bash "$PIPE" --in "$md" --out "$out" --lang "$lang" --article >>"$SUM" 2>&1; then
        echo "OK $site/$lang/$slug" >>"$SUM"; ok=$((ok+1))
      else
        echo "FAIL $site/$lang/$slug" >>"$SUM"; fail=$((fail+1))
      fi
    done
  done
  bash "$REND" "$root" $LANGS >>"$SUM" 2>&1
done
{
  echo "SUMMARY tag=$TAG langs=[$LANGS] ok=$ok fail=$fail"
  for site in milosvasic.ru vasic.digital; do
    for lang in $LANGS; do
      echo "$site/$lang md=$(ls "$ROOT/$site/_article_src/$lang/"*.md 2>/dev/null|wc -l) html=$(ls "$ROOT/$site/articles/$lang/"*.html 2>/dev/null|wc -l)"
    done
  done
  echo DONE
} >>"$SUM"
