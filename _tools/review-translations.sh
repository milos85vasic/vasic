#!/usr/bin/env bash
# Independent per-language translation REVIEW driver (HelixConstitution mandate).
# For each translated article in <site>/_article_src/<lang>/, runs an independent
# reviewer model (different from the translator) against the English source and
# records a strict PASS/FAIL/ERROR verdict + evidence JSON. Aggregates a report.
#
# Usage: review-translations.sh <site-root> <lang> [<lang> ...]
# Env:   REVIEW_PROVIDER (default groq), REVIEW_MODEL (optional)
set -uo pipefail
# ROOT (the repository root) is DERIVED from this script's own location
# (<repo>/_tools/review-translations.sh -> "$(dirname)/..") and is NEVER a
# literal absolute path: a literal only resolves on the machine it was typed on,
# and because this script sets -u and pipefail but NOT -e, a bad path fails
# silently (every review turns into ERROR(no-en-src) / a parse error). Set
# VASIC_ROOT only to deliberately point this tool at a different checkout.
# NOTE: lowercase `root` below is a DIFFERENT variable — the per-site root passed
# in as $1 (e.g. "$ROOT/vasic.digital"). Bash is case-sensitive; they do not clash.
ROOT="${VASIC_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
[ -n "$ROOT" ] && [ -d "$ROOT" ] || { echo "FATAL: cannot resolve repository root (got '$ROOT')" >&2; exit 1; }
PY="$ROOT/_tools/review_translation.py"
[ -f "$PY" ] || { echo "FATAL: reviewer not found: $PY" >&2; exit 1; }
root="${1:?site-root required}"; shift
site="$(basename "$root")"
EVID="$ROOT/_tests/evidence/translate/review/$site"
REPORT="$EVID/REVIEW-REPORT.md"
mkdir -p "$EVID"
PROV="${REVIEW_PROVIDER:-groq}"
echo "# Translation review — $site (independent reviewer: $PROV)" > "$REPORT"
echo "" >> "$REPORT"; echo "| lang | slug | verdict | acc | flu | comp | script | issues |" >> "$REPORT"
echo "|---|---|---|---|---|---|---|---|" >> "$REPORT"
pass=0; fail=0; err=0
for lang in "$@"; do
  for md in "$root/_article_src/$lang/"*.md; do
    [ -e "$md" ] || continue
    slug="$(basename "$md" .md)"
    src="$root/_article_src/en/$slug.md"
    [ -f "$src" ] || { echo "| $lang | $slug | ERROR(no-en-src) | | | | | |" >>"$REPORT"; err=$((err+1)); continue; }
    out="$EVID/$lang/$slug.json"
    # Resumable: a prior PASS is authoritative — reuse it (survives the
    # background-kill pattern). FAIL/ERROR/missing are (re)reviewed so transient
    # provider errors get retried and FAILs re-checked after remediation.
    if [ -f "$out" ] && grep -q '"verdict": *"PASS"\|"verdict":"PASS"' "$out" 2>/dev/null; then
      json="$(cat "$out")"
    else
      json="$(REVIEW_PROVIDER="$PROV" python3 "$PY" --src "$src" --translated "$md" --lang "$lang" --article --out "$out" 2>/dev/null)"
    fi
    v=$(printf '%s' "$json" | python3 -c "import sys,json;d=json.load(sys.stdin);print('%s|%s|%s|%s|%s|%s|%s'%(d.get('verdict'),d.get('accuracy',''),d.get('fluency',''),d.get('completeness',''),d.get('script_ok',''),('; '.join(d.get('issues',[]))[:80]).replace('|','/'),''))" 2>/dev/null || echo "ERROR|||||parse|")
    IFS='|' read -r verdict acc flu comp scr iss _ <<<"$v"
    echo "| $lang | $slug | $verdict | $acc | $flu | $comp | $scr | $iss |" >>"$REPORT"
    case "$verdict" in PASS) pass=$((pass+1));; FAIL) fail=$((fail+1));; *) err=$((err+1));; esac
  done
done
echo "" >> "$REPORT"
echo "**Totals: PASS=$pass FAIL=$fail ERROR=$err**" >> "$REPORT"
echo "REVIEW DONE site=$site PASS=$pass FAIL=$fail ERROR=$err -> $REPORT"
