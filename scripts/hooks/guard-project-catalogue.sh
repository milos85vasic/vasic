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
# HOW A COMMAND LINE IS READ (rewritten 2026-10-14 after an independent review). One shell lexer serves
# every rule: backslash-newline continuation; '...', "...", $'...' quoting and backslash escapes (so
# `FOO='a b' cmd` and `FOO=a\ b cmd` are ONE assignment); comments; the operators ; ;; & && || | |& ( )
# and newline; redirections (an fd number glued to them is dropped); here-strings (data) and
# here-documents (data, EXCEPT when the receiving command is a shell: `bash <<EOF` bodies execute and are
# judged). $(...) and `...` are judged as commands. Each simple command is then normalised: leading
# reserved words (! { } if then elif else do while until), `for`/`case`/`select` headers, VAR=value
# prefixes, wrappers (env command exec nohup builtin setsid nice ionice timeout stdbuf taskset chrt xargs
# flock sudo doas time watch, and bounded-run / agent-admit.sh / systemd-run up to `--`, also when run as
# `bash <path>/agent-admit.sh`), absolute binary paths (/usr/bin/git -> git) and git global options.
# Nested scripts are judged recursively: `sh|bash|zsh -<cluster with c> '<script>'`, eval, env -S,
# flock -c, watch, find -exec/-execdir/-ok.
#
# CATALOGUE RULE. Every row of the catalogue with expected=refused is a CLASS (its `candidate` ERE; `-`:
# the literal tokens), matched at COMMAND POSITION of the normalised command (every wrapper stage is
# tried), so `echo will reboot later` and `git commit -m "avoid git add -A"` are allowed while
# `{ git add -A; }`, `for f in a; do git add -A; done`, `/usr/bin/git add -A`, `bash -lc 'git add -A'` and
# `$(git clean -fd)` are refused. A class that begins with `-` (--no-verify, --force-with-lease) is matched
# against each argument word. `git stash list|show` and `git restore --staged` (no --worktree) are allowed;
# a match ending in `/` followed by more path (`rm -rf ~/Projects/x`) is a sub-path and is allowed.
# Force-push in ANY spelling is refused structurally (see push_verdict).
#
# TMPFS RULE (host-hang fix WP1, 2026-10-14). Refuses writes that bring DISK data into RAM-backed tmpfs
# (/tmp, /dev/shm, /run/user/N): git clone / worktree add / bundle create / archive, git writing into a
# repo or work tree on tmpfs (fetch, pull, checkout, ...), cp -a|-r|-R, mv, rsync, podman|docker cp, tar
# -x / tar -c, unzip, zip -r, 7z, podman|docker save|export, curl -o/-O, wget, dd of=, and the stdout
# forms (`git archive > /tmp/x`, `tar -cf - . > /tmp/x`). Destinations are resolved through literal
# paths, `cd`/`pushd` (subshell-scoped), `git -C`, `env -C`, VAR=literal assignments made earlier on the
# same line, $TMPDIR / ${TMPDIR:-/tmp} (from the hook's own environment; unset TMPDIR => /tmp) and
# $(mktemp ...) (=> $TMPDIR or /tmp unless -p/--tmpdir/template says otherwise). A copy whose sources are
# ALL already on tmpfs (inside the harness scratchpad) is allowed: it brings no disk data into RAM.
# Single-file writes (cp a /tmp/a, > /tmp/f, go build -o /tmp/x) are allowed. The only escape is an inline
# AGENT_TMPFS_OK='<at least 3 distinct real words>' prefix on THAT command (an earlier `export` does not
# count); it is appended to $AGENT_TMPFS_OK_LOG (default <agent-scratch>/tmpfs-overrides.log) and refused
# when the log cannot be written. An agent can still write such a reason: the log is the control.
#
# NOT SEEN, by construction (both rules; the upstream guard shares them): a script FILE run by name
# (`bash x.sh`, `./x.sh`), an alias or shell function, `source`/`.` of a file, code inside an interpreter
# (`python3 -c "shutil.copytree(...)"`, perl, node, make recipes), text built at run time (base64, printf
# into eval, variables assigned by `read` or in an earlier Bash call), a destination reached through a
# symlink (`ln -s /tmp/x lnk && cp -a src lnk/`), a here-document fed to a non-shell interpreter
# (`python3 - <<EOF`), a command substitution other than mktemp used as a path (treated as unknown, i.e.
# disk), positional/special parameters ($1, $@), process substitution, and writes by tools not listed
# above (e.g. `go mod download` into GOMODCACHE=/tmp/x, `npm ci --cache /tmp/x`). Use a disk TMPDIR
# (docs/AGENT_GUARDRAILS.md section D) for the structural fix.
# No escape-hatch marker exists for the catalogue rule: `# guardrails:allow` changes nothing.
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
import json, os, re, sys, time

# ════════════════════════════════════════════════════════════════════════════════════════════════════
# Catalogue
# ════════════════════════════════════════════════════════════════════════════════════════════════════
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

# ════════════════════════════════════════════════════════════════════════════════════════════════════
# Shell lexer (2026-10-14 rewrite). One tokeniser for every rule, so a construct is either understood by
# all rules or by none. Handles: backslash-newline continuation, '…', "…" (with \ escapes), $'…',
# $(…) / `…` (recorded: they EXECUTE and are judged), $((…)) arithmetic (data), ${…}, comments, the
# operators ; ;; & && || | |& ( ) and newline, redirections (an fd number glued to them is dropped),
# here-strings (<<< word: data) and here-documents (<<[-] DELIM: the body is captured and judged only
# when the command that receives it is a shell).
# ════════════════════════════════════════════════════════════════════════════════════════════════════
OPS = [";;&", ";;", ";&", "&&", "||", "|&", "&>>", "&>", ">>", ">|", ">&", "<&", "<>", "<<<", "<<-", "<<",
       ";", "&", "|", "(", ")", ">", "<", "\n"]
REDIR_OPS = {">", ">>", ">|", "&>", "&>>", ">&", "<", "<&", "<>", "<<<", "<<", "<<-"}
OUT_REDIRS = {">", ">>", ">|", "&>", "&>>", ">&"}

def find_close(s, i, oc, cc):
    """Index of the bracket closing an opening at s[i-1] (quotes and nesting respected)."""
    depth, n = 1, len(s)
    while i < n:
        c = s[i]
        if c == "\\":
            i += 2; continue
        if c == "'":
            j = s.find("'", i + 1); i = n if j < 0 else j + 1; continue
        if c == '"':
            i = skip_dq(s, i + 1); continue
        if c == oc:
            depth += 1
        elif c == cc:
            depth -= 1
            if depth == 0:
                return i
        i += 1
    return n

def skip_dq(s, i):
    n = len(s)
    while i < n:
        c = s[i]
        if c == "\\":
            i += 2; continue
        if c == '"':
            return i + 1
        if s.startswith("$(", i):
            i = find_close(s, i + 2, "(", ")") + 1; continue
        if c == "`":
            j = s.find("`", i + 1); i = n if j < 0 else j + 1; continue
        i += 1
    return n

ANSI = {"n": "\n", "t": "\t", "\\": "\\", "'": "'", '"': '"', "e": "\x1b", "a": "\a", "r": "\r", " ": " "}

def lex(s):
    toks = []
    n, i = len(s), 0
    st = {"buf": [], "q": False, "subs": [], "in": False, "delim": None}
    pending = []

    def end_word():
        if st["in"]:
            w = {"t": "".join(st["buf"]), "q": st["q"], "subs": st["subs"]}
            if st["delim"] is not None:
                pending.append((w["t"], st["delim"])); st["delim"] = None
            toks.append(("W", w))
        st.update(buf=[], q=False, subs=[], **{"in": False})

    def put(x, quoted=False):
        st["buf"].append(x); st["in"] = True
        if quoted:
            st["q"] = True

    while i < n:
        c = s[i]
        if c == "\\" and s.startswith("\n", i + 1): i += 2; continue  # MUTANT:continuation
        if c == "\\":
            if i + 1 < n:
                put(s[i + 1], True)
            i += 2; continue
        if c == "'":
            j = s.find("'", i + 1); j = n if j < 0 else j
            put(s[i + 1:j], True); i = j + 1; continue
        if s.startswith("$'", i):
            j, out = i + 2, []
            while j < n and s[j] != "'":
                if s[j] == "\\" and j + 1 < n:
                    out.append(ANSI.get(s[j + 1], "\\" + s[j + 1])); j += 2; continue
                out.append(s[j]); j += 1
            put("".join(out), True); i = j + 1; continue
        if c == '"':
            j, out = i + 1, []
            while j < n and s[j] != '"':
                if s[j] == "\\" and j + 1 < n:
                    if s[j + 1] == "\n":
                        j += 2; continue
                    if s[j + 1] in '$`"\\':
                        out.append(s[j + 1]); j += 2; continue
                    out.append("\\"); j += 1; continue
                if s.startswith("$((", j):
                    k = find_close(s, j + 3, "(", ")"); out.append(s[j:k + 2]); j = k + 2; continue
                if s.startswith("$(", j):
                    k = find_close(s, j + 2, "(", ")"); st["subs"].append(s[j + 2:k]); out.append(s[j:k + 1]); j = k + 1; continue
                if s[j] == "`":
                    k = s.find("`", j + 1); k = n if k < 0 else k
                    st["subs"].append(s[j + 1:k]); out.append(s[j:k + 1]); j = k + 1; continue
                out.append(s[j]); j += 1
            put("".join(out), True); i = j + 1; continue
        if s.startswith("$((", i):
            k = find_close(s, i + 3, "(", ")"); put(s[i:k + 2]); i = k + 2; continue
        if s.startswith("$(", i):
            k = find_close(s, i + 2, "(", ")"); st["subs"].append(s[i + 2:k]); put(s[i:k + 1]); i = k + 1; continue
        if s.startswith("${", i):
            k = s.find("}", i + 2); k = n if k < 0 else k; put(s[i:k + 1]); i = k + 1; continue
        if c == "`":
            k = s.find("`", i + 1); k = n if k < 0 else k
            st["subs"].append(s[i + 1:k]); put(s[i:k + 1]); i = k + 1; continue
        if c == "#" and not st["in"]:
            j = s.find("\n", i); i = n if j < 0 else j; continue
        if c in " \t":
            end_word(); i += 1; continue
        op = next((o for o in OPS if s.startswith(o, i)), None)
        if op:
            if op in REDIR_OPS and st["in"] and not st["q"] and "".join(st["buf"]).isdigit():
                st.update(buf=[], **{"in": False})
            end_word()
            if op == "\n":
                i += 1
                for delim, strip in pending:
                    body = []
                    while i < n:
                        j = s.find("\n", i)
                        line = s[i:] if j < 0 else s[i:j]
                        i = n if j < 0 else j + 1
                        if (line.lstrip("\t") if strip else line) == delim:
                            break
                        body.append(line)
                    toks.append(("H", "\n".join(body)))
                pending.clear()
                toks.append(("O", "\n"))
                continue
            toks.append(("O", op)); i += len(op)
            if op in ("<<", "<<-"):
                st["delim"] = (op == "<<-")
            continue
        put(c); i += 1
    end_word()
    return toks

def commands(toks):
    """[("cmd", words, redirs, heredocs) | ("open",) | ("close",)]"""
    out, cur = [], {"w": [], "r": [], "h": []}

    def emit():
        if cur["w"] or cur["r"] or cur["h"]:
            out.append(("cmd", cur["w"], cur["r"], cur["h"]))
        cur.update(w=[], r=[], h=[])
    i = 0
    while i < len(toks):
        k, v = toks[i]
        if k == "W":
            cur["w"].append(v)
        elif k == "H":
            cur["h"].append(v)
        elif v in REDIR_OPS:
            tgt = None
            if i + 1 < len(toks) and toks[i + 1][0] == "W":
                tgt = toks[i + 1][1]; i += 1
            cur["r"].append((v, tgt))
        elif v in ("(", ")"):
            emit(); out.append(("open",) if v == "(" else ("close",))
        else:
            emit()
        i += 1
    emit()
    return out

# ════════════════════════════════════════════════════════════════════════════════════════════════════
# Expansion and paths
# ════════════════════════════════════════════════════════════════════════════════════════════════════
TMPFS_RE = re.compile(r"^(/tmp|/dev/shm|/run/user/[0-9]+|/var/run/user/[0-9]+)(/|$)")
UNKNOWN = object()
VARRE = re.compile(r"\$\{([A-Za-z_][A-Za-z0-9_]*)(?:(:?[-=+?])([^}]*))?\}|\$([A-Za-z_][A-Za-z0-9_]*)")

def tmp_default():
    return os.environ.get("TMPDIR") or "/tmp"

def lookup(name, ctx):
    if name in ctx["vars"]:
        return ctx["vars"][name]
    if name == "TMPDIR":
        return tmp_default()          # unset TMPDIR: mktemp & co. fall back to /tmp
    return os.environ.get(name)       # each Bash call is a fresh shell: unset means empty

def mktemp_path(inner, ctx):
    items = [x for x in commands(lex(inner)) if x[0] == "cmd"]
    if len(items) != 1:
        return None
    a = [w["t"] for w in items[0][1]]
    if not a or bn(a[0]) != "mktemp":
        return None
    d, tmpl, tflag, i = None, None, False, 1
    while i < len(a):
        w = a[i]
        if w in ("-p", "--tmpdir") and i + 1 < len(a) and w == "-p":
            d = expand(a[i + 1], ctx); i += 2; continue
        if w.startswith("--tmpdir="):
            d = expand(w.split("=", 1)[1], ctx); i += 1; continue
        if w in ("-t", "--tmpdir"):
            tflag = True; i += 1; continue
        if w.startswith("-"):
            i += 1; continue
        tmpl = w; i += 1
    if d is None and (tflag or tmpl is None):
        d = tmp_default()
    if d is None:                       # bare relative/absolute template
        if tmpl.startswith("/"):
            return os.path.dirname(tmpl) + "/tmp.XXXXXXXX"
        return ctx["cwd"] + "/tmp.XXXXXXXX" if ctx["cwd"] else None
    return d + "/tmp.XXXXXXXX"  # MUTANT:mktemp

def expand(text, ctx, depth=0):
    """Expanded word text, or None when a part cannot be known statically."""
    if text is None or depth > 4:
        return None
    t = text
    for m in list(re.finditer(r"\$\(((?:[^()]|\([^()]*\))*)\)|`([^`]*)`", t)):
        r = mktemp_path(m.group(1) if m.group(1) is not None else m.group(2), ctx)
        if r is None:
            return None
        t = t.replace(m.group(0), r, 1)
    if "$((" in t:
        return None
    bad = []

    def rep(m):
        name = m.group(1) or m.group(4)
        op, dflt = m.group(2), m.group(3)
        v = lookup(name, ctx)
        if v is UNKNOWN:
            bad.append(name); return ""
        if op and op.endswith(("-", "=")) and (v is None or (op.startswith(":") and v == "")):
            e = expand(dflt or "", ctx, depth + 1)
            if e is None:
                bad.append(name); return ""
            return e
        return v or ""
    t = VARRE.sub(rep, t)
    if bad or re.search(r"\$[0-9@*#?!$-]", t):
        return None              # positional/special parameters cannot be known statically
    return t

def resolve(text, ctx):
    v = expand(text, ctx)
    if v is None or v == "":
        return None
    if v == "~" or v.startswith("~/"):
        v = os.environ.get("HOME", "/nonexistent-home") + v[1:]
    elif v.startswith("~"):
        return None
    if not v.startswith("/"):
        if not ctx["cwd"]:
            return None
        v = ctx["cwd"] + "/" + v
    v = os.path.normpath("/" + v.lstrip("/"))  # MUTANT:normpath
    return v

def is_tmpfs(p):
    return p is not None and bool(TMPFS_RE.match(p))

# ════════════════════════════════════════════════════════════════════════════════════════════════════
# Command normalisation: assignments, reserved words, wrappers, absolute binary paths, git globals
# ════════════════════════════════════════════════════════════════════════════════════════════════════
ASSIGN = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)(\[[^\]]*\])?\+?=(.*)$", re.S)
RESERVED = {"!", "{", "}", "if", "then", "elif", "else", "do", "while", "until", "fi", "done", "esac", "in"}
HEADERS = {"for", "case", "select", "function"}
SHELLS = {"sh", "bash", "zsh", "dash", "ksh", "mksh", "rbash"}
# wrapper -> options taking a separate value
WRAPPERS = {
    "env": {"-u", "--unset", "-C", "--chdir", "-S", "--split-string"},
    "command": set(), "exec": {"-a"}, "nohup": set(), "builtin": set(), "setsid": set(),
    "nice": {"-n", "--adjustment"}, "ionice": {"-c", "--class", "-n", "--classdata"},
    "timeout": {"-s", "--signal", "-k", "--kill-after"},
    "stdbuf": {"-i", "-o", "-e", "--input", "--output", "--error"},
    "taskset": set(), "chrt": set(),
    "xargs": {"-I", "-n", "-P", "-L", "-s", "-d", "-E", "-a", "--arg-file", "--delimiter", "--max-args",
              "--max-procs", "--max-lines", "--max-chars", "--eof", "--replace", "--process-slot-var"},
    "flock": {"-w", "--timeout", "-E", "--conflict-exit-code", "-c", "--command"},
    "sudo": {"-u", "-g", "-C", "-D", "-h", "-p", "-r", "-t", "-U", "-T"}, "doas": {"-u", "-C"},
    "time": set(), "watch": {"-n", "--interval"},
    "bounded-run": {"-m", "-t", "-c", "-s", "-T", "-n"}, "agent-admit.sh": {"--slots", "--tag", "--wait", "-m", "-T"},
    "systemd-run": {"-p", "--property", "-u", "--unit", "-E", "--setenv", "-M", "--machine", "-H", "--host",
                    "--slice", "--description", "--uid", "--gid", "--nice", "--working-directory"},
}

def bn(t):
    return t.rsplit("/", 1)[-1] if "/" in t else t

def wtext(w):
    return re.sub(r"\s", " ", w["t"])

def strip_reserved(a):
    while a and a[0]["t"] in RESERVED and not a[0]["q"]:
        a = a[1:]
    return a

def unwrap(words):
    """-> dict(env, assigns, argv, stages, nested, nested_argv, chdir, lookup)"""
    r = {"env": {}, "assigns": [], "argv": [], "stages": [], "nested": [], "nested_argv": [], "chdir": None,
         "lookup": False, "header": False}
    a = list(words)
    a = strip_reserved(a)  # MUTANT:reserved
    if a and a[0]["t"] in HEADERS and not a[0]["q"]:
        r["header"] = True
        return r
    while a and ASSIGN.match(a[0]["t"]):
        m = ASSIGN.match(a[0]["t"])
        r["env"][m.group(1)] = m.group(3); r["assigns"].append(a[0]); a = a[1:]
    a = strip_reserved(a)  # MUTANT:reserved
    r["stages"].append(a)
    for _ in range(12):
        if not a:
            break
        name = bn(a[0]["t"])
        if name == "time":
            a = a[1:]
            while a and a[0]["t"] in ("-p", "--"):
                a = a[1:]
            r["stages"].append(a); continue
        if name in ("bounded-run", "agent-admit.sh", "systemd-run") and any(w["t"] == "--" for w in a[1:]):
            k = next(i for i, w in enumerate(a) if i > 0 and w["t"] == "--")
            a = a[k + 1:]; r["stages"].append(a); continue
        if name not in WRAPPERS:
            break
        vals, rest, i = WRAPPERS[name], a[1:], 0
        opts = []
        while i < len(rest):
            t = rest[i]["t"]
            if t == "--":
                i += 1; break
            if not t.startswith("-") or t == "-":
                break
            opts.append(t)
            if t in vals and i + 1 < len(rest):
                if name == "env" and t in ("-C", "--chdir"):
                    r["chdir"] = rest[i + 1]["t"]
                if name == "env" and t in ("-S", "--split-string"):
                    r["nested"].append(rest[i + 1]["t"])
                if name == "flock" and t in ("-c", "--command"):
                    r["nested"].append(rest[i + 1]["t"])
                i += 2; continue
            if name == "env" and t.startswith("--chdir="):
                r["chdir"] = t.split("=", 1)[1]
            if name == "xargs" and re.match(r"^-[iI].", t):
                pass
            i += 1
        rest = rest[i:]
        if name == "command" and any(o in ("-v", "-V") for o in opts):
            r["lookup"] = True; return r
        if name in ("taskset", "chrt") and any(o in ("-p", "--pid") for o in opts):
            r["lookup"] = True; return r
        if name == "ionice" and any(o in ("-p", "--pid") for o in opts):
            r["lookup"] = True; return r
        if name == "env":
            while rest and ASSIGN.match(rest[0]["t"]):
                m = ASSIGN.match(rest[0]["t"]); r["env"][m.group(1)] = m.group(3); rest = rest[1:]
        if name in ("timeout", "taskset", "chrt") and rest:
            rest = rest[1:]                      # DURATION / mask-or-list / priority
        if name == "flock" and rest:
            rest = rest[1:]                      # the lock file
        if name == "watch" and rest:
            r["nested"].append(" ".join(w["t"] for w in rest)); rest = []
        a = rest
        r["stages"].append(a)
    if a and bn(a[0]["t"]) == "eval":
        r["nested"].append(" ".join(w["t"] for w in a[1:]))
    if a and bn(a[0]["t"]) == "find":
        k = 0
        while k < len(a):
            if a[k]["t"] in ("-exec", "-execdir", "-ok", "-okdir"):
                j = k + 1
                while j < len(a) and a[j]["t"] not in (";", "+"):
                    j += 1
                r["nested_argv"].append(a[k + 1:j]); k = j  # MUTANT:find-exec
            k += 1
    r["argv"] = a
    return r

def git_globals(argv):
    """Strip git global options. -> (argv texts, chdir, work_tree, git_dir)"""
    a = [w["t"] for w in argv]
    if not a or bn(a[0]) != "git":
        return a, [], None, None
    chdirs, wt, gd, i = [], None, None, 1
    while i < len(a):
        w = a[i]
        if w == "-C" and i + 1 < len(a):
            chdirs.append(a[i + 1]); i += 2; continue
        if w in ("-c", "--git-dir", "--work-tree", "--namespace", "--exec-path", "--config-env") and i + 1 < len(a):
            if w == "--git-dir":
                gd = a[i + 1]
            if w == "--work-tree":
                wt = a[i + 1]
            i += 2; continue
        if w.startswith("--git-dir="):
            gd = w.split("=", 1)[1]; i += 1; continue
        if w.startswith("--work-tree="):
            wt = w.split("=", 1)[1]; i += 1; continue
        if w.startswith("--") and "=" in w or w in ("--no-pager", "--bare", "--paginate", "-p", "-P", "--no-replace-objects",
                                                    "--literal-pathspecs", "--glob-pathspecs", "--noglob-pathspecs",
                                                    "--icase-pathspecs", "--no-optional-locks", "--no-advice"):
            i += 1; continue
        break
    return ["git"] + a[i:], chdirs, wt, gd

# ════════════════════════════════════════════════════════════════════════════════════════════════════
# Catalogue + force-push judgement on normalised commands
# ════════════════════════════════════════════════════════════════════════════════════════════════════
READONLY = re.compile(r"^git (stash (list|show)\b|restore --staged(?!.*(--worktree|-W|\s-\S*W)))")
PUSH_SHORT = re.compile(r"^-[A-Za-z]*[fd][A-Za-z]*$")

def push_verdict(a):
    if len(a) < 2 or a[0] != "git" or a[1] != "push":
        return False
    for w in a[2:]:
        if w == "--":
            continue
        if w.startswith("--forc") or w == "--mirror" or PUSH_SHORT.match(w):
            return True
        if w.startswith("+") and len(w) > 1:
            return True
    return False

def catalogue_hit(stage_texts, rules):
    """stage_texts: list of argv(text) lists for every unwrap stage."""
    for a in stage_texts:
        if not a:
            continue
        a = [bn(a[0])] + a[1:]  # MUTANT:basename
        t = " ".join(re.sub(r"\s", " ", x) for x in a)
        if READONLY.match(t):
            continue
        for id_, rx in rules:
            if rx.pattern.startswith("-"):
                if any(rx.match(x) for x in a[1:]):
                    return id_
                continue
            m = rx.match(t)
            if not m:
                continue
            end = m.end()
            if m.group(0).endswith("/") and end < len(t) and not t[end].isspace():
                continue
            return id_
        if push_verdict(a):
            return "force-push-any-spelling"
    return None

# ════════════════════════════════════════════════════════════════════════════════════════════════════
# tmpfs bulk-write rule (host-hang fix WP1, 2026-10-14; widened after the independent review)
# ════════════════════════════════════════════════════════════════════════════════════════════════════
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

def opt_values(args, shorts=(), longs=(), attach=()):
    vals = []
    for i, w in enumerate(args):
        if w in shorts or w in longs:
            if i + 1 < len(args):
                vals.append(args[i + 1])
            continue
        for l in longs:
            if w.startswith(l + "="):
                vals.append(w[len(l) + 1:])
        for s in attach:
            if w.startswith(s) and len(w) > len(s) and not w.startswith("--"):
                vals.append(w[len(s):])
    return vals

def cluster_has(args, letters, first_bare=False):
    for i, w in enumerate(args):
        if re.match(r"^-[A-Za-z]+$", w) and any(c in w[1:] for c in letters):
            return True
        if first_bare and i == 0 and re.match(r"^[A-Za-z]+$", w) and any(c in w for c in letters):
            return True
    return False

class C:
    """One normalised command for the tmpfs rules."""
    def __init__(self, a, ctx, out):
        self.a, self.ctx, self.out = a, ctx, out
    def p(self, text):
        return resolve(text, self.ctx)
    def tm(self, text):
        return is_tmpfs(self.p(text))
    def out_tmpfs(self):
        return next((o for o in self.out if is_tmpfs(o)), None)

def copy_like(c, sources, dest):
    """A copy INTO tmpfs whose data comes from outside it. tmpfs -> tmpfs (e.g. inside the harness
    scratchpad) is allowed: it does not bring disk data into RAM. An unknown source counts as disk."""
    d = c.p(dest)
    if not is_tmpfs(d):
        return None
    if sources and all(not REMOTE.match(s) and is_tmpfs(c.p(s)) for s in sources):
        return None
    return d

REMOTE = re.compile(r"^[^/]*:")

CLONE_VAL = {"-b", "--branch", "-o", "--origin", "-u", "--upload-pack", "--depth", "--reference", "--reference-if-able",
             "--separate-git-dir", "-c", "--config", "-j", "--jobs", "--filter", "--shallow-since", "--shallow-exclude",
             "--template", "--bundle-uri", "--server-option", "--revision", "--ref-format"}

def r_git_clone(c, x):
    a = c.a
    if a[:2] != ["git", "clone"]:
        return None
    for v in opt_values(a[2:], longs=("--separate-git-dir",)):
        if c.tm(v):
            return c.p(v)
    pos = positionals(a[2:], CLONE_VAL)
    for p in pos[1:]:                    # every positional after the source: an unknown option cannot hide it
        if c.tm(p):
            return c.p(p)
    if len(pos) == 1:
        d = c.p(os.path.basename(pos[0].rstrip("/")).removesuffix(".git") or "repo")
        return d if is_tmpfs(d) else None
    return None

def r_git_worktree(c, x):
    if c.a[:3] != ["git", "worktree", "add"]:
        return None
    pos = positionals(c.a[3:], {"-b", "-B", "--reason", "--orphan"})
    return c.p(pos[0]) if pos and c.tm(pos[0]) else None

def r_git_bundle(c, x):
    if c.a[:3] != ["git", "bundle", "create"]:
        return None
    pos = positionals(c.a[3:], set())
    if pos and pos[0] != "-":
        return c.p(pos[0]) if c.tm(pos[0]) else None
    return c.out_tmpfs()

def r_git_archive(c, x):
    if c.a[:2] != ["git", "archive"]:
        return None
    outs = opt_values(c.a[2:], ("-o",), ("--output",))
    if outs:
        return c.p(outs[-1]) if c.tm(outs[-1]) else None
    return c.out_tmpfs()

GIT_WRITE = {"fetch", "pull", "checkout", "restore", "switch", "read-tree", "merge", "rebase", "cherry-pick", "am",
             "apply", "stash", "reset", "clean", "worktree", "submodule", "lfs", "sparse-checkout", "init"}

def r_git_tmpfs_repo(c, x):
    """git writing objects/files into a repository or work tree that lives on tmpfs."""
    a = c.a
    if len(a) < 2 or a[0] != "git" or a[1] not in GIT_WRITE or a[1] == "clone":
        return None
    for d in (x.get("git_wt"), x.get("git_dir")):
        if d and c.tm(d):
            return c.p(d)
    if a[1] in ("worktree", "init"):
        return None
    if c.ctx["cwd"] and is_tmpfs(c.ctx["cwd"]):
        return c.ctx["cwd"]
    return None

def r_cp(c, x):
    a = c.a
    if not a or a[0] != "cp":
        return None
    args = a[1:]
    if not (cluster_has(args, "arR") or any(w in ("--recursive", "--archive") for w in args)):
        return None
    tdir = opt_values(args, ("-t",), ("--target-directory",))
    pos = positionals(args, {"-S", "--suffix", "-t", "--target-directory"})
    if tdir:
        return copy_like(c, pos, tdir[-1])
    return copy_like(c, pos[:-1], pos[-1]) if len(pos) >= 2 else None

def r_mv(c, x):
    """mv from disk into tmpfs is a cross-device FULL copy."""
    a = c.a
    if not a or a[0] != "mv":
        return None
    args = a[1:]
    tdir = opt_values(args, ("-t",), ("--target-directory",))
    pos = positionals(args, {"-S", "--suffix", "-t", "--target-directory"})
    if tdir:
        return copy_like(c, pos, tdir[-1])
    return copy_like(c, pos[:-1], pos[-1]) if len(pos) >= 2 else None

RSYNC_VAL = {"-e", "--rsh", "-f", "--filter", "-T", "--temp-dir", "-B", "--block-size", "-M", "--remote-option",
             "--exclude", "--include", "--files-from", "--exclude-from", "--include-from", "--link-dest",
             "--compare-dest", "--copy-dest", "--log-file", "--chmod", "--chown", "--partial-dir", "--backup-dir",
             "--suffix", "--rsync-path", "--password-file", "--port", "--timeout", "--max-size", "--min-size", "--bwlimit"}

def r_rsync(c, x):
    if not c.a or c.a[0] != "rsync":
        return None
    pos = positionals(c.a[1:], RSYNC_VAL)
    if len(pos) < 2:
        return None
    d = pos[-1]
    if d.startswith("rsync://") or re.match(r"^[^/]*:", d):
        return None
    return copy_like(c, pos[:-1], d)

TAR = ("tar", "gtar", "bsdtar")

def r_tar_extract(c, x):
    a = c.a
    if not a or a[0] not in TAR:
        return None
    args = a[1:]
    if not (cluster_has(args, "x", first_bare=True) or "--extract" in args or "--get" in args):
        return None
    dirs = opt_values(args, ("-C",), ("--directory",), attach=("-C",))
    if dirs:
        return c.p(dirs[-1]) if c.tm(dirs[-1]) else None
    cw = c.ctx["cwd"]
    return cw if is_tmpfs(cw) else None

def r_tar_create(c, x):
    a = c.a
    if not a or a[0] not in TAR:
        return None
    args = a[1:]
    if not (cluster_has(args, "c", first_bare=True) or "--create" in args):
        return None
    files = opt_values(args, (), ("--file",), attach=("-f",))
    if not files:
        for i, w in enumerate(args):
            if (re.match(r"^-[A-Za-z]+$", w) or (i == 0 and re.match(r"^[A-Za-z]+$", w))) and "f" in w and i + 1 < len(args):
                files = [args[i + 1]]; break
    if files and files[-1] != "-":
        return c.p(files[-1]) if c.tm(files[-1]) else None
    return c.out_tmpfs()

def r_unzip(c, x):
    a = c.a
    if not a or a[0] != "unzip":
        return None
    args = a[1:]
    for w in args:
        if w == "-v" or (re.match(r"^-[A-Za-z]+$", w) and not w.startswith("-d") and re.search(r"[ltpZc]", w[1:])):
            return None                   # list / test / pipe / zipinfo / to-stdout modes write nothing
    dirs = opt_values(args, ("-d",), (), attach=("-d",))
    if dirs:
        return c.p(dirs[-1]) if c.tm(dirs[-1]) else None
    cw = c.ctx["cwd"]
    return cw if is_tmpfs(cw) else None

def r_zip(c, x):
    a = c.a
    if not a or a[0] != "zip":
        return None
    args = a[1:]
    if not (cluster_has(args, "rR") or "--recurse-paths" in args):
        return None
    pos = positionals(args, {"-b", "-n", "-t", "-tt", "-x", "-i", "-P", "-O", "--out"})
    outs = opt_values(args, ("-O", "--out"))
    z = outs[-1] if outs else (pos[0] if pos else None)
    if z == "-":
        return c.out_tmpfs()
    return c.p(z) if z and c.tm(z) else None

def r_7z(c, x):
    a = c.a
    if not a or a[0] not in ("7z", "7za", "7zr", "7zz"):
        return None
    pos = positionals(a[1:], set())
    if not pos:
        return None
    if pos[0] in ("x", "e"):
        outs = opt_values(a[1:], attach=("-o",))
        if outs:
            return c.p(outs[-1]) if c.tm(outs[-1]) else None
        cw = c.ctx["cwd"]
        return cw if is_tmpfs(cw) else None
    if pos[0] in ("a", "u") and len(pos) > 1:
        return c.p(pos[1]) if c.tm(pos[1]) else None
    return None

def r_container(c, x):
    a = c.a
    if len(a) < 2 or a[0] not in ("podman", "docker", "nerdctl", "buildah", "skopeo"):
        return None
    if a[1] in ("save", "export", "image") and (a[1] != "image" or (len(a) > 2 and a[2] in ("save",))):
        outs = opt_values(a[2:], ("-o",), ("--output",))
        if outs:
            return c.p(outs[-1]) if c.tm(outs[-1]) else None
        return c.out_tmpfs()
    if a[1] in ("cp", "container") and (a[1] == "cp" or (len(a) > 2 and a[2] == "cp")):
        pos = positionals(a[2:] if a[1] == "cp" else a[3:], set())
        return copy_like(c, pos[:-1], pos[-1]) if len(pos) >= 2 else None
    return None

def r_download(c, x):
    a = c.a
    if not a or a[0] not in ("curl", "wget"):
        return None
    args = a[1:]
    if a[0] == "curl":
        outs = opt_values(args, ("-o",), ("--output",))
        for o in outs:
            if o != "-" and c.tm(o):
                return c.p(o)
        if any(w in ("-O", "--remote-name", "--remote-name-all") or re.match(r"^-[A-Za-z]*O[A-Za-z]*$", w) for w in args):
            dirs = opt_values(args, (), ("--output-dir",))
            d = c.p(dirs[-1]) if dirs else c.ctx["cwd"]
            return d if is_tmpfs(d) else None
        return None
    outs = opt_values(args, ("-O",), ("--output-document",), attach=("-O",))
    if outs:
        return None if outs[-1] == "-" else (c.p(outs[-1]) if c.tm(outs[-1]) else None)
    dirs = opt_values(args, ("-P",), ("--directory-prefix",), attach=("-P",))
    d = c.p(dirs[-1]) if dirs else c.ctx["cwd"]
    return d if is_tmpfs(d) else None

def r_dd(c, x):
    if not c.a or c.a[0] != "dd":
        return None
    for w in c.a[1:]:
        if w.startswith("of=") and c.tm(w[3:]):
            return c.p(w[3:])
    return None

TMPFS_RULES = [
    ("git-clone", r_git_clone),               # BRANCH:git-clone
    ("git-worktree-add", r_git_worktree),     # BRANCH:git-worktree-add
    ("git-bundle-create", r_git_bundle),      # BRANCH:git-bundle-create
    ("git-archive", r_git_archive),           # BRANCH:git-archive
    ("git-tmpfs-repo", r_git_tmpfs_repo),     # BRANCH:git-tmpfs-repo
    ("cp-recursive", r_cp),                   # BRANCH:cp-recursive
    ("mv-into-tmpfs", r_mv),                  # BRANCH:mv-into-tmpfs
    ("rsync", r_rsync),                       # BRANCH:rsync
    ("tar-extract", r_tar_extract),           # BRANCH:tar-extract
    ("tar-create", r_tar_create),             # BRANCH:tar-create
    ("unzip", r_unzip),                       # BRANCH:unzip
    ("zip", r_zip),                           # BRANCH:zip
    ("7z", r_7z),                             # BRANCH:7z
    ("container-image", r_container),         # BRANCH:container-image
    ("download", r_download),                 # BRANCH:download
    ("dd", r_dd),                             # BRANCH:dd
]

TMPFS_REASON_WORDS = 3

def reason_ok(r):
    """At least TMPFS_REASON_WORDS distinct real words (>= 3 letters). An agent can still write one; the
    log is the control, not this check."""
    words = set(w.lower() for w in re.findall(r"[A-Za-z]{3,}", r or ""))
    if len(words) < TMPFS_REASON_WORDS: return False  # MUTANT:reason-words
    return bool((r or "").strip())

# ════════════════════════════════════════════════════════════════════════════════════════════════════
# Judge
# ════════════════════════════════════════════════════════════════════════════════════════════════════
def sub_ctx(ctx):
    return {"cwd": ctx["cwd"], "prev": ctx.get("prev"), "vars": dict(ctx["vars"]), "stack": [],
            "dirs": list(ctx.get("dirs", [])), "overrides": ctx["overrides"]}

def judge_script(raw, rules, ctx, depth=0):
    """None | ("cat", id) | ("tmpfs", branch, dest, reason_given)"""
    if depth > 5:
        return None
    try:
        items = commands(lex(raw))
    except (IndexError, ValueError, RecursionError):
        return None
    for it in items:
        if it[0] == "open":
            ctx["stack"].append((ctx["cwd"], ctx.get("prev"), dict(ctx["vars"]))); continue
        if it[0] == "close":
            if ctx["stack"]: ctx["cwd"], ctx["prev"], ctx["vars"] = ctx["stack"].pop()  # MUTANT:subshell-scope
            continue
        v = judge_cmd(it, rules, ctx, depth)
        if v:
            return v
    return None

def judge_cmd(it, rules, ctx, depth):
    words, redirs, hds = it[1], it[2], it[3]
    for w in words + [t for _, t in redirs if t]:
        for sub in w["subs"]:
            v = judge_script(sub, rules, sub_ctx(ctx), depth + 1)
            if v:
                return v
    u = unwrap(words)
    if u["header"] or u["lookup"]:
        return None
    stages = [[x["t"] for x in s] for s in u["stages"]]
    argv, chdirs, gwt, gdir = git_globals(u["argv"])
    stages.append(argv)
    hit = catalogue_hit(stages, rules)
    if hit:
        return ("cat", hit)
    for na in u["nested_argv"]:
        v = judge_cmd(("cmd", na, [], []), rules, sub_ctx(ctx), depth + 1)
        if v:
            return v
    for script in u["nested"]:
        v = judge_script(script, rules, sub_ctx(ctx), depth + 1)
        if v:
            return v
    if not argv or not argv[0]:
        if u["assigns"]:                      # VAR=value alone: remembered for later words
            for w in u["assigns"]:
                m = ASSIGN.match(w["t"]); e = expand(m.group(3), ctx)
                ctx["vars"][m.group(1)] = UNKNOWN if e is None else e  # MUTANT:assign-vars
        return None
    name = bn(argv[0])
    a = [name] + argv[1:]
    if name in ("export", "declare", "typeset", "local", "readonly"):
        for t in a[1:]:
            m = ASSIGN.match(t)
            if m:
                e = expand(m.group(3), ctx); ctx["vars"][m.group(1)] = UNKNOWN if e is None else e
        return None
    if name == "unset":
        for t in a[1:]:
            ctx["vars"][t] = None
        return None
    if name in ("cd", "pushd", "popd"):
        args = [t for t in a[1:] if t not in ("-L", "-P", "-e", "-@", "--")]
        if name == "popd":
            ctx["cwd"] = ctx["dirs"].pop() if ctx.get("dirs") else None
            return None
        tgt = args[0] if args else "~"
        if name == "pushd":
            ctx.setdefault("dirs", []).append(ctx["cwd"])
        if tgt == "-":
            ctx["cwd"], ctx["prev"] = ctx.get("prev"), ctx["cwd"]
        else:
            ctx["prev"], ctx["cwd"] = ctx["cwd"], resolve(tgt, ctx)
        return None
    if name in SHELLS:
        # `bash scripts/agent-admit.sh -- CMD` / `bash .../bounded-run -- CMD`: a wrapper run as a script file
        k = next((i for i, t in enumerate(a) if i > 0 and bn(t) in ("agent-admit.sh", "bounded-run")), None)
        if k is not None and not chdirs:
            return judge_cmd(("cmd", u["argv"][k:], redirs, hds), rules, ctx, depth + 1)
        args, script, files, i = a[1:], None, [], 0
        while i < len(args):
            w = args[i]
            if w in ("-o", "+o", "-O", "+O") and i + 1 < len(args):
                i += 2; continue
            if w.startswith("-") and not w.startswith("--") and "c" in w[1:] and script is None:
                j = i + 1
                while j < len(args) and args[j].startswith("-"):
                    j += 1
                script = args[j] if j < len(args) else ""; break
            if w.startswith("-") or w.startswith("+"):
                i += 1; continue
            files.append(w); i += 1
        if script is not None:
            return judge_script(script, rules, sub_ctx(ctx), depth + 1)
        # `bash <<EOF` / `bash -s` (no script file): the here-document IS the script
        v = None
        v = next((r for r in (judge_script(b, rules, sub_ctx(ctx), depth + 1) for b in hds) if r), None)  # MUTANT:heredoc-shell
        return v if not files else None
    cctx = ctx
    if chdirs or u["chdir"]:
        cctx = sub_ctx(ctx)
        for d in ([u["chdir"]] if u["chdir"] else []) + chdirs:
            cctx["cwd"] = resolve(d, cctx)
    out = [resolve(t["t"], cctx) for op, t in redirs if op in OUT_REDIRS and t and not t["t"].isdigit() and t["t"] != "-"]
    c = C(a, cctx, out)
    x = {"git_wt": gwt, "git_dir": gdir}
    for bname, fn in TMPFS_RULES:
        try:
            dest = fn(c, x)
        except (IndexError, ValueError, TypeError, AttributeError):
            dest = None
        if not dest:
            continue
        reason = u["env"].get("AGENT_TMPFS_OK", "")
        if reason_ok(reason):
            ctx["overrides"].append((bname, dest, reason.strip(), " ".join(w["t"] for w in words)))
            return None
        return ("tmpfs", bname, dest, "AGENT_TMPFS_OK" in u["env"])
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
    if not isinstance(payload, dict) or payload.get("tool_name") != "Bash":
        return 0
    cmd = (payload.get("tool_input") or {}).get("command")
    if not isinstance(cmd, str):
        return 0
    cwd = payload.get("cwd")
    ctx = {"cwd": os.path.normpath(cwd) if isinstance(cwd, str) and cwd.startswith("/") else None,
           "prev": None, "vars": {}, "stack": [], "dirs": [], "overrides": []}
    hit = judge_script(cmd, rules, ctx)
    helper = os.path.join(root, "scripts", "agent-scratch.sh")
    if hit and hit[0] == "cat":
        sys.stderr.write(
            "BLOCKED by guard-project-catalogue (VSC-367): the command matches the refused class '%s' of "
            "docs/zero-gap/guarded-commands.tsv. Use a bounded alternative (named paths, a validated pid, "
            "git add <path>).\n" % hit[1])
        return 2
    if hit:
        _, name, dest, short_reason = hit
        sys.stderr.write(
            "BLOCKED by guard-project-catalogue (tmpfs-bulk-write:%s): this writes a bulk copy into RAM-backed "
            "tmpfs (%s). /tmp, /dev/shm and /run/user/* are RAM: on 2026-10-14 multi-GB copies there stalled the "
            "host (tmpfs shmem 0.33 -> 8.1 GB, direct-reclaim storm). Write to disk instead: "
            "S=$(bash %s new <label>) and use \"$S\"/... (same filesystem as ~/Projects, so `cp -al` hardlink "
            "backups work). If a tmpfs write is truly required, prefix THIS command with "
            "AGENT_TMPFS_OK='<a reason of at least %d real words>' (it is logged)%s.\n"
            % (name, dest, helper, TMPFS_REASON_WORDS,
               "; the AGENT_TMPFS_OK reason given is not a real reason" if short_reason else ""))
        return 2
    if ctx["overrides"]:
        ok_, where = log_overrides(ctx["overrides"])
        if not ok_:
            sys.stderr.write("BLOCKED by guard-project-catalogue (tmpfs-bulk-write): an AGENT_TMPFS_OK override "
                             "must be logged and the log is not writable: %s\n" % where)
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
        printf '%s' "$j" | env -u TMPDIR AGENT_TMPFS_OK_LOG="$T/override.log" python3 -I -c "${3:-$PY}" hook "$CAT" "$ROOT_DEFAULT" 2>"$T/stderr"
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
    # Case driver: runs the hook program ($1) over cases.jsonl rows; prints "<id> <expect> <rc>" per row.
    printf '%s' "$PY" >"$T/hook.py"
    drive() { # $1 program file  $2 jsonl  [$3 comma-separated ids]  -> lines "id expect rc branch"
        env -u TMPDIR AGENT_TMPFS_OK_LOG="$T/override.log" python3 -I - "$1" "$CAT" "$ROOT_DEFAULT" "$2" "${3:-}" <<'PYDRV'
import json, subprocess, sys
prog, cat, root, cases, only = sys.argv[1:6]
want = set(only.split(",")) if only else None
for line in open(cases, encoding="utf-8"):
    r = json.loads(line)
    if want is not None and r["id"] not in want:
        continue
    d = {"tool_name": "Bash", "tool_input": {"command": r["cmd"]}}
    if r.get("cwd", "-") != "-":
        d["cwd"] = r["cwd"]
    p = subprocess.run([sys.executable, "-I", prog, "hook", cat, root], input=json.dumps(d), capture_output=True, text=True)
    print(r["id"], r["expect"], p.returncode, r.get("branch", "-"))
PYDRV
    }
    # P12 every reviewer case (tracked fixture cases.jsonl): B => rc 2, A => rc 0; L rows are DOCUMENTED limits,
    #     printed, never asserted either way
    local pb=0 pa=0 pl=0 bad12=0 id ex rc0 br0
    while read -r id ex rc0 br0; do
        case "$ex" in
            B) pb=$((pb+1)); [ "$rc0" -eq 2 ] || { bad12=$((bad12+1)); echo "    not refused: $id rc=$rc0"; } ;;
            A) pa=$((pa+1)); [ "$rc0" -eq 0 ] || { bad12=$((bad12+1)); echo "    wrongly refused: $id rc=$rc0"; } ;;
            L) pl=$((pl+1)); echo "    LIMIT (documented, not asserted): $id rc=$rc0" ;;
        esac
    done < <(drive "$T/hook.py" "$FX/cases.jsonl")
    [ "$pb" -gt 0 ] && [ "$bad12" -eq 0 ] && ok "P12 cases.jsonl: $pb refused, $pa allowed, $pl documented limits" || bad "P12 $bad12 case(s) wrong"
    # P11 per-branch mutation: removing each rule branch lets at least one of ITS fixture rows through
    local branches mb=0 nbr=0 slipped PYm ids
    branches=$(grep -o '# BRANCH:[a-z0-9-]*' <<<"$PY" | sed 's/# BRANCH://' | sort -u)
    if [ -z "$branches" ]; then bad "P11 no '# BRANCH:' markers found in the hook program"; else
    for b in $branches; do
        nbr=$((nbr+1)); grep -v "# BRANCH:$b\$" <<<"$PY" >"$T/mut.py"; slipped=0
        while IFS=$'\t' read -r br cwd cmdl; do
            [ "$br" = "$b" ] || continue
            probe_cwd "$cmdl" "$cwd" "$(cat "$T/mut.py")"; [ $? -eq 0 ] && slipped=$((slipped+1))
        done <"$FX/golden-bad.tsv"
        ids=$(python3 -I -c 'import json,sys
print(",".join(r["id"] for r in map(json.loads,open(sys.argv[1])) if r["branch"]==sys.argv[2] and r["expect"]=="B"))' "$FX/cases.jsonl" "$b")
        if [ -n "$ids" ]; then
            while read -r id ex rc0 br0; do [ "$rc0" -eq 0 ] && slipped=$((slipped+1)); done < <(drive "$T/mut.py" "$FX/cases.jsonl" "$ids")
        fi
        [ "$slipped" -gt 0 ] || { mb=$((mb+1)); echo "    mutant without branch '$b' still refuses every '$b' row: no fixture exercises it"; }
    done
    [ "$mb" -eq 0 ] && ok "P11 each of $nbr rule branches removed => a named fixture row slips (P8/P12 would FAIL)" || bad "P11 $mb of $nbr branch mutants undetected"
    fi
    # P13 lexer/normaliser mutations: each '# MUTANT:<name>' line removed must flip its named case(s)
    local -A MCASE=([continuation]=rev-F09,rev-L01 [reserved]=rev-F08,rev-F03 [basename]=rev-R06,own-B01,own-B02 [subshell-scope]=rev-G12,own-G01
                    [heredoc-shell]=rev-N24 [reason-words]=rev-OVR [normpath]=rev-N54,rev-N55 [find-exec]=rev-N36
                    [mktemp]=rev-N02,rev-N03 [assign-vars]=rev-N01)
    local mnames nm=0 mm=0 flipped
    mnames=$(grep -o '# MUTANT:[a-z-]*' <<<"$PY" | sed 's/# MUTANT://' | sort -u)
    for b in $mnames; do
        nm=$((nm+1)); grep -v "# MUTANT:$b\$" <<<"$PY" >"$T/mut.py"; flipped=0
        [ -n "${MCASE[$b]:-}" ] || { mm=$((mm+1)); echo "    mutant '$b' has no named case"; continue; }
        while read -r id ex rc0 br0; do
            { [ "$ex" = B ] && [ "$rc0" -ne 2 ]; } || { [ "$ex" = A ] && [ "$rc0" -ne 0 ]; } && flipped=$((flipped+1))
        done < <(drive "$T/mut.py" "$FX/cases.jsonl" "${MCASE[$b]}")
        [ "$flipped" -gt 0 ] && echo "    mutant '$b' caught by ${MCASE[$b]}" || { mm=$((mm+1)); echo "    mutant '$b' NOT caught by ${MCASE[$b]}"; }
    done
    [ "$nm" -ge 8 ] && [ "$mm" -eq 0 ] && ok "P13 $nm lexer/normaliser mutants each caught by a named case" || bad "P13 $mm of $nm mutants undetected"
    # P14 TMPDIR on disk: "$TMPDIR"/${TMPDIR:-/tmp} resolve from the hook's own environment (disk => allowed)
    local jt; jt='{"tool_name":"Bash","tool_input":{"command":"cp -a src \"${TMPDIR:-/tmp}/x\" && cp -a src \"$TMPDIR/y\""}}'
    printf '%s' "$jt" | TMPDIR=/home/agent-disk-tmp python3 -I -c "$PY" hook "$CAT" "$ROOT_DEFAULT" 2>/dev/null; local r14a=$?
    printf '%s' "$jt" | env -u TMPDIR python3 -I -c "$PY" hook "$CAT" "$ROOT_DEFAULT" 2>/dev/null; local r14b=$?
    [ "$r14a" -eq 0 ] && [ "$r14b" -eq 2 ] && ok "P14 \$TMPDIR on disk allowed, unset TMPDIR (=> /tmp) refused" || bad "P14 rc disk=$r14a unset=$r14b"
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
