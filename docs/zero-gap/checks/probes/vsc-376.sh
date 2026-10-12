#!/usr/bin/env bash
# Probe for VSC-376: the zero_findings_sweep `uncatalogued` detector must not pass an
# empty population. Runs the sweep OF THE TREE UNDER TEST (cwd) against a planted
# fixture root in $TMPDIR. Exit: 0 holds, 1 violated, 2 cannot determine.
# Planted cases: (a) a declared scanroot absent on disk; (b) a declared scanroot that
# is present but holds no *.sh (zero-item walk); control: a populated scanroot must
# raise neither signal. Writes only under a private mktemp dir, never into the tree.
set -u
sweep="$PWD/scripts/audit/zero_findings_sweep.sh"
[ -f "$sweep" ] || { echo "probe: $sweep missing"; exit 2; }
t=$(mktemp -d) || exit 2
trap 'rm -rf "$t"' EXIT
run() { # $1 = fixture dir ; prints the sweep's stderr
  ( cd "$1" && timeout 120 bash "$sweep" --root "$1" 2>&1 >/dev/null ) || true
}
mk() { mkdir -p "$1/scripts" && ( cd "$1" && git init -q . ) || return 1; }
# control: populated scanroot
mk "$t/ctl" || exit 2
printf '#!/usr/bin/env bash\nset -u\n' > "$t/ctl/scripts/a.sh"
printf 'scanroot\tscripts\nexempt\tscripts/a.sh\tfixture\n' > "$t/ctl/scripts/check-registry.tsv"
c=$(run "$t/ctl")
if printf '%s' "$c" | grep -q 'scanroot(s) missing on disk\|zero-item walk'; then
  echo "probe: control (populated scanroot) raised an empty-population signal: not determinable"; exit 2; fi
# (a) missing scanroot
mk "$t/miss" || exit 2
printf '#!/usr/bin/env bash\nset -u\n' > "$t/miss/scripts/a.sh"
printf 'scanroot\tscripts\nscanroot\tno_such_dir\nexempt\tscripts/a.sh\tfixture\n' > "$t/miss/scripts/check-registry.tsv"
a=$(run "$t/miss")
# (b) empty scanroot
mk "$t/empty" || exit 2
mkdir -p "$t/empty/emptyroot"
printf 'scanroot\temptyroot\n' > "$t/empty/scripts/check-registry.tsv"
b=$(run "$t/empty")
ok=0
printf '%s' "$a" | grep -q 'scanroot(s) missing on disk' && echo "missing-scanroot: signalled" || { echo "missing-scanroot: NOT signalled (silently skipped)"; ok=1; }
printf '%s' "$b" | grep -q 'zero-item walk' && echo "empty-scanroot: signalled" || { echo "empty-scanroot: NOT signalled (empty population passed)"; ok=1; }
exit $ok
