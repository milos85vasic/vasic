#!/usr/bin/env bash
# VSC-353 probe (check author: t353-check-author-2). Run from the root of the tree under test.
# Everything is measured in throwaway git repos built here; no carrier of the tree under test is read.
# Class under test: $VSC353_CLASS (default ./scripts/zero-gap-class-stale-figures.sh).
#   (A) >=3 planted "<n> declared"/"<n> owned" rows are reported; >=2 clean controls (withdrawal marker on the
#       NEXT line; exit-code MEANING line) are not reported.
#   (B) REAL MISMATCH: .gitmodules declares exactly 22 paths; an unmarked current-tense line claims "14 declared".
#       The class MUST emit a FINDING on that line whose text names BOTH 14 and 22 and says mismatch/disagrees.
#   (C) equal-counts control: "22 declared" against 22 paths -> no mismatch finding.
#   (D) historical-marked "14 declared" ((historical) at sentence end) against 22 paths -> no mismatch finding
#       (recall tradeoff pinned on purpose).
#   (E) 'owned': the class has no honest source for an owned count in a bare repo, so there is NO owned-mismatch
#       clause here (deliberately not invented).
# Exit 0 every clause holds / 1 some clause fails / 2 environment fault or class cannot run (never 0 on a fault).
set -u
SRC=$(pwd)
CLS="${VSC353_CLASS:-$SRC/scripts/zero-gap-class-stale-figures.sh}"
[ -f "$CLS" ] || { echo "class script absent: $CLS"; exit 2; }
command -v python3 >/dev/null 2>&1 && command -v git >/dev/null 2>&1 || { echo "python3/git missing"; exit 2; }
T=$(mktemp -d) || exit 2
trap 'if [ -n "$T" ] && [ -d "$T" ]; then case "$T" in /tmp/*) rm -rf "$T" ;; esac; fi' EXIT
mk() { git -C "$1" init -q 2>/dev/null && git -C "$1" add -A && git -C "$1" -c user.name=t -c user.email=t@example.invalid commit -q -m probe; }
gm() { # gm <dir> <count>: .gitmodules with <count> plain-text submodule sections
  i=1; : >"$1/.gitmodules" || return 1
  while [ "$i" -le "$2" ]; do
    printf '[submodule "m%s"]\n\tpath = mods/m%s\n\turl = https://example.invalid/m%s.git\n' "$i" "$i" "$i" >>"$1/.gitmodules"
    i=$((i+1))
  done
}
mkdir -p "$T/a" "$T/b" "$T/c" "$T/d" || exit 2
cat >"$T/a/CLAUDE.md" <<'DOC'
# Probe carrier

The tree has 22 declared in total today.

Eleven are consumers: 12 owned of the set.

That is why 12 owned gitlinks are probed of 14 declared.

The registry holds 99 checks in the old reading.
That figure is WITHDRAWN and kept as a record.

Run the gate: exit 0 = clean, exit 1 = finding, exit 2 = could not determine.
DOC
mk "$T/a" || { echo "git setup failed (a)"; exit 2; }
for x in b c d; do gm "$T/$x" 22 || { echo "gitmodules build failed"; exit 2; }; done
printf '# Probe carrier\n\nThe fleet has 14 declared.\n' >"$T/b/CLAUDE.md"
printf '# Probe carrier\n\nThe fleet has 22 declared.\n' >"$T/c/CLAUDE.md"
printf '# Probe carrier\n\nThe fleet has 14 declared (historical).\n' >"$T/d/CLAUDE.md"
for x in b c d; do mkdir -p "$T/$x/docs" && printf '# probe ledger\nsurface\tCLAUDE.md\nclaim\tlab-widgets\tCLAUDE.md\tprose\tdoc-vs-code-drift\tminor\teq\t-\tholds \\*\\*(\\d+)\\*\\* widgets\twc -l < data/widgets.txt\n' >"$T/$x/docs/claim-ledger.tsv" && mkdir -p "$T/$x/data" && printf 'w\n' >"$T/$x/data/widgets.txt" && printf 'The lab holds **1** widgets.\n' >>"$T/$x/CLAUDE.md" || exit 2; done
for x in b c d; do mk "$T/$x" || { echo "git setup failed ($x)"; exit 2; }; done
[ "$(grep -c '^\[submodule ' "$T/b/.gitmodules")" = 22 ] || { echo "sandbox .gitmodules is not 22"; exit 2; }
run() { (cd "$SRC" && timeout 300 bash "$CLS" --root "$1" >"$2" 2>"$2.err"); echo $?; }
for x in a b c d; do
  rc=$(run "$T/$x" "$T/$x.out")
  case "$rc" in 0|1) ;; *) echo "class rc $rc on sandbox $x"; exit 2 ;; esac
  grep -q '^INSPECTED ' "$T/$x.out" || { echo "class printed no INSPECTED on sandbox $x"; exit 2; }
done
reported() { # reported <out> <doc> <line>: line is a finding location or listed in a per-doc aggregate
  python3 - "$@" <<'PY'
import re,sys
out,doc,ln=sys.argv[1:4]
for l in open(out,errors='replace'):
    if not l.startswith('FINDING '): continue
    if re.search(r' figure:%s:%s ' % (re.escape(doc),ln), l): sys.exit(0)
    m=re.search(r' figures:%s .*?on line\(s\) ([0-9 ]+)' % re.escape(doc), l)
    if m and ln in m.group(1).split(): sys.exit(0)
sys.exit(1)
PY
}
mismatch() { # mismatch <out> <doc> <line> <a> <b>: a finding on that line naming both figures and mismatch/disagree
  python3 - "$@" <<'PY'
import re,sys,urllib.parse
out,doc,ln,a,b=sys.argv[1:6]
for l in open(out,errors='replace'):
    if not l.startswith('FINDING '): continue
    t=urllib.parse.unquote(l)
    on=re.search(r'figure:%s:%s\b' % (re.escape(doc),ln), t)
    m=re.search(r'figures:%s .*?on line\(s\) ([0-9 ]+)' % re.escape(doc), t)
    if m and ln in m.group(1).split(): on=True
    if on and re.search(r'mismatch|disagree',t,re.I) and re.search(r'\b%s\b'%a,t) and re.search(r'\b%s\b'%b,t): sys.exit(0)
sys.exit(1)
PY
}
anymismatch() { python3 - "$1" <<'PY'
import re,sys,urllib.parse
for l in open(sys.argv[1],errors='replace'):
    if l.startswith('FINDING ') and re.search(r'mismatch|disagree',urllib.parse.unquote(l),re.I): sys.exit(0)
sys.exit(1)
PY
}
bad=0; det=0; clean=0
for n in 3 5 7; do
  if reported "$T/a.out" CLAUDE.md "$n"; then det=$((det+1)); else echo "A: NOT detected planted line $n"; fi
done
for n in 9 12; do
  if reported "$T/a.out" CLAUDE.md "$n"; then echo "A: FALSE POSITIVE on clean control line $n"; else clean=$((clean+1)); fi
done
echo "A: planted declared/owned rows detected $det of 3 (need 3); clean controls not reported $clean of 2 (need 2)"
[ "$det" -ge 3 ] && [ "$clean" -ge 2 ] || bad=1
if mismatch "$T/b.out" CLAUDE.md 3 14 22; then echo "B: PASS mismatch finding names 14 and 22 on CLAUDE.md:3"; else echo "B: FAIL no finding on CLAUDE.md:3 naming both 14 and 22 with mismatch/disagree (.gitmodules declares 22, doc claims 14 declared)"; bad=1; fi
if anymismatch "$T/c.out"; then echo "C: FAIL equal counts (22 declared vs 22 paths) reported as mismatch"; bad=1; else echo "C: PASS equal counts not reported as mismatch"; fi
if anymismatch "$T/d.out"; then echo "D: FAIL (historical)-marked 14 declared reported as mismatch"; bad=1; else echo "D: PASS (historical)-marked line not reported as mismatch"; fi
echo "E: no owned-mismatch clause (no honest source for an owned count)"
exit "$bad"
