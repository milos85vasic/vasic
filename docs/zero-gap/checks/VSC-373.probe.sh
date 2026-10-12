#!/usr/bin/env bash
# VSC-373 probe: run from the root of the tree under test. Every tracked (or untracked-not-ignored) *.sh below
# _tools/ must be VISIBLE to the check registry: either registered in a row of scripts/check-registry.tsv
# (path in field 2 of exempt/debt, field 3 of check) or inside the sweep -- its directory is a plain scanroot, or it
# lies under a scanroot flagged `recursive`. A script that is neither is a BLIND SPOT (the R5 sweep is
# `find -maxdepth 1` per plain scanroot). Also: the meta-check must report no UNREGISTERED script.
# Exit 0 holds / 1 violated / 2 cannot determine.
set -u
reg=scripts/check-registry.tsv
[ -f "$reg" ] || { echo "no $reg"; exit 2; }
[ -f scripts/verify-check-registry.sh ] || { echo "no meta-check"; exit 2; }
roots=$(awk -F'\t' '$1=="scanroot"{print $2 "\t" $3}' "$reg")
paths=$(awk -F'\t' '($1=="exempt"||$1=="debt"){print $2} $1=="check"{print $3}' "$reg")
n=0; blind=0
while IFS= read -r f; do
  [ -n "$f" ] || continue
  n=$((n+1))
  if printf '%s\n' "$paths" | grep -qxF "$f"; then continue; fi
  d=$(dirname "$f"); swept=0
  while IFS=$'\t' read -r r flag; do
    [ -n "$r" ] || continue
    if [ "$d" = "$r" ]; then swept=1; break; fi
    if [ "$flag" = recursive ] && [ "${d#"$r"/}" != "$d" ]; then swept=1; break; fi
  done <<< "$roots"
  if [ "$swept" -eq 0 ]; then echo "BLIND: $f"; blind=$((blind+1)); fi
done < <(git ls-files -co --exclude-standard -- '_tools/*.sh' | sort -u)
[ "$n" -gt 0 ] || { echo "no _tools scripts enumerated"; exit 2; }
echo "scripts under _tools: $n, blind: $blind"
out=$(bash scripts/verify-check-registry.sh --quiet 2>&1); rc=$?
[ "$rc" -eq 2 ] && { echo "meta-check could not determine"; exit 2; }
if printf '%s\n' "$out" | grep -q 'UNREGISTERED'; then echo "meta-check reports UNREGISTERED scripts:"; printf '%s\n' "$out" | grep 'UNREGISTERED' | cut -c1-160 | head -5; blind=$((blind+1)); fi
[ "$blind" -eq 0 ]
