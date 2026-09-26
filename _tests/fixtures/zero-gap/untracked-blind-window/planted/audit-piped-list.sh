#!/usr/bin/env bash
# audit-piped-list.sh — scratch fixture: lists candidate files for a content audit.
SKIP='^vendor/'
list_files() {
    git -C "$1" ls-files -z 2>/dev/null | tr '\0' '\n' | grep -vE "$SKIP"
}
list_files "${1:-.}" | xargs -r grep -l 'password' -- 
