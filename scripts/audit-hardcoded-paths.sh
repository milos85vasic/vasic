#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Fail the build on machine-specific absolute paths — ACROSS THE WHOLE FLEET.
#
# WHY
# ---
# 18 tracked files hardcoded `/Volumes/T7/Projects/vasic` — the original
# author's macOS machine. On every other checkout they silently pointed at
# nonexistent directories. `_tools/deploy-langs.sh` was the worst case: it uses
# `set -uo pipefail` WITHOUT `-e`, so its `cd "$ROOT"` failed silently and the
# script carried on in the caller's working directory — then committed and
# pushed both site submodules. CI papered over the whole class by symlinking
# `/Volumes/T7/Projects/vasic -> $GITHUB_WORKSPACE`.
#
# Paths must be DERIVED, never literal:
#   bash    ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
#   python  pathlib.Path(__file__).resolve().parents[N]
#   node    path.resolve(__dirname, '..')          (CJS)
#           path.dirname(fileURLToPath(import.meta.url))   (ESM)
# `$HOME`, `~` and env overrides are fine — they are not machine-specific.
#
#   ./scripts/audit-hardcoded-paths.sh                 # audit this repo + fleet
#   ./scripts/audit-hardcoded-paths.sh /path/to/repo   # audit another checkout
#   ./scripts/audit-hardcoded-paths.sh --list          # show what is scanned
#   ./scripts/audit-hardcoded-paths.sh --no-submodules # this repo only
#
# Comment-only lines are ignored: documenting the historical bug is not the bug.
# Genuine exceptions go in .hardcoded-paths-allow as `path/to/file` with a
# reason on the preceding `#` line — anything else is a failure.
#
# THE GITLINK BLIND SPOT (fixed 2026-09-01)
# -----------------------------------------
# This gate used to enumerate files with a bare `git ls-files` at the umbrella
# root. A submodule appears there as a GITLINK — one directory entry, no
# contents — and the following `[ -f ... ]` test dropped it, because a gitlink
# is a directory, not a regular file. MEASURED before the fix: the sibling
# gate's `--list` reported 180 files, ZERO of them inside any of the nine
# declared submodules. That is why a `/Users/<name>/Library/Android/sdk/...`
# literal survived undetected in a production QA script inside `ai_interviewing`.
# The identical blind spot was found and fixed in pre-push gate E first; this
# gate follows that fix's approach so the two cannot drift apart.
#
# OWNERSHIP IS DERIVED, NEVER HARDCODED
# -------------------------------------
# The fleet comes from `.gitmodules`, so a submodule added tomorrow is swept
# without editing this file. Ownership comes from `helix-deps.yaml`'s declared
# `deps[].ssh_url` set — the authoritative owned-fleet declaration, guarded in
# BOTH directions by `scripts/verify-governance-cascade.sh` check C6, so it
# cannot drift from `.gitmodules` unnoticed. That is the same evidence source
# `gate_E` uses; deriving a different answer here would fork an ownership model
# the tree already guards.
#
#   OWNED       -> findings are real. They FAIL (rc 1).
#   THIRD-PARTY -> findings are REPORTED as an out-of-scope NOTE and do NOT
#                  fail. §11.4.156(C) scopes enforcement to repositories we
#                  author and push, and §11.4.29 forbids mass-editing vendored
#                  or third-party source. Reporting them is the point; they are
#                  never silently omitted.
#   UNINITIALISED -> rc 2, COULD NOT DETERMINE. Never a pass, never a failure.
#
# `submodules/constitution` is treated as OWNED, deliberately — see the long
# note in the fleet block below.
#
# HONEST BOUNDARIES (§11.4.6)
# ---------------------------
# * The sweep is ONE level deep, from the umbrella that declares the fleet.
#   A gitlink OF a submodule (e.g. `milosvasic.ru/Upstreamable`) is REPORTED as
#   not-swept, never silently skipped, because the nested checkout ships no
#   `helix-deps.yaml` and this gate refuses to classify ownership by guesswork.
# * Files whose extension is neither known-text nor known-binary AND which are
#   larger than the size cap are NOT read (they are ELF binaries in practice).
#   They are listed in the report, so "not scanned" is visible, not implied.
#
# Exit 0 = clean · 1 = findings in an owned repo · 2 = could not do its job
# ------------------------------------------------------------------------------
set -uo pipefail

# ---- arguments ---------------------------------------------------------------
# Target defaults to this script's own repository, but accepts an explicit
# directory so the audit can be pointed at any checkout - and so its own tests
# can exercise it against throwaway repos instead of the live tree.
MODE="audit"
SWEEP=1
TARGET=""
for arg in "$@"; do
    case "$arg" in
        --list)          MODE="list" ;;
        --help|-h)       MODE="help" ;;
        --no-submodules) SWEEP=0 ;;
        --prove-failure) MODE="prove" ;;
        -*)              echo "FATAL: unknown option '$arg'" >&2; exit 2 ;;
        *)               TARGET="$arg" ;;
    esac
done

# Absolute path to THIS file, captured BEFORE the `cd` below. The §1.1 proof
# re-invokes the real entry point dozens of times from inside a sandbox, and a
# relative ${BASH_SOURCE[0]} stops resolving the moment the working directory
# moves.
SELF_ABS="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)/$(basename -- "${BASH_SOURCE[0]}")"

if [[ -n "$TARGET" ]]; then
    ROOT="$(cd -- "$TARGET" 2>/dev/null && pwd)" \
        || { echo "FATAL: no such directory '$TARGET'" >&2; exit 2; }
else
    ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)" \
        || { echo "FATAL: cannot resolve script directory" >&2; exit 2; }
fi
cd "$ROOT" || { echo "FATAL: cannot cd to '$ROOT'" >&2; exit 1; }

if [[ "$MODE" == "help" ]]; then
    grep -E '^#' "${BASH_SOURCE[0]}" | sed -n '2,80p' | sed 's/^# \{0,1\}//'
    exit 0
fi

# ---- prerequisites (rc 2, never rc 0) ---------------------------------------
for _bin in git awk grep; do
    command -v "$_bin" >/dev/null 2>&1 \
        || { echo "FATAL: required tool '$_bin' not on PATH" >&2; exit 2; }
done
git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1 \
    || { echo "FATAL: '$ROOT' is not a git working tree" >&2; exit 2; }

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'
    DIM=$'\033[2m';    NC=$'\033[0m'
else
    RED=""; GREEN=""; YELLOW=""; DIM=""; NC=""
fi

# ------------------------------------------------------------------------------
# §1.1 PAIRED MUTATION PROOF  (--prove-failure)
#
# WHY IT EXISTS
# -------------
# §1.1 requires every gate to carry a paired mutation demonstrating that it
# FAILS when the guarded condition is broken. Until 2026-09-01 this file had
# none, and `scripts/check-registry.tsv` carried it as a `debt` row saying so.
# A gate that has never been observed failing is not known to work — this
# project's own constitution names that defect explicitly.
#
# THE SHAPE, AND WHY IT IS THIS SHAPE
# -----------------------------------
# Copied deliberately from `scripts/verify-check-registry.sh --prove-failure`
# rather than invented, because two other proofs in this tree were found on
# 2026-09-01 running their control against the LIVE tree — so any real finding
# made the control fail and ZERO mutations ever executed. Here:
#
#   * the CONTROL is a SYNTHETIC throwaway git repository, green BY
#     CONSTRUCTION. No state of this repository can redden it, so no state of
#     this repository can silently switch the battery off.
#   * the LIVE run still happens FIRST, with the REAL entry point against the
#     REAL target, because a proof that only ever touches a sandbox while the
#     real gate cannot start is the other half of the same defect. It is
#     REPORTED, never gating.
#
# Mutations come in PAIRS wherever a suppression mechanism is involved: the
# planted violation must FAIL (rc 1), and the same violation with an allow-list
# entry must PASS (rc 0) while still NAMING what it suppressed. A suppression
# that is not shown to suppress something real proves nothing.
#
# Every byte written by this proof lands inside a `mktemp -d`. Nothing under the
# target repository is created, modified or removed, so no restore is needed.
# ------------------------------------------------------------------------------
if [[ "$MODE" == "prove" ]]; then
    # The literal is ASSEMBLED FROM FRAGMENTS on purpose. Written whole, this
    # very file would contain a machine-specific path and would trip the audit
    # it exercises — the proof would break the gate it proves.
    _u="/Users"
    SYN_PLANT="${_u}/proofuser/Projects/demo"

    echo "CM-HARDCODED-PATHS §1.1 PAIRED MUTATION PROOF"
    echo "----------------------------------------------------------------------"

    p_fails=0

    # ---- PRE-FLIGHT: the REAL entry point against the REAL tree -------------
    # Reported, never gating. Its job is to prove the instrument STARTS.
    pf_out="$(bash "$SELF_ABS" "$ROOT" 2>&1)"; pf_rc=$?
    case "$pf_rc" in
        0) printf '✅ %-26s the real audit ran against the real tree and returned rc=0 (clean)\n' "PRE-FLIGHT live-run" ;;
        1) printf 'ℹ %-26s the real audit RAN against the real tree and returned rc=1 (real\n' "PRE-FLIGHT live-run"
           printf '                           findings). REPORTED, NOT GATING: the battery below uses a\n'
           printf '                           synthetic control so a red tree cannot disable the proof.\n' ;;
        2) printf 'ℹ %-26s the real audit RAN and returned rc=2 (could not determine) on the\n' "PRE-FLIGHT live-run"
           printf '                           real tree. REPORTED, NOT GATING; the battery still runs.\n' ;;
        *) printf '❌ %-26s undocumented exit code %s; the contract is 0/1/2 only\n' "PRE-FLIGHT live-run" "$pf_rc"
           p_fails=$((p_fails+1)) ;;
    esac

    SB="$(mktemp -d "${TMPDIR:-/tmp}/hcpaths-proof.XXXXXX")" \
        || { echo "UNDET: cannot create a sandbox; the proof could not run" >&2; exit 2; }
    trap 'rm -rf "$SB"' EXIT INT TERM

    sgit() { git -c user.name=hc-proof -c user.email=hc-proof@invalid \
                 -c core.hooksPath=/dev/null -c init.defaultBranch=main "$@"; }

    # A repository with no machine-specific path anywhere, no .gitmodules, and
    # three tracked files. Green by construction. `git add` is enough: the audit
    # enumerates via `git ls-files`, which reads the INDEX, so no commit (and no
    # committer identity) is required.
    mk_control() {
        local d="$1"
        rm -rf "$d"; mkdir -p "$d/scripts" "$d/src" || return 1
        sgit -C "." init -q "$d" >/dev/null 2>&1 || return 1
        {
            printf '#!/usr/bin/env bash\n'
            printf 'ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"\n'
            printf 'echo "$ROOT"\n'
        } > "$d/scripts/tool.sh"
        printf 'package main\n\nfunc main() {}\n' > "$d/src/main.go"
        printf '# demo\n\nA synthetic repository used only as a proof control.\n' > "$d/README.md"
        sgit -C "$d" add -A >/dev/null 2>&1 || return 1
        return 0
    }

    # p_assert <label> <desc> <want-rc> <needle> <fn...>
    # The needle requirement is not decoration: a mutation that changes the exit
    # code without NAMING the offending thing is a weak proof, because its
    # reader cannot act on it (§11.4.6).
    p_assert() {
        local label="$1" desc="$2" want="$3" needle="$4"; shift 4
        local dir out rc slug
        slug="$(printf '%s' "$label" | tr -cd 'A-Za-z0-9')"
        dir="${SB}/mut_${slug}"
        rm -rf "$dir"
        if ! cp -r "$PRISTINE" "$dir"; then
            printf '❌ %-26s could not copy the control\n' "$label"; p_fails=$((p_fails+1)); return
        fi
        if ! "$@" "$dir"; then
            printf '❌ %-26s could not apply the mutation (%s)\n' "$label" "$desc"; p_fails=$((p_fails+1)); rm -rf "$dir"; return
        fi
        out="$(bash "$SELF_ABS" "$dir" 2>&1)"; rc=$?
        if [[ $rc -ne $want ]]; then
            printf '❌ %-26s %s\n' "$label" "$desc"
            printf '                           -> rc=%s, wanted %s. THIS GATE WOULD BE A SHAM (§1.1).\n' "$rc" "$want"
            printf '%s\n' "$out" | tail -6 | sed 's/^/        /'
            p_fails=$((p_fails+1)); rm -rf "$dir"; return
        fi
        if [[ -n "$needle" ]] && ! grep -qF -- "$needle" <<<"$out"; then
            printf '❌ %-26s %s\n' "$label" "$desc"
            printf '                           -> rc=%s as wanted, but the output never NAMED %s.\n' "$rc" "'$needle'"
            printf '%s\n' "$out" | tail -6 | sed 's/^/        /'
            p_fails=$((p_fails+1)); rm -rf "$dir"; return
        fi
        printf '✅ %-26s %s\n' "$label" "$desc"
        printf '                           -> rc=%s (wanted %s)%s\n' "$rc" "$want" "${needle:+  [names '$needle']}"
        rm -rf "$dir"
    }

    PRISTINE="${SB}/pristine"
    if ! mk_control "$PRISTINE"; then
        echo "UNDET: could not build the synthetic control repository" >&2; exit 2
    fi

    echo "  sandbox: ${SB}"
    echo "----------------------------------------------------------------------"

    out="$(bash "$SELF_ABS" "$PRISTINE" 2>&1)"; rc=$?
    if [[ $rc -eq 0 ]]; then
        printf '✅ %-26s unmutated synthetic repository passes (rc=0), by construction\n' "CONTROL synthetic-green"
    else
        printf '❌ %-26s returned rc=%s\n' "CONTROL synthetic-green" "$rc"
        printf '                           -> ABORTING: ZERO mutations ran, so NOTHING was proved. This is a\n'
        printf '                              fault in the proof harness, not a statement about this tree.\n'
        printf '%s\n' "$out" | tail -8 | sed 's/^/        /'
        exit 1
    fi

    # ---- the mutations -------------------------------------------------------
    plant()      { printf 'DATA_DIR="%s"\n' "$SYN_PLANT" >> "$1/scripts/tool.sh"; }
    plant_note() { printf '# historical bug: it used to say %s\n' "$SYN_PLANT" >> "$1/scripts/tool.sh"; }
    allow_reason()   { plant "$1" && printf '# REASON: synthetic, justified for the proof\nscripts/tool.sh\n'  > "$1/.hardcoded-paths-allow"; }
    allow_baseline() { plant "$1" && printf '# BASELINE: synthetic known-unfixed finding\nscripts/tool.sh\n'   > "$1/.hardcoded-paths-allow"; }
    allow_unmarked() { plant "$1" && printf '# just a comment, no marker at all\nscripts/tool.sh\n'            > "$1/.hardcoded-paths-allow"; }
    stale_baseline() { printf '# BASELINE: names a file that no longer offends\nsrc/main.go\n'                 > "$1/.hardcoded-paths-allow"; }
    # H11/H12: a URL is a REMOTE address. A path-shaped run inside one is not a
    # machine-specific path, and this audit really did report a research citation
    # whose vendor URL contains "/home/publications/". H11 proves the false
    # positive is gone; H12 proves the exemption did not become a hiding place --
    # a genuine literal on the SAME LINE as such a URL must still be caught, or
    # the fix would have handed anyone a one-line way to smuggle a path past it.
    plant_url()          { printf 'ref <https://example.invalid/home/publications/x>\n' >> "$1/scripts/tool.sh"; }
    plant_url_and_real() { printf 'ref <https://example.invalid/home/publications/x> DATA="%s"\n' "$SYN_PLANT" >> "$1/scripts/tool.sh"; }
    not_a_repo()     { rm -rf "$1/.git"; }
    no_such_dir()    { rm -rf "$1"; }
    empty_universe() { local d="$1"; rm -rf "$d"; mkdir -p "$d" && sgit -C "." init -q "$d" >/dev/null 2>&1; }
    uninit_sub()     {
        local d="$1"
        printf '[submodule "vendor/thing"]\n\tpath = vendor/thing\n\turl = git@github.com:someone/thing.git\n' > "$d/.gitmodules"
        printf 'schema_version: 1\ndeps:\n  - name: thing\n    ssh_url: git@github.com:someone/thing.git\n'    > "$d/helix-deps.yaml"
        mkdir -p "$d/vendor/thing" || return 1
        sgit -C "$d" add -A >/dev/null 2>&1 || true
        return 0
    }

    p_assert "H1 violation-caught"   "a machine-specific literal planted in a tracked script         " 1 "scripts/tool.sh"          plant
    p_assert "H2 REASON-suppresses"  "the SAME violation, allow-listed with '# REASON:'              " 0 "explicitly allowed"       allow_reason
    p_assert "H3 BASELINE-is-loud"   "the SAME violation, allow-listed with '# BASELINE:'            " 0 "baselined occurrence"     allow_baseline
    p_assert "H4 UNMARKED-is-named"  "allow-listed with no marker — honoured, but never in silence   " 0 "allow-list entr"          allow_unmarked
    p_assert "H5 stale-baseline"     "a BASELINE entry that no longer matches anything is reported   " 0 "stale baseline"           stale_baseline
    p_assert "H6 comment-not-a-bug"  "the literal in a COMMENT only — documenting it is not doing it " 0 "no machine-specific"      plant_note
    p_assert "H7 target-absent"      "the target directory does not exist — cannot be inspected      " 2 "no such directory"        no_such_dir
    p_assert "H8 not-a-git-tree"     "the target is not a git working tree — nothing to enumerate    " 2 "not a git working tree"   not_a_repo
    p_assert "H9 empty-universe"     "zero tracked files — a clean verdict over nothing is a bluff   " 2 "scan universe is empty"   empty_universe
    p_assert "H11 url-is-not-a-path" "a REMOTE URL whose path happens to contain /home/ — not local    " 0 "no machine-specific"     plant_url
    p_assert "H12 url-hides-nothing" "a real literal on the SAME LINE as such a URL is still caught    " 1 "scripts/tool.sh"         plant_url_and_real
    p_assert "H10 uninit-submodule"  "a declared submodule is not checked out — NOT a pass, NOT a fail" 2 "not initialised"         uninit_sub

    # ---- restored control ----------------------------------------------------
    bash "$SELF_ABS" "$PRISTINE" >/dev/null 2>&1; rc=$?
    if [[ $rc -eq 0 ]]; then
        printf '✅ %-26s the unmutated control is still green after the battery (rc=0)\n' "CONTROL restored"
    else
        printf '❌ %-26s the control no longer passes (rc=%s); a mutation leaked out of its copy\n' "CONTROL restored" "$rc"
        p_fails=$((p_fails+1))
    fi

    echo "----------------------------------------------------------------------"
    if [[ $p_fails -eq 0 ]]; then
        echo "✅ CM-HARDCODED-PATHS §1.1 MUTATION PROOF: PASS — the REAL entry point ran against"
        echo "   the REAL tree (reported, never gating), a SYNTHETIC control green by construction"
        echo "   passed, and 10 mutations each produced the required THREE-VALUED verdict while"
        echo "   NAMING the offending thing: a planted violation as rc=1; three suppression"
        echo "   mechanisms as rc=0 that still name what they suppressed; a comment-only mention"
        echo "   correctly ignored; and four could-not-determine states as rc=2 — never as a pass"
        echo "   and never as an accusation. The control is still green."
        exit 0
    fi
    echo "❌ CM-HARDCODED-PATHS §1.1 MUTATION PROOF: FAIL — ${p_fails} case(s) did not behave as required"
    exit 1
fi

ALLOW_FILE="$ROOT/.hardcoded-paths-allow"

# Machine-specific roots. NOT included: /etc, /usr, /opt, /var, /tmp — those are
# standard system locations, not somebody's home directory.
PATTERN='(/Volumes/|/Users/[A-Za-z]|/home/[A-Za-z][A-Za-z0-9_.-]*/|/run/media/[A-Za-z]|/mnt/[A-Za-z][A-Za-z0-9_.-]*/)'

# Generated evidence is not source. Applied to each repository's OWN relative
# paths, so `<submodule>/_content/...` is skipped for the same reason
# `_content/...` is skipped here.
#
# THE `docs/` BLIND SPOT — REMOVED 2026-09-02, operator decision 20
# -----------------------------------------------------------------
# This list used to begin `^(docs/|...`, on the reasoning "prose legitimately
# quotes real paths". The reasoning was not wrong; the CONSEQUENCE was. Because
# SKIP is applied BEFORE `PATTERN`, `docs/**` was never read at all — measured
# on 2026-09-02, ZERO of the 39 tracked `docs/**.md` files at this root entered
# the scan universe. A real disclosure sat in one of them, on two lines that
# BOTH match this file's own `PATTERN`, for as long as it took somebody to look
# by hand. The detector was right; the scope was wrong.
#
# `docs/` is therefore gone from this list and MUST NOT be put back. What
# surfaced when it was removed is enumerated FILE BY FILE in
# `.hardcoded-paths-allow` — a blanket regex hides an unbounded future
# population, a named file does not, and a docs file added tomorrow with a
# machine-specific path FAILS this gate instead of being skipped in silence.
#
# The other entries here are NOT equivalent to it and are deliberately kept:
# `_content*` and `*/evidence/` are GENERATED trees (renderer output, captured
# run transcripts) rather than authored documentation, and `.superpowers/` and
# `.ashlrcode/` are third-party tool state this repository does not author.
# If one of them is ever shown to hide a disclosure the same way, it goes too.
SKIP='^(_content|_analysis|_tests/evidence/|\.test-evidence/|\.superpowers/|\.ashlrcode/|MANUAL-STEPS\.md)'

# Known-binary: never read. Known-text: always read, whatever the size.
# Anything else is read only below MAXBYTES, and is otherwise reported as
# not-scanned (in this fleet those are ELF binaries with no extension).
BIN_EXT='\.(png|jpe?g|gif|webp|ico|bmp|tiff?|pdf|docx?|pptx?|xlsx?|odt|woff2?|ttf|otf|eot|zip|gz|tgz|bz2|xz|7z|rar|mp4|mov|avi|mkv|webm|mp3|wav|flac|so|dylib|dll|exe|bin|jar|class|wasm|pyc|db|sqlite3?|part-[0-9][0-9]*)$'
TEXT_EXT='\.(md|markdown|html?|txt|json|jsonl|js|mjs|cjs|ts|tsx|jsx|css|scss|less|go|py|rb|sh|bash|zsh|fish|yml|yaml|toml|cfg|conf|ini|xml|svg|csv|tsv|sql|mmd|gradle|kts?|java|c|h|cc|cpp|hpp|rs|php|pl|lua|tf|env|properties|mod|sum|lock|sha256|gitignore|gitattributes|gitmodules|editorconfig|disabled|template|patch|diff|spec|list|log|rules|service|desktop)$'
MAXBYTES=1048576

# ---- the submodule fleet -----------------------------------------------------
# DERIVED from .gitmodules; ownership DERIVED from helix-deps.yaml. No list of
# submodule names appears anywhere in this file.
#
# WHY `submodules/constitution` IS TREATED AS OWNED
# -------------------------------------------------
# It is declared in `helix-deps.yaml` `deps[]` with an own-org `ssh_url`
# (HelixDevelopment/HelixConstitution), and that declared set IS the ownership
# rule here. Carving it out by name would re-introduce exactly the hardcoded
# list this sweep exists to avoid — a hardcoded list of one — and would fork the
# ownership model that cascade check C6 guards in both directions. It is also
# the tree's governance source: a machine-specific path inside it is a real
# defect that this repository consumes on every session, so "police it" is the
# honest answer. The consequence is stated rather than hidden: this repository
# cannot FIX such a finding here (§11.4.28 / §11.4.177 — inherited by reference,
# never copied); the fix lands upstream in HelixConstitution and returns as a
# gitlink bump. Until it does, the finding is carried as an enumerated baseline
# in `.hardcoded-paths-allow`, and a bump that introduces a NEW one turns this
# gate red — which is the intended, if inconvenient, behaviour.
FLEET_OWNED=""      # newline-separated submodule paths
FLEET_THIRD=""      # newline-separated "path<TAB>url"
FLEET_UNINIT=""     # newline-separated "path<TAB>reason"
FLEET_UNCLASSED=""  # gitlinks present but not classifiable from this checkout

if [[ "$SWEEP" == "1" && -r "$ROOT/.gitmodules" ]]; then
    _paths="$(git config -f "$ROOT/.gitmodules" --get-regexp 'submodule\..*\.path' 2>/dev/null | awk '{print $2}')"
    if [[ -n "$_paths" ]]; then
        if [[ -r "$ROOT/helix-deps.yaml" ]]; then
            _owned_urls="$(sed -n -E 's/^[[:space:]]*ssh_url:[[:space:]]*(.+)$/\1/p' \
                           "$ROOT/helix-deps.yaml" 2>/dev/null | tr -d '\r' | sort -u)"
            while IFS= read -r _p; do
                [[ -n "$_p" ]] || continue
                if [[ ! -e "$ROOT/$_p/.git" ]] \
                   || ! git -C "$ROOT/$_p" rev-parse --git-dir >/dev/null 2>&1; then
                    FLEET_UNINIT="${FLEET_UNINIT}${_p}	not initialised (no usable .git)"$'\n'
                    continue
                fi
                _url="$(git config -f "$ROOT/.gitmodules" --get "submodule.${_p}.url" 2>/dev/null || echo '')"
                if [[ -n "$_url" ]] && ! grep -qxF "$_url" <<<"$_owned_urls"; then
                    FLEET_THIRD="${FLEET_THIRD}${_p}	${_url}"$'\n'
                else
                    FLEET_OWNED="${FLEET_OWNED}${_p}"$'\n'
                fi
            done <<< "$_paths"
        else
            FLEET_UNCLASSED="$_paths"
        fi
    fi
fi

# ---- collect the scan universe ----------------------------------------------
TMPDIR_SAFE="${TMPDIR:-/tmp}"
WORK="$(mktemp -d "${TMPDIR_SAFE%/}/audit-hcpaths.XXXXXX")" \
    || { echo "FATAL: cannot create a temporary directory" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT INT TERM

repo_candidates() {   # $1 = repo path relative to $ROOT ("" = the root itself)
    local rel="$1" dir="$ROOT" pfx=""
    if [[ -n "$rel" ]]; then dir="$ROOT/$rel"; pfx="$rel/"; fi
    git -C "$dir" ls-files 2>/dev/null | grep -vE "$SKIP" | awk -v p="$pfx" '$0 != "" {print p $0}'
}

: > "$WORK/cand.txt"
repo_candidates "" >> "$WORK/cand.txt"

SWEPT=0
SWEPT_PATHS=""
while IFS= read -r _p; do
    [[ -n "$_p" ]] || continue
    repo_candidates "$_p" >> "$WORK/cand.txt"
    SWEPT=$((SWEPT+1)); SWEPT_PATHS="${SWEPT_PATHS}${_p}"$'\n'
done <<< "$FLEET_OWNED"

THIRD_PATHS=""
while IFS= read -r _row; do
    [[ -n "$_row" ]] || continue
    _p="${_row%%	*}"
    THIRD_PATHS="${THIRD_PATHS}${_p}"$'\n'
    repo_candidates "$_p" >> "$WORK/cand.txt"
    SWEPT=$((SWEPT+1)); SWEPT_PATHS="${SWEPT_PATHS}${_p}"$'\n'
done <<< "$FLEET_THIRD"

# ---- filter to readable, scannable files ------------------------------------
# Batched passes on purpose. Testing each path with its own `grep` cost 70 s
# over the ~5 900-file fleet; three whole-list greps plus a builtin-only loop
# cost well under a second, and only the handful of unknown-extension files
# ever need a size probe.
grep -viE "$BIN_EXT" "$WORK/cand.txt" > "$WORK/cand2.txt" || true
grep -iE  "$TEXT_EXT" "$WORK/cand2.txt" > "$WORK/known.txt" || true
grep -viE "$TEXT_EXT" "$WORK/cand2.txt" > "$WORK/unknown.txt" || true

: > "$WORK/notscanned.txt"
: > "$WORK/unknown.keep"
while IFS= read -r f; do
    [[ -n "$f" ]] || continue
    [[ -f "$ROOT/$f" ]] || continue
    sz="$(wc -c < "$ROOT/$f" 2>/dev/null | tr -d ' ')"
    [[ -n "$sz" ]] || sz=0
    if [[ "$sz" -gt "$MAXBYTES" ]]; then
        printf '%s (%s bytes, unknown extension)\n' "$f" "$sz" >> "$WORK/notscanned.txt"
        continue
    fi
    printf '%s\n' "$f" >> "$WORK/unknown.keep"
done < "$WORK/unknown.txt"

: > "$WORK/files.txt"
while IFS= read -r f; do
    [[ -n "$f" ]] || continue
    [[ -f "$ROOT/$f" ]] || continue          # drops gitlinks and deleted files
    [[ -r "$ROOT/$f" ]] || continue
    printf '%s\n' "$f"
done < <(cat "$WORK/known.txt" "$WORK/unknown.keep") > "$WORK/files.txt"

FILE_COUNT=$(grep -c . "$WORK/files.txt" || true)

# Breakdown counts the SCANNED universe, not the candidate list, so the table
# and the verdict can never describe different populations.
: > "$WORK/breakdown.txt"
_rootn=$(grep -c . "$WORK/files.txt" || true)
while IFS= read -r _p; do
    [[ -n "$_p" ]] || continue
    _c=$(grep -c "^$_p/" "$WORK/files.txt" || true)
    _rootn=$((_rootn - _c))
done <<< "$SWEPT_PATHS"
printf '%-34s %7s  %s\n' "(umbrella root)" "$_rootn" "self" >> "$WORK/breakdown.txt"
while IFS= read -r _p; do
    [[ -n "$_p" ]] || continue
    printf '%-34s %7s  %s\n' "$_p" "$(grep -c "^$_p/" "$WORK/files.txt" || true)" "OWNED" \
        >> "$WORK/breakdown.txt"
done <<< "$FLEET_OWNED"
while IFS= read -r _row; do
    [[ -n "$_row" ]] || continue
    _p="${_row%%	*}"
    printf '%-34s %7s  %s\n' "$_p" "$(grep -c "^$_p/" "$WORK/files.txt" || true)" \
        "THIRD-PARTY (reported, not enforced)" >> "$WORK/breakdown.txt"
done <<< "$FLEET_THIRD"
while IFS= read -r _row; do
    [[ -n "$_row" ]] || continue
    printf '%-34s %7s  %s\n' "${_row%%	*}" "-" "NOT INITIALISED — could not determine" \
        >> "$WORK/breakdown.txt"
done <<< "$FLEET_UNINIT"

if [[ "$MODE" == "list" ]]; then
    cat "$WORK/files.txt"
    echo "────────────────────────────────────────────────────────"
    cat "$WORK/breakdown.txt"
    printf -- '---- %s file(s) in the scan universe\n' "$FILE_COUNT"
    exit 0
fi

# ANTI-BLUFF: a gate that finds nothing because it looked at nothing is the
# empty-build success this project has already been burned by.
if [[ "$FILE_COUNT" -eq 0 ]]; then
    echo "FATAL: scan universe is empty — refusing to report a clean tree over" >&2
    echo "       zero files. Check the SKIP filter or the target repository." >&2
    exit 2
fi

# ANTI-BLUFF (regression guard for the gitlink blind spot this fix closed):
# if submodules were swept and contributed NOTHING, the sweep is broken again.
if [[ "$SWEPT" -gt 0 ]]; then
    SUB_ONLY=0
    while IFS= read -r _p; do
        [[ -n "$_p" ]] || continue
        _c=$(grep -c "^$_p/" "$WORK/files.txt" || true)
        SUB_ONLY=$((SUB_ONLY + _c))
    done <<< "$SWEPT_PATHS"
    if [[ "$SUB_ONLY" -eq 0 ]]; then
        echo "FATAL: $SWEPT submodule(s) were swept and contributed ZERO files." >&2
        echo "       That is the exact signature of the gitlink blind spot this" >&2
        echo "       sweep exists to close. Refusing to report a verdict." >&2
        exit 2
    fi
fi

# ---- allow-list --------------------------------------------------------------
# Each entry is one repository-relative path. The comment block directly above
# it carries the reason. Two kinds, following the convention the sibling gate
# `scripts/audit-environment-assumptions.sh` established:
#
#   # REASON:   <why this literal is genuinely justified>   -> silent, counted
#   # BASELINE: <known, unfixed finding + where it is filed> -> PRINTED LOUDLY
#
# The markers are ADVISORY here, not fatal, on purpose: `scripts/test-setup-
# agents-wizard.sh` case J6 asserts that a plain `# comment` + path still
# suppresses, and that file is not this change's to edit. An entry with no
# marker is therefore honoured AND named in an advisory warning, so the list
# still cannot grow unexplained entries in silence.
: > "$WORK/allow.tsv"
: > "$WORK/allow.unmarked"
if [[ -f "$ALLOW_FILE" ]]; then
    awk '
        { line = $0 }
        line ~ /^[[:space:]]*$/ { kind = ""; next }
        line ~ /^[[:space:]]*#/ {
            if (line ~ /BASELINE:/)    kind = "BASELINE"
            else if (line ~ /REASON:/) kind = "REASON"
            next
        }
        {
            # The marker carries across a CONTIGUOUS run of paths, so one
            # reason can cover a group; a blank line ends the group. (The
            # sibling gate resets after every rule because its rules are
            # individually class-scoped; here a rule is just a path.)
            p = line
            sub(/^[[:space:]]+/, "", p)
            sub(/[[:space:]]+$/, "", p)
            if (p == "") next
            printf "%s\t%s\n", (kind == "") ? "UNMARKED" : kind, p
        }
    ' "$ALLOW_FILE" > "$WORK/allow.tsv"
    grep '^UNMARKED	' "$WORK/allow.tsv" | cut -f2 > "$WORK/allow.unmarked" || true
fi

allow_kind() {   # echoes REASON|BASELINE|UNMARKED, or nothing when not allowed
    [[ -s "$WORK/allow.tsv" ]] || return 1
    awk -F'\t' -v want="$1" '$2 == want { print $1; found = 1; exit } END { exit !found }' "$WORK/allow.tsv"
}

# ---- the scan ----------------------------------------------------------------
# ONE awk process over the whole fleet. The previous implementation ran two
# subprocesses PER FILE; at 491 root files that cost 3.5 s, and the fleet is
# ~5 000 files. No GNU-only awk extensions are used.
AWK_PROG='
FNR == 1 {
    name = FILENAME
    sub(/\.disabled$/, "", name)
    sub(/\.disabled-local-only$/, "", name)
    base = name
    sub(/^.*\//, "", base)
    style = 0
    if (name ~ /\.(py|sh|bash|yml|yaml|toml|cfg|conf)$/)      style = 1
    else if (name ~ /\.(js|mjs|cjs|ts|go|java|c|h)$/)         style = 2
    # Extensionless hash-comment formats. Without these, the allow-lists own
    # comment blocks - which must be able to QUOTE the literals they are about -
    # trip the very audit they configure.
    else if (base == ".hardcoded-paths-allow" ||
             base == ".environment-assumptions-allow" ||
             base == ".gitignore" || base == ".dockerignore" ||
             base ~ /^Dockerfile/ || base ~ /^Containerfile/ ||
             base == "Makefile" || base ~ /\.mk$/ ||
             base ~ /^\.env/)                                 style = 1
}
{
    if (style == 1 && $0 ~ /^[[:space:]]*#/) next
    if (style == 2 && $0 ~ /^[[:space:]]*(\/\/|\*|\/\*)/) next
    # A path-shaped substring INSIDE a URL is not a machine-specific path, and
    # treating one as a finding is a false positive this audit actually produced:
    # a research citation whose vendor URL contains "/home/publications/" was
    # reported as somebody home directory. Nothing on a remote host can be a
    # local path, so URL tokens are blanked BEFORE the pattern is applied.
    # The probe is a COPY -- the excerpt printed below is still the ORIGINAL
    # line, because a reader has to see what was actually written.
    probe = $0
    gsub(/[a-zA-Z][a-zA-Z0-9+.-]*:\/\/[^[:space:]<>)\]"]*/, " ", probe)
    if (probe ~ pat) {
        # The record is TAB-separated and the excerpt is its last field, so any
        # TAB inside the source line would split it and print an empty excerpt.
        # Go and Makefile sources are TAB-indented, so this is not theoretical:
        # it printed blank excerpts for every hit in submodules/containers.
        txt = $0
        gsub(/\t/, " ", txt)
        printf "HIT\t%s\t%d\t%s\n", FILENAME, FNR, txt
    }
}
'

FILES=()
while IFS= read -r f; do
    [[ -n "$f" ]] || continue
    FILES+=("$f")
done < "$WORK/files.txt"

# Quoted array expansion, NOT `$(cat ...)`: `workshop/` tracks filenames that
# contain spaces, and word-splitting them silently scanned the wrong paths.
LC_ALL=C awk -v pat="$PATTERN" "$AWK_PROG" "${FILES[@]}" > "$WORK/hits.tsv" 2>"$WORK/awk.err"
AWK_RC=$?
if [[ $AWK_RC -ne 0 ]]; then
    echo "FATAL: the scan itself failed (awk rc=$AWK_RC)" >&2
    sed 's/^/       /' "$WORK/awk.err" >&2
    exit 2
fi

# ---- report ------------------------------------------------------------------
is_third_party() {   # $1 = scan path; echoes the owning third-party submodule
    local f="$1" p
    while IFS= read -r p; do
        [[ -n "$p" ]] || continue
        case "$f" in "$p"/*) printf '%s' "$p"; return 0 ;; esac
    done <<< "$THIRD_PATHS"
    return 1
}

violations=0; files_hit=0; allowed=0; baselined=0; note_files=0; note_hits=0
: > "$WORK/baselined.txt"
: > "$WORK/notes.txt"
: > "$WORK/fired.txt"

cut -f2 "$WORK/hits.tsv" | awk '!seen[$0]++' > "$WORK/hitfiles.txt"

while IFS= read -r f; do
    [[ -n "$f" ]] || continue
    n=$(awk -F'\t' -v f="$f" '$2 == f' "$WORK/hits.tsv" | grep -c . || true)

    kind="$(allow_kind "$f" || true)"
    if [[ -n "$kind" ]]; then
        printf '%s\n' "$f" >> "$WORK/fired.txt"
        if [[ "$kind" == "BASELINE" ]]; then
            baselined=$((baselined+n))
            printf '%s (%s occurrence(s))\n' "$f" "$n" >> "$WORK/baselined.txt"
        else
            allowed=$((allowed+1))
            printf "${YELLOW}⚠️  allowed${NC} %s\n" "$f"
        fi
        continue
    fi

    if tp="$(is_third_party "$f")"; then
        note_files=$((note_files+1)); note_hits=$((note_hits+n))
        printf '%s  [third-party: %s]  (%s occurrence(s))\n' "$f" "$tp" "$n" >> "$WORK/notes.txt"
        awk -F'\t' -v f="$f" '$2 == f { printf "     %s:%s\n", $3, $4 }' "$WORK/hits.tsv" \
            | head -3 >> "$WORK/notes.txt"
        continue
    fi

    files_hit=$((files_hit+1))
    violations=$((violations+n))
    printf "${RED}❌ %s${NC}  (%s occurrence(s))\n" "$f" "$n"
    awk -F'\t' -v f="$f" '$2 == f { printf "     %s:%s\n", $3, $4 }' "$WORK/hits.tsv" | head -3
done < "$WORK/hitfiles.txt"

echo "────────────────────────────────────────────────────────"
printf '%sscanned %d file(s) across %d repositor%s%s\n' \
    "$DIM" "$FILE_COUNT" "$((SWEPT+1))" "$([[ $((SWEPT+1)) -eq 1 ]] && echo y || echo ies)" "$NC"

if [[ -s "$WORK/notscanned.txt" ]]; then
    printf '%sNOT SCANNED — unknown extension and larger than %s bytes:%s\n' "$YELLOW" "$MAXBYTES" "$NC"
    sed 's/^/     /' "$WORK/notscanned.txt"
fi

if [[ -s "$WORK/allow.unmarked" ]]; then
    printf '%s⚠️  allow-list entr(ies) with no "# REASON:"/"# BASELINE:" marker:%s\n' "$YELLOW" "$NC"
    sed 's/^/     /' "$WORK/allow.unmarked"
    printf '%s   They are honoured, but an unexplained suppression is a bluff.%s\n' "$YELLOW" "$NC"
fi

# Baselines are PRINTED ON EVERY RUN, clean or not. A tree must never go quietly
# green over known breakage.
if [[ "$baselined" -gt 0 ]]; then
    printf '%s⚠️  %d baselined occurrence(s) — REAL, KNOWN, UNFIXED findings in:%s\n' \
        "$YELLOW" "$baselined" "$NC"
    sort "$WORK/baselined.txt" | sed 's/^/     /'
    printf '%s   A baseline is recorded DEBT, not a justification. It is scoped to%s\n' "$YELLOW" "$NC"
    printf '%s   the named FILE, so a new violation in a new file still fails.%s\n' "$YELLOW" "$NC"
fi

# A baseline that no longer fires is rot: it hides the next real finding.
if [[ -s "$WORK/allow.tsv" ]]; then
    STALE="$(awk -F'\t' '$1 == "BASELINE" { print $2 }' "$WORK/allow.tsv" \
             | while IFS= read -r b; do
                   [[ -n "$b" ]] || continue
                   grep -qxF "$b" "$WORK/fired.txt" 2>/dev/null || printf '%s\n' "$b"
               done)"
    if [[ -n "$STALE" ]]; then
        printf '%s⚠️  stale baseline(s) — listed but no longer matching anything:%s\n' "$YELLOW" "$NC"
        printf '%s\n' "$STALE" | sed 's/^/     /'
        printf '%s   Remove them; a dead entry silences the next real finding.%s\n' "$YELLOW" "$NC"
    fi
fi

if [[ -s "$WORK/notes.txt" ]]; then
    printf '%sNOTE — machine-specific path(s) in THIRD-PARTY gitlink(s): %d occurrence(s)%s\n' \
        "$YELLOW" "$note_hits" "$NC"
    printf '%sOUT OF SCOPE per §11.4.156(C) / §11.4.29 — reported so they are never%s\n' "$YELLOW" "$NC"
    printf '%ssilently omitted; NOT edited here, NOT a failure of this tree:%s\n' "$YELLOW" "$NC"
    sed 's/^/  /' "$WORK/notes.txt"
fi

if [[ -n "$FLEET_UNCLASSED" ]]; then
    printf '%sNOT SWEPT — gitlink(s) declared here, but this checkout ships no%s\n' "$YELLOW" "$NC"
    printf '%shelix-deps.yaml, so ownership cannot be derived and is not guessed:%s\n' "$YELLOW" "$NC"
    printf '%s\n' "$FLEET_UNCLASSED" | sed 's/^/     /'
fi

if [[ -n "$FLEET_UNINIT" ]]; then
    printf '%s⚠️  COULD NOT DETERMINE — submodule(s) not initialised:%s\n' "$RED" "$NC"
    printf '%s' "$FLEET_UNINIT" | sed 's/\t/: /' | sed 's/^/     /'
    printf '%s   Their contents are unknown. This is NOT a pass and NOT a failure.%s\n' "$RED" "$NC"
    echo   "   Run: git submodule update --init --recursive"
    if [[ "$violations" -gt 0 ]]; then
        printf "${RED}❌ %d occurrence(s) across %d file(s) in owned repositories%s\n" \
            "$violations" "$files_hit" "$NC"
    fi
    exit 2
fi

if [[ $violations -eq 0 ]]; then
    printf "${GREEN}✅ no machine-specific hardcoded paths${NC}"
    [[ $allowed -gt 0 ]] && printf " (%d file(s) explicitly allowed)" "$allowed"
    echo
    exit 0
fi
printf "${RED}❌ %d occurrence(s) across %d file(s)${NC}\n" "$violations" "$files_hit"
echo
echo "Derive the path instead of writing it:"
echo "  bash    ROOT=\"\$(cd -- \"\$(dirname -- \"\${BASH_SOURCE[0]}\")/..\" && pwd)\""
echo "  python  pathlib.Path(__file__).resolve().parents[N]"
echo "  node    path.resolve(__dirname, '..')"
echo
echo "A finding inside a submodule is fixed INSIDE that submodule, then the"
echo "gitlink bump is committed here. Do not edit a submodule from this tree."
echo
echo "If an occurrence is genuinely unavoidable, add the file to"
echo "  .hardcoded-paths-allow   (with a '# REASON:' or '# BASELINE:' line above it)"
exit 1
