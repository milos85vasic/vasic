#!/usr/bin/env bash
# Stub PreToolUse guard for the guard-gaps clean control: allows the one read-only `git status` row and
# refuses everything else (rc 2). It only READS the string; nothing is executed.
in=$(cat)
case "$in" in
  *'"git status --short"'*) exit 0 ;;
esac
echo "stub guard: refused" >&2
exit 2
