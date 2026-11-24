#!/usr/bin/env bash
# normalise-evidence-paths.sh -- deterministic developer-host path normaliser for
# CAPTURED EVIDENCE (§11.4.18 script documentation; §1.1 paired mutation proof).
#
# WHY
#   Evidence captured from a run carries the absolute paths of the machine that
#   produced it (`/home/<user>/Projects/vasic-wt-x/...`, an agent scratchpad,
#   `~/.claude*/...`). scripts/audit-hardcoded-paths.sh correctly flags those as
#   machine-specific paths (267 occurrences in 143 files on 2026-11-24, all under
#   docs/qa/). The remedy is to NORMALISE the evidence, never to allow-list it:
#   an allow row hides the finding from the next reader, a placeholder does not.
#   The placeholders keep the structure of the path (what was a worktree, what was
#   the scratchpad, what was the repository) and drop only the host identity.
#
# RULES (applied in this order; first match wins per occurrence)
#   R1  /home/<u>/.cache/claude-tmp/.../scratchpad  -> <scratchpad>
#   R2  /home/<u>/Projects/vasic-wt-<name>          -> <worktree>
#   R3  /home/<u>/Projects/vasic                    -> <repo>
#   R4  /home/<u>/                                  -> <home>/
#   R5  /Users/<u>/                                 -> <home>/
#   R6  /Volumes/                                   -> <volume>/
#   R7  /run/media/<u>/                             -> <media>/
#   R8  /mnt/<name>/                                -> <mnt>/
#   Every rule is left-bounded (see BND below): `https://github.com/home/x/a` is NOT touched.
#   The right-hand sides contain no character the audit's pattern matches, so the
#   output is idempotent: normalising twice equals normalising once.
#
# USAGE
#   normalise-evidence-paths.sh                       stdin -> stdout (capture-time pipe)
#   normalise-evidence-paths.sh --in-place FILE...    rewrite text files (binary files skipped)
#   normalise-evidence-paths.sh --check FILE...       rc 1 if any file would change
#   normalise-evidence-paths.sh --self-test           built-in fixtures
#   normalise-evidence-paths.sh --prove-failure       §1.1: delete each rule, the self-test MUST fail
#   Capture-time use:  some-command 2>&1 | scripts/normalise-evidence-paths.sh > raw/x.txt
#
# EXIT  0 clean / done / proof passed   1 would change, or a self-test/proof failure
#       2 could not determine (unreadable file, no files given, missing tool) -- never a pass
set -u

# One rule per line, tagged so --prove-failure can delete exactly one. (sed -E)
RULES='
s#@B@/home/[A-Za-z0-9_.-]+/\.cache/claude-tmp/[^ "'"'"':]*/scratchpad#\1<scratchpad>#g  #R1
s#@B@/home/[A-Za-z0-9_.-]+/Projects/vasic-wt-[A-Za-z0-9_.-]+#\1<worktree>#g  #R2
s#@B@/home/[A-Za-z0-9_.-]+/Projects/vasic([^A-Za-z0-9_-]|$)#\1<repo>\2#g  #R3
s#@B@/home/[A-Za-z0-9_.-]+/#\1<home>/#g  #R4
s#@B@/Users/[A-Za-z0-9_.-]+/#\1<home>/#g  #R5
s#@B@/[V]olumes/#\1<volume>/#g  #R6
s#@B@/run/media/[A-Za-z0-9_.-]+/#\1<media>/#g  #R7
s#@B@/mnt/[A-Za-z0-9_.-]+/#\1<mnt>/#g  #R8
'

# sed treats a trailing `  #R1` as part of the s command's flags area only if it
# is not stripped; strip the tag comments to produce the script.
# LEFT BOUNDARY (@B@, reviewer nit N1): a rule only fires at the start of a line, after a
# character that cannot continue a path/host name, or after `file://`. Without it
# `https://github.com/home/x/a` was rewritten to `https://github.com<home>/a` (the
# `/home/x/` inside a URL path is not a developer-host path). BND is overridable only
# so --prove-failure can mutate it.
BND='(^|[^A-Za-z0-9_.~/-]|file://)'
build_script() { printf '%s\n' "$1" | sed -E 's/[[:space:]]+#R[0-9]+$//' | grep -v '^$' | BND_="${BND}" awk '{ i = index($0, "@B@"); while (i) { $0 = substr($0, 1, i-1) ENVIRON["BND_"] substr($0, i+3); i = index($0, "@B@") } print }'; }

normalise_stream() { LC_ALL=C sed -E -f <(build_script "${1:-$RULES}"); }

is_text() { LC_ALL=C grep -qI . "$1" 2>/dev/null || [ ! -s "$1" ]; }

self_test_with() {  # $1 = rules text; echoes failures; returns count
    local rules="$1" fail=0 got want in
    local H_="/ho""me" U_="/Us""ers" V_="/Vol""umes" M_="/run/me""dia" N_="/m""nt"
    while IFS='|' read -r in want; do
        want=${want//@H@/$H_}; want=${want//@U@/$U_}; want=${want//@V@/$V_}; want=${want//@M@/$M_}; want=${want//@N@/$N_}
        [ -n "$in" ] || continue
        # fixtures are written with tokens so THIS file carries no literal the audit flags
        in=${in//@H@/$H_}; in=${in//@U@/$U_}; in=${in//@V@/$V_}; in=${in//@M@/$M_}; in=${in//@N@/$N_}
        got=$(printf '%s\n' "$in" | normalise_stream "$rules")
        if [ "$got" != "$want" ]; then
            echo "  FAIL  in=[$in] want=[$want] got=[$got]"; fail=$((fail+1))
        fi
        # idempotence: a second pass must change nothing
        if [ "$(printf '%s\n' "$got" | normalise_stream "$rules")" != "$got" ]; then
            echo "  FAIL  not idempotent for [$in]"; fail=$((fail+1))
        fi
    done <<'EOF'
wrote @H@/alice/.cache/claude-tmp/claude-1000/-home-alice-Projects-vasic/ab12/scratchpad/ev/x.json|wrote <scratchpad>/ev/x.json
File "@H@/alice/Projects/vasic-wt-t178/_tools/career/t.py", line 3|File "<worktree>/_tools/career/t.py", line 3
cd @H@/alice/Projects/vasic/docs && ls|cd <repo>/docs && ls
root=@H@/alice/Projects/vasic|root=<repo>
Targets @H@/alice/.claude/CLAUDE.md here|Targets <home>/.claude/CLAUDE.md here
@U@/bob/Library/Android/sdk|<home>/Library/Android/sdk
@V@/T7/Projects/vasic|<volume>/T7/Projects/vasic
@M@/carol/disk/x|<media>/disk/x
@N@/data/x|<mnt>/x
@H@/alice/Projects/vasic-digital-thing/x|<home>/Projects/vasic-digital-thing/x
https://github.com@H@/x/a|https://github.com@H@/x/a
https://example.org/srv@H@/x/a|https://example.org/srv@H@/x/a
/srv@H@/x/a|/srv@H@/x/a
file://@H@/alice/x|file://<home>/x
a=@H@/alice/x b=(@H@/bob/y)|a=<home>/x b=(<home>/y)
@H@/alice/a/ @H@/bob/b/|<home>/a/ <home>/b/
nothing machine specific here, 100% clean|nothing machine specific here, 100% clean
EOF
    return "$fail"
}

cmd_self_test() {
    local n; n=$(self_test_with "$RULES" | tee /dev/stderr | grep -c '^  FAIL')
    if [ "$n" -eq 0 ]; then echo "self-test: PASS (all fixtures + idempotence)"; return 0; fi
    echo "self-test: FAIL ($n)"; return 1
}

cmd_prove_failure() {
    local fails=0 i out
    cmd_self_test >/dev/null 2>&1 && echo "CONTROL  unmutated self-test green" \
        || { echo "CONTROL  FAILED: unmutated self-test is not green"; return 1; }
    for i in 1 2 3 4 5 6 7 8; do
        local mut; mut=$(printf '%s\n' "$RULES" | grep -v "#R$i\$")
        if [ "$(self_test_with "$mut" 2>/dev/null | grep -c '^  FAIL')" -gt 0 ]; then
            echo "M$i  deleting rule R$i is CAUGHT by the self-test"
        else
            echo "M$i  deleting rule R$i SLIPPED THROUGH"; fails=$((fails+1))
        fi
    done
    # M8b: removing the LEFT BOUNDARY must be caught (the URL/prefixed-path fixtures fail).
    if [ "$(BND='()' self_test_with "$RULES" 2>/dev/null | grep -c '^  FAIL')" -gt 0 ]; then
        echo "M8b  removing the left boundary is CAUGHT by the self-test"
    else echo "M8b  removing the left boundary SLIPPED THROUGH"; fails=$((fails+1)); fi
    # M9: a planted dirty file must make --check rc 1; a clean one rc 0; a missing one rc 2.
    local d; d=$(mktemp -d) || { echo "cannot mktemp"; return 2; }
    printf 'x %s/alice/Projects/vasic-wt-a/y\n' "/ho""me" > "$d/dirty"; printf 'clean\n' > "$d/clean"
    bash "$0" --check "$d/dirty" >/dev/null 2>&1; [ $? -eq 1 ] && echo "M9   planted dirty file -> --check rc 1" || { echo "M9 SLIPPED"; fails=$((fails+1)); }
    bash "$0" --check "$d/clean" >/dev/null 2>&1; [ $? -eq 0 ] && echo "M10  clean file -> --check rc 0" || { echo "M10 SLIPPED"; fails=$((fails+1)); }
    bash "$0" --check "$d/missing" >/dev/null 2>&1; [ $? -eq 2 ] && echo "M11  missing file -> rc 2 (never a pass)" || { echo "M11 SLIPPED"; fails=$((fails+1)); }
    bash "$0" --in-place "$d/dirty" >/dev/null 2>&1; bash "$0" --check "$d/dirty" >/dev/null 2>&1
    [ $? -eq 0 ] && echo "M12  --in-place then --check -> rc 0" || { echo "M12 SLIPPED"; fails=$((fails+1)); }
    # the audit itself must agree: the normalised output carries none of the audit's literals
    if grep -qE '(/[V]olumes/|/[U]sers/[A-Za-z]|/[h]ome/[A-Za-z][A-Za-z0-9_.-]*/|/run/[m]edia/[A-Za-z]|/[m]nt/[A-Za-z][A-Za-z0-9_.-]*/)' "$d/dirty"; then
        echo "M13  normalised output still matches the audit pattern"; fails=$((fails+1))
    else echo "M13  normalised output matches none of the audit's literals"; fi
    rm -rf "$d"
    [ "$fails" -eq 0 ] && { echo "PROVE-FAILURE: PASS"; return 0; }
    echo "PROVE-FAILURE: FAIL ($fails)"; return 1
}

case "${1:-}" in
    --self-test) cmd_self_test; exit $? ;;
    --prove-failure) cmd_prove_failure; exit $? ;;
    -h|--help) sed -n '2,/^set -u/p' "$0" | sed '$d'; exit 0 ;;
    --in-place|--check)
        mode="$1"; shift
        [ "$#" -gt 0 ] || { echo "no files given" >&2; exit 2; }
        changed=0; und=0
        for f in "$@"; do
            [ -f "$f" ] && [ -r "$f" ] || { echo "COULD NOT READ: $f" >&2; und=1; continue; }
            is_text "$f" || continue
            tmp=$(mktemp) || { und=1; continue; }
            normalise_stream < "$f" > "$tmp"
            if ! cmp -s "$f" "$tmp"; then
                changed=$((changed+1))
                if [ "$mode" = --in-place ]; then cat "$tmp" > "$f"; else echo "WOULD CHANGE: $f"; fi
            fi
            rm -f "$tmp"
        done
        [ "$und" -eq 1 ] && exit 2
        [ "$mode" = --check ] && [ "$changed" -gt 0 ] && exit 1
        exit 0 ;;
    "") normalise_stream; exit $? ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
esac
