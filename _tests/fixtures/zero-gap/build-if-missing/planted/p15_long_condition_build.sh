#!/usr/bin/env bash
# planted (fix round F3, review rev-f): the build sits LATE in a long if-condition, after a toolchain
# probe; the then-branch only refuses — the whole condition must be read, not a prefix of it
BIN=./bin/server
if [ ! -x "$BIN" ] && command -v go >/dev/null 2>&1 && ! go build -o "$BIN" ./cmd/server; then
  echo "could not run: the server is not built"
  exit 2
fi
exec "$BIN"
