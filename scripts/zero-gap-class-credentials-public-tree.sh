#!/usr/bin/env bash
# scripts/zero-gap-class-credentials-public-tree.sh — sweep class `credentials-public-tree`
# (feature 010, VSC-388, FR-020).
#
# WHAT IT DETECTS. A credential written as text into a PUBLIC tracked file, anywhere in the public
# tree — not only in the records feature 010 produces. The sibling class `private-in-public` runs its
# credential layers over feature 010's own records plus specs/002-009 only (so 105 older spec files and
# the rest of the tree were never scanned) and its value patterns need a password marker shape that 14
# of the 15 literal-password lines of specs/007-decouple-modules-auth do not carry. This class widens the
# POPULATION and the SHAPES; it replaces nothing in the sibling.
#
# POPULATION (derived at run time, never listed): every tracked TEXT file (git ls-files; `grep -Il .`
# keeps text) of the umbrella and of every checked-out submodule of .gitmodules that is not PRIVATE
# (rows reading **private** in the fleet table of docs/content-boundary.md) and not third-party (the
# shared zg_thirdparty classification); minus _tests/fixtures/zero-gap/ (deliberately defective
# corpora). Binary files (PDF, images) are not text and are NOT read; their markdown/HTML sources are.
# With --corpus <dir>: every regular file under <dir>, with the @@ZG-...@@ placeholders expanded in a
# scratch copy at scan time (the corpus stores no secret-shaped text at rest).
#
# SHAPES (a hit on any is one finding for the line; the matched VALUE is never printed — the finding
# names the shape and `[REDACTED len=N]`, N the length of the withheld value only):
#   aws-key-id        AKIA/ASIA/AGPA/AIDA/AROA/ANPA/ANVA/AIPA + 16 [A-Z0-9]
#   private-key       PEM armour `-----BEGIN ... PRIVATE KEY-----`
#   token-prefix      ghp_/gho_/ghu_/ghs_/ghr_/github_pat_, glpat-, xox[abprs]-, JWT (eyJ.eyJ.sig)
#   url-password      scheme://user:value@host, value not a placeholder
#   marker-value      a marker word (password passwd pwd passphrase secret apikey api_key api-key) followed by a separator (`:` `=` `=>` `->` ` is ` or whitespace; an
#                     opening quote, backtick, `**` or `(` is skipped) and a VALUE. This covers the
#                     shapes `user (password: X)`, `password: X`, `password = "X"`, `` password `X` ``,
#                     `PASSWORD=X`.
#   table-value       a markdown table whose header row has a cell that is a marker word (the column's
#                     data cells), or a two-cell row whose first cell is a marker word (`| password | X |`)
# A VALUE counts only when it is 6..128 characters, holds a digit or one of ! @ # $ % ^ & * + = ? ~, and
# is not a placeholder. The placeholder set is exactly this, matched whole-token, never as a substring
# of a common word (VSC-388: `Admin-7f3k...`, `Xk9-user-...`, `...-token-...` are DETECTED):
#   - REDACTED, PLACEHOLDER, EXAMPLE, CHANGEME as a whole alphanumeric token of the value
#     (`REDACTED-2024`, `CHANGEME_99` are placeholders; `Changeme99`, `examples1` are not)
#   - a value starting YOUR_ or YOUR-
#   - a leading < { [ $ % ( or backtick, a leading @@, a `*` run of 3+, an x/X run of 3+, an
#     ellipsis `...`, a `${NAME}` reference, a trailing `()`
# Conventional fakes such as test/demo/admin/1234 words are NOT filtered: a hit on one is a reading
# assignment like any other.
# A line over 8192 bytes is still read in full (every pattern is linear).
#
# NOT seen, by construction: a name-less value (a bare string with no marker word), an encoded or
# computed secret, a value split across lines, a password of fewer than 6 characters or made only of
# letters (`hunter`), an entropy-only token in no known shape, text inside binary files, a marker in
# another language, a table whose marker header is on a different page of the file than the data.
# PRECISION: the marker-value and table-value shapes also match test fixtures and documentation that
# show FAKE credentials; a hit is a reading assignment (is the literal real?), not a verdict. Measured
# on the live tree when this class was written: see the VSC-388 closure record (do not quote a count
# from this header).
#
# USAGE  zero-gap-class-credentials-public-tree.sh --root <abs dir> [--corpus <abs dir>] [--emit-population]
#        zero-gap-class-credentials-public-tree.sh --prove-failure
# EXIT   0 clean (non-empty population fully read), 1 at least one FINDING (outranks 2), 2 could not
#        determine (root not a git repository, a tool missing, empty population, a file unreadable).
set -uo pipefail
export LC_ALL=C LANG=C

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

# >>> zg_thirdparty (shared exclusion classification; identical in zero-gap-class-unproven-checks.sh
# and zero-gap-class-unregistered-scripts.sh, and each class's --prove-failure asserts the two copies
# are byte-identical)
# zg_thirdparty_prefixes <base>: one entry per line naming what is NOT authored here (vendored
# third-party or generated), DERIVED from tracked data under <base>, never a hand list. An entry
# ending in `/` is a tree (prefix match); any other entry is one exact path.
#   1. helix-deps.yaml's third-party comment block: every `#   <path> -> <url>` line names a
#      third-party gitlink; its tree `<path>/` and its vendored spec-kit extension mirror
#      `.specify/extensions/<basename>/` are excluded.
#   2. config/covenant_propagation_exclusions.tsv rows of class vendored-third-party or
#      generated-code: the glob `*/<path>` names `<path>` (both the tree `<path>/` and the file).
#   3. Controller ruling 2026-09-26 (progress.yml, "Class review rev-gates"): `.specify/scripts/bash/`
#      is spec-kit's vendored tooling (the installer writes exactly that tree; measured 2026-09-26:
#      monetization's copy of check-prerequisites.sh is byte-identical to the umbrella's) and is
#      excluded as third-party in every tree, with or without spec-kit's `.specify/init-options.json`
#      marker. Anything else under `.specify/` is judged.
zg_thirdparty_prefixes() {
    local b=$1 tp
    if [ -f "$b/helix-deps.yaml" ] && [ ! -L "$b/helix-deps.yaml" ]; then
        LC_ALL=C sed -n 's/^#[[:space:]]\{1,\}\([A-Za-z0-9._][A-Za-z0-9._/-]*\)[[:space:]]\{1,\}->[[:space:]].*/\1/p' "$b/helix-deps.yaml" |
            while IFS= read -r tp; do
                [ -n "$tp" ] && printf '%s/\n.specify/extensions/%s/\n' "$tp" "${tp##*/}"
            done
    fi
    if [ -f "$b/config/covenant_propagation_exclusions.tsv" ] && [ ! -L "$b/config/covenant_propagation_exclusions.tsv" ]; then
        LC_ALL=C awk -F'\t' '!/^#/ && NF >= 2 && ($2 == "vendored-third-party" || $2 == "generated-code") {
            g = $1; sub(/^\*\//, "", g); if (g != "" && g !~ /[*?[]/) { print g "/"; print g } }' "$b/config/covenant_propagation_exclusions.tsv"
    fi
    printf '.specify/scripts/bash/\n'
    return 0
}
# zg_drop_excluded <entries-file>: filter newline-separated relative paths on stdin, dropping every
# path that equals an exact entry or starts with a tree entry
zg_drop_excluded() {
    LC_ALL=C awk -v ef="$1" '
        BEGIN { while ((getline e < ef) > 0) if (e != "") { if (e ~ /\/$/) tree[++nt] = e; else exact[e] = 1 } }
        { if ($0 in exact) next; for (i = 1; i <= nt; i++) if (index($0, tree[i]) == 1) next; print }'
}
# <<< zg_thirdparty

CLASS_ID=credentials-public-tree
FIXTURE_PFX=_tests/fixtures/zero-gap/
SELF=$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")
EMPTY_SHA=e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855

ROOT="" CORPUS="" EMIT=0 PROVE=0
fail_early() {
    if [ "$EMIT" -eq 1 ]; then echo "COULD-NOT-INSPECT $1 $2" >&2; exit 2; fi
    echo "COULD-NOT-INSPECT $1 $2"; echo "INSPECTED 0"; echo "POPULATION-SHA $EMPTY_SHA"; exit 2
}
while [ $# -gt 0 ]; do
    case "$1" in
        --root) ROOT="${2:-}"; shift 2 ;;
        --corpus) CORPUS="${2:-}"; shift 2 ;;
        --emit-population) EMIT=1; shift ;;
        --prove-failure) PROVE=1; shift ;;
        *) fail_early arguments "unknown-argument:$(zg_pct_encode "$1")" ;;
    esac
done

decode() { printf '%b' "$(printf '%s' "$1" | sed 's/%\([0-9A-F][0-9A-F]\)/\\x\1/g')"; }

# ------------------------------------------------------------------ the detector (awk)
# Input: file names as arguments. Output, one line per hit: <file>\t<lineno>\t<shape>\t<len>
read -r -d '' AWK_DETECT <<'AWKEOF' || true
function placeholder(v,   l, t) {
    l = tolower(v)
    # VSC-388: the documented set only, matched as a WHOLE token or a prefix, never as a substring of a
    # common word (a real secret may contain admin / user / token / test ...). A token is a maximal
    # run of [a-z0-9]; REDACTED PLACEHOLDER EXAMPLE CHANGEME count only when one token equals the word.
    t = l; gsub(/[^a-z0-9]+/, " ", t); t = " " t " "
    if (t ~ / (redacted|placeholder|example|changeme) /) return 1
    if (l ~ /^your[_-]/) return 1
    if (v ~ /^[<{\[$%(`]/ || v ~ /^@@/ || v ~ /\*\*\*/ || v ~ /[xX]{3,}/ || v ~ /\(\)$/ || v ~ /\$\{?[A-Za-z_]/) return 1
    if (index(v, "...") > 0) return 1
    return 0
}
function valid(v) {
    if (length(v) < 6 || length(v) > 128) return 0
    if (v !~ /[0-9!@#$%^&*+=?~]/ || v !~ /[A-Za-z]/) return 0
    return !placeholder(v)
}
# strip wrapping quote/backtick/bold/paren chars from both ends of a cell or value
function trimv(v) {
    gsub(/^[ \t`"'*(\[]+/, "", v); gsub(/[ \t`"'*)\],;.]+$/, "", v)
    return v
}
function emit(shape, len) { printf "%s\t%d\t%s\t%d\n", FILENAME, FNR, shape, len; hit = 1 }
function ismarker(w) {
    w = tolower(trimv(w))
    return (w ~ /^(password|passwd|pwd|passphrase|secret|api[_-]?key)$/)
}
# paths whose literals are fixtures or test data by convention: the weak (marker/table) shapes are
# not applied there; the strong shapes (key ids, PEM armour, token prefixes, URL passwords) still are
function testpath(f) {
    return (f ~ /(^|\/)(_?tests?|testdata|fixtures?|banks|__tests__|mocks?|examples?|spec)\// || f ~ /_test\.go$/ || f ~ /\.(test|spec)\.[jt]sx?$/ || f ~ /(^|\/)test_[^\/]*$/)
}
function commentline(f, l) {
    if (f ~ /\.(md|markdown|txt|rst|html|tsv|csv)$/) return 0
    return (l ~ /^[ \t]*(\/\/|#|\*|--|<!--|;)/)
}
FNR == 1 { tcol = 0; intable = 0; weak = !testpath(FILENAME) }
{
    hit = 0; line = $0; low = tolower(line)
    # bounded on both sides: a base64 blob that merely contains the letters is not a key id
    if (match(line, /(^|[^A-Za-z0-9+\/])(AKIA|ASIA|AGPA|AIDA|AROA|ANPA|ANVA|AIPA)[A-Z0-9]{16}([^A-Za-z0-9+\/]|$)/)) { emit("aws-key-id", 20); next }
    if (line ~ /-----BEGIN [A-Z ]*PRIVATE KEY-----/) { emit("private-key", 0); next }
    if (match(line, /gh[pousr]_[A-Za-z0-9]{30,}/) || match(line, /github_pat_[A-Za-z0-9_]{30,}/) \
        || match(line, /glpat-[A-Za-z0-9_-]{20,}/) || match(line, /xox[abprs]-[A-Za-z0-9-]{10,}/) \
        || match(line, /eyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}/)) { emit("token-prefix", RLENGTH); next }
    if (!commentline(FILENAME, line) && match(line, /[A-Za-z][A-Za-z0-9+.-]*:\/\/[^\/@ \t:]+:[^\/@ \t]+@/)) {
        s = substr(line, RSTART, RLENGTH); sub(/^[^:]*:\/\/[^:]*:/, "", s); sub(/@$/, "", s)
        if (length(s) >= 4 && !placeholder(s)) { emit("url-password", length(s)); next }
    }
    if (!weak || commentline(FILENAME, line)) next
    # markdown table rows
    if (line ~ /^[ \t]*\|/) {
        n = split(line, cell, "|")   # cell[1] is the text before the first pipe (empty)
        if (n >= 4 && ismarker(cell[2])) { v = trimv(cell[3]); if (valid(v)) { emit("table-value", length(v)); next } }
        if (!intable) {
            for (i = 2; i < n; i++) if (ismarker(cell[i])) { tcol = i; intable = 1; break }
            if (intable) next
        } else if (line ~ /^[ \t]*\|[ \t]*:?-+/) {
            next
        } else if (tcol > 0 && tcol < n) {
            v = trimv(cell[tcol]); if (valid(v)) { emit("table-value", length(v)); next }
        }
    } else { intable = 0; tcol = 0 }
    # marker followed by a separator and a value
    rest = low; off = 0
    while (match(rest, /(password|passwd|pwd|passphrase|secret|apikey|api_key|api-key)/)) {
        e = RSTART + RLENGTH
        tail = substr(line, off + e)
        rest = substr(rest, e); off += e - 1
        if (tail ~ /^[a-z_-]/) continue                              # password_hash, tokens, secretary
        if (match(tail, /^[ \t]*[`"'*)]*[ \t]*(:|=>|->|=|[ \t]is[ \t])[ \t]*[`"'*(]*/)) {
            tail2 = substr(tail, RLENGTH + 1)
        } else if (match(tail, /^[ \t]+[`"'(]/)) {
            tail2 = substr(tail, RLENGTH + 1)                        # password `X`
        } else continue
        if (match(tail2, /^[^ \t`"'),;|<>]+/)) { v = substr(tail2, 1, RLENGTH); v = trimv(v)
            if (valid(v)) { emit("marker-value", length(v)); break } }
    }
}
AWKEOF

# expand the corpus placeholders (the corpus stores no secret-shaped text at rest)
zg_expand() {   # <in file> <out file>
    local akia pw pwq
    akia="AK""IA$(printf 'FAKE%.0s' 1 2 3 4)"
    pw="Kq7""!zv2Rm"; pwq="Wn4""#pl8Xe"
    local pa pu pt ps
    pa="Admin""-7f3kQm"; pu="Xk9-us""er-Qm2pL8"; pt="Zt4-tok""en-Rv8nB3"; ps="Vb6-te""st-Hd2wS9"
    awk -v akia="$akia" -v pw="$pw" -v pwq="$pwq" -v pa="$pa" -v pu="$pu" -v pt="$pt" -v ps="$ps" '{ gsub(/@@ZG-AKIA@@/, akia); gsub(/@@ZG-PWVAL@@/, pw); gsub(/@@ZG-PWVAL2@@/, pwq); gsub(/@@ZG-PWADMIN@@/, pa); gsub(/@@ZG-PWUSER@@/, pu); gsub(/@@ZG-PWTOKEN@@/, pt); gsub(/@@ZG-PWTEST@@/, ps); print }' "$1" >"$2"
}

prove_failure() {
    local T rc fails=0 undet=0 live_before live_after LIVE out
    LIVE="$(cd "$(dirname "$SELF")/.." && pwd)"
    live_sum() {
        ( cd "$LIVE" && {
            git --no-optional-locks status --porcelain=v1 -z --ignore-submodules=all 2>/dev/null
            git --no-optional-locks ls-files -z -m -o --exclude-standard 2>/dev/null | xargs -0 -r sha256sum -- 2>/dev/null
        } | sha256sum | cut -d' ' -f1 )
    }
    live_before=$(live_sum)
    T=$(mktemp -d "${TMPDIR:-/tmp}/zg-cpt.XXXXXX") || { echo "prove-failure: cannot make a temp dir"; return 2; }
    trap 'rm -rf "$T"' RETURN
    pass() { printf 'PASS %s\n' "$1"; }
    fail() { printf 'FAIL %s\n' "$1"; fails=$((fails + 1)); }
    local cdir="$LIVE/_tests/fixtures/zero-gap/$CLASS_ID" got want
    if [ -d "$cdir/planted" ] && [ -d "$cdir/clean" ] && [ -f "$cdir/expect.tsv" ]; then
        mkdir -p "$T/r"; git -C "$T/r" init -q >/dev/null 2>&1
        out=$(bash "$SELF" --root "$T/r" --corpus "$cdir/planted" 2>&1); rc=$?
        got=$(grep '^FINDING ' <<<"$out" | awk '{print $5}' | LC_ALL=C sort -u)
        want=$(awk -F'\t' '!/^#/ && NF { print $1 }' "$cdir/expect.tsv" | LC_ALL=C sort -u)
        if [ "$rc" -eq 1 ] && [ -n "$want" ] && [ "$got" = "$want" ]; then pass "corpus planted/: findings equal expect.tsv exactly ($(printf '%s\n' "$want" | awk 'END{print NR}') rows)"
        else fail "corpus planted rc=$rc missing: $(comm -23 <(printf '%s\n' "$want") <(printf '%s\n' "$got") | tr '\n' ' ') unexpected: $(comm -13 <(printf '%s\n' "$want") <(printf '%s\n' "$got") | tr '\n' ' ')"; fi
        # the value is never printed: expanded placeholders must not appear in any output
        if grep -qF -e "Kq7!zv2Rm" -e "Wn4#pl8Xe" -e "AKIAFAKE" -e "Admin-7f3kQm" -e "Xk9-user-Qm2pL8" -e "Zt4-token-Rv8nB3" -e "Vb6-test-Hd2wS9" <<<"$out"; then fail "a planted value was printed"; else pass "no planted value appears in the output (shape + [REDACTED len=N] only)"; fi
        out=$(bash "$SELF" --root "$T/r" --corpus "$cdir/clean" 2>&1); rc=$?
        if [ "$rc" -eq 0 ] && ! grep -q '^FINDING' <<<"$out"; then pass "corpus clean/: no finding (placeholders, identifiers, short and letter-only values), rc 0"; else fail "corpus clean rc=$rc: $out"; fi
        # the planted corpus stores no secret-shaped text at rest
        if grep -rqE -e 'AKIA[A-Z0-9]{16}' -e 'Kq7!zv2Rm' -e 'Wn4#pl8Xe' -e 'Admin-7f3kQm' -e 'Xk9-user-Qm2pL8' -e 'Zt4-token-Rv8nB3' -e 'Vb6-test-Hd2wS9' "$cdir"; then fail "the corpus stores secret-shaped text at rest"; else pass "the corpus stores no secret-shaped text at rest"; fi
    else
        fail "corpus directory $cdir is incomplete"
    fi
    # a mutation: a detector with the marker-value shape removed misses every marker-value row
    sed 's/(password|passwd|pwd|passphrase|secret|apikey|api_key|api-key)/(zzneverzz)/' "$SELF" >"$T/mut.sh"
    mkdir -p "$T/r2"; git -C "$T/r2" init -q >/dev/null 2>&1
    out=$(bash "$T/mut.sh" --root "$T/r2" --corpus "$cdir/planted" 2>&1); rc=$?
    if [ "$(grep -c '^FINDING ' <<<"$out")" -lt "$(grep -c . <(awk -F'\t' '!/^#/ && NF' "$cdir/expect.tsv"))" ]; then pass "mutation: removing the marker words loses planted findings (the corpus is sensitive to the shape)"; else fail "mutation not detected"; fi
    # a mutation: re-introducing substring filtering of common words (the VSC-388 defect) loses the recall rows
    sed 's/^    l = tolower(v)$/    l = tolower(v); if (l ~ \/test|demo|secret|passw|admin|user|token\/) return 1/' "$SELF" >"$T/mut2.sh"
    mkdir -p "$T/r3"; git -C "$T/r3" init -q >/dev/null 2>&1
    out=$(bash "$T/mut2.sh" --root "$T/r3" --corpus "$cdir/planted" 2>&1); rc=$?
    if [ "$(grep -c '^FINDING ' <<<"$out")" -le $(( $(awk -F'\t' '!/^#/ && NF' "$cdir/expect.tsv" | wc -l) - 7 )) ]; then pass "mutation: substring-filtering common words loses the 7 recall rows (the boundary is pinned)"; else fail "substring mutation not detected"; fi
    out=$(bash "$SELF" --root /nonexistent-zg-root 2>&1); rc=$?
    if [ "$rc" -eq 2 ] && grep -q '^INSPECTED 0$' <<<"$out"; then pass "--root /nonexistent => rc 2 with the contract lines"; else fail "nonexistent rc=$rc: $out"; fi
    mkdir -p "$T/e"; git -C "$T/e" init -q >/dev/null 2>&1
    out=$(bash "$SELF" --root "$T/e" 2>&1); rc=$?
    if [ "$rc" -eq 2 ] && grep -q '^COULD-NOT-INSPECT population ' <<<"$out"; then pass "empty population => COULD-NOT-INSPECT, rc 2 (never clean)"; else fail "empty rc=$rc: $out"; fi
    live_after=$(live_sum)
    if [ "$live_before" = "$live_after" ]; then pass "the live tree is byte-identical before and after the proof"
    else echo "COULD-NOT-INSPECT live-tree the live tree moved while the proof ran (another writer)"; undet=1; fi
    if [ "$fails" -gt 0 ]; then echo "prove-failure: $fails case(s) failed"; return 1; fi
    if [ "$undet" -gt 0 ]; then echo "prove-failure: every case passed, $undet assertion(s) undetermined"; return 2; fi
    echo "prove-failure: all cases passed"; return 0
}

case "$PROVE" in
1) prove_failure; exit $? ;;
esac

for t in git awk od sha256sum sort sed grep find head dirname basename mktemp xargs; do
    command -v "$t" >/dev/null 2>&1 || fail_early tool "required-tool-missing:$t"
done
if [ -z "$ROOT" ] || [ ! -d "$ROOT" ]; then fail_early root "--root-is-not-a-directory"; fi
if [ -n "$CORPUS" ] && [ ! -d "$CORPUS" ]; then fail_early corpus "--corpus-is-not-a-directory"; fi
if [ -z "$CORPUS" ] && ! git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1; then fail_early root "--root-is-not-a-git-repository"; fi
W=$(mktemp -d "${TMPDIR:-/tmp}/zg-cpt.XXXXXX") || fail_early tmp "mktemp-failed"
trap 'rm -rf "$W"' EXIT
BASE=${CORPUS:-$ROOT}

# ---- repositories of the population: the umbrella plus public, non-third-party, checked-out submodules
declare -a REPOS=(".")
if [ -z "$CORPUS" ]; then
    private=""
    if [ -f "$ROOT/docs/content-boundary.md" ]; then
        private=$(sed -n 's/^| `\([^`]*\)` | \*\*private\*\*.*/\1/p' "$ROOT/docs/content-boundary.md")
    fi
    { zg_thirdparty_prefixes "$ROOT"; printf '%s\n' "$FIXTURE_PFX"; } | LC_ALL=C sort -u >"$W/excl"
    while IFS= read -r sp; do
        [ -n "$sp" ] || continue
        grep -qxF -- "$sp" <<<"$private" && continue
        grep -qxF -- "$sp/" "$W/excl" && continue
        { [ -e "$ROOT/$sp/.git" ] || [ -d "$ROOT/$sp/.git" ]; } || continue
        REPOS+=("$sp")
    done < <(git -C "$ROOT" config -f .gitmodules --get-regexp 'submodule\..*\.path' 2>/dev/null | awk '{print $2}')
else
    : >"$W/excl"; printf '%s\n' "$FIXTURE_PFX" >"$W/excl"
fi

# ---- population: tracked text files (NUL-separated, ROOT-relative raw paths)
list_repo() { # <repo rel path> -> NUL-separated paths relative to ROOT, text files only
    local rp=$1 pfx="" dir
    [ "$rp" = "." ] || pfx="$rp/"
    dir="$ROOT"; [ "$rp" = "." ] || dir="$ROOT/$rp"
    ( cd "$dir" && git ls-files -z 2>/dev/null | { xargs -0 -r grep -IlZ . -- 2>/dev/null || true; } ) | while IFS= read -r -d '' f; do
        [ -L "$dir/$f" ] && continue
        [ -f "$dir/$f" ] || continue
        printf '%s%s\0' "$pfx" "$f"
    done
}
raw_items() {
    if [ -n "$CORPUS" ]; then
        ( cd "$CORPUS" && find . -type f -print0 ) | sed -z 's|^\./||'
    else
        local rp
        for rp in "${REPOS[@]}"; do list_repo "$rp"; done
    fi
}
# raw paths minus the excluded trees, NUL-separated, sorted and unique
raw_filtered() {
    raw_items | LC_ALL=C awk -v RS='\0' -v ORS='\0' -v ef="$W/excl" '
        BEGIN { while ((getline e < ef) > 0) if (e != "") tree[++nt] = e }
        { for (i = 1; i <= nt; i++) if (index($0, tree[i]) == 1) next; print }' | LC_ALL=C sort -z -u
}
raw_filtered >"$W/paths0"
TOKENS=$(zg_pct_encode_z <"$W/paths0" | awk 'NF' | LC_ALL=C sort -u)
if [ "$EMIT" -eq 1 ]; then
    [ -n "$TOKENS" ] && printf '%s\n' "$TOKENS"
    exit 0
fi
SHA=$(if [ -n "$TOKENS" ]; then printf '%s\n' "$TOKENS" | sha256sum | cut -d' ' -f1; else echo "$EMPTY_SHA"; fi)
found=0 n=0 bad=0
cni() { printf 'COULD-NOT-INSPECT %s %s\n' "$1" "$2"; }
finish() {
    echo "INSPECTED $n"
    echo "POPULATION-SHA $SHA"
    if [ "$found" -gt 0 ]; then exit 1; fi
    if [ "$bad" -gt 0 ]; then exit 2; fi
    exit 0
}
if [ -z "$TOKENS" ]; then cni population "no-tracked-text-file-after-exclusions-a-zero-size-population-is-never-clean"; bad=1; finish; fi

# ---- scan: expand corpus placeholders into a scratch copy, then awk over batches of files
SCAN="$BASE"
if [ -n "$CORPUS" ]; then
    SCAN="$W/expanded"; mkdir -p "$SCAN"
    while IFS= read -r -d '' p; do
        mkdir -p "$SCAN/$(dirname "$p")"
        zg_expand "$BASE/$p" "$SCAN/$p" || { cni "$(zg_pct_encode "$p")" "placeholder-expansion-failed"; bad=1; }
    done <"$W/paths0"
fi
: >"$W/scan0"
while IFS= read -r -d '' p; do
    case "$p" in *$'\n'*|*$'\t'*) cni "$(zg_pct_encode "$p")" "path-with-control-character-not-read"; bad=1; continue ;; esac
    n=$((n + 1)); printf '%s\0' "$p" >>"$W/scan0"
done <"$W/paths0"
( cd "$SCAN" && xargs -0 -r -a "$W/scan0" -n 400 awk "$AWK_DETECT" ) >"$W/hits" 2>"$W/awk.err"
if [ -s "$W/awk.err" ]; then cni awk "the detector program reported an error; some files may be unread"; bad=1; fi
# locations: <file token>:<line>; evidence_ref = the same file:line
while IFS=$'\t' read -r f ln shape len; do
    [ -n "$f" ] || continue
    tok=$(zg_pct_encode "$f")
    if [ "$len" -gt 0 ]; then val="[REDACTED len=$len]"; else val="[REDACTED]"; fi
    echo "FINDING $CLASS_ID critical security $tok:$ln credential-shaped $shape in a public tracked file $val $tok:$ln"
    found=$((found + 1))
done < <(LC_ALL=C sort -t"$(printf '\t')" -k1,1 -k2,2n "$W/hits")
finish
