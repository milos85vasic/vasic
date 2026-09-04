#!/usr/bin/env bash
# =============================================================================
# NOT CONVERTIBLE to the Containers submodule TODAY — measured, not assumed.
#
# This shim is a §11.4.76(4) exception that cannot currently be closed, and the
# reason is a concrete gap in the module rather than a preference for bash.
#
# The shim STREAMS THE SOURCE DOCUMENT OVER SSH ON STDIN (`< "$IN"`, line ~54).
# Every executed path in `digital.vasic.containers` is stdin-less:
#
#   remote.RemoteExecutor.Execute(ctx, host, command)        -- no stdin
#   remote.RemoteExecutor.ExecuteStream(ctx, host, command)  -- stdout only
#   remoteexec.SSHRunner.Run / .WriteFile                    -- no stdin
#
# `pkg/remote/connection` DOES declare `WithStdin(io.Reader) ExecuteOption`
# (interface.go:146) — but that package is interfaces and option builders ONLY.
# Nothing in the module implements its `Connection` interface and nothing
# imports it; there is no constructor that returns one. Verified at gitlink
# d940b51fc247c285c805799452992da8d09c75b9.
#
# Converting this shim therefore requires an UPSTREAM change (a stdin option on
# RemoteExecutor, or an implementation behind pkg/remote/connection), not a
# rewrite here. Until then this file stays as it is, declared rather than
# quietly tolerated.
#
# The DISTRIBUTION half of this workload has been converted — see
# `_tools/containers/cmd/distribute-helixtranslate` and the superseded-notice
# at the top of `_tools/distribute-helixtranslate.sh`.
# =============================================================================
# helixtranslate-container.sh — engine-compatible shim that runs the
# HelixTranslate unified-translator INSIDE a container on a remote host
# (thinker.local via podman, amber.local via docker), per the mandate that
# HelixTranslate and other infra/services run ONLY via the Containers submodule
# distributed to those hosts. NO local engine binary is invoked.
#
# It accepts the SAME flags the real `unified-translator` binary does, so it is
# a drop-in for translate-pipeline.sh's $ENGINE (HELIX_TRANSLATE_BIN):
#   -i <in> -o <out> -provider <p> -model <m>
#   -source-lang <sl> -target-lang <tl> -script <s>
#
# Host/runtime selection (for round-robin parallelism the driver sets these):
#   HT_HOST     (default thinker.local)
#   HT_RUNTIME  (default: podman for thinker.local, docker for amber.local)
#
# The remote ~/helixtranslate-img/run.sh streams the source over SSH stdin into
# the container and returns ONLY the translated markdown on stdout. The output
# file is written atomically and ONLY on success (empty/failed runs leave it
# absent) so the pipeline's `[ -s out ]` success check stays meaningful.
# =============================================================================
set -euo pipefail

IN="" OUT="" PROVIDER="" MODEL="" SL="en" TL="" SCRIPT="cyrillic"
while [ $# -gt 0 ]; do
  case "$1" in
    -i|-input)        IN="$2"; shift 2 ;;
    -o|-output)       OUT="$2"; shift 2 ;;
    -provider)        PROVIDER="$2"; shift 2 ;;
    -model)           MODEL="$2"; shift 2 ;;
    -source-lang)     SL="$2"; shift 2 ;;
    -target-lang)     TL="$2"; shift 2 ;;
    -script)          SCRIPT="$2"; shift 2 ;;
    -api-key|-base-url|-chunk-size|-concurrency) shift 2 ;;  # ignored here
    *) echo "helixtranslate-container: unknown arg: $1" >&2; exit 2 ;;
  esac
done
[ -n "$IN" ] && [ -f "$IN" ] || { echo "container shim: input missing: $IN" >&2; exit 2; }
[ -n "$OUT" ] || { echo "container shim: -o required" >&2; exit 2; }
[ -n "$PROVIDER" ] && [ -n "$MODEL" ] && [ -n "$TL" ] || { echo "container shim: provider/model/target-lang required" >&2; exit 2; }

HOST="${HT_HOST:-thinker.local}"
if [ -n "${HT_RUNTIME:-}" ]; then RUNTIME="$HT_RUNTIME"
elif [ "$HOST" = "amber.local" ]; then RUNTIME="docker"
else RUNTIME="podman"; fi

USER_AT="milosvasic@${HOST}"
TMP_OUT="$(mktemp)"; trap 'rm -f "$TMP_OUT"' EXIT

# Stream source -> remote container -> translated markdown on stdout.
if ssh -o BatchMode=yes "$USER_AT" \
      "bash ~/helixtranslate-img/run.sh $RUNTIME $PROVIDER $MODEL $SL $TL $SCRIPT" \
      < "$IN" > "$TMP_OUT" 2>/dev/null && [ -s "$TMP_OUT" ]; then
  mkdir -p "$(dirname "$OUT")"
  mv "$TMP_OUT" "$OUT"
  exit 0
fi
echo "container shim: remote translation failed on $HOST ($RUNTIME) provider=$PROVIDER" >&2
exit 1
