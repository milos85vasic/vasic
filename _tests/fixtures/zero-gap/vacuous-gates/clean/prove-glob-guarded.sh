#!/usr/bin/env bash
# clean: glob loop with an explicit emptiness refusal
set -u
seen=0
for f in scripts/*.sh; do
    seen=$((seen + 1))
    bash -n "$f" || exit 1
done
if [ "$seen" -eq 0 ]; then
    echo "cannot determine: glob matched nothing"
    exit 2
fi
exit 0
