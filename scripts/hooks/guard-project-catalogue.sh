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
import json, os, re, shlex, sys, time

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
        # a quoted value is blanked by scrub() but keeps its quotes, so `FOO='a b' cmd` must be consumed
        # as ONE assignment (before 2026-10-14 the blank inside the quotes ended it and `cmd` was missed)
        m = re.match(r"^([A-Za-z_][A-Za-z0-9_]*=(?:'[^']*'|\"[^\"]*\"|[^\s'\"])*)\s+", t)
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

# ── tmpfs bulk-write rule (host-hang fix WP1, 2026-10-14) ────────────────────────────────────────────
# /tmp, /dev/shm and /run/user/* are RAM-backed tmpfs. On 2026-10-14 (host anton) ~20 agents wrote
# multi-GB copies there (git clones, a `cp -a` gitdir backup, rsync copies); tmpfs shmem grew 0.33 -> 8.1 GB
# and the host stalled in direct reclaim. This refuses the BULK/RECURSIVE write forms whose destination is
# a LITERAL tmpfs path: git clone, git worktree add, git bundle create, cp -a/-r/-R, rsync, tar -x/-c into
# or onto tmpfs, unzip into tmpfs. Single-file writes (cp a /tmp/a, go build -o /tmp/x, > /tmp/f) are
# allowed. A relative destination counts as tmpfs when the cwd is tmpfs: the payload's `cwd`, a preceding
# `cd <literal>` in the same command line, or `git -C <dir>`.
# ESCAPE HATCH: a leading `AGENT_TMPFS_OK='<reason, >= 10 chars>'` assignment on that simple command; it is
# appended to $AGENT_TMPFS_OK_LOG (default <agent-scratch>/tmpfs-overrides.log). An override that cannot be
# logged is refused.
# HONEST LIMITS: a destination held in a variable ($S/x, "$(mktemp -d)") or reached through a symlink is not
# resolved; a command run from a script file, an alias or eval is not seen; heredoc bodies are not judged.
# The structural fix is a disk TMPDIR for the harness (docs/AGENT_GUARDRAILS.md section D).
TMPFS_RE = re.compile(r"^(/tmp|/dev/shm|/run/user/[0-9]+|/var/run/user/[0-9]+)(/|$)")
TMPFS_REASON_MIN = 10

def is_tmpfs_path(p, cwd_tmpfs):
    if not p:
        return False
    if p.startswith("/"):
        return bool(TMPFS_RE.match(os.path.normpath("/" + p.lstrip("/"))))
    if p[0] in "~$":
        return False
    return cwd_tmpfs

REDIR = re.compile(r"^(\d*|&)(>>|>\||>&|>|<<<|<<|<&|<)(.*)$")
def argv_of(rawpart):
    try:
        ws = shlex.split(rawpart)
    except ValueError:
        ws = rawpart.split()
    out, skip = [], False
    for w in ws:
        if skip:
            skip = False; continue
        if w.startswith("#"):
            break
        m = REDIR.match(w)
        if m:
            skip = (m.group(3) == ""); continue
        out.append(w)
    return out

ASSIGN = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)=(.*)$", re.S)
def unwrap(av):
    """Drop leading VAR=value (collected), wrappers and their options; return (env, argv)."""
    env = {}
    while av:
        m = ASSIGN.match(av[0])
        if m:
            env[m.group(1)] = m.group(2); av = av[1:]; continue
        w = av[0]
        if w in ("bounded-run", "systemd-run") and "--" in av:
            av = av[av.index("--") + 1:]; continue
        if w == "timeout":
            av = av[1:]
            while av and av[0].startswith("-"):
                av = av[2:] if av[0] in ("-s", "--signal", "-k", "--kill-after") else av[1:]
            av = av[1:]; continue
        if w in ("nice", "ionice"):
            av = av[1:]
            while av and av[0].startswith("-"):
                av = av[2:] if av[0] in ("-n", "-c", "--adjustment", "--class", "--classdata") else av[1:]
            continue
        if w in WRAP:
            av = av[1:]
            while av and av[0].startswith("-"):
                av = av[1:]
            continue
        break
    return env, av

def git_unwrap(av, cwd_tmpfs):
    """git global options; -C <dir> moves the cwd. Returns (argv, cwd_tmpfs)."""
    if not av or av[0] != "git":
        return av, cwd_tmpfs
    i = 1
    while i < len(av):
        w = av[i]
        if w == "-C" and i + 1 < len(av):
            cwd_tmpfs = is_tmpfs_path(av[i + 1], cwd_tmpfs); i += 2; continue
        if w == "-c" and i + 1 < len(av):
            i += 2; continue
        if w.startswith("--git-dir=") or w.startswith("--work-tree=") or w in ("--no-pager", "--bare", "--no-replace-objects"):
            i += 1; continue
        break
    return ["git"] + av[i:], cwd_tmpfs

def positionals(args, val_opts):
    pos, i = [], 0
    while i < len(args):
        w = args[i]
        if w == "--":
            pos += args[i + 1:]; break
        if w in val_opts:
            i += 2; continue
        if w.startswith("-") and w != "-":
            i += 1; continue
        pos.append(w); i += 1
    return pos

def opt_value(args, shorts, longs):
    """Values of an option in any spelling: -X v, -Xv, --long v, --long=v."""
    vals = []
    for i, w in enumerate(args):
        for s in shorts:
            if w == s and i + 1 < len(args):
                vals.append(args[i + 1])
            elif w.startswith(s) and not w.startswith("--") and len(w) > len(s) and w[1] == s[1] and len(s) == 2 and s[1] in "Cd":
                vals.append(w[len(s):])
        for l in longs:
            if w == l and i + 1 < len(args):
                vals.append(args[i + 1])
            elif w.startswith(l + "="):
                vals.append(w[len(l) + 1:])
    return vals

def r_git_clone(av, cwd):
    if av[:2] != ["git", "clone"]:
        return None
    a = av[2:]
    VAL = {"-b", "--branch", "-o", "--origin", "-u", "--upload-pack", "--depth", "--reference", "--reference-if-able",
           "--separate-git-dir", "-c", "--config", "-j", "--jobs", "--filter", "--shallow-since", "--shallow-exclude",
           "--template", "--bundle-uri", "--server-option"}
    for v in opt_value(a, [], ["--separate-git-dir"]):
        if is_tmpfs_path(v, cwd):
            return v
    pos = positionals(a, VAL)
    if len(pos) >= 2:
        return pos[1] if is_tmpfs_path(pos[1], cwd) else None
    if len(pos) == 1 and cwd:
        return "./" + os.path.basename(pos[0].rstrip("/")).removesuffix(".git")
    return None

def r_git_worktree(av, cwd):
    if av[:3] != ["git", "worktree", "add"]:
        return None
    pos = positionals(av[3:], {"-b", "-B", "--reason"})
    return pos[0] if pos and is_tmpfs_path(pos[0], cwd) else None

def r_git_bundle(av, cwd):
    if av[:3] != ["git", "bundle", "create"]:
        return None
    pos = positionals(av[3:], set())
    return pos[0] if pos and is_tmpfs_path(pos[0], cwd) else None

def r_cp(av, cwd):
    if not av or av[0] != "cp":
        return None
    a = av[1:]
    rec = any(w in ("--recursive", "--archive") or (re.match(r"^-[A-Za-z]+$", w) and re.search(r"[arR]", w)) for w in a)
    if not rec:
        return None
    for v in opt_value(a, ["-t"], ["--target-directory"]):
        return v if is_tmpfs_path(v, cwd) else None
    pos = positionals(a, {"-S", "--suffix", "-t", "--target-directory"})
    return pos[-1] if len(pos) >= 2 and is_tmpfs_path(pos[-1], cwd) else None

def r_rsync(av, cwd):
    if not av or av[0] != "rsync":
        return None
    VAL = {"-e", "--rsh", "-f", "--filter", "-T", "--temp-dir", "-B", "--block-size", "-M", "--remote-option",
           "--exclude", "--include", "--files-from", "--exclude-from", "--include-from", "--link-dest",
           "--compare-dest", "--copy-dest", "--log-file", "--chmod", "--chown", "--partial-dir", "--backup-dir", "--suffix"}
    pos = positionals(av[1:], VAL)
    if len(pos) < 2:
        return None
    d = pos[-1]
    if d.startswith("rsync://") or re.match(r"^[^/]*:", d):
        return None
    return d if is_tmpfs_path(d, cwd) else None

def tar_flags(a):
    """(flag letters, rest) — old-style first word ('xzf') counts as a cluster."""
    letters = ""
    for i, w in enumerate(a):
        if i == 0 and w and not w.startswith("-") and re.match(r"^[A-Za-z]+$", w):
            letters += w
        elif re.match(r"^-[A-Za-z]+$", w):
            letters += w[1:]
    return letters

def r_tar_extract(av, cwd):
    if not av or av[0] not in ("tar", "gtar", "bsdtar"):
        return None
    a = av[1:]
    if not ("x" in tar_flags(a) or "--extract" in a or "--get" in a):
        return None
    dirs = opt_value(a, ["-C"], ["--directory"])
    if dirs:
        return dirs[-1] if is_tmpfs_path(dirs[-1], cwd) else None
    return "." if cwd else None

def r_tar_create(av, cwd):
    if not av or av[0] not in ("tar", "gtar", "bsdtar"):
        return None
    a = av[1:]
    fl = tar_flags(a)
    if not ("c" in fl or "--create" in a):
        return None
    files = opt_value(a, [], ["--file"])
    if not files and "f" in fl:
        # the archive is the word after the cluster that holds f (old style: the first non-cluster word)
        for i, w in enumerate(a):
            if (re.match(r"^-[A-Za-z]+$", w) or (i == 0 and re.match(r"^[A-Za-z]+$", w))) and "f" in w and i + 1 < len(a):
                files = [a[i + 1]]; break
    for f in files:
        if f != "-" and is_tmpfs_path(f, cwd):
            return f
    return None

def r_unzip(av, cwd):
    if not av or av[0] != "unzip":
        return None
    a = av[1:]
    if any(re.match(r"^-[A-Za-z]*[ltpvZ]", w) and not w.startswith("-d") for w in a):
        return None
    dirs = opt_value(a, ["-d"], [])
    if dirs:
        return dirs[-1] if is_tmpfs_path(dirs[-1], cwd) else None
    return "." if cwd else None

TMPFS_RULES = [
    ("git-clone", r_git_clone),               # BRANCH:git-clone
    ("git-worktree-add", r_git_worktree),     # BRANCH:git-worktree-add
    ("git-bundle-create", r_git_bundle),      # BRANCH:git-bundle-create
    ("cp-recursive", r_cp),                   # BRANCH:cp-recursive
    ("rsync", r_rsync),                       # BRANCH:rsync
    ("tar-extract", r_tar_extract),           # BRANCH:tar-extract
    ("tar-create", r_tar_create),             # BRANCH:tar-create
    ("unzip", r_unzip),                       # BRANCH:unzip
]

HEREDOC = re.compile(r"<<-?\s*(['\"]?)([A-Za-z_][A-Za-z0-9_]*)\1")
def strip_heredocs(raw):
    out, lines, i = [], raw.split("\n"), 0
    while i < len(lines):
        ln = lines[i]; out.append(ln)
        tags = [m.group(2) for m in HEREDOC.finditer(ln)] if "<<" in ln else []
        i += 1
        for tag in tags:
            while i < len(lines) and lines[i].strip() != tag:
                i += 1
            i += 1
    return "\n".join(out)

def tmpfs_judge(raw, ctx, depth=0):
    """None, or (branch, dest). Records reasoned overrides in ctx['overrides']."""
    if depth > 3:
        return None
    for rawpart, sc in simple_commands(strip_heredocs(raw) if depth == 0 else raw):
        env, av = unwrap(argv_of(rawpart))
        if not av:
            continue
        if av[0] in ("cd", "pushd"):
            tgt = av[1] if len(av) > 1 else "~"
            ctx["cwd"] = False if tgt == "-" else is_tmpfs_path(tgt, ctx["cwd"])
            continue
        if av[0] in ("sh", "bash", "zsh", "dash") and "-c" in av[1:3]:
            k = av.index("-c")
            if k + 1 < len(av):
                v = tmpfs_judge(av[k + 1], ctx, depth + 1)
                if v:
                    return v
            continue
        av, cwd = git_unwrap(av, ctx["cwd"])
        for name, fn in TMPFS_RULES:
            dest = fn(av, cwd)
            if not dest:
                continue
            reason = env.get("AGENT_TMPFS_OK", "").strip()
            if len(reason) >= TMPFS_REASON_MIN:
                ctx["overrides"].append((name, dest, reason, rawpart.strip()))
                break
            return (name, dest, "AGENT_TMPFS_OK" in env)
    return None

def log_overrides(ovs):
    path = os.environ.get("AGENT_TMPFS_OK_LOG") or os.path.join(
        os.environ.get("AGENT_SCRATCH_ROOT") or os.path.expanduser("~/.cache/agent-scratch"), "tmpfs-overrides.log")
    try:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_APPEND, 0o600)
        with os.fdopen(fd, "a", encoding="utf-8") as fh:
            for name, dest, reason, cmd in ovs:
                cmd = re.sub(r"://[^/@\s]+@", "://***@", cmd)[:500]
                fh.write(json.dumps({"ts": time.strftime("%Y-%m-%dT%H:%M:%S%z"), "rule": name, "dest": dest,
                                     "reason": reason, "command": cmd}) + "\n")
        return True, path
    except OSError as e:
        return False, "%s (%s)" % (path, e.strerror)

def main():
    mode, path = sys.argv[1], sys.argv[2]
    root = sys.argv[3] if len(sys.argv) > 3 else "."
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
    if not hit:
        cwd = payload.get("cwd")
        ctx = {"cwd": isinstance(cwd, str) and is_tmpfs_path(cwd, False), "overrides": []}
        t = tmpfs_judge(cmd, ctx)
        helper = os.path.join(root, "scripts", "agent-scratch.sh")
        if t:
            name, dest, short_reason = t
            sys.stderr.write(
                "BLOCKED by guard-project-catalogue (tmpfs-bulk-write:%s): this writes a bulk/recursive copy into "
                "RAM-backed tmpfs (%s). /tmp, /dev/shm and /run/user/* are RAM: on 2026-10-14 multi-GB copies there "
                "stalled the host (tmpfs shmem 0.33 -> 8.1 GB, direct-reclaim storm). Write to disk instead: "
                "S=$(bash %s new <label>) and use \"$S\"/... (same filesystem as ~/Projects, so `cp -al` hardlink "
                "backups work and cost no data). If a tmpfs write is truly required, prefix the command with "
                "AGENT_TMPFS_OK='<reason, >= %d chars>' (it is logged)%s.\n"
                % (name, dest, helper, TMPFS_REASON_MIN, "; the AGENT_TMPFS_OK reason given is too short" if short_reason else ""))
            return 2
        if ctx["overrides"]:
            ok_, where = log_overrides(ctx["overrides"])
            if not ok_:
                sys.stderr.write("BLOCKED by guard-project-catalogue (tmpfs-bulk-write): an AGENT_TMPFS_OK override "
                                 "must be logged and the log is not writable: %s\n" % where)
                return 2
            return 0
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

run_hook() { python3 -I -c "$PY" "$1" "$2" "$ROOT_DEFAULT"; }

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
             "nohup pkill -f workshop-server" "time git stash" "true | killall workshop-server" "FOO='a b' git add -A"; do
        probe "$c"; rc=$?
        [ "$rc" -eq 2 ] || { e=$((e+1)); echo "    evasion not refused: $c rc=$rc"; }
    done
    [ "$e" -eq 0 ] && ok "P3 9 evasion shapes refused (incl. a quoted VAR='a b' prefix)" || bad "P3 $e evasion shapes allowed"
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
    # ── tmpfs bulk-write rule (host-hang fix WP1, 2026-10-14) ──────────────────────────────────────────
    local FX="$HERE/fixtures/tmpfs-guard" br cwd cmdl lbl
    [ -f "$FX/golden-bad.tsv" ] && [ -f "$FX/golden-good.tsv" ] || { echo "COULD-NOT-PROVE: tmpfs fixtures missing under $FX"; return 2; }
    probe_cwd() { # $1 command  $2 cwd ('-' = none)  [$3 python program, default the hook's]
        local j; j=$(python3 -I -c 'import json,sys
d={"tool_name":"Bash","tool_input":{"command":sys.argv[1]}}
if sys.argv[2]!="-": d["cwd"]=sys.argv[2]
print(json.dumps(d))' "$1" "$2")
        printf '%s' "$j" | AGENT_TMPFS_OK_LOG="$T/override.log" python3 -I -c "${3:-$PY}" hook "$CAT" "$ROOT_DEFAULT" 2>"$T/stderr"
    }
    # P8 every golden-bad row is refused (rc 2) and the refusal names the tmpfs rule or a catalogue class
    local nb=0 tb=0
    while IFS=$'\t' read -r br cwd cmdl; do
        case "$br" in ''|'#'*) continue ;; esac
        tb=$((tb+1)); probe_cwd "$cmdl" "$cwd"; rc=$?
        if [ "$rc" -ne 2 ] || ! grep -q 'tmpfs-bulk-write' "$T/stderr"; then nb=$((nb+1)); echo "    golden-bad not refused by the tmpfs rule: [$br] $cmdl rc=$rc"; fi
    done <"$FX/golden-bad.tsv"
    [ "$tb" -gt 0 ] && [ "$nb" -eq 0 ] && ok "P8 all $tb golden-bad tmpfs bulk writes refused" || bad "P8 $nb of $tb golden-bad rows allowed"
    # P9 every golden-good row is allowed (rc 0): single files, disk destinations, reads, mentions
    local ng=0 tg=0
    while IFS=$'\t' read -r lbl cwd cmdl; do
        case "$lbl" in ''|'#'*) continue ;; esac
        tg=$((tg+1)); probe_cwd "$cmdl" "$cwd"; rc=$?
        [ "$rc" -eq 0 ] || { ng=$((ng+1)); echo "    golden-good wrongly refused: [$lbl] $cmdl rc=$rc"; }
    done <"$FX/golden-good.tsv"
    [ "$tg" -gt 0 ] && [ "$ng" -eq 0 ] && ok "P9 all $tg golden-good commands allowed" || bad "P9 $ng of $tg golden-good rows refused"
    # P9b a heredoc BODY is data, not a command: writing a script that mentions a tmpfs copy is allowed
    probe_cwd "$(printf "cat > notes.sh <<'EOF'\ncp -a big /tmp/x\nEOF\nwc -l notes.sh")" -; rc=$?
    [ "$rc" -eq 0 ] && ok "P9b a heredoc body mentioning cp -a ... /tmp is not judged as a command" || bad "P9b rc=$rc"
    # P10 escape hatch: a reasoned AGENT_TMPFS_OK prefix is allowed AND logged; an unloggable override is refused
    rm -f "$T/override.log"
    probe_cwd "AGENT_TMPFS_OK='tiny 4 KB fixture for a tmpfs containment test' cp -a fx /tmp/fx" -; rc=$?
    local logged=1; grep -q 'tiny 4 KB fixture' "$T/override.log" 2>/dev/null && logged=0
    local j2; j2=$(python3 -I -c 'import json;print(json.dumps({"tool_name":"Bash","tool_input":{"command":"AGENT_TMPFS_OK=\"a long enough reason\" cp -a a /tmp/b"}}))')
    printf '%s' "$j2" | AGENT_TMPFS_OK_LOG=/proc/nonexistent/override.log python3 -I -c "$PY" hook "$CAT" "$ROOT_DEFAULT" 2>/dev/null; local rc4=$?
    [ "$rc" -eq 0 ] && [ "$logged" -eq 0 ] && [ "$rc4" -eq 2 ] && ok "P10 reasoned override allowed+logged; unloggable override refused" || bad "P10 rc=$rc logged=$logged unloggable-rc=$rc4"
    # P11 per-branch mutation: removing each rule branch lets at least one of ITS golden-bad rows through
    local branches mb=0 nbr=0 slipped PYm
    branches=$(grep -o '# BRANCH:[a-z-]*' <<<"$PY" | sed 's/# BRANCH://' | sort -u)
    [ -n "$branches" ] || bad "P11 no '# BRANCH:' markers found in the hook program"
    for b in $branches; do
        nbr=$((nbr+1)); PYm=$(grep -v "# BRANCH:$b\$" <<<"$PY"); slipped=0
        while IFS=$'\t' read -r br cwd cmdl; do
            [ "$br" = "$b" ] || continue
            probe_cwd "$cmdl" "$cwd" "$PYm"; [ $? -eq 0 ] && slipped=$((slipped+1))
        done <"$FX/golden-bad.tsv"
        [ "$slipped" -gt 0 ] || { mb=$((mb+1)); echo "    mutant without branch '$b' still refuses every '$b' row: the fixture does not exercise it"; }
    done
    [ "$nbr" -gt 0 ] && [ "$mb" -eq 0 ] && ok "P11 each of $nbr rule branches removed => a named golden-bad row slips (P8 would FAIL)" || bad "P11 $mb of $nbr branch mutants undetected"
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
