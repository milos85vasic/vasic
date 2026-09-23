#!/usr/bin/env bash
# verify-shell-continuations.sh — find BROKEN line continuations in this
# repository's own tracked shell scripts.
#
# ── Purpose ──────────────────────────────────────────────────────────────────
# A bash line continuation is a backslash IMMEDIATELY followed by a newline.
# If anything sits between the two — the rest of the next line pasted on, or a
# single trailing blank — the backslash no longer continues the line. It
# escapes the blank instead, and the command silently gains a literal " "
# argument:
#
#     if grep -q PAT <<<"$x" \       && grep -q OTHER <<<"$x"; then
#                            ^^^^^^^ `\ ` = one argument, a FILE named " "
#
# The first grep then reads a file that does not exist, exits 2, and the whole
# condition is false FOREVER — with no error on screen and a clean `bash -n`.
#
# That is not hypothetical. A mechanical `printf | grep` -> `grep <<<` rewrite
# (commit 59ea607, 2026-09-07) produced exactly this shape on TEN lines in
# three scripts, measured 2026-09-23:
#   * scripts/verify-all-constitution-rules.sh  8 lines -> its §1.1 proof was
#     RED on 8 of its cases (M9 M10 M11 M13 M14 M17 M18 M19) for 16 days;
#   * scripts/pre-push-gates.sh                 1 line  -> proof case M2b RED;
#   * scripts/verify-private-object-exposure.sh 1 line  -> evidence class E5
#     (a captured `.git/config`) could NEVER fire in the shipped detector, and
#     its proof stayed GREEN because no assertion read which classes fired.
# Every other instrument in this tree was green over all three. This check
# watches the two SHAPES that produced them (F1, F2 below), not only the ten
# instances. It is NOT a watch over the whole class, and says so: an independent
# review measured that `\<blanks>;` and `\<blanks>>file` (which parse and
# silently gain a " " argument) and CRLF `\<CR><LF>` are not matched, and that
# F1 can false-positive inside quoted strings, heredoc bodies and sed/grep
# patterns (none present in the tree when this was written).
#
# ── What is flagged ──────────────────────────────────────────────────────────
#   F1  a backslash followed by blanks and then `&&`, `||` or `|` on the SAME
#       line — a continuation that had its newline removed;
#   F2  a backslash followed only by blanks up to end of line — a continuation
#       whose trailing whitespace makes it escape a blank instead.
# Lines whose first non-blank character is `#` are comments and never flagged.
#
# ── Scope ────────────────────────────────────────────────────────────────────
# Every `*.sh` that `git ls-files` lists at --root. A submodule is ONE gitlink
# entry to `git ls-files`, so its files are not in scope: they are another
# repository's to fix, and a finding there returns as a gitlink bump.
#
# ── Usage ────────────────────────────────────────────────────────────────────
#   scripts/verify-shell-continuations.sh [--root <repo-root>]
#   scripts/verify-shell-continuations.sh --prove-failure
#
# ── Exit codes (three-valued; 2 is NEVER a pass) ─────────────────────────────
#   0  every tracked *.sh was read and none carries F1 or F2
#   1  at least one F1/F2 finding (each printed as path:line)
#   2  could not determine: root missing, not a git work tree, git absent, a
#      listed file unreadable, or ZERO *.sh enumerated (a quiet zero from a
#      blind enumeration is indistinguishable from a clean tree)
#
# ── Side-effects ─────────────────────────────────────────────────────────────
#   None. Read-only. --prove-failure writes only inside its own `mktemp -d`.
#
# ── Dependencies ─────────────────────────────────────────────────────────────
#   bash, git, grep -E, awk, mktemp.
#
# ── Cross-references ─────────────────────────────────────────────────────────
#   §1.1 (paired proof), §11.4.6 (report what was measured), §11.4.135 (every
#   fixed defect gets a standing guard), §11.4.201(6)/(7)(b) (a blind
#   instrument is rc 2, never a pass). Registered in scripts/check-registry.tsv
#   as `shell-continuations`.

set -uo pipefail

SELF="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)/$(basename "${BASH_SOURCE[0]:-$0}")"
ROOT="$(cd "$(dirname "$SELF")/.." && pwd)"
PROVE=0

while [ $# -gt 0 ]; do
    case "$1" in
        --root) ROOT="${2:-}"; shift 2 ;;
        --prove-failure) PROVE=1; shift ;;
        -h|--help) sed -n '2,62p' "$SELF" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) printf 'verify-shell-continuations.sh: unknown argument: %s\n' "$1" >&2; exit 2 ;;
    esac
done

# scan_file <path> — print "path:line: F1|F2 <text>" for every finding.
# awk, not grep, so the comment exclusion and both patterns are one pass and
# the classification is printed with the line.
scan_file() {
    awk -v f="$1" '
        /^[[:space:]]*#/ { next }
        /\\[ \t]+(&&|\|\||\|)/ { printf "%s:%d: F1 joined continuation: %s\n", f, NR, substr($0, 1, 140); next }
        /\\[ \t]+$/            { printf "%s:%d: F2 backslash then trailing blank: %s\n", f, NR, substr($0, 1, 140) }
    ' "$1"
}

run_check() {
    local root="$1"
    [ -n "$root" ] && [ -d "$root" ] || {
        printf 'UNDETERMINED: --root %s is not a directory\n' "${root:-<empty>}" >&2; return 2; }
    command -v git >/dev/null 2>&1 || {
        printf 'UNDETERMINED: git is not on PATH; the tracked set cannot be enumerated\n' >&2; return 2; }
    git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
        printf 'UNDETERMINED: %s is not a git work tree; the tracked set cannot be enumerated\n' "$root" >&2; return 2; }

    local list n=0 unread=0 hits="" f out
    list="$(git -C "$root" ls-files -- '*.sh' 2>/dev/null)" || {
        printf 'UNDETERMINED: git ls-files failed at %s\n' "$root" >&2; return 2; }
    while IFS= read -r f; do
        [ -n "$f" ] || continue
        # A gitlink never matches '*.sh'; a path that is not a regular readable
        # file (deleted in the work tree, permissions) is a blind spot, not a pass.
        if [ ! -f "$root/$f" ] || [ ! -r "$root/$f" ]; then
            printf 'UNDETERMINED: listed but unreadable: %s\n' "$f" >&2
            unread=$((unread + 1)); continue
        fi
        n=$((n + 1))
        out="$(cd "$root" && scan_file "$f")"
        [ -n "$out" ] && hits="${hits}${out}"$'\n'
    done <<<"$list"

    if [ "$n" -eq 0 ]; then
        printf 'UNDETERMINED: zero tracked *.sh enumerated at %s — a blind enumeration, not a clean tree\n' "$root" >&2
        return 2
    fi
    local nh=0
    [ -n "$hits" ] && nh="$(printf '%s' "$hits" | grep -c .)"
    if [ "$nh" -gt 0 ]; then
        printf '%s' "$hits"
        printf '❌ SHELL-CONTINUATIONS: FAIL — %s broken continuation(s) across %s tracked *.sh read' "$nh" "$n"
        [ "$unread" -gt 0 ] && printf ' (%s further file(s) could not be read)' "$unread"
        printf '\n'
        return 1
    fi
    if [ "$unread" -gt 0 ]; then
        printf 'UNDETERMINED: %s tracked *.sh read clean, but %s could not be read\n' "$n" "$unread" >&2
        return 2
    fi
    printf '✅ SHELL-CONTINUATIONS: PASS — %s tracked *.sh read, no broken line continuation (F1/F2)\n' "$n"
    return 0
}

if [ "$PROVE" -eq 1 ]; then
    # §1.1 paired proof. Every specimen is built in a throwaway git repo, so the
    # control is green BY CONSTRUCTION and no state of the real tree can switch
    # the battery off. Mutations are DATA (file contents), never code edits.
    LAB="$(mktemp -d "${TMPDIR:-/tmp}/shell-cont-proof.XXXXXX")" || {
        printf 'UNDETERMINED: cannot create a proof sandbox; nothing was proved\n' >&2; exit 2; }
    trap 'rm -rf "$LAB"' EXIT
    command -v git >/dev/null 2>&1 || { printf 'UNDETERMINED: git absent; the proof cannot build its specimen\n' >&2; exit 2; }
    PASSN=0; FAILN=0
    ok()  { PASSN=$((PASSN + 1)); printf '✅ %-34s %s\n' "$1" "$2"; }
    bad() { FAILN=$((FAILN + 1)); printf '❌ %-34s %s\n' "$1" "$2"; }
    G=(env GIT_CONFIG_NOSYSTEM=1 HOME="$LAB/home" git)
    mkdir -p "$LAB/home"
    spec() {  # spec <dir> — fresh repo holding ONE tracked script, content on stdin
        rm -rf "$1"; mkdir -p "$1"
        "${G[@]}" -C "$1" init -q >/dev/null 2>&1
        cat > "$1/s.sh"
        "${G[@]}" -C "$1" add s.sh >/dev/null 2>&1
    }
    expect() {  # expect <label> <want-rc> <dir> [needle]
        local out rc
        out="$(bash "$SELF" --root "$3" 2>&1)"; rc=$?
        if [ "$rc" -eq "$2" ] && { [ -z "${4:-}" ] || grep -qF -- "$4" <<<"$out"; }; then
            ok "$1" "rc=${rc}${4:+, and it named '$4'}"
        else
            bad "$1" "expected rc=$2${4:+ naming '$4'}, got rc=${rc}"
            printf '%s\n' "$out" | tail -3 | sed 's/^/        /'
        fi
    }

    # The specimens are assembled from $BS rather than written out literally:
    # this file is itself a tracked *.sh, and a literal broken continuation in
    # its own source would be a real F1 finding against this tree.
    BS='\'
    printf '%s\n' '#!/usr/bin/env bash' "if grep -q a <<<\"\$x\" ${BS}" \
        '   && grep -q b <<<"$x"; then echo both; fi' | spec "$LAB/c"
    expect "CONTROL well-formed continuation" 0 "$LAB/c" "PASS"

    printf '%s\n' '#!/usr/bin/env bash' \
        "if grep -q a <<<\"\$x\" ${BS}       && grep -q b <<<\"\$x\"; then echo both; fi" | spec "$LAB/m1"
    expect "M1 joined continuation (&&)" 1 "$LAB/m1" "s.sh:2: F1"

    printf '%s\n' '#!/usr/bin/env bash' "false ${BS}   || echo x" | spec "$LAB/m2"
    expect "M2 joined continuation (||)" 1 "$LAB/m2" "s.sh:2: F1"

    printf '%s\n' '#!/usr/bin/env bash' "echo a ${BS} " '  b' | spec "$LAB/m3"
    expect "M3 backslash then trailing blank" 1 "$LAB/m3" "s.sh:2: F2"

    printf '%s\n' '#!/usr/bin/env bash' "# the defect shape: grep a <<<\"\$x\" ${BS}   && grep b" 'true' | spec "$LAB/m4"
    expect "M4 comment line is NOT flagged" 0 "$LAB/m4" "PASS"

    expect "M5 root absent -> rc 2" 2 "$LAB/no-such-root" "UNDETERMINED"

    mkdir -p "$LAB/plain"; printf 'true\n' > "$LAB/plain/s.sh"
    expect "M6 not a git work tree -> rc 2" 2 "$LAB/plain" "not a git work tree"

    rm -rf "$LAB/empty"; mkdir -p "$LAB/empty"; "${G[@]}" -C "$LAB/empty" init -q >/dev/null 2>&1
    expect "M7 zero *.sh enumerated -> rc 2" 2 "$LAB/empty" "zero tracked"

    printf '%s\n' '#!/usr/bin/env bash' 'true' | spec "$LAB/m8"; rm -f "$LAB/m8/s.sh"
    expect "M8 listed-but-unreadable -> rc 2" 2 "$LAB/m8" "listed but unreadable"

    printf -- '----------------------------------------------------------------------\n'
    if [ "$FAILN" -eq 0 ]; then
        printf '✅ SHELL-CONTINUATIONS §1.1 MUTATION PROOF: PASS — control green, and %s mutations\n' "$((PASSN - 1))"
        printf '   were each caught with the right verdict (M1-M3 -> 1, M4 -> 0, M5-M8 -> 2).\n'
        exit 0
    fi
    printf '❌ SHELL-CONTINUATIONS §1.1 MUTATION PROOF: FAIL — %s case(s) did not hold\n' "$FAILN"
    exit 1
fi

run_check "$ROOT"
exit $?
