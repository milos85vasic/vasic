#!/usr/bin/env bash
# Driver: translate ALL article sources for both sites to de/es/fr via the
# mandated HelixTranslate pipeline, then render localized fragments.
# Resumable (skips already-translated files). No `set -e` so one failure
# doesn't abort the whole batch.
set -uo pipefail
PIPE=/Volumes/T7/Projects/vasic/_tools/translate-pipeline.sh
REND=/Volumes/T7/Projects/vasic/_tools/render-articles.sh
SUM=/Volumes/T7/Projects/vasic/_tests/evidence/translate/defresfr-summary.log
mkdir -p "$(dirname "$SUM")"; : > "$SUM"
ok=0; fail=0
for site in milosvasic.ru vasic.digital; do
  root="/Volumes/T7/Projects/vasic/$site"
  for lang in de es fr; do
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
  bash "$REND" "$root" de es fr >>"$SUM" 2>&1
done
{
  echo "SUMMARY ok=$ok fail=$fail"
  for site in milosvasic.ru vasic.digital; do
    for lang in de es fr; do
      echo "$site/$lang md=$(ls /Volumes/T7/Projects/vasic/$site/_article_src/$lang/*.md 2>/dev/null|wc -l) html=$(ls /Volumes/T7/Projects/vasic/$site/articles/$lang/*.html 2>/dev/null|wc -l)"
    done
  done
  echo DONE
} >>"$SUM"
