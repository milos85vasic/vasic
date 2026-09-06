#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# verify-check-registry.sh — the meta-check.
#
# WHY THIS EXISTS
# ---------------
# specs/001-workshop-curriculum-platform/spec.md asserts two success criteria
# that are universally quantified over "every automated check":
#
#   SC-012  every check has a paired demonstration that it FAILS when the
#           guarded condition is broken — 100%, no exceptions;
#   SC-013  the system distinguishes "unable to verify" from "passed" and
#           "failed" in 100% of its checks.
#
# A claim quantified over a set nobody has enumerated cannot be evaluated, and
# per §11.4 an unevaluable PASS is a bluff. scripts/check-registry.tsv is that
# enumeration; this script is what makes it true rather than aspirational.
#
# THE FAILURE CLASS THIS CATCHES, MEASURED ON THIS TREE
# -----------------------------------------------------
# Two gates in this repository were found (2026-09-01) with proofs that could
# not do their job: one whose pre-flight control failed against the live tree,
# so its mutation battery ran ZERO mutations and exited 1 without ever proving
# anything; one that exercised only sandboxed copies while the real entry point
# could not start. Neither is visible from a green summary line. A registry
# walked by an instrument is what surfaces that class.
#
# WHAT IT VERIFIES
#   - every registered entry point exists and is executable
#   - every registered paired proof exists, is a REAL argv case arm (or a real
#     sibling script), and is non-trivial rather than a stub that returns 0
#   - every three-valued claim is EXECUTED: the declared probe must drive the
#     entry point to rc 2, and the probe itself must not be a mere bad-usage
#     probe, because "unknown option" is not "unable to verify"
#   - ANTI-DRIFT: every `*.sh` under a declared scanroot is accounted for by a
#     check, debt, or exempt row. An unregistered check is a FAILURE. Without
#     this half the registry is decorative and rots silently.
#   - RATCHET: a debt row whose owed property is found SATISFIED is a FAILURE.
#     Debt may hide a gap; it must not be able to hide a fix.
#
# EXIT CODES — this instrument is not exempt from its own SC-013 rule
#   0  every registered check conforms (registered debt may exist; it is
#      printed loudly and is NOT compliance)
#   1  a real conformance violation
#   2  COULD NOT DETERMINE — registry missing/unreadable/malformed, a scanroot
#      absent, a probe that timed out. Never reported as 0 and never as 1.
#
# USAGE
#   scripts/verify-check-registry.sh                 structural; seconds
#   scripts/verify-check-registry.sh --run-proofs    also EXECUTES each paired
#                                                    proof (minutes; see below)
#   scripts/verify-check-registry.sh --strict        registered debt -> FAIL
#   scripts/verify-check-registry.sh --list          print the parsed registry
#   scripts/verify-check-registry.sh --root DIR      verify another tree
#   scripts/verify-check-registry.sh --prove-failure its own §1.1 paired proof
#
# THE STRUCTURAL / EXECUTED TRADE, STATED RATHER THAN HIDDEN
# ----------------------------------------------------------
# Executing every paired proof is the strongest evidence and is far too slow for
# a pre-push hook: the proofs in this tree build throwaway repositories and run
# whole mutation batteries, and one of them alone exceeds the budget for the
# entire hook. So the default run verifies proof STRUCTURE (the case arm exists,
# the file exists, it is non-trivial) and EXECUTES every three-valued probe,
# which is cheap. `--run-proofs` executes the batteries too. This is a declared
# trade, not silent sampling: the default run never claims a proof was observed
# to work, and says so in its own summary line.
# ------------------------------------------------------------------------------
set -uo pipefail

# --- portability helpers (Environment Adaptability) -------------------------
# GNU `sed -i` and BSD/macOS `_sed_i ''` take incompatible arguments, so NO
# single in-place sed invocation is portable. Edit through a temp file and copy
# back: `cat >` preserves the target's inode, mode and ownership, which `mv`
# would silently replace.
_sed_i() {
    local _f="${!#}" _t _rc=0
    _t="$(mktemp)" || return 1
    if sed "${@:1:$#-1}" "$_f" >"$_t"; then cat "$_t" >"$_f" || _rc=1; else _rc=1; fi
    rm -f "$_t"
    return "$_rc"
}

# Octal file mode, portably. The GNU coreutils spelling asks for `%a` with the
# format flag; BSD/macOS asks for `%Lp` with the -f flag. THE TWO MUST NOT BE
# `||`-CHAINED, because one of them can HALF-SUCCEED: on GNU coreutils `-f` is
# --file-system and takes no argument, so the BSD spelling parses the format as
# a FILE operand, fails on the format (stderr, swallowed by 2>/dev/null) and
# SUCCEEDS on the real file, writing that file's filesystem report to STDOUT
# while exiting 1 because one operand failed.
#
# WHICH ORDERING PRODUCES THAT, MEASURED -- a correction, not a restatement.
# An earlier revision of this comment attributed a "220 bytes on stdout, 221
# after the trailing `|| printf` appended a question mark" measurement to the
# GNU-first chain. THAT IS WITHDRAWN: it does not reproduce, and _file_mode has
# no such prior form in git history to have produced it. Re-measured on this
# host 2026-09-01 against a mode-754 file, GNU coreutils 9.7:
#
#   GNU-first  `stat -c %a f || stat -f %Lp f || printf '?'`   -> "754", 3 bytes
#   BSD-first  `stat -f %Lp f || stat -c %a f || printf '?'`   -> 231 bytes of
#                                                                 filesystem report
#   GNU-first, file absent                                     -> "?",   1 byte
#
# So the garbage belongs to the BSD-FIRST ordering -- which is exactly the
# ordering portable_mtime() in _tools/pdf/build-pdfs.sh historically had. The
# conclusion the old text drew is unchanged and correct; only the ordering it
# pinned the number to was wrong.
#
# The defect here was therefore LATENT, not live: it is one reordering, or one
# host whose `stat` is neither GNU nor BSD, away from mattering, and "it happens
# to be ordered safely" is not portability. Two measurements make that concrete:
#
#   * GENUINE BSD (FreeBSD 14.2 usr.bin/stat, built from vendor source and run
#     on this host 2026-09-01): `stat -c %a` is rejected by getopt -- the option
#     string is "f:FHlLnqrst:x" and contains no `c` -- so it prints usage to
#     STDERR, NOTHING to stdout, and exits 1. An `||` fallback there REPLACES
#     rather than appends. Current macOS is the same code: Apple file_cmds
#     stat.c uses the same option string.
#   * toybox 0.8.13 (measured 2026-09-01): `stat -f %Lp` writes 215 bytes of
#     filesystem report to STDOUT **and exits 0**. On that implementation an
#     exit-status test does not merely accept garbage, it never even fires.
#     Validating the OUTPUT is the only form that survives all three.
#
# So each spelling is run SEPARATELY and its OUTPUT is validated as three or
# four octal digits before it is accepted. `?` is printed only when NEITHER
# spelling produced a mode: a could-not-determine marker, never a fabricated
# mode, and never a question mark glued onto someone else's stdout.
#
# Same shape as portable_mtime() in _tools/pdf/build-pdfs.sh -- one idiom for
# this problem across the tree, not five.
# Paired §1.1 proof: `bash scripts/verify-check-registry.sh --prove-filemode`.
_file_mode() {
    local _m
    for _m in "$(stat -c %a "$1" 2>/dev/null)" "$(stat -f %Lp "$1" 2>/dev/null)"; do
        if [[ "$_m" =~ ^[0-7]{3,4}$ ]]; then printf '%s' "$_m"; return 0; fi
    done
    printf '?'
    return 1
}


SELF_NAME="$(basename -- "${BASH_SOURCE[0]}")"
SELF_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)" || {
    echo "FATAL: cannot resolve script directory" >&2; exit 2; }

ROOT=""
STRICT=0
RUN_PROOFS=0
QUIET=0
LIST=0
PROVE=0
PROVE_FILEMODE=0

PROBE_TIMEOUT="${CHECKREG_PROBE_TIMEOUT:-60}"
PROOF_TIMEOUT="${CHECKREG_PROOF_TIMEOUT:-900}"

usage() {
    sed -n '/^# USAGE/,/^# THE STRUCTURAL/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --root)          shift; ROOT="${1:-}" ;;
        --strict)        STRICT=1 ;;
        --run-proofs)    RUN_PROOFS=1 ;;
        --quiet)         QUIET=1 ;;
        --list)          LIST=1 ;;
        --prove-failure) PROVE=1 ;;
        --prove-filemode) PROVE_FILEMODE=1 ;;
        -h|--help)       usage; exit 0 ;;
        *) echo "$SELF_NAME: unknown option '$1'" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

# ──────────────────────────────────────────────────────────────────────────────
# §1.1 PAIRED MUTATION PROOF for _file_mode  —  --prove-filemode
#
#   0  the helper is portable-correct
#   1  the helper is broken
#   2  COULD NOT DETERMINE (the fixture could not be established) — never a pass
#
# A DELIBERATELY SEPARATE flag from --prove-failure: that battery reports
# "10 mutations" by subtracting its own control count from P_PASS, so folding
# assertions into it would silently corrupt the number it publishes.
#
# A1 exercises the host's native spelling.
#
# A2 exercises the BSD/macOS contract. IT IS A MEASUREMENT WHENEVER ONE CAN BE
# HAD, AND A SIMULATION ONLY WHEN ONE CANNOT — the label follows the evidence
# actually used at run time and is never hardcoded. Set VASIC_BSD_STAT to a
# genuine BSD `stat` and A2 runs against that binary; the gate first probes it
# for the BSD contract and refuses to call it BSD if it does not answer like
# one. With nothing supplied, A2 falls back to the stub below and says SIM.
#
# The earlier claim here — "no BSD or macOS system is reachable and none can be
# synthesised (no busybox, no toybox, no bsdstat/gstat, no BSD container
# image)" — is WITHDRAWN. It was false in three of its four parts, established
# 2026-09-01 on this host:
#
#   * busybox 1.37.0 and toybox 0.8.13 are BOTH in this host's package
#     repositories and were extracted to a scratch prefix without installing.
#     (Neither is BSD — both follow GNU spellings — but the sentence asserting
#     their absence was simply wrong, and toybox produced the sharpest finding
#     in this whole area: see the note on _file_mode above.)
#   * A FreeBSD 14.2 container image DOES exist and pulls:
#       podman pull --os freebsd --arch amd64 docker.io/freebsd/freebsd-runtime:14.2
#     What is TRUE is that its userland cannot EXECUTE here: the binaries are
#     ELF "for FreeBSD 14.2" with interpreter /libexec/ld-elf.so.1, and running
#     one under `podman run --rootfs` on this Linux kernel dies with SIGSEGV
#     (rc 139) as soon as it issues a FreeBSD syscall. That is the accurate
#     statement of the limit, and it is narrower than the one it replaces.
#   * The genuine vendor SOURCE compiles and runs natively. FreeBSD 14.2
#     usr.bin/stat/stat.c builds against glibc with a prelude supplying only
#     FreeBSD-only libc interfaces that no path under test touches, and agrees
#     with GNU stat on this host's files (%Lp -> 754, %m -> the same epoch).
#     That build is how the BSD side of every claim in this file was measured.
#     Reproduce it with the recipe in docs/environment-adaptability/AUDIT.md.
#
# A3 and A5 are the assertions that DISCRIMINATE the fixed helper from the
# broken one, and neither is invented:
#   A3 reproduces what GNU stat does when the BSD spelling is reached — format
#      string rejected as a missing file (stderr), the real file's filesystem
#      report on STDOUT, exit 1. An `||` chain accepts that stdout on the
#      strength of the exit status and appends its own fallback to it.
#   A5 reproduces the MEASURED toybox 0.8.13 behaviour: the same garbage on
#      stdout but exit **0**. An `||` chain does not merely mis-handle that, it
#      never fires at all. A3 alone cannot catch a subject that tests rc; A5
#      cannot be passed by anything except validating the output.
# The output-validating form returns `?` alone in both cases.
#
# The fixture is read back by a DUPLICATED probe that never calls _file_mode. A
# gate that establishes its fixture with its own subject can only ever report
# UNDETERMINED when that subject breaks, laundering a real defect into "could
# not verify" — so the duplication below is deliberate, not an oversight.
# ──────────────────────────────────────────────────────────────────────────────
if [[ $PROVE_FILEMODE -eq 1 ]]; then
    echo "CM-CHECK-REGISTRY §1.1 PAIRED MUTATION PROOF — _file_mode portability"
    echo "----------------------------------------------------------------------"
    FM_PASS=0; FM_FAIL=0
    fm_ok()  { FM_PASS=$((FM_PASS+1)); printf '✅ %-24s %s\n' "$1" "$2"; }
    fm_bad() { FM_FAIL=$((FM_FAIL+1)); printf '❌ %-24s %s\n' "$1" "$2"; }

    FMW="$(mktemp -d "${TMPDIR:-/tmp}/filemode-proof.XXXXXX")" || {
        echo "UNDETERMINED: cannot create a sandbox, so nothing was proved." >&2; exit 2; }
    trap 'rm -rf "$FMW"' EXIT INT TERM

    : >"$FMW/subject"
    chmod 754 "$FMW/subject" || {
        echo "UNDETERMINED: cannot chmod inside the sandbox, so the fixture is unverified." >&2; exit 2; }

    # Independent readback — deliberately NOT _file_mode. See the note above.
    _fm_readback() {
        local _v
        for _v in "$(stat -c %a "$1" 2>/dev/null)" "$(stat -f %Lp "$1" 2>/dev/null)"; do
            if [[ "$_v" =~ ^[0-7]{3,4}$ ]]; then printf '%s' "$_v"; return 0; fi
        done
        return 1
    }
    if [[ "$(_fm_readback "$FMW/subject" || echo x)" != "754" ]]; then
        echo "UNDETERMINED: cannot establish a known file mode on this host — the" >&2
        echo "  fixture is unverified, so this gate reports neither pass nor fail." >&2
        exit 2
    fi

    mkdir -p "$FMW/bin-bsd" "$FMW/bin-half"

    # A2 stub: the BSD/macOS contract. No format flag of the GNU spelling at all
    # (usage error on stderr, NOTHING on stdout); -f answers with the mode.
    cat >"$FMW/bin-bsd/stat" <<'FM_BSD_STUB'
#!/usr/bin/env bash
case "${1:-}" in
  -c) echo "usage: stat [-FLnq] [-f format | -l | -r | -s | -x] [file ...]" >&2; exit 1 ;;
  -f) if [ "${2:-}" = "%Lp" ] && [ -e "${3:-}" ]; then echo 754; exit 0; fi; exit 1 ;;
esac
exit 1
FM_BSD_STUB

    # A3 stub: the measured GNU behaviour when the BSD spelling is reached —
    # garbage on STDOUT and exit 1 at the same time.
    cat >"$FMW/bin-half/stat" <<'FM_HALF_STUB'
#!/usr/bin/env bash
case "${1:-}" in
  -c) exit 1 ;;
  -f) echo "stat: cannot read file system information for the format operand" >&2
      printf '  File: "%s"\n' "${3:-}"
      printf '    ID: 2b093ae8e28c99dc Namelen: 255     Type: tmpfs\n'
      printf 'Block size: 4096       Fundamental block size: 4096\n'
      printf 'Blocks: Total: 8203131    Free: 6350159    Available: 6350159\n'
      printf 'Inodes: Total: 8203131    Free: 8179967\n'
      exit 1 ;;
esac
exit 1
FM_HALF_STUB
    # A5 stub: the MEASURED toybox 0.8.13 behaviour — the same filesystem
    # report on stdout, but exit 0, so an exit-status test never even fires.
    mkdir -p "$FMW/bin-zero"
    cat >"$FMW/bin-zero/stat" <<'FM_ZERO_STUB'
#!/usr/bin/env bash
case "${1:-}" in
  -c) exit 1 ;;
  -f) echo "stat: '${2:-}': No such file or directory" >&2
      printf '  File: "%s"\n' "${3:-}"
      printf '    ID: 2b093ae8e28c99dc Namelen: 255     Type: tmpfs\n'
      printf 'Block size: 4096       Fundamental block size: 4096\n'
      printf 'Blocks: Total: 8203131    Free: 6350159    Available: 6350159\n'
      printf 'Inodes: Total: 8203131    Free: 8179967\n'
      exit 0 ;;
esac
exit 1
FM_ZERO_STUB
    chmod 755 "$FMW/bin-bsd/stat" "$FMW/bin-half/stat" "$FMW/bin-zero/stat"

    # If a genuine BSD `stat` was supplied, PROVE it behaves like one before
    # believing the label. The contract probed is precisely the claim under
    # test: `-c` must produce EMPTY stdout, and `-f %Lp` must produce the mode.
    # A binary that fails the probe is not called BSD; A2 says SIM instead.
    FM_A2_KIND="SIM"; FM_A2_WHAT="stub reproducing the BSD stat contract"
    if [[ -n "${VASIC_BSD_STAT:-}" && -x "${VASIC_BSD_STAT}" ]]; then
        _p_c="$("$VASIC_BSD_STAT" -c %a "$FMW/subject" 2>/dev/null)"
        _p_f="$("$VASIC_BSD_STAT" -f %Lp "$FMW/subject" 2>/dev/null)"
        if [[ -z "$_p_c" && "$_p_f" == "754" ]]; then
            ln -sf "$VASIC_BSD_STAT" "$FMW/bin-bsd/stat"
            FM_A2_KIND="MEASURED"; FM_A2_WHAT="$VASIC_BSD_STAT"
        else
            printf 'ℹ %-24s %s\n' "A2 bsd-binary" \
              "VASIC_BSD_STAT did not answer to the BSD contract (-c gave ${#_p_c} bytes, -f gave '${_p_f}'); using the stub"
        fi
    fi

    a1="$(_file_mode "$FMW/subject")"
    if [[ "$a1" == "754" ]]; then
        fm_ok "A1 host-native" "the host spelling returned exactly 754"
    else
        fm_bad "A1 host-native" "expected 754, got '${a1}' (${#a1} bytes)"
    fi

    a2="$(PATH="$FMW/bin-bsd:$PATH"; hash -r; _file_mode "$FMW/subject")"
    if [[ "$a2" == "754" ]]; then
        fm_ok "A2 bsd-contract (${FM_A2_KIND})" "the fallback spelling returned exactly 754 — ${FM_A2_WHAT}"
    else
        fm_bad "A2 bsd-contract (${FM_A2_KIND})" "expected 754, got '${a2}' (${#a2} bytes) — ${FM_A2_WHAT}"
    fi

    a3="$(PATH="$FMW/bin-half:$PATH"; hash -r; _file_mode "$FMW/subject")"
    if [[ "$a3" == "?" ]]; then
        fm_ok "A3 half-success" "garbage on stdout at rc 1 was REJECTED; reported '?' (1 byte)"
    else
        fm_bad "A3 half-success" "accepted a non-mode: ${#a3} bytes, tail '${a3: -24}'"
    fi

    a4="$(_file_mode "$FMW/does-not-exist")"
    if [[ "$a4" == "?" ]]; then
        fm_ok "A4 missing-file" "reported '?' rather than inventing a mode"
    else
        fm_bad "A4 missing-file" "expected '?', got '${a4}' (${#a4} bytes)"
    fi

    a5="$(PATH="$FMW/bin-zero:$PATH"; hash -r; _file_mode "$FMW/subject")"
    if [[ "$a5" == "?" ]]; then
        fm_ok "A5 half-success-rc0" "garbage on stdout at rc 0 was REJECTED; reported '?' (1 byte)"
    else
        fm_bad "A5 half-success-rc0" "accepted a non-mode: ${#a5} bytes, tail '${a5: -24}'"
    fi

    echo "----------------------------------------------------------------------"
    if [[ $FM_FAIL -gt 0 ]]; then
        echo "❌ _file_mode §1.1 PROOF: FAIL — ${FM_FAIL} of $((FM_PASS + FM_FAIL)) assertion(s) did not hold."
        echo "   Restore the output-validating form of _file_mode; an || chain over these two"
        echo "   spellings accepts stdout it never inspected."
        exit 1
    fi
    echo "✅ _file_mode §1.1 MUTATION PROOF: PASS — ${FM_PASS} assertions, including the"
    echo "   half-success cases at rc 1 (A3, GNU) and rc 0 (A5, toybox) that no || chain"
    echo "   can survive."
    if [[ "$FM_A2_KIND" == "MEASURED" ]]; then
        echo "   A2 is a MEASUREMENT on a genuine BSD stat: ${FM_A2_WHAT}"
    else
        echo "   A2 is a SIMULATION of the BSD stat contract. To turn it into a measurement,"
        echo "   set VASIC_BSD_STAT to a genuine BSD stat (build recipe:"
        echo "   docs/environment-adaptability/AUDIT.md)."
    fi
    exit 0
fi

if [[ -n "$ROOT" ]]; then
    ROOT="$(cd -- "$ROOT" 2>/dev/null && pwd)" || {
        echo "UNDET  target root does not exist: it cannot be inspected, so this is neither a pass nor a fail" >&2
        exit 2; }
else
    ROOT="$(cd -- "$SELF_DIR/.." && pwd)" || {
        echo "FATAL: cannot derive repository root" >&2; exit 2; }
fi

REGISTRY="$ROOT/scripts/check-registry.tsv"

# ── output ───────────────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
    R=$'\033[0;31m'; G=$'\033[0;32m'; Y=$'\033[0;33m'; B=$'\033[1m'; N=$'\033[0m'
else
    R=""; G=""; Y=""; B=""; N=""
fi

N_PASS=0; N_FAIL=0; N_DEBT=0; N_UNDET=0; N_NOTE=0

say()   { [[ $QUIET -eq 1 ]] || printf '%s\n' "$*"; }
ok()    { N_PASS=$((N_PASS+1));  [[ $QUIET -eq 1 ]] || printf '%s✅ PASS%s  [%s] %s\n' "$G" "$N" "$1" "$2"; }
bad()   { N_FAIL=$((N_FAIL+1));  printf '%s❌ FAIL%s  [%s] %s\n' "$R" "$N" "$1" "$2"; }
debt()  { N_DEBT=$((N_DEBT+1));  [[ $QUIET -eq 1 ]] || printf '%s⚠ DEBT%s  [%s] %s\n' "$Y" "$N" "$1" "$2"; }
undet() { N_UNDET=$((N_UNDET+1)); printf '%s◍ UNDET%s [%s] %s\n' "$Y" "$N" "$1" "$2"; }
note()  { N_NOTE=$((N_NOTE+1));  [[ $QUIET -eq 1 ]] || printf '%sℹ NOTE%s  [%s] %s\n' "$Y" "$N" "$1" "$2"; }

# ──────────────────────────────────────────────────────────────────────────────
# §1.1 PAIRED MUTATION PROOF
#
# The design decision that matters here, and why it is made this way:
#
# A proof whose CONTROL is the live tree stops working the moment the live tree
# is red — the battery never runs and the instrument reports rc 1 having proved
# nothing. That is not hypothetical: `scripts/verify-governance-cascade.sh
# --prove-failure` was observed on 2026-09-01 to run ZERO mutations for exactly
# that reason. So this proof's control is a SYNTHETIC tree that is green BY
# CONSTRUCTION, and the live tree is a reported PRE-FLIGHT that never gates the
# battery. The live run still happens — a proof that only ever touches a
# sandbox, while the real entry point cannot start, is the other half of the
# same defect, and was also observed in this tree.
#
# Every mutation writes ONLY inside a `mktemp -d`. Nothing under $ROOT is
# touched, so no restore of the real repository is required or performed.
# ──────────────────────────────────────────────────────────────────────────────
if [[ $PROVE -eq 1 ]]; then
    printf '%sCM-CHECK-REGISTRY §1.1 PAIRED MUTATION PROOF%s\n' "$B" "$N"
    echo "----------------------------------------------------------------------"

    SELF="$SELF_DIR/$SELF_NAME"
    P_PASS=0; P_FAIL=0

    p_ok()   { P_PASS=$((P_PASS+1)); printf '%s✅ %-28s%s %s\n' "$G" "$1" "$N" "$2"; }
    p_bad()  { P_FAIL=$((P_FAIL+1)); printf '%s❌ %-28s%s %s\n' "$R" "$1" "$N" "$2"; }

    # ---- PRE-FLIGHT: the REAL entry point against the REAL tree --------------
    # Reported, never gating. Its purpose is to prove the instrument STARTS.
    pf_out="$(timeout 300 bash "$SELF" --root "$ROOT" 2>&1)"; pf_rc=$?
    case "$pf_rc" in
        0) p_ok "PRE-FLIGHT live-run" "the real instrument ran against the real tree and returned rc=0" ;;
        1) printf '%sℹ %-28s%s the real instrument RAN against the real tree and returned rc=1 (a real\n' "$Y" "PRE-FLIGHT live-run" "$N"
           printf '                                violation). Reported, NOT gating: the battery below uses a synthetic\n'
           printf '                                control so a red tree cannot silently disable the proof.\n' ;;
        2) printf '%sℹ %-28s%s the real instrument returned rc=2 on the real tree (could not determine).\n' "$Y" "PRE-FLIGHT live-run" "$N" ;;
        124) p_bad "PRE-FLIGHT live-run" "the real instrument TIMED OUT on the real tree — it cannot start, so it cannot guard anything" ;;
        *) p_bad "PRE-FLIGHT live-run" "the real instrument exited rc=$pf_rc, which is outside its own 0/1/2 contract" ;;
    esac

    SB="$(mktemp -d "${TMPDIR:-/tmp}/checkreg-proof.XXXXXX")" || {
        echo "UNDET: cannot create a sandbox; the proof could not run" >&2; exit 2; }
    trap 'rm -rf "$SB"' EXIT INT TERM

    mkdir -p "$SB/scripts" "$SB/tests"

    # A synthetic check that conforms by construction: executable, a real
    # --prove-failure case arm, a non-trivial proof body (mktemp+trap+cleanup),
    # and a genuine rc-2 state reachable through a real --root case arm.
    mk_conforming_check() {
        local path="$1"
        cat >"$path" <<'FAKE'
#!/usr/bin/env bash
set -uo pipefail
ROOT=""
PROVE=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        --root)          shift; ROOT="${1:-}" ;;
        --prove-failure) PROVE=1 ;;
        --quiet)         : ;;
        *) echo "unknown option '$1'" >&2; exit 2 ;;
    esac
    shift
done
if [[ $PROVE -eq 1 ]]; then
    T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
    echo "good" >"$T/f"
    echo "M1 seeded mutation -> caught, as it must"
    echo "MUTATION PROOF: PASS — control passed and all 1 mutations were caught"
    rm -rf "$T"   # cleanup / restore
    exit 0
fi
[[ -n "$ROOT" && ! -d "$ROOT" ]] && { echo "UNDET target root does not exist" >&2; exit 2; }
exit 0
FAKE
        chmod 755 "$path"
    }

    # The same check with a proof that returns 0 while exercising NOTHING —
    # structurally indistinguishable from the real thing, visible only to
    # --run-proofs. This is the defect class the whole instrument exists for.
    mk_hollow_proof_check() {
        local path="$1"
        mk_conforming_check "$path"
        _sed_i '/^    echo "M1 seeded mutation/d; /^    echo "MUTATION PROOF: PASS/d' "$path"
    }

    # A check that owes a paired proof (debt row).
    mk_debt_check() {
        local path="$1" with_proof="${2:-0}"
        {
            printf '#!/usr/bin/env bash\nset -uo pipefail\n'
            printf 'while [[ $# -gt 0 ]]; do\n    case "$1" in\n'
            printf '        --root) shift; [[ -d "${1:-}" ]] || exit 2 ;;\n'
            [[ "$with_proof" == "1" ]] && \
            printf '        --prove-failure) T="$(mktemp -d)"; trap %s EXIT; rm -rf "$T"; exit 0 ;;\n' "'rm -rf \"\$T\"'"
            printf '    esac\n    shift\ndone\nexit 0\n'
        } >"$path"
        chmod 755 "$path"
    }

    mk_conforming_check "$SB/scripts/alpha-check.sh"
    mk_conforming_check "$SB/tests/beta-check.sh"

    # A synthetic script that is genuinely not a check (exempt row).
    printf '#!/usr/bin/env bash\necho installing\n' >"$SB/scripts/gamma-install.sh"
    chmod 755 "$SB/scripts/gamma-install.sh"

    # A synthetic check that owes a proof (debt row): no proof entry point.
    mk_debt_check "$SB/scripts/delta-audit.sh" 0

    # The instrument must also be findable in the sandbox scanroot, since a
    # scanroot named `scripts` will contain it in the real tree.
    cp "$SELF" "$SB/scripts/verify-check-registry.sh"
    chmod 755 "$SB/scripts/verify-check-registry.sh"

    write_registry() {
        cat >"$SB/scripts/check-registry.tsv" <<EOF
# synthetic registry (proof sandbox)
scanroot	scripts
scanroot	tests
exempt	scripts/gamma-install.sh	installer, not a check
exempt	scripts/verify-check-registry.sh	the instrument itself is exercised by the real registry, not this synthetic one
check	alpha	scripts/alpha-check.sh	flag	--prove-failure	--root /nonexistent
check	beta	tests/beta-check.sh	flag	--prove-failure	--root /nonexistent
debt	delta	scripts/delta-audit.sh	proof	synthetic debt row: no paired proof yet
EOF
    }

    run_sb() { timeout 180 bash "$SELF" --root "$SB" "$@" 2>&1; }

    expect() {                        # expect <label> <want-rc> <needle> <cmd...>
        local label="$1" want="$2" needle="$3"; shift 3
        local out rc
        out="$("$@")"; rc=$?
        if [[ $rc -ne $want ]]; then
            p_bad "$label" "expected rc=$want, got rc=$rc"
            printf '%s\n' "$out" | tail -4 | sed 's/^/        /'
            return
        fi
        if [[ -n "$needle" ]] && ! grep -qF -- "$needle" <<<"$out"; then
            p_bad "$label" "rc=$want as expected, but the output never NAMED '$needle' — an unnamed failure is not actionable"
            printf '%s\n' "$out" | tail -4 | sed 's/^/        /'
            return
        fi
        p_ok "$label" "rc=$want${needle:+, and it named '$needle'}"
    }

    # ---- CONTROL -------------------------------------------------------------
    write_registry
    expect "CONTROL synthetic-green" 0 "" run_sb --quiet
    if [[ $P_FAIL -gt 0 ]]; then
        echo "----------------------------------------------------------------------"
        printf '%s❌ CM-CHECK-REGISTRY §1.1 PROOF: ABORTED — the synthetic control did not pass,%s\n' "$R" "$N"
        printf '   so ZERO mutations were run and nothing below would have been proved.\n'
        exit 1
    fi

    # ---- M1  a registered check loses its paired proof ------------------------
    _sed_i 's/^        --prove-failure) PROVE=1 ;;$//' "$SB/scripts/alpha-check.sh"
    expect "M1 proof-removed" 1 "alpha" run_sb
    mk_conforming_check "$SB/scripts/alpha-check.sh"

    # ---- M2  a check claims rc 2 support it does not implement ----------------
    _sed_i 's|echo "UNDET target root does not exist" >&2; exit 2|exit 0|' "$SB/scripts/alpha-check.sh"
    expect "M2 three-valued-claimed-not-implemented" 1 "not 2" run_sb
    mk_conforming_check "$SB/scripts/alpha-check.sh"

    # ---- M3  an unregistered check appears under a scanroot -------------------
    printf '#!/usr/bin/env bash\nexit 0\n' >"$SB/scripts/epsilon-new-check.sh"
    chmod 755 "$SB/scripts/epsilon-new-check.sh"
    expect "M3 unregistered-check" 1 "epsilon-new-check.sh" run_sb
    rm -f "$SB/scripts/epsilon-new-check.sh"

    # ---- M4  the registry cannot be read --------------------------------------
    chmod 000 "$SB/scripts/check-registry.tsv"
    if [[ "$(id -u)" == "0" ]]; then
        printf '%sℹ %-28s%s running as uid 0: mode 000 is not enforced, so the unreadable-registry\n' "$Y" "M4 registry-unreadable" "$N"
        printf '                                case is exercised by removal instead.\n'
        chmod 644 "$SB/scripts/check-registry.tsv"
        mv "$SB/scripts/check-registry.tsv" "$SB/scripts/check-registry.tsv.hidden"
        expect "M4 registry-unreadable" 2 "COULD NOT DETERMINE" run_sb
        mv "$SB/scripts/check-registry.tsv.hidden" "$SB/scripts/check-registry.tsv"
    else
        expect "M4 registry-unreadable" 2 "COULD NOT DETERMINE" run_sb
        chmod 644 "$SB/scripts/check-registry.tsv"
    fi

    # ---- M5  a malformed registry row -----------------------------------------
    printf 'nonsense\tvalue\n' >>"$SB/scripts/check-registry.tsv"
    expect "M5 malformed-row" 2 "vocabulary is closed" run_sb
    write_registry

    # ---- M6  stale debt: the debt row's gap has been closed -------------------
    mk_debt_check "$SB/scripts/delta-audit.sh" 1
    expect "M6 stale-debt" 1 "STALE DEBT" run_sb
    mk_debt_check "$SB/scripts/delta-audit.sh" 0

    # ---- M7  a registered entry point disappears -------------------------------
    mv "$SB/tests/beta-check.sh" "$SB/beta-parked.sh"
    expect "M7 dead-row" 1 "beta" run_sb
    mv "$SB/beta-parked.sh" "$SB/tests/beta-check.sh"

    # ---- M8  a probe that only trips the unknown-option handler ----------------
    _sed_i 's|--root /nonexistent$|--not-a-real-flag|' "$SB/scripts/check-registry.tsv"
    expect "M8 bad-usage-probe-rejected" 1 "NOT a case arm" run_sb
    write_registry

    # ---- M9  a proof that returns 0 without exercising anything ----------------
    # This is the defect class the whole instrument exists for. Only --run-proofs
    # can see it, which is the honest reason --run-proofs exists.
    mk_hollow_proof_check "$SB/scripts/alpha-check.sh"
    expect "M9 hollow-proof (--run-proofs)" 1 "without exercising anything" run_sb --run-proofs
    mk_conforming_check "$SB/scripts/alpha-check.sh"

    # ---- M10 --strict turns registered debt into a failure ---------------------
    expect "M10 strict-debt-fails" 1 "delta" run_sb --strict

    # ---- RESTORED CONTROL ------------------------------------------------------
    expect "CONTROL restored" 0 "" run_sb --quiet
    expect "CONTROL restored (--run-proofs)" 0 "" run_sb --run-proofs --quiet

    echo "----------------------------------------------------------------------"
    if [[ $P_FAIL -gt 0 ]]; then
        printf '%s❌ CM-CHECK-REGISTRY §1.1 PROOF: FAIL — %s case(s) did not behave as required.%s\n' "$R" "$P_FAIL" "$N"
        exit 1
    fi
    printf '%s✅ CM-CHECK-REGISTRY §1.1 MUTATION PROOF: PASS%s — the real entry point ran against the\n' "$G" "$N"
    printf '   real tree, a synthetic control passed, and %s mutations were each caught with the\n' "$((P_PASS - 4))"
    printf '   right THREE-VALUED verdict: conformance breaks as rc 1 and NAMED, an unreadable or\n'
    printf '   malformed registry as rc 2 — never as a pass and never as an accusation.\n'
    exit 0
fi

# ──────────────────────────────────────────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────────────────────────────────────────

# A flag counts as REAL only when it appears at the head of a `case` arm — the
# whole prefix from line start must be case-arm-shaped. A mention inside a
# string, a comment, or a `grep` pattern (verify-all-constitution-rules.sh line
# 201 greps for '--selftest)' in OTHER files) must not be credited.
is_case_arm() {
    local file="$1" flag="$2" esc
    esc="$(printf '%s' "$flag" | sed 's/[][\.*^$/|+?(){}]/\\&/g')"
    grep -qE "^[[:space:]]*[-a-zA-Z0-9_|*[:space:]]*${esc}[[:space:]]*[|)]" "$file"
}

# A proof that cannot possibly build anything to mutate is a stub. Every real
# paired proof in this tree constructs a disposable tree and restores it; a
# file with neither idiom is asserted-not-demonstrated.
proof_is_nontrivial() {
    local file="$1"
    grep -qE 'mktemp|trap[[:space:]]' "$file" || return 1
    grep -qEi 'restore|cleanup|rm -rf|git (checkout|restore)' "$file" || return 1
    return 0
}

# Split a probe spec into leading VAR=value assignments and the remaining argv.
# No `eval`: tokens are classified, never executed as shell text.
PROBE_ENV=(); PROBE_ARGV=()
split_probe() {
    local spec="$1" tok seen_argv=0
    PROBE_ENV=(); PROBE_ARGV=()
    for tok in $spec; do
        if [[ $seen_argv -eq 0 && "$tok" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; then
            PROBE_ENV+=("$tok")
        else
            seen_argv=1
            PROBE_ARGV+=("$tok")
        fi
    done
}

# ──────────────────────────────────────────────────────────────────────────────
# Registry load — every failure here is rc 2, because an unread registry means
# the question was never asked, which is not the same as answering "yes".
# ──────────────────────────────────────────────────────────────────────────────

registry_undet() {
    printf '%s◍ UNDET%s [REGISTRY] %s\n' "$Y" "$N" "$1" >&2
    printf '%s%s: COULD NOT DETERMINE%s — the registry could not be read, so nothing was verified.\n' "$B" "$SELF_NAME" "$N" >&2
    printf '   This is neither a pass nor a fail (§11.4.6 / SC-013).\n' >&2
    exit 2
}

[[ -e "$REGISTRY" ]] || registry_undet "no registry at $REGISTRY"
[[ -f "$REGISTRY" ]] || registry_undet "registry path is not a regular file: $REGISTRY"
[[ -r "$REGISTRY" ]] || registry_undet "registry is not readable (permissions): $REGISTRY"
[[ -s "$REGISTRY" ]] || registry_undet "registry is empty: $REGISTRY"

SCANROOTS=(); EXEMPT_PATHS=(); EXEMPT_REASONS=()
CHK_ID=(); CHK_ENTRY=(); CHK_KIND=(); CHK_ARG=(); CHK_PROBE=()
DEBT_ID=(); DEBT_ENTRY=(); DEBT_OWED=(); DEBT_REASON=()

lineno=0
while IFS= read -r raw || [[ -n "$raw" ]]; do
    lineno=$((lineno+1))
    [[ -z "${raw//[[:space:]]/}" ]] && continue
    [[ "${raw:0:1}" == "#" ]] && continue
    IFS=$'\t' read -r f1 f2 f3 f4 f5 f6 _rest <<<"$raw"
    case "$f1" in
        scanroot)
            [[ -n "${f2:-}" ]] || registry_undet "line $lineno: scanroot row with no directory"
            SCANROOTS+=("$f2") ;;
        exempt)
            [[ -n "${f2:-}" && -n "${f3:-}" ]] || registry_undet "line $lineno: exempt row needs <path> and <reason>"
            EXEMPT_PATHS+=("$f2"); EXEMPT_REASONS+=("$f3") ;;
        check)
            [[ -n "${f2:-}" && -n "${f3:-}" && -n "${f4:-}" && -n "${f5:-}" && -n "${f6:-}" ]] \
                || registry_undet "line $lineno: check row needs <id> <entry> <proof-kind> <proof-arg> <undet-probe>"
            CHK_ID+=("$f2"); CHK_ENTRY+=("$f3"); CHK_KIND+=("$f4"); CHK_ARG+=("$f5"); CHK_PROBE+=("$f6") ;;
        debt)
            [[ -n "${f2:-}" && -n "${f3:-}" && -n "${f4:-}" && -n "${f5:-}" ]] \
                || registry_undet "line $lineno: debt row needs <id> <entry> <owed> <reason>"
            DEBT_ID+=("$f2"); DEBT_ENTRY+=("$f3"); DEBT_OWED+=("$f4"); DEBT_REASON+=("$f5") ;;
        *)
            registry_undet "line $lineno: unrecognised row type '$f1' — the vocabulary is closed {scanroot,exempt,check,debt}" ;;
    esac
done < "$REGISTRY"

[[ ${#SCANROOTS[@]} -gt 0 ]] || registry_undet "registry declares no scanroot: the anti-drift sweep has nothing to sweep"
[[ ${#CHK_ID[@]}   -gt 0 ]] || registry_undet "registry declares no check rows: there would be nothing to verify, and a vacuous PASS is a bluff"

if [[ $LIST -eq 1 ]]; then
    printf 'scanroots : %s\n' "${SCANROOTS[*]}"
    printf 'checks    : %s\n' "${CHK_ID[*]}"
    printf 'debt      : %s\n' "${DEBT_ID[*]:-none}"
    printf 'exempt    : %s\n' "${EXEMPT_PATHS[*]:-none}"
    exit 0
fi

say "${B}CM-CHECK-REGISTRY${N}: verifying SC-012 (paired proof) and SC-013 (three-valued exit)"
say "  registry $REGISTRY"
say "  root     $ROOT"
if [[ $RUN_PROOFS -eq 1 ]]; then
    say "  mode     STRUCTURAL + EXECUTED (--run-proofs: every paired proof is actually run)"
else
    say "  mode     STRUCTURAL (proof structure verified, NOT executed; use --run-proofs)"
fi
say "----------------------------------------------------------------------"

# ──────────────────────────────────────────────────────────────────────────────
# R0  scanroots exist
# ──────────────────────────────────────────────────────────────────────────────
for d in "${SCANROOTS[@]}"; do
    [[ -d "$ROOT/$d" ]] || registry_undet "declared scanroot '$d' is not a directory under $ROOT — the sweep cannot be performed"
done
ok "R0" "all ${#SCANROOTS[@]} declared scanroot(s) exist"

# ──────────────────────────────────────────────────────────────────────────────
# R1  no duplicate ids, no duplicate entry points
# ──────────────────────────────────────────────────────────────────────────────
dupes="$(printf '%s\n' "${CHK_ID[@]}" "${DEBT_ID[@]:-}" | grep -v '^$' | sort | uniq -d)"
if [[ -n "$dupes" ]]; then
    bad "R1" "duplicate check id(s) — a registry keyed on a non-unique id silently loses rows: $(echo "$dupes" | tr '\n' ' ')"
else
    ok "R1" "check ids are unique"
fi
dupe_entry="$(printf '%s\n' "${CHK_ENTRY[@]}" "${DEBT_ENTRY[@]:-}" "${EXEMPT_PATHS[@]:-}" | grep -v '^$' | sort | uniq -d)"
if [[ -n "$dupe_entry" ]]; then
    bad "R1b" "path registered more than once (a check cannot also be exempt or debt): $(echo "$dupe_entry" | tr '\n' ' ')"
else
    ok "R1b" "every registered path appears exactly once"
fi

# ──────────────────────────────────────────────────────────────────────────────
# R2  exempt rows point at real files
# ──────────────────────────────────────────────────────────────────────────────
i=0
while [[ $i -lt ${#EXEMPT_PATHS[@]} ]]; do
    p="${EXEMPT_PATHS[$i]}"
    if [[ ! -f "$ROOT/$p" ]]; then
        bad "R2" "exempt row points at a file that does not exist: $p (a dead exemption hides the next file that takes its name)"
    fi
    i=$((i+1))
done
[[ $N_FAIL -eq 0 ]] && ok "R2" "all ${#EXEMPT_PATHS[@]} exemption(s) point at real files"

# ──────────────────────────────────────────────────────────────────────────────
# R3  every registered CHECK conforms
# ──────────────────────────────────────────────────────────────────────────────
i=0
while [[ $i -lt ${#CHK_ID[@]} ]]; do
    id="${CHK_ID[$i]}"; entry="${CHK_ENTRY[$i]}"
    kind="${CHK_KIND[$i]}"; arg="${CHK_ARG[$i]}"; probe="${CHK_PROBE[$i]}"
    abs="$ROOT/$entry"
    i=$((i+1))

    if [[ ! -f "$abs" ]]; then
        bad "$id" "registered entry point does not exist: $entry"
        continue
    fi
    if [[ ! -x "$abs" ]]; then
        bad "$id" "registered entry point is not executable: $entry (mode $(_file_mode "$abs"))"
        continue
    fi

    # --- SC-012: the paired proof -------------------------------------------
    case "$kind" in
        flag)
            if ! is_case_arm "$abs" "$arg"; then
                bad "$id" "declares proof-kind 'flag' with '$arg', but '$arg' is not a real case arm in $entry — the declared proof cannot be invoked (SC-012)"
                continue
            fi
            if ! proof_is_nontrivial "$abs"; then
                bad "$id" "the '$arg' proof in $entry builds nothing and restores nothing — it is a stub that can only return 0, which demonstrates nothing (SC-012)"
                continue
            fi
            ok "$id" "SC-012 paired proof: '$arg' is a real case arm in $entry and is non-trivial"
            ;;
        sibling)
            sib="$ROOT/$arg"
            if [[ ! -f "$sib" ]]; then
                bad "$id" "declares proof-kind 'sibling' at '$arg', but no such file exists (SC-012)"
                continue
            fi
            if [[ ! -x "$sib" ]]; then
                bad "$id" "sibling proof '$arg' exists but is not executable (SC-012)"
                continue
            fi
            if ! proof_is_nontrivial "$sib"; then
                bad "$id" "sibling proof '$arg' builds nothing and restores nothing — it is a stub (SC-012)"
                continue
            fi
            ok "$id" "SC-012 paired proof: sibling $arg exists, is executable and is non-trivial"
            ;;
        none)
            bad "$id" "check row declares proof-kind 'none'. A check with no paired proof is not a check row — register it as 'debt' with a stated reason, or give it a proof (SC-012)"
            continue
            ;;
        *)
            bad "$id" "unrecognised proof-kind '$kind' — the vocabulary is closed {flag,sibling}"
            continue
            ;;
    esac

    # --- SC-013: three-valued exit, EXECUTED not asserted --------------------
    split_probe "$probe"
    reject=0
    for tok in "${PROBE_ARGV[@]}"; do
        [[ "$tok" == --* ]] || continue
        if ! is_case_arm "$abs" "$tok"; then
            bad "$id" "the declared rc-2 probe uses '$tok', which is NOT a case arm in $entry — it would only trip the unknown-option handler. Bad usage is not 'unable to verify'; such a probe credits SC-013 without testing it"
            reject=1; break
        fi
    done
    [[ $reject -eq 1 ]] && continue

    if ! command -v timeout >/dev/null 2>&1; then
        undet "$id" "coreutils 'timeout' is unavailable, so the rc-2 probe cannot be bounded; refusing to run it unbounded"
        continue
    fi
    if [[ ${#PROBE_ENV[@]} -gt 0 ]]; then
        env "${PROBE_ENV[@]}" timeout "$PROBE_TIMEOUT" bash "$abs" "${PROBE_ARGV[@]}" >/dev/null 2>&1
    else
        timeout "$PROBE_TIMEOUT" bash "$abs" "${PROBE_ARGV[@]}" >/dev/null 2>&1
    fi
    prc=$?
    if [[ $prc -eq 124 ]]; then
        undet "$id" "the rc-2 probe timed out after ${PROBE_TIMEOUT}s; its three-valued claim could not be evaluated"
        continue
    fi
    if [[ $prc -ne 2 ]]; then
        bad "$id" "claims three-valued exit, but the declared could-not-determine probe ('$probe') returned rc=$prc, not 2 — the claim is not implemented (SC-013)"
        continue
    fi
    ok "$id" "SC-013 three-valued exit: probe '$probe' -> rc 2, distinct from 0 and 1"

    # --- optional: actually execute the paired proof --------------------------
    if [[ $RUN_PROOFS -eq 1 && "$kind" == "flag" ]]; then
        # Only pass --quiet to a proof that actually declares it; handing an
        # unknown option to a strict parser turns a working proof into a rc-2
        # usage error and would be scored as a broken proof.
        if is_case_arm "$abs" "--quiet"; then
            out="$(timeout "$PROOF_TIMEOUT" bash "$abs" "$arg" --quiet 2>&1)"; frc=$?
        else
            out="$(timeout "$PROOF_TIMEOUT" bash "$abs" "$arg" 2>&1)"; frc=$?
        fi
        if [[ $frc -eq 124 ]]; then
            undet "$id" "--run-proofs: the paired proof timed out after ${PROOF_TIMEOUT}s; whether it works is unknown"
        elif [[ $frc -ne 0 ]]; then
            bad "$id" "--run-proofs: the paired proof '$arg' exited rc=$frc. A proof that cannot pass on this tree proves nothing: $(printf '%s' "$out" | grep -m1 -E '❌|FAIL' | head -c 200)"
        elif ! grep -qE '(^|[^A-Za-z])M[0-9]|[0-9]+[[:space:]]+(mutation|mutations|drift|drifts|caught|passed)' <<<"$out"; then
            bad "$id" "--run-proofs: the paired proof '$arg' exited 0 but reported no mutation results — it returned success without exercising anything (this is the exact defect SC-012 exists to catch)"
        else
            ok "$id" "--run-proofs: the paired proof RAN and reported mutation results: $(printf '%s' "$out" | grep -m1 -E '(^|[^A-Za-z])M[0-9]|[0-9]+[[:space:]]+(mutation|mutations|drift|drifts|caught|passed)|MUTATIONS? (CAUGHT|caught)' | sed 's/^[[:space:]]*//' | head -c 140)"
        fi
    fi
done

# ──────────────────────────────────────────────────────────────────────────────
# R4  registered DEBT — declared, counted, and ratcheted
# ──────────────────────────────────────────────────────────────────────────────
i=0
while [[ $i -lt ${#DEBT_ID[@]} ]]; do
    id="${DEBT_ID[$i]}"; entry="${DEBT_ENTRY[$i]}"; owed="${DEBT_OWED[$i]}"; reason="${DEBT_REASON[$i]}"
    abs="$ROOT/$entry"
    i=$((i+1))

    if [[ ! -f "$abs" ]]; then
        bad "$id" "debt row points at a file that does not exist: $entry"
        continue
    fi

    bad_owed=0
    IFS=',' read -ra owed_parts <<<"$owed"
    for o in "${owed_parts[@]}"; do
        case "${o// /}" in
            proof|three-valued|executable) ;;
            *) bad "$id" "unrecognised owed property '${o}' — the vocabulary is closed {proof,three-valued,executable}"; bad_owed=1 ;;
        esac
    done
    [[ $bad_owed -eq 1 ]] && continue

    # RATCHET. Debt may hide a gap; it must not be able to hide a fix.
    if [[ ",$owed," == *",proof,"* ]]; then
        found=""
        for f in --prove-failure --selftest --self-test --mutation-test; do
            is_case_arm "$abs" "$f" && { found="$f"; break; }
        done
        sib="${abs%.sh}_mutation_test.sh"
        [[ -z "$found" && -f "$sib" ]] && found="$(basename "$sib")"
        if [[ -n "$found" ]]; then
            bad "$id" "STALE DEBT — registered as owing a paired proof, but '$found' now exists in $entry. Promote it to a 'check' row; debt must not outlive the gap it declares"
            continue
        fi
    fi
    if [[ ",$owed," == *",executable,"* && -x "$abs" ]]; then
        bad "$id" "STALE DEBT — registered as owing the executable bit, but $entry is now mode $(_file_mode "$abs"). Promote it"
        continue
    fi

    debt "$id" "owes {${owed}} — $entry"
    [[ $QUIET -eq 1 ]] || printf '           %s\n' "$reason"
    if [[ $STRICT -eq 1 ]]; then
        bad "$id" "--strict: registered debt is a failure under strict mode"
    fi
done

# ──────────────────────────────────────────────────────────────────────────────
# R5  ANTI-DRIFT — the half without which the registry is decorative
# ──────────────────────────────────────────────────────────────────────────────
declare -A KNOWN=()
for p in "${CHK_ENTRY[@]}" "${DEBT_ENTRY[@]:-}" "${EXEMPT_PATHS[@]:-}"; do
    [[ -n "$p" ]] && KNOWN["$p"]=1
done

unregistered=()
for d in "${SCANROOTS[@]}"; do
    while IFS= read -r f; do
        [[ -n "$f" ]] || continue
        rel="${f#"$ROOT"/}"
        [[ -n "${KNOWN[$rel]:-}" ]] || unregistered+=("$rel")
    done < <(find "$ROOT/$d" -mindepth 1 -maxdepth 1 -type f -name '*.sh' 2>/dev/null | sort)
done

if [[ ${#unregistered[@]} -gt 0 ]]; then
    for u in "${unregistered[@]}"; do
        bad "R5" "UNREGISTERED — $u is under a declared scanroot but appears in no check, debt, or exempt row. Every check must be enumerated or SC-012/SC-013 cannot be quantified over it; add a row (or an 'exempt' row with a reason if it is not a check)"
    done
else
    ok "R5" "anti-drift: every *.sh under $(printf '%s ' "${SCANROOTS[@]}")is registered as a check, debt, or exemption"
fi

# ──────────────────────────────────────────────────────────────────────────────
# Verdict
# ──────────────────────────────────────────────────────────────────────────────
say "----------------------------------------------------------------------"
say "CM-CHECK-REGISTRY: ${N_PASS} PASS, ${N_FAIL} FAIL, ${N_DEBT} DEBT, ${N_UNDET} UNDET, ${N_NOTE} NOTE"

if [[ $N_UNDET -gt 0 && $N_FAIL -eq 0 ]]; then
    printf '%s◍ CM-CHECK-REGISTRY: COULD NOT DETERMINE%s — %s conformance question(s) could not be evaluated.\n' "$Y" "$N" "$N_UNDET"
    printf '   This is NOT a pass. Nothing here says the registry conforms (§11.4.6 / SC-013).\n'
    exit 2
fi
if [[ $N_FAIL -gt 0 ]]; then
    printf '%s❌ CM-CHECK-REGISTRY: FAIL%s — %s real conformance violation(s).\n' "$R" "$N" "$N_FAIL"
    [[ $N_UNDET -gt 0 ]] && printf '   (%s further question(s) were also undecidable and are NOT counted as passes.)\n' "$N_UNDET"
    exit 1
fi
if [[ $N_DEBT -gt 0 ]]; then
    printf '\n%s── REGISTERED DEBT (%s) — declared, not fixed; this is NOT compliance ──%s\n' "$Y" "$N_DEBT" "$N"
    printf '%s  Re-run with --strict to make it block. Debt is visible on every run by\n' "$Y"
    printf '  design: a quietly green tree carrying known gaps is itself the defect.%s\n' "$N"
fi
if [[ $RUN_PROOFS -eq 0 ]]; then
    printf '\n%sℹ Proof STRUCTURE was verified; no paired proof was EXECUTED. This run does\n' "$Y"
    printf '  not claim any proof was observed to work — run --run-proofs for that.%s\n' "$N"
fi
printf '%s✅ CM-CHECK-REGISTRY: PASS%s — every registered check has a paired proof and a demonstrated rc-2 state.\n' "$G" "$N"
exit 0
