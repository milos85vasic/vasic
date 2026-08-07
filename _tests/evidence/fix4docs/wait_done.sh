#!/usr/bin/env bash
cd /Volumes/T7/Projects/vasic
for i in $(seq 1 120); do
  n=$(ps aux | grep -E "retry.sh|translate-content" | grep -v grep | wc -l | tr -d ' ')
  [ "$n" = "0" ] && break
  sleep 20
done
echo "ALL DONE"
grep -H "RESULT:" _tests/evidence/fix4docs/*.log
