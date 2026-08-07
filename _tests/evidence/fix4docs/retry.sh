#!/usr/bin/env bash
# retry.sh <lang> <rel-under-_content>  e.g. retry.sh sr docs/cv.md
set -u
cd /Volumes/T7/Projects/vasic
LANG_CODE="$1"; REL="$2"
SRC="/Volumes/T7/Projects/vasic/_content/${REL}"
LOG="/Volumes/T7/Projects/vasic/_tests/evidence/fix4docs/${LANG_CODE}_$(echo "$REL" | tr '/' '_').log"
: > "$LOG"
MAX=10
for i in $(seq 1 $MAX); do
  echo "===== attempt $i/$MAX  $LANG_CODE  $REL  $(date -u +%H:%M:%S) =====" >> "$LOG"
  if bash /Volumes/T7/Projects/vasic/_tools/translate/translate-content.sh "$LANG_CODE" "$SRC" >> "$LOG" 2>&1; then
    echo "RESULT: PASS on attempt $i" | tee -a "$LOG"
    exit 0
  fi
  echo "attempt $i exit=nonzero (retrying)" >> "$LOG"
done
echo "RESULT: FAIL after $MAX attempts" | tee -a "$LOG"
exit 1
