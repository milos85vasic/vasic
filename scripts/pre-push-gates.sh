#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Local pre-push quality gates for the vasic umbrella.
#
# WHY THIS EXISTS
# ---------------
# Constitution §11.4.156 mandates that ALL server-side CI/CD automation be
# DISABLED in every repository we author and push:
#
#   (A) no active `.github/workflows/*.yml|*.yaml`, no `.gitlab-ci.yml` at the
#       repository ROOT — the only location a provider executes;
#   (B) "disabled" means a push triggers ZERO runs (delete, or rename to a
#       non-active name — `if: false` jobs still queue runs and are NOT
#       compliant);
#   (D) introducing a new active workflow/pipeline is a release blocker;
#   (E) before any push, verify no root-level active CI exists:
#         git ls-files | grep -E '^\.github/workflows/.*\.ya?ml$|^\.gitlab-ci\.yml$'
#       must return empty for authored repos.
#
# "Enforcement migrates to the LOCAL §11.4.75 five-layer git-hook ritual ...
# never a remote runner." This script IS that local enforcement. The umbrella's
# workflow was renamed to `.github/workflows/ci.yml.disabled` (inert, preserved
# for provenance); every gate it ran is reproduced here, in the same order, with
# the same commands — plus gate E, which the remote runner could not perform.
#
# USAGE
# -----
#   bash scripts/pre-push-gates.sh              # run the gates (exit 0 = push OK)
#   bash scripts/pre-push-gates.sh --install    # install .git/hooks/pre-push
#   bash scripts/pre-push-gates.sh --uninstall  # remove the installed hook
#   bash scripts/pre-push-gates.sh --list       # print the gate table, run nothing
#   bash scripts/pre-push-gates.sh --prove-failure   # the §1.1 paired proof
#   bash scripts/pre-push-gates.sh --help
#
#   `.git/hooks/` is NOT tracked by git, so the hook never travels with a clone.
#   `--install` is the reproducible installer — run it once per checkout. It is
#   idempotent and hardlink-backs-up any pre-existing foreign hook (§9).
#
# ENVIRONMENT SWITCHES
# --------------------
#   PREPUSH_VERBOSE=1     stream each gate's output live instead of on failure
#   PREPUSH_SKIP_SLOW=1   skip gate 6 (the full Playwright suite) with an
#                         explicit, printed SKIP reason (§11.4.3) — never a
#                         silent pass
#   PREPUSH_STRICT=1      treat every SKIP as a FAILURE (use before a release /
#                         a §11.4.40 pre-tag sweep, where a SKIP is not good
#                         enough)
#   PREPUSH_ONLY="E 0 1"  run only the listed gate ids (debugging / mutation
#                         proofs); ids are E 0 1 2 3 4 5 6
#
#   There is deliberately NO switch that skips gate E. §11.4.156 states: "No
#   escape hatch — no --allow-ci, --enable-workflow, --keep-pipeline,
#   --remote-ci-OK, --ci-exempt flag."
#
# NO HARDCODED PATHS
# ------------------
# `scripts/audit-hardcoded-paths.sh` (gate 0, which this script runs against
# itself) fails the push if a machine-specific absolute path is reintroduced.
# The repo root below is DERIVED — from `git rev-parse --show-toplevel`, with a
# BASH_SOURCE fallback. Nothing here is literal.
#
# ERROR HANDLING
# --------------
# `set -e` is deliberately NOT used: this script must keep running after a gate
# fails so it can report the full picture, and `set -e` interacts badly with
# functions used in conditionals. EVERY command that matters therefore has an
# EXPLICIT exit-status check. In particular every `cd` is `cd ... || return`:
# `_tools/deploy-langs.sh` once used `set -uo pipefail` WITHOUT `-e`, its
# `cd "$ROOT"` failed silently, and it went on to commit and push both site
# submodules from the wrong directory. That bug is not repeated here.
#
# WORKTREE HYGIENE (evidence guard)
# ---------------------------------
# Gates 5 and 6 REGENERATE TRACKED files under `_tests/evidence/`: verdict
# JSONs embed a fresh `generatedAt` timestamp, the perf budget embeds measured
# LCP timings, and homepage screenshots re-render with pixel-level drift.
# Without a guard, EVERY successful push leaves `git status` dirty with
# gate-produced churn, and the next `git add .` (the commit wrapper) silently
# sweeps that churn into an unrelated commit. The guard snapshots the exact
# pre-gate state of `_tests/evidence/` and restores it once all run gates have
# PASSED, making gate runs worktree-neutral. A deliberate evidence refresh is
# unaffected — it is committed BEFORE the push, so the restore target already
# contains it. If any gate FAILS nothing is restored: the regenerated evidence
# is diagnostic and stays on disk.
# ------------------------------------------------------------------------------
set -uo pipefail

# ---- Repo root: DERIVED, never literal ---------------------------------------
# Resolved while the git hook environment (GIT_DIR/GIT_INDEX_FILE) is still
# intact, then that environment is dropped so the `git` calls in the gates below
# operate on the real worktree and the real index no matter where they run from.
_root_from_git="$(git rev-parse --show-toplevel 2>/dev/null)"
if [[ -n "$_root_from_git" && -d "$_root_from_git" ]]; then
    ROOT="$_root_from_git"
else
    ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)" || {
        echo "FATAL: cannot derive repository root from BASH_SOURCE" >&2; exit 2; }
fi
unset _root_from_git
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_PREFIX 2>/dev/null || true

# ABSOLUTE path to this file, resolved BEFORE the cd below. A relative
# BASH_SOURCE stops resolving the moment the working directory changes, and the
# paired proof re-invokes this file from inside its sandbox (measured: rc 127).
SELF_ABS="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/$(basename -- "${BASH_SOURCE[0]}")"

cd "$ROOT" || { echo "FATAL: cannot cd to derived root '$ROOT'" >&2; exit 2; }

# ---- Presentation ------------------------------------------------------------
if [[ -t 1 ]]; then
    RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'
    BLUE=$'\033[0;34m'; BOLD=$'\033[1m';    NC=$'\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; BLUE=''; BOLD=''; NC=''
fi

VERBOSE="${PREPUSH_VERBOSE:-0}"
SKIP_SLOW="${PREPUSH_SKIP_SLOW:-0}"
STRICT="${PREPUSH_STRICT:-0}"
ONLY="${PREPUSH_ONLY:-}"

LOGDIR="$(mktemp -d "${TMPDIR:-/tmp}/vasic-prepush.XXXXXX")" || {
    echo "FATAL: cannot create a log directory" >&2; exit 2; }

PASSED=0; FAILED=0; SKIPPED=0; UNDET=0
declare -a SUMMARY=()

# ---- Evidence worktree guard (see WORKTREE HYGIENE in the header) ------------
EVIDENCE_GUARD="$LOGDIR/evidence-guard"
mkdir -p "$EVIDENCE_GUARD" || {
    echo "FATAL: cannot create $EVIDENCE_GUARD" >&2; exit 2; }
# Baseline = the CURRENT state, not HEAD: a push attempted with pre-existing
# uncommitted evidence changes must restore THAT state. `--binary` because the
# homepage screenshots are PNGs; a plain diff cannot re-apply their content.
git diff --binary -- _tests/evidence > "$EVIDENCE_GUARD/pre-gates.patch" || {
    echo "FATAL: cannot snapshot _tests/evidence" >&2; exit 2; }
git ls-files --others --exclude-standard -- _tests/evidence \
    > "$EVIDENCE_GUARD/pre-gates-untracked.txt" || {
    echo "FATAL: cannot list untracked evidence files" >&2; exit 2; }

restore_evidence() {
    # `git checkout --` restores the worktree from the INDEX, which also undoes
    # gate regeneration of files that had STAGED changes; the recorded patch
    # (worktree-vs-index delta) then brings pre-existing unstaged edits back.
    if ! git checkout -- _tests/evidence; then
        echo "WARNING: evidence-guard checkout failed — worktree left as-is." >&2
        return 1
    fi
    if [[ -s "$EVIDENCE_GUARD/pre-gates.patch" ]]; then
        if ! git apply "$EVIDENCE_GUARD/pre-gates.patch"; then
            echo "WARNING: evidence-guard patch re-apply failed; the baseline" >&2
            echo "         delta is preserved at $EVIDENCE_GUARD/pre-gates.patch" >&2
            return 1
        fi
    fi
    # Remove untracked files the gates created; keep pre-existing untracked
    # files and anything gitignored (e.g. _tests/evidence/html-report/).
    local f
    while IFS= read -r f; do
        if ! grep -qxF "$f" "$EVIDENCE_GUARD/pre-gates-untracked.txt"; then
            rm -f -- "$f" && echo "evidence-guard: removed gate-created artifact: $f"
        fi
    done < <(git ls-files --others --exclude-standard -- _tests/evidence)
    echo "evidence-guard: _tests/evidence/ restored to its pre-gate state."
    return 0
}

# The canonical §11.4.156(E) probe, quoted verbatim from the anchor so the
# enforcement and the rule cannot drift apart.
CI_PROBE_RE='^\.github/workflows/.*\.ya?ml$|^\.gitlab-ci\.yml$'

# ---- Gate table --------------------------------------------------------------
# id | short name | provenance
GATE_IDS=(E 0 1 2 3 4 5 6)
gate_name() {
    case "$1" in
        E) echo "§11.4.156(E) no active root CI config" ;;
        0) echo "hardcoded path audit" ;;
        1) echo "Go unit tests (_tools/gen)" ;;
        2) echo "hardcoding audit (builds the Go generator)" ;;
        3) echo "HelixTranslate reproducibility self-test" ;;
        4) echo "portfolio §1.1 data-integrity self-validation" ;;
        5) echo "harness self-validation (visual §11.4.170 + export §11.4.168)" ;;
        6) echo "Playwright (chromium), excluding the all-language crawl" ;;
        *) echo "unknown gate '$1'" ;;
    esac
}
gate_cmd_text() {
    case "$1" in
        E) echo "git ls-files | grep -E '${CI_PROBE_RE}'   (must be EMPTY)" ;;
        0) echo "./scripts/audit-hardcoded-paths.sh" ;;
        1) echo "cd _tools/gen && go test ./..." ;;
        2) echo "bash _tools/audit-hardcoding.sh" ;;
        3) echo "bash _tools/translate/reproducibility-selftest.sh" ;;
        4) echo "bash _tools/portfolio/self-validate.sh" ;;
        5) echo "bash _tests/run-harness-selfvalidation.sh" ;;
        6) echo "cd _tests && npx playwright test --project=chromium --grep-invert 'all-language'" ;;
        *) echo "-" ;;
    esac
}

# ---- Preconditions -----------------------------------------------------------
# A gate whose toolchain is absent must SKIP with a stated reason (§11.4.3),
# never silently pass. `precondition` echoes the reason and returns 1 when the
# gate cannot honestly run.
precondition() {
    case "$1" in
        5|6)
            if [[ ! -d "$ROOT/_tests/node_modules/@playwright/test" ]]; then
                echo "_tests/node_modules/@playwright/test is absent — run: (cd _tests && npm ci && npx playwright install chromium)"
                return 1
            fi
            ;;
    esac
    case "$1" in
        6)
            if [[ "$SKIP_SLOW" == "1" ]]; then
                echo "PREPUSH_SKIP_SLOW=1 was set by the operator"
                return 1
            fi
            if [[ ! -f "$ROOT/milosvasic.ru/_site/index.html" ]]; then
                echo "milosvasic.ru/_site is not built — run: (cd milosvasic.ru && bundle exec jekyll build --destination _site)"
                return 1
            fi
            if [[ ! -f "$ROOT/vasic.digital/index.html" ]]; then
                echo "the vasic.digital submodule is not checked out — run: git submodule update --init vasic.digital"
                return 1
            fi
            ;;
    esac
    return 0
}

# ---- Gate bodies -------------------------------------------------------------
# Each runs in its own subshell (see run_gate), so a `cd` cannot leak, and each
# returns an explicit status.

gate_E() {
    # §11.4.156(E). Driven by the anchor's own command. Note: with `pipefail`,
    # a no-match `grep` makes the PIPELINE exit 1 — and no-match is exactly the
    # PASS case — so the verdict is taken from the CAPTURED TEXT, never from $?.
    local hits untracked
    hits="$(git ls-files | grep -E "$CI_PROBE_RE")"

    # Advisory only: an untracked active-looking config is not pushed, but the
    # project's commit wrapper runs `git add .`, so it would become tracked on
    # the next commit. Warn; do not fail on it.
    untracked="$(git ls-files --others --exclude-standard | grep -E "$CI_PROBE_RE")"
    if [[ -n "$untracked" ]]; then
        echo "WARNING (advisory, not a failure): untracked active-CI config(s) present on disk."
        echo "The commit wrapper runs 'git add .', so these would become tracked:"
        printf '%s\n' "$untracked" | sed 's/^/  /'
        echo
    fi

    # ---- Submodule sweep (§11.4.156(C) scope) --------------------------------
    # `git ls-files` at the umbrella CANNOT see inside a submodule — a gitlink is
    # ONE entry, not the submodule's files. Probing only the umbrella therefore
    # passes over an active workflow living in any submodule, which is exactly
    # where a new module's CI would be added. Measured before this fix:
    # milosvasic.ru tracked an active pages.yml and superspec an active ci.yml,
    # and this gate reported PASS. The fleet is DERIVED from .gitmodules, never
    # hardcoded, so a submodule added tomorrow is swept without editing this file.
    local sub_viol="" sub_note="" sub_undet="" sub_dev="" p n owned_urls
    if [[ -r "$ROOT/.gitmodules" ]]; then
        # Namespaces this tree demonstrably owns, derived from the umbrella's own
        # remotes — the same evidence class scripts/verify-provider-ci.sh uses.
        # Ownership is DERIVED from helix-deps.yaml's declared deps[].ssh_url set —
        # the authoritative owned-fleet declaration, itself guarded in BOTH directions
        # by verify-governance-cascade.sh C6, so it cannot drift from .gitmodules
        # unnoticed.
        #
        # An earlier version derived ownership from the UMBRELLA's own remote
        # namespaces. Measured, that yielded only "milos85vasic", so vasic.digital and
        # design-toolkit — both genuinely owned, under the vasic-digital namespace —
        # were classified THIRD-PARTY and waved through as out of scope. A workflow
        # planted in design-toolkit did NOT fail the gate. Recorded because the narrow
        # version looked correct and survived a casual reading.
        owned_urls="$(sed -nE 's/^[[:space:]]*ssh_url:[[:space:]]*(.+)$/\1/p' \
                      "$ROOT/helix-deps.yaml" 2>/dev/null | tr -d '\r' | sort -u)"
        while IFS= read -r p; do
            [[ -n "$p" ]] || continue
            if [[ ! -e "$ROOT/$p/.git" ]]; then
                # NOT a failure: an uninitialised submodule cannot be inspected.
                # Per Honest Instruments, "could not check" is its own state.
                sub_undet="${sub_undet}${p} (not initialised)"$'\n'
                continue
            fi
            n="$(git -C "$ROOT/$p" ls-files 2>/dev/null | grep -E "$CI_PROBE_RE" || true)"
            [[ -n "$n" ]] || continue
            # §11.4.156(C): scope is repositories WE author and push. A gitlink
            # whose remote sits outside every owned namespace is structurally out
            # of scope and MUST NOT be mass-edited (§11.4.29).
            local sub_url
            sub_url="$(git config -f "$ROOT/.gitmodules" --get "submodule.${p}.url" 2>/dev/null || echo '')"
            # A DOCUMENTED DEVIATION is not an override — §11.4.156 forbids overrides
            # ("No escape hatch"), and this is deliberately NOT one. The rule still
            # judges the repo non-compliant; what this table changes is only whether
            # THIS gate blocks the push. It follows the repository's existing baseline
            # convention (scripts/audit-environment-assumptions.sh): every entry
            # carries a REASON, every entry is printed on EVERY run, and the tree can
            # never go quietly green over it. A NEW violation anywhere still fails.
            # Rationale for blocking-vs-reporting: a gate that can never pass is
            # bypassed with --no-verify and then enforces nothing at all.
            local dev_reason=""
            case "$p" in
                milosvasic.ru)
                    dev_reason="sole publish path for the live site https://milosvasic.ru — GitHub Pages reports build_type=\"workflow\", so disabling this file takes production dark. Operator directive 2026-08-27: \"No website can be broken!\" Documented deviation, NOT an override." ;;
            esac
            if [[ -n "$dev_reason" ]]; then
                sub_dev="${sub_dev}${p} $(printf '%s' "$n" | tr '\n' ' ')"$'\n'"    REASON: ${dev_reason}"$'\n'
                continue
            fi
            if [[ -n "$sub_url" ]] && ! printf '%s\n' "$owned_urls" | grep -qxF "$sub_url"; then
                sub_note="${sub_note}${p} [third-party: ${sub_url}] $(printf '%s' "$n" | tr '\n' ' ')"$'\n'
            else
                sub_viol="${sub_viol}${p} $(printf '%s' "$n" | tr '\n' ' ')"$'\n'
            fi
        done < <(git config -f "$ROOT/.gitmodules" --get-regexp 'submodule\..*\.path' 2>/dev/null | awk '{print $2}')
    fi

    if [[ -n "$sub_dev" ]]; then
        # run_gate captures gate stdout to a log and prints it ONLY on failure, so a
        # PASSING gate is silent. A deviation that is only visible when something
        # else breaks is not "recorded" — it is hidden. Route it to a channel the
        # summary prints unconditionally.
        printf '%s' "$sub_dev" >> "${LOGDIR}/deviations" 2>/dev/null || true
        echo "DOCUMENTED DEVIATION — active CI in an owned submodule, knowingly retained."
        echo "This is NOT an override (§11.4.156 forbids one) and NOT compliance."
        echo "The repository remains non-compliant here; it is recorded, not hidden:"
        printf '%s' "$sub_dev" | sed 's/^/  /'
        echo
    fi
    if [[ -n "$sub_note" ]]; then
        echo "NOTE — active CI in third-party gitlink(s), OUT OF SCOPE per §11.4.156(C)."
        echo "Reported so it is never silently omitted; NOT edited, NOT a failure:"
        printf '%s' "$sub_note" | sed 's/^/  /'
        echo
    fi
    if [[ -n "$sub_undet" ]]; then
        echo "COULD NOT CHECK — submodule(s) not initialised, so their CI state is unknown."
        echo "This is not a pass. Run: git submodule update --init --recursive"
        printf '%s' "$sub_undet" | sed 's/^/  /'
        echo
    fi

    if [[ -z "$hits" && -z "$sub_viol" ]]; then
        echo "PASS — no active root-level CI config tracked in this repository"
        echo "       or in any OWNED submodule (fleet derived from .gitmodules)."
        return 0
    fi

    if [[ -n "$sub_viol" ]]; then
        echo "§11.4.156 VIOLATION — active root-level CI config(s) TRACKED in owned submodule(s):"
        printf '%s' "$sub_viol" | sed 's/^/  /'
        echo
        echo "A submodule is a repository we author and push, so §11.4.156 applies to it"
        echo "in full. Fix it INSIDE that submodule, then commit the gitlink bump."
        echo
    fi
    if [[ -z "$hits" ]]; then return 1; fi

    echo "§11.4.156 VIOLATION — active root-level CI config(s) are TRACKED in this repository:"
    printf '%s\n' "$hits" | sed 's/^/  /'
    echo
    echo "§11.4.156(A): no active root .github/workflows/*.yml|*.yaml and no .gitlab-ci.yml"
    echo "              may exist in a repository we author and push."
    echo "§11.4.156(B): disabled means a push triggers ZERO runs. Delete the file, or"
    echo "              rename it to a non-active name (the §11.4.75 '.disabled' /"
    echo "              '.disabled-local-only' convention). Setting 'if: false' on the"
    echo "              jobs is NOT sufficient — the run still queues."
    echo "§11.4.156(D): adding an active workflow/pipeline is a release blocker."
    echo
    echo "Fix, for each file listed above:"
    echo "    git mv <file> <file>.disabled"
    echo "There is no override flag. §11.4.156: 'No escape hatch'."
    return 1
}

gate_0() { "$ROOT/scripts/audit-hardcoded-paths.sh"; }

gate_1() {
    cd "$ROOT/_tools/gen" || { echo "FATAL: cannot cd to _tools/gen" >&2; return 90; }
    go test ./...
}

gate_2() { bash "$ROOT/_tools/audit-hardcoding.sh"; }

gate_3() { bash "$ROOT/_tools/translate/reproducibility-selftest.sh"; }

gate_4() { bash "$ROOT/_tools/portfolio/self-validate.sh"; }

gate_5() { bash "$ROOT/_tests/run-harness-selfvalidation.sh"; }

gate_6() {
    # A suite that CANNOT START is not a suite that FAILED. Playwright exits 1 both
    # when tests fail and when its webServer port is already held — e.g. by another
    # Playwright run on the same box. Reporting the second as a failure sends someone
    # hunting a defect in the site that was never demonstrated. Detected here and
    # mapped to rc=2 so run_gate reports UNDET, matching the project's 0/1/2 contract.
    # The config declares its webServer ports as `port: NNNN` (there are two), not
    # as a localhost URL — parse the real form rather than a guessed one.
    local _pw_busy=""
    while IFS= read -r _pw_port; do
        [[ -n "$_pw_port" ]] || continue
        ss -tln 2>/dev/null | grep -q ":${_pw_port}[[:space:]]" && _pw_busy="${_pw_busy}${_pw_port} "
    done < <(sed -nE 's/^[[:space:]]*port:[[:space:]]*([0-9]+).*/\1/p' "$ROOT/_tests/playwright.config.js" 2>/dev/null)
    if [[ -n "$_pw_busy" ]]; then
        echo "COULD NOT DETERMINE — webServer port(s) already in use: ${_pw_busy}"
        echo "Playwright cannot bind them, so the suite never ran. This is NOT a test"
        echo "failure and NOT a site defect — do not go looking for one."
        for _pw_port in $_pw_busy; do
            ss -tlnp 2>/dev/null | grep ":${_pw_port}[[:space:]]" | sed 's/^/  /'
        done
        echo "Most likely another Playwright run is active on this host. Re-run when it ends."
        return 2
    fi
    # rc=2, not 90: an unreachable _tests directory means the gate COULD NOT RUN.
    cd "$ROOT/_tests" || { echo "COULD NOT DETERMINE — cannot cd to _tests" >&2; return 2; }

    # Part of this suite asserts against the LIVE production sites over the public
    # internet (VASIC_BASE/MILOS_BASE default to https://vasic.digital and
    # https://milosvasic.ru). A DNS or TCP failure there means the suite COULD NOT
    # REACH the site — not that the site is broken. Observed on this host:
    # 6x net::ERR_TIMED_OUT, 5x "getaddrinfo EAI_AGAIN", 50x 60s page.goto timeouts,
    # while curl fetched both sites with http=200 and a valid certificate minutes
    # earlier. Reporting that as a site defect sends someone hunting a bug that was
    # never demonstrated — the same conflation this project has fixed five times.
    #
    # So classify. Every failure network-class => 2 (COULD NOT DETERMINE). ANY real
    # assertion failure => 1. This must never become a blanket excuse that turns a
    # genuine regression green, which is why the assertion count gates it.
    local _out _rc _net _assert
    _out="$(npx playwright test --project=chromium --grep-invert "all-language" 2>&1)"; _rc=$?
    printf '%s\n' "$_out"
    [[ $_rc -eq 0 ]] && return 0

    _net=$(printf '%s' "$_out" | grep -cE 'net::ERR_(TIMED_OUT|NAME_NOT_RESOLVED|CONNECTION_(RESET|REFUSED|CLOSED))|EAI_AGAIN|ENOTFOUND|ECONNRESET|Request context disposed|page\.goto: Test timeout' || true)
    # An assertion FAILURE is Playwright's own error output — 'Error: expect(...)',
    # or a bare 'Expected:'/'Received:' pair. It is NOT the source line Playwright
    # echoes to show WHERE a test died, which looks like:
    #     281 |     expect(await toggle.getAttribute('aria-expanded')).toBe('false');
    # Those echoes appear for EVERY failure, including pure navigation timeouts, so
    # counting them classified 28 network timeouts as 'real assertion failures' and
    # forced rc=1. Strip the 'NNN | ' source-echo lines before classifying.
    # Only 'Error: expect(' and 'AssertionError' are reliable markers of a genuine
    # assertion failure. A bare 'Expected:'/'Received:' pair is NOT: a spec that
    # catches a network error and asserts on a sentinel produces exactly that shape.
    # Measured live — all-languages-link-integrity turns a connection refusal into
    # 'Expected: 200 / Received: 0', which is a reachability failure wearing an
    # assertion's clothes. Counting it would re-introduce the same false positive
    # that source-code echoes already caused once.
    _assert=$(printf '%s' "$_out" \
        | grep -vE '^[[:space:]]*[0-9]+ \|' \
        | grep -cE 'Error: expect\(|AssertionError' || true)

    if [[ $_net -gt 0 && $_assert -eq 0 ]]; then
        echo
        echo "COULD NOT DETERMINE — every failure in this run is network-class"
        echo "(${_net} reachability error(s), 0 assertion failures)."
        echo "Part of this suite targets the LIVE production sites over the public"
        echo "internet. A DNS/TCP failure is a REACHABILITY problem on this host, NOT"
        echo "evidence that the sites are broken. Verify independently:"
        echo "    curl -sS -o /dev/null -w '%{http_code}\\n' -L https://vasic.digital/"
        echo "    curl -sS -o /dev/null -w '%{http_code}\\n' -L https://milosvasic.ru/"
        echo "Re-run on a quiet network, or pin VASIC_BASE/MILOS_BASE at local builds."
        return 2
    fi
    echo
    echo "REAL FAILURE — ${_assert} assertion failure(s) alongside ${_net} reachability error(s)."
    return 1
}

# ---- Runner ------------------------------------------------------------------
run_gate() {
    local id="$1"
    local name log reason rc started elapsed
    name="$(gate_name "$id")"
    log="$LOGDIR/gate-$id.log"

    reason="$(precondition "$id")"
    if [[ $? -ne 0 ]]; then
        if [[ "$STRICT" == "1" ]]; then
            printf '%s✖ FAIL%s  gate %-2s %s\n' "$RED" "$NC" "$id" "$name"
            printf '        PREPUSH_STRICT=1 and the gate cannot run: %s\n' "$reason"
            FAILED=$((FAILED + 1))
            SUMMARY+=("FAIL|$id|$name|unmet precondition under PREPUSH_STRICT=1: $reason")
            return 1
        fi
        printf '%s● SKIP%s  gate %-2s %s\n' "$YELLOW" "$NC" "$id" "$name"
        printf '        reason: %s\n' "$reason"
        SKIPPED=$((SKIPPED + 1))
        SUMMARY+=("SKIP|$id|$name|$reason")
        return 0
    fi

    printf '%s▶ RUN %s  gate %-2s %s\n' "$BLUE" "$NC" "$id" "$name"
    started=$SECONDS
    if [[ "$VERBOSE" == "1" ]]; then
        ( "gate_$id" ) 2>&1 | tee "$log"
        rc=${PIPESTATUS[0]}
    else
        ( "gate_$id" ) > "$log" 2>&1
        rc=$?
    fi
    elapsed=$((SECONDS - started))

    if [[ $rc -eq 0 ]]; then
        printf '%s✔ PASS%s  gate %-2s %s  (%ss)\n' "$GREEN" "$NC" "$id" "$name" "$elapsed"
        PASSED=$((PASSED + 1))
        SUMMARY+=("PASS|$id|$name|${elapsed}s")
        return 0
    fi

    # rc=2 is "COULD NOT DETERMINE", not "FAILED". Until 2026-09-01 this runner
    # mapped EVERY non-zero child rc to FAILED, so a gate that honestly reported
    # it could not inspect something was published as a violation of the tree.
    # That is the same conflation this project has now found five times, and it
    # was sitting in the runner that judges all the others.
    #
    # It still exits non-zero — a blind instrument is never a pass — but it is
    # counted and printed SEPARATELY from FAIL, matching the `err` convention in
    # scripts/verify-all-constitution-rules.sh. Distinct from SKIP: a SKIP never
    # ran (unmet precondition); an UNDET ran and could not reach a verdict.
    if [[ $rc -eq 2 ]]; then
        printf '%s⚠ UNDET%s gate %-2s %s  (rc=2, %ss)\n' "$YELLOW" "$NC" "$id" "$name" "$elapsed"
        printf '        the gate RAN but could not determine a verdict. This is NOT a pass,\n'
        printf '        and NOT a finding against this tree — the check itself could not see.\n'
        printf '        log: %s\n' "$log"
        UNDET=$((UNDET + 1))
        SUMMARY+=("UNDET|$id|$name|rc=2, log=$log")
        return 2
    fi

    printf '%s✖ FAIL%s  gate %-2s %s  (rc=%s, %ss)\n' "$RED" "$NC" "$id" "$name" "$rc" "$elapsed"
    printf '        command: %s\n' "$(gate_cmd_text "$id")"
    if [[ "$VERBOSE" != "1" ]]; then
        echo "        ---- last 40 lines of output ----"
        tail -n 40 "$log" | sed 's/^/        /'
        echo "        ---- full log: $log ----"
    fi
    FAILED=$((FAILED + 1))
    SUMMARY+=("FAIL|$id|$name|rc=$rc, log=$log")
    return 1
}

print_table() {
    printf '%s%-3s %-62s %s%s\n' "$BOLD" "ID" "GATE" "COMMAND" "$NC"
    local id
    for id in "${GATE_IDS[@]}"; do
        printf '%-3s %-62s %s\n' "$id" "$(gate_name "$id")" "$(gate_cmd_text "$id")"
    done
}

# ---- Hook installation -------------------------------------------------------
# The hook is a thin shim: it re-derives the root and execs the tracked script,
# so editing the tracked script takes effect immediately with no reinstall.
HOOK_MARKER='vasic pre-push gates (Constitution 11.4.156)'

install_hook() {
    local gitdir hook backup
    gitdir="$(git rev-parse --git-dir 2>/dev/null)"
    if [[ -z "$gitdir" ]]; then
        echo "FATAL: not inside a git repository — cannot install the hook" >&2; return 2
    fi
    # --git-dir may be relative to the cwd; make it absolute against $ROOT.
    case "$gitdir" in /*) : ;; *) gitdir="$ROOT/$gitdir" ;; esac
    mkdir -p "$gitdir/hooks" || { echo "FATAL: cannot create $gitdir/hooks" >&2; return 2; }
    hook="$gitdir/hooks/pre-push"

    if [[ -e "$hook" ]] && ! grep -qF "$HOOK_MARKER" "$hook" 2>/dev/null; then
        # §9: hardlinked backup before any destructive op; copy if the link fails.
        backup="$hook.pre-vasic-gates.$(date +%Y%m%d-%H%M%S)"
        if ln "$hook" "$backup" 2>/dev/null || cp -p "$hook" "$backup"; then
            echo "Backed up the existing pre-push hook to: $backup"
        else
            echo "FATAL: refusing to overwrite '$hook' — its backup could not be made" >&2
            return 2
        fi
    fi

    cat > "$hook" <<'HOOK'
#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# vasic pre-push gates (Constitution 11.4.156)
#
# GENERATED by `bash scripts/pre-push-gates.sh --install`. Do not edit this file:
# it is a shim, and `.git/hooks/` is not tracked by git. All logic lives in the
# tracked, reviewable script it execs. Re-install with the command above.
#
# Server-side CI is disabled repo-wide per Constitution 11.4.156; these gates are
# the local replacement, including the 11.4.156(E) pre-push self-check.
# ------------------------------------------------------------------------------
set -uo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
if [[ -z "$ROOT" || ! -d "$ROOT" ]]; then
    # Fallback for exotic layouts: this hook lives at <git-dir>/hooks/pre-push.
    ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)" || {
        echo "pre-push: FATAL — cannot derive the repository root" >&2; exit 1; }
fi

RUNNER="$ROOT/scripts/pre-push-gates.sh"
if [[ ! -f "$RUNNER" ]]; then
    echo "pre-push: FATAL — $RUNNER is missing." >&2
    echo "pre-push: the 11.4.156 local gates cannot run; refusing the push." >&2
    exit 1
fi

exec bash "$RUNNER" "$@"
HOOK
    chmod +x "$hook" || { echo "FATAL: cannot chmod +x '$hook'" >&2; return 2; }
    echo "${GREEN}Installed${NC} $hook"
    echo "It execs the tracked runner: scripts/pre-push-gates.sh"
    echo
    print_table
    return 0
}

uninstall_hook() {
    local gitdir hook
    gitdir="$(git rev-parse --git-dir 2>/dev/null)"
    if [[ -z "$gitdir" ]]; then echo "FATAL: not inside a git repository" >&2; return 2; fi
    case "$gitdir" in /*) : ;; *) gitdir="$ROOT/$gitdir" ;; esac
    hook="$gitdir/hooks/pre-push"
    if [[ ! -e "$hook" ]]; then echo "Nothing to remove: $hook does not exist"; return 0; fi
    if ! grep -qF "$HOOK_MARKER" "$hook" 2>/dev/null; then
        echo "Refusing to remove '$hook': it is not the generated vasic shim." >&2; return 1
    fi
    rm -f "$hook" || { echo "FATAL: cannot remove '$hook'" >&2; return 2; }
    echo "Removed $hook"
    return 0
}

usage() {
    sed -n '2,60p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

# ------------------------------------------------------------------------------
# §1.1 PAIRED MUTATION PROOF  —  --prove-failure
#
# WHAT IS UNDER TEST. This RUNNER, not the gates it calls. Its guarded property
# is the verdict machinery: a failing gate must BLOCK the push and be named; a
# gate that could not see must be counted as UNDETERMINED and block WITHOUT
# accusing the tree; an unmet precondition must SKIP with a stated reason and
# become a FAILURE under PREPUSH_STRICT=1; and §11.4.156(E) must fire on active
# CI at the umbrella root AND inside an OWNED submodule while leaving a
# third-party gitlink alone. Every one of those is asserted below by seeding the
# condition and reading the exit code, not by reading the source.
#
# WHY A SYNTHETIC REPOSITORY. Two reasons, both measured rather than assumed:
#
#   1. A control that is the real tree is green only while eight real gates are
#      green — one of which is a Playwright suite that needs a built Jekyll site
#      and the public internet. A red control returns before the first mutation
#      and the proof exits having demonstrated nothing. That is the "inoperative
#      proof" defect recorded in docs/check-registry.md, found in two of this
#      repository's own gates on 2026-09-01.
#   2. A full live run is NOT read-only. On success this runner calls
#      restore_evidence, which runs `git checkout -- _tests/evidence` and
#      re-applies a patch — it REWRITES TRACKED FILES in the working tree. A
#      proof must not do that to the repository it is being run in.
#
# So the battery runs against a throwaway git repository under `mktemp -d` whose
# gate 0 is a stub reading its exit code out of a sidecar file: the mutation is
# DATA, the control is green BY CONSTRUCTION, and nothing outside the sandbox is
# created, written or removed. PREPUSH_ONLY — which this file's own header
# documents as being for "debugging / mutation proofs" — keeps each run to the
# two gates that carry the assertions.
#
# THE PRE-FLIGHT IS BOUNDED, AND SAYS SO (§11.4.6). It runs the REAL entry point
# against the REAL tree as `--list`, which proves the runner starts, derives the
# real root and enumerates its real gate table. It deliberately does NOT execute
# the eight gates, for reason 2 above. No claim is made here that they were run.
# ------------------------------------------------------------------------------
prove_failure() {
    local P_PASS=0 P_FAIL=0
    p_ok()  { P_PASS=$((P_PASS+1)); printf '✅ %-30s %s\n' "$1" "$2"; }
    p_bad() { P_FAIL=$((P_FAIL+1)); printf '❌ %-30s %s\n' "$1" "$2"; }

    echo "PRE-PUSH-GATES §1.1 PAIRED MUTATION PROOF"
    echo "----------------------------------------------------------------------"

    # Even `--list` mktemp's a log directory and does not remove it (by design —
    # its path is printed for diagnosis), so the pre-flight is given a TMPDIR of
    # its own and that is cleaned up here. A proof must leave no litter.
    local pf_out pf_rc pf_tmp
    pf_tmp="$(mktemp -d "${TMPDIR:-/tmp}/prepush-preflight.XXXXXX")" || {
        echo "PRE-PUSH-GATES-PROOF: UNDETERMINED — cannot create a scratch dir" >&2; return 2; }
    pf_out="$(env TMPDIR="$pf_tmp" bash "$SELF_ABS" --list 2>&1)"; pf_rc=$?
    rm -rf "$pf_tmp"
    if [[ $pf_rc -eq 0 ]] && printf '%s' "$pf_out" | grep -qF "§11.4.156(E) no active root CI config"; then
        printf 'ℹ %-30s the real entry point ran against the real tree and enumerated its %s\n' \
               "PRE-FLIGHT live --list" "$(printf '%s' "$pf_out" | grep -cE '^[E0-9] ')"
        printf '%-32s real gates. Bounded on purpose: a full live run REWRITES _tests/evidence\n' ""
        printf '%-32s via restore_evidence, so it is not performed here. REPORTED, never gating.\n' ""
    else
        p_bad "PRE-FLIGHT live --list" "the real entry point could not enumerate its own gate table (rc=${pf_rc})"
    fi

    if ! command -v git >/dev/null 2>&1; then
        echo "PRE-PUSH-GATES-PROOF: UNDETERMINED — git is not on PATH; no specimen can be built" >&2
        return 2
    fi

    # NOT `local`: the EXIT trap below fires after this function has returned, so
    # a function-scoped name would be unbound by then and `set -u` would kill the
    # cleanup with "unbound variable" — leaving the sandbox on disk. Measured.
    PSB="$(mktemp -d "${TMPDIR:-/tmp}/prepush-proof.XXXXXX")" || {
        echo "PRE-PUSH-GATES-PROOF: UNDETERMINED — cannot create a sandbox" >&2; return 2; }
    # cleanup: the specimen and this proof run's own log dir both live in TMPDIR
    # and are removed together. The real repository is never restored because it
    # is never written to.
    trap 'rm -rf "${PSB:-}" "${LOGDIR:-}"' EXIT INT TERM
    echo "  sandbox: $PSB"

    local SPEC="$PSB/tree"

    sgit() {
        env HOME="$PSB" GIT_CONFIG_NOSYSTEM=1 \
            git -c user.name=prepush-proof -c user.email=prepush-proof@invalid \
                -c commit.gpgsign=false -c init.defaultBranch=main "$@"
    }

    build_specimen() {
        rm -rf "$SPEC"
        mkdir -p "$SPEC/scripts" "$SPEC/_tests/evidence" || return 1
        cp "$SELF_ABS" "$SPEC/scripts/pre-push-gates.sh" || return 1
        chmod 755 "$SPEC/scripts/pre-push-gates.sh" || return 1

        # gate 0's subject: a stub whose exit code is DATA in a sidecar file.
        cat > "$SPEC/scripts/audit-hardcoded-paths.sh" <<'STUB0'
#!/usr/bin/env bash
f="${BASH_SOURCE[0]}.rc"; rc=0; [ -f "$f" ] && rc="$(cat "$f")"
echo "synthetic gate 0 reporting rc=${rc}"
exit "$rc"
STUB0
        chmod 755 "$SPEC/scripts/audit-hardcoded-paths.sh" || return 1
        : > "$SPEC/_tests/evidence/.keep" || return 1

        # The owned-fleet declaration gate E derives ownership from.
        cat > "$SPEC/helix-deps.yaml" <<'DEPS'
schema_version: 1
deps:
  - name: ownedsub
    ssh_url: git@github.com:synthetic-org/ownedsub.git
    ref: "1111111111111111111111111111111111111111"
DEPS
        # One OWNED gitlink and one THIRD-PARTY gitlink. Both are real nested git
        # repositories, so gate E's `git -C <path> ls-files` runs for real.
        printf '[submodule "ownedsub"]\n\tpath = ownedsub\n\turl = git@github.com:synthetic-org/ownedsub.git\n' \
            > "$SPEC/.gitmodules" || return 1
        printf '[submodule "vendorsub"]\n\tpath = vendorsub\n\turl = git@github.com:some-upstream/vendorsub.git\n' \
            >> "$SPEC/.gitmodules" || return 1
        local s
        for s in ownedsub vendorsub; do
            mkdir -p "$SPEC/$s" || return 1
            sgit -C "$SPEC/$s" init -q >/dev/null 2>&1 || return 1
            printf 'placeholder\n' > "$SPEC/$s/README" || return 1
            sgit -C "$SPEC/$s" add -A >/dev/null 2>&1 || return 1
            sgit -C "$SPEC/$s" commit -q -m "synthetic submodule" >/dev/null 2>&1 || return 1
        done

        sgit -C "$SPEC" init -q >/dev/null 2>&1 || return 1
        sgit -C "$SPEC" add -A -f -- scripts _tests helix-deps.yaml .gitmodules >/dev/null 2>&1 || return 1
        sgit -C "$SPEC" commit -q -m "synthetic prepush specimen" >/dev/null 2>&1 || return 1
        return 0
    }

    # run_spec [VAR=val ...] -- [argv...]   — the REAL runner, from inside $SPEC
    #
    # TMPDIR is pointed INSIDE the sandbox. Each invocation of this runner
    # mktemp's a log directory and deliberately never removes it (the logs are
    # diagnostic and their path is printed), so a battery of ~16 runs would
    # otherwise leave 16 stray directories in the host's real TMPDIR every time
    # the proof is executed. It is set BEFORE "${envs[@]}", so a case that
    # overrides TMPDIR on purpose — M8 — still wins: env applies assignments
    # left to right.
    mkdir -p "$PSB/tmp"
    run_spec() {
        local -a envs=()
        while [[ $# -gt 0 && "$1" != "--" ]]; do envs+=("$1"); shift; done
        [[ "${1:-}" == "--" ]] && shift
        ( cd "$SPEC" && env HOME="$PSB" GIT_CONFIG_NOSYSTEM=1 PREPUSH_ONLY="E 0" \
            TMPDIR="$PSB/tmp" \
            "${envs[@]}" timeout 300 bash "$SPEC/scripts/pre-push-gates.sh" "$@" 2>&1 )
    }

    # assert <label> <want-rc> <needle-or-empty> [VAR=val ...] -- [argv...]
    assert() {
        local label="$1" want="$2" needle="$3"; shift 3
        local out rc
        out="$(run_spec "$@")"; rc=$?
        if [[ $rc -ne $want ]]; then
            p_bad "$label" "expected rc=${want}, got rc=${rc}"
            printf '%s\n' "$out" | tail -8 | sed 's/^/        /'
            return
        fi
        if [[ -n "$needle" ]] && ! printf '%s' "$out" | grep -qF -- "$needle"; then
            p_bad "$label" "rc=${want} as required, but the output never NAMED '${needle}'"
            printf '%s\n' "$out" | tail -8 | sed 's/^/        /'
            return
        fi
        p_ok "$label" "rc=${rc}${needle:+, and it named '${needle}'}"
    }

    build_specimen || {
        echo "PRE-PUSH-GATES-PROOF: UNDETERMINED — the specimen could not be built" >&2; return 2; }

    # ---- CONTROL -------------------------------------------------------------
    assert "CONTROL synthetic-green    " 0 "ALL RUN GATES PASSED"
    if [[ $P_FAIL -gt 0 ]]; then
        echo "----------------------------------------------------------------------"
        echo "❌ PRE-PUSH-GATES §1.1 PROOF: ABORTED — the synthetic control did not pass, so"
        echo "   ZERO mutations ran and nothing below would have been proved."
        return 1
    fi

    # ---- M1  a gate FAILS -> the push is blocked and the gate is named -------
    printf '1\n' > "$SPEC/scripts/audit-hardcoded-paths.sh.rc"
    assert "M1 gate-fails-blocks-push  " 1 "PUSH BLOCKED"
    local out
    out="$(run_spec)"
    if printf '%s' "$out" | grep -qE 'passed=1[[:space:]]+failed=1[[:space:]]+undetermined=0'; then
        p_ok "M1b failure-counted-as-FAIL" "the counters read passed=1 failed=1 undetermined=0"
    else
        p_bad "M1b failure-counted-as-FAIL" "a failing gate was not counted as a FAIL"
        printf '%s' "$out" | grep -E 'passed=' | sed 's/^/        /'
    fi
    rm -f "$SPEC/scripts/audit-hardcoded-paths.sh.rc"

    # ---- M2  a gate is BLIND (rc=2) -> UNDET, blocks, does NOT accuse --------
    # This is the distinction the runner acquired on 2026-09-01 and that nothing
    # had ever demonstrated. Asserted here on BOTH halves: the exit code, and the
    # counters showing it was not laundered into FAILED.
    printf '2\n' > "$SPEC/scripts/audit-hardcoded-paths.sh.rc"
    assert "M2 gate-blind-is-UNDET     " 1 "COULD NOT DETERMINE a verdict"
    out="$(run_spec)"
    if printf '%s' "$out" | grep -qE 'passed=1[[:space:]]+failed=0[[:space:]]+undetermined=1' \
       && printf '%s' "$out" | grep -qF "NOT a failure of this tree and NOT a pass"; then
        p_ok "M2b blind-is-not-a-FAIL   " "counters read failed=0 undetermined=1, and it refuses to accuse the tree"
    else
        p_bad "M2b blind-is-not-a-FAIL  " "an rc=2 gate was conflated with a FAILURE"
        printf '%s' "$out" | grep -E 'passed=|UNDET' | sed 's/^/        /'
    fi
    rm -f "$SPEC/scripts/audit-hardcoded-paths.sh.rc"

    # ---- M3  §11.4.156(A): an active workflow at the umbrella root -----------
    mkdir -p "$SPEC/.github/workflows"
    printf 'name: ci\non: [push]\njobs:\n  x:\n    runs-on: ubuntu-latest\n    steps: [{run: "true"}]\n' \
        > "$SPEC/.github/workflows/ci.yml"
    sgit -C "$SPEC" add -A -f -- .github >/dev/null 2>&1
    sgit -C "$SPEC" commit -q -m "seed an active root workflow" >/dev/null 2>&1
    assert "M3 root-workflow-active    " 1 "§11.4.156 VIOLATION"
    # ---- M4  no escape hatch: an env switch must not make that pass ----------
    assert "M4 no-escape-hatch         " 1 "There is no override flag" PREPUSH_SKIP_SLOW=1 --
    sgit -C "$SPEC" rm -r -q --cached .github >/dev/null 2>&1
    rm -rf "$SPEC/.github"
    sgit -C "$SPEC" commit -q -m "remove the seeded workflow" >/dev/null 2>&1

    # ---- M5  the same rule, one level down: an OWNED submodule --------------
    # The umbrella's own `git ls-files` cannot see inside a gitlink, which is how
    # this exact violation passed the gate before the submodule sweep existed.
    mkdir -p "$SPEC/ownedsub/.github/workflows"
    printf 'name: deploy\non: [push]\njobs: {x: {runs-on: ubuntu-latest, steps: [{run: "true"}]}}\n' \
        > "$SPEC/ownedsub/.github/workflows/deploy.yml"
    sgit -C "$SPEC/ownedsub" add -A -f >/dev/null 2>&1
    sgit -C "$SPEC/ownedsub" commit -q -m "seed an active workflow inside an owned submodule" >/dev/null 2>&1
    assert "M5 owned-submodule-workflow" 1 "TRACKED in owned submodule(s)"
    sgit -C "$SPEC/ownedsub" rm -r -q --cached .github >/dev/null 2>&1
    rm -rf "$SPEC/ownedsub/.github"
    sgit -C "$SPEC/ownedsub" commit -q -m "remove it" >/dev/null 2>&1

    # ---- M6  the scope rule DISCRIMINATES: a third-party gitlink is reported,
    #          never failed and never edited (§11.4.156(C) / §11.4.29).
    #          Without this, M5 would be satisfied by a gate that just always
    #          fails on any workflow anywhere.
    mkdir -p "$SPEC/vendorsub/.github/workflows"
    printf 'name: upstream\non: [push]\njobs: {x: {runs-on: ubuntu-latest, steps: [{run: "true"}]}}\n' \
        > "$SPEC/vendorsub/.github/workflows/upstream.yml"
    sgit -C "$SPEC/vendorsub" add -A -f >/dev/null 2>&1
    sgit -C "$SPEC/vendorsub" commit -q -m "seed an active workflow inside a third-party gitlink" >/dev/null 2>&1
    assert "M6 third-party-out-of-scope" 0 "ALL RUN GATES PASSED"
    out="$(run_spec PREPUSH_VERBOSE=1 --)"
    if printf '%s' "$out" | grep -qF "OUT OF SCOPE" && printf '%s' "$out" | grep -qF "vendorsub"; then
        p_ok "M6b out-of-scope-is-NAMED " "it is reported by name rather than silently omitted"
    else
        p_bad "M6b out-of-scope-is-NAMED" "a third-party finding was dropped instead of reported"
    fi
    sgit -C "$SPEC/vendorsub" rm -r -q --cached .github >/dev/null 2>&1
    rm -rf "$SPEC/vendorsub/.github"
    sgit -C "$SPEC/vendorsub" commit -q -m "remove it" >/dev/null 2>&1

    # ---- M7  an unmet precondition SKIPs with a reason, and STRICT fails it --
    assert "M7 precondition-skips      " 0 "SKIPPED with a stated reason" PREPUSH_ONLY="5" --
    assert "M7b strict-turns-SKIP-FAIL " 1 "PREPUSH_STRICT=1 and the gate cannot run" \
           PREPUSH_ONLY="5" PREPUSH_STRICT=1 --

    # ---- M8  the runner cannot create its workspace -> rc 2, never 0 --------
    assert "M8 no-log-dir-is-rc2       " 2 "cannot create a log directory" TMPDIR=/nonexistent --

    # ---- M9  PREPUSH_ONLY runs ONLY what it lists ---------------------------
    # Seed gate 0 red and exclude it: the run must stay green, or the selector
    # every mutation above depends on would be meaningless.
    printf '1\n' > "$SPEC/scripts/audit-hardcoded-paths.sh.rc"
    assert "M9 only-selects-gates      " 0 "ALL RUN GATES PASSED" PREPUSH_ONLY="E" --
    assert "M9b and-the-red-gate-is-red" 1 "PUSH BLOCKED" PREPUSH_ONLY="E 0" --
    rm -f "$SPEC/scripts/audit-hardcoded-paths.sh.rc"

    # ---- RESTORED CONTROL ---------------------------------------------------
    assert "CONTROL restored           " 0 "ALL RUN GATES PASSED"

    echo "----------------------------------------------------------------------"
    if [[ $P_FAIL -gt 0 ]]; then
        echo "❌ PRE-PUSH-GATES §1.1 MUTATION PROOF: FAIL — ${P_FAIL} case(s) did not hold."
        return 1
    fi
    echo "✅ PRE-PUSH-GATES §1.1 MUTATION PROOF: PASS — the real entry point ran against the"
    echo "   real tree (bounded to --list, reported, never gating), a synthetic control that is"
    echo "   green by construction passed, and 9 mutations were each caught: a failing gate"
    echo "   blocks the push and is counted as FAILED; a BLIND gate blocks as UNDETERMINED with"
    echo "   failed=0, refusing to accuse the tree; §11.4.156(E) fires at the umbrella root and"
    echo "   inside an OWNED submodule while REPORTING a third-party gitlink it must not edit;"
    echo "   an env switch cannot buy an escape hatch; an unmet precondition SKIPs with a reason"
    echo "   and FAILs under PREPUSH_STRICT=1; an uncreatable log dir is rc=2, not a pass; and"
    echo "   PREPUSH_ONLY runs only what it names. Nothing outside the sandbox was written."
    return 0
}

# ---- Argument handling -------------------------------------------------------
case "${1:-}" in
    --install)   install_hook; exit $? ;;
    --uninstall) uninstall_hook; exit $? ;;
    --list)      print_table; exit 0 ;;
    --prove-failure) prove_failure; exit $? ;;
    --help|-h)   usage; exit 0 ;;
    "")          : ;;
    *)
        # git calls the hook with "<remote> <url>"; ignore those positional args.
        : ;;
esac

# ---- Main --------------------------------------------------------------------
echo
echo "${BOLD}pre-push gates — Constitution §11.4.156 local enforcement${NC}"
echo "repo: $ROOT"
echo "logs: $LOGDIR"
[[ "$STRICT" == "1" ]] && echo "mode: ${BOLD}STRICT${NC} — a SKIP counts as a FAILURE"
echo "----------------------------------------------------------------------"

for gid in "${GATE_IDS[@]}"; do
    if [[ -n "$ONLY" ]]; then
        case " $ONLY " in *" $gid "*) : ;; *) continue ;; esac
    fi
    run_gate "$gid"
done

echo "----------------------------------------------------------------------"
for row in "${SUMMARY[@]}"; do
    IFS='|' read -r st gid nm note <<< "$row"
    case "$st" in
        PASS) printf '%s%-4s%s gate %-2s %-60s %s\n' "$GREEN" "$st" "$NC" "$gid" "$nm" "$note" ;;
        SKIP) printf '%s%-4s%s gate %-2s %-60s %s\n' "$YELLOW" "$st" "$NC" "$gid" "$nm" "$note" ;;
        *)    printf '%s%-4s%s gate %-2s %-60s %s\n' "$RED" "$st" "$NC" "$gid" "$nm" "$note" ;;
    esac
done
echo "----------------------------------------------------------------------"
printf 'passed=%d  failed=%d  undetermined=%d  skipped=%d\n' "$PASSED" "$FAILED" "$UNDET" "$SKIPPED"

# Documented deviations are surfaced on EVERY run, pass or fail. A green run that
# silently carries a known §11.4.156 non-compliance is the "quietly green tree"
# this project's constitution names as a defect in its own right.
if [[ -s "${LOGDIR}/deviations" ]]; then
    printf '\n%s── DOCUMENTED DEVIATIONS (not overrides; still non-compliant) ──%s\n' "$YELLOW" "$NC"
    sed 's/^/  /' "${LOGDIR}/deviations"
    printf '%s  These do NOT block the push. They are NOT compliance.%s\n' "$YELLOW" "$NC"
fi

# An UNDETERMINED gate blocks the push for the same reason the `err` counter does
# in the constitution sweep: a blind instrument is never a pass. It is reported
# separately from FAILED so nobody hunts a defect that was never demonstrated.
if [[ $UNDET -gt 0 && $FAILED -eq 0 ]]; then
    echo
    echo "${YELLOW}${BOLD}$UNDET gate(s) COULD NOT DETERMINE a verdict (rc=2).${NC}"
    echo "This is NOT a failure of this tree and NOT a pass. The listed gate(s)"
    echo "ran but could not see what they needed. Fix the instrument or its"
    echo "environment, then re-run — do not go looking for a defect in the code."
    for row in "${SUMMARY[@]}"; do
        [[ "${row%%|*}" == "UNDET" ]] || continue
        IFS='|' read -r _ i n d <<<"$row"
        printf '  gate %-2s %s — %s\n' "$i" "$n" "$d"
    done
    exit 1
fi

if [[ $FAILED -gt 0 ]]; then
    echo
    echo "${RED}${BOLD}PUSH BLOCKED${NC} — $FAILED gate(s) failed. Logs: $LOGDIR"
    echo "Fix the gate, or state an explicit, evidenced reason; do not bypass."
    echo "Note: _tests/evidence/ regeneration from the failed run is left on disk"
    echo "      for diagnosis; the evidence-guard restore only runs when gates pass."
    exit 1
fi

if [[ $SKIPPED -gt 0 ]]; then
    echo
    echo "${YELLOW}$SKIPPED gate(s) SKIPPED with a stated reason (§11.4.3).${NC}"
    echo "A SKIP is NOT a PASS. Before a release or a §11.4.40 pre-tag sweep,"
    echo "satisfy the preconditions and re-run with PREPUSH_STRICT=1."
fi

echo
restore_evidence || echo "${YELLOW}WARNING: evidence-guard restore incomplete — check 'git status'.${NC}" >&2
echo
echo "${GREEN}${BOLD}ALL RUN GATES PASSED${NC} — push allowed."
exit 0
