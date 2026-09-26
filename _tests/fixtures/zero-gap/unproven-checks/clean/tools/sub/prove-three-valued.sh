#!/usr/bin/env bash
# fixture: sibling paired proof; it mutates a copy and requires tools/sub/verify-sibnamed.sh to fail
d=$(mktemp -d); trap 'rm -rf "$d"' EXIT
( cd "$d" && bash "$(dirname "$0")/verify-sibnamed.sh" ) && { echo "mutation survived"; exit 1; }
echo "mutation caught"
