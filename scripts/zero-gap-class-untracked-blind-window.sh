#!/usr/bin/env bash
# zero-gap-class-untracked-blind-window.sh — sweep class `untracked-blind-window`
# (feature 010, task T029; class contract: docs/zero-gap/README.md).
#
# WHAT IT DETECTS
#   A registered check or gate whose enumeration of "the repository" reads
#   `git ls-files` (tracked files only) and neither (a) also reads the
#   untracked-not-ignored files (`--others`, `ls-files -o`, `status --porcelain`)
#   nor (b) states the limit in a comment (wording: untracked / tracked files
#   only / only tracked). Such a gate reports green while an untracked file on
#   disk carries the defect it exists to find; the gap lasts from the write of
#   the file to its `git add` (the blind window the content-boundary gate found
#   in itself). One FINDING per script, located at the first ls-files
#   enumeration line: `<entry point>:<line>`, severity medium, category
#   false-evidence.
#
# POPULATION AND WHY
#   Live: every entry point named in column 3 of a `check` or `debt` row of
#   scripts/check-registry.tsv, when that entry point is a regular file at
#   --root and is not under _tests/fixtures/zero-gap/. The registry is the
#   repository's own list of "every check", so the population is derived from a
#   named tracked source and never from a hand list. The pre-push gates are
#   covered only through the registered entry points (scripts/pre-push-gates.sh
#   is one); a gate command written inline inside that script is not a separate
#   item (controller ruling: the tsv row text says registered entry points).
#   A registered entry point that is not a root-relative path (`..`, absolute,
#   `./`, `//`) is COULD-NOT-INSPECT at `scripts/check-registry.tsv:<line>`;
#   one that exists but is not a regular file (symlink, FIFO, directory,
#   device) is COULD-NOT-INSPECT by its path and is never read; an absent one
#   is outside the population (a missing registered file is another class's
#   concern). Corpus mode (--corpus): every regular file under the corpus
#   directory, locations relative to it.
#
# ENUMERATION CLASSIFICATION (per non-comment line naming ls-files; a line
#   ending in a backslash is joined to the next line first)
#   - skipped FIRST, before any other rule: echo/printf/*say/*note/*warn/die/log
#     lines (text that mentions the idiom, including a message naming --others,
#     which is therefore never a covering read).
#   - skipped, not a content enumeration: ls-files with -s/--stage,
#     --error-unmatch, -u, -m, -d (git state); `[ -n|-z "$(... ls-files ...)" ]`
#     (existence test); `var="$(... ls-files ... | grep ...)"` (name probe:
#     names are filtered, no file is opened by this line). A bare assignment
#     `var="$(... ls-files ...)"` is a content enumeration only when `var` is
#     later iterated (`for x in $var`, `<<<"$var"`, `$var | while|xargs`), and
#     always when its own substitution pipes the list into xargs or while
#     (`x=$(git ls-files | xargs stat)` opens every file on that line).
#   - covering: `--others`, a short-option cluster holding o after ls-files
#     (`-o`, `-co`, `-oc`, ...), `status --porcelain`.
#   - everything else is a content enumeration.
#
# EXIT CODES
#   0 clean: the full non-empty population was inspected and holds.
#   1 at least one FINDING.
#   2 could not determine: bad --root, missing registry, missing tool, empty
#     population, unsafe entry-point path. Never a pass.
#
# MEASURED (live tree, 2026-09-26, review fix round; three runs byte-identical,
#   about 0.5 s): 58 entry points, 4 FINDINGs, all hand-read. 3 are real
#   tracked-only content audits with no stated limit (audit-environment-
#   assumptions.sh:836, audit-hardcoded-paths.sh:433, verify-shell-
#   continuations.sh:106); 1 is a false positive (verify-provider-ci.sh:1134: a
#   while-read loop that only CLASSIFIES names by regex and opens no file — an
#   untracked CI file triggers no provider run). Precision 3/4. Earlier the same
#   day zero-gap-class-live-vs-source.sh (cleared by stating its real
#   tracked-only limit in its header) and zero-gap-class-unregistered-scripts.sh
#   were hits; the latter dropped out when a comment of its own came to use the
#   word "untracked" — the documented-limit heuristic below, a known false-
#   negative family, not a verified fix.
#
# WHAT IT DOES NOT SEE
#   - Only registered entry points. A gate that is not registered, or a helper
#     library sourced by an entry point, is outside the population (R5 of
#     scripts/verify-check-registry.sh guards registration).
#   - Line-level text analysis, not shell parsing: a heredoc body naming
#     ls-files counts as code; an enumeration built through a variable
#     (cmd="git ls-files"; $cmd) is not recognised; a comment that merely uses
#     the word "untracked" counts as a documented limit.
#   - Whether a covering read really reaches the same file set as the tracked
#     read, or whether the untracked read is reachable at run time.
#   - Python/Go/Node gates: only shell text is read for the git idiom.
#   - A loop over the list that only filters NAMES (regex, case) without opening
#     any file is still reported (the false-positive family measured above); a
#     names-only command-substitution assignment piped to grep is skipped.
#
# Usage:
#   zero-gap-class-untracked-blind-window.sh --root <abs dir> [--corpus <abs dir>] [--emit-population]
#   zero-gap-class-untracked-blind-window.sh --prove-failure
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

CLASS_ID=untracked-blind-window
SELF=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")
export LC_ALL=C
export PYTHONDONTWRITEBYTECODE=1

# analyze <file>: prints the line number of the first content enumeration when
# the script is blind to untracked files and states no limit; prints nothing
# otherwise.
analyze() {
    awk '
    function flush(line, nr,    l, t) {
        l = line
        if (l ~ /^[ \t]*#/) {
            t = tolower(l)
            if (t ~ /untracked|tracked[ -]+(files[ -]+)?only|only[ -]+tracked/) doc = 1
            return
        }
        # drop a trailing inline comment (a "#" preceded by blank, outside quotes)
        while (match(l, /[ \t]#/)) {
            pre = substr(l, 1, RSTART - 1)
            q1 = gsub(/"/, "&", pre); q2 = gsub(/\047/, "&", pre)
            if (q1 % 2 == 0 && q2 % 2 == 0) { l = pre; break } else break
        }
        for (v in pv) {
            if (l ~ ("<<<[ \t]*\"?\\$\\{?" v "([^A-Za-z0-9_]|$)") ||
                l ~ ("for[ \t]+[A-Za-z_][A-Za-z0-9_]*[ \t]+in[^;]*\\$\\{?" v "([^A-Za-z0-9_]|$)") ||
                l ~ ("\\$\\{?" v "\\}?\"?[ \t]*\\|[ \t]*(while|xargs)") ||
                l ~ ("xargs[^|]*\\$\\{?" v "([^A-Za-z0-9_]|$)")) {
                if (first == 0 || pv[v] < first) first = pv[v]
                delete pv[v]
            }
        }
        # a message line (echo/printf/log/...) is text, not a read: it neither covers nor enumerates
        if (l ~ /^[ \t]*(echo|printf|die|log|[A-Za-z_]*say|[A-Za-z_]*note|[A-Za-z_]*warn)([ \t]|$)/) return
        # covering read: --others, a short-option cluster holding o (-o, -co, -oc ...), status --porcelain
        if (l ~ /--others|ls-files[^|;]*[ \t]-[A-Za-z]*o[A-Za-z]*([ \t]|$)|status[ \t]+--porcelain/) { others = 1; return }
        if (l !~ /ls-files/) return
        if (l ~ /ls-files[^|;]*[ \t](-s|-u|-m|-d|--stage|--unmerged|--modified|--deleted|--error-unmatch)([ \t]|$)/) return
        if (l ~ /-[nz][ \t]+"?\$\(.*ls-files/) return
        # an assignment whose substitution pipes the list into xargs / while opens the files right there
        if (l ~ /^[ \t]*(local[ \t]+)?[A-Za-z_][A-Za-z0-9_]*="?\$\(.*ls-files[^)]*\|[ \t]*(xargs|while)/) { if (first == 0) first = nr; return }
        if (l ~ /^[ \t]*(local[ \t]+)?[A-Za-z_][A-Za-z0-9_]*="?\$\(.*ls-files[^)]*\|[ \t]*grep/) return
        if (match(l, /^[ \t]*(local[ \t]+)?[A-Za-z_][A-Za-z0-9_]*=/)) {
            a = substr(l, RSTART, RLENGTH); sub(/^[ \t]*(local[ \t]+)?/, "", a); sub(/=$/, "", a)
            if (!(a in pv)) pv[a] = nr
            return
        }
        if (first == 0) first = nr
    }
    {
        if (buf != "") { buf = buf " " $0 } else { buf = $0; start = NR }
        if (buf ~ /\\[ \t]*$/ && buf !~ /^[ \t]*#/) { sub(/\\[ \t]*$/, "", buf); next }
        flush(buf, start); buf = ""
    }
    END {
        if (buf != "") flush(buf, start)
        if (first > 0 && !others && !doc) print first
    }' "$1"
}

decode() { printf '%b' "$(printf '%s' "$1" | sed 's/%\([0-9A-F][0-9A-F]\)/\\x\1/g')"; }

need_tools() {
    local t
    for t in awk sed sort od tr sha256sum cut find grep mktemp; do
        command -v "$t" >/dev/null 2>&1 || { echo "COULD-NOT-INSPECT tool:$t required tool is not on PATH"; return 1; }
    done
    return 0
}

# live_raw_items -> NUL-separated entry-point paths of the registry, unsorted.
# On stderr: `unsafe<TAB><registry line>` for an entry point that is not a root-relative path (it is
# reported by its REGISTRY LINE, never as a token: `..` cannot be a location), and `nonreg<TAB><path>`
# for one that exists but is not a regular file (symlink, FIFO, directory, device): never read.
live_raw_items() {
    local reg="$ROOT/scripts/check-registry.tsv" n ep
    awk -F'\t' '($1 == "check" || $1 == "debt") && $3 != "" { print NR "\t" $3 }' "$reg" | while IFS=$'\t' read -r n ep; do
        case "$ep" in
            /*|./*|*/../*|../*|*/..|..|*//*|*/./*|*/.) printf 'unsafe\t%s\n' "$n" >&2; continue ;;
            _tests/fixtures/zero-gap/*) continue ;;
        esac
        if [ -L "$ROOT/$ep" ] || { [ -e "$ROOT/$ep" ] && [ ! -f "$ROOT/$ep" ]; }; then printf 'nonreg\t%s\n' "$ep" >&2; continue; fi
        [ -f "$ROOT/$ep" ] || continue
        printf '%s\0' "$ep"
    done
}

corpus_raw_items() { ( cd "$CORPUS" && find . -type f -print0 ) | sed -z 's|^\./||'; }

# tail_empty: the INSPECTED / POPULATION-SHA pair every rc carries, for a run that walked nothing
tail_empty() { echo "INSPECTED 0"; echo "POPULATION-SHA $(printf '' | sha256sum | cut -d' ' -f1)"; }

run_class() {
    local unsafe tokens tok p n=0 found=0 cni=0 line loc kind
    if [ -z "$ROOT" ] || [ ! -d "$ROOT" ]; then echo "COULD-NOT-INSPECT root --root is not a directory"; tail_empty; return 2; fi
    if [ -n "$CORPUS" ] && [ ! -d "$CORPUS" ]; then echo "COULD-NOT-INSPECT corpus --corpus is not a directory"; tail_empty; return 2; fi
    if [ -z "$CORPUS" ] && [ ! -f "$ROOT/scripts/check-registry.tsv" ]; then
        echo "COULD-NOT-INSPECT scripts/check-registry.tsv the registry that defines the population is absent"; tail_empty; return 2
    fi
    if [ -n "$CORPUS" ]; then base=$CORPUS; else base=$ROOT; fi
    unsafe=$TMPDIR_ZG/unsafe.txt; : >"$unsafe"
    if [ -n "$CORPUS" ]; then tokens=$(corpus_raw_items | zg_pct_encode_z | awk 'NF' | LC_ALL=C sort -u)
    else tokens=$(live_raw_items 2>"$unsafe" | zg_pct_encode_z | awk 'NF' | LC_ALL=C sort -u); fi
    while IFS=$'\t' read -r kind line; do
        [ -n "$line" ] || continue
        case "$kind" in
            unsafe) echo "COULD-NOT-INSPECT scripts/check-registry.tsv:$line the registered entry point on this registry line is not a root-relative path; not read" ;;
            nonreg) echo "COULD-NOT-INSPECT $(zg_pct_encode "$line") the registered entry point is not a regular file (symlink, FIFO, directory or device); never read" ;;
            *) continue ;;
        esac
        cni=$((cni + 1))
    done <"$unsafe"
    if [ -z "$tokens" ]; then
        echo "COULD-NOT-INSPECT population the population is empty; an empty population is not clean"
        cni=$((cni + 1))
    fi
    while IFS= read -r tok; do
        [ -n "$tok" ] || continue
        n=$((n + 1))
        p=$(decode "$tok")
        line=$(analyze "$base/$p") || { echo "COULD-NOT-INSPECT $tok the file could not be read"; cni=$((cni + 1)); continue; }
        if [ -n "$line" ]; then
            loc="$tok:$line"
            echo "FINDING $CLASS_ID medium false-evidence $loc enumerates its subject with git ls-files (tracked files only), never reads untracked-not-ignored files and states no such limit, so a file written before git add is invisible to it $loc"
            found=$((found + 1))
        fi
    done <<<"$tokens"
    echo "INSPECTED $n"
    if [ -n "$tokens" ]; then echo "POPULATION-SHA $(printf '%s\n' "$tokens" | sha256sum | cut -d' ' -f1)"
    else echo "POPULATION-SHA $(printf '' | sha256sum | cut -d' ' -f1)"; fi
    if [ "$found" -gt 0 ]; then return 1; fi
    if [ "$cni" -gt 0 ]; then return 2; fi
    return 0
}

emit_population() {
    if [ -z "$ROOT" ] || [ ! -d "$ROOT" ]; then return 2; fi
    need_tools >/dev/null || return 2
    if [ -n "$CORPUS" ]; then
        [ -d "$CORPUS" ] || return 2
        corpus_raw_items | zg_pct_encode_z | awk 'NF' | LC_ALL=C sort -u
    else
        [ -f "$ROOT/scripts/check-registry.tsv" ] || return 2
        live_raw_items 2>/dev/null | zg_pct_encode_z | awk 'NF' | LC_ALL=C sort -u
    fi
    return 0
}

prove_failure() {
    local rc out fails=0 emptybin fp1 fp2 repo_root
    repo_root=$(cd "$(dirname "$SELF")/.." && pwd)
    PF_T=$(mktemp -d "${TMPDIR:-/tmp}/zg-ubw-proof.XXXXXX") || { echo "COULD-NOT-INSPECT proof mktemp failed"; return 2; }
    trap 'rm -rf "$PF_T"' EXIT
    local T=$PF_T
    ck() { # ck <name> <expected rc> <actual rc> [<must-contain> <output>]
        if [ "$2" = "$3" ] && { [ -z "${4:-}" ] || grep -qF -- "$4" <<<"${5:-}"; }; then echo "PASS $1 (rc $3)"
        else echo "FAIL $1 (want rc $2, got rc $3; must contain '${4:-}')"; fails=$((fails + 1)); fi
    }
    mkroot() { mkdir -p "$1/scripts"; printf '# scratch registry\nscanroot\tscripts\n' >"$1/scripts/check-registry.tsv"; }
    reg() { printf 'check\t%s\t%s\tflag\t--prove-failure\t--root /nonexistent\n' "$2" "$3" >>"$1/scripts/check-registry.tsv"; }
    # --- scratch root: control set (all clean) ---
    local R=$T/r1; mkroot "$R"
    printf '#!/usr/bin/env bash\ngit ls-files\ngit ls-files --others --exclude-standard\n' >"$R/scripts/a.sh"
    printf '#!/usr/bin/env bash\n# scope: tracked files only\ngit ls-files\n' >"$R/scripts/b.sh"
    printf '#!/usr/bin/env bash\ngit ls-files --error-unmatch x >/dev/null\ngit ls-files -s -- y\n' >"$R/scripts/c.sh"
    reg "$R" a scripts/a.sh; reg "$R" b scripts/b.sh; reg "$R" c scripts/c.sh
    out=$(bash "$SELF" --root "$R"); rc=$?; ck "control: covering, documented and state-only scripts are clean" 0 "$rc" "INSPECTED 3" "$out"
    # --- planted: tracked-only, undocumented ---
    printf '#!/usr/bin/env bash\nset -u\ngit ls-files | while read -r f; do grep -n TODO "$f"; done\n' >"$R/scripts/d.sh"; reg "$R" d scripts/d.sh
    out=$(bash "$SELF" --root "$R"); rc=$?; ck "planted: ls-files-only content audit is a finding at its line" 1 "$rc" "scripts/d.sh:3" "$out"
    # --- mutation: the same script reads untracked files too -> must go clean ---
    printf '#!/usr/bin/env bash\nset -u\n{ git ls-files; git ls-files --others --exclude-standard; } | while read -r f; do grep -n TODO "$f"; done\n' >"$R/scripts/d.sh"
    out=$(bash "$SELF" --root "$R"); rc=$?; ck "mutation: adding --others clears the finding" 0 "$rc" "" "$out"
    # --- mutation: the same script states the limit -> must go clean ---
    printf '#!/usr/bin/env bash\n# limit: tracked files only\ngit ls-files | while read -r f; do grep -n TODO "$f"; done\n' >"$R/scripts/d.sh"
    out=$(bash "$SELF" --root "$R"); rc=$?; ck "mutation: a documented limit clears the finding" 0 "$rc" "" "$out"
    # --- continuation-joined --others on the next line is a covering read ---
    printf '#!/usr/bin/env bash\ngit ls-files --cached \\\n  --others --exclude-standard | while read -r f; do grep -n TODO "$f"; done\n' >"$R/scripts/d.sh"
    out=$(bash "$SELF" --root "$R"); rc=$?; ck "control: --others on a continuation line is a covering read" 0 "$rc" "" "$out"
    # --- empty population -> rc 2 ---
    local E=$T/r2; mkroot "$E"
    out=$(bash "$SELF" --root "$E"); rc=$?; ck "empty population is rc 2, never clean" 2 "$rc" "population is empty" "$out"
    # --- absent registry / bad root -> rc 2 ---
    mkdir -p "$T/r3"; out=$(bash "$SELF" --root "$T/r3"); rc=$?; ck "absent registry is rc 2" 2 "$rc" "" "$out"
    out=$(bash "$SELF" --root /nonexistent); rc=$?; ck "--root /nonexistent is rc 2, INSPECTED still printed" 2 "$rc" "INSPECTED 0" "$out"
    # --- broken/missing tool -> rc 2 ---
    emptybin=$T/emptybin; mkdir -p "$emptybin"
    out=$(PATH=$emptybin "$BASH" "$SELF" --root "$R" 2>&1); rc=$?; ck "missing tool is rc 2" 2 "$rc" "COULD-NOT-INSPECT tool:" "$out"
    # --- real blind window: the tracked-only scanner passes green on an untracked planted file ---
    local G=$T/g; mkroot "$G"
    printf '#!/usr/bin/env bash\npat=$(printf "so%%s" mebody)\nif git ls-files | while read -r f; do grep -l "$pat/checkout" "$f"; done | grep -q .; then exit 1; fi\nexit 0\n' >"$G/scripts/scan.sh"
    reg "$G" scan scripts/scan.sh
    ( cd "$G" && git init -q . && git add -A && git -c user.name=zg -c user.email=zg@example.invalid commit -q -m base ) >/dev/null 2>&1
    printf 'root=/opt/somebody/checkout\n' >"$G/planted-untracked.txt"
    ( cd "$G" && bash scripts/scan.sh ); rc=$?; ck "blind window: the scanner itself reports green over an untracked planted file" 0 "$rc" "" ""
    out=$(bash "$SELF" --root "$G"); rc=$?; ck "blind window: the class flags that scanner" 1 "$rc" "scripts/scan.sh:3" "$out"
    # --- corpus mode against the shipped corpus, when present ---
    local C="$repo_root/_tests/fixtures/zero-gap/$CLASS_ID"
    if [ -d "$C/planted" ] && [ -d "$C/clean" ]; then
        out=$(bash "$SELF" --root "$repo_root" --corpus "$C/planted"); rc=$?; ck "shipped corpus: planted yields findings" 1 "$rc" "audit-loop-over-list.sh:8" "$out"
        # exact recall: the reported location set EQUALS expect.tsv (a surviving detector mutation shows here)
        if [ "$(awk '$1 == "FINDING" { print $5 }' <<<"$out" | LC_ALL=C sort -u)" = "$(awk -F'\t' '$1 !~ /^(#|$)/ { print $1 }' "$C/expect.tsv" | LC_ALL=C sort -u)" ]; then echo "PASS shipped corpus: reported set equals expect.tsv exactly"
        else echo "FAIL shipped corpus: reported set differs from expect.tsv"; fails=$((fails + 1)); fi
        out=$(bash "$SELF" --root "$repo_root" --corpus "$C/clean"); rc=$?; ck "shipped corpus: clean yields none" 0 "$rc" "" "$out"
    fi
    # --- a registered entry point with a `..` segment: COULD-NOT-INSPECT on its registry line, a valid token ---
    local U=$T/r4; mkroot "$U"
    printf '#!/usr/bin/env bash\ngit ls-files -co --exclude-standard\n' >"$U/scripts/ok.sh"; reg "$U" ok scripts/ok.sh; reg "$U" up ../outside.sh
    out=$(bash "$SELF" --root "$U"); rc=$?; ck "a '..' entry point is COULD-NOT-INSPECT at scripts/check-registry.tsv:4" 2 "$rc" "COULD-NOT-INSPECT scripts/check-registry.tsv:4 " "$out"
    if grep -q '\.\./\|%2E%2E\|unsafe-entrypoint' <<<"$out"; then echo "FAIL the '..' entry point leaked into a token"; fails=$((fails + 1)); else echo "PASS no '..' token printed"; fi
    # --- a registered entry point that is a symlink or a FIFO: COULD-NOT-INSPECT, never read (no hang) ---
    local V=$T/r5; mkroot "$V"
    printf '#!/usr/bin/env bash\ngit ls-files | while read -r f; do cat "$f"; done\n' >"$T/outside-target.sh"
    ln -s "$T/outside-target.sh" "$V/scripts/link.sh"; mkfifo "$V/scripts/pipe.sh"
    reg "$V" link scripts/link.sh; reg "$V" pipe scripts/pipe.sh
    out=$(timeout -k 5 30 bash "$SELF" --root "$V"); rc=$?; ck "symlink / FIFO entry points are COULD-NOT-INSPECT, not followed" 2 "$rc" "COULD-NOT-INSPECT scripts/link.sh " "$out"
    if grep -q '^COULD-NOT-INSPECT scripts/pipe.sh ' <<<"$out" && ! grep -q '^FINDING' <<<"$out"; then echo "PASS FIFO entry point COULD-NOT-INSPECT, symlink target never read"; else echo "FAIL FIFO/symlink: $out"; fails=$((fails + 1)); fi
    # --- the swept tree is byte-identical across a run: measured on a REAL COPY of the live registry and
    # its entry points (the live files are edited by other work concurrently, which a live fingerprint
    # would misattribute to this class) ---
    local LC=$T/livecopy e
    mkdir -p "$LC/scripts"; cp "$repo_root/scripts/check-registry.tsv" "$LC/scripts/"
    while IFS= read -r e; do
        case "$e" in /*|*..*) continue ;; esac
        if [ -f "$repo_root/$e" ] && [ ! -L "$repo_root/$e" ]; then mkdir -p "$LC/$(dirname "$e")"; cp "$repo_root/$e" "$LC/$e"; fi
    done < <(awk -F'\t' '($1=="check"||$1=="debt") && $3 != "" {print $3}' "$repo_root/scripts/check-registry.tsv" | LC_ALL=C sort -u)
    fp1=$(cd "$LC" && find . -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum | sha256sum | cut -d' ' -f1)
    out=$(bash "$SELF" --root "$LC" 2>/dev/null); rc=$?
    fp2=$(cd "$LC" && find . -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum | sha256sum | cut -d' ' -f1)
    if [ "$fp1" = "$fp2" ] && grep -q '^INSPECTED [1-9]' <<<"$out"; then echo "PASS a full-registry run leaves the swept copy byte-identical (rc $rc)"; else echo "FAIL the swept copy changed during a run (or nothing was inspected)"; fails=$((fails + 1)); fi
    if [ "$fails" -eq 0 ]; then echo "prove-failure: all cases held"; return 0; fi
    echo "prove-failure: $fails case(s) failed"; return 1
}

ROOT="" CORPUS="" EMIT=0 PROVE=0
while [ $# -gt 0 ]; do
    case "$1" in
        --root) ROOT="${2:-}"; shift 2 ;;
        --corpus) CORPUS="${2:-}"; shift 2 ;;
        --emit-population) EMIT=1; shift ;;
        --prove-failure) PROVE=1; shift ;;
        *) echo "COULD-NOT-INSPECT argument unknown argument: $(zg_pct_encode "$1")"; echo "INSPECTED 0"; echo "POPULATION-SHA e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"; exit 2 ;;
    esac
done

if [ "$PROVE" -eq 1 ]; then
    prove_failure
    exit $?
fi

if [ "$EMIT" -eq 1 ]; then
    emit_population
    exit $?
fi

if ! need_tools; then echo "INSPECTED 0"; echo "POPULATION-SHA e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"; exit 2; fi
TMPDIR_ZG=$(mktemp -d "${TMPDIR:-/tmp}/zg-ubw.XXXXXX") || { echo "COULD-NOT-INSPECT tmp mktemp failed"; tail_empty; exit 2; }
trap 'rm -rf "$TMPDIR_ZG"' EXIT
run_class
exit $?
