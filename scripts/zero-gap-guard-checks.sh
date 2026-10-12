#!/usr/bin/env bash
# scripts/zero-gap-guard-checks.sh — "no check weakened to reach green" push-path guard
# (feature 010, task T040; FR-023, FR-013, SC-007).
#
# WHAT IT REFUSES. A diff (BASE..HEAD, committed content only) that, WITHOUT a paired waiver:
#   REMOVED  <type> <key>    deletes a row of scripts/check-registry.tsv (types check, scanroot, debt,
#                            exempt) — except a `debt` row whose id reappears as a `check` row in HEAD
#                            (debt paid by a check that carries its own proof columns);
#   DELETED  check entry point <path>   deletes the script a base `check` row points at, or deletes any
#                            scripts/ file whose base content names `--prove-failure` (an unregistered
#                            proof-carrying check is still a check);
#   ADDED    exempt|debt <key>          adds an `exempt` or `debt` row (an allow-list for the registry);
#   ADDED    allow-list entry <subject> adds a non-comment line to any tracked file named *-allow
#                            (e.g. .content-boundary-allow) — derived from the diff, not from a roster;
#   WEAKENED check <id>      keeps a check row but blanks its proof-kind or proof-arg column ("", "-", "none").
#
# THE "PAIRED PROOF" (FR-013). A weakening is permitted only when the SAME diff adds a row to
# docs/zero-gap/guard-waivers.tsv (TAB-separated: kind, subject, paired_check, reason) where
#   kind      one of remove-check remove-scanroot remove-debt remove-exempt delete-script
#             add-exempt add-debt add-allow weaken-check
#   subject   the id / path / allow-list subject the finding names
#   paired_check  the id of a `check` row that exists in HEAD, is not the subject itself, has non-weak proof
#             columns, and whose entry-point exists in HEAD — i.e. something that still carries a proof
#   reason    non-empty free text
# A waiver row that already existed in BASE does not count (a consumed waiver cannot be reused), and a
# newly added waiver row that is malformed or points at a non-proof is itself a finding.
#
# USAGE
#   bash scripts/zero-gap-guard-checks.sh [--root DIR] [--base REF] [--head REF]
#   bash scripts/zero-gap-guard-checks.sh --prove-failure      # paired mutation proof (registered check)
# With no --base the range is merge-base(HEAD, @{upstream} | origin/main | github/main)..HEAD — what a
# push would add. No usable ref => rc 2.
#
# EXIT CODES. 0 no weakening found (prints HOLDS with the row counts it compared); 1 at least one
# FINDING; 2 COULD NOT DETERMINE (not a git work tree, unresolvable ref, base registry present but zero
# rows parse, no range). 2 is never a pass. Read-only: it only runs git cat-file/show/diff/rev-parse.
#
# WHAT IT DOES NOT SEE (stated, not hidden): uncommitted changes (a push carries commits); a check
# neutered INSIDE its script while the row and file remain (that is the paired --prove-failure's job and
# scripts/verify-check-registry.sh --run-proofs'); allow-lists embedded in a script's heredoc (e.g.
# audit-environment-assumptions.sh ALLOW_RULES) rather than a *-allow file; a rewritten registry that
# changes a row's id AND entry-point together reads as REMOVED + ADDED and is flagged as such.
set -uo pipefail

ROOT="" BASE="" HEAD_REF="HEAD" MODE=run
REGISTRY="scripts/check-registry.tsv"
WAIVERS="docs/zero-gap/guard-waivers.tsv"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --root) ROOT="${2:-}"; shift 2 ;;
    --base) BASE="${2:-}"; shift 2 ;;
    --head) HEAD_REF="${2:-}"; shift 2 ;;
    --prove-failure) MODE=prove; shift ;;
    --help|-h) sed -n '2,44p' "$0"; exit 0 ;;
    *) echo "zero-gap-guard-checks: unknown argument '$1'" >&2; exit 2 ;;
  esac
done

SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"

# ---- waiver validity (kept as ONE function: the proof mutates it) ----------------------------------
# waiver_valid <kind> <subject>: succeeds when HEAD's newly added waiver rows hold a valid one.
waiver_valid() {
  local kind="$1" subject="$2"
  grep -qxF -- "$kind"$'\t'"$subject" "$TMP/waivers_valid"
}

main() {
  local TMP; TMP="$(mktemp -d)" || { echo "zero-gap-guard-checks: mktemp failed" >&2; return 2; }
  trap 'rm -rf "$TMP"' RETURN
  [ -n "$ROOT" ] || ROOT="$(cd "$(dirname "$SELF")/.." && pwd)"
  [ -d "$ROOT" ] || { echo "COULD-NOT-DETERMINE root absent: $ROOT" >&2; return 2; }
  command -v git >/dev/null 2>&1 || { echo "COULD-NOT-DETERMINE git absent" >&2; return 2; }
  git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
    || { echo "COULD-NOT-DETERMINE not a git work tree: $ROOT" >&2; return 2; }
  G() { git -C "$ROOT" "$@"; }

  local head_sha base_sha c up
  head_sha="$(G rev-parse -q --verify "$HEAD_REF^{commit}" 2>/dev/null)" \
    || { echo "COULD-NOT-DETERMINE head ref unresolvable: $HEAD_REF" >&2; return 2; }
  if [ -z "$BASE" ]; then
    up="$(G rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || true)"
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

  has() { G cat-file -e "$1:$2" 2>/dev/null; }
  show() { G show "$1:$2" 2>/dev/null; }

  # ---- registry rows --------------------------------------------------------------------------
  : >"$TMP/b.reg"; : >"$TMP/h.reg"
  local base_has=0 head_has=0
  if has "$base_sha" "$REGISTRY"; then base_has=1; show "$base_sha" "$REGISTRY" >"$TMP/b.reg"; fi
  if has "$head_sha" "$REGISTRY"; then head_has=1; show "$head_sha" "$REGISTRY" >"$TMP/h.reg"; fi
  local rowsel='$1 ~ /^(check|debt|exempt|scanroot)$/ { print $1 "\t" $2 }'
  awk -F'\t' "$rowsel" "$TMP/b.reg" | LC_ALL=C sort -u >"$TMP/b.keys"
  awk -F'\t' "$rowsel" "$TMP/h.reg" | LC_ALL=C sort -u >"$TMP/h.keys"
  if [ "$base_has" = 1 ] && [ ! -s "$TMP/b.keys" ]; then
    echo "COULD-NOT-DETERMINE base registry present but zero rows parse (cannot compare against nothing)" >&2; return 2
  fi
  # full check rows: id, entry, proof-kind, proof-arg
  awk -F'\t' '$1=="check"{print $2 "\t" $3 "\t" $4 "\t" $5}' "$TMP/b.reg" | LC_ALL=C sort -u >"$TMP/b.checks"
  awk -F'\t' '$1=="check"{print $2 "\t" $3 "\t" $4 "\t" $5}' "$TMP/h.reg" | LC_ALL=C sort -u >"$TMP/h.checks"

  # ---- waivers newly added in this diff, validated --------------------------------------------
  : >"$TMP/b.wv"; : >"$TMP/h.wv"; : >"$TMP/waivers_valid"; : >"$TMP/wfindings"
  has "$base_sha" "$WAIVERS" && show "$base_sha" "$WAIVERS" >"$TMP/b.wv"
  has "$head_sha" "$WAIVERS" && show "$head_sha" "$WAIVERS" >"$TMP/h.wv"
  grep -v '^[[:space:]]*#' "$TMP/h.wv" | grep -v '^[[:space:]]*$' | LC_ALL=C sort -u >"$TMP/h.wv.rows" || true
  grep -v '^[[:space:]]*#' "$TMP/b.wv" | grep -v '^[[:space:]]*$' | LC_ALL=C sort -u >"$TMP/b.wv.rows" || true
  LC_ALL=C comm -13 "$TMP/b.wv.rows" "$TMP/h.wv.rows" >"$TMP/new.wv"
  local wk ws wp wr why ent pk pa
  while IFS=$'\t' read -r wk ws wp wr; do
    [ -n "$wk$ws" ] || continue
    why=""
    case "$wk" in
      remove-check|remove-scanroot|remove-debt|remove-exempt|delete-script|add-exempt|add-debt|add-allow|weaken-check) ;;
      *) why="unknown kind" ;;
    esac
    [ -z "$why" ] && { [ -n "$ws" ] && [ -n "$wp" ] && [ -n "${wr// /}" ] || why="needs four non-empty columns (kind, subject, paired_check, reason)"; }
    if [ -z "$why" ]; then
      if [ "$wp" = "$ws" ]; then why="paired check '$wp' is the subject itself"
      else
        IFS=$'\t' read -r ent pk pa < <(awk -F'\t' -v id="$wp" '$1==id{print $2"\t"$3"\t"$4; exit}' "$TMP/h.checks")
        if [ -z "${ent:-}" ]; then why="paired check '$wp' is not a check row in HEAD"
        elif ! has "$head_sha" "$ent"; then why="paired check '$wp' entry point '$ent' does not exist in HEAD"
        else
          case "${pk:-}" in ""|-|none) why="paired check '$wp' has no proof-kind" ;; esac
          case "${pa:-}" in ""|-|none) why="paired check '$wp' has no proof-arg" ;; esac
        fi
      fi
    fi
    if [ -n "$why" ]; then
      printf 'FINDING WAIVER INVALID %s %s: %s\n' "$wk" "$ws" "$why" >>"$TMP/wfindings"
    else
      printf '%s\t%s\n' "$wk" "$ws" >>"$TMP/waivers_valid"
    fi
  done <"$TMP/new.wv"

  : >"$TMP/findings"
  find_or_waive() { # <kind> <subject> <message>
    if waiver_valid "$1" "$2"; then printf 'WAIVED %s\n' "$3" >>"$TMP/waived"; else printf 'FINDING %s\n' "$3" >>"$TMP/findings"; fi
  }
  : >"$TMP/waived"
  local t k

  # ---- removed rows ----------------------------------------------------------------------------
  LC_ALL=C comm -23 "$TMP/b.keys" "$TMP/h.keys" >"$TMP/removed"
  while IFS=$'\t' read -r t k; do
    [ -n "$t" ] || continue
    if [ "$t" = debt ] && grep -qxF -- "check"$'\t'"$k" "$TMP/h.keys"; then continue; fi
    find_or_waive "remove-$t" "$k" "REMOVED $t $k (scripts/check-registry.tsv)"
  done <"$TMP/removed"

  # ---- added exempt / debt rows ----------------------------------------------------------------
  LC_ALL=C comm -13 "$TMP/b.keys" "$TMP/h.keys" | awk -F'\t' '$1=="exempt"||$1=="debt"' >"$TMP/added"
  while IFS=$'\t' read -r t k; do
    [ -n "$t" ] || continue
    find_or_waive "add-$t" "$k" "ADDED $t $k (scripts/check-registry.tsv has no pairing proof for it)"
  done <"$TMP/added"

  # ---- weakened check rows ---------------------------------------------------------------------
  local id e pk2 pa2 bpk bpa weak
  while IFS=$'\t' read -r id e pk2 pa2; do
    [ -n "$id" ] || continue
    weak=0
    case "$pk2" in ""|-|none) weak=1 ;; esac
    case "$pa2" in ""|-|none) weak=1 ;; esac
    [ "$weak" = 1 ] || continue
    IFS=$'\t' read -r bpk bpa < <(awk -F'\t' -v id="$id" '$1==id{print $3"\t"$4; exit}' "$TMP/b.checks")
    if [ -n "${bpk:-}${bpa:-}" ] && { [ "$bpk" != "$pk2" ] || [ "$bpa" != "$pa2" ]; }; then
      find_or_waive "weaken-check" "$id" "WEAKENED check $id (proof columns '$bpk'/'$bpa' became '$pk2'/'$pa2')"
    fi
  done <"$TMP/h.checks"

  # ---- deleted check entry points + deleted proof-carrying scripts -----------------------------
  : >"$TMP/delseen"
  while IFS=$'\t' read -r id e _ _; do
    [ -n "$id" ] || continue
    if ! has "$head_sha" "$e"; then
      printf '%s\n' "$e" >>"$TMP/delseen"
      find_or_waive "delete-script" "$e" "DELETED check entry point $e (check $id)"
    fi
  done <"$TMP/b.checks"
  local p
  while IFS= read -r -d '' p; do
    grep -qxF -- "$p" "$TMP/delseen" && continue
    if show "$base_sha" "$p" | grep -qF -- '--prove-failure'; then
      find_or_waive "delete-script" "$p" "DELETED check entry point $p (carried a --prove-failure proof)"
    fi
  done < <(G diff --name-only -z --diff-filter=D "$base_sha" "$head_sha" -- scripts 2>/dev/null | grep -z '\.sh$')

  # ---- added allow-list entries (any tracked *-allow file) -------------------------------------
  local f line subj
  while IFS= read -r -d '' f; do
    case "$(basename -- "$f")" in *-allow) ;; *) continue ;; esac
    while IFS= read -r line; do
      line="${line#+}"
      case "$line" in ""|\#*) continue ;; esac
      [[ "$line" =~ ^[[:space:]]*$ ]] && continue
      subj="${line%%$'\t'*}"; subj="${subj%% *}"
      find_or_waive "add-allow" "$subj" "ADDED allow-list entry $subj in $f"
    done < <(G diff -U0 "$base_sha" "$head_sha" -- "$f" | grep '^+' | grep -v '^+++')
  done < <(G diff --name-only -z "$base_sha" "$head_sha" 2>/dev/null)

  cat "$TMP/wfindings" "$TMP/findings" "$TMP/waived" 2>/dev/null | LC_ALL=C sort
  local nf
  nf=$(cat "$TMP/wfindings" "$TMP/findings" | grep -c '^FINDING')
  if [ "$nf" -gt 0 ]; then
    printf 'VIOLATED %d finding(s); base=%s head=%s; waiver file: %s (a waiver must be ADDED in this diff and pair a check that carries a proof)\n' \
      "$nf" "${base_sha:0:7}" "${head_sha:0:7}" "$WAIVERS"
    return 1
  fi
  printf 'HOLDS no check weakened; base=%s head=%s; registry keys base=%d head=%d; check rows base=%d head=%d; waived=%d; new waiver rows=%d\n' \
    "${base_sha:0:7}" "${head_sha:0:7}" "$(wc -l <"$TMP/b.keys")" "$(wc -l <"$TMP/h.keys")" \
    "$(wc -l <"$TMP/b.checks")" "$(wc -l <"$TMP/h.checks")" "$(wc -l <"$TMP/waived")" "$(wc -l <"$TMP/new.wv")"
  return 0
}

# ---- paired mutation proof ---------------------------------------------------------------------
prove() {
  local here fx drv tmp rc fails=0
  here="$(cd "$(dirname "$SELF")/.." && pwd)"
  fx="$here/_tests/fixtures/zero-gap/guard-checks"
  drv="$here/_tests/zero-gap-guard-fixtures.sh"
  [ -d "$fx/base" ] && [ -r "$drv" ] || { echo "prove: fixtures or driver missing ($fx, $drv)" >&2; return 2; }
  command -v git >/dev/null 2>&1 || { echo "prove: git absent" >&2; return 2; }
  tmp="$(mktemp -d)" || return 2
  trap 'rm -rf "$tmp"' RETURN
  # control: the real script passes every fixture case (controls hold, violations are caught)
  bash "$drv" --script "$SELF" --cases "$fx" >"$tmp/ctl.out" 2>&1; rc=$?
  tail -1 "$tmp/ctl.out"
  [ "$rc" -eq 0 ] && echo "PASS control  real script: all fixture cases behave" || { echo "FAIL control  real script rc=$rc"; sed 's/^/    /' "$tmp/ctl.out" | head -20; fails=$((fails+1)); }
  [ "$rc" -eq 2 ] && return 2
  # mutations: each broken copy MUST make the fixture driver fail (rc 1)
  mut() { # <name> <sed-expr>
    sed "$2" "$SELF" >"$tmp/m.sh"
    if cmp -s "$SELF" "$tmp/m.sh"; then echo "FAIL $1  mutation did not change the script (inoperative proof)"; fails=$((fails+1)); return; fi
    bash "$drv" --script "$tmp/m.sh" --cases "$fx" >"$tmp/m.out" 2>&1; local r=$?
    if [ "$r" -eq 1 ]; then echo "PASS $1  mutant caught ($(tail -1 "$tmp/m.out"))"; else echo "FAIL $1  mutant NOT caught (driver rc=$r)"; fails=$((fails+1)); fi
  }
  mut M1-neutered        's/^main() {/main() { echo "HOLDS neutered"; return 0/'
  mut M2-waiver-always   's/^  grep -qxF -- "\$kind".*$/  true/'
  mut M3-no-removed-rows 's/^  LC_ALL=C comm -23 .*$/  : >"$TMP\/removed"/'
  mut M4-no-allow-scan   's/\*-allow) ;; \*) continue ;; esac/*) continue ;; esac/'
  mut M5-no-script-delete 's/^    if ! has "\$head_sha" "\$e"; then$/    if false; then/'
  mut M6-self-pair-ok    's/if \[ "\$wp" = "\$ws" \]; then why=/if false; then why=/'
  # rc-2 states are never a pass
  bash "$SELF" --root "$tmp/does-not-exist" >/dev/null 2>&1; rc=$?
  [ "$rc" -eq 2 ] && echo "PASS U1  absent root => rc 2" || { echo "FAIL U1  absent root rc=$rc"; fails=$((fails+1)); }
  mkdir -p "$tmp/plain"; bash "$SELF" --root "$tmp/plain" >/dev/null 2>&1; rc=$?
  [ "$rc" -eq 2 ] && echo "PASS U2  not a git work tree => rc 2" || { echo "FAIL U2  non-repo rc=$rc"; fails=$((fails+1)); }
  git init -q "$tmp/norange" >/dev/null 2>&1
  git -C "$tmp/norange" -c user.name=p -c user.email=p@example.invalid commit -q --allow-empty -m x >/dev/null 2>&1
  bash "$SELF" --root "$tmp/norange" >/dev/null 2>&1; rc=$?
  [ "$rc" -eq 2 ] && echo "PASS U3  no base ref resolvable => rc 2" || { echo "FAIL U3  no-range rc=$rc"; fails=$((fails+1)); }
  [ "$fails" -eq 0 ] && { echo "zero-gap-guard-checks proof: 0 failure(s)"; return 0; }
  echo "zero-gap-guard-checks proof: $fails failure(s)"; return 1
}

if [ "$MODE" = prove ]; then prove; exit $?; fi
main
exit $?
