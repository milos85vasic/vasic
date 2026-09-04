#!/usr/bin/env bash
# =============================================================================
# §11.4.76 STATUS — DECLARED EXCEPTION, not an oversight. Read before "fixing".
#
# This file is INSTALLED ON A REMOTE HOST and executed there, outside this
# repository's checkout: `_tools/distribute-helixtranslate.sh` (and its
# converted replacement `_tools/containers/cmd/distribute-helixtranslate`) copy
# it to ~/helixtranslate-img/run.sh on thinker.local / amber.local. It therefore
# cannot import a Go module that lives here.
#
# It does not detect a runtime — line 11 uses whichever runtime its caller
# passes as $1, so it reimplements no detection primitive. What it does do is a
# one-shot `run --rm -i` that reads the source document on STDIN, and that shape
# is NOT expressible through the Containers Submodule today. Measured at gitlink
# d940b51fc247c285c805799452992da8d09c75b9:
#   * pkg/runtime's ContainerRuntime interface has NO Run and no Create — it
#     declares Name/Version/IsAvailable/Start/Stop/Remove/Status/List/Stats/
#     Exec/Logs, all of which act on a container that already exists.
#   * Exec(ctx, id, cmd []string) accepts no stdin.
#   * The only WithStdin in the module (pkg/remote/connection/interface.go:146)
#     sits in an interfaces-and-options-only package that nothing implements.
#
# Closing this is an UPSTREAM change per §11.4.76(4) — an ephemeral-run
# primitive that accepts stdin — not a rewrite here. The same gap is recorded
# in `_tools/helixtranslate-local.sh` and `_tools/helixtranslate-container.sh`.
# =============================================================================
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
