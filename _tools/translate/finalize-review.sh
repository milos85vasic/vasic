#!/usr/bin/env bash
# =============================================================================
# finalize-review.sh — end-of-batch pass that brings every language to 38/38.
#
# WHY: the recalibrated reviewer (§11.4.236) fixes the systematic false-FAIL on
# long, term-dense docs (it no longer penalizes correctly-preserved, MANDATORY
# non-translatable glossary terms, and it compares full documents instead of an
# asymmetric 12k-char cut). Any doc reviewed under the OLD standard (11.4.235)
# may carry a stale verdict — a false-FAIL (term-dense doc wrongly failed) OR a
# false-PASS (e.g. a doc the old reviewer passed despite the engine dropping a
# non-translatable term, which the new PROGRAMMATIC term gate correctly fails).
#
# This helper, run AFTER the batch finishes, makes the state consistent:
#   * RE-REVIEW under the current reviewer every doc that is not already
#     (verdict=PASS AND _standard=11.4.236). A stale false-FAIL flips to PASS
#     with NO re-translation (general fix — same reviewer for every language).
#   * RE-TRANSLATE (via the proven driver, which re-reviews) ONLY a doc with a
#     GENUINE defect the new reviewer catches: a non-translatable term the engine
#     dropped (terms_missing non-empty) or prose that honestly scores <4. The
#     driver's fresh translation preserves the term; run again if needed.
#
# Idempotent. Never git commit/push. Skips a language whose batch translator is
# still running (avoids racing the live pipeline).
#
# Usage:
#   finalize-review.sh --status            # audit only, NO API calls, NO writes
#   finalize-review.sh                     # all 14 langs: re-review + heal
#   finalize-review.sh ru sr de            # only these languages
# Env:
#   REVIEW_PROVIDER (cohere) REVIEW_MODEL (command-r-plus-08-2024)
#   RETRANSLATE (1)  MAX_RT (2)  STD (11.4.236)
# =============================================================================
set -uo pipefail
REPO="/Volumes/T7/Projects/vasic"
CONTENT="$REPO/_content"
EVID="$REPO/_tests/evidence/translate-new"
REVIEWER="$REPO/_tools/review_translation.py"
DRIVER="$REPO/_tools/translate/translate-content.sh"
STD="${STD:-11.4.236}"
REVIEW_PROVIDER="${REVIEW_PROVIDER:-cohere}"
REVIEW_MODEL="${REVIEW_MODEL:-command-r-plus-08-2024}"
RETRANSLATE="${RETRANSLATE:-1}"
MAX_RT="${MAX_RT:-2}"
export REVIEW_PROVIDER REVIEW_MODEL   # so the driver re-reviews with the same model

# shellcheck disable=SC1090
[ -f "$HOME/api_keys.sh" ] && source "$HOME/api_keys.sh"

STATUS_ONLY=0
LANGS_ARG=()
for a in "$@"; do
  case "$a" in
    --status) STATUS_ONLY=1 ;;
    -*) echo "unknown flag: $a" >&2; exit 2 ;;
    *) LANGS_ARG+=("$a") ;;
  esac
done
if [ "${#LANGS_ARG[@]}" -gt 0 ]; then
  LANGS="${LANGS_ARG[*]}"
else
  LANGS="${LANGS:-ru sr de es fr be zh kk hi ja ko ar tr fa}"
fi

mapfile -t DOCS < <(find "$CONTENT/products" "$CONTENT/sites" "$CONTENT/docs" -type f -name '*.md' | sort)
NDOCS=${#DOCS[@]}

# current-PASS := verdict PASS, standard == STD, and translated file present.
is_current_pass() {
  python3 - "$1" "$STD" <<'PY'
import json,sys,os
try: d=json.load(open(sys.argv[1]))
except Exception: sys.exit(1)
tf=d.get("_translated","")
sys.exit(0 if (d.get("verdict")=="PASS" and str(d.get("_standard"))==sys.argv[2]
               and tf and os.path.isfile(tf)) else 1)
PY
}
jverdict() { python3 -c 'import json,sys;print(json.load(open(sys.argv[1])).get("verdict","NONE"))' "$1" 2>/dev/null || echo NONE; }
jmissing() { python3 -c 'import json,sys;print(len(json.load(open(sys.argv[1])).get("terms_missing",[])))' "$1" 2>/dev/null || echo 0; }

echo "finalize-review: langs=[$LANGS] docs=$NDOCS std=$STD reviewer=$REVIEW_PROVIDER/$REVIEW_MODEL status_only=$STATUS_ONLY"
for lang in $LANGS; do
  ev="$EVID/$lang"
  if [ "$STATUS_ONLY" = 1 ]; then
    cur=0; miss=0; stale=0; noout=0
    for src in "${DOCS[@]}"; do
      rel="${src#"$CONTENT"/}"; out="$REPO/_content_$lang/$rel"
      rj="$ev/$(echo "$rel" | tr '/' '_').review.json"
      [ -f "$out" ] || { noout=$((noout+1)); }
      if is_current_pass "$rj"; then cur=$((cur+1)); continue; fi
      [ -f "$rj" ] || { miss=$((miss+1)); continue; }
      if [ "$(jverdict "$rj")" = "PASS" ]; then stale=$((stale+1)); else miss=$((miss+1)); fi
    done
    printf "  %-3s current_PASS=%2d/%d  stale_PASS(need recheck)=%d  need_action=%d  missing_translation=%d\n" \
      "$lang" "$cur" "$NDOCS" "$stale" "$miss" "$noout"
    continue
  fi

  if pgrep -f "translate-content.sh $lang " >/dev/null 2>&1; then
    echo "[$lang] SKIP — batch still translating this language"; continue
  fi
  mkdir -p "$ev"
  pass=0; fail=0; retr=0
  for src in "${DOCS[@]}"; do
    rel="${src#"$CONTENT"/}"; out="$REPO/_content_$lang/$rel"
    rj="$ev/$(echo "$rel" | tr '/' '_').review.json"
    if is_current_pass "$rj"; then pass=$((pass+1)); continue; fi
    if [ ! -f "$out" ]; then
      echo "[$lang] TRANSLATE (missing) $rel"
      bash "$DRIVER" "$lang" "$src" >/dev/null 2>&1
    else
      # Cheap first: re-review the EXISTING translation under the new reviewer.
      python3 "$REVIEWER" --src "$src" --translated "$out" --lang "$lang" --article \
        --provider "$REVIEW_PROVIDER" --model "$REVIEW_MODEL" --out "$rj" >/dev/null 2>&1
    fi
    v="$(jverdict "$rj")"
    n=0
    while [ "$v" != "PASS" ] && [ "$RETRANSLATE" = 1 ] && [ "$n" -lt "$MAX_RT" ]; do
      n=$((n+1)); retr=$((retr+1))
      echo "[$lang] RE-TRANSLATE $rel (attempt $n; verdict=$v missing_terms=$(jmissing "$rj"))"
      bash "$DRIVER" "$lang" "$src" >/dev/null 2>&1   # driver re-reviews with the new reviewer
      v="$(jverdict "$rj")"
    done
    if [ "$v" = "PASS" ]; then pass=$((pass+1)); else fail=$((fail+1)); echo "[$lang] STILL FAIL $rel (verdict=$v)"; fi
  done
  echo "[$lang] FINAL PASS=$pass FAIL=$fail of $NDOCS  (re-translated $retr)"
  printf '%s\tPASS=%s\tFAIL=%s\tTOTAL=%s\n' "$lang" "$pass" "$fail" "$NDOCS" > "$ev/FINALIZE_SUMMARY.txt"
done
echo "finalize-review: done"
