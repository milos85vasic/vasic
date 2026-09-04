#!/usr/bin/env bash
# =============================================================================
# §11.4.76 STATUS — PARTIALLY CONVERTED, and the split is measured, not assumed.
#
# CONVERTED. Which runtime to use is no longer decided here. This file used to
# name the literal `podman` on line 32; that literal was a parallel
# implementation of the first capability §11.4.76(1) makes the Containers
# Submodule authoritative for ("runtime auto-detection"), and §11.4.76(4)
# forbids growing one in a consuming project. The answer now comes from the
# module's own `runtime.AutoDetect`, reached through this repository's single
# consumer module at `_tools/containers` (`cmd/runtime-probe`).
#
# NOT CONVERTED, because the module cannot express it today. The container
# invocation below is a one-shot `run --rm -i` that streams the source document
# on STDIN. Measured at gitlink d940b51fc247c285c805799452992da8d09c75b9:
#
#   * pkg/runtime/runtime.go's ContainerRuntime interface declares Name,
#     Version, IsAvailable, Start, Stop, Remove, Status, List, Stats, Exec and
#     Logs. There is NO Run and no Create — the interface acts on containers
#     that already exist, so there is no ephemeral-run primitive to call.
#   * Exec(ctx, id, cmd []string) accepts no stdin and returns a buffered
#     *ExecResult.
#   * pkg/remote/connection/interface.go:146 declares WithStdin(io.Reader), but
#     that package is interfaces and option builders only: nothing implements
#     its Connection interface and no constructor returns one.
#
# Closing that half is an UPSTREAM change to vasic-digital/containers per
# §11.4.76(4) — an ephemeral-run primitive that accepts stdin — not a rewrite
# here. The exception is declared rather than quietly tolerated, and this file
# was NOT replaced by an unverified Go rewrite: a working script traded for an
# unproven one is a downgrade dressed as compliance.
#
# The same gap is why `_tools/helixtranslate-container.sh` stays as it is; see
# its own header, which measures the remote half of it.
# =============================================================================
# Local drop-in for the HelixTranslate unified-translator: same flags as the
# engine binary, but runs the helixtranslate:cli container LOCALLY through the
# runtime the Containers Submodule detects (no SSH to thinker.local). Reads -i
# input, writes -o output ONLY on success.
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

# ---- Which runtime? The module answers; this script does not guess. --------
# Order, and why each step exists:
#   1. HELIX_RUNTIME — an explicit operator override always wins.
#   2. _tools/containers/cmd/runtime-probe — `runtime.AutoDetect` from the
#      canonical Containers Submodule, reached through this repository's one
#      consumer module. rc 2 there means COULD NOT DETERMINE, and this script
#      propagates that 2 instead of laundering it into a translation failure.
#   3. The former literal `podman` — LAST RESORT ONLY, taken when Go is absent
#      so the probe cannot be built at all. It is kept so that this conversion
#      cannot make a previously-working invocation stop working; it is not a
#      default, and step 2 is expected to answer on any host with a runtime.
RUNTIME="${HELIX_RUNTIME:-}"
if [ -z "$RUNTIME" ]; then
  _HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
  _CMOD="$_HERE/containers"
  _PROBE="$_CMOD/bin/runtime-probe"
  if [ -d "$_CMOD" ] && command -v go >/dev/null 2>&1 \
     && ( cd "$_CMOD" && go build -o "$_PROBE" ./cmd/runtime-probe ) >/dev/null 2>&1; then
    # Built, never `go run`: `go run` collapses every non-zero exit into 1 and
    # would turn the probe's 2 (COULD NOT DETERMINE) into a 1 (real failure).
    if RUNTIME="$("$_PROBE" -name-only 2>/dev/null)" && [ -n "$RUNTIME" ]; then
      :
    else
      echo "helixtranslate-local: COULD NOT DETERMINE a container runtime —" >&2
      echo "  $_PROBE -name-only found none. Install podman or docker, or set" >&2
      echo "  HELIX_RUNTIME=<name> to override." >&2
      exit 2
    fi
  else
    RUNTIME="podman"
    echo "helixtranslate-local: NOTE — the Containers-submodule probe could not be" >&2
    echo "  built (no Go toolchain, or $_CMOD absent); falling back to the former" >&2
    echo "  literal '$RUNTIME'. This is the documented last resort, not a default." >&2
  fi
fi

# Build the inner unified-translator arg string (quoted) from forwarded flags.
INNER=""
for a in "${FWD[@]}"; do INNER="$INNER $(printf '%q' "$a")"; done

TMP_OUT="$(mktemp)"; trap 'rm -f "$TMP_OUT"' EXIT
if "$RUNTIME" run --rm -i --env-file "$ENVF" -v helixtranslate-data:/data --entrypoint sh "$IMAGE" -c \
     "cat > /tmp/in.md; /usr/local/bin/unified-translator -i /tmp/in.md -o /tmp/out.md$INNER 1>&2; \
      cat /tmp/out.md" < "$IN" > "$TMP_OUT" 2>/dev/null && [ -s "$TMP_OUT" ]; then
  mkdir -p "$(dirname "$OUT")"; mv "$TMP_OUT" "$OUT"; exit 0
fi
echo "helixtranslate-local: translation failed (runtime=$RUNTIME image=$IMAGE)" >&2
exit 1
