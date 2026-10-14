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
# HOW A COMMAND LINE IS READ (rewritten 2026-10-14 after two independent reviews). One shell lexer serves
# every rule: backslash-newline continuation; '...', "...", $'...' quoting and backslash escapes (so
# `FOO='a b' cmd` and `FOO=a\ b cmd` are ONE assignment); comments; the operators ; ;; & && || | |& ( )
# and newline; redirections (an fd number glued to them is dropped); `(( ... ))` and `$(( ... ))`
# arithmetic (data: its `<<` is a shift, not a here-document; a $(...) inside it runs and is judged);
# here-documents and here-strings (data, EXCEPT that a body fed to a shell — `bash <<EOF`, `bash <<< 'cmd'`,
# `bash -s`, `bash /dev/stdin|/dev/fd/0 <<EOF`; with -s every word after it is a positional, not a script
# file — is judged as a script, and the $(...) of an UNQUOTED-delimiter body is judged because the shell
# runs it while expanding); `echo|printf '...' | bash` and `|& bash` (the piped text is judged); $(...)
# and `...` (judged as commands). A VAR=value prefix of a command that runs a script (`TMPDIR=/tmp bash -c
# '...'`, eval, env -S) is in that script's environment. Each simple command is then normalised: leading
# reserved words (! { } if then elif else do while until coproc, and `coproc NAME {`), `function NAME`
# (its body is judged), `for`/`case`/`select` headers (a `for VAR in literal...` list sets VAR), VAR=value
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
# `$(git clean -fd)` are refused. A class that begins with `-` (--no-verify, --force-with-lease) is a GIT
# OPTION, judged on the options a git command really passes, per subcommand: option VALUES are skipped
# (`git commit -m "--no-verify is..."`), unique long prefixes count (`--no-ver`, `--no-veri`), `git commit -n`
# / `-nm msg` is --no-verify (push -n is --dry-run), and subcommands whose arguments are patterns or text
# (grep log show notes stash diff ...) are not judged, so `grep -rn -- --no-verify docs/`, `git grep --
# --no-verify` and `git log -G --no-verify` are allowed. `git stash list|show` is allowed, and `git restore`
# only when it touches the index alone (-S/--staged and NO -W/--worktree in any cluster or prefix:
# `-SW`, `-S -W`, `--staged --work` are refused); a match ending in `/` followed by more path (`rm -rf
# ~/Projects/x`) is a sub-path and is allowed. Structural rows the shared tsv's literal regexes miss
# (project-only; the upstream guard still misses them), each in any cluster or unique long prefix:
# force-push, `git clean` with -f / --forc, `git checkout <ref> -- <whole tree>`, `git add -A|--al|<whole
# tree>`, `git branch -D` / `-d -f` / `--del --forc`, and `rm -r|-R|--rec` of / , /home, $HOME or an
# ancestor (or a glob of one) after normalising (~ $HOME ${HOME:?} the literal home path // /. ~/. ~/..).
# A WHOLE-TREE pathspec is . ./ * ** :/ :(top) and their normalised spellings. Every refusal names what to
# do instead (HINTS; the proof asserts the hint).
#
# TMPFS RULE (host-hang fix WP1, 2026-10-14). Refuses BULK writes that bring DISK data into RAM-backed
# tmpfs (/tmp, /dev/shm, /run/user/N). Bulk means: recursive (cp -a|-r|-R, rsync, zip -r, podman|docker cp),
# a clone/worktree/bundle/archive (git clone / worktree add / bundle create / archive, tar -c), an archive
# extraction (tar -x, unzip, 7z x), git FETCHING into a repo on tmpfs or checking a disk repo out into a
# work tree on tmpfs, podman|docker save|export, a directory or a file over 64 MiB moved (`mv`, a
# cross-device full copy) or copied (`cp` without -r) — size and type are checked on this host —, `dd`
# (of= or stdout redirected onto tmpfs) without count= or over 64 MiB (count x bs, else ibs), `git push`
# into a repository on tmpfs, `git remote update` / `remote add -f` in one, and a download (curl -o/-O,
# wget -O/-P/cwd, or stdout redirected onto tmpfs) whose FILE NAME (the target's or the URL's) is a model or
# an archive (.gguf .bin .safetensors .onnx .pt .tar .tgz .gz .xz .zst .zip .7z .iso .img .whl ...): a
# download's size cannot be known statically, so a small page or JSON fetched into /tmp is allowed. NOT
# bulk (allowed): a single named file of bounded or unknown size (`mv out.txt /tmp/`, `cp a /tmp/a`,
# `> /tmp/f`, `go build -o /tmp/x`, `dd ... count=1`), `cp -l|-s` (links copy no data), a tmpfs -> tmpfs
# copy, and a checkout inside a repo that already lives on tmpfs. Destinations are resolved through
# literal paths, `cd`/`pushd` (subshell-scoped; `cd -`), `git -C`, `env -C`, GIT_DIR/GIT_WORK_TREE,
# VAR=literal and `export VAR=` earlier on the same line, `for VAR in literal`, $TMPDIR / ${TMPDIR:-/tmp}
# (an in-line `export TMPDIR=` wins over the hook's own environment; unset => /tmp) and $(mktemp ...)
# (=> that TMPDIR unless -p/--tmpdir/template says otherwise). The only escape is an inline
# AGENT_TMPFS_OK='<at least 3 distinct real words>' prefix on THAT command (an earlier `export` does not
# count); it is appended to $AGENT_TMPFS_OK_LOG (default <agent-scratch>/tmpfs-overrides.log) and refused
# when the log cannot be written. An agent can still write such a reason: the log is the control.
#
# REPLAY (how the re-review measured false positives; the corpus is NOT tracked: real agent commands carry
# private paths and names into a PUBLIC repository). Extract every Bash tool command from
# ~/.claude*/projects/*/*.jsonl (tool_use blocks, name "Bash", input.command), feed each as
# {"tool_name":"Bash","tool_input":{"command":...},"cwd":...} to this hook and diff the rc against the
# previous version. 2026-10-14 (the round-3 version, 28b75d1): 5,101 commands, 100 refused, 0 mis-parses,
# p95 82 ms. 2026-10-14 round 4 (this version vs 7ab93e2/d156b13, same corpus): 94 refused by both, 0 verdict
# changes, 0 tracebacks, 0 timeouts, p95 93 ms per call (bash + python start included). The first round-4
# replay refused 2 legitimate pushes from a tmpfs repo into a tmpfs bare repo (tmpfs -> tmpfs; fixed, r4-G31).
#
# REVIEW MUTANTS (the 24 mutants of the 2026-10-14 round-3 independent review, run in-process over the
# tracked fixtures, a catalogue refusal without a hint counted as a different verdict): before round 4
# 7 caught / 17 survived; after round 4 24 caught / 0 survived. The proof's own P13 (34 line-removal mutants,
# each required to COMPILE: a crashing mutant proves nothing) and P15 (41 replacement mutants) count a mutant
# as caught only when a named case's VERDICT flips.
#
# NOT SEEN, by construction (both rules; the upstream guard shares them): a script FILE run by name
# (`bash x.sh`, `./x.sh`), an alias or shell function, `source`/`.` of a file, code inside an interpreter
# (`python3 -c "shutil.copytree(...)"`, perl, node, make recipes), text built at run time (base64, printf
# into eval, variables assigned by `read` or in an earlier Bash call), a destination reached through a
# symlink (`ln -s /tmp/x lnk && cp -a src lnk/`), a here-document fed to a non-shell interpreter
# (`python3 - <<EOF`), a command substitution other than mktemp used as a path (treated as unknown, i.e.
# disk), positional/special parameters ($1, $@), process substitution, and writes by tools not listed
# above (e.g. `go mod download` into GOMODCACHE=/tmp/x, `npm ci --cache /tmp/x`). Known limits of the
# catalogue half (2026-10-14 round 4, documented, not covered): a git ALIAS (`git ci -n`: an unknown
# subcommand gets a long-option scan only), config-level hook or safety bypasses (`git -c core.hooksPath=...`,
# GIT_CONFIG_* variables, `git -c clean.requireForce=false clean -d`), an rm root reached through a variable
# assigned elsewhere or a command substitution, `dd`/`curl`/`wget` writing onto tmpfs through a shape not
# named above (e.g. `| tee /tmp/x.gguf`), and a here-string fed to a non-shell interpreter. Use a disk TMPDIR
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
PIPES = {"|"}
PIPES.add("|&")  # MUTANT:pipe-amp
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
                pending.append((w["t"], st["delim"], w["q"])); st["delim"] = None
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
                    k = find_close(s, j + 3, "(", ")"); st["subs"].extend(body_subs(s[j + 3:k])); out.append(s[j:k + 2]); j = k + 2; continue
                if s.startswith("$(", j):
                    k = find_close(s, j + 2, "(", ")"); st["subs"].append(s[j + 2:k]); out.append(s[j:k + 1]); j = k + 1; continue
                if s[j] == "`":
                    k = s.find("`", j + 1); k = n if k < 0 else k
                    st["subs"].append(s[j + 1:k]); out.append(s[j:k + 1]); j = k + 1; continue
                out.append(s[j]); j += 1
            put("".join(out), True); i = j + 1; continue
        if s.startswith("$((", i):          # arithmetic is data, but a $(...) inside it RUNS: judged
            k = find_close(s, i + 3, "(", ")")
            st["subs"].extend(body_subs(s[i + 3:k]))  # MUTANT:arith-subs
            put(s[i:k + 2]); i = k + 2; continue
        # an arithmetic command `(( ... ))` is data (its << is a shift); a $(...) inside it runs and is judged
        if s.startswith("((", i) and not st["in"]: k = find_close(s, i + 2, "(", ")"); st["subs"].extend(body_subs(s[i + 2:k])); put(s[i:k + 2], True); i = k + 2; continue  # MUTANT:arith-cmd
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
                for delim, strip, dq in pending:
                    body = []
                    while i < n:
                        j = s.find("\n", i)
                        line = s[i:] if j < 0 else s[i:j]
                        i = n if j < 0 else j + 1
                        if (line.lstrip("\t") if strip else line) == delim:
                            break
                        body.append(line)
                    toks.append(("H", ("\n".join(body), dq)))
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
    """[("cmd", words, redirs, heredocs[(body, delim_quoted)], piped_from_previous) | ("open",) | ("close",)]"""
    out, cur = [], {"w": [], "r": [], "h": [], "p": False}

    def emit(piped_next=False):
        if cur["w"] or cur["r"] or cur["h"]:
            out.append(("cmd", cur["w"], cur["r"], cur["h"], cur["p"]))
        cur.update(w=[], r=[], h=[], p=piped_next)
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
            emit(v in PIPES)                 # `cmd |& bash` pipes like `|`
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
    if name == "TMPDIR":              # an `export TMPDIR=...` / `TMPDIR=...` earlier on the line wins
        v = os.environ.get("TMPDIR")
        v = ctx["vars"].get("TMPDIR", v)  # MUTANT:tmpdir-vars
        return v if v is UNKNOWN or v else "/tmp"   # unset/empty TMPDIR: mktemp & co. fall back to /tmp
    if name in ctx["vars"]:
        return ctx["vars"][name]
    return os.environ.get(name)       # each Bash call is a fresh shell: unset means empty

def mktemp_path(inner, ctx):
    items = [x for x in commands(lex(inner)) if x[0] == "cmd"]
    if len(items) != 1:
        return None
    a = [w["t"] for w in items[0][1]]
    sctx = sub_ctx(ctx)
    while a and ASSIGN.match(a[0]):         # `TMPDIR=/x mktemp -d`
        m = ASSIGN.match(a[0]); e = expand(m.group(3), ctx); sctx["vars"][m.group(1)] = UNKNOWN if e is None else e; a = a[1:]
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
        d = lookup("TMPDIR", sctx)
        if d is UNKNOWN:
            return None
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
RESERVED = {"!", "{", "}", "if", "then", "elif", "else", "do", "while", "until", "fi", "done", "esac", "in", "coproc"}
HEADERS = {"for", "case", "select"}
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
    while a and not a[0]["q"]:
        named = (a[0]["t"] == "coproc" and len(a) > 2 and a[2]["t"] == "{" and not a[2]["q"]
                 and re.match(r"^[A-Za-z_][A-Za-z0-9_]*$", a[1]["t"]))
        if named: a = a[2:]; continue  # MUTANT:coproc-name
        if a[0]["t"] not in RESERVED:
            break
        a = a[1:]
    return a

def unwrap(words):
    """-> dict(env, assigns, argv, stages, nested, nested_argv, chdir, lookup)"""
    r = {"env": {}, "assigns": [], "argv": [], "stages": [], "nested": [], "nested_argv": [], "chdir": None,
         "lookup": False, "header": False}
    a = list(words)
    a = strip_reserved(a)  # MUTANT:reserved
    if a and a[0]["t"] == "function" and not a[0]["q"]:   # `function f { body; }`: judge the body
        a = a[2:]  # MUTANT:function-body
        if a and a[0]["t"] == "()":
            a = a[1:]
        a = strip_reserved(a)  # MUTANT:function-restrip
    if a and a[0]["t"] in HEADERS and not a[0]["q"]:
        r["header"] = True
        if a[0]["t"] in ("for", "select") and len(a) >= 3 and a[2]["t"] == "in":
            r["loop"] = (a[1]["t"], [w["t"] for w in a[3:]])
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
    return git_globals_t([w["t"] for w in argv])

def git_globals_t(a):
    """git_globals on argv TEXTS."""
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
def long_is(w, full, minlen):
    """`w` spells the long option `full`: git and getopt_long accept a unique prefix (`--forc`, `--del`, `--rec`);
    `minlen` is the shortest prefix that cannot be another option of the commands concerned."""
    n = w.split("=", 1)[0]
    return n.startswith("--") and len(n) >= minlen and full.startswith(n)

def readonly_git(a):
    """git stash list|show, and a git restore that touches ONLY the index (-S/--staged without -W/--worktree),
    decided from the short-option clusters and the long-option prefixes before `--`."""
    if len(a) < 2 or a[0] != "git":
        return False
    if a[1] == "stash":
        return len(a) > 2 and a[2] in ("list", "show")
    if a[1] != "restore":
        return False
    staged = worktree = False
    i, r = 0, a[2:]
    while i < len(r):
        w = r[i]
        if w == "--":
            break
        if w.startswith("--"):
            staged |= long_is(w, "--staged", 4)
            worktree |= long_is(w, "--worktree", 3)
            if "=" not in w and (long_is(w, "--source", 4) or long_is(w, "--pathspec-from-file", 4)):
                i += 1                         # its value is the next word
        elif w.startswith("-") and len(w) > 1:
            for k, ch in enumerate(w[1:], 1):
                if ch == "s":                  # -s <tree>: the rest of the cluster, or the next word, is the value
                    if k == len(w) - 1:
                        i += 1
                    break
                staged |= ch == "S"
                worktree |= ch == "W"
        i += 1
    return staged and not worktree  # MUTANT-ANCHOR:readonly-worktree

# Hook-bypass / force flag classes (--no-verify, --force-with-lease) are git OPTIONS, judged on the options a git command
# really passes. Per subcommand: (short letters taking a value, short letters taking an optional ATTACHED value, long
# options taking a separate value, short letters that ARE a class flag). Subcommands that accept none of the class flags
# are skipped (their arguments are patterns, messages, refs: `git grep -- --no-verify`, `git log -G --no-verify`); an
# unknown subcommand (an alias) gets a scan of its long options only.
GIT_FLAG_SPEC = {
    "commit": ("mFcCt", "uS", {"--message", "--file", "--author", "--date", "--template", "--reuse-message",
                                "--reedit-message", "--fixup", "--squash", "--cleanup", "--trailer", "--pathspec-from-file"},
               {"n": "--no-verify"}),
    "merge": ("mFsX", "S", {"--message", "--file", "--strategy", "--strategy-option", "--into-name", "--cleanup"}, {}),
    "pull": ("sXoj", "S", {"--strategy", "--strategy-option", "--depth", "--deepen", "--shallow-since",
                           "--shallow-exclude", "--upload-pack", "--negotiation-tip", "--server-option", "--jobs"}, {}),
    "push": ("o", "", {"--repo", "--receive-pack", "--exec", "--push-option"}, {}),
    "rebase": ("sXx", "S", {"--onto", "--strategy", "--strategy-option", "--exec"}, {}),
    "am": ("", "pCS", {"--patch-format", "--directory", "--exclude", "--include"}, {}),
}
GIT_FLAG_NEVER = {"grep", "log", "show", "notes", "stash", "diff", "shortlog", "whatchanged", "reflog", "blame", "annotate",
                  "format-patch", "describe", "rev-list", "rev-parse", "for-each-ref", "ls-files", "ls-tree", "ls-remote",
                  "cat-file", "config", "help", "status", "branch", "tag", "add", "rm", "mv", "restore", "checkout",
                  "switch", "reset", "clean", "fetch", "clone", "remote", "submodule", "worktree", "bisect", "apply",
                  "archive", "bundle", "show-ref", "var", "check-ignore", "range-diff", "cherry", "name-rev", "fsck",
                  "gc", "init", "sparse-checkout", "maintenance", "hash-object", "symbolic-ref", "update-ref", "merge-base"}
CLASS_LONG = {"--no-verify": 6, "--force-with-lease": 9}   # the shortest prefix git still resolves to the class flag

def git_flags(a):
    """The long options a git argv (globals stripped) passes: unique prefixes of the class flags expanded, option
    VALUES skipped (`-m "--no-verify is..."`), short flags that are a class flag mapped (`commit -n`, `-nm msg`)."""
    if len(a) < 2 or a[0] != "git" or a[1] in GIT_FLAG_NEVER:
        return set()
    spec = GIT_FLAG_SPEC.get(a[1])
    vals_s, opt_s, vals_l, smap = spec if spec else ("", "", set(), {})
    out, i, r = set(), 0, a[2:]
    while i < len(r):
        w = r[i]
        if w == "--":
            break
        if w.startswith("--"):
            n = w.split("=", 1)[0]
            out.add(n)
            out.update(full for full, k in CLASS_LONG.items() if long_is(n, full, k))  # MUTANT:flag-prefix
            if "=" not in w and any(len(n) >= 4 and v.startswith(n) for v in vals_l): i += 1  # MUTANT:flag-values
        elif w.startswith("-") and len(w) > 1 and spec:
            for k, ch in enumerate(w[1:], 1):
                if ch in smap:
                    out.add(smap[ch])
                if ch in vals_s:               # the rest of the cluster, or the next word, is the value
                    if k == len(w) - 1:
                        i += 1
                    break
                if ch in opt_s:                # optional attached value: the rest of the cluster
                    break
        i += 1
    return out

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

def catalogue_hit(stage_texts, rules, cwd=None):
    """stage_texts: list of argv(text) lists for every unwrap stage."""
    for a in stage_texts:
        if not a:
            continue
        a = [bn(a[0])] + a[1:]  # MUTANT:basename
        t = " ".join(re.sub(r"\s", " ", x) for x in a)
        ga = git_globals_t(a)[0] if a[0] == "git" else a
        if readonly_git(ga):
            continue
        for id_, rx in rules:
            if rx.pattern.startswith("-"):
                # a flag class (--no-verify, --force-with-lease) is a git OPTION: never judged on grep/rg/printf,
                # nor on a git subcommand's values or patterns
                if a[0] == "git" and any(rx.match(x) for x in git_flags(ga)): return id_  # MUTANT:flag-git-only
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
        x = extra_hit(a, cwd)
        if x:
            return x
    return None

def short_flags(args):
    """Letters of every short-option cluster (-fd -> fd), ignoring words after `--`."""
    out = ""
    for w in args:
        if w == "--":
            break
        if re.match(r"^-[A-Za-z]+$", w):
            out += w[1:]
    return out

def rm_root(w, cwd):
    """`w` names / , /home, $HOME or an ancestor of it (or a glob of one) in any spelling: ~ $HOME ${HOME} ${HOME:?},
    a literal home path, //, /., ~/., ~/.. (normalised before comparing). A sub-path of them is not a root."""
    h = os.environ.get("HOME") or "/nonexistent-home"
    t = re.sub(r"^(\$\{HOME(:?[-?=+][^}]*)?\}|\$HOME(?![A-Za-z0-9_]))", lambda m: h, w)
    if t == "~" or t.startswith("~/"):
        t = h + t[1:]
    for g in ("/*", "/.*"):
        if t.endswith(g):
            t = t[:-len(g)] or "/"; break
    if t in ("*", ".*"):
        t = "."
    if not t.startswith("/"):
        if not cwd or "$" in t or t.startswith("~"):
            return False
        t = cwd + "/" + t
    n = os.path.normpath("/" + t.lstrip("/"))  # MUTANT-ANCHOR:rm-normpath
    roots, d = {"/", "/home"}, os.path.normpath(h)
    while d not in ("/", ""):
        roots.add(d); d = os.path.dirname(d)
    return n in roots

def whole_tree(w):
    """A pathspec naming the whole work tree in any spelling: . ./ * ** :/ :/. :(top) :(top,glob)* ..."""
    rest = w
    if w.startswith(":/"):
        rest = w[2:]
    elif w.startswith(":("):
        k = w.find(")")
        if k < 0 or "exclude" in w[2:k] or "attr" in w[2:k]:
            return False
        rest = w[k + 1:]
    elif w.startswith(":"):
        return False                     # :!x / :^x (exclude) and other short magic: not the whole tree
    return os.path.normpath(rest or ".") in (".", "*", "**")  # MUTANT-ANCHOR:whole-tree

def operands(args, vals=()):
    """Non-option words (values of the options in `vals` skipped), and every word after `--`."""
    out, i = [], 0
    while i < len(args):
        w = args[i]
        if w == "--":
            return out + args[i + 1:]
        if w in vals:
            i += 2; continue
        if not (w.startswith("-") and w != "-"):
            out.append(w)
        i += 1
    return out

def longs(args):
    """Long options before `--`."""
    return [w for w in (args[:args.index("--")] if "--" in args else args) if w.startswith("--")]

def extra_hit(a, cwd=None):
    """Project-catalogue rows the shared tsv's literal regexes miss (2026-10-14 re-reviews). A long option is matched
    by its unique prefix (git and getopt_long accept `--forc`, `--del`, `--rec`)."""
    if not a:
        return None
    if a[0] == "rm":
        fl, lo = short_flags(a[1:]), longs(a[1:])
        rec = "r" in fl or "R" in fl or any(long_is(w, "--recursive", 3) for w in lo)
        if rec and any(rm_root(w, cwd) for w in operands(a[1:])): return "rm-recursive-root"  # MUTANT:extra-rm-root
    if a[0] != "git" or len(a) < 2:
        return None
    sub, rest = a[1], a[2:]
    fl, lo = short_flags(rest), longs(rest)
    if sub == "clean" and ("f" in fl or any(long_is(w, "--force", 3) for w in lo)): return "clean-force-any-spelling"  # MUTANT:extra-clean
    if sub == "checkout" and any(whole_tree(w) for w in operands(rest, ("-b", "-B", "--orphan"))): return "checkout-tree-discard"  # MUTANT:extra-checkout
    if sub == "add" and ("A" in fl or any(long_is(w, "--all", 3) for w in lo) or any(whole_tree(w) for w in operands(rest))): return "add-all-any-spelling"  # MUTANT:extra-add-all
    dele = "d" in fl or any(long_is(w, "--delete", 3) for w in lo)
    force = "f" in fl or any(long_is(w, "--force", 6) for w in lo)
    if sub == "branch" and ("D" in fl or (dele and force)): return "branch-force-delete"  # MUTANT:extra-branch
    return None

HINTS = {
    "add-all": "stage named paths only: git add -- <path> <path>",
    "add-dot": "stage named paths only: git add -- <path> <path>",
    "add-all-any-spelling": "stage named paths only: git add -- <path> <path>",
    "force-push": "never force: git fetch, merge onto the latest main, then a plain git push",
    "force-with-lease": "never force: git fetch, merge onto the latest main, then a plain git push",
    "force-push-any-spelling": "never force: git fetch, merge onto the latest main, then a plain git push",
    "no-verify": "let the hooks run and fix what they report; there is no bypass",
    "reset-hard": "keep the work: commit it, or save `git diff > \"$S\"/wip.patch` on disk; ask the operator before discarding",
    "checkout-discard": "to discard ONE file's edits ask the operator; to inspect use git diff / git show HEAD:<path>",
    "checkout-dot": "to discard ONE file's edits ask the operator; to inspect use git diff / git show HEAD:<path>",
    "checkout-tree-discard": "to discard ONE file's edits ask the operator; to inspect use git diff / git show HEAD:<path>",
    "restore-discard": "unstage with git restore --staged <path>; discarding working-tree edits needs the operator",
    "stash-all": "commit to a branch instead, or save `git diff > \"$S\"/wip.patch` on disk; git stash list/show are allowed",
    "clean-force-dirs": "list first with git clean -n; remove named untracked paths with rm -- <path>",
    "clean-ignored": "list first with git clean -n; remove named untracked paths with rm -- <path>",
    "clean-force-any-spelling": "list first with git clean -n; remove named untracked paths with rm -- <path>",
    "branch-delete": "deleting branches is an operator decision; git branch -d (merged only) is the safe form",
    "branch-force-delete": "deleting branches is an operator decision; git branch -d (merged only) is the safe form",
    "rm-recursive-root": "remove a NAMED path inside your scratch dir: rm -rf -- \"$S\"/<name>",
    "remove-root": "remove a NAMED path inside your scratch dir: rm -rf -- \"$S\"/<name>",
    "remove-home": "remove a NAMED path inside your scratch dir: rm -rf -- \"$S\"/<name>",
    "signal-by-pattern": "signal one validated pid you started: kill <pid> (never by name or pattern)",
    "signal-by-name": "signal one validated pid you started: kill <pid> (never by name or pattern)",
    "privilege-escalation": "no sudo: report the step that needs root to the operator",
}
def hint(id_):
    return HINTS.get(id_, "this is an operator decision: report the exact command and why it is needed")

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
    outs = opt_values(c.a[2:], ("-o",), ("--output",), attach=("-o",))
    if outs:
        return c.p(outs[-1]) if c.tm(outs[-1]) else None
    return c.out_tmpfs()

GIT_IMPORT = {"fetch", "pull", "submodule", "lfs"}           # bring objects in from elsewhere
GIT_TREEWRITE = {"checkout", "restore", "switch", "reset", "read-tree", "merge", "rebase", "cherry-pick", "stash",
                 "sparse-checkout"}                           # write work-tree files from the repo's own objects

def r_git_tmpfs_repo(c, x):
    """Disk data entering tmpfs through git: objects FETCHED into a repo on tmpfs, or a disk repo's files checked
    out into a work tree on tmpfs. A checkout inside a repo that already lives on tmpfs moves nothing new
    into RAM (tmpfs -> tmpfs) and is allowed."""
    a = c.a
    if len(a) < 2 or a[0] != "git":
        return None
    wt = c.p(x["git_wt"]) if x.get("git_wt") else None
    gd = c.p(x["git_dir"]) if x.get("git_dir") else None
    cw = c.ctx["cwd"]
    src_on_tmpfs = is_tmpfs(gd) if gd else is_tmpfs(cw)
    if a[1] == "push" and not src_on_tmpfs:  # pushing a DISK repo's objects INTO a repository on tmpfs (tmpfs -> tmpfs is allowed)
        for r in opt_values(a[2:], (), ("--repo",)) + positionals(a[2:], {"-o", "--push-option", "--receive-pack", "--exec", "--repo"})[:1]:
            r = r[7:] if r.startswith("file://") else r
            if ("/" in r or r.startswith((".", "~"))) and not REMOTE.match(r) and c.tm(r):
                return c.p(r)
    imports = a[1] in GIT_IMPORT or (a[1] == "remote" and len(a) > 2 and (
        a[2] == "update" or (a[2] == "add" and any(w in ("-f", "--fetch") for w in a[3:]))))
    if imports:
        for d in (gd, wt, cw if not gd else None):
            if is_tmpfs(d):
                return d
    if a[1] in GIT_TREEWRITE and is_tmpfs(wt):
        repo_on_tmpfs = is_tmpfs(gd) if gd else is_tmpfs(cw)
        if not repo_on_tmpfs:
            return wt
    return None

LARGE_BYTES = 64 * 1024 * 1024
BULK_SUFFIX = re.compile(r"\.(gguf|bin|safetensors|onnx|pt|pth|ckpt|tar|tgz|tbz2|txz|tzst|gz|xz|zst|bz2|zip|7z|iso|img|qcow2|vmdk|deb|rpm|whl|jar)$", re.I)

def big_or_dir(c, s):
    """A source that is a directory, ends in '/', or a regular file over LARGE_BYTES. Unknown -> False."""
    if s.endswith("/") or s in (".", ".."):
        return True
    p = c.p(s)
    try:
        return bool(p) and (os.path.isdir(p) or (os.path.isfile(p) and os.path.getsize(p) > LARGE_BYTES))
    except OSError:
        return False

def r_cp(c, x):
    a = c.a
    if not a or a[0] != "cp":
        return None
    args = a[1:]
    if cluster_has(args, "ls") or any(w in ("--link", "--symbolic-link") for w in args):
        return None                      # hard/symbolic links copy no data (and cannot cross into tmpfs)
    rec = cluster_has(args, "arR") or any(w in ("--recursive", "--archive") for w in args)
    tdir = opt_values(args, ("-t",), ("--target-directory",))
    pos = positionals(args, {"-S", "--suffix", "-t", "--target-directory"})
    srcs, dest = (pos, tdir[-1]) if tdir else ((pos[:-1], pos[-1]) if len(pos) >= 2 else (None, None))
    if dest is None:
        return None
    if not rec and not any(big_or_dir(c, s) for s in srcs): return None  # MUTANT:cp-single-file
    return copy_like(c, srcs, dest)

def r_mv(c, x):
    """mv from disk into tmpfs is a cross-device FULL copy: refused for a directory or a file over 64 MiB
    (checked on this host); a small named file or an unknown source is allowed."""
    a = c.a
    if not a or a[0] != "mv":
        return None
    args = a[1:]
    tdir = opt_values(args, ("-t",), ("--target-directory",))  # mv -t DIR
    pos = positionals(args, {"-S", "--suffix", "-t", "--target-directory"})
    srcs, dest = (pos, tdir[-1]) if tdir else ((pos[:-1], pos[-1]) if len(pos) >= 2 else (None, None))
    if dest is None or not any(big_or_dir(c, s) for s in srcs): return None  # MUTANT:mv-single-file
    return copy_like(c, srcs, dest)

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

def cluster_vals(args, letter):
    """Values of a value-taking short option in any cluster spelling: -o F, -sSLo F, -oF, -qO-."""
    vals = []
    for i, w in enumerate(args):
        if w == "--":
            break
        if re.match(r"^-[A-Za-z]", w) and not w.startswith("--"):
            k = w.find(letter, 1)
            if k < 0 or not re.match(r"^[A-Za-z]*$", w[1:k]):
                continue
            if k == len(w) - 1:
                if i + 1 < len(args):
                    vals.append(args[i + 1])
            else:
                vals.append(w[k + 1:])
    return vals

def url_name(args):
    urls = [w for w in args if re.match(r"^[a-z][a-z0-9+.-]*://", w)]
    return os.path.basename(urls[-1].split("?")[0].split("#")[0].rstrip("/")) if urls else ""

def r_download(c, x):
    """A download's size cannot be known statically. Refused only when it lands on tmpfs AND its file name
    says bulk (a model or an archive: BULK_SUFFIX); a small page/JSON fetch into /tmp is allowed."""
    a = c.a
    if not a or a[0] not in ("curl", "wget"):
        return None
    args = a[1:]
    def bulk(path, name):
        hit = is_tmpfs(path)
        hit = hit and BULK_SUFFIX.search(name or "")  # MUTANT:download-suffix
        return path if hit else None
    def bulk_stdout():                        # to stdout, redirected onto tmpfs: the redirect's or the URL's name decides
        o = c.out_tmpfs()
        return bulk(o, o) or bulk(o, url_name(args)) if o else None
    if a[0] == "curl":
        outs = cluster_vals(args, "o") + opt_values(args, (), ("--output",))
        for o in outs:
            if o != "-":
                r = bulk(c.p(o), o)
                if r:
                    return r
        if (any(re.match(r"^-[A-Za-z]*O[A-Za-z]*$", w) for w in args)
                or any(w in ("--remote-name", "--remote-name-all") for w in args)):
            dirs = opt_values(args, (), ("--output-dir",))
            d = c.p(dirs[-1]) if dirs else c.ctx["cwd"]
            return bulk(d, url_name(args))
        return bulk_stdout() if (not outs or "-" in outs) else None
    outs = cluster_vals(args, "O") + opt_values(args, (), ("--output-document",))
    if outs:
        return bulk_stdout() if outs[-1] == "-" else bulk(c.p(outs[-1]), outs[-1])
    dirs = cluster_vals(args, "P") + opt_values(args, (), ("--directory-prefix",))
    d = c.p(dirs[-1]) if dirs else c.ctx["cwd"]
    return bulk(d, url_name(args))

DD_MULT = {"": 1, "c": 1, "w": 2, "b": 512, "kB": 1000, "K": 1024, "k": 1024, "KiB": 1024, "MB": 1000 ** 2,
           "M": 1024 ** 2, "MiB": 1024 ** 2, "GB": 1000 ** 3, "G": 1024 ** 3, "GiB": 1024 ** 3, "T": 1024 ** 4}

def dd_num(v):
    m = re.match(r"^([0-9]+)([A-Za-z]*)$", v or "")
    return int(m.group(1)) * DD_MULT[m.group(2)] if m and m.group(2) in DD_MULT else None

def r_dd(c, x):
    """dd onto tmpfs (of= or a stdout redirect): refused when unbounded (no count=) or when count x input block size
    (bs=, else ibs=) exceeds 64 MiB."""
    if not c.a or c.a[0] != "dd":
        return None
    kv = dict(w.split("=", 1) for w in c.a[1:] if "=" in w)
    of = kv.get("of")
    if of:
        if not c.tm(of):
            return None
        dest = c.p(of)
    else:
        dest = c.out_tmpfs()                         # no of=: dd writes to stdout, here redirected onto tmpfs
        if not dest:
            return None
    bs = dd_num(kv.get("bs") or kv.get("ibs") or "512")   # count= counts INPUT blocks (ibs), never obs
    cnt = kv.get("count")
    if cnt is None or bs is None or dd_num(cnt) is None:
        return dest                                  # unbounded / unparseable size: bulk
    nbytes = dd_num(cnt) if "count_bytes" in kv.get("iflag", "") else dd_num(cnt) * bs
    return dest if nbytes > LARGE_BYTES else None  # MUTANT:dd-size

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

def env_ctx(ctx, u):
    """The context of a script a command runs (bash -c, eval, env -S, a here-document): the command's VAR=value
    prefixes are in that script's environment (`TMPDIR=/tmp bash -c '... $(mktemp -d)'`)."""
    sctx = sub_ctx(ctx)
    for k, v in u["env"].items():
        e = expand(v, ctx)
        sctx["vars"][k] = UNKNOWN if e is None else e  # MUTANT:shell-env
    return sctx

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

def body_subs(body):
    """$(...) and `...` in an UNQUOTED here-document body: the shell runs them while expanding it."""
    out, i, n = [], 0, len(body)
    while i < n:
        c = body[i]
        if c == "\\":
            i += 2; continue
        if body.startswith("$((", i):
            i = find_close(body, i + 3, "(", ")") + 2; continue
        if body.startswith("$(", i):
            k = find_close(body, i + 2, "(", ")"); out.append(body[i + 2:k]); i = k + 1; continue
        if c == "`":
            k = body.find("`", i + 1); k = n if k < 0 else k; out.append(body[i + 1:k]); i = k + 1; continue
        i += 1
    return out

def judge_cmd(it, rules, ctx, depth):
    words, redirs, hds = it[1], it[2], it[3]
    piped = it[4] if len(it) > 4 else False
    last_echo, ctx["last_echo"] = ctx.get("last_echo"), None
    subs = [sub for w in words + [t for _, t in redirs if t] for sub in w["subs"]]
    subs += [sub for body, dq in hds if not dq for sub in body_subs(body)]  # MUTANT:heredoc-subs
    for sub in subs:
        v = judge_script(sub, rules, sub_ctx(ctx), depth + 1)
        if v:
            return v
    u = unwrap(words)
    if u.get("loop"):   # `for d in /tmp/x; do ... "$d"`: the variable takes the listed literal values
        name_, vals = u["loop"]
        ev = [expand(v, ctx) for v in vals]
        ctx["vars"][name_] = UNKNOWN
        if not any(e is None for e in ev): ctx["vars"][name_] = next((e for e in ev if is_tmpfs(resolve(e, ctx))), ev[0] if ev else "")  # MUTANT:loop-var
    if u["header"] or u["lookup"]:
        return None
    stages = [[x["t"] for x in s] for s in u["stages"]]
    argv, chdirs, gwt, gdir = git_globals(u["argv"])
    stages.append(argv)
    hit = catalogue_hit(stages, rules, ctx["cwd"])
    if hit:
        return ("cat", hit)
    for na in u["nested_argv"]:
        v = judge_cmd(("cmd", na, [], [], False), rules, sub_ctx(ctx), depth + 1)
        if v:
            return v
    for script in u["nested"]:
        v = judge_script(script, rules, env_ctx(ctx, u), depth + 1)
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
    if name in ("echo", "printf"):        # remembered for `echo 'cmd' | bash`
        ctx["last_echo"] = " ".join(t for t in a[1:] if not re.match(r"^-[neE]+$", t)).replace("\\n", "\n")
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
        args, script, files, i, sflag = a[1:], None, [], 0, False
        STDIN = ("-", "/dev/stdin", "/dev/fd/0", "/proc/self/fd/0")
        while i < len(args):
            w = args[i]
            if w == "--":                     # options end; with -s every later word is a positional, not a file
                files = [] if sflag else args[i + 1:i + 2]; break
            if w in ("-o", "+o", "-O", "+O", "--rcfile", "--init-file") and i + 1 < len(args):
                i += 2; continue
            if w.startswith("-") and not w.startswith("--") and "c" in w[1:] and script is None:
                j = i + 1
                while j < len(args) and args[j].startswith("-"):
                    j += 1
                script = args[j] if j < len(args) else ""; break
            if w.startswith("-") or w.startswith("+"):
                sflag = sflag or (w.startswith("-") and not w.startswith("--") and "s" in w[1:])
                i += 1; continue
            if not sflag: files.append(w)
            break                             # the script file (or, with -s, a positional); the rest are ITS arguments
        sctx = env_ctx(ctx, u)                # `TMPDIR=/tmp bash -c '...'`: the prefix is the nested script's environment
        if script is not None:
            return judge_script(script, rules, sctx, depth + 1)
        files = [f for f in files if f not in STDIN]   # `bash /dev/stdin <<EOF` reads the here-document too
        if files:
            return None
        # `bash <<EOF` / `bash -s`: the here-document IS the script; so is a here-string (`bash <<< 'cmd'`); and
        # `echo '...' | bash`: the piped text
        hstr = [t["t"] for op, t in redirs if op == "<<<" and t]
        v = None
        v = next((r for r in (judge_script(b, rules, sub_ctx(sctx), depth + 1) for b, _dq in hds) if r), None)  # MUTANT:heredoc-shell
        if v is None: v = next((r for r in (judge_script(b, rules, sub_ctx(sctx), depth + 1) for b in hstr) if r), None)  # MUTANT:herestring-shell
        if v is None and piped and last_echo: v = judge_script(last_echo, rules, sub_ctx(sctx), depth + 1)  # MUTANT:pipe-to-shell
        return v
    cctx = ctx
    if chdirs or u["chdir"]:
        cctx = sub_ctx(ctx)
        for d in ([u["chdir"]] if u["chdir"] else []) + chdirs:
            cctx["cwd"] = resolve(d, cctx)
    out = [resolve(t["t"], cctx) for op, t in redirs if op in OUT_REDIRS and t and not t["t"].isdigit() and t["t"] != "-"]
    c = C(a, cctx, out)
    x = {"git_wt": gwt or u["env"].get("GIT_WORK_TREE"), "git_dir": gdir or u["env"].get("GIT_DIR")}
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
            "BLOCKED by guard-project-catalogue (VSC-367): the command matches the refused class '%s' "
            "(docs/zero-gap/guarded-commands.tsv or the project's structural rules). Instead: %s.\n" % (hit[1], hint(hit[1])))
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
    # the proof's fixtures need a DISK temp dir (@T@ is a disk source in several rows; /tmp is RAM): TMPDIR when it is on
    # disk, else the agent scratch root
    local troot="${TMPDIR:-}"
    case "$troot" in ''|/tmp|/tmp/*|/dev/shm|/dev/shm/*|/run/user/*|/var/run/user/*) troot="${AGENT_SCRATCH_ROOT:-$HOME/.cache/agent-scratch}" ;; esac
    mkdir -p "$troot" 2>/dev/null; chmod 700 "$troot" 2>/dev/null
    T=$(mktemp -d "$troot/zg-pcg.XXXXXX") || { echo "COULD-NOT-PROVE: no temp dir"; return 2; }
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
    # Fixtures carry no host paths: @REPO@ = this checkout, @HOME@ = $HOME, @T@ = this proof's temp dir (it
    # holds small.txt and a SPARSE 65 MiB file, so the size rule is exercised without writing 65 MiB).
    printf 'x\n' >"$T/small.txt"; mkdir "$T/adir"; truncate -s 65M "$T/sparse65m" 2>/dev/null || { echo "COULD-NOT-PROVE: truncate failed"; return 2; }
    probe_cwd() { # $1 command  $2 cwd ('-' = none)  [$3 python program, default the hook's]
        local j; j=$(python3 -I -c 'import json,sys
sub=lambda x: x.replace("@REPO@",sys.argv[3]).replace("@HOME@",sys.argv[4]).replace("@T@",sys.argv[5])
d={"tool_name":"Bash","tool_input":{"command":sub(sys.argv[1])}}
if sys.argv[2]!="-": d["cwd"]=sub(sys.argv[2])
print(json.dumps(d))' "$1" "$2" "$ROOT_DEFAULT" "$HOME" "$T")
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
    # Case driver: runs the hook program ($1) over cases.jsonl rows; prints "<id> <expect> <rc> <branch>" per row. A
    # catalogue refusal (branch cat:*) must name what to do instead: rc 2 WITHOUT an "Instead: <words>" hint is printed
    # as rc 3, so every B-row check and every mutant check sees a hint-less refusal as a failure.
    printf '%s' "$PY" >"$T/hook.py"
    drive() { # $1 program file  $2 jsonl  [$3 comma-separated ids]  -> lines "id expect rc branch"
        env -u TMPDIR AGENT_TMPFS_OK_LOG="$T/override.log" python3 -I - "$1" "$CAT" "$ROOT_DEFAULT" "$2" "${3:-}" "$HOME" "$T" <<'PYDRV'
import json, os, re, subprocess, sys
prog, cat, root, cases, only, home, tmp = sys.argv[1:8]
sub = lambda x: x.replace("@REPO@", root).replace("@HOME@", home).replace("@T@", tmp)
want = set(only.split(",")) if only else None
for line in open(cases, encoding="utf-8"):
    r = json.loads(line)
    if want is not None and r["id"] not in want:
        continue
    d = {"tool_name": "Bash", "tool_input": {"command": sub(r["cmd"])}}
    if r.get("cwd", "-") != "-":
        d["cwd"] = sub(r["cwd"])
    env = dict(os.environ)
    if r.get("tmpdir"):                       # the hook's own TMPDIR for this row (unset otherwise)
        env["TMPDIR"] = sub(r["tmpdir"])
    p = subprocess.run([sys.executable, "-I", prog, "hook", cat, root], input=json.dumps(d), capture_output=True, text=True, env=env)
    rc = p.returncode
    if rc == 2 and r.get("branch", "-").startswith("cat:") and not re.search(r"Instead: [A-Za-z]", p.stderr):
        rc = 3
    print(r["id"], r["expect"], rc, r.get("branch", "-"))
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
    # A mutant is caught only when a named case's VERDICT flips: a B row allowed (rc 0) or refused without its
    # "Instead:" hint (rc 3), an A row refused (rc 2). A mutant that merely crashes the hook (rc 1) proves nothing.
    flips() { { [ "$1" = B ] && { [ "$2" -eq 0 ] || [ "$2" -eq 3 ]; }; } || { [ "$1" = A ] && [ "$2" -eq 2 ]; }; }
    # P13 lexer/normaliser mutations: each '# MUTANT:<name>' line removed must flip its named case(s)
    local -A MCASE=([continuation]=rev-F09,rev-L01 [reserved]=rev-F08,rev-F03 [basename]=rev-R06,own-B01,own-B02 [subshell-scope]=rev-G12,own-G01
                    [heredoc-shell]=rev-N24 [reason-words]=rev-OVR [normpath]=rev-N54,rev-N55 [find-exec]=rev-N36
                    [mktemp]=rev-N02,rev-N03 [assign-vars]=rev-N01
                    [arith-cmd]=rev2-B09 [tmpdir-vars]=rev2-B01,rev2-G08 [function-body]=rev2-B05 [flag-git-only]=rev-R07,rev-R17,own-B11
                    [heredoc-subs]=rev2-B08 [loop-var]=rev2-B02 [pipe-to-shell]=rev2-B07 [cp-single-file]=own-G12
                    [mv-single-file]=rev2-G04,own-G07 [download-suffix]=r4-G25,r4-G26 [dd-size]=rev-N08
                    [extra-rm-root]=rev2-B12,rev2-B19 [extra-clean]=rev2-B10 [extra-checkout]=rev2-B11 [extra-add-all]=rev2-B13
                    [extra-branch]=rev2-B18 [arith-subs]=r4-B52 [coproc-name]=r4-B50 [flag-prefix]=r4-B08,r4-B09
                    [flag-values]=r4-G30 [shell-env]=r4-B49 [herestring-shell]=r4-B11,r4-B12,r4-B13 [pipe-amp]=r4-B36
                    [function-restrip]=r4-B37)
    local mnames nm=0 mm=0 flipped
    mnames=$(grep -o '# MUTANT:[a-z-]*' <<<"$PY" | sed 's/# MUTANT://' | sort -u)
    for b in $mnames; do
        nm=$((nm+1)); grep -v "# MUTANT:$b\$" <<<"$PY" >"$T/mut.py"; flipped=0
        [ -n "${MCASE[$b]:-}" ] || { mm=$((mm+1)); echo "    mutant '$b' has no named case"; continue; }
        python3 -I -c 'import sys; compile(open(sys.argv[1]).read(), "mut", "exec")' "$T/mut.py" 2>/dev/null \
            || { mm=$((mm+1)); echo "    mutant '$b' does not compile: a hollow mutant (its marker must sit on a removable line)"; continue; }
        while read -r id ex rc0 br0; do flips "$ex" "$rc0" && flipped=$((flipped+1)); done < <(drive "$T/mut.py" "$FX/cases.jsonl" "${MCASE[$b]}")
        [ "$flipped" -gt 0 ] && echo "    mutant '$b' caught by ${MCASE[$b]}" || { mm=$((mm+1)); echo "    mutant '$b' NOT caught by ${MCASE[$b]}"; }
    done
    [ "$nm" -ge 8 ] && [ "$mm" -eq 0 ] && ok "P13 $nm lexer/normaliser mutants each caught by a named case" || bad "P13 $mm of $nm mutants undetected"
    # P15 REPLACEMENT mutants (the independent re-review's survivors + precise variants of new rules): each old->new
    #     edit of the hook program must flip its named case(s)
    local nr=0 mr=0 rname rold rnew rcases
    while IFS='|' read -r rname rold rnew rcases; do
        [ -n "$rname" ] || continue
        nr=$((nr+1))
        if ! python3 -I -c 'import sys
s=open(sys.argv[1]).read(); o,n=sys.argv[2],sys.argv[3]
sys.exit(3) if s.count(o)!=1 else open(sys.argv[4],"w").write(s.replace(o,n,1))' "$T/hook.py" "$rold" "$rnew" "$T/mut.py"; then
            mr=$((mr+1)); echo "    replacement mutant '$rname': anchor not found exactly once"; continue
        fi
        flipped=0
        while read -r id ex rc0 br0; do flips "$ex" "$rc0" && flipped=$((flipped+1)); done < <(drive "$T/mut.py" "$FX/cases.jsonl" "$rcases")
        [ "$flipped" -gt 0 ] && echo "    replacement mutant '$rname' caught by $rcases" || { mr=$((mr+1)); echo "    replacement mutant '$rname' NOT caught by $rcases"; }
    done <<'MUTS'
readonly-exemption|        if readonly_git(ga):|        if False:|own-G02,own-G03,own-G04,r4-G01,r4-G02
readonly-worktree|    return staged and not worktree  # MUTANT-ANCHOR:readonly-worktree|    return staged|r4-B01,r4-B02,r4-B03,r4-B04,r4-B05
env-C|                    r["chdir"] = rest[i + 1]["t"]|                    pass|own-B03
cd-minus|        if tgt == "-":|        if False:|own-G05
curl-O|        if (any(re.match(r"^-[A-Za-z]*O[A-Za-z]*$", w) for w in args)|        if False and (any(re.match(r"^-[A-Za-z]*O[A-Za-z]*$", w) for w in args)|own-B04
unzip-listmode|            return None                   # list / test / pipe / zipinfo / to-stdout modes write nothing|            pass|own-G06
export-vars|    if name in ("export", "declare", "typeset", "local", "readonly"):|    if False:|own-B05
flag-any-word|                if a[0] == "git" and any(rx.match(x) for x in git_flags(ga)): return id_  # MUTANT:flag-git-only|                if any(rx.match(x) for x in a[1:]): return id_|rev2-G01,rev2-G02,rev2-G03,own-G11,r4-G03,r4-G04,r4-G05
flag-short-map|{"n": "--no-verify"}|{}|r4-B06,r4-B07
flag-short-values|                if ch in vals_s:               # the rest of the cluster, or the next word, is the value|                if False:|r4-G05,r4-G06
flag-never|    if len(a) < 2 or a[0] != "git" or a[1] in GIT_FLAG_NEVER:|    if len(a) < 2 or a[0] != "git":|r4-G04,r4-G08
cp-link-exempt|    if cluster_has(args, "ls") or|    if False and|own-G08
cp-link-l-only|    if cluster_has(args, "ls") or|    if cluster_has(args, "l") or|r4-G22
stdin-script|        files = [f for f in files if f not in STDIN]|        files = files|rev2-B16
stdin-fd0|        STDIN = ("-", "/dev/stdin", "/dev/fd/0", "/proc/self/fd/0")|        STDIN = ("-", "/dev/stdin")|r4-B40
sflag-dashdash|                files = [] if sflag else args[i + 1:i + 2]; break|                files = args[i + 1:i + 2]; break|r4-B14
sflag-positional|            if not sflag: files.append(w)|            files.append(w)|r4-B53
shell-first-word|            break                             # the script file (or, with -s, a positional); the rest are ITS arguments|            i += 1; continue|r4-G10
git-dir-env|"git_dir": gdir or u["env"].get("GIT_DIR")|"git_dir": gdir|rev2-B15
dd-unbounded|        return dest                                  # unbounded / unparseable size: bulk|        return None|own-B09
dd-threshold|    return dest if nbytes > LARGE_BYTES else None  # MUTANT:dd-size|    return dest if nbytes > LARGE_BYTES * 16 else None|r4-B41
dd-ibs|kv.get("bs") or kv.get("ibs") or "512"|kv.get("bs") or kv.get("obs") or "512"|r4-B46
dd-count-bytes|    nbytes = dd_num(cnt) if "count_bytes" in kv.get("iflag", "") else dd_num(cnt) * bs|    nbytes = dd_num(cnt) * bs|r4-G23
dd-stdout|        dest = c.out_tmpfs()                         # no of=: dd writes to stdout, here redirected onto tmpfs|        dest = None|r4-B45
curl-stdout|        return bulk_stdout() if (not outs or "-" in outs) else None|        return None|r4-B44
git-push-tmpfs|    if a[1] == "push" and not src_on_tmpfs:  # pushing a DISK repo's objects INTO a repository on tmpfs (tmpfs -> tmpfs is allowed)|    if False:|r4-B47
git-push-src-tmpfs|    src_on_tmpfs = is_tmpfs(gd) if gd else is_tmpfs(cw)|    src_on_tmpfs = False|r4-G31
remote-update|        a[2] == "update" or|        False or|r4-B48
import-pull|GIT_IMPORT = {"fetch", "pull", "submodule", "lfs"}|GIT_IMPORT = {"fetch", "submodule", "lfs"}|r4-B43
treewrite-tmpfs-repo|        repo_on_tmpfs = is_tmpfs(gd) if gd else is_tmpfs(cw)|        repo_on_tmpfs = False|r4-G24
big-or-dir|(os.path.isdir(p) or (os.path.isfile(p)|(False or (os.path.isfile(p)|r4-B42
mv-target-dir|    tdir = opt_values(args, ("-t",), ("--target-directory",))  # mv -t DIR|    tdir = []  # mv -t DIR|r4-B39
loop-var-first|next((e for e in ev if is_tmpfs(resolve(e, ctx))), ev[0] if ev else "")|(ev[0] if ev else "")|r4-B38
heredoc-quoted|    subs += [sub for body, dq in hds if not dq for sub in body_subs(body)]|    subs += [sub for body, dq in hds for sub in body_subs(body)]|r4-G21
whole-tree|    return os.path.normpath(rest or ".") in (".", "*", "**")  # MUTANT-ANCHOR:whole-tree|    return rest in (".", "*")|r4-B17,r4-B18,r4-B34,r4-B35,r4-B54
rm-normpath|    n = os.path.normpath("/" + t.lstrip("/"))  # MUTANT-ANCHOR:rm-normpath|    n = t|r4-B25,r4-B26,r4-B27,r4-B28,r4-B29
rm-home-forms|lambda m: h, w)|lambda m: m.group(0), w)|r4-B30
rm-roots-slash-only|    roots, d = {"/", "/home"}, os.path.normpath(h)|    roots, d = {"/"}, "/"|r4-B25,r4-B31,r4-B33
long-prefix|    return n.startswith("--") and len(n) >= minlen and full.startswith(n)|    return n == full|r4-B19,r4-B20,r4-B22,r4-B24,r4-B33
clean-needs-d|    if sub == "clean" and ("f" in fl or|    if sub == "clean" and (("f" in fl and "d" in fl) or|r4-B21
branch-long-only|    dele = "d" in fl or any(|    dele = any(|r4-B23
hint-empty|    return HINTS.get(id_, "this is an operator decision: report the exact command and why it is needed")|    return ""|rev2-B10,rev2-B12,r4-B06,r4-B21
MUTS
    [ "$nr" -ge 8 ] && [ "$mr" -eq 0 ] && ok "P15 $nr replacement mutants each caught by a named case" || bad "P15 $mr of $nr replacement mutants undetected"
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
