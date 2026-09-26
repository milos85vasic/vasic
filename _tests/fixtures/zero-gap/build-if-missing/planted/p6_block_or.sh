#!/usr/bin/env bash
# planted: build inside a || { ...; } group
BIN=./bin/server
[ -x "$BIN" ] || {
  echo "no binary yet"
  ( cd src && go build -o "$BIN" . )
}
exec "$BIN"
