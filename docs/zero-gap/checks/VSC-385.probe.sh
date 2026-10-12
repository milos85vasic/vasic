#!/usr/bin/env bash
# VSC-385 probe: run from the root of the tree under test. The doc-count-drift row of
# docs/zero-gap/sweep-classes.tsv must not assert an unmeasured probability ("least likely to drift")
# and must keep its 8 tab-separated fields. Exit 0 holds / 1 violated / 2 cannot determine.
set -u
f=docs/zero-gap/sweep-classes.tsv
[ -f "$f" ] || { echo "no $f"; exit 2; }
row=$(grep -P '^doc-count-drift\t' "$f") || { echo "no doc-count-drift row"; exit 2; }
bad=0
if printf '%s' "$row" | grep -qi 'least likely to drift'; then echo "UNMEASURED-CLAUSE present"; bad=1; fi
n=$(printf '%s' "$row" | awk -F'\t' '{print NF}')
[ "$n" -eq 8 ] || { echo "field count $n != 8"; bad=1; }
[ "$bad" -eq 0 ]
