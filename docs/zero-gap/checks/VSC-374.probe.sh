#!/usr/bin/env bash
# VSC-374 probe: run from the root of the tree under test. The unregistered-scripts class must report NO finding for
# the seven tracked executables outside the declared scanroots (_tests x6, upstreams/GitHub.sh), and the aggregator
# _tests/run-harness-selfvalidation.sh, now registered as a check, must pass its own --prove-failure.
# Exit 0 holds / 1 violated / 2 cannot determine.
set -u
[ -f scripts/zero-gap-class-unregistered-scripts.sh ] || { echo "class absent"; exit 2; }
out=$(bash scripts/zero-gap-class-unregistered-scripts.sh --root . 2>/dev/null); rc=$?
if [ "$rc" -eq 2 ] || ! printf '%s\n' "$out" | grep -q '^INSPECTED [1-9]'; then echo "class could not run (rc $rc)"; exit 2; fi
bad=0
for p in _tests/evidence/fix4docs/retry.sh _tests/export/build-fixtures.sh _tests/export/self-validate.sh _tests/prove-preflight.sh \
         _tests/run-harness-selfvalidation.sh _tests/visual/self-validate.sh upstreams/GitHub.sh; do
  if printf '%s\n' "$out" | awk -v p="$p" '$1=="FINDING" && $5==p {f=1} END{exit !f}'; then echo "UNREGISTERED: $p"; bad=1; fi
done
if grep -q -- '--prove-failure)' _tests/run-harness-selfvalidation.sh 2>/dev/null; then
  bash _tests/run-harness-selfvalidation.sh --prove-failure >/dev/null 2>&1 || { echo "aggregator --prove-failure failed"; bad=1; }
else echo "aggregator has no --prove-failure arm"; bad=1; fi
[ "$bad" -eq 0 ] && echo "all seven registered; aggregator proof passes"
exit "$bad"
