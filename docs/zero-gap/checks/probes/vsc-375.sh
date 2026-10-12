#!/usr/bin/env bash
# Probe for VSC-375: no registered audit/check may enumerate its subject with a bare
# tracked-only `git ls-files` without covering untracked files or stating the limit.
# Oracle: the repository's own sweep class (untracked-blind-window), run against the
# tree under test (cwd) from the main checkout. Source-level evidence by nature.
# Exit: 0 no finding names the three audits, 1 any of them is a finding, 2 undetermined.
set -u
R=$(cd "$(git rev-parse --git-common-dir)/.." && pwd) || exit 2
cls="$R/scripts/zero-gap-class-untracked-blind-window.sh"
[ -f "$cls" ] || { echo "probe: class script missing"; exit 2; }
out=$(bash "$cls" --root "$PWD" 2>&1); rc=$?
printf '%s\n' "$out" | grep -E '^(FINDING|INSPECTED|COULD)' | cut -c1-200
case "$rc" in 0|1) ;; *) echo "probe: class script rc=$rc"; exit 2 ;; esac
printf '%s\n' "$out" | grep -q '^INSPECTED [1-9]' || { echo "probe: empty population"; exit 2; }
if printf '%s\n' "$out" | grep -E '^FINDING' | grep -qE 'audit-environment-assumptions\.sh|audit-hardcoded-paths\.sh|verify-provider-ci\.sh'; then exit 1; fi
exit 0
