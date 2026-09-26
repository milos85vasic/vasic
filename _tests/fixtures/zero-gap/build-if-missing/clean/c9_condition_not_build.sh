#!/usr/bin/env bash
# clean: an if-condition that joins the existence test to a NON-build command (a probe) and refuses
BIN=./bin/server
if [ ! -x "$BIN" ] && ! command -v go >/dev/null 2>&1; then
  echo "not built and no toolchain: run scripts/build.sh"
  exit 2
fi
exec "$BIN"
