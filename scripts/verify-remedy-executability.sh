#!/usr/bin/env bash
# verify-remedy-executability.sh — every documented way out must actually exist.
#
# ── THE DEFECT CLASS, MEASURED BEFORE IT WAS GENERALISED ─────────────────────
#
# `GET /api/chapters/{chapter}/accuracy` served a correct, honest body:
#
#     {"measured": false,
#      "reason": "verify-accuracy has not been run for this chapter",
#      "remedy": "bash workshop/scripts/verify-accuracy.sh <chapter> --reference <path>",
#      "wer": null}
#
# and the file it named DID NOT EXIST. Accuracy was not un-measured; it was
# un-runnable by the documented command. Under §11.4.6 that is a bluff — the
# body asserts a path to resolution that cannot be walked, and a reader cannot
# tell without trying it. The endpoint was not wrong about the measurement. It
# was wrong about the way out, which is the part a reader acts on.
#
# NOBODY WAS CHECKING. Every gate in this tree verifies its subject; not one
# verified its own advice. A remedy string is the only output a gate produces
# that the reader is expected to EXECUTE, and it was the only output nothing
# graded. This closes that.
#
# ── THREE-VALUED, AND 2 IS NEVER A PASS ──────────────────────────────────────
#
#   0  every remedy that names something resolves to something startable
#   1  a remedy names a file that is absent, unreadable, unstartable, or whose
#      interpreter is missing — a reader following it would fail
#   2  the question could not be answered: a scanroot is missing, no grep, the
#      scan matched nothing at all, or a candidate could not be classified
#
# `--strict` additionally promotes the EXTERNAL note (below) to 2.
#
# ── COMMAND vs INSTRUCTION: the discriminator, stated ────────────────────────
#
# Not every remedy is a command. "Ask your administrator to install podman" is a
# legitimate remedy and there is nothing here to resolve. Distinguishing the two
# badly is how this gate would become either useless or a liar, so the rule is
# stated rather than implied:
#
#   A remedy is a COMMAND when it names a SUBJECT A SHELL CAN START — a
#   path-shaped token (`dir/file.ext`, `./file`, an absolute path), or a head
#   token that resolves on PATH TO AN EXECUTABLE.
#
#   A remedy is an INSTRUCTION when it names no such subject. It addresses a
#   person; there is nothing for this gate to resolve; it is not a defect.
#
# "resolves on PATH" is not `command -v`. Measured on this host: `command -v
# AGENTS.md` SUCCEEDS, because a directory holding a markdown file is on this
# operator's PATH — so the target must also carry the executable bit and not be
# a directory. See `resolves_as_command`.
#
# One narrow refinement applies to the ambiguous branch ONLY — see
# `reads_as_prose`. `"remedy": "install a working ffprobe or ffmpeg on the host
# that runs …"` has the coreutils `install` as its head token, so a
# head-resolves rule alone would call an operator instruction a command. A
# payload carrying bare English articles and prepositions as standalone words is
# read as prose. It is consulted only AFTER the path-shaped search has come back
# empty, so it can never hide a broken file remedy.
#
# THE PROPERTY THAT MAKES THIS SAFE: classification NEVER consults whether the
# subject exists. Path-shape is lexical. `bash scripts/nope.sh` is therefore a
# COMMAND that FAILS, not an instruction that passes — a broken remedy can never
# be reclassified into the harmless bucket by virtue of being broken. That is
# the exact inversion this gate exists to prevent, so it is excluded by
# construction, not by care.
#
# Tokens holding a placeholder or an expansion (`<path>`, `${VAR}`, `$1`, `*`)
# are NOT subjects: they are holes the reader fills, and resolving them would be
# resolving the gate's own guess.
#
# ── EXISTENCE IS NOT ENOUGH; THE OPERATION IS EXERCISED ──────────────────────
#
# Measured on this host, 2026-09-01, and it is why "is it there?" is the wrong
# question:
#
#     command -v ffprobe   ->  /usr/bin/ffprobe        (found)
#     ffprobe -version     ->  exit 0                  (runs)
#     ffprobe -show_format ->  exit 8                  (UNUSABLE)
#
# Present, executable, and unable to do the thing it is named for. So for every
# file subject this gate does not stop at `-e`: it requires the file to be a
# readable, non-empty regular file; it requires either the executable bit or an
# explicit interpreter in the remedy itself; it resolves that interpreter (or
# the shebang's) on PATH; and it PARSES the file with that interpreter's own
# syntax check. `bash -n` on a shell script exercises exactly the operation the
# remedy promises — "this can be started" — and it catches the present-but-
# broken case without executing anything.
#
# HONEST BOUNDARY (§11.4.6). For an EXTERNAL head token — `git`, `podman`, `npm`
# — this gate proves EXISTENCE ONLY. It does not run them: a remedy corpus
# contains `git push`, `podman rm`, and this repository contains a deploy script
# that was fired accidentally today against two live production sites. Executing
# discovered strings is not a safety trade this gate is willing to make. Those
# are counted, listed under an unsuppressible NOTE, and `--strict` turns them
# into 2. A NOTE IS NOT A PASS; it is a stated limit.
#
# ── DERIVATION ───────────────────────────────────────────────────────────────
#
# CANDIDATES ARE DERIVED, never listed: the tree is scanned for the marker forms
# it actually emits (`"remedy":`, `*Remedy =`, and line-leading `Remedy:`/
# `Fix:`/`Run:`/`Try:`/`try:`) and whatever is found is what is graded. SCOPE is
# declared — `--scanroot`, defaults printed on every run — following the
# `scanroot` convention `scripts/check-registry.tsv` already established at this
# root. A declared scope boundary is not a claim that what lies outside it
# conforms, and this prints its own boundary rather than leaving it inferred.
#
# Usage:
#   bash scripts/verify-remedy-executability.sh
#   bash scripts/verify-remedy-executability.sh --strict
#   bash scripts/verify-remedy-executability.sh --scanroot workshop/docs
#   bash scripts/verify-remedy-executability.sh --prove-failure   # §1.1
#
# Registered in scripts/check-registry.tsv (rule R5); documented in
# docs/check-registry.md.

set -uo pipefail
# NOGLOB, and it is load-bearing. Remedy payloads are split into tokens with an
# unquoted expansion, which is the only way to word-split in POSIX shell — and
# under the default settings a payload containing `**` (markdown emphasis, in
# every `**Run:**` line in these docs) GLOBS AGAINST THE CURRENT DIRECTORY. The
# first run of this gate reported a remedy naming `AGENTS.md`, a file that
# appears in no remedy anywhere: `**` had expanded to the working directory's
# entries. A gate that invents its own subjects grades nothing.
set -f

SELF="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/$(basename -- "${BASH_SOURCE[0]}")"
ROOT="$(cd -- "$(dirname -- "$SELF")/.." && pwd -P)"
STRICT=0
PROVE=0
VERBOSE=0
SCANROOTS=()

while [ "$#" -gt 0 ]; do
    case "$1" in
        --root)          ROOT="${2:-}"; shift 2 ;;
        --scanroot)      SCANROOTS+=("${2:-}"); shift 2 ;;
        --strict)        STRICT=1; shift ;;
        --verbose)       VERBOSE=1; shift ;;
        --prove-failure) PROVE=1; shift ;;
        -h|--help)       sed -n '1,110p' "$SELF"; exit 0 ;;
        *) printf 'UNDETERMINED: unknown argument %s\n' "$1" >&2; exit 2 ;;
    esac
done

# DECLARED SCOPE. These are the trees that emit operator-facing remedies: the
# governance instruments at this root, the workshop control plane, the platform
# and its gates, the pipeline, and the operator documentation. `ai_interviewing/`
# and the two site submodules are OUT OF SCOPE — their `Fix:` lines are prose
# about software engineering in general, not remedies this platform emits — and
# that is a boundary, not a verdict on them.
if [ "${#SCANROOTS[@]}" -eq 0 ]; then
    SCANROOTS=(scripts tests workshop/scripts workshop/platform workshop/pipeline
               workshop/docs _tools _tests docs)
fi

command -v grep >/dev/null 2>&1 || { printf 'UNDETERMINED: no grep on PATH\n' >&2; exit 2; }
[ -d "$ROOT" ] || { printf 'UNDETERMINED: --root %s is not a directory\n' "$ROOT" >&2; exit 2; }

green() { printf '  \033[32m%-12s\033[0m %s\n' "$1" "$2"; }
redln() { printf '  \033[31m%-12s\033[0m %s\n' "$1" "$2"; }
yellow(){ printf '  \033[33m%-12s\033[0m %s\n' "$1" "$2"; }
grey()  { printf '  \033[90m%-12s\033[0m %s\n' "$1" "$2"; }

# ---------------------------------------------------------------------------
# discover_files — every scanned file. Vendored and generated trees are pruned:
# their remedies are not ours to repair, and counting an upstream's broken
# advice as this tree's finding is a claim with no remedy attached (which would
# be this gate committing its own defect).
# ---------------------------------------------------------------------------
discover_files() {
    local sr
    for sr in "${SCANROOTS[@]}"; do
        [ -d "$ROOT/$sr" ] || continue
        find "$ROOT/$sr" \
            \( -name '.git' -o -name 'node_modules' -o -name 'venv' -o -name 'vendor' \
               -o -name 'engines' -o -name 'models' -o -name 'dist' -o -name '_site' \
               -o -name '__pycache__' -o -name '.docspin.*' -o -name 'testdata' \
               -o -name 'coverage' -o -name '.specify' \) -prune -o \
            -type f \( -name '*.sh' -o -name '*.go' -o -name '*.py' -o -name '*.md' \
                       -o -name '*.json' -o -name '*.ts' -o -name '*.js' \) \
            ! -name '*.bak.*' -print 2>/dev/null
    done | sort -u
}

# ---------------------------------------------------------------------------
# extract — emit `file<TAB>line<TAB>payload` for every remedy-marked string.
#
# Two forms, both derived from what the tree writes:
#   A. structured   "remedy": "<payload>"      and   XxxRemedy = "<payload>"
#   B. line marker  Remedy: / Fix: / Run: / Try: / try:   <payload>
#
# Form B's marker must be at the head of its line (allowing indentation, a
# quote, a comment hash, a markdown bullet, a `>` or a `|`), which is what makes
# a Python `try:` — always payload-free — and a mid-sentence "fix:" not become
# candidates. A payload-free marker yields nothing and is not counted.
# ---------------------------------------------------------------------------
extract() {
    local f rel
    while IFS= read -r f; do
        [ -n "$f" ] || continue
        rel="${f#"$ROOT"/}"
        # A: structured key/const with a double-quoted value
        grep -nE '("remedy"|[A-Za-z_]*Remedy)[[:space:]]*[:=][[:space:]]*"[^"]+"' "$f" 2>/dev/null |
            sed -E 's/^([0-9]+):.*("remedy"|[A-Za-z_]*Remedy)[[:space:]]*[:=][[:space:]]*"([^"]+)".*/\1\t\3/' |
            while IFS=$'\t' read -r ln pay; do
                [ -n "${pay:-}" ] && printf '%s\t%s\t%s\n' "$rel" "$ln" "$pay"
            done
        # B: line-leading prose marker. Leading markdown emphasis is stripped
        # from the payload: `**Run:** \`git ...\`` leaves a payload beginning
        # `** ` whose head token is not a command, and a gate that read `**` as
        # the subject would classify a perfectly good remedy as prose.
        grep -nE '^[[:space:]]*["'"'"'#*>|\-]*[[:space:]]*(Remedy|REMEDY|Fix|FIX|Run|RUN|Try|TRY|try)[[:space:]]*:[[:space:]]*[^[:space:]]' "$f" 2>/dev/null |
            sed -E 's/^([0-9]+):[[:space:]]*["'"'"'#*>|\-]*[[:space:]]*(Remedy|REMEDY|Fix|FIX|Run|RUN|Try|TRY|try)[[:space:]]*:[[:space:]]*/\1\t/; s/\t[*_]+[[:space:]]*/\t/' |
            while IFS=$'\t' read -r ln pay; do
                [ -n "${pay:-}" ] && printf '%s\t%s\t%s\n' "$rel" "$ln" "$pay"
            done
    done < <(discover_files)
}

# ---------------------------------------------------------------------------
# subject_of <payload> — the first path-shaped token, or empty.
#
# Path-shaped: contains a `/`, and holds no placeholder or expansion. A token
# with `<`, `>`, `$`, `{`, `}`, `*`, `?`, `%` or a backtick is a HOLE the reader
# fills, not a path this gate may resolve.
# ---------------------------------------------------------------------------
subject_of() {
    local payload="$1" tok
    # shellcheck disable=SC2086
    for tok in $payload; do
        tok="${tok#\`}"; tok="${tok%%\`*}"
        tok="${tok%[.,;:)\"\']}"; tok="${tok#[(\"\']}"
        case "$tok" in
            */*) : ;;
            *)   continue ;;
        esac
        case "$tok" in
            *'<'*|*'>'*|*'$'*|*'{'*|*'}'*|*'*'*|*'?'*|*'%'*|*'`'*|*'|'*) continue ;;
            http://*|https://*|git@*) continue ;;
        esac
        printf '%s' "$tok"
        return 0
    done
    return 1
}

# head_of <payload> — the first token that is not an env assignment, `sudo`,
# `$`, or a backtick fence.
head_of() {
    local payload="$1" tok
    # shellcheck disable=SC2086
    for tok in $payload; do
        tok="${tok#\`}"; tok="${tok%\`}"
        case "$tok" in
            '$'|sudo|command|''|'#') continue ;;
            *=*) continue ;;
            *) printf '%s' "$tok"; return 0 ;;
        esac
    done
    return 1
}

# sum_of <path> — a 64-hex digest, or empty. `sha256sum` is GNU-only and this
# root has no `_portable.sh`; a proof that silently compared two EMPTY strings
# and printed "MATCHES" would be the bluff this whole gate is about, so the
# absence of every candidate is an rc-2 below, not a pass.
sum_of() {
    local out
    if command -v sha256sum >/dev/null 2>&1; then
        out="$(sha256sum -- "$1" 2>/dev/null | cut -d" " -f1)"
    elif command -v shasum >/dev/null 2>&1; then
        out="$(shasum -a 256 -- "$1" 2>/dev/null | cut -d" " -f1)"
    elif command -v openssl >/dev/null 2>&1; then
        out="$(openssl dgst -sha256 -r -- "$1" 2>/dev/null | cut -d" " -f1)"
    fi
    [ "${#out}" -eq 64 ] && printf '%s' "$out"
}

# resolves_as_command <token> — true when a SHELL would actually run it.
#
# `command -v` alone is not that test. Measured on this host: `command -v
# AGENTS.md` succeeds and prints a path, because a directory holding a markdown
# file is on this operator's PATH. A name that resolves to a non-executable file
# is not a command, so the resolved target must carry the executable bit; a
# builtin, function or keyword needs no file at all.
resolves_as_command() {
    local t="$1" kind p
    kind="$(type -t "$t" 2>/dev/null)" || return 1
    case "$kind" in
        builtin|function|keyword|alias) return 0 ;;
        file) ;;
        *) return 1 ;;
    esac
    p="$(command -v "$t" 2>/dev/null)" || return 1
    [ -x "$p" ] && [ ! -d "$p" ]
}

# reads_as_prose <payload> — true when the payload is an English sentence.
#
# APPLIED ONLY IN THE AMBIGUOUS BRANCH, and that restriction is the safety
# property. By the time this is consulted the remedy has already been shown to
# name NO path-shaped subject, so nothing this returns can reclassify a broken
# file remedy into a harmless bucket. It exists for one measured case:
#
#     "remedy": "install a working ffprobe or ffmpeg on the host that runs " …
#
# whose head token `install` is coreutils, so a head-resolves rule alone calls
# an operator instruction a command. The discriminator is that a shell command
# line does not carry bare English articles and prepositions as standalone
# words. The marker set is small, closed and stated; it is not a grammar.
reads_as_prose() {
    local tok
    # shellcheck disable=SC2086
    for tok in $1; do
        case "$tok" in
            a|an|the|to|of|on|in|for|your|their|please|ask|so|that|it|is|are|from|with)
                return 0 ;;
        esac
    done
    return 1
}

# interpreter_before <payload> <subject> — the token immediately preceding the
# subject, when it resolves on PATH. `bash foo.sh` does not need foo.sh to carry
# the executable bit; `foo.sh` on its own does.
interpreter_before() {
    local payload="$1" subject="$2" prev="" tok
    # shellcheck disable=SC2086
    for tok in $payload; do
        tok="${tok#\`}"; tok="${tok%%\`*}"
        if [ "$tok" = "$subject" ]; then
            [ -n "$prev" ] && resolves_as_command "$prev" && printf '%s' "$prev"
            return 0
        fi
        case "$tok" in ''|'$'|sudo|*=*) continue ;; esac
        prev="$tok"
    done
    return 0
}

# resolve_subject <subject> <emitting-file> — echo the resolved absolute path.
#
# Anchors are tried from the emitting file OUTWARD to the root, because a
# remedy written inside `workshop/` may spell a path from the module root while
# the same string served over HTTP spells it from the repository root. Both are
# correct; a gate that knew only one would invent findings.
resolve_subject() {
    local subject="$1" from="$2" dir cand
    case "$subject" in
        /*) [ -e "$subject" ] && { printf '%s' "$subject"; return 0; }; return 1 ;;
    esac
    dir="$ROOT/$(dirname -- "$from")"
    while :; do
        cand="$dir/${subject#./}"
        [ -e "$cand" ] && { printf '%s' "$cand"; return 0; }
        [ "$dir" = "$ROOT" ] && break
        [ "$dir" = "/" ] && break
        dir="$(dirname -- "$dir")"
        case "$dir" in "$ROOT"*) : ;; *) break ;; esac
    done
    [ -e "$ROOT/${subject#./}" ] && { printf '%s' "$ROOT/${subject#./}"; return 0; }
    return 1
}

# startable <path> <declared-interpreter> — echo a reason on failure.
#
# This is the half that separates "the file is there" from "the reader can run
# it". See the ffprobe measurement in the header.
startable() {
    local p="$1" interp="${2:-}" shebang first
    [ -f "$p" ] || { printf 'not a regular file'; return 1; }
    [ -r "$p" ] || { printf 'not readable'; return 1; }
    [ -s "$p" ] || { printf 'is empty'; return 1; }

    if [ -z "$interp" ]; then
        [ -x "$p" ] || { printf 'exists but is NOT executable and the remedy names no interpreter'; return 1; }
        first="$(head -c 2 "$p" 2>/dev/null)"
        if [ "$first" = '#!' ]; then
            shebang="$(head -n 1 "$p" 2>/dev/null)"
            shebang="${shebang#\#!}"
            shebang="${shebang# }"
            set -- $shebang
            if [ "${1:-}" = "/usr/bin/env" ]; then shift; fi
            if [ -n "${1:-}" ] && ! resolves_as_command "$1" && [ ! -x "${1:-}" ]; then
                printf 'shebang interpreter %s is not on PATH' "$1"
                return 1
            fi
            interp="${1:-}"
        fi
    else
        resolves_as_command "$interp" || {
            printf 'the remedy names interpreter %s, which is not on PATH' "$interp"
            return 1
        }
    fi

    # EXERCISE, not presence: ask the interpreter itself whether it can start
    # this file. A syntax-broken script that exists and is +x fails the reader
    # exactly as an absent one does.
    case "${interp##*/}:${p##*.}" in
        bash:*|sh:*|*:sh)
            if command -v bash >/dev/null 2>&1; then
                bash -n "$p" 2>/dev/null || { printf 'exists but does NOT parse (bash -n)'; return 1; }
            fi ;;
        python3:*|python:*|*:py)
            if command -v python3 >/dev/null 2>&1; then
                python3 -c 'import ast,sys; ast.parse(open(sys.argv[1],encoding="utf-8",errors="replace").read())' \
                    "$p" 2>/dev/null || { printf 'exists but does NOT parse (python3 ast)'; return 1; }
            fi ;;
    esac
    return 0
}

# ---------------------------------------------------------------------------
# --prove-failure: the §1.1 paired mutation for THIS gate.
#
# Built in a throwaway lab, never the real tree. The seeded remedy names a
# script that does not exist — the exact defect the accuracy endpoint shipped.
# Requirements: GREEN before, RED (rc 1, NOT 2) after, byte-identical restore
# proved by checksum, GREEN again, and the mutant must still PARSE.
#
# The seeded marker is assembled at run time from fragments so that the literal
# string never appears in THIS file. A gate whose own source contains a remedy
# naming a nonexistent script would report itself, permanently — and excluding
# itself from its own scan would be a suppression, which is worse.
# ---------------------------------------------------------------------------
if [ "$PROVE" -eq 1 ]; then
    printf '== prove-failure: this gate must be seen catching an unrunnable remedy ==\n\n'
    LAB="$(mktemp -d)" || { printf 'UNDETERMINED: cannot create a lab directory\n' >&2; exit 2; }
    trap 'rm -rf "$LAB"' EXIT
    mkdir -p "$LAB/scripts"

    printf '#!/usr/bin/env bash\nset -euo pipefail\necho "the remedy"\n' > "$LAB/scripts/present.sh"
    chmod +x "$LAB/scripts/present.sh"

    M="R"; M="${M}emedy"        # assembled, never literal — see above
    {
        printf '#!/usr/bin/env bash\n'
        printf 'set -euo pipefail\n'
        printf '# %s: bash scripts/present.sh --now\n' "$M"
        printf 'echo subject\n'
    } > "$LAB/scripts/subject.sh"
    chmod +x "$LAB/scripts/subject.sh"
    SUM_BEFORE="$(sum_of "$LAB/scripts/subject.sh")"
    [ -n "$SUM_BEFORE" ] || { printf 'UNDETERMINED: no sha256 tool, so a\n' >&2; printf 'byte-identical restore cannot be PROVED and will not be claimed.\n' >&2; exit 2; }

    printf -- '--- GREEN: the remedy names a script that exists and starts ---\n'
    bash "$SELF" --root "$LAB" --scanroot scripts >"$LAB/g.out" 2>&1; G=$?
    sed 's/^/    | /' "$LAB/g.out" | tail -6
    printf '    rc=%s (expected 0)\n\n' "$G"

    printf -- '--- RED: repoint the remedy at a script that does not exist ---\n'
    {
        printf '#!/usr/bin/env bash\n'
        printf 'set -euo pipefail\n'
        printf '# %s: bash scripts/verify-nothing-at-all.sh --now\n' "$M"
        printf 'echo subject\n'
    } > "$LAB/scripts/subject.sh"
    if bash -n "$LAB/scripts/subject.sh" 2>/dev/null; then
        printf '    the mutant still PARSES (bash -n): this proof measures the remedy,\n'
        printf '    not a syntax break\n'
    else
        printf 'UNDETERMINED: the seeded mutant does not parse; this proves nothing\n' >&2
        exit 2
    fi
    bash "$SELF" --root "$LAB" --scanroot scripts >"$LAB/r.out" 2>&1; R=$?
    sed 's/^/    | /' "$LAB/r.out" | tail -10
    printf '    rc=%s (expected 1 — a real finding, NOT 2)\n\n' "$R"

    printf -- '--- restore, byte-identically ---\n'
    {
        printf '#!/usr/bin/env bash\n'
        printf 'set -euo pipefail\n'
        printf '# %s: bash scripts/present.sh --now\n' "$M"
        printf 'echo subject\n'
    } > "$LAB/scripts/subject.sh"
    SUM_AFTER="$(sum_of "$LAB/scripts/subject.sh")"
    bash "$SELF" --root "$LAB" --scanroot scripts >"$LAB/g2.out" 2>&1; G2=$?
    printf '    rc=%s (expected 0)   subject sha256 %s\n\n' "$G2" \
        "$( [ "$SUM_AFTER" = "$SUM_BEFORE" ] && echo 'MATCHES the original' || echo 'DIFFERS — restore failed' )"

    printf -- '--- a SECOND, independent mutation: present but not startable ---\n'
    printf '    (a remedy can be broken without the file being missing; a gate that\n'
    printf '     only catches absence would pass this one)\n'
    printf '#!/usr/bin/env bash\nif then fi done\n' > "$LAB/scripts/present.sh"
    bash "$SELF" --root "$LAB" --scanroot scripts >"$LAB/r2.out" 2>&1; R2=$?
    sed 's/^/    | /' "$LAB/r2.out" | grep -E 'UNSTARTABLE|MISSING|===' | head -4
    printf '    rc=%s (expected 1)\n\n' "$R2"
    printf '#!/usr/bin/env bash\nset -euo pipefail\necho "the remedy"\n' > "$LAB/scripts/present.sh"

    printf -- '--- an INSTRUCTION must not be a finding ---\n'
    {
        printf '#!/usr/bin/env bash\n'
        printf '# %s: ask your administrator to install podman\n' "$M"
        printf 'echo instruction\n'
    } > "$LAB/scripts/instruction.sh"
    chmod +x "$LAB/scripts/instruction.sh"
    bash "$SELF" --root "$LAB" --scanroot scripts --verbose >"$LAB/i.out" 2>&1; I=$?
    grep -E 'INSTRUCTION' "$LAB/i.out" | sed 's/^/    | /' | head -2
    grep -qE 'INSTRUCTION' "$LAB/i.out" || {
        printf 'UNDETERMINED: the instruction was not classified as one, so this\n' >&2
        printf 'case proves nothing about the command/instruction split.\n' >&2
        exit 2
    }
    printf '    rc=%s (expected 0)\n\n' "$I"

    printf -- '--- an EMPTY scan is 2, never 0 ---\n'
    mkdir -p "$LAB/empty/scripts"
    bash "$SELF" --root "$LAB/empty" --scanroot scripts >"$LAB/e.out" 2>&1; E=$?
    sed 's/^/    | /' "$LAB/e.out" | tail -3
    printf '    rc=%s (expected 2)\n\n' "$E"

    F=0
    [ "$G"  -eq 0 ] || { printf 'PROBLEM: a resolvable remedy did not yield 0 (got %s)\n' "$G"  >&2; F=1; }
    [ "$R"  -eq 1 ] || { printf 'PROBLEM: an absent remedy subject did not yield 1 (got %s)\n' "$R" >&2; F=1; }
    [ "$G2" -eq 0 ] || { printf 'PROBLEM: the restored tree did not yield 0 (got %s)\n' "$G2" >&2; F=1; }
    [ "$R2" -eq 1 ] || { printf 'PROBLEM: a present-but-unparsable subject did not yield 1 (got %s)\n' "$R2" >&2; F=1; }
    [ "$I"  -eq 0 ] || { printf 'PROBLEM: an operator INSTRUCTION was treated as a defect (got %s)\n' "$I" >&2; F=1; }
    [ "$E"  -eq 2 ] || { printf 'PROBLEM: an empty scan did not yield 2 (got %s)\n' "$E" >&2; F=1; }
    [ "$SUM_AFTER" = "$SUM_BEFORE" ] || { printf 'PROBLEM: the subject was not restored byte-identically\n' >&2; F=1; }
    if [ "$F" -ne 0 ]; then
        printf '\nPROBLEM: this gate does not grade what it claims to.\n' >&2
        exit 1
    fi
    printf 'OK: an absent remedy was CAUGHT (1), a present-but-unstartable one was\n'
    printf 'CAUGHT (1), an instruction was NOT a finding (0), an empty scan was 2, the\n'
    printf 'mutants parsed, and the subject was restored byte-identically.\n'
    exit 0
fi

# ---------------------------------------------------------------------------
printf '== remedy executability ==\n'
printf 'root:      %s\n' "$ROOT"
printf 'scanroots: %s\n' "${SCANROOTS[*]}"

MISSING_SR=""
for sr in "${SCANROOTS[@]}"; do
    [ -d "$ROOT/$sr" ] || MISSING_SR="$MISSING_SR $sr"
done
if [ -n "$MISSING_SR" ]; then
    printf '\nUNDETERMINED: declared scanroot(s) do not exist:%s\n' "$MISSING_SR" >&2
    printf 'A gate that skipped part of its own scope has not reported a clean tree.\n' >&2
    exit 2
fi
printf '\n'

TOTAL=0; RESOLVED=0; BROKEN=0; INSTRUCTION=0; EXTERNAL=0; UNCLASSIFIED=0
BROKEN_LINES=""; EXTERNAL_LINES=""; UNCLASS_LINES=""

while IFS=$'\t' read -r file line payload; do
    [ -n "${payload:-}" ] || continue
    TOTAL=$((TOTAL+1))
    where="$file:$line"

    subject="$(subject_of "$payload")" || subject=""
    if [ -n "$subject" ]; then
        interp="$(interpreter_before "$payload" "$subject")"
        if path="$(resolve_subject "$subject" "$file")"; then
            if why="$(startable "$path" "$interp")"; then
                RESOLVED=$((RESOLVED+1))
                [ "$VERBOSE" -eq 1 ] && green "RESOLVES" "$where -> ${path#"$ROOT"/}"
            else
                BROKEN=$((BROKEN+1))
                redln "UNSTARTABLE" "$where"
                printf '               | remedy:  %s\n' "$payload"
                printf '               | subject: %s — %s\n' "${path#"$ROOT"/}" "$why"
                BROKEN_LINES="$BROKEN_LINES  $where  ($subject: $why)"$'\n'
            fi
        else
            BROKEN=$((BROKEN+1))
            redln "MISSING" "$where"
            printf '               | remedy:  %s\n' "$payload"
            printf '               | subject: %s — resolves nowhere from %s up to the root\n' \
                   "$subject" "$(dirname -- "$file")"
            BROKEN_LINES="$BROKEN_LINES  $where  ($subject: absent)"$'\n'
        fi
        continue
    fi

    head="$(head_of "$payload")" || head=""
    if [ -n "$head" ] && resolves_as_command "$head" && ! reads_as_prose "$payload"; then
        EXTERNAL=$((EXTERNAL+1))
        [ "$VERBOSE" -eq 1 ] && yellow "EXTERNAL" "$where -> $head (exists; operation not exercised)"
        EXTERNAL_LINES="$EXTERNAL_LINES  $where  ($head)"$'\n'
        continue
    fi

    # No shell-startable subject at all. That is an operator INSTRUCTION — or
    # prose that merely matched a marker. Either way there is nothing here for
    # this gate to resolve, and inventing a verdict would be the bluff.
    INSTRUCTION=$((INSTRUCTION+1))
    [ "$VERBOSE" -eq 1 ] && grey "INSTRUCTION" "$where — $payload"
done < <(extract)

printf '=== %d remedy string(s): %d resolve / %d BROKEN / %d external / %d instruction ===\n' \
       "$TOTAL" "$RESOLVED" "$BROKEN" "$EXTERNAL" "$INSTRUCTION"

if [ "$TOTAL" -eq 0 ]; then
    printf '\nUNDETERMINED: not one remedy string was found under %s.\n' "${SCANROOTS[*]}" >&2
    printf 'A gate that matched nothing has not reported a clean tree; it has failed to\n' >&2
    printf 'run. Check the scanroots and the extraction patterns before believing this.\n' >&2
    exit 2
fi

if [ "$EXTERNAL" -gt 0 ]; then
    printf '\n'
    printf '\033[33m┌─ NOTE — %d REMEDY(S) NAME AN EXTERNAL COMMAND ──────────────\033[0m\n' "$EXTERNAL"
    printf '\033[33m│\033[0m Their head token EXISTS on PATH. Whether it can do the thing the\n'
    printf '\033[33m│\033[0m remedy names is NOT KNOWN from here: this gate does not execute\n'
    printf '\033[33m│\033[0m discovered strings, because the corpus contains `git push`, and\n'
    printf '\033[33m│\033[0m this tree contains a deploy script that fired at two live\n'
    printf '\033[33m│\033[0m production sites when it was run by accident.\n'
    printf '\033[33m│\033[0m Measured trap on this host: `ffprobe -version` exits 0 while\n'
    printf '\033[33m│\033[0m `ffprobe -show_format` exits 8. Presence is not capability.\n'
    printf '\033[33m│\033[0m This is a stated limit, not a pass. --strict makes it rc 2.\n'
    if [ "$VERBOSE" -eq 1 ]; then
        printf '\033[33m│\033[0m\n'
        printf '%s' "$EXTERNAL_LINES" | sed 's/^/\o033[33m│\o033[0m/'
    fi
    printf '\033[33m└────────────────────────────────────────────────────────────\033[0m\n'
fi

if [ "$BROKEN" -gt 0 ]; then
    printf '\n'
    printf '\033[31m┌─ BROKEN — %d REMEDY(S) CANNOT BE FOLLOWED ──────────────────\033[0m\n' "$BROKEN"
    printf '\033[31m│\033[0m Each names a file a reader is told to run, and that file is\n'
    printf '\033[31m│\033[0m absent or cannot be started. Under 11.4.6 a remedy naming a\n'
    printf '\033[31m│\033[0m nonexistent script is a bluff: it asserts a path to resolution\n'
    printf '\033[31m│\033[0m that does not exist, and the reader cannot tell without trying.\n'
    printf '\033[31m│\033[0m\n'
    printf '%s' "$BROKEN_LINES" | sed 's/^/\o033[31m│\o033[0m/'
    printf '\033[31m│\033[0m\n'
    printf '\033[31m│\033[0m Two honest repairs: build the thing the remedy names, or change\n'
    printf '\033[31m│\033[0m the remedy to name something that exists. Deleting the remedy\n'
    printf '\033[31m│\033[0m is a third and it is worse — a state with no way out, unstated.\n'
    printf '\033[31m└────────────────────────────────────────────────────────────\033[0m\n'
fi

# A CONFIRMED FAILURE OUTRANKS AN UNDETERMINED.
[ "$BROKEN" -gt 0 ] && exit 1
[ "$UNCLASSIFIED" -gt 0 ] && exit 2
if [ "$STRICT" -eq 1 ] && [ "$EXTERNAL" -gt 0 ]; then
    printf '\n--strict: %d remedy(s) name an external command whose operation was NOT\n' "$EXTERNAL" >&2
    printf 'exercised — could not determine, which is not a pass.\n' >&2
    exit 2
fi
if [ "$RESOLVED" -eq 0 ] && [ "$EXTERNAL" -eq 0 ]; then
    printf '\nUNDETERMINED: not one remedy named anything resolvable, so nothing was\n' >&2
    printf 'actually verified. %d string(s) were classified as instructions.\n' "$INSTRUCTION" >&2
    exit 2
fi
exit 0
