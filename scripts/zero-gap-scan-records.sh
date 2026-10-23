#!/usr/bin/env bash
# scripts/zero-gap-scan-records.sh — feature 010 record scanner (task T062, FR-020, SC-008).
#
# WHAT IT DETECTS, over the records feature 010 PRODUCES (scope below):
#   guessing   a causal statement that hedges: a sentence holding a causal marker
#              (because / due to / caused by / root cause / reason is / result of / since the)
#              AND a hedge word (likely / probably / maybe / seems / appears / perhaps /
#              presumably / possibly / might be / could be). Constitution 11.4.6 requires
#              UNCONFIRMED: / UNKNOWN: / PENDING_FORENSICS: instead; a line carrying one of
#              those markers is the permitted form and is not a finding. A hedge inside
#              quotes or backticks is a MENTION of the word (a rule text), not a use.
#   credential a credential-shaped literal: AWS key id, PEM private-key armour, vendor token
#              prefixes (gh*_, github_pat_, glpat-, xox*-), JWT, scheme://user:secret@host,
#              and `password|secret|api_key ... = VALUE` with VALUE 8+ chars holding a digit
#              or symbol and no placeholder token. The matched VALUE is never printed.
#   private    private-text leakage: an 8-word shingle (case/punctuation-folded) of a PRIVATE
#              source (default <root>/workshop/chapters) appearing in a scoped record.
#              Only path:line and a 12-hex shingle digest are printed, never the text.
#              With no private source present the layer is COULD-NOT-DETERMINE (rc 2): a
#              leak check that read nothing is never a pass.
#
# SCOPE (derived at run time): tracked + untracked-not-ignored text files under
#   docs/zero-gap/ , specs/010-*/ , and, when present, the untracked evidence streams
#   .remember/logs/zero-gap/evidence/ ; minus the deliberately defective corpora under
#   _tests/fixtures/zero-gap/ . Binary files are not text and are not read.
#
# USAGE  zero-gap-scan-records.sh [--root <dir>] [--private-root <dir>] [--scope <relpath> | <relpath>]...
#        zero-gap-scan-records.sh --prove-failure
# ENV    ZG_SCAN_DISABLE=<layer>[,<layer>]  disables a layer (used ONLY by --prove-failure to show
#        each planted case really depends on its layer; a disabled layer is printed as DISABLED and
#        forces rc 2 so a disabled scan can never pass as clean).
# EXIT   0 clean (non-empty population fully read, every layer ran), 1 at least one FINDING (outranks 2),
#        2 could not determine (root not a git repo, empty population, a layer disabled or unable to run).
# Wired into: scripts/pre-push-gates.sh (gate) and `workable-items-vsc gap freeze` (release gate).
set -uo pipefail
export LC_ALL=C LANG=C

SELF=$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")
ROOT="" PRIVATE="" PROVE=0
SCOPES=()
while [ $# -gt 0 ]; do
    case "$1" in
        --root) ROOT="${2:-}"; shift 2 ;;
        --private-root) PRIVATE="${2:-}"; shift 2 ;;
        --scope) SCOPES+=("${2:-}"); shift 2 ;;
        --prove-failure) PROVE=1; shift ;;
        -*) echo "COULD-NOT-INSPECT arguments unknown-argument"; echo "VERDICT UNDETERMINED (rc 2)"; exit 2 ;;
        *) SCOPES+=("$1"); shift ;;   # quickstart form: positional scope paths, relative to --root
    esac
done

# ---------------------------------------------------------------- the scanner (python3, stdlib only)
read -r -d '' PYSCAN <<'PYEOF' || true
import hashlib, os, re, subprocess, sys

root, private_arg, disable, scopes_arg, fixture_pfx = sys.argv[1:6]
disabled = set(x for x in disable.split(",") if x)
scopes = [s for s in scopes_arg.split("\n") if s]

def out(s):
    sys.stdout.write(s + "\n")

# ---- population
def git(args):
    return subprocess.run(["git", "-C", root] + args, capture_output=True)

if git(["rev-parse", "--is-inside-work-tree"]).returncode != 0:
    out("COULD-NOT-INSPECT root not-a-git-work-tree"); out("INSPECTED 0"); sys.exit(2)

specs = []
for s in scopes:
    if s.endswith("*"):
        base = os.path.dirname(s) or "."
        pat = os.path.basename(s)
        try:
            for n in sorted(os.listdir(os.path.join(root, base))):
                if n.startswith(pat[:-1]) and os.path.isdir(os.path.join(root, base, n)):
                    specs.append(os.path.join(base, n))
        except OSError:
            pass
    else:
        specs.append(s)

files = set()
for sp in specs:
    r = git(["ls-files", "-z", "--cached", "--others", "--exclude-standard", "--", sp])
    if r.returncode != 0:
        out("COULD-NOT-INSPECT %s git-ls-files-failed" % sp); sys.exit(2)
    for p in r.stdout.split(b"\0"):
        if p:
            files.add(p.decode("utf-8", "surrogateescape"))
# untracked, git-ignored evidence streams are records too
ev = ".remember/logs/zero-gap/evidence"
evabs = os.path.join(root, ev)
if os.path.isdir(evabs):
    for dp, dn, fn in os.walk(evabs):
        for f in fn:
            files.add(os.path.relpath(os.path.join(dp, f), root))

texts = []
for p in sorted(files):
    if p.startswith(fixture_pfx):
        continue
    ap = os.path.join(root, p)
    if os.path.islink(ap) or not os.path.isfile(ap):
        continue
    try:
        b = open(ap, "rb").read()
    except OSError:
        out("COULD-NOT-INSPECT %s unreadable" % p); sys.exit(2)
    if b"\0" in b[:8192]:
        continue
    texts.append((p, b.decode("utf-8", "replace")))

findings = []
def find(layer, p, ln, detail):
    findings.append((layer, p, ln, detail))

# ---- layer: guessing
CAUSAL = re.compile(r"\b(because|due to|caused by|root cause|the cause|reason is|result of|since the)\b", re.I)
HEDGE = re.compile(r"\b(likely|probably|maybe|seems|appears|perhaps|presumably|possibly|might be|could be)\b", re.I)
OKMARK = re.compile(r"\b(UNCONFIRMED|UNKNOWN|PENDING_FORENSICS)\s*:")
QUOTED = re.compile(r"`[^`]*`|\"[^\"]*\"|'[^']*'|“[^”]*”")
def sentences(line):
    return re.split(r"(?<=[.;!?])\s+", line)
if "guessing" not in disabled:
    for p, t in texts:
        for i, line in enumerate(t.split("\n"), 1):
            if OKMARK.search(line):
                continue
            for s in sentences(line):
                s2 = QUOTED.sub(" ", s)
                if CAUSAL.search(s2) and HEDGE.search(s2):
                    find("guessing", p, i, "hedge=%s" % HEDGE.search(s2).group(0).lower())
                    break

# ---- layer: credential
PH = re.compile(r"(?i)(?:^|[^a-z0-9])(redacted|placeholder|example|changeme)(?:[^a-z0-9]|$)")
def valid_value(v):
    if len(v) < 8 or len(v) > 128: return False
    if not re.search(r"[0-9!@#$%^&*+=?~]", v) or not re.search(r"[A-Za-z]", v): return False
    if PH.search(v) or re.match(r"(?i)^your[_-]", v): return False
    if re.match(r"^[<{\[$%(`@]", v) or "***" in v or re.search(r"[xX]{3,}", v) or "..." in v or re.search(r"\$\{?[A-Za-z_]", v): return False
    return True
STRONG = [
    ("aws-key-id", re.compile(r"(?<![A-Za-z0-9+/])(AKIA|ASIA|AGPA|AIDA|AROA|ANPA|ANVA|AIPA)[A-Z0-9]{16}(?![A-Za-z0-9+/])")),
    ("private-key", re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----")),
    ("token-prefix", re.compile(r"gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,}|glpat-[A-Za-z0-9_-]{20,}|xox[abprs]-[A-Za-z0-9-]{10,}|eyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}")),
]
URLPW = re.compile(r"[A-Za-z][A-Za-z0-9+.-]*://[^/@\s:]+:([^/@\s]+)@")
MARK = re.compile(r"(?i)\b(password|passwd|pwd|passphrase|secret|api[_-]?key)\b[`\"'*)\]]*\s*(?:[:=]|=>|->|\bis\b)\s*[`\"'*(\[]*([^\s`\"'*)\],;]+)")
if "credential" not in disabled:
    for p, t in texts:
        for i, line in enumerate(t.split("\n"), 1):
            hit = None
            for name, rx in STRONG:
                m = rx.search(line)
                if m: hit = (name, len(m.group(0))); break
            if not hit:
                m = URLPW.search(line)
                if m and len(m.group(1)) >= 4 and not PH.search(m.group(1)) and not re.match(r"[<{$%]", m.group(1)):
                    hit = ("url-password", len(m.group(1)))
            if not hit:
                for m in MARK.finditer(line):
                    if valid_value(m.group(2)):
                        hit = ("marker-value", len(m.group(2))); break
            if hit:
                find("credential", p, i, "shape=%s [REDACTED len=%d]" % hit)

# ---- layer: private
undet = []
def words(s):
    return re.sub(r"[^a-z0-9]+", " ", s.lower()).split()
SH = 8
if "private" in disabled:
    pass
else:
    priv = private_arg
    if not priv or not os.path.isdir(priv):
        undet.append("private: no private source directory present (%s); the leak layer read nothing" % (priv or "none"))
    else:
        shing = {}
        nfiles = 0
        for dp, dn, fn in os.walk(priv):
            dn.sort()
            for f in sorted(fn):
                fp = os.path.join(dp, f)
                try:
                    if os.path.islink(fp) or os.path.getsize(fp) > 64 * 1024 * 1024:
                        continue  # bounded read: never slurp a multi-GB recording into memory
                    with open(fp, "rb") as fh:
                        head = fh.read(8192)
                        if b"\0" in head:
                            continue
                        b = head + fh.read()
                except OSError:
                    continue
                nfiles += 1
                w = words(b.decode("utf-8", "replace"))
                for k in range(0, max(0, len(w) - SH + 1)):
                    shing[hashlib.sha1(" ".join(w[k:k+SH]).encode()).digest()[:8]] = 1
        if nfiles == 0 or not shing:
            undet.append("private: private source directory holds no readable text; the leak layer read nothing")
        else:
            for p, t in texts:
                for i, line in enumerate(t.split("\n"), 1):
                    w = words(line)
                    for k in range(0, max(0, len(w) - SH + 1)):
                        h = hashlib.sha1(" ".join(w[k:k+SH]).encode()).digest()
                        if h[:8] in shing:
                            find("private", p, i, "shingle=%s" % h.hex()[:12]); break
for d in sorted(disabled):
    undet.append("%s: layer DISABLED (ZG_SCAN_DISABLE); a disabled scan cannot pass" % d)

findings.sort()
for layer, p, ln, d in findings:
    out("FINDING %s %s:%d %s" % (layer, p, ln, d))
for u in undet:
    out("COULD-NOT-INSPECT %s" % u)
pop = hashlib.sha256("\n".join(p for p, _ in texts).encode("utf-8", "surrogateescape")).hexdigest()
out("INSPECTED %d" % len(texts))
out("POPULATION-SHA %s" % pop)
if not texts:
    out("COULD-NOT-INSPECT empty population"); out("VERDICT UNDETERMINED (rc 2)"); sys.exit(2)
if findings:
    out("VERDICT VIOLATED (rc 1) %d finding(s)" % len(findings)); sys.exit(1)
if undet:
    out("VERDICT UNDETERMINED (rc 2)"); sys.exit(2)
out("VERDICT HOLDS (rc 0)"); sys.exit(0)
PYEOF

run_scan() { # $1 root $2 private-root $3.. scopes
    local r=$1 p=$2; shift 2
    local sc
    if [ "$#" -eq 0 ]; then set -- docs/zero-gap "specs/010-*"; fi
    sc=$(printf '%s\n' "$@")
    python3 -I -c "$PYSCAN" "$r" "$p" "${ZG_SCAN_DISABLE:-}" "$sc" "_tests/fixtures/zero-gap/"
}

# ---------------------------------------------------------------- paired proof
prove_failure() {
    local T fails=0 undet=0 rc o
    command -v git >/dev/null 2>&1 && command -v python3 >/dev/null 2>&1 || { echo "prove-failure: git or python3 missing"; return 2; }
    T=$(mktemp -d "${TMPDIR:-/tmp}/zg-scanrec.XXXXXX") || { echo "prove-failure: no temp dir"; return 2; }
    trap 'rm -rf "$T"' RETURN
    mkdir -p "$T/priv" "$T/repo/docs/zero-gap" "$T/repo/specs/010-x"
    git -C "$T/repo" init -q 2>/dev/null || { echo "prove-failure: git init failed"; return 2; }
    # a private source: one distinctive 12-word sentence
    echo "the migrating heron negotiated seventeen quiet lanterns beside every frozen orchard gate" >"$T/priv/session.txt"
    # control: clean prose, a permitted UNCONFIRMED form, a quoted mention of a hedge word
    cat >"$T/repo/docs/zero-gap/control.md" <<'EOF'
The gate failed because the fixture was missing.
The cause: UNCONFIRMED: probably the cache, not yet measured because the log rotated.
Rule text: never write "probably" in a causal statement because it is a guess.
EOF
    assert() { # name expected-rc must-contain
        local name=$1 want=$2 needle=$3
        o=$(run_scan "$T/repo" "$T/priv" 2>&1); rc=$?
        if [ "$rc" -ne "$want" ]; then echo "  FAIL $name: rc=$rc want=$want"; echo "$o" | sed 's/^/    /'; fails=$((fails+1)); return; fi
        if [ -n "$needle" ] && ! printf '%s\n' "$o" | grep -q -- "$needle"; then echo "  FAIL $name: output lacks '$needle'"; fails=$((fails+1)); return; fi
        echo "  ok   $name (rc=$rc)"
    }
    assert "C0 control corpus is clean" 0 "VERDICT HOLDS"
    # planted: guessing
    echo "The sweep stalled because the host was probably under load." >"$T/repo/docs/zero-gap/bad-guess.md"
    assert "M1 hedged causal statement is caught" 1 "FINDING guessing docs/zero-gap/bad-guess.md:1"
    ZG_SCAN_DISABLE=guessing assert "M1b with the guessing layer disabled the corpus is NOT clean (rc 2, never 0)" 2 "DISABLED"
    rm "$T/repo/docs/zero-gap/bad-guess.md"
    # planted: credential (constructed at proof time so no secret-shaped text sits in this file at rest)
    local k1="AKIA""ABCDEFGH12345678" k2="gh""p_$(printf 'a1B2c3D4e5%.0s' 1 2 3 4)"
    printf 'key id %s in a note\n' "$k1" >"$T/repo/docs/zero-gap/bad-aws.md"
    assert "M2 AWS key id is caught and the value is not printed" 1 "FINDING credential docs/zero-gap/bad-aws.md:1 shape=aws-key-id"
    if run_scan "$T/repo" "$T/priv" 2>&1 | grep -q "$k1"; then echo "  FAIL M2b the matched value was printed"; fails=$((fails+1)); else echo "  ok   M2b matched value is not printed"; fi
    rm "$T/repo/docs/zero-gap/bad-aws.md"
    printf 'token %s\n' "$k2" >"$T/repo/docs/zero-gap/bad-tok.md"
    assert "M3 vendor token prefix is caught" 1 "shape=token-prefix"
    rm "$T/repo/docs/zero-gap/bad-tok.md"
    printf 'db password: Zk8%%q2Lm9x\n' >"$T/repo/specs/010-x/bad-pw.md"
    assert "M4 marker=value password is caught in specs/010-*" 1 "FINDING credential specs/010-x/bad-pw.md:1 shape=marker-value"
    printf 'password: <your-password-here>\n' >"$T/repo/specs/010-x/bad-pw.md"
    assert "C1 a placeholder password is not a finding" 0 "VERDICT HOLDS"
    rm "$T/repo/specs/010-x/bad-pw.md"
    # planted: private leak
    echo "He said: the migrating heron negotiated seventeen quiet lanterns beside every frozen orchard gate, loudly." >"$T/repo/docs/zero-gap/bad-leak.md"
    assert "M5 verbatim private text is caught by shingle and not printed" 1 "FINDING private docs/zero-gap/bad-leak.md:1"
    if run_scan "$T/repo" "$T/priv" 2>&1 | grep -qi "heron"; then echo "  FAIL M5b private text printed"; fails=$((fails+1)); else echo "  ok   M5b private text is not printed"; fi
    ZG_SCAN_DISABLE=private assert "M5c with the private layer disabled the result is rc 2, never a pass" 2 "DISABLED"
    rm "$T/repo/docs/zero-gap/bad-leak.md"
    # no private source present => rc 2
    o=$(run_scan "$T/repo" "$T/nonexistent" 2>&1); rc=$?
    if [ "$rc" -eq 2 ] && printf '%s\n' "$o" | grep -q "no private source"; then echo "  ok   M6 absent private source is rc 2 (a leak check that read nothing is not a pass)"; else echo "  FAIL M6 rc=$rc"; fails=$((fails+1)); fi
    # fixture corpus directory is excluded from the scan population
    mkdir -p "$T/repo/_tests/fixtures/zero-gap/x"
    echo "It broke because it was probably the cache." >"$T/repo/_tests/fixtures/zero-gap/x/planted.md"
    assert "C2 the planted-defect corpus itself is out of scope" 0 "VERDICT HOLDS"
    # empty population => rc 2
    o=$(run_scan "$T/repo" "$T/priv" nothing/here 2>&1); rc=$?
    if [ "$rc" -eq 2 ]; then echo "  ok   M7 empty population is rc 2"; else echo "  FAIL M7 empty population rc=$rc"; fails=$((fails+1)); fi
    # not a git repo => rc 2
    o=$(run_scan "$T/priv" "$T/priv" 2>&1); rc=$?
    if [ "$rc" -eq 2 ]; then echo "  ok   M8 non-repo root is rc 2"; else echo "  FAIL M8 rc=$rc"; fails=$((fails+1)); fi
    if [ "$fails" -gt 0 ]; then echo "prove-failure: $fails case(s) failed"; return 1; fi
    echo "prove-failure: all cases passed"; return 0
}

if [ "$PROVE" -eq 1 ]; then prove_failure; exit $?; fi

if [ -z "$ROOT" ]; then ROOT=$(cd "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd); fi
if [ ! -d "$ROOT" ]; then echo "COULD-NOT-INSPECT root absent:$ROOT"; echo "INSPECTED 0"; echo "VERDICT UNDETERMINED (rc 2)"; exit 2; fi
ROOT=$(cd "$ROOT" && pwd)
if [ -z "$PRIVATE" ] && [ -d "$ROOT/workshop/chapters" ]; then PRIVATE="$ROOT/workshop/chapters"; fi
run_scan "$ROOT" "$PRIVATE" "${SCOPES[@]}"
exit $?
