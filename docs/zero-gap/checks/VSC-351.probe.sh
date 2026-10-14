#!/usr/bin/env bash
# VSC-351 probe: run from the root of the tree under test. In the CURRENT-STATE sections of CONTINUATION.md
# (every "## " section whose heading does not carry the section sign + 3) no recorded-figure line may lack a
# line-level historical marker, and the stale-figures class must report no per-line finding there.
# Exit 0 holds / 1 violated / 2 cannot determine.
set -u
export TMPDIR=${TMPDIR:-/tmp}
py=$(dirname "$0")/fig-population.py
[ -f "$py" ] || py="$(git rev-parse --show-toplevel)/docs/zero-gap/checks/fig-population.py"
out=$(python3 -I "$py" CONTINUATION.md --outside-s3); rc=$?
[ "$rc" -eq 2 ] && { echo "$out"; exit 2; }
bad=0
[ "$rc" -eq 1 ] && { printf '%s\n' "$out" | tail -8; bad=1; }
cls=$(bash scripts/zero-gap-class-stale-figures.sh --root . 2>/dev/null); crc=$?
if [ "$crc" -eq 2 ] || ! printf '%s\n' "$cls" | grep -q '^INSPECTED [1-9]'; then echo "class could not run (rc $crc)"; exit 2; fi
# per-line findings whose line is outside section 3
lines=$(printf '%s\n' "$cls" | sed -nE 's/^FINDING .* figure:CONTINUATION\.md:([0-9]+) .*/\1/p' | sort -un | tr '\n' ' ')
outside=$(awk -v L="$lines" 'BEGIN{n=split(L,a," ");for(i=1;i<=n;i++)w[a[i]]=1} /^## /{s3=($0 ~ /§3/)} {if(!s3 && (NR in w)) print NR}' CONTINUATION.md)
if [ -n "$outside" ]; then echo "class reports current-state lines: $(printf '%s' "$outside" | tr '\n' ' ' | cut -c1-120)"; bad=1; fi
[ "$bad" -eq 0 ] && echo "CONTINUATION.md current-state sections: every figure line marked, class clean there"
[ "$bad" -eq 0 ]
