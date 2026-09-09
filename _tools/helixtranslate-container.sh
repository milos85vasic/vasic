#!/usr/bin/env bash
# =============================================================================
# NOT CONVERTIBLE to the Containers submodule TODAY — measured, not assumed.
#
# This shim is a §11.4.76(4) exception that cannot currently be closed, and the
# reason is a concrete gap in the module rather than a preference for bash.
#
# THE EXCEPTION STANDS, and its REASON IS NARROWED BY MEASUREMENT to the
# REMOTE-stdin gap specifically. One sentence this header used to carry is
# WITHDRAWN BY NAME — it read "Every executed path in
# `digital.vasic.containers` is stdin-less" — and it was TRUE when written, at
# gitlink d940b51fc247c285c805799452992da8d09c75b9. It is FALSE as a general
# statement at the pin this repository consumes today: the LOCAL path gained a
# stdin-capable ephemeral run in 6d13ad03528c (2026-09-04), and
# pkg/runtime.Run + WithRunStdin is exactly that. See
# `_tools/helixtranslate-container/run.sh`, whose exception reason the same
# change WITHDREW.
#
# WHAT IS STILL TRUE — and is now the whole reason — is the REMOTE half.
# The shim STREAMS THE SOURCE DOCUMENT OVER SSH ON STDIN (`< "$IN"`, line ~54),
# and every REMOTE path is still stdin-less. Re-measured 2026-09-09 at gitlink
# 7f5922563d8bec866b1a25eac483590c9a212817:
#
#   remote.RemoteExecutor.Execute(ctx, host, command)        -- no stdin
#   remote.RemoteExecutor.ExecuteStream(ctx, host, command)  -- stdout only
#   remoteexec.SSHRunner.Run / .WriteFile                    -- no stdin
#
#   remote.RemoteRuntime.Run (pkg/remote/runtime.go, ~line 240) EXPLICITLY
#   REFUSES a caller that passes WithRunStdin, returning an error wrapping
#   runtime.ErrStdinUnsupported. Its own comment states the reason: neither
#   Execute nor ExecuteStream accepts an io.Reader, "so there is no seam through
#   which a local document could be streamed to the remote container's standard
#   input". It refuses rather than running the same command with an empty stdin
#   and returning a zero exit that would look exactly like success — record that
#   as good practice, not as an obstacle.
#
# `pkg/remote/connection` DOES declare `WithStdin(io.Reader) ExecuteOption`
# (interface.go:146) — and that package is STILL interfaces and option builders
# ONLY: four files, nothing implementing its `Connection` interface, no
# constructor returning one.
#
# Converting this shim therefore STILL requires an UPSTREAM change (a stdin
# option on RemoteExecutor, or an implementation behind pkg/remote/connection),
# not a rewrite here. Until then this file stays as it is, declared rather than
# quietly tolerated.
#
# The DISTRIBUTION half of this workload has been converted — see
# `_tools/containers/cmd/distribute-helixtranslate` and the superseded-notice
# at the top of `_tools/distribute-helixtranslate.sh`.
# =============================================================================
# helixtranslate-container.sh — engine-compatible shim that runs the
# HelixTranslate unified-translator INSIDE a container on a remote host
# (each fleet host with the runtime declared for it in HT_FLEET), per the mandate that
# HelixTranslate and other infra/services run ONLY via the Containers submodule
# distributed to those hosts. NO local engine binary is invoked.
#
# It accepts the SAME flags the real `unified-translator` binary does, so it is
# a drop-in for translate-pipeline.sh's $ENGINE (HELIX_TRANSLATE_BIN):
#   -i <in> -o <out> -provider <p> -model <m>
#   -source-lang <sl> -target-lang <tl> -script <s>
#
# Host/runtime selection (for round-robin parallelism the driver sets these):
#   HT_HOST     (default: the first host declared in HT_FLEET)
#   HT_RUNTIME  (default: the `:runtime` suffix declared for that host in
#                HT_FLEET, else $HT_DEFAULT_RUNTIME, else podman)
#   HT_SSH_USER (default: $USER)
# NOTHING here names a machine. See _tools/lib/translation-fleet.sh.
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

# Host, runtime and SSH account are RESOLVED, never literal. The shared
# declaration lives in _tools/lib/translation-fleet.sh and comes entirely from
# the environment (HT_FLEET / HT_SSH_USER); this file names no machine.
# shellcheck source=lib/translation-fleet.sh
. "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib/translation-fleet.sh"

HOST="${HT_HOST:-}"
if [ -z "$HOST" ]; then
  HOST="$(ht_build_host)" || exit 2
fi
if [ -n "${HT_RUNTIME:-}" ]; then RUNTIME="$HT_RUNTIME"
else RUNTIME="$(ht_fleet_runtime "$HOST")" || exit 2; fi

USER_AT="$(ht_ssh_target "$HOST")" || exit 2
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
