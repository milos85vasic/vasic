#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Fail the build on machine-specific absolute paths.
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
#   ./scripts/audit-hardcoded-paths.sh              # audit this repo
#   ./scripts/audit-hardcoded-paths.sh /path/to/repo # audit another checkout
#   ./scripts/audit-hardcoded-paths.sh --list        # show what is scanned
#
# Comment-only lines are ignored: documenting the historical bug is not the bug.
# Genuine exceptions go in .hardcoded-paths-allow as `path/to/file` with a
# reason on the preceding `#` line — anything else is a failure.
# ------------------------------------------------------------------------------
set -uo pipefail

# Target defaults to this script's own repository, but accepts an explicit
# directory so the audit can be pointed at any checkout - and so its own tests
# can exercise it against throwaway repos instead of the live tree.
TARGET="${1:-}"
case "$TARGET" in --list|--help|-h) TARGET="" ;; esac
if [[ -n "$TARGET" ]]; then
    ROOT="$(cd -- "$TARGET" && pwd)" || { echo "FATAL: no such directory '$TARGET'" >&2; exit 2; }
    shift
else
    ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
fi
cd "$ROOT" || { echo "FATAL: cannot cd to '$ROOT'" >&2; exit 1; }

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
ALLOW_FILE="$ROOT/.hardcoded-paths-allow"

# Machine-specific roots. NOT included: /etc, /usr, /opt, /var, /tmp — those are
# standard system locations, not somebody's home directory.
PATTERN='(/Volumes/|/Users/[A-Za-z]|/home/[A-Za-z][A-Za-z0-9_.-]*/|/run/media/[A-Za-z]|/mnt/[A-Za-z][A-Za-z0-9_.-]*/)'

# Prose legitimately quotes real paths; generated evidence is not source.
SKIP='^(docs/|_content|_analysis|_tests/evidence/|\.test-evidence/|\.superpowers/|\.ashlrcode/|MANUAL-STEPS\.md)'

is_allowed() {
    [[ -f "$ALLOW_FILE" ]] || return 1
    grep -vE '^\s*(#|$)' "$ALLOW_FILE" 2>/dev/null | grep -qxF "$1"
}

# Strip comment-only lines per language so a comment explaining this very bug
# does not trip the audit that exists because of it.
strip_comments() {
    case "$1" in
        *.py|*.sh|*.bash|*.yml|*.yaml|*.toml|*.cfg|*.conf) grep -vE '^[[:space:]]*#' ;;
        *.js|*.mjs|*.cjs|*.ts|*.go|*.java|*.c|*.h)         grep -vE '^[[:space:]]*(//|\*|/\*)' ;;
        *)                                                  cat ;;
    esac
}

if [[ "${1:-}" == "--list" ]]; then
    git ls-files | grep -vE "$SKIP" | head -50
    exit 0
fi

violations=0; files_hit=0; allowed=0
while IFS= read -r f; do
    [[ -f "$f" ]] || continue
    case "$f" in *.png|*.jpg|*.jpeg|*.pdf|*.ico|*.woff|*.woff2|*.ttf|*.zip|*.gz) continue;; esac
    hits=$(strip_comments "$f" < "$f" | grep -nE "$PATTERN" 2>/dev/null)
    [[ -z "$hits" ]] && continue
    if is_allowed "$f"; then
        allowed=$((allowed+1))
        printf "${YELLOW}⚠️  allowed${NC} %s\n" "$f"
        continue
    fi
    files_hit=$((files_hit+1))
    n=$(printf '%s\n' "$hits" | wc -l)
    violations=$((violations+n))
    printf "${RED}❌ %s${NC}  (%s occurrence(s))\n" "$f" "$n"
    printf '%s\n' "$hits" | head -3 | sed 's/^/     /'
done < <(git ls-files | grep -vE "$SKIP")

echo "────────────────────────────────────────────────────────"
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
echo "If an occurrence is genuinely unavoidable, add the file to"
echo "  .hardcoded-paths-allow   (with a '#' reason line above it)"
exit 1
