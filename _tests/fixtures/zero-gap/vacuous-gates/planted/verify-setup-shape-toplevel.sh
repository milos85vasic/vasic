#!/usr/bin/env bash
# planted: the setup-error shape (`|| exit 1` on a command, no test) OUTSIDE a proof helper is a
# gate's own verdict (jq validates each file) and is still reported.
for f in $(git ls-files '*.json'); do
    jq . "$f" >/dev/null || exit 1
done
echo PASS
