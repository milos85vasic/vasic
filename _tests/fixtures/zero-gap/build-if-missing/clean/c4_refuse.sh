#!/usr/bin/env bash
# clean: a missing binary is REFUSED, nothing is built
BIN=./bin/server
[ -x "$BIN" ] || undetermined "not built; run scripts/build.sh"
[ -f ./bin/other ] || { echo "not built: run scripts/build.sh"; exit 2; }
exec "$BIN"
