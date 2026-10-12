#!/usr/bin/env bash
# VSC-354 probe: run from the root of the tree under test. EVERY occurrence (not only the first) of the phase-1
# figures of docs/constitution-adoption/INVENTORY.md must carry a line-level historical marker: "11,101 lines",
# "registers 7 submodules", "all 7 of its own nested submodules", "own 7 deps" (round 2, closer-fixer-b13: the first
# version checked head -1 of the two first patterns and so missed line 80 and the later restatements). The file
# must stay OUT of docs/zero-gap/point-in-time.tsv. When the constitution submodule is checked out in this tree the
# doc-count-drift class is also run and must report no INVENTORY.md per-line finding.
# `--selftest`: mutated copies (an extra unmarked occurrence of each pattern) must be caught, the control must pass.
# Exit 0 holds / 1 violated / 2 cannot determine.
set -u
REQUIRED=('11,101 lines' 'registers 7 submodules')
OPTIONAL=('all 7 of its own nested submodules' 'own 7 deps')
MARK='WITHDRAWN|SUPERSEDED|[Ww]ithdrawn|[Ss]uperseded|HISTORICAL|[Hh]istorical|~~'
inv_check() {  # $1 = file ; prints per-occurrence verdicts ; rc 0 all marked / 1 unmarked / 2 required figure absent
  local f=$1 bad=0 pat n
  for pat in "${REQUIRED[@]}" "${OPTIONAL[@]}"; do
    n=0
    while IFS= read -r line; do
      n=$((n+1))
      if printf '%s' "$line" | grep -qE "$MARK"; then echo "marked: $pat (line ${line%%:*})"
      else echo "UNMARKED: $pat -> line ${line%%:*}"; bad=1; fi
    done < <(grep -nF -- "$pat" "$f")
    if [ "$n" -eq 0 ]; then
      case " ${REQUIRED[*]} " in *" $pat "*) echo "figure '$pat' not found (cannot determine)"; return 2;; esac
    fi
  done
  # the capitalised restatement "All 7 are" / "All 7 (" on a line of its own must be marked too
  while IFS= read -r line; do
    if ! printf '%s' "$line" | grep -qE "$MARK"; then echo "UNMARKED: 'All 7' -> line ${line%%:*}"; bad=1; fi
  done < <(grep -nE '(^|[^A-Za-z])All 7 ' "$f")
  return $bad
}
f=docs/constitution-adoption/INVENTORY.md
[ -f "$f" ] || { echo "no $f"; exit 2; }
if [ "${1:-}" = "--selftest" ]; then
  d=$(mktemp -d) || exit 2; trap 'rm -rf "$d"' EXIT; fail=0
  inv_check "$f" >/dev/null || { echo "control (current INVENTORY.md) not clean"; fail=1; }
  for pat in '11,101 lines' 'registers 7 submodules' 'all 7 of its own nested submodules' "own 7 deps"; do
    { cat "$f"; printf '\nExtra unmarked restatement: %s.\n' "$pat"; } > "$d/m.md"
    if inv_check "$d/m.md" >/dev/null; then echo "MISSED: extra unmarked '$pat'"; fail=1; else echo "caught: extra unmarked '$pat'"; fi
  done
  { cat "$f"; printf '\nAll 7 are populated today.\n'; } > "$d/m.md"
  if inv_check "$d/m.md" >/dev/null; then echo "MISSED: unmarked 'All 7'"; fail=1; else echo "caught: unmarked 'All 7'"; fi
  [ "$fail" -eq 0 ] && echo "selftest: 5 mutations caught, control clean"
  exit "$fail"
fi
bad=0
inv_check "$f"; rc=$?
[ "$rc" -eq 2 ] && exit 2
[ "$rc" -eq 1 ] && bad=1
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
