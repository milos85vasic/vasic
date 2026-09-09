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
# one-shot `run --rm -i` that reads the source document on STDIN.
#
# THE REASON THIS EXCEPTION USED TO GIVE IS WITHDRAWN BY NAME. It was TRUE when
# written, at gitlink d940b51fc247c285c805799452992da8d09c75b9, and it is FALSE
# at the pin this repository consumes today. It read:
#
#   "that shape is NOT expressible through the Containers Submodule today.
#    Measured at gitlink d940b51...:
#      * pkg/runtime's ContainerRuntime interface has NO Run and no Create ...
#      * Exec(ctx, id, cmd []string) accepts no stdin.
#      * The only WithStdin in the module
#        (pkg/remote/connection/interface.go:146) sits in an
#        interfaces-and-options-only package that nothing implements."
#
# Re-measured 2026-09-09 at gitlink 7f5922563d8bec866b1a25eac483590c9a212817:
# the ephemeral-run primitive EXISTS. It landed upstream in 6d13ad03528c
# (2026-09-04), two commits before the current pin.
#
#   * pkg/runtime/runtime.go declares, ON the ContainerRuntime interface,
#       Run(ctx, image string, cmd []string, opts ...RunOption) (*ExecResult, error)
#   * pkg/runtime/run.go and run_test.go exist. WithRunStdin(io.Reader) supplies
#     the document and is what puts `-i` on the argv (run.go:119, run.go:204).
#   * StdinExecutor / ExecuteWithStdin is really implemented, by defaultExecutor
#     on the os/exec path (run.go:53).
#
# THIS FILE RUNS ON THE REMOTE HOST, so from that host's own view the run below
# is a LOCAL run — the remote-stdin gap that still blocks
# `_tools/helixtranslate-container.sh` does NOT apply here. This script is
# therefore CONVERTIBLE IN PRINCIPLE today, via runtime.Run with WithRunStdin /
# WithRunVolumes / WithRunEntrypoint / WithRunExtraArgs.
#
# THE CONVERSION IS DELIBERATELY NOT PERFORMED, and the evidence is the reason.
# Re-measured 2026-09-09 on the development host: `podman images | grep -i
# helixtranslate` matches ZERO rows; `getent hosts` fails to resolve
# thinker.local and amber.local; `ssh -o BatchMode=yes` returns rc 255 for both.
# Absent image, unreachable hosts — that is an rc 2, and a 2 is never a pass. A
# WORKING script must not be traded for a rewrite that cannot be exercised end
# to end. Convertible in principle is not verified in practice.
#
# So what stands here is no longer "we cannot" but "we can, and we have not yet
# proved it" — which is a smaller claim, and an honest one. When an image exists
# and a host answers, convert it and prove it; until then, leave it alone.
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
