#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Fail the build on FROZEN ENVIRONMENT ASSUMPTIONS.
#
# WHY
# ---
# scripts/audit-hardcoded-paths.sh catches one narrow class: machine-specific
# absolute PATHS (`/Volumes/T7/...`). It is blind to everything else that ties
# this tree to one box. This is its sibling for the broader class, written
# against the operator directive:
#
#     "Make sure all this is fully dynamic and adaptable based on the
#      environment!"
#
# The failure mode this exists to prevent is NOT a loud crash — it is SILENT
# MISBEHAVIOUR. Three already-observed shapes in this repository:
#
#   * scripts/lumen-reindex.sh reads the Ollama backend via `systemctl show` +
#     `journalctl`. On a host with no systemd both return empty through
#     `2>/dev/null`, `backend_library()` yields "", and the Vulkan refusal that
#     the function exists to trigger NEVER FIRES. The script reports success
#     while doing none of its safety work.
#   * _tools/od/start-daemon.sh hardcodes /Applications/Open Design.app. On
#     Linux the `-x` test fails and the daemon simply never starts, so every
#     downstream diagram generation silently produces nothing.
#   * scripts/ollama-vulkan-remediation.sh writes /etc/sysconfig/ollama. On a
#     Debian-family host that file is /etc/default/ollama; the write "succeeds"
#     into a file systemd never reads.
#
# So `2>/dev/null` is NOT treated as a guard by this audit. It is the delivery
# mechanism for the bug.
#
# WHAT COUNTS AS DYNAMIC
# ----------------------
#   shell   HOST="${OLLAMA_HOST:-http://localhost:11434}"
#   python  os.environ.get("UI_WORKERS", "5")
#   node    process.env.VD_BASE || 'http://localhost:8401'
#   go      os.Getenv("...")
#   caps    command -v systemctl   /  check_command brew  /  case $(uname -s)
#   os      $OSTYPE / process.platform / sys.platform / runtime.GOOS
#
# A literal that sits behind ANY of those is a DEFAULT, not an assumption, and
# is not reported. A bare literal with no such escape hatch is the defect.
#
#   ./scripts/audit-environment-assumptions.sh               # audit this repo
#   ./scripts/audit-environment-assumptions.sh /path/to/repo # another checkout
#   ./scripts/audit-environment-assumptions.sh --list        # scanned universe
#   ./scripts/audit-environment-assumptions.sh --classes     # class reference
#   ./scripts/audit-environment-assumptions.sh --allow-list  # effective rules
#
# Exit 0 = clean · 1 = findings · 2 = could not do its job
# (three-valued convention, same as scripts/lumen-index-doctor.sh — rc 2 must
#  never be collapsed into rc 1: a broken checker is not a clean tree, and it is
#  not a violating tree either.)
#
# ALLOW-LIST
# ----------
# Embedded below in ALLOW_RULES (the audit that produced this gate was allowed
# to add exactly two files to the tree, so the list could not be a third file).
# An external `.environment-assumptions-allow`, or $ENV_ASSUMPTIONS_ALLOW, is
# read IN ADDITION when present, so the list can be externalised later without
# touching this script.
#
# Rule syntax — three whitespace-separated fields, MATCH may contain spaces:
#
#     # REASON: <why this literal is genuinely justified>
#     path/to/file            CLASS    substring-of-the-offending-line
#
#     # BASELINE: <known defect, ticket/section reference>
#     path/to/file            CLASS    substring-of-the-offending-line
#
# PATH may end in `*` to prefix-match. CLASS and MATCH may each be `*`.
# EVERY rule MUST be immediately preceded by a `# REASON:` or `# BASELINE:`
# line. A rule without one is a MALFORMED ALLOW-LIST and exits 2 — an
# unexplained suppression is indistinguishable from a bluff.
#
# REASON  = justified forever; invisible in the summary beyond a count.
# BASELINE = a REAL defect, deliberately not fixed yet. Baselines are counted
#            and printed loudly on every clean run so the tree can never go
#            quietly green over known breakage.
# ------------------------------------------------------------------------------
set -uo pipefail

# ---- target ------------------------------------------------------------------
# Defaults to this script's own repository, but accepts an explicit directory so
# the gate can be pointed at any checkout — and so its own mutation proofs can
# run against throwaway repos instead of the live tree.
TARGET=""
MODE="audit"
for arg in "$@"; do
    case "$arg" in
        --list)       MODE="list" ;;
        --classes)    MODE="classes" ;;
        --allow-list) MODE="allow" ;;
        --help|-h)    MODE="help" ;;
        -*)           echo "FATAL: unknown option '$arg'" >&2; exit 2 ;;
        *)            TARGET="$arg" ;;
    esac
done

if [ -n "$TARGET" ]; then
    ROOT="$(cd -- "$TARGET" 2>/dev/null && pwd)" \
        || { echo "FATAL: no such directory '$TARGET'" >&2; exit 2; }
else
    ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd)" \
        || { echo "FATAL: cannot resolve script directory" >&2; exit 2; }
fi
cd "$ROOT" || { echo "FATAL: cannot cd to '$ROOT'" >&2; exit 2; }

# ---- prerequisites (rc 2, never rc 0) ---------------------------------------
for _bin in git awk grep; do
    command -v "$_bin" >/dev/null 2>&1 \
        || { echo "FATAL: required tool '$_bin' not on PATH" >&2; exit 2; }
done
git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1 \
    || { echo "FATAL: '$ROOT' is not a git working tree" >&2; exit 2; }

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'
    DIM=$'\033[2m';    NC=$'\033[0m'
else
    RED=""; GREEN=""; YELLOW=""; DIM=""; NC=""
fi

# ---- class reference ---------------------------------------------------------
CLASS_DOC='ENDPOINT  host:port literal (backend URL, bound port) with no env override
PARALLEL  CPU / thread / worker / concurrency count frozen to one box
MODEL     LLM or embedding model id, or a vector dimension, frozen in source
OSPATH    OS- or distro-specific filesystem location (/etc/sysconfig, /Applications, ...)
SERVICE   service-manager call (systemctl/journalctl/launchctl) with no capability guard
PKGMGR    package-manager call (apt-get/yum/dnf/pacman/apk/brew) with no capability guard
GNUBSD    tool invocation whose flags differ between GNU coreutils and BSD/macOS
HOSTNAME  a specific machine name baked into source
TOOLVER   toolchain version duplicated away from the manifest that already pins it
GITREF    git remote or branch name written as a literal instead of derived
GPU       GPU / driver / accelerator assumption with no capability guard
SHEBANG   absolute interpreter path instead of /usr/bin/env (except /bin/sh)'

# ---- embedded allow-list -----------------------------------------------------
# Two kinds only. Read the header before adding anything here.
ALLOW_RULES="$(cat <<'ALLOW_EOF'
# REASON: this IS the detector. Its class patterns must literally contain every
# token it searches for (systemctl, /etc/sysconfig, llama-, *.local, sed -i,
# nvidia-smi ...). Exempting the detector from its own patterns is not an
# exemption from the rule - the same precedent as .hardcoded-paths-allow
# exempting scripts/audit-hardcoded-paths.sh.
scripts/audit-environment-assumptions.sh * *

# REASON: the sibling paths audit embeds machine-path prefixes for the same
# structural reason, and its SKIP/PATTERN strings collide with OSPATH.
scripts/audit-hardcoded-paths.sh * *

# REASON: _tools/pdf/build-pdfs.sh already dispatches BSD-first with a GNU
# fallback - `stat -f %m ... || stat -c %Y ... || echo 0`. That is the portable
# form this class asks for; flagging it would punish the fix.
_tools/pdf/build-pdfs.sh GNUBSD stat -f %m

# BASELINE: known defect F3 - docs/environment-adaptability/AUDIT.md.
# GNU `sed -i` in-place form; BSD/macOS sed requires an explicit backup suffix.
scripts/ollama-vulkan-remediation.sh GNUBSD sed -i

# BASELINE: known defect F6 - docs/environment-adaptability/AUDIT.md.
# GNU `sed -i` inside the mutation harness m4().
scripts/verify-governance-cascade.sh GNUBSD sed -i

# BASELINE: known defect F7 - docs/environment-adaptability/AUDIT.md.
# `readlink -f` is GNU-only; BSD/macOS readlink has no -f.
scripts/setup-agents-wizard.sh GNUBSD readlink -f

# BASELINE: known defect F8 - docs/environment-adaptability/AUDIT.md.
# `sort -V` is GNU-only; BSD sort has no version sort.
scripts/setup-agents-wizard.sh GNUBSD sort -V

# BASELINE: known defect F9 - docs/environment-adaptability/AUDIT.md.
# `stat -c` is GNU-only; the BSD/macOS spelling is `stat -f`.
scripts/test-setup-agents-wizard.sh GNUBSD stat -c

# REASON: test fixture - `sort -V` appears only inside the TITLE STRING of an
# assertion ("B3 launcher selects highest version (sort -V, not lexical)"). No
# sort is invoked on this line. The wizards real `sort -V` call is baselined
# separately as F8 against scripts/setup-agents-wizard.sh.
scripts/test-setup-agents-wizard.sh GNUBSD sort -V

# BASELINE: known defect F10 - docs/environment-adaptability/AUDIT.md.
# /Applications/Open Design.app is macOS-only with NO env override at all.
_tools/od/start-daemon.sh OSPATH /Applications/

# BASELINE: known defect F11 - docs/environment-adaptability/AUDIT.md.
# thinker.local / amber.local are the operators own two machines.
_tools/translate-fleet.sh HOSTNAME *

# BASELINE: known defect F11 (mirror) - docs/environment-adaptability/AUDIT.md.
_tools/helixtranslate-container.sh HOSTNAME *

# BASELINE: known defect F12 - docs/environment-adaptability/AUDIT.md.
# /usr/local/bin/unified-translator is the in-container install prefix, but it
# is written as a literal on the host side of the ssh boundary with no override.
_tools/helixtranslate-container/run.sh OSPATH /usr/local/bin/
# BASELINE: known defect F12 (mirror) - docs/environment-adaptability/AUDIT.md.
_tools/helixtranslate-local.sh OSPATH /usr/local/bin/

# BASELINE: known defect F13 - docs/environment-adaptability/AUDIT.md.
# Playwright binds fixed ports 8401/8082 and shells out to `python3 -m
# http.server`; no PORT env override, so two checkouts cannot test in parallel.
_tests/playwright.config.js ENDPOINT *
# BASELINE: known defect F13 (mirror) - docs/environment-adaptability/AUDIT.md.
_tests/visual-effects.config.js ENDPOINT *

# BASELINE: known defect F14 - docs/environment-adaptability/AUDIT.md.
# Spec files hardcode http://localhost:8401 / :8082 with no env override.
# all-languages-link-integrity.spec.js is the counter-example that already
# does it right (process.env.VD_BASE || ...) and is therefore NOT listed.
_tests/tests/* ENDPOINT *
# BASELINE: known defect F14 (mirror) - docs/environment-adaptability/AUDIT.md.
_tests/tools/motion-audit.cjs ENDPOINT *
# BASELINE: known defect F14 (mirror) - docs/environment-adaptability/AUDIT.md.
_tests/ui-l10n2-verify.js ENDPOINT *
# BASELINE: known defect F14 (mirror) - docs/environment-adaptability/AUDIT.md.
_tests/visual-effects.spec.js ENDPOINT *

# BASELINE: known defect F15 - docs/environment-adaptability/AUDIT.md.
# Model ids frozen as bare module constants instead of env-overridable.
_tools/gen/translate_home.py MODEL *
# BASELINE: known defect F15 (mirror) - docs/environment-adaptability/AUDIT.md.
_tools/gen/translate_ui_headroom.py MODEL *
# BASELINE: known defect F15 (mirror) - docs/environment-adaptability/AUDIT.md.
_tools/gen/review_ui_all.py MODEL *
# BASELINE: known defect F15 (mirror) - docs/environment-adaptability/AUDIT.md.
_tools/gen/translate_ui_batch.py MODEL *
# BASELINE: known defect F15 (mirror) - docs/environment-adaptability/AUDIT.md.
_tools/gen/translate_ui_chunked.py MODEL *
# BASELINE: known defect F15 (mirror) - docs/environment-adaptability/AUDIT.md.
_tools/gen/translate_ui_all.py MODEL *
# BASELINE: known defect F15 (mirror) - docs/environment-adaptability/AUDIT.md.
_tools/gen/translate-ui.py MODEL *
# REASON: this is a PROVIDER REGISTRY - each row is (canonical API endpoint,
# api-key env var, that providers own default model). The endpoints are the
# vendors published URLs and the model is overridden by the --model flag that
# the CLI already documents. Nothing here is bound to a machine.
_tools/review_translation.py MODEL *

# BASELINE: known defect F16 - docs/environment-adaptability/AUDIT.md.
# BYOK provider/model/base-url pinned with no override on the prompt driver.
design-system/diagrams/_prompts/build-and-generate.sh * *

# BASELINE: known defect F18 - docs/environment-adaptability/AUDIT.md.
# Go/Node/Ruby versions restated in the workflow instead of read from go.mod,
# _tests/package.json engines, and milosvasic.ru/.ruby-version.
.github/workflows/ci.yml.disabled TOOLVER *
# BASELINE: known defect F18 (mirror) - apt-get assumed as THE package manager.
.github/workflows/ci.yml.disabled PKGMGR *

# BASELINE: known defect F19 - docs/environment-adaptability/AUDIT.md.
# `#!/bin/bash` instead of `#!/usr/bin/env bash`; /bin/bash is absent on NixOS
# and is bash 3.2 on macOS.
upstreams/GitHub.sh SHEBANG *

# BASELINE: known defect F20 - docs/environment-adaptability/AUDIT.md.
# Fixed worker/parallelism counts and a 1200s sleep tuned to one machine.
_tools/watch-deploy.sh PARALLEL *

# REASON: .specify/extensions/superspec is THIRD-PARTY vendored upstream
# (WangX0111/superspec), outside the owned-submodule set. Its pinned
# python-version and installer calls are upstreams to change, not this repos.
.specify/extensions/* * *

# BASELINE: known defect F11 (mirror) - docs/environment-adaptability/AUDIT.md.
# thinker.local / amber.local plus the operators own ssh login are literals.
_tools/distribute-helixtranslate.sh HOSTNAME *

# BASELINE: known defect F15 (mirror) - docs/environment-adaptability/AUDIT.md.
_tools/gen/repair_ui_terms.py MODEL *
# BASELINE: known defect F15 (mirror) - docs/environment-adaptability/AUDIT.md.
_tools/gen/translate_aria_footer.py MODEL *
# BASELINE: known defect F15 (mirror) - docs/environment-adaptability/AUDIT.md.
_tools/gen/translate_ui_slow.py MODEL *

# BASELINE: known defect F22 - docs/environment-adaptability/AUDIT.md.
# /proc/uptime is Linux-only. The `|| echo` keeps it non-fatal, so this is LOW,
# but the started-at marker silently becomes blank on macOS/BSD.
_tools/watch-deploy.sh OSPATH /proc/uptime

# ---- genuinely justified, NOT defects ---------------------------------------
# Everything below this line was hand-checked and is a FALSE POSITIVE of the
# class pattern. Each states why. See the false-positive analysis in
# docs/environment-adaptability/AUDIT.md.

# REASON: the port is env-derived one line earlier (PORT="${OD_PORT:-4321}") and
# 127.0.0.1 is the loopback constant, deliberately chosen so the daemon is not
# reachable off-box. This specific line is a log message, not a binding.
_tools/od/start-daemon.sh ENDPOINT http://127.0.0.1:${PORT}

# REASON: "codestral" here is an entry in the NON-TRANSLATABLE technology-term
# list, alongside "Playwright", "pandoc" and "Jekyll". It configures nothing.
_tools/translate/glossary.json MODEL *

# REASON: this file defines its own `env(name, default)` os.environ wrapper
# (line ~86) and every literal is the last term of an
# `env(X) or cfg.get(Y) or "<literal>"` chain - the precedence is copied from
# the lumen upstream applyEnvOverrides. The literals ARE the documented final
# fallback. (No apostrophes in this block: ALLOW_RULES is a single-quoted here-
# string, and one stray quote would end it and let the rest run as shell.)
scripts/lumen-index-doctor.sh MODEL *
# REASON: as above - `env("OLLAMA_HOST") or cfg.get("host") or "http://..."`.
scripts/lumen-index-doctor.sh ENDPOINT *

# REASON: test fixture, not configuration. This grep PATTERN asserts that the
# wizard never restarts ollama nor writes /etc/sysconfig/ollama; the literal is
# the thing being forbidden.
scripts/test-setup-agents-wizard.sh OSPATH grep -cE
# REASON: test fixture - a synthetic throwaway repo is written with these lines
# to prove the sibling paths audit does NOT flag standard system locations.
scripts/test-setup-agents-wizard.sh OSPATH printf
# REASON: test fixture - port 1 is deliberately unreachable, proving the wizard
# survives an absent ollama backend. A reachable value would break the test.
scripts/test-setup-agents-wizard.sh ENDPOINT OLLAMA_HOST="http://127.0.0.1:1"
ALLOW_EOF
)"

# ---- collect the scan universe ----------------------------------------------
# Generated evidence, prose and translated content are not source: a documented
# example is not a defect (the false-positive rule this project learned the hard
# way when 167 of 187 raw grep hits turned out to be legitimate).
SKIP_PREFIX='^(_content|_analysis|_tests/evidence/|docs/|\.superpowers/|node_modules/|.*/node_modules/|.*/vendor/)'
KEEP_SUFFIX='\.(sh|bash|py|js|mjs|cjs|ts|go|yml|yaml|toml|cfg|conf|json|disabled)$'
SKIP_NAME='(package-lock\.json|Gemfile\.lock|go\.sum|\.min\.(js|css)$)'

FILELIST="$(git -C "$ROOT" ls-files 2>/dev/null \
    | grep -Ev "$SKIP_PREFIX" \
    | grep -E "$KEEP_SUFFIX" \
    | grep -Ev "$SKIP_NAME")" || true

# `git ls-files` also lists gitlinks (submodule directories). Drop anything that
# is not a regular readable file — including files deleted from the work tree.
SCANNED=""
while IFS= read -r f; do
    [ -n "$f" ] || continue
    [ -f "$ROOT/$f" ] || continue
    [ -r "$ROOT/$f" ] || continue
    SCANNED="$SCANNED$f
"
done <<EOF
$FILELIST
EOF

FILE_COUNT=$(printf '%s' "$SCANNED" | grep -c . || true)

case "$MODE" in
    help)
        grep -E '^#' "${BASH_SOURCE[0]}" | sed -n '2,80p' | sed 's/^# \{0,1\}//'
        exit 0 ;;
    classes)
        printf '%s\n' "$CLASS_DOC"; exit 0 ;;
    list)
        printf '%s' "$SCANNED"
        printf -- '---- %s file(s) in the scan universe\n' "$FILE_COUNT"
        exit 0 ;;
esac

# ANTI-BLUFF: a gate that finds nothing because it looked at nothing is the
# empty-build success this project has already been burned by. Zero files is a
# broken run (rc 2), never a clean one (rc 0).
if [ "$FILE_COUNT" -eq 0 ]; then
    echo "FATAL: scan universe is empty - refusing to report a clean tree over" >&2
    echo "       zero files. Check the SKIP/KEEP filters or the target repo." >&2
    exit 2
fi

# ---- assemble the effective allow-list --------------------------------------
TMPDIR_SAFE="${TMPDIR:-/tmp}"
WORK="$(mktemp -d "${TMPDIR_SAFE%/}/audit-envassume.XXXXXX")" \
    || { echo "FATAL: cannot create a temporary directory" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT INT TERM

ALLOW_FILE="${ENV_ASSUMPTIONS_ALLOW:-$ROOT/.environment-assumptions-allow}"
printf '%s\n' "$ALLOW_RULES" > "$WORK/allow.raw"
if [ -f "$ALLOW_FILE" ]; then
    printf '\n# ---- external: %s\n' "$ALLOW_FILE" >> "$WORK/allow.raw"
    cat "$ALLOW_FILE" >> "$WORK/allow.raw"
fi

# Validate: every rule needs a REASON/BASELINE on the line directly above it.
# A silent suppression is a bluff, so a malformed list is rc 2, not rc 1.
# The REASON may span several `#` lines; what matters is that the contiguous
# comment block directly above the rule carries one, with nothing between them.
BAD_RULES="$(awk '
    { line = $0 }
    line ~ /^[[:space:]]*$/ { blk = 0; next }
    line ~ /^[[:space:]]*#/ {
        if (line ~ /REASON:/ || line ~ /BASELINE:/) blk = 1
        next
    }
    {
        if (!blk) printf "line %d: %s\n", NR, line
        blk = 0
    }
' "$WORK/allow.raw")"

if [ -n "$BAD_RULES" ]; then
    echo "FATAL: malformed allow-list - every rule needs a '# REASON:' or" >&2
    echo "       '# BASELINE:' comment on the line directly above it." >&2
    printf '%s\n' "$BAD_RULES" | sed 's/^/       /' >&2
    exit 2
fi

if [ "$MODE" = "allow" ]; then
    cat "$WORK/allow.raw"; exit 0
fi

# Normalise to  KIND<TAB>PATH<TAB>CLASS<TAB>MATCH
awk '
    { line = $0 }
    line ~ /^[[:space:]]*$/ { blkkind = ""; next }
    line ~ /^[[:space:]]*#/ {
        if (line ~ /BASELINE:/)    blkkind = "BASELINE"
        else if (line ~ /REASON:/) blkkind = "REASON"
        next
    }
    {
        kind = (blkkind == "BASELINE") ? "BASELINE" : "REASON"
        n = split(line, f, /[[:space:]]+/)
        # f[1] may be empty when the line is indented
        i = (f[1] == "") ? 2 : 1
        p = f[i]; c = f[i+1]
        m = ""
        # MATCH is the remainder of the line after PATH and CLASS.
        rest = line
        sub(/^[[:space:]]+/, "", rest)
        sub(/^[^[:space:]]+[[:space:]]+/, "", rest)   # drop PATH
        sub(/^[^[:space:]]+[[:space:]]*/, "", rest)   # drop CLASS
        m = rest
        if (m == "") m = "*"
        if (c == "") c = "*"
        printf "%s\t%s\t%s\t%s\n", kind, p, c, m
        blkkind = ""
    }
' "$WORK/allow.raw" > "$WORK/allow.tsv"

printf '%s' "$SCANNED" > "$WORK/files.txt"

# ---- the scan ---------------------------------------------------------------
# ONE awk process over the whole universe. No per-file subshells, no GNU-only
# awk extensions (no ENDFILE, no gensub, no interval quantifiers - mawk 1.3.3
# does not support {n,m}), so the gate is itself free of the assumptions it
# polices and stays fast enough for a pre-push hook.
AWK_PROG='
function isallowed(path, cls, line,   i, ap, ac, am, ok) {
    for (i = 1; i <= arn; i++) {
        ap = arp[i]; ac = arc[i]; am = arm[i]
        ok = 0
        if (ap == path) ok = 1
        else if (substr(ap, length(ap), 1) == "*" &&
                 substr(path, 1, length(ap) - 1) == substr(ap, 1, length(ap) - 1)) ok = 1
        if (!ok) continue
        if (ac != "*" && ac != cls) continue
        if (am != "*" && index(line, am) == 0) continue
        allowkind = ark[i]
        return 1
    }
    return 0
}

function flush(   i, k, cls, ln, txt) {
    for (i = 1; i <= bn; i++) {
        cls = bc[i]; ln = bl[i]; txt = bt[i]
        # File-scope capability guard clears the three capability classes.
        if ((cls == "SERVICE" || cls == "PKGMGR" || cls == "GPU") && guarded) continue
        if (isallowed(bf[i], cls, txt)) {
            if (allowkind == "BASELINE") { basecount++; basefiles[bf[i]] = 1 }
            else                         { allowcount++ }
            continue
        }
        printf "HIT\t%s\t%d\t%s\t%s\n", bf[i], ln, cls, txt
        hits++
    }
    bn = 0; guarded = 0
}

BEGIN { FS = "\t" }

# ---- pass 0: the allow rules -------------------------------------------------
NR == FNR {
    arn++
    ark[arn] = $1; arp[arn] = $2; arc[arn] = $3; arm[arn] = $4
    next
}

# ---- per-file bookkeeping ----------------------------------------------------
FNR == 1 {
    if (cur != "") flush()
    cur = FILENAME
    guarded = 0
}

{
    raw = $0
    line = raw

    # SHEBANG is read from the raw first line, before comment blanking.
    if (FNR == 1) {
        if (line ~ /^#![ ]*\/(bin|usr\/bin|usr\/local\/bin)\/(bash|python|python3|node|perl|ruby|zsh|ksh)[ ]*$/) {
            bn++; bf[bn] = FILENAME; bl[bn] = FNR; bc[bn] = "SHEBANG"; bt[bn] = line
        }
    }

    # ---- capability guards are file-scoped ----------------------------------
    if (line ~ /command -v/ || line ~ /check_command/ || line ~ /uname -s/ ||
        line ~ /uname\)/    || line ~ /OSTYPE/        || line ~ /process\.platform/ ||
        line ~ /sys\.platform/ || line ~ /runtime\.GOOS/ || line ~ /type -p /)
        guarded = 1

    # ---- comment blanking, numbering preserved ------------------------------
    name = FILENAME
    sub(/\.disabled$/, "", name)
    sub(/\.disabled-local-only$/, "", name)
    if (name ~ /\.(py|sh|bash|yml|yaml|toml|cfg|conf)$/) {
        if (line ~ /^[[:space:]]*#/) line = ""
    } else if (name ~ /\.(js|mjs|cjs|ts|go)$/) {
        if (line ~ /^[[:space:]]*(\/\/|\*|\/\*)/) line = ""
    }
    if (line == "") next

    # ---- env-override escape hatch ------------------------------------------
    # Applies to the value classes only. No env var can make `sed -i` portable,
    # so GNUBSD / SHEBANG / SERVICE / PKGMGR / GITREF are not exempted here.
    envd = 0
    if (line ~ /\$\{[A-Za-z_][A-Za-z0-9_]*:[-=?]/ ||
        line ~ /os\.environ/     || line ~ /os\.getenv/  ||
        line ~ /process\.env/    || line ~ /os\.Getenv/  ||
        line ~ /System\.getenv/  || line ~ /getenv\(/    ||
        line ~ /ENV\[/)
        envd = 1

    # ---- classes -------------------------------------------------------------
    if (!envd) {
        if (line ~ /\/\/(localhost|127\.0\.0\.1|0\.0\.0\.0)/ ||
            line ~ /(localhost|127\.0\.0\.1|0\.0\.0\.0):[0-9]/ ||
            line ~ /[Pp][Oo][Rr][Tt][ ]*[:=][ ]*[0-9][0-9][0-9][0-9]/)
            add("ENDPOINT", raw)

        if (line ~ /(max_workers|maxWorkers|NUM_PARALLEL|OMP_NUM_THREADS|GOMAXPROCS|num_thread|MAXPAR|CONCURRENCY|FLEET_PARALLEL)[ ]*[:=][ ]*["'"'"']?[0-9]/ ||
            line ~ /[ ]-j[0-9]/ || line ~ /--jobs[ =][0-9]/ ||
            line ~ /--max-old-space-size=[0-9]/ ||
            line ~ /[ ]sleep [0-9][0-9][0-9]/)
            add("PARALLEL", raw)

        # A model id only counts as CODE when it is a quoted literal. The same
        # token in prose (a module docstring explaining which model was used) is
        # documentation, not a frozen assumption - see the false-positive rule
        # in docs/environment-adaptability/AUDIT.md.
        # A variable whose NAME says "fallback"/"default" is declaring the last
        # resort of an env/config precedence chain, not freezing a choice.
        isfallback = (line ~ /^[[:space:]]*[A-Za-z_]*([Ff]allback|[Dd]efault|DEFAULT|FALLBACK)[A-Za-z_]*[[:space:]]*=/)
        if (!isfallback && ((line ~ /["'"'"']/ &&
             line ~ /(llama-[0-9]|llama3|mistral-[a-z]|codestral|nomic-embed|jina-embeddings|command-r|glm-[0-9]|gpt-oss-|zai-glm|qwen[0-9]|all-minilm|text-embedding-|deepseek-)/) ||
            line ~ /(EMBED_DIM|embedding_dim|n_dims|vector_size)[ ]*[:=][ ]*[0-9]/))
            add("MODEL", raw)

        # A path is a PROBE, not an assumption, when the line either tests for
        # its existence or lists it alongside the sibling layouts of other
        # distributions. Flagging a working `for f in /etc/sysconfig/x
        # /etc/default/x /etc/conf.d/x` loop would punish the correct fix.
        nprobe = 0
        if (line ~ /\/etc\/sysconfig/) nprobe++
        if (line ~ /\/etc\/default/)   nprobe++
        if (line ~ /\/etc\/conf\.d/)   nprobe++
        isprobe = (nprobe > 1) || (line ~ /-[defrx][ ]+["$]*\/(etc|usr|opt|Applications|Library|proc)/)
        if (!isprobe &&
            line ~ /(\/etc\/sysconfig\/|\/etc\/default\/[a-z]|\/etc\/init\.d\/|\/Applications\/|\/Library\/|\/System\/Library|\/opt\/homebrew|\/usr\/local\/bin\/[a-z]|\/usr\/local\/lib\/[a-z]|\/proc\/[a-z]|C:\\\\)/)
            add("OSPATH", raw)

        if (line ~ /[a-z0-9][a-z0-9-]*\.(local|lan|home\.arpa)([^a-zA-Z0-9]|$)/ &&
            line !~ /localhost/)
            add("HOSTNAME", raw)

        if (line ~ /(go-version|node-version|ruby-version|python-version|java-version)[ ]*:[ ]*["'"'"']?[0-9]/ ||
            line ~ /(golang|node|ruby|python):[0-9]+\.[0-9]+/ ||
            line ~ /nvm use [0-9]/)
            add("TOOLVER", raw)

        if (line ~ /(nvidia-smi|CUDA_VISIBLE_DEVICES|GGML_VK_|HSA_OVERRIDE|rocm-smi|\/dev\/dri|\/dev\/nvidia)/)
            add("GPU", raw)
    }

    if (line ~ /(systemctl |journalctl |launchctl |rc-service |\/etc\/systemd)/ ||
        line ~ /service [a-z][a-z-]* (start|stop|restart|status)/)
        add("SERVICE", raw)

    if (line ~ /(apt-get |apt install|yum install|dnf install|pacman -S|apk add|brew install|zypper install)/)
        add("PKGMGR", raw)

    if (line ~ /(sed -i[ "'"'"']|readlink -f|stat -c |date -d |date --date|grep -P |xargs -r |sort -V|mktemp -p |du -b |cp --parents|base64 -w)/)
        add("GNUBSD", raw)

    if (line ~ /git [a-z-]+ [^;|&]*(origin|upstream)[ \/]/ ||
        line ~ /(origin|upstream)\/(main|master|develop)/ ||
        line ~ /refs\/heads\/(main|master)/)
        add("GITREF", raw)
}

function add(cls, txt) {
    bn++; bf[bn] = FILENAME; bl[bn] = FNR; bc[bn] = cls; bt[bn] = txt
}

END {
    if (cur != "") flush()
    printf "SUMMARY\t%d\t%d\t%d\n", hits, allowcount, basecount
    for (f in basefiles) printf "BASEFILE\t%s\n", f
}
'

# Relative paths on purpose: we are already cd'd to $ROOT, awk's FILENAME then
# matches the allow-list rules verbatim and the report needs no path surgery.
# shellcheck disable=SC2046  # word splitting of the file list is intended
RESULT="$(awk "$AWK_PROG" "$WORK/allow.tsv" $(cat "$WORK/files.txt") 2>"$WORK/awk.err")"
AWK_RC=$?
if [ $AWK_RC -ne 0 ]; then
    echo "FATAL: the scan itself failed (awk rc=$AWK_RC)" >&2
    sed 's/^/       /' "$WORK/awk.err" >&2
    exit 2
fi

# ---- report ------------------------------------------------------------------
printf '%s\n' "$RESULT" | grep '^HIT' > "$WORK/hits.tsv" || true

SUMMARY_LINE="$(printf '%s\n' "$RESULT" | grep '^SUMMARY' | head -1)"
[ -n "$SUMMARY_LINE" ] || { echo "FATAL: scan produced no summary record" >&2; exit 2; }

HITS=$(printf '%s' "$SUMMARY_LINE"    | cut -f2)
ALLOWED=$(printf '%s' "$SUMMARY_LINE" | cut -f3)
BASELINED=$(printf '%s' "$SUMMARY_LINE" | cut -f4)

if [ -s "$WORK/hits.tsv" ]; then
    cur_file=""
    while IFS="$(printf '\t')" read -r _tag path lineno cls text; do
        if [ "$path" != "$cur_file" ]; then
            printf '%s❌ %s%s\n' "$RED" "$path" "$NC"
            cur_file="$path"
        fi
        trimmed="$(printf '%s' "$text" | sed 's/^[[:space:]]*//' | cut -c1-96)"
        printf '     %s%-9s%s line %-5s %s\n' "$YELLOW" "$cls" "$NC" "$lineno" "$trimmed"
    done < "$WORK/hits.tsv"
fi

echo "────────────────────────────────────────────────────────"
printf '%sscanned %d file(s) · %d class(es)%s\n' "$DIM" "$FILE_COUNT" "$(printf '%s\n' "$CLASS_DOC" | grep -c .)" "$NC"

if [ "$BASELINED" -gt 0 ]; then
    printf '%s⚠️  %d baselined occurrence(s) — REAL, KNOWN, UNFIXED defects in:%s\n' \
        "$YELLOW" "$BASELINED" "$NC"
    printf '%s\n' "$RESULT" | grep '^BASEFILE' | cut -f2 | sort | sed 's/^/     /'
    printf '%s   see docs/environment-adaptability/AUDIT.md — a baseline is a debt,%s\n' "$YELLOW" "$NC"
    printf '%s   not a justification. Do not add to it without a finding id.%s\n' "$YELLOW" "$NC"
fi

if [ "$HITS" -eq 0 ]; then
    printf '%s✅ no NEW frozen environment assumptions%s' "$GREEN" "$NC"
    [ "$ALLOWED" -gt 0 ] && printf ' (%d justified occurrence(s) allow-listed)' "$ALLOWED"
    echo
    exit 0
fi

printf '%s❌ %d frozen environment assumption(s)%s\n' "$RED" "$HITS" "$NC"
echo
echo "Derive it from the environment instead of freezing it:"
echo "  shell   HOST=\"\${OLLAMA_HOST:-http://localhost:11434}\""
echo "  python  os.environ.get(\"UI_WORKERS\", \"5\")"
echo "  node    process.env.VD_BASE || 'http://localhost:8401'"
echo "  caps    command -v systemctl >/dev/null 2>&1 || fallback"
echo "  os      case \"\$(uname -s)\" in Darwin) ...;; Linux) ...;; esac"
echo
echo "\`2>/dev/null\` is NOT a guard — it is how the bug stays silent."
echo
echo "If an occurrence is genuinely justified, add a rule to ALLOW_RULES in"
echo "  scripts/audit-environment-assumptions.sh   (or .environment-assumptions-allow)"
echo "with a '# REASON:' line above it. A known-but-unfixed defect uses"
echo "'# BASELINE:' instead and must carry an AUDIT.md finding id."
exit 1
