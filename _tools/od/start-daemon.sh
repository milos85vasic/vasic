#!/usr/bin/env bash
# Start the OpenDesign daemon headlessly using the app's bundled Electron runtime
# (required: the app's native better-sqlite3 is built for that runtime's ABI, not system node).
# Serves OD_DAEMON_URL=http://127.0.0.1:<port>. Run in the background.
set -euo pipefail
APP="/Applications/Open Design.app/Contents/MacOS/Open Design"
DC="/Applications/Open Design.app/Contents/Resources/app/prebundled/daemon/daemon-cli.mjs"
PORT="${OD_PORT:-4321}"
if [ ! -x "$APP" ]; then echo "Open Design app not found at: $APP" >&2; exit 1; fi
echo "Starting OpenDesign daemon on http://127.0.0.1:${PORT} ..."
exec env ELECTRON_RUN_AS_NODE=1 "$APP" "$DC" --port "$PORT" --host 127.0.0.1 --no-open
