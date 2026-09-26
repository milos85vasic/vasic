#!/usr/bin/env bash
# clean: no enumeration at all
set -u
test -f README.md || exit 1
echo PASS
exit 0
