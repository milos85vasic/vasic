#!/usr/bin/env bash
# VSC-381 probe: run from the root of the tree under test. The module x test-kind matrix docs/zero-gap/coverage.tsv
# must exist and the coverage-gaps class must INSPECT every cell of it (population = data rows), so a coverage gap is
# visible rather than COULD-NOT-INSPECT. Exit 0 holds / 1 violated / 2 cannot determine.
set -u
[ -f scripts/zero-gap-class-coverage-gaps.sh ] || { echo "coverage-gaps class absent"; exit 2; }
if [ ! -f docs/zero-gap/coverage.tsv ]; then echo "docs/zero-gap/coverage.tsv absent: class population is 0"; exit 1; fi
rows=$(awk -F'\t' 'NR>1 && NF>=3 && $1 !~ /^#/' docs/zero-gap/coverage.tsv | wc -l)
out=$(bash scripts/zero-gap-class-coverage-gaps.sh --root . 2>/dev/null); rc=$?
n=$(printf '%s\n' "$out" | awk '$1=="INSPECTED"{print $2}')
if [ -z "$n" ]; then echo "class printed no INSPECTED line (rc $rc)"; exit 2; fi
if [ "$n" -lt 1 ] || [ "$rows" -lt 1 ]; then echo "class population $n / matrix rows $rows: nothing inspected"; exit 1; fi
if [ "$n" -ne "$rows" ]; then echo "class inspected $n cells but the matrix has $rows rows"; exit 1; fi
echo "matrix has $rows cells; the class inspected $n"
exit 0
