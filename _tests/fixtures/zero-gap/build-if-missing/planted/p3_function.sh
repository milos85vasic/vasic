#!/usr/bin/env bash
# planted: the build is hidden behind a function
BIN=./bin/server
ensure_built() {
  [ -f "$BIN" ] || make -C ./src
}
ensure_built
exec "$BIN"
