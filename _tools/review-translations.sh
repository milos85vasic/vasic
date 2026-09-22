#!/usr/bin/env bash
# Independent per-language translation REVIEW driver (HelixConstitution mandate).
# For each translated article in <site>/_article_src/<lang>/, runs an independent
# reviewer model (different from the translator) against the English source and
# records a strict PASS/FAIL/ERROR verdict + evidence JSON. Aggregates a report.
#
# Usage: review-translations.sh <site-root> <lang> [<lang> ...]
#        review-translations.sh --prove-failure     paired §1.1 mutation proof
# Env:   REVIEW_PROVIDER (default groq), REVIEW_MODEL (optional)
#        VASIC_REVIEW_PY  reviewer program (default _tools/review_translation.py);
#                         overridden by --prove-failure with a stub, never needed
#                         in normal use
#
# EXIT — three-valued, like every check in this tree:
#   0  every reviewed article PASSED
#   1  at least one article FAILED review (a real finding)
#   2  COULD NOT DETERMINE: the repository root, the reviewer or the site root
#      could not be resolved, no language was given, NOTHING was reviewed, or
#      some article could not be reviewed (ERROR) — never a pass
# Precedence: FAIL (1) outranks ERROR (2) outranks PASS (0) — an article that
# could not be reviewed may never launder a real FAIL into "could not tell".
#
# WHY THE EXIT CONTRACT EXISTS (2026-09-22). Before it, this driver printed its
# totals and exited 0 unconditionally: a run with FAIL=12 was, to every caller,
# indistinguishable from a clean one; and its two cannot-run guards exited 1,
# reporting "could not run" as a finding. It was registered as `debt` in
# scripts/check-registry.tsv for exactly that; --prove-failure below proves the
# old form gets the FAIL case wrong (mutation M9).
set -uo pipefail
# ROOT (the repository root) is DERIVED from this script's own location
# (<repo>/_tools/review-translations.sh -> "$(dirname)/..") and is NEVER a
# literal absolute path: a literal only resolves on the machine it was typed on,
# and because this script sets -u and pipefail but NOT -e, a bad path fails
# silently (every review turns into ERROR(no-en-src) / a parse error). Set
# VASIC_ROOT only to deliberately point this tool at a different checkout.
# NOTE: lowercase `root` below is a DIFFERENT variable — the per-site root passed
# in as $1 (e.g. "$ROOT/vasic.digital"). Bash is case-sensitive; they do not clash.
SELF="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/$(basename -- "${BASH_SOURCE[0]}")"

undetermined() { echo "UNDETERMINED: $1" >&2; exit 2; }

prove_failure() {
    local T rc pass=0 fail=0
    T="$(mktemp -d)"
    trap 'rm -rf "$T"' EXIT
    # A stub reviewer: emits the verdict named in STUB_VERDICT, or garbage.
    cat > "$T/stub.py" <<'PY'
import json, os, sys
a = sys.argv
out = a[a.index("--out") + 1]
v = os.environ.get("STUB_VERDICT", "PASS")
os.makedirs(os.path.dirname(out), exist_ok=True)
if v == "GARBAGE":
    print("this is not json"); sys.exit(0)
d = {"verdict": v, "accuracy": 5, "fluency": 5, "completeness": 5, "script_ok": True, "issues": []}
open(out, "w").write(json.dumps(d)); print(json.dumps(d))
PY
    mk_site() {   # $1 site dir, $2.. slugs to translate into "xx"
        local s="$1"; shift
        mkdir -p "$s/_article_src/en" "$s/_article_src/xx"
        for slug in "$@"; do
            echo "# $slug" > "$s/_article_src/en/$slug.md"
            echo "# $slug (xx)" > "$s/_article_src/xx/$slug.md"
        done
    }
    run() {       # $1 expected rc, $2 label, rest: env + args for the SUBJECT
        local want="$1" label="$2"; shift 2
        env VASIC_ROOT="$T/root" VASIC_REVIEW_PY="$T/stub.py" "$@" >/dev/null 2>&1; rc=$?
        if [ "$rc" = "$want" ]; then pass=$((pass+1)); echo "✅ $label — rc $rc"
        else fail=$((fail+1)); echo "❌ $label — want rc $want, got rc $rc"; fi
    }
    mkdir -p "$T/root"
    mk_site "$T/s1" a b
    run 0 "M1 control: every article PASSes -> rc 0" STUB_VERDICT=PASS bash "$SELF" "$T/s1" xx
    mk_site "$T/s2" a
    run 1 "M2 a FAILed review -> rc 1" STUB_VERDICT=FAIL bash "$SELF" "$T/s2" xx
    mk_site "$T/s3" a
    run 2 "M3 reviewer output unparseable (ERROR) -> rc 2" STUB_VERDICT=GARBAGE bash "$SELF" "$T/s3" xx
    # M4: one FAIL and one ERROR in the same run — FAIL must win.
    mk_site "$T/s4" a
    mkdir -p "$T/s4/_article_src/xx"; echo "# orphan" > "$T/s4/_article_src/xx/orphan.md"
    run 1 "M4 precedence: FAIL + ERROR(no-en-src) -> rc 1, not 2" STUB_VERDICT=FAIL bash "$SELF" "$T/s4" xx
    mkdir -p "$T/s5/_article_src/en" "$T/s5/_article_src/xx"
    run 2 "M5 nothing to review (vacuous) -> rc 2, never a pass" STUB_VERDICT=PASS bash "$SELF" "$T/s5" xx
    run 2 "M6 reviewer program missing -> rc 2" VASIC_REVIEW_PY="$T/absent.py" bash "$SELF" "$T/s1" xx
    run 2 "M7 site root missing -> rc 2" bash "$SELF" "$T/no-such-site" xx
    run 2 "M8 no language given -> rc 2" bash "$SELF" "$T/s1"
    # M10: a cached PASS older than an EDITED translation must not be reused.
    mk_site "$T/s10" a
    run 0 "M10a first review PASSes and is cached" STUB_VERDICT=PASS bash "$SELF" "$T/s10" xx
    sleep 1; echo "# a (xx) — edited after the PASS" > "$T/s10/_article_src/xx/a.md"
    run 1 "M10b translation edited after its cached PASS -> re-reviewed (FAIL) -> rc 1" STUB_VERDICT=FAIL bash "$SELF" "$T/s10" xx
    touch "$T/root/_tests/evidence/translate/review/s10/xx/a.json" 2>/dev/null
    echo '{"verdict":"PASS"}' > "$T/root/_tests/evidence/translate/review/s10/xx/a.json"
    run 0 "M10c an unedited cached PASS is still reused (resumable) -> rc 0" STUB_VERDICT=FAIL bash "$SELF" "$T/s10" xx
    # M9: the HISTORICAL form (exit 0 unconditionally) must get M2 wrong — if it
    # did not, M2 could not discriminate and this proof would be reporting on
    # nothing. Reconstructed from the fact, not by calling the subject.
    # Portable (no GNU-only `sed -i`): write the reconstruction as a new file.
    sed 's/^finish_verdict$/:/' "$SELF" > "$T/historical.sh"
    printf '\nexit 0\n' >> "$T/historical.sh"
    mk_site "$T/s9" a
    env VASIC_ROOT="$T/root" VASIC_REVIEW_PY="$T/stub.py" STUB_VERDICT=FAIL \
        bash "$T/historical.sh" "$T/s9" xx >/dev/null 2>&1; rc=$?
    if [ "$rc" = 0 ]; then pass=$((pass+1)); echo "✅ M9 the historical always-0 form scores a FAIL as rc 0 — M2 discriminates"
    else fail=$((fail+1)); echo "❌ M9 the historical form returned rc $rc; M2 cannot discriminate"; fi
    echo "----------------------------------------------------------------------"
    if [ "$fail" -eq 0 ]; then
        echo "✅ review-translations §1.1 MUTATION PROOF: PASS — $pass mutations caught, 0 slipped"
        exit 0
    fi
    echo "❌ review-translations §1.1 MUTATION PROOF: FAIL — $fail of $((pass+fail)) did not behave"
    exit 1
}

case "${1:-}" in
    --prove-failure) prove_failure ;;
    -h|--help) sed -n '2,27p' "$SELF"; exit 0 ;;
esac

ROOT="${VASIC_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
[ -n "$ROOT" ] && [ -d "$ROOT" ] || undetermined "cannot resolve repository root (got '$ROOT')"
PY="${VASIC_REVIEW_PY:-$ROOT/_tools/review_translation.py}"
[ -f "$PY" ] || undetermined "reviewer not found: $PY"
[ "$#" -ge 1 ] || undetermined "site-root required"
root="$1"; shift
[ -d "$root" ] || undetermined "site root is not a directory: $root"
[ "$#" -ge 1 ] || undetermined "at least one <lang> is required"
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
    # Resumable: a prior PASS is reused (survives the background-kill pattern)
    # ONLY while it is newer than BOTH texts it judged. A PASS recorded before
    # the translation or its English source was edited is a verdict about text
    # that no longer exists — reusing it was a stale-pass defect (found by an
    # independent review, 2026-09-22; mutation M10). FAIL/ERROR/missing are
    # always (re)reviewed so transient provider errors get retried.
    if [ -f "$out" ] && [ "$out" -nt "$md" ] && [ "$out" -nt "$src" ] \
       && grep -q '"verdict": *"PASS"\|"verdict":"PASS"' "$out" 2>/dev/null; then
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

finish_verdict() {
    if [ "$fail" -gt 0 ]; then exit 1; fi
    if [ $((pass + err)) -eq 0 ]; then undetermined "no translated article was found to review — a vacuous run is not a pass"; fi
    if [ "$err" -gt 0 ]; then undetermined "$err article(s) could not be reviewed (ERROR); see $REPORT"; fi
    exit 0
}
finish_verdict
