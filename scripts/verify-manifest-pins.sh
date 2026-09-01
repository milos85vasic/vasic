#!/usr/bin/env bash
# verify-manifest-pins.sh — the §11.4.31 PIN half of the manifest contract:
# every `deps[].ref` recorded in `helix-deps.yaml` is the commit this
# repository actually records for that submodule's gitlink. See
# "WHICH live" below for exactly which of the three candidate commits that is,
# and why.
#
# ── Why this file exists ─────────────────────────────────────────────────────
# `scripts/verify-governance-cascade.sh` check C6 compares the manifest and the
# fleet by NAME, in both directions. That is a real property and it stays. But
# it is only half of §11.4.31: a manifest can name exactly the right seven
# submodules and record seven WRONG commits, and C6 goes green over it.
#
# That is not hypothetical. Measured on 2026-09-01 at HEAD 63ac4df:
#
#   dep              recorded ref                              live gitlink
#   constitution     448981ae3498229c734dc60719f4b19f01d7a75f  902979027a90…
#   vasic.digital    v1.8.0 -> 9d408cd0b1012048c36bb711b801a…  6e5411c21b3c…
#   milosvasic.ru    v1.8.0 -> 366f160bf61e7b9f701012958ce03…  8166fdba295d…
#   design-toolkit   16e4e76d57ab61b5f3b46fae3372b2e6d6cc73e3  efd2c3fb2f88…
#   ai_interviewing  023abbfdfe12a604144cf420d1ec3d9efaa6e89c  ed73d8558e28…
#   monetization     1f9f52042a81c9a2d0e0f2f42e3ca9fbf4d7fbfe  54ed7b0f5add…
#   workshop         ff59fca320efd839c9322bcf6f683ccb74754da8  55076bf943a5…
#
# SEVEN of seven wrong, and `verify-governance-cascade.sh` exited 0 anyway
# (10 PASS / 0 FAIL / 0 ENV). The `workshop` entry is the sharpest case: it was
# ADDED in commit 63ac4df recording ff59fca — and 63ac4df is the very commit
# that moved the `workshop` gitlink to 55076bf. The entry was untrue in the
# commit that created it, and nothing in the tree could say so.
#
# This project's constitution (`.specify/memory/constitution.md`) names the
# defect class twice over: "A document that states a status MUST name the
# command that re-derives it" (Comprehensive Documentation) and "A gate that has
# never been observed failing is not known to work" (Isolation by Default). A
# `ref:` that nothing re-derives is a status nobody can date.
#
# ── What `ref:` MEANS here, decided and enforced ─────────────────────────────
# `helix-deps.yaml`'s own header calls its refs "pinned", says each entry "names
# the sha AND the branch the gitlink tracks, so nothing is guessed", and closes
# with a "Pin drift — compare each `ref` against the live gitlink" recipe. The
# file's stated intent is therefore reading (a): **`ref:` is a PIN the tree MUST
# match**, not a last-known-good souvenir. This checker enforces exactly that
# intent; it does not invent a third reading, and the manifest now says so in
# one sentence at the top of its `Refs` section.
#
# ── WHICH "live" — the choice, and why it is this one ────────────────────────
# There are three candidate answers to "what commit is this submodule really
# at", and they are genuinely different states. This gate compares against the
# INDEX gitlink — `git ls-files -s -- <path>` — and reports the other two.
#
#   * The INDEX gitlink (CHOSEN). This is the commit the repository is about to
#     record, and for any clean tree it is byte-identical to the committed one.
#     A gitlink enters the index only when someone deliberately STAGES a
#     submodule bump, which is exactly the moment this file starts lying — so
#     the gate fires at `git add`, one step BEFORE the untrue commit exists,
#     and keeps firing after it (index == HEAD once committed). It also sees a
#     submodule being onboarded in the current change-window, which HEAD cannot:
#     a newly added gitlink is in the index and absent from HEAD, and a gate
#     that could not evaluate it would have to report state 2 through the whole
#     onboarding — the exact "cannot fail, so cannot help" shape being removed.
#
#   * The COMMITTED gitlink, `git ls-tree HEAD` (rejected as the primary, kept
#     as a NOTE). It fires one commit too late and is blind to work in progress.
#     Where it disagrees with the index, that divergence is REPORTED, because it
#     means a submodule bump is staged and not yet committed — useful context,
#     never a verdict.
#
#   * The submodule WORKING TREE's HEAD, i.e. what `git submodule status`
#     prints (rejected). It would go red every time a developer checked a
#     submodule out to look at something — states that were never recorded
#     anywhere and harm nobody. A gate that red-lights uncommitted local
#     exploration is the kind that gets `--no-verify`'d within a week. Also
#     REPORTED as a NOTE, never as a verdict input.
#
#   * "No more than N commits stale" (rejected, and this is the interesting
#     one). Three defects: (1) it needs BOTH commits reachable in the
#     submodule's object store to count the distance — after a force-push, a
#     shallow clone, or a pruned branch the recorded sha is simply gone and the
#     count is unanswerable, which turns a routine check into a permanent
#     state 2; (2) it needs every submodule initialised, which is itself
#     state 2; (3) any N legitimises a manifest that is KNOWABLY wrong for N
#     commits, and §11.4.6 has no tolerance band — either the recorded state is
#     the state or it is not. A pin is boolean; only its remedy needs to be cheap.
#
# Cheap remedy is how bypass pressure is answered instead: every drift line
# names the dep, the recorded ref, the live gitlink, and `--fix`, which rewrites
# the manifest to the truth in one command (after a §9 hardlinked backup).
#
# ── Where it runs ────────────────────────────────────────────────────────────
# `verify-governance-cascade.sh` check C9 delegates to this file, so the pin
# half rides the existing entry points with no new wiring: the §11.4.32 sweep
# (`scripts/verify-all-constitution-rules.sh` step 1) and the local pre-push
# hook both reach it through the cascade. It is also runnable directly.
#
# ── Usage ────────────────────────────────────────────────────────────────────
#   scripts/verify-manifest-pins.sh [--root <project-root>] [--quiet]
#   scripts/verify-manifest-pins.sh --fix [--root <project-root>]
#   scripts/verify-manifest-pins.sh --prove-failure [--quiet]
#     --root <dir>     project root to verify (default: this script's parent
#                      directory). A bare positional <dir> means the same thing.
#     --quiet          suppress the per-dep table and PASS lines. FAIL, ENV and
#                      the summary are ALWAYS shown.
#     --fix            rewrite every drifted `ref:` to the live gitlink. Takes a
#                      hardlinked backup under .git/ first (§9: no naked writes).
#                      Only values that were DETERMINED are written; an
#                      undetermined dep is left alone and reported. The EXIT CODE
#                      still reports the state as FOUND, not as left — a run that
#                      repaired a drift exits 1, deliberately, so `--fix` can
#                      never be used to launder a red gate into a green one.
#                      Re-run without `--fix` to get the post-repair verdict.
#     --prove-failure  run the paired §1.1 mutation proof (see below).
#     -h|--help        this header.
#
# ── Exit codes (three-valued, per "Honest Instruments") ──────────────────────
#   0 — every recorded ref was compared and equals the committed gitlink.
#   1 — at least one recorded ref was compared and DIFFERS. Real drift.
#   2 — COULD NOT DETERMINE: git absent, target is not a git work tree,
#       manifest missing/unreadable/parsing to zero deps, no gitlink at a
#       declared path, a symbolic ref whose submodule is NOT INITIALISED, or a
#       symbolic ref that does not resolve in the checkout.
#       An UNINITIALISED SUBMODULE IS ALWAYS STATE 2 — never a pass, never a
#       violation. State 2 outranks state 1 in the summary (same precedence the
#       cascade verifier uses): a run that could not see everything must not be
#       read as a complete verdict, and the drift lines are printed regardless.
#   In --prove-failure: 0 = control green and every mutation produced its
#   required code; 1 = a mutation was not caught (this gate would be a sham,
#   §1.1); 2 = the sandbox could not be built.
#
# ── Side-effects ─────────────────────────────────────────────────────────────
#   Default mode: read-only. Every git invocation is a read (`ls-tree`,
#   `rev-parse`, `describe`); no submodule working tree is written or checked
#   out; `git submodule update` is never run.
#   --fix: writes ONLY <root>/helix-deps.yaml, after hardlinking a backup.
#   --prove-failure: writes ONLY inside a `mktemp -d` sandbox, trap-removed.
#
# ── Dependencies ─────────────────────────────────────────────────────────────
#   bash, git, POSIX awk/grep/sed/cp/mv/mkdir/ln/sort. bash -n clean.
#
# ── Honest boundaries (§11.4.6) ──────────────────────────────────────────────
#   1. A ref token of 7..40 hex characters is read as an object name. A BRANCH
#      or TAG whose name happens to be valid hex (`deadbeef`) would be misread —
#      the same ambiguity git itself has. Write such a ref as `refs/tags/<name>`
#      or `refs/heads/<name>`; any ref starting with `refs/` is always treated
#      as symbolic. No entry in this repository's manifest is affected today.
#   2. This checks THIS root's manifest against THIS root's gitlinks. It does
#      NOT reconcile two manifests that declare the same dep at different refs
#      (§11.4.31 `conflict_resolution: operator-required`). One such conflict is
#      live and is recorded in helix-deps.yaml rather than silently gated here.
#   3. It says nothing about whether the pinned commit is a GOOD commit. It only
#      says the record matches the tree.

set -uo pipefail

GATE="CM-MANIFEST-PIN-SYNC"

# ── INTERNAL-FAULT TRAP: a crash is rc=2, never rc=1 ─────────────────────────
# Identical reasoning to verify-governance-cascade.sh: `set -u` aborts with
# status 1, the code reserved here for a REAL drift, so a broken instrument
# would accuse a healthy tree. The decidable signal is "exited 1 without having
# emitted a verdict line"; every deliberate rc=1 path sets the flag first.
_verdict_emitted=0
_sandbox_to_clean=""
_on_exit() {
    local rc=$?
    trap - EXIT INT TERM
    [ -n "$_sandbox_to_clean" ] && rm -rf "$_sandbox_to_clean"
    if [ "$rc" -eq 1 ] && [ "$_verdict_emitted" -eq 0 ]; then
        echo "${GATE}: INTERNAL-FAULT — aborted with status 1 before emitting any verdict." >&2
        echo "${GATE}: an instrument that crashes MUST NOT accuse the tree (§11.4.201(1))." >&2
        echo "${GATE}: re-mapped to rc=2 COULD NOT DETERMINE — this is NOT a violation verdict." >&2
        exit 2
    fi
    exit "$rc"
}
trap '_on_exit' EXIT INT TERM

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

root=""
quiet=""
fix=""
prove=""

while [ $# -gt 0 ]; do
    case "$1" in
        --root)  root="${2:-}"; shift 2 ;;
        --quiet) quiet="1"; shift ;;
        --fix)   fix="1"; shift ;;
        --prove-failure) prove="1"; shift ;;
        -h|--help) awk 'NR==1{next} /^#/{sub(/^# ?/,""); print; next} {exit}' "$0"; exit 0 ;;
        -*) echo "${GATE}: unknown arg '$1'" >&2; exit 2 ;;
        *)  if [ -n "$root" ]; then
                echo "${GATE}: more than one target root given ('${root}', '$1')" >&2; exit 2
            fi
            root="$1"; shift ;;
    esac
done

[ -n "$root" ] || root="${REPO_ROOT}"
[ -d "$root" ] || { echo "${GATE}: project root not found: '${root}'" >&2; exit 2; }
root="$(cd "$root" && pwd -P)"

MANIFEST_NAME="helix-deps.yaml"

pass=0; fail=0; undet=0
ok()   { pass=$((pass+1));   [ -n "$quiet" ] || echo "✅ PASS  $1"; }
bad()  { fail=$((fail+1));   echo "❌ DRIFT $1"; }
und()  { undet=$((undet+1)); echo "⚠ ENV   $1"; }
inf()  { [ -n "$quiet" ] || echo "ℹ NOTE  $1"; }

# ─────────────────────────────────────────────────────────────────────────────
# Manifest parsing. Emits one `name<TAB>path<TAB>ref` line per deps[] entry.
#
# The layout mapping is the one helix-deps.yaml documents about itself, and is
# deliberately the SAME mapping verify-governance-cascade.sh's helix_dep_paths
# uses, so "which directory is this dep" is answered identically by both
# verifiers rather than by two parsers that can disagree:
#   layout: flat    -> <root>/<name>
#   layout: grouped -> <root>/submodules/<name>
#
# Scalars are read with quotes honoured and trailing `# comments` stripped, so
# `ref: "abc"   # note` and `ref: abc   # note` both yield `abc`. A missing
# `ref:` yields an empty field, which the caller reports as state 2 — never as
# a pass.
# ─────────────────────────────────────────────────────────────────────────────
manifest_entries() {
    awk '
        function scalar(line,   q, i) {
            sub(/^[^:]*:[[:space:]]*/, "", line)
            q = ""
            if (substr(line, 1, 1) == "\"")   q = "\""
            else if (substr(line, 1, 1) == "\047") q = "\047"
            if (q != "") {
                line = substr(line, 2)
                i = index(line, q)
                if (i > 0) line = substr(line, 1, i - 1)
            } else {
                sub(/[[:space:]]*#.*$/, "", line)
            }
            gsub(/^[[:space:]]+/, "", line); gsub(/[[:space:]]+$/, "", line)
            return line
        }
        function flush() {
            if (name != "")
                print name "\t" (layout == "grouped" ? "submodules/" name : name) "\t" ref
            name = ""; ref = ""; layout = "flat"
        }
        BEGIN { in_deps = 0; name = ""; ref = ""; layout = "flat" }
        /^deps:[[:space:]]*$/                       { flush(); in_deps = 1; next }
        /^[A-Za-z_][A-Za-z0-9_]*[[:space:]]*:/      { if (in_deps) { flush(); in_deps = 0 } next }
        in_deps && /^[[:space:]]*-[[:space:]]*name[[:space:]]*:/ { flush(); name = scalar($0); next }
        in_deps && /^[[:space:]]*ref[[:space:]]*:/               { if (name != "") ref    = scalar($0); next }
        in_deps && /^[[:space:]]*layout[[:space:]]*:/            { if (name != "") layout = scalar($0); next }
        END { flush() }
    ' "$1"
}

# is_hex_ref <ref> — true when the token is an object name (7..40 hex chars).
# `refs/...` is always symbolic; see honest boundary 1 in the header.
is_hex_ref() {
    case "$1" in refs/*) return 1 ;; esac
    printf '%s' "$1" | grep -qE '^[0-9a-fA-F]{7,40}$'
}

lower() { printf '%s' "$1" | tr 'A-Z' 'a-z'; }

# ─────────────────────────────────────────────────────────────────────────────
# The check.
# ─────────────────────────────────────────────────────────────────────────────
DRIFTED=""          # "name<TAB>live-sha" per line — the input to --fix

check_pins() {
    local hd="${root}/${MANIFEST_NAME}"
    local toplevel line name path ref gitlink resolved shown want got sub desc
    local n_entries=0

    if ! command -v git >/dev/null 2>&1; then
        und "PIN-SYNC — git is not on PATH; the committed gitlinks cannot be read"
        echo "         fix: install git, or run this gate on a host that has it."
        return 2
    fi
    toplevel="$(git -C "$root" rev-parse --show-toplevel 2>/dev/null)" || toplevel=""
    if [ -z "$toplevel" ] || [ "$(cd "$toplevel" 2>/dev/null && pwd -P)" != "$root" ]; then
        und "PIN-SYNC — '${root}' is not the top level of a git work tree; there are no committed gitlinks to compare against"
        echo "         fix: point --root at a real checkout. A verifier that cannot see MUST NOT report a pass."
        return 2
    fi
    if [ ! -f "$hd" ] || [ ! -r "$hd" ]; then
        und "PIN-SYNC — ${MANIFEST_NAME} missing or unreadable at ${hd}; the pins cannot be read"
        echo "         fix: restore the manifest (§11.4.31 mandates it at this canonical path)."
        return 2
    fi

    local entries
    entries="$(manifest_entries "$hd")"
    n_entries="$(printf '%s\n' "$entries" | grep -c '.')"
    if [ -z "${entries//[$' \t\r\n']/}" ] || [ "$n_entries" -eq 0 ]; then
        und "PIN-SYNC — ${MANIFEST_NAME} parsed to ZERO deps[] entries; a manifest that declares nothing certifies nothing"
        echo "         fix: the file is empty, truncated, or its deps[] block is malformed. Confirm with:"
        echo "              python3 -c \"import yaml,sys;print(len(yaml.safe_load(open(sys.argv[1]))['deps']))\" ${MANIFEST_NAME}"
        return 2
    fi

    [ -n "$quiet" ] || {
        printf '  %-17s %-42s %-42s %s\n' "dep" "manifest ref" "live gitlink (index)" "verdict"
        printf '  %-17s %-42s %-42s %s\n' "-----------------" \
               "------------------------------------------" \
               "------------------------------------------" "-------"
    }

    while IFS=$'\t' read -r name path ref; do
        [ -n "$name" ] || continue

        gitlink="$(git -C "$root" ls-files -s -- "$path" 2>/dev/null | awk '$1=="160000"{print $2; exit}')"
        if [ -z "$gitlink" ]; then
            [ -n "$quiet" ] || printf '  %-17s %-42s %-42s %s\n' "$name" "${ref:-<none>}" "<no gitlink>" "UNDET"
            und "PIN-SYNC ${name} — no gitlink at '${path}' in the index; nothing to compare the recorded ref to"
            echo "         fix: C6 in verify-governance-cascade.sh owns the name-level half of this — a deps[]"
            echo "              entry whose path .gitmodules does not declare is C6's phantom check, not a pin"
            echo "              violation, so it is reported here as UNDETERMINED and not double-counted."
            continue
        fi

        if [ -z "$ref" ]; then
            [ -n "$quiet" ] || printf '  %-17s %-42s %-42s %s\n' "$name" "<none>" "$gitlink" "UNDET"
            und "PIN-SYNC ${name} — no 'ref:' recorded; §11.4.31's schema requires one on every dep"
            echo "         fix: add   ref: \"${gitlink}\"   to the '${name}' entry in ${MANIFEST_NAME}."
            continue
        fi

        if is_hex_ref "$ref"; then
            want="$(lower "$ref")"; got="$(lower "$gitlink")"
            desc="$ref"
            if [ "${#want}" -eq 40 ]; then
                [ "$want" = "$got" ] && shown="MATCH" || shown="DRIFT"
            else
                # An abbreviated object name pins by prefix — the form the
                # constitution's own manifest uses (`ref: 16e4e76`).
                [ "${got:0:${#want}}" = "$want" ] && shown="MATCH" || shown="DRIFT"
            fi
        else
            # Symbolic ref (tag or branch). Resolving it REQUIRES the submodule
            # checkout. Not initialised => state 2, never a pass and never a
            # violation: we simply do not know what the tag points at.
            sub="${root}/${path}"
            if [ ! -e "${sub}/.git" ]; then
                [ -n "$quiet" ] || printf '  %-17s %-42s %-42s %s\n' "$name" "$ref" "$gitlink" "UNDET"
                und "PIN-SYNC ${name} — ref '${ref}' is symbolic and '${path}' is NOT INITIALISED; it cannot be resolved to a commit"
                echo "         fix: initialise the submodule, then re-run:"
                echo "              git submodule update --init ${path} && scripts/verify-manifest-pins.sh"
                continue
            fi
            resolved="$(git -C "$sub" rev-parse --verify --quiet "${ref}^{commit}" 2>/dev/null)" || resolved=""
            if [ -z "$resolved" ]; then
                [ -n "$quiet" ] || printf '  %-17s %-42s %-42s %s\n' "$name" "$ref" "$gitlink" "UNDET"
                und "PIN-SYNC ${name} — ref '${ref}' does not resolve in '${path}'; unfetched tag and typo are indistinguishable from here"
                echo "         fix: git -C ${path} fetch --tags   then re-run. If the ref is genuinely gone,"
                echo "              record the commit instead:  scripts/verify-manifest-pins.sh --fix"
                continue
            fi
            desc="${ref} -> ${resolved}"
            want="$(lower "$resolved")"; got="$(lower "$gitlink")"
            [ "$want" = "$got" ] && shown="MATCH" || shown="DRIFT"
        fi

        [ -n "$quiet" ] || printf '  %-17s %-42s %-42s %s\n' "$name" "$desc" "$gitlink" "$shown"

        if [ "$shown" = "MATCH" ]; then
            ok "PIN-SYNC ${name} — recorded ref ${desc} == index gitlink ${gitlink}"
        else
            DRIFTED="${DRIFTED}${name}"$'\t'"${gitlink}"$'\n'
            bad "PIN-SYNC ${name} — recorded ref does NOT match the live gitlink"
            echo "         dep          : ${name}   (path ${path})"
            echo "         manifest ref : ${desc}"
            echo "         live gitlink : ${gitlink}   (git ls-files -s -- ${path})"
            echo "         fix: scripts/verify-manifest-pins.sh --fix"
            echo "              (rewrites this ref to ${gitlink} after a hardlinked backup; §11.4.31 / §11.4.6)"
        fi

        # The two OTHER answers to "what commit is it really at", REPORTED and
        # never a verdict input. Both are legitimate, uncommitted, local states;
        # failing on either is the noise that gets a gate bypassed.
        local head_link wt
        head_link="$(git -C "$root" ls-tree HEAD -- "$path" 2>/dev/null | awk '$1=="160000"{print $3; exit}')"
        if [ -z "$head_link" ]; then
            inf "PIN-SYNC ${name} — newly STAGED: the gitlink is in the index and absent from HEAD (submodule onboarding in progress). Checked against the index, which is what the next commit will record."
        elif [ "$head_link" != "$gitlink" ]; then
            inf "PIN-SYNC ${name} — a gitlink bump is STAGED: index ${gitlink} vs HEAD ${head_link}. Checked against the index, i.e. against what the next commit will record."
        fi
        if [ -e "${root}/${path}/.git" ]; then
            wt="$(git -C "${root}/${path}" rev-parse --verify --quiet HEAD 2>/dev/null)" || wt=""
            if [ -n "$wt" ] && [ "$wt" != "$gitlink" ]; then
                inf "PIN-SYNC ${name} — working tree is checked out at ${wt}, not at the index gitlink ${gitlink}; not a verdict input (uncommitted local state)"
            fi
        fi
    done <<< "$entries"

    echo "----------------------------------------------------------------------"
    echo "${GATE}: ${pass} MATCH, ${fail} DRIFT, ${undet} UNDETERMINED  of ${n_entries} declared dep(s)  (root ${root})"
    _verdict_emitted=1
    # State 2 outranks state 1, the same precedence verify-governance-cascade.sh
    # applies: a run that could not see every dep must not be read as a complete
    # verdict. The DRIFT lines above are printed either way, never suppressed.
    if [ "$undet" -gt 0 ]; then
        echo "⚠ ${GATE}: COULD NOT DETERMINE — ${undet} dep(s) could not be compared; rc=2, NOT a violation verdict"
        return 2
    fi
    if [ "$fail" -gt 0 ]; then
        echo "❌ ${GATE}: FAIL — ${fail} recorded ref(s) do not match the live gitlink (§11.4.31)"
        return 1
    fi
    echo "✅ ${GATE}: PASS — all ${n_entries} recorded ref(s) equal the gitlink this repository will commit"
    return 0
}

# ─────────────────────────────────────────────────────────────────────────────
# --fix — rewrite drifted refs to the live gitlinks.
#
# §9 "no naked writes": a hardlinked backup is taken first. It goes under
# <root>/.git/ so it is on the same filesystem (a hardlink cannot cross one) and
# is never tracked, never staged by a `git add .`, and never shipped.
# ─────────────────────────────────────────────────────────────────────────────
apply_fix() {
    local hd="${root}/${MANIFEST_NAME}" gitdir bakdir bak tmp fixfile n
    if [ -z "${DRIFTED//[$' \t\r\n']/}" ]; then
        echo "${GATE}: --fix — nothing to rewrite; no dep was measured as drifted."
        return 0
    fi
    n="$(printf '%s' "$DRIFTED" | grep -c '.')"

    gitdir="$(git -C "$root" rev-parse --git-dir 2>/dev/null)" || gitdir=""
    case "$gitdir" in ""|/*) : ;; *) gitdir="${root}/${gitdir}" ;; esac
    if [ -n "$gitdir" ] && [ -d "$gitdir" ]; then
        bakdir="${gitdir}/manifest-pin-backups"
    else
        bakdir="$(mktemp -d)" || { echo "${GATE}: ENV — cannot create a backup directory" >&2; return 2; }
    fi
    mkdir -p "$bakdir" || { echo "${GATE}: ENV — cannot create ${bakdir}" >&2; return 2; }
    bak="${bakdir}/${MANIFEST_NAME}.$(date -u +%Y%m%dT%H%M%SZ).$$"
    if ! ln "$hd" "$bak" 2>/dev/null; then
        cp -p "$hd" "$bak" || { echo "${GATE}: ENV — could not back up ${hd}" >&2; return 2; }
        echo "${GATE}: --fix — hardlink unavailable on this filesystem; took a copy backup instead."
    fi
    echo "${GATE}: --fix — backup: ${bak}"

    fixfile="$(mktemp)" || { echo "${GATE}: ENV — mktemp failed" >&2; return 2; }
    printf '%s' "$DRIFTED" > "$fixfile"
    tmp="$(mktemp)" || { rm -f "$fixfile"; echo "${GATE}: ENV — mktemp failed" >&2; return 2; }

    # Rewrites ONLY the value token of a matched dep's `ref:` line, preserving
    # indentation, the quoting style already in the file, and any trailing
    # comment. Nothing else in the manifest is touched.
    awk -v fixfile="$fixfile" '
        function scalar_name(line,   q, i) {
            sub(/^[^:]*:[[:space:]]*/, "", line)
            q = ""
            if (substr(line, 1, 1) == "\"")   q = "\""
            else if (substr(line, 1, 1) == "\047") q = "\047"
            if (q != "") { line = substr(line, 2); i = index(line, q); if (i > 0) line = substr(line, 1, i - 1) }
            else { sub(/[[:space:]]*#.*$/, "", line) }
            gsub(/^[[:space:]]+/, "", line); gsub(/[[:space:]]+$/, "", line)
            return line
        }
        BEGIN {
            while ((getline l < fixfile) > 0) { split(l, a, "\t"); if (a[1] != "") want[a[1]] = a[2] }
            in_deps = 0; cur = ""
        }
        /^deps:[[:space:]]*$/                  { in_deps = 1; cur = ""; print; next }
        /^[A-Za-z_][A-Za-z0-9_]*[[:space:]]*:/ { if (in_deps) { in_deps = 0; cur = "" } print; next }
        in_deps && /^[[:space:]]*-[[:space:]]*name[[:space:]]*:/ { cur = scalar_name($0); print; next }
        in_deps && /^[[:space:]]*ref[[:space:]]*:/ && cur != "" && (cur in want) {
            head = ""; rest = $0
            if (match(rest, /^[[:space:]]*ref[[:space:]]*:[[:space:]]*/)) {
                head = substr(rest, 1, RLENGTH); rest = substr(rest, RLENGTH + 1)
            }
            q = ""
            if (substr(rest, 1, 1) == "\"")   q = "\""
            else if (substr(rest, 1, 1) == "\047") q = "\047"
            if (q != "") {
                i = index(substr(rest, 2), q)
                tail = (i > 0) ? substr(rest, i + 2) : ""
            } else if (match(rest, /[[:space:]#]/)) {
                tail = substr(rest, RSTART)
            } else {
                tail = ""
            }
            print head q want[cur] q tail
            next
        }
        { print }
    ' "$hd" > "$tmp" || { rm -f "$fixfile" "$tmp"; echo "${GATE}: ENV — rewrite failed" >&2; return 2; }

    if [ ! -s "$tmp" ]; then
        rm -f "$fixfile" "$tmp"
        echo "${GATE}: ENV — the rewrite produced an empty file; refusing to write" >&2
        return 2
    fi
    mv "$tmp" "$hd" || { rm -f "$fixfile" "$tmp"; echo "${GATE}: ENV — could not replace ${hd}" >&2; return 2; }
    rm -f "$fixfile"
    echo "${GATE}: --fix — rewrote ${n} ref(s) to the live gitlinks. This run still exits with the code"
    echo "${GATE}: --fix — for the state it FOUND; re-run without --fix for the post-repair verdict."
    echo "${GATE}: --fix — review the surrounding comments: a comment that restates a sha is now stale."
    return 0
}

# ─────────────────────────────────────────────────────────────────────────────
# Paired §1.1 mutation proof.
#
# ── WHY THE CONTROL IS SYNTHETIC (a real defect, measured — not a refactor) ──
# Until 2026-09-01 this proof did two things that made it INOPERATIVE the moment
# the tree was anything other than green:
#
#   1. the PRE-FLIGHT live run GATED the battery — it `return 1`-ed on rc 1 and
#      on rc 2 — so a single real pin drift meant ZERO mutations ever executed
#      and the proof exited 1 having demonstrated nothing;
#   2. the CONTROL specimen was built from the REAL manifest and the REAL index
#      gitlinks, so it was green only while the real manifest was ALREADY in
#      sync — which is precisely the condition this gate exists to detect the
#      absence of. A drifted manifest reddened the control, and a red control
#      returned before the first mutation.
#
# Measured, not inferred: on 2026-09-01 this file was copied into a directory
# that is not a git work tree and `--prove-failure` was run there. It exited 1
# with 0 of 8 mutations executed. A proof that cannot run is worse than no
# proof, because the line it prints still reads as coverage.
#
# The shape below is the one `scripts/verify-check-registry.sh --prove-failure`
# already uses, copied deliberately rather than reinvented:
#
#   * the CONTROL is SYNTHETIC and green BY CONSTRUCTION. Its manifest and its
#     gitlinks are generated together from the same constants, so no state of
#     this repository — drifted refs, an uninitialised submodule, a missing
#     manifest — can redden it. Nothing is copied from the real tree.
#   * the LIVE run still happens, FIRST, with the REAL entry point against the
#     REAL tree. A proof that only ever touches a sandbox while the real gate
#     cannot start is the other half of the same defect, and this repository has
#     shipped that half too. It is REPORTED, never gating: rc 0, 1 and 2 are all
#     printed and none of them can disable the battery. Only an INSTRUMENT fault
#     — a crash marker on stderr, or an exit code outside the documented 0/1/2
#     contract — is counted as a proof failure, because that genuinely voids the
#     instrument rather than merely describing the tree.
#
# The synthetic manifest deliberately exercises every parser branch the real one
# does: `layout: flat` and `layout: grouped`, a quoted 40-hex ref, an unquoted
# ref with a trailing comment, an ABBREVIATED prefix pin, and a trailing
# top-level key that must terminate the deps[] block.
#
# No submodule is checked out in the specimen, so the uninitialised-submodule
# path (N6) is exercised as a first-class case; N9 initialises one on purpose to
# reach the OTHER rc-2 branch, an unresolvable ref in a real checkout.
#
# Every mutation writes ONLY inside a `mktemp -d`. Nothing under the real
# repository is read for content or written to, so no restore is required.
# ─────────────────────────────────────────────────────────────────────────────
sg() {  # sandboxed git: no host identity, no signing, no hooks
    git -c user.name=pin-proof -c user.email=pin-proof@invalid \
        -c commit.gpgsign=false "$@"
}

# Deterministic, mutually distinct synthetic object names. They are NOT commits
# in any repository and never need to be: a gitlink index entry records a raw
# object name, which is the whole point — the specimen can pin anything.
SYN_SHA_ALPHA="1111111111111111111111111111111111111111"
SYN_SHA_BETA="2222222222222222222222222222222222222222"
SYN_SHA_GAMMA="33333333cccccccccccccccccccccccccccccccc"

build_synthetic_specimen() {
    local dest="$1"
    mkdir -p "$dest" || return 1
    sg -C "$dest" init -q >/dev/null 2>&1 || return 1

    # The manifest and the gitlinks below are written from the SAME three
    # constants, so "every recorded ref equals its gitlink" holds by
    # construction. This is the property that makes the control immune to the
    # state of the real tree.
    cat > "${dest}/${MANIFEST_NAME}" <<EOF
schema_version: 1

deps:
  - name: alpha
    ssh_url: git@github.com:synthetic-org/alpha.git
    ref: "${SYN_SHA_ALPHA}"
    why: "synthetic dep — quoted full 40-hex pin, flat layout"
    layout: flat

  - name: beta
    ssh_url: git@github.com:synthetic-org/beta.git
    ref: ${SYN_SHA_BETA}   # synthetic dep — unquoted pin with a trailing comment
    why: "synthetic dep — grouped layout, so its path is submodules/beta"
    layout: grouped

  - name: gamma
    ssh_url: git@github.com:synthetic-org/gamma.git
    ref: "${SYN_SHA_GAMMA:0:7}"
    why: "synthetic dep — ABBREVIATED prefix pin, the form the constitution's own manifest uses"
    layout: flat

language_specific_subtree: false
EOF
    sg -C "$dest" add -f "${MANIFEST_NAME}" >/dev/null 2>&1 || return 1

    printf '[submodule "alpha"]\n\tpath = alpha\n\turl = git@github.com:synthetic-org/alpha.git\n' \
        > "${dest}/.gitmodules" || return 1
    printf '[submodule "submodules/beta"]\n\tpath = submodules/beta\n\turl = git@github.com:synthetic-org/beta.git\n' \
        >> "${dest}/.gitmodules" || return 1
    printf '[submodule "gamma"]\n\tpath = gamma\n\turl = git@github.com:synthetic-org/gamma.git\n' \
        >> "${dest}/.gitmodules" || return 1
    sg -C "$dest" add -f .gitmodules >/dev/null 2>&1 || return 1

    sg -C "$dest" update-index --add --cacheinfo "160000,${SYN_SHA_ALPHA},alpha"          >/dev/null 2>&1 || return 1
    sg -C "$dest" update-index --add --cacheinfo "160000,${SYN_SHA_BETA},submodules/beta" >/dev/null 2>&1 || return 1
    sg -C "$dest" update-index --add --cacheinfo "160000,${SYN_SHA_GAMMA},gamma"          >/dev/null 2>&1 || return 1

    sg -C "$dest" commit -q --no-verify -m "synthetic pin-proof specimen" >/dev/null 2>&1 || return 1
    return 0
}

prove_failure() {
    local sandbox pristine rc mut_fails=0 live_out live_rc

    echo "${GATE} §1.1 PAIRED MUTATION PROOF"
    echo "----------------------------------------------------------------------"

    # ── PRE-FLIGHT: the REAL entry point, on the REAL tree — REPORTED ─────────
    # It runs FIRST, because a proof that only ever exercises sandboxes can go
    # green over a gate that cannot start. It GATES NOTHING, because a proof
    # whose battery a red tree can switch off demonstrates nothing at all. Both
    # halves of that sentence are defects this file has actually shipped; see
    # the block above build_synthetic_specimen for the measurements.
    live_out="$(bash "$0" --root "$REPO_ROOT" 2>&1)"; live_rc=$?
    if printf '%s' "$live_out" | grep -qE 'INTERNAL-FAULT|unbound variable|command not found|syntax error near'; then
        echo "❌ PRE-FLIGHT live-run   — INSTRUMENT FAULT: the real entry point aborted on the real tree"
        echo "                        -> a gate that cannot start proves nothing. Counted as a proof FAILURE."
        printf '%s\n' "$live_out" | sed 's/^/        /'
        mut_fails=$((mut_fails+1))
    else
        case "$live_rc" in
            0) echo "✅ PRE-FLIGHT live-run   — real entry point, real tree, rc=0 (gate runs; every pin in sync)" ;;
            1) echo "ℹ PRE-FLIGHT live-run   — the real entry point RAN against the real tree and returned rc=1,"
               echo "                          a REAL pin drift. REPORTED, NOT GATING: the battery below uses a"
               echo "                          synthetic control precisely so a red tree cannot disable the proof."
               echo "                          Remedy for the tree (not for this proof): scripts/verify-manifest-pins.sh --fix"
               printf '%s\n' "$live_out" | sed 's/^/        /' ;;
            2) echo "ℹ PRE-FLIGHT live-run   — the real entry point RAN against the real tree and returned rc=2,"
               echo "                          COULD NOT DETERMINE. REPORTED, NOT GATING; the battery still runs."
               printf '%s\n' "$live_out" | sed 's/^/        /' ;;
            *) echo "❌ PRE-FLIGHT live-run   — INSTRUMENT FAULT: undocumented exit code ${live_rc}; the contract is 0/1/2"
               printf '%s\n' "$live_out" | sed 's/^/        /'
               mut_fails=$((mut_fails+1)) ;;
        esac
    fi

    if ! command -v git >/dev/null 2>&1; then
        echo "${GATE}: ENV — git is not on PATH; the specimen cannot be built" >&2
        exit 2
    fi

    sandbox="$(mktemp -d)" || { echo "${GATE}: ENV — mktemp -d failed" >&2; exit 2; }
    _sandbox_to_clean="$sandbox"
    export HOME="$sandbox" GIT_CONFIG_NOSYSTEM=1

    echo "  sandbox: ${sandbox}"
    echo "  Every mutation is applied to a THROWAWAY git repository whose manifest and"
    echo "  gitlinks are GENERATED TOGETHER, so the control is green by construction and no"
    echo "  state of this repository can disable the battery. Neither this repository nor any"
    echo "  submodule working tree is read for content or written to."
    echo "----------------------------------------------------------------------"

    pristine="${sandbox}/pristine"
    if ! build_synthetic_specimen "$pristine"; then
        echo "${GATE}: ENV — could not build the synthetic git specimen" >&2
        exit 2
    fi

    bash "$0" --root "$pristine" --quiet >/dev/null 2>&1; rc=$?
    if [ "$rc" -eq 0 ]; then
        echo "✅ CONTROL synthetic-green — unmutated synthetic specimen passes (rc=0), by construction"
    else
        echo "❌ CONTROL synthetic-green — unmutated synthetic specimen returned rc=${rc}."
        echo "                        -> ABORTING: ZERO mutations were run, so NOTHING below was proved."
        echo "                           This is an instrument fault in the proof harness itself, not a"
        echo "                           statement about this repository's manifest."
        bash "$0" --root "$pristine" 2>&1 | sed 's/^/        /'
        return 1
    fi

    # mutate_and_assert <label> <description> <want-rc> <must-name-or-empty> <fn>
    mutate_and_assert() {
        local name="$1" desc="$2" want="$3" needle="$4"; shift 4
        local slug dir out mrc
        slug="$(printf '%s' "$name" | tr -cd 'A-Za-z0-9')"
        dir="${sandbox}/mut_${slug}"
        rm -rf "$dir"
        if ! cp -r "$pristine" "$dir"; then
            echo "❌ ${name} — could not copy the specimen"; mut_fails=$((mut_fails+1)); return
        fi
        if ! "$@" "$dir"; then
            echo "❌ ${name} — could not apply the mutation (${desc})"; mut_fails=$((mut_fails+1)); rm -rf "$dir"; return
        fi
        out="$(bash "$0" --root "$dir" 2>&1)"; mrc=$?
        if [ "$mrc" -ne "$want" ]; then
            echo "❌ ${name} — ${desc}"
            echo "                        -> rc=${mrc}, wanted ${want}. THIS GATE IS A SHAM (§1.1)."
            printf '%s\n' "$out" | sed 's/^/        /'
            mut_fails=$((mut_fails+1)); rm -rf "$dir"; return
        fi
        if [ -n "$needle" ] && ! printf '%s' "$out" | grep -qF "$needle"; then
            echo "❌ ${name} — ${desc}"
            echo "                        -> rc=${mrc} as wanted, but the message never NAMES '${needle}'."
            echo "                           An unactionable failure message is a §11.4.6 defect of its own."
            printf '%s\n' "$out" | sed 's/^/        /'
            mut_fails=$((mut_fails+1)); rm -rf "$dir"; return
        fi
        echo "✅ ${name} — ${desc}"
        echo "                        -> rc=${mrc} (wanted ${want})${needle:+  [names '${needle}']}"
        rm -rf "$dir"
    }

    # N1 — the manifest records a ref nothing points at (the drift this gate exists for).
    n1() { sed -i '/^[[:space:]]*ref[[:space:]]*:/ s/[0-9a-fA-F]\{40\}/deadbeefdeadbeefdeadbeefdeadbeefdeadbeef/' "$1/${MANIFEST_NAME}"; }
    # N2 — the OTHER direction, and the realistic one: the gitlink is bumped in a
    #      COMMIT and the manifest is left behind.
    n2() {
        local d="$1" p
        p="$(manifest_entries "${d}/${MANIFEST_NAME}" | awk -F'\t' 'NR==1{print $2}')"
        [ -n "$p" ] || return 1
        sg -C "$d" update-index --add --cacheinfo "160000,cafebabecafebabecafebabecafebabecafebabe,${p}" >/dev/null 2>&1 || return 1
        sg -C "$d" commit -q --no-verify -m "bump a gitlink and forget the manifest" >/dev/null 2>&1
    }
    # N8 — the same bump STAGED but NOT committed. This is the whole point of
    #      comparing against the index: the gate must go red at `git add`, one
    #      step before the untrue commit exists. Under a HEAD-based comparison
    #      this mutation would pass, which is why that design was rejected.
    n8() {
        local d="$1" p
        p="$(manifest_entries "${d}/${MANIFEST_NAME}" | awk -F'\t' 'NR==1{print $2}')"
        [ -n "$p" ] || return 1
        sg -C "$d" update-index --add --cacheinfo "160000,facefeedfacefeedfacefeedfacefeedfacefeed,${p}" >/dev/null 2>&1
    }
    # N3 — the manifest is gone. MUST be 2: absent evidence is not clean evidence.
    n3() { rm -f "$1/${MANIFEST_NAME}"; }
    # N4 — the manifest is present but parses to zero deps. MUST be 2, not 0:
    #      "nothing to check" and "everything checks out" are different states.
    n4() { printf 'schema_version: 1\n' > "$1/${MANIFEST_NAME}"; }
    # N5 — the target is not a git work tree at all. MUST be 2.
    n5() { rm -rf "$1/.git"; }
    # N6 — a SYMBOLIC ref whose submodule is NOT INITIALISED. MUST be 2 —
    #      never 0 and never 1. This is the explicit uninitialised-submodule
    #      contract; the specimen checks out no submodule, so `v9.9.9` is
    #      unresolvable for a reason that is environmental, not a violation.
    n6() {
        awk 'BEGIN{d=0}
             /^[[:space:]]*ref[[:space:]]*:/ && d==0 { sub(/ref[[:space:]]*:.*/, "ref: v9.9.9"); d=1 }
             {print}' "$1/${MANIFEST_NAME}" > "$1/.n6.tmp" || return 1
        mv "$1/.n6.tmp" "$1/${MANIFEST_NAME}"
    }
    # N7 — the remedy the failure message names actually works, end to end.
    n7() {
        local d="$1"
        n1 "$d" || return 1
        bash "$0" --root "$d" --fix --quiet >/dev/null 2>&1
        return 0
    }
    # N9 — the OTHER rc=2 branch, which N6 cannot reach: the submodule IS a real
    #      checkout, and the symbolic ref simply does not resolve in it (an
    #      unfetched tag and a typo are indistinguishable from here). Without
    #      this pairing, "does not resolve" was an unproven code path.
    n9() {
        local d="$1"
        n6 "$d" || return 1
        sg -C "$d" init -q "${d}/alpha" >/dev/null 2>&1 || return 1
        return 0
    }
    # N10 — the ABBREVIATED-prefix comparison. N1 rewrites only 40-hex refs, so
    #       the 7-character pin is invisible to it and the prefix branch was
    #       never demonstrated to fail. A prefix that does NOT match must be
    #       rc=1, exactly like a full sha that does not match.
    n10() { sed -i 's/^    ref: "3333333"$/    ref: "9999999"/' "$1/${MANIFEST_NAME}"; }

    mutate_and_assert "N1 manifest-ref-drifted  " "a recorded ref is rewritten to a commit nothing points at        " 1 "deadbeef" n1
    mutate_and_assert "N2 gitlink-bumped        " "the committed gitlink moves; the manifest is left behind         " 1 "cafebabe" n2
    mutate_and_assert "N3 manifest-absent       " "helix-deps.yaml deleted — absent evidence is NOT clean evidence  " 2 "missing or unreadable" n3
    mutate_and_assert "N4 manifest-zero-deps    " "helix-deps.yaml parses to zero deps[] — certifies nothing        " 2 "ZERO deps" n4
    mutate_and_assert "N5 not-a-git-work-tree   " ".git removed — the committed gitlinks cannot be read             " 2 "not the top level" n5
    mutate_and_assert "N6 uninit-submodule-tag  " "a symbolic ref whose submodule is NOT initialised                " 2 "NOT INITIALISED" n6
    mutate_and_assert "N7 --fix remediates      " "N1's drift, then --fix, then re-verify — the named remedy works  " 0 "" n7
    mutate_and_assert "N8 gitlink-bump-STAGED   " "the bump is staged and NOT committed — caught before the commit  " 1 "facefeed" n8
    mutate_and_assert "N9 tag-unresolvable      " "the submodule IS initialised but the symbolic ref does not resolve" 2 "does not resolve" n9
    mutate_and_assert "N10 abbrev-prefix-drifted" "the ABBREVIATED prefix pin no longer prefixes the live gitlink   " 1 "9999999" n10

    # ── RESTORED CONTROL ─────────────────────────────────────────────────────
    # Every mutation ran on its own throwaway copy, so the pristine specimen must
    # still be green. Showing it again is what distinguishes "the mutations were
    # caught" from "the specimen decayed part-way through the battery".
    bash "$0" --root "$pristine" --quiet >/dev/null 2>&1; rc=$?
    if [ "$rc" -eq 0 ]; then
        echo "✅ CONTROL restored        — the unmutated specimen is still green after the battery (rc=0)"
    else
        echo "❌ CONTROL restored        — the specimen no longer passes (rc=${rc}); a mutation leaked out of its copy"
        mut_fails=$((mut_fails+1))
    fi

    echo "----------------------------------------------------------------------"
    if [ "$mut_fails" -eq 0 ]; then
        echo "✅ ${GATE} §1.1 MUTATION PROOF: PASS — the REAL entry point ran against the REAL tree"
        echo "   (reported, never gating), a SYNTHETIC control that is green by construction passed,"
        echo "   10 mutations each FLIPPED the verdict with the right three-valued code and NAMED the"
        echo "   offending thing: 4 real drifts as rc=1 (manifest-side, committed gitlink, staged-but-"
        echo "   uncommitted gitlink, abbreviated prefix), 5 could-not-determine states as rc=2 rather"
        echo "   than as a pass or an accusation, --fix remediated, and the control is still green."
        return 0
    fi
    echo "❌ ${GATE} §1.1 MUTATION PROOF: FAIL — ${mut_fails} case(s) did not produce the required result"
    return 1
}

if [ -n "$prove" ]; then
    prove_failure; _prc=$?
    _verdict_emitted=1
    exit "$_prc"
fi

check_pins; _rc=$?
if [ -n "$fix" ]; then
    echo "----------------------------------------------------------------------"
    apply_fix; _frc=$?
    [ "$_frc" -ne 0 ] && exit "$_frc"
    exit "$_rc"
fi
exit "$_rc"
