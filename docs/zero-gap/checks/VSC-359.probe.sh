#!/usr/bin/env bash
# VSC-359 probe: run from the root of the tree under test. Each of the five modules whose pins the root carriers
# narrate must have its CURRENT index gitlink (12 chars, `git ls-files -s <path>`) quoted in CLAUDE.md, and the
# other three carriers must quote the same (lockstep).  Round 2 (closer-fixer-b13): ALSO the negative check
# probes/pin_wording.py - present-tense pin wording ("currently checked out at `<hash>`", "current pin") that names a
# hash other than the index gitlink, or no live hash, and carries no marker in its own clause, fails.
# Exit 0 holds / 1 violated / 2 cannot determine.
set -u
bad=0
for m in submodules/constitution design-toolkit submodules/containers submodules/curriculum-kit workshop; do
  p=$(git ls-files -s -- "$m" | awk '{print substr($2,1,12)}')
  [[ "$p" =~ ^[0-9a-f]{12}$ ]] || { echo "no gitlink for $m"; exit 2; }
  for f in CLAUDE.md AGENTS.md QWEN.md GEMINI.md; do
    if grep -qF "$p" "$f"; then :; else echo "$f does not quote the current pin of $m ($p)"; bad=1; fi
  done
done
py="$(cd "$(dirname "$0")" && pwd)/probes/pin_wording.py"
[ -f "$py" ] || { echo "no $py"; exit 2; }
out=$(python3 -I "$py" --root "$(pwd)"); prc=$?
printf '%s\n' "$out" | tail -8
[ "$prc" -eq 2 ] && exit 2
[ "$prc" -eq 0 ] || bad=1
[ "$bad" -eq 0 ] && echo "all five current gitlinks are quoted in all four carriers, and no stale present-tense pin wording"
[ "$bad" -eq 0 ]
