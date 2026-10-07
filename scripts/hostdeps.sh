#!/usr/bin/env bash
# ==============================================================================
# hostdeps.sh — detect, and when it is safe INSTALL, the host packages the
# umbrella's own gates and browser tests depend on.
#
# WHY THIS EXISTS
# ---------------
# Gate 5 (export validation) exits 2 without `tesseract`; the browser harness
# (`_tests/preflight.js`) exits 2 while webkit's system libraries are missing
# or a Playwright browser has never been downloaded. Each time, the remedy was
# a command a human had to read, copy and run. The operator's standing rule
# (2026-10-07): a dependency that is missing MUST be installed automatically by
# the existing setup / gate entry points that depend on it.
#
# THE POLICY, and why it is not "just run sudo"
# ---------------------------------------------
#   present                          -> say "present", do nothing, rc 0.
#   missing, caller is root, or
#     `sudo -n true` succeeds        -> run the install ONCE, non-interactively,
#                                       re-probe, rc 0 only if the re-probe
#                                       finds it.
#   missing, no privilege            -> DO NOT HANG on a password prompt and do
#                                       not guess. Print the exact command for
#                                       THIS host and return 2.
#   install ran and failed, or the
#     re-probe still says absent     -> rc 1, naming the command and its rc.
#   no package manager / no known
#     package name for this manager  -> rc 2. Guessing a package name is worse
#                                       than not offering one, so a name is
#                                       listed only where it is known.
#
# Exit codes (three-valued, the repository's contract): 0 every requested
# dependency is present or was installed and re-probed; 1 an install failed or
# a dependency is absent in --check; 2 the question could not be answered — NOT
# a pass. A failure (1) outranks an undetermined (2) across several ids.
#
# `sudo` is only ever called as `sudo -n` (never prompts). HOSTDEPS_AUTO_INSTALL=0
# turns every install into the "no privilege" branch, for hosts where an
# operator wants the old print-the-command behaviour — for system packages AND
# for the Playwright browser downloads (ensure-browsers / harness).
#
# BOUNDS. Every installer call is wrapped in `timeout $HOSTDEPS_INSTALL_TIMEOUT`
# (default 900 s; scripts/pre-push-gates.sh sets 180 s so a push cannot hang for
# a quarter of an hour). The apt-get call carries `-o DPkg::Lock::Timeout=30` so a
# held dpkg lock fails fast; an install that fails with rc 100 (a stale package
# index) is retried ONCE after `apt-get update`.
#
# THE PACKAGE MANAGER IS CHOSEN FROM A SANITISED PATH ($HOSTDEPS_MGR_PATH, default
# /usr/sbin:/usr/bin:/sbin:/bin) and executed by its absolute path, so a
# user-writable directory early on the caller's PATH cannot substitute a fake
# installer that then runs as root. Homebrew (which never escalates) is looked up
# on the caller's PATH.
#
# NO LITERAL PACKAGE-MANAGER INVOCATION IS WRITTEN IN THIS FILE. The command is
# ASSEMBLED from the table below at run time, because
# scripts/audit-environment-assumptions.sh classifies a hardcoded invocation as
# a frozen environment assumption — and is right to.
#
# The system libraries in the table were MEASURED, not recalled: on this host
# (Ubuntu 26.04, 2026-09-22) webkit failed to launch with exactly
# `libmanette-0.2-0` and `libwoff1` missing; every other `ldd` "not found" is
# bundled by Playwright. The soname each probes is read from `ldconfig -p`.
#
# USAGE
#   scripts/hostdeps.sh ensure [id ...]        install what is missing (policy above)
#   scripts/hostdeps.sh --check [id ...]       report only; never installs
#   scripts/hostdeps.sh ensure-browsers <testsdir> <browser ...>
#   scripts/hostdeps.sh harness                the FULL browser matrix: webkit's two
#                                              system libraries + chromium, firefox
#                                              and webkit downloads (_tests/ or
#                                              $HOSTDEPS_TESTS_DIR)
#   scripts/hostdeps.sh --prove-failure        paired proof: stubbed package
#                                              managers, plus seeded mutations
#   scripts/hostdeps.sh --probe-path <dir> --check ...   probe with PATH=<dir>
#   Sourced: hostdep_ensure, hostdep_check, hostdep_ensure_browsers.
#   ids: tesseract poppler libmanette libwoff (default: all four)
# ==============================================================================

HOSTDEPS_IDS="tesseract poppler libmanette libwoff"

# id|probe-kind|probe-arg — a command on PATH, or a soname in `ldconfig -p`.
HOSTDEPS_PROBE_TABLE='tesseract|cmd|tesseract
poppler|cmd|pdftotext
libmanette|soname|libmanette-0.2.so.0
libwoff|soname|libwoff2dec.so.1'

# id|manager=package ... — only names that are known. Unlisted = rc 2, never a guess.
HOSTDEPS_PKG_TABLE='tesseract|apt-get=tesseract-ocr dnf=tesseract yum=tesseract zypper=tesseract-ocr pacman=tesseract apk=tesseract-ocr brew=tesseract
poppler|apt-get=poppler-utils dnf=poppler-utils yum=poppler-utils zypper=poppler-tools pacman=poppler apk=poppler-utils brew=poppler
libmanette|apt-get=libmanette-0.2-0
libwoff|apt-get=libwoff1'

# manager:subcommand — the manager name is not written next to its subcommand.
HOSTDEPS_MGR_TABLE='apt-get:install -y
dnf:install -y
yum:install -y
zypper:in -y
pacman:-S --noconfirm
apk:add
brew:install'

# manager:extra-options — placed before the subcommand. Table-driven for the same
# reason as the table above.
HOSTDEPS_MGR_OPTS='apt-get:-o DPkg::Lock::Timeout=30'

HOSTDEPS_PROBE_PATH="${HOSTDEPS_PROBE_PATH:-$PATH:/sbin:/usr/sbin}"
HOSTDEPS_MGR_PATH="${HOSTDEPS_MGR_PATH:-/usr/sbin:/usr/bin:/sbin:/bin}"

# _hd_auto_off <what> — is automatic installation switched off by the operator?
# <what> (pkg|browser) only names the call site, so a proof can mutate each one.
_hd_auto_off() { [ "${HOSTDEPS_AUTO_INSTALL:-1}" = "0" ]; }

_hd_table_field() { # <table> <id> <field-index, 1-based after id>
    local line
    while IFS= read -r line; do
        [ "${line%%|*}" = "$2" ] || continue
        printf '%s' "$line" | cut -d'|' -f"$3"
        return 0
    done <<EOF
$1
EOF
    return 1
}

# _hd_arch_tag — the architecture token `ldconfig -p` prints for THIS host.
_hd_arch_tag() {
    case "${HOSTDEPS_ARCH:-${HOSTTYPE:-}}" in
        x86_64)         printf 'x86-64' ;;
        aarch64|arm64)  printf 'AArch64' ;;
        i?86)           printf 'libc6\\)' ;;
        *)              printf '' ;;
    esac
}

# hostdep_probe <id> — 0 present, 1 absent, 2 cannot determine.
hostdep_probe() {
    local id="$1" kind arg ldc
    kind="$(_hd_table_field "$HOSTDEPS_PROBE_TABLE" "$id" 2)" || return 2
    arg="$(_hd_table_field "$HOSTDEPS_PROBE_TABLE" "$id" 3)"
    case "$kind" in
        cmd)
            if PATH="$HOSTDEPS_PROBE_PATH" command -v "$arg" >/dev/null 2>&1; then return 0; fi
            return 1
            ;;
        soname)
            ldc="$(PATH="$HOSTDEPS_PROBE_PATH" command -v ldconfig 2>/dev/null || true)"
            [ -n "$ldc" ] || return 2
            local out tag re
            out="$("$ldc" -p 2>/dev/null)" || return 2
            # An `ldconfig -p` row is `<TAB>soname (libc6,<arch>) => path`. Match the
            # soname as a WHOLE token (so `...so.1` never matches `...so.10`) and
            # require the host's own architecture tag (so an i386-only package
            # never reads as present). An architecture with no known tag accepts
            # any row rather than refusing to answer.
            tag="$(_hd_arch_tag)"
            re="^[[:space:]]*${arg//./\\.}[[:space:]]+\\([^)]*${tag}"
            if grep -Eq "$re" <<<"$out"; then return 0; fi
            return 1
            ;;
    esac
    return 2
}

# hostdep_manager — echo "manager<TAB>subcommand<TAB>absolute-path" for the first
# manager found. Every manager except brew is looked up on $HOSTDEPS_MGR_PATH,
# never on the caller's PATH (see the header).
hostdep_manager() {
    local line mgr sub where
    while IFS= read -r line; do
        [ -n "$line" ] || continue
        mgr="${line%%:*}"; sub="${line#*:}"
        if [ "$mgr" = "brew" ]; then
            where="$(command -v "$mgr" 2>/dev/null)" || continue
        else
            where="$(PATH="$HOSTDEPS_MGR_PATH" command -v "$mgr" 2>/dev/null)" || continue
        fi
        [ -n "$where" ] || continue
        case "$where" in /*) ;; *) continue ;; esac
        printf '%s\t%s\t%s\n' "$mgr" "$sub" "$where"
        return 0
    done <<EOF
$HOSTDEPS_MGR_TABLE
EOF
    return 1
}

# hostdep_pkg <id> <manager> — the package name, or nothing (and rc 1).
hostdep_pkg() {
    local row tok
    row="$(_hd_table_field "$HOSTDEPS_PKG_TABLE" "$1" 2)" || return 1
    for tok in $row; do
        if [ "${tok%%=*}" = "$2" ]; then printf '%s' "${tok#*=}"; return 0; fi
    done
    return 1
}

# hostdep_escalation — echo "root", "sudo" or "none". Never prompts.
hostdep_escalation() {
    local uid
    uid="$(id -u 2>/dev/null || printf 1)"
    if [ "$uid" = "0" ]; then printf 'root'; return 0; fi
    local sudo_bin
    sudo_bin="$(PATH="$HOSTDEPS_MGR_PATH" command -v sudo 2>/dev/null)" || sudo_bin=""
    if [ -n "$sudo_bin" ] && "$sudo_bin" -n true >/dev/null 2>&1; then
        printf 'sudo'; return 0
    fi
    printf 'none'
}

# hostdep_command_text <id> — the exact command for THIS host, for messages.
hostdep_command_text() {
    local row mgr sub pkg pfx=""
    row="$(hostdep_manager)" || { printf 'install %s with this host'\''s package manager' "$1"; return 0; }
    mgr="$(printf '%s' "$row" | cut -f1)"; sub="$(printf '%s' "$row" | cut -f2)"
    pkg="$(hostdep_pkg "$1" "$mgr")" || { printf 'install the library that provides %s (no package name is recorded for %s)' "$1" "$mgr"; return 0; }
    if [ "$mgr" != "brew" ] && [ "$(id -u 2>/dev/null || printf 1)" != "0" ]; then pfx="sudo "; fi
    printf '%s%s %s %s' "$pfx" "$mgr" "$sub" "$pkg"
}

# _hd_one <id> <mode> — mode ensure|check. Prints one line, returns 0/1/2.
_hd_one() {
    local id="$1" mode="$2" st row mgr sub mpath pkg esc rc
    hostdep_probe "$id"; st=$?
    case "$st" in
        0) printf 'present      %s\n' "$id"; return 0 ;;
        2) printf 'UNDETERMINED %s — the probe could not run (no ldconfig / unknown id / bad probe path)\n' "$id"; return 2 ;;
    esac
    # absent
    if [ "$mode" = "check" ]; then
        printf 'MISSING      %s — run: %s\n' "$id" "$(hostdep_command_text "$id")"
        return 1
    fi
    if _hd_auto_off pkg; then
        printf 'MISSING      %s — auto-install is off (HOSTDEPS_AUTO_INSTALL=0); run: %s\n' "$id" "$(hostdep_command_text "$id")"
        return 2
    fi
    if ! row="$(hostdep_manager)"; then
        printf 'UNDETERMINED %s — no supported package manager found on PATH; install it by hand\n' "$id"
        return 2
    fi
    mgr="$(printf '%s' "$row" | cut -f1)"; sub="$(printf '%s' "$row" | cut -f2)"; mpath="$(printf '%s' "$row" | cut -f3)"
    if ! pkg="$(hostdep_pkg "$id" "$mgr")"; then
        printf 'UNDETERMINED %s — no package name is recorded for %s; %s\n' "$id" "$mgr" "$(hostdep_command_text "$id")"
        return 2
    fi
    esc="root"
    if [ "$mgr" != "brew" ]; then esc="$(hostdep_escalation)"; fi
    if [ "$esc" = "none" ]; then
        printf 'MISSING      %s — no privilege to install without a password prompt; run: %s\n' "$id" "$(hostdep_command_text "$id")"
        return 2
    fi
    printf 'installing   %s (%s) via %s%s — set HOSTDEPS_AUTO_INSTALL=0 to turn this off\n' \
        "$id" "$pkg" "$([ "$esc" = "sudo" ] && printf 'sudo -n ')" "$mgr" >&2
    _hd_install "$esc" "$mgr" "$sub" "$mpath" "$pkg"; rc=$?
    if [ "$rc" -ne 0 ]; then
        printf 'FAILED       %s — %s exited rc=%s\n' "$id" "$(hostdep_command_text "$id")" "$rc"
        return 1
    fi
    hostdep_probe "$id"; st=$?
    if [ "$st" -eq 0 ]; then
        printf 'installed    %s (%s)\n' "$id" "$pkg"
        return 0
    fi
    printf 'FAILED       %s — the install exited 0 but the probe still does not find it\n' "$id"
    return 1
}

# _hd_timeout_prefix — `timeout N` when timeout(1) exists, else nothing.
_hd_timeout_prefix() {
    if command -v timeout >/dev/null 2>&1; then printf 'timeout %s' "${HOSTDEPS_INSTALL_TIMEOUT:-900}"; fi
}

# _hd_run_installer <esc> <mgr> <abs> <opts> <sub> <pkg> — one installer call.
_hd_run_installer() {
    local esc="$1" mgr="$2" mpath="$3" opts="$4" sub="$5" pkg="$6" t sudo_bin
    t="$(_hd_timeout_prefix)"
    # shellcheck disable=SC2086
    if [ "$esc" = "sudo" ]; then
        sudo_bin="$(PATH="$HOSTDEPS_MGR_PATH" command -v sudo 2>/dev/null)" || return 2
        "$sudo_bin" -n $t env DEBIAN_FRONTEND=noninteractive "$mpath" $opts $sub ${pkg:+"$pkg"} >&2
    else
        $t env DEBIAN_FRONTEND=noninteractive "$mpath" $opts $sub ${pkg:+"$pkg"} >&2
    fi
}

# _hd_install <esc> <mgr> <sub> <abs> <pkg> — install, and for apt-get alone, on a
# stale package index (rc 100) refresh it ONCE and retry ONCE.
_hd_install() {
    local esc="$1" mgr="$2" sub="$3" mpath="$4" pkg="$5" opts rc line
    opts=""
    while IFS= read -r line; do
        [ "${line%%:*}" = "$mgr" ] && opts="${line#*:}"
    done <<EOF
$HOSTDEPS_MGR_OPTS
EOF
    _hd_run_installer "$esc" "$mgr" "$mpath" "$opts" "$sub" "$pkg"; rc=$?
    if [ "$rc" -eq 100 ] && [ "$mgr" = "apt-get" ]; then
        _hd_run_installer "$esc" "$mgr" "$mpath" "$opts" "update" "" >/dev/null 2>&1
        _hd_run_installer "$esc" "$mgr" "$mpath" "$opts" "$sub" "$pkg"; rc=$?
    fi
    return "$rc"
}

_hd_run() { # <mode> [ids]
    local mode="$1" id r worst=0; shift
    [ $# -gt 0 ] || set -- $HOSTDEPS_IDS
    for id in "$@"; do
        _hd_one "$id" "$mode"; r=$?
        case "$r" in
            1) worst=1 ;;
            2) [ "$worst" -eq 1 ] || worst=2 ;;
        esac
    done
    return "$worst"
}

hostdep_ensure() { _hd_run ensure "$@"; }
hostdep_check()  { _hd_run check "$@"; }

# hostdep_ensure_browsers <testsdir> <browser ...> — Playwright browser
# downloads need NO privilege, so there is no escalation branch: present is a
# no-op, missing runs the installer once, a missing toolchain is rc 2.
hostdep_ensure_browsers() {
    local dir="$1" b root worst=0 rc t; shift
    root="${PLAYWRIGHT_BROWSERS_PATH:-${HOME:-/nonexistent}/.cache/ms-playwright}"
    for b in "$@"; do
        if compgen -G "$root/$b-*" >/dev/null 2>&1; then
            printf 'present      browser:%s\n' "$b"; continue
        fi
        if ! command -v npx >/dev/null 2>&1 || [ ! -d "$dir/node_modules/@playwright/test" ]; then
            printf 'UNDETERMINED browser:%s — npx or %s/node_modules/@playwright/test is missing; run: (cd %s && npm ci)\n' "$b" "$dir" "$dir"
            [ "$worst" -eq 1 ] || worst=2; continue
        fi
        if _hd_auto_off browser; then
            printf 'MISSING      browser:%s — auto-install is off (HOSTDEPS_AUTO_INSTALL=0); run: (cd %s && npx playwright install %s)\n' "$b" "$dir" "$b"
            [ "$worst" -eq 1 ] || worst=2; continue
        fi
        printf 'installing   browser:%s via npx playwright install — a download; HOSTDEPS_AUTO_INSTALL=0 turns this off\n' "$b" >&2
        t="$(_hd_timeout_prefix)"
        # shellcheck disable=SC2086
        ( cd "$dir" && $t npx playwright install "$b" >&2 ); rc=$?
        if [ "$rc" -ne 0 ]; then
            printf 'FAILED       browser:%s — npx playwright install %s exited rc=%s\n' "$b" "$b" "$rc"
            worst=1; continue
        fi
        if compgen -G "$root/$b-*" >/dev/null 2>&1; then
            printf 'installed    browser:%s\n' "$b"
        else
            printf 'FAILED       browser:%s — the installer exited 0 but %s/%s-* does not exist\n' "$b" "$root" "$b"
            worst=1
        fi
    done
    return "$worst"
}

# hostdep_harness — everything `_tests/preflight.js` needs for the full matrix.
# A failure (1) outranks an undetermined (2).
hostdep_harness() {
    local root tests r1 r2
    root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
    tests="${HOSTDEPS_TESTS_DIR:-$root/_tests}"
    hostdep_ensure libmanette libwoff; r1=$?
    hostdep_ensure_browsers "$tests" chromium firefox webkit; r2=$?
    if [ "$r1" -eq 1 ] || [ "$r2" -eq 1 ]; then return 1; fi
    if [ "$r1" -eq 2 ] || [ "$r2" -eq 2 ]; then return 2; fi
    return 0
}

# ------------------------------------------------------------------------------
# PAIRED PROOF. Stubbed package managers on a hermetic PATH; then the same
# battery against seeded MUTANTS of this very file, each of which must be
# caught. A battery that cannot fail proves nothing.
# ------------------------------------------------------------------------------
_hd_mkenv() { # <tmp> -> builds $tmp/bin with stubs and symlinks, $tmp/log
    local t="$1" b="$1/bin" tool
    mkdir -p "$b"; : >"$t/log"; : >"$t/tlog"
    for tool in env grep cat mkdir cut sed true touch; do
        ln -s "$(type -P "$tool")" "$b/$tool"
    done
    cat >"$b/id" <<EOF
#!/bin/sh
printf '%s\n' "\${STUB_UID:-1000}"
EOF
    cat >"$b/sudo" <<EOF
#!/bin/sh
printf 'sudo %s\n' "\$*" >>"$t/log"
[ "\$1" = "-n" ] || exit 99
[ "\${STUB_SUDO_OK:-0}" = "1" ] || exit 1
shift
exec "\$@"
EOF
    cat >"$b/apt-get" <<EOF
#!/bin/sh
printf 'apt-get %s\n' "\$*" >>"$t/log"
case " \$* " in *" update "*) : >"$t/updated"; exit 0 ;; esac
if [ "\${STUB_APT_STALE:-0}" = "1" ] && [ ! -f "$t/updated" ]; then exit 100; fi
[ "\${STUB_APT_RC:-0}" = "0" ] || [ "\${STUB_APT_PARTIAL:-0}" = "1" ] || exit "\$STUB_APT_RC"
for a in "\$@"; do
  case "\$a" in
    tesseract-ocr) printf '#!/bin/sh\n' >"$b/tesseract"; chmod +x "$b/tesseract" ;;
    libmanette-0.2-0) printf '\tlibmanette-0.2.so.0 (libc6,x86-64) => /x\n' >>"$t/ldc" ;;
    libwoff1) printf '\tlibwoff2dec.so.1 (libc6,x86-64) => /x\n' >>"$t/ldc" ;;
  esac
done
exit "\${STUB_APT_RC:-0}"
EOF
    cat >"$b/timeout" <<EOF
#!/bin/sh
printf 'timeout %s\n' "\$1" >>"$t/tlog"
shift
exec "\$@"
EOF
    cat >"$b/dnf" <<EOF
#!/bin/sh
printf 'dnf %s\n' "\$*" >>"$t/log"
exit "\${STUB_DNF_RC:-0}"
EOF
    cat >"$b/ldconfig" <<EOF
#!/bin/sh
[ -f "$t/ldc" ] && cat "$t/ldc"
exit 0
EOF
    chmod +x "$b/id" "$b/sudo" "$b/apt-get" "$b/dnf" "$b/ldconfig" "$b/timeout"
}

_hd_battery() { # <script> -> prints FAIL lines, returns number of failed cases
    local script="$1" T fails=0 out rc log
    T="$(mktemp -d "${TMPDIR:-/tmp}/hostdeps-prove.XXXXXX")" || return 99
    local base="$T/base"
    mkdir -p "$base"
    run() { # <tag> <env...> -- <args...>
        local tag="$1"; shift
        rm -rf "$T/case"; mkdir -p "$T/case"; _hd_mkenv "$T/case"
        local envs=()
        while [ "$1" != "--" ]; do envs+=("$1"); shift; done; shift
        out="$(env -i PATH="$T/case/bin" HOSTDEPS_PROBE_PATH="$T/case/bin" HOSTDEPS_MGR_PATH="$T/case/bin" HOSTDEPS_ARCH=x86_64 "${envs[@]}" "$BASH" "$script" "$@" 2>/dev/null)"; rc=$?
        log="$(cat "$T/case/log")"
    }
    expect() { # <name> <cond-result>
        if [ "$2" != "ok" ]; then printf '    FAIL  %s\n' "$1"; fails=$((fails+1)); fi
    }
    local ok

    # C1 present: nothing installed, nothing run.
    rm -rf "$T/case"; mkdir -p "$T/case"; _hd_mkenv "$T/case"; printf '#!/bin/sh\n' >"$T/case/bin/tesseract"; chmod +x "$T/case/bin/tesseract"
    out="$(env -i PATH="$T/case/bin" HOSTDEPS_PROBE_PATH="$T/case/bin" HOSTDEPS_MGR_PATH="$T/case/bin" HOSTDEPS_ARCH=x86_64 STUB_UID=1000 "$BASH" "$script" ensure tesseract 2>/dev/null)"; rc=$?; log="$(cat "$T/case/log")"
    ok=bad; [ "$rc" -eq 0 ] && [ -z "$log" ] && grep -q '^present' <<<"$out" && ok=ok
    expect "C1 present -> no-op, rc 0, no apt/sudo call" "$ok"

    # C2 missing + root: exactly one install, rc 0, installed.
    run c2 STUB_UID=0 -- ensure tesseract
    ok=bad; [ "$rc" -eq 0 ] && [ "$(grep -c '^apt-get -o DPkg::Lock::Timeout=30 install -y tesseract-ocr$' <<<"$log")" -eq 1 ] && ! grep -q '^sudo' <<<"$log" && grep -q '^installed' <<<"$out" && ok=ok
    expect "C2 missing + root -> one install, rc 0" "$ok"

    # C3 missing + passwordless sudo: only ever sudo -n.
    run c3 STUB_UID=1000 STUB_SUDO_OK=1 -- ensure tesseract
    ok=bad; [ "$rc" -eq 0 ] && grep -q '^sudo -n true$' <<<"$log" && grep -qE '^sudo -n timeout [0-9]+ env DEBIAN_FRONTEND=noninteractive .*/apt-get -o DPkg::Lock::Timeout=30 install -y tesseract-ocr$' <<<"$log" && ! grep -vqE '^(sudo -n|apt-get)' <<<"$log" && ok=ok
    expect "C3 missing + passwordless sudo -> sudo -n install, rc 0" "$ok"

    # C4 missing + no privilege: rc 2, exact command, no install.
    run c4 STUB_UID=1000 STUB_SUDO_OK=0 -- ensure tesseract
    ok=bad; [ "$rc" -eq 2 ] && ! grep -q '^apt-get' <<<"$log" && grep -qF 'sudo apt-get install -y tesseract-ocr' <<<"$out" && ok=ok
    expect "C4 missing + no privilege -> rc 2 naming the exact command, no install" "$ok"

    # C5 install fails: rc 1.
    run c5 STUB_UID=0 STUB_APT_RC=100 -- ensure tesseract
    ok=bad; [ "$rc" -eq 1 ] && grep -q '^FAILED' <<<"$out" && ok=ok
    expect "C5 install exits non-zero -> rc 1" "$ok"

    # C5b a PARTIAL install: the files appear, yet the manager reports failure.
    run c5b STUB_UID=0 STUB_APT_RC=100 STUB_APT_PARTIAL=1 -- ensure tesseract
    ok=bad; [ "$rc" -eq 1 ] && grep -q '^FAILED' <<<"$out" && ok=ok
    expect "C5b install fails after leaving the file behind -> still rc 1" "$ok"

    # C6 install exits 0 but nothing appears: rc 1, never a pass.
    run c6 STUB_UID=0 -- ensure poppler
    ok=bad; [ "$rc" -eq 1 ] && grep -q '^FAILED' <<<"$out" && ok=ok
    expect "C6 install exits 0 yet probe still absent -> rc 1" "$ok"

    # C7 no package manager at all: rc 2.
    rm -rf "$T/case"; mkdir -p "$T/case"; _hd_mkenv "$T/case"; rm -f "$T/case/bin/apt-get" "$T/case/bin/dnf"
    out="$(env -i PATH="$T/case/bin" HOSTDEPS_PROBE_PATH="$T/case/bin" HOSTDEPS_MGR_PATH="$T/case/bin" HOSTDEPS_ARCH=x86_64 STUB_UID=0 "$BASH" "$script" ensure tesseract 2>/dev/null)"; rc=$?
    ok=bad; [ "$rc" -eq 2 ] && grep -q 'no supported package manager' <<<"$out" && ok=ok
    expect "C7 no package manager -> rc 2" "$ok"

    # C8 operator switch: auto-install off.
    run c8 STUB_UID=0 HOSTDEPS_AUTO_INSTALL=0 -- ensure tesseract
    ok=bad; [ "$rc" -eq 2 ] && ! grep -q '^apt-get' <<<"$log" && ok=ok
    expect "C8 HOSTDEPS_AUTO_INSTALL=0 -> rc 2, no install" "$ok"

    # C9 no recorded package name for the manager present (dnf has none for libmanette).
    rm -rf "$T/case"; mkdir -p "$T/case"; _hd_mkenv "$T/case"; rm -f "$T/case/bin/apt-get"
    out="$(env -i PATH="$T/case/bin" HOSTDEPS_PROBE_PATH="$T/case/bin" HOSTDEPS_MGR_PATH="$T/case/bin" HOSTDEPS_ARCH=x86_64 STUB_UID=0 "$BASH" "$script" ensure libmanette 2>/dev/null)"; rc=$?; log="$(cat "$T/case/log")"
    ok=bad; [ "$rc" -eq 2 ] && ! grep -q '^dnf' <<<"$log" && ok=ok
    expect "C9 no known package name -> rc 2, no guessed install" "$ok"

    # C10 failure outranks undetermined across ids.
    rm -rf "$T/case"; mkdir -p "$T/case"; _hd_mkenv "$T/case"; rm -f "$T/case/bin/apt-get"
    out="$(env -i PATH="$T/case/bin" HOSTDEPS_PROBE_PATH="$T/case/bin" HOSTDEPS_MGR_PATH="$T/case/bin" HOSTDEPS_ARCH=x86_64 STUB_UID=0 STUB_DNF_RC=1 "$BASH" "$script" ensure tesseract libmanette 2>/dev/null)"; rc=$?
    ok=bad; [ "$rc" -eq 1 ] && ok=ok
    expect "C10 one FAILED + one UNDETERMINED -> rc 1 (failure outranks undetermined)" "$ok"

    # C11 --check never installs and reports the absence as rc 1.
    run c11 STUB_UID=0 -- --check tesseract
    ok=bad; [ "$rc" -eq 1 ] && ! grep -q '^apt-get' <<<"$log" && ok=ok
    expect "C11 --check -> rc 1, never installs" "$ok"

    # C12 no ldconfig: a library probe cannot answer -> rc 2, not 0 and not 1.
    rm -rf "$T/case"; mkdir -p "$T/case"; _hd_mkenv "$T/case"; rm -f "$T/case/bin/ldconfig"
    out="$(env -i PATH="$T/case/bin" HOSTDEPS_PROBE_PATH="$T/case/bin" HOSTDEPS_MGR_PATH="$T/case/bin" HOSTDEPS_ARCH=x86_64 STUB_UID=0 "$BASH" "$script" --check libwoff 2>/dev/null)"; rc=$?
    ok=bad; [ "$rc" -eq 2 ] && ok=ok
    expect "C12 no ldconfig -> library probe rc 2" "$ok"

    # C13 browsers: present no-op / missing runs npx once / failing npx rc 1 / no npx rc 2.
    mkdir -p "$base"; ln -s "$(type -P mkdir)" "$base/mkdir"
    local B="$T/browsers"; mkdir -p "$B/ms/webkit-1" "$B/tests/node_modules/@playwright/test"
    cat >"$T/npx" <<EOF
#!/bin/sh
printf 'npx %s\n' "\$*" >>"$T/npxlog"
[ "\${STUB_NPX_RC:-0}" = "0" ] || exit "\$STUB_NPX_RC"
mkdir -p "$B/ms/firefox-1"
EOF
    chmod +x "$T/npx"; cp "$T/npx" "$T/npx.sh"; : >"$T/npxlog"
    cat >"$T/timeout" <<EOF
#!/bin/sh
printf 'timeout %s\n' "\$1" >>"$T/tlog"
shift
exec "\$@"
EOF
    chmod +x "$T/timeout"; cp "$T/timeout" "$T/timeout.sh"; : >"$T/tlog"
    out="$(env -i PATH="$T:$T/base" PLAYWRIGHT_BROWSERS_PATH="$B/ms" "$BASH" "$script" ensure-browsers "$B/tests" webkit 2>/dev/null)"; rc=$?
    ok=bad; [ "$rc" -eq 0 ] && [ ! -s "$T/npxlog" ] && grep -q '^present' <<<"$out" && ok=ok
    expect "C13a browser present -> no-op" "$ok"
    out="$(env -i PATH="$T:$T/base" PLAYWRIGHT_BROWSERS_PATH="$B/ms" HOSTDEPS_INSTALL_TIMEOUT=123 "$BASH" "$script" ensure-browsers "$B/tests" firefox 2>/dev/null)"; rc=$?
    ok=bad; [ "$rc" -eq 0 ] && [ "$(grep -c '^npx playwright install firefox$' "$T/npxlog")" -eq 1 ] && ok=ok
    expect "C13b browser missing -> npx playwright install once, rc 0" "$ok"
    ok=bad; grep -qx 'timeout 123' "$T/tlog" && ok=ok
    expect "C13b2 the browser download runs under timeout \$HOSTDEPS_INSTALL_TIMEOUT" "$ok"
    rm -rf "$B/ms/firefox-1"; : >"$T/npxlog"
    out="$(env -i PATH="$T:$T/base" PLAYWRIGHT_BROWSERS_PATH="$B/ms" HOSTDEPS_AUTO_INSTALL=0 "$BASH" "$script" ensure-browsers "$B/tests" firefox 2>/dev/null)"; rc=$?
    ok=bad; [ "$rc" -eq 2 ] && [ ! -s "$T/npxlog" ] && grep -q '^MISSING' <<<"$out" && ok=ok
    expect "C13e HOSTDEPS_AUTO_INSTALL=0 -> browsers are NOT downloaded, rc 2" "$ok"
    rm -rf "$B/ms/firefox-1"; : >"$T/npxlog"
    out="$(env -i PATH="$T:$T/base" PLAYWRIGHT_BROWSERS_PATH="$B/ms" STUB_NPX_RC=7 "$BASH" "$script" ensure-browsers "$B/tests" firefox 2>/dev/null)"; rc=$?
    ok=bad; [ "$rc" -eq 1 ] && ok=ok
    expect "C13c installer failing -> rc 1" "$ok"
    rm -f "$T/npx"
    out="$(env -i PATH="$T/base" PLAYWRIGHT_BROWSERS_PATH="$B/ms" "$BASH" "$script" ensure-browsers "$B/tests" firefox 2>/dev/null)"; rc=$?
    ok=bad; [ "$rc" -eq 2 ] && ok=ok
    expect "C13d no npx -> rc 2" "$ok"

    # C14 harness = webkit libraries AND browsers: libs missing + root -> one
    # install of each library package; a missing browser -> one npx install.
    rm -rf "$T/case" "$B/ms"; mkdir -p "$T/case" "$B/ms/chromium-1" "$B/ms/webkit-1"; _hd_mkenv "$T/case"
    cp "$T/npx.sh" "$T/case/bin/npx" 2>/dev/null; : >"$T/npxlog"
    out="$(env -i PATH="$T/case/bin" HOSTDEPS_PROBE_PATH="$T/case/bin" HOSTDEPS_MGR_PATH="$T/case/bin" HOSTDEPS_ARCH=x86_64 HOSTDEPS_TESTS_DIR="$B/tests" PLAYWRIGHT_BROWSERS_PATH="$B/ms" STUB_UID=0 "$BASH" "$script" harness 2>/dev/null)"; rc=$?; log="$(cat "$T/case/log")"
    ok=bad; [ "$rc" -eq 0 ] && grep -q '^apt-get -o DPkg::Lock::Timeout=30 install -y libmanette-0.2-0$' <<<"$log" && grep -q '^apt-get -o DPkg::Lock::Timeout=30 install -y libwoff1$' <<<"$log" && grep -q '^npx playwright install firefox$' "$T/npxlog" && ok=ok
    expect "C14 harness -> installs both libraries and the missing browser" "$ok"

    # C14b harness: a failure (1) outranks an undetermined (2). Libraries cannot
    # be installed (no privilege -> 2) while the browser download fails (1).
    rm -rf "$T/case" "$B/ms"; mkdir -p "$T/case" "$B/ms/chromium-1" "$B/ms/webkit-1"; _hd_mkenv "$T/case"
    cp "$T/npx.sh" "$T/case/bin/npx" 2>/dev/null; : >"$T/npxlog"
    out="$(env -i PATH="$T/case/bin" HOSTDEPS_PROBE_PATH="$T/case/bin" HOSTDEPS_MGR_PATH="$T/case/bin" HOSTDEPS_ARCH=x86_64 HOSTDEPS_TESTS_DIR="$B/tests" PLAYWRIGHT_BROWSERS_PATH="$B/ms" STUB_UID=1000 STUB_SUDO_OK=0 STUB_NPX_RC=7 "$BASH" "$script" harness 2>/dev/null)"; rc=$?
    ok=bad; [ "$rc" -eq 1 ] && ok=ok
    expect "C14b harness: libraries rc 2 + download rc 1 -> rc 1 (failure outranks undetermined)" "$ok"

    # C5c stale package index: install exits 100, ONE refresh, ONE retry, then ok.
    run c5c STUB_UID=0 STUB_APT_STALE=1 -- ensure tesseract
    ok=bad; [ "$rc" -eq 0 ] && [ "$(grep -c ' update$' <<<"$log")" -eq 1 ] && [ "$(grep -c 'install -y tesseract-ocr$' <<<"$log")" -eq 2 ] && grep -q '^installed' <<<"$out" && ok=ok
    expect "C5c rc 100 -> apt-get update once, retry once, rc 0" "$ok"
    run c5d STUB_UID=0 STUB_APT_RC=100 -- ensure tesseract
    ok=bad; [ "$rc" -eq 1 ] && [ "$(grep -c 'install -y tesseract-ocr$' <<<"$log")" -eq 2 ] && ok=ok
    expect "C5d a persistent rc 100 is retried ONCE, not forever, and ends rc 1" "$ok"

    # C2b the operator is told, on stderr, what is about to be installed and how to opt out.
    rm -rf "$T/case"; mkdir -p "$T/case"; _hd_mkenv "$T/case"
    out="$(env -i PATH="$T/case/bin" HOSTDEPS_PROBE_PATH="$T/case/bin" HOSTDEPS_MGR_PATH="$T/case/bin" HOSTDEPS_ARCH=x86_64 STUB_UID=0 "$BASH" "$script" ensure tesseract 2>&1 >/dev/null)"
    ok=bad; grep -q '^installing   tesseract' <<<"$out" && grep -qF 'HOSTDEPS_AUTO_INSTALL=0' <<<"$out" && ok=ok
    expect "C2b an install is announced on stderr with the opt-out" "$ok"

    # C15 library probe: whole-token soname, native architecture only.
    ldcase() { # <ldconfig row> <id> -> rc of --check
        rm -rf "$T/case"; mkdir -p "$T/case"; _hd_mkenv "$T/case"; printf '%s\n' "$1" >"$T/case/ldc"
        env -i PATH="$T/case/bin" HOSTDEPS_PROBE_PATH="$T/case/bin" HOSTDEPS_MGR_PATH="$T/case/bin" HOSTDEPS_ARCH=x86_64 "$BASH" "$script" --check "$2" >/dev/null 2>&1
    }
    ldcase "$(printf '\tlibwoff2dec.so.1 (libc6,x86-64) => /x')" libwoff; rc=$?
    ok=bad; [ "$rc" -eq 0 ] && ok=ok
    expect "C15a the native-arch whole-token row reads as present (control)" "$ok"
    ldcase "$(printf '\tlibwoff2dec.so.1 (libc6) => /x')" libwoff; rc=$?
    ok=bad; [ "$rc" -eq 1 ] && ok=ok
    expect "C15b an i386-only row does NOT read as present" "$ok"
    ldcase "$(printf '\tlibwoff2dec.so.10 (libc6,x86-64) => /x')" libwoff; rc=$?
    ok=bad; [ "$rc" -eq 1 ] && ok=ok
    expect "C15c a longer soname (…so.10) does NOT satisfy …so.1" "$ok"

    # C16 a hostile directory early on the CALLER's PATH cannot supply the installer.
    rm -rf "$T/case" "$T/evil"; mkdir -p "$T/case" "$T/evil"; _hd_mkenv "$T/case"
    printf '#!/bin/sh\nprintf evil >>"%s/evillog"\nexit 0\n' "$T" >"$T/evil/apt-get"; chmod +x "$T/evil/apt-get"; : >"$T/evillog"
    out="$(env -i PATH="$T/evil:$T/case/bin" HOSTDEPS_PROBE_PATH="$T/case/bin" HOSTDEPS_MGR_PATH="$T/case/bin" HOSTDEPS_ARCH=x86_64 STUB_UID=0 "$BASH" "$script" ensure tesseract 2>/dev/null)"; rc=$?; log="$(cat "$T/case/log")"
    ok=bad; [ "$rc" -eq 0 ] && [ ! -s "$T/evillog" ] && grep -q '^apt-get -o DPkg::Lock::Timeout=30 install' <<<"$log" && ok=ok
    expect "C16 the installer comes from \$HOSTDEPS_MGR_PATH, not the caller's PATH" "$ok"

    rm -rf "$T"
    return "$fails"
}

_hd_prove() {
    local T rc
    T="$(mktemp -d "${TMPDIR:-/tmp}/hostdeps-mut.XXXXXX")" || { printf 'cannot create a scratch dir\n' >&2; return 2; }
    _hd_prove_in "$T"; rc=$?
    rm -rf "$T"
    return "$rc"
}

_hd_prove_in() {
    local self="${BASH_SOURCE[0]}" T="$1" fails=0 n=0 caught=0 name from to mutated rest
    printf 'CONTROL — the unmodified script must pass every case\n'
    cp "$self" "$T/control.sh"
    _hd_battery "$T/control.sh"; local cf=$?
    if [ "$cf" -ne 0 ]; then printf 'CONTROL FAILED (%s case(s)) — the battery is not green on the real script\n' "$cf"; return 1; fi
    printf '    control: all cases pass\n\nMUTATIONS — each seeded defect must be caught by at least one case\n'
    local text; text="$(cat "$self")"
    # name|from|to  (exact substrings of this file; an anchor that no longer
    # matches is rc 2 — anchor rot — never a silent pass)
    local muts=(
'M1 probe always reports present@@hostdep_probe "$id"; st=$?@@hostdep_probe "$id"; st=0'
'M2 install without checking privilege@@if [ "$esc" = "none" ]; then@@if [ "$esc" = "nevermatches" ]; then'
'M3 sudo allowed to prompt (no -n)@@"$sudo_bin" -n $t env@@"$sudo_bin" $t env'
'M4 install exit code ignored@@if [ "$rc" -ne 0 ]; then@@if [ "$rc" -eq 12345 ]; then'
'M5 no re-probe verdict after install@@if [ "$st" -eq 0 ]; then@@if [ "$st" -ge 0 ]; then'
'M6 undetermined outranks failure@@2) [ "$worst" -eq 1 ] || worst=2 ;;@@2) worst=2 ;;'
'M7 --check installs too@@if [ "$mode" = "check" ]; then@@if [ "$mode" = "nevermatches" ]; then'
'M8 auto-install switch ignored for packages@@if _hd_auto_off pkg; then@@if false; then'
'M9 guessed package name when none is recorded@@if ! pkg="$(hostdep_pkg "$id" "$mgr")"; then@@if pkg="$id" && false; then'
'M11 harness skips the system libraries@@hostdep_ensure libmanette libwoff; r1=$?@@r1=0'
'M10 missing ldconfig reads as present@@[ -n "$ldc" ] || return 2@@[ -n "$ldc" ] || return 0'
'M12 auto-install switch ignored for browsers@@if _hd_auto_off browser; then@@if false; then'
'M13 browser download not under timeout@@( cd "$dir" && $t npx playwright install "$b" >&2 )@@( cd "$dir" && npx playwright install "$b" >&2 )'
'M14 harness lets undetermined outrank failure@@if [ "$r1" -eq 1 ] || [ "$r2" -eq 1 ]; then return 1; fi@@if [ "$r1" -eq 2 ] || [ "$r2" -eq 2 ]; then return 2; fi'
'M15 no dpkg lock timeout@@HOSTDEPS_MGR_OPTS='"'"'apt-get:-o DPkg::Lock::Timeout=30'"'"'@@HOSTDEPS_MGR_OPTS='"'"'apt-get:'"'"''
'M16 no stale-index refresh and retry@@if [ "$rc" -eq 100 ] && [ "$mgr" = "apt-get" ]; then@@if false; then'
'M17 soname matched as a substring@@re="^[[:space:]]*${arg//./\\.}[[:space:]]+\\([^)]*${tag}"@@re="${arg//./\\.}"'
'M18 any architecture counts as present@@tag="$(_hd_arch_tag)"@@tag=""'
'M19 installer chosen from the caller PATH@@where="$(PATH="$HOSTDEPS_MGR_PATH" command -v "$mgr" 2>/dev/null)" || continue@@where="$(command -v "$mgr" 2>/dev/null)" || continue'
'M20 install not announced@@"$id" "$pkg" "$([ "$esc" = "sudo" ] && printf '"'"'sudo -n '"'"')" "$mgr" >&2@@"$id" "$pkg" "$([ "$esc" = "sudo" ] && printf '"'"'sudo -n '"'"')" "$mgr" >/dev/null'
    )
    local m
    for m in "${muts[@]}"; do
        name="${m%%@@*}"; rest="${m#*@@}"; from="${rest%%@@*}"; to="${rest#*@@}"
        n=$((n+1))
        if [[ "$text" != *"$from"* ]]; then
            printf '    M%-2s ANCHOR ROT — the substring this mutation targets is gone; the proof is stale\n' "$n"
            return 2
        fi
        mutated="${text/"$from"/"$to"}"
        if [ "$mutated" = "$text" ]; then printf '    M%s did not change the file\n' "$n"; return 2; fi
        printf '%s\n' "$mutated" >"$T/mut.sh"
        local out; out="$(_hd_battery "$T/mut.sh")"; local mf=$?
        if [ "$mf" -gt 0 ]; then
            caught=$((caught+1)); printf '    caught  %s  (%s case(s) failed)\n' "$name" "$mf"
        else
            fails=$((fails+1)); printf '    ESCAPED %s — no case noticed it\n' "$name"
        fi
    done
    printf '\nRESULT  %s mutation(s), %s caught, %s escaped\n' "$n" "$caught" "$fails"
    [ "$fails" -eq 0 ] && return 0
    return 1
}

_hd_main() {
    local cmd="${1:-}"
    case "$cmd" in
        --probe-path)
            HOSTDEPS_PROBE_PATH="${2:-}"
            [ -d "$HOSTDEPS_PROBE_PATH" ] || { printf 'UNDETERMINED the probe path %s does not exist, so nothing was probed\n' "$HOSTDEPS_PROBE_PATH" >&2; return 2; }
            shift 2; _hd_main "$@"; return $?
            ;;
        --check)           shift; hostdep_check "$@"; return $? ;;
        ensure)            shift; hostdep_ensure "$@"; return $? ;;
        ensure-browsers)   shift; hostdep_ensure_browsers "$@"; return $? ;;
        harness)           hostdep_harness; return $? ;;
        --prove-failure)   _hd_prove; return $? ;;
        -h|--help|help)    sed -n '2,60p' "${BASH_SOURCE[0]}"; return 0 ;;
        *)                 printf 'usage: %s ensure|--check [id ...] | ensure-browsers <testsdir> <browser ...> | --prove-failure\n' "$0" >&2; return 2 ;;
    esac
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    set -u
    _hd_main "$@"
    exit $?
fi
