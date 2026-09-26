#!/usr/bin/env bash
# clean: an existence guard PLUS a stamp-vs-HEAD comparison
BIN=./bin/server
[ -x "$BIN" ] || bash ./build.sh
[ "$(cat "$BIN.stamp" 2>/dev/null)" = "$(git rev-parse HEAD)" ] || bash ./build.sh
exec "$BIN"
