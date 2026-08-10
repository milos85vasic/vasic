#!/usr/bin/env bash
# Local drop-in for the HelixTranslate unified-translator: same flags as the
# engine binary, but runs the helixtranslate:cli container LOCALLY via podman
# (no SSH to thinker.local). Reads -i input, writes -o output ONLY on success.
# Tolerant of extra engine flags (-api-key/-timeout/-verify[=x]) and forwards
# the translate flags into the container. LLM keys come from the env-file.
set -euo pipefail
IN="" OUT=""
FWD=()   # forwarded engine flags (provider/model/langs/script/api-key/timeout/verify)
while [ $# -gt 0 ]; do
  case "$1" in
    -i|-input)  IN="$2"; shift 2 ;;
    -o|-output) OUT="$2"; shift 2 ;;
    -provider|-model|-source-lang|-target-lang|-script|-api-key|-base-url|-timeout|-chunk-size|-concurrency)
                FWD+=("$1" "$2"); shift 2 ;;
    -verify=*|--verify=*) FWD+=("$1"); shift ;;
    -verify|--verify)     FWD+=("$1" "$2"); shift 2 ;;
    *) echo "helixtranslate-local: unknown arg: $1" >&2; exit 2 ;;
  esac
done
[ -n "$IN" ] && [ -f "$IN" ] || { echo "input missing: $IN" >&2; exit 2; }
[ -n "$OUT" ] || { echo "-o required" >&2; exit 2; }
ENVF="${HELIX_ENVFILE:-$HOME/.helixtranslate.env}"
[ -f "$ENVF" ] || { echo "missing env file $ENVF" >&2; exit 90; }
IMAGE="${HELIX_IMAGE:-helixtranslate:cli}"

# Build the inner unified-translator arg string (quoted) from forwarded flags.
INNER=""
for a in "${FWD[@]}"; do INNER="$INNER $(printf '%q' "$a")"; done

TMP_OUT="$(mktemp)"; trap 'rm -f "$TMP_OUT"' EXIT
if podman run --rm -i --env-file "$ENVF" -v helixtranslate-data:/data --entrypoint sh "$IMAGE" -c \
     "cat > /tmp/in.md; /usr/local/bin/unified-translator -i /tmp/in.md -o /tmp/out.md$INNER 1>&2; \
      cat /tmp/out.md" < "$IN" > "$TMP_OUT" 2>/dev/null && [ -s "$TMP_OUT" ]; then
  mkdir -p "$(dirname "$OUT")"; mv "$TMP_OUT" "$OUT"; exit 0
fi
echo "helixtranslate-local: translation failed" >&2
exit 1
