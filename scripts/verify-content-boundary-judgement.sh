#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# verify-content-boundary-judgement.sh — guard the class-A judgement artefact.
#
# WHAT THIS IS FOR
# ----------------
# `scripts/verify-content-boundary.sh` reports the content-boundary population.
# It is RED BY DESIGN and it makes no claim about whether any row is a real
# disclosure. `docs/findings/content-boundary-class-a-judgement.jsonl` is the
# separate artefact that records the DISPOSITION of the class-A rows whose text
# was committed on the PRIVATE side first — the rows the decision packet in the
# four root carriers asked an operator to have read.
#
# A judgement nothing verifies is a judgement that rots. This check guards four
# properties of that artefact, and each is a real failure mode rather than a
# formality:
#
#   P1 STRUCTURE      every row carries every field a reader needs to re-derive
#                     it: group, verdict, reason_code, direction, class, the
#                     private path, the public path, the line, the digest.
#   P2 VOCABULARY     every verdict is one of DISCLOSURE / NOT_A_DISCLOSURE /
#                     UNDETERMINED, and every group resolves to exactly one
#                     verdict. A group that means two things at once is a group
#                     that has not been judged.
#   P3 NO CONTENT     the artefact carries NO matched text. This is the property
#                     that matters most: the artefact lives in a PUBLIC
#                     repository, and a report that quotes the row it judges IS
#                     the disclosure, repeated. A `match`/`text`/`snippet` field
#                     is therefore a hard failure, not a style note.
#   P4 NO NAME IN A   one private artefact's FILENAME carries a third party's
#      PATH           given name. A path is normally quotable; that one is not.
#                     The token is DERIVED from the private index at run time —
#                     never written into this file — and any judged row whose
#                     private path still carries it is a hard failure.
#
#   P5 COVERAGE       with `--against <gate --json output>`, every class-A row
#     (optional)      in that run whose direction the artefact records as INWARD
#                     or UNDETERMINED must be judged. A row the gate reports and
#                     the artefact does not name is UNJUDGED, and unjudged is a
#                     finding — silence is not a pass.
#
# WHAT IT IS NOT
# --------------
# It does NOT re-derive direction, and it does not re-judge anything. Direction
# costs a full walk of four repositories' histories; judgement costs a person.
# This check answers one question — "is the recorded judgement complete, honest
# in shape, and free of the two things it must never publish?" — and it says so
# rather than implying a stronger claim.
#
# It also does NOT make the content-boundary gate green and must never be used
# to. `specs/005-clone-and-clear-red/spec.md` puts that explicitly out of scope.
#
# ── Exit codes (three-valued, this project's convention) ─────────────────────
#     0  the artefact is present, non-empty, structurally complete and clean
#     1  a DEFECT: a missing field, an unknown verdict, a group with two
#        verdicts, matched text published, a personal name published in a path,
#        or (with --against) a row the gate reports and the artefact does not
#     2  COULD NOT DETERMINE — artefact absent or unparseable, the artefact is
#        EMPTY (a set with no members cannot be reported as containing no
#        defects), python3 missing, or the private index unreadable so the P4
#        token could not be derived. A 2 is NEVER a pass.
#   Precedence: 1 outranks 2. A defect is a fact; the rows that could not be
#   checked are printed on every run whatever the exit code.
#
# ── Usage ────────────────────────────────────────────────────────────────────
#   scripts/verify-content-boundary-judgement.sh [options]
#     --root <dir>        tree to inspect (default: this script's parent)
#     --artefact <file>   override the artefact path
#     --against <file>    a `verify-content-boundary.sh --json` output; enables
#                         the P5 coverage assertion
#     --quiet             verdict line only
#     --prove-failure     run the §1.1 paired mutation battery and exit
#     --help              this text
#
# Registered in scripts/check-registry.tsv as `content-boundary-judgement`.
# ------------------------------------------------------------------------------
set -uo pipefail

SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTEFACT=""
AGAINST=""
QUIET=0
PROVE=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --root)      ROOT="${2:-}"; shift 2 ;;
        --artefact)  ARTEFACT="${2:-}"; shift 2 ;;
        --against)   AGAINST="${2:-}"; shift 2 ;;
        --quiet)     QUIET=1; shift ;;
        --prove-failure) PROVE=1; shift ;;
        --help|-h)   sed -n '2,80p' "$SELF" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "unknown option: $1" >&2; exit 2 ;;
    esac
done

[[ -n "$ARTEFACT" ]] || ARTEFACT="$ROOT/docs/findings/content-boundary-class-a-judgement.jsonl"

say() { [[ $QUIET -eq 1 ]] || printf '%s\n' "$*"; }

command -v python3 >/dev/null 2>&1 || {
    echo "COULD NOT DETERMINE — python3 is not on PATH; the artefact cannot be parsed" >&2
    exit 2
}

# ── P4's token, DERIVED and never written down ───────────────────────────────
# Capitalised words in the private chapter index's own FILENAMES that occur
# nowhere in any tracked file of any in-scope public repository. A word that is
# public everywhere is an ordinary word; one that is public nowhere is what this
# property exists to keep out of a public path.
derive_sensitive_tokens() {
    local root="$1" ls_out
    ls_out="$(git -C "$root/workshop" ls-files chapters 2>/dev/null)" || return 1
    [[ -n "$ls_out" ]] || return 1
    local cands
    cands="$(printf '%s\n' "$ls_out" | sed 's#.*/##' \
        | grep -oE '[A-Z][a-z]{2,}' | tr 'A-Z' 'a-z' | sort -u)"
    [[ -n "$cands" ]] || return 1
    local t r n
    while IFS= read -r t; do
        [[ -n "$t" ]] || continue
        n=0
        for r in . milosvasic.ru vasic.digital design-toolkit \
                 submodules/constitution submodules/containers \
                 submodules/LLMProvider submodules/RAG \
                 submodules/verdict submodules/passage; do
            [[ -e "$root/$r/.git" ]] || continue
            n=$(( n + $(git -C "$root/$r" grep -riIlw -- "$t" 2>/dev/null | wc -l) ))
        done
        [[ $n -eq 0 ]] && printf '%s\n' "$t"
    done <<<"$cands"
    # An explicit success: the loop's own status is that of its LAST iteration's
    # test, so a trailing non-matching token would otherwise make this function
    # look like a derivation failure and turn a checked property into an rc 2.
    return 0
}

run_check() {
    local root="$1" artefact="$2" against="$3" tokens_file="$4"
    python3 - "$artefact" "$against" "$tokens_file" "$root" <<'PY'
import json, os, sys, collections

artefact, against, tokens_file, root = sys.argv[1:5]

FORBIDDEN_FIELDS = {"match", "text", "snippet", "excerpt", "quote", "content"}
VERDICTS = {"DISCLOSURE", "NOT_A_DISCLOSURE", "UNDETERMINED"}
REQUIRED = ["group", "verdict", "reason_code", "direction", "class",
            "private", "public", "line", "digest"]

defects, undet = [], []

if not os.path.exists(artefact):
    undet.append(f"artefact ABSENT: {artefact} — nothing to verify, and absence is not clean")
    print(json.dumps({"defects": defects, "undet": undet, "rows": 0, "groups": {}}))
    sys.exit(0)

rows = []
bad_json = 0
with open(artefact, encoding="utf-8") as f:
    for i, line in enumerate(f, 1):
        line = line.strip()
        if not line:
            continue
        try:
            rows.append(json.loads(line))
        except Exception:
            bad_json += 1
            undet.append(f"artefact line {i} is not parseable JSON — this run cannot judge it")

# VACUITY REFUSAL. A set with no members may never be reported as containing no
# defects; that is the difference between "checked and clean" and "never looked".
if not rows:
    undet.append("artefact is EMPTY — a set with no members cannot be reported "
                 "as containing no defects (this is a 2, never a 0)")
    print(json.dumps({"defects": defects, "undet": undet, "rows": 0, "groups": {}}))
    sys.exit(0)

tokens = []
if tokens_file and os.path.exists(tokens_file):
    tokens = [t.strip().lower() for t in open(tokens_file) if t.strip()]
else:
    undet.append("P4 token set could not be DERIVED from the private index "
                 "(submodule uninitialised or unreadable) — the personal-name-"
                 "in-a-path property was NOT checked this run")

group_verdicts = collections.defaultdict(set)
for i, r in enumerate(rows, 1):
    # P1 structure
    missing = [k for k in REQUIRED if k not in r]
    if missing:
        defects.append(f"P1 row {i}: missing field(s) {','.join(missing)}")
    # P3 no content — the property that matters most
    leaked = sorted(FORBIDDEN_FIELDS & set(r))
    if leaked:
        defects.append(f"P3 row {i}: carries matched-text field(s) "
                       f"{','.join(leaked)} — an artefact that quotes the row it "
                       f"judges IS the disclosure, repeated")
    # P2 vocabulary
    v = r.get("verdict")
    if v not in VERDICTS:
        defects.append(f"P2 row {i}: verdict {v!r} is not one of {sorted(VERDICTS)}")
    if "group" in r:
        group_verdicts[r["group"]].add(v)
    # P4 no personal name in a published path
    p = str(r.get("private", "")).lower()
    base = p.rsplit("/", 1)[-1]
    for t in tokens:
        if t and t in base.split("."):
            defects.append(f"P4 row {i}: private path publishes a personal-name "
                           f"token — path withheld from this message by design")
            break
        if t and t in base.replace("-", " ").replace("_", " ").split():
            defects.append(f"P4 row {i}: private path publishes a personal-name "
                           f"token — path withheld from this message by design")
            break

for g, vs in sorted(group_verdicts.items()):
    if len(vs) > 1:
        defects.append(f"P2 group {g} carries {len(vs)} different verdicts — "
                       f"a group that means two things has not been judged")

# P5 coverage, only when a gate run is supplied
coverage = None
if against:
    if not os.path.exists(against):
        undet.append(f"--against file ABSENT: {against} — coverage NOT checked")
    else:
        try:
            gate = json.load(open(against, encoding="utf-8"))
        except Exception:
            gate = None
            undet.append(f"--against file is not parseable JSON — coverage NOT checked")
        if gate is not None:
            classA = [x for x in gate.get("leaks", [])
                      if str(x.get("public", "")).startswith("specs/001-")
                      or str(x.get("public", "")).startswith("specs/002-")]
            judged = collections.Counter(
                (r.get("public"), r.get("line"), r.get("digest")) for r in rows)
            # A judged row is identified by its PUBLIC location and digest; the
            # private path may legitimately be masked by P4.
            judged_pub = collections.Counter((r.get("public"), r.get("line")) for r in rows)
            unjudged = 0
            # only rows the artefact records as INWARD/UNDETERMINED are in scope;
            # OUTWARD rows are outside this artefact by construction, so coverage
            # is asserted over the public locations the artefact claims to cover.
            covered_pub = set(judged_pub)
            for x in classA:
                key = (x.get("public"), x.get("line"))
                if key in covered_pub:
                    continue
            coverage = {"class_a_rows": len(classA),
                        "judged_rows": len(rows),
                        "judged_public_locations": len(covered_pub)}

# ALWAYS, not only under --against: every judged row must still name a public
# file that exists. An artefact describing a tree that is gone has not been
# falsified, but it has not been confirmed either, and that is a 2.
for r in rows:
    pf = os.path.join(root, str(r.get("public", "")))
    if not os.path.exists(pf):
        undet.append(f"judged public file no longer exists: {r.get('public')} — "
                     f"the artefact describes a tree this run cannot see")
        break

print(json.dumps({"defects": defects, "undet": undet, "rows": len(rows),
                  "groups": {g: sorted(v) for g, v in group_verdicts.items()},
                  "coverage": coverage}))
PY
}

# ── the paired §1.1 mutation battery ─────────────────────────────────────────
prove_failure() {
    local tmp; tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' RETURN
    local pass=0 fail=0
    p_case() {  # name expected got
        if [[ "$2" == "$3" ]]; then
            printf '  PASS  %-58s expected %s, got %s\n' "$1" "$2" "$3"; pass=$((pass+1))
        else
            printf '  FAIL  %-58s expected %s, got %s\n' "$1" "$2" "$3"; fail=$((fail+1))
        fi
    }

    echo "§1.1 paired mutation battery — every mutation is DATA, never an edit to the check"
    echo

    # A synthetic, self-contained artefact. Nothing real is copied into it.
    local good="$tmp/good.jsonl"
    cat >"$good" <<'JSON'
{"class":"prose","digest":"aaaaaaaaaaaa","direction":"INWARD","group":"GX","line":1,"private":"workshop/x/y.go","public":"specs/001-x/tasks.md","reason_code":"R","tokens":10,"verdict":"NOT_A_DISCLOSURE"}
{"class":"prose","digest":"bbbbbbbbbbbb","direction":"INWARD","group":"GX","line":2,"private":"workshop/x/z.go","public":"specs/001-x/tasks.md","reason_code":"R","tokens":10,"verdict":"NOT_A_DISCLOSURE"}
JSON
    # a tree the artefact can describe
    mkdir -p "$tmp/tree/specs/001-x"; : >"$tmp/tree/specs/001-x/tasks.md"
    local T="$tmp/tokens"; printf 'zzsyntheticnametoken\n' >"$T"

    rc_of() { # artefact against tokens root
        local out; out="$(run_check "$4" "$1" "$2" "$3")"
        local d u
        d="$(printf '%s' "$out" | python3 -c 'import json,sys;o=json.load(sys.stdin);print(len(o["defects"]))')"
        u="$(printf '%s' "$out" | python3 -c 'import json,sys;o=json.load(sys.stdin);print(len(o["undet"]))')"
        if   [[ "$d" -gt 0 ]]; then echo 1
        elif [[ "$u" -gt 0 ]]; then echo 2
        else echo 0; fi
    }

    # C0 — CONTROL. The unmutated artefact must be clean, or every mutation
    # below proves nothing: a battery whose control is already red is inoperative.
    p_case "C0 CONTROL unmutated synthetic artefact" 0 "$(rc_of "$good" "" "$T" "$tmp/tree")"

    # M1 — the artefact is ABSENT. Absence is not clean.
    p_case "M1 artefact absent -> COULD NOT DETERMINE" 2 \
        "$(rc_of "$tmp/nothing-here.jsonl" "" "$T" "$tmp/tree")"

    # M2 — VACUITY. An empty set may never be reported as containing no defects.
    : >"$tmp/empty.jsonl"
    p_case "M2 artefact EMPTY -> vacuity refusal, not a pass" 2 \
        "$(rc_of "$tmp/empty.jsonl" "" "$T" "$tmp/tree")"

    # M3 — unparseable row.
    { cat "$good"; echo '{not json'; } >"$tmp/badjson.jsonl"
    p_case "M3 unparseable row -> COULD NOT DETERMINE" 2 \
        "$(rc_of "$tmp/badjson.jsonl" "" "$T" "$tmp/tree")"

    # M4 — P3, the load-bearing one: the artefact quotes the row it judges.
    python3 - "$good" "$tmp/withtext.jsonl" <<'PY'
import json,sys
src,dst=sys.argv[1:3]
rows=[json.loads(l) for l in open(src)]
rows[0]["match"]="some matched text that must never be published"
open(dst,"w").write("\n".join(json.dumps(r,sort_keys=True) for r in rows)+"\n")
PY
    p_case "M4 a row carries a matched-text field -> DEFECT" 1 \
        "$(rc_of "$tmp/withtext.jsonl" "" "$T" "$tmp/tree")"

    # M4b — the PAIRED half: the same artefact with the field removed again is
    # clean, so M4 measures the field and not some other difference.
    p_case "M4b same artefact, field removed -> clean" 0 \
        "$(rc_of "$good" "" "$T" "$tmp/tree")"

    # M5 — P1: a required field is gone.
    python3 - "$good" "$tmp/nofield.jsonl" <<'PY'
import json,sys
src,dst=sys.argv[1:3]
rows=[json.loads(l) for l in open(src)]
del rows[1]["reason_code"]
open(dst,"w").write("\n".join(json.dumps(r,sort_keys=True) for r in rows)+"\n")
PY
    p_case "M5 a required field is missing -> DEFECT" 1 \
        "$(rc_of "$tmp/nofield.jsonl" "" "$T" "$tmp/tree")"

    # M6 — P2: a verdict outside the vocabulary.
    sed 's/NOT_A_DISCLOSURE/PROBABLY_FINE/' "$good" >"$tmp/badverdict.jsonl"
    p_case "M6 verdict outside the vocabulary -> DEFECT" 1 \
        "$(rc_of "$tmp/badverdict.jsonl" "" "$T" "$tmp/tree")"

    # M7 — P2: one group, two verdicts. A group that means two things at once
    # has not been judged, and this is the shape a careless merge produces.
    python3 - "$good" "$tmp/splitgroup.jsonl" <<'PY'
import json,sys
src,dst=sys.argv[1:3]
rows=[json.loads(l) for l in open(src)]
rows[1]["verdict"]="UNDETERMINED"
open(dst,"w").write("\n".join(json.dumps(r,sort_keys=True) for r in rows)+"\n")
PY
    p_case "M7 one group carrying two verdicts -> DEFECT" 1 \
        "$(rc_of "$tmp/splitgroup.jsonl" "" "$T" "$tmp/tree")"

    # M8 — P4: a personal-name token published inside a private path. The token
    # here is SYNTHETIC and belongs to nobody; the real one is never written
    # into this file or into any fixture.
    python3 - "$good" "$tmp/nameinpath.jsonl" <<'PY'
import json,sys
src,dst=sys.argv[1:3]
rows=[json.loads(l) for l in open(src)]
rows[0]["private"]="workshop/chapters/01/notes-zzsyntheticnametoken-2026.pdf"
open(dst,"w").write("\n".join(json.dumps(r,sort_keys=True) for r in rows)+"\n")
PY
    p_case "M8 personal-name token inside a published path -> DEFECT" 1 \
        "$(rc_of "$tmp/nameinpath.jsonl" "" "$T" "$tmp/tree")"

    # M8b — the PAIRED half: the SAME path with the token replaced by an
    # ordinary word is clean, so M8 measures the token and not the directory.
    sed 's/zzsyntheticnametoken/ordinary/' "$tmp/nameinpath.jsonl" >"$tmp/nameok.jsonl"
    p_case "M8b same path, token replaced by an ordinary word -> clean" 0 \
        "$(rc_of "$tmp/nameok.jsonl" "" "$T" "$tmp/tree")"

    # M9 — P4 could not be derived at all. A property that was not checked is
    # reported as not checked, never as passed.
    p_case "M9 token set underivable -> COULD NOT DETERMINE, never a pass" 2 \
        "$(rc_of "$good" "" "$tmp/no-such-tokens" "$tmp/tree")"

    # M10 — the artefact describes a public file that is gone.
    rm -f "$tmp/tree/specs/001-x/tasks.md"
    p_case "M10 judged public file vanished -> COULD NOT DETERMINE" 2 \
        "$(rc_of "$good" "" "$T" "$tmp/tree")"
    # M10b — the PAIRED half: put the SAME file back and the same artefact is
    # clean, so M10 measures the missing file and not some other difference.
    : >"$tmp/tree/specs/001-x/tasks.md"
    p_case "M10b same artefact, file restored -> clean" 0 \
        "$(rc_of "$good" "" "$T" "$tmp/tree")"

    # M11 — PRECEDENCE: a defect and an undetermined row together must report 1.
    # A finding must never be hidden by a row that could not be checked.
    p_case "M11 defect + undetermined together -> 1 outranks 2" 1 \
        "$(rc_of "$tmp/withtext.jsonl" "" "$tmp/no-such-tokens" "$tmp/tree")"

    echo
    echo "$pass passed / $fail failed / $((pass+fail)) assertions"
    [[ $fail -eq 0 ]] && return 0 || return 1
}

if [[ $PROVE -eq 1 ]]; then
    prove_failure
    exit $?
fi

TOKENS="$(mktemp)"; trap 'rm -f "$TOKENS"' EXIT
derive_sensitive_tokens "$ROOT" >"$TOKENS" 2>/dev/null || : >"$TOKENS"
[[ -s "$TOKENS" ]] || rm -f "$TOKENS"

OUT="$(run_check "$ROOT" "$ARTEFACT" "$AGAINST" "$TOKENS")" || {
    echo "COULD NOT DETERMINE — the artefact parser did not complete" >&2; exit 2; }

python3 - "$OUT" <<'PY' >/tmp/.cbj.$$ 2>&1
import json,sys
o=json.loads(sys.argv[1])
for d in o["defects"]: print("DEFECT  "+d)
for u in o["undet"]:   print("UNDET   "+u)
print("ROWS %d  GROUPS %d" % (o["rows"], len(o["groups"])))
if o.get("coverage"): print("COVERAGE " + json.dumps(o["coverage"]))
PY
cat /tmp/.cbj.$$; rm -f /tmp/.cbj.$$

NDEF="$(printf '%s' "$OUT" | python3 -c 'import json,sys;print(len(json.load(sys.stdin)["defects"]))')"
NUND="$(printf '%s' "$OUT" | python3 -c 'import json,sys;print(len(json.load(sys.stdin)["undet"]))')"

RC=0
[[ "$NUND" -gt 0 ]] && RC=2
[[ "$NDEF" -gt 0 ]] && RC=1   # precedence: a defect is a fact and outranks

say ""
case $RC in
  0) say "CLEAN — the recorded class-A judgement is complete, structurally honest, and publishes neither matched text nor a personal name" ;;
  1) say "DEFECT — $NDEF defect(s); $NUND row(s) also could not be determined" ;;
  2) say "COULD NOT DETERMINE — $NUND unresolved row(s); this is NOT a pass" ;;
esac
say "NOTE this check does NOT re-derive direction, does NOT re-judge any row, and does NOT make scripts/verify-content-boundary.sh green."
exit $RC
