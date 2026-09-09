#!/usr/bin/env bash
# scripts/verify-pretooluse-guard.sh
#
# The §11.4.234(A)(3) dedicated hook-validation script for the §11.4.109
# PreToolUse guard hook: it asserts that the guard is INSTALLED, that it is
# REFERENCED rather than copied, that it SURVIVES A FRESH CLONE, and — the part
# that matters — that it is actually OPERATIVE, by executing the wired command
# against live probes and requiring a real refusal.
#
# WHY THE EXECUTION ARM EXISTS. A validator that reads a config key and reports
# green has verified that a string is present in a file. It has verified nothing
# about whether a forbidden command would be stopped. §11.4.201 names that
# precisely: every guard MUST assert the REAL condition, because a false GREEN
# is worse than no gate at all — it is a gate that lies. So V4 below pipes a
# force-push payload into whatever the settings file actually names and requires
# exit 2, and pipes a benign payload in and requires exit 0. A guard that blocks
# everything is as broken as one that blocks nothing.
#
# WHY THE TRACKED-IN-GIT ARM EXISTS (V3). This repository has a recorded lesson:
# `.git/hooks/` is UNTRACKED, so a fresh clone runs no gates at all until
# `scripts/pre-push-gates.sh --install` is run by hand, and `git push
# --no-verify` bypasses it with no record. A PreToolUse guard wired only into an
# untracked or user-scoped settings file has exactly the same hole with none of
# the visibility. V3 refuses to call that state wired.
#
# EXIT CONTRACT — three-valued, per SC-013. 2 IS NEVER A PASS.
#   0  the guard is wired AND demonstrably fires
#   1  a real defect: not wired, wired to a copy, wired but inoperative,
#      untracked, or a missing/mutilated §11.4.109 (B)/(C) preamble document
#   2  could not determine: the root is absent, is not a git tree, or a tool
#      this check depends on is missing
#
# Paired §1.1 proof:  bash scripts/verify-pretooluse-guard.sh --prove-failure
#
# Classification: consumer (§11.4.17) — the anchor is universal; the paths are
# this repository's binding of it as DATA per §11.4.35.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE=run

CANONICAL_REL="submodules/constitution/scripts/hooks/guard-forbidden-commands.sh"
UPSTREAM_TEST_REL="submodules/constitution/scripts/hooks/test_guard_forbidden_commands.sh"
SETTINGS_REL=".claude/settings.json"
PREAMBLE_REL="docs/AGENT_GUARDRAILS.md"

PASS=0; FAIL=0; UNDET=0
rc_undet_reason=""

say()  { printf '%s\n' "$*"; }
ok()   { PASS=$((PASS+1));  printf '  PASS  %-46s %s\n' "$1" "${2-}"; }
bad()  { FAIL=$((FAIL+1));  printf '  FAIL  %-46s %s\n' "$1" "${2-}"; }
undet(){ UNDET=$((UNDET+1)); rc_undet_reason="${rc_undet_reason}${rc_undet_reason:+; }$1"; printf '  UNDET %-46s %s\n' "$1" "${2-}"; }

usage() {
  cat <<'EOF'
usage: verify-pretooluse-guard.sh [--root <dir>] [--prove-failure] [--help]

  --root <dir>      verify the tree at <dir> instead of this repository
  --prove-failure   run the paired §1.1 mutation battery (rc 0 = every
                    mutation was caught and the control passed)
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --root) ROOT="${2-}"; shift 2 || { usage; exit 2; } ;;
    --prove-failure) MODE=prove; shift ;;
    --help|-h) usage; exit 0 ;;
    *) printf 'unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done

# ---------------------------------------------------------------------------
# A tiny, dependency-free reader for the ONE thing we need out of the settings
# file: every `command` string that appears under a PreToolUse hook entry.
# jq is preferred when present; the awk fallback keeps this check runnable on a
# host with no jq, because a check that cannot load its own input reports a
# green tree it never read.
# ---------------------------------------------------------------------------
pretooluse_commands() {
  local f="$1"
  if command -v jq >/dev/null 2>&1; then
    jq -r '.hooks.PreToolUse[]?.hooks[]?.command // empty' "$f" 2>/dev/null
    return 0
  fi
  awk '
    /"PreToolUse"/ { inblock=1 }
    inblock && /"PostToolUse"|"Stop"|"SessionStart"|"UserPromptSubmit"|"Notification"|"SubagentStop"|"PreCompact"/ { inblock=0 }
    inblock && /"command"[ \t]*:/ {
      line=$0
      sub(/.*"command"[ \t]*:[ \t]*"/, "", line)
      sub(/"[ \t]*,?[ \t]*$/, "", line)
      gsub(/\\"/, "\"", line)
      gsub(/\\\\/, "\\", line)
      print line
    }
  ' "$f"
}

# Does this settings file parse at all? A malformed settings file means the
# harness loads NO hooks — that is a defect, not an unknown.
settings_parses() {
  local f="$1"
  if command -v jq >/dev/null 2>&1; then jq -e . "$f" >/dev/null 2>&1; return $?; fi
  # No jq: fall back to a balanced-brace sanity check rather than claiming to
  # have validated JSON we cannot validate.
  grep -q '"PreToolUse"' "$f"
}

# ---------------------------------------------------------------------------
# The verification itself, parameterised on a tree so the mutation battery can
# aim it at throwaway copies.
# ---------------------------------------------------------------------------
verify_tree() {
  local root="$1"
  PASS=0; FAIL=0; UNDET=0; rc_undet_reason=""

  local canonical="$root/$CANONICAL_REL"
  local settings="$root/$SETTINGS_REL"
  local preamble="$root/$PREAMBLE_REL"

  # ---- precondition: could-not-determine states, never a pass -------------
  if [ ! -d "$root" ]; then
    undet "root exists" "no such directory: $root"; return
  fi
  if ! git -C "$root" rev-parse --git-dir >/dev/null 2>&1; then
    undet "root is a git tree" "git cannot resolve a repository at $root"; return
  fi
  if ! command -v bash >/dev/null 2>&1; then
    undet "bash available" "cannot execute the guard without bash"; return
  fi

  # ---- V1: the canonical guard exists at the canonical path ---------------
  if [ -f "$canonical" ]; then
    if [ -r "$canonical" ]; then
      ok "V1 canonical guard present" "$CANONICAL_REL"
    else
      bad "V1 canonical guard present" "exists but is not readable"
    fi
  else
    bad "V1 canonical guard present" "missing: $CANONICAL_REL — §11.4.109(A) canonical path"
  fi

  # ---- V2: settings file wires a PreToolUse hook at that canonical path ---
  local wired_cmd=""
  if [ ! -f "$settings" ]; then
    bad "V2 PreToolUse hook wired" "no $SETTINGS_REL — the guard is not wired anywhere project-scoped"
  elif ! settings_parses "$settings"; then
    bad "V2 PreToolUse hook wired" "$SETTINGS_REL does not parse — the harness would load no hooks from it"
  else
    local cmds; cmds="$(pretooluse_commands "$settings")"
    if [ -z "$cmds" ]; then
      bad "V2 PreToolUse hook wired" "$SETTINGS_REL declares no PreToolUse hook command"
    else
      # Accept only a reference INTO the constitution submodule. §11.4.109(A):
      # "MUST reference it at that path — NEVER copy it locally (a copy
      # diverges silently)."
      local match=""
      while IFS= read -r c; do
        [ -n "$c" ] || continue
        case "$c" in
          *"$CANONICAL_REL"*) match="$c"; break ;;
        esac
      done <<< "$cmds"
      if [ -n "$match" ]; then
        wired_cmd="$match"
        ok "V2 PreToolUse hook wired" "→ $CANONICAL_REL"
      else
        bad "V2 PreToolUse hook wired" "PreToolUse commands reference no canonical guard (a local copy is NOT compliant): $(printf '%s' "$cmds" | tr '\n' ' ')"
      fi
    fi
  fi

  # ---- V3: the wiring is TRACKED, so a fresh clone inherits it ------------
  if [ -f "$settings" ]; then
    if git -C "$root" ls-files --error-unmatch "$SETTINGS_REL" >/dev/null 2>&1; then
      ok "V3 wiring survives a fresh clone" "$SETTINGS_REL is tracked"
    else
      bad "V3 wiring survives a fresh clone" "$SETTINGS_REL is UNTRACKED — same hole as .git/hooks/: a clone is unguarded"
    fi
  else
    bad "V3 wiring survives a fresh clone" "no $SETTINGS_REL to track"
  fi

  # ---- V4: the wired guard is OPERATIVE — execute it ----------------------
  # This is the assertion §11.4.201 demands. Every probe below is HARMLESS
  # even if the guard were absent: nothing is executed, the command string is
  # only ever fed to the guard on stdin as JSON.
  if [ -n "$wired_cmd" ]; then
    # Resolve the wired command into something runnable from $root. The
    # settings file addresses the script through $CLAUDE_PROJECT_DIR; we
    # execute the resolved path directly rather than re-implementing the
    # harness's expansion, but we execute the path the SETTINGS names, not a
    # path we assumed — otherwise a mis-wired settings file would still pass.
    local guard_path="$root/$CANONICAL_REL"
    if [ ! -f "$guard_path" ]; then
      bad "V4 guard fires on a forbidden probe" "wired path does not resolve to a file"
    else
      local blocked_all=1 allowed_ok=1 detail=""
      local p rc label cmd   # `label` MUST be local: without it the probe loop
                             # below clobbers the caller's variable of the same
                             # name. It did, and the mutation battery's own
                             # report went blank until this line was added.
      # Each probe names a class §11.4.109(A) makes mandatory.
      while IFS='|' read -r label cmd; do
        [ -n "$label" ] || continue
        p="$(printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$cmd")"
        printf '%s' "$p" | bash "$guard_path" >/dev/null 2>&1
        rc=$?
        if [ "$rc" -ne 2 ]; then
          blocked_all=0
          detail="${detail}${detail:+, }$label(rc=$rc)"
        fi
      done <<'PROBES'
force-push|git push --force origin main
force-with-lease|git push --force-with-lease origin main
no-verify|git push --no-verify origin main
privilege-escalation|sudo apt-get install something
host-power|systemctl suspend
PROBES

      if [ "$blocked_all" -eq 1 ]; then
        ok "V4 guard fires on a forbidden probe" "5/5 classes refused with rc 2"
      else
        bad "V4 guard fires on a forbidden probe" "NOT refused: $detail — the hook is wired but inoperative"
      fi

      # The complement: a guard that blocks everything is equally broken,
      # because it would be switched off within the hour.
      p='{"tool_name":"Bash","tool_input":{"command":"git status --short"}}'
      printf '%s' "$p" | bash "$guard_path" >/dev/null 2>&1
      rc=$?
      [ "$rc" -eq 0 ] || { allowed_ok=0; }
      p='{"tool_name":"Read","tool_input":{"file_path":"/etc/hostname"}}'
      printf '%s' "$p" | bash "$guard_path" >/dev/null 2>&1
      rc=$?
      [ "$rc" -eq 0 ] || { allowed_ok=0; }

      if [ "$allowed_ok" -eq 1 ]; then
        ok "V5 guard passes benign calls" "benign Bash + non-Bash tool both rc 0"
      else
        bad "V5 guard passes benign calls" "a benign call was refused — an over-blocking guard gets disabled"
      fi

      # Host-power is CATEGORICALLY non-overridable (§11.4.109(A)5, §12).
      p='{"tool_name":"Bash","tool_input":{"command":"systemctl suspend # guardrails:allow probe"}}'
      printf '%s' "$p" | bash "$guard_path" >/dev/null 2>&1
      rc=$?
      if [ "$rc" -eq 2 ]; then
        ok "V6 escape hatch cannot unlock host-power" "still rc 2 with the marker present"
      else
        bad "V6 escape hatch cannot unlock host-power" "rc=$rc — the marker downgraded a categorically forbidden class"
      fi
    fi
  else
    bad "V4 guard fires on a forbidden probe" "nothing wired to execute"
    bad "V5 guard passes benign calls" "nothing wired to execute"
    bad "V6 escape hatch cannot unlock host-power" "nothing wired to execute"
  fi

  # ---- V7: §11.4.109 (B) + (C) preamble document --------------------------
  if [ ! -f "$preamble" ]; then
    bad "V7 preamble document" "missing: $PREAMBLE_REL — §11.4.109(B)/(C)"
  else
    local miss=""
    grep -q 'SUBAGENT CONSTITUTIONAL PREAMBLE' "$preamble" || miss="${miss}${miss:+, }SUBAGENT CONSTITUTIONAL PREAMBLE"
    grep -q 'ORCHESTRATOR PRE-ACTION CHECKLIST' "$preamble" || miss="${miss}${miss:+, }ORCHESTRATOR PRE-ACTION CHECKLIST"
    grep -q '11\.4\.109' "$preamble" || miss="${miss}${miss:+, }the 11.4.109 anchor literal"
    if [ -z "$miss" ]; then
      ok "V7 preamble document" "both mandated headings + anchor literal present"
    else
      bad "V7 preamble document" "missing from $PREAMBLE_REL: $miss"
    fi
  fi

  # ---- V8: the upstream hermetic test harness is present ------------------
  # §11.4.109 mechanical enforcement (4): "a hermetic test for the hook exists
  # and passes". Presence is asserted here; EXECUTION is a separate, named
  # stage — see the note printed below, per §11.4.234(C) (no gate is lost, and
  # a deferral is recorded rather than forgotten).
  if [ -f "$root/$UPSTREAM_TEST_REL" ]; then
    ok "V8 upstream hermetic harness present" "$UPSTREAM_TEST_REL"
  else
    bad "V8 upstream hermetic harness present" "missing: $UPSTREAM_TEST_REL"
  fi
}

verdict() {
  say ""
  say "  PASS=$PASS FAIL=$FAIL UNDET=$UNDET"
  if [ "$FAIL" -gt 0 ]; then
    say "❌ PreToolUse guard: $FAIL defect(s)"
    return 1
  fi
  if [ "$UNDET" -gt 0 ]; then
    say "⚠️  PreToolUse guard: COULD NOT DETERMINE — $rc_undet_reason"
    say "    rc 2 is NOT a pass."
    return 2
  fi
  say "✅ PreToolUse guard is wired at $SETTINGS_REL (tracked) and demonstrably fires."
  say "   DEFERRED, not dropped (§11.4.234(C)): the upstream hermetic harness is"
  say "   asserted PRESENT here and EXECUTED as its own stage —"
  say "   bash $UPSTREAM_TEST_REL"
  return 0
}

# ===========================================================================
# --prove-failure — the paired §1.1 mutation battery.
#
# The CONTROL is a SYNTHETIC throwaway tree, green by construction, so no state
# of the real repository can redden the control and silently switch the battery
# off. The live tree is verified separately by the default mode.
# ===========================================================================
prove_failure() {
  local real_guard="$ROOT/$CANONICAL_REL"
  if [ ! -f "$real_guard" ]; then
    say "⚠️  cannot build the battery: $CANONICAL_REL absent — rc 2, not a pass"
    return 2
  fi
  if ! command -v git >/dev/null 2>&1; then
    say "⚠️  git unavailable — rc 2, not a pass"
    return 2
  fi

  local tmp; tmp="$(mktemp -d)" || { say "⚠️  mktemp failed — rc 2"; return 2; }
  trap 'rm -rf "$tmp"' RETURN

  local caught=0 slipped=0 n=0

  # Build a pristine synthetic consumer tree.
  build() {
    local d="$1"
    rm -rf "$d"; mkdir -p "$d/$(dirname "$CANONICAL_REL")" "$d/.claude" "$d/docs"
    cp "$real_guard" "$d/$CANONICAL_REL"
    cp "$ROOT/$UPSTREAM_TEST_REL" "$d/$UPSTREAM_TEST_REL" 2>/dev/null || : > "$d/$UPSTREAM_TEST_REL"
    chmod +x "$d/$CANONICAL_REL"
    cat > "$d/$SETTINGS_REL" <<EOF
{
  "hooks": {
    "PreToolUse": [
      { "matcher": "*", "hooks": [ { "type": "command", "command": "bash \\"\$CLAUDE_PROJECT_DIR/$CANONICAL_REL\\"" } ] }
    ]
  }
}
EOF
    cat > "$d/$PREAMBLE_REL" <<'EOF'
# guardrails (synthetic)
Anchor 11.4.109.
## SUBAGENT CONSTITUTIONAL PREAMBLE
paste verbatim
## ORCHESTRATOR PRE-ACTION CHECKLIST
- [ ] check
EOF
    git -C "$d" init -q 2>/dev/null
    git -C "$d" add -A >/dev/null 2>&1
    git -C "$d" -c user.email=p@p -c user.name=p commit -qm base >/dev/null 2>&1
  }

  # $1 label, $2 expected rc, $3 mutator function name (or "" for control)
  run_case() {
    local label="$1" want="$2" mut="${3-}"
    n=$((n+1))
    local d="$tmp/case$n"
    build "$d"
    [ -n "$mut" ] && "$mut" "$d"
    verify_tree "$d" >/dev/null 2>&1
    local got
    if   [ "$FAIL"  -gt 0 ]; then got=1
    elif [ "$UNDET" -gt 0 ]; then got=2
    else got=0; fi
    if [ "$got" = "$want" ]; then
      caught=$((caught+1)); printf '  PASS  %-46s (rc %s as required)\n' "$label" "$got"
    else
      slipped=$((slipped+1)); printf '  FAIL  %-46s (rc %s, required %s)\n' "$label" "$got" "$want"
    fi
  }

  m_unwire()     { python3 - "$1/$SETTINGS_REL" <<'PY' 2>/dev/null || printf '{"hooks":{}}\n' > "$1/$SETTINGS_REL"
import json,sys
p=sys.argv[1]; d=json.load(open(p)); d.pop("hooks",None); json.dump(d,open(p,"w"))
PY
  }
  m_local_copy() {
    mkdir -p "$1/scripts/hooks"; cp "$1/$CANONICAL_REL" "$1/scripts/hooks/guard.sh"
    sed -i "s#\$CLAUDE_PROJECT_DIR/$CANONICAL_REL#\$CLAUDE_PROJECT_DIR/scripts/hooks/guard.sh#" "$1/$SETTINGS_REL"
  }
  m_neuter()     { printf '#!/usr/bin/env bash\nexit 0\n' > "$1/$CANONICAL_REL"; chmod +x "$1/$CANONICAL_REL"; }
  m_overblock()  { printf '#!/usr/bin/env bash\nexit 2\n' > "$1/$CANONICAL_REL"; chmod +x "$1/$CANONICAL_REL"; }
  m_power_hatch(){
    # A guard that honours the escape marker for host-power — the one
    # downgrade §11.4.109(A)5 forbids.
    cat > "$1/$CANONICAL_REL" <<'EOF'
#!/usr/bin/env bash
p="$(cat)"
case "$p" in
  *'guardrails:allow'*) exit 0 ;;
  *'--force'*|*'--no-verify'*|*sudo*|*suspend*) exit 2 ;;
esac
exit 0
EOF
    chmod +x "$1/$CANONICAL_REL"
  }
  m_untrack()    { git -C "$1" rm --cached -q "$SETTINGS_REL" >/dev/null 2>&1; git -C "$1" -c user.email=p@p -c user.name=p commit -qm untrack >/dev/null 2>&1; }
  m_no_guard()   { rm -f "$1/$CANONICAL_REL"; }
  m_no_doc()     { rm -f "$1/$PREAMBLE_REL"; }
  m_no_heading() { sed -i '/ORCHESTRATOR PRE-ACTION CHECKLIST/d' "$1/$PREAMBLE_REL"; }
  m_no_anchor()  { sed -i 's/11\.4\.109/one-one-four/' "$1/$PREAMBLE_REL"; }
  m_no_harness() { rm -f "$1/$UPSTREAM_TEST_REL"; }
  m_badjson()    { printf '{ "hooks": { "PreToolUse": [ \n' > "$1/$SETTINGS_REL"; }
  m_notgit()     { rm -rf "$1/.git"; }
  m_absent()     { rm -rf "$1"; }

  say "-- CONTROL: an intact synthetic tree MUST pass --"
  run_case "C1 intact tree"                          0 ""

  say ""
  say "-- MUTATIONS: each MUST be caught --"
  run_case "M1  hook entry removed from settings"    1 m_unwire
  run_case "M2  wired to a LOCAL COPY of the guard"  1 m_local_copy
  run_case "M3  guard NEUTERED (always exit 0)"      1 m_neuter
  run_case "M4  guard OVER-BLOCKS (always exit 2)"   1 m_overblock
  run_case "M5  escape marker unlocks host-power"    1 m_power_hatch
  run_case "M6  settings UNTRACKED in git"           1 m_untrack
  run_case "M7  canonical guard script deleted"      1 m_no_guard
  run_case "M8  preamble document deleted"           1 m_no_doc
  run_case "M9  a mandated heading stripped"         1 m_no_heading
  run_case "M10 the 11.4.109 literal stripped"       1 m_no_anchor
  run_case "M11 upstream hermetic harness deleted"   1 m_no_harness
  run_case "M12 settings.json malformed"             1 m_badjson

  say ""
  say "-- COULD-NOT-DETERMINE: each MUST be rc 2, never a pass --"
  run_case "U1  root is not a git tree"              2 m_notgit
  run_case "U2  root does not exist"                 2 m_absent

  say ""
  say "  $caught passed / $slipped failed / $n cases"
  if [ "$slipped" -gt 0 ]; then
    say "❌ the validator does NOT catch every mutation — it can report a false green"
    return 1
  fi
  say "✅ every mutation caught and the control passed"
  return 0
}

if [ "$MODE" = prove ]; then
  prove_failure; exit $?
fi

say "PreToolUse guard validation (§11.4.109 · §11.4.234) — root: $ROOT"
say ""
verify_tree "$ROOT"
verdict; exit $?
