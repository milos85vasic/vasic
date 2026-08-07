#!/bin/bash
CURL=/usr/bin/curl
D=/Volumes/T7/Projects/vasic/_tests/evidence/live-v1.3.1
out="$D/broken-assets-scope.txt"
: > "$out"
echo "Confirming broken '../assets' CSS ref on localized vasic pages (depth-2)." | tee -a "$out"
echo "A page is BROKEN if it references href=\"../assets/od/vasic-digital.css\" (resolves to 404 at depth-2)." | tee -a "$out"
echo "" | tee -a "$out"
# sample product pages across langs & slugs
for u in \
  "/products/ar/catalogizer.html" "/products/de/helixagent.html" "/products/ja/helixcode.html" \
  "/products/zh/helixllm.html" "/products/sr/helixqa.html" "/products/fr/visionengine.html" \
  "/portfolio/be/" "/portfolio/hi/" "/portfolio/ko/" "/portfolio/tr/" "/portfolio/es/" "/portfolio/kk/" ; do
  html=$($CURL -sSL "https://vasic.digital$u")
  ref=$(echo "$html" | grep -c 'href="../assets/od/vasic-digital.css"')
  # css resolves?
  cssabs=$(echo "$u" | sed -E 's#/[^/]*$#/../assets/od/vasic-digital.css#')
  code=$($CURL -sSL -o /dev/null -w "%{http_code}" "https://vasic.digital$u" )
  # actual resolved css url
  base_dir=$(dirname "$u")
  resolved="https://vasic.digital$base_dir/../assets/od/vasic-digital.css"
  csscode=$($CURL -sSL -o /dev/null -w "%{http_code}" "$resolved")
  verdict="BROKEN"; [ "$ref" = "0" ] && verdict="(no ref?)"; [ "$csscode" = "200" ] && verdict="OK"
  printf "%-8s page=%s(http %s) brokenCssRef=%s cssHttp=%s\n" "$verdict" "$u" "$code" "$ref" "$csscode" | tee -a "$out"
done
echo "" | tee -a "$out"
echo "Contrast — depth-1 EN pages (should be OK):" | tee -a "$out"
for u in "/products/catalogizer.html" "/portfolio/"; do
  base_dir=$(dirname "$u"); [ "$u" = "/portfolio/" ] && base_dir="/portfolio"
  resolved="https://vasic.digital$base_dir/../assets/od/vasic-digital.css"
  csscode=$($CURL -sSL -o /dev/null -w "%{http_code}" "$resolved")
  printf "%-8s page=%s cssResolvesTo=%s http=%s\n" "OK?" "$u" "$resolved" "$csscode" | tee -a "$out"
done
