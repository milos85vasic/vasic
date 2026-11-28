#!/usr/bin/env bash
# usage: land.sh branch pr
set -e
cd /home/milosvasic/Projects/vasic/job_seeker-wt-w2r
git fetch -q github
git checkout -q -B "$1" "github/$1"
git merge -q github/main -m "Merge github/main into $1" 2>&1 | tail -2 || true
if git ls-files -u | grep -q .; then
  for f in $(git ls-files -u | cut -f2 | sort -u); do
    case "$f" in tests/mutations.tsv|specs/001-job-seeker-mvp/tasks.md) ;; *) echo "CONFLICT in $f"; exit 3;; esac
  done
  python3 - <<'PY'
import subprocess,re
for f in subprocess.check_output(["git","ls-files","-u"]).decode().split("\n"):
    pass
f="tests/mutations.tsv"
try:
    s=open(f).read()
    if "<<<<<<<" in s:
        out=[];
        for l in s.split("\n"):
            if l.startswith(("<<<<<<<","=======",">>>>>>>")): continue
            out.append(l)
        open(f,"w").write("\n".join(out))
except FileNotFoundError: pass
PY
  if grep -q '<<<<<<<' specs/001-job-seeker-mvp/tasks.md 2>/dev/null; then echo "tasks.md conflict needs manual"; exit 4; fi
  git add tests/mutations.tsv specs/001-job-seeker-mvp/tasks.md
  git commit -q --no-edit
fi
go build ./... && go vet ./internal/ext/... >/dev/null
git push -q github "HEAD:$1"
