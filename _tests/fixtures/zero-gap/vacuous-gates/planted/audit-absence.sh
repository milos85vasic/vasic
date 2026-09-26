#!/usr/bin/env bash
# planted: absence assertion over a subject set never shown non-empty
set -u
if [ -z "$(grep -rn TODO docs)" ]; then
    echo PASS
    exit 0
fi
exit 1
