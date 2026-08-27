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

PASSED=0; FAILED=0; SKIPPED=0
declare -a SUMMARY=()

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

    if [[ -z "$hits" ]]; then
        echo "PASS — 'git ls-files | grep -E \"$CI_PROBE_RE\"' returned empty."
        echo "No active root-level GitHub Actions workflow or GitLab pipeline is tracked."
        return 0
    fi

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
    cd "$ROOT/_tests" || { echo "FATAL: cannot cd to _tests" >&2; return 90; }
    npx playwright test --project=chromium --grep-invert "all-language"
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

# ---- Argument handling -------------------------------------------------------
case "${1:-}" in
    --install)   install_hook; exit $? ;;
    --uninstall) uninstall_hook; exit $? ;;
    --list)      print_table; exit 0 ;;
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
printf 'passed=%d  failed=%d  skipped=%d\n' "$PASSED" "$FAILED" "$SKIPPED"

if [[ $FAILED -gt 0 ]]; then
    echo
    echo "${RED}${BOLD}PUSH BLOCKED${NC} — $FAILED gate(s) failed. Logs: $LOGDIR"
    echo "Fix the gate, or state an explicit, evidenced reason; do not bypass."
    exit 1
fi

if [[ $SKIPPED -gt 0 ]]; then
    echo
    echo "${YELLOW}$SKIPPED gate(s) SKIPPED with a stated reason (§11.4.3).${NC}"
    echo "A SKIP is NOT a PASS. Before a release or a §11.4.40 pre-tag sweep,"
    echo "satisfy the preconditions and re-run with PREPUSH_STRICT=1."
fi

echo
echo "${GREEN}${BOLD}ALL RUN GATES PASSED${NC} — push allowed."
exit 0
