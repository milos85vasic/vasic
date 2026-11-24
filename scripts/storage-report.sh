#!/usr/bin/env bash
# storage-report.sh — READ-ONLY storage-policy report (docs/storage-policy.md).
#
# Reports root-filesystem free space and per-consumer sizes, and FAILS when the
# root filesystem is fuller than the threshold OR when a known heavy consumer
# (podman graphroot, language/package caches, model stores) still resolves to
# the root filesystem instead of the data drives.
#
# Exit codes (three-valued; 2 is never a pass):
#   0  root usage within threshold AND every present heavy consumer is off-root
#   1  a real finding: usage above threshold, or a heavy consumer is on root
#   2  could not determine (df failed, --root-path missing, bad argument)
#
#   scripts/storage-report.sh [--threshold PCT] [--root-path DIR] [--home DIR]
#                             [--no-sizes] [--prove-failure]
#
#   --threshold PCT   fail when used% of --root-path's filesystem exceeds PCT
#                     (default 90)
#   --root-path DIR   the filesystem treated as "root" (default /)
#   --home DIR        home directory whose consumers are checked (default $HOME)
#   --no-sizes        skip the (slow) du size column
#   --prove-failure   paired mutation proof: runs this script against synthetic
#                     homes and requires rc 1 for each seeded violation, rc 0 for
#                     the control and rc 2 for the could-not-determine probe.
#
# It never writes, moves or deletes anything.
set -uo pipefail

SELF="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/$(basename -- "${BASH_SOURCE[0]}")"
THRESHOLD=90
ROOT_PATH=/
HOME_DIR="${HOME:-}"
SIZES=1
PROVE=0

while [ $# -gt 0 ]; do
  case "$1" in
    --threshold)  THRESHOLD="${2:-}"; shift 2 ;;
    --root-path)  ROOT_PATH="${2:-}"; shift 2 ;;
    --home)       HOME_DIR="${2:-}"; shift 2 ;;
    --no-sizes)   SIZES=0; shift ;;
    --prove-failure) PROVE=1; shift ;;
    -h|--help)    sed -n 2,28p "$SELF"; exit 0 ;;
    *) echo "storage-report: unknown argument: $1" >&2; exit 2 ;;
  esac
done

# Heavy consumers, relative to the home directory. Keep in sync with
# docs/storage-policy.md (section "Which path holds what").
CONSUMERS=(
  ".local/share/containers/storage"
  ".local/share/llmctl/models"
  "go/pkg/mod"
  ".npm"
  ".gradle"
  ".m2"
  ".local/share/swift"
  ".local/share/clangd"
  ".local/share/kotlin-lsp"
)

if [ "$PROVE" -eq 1 ]; then
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/storage-report-prove.XXXXXX")" || exit 2
  trap 'rm -rf "$tmp"' EXIT
  fail=0; pass=0
  expect() { # name want_rc got_rc
    if [ "$2" = "$3" ]; then pass=$((pass+1)); echo "  PASS $1 (rc $3)"
    else fail=$((fail+1)); echo "  FAIL $1 (want rc $2, got rc $3)"; fi
  }
  # Another device is needed for the "off-root" control; /dev/shm is tmpfs.
  off=/dev/shm
  if [ ! -d "$off" ] || [ "$(stat -c %d "$off")" = "$(stat -c %d "$tmp")" ]; then
    echo "storage-report: no second filesystem available for the proof" >&2; exit 2
  fi
  offd="$(mktemp -d "$off/storage-report-prove.XXXXXX")" || exit 2
  trap 'rm -rf "$tmp" "$offd"' EXIT
  mk_home() { # dir  mode(onroot|offroot)
    local h="$1" m="$2" c
    for c in "${CONSUMERS[@]}"; do
      mkdir -p "$(dirname "$h/$c")"
      if [ "$m" = offroot ]; then mkdir -p "$offd/$(echo "$c" | tr / _)"; ln -s "$offd/$(echo "$c" | tr / _)" "$h/$c"
      else mkdir -p "$h/$c"; fi
    done
  }
  # "root" for the proof is the temp dir's own filesystem; threshold 100 so the
  # usage arm never interferes with the placement arms.
  mk_home "$tmp/ctl" offroot
  bash "$SELF" --home "$tmp/ctl" --root-path "$tmp" --threshold 100 --no-sizes >/dev/null 2>&1
  expect "control: all consumers off-root" 0 $?
  mk_home "$tmp/bad" onroot
  bash "$SELF" --home "$tmp/bad" --root-path "$tmp" --threshold 100 --no-sizes >/dev/null 2>&1
  expect "mutation: every consumer on root" 1 $?
  mk_home "$tmp/one" offroot
  rm "$tmp/one/.local/share/containers/storage"; mkdir -p "$tmp/one/.local/share/containers/storage"
  bash "$SELF" --home "$tmp/one" --root-path "$tmp" --threshold 100 --no-sizes >/dev/null 2>&1
  expect "mutation: only podman graphroot on root" 1 $?
  bash "$SELF" --home "$tmp/ctl" --root-path "$tmp" --threshold -1 --no-sizes >/dev/null 2>&1
  expect "mutation: usage above threshold" 1 $?
  bash "$SELF" --home "$tmp/ctl" --root-path /nonexistent --no-sizes >/dev/null 2>&1
  expect "undetermined: root path missing" 2 $?
  echo "storage-report --prove-failure: $pass passed, $fail failed"
  [ "$fail" -eq 0 ] && exit 0 || exit 1
fi

case "$THRESHOLD" in ''|*[!0-9-]*) echo "storage-report: --threshold must be an integer" >&2; exit 2 ;; esac
[ -d "$ROOT_PATH" ] || { echo "UNDETERMINED: root path $ROOT_PATH is not a directory" >&2; exit 2; }
[ -d "$HOME_DIR" ] || { echo "UNDETERMINED: home $HOME_DIR is not a directory" >&2; exit 2; }

line="$(df -Pk "$ROOT_PATH" 2>/dev/null | awk 'NR==2')"
[ -n "$line" ] || { echo "UNDETERMINED: df failed for $ROOT_PATH" >&2; exit 2; }
total_k="$(echo "$line" | awk '{print $2}')"; used_k="$(echo "$line" | awk '{print $3}')"
avail_k="$(echo "$line" | awk '{print $4}')"; pct="$(echo "$line" | awk '{gsub("%","",$5); print $5}')"
root_dev="$(stat -c %d "$ROOT_PATH" 2>/dev/null)" || { echo "UNDETERMINED: stat failed" >&2; exit 2; }

echo "storage-report: root filesystem of $ROOT_PATH"
printf '  size %s MiB, used %s MiB, free %s MiB, used%% %s (threshold %s)\n' \
  "$((total_k/1024))" "$((used_k/1024))" "$((avail_k/1024))" "$pct" "$THRESHOLD"

rc=0
if [ "$pct" -gt "$THRESHOLD" ]; then
  echo "  FINDING: root usage ${pct}% exceeds threshold ${THRESHOLD}%"; rc=1
fi

echo "consumers (relative to $HOME_DIR):"
for c in "${CONSUMERS[@]}"; do
  p="$HOME_DIR/$c"
  if [ ! -e "$p" ]; then printf '  %-36s absent (not a consumer on this host)\n' "$c"; continue; fi
  real="$(readlink -f "$p" 2>/dev/null)"
  dev="$(stat -c %d "$real" 2>/dev/null)"
  if [ -z "$real" ] || [ -z "$dev" ]; then printf '  %-36s UNDETERMINED (cannot resolve)\n' "$c"; [ "$rc" -eq 0 ] && rc=2; continue; fi
  size="-"
  if [ "$SIZES" -eq 1 ]; then
    size="$(timeout 90 du -xsk "$real" 2>/dev/null | awk '{printf "%d MiB", $1/1024}')"; [ -n "$size" ] || size="? (du timeout/denied)"
  fi
  if [ "$dev" = "$root_dev" ]; then
    printf '  %-36s ON ROOT   -> %s  [%s]\n' "$c" "$real" "$size"
    echo "  FINDING: $c resolves to the root filesystem"; rc=1
  else
    printf '  %-36s off-root  -> %s  [%s]\n' "$c" "$real" "$size"
  fi
done

case "$rc" in
  0) echo "storage-report: OK" ;;
  1) echo "storage-report: FINDING(S) — see docs/storage-policy.md" ;;
  *) echo "storage-report: UNDETERMINED (not a pass)" ;;
esac
exit "$rc"
