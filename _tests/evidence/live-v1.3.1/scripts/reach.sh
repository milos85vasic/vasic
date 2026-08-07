#!/bin/bash
CURL=/usr/bin/curl
D=/Volumes/T7/Projects/vasic/_tests/evidence/live-v1.3.1
langs="ar be de es fa fr hi ja kk ko ru sr tr zh"
check() {
  local base=$1 out=$2
  : > "$out"
  for path in "/" "/portfolio/"; do
    code=$($CURL -sSL -o /dev/null -w "%{http_code}" "$base$path")
    echo "$code  $base$path" >> "$out"
  done
  for l in $langs; do
    code=$($CURL -sSL -o /dev/null -w "%{http_code}" "$base/portfolio/$l/")
    echo "$code  $base/portfolio/$l/" >> "$out"
  done
  code=$($CURL -sSL -o /dev/null -w "%{http_code}" "$base/products/catalogizer.html")
  echo "$code  $base/products/catalogizer.html" >> "$out"
  for l in $langs; do
    code=$($CURL -sSL -o /dev/null -w "%{http_code}" "$base/products/$l/catalogizer.html")
    echo "$code  $base/products/$l/catalogizer.html" >> "$out"
  done
}
check "https://vasic.digital" "$D/reach-vasic.txt"
check "https://milosvasic.ru" "$D/reach-milos.txt"
echo "=== VASIC non-200 ==="; grep -v "^200" "$D/reach-vasic.txt" || echo "(none)"
echo "vasic lines: $(wc -l < "$D/reach-vasic.txt"), 200s: $(grep -c "^200" "$D/reach-vasic.txt")"
echo "=== MILOS non-200 ==="; grep -v "^200" "$D/reach-milos.txt" || echo "(none)"
echo "milos lines: $(wc -l < "$D/reach-milos.txt"), 200s: $(grep -c "^200" "$D/reach-milos.txt")"
