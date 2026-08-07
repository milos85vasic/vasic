#!/bin/bash
CURL=/usr/bin/curl
D=/Volumes/T7/Projects/vasic/_tests/evidence/live-v1.3.1
mkdir -p "$D/html/portfolio"
langs="ar be de es fa fr hi ja kk ko ru sr tr zh"

grid() { # base label i18nkeys(comma) enWords(pipe)
  local base=$1 label=$2
  local out="$D/l10n-grid-$label.txt"
  echo "lang | html_lang_ok | dir_ok | nav_work | nav_2 | nav_3 | nav_contact | en_leak" > "$out"
  for l in $langs; do
    f="$D/html/portfolio/$label-$l.html"
    $CURL -sSL "$base/portfolio/$l/" -o "$f"
    htmltag=$(grep -o '<html[^>]*>' "$f" | head -1)
    langok=$(echo "$htmltag" | grep -q "lang=\"$l\"" && echo yes || echo NO)
    # expected dir
    if [ "$l" = "ar" ] || [ "$l" = "fa" ]; then expdir="rtl"; else expdir="ltr"; fi
    dirok=$(echo "$htmltag" | grep -q "dir=\"$expdir\"" && echo "$expdir" || echo "NO($expdir)")
    # nav texts by data-i18n key
    nw=$(grep -oE '<a[^>]*data-i18n="nav.work"[^>]*>[^<]*</a>' "$f" | sed -E 's/.*>([^<]*)<.*/\1/' | head -1)
    n2k1=$(grep -oE '<a[^>]*data-i18n="nav.products"[^>]*>[^<]*</a>' "$f" | sed -E 's/.*>([^<]*)<.*/\1/' | head -1)
    n2k2=$(grep -oE '<a[^>]*data-i18n="nav.experience"[^>]*>[^<]*</a>' "$f" | sed -E 's/.*>([^<]*)<.*/\1/' | head -1)
    n2="$n2k1$n2k2"
    n3k1=$(grep -oE '<a[^>]*data-i18n="nav.portfolio"[^>]*>[^<]*</a>' "$f" | sed -E 's/.*>([^<]*)<.*/\1/' | head -1)
    n3k2=$(grep -oE '<a[^>]*data-i18n="nav.skills"[^>]*>[^<]*</a>' "$f" | sed -E 's/.*>([^<]*)<.*/\1/' | head -1)
    n3="$n3k1$n3k2"
    nc=$(grep -oE '<a[^>]*data-i18n="nav.contact"[^>]*>[^<]*</a>' "$f" | sed -E 's/.*>([^<]*)<.*/\1/' | head -1)
    # english-leak heuristic: nav.work text still == "Work" on a non-en page
    leak="ok"
    if [ "$nw" = "Work" ]; then leak="LEAK(work=Work)"; fi
    echo "$l | $langok | $dirok | $nw | $n2 | $n3 | $nc | $leak" >> "$out"
  done
  echo "===== $label ====="; cat "$out"
}
grid "https://vasic.digital" "vasic"
grid "https://milosvasic.ru" "milos"
