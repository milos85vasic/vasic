#!/usr/bin/env bash
# planted: only a COMMENT mentions freshness (build stamp, git rev-parse HEAD, -nt);
# no executable line compares anything
BIN=./bin/server
[ -x "$BIN" ] || bash ./build.sh
exec "$BIN"
