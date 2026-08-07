#!/bin/bash
CURL=/usr/bin/curl
D=/Volumes/T7/Projects/vasic/_tests/evidence/live-v1.3.1
out="$D/pdf-check.txt"
: > "$out"
chk() { # url
  local u=$1
  read code type size < <($CURL -sSL -o /dev/null -w "%{http_code} %{content_type} %{size_download}" "$u")
  local verdict="PASS"
  [ "$code" != "200" ] && verdict="FAIL(http=$code)"
  case "$type" in *pdf*) : ;; *) [ "$code" = "200" ] && verdict="FAIL(type=$type)";; esac
  [ "$code" = "200" ] && [ "$size" -lt 5000 ] && verdict="WARN(size=$size)"
  printf "%-8s http=%s type=%s size=%s  %s\n" "$verdict" "$code" "$type" "$size" "$u" | tee -a "$out"
}
echo "===== milosvasic.ru PDFs (CV/Cover/Portfolio x EN/SR/RU) ====="
for L in EN SR RU; do
  chk "https://milosvasic.ru/downloads/Milos_Vasic_CV_${L}.pdf"
  chk "https://milosvasic.ru/downloads/Milos_Vasic_Cover_Letter_${L}.pdf"
  chk "https://milosvasic.ru/downloads/Portfolio_${L}.pdf"
done
echo "===== vasic.digital PDFs (Portfolio EN + probe other langs) ====="
chk "https://vasic.digital/downloads/Portfolio_EN.pdf"
for L in RU SR DE; do chk "https://vasic.digital/downloads/Portfolio_${L}.pdf"; done
