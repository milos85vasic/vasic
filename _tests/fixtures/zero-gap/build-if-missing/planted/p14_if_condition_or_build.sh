#!/usr/bin/env bash
# planted: positive test whose || arm in the if-condition builds (make runs only when the binary is absent)
BIN=./bin/server
if [ -x "$BIN" ] || make server; then
  exec "$BIN"
fi
