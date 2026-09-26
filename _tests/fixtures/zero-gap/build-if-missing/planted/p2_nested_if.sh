#!/usr/bin/env bash
# planted: nested if / not-executable form
BIN=./bin/server
if [ ! -x "$BIN" ]; then
  echo "building the server"
  go build -o "$BIN" ./cmd/server
fi
exec "$BIN"
