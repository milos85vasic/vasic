#!/usr/bin/env bash
# VSC-354 probe: run from the root of the tree under test. The two phase-1 figures of
# docs/constitution-adoption/INVENTORY.md (sections 2-3: "11,101 lines", "registers 7 submodules")
# must carry a line-level historical marker (the doc-count-drift class's own R_HIST words), and the
# file must stay OUT of docs/zero-gap/point-in-time.tsv. When the constitution submodule is checked out
# in this tree the doc-count-drift class is also run and must report no INVENTORY.md per-line finding.
# Exit 0 holds / 1 violated / 2 cannot determine.
set -u
f=docs/constitution-adoption/INVENTORY.md
[ -f "$f" ] || { echo "no $f"; exit 2; }
bad=0
for pat in '11,101 lines' 'registers 7 submodules'; do
  hits=$(grep -nF -- "$pat" "$f" | head -1)
  [ -n "$hits" ] || { echo "figure '$pat' not found (cannot determine)"; exit 2; }
  if printf '%s' "$hits" | grep -qE 'WITHDRAWN|SUPERSEDED|[Ww]ithdrawn|[Ss]uperseded|HISTORICAL|[Hh]istorical|~~'; then
    echo "marked: $pat"
  else
    echo "UNMARKED: $pat -> ${hits%%|*}"; bad=1
  fi
done
if grep -v '^#' docs/zero-gap/point-in-time.tsv 2>/dev/null | cut -f1 | grep -qxF 'docs/constitution-adoption/INVENTORY.md'; then
  echo "INVENTORY.md was added to point-in-time.tsv (forbidden by the item)"; bad=1
fi
if [ -f submodules/constitution/Constitution.md ]; then
  out=$(bash scripts/zero-gap-class-doc-count-drift.sh --root . 2>/dev/null); rc=$?
  if [ "$rc" -eq 2 ]; then echo "class could not run"; exit 2; fi
  if printf '%s\n' "$out" | grep -E '^FINDING .* docs/constitution-adoption/INVENTORY\.md:[0-9]+ ' >/dev/null; then
    echo "class still reports a per-line INVENTORY.md finding"; bad=1
  else echo "class: no per-line INVENTORY.md finding"; fi
fi
[ "$bad" -eq 0 ]
