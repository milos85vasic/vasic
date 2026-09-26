#!/usr/bin/env bash
# clean: the "build" words sit inside messages and reporting helpers, never as a command
SRC=./src
if [[ ! -f "$SRC/gen.out" ]]; then
    echo "UNDETERMINED: $SRC/gen.out does not exist."
    echo "  Run: node $(dirname -- "$SRC")/tools/build.mjs; then retry"
    exit 2
fi
if [ -x ./bin/tool ]; then
    ./bin/tool
else
    build_undet "the tool is absent and is not built here"
fi
