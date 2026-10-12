#!/usr/bin/env bash
# VSC-350 probe: run from the root of the tree under test. The stale-figures class must report NO figure
# located inside a DATED section-3 entry of CONTINUATION.md (an entry whose own "### " heading carries a
# YYYY-MM-DD date under a "## ...§3..." section): those are point-in-time status notes, true when written
# (docs/zero-gap/point-in-time.tsv caption-gated row, T091). Findings in UNDATED entries and in the
# current-state sections are deliberately NOT counted here: they are not what this item is about.
# Exit 0 holds / 1 violated / 2 cannot determine.
set -u
export TMPDIR=${TMPDIR:-/tmp}
[ -f CONTINUATION.md ] || { echo "no CONTINUATION.md"; exit 2; }
out=$(bash scripts/zero-gap-class-stale-figures.sh --root . 2>/dev/null); rc=$?
if [ "$rc" -eq 2 ] || ! printf '%s\n' "$out" | grep -q '^INSPECTED [1-9]'; then echo "class could not run (rc $rc)"; exit 2; fi
# lines reported for CONTINUATION.md: per-line findings plus the (first 30) lines named by the per-document aggregate
lines=$( { printf '%s\n' "$out" | sed -nE 's/^FINDING .* figure:CONTINUATION\.md:([0-9]+) .*/\1/p'
           printf '%s\n' "$out" | sed -nE 's/^FINDING .* figures:CONTINUATION\.md [0-9]+ recorded figure\(s\) with no re-measure command on line\(s\) ([0-9 ]+).*/\1/p' | tr ' ' '\n'; } | grep -E '^[0-9]+$' | sort -un)
dated=$(awk -v L="$(printf '%s\n' $lines | tr '\n' ' ')" '
  BEGIN { n=split(L, a, " "); for (i=1;i<=n;i++) want[a[i]]=1 }
  /^## / { sec3 = ($0 ~ /§3/); entry_dated = 0 }
  /^### / { entry_dated = ($0 ~ /[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]/) }
  { if (sec3 && entry_dated && (NR in want)) print NR }' CONTINUATION.md)
if [ -n "$dated" ]; then echo "figures still reported inside dated section-3 entries, lines: $(printf '%s' "$dated" | tr '\n' ' ' | cut -c1-200)"; exit 1; fi
echo "no stale-figures finding inside a dated section-3 entry (reported lines examined: $(printf '%s\n' $lines | grep -c .))"
exit 0
