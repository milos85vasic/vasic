#!/usr/bin/env bash
# synthetic fixture: a stage RUNNER (0 every planned step ran, 1 a step failed, 2 a
# precondition is unmet). It renders no verdict over any guarded condition.
set -u
[ -d "${1:-.}" ] || exit 2
echo "ran ${1:-.}"
exit 0
