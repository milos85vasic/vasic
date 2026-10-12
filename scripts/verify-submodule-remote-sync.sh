#!/usr/bin/env bash
# CM-SUBMODULE-REMOTE-SYNC — is each gitlink CURRENT with the repository it
# points at, or has upstream moved on without us?
#
# ── Why this gate exists ─────────────────────────────────────────────────────
# It closes a measured blind spot, not a hypothetical one. Cascade check C9 and
# scripts/verify-manifest-pins.sh both answer the question "does helix-deps.yaml
# agree with the gitlink this repository will commit?" — a purely LOCAL
# comparison. Neither has ever contacted a remote; on 2026-09-01 a grep for
# `ls-remote` / `git fetch` across scripts/*.sh returned nothing at all. So the
# two of them exited 0 all day while submodules/constitution sat three commits
# behind its upstream, and the umbrella's own carrier had to warn readers in
# prose that "the pin is BEHIND its upstream, and no gate in this tree catches
# that". Prose is not a gate. This is the gate.
#
# The distinction the two instruments draw is worth stating plainly, because
# they are easy to mistake for each other:
#
#   verify-manifest-pins.sh (C9)   manifest ref  ==  local gitlink   (RECORD)
#   this gate                      local gitlink ==  remote tip      (FRESHNESS)
#
# Both can be green while the tree is stale, and only together do they mean
# "what we recorded is what we will commit, and what we will commit is what
# upstream actually has". Neither subsumes the other and neither is deleted.
#
# ── What it compares, and against which ref ──────────────────────────────────
# LOCAL side: the INDEX gitlink, `git ls-files -s -- <path>`. Deliberately the
# same choice verify-manifest-pins.sh made and for the same reason — it is the
# commit this repository is about to commit, so a freshly staged bump is judged
# as staged rather than as the older HEAD value.
#
# REMOTE side: `git ls-remote <url> <ref>`, where <ref> is
#   * refs/heads/<branch>  when .gitmodules declares `branch = <branch>` for
#     that submodule — the operator said which line to track, so track it;
#   * HEAD otherwise, which is the remote's default branch.
# Measured 2026-09-01: this repository declares no `branch` for any of its 13
# gitlinks, so every comparison today is against HEAD. The branch path is
# implemented anyway rather than assumed away — an assumption about the fleet's
# shape is exactly the frozen-assumption defect these gates keep being bitten by.
#
# ── behind / ahead / diverged are NOT the same finding ───────────────────────
# Reporting them identically would be a conflation: they have different
# remedies, and one of them is not even ours to fix.
#   BEHIND    upstream is strictly ahead; our pin is fast-forwardable.
#             Remedy: bump the gitlink (and then the manifest ref).
#   AHEAD     we hold commits upstream does not. Remedy: push them. A gitlink
#             pointing at an unpushed commit is unclonable for everyone else,
#             which is a worse failure than being stale.
#   DIVERGED  both sides moved. Remedy: operator reconciliation. Never automate.
# Direction is decided with `merge-base --is-ancestor` inside the submodule's
# own object database, which requires BOTH commits to be present locally. When
# the remote commit is not in the local object store the SHAs are still known to
# differ — that much is determined — but the direction is not, and the gate says
# so in those words instead of guessing a remedy. See --fetch below.
#
# ── Ownership is classified from evidence, never from a name list ────────────
# A hardcoded roster is the same defect class this gate exists to catch, so the
# fleet is DERIVED on every run from `.gitmodules` (paths + urls) and
# `helix-deps.yaml` (recorded deps, and the trailing comment block in which
# third-party gitlinks are documented). The classification rule:
#   * a path documented in the manifest's exclusion block is THIRD-PARTY;
#   * every other declared gitlink is OWNED.
# Third-party modules are probed and REPORTED but never gate: upstream's release
# cadence is not ours to fix, and failing a push because a vendor tagged a
# release would train everyone to bypass the hook. Measured 2026-09-01: that
# rule classifies submodules/superspec third-party and the other 12 owned,
# without this script containing either name.
#
# ── Exit codes (three-valued; 2 IS NEVER A PASS) ─────────────────────────────
#   0 — every OWNED gitlink was compared against its remote and is CURRENT.
#   1 — at least one OWNED gitlink was compared and DIFFERS (behind, ahead or
#       diverged). A real, determined finding.
#   2 — COULD NOT DETERMINE for at least one OWNED gitlink: no network, DNS
#       failure, SSH auth refused, the remote repository gone or renamed, the
#       probe timing out, git absent, or a declared gitlink with no url.
#
# State 2 OUTRANKS state 1, the same precedence verify-governance-cascade.sh and
# verify-manifest-pins.sh use. The reason is the whole point of this file: a run
# that could not see every remote must not be read as a complete verdict. THE
# ONE FAILURE MODE THIS GATE MUST NEVER HAVE IS REPORTING A NETWORK FAILURE AS
# "CURRENT" — that would replace the old blind instrument with a new one wearing
# a fresher name. Every unreachable remote is state 2 and is printed; findings
# already determined are printed alongside it rather than being suppressed.
#
# ── Usage ────────────────────────────────────────────────────────────────────
#   scripts/verify-submodule-remote-sync.sh [--root <dir>] [--quiet]
#                                           [--timeout <seconds>] [--fetch]
#   scripts/verify-submodule-remote-sync.sh --prove-failure [--quiet]
#     --root <dir>     project root to verify (default: this script's parent).
#     --quiet          suppress the table and PASS lines. Findings, ENV and the
#                      summary are ALWAYS shown.
#     --timeout <n>    seconds per remote probe (default 45). A probe that times
#                      out is state 2, never a pass.
#     --fetch          OPT-IN. Before classifying direction, fetch the single
#                      remote commit into the submodule's object store so
#                      behind/ahead/diverged can be decided precisely. Off by
#                      default because the default mode of this gate is strictly
#                      read-only. Even with --fetch nothing is checked out, no
#                      ref is updated and no working tree is touched: it is
#                      `git fetch --no-write-fetch-head --no-tags <url> <sha>`,
#                      which writes objects and nothing else.
#     --prove-failure  run the paired §1.1 mutation proof (see the bottom).
#     -h|--help        this header.
#
# ── Side-effects ─────────────────────────────────────────────────────────────
#   Default mode: READ-ONLY, and network-reading. It runs `git ls-remote`, which
#   contacts each remote but writes nothing anywhere. No working tree, index,
#   ref or config is modified; `git submodule update` is never run.
#   --fetch: writes loose objects into submodule object stores. Nothing else.
#   --prove-failure: writes ONLY inside a `mktemp -d` sandbox, trap-removed, and
#   makes NO network calls at all.
#
# ── Dependencies ─────────────────────────────────────────────────────────────
#   bash, git, POSIX awk/grep/sed/sort. `timeout` is used when present and its
#   absence is REPORTED rather than silently ignored — without it a hung probe
#   would stall the gate instead of returning state 2.
#
# ── Honest boundaries (§11.4.6) ──────────────────────────────────────────────
#   1. `git ls-remote` reports the remote's tip AT THIS MOMENT. A green verdict
#      is a dated observation with a shelf life of seconds, not a standing fact.
#      That is inherent to the question and is why the gate re-measures rather
#      than caching.
#   2. Without --fetch, direction is only decidable when the remote commit
#      already exists locally. Otherwise the gate reports DIFFERS with the
#      direction explicitly undetermined. It never guesses a remedy.
#   3. It says nothing about whether the remote tip is a GOOD commit, only that
#      it is not the one we point at.
#   4. It compares against ONE ref per submodule (the declared branch, else
#      HEAD). A commit living only on some other branch is invisible to it, by
#      design — that is the operator's declaration doing its job.
#   6. (VSC-360) `origin` may PUSH to repositories other than the one it fetches from
#      (`remote.origin.pushurl`, read from the checked-out submodule). Each distinct push
#      target is probed with the same ref and compared with the same gitlink; a push target
#      that lags is DRIFT, one that cannot be read is state 2, one that is current is a PASS.
#      A submodule that is not checked out has no readable pushurl: that is a NOTE, because
#      the information does not exist in this checkout, and the fetch URL is then the only
#      remote compared. Credentials embedded in an http(s) URL are masked in every message.
#   5. Third-party modules never gate. If that is ever wrong for a given vendor,
#      the remedy is to stop documenting it as third-party in the manifest, not
#      to special-case it here.
# ─────────────────────────────────────────────────────────────────────────────

set -uo pipefail

GATE="CM-SUBMODULE-REMOTE-SYNC"

# ── INTERNAL-FAULT TRAP: a crash is rc=2, never rc=1 ─────────────────────────
# Same reasoning as the sibling gates. `set -u` aborts with status 1, the code
# reserved here for a REAL finding, so a broken instrument would accuse a
# healthy tree. Every deliberate rc=1 path sets _verdict_emitted first.
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
probe_timeout=45
do_fetch=""
prove=""

while [ $# -gt 0 ]; do
    case "$1" in
        --root)    root="${2:-}"; shift 2 ;;
        --quiet)   quiet="1"; shift ;;
        --timeout) probe_timeout="${2:-}"; shift 2 ;;
        --fetch)   do_fetch="1"; shift ;;
        --prove-failure) prove="1"; shift ;;
        -h|--help) awk 'NR==1{next} /^#/{sub(/^# ?/,""); print; next} {exit}' "$0"; exit 0 ;;
        -*) echo "${GATE}: unknown arg '$1'" >&2; exit 2 ;;
        *)  if [ -n "$root" ]; then
                echo "${GATE}: more than one target root given ('${root}', '$1')" >&2; exit 2
            fi
            root="$1"; shift ;;
    esac
done

case "$probe_timeout" in
    ''|*[!0-9]*) echo "${GATE}: --timeout must be a whole number of seconds, got '${probe_timeout}'" >&2; exit 2 ;;
esac

[ -n "$root" ] || root="${REPO_ROOT}"
[ -d "$root" ] || { echo "${GATE}: project root not found: '${root}'" >&2; exit 2; }
root="$(cd "$root" && pwd -P)"

MANIFEST_NAME="helix-deps.yaml"

pass=0; fail=0; undet=0; note=0
ok()   { pass=$((pass+1));   [ -n "$quiet" ] || echo "✅ PASS  $1"; }
bad()  { fail=$((fail+1));   echo "❌ DRIFT $1"; }
und()  { undet=$((undet+1)); echo "⚠ UNDET $1"; }
inf()  { note=$((note+1));   [ -n "$quiet" ] || echo "ℹ NOTE  $1"; }

# ── Never let a probe block on a credential prompt ───────────────────────────
# Without these an unauthenticated run does not fail — it HANGS waiting for a
# password on a terminal nobody is watching, which in a pre-push hook is
# indistinguishable from the gate being slow. Batch mode converts that into a
# prompt refusal, which the caller turns into state 2.
export GIT_TERMINAL_PROMPT=0
export GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10}"

HAVE_TIMEOUT=""
command -v timeout >/dev/null 2>&1 && HAVE_TIMEOUT="1"

# run_bounded <cmd...> — run with a wall-clock bound when `timeout` exists.
run_bounded() {
    if [ -n "$HAVE_TIMEOUT" ]; then
        timeout "$probe_timeout" "$@"
    else
        "$@"
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Fleet derivation. Identical inputs to verify-governance-cascade.sh so the two
# gates can never disagree about who is in the fleet.
# ─────────────────────────────────────────────────────────────────────────────

# gitmodules_entries <file> — one `path<TAB>url` per declared submodule.
# Parsed from the file rather than via `git config -f`, so a target root that is
# not a git work tree (the mutation sandbox) is still readable.
gitmodules_entries() {
    awk '
        function val(line) {
            sub(/^[^=]*=[[:space:]]*/, "", line)
            gsub(/^[[:space:]]+/, "", line); gsub(/[[:space:]]+$/, "", line)
            return line
        }
        function flush() { if (p != "") print p "\t" u; p = ""; u = "" }
        /^[[:space:]]*\[submodule[[:space:]]/ { flush(); next }
        /^[[:space:]]*path[[:space:]]*=/      { p = val($0); next }
        /^[[:space:]]*url[[:space:]]*=/       { u = val($0); next }
        END { flush() }
    ' "$1"
}

# gitmodules_branch <file> <path> — the declared tracking branch, or empty.
gitmodules_branch() {
    awk -v want="$2" '
        function val(line) {
            sub(/^[^=]*=[[:space:]]*/, "", line)
            gsub(/^[[:space:]]+/, "", line); gsub(/[[:space:]]+$/, "", line)
            return line
        }
        /^[[:space:]]*\[submodule[[:space:]]/ { p = ""; b = ""; next }
        /^[[:space:]]*path[[:space:]]*=/      { p = val($0); if (p == want && b != "") { print b; exit } next }
        /^[[:space:]]*branch[[:space:]]*=/    { b = val($0); if (p == want)            { print b; exit } next }
    ' "$1"
}

# helix_excluded_paths <file> — each third-party gitlink recorded in the
# manifest's trailing commentary block. Same shape and same reasoning as
# verify-governance-cascade.sh's function of the same name: the schema defines
# no field for an exclusion, so they are recorded as comments.
#   `#   <path>  -> git@host:owner/repo.git`
helix_excluded_paths() {
    sed -nE 's/^#[[:space:]]+([^[:space:]]+)[[:space:]]+->[[:space:]]+git@.*/\1/p' "$1"
}

in_list() {
    local needle="$1" hay="$2" item
    for item in $hay; do [ "$item" = "$needle" ] && return 0; done
    return 1
}


# VSC-360 -- push targets. `git push` from the submodule's origin goes to every
# remote.origin.pushurl, which may name a DIFFERENT repository from the fetch URL; a lagging
# push target read as CURRENT because only the fetch URL was ever asked.
# Read one ref from a remote. Sets RR_RC, RR_OUT, RR_SHA, RR_REF (the ref actually read: what the messages name).
# A remote may exit 0 from `ls-remote <url> HEAD` with ZERO lines (HEAD is a symref to a branch that does not exist, so
# nothing is advertised). When ref_label is HEAD and rc is 0 with no line, fall back to the full listing ONLY when it is
# unambiguous: exactly ONE refs/heads/* line, whatever that branch is called. With several branches and no HEAD symref the
# default branch is unknowable and guessing main/master reads a stale branch as CURRENT (the reviewer's false green), so
# RR_SHA stays empty and the caller reports state 2. A declared branch needs no fallback (ref_label is already that branch).
# rc != 0 is never retried or softened: it stays a read failure (state 2).
read_remote_ref() {
    local url="$1" ref_label="$2" full heads
    RR_REF="$ref_label"
    RR_OUT="$(run_bounded git ls-remote "$url" "$ref_label" 2>&1)"; RR_RC=$?
    RR_SHA="$(printf '%s\n' "$RR_OUT" | awk '/^[0-9a-f]{40}[[:space:]]/{print $1; exit}')"
    if [ "$RR_RC" -eq 0 ] && [ -z "$RR_SHA" ] && [ "$ref_label" = "HEAD" ]; then
        full="$(run_bounded git ls-remote "$url" 2>&1)" || return 0
        heads="$(printf '%s\n' "$full" | awk '$2 ~ /^refs\/heads\// && $1 ~ /^[0-9a-f]{40}$/')"
        if [ -n "$heads" ] && [ "$(printf '%s\n' "$heads" | wc -l)" -eq 1 ]; then
            RR_SHA="$(printf '%s\n' "$heads" | awk '{print $1}')"
            RR_REF="$(printf '%s\n' "$heads" | awk '{print $2}')"
        fi
    fi
    return 0
}

mask_url() { printf '%s' "$1" | sed -E 's#(https?://)[^/@]*@#\1***@#'; }
probe_pushurls() {
    local path="$1" local_sha="$2" fetch_url="$3" ref_label="$4" owned="$5"
    local sub_dir="${root}/${path}" pushes pu i=0 out prc rsha rref direction mu
    [ "$owned" -eq 1 ] || return 0
    if [ ! -d "$sub_dir" ] || ! git -C "$sub_dir" rev-parse --git-dir >/dev/null 2>&1; then
        inf "REMOTE-SYNC · ${path} — not checked out, so its push targets (remote.origin.pushurl) cannot be read; the fetch URL is the only remote compared"
        return 0
    fi
    pushes="$(git -C "$sub_dir" config --get-all remote.origin.pushurl 2>/dev/null)"
    [ -n "$pushes" ] || return 0
    while IFS= read -r pu; do
        [ -n "$pu" ] || continue
        i=$((i + 1))
        [ "$pu" = "$fetch_url" ] && continue
        mu="$(mask_url "$pu")"
        read_remote_ref "$pu" "$ref_label"; out="$RR_OUT"; prc=$RR_RC; rsha="$RR_SHA"; rref="$RR_REF"
        if [ "$prc" -ne 0 ] || [ -z "$rsha" ]; then
            [ -n "$quiet" ] || printf '   %-28s %-12.12s %-12s %s\n' "${path}@push${i}" "$local_sha" "unreachable" "UNDETERMINED"
            und "REMOTE-SYNC ${path} push target ${i} — could not read ${ref_label} from ${mu} (rc=${prc}; rc 0 with no line = no HEAD symref and zero or several branches, so the default branch is not decidable). OFFLINE / AUTH / GONE are indistinguishable here and all three are state 2, NEVER 'current'."
            continue
        fi
        if [ "$rsha" = "$local_sha" ]; then
            [ -n "$quiet" ] || printf '   %-28s %-12.12s %-12.12s %s\n' "${path}@push${i}" "$local_sha" "$rsha" "CURRENT"
            ok "REMOTE-SYNC ${path} push target ${i} — gitlink ${local_sha} == ${rref} at ${mu}"
            continue
        fi
        direction="DIFFERS"
        if git -C "$sub_dir" cat-file -e "${local_sha}^{commit}" 2>/dev/null && git -C "$sub_dir" cat-file -e "${rsha}^{commit}" 2>/dev/null; then
            if git -C "$sub_dir" merge-base --is-ancestor "$rsha" "$local_sha" 2>/dev/null; then direction="LAGS"
            elif git -C "$sub_dir" merge-base --is-ancestor "$local_sha" "$rsha" 2>/dev/null; then direction="BEHIND"
            else direction="DIVERGED"; fi
        fi
        [ -n "$quiet" ] || printf '   %-28s %-12.12s %-12.12s %s\n' "${path}@push${i}" "$local_sha" "$rsha" "$direction"
        case "$direction" in
            LAGS)     bad "REMOTE-SYNC ${path} push target ${i} — LAGS the gitlink: ${rref} ${rsha} at ${mu} is an ancestor of ${local_sha} (a push target missing the commit this repository points at)."
                      echo "           fix: push the submodule to that target — git -C ${path} push origin — then re-run." ;;
            BEHIND)   bad "REMOTE-SYNC ${path} push target ${i} — BEHIND: gitlink ${local_sha} is an ancestor of ${rref} ${rsha} at ${mu}." ;;
            DIVERGED) bad "REMOTE-SYNC ${path} push target ${i} — DIVERGED from the gitlink (${local_sha} vs ${rsha} at ${mu}); NOT fast-forwardable and MUST NOT be automated." ;;
            *)        bad "REMOTE-SYNC ${path} push target ${i} — DIFFERS from the gitlink: ${local_sha} vs ${rsha} at ${mu}; the direction is not decidable without the objects (fetch ${path} first)." ;;
        esac
    done <<< "$pushes"
}

# ─────────────────────────────────────────────────────────────────────────────
# The check.
# ─────────────────────────────────────────────────────────────────────────────
check_remote_sync() {
    local gm="${root}/.gitmodules" hd="${root}/${MANIFEST_NAME}"
    local excl="" entries="" line path url branch ref_label
    local local_sha remote_sha remote_out lsrc rc=0 n=0 owned_n=0
    local direction sub_dir have_local have_remote rref

    if ! command -v git >/dev/null 2>&1; then
        und "REMOTE-SYNC — git is not on PATH; no remote can be consulted"
        return 2
    fi
    if [ ! -r "$gm" ]; then
        und "REMOTE-SYNC — .gitmodules unreadable at ${gm}; the fleet cannot be enumerated"
        return 2
    fi
    [ -n "$HAVE_TIMEOUT" ] || inf "REMOTE-SYNC · \`timeout\` is not on PATH; probes run unbounded. A hung remote will stall this gate rather than returning state 2 (§11.4.6: stated, not silently accepted)"

    if [ -r "$hd" ]; then
        excl="$(helix_excluded_paths "$hd")"
    else
        inf "REMOTE-SYNC · ${MANIFEST_NAME} unreadable at ${hd}; no gitlink can be classified third-party from evidence, so ALL are treated as OWNED. That is the conservative direction — it over-reports rather than under-reports (§11.4.6)"
    fi

    entries="$(gitmodules_entries "$gm")"
    if [ -z "$entries" ]; then
        und "REMOTE-SYNC — .gitmodules declares no submodule at ${gm}; there is nothing to compare and that is not a pass"
        return 2
    fi

    [ -n "$quiet" ] || {
        printf '   %-28s %-12s %-12s %s\n' "gitlink" "local" "remote" "verdict"
        printf '   %-28s %-12s %-12s %s\n' "----------------------------" "------------" "------------" "-------"
    }

    while IFS=$'\t' read -r path url; do
        [ -n "$path" ] || continue
        n=$((n + 1))

        local owned=1
        if [ -n "$excl" ] && grep -qxF "$path" <<<"$excl"; then owned=0; fi

        if [ -z "$url" ]; then
            if [ "$owned" -eq 1 ]; then
                und "REMOTE-SYNC ${path} — declared in .gitmodules with NO url; its remote cannot be identified, let alone compared"
            else
                inf "REMOTE-SYNC · ${path} — third-party, and no url declared; not probed"
            fi
            continue
        fi

        # LOCAL side — the index gitlink.
        local_sha="$(git -C "$root" ls-files -s -- "$path" 2>/dev/null | awk '$1=="160000"{print $2; exit}')"
        if [ -z "$local_sha" ]; then
            if [ "$owned" -eq 1 ]; then
                und "REMOTE-SYNC ${path} — declared in .gitmodules but no gitlink in the index; there is no local commit to compare against"
            else
                inf "REMOTE-SYNC · ${path} — third-party with no gitlink in the index; not probed"
            fi
            continue
        fi

        [ "$owned" -eq 1 ] && owned_n=$((owned_n + 1))

        # REMOTE side — the declared branch if there is one, else HEAD.
        branch="$(gitmodules_branch "$gm" "$path")"
        if [ -n "$branch" ]; then ref_label="refs/heads/${branch}"; else ref_label="HEAD"; fi

        probe_pushurls "$path" "$local_sha" "$url" "$ref_label" "$owned"

        read_remote_ref "$url" "$ref_label"; remote_out="$RR_OUT"; lsrc=$RR_RC; remote_sha="$RR_SHA"; rref="$RR_REF"

        if [ "$lsrc" -ne 0 ] || [ -z "$remote_sha" ]; then
            # THE CRITICAL BRANCH. Unreachable is state 2 for an owned module.
            # It is never folded into "current", and it is never silently
            # dropped: that substitution is the exact defect this gate exists
            # to end.
            [ -n "$quiet" ] || printf '   %-28s %-12.12s %-12s %s\n' "$path" "$local_sha" "unreachable" "UNDETERMINED"
            if [ "$owned" -eq 1 ]; then
                local why="rc=${lsrc}"
                [ -n "$HAVE_TIMEOUT" ] && [ "$lsrc" -eq 124 ] && why="timed out after ${probe_timeout}s"
                und "REMOTE-SYNC ${path} — could not read ${ref_label} from ${url} (${why}; rc=0 with no line = no HEAD symref and zero or several branches, so the default branch is not decidable). OFFLINE / AUTH / GONE are indistinguishable here and all three are state 2, NEVER 'current'."
                printf '%s\n' "$remote_out" | sed 's/^/           /' | head -n 4
            else
                inf "REMOTE-SYNC · ${path} — third-party remote unreadable (${url}); reported, never gating"
            fi
            continue
        fi

        if [ "$local_sha" = "$remote_sha" ]; then
            [ -n "$quiet" ] || printf '   %-28s %-12.12s %-12.12s %s\n' "$path" "$local_sha" "$remote_sha" "CURRENT"
            if [ "$owned" -eq 1 ]; then
                ok "REMOTE-SYNC ${path} — gitlink ${local_sha} == ${rref} at ${url}"
            else
                inf "REMOTE-SYNC · ${path} — third-party, and current at ${remote_sha}"
            fi
            continue
        fi

        # ── They differ. Now decide the DIRECTION, which decides the remedy. ──
        direction="DIFFERS"
        sub_dir="${root}/${path}"
        have_local=""; have_remote=""
        if [ -d "$sub_dir" ] && git -C "$sub_dir" rev-parse --git-dir >/dev/null 2>&1; then
            git -C "$sub_dir" cat-file -e "${local_sha}^{commit}"  2>/dev/null && have_local="1"
            git -C "$sub_dir" cat-file -e "${remote_sha}^{commit}" 2>/dev/null && have_remote="1"
            if [ -z "$have_remote" ] && [ -n "$do_fetch" ]; then
                # Objects only. No ref is written, no tree is touched.
                run_bounded git -C "$sub_dir" fetch --no-write-fetch-head --no-tags \
                    "$url" "$remote_sha" >/dev/null 2>&1 \
                    && git -C "$sub_dir" cat-file -e "${remote_sha}^{commit}" 2>/dev/null \
                    && have_remote="1"
            fi
            if [ -n "$have_local" ] && [ -n "$have_remote" ]; then
                if git -C "$sub_dir" merge-base --is-ancestor "$local_sha" "$remote_sha" 2>/dev/null; then
                    direction="BEHIND"
                elif git -C "$sub_dir" merge-base --is-ancestor "$remote_sha" "$local_sha" 2>/dev/null; then
                    direction="AHEAD"
                else
                    direction="DIVERGED"
                fi
            fi
        fi

        [ -n "$quiet" ] || printf '   %-28s %-12.12s %-12.12s %s\n' "$path" "$local_sha" "$remote_sha" "$direction"

        if [ "$owned" -eq 0 ]; then
            inf "REMOTE-SYNC · ${path} — third-party and ${direction} (${local_sha} vs ${remote_sha}); upstream's cadence is not ours to fix, so this is reported and never gating"
            continue
        fi

        case "$direction" in
            BEHIND)
                bad "REMOTE-SYNC ${path} — BEHIND upstream: gitlink ${local_sha} is an ancestor of ${rref} ${remote_sha}. Fast-forwardable."
                echo "           fix: git -C ${path} fetch && git -C ${path} checkout ${remote_sha}"
                echo "                then re-record the pin: bash scripts/verify-manifest-pins.sh --fix"
                ;;
            AHEAD)
                bad "REMOTE-SYNC ${path} — AHEAD of upstream: gitlink ${local_sha} is NOT on ${rref} (${remote_sha}). The commit this repository points at is UNPUSHED, so this tree does not clone for anyone else."
                echo "           fix: push the submodule first — git -C ${path} push — then re-run."
                ;;
            DIVERGED)
                bad "REMOTE-SYNC ${path} — DIVERGED: neither ${local_sha} nor ${remote_sha} is an ancestor of the other. Both sides moved; this is NOT fast-forwardable and MUST NOT be automated."
                echo "           fix: operator reconciliation inside ${path} (§11.4.31 conflict_resolution: operator-required)."
                ;;
            *)
                bad "REMOTE-SYNC ${path} — DIFFERS from ${rref}: gitlink ${local_sha} vs remote ${remote_sha}. The difference is DETERMINED; the direction is NOT, because the remote commit is not in this checkout's object store."
                echo "           fix: re-run with --fetch to classify behind/ahead/diverged, or fetch ${path} by hand."
                ;;
        esac
    done <<< "$entries"

    [ -n "$quiet" ] || echo "----------------------------------------------------------------------"
    echo "${GATE}: ${pass} CURRENT, ${fail} DRIFT, ${undet} UNDETERMINED  of ${owned_n} owned gitlink(s) probed, ${n} declared  (root ${root})"

    _verdict_emitted=1
    # State 2 outranks state 1: an incomplete sweep is not a complete verdict.
    if [ "$undet" -gt 0 ]; then
        echo "⚠ ${GATE}: CANNOT VERIFY — ${undet} owned gitlink(s) could not be compared against their remote."
        echo "   This is NOT a pass and MUST NOT be recorded as one. Findings already determined are printed above."
        return 2
    fi
    if [ "$fail" -gt 0 ]; then
        echo "❌ ${GATE}: FAIL [DEFECT] — ${fail} owned gitlink(s) are out of sync with their remote."
        return 1
    fi
    echo "✅ ${GATE}: PASS — every one of the ${owned_n} owned gitlink(s) equals its remote tip, measured just now."
    echo "   Dated observation, not a standing fact: remotes move (honest boundary 1)."
    return 0
}

# ─────────────────────────────────────────────────────────────────────────────
# §1.1 PAIRED MUTATION PROOF
#
# Entirely offline and entirely synthetic. The fixtures are real LOCAL git
# repositories created inside a mktemp sandbox and wired to each other with
# `file://` remotes, so `git ls-remote` exercises the REAL code path — the same
# function, the same parsing, the same comparison — without touching the network
# or this repository's actual submodules.
#
# The three states this gate must never confuse are each proved separately:
#   P1 CURRENT   gitlink == remote tip                          -> rc=0
#   P2 BEHIND    upstream advanced; ours is an ancestor         -> rc=1, "BEHIND"
#   P3 DIVERGED  both moved; neither is an ancestor             -> rc=1, "DIVERGED"
#   P4 AHEAD     we hold an unpushed commit                     -> rc=1, "AHEAD"
#   P5 UNREACHABLE  the remote is gone                          -> rc=2, NOT 0
#   P6 THIRD-PARTY  a documented vendor module is behind        -> rc=0 (reported)
#
# P5 is the one that matters most and the reason this file exists: if a dead
# remote ever produced rc=0 this gate would be the same blind instrument it
# replaced, and the assertion below would be the only thing standing between
# that bug and a green pre-push run.
# ─────────────────────────────────────────────────────────────────────────────
prove_failure() {
    local sandbox rc mut_fails=0
    echo "${GATE} §1.1 PAIRED MUTATION PROOF"
    echo "----------------------------------------------------------------------"

    if ! command -v git >/dev/null 2>&1; then
        echo "${GATE}: cannot verify — git is not on PATH, so no fixture can be built" >&2
        return 2
    fi
    sandbox="$(mktemp -d)" || { echo "${GATE}: cannot verify — mktemp failed" >&2; return 2; }
    _sandbox_to_clean="$sandbox"

    local G=(-c user.name=proof -c user.email=proof@example.invalid -c commit.gpgsign=false -c init.defaultBranch=main)

    # mk_upstream <name> <n-commits> — a bare-ish upstream with n commits.
    mk_upstream() {
        local nm="$1" cnt="$2" i
        git "${G[@]}" init -q "${sandbox}/up/${nm}" >/dev/null 2>&1 || return 1
        i=1
        while [ "$i" -le "$cnt" ]; do
            printf 'commit %s\n' "$i" > "${sandbox}/up/${nm}/f.txt"
            git "${G[@]}" -C "${sandbox}/up/${nm}" add f.txt >/dev/null 2>&1 || return 1
            git "${G[@]}" -C "${sandbox}/up/${nm}" commit -qm "c${i}" >/dev/null 2>&1 || return 1
            i=$((i + 1))
        done
        return 0
    }

    # up_sha <name> <n-from-tip> — the sha n commits back from the tip.
    up_sha() { git -C "${sandbox}/up/$1" rev-parse "HEAD~${2}" 2>/dev/null; }

    # build_specimen <dir> — a project root whose .gitmodules and index gitlinks
    # are written deliberately, one line per fixture module.
    #   spec lines: "<path>|<upstream-name>|<sha>|<third-party?>"
    build_specimen() {
        local dest="$1"; shift
        local spec line p upn sha tp
        rm -rf "$dest"; mkdir -p "$dest" || return 1
        git "${G[@]}" init -q "$dest" >/dev/null 2>&1 || return 1
        : > "${dest}/.gitmodules"
        {
            printf 'schema_version: 1\n\ndeps:\n'
        } > "${dest}/helix-deps.yaml"
        for spec in "$@"; do
            IFS='|' read -r p upn sha tp <<< "$spec"
            printf '[submodule "%s"]\n\tpath = %s\n\turl = %s\n' \
                   "$p" "$p" "file://${sandbox}/up/${upn}" >> "${dest}/.gitmodules"
            # A real gitlink in the index, created without a working tree.
            git "${G[@]}" -C "$dest" update-index --add --cacheinfo "160000,${sha},${p}" \
                >/dev/null 2>&1 || return 1
            if [ "$tp" = "tp" ]; then
                printf '#   %s  -> git@github.com:vendor/%s.git\n' "$p" "$upn" >> "${dest}/helix-deps.yaml"
            fi
        done
        return 0
    }

    # A checked-out submodule clone, so direction can be decided from objects.
    clone_into_specimen() {
        local dest="$1" p="$2" upn="$3"
        git "${G[@]}" clone -q "${sandbox}/up/${upn}" "${dest}/${p}" >/dev/null 2>&1
    }

    assert_case() {
        local name="$1" want="$2" expect="$3" dir="$4"
        local out orc
        out="$(bash "$0" --root "$dir" 2>&1)"; orc=$?
        if [ "$orc" -ne "$want" ]; then
            echo "❌ ${name}"
            echo "                        -> rc=${orc}, wanted ${want}. THIS GATE WOULD BE A SHAM (§1.1)."
            printf '%s\n' "$out" | sed 's/^/        /'
            mut_fails=$((mut_fails+1)); return
        fi
        if [ -n "$expect" ] && ! grep -qF -- "$expect" <<<"$out"; then
            echo "❌ ${name}"
            echo "                        -> rc=${orc} as wanted, but the verdict never said '${expect}'."
            echo "                           A finding that does not name the remedy is unactionable (§11.4.6)."
            printf '%s\n' "$out" | sed 's/^/        /'
            mut_fails=$((mut_fails+1)); return
        fi
        echo "✅ ${name}"
        echo "                        -> rc=${orc} (wanted ${want})${expect:+  named '${expect}'}"
    }

    mkdir -p "${sandbox}/up" || { echo "${GATE}: cannot verify — sandbox unusable" >&2; return 2; }
    mk_upstream mod 3 || { echo "${GATE}: cannot verify — fixture upstream not built" >&2; return 2; }
    mk_upstream vend 2 || { echo "${GATE}: cannot verify — vendor fixture not built" >&2; return 2; }

    local tip behind_sha vend_behind
    tip="$(up_sha mod 0)"; behind_sha="$(up_sha mod 2)"; vend_behind="$(up_sha vend 1)"
    if [ -z "$tip" ] || [ -z "$behind_sha" ] || [ -z "$vend_behind" ]; then
        echo "${GATE}: cannot verify — fixture shas could not be read" >&2; return 2
    fi

    # ── CONTROL: gitlink AT the tip must be green, or nothing below means anything
    build_specimen "${sandbox}/p1" "mod|mod|${tip}|" || { echo "${GATE}: cannot verify — specimen p1" >&2; return 2; }
    assert_case "P1 current            — gitlink equals the remote tip                       " 0 "PASS" "${sandbox}/p1"

    # ── P2 BEHIND: two commits back, and it must SAY fast-forwardable
    build_specimen "${sandbox}/p2" "mod|mod|${behind_sha}|" || { echo "${GATE}: cannot verify — specimen p2" >&2; return 2; }
    clone_into_specimen "${sandbox}/p2" mod mod
    assert_case "P2 behind             — upstream advanced; ours is an ancestor              " 1 "BEHIND" "${sandbox}/p2"

    # ── P3 DIVERGED: a commit that upstream has never seen, on a rewritten base.
    #    Built by committing into the clone AFTER resetting it back, so neither
    #    side is an ancestor of the other — the case that must never be reported
    #    as "behind", because the remedies are not the same.
    build_specimen "${sandbox}/p3" "mod|mod|${tip}|" || { echo "${GATE}: cannot verify — specimen p3" >&2; return 2; }
    clone_into_specimen "${sandbox}/p3" mod mod
    local div_sha=""
    if git "${G[@]}" -C "${sandbox}/p3/mod" reset -q --hard HEAD~1 >/dev/null 2>&1 \
       && printf 'divergent\n' > "${sandbox}/p3/mod/f.txt" \
       && git "${G[@]}" -C "${sandbox}/p3/mod" add f.txt >/dev/null 2>&1 \
       && git "${G[@]}" -C "${sandbox}/p3/mod" commit -qm "divergent" >/dev/null 2>&1; then
        div_sha="$(git -C "${sandbox}/p3/mod" rev-parse HEAD)"
    fi
    if [ -n "$div_sha" ] \
       && git "${G[@]}" -C "${sandbox}/p3" update-index --add --cacheinfo "160000,${div_sha},mod" >/dev/null 2>&1; then
        assert_case "P3 diverged           — both sides moved; NOT fast-forwardable             " 1 "DIVERGED" "${sandbox}/p3"
    else
        echo "❌ P3 diverged           — the divergent fixture could not be built"
        mut_fails=$((mut_fails+1))
    fi

    # ── P4 AHEAD: a local commit upstream does not have. An unpushed gitlink is
    #    unclonable for everyone else, so it must not be reported as "behind".
    build_specimen "${sandbox}/p4" "mod|mod|${tip}|" || { echo "${GATE}: cannot verify — specimen p4" >&2; return 2; }
    clone_into_specimen "${sandbox}/p4" mod mod
    local ahead_sha=""
    if printf 'unpushed\n' > "${sandbox}/p4/mod/f.txt" \
       && git "${G[@]}" -C "${sandbox}/p4/mod" add f.txt >/dev/null 2>&1 \
       && git "${G[@]}" -C "${sandbox}/p4/mod" commit -qm "unpushed" >/dev/null 2>&1; then
        ahead_sha="$(git -C "${sandbox}/p4/mod" rev-parse HEAD)"
    fi
    if [ -n "$ahead_sha" ] \
       && git "${G[@]}" -C "${sandbox}/p4" update-index --add --cacheinfo "160000,${ahead_sha},mod" >/dev/null 2>&1; then
        assert_case "P4 ahead              — gitlink points at an UNPUSHED commit               " 1 "AHEAD" "${sandbox}/p4"
    else
        echo "❌ P4 ahead              — the ahead fixture could not be built"
        mut_fails=$((mut_fails+1))
    fi

    # ── P5 UNREACHABLE — THE ONE THAT MATTERS ────────────────────────────────
    # The remote is deleted outright. A gate that answers 0 here has replaced an
    # old blind instrument with a new one, so this asserts BOTH the exit code
    # and that the verdict refuses the word "pass" for it.
    build_specimen "${sandbox}/p5" "mod|gone|${tip}|" || { echo "${GATE}: cannot verify — specimen p5" >&2; return 2; }
    assert_case "P5 unreachable (UNDET)— remote does not exist; MUST be 2, never 0          " 2 "CANNOT VERIFY" "${sandbox}/p5"

    # ── P6 third-party — classified from the manifest's exclusion block, not by
    #    name. Behind upstream, and must NOT gate.
    build_specimen "${sandbox}/p6" "vend|vend|${vend_behind}|tp" || { echo "${GATE}: cannot verify — specimen p6" >&2; return 2; }
    clone_into_specimen "${sandbox}/p6" vend vend
    assert_case "P6 third-party        — documented vendor is behind; reported, never gating " 0 "third-party" "${sandbox}/p6"

    # ── P7/P8/P9 (VSC-360) PUSH TARGETS: origin pushes to a repository other than the one it fetches from.
    #    P7 a push target that LAGS the gitlink must be DRIFT (it read CURRENT before: only the fetch URL was asked);
    #    P8 a push target that is current stays green; P9 an unreadable push target is state 2, never 0.
    local pt_ok=1
    git "${G[@]}" clone -q "${sandbox}/up/mod" "${sandbox}/up/mirror_lag" >/dev/null 2>&1 \
        && git "${G[@]}" -C "${sandbox}/up/mirror_lag" reset -q --hard HEAD~2 >/dev/null 2>&1 || pt_ok=0
    git "${G[@]}" clone -q "${sandbox}/up/mod" "${sandbox}/up/mirror_ok" >/dev/null 2>&1 || pt_ok=0
    if [ "$pt_ok" -eq 1 ]; then
        build_specimen "${sandbox}/p7" "mod|mod|${tip}|" || { echo "${GATE}: cannot verify — specimen p7" >&2; return 2; }
        clone_into_specimen "${sandbox}/p7" mod mod
        git -C "${sandbox}/p7/mod" config --add remote.origin.pushurl "file://${sandbox}/up/mirror_lag"
        assert_case "P7 push target lags   — origin fetches the tip, one push target is behind  " 1 "push target" "${sandbox}/p7"
        build_specimen "${sandbox}/p8" "mod|mod|${tip}|" || { echo "${GATE}: cannot verify — specimen p8" >&2; return 2; }
        clone_into_specimen "${sandbox}/p8" mod mod
        git -C "${sandbox}/p8/mod" config --add remote.origin.pushurl "file://${sandbox}/up/mirror_ok"
        assert_case "P8 push target current— a second push target at the tip stays green        " 0 "PASS" "${sandbox}/p8"
        build_specimen "${sandbox}/p9" "mod|mod|${tip}|" || { echo "${GATE}: cannot verify — specimen p9" >&2; return 2; }
        clone_into_specimen "${sandbox}/p9" mod mod
        git -C "${sandbox}/p9/mod" config --add remote.origin.pushurl "file://${sandbox}/up/does_not_exist"
        assert_case "P9 push target gone   — an unreadable push target MUST be 2, never 0       " 2 "CANNOT VERIFY" "${sandbox}/p9"
    else
        echo "❌ P7-P9 push-target fixtures could not be built"
        mut_fails=$((mut_fails+1))
    fi

    # ── P10-P14 (VSC-360 follow-up) NO HEAD SYMREF: a remote may exit 0 from `ls-remote <url> HEAD` with ZERO lines
    #    (HEAD names a branch that does not exist) while `ls-remote <url>` lists refs/heads/main. That is a readable remote,
    #    not an unreadable one. A genuine failure (rc != 0) and a remote with no usable branch stay state 2.
    mk_nohead() {   # <name> <source-upstream> [branch] : bare remote carrying <branch> (default main) whose HEAD dangles
        local nm="$1" src="$2" br="${3:-main}"
        git "${G[@]}" clone -q --bare "${sandbox}/up/${src}" "${sandbox}/up/${nm}" >/dev/null 2>&1 || return 1
        if [ "$br" != "main" ]; then
            git -C "${sandbox}/up/${nm}" branch -m main "$br" >/dev/null 2>&1 || return 1
        fi
        git -C "${sandbox}/up/${nm}" symbolic-ref HEAD refs/heads/dangling_head >/dev/null 2>&1 || return 1
    }
    local nh_ok=1
    mk_nohead nohead mod || nh_ok=0
    mk_nohead nohead_dev mod dev || nh_ok=0
    if [ "$nh_ok" -eq 1 ] && [ -n "$(git ls-remote "file://${sandbox}/up/nohead" refs/heads/main 2>/dev/null)" ] \
       && [ -z "$(git ls-remote "file://${sandbox}/up/nohead" HEAD 2>/dev/null)" ]; then
        build_specimen "${sandbox}/p10" "mod|nohead|${tip}|" || { echo "${GATE}: cannot verify — specimen p10" >&2; return 2; }
        assert_case "P10 no HEAD symref    — fetch URL lists main only; gitlink at tip is CURRENT   " 0 "PASS" "${sandbox}/p10"
        build_specimen "${sandbox}/p11" "mod|nohead|${behind_sha}|" || { echo "${GATE}: cannot verify — specimen p11" >&2; return 2; }
        clone_into_specimen "${sandbox}/p11" mod mod
        assert_case "P11 no HEAD, behind   — fetch URL lists main only; gitlink behind is BEHIND  " 1 "BEHIND" "${sandbox}/p11"
        build_specimen "${sandbox}/p12" "mod|mod|${tip}|" || { echo "${GATE}: cannot verify — specimen p12" >&2; return 2; }
        clone_into_specimen "${sandbox}/p12" mod mod
        git -C "${sandbox}/p12/mod" config --add remote.origin.pushurl "file://${sandbox}/up/nohead"
        assert_case "P12 push, no HEAD     — push target without HEAD symref at the tip is green  " 0 "PASS" "${sandbox}/p12"
        build_specimen "${sandbox}/p13" "mod|mod|${tip}|" || { echo "${GATE}: cannot verify — specimen p13" >&2; return 2; }
        clone_into_specimen "${sandbox}/p13" mod mod
        git "${G[@]}" clone -q --bare "${sandbox}/up/mirror_lag" "${sandbox}/up/nohead_lag" >/dev/null 2>&1 \
            && git "${G[@]}" -C "${sandbox}/up/nohead_lag" branch -m master main >/dev/null 2>&1
        git -C "${sandbox}/up/nohead_lag" symbolic-ref HEAD refs/heads/dangling_head >/dev/null 2>&1
        git -C "${sandbox}/p13/mod" config --add remote.origin.pushurl "file://${sandbox}/up/nohead_lag"
        assert_case "P13 push, no HEAD lag — lagging push target without HEAD still exits 1 named " 1 "push target" "${sandbox}/p13"
        # P14 (adjusted for the no-guess rule): TWO branches, neither main nor master, no HEAD symref => ambiguous => 2.
        # (It formerly used ONE branch 'dev' and relied on there being no main/master to guess; a single branch is now
        # resolved correctly -- that case is P16 -- so P14 needed a genuinely ambiguous fixture to stay meaningful.)
        mk_nohead nohead_two mod dev || nh_ok=0
        git -C "${sandbox}/up/nohead_two" branch feat dev >/dev/null 2>&1 || nh_ok=0
        build_specimen "${sandbox}/p14" "mod|nohead_two|${tip}|" || { echo "${GATE}: cannot verify — specimen p14" >&2; return 2; }
        assert_case "P14 no HEAD, 2 branches— 'dev' and 'feat', no main/master; ambiguous, MUST be 2" 2 "CANNOT VERIFY" "${sandbox}/p14"
        # P15 (reviewer false green): stale main at c1 + the real default branch 'trunk' at the tip + dangling HEAD, gitlink at
        # the stale main commit. Guessing main read this CURRENT; with several branches and no HEAD symref it MUST be 2.
        git "${G[@]}" clone -q --bare "${sandbox}/up/mod" "${sandbox}/up/trunkrepo" >/dev/null 2>&1 || nh_ok=0
        git -C "${sandbox}/up/trunkrepo" branch trunk main >/dev/null 2>&1 || nh_ok=0
        git -C "${sandbox}/up/trunkrepo" update-ref refs/heads/main "${behind_sha}" >/dev/null 2>&1 || nh_ok=0
        git -C "${sandbox}/up/trunkrepo" symbolic-ref HEAD refs/heads/dangling_head >/dev/null 2>&1 || nh_ok=0
        build_specimen "${sandbox}/p15" "mod|trunkrepo|${behind_sha}|" || { echo "${GATE}: cannot verify — specimen p15" >&2; return 2; }
        assert_case "P15 stale main + trunk— several branches, no HEAD, gitlink at stale main: 2  " 2 "CANNOT VERIFY" "${sandbox}/p15"
        # P16: ONE branch, named other than main/master, no HEAD symref => resolved, and the row names the ref actually read.
        build_specimen "${sandbox}/p16" "mod|nohead_dev|${tip}|" || { echo "${GATE}: cannot verify — specimen p16" >&2; return 2; }
        assert_case "P16 single branch dev — only 'dev', no HEAD symref; resolved, names the ref " 0 "== refs/heads/dev" "${sandbox}/p16"
        # P17: declared branch (.gitmodules branch = trunk) on the P15 remote: no fallback needed, gitlink at the trunk tip is CURRENT.
        build_specimen "${sandbox}/p17" "mod|trunkrepo|${tip}|" || { echo "${GATE}: cannot verify — specimen p17" >&2; return 2; }
        printf '\tbranch = trunk\n' >> "${sandbox}/p17/.gitmodules"
        assert_case "P17 declared branch   — branch=trunk declared; gitlink at trunk tip CURRENT " 0 "== refs/heads/trunk" "${sandbox}/p17"
    else
        echo "❌ P10-P14 no-HEAD-symref fixtures could not be built (or did not reproduce rc 0 with zero lines)"
        mut_fails=$((mut_fails+1))
    fi

    # ── RESTORED CONTROL ─────────────────────────────────────────────────────
    assert_case "CONTROL restored      — the P1 specimen is still green                      " 0 "PASS" "${sandbox}/p1"

    rm -rf "$sandbox"; _sandbox_to_clean=""
    echo "----------------------------------------------------------------------"
    _verdict_emitted=1
    if [ "$mut_fails" -eq 0 ]; then
        echo "✅ ${GATE} §1.1 MUTATION PROOF: PASS — 16 mutations each produced the verdict they"
        echo "   must (incl. P10-P17: no-HEAD-symref remotes, never guessing main/master), and 3 control assertions passed,"
        echo "   proved against real local git repositories wired by file:// remotes, with no"
        echo "   network involved."
        echo "   CURRENT is 0; BEHIND, AHEAD and DIVERGED are each 1 AND are named distinctly"
        echo "   rather than conflated; a documented third-party module that is behind stays 0;"
        echo "   and an UNREACHABLE remote is 2 — never 0. That last case is the whole reason"
        echo "   this gate exists, and it is the one an unproven instrument would get wrong."
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

echo "${GATE}: comparing every declared gitlink against its remote, under ${root}"
echo "   local side = index gitlink · remote side = ls-remote (declared branch, else HEAD)"
echo "----------------------------------------------------------------------"
check_remote_sync
exit $?
