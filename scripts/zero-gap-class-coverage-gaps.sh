#!/usr/bin/env bash
# zero-gap-class-coverage-gaps.sh — sweep class `coverage-gaps` (feature 010, task T032).
#
# WHAT IT DETECTS. Every part of the test-kind coverage matrix docs/zero-gap/coverage.tsv
# (subject x test kind; one row `subject<TAB>test_kind<TAB>status<TAB>ref`, status one of
# check | n/a | gap | could-not-run, data-model.md "CoverageCell") that is not honestly covered:
#   gap                          FINDING medium test-coverage  (an untested part, names the missing test kind)
#   check, ref not resolving     FINDING high false-evidence   ("covered" by a check that does not exist)
#   n/a without a reason         FINDING medium test-coverage  (a silent exemption)
#   required kind row absent     FINDING medium test-coverage  (a blank cell in the matrix)
#   could-not-run[:tool]         COULD-NOT-INSPECT naming the tool (never a pass, never a finding)
#   blank/unknown status, malformed row, duplicate cell, empty matrix, unreadable file
#                                COULD-NOT-INSPECT (fail closed)
# The twelve required kinds are: unit integration e2e contract security accessibility perf-load
# stress-chaos mutation determinism regression manual-qa-readiness (extra kinds are allowed).
# SOURCE of the twelve: specs/010-zero-gap-verified-closure/spec.md, User Story 3 (the parenthesised
# list: unit, integration, end-to-end, contract, security, accessibility, performance and load, stress
# and chaos, mutation, determinism, regression, manual-QA readiness) and FR-010 ("the twelve named in
# User Story 3"); the kebab-case ids are this class's spelling. SINGLE SOURCE with T052: the matrix
# generator scripts/zero-gap-coverage.sh (T052, not yet written) MUST emit exactly these ids; when it
# exists, REQ_KINDS below is to be read from it (or from a tracked kinds file both read) instead of
# being restated here — until then this constant is the only copy.
# A `gap:<note>` status is a gap (a finding); the note is quoted in the description.
#
# POPULATION (and why). The cells of the matrix: for every subject named in coverage.tsv, the
# twelve required kinds plus every extra kind the file lists for it, as typed tokens
# `cell:<subject>:<kind>` (subject and kind percent-encoded). Required kinds are part of the
# population even when their row is missing, because a missing row is itself a defect that needs a
# locatable subject. This is BROADER than "every gap cell" (the docs/zero-gap/sweep-classes.tsv row
# text): every cell is inspected, and gap cells, dangling check refs, n/a without a reason and
# missing required rows are all findings (controller ruling 2026-09-26, progress.yml "Class review
# rev-gates": accept the broader population and correct the row text). Source: docs/zero-gap/coverage.tsv at --root only (never a hand list). The
# matrix generator (scripts/zero-gap-coverage.sh, T052) does not exist yet: while the file is absent
# the class reports COULD-NOT-INSPECT `coverage.tsv absent` (rc 2), never clean, never a finding.
#
# REF RESOLUTION. A `check` cell's ref is one id or a comma list; each must be a `check` or `debt`
# row id of scripts/check-registry.tsv, or a file tracked at --root (git ls-files; in corpus mode a
# file under the corpus). A ref starting with `/` or `./` or containing a `..` segment never resolves.
# `n/a` needs a reason in the status (`n/a:<reason>`) or in ref (not empty, not `-`);
# `could-not-run` names its tool in the status suffix or in ref.
#
# Usage (class contract, docs/zero-gap/README.md):
#   --root <dir> --emit-population | --root <dir> | --root <dir> --corpus <dir> | --prove-failure
# Exit: 0 clean (non-empty population fully inspected, no finding), 1 at least one FINDING,
#       2 could not determine. A finding outranks an undetermined.
#
# WHAT IT DOES NOT SEE. Whether a resolving check actually exercises the subject's kind (that is the
# matrix generator's zero-case rule, FR-011); subjects absent from coverage.tsv (the generator owns
# subject enumeration); refs of `gap` cells (item ids are not resolved); the contents of a tracked
# ref file. It writes only under $TMPDIR and never into --root.
set -uo pipefail
export LC_ALL=C

# >>> zg_pct_encode (feature 010 class contract; copy verbatim)
# zg_pct_encode_z: NUL-separated raw items on stdin -> one canonical token per line.
# Every byte outside A-Z a-z 0-9 . _ ~ / + : @ , = - becomes %XX (uppercase hex).
zg_pct_encode_z() {
    LC_ALL=C od -An -v -tx1 | LC_ALL=C awk '
        BEGIN { hx = "0123456789abcdef"; safe = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._~/+:@,=-"; tok = ""; pending = 0 }
        { for (i = 1; i <= NF; i++) {
              if ($i == "00") { print tok; tok = ""; pending = 0; continue }
              pending = 1
              v = (index(hx, substr($i, 1, 1)) - 1) * 16 + index(hx, substr($i, 2, 1)) - 1
              c = (v > 32 && v < 127) ? sprintf("%c", v) : ""
              if (c != "" && index(safe, c) > 0) tok = tok c; else tok = tok "%" toupper($i)
          } }
        END { if (pending) print tok }'
}
# zg_pct_encode <string>: one item -> one canonical token.
zg_pct_encode() { printf '%s\0' "$1" | zg_pct_encode_z; }
# <<< zg_pct_encode

CLASS_ID=coverage-gaps
REQ_KINDS="unit integration e2e contract security accessibility perf-load stress-chaos mutation determinism regression manual-qa-readiness"
REL_CSV=docs/zero-gap/coverage.tsv
REL_REG=scripts/check-registry.tsv
SELF=$(cd "$(dirname "$0")" && pwd)/$(basename "$0")

ROOT="" CORPUS="" EMIT=0 PROVE=0
while [ $# -gt 0 ]; do
    case "$1" in
        --root) ROOT="${2:-}"; shift 2 ;;
        --corpus) CORPUS="${2:-}"; shift 2 ;;
        --emit-population) EMIT=1; shift ;;
        --prove-failure) PROVE=1; shift ;;
        *) echo "COULD-NOT-INSPECT - unknown argument: $(zg_pct_encode "$1")"; echo "INSPECTED 0"; echo "POPULATION-SHA e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"; exit 2 ;;
    esac
done

# ── §1.1 paired proof: --prove-failure ───────────────────────────────────────────────────────
# Every mutation runs on a THROWAWAY copy under one mktemp -d (removed by the trap on exit); the
# live tree is only READ (its owned files are hashed before and after: byte-identical).
prove_failure() {
    local pass=0 fail=0 out rc LIVE h0 h1 REQ="$REQ_KINDS" k n d
    T=$(mktemp -d "${TMPDIR:-/tmp}/zg-covgaps-proof.XXXXXX") || { echo "prove-failure: cannot create a scratch directory" >&2; return 2; }
    trap '[ -n "${T:-}" ] && rm -rf "$T"' EXIT INT TERM
    mkdir -p "$T/tmp"
    LIVE=$(cd "$(dirname "$SELF")/.." && pwd)
    ok() { pass=$((pass + 1)); echo "  PASS $1"; }
    bad() { fail=$((fail + 1)); echo "  FAIL $1"; }
    full_rows() { for k in $REQ; do printf '%s\t%s\tcheck\tchk-real\n' "$1" "$k"; done; }
    mkbase() { # <dir>: a clean single-subject matrix, its registry and one tracked-style file
        mkdir -p "$1/docs/zero-gap" "$1/scripts"
        printf 'check\tchk-real\tscripts/entry.sh\tflag\t--prove-failure\t--root /nonexistent\n' >"$1/scripts/check-registry.tsv"
        printf '#!/usr/bin/env bash\nexit 0\n' >"$1/scripts/entry.sh"
        full_rows s1 >"$1/docs/zero-gap/coverage.tsv"
    }
    # setrow <dir> <kind> <status> <ref>: replace subject s1's row of <kind>
    setrow() { awk -F'\t' -v OFS='\t' -v k="$2" -v s="$3" -v r="$4" '$1 == "s1" && $2 == k { print "s1", k, s, r; next } { print }' "$1/docs/zero-gap/coverage.tsv" >"$1/c.new" && mv "$1/c.new" "$1/docs/zero-gap/coverage.tsv"; }
    runc() { # <dir> [args...]: corpus-mode run; sets out rc
        d=$1; shift
        out=$(env -i PATH="$PATH" HOME="${HOME:-/}" TMPDIR="$T/tmp" LC_ALL=C "$BASH" "$SELF" --root "$T" --corpus "$d" "$@" 2>"$T/err"); rc=$?
    }
    has() { grep -qF -- "$1" <<<"$out"; }
    nofind() { ! grep -q '^FINDING ' <<<"$out"; }
    h0=$(find "$LIVE/docs/zero-gap/coverage.tsv" "$SELF" "$LIVE/_tests/fixtures/zero-gap/coverage-gaps" -type f -exec sha256sum {} + 2>/dev/null | LC_ALL=C sort | sha256sum)

    echo "coverage-gaps paired proof"
    # C0 control
    mkbase "$T/c0"; runc "$T/c0"
    if [ "$rc" -eq 0 ] && nofind && ! has COULD-NOT-INSPECT && has "INSPECTED 12"; then ok "C0 control: clean 12-cell matrix => rc 0, nothing reported, 12 inspected"; else bad "C0 rc=$rc out=$out"; fi
    # C1 gap
    mkbase "$T/c1"; setrow "$T/c1" unit gap item-9; runc "$T/c1"
    if [ "$rc" -eq 1 ] && has "FINDING coverage-gaps medium test-coverage cell:s1:unit " && has "unit"; then ok "C1 gap cell => FINDING medium test-coverage at cell:s1:unit"; else bad "C1 rc=$rc out=$out"; fi
    # C2 dangling check id
    mkbase "$T/c2"; setrow "$T/c2" e2e check chk-ghost; runc "$T/c2"
    if [ "$rc" -eq 1 ] && has "FINDING coverage-gaps high false-evidence cell:s1:e2e "; then ok "C2 check cell naming an unregistered id => FINDING high false-evidence"; else bad "C2 rc=$rc out=$out"; fi
    # C3 dangling path refs
    mkbase "$T/c3"; setrow "$T/c3" e2e check scripts/nowhere.sh; setrow "$T/c3" contract check ../entry.sh; setrow "$T/c3" security check /etc/passwd; runc "$T/c3"
    if [ "$rc" -eq 1 ] && has "high false-evidence cell:s1:e2e " && has "high false-evidence cell:s1:contract " && has "high false-evidence cell:s1:security "; then ok "C3 absent path, .. escape and absolute path never resolve"; else bad "C3 rc=$rc out=$out"; fi
    mkbase "$T/c3b"; setrow "$T/c3b" e2e check scripts/entry.sh; setrow "$T/c3b" contract check chk-real,scripts/entry.sh; runc "$T/c3b"
    if [ "$rc" -eq 0 ]; then ok "C3b guard: an existing file ref and a comma list of resolving refs are clean"; else bad "C3b rc=$rc out=$out"; fi
    mkbase "$T/c3c"; setrow "$T/c3c" e2e check chk-real,chk-ghost; runc "$T/c3c"
    if [ "$rc" -eq 1 ] && has "high false-evidence cell:s1:e2e "; then ok "C3c one dangling id inside a comma list is a finding"; else bad "C3c rc=$rc out=$out"; fi
    mkbase "$T/c3d"; setrow "$T/c3d" e2e check ""; runc "$T/c3d"
    if [ "$rc" -eq 1 ] && has "high false-evidence cell:s1:e2e "; then ok "C3d check cell with an empty ref is a finding"; else bad "C3d rc=$rc out=$out"; fi
    # C4 n/a
    mkbase "$T/c4"; setrow "$T/c4" accessibility n/a ""; runc "$T/c4"
    if [ "$rc" -eq 1 ] && has "FINDING coverage-gaps medium test-coverage cell:s1:accessibility "; then ok "C4 n/a without a reason => FINDING medium"; else bad "C4 rc=$rc out=$out"; fi
    mkbase "$T/c4b"; setrow "$T/c4b" accessibility n/a:no-ui ""; setrow "$T/c4b" perf-load n/a "no load path"; runc "$T/c4b"
    if [ "$rc" -eq 0 ]; then ok "C4b guard: n/a:<reason> and n/a + reason in ref are clean"; else bad "C4b rc=$rc out=$out"; fi
    mkbase "$T/c4c"; setrow "$T/c4c" accessibility n/a -; runc "$T/c4c"
    if [ "$rc" -eq 1 ] && has "cell:s1:accessibility "; then ok "C4c n/a with ref '-' has no reason"; else bad "C4c rc=$rc out=$out"; fi
    # C5 missing kind row
    mkbase "$T/c5"; awk -F'\t' '$2 != "e2e"' "$T/c5/docs/zero-gap/coverage.tsv" >"$T/c5/x" && mv "$T/c5/x" "$T/c5/docs/zero-gap/coverage.tsv"; runc "$T/c5"
    if [ "$rc" -eq 1 ] && has "FINDING coverage-gaps medium test-coverage cell:s1:e2e " && has "INSPECTED 12"; then ok "C5 a required kind with no row => FINDING for that cell, still 12 cells inspected"; else bad "C5 rc=$rc out=$out"; fi
    # C6 absent file
    mkbase "$T/c6"; rm "$T/c6/docs/zero-gap/coverage.tsv"; runc "$T/c6"
    if [ "$rc" -eq 2 ] && nofind && has "COULD-NOT-INSPECT docs/zero-gap/coverage.tsv coverage.tsv absent" && has "INSPECTED 0"; then ok "C6 absent coverage.tsv => COULD-NOT-INSPECT rc 2, no finding, never clean"; else bad "C6 rc=$rc out=$out"; fi
    # C7 could-not-run
    mkbase "$T/c7"; setrow "$T/c7" perf-load could-not-run:k6 ""; runc "$T/c7"
    if [ "$rc" -eq 2 ] && nofind && has "COULD-NOT-INSPECT cell:s1:perf-load " && has "k6"; then ok "C7 could-not-run:k6 => COULD-NOT-INSPECT naming the tool, rc 2"; else bad "C7 rc=$rc out=$out"; fi
    mkbase "$T/c7b"; setrow "$T/c7b" perf-load could-not-run ab6; runc "$T/c7b"
    if [ "$rc" -eq 2 ] && has "ab6"; then ok "C7b could-not-run with the tool in ref names it too"; else bad "C7b rc=$rc out=$out"; fi
    # C8 malformed / blank / unknown / empty
    mkbase "$T/c8"; printf 's1\tunit\tcheck\n' >>"$T/c8/docs/zero-gap/coverage.tsv"; runc "$T/c8"
    if [ "$rc" -eq 2 ] && nofind && has "COULD-NOT-INSPECT docs/zero-gap/coverage.tsv:"; then ok "C8 a 3-field row => COULD-NOT-INSPECT naming the line, rc 2"; else bad "C8 rc=$rc out=$out"; fi
    mkbase "$T/c8b"; setrow "$T/c8b" unit "" chk-real; runc "$T/c8b"
    if [ "$rc" -eq 2 ] && nofind && has "COULD-NOT-INSPECT cell:s1:unit "; then ok "C8b blank status => COULD-NOT-INSPECT, rc 2"; else bad "C8b rc=$rc out=$out"; fi
    mkbase "$T/c8c"; setrow "$T/c8c" unit maybe chk-real; runc "$T/c8c"
    if [ "$rc" -eq 2 ] && nofind && has "COULD-NOT-INSPECT cell:s1:unit "; then ok "C8c unknown status => COULD-NOT-INSPECT, rc 2"; else bad "C8c rc=$rc out=$out"; fi
    mkbase "$T/c8d"; printf 'subject\ttest_kind\tstatus\tref\n' >"$T/c8d/docs/zero-gap/coverage.tsv"; runc "$T/c8d"
    if [ "$rc" -eq 2 ] && nofind && has "INSPECTED 0"; then ok "C8d header-only matrix (zero cells) => rc 2, never clean"; else bad "C8d rc=$rc out=$out"; fi
    mkbase "$T/c8e"; printf 's1\tunit\tcheck\tchk-real\r\n' >>"$T/c8e/docs/zero-gap/coverage.tsv"; runc "$T/c8e"
    if [ "$rc" -eq 2 ] && nofind; then ok "C8e a control character (CR) in a row => rc 2"; else bad "C8e rc=$rc out=$out"; fi
    mkbase "$T/c8f"; printf 's1\tunit\tcheck\tchk-real bad\377byte\n' >>"$T/c8f/docs/zero-gap/coverage.tsv"; runc "$T/c8f"
    if [ "$rc" -eq 2 ] && nofind; then ok "C8f invalid UTF-8 => rc 2"; else bad "C8f rc=$rc out=$out"; fi
    mkbase "$T/c8g"; printf 's:x\tunit\tcheck\tchk-real\n' >>"$T/c8g/docs/zero-gap/coverage.tsv"; runc "$T/c8g"
    if [ "$rc" -eq 2 ] && nofind; then ok "C8g a ':' in a subject (ambiguous token) => rc 2"; else bad "C8g rc=$rc out=$out"; fi
    mkbase "$T/c8h"; printf 's1\tunit\tgap\titem-1\n' >>"$T/c8h/docs/zero-gap/coverage.tsv"; runc "$T/c8h"
    if [ "$rc" -eq 2 ] && has "COULD-NOT-INSPECT docs/zero-gap/coverage.tsv:" && has "duplicate"; then ok "C8h a duplicate cell => COULD-NOT-INSPECT, rc 2"; else bad "C8h rc=$rc out=$out"; fi
    # C9 extra column tolerated, extra kind allowed and counted
    mkbase "$T/c9"; sed 's/$/\tnote/' "$T/c9/docs/zero-gap/coverage.tsv" >"$T/c9/x" && mv "$T/c9/x" "$T/c9/docs/zero-gap/coverage.tsv"; printf 's1\tfuzz\tcheck\tchk-real\tnote\n' >>"$T/c9/docs/zero-gap/coverage.tsv"; runc "$T/c9"
    if [ "$rc" -eq 0 ] && has "INSPECTED 13"; then ok "C9 additive column tolerated; an extra kind is a 13th inspected cell"; else bad "C9 rc=$rc out=$out"; fi
    # C10 finding outranks an undetermined
    mkbase "$T/c10"; setrow "$T/c10" unit gap item-9; setrow "$T/c10" perf-load could-not-run:k6 ""; runc "$T/c10"
    if [ "$rc" -eq 1 ] && has "FINDING coverage-gaps medium test-coverage cell:s1:unit " && has "COULD-NOT-INSPECT cell:s1:perf-load "; then ok "C10 finding + undetermined => rc 1, both lines printed"; else bad "C10 rc=$rc out=$out"; fi
    # C11 tool / root faults
    mkbase "$T/c11"; out=$(env -i PATH="$T/emptybin" HOME="${HOME:-/}" TMPDIR="$T/tmp" LC_ALL=C "$BASH" "$SELF" --root "$T" --corpus "$T/c11" 2>/dev/null); rc=$?
    if [ "$rc" -eq 2 ] && nofind && has "COULD-NOT-INSPECT"; then ok "C11 tools missing from PATH => rc 2, never clean"; else bad "C11 rc=$rc out=$out"; fi
    out=$(env -i PATH="$PATH" HOME="${HOME:-/}" TMPDIR="$T/tmp" LC_ALL=C "$BASH" "$SELF" --root /nonexistent 2>/dev/null); rc=$?
    if [ "$rc" -eq 2 ] && nofind && has "INSPECTED 0" && has "POPULATION-SHA e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"; then ok "C12 --root /nonexistent => rc 2, INSPECTED 0 and POPULATION-SHA still printed"; else bad "C12 rc=$rc out=$out"; fi
    # C20 a gap cell carrying a note is still a gap (a finding, never an unknown status)
    mkbase "$T/c20"; setrow "$T/c20" unit gap:needs-a-harness item-9; runc "$T/c20"
    if [ "$rc" -eq 1 ] && has "FINDING coverage-gaps medium test-coverage cell:s1:unit " && ! has "COULD-NOT-INSPECT"; then ok "C20 gap:<note> => FINDING medium test-coverage, not COULD-NOT-INSPECT"; else bad "C20 rc=$rc out=$out"; fi
    # C21 the ref-safety rule decides even when the registry cannot be read: ../x, ./x and /x are
    # dangling (a finding), never 'undetermined'; and a registry id spelled ../x never resolves one
    mkbase "$T/c21"; rm "$T/c21/scripts/check-registry.tsv"; setrow "$T/c21" e2e check ../entry.sh; setrow "$T/c21" unit check chk-real; runc "$T/c21"
    if [ "$rc" -eq 1 ] && has "high false-evidence cell:s1:e2e " && has "COULD-NOT-INSPECT cell:s1:unit "; then ok "C21 registry unreadable: a ../ ref is still a finding, a plain id is undetermined"; else bad "C21 rc=$rc out=$out"; fi
    mkbase "$T/c21b"; printf 'check\t./scripts/entry.sh\tscripts/entry.sh\tflag\t--prove-failure\t--root /nonexistent\n' >>"$T/c21b/scripts/check-registry.tsv"; setrow "$T/c21b" e2e check ./scripts/entry.sh; runc "$T/c21b"
    if [ "$rc" -eq 1 ] && has "high false-evidence cell:s1:e2e "; then ok "C21b a registry id spelled ./path never resolves a ./path ref"; else bad "C21b rc=$rc out=$out"; fi
    mkbase "$T/c12"; rm "$T/c12/scripts/check-registry.tsv"; setrow "$T/c12" unit check chk-real; runc "$T/c12"
    if [ "$rc" -eq 2 ] && nofind && has "check-registry.tsv"; then ok "C13 registry absent while check cells exist => rc 2, no invented finding"; else bad "C13 rc=$rc out=$out"; fi
    # C14 emit-population
    mkbase "$T/c14"; printf 'svc x\tunit\tgap\titem-1\n' >>"$T/c14/docs/zero-gap/coverage.tsv"
    e=$(env -i PATH="$PATH" HOME="${HOME:-/}" TMPDIR="$T/tmp" LC_ALL=C "$BASH" "$SELF" --root "$T" --corpus "$T/c14" --emit-population 2>/dev/null); erc=$?
    runc "$T/c14"; n=$(printf '%s\n' "$e" | awk 'END{print NR}')
    if [ "$erc" -eq 0 ] && [ "$n" -eq 24 ] && printf '%s\n' "$e" | LC_ALL=C sort -u | cmp -s - <(printf '%s\n' "$e") && grep -qx 'cell:svc%20x:unit' <<<"$e" && has "POPULATION-SHA $(printf '%s\n' "$e" | sha256sum | cut -d' ' -f1)" && has "INSPECTED 24"; then ok "C14 --emit-population: 24 sorted unique encoded cells (12 required x 2 subjects), '%20' for a blank, SHA equals the run's"; else bad "C14 erc=$erc n=$n"; fi
    e=$(env -i PATH="$PATH" HOME="${HOME:-/}" TMPDIR="$T/tmp" LC_ALL=C "$BASH" "$SELF" --root "$T" --corpus "$T/c6" --emit-population 2>/dev/null); erc=$?
    if [ "$erc" -eq 2 ] && [ -z "$e" ]; then ok "C14b --emit-population with the matrix absent => rc 2, no output"; else bad "C14b erc=$erc"; fi
    # C15 determinism
    runc "$T/c14"; o1=$out; runc "$T/c14"
    if [ "$o1" = "$out" ]; then ok "C15 two runs give identical bytes"; else bad "C15 outputs differ"; fi
    # C16 the shipped corpus: recall 1.0, zero false positives
    FX="$LIVE/_tests/fixtures/zero-gap/coverage-gaps"
    if [ -d "$FX/planted" ] && [ -f "$FX/expect.tsv" ]; then
        cp -R "$FX" "$T/fx"
        runc "$T/fx/planted"; pl=$rc; grep '^FINDING ' <<<"$out" | awk '{print $5}' | LC_ALL=C sort -u >"$T/found"
        awk -F'\t' '!/^#/ && NF { print $1 }' "$T/fx/expect.tsv" | LC_ALL=C sort -u >"$T/want"
        runc "$T/fx/clean"; cl=$rc; cf=$(grep -c '^FINDING ' <<<"$out")
        if [ "$pl" -eq 1 ] && cmp -s "$T/found" "$T/want" && [ "$cl" -eq 0 ] && [ "$cf" -eq 0 ]; then ok "C16 shipped corpus: planted findings == expect.tsv ($(awk 'END{print NR}' "$T/want")/$(awk 'END{print NR}' "$T/want")), clean corpus silent"; else bad "C16 planted rc=$pl clean rc=$cl found=$(tr '\n' ' ' <"$T/found")"; fi
    else bad "C16 corpus absent at $FX"; fi
    # C17 live mode on a throwaway git repository: only TRACKED files resolve a path ref
    mkbase "$T/c17"; setrow "$T/c17" e2e check scripts/entry.sh; setrow "$T/c17" contract check scripts/untracked.sh; printf '#!/bin/sh\n' >"$T/c17/scripts/untracked.sh"
    ( cd "$T/c17" && git init -q . && git add docs scripts/entry.sh scripts/check-registry.tsv ) >/dev/null 2>&1
    out=$(env -i PATH="$PATH" HOME="${HOME:-/}" TMPDIR="$T/tmp" LC_ALL=C "$BASH" "$SELF" --root "$T/c17" 2>/dev/null); rc=$?
    if [ "$rc" -eq 1 ] && has "high false-evidence cell:s1:contract " && ! has "cell:s1:e2e "; then ok "C17 live mode: a tracked path ref resolves, an untracked file does not"; else bad "C17 rc=$rc out=$out"; fi
    mkbase "$T/c17b"; setrow "$T/c17b" e2e check scripts/entry.sh
    out=$(env -i PATH="$PATH" HOME="${HOME:-/}" TMPDIR="$T/tmp" LC_ALL=C "$BASH" "$SELF" --root "$T/c17b" 2>/dev/null); rc=$?
    if [ "$rc" -eq 2 ] && nofind && has "COULD-NOT-INSPECT cell:s1:e2e "; then ok "C17b live mode where git cannot list files (not a repository): a path ref is undetermined, rc 2, no invented finding"; else bad "C17b rc=$rc out=$out"; fi
    # C18 the live tree: contract-shaped output, and nothing of ours changed
    out=$(env -i PATH="$PATH" HOME="${HOME:-/}" TMPDIR="$T/tmp" LC_ALL=C "$BASH" "$SELF" --root "$LIVE" 2>/dev/null); rc=$?
    if [ "$rc" -le 2 ] && has "INSPECTED " && has "POPULATION-SHA " && { [ -f "$LIVE/$REL_CSV" ] || { [ "$rc" -eq 2 ] && has "coverage.tsv absent"; }; }; then ok "C18 live tree: rc $rc, INSPECTED and POPULATION-SHA present ($([ -f "$LIVE/$REL_CSV" ] && echo 'matrix present' || echo 'matrix absent => undetermined'))"; else bad "C18 live rc=$rc out=$out"; fi
    h1=$(find "$LIVE/docs/zero-gap/coverage.tsv" "$SELF" "$LIVE/_tests/fixtures/zero-gap/coverage-gaps" -type f -exec sha256sum {} + 2>/dev/null | LC_ALL=C sort | sha256sum)
    if [ "$h0" = "$h1" ]; then ok "C19 live tree byte-identical before and after (owned files + coverage.tsv)"; else bad "C19 live files changed during the proof"; fi
    echo "coverage-gaps proof: $pass passed, $fail failed"
    [ "$fail" -eq 0 ]
}

if [ "$PROVE" -eq 1 ]; then
    prove_failure
    exit $?
fi

# ── the class ────────────────────────────────────────────────────────────────────────────────
EMPTY_SHA=e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855   # sha256 of the empty population
# early <part> <reason>: nothing was enumerated; an inspection run still prints INSPECTED 0 and the
# POPULATION-SHA of the empty set (every rc carries the full contract); --emit-population prints the
# reason on stderr only and exits 2
early() {
    if [ "$EMIT" -eq 1 ]; then echo "COULD-NOT-INSPECT $1 $2" >&2; exit 2; fi
    echo "COULD-NOT-INSPECT $1 $2"; echo "INSPECTED 0"; echo "POPULATION-SHA $EMPTY_SHA"; exit 2
}
need() {
    local t
    for t in "$@"; do
        command -v "$t" >/dev/null 2>&1 || early - "required tool missing: $t"
    done
}
need awk sort sha256sum od iconv cut paste tr mktemp grep find cmp
if [ -z "$ROOT" ] || [ ! -d "$ROOT" ]; then early - "--root is not a directory"; fi
if [ -n "$CORPUS" ] && [ ! -d "$CORPUS" ]; then early - "--corpus is not a directory"; fi
if [ -n "$CORPUS" ]; then BASE=$CORPUS; else BASE=$ROOT; need git; fi

W=$(mktemp -d "${TMPDIR:-/tmp}/zg-covgaps.XXXXXX") || early - "cannot create a scratch directory"
trap '[ -n "${W:-}" ] && rm -rf "$W"' EXIT INT TERM
CSV=$BASE/$REL_CSV

# whole-file faults: nothing can be enumerated, nothing is inspected
filefail() { # <reason>
    if [ "$EMIT" -eq 1 ]; then exit 2; fi
    echo "COULD-NOT-INSPECT $REL_CSV $1"
    echo "INSPECTED 0"
    echo "POPULATION-SHA $EMPTY_SHA"
    exit 2
}
if [ ! -e "$CSV" ] && [ ! -L "$CSV" ]; then filefail "coverage.tsv absent — matrix not yet generated (T052)"; fi
if [ -L "$CSV" ] || [ ! -f "$CSV" ] || [ ! -r "$CSV" ]; then filefail "coverage.tsv is not a readable regular file"; fi
if ! iconv -f UTF-8 -t UTF-8 "$CSV" >/dev/null 2>&1; then filefail "coverage.tsv is not valid UTF-8"; fi

# pass 1: syntax. rows -> R <line> <subject> <kind> <status> <ref>; faults -> B <line> <reason>
if ! awk -F'\t' -v OFS='\t' -v rows="$W/rows" -v bad="$W/bad" '
    /^ *$/ { next }
    /^#/ { next }
    /[\001-\010\013-\037\177]/ { print "B", NR, "the row carries a control character other than TAB" > bad; seen = 1; next }
    !seen && NF >= 4 && $1 == "subject" && $2 == "test_kind" && $3 == "status" && $4 == "ref" { seen = 1; next }
    { seen = 1 }
    NF < 4 { print "B", NR, "the row has " NF " tab-separated field(s), 4 are required (subject, test_kind, status, ref)" > bad; next }
    $1 == "" || $2 == "" { print "B", NR, "the row has a blank subject or test kind" > bad; next }
    $1 ~ /:/ || $2 ~ /:/ { print "B", NR, "a subject or test kind contains a colon, which would make its cell token ambiguous" > bad; next }
    { print "R", NR, $1, $2, $3, $4 > rows }
    END { close(rows); close(bad) }' "$CSV"; then filefail "coverage.tsv could not be parsed"; fi
: >>"$W/rows"; : >>"$W/bad"

# encode every distinct raw string once, with the class-contract helper
{ cut -f3-6 "$W/rows" | tr '\t' '\n'; cut -f6 "$W/rows" | tr ',' '\n'; cut -f5 "$W/rows" | awk 'p = index($0, ":") { print substr($0, p + 1) }'; printf '%s\n' $REQ_KINDS; } | awk 'length' | LC_ALL=C sort -u >"$W/uniq"
tr '\n' '\0' <"$W/uniq" | zg_pct_encode_z >"$W/enc"
if [ "$(awk 'END{print NR}' "$W/uniq")" -ne "$(awk 'END{print NR}' "$W/enc")" ]; then filefail "coverage.tsv strings could not be encoded"; fi
paste "$W/uniq" "$W/enc" >"$W/map"

# registered check ids and the tracked file set (what a check ref may resolve to)
REG_OK=0; TRK_OK=0
if [ -f "$BASE/$REL_REG" ] && [ ! -L "$BASE/$REL_REG" ] && awk -F'\t' '($1 == "check" || $1 == "debt") && $2 != "" { print $2 }' "$BASE/$REL_REG" | LC_ALL=C sort -u >"$W/ids"; then REG_OK=1; fi
if [ -n "$CORPUS" ]; then
    if ( cd "$CORPUS" && find . -type f -print0 ) >"$W/trk.z" 2>/dev/null; then TRK_OK=1; fi
else
    if git -C "$ROOT" ls-files -z >"$W/trk.z" 2>/dev/null; then TRK_OK=1; fi
fi
if [ "$TRK_OK" -eq 1 ]; then awk 'BEGIN { RS = "\0" } index($0, "\n") == 0 { sub(/^\.\//, ""); print }' "$W/trk.z" >"$W/trk"; else : >"$W/trk"; fi
: >>"$W/ids"

# pass 2: semantics over the cells
if ! awk -F'\t' -v OFS='\t' -v req="$REQ_KINDS" -v csv="$REL_CSV" -v reg="$REL_REG" -v regok="$REG_OK" -v trkok="$TRK_OK" \
    -v mapf="$W/map" -v idf="$W/ids" -v trkf="$W/trk" -v rowf="$W/rows" '
function E(x) { if (!(x in enc)) { miss = 1; return "?" } return enc[x] }
function tk(s, k) { return "cell:" E(s) ":" E(k) }
function e(x) { return (x == "" ? "(empty)" : E(x)) }
function safe(r) { return r !~ /^\// && r !~ /^\.\// && r !~ /(^|\/)\.\.(\/|$)/ }
function fnd(loc, sev, cat, desc, evref) { print "F", loc, sev, cat, desc, evref }
FILENAME == mapf { enc[$1] = $2; next }
FILENAME == idf { ids[$0] = 1; next }
FILENAME == trkf { trk[$0] = 1; next }
FILENAME == rowf {
    key = $3 SUBSEP $4
    if (key in have) { print "C", csv ":" $2, "duplicate row for cell " tk($3, $4) " (first at line " lnof[key] "); the cell is evaluated from its first row only"; next }
    have[key] = 1; lnof[key] = $2; stof[key] = $5; rfof[key] = $6; subj[$3] = 1
    next
}
END {
    nreq = split(req, R, " ")
    for (s in subj) for (i = 1; i <= nreq; i++) {
        key = s SUBSEP R[i]
        print "P", tk(s, R[i])
        if (!(key in have)) fnd(tk(s, R[i]), "medium", "test-coverage", "the matrix has no row for required test kind " E(R[i]) " of subject " E(s) " (a blank cell)", csv)
    }
    for (key in have) {
        split(key, a, SUBSEP); s = a[1]; k = a[2]; loc = tk(s, k); print "P", loc
        st = stof[key]; rf = rfof[key]; ev = csv ":" lnof[key]
        sb = st; suf = ""; p = index(st, ":")
        if (p > 0) { sb = substr(st, 1, p - 1); suf = substr(st, p + 1) }
        if (sb == "gap") {
            # gap or gap:<note>: the note never turns a gap into something else
            fnd(loc, "medium", "test-coverage", "subject " E(s) " has no " E(k) " test: the matrix cell is a gap (ref " e(rf) (suf != "" ? ", note " E(suf) : "") ")", ev)
        } else if (sb == "check" && suf == "") {
            if (rf == "") { fnd(loc, "high", "false-evidence", "check cell for " E(k) " of subject " E(s) " names no check (empty ref), so the claimed coverage cannot exist", ev); continue }
            nb = split(rf, L, ","); dang = ""; und = ""
            for (j = 1; j <= nb; j++) {
                r = L[j]
                if (r == "") { dang = dang " (empty-element)"; continue }
                if (safe(r) && ((regok == 1 && (r in ids)) || (trkok == 1 && (r in trk)))) continue
                if (!safe(r) || (regok == 1 && trkok == 1)) dang = dang " " E(r); else und = und " " E(r)
            }
            if (dang != "") fnd(loc, "high", "false-evidence", "check cell for " E(k) " of subject " E(s) " is covered by a check that does not exist: no registered check id in " reg " and no tracked file matches" dang, ev)
            else if (und != "") print "C", loc, "cannot resolve ref" und " for the check cell of " E(k) ": the registry " reg " or the tracked file set could not be read"
        } else if (sb == "n/a") {
            reason = (suf != "" ? suf : rf)
            if (reason == "" || reason == "-") fnd(loc, "medium", "test-coverage", "n/a cell claims " E(k) " does not apply to subject " E(s) " but gives no reason (status n/a:<reason> or a reason in ref)", ev)
        } else if (sb == "could-not-run") {
            tool = (suf != "" ? suf : rf)
            if (tool == "" || tool == "-") print "C", loc, "the " E(k) " test of subject " E(s) " is recorded as could-not-run and no tool is named"
            else print "C", loc, "the " E(k) " test of subject " E(s) " is recorded as could-not-run: tool " E(tool) " was unusable; this is not a pass"
        } else {
            print "C", loc, "unknown or blank status " e(st) " for the " E(k) " cell of subject " E(s) "; expected check, n/a, gap or could-not-run"
        }
    }
    if (miss) exit 3
}' "$W/map" "$W/ids" "$W/trk" "$W/rows" >"$W/sem"; then filefail "coverage.tsv cells could not be evaluated"; fi

awk -F'\t' '$1 == "P" { print $2 }' "$W/sem" | LC_ALL=C sort -u >"$W/pop"
if [ "$EMIT" -eq 1 ]; then cat "$W/pop"; exit 0; fi

{
    awk -F'\t' -v csv="$REL_CSV" '$1 == "B" { print "COULD-NOT-INSPECT " csv ":" $2 " " $3 }' "$W/bad"
    awk -F'\t' '$1 == "C" { print "COULD-NOT-INSPECT " $2 " " $3 }' "$W/sem"
    if [ ! -s "$W/pop" ]; then echo "COULD-NOT-INSPECT $REL_CSV coverage.tsv holds no cells: an empty matrix inspects nothing and is never clean"; fi
} | LC_ALL=C sort -u >"$W/cni"
awk -F'\t' -v c="$CLASS_ID" '$1 == "F" { print "FINDING " c " " $3 " " $4 " " $2 " " $5 " " $6 }' "$W/sem" | LC_ALL=C sort -u >"$W/fnd"

cat "$W/fnd" "$W/cni"
echo "INSPECTED $(awk 'END{print NR}' "$W/pop")"
if [ -s "$W/pop" ]; then echo "POPULATION-SHA $(sha256sum <"$W/pop" | cut -d' ' -f1)"; else echo "POPULATION-SHA $EMPTY_SHA"; fi
if [ -s "$W/fnd" ]; then exit 1; fi
if [ -s "$W/cni" ]; then exit 2; fi
exit 0
