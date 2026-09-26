#!/usr/bin/env bash
# xargs-in-assignment.sh — scratch fixture: the command substitution itself opens every tracked file.
sizes=$(git ls-files | xargs stat -c '%s %n')
echo "$sizes" | sort -n | tail -1
