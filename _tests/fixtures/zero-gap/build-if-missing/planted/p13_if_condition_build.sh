#!/usr/bin/env bash
# planted (fix round F2, review rev-base-A): the build sits IN THE if-CONDITION, not in a branch;
# the then-branch is only the refusal when the build also fails (scripts/verify-workable-items.sh:185)
TOOL_BIN=./bin/tool
build_tool() { ( cd tools && go build -o ../bin/tool ./cmd/tool ); }
if [ ! -x "$TOOL_BIN" ] && ! build_tool; then
  echo "could not run: the tool is not available"
  exit 2
fi
exec "$TOOL_BIN" "$@"
