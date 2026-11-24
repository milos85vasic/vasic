#!/usr/bin/env bash
# Start the OpenDesign daemon headlessly using the app's bundled Electron runtime
# (required: the app's native better-sqlite3 is built for that runtime's ABI, not system node).
# Serves OD_DAEMON_URL=http://127.0.0.1:<port>. Run in the background.
#
# --runner=NAME (the ecosystem-wide launcher flag, docs/RUNNER_FLAG.md) is
# ACCEPTED so every launcher answers the same flag, but this one runs a native
# Electron process and uses NO container, so there is no runner to force: it
# prints "no containers used" and ignores the value. (Only the flag SHAPE is
# checked, so a typo such as a missing value is still an error, exit 2.)
set -euo pipefail
while [ "$#" -gt 0 ]; do
  case "$1" in
    --help|-h) printf 'Usage: start-daemon.sh [--runner=NAME]\n  --runner=NAME  accepted and ignored: this launcher starts a native Electron process and uses no container (docs/RUNNER_FLAG.md)\n  env: OD_PORT (default 4321)\n'; exit 0 ;;
    --runner=?*) echo "start-daemon: --runner=${1#--runner=} ignored: no containers used (native Electron daemon)" >&2; shift ;;
    --runner) [ "$#" -ge 2 ] || { echo "start-daemon: --runner needs a value" >&2; exit 2; }
              echo "start-daemon: --runner=$2 ignored: no containers used (native Electron daemon)" >&2; shift 2 ;;
    --runner=) echo "start-daemon: --runner needs a value" >&2; exit 2 ;;
    *) shift ;;
  esac
done
APP="/Applications/Open Design.app/Contents/MacOS/Open Design"
DC="/Applications/Open Design.app/Contents/Resources/app/prebundled/daemon/daemon-cli.mjs"
PORT="${OD_PORT:-4321}"
if [ ! -x "$APP" ]; then echo "Open Design app not found at: $APP" >&2; exit 1; fi
echo "Starting OpenDesign daemon on http://127.0.0.1:${PORT} ..."
exec env ELECTRON_RUN_AS_NODE=1 "$APP" "$DC" --port "$PORT" --host 127.0.0.1 --no-open
