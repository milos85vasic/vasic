#!/usr/bin/env bash
# planted: positive test, the build sits in the else branch
BIN=./bin/server
if [ -x "$BIN" ]; then
  echo "binary present"
else
  bash ./scripts/build.sh
fi
exec "$BIN"
