#!/usr/bin/env bash
# Remote container runner for HelixTranslate (installed on thinker.local/amber.local).
# Reads the English source on STDIN, runs the unified-translator inside the
# helixtranslate:cli container, writes ONLY the translated markdown to STDOUT.
# Engine logs go to STDERR. LLM keys come from ~/.helixtranslate.env (mode 600).
#   usage: run.sh <runtime> <provider> <model> <source-lang> <target-lang> <script>
set -euo pipefail
RUNTIME="$1"; PROVIDER="$2"; MODEL="$3"; SL="$4"; TL="$5"; SCRIPT="$6"
ENVF="$HOME/.helixtranslate.env"
[ -f "$ENVF" ] || { echo "missing $ENVF" >&2; exit 90; }
exec "$RUNTIME" run --rm -i --env-file "$ENVF" -v helixtranslate-data:/data --entrypoint sh helixtranslate:cli -c \
  "cat > /tmp/in.md; /usr/local/bin/unified-translator -i /tmp/in.md -o /tmp/out.md \
     -provider $PROVIDER -model $MODEL -source-lang $SL -target-lang $TL -script $SCRIPT 1>&2; \
   cat /tmp/out.md"
