#!/usr/bin/env bash
# clean: the vacuous loop appears only in a comment and in a here-document body; the heredoc loop
# carries a verdict (exit 1 on a failed case), so a broken here-document skip WOULD report it
set -u
cat > "$TMPDIR/stub.sh" <<'STUB'
for f in $(git ls-files 'x*'); do
    grep -q marker "$f" || { echo "FAIL $f"; exit 1; }
done
echo PASS
exit 0
STUB
# for f in $(find . -name '*.md'); do grep -q x "$f" || exit 1; done
echo PASS
exit 0
