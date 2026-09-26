#!/usr/bin/env bash
# planted: env-assignment prefix on the build, compound condition
BIN=./bin/site-build
if [ ! -x "$BIN" ] && command -v go >/dev/null 2>&1; then
  ( cd tools && GOPROXY=off go build -o "$BIN" ./cmd/site-build ) >/dev/null 2>&1
fi
exec "$BIN"
