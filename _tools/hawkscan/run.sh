#!/usr/bin/env bash
# run.sh — local HawkScan runner. Never blocks other work: if no HAWK_API_KEY
# is configured (or the applicationId placeholder hasn't been replaced), this
# prints a clear, loud warning and exits 0 — a missing third-party credential
# is an operator setup gap, not a build failure.
#
# Usage: _tools/hawkscan/run.sh [--target <base-url>]
set -uo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TARGET=""

while [ $# -gt 0 ]; do
    case "$1" in
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

if ! command -v podman >/dev/null 2>&1 && ! command -v docker >/dev/null 2>&1; then
    warn_and_skip "neither podman nor docker is available on this host."
fi

RUNTIME="podman"
command -v podman >/dev/null 2>&1 || RUNTIME="docker"

EXTRA_ARGS=()
if [ -n "$TARGET" ]; then
    EXTRA_ARGS+=(-e "app.host=$TARGET")
fi

echo "== running HawkScan via $RUNTIME against ${TARGET:-the config's default host} =="
"$RUNTIME" run --rm \
    --network host \
    -e "HAWK_API_KEY=${HAWK_API_KEY}" \
    -v "$HERE/stackhawk.yml:/hawk/stackhawk.yml:ro" \
    docker.io/stackhawk/hawkscan:latest \
    "${EXTRA_ARGS[@]}"
