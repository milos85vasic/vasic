#!/usr/bin/env bash
# VSC-386 probe (check author: t090-check-author). Run from the root of the tree under test.
# Target: the 7 member locations (4 progress.yml lines + the 3 sweep report files) are reported 0 times while the planted
# corpus keeps 9/9 guessing and 4/4 credential shapes.
# Measured on a throwaway git repo that holds the PRE-FIX text of the member files (git show of PRE_REF), so editing the
# live ledger cannot satisfy it; the class under test is the tree's own scripts/zero-gap-class-private-in-public.sh.
#   (A) member locations: progress.yml lines 43 72 86 95 of PRE_REF and every finding inside baseline/sweep-2026-09-26/
#       (report.txt, report.json, FINDINGS-BY-CLASS.tsv) must be absent;
#   (B) planted corpus (the tree's fixture planted/ via --corpus): the 7 guess.md lines + CONTINUATION.md:7 + rows.tsv:2
#       (9 guessing) and secret.md:3-6 (4 credential shapes) must all still be FINDINGs.
# Exit 0 met / 1 measurably not met / 2 cannot determine.
set -u
PRE_REF=c827c66
SRC=$(pwd)
CLS="$SRC/scripts/zero-gap-class-private-in-public.sh"
CORP="$SRC/_tests/fixtures/zero-gap/private-in-public/planted"
[ -f "$CLS" ] && [ -d "$CORP" ] || { echo "class or planted corpus absent"; exit 2; }
for t in git python3; do command -v $t >/dev/null 2>&1 || { echo "$t missing"; exit 2; }; done
T=$(mktemp -d) || exit 2
trap 'rm -rf "$T"' EXIT
D=specs/010-zero-gap-verified-closure
mkdir -p "$T/r/$D/baseline/sweep-2026-09-26" || exit 2
for f in progress.yml baseline/sweep-2026-09-26/report.txt baseline/sweep-2026-09-26/report.json baseline/sweep-2026-09-26/FINDINGS-BY-CLASS.tsv; do
  git -C "$SRC" show "$PRE_REF:$D/$f" >"$T/r/$D/$f" 2>/dev/null || { echo "cannot read $D/$f at $PRE_REF"; exit 2; }
done
git -C "$T/r" init -q 2>/dev/null && git -C "$T/r" add -A && git -C "$T/r" -c user.name=t -c user.email=t@example.invalid commit -q -m probe || { echo "git setup failed"; exit 2; }
( cd "$SRC" && timeout 300 bash "$CLS" --root "$T/r" >"$T/r.out" 2>"$T/r.err" ); rc=$?
case "$rc" in 0|1) ;; *) echo "class rc $rc on member repo"; exit 2 ;; esac
grep -q '^INSPECTED ' "$T/r.out" || { echo "no INSPECTED line (member repo)"; exit 2; }
bad=0; seen=0
for n in 43 72 86 95; do
  if grep -q "^FINDING .* $D/progress.yml:$n " "$T/r.out"; then echo "member still reported: $D/progress.yml:$n"; seen=$((seen+1)); fi
done
for f in report.txt report.json FINDINGS-BY-CLASS.tsv; do
  c=$(grep -c "^FINDING .* $D/baseline/sweep-2026-09-26/$f:" "$T/r.out"); if [ "$c" -gt 0 ]; then echo "member still reported: sweep report file $f ($c row(s))"; seen=$((seen+1)); fi
done
echo "(A) member locations still reported: $seen (need 0)"
[ "$seen" -eq 0 ] || bad=1
( cd "$SRC" && timeout 300 bash "$CLS" --root "$SRC" --corpus "$CORP" >"$T/c.out" 2>"$T/c.err" ); rc=$?
case "$rc" in 1) ;; *) echo "class rc $rc on planted corpus (expected 1)"; exit 2 ;; esac
g9=0; c4=0
for loc in guess.md:3 guess.md:4 guess.md:12 guess.md:13 guess.md:14 guess.md:15 guess.md:16 CONTINUATION.md:7 rows.tsv:2; do
  if grep -q "^FINDING .* $loc " "$T/c.out"; then g9=$((g9+1)); else echo "planted guessing NOT detected: $loc"; fi
done
for loc in secret.md:3 secret.md:4 secret.md:5 secret.md:6; do
  if grep -q "^FINDING .* $loc " "$T/c.out"; then c4=$((c4+1)); else echo "planted credential NOT detected: $loc"; fi
done
echo "(B) planted guessing detected: $g9/9; credential shapes detected: $c4/4"
[ "$g9" -eq 9 ] && [ "$c4" -eq 4 ] || bad=1
exit "$bad"
