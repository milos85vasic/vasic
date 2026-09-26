#!/usr/bin/env bash
# planted: build guarded by existence only
HERE="$(dirname "$0")"
BIN="$HERE/bin/server"
[ -x "$BIN" ] || bash "$HERE/build.sh"
exec "$BIN"
