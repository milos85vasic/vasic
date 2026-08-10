#!/usr/bin/env bash
# =============================================================================
# translate-content.sh <lang> [<file.md> ...]
#
# Committed, constitution-compliant content translation utility.
#
#   §11.4.140  ALL translation goes through the HelixTranslate engine. No silent
#              fallback, no hand-translation: engine error => FAIL LOUD.
#   §11.4.141  Every output is independently reviewed by a DIFFERENT model than
#              the one that produced it (translator=mistral/mistral-large-latest,
#              reviewer=groq/llama-3.3-70b-versatile) via review_translation.py.
#   Mandates:  cutting-edge professional quality (strong general LLM, not
#              codestral), technology-vocabulary aware, NON-TRANSLATABLE terms
#              preserved verbatim (glossary sentinels).
#
# Per file:
#   1. Split YAML frontmatter (kept BYTE-IDENTICAL) from the body. The body may
#      itself contain '---' horizontal rules, so the split keys off the FIRST
#      two fences only and treats everything after as body.
#   2. PROTECT every glossary term in the body with a unique Z9TERM<NNN>Z9
#      sentinel (glossary_protect.py protect) that survives translation.
#   3. Translate the protected body en->LANG with HelixTranslate, in paragraph
#      chunks. (The engine truncates a single request whose output exceeds
#      ~6.5k chars; chunking on blank-line boundaries well under that cliff
#      guarantees complete output. Sentinels are within lines, never split.)
#   4. RESTORE sentinels -> original terms (glossary_protect.py restore).
#   5. Strip any leading translator "Contents" artifact; reassemble
#      original-frontmatter + translated-body. Guard: translated body must not
#      be grossly shorter than source (catches any residual truncation).
#   6. Write to _content_<LANG>/<same relative path>.
#   7. INDEPENDENT review (different provider/model); emit PASS/FAIL JSON.
#
# Usage:
#   translate-content.sh de                       # all _content/**/*.md
#   translate-content.sh de _content/docs/cv.md   # specific file(s)
#
# Env overrides:
#   TRANSLATOR_PROVIDER (mistral) TRANSLATOR_MODEL (mistral-large-latest)
#   REVIEW_PROVIDER (groq)        REVIEW_MODEL (llama-3.3-70b-versatile)
#   CONTENT_DIR (_content)        OUT_ROOT (_content_<lang>)
#   HELIX_BIN (_tools/helixtranslate-container.sh — repo-relative)  MAXCHARS (3000)
#
# Exit: 0 iff every file translated AND every review verdict == PASS.
# =============================================================================
set -euo pipefail

# Repo root is DERIVED from this script's own location (…/_tools/translate/…),
# never hardcoded, so every path below reproduces from a clean clone (§11.4.77).
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$SELF_DIR/../.." && pwd)"
TOOLS="$REPO/_tools"
TDIR="$TOOLS/translate"
GLOSSARY="$TDIR/glossary.json"
PROTECT="$TDIR/glossary_protect.py"
REVIEWER="$TOOLS/review_translation.py"
# HelixTranslate engine: default to the REPO-RELATIVE engine entrypoint produced
# by the committed container recipe (_tools/distribute-helixtranslate.sh builds
# the helixtranslate:cli image + installs the runner; _tools/helixtranslate-
# container.sh is the committed drop-in shim). NEVER an ephemeral /tmp path
# (§11.4.77). Override with HELIX_BIN=<path> if you have a local engine binary.
HELIX_BIN="${HELIX_BIN:-$TOOLS/helixtranslate-container.sh}"
CONTENT_DIR="${CONTENT_DIR:-$REPO/_content}"
MAXCHARS="${MAXCHARS:-3000}"

TRANSLATOR_PROVIDER="${TRANSLATOR_PROVIDER:-mistral}"
TRANSLATOR_MODEL="${TRANSLATOR_MODEL:-mistral-large-latest}"
ENGINE_RETRIES="${ENGINE_RETRIES:-6}"   # transient (429/5xx) retries per chunk before FAIL LOUD
REVIEW_PROVIDER="${REVIEW_PROVIDER:-groq}"
REVIEW_MODEL="${REVIEW_MODEL:-llama-3.3-70b-versatile}"

# ---- API keys ---------------------------------------------------------------
# shellcheck disable=SC1090
[ -f "$HOME/api_keys.sh" ] && source "$HOME/api_keys.sh"

die() { echo "FATAL: $*" >&2; exit 1; }

[ $# -ge 1 ] || die "usage: translate-content.sh <lang> [file.md ...]"
LANG_CODE="$1"; shift
[ -x "$HELIX_BIN" ] || die "HelixTranslate engine not found/executable: $HELIX_BIN
  The engine is produced by the committed container recipe — build & distribute it first:
      bash $TOOLS/distribute-helixtranslate.sh
  (or set HELIX_BIN=<path-to-engine>). No silent fallback, no hand-translation (§11.4.140)."
[ -f "$GLOSSARY" ] || die "glossary not found: $GLOSSARY"
: "${MISTRAL_API_KEY:?MISTRAL_API_KEY missing (source ~/api_keys.sh)}"

OUT_ROOT="${OUT_ROOT:-$REPO/_content_${LANG_CODE}}"
EVID_ROOT="${EVID_ROOT:-$REPO/_tests/evidence/translate-new/${LANG_CODE}}"
mkdir -p "$OUT_ROOT" "$EVID_ROOT"

# ---- language -> script (mirrors translate-pipeline.sh) ---------------------
case "$LANG_CODE" in
  ru|be|kk|bg|mk|sr_cyrl) SCRIPT="cyrillic" ;;
  ar|fa)                  SCRIPT="arabic" ;;
  zh|ja|ko|hi)            SCRIPT="default" ;;
  *)                      SCRIPT="latin" ;;   # de, es, fr, tr, sr(latin), ...
esac

# ---- file list --------------------------------------------------------------
FILES=()
if [ $# -gt 0 ]; then
  FILES=("$@")
else
  while IFS= read -r f; do FILES+=("$f"); done < <(find "$CONTENT_DIR" -type f -name '*.md' | sort)
fi
[ ${#FILES[@]} -gt 0 ] || die "no input files"

# Strip a leading standalone translator "Contents" artifact (localized word the
# engine occasionally prepends) if present at the very top of the body.
strip_artifact() {
  awk '
    BEGIN{done=0}
    done==0 && /^[[:space:]]*$/ { next }
    done==0 && ($0=="Contents"||$0=="Inhalt"||$0=="Inhaltsverzeichnis"||$0=="Содержание"||$0=="Sadržaj"||$0=="Sadrzaj"||$0=="Table des matières"||$0=="Contenido") { done=1; next }
    { done=1; print }
  ' "$1" > "$1.sa" && mv "$1.sa" "$1"
}

OVERALL_RC=0
SUMMARY="$EVID_ROOT/summary.tsv"
: > "$SUMMARY"
printf 'file\tstatus\tverdict\taccuracy\tfluency\tcompleteness\tscript_ok\tuntranslated_leftovers\n' >> "$SUMMARY"

jget() { python3 -c 'import json,sys;print(json.load(open(sys.argv[1])).get(sys.argv[2],""))' "$1" "$2" 2>/dev/null || echo ""; }

for SRC in "${FILES[@]}"; do
  [ -f "$SRC" ] || die "input not found: $SRC"
  # Resolve REL relative to CONTENT_DIR, robust to relative vs absolute inputs,
  # so the output mirrors the SAME relative path under _content_<lang>/.
  ABS_SRC="$(cd "$(dirname "$SRC")" && pwd)/$(basename "$SRC")"
  ABS_CONTENT="$(cd "$CONTENT_DIR" && pwd)"
  case "$ABS_SRC" in
    "$ABS_CONTENT"/*) REL="${ABS_SRC#"$ABS_CONTENT"/}" ;;
    *)                REL="$(basename "$SRC")" ;;
  esac
  OUT="$OUT_ROOT/$REL"
  echo "=============================================================="
  echo ">>> $REL  (en -> $LANG_CODE, script=$SCRIPT)"
  mkdir -p "$(dirname "$OUT")"

  WORK="$(mktemp -d)"

  # 1. Split frontmatter (byte-identical) + body. Body keeps its own '---' HRs.
  if [ "$(head -1 "$SRC")" = "---" ]; then
    awk 'NR==1{print;f=1;next} f==1{print; if($0=="---"){exit}}' "$SRC" > "$WORK/front.md"
    awk 'BEGIN{fence=0}{if(!body){if($0 ~ /^---[[:space:]]*$/){fence++; if(fence==2)body=1}; next} print}' "$SRC" > "$WORK/body.md"
    HAS_FRONT=1
  else
    cp "$SRC" "$WORK/body.md"; : > "$WORK/front.md"; HAS_FRONT=0
  fi
  [ -s "$WORK/body.md" ] || die "empty body for $SRC"
  BODY_SRC_CHARS=$(wc -c < "$WORK/body.md")

  # 2. Protect glossary terms.
  python3 "$PROTECT" protect --glossary "$GLOSSARY" --map "$WORK/map.json" \
      < "$WORK/body.md" > "$WORK/body.protected.md"

  # 3. Translate protected body in paragraph chunks (<= MAXCHARS). FAIL LOUD.
  echo "--- HelixTranslate: provider=$TRANSLATOR_PROVIDER model=$TRANSLATOR_MODEL (chunked <= ${MAXCHARS} chars)"
  rm -f "$WORK"/chunk_*.md
  NCHUNKS=$(awk -v max="$MAXCHARS" -v pre="$WORK/chunk_" '
    BEGIN{idx=0; sz=0}
    { buf[idx]=buf[idx] $0 "\n"; sz+=length($0)+1
      if ($0 ~ /^[[:space:]]*$/ && sz>=max){ idx++; sz=0 } }
    END{ n=0; for(i=0;i<=idx;i++){ if(length(buf[i])>0){ f=sprintf("%s%03d.md", pre, n); printf "%s", buf[i] > f; close(f); n++ } } print n }
  ' "$WORK/body.protected.md")
  : > "$WORK/body.translated.md"
  ci=0
  for cf in "$WORK"/chunk_*.md; do
    ci=$((ci+1))
    inb=$(wc -c < "$cf")
    cout="${cf%.md}.tr.md"   # output MUST end in a format the engine recognizes (.md)
    echo "    chunk $ci/$NCHUNKS ($inb chars)"
    # Same engine, same provider — retried on TRANSIENT failures (rate-limit 429 /
    # 5xx / timeout) with exponential backoff. This is NOT a fallback and NOT a
    # hand-translation: §11.4.140 stays satisfied (only HelixTranslate produces
    # the text). Only a hard, non-transient exhaustion FAILs LOUD.
    attempt=0; ok=0
    while [ "$attempt" -le "$ENGINE_RETRIES" ]; do
      attempt=$((attempt+1))
      rm -f "$cout"
      if "$HELIX_BIN" -i "$cf" -o "$cout" \
            -provider "$TRANSLATOR_PROVIDER" -model "$TRANSLATOR_MODEL" -api-key "$MISTRAL_API_KEY" \
            -source-lang en -target-lang "$LANG_CODE" -script "$SCRIPT" -verify=false -timeout 120s \
            >> "$WORK/engine.log" 2>&1 && [ -s "$cout" ]; then
        ok=1; break
      fi
      # Backoff before retrying (5s, 12s, 24s, 40s, 60s, 60s ...); jittered.
      back=$(( attempt*attempt*5 )); [ "$back" -gt 60 ] && back=60
      echo "      chunk $ci attempt $attempt/$((ENGINE_RETRIES+1)) failed (likely rate-limit); backoff ${back}s" >&2
      sleep $(( back + (RANDOM % 5) ))
    done
    if [ "$ok" != 1 ]; then
      tail -25 "$WORK/engine.log" >&2
      die "HelixTranslate FAILED for $REL chunk $ci after $((ENGINE_RETRIES+1)) attempts (no fallback, no hand-translation)"
    fi
    outb=$(wc -c < "$cout")
    if [ "$outb" -lt $(( inb / 2 )) ]; then
      echo "chunk $ci suspiciously short: in=$inb out=$outb" >&2
      die "HelixTranslate truncated chunk $ci of $REL (in=$inb out=$outb)"
    fi
    # The engine occasionally prepends a localized standalone "Contents" word
    # (de: "Inhalt") to a chunk; strip it per-chunk so it never lands mid-body.
    strip_artifact "$cout"
    cat "$cout" >> "$WORK/body.translated.md"
    printf '\n' >> "$WORK/body.translated.md"
  done
  [ -s "$WORK/body.translated.md" ] || die "empty translation for $REL"

  # 4. Restore sentinels -> original terms. FAIL LOUD on leftover/unknown.
  python3 "$PROTECT" restore --map "$WORK/map.json" \
      < "$WORK/body.translated.md" > "$WORK/body.restored.md"

  # 5. Strip leading artifact; whole-body completeness guard; reassemble.
  strip_artifact "$WORK/body.restored.md"
  BODY_OUT_CHARS=$(wc -c < "$WORK/body.restored.md")
  if [ "$BODY_OUT_CHARS" -lt $(( BODY_SRC_CHARS * 7 / 10 )) ]; then
    die "translated body for $REL too short (src=$BODY_SRC_CHARS out=$BODY_OUT_CHARS) — likely engine truncation"
  fi
  if [ "$HAS_FRONT" = 1 ]; then
    { cat "$WORK/front.md"; echo; cat "$WORK/body.restored.md"; } > "$OUT"
  else
    cp "$WORK/body.restored.md" "$OUT"
  fi
  echo "--- wrote $OUT ($(wc -c < "$OUT") bytes; body src=$BODY_SRC_CHARS out=$BODY_OUT_CHARS)"

  # 6. Independent review (§11.4.141) — DIFFERENT provider/model than translator.
  REVJSON="$EVID_ROOT/$(echo "$REL" | tr '/' '_').review.json"
  echo "--- review: provider=$REVIEW_PROVIDER model=$REVIEW_MODEL (translator was $TRANSLATOR_PROVIDER)"
  set +e
  REVIEW_PROVIDER="$REVIEW_PROVIDER" REVIEW_MODEL="$REVIEW_MODEL" \
    python3 "$REVIEWER" --src "$SRC" --translated "$OUT" --lang "$LANG_CODE" --article \
      --provider "$REVIEW_PROVIDER" --model "$REVIEW_MODEL" --out "$REVJSON"
  RRC=$?
  set -e
  VERDICT="$(jget "$REVJSON" verdict)"; [ -n "$VERDICT" ] || VERDICT=ERROR
  ACC="$(jget "$REVJSON" accuracy)"; FLU="$(jget "$REVJSON" fluency)"; CMP="$(jget "$REVJSON" completeness)"
  SOK="$(jget "$REVJSON" script_ok)"; LEFT="$(jget "$REVJSON" untranslated_leftovers)"
  echo "--- verdict=$VERDICT (rc=$RRC)  acc=$ACC flu=$FLU comp=$CMP script_ok=$SOK leftovers=$LEFT"
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$REL" "written" "$VERDICT" "$ACC" "$FLU" "$CMP" "$SOK" "$LEFT" >> "$SUMMARY"
  [ "$VERDICT" = "PASS" ] || OVERALL_RC=1

  rm -rf "$WORK"
done

echo "=============================================================="
echo "Summary ($SUMMARY):"; cat "$SUMMARY"
[ "$OVERALL_RC" = 0 ] && echo "ALL PASS" || echo "SOME FILES DID NOT PASS"
exit "$OVERALL_RC"
