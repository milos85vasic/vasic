#!/usr/bin/env bash
# VSC-352 probe: run from the root of the tree under test. The stale-figures class must report NO
# per-line `figure:README.md:<n>` finding for a recorded exit/rc figure that has no re-measure command.
# (README.md:3 is a different, ledger-verified claim and is not what this item is about.)
# Exit 0 holds / 1 violated / 2 cannot determine.
set -u
out=$(bash scripts/zero-gap-class-stale-figures.sh --root . 2>/dev/null); rc=$?
if [ "$rc" -eq 2 ] || ! printf '%s\n' "$out" | grep -q '^INSPECTED [1-9]'; then echo "class could not run (rc $rc)"; exit 2; fi
hits=$(printf '%s\n' "$out" | grep -E "^FINDING stale-figures medium docs-drift figure:README\.md:[0-9]+ recorded figure '(exits?|exited|rc)[ =]" || true)
if [ -n "$hits" ]; then printf '%s\n' "$hits" | cut -c1-150; exit 1; fi
echo "no README.md exit/rc figure without a re-measure command"
exit 0
