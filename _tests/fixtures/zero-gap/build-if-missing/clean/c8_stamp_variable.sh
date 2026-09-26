#!/usr/bin/env bash
# clean: the stamp and HEAD are read into variables and the variables are compared
BIN=./bin/server
STAMP_FILE="$BIN.stamp"
built=$(cat "$STAMP_FILE" 2>/dev/null)
head=$(git rev-parse HEAD)
[ -x "$BIN" ] || bash ./build.sh
if [ "$built" != "$head" ]; then bash ./build.sh; fi
exec "$BIN"
