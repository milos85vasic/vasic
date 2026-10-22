#!/usr/bin/env bash
# =============================================================================
# qa-candidate.sh — build / update the REPRODUCIBLE manual-QA CANDIDATE branch
# of the workshop repository.
#
# WHAT THE CANDIDATE IS (and is not)
#   An INTEGRATION of every in-flight stream, rebuilt by this script as the
#   streams' branches advance, so a human can exercise every flow and report what
#   is wrong. It is NOT a release, NOT main, NOT reviewed, and it is EXPECTED to
#   carry known defects. Nothing here promotes anything: the candidate branch
#   (`qa-candidate`) is never merged into main or int-*, and this script contains
#   no push, ever (it refuses --push / any push-shaped argument with rc 2).
#
# WHAT IT DOES
#   1. Ensures a dedicated git worktree on branch `qa-candidate` (created from
#      the `base` row of the branch list when it does not exist yet).
#   2. For each `merge` row of scripts/qa-candidate.branches.tsv, IN ORDER, takes
#      the branch's CURRENT COMMITTED tip (never a worktree's dirty state; no
#      other branch's worktree is touched) and `git merge --no-ff`s it (never
#      rebase). A tip that is already an ancestor of the candidate is a no-op, so
#      re-running after branches advance merges only the new tips (idempotent).
#   3. A merge that leaves unmerged paths is ABORTED and recorded `conflict`; a
#      merge that applies cleanly but makes the build check fail is ABORTED and
#      recorded `skipped-build-break` (the candidate is never left unbuildable).
#      Conflicts are resolved by a human by UNION in the candidate worktree with a
#      merge commit whose subject ends `[conflict-resolved]`; git rerere is
#      enabled in the worktree so the same resolution replays on later runs.
#   4. Writes evidence/qa-candidate/MANIFEST.tsv inside the candidate branch
#      (branch, sha, status, notes) and commits it when it changed. Fix commits
#      made on the candidate whose subject starts `qa-fix:` are listed as rows.
#
# USAGE
#   scripts/qa-candidate.sh                 merge new tips, refresh the manifest
#   scripts/qa-candidate.sh --status        read-only: print what a run would do
#   scripts/qa-candidate.sh --no-build      skip the per-merge build check
#   scripts/qa-candidate.sh --repo DIR --wt DIR --branches FILE   overrides
#   scripts/qa-candidate.sh --prove-failure paired mutation proof (see below)
#
# ENVIRONMENT
#   QA_CANDIDATE_REPO   the repository (default: <umbrella>/workshop)
#   QA_CANDIDATE_WT     the worktree  (default: <umbrella>/../vasic-wt/qa-candidate)
#   QA_CANDIDATE_BUILD_CMD   build check, run with bash -c inside the worktree
#                       (default: cd platform/backend && go build ./... under
#                       nice; this is the Go half only — the Angular build is
#                       verified by the operator-driven steps in docs/QA-CANDIDATE.md)
#   QA_CANDIDATE_LOGDIR where build logs of rejected merges go
#
# EXIT (three-valued; 2 is never a pass)
#   0  every non-skipped branch is merged and the candidate builds
#   1  at least one branch is missing, conflicted, or was rejected for breaking
#      the build (the candidate itself is still consistent and buildable)
#   2  could not determine: git absent, repo / worktree unusable, dirty
#      candidate worktree, bad branch list, forbidden (push) argument
#
# PAIRED PROOF  scripts/qa-candidate.sh --prove-failure
#   Builds a synthetic repository and proves, with pasted per-case output, that a
#   conflicting branch is aborted + recorded, a build-breaking branch is rejected
#   and leaves the tree buildable, a missing branch is recorded, a re-run is
#   idempotent, an advanced branch tip is merged on re-run, a clean list exits 0,
#   a push-shaped argument is refused, and that two source mutations (build check
#   disabled, conflict check disabled) are CAUGHT by the same cases.
# =============================================================================
set -uo pipefail

SELF="$(readlink -f -- "${BASH_SOURCE[0]}")"
ROOT="$(cd -- "$(dirname -- "$SELF")/.." && pwd -P)"
REPO="${QA_CANDIDATE_REPO:-$ROOT/workshop}"
WT="${QA_CANDIDATE_WT:-$(dirname "$ROOT")/vasic-wt/qa-candidate}"
BRANCHES="$ROOT/scripts/qa-candidate.branches.tsv"
CAND_BRANCH="qa-candidate"
LOGDIR="${QA_CANDIDATE_LOGDIR:-${XDG_CACHE_HOME:-$HOME/.cache}/qa-candidate/logs}"
DEFAULT_BUILD='cd platform/backend && nice -n 10 go build ./...'
BUILD_CMD="${QA_CANDIDATE_BUILD_CMD:-$DEFAULT_BUILD}"
TRAILER='Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>'
DO_BUILD=1 STATUS_ONLY=0 PROVE=0

say()  { printf '>> %s\n' "$*"; }
warn() { printf '!! %s\n' "$*" >&2; }
undet() { printf 'UNDETERMINED: %s\n' "$*" >&2; exit 2; }

while [ $# -gt 0 ]; do
  case "$1" in
    --repo) REPO="${2:-}"; shift 2 ;;
    --wt) WT="${2:-}"; shift 2 ;;
    --branches) BRANCHES="${2:-}"; shift 2 ;;
    --no-build) DO_BUILD=0; shift ;;
    --status) STATUS_ONLY=1; shift ;;
    --prove-failure) PROVE=1; shift ;;
    -h|--help) sed -n '2,/^set -uo/p' "$SELF" | sed '$d; s/^# \{0,1\}//'; exit 0 ;;
    *push*|*Push*|*PUSH*) undet "refused: this script never pushes (argument '$1')" ;;
    *) undet "unknown argument '$1'" ;;
  esac
done

# ------------------------------------------------------------------ prove mode
prove_failure() {
  local T; T="$(mktemp -d "${TMPDIR:-/tmp}/qa-cand-prove.XXXXXX")" || undet "mktemp"
  local pass=0 fail=0
  ok()  { printf '  PASS  %s\n' "$1"; pass=$((pass+1)); }
  bad() { printf '  FAIL  %s\n' "$1"; fail=$((fail+1)); }
  export GIT_AUTHOR_NAME=prove GIT_AUTHOR_EMAIL=prove@example.invalid
  export GIT_COMMITTER_NAME=prove GIT_COMMITTER_EMAIL=prove@example.invalid
  local R="$T/repo" W="$T/wt" B="$T/branches.tsv"
  git init -q -b base "$R" || undet "git init"
  ( cd "$R" && printf 'line1\nline2\n' > a.txt && git add a.txt && git commit -qm base ) || undet "seed commit"
  mk() { # name file content  (branch off base)
    ( cd "$R" && git checkout -q -b "$1" base && printf '%b' "$3" > "$2" && git add "$2" && git commit -qm "$1" && git checkout -q base ); }
  mk ok1 ok1.txt 'one\n'
  mk conf a.txt 'CHANGED\nline2\n'
  mk ok2 ok2.txt 'two\n'
  mk brk BROKEN 'x\n'
  # conf conflicts only once ok-a (which edits a.txt) is merged first
  mk oka a.txt 'line1\nEDITED\n'
  printf 'base\tbase\nmerge\toka\nmerge\tok1\nmerge\tconf\nmerge\tbrk\nmerge\tnosuch\nmerge\tok2\nmerge\tskipme\tnot ready (configured)\n' > "$B"
  mk skipme skip.txt 's\n'
  local ENVP=(env QA_CANDIDATE_REPO="$R" QA_CANDIDATE_WT="$W" QA_CANDIDATE_LOGDIR="$T/logs"
              "QA_CANDIDATE_BUILD_CMD=test ! -e BROKEN")
  run() { "${ENVP[@]}" bash "${1:-$SELF}" --branches "$B" 2>&1; }
  man() { git -C "$W" show "HEAD:evidence/qa-candidate/MANIFEST.tsv" 2>/dev/null; }
  say "CASE 1: first run over a list with a conflict, a build-breaker, a missing and a skipped branch"
  local out rc h1
  out="$(run)"; rc=$?
  [ "$rc" = 1 ] && ok "rc 1 (not a pass) = $rc" || bad "expected rc 1 got $rc"
  man | grep -qP '^oka\t.*\tmerged\t' && ok "oka merged" || bad "oka not merged"
  man | grep -qP '^ok1\t.*\tmerged\t' && ok "ok1 merged" || bad "ok1 not merged"
  man | grep -qP '^conf\t.*\tconflict\t' && ok "conf recorded conflict" || bad "conf not recorded conflict"
  man | grep -qP '^brk\t.*\tskipped-build-break\t' && ok "brk recorded skipped-build-break" || bad "brk not rejected"
  man | grep -qP '^nosuch\t.*\tmissing\t' && ok "nosuch recorded missing" || bad "nosuch not recorded missing"
  man | grep -qP '^skipme\t.*\tskipped\t' && ok "skipme skipped by configuration" || bad "skipme not skipped"
  man | grep -qP '^ok2\t.*\tmerged\t' && ok "ok2 merged after the failures (loop continued)" || bad "ok2 not merged"
  [ ! -e "$W/BROKEN" ] && ok "tree has no BROKEN (stays buildable)" || bad "BROKEN is in the candidate tree"
  ! git -C "$W" grep -q '^<<<<<<<' HEAD -- . && ok "no conflict markers committed" || bad "conflict markers committed"
  git -C "$W" rev-parse -q --verify MERGE_HEAD >/dev/null && bad "merge left in progress" || ok "no merge left in progress"
  [ -z "$(git -C "$W" status --porcelain)" ] && ok "worktree clean after run" || bad "worktree dirty after run"
  h1="$(git -C "$W" rev-parse HEAD)"
  say "CASE 2: idempotent re-run (nothing advanced)"
  out="$(run)"; rc=$?
  [ "$(git -C "$W" rev-parse HEAD)" = "$h1" ] && ok "HEAD unchanged on re-run" || bad "HEAD moved on idempotent re-run"
  [ "$rc" = 1 ] && ok "same rc 1" || bad "rc changed to $rc"
  say "CASE 3: a branch advances -> only the new tip is merged"
  ( cd "$R" && git checkout -q ok1 && printf 'more\n' > ok1b.txt && git add ok1b.txt && git commit -qm adv && git checkout -q base )
  out="$(run)"; rc=$?
  [ -f "$W/ok1b.txt" ] && ok "advanced tip merged on re-run" || bad "advanced tip not merged"
  say "CASE 4: a clean list exits 0"
  printf 'base\tbase\nmerge\toka\nmerge\tok1\nmerge\tok2\n' > "$B"
  out="$(run)"; rc=$?
  [ "$rc" = 0 ] && ok "clean list rc 0" || bad "clean list rc $rc (out: $(printf '%s' "$out" | tail -3))"
  say "CASE 5: refusals (rc 2, never a pass)"
  "${ENVP[@]}" bash "$SELF" --branches "$B" --push >/dev/null 2>&1; rc=$?
  [ "$rc" = 2 ] && ok "--push refused rc 2" || bad "--push rc $rc"
  QA_CANDIDATE_REPO="$T/nonexistent" bash "$SELF" --branches "$B" >/dev/null 2>&1; rc=$?
  [ "$rc" = 2 ] && ok "nonexistent repo rc 2" || bad "nonexistent repo rc $rc"
  local pat="git[^|;&]* pu""sh"
  ! grep -v '^[[:space:]]*#' "$SELF" | grep -Eq "$pat" \
    && ok "script body has no executable publish command" || bad "script body has a publish command"
  say "CASE 6: mutations of this script are CAUGHT"
  local MUT_B="$T/mut_build.sh" MUT_C="$T/mut_conf.sh"
  sed 's/^\(.*\)# MUT:build-gate$/  if false; then # MUT:build-gate/' "$SELF" > "$MUT_B"
  sed 's/^\(.*\)# MUT:conflict-gate$/  if false; then # MUT:conflict-gate/' "$SELF" > "$MUT_C"
  cmp -s "$SELF" "$MUT_B" && bad "build-gate mutation did not change the source (marker lost)" || ok "build-gate mutation applied"
  cmp -s "$SELF" "$MUT_C" && bad "conflict-gate mutation did not change the source (marker lost)" || ok "conflict-gate mutation applied"
  rm -rf "$W" "$T/logs"; git -C "$R" worktree prune; git -C "$R" branch -q -D "$CAND_BRANCH" 2>/dev/null
  printf 'base\tbase\nmerge\toka\nmerge\tbrk\n' > "$B"
  env "QA_CANDIDATE_BUILD_CMD=test ! -e BROKEN" QA_CANDIDATE_LOGDIR="$T/logs" bash "$MUT_B" --branches "$B" --repo "$R" --wt "$W" >/dev/null 2>&1
  [ -e "$W/BROKEN" ] && ok "build-gate mutant lets the build-breaker in (the check is load-bearing)" || bad "build-gate mutant NOT caught"
  rm -rf "$W"; git -C "$R" worktree prune; git -C "$R" branch -q -D "$CAND_BRANCH" 2>/dev/null
  printf 'base\tbase\nmerge\toka\nmerge\tconf\n' > "$B"
  env "QA_CANDIDATE_BUILD_CMD=true" QA_CANDIDATE_LOGDIR="$T/logs" bash "$MUT_C" --branches "$B" --repo "$R" --wt "$W" >/dev/null 2>&1; rc=$?
  git -C "$W" show "HEAD:evidence/qa-candidate/MANIFEST.tsv" 2>/dev/null | grep -qP '^conf\t.*\tconflict\t' \
    && bad "conflict-gate mutant NOT caught" || ok "conflict-gate mutant no longer records the conflict (the check is load-bearing)"
  rm -rf "$T"
  printf 'prove-failure: %d passed, %d failed\n' "$pass" "$fail"
  [ "$fail" = 0 ]
}
if [ "$PROVE" = 1 ]; then prove_failure; exit $?; fi

# ------------------------------------------------------------------- real run
command -v git >/dev/null 2>&1 || undet "git not found"
[ -d "$REPO/.git" ] || [ -f "$REPO/.git" ] || git -C "$REPO" rev-parse --git-dir >/dev/null 2>&1 || undet "not a git repository: $REPO"
[ -r "$BRANCHES" ] || undet "branch list not readable: $BRANCHES"
G() { git -C "$REPO" "$@"; }
W() { git -C "$WT" "$@"; }

BASE_BRANCH="$(awk -F'\t' '$1=="base"{print $2; exit}' "$BRANCHES")"
[ -n "$BASE_BRANCH" ] || undet "no 'base' row in $BRANCHES"
BASE_SHA="$(G rev-parse --verify -q "refs/heads/$BASE_BRANCH^{commit}")" || undet "base branch '$BASE_BRANCH' not found in $REPO"

# worktree
if [ ! -e "$WT" ]; then
  [ "$STATUS_ONLY" = 1 ] && undet "candidate worktree $WT does not exist yet (run without --status)"
  mkdir -p "$(dirname "$WT")" || undet "cannot create $(dirname "$WT")"
  if G rev-parse --verify -q "refs/heads/$CAND_BRANCH" >/dev/null; then
    G worktree add "$WT" "$CAND_BRANCH" >/dev/null 2>&1 || undet "git worktree add failed"
  else
    G worktree add -b "$CAND_BRANCH" "$WT" "$BASE_BRANCH" >/dev/null 2>&1 || undet "git worktree add -b failed"
  fi
  say "created worktree $WT on $CAND_BRANCH from $BASE_BRANCH@${BASE_SHA:0:12}"
fi
[ "$(W rev-parse --abbrev-ref HEAD 2>/dev/null)" = "$CAND_BRANCH" ] || undet "$WT is not on branch $CAND_BRANCH"
[ -z "$(W status --porcelain 2>/dev/null)" ] || undet "candidate worktree is dirty; commit or clean it first ($WT)"
W rev-parse -q --verify MERGE_HEAD >/dev/null 2>&1 && undet "a merge is already in progress in $WT"
W config rerere.enabled true; W config rerere.autoupdate true

MAN_DIR="evidence/qa-candidate"; MAN="$MAN_DIR/MANIFEST.tsv"
ROWS="$(mktemp)"; trap 'rm -f "$ROWS"' EXIT
RC=0
row() { printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" >> "$ROWS"; }
merge_commit_of() { W log --merges --format='%h %s' --grep="^merge $1 (" -1 2>/dev/null; }

run_build() {
  [ "$DO_BUILD" = 1 ] || return 0
  ( cd "$WT" && bash -c "$BUILD_CMD" ) >"$1" 2>&1
}

row base "$BASE_BRANCH" "base" "${BASE_SHA:0:12}"
while IFS=$'\t' read -r kind br reason _; do
  case "$kind" in merge) ;; *) continue ;; esac
  [ -n "$br" ] || continue
  sha="$(G rev-parse --verify -q "refs/heads/$br^{commit}")" || {
    warn "$br: branch not found"; row "$br" "-" missing "no local branch"; RC=1; continue; }
  s12="${sha:0:12}"
  if [ -n "${reason:-}" ]; then row "$br" "$s12" skipped "configured: $reason"; continue; fi
  if W merge-base --is-ancestor "$sha" HEAD 2>/dev/null; then
    mc="$(merge_commit_of "$br")"; st=merged
    case "$mc" in *'[conflict-resolved]'*) st=conflict-resolved ;; esac
    if [ -n "$mc" ]; then note="merge commit ${mc%% *}"; else note="tip contained in base or another merged branch"; fi
    row "$br" "$s12" "$st" "$note"
    continue
  fi
  [ "$STATUS_ONLY" = 1 ] && { row "$br" "$s12" pending "would merge ($(W rev-list --count HEAD..$sha) commits)"; continue; }
  say "merging $br @ $s12"
  mout="$(W merge --no-ff --no-commit "$sha" 2>&1)"; mrc=$?
  unmerged="$(W diff --name-only --diff-filter=U 2>/dev/null | tr '\n' ' ')"
  if [ -n "$unmerged" ]; then # MUT:conflict-gate
    W merge --abort >/dev/null 2>&1
    warn "$br: CONFLICT in: $unmerged"
    row "$br" "$s12" conflict "needs union resolution in $WT: $unmerged"; RC=1; continue
  fi
  if [ "$mrc" != 0 ]; then
    W merge --abort >/dev/null 2>&1
    warn "$br: git merge failed without conflicts: $(printf '%s' "$mout" | head -2 | tr '\n' ' ')"
    row "$br" "$s12" error "git merge failed: $(printf '%s' "$mout" | head -1)"; RC=1; continue
  fi
  if ! W rev-parse -q --verify MERGE_HEAD >/dev/null 2>&1; then
    row "$br" "$s12" merged "no-op (nothing to commit)"; continue
  fi
  mkdir -p "$LOGDIR"; blog="$LOGDIR/build-$br-$s12.log"
  if ! run_build "$blog"; then # MUT:build-gate
    W merge --abort >/dev/null 2>&1
    warn "$br: BUILD BREAK after merge; rejected (log: $blog)"
    row "$br" "$s12" skipped-build-break "go build failed after merge; log $blog"; RC=1; continue
  fi
  W commit -q -m "merge $br ($s12) into $CAND_BRANCH" -m "$TRAILER" || { W merge --abort >/dev/null 2>&1; undet "commit failed for $br"; }
  mc="$(merge_commit_of "$br")"; st=merged
  case "$mc" in *'[conflict-resolved]'*) st=conflict-resolved ;; esac
  row "$br" "$s12" "$st" "merge commit ${mc%% *}"
done < "$BRANCHES"

# qa-fix commits (fixes made inside the candidate for merge-induced breakage)
W log --reverse --format='%h%x09%s' "$BASE_SHA..HEAD" --no-merges --grep='^qa-fix:' 2>/dev/null | \
  while IFS=$'\t' read -r h s; do printf 'qa-fix\t%s\tqa-fix\t%s\n' "$h" "$s"; done >> "$ROWS"

{ printf 'branch\tsha\tstatus\tnotes\n'; cat "$ROWS"; } > "$ROWS.new"
if [ "$STATUS_ONLY" = 1 ]; then cat "$ROWS.new"; rm -f "$ROWS.new"; exit "$RC"; fi
mkdir -p "$WT/$MAN_DIR"
if ! cmp -s "$ROWS.new" "$WT/$MAN" 2>/dev/null; then
  cp "$ROWS.new" "$WT/$MAN"
  W add "$MAN" && W commit -q -m "qa-candidate: update MANIFEST" -m "$TRAILER" || undet "cannot commit MANIFEST"
fi
rm -f "$ROWS.new"
cat "$WT/$MAN"
say "candidate HEAD $(W rev-parse --short=12 HEAD) in $WT (rc $RC)"
exit "$RC"
