#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# zero-gap-class-content-boundary-rows.sh — sweep class `content-boundary-rows`
# (feature 010, task T023; class contract: docs/zero-gap/README.md).
#
# WHAT IT DETECTS
#   Every row that scripts/verify-content-boundary.sh reports as SURVIVING —
#   text that co-occurs between a PRIVATE repository of this fleet and a PUBLIC
#   one after all of that gate's subtractions (already-public, path-reference,
#   declared pairs, direction). Those rows are the unjudged reading assignment
#   the operator owns. This class REGISTERS them, by COUNT and PATH CLASS:
#     one FINDING per (public path class, gate class), severity high, category
#     content-boundary, location `<public path class>:<gate class>`,
#     evidence_ref docs/content-boundary.md (in --corpus mode: the group's first
#     public corpus file, because the runner resolves it inside the corpus).
#   It NEVER allow-lists, judges, redacts or subtracts a row, and it NEVER
#   prints matched text: the description carries counts, a count band, the
#   number of public files and the PRIVATE REPOSITORY PATHS the rows came from
#   (paths only). The `name` and `fingerprint` classes are counted like the
#   others; their values are withheld by the gate itself and never reach here.
#
# POPULATION (docs/zero-gap/sweep-classes.tsv row `content-boundary-rows`)
#   "every surviving row emitted by scripts/verify-content-boundary.sh --json on
#   the swept tree, grouped by class and public path class". Implemented as the
#   sorted, percent-encoded set:
#     gate:scripts/verify-content-boundary.sh    the gate result itself (always
#                                                present, so a gate that reports
#                                                ZERO rows is an inspected, clean
#                                                result and not an empty population)
#     <public path class>                        one per path class with >= 1 row
#   PUBLIC PATH CLASS: the public repository's fleet path (as the gate's own
#   "fleet" names it; `.` is the umbrella and contributes no prefix) followed by
#   at most TWO leading directory segments of the file inside that repository.
#   A file at a repository's top level is its own path class. Examples:
#   specs/002-x/tasks.md -> specs/002-x ; scripts/a.sh -> scripts ;
#   CLAUDE.md -> CLAUDE.md ; submodules/RAG/pkg/grounding/g.go ->
#   submodules/RAG/pkg/grounding.
#   WHY: the gate's surviving rows ARE the population the operator must read
#   (FR-001); grouping by path class keeps the register finite and stable while
#   every row stays counted.
#
# HOW IT OBTAINS THE ROWS — a CACHE, chosen by measurement (2026-09-26)
#   The gate is too heavy to run inside the class budget (900 s for ALL runs of
#   a class, up to four runs per sweep): one real `--json` run on this tree, under
#   `nice -n 10`, did not finish within `timeout 600` (wall 600.41 s, peak RSS
#   768,652 kB, no JSON produced); a later full run took about 2170 s and 760 MB.
#   So the LIVE mode never runs the gate. It READS a cached machine result written
#   by the operator/controller command below. UNTIL THAT ONE-TIME REFRESH IS MADE
#   (task T036, on a frozen real copy) THIS CLASS REPORTS rc 2 (cache absent) IN
#   EVERY SWEEP. The checks below detect STALENESS AND ACCIDENT, NOT FORGERY: the
#   cache is a writable, git-ignored file, and a careful editor can make every
#   field agree (tamper evidence belongs to the §11.4.268 evidence chain once
#   T068 binds this cache to it). The cache is trusted ONLY when:
#     1. both files exist and the JSON has the gate's --json shape, including its
#        windows / direction / not_indexed / untracked fields, and carries NO
#        matched text (`.leaks[].match`; the documented refresh strips it);
#     2. it is internally consistent: counts.leaks == the number of rows; the
#        per-class counts (prose, short, name, fingerprint) sum to counts.leaks
#        AND each equals that class's rows; exit agrees with rows (1 iff rows,
#        2 iff no row and >= 1 undetermined, 0 iff neither);
#     3. the gate measured an UNMOVING tree (corpus.stable == true);
#     4. it is the DEFAULT measurement: windows long=10 short=5 short_line_max=9
#        names=1, direction enabled with status `ran` (or `idle` with 0 eligible
#        keys). A narrower run (--no-names, --no-short, --no-direction, another
#        window) reports fewer rows and is refused. NOT CHECKABLE: --allow and
#        --name-rank / --name-ppm / --name-floor are not recorded in the gate's
#        --json, so a cache made with another exemption file or name floor cannot
#        be told apart from a default one;
#     5. the JSON's root is --root, and its fleet was DERIVED from the provider
#        (a --fleet-spec result is accepted only when --root is NOT the
#        repository holding this script — the same fence the gate uses);
#     6. the cached fleet holds EVERY repository path this root declares:
#        `.gitmodules` paths, `helix-deps.yaml` deps (grouped -> submodules/<name>,
#        flat -> <name>) and, for a derived fleet, the umbrella `.` (any role;
#        roles themselves are provider answers and are NOT re-checked);
#     7. the corpus manifest is the one that JSON was computed over (line count
#        and the gate's own cksum digest agree);
#     8. the manifest RE-COMPUTED NOW, by the gate's own enumeration rule
#        (tracked files of every public and private fleet repository minus
#        lock/min/map files, `cksum` per file, plus untracked public files when
#        the cache was made with --include-untracked), equals the cached one.
#        Every listed entry is classified BEFORE anything is opened: a FIFO,
#        device or socket, or a symlink that dangles, names a directory or leaves
#        --root, is COULD-NOT-INSPECT naming it and is never read (no hang, no
#        content from outside the tree); a symlink to a regular file inside
#        --root is hashed through, as the gate's cksum does; a plain directory (a
#        nested gitlink) and a path absent from the working tree are skipped, as
#        the gate skips them; a tracked NAME carrying a newline is
#        COULD-NOT-INSPECT naming it (measured: the gate splits it, reads neither
#        half and counts it nowhere). Hashing is bounded by `timeout` per repo.
#   Any failure is COULD-NOT-INSPECT naming the exact command to refresh it.
#   Rows the gate enumerated but did NOT read are never a clean result: a
#   counts.not_indexed > 0 (size cap, machine-generated) or an
#   untracked.files_unscanned > 0 adds a COULD-NOT-INSPECT on the gate token.
#   The cache lives under .remember/logs/zero-gap/ (git-ignored); this class
#   only READS it and never writes anywhere but $TMPDIR. Refresh command, run
#   from the repository root on a QUIET tree (it strips every matched string
#   before storing):
#     mkdir -p .remember/logs/zero-gap && rm -f .remember/logs/zero-gap/content-boundary-rows.corpus .remember/logs/zero-gap/content-boundary-rows.json && nice -n 10 bash scripts/verify-content-boundary.sh --json --expect-corpus .remember/logs/zero-gap/content-boundary-rows.corpus | jq -c '.leaks |= map(del(.match))' >.remember/logs/zero-gap/content-boundary-rows.json.part && mv .remember/logs/zero-gap/content-boundary-rows.json.part .remember/logs/zero-gap/content-boundary-rows.json
#   On a FROZEN COPY instead (so the tree cannot move under the 36-minute run):
#   run the same gate command with `--root <copy> --expect-corpus <copy>/...`
#   inside a real copy (`cp -a`, not hardlinks, remotes and gitlinks intact),
#   then set `.root` to the live root (`jq --arg r <live root> '.root = $r'`)
#   and copy both files into the live .remember/logs/zero-gap/. Check 8 then
#   proves the live tree equals the copy byte-for-byte, file by file.
#
#   --corpus <dir> runs the REAL gate (the one at <root>/scripts/) on a tiny
#   SYNTHETIC fleet built in $TMPDIR from <dir>/fleet.tsv (<dir> <role> <date>;
#   each directory becomes a throwaway git repository committed once at that
#   date; the entry `.` is the umbrella: every other top-level corpus entry,
#   tracked at the fleet root itself) with --fleet-spec and an EMPTY exemption
#   file; the matched text is stripped from the gate's JSON at once; the gate's
#   fleet must equal fleet.tsv. Locations are relative to <dir>. About 1-2 s.
#
# USAGE
#   zero-gap-class-content-boundary-rows.sh --root <dir> [--corpus <dir>] [--emit-population]
#   zero-gap-class-content-boundary-rows.sh --prove-failure
#   zero-gap-class-content-boundary-rows.sh --help
#
# OUTPUT (stdout only; class contract): FINDING / COULD-NOT-INSPECT / INSPECTED <n> /
#   POPULATION-SHA <sha256>. Diagnostics go to stderr. Under --emit-population
#   stdout carries population tokens only (every refusal goes to stderr, rc 2).
#
# EXIT CODES (three-valued; a 2 is never a pass; a finding outranks an undetermined)
#   0  the cached gate result is fresh and reports no surviving row
#   1  at least one FINDING (surviving rows registered)
#   2  COULD NOT DETERMINE: cache absent, unparseable, inconsistent, non-default,
#      stale, from a moving tree, for another root or missing a declared fleet
#      repository; an unreadable fleet entry; the gate reported undetermined rows,
#      unindexed or unscanned files and no surviving row; a tool (git, jq, cksum,
#      timeout, ...) or the gate script is missing; an empty corpus population;
#      --root not a directory; an unknown argument or a flag without its value.
#   --prove-failure: 0 every case behaved, 1 a case failed, 2 fixtures could not be built.
#
# WHAT IT DOES NOT SEE (declared, not implied away)
#   * Everything the gate itself does not see (its header lists it: non-ASCII
#     text, paraphrase, private code, git history, untracked private files, ...).
#   * A FORGED cache whose every field was made to agree (see above): this class
#     guards against staleness and accident only.
#   * A provider-side visibility flip, or a role edited in the cache: roles are
#     the cached fleet's; checks 6 and 8 cover paths and content, not visibility.
#   * The exemption file and the name-floor options the cache was made with
#     (not recorded by the gate's --json).
#   * History-only changes (a new commit whose working tree is byte-identical)
#     that would move the gate's direction dating: the manifest is content-only.
#   * The gate's UNDETERMINED rows are not registered as findings; their count is
#     surfaced as one COULD-NOT-INSPECT on gate:scripts/verify-content-boundary.sh.
#   * A public path carrying a backslash or a control character, or a row with an
#     empty field: the gate's hand-written JSON cannot carry it faithfully, so such
#     a row is COULD-NOT-INSPECT instead of a finding at a wrong location.
#   * Whether any row is a disclosure. Registering is not judging.
# ------------------------------------------------------------------------------
set -uo pipefail
export LC_ALL=C LANG=C PYTHONDONTWRITEBYTECODE=1

CLASS_ID=content-boundary-rows
GATE_REL=scripts/verify-content-boundary.sh
CACHE_DIR_REL=.remember/logs/zero-gap
CACHE_JSON_REL=$CACHE_DIR_REL/content-boundary-rows.json
CACHE_CORPUS_REL=$CACHE_DIR_REL/content-boundary-rows.corpus
EVIDENCE_REF=docs/content-boundary.md
SENTINEL="gate:$GATE_REL"
SELF_PATH="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/$(basename -- "${BASH_SOURCE[0]}")"
SELF_REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
HASH_TIMEOUT=300   # seconds per fleet repository for the manifest's cksum pass (never a hang)
REFRESH_CMD="mkdir -p $CACHE_DIR_REL && rm -f $CACHE_CORPUS_REL $CACHE_JSON_REL && nice -n 10 bash $GATE_REL --json --expect-corpus $CACHE_CORPUS_REL | jq -c '.leaks |= map(del(.match))' >$CACHE_JSON_REL.part && mv $CACHE_JSON_REL.part $CACHE_JSON_REL"

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

usage() { awk 'NR == 1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "$SELF_PATH"; }

# ══════════════════════════════════════════════════════════════════════════════
# PAIRED PROOF — throwaway copies only; the live tree is read, never written.
# ══════════════════════════════════════════════════════════════════════════════
prove_failure() {
    local T P_PASS=0 P_FAIL=0 out rc exp got o2 before after corpus
    T=$(mktemp -d "${TMPDIR:-/tmp}/zg-cbr-proof.XXXXXX") || { echo "PROOF: mktemp failed" >&2; return 2; }
    # shellcheck disable=SC2064
    trap "rm -rf '$T'" EXIT
    corpus="$SELF_REPO/_tests/fixtures/zero-gap/$CLASS_ID"
    for f in "$corpus/planted/fleet.tsv" "$corpus/clean/fleet.tsv" "$corpus/expect.tsv" "$SELF_REPO/$GATE_REL" "$SELF_REPO/scripts/zero-gap-lib.sh"; do
        [ -f "$f" ] || { echo "PROOF: fixture input absent: ${f#"$SELF_REPO"/}" >&2; return 2; }
    done
    for b in git jq cksum sha256sum awk; do command -v "$b" >/dev/null 2>&1 || { echo "PROOF: $b absent" >&2; return 2; }; done
    ok() { P_PASS=$((P_PASS + 1)); printf 'PASS  %s\n' "$1"; }
    bad() { P_FAIL=$((P_FAIL + 1)); printf 'FAIL  %s\n' "$1"; [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/      /' | head -20; return 0; }
    runc() { # <outfile> <args...> -> rc ; run THIS script under the runner's environment shape
        local o=$1; shift
        env -i PATH="$PATH" HOME="${HOME:-/nonexistent}" TMPDIR="$T/tmp" LC_ALL=C LANG=C bash "$SELF_PATH" "$@" >"$o" 2>"$o.err" </dev/null
    }
    mkdir -p "$T/tmp"
    # the live tree must stay byte-identical: fingerprint what this proof could touch
    # shellcheck disable=SC1091
    . "$SELF_REPO/scripts/zero-gap-lib.sh" || { echo "PROOF: cannot source zero-gap-lib.sh" >&2; return 2; }
    livefp() {
        zg_fingerprint "$SELF_REPO" "_tests/fixtures/zero-gap/$CLASS_ID" "scripts/zero-gap-class-$CLASS_ID.sh" "$GATE_REL" 2>/dev/null | cut -d' ' -f1
        ls -la --time-style=+%s.%N "$SELF_REPO/$CACHE_DIR_REL" 2>/dev/null | sha256sum | cut -d' ' -f1
    }
    before=$(livefp)
    cp -R "$corpus" "$T/corpus"
    exp=$(awk -F'\t' '!/^#/ && NF { print $1 }' "$T/corpus/expect.tsv" | LC_ALL=C sort -u)
    findings() { awk '$1 == "FINDING" { print $5 }' "$1" | LC_ALL=C sort -u; }
    # words of the corpus's synthetic private text: none of them may ever reach the output
    MT_RE='harbour|lantern|bakers|flour|wheels|quorvel|tansiby|ropewalk|ferry|timetable|0b1e5c7a|withheld #'

    echo "paired proof for $(basename "$SELF_PATH") (throwaway root: \$TMPDIR)"

    # C0 control: the clean corpus (public-first text, subtracted by the gate) -> 0, no finding
    runc "$T/c0" --root "$SELF_REPO" --corpus "$T/corpus/clean"; rc=$?
    if [ "$rc" -eq 0 ] && ! grep -q '^FINDING' "$T/c0" && grep -qx 'INSPECTED 1' "$T/c0"; then ok "C0 clean corpus => rc 0, no finding, INSPECTED 1 (the gate result)"
    else bad "C0 clean corpus rc=$rc" "$(cat "$T/c0" "$T/c0.err")"; fi

    # M1 planted corpus -> 1, exactly the expect.tsv locations
    runc "$T/m1" --root "$SELF_REPO" --corpus "$T/corpus/planted"; rc=$?
    got=$(findings "$T/m1")
    if [ "$rc" -eq 1 ] && [ "$got" = "$exp" ]; then ok "M1 planted corpus => rc 1, exactly the $(printf '%s\n' "$exp" | wc -l) planted locations"
    else bad "M1 planted corpus rc=$rc" "expected: $exp"$'\n'"got: $got"$'\n'"$(cat "$T/m1.err")"; fi

    # M1b one group fed by TWO private repositories names both, by path, with a count each
    if grep -Eq '^FINDING [^ ]+ high content-boundary pub/docs/guide:prose .*private source repositories by path: priv [0-9]+, priv2 [0-9]+;' "$T/m1"; then ok "M1b a multi-source group names every private source repository by path with its count"
    else bad "M1b multi-source description" "$(grep 'pub/docs/guide:prose' "$T/m1")"; fi

    # M2 no matched text and no withheld value ever reaches the output
    if [ -s "$T/m1" ] && ! grep -Eiq "$MT_RE" "$T/m1"; then ok "M2 output carries counts and paths only (no matched text, no name, no digest)"
    else bad "M2 output empty, or matched text reached it" "$(grep -Ei "$MT_RE" "$T/m1" | head -3)"; fi

    # M3 determinism: the same corpus twice -> byte-identical output
    runc "$T/m3" --root "$SELF_REPO" --corpus "$T/corpus/planted"
    if [ -s "$T/m1" ] && cmp -s "$T/m1" "$T/m3"; then ok "M3 same corpus twice => byte-identical output"; else bad "M3 output differs between two runs"; fi

    # ---- live mode on a SYNTHETIC root with a cache written by the real gate ----
    gcommit() { # <repo dir> <date> [paths...]: commit (all, or the named paths) at a fixed date
        local g=$1 dt=$2; shift 2
        ( cd "$g" && export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 \
          && { [ -d .git ] || git init -q; } && if [ $# -gt 0 ]; then git add -- "$@"; else git add -A; fi \
          && GIT_AUTHOR_DATE=$dt GIT_COMMITTER_DATE=$dt \
             git -c user.name=zg -c user.email=zg@example.invalid -c commit.gpgsign=false commit -qm seed ) >/dev/null 2>&1
    }
    regate() { # <root> [extra gate args...]: run the REAL gate on <root>'s .spec and write a fresh cache
        local d=$1; shift
        rm -f "$d/$CACHE_CORPUS_REL" "$d/$CACHE_JSON_REL"
        ( set +o pipefail; cd "$d" && env -i PATH="$PATH" HOME="${HOME:-/nonexistent}" TMPDIR="$T/tmp" LC_ALL=C bash "$SELF_REPO/$GATE_REL" \
            --root "$d" --fleet-spec "$d/.spec" --allow "$d/.allow" --json --expect-corpus "$CACHE_CORPUS_REL" "$@" 2>/dev/null \
            | jq -c '.leaks |= map(del(.match))' >"$CACHE_JSON_REL" ) || return 2
        [ -s "$d/$CACHE_JSON_REL" ] && [ -s "$d/$CACHE_CORPUS_REL" ]
    }
    mkroot() { # <dir> <corpus part> [extra gate args...]: fleet repos + a copy of the gate + a fresh cache
        local d=$1 part=$2 r role date dotrole="" dotdate="" e; shift 2
        local gargs=("$@")
        mkdir -p "$d/scripts" "$d/$CACHE_DIR_REL" || return 2
        : >"$d/.spec"; : >"$d/.allow"
        cp "$SELF_REPO/$GATE_REL" "$d/$GATE_REL" || return 2
        while IFS=$'\t' read -r r role date _; do
            case "$r" in ''|'#'*) continue ;; .) dotrole=$role; dotdate=$date; continue ;; esac
            cp -R "$T/corpus/$part/$r" "$d/$r" || return 2
            gcommit "$d/$r" "$date" || return 2
            printf '%s\t%s\n' "$r" "$role" >>"$d/.spec"
        done <"$T/corpus/$part/fleet.tsv"
        if [ -n "$dotrole" ]; then # the umbrella `.`: every other top-level corpus entry, tracked at the root itself
            set --
            for e in "$T/corpus/$part"/*; do
                e=${e##*/}; [ "$e" = fleet.tsv ] && continue
                awk -F'\t' -v x="$e" '$1 == x { f = 1 } END { exit !f }' "$T/corpus/$part/fleet.tsv" && continue
                cp -R "$T/corpus/$part/$e" "$d/$e" || return 2; set -- "$@" "$e"
            done
            gcommit "$d" "$dotdate" "$@" || return 2
            # only the umbrella's own entries are its content: nothing else at the root is untracked noise
            { echo '/*'; for e in "$@"; do printf '!/%s\n' "$e"; done; } >"$d/.git/info/exclude"
            printf '.\t%s\n' "$dotrole" >>"$d/.spec"
        fi
        regate "$d" ${gargs[@]+"${gargs[@]}"}
    }
    clone() { # <src root> <dst root>: a copy whose cached .root names the copy, so only the planted change differs
        cp -R "$1" "$2" && jq -c --arg r "$2" '.root = $r' "$1/$CACHE_JSON_REL" >"$2/$CACHE_JSON_REL"
    }
    cni_has() { grep -q "^COULD-NOT-INSPECT .*$2" "$1"; }
    mkroot "$T/L" planted || { echo "PROOF: synthetic live root could not be built" >&2; return 2; }
    mkroot "$T/LC" clean || { echo "PROOF: synthetic clean live root could not be built" >&2; return 2; }

    # M4 fresh cache -> rc 1, the same findings as the corpus run, POPULATION-SHA == --emit-population
    o2=$(zg_fingerprint "$T/L/pub" 2>/dev/null | cut -d' ' -f1)$(ls -la --time-style=+%s.%N "$T/L/$CACHE_DIR_REL" | sha256sum)
    runc "$T/m4p" --root "$T/L" --emit-population; rc=$?
    runc "$T/m4" --root "$T/L"; local rc4=$?
    got=$(findings "$T/m4")
    if [ "$rc" -eq 0 ] && [ "$rc4" -eq 1 ] && [ "$got" = "$exp" ] \
       && [ "$(awk '$1 == "POPULATION-SHA" { print $2 }' "$T/m4")" = "$(sha256sum <"$T/m4p" | cut -d' ' -f1)" ] \
       && grep -qx "INSPECTED $(wc -l <"$T/m4p")" "$T/m4"; then ok "M4 fresh cache on a synthetic root => rc 1, planted locations, POPULATION-SHA matches --emit-population"
    else bad "M4 fresh cache emit-rc=$rc live-rc=$rc4" "$(cat "$T/m4" "$T/m4.err" "$T/m4p")"; fi
    if [ "$o2" = "$(zg_fingerprint "$T/L/pub" 2>/dev/null | cut -d' ' -f1)$(ls -la --time-style=+%s.%N "$T/L/$CACHE_DIR_REL" | sha256sum)" ]; then ok "M4b --emit-population and the live run wrote nothing into the root or the cache"
    else bad "M4b the class wrote into the swept root"; fi
    if ! grep -Eiq "$MT_RE" "$T/m4"; then ok "M4c live output carries no matched text"; else bad "M4c matched text in live output"; fi

    # M5 a gate result with no surviving row -> rc 0, INSPECTED 1
    runc "$T/m5" --root "$T/LC"; rc=$?
    if [ "$rc" -eq 0 ] && ! grep -q '^FINDING' "$T/m5" && grep -qx 'INSPECTED 1' "$T/m5"; then ok "M5 fresh cache with zero surviving rows => rc 0 (the gate result is the inspected item)"
    else bad "M5 clean cache rc=$rc" "$(cat "$T/m5" "$T/m5.err")"; fi

    # M6 absent cache -> rc 2 naming the refresh command; --emit-population rc 2
    clone "$T/L" "$T/L6"; rm -f "$T/L6/$CACHE_JSON_REL"
    runc "$T/m6" --root "$T/L6"; rc=$?
    runc "$T/m6p" --root "$T/L6" --emit-population; local rc6p=$?
    if [ "$rc" -eq 2 ] && grep -q '^COULD-NOT-INSPECT' "$T/m6" && grep -qF -- "--expect-corpus $CACHE_CORPUS_REL" "$T/m6" && [ "$rc6p" -eq 2 ] && ! grep -q '^FINDING' "$T/m6"; then ok "M6 absent cache => rc 2 with the refresh command; --emit-population rc 2"
    else bad "M6 absent cache rc=$rc emit=$rc6p" "$(cat "$T/m6")"; fi

    # M7 stale cache: a public file changes after the gate ran -> rc 2, never the old findings
    clone "$T/L" "$T/L7"; printf 'one more line written after the gate ran\n' >>"$T/L7/pub/docs/plan.md"
    runc "$T/m7" --root "$T/L7"; rc=$?
    if [ "$rc" -eq 2 ] && cni_has "$T/m7" "cache stale" && ! grep -q '^FINDING' "$T/m7"; then ok "M7 stale cache (tree changed after the gate) => rc 2, no stale findings"
    else bad "M7 stale cache rc=$rc" "$(cat "$T/m7")"; fi

    # M7b stale cache: a PRIVATE file changes -> rc 2 as well (both sides are in the manifest)
    clone "$T/L" "$T/L7b"; printf 'private edit\n' >>"$T/L7b/priv/chapters/notes.md"
    runc "$T/m7b" --root "$T/L7b"; rc=$?
    if [ "$rc" -eq 2 ] && cni_has "$T/m7b" "cache stale" && ! grep -q '^FINDING' "$T/m7b"; then ok "M7b private-side change after the gate => rc 2"; else bad "M7b rc=$rc" "$(cat "$T/m7b")"; fi

    # M8 the gate measured a MOVING tree -> rc 2
    clone "$T/L" "$T/L8"; jq -c '.corpus.stable = false' "$T/L8/$CACHE_JSON_REL" >"$T/j" && mv "$T/j" "$T/L8/$CACHE_JSON_REL"
    runc "$T/m8" --root "$T/L8"; rc=$?
    if [ "$rc" -eq 2 ] && cni_has "$T/m8" "MOVING tree" && ! grep -q '^FINDING' "$T/m8"; then ok "M8 cache from a moving tree (corpus.stable=false) => rc 2"; else bad "M8 rc=$rc" "$(cat "$T/m8")"; fi

    # M9 truncated cache: one leak row missing -> rc 2
    clone "$T/L" "$T/L9"; jq -c '.leaks |= .[1:]' "$T/L9/$CACHE_JSON_REL" >"$T/j" && mv "$T/j" "$T/L9/$CACHE_JSON_REL"
    runc "$T/m9" --root "$T/L9"; rc=$?
    if [ "$rc" -eq 2 ] && cni_has "$T/m9" "truncated" && ! grep -q '^FINDING' "$T/m9"; then ok "M9 truncated cache (counts.leaks != rows) => rc 2"; else bad "M9 rc=$rc" "$(cat "$T/m9")"; fi

    # M10 unparseable cache -> rc 2
    clone "$T/L" "$T/L10"; head -c 40 "$T/L/$CACHE_JSON_REL" >"$T/L10/$CACHE_JSON_REL"
    runc "$T/m10" --root "$T/L10"; rc=$?
    if [ "$rc" -eq 2 ] && cni_has "$T/m10" "not the gate.s --json shape"; then ok "M10 unparseable cache => rc 2"; else bad "M10 rc=$rc" "$(cat "$T/m10")"; fi

    # M11 a manifest that belongs to a different JSON (digest mismatch) -> rc 2
    clone "$T/L" "$T/L11"; cp "$T/LC/$CACHE_CORPUS_REL" "$T/L11/$CACHE_CORPUS_REL"
    runc "$T/m11" --root "$T/L11"; rc=$?
    if [ "$rc" -eq 2 ] && cni_has "$T/m11" "not the one the cached JSON" && ! grep -q '^FINDING' "$T/m11"; then ok "M11 manifest/JSON pair mismatch => rc 2"; else bad "M11 rc=$rc" "$(cat "$T/m11")"; fi

    # M12 undetermined rows next to leaks -> rc 1 AND a COULD-NOT-INSPECT (a finding outranks)
    clone "$T/L" "$T/L12"; jq -c '.undetermined += ["a synthetic undetermined row"] | .counts.undetermined += 1' "$T/L12/$CACHE_JSON_REL" >"$T/j" && mv "$T/j" "$T/L12/$CACHE_JSON_REL"
    runc "$T/m12" --root "$T/L12"; rc=$?
    if [ "$rc" -eq 1 ] && grep -q "^COULD-NOT-INSPECT $SENTINEL " "$T/m12" && [ "$(findings "$T/m12")" = "$exp" ]; then ok "M12 undetermined rows => surfaced as COULD-NOT-INSPECT; findings still rc 1"
    else bad "M12 rc=$rc" "$(cat "$T/m12")"; fi
    # M12b undetermined rows and no leak -> rc 2, never clean
    clone "$T/LC" "$T/L12b"; jq -c '.undetermined += ["a synthetic undetermined row"] | .counts.undetermined += 1 | .exit = 2' "$T/L12b/$CACHE_JSON_REL" >"$T/j" && mv "$T/j" "$T/L12b/$CACHE_JSON_REL"
    runc "$T/m12b" --root "$T/L12b"; rc=$?
    if [ "$rc" -eq 2 ] && cni_has "$T/m12b" "undetermined row" && ! grep -q '^FINDING' "$T/m12b"; then ok "M12b undetermined rows and zero surviving rows => rc 2, never clean"; else bad "M12b rc=$rc" "$(cat "$T/m12b")"; fi

    # M13 a --fleet-spec (synthetic) cache is refused when --root is the repository holding the class
    clone "$T/L" "$T/L13"; cp "$SELF_PATH" "$T/L13/scripts/zero-gap-class-$CLASS_ID.sh"
    env -i PATH="$PATH" HOME="${HOME:-/nonexistent}" TMPDIR="$T/tmp" LC_ALL=C bash "$T/L13/scripts/zero-gap-class-$CLASS_ID.sh" --root "$T/L13" >"$T/m13" 2>&1 </dev/null; rc=$?
    if [ "$rc" -eq 2 ] && cni_has "$T/m13" "SYNTHETIC --fleet-spec" && ! grep -q '^FINDING' "$T/m13"; then ok "M13 synthetic-fleet cache on the class's own repository => rc 2 (not evidence about it)"; else bad "M13 rc=$rc" "$(cat "$T/m13")"; fi

    # M14 a cache written for ANOTHER root -> rc 2
    clone "$T/L" "$T/L14"; jq -c '.root = "/elsewhere"' "$T/L14/$CACHE_JSON_REL" >"$T/j" && mv "$T/j" "$T/L14/$CACHE_JSON_REL"
    runc "$T/m14" --root "$T/L14"; rc=$?
    if [ "$rc" -eq 2 ] && cni_has "$T/m14" "another root"; then ok "M14 cache for another root => rc 2"; else bad "M14 rc=$rc" "$(cat "$T/m14")"; fi

    # M15 --root /nonexistent -> rc 2
    runc "$T/m15" --root /nonexistent; rc=$?
    if [ "$rc" -eq 2 ]; then ok "M15 --root /nonexistent => rc 2"; else bad "M15 rc=$rc"; fi

    # M16 a broken tool (jq fails) -> rc 2
    mkdir -p "$T/badbin"; printf '#!/bin/sh\nexit 127\n' >"$T/badbin/jq"; chmod +x "$T/badbin/jq"
    env -i PATH="$T/badbin:$PATH" HOME="${HOME:-/nonexistent}" TMPDIR="$T/tmp" LC_ALL=C bash "$SELF_PATH" --root "$T/L" >"$T/m16" 2>&1 </dev/null; rc=$?
    if [ "$rc" -eq 2 ] && ! grep -q '^FINDING' "$T/m16"; then ok "M16 broken jq => rc 2"; else bad "M16 rc=$rc" "$(cat "$T/m16")"; fi

    # M17 the gate script is absent from --root -> rc 2 (corpus mode and live mode)
    mkdir -p "$T/nogate"
    runc "$T/m17" --root "$T/nogate" --corpus "$T/corpus/planted"; rc=$?
    clone "$T/L" "$T/L17"; rm -f "$T/L17/$GATE_REL"
    runc "$T/m17b" --root "$T/L17"; local rc17b=$?
    if [ "$rc" -eq 2 ] && [ "$rc17b" -eq 2 ]; then ok "M17 gate script absent => rc 2 (corpus and live)"; else bad "M17 rc=$rc/$rc17b" "$(cat "$T/m17" "$T/m17b")"; fi

    # M18 empty corpus population -> rc 2, never clean
    mkdir -p "$T/empty"
    runc "$T/m18" --root "$SELF_REPO" --corpus "$T/empty"; rc=$?
    mkdir -p "$T/pubonly/pub"; cp "$T/corpus/planted/pub/docs/plan.md" "$T/pubonly/pub/plan.md"; printf 'pub\tpublic\t2021-01-01T00:00:00Z\n' >"$T/pubonly/fleet.tsv"
    runc "$T/m18b" --root "$SELF_REPO" --corpus "$T/pubonly"; local rc18b=$?
    if [ "$rc" -eq 2 ] && [ "$rc18b" -eq 2 ]; then ok "M18 empty corpus / a fleet with no private side => rc 2"; else bad "M18 rc=$rc/$rc18b" "$(cat "$T/m18" "$T/m18b")"; fi

    # ---- review round rev-cbrows: forged, non-default and unreadable caches ----
    forge() { # <root> <jq filter>: rewrite the cached JSON in place (a throwaway root only)
        jq -c "$2" "$1/$CACHE_JSON_REL" >"$T/j" && mv "$T/j" "$1/$CACHE_JSON_REL"
    }
    recount() { # <root>: make the cached JSON's counts and exit agree with its rows again (what a careful forger does)
        forge "$1" '.counts.leaks = (.leaks | length)
            | .counts.prose = ([.leaks[] | select(.class == "prose")] | length)
            | .counts.short = ([.leaks[] | select(.class == "short")] | length)
            | .counts.name = ([.leaks[] | select(.class == "name")] | length)
            | .counts.fingerprint = ([.leaks[] | select(.class == "fingerprint")] | length)
            | .counts.undetermined = (.undetermined | length)
            | .exit = (if (.leaks | length) > 0 then 1 elif (.undetermined | length) > 0 then 2 else 0 end)'
    }
    remanifest() { # <root>: make .corpus.files/.corpus.digest name the (edited) cached manifest again
        local f dg
        f=$(wc -l <"$1/$CACHE_CORPUS_REL" | tr -d ' '); dg=$(printf '%08x' "$(cksum <"$1/$CACHE_CORPUS_REL" | awk '{ print $1 }')")
        forge "$1" ".corpus.files = $f | .corpus.digest = \"$dg\""
    }
    no_finding() { ! grep -q '^FINDING' "$1"; }

    # M20 a GENUINE cache from a NON-DEFAULT gate run (fewer passes, wider window) -> rc 2, never a clean or a finding
    mkroot "$T/L20" planted --no-names --no-short --window 30 || { echo "PROOF: non-default root could not be built" >&2; return 2; }
    runc "$T/m20" --root "$T/L20"; rc=$?
    if [ "$rc" -eq 2 ] && cni_has "$T/m20" "non-default" && no_finding "$T/m20"; then ok "M20 genuine cache from --no-names --no-short --window 30 => rc 2 (a narrower gate run is not the default measurement)"
    else bad "M20 non-default gate run rc=$rc" "$(cat "$T/m20")"; fi
    # M20b every recorded parameter is checked on its own (one forged field at a time)
    local fx i=0 m20b=0
    for fx in '.windows.long = 30' '.windows.short = 0' '.windows.short_line_max = 12' '.windows.names = 0' \
              '.direction.enabled = false' '.direction.status = "off"' '.direction.status = "unavailable"' \
              '.direction.status = "error"' '.direction.status = "idle"'; do
        i=$((i + 1)); clone "$T/L" "$T/L20b$i"; forge "$T/L20b$i" "$fx"
        runc "$T/m20b$i" --root "$T/L20b$i"; rc=$?
        if [ "$rc" -eq 2 ] && cni_has "$T/m20b$i" "non-default" && no_finding "$T/m20b$i"; then :; else m20b=1; bad "M20b forged parameter [$fx] rc=$rc" "$(cat "$T/m20b$i")"; fi
    done
    [ "$m20b" -eq 0 ] && ok "M20b each of the 9 recorded parameters (windows, names, direction) is checked on its own => rc 2"
    # M20c direction "idle" is the default run on a tree with nothing to date (eligible 0) -> accepted
    clone "$T/LC" "$T/L20c"; forge "$T/L20c" '.direction.status = "idle" | .direction.eligible = 0'
    runc "$T/m20c" --root "$T/L20c"; rc=$?
    if [ "$rc" -eq 0 ]; then ok "M20c direction idle with 0 eligible keys (a default run with nothing to date) => accepted, rc 0"; else bad "M20c rc=$rc" "$(cat "$T/m20c")"; fi

    # M21 rows the gate did NOT read (a newline-named public file -> counts.not_indexed) are never a clean result
    clone "$T/LC" "$T/L21"; printf 'a public file whose name carries a newline\n' >"$T/L21/pub/docs/two"$'\n'"lines.md"
    gcommit "$T/L21/pub" 2019-06-01T00:00:00Z && regate "$T/L21" || { echo "PROOF: newline-named root could not be built" >&2; return 2; }
    runc "$T/m21" --root "$T/L21"; rc=$?
    # measured: the gate splits that name at the newline, reads neither half and counts it nowhere (not_indexed stays 0)
    if [ "$rc" -eq 2 ] && grep -q '^COULD-NOT-INSPECT pub/docs/two%0Alines\.md .*newline' "$T/m21" && no_finding "$T/m21"; then ok "M21 genuine gate result over a newline-named public file (read and counted nowhere by the gate) => rc 2 naming it"
    else bad "M21 newline-named file (not_indexed=$(jq '.counts.not_indexed' "$T/L21/$CACHE_JSON_REL")) rc=$rc" "$(cat "$T/m21")"; fi
    # M21a files the gate reports as not indexed (size cap, machine-generated) -> rc 2, never clean
    clone "$T/LC" "$T/L21a"; forge "$T/L21a" '.counts.not_indexed = 1'
    runc "$T/m21a" --root "$T/L21a"; rc=$?
    if [ "$rc" -eq 2 ] && grep -q "^COULD-NOT-INSPECT $SENTINEL .*not indexed" "$T/m21a" && no_finding "$T/m21a"; then ok "M21a counts.not_indexed > 0 => rc 2 (those files were never read)"
    else bad "M21a rc=$rc" "$(cat "$T/m21a")"; fi
    # M21b untracked public files the gate did not scan -> rc 2 even with no undetermined row
    clone "$T/LC" "$T/L21b"; forge "$T/L21b" '.untracked.files_unscanned = 2'
    runc "$T/m21b" --root "$T/L21b"; rc=$?
    if [ "$rc" -eq 2 ] && grep -q "^COULD-NOT-INSPECT $SENTINEL .*untracked" "$T/m21b"; then ok "M21b untracked.files_unscanned > 0 => rc 2"; else bad "M21b rc=$rc" "$(cat "$T/m21b")"; fi
    # M21c not-indexed files next to surviving rows -> rc 1 AND the COULD-NOT-INSPECT (a finding outranks)
    clone "$T/L" "$T/L21c"; forge "$T/L21c" '.counts.not_indexed = 3'
    runc "$T/m21c" --root "$T/L21c"; rc=$?
    if [ "$rc" -eq 1 ] && grep -q "^COULD-NOT-INSPECT $SENTINEL .*3 .*not indexed" "$T/m21c" && [ "$(findings "$T/m21c")" = "$exp" ]; then ok "M21c not-indexed files next to surviving rows => rc 1 plus COULD-NOT-INSPECT"
    else bad "M21c rc=$rc" "$(cat "$T/m21c")"; fi

    # M22 emptied leak rows with counts.leaks and exit adjusted (per-class counts left) -> rc 2
    clone "$T/L" "$T/L22"; forge "$T/L22" '.leaks = [] | .counts.leaks = 0 | .exit = 0'
    runc "$T/m22" --root "$T/L22"; rc=$?
    if [ "$rc" -eq 2 ] && cni_has "$T/m22" "per-class" && no_finding "$T/m22"; then ok "M22 emptied rows with counts.leaks/exit adjusted => rc 2 (per-class counts disagree)"; else bad "M22 rc=$rc" "$(cat "$T/m22")"; fi
    # M22b a row relabelled to another class (every count untouched) -> rc 2
    clone "$T/L" "$T/L22b"; forge "$T/L22b" '.leaks[0].class = (if .leaks[0].class == "prose" then "short" else "prose" end)'
    runc "$T/m22b" --root "$T/L22b"; rc=$?
    if [ "$rc" -eq 2 ] && cni_has "$T/m22b" "per-class" && no_finding "$T/m22b"; then ok "M22b a row relabelled to another class => rc 2"; else bad "M22b rc=$rc" "$(cat "$T/m22b")"; fi
    # M22c per-class counts that sum to counts.leaks but disagree with the rows -> rc 2
    clone "$T/L" "$T/L22c"; forge "$T/L22c" '.counts.prose += 1 | .counts.short -= 1'
    runc "$T/m22c" --root "$T/L22c"; rc=$?
    if [ "$rc" -eq 2 ] && cni_has "$T/m22c" "per-class" && no_finding "$T/m22c"; then ok "M22c per-class counts that disagree with the rows => rc 2"; else bad "M22c rc=$rc" "$(cat "$T/m22c")"; fi

    # M23 a derived-fleet cache is checked against the fleet the root DECLARES (.gitmodules + helix-deps.yaml + `.`)
    mkderived() { # <dst>: a copy of L whose cache claims a provider-derived fleet, declared by the root itself
        clone "$T/L" "$1" || return 2
        printf '[submodule "pub"]\n\tpath = pub\n\turl = git@example.invalid:zg/pub.git\n[submodule "priv"]\n\tpath = priv\n\turl = git@example.invalid:zg/priv.git\n' >"$1/.gitmodules"
        printf 'schema_version: 1\n\ndeps:\n  - name: priv2\n    ssh_url: git@example.invalid:zg/priv2.git\n    layout: flat\n\ntransitive_handling:\n  recursive: false\n' >"$1/helix-deps.yaml"
        forge "$1" '.fleet_source = "derived"'
    }
    mkderived "$T/L23" || { echo "PROOF: derived root could not be built" >&2; return 2; }
    runc "$T/m23" --root "$T/L23"; rc=$?
    if [ "$rc" -eq 1 ] && [ "$(findings "$T/m23")" = "$exp" ] && ! grep -q '^COULD-NOT-INSPECT' "$T/m23"; then ok "M23 control: derived cache whose fleet holds every declared path => rc 1, planted locations"
    else bad "M23 control rc=$rc" "$(cat "$T/m23" "$T/m23.err")"; fi
    # M23b-d cut ONE declared repository out of the fleet, with its rows, counts and manifest recomputed -> rc 2
    local cut m23x=0
    for cut in priv priv2 .; do
        mkderived "$T/L23x" || return 2
        if [ "$cut" = . ]; then
            forge "$T/L23x" '.fleet |= map(select(.path != ".")) | .leaks |= map(select(.public | test("^(pub|priv|priv2)/")))'
            awk -F'\t' '$1 ~ /^(pub|priv|priv2)\//' "$T/L23x/$CACHE_CORPUS_REL" >"$T/cc"
        else
            forge "$T/L23x" ".fleet |= map(select(.path != \"$cut\")) | .leaks |= map(select(.private | startswith(\"$cut/\") | not))"
            awk -F'\t' -v P="$cut/" 'index($1, P) != 1' "$T/L23x/$CACHE_CORPUS_REL" >"$T/cc"
        fi
        mv "$T/cc" "$T/L23x/$CACHE_CORPUS_REL"; recount "$T/L23x"; remanifest "$T/L23x"
        runc "$T/m23x" --root "$T/L23x"; rc=$?
        if [ "$rc" -eq 2 ] && cni_has "$T/m23x" "absent from the cached fleet" && no_finding "$T/m23x"; then :
        else m23x=1; bad "M23 fleet cut [$cut] rc=$rc" "$(cat "$T/m23x")"; fi
        rm -rf "$T/L23x"
    done
    [ "$m23x" -eq 0 ] && ok "M23b-d a declared repository cut out of the fleet (via .gitmodules, via helix-deps.yaml, the umbrella .) => rc 2, even with rows, counts and manifest recomputed"

    # M24 a tracked entry that is not a regular file never hangs the hashing and is named (never read)
    clone "$T/L" "$T/L24"; rm -f "$T/L24/pub/docs/plan.md"; mkfifo "$T/L24/pub/docs/plan.md"
    timeout 120 env -i PATH="$PATH" HOME="${HOME:-/nonexistent}" TMPDIR="$T/tmp" LC_ALL=C LANG=C bash "$SELF_PATH" --root "$T/L24" >"$T/m24" 2>&1 </dev/null; rc=$?
    if [ "$rc" -eq 2 ] && grep -q '^COULD-NOT-INSPECT .*pub/docs/plan\.md.*not a regular file' "$T/m24" && no_finding "$T/m24"; then ok "M24 a FIFO in place of a tracked file => rc 2 naming it, no hang"
    else bad "M24 FIFO rc=$rc (124 = hung)" "$(cat "$T/m24")"; fi
    clone "$T/L" "$T/L24b"; rm -f "$T/L24b/pub/docs/plan.md"; ln -s /dev/zero "$T/L24b/pub/docs/plan.md"
    timeout 120 env -i PATH="$PATH" HOME="${HOME:-/nonexistent}" TMPDIR="$T/tmp" LC_ALL=C LANG=C bash "$SELF_PATH" --root "$T/L24b" >"$T/m24b" 2>&1 </dev/null; rc=$?
    if [ "$rc" -eq 2 ] && grep -q '^COULD-NOT-INSPECT .*pub/docs/plan\.md.*not a regular file' "$T/m24b" && no_finding "$T/m24b"; then ok "M24b a symlink to /dev/zero => rc 2 naming it, no hang"
    else bad "M24b /dev/zero rc=$rc (124 = hung)" "$(cat "$T/m24b")"; fi
    printf 'outside the root\n' >"$T/outside.md"
    clone "$T/L" "$T/L24c"; rm -f "$T/L24c/pub/docs/plan.md"; ln -s "$T/outside.md" "$T/L24c/pub/docs/plan.md"
    runc "$T/m24c" --root "$T/L24c"; rc=$?
    if [ "$rc" -eq 2 ] && grep -q '^COULD-NOT-INSPECT .*pub/docs/plan\.md.*not a regular file inside --root' "$T/m24c" && no_finding "$T/m24c"; then ok "M24c a symlink leaving --root => rc 2 naming it (the target is never read)"
    else bad "M24c outside symlink rc=$rc" "$(cat "$T/m24c")"; fi
    # M24d control: a tracked symlink to a regular file INSIDE the root is hashed through, like the gate does
    clone "$T/L" "$T/L24d"; ln -s plan.md "$T/L24d/pub/docs/alias.md"; gcommit "$T/L24d/pub" 2021-06-01T00:00:00Z docs/alias.md && regate "$T/L24d" \
        || { echo "PROOF: symlink root could not be built" >&2; return 2; }
    runc "$T/m24d" --root "$T/L24d"; rc=$?
    if [ "$rc" -eq 1 ] && [ "$(findings "$T/m24d")" = "$exp" ] && ! grep -q '^COULD-NOT-INSPECT' "$T/m24d"; then ok "M24d control: a symlink to a regular file inside the root is hashed like the gate hashes it => rc 1"
    else bad "M24d rc=$rc" "$(cat "$T/m24d")"; fi

    # M25 the gate's exit must agree with its rows (each disagreement on its own)
    local m25=0 spec
    for spec in 'L:.exit = 0' 'L:.exit = 2' 'LC:.exit = 1' 'LC:.exit = 2' 'L:.exit = 7'; do
        clone "$T/${spec%%:*}" "$T/L25"; forge "$T/L25" "${spec#*:}"
        runc "$T/m25" --root "$T/L25"; rc=$?
        if [ "$rc" -eq 2 ] && cni_has "$T/m25" "inconsistent: exit=" && no_finding "$T/m25"; then :; else m25=1; bad "M25 [$spec] rc=$rc" "$(cat "$T/m25")"; fi
        rm -rf "$T/L25"
    done
    [ "$m25" -eq 0 ] && ok "M25 an exit code that disagrees with the rows (5 shapes) => rc 2"

    # M26 a row with a backslash in its public path, and one with an empty private field -> not registered, named
    clone "$T/L" "$T/L26"
    forge "$T/L26" '.leaks += [{"class":"prose","private":"priv/chapters/notes.md","public":"pub/docs/a\\b.md","line":1},
                               {"class":"prose","private":"","public":"pub/docs/plan.md","line":2}]'
    recount "$T/L26"
    runc "$T/m26" --root "$T/L26"; rc=$?
    if [ "$rc" -eq 1 ] && [ "$(findings "$T/m26")" = "$exp" ] && grep -q "^COULD-NOT-INSPECT $SENTINEL 2 surviving row" "$T/m26"; then ok "M26 a backslash path and an empty field => 2 rows named COULD-NOT-INSPECT, never a finding at a wrong location"
    else bad "M26 rc=$rc" "$(cat "$T/m26")"; fi

    # M27 a cache that still carries matched text is refused, and the text is never printed
    clone "$T/L" "$T/L27"; forge "$T/L27" '.leaks[0].match = "harbour lantern quay text"'
    runc "$T/m27" --root "$T/L27"; rc=$?
    if [ "$rc" -eq 2 ] && cni_has "$T/m27" "matched text" && no_finding "$T/m27" && ! grep -Eiq "$MT_RE" "$T/m27"; then ok "M27 a cache still holding .match => rc 2, the text never printed"
    else bad "M27 rc=$rc" "$(cat "$T/m27")"; fi

    # M28 a flag without its value ends (rc 2), never loops
    timeout 20 env -i PATH="$PATH" TMPDIR="$T/tmp" bash "$SELF_PATH" --root >"$T/m28" 2>&1 </dev/null; rc=$?
    timeout 20 env -i PATH="$PATH" TMPDIR="$T/tmp" bash "$SELF_PATH" --root "$T/L" --corpus >"$T/m28b" 2>&1 </dev/null; local rc28b=$?
    if [ "$rc" -eq 2 ] && [ "$rc28b" -eq 2 ]; then ok "M28 --root / --corpus without a value => rc 2 (no endless loop)"; else bad "M28 rc=$rc/$rc28b (124 = looped)"; fi

    # M29 an unknown argument under --emit-population keeps stdout token-only (either order)
    runc "$T/m29" --root "$T/L" --emit-population --bogus; rc=$?
    runc "$T/m29b" --bogus --root "$T/L" --emit-population; local rc29b=$?
    runc "$T/m29c" --root "$T/L" --bogus; local rc29c=$?
    if [ "$rc" -eq 2 ] && [ "$rc29b" -eq 2 ] && [ ! -s "$T/m29" ] && [ ! -s "$T/m29b" ] && [ "$rc29c" -eq 2 ] && grep -q '^COULD-NOT-INSPECT' "$T/m29c"; then ok "M29 unknown argument => rc 2; stdout empty under --emit-population, COULD-NOT-INSPECT otherwise"
    else bad "M29 rc=$rc/$rc29b/$rc29c" "$(cat "$T/m29" "$T/m29b" "$T/m29c")"; fi

    # M19 the live tree is byte-identical before and after the proof
    after=$(livefp)
    if [ -n "$before" ] && [ "$before" = "$after" ]; then ok "M19 live tree (corpus, class, gate, cache dir) byte-identical before/after"
    else bad "M19 live tree changed during the proof (a concurrent editor cannot be told apart)"; echo "proof: $P_PASS passed, $P_FAIL failed"; return 2; fi

    echo "proof: $P_PASS passed, $P_FAIL failed"
    [ "$P_FAIL" -eq 0 ] && return 0
    return 1
}

# ══════════════════════════════════════════════════════════════════════════════
ROOT="" CORPUS="" EMIT=0 BADARG=""
while [ $# -gt 0 ]; do
    case "$1" in
        --root|--corpus)
            # a flag without its value ends the parse (a bare `shift 2` would loop forever)
            if [ $# -lt 2 ]; then BADARG="$1 needs a value"; echo "$CLASS_ID: $1 needs a value" >&2; shift; continue; fi
            if [ "$1" = --root ]; then ROOT=$2; else CORPUS=$2; fi
            shift 2 ;;
        --emit-population) EMIT=1; shift ;;
        --prove-failure) prove_failure; exit $? ;;
        --help|-h) usage; exit 0 ;;
        # reported after the parse, so --emit-population keeps stdout token-only whatever the order
        *) [ -n "$BADARG" ] || BADARG="unknown argument"; echo "$CLASS_ID: unknown argument: $1" >&2; shift ;;
    esac
done

W=""
cleanup() { if [ -n "$W" ]; then rm -rf "$W"; fi; }
trap cleanup EXIT
EMPTY_SHA=$(printf '' | sha256sum | cut -d' ' -f1)

# finish_undet <part> <reason>: nothing could be walked. In --emit-population mode
# stdout carries tokens only, so the reason goes to stderr and the exit is 2.
finish_undet() {
    if [ "$EMIT" -eq 1 ]; then echo "$CLASS_ID: cannot enumerate: $2" >&2; exit 2; fi
    printf 'COULD-NOT-INSPECT %s %s\n' "$(zg_pct_encode "$1")" "$2"
    echo "INSPECTED 0"
    echo "POPULATION-SHA $EMPTY_SHA"
    exit 2
}

if [ -n "$BADARG" ]; then finish_undet - "$BADARG (usage: --root <dir> [--corpus <dir>] [--emit-population])"; fi
if [ -z "$ROOT" ] || [ ! -d "$ROOT" ]; then finish_undet - "--root is not a directory"; fi
ROOT=$(cd -- "$ROOT" 2>/dev/null && pwd) || finish_undet - "--root cannot be entered"
ROOTP=$(cd -- "$ROOT" 2>/dev/null && pwd -P) || finish_undet - "--root cannot be resolved"
for b in git jq cksum sha256sum awk sort od xargs grep tr cp mktemp wc cmp comm readlink dirname basename timeout; do
    command -v "$b" >/dev/null 2>&1 || finish_undet - "required tool '$b' is not on PATH"
done
[ "$(jq -n 1 2>/dev/null)" = 1 ] || finish_undet - "jq is present but does not work (jq -n 1 failed)"
[ -f "$ROOT/$GATE_REL" ] || finish_undet "$SENTINEL" "the gate script $GATE_REL is absent from --root: there is no gate result to register"
W=$(mktemp -d "${TMPDIR:-/tmp}/zg-cbr.XXXXXX") || { W=""; finish_undet - "mktemp failed"; }

SYNTH=0
if [ -n "$CORPUS" ]; then
    # ── corpus mode: run the REAL gate on a synthetic fleet built from <corpus>/fleet.tsv ──
    C=$(cd -- "$CORPUS" 2>/dev/null && pwd) || finish_undet - "--corpus is not a directory"
    [ -f "$C/fleet.tsv" ] || finish_undet fleet.tsv "the corpus has no fleet.tsv: an empty population is never clean"
    mkdir -p "$W/root" "$W/tmp"; : >"$W/spec"; : >"$W/allow"
    npub=0 npriv=0 dotrole="" dotdate=""
    # gcommit <dir> <date> [paths...]: a throwaway repository committed once at <date>
    gcommit() {
        local g=$1 dt=$2; shift 2
        ( cd "$g" && export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 \
          && git init -q && if [ $# -gt 0 ]; then git add -- "$@"; else git add -A; fi \
          && GIT_AUTHOR_DATE=$dt GIT_COMMITTER_DATE=$dt \
             git -c user.name=zg -c user.email=zg@example.invalid -c commit.gpgsign=false commit -qm seed ) >/dev/null 2>&1
    }
    while IFS=$'\t' read -r r role date _ || [ -n "${r:-}" ]; do
        case "$r" in ''|'#'*) continue ;; esac
        # `.` is the umbrella (every other top-level corpus entry); any other name is one plain directory
        case "$r" in .) ;; ..|.*|*[!A-Za-z0-9._-]*) finish_undet fleet.tsv "fleet.tsv names a directory outside [A-Za-z0-9._-] (or a dot name other than the umbrella .)" ;; esac
        case "$role" in public) npub=$((npub + 1)) ;; private) npriv=$((npriv + 1)) ;; *) finish_undet fleet.tsv "fleet.tsv role must be public or private" ;; esac
        [[ "$date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]] || finish_undet fleet.tsv "fleet.tsv date must be YYYY-MM-DDTHH:MM:SSZ"
        if [ "$r" = . ]; then
            [ -z "$dotrole" ] || finish_undet fleet.tsv "fleet.tsv names the umbrella . twice"
            dotrole=$role; dotdate=$date; continue
        fi
        [ -d "$C/$r" ] || finish_undet fleet.tsv "fleet.tsv names a directory the corpus does not hold"
        cp -R "$C/$r" "$W/root/$r" || finish_undet - "the throwaway fleet could not be copied"
        gcommit "$W/root/$r" "$date" || finish_undet - "a throwaway git repository could not be built"
        printf '%s\t%s\n' "$r" "$role" >>"$W/spec"
    done <"$C/fleet.tsv"
    if [ -n "$dotrole" ]; then
        # the umbrella: the corpus's other top-level entries, tracked at the fleet root itself
        set --
        for e in "$C"/*; do
            e=${e##*/}; [ "$e" = fleet.tsv ] && continue
            awk -F'\t' -v x="$e" '$1 == x { f = 1 } END { exit !f }' "$C/fleet.tsv" && continue
            cp -R "$C/$e" "$W/root/$e" || finish_undet - "the throwaway fleet could not be copied"
            set -- "$@" "$e"
        done
        [ $# -gt 0 ] || finish_undet fleet.tsv "fleet.tsv names the umbrella . but the corpus holds no umbrella entry"
        gcommit "$W/root" "$dotdate" "$@" || finish_undet - "the throwaway umbrella repository could not be built"
        { echo '/*'; for e in "$@"; do printf '!/%s\n' "$e"; done; } >"$W/root/.git/info/exclude"
        printf '.\t%s\n' "$dotrole" >>"$W/spec"
    fi
    if [ "$npub" -lt 1 ] || [ "$npriv" -lt 1 ]; then
        finish_undet fleet.tsv "a boundary needs at least one public and one private repository: an empty population is never clean"
    fi
    grc=0
    env -i PATH="$PATH" HOME="${HOME:-/nonexistent}" TMPDIR="$W/tmp" LC_ALL=C LANG=C \
        bash "$ROOT/$GATE_REL" --root "$W/root" --fleet-spec "$W/spec" --allow "$W/allow" --json \
        >"$W/g.json" 2>"$W/g.err" </dev/null || grc=$?
    [ -s "$W/g.json" ] || finish_undet "$SENTINEL" "the gate produced no JSON on the synthetic fleet (rc $grc)"
    # the gate's matched text never outlives this run: strip it before anything else reads the result
    jq -c '.leaks |= map(del(.match))' "$W/g.json" >"$W/g.strip" 2>/dev/null && mv "$W/g.strip" "$W/g.json" \
        || finish_undet "$SENTINEL" "the gate result on the synthetic fleet is not JSON (rc $grc)"
    EXPECT_ROOT="$W/root"; SYNTH=1
else
    # ── live mode: read the cache; never run the gate (measured > 600 s) ──
    if [ ! -f "$ROOT/$CACHE_JSON_REL" ] || [ ! -f "$ROOT/$CACHE_CORPUS_REL" ]; then
        finish_undet "$CACHE_JSON_REL" "cache absent: this class reads the gate result from $CACHE_JSON_REL and $CACHE_CORPUS_REL (the gate itself took over 600 s here, about 2170 s in full, and cannot run inside the class budget), so this class reports rc 2 until that one-time refresh is made; refresh it from the repository root with: $REFRESH_CMD"
    fi
    # snapshot both files first, so a concurrent refresh cannot change them mid-read
    cp "$ROOT/$CACHE_JSON_REL" "$W/g.json" && cp "$ROOT/$CACHE_CORPUS_REL" "$W/cached.corpus" \
        || finish_undet "$CACHE_JSON_REL" "the cache could not be read"
    EXPECT_ROOT="$ROOT"; grc=""
fi

# ── the gate result must be well-formed and internally consistent ──
jq -e 'type == "object" and (.leaks | type) == "array" and (.fleet | type) == "array"
       and (.undetermined | type) == "array" and (.exit | type) == "number"
       and ([.counts.leaks, .counts.prose, .counts.short, .counts.name, .counts.fingerprint,
             .counts.undetermined, .counts.not_indexed, .untracked.files_unscanned,
             .windows.long, .windows.short, .windows.short_line_max, .windows.names] | all(type == "number"))
       and (.corpus.stable | type) == "boolean" and (.root | type) == "string"
       and (.direction.enabled | type) == "boolean" and (.direction.status | type) == "string"
       and (.leaks | all(type == "object"))' "$W/g.json" >/dev/null 2>&1 \
    || finish_undet "$CACHE_JSON_REL" "the cached gate result is not the gate's --json shape (empty, truncated, unparseable, or from a gate that records no windows/direction/not_indexed fields); refresh it from the repository root with: $REFRESH_CMD"
# the refresh strips every matched string; a cache that still carries one is not the documented artefact (never printed)
if ! jq -e '.leaks | all(has("match") | not)' "$W/g.json" >/dev/null 2>&1; then
    finish_undet "$CACHE_JSON_REL" "the cached gate result still carries matched text (.leaks[].match): it was not written by the documented refresh, which strips it; delete it and refresh from the repository root with: $REFRESH_CMD"
fi
NLEAK=$(jq '.leaks | length' "$W/g.json"); CLEAK=$(jq '.counts.leaks' "$W/g.json")
NUND=$(jq '.undetermined | length' "$W/g.json"); CUND=$(jq '.counts.undetermined' "$W/g.json")
GEXIT=$(jq '.exit' "$W/g.json")
if [ "$NLEAK" != "$CLEAK" ]; then
    finish_undet "$CACHE_JSON_REL" "the cached gate result is inconsistent: counts.leaks=$CLEAK but $NLEAK leak row(s) are present (truncated); refresh it from the repository root with: $REFRESH_CMD"
fi
# per-class counts must sum to counts.leaks AND equal the rows of each class (an honest-accident guard, not a forgery guard)
if ! jq -e '(.counts.prose + .counts.short + .counts.name + .counts.fingerprint) == .counts.leaks
            and ([.leaks[] | select(.class == "prose")] | length) == .counts.prose
            and ([.leaks[] | select(.class == "short")] | length) == .counts.short
            and ([.leaks[] | select(.class == "name")] | length) == .counts.name
            and ([.leaks[] | select(.class == "fingerprint")] | length) == .counts.fingerprint' "$W/g.json" >/dev/null 2>&1; then
    finish_undet "$CACHE_JSON_REL" "the cached gate result is inconsistent: its per-class counts (prose, short, name, fingerprint) do not sum to counts.leaks or do not equal its rows of each class; refresh it from the repository root with: $REFRESH_CMD"
fi
case "$GEXIT" in
    1) [ "$NLEAK" -gt 0 ] ;;
    2) [ "$NLEAK" -eq 0 ] && [ "$CUND" -gt 0 ] ;;
    0) [ "$NLEAK" -eq 0 ] && [ "$CUND" -eq 0 ] ;;
    *) false ;;
esac || finish_undet "$CACHE_JSON_REL" "the cached gate result is inconsistent: exit=$GEXIT with $NLEAK surviving and $CUND undetermined row(s)"
if [ -n "$grc" ] && [ "$grc" != "$GEXIT" ]; then finish_undet "$SENTINEL" "the gate exited $grc but its JSON says exit $GEXIT"; fi
if [ "$(jq -r '.corpus.stable' "$W/g.json")" != true ]; then
    finish_undet "$CACHE_JSON_REL" "the gate measured a MOVING tree (corpus.stable=false): its rows describe no single state; refresh it on a quiet tree from the repository root with: $REFRESH_CMD"
fi
if [ "$(jq -r '.root' "$W/g.json")" != "$EXPECT_ROOT" ]; then
    finish_undet "$CACHE_JSON_REL" "the cached gate result was computed for another root; refresh it from the repository root with: $REFRESH_CMD"
fi
# the DEFAULT measurement only: a narrower run (--no-names, --no-short, --no-direction, another window) reports fewer
# rows and would read as a clean or smaller register. --allow and --name-rank/--name-ppm/--name-floor are NOT recorded
# in the gate's --json, so they cannot be checked here (declared in the header).
PARAMS=$(jq -r '[.windows.long, .windows.short, .windows.short_line_max, .windows.names, .direction.enabled, .direction.status, .direction.eligible] | map(tostring) | join(" ")' "$W/g.json" 2>/dev/null)
case "$PARAMS" in
    "10 5 9 1 true ran "*|"10 5 9 1 true idle 0") ;;
    *) finish_undet "$CACHE_JSON_REL" "the cached gate result is from a non-default gate run (window long/short/short_line_max/names, direction enabled/status/eligible = $PARAMS; the default measurement is 10 5 9 1 true ran, or idle with 0 eligible): a narrower run is not the register's population; refresh it from the repository root with: $REFRESH_CMD" ;;
esac
FSRC=$(jq -r '.fleet_source' "$W/g.json")
if [ -z "$CORPUS" ]; then
    case "$FSRC" in
        derived) ;;
        spec) if [ "$ROOT" = "$SELF_REPO" ]; then
                  finish_undet "$CACHE_JSON_REL" "the cached gate result used a SYNTHETIC --fleet-spec fleet, which is not evidence about this repository; refresh it from the repository root with: $REFRESH_CMD"
              fi
              SYNTH=1 ;;
        *) finish_undet "$CACHE_JSON_REL" "the cached gate result names no fleet source" ;;
    esac
fi
jq -r '.fleet[] | select(.role == "public" or .role == "private") | [.role, .path] | @tsv' "$W/g.json" >"$W/fleet" 2>/dev/null \
    || finish_undet "$CACHE_JSON_REL" "the fleet of the cached gate result cannot be read"
jq -r '.fleet[] | .path' "$W/g.json" 2>/dev/null | LC_ALL=C sort -u >"$W/fleet.paths" \
    || finish_undet "$CACHE_JSON_REL" "the fleet of the cached gate result cannot be read"
if [ -n "$CORPUS" ]; then
    # corpus mode: the gate's fleet is exactly the synthetic one it was handed
    jq -r '.fleet[] | [.path, .role] | @tsv' "$W/g.json" | LC_ALL=C sort >"$W/fleet.got"
    LC_ALL=C sort "$W/spec" >"$W/fleet.want"
    cmp -s "$W/fleet.got" "$W/fleet.want" || finish_undet "$SENTINEL" "the gate's fleet differs from the synthetic fleet it was handed"
else
    # ── the cached fleet must cover every repository this root DECLARES (the gate derives its fleet from
    #    .gitmodules plus the umbrella `.`; helix-deps.yaml is guarded against .gitmodules by cascade check C6) ──
    {
        if [ "$FSRC" = derived ]; then echo .; fi
        if [ -f "$ROOT/.gitmodules" ]; then
            grc_gm=0
            git config -f "$ROOT/.gitmodules" --get-regexp '^submodule\..*\.path$' >"$W/gm" 2>/dev/null || grc_gm=$?
            [ "$grc_gm" -le 1 ] || echo "//unreadable .gitmodules"
            sed 's/^[^ ]* //' "$W/gm"
        fi
        if [ -f "$ROOT/helix-deps.yaml" ]; then
            # deps[].name + deps[].layout (grouped -> submodules/<name>, flat -> <name>), the §11.4.31 schema
            awk '/^deps:/ { d = 1; next } /^[^ #]/ { d = 0 }
                 d && /^  - name:/ { n = $3; gsub(/["'"'"']/, "", n); next }
                 d && /^    layout:/ { l = $2; gsub(/["'"'"']/, "", l)
                     if (n == "") next
                     if (l == "grouped") print "submodules/" n; else if (l == "flat") print n; else print "//unknown layout for " n
                     n = "" }' "$ROOT/helix-deps.yaml"
        fi
    } | LC_ALL=C sort -u >"$W/declared"
    if grep -q '^//' "$W/declared"; then
        finish_undet "$CACHE_JSON_REL" "the fleet this root declares cannot be read ($(grep -m1 '^//' "$W/declared" | cut -c3- | tr -cd 'A-Za-z0-9 ._/-')): the cached fleet cannot be checked against it"
    fi
    LC_ALL=C comm -23 "$W/declared" "$W/fleet.paths" >"$W/missing"
    if [ -s "$W/missing" ]; then
        finish_undet "$CACHE_JSON_REL" "$(wc -l <"$W/missing" | tr -d ' ') repository path(s) this root declares (.gitmodules, helix-deps.yaml, the umbrella .) are absent from the cached fleet (first: $(zg_pct_encode "$(head -n1 "$W/missing")")): the gate result does not cover the declared fleet; refresh it from the repository root with: $REFRESH_CMD"
    fi
fi
if [ -z "$CORPUS" ]; then
    # ── freshness: the manifest must belong to this JSON, and describe the tree NOW ──
    mdig=$(printf '%08x' "$(cksum <"$W/cached.corpus" | awk '{ print $1 }')")
    if [ "$(wc -l <"$W/cached.corpus" | tr -d ' ')" != "$(jq '.corpus.files' "$W/g.json")" ] || [ "$mdig" != "$(jq -r '.corpus.digest' "$W/g.json")" ]; then
        finish_undet "$CACHE_CORPUS_REL" "the cached corpus manifest is not the one the cached JSON was computed over (file count or cksum digest differ); refresh it from the repository root with: $REFRESH_CMD"
    fi
    INCL=$(jq -r '.untracked.included // 0' "$W/g.json")
    # The gate's own enumeration rule (cb_ls_tracked / cb_ls_untracked / corpus_fingerprint),
    # re-implemented here because the gate cannot be sourced; the manifest comparison is
    # what proves the two agree on THIS tree. Unlike the gate, every listed entry is CLASSIFIED
    # before anything is opened: a FIFO, device or socket (or a symlink to one, to a directory,
    # dangling, or leaving --root) is never read, so it can neither hang the hashing nor pull
    # content from outside the tree; a plain directory (a nested gitlink) and a path absent from
    # the working tree are skipped exactly as the gate's cksum skips them.
    lsz() { # <abs dir> <untracked 0/1> -> NUL-separated names, the gate's filter applied
        { git -C "$1" ls-files -z 2>/dev/null
          if [ "$2" = 1 ]; then git -C "$1" ls-files --others --exclude-standard -z 2>/dev/null; fi
        } | tr '\0\n' '\n\001' | grep -vE '(lock\.json|\.min\.[A-Za-z0-9]+|\.map)$' | tr '\n\001' '\0\n' || :
    }
    resolve_link() { # <symlink> -> its final physical target path (portable: plain readlink + cd -P, at most 40 hops)
        local p=$1 n=0 l dir
        while [ -L "$p" ] && [ "$n" -lt 40 ]; do
            l=$(readlink -- "$p") || return 1
            case "$l" in /*) p=$l ;; *) p=$(dirname -- "$p")/$l ;; esac
            n=$((n + 1))
        done
        [ -L "$p" ] && return 1
        dir=$(cd -P -- "$(dirname -- "$p")" 2>/dev/null && pwd -P) || return 1
        printf '%s/%s\n' "$dir" "$(basename -- "$p")"
    }
    : >"$W/now.raw"; : >"$W/nonreg"; : >"$W/nlname"
    while IFS=$'\t' read -r role p; do
        [ -n "$p" ] || continue
        d="$ROOT/$p"; pfx="$p/"; if [ "$p" = . ]; then d="$ROOT"; pfx=""; fi
        u=0; if [ "$role" = public ] && [ "$INCL" = 1 ]; then u=1; fi
        lsz "$d" "$u" >"$W/lstz"
        # a name carrying a newline: the gate splits it at the newline and reads neither half (measured)
        if [ "$(tr -cd '\n' <"$W/lstz" | wc -c | tr -d ' ')" -gt 0 ]; then
            tr '\0\n' '\n\001' <"$W/lstz" | awk -v P="$pfx" 'index($0, "\001") { print P $0 }' | tr '\n\001' '\0\n' | zg_pct_encode_z >>"$W/nlname"
        fi
        tr '\0' '\n' <"$W/lstz" >"$W/lst"
        [ -s "$W/lst" ] || continue
        while IFS= read -r f; do
            q="$d/$f"
            if [ -L "$q" ]; then
                t=$(resolve_link "$q") || t=""
                case "$t" in
                    "$ROOTP"/*) if [ -f "$t" ]; then printf 'H\t%s\n' "$f"; continue; fi ;;
                esac
                printf 'N\t%s%s\n' "$pfx" "$f"
            elif [ -f "$q" ]; then printf 'H\t%s\n' "$f"
            elif [ -d "$q" ] || [ ! -e "$q" ]; then :
            else printf 'N\t%s%s\n' "$pfx" "$f"
            fi
        done <"$W/lst" >"$W/classified"
        awk '/^N\t/ { print substr($0, 3) }' "$W/classified" >>"$W/nonreg"
        awk '/^H\t/ { print substr($0, 3) }' "$W/classified" >"$W/hash.lst"
        [ -s "$W/nonreg" ] && continue
        [ -s "$W/hash.lst" ] || continue
        hrc=0
        ( cd "$d" && timeout "$HASH_TIMEOUT" xargs -a "$W/hash.lst" -d '\n' -r cksum 2>/dev/null ) >"$W/sums" || hrc=$?
        if [ "$hrc" -eq 124 ] || [ "$hrc" -ge 125 ]; then
            finish_undet "$CACHE_CORPUS_REL" "hashing the files of fleet repository $(zg_pct_encode "$p") did not finish within ${HASH_TIMEOUT}s (rc $hrc): the manifest cannot be recomputed"
        fi
        awk -v PFX="$pfx" 'match($0, /^[0-9]+ [0-9]+ /) { s = substr($0, 1, RLENGTH - 1); gsub(/ /, ":", s); print PFX substr($0, RLENGTH + 1) "\t" s }' "$W/sums" >>"$W/now.raw"
    done <"$W/fleet"
    if [ -s "$W/nonreg" ] || [ -s "$W/nlname" ]; then
        if [ "$EMIT" -eq 1 ]; then echo "$CLASS_ID: cannot enumerate: $(cat "$W/nonreg" "$W/nlname" | wc -l | tr -d ' ') fleet entr(y/ies) cannot be read" >&2; exit 2; fi
        LC_ALL=C sort -u "$W/nonreg" | head -n 20 | while IFS= read -r f; do
            printf 'COULD-NOT-INSPECT %s %s\n' "$(zg_pct_encode "$f")" "this tracked entry is not a regular file inside --root (a FIFO, device or socket, or a symlink that dangles, names a directory or leaves --root); it was never read, so the cached manifest cannot be recomputed and the cached rows cannot be proven fresh"
        done
        LC_ALL=C sort -u "$W/nlname" | head -n 20 | while IFS= read -r f; do
            printf 'COULD-NOT-INSPECT %s %s\n' "$f" "this tracked name carries a newline: the gate splits it at the newline and reads neither half, and counts it nowhere, so its content was never checked"
        done
        nx=$(( $(LC_ALL=C sort -u "$W/nonreg" | wc -l) + $(LC_ALL=C sort -u "$W/nlname" | wc -l) ))
        if [ "$nx" -gt 40 ]; then printf 'COULD-NOT-INSPECT %s %s\n' "$CACHE_CORPUS_REL" "$nx unreadable fleet entries in total; the first 20 of each kind are named above"; fi
        echo "INSPECTED 0"
        echo "POPULATION-SHA $EMPTY_SHA"
        exit 2
    fi
    LC_ALL=C sort -u "$W/now.raw" >"$W/now.corpus"
    if ! cmp -s "$W/now.corpus" "$W/cached.corpus"; then
        nd=$(awk -F'\t' 'NR == FNR { a[$1] = $2; next } { b[$1] = $2; if (!($1 in a) || a[$1] != $2) n++ } END { for (k in a) if (!(k in b)) n++; print n + 0 }' "$W/cached.corpus" "$W/now.corpus")
        finish_undet "$CACHE_CORPUS_REL" "cache stale: $nd enumerated file(s) differ between the cached corpus manifest and the tree now, so the cached rows describe another state; refresh it on a quiet tree from the repository root with: $REFRESH_CMD"
    fi
fi

# ── aggregate: one group per (public path class, gate class); counts and paths only ──
jq -r '.leaks[] | [.class, .private, .public] | @tsv' "$W/g.json" >"$W/rows" 2>/dev/null \
    || finish_undet "$CACHE_JSON_REL" "the leak rows of the gate result cannot be read"
awk -F'\t' -v FLEET="$W/fleet" -v BAD="$W/bad" '
    BEGIN { while ((getline l < FLEET) > 0) { split(l, f, "\t"); if (f[1] == "public") pub[f[2]] = 1; else prv[f[2]] = 1 } }
    function longest(q, set,   p, best, bl) {
        best = ""; bl = -1
        for (p in set) {
            if (p == ".") { if (bl < 0) { best = "."; bl = 0 } continue }
            if (index(q, p "/") == 1 && length(p) > bl) { best = p; bl = length(p) }
        }
        return best
    }
    {
        if (NF != 3 || $1 !~ /^[a-z]+$/ || $2 == "" || $3 == "" || index($0, "\\") > 0) { nbad++; next }
        r = longest($3, pub); pre = (r == "" || r == ".") ? "" : r "/"
        rel = substr($3, length(pre) + 1); n = split(rel, a, "/")
        pc = (n == 1) ? $3 : (n == 2 ? pre a[1] : pre a[1] "/" a[2])
        s = longest($2, prv); if (s == "") s = "(unattributed)"
        k = pc SUBSEP $1
        cnt[k]++; if (!((k, $3) in fs)) { fs[k, $3] = 1; nf[k]++ }
        if (!(k in first) || $3 < first[k]) first[k] = $3
        ps[k, s]++; if (!((k, s) in seen)) { seen[k, s] = 1; srcs[k] = srcs[k] SUBSEP s }
    }
    END {
        for (k in cnt) {
            split(k, kk, SUBSEP); m = split(substr(srcs[k], 2), sl, SUBSEP)
            for (i = 2; i <= m; i++) { v = sl[i]; j = i - 1; while (j > 0 && sl[j] > v) { sl[j + 1] = sl[j]; j-- } sl[j + 1] = v }
            d = ""; for (i = 1; i <= m; i++) d = d (i > 1 ? ", " : "") sl[i] " " ps[k, sl[i]]
            printf "%s\t%s\t%d\t%d\t%s\t%s\n", kk[1], kk[2], cnt[k], nf[k], d, first[k]
        }
        print nbad + 0 > BAD
    }' "$W/rows" >"$W/groups" || finish_undet "$CACHE_JSON_REL" "the leak rows could not be aggregated"
NBAD=$(cat "$W/bad" 2>/dev/null || echo 0)

band() { if [ "$1" -ge 1000 ]; then echo 1000+; elif [ "$1" -ge 100 ]; then echo 100-999; elif [ "$1" -ge 10 ]; then echo 10-99; elif [ "$1" -ge 2 ]; then echo 2-9; else echo 1; fi; }
: >"$W/find"; : >"$W/pop"
printf '%s\n' "$SENTINEL" >>"$W/pop"
while IFS=$'\t' read -r pc gc n nfile srcs firstpub; do
    [ -n "$pc" ] || continue
    epc=$(zg_pct_encode "$pc"); printf '%s\n' "$epc" >>"$W/pop"
    extra=""; case "$gc" in name|fingerprint) extra=" (the gate withholds every $gc value; counted only)" ;; esac
    # evidence_ref: live -> the gate's documentation; corpus -> the group's first public corpus
    # file (the runner resolves a corpus finding's evidence_ref inside the corpus directory)
    ref=$EVIDENCE_REF; if [ -n "$CORPUS" ]; then ref=$(zg_pct_encode "$firstpub"); fi
    syn=""; if [ "$SYNTH" -eq 1 ]; then syn=" [synthetic fleet, not evidence about any real repository]"; fi
    printf 'FINDING %s high content-boundary %s:%s %s surviving %s row(s) of %s (count band %s) in %s public file(s) under this path class; private source repositories by path: %s; matched text withheld%s, rows neither judged nor allow-listed: read and judge them per %s%s %s\n' \
        "$CLASS_ID" "$epc" "$gc" "$n" "$gc" "$GATE_REL" "$(band "$n")" "$nfile" "$srcs" "$extra" "$EVIDENCE_REF" "$syn" "$ref" >>"$W/find"
done <"$W/groups"
LC_ALL=C sort -u "$W/pop" >"$W/pop.sorted"

if [ "$EMIT" -eq 1 ]; then cat "$W/pop.sorted"; exit 0; fi

LC_ALL=C sort -k5,5 "$W/find"
nc=0
if [ "$NBAD" -gt 0 ]; then
    printf 'COULD-NOT-INSPECT %s %s\n' "$SENTINEL" "$NBAD surviving row(s) carry a path the gate's JSON cannot hold faithfully (a backslash or a control character) or a malformed field; they are not registered"
    nc=$((nc + 1))
fi
if [ "$NUND" -gt 0 ]; then
    printf 'COULD-NOT-INSPECT %s %s\n' "$SENTINEL" "the gate result carries $NUND undetermined row(s) (paths only, in its --json undetermined list); this class registers surviving rows only, so those parts stay uninspected"
    nc=$((nc + 1))
fi
# files the gate enumerated but never READ are not a clean result (review rev-cbrows fix 2)
NIDX=$(jq '.counts.not_indexed' "$W/g.json"); NUNS=$(jq '.untracked.files_unscanned' "$W/g.json")
if [ "$NIDX" -gt 0 ]; then
    printf 'COULD-NOT-INSPECT %s %s\n' "$SENTINEL" "$NIDX file(s) were not indexed by the gate (over its size cap or machine-generated; counts.not_indexed): their content was never read, so no row about them exists and their absence is not a clean result"
    nc=$((nc + 1))
fi
if [ "$NUNS" -gt 0 ]; then
    printf 'COULD-NOT-INSPECT %s %s\n' "$SENTINEL" "$NUNS untracked public file(s) were not scanned by the gate (untracked.files_unscanned; the default run reads tracked files only): their content was never read"
    nc=$((nc + 1))
fi
echo "INSPECTED $(wc -l <"$W/pop.sorted" | tr -d ' ')"
echo "POPULATION-SHA $(sha256sum <"$W/pop.sorted" | cut -d' ' -f1)"
if [ -s "$W/find" ]; then exit 1; fi
if [ "$nc" -gt 0 ]; then exit 2; fi
exit 0
