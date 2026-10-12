#!/usr/bin/env bash
# VSC-355 probe (check author: t090-check-author). Run from the root of the tree under test.
# Target: the 6 member claim-keys (specs/008 tasks.md x5 rows, module-page-walkthrough.md:91) are no longer reported
# AND the planted corpus keeps 14/14 detected plus >=2 new clean controls.
# Measured here as:
#   (A) live tree: none of the 4 pre-fix claim-keys (96a70bd5c5fc f63cf98b05c5 dbd8041f75e4 0eacec528775 = the 6 member
#       finding rows) appears in the class output on the tree under test;
#   (B) planted corpus: the tree's own fixture _tests/fixtures/zero-gap/doc-count-drift/planted is copied to a throwaway
#       git repo; every location of its expect.tsv (14 at authoring) is still a FINDING;
#   (C) 3 synthetic clean controls added to that copy (a "Measured <date>" claim line, a commit-anchored claim line, a
#       count qualified by a subset phrase) whose counts really differ from the measure must NOT be reported, while the
#       same sentence without the qualifier (docs/files.md in the corpus) stays detected.
# Exit 0 met / 1 measurably not met / 2 cannot determine.
set -u
SRC=$(pwd)
CLS="$SRC/scripts/zero-gap-class-doc-count-drift.sh"
CORP="$SRC/_tests/fixtures/zero-gap/doc-count-drift"
[ -f "$CLS" ] && [ -f "$CORP/expect.tsv" ] && [ -d "$CORP/planted" ] || { echo "class or corpus absent"; exit 2; }
for t in git python3 awk; do command -v $t >/dev/null 2>&1 || { echo "$t missing"; exit 2; }; done
T=$(mktemp -d) || exit 2
trap 'rm -rf "$T"' EXIT
bad=0
# (A) live tree
( cd "$SRC" && timeout 600 bash "$CLS" --root . >"$T/live.out" 2>"$T/live.err" ); rc=$?
case "$rc" in 0|1) ;; *) echo "class rc $rc on live tree"; exit 2 ;; esac
grep -q '^INSPECTED ' "$T/live.out" || { echo "no INSPECTED line on live tree"; exit 2; }
n=0
for k in 96a70bd5c5fc f63cf98b05c5 dbd8041f75e4 0eacec528775; do
  c=$(grep -c "claim-key=$k" "$T/live.out"); n=$((n+c))
  [ "$c" -eq 0 ] || echo "member claim-key $k still reported ($c row(s))"
done
echo "(A) member finding rows still reported on the live tree: $n (need 0)"
[ "$n" -eq 0 ] || bad=1
# (B)+(C) planted corpus copy
cp -R "$CORP/planted" "$T/p" || exit 2
while IFS= read -r p; do
  [ -d "$T/p/$p" ] || continue
  git -C "$T/p/$p" init -q && git -C "$T/p/$p" add -A && git -C "$T/p/$p" -c user.name=t -c user.email=t@example.invalid commit -q -m f || { echo "nested repo setup failed"; exit 2; }
done < <(git config -f "$T/p/.gitmodules" --get-regexp '^submodule\..*\.path$' 2>/dev/null | awk '{print $2}')
cat >"$T/p/docs/vsc355-dated.md" <<'DOC'
# Dated

Measured 2026-09-03: there are 7 tracked files in `data/`.
DOC
cat >"$T/p/docs/vsc355-commit.md" <<'DOC'
# Commit anchored

At commit 1a2b3c4d5e6f the notes say there are 7 tracked files in `data/`.
DOC
cat >"$T/p/docs/vsc355-subset.md" <<'DOC'
# Subset

The V-G8 roster gaps name 8 submodules out of those in `.gitmodules`.
DOC
git -C "$T/p" init -q && git -C "$T/p" -c advice.addEmbeddedRepo=false add -A 2>/dev/null
( cd "$SRC" && timeout 300 bash "$CLS" --root "$T/p" >"$T/p.out" 2>"$T/p.err" ); rc=$?
case "$rc" in 1) ;; 0) echo "planted corpus produced rc 0 (nothing detected)"; exit 1 ;; *) echo "class rc $rc on planted copy"; exit 2 ;; esac
tot=0; hit=0
while IFS= read -r loc; do
  tot=$((tot+1))
  if awk -v l="$loc" '$1=="FINDING" && $5==l {f=1} END{exit !f}' "$T/p.out"; then hit=$((hit+1)); else echo "planted NOT detected: $loc"; fi
done < <(awk -F'\t' '!/^#/ && NF {print $1}' "$CORP/expect.tsv")
echo "(B) planted locations detected: $hit of $tot (need all, and tot >= 14)"
[ "$hit" -eq "$tot" ] && [ "$tot" -ge 14 ] || bad=1
fp=0
for d in vsc355-dated vsc355-commit vsc355-subset; do
  if grep -q "docs/$d.md" "$T/p.out"; then echo "FALSE POSITIVE: docs/$d.md reported"; fp=$((fp+1)); fi
done
echo "(C) clean controls reported: $fp of 3 (need 0; >=2 required clean)"
[ "$fp" -le 1 ] || bad=1
[ "$fp" -eq 0 ] || bad=1
exit "$bad"
