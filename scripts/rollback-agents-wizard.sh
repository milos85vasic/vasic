#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Rollback for scripts/setup-agents-wizard.sh
#
# The wizard records every mutation in a per-run manifest under
#   ~/.local/share/setup-agents-wizard/backups/<UTC timestamp>/manifest.tsv
# This script replays that manifest in reverse.
#
#   MODIFIED -> restore the byte-exact original (mode preserved)
#   CREATED  -> delete the file the wizard created
#   ACTION   -> a non-file change; its undo command is printed, and executed
#               only with --run-actions
#
# Rolling back is itself reversible: whatever is on disk now is copied into a
# pre-rollback snapshot before anything is touched, so no state is ever lost.
#
#   ./scripts/rollback-agents-wizard.sh --list
#   ./scripts/rollback-agents-wizard.sh --dry-run
#   ./scripts/rollback-agents-wizard.sh --component lumen --component shell
#   ./scripts/rollback-agents-wizard.sh --session 20260826T210000Z --yes
# ------------------------------------------------------------------------------
set -uo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'
print_header()  { echo -e "\n${CYAN}========================================${NC}\n${CYAN} $1${NC}\n${CYAN}========================================${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_error()   { echo -e "${RED}❌ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_info()    { echo -e "${BLUE}ℹ️  $1${NC}"; }

WIZARD_STATE_DIR="${WIZARD_STATE_DIR:-$HOME/.local/share/setup-agents-wizard}"
BACKUP_ROOT="$WIZARD_STATE_DIR/backups"

SESSION=""; DRY_RUN=0; ASSUME_YES=0; RUN_ACTIONS=0; COMPONENTS=()

usage() { sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//'; exit 0; }

while [[ $# -gt 0 ]]; do
    case "$1" in
        --list)        LIST_ONLY=1; shift ;;
        --session)     SESSION="${2:-}"; shift 2 ;;
        --component|-c) COMPONENTS+=("${2:-}"); shift 2 ;;
        --dry-run|-n)  DRY_RUN=1; shift ;;
        --yes|-y)      ASSUME_YES=1; shift ;;
        --run-actions) RUN_ACTIONS=1; shift ;;
        --help|-h)     usage ;;
        *) print_error "Unknown option: $1"; exit 2 ;;
    esac
done

if [[ ! -d "$BACKUP_ROOT" ]]; then
    print_error "No backup sessions found at $BACKUP_ROOT"
    print_info "The wizard creates one every time it runs."
    exit 1
fi

list_sessions() {
    print_header "Backup sessions"
    local found=0
    for d in "$BACKUP_ROOT"/*/; do
        # `latest` is a symlink to one of the real session dirs; globbing it
        # would list that session twice.
        [[ -L "${d%/}" ]] && continue
        [[ -f "$d/manifest.tsv" ]] || continue
        found=1
        local id n comps
        id=$(basename "$d")
        n=$(( $(wc -l < "$d/manifest.tsv") - 1 ))
        comps=$(awk -F'\t' 'NR>1{print $1}' "$d/manifest.tsv" | sort -u | tr '\n' ' ')
        printf "  %-20s %3s changes   components: %s\n" "$id" "$n" "$comps"
    done
    [[ $found -eq 1 ]] || print_warning "No sessions with a manifest yet."
}

if [[ -n "${LIST_ONLY:-}" ]]; then list_sessions; exit 0; fi

# Resolve the session (default: newest).
if [[ -z "$SESSION" || "$SESSION" == "latest" ]]; then
    SESSION=$(ls -1d "$BACKUP_ROOT"/*/ 2>/dev/null | grep -v '/latest/$' | sort | tail -1)
    SESSION=${SESSION%/}
else
    SESSION="$BACKUP_ROOT/$SESSION"
fi
MANIFEST="$SESSION/manifest.tsv"
if [[ ! -f "$MANIFEST" ]]; then
    print_error "No manifest at $MANIFEST"; list_sessions; exit 1
fi

wanted() {
    [[ ${#COMPONENTS[@]} -eq 0 ]] && return 0
    local c
    for c in "${COMPONENTS[@]}"; do
        [[ "$c" == "all" || "$c" == "$1" ]] && return 0
    done
    return 1
}

print_header "Rollback plan"
print_info "Session   : $(basename "$SESSION")"
print_info "Components: ${COMPONENTS[*]:-all}"
[[ $DRY_RUN -eq 1 ]] && print_warning "DRY RUN - nothing will be changed."

# ---- Plan ----
planned=0
while IFS=$'\t' read -r component action target backup sha ts; do
    [[ "$component" == "component" ]] && continue
    wanted "$component" || continue
    case "$action" in
        MODIFIED) echo "  restore  [$component] $target"; planned=$((planned+1)) ;;
        CREATED)  echo "  delete   [$component] $target"; planned=$((planned+1)) ;;
        ACTION)   if [[ $RUN_ACTIONS -eq 1 ]]; then echo "  run      [$component] $target"
                  else echo "  manual   [$component] $target   (use --run-actions to execute)"; fi
                  planned=$((planned+1)) ;;
    esac
done < "$MANIFEST"

if [[ $planned -eq 0 ]]; then print_warning "Nothing to roll back for the selected components."; exit 0; fi
[[ $DRY_RUN -eq 1 ]] && exit 0

if [[ $ASSUME_YES -ne 1 ]]; then
    echo
    read -r -p "Apply this rollback? [y/N] " reply
    [[ "$reply" =~ ^[Yy]$ ]] || { print_warning "Aborted - nothing changed."; exit 0; }
fi

# ---- Pre-rollback snapshot, so the rollback itself is reversible ----
PRE="$SESSION/pre-rollback-$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$PRE"
print_info "Current state is being saved to $PRE"

print_header "Applying rollback"
ok=0; failed=0
while IFS=$'\t' read -r component action target backup sha ts; do
    [[ "$component" == "component" ]] && continue
    wanted "$component" || continue
    case "$action" in
        MODIFIED)
            if [[ ! -f "$backup" ]]; then
                print_error "Backup missing for $target ($backup)"; failed=$((failed+1)); continue
            fi
            [[ -e "$target" ]] && cp -p "$target" "$PRE/$(printf '%s' "$target" | sha256sum | cut -c1-16)__$(basename "$target")" 2>/dev/null
            if cp -p "$backup" "$target"; then
                print_success "restored [$component] $target"; ok=$((ok+1))
            else
                print_error "failed to restore $target"; failed=$((failed+1))
            fi ;;
        CREATED)
            if [[ -e "$target" ]]; then
                cp -p "$target" "$PRE/$(printf '%s' "$target" | sha256sum | cut -c1-16)__$(basename "$target")" 2>/dev/null
                if rm -f "$target"; then print_success "deleted  [$component] $target"; ok=$((ok+1))
                else print_error "failed to delete $target"; failed=$((failed+1)); fi
            else
                print_info "already absent [$component] $target"; ok=$((ok+1))
            fi ;;
        ACTION)
            if [[ $RUN_ACTIONS -eq 1 ]]; then
                if eval "$target" >/dev/null 2>&1; then print_success "ran      [$component] $target"; ok=$((ok+1))
                else print_warning "undo command failed (may already be undone): $target"; fi
            else
                print_info "manual   [$component] $target"
            fi ;;
    esac
done < "$MANIFEST"

print_header "Rollback complete"
print_info "restored/removed: $ok    failures: $failed"
print_info "Pre-rollback state kept at: $PRE"
[[ $failed -eq 0 ]] || print_warning "Some entries failed - inspect $MANIFEST"
echo
print_info "Open a new shell for PATH changes to take effect."
[[ $failed -eq 0 ]] && exit 0 || exit 1
