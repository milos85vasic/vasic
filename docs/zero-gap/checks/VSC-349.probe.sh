#!/usr/bin/env bash
# VSC-349 probe: run from the root of the tree under test. Every recorded-figure line of the four root
# carriers must carry a line-level historical marker (or a ledger anchor), the stale-figures class must report
# no CLAUDE.md finding, and the four carriers must still agree from line 19 (the shared region, C5).
# Exit 0 holds / 1 violated / 2 cannot determine.
set -u
export TMPDIR=${TMPDIR:-/tmp}
bad=0
for f in CLAUDE.md AGENTS.md QWEN.md GEMINI.md; do [ -f "$f" ] || { echo "no $f"; exit 2; }; done
n=$(for f in CLAUDE.md AGENTS.md QWEN.md GEMINI.md; do tail -n +19 "$f" | sha256sum; done | sort -u | wc -l)
[ "$n" -eq 1 ] || { echo "carriers differ from line 19 (C5 lockstep broken)"; bad=1; }
py=$(dirname "$0")/fig-population.py
[ -f "$py" ] || py="$(git rev-parse --show-toplevel)/docs/zero-gap/checks/fig-population.py"
for f in CLAUDE.md AGENTS.md QWEN.md GEMINI.md; do
  out=$(python3 -I "$py" "$f"); rc=$?
  [ "$rc" -eq 2 ] && { echo "$out"; exit 2; }
  if [ "$rc" -eq 1 ]; then echo "== $f"; printf '%s\n' "$out" | tail -6; bad=1; fi
done
out=$(bash scripts/zero-gap-class-stale-figures.sh --root . 2>/dev/null); rc=$?
if [ "$rc" -eq 2 ] || ! printf '%s\n' "$out" | grep -q '^INSPECTED [1-9]'; then echo "class could not run (rc $rc)"; exit 2; fi
if printf '%s\n' "$out" | grep -E '^FINDING stale-figures [a-z]+ docs-drift figures?:(CLAUDE|AGENTS|QWEN|GEMINI)\.md' | grep -v 'ledger row' >/dev/null; then
  echo "the stale-figures class still reports a carrier figure"; bad=1; fi
[ "$bad" -eq 0 ] && echo "carriers: every figure line marked, class clean, lockstep intact"
[ "$bad" -eq 0 ]
