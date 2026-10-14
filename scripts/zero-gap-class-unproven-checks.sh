#!/usr/bin/env bash
# zero-gap-class-unproven-checks.sh — sweep class `unproven-checks` (feature 010, T021; SC-007, FR-001, FR-013).
#
# WHAT IT DETECTS (§1.1 paired mutation: a check with no proof that it can FAIL is a bluff waiting to happen)
#   For every `check` row of scripts/check-registry.tsv, statically:
#     - entry-point missing or not executable                         high   false-evidence
#     - proof-kind `flag`: the proof-arg flag has no `case` arm in the entry, or the arm is a STUB
#       (only echo/printf/true/:/exit/return/shift, or it sets only variables nothing else reads)   high   false-evidence
#     - proof-kind `sibling`: the named proof script is absent or empty                              high   false-evidence
#     - any other proof-kind                                                                         high   false-evidence
#     - the documented undetermined probe: when it is exactly `--root /nonexistent`, it is RUN. THIS CLASS
#       EXECUTES EVERY REGISTERED ENTRY POINT whose probe is that argv: `bash <entry> --root /nonexistent`
#       with cwd = the inspected root, stdin /dev/null, a scrubbed environment (PATH HOME TMPDIR LC_ALL
#       only), TMPDIR = a scratch directory, `timeout 10`; it must exit 2, another code is  high   false-evidence
#       (a probe that exceeds 10 s is COULD-NOT-INSPECT, never a pass). Any other probe form is not run.
#   For every `debt` row: MEDIUM test-coverage "declared without proof", naming lifting_authority and
#   next_review; an elapsed or malformed next_review is HIGH governance-drift.
#   For every `exempt` row: HIGH governance-drift when next_review is elapsed/malformed or the file is missing;
#   MEDIUM test-coverage when the exempt file's name is gate-like (verify/audit/check/prove/guard/gate/lint/
#   validate/challenge) — an exemption over a gate is a check without a proof by declaration.
#   For every tracked *.sh that R5 (scripts/verify-check-registry.sh) does NOT cover: MEDIUM test-coverage when
#   its name is gate-like and it has no proof mode, where a proof mode is ANY of: a case arm for
#   --prove-failure|--selftest|--self-test|--prove|--mutation|--mutate|--anti-bluff-mutate or the POSITIONAL
#   mode word `mutate` (`case "${1:-normal}" in normal) ..;; mutate) ..;;`); a `[ "$1" == <one of them> ]` /
#   `[[ ... ]]` test; a sibling `*mutation*.sh` / `prove-*<name>*.sh` in its directory; or a proof-like file
#   in its directory (name holding prove/mutation/test/selftest/anti-bluff) that names the script inside its
#   text. A proof arm that exists but is a STUB is HIGH false-evidence.
#   SUBMODULE-REGISTRY EXEMPTIONS (operator decision #26, docs/operator-decisions-2026-10-14-session.md): that
#   MEDIUM name-rule finding is NOT emitted for a script an owned submodule's OWN tracked check registry
#   (`check-registry*.tsv` at any depth of that gitlink, rows `exempt <module-relative path> <reason>`) exempts —
#   and only when ALL hold: the row names that EXACT regular file (no directory, link, prefix or glob), its reason
#   is non-blank, no registry of the same submodule names the file as a check/debt entry point, and the file's
#   name does not declare a verdict gate by its leading verb (verify|audit|check|guard|gate|lint|validate). The
#   exemption silences only the name rule: a stub proof arm is still reported. Not a blanket allow, not a name skip.
#     exempt row with a blank/absent reason, naming a missing file, or naming a non-regular file   high  governance-drift
#     exempt row refused (verdict-gate name, or contradicted by a check/debt row)                  high  governance-drift
#   Fail-closed: a registry that is tracked but absent, unreadable, not a regular file, carries a NUL/CR byte,
#   has a row type outside scanroot|prune|exempt|check|debt, an exempt row with more than three fields, or an
#   exempt path that is empty/absolute/not normal (`.`/`..`/`//`) is COULD-NOT-INSPECT (rc 2 unless a finding
#   outranks it) and NO exemption of that whole submodule is honoured. Reason text is never printed (a submodule
#   may be private): findings name paths and line numbers only.
#
# POPULATION (identical for --emit-population and the live run; typed tokens, sorted, unique, LC_ALL=C)
#   check:<id>   debt:<id>   exempt:<path>     one per registry row (docs/zero-gap sweep-classes.tsv row unproven-checks:
#                                              check+debt rows; exempt rows are added because the class brief names them)
#   <path>       every `git ls-files -z '*.sh'` of the umbrella and of every gitlink that is neither third-party
#                nor the governance source, MINUS scripts R5 covers (dirname is exactly a declared scanroot),
#                MINUS _tests/fixtures/zero-gap/, MINUS paths already named by a registry row (attributed to that
#                row). Third-party is the SHARED classification `zg_thirdparty` (identical in
#                zero-gap-class-unregistered-scripts.sh; each proof asserts the copies are byte-identical),
#                derived from tracked data: helix-deps.yaml's `#   <path> -> <url>` third-party comment block
#                (+ its `.specify/extensions/<name>/` mirror), config/covenant_propagation_exclusions.tsv rows
#                of class vendored-third-party or generated-code, and `.specify/scripts/bash/` (spec-kit's vendored
#                tooling, controller ruling 2026-09-26), each read in the umbrella AND in every walked
#                gitlink (the submodule's own data, prefixed with its path). The governance SOURCE is the gitlink that supplies
#                scripts/gates/lib/pointer_carrier.sh (the evidence C1 of scripts/verify-governance-cascade.sh
#                uses; today submodules/constitution) — consumed here, audited by its own sweep.
#                A tracked path holding a NEWLINE is refused (COULD-NOT-INSPECT naming its %0A token), never
#                split; a symlink or special file is COULD-NOT-INSPECT, never read.
#   subregistry:<path>  every tracked check-registry*.tsv of every walked gitlink (decision #26), minus the shared
#                third-party classification; a finding about one of its rows is located at <path>:<line>.
#   With --corpus <dir> the tree is <dir> itself (a scratch tree holding scripts/check-registry.tsv); scripts are
#   found with find, there are no gitlinks: the submodules are the paths <dir>/.gitmodules declares (an absent
#   one is COULD-NOT-INSPECT), and their registries are found with find; locations are relative to <dir>.
#   INSPECTED is the number of population items actually READ (a COULD-NOT-INSPECT item is not counted).
#
# EXIT CODES  0 clean (full non-empty population inspected)  1 at least one FINDING  2 could not determine
#   (registry absent/empty, zero population, a needed tool missing, an uninitialised gitlink, a probe timeout).
#   INSPECTED and POPULATION-SHA are printed on every rc of an inspection run.
#
# PRECISION (measured by hand on the live tree, 2026-09-26 fix round) — 103 findings (all MEDIUM test-coverage,
#   uncovered gate-like scripts in owned submodules), INSPECTED 836 of 837 items (one tracked symlink,
#   submodules/qa/scripts/anti-bluff-scan.sh, is COULD-NOT-INSPECT). 10 hits read by hand (every 10th): 10 of 10
#   carry no proof mode of any recognised form and no proof-like file in their directory names them = 10/10 true
#   as stated. The previous round's 115 included 13 false hits of two families now recognised (8 positional
#   `mutate` / --anti-bluff-mutate / [[ $1 == --mutate ]] modes; 3 sibling proofs naming the target) plus 2
#   submodule spec-kit helpers now excluded. What stays unmeasured: whether each `*_challenge.sh` is a GATE
#   (the name heuristic) and whether a challenges/ meta-test elsewhere proves it.
#   2026-10-14 (decision #26), measured on the live tree before and after: 101 -> 100 findings, the ONLY row that
#   left is workshop/pipeline/run_audit.sh (exempted by workshop's check-registry-001.tsv); the other 100 rows are
#   byte-identical. INSPECTED 921 -> 928: the seven owned-submodule registries are now read population items.
#
# WHAT IT DOES NOT SEE
#   A proof arm that runs real code but asserts nothing (semantic vacuity) — that is class `vacuous-gates`.
#   Proofs are NOT executed (they take ~33 minutes in total; scripts/verify-check-registry.sh --run-proofs does).
#   Probes whose argv is not exactly `--root /nonexistent` are not run. "Gate-like" is a NAME heuristic: a gate
#   named unlike the vocabulary above is not reported; a non-gate named like one is (and is reported as a finding
#   that says the name is the evidence; names with test/mutation/self-validate parts or an install/setup prefix are
#   treated as proofs or installers, not gates). Several arms for one flag (a heredoc-embedded fixture gate) are all
#   judged: a stub is reported only when EVERY arm found is a stub. Submodule scripts are judged by name and arm only.
#   A sibling proof in ANOTHER directory (a challenges/ meta-test naming the script) is not seen.
#   Whether a submodule-exempted script is REALLY not a gate is the submodule's own judgement (its reason); this
#   class only enforces the row's shape, existence and the two refusal rules above. A verdict gate named with
#   neither a leading gate verb nor a check/debt row in its own submodule's registries can still be exempted.
#   Submodule registries are judged only for `exempt` rows and the closed row vocabulary; their check/debt rows are
#   not verified here (each submodule's own meta-check does that). Registries outside a file named
#   check-registry*.tsv, and registries of the governance source or of third-party gitlinks, are not read.
#
# Usage: --root <abs dir> [--corpus <abs dir>] [--emit-population]      |   --prove-failure
set -uo pipefail
export LC_ALL=C PYTHONDONTWRITEBYTECODE=1
ID=unproven-checks

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

SELF=$(readlink -f "$0" 2>/dev/null || echo "$0")
EMPTY_SHA=e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855   # sha256 of the empty population
ROOT="" CORPUS="" EMIT=0 PROVE=0
# fail_early <part> <reason>: nothing was enumerated. An inspection run still prints INSPECTED 0 and
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

need_tools() {
    local b miss=""
    for b in awk sed grep sort git date timeout sha256sum od find mktemp cut tr readlink xargs; do
        command -v "$b" >/dev/null 2>&1 || miss+=" $b"
    done
    if [ -n "$miss" ]; then NEED_MISSING="required-tool-missing:${miss// /,}"; NEED_MISSING=${NEED_MISSING%,}; return 1; fi
    return 0
}

decode() { printf '%b' "$(printf '%s' "$1" | sed 's/%\([0-9A-F][0-9A-F]\)/\\x\1/g')"; }
enc() { zg_pct_encode "$1"; }

# ── proof mode ───────────────────────────────────────────────────────────────
if [ "$PROVE" -eq 1 ]; then
    need_tools || { echo "COULD-NOT-INSPECT tools $NEED_MISSING"; exit 2; }
    FIX="$(cd "$(dirname "$SELF")/.." && pwd)/_tests/fixtures/zero-gap/$ID"
    if [ ! -d "$FIX/planted" ] || [ ! -d "$FIX/clean" ] || [ ! -f "$FIX/expect.tsv" ]; then
        echo "prove-failure: cannot determine — corpus $FIX incomplete"; exit 2
    fi
    T=$(mktemp -d) || { echo "prove-failure: cannot determine — mktemp failed"; exit 2; }
    trap 'rm -rf "$T"' EXIT
    pass=0 failn=0 muts=0
    ok() { echo "PASS $*"; pass=$((pass + 1)); }
    bad() { echo "FAIL $*"; failn=$((failn + 1)); }
    # run <dir> [args...] -> RC, OUT (self run against a throwaway tree)
    run() { local d=$1; shift; OUT=$(cd "$d" && env -i PATH="$PATH" HOME="${HOME:-/}" TMPDIR="$T" LC_ALL=C bash "$SELF" --root "$d" --corpus "$d" "$@" 2>&1); RC=$?; }
    fpr() { ( cd "$1" && find . -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum; find . -type f -perm -u+x -print0 | LC_ALL=C sort -z | xargs -0 printf '%s\n' ) | sha256sum | cut -d' ' -f1; }
    has() { grep -q -- "$1" <<<"$OUT"; }
    mk() { rm -rf "$T/$1"; mkdir -p "$T/$1"; cp -a "$FIX/$2/." "$T/$1/"; }
    own_before=$( { sha256sum "$SELF"; fpr "$FIX"; } | sha256sum | cut -d' ' -f1)
    LIVE="$(cd "$(dirname "$SELF")/.." && pwd)"
    live_sum() {
        ( cd "$LIVE" && {
            git --no-optional-locks status --porcelain=v1 -z --ignore-submodules=all 2>/dev/null
            git --no-optional-locks ls-files -z -m -o --exclude-standard 2>/dev/null | xargs -0 -r sha256sum -- 2>/dev/null
        } | sha256sum | cut -d' ' -f1 )
    }
    live_before=$(live_sum)

    mk ctl clean; run "$T/ctl"
    if [ "$RC" -eq 0 ] && has '^INSPECTED [1-9]'; then ok "M0 control: the clean corpus exits 0 with a non-empty inspected population"; else bad "M0 control rc=$RC: $OUT"; fi

    mk pl planted; run "$T/pl"; before=$(fpr "$T/pl"); run "$T/pl"; after=$(fpr "$T/pl")
    # EXACT set: every expect.tsv row reported AND nothing else (a surviving mutation that drops one
    # finding kind, or invents one, fails here)
    got=$(grep '^FINDING ' <<<"$OUT" | awk '{print $5}' | LC_ALL=C sort -u)
    want=$(awk -F'\t' '!/^#/ && NF { print $1 }' "$FIX/expect.tsv" | LC_ALL=C sort -u)
    total=$(printf '%s\n' "$want" | awk 'NF' | awk 'END{print NR}')
    if [ "$RC" -eq 1 ] && [ "$total" -gt 0 ] && [ "$got" = "$want" ]; then ok "M1 planted corpus: rc 1 and the findings equal expect.tsv exactly ($total rows, recall 1.0, nothing unexpected)"
    else bad "M1 planted rc=$RC missing: $(comm -23 <(printf '%s\n' "$want") <(printf '%s\n' "$got") | tr '\n' ' ') unexpected: $(comm -13 <(printf '%s\n' "$want") <(printf '%s\n' "$got") | tr '\n' ' ')"; fi
    # severity + category of the rows whose location alone cannot tell two branches apart (a
    # malformed date must be HIGH governance-drift, not the MEDIUM "declared without proof" branch)
    sevmiss=""
    for want_line in "high governance-drift debt:bad-date" "high governance-drift debt:lapsed-debt" "medium test-coverage debt:owed-proof" \
        "high governance-drift exempt:scripts/exempt-baddate.sh" "high governance-drift exempt:scripts/gone-exempt.sh" \
        "high governance-drift exempt:scripts/verify-lapsed-ex.sh" "medium test-coverage exempt:scripts/verify-gatey.sh" \
        "high false-evidence check:odd-kind" "high false-evidence tools/sub/verify-stubarm.sh" "medium test-coverage tools/sub/verify-noproof.sh" \
        "high governance-drift subregistry:mods/owned/gates/check-registry-own.tsv:4" "high governance-drift subregistry:mods/owned/gates/check-registry-own.tsv:5" \
        "high governance-drift subregistry:mods/owned/gates/check-registry-own.tsv:7" "high governance-drift subregistry:mods/owned/gates/check-registry-own.tsv:8" \
        "medium test-coverage mods/owned/tools/verify-wrongly.sh" "medium test-coverage mods/owned/tools/checked_audit.sh" "medium test-coverage mods/owned/tools/noreason_audit.sh"; do
        has "^FINDING $ID $want_line " || sevmiss+=" [$want_line]"
    done
    muts=$((muts + 1))
    if [ -z "$sevmiss" ]; then ok "M1b planted rows carry the documented severity and category (dates, exemptions, vocabulary, stub arm)"; else bad "M1b wrong or missing severity/category:$sevmiss"; fi
    if [ "$before" = "$after" ]; then ok "M2 the scanned tree is byte-identical before and after a run"; else bad "M2 the scanned tree changed during a run"; fi
    muts=$((muts + 2))

    # each mutation edits ONE property of a clean copy and must produce a finding at the named location
    k=2
    mut() { # location description target expr(@chmod|@rm|sed script)
        local loc=$1 desc=$2 tgt=$3 expr=$4
        k=$((k + 1)); muts=$((muts + 1)); mk "m$k" clean
        if [ "$expr" = "@chmod" ]; then chmod -x "$T/m$k/$tgt"; elif [ "$expr" = "@rm" ]; then rm -f "$T/m$k/$tgt"; else sed -i "$expr" "$T/m$k/$tgt"; fi
        run "$T/m$k"
        if [ "$RC" -eq 1 ] && has "^FINDING $ID [a-z]* [a-z-]* $loc "; then ok "M$k $desc => finding at $loc"; else bad "M$k $desc rc=$RC (want 1 with a finding at $loc)"; fi
    }
    mut check:ok-real "the proof arm is removed from a clean entry" scripts/ok-real.sh 's/--prove-failure)/--other)/'
    mut check:ok-real "the proof arm is reduced to an echo" scripts/ok-real.sh 's/--prove-failure) run_proof; exit \$? ;;/--prove-failure) echo done; exit 0 ;;/'
    mut check:ok-real "the entry loses its executable bit" scripts/ok-real.sh @chmod
    mut check:ok-real "the entry file is removed" scripts/ok-real.sh @rm
    mut check:ok-sibling "the sibling proof is removed" scripts/ok_mutation_test.sh @rm
    mut check:ok-real "the undetermined probe stops exiting 2" scripts/ok-real.sh 's/exit 2/exit 0/'
    mut exempt:scripts/install-thing.sh "an exemption's next_review is elapsed" scripts/check-registry.tsv 's/2999-12-31/2020-01-01/'
    k=$((k + 1)); muts=$((muts + 1)); mk pathgate clean
    printf '#!/usr/bin/env bash\nexit 0\n' >"$T/pathgate/tools/sub/audit-thing.sh"; chmod +x "$T/pathgate/tools/sub/audit-thing.sh"; run "$T/pathgate"
    if [ "$RC" -eq 1 ] && has "^FINDING $ID [a-z]* [a-z-]* tools/sub/audit-thing.sh "; then ok "M$k a gate-like script outside R5's depth with no proof arm => finding"; else bad "M$k rc=$RC"; fi

    # ── operator decision #26: an owned submodule's OWN registry may exempt one exact non-gate file, with a
    # reason; anything less is not honoured and is reported. Every case edits a throwaway copy of clean/.
    SR=mods/owned/gates/check-registry-own.tsv SS=mods/owned/tools/stage_audit.sh
    flagged() { has "^FINDING $ID medium test-coverage $SS "; }
    # sx <name> <description> <assertion> <edit...>: one property edited, then the assertion is evaluated
    sx() {
        local nm=$1 desc=$2 cond=$3; shift 3
        k=$((k + 1)); muts=$((muts + 1)); mk "$nm" clean; ( cd "$T/$nm" && eval "$*" ); run "$T/$nm"
        if eval "$cond"; then ok "M$k $desc"; else bad "M$k $desc rc=$RC: $(grep -E '^(FINDING|COULD)' <<<"$OUT" | tr '\n' '|')"; fi
    }
    k=$((k + 1)); muts=$((muts + 1)); mk sx0 clean; run "$T/sx0"
    pop0=$(cd "$T/sx0" && env -i PATH="$PATH" HOME="${HOME:-/}" TMPDIR="$T" LC_ALL=C bash "$SELF" --root "$T/sx0" --corpus "$T/sx0" --emit-population 2>/dev/null)
    if [ "$RC" -eq 0 ] && ! flagged && grep -qxF "$SS" <<<"$pop0" && grep -qxF "subregistry:$SR" <<<"$pop0"; then ok "M$k a reasoned exemption for the exact file in an owned submodule's registry is honoured: rc 0, the script stays in the population (inspected, not skipped) and the registry is a population item"
    else bad "M$k honoured exemption rc=$RC: $OUT"; fi
    sx sxa "exemption without a reason => not honoured, the script is flagged and the row is a finding" \
        '[ "$RC" -eq 1 ] && flagged && has "^FINDING $ID high governance-drift subregistry:$SR:4 "' \
        "sed -i 's/^\(exempt\ttools\/stage_audit.sh\)\t.*/\1/' $SR"
    sx sxa2 "exemption whose reason is only blanks => not honoured, flagged, row reported" \
        '[ "$RC" -eq 1 ] && flagged && has "^FINDING $ID high governance-drift subregistry:$SR:4 "' \
        "sed -i 's/^\(exempt\ttools\/stage_audit.sh\)\t.*/\1\t   /' $SR"
    sx sxb "exemption naming a DIFFERENT existing file => the real script is still flagged, the other is not" \
        '[ "$RC" -eq 1 ] && flagged && ! has "mods/owned/tools/stage_audit2.sh " && ! has "subregistry:"' \
        "cp -p mods/owned/tools/stage_audit.sh mods/owned/tools/stage_audit2.sh; sed -i 's|tools/stage_audit.sh|tools/stage_audit2.sh|' $SR"
    sx sxb2 "exemption naming the script's DIRECTORY (a blanket allow) => not honoured, flagged, row reported" \
        '[ "$RC" -eq 1 ] && flagged && has "^FINDING $ID high governance-drift subregistry:$SR:4 "' \
        "sed -i 's|^exempt\ttools/stage_audit.sh|exempt\ttools|' $SR"
    sx sxb3 "exemption naming a PREFIX of the file name (not the exact file) => not honoured, flagged" \
        '[ "$RC" -eq 1 ] && flagged && has "^FINDING $ID high governance-drift subregistry:$SR:4 "' \
        "sed -i 's|^exempt\ttools/stage_audit.sh|exempt\ttools/stage_aud|' $SR"
    sx sxc "registry missing => the exemption is gone and the script is flagged (never a silent pass)" \
        '[ "$RC" -eq 1 ] && flagged' "rm -f $SR"
    sx sxc2 "registry unreadable => COULD-NOT-INSPECT naming it, exemption not honoured" \
        '[ "$RC" -ne 0 ] && flagged && has "^COULD-NOT-INSPECT subregistry:$SR "' "chmod 000 $SR"
    sx sxd "registry malformed (row type outside the closed vocabulary) => COULD-NOT-INSPECT, exemption not honoured" \
        '[ "$RC" -ne 0 ] && flagged && has "^COULD-NOT-INSPECT subregistry:$SR "' "printf 'bogus\tx\n' >>$SR"
    sx sxd2 "registry malformed and nothing else to report => rc 2 exactly, never 0" \
        '[ "$RC" -eq 2 ] && has "^COULD-NOT-INSPECT subregistry:$SR " && ! has "^FINDING"' \
        "rm -f mods/owned/tools/stage_audit.sh; sed -i '/^exempt/d' $SR; printf 'bogus\tx\n' >>$SR"
    sx sxd3 "registry malformed (exempt row with an extra field) => COULD-NOT-INSPECT, not honoured" \
        '[ "$RC" -ne 0 ] && flagged && has "^COULD-NOT-INSPECT subregistry:$SR "' "sed -i 's/^\(exempt\t.*\)$/\1\textra/' $SR"
    sx sxd4 "registry malformed (an exempt path escaping the submodule with ..) => COULD-NOT-INSPECT" \
        '[ "$RC" -ne 0 ] && flagged && has "^COULD-NOT-INSPECT subregistry:$SR "' "printf 'exempt\t../../scripts/ok-real.sh\tescape\n' >>$SR"
    sx sxd5 "registry malformed (a CR line ending) => COULD-NOT-INSPECT, not honoured" \
        '[ "$RC" -ne 0 ] && flagged && has "^COULD-NOT-INSPECT subregistry:$SR "' "sed -i 's/\$/\r/' $SR"
    sx sxe "exemption for a file that does not exist => the row itself is a finding" \
        '[ "$RC" -eq 1 ] && ! flagged && has "^FINDING $ID high governance-drift subregistry:$SR:5 "' \
        "printf 'exempt\ttools/ghost_audit.sh\treason given\n' >>$SR"
    sx sxf "a verdict gate (leading gate verb) wrongly exempted => refused: row finding and the gate is flagged" \
        '[ "$RC" -eq 1 ] && has "^FINDING $ID high governance-drift subregistry:$SR:5 " && has "^FINDING $ID medium test-coverage mods/owned/tools/verify-stage.sh "' \
        "cp -p mods/owned/tools/stage_audit.sh mods/owned/tools/verify-stage.sh; printf 'exempt\ttools/verify-stage.sh\tclaimed not a gate\n' >>$SR"
    sx sxf2 "a script the same submodule registers as a check entry point, also exempted => refused: row finding, flagged" \
        '[ "$RC" -eq 1 ] && flagged && has "^FINDING $ID high governance-drift subregistry:$SR:4 "' \
        "printf 'check\tc1\ttools/stage_audit.sh\tflag\t--prove-failure\t--root /nonexistent\n' >>$SR"
    sx sxf3 "the contradicting check row sits in a SIBLING registry of the same submodule => still refused" \
        '[ "$RC" -eq 1 ] && flagged && has "^FINDING $ID high governance-drift subregistry:$SR:4 "' \
        "printf 'check\tc1\tshell\ttools/stage_audit.sh\ttools/prove-x.sh\n' >mods/owned/gates/check-registry-two.tsv"
    sx sxg "the registry's directory is not a declared submodule (.gitmodules entry removed) => not honoured, flagged" \
        '[ "$RC" -eq 1 ] && flagged' "rm -f .gitmodules"
    sx sxg2 "a declared submodule path that is absent => COULD-NOT-INSPECT, never clean" \
        '[ "$RC" -eq 2 ] && has "^COULD-NOT-INSPECT gitlink:mods/ghost "' \
        "printf '[submodule \"mods/ghost\"]\n\tpath = mods/ghost\n\turl = x\n' >>.gitmodules"

    # empty / absent population, broken tool, absent registry: never clean
    mkdir -p "$T/empty/scripts"; printf 'scanroot\tscripts\n' >"$T/empty/scripts/check-registry.tsv"; run "$T/empty"; k=$((k + 1)); muts=$((muts + 1))
    if [ "$RC" -eq 2 ] && has '^COULD-NOT-INSPECT'; then ok "M$k a registry with no rows and no scripts (empty population) => rc 2, never clean"; else bad "M$k rc=$RC"; fi
    mkdir -p "$T/noreg"; run "$T/noreg"; k=$((k + 1)); muts=$((muts + 1))
    if [ "$RC" -eq 2 ] && has '^COULD-NOT-INSPECT'; then ok "M$k an absent registry => rc 2"; else bad "M$k rc=$RC"; fi
    OUT=$(cd "$T/ctl" && env -i PATH="$T/nothing" LC_ALL=C "$BASH" "$SELF" --root "$T/ctl" --corpus "$T/ctl" 2>&1); RC=$?; k=$((k + 1)); muts=$((muts + 1))
    if [ "$RC" -eq 2 ] && has '^COULD-NOT-INSPECT tools'; then ok "M$k a missing tool (empty PATH) => rc 2 naming the tool"; else bad "M$k rc=$RC: $OUT"; fi
    OUT=$(bash "$SELF" --root /nonexistent 2>&1); RC=$?; k=$((k + 1)); muts=$((muts + 1))
    if [ "$RC" -eq 2 ] && has '^COULD-NOT-INSPECT' && has '^INSPECTED 0$' && has "^POPULATION-SHA $EMPTY_SHA\$"; then ok "M$k --root /nonexistent => rc 2, INSPECTED 0 and POPULATION-SHA still printed"; else bad "M$k rc=$RC: $OUT"; fi

    # INSPECTED counts items READ: a symlinked uncovered script is COULD-NOT-INSPECT and not counted
    k=$((k + 1)); muts=$((muts + 1)); mk sym clean
    ln -s /etc/hostname "$T/sym/tools/sub/verify-linked.sh"; run "$T/sym"
    ntok=$(cd "$T/sym" && env -i PATH="$PATH" HOME="${HOME:-/}" TMPDIR="$T" LC_ALL=C bash "$SELF" --root "$T/sym" --corpus "$T/sym" --emit-population 2>/dev/null | awk 'END{print NR}')
    if [ "$RC" -eq 2 ] && has '^COULD-NOT-INSPECT tools/sub/verify-linked.sh ' && has "^INSPECTED $((ntok - 1))\$" && ! has '^FINDING'; then ok "M$k a symlinked script is COULD-NOT-INSPECT, never read, and INSPECTED ($((ntok - 1))) is one less than the population ($ntok)"; else bad "M$k rc=$RC ntok=$ntok: $OUT"; fi

    # VSC-372: an in-tree symlink to a regular file is an ALIAS of the (already inspected) target: no
    # COULD-NOT-INSPECT, counted as inspected, no second finding; a dangling link stays COULD-NOT-INSPECT
    k=$((k + 1)); muts=$((muts + 1)); mk al planted
    ln -s verify-noproof.sh "$T/al/tools/sub/verify-alias.sh"; ln -s no-such-target.sh "$T/al/tools/sub/verify-dangling.sh"; run "$T/al"
    ntok=$(cd "$T/al" && env -i PATH="$PATH" HOME="${HOME:-/}" TMPDIR="$T" LC_ALL=C bash "$SELF" --root "$T/al" --corpus "$T/al" --emit-population 2>/dev/null | awk 'END{print NR}')
    nfind=$(grep -c '^FINDING .* tools/sub/verify-noproof.sh ' <<<"$OUT")
    if [ "$RC" -eq 1 ] && ! has '^COULD-NOT-INSPECT tools/sub/verify-alias.sh' && has '^COULD-NOT-INSPECT tools/sub/verify-dangling.sh ' && ! has '^FINDING .* tools/sub/verify-alias.sh ' && [ "$nfind" -eq 1 ]; then ok "M$k an in-tree symlink is an alias of its inspected target (no CNI, no second finding); a dangling link stays COULD-NOT-INSPECT"; else bad "M$k rc=$RC nfind=$nfind: $OUT"; fi

    # live mode, throwaway git repositories: a tracked path holding a NEWLINE is refused (not split);
    # a third-party gitlink named in helix-deps.yaml and the governance source are not walked, an
    # owned gitlink is
    k=$((k + 1)); muts=$((muts + 1)); G="$T/git"; rm -rf "$G"; mkdir -p "$G/scripts"
    gi() { git -C "$1" -c user.name=zg -c user.email=zg@example.invalid -c commit.gpgsign=false -c core.hooksPath=/dev/null "${@:2}"; }
    cp -a "$FIX/clean/scripts/." "$G/scripts/"
    mksub() { mkdir -p "$G/$1/tools"; printf '#!/usr/bin/env bash\nexit 0\n' >"$G/$1/tools/audit-$2.sh"; chmod +x "$G/$1/tools/audit-$2.sh"; [ -z "${3:-}" ] || { mkdir -p "$G/$1/scripts/gates/lib"; : >"$G/$1/scripts/gates/lib/pointer_carrier.sh"; }; [ -z "${4:-}" ] || { mkdir -p "$G/$1/.specify/scripts/bash"; printf '#!/usr/bin/env bash\nexit 0\n' >"$G/$1/.specify/scripts/bash/check-prerequisites.sh"; }; git init -q "$G/$1" && gi "$G/$1" add -A && gi "$G/$1" commit -q -m f; }
    # decision #26: the owned gitlink carries its OWN registry exempting one exact non-gate (honoured); the
    # governance source carries one too (never read: that gitlink is not walked)
    mkdir -p "$G/owned/tools" "$G/owned/gates" "$G/gov/tools" "$G/gov/gates"
    cp -p "$FIX/clean/mods/owned/tools/stage_audit.sh" "$G/owned/tools/stage_audit.sh"
    cp -p "$FIX/clean/mods/owned/gates/check-registry-own.tsv" "$G/owned/gates/check-registry-own.tsv"
    printf 'exempt\ttools/audit-gov.sh\tnever read\n' >"$G/gov/gates/check-registry-gov.tsv"
    mksub vendor/tp tp; mksub owned own "" speckit; mksub gov gov yes
    printf '#   vendor/tp -> git@example.invalid:someone/tp.git\n' >"$G/helix-deps.yaml"
    printf '#!/usr/bin/env bash\nexit 0\n' >"$G/scripts/verify-nl
x.sh"
    git init -q "$G" && gi "$G" add -A 2>/dev/null && gi "$G" commit -q -m f
    OUT=$(cd "$G" && env -i PATH="$PATH" HOME="${HOME:-/}" TMPDIR="$T" LC_ALL=C bash "$SELF" --root "$G" 2>&1); RC=$?
    if has '^COULD-NOT-INSPECT scripts/verify-nl%0Ax.sh tracked-path-contains-a-newline' && has '^FINDING unproven-checks medium test-coverage owned/tools/audit-own.sh ' && ! has 'vendor/tp/tools/audit-tp.sh' && ! has 'gov/tools/audit-gov.sh' && ! has 'owned/.specify/scripts/bash/check-prerequisites.sh' && ! grep -q '^FINDING [^ ]* [^ ]* [^ ]* x.sh ' <<<"$OUT"; then ok "M$k live mode: newline path refused (not split), third-party gitlink (helix-deps.yaml) and governance source not walked, owned gitlink walked minus its own spec-kit .specify/scripts/bash"; else bad "M$k rc=$RC: $OUT"; fi
    k=$((k + 1)); muts=$((muts + 1))
    if ! has 'owned/tools/stage_audit.sh' && ! has 'gov/gates/' && ! has '^COULD-NOT-INSPECT subregistry:'; then ok "M$k live mode: a tracked registry inside an owned gitlink is read and its reasoned exact exemption honoured; the governance source's registry is never read"; else bad "M$k rc=$RC: $OUT"; fi
    rm -f "$G/owned/gates/check-registry-own.tsv"
    OUT=$(cd "$G" && env -i PATH="$PATH" HOME="${HOME:-/}" TMPDIR="$T" LC_ALL=C bash "$SELF" --root "$G" 2>&1); RC=$?
    k=$((k + 1)); muts=$((muts + 1))
    if [ "$RC" -ne 0 ] && has '^COULD-NOT-INSPECT subregistry:owned/gates/check-registry-own.tsv ' && has '^FINDING unproven-checks medium test-coverage owned/tools/stage_audit.sh '; then ok "M$k live mode: a TRACKED submodule registry missing from the worktree => COULD-NOT-INSPECT naming it and the exemption is not honoured"; else bad "M$k rc=$RC: $OUT"; fi

    # the shared exclusion block is byte-identical in the sibling class (one classification for both)
    k=$((k + 1)); muts=$((muts + 1)); SIB="$(dirname "$SELF")/zero-gap-class-unregistered-scripts.sh"
    blk() { sed -n '/^# >>> zg_thirdparty/,/^# <<< zg_thirdparty/p' "$1"; }
    if [ ! -f "$SIB" ]; then echo "COULD-NOT-INSPECT shared-block sibling class $SIB absent: identity not judged"; UND=1
    elif [ -n "$(blk "$SELF")" ] && [ "$(blk "$SELF")" = "$(blk "$SIB")" ]; then ok "M$k the zg_thirdparty exclusion block is byte-identical in zero-gap-class-unregistered-scripts.sh"
    else bad "M$k the zg_thirdparty exclusion block differs from zero-gap-class-unregistered-scripts.sh"; fi
    own_after=$( { sha256sum "$SELF"; fpr "$FIX"; } | sha256sum | cut -d' ' -f1)
    k=$((k + 1)); muts=$((muts + 1))
    if [ "$own_before" = "$own_after" ]; then ok "M$k this class's own script and corpus are byte-identical before and after the proof (all mutations ran on throwaway copies)"; else bad "M$k own files changed"; fi
    live_after=$(live_sum)
    k=$((k + 1)); muts=$((muts + 1))
    if [ "$live_before" = "$live_after" ]; then ok "M$k the live tree is byte-identical before and after (status + content of every modified/untracked file)"
    else echo "COULD-NOT-INSPECT live-tree the live tree moved while the proof ran (another writer); the byte-identical assertion cannot be judged"; UND=1; fi
    echo "$pass passed, $failn failed, $muts mutations"
    [ "$failn" -eq 0 ] || exit 1
    [ "${UND:-0}" -eq 0 ] || exit 2
    exit 0
fi

# ── inspection mode ──────────────────────────────────────────────────────────
need_tools || fail_early tools "$NEED_MISSING"
if [ -z "$ROOT" ] || [ ! -d "$ROOT" ]; then fail_early root "not-a-directory"; fi
if [ -n "$CORPUS" ] && [ ! -d "$CORPUS" ]; then fail_early corpus "not-a-directory"; fi
BASE=${CORPUS:-$ROOT}
REG="$BASE/scripts/check-registry.tsv"
REGREL=scripts/check-registry.tsv
W=$(mktemp -d) || fail_early tmp mktemp-failed
trap 'rm -rf "$W"' EXIT
CNI="$W/cni"; : >"$CNI"
cni() { printf 'COULD-NOT-INSPECT %s %s\n' "$1" "$2" >>"$CNI"; }

if [ ! -f "$REG" ] || [ ! -r "$REG" ] || [ ! -s "$REG" ]; then
    fail_early "$(enc "$REGREL")" registry-absent-unreadable-or-empty
fi
# rows: type US lineno US f2..f9 (US keeps empty fields; tab-collapsing `read` would shift them)
awk -F'\t' 'BEGIN { OFS = "\037" } /^#/ || /^[ \t]*$/ { next } { print $1, NR, $2, $3, $4, $5, $6, $7, $8, $9 }' "$REG" >"$W/rows"
grep -a '^scanroot' "$W/rows" | awk -F'\037' '{ print $3 }' >"$W/scanroots"
if [ ! -s "$W/scanroots" ]; then fail_early "$(enc "$REGREL")" registry-declares-no-scanroot; fi

# registered paths (entry-points, sibling proofs are NOT registered paths; exempt paths)
awk -F'\037' '$1=="check"||$1=="debt" { print $4 } $1=="exempt" { print $3 }' "$W/rows" | LC_ALL=C sort -u >"$W/registered"

covered_by_r5() { local d; d=$(dirname -- "$1"); grep -qxF -- "$d" "$W/scanroots"; }

# uncovered scripts -> $W/paths (raw, one per line). A tracked path holding a newline cannot be one
# line: it is REFUSED (COULD-NOT-INSPECT naming its encoded form), never split into two paths.
: >"$W/paths"
zg_thirdparty_prefixes "$BASE" | LC_ALL=C sort -u >"$W/excl"
printf '_tests/fixtures/zero-gap/\n' >>"$W/excl"
# nl_split <prefix>: NUL-separated paths on stdin -> newline-separated on stdout (prefixed), paths
# holding a newline refused
nl_split() {
    local p
    while IFS= read -r -d '' p; do
        case "$p" in *$'\n'*) cni "$(enc "$1$p")" "tracked-path-contains-a-newline-and-is-refused"; continue ;; esac
        printf '%s%s\n' "$1" "$p"
    done
}
# sub_registries <sub>: NUL-separated registry paths (relative to <sub>) on stdin -> "<sub> US <rel>" lines in
# $W/subregs.raw; a path holding a newline is refused, never split
sub_registries() {
    local r
    while IFS= read -r -d '' r; do
        case "$r" in *$'\n'*) cni "subregistry:$(enc "$1/$r")" "registry-path-contains-a-newline-and-is-refused"; continue ;; esac
        printf '%s\037%s\n' "$1" "$r" >>"$W/subregs.raw"
    done
}
: >"$W/subregs.raw"
collect_paths() {
    local sub
    : >"$W/all"
    if [ -n "$CORPUS" ]; then
        ( cd "$BASE" && find . -name '*.sh' ! -type d -print0 ) | sed -z 's|^\./||' | nl_split "" >>"$W/all"
        # a scratch corpus has no gitlinks: its submodules are the paths its own .gitmodules declares
        if [ -L "$BASE/.gitmodules" ]; then cni .gitmodules "a-symlink-and-is-not-read"
        elif [ -f "$BASE/.gitmodules" ]; then
            git config -f "$BASE/.gitmodules" --get-regexp '^submodule\..*\.path$' 2>/dev/null | cut -d' ' -f2- | LC_ALL=C sort -u >"$W/cgl"
            while IFS= read -r sub; do
                [ -n "$sub" ] || continue
                if [[ $sub =~ ^/|(^|/)\.\.?(/|$)|//|/$ ]]; then cni "gitlink:$(enc "$sub")" "declared-submodule-path-is-not-a-normal-relative-path"; continue; fi
                if [ -L "$BASE/$sub" ] || [ ! -d "$BASE/$sub" ]; then cni "gitlink:$(enc "$sub")" "gitlink-not-initialised-or-has-no-checked-out-commit"; continue; fi
                ( cd "$BASE/$sub" && find . -name 'check-registry*.tsv' ! -type d -print0 ) | sed -z 's|^\./||' | sub_registries "$sub"
            done <"$W/cgl"
        fi
    else
        git -C "$ROOT" ls-files -z -- '*.sh' >"$W/all.z" || { cni umbrella git-ls-files-failed; return; }
        nl_split "" <"$W/all.z" >>"$W/all"
        git -C "$ROOT" ls-files -s -z | tr '\0' '\n' | awk -F'\t' '$1 ~ /^160000 / { print $2 }' >"$W/gitlinks"
        while IFS= read -r sub; do
            [ -n "$sub" ] || continue
            # third-party (derived, shared classification) and the governance SOURCE (the gitlink that
            # supplies scripts/gates/lib/pointer_carrier.sh, the evidence C1 of
            # scripts/verify-governance-cascade.sh uses) are not walked
            if [ -z "$(printf '%s\n' "$sub/x" | zg_drop_excluded "$W/excl")" ]; then continue; fi
            if [ -f "$ROOT/$sub/scripts/gates/lib/pointer_carrier.sh" ]; then continue; fi
            if [ -z "$(git -C "$ROOT/$sub" rev-parse --verify -q HEAD 2>/dev/null)" ]; then
                cni "gitlink:$(enc "$sub")" "gitlink-not-initialised-or-has-no-checked-out-commit"; continue
            fi
            if git -C "$ROOT/$sub" ls-files -z -- '*.sh' >"$W/sub.z" 2>/dev/null; then
                nl_split "$sub/" <"$W/sub.z" >>"$W/all"
                # decision #26: the submodule's OWN tracked check registries (any depth) are read for exemptions
                if git -C "$ROOT/$sub" ls-files -z -- ':(glob)**/check-registry*.tsv' >"$W/subreg.z" 2>/dev/null; then
                    sub_registries "$sub" <"$W/subreg.z"
                else
                    cni "gitlink:$(enc "$sub")" "submodule-registries-could-not-be-listed"
                fi
                # the submodule's OWN tracked data classifies its own vendored trees (its helix-deps.yaml,
                # covenant exclusions, its spec-kit .specify/scripts/bash/), prefixed with its path
                zg_thirdparty_prefixes "$ROOT/$sub" | sed "s|^|$sub/|" >>"$W/excl"
            else
                cni "gitlink:$(enc "$sub")" "gitlink-not-initialised-or-unreadable"
            fi
        done <"$W/gitlinks"
    fi
    zg_drop_excluded "$W/excl" <"$W/all" | while IFS= read -r p; do
        [ -n "$p" ] || continue
        covered_by_r5 "$p" && continue
        grep -qxF -- "$p" "$W/registered" && continue
        printf '%s\n' "$p"
    done >>"$W/paths"
}
collect_paths
# a registry inside a tree the shared classification calls third-party or generated is not the module's own
: >"$W/subregs"
while IFS=$'\037' read -r s r; do
    [ -n "$(printf '%s/%s\n' "$s" "$r" | zg_drop_excluded "$W/excl")" ] && printf '%s\037%s\n' "$s" "$r" >>"$W/subregs"
done < <(LC_ALL=C sort -u "$W/subregs.raw")

# tokens
tokens() {
    local ty
    {
        # ':' is a safe byte, so "<type>:" + encode(value) equals encode("<type>:value"); batch-encode per type
        for ty in check debt exempt; do
            awk -F'\037' -v t="$ty" '$1 == t { printf "%s\0", $3 }' "$W/rows" | zg_pct_encode_z | sed "s/^/$ty:/"
        done
        tr '\n' '\0' <"$W/paths" | zg_pct_encode_z
        awk -F'\037' '{ printf "%s/%s\0", $1, $2 }' "$W/subregs" | zg_pct_encode_z | sed 's/^/subregistry:/'
    } | awk 'NF' | LC_ALL=C sort -u
}
TOK=$(tokens)
if [ "$EMIT" -eq 1 ]; then
    if [ -s "$CNI" ]; then cat "$CNI" >&2; exit 2; fi
    if [ -n "$TOK" ]; then printf '%s\n' "$TOK"; fi
    exit 0
fi
if [ -z "$TOK" ]; then cat "$CNI"; echo "COULD-NOT-INSPECT population empty:no-check-rows-and-no-uncovered-scripts"; echo "INSPECTED 0"; echo "POPULATION-SHA $EMPTY_SHA"; exit 2; fi

FOUND=0
finding() { # sev cat location desc ref
    printf 'FINDING %s %s %s %s %s %s\n' "$ID" "$1" "$2" "$3" "$4" "$5"; FOUND=$((FOUND + 1))
}

# arm_body <file> <flag> [ordinal] -> prints the body of the ordinal-th (default 1st) case arm for <flag>; rc 1 when there is none
arm_body() {
    local f=$1 flag=$2 ord=${3:-1} n line body cnt=0
    n=$(grep -nE -- "(^|[[:space:]|(])${flag}[[:space:]]*(\|[^)]*)?\)" "$f" | grep -vE '^[0-9]+:[[:space:]]*#' | sed -n "${ord}p" | cut -d: -f1)
    [ -n "$n" ] || return 1
    body=""
    while IFS= read -r line; do
        cnt=$((cnt + 1)); [ "$cnt" -gt 60 ] && break
        if [ "$cnt" -eq 1 ]; then line=$(printf '%s' "$line" | sed -E "s/^.*${flag}[[:space:]]*(\|[^)]*)?\)//"); fi
        case "$line" in *';;'*) body+="${line%%;;*}"$'\n'; break ;; esac
        body+="$line"$'\n'
    done < <(sed -n "${n},\$p" "$f")
    printf '%s' "$body"
    return 0
}

# is_stub <file> <body> -> 0 when the arm cannot run a proof; sets STUB_WHY
is_stub() {
    local f=$1 body=$2 cmds c w vars="" v real=0 hasassign=0 live=0
    cmds=$(printf '%s\n' "$body" | sed -E 's/#.*$//; s/&&|\|\||;|\{|\}/\n/g' | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//' | awk 'NF')
    while IFS= read -r c; do
        [ -n "$c" ] || continue
        w=${c%%[[:space:]]*}
        if [[ $w =~ ^([A-Za-z_][A-Za-z0-9_]*)=.*$ ]]; then hasassign=1; vars+=" ${BASH_REMATCH[1]}"; continue; fi
        case "$w" in echo|printf|true|:|shift|exit|return) ;; *) real=1 ;; esac
    done <<<"$cmds"
    if [ "$real" -eq 1 ]; then return 1; fi
    if [ "$hasassign" -eq 1 ]; then
        for v in $vars; do
            # a read is $v / ${v} / a bare name inside (( )) arithmetic (declare/assignments do not count)
            if grep -Eq -e "\\\$\\{?${v}([^A-Za-z0-9_]|\$)" -e "\\(\\(([^)]*[^A-Za-z0-9_\$])?${v}([^A-Za-z0-9_=]|\$)" "$f"; then live=1; fi
        done
        if [ "$live" -eq 1 ]; then return 1; fi
        STUB_WHY="the arm only sets variable(s)${vars} that nothing else in the file reads"
    else
        STUB_WHY="the arm only echoes, shifts or exits and runs no proof"
    fi
    return 0
}

# arm_verdict <file> <flag> -> 1 no arm; 2 an arm exists and one of them is real (a heredoc-embedded fixture arm cannot
# hide the real one); 0 every arm found is a stub (STUB_WHY set from the first)
arm_verdict() {
    local f=$1 flag=$2 o=0 b any=0 firstwhy=""
    while b=$(arm_body "$f" "$flag" $((o + 1))); do
        o=$((o + 1)); any=1; STUB_WHY=""
        if ! is_stub "$f" "$b"; then return 2; fi
        [ -n "$firstwhy" ] || firstwhy=$STUB_WHY
        [ "$o" -ge 20 ] && break
    done
    [ "$any" -eq 1 ] || return 1
    STUB_WHY=$firstwhy; return 0
}

# proof-mode vocabulary: a flag arm, or the POSITIONAL mode word `mutate` (`case "${1:-normal}" in
# normal) ...;; mutate) ...;;`), or the same words tested with [ ] / [[ ]] against $1
PROOF_WORDS="--prove-failure --selftest --self-test --prove --mutation --mutate --anti-bluff-mutate mutate"
has_proof_arm() { # file -> 0 a real proof-mode arm; 1 none; 2 only stub arms
    local f=$1 fl v stub=0
    for fl in $PROOF_WORDS; do
        arm_verdict "$f" "$fl"; v=$?
        case "$v" in 2) return 0 ;; 0) stub=1 ;; esac
    done
    if grep -Eq -- '\[\[?[[:space:]]+"?\$\{?1(:-[^}]*)?\}?"?[[:space:]]+==?[[:space:]]+"?(--prove-failure|--selftest|--self-test|--prove|--mutation|--mutate|--anti-bluff-mutate|mutate)"?[[:space:]]' "$f"; then return 0; fi
    [ "$stub" -eq 1 ] && return 2
    return 1
}
# sibling_proof <dir> <basename>: 0 when a proof-like file in the same directory (name holding
# prove / mutation / test / selftest / anti-bluff) names the script inside its text (a path ending in
# the basename, not followed by another name character)
sibling_proof() {
    local d=$1 b=$2 s sb re
    re=$(printf '%s' "$b" | sed 's/[][\.*^$+?(){}|/]/\\&/g')
    for s in "$BASE/$d"/*; do
        [ -f "$s" ] && [ ! -L "$s" ] || continue
        sb=${s##*/}
        [ "$sb" = "$b" ] && continue
        case "$sb" in *prove*|*mutation*|*test*|*selftest*|*anti-bluff*|*anti_bluff*) ;; *) continue ;; esac
        grep -Eq -- "(^|[^A-Za-z0-9._-])${re}([^A-Za-z0-9._-]|\$)" "$s" 2>/dev/null && return 0
    done
    return 1
}

gate_like() { # basename -> 0 gate-like, non-test
    local b=$1
    [[ $b =~ (^|[-_.])(test|tests|mutation)([-_.]|$) ]] && return 1
    [[ $b =~ ^(prove)[-_] ]] && return 1
    [[ $b =~ self[-_]?validat ]] && return 1
    [[ $b =~ ^(install|uninstall|setup)[-_] ]] && return 1
    [[ $b =~ ^(verify|audit|check|prove|guard|gate|lint|validate)[-_.] ]] && return 0
    [[ $b =~ [-_](verify|audit|check|gate|lint|validate|challenge|guard)\.sh$ ]] && return 0
    [[ $b =~ ^[a-z0-9_-]*(challenge)[a-z0-9_-]*\.sh$ ]] && return 0
    return 1
}

today=$(date +%F)
elapsed() { # date -> 0 elapsed, 1 valid future/today, 2 malformed
    [[ $1 =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || return 2
    if [[ $1 < $today ]]; then return 0; fi
    return 1
}

n=0
# ---- registry rows
while IFS=$'\037' read -r ty ln f2 f3 f4 f5 f6 f7 f8 f9; do
    case "$ty" in check|debt|exempt) ;; *) continue ;; esac
    n=$((n + 1)); ref="$REGREL:$ln"
    case "$ty" in
    check)
        loc="check:$(enc "$f2")"; entry=$f3; kind=$f4; arg=$f5; probe=$f6
        if [ ! -f "$BASE/$entry" ]; then finding high false-evidence "$loc" "check $(enc "$f2") names entry-point $(enc "$entry") which does not exist, so its proof cannot run" "$ref"; continue; fi
        if [ ! -x "$BASE/$entry" ]; then finding high false-evidence "$loc" "check $(enc "$f2") entry-point $(enc "$entry") is not executable, so the registry's own contract is broken" "$ref"; continue; fi
        case "$kind" in
        flag)
            flag=${arg%% *}
            case "$flag" in
                --*) ;;
                *) finding high false-evidence "$loc" "check $(enc "$f2") proof-arg is not a flag" "$ref"; continue ;;
            esac
            arm_verdict "$BASE/$entry" "$flag"; av=$?
            if [ "$av" -eq 1 ]; then
                finding high false-evidence "$loc" "check $(enc "$f2") declares proof flag $flag but $(enc "$entry") has no case arm for it" "$(enc "$entry")"
            elif [ "$av" -eq 0 ]; then
                finding high false-evidence "$loc" "check $(enc "$f2") proof arm $flag in $(enc "$entry") is a stub: $STUB_WHY" "$(enc "$entry")"
            fi ;;
        sibling)
            if [ ! -s "$BASE/$arg" ]; then finding high false-evidence "$loc" "check $(enc "$f2") names sibling proof $(enc "$arg") which is absent or empty" "$ref"; fi ;;
        *) finding high false-evidence "$loc" "check $(enc "$f2") has proof-kind $(enc "$kind") outside the closed vocabulary flag|sibling" "$ref" ;;
        esac
        if [ "$probe" = "--root /nonexistent" ]; then
            prc=0
            ( cd "$BASE" && env -i PATH="$PATH" HOME="${HOME:-/}" TMPDIR="$W" LC_ALL=C timeout 10 bash "$entry" --root /nonexistent ) </dev/null >/dev/null 2>&1 || prc=$?
            if [ "$prc" -eq 124 ]; then cni "$loc" "undetermined-probe-exceeded-10s-and-was-terminated"
            elif [ "$prc" -ne 2 ]; then finding high false-evidence "$loc" "check $(enc "$f2") undetermined probe --root /nonexistent exited $prc, not 2: unable-to-verify is not distinguished from pass or fail" "$(enc "$entry")"; fi
        fi ;;
    debt)
        loc="debt:$(enc "$f2")"; elapsed "$f8"; er=$?
        if [ "$er" -eq 0 ]; then finding high governance-drift "$loc" "debt row $(enc "$f2") owes ${f4// /_} and its next_review $f8 has elapsed (lifting_authority=$(enc "${f6:-none}"))" "$ref"
        elif [ "$er" -eq 2 ]; then finding high governance-drift "$loc" "debt row $(enc "$f2") owes ${f4// /_} and carries no valid ISO next_review, so its expiry cannot be verified" "$ref"
        else finding medium test-coverage "$loc" "debt row $(enc "$f2") is declared without proof (owed=${f4// /_}) until next_review $f8 by lifting_authority=$(enc "${f6:-none}")" "$ref"; fi ;;
    exempt)
        loc="exempt:$(enc "$f2")"; elapsed "$f6"; er=$?
        if [ ! -e "$BASE/$f2" ]; then finding high governance-drift "$loc" "exempt row names $(enc "$f2") which does not exist" "$ref"
        elif [ "$er" -eq 0 ]; then finding high governance-drift "$loc" "exempt row for $(enc "$f2") has next_review $f6 elapsed (lifting_authority=$(enc "${f4:-none}"))" "$ref"
        elif [ "$er" -eq 2 ]; then finding high governance-drift "$loc" "exempt row for $(enc "$f2") carries no valid ISO next_review, so its expiry cannot be verified" "$ref"
        elif gate_like "$(basename -- "$f2")"; then finding medium test-coverage "$loc" "exempt row covers $(enc "$f2") whose name is gate-like: declared without a paired proof until $f6 (lifting_authority=$(enc "${f4:-none}"))" "$ref"; fi ;;
    esac
done <"$W/rows"

# ---- submodule registries (operator decision #26, 2026-10-14): an owned submodule's OWN check registry may exempt
# one EXACT file from the gate-name rule, with a reason. Fail-closed: a registry that is absent, unreadable, not a
# regular file or malformed is COULD-NOT-INSPECT and honours nothing for its WHOLE submodule (the contradiction test
# below would be incomplete). Reason text is never printed: a submodule may be private; paths and lines only.
: >"$W/subex" ; : >"$W/subent" ; : >"$W/subbad" ; : >"$W/subexok"
while IFS=$'\037' read -r s r; do
    f="$BASE/$s/$r"; rl="subregistry:$(enc "$s/$r")"
    if [ -L "$f" ] || [ ! -f "$f" ] || [ ! -r "$f" ]; then
        cni "$rl" "registry-absent-unreadable-or-not-a-regular-file-so-no-exemption-of-$(enc "$s")-is-honoured"; printf '%s\n' "$s" >>"$W/subbad"; continue
    fi
    if [ "$(sha256sum <"$f")" != "$(tr -d '\000\r' <"$f" | sha256sum)" ]; then
        cni "$rl" "registry-malformed:carries-a-NUL-or-CR-byte-so-no-exemption-of-$(enc "$s")-is-honoured"; printf '%s\n' "$s" >>"$W/subbad"; continue
    fi
    # closed row vocabulary (the union every registry of this convention uses); `#` and blank lines are inert
    awk -F'\t' '
        /^#/ || /^[ \t]*$/ { next }
        $1 !~ /^(scanroot|prune|exempt|check|debt)$/ { print "BAD\037" NR "\037row-type-outside-the-closed-vocabulary"; exit }
        $1 == "exempt" {
            if (NF > 3) { print "BAD\037" NR "\037exempt-row-has-more-than-three-fields"; exit }
            p = $2
            if (p == "" || p ~ /^\// || p ~ /(^|\/)\.\.?(\/|$)/ || p ~ /\/\//) { print "BAD\037" NR "\037exempt-path-empty-absolute-or-not-normal"; exit }
            rs = $3; gsub(/[ \t]/, "", rs)
            print "EX\037" NR "\037" p "\037" (rs != "" ? 1 : 0); next }
        $1 == "check" || $1 == "debt" { for (i = 3; i <= NF; i++) if ($i != "") print "ENT\037" $i }
    ' "$f" >"$W/reg.parsed" 2>/dev/null || { cni "$rl" "registry-could-not-be-parsed"; printf '%s\n' "$s" >>"$W/subbad"; continue; }
    bl=$(grep -m1 '^BAD' "$W/reg.parsed")
    if [ -n "$bl" ]; then
        IFS=$'\037' read -r _ bn bw <<<"$bl"
        cni "$rl" "registry-malformed:line-$bn:$bw-so-no-exemption-of-$(enc "$s")-is-honoured"; printf '%s\n' "$s" >>"$W/subbad"; continue
    fi
    n=$((n + 1))
    awk -F'\037' -v s="$s" -v r="$r" '$1 == "EX" { print s "\037" r "\037" $2 "\037" $3 "\037" $4 }' "$W/reg.parsed" >>"$W/subex"
    awk -F'\037' -v s="$s" '$1 == "ENT" { print s "/" $2 }' "$W/reg.parsed" >>"$W/subent"
done <"$W/subregs"
while IFS=$'\037' read -r s r ln ep hr; do
    tgt="$s/$ep"; rl="subregistry:$(enc "$s/$r"):$ln"; rref="$(enc "$s/$r"):$ln"
    if [ "$hr" != 1 ]; then finding high governance-drift "$rl" "submodule registry exempt row for $(enc "$tgt") carries no reason, so it is not honoured" "$rref"; continue; fi
    if [ ! -e "$BASE/$tgt" ] && [ ! -L "$BASE/$tgt" ]; then finding high governance-drift "$rl" "submodule registry exempt row names $(enc "$tgt") which does not exist" "$rref"; continue; fi
    if [ -L "$BASE/$tgt" ] || [ ! -f "$BASE/$tgt" ]; then finding high governance-drift "$rl" "submodule registry exempt row names $(enc "$tgt") which is not a regular file: only one exact file can be exempted, never a directory or a link" "$rref"; continue; fi
    grep -qxF -- "$s" "$W/subbad" && continue
    printf '%s\037%s\037%s\n' "$tgt" "$rl" "$rref" >>"$W/subexok"
done <"$W/subex"

# sub_exempt <path>: 0 when an honoured submodule exemption covers exactly <path>. An exemption is REFUSED (with a
# finding at its row) when the file's name declares a verdict gate by its leading verb, or when any registry of the
# same submodule also names the file as a check/debt entry point: a gate cannot be exempted from having a proof.
sub_exempt() {
    local p=$1 row tgt rl rref
    row=$(awk -F'\037' -v t="$p" '$1 == t { print; exit }' "$W/subexok")
    [ -n "$row" ] || return 1
    IFS=$'\037' read -r tgt rl rref <<<"$row"
    if [[ $(basename -- "$p") =~ ^(verify|audit|check|guard|gate|lint|validate)[-_.] ]]; then
        finding high governance-drift "$rl" "submodule registry exempts $(enc "$p") whose name declares a verdict gate by its leading verb; the exemption is refused" "$rref"; return 1
    fi
    if grep -qxF -- "$p" "$W/subent"; then
        finding high governance-drift "$rl" "submodule registry exempts $(enc "$p") which a registry of the same submodule also names as a check or debt entry point; the exemption is refused" "$rref"; return 1
    fi
    return 0
}

# alias_target <rel link path>: prints the repository-relative path of the regular file the tracked symlink
# resolves to; rc 1 unless that file lies inside BASE, is a regular non-symlink file and (live mode) belongs to the
# SAME git repository as the link.
BASE_REAL=$(cd "$BASE" 2>/dev/null && pwd -P)
alias_target() {
    local real t1 t2
    real=$(readlink -f -- "$BASE/$1" 2>/dev/null) || return 1
    [ -f "$real" ] && [ ! -L "$real" ] || return 1
    case "$real" in "$BASE_REAL"/*) ;; *) return 1 ;; esac
    if [ -z "$CORPUS" ]; then
        t1=$(git -C "$(dirname -- "$BASE/$1")" rev-parse --show-toplevel 2>/dev/null) || return 1
        t2=$(git -C "$(dirname -- "$real")" rev-parse --show-toplevel 2>/dev/null) || return 1
        [ "$t1" = "$t2" ] || return 1
    fi
    printf '%s\n' "${real#"$BASE_REAL"/}"
}

# ---- uncovered scripts
while IFS= read -r p; do
    [ -n "$p" ] || continue
    tp=$(enc "$p")
    if [ -L "$BASE/$p" ]; then
        # VSC-372: a tracked symlink whose fully-resolved target is a regular file inside the SAME repository is
        # an alias. When the target is itself in the population it is reported there (the link is counted as
        # inspected, not a second report); otherwise the target is read in the link's place. Dangling,
        # out-of-tree and cross-repository links stay COULD-NOT-INSPECT.
        if tgt=$(alias_target "$p"); then
            if grep -qxF -- "$tgt" "$W/paths" || grep -qxF -- "$tgt" "$W/registered" || covered_by_r5 "$tgt"; then n=$((n + 1)); continue; fi
            p=$tgt; tp=$(enc "$p")
        fi
    fi
    if [ -L "$BASE/$p" ] || [ ! -f "$BASE/$p" ]; then cni "$tp" "tracked-script-absent-or-not-a-regular-file-not-read"; continue; fi
    n=$((n + 1))
    gate_like "$(basename -- "$p")" || continue
    has_proof_arm "$BASE/$p"; hp=$?
    if [ "$hp" -eq 2 ]; then finding high false-evidence "$tp" "gate-like script outside R5's one-level scan has a proof-mode arm that is a stub: $STUB_WHY" "$tp"; continue; fi
    [ "$hp" -eq 0 ] && continue
    d=$(dirname -- "$p"); st=$(basename -- "$p" .sh); sib=0
    for s in "$BASE/$d"/*mutation*.sh "$BASE/$d"/prove-*"$st"*.sh "$BASE/$d"/prove_*"$st"*.sh; do [ -f "$s" ] && sib=1; done
    [ "$sib" -eq 1 ] && continue
    sibling_proof "$d" "$(basename -- "$p")" && continue
    sub_exempt "$p" && continue
    finding medium test-coverage "$tp" "gate-like script outside R5's one-level scan has no proof-mode arm (flag, positional mutate, or a [[ \$1 == ... ]] test), no sibling proof naming it and no registry row; its name is the gate evidence" "$tp"
done <"$W/paths"

cat "$CNI"
echo "INSPECTED $n"
echo "POPULATION-SHA $(printf '%s\n' "$TOK" | sha256sum | cut -d' ' -f1)"
if [ "$FOUND" -gt 0 ]; then exit 1; fi
if [ -s "$CNI" ]; then exit 2; fi
exit 0
