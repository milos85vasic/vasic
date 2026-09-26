#!/usr/bin/env bash
# zero-gap-class-unregistered-scripts.sh — sweep class `unregistered-scripts` (feature 010, T027).
#
# WHAT IT DETECTS
#   Rule R5 of scripts/verify-check-registry.sh ("every *.sh is a registered check, debt or exempt
#   row") applied as a sweep class over EVERY tracked shell script of the umbrella, not only the
#   maxdepth-1 files of the declared scanroots. Three finding kinds:
#     1. unregistered script (medium, test-coverage): a tracked *.sh that no check/debt/exempt row
#        names, that is executable AND (starts with a #! line OR is named by path in another tracked
#        file). A non-executable, shebang-less, unreferenced script is not a claim of being a check.
#     2. blind-spot script (medium, governance-drift): an unregistered *.sh that sits below a declared
#        scanroot at a depth R5 does not reach (its directory is under a scanroot but is not itself a
#        scanroot). Reported whether or not it is executable, with the reason.
#     3. dangling row (high, governance-drift; the R3 class): a check/debt/exempt row whose entry-point
#        path does not exist. Location `scripts/check-registry.tsv:<line>`.
#
# POPULATION (docs/zero-gap/sweep-classes.tsv row `unregistered-scripts`; UMBRELLA-ONLY per the
# controller ruling 2026-09-26, progress.yml "Class-wave reconcile list" item 2)
#   Tracked *.sh at --root (`git ls-files -z '*.sh'`, every depth; a path holding a newline stays ONE
#   token, %0A), MINUS `_tests/fixtures/zero-gap/` (deliberately defective corpora) and MINUS what the
#   shared exclusion block `zg_thirdparty` (identical in zero-gap-class-unproven-checks.sh; each
#   proof asserts the two copies are byte-identical) derives from tracked data: third-party gitlinks
#   of helix-deps.yaml's `#   <path> -> <url>` comment block and their `.specify/extensions/<name>/`
#   mirrors, config/covenant_propagation_exclusions.tsv rows of class vendored-third-party or
#   generated-code, and `.specify/scripts/bash/` (spec-kit's vendored tooling, ruled third-party for
#   both classes).
#   Registry read: scripts/check-registry.tsv. With --corpus <dir> the population is every *.sh
#   entry under <dir> (same exclusions and rules; registry and exclusion sources read from <dir>).
#   A tracked symlink or special file is COULD-NOT-INSPECT (never read, never followed).
#
# OUTPUT: FINDING / COULD-NOT-INSPECT / INSPECTED / POPULATION-SHA; INSPECTED and POPULATION-SHA are
#   printed on EVERY rc of an inspection run (also an absent tracked file, an absent registry, a
#   missing tool). A reference is found through a temp file, never `producer | grep -q` (pipefail).
#
# NOT SEEN (honest boundary)
#   * Scripts inside owned submodules: this registry has no rows for them and each submodule has no
#     registry of its own (measured: 0 of 22 carry scripts/check-registry.tsv; about 1,900 tracked
#     *.sh live there), so "unregistered" is undefined there; the class enumerates the umbrella
#     only. zero-gap-class-unproven-checks.sh is the class that walks owned submodules.
#   * scripts/zero-gap-class-*.sh are walked but never reported: R5 of scripts/verify-check-registry.sh
#     already reports an unregistered one (scripts/ is a declared scanroot, depth 1), and the sweep
#     runner reports a class script no docs/zero-gap/sweep-classes.tsv row lists (no double report).
#   * Scripts without the .sh suffix, and non-executable shebang-less unreferenced *.sh files.
#   * A reference counts only as the full relative path appearing in another tracked file, the name
#     ending there (`other/x.sh` does not match `other/x.sh.bak`); a path spelled through a variable
#     (`"$HERE/x.sh"`) is not a reference.
#
# Usage: --root <abs dir> [--corpus <abs dir>] [--emit-population] | --prove-failure
# Exit:  0 clean (full non-empty population inspected), 1 finding(s), 2 could not determine.
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

CLASS_ID=unregistered-scripts
REGISTRY_REL=scripts/check-registry.tsv
FIXTURE_PFX=_tests/fixtures/zero-gap/
SELF=$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")
EMPTY_SHA=e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855   # sha256 of the empty population

ROOT="" CORPUS="" EMIT=0 PROVE=0
# fail_early <part> <reason>: nothing was enumerated; an inspection run still prints INSPECTED 0 and
# the POPULATION-SHA of the empty set (every rc carries the full contract); --emit-population prints
# the reason on stderr only and exits 2
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

# decode <token> -> raw path
decode() { printf '%b' "$(printf '%s' "$1" | sed 's/%\([0-9A-F][0-9A-F]\)/\\x\1/g')"; }

prove_failure() {
    local T rc fails=0 undet=0 tool_dir LIVE live_before live_after
    LIVE="$(cd "$(dirname "$SELF")/.." && pwd)"
    live_sum() {
        ( cd "$LIVE" && {
            git --no-optional-locks status --porcelain=v1 -z --ignore-submodules=all 2>/dev/null
            git --no-optional-locks ls-files -z -m -o --exclude-standard 2>/dev/null | xargs -0 -r sha256sum -- 2>/dev/null
        } | sha256sum | cut -d' ' -f1 )
    }
    live_before=$(live_sum)
    T=$(mktemp -d "${TMPDIR:-/tmp}/zg-unreg.XXXXXX") || { echo "prove-failure: cannot make a temp dir"; return 2; }
    trap 'rm -rf "$T"' RETURN
    pass() { printf 'PASS %s\n' "$1"; }
    fail() { printf 'FAIL %s\n' "$1"; fails=$((fails + 1)); }
    mkrepo() { # <dir>: a throwaway git repo with a registry, a scanroot and one registered script
        mkdir -p "$1/scripts" "$1/_tests/fixtures/zero-gap/x" "$1/other" "$1/.specify/extensions/vend"
        printf '#!/usr/bin/env bash\necho ok\n' >"$1/scripts/reg.sh"; chmod +x "$1/scripts/reg.sh"
        printf 'scanroot\tscripts\ncheck\treg\tscripts/reg.sh\tflag\t--prove-failure\t--root /nonexistent\n' >"$1/scripts/check-registry.tsv"
        printf '#   submodules/vend -> git@example.invalid:t/vend.git\n' >"$1/helix-deps.yaml"
        printf '#!/usr/bin/env bash\necho fx\n' >"$1/_tests/fixtures/zero-gap/x/f.sh"; chmod +x "$1/_tests/fixtures/zero-gap/x/f.sh"
        printf '#!/usr/bin/env bash\necho tp\n' >"$1/.specify/extensions/vend/t.sh"; chmod +x "$1/.specify/extensions/vend/t.sh"
    }
    commit() { git -C "$1" add -A >/dev/null 2>&1 && git -C "$1" -c user.name=t -c user.email=t@t -c commit.gpgsign=false commit -q -m t >/dev/null 2>&1; }
    newrepo() { rm -rf "$1"; mkdir -p "$1"; git -C "$1" init -q >/dev/null 2>&1; mkrepo "$1"; }
    run() { bash "$SELF" --root "$1" 2>&1; }

    newrepo "$T/c"; commit "$T/c"
    out=$(run "$T/c"); rc=$?
    if [ "$rc" -eq 0 ] && grep -q '^INSPECTED 1$' <<<"$out"; then pass "control: registered script, excluded fixture and third-party tree => rc 0, 1 item inspected"; else fail "control rc=$rc: $out"; fi

    newrepo "$T/u"; printf '#!/usr/bin/env bash\necho u\n' >"$T/u/scripts/new.sh"; chmod +x "$T/u/scripts/new.sh"; commit "$T/u"
    out=$(run "$T/u"); rc=$?
    if [ "$rc" -eq 1 ] && grep -q '^FINDING unregistered-scripts medium test-coverage scripts/new.sh ' <<<"$out"; then pass "planted unregistered executable script => finding, rc 1"; else fail "unregistered rc=$rc: $out"; fi

    newrepo "$T/d"; mkdir -p "$T/d/scripts/deep"; printf 'echo d\n' >"$T/d/scripts/deep/x.sh"; commit "$T/d"
    out=$(run "$T/d"); rc=$?
    if [ "$rc" -eq 1 ] && grep -q '^FINDING unregistered-scripts medium governance-drift scripts/deep/x.sh .*maxdepth-1' <<<"$out"; then pass "planted depth-2 script under a scanroot => blind-spot finding, rc 1"; else fail "depth-2 rc=$rc: $out"; fi

    newrepo "$T/m"; printf 'check\tgone\tscripts/gone.sh\tflag\t--prove-failure\t--root /nonexistent\n' >>"$T/m/scripts/check-registry.tsv"; commit "$T/m"
    out=$(run "$T/m"); rc=$?
    if [ "$rc" -eq 1 ] && grep -q '^FINDING unregistered-scripts high governance-drift scripts/check-registry.tsv:3 ' <<<"$out"; then pass "planted row with a missing entry-point => high finding, rc 1"; else fail "missing-entry rc=$rc: $out"; fi

    newrepo "$T/e"; git -C "$T/e" rm -q -f --cached scripts/reg.sh 2>/dev/null; rm -f "$T/e/scripts/reg.sh" "$T/e/_tests/fixtures/zero-gap/x/f.sh" "$T/e/.specify/extensions/vend/t.sh"; commit "$T/e"
    out=$(run "$T/e"); rc=$?
    if [ "$rc" -eq 2 ] && grep -q '^COULD-NOT-INSPECT population ' <<<"$out"; then pass "empty population => COULD-NOT-INSPECT, rc 2 (never clean)"; else fail "empty rc=$rc: $out"; fi

    tool_dir="$T/notools"; mkdir -p "$tool_dir"
    out=$(PATH="$tool_dir" /bin/bash "$SELF" --root "$T/c" 2>&1); rc=$?
    if [ "$rc" -eq 2 ] && grep -q '^COULD-NOT-INSPECT tool ' <<<"$out"; then pass "missing tools => COULD-NOT-INSPECT, rc 2"; else fail "no-tools rc=$rc: $out"; fi

    out=$(run /nonexistent-zg-root); rc=$?
    if [ "$rc" -eq 2 ]; then pass "--root /nonexistent => rc 2"; else fail "nonexistent rc=$rc: $out"; fi

    newrepo "$T/n"; rm -f "$T/n/scripts/check-registry.tsv"; commit "$T/n"
    out=$(run "$T/n"); rc=$?
    if [ "$rc" -eq 2 ]; then pass "missing registry => rc 2"; else fail "no-registry rc=$rc: $out"; fi

    newrepo "$T/x"; printf '#!/usr/bin/env bash\necho r\n' >"$T/x/scripts/zero-gap-class-foo.sh"; chmod +x "$T/x/scripts/zero-gap-class-foo.sh"; commit "$T/x"
    out=$(run "$T/x"); rc=$?
    if [ "$rc" -eq 0 ]; then pass "an unregistered zero-gap-class script is walked but not double-reported"; else fail "class-script rc=$rc: $out"; fi

    local cdir got want
    cdir="$(dirname "$SELF")/../_tests/fixtures/zero-gap/$CLASS_ID"
    if [ -d "$cdir/planted" ] && [ -d "$cdir/clean" ] && [ -f "$cdir/expect.tsv" ]; then
        cp -R "$cdir" "$T/fx"
        out=$(bash "$SELF" --root "$T/c" --corpus "$T/fx/planted" 2>&1); rc=$?
        got=$(grep '^FINDING ' <<<"$out" | awk '{print $5}' | LC_ALL=C sort -u)
        want=$(awk -F'\t' '!/^#/ && NF { print $1 }' "$T/fx/expect.tsv" | LC_ALL=C sort -u)
        if [ "$rc" -eq 1 ] && [ -n "$want" ] && [ "$got" = "$want" ]; then pass "corpus planted/: findings equal expect.tsv exactly ($(printf '%s\n' "$want" | awk 'END{print NR}') rows, nothing unexpected)"
        else fail "corpus planted rc=$rc missing: $(comm -23 <(printf '%s\n' "$want") <(printf '%s\n' "$got") | tr '\n' ' ') unexpected: $(comm -13 <(printf '%s\n' "$want") <(printf '%s\n' "$got") | tr '\n' ' ')"; fi
        out=$(bash "$SELF" --root "$T/c" --corpus "$T/fx/clean" 2>&1); rc=$?
        if [ "$rc" -eq 0 ] && ! grep -q '^FINDING' <<<"$out"; then pass "corpus clean/: no finding (spec-kit .specify/scripts, generated tree, x.sh.bak near-miss), rc 0"; else fail "corpus clean rc=$rc: $out"; fi
    else
        fail "corpus directory $cdir is incomplete"
    fi

    # every rc carries INSPECTED + POPULATION-SHA: a tracked script absent on disk (rc 2) ...
    newrepo "$T/a"; printf '#!/usr/bin/env bash\necho a\n' >"$T/a/scripts/gone2.sh"; chmod +x "$T/a/scripts/gone2.sh"; commit "$T/a"; rm -f "$T/a/scripts/gone2.sh"
    out=$(run "$T/a"); rc=$?
    if [ "$rc" -eq 2 ] && grep -q '^COULD-NOT-INSPECT scripts/gone2.sh tracked-but-absent-on-disk' <<<"$out" && grep -q '^INSPECTED 1$' <<<"$out" && grep -q '^POPULATION-SHA [0-9a-f]\{64\}$' <<<"$out"; then pass "a tracked script absent on disk => COULD-NOT-INSPECT, rc 2, INSPECTED and POPULATION-SHA still printed"; else fail "absent-on-disk rc=$rc: $out"; fi
    # ... with a finding next to it (rc 1)
    printf '#!/usr/bin/env bash\necho u\n' >"$T/a/scripts/new.sh"; chmod +x "$T/a/scripts/new.sh"; commit "$T/a"
    out=$(run "$T/a"); rc=$?
    if [ "$rc" -eq 1 ] && grep -q '^INSPECTED 2$' <<<"$out" && grep -q '^POPULATION-SHA ' <<<"$out"; then pass "finding + undetermined => rc 1 and the contract lines are printed"; else fail "finding+absent rc=$rc: $out"; fi
    out=$(run /nonexistent-zg-root); rc=$?
    if [ "$rc" -eq 2 ] && grep -q '^INSPECTED 0$' <<<"$out" && grep -q '^POPULATION-SHA ' <<<"$out"; then pass "--root /nonexistent prints INSPECTED 0 and POPULATION-SHA"; else fail "nonexistent contract rc=$rc: $out"; fi

    # a TRACKED symlink is never read (its target may sit outside the root)
    newrepo "$T/s"; ln -s /etc/hostname "$T/s/other/link.sh"; commit "$T/s"
    out=$(run "$T/s"); rc=$?
    if [ "$rc" -eq 2 ] && grep -q '^COULD-NOT-INSPECT other/link.sh not-a-regular-file' <<<"$out" && ! grep -q '^FINDING' <<<"$out"; then pass "a tracked symlink => COULD-NOT-INSPECT, not read"; else fail "symlink rc=$rc: $out"; fi

    # a reference list far larger than a pipe buffer is still found (no producer | grep -q under pipefail)
    newrepo "$T/r"; printf 'echo r\n' >"$T/r/other/refd.sh"; chmod +x "$T/r/other/refd.sh"
    mkdir -p "$T/r/docs/many"; for i in $(seq 1 1500); do printf 'see other/refd.sh\n' >"$T/r/docs/many/reference-file-with-a-long-name-to-fill-the-pipe-buffer-$i.md"; done
    out=$(bash "$SELF" --root "$T/r" --corpus "$T/r" 2>&1); rc=$?
    if [ "$rc" -eq 1 ] && grep -q '^FINDING unregistered-scripts medium test-coverage other/refd.sh .*named by path' <<<"$out"; then pass "a reference among 1500 referencing files (list > 64 KiB) is found in corpus mode"; else fail "large reference list rc=$rc: $(grep -v '^FINDING unregistered-scripts medium governance' <<<"$out" | head -5)"; fi

    # the shared exclusion block is byte-identical in the sibling class (one classification for both)
    local sib blkself blksib
    sib="$(dirname "$SELF")/zero-gap-class-unproven-checks.sh"
    blkself=$(sed -n '/^# >>> zg_thirdparty/,/^# <<< zg_thirdparty/p' "$SELF")
    if [ ! -f "$sib" ]; then echo "COULD-NOT-INSPECT shared-block the sibling class is absent: identity not judged"; undet=1
    else
        blksib=$(sed -n '/^# >>> zg_thirdparty/,/^# <<< zg_thirdparty/p' "$sib")
        if [ -n "$blkself" ] && [ "$blkself" = "$blksib" ]; then pass "the zg_thirdparty exclusion block is byte-identical in zero-gap-class-unproven-checks.sh"; else fail "the zg_thirdparty exclusion block differs from zero-gap-class-unproven-checks.sh"; fi
    fi

    # the live tree: status + content of every modified/untracked file, before vs after
    live_after=$(live_sum)
    if [ "$live_before" = "$live_after" ]; then pass "the live tree is byte-identical before and after the proof"
    else echo "COULD-NOT-INSPECT live-tree the live tree moved while the proof ran (another writer); the byte-identical assertion cannot be judged"; undet=1; fi

    if [ "$fails" -gt 0 ]; then echo "prove-failure: $fails case(s) failed"; return 1; fi
    if [ "$undet" -gt 0 ]; then echo "prove-failure: every case passed, $undet assertion(s) undetermined"; return 2; fi
    echo "prove-failure: all cases passed"; return 0
}

case "$PROVE" in
1) prove_failure; exit $? ;;
esac

cni() { printf 'COULD-NOT-INSPECT %s %s\n' "$1" "$2"; }

for t in git awk od sha256sum sort sed grep find head dirname basename mktemp; do
    command -v "$t" >/dev/null 2>&1 || fail_early tool "required-tool-missing:$t"
done
if [ -z "$ROOT" ] || [ ! -d "$ROOT" ]; then fail_early root "--root-is-not-a-directory"; fi
if [ -n "$CORPUS" ] && [ ! -d "$CORPUS" ]; then fail_early corpus "--corpus-is-not-a-directory"; fi
BASE=${CORPUS:-$ROOT}
if [ -z "$CORPUS" ] && ! git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1; then fail_early root "--root-is-not-a-git-repository"; fi
W=$(mktemp -d "${TMPDIR:-/tmp}/zg-unreg.XXXXXX") || fail_early tmp "mktemp-failed"
trap 'rm -rf "$W"' EXIT

# ---- exclusions: the shared third-party classification (zg_thirdparty) plus the corpora ----
# the entries are percent-encoded like the tokens they filter (a `/` stays `/`), so a prefix test on
# the encoded token is exact even for an entry holding a byte outside the safe set
{ zg_thirdparty_prefixes "$BASE"; printf '%s\n' "$FIXTURE_PFX"; } | LC_ALL=C sort -u | tr '\n' '\0' | zg_pct_encode_z >"$W/excl"

raw_items() {
    if [ -n "$CORPUS" ]; then
        ( cd "$CORPUS" && find . -name '*.sh' ! -type d -print0 ) | sed -z 's|^\./||'
    else
        git -C "$ROOT" ls-files -z -- '*.sh'
    fi
}

# tokens: encode first (a path holding a newline stays ONE token, %0A), then drop every token that
# equals an encoded exact entry or starts with an encoded tree entry
tokens() {
    raw_items | zg_pct_encode_z | awk 'NF' | zg_drop_excluded "$W/excl" | LC_ALL=C sort -u
}

TOKENS=$(tokens)
if [ "$EMIT" -eq 1 ]; then
    [ -n "$TOKENS" ] && printf '%s\n' "$TOKENS"
    exit 0
fi
SHA=$(if [ -n "$TOKENS" ]; then printf '%s\n' "$TOKENS" | sha256sum | cut -d' ' -f1; else echo "$EMPTY_SHA"; fi)
# finish <rc-candidate>: the contract lines are printed on EVERY rc from here on
finish() {
    echo "INSPECTED $n"
    echo "POPULATION-SHA $SHA"
    if [ "$found" -gt 0 ]; then exit 1; fi
    if [ "$bad" -gt 0 ]; then exit 2; fi
    exit 0
}
found=0 n=0 bad=0
if [ -z "$TOKENS" ]; then cni population "no-tracked-shell-script-after-exclusions-a-zero-size-population-is-never-clean"; bad=1; finish; fi

REG="$BASE/$REGISTRY_REL"
if [ -L "$REG" ] || [ ! -f "$REG" ] || [ ! -s "$REG" ]; then cni "$REGISTRY_REL" "registry-missing-empty-or-not-a-regular-file"; bad=1; finish; fi

# ---- registry: scanroots, known entry-points (with line numbers) ----
declare -A KNOWN=() ; SCANROOTS=() ; ROWS=()
while IFS=$'\t' read -r kind lineno path; do
    case "$kind" in
        scanroot) SCANROOTS+=("$path") ;;
        entry) KNOWN["$path"]=1; ROWS+=("$lineno"$'\t'"$path") ;;
        badtype) cni "$REGISTRY_REL:$lineno" "unrecognised-row-type"; bad=1; finish ;;
    esac
done < <(LC_ALL=C awk -F'\t' '
    /^[[:space:]]*$/ || /^#/ { next }
    $1 == "scanroot" && $2 != "" { print "scanroot\t" NR "\t" $2; next }
    ($1 == "check" || $1 == "debt") && $3 != "" { print "entry\t" NR "\t" $3; next }
    $1 == "exempt" && $2 != "" { print "entry\t" NR "\t" $2; next }
    { print "badtype\t" NR "\t-" }' "$REG")
if [ "${#SCANROOTS[@]}" -eq 0 ]; then cni "$REGISTRY_REL" "no-scanroot-declared"; bad=1; finish; fi

is_scanroot() { local d; for d in "${SCANROOTS[@]}"; do [ "$1" = "$d" ] && return 0; done; return 1; }
under_scanroot() { local d; for d in "${SCANROOTS[@]}"; do case "$1/" in "$d"/*) return 0 ;; esac; done; return 1; }

# referenced <rel path> -> 0 when ANOTHER tracked/corpus file names the path, the name ending there
# (`other/x.sh` is not a reference to `other/x.sh.bak` or `other/x.sh2`). No producer | grep -q
# pipeline: the file list goes through a temp file (pipefail would turn an early-exiting grep into
# a false "not referenced").
referenced() {
    local re
    re="$(printf '%s' "$1" | sed 's/[][\.*^$+?(){}|/]/\\&/g')([^A-Za-z0-9._-]|\$)"
    if [ -n "$CORPUS" ]; then
        grep -rlE -e "$re" -- "$BASE" >"$W/refs" 2>/dev/null
        LC_ALL=C awk -v self="$BASE/$1" -v reg="$BASE/$REGISTRY_REL" '$0 != self && $0 != reg { f = 1 } END { exit f ? 0 : 1 }' "$W/refs"
    else
        git -C "$ROOT" grep -lE -e "$re" -- . ":(exclude,literal)$1" ":(exclude,literal)$REGISTRY_REL" >/dev/null 2>&1
    fi
}

while IFS= read -r tok; do
    [ -n "$tok" ] || continue
    p=$(decode "$tok")
    if [ -L "$BASE/$p" ] || { [ -e "$BASE/$p" ] && [ ! -f "$BASE/$p" ]; }; then cni "$tok" "not-a-regular-file-symlink-or-special-not-read"; bad=1; continue; fi
    if [ ! -f "$BASE/$p" ]; then cni "$tok" "tracked-but-absent-on-disk"; bad=1; continue; fi
    n=$((n + 1))
    # R5 of scripts/verify-check-registry.sh already reports an unregistered scripts/zero-gap-class-*.sh
    # (scripts/ is a declared scanroot) and the sweep runner reports one no sweep-classes.tsv row lists
    case "$p" in scripts/zero-gap-class-*.sh) continue ;; esac
    [ -z "${KNOWN[$p]:-}" ] || continue
    dir=$(dirname "$p")
    if ! is_scanroot "$dir" && under_scanroot "$dir"; then
        echo "FINDING $CLASS_ID medium governance-drift $tok unregistered script below the maxdepth-1 boundary of a declared scanroot: R5 of scripts/verify-check-registry.sh cannot see it and no check/debt/exempt row names it $tok"
        found=$((found + 1)); continue
    fi
    [ -x "$BASE/$p" ] || continue
    why=""
    if [ "$(head -c2 -- "$BASE/$p" 2>/dev/null)" = '#!' ]; then why="executable with a shebang line"
    elif referenced "$p"; then why="executable and named by path in another tracked file"; fi
    [ -n "$why" ] || continue
    echo "FINDING $CLASS_ID medium test-coverage $tok unregistered script ($why): no check, debt or exempt row in $REGISTRY_REL names it $tok"
    found=$((found + 1))
done <<<"$TOKENS"

for row in "${ROWS[@]}"; do
    ln=${row%%$'\t'*}; ent=${row#*$'\t'}
    if [ ! -e "$BASE/$ent" ] && [ ! -L "$BASE/$ent" ]; then
        echo "FINDING $CLASS_ID high governance-drift $REGISTRY_REL:$ln registry row names an entry-point that does not exist ($(zg_pct_encode "$ent")): the row asserts a check that cannot run $REGISTRY_REL:$ln"
        found=$((found + 1))
    fi
done

finish
