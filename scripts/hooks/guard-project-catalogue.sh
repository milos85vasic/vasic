#!/usr/bin/env bash
# scripts/hooks/guard-project-catalogue.sh — project-level PreToolUse mitigation (VSC-367, feature 010).
#
# WHY. The only wired PreToolUse hook is the upstream constitution guard
# (submodules/constitution/scripts/hooks/guard-forbidden-commands.sh). Measured by the `guard-gaps`
# sweep class, it lets 21 destructive commands of docs/zero-gap/guarded-commands.tsv through. That
# guard is upstream code this repository does not edit, so the project closes the gap with a SECOND
# hook that enforces the same tracked catalogue until the upstream guard catches up.
#
# CONTRACT (Claude Code PreToolUse hook). stdin: the tool call as JSON ({"tool_name":"Bash",
# "tool_input":{"command":"..."}}). Exit 0 allow; exit 2 BLOCK, the stderr text is fed back to the
# agent. Exit 1 = catalogue unreadable: NON-blocking but loud (blocking every command would also block
# repairing the catalogue); the check `--check-catalogue` makes that state visible to a gate.
#
# WHAT IT REFUSES. Every row of the catalogue with expected=refused. A row's CLASS is its `candidate`
# extended regex (`-`: the literal command tokens). The regex is matched at COMMAND POSITION of each
# simple command of the QUOTE-SCRUBBED command line, never anywhere inside it, so
#   echo will reboot later   grep -n halt build.log   git commit -m "avoid git add -A"
# are allowed while `ls && git reset --hard`, `git -C x add -A`, `FOO=1 reboot`, `bash -c 'git add -A'`
# and `$(git clean -fd)` are refused. Rules applied before matching:
#   * quoted text is blanked (single, double, $'...'), so a mention is not a call;
#   * the line is split into simple commands on ; & | newline ( ) ` and $( ;
#   * leading VAR=value words and the wrappers command/exec/nohup/time/env/nice/xargs are dropped;
#   * git global options (-C <p>, -c <k=v>, --git-dir=, --work-tree=, --no-pager) are dropped;
#   * `sh|bash|zsh|dash -c '<script>'`: the script text (unscrubbed) is judged recursively;
#   * a class regex that begins with `-` (a flag: --no-verify, --force-with-lease) is searched anywhere
#     in the simple command, not only at command position;
#   * `git stash list|show` and `git restore --staged <path>` (no --worktree) are read-only/index-only
#     and allowed although their class regex is broader;
#   * a match that ends in `/` and is followed by more path (`rm -rf ~/Projects/x`) is a sub-path, not
#     the guarded root, and is allowed.
# NOT SEEN, by construction: a destructive command built at run time (variables, base64, eval of a
# file), a script file run by name, a heredoc body, an alias. The upstream guard shares these limits.
# No escape-hatch marker exists: a `# guardrails:allow` comment does not change the verdict.
#
# USAGE  (hook)            guard-project-catalogue.sh              < tool-call JSON
#        --check-catalogue [--root DIR]    rc 0 loads / 2 missing, empty or malformed
#        --prove-failure                   paired proof (rc 0 = every assertion held)
# Dependencies: bash, python3.
set -u
HERE=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT_DEFAULT=$(CDPATH='' cd -- "$HERE/../.." && pwd)
CAT_REL=docs/zero-gap/guarded-commands.tsv

PY=$(cat <<'PYEOF'
import json, re, sys

def load(path):
    rows = []
    try:
        fh = open(path, encoding="utf-8")
    except OSError as e:
        return None, "cannot read catalogue: %s" % e.strerror
    hdr = False
    with fh:
        for n, line in enumerate(fh, 1):
            line = line.rstrip("\n")
            if not line or line.startswith("#"):
                continue
            f = line.split("\t")
            if not hdr:
                if f != ["id", "command", "expected", "source", "candidate"]:
                    return None, "line %d: unexpected header" % n
                hdr = True
                continue
            if len(f) != 5 or not all(f):
                return None, "line %d: a row needs exactly five non-empty fields" % n
            if f[2] not in ("refused", "allowed"):
                return None, "line %d: expected must be refused|allowed" % n
            rows.append(f)
    if not rows:
        return None, "catalogue has no rows"
    out = []
    for id_, cmd, exp, _src, cand in rows:
        if exp != "refused":
            continue
        pat = re.escape(cmd) if cand == "-" else cand
        try:
            out.append((id_, re.compile(pat)))
        except re.error as e:
            return None, "row %s: candidate is not a valid regex (%s)" % (id_, e)
    return out, ""

def scrub(s):
    """Blank quoted text (keep the quotes so word boundaries survive)."""
    out, i, n = [], 0, len(s)
    while i < n:
        c = s[i]
        if c == "\\" and i + 1 < n:
            out.append("  "); i += 2; continue
        if c in "'\"":
            j = i + 1
            while j < n:
                if s[j] == "\\" and c == '"' and j + 1 < n:
                    j += 2; continue
                if s[j] == c:
                    break
                j += 1
            out.append(c + " " * (j - i - 1) + c)
            i = j + 1
            continue
        out.append(c); i += 1
    return "".join(out)

SPLIT = re.compile(r"\$\(|[;&|\n()`]")
WRAP = {"command", "exec", "nohup", "time", "env", "nice", "xargs", "builtin"}
GIT_OPT = re.compile(r"^git(\s+(-C\s+\S+|-c\s+\S+|--git-dir=\S+|--work-tree=\S+|--no-pager))+")

def simple_commands(raw):
    sc = scrub(raw)
    # indexes in sc map 1:1 to raw, so a script text can be taken from raw
    parts, last = [], 0
    for m in SPLIT.finditer(sc):
        parts.append((last, m.start())); last = m.end()
    parts.append((last, len(sc)))
    for a, b in parts:
        yield raw[a:b], sc[a:b]

def normalise(sc):
    t = sc.strip()
    while True:
        m = re.match(r"^([A-Za-z_][A-Za-z0-9_]*=\S*)\s+", t)
        if m:
            t = t[m.end():]; continue
        w = t.split(None, 1)
        if w and w[0] in WRAP and len(w) == 2:
            t = w[1]
            while t.startswith("-") and len(t.split(None, 1)) == 2:
                t = t.split(None, 1)[1]
            continue
        break
    m = GIT_OPT.match(t)
    if m:
        t = "git" + t[m.end():]
    return re.sub(r"\s+", " ", t)

# Read-only / index-only forms whose catalogue class regex is broader than the danger.
READONLY = re.compile(r"^git (stash (list|show)\b|restore --staged(?!.*(--worktree|-W|\s-\S*W)))")

# Force-push in ANY spelling (constitution 11.4.113). The catalogue lists the literal `--force` only, so a
# structural check on the argv of every `git push`: --force* (and unambiguous abbreviations --forc...),
# --force-with-lease, --force-if-includes, a short-flag cluster holding f (-f -fu -uf) or d (delete),
# --mirror (deletes remote refs), a `+refspec`. Quoted words are un-quoted first, so '+main' is seen.
PUSH = re.compile(r"^git push(\s|$)")
PUSH_SHORT = re.compile(r"^-[A-Za-z]*[fd][A-Za-z]*$")
def push_verdict(rawpart):
    t = normalise(re.sub(r"['\"]", "", rawpart))
    if not PUSH.match(t):
        return False
    for w in t.split()[2:]:
        if w == "--":
            continue
        if w.startswith("--forc") or w == "--mirror" or PUSH_SHORT.match(w):
            return True
        if w.startswith("+") and len(w) > 1:
            return True
    return False

def judge(raw, rules, depth=0):
    if depth > 3:
        return None
    for rawpart, sc in simple_commands(raw):
        t = normalise(sc)
        if not t:
            continue
        if READONLY.match(t):
            continue
        for id_, rx in rules:
            # a flag-only class (`--no-verify`) is searched anywhere in the simple command
            m = rx.search(t) if rx.pattern.startswith("-") else rx.match(t)
            if not m:
                continue
            end = m.end()
            if m.group(0).endswith("/") and end < len(t) and not t[end].isspace():
                continue
            return id_
        if PUSH.match(t) and push_verdict(rawpart):
            return "force-push-any-spelling"
        w = t.split()
        if len(w) >= 3 and w[0] in ("sh", "bash", "zsh", "dash") and "-c" in w[1:3]:
            # the script text is the quoted word of the RAW part
            for q in re.finditer(r"'([^']*)'|\"((?:[^\"\\]|\\.)*)\"", rawpart):
                inner = q.group(1) if q.group(1) is not None else q.group(2)
                v = judge(inner, rules, depth + 1)
                if v:
                    return v
    return None

def main():
    mode, path = sys.argv[1], sys.argv[2]
    rules, why = load(path)
    if rules is None:
        sys.stderr.write("guard-project-catalogue: %s\n" % why)
        return 2 if mode == "check" else 1
    if mode == "check":
        print("catalogue ok: %d refused classes" % len(rules))
        return 0
    try:
        payload = json.loads(sys.stdin.read() or "{}")
    except ValueError:
        return 0
    if payload.get("tool_name") != "Bash":
        return 0
    cmd = (payload.get("tool_input") or {}).get("command")
    if not isinstance(cmd, str):
        return 0
    hit = judge(cmd, rules)
    if hit:
        sys.stderr.write(
            "BLOCKED by guard-project-catalogue (VSC-367): the command matches the refused class '%s' of "
            "docs/zero-gap/guarded-commands.tsv. Use a bounded alternative (named paths, a validated pid, "
            "git add <path>).\n" % hit)
        return 2
    return 0

sys.exit(main())
PYEOF
)

run_hook() { python3 -I -c "$PY" "$1" "$2"; }

prove() {
    local pass=0 fail=0 T rc c
    ok() { pass=$((pass+1)); echo "  ok   $*"; }
    bad() { fail=$((fail+1)); echo "  FAIL $*"; }
    T=$(mktemp -d "${TMPDIR:-/tmp}/zg-pcg.XXXXXX") || { echo "COULD-NOT-PROVE: no temp dir"; return 2; }
    trap 'rm -rf "$T"' RETURN
    local CAT="$ROOT_DEFAULT/$CAT_REL"
    [ -f "$CAT" ] || { echo "COULD-NOT-PROVE: catalogue missing"; return 2; }
    probe() { printf '{"tool_name":"Bash","tool_input":{"command":%s}}' "$(python3 -I -c 'import json,sys;print(json.dumps(sys.argv[1]))' "$1")" | run_hook hook "${2:-$CAT}" 2>/dev/null; }
    # P1 every refused catalogue row is refused (rc 2)
    local n=0 miss=0 id cmd exp
    while IFS=$'\t' read -r id cmd exp _; do
        [ "$exp" = refused ] || continue
        n=$((n+1)); probe "$cmd"; rc=$?
        [ "$rc" -eq 2 ] || { miss=$((miss+1)); echo "    not refused: $id ($cmd) rc=$rc"; }
    done < <(grep -v '^#' "$CAT" | tail -n +2)
    [ "$n" -gt 0 ] && [ "$miss" -eq 0 ] && ok "P1 all $n refused catalogue commands blocked" || bad "P1 $miss of $n not blocked"
    # P2 eight benign controls (including the broad-candidate look-alikes) allowed (rc 0)
    local b=0
    for c in "git status" "git add specs/010-zero-gap-verified-closure/tasks.md" "git push origin main" \
             "echo will reboot later" "grep -n halt build.log" "rm -rf ~/Projects/x/build" \
             'git commit -m "avoid git add -A and git reset --hard"' "ls -la && git log --oneline -3"; do
        probe "$c"; rc=$?
        [ "$rc" -eq 0 ] || { b=$((b+1)); echo "    wrongly refused: $c rc=$rc"; }
    done
    [ "$b" -eq 0 ] && ok "P2 8 benign controls allowed" || bad "P2 $b benign controls refused"
    # P3 evasion shapes refused
    local e=0
    for c in "ls && git reset --hard" "git -C /tmp/x add -A" "FOO=1 reboot" "bash -c 'git add -A'" 'echo $(git clean -fd)' \
             "nohup pkill -f workshop-server" "time git stash" "true | killall workshop-server"; do
        probe "$c"; rc=$?
        [ "$rc" -eq 2 ] || { e=$((e+1)); echo "    evasion not refused: $c rc=$rc"; }
    done
    [ "$e" -eq 0 ] && ok "P3 8 evasion shapes refused" || bad "P3 $e evasion shapes allowed"
    # P6 force-push in ANY spelling is refused (constitution 11.4.113); the catalogue only lists `--force`,
    # so the hook carries a structural git-push check. Each case must be rc 2.
    local f=0
    for c in "git push -f" "git push -fu origin main" "git push -uf origin main" "git push origin +main" \
             "git push origin +HEAD:main" "git push --force-if-includes" "git push --force" "git push --force-with-lease=main" \
             "git push --forc origin main" "git push --mirror" "git push -d origin x" "git push -fd origin x" \
             "bash -c 'git push -f'" "sh -c \"git push origin +main\"" "nohup git push -f" "env X=1 xargs git push -f" \
             "git -C /tmp/x push -f" "cd x && git push -f origin main" "git push origin '+main'" "git push -f # guardrails:allow because"; do
        probe "$c"; rc=$?
        [ "$rc" -eq 2 ] || { f=$((f+1)); echo "    force-push spelling not refused: $c rc=$rc"; }
    done
    [ "$f" -eq 0 ] && ok "P6 20 force-push spellings refused" || bad "P6 $f force-push spellings allowed"
    # P7 benign push/fetch controls stay allowed (rc 0); quoted mentions follow the quote-scrub rule
    local g=0
    for c in "git push" "git push -u origin feature" "git push origin main --tags" "git push --follow-tags" \
             "git push -v -n origin main" "git push origin HEAD:refs/heads/feature" "git fetch -f" "git fetch --force origin" \
             'echo "git push -f"' "grep -n 'git push -f' notes.md" 'git commit -m "never git push origin +main"' "git pull -f"; do
        probe "$c"; rc=$?
        [ "$rc" -eq 0 ] || { g=$((g+1)); echo "    benign push control wrongly refused: $c rc=$rc"; }
    done
    [ "$g" -eq 0 ] && ok "P7 12 benign push/fetch controls allowed" || bad "P7 $g benign push controls refused"
    # P4 the escape-hatch marker does not downgrade a refusal
    probe "git add -A # guardrails:allow because"; [ $? -eq 2 ] && ok "P4 no escape hatch" || bad "P4 marker downgraded a refusal"
    # P5 non-Bash tool calls and garbage input pass (never a false block)
    printf '{"tool_name":"Read","tool_input":{"file_path":"x"}}' | run_hook hook "$CAT" 2>/dev/null; rc=$?
    printf 'not json' | run_hook hook "$CAT" 2>/dev/null; local rc2=$?
    [ "$rc" -eq 0 ] && [ "$rc2" -eq 0 ] && ok "P5 non-Bash and malformed input pass" || bad "P5 rc=$rc/$rc2"
    # M1 mutation: a catalogue with the reboot class removed => `reboot` is allowed (the P1 detector would fail)
    grep -v '^host-reboot	' "$CAT" >"$T/m1.tsv"
    probe "reboot" "$T/m1.tsv"; rc=$?
    [ "$rc" -eq 0 ] && ok "M1 removing a row un-blocks it (so P1 is sensitive to the catalogue)" || bad "M1 rc=$rc"
    # M2 mutation: a neutered hook copy allows everything => P1's detector sees it
    printf '#!/usr/bin/env bash\nexit 0\n' >"$T/neutered.sh"
    printf '{"tool_name":"Bash","tool_input":{"command":"git add -A"}}' | bash "$T/neutered.sh"; rc=$?
    [ "$rc" -ne 2 ] && ok "M2 a neutered hook returns $rc, not 2 (P1 would FAIL on it)" || bad "M2 neutered hook blocked?"
    # E1 unreadable catalogue: hook rc 1 (loud, non-blocking); check mode rc 2
    probe "git add -A" "$T/none.tsv"; rc=$?
    run_hook check "$T/none.tsv" 2>/dev/null; local rc3=$?
    [ "$rc" -eq 1 ] && [ "$rc3" -eq 2 ] && ok "E1 missing catalogue: hook rc 1, check rc 2" || bad "E1 rc=$rc/$rc3"
    # L1 latency p95 over 200 probes under 100 ms
    local i s e2 ms; local -a lat=()
    for i in $(seq 1 200); do
        s=$(date +%s%N)
        printf '{"tool_name":"Bash","tool_input":{"command":"git status && ls"}}' | run_hook hook "$CAT" 2>/dev/null
        e2=$(date +%s%N); lat+=($(( (e2 - s) / 1000000 )))
    done
    ms=$(printf '%s\n' "${lat[@]}" | sort -n | sed -n '190p')
    [ "$ms" -lt 100 ] && ok "L1 latency p95=${ms} ms over 200 probes (< 100 ms)" || bad "L1 latency p95=${ms} ms"
    echo "guard-project-catalogue --prove-failure: $pass passed, $fail failed"
    [ "$fail" -eq 0 ]
}

case "${1:-}" in
    --prove-failure) prove; exit $? ;;
    --check-catalogue) shift; ROOT=$ROOT_DEFAULT
        [ "${1:-}" = --root ] && ROOT=${2:-/nonexistent}
        run_hook check "$ROOT/$CAT_REL"; exit $? ;;
    --root) run_hook check "${2:-/nonexistent}/$CAT_REL"; exit $? ;;
    '') run_hook hook "$ROOT_DEFAULT/$CAT_REL"; exit $? ;;
    *) echo "usage: $0 [--check-catalogue [--root DIR] | --prove-failure]" >&2; exit 2 ;;
esac
