#!/usr/bin/env bash
# scripts/zero-gap-third-party-guard.sh — third-party edit guard for the push path
# (feature 010, task T041; FR-021).
#
# WHAT IT REFUSES. A diff (BASE..HEAD, committed content) that modifies third-party code. The project does
# not own third-party gitlinks; a gap inside one is registered and classified, never edited (FR-021). The
# diff is read with `git diff --raw`, and for every PROTECTED gitlink path P:
#   FINDING THIRD-PARTY EDIT       any entry at or under P other than a pure gitlink pointer move: a file
#                                  path under P/, a gitlink removed, or a gitlink replaced by files
#                                  (type change). No data row can permit these.
#   FINDING THIRD-PARTY GITLINK BUMP   P stays a gitlink (160000 -> 160000) and its commit changed, while
#                                  the data row's gitlink_bump column is `refuse` (the default for a path
#                                  with no row). A row saying `allow` records a standing operator decision
#                                  that pointer moves are permitted (see the tsv's evidence column); the
#                                  bump is then printed as NOTE, not hidden.
# A gitlink ADDED where base had none is not an edit of third-party code (it is adopting one) and is only
# checked for classification data (below).
#
# CLASSIFICATION DATA — docs/zero-gap/third-party.tsv (tracked, TAB-separated, header first):
#   path  classification  gitlink_bump  evidence
# It is DERIVED, not a roster: `--derive` recomputes it from .gitmodules and helix-deps.yaml with the same
# rule as scripts/verify-governance-cascade.sh C1 and scripts/zero-gap-class-doc-count-drift.sh — a
# declared submodule is OWNED when its URL namespace (host/owner) hosts >= 2 declared submodules or is the
# namespace of a helix-deps.yaml ssh_url; the governance source is the checked-out submodule carrying
# scripts/gates/lib/pointer_carrier.sh; everything else is third-party. At run time the protected set is
#   (rows of the tsv) UNION (paths derived from BASE's .gitmodules) UNION (paths derived from HEAD's),
# so a diff that edits .gitmodules to reclassify a path in the same push does not escape. A path that is
# derived third-party but has NO tsv row is itself a FINDING (stale classification data: fix the tsv, with
# `--derive`, in the same push) and defaults to `refuse`.
#
# USAGE
#   bash scripts/zero-gap-third-party-guard.sh [--root DIR] [--base REF] [--head REF]
#   bash scripts/zero-gap-third-party-guard.sh --derive [--root DIR] [--ref REF]   # print proposed rows
#   bash scripts/zero-gap-third-party-guard.sh --prove-failure
# With no --base: merge-base(HEAD, @{upstream} | origin/main | github/main)..HEAD, i.e. what a push adds.
#
# EXIT CODES. 0 no third-party modification (prints HOLDS with the protected count and entries scanned);
# 1 at least one FINDING; 2 COULD NOT DETERMINE (not a git work tree, unresolvable ref/range, `.gitmodules`
# unreadable, the protected set is EMPTY while the repository declares submodules — a guard over zero
# subjects is not a pass — or the tsv is missing/malformed). 2 is never a pass. Read-only (git
# cat-file/show/diff/config/rev-parse only).
#
# WHAT IT DOES NOT SEE: uncommitted edits inside a third-party submodule's own work tree (they are not in
# the umbrella's diff; a push cannot carry them), nor commits inside the third-party repository itself
# (those never reach this repository except as a gitlink move, which it does see), nor `allow` policy
# abuse: whether a permitted pointer move is a true fast-forward is not checked here.
set -uo pipefail

ROOT="" BASE="" HEAD_REF="HEAD" REF="" MODE=run
DATA="docs/zero-gap/third-party.tsv"
SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --root) ROOT="${2:-}"; shift 2 ;;
    --base) BASE="${2:-}"; shift 2 ;;
    --head) HEAD_REF="${2:-}"; shift 2 ;;
    --ref)  REF="${2:-}"; shift 2 ;;
    --derive) MODE=derive; shift ;;
    --prove-failure) MODE=prove; shift ;;
    --help|-h) sed -n '2,47p' "$0"; exit 0 ;;
    *) echo "zero-gap-third-party-guard: unknown argument '$1'" >&2; exit 2 ;;
  esac
done

# ns <url> -> host/owner (lowercase), empty when unparseable. Same patterns as doc-count-drift.
ns() {
  local u="$1" h o
  if [[ "$u" =~ ^[A-Za-z0-9._-]+@([A-Za-z0-9._-]+):/?([^/]+)/ ]]; then h="${BASH_REMATCH[1]}"; o="${BASH_REMATCH[2]}"
  elif [[ "$u" =~ ^(ssh|https?|git)://([^@/]+@)?([^/:]+)(:[0-9]+)?/([^/]+)/ ]]; then h="${BASH_REMATCH[3]}"; o="${BASH_REMATCH[5]}"
  else return 0; fi
  printf '%s/%s' "$h" "$o" | tr 'A-Z' 'a-z'
}

# derive_paths <ref> -> stdout: "<path>\t<classification>" for every NON-owned declared submodule at <ref>.
# rc 2 when .gitmodules cannot be read.
derive_paths() {
  local ref="$1" tmp rec k v name attr p u n dn
  tmp="$(mktemp -d)" || return 2
  : >"$tmp/decl"; : >"$tmp/ns"
  if ! git -C "$ROOT" cat-file -e "$ref:.gitmodules" 2>/dev/null; then rm -rf "$tmp"; return 0; fi
  git -C "$ROOT" show "$ref:.gitmodules" >"$tmp/gm" 2>/dev/null || { rm -rf "$tmp"; return 2; }
  git config -f "$tmp/gm" -z --get-regexp '^submodule\..*\.(path|url)$' >"$tmp/raw" 2>/dev/null || true
  # records: key \n value \0
  while IFS= read -r -d '' rec; do
    k="${rec%%$'\n'*}"; v="${rec#*$'\n'}"
    name="${k#submodule.}"; attr="${name##*.}"; name="${name%.*}"
    printf '%s\t%s\t%s\n' "$name" "$attr" "$v" >>"$tmp/decl"
  done <"$tmp/raw"
  # paths and urls per name
  awk -F'\t' '$2=="path"{p[$1]=$3} $2=="url"{u[$1]=$3} END{for(n in p) print p[n] "\t" u[n]}' "$tmp/decl" | LC_ALL=C sort >"$tmp/pu"
  while IFS=$'\t' read -r p u; do n="$(ns "$u")"; [ -n "$n" ] && printf '%s\n' "$n" >>"$tmp/ns"; done <"$tmp/pu"
  LC_ALL=C sort "$tmp/ns" | uniq -c | awk '$1>=2{print $2}' >"$tmp/owned_ns"
  if git -C "$ROOT" cat-file -e "$ref:helix-deps.yaml" 2>/dev/null; then
    git -C "$ROOT" show "$ref:helix-deps.yaml" 2>/dev/null | sed -n 's/^[[:space:]]*-\{0,1\}[[:space:]]*ssh_url:[[:space:]]*["'\'']\{0,1\}\([^"'\''[:space:]#]*\).*/\1/p' \
      | while IFS= read -r u; do ns "$u"; echo; done | grep -v '^$' >>"$tmp/owned_ns"
  fi
  while IFS=$'\t' read -r p u; do
    p="${p%/}"; [ -n "$p" ] || continue
    if [ -f "$ROOT/$p/scripts/gates/lib/pointer_carrier.sh" ]; then printf '%s\tgovernance-source\n' "$p"; continue; fi
    n="$(ns "$u")"
    if [ -n "$n" ] && grep -qxF -- "$n" "$tmp/owned_ns"; then continue; fi
    printf '%s\tthird-party\n' "$p"
  done <"$tmp/pu"
  rm -rf "$tmp"
}

resolve_range() { # sets head_sha base_sha; rc 2 on failure
  G() { git -C "$ROOT" "$@"; }
  [ -n "$ROOT" ] || ROOT="$(cd "$(dirname "$SELF")/.." && pwd)"
  [ -d "$ROOT" ] || { echo "COULD-NOT-DETERMINE root absent: $ROOT" >&2; return 2; }
  command -v git >/dev/null 2>&1 || { echo "COULD-NOT-DETERMINE git absent" >&2; return 2; }
  git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
    || { echo "COULD-NOT-DETERMINE not a git work tree: $ROOT" >&2; return 2; }
  head_sha="$(G rev-parse -q --verify "$HEAD_REF^{commit}" 2>/dev/null)" \
    || { echo "COULD-NOT-DETERMINE head ref unresolvable: $HEAD_REF" >&2; return 2; }
  if [ -z "$BASE" ]; then
    local up c; up="$(G rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || true)"
    for c in "$up" origin/main github/main; do
      [ -n "$c" ] || continue
      G rev-parse -q --verify "$c^{commit}" >/dev/null 2>&1 || continue
      BASE="$(G merge-base "$c" "$head_sha" 2>/dev/null)" && [ -n "$BASE" ] && break
      BASE=""
    done
    [ -n "$BASE" ] || { echo "COULD-NOT-DETERMINE no base ref (no @{upstream}, origin/main or github/main)" >&2; return 2; }
  fi
  base_sha="$(G rev-parse -q --verify "$BASE^{commit}" 2>/dev/null)" \
    || { echo "COULD-NOT-DETERMINE base ref unresolvable: $BASE" >&2; return 2; }
}

# policy_blocks <path>: succeeds when the pointer move of <path> must be refused (kept as ONE function: the proof mutates it).
policy_blocks() {
  local pol
  pol="$(awk -F'\t' -v p="$1" '$1==p{print $3; exit}' "$TMP/data")"
  [ "$pol" != "allow" ]
}

main() {
  local TMP head_sha base_sha rc
  TMP="$(mktemp -d)" || { echo "zero-gap-third-party-guard: mktemp failed" >&2; return 2; }
  trap 'rm -rf "$TMP"' RETURN
  resolve_range || return 2

  # ---- classification data -------------------------------------------------------------------
  if ! git -C "$ROOT" cat-file -e "$head_sha:$DATA" 2>/dev/null; then
    echo "COULD-NOT-DETERMINE classification data missing in HEAD: $DATA" >&2; return 2
  fi
  git -C "$ROOT" show "$head_sha:$DATA" 2>/dev/null | grep -v '^[[:space:]]*#' | grep -v '^[[:space:]]*$' >"$TMP/data.all"
  head -1 "$TMP/data.all" | grep -q '^path'$'\t''classification'$'\t''gitlink_bump' \
    || { echo "COULD-NOT-DETERMINE $DATA header must be: path<TAB>classification<TAB>gitlink_bump<TAB>evidence" >&2; return 2; }
  tail -n +2 "$TMP/data.all" >"$TMP/data"
  if awk -F'\t' 'NF<4 || $1=="" || ($3!="refuse" && $3!="allow") || $4==""{bad=1} END{exit !bad}' "$TMP/data"; then
    echo "COULD-NOT-DETERMINE $DATA has a malformed row (needs 4 columns; gitlink_bump refuse|allow; non-empty evidence)" >&2; return 2
  fi

  # ---- protected set -------------------------------------------------------------------------
  : >"$TMP/derived"
  local r
  for r in "$base_sha" "$head_sha"; do derive_paths "$r" >>"$TMP/derived"; rc=$?; [ "$rc" -eq 0 ] || { echo "COULD-NOT-DETERMINE .gitmodules unreadable at $r" >&2; return 2; }; done
  LC_ALL=C sort -u "$TMP/derived" -o "$TMP/derived"
  { cut -f1 "$TMP/data"; cut -f1 "$TMP/derived"; } | LC_ALL=C sort -u >"$TMP/protected"
  local declared
  declared=$( { git -C "$ROOT" show "$head_sha:.gitmodules" 2>/dev/null || true; } | grep -c '^\[submodule ')
  if [ ! -s "$TMP/protected" ] && [ "$declared" -gt 0 ]; then
    echo "COULD-NOT-DETERMINE the repository declares $declared submodule(s) but the protected set is empty (a guard over zero subjects is not a pass)" >&2; return 2
  fi
  : >"$TMP/out"
  local p
  while IFS=$'\t' read -r p _; do
    awk -F'\t' -v p="$p" '$1==p{f=1} END{exit !f}' "$TMP/data" \
      || printf 'FINDING STALE classification data: %s is derived third-party but has no row in %s (add it; defaults to refuse)\n' "$p" "$DATA" >>"$TMP/out"
  done <"$TMP/derived"

  # ---- the diff ------------------------------------------------------------------------------
  local nentries=0 om nm os ns_ st path q
  git -C "$ROOT" diff --raw -z --no-renames "$base_sha" "$head_sha" >"$TMP/raw" 2>/dev/null \
    || { echo "COULD-NOT-DETERMINE git diff failed for $base_sha..$head_sha" >&2; return 2; }
  while IFS= read -r -d '' meta && IFS= read -r -d '' path; do
    nentries=$((nentries+1))
    meta="${meta#:}"; read -r om nm os ns_ st <<<"$meta"
    st="${st:0:1}"
    while IFS= read -r q; do
      [ -n "$q" ] || continue
      if [ "$path" = "$q" ]; then
        if [ "$om" = 160000 ] && [ "$nm" = 160000 ] && [ "$st" = M ]; then
          if policy_blocks "$q"; then
            printf 'FINDING THIRD-PARTY GITLINK BUMP %s %s..%s (gitlink_bump=refuse in %s)\n' "$q" "${os:0:7}" "${ns_:0:7}" "$DATA" >>"$TMP/out"
          else
            printf 'NOTE third-party gitlink bump allowed by %s: %s %s..%s\n' "$DATA" "$q" "${os:0:7}" "${ns_:0:7}" >>"$TMP/out"
          fi
        elif [ "$st" = A ] && [ "$nm" = 160000 ]; then
          :
        else
          printf 'FINDING THIRD-PARTY EDIT %s (status %s, mode %s->%s; a third-party gitlink may not be removed or replaced)\n' "$path" "$st" "$om" "$nm" >>"$TMP/out"
        fi
      elif [[ "$path" == "$q"/* ]]; then
        printf 'FINDING THIRD-PARTY EDIT %s (status %s, under third-party path %s)\n' "$path" "$st" "$q" >>"$TMP/out"
      fi
    done <"$TMP/protected"
  done <"$TMP/raw"

  LC_ALL=C sort "$TMP/out"
  local nf; nf=$(grep -c '^FINDING' "$TMP/out")
  if [ "$nf" -gt 0 ]; then
    printf 'VIOLATED %d finding(s); base=%s head=%s; third-party code is registered and classified, never edited (FR-021)\n' "$nf" "${base_sha:0:7}" "${head_sha:0:7}"
    return 1
  fi
  printf 'HOLDS no third-party modification; base=%s head=%s; protected=%d (tsv=%d derived=%d); diff entries scanned=%d\n' \
    "${base_sha:0:7}" "${head_sha:0:7}" "$(wc -l <"$TMP/protected")" "$(wc -l <"$TMP/data")" "$(wc -l <"$TMP/derived")" "$nentries"
  return 0
}

derive_mode() {
  local head_sha base_sha
  [ -n "$REF" ] || REF="$HEAD_REF"
  HEAD_REF="$REF"; BASE="$REF"
  resolve_range || return 2
  printf 'path\tclassification\tgitlink_bump\tevidence\n'
  derive_paths "$head_sha" | LC_ALL=C sort | while IFS=$'\t' read -r p c; do
    case "$c" in
      governance-source) printf '%s\t%s\tallow\tgovernance source (carries scripts/gates/lib/pointer_carrier.sh); pointer moves follow the standing fast-forward-only authorization recorded in CLAUDE.md -- confirm and edit this column deliberately\n' "$p" "$c" ;;
      *) printf '%s\t%s\trefuse\tdeclared in .gitmodules; URL namespace hosts one declared submodule and is not a helix-deps.yaml ssh_url namespace\n' "$p" "$c" ;;
    esac
  done
}

prove() {
  local here fx drv tmp rc fails=0
  here="$(cd "$(dirname "$SELF")/.." && pwd)"
  fx="$here/_tests/fixtures/zero-gap/third-party-guard"
  drv="$here/_tests/zero-gap-guard-fixtures.sh"
  [ -d "$fx/base" ] && [ -r "$drv" ] || { echo "prove: fixtures or driver missing ($fx, $drv)" >&2; return 2; }
  command -v git >/dev/null 2>&1 || { echo "prove: git absent" >&2; return 2; }
  tmp="$(mktemp -d)" || return 2
  trap 'rm -rf "$tmp"' RETURN
  bash "$drv" --script "$SELF" --cases "$fx" >"$tmp/ctl.out" 2>&1; rc=$?
  tail -1 "$tmp/ctl.out"
  [ "$rc" -eq 0 ] && echo "PASS control  real script: all fixture cases behave" || { echo "FAIL control  real script rc=$rc"; sed 's/^/    /' "$tmp/ctl.out" | head -20; fails=$((fails+1)); }
  [ "$rc" -eq 2 ] && return 2
  mut() {
    sed "$2" "$SELF" >"$tmp/m.sh"
    if cmp -s "$SELF" "$tmp/m.sh"; then echo "FAIL $1  mutation did not change the script (inoperative proof)"; fails=$((fails+1)); return; fi
    bash "$drv" --script "$tmp/m.sh" --cases "$fx" >"$tmp/m.out" 2>&1; local r=$?
    if [ "$r" -eq 1 ]; then echo "PASS $1  mutant caught ($(tail -1 "$tmp/m.out"))"; else echo "FAIL $1  mutant NOT caught (driver rc=$r)"; fails=$((fails+1)); fi
  }
  mut M1-neutered          's/^main() {/main() { echo "HOLDS neutered"; return 0/'
  mut M2-policy-allows-all 's/^  \[ "\$pol" != "allow" \]$/  false/'
  mut M3-ignore-subpaths   's/^      elif \[\[ "\$path" == "\$q"\/\* \]\]; then$/      elif false; then/'
  mut M4-no-derivation     's/^  for r in "\$base_sha" "\$head_sha"; do derive_paths.*$/  :/'
  mut M5-no-stale-check    's/^      || printf .FINDING STALE.*$/      || true/'
  mut M6-removal-allowed   's/^        elif \[ "\$st" = A \] \&\& \[ "\$nm" = 160000 \]; then$/        elif [ "$nm" != 160000 ] || [ "$st" = A ]; then/'
  bash "$SELF" --root "$tmp/does-not-exist" >/dev/null 2>&1; rc=$?
  [ "$rc" -eq 2 ] && echo "PASS U1  absent root => rc 2" || { echo "FAIL U1  absent root rc=$rc"; fails=$((fails+1)); }
  mkdir -p "$tmp/plain"; bash "$SELF" --root "$tmp/plain" >/dev/null 2>&1; rc=$?
  [ "$rc" -eq 2 ] && echo "PASS U2  not a git work tree => rc 2" || { echo "FAIL U2  non-repo rc=$rc"; fails=$((fails+1)); }
  [ "$fails" -eq 0 ] && { echo "zero-gap-third-party-guard proof: 0 failure(s)"; return 0; }
  echo "zero-gap-third-party-guard proof: $fails failure(s)"; return 1
}

case "$MODE" in
  prove) prove; exit $? ;;
  derive) derive_mode; exit $? ;;
  *) main; exit $? ;;
esac
