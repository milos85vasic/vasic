#!/usr/bin/env bash
# VSC-372 probe: run from the root of the tree under test. Builds a throwaway git repository holding an in-tree
# tracked symlink to a regular script and runs the tree-under-test's unproven-checks and build-if-missing classes
# against it. Holds only if the in-tree symlink is NOT reported COULD-NOT-INSPECT (it is an alias of its target)
# AND a dangling symlink still is. Exit 0 holds / 1 violated / 2 cannot determine.
set -u
SRC=$(pwd)
for c in unproven-checks build-if-missing; do [ -f "$SRC/scripts/zero-gap-class-$c.sh" ] || { echo "class $c absent"; exit 2; }; done
T=$(mktemp -d) || exit 2
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/r/scripts" "$T/r/tools/sub" || exit 2
printf 'scanroot\tscripts\n' >"$T/r/scripts/check-registry.tsv"
printf 'check\tdummy\tscripts/dummy.sh\tflag\t--prove-failure\t--root /nonexistent\n' >>"$T/r/scripts/check-registry.tsv"
printf '#!/usr/bin/env bash\ncase "${1:-}" in --prove-failure) echo proof; exit 0;; esac\nif [ "${1:-}" = --root ]; then exit 2; fi\nexit 0\n' >"$T/r/scripts/dummy.sh"; chmod +x "$T/r/scripts/dummy.sh"
printf '#!/usr/bin/env bash\nexit 0\n' >"$T/r/tools/sub/verify-real.sh"; chmod +x "$T/r/tools/sub/verify-real.sh"
printf '#!/usr/bin/env bash\n[ -x ./b ] || bash ./build.sh\n' >"$T/r/tools/sub/start.sh"; chmod +x "$T/r/tools/sub/start.sh"
ln -s verify-real.sh "$T/r/tools/sub/verify-alias.sh"
ln -s start.sh "$T/r/tools/sub/restart.sh"
ln -s no-such-target.sh "$T/r/tools/sub/verify-dangling.sh"
git -C "$T/r" init -q 2>/dev/null && git -C "$T/r" add -A && git -C "$T/r" -c user.name=t -c user.email=t@example.invalid commit -q -m probe || { echo "git setup failed"; exit 2; }
bad=0
for c in unproven-checks build-if-missing; do
  out=$(cd "$SRC" && timeout 120 bash "scripts/zero-gap-class-$c.sh" --root "$T/r" 2>/dev/null); rc=$?
  if [ "$rc" -ne 0 ] && [ "$rc" -ne 1 ] && [ "$rc" -ne 2 ]; then echo "$c: unexpected rc $rc"; exit 2; fi
  if ! printf '%s\n' "$out" | grep -q '^INSPECTED '; then echo "$c: class did not report INSPECTED (rc $rc)"; exit 2; fi
  for l in verify-alias restart; do
    if printf '%s\n' "$out" | grep -q "^COULD-NOT-INSPECT tools/sub/$l.sh "; then echo "$c: in-tree symlink $l.sh is COULD-NOT-INSPECT"; bad=1; fi
  done
done
out=$(cd "$SRC" && timeout 120 bash scripts/zero-gap-class-unproven-checks.sh --root "$T/r" 2>/dev/null)
printf '%s\n' "$out" | grep -q '^COULD-NOT-INSPECT tools/sub/verify-dangling.sh ' || { echo "dangling link no longer COULD-NOT-INSPECT (unproven-checks)"; bad=1; }
[ "$bad" -eq 0 ] && echo "in-tree symlinks are aliases, dangling stays COULD-NOT-INSPECT"
exit "$bad"
