#!/usr/bin/env bash
# planted: the stamp and HEAD comparisons live only in messages and an inline comment
BIN=./bin/server
echo "skipped here: [ stamp = HEAD ] comparison"
log_warn "not checked: [ \"$(git rev-parse HEAD)\" = recorded ]"
[ -x "$BIN" ] || bash ./build.sh   # TODO: [ "$(cat "$BIN.stamp")" = "$(git rev-parse HEAD)" ]
exec "$BIN"
