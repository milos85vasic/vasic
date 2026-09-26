#!/usr/bin/env bash
# zero-gap-class-build-if-missing.sh — sweep class `build-if-missing` (feature 010, task T025).
#
# WHAT IT DETECTS (§11.4.18)
#   The "rebuild trap": a start / restart path that builds its binary ONLY WHEN THE
#   BINARY IS ABSENT.  `[ -x "$BIN" ] || bash build.sh` runs a stale binary after
#   every source change, and a `restart` of it restarts the stale binary
#   (constitution principle "A Restart Runs What Was Built").  A script is CLEAN
#   when it carries a freshness guard (below) or never builds behind an existence
#   test; otherwise each guarded build is one FINDING (build-freshness), located at
#   `<tracked path>:<line of the guard>`.  Severity is by consequence: a start* /
#   restart* script runs the stale binary AS THE SERVICE (high); a script under a
#   test / fixture / challenge / example directory only exercises a stale build
#   (low); any other script — gate, deploy, tool wrapper — uses a stale build (medium).
#
# POPULATION (docs/zero-gap/sweep-classes.tsv row `build-if-missing`)
#   TRACKED files only, in the umbrella AND every checked-out submodule (read from
#   `git ls-files --recurse-submodules`, so nested gitlinks and private submodules
#   are covered by path only; an untracked script is not seen), that either
#     (a) is NAMED like a start path: basename start*.sh or restart*.sh, at any
#         depth (covers scripts/start*.sh, platform/scripts/start*.sh, **/restart*.sh
#         and stray start.sh / start-daemon.sh), or
#     (b) is a *.sh / *.bash file containing the guarded-build idiom (a test on an
#         artefact whose "missing" branch runs a build command).
#   EXCLUDED: `_tests/fixtures/zero-gap/` (the corpora are deliberately defective);
#   third-party trees, DERIVED from helix-deps.yaml's own `#   <path> -> <url>`
#   exclusion comment block (the feature-010 shared exclusion ruling, the same
#   derivation unregistered-scripts uses: today submodules/superspec,
#   milosvasic.ru/Upstreamable and the 27 submodules/qa/tools/** gitlinks); and the
#   vendored spec-kit tree `.specify/` at any depth (same ruling).
#   Because the set is derived from file names and a text scan, a NEW start script
#   or a new guarded build is covered without editing this class.
#   With `--corpus <dir>` the population is every non-directory under <dir> and
#   locations are relative to it.
#
# THE GUARDED-BUILD IDIOM (all of these, on non-comment lines)
#   [ -x|-f|-e|-X|-s ARTEFACT ] || BUILD          test(1) and [[ ]] spellings
#   [ ! -x|-f|-e ARTEFACT ] && BUILD
#   [ ... ] || { ...; BUILD; }                    multi-line group (12 lines)
#   if [ ! -x ARTEFACT ]; then ... BUILD ... fi   negated test: build in the then-branch
#   if [ -x ARTEFACT ]; then ... else BUILD fi    positive test: build in the else-branch
#   if [ ! -x ARTEFACT ] && [!] BUILD; then       the build IN THE if-CONDITION (fix round F2;
#   if [ -x ARTEFACT ] || [!] BUILD; then          rev-base-A's false negative at
#                                                  scripts/verify-workable-items.sh:185)
#   (the condition arm counts only with the connector that runs it when the artefact is ABSENT:
#   `&&` after a negated test, `||` after a positive one; `[ -x ] && make -q` is not the trap)
#   A guard inside a function body is found where it is written, so a build
#   "hidden behind a function" is seen.  BUILD is a command whose word is one of
#   build*.sh / build_*, go build|install, make, cmake, ninja, cargo, mvn, gradle,
#   npm|yarn|pnpm [run] build, docker|podman [compose] build, jekyll build; a
#   command that begins with echo/printf/log*/undetermined/die/fail/warn/exit/return
#   (a REFUSAL that merely names build.sh in its message) is not a build.
#
# FRESHNESS GUARD (the file is CLEAN when ANY executable line has one)
#   Inline `#` comments are stripped and message lines (first command echo, printf,
#   log*, warn*, info, ...) are ignored first.  Then a line is a guard when it has
#   -nt / -ot, -newer, find -newer|-mmin|-mtime, stat ... %Y, a call to a freshness
#   gate (ensure_fresh*, prepare_fresh*, assert_fresh*, check_fresh*), OR it
#   COMPARES (test / [ ] / [[ ]] with = == != -eq -ne -lt -gt -le -ge, or cmp /
#   diff / grep -q) an operand that is a build stamp or `git rev-parse HEAD` —
#   directly, or through a variable assigned from one (two levels).  A `stamp` word
#   glued to a preceding letter (`timestamp`, `TIMESTAMP`) is a wall clock, not a
#   build stamp, and a stamp file only tested for existence (`[ -f x.stamp ]`) or
#   HEAD read only to label a binary is not a guard.  workshop's
#   `ensure_fresh_server` (scripts/_common.sh) is the fixed reference and is not reported.
#
# EXIT CODES   0 clean (full non-empty population inspected)   1 at least one FINDING
#              2 could not determine (empty population, tool missing, bad --root, a
#                candidate that is not a regular file, ...).  A finding outranks an
#                undetermined.  Every rc prints INSPECTED and POPULATION-SHA.
#
# MEASURED (live tree, 2026-09-26, re-measured in fix round F2)
#   13 population items, 8 FINDINGs (1 high, 5 medium, 2 low); all 8 hand-read and
#   all 8 are real existence-only guarded builds (precision 8/8), including
#   submodules/llms_verifier/.../run_all_providers_challenge.sh:79 (the earlier class review's
#   false negative: a `local timestamp=` used to count as a stamp) and, new in F2,
#   scripts/verify-workable-items.sh:185 (medium): its --prove-failure path runs
#   `if [ ! -x "$TOOL_BIN" ] && ! build_tool; then <refusal>`, so the proof exercises a stale
#   workable-items binary after a change under _tools/workable-items/ (the same file's G4/G5 leg
#   at :128 was already reported; no freshness guard anywhere in the file).
#   1 COULD-NOT-INSPECT: submodules/qa/scripts/anti-bluff-scan.sh is a tracked
#   symlink and is never followed, so the live rc is 1 (findings outrank it).
#   Planted-corpus detection: 1.0 (N = 14 planted rows), a regression check of known patterns;
#   live-population recall UNMEASURED.  Runtime about 6 s.
#
# WHAT IT DOES NOT SEE (honest limits, §11.4.6)
#   - a build behind indirection: `[ -x "$BIN" ] || "$BUILD_CMD"`, `|| eval ...`, or a
#     guard in one file whose build lives in another it sources or calls;
#   - a start path with NO shell file at all: systemd units, compose `command:`,
#     Makefile targets, package.json scripts, extensionless scripts, CI files;
#   - freshness is decided PER FILE: one stamp comparison anywhere makes the whole
#     file CLEAN, so a second unrelated guarded build in it is not reported; and the
#     indicator is textual, not proof that the comparison gates THIS build;
#   - a stamp compared through three or more variable hops is not recognised (the
#     file is then REPORTED, a false positive, never a silent miss);
#   - uninitialised submodules (not on disk), untracked files, third-party trees
#     (excluded above), and files whose names hold a tab or a newline (reported as
#     COULD-NOT-INSPECT); symlinks, FIFOs, devices, sockets and tracked-but-absent
#     candidates are never read (COULD-NOT-INSPECT, one line each);
#   - it never runs anything: no build, no start, no network.
#
# USAGE  zero-gap-class-build-if-missing.sh --root <abs dir> [--corpus <abs dir>] [--emit-population]
#        zero-gap-class-build-if-missing.sh --prove-failure      (paired proof, throwaway copies)
set -uo pipefail
export LC_ALL=C LANG=C
export PYTHONDONTWRITEBYTECODE=1

CLASS_ID="build-if-missing"
SELF_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SELF="$SELF_DIR/$(basename "${BASH_SOURCE[0]}")"
FIXPFX="_tests/fixtures/zero-gap/"

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

# ---------------------------------------------------------------------------
# The detector.  awk reads the named files (relative to cwd) and prints
#   G<TAB>path<TAB>line<TAB>guard-form      one per guarded build
#   F<TAB>path                              the file carries a freshness indicator
# ---------------------------------------------------------------------------
DETECTOR='
function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
function is_msg_word(w) {
    return (w ~ /^(echo|printf|undet[A-Za-z_]*|die|fail[A-Za-z_]*|fatal|warn[A-Za-z_]*|error|err|log[A-Za-z_]*|info|debug|exit|return|msg|say|skip|note|abort|usage|zge_say|true|false|:)$/ \
         || w ~ /^(report_build|build_(fail|undet|warn|error|gate|ok|skip))/)
}
# mask(text): separators (; | & ( ) { }) inside quotes become blanks so a message cannot be split into commands
function mask(text,   i, ch, q, out) {
    q = ""; out = ""
    for (i = 1; i <= length(text); i++) {
        ch = substr(text, i, 1)
        if (q == "") { if (ch == "\"" || ch == "\047") q = ch; out = out ch }
        else { if (ch == q) { q = ""; out = out ch } else if (ch ~ /[;|&(){}]/) out = out " "; else out = out ch }
    }
    return out
}
# has_build(text): 1 when some command in the text is a build command
function has_build(text,   n, i, c, w, b, k, parts) {
    text = mask(text)
    gsub(/&&|\|\||[;|(){}]/, "\n", text)
    n = split(text, parts, "\n")
    for (i = 1; i <= n; i++) {
        c = trim(parts[i])
        if (c == "") continue
        # strip wrappers
        while (c ~ /^(exec|sudo|nohup|env|time|command|then|do|else|!)[ \t]+/ || c ~ /^[A-Za-z_][A-Za-z0-9_]*=[^ \t]*[ \t]+/) { sub(/^[^ \t]+[ \t]+/, "", c) }
        if (c ~ /^(bash|sh|source|\.)[ \t]+/) { sub(/^[^ \t]+[ \t]+/, "", c); while (c ~ /^-[A-Za-z-]+[ \t]+/) sub(/^[^ \t]+[ \t]+/, "", c) }
        w = c; sub(/[ \t].*$/, "", w)
        if (is_msg_word(w)) continue
        if (c ~ /^(go[ \t]+(build|install)|(npm|yarn|pnpm)[ \t]+(run[ \t]+)?build|(docker|podman)([ \t]+compose)?[ \t]+build|cargo|make|gmake|cmake|ninja|mvn|gradle|gradlew|jekyll[ \t]+build|bundle[ \t]+exec[ \t]+jekyll[ \t]+build)([ \t]|$)/) return 1
        b = w; gsub(/["\047]/, "", b); k = b; sub(/^.*\//, "", k)
        if (substr(b, 1, 1) != "$" && k ~ /^[a-z0-9_.-]*build[a-z0-9_.-]*$/) return 1
        if (k ~ /^[a-z0-9_.-]*build[a-z0-9_.-]*$/ && b ~ /\// ) return 1
    }
    return 0
}
# strip_comment(s): drop an unquoted `#` comment that starts a word (inline comments)
function strip_comment(s,   i, ch, q, out, prev) {
    q = ""; out = ""; prev = " "
    for (i = 1; i <= length(s); i++) {
        ch = substr(s, i, 1)
        if (q == "") { if (ch == "#" && prev ~ /[ \t;]/) break; if (ch == "\"" || ch == "\047") q = ch }
        else if (ch == q) q = ""
        out = out ch; prev = ch
    }
    return out
}
# msg_line(s): the first command of the line is a message / reporting word (echo, printf, log*, ...)
function msg_line(s,   w) {
    w = s; sub(/^[ \t]*(((if|then|else|elif|do|while|until|!)[ \t]+)|[;{(][ \t]*)*/, "", w); sub(/[ \t;].*$/, "", w)
    return is_msg_word(w)
}
# structural freshness: a timestamp comparison or a freshness gate, by construction
function structural_fresh(s) {
    return (s ~ /[ \t](-nt|-ot)[ \t]/ || s ~ /-newer/ || s ~ /find[^|;&]*-(mmin|mtime|cmin)/ || s ~ /stat[^|;&]*(%Y|%y|%Z)/ \
         || s ~ /(ensure|prepare|assert|check)_fresh/)
}
# stampish(s): names a build stamp (a `stamp` word not glued to a preceding letter, so a wall-clock
# `timestamp`/`TIMESTAMP` is not one; `buildstamp` is), reads HEAD, or references a variable assigned from one
function stampish(s,   v) {
    if (tolower(s) ~ /(^|[^a-z]|build)stamp/ || s ~ /rev-parse[ \t]+(-[-A-Za-z=0-9]*[ \t]+)*HEAD/) return 1
    for (v in marked) if (s ~ ("[$][{]?" v "([^A-Za-z0-9_]|$)")) return 1
    return 0
}
# compared(s): the line COMPARES operands (test/[ ]/[[ ]] with an operator, or cmp/diff/grep -q)
function compared(s) {
    return ((s ~ /\[/ || s ~ /(^|[ \t;!(])test[ \t]/) && s ~ /[ \t](=|==|!=|-eq|-ne|-lt|-gt|-le|-ge)[ \t]/) \
        || s ~ /(^|[ \t;|&(!])(cmp|diff)[ \t]/ || s ~ /(^|[ \t;|&(!])grep[ \t]+-[A-Za-z]*[qxF]/
}
# file_fresh(): 1 when some executable, non-message line carries a freshness guard.  A `stamp` word or
# `git rev-parse HEAD` counts ONLY as a compared operand (directly, or through a variable assigned from it):
# `local timestamp=$(date ...)` in a log helper, or HEAD read to label a binary, is not a guard.
function file_fresh(   i, k, s, name, rhs) {
    split("", marked)
    for (i = 1; i <= n; i++) { C[i] = iscomment[i] ? "" : strip_comment(L[i]); if (C[i] != "" && msg_line(C[i])) C[i] = "" }
    for (k = 1; k <= 2; k++)
        for (i = 1; i <= n; i++) {
            s = C[i]
            if (!match(s, /^[ \t]*((local|export|readonly|declare|typeset)[ \t]+(-[A-Za-z]+[ \t]+)*)?[A-Za-z_][A-Za-z0-9_]*=/)) continue
            name = substr(s, 1, RLENGTH - 1); sub(/^.*[ \t]/, "", name); rhs = substr(s, RLENGTH + 1)
            if (stampish(rhs)) marked[name] = 1
        }
    for (i = 1; i <= n; i++) {
        s = C[i]; if (s == "") continue
        if (structural_fresh(s)) return 1
        if (compared(s) && stampish(s)) return 1
    }
    return 0
}
function process(f,   i, j, s, m, neg, rest, action, depth, mode, hit, lim, t, iff, cond, form, blk, part, inl) {
    if (file_fresh()) print "F\t" f
    for (i = 1; i <= n; i++) {
        if (iscomment[i]) continue
        s = L[i]
        iff = (s ~ /^[ \t]*if[ \t]+/)
        t = s; sub(/^[ \t]*if[ \t]+/, "", t); sub(/^[ \t]+/, "", t)
        if (!match(t, /^(\[\[?|test)[ \t]+(![ \t]+)?-[xfeXs][ \t]+("[^"]*"|\047[^\047]*\047|[^ \t]+)([ \t]*\]\]?)?/)) continue
        m = substr(t, 1, RLENGTH); rest = trim(substr(t, RLENGTH + 1))
        neg = (m ~ /^(\[\[?|test)[ \t]+![ \t]/)
        hit = 0
        if (iff) {
            # then-branch (negated test) or else-branch (positive test)
            depth = 1; mode = "then"; part = ""
            inl = rest; if (inl ~ /then/) { sub(/^.*then/, "", inl) } else inl = ""
            if (inl ~ /;[ \t]*else/) { part = part " " (neg ? substr(inl, 1, index(inl, "else") - 1) : substr(inl, index(inl, "else") + 4)) ; hit = has_build(part) }
            else if (neg) part = inl
            lim = i + 25; if (lim > n) lim = n
            for (j = i + 1; j <= lim && !hit; j++) {
                if (iscomment[j]) continue
                if (L[j] ~ /^[ \t]*if[ \t]/) depth++
                if (L[j] ~ /^[ \t]*fi([ \t;]|$)/) { depth--; if (depth == 0) break }
                if (depth == 1 && L[j] ~ /^[ \t]*(else|elif)([ \t;]|$)/) { mode = "else"; continue }
                if (depth == 1 && ((neg && mode == "then") || (!neg && mode == "else"))) part = part "\n" L[j]
            }
            if (!hit) hit = has_build(part)
            form = neg ? "if-negated-test-then-build" : "if-test-else-build"
            # the build sits IN THE CONDITION (fix round F2, review rev-base-A):
            # `if [ ! -x B ] && ! build_tool; then <refusal>` or `if [ -x B ] || make; then`
            cond = rest; if (match(cond, /;?[ \t]*then([ \t;]|$)/)) cond = substr(cond, 1, RSTART - 1)
            if (!hit && ((neg && cond ~ /^&&/) || (!neg && cond ~ /^\|\|/)) && has_build(substr(cond, 3))) {
                hit = 1; form = neg ? "if-negated-test-and-build-in-condition" : "if-test-or-build-in-condition"
            }
        } else {
            action = ""
            if (!neg && rest ~ /^\|\|/) { action = substr(rest, 3); form = "test-or-build" }
            else if (neg && rest ~ /^&&/) { action = substr(rest, 3); form = "negated-test-and-build" }
            else continue
            action = trim(action)
            if (action ~ /^\{/ && action !~ /\}[ \t]*$/) {
                blk = action; lim = i + 12; if (lim > n) lim = n
                for (j = i + 1; j <= lim; j++) { if (iscomment[j]) continue; if (L[j] ~ /^[ \t]*\}/) break; blk = blk "\n" L[j] }
                action = blk; form = "test-or-build-group"
            }
            hit = has_build(action)
        }
        if (hit) print "G\t" f "\t" line0[i] "\t" form
    }
}
function flush(   ) { if (curfile != "") process(curfile); n = 0 }
FNR == 1 { flush(); curfile = FILENAME; n = 0; cont = 0 }
{
    raw = $0
    if (cont) { L[n] = L[n] " " raw } else { n++; L[n] = raw; line0[n] = FNR; iscomment[n] = (raw ~ /^[ \t]*#/) }
    cont = (raw ~ /\\[ \t]*$/ && !iscomment[n])
    if (cont) sub(/\\[ \t]*$/, "", L[n])
}
END { flush() }
'

usage() { sed -n '2,/^# USAGE/p' "$SELF" | sed 's/^# \{0,1\}//'; }

cni() { printf 'COULD-NOT-INSPECT %s %s\n' "$1" "$2"; }

# third_party_prefixes <base>: the excluded third-party trees, DERIVED from helix-deps.yaml's own
# `#   <path> -> <url>` exclusion comment block (the shared exclusion ruling of feature 010, the same
# derivation unregistered-scripts uses); one path prefix per line.  The vendored spec-kit tree
# `.specify/` (any depth) is excluded separately by the same ruling.
third_party_prefixes() {
    [ -f "$1/helix-deps.yaml" ] || return 0
    LC_ALL=C sed -n 's/^#[[:space:]]\{1,\}\([A-Za-z0-9._][A-Za-z0-9._/-]*\)[[:space:]]\{1,\}->[[:space:]].*/\1\//p' "$1/helix-deps.yaml"
}

# scan <base dir> <mode: live|corpus>  -> fills SCAN_G (guard records), SCAN_F, POP (encoded tokens),
# NONREG (raw paths of candidates that are not regular files: never read)
# Exit 0 ok, 2 cannot enumerate.
scan() {
    local base=$1 mode=$2 tmp p
    tmp=$(mktemp -d "${TMPDIR:-/tmp}/zg-bim.XXXXXX") || return 2
    # shellcheck disable=SC2064
    trap "rm -rf '$tmp'" RETURN
    if [ "$mode" = corpus ]; then
        ( cd "$base" && find . ! -type d -print0 ) 2>"$tmp/err" | sed -z 's|^\./||' >"$tmp/all.z" || return 2
    else
        command -v git >/dev/null 2>&1 || { cni git "git is not on PATH"; return 2; }
        git -C "$base" ls-files -z --recurse-submodules >"$tmp/all.z" 2>"$tmp/err" || { cni ls-files "git ls-files --recurse-submodules failed at the root"; return 2; }
        { printf '%s\n' "$FIXPFX"; third_party_prefixes "$base"; } >"$tmp/excl"
        awk 'BEGIN { RS = ORS = "\0" }
             NR == FNR { if ($0 != "") ex[++ne] = $0; next }
             { for (i = 1; i <= ne; i++) if (index($0, ex[i]) == 1) next
               if ($0 ~ /(^|\/)\.specify\//) next
               print }' RS='\n' "$tmp/excl" RS='\0' "$tmp/all.z" >"$tmp/all2.z" || { cni exclusion "the third-party exclusion filter failed"; return 2; }
        mv "$tmp/all2.z" "$tmp/all.z"
    fi
    # names with a tab or newline cannot be carried through the record format
    BADNAMES=$(awk 'BEGIN { RS = "\0" } /[\t\n]/ { c++ } END { print c + 0 }' "$tmp/all.z")
    # candidate scan set: live = *.sh|*.bash or start-named; corpus = everything
    if [ "$mode" = corpus ]; then
        awk 'BEGIN { RS = ORS = "\0" } !/[\t\n]/' "$tmp/all.z" >"$tmp/cand.z"
    else
        awk 'BEGIN { RS = ORS = "\0" } !/[\t\n]/ && (/\.(sh|bash)$/ || /(^|\/)(re)?start[^\/]*$/)' "$tmp/all.z" >"$tmp/cand.z"
    fi
    # a candidate that is a symlink, FIFO, device, socket or absent is NEVER read (a FIFO would block the
    # reader forever; a symlink can leave the tree): it is reported COULD-NOT-INSPECT by the caller
    : >"$tmp/scan.z"; NONREG=""
    while IFS= read -r -d '' p; do
        if [ -f "$base/$p" ] && [ ! -L "$base/$p" ]; then printf '%s\0' "$p" >>"$tmp/scan.z"; else NONREG+="$p"$'\n'; fi
    done <"$tmp/cand.z"
    : >"$tmp/rec"
    if [ -s "$tmp/scan.z" ]; then
        ( cd "$base" && xargs -0 -a "$tmp/scan.z" awk "$DETECTOR" ) >"$tmp/rec" 2>"$tmp/awkerr" || { cni awk "the detector failed: $(head -c 200 "$tmp/awkerr" | tr -c '[:print:]' ' ')"; return 2; }
        if [ -s "$tmp/awkerr" ]; then cni awk "the detector could not read a file: $(head -c 200 "$tmp/awkerr" | tr -c '[:print:]' ' ')"; return 2; fi
    fi
    SCAN_G=$(awk -F'\t' '$1 == "G"' "$tmp/rec" | LC_ALL=C sort -t "$(printf '\t')" -k2,2 -k3,3n)
    SCAN_F=$(awk -F'\t' '$1 == "F" { print $2 }' "$tmp/rec" | LC_ALL=C sort -u)
    # population = start-named files (live) + files with a guarded build; corpus: every file
    if [ "$mode" = corpus ]; then
        POP=$(awk 'BEGIN { RS = ORS = "\0" } !/[\t\n]/' "$tmp/all.z" | zg_pct_encode_z | awk 'NF' | LC_ALL=C sort -u)
    else
        {
            awk 'BEGIN { RS = "\0" } !/[\t\n]/ && /(^|\/)(re)?start[^\/]*\.sh$/ { print }' "$tmp/all.z"
            awk -F'\t' '$1 == "G" { print $2 }' "$tmp/rec"
        } | LC_ALL=C sort -u >"$tmp/popraw"
        POP=$(tr '\n' '\0' <"$tmp/popraw" | zg_pct_encode_z | awk 'NF' | LC_ALL=C sort -u)
    fi
    return 0
}

# severity_of <path>: consequence-based.  A start/restart path runs the stale binary as the SERVICE (high);
# a test harness or fixture only tests a stale build (low); any other script (gate, deploy, tool) medium.
severity_of() {
    case "/$1" in
        */start*|*/restart*) case "${1##*/}" in start*|restart*) echo high; return ;; esac ;;
    esac
    case "/$1" in
        */_tests/*|*/tests/*|*/test/*|*/testdata/*|*/fixtures/*|*/challenges/*|*/examples/*|*/example/*) echo low; return ;;
    esac
    echo medium
}

# tail_empty: the INSPECTED / POPULATION-SHA pair every rc carries, for a run that walked nothing
tail_empty() { echo "INSPECTED 0"; echo "POPULATION-SHA $(printf '' | sha256sum | cut -d' ' -f1)"; }

run_class() { # run_class <root> <corpus-or-empty>
    local root=$1 corpus=$2 base mode n nread found=0 undet=0 path lnum form loc fresh sev why p tok
    if [ ! -d "$root" ]; then cni root "--root is not a directory"; tail_empty; return 2; fi
    if [ -n "$corpus" ]; then
        [ -d "$corpus" ] || { cni corpus "--corpus is not a directory"; tail_empty; return 2; }
        base=$corpus; mode=corpus
    else
        base=$root; mode=live
        git -C "$root" rev-parse --git-dir >/dev/null 2>&1 || { cni root "--root is not a git checkout"; tail_empty; return 2; }
    fi
    BADNAMES=0; SCAN_G=""; SCAN_F=""; POP=""; NONREG=""
    scan "$base" "$mode" || { tail_empty; return 2; }
    n=0; [ -n "$POP" ] && n=$(printf '%s\n' "$POP" | awk 'END { print NR }')
    nread=$n
    if [ "$BADNAMES" -gt 0 ]; then cni names "$BADNAMES tracked file name(s) contain a tab or newline and were not scanned"; undet=1; fi
    while IFS= read -r p; do
        [ -n "$p" ] || continue
        tok=$(zg_pct_encode "$p")
        cni "$tok" "not a regular file on disk (symlink, FIFO, device, socket or absent): never read, so its start/build guard is unknown"
        undet=1
        case $'\n'"$POP"$'\n' in *$'\n'"$tok"$'\n'*) nread=$((nread - 1)) ;; esac
    done <<<"$NONREG"
    if [ "$n" -eq 0 ]; then
        cni population "the population is empty: no start-named file and no guarded build was found, which is a failure to inspect and never a clean result"
        tail_empty
        return 2
    fi
    while IFS=$'\t' read -r _ path lnum form; do
        [ -n "$path" ] || continue
        fresh=0; if [ -n "$SCAN_F" ]; then case $'\n'"$SCAN_F"$'\n' in *$'\n'"$path"$'\n'*) fresh=1 ;; esac; fi
        [ "$fresh" -eq 1 ] && continue
        loc=$(zg_pct_encode "$path"):$lnum
        sev=$(severity_of "$path")
        case $sev in
            high) why="so a restart runs a stale binary" ;;
            low)  why="so this test harness exercises a stale build after a source change" ;;
            *)    why="so a run after a source change uses a stale build" ;;
        esac
        printf 'FINDING %s %s build-freshness %s builds only when the artefact is absent (%s) with no freshness guard, %s %s\n' "$CLASS_ID" "$sev" "$loc" "$form" "$why" "$loc"
        found=$((found + 1))
    done <<<"$SCAN_G"
    echo "INSPECTED $nread"
    echo "POPULATION-SHA $(printf '%s\n' "$POP" | sha256sum | cut -d' ' -f1)"
    if [ "$found" -gt 0 ]; then return 1; fi
    if [ "$undet" -eq 1 ]; then return 2; fi
    return 0
}

emit_population() { # emit_population <root> <corpus-or-empty>
    local root=$1 corpus=$2 base mode
    [ -d "$root" ] || { cni root "--root is not a directory" >&2; return 2; }
    if [ -n "$corpus" ]; then [ -d "$corpus" ] || { cni corpus "--corpus is not a directory" >&2; return 2; }; base=$corpus; mode=corpus
    else base=$root; mode=live; git -C "$root" rev-parse --git-dir >/dev/null 2>&1 || { cni root "--root is not a git checkout" >&2; return 2; }; fi
    BADNAMES=0; SCAN_G=""; SCAN_F=""; POP=""; NONREG=""
    scan "$base" "$mode" >&2 || return 2
    [ -n "$POP" ] && printf '%s\n' "$POP"
    return 0
}

# ---------------------------------------------------------------------------
# --prove-failure: paired proof on THROWAWAY copies
# ---------------------------------------------------------------------------
prove_failure() {
    local T pass=0 fail=0 rc out fp1 fp2 corpus
    T=$(mktemp -d "${TMPDIR:-/tmp}/zg-bim-proof.XXXXXX") || { echo "prove-failure: cannot create a scratch directory"; return 2; }
    # shellcheck disable=SC2064
    trap "rm -rf '$T'" RETURN
    corpus="$SELF_DIR/../_tests/fixtures/zero-gap/$CLASS_ID"
    ok()  { pass=$((pass + 1)); printf 'PASS  %s\n' "$1"; }
    bad() { fail=$((fail + 1)); printf 'FAIL  %s\n' "$1"; }
    mkrepo() { rm -rf "$T/$1"; mkdir -p "$T/$1/scripts"; git -C "$T/$1" init -q 2>/dev/null; }
    fingerprint() { ( cd "$1" && find . -path ./.git -prune -o -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum; ) | sha256sum; }

    # M0 control: a clean start script (unconditional build) => rc 0 with a non-empty population
    mkrepo ctl
    printf '#!/usr/bin/env bash\nbash ./build.sh\nexec ./bin/server\n' >"$T/ctl/scripts/start.sh"
    git -C "$T/ctl" add -A
    out=$(bash "$SELF" --root "$T/ctl"); rc=$?
    if [ $rc -eq 0 ] && grep -q '^INSPECTED 1$' <<<"$out"; then ok "M0 control: unconditional build is clean (rc 0, INSPECTED 1)"; else bad "M0 control rc=$rc: $out"; fi

    # M1 planted defect: existence-only guard => rc 1 with the exact location
    mkrepo pl
    printf '#!/usr/bin/env bash\nBIN=./bin/server\n[ -x "$BIN" ] || bash ./build.sh\nexec "$BIN"\n' >"$T/pl/scripts/start.sh"
    git -C "$T/pl" add -A
    out=$(bash "$SELF" --root "$T/pl"); rc=$?
    if [ $rc -eq 1 ] && grep -q '^FINDING build-if-missing high build-freshness scripts/start.sh:3 ' <<<"$out"; then ok "M1 planted existence-only guard => FINDING scripts/start.sh:3, rc 1"; else bad "M1 rc=$rc: $out"; fi

    # M2 mutation of a clean file: remove its freshness term => finding
    mkrepo mu
    cp "$corpus/clean/c2_newer_compare.sh" "$T/mu/scripts/start.sh"
    git -C "$T/mu" add -A
    out=$(bash "$SELF" --root "$T/mu"); rc=$?
    if [ $rc -eq 0 ]; then ok "M2a control: existence AND -newer comparison is clean"; else bad "M2a rc=$rc: $out"; fi
    sed -i 's/ || \[ -n "\$(find src -newer "\$BIN" -print -quit)" \]//' "$T/mu/scripts/start.sh"
    out=$(bash "$SELF" --root "$T/mu"); rc=$?
    if [ $rc -eq 1 ]; then ok "M2b mutation: freshness term removed => FINDING, rc 1"; else bad "M2b rc=$rc: $out"; fi

    # M3 empty / absent population => rc 2, never clean
    mkrepo em
    printf 'just a note\n' >"$T/em/README.txt"; git -C "$T/em" add -A
    out=$(bash "$SELF" --root "$T/em"); rc=$?
    if [ $rc -eq 2 ] && grep -q '^COULD-NOT-INSPECT population ' <<<"$out"; then ok "M3 empty population => COULD-NOT-INSPECT, rc 2"; else bad "M3 rc=$rc: $out"; fi
    out=$(bash "$SELF" --root /nonexistent); rc=$?
    if [ $rc -eq 2 ]; then ok "M4 --root /nonexistent => rc 2"; else bad "M4 rc=$rc: $out"; fi

    # M5 a broken / missing tool => rc 2 (no git and no awk on PATH)
    out=$(PATH=/nonexistent "$BASH" "$SELF" --root "$T/pl" 2>/dev/null); rc=$?
    if [ $rc -eq 2 ]; then ok "M5 tools missing from PATH => rc 2"; else bad "M5 rc=$rc: $out"; fi

    # M6 the shipped corpus: every planted row reported, nothing on clean
    if [ -d "$corpus/planted" ] && [ -d "$corpus/clean" ]; then
        out=$(bash "$SELF" --root "$T/pl" --corpus "$corpus/planted"); rc=$?
        miss=0
        while IFS=$'\t' read -r loc _; do
            case $loc in ''|'#'*) continue ;; esac
            grep -q " $loc " <<<"$out" || { miss=$((miss + 1)); echo "  planted location not reported: $loc"; }
        done <"$corpus/expect.tsv"
        if [ $rc -eq 1 ] && [ $miss -eq 0 ]; then ok "M6a planted corpus: every expect.tsv row reported"; else bad "M6a rc=$rc missed=$miss"; fi
        # exact recall: the reported location set EQUALS the expect.tsv set (no extra, no missing)
        if [ "$(awk '$1 == "FINDING" { print $5 }' <<<"$out" | LC_ALL=C sort -u)" = "$(awk -F'\t' '$1 !~ /^(#|$)/ { print $1 }' "$corpus/expect.tsv" | LC_ALL=C sort -u)" ]; then ok "M6c planted corpus: reported set equals expect.tsv exactly"; else bad "M6c reported set differs from expect.tsv"; fi
        out=$(bash "$SELF" --root "$T/pl" --corpus "$corpus/clean"); rc=$?
        if [ $rc -eq 0 ]; then ok "M6b clean corpus: no finding"; else bad "M6b rc=$rc: $out"; fi
    else
        bad "M6 corpus directories are missing at $corpus"
    fi

    # M7 the swept tree is byte-identical around a run, and emit-population equals the walked set
    fp1=$(fingerprint "$T/pl"); out=$(bash "$SELF" --root "$T/pl"); bash "$SELF" --root "$T/pl" --emit-population >"$T/emit.txt"; fp2=$(fingerprint "$T/pl")
    if [ "$fp1" = "$fp2" ]; then ok "M7a tree byte-identical before/after"; else bad "M7a tree changed"; fi
    if [ "$(sha256sum <"$T/emit.txt" | cut -d' ' -f1)" = "$(sed -n 's/^POPULATION-SHA //p' <<<"$out")" ]; then ok "M7b POPULATION-SHA equals the emitted set"; else bad "M7b population sha differs from --emit-population"; fi

    # M8 forms the detector must not miss: negated-and, group, if/else, function, comment-only freshness
    for f in p2_nested_if p3_function p4_test_form p5_negated_and p6_block_or p7_comment_freshness p8_if_else p9_env_prefix p10_timestamp_log p11_stamp_in_message p12_revparse_uncompared p13_if_condition_build p14_if_condition_or_build; do
        rm -f "$T/pl/scripts/"*; cp "$corpus/planted/$f.sh" "$T/pl/scripts/start.sh"; git -C "$T/pl" add -A
        out=$(bash "$SELF" --root "$T/pl"); rc=$?
        if [ $rc -eq 1 ]; then ok "M8 form $f => FINDING"; else bad "M8 form $f rc=$rc: $out"; fi
    done

    # M9 a tracked candidate that is a FIFO on disk: never read (no hang), COULD-NOT-INSPECT, rc 2, no temp left
    mkrepo fi
    printf '#!/usr/bin/env bash\nbash ./build.sh\n' >"$T/fi/scripts/start.sh"
    printf 'x\n' >"$T/fi/scripts/restart.sh"; git -C "$T/fi" add -A; rm -f "$T/fi/scripts/restart.sh"; mkfifo "$T/fi/scripts/restart.sh"
    local before after
    before=$(find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'zg-bim.*' 2>/dev/null | LC_ALL=C sort)
    out=$(timeout -k 5 30 bash "$SELF" --root "$T/fi"); rc=$?
    after=$(find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'zg-bim.*' 2>/dev/null | LC_ALL=C sort)
    if [ $rc -eq 2 ] && grep -q '^COULD-NOT-INSPECT scripts/restart.sh ' <<<"$out" && grep -q '^INSPECTED ' <<<"$out" && [ "$before" = "$after" ]; then ok "M9 tracked FIFO => COULD-NOT-INSPECT, rc 2, no hang, no temp left"; else bad "M9 rc=$rc: $out"; fi
    # M10 a tracked symlink candidate (points outside the tree) => COULD-NOT-INSPECT, never followed
    mkrepo sl
    printf '#!/usr/bin/env bash\nbash ./build.sh\n' >"$T/sl/scripts/start.sh"
    printf '[ -x ./b ] || bash ./build.sh\n' >"$T/outside.sh"; ln -s "$T/outside.sh" "$T/sl/scripts/restart.sh"; git -C "$T/sl" add -A
    out=$(timeout -k 5 30 bash "$SELF" --root "$T/sl"); rc=$?
    if [ $rc -eq 2 ] && grep -q '^COULD-NOT-INSPECT scripts/restart.sh ' <<<"$out" && ! grep -q '^FINDING' <<<"$out"; then ok "M10 tracked symlink => COULD-NOT-INSPECT, not followed, rc 2"; else bad "M10 rc=$rc: $out"; fi

    # M11 third-party trees derived from helix-deps.yaml and the vendored .specify/ tree are excluded
    mkrepo tp
    mkdir -p "$T/tp/vendor/up" "$T/tp/.specify/scripts/bash"
    printf '#!/usr/bin/env bash\nbash ./build.sh\n' >"$T/tp/scripts/start.sh"
    printf '[ -x ./b ] || bash ./build.sh\n' >"$T/tp/vendor/up/start.sh"
    printf '[ -x ./b ] || bash ./build.sh\n' >"$T/tp/.specify/scripts/bash/start.sh"
    printf 'deps: []\n#   vendor/up -> git@example.invalid:t/up.git\n' >"$T/tp/helix-deps.yaml"
    git -C "$T/tp" add -A
    out=$(bash "$SELF" --root "$T/tp"); rc=$?
    if [ $rc -eq 0 ] && grep -q '^INSPECTED 1$' <<<"$out"; then ok "M11a third-party (helix-deps.yaml) and .specify/ excluded => rc 0, INSPECTED 1"; else bad "M11a rc=$rc: $out"; fi
    printf 'deps: []\n' >"$T/tp/helix-deps.yaml"; git -C "$T/tp" add -A
    out=$(bash "$SELF" --root "$T/tp"); rc=$?
    if [ $rc -eq 1 ] && grep -q ' vendor/up/start.sh:1 ' <<<"$out"; then ok "M11b same tree without the helix-deps.yaml row => vendor/up reported (exclusion is derived, not hard-coded)"; else bad "M11b rc=$rc: $out"; fi

    # M12 severity by consequence: start/restart path high, other script medium, test/fixture script low
    mkrepo sv
    mkdir -p "$T/sv/_tests"
    printf '[ -x ./b ] || bash ./build.sh\n' >"$T/sv/scripts/restart-api.sh"
    printf '[ -x ./b ] || bash ./build.sh\n' >"$T/sv/scripts/verify-gate.sh"
    printf '[ -x ./b ] || bash ./build.sh\n' >"$T/sv/_tests/self-validate.sh"
    git -C "$T/sv" add -A
    out=$(bash "$SELF" --root "$T/sv"); rc=$?
    if [ $rc -eq 1 ] && grep -q '^FINDING build-if-missing high build-freshness scripts/restart-api.sh:1 ' <<<"$out" \
        && grep -q '^FINDING build-if-missing medium build-freshness scripts/verify-gate.sh:1 ' <<<"$out" \
        && grep -q '^FINDING build-if-missing low build-freshness _tests/self-validate.sh:1 ' <<<"$out"; then ok "M12 severity: restart high, gate medium, test harness low"; else bad "M12 rc=$rc: $out"; fi

    printf 'prove-failure: %d passed, %d failed\n' "$pass" "$fail"
    [ "$fail" -eq 0 ] && return 0
    return 1
}

ROOT="" CORPUS="" EMIT=0 PROVE=0
while [ $# -gt 0 ]; do
    case "$1" in
        --root) ROOT="${2:-}"; shift 2 ;;
        --corpus) CORPUS="${2:-}"; shift 2 ;;
        --emit-population) EMIT=1; shift ;;
        --prove-failure) PROVE=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) cni args "unknown argument: $(zg_pct_encode "$1")"; tail_empty; exit 2 ;;
    esac
done

case "$PROVE" in
    1) prove_failure; exit $? ;;
esac
if [ -z "$ROOT" ]; then cni root "--root <abs dir> is required"; tail_empty; exit 2; fi
if [ "$EMIT" -eq 1 ]; then emit_population "$ROOT" "$CORPUS"; exit $?; fi
run_class "$ROOT" "$CORPUS"
exit $?
