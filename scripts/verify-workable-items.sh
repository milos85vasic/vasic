#!/usr/bin/env bash
#
# verify-workable-items.sh — the §11.4.93 / §11.4.95 / §11.4.148 workable-items
# gate for this umbrella.
#
# WHAT IT ASSERTS
# ---------------
#   G1  the SQLite SSoT exists at the canonical path §11.4.93 names,
#       `docs/workable_items.db`
#   G2  it is NOT gitignored. §11.4.95, verbatim: "TRACKED in git at canonical
#       path docs/workable_items.db. NEVER gitignored regardless of file-size or
#       'build-artefact-class' heuristics"
#   G3  it is TRACKED by git. Before the adopting commit lands this is honestly
#       UNDETERMINED (rc 2), never a pass — a file that exists and is not
#       ignored is not yet a file in history.
#   G4  the sub-project identifier roster covers the fleet derived from
#       `.gitmodules`, in both directions
#   G5  the umbrella validator is green: §11.4.148(D1) status+type+id on every
#       item, §11.4.33 closure vocabulary, §11.4.91 description floor,
#       §11.4.54 uniqueness and sequence, prefix-in-roster membership
#   G6  the CANONICAL upstream validator is green. This is a deliberate
#       producer-is-not-verifier split (§11.4.240): the rows are written by this
#       repository's own tool, and checked by the constitution submodule's
#       binary, which this repository does not author. G6 has already caught two
#       real defects the umbrella validator did not look for — items with no
#       `doc_segments` row, and closure evidence paths that did not resolve.
#
# THREE-VALUED, and 2 is never a pass:
#   0  clean          1  a real finding          2  could not determine
# A FINDING OUTRANKS AN UNDETERMINED, so a leg that cannot run can never mask a
# violation another leg did see.
#
# PAIRED PROOF (§1.1). `--prove-failure` runs six mutations and one control.
# Every mutation is DATA — a row edited or deleted in a THROWAWAY COPY of the
# database, or a throwaway git repository — never an edit to this script or to
# the validator's source. A gate whose proof works by weakening the gate proves
# nothing.
#
# USAGE
#   bash scripts/verify-workable-items.sh
#   bash scripts/verify-workable-items.sh --db <path>      # check another DB
#   bash scripts/verify-workable-items.sh --prove-failure  # the §1.1 paired proof
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT" || exit 2

DB_REL="docs/workable_items.db"
CANON="submodules/constitution/scripts/workable-items/bin/workable-items-linux"
TOOL_SRC="_tools/workable-items"
TOOL_BIN="$TOOL_SRC/bin/workable-items-vsc"

# Scratch lives under the user cache, never /tmp: /tmp on this host is a small
# tmpfs, and no host path is hardcoded — TMPDIR wins when the caller sets it.
SCRATCH_BASE="${TMPDIR:-$HOME/.cache}/vasic-workable-items"

FINDINGS=0
UNDET=0

finding() { printf 'FINDING  %s\n' "$*"; FINDINGS=$((FINDINGS + 1)); }
undet()   { printf 'UNDET    %s\n' "$*"; UNDET=$((UNDET + 1)); }
ok()      { printf 'OK       %s\n' "$*"; }

verdict() {
  printf '\n'
  if [ "$FINDINGS" -gt 0 ]; then
    printf '❌ workable-items: %d finding(s), %d undetermined.\n' "$FINDINGS" "$UNDET"
    return 1
  fi
  if [ "$UNDET" -gt 0 ]; then
    printf '⚠️  workable-items: COULD NOT DETERMINE — %d unresolved condition(s). A 2 is never a pass.\n' "$UNDET"
    return 2
  fi
  printf '✅ workable-items: clean.\n'
  return 0
}

# build_tool ensures the umbrella binary exists. Offline by construction: the
# module cache already carries every dependency, and GOPROXY=off makes a missing
# one an honest failure rather than a silent network reach.
build_tool() {
  if ! command -v go >/dev/null 2>&1; then
    return 2
  fi
  ( cd "$TOOL_SRC" && GOFLAGS=-mod=mod GOPROXY=off CGO_ENABLED=0 \
      go build -o bin/workable-items-vsc . ) >/dev/null 2>&1
}

# ── G2 as a reusable predicate, so the paired proof can exercise the real
# decision procedure against a repository it constructs, rather than against a
# re-implementation of it.
# Returns 0 when the DB is NOT ignored (the good state), 1 when it IS ignored.
db_not_ignored() {
  local repo="$1" rel="$2"
  if git -C "$repo" check-ignore -q "$rel" 2>/dev/null; then
    return 1
  fi
  return 0
}

main_check() {
  local db_rel="$1"

  # G1 — presence.
  if [ ! -f "$db_rel" ]; then
    undet "G1 the workable-items database is absent at $db_rel — no claim about its contents is possible"
    return
  fi
  ok "G1 database present at $db_rel ($(wc -c < "$db_rel") bytes)"

  # G2 — not gitignored (§11.4.95).
  if db_not_ignored "$REPO_ROOT" "$db_rel"; then
    ok "G2 $db_rel is NOT gitignored (§11.4.95)"
  else
    finding "G2 $db_rel IS gitignored — §11.4.95 forbids it outright: the DB is authoritative source data, not a build artefact"
  fi

  # G3 — tracked.
  if git -C "$REPO_ROOT" ls-files --error-unmatch "$db_rel" >/dev/null 2>&1; then
    ok "G3 $db_rel is tracked by git"
  elif git -C "$REPO_ROOT" diff --cached --name-only 2>/dev/null | grep -qxF "$db_rel"; then
    ok "G3 $db_rel is staged for the next commit"
  else
    undet "G3 $db_rel exists and is not ignored, but is neither tracked nor staged — it is not yet in history, and a file that is merely present is not a source of truth anyone else can read"
  fi

  # Tool availability.
  if [ ! -x "$TOOL_BIN" ]; then
    build_tool
    case "$?" in
      2) undet "G4/G5 the umbrella tool is not built and no go toolchain is on PATH"; ;;
      0) : ;;
      *) undet "G4/G5 the umbrella tool failed to build; the roster and integrity legs did not run" ;;
    esac
  fi

  if [ -x "$TOOL_BIN" ]; then
    # G4 — roster coverage.
    local out rc
    out="$("$TOOL_BIN" roster --repo "$REPO_ROOT" 2>&1)"; rc=$?
    case "$rc" in
      0) ok "G4 roster: every declared submodule carries exactly one identifier" ;;
      1) finding "G4 roster: $(printf '%s' "$out" | grep -c '^FINDING' ) finding(s) — $(printf '%s' "$out" | grep '^FINDING' | head -3 | tr '\n' ';')" ;;
      *) undet "G4 roster: $(printf '%s' "$out" | grep -E '^COULD NOT DETERMINE' | head -1)" ;;
    esac

    # G5 — umbrella integrity validator.
    out="$("$TOOL_BIN" validate --repo "$REPO_ROOT" --db "$db_rel" 2>&1)"; rc=$?
    case "$rc" in
      0) ok "G5 umbrella validate: $(printf '%s' "$out" | tail -1)" ;;
      1) finding "G5 umbrella validate: $(printf '%s' "$out" | grep -c '^FINDING') integrity violation(s)"
         printf '%s\n' "$out" | grep '^FINDING' | head -10 | sed 's/^/           /' ;;
      *) undet "G5 umbrella validate could not determine: $(printf '%s' "$out" | tail -1)" ;;
    esac
  fi

  # G6 — the independent upstream verifier.
  if [ ! -x "$CANON" ]; then
    undet "G6 the canonical validator is absent at $CANON — the submodule may not be initialised"
  else
    local out rc
    out="$("$CANON" validate --db "$db_rel" 2>&1)"; rc=$?
    case "$rc" in
      0) ok "G6 canonical validate (independent verifier): $(printf '%s' "$out" | head -1)" ;;
      1) finding "G6 canonical validate: $(printf '%s' "$out" | head -1)"
         printf '%s\n' "$out" | sed -n '2,8p' | sed 's/^/           /' ;;
      *) undet "G6 canonical validate could not determine (rc $rc)" ;;
    esac
  fi
}

# ── §1.1 paired proof ───────────────────────────────────────────────────────

prove_failure() {
  local passed=0 failed=0
  local work="$SCRATCH_BASE/prove.$$"
  mkdir -p "$work" || { echo "PROOF COULD NOT RUN: cannot create $work"; return 2; }
  # shellcheck disable=SC2064
  trap "rm -rf '$work'" EXIT

  if [ ! -f "$DB_REL" ]; then
    echo "PROOF COULD NOT RUN: no database at $DB_REL to copy from"
    return 2
  fi
  if [ ! -x "$TOOL_BIN" ] && ! build_tool; then
    echo "PROOF COULD NOT RUN: the umbrella tool is not available"
    return 2
  fi

  assert() { # assert <label> <expected-rc> <actual-rc>
    if [ "$2" = "$3" ]; then
      printf 'PASS  %-46s rc=%s\n' "$1" "$3"; passed=$((passed + 1))
    else
      printf 'FAIL  %-46s want rc=%s got rc=%s\n' "$1" "$2" "$3"; failed=$((failed + 1))
    fi
  }

  # sqlite driver access goes through the tool's own module so no sqlite3 CLI
  # dependency is introduced; mutations are applied with python3's sqlite3,
  # which is stdlib and already required by other gates in this tree.
  if ! command -v python3 >/dev/null 2>&1; then
    echo "PROOF COULD NOT RUN: python3 is not on PATH; mutations cannot be applied"
    return 2
  fi

  mutate() { # mutate <name> <sql>
    local name="$1" sql="$2"
    cp "$DB_REL" "$work/$name.db" || return 2
    python3 - "$work/$name.db" "$sql" <<'PY'
import sqlite3, sys
con = sqlite3.connect(sys.argv[1])
con.executescript(sys.argv[2])
con.commit()
con.close()
PY
  }

  run_validate() { "$TOOL_BIN" validate --repo "$REPO_ROOT" --db "$1" >/dev/null 2>&1; echo $?; }

  # CONTROL — an unmutated copy must still be clean. Without this, every
  # mutation below could be passing for the wrong reason (the copy itself).
  cp "$DB_REL" "$work/control.db"
  assert "CONTROL well-formed copy validates clean" 0 "$(run_validate "$work/control.db")"

  # M1 — an identifier whose prefix names no sub-project.
  mutate m1 "INSERT INTO items(atm_id,type,status,severity,title,description,current_location)
             VALUES('ZZZ-001','Task','Queued','','mutation','A mutation row whose three-letter prefix names no sub-project in the roster.','Issues');
             INSERT INTO item_provenance VALUES('ZZZ-001','spec-task','x','y','checkbox-state','');"
  assert "M1 prefix not in the roster" 1 "$(run_validate "$work/m1.db")"

  # M2 — a gap in a prefix's monotonic sequence (§11.4.54(4)).
  mutate m2 "DELETE FROM items WHERE atm_id='WSP-002'; DELETE FROM item_provenance WHERE atm_id='WSP-002';"
  assert "M2 gap in the id sequence" 1 "$(run_validate "$work/m2.db")"

  # M3 — §11.4.33 closure vocabulary violated: a Bug closed as Completed.
  mutate m3 "UPDATE items SET type='Bug' WHERE status='Completed (→ Fixed.md)' AND atm_id=(SELECT atm_id FROM items WHERE status='Completed (→ Fixed.md)' LIMIT 1);"
  assert "M3 closure status mismatched to type" 1 "$(run_validate "$work/m3.db")"

  # M4 — §11.4.91 description floor breached.
  mutate m4 "UPDATE items SET description='too short' WHERE atm_id='VSC-002';"
  assert "M4 description below the §11.4.91 floor" 1 "$(run_validate "$work/m4.db")"

  # M5 — an item whose status rests on nothing recorded.
  mutate m5 "DELETE FROM item_provenance WHERE atm_id='VSC-003';"
  assert "M5 item with no provenance row" 1 "$(run_validate "$work/m5.db")"

  # M6 — the §11.4.95 tracking rule, exercised against a throwaway repository
  # rather than a re-implementation of the predicate. The SAME db_not_ignored
  # function decides both directions.
  local fake="$work/fakerepo"
  mkdir -p "$fake/docs"
  git -C "$fake" init -q 2>/dev/null
  : > "$fake/docs/workable_items.db"
  if db_not_ignored "$fake" "docs/workable_items.db"; then
    printf 'PASS  %-46s not-ignored recognised\n' "M6 control: DB with no ignore rule"; passed=$((passed + 1))
  else
    printf 'FAIL  %-46s a DB with no ignore rule read as ignored\n' "M6 control"; failed=$((failed + 1))
  fi
  printf 'docs/workable_items.db\n' > "$fake/.gitignore"
  if db_not_ignored "$fake" "docs/workable_items.db"; then
    printf 'FAIL  %-46s a gitignored DB read as NOT ignored\n' "M6 gitignored DB"; failed=$((failed + 1))
  else
    printf 'PASS  %-46s gitignored DB detected\n' "M6 gitignored DB"; passed=$((passed + 1))
  fi

  # M7 — the canonical upstream verifier must also be able to go red, or G6 is
  # a decorative leg. Its own documented invariant: a closed item whose
  # evidence path does not resolve.
  if [ -x "$CANON" ]; then
    mutate m7 "UPDATE item_history SET evidence_path='docs/this-path-does-not-exist.md' WHERE event_type='Completed';"
    "$CANON" validate --db "$work/m7.db" >/dev/null 2>&1
    assert "M7 canonical verifier goes red on bad evidence" 1 "$?"
  else
    printf 'SKIP  %-46s canonical verifier absent\n' "M7"
  fi

  printf '\nprove-failure: %d passed / %d failed\n' "$passed" "$failed"
  [ "$failed" -eq 0 ] && return 0
  return 1
}

# ── argv ────────────────────────────────────────────────────────────────────

DB_ARG="$DB_REL"
MODE=check
while [ $# -gt 0 ]; do
  case "$1" in
    --prove-failure) MODE=prove; shift ;;
    --db) DB_ARG="${2:-}"; shift 2 || exit 2 ;;
    -h|--help) sed -n '2,50p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) printf 'unknown option %q\n' "$1" >&2; exit 2 ;;
  esac
done

if [ "$MODE" = prove ]; then
  prove_failure
  exit $?
fi

printf 'workable-items gate — §11.4.93 / §11.4.95 / §11.4.148\n\n'
main_check "$DB_ARG"
verdict
exit $?
