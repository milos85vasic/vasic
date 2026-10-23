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
# a quarter of an hour; the setup wizard sets 360 s). The apt-get call carries
# `-o DPkg::Lock::Timeout=30` so a held dpkg lock fails fast; an install that
# fails with rc 100 (a stale package index) is retried ONCE after `apt-get
# update`. So the WORST CASE on apt is THREE bounded calls (install, update,
# install) = 3 x HOSTDEPS_INSTALL_TIMEOUT; every other manager makes one call.
# A caller that wraps this script in its own timeout must allow 3x (the wizard:
# 3 x 360 s = 1080 s inside its 1200 s bound). dnf and yum have no lock-wait
# option: a held rpm/dnf lock waits until the per-call timeout fires (rc 124 ->
# FAILED, rc 1) — loud and bounded, never a hang. pacman, apk, zypper and brew
# fail fast on a held lock by themselves.
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
# bundled by Playwright. The soname each probes is read from `ldconfig -p`
# (glibc) or, on musl, from the library directories (see SUPPORTED HOSTS).
#
# SUPPORTED HOSTS — derived from workshop/scripts/_capabilities.sh CAP_PKG_TABLE
# (apt-get, ALT apt-rpm, dnf, yum, zypper, pacman, apk, brew, port). ALT Linux
# ships its RPM-backed apt as the binary `apt-get`, so the package NAMES are
# chosen by the distribution read from os-release (ID / ID_LIKE `altlinux` ->
# the `apt-rpm` column), never by the binary name alone. Every non-apt name in
# the table was checked against that distribution's own package index on
# 2026-10-22 (Fedora packages.fedoraproject.org, Arch archlinux.org/packages,
# Alpine pkgs.alpinelinux.org, ALT packages.altlinux.org, Homebrew
# formulae.brew.sh, MacPorts ports.macports.org); apt names were measured with
# dpkg-query on Ubuntu 26.04. openSUSE names were read from the Open Build
# Service public API (api.opensuse.org/public, openSUSE:Factory: the OCR engine
# is `tesseract-ocr`, its packs `tesseract-ocr-traineddata-<lang>`, poppler's
# utilities `poppler-tools`, the webkit libraries `libmanette-0_2-0` and
# `libwoff2dec1_0_2`); software.opensuse.org itself answered 403. Gaps, each rc 2
# (never a guess): Alpine publishes no srp_latn pack; ALT's poppler utilities
# package and every MacPorts name are UNCONFIRMED (ALT's binary page and
# ports.macports.org could not be read); yum (EL7) carries only the engine and
# poppler, and those were not verified. On Alpine (musl) `ldconfig -p` does not
# exist, so the two libraries are probed by path next to the musl loader
# (/lib:/usr/lib:/usr/local/lib; HOSTDEPS_LIB_PATH overrides) — and Playwright's
# webkit build is glibc-only, so on Alpine the libraries install but webkit
# itself still cannot run. On macOS the two webkit libraries are n/a
# (Playwright's webkit bundles them; `install-deps` is Linux-only) and are
# reported as such.
#
# LANGUAGE PACKS are probed with `tesseract --list-langs` (the engine reading its
# own tessdata), so present means "the engine can load it", not "a package is
# registered". Installing the packs is independent of turning OCR on: per-book
# OCR stays opt-in and OFF by default. NO user-level tessdata download fallback
# exists, on purpose: no in-tree OCR caller reads a user TESSDATA_PREFIX (the
# OCR runtime is the `jitesoft/tesseract-ocr` container), and a prefix replaces
# the system tessdata directory wholesale, so a partial user copy would hide
# the packs the system already has.
#
# USAGE
#   scripts/hostdeps.sh install [--only <cap|id>]... [--dry-run] [--print-commands] [--yes]
#       Probe, then install EVERY missing package in ONE manager call.
#       caps: webkit (libmanette libwoff), ocr (tesseract + eng osd srp
#       srp_latn rus deu fra packs), pdf (poppler); default all three.
#       --dry-run         print the plan and the exact command; change nothing
#       --print-commands  print ONLY the exact command line(s); change nothing
#       (both: rc 0 nothing to do, 1 something would be installed, 2 unknown)
#       --yes             install even when HOSTDEPS_AUTO_INSTALL=0 (an explicit
#                         operator request); never makes sudo prompt
#   scripts/hostdeps.sh check [--only <cap|id>]...
#       Machine-readable, never installs: one `hostdep id=.. capability=..
#       state=present|missing|n/a|undetermined manager=.. package=.. distro=..`
#       line per id, then `hostdeps verdict=<rc> ...`. rc 0/1/2.
#   scripts/hostdeps.sh ensure [id ...]        legacy per-id install (policy above)
#   scripts/hostdeps.sh --check [id ...]       legacy human report; never installs
#   scripts/hostdeps.sh ensure-browsers <testsdir> <browser ...>
#   scripts/hostdeps.sh harness                the FULL browser matrix: webkit's two
#                                              system libraries + chromium, firefox
#                                              and webkit downloads (_tests/ or
#                                              $HOSTDEPS_TESTS_DIR)
#   scripts/hostdeps.sh --prove-failure        paired proof: stubbed package
#                                              managers, plus seeded mutations
#   scripts/hostdeps.sh --probe-path <dir> --check ...   probe with PATH=<dir>
#   Sourced: hostdep_ensure, hostdep_check, hostdep_ensure_browsers.
#   ids: tesseract lang-eng lang-osd lang-srp lang-srp_latn lang-rus lang-deu
#        lang-fra poppler libmanette libwoff (default: all)
#   Env: HOSTDEPS_OS_RELEASE (default /etc/os-release, then /usr/lib/os-release),
#        HOSTDEPS_UNAME (default `uname -s`) — both exist so tests can fixture a
#        distribution; HOSTDEPS_AUTO_INSTALL, HOSTDEPS_INSTALL_TIMEOUT as above.
# ==============================================================================

HOSTDEPS_IDS="tesseract lang-eng lang-osd lang-srp lang-srp_latn lang-rus lang-deu lang-fra poppler libmanette libwoff"

# capability|ids — what `--only <capability>` selects.
HOSTDEPS_CAP_TABLE='ocr|tesseract lang-eng lang-osd lang-srp lang-srp_latn lang-rus lang-deu lang-fra
pdf|poppler
webkit|libmanette libwoff'

# id|probe-kind|probe-arg — a command on PATH, a soname in `ldconfig -p`, or a
# language the engine itself lists with `tesseract --list-langs`.
HOSTDEPS_PROBE_TABLE='tesseract|cmd|tesseract
lang-eng|tesslang|eng
lang-osd|tesslang|osd
lang-srp|tesslang|srp
lang-srp_latn|tesslang|srp_latn
lang-rus|tesslang|rus
lang-deu|tesslang|deu
lang-fra|tesslang|fra
poppler|cmd|pdftotext
libmanette|soname|libmanette-0.2.so.0
libwoff|soname|libwoff2dec.so.1.0.2'

# id|key=package ... — only names that are known. Unlisted = rc 2, never a guess.
# The key is the manager, except `apt-rpm` (ALT Linux, chosen from os-release).
# Provenance of every name: the header, SUPPORTED HOSTS.
HOSTDEPS_PKG_TABLE='tesseract|apt-get=tesseract-ocr apt-rpm=tesseract dnf=tesseract yum=tesseract zypper=tesseract-ocr pacman=tesseract apk=tesseract-ocr brew=tesseract port=tesseract
lang-eng|apt-get=tesseract-ocr-eng apt-rpm=tesseract-langpack-en dnf=tesseract-langpack-eng zypper=tesseract-ocr-traineddata-eng pacman=tesseract-data-eng apk=tesseract-ocr-data-eng brew=tesseract port=tesseract-eng
lang-osd|apt-get=tesseract-ocr-osd apt-rpm=tesseract-langpack-osd dnf=tesseract-osd zypper=tesseract-ocr-traineddata-osd pacman=tesseract-data-osd apk=tesseract-ocr-data-osd brew=tesseract port=tesseract-osd
lang-srp|apt-get=tesseract-ocr-srp apt-rpm=tesseract-langpack-sr dnf=tesseract-langpack-srp zypper=tesseract-ocr-traineddata-srp pacman=tesseract-data-srp apk=tesseract-ocr-data-srp brew=tesseract-lang port=tesseract-srp
lang-srp_latn|apt-get=tesseract-ocr-srp-latn apt-rpm=tesseract-langpack-sr_latn dnf=tesseract-langpack-srp_latn zypper=tesseract-ocr-traineddata-srp_latn pacman=tesseract-data-srp_latn brew=tesseract-lang port=tesseract-srp-latn
lang-rus|apt-get=tesseract-ocr-rus apt-rpm=tesseract-langpack-ru dnf=tesseract-langpack-rus zypper=tesseract-ocr-traineddata-rus pacman=tesseract-data-rus apk=tesseract-ocr-data-rus brew=tesseract-lang port=tesseract-rus
lang-deu|apt-get=tesseract-ocr-deu apt-rpm=tesseract-langpack-de dnf=tesseract-langpack-deu zypper=tesseract-ocr-traineddata-deu pacman=tesseract-data-deu apk=tesseract-ocr-data-deu brew=tesseract-lang port=tesseract-deu
lang-fra|apt-get=tesseract-ocr-fra apt-rpm=tesseract-langpack-fr dnf=tesseract-langpack-fra zypper=tesseract-ocr-traineddata-fra pacman=tesseract-data-fra apk=tesseract-ocr-data-fra brew=tesseract-lang port=tesseract-fra
poppler|apt-get=poppler-utils dnf=poppler-utils yum=poppler-utils zypper=poppler-tools pacman=poppler apk=poppler-utils brew=poppler
libmanette|apt-get=libmanette-0.2-0 apt-rpm=libmanette dnf=libmanette zypper=libmanette-0_2-0 pacman=libmanette apk=libmanette
libwoff|apt-get=libwoff1 apt-rpm=libwoff2 dnf=woff2 zypper=libwoff2dec1_0_2 pacman=woff2 apk=woff2'

# manager:subcommand — the manager name is not written next to its subcommand.
HOSTDEPS_MGR_TABLE='apt-get:install -y
dnf:install -y
yum:install -y
zypper:in -y
pacman:-S --noconfirm --needed
apk:add
brew:install
port:-N install'

# manager:extra-options — placed before the subcommand. Table-driven for the same
# reason as the table above.
HOSTDEPS_MGR_OPTS='apt-get:-o DPkg::Lock::Timeout=30'

HOSTDEPS_PROBE_PATH="${HOSTDEPS_PROBE_PATH:-$PATH:/sbin:/usr/sbin}"
# /opt/local/bin is MacPorts' root-owned prefix; it is last so it can never
# shadow a system manager.
HOSTDEPS_MGR_PATH="${HOSTDEPS_MGR_PATH:-/usr/sbin:/usr/bin:/sbin:/bin:/opt/local/bin}"

# _hd_uname — the kernel name, overridable for fixtures.
_hd_uname() { printf '%s' "${HOSTDEPS_UNAME:-$(uname -s 2>/dev/null || printf unknown)}"; }

# _hd_os_field <ID|ID_LIKE|PRETTY_NAME> — one os-release field, unquoted, or
# nothing. Reads $HOSTDEPS_OS_RELEASE, else /etc/os-release, else
# /usr/lib/os-release (the os-release(5) search order).
_hd_os_field() {
    local f line v
    if [ -n "${HOSTDEPS_OS_RELEASE:-}" ]; then f="$HOSTDEPS_OS_RELEASE"
    elif [ -r /etc/os-release ]; then f=/etc/os-release
    else f=/usr/lib/os-release; fi
    [ -r "$f" ] || return 1
    while IFS= read -r line; do
        case "$line" in
            "$1="*) v="${line#*=}"; v="${v#\"}"; v="${v%\"}"; v="${v#\'}"; v="${v%\'}"
                    printf '%s' "$v"; return 0 ;;
        esac
    done <"$f"
    return 1
}

# hostdep_distro — a short name for messages: os-release ID, else the kernel.
hostdep_distro() {
    local id
    id="$(_hd_os_field ID)" || id=""
    if [ -z "$id" ]; then
        case "$(_hd_uname)" in Darwin) id=macos ;; *) id="unknown($(_hd_uname))" ;; esac
    fi
    printf '%s' "$id"
}

# hostdep_pkgkey <manager> — which column of HOSTDEPS_PKG_TABLE applies. ALT
# Linux runs an RPM-backed `apt-get` whose package names are NOT Debian's.
hostdep_pkgkey() {
    if [ "$1" = "apt-get" ]; then
        case " $(_hd_os_field ID 2>/dev/null) $(_hd_os_field ID_LIKE 2>/dev/null) " in
            *" altlinux "*) printf 'apt-rpm'; return 0 ;;
        esac
    fi
    printf '%s' "$1"
}

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

# _hd_musl_probe <soname> — for a musl host, whose ldconfig cannot list the
# cache: 0 when <soname> exists in a directory of $HOSTDEPS_LIB_PATH (default
# /lib:/usr/lib:/usr/local/lib, musl's own default search path), 1 when it does
# not, and 2 when no musl loader (ld-musl-*.so.1) is found there — i.e. this is
# not a musl host, so an absent file would prove nothing and is never reported
# as "missing".
_hd_musl_probe() {
    local d f musl=0 IFS=:
    # IFS is ':' for this function only: $HOSTDEPS_LIB_PATH splits like PATH.
    for d in ${HOSTDEPS_LIB_PATH:-/lib:/usr/lib:/usr/local/lib}; do
        [ -n "$d" ] || continue
        for f in "$d"/ld-musl-*.so.1; do [ -e "$f" ] && musl=1; done
    done
    [ "$musl" -eq 1 ] || return 2
    for d in ${HOSTDEPS_LIB_PATH:-/lib:/usr/lib:/usr/local/lib}; do
        [ -n "$d" ] || continue
        [ -e "$d/$1" ] && return 0
    done
    return 1
}

# hostdep_probe <id> — 0 present, 1 absent, 2 cannot determine, 3 not
# applicable on this OS (a Linux-only library on macOS).
hostdep_probe() {
    local id="$1" kind arg ldc
    kind="$(_hd_table_field "$HOSTDEPS_PROBE_TABLE" "$id" 2)" || return 2
    arg="$(_hd_table_field "$HOSTDEPS_PROBE_TABLE" "$id" 3)"
    case "$kind" in
        cmd)
            if PATH="$HOSTDEPS_PROBE_PATH" command -v "$arg" >/dev/null 2>&1; then return 0; fi
            return 1
            ;;
        tesslang)
            # No engine means no pack the engine can load: absent, not unknown —
            # the pack's package pulls the engine in on every listed manager.
            local tb langs
            tb="$(PATH="$HOSTDEPS_PROBE_PATH" command -v tesseract 2>/dev/null)" || return 1
            langs="$("$tb" --list-langs 2>&1)" || return 2
            # Whole-line match: `srp` must never be satisfied by `srp_latn`.
            if printf '%s\n' "$langs" | grep -qx "$arg"; then return 0; fi
            return 1
            ;;
        soname)
            [ "$(_hd_uname)" = "Darwin" ] && return 3
            ldc="$(PATH="$HOSTDEPS_PROBE_PATH" command -v ldconfig 2>/dev/null || true)"
            local out tag re
            # glibc answers `ldconfig -p`; musl's ldconfig is a stub without -p
            # (Alpine: "Illegal option -p", non-zero). Only then, and only when a
            # musl loader is really present, read the library directories.
            if [ -z "$ldc" ] || ! out="$("$ldc" -p 2>/dev/null)"; then
                _hd_musl_probe "$arg"; return $?
            fi
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

# hostdep_pkg <id> <manager> — the package name, or nothing (and rc 1). The
# manager is mapped to its table column first (ALT's apt-get -> apt-rpm).
hostdep_pkg() {
    local row tok key
    key="$(hostdep_pkgkey "$2")"
    row="$(_hd_table_field "$HOSTDEPS_PKG_TABLE" "$1" 2)" || return 1
    for tok in $row; do
        if [ "${tok%%=*}" = "$key" ]; then printf '%s' "${tok#*=}"; return 0; fi
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
        3) printf 'n/a          %s — a Linux system library; not used on %s\n' "$id" "$(_hd_uname)"; return 0 ;;
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
    # $pkg is a SPACE-separated list (the batched `install`); every name in it
    # comes from HOSTDEPS_PKG_TABLE, which holds no glob or space characters.
    # shellcheck disable=SC2086
    if [ "$esc" = "sudo" ]; then
        sudo_bin="$(PATH="$HOSTDEPS_MGR_PATH" command -v sudo 2>/dev/null)" || return 2
        "$sudo_bin" -n $t env DEBIAN_FRONTEND=noninteractive "$mpath" $opts $sub $pkg >&2
    else
        $t env DEBIAN_FRONTEND=noninteractive "$mpath" $opts $sub $pkg >&2
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

# _hd_resolve_only <name ...> — capability names and ids -> ids. rc 2 on an
# unknown name, so a typo can never silently select nothing.
_hd_resolve_only() {
    local n ids out=""
    for n in "$@"; do
        if ids="$(_hd_table_field "$HOSTDEPS_CAP_TABLE" "$n" 2)"; then
            out="$out $ids"
        elif _hd_table_field "$HOSTDEPS_PROBE_TABLE" "$n" 2 >/dev/null; then
            out="$out $n"
        else
            printf 'UNDETERMINED unknown capability or id: %s (capabilities: ocr pdf webkit; ids: %s)\n' "$n" "$HOSTDEPS_IDS" >&2
            return 2
        fi
    done
    printf '%s' "${out# }"
}

# hostdep_capability_of <id> — the capability that selects <id>, or "-".
hostdep_capability_of() {
    local line
    while IFS= read -r line; do
        case " ${line#*|} " in *" $1 "*) printf '%s' "${line%%|*}"; return 0 ;; esac
    done <<EOF
$HOSTDEPS_CAP_TABLE
EOF
    printf '%s' '-'
}

_hd_supported_text() {
    printf 'supported: apt-get (Debian/Ubuntu), apt-get on ALT Linux, dnf (Fedora/RHEL 8+), yum, zypper (openSUSE), pacman (Arch), apk (Alpine), brew / port (macOS)'
}

# hostdep_install <install|dry-run|print> <id ...> — probe every id, then install
# EVERY missing package in ONE manager call. Idempotent: when nothing is missing
# no manager, no sudo and no installer is ever invoked. HOSTDEPS_YES=1 (--yes)
# overrides HOSTDEPS_AUTO_INSTALL=0; nothing overrides the no-prompt rule.
# In print mode stdout carries ONLY the command; everything else goes to stderr.
hostdep_install() {
    local mode="$1"; shift
    local id st worst=0 missing="" todo="" pkgs="" row mgr sub mpath key pkg esc pfx="" cmd rc distro
    _hd_say() { if [ "$mode" = "print" ]; then printf '%s\n' "$*" >&2; else printf '%s\n' "$*"; fi; }
    _hd_bump() { case "$1" in 1) worst=1 ;; 2) [ "$worst" -eq 1 ] || worst=2 ;; esac; }
    for id in "$@"; do
        hostdep_probe "$id"; st=$?
        case "$st" in
            0) _hd_say "present      $id" ;;
            1) missing="$missing $id" ;;
            3) _hd_say "n/a          $id — a Linux system library; not used on $(_hd_uname)" ;;
            *) _hd_say "UNDETERMINED $id — the probe could not run (no ldconfig / tesseract --list-langs failed / unknown id)"; _hd_bump 2 ;;
        esac
    done
    if [ -z "$missing" ]; then
        _hd_say "satisfied    every requested host dependency that could be probed is present — nothing to install"
        return "$worst"
    fi
    distro="$(hostdep_distro)"
    if ! row="$(hostdep_manager)"; then
        for id in $missing; do
            _hd_say "UNDETERMINED $id — no supported package manager found on this host (distro: $distro); $(_hd_supported_text). Install it by hand, then re-run: bash scripts/hostdeps.sh check"
        done
        return 2
    fi
    mgr="$(printf '%s' "$row" | cut -f1)"; sub="$(printf '%s' "$row" | cut -f2)"; mpath="$(printf '%s' "$row" | cut -f3)"
    key="$(hostdep_pkgkey "$mgr")"
    for id in $missing; do
        if pkg="$(hostdep_pkg "$id" "$mgr")"; then
            todo="$todo $id"
            case " $pkgs " in *" $pkg "*) ;; *) pkgs="$pkgs $pkg" ;; esac
        else
            _hd_say "UNDETERMINED $id — no package name is recorded for $key on $distro (never guessed); install the package that provides it by hand"
            _hd_bump 2
        fi
    done
    pkgs="${pkgs# }"; todo="${todo# }"
    [ -n "$pkgs" ] || return "$worst"
    [ "$(id -u 2>/dev/null || printf 1)" = "0" ] || [ "$mgr" = "brew" ] || pfx="sudo "
    cmd="$pfx$mgr $sub $pkgs"
    case "$mode" in
        print)
            printf '%s\n' "$cmd"; _hd_bump 1; return "$worst" ;;
        dry-run)
            for id in $todo; do _hd_say "MISSING      $id"; done
            _hd_say "would run:   $cmd"
            _hd_say "dry run — nothing was installed"; _hd_bump 1; return "$worst" ;;
    esac
    if _hd_auto_off pkg && [ "${HOSTDEPS_YES:-0}" != "1" ]; then
        for id in $todo; do _hd_say "MISSING      $id — auto-install is off (HOSTDEPS_AUTO_INSTALL=0; --yes overrides)"; done
        _hd_say "command:     $cmd"
        _hd_bump 2; return "$worst"
    fi
    esc="root"
    [ "$mgr" = "brew" ] || esc="$(hostdep_escalation)"
    if [ "$esc" = none ]; then
        for id in $todo; do _hd_say "MISSING      $id — no privilege to install without a password prompt (not root; sudo -n refused)"; done
        _hd_say "command:     $cmd"
        _hd_say "run that once as an administrator, then re-run: bash scripts/hostdeps.sh check"
        _hd_bump 2; return "$worst"
    fi
    printf 'installing   %s (%s) via %s%s — set HOSTDEPS_AUTO_INSTALL=0 to turn this off\n' \
        "$todo" "$pkgs" "$([ "$esc" = "sudo" ] && printf 'sudo -n ')" "$mgr" >&2
    _hd_install "$esc" "$mgr" "$sub" "$mpath" "$pkgs"; rc=$?
    if [ "$rc" != 0 ]; then
        for id in $todo; do _hd_say "FAILED       $id — '$cmd' exited rc=$rc"; done
        return 1
    fi
    for id in $todo; do
        hostdep_probe "$id"; st=$?
        if [ "$st" -eq 0 ]; then
            _hd_say "installed    $id"
        else
            _hd_say "FAILED       $id — '$cmd' exited 0 but the probe still does not find it"
            _hd_bump 1
        fi
    done
    return "$worst"
}

# hostdep_check_machine <id ...> — one key=value line per id; never installs.
hostdep_check_machine() {
    local id st state worst=0 np=0 nm=0 nn=0 nu=0 row mgr="none" pkg distro
    distro="$(hostdep_distro)"
    if row="$(hostdep_manager)"; then mgr="$(printf '%s' "$row" | cut -f1)"; fi
    for id in "$@"; do
        hostdep_probe "$id"; st=$?
        case "$st" in
            0) state=present; np=$((np+1)) ;;
            1) state=missing; nm=$((nm+1)); worst=1 ;;
            3) state=n/a; nn=$((nn+1)) ;;
            *) state=undetermined; nu=$((nu+1)); [ "$worst" -eq 1 ] || worst=2 ;;
        esac
        pkg="-"
        if [ "$mgr" != "none" ]; then pkg="$(hostdep_pkg "$id" "$mgr")" || pkg="-"; fi
        printf 'hostdep id=%s capability=%s state=%s manager=%s package=%s distro=%s\n' \
            "$id" "$(hostdep_capability_of "$id")" "$state" "$mgr" "$pkg" "$distro"
    done
    printf 'hostdeps verdict=%s present=%s missing=%s not_applicable=%s undetermined=%s\n' "$worst" "$np" "$nm" "$nn" "$nu"
    # A human line in the "<N> probed" form that scripts/zero-gap-coverage-measure.py counts.
    printf 'hostdeps summary: %s probed, %s present, %s missing, %s not applicable, %s undetermined\n' \
        "$((np + nm + nn + nu))" "$np" "$nm" "$nn" "$nu"
    return "$worst"
}

# _hd_cli <install|check> [options] — option parsing for the two entry points.
_hd_cli() {
    local cmd="$1" mode only="" ids; shift
    mode="install"
    while [ $# -gt 0 ]; do
        case "$1" in
            --only)           [ $# -ge 2 ] || { printf 'UNDETERMINED --only needs a capability or id\n' >&2; return 2; }
                              only="$only $2"; shift ;;
            --only=*)         only="$only ${1#--only=}" ;;
            --dry-run)        mode="dry-run" ;;
            --print-commands) mode="print" ;;
            --yes|-y)         HOSTDEPS_YES=1 ;;
            *)                printf 'UNDETERMINED unknown option for %s: %s\n' "$cmd" "$1" >&2; return 2 ;;
        esac
        shift
    done
    if [ -n "$only" ]; then
        # shellcheck disable=SC2086
        ids="$(_hd_resolve_only $only)" || return 2
    else
        ids="$HOSTDEPS_IDS"
    fi
    # shellcheck disable=SC2086
    if [ "$cmd" = "check" ]; then hostdep_check_machine $ids; return $?; fi
    # shellcheck disable=SC2086
    hostdep_install "$mode" $ids
}

# hostdep_ensure_browsers <testsdir> <browser ...> — Playwright browser
# downloads need NO privilege, so there is no escalation branch: present is a
# no-op, missing runs the installer once, a missing toolchain is rc 2.
hostdep_ensure_browsers() {
    if [ $# -lt 2 ]; then
        printf 'UNDETERMINED usage: hostdeps.sh ensure-browsers <tests-dir> <browser> [browser ...]\n' >&2
        return 2
    fi
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
    libwoff1) printf '\tlibwoff2dec.so.1.0.2 (libc6,x86-64) => /x\n' >>"$t/ldc" ;;
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
printf '%s %s\n' "\${0##*/}" "\$*" >>"$t/log"
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
        out="$(env -i PATH="$T/case/bin" HOSTDEPS_PROBE_PATH="$T/case/bin" HOSTDEPS_MGR_PATH="$T/case/bin" HOSTDEPS_LIB_PATH="$T/case/lib" HOSTDEPS_ARCH=x86_64 HOSTDEPS_UNAME=Linux HOSTDEPS_OS_RELEASE=/nonexistent-os-release "${envs[@]}" "$BASH" "$script" "$@" 2>/dev/null)"; rc=$?
        log="$(cat "$T/case/log")"
    }
    expect() { # <name> <cond-result>
        if [ "$2" != "ok" ]; then printf '    FAIL  %s\n' "$1"; fails=$((fails+1)); fi
    }
    local ok

    # C1 present: nothing installed, nothing run.
    rm -rf "$T/case"; mkdir -p "$T/case"; _hd_mkenv "$T/case"; printf '#!/bin/sh\n' >"$T/case/bin/tesseract"; chmod +x "$T/case/bin/tesseract"
    out="$(env -i PATH="$T/case/bin" HOSTDEPS_PROBE_PATH="$T/case/bin" HOSTDEPS_MGR_PATH="$T/case/bin" HOSTDEPS_LIB_PATH="$T/case/lib" HOSTDEPS_ARCH=x86_64 HOSTDEPS_UNAME=Linux HOSTDEPS_OS_RELEASE=/nonexistent-os-release STUB_UID=1000 "$BASH" "$script" ensure tesseract 2>/dev/null)"; rc=$?; log="$(cat "$T/case/log")"
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
    out="$(env -i PATH="$T/case/bin" HOSTDEPS_PROBE_PATH="$T/case/bin" HOSTDEPS_MGR_PATH="$T/case/bin" HOSTDEPS_LIB_PATH="$T/case/lib" HOSTDEPS_ARCH=x86_64 HOSTDEPS_UNAME=Linux HOSTDEPS_OS_RELEASE=/nonexistent-os-release STUB_UID=0 "$BASH" "$script" ensure tesseract 2>/dev/null)"; rc=$?
    ok=bad; [ "$rc" -eq 2 ] && grep -q 'no supported package manager' <<<"$out" && ok=ok
    expect "C7 no package manager -> rc 2" "$ok"

    # C8 operator switch: auto-install off.
    run c8 STUB_UID=0 HOSTDEPS_AUTO_INSTALL=0 -- ensure tesseract
    ok=bad; [ "$rc" -eq 2 ] && ! grep -q '^apt-get' <<<"$log" && ok=ok
    expect "C8 HOSTDEPS_AUTO_INSTALL=0 -> rc 2, no install" "$ok"

    # C9 no recorded package name for the manager present (yum/EL7 has none for libmanette).
    rm -rf "$T/case"; mkdir -p "$T/case"; _hd_mkenv "$T/case"; rm -f "$T/case/bin/apt-get"; mv "$T/case/bin/dnf" "$T/case/bin/yum"
    out="$(env -i PATH="$T/case/bin" HOSTDEPS_PROBE_PATH="$T/case/bin" HOSTDEPS_MGR_PATH="$T/case/bin" HOSTDEPS_LIB_PATH="$T/case/lib" HOSTDEPS_ARCH=x86_64 HOSTDEPS_UNAME=Linux HOSTDEPS_OS_RELEASE=/nonexistent-os-release STUB_UID=0 "$BASH" "$script" ensure libmanette 2>/dev/null)"; rc=$?; log="$(cat "$T/case/log")"
    ok=bad; [ "$rc" -eq 2 ] && ! grep -q '^yum' <<<"$log" && ok=ok
    expect "C9 no known package name -> rc 2, no guessed install" "$ok"

    # C10 failure outranks undetermined across ids (yum: tesseract fails, libmanette has no name).
    rm -rf "$T/case"; mkdir -p "$T/case"; _hd_mkenv "$T/case"; rm -f "$T/case/bin/apt-get"; mv "$T/case/bin/dnf" "$T/case/bin/yum"
    out="$(env -i PATH="$T/case/bin" HOSTDEPS_PROBE_PATH="$T/case/bin" HOSTDEPS_MGR_PATH="$T/case/bin" HOSTDEPS_LIB_PATH="$T/case/lib" HOSTDEPS_ARCH=x86_64 HOSTDEPS_UNAME=Linux HOSTDEPS_OS_RELEASE=/nonexistent-os-release STUB_UID=0 STUB_DNF_RC=1 "$BASH" "$script" ensure tesseract libmanette 2>/dev/null)"; rc=$?
    ok=bad; [ "$rc" -eq 1 ] && ok=ok
    expect "C10 one FAILED + one UNDETERMINED -> rc 1 (failure outranks undetermined)" "$ok"

    # C11 --check never installs and reports the absence as rc 1.
    run c11 STUB_UID=0 -- --check tesseract
    ok=bad; [ "$rc" -eq 1 ] && ! grep -q '^apt-get' <<<"$log" && ok=ok
    expect "C11 --check -> rc 1, never installs" "$ok"

    # C12 no ldconfig: a library probe cannot answer -> rc 2, not 0 and not 1.
    rm -rf "$T/case"; mkdir -p "$T/case"; _hd_mkenv "$T/case"; rm -f "$T/case/bin/ldconfig"
    out="$(env -i PATH="$T/case/bin" HOSTDEPS_PROBE_PATH="$T/case/bin" HOSTDEPS_MGR_PATH="$T/case/bin" HOSTDEPS_LIB_PATH="$T/case/lib" HOSTDEPS_ARCH=x86_64 HOSTDEPS_UNAME=Linux HOSTDEPS_OS_RELEASE=/nonexistent-os-release STUB_UID=0 "$BASH" "$script" --check libwoff 2>/dev/null)"; rc=$?
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
    out="$(env -i PATH="$T/case/bin" HOSTDEPS_PROBE_PATH="$T/case/bin" HOSTDEPS_MGR_PATH="$T/case/bin" HOSTDEPS_LIB_PATH="$T/case/lib" HOSTDEPS_ARCH=x86_64 HOSTDEPS_UNAME=Linux HOSTDEPS_OS_RELEASE=/nonexistent-os-release HOSTDEPS_TESTS_DIR="$B/tests" PLAYWRIGHT_BROWSERS_PATH="$B/ms" STUB_UID=0 "$BASH" "$script" harness 2>/dev/null)"; rc=$?; log="$(cat "$T/case/log")"
    ok=bad; [ "$rc" -eq 0 ] && grep -q '^apt-get -o DPkg::Lock::Timeout=30 install -y libmanette-0.2-0$' <<<"$log" && grep -q '^apt-get -o DPkg::Lock::Timeout=30 install -y libwoff1$' <<<"$log" && grep -q '^npx playwright install firefox$' "$T/npxlog" && ok=ok
    expect "C14 harness -> installs both libraries and the missing browser" "$ok"

    # C14b harness: a failure (1) outranks an undetermined (2). Libraries cannot
    # be installed (no privilege -> 2) while the browser download fails (1).
    rm -rf "$T/case" "$B/ms"; mkdir -p "$T/case" "$B/ms/chromium-1" "$B/ms/webkit-1"; _hd_mkenv "$T/case"
    cp "$T/npx.sh" "$T/case/bin/npx" 2>/dev/null; : >"$T/npxlog"
    out="$(env -i PATH="$T/case/bin" HOSTDEPS_PROBE_PATH="$T/case/bin" HOSTDEPS_MGR_PATH="$T/case/bin" HOSTDEPS_LIB_PATH="$T/case/lib" HOSTDEPS_ARCH=x86_64 HOSTDEPS_UNAME=Linux HOSTDEPS_OS_RELEASE=/nonexistent-os-release HOSTDEPS_TESTS_DIR="$B/tests" PLAYWRIGHT_BROWSERS_PATH="$B/ms" STUB_UID=1000 STUB_SUDO_OK=0 STUB_NPX_RC=7 "$BASH" "$script" harness 2>/dev/null)"; rc=$?
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
    out="$(env -i PATH="$T/case/bin" HOSTDEPS_PROBE_PATH="$T/case/bin" HOSTDEPS_MGR_PATH="$T/case/bin" HOSTDEPS_LIB_PATH="$T/case/lib" HOSTDEPS_ARCH=x86_64 HOSTDEPS_UNAME=Linux HOSTDEPS_OS_RELEASE=/nonexistent-os-release STUB_UID=0 "$BASH" "$script" ensure tesseract 2>&1 >/dev/null)"
    ok=bad; grep -q '^installing   tesseract' <<<"$out" && grep -qF 'HOSTDEPS_AUTO_INSTALL=0' <<<"$out" && ok=ok
    expect "C2b an install is announced on stderr with the opt-out" "$ok"

    # C15 library probe: whole-token soname, native architecture only.
    ldcase() { # <ldconfig row> <id> -> rc of --check
        rm -rf "$T/case"; mkdir -p "$T/case"; _hd_mkenv "$T/case"; printf '%s\n' "$1" >"$T/case/ldc"
        env -i PATH="$T/case/bin" HOSTDEPS_PROBE_PATH="$T/case/bin" HOSTDEPS_MGR_PATH="$T/case/bin" HOSTDEPS_LIB_PATH="$T/case/lib" HOSTDEPS_ARCH=x86_64 HOSTDEPS_UNAME=Linux HOSTDEPS_OS_RELEASE=/nonexistent-os-release "$BASH" "$script" --check "$2" >/dev/null 2>&1
    }
    ldcase "$(printf '\tlibwoff2dec.so.1.0.2 (libc6,x86-64) => /x')" libwoff; rc=$?
    ok=bad; [ "$rc" -eq 0 ] && ok=ok
    expect "C15a the native-arch whole-token row reads as present (control)" "$ok"
    ldcase "$(printf '\tlibwoff2dec.so.1.0.2 (libc6) => /x')" libwoff; rc=$?
    ok=bad; [ "$rc" -eq 1 ] && ok=ok
    expect "C15b an i386-only row does NOT read as present" "$ok"
    ldcase "$(printf '\tlibwoff2dec.so.1.0.20 (libc6,x86-64) => /x')" libwoff; rc=$?
    ok=bad; [ "$rc" -eq 1 ] && ok=ok
    expect "C15c a longer soname (…so.1.0.20) does NOT satisfy …so.1.0.2" "$ok"

    # C16 a hostile directory early on the CALLER's PATH cannot supply the installer.
    rm -rf "$T/case" "$T/evil"; mkdir -p "$T/case" "$T/evil"; _hd_mkenv "$T/case"
    printf '#!/bin/sh\nprintf evil >>"%s/evillog"\nexit 0\n' "$T" >"$T/evil/apt-get"; chmod +x "$T/evil/apt-get"; : >"$T/evillog"
    out="$(env -i PATH="$T/evil:$T/case/bin" HOSTDEPS_PROBE_PATH="$T/case/bin" HOSTDEPS_MGR_PATH="$T/case/bin" HOSTDEPS_LIB_PATH="$T/case/lib" HOSTDEPS_ARCH=x86_64 HOSTDEPS_UNAME=Linux HOSTDEPS_OS_RELEASE=/nonexistent-os-release STUB_UID=0 "$BASH" "$script" ensure tesseract 2>/dev/null)"; rc=$?; log="$(cat "$T/case/log")"
    ok=bad; [ "$rc" -eq 0 ] && [ ! -s "$T/evillog" ] && grep -q '^apt-get -o DPkg::Lock::Timeout=30 install' <<<"$log" && ok=ok
    expect "C16 the installer comes from \$HOSTDEPS_MGR_PATH, not the caller's PATH" "$ok"

    _hd_battery_distro "$script" "$T"; fails=$((fails+$?))
    rm -rf "$T"
    return "$fails"
}

# ------------------------------------------------------------------------------
# PER-DISTRIBUTION BATTERY for `install` / `check`. One hermetic fixture per
# supported manager: an os-release file, ONE generic manager stub and a set of
# EFFECTS the test declares (package name -> what appears on disk). The expected
# command in each fixture is a LITERAL written here, independently of the
# package table, so a wrong or missing name in the table is a visible failure.
# ------------------------------------------------------------------------------
_hd_mkenv2() { # <dir> <manager-binary-name>
    local t="$1" m="$2" b="$1/bin" tool
    mkdir -p "$b"; : >"$t/log"; : >"$t/ldc"; : >"$t/langs"; : >"$t/effects"
    for tool in env grep cat mkdir cut sed true touch chmod; do
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
    cat >"$b/timeout" <<EOF
#!/bin/sh
shift
exec "\$@"
EOF
    # STUB_MUSL=1 behaves like Alpine's musl-utils ldconfig: no -p, non-zero exit.
    cat >"$b/ldconfig" <<EOF
#!/bin/sh
if [ "\${STUB_MUSL:-0}" = "1" ]; then printf 'Illegal option -p\n' >&2; exit 1; fi
cat "$t/ldc"
EOF
    cat >"$t/tess.tmpl" <<EOF
#!/bin/sh
[ -n "\${STUB_TESS_RC:-}" ] && exit "\$STUB_TESS_RC"
printf 'List of available languages in "/x/" (n):\n'
cat "$t/langs"
EOF
    cat >"$b/$m" <<EOF
#!/bin/sh
printf '%s %s\n' "\${0##*/}" "\$*" >>"$t/log"
printf '%s\n' "\${DEBIAN_FRONTEND:-unset}" >"$t/frontend"
# STUB_STALE=1: every install fails rc 100 until an update has run.
if [ "\${STUB_STALE:-0}" = "1" ]; then
  case " \$* " in *" update "*) : >"$t/updated"; exit 0 ;; esac
  [ -f "$t/updated" ] || exit 100
fi
[ "\${STUB_MGR_RC:-0}" = "0" ] || exit "\$STUB_MGR_RC"
for a in "\$@"; do
  while IFS='|' read -r p kind arg; do
    [ "\$p" = "\$a" ] || continue
    case "\$kind" in
      tess) cat "$t/tess.tmpl" >"$b/tesseract"; chmod +x "$b/tesseract" ;;
      cmd)  printf '#!/bin/sh\n' >"$b/\$arg"; chmod +x "$b/\$arg" ;;
      lang) printf '%s\n' "\$arg" >>"$t/langs" ;;
      so)   if [ "\${STUB_MUSL:-0}" = "1" ]; then mkdir -p "$t/lib"; : >"$t/lib/\$arg"
            else printf '\t%s (libc6,%s) => /x\n' "\$arg" "\${STUB_LDTAG:-x86-64}" >>"$t/ldc"; fi ;;
    esac
  done <"$t/effects"
done
exit 0
EOF
    chmod +x "$b/id" "$b/sudo" "$b/timeout" "$b/ldconfig" "$b/$m"
}

_hd_battery_distro() { # <script> <scratch> -> prints FAIL lines, returns failed count
    local script="$1" D="$2/distro" fails=0 out rc log ok pkgs
    d_new() { # <manager-binary> <os-release text, or "" for none>
        rm -rf "$D"; mkdir -p "$D"; _hd_mkenv2 "$D" "$1"
        [ -z "$2" ] || printf '%s\n' "$2" >"$D/os-release"
    }
    d_run() { # <env...> -- <args...>
        local envs=()
        while [ "$1" != "--" ]; do envs+=("$1"); shift; done; shift
        : >"$D/log"
        out="$(env -i PATH="$D/bin" HOSTDEPS_PROBE_PATH="$D/bin" HOSTDEPS_MGR_PATH="$D/bin" HOSTDEPS_LIB_PATH="$D/lib" HOSTDEPS_ARCH=x86_64 HOSTDEPS_UNAME=Linux HOSTDEPS_OS_RELEASE="$D/os-release" "${envs[@]}" "$BASH" "$script" "$@" 2>/dev/null)"; rc=$?
        log="$(cat "$D/log")"
    }
    expect() { if [ "$2" != "ok" ]; then printf '    FAIL  %s\n' "$1"; fails=$((fails+1)); fi; }
    # d_fx tess eng osd srp srp_latn rus deu fra poppler manette woff — writes the
    # effects for a Linux fixture and sets $pkgs to the expected install list
    # ("-" = this distribution publishes no package for it).
    d_fx() {
        local i=0 n kinds="tess:|lang:eng|lang:osd|lang:srp|lang:srp_latn|lang:rus|lang:deu|lang:fra|cmd:pdftotext|so:libmanette-0.2.so.0|so:libwoff2dec.so.1.0.2" k
        pkgs=""
        for n in "$@"; do
            i=$((i+1)); k="$(printf '%s' "$kinds" | cut -d'|' -f"$i")"
            [ "$n" = "-" ] && continue
            printf '%s|%s|%s\n' "$n" "${k%%:*}" "${k#*:}" >>"$D/effects"
            pkgs="$pkgs $n"
        done
        pkgs="${pkgs# }"
    }
    # d_matrix <tag> <logged-prefix> <shown-command-prefix> <expected install rc> [env...]
    # dry-run names the exact command and touches nothing; install calls the
    # manager ONCE with exactly that list; a second install calls nothing.
    d_matrix() {
        local tag="$1" logp="$2" cmdp="$3" want="$4"; shift 4
        d_run STUB_UID=0 "$@" -- install --dry-run
        ok=bad; [ "$rc" -eq 1 ] && grep -qxF "would run:   $cmdp $pkgs" <<<"$out" && [ -z "$log" ] && ok=ok
        expect "$tag dry-run names exactly '$cmdp $pkgs' and installs nothing" "$ok"
        d_run STUB_UID=0 "$@" -- install
        ok=bad; [ "$rc" -eq "$want" ] && [ "$log" = "$logp $pkgs" ] && ok=ok
        expect "$tag install calls the manager ONCE with exactly the expected packages, rc $want (got rc $rc, log '$log')" "$ok"
        d_run STUB_UID=0 "$@" -- install
        ok=bad; [ "$rc" -eq "$want" ] && [ -z "$log" ] && ok=ok
        expect "$tag second install is a no-op (idempotent): no manager call" "$ok"
    }

    # D1..D10 — the supported matrix (workshop/scripts/_capabilities.sh CAP_PKG_TABLE).
    d_new apt-get 'ID=debian'
    d_fx tesseract-ocr tesseract-ocr-eng tesseract-ocr-osd tesseract-ocr-srp tesseract-ocr-srp-latn tesseract-ocr-rus tesseract-ocr-deu tesseract-ocr-fra poppler-utils libmanette-0.2-0 libwoff1
    d_matrix D1-debian 'apt-get -o DPkg::Lock::Timeout=30 install -y' 'apt-get install -y' 0
    local DEB="$pkgs"
    d_new apt-get "$(printf 'ID=ubuntu\nID_LIKE=debian')"
    d_fx tesseract-ocr tesseract-ocr-eng tesseract-ocr-osd tesseract-ocr-srp tesseract-ocr-srp-latn tesseract-ocr-rus tesseract-ocr-deu tesseract-ocr-fra poppler-utils libmanette-0.2-0 libwoff1
    d_matrix D2-ubuntu 'apt-get -o DPkg::Lock::Timeout=30 install -y' 'apt-get install -y' 0
    d_new apt-get "$(printf 'ID=altlinux\nNAME="ALT Linux"')"
    d_fx tesseract tesseract-langpack-en tesseract-langpack-osd tesseract-langpack-sr tesseract-langpack-sr_latn tesseract-langpack-ru tesseract-langpack-de tesseract-langpack-fr - libmanette libwoff2
    d_matrix D3-altlinux 'apt-get -o DPkg::Lock::Timeout=30 install -y' 'apt-get install -y' 2
    local ALT="$pkgs"
    d_new apt-get "$(printf 'ID=simply\nID_LIKE="altlinux"')"
    d_fx tesseract tesseract-langpack-en tesseract-langpack-osd tesseract-langpack-sr tesseract-langpack-sr_latn tesseract-langpack-ru tesseract-langpack-de tesseract-langpack-fr - libmanette libwoff2
    d_run STUB_UID=0 -- install --dry-run
    ok=bad; [ "$rc" -eq 1 ] && grep -qxF "would run:   apt-get install -y $ALT" <<<"$out" && ok=ok
    expect "D3b an ALT derivative named only by ID_LIKE=altlinux gets the ALT (apt-rpm) names" "$ok"
    # aarch64: ldconfig tags arm64 rows AArch64; an x86-64 row must not count.
    d_new apt-get "$(printf 'ID=ubuntu\nID_LIKE=debian')"
    d_fx tesseract-ocr tesseract-ocr-eng tesseract-ocr-osd tesseract-ocr-srp tesseract-ocr-srp-latn tesseract-ocr-rus tesseract-ocr-deu tesseract-ocr-fra poppler-utils libmanette-0.2-0 libwoff1
    d_run STUB_UID=0 HOSTDEPS_ARCH=aarch64 STUB_LDTAG=AArch64 -- install
    ok=bad; [ "$rc" -eq 0 ] && grep -q '^installed .*libwoff' <<<"$out" && ok=ok
    expect "D2b aarch64: the AArch64 ldconfig rows are read as present after the install, rc 0 (got rc $rc)" "$ok"
    d_new apt-get "$(printf 'ID=ubuntu\nID_LIKE=debian')"
    printf '\tlibmanette-0.2.so.0 (libc6,x86-64) => /x\n\tlibwoff2dec.so.1.0.2 (libc6,x86-64) => /x\n' >"$D/ldc"
    d_run STUB_UID=0 HOSTDEPS_ARCH=aarch64 -- check --only webkit
    ok=bad; [ "$rc" -eq 1 ] && [ "$(grep -c 'state=missing' <<<"$out")" -eq 2 ] && ok=ok
    expect "D2c aarch64: x86-64-only rows do not satisfy an arm64 host, rc 1" "$ok"
    d_new dnf 'ID=fedora'
    d_fx tesseract tesseract-langpack-eng tesseract-osd tesseract-langpack-srp tesseract-langpack-srp_latn tesseract-langpack-rus tesseract-langpack-deu tesseract-langpack-fra poppler-utils libmanette woff2
    d_matrix D4-fedora 'dnf install -y' 'dnf install -y' 0
    d_new pacman 'ID=arch'
    d_fx tesseract tesseract-data-eng tesseract-data-osd tesseract-data-srp tesseract-data-srp_latn tesseract-data-rus tesseract-data-deu tesseract-data-fra poppler libmanette woff2
    d_matrix D5-arch 'pacman -S --noconfirm --needed' 'pacman -S --noconfirm --needed' 0
    # Alpine is musl: its ldconfig has no -p, so the libraries are found by path
    # next to the musl loader. This fixture does NOT fake glibc ldconfig rows.
    d_new apk 'ID=alpine'; mkdir -p "$D/lib"; : >"$D/lib/ld-musl-x86_64.so.1"
    d_fx tesseract-ocr tesseract-ocr-data-eng tesseract-ocr-data-osd tesseract-ocr-data-srp - tesseract-ocr-data-rus tesseract-ocr-data-deu tesseract-ocr-data-fra poppler-utils libmanette woff2
    d_matrix D6-alpine 'apk add' 'apk add' 2 STUB_MUSL=1 HOSTDEPS_LIB_PATH="$D/lib"
    d_run STUB_UID=0 STUB_MUSL=1 HOSTDEPS_LIB_PATH="$D/lib" -- check --only webkit
    ok=bad; [ "$rc" -eq 0 ] && [ "$(grep -c 'state=present' <<<"$out")" -eq 2 ] && ok=ok
    expect "D6b musl: after the install both webkit libraries read present by path (no ldconfig -p), rc 0" "$ok"
    d_new apk 'ID=alpine'; mkdir -p "$D/lib"; : >"$D/lib/ld-musl-x86_64.so.1"
    d_run STUB_UID=0 STUB_MUSL=1 HOSTDEPS_LIB_PATH="$D/lib" -- check --only webkit
    ok=bad; [ "$rc" -eq 1 ] && [ "$(grep -c 'state=missing' <<<"$out")" -eq 2 ] && ok=ok
    expect "D6c musl without the libraries: missing (installable), not undetermined, rc 1" "$ok"
    d_new apk 'ID=alpine'; mkdir -p "$D/lib"
    d_run STUB_UID=0 STUB_MUSL=1 HOSTDEPS_LIB_PATH="$D/lib" -- check --only webkit
    ok=bad; [ "$rc" -eq 2 ] && [ "$(grep -c 'state=undetermined' <<<"$out")" -eq 2 ] && ok=ok
    expect "D6d ldconfig -p fails and no musl loader is found: undetermined, rc 2 (never guessed absent)" "$ok"
    d_new zypper 'ID=opensuse-tumbleweed'
    d_fx tesseract-ocr tesseract-ocr-traineddata-eng tesseract-ocr-traineddata-osd tesseract-ocr-traineddata-srp tesseract-ocr-traineddata-srp_latn tesseract-ocr-traineddata-rus tesseract-ocr-traineddata-deu tesseract-ocr-traineddata-fra poppler-tools libmanette-0_2-0 libwoff2dec1_0_2
    d_matrix D7-opensuse 'zypper in -y' 'zypper in -y' 0
    d_new yum 'ID=centos'
    d_fx tesseract - - - - - - - poppler-utils - -
    d_matrix D8-centos7 'yum install -y' 'yum install -y' 2
    # macOS: no os-release; webkit libraries are n/a; brew never escalates.
    d_new brew ''
    printf '%s\n' 'tesseract|tess|' 'tesseract|lang|eng' 'tesseract|lang|osd' 'tesseract-lang|lang|srp' \
        'tesseract-lang|lang|srp_latn' 'tesseract-lang|lang|rus' 'tesseract-lang|lang|deu' \
        'tesseract-lang|lang|fra' 'poppler|cmd|pdftotext' >"$D/effects"
    pkgs="tesseract tesseract-lang poppler"
    d_matrix D9-macos-brew 'brew install' 'brew install' 0 HOSTDEPS_UNAME=Darwin
    d_run STUB_UID=1000 HOSTDEPS_UNAME=Darwin -- check --only webkit
    ok=bad; [ "$rc" -eq 0 ] && [ "$(grep -c 'state=n/a' <<<"$out")" -eq 2 ] && ok=ok
    expect "D9b macOS: the webkit libraries are n/a, rc 0 (Linux-only)" "$ok"
    d_new port ''
    printf '%s\n' 'tesseract|tess|' 'tesseract-eng|lang|eng' 'tesseract-osd|lang|osd' 'tesseract-srp|lang|srp' \
        'tesseract-srp-latn|lang|srp_latn' 'tesseract-rus|lang|rus' 'tesseract-deu|lang|deu' 'tesseract-fra|lang|fra' >"$D/effects"
    pkgs="tesseract tesseract-eng tesseract-osd tesseract-srp tesseract-srp-latn tesseract-rus tesseract-deu tesseract-fra"
    d_matrix D10-macos-port 'port -N install' 'port -N install' 2 HOSTDEPS_UNAME=Darwin
    d_new brew ''
    printf '%s\n' 'tesseract|tess|' 'tesseract|lang|eng' 'tesseract|lang|osd' 'tesseract-lang|lang|srp' \
        'tesseract-lang|lang|srp_latn' 'tesseract-lang|lang|rus' 'tesseract-lang|lang|deu' \
        'tesseract-lang|lang|fra' 'poppler|cmd|pdftotext' >"$D/effects"
    d_run STUB_UID=1000 HOSTDEPS_UNAME=Darwin -- install
    ok=bad; [ "$rc" -eq 0 ] && ! grep -q '^sudo' <<<"$log" && [ "$log" = "brew install tesseract tesseract-lang poppler" ] && ok=ok
    expect "D9c brew installs as the user and never calls sudo" "$ok"
    # Homebrew lives in /opt/homebrew/bin or /usr/local/bin: on the caller's PATH,
    # NOT on the sanitised manager path. It must still be found.
    mkdir -p "$D/brewbin"; mv "$D/bin/brew" "$D/brewbin/brew"; rm -f "$D/bin/tesseract" "$D/bin/pdftotext"; : >"$D/langs"
    d_run STUB_UID=1000 HOSTDEPS_UNAME=Darwin PATH="$D/bin:$D/brewbin" -- install
    ok=bad; [ "$rc" -eq 0 ] && [ "$log" = "brew install tesseract tesseract-lang poppler" ] && ok=ok
    expect "D9d brew found on the caller's PATH although it is absent from HOSTDEPS_MGR_PATH (got rc $rc)" "$ok"

    # E — elevation, modes and edge cases, on the Debian fixture.
    d_new apt-get 'ID=debian'
    d_fx tesseract-ocr tesseract-ocr-eng tesseract-ocr-osd tesseract-ocr-srp tesseract-ocr-srp-latn tesseract-ocr-rus tesseract-ocr-deu tesseract-ocr-fra poppler-utils libmanette-0.2-0 libwoff1
    d_run STUB_UID=1000 STUB_SUDO_OK=0 -- install
    ok=bad; [ "$rc" -eq 2 ] && ! grep -q '^apt-get' <<<"$log" && ! grep -qE '^sudo ([^-]|-[^n])' <<<"$log" \
        && grep -qxF "command:     sudo apt-get install -y $DEB" <<<"$out" && ok=ok
    expect "E1 no root, no passwordless sudo -> rc 2, exact sudo command printed, nothing installed, no prompt" "$ok"
    d_run STUB_UID=1000 STUB_SUDO_OK=1 -- install
    ok=bad; [ "$rc" -eq 0 ] && grep -qx 'sudo -n true' <<<"$log" && grep -q '^sudo -n .*apt-get -o DPkg::Lock::Timeout=30 install -y ' <<<"$log" \
        && [ "$(grep -c '^apt-get ' <<<"$log")" -eq 1 ] && ! grep -qE '^sudo ([^-]|-[^n])' <<<"$log" && ok=ok
    expect "E2 passwordless sudo -> ONE sudo -n install, rc 0" "$ok"
    d_new apt-get 'ID=debian'
    d_fx tesseract-ocr tesseract-ocr-eng tesseract-ocr-osd tesseract-ocr-srp tesseract-ocr-srp-latn tesseract-ocr-rus tesseract-ocr-deu tesseract-ocr-fra poppler-utils libmanette-0.2-0 libwoff1
    # poppler is already present here, so a status line ("present poppler") exists
    # and must go to stderr: stdout is ONLY the command, ready to paste.
    printf '#!/bin/sh\n' >"$D/bin/pdftotext"; chmod +x "$D/bin/pdftotext"
    d_run STUB_UID=1000 -- install --print-commands
    ok=bad; [ "$rc" -eq 1 ] && [ "$out" = "sudo apt-get install -y ${DEB/ poppler-utils/}" ] && [ -z "$log" ] && ok=ok
    expect "E3 --print-commands prints ONLY the command (stdout), installs nothing, rc 1" "$ok"
    rm -f "$D/bin/pdftotext"
    d_run STUB_UID=0 HOSTDEPS_AUTO_INSTALL=0 -- install
    ok=bad; [ "$rc" -eq 2 ] && [ -z "$log" ] && ok=ok
    expect "E4 HOSTDEPS_AUTO_INSTALL=0 -> rc 2, nothing installed" "$ok"
    d_run STUB_UID=0 STUB_MGR_RC=100 -- install
    ok=bad; [ "$rc" -eq 1 ] && grep -q '^FAILED .*exited rc=100' <<<"$out" && ! grep -q '^installed' <<<"$out" && ok=ok
    expect "E5 the manager fails -> rc 1 naming its exit code, never a silent success" "$ok"
    d_run STUB_UID=0 -- check
    ok=bad; [ "$rc" -eq 1 ] && grep -qx 'hostdep id=lang-srp_latn capability=ocr state=missing manager=apt-get package=tesseract-ocr-srp-latn distro=debian' <<<"$out" && [ -z "$log" ] && ok=ok
    expect "E6 check is machine-readable, names the package, never installs, rc 1" "$ok"
    d_run STUB_UID=0 HOSTDEPS_AUTO_INSTALL=0 -- install --yes
    ok=bad; [ "$rc" -eq 0 ] && [ "$log" = "apt-get -o DPkg::Lock::Timeout=30 install -y $DEB" ] && ok=ok
    expect "E7 --yes is an explicit request that overrides HOSTDEPS_AUTO_INSTALL=0" "$ok"
    d_run STUB_UID=0 -- check
    ok=bad; [ "$rc" -eq 0 ] && grep -qx 'hostdeps verdict=0 present=11 missing=0 not_applicable=0 undetermined=0' <<<"$out" && ok=ok
    expect "E8 after the install every one of the 11 ids reads present, rc 0" "$ok"
    # srp must never be satisfied by srp_latn; a failing --list-langs is unknown.
    d_new apt-get 'ID=debian'
    cat "$D/tess.tmpl" >"$D/bin/tesseract"; chmod +x "$D/bin/tesseract"; printf 'srp_latn\n' >"$D/langs"
    d_run STUB_UID=0 -- check --only lang-srp --only lang-srp_latn
    ok=bad; [ "$rc" -eq 1 ] && grep -q 'id=lang-srp .*state=missing' <<<"$out" && grep -q 'id=lang-srp_latn .*state=present' <<<"$out" && ok=ok
    expect "E9 the language probe matches whole names: srp_latn does not satisfy srp" "$ok"
    d_run STUB_UID=0 STUB_TESS_RC=1 -- check --only lang-eng
    ok=bad; [ "$rc" -eq 2 ] && grep -q 'state=undetermined' <<<"$out" && ok=ok
    expect "E10 tesseract --list-langs failing -> undetermined, rc 2" "$ok"
    d_new nothing 'ID=plan9'; rm -f "$D/bin/nothing"
    d_run STUB_UID=0 -- install
    ok=bad; [ "$rc" -eq 2 ] && grep -q 'distro: plan9' <<<"$out" && grep -q 'supported: apt-get' <<<"$out" && ok=ok
    expect "E11 unknown distribution with no supported manager -> rc 2 with guidance" "$ok"
    d_run STUB_UID=0 -- install --only nosuchcap
    ok=bad; [ "$rc" -eq 2 ] && [ -z "$log" ] && ok=ok
    expect "E12 an unknown --only selects nothing silently -> rc 2" "$ok"
    d_new apt-get 'ID=debian'
    d_fx tesseract-ocr tesseract-ocr-eng tesseract-ocr-osd tesseract-ocr-srp tesseract-ocr-srp-latn tesseract-ocr-rus tesseract-ocr-deu tesseract-ocr-fra poppler-utils libmanette-0.2-0 libwoff1
    d_run STUB_UID=1000 STUB_SUDO_OK=0 -- install --yes
    ok=bad; [ "$rc" -eq 2 ] && ! grep -q '^apt-get' <<<"$log" && ok=ok
    expect "E13 --yes without root or passwordless sudo still installs nothing, rc 2 (it overrides the opt-out, not privilege)" "$ok"
    d_run STUB_UID=1000 STUB_SUDO_OK=1 STUB_STALE=1 -- install
    ok=bad; [ "$rc" -eq 0 ] && grep -q '^sudo -n .*apt-get -o DPkg::Lock::Timeout=30 update' <<<"$log" \
        && [ "$(grep -c '^apt-get ' <<<"$log")" -eq 3 ] && ok=ok
    expect "E14 stale index as a sudo user: the one apt-get update runs through sudo -n too, then the retry succeeds" "$ok"
    d_new apt-get 'ID=debian'
    d_fx tesseract-ocr tesseract-ocr-eng tesseract-ocr-osd tesseract-ocr-srp tesseract-ocr-srp-latn tesseract-ocr-rus tesseract-ocr-deu tesseract-ocr-fra poppler-utils libmanette-0.2-0 libwoff1
    d_run STUB_UID=0 -- install
    ok=bad; [ "$rc" -eq 0 ] && [ "$(cat "$D/frontend" 2>/dev/null)" = "noninteractive" ] && ok=ok
    expect "E15 as root the manager still runs with DEBIAN_FRONTEND=noninteractive (no debconf prompt)" "$ok"
    d_run STUB_UID=0 -- check
    ok=bad; [ "$rc" -eq 0 ] && grep -qx 'hostdeps summary: 11 probed, 11 present, 0 missing, 0 not applicable, 0 undetermined' <<<"$out" && ok=ok
    expect "E16 check ends with a human summary the coverage measurer can count (N probed)" "$ok"
    d_run STUB_UID=0 -- ensure-browsers
    ok=bad; [ "$rc" -eq 2 ] && ok=ok
    expect "E17 ensure-browsers with no arguments is a usage error, rc 2 (got rc $rc)" "$ok"
    d_run STUB_UID=0 -- ensure-browsers "$D"
    ok=bad; [ "$rc" -eq 2 ] && ok=ok
    expect "E18 ensure-browsers with a directory but no browser is a usage error, rc 2 (got rc $rc)" "$ok"
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
'M10 missing ldconfig reads as present@@_hd_musl_probe "$arg"; return $?@@return 0'
'M12 auto-install switch ignored for browsers@@if _hd_auto_off browser; then@@if false; then'
'M13 browser download not under timeout@@( cd "$dir" && $t npx playwright install "$b" >&2 )@@( cd "$dir" && npx playwright install "$b" >&2 )'
'M14 harness lets undetermined outrank failure@@if [ "$r1" -eq 1 ] || [ "$r2" -eq 1 ]; then return 1; fi@@if [ "$r1" -eq 2 ] || [ "$r2" -eq 2 ]; then return 2; fi'
'M15 no dpkg lock timeout@@HOSTDEPS_MGR_OPTS='"'"'apt-get:-o DPkg::Lock::Timeout=30'"'"'@@HOSTDEPS_MGR_OPTS='"'"'apt-get:'"'"''
'M16 no stale-index refresh and retry@@if [ "$rc" -eq 100 ] && [ "$mgr" = "apt-get" ]; then@@if false; then'
'M17 soname matched as a substring@@re="^[[:space:]]*${arg//./\\.}[[:space:]]+\\([^)]*${tag}"@@re="${arg//./\\.}"'
'M18 any architecture counts as present@@tag="$(_hd_arch_tag)"@@tag=""'
'M19 installer chosen from the caller PATH@@where="$(PATH="$HOSTDEPS_MGR_PATH" command -v "$mgr" 2>/dev/null)" || continue@@where="$(command -v "$mgr" 2>/dev/null)" || continue'
'M20 install not announced@@"$id" "$pkg" "$([ "$esc" = "sudo" ] && printf '"'"'sudo -n '"'"')" "$mgr" >&2@@"$id" "$pkg" "$([ "$esc" = "sudo" ] && printf '"'"'sudo -n '"'"')" "$mgr" >/dev/null'
'M21 wrong apt name for a language pack@@apt-get=tesseract-ocr-srp-latn@@apt-get=tesseract-ocr-srp_latn'
'M22 a language pack dropped from the default set@@lang-deu lang-fra poppler libmanette@@lang-deu poppler libmanette'
'M23 batched install without the elevation check@@if [ "$esc" = none ]; then@@if [ "$esc" = nevermatches ]; then'
'M24 non-idempotent: present ids are reinstalled@@0) _hd_say "present      $id" ;;@@0) missing="$missing $id" ;;'
'M25 silent success when the manager fails@@if [ "$rc" != 0 ]; then@@if false; then'
'M26 --dry-run falls through and installs@@_hd_say "dry run — nothing was installed"; _hd_bump 1; return "$worst" ;;@@_hd_say "dry run — nothing was installed" ;;'
'M27 ALT Linux treated as Debian@@*" altlinux "*) printf '"'"'apt-rpm'"'"'; return 0 ;;@@*" nevermatches "*) printf '"'"'apt-rpm'"'"'; return 0 ;;'
'M28 language probe matches substrings@@grep -qx "$arg"@@grep -q "$arg"'
'M29 --yes ignored@@[ "${HOSTDEPS_YES:-0}" != "1" ]@@true'
'M30 unknown --only selects nothing silently@@ids="$(_hd_resolve_only $only)" || return 2@@ids="$(_hd_resolve_only $only)" || ids=""'
'M31 --print-commands pollutes stdout@@then printf '"'"'%s\n'"'"' "$*" >&2; else@@then printf '"'"'%s\n'"'"' "$*"; else'
'M32 webkit libraries not n/a on macOS@@[ "$(_hd_uname)" = "Darwin" ] && return 3@@false && return 3'
'M33 libwoff probed by the wrong soname@@libwoff|soname|libwoff2dec.so.1.0.2'"'"'@@libwoff|soname|libwoff2dec.so.1'"'"''
'M34 brew escalated through sudo@@[ "$mgr" = "brew" ] || esc="$(hostdep_escalation)"@@esc="$(hostdep_escalation)"'
'M35 printed command for a non-root user lacks sudo@@|| [ "$mgr" = "brew" ] || pfx="sudo "@@|| [ "$mgr" = "brew" ] || pfx=""'
'M36 wrong Fedora OSD package@@dnf=tesseract-osd@@dnf=tesseract-langpack-osd'
'M37 non-musl host with a failing ldconfig reads as absent@@[ "$musl" -eq 1 ] || return 2@@[ "$musl" -eq 1 ] || return 1'
'M38 musl library directories never searched@@[ -e "$d/$1" ] && return 0@@false && return 0'
'M39 wrong aarch64 ldconfig tag@@aarch64|arm64)  printf '"'"'AArch64'"'"' ;;@@aarch64|arm64)  printf '"'"'x86-64'"'"' ;;'
'M40 --yes also bypasses the privilege check@@if [ "$esc" = none ]; then@@if [ "$esc" = none ] && [ "${HOSTDEPS_YES:-0}" != "1" ]; then'
'M41 stale-index refresh runs without sudo@@_hd_run_installer "$esc" "$mgr" "$mpath" "$opts" "update" ""@@_hd_run_installer root "$mgr" "$mpath" "$opts" "update" ""'
'M42 ALT detected from ID only, not ID_LIKE@@case " $(_hd_os_field ID 2>/dev/null) $(_hd_os_field ID_LIKE 2>/dev/null) " in@@case " $(_hd_os_field ID 2>/dev/null) " in'
'M43 brew looked up on the sanitised manager path@@where="$(command -v "$mgr" 2>/dev/null)" || continue@@where="$(PATH="$HOSTDEPS_MGR_PATH" command -v "$mgr" 2>/dev/null)" || continue'
'M44 root install without DEBIAN_FRONTEND=noninteractive@@        $t env DEBIAN_FRONTEND=noninteractive "$mpath"@@        $t env "$mpath"'
'M45 wrong openSUSE language-pack name@@zypper=tesseract-ocr-traineddata-srp_latn@@zypper=tesseract-ocr-traineddata-srp-latn'
'M46 ensure-browsers without its usage guard@@if [ $# -lt 2 ]; then@@if false; then'
'M47 check without the countable summary line@@printf '"'"'hostdeps summary: %s probed@@printf '"'"'hostdeps total: %s probed'
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
        install|check)     _hd_cli "$@"; return $? ;;
        ensure)            shift; hostdep_ensure "$@"; return $? ;;
        ensure-browsers)   shift; hostdep_ensure_browsers "$@"; return $? ;;
        harness)           hostdep_harness; return $? ;;
        --prove-failure)   _hd_prove; return $? ;;
        -h|--help|help)    awk 'NR>2 && /^# =====/ {exit} NR>1 {print}' "${BASH_SOURCE[0]}"; return 0 ;;
        *)                 printf 'usage: %s install [--only <cap|id>]... [--dry-run|--print-commands] [--yes] | check [--only ...] | ensure|--check [id ...] | ensure-browsers <testsdir> <browser ...> | harness | --prove-failure\n' "$0" >&2; return 2 ;;
    esac
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    set -u
    _hd_main "$@"
    exit $?
fi
