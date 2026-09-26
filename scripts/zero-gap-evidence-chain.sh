#!/usr/bin/env bash
# zero-gap-evidence-chain.sh — feature 010 evidence CHAIN + ANCHOR verifier (task T014).
#
# Purpose
#   Decides whether a two-file evidence store written by
#   scripts/zero-gap-evidence.sh is intact, in FOUR independent parts, and
#   reports each part separately (the pair "chain PASS / anchor DETECTED" is
#   itself the evidence that the anchor, not the chain, carries truncation):
#     1 chain    upstream `continuum-integrity chain verify` (the constitution's
#                verifier; its walk is never re-implemented here)
#     2 sidecar  every adapter invariant of data-model.md, BY POSITION — the
#                upstream verifier never reads the sidecar (research.md T001)
#     3 anchor   upstream `continuum-integrity anchor verify` against the anchor
#                record {head_digest, entry_count, anchor_strength}
#     4 history  per-COMMIT forward-only walk of a git-tracked anchor: entry_count
#                never drops, and every committed head_digest is still the digest
#                of the chain record at that position
#
# Where things live (operator ruling, review T015 finding 2)
#   chain + sidecar + streams   UNTRACKED under .remember/logs/zero-gap/evidence/
#                               (git-ignored by .remember/.gitignore; they carry
#                               stream ids and a <repo>-relative cwd, but are
#                               evidence, not source)
#   anchor                      TRACKED at docs/zero-gap/anchor.json — it holds
#                               only {head_digest, entry_count, anchor_strength},
#                               no path, and its git history is what part 4 walks.
#
# Usage
#   zero-gap-evidence-chain.sh --verify [<store>] [--anchor PATH] [--streams DIR]
#                              [--allow-untracked-anchor] [--witness-remote R]
#   zero-gap-evidence-chain.sh --anchor-write [<store>] [--anchor PATH]
#                              (--remote R | --unprobed)
#   zero-gap-evidence-chain.sh --prove-failure
#
#   <store>             default .remember/logs/zero-gap/evidence ($ZG_STORE_DIR)
#   --anchor PATH       default docs/zero-gap/anchor.json (tracked)
#   --streams DIR       default <store>/streams ($ZG_STREAMS_DIR); scanned for
#                       stale `.incoming.*` dirs an interrupted record left
#                       (they may hold UNREDACTED output): named, rc 2.
#   STRICT BY DEFAULT   an anchor with no committed history is rc 2. An
#                       untracked anchor can be rewritten to any lower count
#                       together with both tails and nothing would notice (the
#                       review measured VERDICT HOLDS for exactly that); only
#                       git history can see it.
#   --allow-untracked-anchor   opt-in for throwaway proof/fixture stores ONLY:
#                       the missing history becomes a printed NOTE.
#   --witness-remote R  the git remote that WITNESSES the anchor history
#                       (default `origin`). Echoed in the output; refused (rc 2)
#                       when it is not a configured remote of the anchor's repo.
#   --remote R          passed to `anchor write`: the upstream strength PROBE.
#                       A reachable remote without mechanical non-fast-forward
#                       protection records `policy` — this repository's honest
#                       value (research D6: one upstream, append-only by policy).
#   --unprobed          write WITHOUT a probe: records `unknown`. Upstream then
#                       locks that strength for this entry_count (a same-count
#                       rewrite is refused), so it must be deliberate.
#
# Exit codes (three-valued; a finding outranks an undetermined)
#   0 HOLDS     every part that applies holds
#   1 VIOLATED  some part DETECTED an alteration (named in the output)
#   2 UNDETERMINED / REFUSE: absent store, unwalkable chain, unreachable
#     anchor, missing verifier build, no committed anchor history (unless
#     --allow-untracked-anchor), a stale .incoming dir, or an upstream exit
#     code that contradicts upstream's own verdict word (INCONSISTENT).
#   Upstream `continuum-integrity` codes are mapped: 0 PASS->0, 3 DETECTED->1,
#   4 REFUSE->2, 5 SKIP->2, anything else->2 (an unknown code decided nothing).
#
# Environment
#   ZG_CHAIN_BIN / ZG_INTEGRITY_BIN  prebuilt binaries (else built offline into a
#   temp dir from _tools/zero-gap-chain, GOPROXY=off); ZG_GO  go binary.
#
# Side effects
#   --verify: the store is not modified. Part 4 performs a NETWORK fetch of
#   the witness branch from the witness remote (prompts disabled, bounded to
#   60 s) into the private ref refs/zero-gap/witness/<remote>/<branch> of the
#   anchor's repository — the only write. --anchor-write: writes the anchor file through
#   the upstream writer, which is forward-only (a lower count or a rewrite is
#   refused as DETECTED). It refuses to anchor a store whose sidecar does not
#   verify: anchoring a tampered state would record it as the expected one.
#
# Honest limits (§11.4.6)
#   The anchor is a tracked FILE: an ordinary commit can rewrite it, which is
#   why part 4 exists; its strength is `policy`, never `mechanism`. The chain
#   proves internal consistency; completeness is the anchor's; the anchor
#   window is the interval between anchor writes. Part 4 walks every commit
#   that touched the anchor (--full-history, so a side-branch change hidden by
#   a TREESAME merge is still seen) and compares it with EACH of its parents;
#   it does not follow renames of the anchor file. Part 2 also holds the CHAIN
#   file's bytes to the canonical form (I10): upstream decodes records, not
#   bytes, so a missing final newline or stray whitespace would otherwise pass.
#   WITNESS: local history alone can be rewritten (amend, rebase) to hide a
#   lowered count, and every LOCAL ref is forgeable too (`git update-ref
#   refs/remotes/origin/main HEAD`, `git branch -u evil/main`). So part 4 never
#   reads a remote-tracking ref or @{u}: it FETCHES HEAD's branch from a FIXED
#   remote (`origin`, or an explicit --witness-remote that must be configured)
#   into a private ref, requires that tip to be an ancestor of HEAD, and holds
#   its anchor against the current chain and the current anchor (never above
#   it). No such remote, a detached HEAD, a failed fetch (unreachable, no such
#   branch, authentication) or a HEAD that does not descend from the fetched
#   tip is rc 2 `UNWITNESSED` (a NOTE only with --allow-untracked-anchor, which
#   is refused for the tracked default anchor). The FETCH is itself an
#   execution surface, so it is pinned (review T015d F3, review T014 N3):
#   hooks off (`-c core.hooksPath=/dev/null`, so a reference-transaction hook
#   never fires on the ref write), `--no-recurse-submodules` (measured: an
#   unfixed fetch recurses into every populated submodule — this repository
#   owns 22 — and re-runs every one of these vectors again against THAT
#   submodule's own config; it ALSO turns out to be the reason a plain fetch
#   invokes a configured `core.fsmonitor` hook — that call is part of git's
#   own submodule-recursion decision, measured to already stop once recursion
#   is off), `-c core.fsmonitor=false` on both this fetch AND the separate
#   `git ls-files` call this script's binary makes to locate the tracked
#   anchor (kept as defense in depth; `ls-files` invokes fsmonitor on its own,
#   independently of submodule recursion), `--no-auto-maintenance` (no unwanted background
#   `git maintenance --auto` after a witness check), `--upload-pack=git-
#   upload-pack` (measured: `-c remote.<r>.uploadpack=...` does NOT win —
#   git reports "more than one uploadpack given, using the first" and still
#   runs the config file's program; the `--upload-pack` command-line flag is
#   the construct that actually overrides it), transports limited to `file`,
#   `https` and `ssh` (GIT_ALLOW_PROTOCOL — `file` because this repository's
#   proofs and any local mirror are path remotes; `ext::`, `fd::`, `git://`
#   and cleartext `http://` are refused whatever protocol.<x>.allow says, and
#   this holds even when an `insteadOf` rewrite RETARGETS the URL to `ext::`:
#   the allowlist is checked against the resolved URL, not the configured
#   one), prompts off, and the config-redirecting environment DROPPED
#   (GIT_CONFIG_COUNT / GIT_CONFIG_KEY_* / GIT_CONFIG_VALUE_* /
#   GIT_CONFIG_GLOBAL / GIT_CONFIG_SYSTEM / GIT_CONFIG_PARAMETERS) so a
#   caller's environment cannot steer it; the remote URL is printed with any
#   userinfo AND any secret-named query value (`?access_token=`, `?token=`,
#   `?key=`) redacted.
#   RESIDUAL, deliberately NOT neutralised (review T014 N3 ruling; rev-n3
#   independent re-review): whoever controls the remote (or can rewrite this
#   clone's remote URL configuration) can rewrite what is fetched; a
#   `url.<x>.insteadOf` rewrite still redirects the witness to a different
#   URL (never to a different, disallowed protocol — see above). TWO
#   transport-specific execution points, each pinned by its own test rather
#   than only documented here: `core.sshCommand` (ssh://) still names a
#   program the fetch runs (H19 / TestN3_..SshCommand..), and
#   `credential.helper` (https://) likewise still runs a configured program —
#   genuinely invoked only once the connection reaches a real, reachable 401,
#   never on a mere DNS failure, which is why H20 /
#   TestN3_..CredentialHelper.. run an actual local TLS server that answers
#   401 rather than pointing at an unreachable host. Pinning either was
#   rejected: it would break a legitimate operator's own ssh/credential setup
#   for the three real umbrella remotes, which this fetch must keep reaching.
#   Also residual: GIT_SSH_COMMAND / GIT_PROXY_COMMAND / GIT_EXEC_PATH / PATH
#   in the environment still name programs the fetch runs; anchor history not
#   yet pushed is witnessed by nothing outside this clone; and if
#   `.git/refs/zero-gap/witness` is already a symlink to somewhere outside
#   `.git` — which needs pre-existing write access to this clone's `.git` —
#   the fetch follows it and writes the loose-ref file at the symlink's
#   target, exactly as any other git ref write would: not a new privilege
#   this fetch grants.
#   CONSISTENCY: the four parts (and --anchor-write's verify-then-write) run
#   under ONE shared lock on the store directory that the function takes
#   itself, on a descriptor this shell holds — so it holds whether the script
#   is run as a command or sourced; appends take it EXCLUSIVE for the whole
#   record. A lock not obtained within ZG_LOCK_TIMEOUT (default 120s) is rc 2.
#   The lock cannot be skipped or CONVERTED by environment variables:
#   ZG_LOCK_FD names a descriptor that must really be the locked store
#   directory, and the held mode is read from the kernel
#   (/proc/self/fdinfo/<fd>), never from ZG_LOCK_MODE — a variable that
#   disagrees with it is refused and no flock is ever issued on an inherited
#   descriptor (a failed conversion would DROP the holder's lock; review
#   T015d F4). Without /proc the inherited lock is unknowable and refused.
#
# Dependencies
#   bash, git, go (unless prebuilt binaries are given), scripts/zero-gap-lib.sh,
#   scripts/zero-gap-evidence.sh (build helper + proof fixtures),
#   submodules/constitution/submodules/continuum (upstream verifier + chain lib).
#
# Cross-references
#   T014 (tasks.md), data-model.md (AnchorRecord, Adapter invariants),
#   research.md D6/D6a + T001 addendum, §11.4.268, §11.4.201, §11.4.273.

set -u

ZGC_HERE=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=scripts/zero-gap-evidence.sh
. "$ZGC_HERE/zero-gap-evidence.sh"

zgc_say() { printf 'zero-gap-evidence-chain: %s\n' "$*" >&2; }

# Upstream continuum-integrity exit code -> this repository's three values.
zgc_map_rc() {
    case "$1" in
        0) echo 0 ;;
        3) echo 1 ;;
        *) echo 2 ;;   # 4 REFUSE, 5 SKIP, 1 operational error, 2 usage, other
    esac
}

# zgc_bins -> sets ZGC_CB (zg-chain) ZGC_IB (continuum-integrity) ZGC_TB (temp to
# remove, may be empty). Prebuilt binaries win; otherwise an offline build.
zgc_bins() {
    ZGC_TB=""
    if [ -n "${ZG_CHAIN_BIN:-}" ] && [ -n "${ZG_INTEGRITY_BIN:-}" ] &&
       [ -x "$ZG_CHAIN_BIN" ] && [ -x "$ZG_INTEGRITY_BIN" ]; then
        ZGC_CB=$ZG_CHAIN_BIN ZGC_IB=$ZG_INTEGRITY_BIN; return 0
    fi
    ZGC_TB=$(mktemp -d) || return 2
    local b
    b=$(zge_build_bins "$ZGC_TB") || { rm -rf "$ZGC_TB"; ZGC_TB=""; return 2; }
    ZGC_CB=${b%% *} ZGC_IB=${b##* }
}

# zgc_upstream_word <stderr-file> <field> -> the verdict word of chain_alone or
# chain_plus_anchor from upstream's one-line human summary. Empty = unreadable,
# which the caller reports as UNDETERMINED, never as a guess.
zgc_upstream_word() {
    sed -n "s/.*$2=\([A-Z]*\).*/\1/p" "$1" | head -n 1
}

# zgc_lock <store> -> takes a SHARED lock on the store directory on a
# descriptor THIS shell holds ({ZGC_LOCKFD}), bounded by ZG_LOCK_TIMEOUT
# (default 120s), and exports it to zg-chain children (ZG_LOCK_FD/MODE) so
# they re-assert the same lock. The lock belongs to this shell: it is released
# by zgc_unlock, or when the shell exits or is killed — a plain environment
# variable can neither stand in for it nor outlive it (review T015c I2).
ZGC_LOCKFD="" ZGC_SAVED_LOCK=""
zgc_lock() {
    exec {ZGC_LOCKFD}<"$1" || { ZGC_LOCKFD=""; return 2; }
    if ! "$ZGC_CB" lock-fd --store "$1" --fd "$ZGC_LOCKFD" --shared --timeout "${ZG_LOCK_TIMEOUT:-120s}"; then
        exec {ZGC_LOCKFD}<&-; ZGC_LOCKFD=""; return 2
    fi
    ZGC_SAVED_LOCK="${ZG_LOCK_FD-}|${ZG_LOCK_MODE-}"
    export ZG_LOCK_FD=$ZGC_LOCKFD ZG_LOCK_MODE=shared
}
zgc_unlock() {
    [ -n "$ZGC_LOCKFD" ] || return 0
    exec {ZGC_LOCKFD}<&-; ZGC_LOCKFD=""
    if [ "$ZGC_SAVED_LOCK" = "|" ]; then unset ZG_LOCK_FD ZG_LOCK_MODE
    else export ZG_LOCK_FD="${ZGC_SAVED_LOCK%%|*}" ZG_LOCK_MODE="${ZGC_SAVED_LOCK#*|}"; fi
}

zgc_word_rc() { case "$1" in PASS|HOLDS) echo 0 ;; DETECTED|VIOLATED) echo 1 ;; *) echo 2 ;; esac; }

zgc_verify() {
    local store=$1 anchor=$2 allow=$3 streams=$4 witness=${5:-} t rc c_w s_w a_w h_w="NOT_RUN" c_rc s_rc a_rc h_rc=0 up ov i_w=CLEAN i_rc=0
    zgc_summary() { # rc chain sidecar anchor history incoming
        local word=HOLDS
        [ "$1" -eq 1 ] && word=VIOLATED
        [ "$1" -eq 2 ] && word=UNDETERMINED
        printf 'VERDICT %s (rc %s) chain=%s sidecar=%s anchor=%s history=%s incoming=%s\n' "$word" "$1" "$2" "$3" "$4" "$5" "${6:-NOT_RUN}"
    }
    # The fixtures opt-in never applies to the ruled, TRACKED anchor: accepting
    # "no committed history" there would silently disable part 4 (T015b M4).
    if [ "$allow" -eq 1 ] && [ "$(realpath -m -- "$anchor")" = "$(realpath -m -- "$ZGE_ROOT/docs/zero-gap/anchor.json")" ]; then
        echo "REFUSE --allow-untracked-anchor is refused for the default tracked anchor docs/zero-gap/anchor.json: the opt-in is for throwaway proof/fixture anchors only"
        zgc_summary 2 NOT_RUN NOT_RUN NOT_RUN NOT_RUN; return 2
    fi
    # 0 — interrupted records (review finding 3): a stale .incoming dir may
    # hold UNREDACTED output. Read-only here: named, rc 2; `record` removes it.
    # Run FIRST, so it is reported even when the store itself is gone (M2).
    local i_out
    if ! i_out=$(zge_incoming_sweep "$streams" report); then i_w=STALE; i_rc=2; fi
    [ -z "$i_out" ] || printf '%s\n' "$i_out" | sed 's/^/[0\/4 incoming] /'
    if [ ! -e "$store" ] || [ ! -d "$store" ]; then
        echo "REFUSE store '$store' is absent or not a directory: nothing was verified (the wholesale-deletion case is never reported as intact)"
        zgc_summary 2 REFUSE NOT_RUN NOT_RUN NOT_RUN "$i_w"; return 2
    fi
    if ! zgc_bins; then
        echo "REFUSE missing verifier build: continuum-integrity / zg-chain could not be built or found"
        zgc_summary 2 NOT_RUN NOT_RUN NOT_RUN NOT_RUN "$i_w"; return 2
    fi
    # One consistent store for every part (review T015b/T015c I2): all four
    # parts run under ONE shared lock that this function takes itself, so it
    # holds whether the script is run as a command or sourced.
    if ! zgc_lock "$store"; then
        echo "REFUSE the store lock on '$store' was not obtained within ${ZG_LOCK_TIMEOUT:-120s} (an append is in progress or stuck): nothing was verified"
        [ -z "$ZGC_TB" ] || rm -rf "$ZGC_TB"
        zgc_summary 2 NOT_RUN NOT_RUN NOT_RUN NOT_RUN "$i_w"; return 2
    fi
    t=$(mktemp -d) || { zgc_unlock; return 2; }

    # 1 — chain (upstream)
    "$ZGC_IB" chain verify --chain "$store/chain.jsonl" >"$t/c.json" 2>"$t/c.err"; up=$?
    c_w=$(zgc_upstream_word "$t/c.err" chain_alone)
    [ -n "$c_w" ] || c_w="UNREADABLE(rc=$up)"
    c_rc=$(zgc_map_rc "$up")
    [ "$(zgc_word_rc "$c_w")" = "$c_rc" ] || { c_rc=2; c_w="INCONSISTENT(word=$c_w,rc=$up)"; }
    printf '[1/4 chain]   %s\n' "$(head -n 1 "$t/c.err")"

    # 2 — sidecar (every adapter invariant, by position)
    "$ZGC_CB" verify --store "$store" --schema "$ZGE_CONTRACT" >"$t/s.out" 2>&1; s_rc=$?
    case $s_rc in 0) s_w=HOLDS ;; 1) s_w=VIOLATED ;; *) s_w=UNDETERMINED; s_rc=2 ;; esac
    sed 's/^/[2\/4 sidecar] /' "$t/s.out"

    # 3 — anchor (upstream): the chain_plus_anchor half is this part's
    # verdict, and upstream's exit code must agree with its OWN overall word
    # (review finding 9: the same INCONSISTENT cross-check as part 1).
    "$ZGC_IB" anchor verify --chain "$store/chain.jsonl" --anchor "$anchor" >"$t/a.json" 2>"$t/a.err"; up=$?
    a_w=$(zgc_upstream_word "$t/a.err" chain_plus_anchor)
    ov=$(sed -n 's/^anchor verify \[\([A-Z]*\)\].*/\1/p' "$t/a.err" | head -n 1)
    if [ -z "$a_w" ] || [ -z "$ov" ]; then a_w="UNREADABLE(rc=$up)"; a_rc=2
    elif [ "$(zgc_word_rc "$ov")" != "$(zgc_map_rc "$up")" ]; then a_w="INCONSISTENT(overall=$ov,rc=$up)"; a_rc=2
    else a_rc=$(zgc_word_rc "$a_w"); fi
    printf '[3/4 anchor]  %s\n' "$(head -n 1 "$t/a.err")"

    # 4 — history (per commit, forward-only) of a git-tracked anchor
    if [ -e "$anchor" ]; then
        local wr=()
        if [ -n "$witness" ]; then
            echo "[4/4 history] witness remote: $witness (explicit --witness-remote; must be a configured remote of the anchor's repository)"
            wr=(--witness-remote "$witness")
        fi
        "$ZGC_CB" history --chain "$store/chain.jsonl" --anchor "$anchor" ${wr[@]+"${wr[@]}"} >"$t/h.out" 2>&1; rc=$?
        sed 's/^/[4\/4 history] /' "$t/h.out"
        case $rc in
            0) h_w=HOLDS; h_rc=0 ;;
            1) h_w=VIOLATED; h_rc=1 ;;
            5) h_w=NOT_APPLICABLE
               if [ "$allow" -eq 1 ]; then h_rc=0; echo "[4/4 history] NOTE per-commit forward-only NOT checked (anchor not committed) — accepted ONLY because --allow-untracked-anchor was given (proofs/fixtures)"
               else h_rc=2; echo "[4/4 history] REFUSE the anchor has no committed history: an untracked anchor can be rewritten to any lower count unseen (the default is strict; see the header)"; fi ;;
            6) h_w=UNWITNESSED
               if [ "$allow" -eq 1 ]; then h_rc=0; echo "[4/4 history] NOTE the committed anchor history is NOT witnessed by a remote-tracking copy — accepted ONLY because --allow-untracked-anchor was given (proofs/fixtures)"
               else h_rc=2; echo "[4/4 history] REFUSE anchor history not witnessed: no upstream (@{u}), or HEAD does not descend from it — local history alone can be rewritten (amend/rebase) to hide a lowered count"; fi ;;
            *) h_w=UNDETERMINED; h_rc=2 ;;
        esac
    else
        echo "[4/4 history] not run: the anchor is unreachable (part 3 already refuses)"
    fi
    zgc_unlock
    rm -rf "$t"; [ -z "$ZGC_TB" ] || rm -rf "$ZGC_TB"
    zg_combine "$c_rc" "$s_rc" "$a_rc" "$h_rc" "$i_rc"; rc=$?
    zgc_summary "$rc" "$c_w" "$s_w" "$a_w" "$h_w" "$i_w"
    return "$rc"
}

zgc_anchor_write() {
    local store=$1 anchor=$2 remote=$3 unprobed=$4 t rc up strength
    if [ ! -d "$store" ]; then echo "REFUSE store '$store' is absent: nothing to anchor"; return 2; fi
    # Upstream locks the strength recorded for an entry_count (a rewrite at the
    # same count is refused), so an unprobed write must be DELIBERATE (finding 8).
    if [ -z "$remote" ] && [ "$unprobed" -ne 1 ]; then
        echo "REFUSE anchor write needs --remote <r> (probe the strength; a reachable remote records policy) or an explicit --unprobed (records unknown, which upstream then locks for this entry_count)"
        return 2
    fi
    zgc_bins || { echo "REFUSE missing verifier build"; return 2; }
    # verify-then-write under ONE shared lock (an append cannot slip between).
    if ! zgc_lock "$store"; then
        echo "REFUSE the store lock on '$store' was not obtained within ${ZG_LOCK_TIMEOUT:-120s}: the store is NOT anchored"
        [ -z "$ZGC_TB" ] || rm -rf "$ZGC_TB"; return 2
    fi
    t=$(mktemp -d) || { zgc_unlock; return 2; }
    # Anchoring a tampered state would record it as the expected one.
    "$ZGC_CB" verify --store "$store" --schema "$ZGE_CONTRACT" >"$t/s.out" 2>&1; rc=$?
    if [ "$rc" -ne 0 ]; then
        sed 's/^/[sidecar] /' "$t/s.out"
        echo "REFUSE the sidecar does not verify (rc $rc); the store is NOT anchored"
        zgc_unlock; rm -rf "$t"; [ -z "$ZGC_TB" ] || rm -rf "$ZGC_TB"
        [ "$rc" -eq 1 ] && return 1
        return 2
    fi
    if [ -n "$remote" ]; then
        "$ZGC_IB" anchor write --chain "$store/chain.jsonl" --anchor "$anchor" --remote "$remote" >"$t/w.json" 2>"$t/w.err"; up=$?
    else
        "$ZGC_IB" anchor write --chain "$store/chain.jsonl" --anchor "$anchor" >"$t/w.json" 2>"$t/w.err"; up=$?
    fi
    head -n 1 "$t/w.err"
    rc=$(zgc_map_rc "$up")
    strength=$(sed -n 's/.*"anchor_strength":"\([a-z]*\)".*/\1/p' "$anchor" 2>/dev/null | head -n 1)
    if [ "$rc" -eq 0 ]; then
        echo "anchored: $(cat "$anchor" 2>/dev/null)"
        case $strength in
            policy)    echo "strength: policy — probed: the remote is reachable and does not mechanically refuse a rewrite (append-only by policy, research D6)" ;;
            mechanism) echo "strength: mechanism — probed: the remote refuses a non-fast-forward update" ;;
            *)         echo "strength: ${strength:-unreadable} — no probe established one (pass --remote to probe); recorded honestly, never upgraded here" ;;
        esac
    fi
    zgc_unlock
    rm -rf "$t"; [ -z "$ZGC_TB" ] || rm -rf "$ZGC_TB"
    return "$rc"
}

# ─────────────────────────────────────────────────────────────────────────────
# Paired proof: control + the constitution attack corpus + the sidecar attacks
# + the history attacks, every one on a THROWAWAY store built by the real
# adapter. Nothing shipped is modified; the live inputs are checked unchanged.
# ─────────────────────────────────────────────────────────────────────────────
zgc_prove_failure() (
    set -u
    pass=0 fail=0 undet=0
    ok()  { pass=$((pass+1)); printf '  PASS %s\n' "$1"; }
    bad() { fail=$((fail+1)); printf '  FAIL %s\n' "$1"; }
    T=$(mktemp -d) || exit 2
    trap 'rm -rf "$T"' EXIT
    LIVE=(scripts/zero-gap-evidence.sh scripts/zero-gap-evidence-chain.sh scripts/zero-gap-lib.sh
          _tools/zero-gap-chain specs/010-zero-gap-verified-closure/contracts _tests/fixtures/zero-gap/evidence
          docs/zero-gap)
    zg_manifest "$ZGE_ROOT" "${LIVE[@]}" > "$T/live0" 2>/dev/null \
        || { echo "  UNDETERMINED: cannot fingerprint the live inputs"; exit 2; }
    command -v jq >/dev/null 2>&1 || { echo "  UNDETERMINED: jq absent"; exit 2; }
    mkdir -p "$T/bin"
    bins=$(zge_build_bins "$T/bin") || { echo "  UNDETERMINED: missing verifier build"; exit 2; }
    export ZG_CHAIN_BIN=${bins%% *} ZG_INTEGRITY_BIN=${bins##* } ZG_SESSION_ID=proof-session
    CONT=$(CDPATH='' cd -- "$ZGE_ROOT/submodules/constitution/submodules/continuum" && pwd)

    # A tiny attack tool, compiled into the temp dir from the UPSTREAM chain
    # library: an attacker who understands the chain re-links it with the real
    # digest, so the attacks below are the strongest form, not a strawman.
    mkdir -p "$T/attk"
    printf 'module attk\n\ngo 1.22\n\nrequire github.com/vasic-digital/continuum v0.0.0\n\nreplace github.com/vasic-digital/continuum => %s\n' "$CONT" > "$T/attk/go.mod"
    cat > "$T/attk/main.go" <<'GOEOF'
package main

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"strconv"

	"github.com/vasic-digital/continuum/pkg/chain"
	"github.com/vasic-digital/continuum/pkg/model"
)

func load(p string) []chain.Record {
	b, err := os.ReadFile(p)
	if err != nil { fmt.Fprintln(os.Stderr, err); os.Exit(2) }
	r, err := chain.Decode(b)
	if err != nil { fmt.Fprintln(os.Stderr, err); os.Exit(2) }
	return r
}

func save(p string, rs []chain.Record) {
	prev := chain.GenesisPrev
	var buf bytes.Buffer
	for i := range rs {
		rs[i].PrevDigest = prev
		b, _ := model.Canonical(rs[i])
		buf.Write(b); buf.WriteByte('\n')
		prev, _ = chain.Digest(rs[i])
	}
	if err := os.WriteFile(p, buf.Bytes(), 0o644); err != nil { fmt.Fprintln(os.Stderr, err); os.Exit(2) }
}

func main() {
	a := os.Args
	switch a[1] {
	case "rechain":
		save(a[2], load(a[2]))
	case "bind": // chain sidecar k(1-based): artifact_path := sha256(sidecar line k), re-link
		rs := load(a[2])
		sb, _ := os.ReadFile(a[3])
		ls := bytes.Split(bytes.TrimSuffix(sb, []byte("\n")), []byte("\n"))
		k, _ := strconv.Atoi(a[4])
		h := sha256.Sum256(ls[k-1])
		rs[k-1].ArtifactPath = "sha256:" + hex.EncodeToString(h[:])
		save(a[2], rs)
	case "replay": // chain k: append a copy of record k as a new, properly linked tail
		rs := load(a[2])
		k, _ := strconv.Atoi(a[3])
		n := rs[k-1]
		n.Seq = rs[len(rs)-1].Seq + 1
		save(a[2], append(rs, n))
	case "execrows": // rows-file chain-file: upstream DecodeExecRows + the union-rule seam
		b, err := os.ReadFile(a[2])
		if err != nil { fmt.Println("UNREADABLE", err); os.Exit(1) }
		rows, err := chain.DecodeExecRows(b)
		if err != nil { fmt.Println("REFUSED", err); os.Exit(1) }
		rs := load(a[3])
		rep, _, err := chain.VerifyExecRows(rs, rows)
		if err != nil || rep.Verdict != chain.PASS || len(rows) != len(rs) {
			fmt.Println("FAIL", err, rep.Verdict, len(rows), len(rs)); os.Exit(1)
		}
		fmt.Println("PASS", len(rows), "rows decoded by upstream DecodeExecRows; union rule PASS")
	case "digest": // chain k
		rs := load(a[2])
		k, _ := strconv.Atoi(a[3])
		d, _ := chain.Digest(rs[k-1])
		fmt.Println(d)
	case "httpsrv401": // review T014 N3 rev-n3: a REAL reachable https 401 so
		// credential.helper is genuinely invoked (DNS failure alone never
		// reaches the credential subsystem). Prints the base URL, then blocks
		// until killed by the caller.
		srv := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			w.Header().Set("WWW-Authenticate", `Basic realm="zero-gap-n3"`)
			w.WriteHeader(http.StatusUnauthorized)
		}))
		fmt.Println(srv.URL)
		select {}
	}
}
GOEOF
    ( cd "$T/attk" && GOPROXY=off GOTOOLCHAIN=local GOFLAGS=-mod=mod "${ZG_GO:-go}" build -o "$T/bin/attk" . ) >"$T/attk.log" 2>&1 \
        || { echo "  UNDETERMINED: the attack tool cannot be built: $(head -3 "$T/attk.log" | tr '\n' ' ')"; exit 2; }
    ATTK="$T/bin/attk"

    W="$T/work"; mkdir -p "$W"
    git -C "$W" init -q && printf 'x\n' > "$W/f" && git -C "$W" add f &&
        git -C "$W" -c user.email=t@example.invalid -c user.name=t commit -qm init \
        || { echo "  UNDETERMINED: cannot build the scratch work tree"; exit 2; }
    mkrec() { # store n
        local i
        for i in $(seq 1 "$2"); do
            bash "$ZGE_HERE/zero-gap-evidence.sh" record --store "$1" --streams "$T/streams" --fp-dir "$W" \
                --item-id "ATM-00$i" --check-id "c$i" --population-kind source --verdict-role author \
                --independence-tier instance --evidence-class runtime --verdict-exit \
                -- /bin/sh -c 'exit 0' "run$i" >/dev/null 2>&1 || return 2
        done
    }
    # Golden store: 3 records, anchored at 3 with strength probed against a
    # reachable local remote (=> policy).
    G="$T/golden"
    mkrec "$G" 3 || { echo "  UNDETERMINED: the adapter could not build the golden store"; exit 2; }
    bash "$ZGC_HERE/zero-gap-evidence-chain.sh" --anchor-write "$G" --anchor "$G/anchor.json" --remote "$W" >"$T/aw" 2>&1; rc=$?
    strength=$(jq -r .anchor_strength "$G/anchor.json" 2>/dev/null)
    [ "$rc" -eq 0 ] && [ "$strength" = policy ] && [ "$(jq -r .entry_count "$G/anchor.json")" = 3 ] \
        && ok "C0 anchor written through upstream \`anchor write\`: entry_count 3, strength probed = policy" \
        || bad "C0 anchor write (rc=$rc strength=$strength): $(tail -2 "$T/aw" | tr '\n' ' ')"

    # V <store> [args]: a throwaway store whose anchor sits beside it, so the
    # proof passes --allow-untracked-anchor; `V STRICT <store>` omits it.
    V() {
        local strict=0 st
        [ "$1" = STRICT ] && { strict=1; shift; }
        st=$1; shift
        if [ "$strict" -eq 1 ]; then
            bash "$ZGC_HERE/zero-gap-evidence-chain.sh" --verify "$st" --anchor "$st/anchor.json" --streams "$T/streams" "$@"
        else
            bash "$ZGC_HERE/zero-gap-evidence-chain.sh" --verify "$st" --anchor "$st/anchor.json" --streams "$T/streams" --allow-untracked-anchor "$@"
        fi
    }
    copy() { rm -rf "$T/c"; cp -r "$G" "$T/c"; }
    # expect <name> <want-rc> <regex>... -- <verify-args...>
    # EVERY regex must match the output (they are ANDed, never alternatives).
    expect() {
        local name=$1 want=$2 res=() r miss=""; shift 2
        while [ "$1" != -- ]; do res+=("$1"); shift; done; shift
        V "$@" >"$T/out" 2>&1; local got=$?
        for r in "${res[@]}"; do grep -Eq -- "$r" "$T/out" || miss="$miss /$r/"; done
        if [ "$got" -eq "$want" ] && [ -z "$miss" ]; then
            ok "$name (rc $got)"
        else
            bad "$name — want rc $want, got rc $got; unmatched:${miss:- none}; $(grep -E 'VERDICT|VIOLATED|REFUSE|DETECTED' "$T/out" | head -4 | tr '\n' ' ')"
        fi
    }
    trunc_bytes() { local n; n=$(wc -c < "$1" | tr -d ' '); head -c $((n - $2)) "$1" > "$T/x" && mv "$T/x" "$1"; }

    # ── Control and golden-false ────────────────────────────────────────────
    copy; expect "C1 healthy store HOLDS" 0 'chain=PASS sidecar=HOLDS anchor=PASS' -- "$T/c"
    copy; mkrec "$T/c" 1 >/dev/null
    expect "C2 golden-FALSE: store grew by a valid append after anchoring (lagging anchor) still HOLDS" 0 'chain=PASS sidecar=HOLDS anchor=PASS' -- "$T/c"

    # ── Constitution attack corpus ──────────────────────────────────────────
    copy; sed '2s/"exit_status":0/"exit_status":1/' "$T/c/chain.jsonl" > "$T/x" && mv "$T/x" "$T/c/chain.jsonl"
    expect "A1 chain record mutated (not re-linked) => DETECTED by the chain" 1 'chain=DETECTED' -- "$T/c"
    copy; awk 'NR!=2' "$T/c/chain.jsonl" > "$T/x" && mv "$T/x" "$T/c/chain.jsonl"
    expect "A2 chain record deleted (not re-linked) => DETECTED" 1 'chain=DETECTED' -- "$T/c"
    copy; awk 'NR==1{a=$0;next} NR==2{print;print a;next} {print}' "$T/c/chain.jsonl" > "$T/x" && mv "$T/x" "$T/c/chain.jsonl"
    expect "A3 chain records reordered => DETECTED" 1 'chain=DETECTED' -- "$T/c"
    expect "A4 absent store => REFUSE (rc 2) before anything runs" 2 'chain=REFUSE sidecar=NOT_RUN anchor=NOT_RUN' 'absent' -- "$T/no-such-store"
    copy; trunc_bytes "$T/c/chain.jsonl" 25
    expect "A5 unwalkable (torn) chain => REFUSE (rc 2)" 2 'chain=REFUSE' -- "$T/c"
    copy; for f in chain.jsonl sidecar.jsonl; do head -n 2 "$T/c/$f" > "$T/x" && mv "$T/x" "$T/c/$f"; done
    expect "A6 tail truncated in BOTH files => chain PASS, sidecar HOLDS, caught ONLY by the anchor" 1 'chain=PASS sidecar=HOLDS anchor=DETECTED' -- "$T/c"
    copy; for f in chain.jsonl sidecar.jsonl; do awk 'NR!=2' "$T/c/$f" > "$T/x" && mv "$T/x" "$T/c/$f"; done
    "$ATTK" rechain "$T/c/chain.jsonl"
    expect "A7 delete + full re-chain of both files => chain PASS, sidecar HOLDS, caught ONLY by the anchor" 1 'chain=PASS sidecar=HOLDS anchor=DETECTED' -- "$T/c"
    copy; sed '2s/"author_session_id":"proof-session"/"author_session_id":"forged"/' "$T/c/chain.jsonl" > "$T/x" && mv "$T/x" "$T/c/chain.jsonl"
    expect "A9 a chain field the sidecar does not duplicate is altered => caught ONLY by the chain" 1 'chain=DETECTED sidecar=HOLDS anchor=PASS' -- "$T/c"
    copy; rm -f "$T/c/anchor.json"
    expect "A8 anchor unreachable => REFUSE (rc 2), never intact" 2 'anchor=REFUSE' -- "$T/c"

    # ── Sidecar attacks (the upstream verifier never reads the sidecar) ─────
    copy; sed '2s/"outcome":0/"outcome":1/' "$T/c/sidecar.jsonl" > "$T/x" && mv "$T/x" "$T/c/sidecar.jsonl"
    expect "S1 one sidecar byte flipped => chain PASS, sidecar VIOLATED [I3]" 1 'chain=PASS sidecar=VIOLATED' 'I3-positional-binding' -- "$T/c"
    copy; awk 'NR!=2' "$T/c/sidecar.jsonl" > "$T/x" && mv "$T/x" "$T/c/sidecar.jsonl"
    expect "S2 sidecar line deleted => [I2]" 1 'I2-line-count' -- "$T/c"
    copy; awk 'NR==1{a=$0;next} NR==2{print;print a;next} {print}' "$T/c/sidecar.jsonl" > "$T/x" && mv "$T/x" "$T/c/sidecar.jsonl"
    expect "S3 two sidecar lines swapped => [I3] by position" 1 'I3-positional-binding' -- "$T/c"
    copy; sed -n '2p' "$T/c/sidecar.jsonl" >> "$T/c/sidecar.jsonl"
    expect "S4 sidecar line duplicated => [I2]" 1 'I2-line-count' -- "$T/c"
    copy; sed -n '1p' "$T/c/sidecar.jsonl" | sed 's/"chain_seq":1/"chain_seq":9/' >> "$T/c/sidecar.jsonl"
    expect "S5 unbound sidecar line added => [I2]" 1 'I2-line-count' -- "$T/c"
    copy; sed -n '1p' "$T/c/sidecar.jsonl" >> "$T/c/sidecar.jsonl"; "$ATTK" replay "$T/c/chain.jsonl" 1
    expect "S6 line replayed under a new, properly linked tail record => chain PASS, anchor PASS (lagging), sidecar [I5][I4]" 1 'chain=PASS sidecar=VIOLATED anchor=PASS' 'I5-artifact-path-unique' 'I4-chain-seq' -- "$T/c"
    copy; awk 'NR==1{printf "%s\r\n", $0; next} {print}' "$T/c/sidecar.jsonl" > "$T/x" && mv "$T/x" "$T/c/sidecar.jsonl"
    expect "S7 CR in a sidecar line => [I1]" 1 'I1-byte-rule' -- "$T/c"
    copy; trunc_bytes "$T/c/sidecar.jsonl" 1
    expect "S8 sidecar without a final newline => [I1]" 1 'I1-byte-rule' -- "$T/c"
    copy; awk 'NR==1{print; print ""; next} {print}' "$T/c/sidecar.jsonl" > "$T/x" && mv "$T/x" "$T/c/sidecar.jsonl"
    expect "S9 blank line in the sidecar => [I1]" 1 'I1-byte-rule' -- "$T/c"
    copy; fpa=$(sed -n '3p' "$T/c/sidecar.jsonl" | jq -r .state_fingerprint_after)
    sed "3s/\"state_fingerprint_after\":\"$fpa\"/\"state_fingerprint_after\":\"$(printf '%064d' 0)\"/" "$T/c/sidecar.jsonl" > "$T/x" && mv "$T/x" "$T/c/sidecar.jsonl"
    "$ATTK" bind "$T/c/chain.jsonl" "$T/c/sidecar.jsonl" 3
    expect "S10 unstable run recorded with outcome 0, re-bound and re-linked => [I9]" 1 'I9-unstable-means-outcome-2' -- "$T/c"
    copy; sed '2s/"command":"\/bin\/sh"/"command":"\/bin\/other"/' "$T/c/chain.jsonl" > "$T/x" && mv "$T/x" "$T/c/chain.jsonl"
    "$ATTK" rechain "$T/c/chain.jsonl"
    expect "S11 chain command no longer argv[0], re-linked => [I6]" 1 'I6-duplicated-fields-agree' -- "$T/c"

    # ── The committed fixture corpus (read-only: verify never writes) ───────
    FX="$ZGE_ROOT/_tests/fixtures/zero-gap/evidence"
    if [ -d "$FX/golden-good" ]; then
        expect "F0 committed golden-good store HOLDS" 0 'chain=PASS sidecar=HOLDS anchor=PASS' -- "$FX/golden-good"
        nfx=0
        for d in "$FX"/golden-bad/*/; do
            d=${d%/}; nfx=$((nfx+1))
            want=$(sed -n 's/.*"summary": *"\([^"]*\)".*/\1/p' "$d/expect.json")
            invs=$(sed -n '/"invariants"/,/]/p' "$d/expect.json" | grep -o 'I[0-9]-[a-z0-9-]*' | tr '\n' ' ')
            args=("$want"); for i in $invs; do args+=("$i"); done
            [ -n "$want" ] || { bad "F ${d##*/}: expect.json summary unreadable"; continue; }
            expect "F ${d##*/} => $want${invs:+ [$invs]}" 1 "${args[@]}" -- "$d"
        done
        [ "$nfx" -ge 13 ] && ok "F* $nfx golden-bad stores exercised (control: the glob saw the corpus)" \
            || bad "F* only $nfx golden-bad stores found — the corpus or the glob is broken"
    else
        bad "F0 the committed fixture corpus is absent at $FX"
    fi

    # ── rc mapping and missing build ────────────────────────────────────────
    m=""; for c in 0 3 4 5 1 2 9; do m="$m$c:$(zgc_map_rc "$c") "; done
    [ "$m" = "0:0 3:1 4:2 5:2 1:2 2:2 9:2 " ] && ok "R1 upstream rc mapping 0->0 3->1 4->2 5->2 other->2" || bad "R1 rc mapping: $m"
    copy; ZG_CHAIN_BIN='' ZG_INTEGRITY_BIN='' ZG_GO="$T/no-such-go" V "$T/c" >"$T/out" 2>&1; rc=$?
    [ "$rc" -eq 2 ] && grep -q 'missing verifier build' "$T/out" && ok "R2 missing verifier build => rc 2, named" \
        || bad "R2 missing build (rc=$rc)"

    # ── History (anchor tracked in git) ─────────────────────────────────────
    AW() { bash "$ZGC_HERE/zero-gap-evidence-chain.sh" --anchor-write "$1" --anchor "$1/anchor.json" --remote "$W" >/dev/null 2>&1; }
    newh() { # repo n-records
        mkdir -p "$1" && git -C "$1" init -q && git -C "$1" config user.email t@example.invalid &&
            git -C "$1" config user.name t && mkrec "$1/store" "$2"; }
    hc() { git -C "$1" add store/anchor.json && git -C "$1" commit -qm "$2"; }
    anchor_json() { printf '{"head_digest":"%s","entry_count":%s,"anchor_strength":"policy"}\n' "$2" "$1"; }
    H="$T/h1"
    remote_of() { git init -q --bare "$1.git" && git -C "$1" remote add origin "$1.git" && git -C "$1" push -q -u origin HEAD 2>/dev/null; }
    newh "$H" 2 && AW "$H/store" && hc "$H" a2 && mkrec "$H/store" 1 && AW "$H/store" && hc "$H" a3 && remote_of "$H" \
        || { echo "  UNDETERMINED: cannot build the history fixture"; exit 2; }
    expect "H1b pushed, forward-only history under the STRICT default => HOLDS (witnessed by the remote-tracking copy)" 0 'history=HOLDS' -- STRICT "$H/store"
    expect "H1 committed anchors 2 then 3, forward-only => HOLDS with history" 0 'history=HOLDS' 'VERDICT HOLDS' -- "$H/store"
    anchor_json 2 "$("$ATTK" digest "$H/store/chain.jsonl" 2)" > "$H/store/anchor.json"; hc "$H" back-to-2
    expect "H2 a later commit drops entry_count 3 -> 2 (anchor verify alone: lagging PASS) => caught ONLY by history" 1 'anchor=PASS history=VIOLATED' 'dropped' -- "$H/store"
    H="$T/h3"
    newh "$H" 3 && anchor_json 1 "$(printf '%064d' 7)" > "$H/store/anchor.json" && hc "$H" forged-early &&
        AW "$H/store" && hc "$H" a3 || { echo "  UNDETERMINED: cannot build the second history fixture"; exit 2; }
    expect "H3 an earlier committed head_digest is not the digest of that chain record (current anchor PASS) => caught by history" 1 'anchor=PASS history=VIOLATED' 'rewritten' -- "$H/store"
    copy
    expect "H4 untracked anchor under the STRICT default => rc 2" 2 'history=NOT_APPLICABLE' -- STRICT "$T/c"
    expect "H5 untracked anchor with the opt-in --allow-untracked-anchor => NOTE, rc 0" 0 'history=NOT_APPLICABLE' 'VERDICT HOLDS' -- "$T/c"
    H="$T/h1"
    for f in chain.jsonl sidecar.jsonl; do head -n 2 "$H/store/$f" > "$T/x" && mv "$T/x" "$H/store/$f"; done
    anchor_json 2 "$("$ATTK" digest "$H/store/chain.jsonl" 2)" > "$H/store/anchor.json"
    expect "H6 tracked anchor: both tails truncated AND the anchor rewritten lower (uncommitted) => history VIOLATED" 1 'history=VIOLATED' -- "$H/store"

    # ── Fix round 2 (review T015b) ──────────────────────────────────────────
    H="$T/h7"
    newh "$H" 2 && AW "$H/store" && hc "$H" a2 && remote_of "$H" && mkrec "$H/store" 1 && AW "$H/store" && hc "$H" a3 &&
        git -C "$H" push -q 2>/dev/null || { echo "  UNDETERMINED: cannot build the amend fixture"; exit 2; }
    for f in chain.jsonl sidecar.jsonl; do head -n 2 "$H/store/$f" > "$T/x" && mv "$T/x" "$H/store/$f"; done
    anchor_json 2 "$("$ATTK" digest "$H/store/chain.jsonl" 2)" > "$H/store/anchor.json"
    git -C "$H" commit -q --amend --allow-empty -a -m "anchor 3 (amended)"
    expect "H7 reviewer attack: both tails truncated, anchor lowered, commit AMENDED after push => history VIOLATED (not HOLDS)" 1 'history=VIOLATED' -- "$H/store"
    H="$T/h8"
    newh "$H" 3 && AW "$H/store" && hc "$H" a3 || { echo "  UNDETERMINED: cannot build the no-upstream fixture"; exit 2; }
    expect "H8 committed history with NO upstream under the STRICT default => rc 2 UNWITNESSED" 2 'history=UNWITNESSED' -- STRICT "$H/store"
    expect "H8b the same with the fixtures opt-in => NOTE, rc 0" 0 'history=UNWITNESSED' 'VERDICT HOLDS' -- "$H/store"
    # ── Fix round 3 (review T015c): the witness is FETCHED, never read locally
    lowered() { # repo: anchors 2,3 pushed; then both tails cut, anchor lowered, tip amended
        newh "$1" 2 && AW "$1/store" && hc "$1" a2 && remote_of "$1" && mkrec "$1/store" 1 && AW "$1/store" && hc "$1" a3 &&
            git -C "$1" push -q 2>/dev/null || return 1
        for f in chain.jsonl sidecar.jsonl; do head -n 2 "$1/store/$f" > "$T/x" && mv "$T/x" "$1/store/$f"; done
        anchor_json 2 "$("$ATTK" digest "$1/store/chain.jsonl" 2)" > "$1/store/anchor.json"
        git -C "$1" commit -q --amend --allow-empty -a -m "anchor 3 (amended)"
    }
    H="$T/h9"; lowered "$H" || { echo "  UNDETERMINED: cannot build the forgery fixture"; exit 2; }
    git -C "$H" update-ref "refs/remotes/origin/$(git -C "$H" symbolic-ref --short HEAD)" HEAD
    expect "H9 witness forged with update-ref refs/remotes/origin/<br> HEAD after the amend => still VIOLATED (the witness is fetched)" 1 'history=VIOLATED' -- STRICT "$H/store"
    H="$T/h10"; lowered "$H" && git init -q --bare "$H.evil.git" && git -C "$H" remote add evil "$H.evil.git" &&
        git -C "$H" push -q evil HEAD 2>/dev/null && git -C "$H" branch -q -u "evil/$(git -C "$H" symbolic-ref --short HEAD)" \
        || { echo "  UNDETERMINED: cannot build the evil-upstream fixture"; exit 2; }
    expect "H10 witness forged with branch -u evil/<br> => still VIOLATED (the remote is fixed: origin)" 1 'history=VIOLATED' -- STRICT "$H/store"
    H="$T/h11"
    newh "$H" 2 && AW "$H/store" && hc "$H" a2 && remote_of "$H" || { echo "  UNDETERMINED: cannot build the unreachable fixture"; exit 2; }
    git -C "$H" remote set-url origin "$T/does-not-exist.git"
    expect "H11 witness remote unreachable (nonexistent path; the stale local ref is ignored) => rc 2 UNWITNESSED" 2 'history=UNWITNESSED' 'could not be fetched' -- STRICT "$H/store"
    expect "H11b the same with the fixtures opt-in => NOTE, rc 0" 0 'history=UNWITNESSED' -- "$H/store"
    H="$T/h12"
    newh "$H" 2 && AW "$H/store" && hc "$H" a2 && remote_of "$H" && git clone -q "$H.git" "$H.other" 2>/dev/null &&
        git -C "$H.other" -c user.email=o@example.invalid -c user.name=o commit -q --allow-empty -m theirs &&
        git -C "$H.other" push -q 2>/dev/null && git -C "$H" commit -q --allow-empty -m ours \
        || { echo "  UNDETERMINED: cannot build the diverged fixture"; exit 2; }
    expect "H12 the remote diverged from HEAD (each has commits the other lacks) => rc 2 UNWITNESSED" 2 'history=UNWITNESSED' 'NOT an ancestor' -- STRICT "$H/store"
    H="$T/h1b"; newh "$H" 2 && AW "$H/store" && hc "$H" a2 && remote_of "$H" || { echo "  UNDETERMINED: cannot build the named-remote fixture"; exit 2; }
    expect "H13 an explicit --witness-remote that is not a configured remote => refused, rc 2" 2 'is not a configured remote' 'witness remote: nosuch' -- STRICT "$H/store" --witness-remote nosuch
    expect "H14 the witness remote is named in the output (default origin, fetched now)" 0 'history=HOLDS' 'witness remote "origin"' -- STRICT "$H/store"
    # H15 — review T015d F3: the witness fetch is an execution surface. An
    # ext:: remote (allowed by the repo's OWN config) and a reference-transaction
    # hook must NOT run. git-remote-ext splits on spaces without quoting, so the
    # helper is a spaceless script path (a quoted `sh -c` would never run).
    H="$T/h15"; newh "$H" 2 && AW "$H/store" && hc "$H" a2 && remote_of "$H" || { echo "  UNDETERMINED: cannot build the ext fixture"; exit 2; }
    printf '#!/bin/sh\n: > "%s"\nexit 0\n' "$T/h15.hook-ran" > "$H/.git/hooks/reference-transaction"; chmod +x "$H/.git/hooks/reference-transaction"
    expect "H15a a reference-transaction hook in the anchor's repository does not run on the witness fetch" 0 'history=HOLDS' -- STRICT "$H/store"
    [ ! -e "$T/h15.hook-ran" ] && ok "H15a (marker) the hook left no marker" || bad "H15a the repository hook RAN on the witness fetch"
    printf '#!/bin/sh\n: > "%s"\nexit 0\n' "$T/h15.ext-ran" > "$T/h15.helper"; chmod +x "$T/h15.helper"
    git -C "$H" config protocol.ext.allow always; git -C "$H" remote set-url origin "ext::$T/h15.helper"
    expect "H15b an ext:: witness remote is refused (UNWITNESSED, rc 2), never executed" 2 'history=UNWITNESSED' -- STRICT "$H/store"
    [ ! -e "$T/h15.ext-ran" ] && ok "H15b (marker) the ext:: helper was not executed" || bad "H15b the ext:: remote helper RAN"
    # H16-H19 — review T014 N3: the witness fetch used to recurse into
    # populated submodules, trigger auto-maintenance, and let this
    # repository's OWN config execute an upload-pack program during a
    # local-transport fetch. H16-H18 must now be closed (marker absent);
    # H19 pins the DOCUMENTED residual (core.sshCommand): still runs,
    # deliberately, because pinning it would break a real ssh operator setup.
    H="$T/h16"; newh "$H" 2 && AW "$H/store" && hc "$H" a2 && remote_of "$H" || { echo "  UNDETERMINED: cannot build the uploadpack fixture"; exit 2; }
    printf '#!/bin/sh\n: > "%s"\nexit 1\n' "$T/h16.marker" > "$T/h16.upload.sh"; chmod +x "$T/h16.upload.sh"
    git -C "$H" config remote.origin.uploadpack "$T/h16.upload.sh"
    expect "H16 remote.origin.uploadpack named by the repository's OWN config is overridden (--upload-pack=git-upload-pack), never executed" 0 'history=HOLDS' -- STRICT "$H/store"
    [ ! -e "$T/h16.marker" ] && ok "H16 (marker) the configured uploadpack program was not executed" || bad "H16 the configured uploadpack program RAN"
    H="$T/h17"; newh "$H" 2 && AW "$H/store" && hc "$H" a2 && remote_of "$H" || { echo "  UNDETERMINED: cannot build the fsmonitor fixture"; exit 2; }
    printf '#!/bin/sh\n: > "%s"\necho '"'"'{"version":2,"clock":"c:0:0","is_fresh_instance":true,"files":[]}'"'"'\nexit 0\n' "$T/h17.marker" > "$T/h17.fsmon.sh"; chmod +x "$T/h17.fsmon.sh"
    git -C "$H" config core.fsmonitor "$T/h17.fsmon.sh"
    expect "H17 a core.fsmonitor hook named by the repository's OWN config does not run on the witness fetch" 0 'history=HOLDS' -- STRICT "$H/store"
    [ ! -e "$T/h17.marker" ] && ok "H17 (marker) the fsmonitor hook was not executed" || bad "H17 the fsmonitor hook RAN"
    H="$T/h18"; newh "$H" 2 && AW "$H/store" && hc "$H" a2 && remote_of "$H" || { echo "  UNDETERMINED: cannot build the insteadOf fixture"; exit 2; }
    printf '#!/bin/sh\n: > "%s"\nexit 1\n' "$T/h18.marker" > "$T/h18.helper"; chmod +x "$T/h18.helper"
    origin_url=$(git -C "$H" remote get-url origin)
    git -C "$H" config protocol.ext.allow always
    git -C "$H" config "url.ext::$T/h18.helper.insteadOf" "$origin_url"
    expect "H18 an insteadOf rewrite RETARGETING origin to ext:: is refused before the helper runs (allowlist checks the resolved URL)" 2 'history=UNWITNESSED' -- STRICT "$H/store"
    [ ! -e "$T/h18.marker" ] && ok "H18 (marker) the insteadOf-redirected ext:: helper was not executed" || bad "H18 the insteadOf-redirected ext:: helper RAN"
    H="$T/h19"; newh "$H" 2 && AW "$H/store" && hc "$H" a2 && remote_of "$H" || { echo "  UNDETERMINED: cannot build the sshCommand fixture"; exit 2; }
    printf '#!/bin/sh\n: > "%s"\nexit 1\n' "$T/h19.marker" > "$T/h19.ssh.sh"; chmod +x "$T/h19.ssh.sh"
    git -C "$H" config core.sshCommand "$T/h19.ssh.sh"
    git -C "$H" remote set-url origin "ssh://nosuchhost.invalid/x/y.git"
    V STRICT "$H/store" >"$T/h19.out" 2>&1
    [ -e "$T/h19.marker" ] && ok "H19 (documented residual, review T014 N3) core.sshCommand still names a program the fetch runs — pinning it would break a real ssh operator setup, so it is intentionally NOT neutralised" \
        || bad "H19 core.sshCommand no longer ran on the witness fetch — either the residual was silently closed (good, but update the header) or this fixture broke"
    H="$T/h20"; newh "$H" 2 && AW "$H/store" && hc "$H" a2 && remote_of "$H" || { echo "  UNDETERMINED: cannot build the credential-helper fixture"; exit 2; }
    "$ATTK" httpsrv401 > "$T/h20.url" 2>"$T/h20.srv.log" &
    h20_pid=$!
    for _i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do [ -s "$T/h20.url" ] && break; sleep 0.1; done
    h20_url=$(cat "$T/h20.url" 2>/dev/null)
    if [ -z "$h20_url" ]; then
        echo "  UNDETERMINED: the local TLS 401 test server did not start: $(cat "$T/h20.srv.log" 2>/dev/null | tr '\n' ' ')"
        kill "$h20_pid" 2>/dev/null || true
    else
        printf '#!/bin/sh\n: > "%s"\ncat >/dev/null\necho username=x\necho password=y\nexit 0\n' "$T/h20.marker" > "$T/h20.cred.sh"; chmod +x "$T/h20.cred.sh"
        git -C "$H" config http.sslVerify false
        git -C "$H" config credential.helper "$T/h20.cred.sh"
        git -C "$H" remote set-url origin "$h20_url/repo.git"
        V STRICT "$H/store" >"$T/h20.out" 2>&1
        [ -e "$T/h20.marker" ] && ok "H20 (documented residual, review T014 N3 rev-n3) credential.helper still names a program the fetch runs against a REAL reachable 401 over https — pinning it would break a real credential-helper operator setup, so it is intentionally NOT neutralised" \
            || bad "H20 credential.helper did NOT run against a real reachable 401 — either the residual was silently closed (good, but update the header) or this fixture broke"
        kill "$h20_pid" 2>/dev/null || true
    fi
    wait "$h20_pid" 2>/dev/null || true
    # L3 — review T015d F4: a FORGED ZG_LOCK_MODE=exclusive on a descriptor
    # held SHARED must not convert the lock (a failed conversion DROPS it and
    # the holder then runs unlocked). A second reader makes the conversion
    # impossible; afterwards an exclusive probe must still be refused.
    copy; rm -f "$T/l3.out"
    # The second reader must BE the process holding its descriptor (`exec`),
    # so killing its pid really releases it: `flock -s dir sleep` would leave
    # an orphan sleep holding the lock and make the final probe fail for the
    # wrong reason (measured: the case read HELD before the fix).
    "$ZG_CHAIN_BIN" with-lock --store "$T/c" --shared -- /bin/bash -c '
        ( exec 8<"$2" && flock -s 8 && exec sleep 60 ) & r=$!
        sleep 0.3
        ZG_LOCK_MODE=exclusive "$1" verify --store "$2" --schema "$3" --lock-timeout 1s >"$4" 2>&1; vrc=$?
        kill -9 "$r" 2>/dev/null; wait "$r" 2>/dev/null
        if flock -x -n "$2" true; then echo "DROPPED vrc=$vrc"; else echo "HELD vrc=$vrc"; fi' x "$ZG_CHAIN_BIN" "$T/c" "$ZGE_CONTRACT" "$T/l3.out" >"$T/l3.res" 2>&1
    grep -q '^HELD' "$T/l3.res" && ! grep -q '^HOLDS sidecar' "$T/l3.out" \
        && ok "L3 forged ZG_LOCK_MODE=exclusive on a SHARED descriptor: no conversion, the holder's lock survives ($(cat "$T/l3.res"))" \
        || bad "L3 forged lock mode: $(cat "$T/l3.res") verify=$(head -1 "$T/l3.out")"
    # L2 — the environment cannot skip the lock: a FORGED ZGC_LOCKED / ZG_LOCK_*
    # set while a real append holds the store mid-write must still wait.
    copy; rm -f "$T/held" "$T/release"
    "$ZG_CHAIN_BIN" with-lock --store "$T/c" --exclusive -- /bin/sh -c '
        cp "$1/sidecar.jsonl" "$1/s.keep"; cp "$1/chain.jsonl" "$1/c.keep"
        sed -n 1p "$1/sidecar.jsonl" >> "$1/sidecar.jsonl"; printf "{\"seq\":9" >> "$1/chain.jsonl"
        : > "$2"; while [ ! -e "$3" ]; do sleep 0.05; done
        mv "$1/s.keep" "$1/sidecar.jsonl"; mv "$1/c.keep" "$1/chain.jsonl"' x "$T/c" "$T/held" "$T/release" >"$T/holder.out" 2>&1 &
    hpid=$!
    for i in $(seq 1 200); do [ -e "$T/held" ] && break; sleep 0.05; done
    ZGC_LOCKED=1 ZG_LOCK_FD=9 ZG_LOCK_MODE=shared V "$T/c" >"$T/out" 2>&1 &
    vpid=$!
    waited=n; for i in $(seq 1 20); do sleep 0.05; done; ps -p "$vpid" >/dev/null 2>&1 && waited=y
    : > "$T/release"; wait "$hpid"; wait "$vpid"; vrc=$?
    [ "$waited" = y ] && [ "$vrc" -eq 0 ] && grep -q 'VERDICT HOLDS' "$T/out" \
        && ok "L2 forged ZGC_LOCKED=1 / ZG_LOCK_FD / ZG_LOCK_MODE did NOT skip the lock: verify waited, then HOLDS" \
        || bad "L2 forged lock env (waited=$waited rc=$vrc): $(grep VERDICT "$T/out")"
    # L1 — a REAL concurrent append holds the exclusive lock while BOTH files are
    # mid-write (sidecar one line ahead, chain carrying a torn line): verify must
    # WAIT for it, then report the consistent store — never a false VIOLATED.
    copy; rm -f "$T/held" "$T/release"
    "$ZG_CHAIN_BIN" with-lock --store "$T/c" --exclusive -- /bin/sh -c '
        cp "$1/sidecar.jsonl" "$1/s.keep"; cp "$1/chain.jsonl" "$1/c.keep"
        sed -n 1p "$1/sidecar.jsonl" >> "$1/sidecar.jsonl"; printf "{\"seq\":9" >> "$1/chain.jsonl"
        : > "$2"; while [ ! -e "$3" ]; do sleep 0.05; done
        mv "$1/s.keep" "$1/sidecar.jsonl"; mv "$1/c.keep" "$1/chain.jsonl"' x "$T/c" "$T/held" "$T/release" >"$T/holder.out" 2>&1 &
    hpid=$!
    for i in $(seq 1 200); do [ -e "$T/held" ] && break; sleep 0.05; done
    V "$T/c" >"$T/out" 2>&1 &
    vpid=$!
    waited=n; for i in $(seq 1 20); do sleep 0.05; done; ps -p "$vpid" >/dev/null 2>&1 && waited=y
    : > "$T/release"; wait "$hpid"; wait "$vpid"; vrc=$?
    [ -e "$T/held" ] && [ "$waited" = y ] && [ "$vrc" -eq 0 ] && grep -q 'VERDICT HOLDS' "$T/out" \
        && ok "L1 verify WAITED for a real in-progress append (both files mid-write) and then read HOLDS" \
        || bad "L1 concurrent append (held=$([ -e "$T/held" ] && echo y || echo n) waited=$waited rc=$vrc): $(grep VERDICT "$T/out")"
    # M2 — stale incoming dirs are named even when the store is absent
    sh -c 'exit 0' & dead=$!; wait "$dead"
    mkdir -p "$T/ss/.incoming.$dead.m2" && printf '%s 1\n' "$dead" > "$T/ss/.incoming.$dead.m2/owner"
    bash "$ZGC_HERE/zero-gap-evidence-chain.sh" --verify "$T/no-store" --anchor "$T/no-store/a.json" --streams "$T/ss" >"$T/out" 2>&1; rc=$?
    [ "$rc" -eq 2 ] && grep -q "STALE incoming .incoming.$dead.m2" "$T/out" && ok "M2 absent store: the stale incoming dir is still named (rc 2)" \
        || bad "M2 absent store + stale incoming (rc=$rc): $(head -2 "$T/out" | tr '\n' ' ')"
    # M4 — the fixtures opt-in is refused for the tracked default anchor
    copy; bash "$ZGC_HERE/zero-gap-evidence-chain.sh" --verify "$T/c" --streams "$T/streams" --allow-untracked-anchor >"$T/out" 2>&1; rc=$?
    [ "$rc" -eq 2 ] && grep -q 'allow-untracked-anchor is refused' "$T/out" && ok "M4 --allow-untracked-anchor with the default tracked anchor path => refused, rc 2" \
        || bad "M4 opt-in on the default anchor (rc=$rc): $(head -2 "$T/out" | tr '\n' ' ')"

    # ── Fix round 1 (review T015) ───────────────────────────────────────────
    copy
    expect "D1 the DEFAULT is strict: a healthy store whose anchor is untracked is rc 2, never HOLDS" 2 'history=NOT_APPLICABLE' -- STRICT "$T/c"
    copy; for f in chain.jsonl sidecar.jsonl; do head -n 2 "$T/c/$f" > "$T/x" && mv "$T/x" "$T/c/$f"; done
    anchor_json 2 "$("$ATTK" digest "$T/c/chain.jsonl" 2)" > "$T/c/anchor.json"
    expect "D2 reviewer attack: both tails truncated + untracked anchor rewritten lower => rc 2 under the default (it read HOLDS before)" 2 'VERDICT UNDETERMINED' -- STRICT "$T/c"
    copy; bash "$ZGC_HERE/zero-gap-evidence-chain.sh" --verify "$T/c" --streams "$T/streams" >"$T/out" 2>&1
    grep -q 'docs/zero-gap/anchor.json' "$T/out" && ok "D3 the default anchor is the TRACKED docs/zero-gap/anchor.json (read-only probe)" \
        || bad "D3 default anchor path not docs/zero-gap/anchor.json: $(grep -E 'anchor' "$T/out" | head -2 | tr '\n' ' ')"
    bash "$ZGC_HERE/zero-gap-evidence-chain.sh" --verify --streams "$T/streams" >"$T/out" 2>&1
    grep -q '.remember/logs/zero-gap/evidence' "$T/out" && ok "D4 the default store is the untracked .remember/logs/zero-gap/evidence (read-only probe)" \
        || bad "D4 default store: $(head -2 "$T/out" | tr '\n' ' ')"
    copy; trunc_bytes "$T/c/chain.jsonl" 1
    expect "C3 chain file without its final newline (upstream still walks it) => [I10]" 1 'I10-chain-byte-rule' -- "$T/c"
    copy; rm -f "$T/c/anchor.json"
    bash "$ZGC_HERE/zero-gap-evidence-chain.sh" --anchor-write "$T/c" --anchor "$T/aw1.json" >"$T/out" 2>&1; rc=$?
    [ "$rc" -eq 2 ] && [ ! -e "$T/aw1.json" ] && grep -q -- '--remote' "$T/out" && ok "AW1 --anchor-write without --remote or --unprobed => rc 2, nothing written" \
        || bad "AW1 anchor write without a probe (rc=$rc, written=$([ -e "$T/aw1.json" ] && echo y || echo n))"
    bash "$ZGC_HERE/zero-gap-evidence-chain.sh" --anchor-write "$T/c" --anchor "$T/aw2.json" --unprobed >"$T/out" 2>&1; rc=$?
    [ "$rc" -eq 0 ] && [ "$(jq -r .anchor_strength "$T/aw2.json" 2>/dev/null)" = unknown ] && ok "AW2 --unprobed => rc 0, strength recorded honestly as unknown" \
        || bad "AW2 --unprobed (rc=$rc)"
    printf '#!/bin/sh\n"%s" "$@"\nexit 0\n' "$ZG_INTEGRITY_BIN" > "$T/bin/liar"; chmod +x "$T/bin/liar"
    copy; for f in chain.jsonl sidecar.jsonl; do head -n 2 "$T/c/$f" > "$T/x" && mv "$T/x" "$T/c/$f"; done
    ZG_INTEGRITY_BIN="$T/bin/liar" V "$T/c" >"$T/out" 2>&1; rc=$?
    [ "$rc" -eq 2 ] && grep -q 'anchor=INCONSISTENT' "$T/out" && ok "IC1 upstream exit code contradicting its own anchor verdict => anchor=INCONSISTENT, rc 2" \
        || bad "IC1 anchor cross-check (rc=$rc): $(grep VERDICT "$T/out")"
    sh -c 'exit 0' & dead=$!; wait "$dead"
    mkdir -p "$T/streams/.incoming.$dead.proof" && printf '%s 1\n' "$dead" > "$T/streams/.incoming.$dead.proof/owner"
    copy; expect "ST1 a stale .incoming directory (dead owner) under the streams root => rc 2, named" 2 'incoming=STALE' "STALE incoming \.incoming\.$dead\.proof" -- "$T/c"
    rm -rf "$T/streams/.incoming.$dead.proof"
    X="$T/xstore"
    bash "$ZGE_HERE/zero-gap-evidence.sh" record --store "$X" --streams "$T/xstreams" --fp-dir "$W" \
        --item-id ATM-001 --check-id x --population-kind source --verdict-role author \
        --independence-tier instance --evidence-class runtime --verdict-exit \
        -- /bin/sh -c 'exit 0' 'q"uote' "$(printf 't\tab')" "$(printf 'new\nline')" >/dev/null 2>&1
    out=$("$ATTK" execrows "$T/xstreams/exec_rows.jsonl" "$X/chain.jsonl" 2>&1); rc=$?
    [ "$rc" -eq 0 ] && ok "X1 exec_rows.jsonl after a quote/tab/newline command: $out" || bad "X1 exec rows: $out"

    zg_manifest "$ZGE_ROOT" "${LIVE[@]}" > "$T/live1" 2>/dev/null || : > "$T/live1"
    if ! cmp -s "$T/live0" "$T/live1"; then
        echo "  UNDETERMINED: the live inputs changed while the proof ran:"
        { diff "$T/live0" "$T/live1" || true; } | sed -n 's/^[<>] //p' | cut -f1 | LC_ALL=C sort -u | sed 's/^/    /'
        echo "prove-failure: $pass passed, $fail failed (live inputs moved)"; exit 2
    fi
    ok "Z live inputs byte-identical before and after"
    echo "prove-failure: $pass passed, $fail failed"
    [ "$fail" -eq 0 ] && exit 0
    exit 1
)

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    witness=""
    store="" anchor="$ZGE_ROOT/docs/zero-gap/anchor.json" allow=0 remote="" unprobed=0 mode="" streams=""
    case "${1:-}" in
        --verify|--anchor-write)
            [ "$1" = --verify ] && mode=verify || mode=write
            shift
            if [ "$#" -gt 0 ] && [ "${1#--}" = "$1" ]; then store=$1; shift; fi ;;
        --prove-failure) zgc_prove_failure; exit $? ;;
        -h|--help)       sed -n '2,142p' "$0"; exit 0 ;;
        *) zgc_say "usage: --verify [<store>] [--anchor P] [--streams D] [--allow-untracked-anchor] [--witness-remote R] | --anchor-write [<store>] [--anchor P] (--remote R | --unprobed) | --prove-failure"; exit 2 ;;
    esac
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --anchor) anchor=${2:-}; shift 2 ;;
            --streams) streams=${2:-}; shift 2 ;;
            --allow-untracked-anchor) allow=1; shift ;;
            --witness-remote) witness=${2:-}; [ -n "$witness" ] || { zgc_say "empty --witness-remote"; exit 2; }; shift 2 ;;
            --remote) remote=${2:-}; shift 2 ;;
            --unprobed) unprobed=1; shift ;;
            *) zgc_say "unknown argument '$1'"; exit 2 ;;
        esac
    done
    [ -n "$store" ] || store="${ZG_STORE_DIR:-$ZGE_DEFAULT_STORE}"
    [ -n "$streams" ] || streams="${ZG_STREAMS_DIR:-$store/streams}"
    [ -n "$anchor" ] || { zgc_say "empty --anchor"; exit 2; }
    if [ "$mode" = verify ]; then zgc_verify "$store" "$anchor" "$allow" "$streams" "$witness"; exit $?; fi
    zgc_anchor_write "$store" "$anchor" "$remote" "$unprobed"; exit $?
fi
