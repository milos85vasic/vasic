#!/usr/bin/env bash
# run.sh — local HawkScan runner. Never blocks other work: if no HAWK_API_KEY
# is configured (or the applicationId placeholder hasn't been replaced), this
# prints a clear, loud warning and exits 0 — a missing third-party credential
# is an operator setup gap, not a build failure.
#
# Usage: _tools/hawkscan/run.sh [--target <base-url>] [--runner=NAME]
#
#   --runner=NAME   FORCE the container runner (podman|docker|nerdctl|auto; the
#                   supported list comes from the Containers Submodule, see
#                   docs/RUNNER_FLAG.md). flag > $CONTAINERS_RUNNER > default
#                   order. An unknown or not-installed runner exits 2 (not the
#                   "skipped" exit 0): the operator asked for something specific.
#                   Without it the Containers Submodule picks the runtime (it
#                   replaced this script's hand-rolled `podman else docker`).
set -uo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../lib/vasic-runner.sh"
vasic_runner_maybe "$@" || exit 2
set -- "${VASIC_ARGS[@]+"${VASIC_ARGS[@]}"}"
TARGET=""

while [ $# -gt 0 ]; do
    case "$1" in
        --help|-h) printf 'Usage: _tools/hawkscan/run.sh [--target <base-url>] [--runner=NAME]\n%s\n' '  Container runner: --runner=NAME (or --runner NAME, or env CONTAINERS_RUNNER; flag wins; unknown or not-installed runner exit 2, no fallback). See docs/RUNNER_FLAG.md.'; exit 0 ;;
        --target) TARGET="$2"; shift 2 ;;
        *) echo "unknown argument: $1" >&2; exit 2 ;;
    esac
done

warn_and_skip() {
    cat >&2 <<EOF

⚠️  HawkScan SKIPPED — $1

    This does NOT block your work. HawkScan is a third-party DAST scanner
    (StackHawk) requiring an account and API key this host does not have
    configured. See _tools/hawkscan/README.md for setup steps.

EOF
    exit 0
}

if [ -z "${HAWK_API_KEY:-}" ]; then
    warn_and_skip "HAWK_API_KEY is not set in the environment."
fi

if grep -q "REPLACE_WITH_REAL_STACKHAWK_APPLICATION_ID" "$HERE/stackhawk.yml"; then
    warn_and_skip "stackhawk.yml still has the placeholder applicationId — create a real Application at app.stackhawk.com first."
fi

# Which runtime? A forced runner (flag/env) was validated above and is strict.
# With none forced, prefer the Containers Submodule's selection and, when it
# cannot answer (no Go toolchain / no cached runner binary), fall back to the
# host's own podman-else-docker so the scan still runs where it always did.
CHOSEN="${CONTAINERS_RUNNER_CHOSEN:-}"
if [ -z "$CHOSEN" ]; then
    if vasic_runner_load 2>/dev/null && runner_parse_args && runner_select 2>/dev/null; then
        CHOSEN="$CONTAINERS_RUNNER_CHOSEN"
    elif command -v podman >/dev/null 2>&1; then CHOSEN="podman"
    elif command -v docker >/dev/null 2>&1; then CHOSEN="docker"
    else warn_and_skip "neither podman nor docker is available on this host."; fi
fi
RUNTIME="$CHOSEN"
case "$RUNTIME" in
    podman|docker|nerdctl) ;;
    *) echo "hawkscan: runner '$RUNTIME' cannot 'run --rm' an image (use podman, docker or nerdctl)" >&2; exit 2 ;;
esac

EXTRA_ARGS=()
if [ -n "$TARGET" ]; then
    EXTRA_ARGS+=(-e "app.host=$TARGET")
fi

echo "== running HawkScan via $RUNTIME against ${TARGET:-the config default host} =="
"$RUNTIME" run --rm \
    --network host \
    -e "HAWK_API_KEY=${HAWK_API_KEY}" \
    -v "$HERE/stackhawk.yml:/hawk/stackhawk.yml:ro" \
    docker.io/stackhawk/hawkscan:latest \
    "${EXTRA_ARGS[@]}"
