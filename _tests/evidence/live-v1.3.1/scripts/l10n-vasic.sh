#!/bin/bash
CURL=/usr/bin/curl
D=/Volumes/T7/Projects/vasic/_tests/evidence/live-v1.3.1
langs="ar be de es fa fr hi ja kk ko ru sr tr zh"
out="$D/l10n-grid-vasic.txt"
echo "lang | html_lang | dir | nav_home | nav_portfolio | aria_nav | home_href | home_http | en_leak" > "$out"
for l in $langs; do
  f="$D/html/portfolio/vasic-$l.html"
  htmltag=$(grep -o '<html[^>]*>' "$f" | head -1)
  langok=$(echo "$htmltag" | grep -q "lang=\"$l\"" && echo "$l" || echo "NO:$htmltag")
  if [ "$l" = "ar" ] || [ "$l" = "fa" ]; then expdir="rtl"; else expdir="ltr"; fi
  dirok=$(echo "$htmltag" | grep -q "dir=\"$expdir\"" && echo "$expdir" || echo "NO($expdir)")
  navblock=$(awk '/<nav class="od-nav"/,/<\/nav>/' "$f")
  home=$(echo "$navblock" | grep -oE '<a [^>]*>[^<]*</a>' | sed -n '1p' | sed -E 's/.*>([^<]*)<.*/\1/')
  port=$(echo "$navblock" | grep -oE '<a [^>]*>[^<]*</a>' | sed -n '2p' | sed -E 's/.*>([^<]*)<.*/\1/')
  aria=$(echo "$htmltag" >/dev/null; grep -oE '<nav class="od-nav" aria-label="[^"]*"' "$f" | sed -E 's/.*aria-label="([^"]*)".*/\1/')
  hhref=$(echo "$navblock" | grep -oE 'href="[^"]*"' | head -1 | sed -E 's/href="([^"]*)"/\1/')
  # resolve home href relative to /portfolio/$l/
  case "$hhref" in
    http*) full="$hhref" ;;
    /*) full="https://vasic.digital$hhref" ;;
    *) full="https://vasic.digital/portfolio/$l/$hhref" ;;
  esac
  hcode=$($CURL -sSL -o /dev/null -w "%{http_code}" "$full")
  leak="ok"
  if [ "$home" = "Home" ]; then leak="LEAK(home=Home)"; fi
  echo "$l | $langok | $dirok | $home | $port | $aria | $hhref->$hcode | $leak" >> "$out"
done
cat "$out"
