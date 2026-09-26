#!/usr/bin/env bash
# clean: the connector runs the build arm when the binary is PRESENT (an up-to-date check or a
# rebuild), never only when it is absent — not the build-if-missing trap
BIN=./bin/server
if [ -x "$BIN" ] && make -q server; then
  exec "$BIN"
fi
if [ ! -x "$BIN" ] || make server; then
  echo "not built: run scripts/build.sh"
  exit 2
fi
if [ -x "$BIN" ] || command -v go >/dev/null 2>&1; then make server; fi
