#!/usr/bin/env bash
# Start the OpenDesign daemon headlessly using the app's bundled Electron runtime
# (required: the app's native better-sqlite3 is built for that runtime's ABI, not system node).
# Serves OD_DAEMON_URL=http://127.0.0.1:<port>. Run in the background.
#
# --runner=NAME (the ecosystem-wide launcher flag, docs/RUNNER_FLAG.md) is part of
# the contract every launcher honours. This one runs a native Electron process and
# uses NO container, so the runner is VALIDATED but not used: an unknown or
# malformed name is refused (rc 2); when the Go toolchain and the Containers module
# are reachable a NOT-INSTALLED runner is refused too (rc 2, no fallback) -- exactly
# as ai_interviewing's native launchers do. Without Go only the shape and (when the
# module's runner binary is cached) the membership are checked. Accepted ->
# "runner: NAME (no containers used by this launcher)". --help/-h: usage, rc 0.
set -euo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
. "$HERE/../lib/vasic-runner.sh"
for _a in "$@"; do
  case "$_a" in
    --) break ;;
    -h|--help)
      printf 'Usage: start-daemon.sh [--runner=NAME | --runner NAME]   (env: OD_PORT, CONTAINERS_RUNNER)\n'
      vasic_runner_usage
      printf '  This launcher runs a native Electron daemon: no containers are used; the runner is validated only.\n'
      exit 0 ;;
  esac
done
vasic_runner_strip "$@" || exit 2
if [ "$VASIC_RUNNER_ASKED" = 1 ]; then
  if command -v go >/dev/null 2>&1 && vasic_runner_load 2>/dev/null; then
    vasic_runner_maybe "$@" || exit 2
    echo "start-daemon: runner: ${CONTAINERS_RUNNER_CHOSEN:-auto} (no containers used by this launcher)" >&2
  else
    echo "start-daemon: runner validated by shape only (no Go toolchain / Containers module): no containers used by this launcher" >&2
  fi
fi
APP="/Applications/Open Design.app/Contents/MacOS/Open Design"
DC="/Applications/Open Design.app/Contents/Resources/app/prebundled/daemon/daemon-cli.mjs"
PORT="${OD_PORT:-4321}"
if [ ! -x "$APP" ]; then echo "Open Design app not found at: $APP" >&2; exit 1; fi
echo "Starting OpenDesign daemon on http://127.0.0.1:${PORT} ..."
exec env ELECTRON_RUN_AS_NODE=1 "$APP" "$DC" --port "$PORT" --host 127.0.0.1 --no-open
