#!/bin/bash
CURL=/usr/bin/curl
D=/Volumes/T7/Projects/vasic/_tests/evidence/live-v1.3.1
sample() { # sitemapfile outfile
  local sm=$1 out=$2
  : > "$out"
  # take every 17th loc -> ~30 URLs
  grep -o "<loc>[^<]*</loc>" "$sm" | sed -E 's#</?loc>##g' | awk 'NR%17==1' | while read -r u; do
    code=$($CURL -sSL -o /dev/null -w "%{http_code}" "$u")
    echo "$code  $u" >> "$out"
  done
}
sample "$D/sitemap-vasic.xml" "$D/reach-vasic-sitemap-sample.txt"
sample "$D/sitemap-milos.xml" "$D/reach-milos-sitemap-sample.txt"
echo "=== VASIC sitemap sample: count=$(wc -l < "$D/reach-vasic-sitemap-sample.txt") non200: ==="
grep -v "^200" "$D/reach-vasic-sitemap-sample.txt" || echo "(none)"
echo "=== MILOS sitemap sample: count=$(wc -l < "$D/reach-milos-sitemap-sample.txt") non200: ==="
grep -v "^200" "$D/reach-milos-sitemap-sample.txt" || echo "(none)"
