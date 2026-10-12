#!/usr/bin/env bash
# Runtime probe for VSC-375 ("audits enumerate tracked files only").
# Builds a throwaway git repo, commits a clean tracked file, then adds UNTRACKED files and
# runs the three REAL audits from the tree under test (cwd/scripts, or $VSC375_SCRIPTS_DIR):
#   scripts/audit-hardcoded-paths.sh        planted: absolute home path        (rc 1 + file named)
#   scripts/audit-environment-assumptions.sh planted: GNU-only `sed -i`        (rc 1 + file named)
#   scripts/verify-provider-ci.sh           planted: .github/workflows/*.yml   (JSON file_ci_active)
# Controls, in the SAME run as the planted file: a git-IGNORED violating file and a CLEAN untracked
# file must NOT be reported. Provider-ci is pointed at an unadapted host, so no network is used;
# only its file-level count is read.
# Exit: 0 all hold; 1 an audit misses the untracked violation (or a control is reported);
#       2 sandbox/audit cannot be determined (never 0 on an environment fault).
set -u
SD=${VSC375_SCRIPTS_DIR:-$PWD/scripts}
for s in audit-hardcoded-paths.sh audit-environment-assumptions.sh verify-provider-ci.sh; do
  [ -f "$SD/$s" ] || { echo "probe: missing $SD/$s"; exit 2; }
done
for b in git python3 mktemp; do command -v "$b" >/dev/null 2>&1 || { echo "probe: $b not on PATH"; exit 2; }; done
t=$(mktemp -d /tmp/t375.XXXXXX) || { echo "probe: mktemp failed"; exit 2; }
cleanup() {
  if [ -n "$t" ] && [ -d "$t" ]; then
    case "$t" in /tmp/t375.??????) rm -rf -- "$t" ;; esac
  fi
}
trap cleanup EXIT INT TERM
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null NO_COLOR=1
g() { git -C "$t" -c user.email=probe@example.invalid -c user.name=probe "$@"; }
g init -q . || { echo "probe: git init failed"; exit 2; }
printf '#!/usr/bin/env bash\necho clean\n' > "$t/clean_tracked.sh"
printf 'zz375_ignored.*\n.circleci/\n' > "$t/.gitignore"
g add clean_tracked.sh .gitignore && g commit -qm base || { echo "probe: commit failed"; exit 2; }
g remote add origin git@example.invalid:o/r.git || exit 2
# planted violations (untracked, NOT ignored)
printf '#!/usr/bin/env bash\ncd /home/someuser/proj\nsed -i "s/a/b/" f.txt\n' > "$t/zz375_planted.sh"
# ignored controls (same violations, git-ignored)
printf '#!/usr/bin/env bash\ncd /home/someuser/proj\nsed -i "s/a/b/" f.txt\n' > "$t/zz375_ignored.sh"
# clean untracked control
printf '#!/usr/bin/env bash\necho fine\n' > "$t/zz375_cleanctl.sh"
# provider-ci: planted workflow, ignored CI config
mkdir "$t/.github" "$t/.github/workflows" "$t/.circleci" || exit 2
printf 'on: push\njobs: {}\n' > "$t/.github/workflows/zz375_planted.yml"
printf 'version: 2.1\n' > "$t/.circleci/config.yml"
# sanity: the sandbox really has the intended tracked/untracked/ignored split
[ -z "$(g ls-files zz375_planted.sh)" ] || { echo "probe: planted file is tracked"; exit 2; }
[ -n "$(g status --porcelain --untracked-files=all | grep 'zz375_planted.sh')" ] || { echo "probe: planted not untracked"; exit 2; }
g check-ignore -q zz375_ignored.sh || { echo "probe: ignored control not ignored"; exit 2; }
g check-ignore -q .circleci/config.yml || { echo "probe: circleci control not ignored"; exit 2; }
fail=0
run_audit() { # name script
  local name=$1 s=$2 out rc
  out=$(bash "$SD/$s" "$t" --no-submodules 2>&1); rc=$?
  case "$rc" in 0|1) ;; *) echo "probe: $name rc=$rc (undetermined)"; printf '%s\n' "$out" | tail -3 | cut -c1-200; exit 2 ;; esac
  if printf '%s\n' "$out" | grep -qF 'zz375_planted.sh'; then echo "OK   $name reports untracked planted violation (rc=$rc)"
  else echo "MISS $name does NOT report the untracked planted violation (rc=$rc)"; fail=1; fi
  if printf '%s\n' "$out" | grep -qF 'zz375_ignored.sh'; then echo "BAD  $name reports the git-ignored file"; fail=1
  else echo "OK   $name ignores the git-ignored file"; fi
  if printf '%s\n' "$out" | grep -qF 'zz375_cleanctl.sh'; then echo "BAD  $name reports the clean untracked file"; fail=1
  else echo "OK   $name does not report the clean untracked file"; fi
}
run_audit audit-hardcoded-paths audit-hardcoded-paths.sh
run_audit audit-environment-assumptions audit-environment-assumptions.sh
pj=$(bash "$SD/verify-provider-ci.sh" --root "$t" --no-recurse --json 2>/dev/null)
res=$(printf '%s' "$pj" | python3 -I -c '
import json,sys
d=json.load(sys.stdin); r=d["repositories"][0]
print(r["file_ci_active"], r["file_ci_list"])' 2>/dev/null) || { echo "probe: verify-provider-ci produced no parsable JSON"; exit 2; }
n=${res%% *}; lst=${res#* }
case "$lst" in *zz375_planted.yml*) echo "OK   verify-provider-ci counts the untracked workflow (file_ci_active=$n)" ;;
  *) echo "MISS verify-provider-ci does NOT see the untracked workflow (file_ci_active=$n)"; fail=1 ;; esac
case "$lst" in *circleci*) echo "BAD  verify-provider-ci counts the git-ignored CI config"; fail=1 ;;
  *) echo "OK   verify-provider-ci ignores the git-ignored CI config" ;; esac
[ "$n" = "1" ] || { echo "BAD  verify-provider-ci file_ci_active=$n, expected exactly 1"; fail=1; }
[ "$fail" -eq 0 ] && { echo "RESULT: all three audits see untracked, skip ignored"; exit 0; }
echo "RESULT: at least one audit is tracked-only or a control failed"; exit 1
