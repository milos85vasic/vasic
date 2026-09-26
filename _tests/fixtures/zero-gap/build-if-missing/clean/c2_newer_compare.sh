#!/usr/bin/env bash
# clean: existence AND source-newer-than-binary
BIN=./bin/server
if [ ! -x "$BIN" ] || [ -n "$(find src -newer "$BIN" -print -quit)" ]; then
  go build -o "$BIN" ./cmd/server
fi
exec "$BIN"
