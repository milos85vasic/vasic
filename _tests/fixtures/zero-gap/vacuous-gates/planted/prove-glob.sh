#!/usr/bin/env bash
# planted: glob loop whose unmatched literal is skipped
set -u
for f in scripts/*.sh; do
    [ -e "$f" ] || continue
    bash -n "$f" || exit 1
done
echo PASS
exit 0
