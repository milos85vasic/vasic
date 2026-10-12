#!/usr/bin/env bash
# VSC-384 probe: run from the root of the tree under test. The missing-toolchain class must report NO
# `derived:` governance-drift finding for the four tools that scripts probe optionally or as a fallback
# (docs_chain, ifconfig, lumen, shellcheck): each needs a docs/zero-gap/toolchains.tsv row carrying its role.
# Exit 0 holds / 1 violated / 2 cannot determine (the class could not run).
set -u
out=$(bash scripts/zero-gap-class-missing-toolchain.sh --root . 2>/dev/null); rc=$?
if [ "$rc" -eq 2 ] || ! printf '%s\n' "$out" | grep -q '^INSPECTED [1-9]'; then echo "class could not run (rc $rc)"; exit 2; fi
bad=0
for t in docs_chain ifconfig lumen shellcheck; do
  if printf '%s\n' "$out" | awk -v t="derived:$t" '$1=="FINDING" && $5==t {f=1} END{exit !f}'; then
    echo "UNCATALOGUED: derived:$t is still reported"; bad=1
  else echo "catalogued or present: $t"; fi
done
[ "$bad" -eq 0 ]
