#!/usr/bin/env bash
# CM-PUSH-TOPOLOGY — where does a `git push` in this tree actually SEND bytes,
# and is any of those destinations one this repository cannot vouch for?
#
# ── Why this gate exists ─────────────────────────────────────────────────────
# It closes a measured blind spot, not a hypothetical one. On 2026-09-06,
# `git grep -- '--all --push'` returned NOTHING in the entire tree, and every
# instrument that touches remotes reads either `.gitmodules` or a single
# `origin` FETCH url:
#
#   verify-manifest-pins.sh (C9)     manifest ref  == local gitlink   (RECORD)
#   verify-submodule-remote-sync.sh  local gitlink == remote tip      (FRESHNESS)
#   verify-provider-ci.sh            provider-side CI settings        (TRIGGERS)
#   this gate                        every remote's PUSH url set      (EGRESS)
#
# `.gitmodules` carries exactly ONE url per submodule, and that url is a FETCH
# url. Push urls live only in each checkout's untracked `.git/config`, so a
# fan-out configured there is invisible to every tracked-file instrument in this
# repository and to every gate listed above. Measured on this tree the same day:
# 8 of 14 repositories have a remote whose push url set has MORE THAN ONE entry,
# `submodules/constitution` has SIX on `origin` alone, and `milosvasic.ru`
# carries a two-way fan-out while having no tracked `upstreams/` directory at
# all. None of that was visible to anything. This is the instrument that looks.
#
# ── THE METHOD TRAP, recorded because it has caught several readers ──────────
# `git remote get-url --push <remote>` prints only the FIRST push url. It exits
# 0 and prints ONE line for a remote that has six. Any survey built on it
# undercounts by design and reports a fan-out as a single destination.
#
#   git remote get-url --push origin          # 1 line   -- WRONG
#   git remote get-url --all --push origin    # N lines  -- correct
#
# This gate parses `git remote -v`, which lists every (name, url, direction)
# triple, and cross-checks each remote with `get-url --all --push`. Assertion
# M1 of the paired proof exists solely to keep it that way: it builds a remote
# with six push urls and fails if the gate reports fewer.
#
# ── What is a FINDING (1) and what is a NOTE, and why ────────────────────────
# A gate nobody reads is worth nothing, and one that fires on every fan-out in
# a fleet that deliberately mirrors to four hosts would be read exactly once.
# So the line is drawn at the only thing here that is irreversible:
#
#   FINDING  a PRIVATE repository has a push destination this tree cannot
#            establish as private — either because the provider answers PUBLIC,
#            or because no read-only API adapter is registered for that host so
#            the question cannot be asked at all.
#
# That is the content-boundary rule of this repository (docs/content-boundary.md)
# applied to EGRESS rather than to file contents. A private repository's whole
# history is one `git push` away from a destination whose visibility is unknown,
# and a push is not reversible: once objects land on a host, deleting the
# reference does not unpublish them. The umbrella's own carrier records what
# that costs — a 2026-09-01 incident in which private material reached a public
# remote and could not be withdrawn, because history is not editable after a
# push.
#
# Both halves of that rule are findings, and the reason they are NOT split into
# 1 and 2 is worth stating rather than leaving implicit. "The destination host
# has no adapter" is not the GATE failing to determine something; the gate
# determined the topology completely. What it establishes, as a fact, is that
# private content can leave for a destination NOBODY HERE CAN VOUCH FOR. That
# is the finding. Downgrading it to "could not determine" would convert the
# most dangerous row in the fleet into the quietest one.
#
#   NOTE (never gates), each measured on this tree:
#     * a PUBLIC repository fanning out to any number of hosts. Nothing can be
#       disclosed that is not already disclosed. This is 7 of the 8 fan-outs.
#     * a repository whose FETCH host differs from its FIRST PUSH host. Real,
#       surprising, and worth printing — `submodules/constitution` and
#       `monetization` both fetch from github.com and push to gitflic.ru first.
#       It is not a disclosure and it is not a breakage.
#     * a push url whose repository NAME the provider RESOLVES to a different
#       name — a rename redirect. Measured: `milosvasic.ru` pushes to
#       `milos85vasic/milosvasic.net.v2`, which GitHub resolves to
#       `milos85vasic/milosvasic.ru`. That is the SOLE publish path of a LIVE
#       production site, reaching production only through a redirect.
#
#       This one was argued for a finding and DELIBERATELY LEFT A NOTE. The
#       argument for promoting it is real and is recorded so an operator can
#       overrule this file: a redirect survives only while the old name stays
#       unclaimed, and a name-takeover would silently retarget a production
#       deploy. The argument against, which won: the repository is PUBLIC so
#       nothing can be disclosed; the redirect is CURRENTLY LIVE and measured,
#       not assumed; and blocking a push on it would block the only mechanism
#       that deploys the site, which is the textbook way to train everyone to
#       pass `--no-verify`. A loud note that names both halves of the redirect
#       is the honest instrument here.
#     * a third-party gitlink, reported and never gating — same rule and same
#       reasoning as verify-submodule-remote-sync.sh: a vendor's remote layout
#       is not ours to fix.
#
# ── Exit codes (three-valued; 2 IS NEVER A PASS) ─────────────────────────────
#   0 — every repository's push destinations were classified and none is a
#       private repository leaving for an unvouchable destination.
#   1 — at least one FINDING as defined above. Determined, with the offending
#       (repository, destination) pair named.
#   2 — COULD NOT DETERMINE for at least one repository: a declared submodule
#       that is not initialised (no .git, so its `.git/config` and therefore its
#       push urls do not exist), git absent, `.gitmodules` unreadable, or a
#       repository whose OWN visibility could not be established — because if
#       we cannot say whether the source is private, the rule above cannot be
#       applied to it either way.
#
# PRECEDENCE: 1 OUTRANKS 2, which is the OPPOSITE of the precedence in
# verify-submodule-remote-sync.sh and verify-manifest-pins.sh, and the
# difference is deliberate rather than an oversight. Those gates answer "is
# everything in sync?", a universally quantified claim that an incomplete sweep
# cannot support. This one answers "does anything leak?", an existential claim:
# a confirmed leak is confirmed whether or not some other row was readable, and
# hiding it behind an unrelated uninitialised submodule would be the worse
# error. It is the same precedence, for the same reason, that
# verify-content-boundary.sh asserts by mutation. Both states are always
# printed; a 1 never suppresses the list of rows that could not be determined.
#
# ── Usage ────────────────────────────────────────────────────────────────────
#   scripts/verify-push-topology.sh [--root <dir>] [--quiet] [--timeout <n>]
#   scripts/verify-push-topology.sh --prove-failure [--quiet]
#     --root <dir>     project root to verify (default: this script's parent).
#     --quiet          suppress the table and PASS lines. FINDINGS, UNDET and
#                      the summary are ALWAYS shown.
#     --timeout <n>    seconds per provider probe (default 30). A probe that
#                      times out yields visibility `unknown`, never a pass.
#     --prove-failure  run the paired §1.1 mutation proof (see the bottom).
#     -h|--help        this header.
#
# ── Side-effects ─────────────────────────────────────────────────────────────
#   Default mode: STRICTLY READ-ONLY, and it NEVER CONTACTS A GIT REMOTE. It
#   reads each checkout's remote configuration with `git remote -v` /
#   `git remote get-url --all --push` and asks the PROVIDER API about
#   visibility. It never runs push, fetch, ls-remote, or `remote add/set-url`.
#   Nothing in any `.git/config` is written, and no disabled upstream recipe is
#   enabled.
#   --prove-failure: writes ONLY inside a `mktemp -d` sandbox, trap-removed,
#   and makes NO network calls at all — the provider adapters are PATH-shimmed.
#
# ── SECRETS ARE NEVER PRINTED ────────────────────────────────────────────────
# A remote url may legitimately carry credentials in its userinfo field
# (`https://user:token@host/owner/name.git`). Every url this gate prints passes
# through redact_url(), which replaces the whole userinfo with `<redacted>@`
# BEFORE the string reaches any output stream. The parser reads the host from
# the redacted form for the same reason. Assertion M7 of the paired proof seeds
# a url containing a token-shaped secret and fails if the secret appears
# anywhere in the gate's output.
#
# ── Dependencies ─────────────────────────────────────────────────────────────
#   bash, git, POSIX awk/grep/sed/sort. `timeout` is used when present and its
#   absence is REPORTED rather than silently ignored.
#   Optional per provider (absence downgrades a destination to `unknown`, never
#   to `public` and never to a pass) — same adapter registry, same host mapping
#   and same vocabulary as scripts/verify-provider-ci.sh, so the two gates can
#   never disagree about which hosts this tree can interrogate:
#     github.com  -> `gh`,   authenticated
#     gitlab.com  -> `glab`, authenticated, plus `jq`
#   Any other host has NO adapter registered. Measured on this tree 2026-09-06,
#   the push urls name four hosts: github.com, gitlab.com, gitflic.ru and
#   gitverse.ru. The last two have no adapter, which is precisely why the
#   finding on this tree exists.
#
# ── Honest boundaries (§11.4.6) ──────────────────────────────────────────────
#   1. This gate reads CONFIGURATION, not history. It establishes that a push
#      to remote R WOULD send to destination D. It does NOT establish that any
#      push ever happened, nor what it contained. A finding is a live egress
#      PATH, never evidence of an actual disclosure.
#   2. Push urls live in untracked `.git/config`. This is therefore a statement
#      about THIS CHECKOUT on THIS HOST, and a fresh clone will have different
#      answers. That is not a defect of the gate; it is the reason a
#      tracked-file instrument could never have found any of this.
#   3. Visibility is asked of the provider at this moment and is a dated
#      observation. A repository can be flipped public-to-private outside this
#      tree and nothing here can see that happen.
#   4. `push.default`, refspecs, branch-level `remote.pushDefault` and hooks
#      are NOT modelled. The gate answers "which destinations does this remote
#      name", not "which of them would a given `git push` invocation reach".
#   5. It cannot see a fan-out configured in a remote this checkout does not
#      have, nor one implemented by a push hook rather than by a url.
# ─────────────────────────────────────────────────────────────────────────────

set -uo pipefail

GATE="CM-PUSH-TOPOLOGY"

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
probe_timeout=30
prove=""

while [ $# -gt 0 ]; do
    case "$1" in
        --root)    root="${2:-}"; shift 2 ;;
        --quiet)   quiet="1"; shift ;;
        --timeout) probe_timeout="${2:-}"; shift 2 ;;
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
bad()  { fail=$((fail+1));   echo "❌ EGRESS $1"; }
und()  { undet=$((undet+1)); echo "⚠ UNDET $1"; }
inf()  { note=$((note+1));   [ -n "$quiet" ] || echo "ℹ NOTE  $1"; }

export GIT_TERMINAL_PROMPT=0

HAVE_TIMEOUT=""
command -v timeout >/dev/null 2>&1 && HAVE_TIMEOUT="1"

run_bounded() {
    if [ -n "$HAVE_TIMEOUT" ]; then timeout "$probe_timeout" "$@"; else "$@"; fi
}

# ─────────────────────────────────────────────────────────────────────────────
# URL handling. Redaction happens FIRST, and parsing reads the redacted form,
# so no code path downstream of here has a credential to leak.
# ─────────────────────────────────────────────────────────────────────────────

# redact_url <url> — strip any userinfo, EXCEPT the bare, universal, secret-free
# ssh user `git`, whose presence is load-bearing information about the url form.
# Anything else in the userinfo position — a username, a token, a user:password
# pair — is replaced wholesale. This is deliberately over-broad: a username is
# not a secret, but distinguishing "username" from "token" by shape is exactly
# the kind of guess that eventually prints one.
redact_url() {
    printf '%s' "$1" | sed -E 's#^([a-zA-Z][a-zA-Z0-9+.-]*://)?(git@)?([^/@]+@)#\1\2<redacted>@#'
}

# url_host <redacted-url> — the host, port stripped, lowercased.
url_host() {
    printf '%s' "$1" \
        | sed -E 's#^[a-zA-Z][a-zA-Z0-9+.-]*://##; s#^[^/@]*@##; s#[:/].*$##' \
        | tr 'A-Z' 'a-z'
}

# url_path <redacted-url> — `owner/name`, `.git` and a leading `/` removed.
# Takes the LAST TWO path segments, which is correct for every form this fleet
# uses (scp-like `git@h:o/n.git`, `ssh://git@h:2222/o/n.git`, `https://h/o/n`)
# and yields the empty string for a `file://` fixture path, which is then
# reported as unclassifiable rather than guessed at.
url_path() {
    printf '%s' "$1" \
        | sed -E 's#^[a-zA-Z][a-zA-Z0-9+.-]*://##; s#^[^/@]*@##; s#^[^:/]*(:[0-9]+)?[:/]##; s#\.git$##; s#/+$##' \
        | awk -F/ 'NF>=2{print $(NF-1) "/" $NF; next} {print ""}'
}

# ─────────────────────────────────────────────────────────────────────────────
# Provider adapters. Registry, host mapping and vocabulary are deliberately the
# same as scripts/verify-provider-ci.sh — a second, subtly different opinion
# about which hosts are interrogable is a drift generator.
# ─────────────────────────────────────────────────────────────────────────────
adapter_for_host() {
    case "$1" in
        github.com|github.*) printf 'gh' ;;
        gitlab.com|gitlab.*) printf 'glab' ;;
        *) printf '' ;;
    esac
}

GH_STATE="absent";   GH_REASON="the 'gh' CLI is not installed"
GLAB_STATE="absent"; GLAB_REASON="the 'glab' CLI is not installed"

init_adapters() {
    GH_STATE="absent"; GH_REASON="the 'gh' CLI is not installed"
    if command -v gh >/dev/null 2>&1; then
        if run_bounded gh auth status >/dev/null 2>&1; then
            GH_STATE="ready"; GH_REASON=""
        else
            GH_STATE="broken"; GH_REASON="the 'gh' CLI is installed but not authenticated"
        fi
    fi
    GLAB_STATE="absent"; GLAB_REASON="the 'glab' CLI is not installed"
    if command -v glab >/dev/null 2>&1; then
        if ! command -v jq >/dev/null 2>&1; then
            GLAB_STATE="broken"; GLAB_REASON="glab is installed but 'jq' is not, and glab returns raw JSON"
        elif run_bounded glab auth status >/dev/null 2>&1; then
            GLAB_STATE="ready"; GLAB_REASON=""
        else
            GLAB_STATE="broken"; GLAB_REASON="glab is installed but not authenticated"
        fi
    fi
}

adapter_state()  { case "$1" in gh) printf '%s' "$GH_STATE" ;; glab) printf '%s' "$GLAB_STATE" ;; *) printf 'none' ;; esac; }
adapter_reason() { case "$1" in gh) printf '%s' "$GH_REASON" ;; glab) printf '%s' "$GLAB_REASON" ;; *) printf 'no read-only API adapter is registered for this host' ;; esac; }

# VIS_CACHE — "host|owner/name" -> "visibility<TAB>resolved-name". One provider
# call per distinct destination however many remotes name it.
declare -A VIS_CACHE=()

# probe_visibility <host> <owner/name> — echoes "<visibility>\t<resolved>".
# visibility is one of public | private | unknown. `unknown` is the ONLY answer
# for an absent adapter, an unauthenticated one, a timeout, or a repository the
# token cannot see; none of those is ever allowed to become `public`, because a
# wrong `public` here silences the finding this gate exists to raise.
probe_visibility() {
    local host="$1" slug="$2" key="$1|$2" ad st out vis="unknown" resolved=""
    if [ -n "${VIS_CACHE[$key]+set}" ]; then printf '%s' "${VIS_CACHE[$key]}"; return 0; fi

    ad="$(adapter_for_host "$host")"
    st="$(adapter_state "$ad")"
    if [ -n "$slug" ] && [ "$st" = "ready" ]; then
        case "$ad" in
            gh)
                out="$(run_bounded gh api "repos/${slug}" --jq '[.visibility,.full_name]|@tsv' 2>/dev/null)"
                ;;
            glab)
                out="$(run_bounded glab api "projects/$(printf '%s' "$slug" | sed 's#/#%2F#g')" 2>/dev/null \
                        | jq -r '[.visibility,.path_with_namespace]|@tsv' 2>/dev/null)"
                ;;
        esac
        case "$out" in
            public*)   vis="public";   resolved="$(printf '%s' "$out" | cut -f2)" ;;
            private*|internal*) vis="private"; resolved="$(printf '%s' "$out" | cut -f2)" ;;
        esac
    fi
    VIS_CACHE[$key]="$(printf '%s\t%s' "$vis" "$resolved")"
    printf '%s' "${VIS_CACHE[$key]}"
}

# ─────────────────────────────────────────────────────────────────────────────
# Fleet derivation. Identical inputs to verify-governance-cascade.sh and
# verify-submodule-remote-sync.sh, so the three gates can never disagree about
# who is in the fleet. NO HARDCODED ROSTER — a name list is the same defect
# class these gates exist to catch.
# ─────────────────────────────────────────────────────────────────────────────
gitmodules_paths() {
    awk '
        function val(line) {
            sub(/^[^=]*=[[:space:]]*/, "", line)
            gsub(/^[[:space:]]+/, "", line); gsub(/[[:space:]]+$/, "", line)
            return line
        }
        /^[[:space:]]*path[[:space:]]*=/ { print val($0) }
    ' "$1"
}

helix_excluded_paths() {
    sed -nE 's/^#[[:space:]]+([^[:space:]]+)[[:space:]]+->[[:space:]]+git@.*/\1/p' "$1"
}

# remote_names <dir>
remote_names() { git -C "$1" remote 2>/dev/null; }

# push_urls <dir> <remote> — ALL push urls, one per line.
#
# THE METHOD TRAP LIVES HERE. `git remote get-url --push` prints only the first
# and would report a six-way fan-out as one destination, so `--all` is not
# optional. `git remote -v` is used as the cross-check because it is the form
# that also reports direction; when the two disagree the LARGER set wins, since
# undercounting an egress path is the failure that matters.
push_urls() {
    local dir="$1" rem="$2" a b
    a="$(git -C "$dir" remote get-url --all --push "$rem" 2>/dev/null)"
    b="$(git -C "$dir" remote -v 2>/dev/null | awk -v r="$rem" '$1==r && $3=="(push)"{print $2}')"
    if [ "$(printf '%s\n' "$b" | grep -c .)" -gt "$(printf '%s\n' "$a" | grep -c .)" ]; then
        printf '%s\n' "$b"
    else
        printf '%s\n' "$a"
    fi
}

fetch_url() { git -C "$1" remote get-url "$2" 2>/dev/null; }

# ─────────────────────────────────────────────────────────────────────────────
# The check.
# ─────────────────────────────────────────────────────────────────────────────
declare -a ROW_PATH=() ROW_DIR=() ROW_OWNED=()

check_push_topology() {
    local gm="${root}/.gitmodules" hd="${root}/${MANIFEST_NAME}"
    local excl="" p i n=0 total_targets=0 fanout_repos=0

    if ! command -v git >/dev/null 2>&1; then
        und "PUSH-TOPOLOGY — git is not on PATH; no remote configuration can be read"
        return 2
    fi
    [ -n "$HAVE_TIMEOUT" ] || inf "PUSH-TOPOLOGY · \`timeout\` is not on PATH; provider probes run unbounded. A hung provider will stall this gate rather than yielding \`unknown\` (§11.4.6: stated, not silently accepted)"

    # The umbrella root is always row 0 — it has push urls of its own and no
    # other instrument reads them either.
    ROW_PATH+=("."); ROW_DIR+=("$root"); ROW_OWNED+=(1)

    if [ -r "$gm" ]; then
        if [ -r "$hd" ]; then
            excl="$(helix_excluded_paths "$hd")"
        else
            inf "PUSH-TOPOLOGY · ${MANIFEST_NAME} unreadable at ${hd}; no gitlink can be classified third-party from evidence, so ALL are treated as OWNED — the conservative direction (§11.4.6)"
        fi
        while IFS= read -r p; do
            [ -n "$p" ] || continue
            local owned=1
            if [ -n "$excl" ] && grep -qxF "$p" <<<"$excl"; then owned=0; fi
            ROW_PATH+=("$p"); ROW_DIR+=("${root}/${p}"); ROW_OWNED+=("$owned")
        done <<< "$(gitmodules_paths "$gm")"
    else
        inf "PUSH-TOPOLOGY · no .gitmodules at ${gm}; only the root repository is examined"
    fi

    init_adapters
    [ "$GH_STATE"   = "ready" ] || inf "PUSH-TOPOLOGY · github.com adapter unavailable: ${GH_REASON}. Every github.com destination will read \`unknown\`, never \`public\`"
    [ "$GLAB_STATE" = "ready" ] || inf "PUSH-TOPOLOGY · gitlab.com adapter unavailable: ${GLAB_REASON}. Every gitlab.com destination will read \`unknown\`, never \`public\`"

    [ -n "$quiet" ] || {
        printf '   %-28s %-9s %-5s %-7s %s\n' "repository" "self" "rem" "targets" "verdict"
        printf '   %-28s %-9s %-5s %-7s %s\n' "----------------------------" "---------" "-----" "-------" "-------"
    }

    for i in "${!ROW_PATH[@]}"; do
        local path="${ROW_PATH[$i]}" dir="${ROW_DIR[$i]}" owned="${ROW_OWNED[$i]}"
        n=$((n + 1))

        # ── Uninitialised submodule: rc 2 for this row, NEVER a pass. Its push
        #    urls live in a `.git/config` that does not exist, so "no fan-out
        #    found" here would be an artefact of absence, not a measurement.
        if [ ! -e "${dir}/.git" ] || ! git -C "$dir" rev-parse --git-dir >/dev/null 2>&1; then
            [ -n "$quiet" ] || printf '   %-28s %-9s %-5s %-7s %s\n' "$path" "-" "-" "-" "UNINITIALISED"
            if [ "$owned" -eq 1 ]; then
                und "PUSH-TOPOLOGY ${path} — declared but NOT INITIALISED; its .git/config does not exist, so its push urls cannot be read. Absence of a finding here is absence of evidence, not a pass."
                echo "           fix: git submodule update --init -- ${path}  (operator decision), then re-run."
            else
                inf "PUSH-TOPOLOGY · ${path} — third-party and not initialised; not examined"
            fi
            continue
        fi

        # ── This repository's own identity and visibility, from its `origin`
        #    FETCH url (falling back to the first remote that has one).
        local self_fetch="" rem
        self_fetch="$(fetch_url "$dir" origin)"
        if [ -z "$self_fetch" ]; then
            while IFS= read -r rem; do
                [ -n "$rem" ] || continue
                self_fetch="$(fetch_url "$dir" "$rem")"
                [ -n "$self_fetch" ] && break
            done <<< "$(remote_names "$dir")"
        fi
        local self_r self_host self_slug self_vis="unknown" self_resolved="" vr
        self_r="$(redact_url "$self_fetch")"
        self_host="$(url_host "$self_r")"; self_slug="$(url_path "$self_r")"
        if [ -n "$self_host" ]; then
            vr="$(probe_visibility "$self_host" "$self_slug")"
            self_vis="$(printf '%s' "$vr" | cut -f1)"; self_resolved="$(printf '%s' "$vr" | cut -f2)"
        fi

        # ── Collect every distinct push destination across every remote.
        local -a t_url=() t_host=() t_slug=() t_remotes=()
        local first_push_host=""
        while IFS= read -r rem; do
            [ -n "$rem" ] || continue
            local u ru h s k j found
            while IFS= read -r u; do
                [ -n "$u" ] || continue
                ru="$(redact_url "$u")"; h="$(url_host "$ru")"; s="$(url_path "$ru")"
                [ -n "$first_push_host" ] || first_push_host="$h"
                k="${h}|${s}"
                found=""
                for j in "${!t_url[@]}"; do
                    if [ "${t_host[$j]}|${t_slug[$j]}" = "$k" ]; then
                        t_remotes[$j]="${t_remotes[$j]},${rem}"; found=1; break
                    fi
                done
                [ -n "$found" ] && continue
                t_url+=("$ru"); t_host+=("$h"); t_slug+=("$s"); t_remotes+=("$rem")
            done <<< "$(push_urls "$dir" "$rem")"
        done <<< "$(remote_names "$dir")"

        local ntargets="${#t_url[@]}"
        total_targets=$((total_targets + ntargets))

        if [ "$ntargets" -eq 0 ]; then
            [ -n "$quiet" ] || printf '   %-28s %-9s %-5s %-7s %s\n' "$path" "$self_vis" "0" "0" "NO-PUSH"
            if [ "$owned" -eq 1 ]; then
                ok "PUSH-TOPOLOGY ${path} — no remote declares a push url; nothing can leave this checkout by push"
            else
                inf "PUSH-TOPOLOGY · ${path} — third-party with no push url"
            fi
            continue
        fi

        # ── Source visibility unknown => the rule cannot be applied. rc 2.
        if [ "$self_vis" = "unknown" ]; then
            [ -n "$quiet" ] || printf '   %-28s %-9s %-5s %-7s %s\n' "$path" "unknown" "$(remote_names "$dir" | grep -c .)" "$ntargets" "UNDETERMINED"
            if [ "$owned" -eq 1 ]; then
                und "PUSH-TOPOLOGY ${path} — the visibility of this repository ITSELF could not be established from ${self_host:-<no host>}/${self_slug:-<no path>} ($(adapter_reason "$(adapter_for_host "$self_host")")). Whether its ${ntargets} push destination(s) are a disclosure risk therefore cannot be answered either way."
            else
                inf "PUSH-TOPOLOGY · ${path} — third-party and self-visibility unknown; reported, never gating"
            fi
            continue
        fi

        # ── Classify each destination.
        local j leaks=0 pub=0 priv=0 unk=0 detail=""
        for j in "${!t_url[@]}"; do
            local dvis dres
            if [ -n "${t_slug[$j]}" ] && [ -n "${t_host[$j]}" ]; then
                vr="$(probe_visibility "${t_host[$j]}" "${t_slug[$j]}")"
                dvis="$(printf '%s' "$vr" | cut -f1)"; dres="$(printf '%s' "$vr" | cut -f2)"
            else
                dvis="unknown"; dres=""
            fi
            case "$dvis" in
                public)  pub=$((pub+1)) ;;
                private) priv=$((priv+1)) ;;
                *)       unk=$((unk+1)) ;;
            esac

            # Rename-redirect note: the provider resolved the requested name to
            # a different one. Measured, not inferred.
            if [ -n "$dres" ] && [ -n "${t_slug[$j]}" ] && [ "$dres" != "${t_slug[$j]}" ]; then
                inf "PUSH-TOPOLOGY · ${path} — push url names ${t_host[$j]}/${t_slug[$j]} but the provider RESOLVES it to ${t_host[$j]}/${dres}. This destination is reached only through a RENAME REDIRECT; it works today and is measured, not assumed. A redirect survives only while the old name stays unclaimed."
            fi

            if [ "$self_vis" = "private" ] && [ "$dvis" != "private" ]; then
                leaks=$((leaks+1))
                if [ "$dvis" = "public" ]; then
                    detail="${detail}
           → ${t_url[$j]}  [remote(s): ${t_remotes[$j]}]  destination is CONFIRMED PUBLIC"
                else
                    detail="${detail}
           → ${t_url[$j]}  [remote(s): ${t_remotes[$j]}]  destination visibility UNVERIFIABLE: $(adapter_reason "$(adapter_for_host "${t_host[$j]}")")"
                fi
            fi
        done

        # ── Notes that never gate.
        if [ "$ntargets" -gt 1 ]; then
            fanout_repos=$((fanout_repos + 1))
            [ "$self_vis" = "public" ] && inf "PUSH-TOPOLOGY · ${path} — PUBLIC repository fanning out to ${ntargets} destination(s) (${pub} public, ${priv} private, ${unk} unverifiable). Nothing can be disclosed that is not already disclosed, so this is reported and never gating."
        fi
        if [ -n "$first_push_host" ] && [ -n "$self_host" ] && [ "$first_push_host" != "$self_host" ]; then
            inf "PUSH-TOPOLOGY · ${path} — fetches from ${self_host} but its FIRST push destination is ${first_push_host}. A plain \`git push\` does not send where \`git pull\` reads from."
        fi

        local verdict="OK"
        [ "$leaks" -gt 0 ] && verdict="EGRESS"
        [ -n "$quiet" ] || printf '   %-28s %-9s %-5s %-7s %s\n' "$path" "$self_vis" "$(remote_names "$dir" | grep -c .)" "$ntargets" "$verdict"

        if [ "$owned" -eq 0 ]; then
            inf "PUSH-TOPOLOGY · ${path} — third-party (${self_vis}) with ${ntargets} destination(s); a vendor's remote layout is not ours to fix, so this is reported and never gating"
            continue
        fi

        if [ "$leaks" -gt 0 ]; then
            bad "PUSH-TOPOLOGY ${path} — PRIVATE repository with ${leaks} of ${ntargets} push destination(s) this tree CANNOT establish as private:${detail}"
            echo "           A push is not reversible: once objects land on a host, removing the ref does not unpublish them."
            echo "           fix: remove the destination(s) from this checkout's remote configuration, or register a"
            echo "                read-only API adapter for the host so its visibility can be established from evidence."
            continue
        fi

        ok "PUSH-TOPOLOGY ${path} — ${self_vis} repository; all ${ntargets} push destination(s) accounted for (${pub} public, ${priv} private, ${unk} unverifiable)"
    done

    [ -n "$quiet" ] || echo "----------------------------------------------------------------------"
    echo "${GATE}: ${pass} OK, ${fail} EGRESS, ${undet} UNDETERMINED, ${note} NOTE  over ${n} repositor(y|ies), ${total_targets} distinct push destination(s), ${fanout_repos} fan-out(s)  (root ${root})"

    _verdict_emitted=1
    # PRECEDENCE: 1 OUTRANKS 2. See the header — this gate answers an
    # EXISTENTIAL question, so a confirmed leak stands whether or not some
    # other row was readable. Both are always printed.
    if [ "$fail" -gt 0 ]; then
        echo "❌ ${GATE}: FAIL — ${fail} private repositor(y|ies) can push to a destination this tree cannot vouch for."
        [ "$undet" -gt 0 ] && echo "   ${undet} further row(s) could NOT be determined and are printed above; they are not passes."
        return 1
    fi
    if [ "$undet" -gt 0 ]; then
        echo "⚠ ${GATE}: CANNOT VERIFY — ${undet} repositor(y|ies) could not be classified."
        echo "   This is NOT a pass and MUST NOT be recorded as one."
        return 2
    fi
    echo "✅ ${GATE}: PASS — every repository's push destinations were classified, and no private"
    echo "   repository can push to a destination whose visibility this tree cannot establish."
    echo "   Dated observation, not a standing fact: visibility is a provider setting (boundary 3)."
    return 0
}

# ─────────────────────────────────────────────────────────────────────────────
# §1.1 PAIRED MUTATION PROOF
#
# Entirely offline and entirely synthetic. Every mutation is DATA — a real
# local git repository in a mktemp sandbox with a deliberately seeded remote
# configuration, plus a PATH-shimmed provider whose answers come from a fixture
# TABLE. Not one of them edits this gate. The shim technique is the one
# scripts/verify-provider-ci.sh already uses for the same purpose, and it works
# here precisely because this gate NEVER CONTACTS A GIT REMOTE: the seeded urls
# only have to parse, not to resolve, so the real shipped code path — the same
# parser, the same adapter registry, the same verdict logic — runs untouched.
#
#   M1 six push urls on ONE remote are ALL enumerated       -> reports 6, not 1
#      (THE METHOD TRAP. `get-url --push` prints one; a gate built on it would
#       report a six-way fan-out as a single destination and this assertion is
#       the only thing standing between that bug and a green run.)
#   M2 PRIVATE repo -> destination on an ADAPTERLESS host   -> rc=1
#   M3 PRIVATE repo -> destination CONFIRMED PUBLIC         -> rc=1
#   M4 PUBLIC repo  -> four-way fan-out incl. adapterless   -> rc=0, noted
#   M5 PRIVATE repo -> only PRIVATE destinations            -> rc=0
#   M6 uninitialised declared submodule                     -> rc=2, never 0
#   M7 a token-shaped secret in a push url                  -> NEVER printed
#   M8 a rename redirect is NAMED, and does not gate        -> rc=0 + both names
#   M9 self-visibility unknown                              -> rc=2, never 0
#   L1 PRECEDENCE: a finding AND an undetermined row together -> rc=1, and the
#      undetermined row is still printed rather than suppressed.
#
# M2 and M6 are the two that matter most. If M2 ever returned 0 this gate would
# be decorative on the exact tree that motivated it; if M6 ever returned 0, an
# uninitialised submodule would read as "no fan-out found", which is absence of
# evidence sold as evidence of absence.
# ─────────────────────────────────────────────────────────────────────────────
prove_failure() {
    local sandbox mut_fails=0
    echo "${GATE} §1.1 PAIRED MUTATION PROOF"
    echo "----------------------------------------------------------------------"

    if ! command -v git >/dev/null 2>&1; then
        echo "${GATE}: cannot verify — git is not on PATH, so no fixture can be built" >&2
        return 2
    fi
    sandbox="$(mktemp -d)" || { echo "${GATE}: cannot verify — mktemp failed" >&2; return 2; }
    _sandbox_to_clean="$sandbox"

    local G=(-c user.name=proof -c user.email=proof@example.invalid -c commit.gpgsign=false -c init.defaultBranch=main)

    # ── The fixture provider. `gh` and `glab` shims that answer from a TSV
    #    table: "<slug>\t<visibility>\t<resolved-slug>". Absent from the table
    #    means the repository does not exist -> the shim fails -> `unknown`,
    #    which is exactly what a real provider does for a repo it cannot see.
    mkdir -p "${sandbox}/bin" || { echo "${GATE}: cannot verify — sandbox unusable" >&2; return 2; }
    cat > "${sandbox}/vis.tsv" <<'EOF'
fixture/priv	private	fixture/priv
fixture/pub	public	fixture/pub
fixture/pub2	public	fixture/pub2
fixture/privmirror	private	fixture/privmirror
fixture/oldname	public	fixture/newname
EOF
    cat > "${sandbox}/bin/gh" <<EOF
#!/bin/sh
# fixture provider shim — no network, answers from ${sandbox}/vis.tsv
[ "\$1" = "auth" ] && exit 0
if [ "\$1" = "api" ]; then
    slug=\$(printf '%s' "\$2" | sed 's#^repos/##')
    line=\$(awk -F'\t' -v s="\$slug" '\$1==s{print \$2 "\t" \$3; exit}' "${sandbox}/vis.tsv")
    [ -n "\$line" ] || exit 1
    printf '%s\n' "\$line"; exit 0
fi
exit 1
EOF
    cat > "${sandbox}/bin/glab" <<'EOF'
#!/bin/sh
exit 1
EOF
    chmod +x "${sandbox}/bin/gh" "${sandbox}/bin/glab"

    # mk_repo <dir> — a real git repository with one commit.
    mk_repo() {
        git "${G[@]}" init -q "$1" >/dev/null 2>&1 || return 1
        printf 'x\n' > "$1/f.txt"
        git "${G[@]}" -C "$1" add f.txt >/dev/null 2>&1 || return 1
        git "${G[@]}" -C "$1" commit -qm c1 >/dev/null 2>&1 || return 1
        return 0
    }

    # add_remote <dir> <name> <fetch-url> [push-url...]
    add_remote() {
        local d="$1" nm="$2" fu="$3"; shift 3
        git -C "$d" remote add "$nm" "$fu" >/dev/null 2>&1 || return 1
        local first=1 u
        for u in "$@"; do
            if [ "$first" = 1 ]; then
                git -C "$d" remote set-url --push "$nm" "$u" >/dev/null 2>&1 || return 1
                first=0
            else
                git -C "$d" remote set-url --add --push "$nm" "$u" >/dev/null 2>&1 || return 1
            fi
        done
        return 0
    }

    # declare_sub <root> <path> — a .gitmodules entry plus an index gitlink,
    # WITHOUT a working tree. That is the uninitialised-submodule fixture.
    declare_sub() {
        printf '[submodule "%s"]\n\tpath = %s\n\turl = git@github.com:fixture/%s.git\n' \
               "$2" "$2" "$2" >> "$1/.gitmodules"
    }

    assert_case() {
        local name="$1" want="$2" expect="$3" dir="$4"
        local out orc
        out="$(PATH="${sandbox}/bin:$PATH" bash "$0" --root "$dir" 2>&1)"; orc=$?
        if [ "$orc" -ne "$want" ]; then
            echo "❌ ${name}"
            echo "                        -> rc=${orc}, wanted ${want}. THIS GATE WOULD BE A SHAM (§1.1)."
            printf '%s\n' "$out" | sed 's/^/        /'
            mut_fails=$((mut_fails+1)); return
        fi
        if [ -n "$expect" ] && ! grep -qF -- "$expect" <<<"$out"; then
            echo "❌ ${name}"
            echo "                        -> rc=${orc} as wanted, but the verdict never said '${expect}'."
            echo "                           A finding that does not name the destination is unactionable (§11.4.6)."
            printf '%s\n' "$out" | sed 's/^/        /'
            mut_fails=$((mut_fails+1)); return
        fi
        echo "✅ ${name}"
        echo "                        -> rc=${orc} (wanted ${want})${expect:+  named '${expect}'}"
    }

    # ── M1 THE METHOD TRAP — six push urls on ONE remote ─────────────────────
    mk_repo "${sandbox}/m1" || { echo "${GATE}: cannot verify — fixture m1" >&2; return 2; }
    add_remote "${sandbox}/m1" origin "git@github.com:fixture/pub.git" \
        "git@github.com:fixture/pub.git" "git@github.com:fixture/pub2.git" \
        "git@gitlab.com:fixture/pub.git" "git@gitflic.ru:fixture/pub.git" \
        "ssh://git@gitverse.ru:2222/fixture/pub.git" "git@nowhere.invalid:fixture/pub.git" \
        || { echo "${GATE}: cannot verify — fixture m1 remotes" >&2; return 2; }
    local m1_seen
    m1_seen="$(git -C "${sandbox}/m1" remote get-url --all --push origin | grep -c .)"
    local m1_trap
    m1_trap="$(git -C "${sandbox}/m1" remote get-url --push origin 2>/dev/null | grep -c .)"
    assert_case "M1 method trap        — 6 push urls on ONE remote are ALL enumerated        " 0 "6 distinct push destination" "${sandbox}/m1"
    echo "                           (control: \`get-url --all --push\` sees ${m1_seen}; the trap form \`get-url --push\` sees ${m1_trap})"
    if [ "$m1_seen" -ne 6 ] || [ "$m1_trap" -ne 1 ]; then
        echo "❌ M1 control            — the fixture itself is wrong (${m1_seen}/${m1_trap}); the assertion above proves nothing"
        mut_fails=$((mut_fails+1))
    fi

    # ── M2 PRIVATE -> ADAPTERLESS HOST — the finding this gate exists for ────
    mk_repo "${sandbox}/m2" || { echo "${GATE}: cannot verify — fixture m2" >&2; return 2; }
    add_remote "${sandbox}/m2" origin "git@github.com:fixture/priv.git" \
        "git@github.com:fixture/priv.git" "git@gitflic.ru:fixture/priv.git" \
        || { echo "${GATE}: cannot verify — fixture m2 remotes" >&2; return 2; }
    assert_case "M2 private->adapterless— destination host cannot be vouched for; MUST be 1  " 1 "UNVERIFIABLE" "${sandbox}/m2"

    # ── M3 PRIVATE -> CONFIRMED PUBLIC ───────────────────────────────────────
    mk_repo "${sandbox}/m3" || { echo "${GATE}: cannot verify — fixture m3" >&2; return 2; }
    add_remote "${sandbox}/m3" origin "git@github.com:fixture/priv.git" \
        "git@github.com:fixture/pub.git" \
        || { echo "${GATE}: cannot verify — fixture m3 remotes" >&2; return 2; }
    assert_case "M3 private->public    — a CONFIRMED public destination for private content  " 1 "CONFIRMED PUBLIC" "${sandbox}/m3"

    # ── M4 PUBLIC fan-out — noisy trees must NOT gate ────────────────────────
    mk_repo "${sandbox}/m4" || { echo "${GATE}: cannot verify — fixture m4" >&2; return 2; }
    add_remote "${sandbox}/m4" origin "git@github.com:fixture/pub.git" \
        "git@github.com:fixture/pub.git" "git@github.com:fixture/pub2.git" \
        "git@gitflic.ru:fixture/pub.git" "git@gitverse.ru:fixture/pub.git" \
        || { echo "${GATE}: cannot verify — fixture m4 remotes" >&2; return 2; }
    assert_case "M4 public fan-out     — 4 destinations incl. adapterless; reported, NOT 1   " 0 "PUBLIC repository fanning out" "${sandbox}/m4"

    # ── M5 PRIVATE -> only PRIVATE destinations ──────────────────────────────
    mk_repo "${sandbox}/m5" || { echo "${GATE}: cannot verify — fixture m5" >&2; return 2; }
    add_remote "${sandbox}/m5" origin "git@github.com:fixture/priv.git" \
        "git@github.com:fixture/priv.git" "git@github.com:fixture/privmirror.git" \
        || { echo "${GATE}: cannot verify — fixture m5 remotes" >&2; return 2; }
    assert_case "M5 private->private   — a verified-private mirror is legitimate; MUST be 0  " 0 "2 private" "${sandbox}/m5"

    # ── M6 UNINITIALISED SUBMODULE — absence is not a pass ───────────────────
    mk_repo "${sandbox}/m6" || { echo "${GATE}: cannot verify — fixture m6" >&2; return 2; }
    add_remote "${sandbox}/m6" origin "git@github.com:fixture/pub.git" "git@github.com:fixture/pub.git" \
        || { echo "${GATE}: cannot verify — fixture m6 remotes" >&2; return 2; }
    declare_sub "${sandbox}/m6" "ghost"
    assert_case "M6 uninitialised sub  — .git/config absent; MUST be 2, never 0              " 2 "NOT INITIALISED" "${sandbox}/m6"

    # ── M7 SECRETS ARE NEVER PRINTED ─────────────────────────────────────────
    # A url carrying a token-shaped credential. The assertion is the ABSENCE of
    # the token — but absence alone proves nothing, because a url that is never
    # reported also never leaks. So the fixture is built to FORCE the url into
    # the output: a PRIVATE source pushing to a CONFIRMED PUBLIC destination is
    # the one row whose url the gate prints verbatim. The assertion therefore
    # demands all three of rc=1, the redacted form present, and the token
    # absent. (The first draft of this fixture used a PUBLIC source; it passed
    # the "token absent" half for the trivial reason that no url was printed at
    # all, and this proof caught that. Recorded because a vacuous assertion is
    # exactly what §1.1 exists to prevent.)
    local SECRET="ghp_FIXTUREtoken0123456789abcdefGHIJ"
    mk_repo "${sandbox}/m7" || { echo "${GATE}: cannot verify — fixture m7" >&2; return 2; }
    add_remote "${sandbox}/m7" origin "git@github.com:fixture/priv.git" \
        "https://u:${SECRET}@github.com/fixture/pub.git" \
        || { echo "${GATE}: cannot verify — fixture m7 remotes" >&2; return 2; }
    local m7_out m7_rc
    m7_out="$(PATH="${sandbox}/bin:$PATH" bash "$0" --root "${sandbox}/m7" 2>&1)"; m7_rc=$?
    if grep -qF -- "$SECRET" <<<"$m7_out"; then
        echo "❌ M7 secret redaction   — THE TOKEN WAS PRINTED. This gate would exfiltrate a credential into"
        echo "                           every log that captures it. Nothing else it reports would matter."
        mut_fails=$((mut_fails+1))
    elif [ "$m7_rc" -ne 1 ] || ! grep -qF -- "<redacted>@github.com" <<<"$m7_out"; then
        echo "❌ M7 secret redaction   — rc=${m7_rc} (wanted 1) and/or the redacted url never appeared, so the"
        echo "                           'token absent' half is VACUOUS: a url that is not printed cannot leak."
        printf '%s\n' "$m7_out" | sed 's/^/        /'
        mut_fails=$((mut_fails+1))
    else
        echo "✅ M7 secret redaction   — a token-shaped credential in a push url is NEVER printed"
        echo "                        -> rc=${m7_rc} (wanted 1, so the url IS printed), reported as"
        echo "                           'https://<redacted>@github.com/fixture/pub.git', token absent from all output"
    fi

    # ── M8 RENAME REDIRECT — named, and does not gate ────────────────────────
    mk_repo "${sandbox}/m8" || { echo "${GATE}: cannot verify — fixture m8" >&2; return 2; }
    add_remote "${sandbox}/m8" origin "git@github.com:fixture/pub.git" "git@github.com:fixture/oldname.git" \
        || { echo "${GATE}: cannot verify — fixture m8 remotes" >&2; return 2; }
    assert_case "M8 rename redirect    — provider resolves a different name; named, NOT 1    " 0 "RENAME REDIRECT" "${sandbox}/m8"

    # ── M9 SELF-VISIBILITY UNKNOWN — the rule cannot be applied ──────────────
    mk_repo "${sandbox}/m9" || { echo "${GATE}: cannot verify — fixture m9" >&2; return 2; }
    add_remote "${sandbox}/m9" origin "git@gitflic.ru:fixture/whoknows.git" "git@gitflic.ru:fixture/whoknows.git" \
        || { echo "${GATE}: cannot verify — fixture m9 remotes" >&2; return 2; }
    assert_case "M9 self-vis unknown   — source cannot be classified; MUST be 2, never 0     " 2 "could not be established" "${sandbox}/m9"

    # ── L1 PRECEDENCE — a finding AND an undetermined row in ONE tree ────────
    # 1 must outrank 2 here (see the header), and the undetermined row must
    # still be printed. Asserting only the rc would let a gate pass this while
    # silently swallowing the other row.
    mk_repo "${sandbox}/l1" || { echo "${GATE}: cannot verify — fixture l1" >&2; return 2; }
    add_remote "${sandbox}/l1" origin "git@github.com:fixture/priv.git" \
        "git@gitflic.ru:fixture/priv.git" \
        || { echo "${GATE}: cannot verify — fixture l1 remotes" >&2; return 2; }
    declare_sub "${sandbox}/l1" "ghost"
    local l1_out l1_rc
    l1_out="$(PATH="${sandbox}/bin:$PATH" bash "$0" --root "${sandbox}/l1" 2>&1)"; l1_rc=$?
    if [ "$l1_rc" -ne 1 ]; then
        echo "❌ L1 precedence         — rc=${l1_rc}, wanted 1. A confirmed leak must not be hidden behind an"
        echo "                           unrelated uninitialised submodule."
        mut_fails=$((mut_fails+1))
    elif ! grep -qF -- "NOT INITIALISED" <<<"$l1_out"; then
        echo "❌ L1 precedence         — rc=1 as wanted, but the UNDETERMINED row was SUPPRESSED. A gate that"
        echo "                           drops rows once it has a finding under-reports the tree (§11.4.6)."
        mut_fails=$((mut_fails+1))
    else
        echo "✅ L1 precedence         — a finding outranks an undetermined row, and the row is still printed"
        echo "                        -> rc=${l1_rc} (wanted 1)  and 'NOT INITIALISED' still appears"
    fi

    # ── RESTORED CONTROL ─────────────────────────────────────────────────────
    assert_case "CONTROL restored      — the M4 specimen is still green                      " 0 "PASS" "${sandbox}/m4"

    rm -rf "$sandbox"; _sandbox_to_clean=""
    echo "----------------------------------------------------------------------"
    _verdict_emitted=1
    if [ "$mut_fails" -eq 0 ]; then
        echo "✅ ${GATE} §1.1 MUTATION PROOF: PASS — 11 assertions over 10 fixture trees, every"
        echo "   mutation DATA (a seeded git remote configuration plus a PATH-shimmed provider"
        echo "   answering from a fixture table), not one an edit to this gate, and no network."
        echo "   Proved: all six push urls on one remote are enumerated and the \`get-url --push\`"
        echo "   trap form sees only one; a private repository reaching an adapterless host is 1;"
        echo "   a private repository reaching a CONFIRMED public host is 1; a public fan-out to"
        echo "   four hosts is 0 and merely noted; a private-to-private mirror is 0; an"
        echo "   UNINITIALISED submodule is 2 and never 0; a credential in a push url is never"
        echo "   printed; a rename redirect is named without gating; an unclassifiable source is"
        echo "   2; and a finding outranks an undetermined row WITHOUT suppressing it."
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

echo "${GATE}: enumerating every remote's FETCH and ALL PUSH urls, under ${root}"
echo "   read-only · no git remote is contacted · credentials in urls are redacted before printing"
echo "----------------------------------------------------------------------"
check_push_topology
exit $?
