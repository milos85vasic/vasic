#!/usr/bin/env bash
# VSC-354 probe: run from the root of the tree under test. EVERY occurrence (not only the first) of the phase-1
# figures of docs/constitution-adoption/INVENTORY.md must carry a line-level historical marker: "11,101 lines" /
# "11101 lines" / the table cell "| Constitution.md | 11101 |", "registers 7 submodules", "all 7 of its own nested
# submodules", "own 7 deps", "All 7", the pinned commit (448981a + any hex suffix) and the describe string
# "v1.0.0-51-g448981a", and the counts derived from the historical 7 ("eighth directory", "the other five").
# Round 3 (t349-354-check-author-3): comma-less and table-cell figure forms, pin/describe strings, derived counts.
# The file must stay OUT of docs/zero-gap/point-in-time.tsv. When the constitution submodule is checked out in this
# tree the doc-count-drift class is also run and must report no INVENTORY.md per-line finding. When it is NOT
# checked out (worktree) that class step cannot run: a LOUD "CLASS STEP SKIPPED" line goes to stdout AND stderr,
# the probe never reports a plain "holds", and with --strict (the closure .check uses it) the result is rc 2.
# `--selftest`: a synthetic clean base (embedded below) plus mutated copies; each mutation must be caught, each
# marked variant and the control must pass, and an emptied-submodule tree must print the skip line and exit 2.
# Exit 0 holds / 1 violated / 2 cannot determine.
set -u
SKIPPED=0
# required figures (absent => cannot determine) and optional ones; all are ERE, one occurrence per line is judged
REQUIRED=('11,?101 lines' 'registers 7 submodules')
OPTIONAL=('all 7 of its own nested submodules' 'own 7 deps'
          '\|[[:space:]]*`?Constitution\.md`?[[:space:]]*\|[[:space:]]*11,?101([^0-9]|$)'
          '448981a[0-9a-f]*' 'v1\.0\.0-51-g448981a' '[Ee]ighth directory' 'the other five')
MARK='WITHDRAWN|SUPERSEDED|[Ww]ithdrawn|[Ss]uperseded|HISTORICAL|[Hh]istorical|~~'
SKIP_MSG='CLASS STEP SKIPPED: submodules/constitution not checked out - doc-count-drift class NOT run'
inv_check() {  # $1 = file ; prints per-occurrence verdicts ; rc 0 all marked / 1 unmarked / 2 required figure absent
  local f=$1 bad=0 pat n line
  for pat in "${REQUIRED[@]}" "${OPTIONAL[@]}"; do
    n=0
    while IFS= read -r line; do
      n=$((n+1))
      if printf '%s' "$line" | grep -qE "$MARK"; then echo "marked: $pat (line ${line%%:*})"
      else echo "UNMARKED: $pat -> line ${line%%:*}"; bad=1; fi
    done < <(grep -nE -- "$pat" "$f")
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
skip_notice() { echo "$SKIP_MSG"; echo "$SKIP_MSG" >&2; }
run_probe() {  # $1 = "--strict" or "" ; runs in the cwd
  local strict=${1:-} f=docs/constitution-adoption/INVENTORY.md bad=0 rc out
  [ -f "$f" ] || { echo "no $f"; return 2; }
  inv_check "$f"; rc=$?
  [ "$rc" -eq 2 ] && return 2
  [ "$rc" -eq 1 ] && bad=1
  if grep -v '^#' docs/zero-gap/point-in-time.tsv 2>/dev/null | cut -f1 | grep -qxF 'docs/constitution-adoption/INVENTORY.md'; then
    echo "INVENTORY.md was added to point-in-time.tsv (forbidden by the item)"; bad=1
  fi
  SKIPPED=0
  if [ -f submodules/constitution/Constitution.md ]; then
    out=$(bash scripts/zero-gap-class-doc-count-drift.sh --root . 2>/dev/null); rc=$?
    if [ "$rc" -eq 2 ]; then echo "class could not run"; return 2; fi
    if printf '%s\n' "$out" | grep -E '^FINDING .* docs/constitution-adoption/INVENTORY\.md:[0-9]+ ' >/dev/null; then
      echo "class still reports a per-line INVENTORY.md finding"; bad=1
    else echo "class: no per-line INVENTORY.md finding"; fi
  else
    SKIPPED=1; skip_notice
  fi
  [ "$bad" -eq 1 ] && return 1          # a finding outranks a skipped step
  if [ "$SKIPPED" -eq 1 ]; then
    echo "line-level markers hold; doc-count-drift class NOT run (cannot determine the class half)"
    [ "$strict" = "--strict" ] && return 2
    return 0
  fi
  return 0
}
if [ "${1:-}" = "--selftest" ]; then
  self=$(cd "$(dirname "$0")" && pwd)/$(basename "$0")
  base=${TMPDIR:-$HOME/.cache/agent-scratch}; mkdir -p -m 700 "$base" || exit 2
  d=$(mktemp -d "$base/vsc354.XXXXXX") || exit 2; trap 'rm -rf "$d"' EXIT; fail=0; ncaught=0
  # synthetic clean base: every figure present, every occurrence marked
  cat > "$d/base.md" <<'BASE'
| Pinned commit | historical, superseded: `448981ae3498229c734dc60719f4b19f01d7a75f` at the audit |
| `git describe` | historical, superseded: `v1.0.0-51-g448981a` at the pin |
| Checked out? | Yes, including all 7 of its own nested submodules (historical: counted at the old pin) |
| Canonical rule text | `Constitution.md` - 11,101 lines (historical: measured at the old pin) |
| `Constitution.md` | 11101 (historical: measured at the old pin) | text |
| `helix-deps.yaml` | - | the constitution's own 7 deps (historical: counted at the old pin). |
`.gitmodules` registers 7 submodules (historical: counted at the old pin). All 7 (historical) are
populated. In that historical count an eighth directory existed on disk.
the other five track main (the count of five derives from the historical 7).
BASE
  inv_check "$d/base.md" >/dev/null || { echo "control (synthetic clean base) not clean"; fail=1; }
  mut() {  # $1 = label ; $2 = line to append
    { cat "$d/base.md"; printf '\n%s\n' "$2"; } > "$d/m.md"
    if inv_check "$d/m.md" >/dev/null; then echo "MISSED: $1"; fail=1; else echo "caught: $1"; ncaught=$((ncaught+1)); fi
  }
  ok() {   # $1 = label ; $2 = line that carries a marker => must pass
    { cat "$d/base.md"; printf '\n%s\n' "$2"; } > "$d/m.md"
    if inv_check "$d/m.md" >/dev/null; then echo "passes (marked): $1"; else echo "WRONGLY CAUGHT marked variant: $1"; fail=1; fi
  }
  mut 'extra unmarked 11,101 lines' 'Extra unmarked restatement: 11,101 lines.'
  mut 'extra unmarked 11101 lines (comma-less)' 'Extra unmarked restatement: 11101 lines.'
  mut 'extra unmarked table row | Constitution.md | 11101 |' '| `Constitution.md` | 11101 | text |'
  mut 'extra unmarked table row | Constitution.md | 11,101 |' '| Constitution.md | 11,101 | text |'
  mut 'extra unmarked registers 7 submodules' 'Extra unmarked restatement: registers 7 submodules.'
  mut 'extra unmarked all 7 of its own nested submodules' 'Extra unmarked restatement: all 7 of its own nested submodules.'
  mut 'extra unmarked own 7 deps' 'Extra unmarked restatement: own 7 deps.'
  mut 'extra unmarked All 7' 'All 7 are populated today.'
  mut 'extra unmarked pin 448981ae3498' 'The pin is `448981ae3498`.'
  mut 'extra unmarked pin 448981a (7-char prefix)' 'The pin is 448981a.'
  mut 'extra unmarked describe v1.0.0-51-g448981a' 'The describe is `v1.0.0-51-g448981a`.'
  mut 'extra unmarked "An eighth directory"' 'An eighth directory exists on disk.'
  mut 'extra unmarked "the other five"' 'the other five track heads/main.'
  ok '11101 lines marked' 'Restated 11101 lines (historical: old pin).'
  ok 'table cell marked' '| Constitution.md | 11101 (superseded) | text |'
  ok 'pin marked' 'The pin was `448981ae3498` (withdrawn).'
  ok 'describe marked' 'The describe was v1.0.0-51-g448981a, SUPERSEDED.'
  ok 'eighth directory marked' 'An eighth directory existed (historical).'
  ok 'the other five marked' 'the other five (historical count) tracked main.'
  # the emptied-submodule tree: skip notice on stdout AND stderr, rc 2 under --strict, never a plain pass
  mkdir -p "$d/t/docs/constitution-adoption" "$d/t/docs/zero-gap" "$d/t/submodules/constitution"
  cp "$d/base.md" "$d/t/docs/constitution-adoption/INVENTORY.md"
  : > "$d/t/docs/zero-gap/point-in-time.tsv"
  so=$(cd "$d/t" && bash "$self" --strict 2>"$d/err.txt"); src=$?
  if [ "$src" -eq 2 ] && printf '%s\n' "$so" | grep -qF "$SKIP_MSG" && grep -qF "$SKIP_MSG" "$d/err.txt"; then
    echo "caught: emptied submodule tree -> skip notice on stdout+stderr, rc 2 (strict)"; ncaught=$((ncaught+1))
  else echo "MISSED: emptied submodule tree (rc $src)"; fail=1; fi
  so=$(cd "$d/t" && bash "$self" 2>/dev/null); src=$?
  if [ "$src" -eq 0 ] && printf '%s\n' "$so" | grep -qF "$SKIP_MSG" && ! printf '%s\n' "$so" | grep -q 'and the class step ran'; then
    echo "passes (non-strict): skip notice printed, no plain 'holds'"
  else echo "WRONG non-strict skip behaviour (rc $src)"; fail=1; fi
  printf '\n- stray unmarked 11101 lines\n' >> "$d/t/docs/constitution-adoption/INVENTORY.md"
  so=$(cd "$d/t" && bash "$self" --strict 2>/dev/null); src=$?
  if [ "$src" -eq 1 ]; then echo "caught: finding outranks the skipped class step (rc 1)"; ncaught=$((ncaught+1))
  else echo "MISSED: finding must outrank a skip (rc $src)"; fail=1; fi
  [ "$fail" -eq 0 ] && echo "selftest: $ncaught mutations caught, marked variants and control clean"
  exit "$fail"
fi
run_probe "${1:-}"; rc=$?
[ "$rc" -eq 0 ] && [ "$SKIPPED" -eq 0 ] && echo "VSC-354 line-level markers hold and the class step ran"
exit "$rc"
