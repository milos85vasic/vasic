#!/usr/bin/env bash
# VSC-353 probe (check author: t353-check-author-2). Run from the root of the tree under test.
# Everything is measured in throwaway git repos built here; no carrier of the tree under test is read.
# Class under test: $VSC353_CLASS (default ./scripts/zero-gap-class-stale-figures.sh).
#   (A) >=3 planted "<n> declared"/"<n> owned" rows are reported; >=2 clean controls (withdrawal marker on the
#       NEXT line; exit-code MEANING line) are not reported.
#   (B) REAL MISMATCH: .gitmodules declares exactly 22 paths; an unmarked current-tense line claims "14 declared".
#       The class MUST emit a FINDING on that line whose text names BOTH 14 and 22 and says mismatch/disagrees.
#   (C) equal-counts control: "22 declared" against 22 paths -> no mismatch finding.
#   (D) historical-marked "14 declared. (historical)" against 22 paths -> no mismatch finding (recall tradeoff pinned on
#       purpose). The line is one the comparison SEES ("14 declared." is a figure and a match); D-mut disables the skip
#       rule in a copy of the class and requires the mismatch to appear, proving the skip rule is what keeps D silent.
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
printf '# Probe carrier\n\nThe fleet has 14 declared. (historical)\n' >"$T/d/CLAUDE.md"
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
# D-mut: a copy of the class with the skip rule disabled MUST report the D line (else D's silence proves nothing).
mkdir -p "$T/dmut" || exit 2
cp "$CLS" "$T/dmut/zero-gap-class-stale-figures.sh" && cp "$(dirname "$CLS")/verify-claim-ledger.sh" "$T/dmut/" || { echo "D-mut: cannot copy the class and its ledger gate"; exit 2; }
sed -i 's/if m is None or SKIP[.]search(s)/if m is None/' "$T/dmut/zero-gap-class-stale-figures.sh"
if cmp -s "$CLS" "$T/dmut/zero-gap-class-stale-figures.sh"; then echo "D-mut: inoperative mutation (skip-rule anchor not found)"; exit 2; fi
(cd "$SRC" && timeout 300 bash "$T/dmut/zero-gap-class-stale-figures.sh" --root "$T/d" >"$T/dmut.out" 2>"$T/dmut.err")
if mismatch "$T/dmut.out" CLAUDE.md 3 14 22; then echo "D-mut: PASS with the skip rule disabled the D line IS a mismatch, so the skip rule is what keeps D silent"; else echo "D-mut: FAIL the D line is hidden even without the skip rule (D proves nothing)"; bad=1; fi
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
# ---- Clause I (round 4): case-insensitive comparison and the B1 verb forms. Box ci: every line must be a mismatch vs 22.
#   "14 Declared." / "13 GITLINKS ARE DECLARED" / "13 gitlinks are Declared"; "have been", "has been", "are now", "were now".
mkbox ci '14 Declared.' '13 GITLINKS ARE DECLARED' '13 gitlinks are Declared.' 'The fleet: 13 gitlinks have been declared.' 'The fleet: 14 submodules has been declared.' 'The fleet: 13 gitlinks are now declared.' 'The fleet: 14 submodules were now declared.' || { echo "box ci setup failed"; exit 2; }
mkbox ce 'The fleet: 22 Gitlinks Have Been Declared.' '22 DECLARED' 'The fleet: 22 submodules are now declared.' || { echo "box ce setup failed"; exit 2; }
for x in ci ce; do
  rc=$(run "$T/$x" "$T/$x.out")
  case "$rc" in 0|1) ;; *) echo "class rc $rc on sandbox $x"; exit 2 ;; esac
  grep -q '^INSPECTED [1-9]' "$T/$x.out" || { echo "sandbox $x: class inspected no document"; exit 2; }
done
il=0
for spec in 3:14 5:13 7:13 9:13 11:14 13:13 15:14; do
  n=${spec%%:*}; v=${spec##*:}
  if mismatch "$T/ci.out" CLAUDE.md "$n" "$v" 22; then il=$((il+1)); else echo "I: NOT detected: ci line $n (claim $v vs 22)"; fi
done
echo "I: case/verb-form planted mismatches detected $il of 7 (need 7)"
[ "$il" -ge 7 ] || bad=1
if anymismatch "$T/ce.out"; then echo "I: FAIL equal-count (22) control in mixed case / new verb forms reported as mismatch"; bad=1; else echo "I: PASS equal-count control silent"; fi
# ---- Clause H2 (round 4): every recall cost listed in the class header is pinned silent HERE, each with a paired control
#   (the same claim without the exemption IS a mismatch), so the silence is caused by the listed cost and not by a dead box.
#   box hs: lines 3 '13 declared in <place>', 5 '13 declared entries', 7 '13 declared owned', 9-10 noun wrapped onto the next
#   line, 12-13 verb wrapped onto the next line, 15 an unrelated skip word on the same line, 17-18 deictic next-line exemption;
#   controls: 20 '13 declared today' without a skip word is detected, 22-23 the same B1 line followed by a non-deictic line is detected.
mkbox hs 'The fleet: 13 declared in .gitmodules.' 'The fleet: 13 declared entries.' 'The fleet: 13 declared owned.' 'The fleet has 13
gitlinks are declared.' 'The fleet: 13 gitlinks are
declared.' 'The fleet: 13 declared today; the old 99 checks reading is WITHDRAWN.' 'The fleet: 13 gitlinks are declared.
That figure is WITHDRAWN.' 'The fleet: 13 declared today; the old 99 checks reading is current.' 'The fleet: 13 gitlinks are declared.
That is the current reading.' || { echo "box hs setup failed"; exit 2; }
# box hc: dated section-3 caption exemption in CONTINUATION.md (point-in-time.tsv row with the marker phrase)
mkbox hc 'unused' || { echo "box hc setup failed"; exit 2; }
printf 'path\treason\nCONTINUATION.md\town dated caption entries of section 3 are point-in-time, true when written\n' >"$T/hc/docs/zero-gap-pit.tmp" && mkdir -p "$T/hc/docs/zero-gap" && mv "$T/hc/docs/zero-gap-pit.tmp" "$T/hc/docs/zero-gap/point-in-time.tsv" || exit 2
printf '## §3 Active work\n\n### DATED ENTRY — 2026-09-03\n\nThe fleet: 13 gitlinks are declared.\n\n### UNDATED ENTRY\n\nThe fleet: 13 gitlinks are declared.\n' >"$T/hc/CONTINUATION.md" || exit 2
mk "$T/hc" || { echo "box hc commit failed"; exit 2; }
for x in hs hc; do
  rc=$(run "$T/$x" "$T/$x.out")
  case "$rc" in 0|1) ;; *) echo "class rc $rc on sandbox $x"; exit 2 ;; esac
  grep -q '^INSPECTED [1-9]' "$T/$x.out" || { echo "sandbox $x: class inspected no document"; exit 2; }
done
hb=0
for n in 20 22; do
  if mismatch "$T/hs.out" CLAUDE.md "$n" 13 22; then :; else echo "H2: control line $n NOT detected (box is dead; silences below prove nothing)"; hb=1; fi
done
if mismatch "$T/hc.out" CONTINUATION.md 9 13 22; then :; else echo "H2: control line CONTINUATION.md:9 (undated entry) NOT detected"; hb=1; fi
for spec in 3:in-place 5:entries 7:owned 9:noun-wrap 12:verb-wrap 15:unrelated-skip-word 17:deictic-next-line; do
  n=${spec%%:*}; w=${spec##*:}
  if mismatch "$T/hs.out" CLAUDE.md "$n" 13 22; then echo "H2: FAIL '$w' (line $n) now produces a mismatch; the header recall cost is no longer true"; hb=1; else echo "H2: PASS '$w' pinned silent"; fi
done
if mismatch "$T/hc.out" CONTINUATION.md 5 13 22; then echo "H2: FAIL dated section-3 caption line now produces a mismatch"; hb=1; else echo "H2: PASS dated section-3 caption exemption pinned silent"; fi
[ "$hb" -eq 0 ] || bad=1
# ---- Clause J (round 5): markdown markup around the number, the verb and "declared"; compound noun; parenthesis.
#   box jm: every line is a mismatch vs 22 (claims 13, except the third-from-... "14 declared (current)." which claims 14);
#   box je: the same lines with 22 (must be silent). Then a copy of the class WITHOUT markup tolerance (MK empty) must
#   lose the markup lines. Lines are separated by '|' here, so the table-cell shape is pinned in the PROVE battery instead.
mkbox_pipe() { # mkbox_pipe <name> <pipe-separated lines>
  _n=$1; _ifs=$IFS; IFS='|'; set -f; set -- $2; set +f; IFS=$_ifs; mkbox "$_n" "$@"
}
JL='13 gitlinks are **declared**|13 gitlinks **are** declared|13 gitlinks are _declared_.|13 gitlinks `are declared`|_13_ gitlinks are declared|13 submodule paths are declared|14 declared (current).|13 declared **(current)**|13 declared **submodules**|13 modules are _now_ declared|**13 gitlinks are declared**|13 **gitlinks** are declared|**13 gitlinks** are declared|13 Submodule Paths Are Declared|13 submodule is declared'
mkbox_pipe jm "$JL" || { echo "box jm setup failed"; exit 2; }
mkbox_pipe je "$(printf '%s' "$JL" | sed 's/1[34]/22/g')" || { echo "box je setup failed"; exit 2; }
for x in jm je; do
  rc=$(run "$T/$x" "$T/$x.out")
  case "$rc" in 0|1) ;; *) echo "class rc $rc on sandbox $x"; exit 2 ;; esac
  grep -q '^INSPECTED [1-9]' "$T/$x.out" || { echo "sandbox $x: class inspected no document"; exit 2; }
done
jl=0; jn=0
while IFS= read -r _l; do
  jn=$((jn+1)); ln=$((1 + 2 * jn)); v=13; case "$_l" in 14*) v=14 ;; esac
  if mismatch "$T/jm.out" CLAUDE.md "$ln" "$v" 22; then jl=$((jl+1)); else echo "J: NOT detected line $ln: $_l"; fi
done < <(printf '%s\n' "$JL" | tr '|' '\n')
echo "J: markup/compound/parenthesis planted mismatches detected $jl of $jn (need all)"
[ "$jl" -eq "$jn" ] || bad=1
if anymismatch "$T/je.out"; then echo "J: FAIL equal-count control (22) reported as mismatch"; bad=1; else echo "J: PASS equal-count control silent"; fi
# J-mut: with MK emptied (no markup tolerance anywhere) the markup lines must be lost, else J does not test markup.
mkdir -p "$T/jmut" || exit 2
cp "$CLS" "$T/jmut/zero-gap-class-stale-figures.sh" && cp "$(dirname "$CLS")/verify-claim-ledger.sh" "$T/jmut/" || { echo "J-mut: cannot copy the class"; exit 2; }
sed -i 's/^MK = .*/MK = r""/' "$T/jmut/zero-gap-class-stale-figures.sh"
if cmp -s "$CLS" "$T/jmut/zero-gap-class-stale-figures.sh"; then echo "J-mut: inoperative mutation"; exit 2; fi
(cd "$SRC" && timeout 300 bash "$T/jmut/zero-gap-class-stale-figures.sh" --root "$T/jm" >"$T/jmut.out" 2>"$T/jmut.err")
jlost=0
for ln in 3 5 7 9 11 21 25 27; do mismatch "$T/jmut.out" CLAUDE.md "$ln" 13 22 || jlost=$((jlost+1)); done
if [ "$jlost" -eq 8 ]; then echo "J-mut: PASS removing markup tolerance loses all 8 markup-dependent lines (3 5 7 9 11 21 25 27); the other 7 do not depend on markup"; else echo "J-mut: FAIL removing markup tolerance lost only $jlost of the 8 markup-dependent lines"; bad=1; fi
# ---- Clause H3 (round 5): the shapes the grammar deliberately does NOT see, each pinned silent with a paired twin
#   (the same claim in the supported form IS a mismatch). box hz holds the silent shapes, box ht their twins, same line numbers.
HZ='13 gitlinks are all declared.|13 gitlinks are not declared.|Thirteen gitlinks are declared.|[13](https://example.invalid/x) gitlinks are declared.|<b>13</b> gitlinks are declared.|13.5 gitlinks are declared.|13 gitlinks (are declared).|13 gitlinks, all declared.|13-gitlink fleet is declared.|13 gitlinks are ~~declared~~.|13 gitlinks are ==declared==.|13 gitlinks are "declared".|13 owned gitlinks are declared.|13 gitlinks will be declared.|13 gitlinks got declared.|13 path-entries are declared.'
mkbox_pipe hz "$HZ" || { echo "box hz setup failed"; exit 2; }
mkbox_pipe ht "$(printf '%s' "$HZ" | awk -F'|' '{for(i=1;i<=NF;i++) printf "%s13 gitlinks are declared.", (i>1?"|":"")}')" || { echo "box ht setup failed"; exit 2; }
for x in hz ht; do
  rc=$(run "$T/$x" "$T/$x.out")
  case "$rc" in 0|1) ;; *) echo "class rc $rc on sandbox $x"; exit 2 ;; esac
  grep -q '^INSPECTED [1-9]' "$T/$x.out" || { echo "sandbox $x: class inspected no document"; exit 2; }
done
hn=0; hb3=0
while IFS= read -r _l; do
  hn=$((hn+1)); ln=$((1 + 2 * hn))
  if ! mismatch "$T/ht.out" CLAUDE.md "$ln" 13 22; then echo "H3: twin line $ln NOT detected (the pair proves nothing)"; hb3=1; fi
  if mismatch "$T/hz.out" CLAUDE.md "$ln" 13 22; then echo "H3: FAIL silent shape now produces a mismatch (line $ln: $_l); the header recall cost is no longer true"; hb3=1; fi
done < <(printf '%s\n' "$HZ" | tr '|' '\n')
[ "$hb3" -eq 0 ] && echo "H3: PASS $hn silent shapes pinned, each with a detected twin"
[ "$hb3" -eq 0 ] || bad=1
exit "$bad"
