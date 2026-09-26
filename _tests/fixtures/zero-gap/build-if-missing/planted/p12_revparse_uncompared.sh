#!/usr/bin/env bash
# planted: HEAD is read only to label the binary, never compared with what was built
BIN=./bin/server
VERSION=$(git rev-parse HEAD)
[ -f "$BIN.stamp" ] || touch "$BIN.stamp"
[ -x "$BIN" ] || go build -ldflags "-X main.version=$VERSION" -o "$BIN" ./cmd/server
exec "$BIN"
