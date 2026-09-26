#!/usr/bin/env bash
# Stub PreToolUse guard for the guard-gaps corpus: reads the hook JSON on stdin, refuses (rc 2) some
# commands and allows the rest. It only READS the string; nothing is executed.
in=$(cat)
case "$in" in
  *"checkout --"*|*"git restore"*|*"clean -fd"*|*"git reset"*|*"push --force"*|*"--no-verify"*|*"git diff"*) echo "stub guard: refused" >&2; exit 2 ;;
esac
exit 0
