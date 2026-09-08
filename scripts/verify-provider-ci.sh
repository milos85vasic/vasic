#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# verify-provider-ci.sh — MEASURE provider-side CI triggering, per host, per repo.
#
# WHY THIS EXISTS
# ---------------
# §11.4.156 mandates that a push to one of OUR upstreams trigger ZERO
# provider-side runs, and closes with an honest boundary:
#
#   "file-level disabling stops FILE-triggered runs; it does NOT disable
#    provider-side server settings the agent cannot reach (org-default required
#    workflows, branch-protection required checks, provider-side scheduled
#    exports) — those MUST be turned off in provider settings by the operator,
#    and the agent documents what it cannot reach rather than claiming a
#    completeness it did not achieve."
#
# That boundary has, until now, been carried as hand-written prose naming
# specific repositories and specific findings. Prose goes stale the instant a
# provider setting changes, and prose cannot be re-run. This script replaces the
# assertion with a measurement.
#
# The blind spot it exists to expose: a provider can run CI for a repository
# that contains ZERO workflow files. `git ls-files | grep '^\.github/workflows/'`
# returns empty and every file-level gate says PASS, while the provider queues a
# run on every push because of a server-side setting — a Pages source in
# "deploy from a branch" mode, an org-default required workflow, a provider-side
# schedule. No amount of reading the tree can see that. Only asking the provider
# can, so this asks the provider.
#
# §11.4.156(C) scope: "repositories we author + push". Ownership is DERIVED here
# (from the tree's own remotes, from the authenticated provider identity, and
# from the provider's own report of push permission) — never from a name list
# baked into this file. Adding, renaming or removing a submodule needs no edit
# here. A repository whose ownership cannot be established is reported UNKNOWN
# and is never edited, never assumed inert, and never counted as compliant.
#
# §11.4.6: inertness is a FACT to be verified, never assumed. A missing
# credential is NOT a pass — it is exit code 2.
#
# ── Usage ────────────────────────────────────────────────────────────────────
#   scripts/verify-provider-ci.sh [options]
#     --root <dir>     tree to inspect (default: this script's parent directory)
#     --json           machine-readable output on stdout, human log on stderr
#     --quiet          table + verdict only; suppress the per-row evidence block
#     --no-recurse     do not descend into nested submodules
#     --window <days>  "recent run" window for provider run history (default 30)
#     --list-repos     print the discovered repositories + derived ownership,
#                      then exit 0 without querying any provider
#     --selftest       run the §1.1 mutation battery against this host and exit
#                      0 only if every case moved the verdict as expected
#     --help           this text
#
# ── Per-row TRIGGER states ───────────────────────────────────────────────────
#   CONFIRMED     a STANDING provider setting triggers runs right now: a legacy
#                 Pages source, GitLab Auto DevOps, an active pipeline schedule,
#                 a ruleset imposing required workflows. Present tense, and no
#                 file in the tree can remove it.
#   HISTORICAL    provider-generated runs DID occur inside the window, but no
#                 standing setting readable now produces them. A fact about the
#                 past, deliberately NOT dressed up as a fact about today — and
#                 deliberately not hidden either.
#   NONE          nothing provider-side triggers a run. File-level CI, if the
#                 tree declares any, is reported separately: that is visible to
#                 file gates and is a §11.4.156(A)/(B) matter, not this one.
#   UNVERIFIED    the question could not be answered. Never a pass.
#   OUT-OF-SCOPE  §11.4.156(C): an upstream we do not push. Inert to us, and
#                 never to be edited.
#
# ── Exit codes (three-valued, per this project's convention) ─────────────────
#     0  no standing provider-side trigger, and everything in scope was checked
#     1  provider-side triggering CONFIRMED for at least one owned upstream
#     2  COULD NOT DETERMINE — some owned upstream could not be checked
#        (no API client, unauthenticated, network failure, insufficient scope,
#        or ownership itself undeterminable)
#   Precedence: CONFIRMED (1) outranks UNDETERMINED (2) outranks clean (0).
#   A CONFIRMED finding is a fact and is reported as such; the rows that could
#   not be checked are ALWAYS listed regardless of the exit code, so a 1 never
#   hides a 2 and a 2 never reads as a 0. HISTORICAL rows do not move the exit
#   code — they are not a present-tense claim — but they are counted in the
#   summary and called out in the verdict line so a 0 cannot read as "nothing
#   ever ran here".
#
# ── Side effects ─────────────────────────────────────────────────────────────
#   NONE. Every provider call is a read (HTTP GET). No git command that writes
#   is run: no fetch, no push, no checkout, no submodule update, no config
#   write. No provider setting is changed — this script reports, the operator
#   decides. It does not write to any repository working tree.
#
# ── Dependencies ─────────────────────────────────────────────────────────────
#   Required: bash 4+, git, date.
#   Optional per provider (absence downgrades rows to UNVERIFIED, never to OK):
#     github.com  -> `gh`, authenticated (`gh auth status`)
#     gitlab.com  -> `glab`, authenticated, plus `jq`
#     gitflic.ru  -> `curl` + `jq`, credential in $GITFLIC_TOKEN  (HTTP adapter)
#     gitverse.ru -> `curl` + `jq`, credential in $GITVERSE_TOKEN (HTTP adapter)
#   Any other host has no adapter registered and is reported UNVERIFIED with
#   that as the stated reason. GitHub's answer is never generalised to a host
#   that was not asked.
#
# ── The two HTTP adapters, and their honest ceiling ──────────────────────────
# Neither of these hosts ships a CLI, so their adapters speak HTTP directly.
# Both are READ-ONLY: every call is a GET and no request body is ever sent.
# Credentials are handed to curl on STDIN (`curl -K -`), never in argv, because
# an argv secret is readable by every process on the host through /proc.
#
# Read this before trusting either row, because the two ceilings DIFFER:
#
#   gitflic.ru   CANNOT reach NONE, by construction, and says so on every row.
#                GitFlic's pipeline SCHEDULER — the one standing, server-side,
#                push-independent trigger it has — is configured in the project
#                web UI, and GitFlic's REST API documents no endpoint that reads
#                it. So the standing-trigger question is structurally
#                unanswerable read-only on this host TODAY, with or without a
#                credential. The adapter still reads what it can (project
#                object, mirror state, pipeline history) and reports it, then
#                returns UNVERIFIED naming exactly the one question it could not
#                put. That is "asked, and could not determine" — never a pass.
#
#   gitverse.ru  CAN reach NONE. Its route set was established empirically
#                against the live host (a route that exists answers 401 without
#                a credential; a route that does not answer 400), so the adapter
#                asks only routes that were observed to exist: the repository
#                object, the Actions workflow list, the Actions run history and
#                the server-side webhook list. If every one answers and none
#                shows a trigger, NONE is a measured verdict rather than an
#                assumed one.
#
# Both API base URLs are overridable ($GITFLIC_API_BASE / $GITVERSE_API_BASE)
# for self-hosted installations — which is also the lever the §1.1 mutation
# battery pulls, so every new case is driven by DATA rather than by editing the
# adapter it tests.
# ------------------------------------------------------------------------------
set -uo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
JSON=0
QUIET=0
RECURSE=1
WINDOW_DAYS=30
LIST_ONLY=0
SELFTEST=0

usage() {
    # Print the header block itself, so --help can never drift from the truth.
    awk 'NR==1{next} /^#/{sub(/^# ?/,""); print; next} {exit}' "${BASH_SOURCE[0]}"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --root)        ROOT="$(cd -- "${2:-}" 2>/dev/null && pwd)" || { echo "FATAL: --root: no such directory '${2:-}'" >&2; exit 2; }; shift 2 ;;
        --json)        JSON=1; shift ;;
        --quiet)       QUIET=1; shift ;;
        --no-recurse)  RECURSE=0; shift ;;
        --window)      WINDOW_DAYS="${2:-30}"; shift 2 ;;
        --list-repos)  LIST_ONLY=1; shift ;;
        --selftest)    SELFTEST=1; shift ;;
        --help|-h)     usage; exit 0 ;;
        *)             echo "FATAL: unknown option '$1' (try --help)" >&2; exit 2 ;;
    esac
done

[[ "$WINDOW_DAYS" =~ ^[0-9]+$ ]] || { echo "FATAL: --window expects an integer number of days" >&2; exit 2; }

# ══════════════════════════════════════════════════════════════════════════════
# SELF-TEST (§1.1 mutation pairing) — a checker that cannot fail is worthless.
#
# Each case MUTATES a condition and asserts the verdict MOVES. Every fixture is
# derived from this tree at run time: no repository name, URL or path is written
# here, so the battery keeps working when a submodule is added or renamed.
# It re-invokes this script as a subprocess, so it exercises the real entry
# point rather than internal functions. Every provider call it makes is a read.
# ══════════════════════════════════════════════════════════════════════════════
ST_PASS=0; ST_FAIL=0
st_case() {  # $1 name, $2 expectation, $3 outcome, $4 ok?(0/1), $5 detail
    if [[ "$4" -eq 0 ]]; then
        ST_PASS=$((ST_PASS + 1)); printf 'PASS  %-38s expected %-28s got %s\n' "$1" "$2" "$3"
    else
        ST_FAIL=$((ST_FAIL + 1)); printf 'FAIL  %-38s expected %-28s got %s\n' "$1" "$2" "$3"
        [[ -n "${5:-}" ]] && printf '      %s\n' "$5"
    fi
}

run_selftest() {
    local self="${BASH_SOURCE[0]}"
    command -v jq >/dev/null 2>&1 || { echo "SELFTEST FATAL: jq is required for the self-test" >&2; return 2; }
    local tmp; tmp="$(mktemp -d)" || return 2
    # shellcheck disable=SC2064
    trap "rm -rf '$tmp'" RETURN

    echo "self-test root: $ROOT"
    echo "scratch:        $tmp"
    echo

    # -- baseline: one real scan, reused by several cases --------------------
    local base="$tmp/base.json" brc jrc
    bash "$self" --root "$ROOT" --json >"$base" 2>"$tmp/base.log"; brc=$?
    jq -e . "$base" >/dev/null 2>&1; jrc=$?
    st_case "baseline --json is valid JSON" "parseable" \
        "$( [[ $jrc -eq 0 ]] && echo parseable || echo malformed )" "$jrc" "$(head -3 "$tmp/base.log")"
    [[ $jrc -eq 0 ]] || { echo "SELFTEST ABORT: baseline scan produced no usable JSON (rc=$brc)"; return 2; }

    # M1  DISCRIMINATION. If every row came back the same, the checker is
    #     constant and proves nothing. Two different verdicts over one run is
    #     the evidence that it actually measures something.
    local nstates
    nstates=$(jq -r '[.rows[].provider_trigger]|unique|length' "$base")
    st_case "M1 verdict is not constant" ">1 distinct state" "$nstates distinct" \
        "$( [[ "${nstates:-0}" -gt 1 ]] && echo 0 || echo 1 )" \
        "all rows returned the same state — the checker cannot distinguish anything"

    # M2  CONFIRMED is reachable AND is backed by a named standing setting,
    #     not by a default.
    local nconf conf_detail
    nconf=$(jq -r '.counts.confirmed' "$base")
    conf_detail=$(jq -r '[.rows[]|select(.provider_trigger=="CONFIRMED")|.detail]|first // ""' "$base")
    if [[ "${nconf:-0}" -gt 0 ]]; then
        st_case "M2 CONFIRMED cites a standing setting" "STANDING TRIGGER in detail" \
            "$( [[ "$conf_detail" == *"STANDING TRIGGER"* ]] && echo "cited" || echo "not cited" )" \
            "$( [[ "$conf_detail" == *"STANDING TRIGGER"* ]] && echo 0 || echo 1 )" "$conf_detail"
    else
        st_case "M2 CONFIRMED cites a standing setting" "n/a (0 confirmed here)" "skipped" 0
    fi

    # M3  CREDENTIAL REMOVED must read UNDETERMINED, never clean. This is the
    #     single most important case: the failure mode this script exists to
    #     prevent is a missing credential silently reading as compliance.
    # The provider CLIs are shadowed by stubs that fail the way an absent or
    # broken binary does, keeping the rest of PATH intact.
    local shim="$tmp/nobin"; mkdir -p "$shim"
    local b
    for b in gh glab; do printf '#!/bin/sh\nexit 127\n' >"$shim/$b"; chmod +x "$shim/$b"; done
    local rc3
    PATH="$shim:$PATH" bash "$self" --root "$ROOT" --json >"$tmp/m3.json" 2>"$tmp/m3.log"; rc3=$?
    st_case "M3 provider CLI unusable" "rc=2" "rc=$rc3" \
        "$( [[ $rc3 -eq 2 ]] && echo 0 || echo 1 )" "$(tail -3 "$tmp/m3.log")"
    # Counted from the structured output, so this is a count of ROWS, not of
    # lines that happened to match a pattern.
    local m3clean
    m3clean=$(jq -r '[.rows[]|select(.provider_trigger=="NONE" or .provider_trigger=="HISTORICAL")]|length' "$tmp/m3.json" 2>/dev/null)
    st_case "M3 no row reads as clean" "0 clean rows" "${m3clean:-?} clean rows" \
        "$( [[ "${m3clean:-1}" -eq 0 ]] && echo 0 || echo 1 )" \
        "$(jq -r '[.rows[]|select(.provider_trigger=="NONE")|.target]|join(", ")' "$tmp/m3.json" 2>/dev/null)"

    # M4  BOGUS CREDENTIAL is not the same as a missing one, and must also
    #     refuse to pass.
    local rc4
    GH_TOKEN="invalid-token-for-selftest" GITHUB_TOKEN="invalid-token-for-selftest" \
        GITLAB_TOKEN="invalid-token-for-selftest" \
        bash "$self" --root "$ROOT" --quiet >"$tmp/m4.log" 2>&1; rc4=$?
    st_case "M4 bogus credential" "rc=2" "rc=$rc4" \
        "$( [[ $rc4 -eq 2 ]] && echo 0 || echo 1 )" "$(tail -3 "$tmp/m4.log")"

    # M5  A REPOSITORY WITH NO REMOTES must not crash the run.
    local nr="$tmp/noremote"
    mkdir -p "$nr" && git -C "$nr" init -q 2>/dev/null
    local rc5
    bash "$self" --root "$nr" --quiet >"$tmp/m5.log" 2>&1; rc5=$?
    local m5row=1; grep -q 'no upstream configured' "$tmp/m5.log" && m5row=0
    st_case "M5 repo with no remotes" "reported, no crash" \
        "rc=$rc5 $( [[ $m5row -eq 0 ]] && echo 'row present' || echo 'row MISSING' )" \
        "$( [[ $rc5 -ne 0 && $rc5 -ne 2 ]] && echo 1 || echo $m5row )" "$(cat "$tmp/m5.log")"

    # M6  OWNERSHIP IS DERIVED, NOT NAMED. Every out-of-scope classification
    #     must cite a provider-reported push permission, and this file must not
    #     contain the name of ANY repository in the tree — otherwise ownership
    #     could be coming from a baked-in list.
    local tp_names tp_bad=0 tp_n=0 nm
    tp_names=$(jq -r '.repositories[]|select(.ownership=="THIRD-PARTY")|.evidence' "$base")
    while IFS= read -r ev; do
        [[ -z "$ev" ]] && continue
        tp_n=$((tp_n + 1))
        [[ "$ev" == *"push-perm"* ]] || tp_bad=$((tp_bad + 1))
    done <<<"$tp_names"
    if [[ $tp_n -gt 0 ]]; then
        st_case "M6a out-of-scope cites push permission" "all $tp_n derived" \
            "$((tp_n - tp_bad))/$tp_n derived" "$( [[ $tp_bad -eq 0 ]] && echo 0 || echo 1 )" "$tp_names"
    else
        st_case "M6a out-of-scope cites push permission" "n/a (none here)" "skipped" 0
    fi

    # M6b  NO REPOSITORY IDENTITY IN THE BODY.
    #
    # WHAT CHANGED AND WHY, stated rather than left to be discovered (§11.4.6).
    # No repository, owner or slug is written in this comment, for the same
    # reason the case exists — read the run output, which names what it found.
    #
    # This case used to split every discovered `owner/repo` slug on "/" and grep
    # the whole file for each bare component. On 2026-09-02 it reported exactly
    # one hit, and the hit was NOT a leak. A repository joined this tree in
    # 2026-09 whose BASENAME is an ordinary English word that this file has used
    # since long before that repository existed — 15 occurrences, as a shell
    # variable, as a JSON output key, and in prose. A bare English word in those
    # positions cannot be a baked-in ownership table: nothing here compares a
    # discovered repository against it. The old form could not tell the two
    # apart, so it graded a name COLLISION as a name LEAK. Renaming the English
    # word would have been a symptom fix that regresses the moment anyone writes
    # ordinary prose again, and any repository basename can be an English word.
    #
    # The fix makes the case test repository IDENTITY — what a baked-in list
    # must actually contain — and it is a STRENGTHENING, not a relaxation:
    #   * the FULL SLUG is now searched. It never was, and it is the single most
    #     likely shape for a hardcoded ownership table.
    #   * a basename in a path/URL position (`/x`, `:x`, `@x`, `x.git`, `x/`) is
    #     now searched. It never was.
    #   * a basename as a `case` ARM or as a `==` / `!=` / `=~` OPERAND is now
    #     searched — the only shell shapes in which a bare basename could be
    #     compared against the discovered name.
    #   * a basename on a line that also names a provider host or any discovered
    #     OWNER is now searched.
    #   * the OWNER sweep is unchanged and an owner is NEVER clearable: owner is
    #     the key ownership is actually derived on, and owner names have no
    #     ordinary-English use here.
    # A bare token is cleared ONLY when all of those come back empty AND the
    # token is a plain lowercase word of 4+ letters, so every name carrying a
    # hyphen, an underscore, a dot, a digit or a capital cannot take the
    # clearing route at all.
    #
    # The clearing is DERIVED, never declared. An exemption LIST would have to
    # write a repository name into this file — an allow-list here would BE the
    # defect M6 forbids. Every cleared token is PRINTED with its occurrence
    # count, so a clearing is visible rather than silent.
    local owners_re=""
    while IFS= read -r o; do
        [[ -z "$o" || "$o" == \(* ]] && continue
        owners_re="${owners_re}${owners_re:+|}$(printf '%s' "$o" | sed 's/[][\.^$*+?(){}|\\]/\\&/g')"
    done < <(jq -r '.rows[].target' "$base" | cut -d/ -f1 | sort -u)

    _ere() { printf '%s' "$1" | sed 's/[][\.^$*+?(){}|\\]/\\&/g'; }

    # A token used where a repository is IDENTIFIED: path, URL or ".git".
    _identity_position() {
        local t; t="$(_ere "$1")"
        grep -qE "([/:@]${t}([^[:alnum:]_.-]|\$)|${t}\.git|(^|[^[:alnum:]_.-])${t}/)" "$self"
    }
    # A token COMPARED against something: a `case` ARM anywhere on the line
    # (`case $x in tok)`, `;; tok|`, a line-leading arm), or the right-hand
    # operand of `=`, `==`, `!=` or `=~`. The arm alternative is deliberately
    # NOT line-anchored: a one-line `case $name in tok) ... esac` is the most
    # compact shape a baked-in ownership table can take, and an anchored form
    # missed exactly that (measured 2026-09-02 against a seeded mutant).
    _compared_against() {
        local t; t="$(_ere "$1")"
        grep -qE "((^|[[:space:]]|\(|\||;)[*]?\"?${t}\"?[*]?[[:space:]]*[|)]|[!=]=[[:space:]]*\"?${t}\"?([^[:alnum:]_.-]|\$)|=~[[:space:]]*\"?${t}\"?([^[:alnum:]_.-]|\$)|(^|[[:space:]])=[[:space:]]*\"?${t}\"?([^[:alnum:]_.-]|\$))" "$self"
    }
    # A token sitting on a line that also names a provider host or an owner.
    _near_an_owner() {
        local t; t="$(_ere "$1")"
        grep -E "(^|[^[:alnum:]_.-])${t}" "$self" \
            | grep -qE "github\.com|gitlab\.com${owners_re:+|$owners_re}"
    }

    local hard="" hits=0 cleared="" ncleared=0 nocc
    # 1. The full slug — unclearable, and never checked before this change.
    while IFS= read -r slug; do
        [[ -z "$slug" || "$slug" == \(* ]] && continue
        [[ "$slug" == */* ]] || continue
        if grep -qF -- "$slug" "$self"; then
            hard="${hard}${hard:+ }${slug}(slug)"; hits=$((hits + 1))
        fi
    done < <(jq -r '.rows[].target' "$base" | sort -u)

    # 2. Every bare component — owner and basename alike.
    while IFS= read -r nm; do
        [[ -z "$nm" ]] && continue
        grep -qF -- "$nm" "$self" || continue
        nocc="$(grep -cF -- "$nm" "$self")"
        if _identity_position "$nm"; then
            hard="${hard}${hard:+ }${nm}(path/URL)"; hits=$((hits + 1)); continue
        fi
        if _compared_against "$nm"; then
            hard="${hard}${hard:+ }${nm}(compared)"; hits=$((hits + 1)); continue
        fi
        if _near_an_owner "$nm"; then
            hard="${hard}${hard:+ }${nm}(beside an owner/host)"; hits=$((hits + 1)); continue
        fi
        # An OWNER is never cleared: an owner name has no ordinary-English use
        # here, and owner is the key ownership is actually derived on.
        if jq -r '.rows[].target' "$base" | cut -d/ -f1 | grep -qxF -- "$nm"; then
            hard="${hard}${hard:+ }${nm}(owner)"; hits=$((hits + 1)); continue
        fi
        if [[ "$nm" =~ ^[a-z]{4,}$ ]]; then
            cleared="${cleared}${cleared:+ }${nm}(x${nocc})"; ncleared=$((ncleared + 1)); continue
        fi
        hard="${hard}${hard:+ }${nm}(bare name)"; hits=$((hits + 1))
    done < <(jq -r '.rows[].target' "$base" | tr '/' '\n' | sort -u | grep -vE '^(\(|$)' )

    st_case "M6b no repository identity in body" "0 identities present" "$hits present" \
        "$( [[ $hits -eq 0 ]] && echo 0 || echo 1 )" "found: $hard"
    if [[ $ncleared -gt 0 ]]; then
        printf '      note: %d token(s) present but DERIVED to be English-word collisions,\n' "$ncleared"
        printf '            not identities — no path/URL, no comparison, no owner or host on\n'
        printf '            the line, and each is a plain lowercase word: %s\n' "$cleared"
    fi

    # M7  DISCOVERY uses -e, not -d. A submodule's .git is a FILE; a `-d` test
    #     would find zero of them. Assert that the tree really does present
    #     .git as a file somewhere AND that those repositories were discovered.
    local gitfiles=0 disc
    while IFS= read -r p; do
        [[ -f "$ROOT/$p/.git" ]] && gitfiles=$((gitfiles + 1))
    done < <(git -C "$ROOT" config -f "$ROOT/.gitmodules" --get-regexp '^submodule\..*\.path$' 2>/dev/null | sed 's/^[^ ]* //')
    disc=$(jq -r '.repositories|length' "$base")
    st_case "M7 gitlink files discovered" "$gitfiles gitlink file(s) < $disc found" \
        "$gitfiles vs $disc" "$( [[ $gitfiles -gt 0 && $disc -gt $gitfiles ]] && echo 0 || echo 1 )" \
        "if this reports 0 gitlink files the fixture is wrong, not the code"

    # ══════════════════════════════════════════════════════════════════════════
    # M8..M13 — THE TWO CLI-LESS HTTP ADAPTERS (gitflic.ru, gitverse.ru).
    #
    # Every case is driven by DATA — an environment variable naming a different
    # API base, and a stub that serves a different canned body. Not one of them
    # edits the adapter it tests, which is the whole point of a §1.1 pairing: a
    # proof that only passes because the thing it proves was rewritten proves
    # nothing.
    #
    # Each runs against a MINIMAL fixture tree — one `git init` with one remote
    # on the host under test — rather than against this tree. Two reasons, and
    # the second is the load-bearing one: it is fast, and it is HERMETIC, so a
    # case cannot pass or fail because of what some unrelated submodule's
    # provider happened to answer today.
    #
    # The battery deliberately contains BOTH polarities. A case proving the
    # adapter refuses to pass is worth little on its own — an adapter hardwired
    # to return UNVERIFIED would satisfy every one of them. M9 is the control
    # that must go GREEN, and M10 is the same fixture with one field changed
    # that must go RED. Together they prove the verdict tracks the data.
    # ══════════════════════════════════════════════════════════════════════════
    local stub="$tmp/stub.py"
    cat >"$stub" <<'STUBPY'
import json, os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
MODE = os.environ.get("STUB_MODE", "clean")
class H(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    def log_message(self, *a): pass
    def _send(self, code, obj):
        b = json.dumps(obj).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(b)))
        self.end_headers()
        self.wfile.write(b)
    def do_GET(self):
        p = self.path.split("?")[0]
        if MODE == "reject":
            return self._send(401, {"message": "stub rejects every credential"})
        if p == "/user":
            return self._send(200, {"login": "stub"})
        if p == "/project/my":
            return self._send(200, {"_embedded": {"projectList": []}})
        if p.endswith("/actions/workflows"):
            n = 2 if MODE == "trigger" else 0
            return self._send(200, {"total_count": n,
                                    "workflows": [{"id": i} for i in range(n)]})
        if p.endswith("/actions/runs"):
            return self._send(200, {"total_count": 0, "workflow_runs": []})
        if p.endswith("/hooks"):
            return self._send(200, [])
        if p.endswith("/cicd/pipeline"):
            return self._send(200, {"_embedded": {"pipelineList": []}})
        if p.startswith("/repos/"):
            return self._send(200, {"default_branch": "main", "archived": False})
        if p.startswith("/project/"):
            return self._send(200, {"mirror": False, "mirrorType": None,
                                    "defaultBranch": "main"})
        return self._send(404, {"message": "stub has no such route"})
srv = ThreadingHTTPServer(("127.0.0.1", 0), H)
print(srv.server_address[1], flush=True)
srv.serve_forever()
STUBPY

    # One fixture repository per host. The remote URL is synthesised from the
    # host token this script itself registers, so no repository in this tree is
    # named here and M6b stays satisfied.
    mk_fixture() {   # $1 = host, $2 = dir
        mkdir -p "$2" && git -C "$2" init -q 2>/dev/null || return 1
        git -C "$2" remote add origin "https://$1/fixtureowner/fixturerepo.git" 2>/dev/null
    }
    STUB_PID=""; STUB_PORT=""
    start_stub() {   # $1 = mode
        [[ -n "$STUB_PID" ]] && stop_stub
        local fifo="$tmp/stubport"; rm -f "$fifo"
        STUB_MODE="$1" python3 "$stub" >"$fifo" 2>/dev/null &
        STUB_PID=$!
        local n=0
        while [[ $n -lt 100 ]]; do
            STUB_PORT="$(head -1 "$fifo" 2>/dev/null)"
            [[ "$STUB_PORT" =~ ^[0-9]+$ ]] && return 0
            n=$((n + 1)); sleep 0.05
        done
        STUB_PORT=""; return 1
    }
    stop_stub() { [[ -n "$STUB_PID" ]] && kill "$STUB_PID" 2>/dev/null; wait "$STUB_PID" 2>/dev/null; STUB_PID=""; }

    if ! command -v python3 >/dev/null 2>&1; then
        st_case "M8..M13 HTTP adapter battery" "python3 for the stub" "python3 absent" 1 \
            "the battery cannot run without a stub server — this is UNRUN, not passed"
    else
        local fx_gvs="$tmp/fx-gitverse" fx_gfl="$tmp/fx-gitflic"
        mk_fixture "gitverse.ru" "$fx_gvs"; mk_fixture "gitflic.ru" "$fx_gfl"
        local rcx rowtrig

        # -- M8  UNREACHABLE HOST -> 2. THE case FR-011c exists for. Port 1 on
        #        loopback refuses instantly, which is a transport failure and
        #        not an answer.
        GITVERSE_API_BASE="http://127.0.0.1:1" GITVERSE_TOKEN="stub" \
            bash "$self" --root "$fx_gvs" --json >"$tmp/m8.json" 2>"$tmp/m8.log"; rcx=$?
        rowtrig="$(jq -r '[.rows[]|select(.provider=="gitverse.ru")|.provider_trigger]|join(",")' "$tmp/m8.json" 2>/dev/null)"
        st_case "M8 gitverse unreachable" "rc=2, row UNVERIFIED" "rc=$rcx, row=$rowtrig" \
            "$( [[ $rcx -eq 2 && "$rowtrig" == "UNVERIFIED" ]] && echo 0 || echo 1 )" \
            "$(jq -r '.adapters["gitverse.ru"].reason' "$tmp/m8.json" 2>/dev/null)"

        # -- M9  CONTROL THAT MUST GO GREEN. Every route answers, nothing is
        #        armed: the verdict must be NONE and the exit code 0. Without
        #        this case the battery would be satisfied by an adapter that
        #        can only ever say UNVERIFIED.
        if start_stub clean; then
            GITVERSE_API_BASE="http://127.0.0.1:$STUB_PORT" GITVERSE_TOKEN="stub" \
                bash "$self" --root "$fx_gvs" --json >"$tmp/m9.json" 2>"$tmp/m9.log"; rcx=$?
            rowtrig="$(jq -r '[.rows[]|select(.provider=="gitverse.ru")|.provider_trigger]|join(",")' "$tmp/m9.json" 2>/dev/null)"
            st_case "M9 gitverse control goes green" "rc=0, row NONE" "rc=$rcx, row=$rowtrig" \
                "$( [[ $rcx -eq 0 && "$rowtrig" == "NONE" ]] && echo 0 || echo 1 )" \
                "$(jq -r '[.rows[]|select(.provider=="gitverse.ru")|.detail]|first' "$tmp/m9.json" 2>/dev/null)"
            stop_stub
        else
            st_case "M9 gitverse control goes green" "stub server" "stub failed to start" 1 ""
        fi

        # -- M10 THE SAME FIXTURE, ONE FIELD CHANGED, MUST GO RED. The stub now
        #        reports workflows the tree does not declare. Only the DATA
        #        differs from M9.
        if start_stub trigger; then
            GITVERSE_API_BASE="http://127.0.0.1:$STUB_PORT" GITVERSE_TOKEN="stub" \
                bash "$self" --root "$fx_gvs" --json >"$tmp/m10.json" 2>"$tmp/m10.log"; rcx=$?
            rowtrig="$(jq -r '[.rows[]|select(.provider=="gitverse.ru")|.provider_trigger]|join(",")' "$tmp/m10.json" 2>/dev/null)"
            local m10det; m10det="$(jq -r '[.rows[]|select(.provider=="gitverse.ru")|.detail]|first // ""' "$tmp/m10.json" 2>/dev/null)"
            st_case "M10 gitverse standing trigger detected" "rc=1, CONFIRMED, cited" \
                "rc=$rcx, row=$rowtrig" \
                "$( [[ $rcx -eq 1 && "$rowtrig" == "CONFIRMED" && "$m10det" == *"STANDING TRIGGER"* ]] && echo 0 || echo 1 )" \
                "$m10det"
            stop_stub
        else
            st_case "M10 gitverse standing trigger detected" "stub server" "stub failed to start" 1 ""
        fi

        # -- M11 A REJECTED CREDENTIAL IS NOT A MISSING ONE, and neither is a
        #        pass. The stub answers 401 to everything.
        if start_stub reject; then
            GITVERSE_API_BASE="http://127.0.0.1:$STUB_PORT" GITVERSE_TOKEN="stub" \
                bash "$self" --root "$fx_gvs" --json >"$tmp/m11.json" 2>"$tmp/m11.log"; rcx=$?
            local m11state m11clean
            m11state="$(jq -r '.adapters["gitverse.ru"].state' "$tmp/m11.json" 2>/dev/null)"
            m11clean="$(jq -r '[.rows[]|select(.provider_trigger=="NONE" or .provider_trigger=="HISTORICAL")]|length' "$tmp/m11.json" 2>/dev/null)"
            st_case "M11 gitverse credential rejected" "rc=2, state=broken, 0 clean" \
                "rc=$rcx, state=$m11state, clean=$m11clean" \
                "$( [[ $rcx -eq 2 && "$m11state" == "broken" && "${m11clean:-1}" -eq 0 ]] && echo 0 || echo 1 )" \
                "$(jq -r '.adapters["gitverse.ru"].reason' "$tmp/m11.json" 2>/dev/null)"
            stop_stub
        else
            st_case "M11 gitverse credential rejected" "stub server" "stub failed to start" 1 ""
        fi

        # -- M12 THE GITFLIC CEILING IS ENFORCED, NOT ACCIDENTAL. Every gitflic
        #        route answers 200 and nothing is armed — and the row must STILL
        #        be UNVERIFIED, because the one standing-trigger question this
        #        vendor exposes no route for was never answered. This is the
        #        case that stops a future edit from quietly turning a structural
        #        unknown into a green.
        if start_stub clean; then
            GITFLIC_API_BASE="http://127.0.0.1:$STUB_PORT" GITFLIC_TOKEN="stub" \
                bash "$self" --root "$fx_gfl" --json >"$tmp/m12.json" 2>"$tmp/m12.log"; rcx=$?
            rowtrig="$(jq -r '[.rows[]|select(.provider=="gitflic.ru")|.provider_trigger]|join(",")' "$tmp/m12.json" 2>/dev/null)"
            local m12det; m12det="$(jq -r '[.rows[]|select(.provider=="gitflic.ru")|.detail]|first // ""' "$tmp/m12.json" 2>/dev/null)"
            st_case "M12 gitflic ceiling holds when API answers" "rc=2, UNVERIFIED, reason cited" \
                "rc=$rcx, row=$rowtrig" \
                "$( [[ $rcx -eq 2 && "$rowtrig" == "UNVERIFIED" && "$m12det" == *"STANDING-trigger question cannot be answered"* ]] && echo 0 || echo 1 )" \
                "$m12det"
            stop_stub
        else
            st_case "M12 gitflic ceiling holds when API answers" "stub server" "stub failed to start" 1 ""
        fi

        # -- M13 GITFLIC UNREACHABLE -> 2, with the transport failure named.
        GITFLIC_API_BASE="http://127.0.0.1:1" GITFLIC_TOKEN="stub" \
            bash "$self" --root "$fx_gfl" --json >"$tmp/m13.json" 2>"$tmp/m13.log"; rcx=$?
        local m13state
        m13state="$(jq -r '.adapters["gitflic.ru"].state' "$tmp/m13.json" 2>/dev/null)"
        rowtrig="$(jq -r '[.rows[]|select(.provider=="gitflic.ru")|.provider_trigger]|join(",")' "$tmp/m13.json" 2>/dev/null)"
        st_case "M13 gitflic unreachable" "rc=2, state=unreachable" \
            "rc=$rcx, state=$m13state, row=$rowtrig" \
            "$( [[ $rcx -eq 2 && "$m13state" == "unreachable" && "$rowtrig" == "UNVERIFIED" ]] && echo 0 || echo 1 )" \
            "$(jq -r '.adapters["gitflic.ru"].reason' "$tmp/m13.json" 2>/dev/null)"

        # -- M14 NO CREDENTIAL EVER REACHES THE PROCESS TABLE. The adapters hand
        #        curl its config on stdin precisely so a token cannot be read
        #        out of /proc by any other process on the host. Asserted on the
        #        source rather than trusted: no token variable may appear as a
        #        curl ARGUMENT anywhere in this file.
        local argvleak
        #        Comment lines are excluded before the search, not after: this
        #        header documents which variable holds which credential, and a
        #        rule that cannot tell prose from an invocation would force the
        #        documentation out to stay green — a symptom fix.
        argvleak="$(grep -vE '^[[:space:]]*#' "$self" \
            | grep -nE '(^|[^[:alnum:]_-])curl([[:space:]]|$)[^|;&]*\$\{?(GFL_TOKEN|GVS_TOKEN|GITFLIC_TOKEN|GITVERSE_TOKEN)' \
            | grep -v 'grep -nE' || true)"
        st_case "M14 no credential in curl argv" "0 occurrences" \
            "$( [[ -z "$argvleak" ]] && echo 0 || echo "$(printf '%s\n' "$argvleak" | wc -l)" ) occurrence(s)" \
            "$( [[ -z "$argvleak" ]] && echo 0 || echo 1 )" "$argvleak"

        # -- M14b M14's OWN PAIRED PROOF. A rule that reports zero because it
        #        matches nothing is worthless, so the same pattern is run over a
        #        seeded leak. The seed is DATA in a scratch file; this script is
        #        not touched.
        #        The seed is ASSEMBLED from pieces rather than written out
        #        literally, because a literal leak line here would be a leak
        #        line in this file and M14 would — correctly — flag its own
        #        fixture.
        local seed="$tmp/seeded-leak.sh"
        local _var='$GVS_TOKEN'
        local _bin
        _bin=cur; _bin="${_bin}l"
        printf '%s\n' '#!/usr/bin/env bash' \
            "# a comment naming $_var must NOT be flagged" \
            "out=\"\$($_bin -s -H \"Authorization: Bearer $_var\" https://example.invalid/user)\"" >"$seed"
        local seedhit seedcomment
        seedhit="$(grep -vE '^[[:space:]]*#' "$seed" \
            | grep -cE '(^|[^[:alnum:]_-])curl([[:space:]]|$)[^|;&]*\$\{?(GFL_TOKEN|GVS_TOKEN|GITFLIC_TOKEN|GITVERSE_TOKEN)')"
        seedcomment="$(grep -cE '^[[:space:]]*#.*GVS_TOKEN' "$seed")"
        st_case "M14b the argv rule detects a seeded leak" "1 hit, comment ignored" \
            "hits=$seedhit, comment-lines-present=$seedcomment" \
            "$( [[ "$seedhit" -eq 1 && "$seedcomment" -eq 1 ]] && echo 0 || echo 1 )" \
            "if this reports 0 hits the rule is inert and M14's zero means nothing"
    fi

    echo
    echo "self-test: $ST_PASS passed, $ST_FAIL failed"
    [[ $ST_FAIL -eq 0 ]]
}

if [[ $SELFTEST -eq 1 ]]; then
    run_selftest
    exit $?
fi

# Human output goes to stderr in --json mode so stdout stays parseable.
if [[ $JSON -eq 1 ]]; then exec 3>&2; else exec 3>&1; fi
say() { printf '%s\n' "$*" >&3; }

if [[ -t 1 && $JSON -eq 0 ]]; then
    C_RED=$'\033[0;31m'; C_GRN=$'\033[0;32m'; C_YEL=$'\033[1;33m'
    C_DIM=$'\033[2m'; C_BLD=$'\033[1m'; C_OFF=$'\033[0m'
else
    C_RED=""; C_GRN=""; C_YEL=""; C_DIM=""; C_BLD=""; C_OFF=""
fi

command -v git >/dev/null 2>&1 || { echo "FATAL: git not found" >&2; exit 2; }

# ── window boundary ───────────────────────────────────────────────────────────
# GNU and BSD date disagree; try both rather than assume one. The result is
# checked, not piped-and-hoped: a pipeline's status is its LAST command's, so a
# `date ... | sed ... || fallback` would never fire the fallback.
SINCE=""
SINCE="$(date -u -d "-${WINDOW_DAYS} days" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)"
if [[ -z "$SINCE" ]]; then
    SINCE="$(date -u -v-"${WINDOW_DAYS}"d +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)"
fi
if [[ -z "$SINCE" ]]; then
    say "${C_YEL}WARN${C_OFF}  neither GNU nor BSD date accepted a relative offset;"
    say "      run-history recency cannot be bounded — every listed run is reported."
fi

# ══════════════════════════════════════════════════════════════════════════════
# 1. DISCOVERY — the umbrella plus every submodule, found from the tree itself.
#
# A submodule's `.git` is a FILE (a gitdir pointer), not a directory. Testing
# `[[ -d "$p/.git" ]]` silently classifies every submodule as "not a repo"; that
# exact mistake has already caused data loss in this project. `-e` is the only
# correct test.
# ══════════════════════════════════════════════════════════════════════════════
declare -a REPO_DIR=()          # absolute path
declare -a REPO_REL=()          # path relative to ROOT
declare -A SEEN_DIR=()          # cycle / duplicate guard, keyed by realpath
declare -a UNINIT=()            # declared submodules with no .git present

abspath() { (cd -- "$1" 2>/dev/null && pwd) }

add_repo() {
    local dir="$1" real
    real="$(abspath "$dir")" || return 1
    [[ -n "$real" ]] || return 1
    [[ -n "${SEEN_DIR[$real]:-}" ]] && return 1
    SEEN_DIR["$real"]=1
    REPO_DIR+=("$real")
    local rel="${real#"$ROOT"/}"
    [[ "$rel" == "$real" ]] && rel="."
    REPO_REL+=("$rel")
    return 0
}

# Declared submodule paths of one repo, read from its own .gitmodules.
submodule_paths() {
    local d="$1" line
    [[ -f "$d/.gitmodules" ]] || return 0
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        printf '%s\n' "${line#* }"
    done < <(git -C "$d" config -f "$d/.gitmodules" --get-regexp '^submodule\..*\.path$' 2>/dev/null)
}

discover() {
    add_repo "$ROOT" || return
    local i=0 d sub
    while [[ $i -lt ${#REPO_DIR[@]} ]]; do
        d="${REPO_DIR[$i]}"
        i=$((i + 1))
        [[ $RECURSE -eq 0 && $i -gt 1 ]] && continue
        while IFS= read -r sub; do
            [[ -z "$sub" ]] && continue
            if [[ -e "$d/$sub/.git" ]]; then          # -e, NOT -d: gitlinks are files
                add_repo "$d/$sub"
            else
                local rel="${d#"$ROOT"/}"; [[ "$rel" == "$d" ]] && rel="."
                UNINIT+=("${rel%/}/$sub")
            fi
        done < <(submodule_paths "$d")
    done
}

discover
if [[ ${#REPO_DIR[@]} -eq 0 ]]; then
    say "FATAL: '$ROOT' is not a git repository (no .git entry found)"
    exit 2
fi

# ══════════════════════════════════════════════════════════════════════════════
# 2. REMOTES -> (host, owner, name) upstreams. Derived, never assumed.
# ══════════════════════════════════════════════════════════════════════════════
P_HOST=""; P_OWNER=""; P_NAME=""
parse_remote_url() {
    local url="$1" rest host path
    P_HOST=""; P_OWNER=""; P_NAME=""
    case "$url" in
        *://*)
            rest="${url#*://}"
            # strip a userinfo@ only when the @ precedes the first '/'
            if [[ "${rest%%/*}" == *@* ]]; then rest="${rest#*@}"; fi
            [[ "$rest" == */* ]] || return 1
            host="${rest%%/*}"; path="${rest#*/}"
            host="${host%%:*}"                    # drop :port
            ;;
        *@*:*)
            rest="${url#*@}"
            host="${rest%%:*}"; path="${rest#*:}"
            ;;
        *:*/*)
            host="${url%%:*}"; path="${url#*:}"
            ;;
        *) return 1 ;;
    esac
    path="${path#/}"; path="${path%/}"; path="${path%.git}"
    [[ -n "$host" && "$path" == */* ]] || return 1
    P_HOST="$(printf '%s' "$host" | tr 'A-Z' 'a-z')"
    P_OWNER="${path%%/*}"
    P_NAME="${path#*/}"
    return 0
}

# UPSTREAM records: one per distinct (repo, host, owner, name).
declare -a UP_REPO=() UP_HOST=() UP_OWNER=() UP_NAME=()
declare -A UP_SEEN=()           # "<repoidx>|<host>/<owner>/<name>"
declare -A NS_REPOCOUNT=()      # "<host>/<lowerowner>" -> distinct repo count
declare -A NS_REPOSEEN=()
declare -A REPO_NOREMOTE=()

collect_upstreams() {
    local i d name url key ns lowowner
    for i in "${!REPO_DIR[@]}"; do
        d="${REPO_DIR[$i]}"
        local found=0
        # `git remote -v` lists every fetch AND every push URL, including the
        # extra pushurls of a multi-upstream remote (§2.1). Both matter: a push
        # URL is precisely "an upstream we push".
        while read -r name url _; do
            [[ -z "${url:-}" ]] && continue
            found=1
            parse_remote_url "$url" || continue
            key="$i|$P_HOST/$P_OWNER/$P_NAME"
            [[ -n "${UP_SEEN[$key]:-}" ]] && continue
            UP_SEEN["$key"]=1
            UP_REPO+=("$i"); UP_HOST+=("$P_HOST"); UP_OWNER+=("$P_OWNER"); UP_NAME+=("$P_NAME")
            lowowner="$(printf '%s' "$P_OWNER" | tr 'A-Z' 'a-z')"
            ns="$P_HOST/$lowowner"
            if [[ -z "${NS_REPOSEEN[$ns|$i]:-}" ]]; then
                NS_REPOSEEN["$ns|$i"]=1
                NS_REPOCOUNT["$ns"]=$(( ${NS_REPOCOUNT[$ns]:-0} + 1 ))
            fi
        done < <(git -C "$d" remote -v 2>/dev/null)
        [[ $found -eq 0 ]] && REPO_NOREMOTE["$i"]=1
    done
}
collect_upstreams

# ══════════════════════════════════════════════════════════════════════════════
# 3. PROVIDER ADAPTERS — registered by host, probed for availability.
# ══════════════════════════════════════════════════════════════════════════════
adapter_for_host() {
    case "$1" in
        github.com)            printf 'gh' ;;
        gitlab.com|gitlab.*)   printf 'glab' ;;
        gitflic.ru|gitflic.*)  printf 'gitflic' ;;
        gitverse.ru|gitverse.*) printf 'gitverse' ;;
        *)                     printf '' ;;
    esac
}

# Which adapters this tree actually needs. The two HTTP adapters below cost a
# network round trip to probe, so they are probed only when some upstream in
# this tree is actually on that host — never speculatively.
declare -A HOST_ADAPTER_NEEDED=()
for u in ${UP_HOST[@]+"${!UP_HOST[@]}"}; do
    a="$(adapter_for_host "${UP_HOST[$u]}")"
    [[ -n "$a" ]] && HOST_ADAPTER_NEEDED["$a"]=1
done

# ── Read-only HTTP transport, shared by the CLI-less adapters ────────────────
# Sets HTTP_CODE / HTTP_BODY, or returns non-zero with HTTP_TRANSPORT naming the
# transport failure. Returning non-zero is NOT a verdict about the repository —
# it is the absence of an answer, and every caller must route it to `unv`.
#
# The credential never touches argv. It is written into a curl config read from
# STDIN, so `ps`, `/proc/<pid>/cmdline` and any shell history see the URL and
# nothing else. Redirects are deliberately NOT followed: an API that answers a
# redirect has not answered the question, and following one risks carrying an
# Authorization header somewhere it was not issued for.
HTTP_CODE=0; HTTP_BODY=""; HTTP_TRANSPORT=""
http_get() {   # $1 url, $2 accept media type, $3 Authorization value (may be empty)
    HTTP_CODE=0; HTTP_BODY=""; HTTP_TRANSPORT=""
    command -v curl >/dev/null 2>&1 || { HTTP_TRANSPORT="curl is not installed"; return 1; }
    local cfg out rc
    printf -v cfg 'url = "%s"\nheader = "Accept: %s"\n' "$1" "$2"
    if [[ -n "${3:-}" ]]; then
        local esc="${3//\\/\\\\}"; esc="${esc//\"/\\\"}"
        printf -v cfg '%sheader = "Authorization: %s"\n' "$cfg" "$esc"
    fi
    printf -v cfg '%ssilent\nmax-time = 20\nwrite-out = "\\n%%{http_code}"\n' "$cfg"
    out="$(printf '%s' "$cfg" | curl -K - 2>/dev/null)"; rc=$?
    if [[ $rc -ne 0 ]]; then
        HTTP_TRANSPORT="curl exit $rc — network, DNS or TLS failure reaching the host"
        return 1
    fi
    HTTP_CODE="${out##*$'\n'}"
    HTTP_BODY="${out%$'\n'*}"
    [[ "$HTTP_CODE" =~ ^[0-9]{3}$ ]] || {
        HTTP_TRANSPORT="the host returned no HTTP status line"; HTTP_CODE=0; return 1; }
    return 0
}

GH_STATE="absent"; GH_REASON="the 'gh' CLI is not installed"; GH_LOGIN=""
if command -v gh >/dev/null 2>&1; then
    GH_ERR="$(gh auth status 2>&1)"
    if [[ $? -eq 0 ]]; then
        GH_LOGIN="$(gh api user --jq .login 2>/dev/null)"
        if [[ -n "$GH_LOGIN" ]]; then
            GH_STATE="ready"; GH_REASON="authenticated as $GH_LOGIN"
        else
            GH_STATE="broken"; GH_REASON="gh is authenticated but 'gh api user' returned nothing (network or token scope)"
        fi
    else
        GH_STATE="unauth"
        GH_REASON="gh is installed but not usable: $(printf '%s' "$GH_ERR" | head -1)"
    fi
fi

GLAB_STATE="absent"; GLAB_REASON="the 'glab' CLI is not installed"; GLAB_LOGIN=""
if command -v glab >/dev/null 2>&1; then
    if ! command -v jq >/dev/null 2>&1; then
        GLAB_STATE="broken"; GLAB_REASON="glab is installed but 'jq' is not, and glab returns raw JSON"
    else
        GLAB_ERR="$(glab auth status 2>&1)"
        if [[ $? -eq 0 ]]; then
            GLAB_LOGIN="$(glab api user 2>/dev/null | jq -r '.username // empty' 2>/dev/null)"
            if [[ -n "$GLAB_LOGIN" ]]; then
                GLAB_STATE="ready"; GLAB_REASON="authenticated as $GLAB_LOGIN"
            else
                GLAB_STATE="broken"; GLAB_REASON="glab is authenticated but 'glab api user' returned nothing"
            fi
        else
            GLAB_STATE="unauth"
            GLAB_REASON="glab is installed but not usable: $(printf '%s' "$GLAB_ERR" | head -1)"
        fi
    fi
fi

# ── HTTP adapter: gitflic.ru ─────────────────────────────────────────────────
# Base + auth scheme are the vendor's documented ones ("Authorization: token
# <access token>"). The identity probe is `GET /project/my` — a documented,
# read-only listing of the authenticated account's own projects, chosen because
# it answers the only question an availability probe should ask: does this
# credential authenticate?
GFL_API="${GITFLIC_API_BASE:-https://api.gitflic.ru}"
GFL_ACCEPT="application/json"
GFL_TOKEN="${GITFLIC_TOKEN:-${GITFLIC_API_TOKEN:-}}"
GFL_STATE="absent"; GFL_REASON="no upstream in this tree is on this host, so the adapter was not probed"
if [[ -n "${HOST_ADAPTER_NEEDED[gitflic]:-}" ]]; then
    if ! command -v curl >/dev/null 2>&1; then
        GFL_STATE="absent"; GFL_REASON="this host has no CLI adapter and its API is reached over HTTP, but 'curl' is not installed"
    elif ! command -v jq >/dev/null 2>&1; then
        GFL_STATE="broken"; GFL_REASON="'jq' is not installed and this API returns raw JSON"
    elif [[ -z "$GFL_TOKEN" ]]; then
        # Ask the host anyway. "Reachable but demands a credential" and "host is
        # down" are different unknowns and must not be reported as one.
        if http_get "$GFL_API/project/my" "$GFL_ACCEPT" ""; then
            GFL_STATE="unauth"
            GFL_REASON="host reachable ($GFL_API answered HTTP $HTTP_CODE) but its API requires a credential for every route; none is configured — set GITFLIC_TOKEN to a read-only personal access token"
        else
            GFL_STATE="unreachable"
            GFL_REASON="$GFL_API could not be reached: $HTTP_TRANSPORT"
        fi
    elif http_get "$GFL_API/project/my" "$GFL_ACCEPT" "token $GFL_TOKEN"; then
        case "$HTTP_CODE" in
            200) GFL_STATE="ready";  GFL_REASON="authenticated (identity route answered HTTP 200)" ;;
            401|403) GFL_STATE="broken"; GFL_REASON="the configured credential was rejected (HTTP $HTTP_CODE)" ;;
            *)   GFL_STATE="broken"; GFL_REASON="the identity route answered HTTP $HTTP_CODE, which is neither an authentication nor a usable answer" ;;
        esac
    else
        GFL_STATE="unreachable"; GFL_REASON="$GFL_API could not be reached: $HTTP_TRANSPORT"
    fi
fi

# ── HTTP adapter: gitverse.ru ────────────────────────────────────────────────
# The vendor media type is required: without it the host answers 400 for every
# route. With it, an existing route answers 401 unauthenticated and a
# non-existent route still answers 400 — which is how this adapter's route set
# was established against the live host rather than guessed.
GVS_API="${GITVERSE_API_BASE:-https://api.gitverse.ru}"
GVS_ACCEPT="application/vnd.gitverse.object+json;version=1"
GVS_TOKEN="${GITVERSE_TOKEN:-${GITVERSE_API_TOKEN:-}}"
GVS_STATE="absent"; GVS_REASON="no upstream in this tree is on this host, so the adapter was not probed"
if [[ -n "${HOST_ADAPTER_NEEDED[gitverse]:-}" ]]; then
    if ! command -v curl >/dev/null 2>&1; then
        GVS_STATE="absent"; GVS_REASON="this host has no CLI adapter and its API is reached over HTTP, but 'curl' is not installed"
    elif ! command -v jq >/dev/null 2>&1; then
        GVS_STATE="broken"; GVS_REASON="'jq' is not installed and this API returns raw JSON"
    elif [[ -z "$GVS_TOKEN" ]]; then
        if http_get "$GVS_API/user" "$GVS_ACCEPT" ""; then
            GVS_STATE="unauth"
            GVS_REASON="host reachable ($GVS_API answered HTTP $HTTP_CODE) but its API requires a credential for every route; none is configured — set GITVERSE_TOKEN to a read-only personal access token"
        else
            GVS_STATE="unreachable"
            GVS_REASON="$GVS_API could not be reached: $HTTP_TRANSPORT"
        fi
    elif http_get "$GVS_API/user" "$GVS_ACCEPT" "Bearer $GVS_TOKEN"; then
        case "$HTTP_CODE" in
            200) GVS_STATE="ready";  GVS_REASON="authenticated (identity route answered HTTP 200)" ;;
            401|403) GVS_STATE="broken"; GVS_REASON="the configured credential was rejected (HTTP $HTTP_CODE)" ;;
            *)   GVS_STATE="broken"; GVS_REASON="the identity route answered HTTP $HTTP_CODE, which is neither an authentication nor a usable answer" ;;
        esac
    else
        GVS_STATE="unreachable"; GVS_REASON="$GVS_API could not be reached: $HTTP_TRANSPORT"
    fi
fi

adapter_state()  { case "$1" in
        gh)       printf '%s' "$GH_STATE" ;;
        glab)     printf '%s' "$GLAB_STATE" ;;
        gitflic)  printf '%s' "$GFL_STATE" ;;
        gitverse) printf '%s' "$GVS_STATE" ;;
        *)        printf 'none' ;;
    esac; }
adapter_reason() { case "$1" in
        gh)       printf '%s' "$GH_REASON" ;;
        glab)     printf '%s' "$GLAB_REASON" ;;
        gitflic)  printf '%s' "$GFL_REASON" ;;
        gitverse) printf '%s' "$GVS_REASON" ;;
        *)        printf 'no read-only API adapter is registered for this host' ;;
    esac; }

# ══════════════════════════════════════════════════════════════════════════════
# 4. OWNERSHIP — derived, in this order, with the evidence recorded per repo.
#
#      tree-root     the umbrella we are running inside is ours by definition,
#                    so every namespace on its remotes is an owned namespace
#      tree-shared   a namespace used by two or more DISTINCT repositories in
#                    this tree is a namespace this tree publishes to; a vendored
#                    upstream appears exactly once
#      identity      the namespace owner is the authenticated provider account
#                    or one of the organisations that account belongs to
#      push-perm     the provider itself reports we may push (the literal
#                    §11.4.156(C) test), used to resolve anything still open
#
# Nothing here reads a repository name. Ownership that no signal establishes is
# UNKNOWN — never guessed, never defaulted to "ours", never defaulted to inert.
# ══════════════════════════════════════════════════════════════════════════════
declare -A OWNED_NS=()          # namespace -> evidence tag
ns_key() { printf '%s/%s' "$1" "$(printf '%s' "$2" | tr 'A-Z' 'a-z')"; }

for u in "${!UP_REPO[@]}"; do
    [[ "${UP_REPO[$u]}" == "0" ]] || continue
    k="$(ns_key "${UP_HOST[$u]}" "${UP_OWNER[$u]}")"
    OWNED_NS["$k"]="tree-root"
done
for k in "${!NS_REPOCOUNT[@]}"; do
    if [[ ${NS_REPOCOUNT[$k]} -ge 2 && -z "${OWNED_NS[$k]:-}" ]]; then
        OWNED_NS["$k"]="tree-shared(${NS_REPOCOUNT[$k]} repos)"
    fi
done

add_identity_ns() {   # $1 host, $2 owner, $3 tag
    local k; k="$(ns_key "$1" "$2")"
    [[ -n "${OWNED_NS[$k]:-}" ]] || OWNED_NS["$k"]="$3"
}
IDENTITY_NOTE=""
if [[ "$GH_STATE" == "ready" ]]; then
    add_identity_ns "github.com" "$GH_LOGIN" "identity(account)"
    while IFS= read -r org; do
        [[ -n "$org" ]] && add_identity_ns "github.com" "$org" "identity(org)"
    done < <(gh api user/orgs --paginate --jq '.[].login' 2>/dev/null)
else
    IDENTITY_NOTE="github.com identity not consulted: $GH_REASON"
fi
if [[ "$GLAB_STATE" == "ready" ]]; then
    add_identity_ns "gitlab.com" "$GLAB_LOGIN" "identity(account)"
    while IFS= read -r grp; do
        [[ -n "$grp" ]] && add_identity_ns "gitlab.com" "$grp" "identity(group)"
    done < <(glab api "groups?min_access_level=30&per_page=100" 2>/dev/null | jq -r '.[].full_path // empty' 2>/dev/null)
fi

# Per-repo ownership verdict + evidence.
declare -a REPO_OWNED=() REPO_EVID=()
for i in "${!REPO_DIR[@]}"; do REPO_OWNED[$i]="UNKNOWN"; REPO_EVID[$i]=""; done

for u in "${!UP_REPO[@]}"; do
    i="${UP_REPO[$u]}"
    k="$(ns_key "${UP_HOST[$u]}" "${UP_OWNER[$u]}")"
    tag="${OWNED_NS[$k]:-}"
    if [[ -n "$tag" ]]; then
        REPO_OWNED[$i]="OURS"
        case "${REPO_EVID[$i]}" in
            *"$k=$tag"*) : ;;
            *) REPO_EVID[$i]="${REPO_EVID[$i]:+${REPO_EVID[$i]}; }$k=$tag" ;;
        esac
    fi
done

# Anything still open: ask the provider whether we may push. Read-only GET.
for i in "${!REPO_DIR[@]}"; do
    [[ "${REPO_OWNED[$i]}" == "UNKNOWN" ]] || continue
    if [[ -n "${REPO_NOREMOTE[$i]:-}" ]]; then
        REPO_EVID[$i]="no remotes configured — nothing to push, no upstream to classify"
        continue
    fi
    for u in "${!UP_REPO[@]}"; do
        [[ "${UP_REPO[$u]}" == "$i" ]] || continue
        [[ "${REPO_OWNED[$i]}" == "UNKNOWN" ]] || break
        host="${UP_HOST[$u]}"; owner="${UP_OWNER[$u]}"; name="${UP_NAME[$u]}"
        case "$(adapter_for_host "$host")" in
            gh)
                if [[ "$GH_STATE" == "ready" ]]; then
                    perm="$(gh api "repos/$owner/$name" --jq '.permissions.push' 2>/dev/null)"
                    if [[ "$perm" == "true" ]]; then
                        REPO_OWNED[$i]="OURS"
                        REPO_EVID[$i]="$host/$owner=push-perm(provider reports push=true)"
                        OWNED_NS["$(ns_key "$host" "$owner")"]="push-perm"
                    elif [[ "$perm" == "false" ]]; then
                        REPO_OWNED[$i]="THIRD-PARTY"
                        REPO_EVID[$i]="$host/$owner/$name=push-perm(provider reports push=false) — §11.4.156(C) out of scope"
                    else
                        REPO_EVID[$i]="$host/$owner/$name=provider did not answer the push-permission query"
                    fi
                else
                    REPO_EVID[$i]="${REPO_EVID[$i]:+${REPO_EVID[$i]}; }$host=cannot ask ($GH_REASON)"
                fi ;;
            glab)
                if [[ "$GLAB_STATE" == "ready" ]]; then
                    enc="$(printf '%s/%s' "$owner" "$name" | sed 's|/|%2F|g')"
                    lvl="$(glab api "projects/$enc" 2>/dev/null | jq -r '.permissions.project_access.access_level // .permissions.group_access.access_level // empty' 2>/dev/null)"
                    if [[ -n "$lvl" && "$lvl" != "null" && "$lvl" -ge 30 ]] 2>/dev/null; then
                        REPO_OWNED[$i]="OURS"
                        REPO_EVID[$i]="$host/$owner=push-perm(access_level=$lvl)"
                        OWNED_NS["$(ns_key "$host" "$owner")"]="push-perm"
                    fi
                fi ;;
            gitflic|gitverse)
                # These adapters exist, but neither vendor documents a
                # per-repository push-permission field, so ownership is not
                # derivable from them. Stated rather than left to look like the
                # adapter is missing — a different and much weaker fact.
                REPO_EVID[$i]="${REPO_EVID[$i]:+${REPO_EVID[$i]}; }$host=adapter registered, but this API exposes no push-permission field — ownership not derivable here"
                ;;
            *)
                REPO_EVID[$i]="${REPO_EVID[$i]:+${REPO_EVID[$i]}; }$host=no adapter registered, ownership unverifiable"
                ;;
        esac
    done
    [[ -z "${REPO_EVID[$i]}" ]] && REPO_EVID[$i]="no ownership signal matched"
done

if [[ $LIST_ONLY -eq 1 ]]; then
    say "${C_BLD}Discovered repositories (root: $ROOT)${C_OFF}"
    for i in "${!REPO_DIR[@]}"; do
        say "  ${REPO_REL[$i]}  [${REPO_OWNED[$i]}]  ${C_DIM}${REPO_EVID[$i]}${C_OFF}"
    done
    say ""
    say "${C_BLD}Owned namespaces derived from this tree${C_OFF}"
    for k in "${!OWNED_NS[@]}"; do say "  $k  <- ${OWNED_NS[$k]}"; done
    if [[ ${#UNINIT[@]} -gt 0 ]]; then
        say ""
        say "${C_BLD}Declared but not initialised (not inspected)${C_OFF}"
        for p in "${UNINIT[@]}"; do say "  $p"; done
    fi
    exit 0
fi

# ══════════════════════════════════════════════════════════════════════════════
# 5. FILE-LEVEL CI — what the tree can explain on its own.
#    Only ROOT-level configs execute; a provider never runs a config nested
#    below the repository root (§11.4.156(C)).
# ══════════════════════════════════════════════════════════════════════════════
ACTIVE_CI_RE='^(\.github/workflows/[^/]+\.ya?ml|\.gitlab-ci\.yml|\.circleci/config\.yml|azure-pipelines\.yml|\.drone\.yml|Jenkinsfile|\.woodpecker\.yml|bitbucket-pipelines\.yml|\.travis\.yml)$'
INERT_CI_RE='^(\.github/workflows/.+|\.gitlab-ci\.yml\..+|azure-pipelines\.yml\..+|\.drone\.yml\..+)$'

declare -a FILE_ACTIVE_N=() FILE_INERT_N=() FILE_ACTIVE_LIST=()
for i in "${!REPO_DIR[@]}"; do
    d="${REPO_DIR[$i]}"
    active=""; inert=""
    while IFS= read -r f; do
        [[ -z "$f" ]] && continue
        if [[ "$f" =~ $ACTIVE_CI_RE ]]; then
            active="${active}${f}"$'\n'
        elif [[ "$f" =~ $INERT_CI_RE ]]; then
            inert="${inert}${f}"$'\n'
        fi
    done < <(git -C "$d" ls-files 2>/dev/null)
    # Count ENTRIES, not `grep -c` lines: the list is kept so the number can be
    # checked against the things it counts.
    an=0; [[ -n "$active" ]] && an=$(printf '%s' "$active" | grep -c '^' )
    in_=0; [[ -n "$inert" ]] && in_=$(printf '%s' "$inert" | grep -c '^' )
    FILE_ACTIVE_N[$i]="$an"; FILE_INERT_N[$i]="$in_"
    FILE_ACTIVE_LIST[$i]="$(printf '%s' "$active" | tr '\n' ' ')"
done

# ══════════════════════════════════════════════════════════════════════════════
# 6. PROVIDER PROBES — read-only. One row per (repo, upstream).
# ══════════════════════════════════════════════════════════════════════════════
declare -a R_REPO=() R_HOST=() R_TARGET=() R_OURS=() R_FILECI=() R_TRIG=() R_VERDICT=() R_DETAIL=() R_IDX=()
declare -a REMEDY=()
declare -a UNVERIFIED_LOG=()

add_remedy() { local m="$1" x; for x in ${REMEDY[@]+"${REMEDY[@]}"}; do [[ "$x" == "$m" ]] && return 0; done; REMEDY+=("$m"); }

# A CLI's error output is a JSON body followed by a one-line summary. Report the
# summary, not the body: an unreadable wall of JSON in a "could not verify"
# section is how a real reason gets skipped over.
api_err() {
    local raw="$1" line
    line="$(printf '%s\n' "$raw" | grep -m1 -E '^(gh|glab): ')"
    [[ -z "$line" ]] && line="$(printf '%s\n' "$raw" | head -1)"
    line="${line//$'\n'/ }"
    if [[ ${#line} -gt 160 ]]; then printf '%s…' "${line:0:159}"; else printf '%s' "$line"; fi
}

probe_github() {    # $1 owner $2 name $3 repo index -> sets PB_TRIG PB_DETAIL
    local owner="$1" name="$2" i="$3"
    local detail="" trig="NONE" unv="" hist=0
    local out rc

    out="$(gh api "repos/$owner/$name" --jq '[.default_branch,(.archived|tostring),(.permissions.push|tostring),.owner.type,.full_name]|@tsv' 2>&1)"; rc=$?
    local defbr="" archived="" pushperm="" ownertype="" fullname=""
    if [[ $rc -eq 0 ]]; then
        IFS=$'\t' read -r defbr archived pushperm ownertype fullname <<<"$out"
        detail="${detail}default-branch=$defbr archived=$archived push=$pushperm owner-type=$ownertype; "
        # A renamed repository still answers on its old path via a redirect. Say
        # so, rather than reporting the same upstream twice as if it were two.
        if [[ -n "$fullname" && "$(printf '%s' "$fullname" | tr 'A-Z' 'a-z')" != "$(printf '%s/%s' "$owner" "$name" | tr 'A-Z' 'a-z')" ]]; then
            detail="${detail}NOTE: the provider redirects this path to '$fullname' (renamed upstream) — the findings below are that repository's; "
        fi
    else
        unv="${unv}repo metadata unreadable ($(api_err "$out")); "
    fi

    # -- STANDING SETTING: Pages. The setting that runs CI with zero workflow
    #    files. `legacy` = "deploy from a branch": the provider itself builds on
    #    every push. `workflow` = the repository's own workflow file builds, so
    #    the trigger is file-level and a file gate can see it.
    local pages_bt=""
    out="$(gh api "repos/$owner/$name/pages" --jq '[.build_type,(.source.branch//"-"),(.source.path//"-"),.status]|@tsv' 2>&1)"; rc=$?
    if [[ $rc -eq 0 ]]; then
        local sbr spath pstat
        IFS=$'\t' read -r pages_bt sbr spath pstat <<<"$out"
        detail="${detail}pages=enabled build_type=$pages_bt source=$sbr:$spath status=$pstat; "
        if [[ "$pages_bt" == "legacy" ]]; then
            trig="CONFIRMED"
            detail="${detail}STANDING TRIGGER: Pages build_type=legacy — the provider queues a 'pages build and deployment' Actions run on every push to '$sbr'. The tree contains no file that declares it and no file that can stop it; "
            add_remedy "PROVIDER|$owner/$name|GitHub Pages is in legacy (deploy-from-a-branch) mode, so the provider builds on every push with no workflow file involved. Operator-only, Settings > Pages: (a) leave it and record a documented deviation, (b) change the source, or (c) disable Pages. (b) and (c) change or stop publishing — decide what serves the live site before touching either."
        fi
    elif grep -q '404' <<<"$out"; then
        detail="${detail}pages=not enabled; "
    else
        unv="${unv}Pages configuration unreadable ($(api_err "$out")); "
    fi

    # -- STANDING SETTING: repository rulesets, including those inherited from
    #    the owning organisation. Required workflows were migrated to rulesets
    #    in January 2024; the old orgs/*/actions/required_workflows endpoint is
    #    gone, so asking it would produce a permanent, meaningless UNVERIFIED.
    out="$(gh api "repos/$owner/$name/rulesets?includes_parents=true" --jq '.[]|select(.enforcement=="active")|[(.id|tostring),.name,(.source//"?")]|@tsv' 2>&1)"; rc=$?
    if [[ $rc -eq 0 ]]; then
        local nrs=0 wfrules=""
        while IFS=$'\t' read -r rsid rsname rssrc; do
            [[ -z "${rsid:-}" ]] && continue
            nrs=$((nrs + 1))
            local rout rrc
            rout="$(gh api "repos/$owner/$name/rulesets/$rsid" --jq '[.rules[]?|select(.type=="workflows")]|length' 2>&1)"; rrc=$?
            if [[ $rrc -eq 0 && "$rout" =~ ^[0-9]+$ && "$rout" -gt 0 ]]; then
                wfrules="${wfrules}${wfrules:+, }'$rsname' (from $rssrc)"
            elif [[ $rrc -ne 0 ]]; then
                unv="${unv}ruleset '$rsname' rules unreadable ($(api_err "$rout")); "
            fi
        done <<<"$out"
        detail="${detail}active-rulesets=$nrs; "
        if [[ -n "$wfrules" ]]; then
            trig="CONFIRMED"
            detail="${detail}STANDING TRIGGER: ruleset(s) $wfrules impose required workflows on this repository — imposed above the repository, unremovable by any file in it; "
            add_remedy "PROVIDER|$owner/$name|A repository ruleset (possibly inherited from the owning organisation) imposes required workflows: $wfrules. No file-level change removes it. Operator-only: repository or organisation Settings > Rules > Rulesets."
        fi
    elif grep -qi 'Upgrade to GitHub' <<<"$out"; then
        # The provider is not refusing to answer, it is stating the feature is
        # not available for this repository — so none can be in force. Its own
        # words are quoted rather than paraphrased into a claim of our own.
        detail="${detail}rulesets=feature unavailable for this repository (provider: \"$(api_err "$out")\"); "
    else
        unv="${unv}rulesets unreadable ($(api_err "$out")); "
    fi

    # -- OBSERVED HISTORY: runs whose `path` corresponds to no file in the tree.
    #    History is evidence, not a present-tense claim. If a standing setting
    #    above explains it, the verdict is already CONFIRMED. If nothing
    #    standing explains it, that is reported as HISTORICAL — a fact about the
    #    past that does NOT get dressed up as a fact about today.
    out="$(gh api "repos/$owner/$name/actions/runs?per_page=100" --jq '.workflow_runs[]|[.created_at,.event,.path,.name]|@tsv' 2>&1)"; rc=$?
    if [[ $rc -eq 0 ]]; then
        local total=0 recent=0 dyn=0 dynrecent=0 newest="" dynnewest="" dynnames=""
        while IFS=$'\t' read -r cat ev pth nm; do
            [[ -z "${cat:-}" ]] && continue
            total=$((total + 1))
            [[ -z "$newest" ]] && newest="$cat"
            local isrecent=0
            if [[ -z "$SINCE" || "$cat" > "$SINCE" ]]; then isrecent=1; fi
            [[ $isrecent -eq 1 ]] && recent=$((recent + 1))
            case "$pth" in
                dynamic/*)
                    dyn=$((dyn + 1))
                    [[ -z "$dynnewest" ]] && dynnewest="$cat"
                    if [[ $isrecent -eq 1 ]]; then
                        dynrecent=$((dynrecent + 1))
                        case "$dynnames" in *"$nm"*) : ;; *) dynnames="${dynnames}${dynnames:+, }$nm [$pth]";; esac
                    fi ;;
            esac
        done <<<"$out"
        detail="${detail}runs(listed=$total, newest=${newest:-none}, in-window=$recent, provider-generated=$dyn, newest-provider-generated=${dynnewest:-none}); "
        if [[ $dynrecent -gt 0 ]]; then
            if [[ "$trig" == "CONFIRMED" ]]; then
                detail="${detail}corroboration: $dynrecent provider-generated run(s) since ${SINCE:-the start of the listing} — $dynnames; "
            else
                hist=$dynrecent
                detail="${detail}HISTORICAL: $dynrecent provider-generated run(s) since ${SINCE:-the start of the listing} — $dynnames — newest $dynnewest. No file declares them, and no standing setting readable now produces them (pages build_type=${pages_bt:-n/a}). They are a fact about the past, NOT a claim that a push today triggers one; "
                add_remedy "REVIEW|$owner/$name|$dynrecent provider-generated Actions run(s) occurred in the window (newest $dynnewest) but no standing provider setting readable now explains them. Operator-only: confirm which setting produced them and that it is genuinely gone, rather than assuming the change stuck."
            fi
        fi
    else
        unv="${unv}run history unreadable ($(api_err "$out")); "
    fi

    # -- Actions enabled at repository level ---------------------------------
    #    Not itself a trigger, but it is the one file-independent off-switch, so
    #    it belongs in the report when the tree explains no runs at all.
    out="$(gh api "repos/$owner/$name/actions/permissions" --jq '.enabled' 2>&1)"; rc=$?
    if [[ $rc -eq 0 ]]; then
        detail="${detail}actions-enabled=$out; "
        if [[ "$out" == "true" && "${FILE_ACTIVE_N[$i]}" == "0" ]]; then
            add_remedy "HARDEN|$owner/$name|Actions are enabled at repository level while the tree declares zero active workflow files. Disabling Actions (Settings > Actions > General > Disable actions) is the only file-independent way to stop provider-generated runs — but it also stops any Pages workflow build, so check what publishes each repository before switching it off."
        fi
    else
        unv="${unv}Actions repo-level permission unreadable ($(api_err "$out")); "
    fi

    # -- Branch protection / required checks ---------------------------------
    #    A required check whose workflow was renamed to `.disabled` can never
    #    report, and every pull request then blocks forever. That is a real cost
    #    of complying with §11.4.156(B) and it is invisible to any file gate.
    if [[ -n "$defbr" ]]; then
        out="$(gh api "repos/$owner/$name/branches/$defbr/protection" --jq '[.required_status_checks.contexts[]?]|join(",")' 2>&1)"; rc=$?
        if [[ $rc -eq 0 ]]; then
            if [[ -n "$out" ]]; then
                detail="${detail}required-checks-on-$defbr=[$out]; "
                if [[ "${FILE_ACTIVE_N[$i]}" == "0" ]]; then
                    detail="${detail}RISK: required checks exist but the tree declares zero active workflows — nothing can report them and pull requests cannot merge; "
                    add_remedy "RISK|$owner/$name|Branch '$defbr' requires status checks [$out] while the tree declares zero active workflow files. Nothing can ever report those checks, so pull requests are unmergeable. Operator-only: Settings > Branches — remove the stale required checks."
                fi
            else
                detail="${detail}branch-protection=present, no required status checks; "
            fi
        elif grep -qi 'not protected\|404' <<<"$out"; then
            detail="${detail}branch-protection=none on $defbr; "
        elif grep -qi 'Upgrade to GitHub' <<<"$out"; then
            detail="${detail}branch-protection=unavailable on this plan for a private repository (so none is in force); "
        else
            unv="${unv}branch protection unreadable ($(api_err "$out")); "
        fi
    else
        unv="${unv}default branch unknown, branch protection not checked; "
    fi

    # -- Organisation layer ---------------------------------------------------
    if [[ "$ownertype" == "Organization" ]]; then
        detail="${detail}org-layer=covered by the inherited-rulesets query above; "
    elif [[ -n "$ownertype" ]]; then
        detail="${detail}org-layer=n/a (owner is a user account, not an organisation); "
    fi

    if [[ -n "$unv" && "$trig" != "CONFIRMED" ]]; then
        trig="UNVERIFIED"
        detail="${detail}NOT VERIFIED: $unv"
    elif [[ -n "$unv" ]]; then
        detail="${detail}also not verified: $unv"
    fi
    [[ "$trig" == "NONE" && $hist -gt 0 ]] && trig="HISTORICAL"
    PB_TRIG="$trig"; PB_DETAIL="$detail"
}

probe_gitlab() {    # $1 owner $2 name $3 repo index
    local owner="$1" name="$2" i="$3"
    local detail="" trig="NONE" unv="" hist=0
    local enc out rc
    enc="$(printf '%s/%s' "$owner" "$name" | sed 's|/|%2F|g')"

    out="$(glab api "projects/$enc" 2>&1)"; rc=$?
    if [[ $rc -eq 0 ]]; then
        local jobs auto cfg defbr
        jobs="$(printf '%s' "$out" | jq -r '.jobs_enabled // "?"' 2>/dev/null)"
        auto="$(printf '%s' "$out" | jq -r '.auto_devops_enabled // "?"' 2>/dev/null)"
        cfg="$(printf '%s'  "$out" | jq -r '.ci_config_path // "(default .gitlab-ci.yml)"' 2>/dev/null)"
        defbr="$(printf '%s' "$out" | jq -r '.default_branch // "?"' 2>/dev/null)"
        detail="${detail}jobs_enabled=$jobs auto_devops=$auto ci_config_path=$cfg default-branch=$defbr; "
        if [[ "$auto" == "true" ]]; then
            trig="CONFIRMED"
            detail="${detail}TRIGGER: Auto DevOps is enabled — GitLab runs a provider-supplied pipeline on push even with no .gitlab-ci.yml in the tree; "
            add_remedy "PROVIDER|$owner/$name|GitLab Auto DevOps is enabled. It runs a provider-supplied pipeline with no file in the tree. Operator-only: project Settings > CI/CD > Auto DevOps."
        fi
    else
        unv="${unv}project metadata unreadable ($(api_err "$out")); "
    fi

    out="$(glab api "projects/$enc/pipeline_schedules" 2>&1)"; rc=$?
    if [[ $rc -eq 0 ]]; then
        local nact; nact="$(printf '%s' "$out" | jq -r '[.[]?|select(.active==true)]|length' 2>/dev/null)"
        detail="${detail}active-pipeline-schedules=${nact:-?}; "
        if [[ "${nact:-0}" =~ ^[0-9]+$ && "${nact:-0}" -gt 0 ]]; then
            trig="CONFIRMED"
            detail="${detail}TRIGGER: ${nact} active provider-side pipeline schedule(s); "
            add_remedy "PROVIDER|$owner/$name|GitLab holds ${nact} active pipeline schedule(s). These are server-side and survive deleting .gitlab-ci.yml. Operator-only: project Settings > CI/CD > Schedules."
        fi
    else
        unv="${unv}pipeline schedules unreadable ($(api_err "$out")); "
    fi

    out="$(glab api "projects/$enc/pipelines?per_page=50" 2>&1)"; rc=$?
    if [[ $rc -eq 0 ]]; then
        local tot rec
        tot="$(printf '%s' "$out" | jq -r 'length' 2>/dev/null)"
        if [[ -n "$SINCE" ]]; then
            rec="$(printf '%s' "$out" | jq -r --arg s "$SINCE" '[.[]?|select(.created_at>$s)]|length' 2>/dev/null)"
        else
            rec="$tot"
        fi
        detail="${detail}pipelines(listed=${tot:-?}, in-window=${rec:-?}); "
        # Pipelines that ran while the tree declares no active CI config are not
        # explained by any file. Past tense, reported as such.
        if [[ "${rec:-0}" =~ ^[0-9]+$ && "${rec:-0}" -gt 0 && "${FILE_ACTIVE_N[$i]}" == "0" && "$trig" != "CONFIRMED" ]]; then
            hist="$rec"
            detail="${detail}HISTORICAL: ${rec} pipeline(s) ran in the window while the tree declares zero active CI config — no standing setting readable now explains them; "
            add_remedy "REVIEW|$owner/$name|${rec} GitLab pipeline(s) ran in the window while the tree declares zero active CI config. Operator-only: confirm which project setting produced them and that it is genuinely gone."
        fi
    else
        unv="${unv}pipeline history unreadable ($(api_err "$out")); "
    fi

    if [[ -n "$unv" && "$trig" != "CONFIRMED" ]]; then
        trig="UNVERIFIED"; detail="${detail}NOT VERIFIED: $unv"
    elif [[ -n "$unv" ]]; then
        detail="${detail}also not verified: $unv"
    fi
    [[ "$trig" == "NONE" && "${hist:-0}" != "0" ]] && trig="HISTORICAL"
    PB_TRIG="$trig"; PB_DETAIL="$detail"
}

probe_gitflic() {   # $1 owner $2 name $3 repo index
    local owner="$1" name="$2" i="$3"
    local detail="" trig="NONE" unv="" hist=0
    local base="$GFL_API/project/$owner/$name" auth="token $GFL_TOKEN"

    # -- project object. `mirror` is the field worth reading here: a server-side
    #    mirror moves refs into this project without a push of ours. That is a
    #    fact about ref movement, NOT by itself a CI trigger, and it is reported
    #    as evidence rather than graded as one.
    if http_get "$base" "$GFL_ACCEPT" "$auth" && [[ "$HTTP_CODE" == "200" ]]; then
        local mir mtyp defbr
        mir="$(printf  '%s' "$HTTP_BODY" | jq -r '.mirror     // "?"' 2>/dev/null)"
        mtyp="$(printf '%s' "$HTTP_BODY" | jq -r '.mirrorType // "-"' 2>/dev/null)"
        defbr="$(printf '%s' "$HTTP_BODY" | jq -r '.defaultBranch // "?"' 2>/dev/null)"
        detail="${detail}project=readable mirror=${mir:-?} mirrorType=${mtyp:--} default-branch=${defbr:-?}; "
        if [[ "$mir" == "true" ]]; then
            detail="${detail}NOTE: server-side MIRROR — the provider moves refs here without a push of ours; reported, not graded as a trigger; "
        fi
    elif [[ "${HTTP_CODE:-0}" =~ ^[0-9]{3}$ ]]; then
        unv="${unv}project object unreadable (HTTP $HTTP_CODE); "
    else
        unv="${unv}project object unreadable ($HTTP_TRANSPORT); "
    fi

    # -- pipeline history. Past tense, and reported as such.
    if http_get "$base/cicd/pipeline" "$GFL_ACCEPT" "$auth" && [[ "$HTTP_CODE" == "200" ]]; then
        local tot rec newest
        # The vendor paginates with a Spring `_embedded` envelope; a bare array
        # is also accepted. Deliberately `// empty` and NOT `// 0`: a body with
        # no array at all is an UNRECOGNISED SHAPE, and defaulting it to zero
        # would turn "I could not read this" into "there were none".
        tot="$(printf '%s' "$HTTP_BODY"    | jq -r '[..|arrays|length]|max // empty' 2>/dev/null | head -1)"
        newest="$(printf '%s' "$HTTP_BODY" | jq -r '[..|objects|select(has("createdAt"))|.createdAt]|sort|last // ""' 2>/dev/null)"
        if [[ -n "$SINCE" ]]; then
            rec="$(printf '%s' "$HTTP_BODY" | jq -r --arg s "$SINCE" '[..|objects|select(has("createdAt"))|select(.createdAt>$s)]|length' 2>/dev/null)"
        else
            rec="$tot"
        fi
        if [[ "${tot:-}" =~ ^[0-9]+$ ]]; then
            detail="${detail}pipelines(listed=$tot, newest=${newest:-none}, in-window=${rec:-?}); "
            if [[ "${rec:-0}" =~ ^[0-9]+$ && "${rec:-0}" -gt 0 && "${FILE_ACTIVE_N[$i]}" == "0" ]]; then
                hist="$rec"
                detail="${detail}HISTORICAL: ${rec} pipeline(s) ran in the window while the tree declares zero active CI config; "
                add_remedy "REVIEW|$owner/$name|${rec} GitFlic pipeline(s) ran in the window while the tree declares zero active CI config. Operator-only: project CI/CD > Schedules, and the project's CI/CD settings, in the GitFlic web UI."
            fi
        else
            unv="${unv}pipeline history returned an unrecognised JSON shape; "
        fi
    elif [[ "${HTTP_CODE:-0}" =~ ^[0-9]{3}$ ]]; then
        unv="${unv}pipeline history unreadable (HTTP $HTTP_CODE); "
    else
        unv="${unv}pipeline history unreadable ($HTTP_TRANSPORT); "
    fi

    # -- THE STANDING-TRIGGER QUESTION, AND WHY IT CANNOT BE PUT HERE.
    #    This is not a missing feature of this adapter; it is a missing endpoint
    #    at the vendor. The scheduler is a server-side project setting edited in
    #    the web UI, and the published REST API documents no route that reads
    #    it — so no read-only probe can establish that none is armed. Reporting
    #    NONE would be inventing the answer, so this row can never be clean, and
    #    the reason travels with it on every run.
    unv="${unv}the STANDING-trigger question cannot be answered read-only on this host: its pipeline scheduler is a server-side project setting configured in the web UI and its REST API documents no route that reads it; "
    add_remedy "MANUAL|$owner/$name|GitFlic's pipeline scheduler is server-side and has no documented read-only API route, so no probe can confirm that no schedule is armed. Operator-only, in the GitFlic web UI: project CI/CD > Schedules (Расписания), plus the project's CI/CD settings and webhooks."

    if [[ -n "$unv" && "$trig" != "CONFIRMED" ]]; then
        trig="UNVERIFIED"; detail="${detail}NOT VERIFIED: $unv"
    elif [[ -n "$unv" ]]; then
        detail="${detail}also not verified: $unv"
    fi
    [[ "$trig" == "NONE" && "${hist:-0}" != "0" ]] && trig="HISTORICAL"
    PB_TRIG="$trig"; PB_DETAIL="$detail"
}

probe_gitverse() {  # $1 owner $2 name $3 repo index
    local owner="$1" name="$2" i="$3"
    local detail="" trig="NONE" unv="" hist=0
    local base="$GVS_API/repos/$owner/$name" auth="Bearer $GVS_TOKEN"

    _gvs() {  # $1 route suffix, $2 label -> body in HTTP_BODY, or appends to unv
        if http_get "$base$1" "$GVS_ACCEPT" "$auth" && [[ "$HTTP_CODE" == "200" ]]; then
            return 0
        elif [[ "${HTTP_CODE:-0}" =~ ^[0-9]{3}$ ]]; then
            unv="${unv}$2 unreadable (HTTP $HTTP_CODE); "; return 1
        else
            unv="${unv}$2 unreadable ($HTTP_TRANSPORT); "; return 1
        fi
    }

    if _gvs "" "repository object"; then
        local defbr arch
        defbr="$(printf '%s' "$HTTP_BODY" | jq -r '.default_branch // "?"' 2>/dev/null)"
        arch="$(printf  '%s' "$HTTP_BODY" | jq -r '.archived       // "?"' 2>/dev/null)"
        detail="${detail}repo=readable default-branch=${defbr:-?} archived=${arch:-?}; "
    fi

    # Workflows the PROVIDER believes it holds. A workflow the provider lists
    # that no file in the tree declares is the shape this whole script exists
    # to catch, so the two counts are printed side by side and the reader is
    # told which is which rather than being handed a single reconciled number.
    if _gvs "/actions/workflows" "Actions workflow list"; then
        local nwf
        nwf="$(printf '%s' "$HTTP_BODY" | jq -r 'if type=="array" then length elif type=="object" and has("total_count") then .total_count elif type=="object" and has("workflows") then (.workflows|length) else empty end' 2>/dev/null | head -1)"
        if [[ "${nwf:-}" =~ ^[0-9]+$ ]]; then
            detail="${detail}provider-listed-workflows=$nwf tree-active-configs=${FILE_ACTIVE_N[$i]}; "
            if [[ "$nwf" -gt 0 && "${FILE_ACTIVE_N[$i]}" == "0" ]]; then
                trig="CONFIRMED"
                detail="${detail}STANDING TRIGGER: the provider lists $nwf workflow(s) while the tree declares zero active CI config — nothing in the tree declares them and no file in it can remove them; "
                add_remedy "PROVIDER|$owner/$name|GitVerse lists $nwf Actions workflow(s) for this repository while the tree declares zero active CI config. Operator-only: project Settings > Actions in the GitVerse web UI."
            fi
        else
            unv="${unv}Actions workflow list returned an unrecognised JSON shape; "
        fi
    fi

    if _gvs "/actions/runs" "Actions run history"; then
        local tot rec newest
        tot="$(printf '%s' "$HTTP_BODY"    | jq -r 'if type=="array" then length elif type=="object" and has("total_count") then .total_count elif type=="object" and has("workflow_runs") then (.workflow_runs|length) else empty end' 2>/dev/null | head -1)"
        newest="$(printf '%s' "$HTTP_BODY" | jq -r '[..|objects|select(has("created_at"))|.created_at]|sort|last // ""' 2>/dev/null)"
        if [[ -n "$SINCE" ]]; then
            rec="$(printf '%s' "$HTTP_BODY" | jq -r --arg s "$SINCE" '[..|objects|select(has("created_at"))|select(.created_at>$s)]|length' 2>/dev/null)"
        else
            rec="$tot"
        fi
        if [[ "${tot:-}" =~ ^[0-9]+$ ]]; then
            detail="${detail}runs(listed=$tot, newest=${newest:-none}, in-window=${rec:-?}); "
            if [[ "${rec:-0}" =~ ^[0-9]+$ && "${rec:-0}" -gt 0 && "${FILE_ACTIVE_N[$i]}" == "0" && "$trig" != "CONFIRMED" ]]; then
                hist="$rec"
                detail="${detail}HISTORICAL: ${rec} run(s) in the window while the tree declares zero active CI config — a fact about the past, NOT a claim that a push today triggers one; "
                add_remedy "REVIEW|$owner/$name|${rec} GitVerse Actions run(s) occurred in the window while the tree declares zero active CI config. Operator-only: confirm which setting produced them and that it is genuinely gone."
            fi
        else
            unv="${unv}Actions run history returned an unrecognised JSON shape; "
        fi
    fi

    # Server-side webhooks. Not provider CI, but they are push-triggered actions
    # the provider performs that no file in the tree declares, so they are
    # reported — and never counted as a trigger they are not.
    if _gvs "/hooks" "server-side webhook list"; then
        local nhk
        nhk="$(printf '%s' "$HTTP_BODY" | jq -r 'if type=="array" then length elif type=="object" and has("total_count") then .total_count else empty end' 2>/dev/null | head -1)"
        if [[ "${nhk:-}" =~ ^[0-9]+$ ]]; then
            detail="${detail}server-side-webhooks=$nhk; "
            if [[ "$nhk" -gt 0 ]]; then
                add_remedy "REVIEW|$owner/$name|GitVerse holds $nhk server-side webhook(s) on this repository. A webhook is not provider CI, but it is a push-triggered action declared by no file in the tree. Operator-only: project Settings > Webhooks."
            fi
        else
            unv="${unv}server-side webhook list returned an unrecognised JSON shape; "
        fi
    fi

    if [[ -n "$unv" && "$trig" != "CONFIRMED" ]]; then
        trig="UNVERIFIED"; detail="${detail}NOT VERIFIED: $unv"
    elif [[ -n "$unv" ]]; then
        detail="${detail}also not verified: $unv"
    fi
    [[ "$trig" == "NONE" && "${hist:-0}" != "0" ]] && trig="HISTORICAL"
    PB_TRIG="$trig"; PB_DETAIL="$detail"
}

# -- build the rows ------------------------------------------------------------
for i in "${!REPO_DIR[@]}"; do
    fileci="active=${FILE_ACTIVE_N[$i]} inert=${FILE_INERT_N[$i]}"
    have_row=0
    for u in "${!UP_REPO[@]}"; do
        [[ "${UP_REPO[$u]}" == "$i" ]] || continue
        have_row=1
        host="${UP_HOST[$u]}"; owner="${UP_OWNER[$u]}"; name="${UP_NAME[$u]}"
        ad="$(adapter_for_host "$host")"; st="$(adapter_state "$ad")"
        PB_TRIG="UNVERIFIED"; PB_DETAIL=""
        verdict=""
        case "${REPO_OWNED[$i]}" in
            THIRD-PARTY)
                PB_TRIG="OUT-OF-SCOPE"
                PB_DETAIL="§11.4.156(C): we do not push this upstream, so no push of ours triggers anything here. Its files are inert to us and MUST NOT be edited."
                verdict="OUT-OF-SCOPE" ;;
            UNKNOWN)
                PB_TRIG="UNVERIFIED"
                PB_DETAIL="ownership undetermined — ${REPO_EVID[$i]}. Not probed, and NOT assumed inert."
                verdict="UNDETERMINED"
                UNVERIFIED_LOG+=("${REPO_REL[$i]} @ $host/$owner/$name — ownership undetermined: ${REPO_EVID[$i]}") ;;
            OURS)
                if [[ "$st" == "ready" ]]; then
                    case "$ad" in
                        gh)       probe_github   "$owner" "$name" "$i" ;;
                        glab)     probe_gitlab   "$owner" "$name" "$i" ;;
                        gitflic)  probe_gitflic  "$owner" "$name" "$i" ;;
                        gitverse) probe_gitverse "$owner" "$name" "$i" ;;
                    esac
                else
                    PB_TRIG="UNVERIFIED"
                    PB_DETAIL="not asked: $(adapter_reason "$ad"). GitHub's answer is NOT generalised to this host."
                    UNVERIFIED_LOG+=("${REPO_REL[$i]} @ $host/$owner/$name — $(adapter_reason "$ad")")
                    if [[ -n "$ad" ]]; then
                        add_remedy "MANUAL|$host/$owner/$name|An adapter IS registered for this host but could not run: $(adapter_reason "$ad"). Until it can, verify by hand in that provider's web UI: CI/CD settings, pipeline schedules, pages/publishing settings, webhooks, and required checks on the default branch."
                    else
                        add_remedy "MANUAL|$host/$owner/$name|No read-only API adapter could answer for this host. Verify by hand in that provider's web UI: CI/CD settings, pipeline schedules, pages/publishing settings, and required checks on the default branch."
                    fi
                fi
                case "$PB_TRIG" in
                    CONFIRMED)  verdict="PROVIDER-SIDE CI CONFIRMED" ;;
                    UNVERIFIED) verdict="UNDETERMINED"
                                [[ "$st" == "ready" ]] && UNVERIFIED_LOG+=("${REPO_REL[$i]} @ $host/$owner/$name — ${PB_DETAIL##*NOT VERIFIED: }") ;;
                    HISTORICAL) verdict="no standing provider trigger; provider-generated runs DID occur in the window" ;;
                    NONE)       if [[ "${FILE_ACTIVE_N[$i]}" != "0" ]]; then
                                    verdict="no provider-side trigger; ${FILE_ACTIVE_N[$i]} FILE-level config(s) active"
                                    add_remedy "FILE|$owner/$name|Active root-level CI config(s) in the tree: ${FILE_ACTIVE_LIST[$i]}— file-level, visible to file gates, a §11.4.156(A)/(B) matter rather than a provider-side one."
                                else
                                    verdict="clean"
                                fi ;;
                    *)          verdict="$PB_TRIG" ;;
                esac ;;
        esac
        R_REPO+=("${REPO_REL[$i]}"); R_HOST+=("$host"); R_TARGET+=("$owner/$name")
        R_OURS+=("${REPO_OWNED[$i]}"); R_FILECI+=("$fileci"); R_IDX+=("$i")
        R_TRIG+=("$PB_TRIG"); R_VERDICT+=("$verdict"); R_DETAIL+=("$PB_DETAIL")
    done
    if [[ $have_row -eq 0 ]]; then
        R_REPO+=("${REPO_REL[$i]}"); R_HOST+=("(none)"); R_TARGET+=("(no remote)")
        R_OURS+=("${REPO_OWNED[$i]}"); R_FILECI+=("$fileci"); R_IDX+=("$i")
        R_TRIG+=("N/A"); R_VERDICT+=("no upstream configured")
        R_DETAIL+=("This repository has no remotes, so there is no upstream a push could reach and no provider to ask.")
    fi
done

# ══════════════════════════════════════════════════════════════════════════════
# 7. VERDICT
# ══════════════════════════════════════════════════════════════════════════════
n_confirmed=0; n_unverified=0; n_clean=0; n_scope=0; n_hist=0
for t in ${R_TRIG[@]+"${R_TRIG[@]}"}; do
    case "$t" in
        CONFIRMED)    n_confirmed=$((n_confirmed + 1)) ;;
        UNVERIFIED)   n_unverified=$((n_unverified + 1)) ;;
        HISTORICAL)   n_hist=$((n_hist + 1)) ;;
        NONE)         n_clean=$((n_clean + 1)) ;;
        OUT-OF-SCOPE) n_scope=$((n_scope + 1)) ;;
    esac
done
if   [[ $n_confirmed -gt 0 ]]; then RC=1
elif [[ $n_unverified -gt 0 ]]; then RC=2
else RC=0; fi

# ══════════════════════════════════════════════════════════════════════════════
# 8. OUTPUT
# ══════════════════════════════════════════════════════════════════════════════
pad() { local s="$1" w="$2"; if [[ ${#s} -gt $w ]]; then printf '%s' "${s:0:$((w-1))}…"; else printf '%-*s' "$w" "$s"; fi; }

say "${C_BLD}Provider-side CI verification${C_OFF}   root: $ROOT"
say "window: last ${WINDOW_DAYS} day(s)${SINCE:+ (since $SINCE)}   repos: ${#REPO_DIR[@]}   upstream rows: ${#R_REPO[@]}"
say "adapters: github.com -> gh [$GH_STATE: $GH_REASON]"
say "          gitlab.com -> glab [$GLAB_STATE: $GLAB_REASON]"
say "          gitflic.ru -> http [$GFL_STATE: $GFL_REASON]"
say "          gitverse.ru -> http [$GVS_STATE: $GVS_REASON]"
say "          any other host -> none registered (rows reported UNVERIFIED)"
say ""
# Column widths are measured from the data, not guessed: a fixed width silently
# truncates the nested-submodule paths that are exactly the rows a reader is
# least able to reconstruct from memory.
maxw() {  # $1 = minimum (header) width, rest = values
    local w="$1"; shift
    local v; for v in "$@"; do [[ ${#v} -gt $w ]] && w=${#v}; done
    [[ $w -gt 46 ]] && w=46
    printf '%s' "$w"
}
W_REPO=$(maxw 4 ${R_REPO[@]+"${R_REPO[@]}"})
W_HOST=$(maxw 8 ${R_HOST[@]+"${R_HOST[@]}"})
W_TGT=$(maxw 8 ${R_TARGET[@]+"${R_TARGET[@]}"})
W_OURS=$(maxw 4 ${R_OURS[@]+"${R_OURS[@]}"})
W_FILE=$(maxw 7 ${R_FILECI[@]+"${R_FILECI[@]}"})
W_TRIG=$(maxw 7 ${R_TRIG[@]+"${R_TRIG[@]}"})
RULEW=$(( W_REPO + W_HOST + W_TGT + W_OURS + W_FILE + W_TRIG + 40 ))

say "${C_BLD}$(pad REPO "$W_REPO") $(pad HOST "$W_HOST") $(pad UPSTREAM "$W_TGT") $(pad OURS "$W_OURS") $(pad FILE-CI "$W_FILE") $(pad TRIGGER "$W_TRIG") VERDICT${C_OFF}"
say "$(printf "%.0s─" $(seq 1 "$RULEW"))"
for (( r=0; r<${#R_REPO[@]}; r++ )); do
    col=""
    case "${R_TRIG[$r]}" in
        CONFIRMED)  col="$C_RED" ;;
        UNVERIFIED) col="$C_YEL" ;;
        HISTORICAL) col="$C_YEL" ;;
        NONE)       col="$C_GRN" ;;
        *)          col="$C_DIM" ;;
    esac
    say "$(pad "${R_REPO[$r]}" "$W_REPO") $(pad "${R_HOST[$r]}" "$W_HOST") $(pad "${R_TARGET[$r]}" "$W_TGT") $(pad "${R_OURS[$r]}" "$W_OURS") $(pad "${R_FILECI[$r]}" "$W_FILE") ${col}$(pad "${R_TRIG[$r]}" "$W_TRIG")${C_OFF} ${R_VERDICT[$r]}"
done
say "$(printf "%.0s─" $(seq 1 "$RULEW"))"
say "rows: ${n_confirmed} CONFIRMED · ${n_unverified} UNVERIFIED · ${n_hist} HISTORICAL · ${n_clean} no-trigger · ${n_scope} out-of-scope"

if [[ $QUIET -eq 0 ]]; then
    say ""
    say "${C_BLD}Evidence${C_OFF}"
    for (( r=0; r<${#R_REPO[@]}; r++ )); do
        say "  ${C_BLD}${R_REPO[$r]}${C_OFF} @ ${R_HOST[$r]}/${R_TARGET[$r]}  [${R_TRIG[$r]}]"
        say "    ownership: ${R_OURS[$r]} — ${REPO_EVID[${R_IDX[$r]}]}"
        say "    ${C_DIM}${R_DETAIL[$r]}${C_OFF}"
    done
    say ""
    say "${C_BLD}Derived ownership${C_OFF}"
    for i in "${!REPO_DIR[@]}"; do
        say "  $(pad "${REPO_REL[$i]}" 30) ${REPO_OWNED[$i]}  ${C_DIM}${REPO_EVID[$i]}${C_OFF}"
    done
fi

if [[ ${#UNINIT[@]} -gt 0 ]]; then
    say ""
    say "${C_YEL}Declared but not initialised — NOT inspected, NOT assumed clean${C_OFF}"
    for p in "${UNINIT[@]}"; do say "  $p"; done
fi

say ""
say "${C_BLD}Operator-only remediation that applies to what was found on THIS host${C_OFF}"
if [[ ${#REMEDY[@]} -eq 0 ]]; then
    say "  (none — nothing found on this host needs an operator action)"
else
    # Group by the action text so one instruction that applies to twenty
    # upstreams prints once, with the twenty subjects listed under it. A wall of
    # identical paragraphs is how the one distinct item gets missed.
    declare -A G_SUBJ=() G_KIND=()
    declare -a G_ORDER=()
    for m in "${REMEDY[@]}"; do
        kind="${m%%|*}"; rest="${m#*|}"; who="${rest%%|*}"; text="${rest#*|}"
        if [[ -z "${G_SUBJ[$text]:-}" ]]; then G_ORDER+=("$text"); G_KIND["$text"]="$kind"; G_SUBJ["$text"]="$who"
        else G_SUBJ["$text"]="${G_SUBJ[$text]}, $who"; fi
    done
    n=0
    for text in "${G_ORDER[@]}"; do
        n=$((n + 1))
        say "  $n. [${G_KIND[$text]}] $text"
        say "     applies to: ${G_SUBJ[$text]}"
    done
fi

say ""
say "${C_BLD}Could NOT verify${C_OFF} (§11.4.6 — recorded, never silently omitted)"
if [[ ${#UNVERIFIED_LOG[@]} -eq 0 ]]; then
    say "  (nothing — every in-scope upstream answered)"
else
    for m in "${UNVERIFIED_LOG[@]}"; do say "  · $m"; done
fi
[[ -n "$IDENTITY_NOTE" ]] && say "  · $IDENTITY_NOTE"
say "  · This script reads provider settings it has scope for. Settings behind"
say "    permissions this token does not hold are reported above by their error,"
say "    never by an assumed value."

say ""
case $RC in
    0) if [[ $n_hist -gt 0 ]]; then
           say "${C_GRN}VERDICT: no STANDING provider-side trigger found, and every in-scope upstream was checked${C_OFF}"
           say "${C_YEL}         — but ${n_hist} row(s) show provider-generated runs that DID happen in the window. (rc=0)${C_OFF}"
       else
           say "${C_GRN}VERDICT: no provider-side triggering found, and every in-scope upstream was checked. (rc=0)${C_OFF}"
       fi ;;
    1) say "${C_RED}VERDICT: provider-side triggering CONFIRMED on ${n_confirmed} upstream row(s). (rc=1)${C_OFF}" ;;
    2) say "${C_YEL}VERDICT: COULD NOT DETERMINE for ${n_unverified} upstream row(s). This is NOT a pass. (rc=2)${C_OFF}" ;;
esac

# -- JSON ----------------------------------------------------------------------
if [[ $JSON -eq 1 ]]; then
    jstr() {
        local s="$1" out="" c i
        for (( i=0; i<${#s}; i++ )); do
            c="${s:$i:1}"
            case "$c" in
                '"')  out+='\"' ;;
                '\')  out+='\\' ;;
                $'\n') out+='\n' ;;
                $'\t') out+='\t' ;;
                $'\r') out+='\r' ;;
                *)    if [[ "$c" < " " ]]; then out+=$(printf '\\u%04x' "'$c"); else out+="$c"; fi ;;
            esac
        done
        printf '"%s"' "$out"
    }
    printf '{\n'
    printf '  "schema": "verify-provider-ci/1",\n'
    printf '  "root": %s,\n' "$(jstr "$ROOT")"
    printf '  "window_days": %s,\n' "$WINDOW_DAYS"
    printf '  "since": %s,\n' "$(jstr "$SINCE")"
    printf '  "exit_code": %s,\n' "$RC"
    printf '  "verdict": %s,\n' "$(jstr "$(case $RC in 0) echo no-provider-side-triggering ;; 1) echo provider-side-triggering-confirmed ;; 2) echo could-not-determine ;; esac)")"
    printf '  "adapters": { "github.com": {"state": %s, "reason": %s}, "gitlab.com": {"state": %s, "reason": %s}, "gitflic.ru": {"state": %s, "reason": %s}, "gitverse.ru": {"state": %s, "reason": %s} },\n' \
        "$(jstr "$GH_STATE")" "$(jstr "$GH_REASON")" "$(jstr "$GLAB_STATE")" "$(jstr "$GLAB_REASON")" \
        "$(jstr "$GFL_STATE")" "$(jstr "$GFL_REASON")" "$(jstr "$GVS_STATE")" "$(jstr "$GVS_REASON")"
    printf '  "counts": {"confirmed": %s, "unverified": %s, "historical": %s, "no_trigger": %s, "out_of_scope": %s},\n' \
        "$n_confirmed" "$n_unverified" "$n_hist" "$n_clean" "$n_scope"
    printf '  "repositories": [\n'
    first=1
    for i in "${!REPO_DIR[@]}"; do
        [[ $first -eq 0 ]] && printf ',\n'; first=0
        printf '    {"path": %s, "ownership": %s, "evidence": %s, "file_ci_active": %s, "file_ci_inert": %s, "file_ci_list": %s}' \
            "$(jstr "${REPO_REL[$i]}")" "$(jstr "${REPO_OWNED[$i]}")" "$(jstr "${REPO_EVID[$i]}")" \
            "${FILE_ACTIVE_N[$i]}" "${FILE_INERT_N[$i]}" "$(jstr "${FILE_ACTIVE_LIST[$i]}")"
    done
    printf '\n  ],\n'
    printf '  "rows": [\n'
    first=1
    for (( r=0; r<${#R_REPO[@]}; r++ )); do
        [[ $first -eq 0 ]] && printf ',\n'; first=0
        printf '    {"repo": %s, "provider": %s, "target": %s, "ownership": %s, "file_ci": %s, "provider_trigger": %s, "verdict": %s, "detail": %s}' \
            "$(jstr "${R_REPO[$r]}")" "$(jstr "${R_HOST[$r]}")" "$(jstr "${R_TARGET[$r]}")" \
            "$(jstr "${R_OURS[$r]}")" "$(jstr "${R_FILECI[$r]}")" "$(jstr "${R_TRIG[$r]}")" \
            "$(jstr "${R_VERDICT[$r]}")" "$(jstr "${R_DETAIL[$r]}")"
    done
    printf '\n  ],\n'
    printf '  "remediation": [\n'
    first=1
    for m in ${REMEDY[@]+"${REMEDY[@]}"}; do
        [[ $first -eq 0 ]] && printf ',\n'; first=0
        kind="${m%%|*}"; rest="${m#*|}"; who="${rest%%|*}"; text="${rest#*|}"
        printf '    {"kind": %s, "subject": %s, "action": %s}' "$(jstr "$kind")" "$(jstr "$who")" "$(jstr "$text")"
    done
    printf '\n  ],\n'
    printf '  "unverified": [\n'
    first=1
    for m in ${UNVERIFIED_LOG[@]+"${UNVERIFIED_LOG[@]}"}; do
        [[ $first -eq 0 ]] && printf ',\n'; first=0
        printf '    %s' "$(jstr "$m")"
    done
    printf '\n  ],\n'
    printf '  "uninitialised_submodules": [\n'
    first=1
    for m in ${UNINIT[@]+"${UNINIT[@]}"}; do
        [[ $first -eq 0 ]] && printf ',\n'; first=0
        printf '    %s' "$(jstr "$m")"
    done
    printf '\n  ]\n'
    printf '}\n'
fi

exit $RC
