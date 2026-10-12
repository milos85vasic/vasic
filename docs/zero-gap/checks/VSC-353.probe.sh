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
# ---- Clauses F/G (B1/B2 shapes; added by t353-check-author-3). Each box is a separate sandbox: .gitmodules declares 22 paths.
# F shapes (B1): "<n> <fleet noun> (is|are|were) declared" with fleet noun gitlinks|submodules; the line must enter the figure population.
# G shapes (B2): "<n> declared <adverb>" with adverb in {today, now, currently, so far}; markup around the number allowed.
# H KNOWN-INVISIBLE shapes (recall cost, NOT required to be detected; silence is pinned on purpose): "declared: 14",
#   "14 submodules declared", "fourteen declared", and a number wrapped onto the previous physical line before "declared".
mkbox() { # mkbox <name> <line>...: carrier with each line as its own paragraph (lines 3,5,7,9) + the ledger claim; 22 .gitmodules paths
  _d="$T/$1"; shift
  mkdir -p "$_d/docs" "$_d/data" || return 1
  gm "$_d" 22 || return 1
  printf '# Probe carrier\n' >"$_d/CLAUDE.md" || return 1
  for _l in "$@"; do printf '\n%s\n' "$_l" >>"$_d/CLAUDE.md"; done
  printf '# probe ledger\nsurface\tCLAUDE.md\nclaim\tlab-widgets\tCLAUDE.md\tprose\tdoc-vs-code-drift\tminor\teq\t-\tholds \\*\\*(\\d+)\\*\\* widgets\twc -l < data/widgets.txt\n' >"$_d/docs/claim-ledger.tsv" || return 1
  printf 'w\n' >"$_d/data/widgets.txt" && printf '\nThe lab holds **1** widgets.\n' >>"$_d/CLAUDE.md" || return 1
  mk "$_d"
}
mkbox fm 'The fleet: 13 gitlinks are declared.' 'The fleet: 13 submodules are declared.' 'The fleet: 14 submodules were declared.' || { echo "box fm setup failed"; exit 2; }
mkbox fe 'The fleet: 22 gitlinks are declared.' 'The fleet: 22 submodules are declared.' 'The fleet: 22 submodules were declared.' || { echo "box fe setup failed"; exit 2; }
mkbox fh 'The fleet: 13 gitlinks are declared (historical).' 'The fleet: 14 submodules were declared (historical).' || { echo "box fh setup failed"; exit 2; }
mkbox gm 'The fleet: **14** declared today' 'The fleet: 14 declared now.' 'The fleet: 14 declared currently.' 'The fleet: 14 declared so far.' || { echo "box gm setup failed"; exit 2; }
mkbox ge 'The fleet: **22** declared today' 'The fleet: 22 declared now.' 'The fleet: 22 declared currently.' 'The fleet: 22 declared so far.' || { echo "box ge setup failed"; exit 2; }
mkbox gh 'The fleet: **14** declared today (historical).' 'The fleet: 14 declared so far (historical).' || { echo "box gh setup failed"; exit 2; }
mkbox hk 'The fleet: declared: 14' 'The fleet: 14 submodules declared.' 'The fleet: fourteen declared.' 'The fleet has 14
declared.' || { echo "box hk setup failed"; exit 2; }
for x in fm fe fh gm ge gh hk; do
  rc=$(run "$T/$x" "$T/$x.out")
  case "$rc" in 0|1) ;; *) echo "class rc $rc on sandbox $x"; exit 2 ;; esac
  grep -q '^INSPECTED ' "$T/$x.out" || { echo "class printed no INSPECTED on sandbox $x"; exit 2; }
done
# a silent clause proves nothing unless the class inspected at least one document in the box
for x in fm fe fh gm ge gh hk; do grep -q '^INSPECTED [1-9]' "$T/$x.out" || { echo "sandbox $x: class inspected no document"; exit 2; }; done
fl=0
for n in 3 5; do
  if mismatch "$T/fm.out" CLAUDE.md "$n" 13 22; then fl=$((fl+1)); else echo "F: NOT detected: line $n '13 ... declared' vs 22 (need finding naming 13 and 22)"; fi
done
if mismatch "$T/fm.out" CLAUDE.md 7 14 22; then fl=$((fl+1)); else echo "F: NOT detected: line 7 '14 submodules were declared' vs 22"; fi
echo "F: B1 planted mismatches detected $fl of 3 (need 3)"
[ "$fl" -ge 3 ] || bad=1
if anymismatch "$T/fe.out"; then echo "F: FAIL equal-count control (22) reported as mismatch"; bad=1; else echo "F: PASS equal-count control silent"; fi
if anymismatch "$T/fh.out"; then echo "F: FAIL (historical) control reported as mismatch"; bad=1; else echo "F: PASS (historical) control silent"; fi
gl=0
for n in 3 5 7 9; do
  if mismatch "$T/gm.out" CLAUDE.md "$n" 14 22; then gl=$((gl+1)); else echo "G: NOT detected: line $n '14 declared <adverb>' vs 22 (need finding naming 14 and 22)"; fi
done
echo "G: B2 planted mismatches detected $gl of 4 (need 4)"
[ "$gl" -ge 4 ] || bad=1
if anymismatch "$T/ge.out"; then echo "G: FAIL equal-count control (22) reported as mismatch"; bad=1; else echo "G: PASS equal-count control silent"; fi
if anymismatch "$T/gh.out"; then echo "G: FAIL (historical) control reported as mismatch"; bad=1; else echo "G: PASS (historical) control silent"; fi
if anymismatch "$T/hk.out"; then echo "H: FAIL known-invisible shapes now produce a mismatch finding (recall cost pin changed; update deliberately)"; bad=1; else echo "H: PASS known-invisible shapes stay silent (pinned recall cost)"; fi
exit "$bad"
