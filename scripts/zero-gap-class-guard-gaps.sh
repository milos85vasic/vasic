#!/usr/bin/env bash
# scripts/zero-gap-class-guard-gaps.sh — sweep class `guard-gaps` (feature 010, T033, FR-021).
#
# WHAT IT DETECTS. Destructive shell and git commands that the wired PreToolUse guard does NOT refuse.
# The guard is UPSTREAM code (submodules/constitution/scripts/hooks/guard-forbidden-commands.sh, wired by
# .claude/settings.json); this repository never edits it, so a gap it finds is reported, never patched
# here. Three kinds of finding:
#   guarded:<id>     the catalogue says the command must be REFUSED and the guard exits 0 (allowed):
#                    high / security, "destructive command not blocked: ..."; the fix belongs UPSTREAM
#                    (reporting route: an issue against the constitution repository, classified
#                    third-party in the workable-items register).
#   guarded:<id>     the catalogue says ALLOWED and the guard refuses (rc 2): medium / other,
#                    "guard blocks a legitimate command".
#   candidate:<id>   catalogue drift: the row declares a dangerous command CLASS in its `candidate` column
#                    (an extended regex) and no row catalogued `refused` has a command matching it, so the
#                    guard is never probed for that class (a row softened below its class, or a dangerous
#                    class flipped to `allowed`): low / governance-drift.
#
# POPULATION AND WHY. Every data row of docs/zero-gap/guarded-commands.tsv (token guarded:<id>), plus
# candidate:<id> for every row whose `candidate` cell is not `-`. The catalogue is the tracked, data-driven
# record of every destructive command class this repository's documents name, with the source of each
# (header: id, command, expected, source, candidate); adding a command or a class is a data change there,
# never an edit here — this class holds NO hand list of commands or classes. The corpus mode
# (--corpus <dir>) reads <dir>/guarded-commands.tsv and probes <dir>/guard.sh instead.
#
# HOW IT PROBES. Each command is fed to the guard as the hook's stdin JSON
# {"tool_name":"Bash","tool_input":{"command":"<cmd>"}} (the contract scripts/verify-pretooluse-guard.sh
# V4 uses), under a temporary cwd, `timeout -k 2 10` (ZG_GG_TIMEOUT overrides the 10 s, for the proof
# only; the -k sends KILL 2 s after TERM, so a guard that ignores TERM cannot stretch the budget). rc 2
# means refused, rc 0 means allowed, any other rc or a timeout is COULD-NOT-INSPECT. The command is only
# a string on a pipe: NOTHING IS EVER EXECUTED by this class.
#
# EXIT CODES. 0 clean (non-empty population fully inspected, every verdict as catalogued); 1 at least one
# FINDING; 2 could not determine (root or catalogue missing/malformed, a candidate cell that is not a valid
# extended regex, empty catalogue, guard missing, unreadable, timing out or erroring). A finding outranks
# an undetermined.
#
# MEASURED ON THE LIVE TREE (2026-09-26, fix round F2): 26 catalogue rows, 52 population items (26 guarded +
# 26 candidate); the live guard refuses the five push/sudo/host-power rows and exits 0 on the other 21 (git
# checkout -- ., git restore ., git stash, git clean -fd, git add -A, git reset --hard, poweroff, pkill -f,
# killall, rm -rf /, git filter-branch, git branch -D, git update-ref -d, git clean -fdx, git checkout .,
# git add ., and — added in F2 after review rev-base-A found them uncatalogued, each probed as data first —
# reboot, halt, git push origin :main, git push --delete origin main, rm -rf ~): 21 high findings (16 before
# F2), every one a verdict read from the guard's exit code (precision is exact by construction: a finding is
# the guard's own rc 0 on a row the catalogue sources to a governance document). The guard blocks
# `systemctl reboot|halt` but not the bare commands; it blocks force-push but not a remote-branch deletion.
# SOURCING (F2): every row cites an existing tracked document other than this feature's tasks.md (proof L2);
# the five shared-tree rows (checkout --, restore, stash, clean -fd, add -A) cite the project constitution
# .specify/memory/constitution.md "Shared-Tree Discipline Is Wider Than stash", which names each of them.
# Relative --root / --corpus paths are resolved first (proof R1): before F2 a relative --root made every
# probe exit 127 and the class reported COULD-NOT-INSPECT instead of the 16 verdicts.
#
# WHAT IT DOES NOT SEE. Commands the catalogue does not list (a governance document naming a new
# destructive command is caught only when someone adds the row); how the guard treats a compound command
# that hides a destructive one inside quoting or a script file (each catalogue row is one plain command
# line); whether the harness actually invokes the guard (scripts/verify-pretooluse-guard.sh checks the
# wiring); the guard's behaviour on other hosts.
#
# USAGE  zero-gap-class-guard-gaps.sh --root <abs dir> [--corpus <dir>] [--emit-population]
#        zero-gap-class-guard-gaps.sh --prove-failure      (paired proof on throwaway copies)
set -uo pipefail

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

SELF="${BASH_SOURCE[0]}"
SELF_DIR="$(cd "$(dirname "$SELF")" && pwd)"
SELF_ROOT="$(cd "$SELF_DIR/.." && pwd)"

CAT_REL="docs/zero-gap/guarded-commands.tsv"
GUARD_REL="submodules/constitution/scripts/hooks/guard-forbidden-commands.sh"
TIMEOUT="${ZG_GG_TIMEOUT:-10}"


ROOT="" CORPUS="" EMIT=0 MODE=run

# ---------------------------------------------------------------------------------------------
# --prove-failure: the paired proof, on THROWAWAY copies of the corpus (never on the live tree).
# ---------------------------------------------------------------------------------------------
prove_failure() {
    local FIX="$SELF_ROOT/_tests/fixtures/zero-gap/guard-gaps" T pass=0 fail=0 rc out
    for b in planted/guarded-commands.tsv planted/guard.sh clean/guarded-commands.tsv clean/guard.sh expect.tsv; do
        [ -f "$FIX/$b" ] || { echo "COULD-NOT-PROVE: corpus part missing: $b"; return 2; }
    done
    T="$(mktemp -d "${TMPDIR:-/tmp}/zg-gg-prove.XXXXXX")" || { echo "COULD-NOT-PROVE: no temp dir"; return 2; }
    trap "rm -rf '$T'" EXIT
    ok()  { pass=$((pass + 1)); printf '  PASS  %s\n' "$1"; }
    bad() { fail=$((fail + 1)); printf '  FAIL  %s\n' "$1"; }
    cp -R "$FIX" "$T/fix"
    local before after
    before=$( { find "$FIX" "$SELF_ROOT/$CAT_REL" -type f -print0 2>/dev/null | LC_ALL=C sort -z | xargs -0 sha256sum 2>/dev/null; } | sha256sum | cut -d' ' -f1)
    run() { out=$(bash "$SELF" --root "$T/root" "$@" 2>"$T/err"); rc=$?; }
    mkdir -p "$T/root"

    # C0 control: the clean corpus (all-refusing stub, every candidate catalogued) is clean.
    run --corpus "$T/fix/clean"
    if [ "$rc" -eq 0 ] && ! grep -q '^FINDING' <<<"$out" && grep -q '^INSPECTED [1-9]' <<<"$out"; then ok "C0 control: clean corpus rc 0, no finding, non-empty population inspected"; else bad "C0 rc=$rc: $out"; fi

    # P1 planted: exactly the four planted locations.
    run --corpus "$T/fix/planted"
    local got want
    got=$(grep '^FINDING' <<<"$out" | awk '{print $5}' | LC_ALL=C sort | tr '\n' ' ')
    want=$(grep -v '^#' "$T/fix/expect.tsv" | cut -f1 | LC_ALL=C sort | tr '\n' ' ')
    if [ "$rc" -eq 1 ] && [ "$got" = "$want" ]; then ok "P1 planted corpus: rc 1, findings = $got"; else bad "P1 rc=$rc got [$got] want [$want]"; fi

    # P2 severities and wording of each finding kind.
    if grep -q '^FINDING guard-gaps high security guarded:stash-all destructive command not blocked: git stash' <<<"$out" \
       && grep -q '^FINDING guard-gaps medium other guarded:legit-diff guard blocks a legitimate command' <<<"$out" \
       && grep -q '^FINDING guard-gaps low governance-drift candidate:reset-hard catalogue drift: row reset-hard names the dangerous command class matching .git reset --hard.' <<<"$out" \
       && grep -q '^FINDING guard-gaps low governance-drift candidate:update-ref-delete ' <<<"$out" \
       && grep -q 'fix belongs UPSTREAM' <<<"$out"; then ok "P2 severity/category/wording of the three finding kinds"; else bad "P2 $out"; fi

    # P3 population: --emit-population equals what the run walks.
    local emitted psha
    emitted=$(bash "$SELF" --root "$T/root" --corpus "$T/fix/planted" --emit-population)
    psha=$(grep '^POPULATION-SHA' <<<"$out" | cut -d' ' -f2)
    if [ -n "$emitted" ] && [ "$psha" = "$(printf '%s\n' "$emitted" | sha256sum | cut -d' ' -f1)" ]; then ok "P3 POPULATION-SHA equals the sha of --emit-population"; else bad "P3 sha mismatch"; fi

    # P4 every planted FINDING location is a population item, and the population is guarded:<id> for every
    # row plus candidate:<id> for every row naming a class (11 rows, 10 classes in the planted catalogue).
    local loc miss=0
    while IFS= read -r loc; do grep -qxF -- "$loc" <<<"$emitted" || miss=$((miss + 1)); done < <(grep '^FINDING' <<<"$out" | awk '{print $5}')
    if [ "$miss" -eq 0 ] && [ "$(grep -c '^guarded:' <<<"$emitted")" -eq 11 ] && [ "$(grep -c '^candidate:' <<<"$emitted")" -eq 10 ]; then ok "P4 findings located on population items; population = 11 guarded + 10 candidate"; else bad "P4 miss=$miss emitted=[$(tr '\n' ' ' <<<"$emitted")]"; fi

    # E1 empty catalogue (header only) => rc 2, never clean, and no candidate finding.
    rm -rf "$T/e1"; cp -R "$T/fix/clean" "$T/e1"; { grep '^#' "$T/e1/guarded-commands.tsv"; printf 'id\tcommand\texpected\tsource\tcandidate\n'; } >"$T/e1/c" && mv "$T/e1/c" "$T/e1/guarded-commands.tsv"
    run --corpus "$T/e1"
    if [ "$rc" -eq 2 ] && ! grep -q '^FINDING' <<<"$out" && grep -q '^COULD-NOT-INSPECT' <<<"$out"; then ok "E1 empty catalogue => rc 2"; else bad "E1 rc=$rc: $out"; fi

    # E2 guard missing => rc 2.
    rm -rf "$T/e2"; cp -R "$T/fix/clean" "$T/e2"; rm "$T/e2/guard.sh"
    run --corpus "$T/e2"
    if [ "$rc" -eq 2 ] && grep -q '^COULD-NOT-INSPECT' <<<"$out"; then ok "E2 missing guard => rc 2"; else bad "E2 rc=$rc: $out"; fi

    # E3 guard errors (rc 1) => rc 2, and is not read as a verdict.
    rm -rf "$T/e3"; cp -R "$T/fix/clean" "$T/e3"; printf '#!/usr/bin/env bash\ncat >/dev/null\nexit 1\n' >"$T/e3/guard.sh"
    run --corpus "$T/e3"
    if [ "$rc" -eq 2 ] && ! grep -q '^FINDING' <<<"$out"; then ok "E3 guard exiting 1 => rc 2, no verdict invented"; else bad "E3 rc=$rc: $out"; fi

    # E4 nonexistent root => rc 2.
    out=$(bash "$SELF" --root /nonexistent 2>/dev/null); rc=$?
    if [ "$rc" -eq 2 ]; then ok "E4 --root /nonexistent => rc 2"; else bad "E4 rc=$rc"; fi

    # E5 catalogue with an unknown expected value => rc 2.
    rm -rf "$T/e5"; cp -R "$T/fix/clean" "$T/e5"; printf 'weird\tgit status\tmaybe\tcorpus\t-\n' >>"$T/e5/guarded-commands.tsv"
    run --corpus "$T/e5"
    if [ "$rc" -eq 2 ]; then ok "E5 unknown expected value => rc 2"; else bad "E5 rc=$rc: $out"; fi

    # E6 a guard that hangs => rc 2 via the timeout.
    rm -rf "$T/e6"; cp -R "$T/fix/clean" "$T/e6"; printf '#!/usr/bin/env bash\nsleep 30\n' >"$T/e6/guard.sh"
    out=$(ZG_GG_TIMEOUT=1 bash "$SELF" --root "$T/root" --corpus "$T/e6" 2>/dev/null); rc=$?
    if [ "$rc" -eq 2 ] && ! grep -q '^FINDING' <<<"$out"; then ok "E6 hanging guard => rc 2 by timeout"; else bad "E6 rc=$rc"; fi

    # E7 duplicate id => rc 2.
    rm -rf "$T/e7"; cp -R "$T/fix/clean" "$T/e7"; printf 'add-all\tgit add -A\trefused\tcorpus\tgit add -A\n' >>"$T/e7/guarded-commands.tsv"
    run --corpus "$T/e7"
    if [ "$rc" -eq 2 ]; then ok "E7 duplicate id => rc 2"; else bad "E7 rc=$rc"; fi

    # J1 the command reaches the guard as valid JSON (quote and backslash escaped) and is never executed.
    rm -rf "$T/j1"; cp -R "$T/fix/clean" "$T/j1"
    printf 'quoted\tgit commit -m "a\\b" && touch %s/EXECUTED\trefused\tcorpus\t-\n' "$T/j1" >>"$T/j1/guarded-commands.tsv"
    printf '#!/usr/bin/env bash\nin=$(cat)\nprintf "%%s\\n" "$in" >>"%s/stdin.log"\ncase "$in" in *"\\"git status --short\\""*) exit 0 ;; esac\nexit 2\n' "$T/j1" >"$T/j1/guard.sh"
    run --corpus "$T/j1"
    if [ "$rc" -eq 0 ] && grep -qF 'git commit -m \"a\\b\" && touch' "$T/j1/stdin.log" && [ ! -e "$T/j1/EXECUTED" ]; then ok "J1 command JSON-escaped on the guard's stdin and never executed"; else bad "J1 rc=$rc log=$(head -c 300 "$T/j1/stdin.log" 2>/dev/null)"; fi

    # E8 a candidate cell that is not a valid extended regex => rc 2 (never read as "no match").
    rm -rf "$T/e8"; cp -R "$T/fix/clean" "$T/e8"; printf 'broken-rx\tgit gc --prune=now\trefused\tcorpus\tgit gc (\n' >>"$T/e8/guarded-commands.tsv"
    run --corpus "$T/e8"
    if [ "$rc" -eq 2 ] && grep -q 'not a valid extended regex' <<<"$out"; then ok "E8 invalid candidate regex => rc 2"; else bad "E8 rc=$rc: $out"; fi

    # E9 a four-column (pre-candidate) catalogue => rc 2: the candidate column is mandatory data.
    rm -rf "$T/e9"; cp -R "$T/fix/clean" "$T/e9"; cut -f1-4 "$T/fix/clean/guarded-commands.tsv" >"$T/e9/guarded-commands.tsv"
    run --corpus "$T/e9"
    if [ "$rc" -eq 2 ] && ! grep -q '^FINDING' <<<"$out"; then ok "E9 catalogue without the candidate column => rc 2"; else bad "E9 rc=$rc: $out"; fi

    # K1 a guard that IGNORES TERM is still stopped (timeout -k): 1 s budget, finished well under 8 s.
    rm -rf "$T/k1"; cp -R "$T/fix/clean" "$T/k1"; printf '#!/usr/bin/env bash\ntrap "" TERM\ncat >/dev/null\nsleep 12\nexit 2\n' >"$T/k1/guard.sh"
    local t0 t1; t0=$(date +%s)
    out=$(ZG_GG_TIMEOUT=1 bash "$SELF" --root "$T/root" --corpus "$T/k1" 2>/dev/null); rc=$?
    t1=$(date +%s)
    if [ "$rc" -eq 2 ] && [ $((t1 - t0)) -lt 8 ] && ! grep -q '^FINDING' <<<"$out"; then ok "K1 TERM-ignoring guard killed by timeout -k (rc 2 in $((t1 - t0)) s)"; else bad "K1 rc=$rc elapsed=$((t1 - t0)) s"; fi

    # R1 (fix round F2) RELATIVE --root / --corpus paths are resolved before the probe changes directory:
    # a relative guard path used to make every probe exit 127 (COULD-NOT-INSPECT) instead of a verdict.
    out=$(cd "$T" && bash "$SELF_DIR/$(basename "$SELF")" --root root --corpus fix/planted 2>/dev/null); rc=$?
    if [ "$rc" -eq 1 ] && [ "$(grep -c '^FINDING' <<<"$out")" -eq "$(grep -vc '^#' "$T/fix/expect.tsv")" ] && ! grep -q '^COULD-NOT-INSPECT' <<<"$out"; then ok "R1 relative --root/--corpus give the same verdicts as absolute ones"; else bad "R1 rc=$rc: $(head -c 300 <<<"$out")"; fi

    # R2 the same in LIVE mode: a throwaway root holding the planted catalogue and stub guard at their live
    # paths, named by a relative --root.
    mkdir -p "$T/lr/docs/zero-gap" "$T/lr/submodules/constitution/scripts/hooks"
    cp "$T/fix/planted/guarded-commands.tsv" "$T/lr/$CAT_REL"; cp "$T/fix/planted/guard.sh" "$T/lr/$GUARD_REL"
    out=$(cd "$T" && bash "$SELF_DIR/$(basename "$SELF")" --root lr 2>/dev/null); rc=$?
    if [ "$rc" -eq 1 ] && [ "$(grep -c '^FINDING' <<<"$out")" -eq "$(grep -vc '^#' "$T/fix/expect.tsv")" ] && ! grep -q '^COULD-NOT-INSPECT' <<<"$out"; then ok "R2 relative --root in live mode gives the planted verdicts"; else bad "R2 rc=$rc: $(head -c 300 <<<"$out")"; fi

    # A1 the clean control carries an ALLOWED row, and the class reads it as allowed (no finding).
    if grep -q $'\tallowed\t' "$T/fix/clean/guarded-commands.tsv"; then ok "A1 clean corpus holds an allowed row and C0 was clean"; else bad "A1 clean corpus has no allowed row"; fi

    # L1 the LIVE catalogue is well formed and self-consistent: with an all-refusing stub guard every row
    # is inspected, every named class is covered by a refused row (no drift), and no row is allowed.
    rm -rf "$T/l1"; mkdir -p "$T/l1"; cp "$SELF_ROOT/$CAT_REL" "$T/l1/guarded-commands.tsv"
    printf '#!/usr/bin/env bash\ncat >/dev/null\nexit 2\n' >"$T/l1/guard.sh"
    run --corpus "$T/l1"
    local nrows ncand
    nrows=$(grep -v '^#' "$T/l1/guarded-commands.tsv" | tail -n +2 | grep -c .)
    ncand=$(grep -v '^#' "$T/l1/guarded-commands.tsv" | tail -n +2 | awk -F'\t' '$5 != "-"' | grep -c .)
    if [ "$rc" -eq 0 ] && grep -qx "INSPECTED $((nrows + ncand))" <<<"$out" && [ "$nrows" -ge 21 ]; then ok "L1 live catalogue: $nrows rows, $ncand named classes, all covered, rc 0 under an all-refusing guard"; else bad "L1 rc=$rc rows=$nrows cand=$ncand: $out"; fi

    # L2 (fix round F2, review rev-base-A) every LIVE row is SOURCED: its source cell names at least one
    # tracked-path token that exists under the root and is not this feature's own tasks.md (a row that
    # cites only the feature's task list states no governance rule).
    local unsourced="" sid ssrc tok okrow
    while IFS=$'\t' read -r sid _ _ ssrc _; do
        case "$sid" in ''|'#'*|id) continue ;; esac
        okrow=0
        for tok in $(grep -oE '[A-Za-z0-9_.][A-Za-z0-9_./-]*\.(md|sh|tsv|yml|yaml|json)' <<<"$ssrc"); do
            [ "$tok" = specs/010-zero-gap-verified-closure/tasks.md ] && continue
            [ -f "$SELF_ROOT/$tok" ] && { okrow=1; break; }
        done
        [ "$okrow" -eq 1 ] || unsourced="$unsourced $sid"
    done <"$SELF_ROOT/$CAT_REL"
    if [ -z "$unsourced" ]; then ok "L2 every live row cites an existing tracked document other than the feature's own tasks.md"; else bad "L2 rows sourced only to the feature's tasks.md or to no existing path:$unsourced"; fi

    # L3 (fix round F2) the destructive classes rev-base-A found uncatalogued are catalogued refused.
    local want_cmd missing_cmd=""
    for want_cmd in 'reboot' 'halt' 'git push origin :main' 'git push --delete origin main' 'rm -rf ~'; do
        awk -F'\t' -v c="$want_cmd" '!/^#/ && $2 == c && $3 == "refused" { f = 1 } END { exit !f }' "$SELF_ROOT/$CAT_REL" || missing_cmd="$missing_cmd [$want_cmd]"
    done
    if [ -z "$missing_cmd" ]; then ok "L3 reboot, halt, both remote-branch deletions and rm -rf ~ are catalogued refused"; else bad "L3 not catalogued refused:$missing_cmd"; fi

    # I1 the live tree and the corpus are byte-identical before and after.
    after=$( { find "$FIX" "$SELF_ROOT/$CAT_REL" -type f -print0 2>/dev/null | LC_ALL=C sort -z | xargs -0 sha256sum 2>/dev/null; } | sha256sum | cut -d' ' -f1)
    if [ "$before" = "$after" ]; then ok "I1 live corpus and catalogue byte-identical before/after the proof"; else bad "I1 the live tree changed"; fi

    printf 'guard-gaps prove-failure: %d passed, %d failed\n' "$pass" "$fail"
    [ "$fail" -eq 0 ] && return 0 || return 1
}

while [ $# -gt 0 ]; do
    case "$1" in
        --root) ROOT="${2:-}"; shift 2 ;;
        --corpus) CORPUS="${2:-}"; shift 2 ;;
        --emit-population) EMIT=1; shift ;;
        --prove-failure) MODE=prove; shift ;;
        *) echo "guard-gaps: unknown argument: $1" >&2; exit 2 ;;
    esac
done
if [ "$MODE" = prove ]; then
    prove_failure
    exit $?
fi

# ---------------------------------------------------------------------------------------------
# The class proper.
# ---------------------------------------------------------------------------------------------
if [ -z "$ROOT" ] || [ ! -d "$ROOT" ]; then echo "COULD-NOT-INSPECT - --root is not a directory"; exit 2; fi
if [ -n "$CORPUS" ] && [ ! -d "$CORPUS" ]; then echo "COULD-NOT-INSPECT - --corpus is not a directory"; exit 2; fi
# absolute paths: the probe runs the guard from a scratch cwd, so a relative guard path would exit 127
ROOT="$(cd "$ROOT" && pwd)" || { echo "COULD-NOT-INSPECT - --root cannot be resolved"; exit 2; }
if [ -n "$CORPUS" ]; then CORPUS="$(cd "$CORPUS" && pwd)" || { echo "COULD-NOT-INSPECT - --corpus cannot be resolved"; exit 2; }; fi
if [ -n "$CORPUS" ]; then
    CAT_FILE="$CORPUS/guarded-commands.tsv"; GUARD_FILE="$CORPUS/guard.sh"
    CAT_SHOW="guarded-commands.tsv"; GUARD_SHOW="guard.sh"
else
    CAT_FILE="$ROOT/$CAT_REL"; GUARD_FILE="$ROOT/$GUARD_REL"
    CAT_SHOW="$CAT_REL"; GUARD_SHOW="$GUARD_REL"
fi
CAT_TOK="$(zg_pct_encode "$CAT_SHOW")"
GUARD_TOK="$(zg_pct_encode "$GUARD_SHOW")"

CNI=0
cni() { CNI=$((CNI + 1)); printf 'COULD-NOT-INSPECT %s %s\n' "$1" "$2"; }
clean_text() { printf '%s' "$1" | LC_ALL=C tr -d '\000-\037\177' ; }
empty_sha() { printf '' | sha256sum | cut -d' ' -f1; }

# --- load the catalogue: parallel arrays ID / CMD / EXP / LN --------------------------------
ID=() CMD=() EXP=() LN=() CAND=()
CAT_BAD=""
load_catalogue() {
    local line n=0 hdr=0 id cmd exp src cand extra rrc
    if [ ! -f "$CAT_FILE" ] || [ ! -r "$CAT_FILE" ]; then CAT_BAD="the catalogue $CAT_SHOW is missing or unreadable"; return; fi
    if ! iconv -f UTF-8 -t UTF-8 "$CAT_FILE" >/dev/null 2>&1; then CAT_BAD="the catalogue is not valid UTF-8"; return; fi
    local -A seen=()
    while IFS= read -r line || [ -n "$line" ]; do
        n=$((n + 1))
        case "$line" in ''|'#'*) continue ;; esac
        if [ "$hdr" -eq 0 ]; then
            if [ "$line" != $'id\tcommand\texpected\tsource\tcandidate' ]; then CAT_BAD="line $n: the header must be id, command, expected, source, candidate"; return; fi
            hdr=1; continue
        fi
        IFS=$'\t' read -r id cmd exp src cand extra <<<"$line"
        if [ -z "$id" ] || [ -z "$cmd" ] || [ -z "$exp" ] || [ -z "$src" ] || [ -z "$cand" ] || [ -n "$extra" ]; then CAT_BAD="line $n: a row needs exactly five non-empty fields (candidate is - when the row names no class)"; return; fi
        if ! [[ $id =~ ^[a-z0-9][a-z0-9-]*$ ]]; then CAT_BAD="line $n: id '$(clean_text "$id")' is not lowercase words joined by -"; return; fi
        if [ -n "${seen[$id]:-}" ]; then CAT_BAD="line $n: id $id is listed twice"; return; fi
        seen[$id]=1
        case "$cmd$cand" in *[[:cntrl:]]*) CAT_BAD="line $n: the command or candidate carries a control character"; return ;; esac
        if [ "$cand" != - ]; then
            grep -Eq -- "$cand" </dev/null 2>/dev/null; rrc=$?
            if [ "$rrc" -gt 1 ]; then CAT_BAD="line $n: the candidate cell is not a valid extended regex"; return; fi
        fi
        case "$exp" in
            refused|block) exp=block ;;
            allowed|allow) exp=allow ;;
            *) CAT_BAD="line $n: expected must be refused|block or allowed|allow, got '$(clean_text "$exp")'"; return ;;
        esac
        ID+=("$id"); CMD+=("$cmd"); EXP+=("$exp"); LN+=("$n"); CAND+=("$cand")
    done <"$CAT_FILE"
    if [ "$hdr" -eq 0 ]; then CAT_BAD="the catalogue has no header line"; fi
}
load_catalogue

# --- population: guarded:<id> for every row, candidate:<id> for every row naming a class --------
population() {
    local i
    [ -z "$CAT_BAD" ] || return 0
    [ "${#ID[@]}" -gt 0 ] || return 0
    for i in "${!ID[@]}"; do
        zg_pct_encode "guarded:${ID[$i]}"
        [ "${CAND[$i]}" = - ] || zg_pct_encode "candidate:${ID[$i]}"
    done
}
POP="$(population | LC_ALL=C sort -u)"

if [ "$EMIT" -eq 1 ]; then
    if [ -n "$CAT_BAD" ] || [ -z "$POP" ]; then exit 2; fi
    printf '%s\n' "$POP"
    exit 0
fi

FOUND=0 INSPECTED=0
finding() { # <sev> <cat> <location> <description> <evidence_ref>
    FOUND=$((FOUND + 1))
    printf 'FINDING guard-gaps %s %s %s %s %s\n' "$1" "$2" "$3" "$(clean_text "$4")" "$5"
}
finish() {
    if [ -n "$POP" ]; then printf 'POPULATION-SHA %s\n' "$(printf '%s\n' "$POP" | sha256sum | cut -d' ' -f1)"
    else printf 'POPULATION-SHA %s\n' "$(empty_sha)"; fi
    if [ "$FOUND" -gt 0 ]; then exit 1; fi
    if [ "$CNI" -gt 0 ]; then exit 2; fi
    exit 0
}

if [ -n "$CAT_BAD" ]; then
    cni "$CAT_TOK" "$CAT_BAD"
    echo "INSPECTED 0"; finish
fi
if [ "${#ID[@]}" -eq 0 ]; then
    cni "$CAT_TOK" "the catalogue lists no command: a class that inspects nothing is never clean"
    echo "INSPECTED 0"; finish
fi

# --- probe the guard: one plain command line per row, as data on a pipe ------------------------
CAT_REF="$(zg_pct_encode "$CAT_SHOW")"
json_escape() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }
GUARD_OK=1
if ! command -v timeout >/dev/null 2>&1; then cni "$GUARD_TOK" "the timeout tool is missing: the guard cannot be probed under a time limit"; GUARD_OK=0
elif [ ! -f "$GUARD_FILE" ] || [ ! -r "$GUARD_FILE" ]; then cni "$GUARD_TOK" "the guard script is missing or unreadable: $GUARD_SHOW"; GUARD_OK=0; fi
SCRATCH=""
if [ "$GUARD_OK" -eq 1 ]; then
    SCRATCH="$(mktemp -d "${TMPDIR:-/tmp}/zg-gg.XXXXXX")" || { cni "$GUARD_TOK" "no temporary directory for the probe"; GUARD_OK=0; }
    [ -z "$SCRATCH" ] || trap "rm -rf '$SCRATCH'" EXIT
fi

if [ "$GUARD_OK" -eq 1 ]; then
    for i in "${!ID[@]}"; do
        payload="$(printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$(json_escape "${CMD[$i]}")")"
        ( cd "$SCRATCH" && printf '%s' "$payload" | timeout -k 2 "$TIMEOUT" bash "$GUARD_FILE" >/dev/null 2>&1 )
        prc=$?
        loc="$(zg_pct_encode "guarded:${ID[$i]}")"
        ref="$(zg_pct_encode "$CAT_SHOW:${LN[$i]}")"
        case "$prc" in
            0)
                INSPECTED=$((INSPECTED + 1))
                if [ "${EXP[$i]}" = block ]; then
                    finding high security "$loc" "destructive command not blocked: ${CMD[$i]} (catalogue id ${ID[$i]}); the guard exited 0 and would let it run; the fix belongs UPSTREAM in the constitution guard script, so report it there and register the item classified third-party" "$ref"
                fi ;;
            2)
                INSPECTED=$((INSPECTED + 1))
                if [ "${EXP[$i]}" = allow ]; then
                    finding medium other "$loc" "guard blocks a legitimate command: ${CMD[$i]} (catalogue id ${ID[$i]}); the guard exited 2 on a command the catalogue expects to be allowed; the fix belongs UPSTREAM in the constitution guard script" "$ref"
                fi ;;
            *)
                if [ "$prc" -eq 124 ]; then cni "$loc" "the guard did not answer within ${TIMEOUT}s on catalogue id ${ID[$i]}; probing stopped"
                else cni "$loc" "the guard exited $prc (neither 0 allowed nor 2 refused) on catalogue id ${ID[$i]}; probing stopped"; fi
                break ;;
        esac
    done
fi

# --- catalogue drift: every class a row names needs a REFUSED row whose command matches it ------
for j in "${!ID[@]}"; do
    rx="${CAND[$j]}"
    [ "$rx" != - ] || continue
    INSPECTED=$((INSPECTED + 1))
    hit=0
    for i in "${!ID[@]}"; do
        [ "${EXP[$i]}" = block ] || continue
        if grep -Eq -- "$rx" <<<"${CMD[$i]}"; then hit=1; break; fi
    done
    if [ "$hit" -eq 0 ]; then
        finding low governance-drift "$(zg_pct_encode "candidate:${ID[$j]}")" "catalogue drift: row ${ID[$j]} names the dangerous command class matching '$rx' and no row catalogued refused in $CAT_SHOW has a command in that class, so the guard is never probed for it; restore a refused row for the class" "$(zg_pct_encode "$CAT_SHOW:${LN[$j]}")"
    fi
done

echo "INSPECTED $INSPECTED"
finish
