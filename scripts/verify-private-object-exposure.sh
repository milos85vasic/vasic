#!/usr/bin/env bash
# verify-private-object-exposure.sh — make it IMPOSSIBLE to publish a private
# repository's content from this PUBLIC repository by accident.
#
# =============================================================================
# THE FAILURE MODE THIS EXISTS FOR
# =============================================================================
#
# On 2026-08-29 a §9.3 pre-destructive-operation backup of the PRIVATE
# `workshop_curriculum` submodule's entire `.git` directory — a 1,870,772,012-byte
# packfile among 96 files — was COMMITTED into this PUBLIC umbrella repository on
# a local branch. The branch was never pushed and was not an ancestor of `main`,
# so nothing escaped. But nothing prevented it either: a single
# `git push --all` or `git push --mirror` publishes every local ref, and
# `.git/hooks/` is untracked, so a fresh clone carries no protection at all.
#
# The near-miss is recorded at `docs/content-boundary-incident-2026-09-01.md`
# §8A.6, which states the correct conclusion and names the missing half:
#
#     "It is recorded here because a local-only hazard that nothing checks is
#      one accidental `git push --all` away from being a much larger incident."
#
# "that nothing checks" is what this file removes.
#
# THE BRANCH IS GONE — THE HAZARD IS NOT. The operator removed it on 2026-09-01
# (`docs/branch-removal-2026-09-01.txt`). This file was written to cover the
# whole CATEGORY rather than that one branch, and none of its detection reads a
# branch name, so the removal changed nothing about how it works. The habit that produced the
# instance — copy a submodule's `.git` into the umbrella before a destructive
# operation — is still the correct §9.3 habit, and it will produce another one.
# What changed is only which state the tree is in: as of 2026-09-01 the store is
# reachable from the REFLOG but from no ref, so it is unpushable and this gate
# reports it as a loud NOTE at rc=0 rather than a finding. Restore the branch
# and it is rc=1 again, which the paired proof asserts rather than promises.
#
# =============================================================================
# WHY THIS CANNOT BE DEFEATED BY A RENAME
# =============================================================================
#
# This detector NEVER reads a branch name, a directory name, a commit message,
# or a date. Not one of its evidence classes would change if the branch were
# renamed to `wip/notes` and the directory to `assets/vendor-data`.
#
# It keys on the INTERNAL LAYOUT AND BYTE MAGIC OF A GIT REPOSITORY, which a
# copied repository must preserve to remain a usable repository — the moment
# those are renamed the artefact stops being a backup and the hazard stops
# existing. Concretely:
#
#   E1  a blob whose FIRST FOUR BYTES ARE `PACK` followed by a 4-byte
#       big-endian pack version of 2 or 3, at a path shaped
#       `.../objects/pack/pack-<40hex>.pack`
#   E2  a blob whose first four bytes are `\377tOc` (the pack-index magic)
#       followed by version 2, at a path shaped `.../objects/pack/pack-<40hex>.idx`
#   E3  a zlib stream at a path shaped `.../objects/<2hex>/<38hex>` which, when
#       inflated, begins with a git loose-object header (`blob `/`tree `/
#       `commit `/`tag ` + decimal length + NUL)
#   E4  a `HEAD` blob whose CONTENT is `ref: refs/…` or a bare 40-hex sha
#   E5  a `config` blob whose CONTENT carries `[core]` and `repositoryformatversion`
#   E6  a `packed-refs` blob whose CONTENT begins with `# pack-refs with:`
#
# A directory is judged A FOREIGN GIT OBJECT STORE when at least TWO independent
# evidence classes hold AND at least one of them is an objects-layer proof
# (E1, E2 or E3). Both halves matter:
#
#   * The objects-layer requirement means a directory holding only a `config`
#     and a `HEAD` — a dotfiles repo, a test fixture — is NOT flagged.
#   * The two-class requirement means a text file parked at a path that merely
#     LOOKS like `objects/pack/pack-<40hex>.pack` is NOT flagged. `--prove-failure`
#     seeds exactly that decoy and requires the detector to ignore it, so "it
#     only matched the name" is a claim this file refutes on demand rather than
#     denies in prose.
#
# Everything found this way is FOREIGN by construction: git will not track its
# own `.git`, so an object store appearing in `git rev-list --objects` output is
# necessarily a copy of some OTHER repository, committed as content.
#
# Provenance, where it can be established, comes from E5: the `url =` lines of
# the captured `config` name the repository the store came from. That slug is
# matched against the private half of the fleet. No roster is hardcoded here.
#
# =============================================================================
# THE GENERAL CLASS, NOT JUST ONE BRANCH
# =============================================================================
#
#   A  HISTORY   Does any object reachable from ANY local ref — or sitting in
#                the index, which the project's `git add .` commit wrapper would
#                sweep into the next commit — belong to a foreign object store?
#                Scanned: everything under `refs/` plus `HEAD` plus the index,
#                because that is exactly what `--all` / `--mirror` publish.
#                The REFLOG is scanned too, and graded differently: a store
#                reachable only from the reflog cannot be pushed, so it is a
#                loud NOTE rather than a finding — but it is never silent,
#                because one checkout out of the reflog makes it a finding.
#                A pack's contents are read from its `.idx` via `git show-index`,
#                which needs no repository and no `.pack`, so a captured store
#                whose config aborts every ordinary git command can still be
#                counted. A census that cannot be taken prints as unknown.
#
#   B  FLEET     Is any submodule's working tree committed into this repository
#                as regular files instead of a gitlink? Is any submodule's
#                directory NOT a real repository checkout, so `git add .` would
#                sweep its files in? The fleet is DERIVED from `.gitmodules`
#                (paths + urls), corroborated against `helix-deps.yaml`, and
#                each repository's visibility is asked of the provider via `gh`.
#                Visibility decides SEVERITY; the structural facts stand without it.
#
#   C  WORKTREE  Is a foreign object store sitting in the working tree right
#                now, held off by nothing but a `.gitignore` line? That is this
#                repository's ACTUAL state, and a `.gitignore` rule is one edit
#                and one `git add -f` away from being no protection at all.
#
# =============================================================================
# THREE-VALUED EXIT, AND 2 IS NEVER A PASS
# =============================================================================
#
#   0  clean: no foreign object store anywhere, no submodule content committed
#      as files, every declared submodule path is a real repository checkout
#   1  A REAL FINDING, determined
#   2  COULD NOT DETERMINE: no root, root is not a git repository toplevel,
#      history could not be enumerated, `.gitmodules` present but unreadable,
#      a declared submodule path that cannot be classified, or a submodule whose
#      state needs grading while its provider visibility is unknown
#
# A CONFIRMED FAILURE OUTRANKS AN UNDETERMINED: if layer A finds a foreign
# object store the exit is 1 even when `gh` was unusable. A finding does not
# become less true because its provenance could not be labelled.
#
# WHEN AN UNKNOWN VISIBILITY IS *NOT* AN UNDETERMINED, stated so nobody reads it
# as leniency: a submodule that contributes ZERO objects to this repository's
# history and whose path is a real repository checkout has no content here to
# expose. Whether that repository is public or private cannot change that
# structural fact, so no provider answer is required to grade it. Visibility is
# demanded — and its absence escalated — exactly where it would change the
# verdict, and nowhere else.
#
# THE UNINITIALISED-SUBMODULE TRAP, stated because a gate in this tree had it.
# `git -C <dir> rev-parse --git-dir` SUCCEEDS inside an EMPTY directory nested in
# a repository, because it WALKS UP and finds the parent's `.git`. A check
# written that way reads an uninitialised submodule as healthy. Every repository
# test here therefore requires the directory to BE the resolved toplevel —
# `rev-parse --show-toplevel`, made physical with `pwd -P` on both sides,
# compared for equality. Walking up is a mismatch, and a mismatch is never a pass.
#
# THIS GUARD IS READ-ONLY. It never writes to, deletes, renames, force-updates
# or pushes any ref. Removing a backup is an OPERATOR decision under §9.3, not
# a gate's.
#
# Usage:
#   bash scripts/verify-private-object-exposure.sh
#   bash scripts/verify-private-object-exposure.sh --root <dir>
#   bash scripts/verify-private-object-exposure.sh --prove-failure   # §1.1 proof
#   bash scripts/verify-private-object-exposure.sh --help

set -uo pipefail

SELF="${BASH_SOURCE[0]}"
SELF_DIR="$(cd -- "$(dirname -- "$SELF")" && pwd)"
ROOT="$(cd -- "$SELF_DIR/.." && pwd)"
PROVE=0

while [ "$#" -gt 0 ]; do
    case "$1" in
        --root)          ROOT="${2:-}"; shift 2 ;;
        --prove-failure) PROVE=1; shift ;;
        -h|--help)       sed -n '1,140p' "$SELF"; exit 0 ;;
        *) printf 'UNDETERMINED: unknown argument %s\n' "$1" >&2; exit 2 ;;
    esac
done

RED=$'\033[31m'; GRN=$'\033[32m'; YEL=$'\033[33m'; NC=$'\033[0m'
ok()   { printf '  %s%-11s%s %s\n' "$GRN" "$1" "$NC" "$2"; }
warn() { printf '  %s%-11s%s %s\n' "$YEL" "$1" "$NC" "$2"; }
note() { printf '  %-11s %s\n' "$1" "$2"; }

FINDINGS=0; UNDET=0
FINDING_LINES=""; UNDET_LINES=""
finding() { FINDINGS=$((FINDINGS+1)); FINDING_LINES="${FINDING_LINES}  $1"$'\n'
            printf '  %s%-11s%s %s\n' "$RED" "FINDING" "$NC" "$1"; }
undet()   { UNDET=$((UNDET+1));       UNDET_LINES="${UNDET_LINES}  $1"$'\n'
            printf '  %s%-11s%s %s\n' "$YEL" "UNDET" "$NC" "$1"; }

# ---------------------------------------------------------------------------
# is_repo_toplevel <dir> — TRUE only when <dir> IS the toplevel of a git working
# tree. Deliberately NOT `rev-parse --git-dir`, which walks up and reports
# success from inside an empty uninitialised submodule directory. Both sides are
# made physical so a symlinked path cannot produce a spurious mismatch.
# ---------------------------------------------------------------------------
is_repo_toplevel() {
    local d="$1" phys top
    [ -d "$d" ] || return 1
    phys="$(cd -- "$d" 2>/dev/null && pwd -P)" || return 1
    top="$(git -C "$d" rev-parse --show-toplevel 2>/dev/null)" || return 1
    [ -n "$top" ] || return 1
    top="$(cd -- "$top" 2>/dev/null && pwd -P)" || return 1
    [ "$top" = "$phys" ]
}

# ---------------------------------------------------------------------------
# CONTENT PROBES — these read BYTES, never a name. `head -c` closes the pipe
# immediately, so probing a 1.78 GB blob costs milliseconds: git takes SIGPIPE
# and the object never streams.
# ---------------------------------------------------------------------------
blob_magic_hex() { git -C "$ROOT" cat-file blob "$1" 2>/dev/null | head -c "$2" 2>/dev/null \
                     | od -An -tx1 -v 2>/dev/null | tr -d ' \n'; }
file_magic_hex() { head -c "$2" -- "$1" 2>/dev/null | od -An -tx1 -v 2>/dev/null | tr -d ' \n'; }
blob_text_head() { git -C "$ROOT" cat-file blob "$1" 2>/dev/null | head -c "$2" 2>/dev/null; }
blob_size()      { git -C "$ROOT" cat-file -s "$1" 2>/dev/null || printf '0'; }

is_pack_magic() { case "$1" in 5041434b00000002*|5041434b00000003*) return 0 ;; esac; return 1; }
is_idx_magic()  { case "$1" in ff744f6300000002*) return 0 ;; esac; return 1; }
is_zlib_magic() { case "$1" in 7801*|785e*|789c*|78da*) return 0 ;; esac; return 1; }

# E3's decisive half. python3 may be absent; its absence NEVER upgrades a guess
# to a proof, it just leaves E3 resting on the zlib magic — which is why the
# verdict rule demands a second, independent evidence class regardless.
HAVE_PY=0
command -v python3 >/dev/null 2>&1 && HAVE_PY=1
#
# NOTE ON PIPELINES, because this cost a silent wrong answer once already.
# `set -o pipefail` is in force. `git cat-file blob | head -c N` makes git take
# SIGPIPE, and `cmd | grep -q` makes grep exit before the producer finishes —
# in BOTH cases the PIPELINE's status is non-zero even though the answer is
# correct. Any pipeline whose exit status is CONSUMED must therefore be
# materialised through a file first. Pipelines inside `$(…)` are safe: only
# their stdout is used.
is_loose_object() {
    [ "$HAVE_PY" -eq 1 ] || return 1
    local tmp rc
    tmp="$(mktemp 2>/dev/null)" || return 1
    git -C "$ROOT" cat-file blob "$1" 2>/dev/null | head -c 512 > "$tmp" 2>/dev/null
    python3 -c '
import sys, zlib
raw = sys.stdin.buffer.read()
try:
    out = zlib.decompressobj().decompress(raw, 64)
except zlib.error:
    sys.exit(1)
for kind in (b"blob ", b"tree ", b"commit ", b"tag "):
    if out.startswith(kind):
        n = out[len(kind):].split(b"\x00", 1)[0]
        sys.exit(0 if n and n.isdigit() else 1)
sys.exit(1)
' < "$tmp" >/dev/null 2>&1
    rc=$?
    rm -f "$tmp"
    return "$rc"
}

# Any git remote URL -> owner/repo slug. Only the two URL shapes git itself
# accepts are stripped; no provider is hardcoded.
url_to_slug() {
    printf '%s' "$1" | sed -E 's#^[a-zA-Z0-9._-]+@[^:/]+[:/]#/#; s#^[a-zA-Z]+://[^/]+/#/#; s#^/##; s#\.git$##'
}

# =============================================================================
# --prove-failure — the §1.1 paired mutation for THIS guard.
#
# It builds a THROWAWAY repository under mktemp and never touches the real one.
# Required, in order:
#
#   GREEN  an ordinary repository                                       -> rc 0
#   RED    a REAL foreign object store committed under an INNOCUOUS path
#          on an INNOCUOUS branch — a DETERMINED finding                -> rc 1
#   DECOY  a same-SHAPED path whose bytes are plain text must NOT be
#          flagged. This is what separates content detection from a name
#          match, and it is ASSERTED, not asserted-about.
#   GREEN  the store removed and the branch deleted                     -> rc 0
#   UNDET  a root that does not exist                                   -> rc 2
#   UNDET  a directory that is not a repository toplevel                -> rc 2
#   UNDET  an EMPTY submodule directory nested inside a repository — the
#          exact shape `rev-parse --git-dir` reports as healthy         -> rc 2
#
# plus: the guard wrote nothing (the sandbox worktree is clean after a scan and
# the subject file's sha256 is unchanged).
# =============================================================================
if [ "$PROVE" -eq 1 ]; then
    printf '== prove-failure: this guard must be SEEN reddening on a foreign object store ==\n\n'
    LAB="$(mktemp -d 2>/dev/null)" || { printf 'UNDETERMINED: cannot create a lab directory\n' >&2; exit 2; }
    trap 'rm -rf "$LAB"' EXIT
    mkdir -p "$LAB/home" "$LAB/ghconf"
    # Isolated identity and an isolated (empty) gh config, so the lab cannot
    # reach the provider and cannot inherit the operator's credentials.
    LABENV=(env HOME="$LAB/home" XDG_CONFIG_HOME="$LAB/ghconf" GH_CONFIG_DIR="$LAB/ghconf"
                GH_TOKEN= GITHUB_TOKEN= GIT_CONFIG_NOSYSTEM=1 GIT_TERMINAL_PROMPT=0
                GIT_AUTHOR_NAME=lab GIT_AUTHOR_EMAIL=lab@lab
                GIT_COMMITTER_NAME=lab GIT_COMMITTER_EMAIL=lab@lab)

    SUB="$LAB/subject"
    mkdir -p "$SUB"
    "${LABENV[@]}" git -C "$SUB" init -q -b main >/dev/null 2>&1
    printf 'hello\n' > "$SUB/README.md"
    "${LABENV[@]}" git -C "$SUB" add -A >/dev/null 2>&1
    "${LABENV[@]}" git -C "$SUB" commit -qm base >/dev/null 2>&1
    SUBJECT_SUM="$(sha256sum "$SUB/README.md" 2>/dev/null | awk '{print $1}')"

    printf -- '--- GREEN: an ordinary repository ---\n'
    "${LABENV[@]}" bash "$SELF" --root "$SUB" >"$LAB/g1.out" 2>&1; G1=$?
    sed 's/^/    | /' "$LAB/g1.out" | tail -8
    printf '    rc=%s (expected 0)\n\n' "$G1"

    # ---- a REAL foreign repository, with a REAL packfile and loose objects ---
    FOR="$LAB/foreign"
    mkdir -p "$FOR"
    "${LABENV[@]}" git -C "$FOR" init -q -b main >/dev/null 2>&1
    "${LABENV[@]}" git -C "$FOR" remote add origin git@github.com:lab/private-thing.git >/dev/null 2>&1
    printf 'a private transcript\n' > "$FOR/secret.txt"
    "${LABENV[@]}" git -C "$FOR" add -A >/dev/null 2>&1
    "${LABENV[@]}" git -C "$FOR" commit -qm one >/dev/null 2>&1
    "${LABENV[@]}" git -C "$FOR" repack -adq >/dev/null 2>&1      # -> objects/pack/pack-*.pack
    printf 'more\n' >> "$FOR/secret.txt"
    "${LABENV[@]}" git -C "$FOR" add -A >/dev/null 2>&1
    "${LABENV[@]}" git -C "$FOR" commit -qm two >/dev/null 2>&1   # -> loose objects
    "${LABENV[@]}" git -C "$FOR" pack-refs --all >/dev/null 2>&1  # -> packed-refs

    MUT_DIR='assets/vendor-data'     # no "backup", no "workshop", no ".git"
    MUT_BRANCH='wip/notes'
    for tok in backup workshop git-backup .git objects-copy mirror; do
        case "$MUT_DIR/$MUT_BRANCH" in
            *"$tok"*) printf 'UNDETERMINED: the mutant name contains "%s"; this proof could not\n' "$tok" >&2
                      printf 'then distinguish content detection from a name match\n' >&2; exit 2 ;;
        esac
    done
    "${LABENV[@]}" git -C "$SUB" checkout -q -b "$MUT_BRANCH" >/dev/null 2>&1
    mkdir -p "$SUB/$MUT_DIR"
    cp -a "$FOR/.git/." "$SUB/$MUT_DIR/" 2>/dev/null

    # ---- the DECOY: identical path SHAPE, content that is not git at all ----
    DECOY='docs/samples'
    mkdir -p "$SUB/$DECOY/objects/pack" "$SUB/$DECOY/objects/ab"
    printf 'plain text at a packfile-shaped path\n' \
        > "$SUB/$DECOY/objects/pack/pack-0123456789abcdef0123456789abcdef01234567.pack"
    printf 'not an index either\n' \
        > "$SUB/$DECOY/objects/pack/pack-0123456789abcdef0123456789abcdef01234567.idx"
    printf 'not a loose object\n' \
        > "$SUB/$DECOY/objects/ab/cdef0123456789abcdef0123456789abcdef01"
    printf 'a file named HEAD that says nothing git-like\n' > "$SUB/$DECOY/HEAD"
    printf 'a config, but not a git one\n'                  > "$SUB/$DECOY/config"
    printf '# pack-refs is what a real one starts with; this does not\n' > "$SUB/$DECOY/packed-refs"

    "${LABENV[@]}" git -C "$SUB" add -A -f >/dev/null 2>&1
    "${LABENV[@]}" git -C "$SUB" commit -qm 'add vendor data and samples' >/dev/null 2>&1

    MUT_PACK_SHA="$("${LABENV[@]}" git -C "$SUB" rev-list --objects HEAD 2>/dev/null \
        | grep -E "^[0-9a-f]{40} $MUT_DIR/objects/pack/pack-[0-9a-f]{40}\.pack$" | head -1 | cut -d' ' -f1)"
    [ -n "$MUT_PACK_SHA" ] || { printf 'UNDETERMINED: the lab produced no committed packfile; the RED step\n' >&2
                                printf 'would measure an absent mutant rather than a detected one\n' >&2; exit 2; }
    MUT_MAGIC="$("${LABENV[@]}" git -C "$SUB" cat-file blob "$MUT_PACK_SHA" 2>/dev/null \
        | head -c 8 2>/dev/null | od -An -tx1 -v 2>/dev/null | tr -d ' \n')"
    case "$MUT_MAGIC" in
        5041434b0000000[23])
            printf -- '--- RED: the seeded store is a GENUINE packfile (magic %s), committed at\n' "$MUT_MAGIC"
            printf '    "%s" on branch "%s" — neither name hints at git ---\n' "$MUT_DIR" "$MUT_BRANCH" ;;
        *) printf 'UNDETERMINED: the seeded blob is not a packfile (magic %s)\n' "$MUT_MAGIC" >&2; exit 2 ;;
    esac

    "${LABENV[@]}" bash "$SELF" --root "$SUB" >"$LAB/r.out" 2>&1; R=$?
    sed 's/^/    | /' "$LAB/r.out" | tail -22
    printf '    rc=%s (expected 1 — a DETERMINED finding, never a 2)\n\n' "$R"

    DECOY_FLAGGED=0
    grep -qE "(FINDING|UNDET).*$DECOY" "$LAB/r.out" 2>/dev/null && DECOY_FLAGGED=1
    if [ "$DECOY_FLAGGED" -eq 0 ]; then
        printf -- '--- DECOY: "%s" carries a packfile-shaped path, an idx-shaped path, a\n' "$DECOY"
        printf '    loose-object-shaped path, a HEAD, a config and a packed-refs — every one\n'
        printf '    with non-git bytes. It was NOT flagged: the detector read content ---\n\n'
    else
        printf -- '--- DECOY: "%s" WAS flagged. The detector is matching path shape alone ---\n\n' "$DECOY"
    fi

    # ---- the state DELETING THE BRANCH leaves behind, asserted separately ---
    # `git branch -D` unhooks the objects from every ref but leaves them in the
    # object database, reachable from the reflog. `git push` cannot publish them
    # and the gate must NOT call that an exposure — but it must also not go
    # silent, because a reflog checkout puts them straight back on a ref. This
    # is the exact state this repository was in on 2026-09-01 after the real
    # branch was removed, so it is asserted rather than assumed.
    printf -- '--- REFLOG-ONLY: delete the branch, keep the reflog ---\n'
    "${LABENV[@]}" git -C "$SUB" checkout -q main >/dev/null 2>&1
    "${LABENV[@]}" git -C "$SUB" branch -q -D "$MUT_BRANCH" >/dev/null 2>&1
    rm -rf "$SUB/$MUT_DIR" "$SUB/$DECOY" "$SUB/assets" "$SUB/docs"
    "${LABENV[@]}" bash "$SELF" --root "$SUB" >"$LAB/rf.out" 2>&1; RF=$?
    RF_NAMED=0
    grep -q 'REFLOG-ONLY' "$LAB/rf.out" 2>/dev/null && RF_NAMED=1
    RF_SILENT=0
    grep -q "$MUT_DIR" "$LAB/rf.out" 2>/dev/null || RF_SILENT=1
    printf '    rc=%s (expected 0 — unpushable is not an exposure)\n' "$RF"
    printf '    still REPORTED as reflog-only: %s   went silent about it: %s\n\n' \
        "$( [ "$RF_NAMED" -eq 1 ] && echo yes || echo NO )" \
        "$( [ "$RF_SILENT" -eq 1 ] && echo YES || echo no )"

    printf -- '--- restore: expire the reflog and prune, in the SANDBOX only ---\n'
    "${LABENV[@]}" git -C "$SUB" reflog expire --expire=now --all >/dev/null 2>&1
    "${LABENV[@]}" git -C "$SUB" gc --prune=now -q >/dev/null 2>&1
    AFTER="$(sha256sum "$SUB/README.md" 2>/dev/null | awk '{print $1}')"
    "${LABENV[@]}" bash "$SELF" --root "$SUB" >"$LAB/g2.out" 2>&1; G2=$?
    DIRT="$("${LABENV[@]}" git -C "$SUB" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
    printf '    rc=%s (expected 0)  subject sha256 %s  worktree dirt after scan: %s file(s)\n\n' \
        "$G2" "$( [ "$AFTER" = "$SUBJECT_SUM" ] && echo 'MATCHES the original' || echo 'DIFFERS — restore failed' )" "$DIRT"

    printf -- '--- UNDET: a root that does not exist ---\n'
    bash "$SELF" --root /nonexistent >"$LAB/u1.out" 2>&1; U1=$?
    printf '    rc=%s (expected 2)\n\n' "$U1"

    printf -- '--- UNDET: a directory that is not a git repository at all ---\n'
    mkdir -p "$LAB/plain"
    bash "$SELF" --root "$LAB/plain" >"$LAB/u2.out" 2>&1; U2=$?
    printf '    rc=%s (expected 2)\n\n' "$U2"

    printf -- '--- UNDET: an EMPTY submodule directory nested INSIDE a repository.\n'
    printf '    `git -C <that dir> rev-parse --git-dir` SUCCEEDS, because it walks UP to\n'
    printf '    the parent .git. A guard written that way calls this healthy ---\n'
    printf '[submodule "lib"]\n\tpath = lib\n\turl = git@github.com:lab/lib.git\n' > "$SUB/.gitmodules"
    mkdir -p "$SUB/lib"
    WALKUP="$("${LABENV[@]}" git -C "$SUB/lib" rev-parse --git-dir 2>&1; printf 'rc=%s' "$?")"
    printf '    rev-parse --git-dir inside the empty dir -> %s\n' "$(printf '%s' "$WALKUP" | tr '\n' ' ')"
    printf '    is_repo_toplevel on the same dir       -> %s\n' \
        "$(is_repo_toplevel "$SUB/lib" && echo 'true (WRONG)' || echo 'false (correct)')"
    "${LABENV[@]}" bash "$SELF" --root "$SUB" >"$LAB/u3.out" 2>&1; U3=$?
    U3_NAMED=0
    grep -q 'walks UP' "$LAB/u3.out" 2>/dev/null && U3_NAMED=1
    grep -E 'UNDET' "$LAB/u3.out" | sed 's/^/    | /' | head -3
    printf '    rc=%s (expected 2); the walk-up trap is named in the output: %s\n\n' \
        "$U3" "$( [ "$U3_NAMED" -eq 1 ] && echo yes || echo no )"

    FAILS=0
    [ "$G1" -eq 0 ] || { printf 'PROBLEM: an ordinary repository did not yield 0 (got %s)\n' "$G1" >&2; FAILS=1; }
    [ "$R"  -eq 1 ] || { printf 'PROBLEM: a committed foreign object store did not yield 1 (got %s). A\n' "$R" >&2
                         printf 'broken subject must be a DETERMINED finding, never could-not-determine.\n' >&2; FAILS=1; }
    [ "$DECOY_FLAGGED" -eq 0 ] || { printf 'PROBLEM: the plain-text decoy at a packfile-shaped path WAS flagged —\n' >&2
                                    printf 'the detector matches names, so the RED above proves nothing.\n' >&2; FAILS=1; }
    [ "$RF" -eq 0 ] || { printf 'PROBLEM: a reflog-only store did not yield 0 (got %s). An object no ref\n' "$RF" >&2
                         printf 'reaches cannot be pushed, so grading it as an exposure is a false finding.\n' >&2; FAILS=1; }
    [ "$RF_NAMED" -eq 1 ] || { printf 'PROBLEM: rc was 0 for the reflog-only store but nothing said REFLOG-ONLY.\n' >&2
                               printf 'A 0 that says nothing is indistinguishable from a clean tree.\n' >&2; FAILS=1; }
    [ "$RF_SILENT" -eq 0 ] || { printf 'PROBLEM: the guard went silent about the reflog-only store entirely.\n' >&2; FAILS=1; }
    [ "$G2" -eq 0 ] || { printf 'PROBLEM: the cleaned repository did not return to 0 (got %s)\n' "$G2" >&2; FAILS=1; }
    [ "$U1" -eq 2 ] || { printf 'PROBLEM: a missing root did not yield 2 (got %s)\n' "$U1" >&2; FAILS=1; }
    [ "$U2" -eq 2 ] || { printf 'PROBLEM: a non-repository root did not yield 2 (got %s)\n' "$U2" >&2; FAILS=1; }
    [ "$U3" -eq 2 ] || { printf 'PROBLEM: an uninitialised submodule did not yield 2 (got %s) — the\n' "$U3" >&2
                         printf 'rev-parse walk-up trap is still open.\n' >&2; FAILS=1; }
    [ "$U3_NAMED" -eq 1 ] || { printf 'PROBLEM: rc was 2 but the uninitialised submodule was not the stated\n' >&2
                               printf 'reason; a 2 for an unrelated reason proves nothing about the trap.\n' >&2; FAILS=1; }
    [ "${DIRT:-1}" -eq 0 ] || { printf 'PROBLEM: the scan left %s modified file(s); this guard must be read-only\n' "$DIRT" >&2; FAILS=1; }
    [ "$AFTER" = "$SUBJECT_SUM" ] || { printf 'PROBLEM: the subject was not restored byte-identically\n' >&2; FAILS=1; }

    [ "$FAILS" -ne 0 ] && { printf '\nPROBLEM: this guard does not grade what it claims to.\n' >&2; exit 1; }
    printf 'OK: a real foreign object store, under an innocuous directory name on an\n'
    printf 'innocuous branch, was DETECTED as rc=1; a same-shaped plain-text decoy was\n'
    printf 'NOT flagged; deleting the branch dropped it to rc=0 while STILL reporting it\n'
    printf 'as reflog-only; the pruned tree returned to a silent rc=0; the scan wrote\n'
    printf 'nothing; and all three could-not-determine shapes returned rc=2 — including\n'
    printf 'the empty nested directory that `rev-parse --git-dir` calls healthy.\n'
    printf 'MUTATION PROOF: PASS — 6 mutations each produced the verdict they must, over 13\n'
    printf 'assertions: a genuine foreign object store -> 1; a same-shaped plain-text decoy\n'
    printf '-> NOT flagged; a reflog-only store -> 0 and still NAMED; an uninitialised\n'
    printf 'nested submodule -> 2; a missing root -> 2; a non-repository root -> 2. Controls:\n'
    printf 'an ordinary repository -> 0, the pruned tree -> 0, zero worktree dirt, subject\n'
    printf 'sha256 unchanged.\n'
    exit 0
fi

# =============================================================================
# PREFLIGHT
# =============================================================================
[ -n "$ROOT" ] && [ -d "$ROOT" ] || {
    printf 'UNDETERMINED: --root %s is not a directory\n' "${ROOT:-<empty>}" >&2; exit 2; }
if ! is_repo_toplevel "$ROOT"; then
    printf 'UNDETERMINED: %s is not the TOPLEVEL of a git repository. Nothing about\n' "$ROOT" >&2
    printf 'what this tree would publish can be established from here.\n' >&2
    exit 2
fi
ROOT="$(cd -- "$ROOT" && pwd -P)"

printf '== private-content exposure across every ref, the index and the worktree ==\n'
printf 'root: %s\n\n' "$ROOT"

OBJLIST="$(mktemp 2>/dev/null)" || { printf 'UNDETERMINED: cannot create a temp file\n' >&2; exit 2; }
CANDS="$(mktemp 2>/dev/null)"   || { rm -f "$OBJLIST"; printf 'UNDETERMINED: cannot create a temp file\n' >&2; exit 2; }
STORES="$(mktemp 2>/dev/null)"  || { rm -f "$OBJLIST" "$CANDS"; printf 'UNDETERMINED: cannot create a temp file\n' >&2; exit 2; }
SLUGF="$(mktemp 2>/dev/null)"   || { rm -f "$OBJLIST" "$CANDS" "$STORES"; printf 'UNDETERMINED: cannot create a temp file\n' >&2; exit 2; }
REFOBJ="$(mktemp 2>/dev/null)"  || { rm -f "$OBJLIST" "$CANDS" "$STORES" "$SLUGF"; printf 'UNDETERMINED: cannot create a temp file\n' >&2; exit 2; }
UNIONLIST="$(mktemp 2>/dev/null)" || { rm -f "$OBJLIST" "$CANDS" "$STORES" "$SLUGF" "$REFOBJ"; printf 'UNDETERMINED: cannot create a temp file\n' >&2; exit 2; }
IDXTMP="$(mktemp 2>/dev/null)"    || { rm -f "$OBJLIST" "$CANDS" "$STORES" "$SLUGF" "$REFOBJ" "$UNIONLIST"; printf 'UNDETERMINED: cannot create a temp file\n' >&2; exit 2; }
PACKOBJ="$(mktemp 2>/dev/null)"   || { rm -f "$OBJLIST" "$CANDS" "$STORES" "$SLUGF" "$REFOBJ" "$UNIONLIST" "$IDXTMP"; printf 'UNDETERMINED: cannot create a temp file\n' >&2; exit 2; }
trap 'rm -f "$OBJLIST" "$CANDS" "$STORES" "$SLUGF" "$SLUGF.reflog" "$REFOBJ" "$UNIONLIST" "$IDXTMP" "$PACKOBJ"' EXIT
NOTE_LINES=""; NOTES=0
storenote() { NOTES=$((NOTES+1)); NOTE_LINES="${NOTE_LINES}  $1"$'\n'
              printf '  %s%-11s%s %s\n' "$YEL" "NOTE" "$NC" "$1"; }

# =============================================================================
# LAYER A — foreign git object stores in history and in the index
# =============================================================================
printf -- '-- A. foreign git object stores reachable from any ref, or staged --\n'

# TWO enumerations, because they answer different questions and conflating them
# would either over- or under-state the hazard:
#
#   PUSHABLE  `--all` is every ref under refs/ plus HEAD — precisely what
#             `git push --all` and `git push --mirror` publish. `--indexed-objects`
#             adds the staging area, because this project's commit wrapper runs
#             `git add .` and would commit it in the next commit.
#   UNION     the same plus `--reflog`. A branch that was deleted leaves its
#             objects in the object database, reachable from the reflog, until a
#             `gc --prune=now`. `git push` CANNOT publish them — but one
#             `git checkout` from the reflog puts them back on a ref, and then
#             it can. That is a NOTE, not a finding, and the difference is
#             stated rather than quietly folded into one number.
#
# A QUERY THAT FAILED TO RUN IS NEVER A CLEAN RESULT. Every enumeration below is
# rc-checked and a failure exits 2. This is not defensive boilerplate: on
# 2026-09-01 three consecutive attempts to read a foreign object store in this
# very tree reported "0 commits, nothing here", and all three were queries that
# had ABORTED — a stale `worktree =` line in the captured config made git refuse
# to run at all, and the refs had been separated from the objects so
# `for-each-ref` returned nothing. A blind instrument reports clean.
if ! git -C "$ROOT" rev-list --objects --all --indexed-objects > "$OBJLIST" 2>/dev/null; then
    printf 'UNDETERMINED: `git rev-list --objects --all --indexed-objects` failed in %s;\n' "$ROOT" >&2
    printf 'the pushable history could not be enumerated, so nothing about it is known.\n' >&2
    exit 2
fi
if ! git -C "$ROOT" rev-list --objects --all --reflog --indexed-objects > "$UNIONLIST" 2>/dev/null; then
    printf 'UNDETERMINED: `git rev-list --objects --all --reflog --indexed-objects` failed\n' >&2
    printf 'in %s; objects left behind by a deleted branch could not be enumerated.\n' "$ROOT" >&2
    exit 2
fi
TOTAL_OBJ="$(wc -l < "$OBJLIST" | tr -d ' ')"
TOTAL_UNION="$(wc -l < "$UNIONLIST" | tr -d ' ')"

# Path SHAPE narrows the field cheaply. It is a FILTER, never a verdict: every
# survivor is judged on its bytes, and --prove-failure seeds a decoy that passes
# this filter and must still not be flagged.
{
  grep -E '^[0-9a-f]{40} (.*/)?objects/(pack/pack-[0-9a-f]{40}\.(pack|idx)|[0-9a-f]{2}/[0-9a-f]{38})$' "$UNIONLIST"
  grep -E '^[0-9a-f]{40} (.*/)?(HEAD|config|packed-refs|refs/.*)$' "$UNIONLIST"
} 2>/dev/null | sort -u > "$CANDS"

sed -E 's#^[0-9a-f]{40} ##
        s#(^|/)objects/(pack/pack-[0-9a-f]{40}\.(pack|idx)|[0-9a-f]{2}/[0-9a-f]{38})$##
        s#(^|/)(HEAD|config|packed-refs)$##
        s#(^|/)refs/.*$##' "$CANDS" 2>/dev/null | sort -u > "$STORES"

A_HITS=0; A_PUSHABLE=0
: > "$SLUGF"; : > "$SLUGF.reflog"
while IFS= read -r store; do
    prefix=""
    [ -n "$store" ] && prefix="$store/"

    e_pack=0; e_idx=0; e_loose=0; e_head=0; e_config=0; e_prefs=0
    pack_sha=""; pack_path=""; pack_bytes=0; config_sha=""; loose_decisive=0
    idx_shas=""; ref_shas=""; own_shas=""; loose_shas=""; pushable=0

    while IFS=' ' read -r sha path; do
        [ -n "${path:-}" ] || continue
        case "$path" in "$prefix"*) ;; *) continue ;; esac
        rel="${path#"$prefix"}"
        # Is THIS blob reachable from something `git push` can publish? A store
        # whose objects survive only in the reflog cannot be pushed; that is a
        # different state from an exposure and is reported as one.
        grep -qF "$sha " "$OBJLIST" 2>/dev/null && pushable=1
        case "$rel" in
            objects/pack/pack-*.pack)
                if is_pack_magic "$(blob_magic_hex "$sha" 8)"; then
                    e_pack=1
                    sz="$(blob_size "$sha")"
                    if [ "${sz:-0}" -gt "${pack_bytes:-0}" ] 2>/dev/null; then
                        pack_bytes="$sz"; pack_sha="$sha"; pack_path="$path"
                    fi
                fi ;;
            objects/pack/pack-*.idx)
                if is_idx_magic "$(blob_magic_hex "$sha" 8)"; then
                    e_idx=1; idx_shas="$idx_shas $sha"
                fi ;;
            objects/??/*)
                if is_zlib_magic "$(blob_magic_hex "$sha" 2)"; then
                    e_loose=1
                    is_loose_object "$sha" && loose_decisive=1
                    # `objects/ab/cdef…` IS the object's sha. Recorded so a ref
                    # naming a loose object is not miscounted as dangling.
                    l="${rel#objects/}"; l="${l/\//}"
                    [[ "$l" =~ ^[0-9a-f]{40}$ ]] && loose_shas="$loose_shas $l"
                fi ;;
            refs/*)
                t="$(blob_text_head "$sha" 64)"; t="${t%%$'\n'*}"
                [[ "$t" =~ ^[0-9a-f]{40}$ ]] && ref_shas="$ref_shas $t" ;;
            HEAD)
                t="$(blob_text_head "$sha" 64)"
                t="${t%%$'\n'*}"
                case "$t" in
                    'ref: refs/'*) e_head=1 ;;
                    *) if [[ "$t" =~ ^[0-9a-f]{40}$ ]]; then e_head=1; ref_shas="$ref_shas $t"; fi ;;
                esac ;;
            config)
                t="$(blob_text_head "$sha" 4096)"
                if grep -q '\[core\]' <<<"$t" \                   && grep -q 'repositoryformatversion' <<<"$t"; then
                    e_config=1; config_sha="$sha"
                fi ;;
            packed-refs)
                if [ "$(blob_text_head "$sha" 17)" = '# pack-refs with:' ]; then
                    e_prefs=1
                    while IFS= read -r pr; do
                        [[ "$pr" =~ ^([0-9a-f]{40})[[:space:]] ]] && ref_shas="$ref_shas ${BASH_REMATCH[1]}"
                    done < <(blob_text_head "$sha" 65536)
                fi ;;
        esac
    done < "$CANDS"

    objects_layer=$((e_pack + e_idx + e_loose))
    classes=$((e_pack + e_idx + e_loose + e_head + e_config + e_prefs))
    [ "$objects_layer" -ge 1 ] && [ "$classes" -ge 2 ] || continue

    A_HITS=$((A_HITS+1))
    [ "$pushable" -eq 1 ] && A_PUSHABLE=$((A_PUSHABLE+1))
    label="${store:-<repository root>}"
    ev=""
    [ "$e_pack"   -eq 1 ] && ev="${ev}E1(PACK magic) "
    [ "$e_idx"    -eq 1 ] && ev="${ev}E2(idx magic) "
    [ "$e_loose"  -eq 1 ] && ev="${ev}E3(zlib$( [ "$loose_decisive" -eq 1 ] && printf ' inflating to a git object header')) "
    [ "$e_head"   -eq 1 ] && ev="${ev}E4(HEAD content) "
    [ "$e_config" -eq 1 ] && ev="${ev}E5(git config) "
    [ "$e_prefs"  -eq 1 ] && ev="${ev}E6(packed-refs) "

    if [ "$pushable" -eq 1 ]; then
        finding "FOREIGN GIT OBJECT STORE committed at '$label' — $classes evidence class(es): $ev"
    else
        # Reachable only through the reflog: `git push` cannot publish it, so
        # this is NOT the exposure the gate grades. It is also not nothing —
        # one `git checkout` out of the reflog puts it back on a ref. Stated as
        # what it is, and never folded into the finding count.
        storenote "foreign git object store at '$label' is REFLOG-ONLY: unreachable from every ref and from the index, so no \`git push\` can publish it — but its objects are still in the object database until \`git gc --prune=now\`, and a reflog checkout would put them back on a ref. $classes evidence class(es): $ev"
    fi
    [ -n "$pack_path" ] && printf '              largest packfile: %s bytes at %s (blob %s)\n' \
        "$pack_bytes" "$pack_path" "${pack_sha:0:12}"

    # ---- what the pack actually CONTAINS, read from the .idx alone ----------
    # `git show-index` parses a pack index with NO repository and NO .pack file,
    # so a captured store whose config is broken — a stale `worktree =` line
    # makes every ordinary git command abort — can still be read. That is the
    # lesson of 2026-09-01: three consecutive reads of such a store reported
    # "0 commits, nothing here" and every one of them was an ABORTED query.
    # A census that cannot be taken is reported as unknown, never as empty.
    if [ -n "$idx_shas" ]; then
        idx_total=0; idx_ok=0; idx_bad=0
        : > "$PACKOBJ"
        for isha in $idx_shas; do
            git -C "$ROOT" cat-file blob "$isha" > "$IDXTMP" 2>/dev/null
            if git show-index < "$IDXTMP" > "$REFOBJ" 2>/dev/null; then
                n="$(wc -l < "$REFOBJ" | tr -d ' ')"
                idx_total=$((idx_total + n)); idx_ok=$((idx_ok+1))
                awk '{print $2}' "$REFOBJ" >> "$PACKOBJ" 2>/dev/null
            else
                idx_bad=$((idx_bad+1))
            fi
        done
        if [ "$idx_bad" -eq 0 ]; then
            printf '              pack index census: %s object(s) across %s index file(s)\n' "$idx_total" "$idx_ok"
        else
            printf '              pack index census: %s object(s) across %s readable index file(s); %s\n' \
                "$idx_total" "$idx_ok" "$idx_bad"
            printf '              index file(s) COULD NOT BE READ — the census is a lower bound, not a total\n'
        fi
        # A ref naming an object the store does not hold means the capture is
        # INCOMPLETE. Reported because "there is a backup" and "the backup
        # restores" are different claims, and only the second one is worth having.
        if [ -n "$ref_shas" ]; then
            printf '%s\n' $loose_shas >> "$PACKOBJ" 2>/dev/null
            sort -u -o "$PACKOBJ" "$PACKOBJ" 2>/dev/null
            dangling=0; reftot=0
            for rs in $ref_shas; do
                reftot=$((reftot+1))
                grep -qx "$rs" "$PACKOBJ" 2>/dev/null || dangling=$((dangling+1))
            done
            if [ "$dangling" -gt 0 ]; then
                printf '              %sINCOMPLETE CAPTURE: %s of %s ref(s) in this store name an object\n' "$YEL" "$dangling" "$reftot"
                printf '              the store does not contain — it would not restore.%s\n' "$NC"
            else
                printf '              every one of its %s ref(s) resolves inside the store\n' "$reftot"
            fi
        fi
    elif [ "$e_pack" -eq 1 ]; then
        printf '              pack index census: NOT TAKEN — a packfile is present but no\n'
        printf '              readable pack index was captured with it; contents unknown\n'
    fi

    if [ -n "$config_sha" ]; then
        slugs=""
        while IFS= read -r u; do
            [ -n "$u" ] || continue
            s="$(url_to_slug "$u")"; [ -n "$s" ] || continue
            case " $slugs " in *" $s "*) ;; *) slugs="$slugs $s" ;; esac
        done < <(blob_text_head "$config_sha" 4096 \
                 | sed -nE 's/^[[:space:]]*(url|pushurl)[[:space:]]*=[[:space:]]*(.+)$/\2/p')
        if [ -n "$slugs" ]; then
            printf '              provenance, from its own captured config:%s\n' "$slugs"
            # Only a PUSHABLE store can produce a publication finding. A
            # reflog-only one is already reported as the note it is; counting it
            # twice would inflate the verdict with a state that cannot be pushed.
            [ "$pushable" -eq 1 ] && printf '%s\n' "$slugs" >> "$SLUGF"
            [ "$pushable" -eq 0 ] && printf '%s\n' "$slugs" >> "$SLUGF.reflog"
        else
            printf '              provenance: the captured config names no remote URL\n'
        fi
    else
        printf '              provenance: UNKNOWN — no git config was captured with the store\n'
    fi

    # Attribution runs ONLY when there is something to attribute, so a clean
    # repository never pays for this pass.
    if [ -n "$pack_sha" ]; then
        carriers=""
        while IFS= read -r ref; do
            [ -n "$ref" ] || continue
            # Materialised through a file: `… | grep -q` would report failure
            # under pipefail even on a match. See the pipeline note above.
            git -C "$ROOT" rev-list --objects "$ref" > "$REFOBJ" 2>/dev/null
            grep -qF "$pack_sha" "$REFOBJ" 2>/dev/null && carriers="$carriers $ref"
        done < <(git -C "$ROOT" for-each-ref --format='%(refname)' 2>/dev/null)
        git -C "$ROOT" ls-files -s > "$REFOBJ" 2>/dev/null
        grep -qF "$pack_sha" "$REFOBJ" 2>/dev/null && carriers="$carriers (STAGED-in-index)"
        printf '              carried by:%s\n' \
            "${carriers:- no ref and not the index — reflog-only, therefore unpushable}"
        for ref in $carriers; do
            case "$ref" in
                refs/remotes/*) printf '              %sALREADY PUBLISHED: %s is a remote-tracking ref%s\n' "$RED" "$ref" "$NC" ;;
            esac
        done
    fi
done < "$STORES"

[ "$A_HITS" -eq 0 ] && ok "CLEAN" "$TOTAL_OBJ pushable object path(s) ($TOTAL_UNION including reflog): no foreign object store"

# =============================================================================
# LAYER B — the fleet, its visibility, and private content in public history
# =============================================================================
printf -- '\n-- B. fleet content reachable from this repository --\n'

GM="$ROOT/.gitmodules"
if [ ! -f "$GM" ]; then
    # A repository that declares no submodules has no fleet. That is a
    # DETERMINED fact, not an inability to measure one.
    note "fleet" "no .gitmodules: this repository declares no submodules"
else
    if ! git config -f "$GM" --get-regexp 'submodule\..*\.path' >/dev/null 2>&1; then
        undet ".gitmodules exists at $ROOT but declares no parseable submodule path; the fleet cannot be derived"
    fi
    HD="$ROOT/helix-deps.yaml"

    # Provider probe, done once. Its failure is recorded, NOT yet escalated:
    # whether an unknown visibility matters depends on what it would grade.
    GH_OK=1; GH_WHY=""
    if ! command -v gh >/dev/null 2>&1; then
        GH_OK=0; GH_WHY="gh is not on PATH"
    elif ! gh auth status >/dev/null 2>&1; then
        GH_OK=0; GH_WHY="gh is present but not authenticated"
    fi
    visibility() {
        [ "$GH_OK" -eq 1 ] || { printf 'UNKNOWN'; return; }
        local v; v="$(gh repo view "$1" --json visibility -q .visibility 2>/dev/null)"
        [ -n "$v" ] && printf '%s' "$v" || printf 'UNKNOWN'
    }

    SELF_SLUG=""
    for r in origin github upstream $(git -C "$ROOT" remote 2>/dev/null); do
        u="$(git -C "$ROOT" remote get-url "$r" 2>/dev/null)" || continue
        [ -n "$u" ] && { SELF_SLUG="$(url_to_slug "$u")"; break; }
    done
    SELF_VIS="UNKNOWN"
    if [ -z "$SELF_SLUG" ]; then
        note "this repo" "no remote is configured: this working copy publishes nowhere as it stands"
    else
        SELF_VIS="$(visibility "$SELF_SLUG")"
        case "$SELF_VIS" in
            PUBLIC)  warn "THIS REPO" "$SELF_SLUG is PUBLIC — anything published from here is published to everyone" ;;
            UNKNOWN) note "this repo" "$SELF_SLUG — visibility not determined${GH_WHY:+ ($GH_WHY)}" ;;
            *)       ok   "THIS REPO" "$SELF_SLUG is $SELF_VIS" ;;
        esac
    fi

    NPUB=0; NPRIV=0; NUNK=0; NTOT=0
    PRIVATE_SLUGS=""
    while read -r key path; do
        name="${key#submodule.}"; name="${name%.path}"
        NTOT=$((NTOT+1))
        url="$(git config -f "$GM" --get "submodule.$name.url" 2>/dev/null)"
        if [ -z "$url" ]; then
            undet "submodule '$name' declares a path but no url in .gitmodules; its repository cannot be identified"
            continue
        fi
        slug="$(url_to_slug "$url")"

        # Corroborate .gitmodules against helix-deps.yaml. Disagreement is a
        # NOTE, never a verdict input: cascade check C6 owns that comparison.
        [ -f "$HD" ] && ! grep -qF "$url" "$HD" 2>/dev/null \
            && note "note" "$slug is in .gitmodules but its ssh_url is absent from helix-deps.yaml (C6 owns this)"

        # ---- structural facts, established WITHOUT the provider -------------
        # A gitlink contributes no object whose path lies under `<path>/`, so
        # any such path is committed CONTENT, not a gitlink.
        esc="$(printf '%s' "$path" | sed 's/[][\.*^$+?(){}|\/]/\\&/g')"
        leaked="$(grep -cE "^[0-9a-f]{40} ${esc}/" "$OBJLIST" 2>/dev/null)"
        [ -n "$leaked" ] || leaked=0

        if is_repo_toplevel "$ROOT/$path"; then state=REPO
        elif [ ! -e "$ROOT/$path" ];             then state=MISSING
        elif [ -z "$(ls -A "$ROOT/$path" 2>/dev/null)" ]; then state=EMPTY
        else state=NONREPO
        fi

        # ---- does grading this one NEED the provider? -----------------------
        if [ "$leaked" -eq 0 ] && [ "$state" = REPO ]; then
            # No content of it is here and its path is a real checkout. No
            # provider answer could change that, so none is demanded. The
            # visibility is still shown when it is cheaply known.
            vis="$(visibility "$slug")"
            case "$vis" in PUBLIC) NPUB=$((NPUB+1)) ;; UNKNOWN) NUNK=$((NUNK+1)) ;; *) NPRIV=$((NPRIV+1)); PRIVATE_SLUGS="$PRIVATE_SLUGS $slug" ;; esac
            ok "GITLINK" "$path ($slug${vis:+, $vis}) — a gitlink only; no content of it is in this repository"
            continue
        fi

        vis="$(visibility "$slug")"
        case "$vis" in PUBLIC) NPUB=$((NPUB+1)) ;; UNKNOWN) NUNK=$((NUNK+1)) ;; *) NPRIV=$((NPRIV+1)); PRIVATE_SLUGS="$PRIVATE_SLUGS $slug" ;; esac

        if [ "$leaked" -gt 0 ]; then
            case "$vis" in
                UNKNOWN) undet "submodule '$path' ($slug) has $leaked object path(s) committed as FILES here, and its visibility is UNKNOWN${GH_WHY:+ — $GH_WHY}; whether that is an exposure cannot be graded" ;;
                PUBLIC)  note "note" "$path ($slug, PUBLIC) has $leaked object path(s) committed as files rather than a gitlink — a hygiene defect, not an exposure" ;;
                *)       finding "$vis submodule '$path' ($slug) has $leaked object path(s) committed as FILES in this repository's history or index — a gitlink contributes none"
                         grep -E "^[0-9a-f]{40} ${esc}/" "$OBJLIST" 2>/dev/null | head -5 | sed 's/^/              /' ;;
            esac
        fi

        case "$state" in
            REPO) ;;
            NONREPO)
                case "$vis" in
                    UNKNOWN) undet "'$path' ($slug) is NOT a repository toplevel and is NOT empty, and its visibility is UNKNOWN${GH_WHY:+ — $GH_WHY}" ;;
                    PUBLIC)  note "note" "$path ($slug, PUBLIC) is not a repository toplevel but is not empty; its files sit loose in this tree" ;;
                    *)       finding "$vis submodule '$path' ($slug) is NOT a repository toplevel but is NOT empty: its files sit loose inside ${SELF_SLUG:-this repository}${SELF_VIS:+ ($SELF_VIS)}, where \`git add .\` would commit them" ;;
                esac ;;
            EMPTY)
                undet "submodule '$path' ($slug, $vis) is an EMPTY directory — uninitialised. \`git rev-parse --git-dir\` walks UP from there and succeeds, which is why that test is not used; its content state is NOT KNOWN" ;;
            MISSING)
                undet "submodule '$path' ($slug, $vis) is declared but absent from the worktree; its content state cannot be established from disk" ;;
        esac
    done < <(git config -f "$GM" --get-regexp 'submodule\..*\.path' 2>/dev/null)

    note "fleet" "$NTOT declared submodule(s): $NPUB public / $NPRIV private / $NUNK visibility-undetermined"

    # Cross-reference layer A provenance against the private half of the fleet.
    while IFS= read -r line; do
        for s in $line; do
            case " $PRIVATE_SLUGS " in
                *" $s "*) finding "an object store above is a copy of the PRIVATE repository $s, held inside ${SELF_SLUG:-this repository}${SELF_VIS:+ ($SELF_VIS)}. One \`git push --all\` or \`--mirror\` publishes its entire history." ;;
            esac
        done
    done < "$SLUGF"
    while IFS= read -r line; do
        for s in $line; do
            case " $PRIVATE_SLUGS " in
                *" $s "*) storenote "the reflog-only store above is a copy of the PRIVATE repository $s. It is NOT pushable as things stand; \`git gc --prune=now\` is what removes it from the object database, and that is an operator action." ;;
            esac
        done
    done < "$SLUGF.reflog"
    if [ "$A_HITS" -gt 0 ] && [ "$GH_OK" -eq 0 ]; then
        undet "a foreign object store was found but $GH_WHY, so its provenance could not be matched against the private fleet"
    fi
fi

# =============================================================================
# LAYER C — the working tree, where .gitignore is the only thing standing
# =============================================================================
printf -- '\n-- C. foreign object stores present in the working tree --\n'

C_HITS=0; C_IGNORED=0
while IFS= read -r headfile; do
    [ -n "$headfile" ] || continue
    d="$(dirname -- "$headfile")"
    [ -d "$d/objects" ] || continue

    e_pack=0; e_head=0; e_config=0
    case "$(file_magic_hex "$headfile" 8)" in
        7265663a20726566*) e_head=1 ;;   # 'ref: ref'
        *) ht="$(head -c 41 -- "$headfile" 2>/dev/null)"; ht="${ht%%$'\n'*}"
           [[ "$ht" =~ ^[0-9a-f]{40} ]] && e_head=1 ;;
    esac
    while IFS= read -r p; do
        [ -n "$p" ] || continue
        is_pack_magic "$(file_magic_hex "$p" 8)" && { e_pack=1; break; }
    done < <(find "$d/objects" -type f -name 'pack-*.pack' 2>/dev/null | head -20)
    if [ -f "$d/config" ] && grep -q '\[core\]' "$d/config" 2>/dev/null \
       && grep -q 'repositoryformatversion' "$d/config" 2>/dev/null; then e_config=1; fi
    [ "$e_pack" -eq 1 ] && [ $((e_head + e_config)) -ge 1 ] || continue

    rel="${d#"$ROOT"/}"
    bytes="$(du -sb "$d" 2>/dev/null | cut -f1)"
    prov_slug=""
    if [ -f "$d/config" ]; then
        p="$(sed -nE 's/^[[:space:]]*url[[:space:]]*=[[:space:]]*(.+)$/\1/p' "$d/config" 2>/dev/null | head -1)"
        [ -n "$p" ] && prov_slug="$(url_to_slug "$p")"
    fi

    if git -C "$ROOT" ls-files --error-unmatch -- "$rel" >/dev/null 2>&1; then
        C_HITS=$((C_HITS+1))
        finding "a foreign object store is TRACKED in the worktree at '$rel' (${bytes:-?} bytes${prov_slug:+, from $prov_slug})"
    elif git -C "$ROOT" check-ignore -q -- "$rel" 2>/dev/null; then
        C_IGNORED=$((C_IGNORED+1))
        rule="$(git -C "$ROOT" check-ignore -v -- "$rel" 2>/dev/null | head -1)"
        warn "IGNORED" "'$rel' (${bytes:-?} bytes${prov_slug:+, from $prov_slug}) is untracked ONLY because of: ${rule:-<unknown rule>}"
    else
        C_HITS=$((C_HITS+1))
        finding "a foreign object store sits UNTRACKED AND UNIGNORED at '$rel' (${bytes:-?} bytes${prov_slug:+, from $prov_slug}); \`git add .\` would commit it"
    fi
done < <(find "$ROOT" \
            \( -name '.git' -o -name node_modules -o -name '.venv' -o -name venv \
               -o -name '.cache' \) -prune -o -type f -name HEAD -print 2>/dev/null)

[ "$C_HITS" -eq 0 ] && [ "$C_IGNORED" -eq 0 ] && ok "CLEAN" "no foreign object store in the working tree"

# =============================================================================
# VERDICT
# =============================================================================
printf '\n=== %d finding(s) / %d undetermined / %d unsuppressible note(s) ===\n' \
       "$FINDINGS" "$UNDET" "$((NOTES + C_IGNORED))"

if [ "$NOTES" -gt 0 ]; then
    printf '\n%s┌─ NOTE — %d STORE(S) REACHABLE ONLY FROM THE REFLOG ───────────────%s\n' "$YEL" "$NOTES" "$NC"
    printf '%s' "$NOTE_LINES" | sed "s/^/${YEL}│${NC}/"
    printf '%s│%s\n' "$YEL" "$NC"
    printf '%s│%s Not a finding, and the reason is stated rather than assumed: `git push`\n' "$YEL" "$NC"
    printf '%s│%s cannot publish an object no ref reaches. It is not nothing either —\n' "$YEL" "$NC"
    printf '%s│%s `git reflog` still names the deleted branch and a checkout puts the\n' "$YEL" "$NC"
    printf '%s│%s objects back on a ref, after which this gate reports rc=1.\n' "$YEL" "$NC"
    printf '%s└──────────────────────────────────────────────────────────────────%s\n' "$YEL" "$NC"
fi

if [ "$C_IGNORED" -gt 0 ]; then
    printf '\n%s┌─ NOTE — %d FOREIGN OBJECT STORE(S) HELD OFF BY .gitignore ALONE ──%s\n' "$YEL" "$C_IGNORED" "$NC"
    printf '%s│%s A `.gitignore` rule is a convention, not a boundary. It is one edit,\n' "$YEL" "$NC"
    printf '%s│%s one `git add -f`, or one wrapper that runs `git add .` away from being\n' "$YEL" "$NC"
    printf '%s│%s no protection at all. Printed on every run and not silenceable: this is\n' "$YEL" "$NC"
    printf '%s│%s the state that produced the near-miss this guard exists for. Move the\n' "$YEL" "$NC"
    printf '%s│%s store OUTSIDE the repository, or keep it knowingly.\n' "$YEL" "$NC"
    printf '%s└──────────────────────────────────────────────────────────────────%s\n' "$YEL" "$NC"
fi

if [ "$FINDINGS" -gt 0 ]; then
    printf '\n%s┌─ %d EXPOSURE FINDING(S) ──────────────────────────────────────────%s\n' "$RED" "$FINDINGS" "$NC"
    printf '%s' "$FINDING_LINES" | sed "s/^/${RED}│${NC}/"
    printf '%s│%s\n' "$RED" "$NC"
    printf '%s│%s Until resolved: NEVER `git push --all`, NEVER `git push --mirror`.\n' "$RED" "$NC"
    printf '%s│%s Push one explicit refspec at a time.\n' "$RED" "$NC"
    printf '%s│%s Deleting a branch is an OPERATOR decision. A backup is not this\n' "$RED" "$NC"
    printf '%s│%s guard'"'"'s to destroy, and §9.3 requires a fresh hardlinked backup\n' "$RED" "$NC"
    printf '%s│%s before any destructive operation.\n' "$RED" "$NC"
    printf '%s└──────────────────────────────────────────────────────────────────%s\n' "$RED" "$NC"
fi

if [ "$UNDET" -gt 0 ]; then
    printf '\n%s┌─ %d COULD NOT DETERMINE — NOT A PASS ─────────────────────────────%s\n' "$YEL" "$UNDET" "$NC"
    printf '%s' "$UNDET_LINES" | sed "s/^/${YEL}│${NC}/"
    printf '%s└──────────────────────────────────────────────────────────────────%s\n' "$YEL" "$NC"
fi

# A CONFIRMED FAILURE OUTRANKS AN UNDETERMINED.
[ "$FINDINGS" -gt 0 ] && exit 1
[ "$UNDET"    -gt 0 ] && exit 2
exit 0
