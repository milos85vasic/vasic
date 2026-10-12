#!/usr/bin/env bash
# VSC-352 probe: run from the root of the tree under test.
# (1) The stale-figures class must report NO per-line `figure:README.md:<n>` finding for a recorded exit/rc
#     figure that has no re-measure command (README.md:3 is a different, ledger-verified claim, not this item).
# (2) Round 2 (closer-fixer-b13): a recorded exit code must not be BLURRED. README.md must not say a gate
#     "exits non-zero" / "exited non-zero" / "non-zero by design" / "non-zero until" (the exact code is `1`, or the
#     0/1/2 conditional), must state the exact `1` for verify-content-boundary.sh with its re-measure command,
#     and must state the 0/1/2 mapping for verify-submodule-remote-sync.sh with its re-measure command.
# Honest limit: this probe checks the README states the exact code and carries the command; it does not run the
# content-boundary gate (over ten minutes on this host), so the live rc is the command's job, not this probe's.
# `--selftest` mutates copies of README.md and requires each blur to be caught (rc 1) and the control to pass.
# Exit 0 holds / 1 violated / 2 cannot determine.
set -u
readme_check() {  # $1 = README path; prints findings; rc 0/1
  local f=$1 bad=0
  if grep -nEi 'exit(s|ed)? +non-?zero|non-?zero (by design|until|whenever)' "$f" >/dev/null; then
    grep -nEi 'exit(s|ed)? +non-?zero|non-?zero (by design|until|whenever)' "$f" | cut -c1-140
    echo "blurred exit code: the exact code must be stated"; bad=1
  fi
  grep -qE 'verify-content-boundary\.sh`[^.]*exit `1` =' "$f" || { echo "no exact exit \`1\` for verify-content-boundary.sh"; bad=1; }
  grep -qF 'bash scripts/verify-content-boundary.sh; echo "rc=$?"' "$f" || { echo "no re-measure command for verify-content-boundary.sh"; bad=1; }
  for c in 0 1 2; do
    grep -qE "^ *exit \`$c\` = " "$f" || { echo "remote-sync mapping lacks exit \`$c\`"; bad=1; }
  done
  grep -qF 'bash scripts/verify-submodule-remote-sync.sh; echo "rc=$?"' "$f" || { echo "no re-measure command for verify-submodule-remote-sync.sh"; bad=1; }
  return $bad
}
if [ "${1:-}" = "--selftest" ]; then
  [ -f README.md ] || { echo "no README.md"; exit 2; }
  d=$(mktemp -d) || exit 2; trap 'rm -rf "$d"' EXIT; fail=0
  readme_check README.md >/dev/null || { echo "control (current README) not clean"; fail=1; }
  mut() { # name sed-expr
    sed -E "$2" README.md > "$d/m.md"
    if readme_check "$d/m.md" >/dev/null; then echo "MISSED mutation: $1"; fail=1; else echo "caught: $1"; fi; }
  mut blur-content-boundary 's/designed to stay red: exit `1` = findings present/exits non-zero by design/'
  mut blur-remote-sync 's/^( *)exit `1` = at least one pin/\1it fails when at least one pin/'
  mut drop-command 's/bash scripts\/verify-content-boundary\.sh; echo "rc=\$\?"/the gate/'
  mut drop-code-2 's/^( *)exit `2` = /\1otherwise /'
  [ "$fail" -eq 0 ] && echo "selftest: 4 mutations caught, control clean"
  exit "$fail"
fi
out=$(bash scripts/zero-gap-class-stale-figures.sh --root . 2>/dev/null); rc=$?
if [ "$rc" -eq 2 ] || ! printf '%s\n' "$out" | grep -q '^INSPECTED [1-9]'; then echo "class could not run (rc $rc)"; exit 2; fi
[ -f README.md ] || { echo "no README.md"; exit 2; }
bad=0
hits=$(printf '%s\n' "$out" | grep -E "^FINDING stale-figures medium docs-drift figure:README\.md:[0-9]+ recorded figure '(exits?|exited|rc)[ =]" || true)
if [ -n "$hits" ]; then printf '%s\n' "$hits" | cut -c1-150; bad=1; fi
readme_check README.md || bad=1
[ "$bad" -eq 0 ] && echo "no README.md exit/rc figure without a re-measure command, and no blurred exit code"
[ "$bad" -eq 0 ]
