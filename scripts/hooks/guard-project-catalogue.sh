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
# HOW A COMMAND LINE IS READ (rewritten 2026-10-14 after two independent reviews; round 5 the same day). One shell lexer
# serves every rule: backslash-newline continuation; '...', "...", $'...' quoting and backslash escapes (so
# `FOO='a b' cmd` and `FOO=a\ b cmd` are ONE assignment); BRACE EXPANSION of unquoted words ({git,reset,--hard},
# --{hard,}, ~{,}, {1..3}; never inside quotes, $(..), ${..}); comments; the operators ; ;; & && || | |& ( ) and newline;
# redirections (an fd number glued to them is dropped); `(( ... ))` and `$(( ... ))` arithmetic (data: its `<<` is a
# shift; a $(...) inside it runs and is judged); here-documents, each BOUND TO THE COMMAND THAT OWNS ITS `<<` even when
# the line goes on with | && ; or another here-document (`bash <<'E' | tail` judges the body as bash's script;
# `cat <<'A' > notes; bash <<'B'` keeps A as cat's data), and here-strings (data, EXCEPT a body fed to a shell — `bash
# <<EOF`, `bash <<< 'cmd'`, `bash -s`, `bash /dev/stdin|/dev/fd/0 <<EOF`, `cat <<EOF | bash`; with -s every word after it
# is a positional — is judged as a script, and the $(...) of an UNQUOTED-delimiter body is judged because the shell runs
# it while expanding); `echo|printf|cat ... | bash` and `|& bash` (the piped text is judged); $(...) and `...` (judged as
# commands). A VAR=value prefix of a command that runs a script (`TMPDIR=/tmp bash -c '...'`, eval, env -S) is in that
# script's environment. Each simple command is then normalised: leading reserved words (! { } if then elif else do while
# until coproc, and `coproc NAME {`), `function NAME` (its body is judged), `for`/`case`/`select` headers (a `for VAR in
# literal...` list sets VAR), VAR=value prefixes, wrappers (env command exec nohup builtin setsid nice ionice timeout
# stdbuf taskset chrt xargs flock sudo doas time watch, and bounded-run / agent-admit.sh / systemd-run, also when run as
# `bash <path>/agent-admit.sh`), absolute binary paths (/usr/bin/git -> git) and EVERY git global option (generic: any
# word starting with '-' before the subcommand; -C -c --git-dir --work-tree --namespace --config-env --attr-source
# --super-prefix take a value; git does not abbreviate them). Nested commands are judged recursively: `sh|bash|zsh
# -<cluster with c> '<script>'`, eval, env -S, `flock FILE -c '<cmd>'` and `flock [opts] FILE CMD...` (util-linux order),
# `script -c|-qc|--command '<cmd>'`, GNU `parallel CMD ::: ...` / `parallel ::: 'CMD'` / `... | parallel`, watch,
# find -exec/-execdir/-ok, `git submodule foreach [--recursive] '<cmd>'`, `git rebase -x|--exec '<cmd>'`, `git bisect
# run CMD`.
#
# CATALOGUE RULE (round 5: STRUCTURAL). Every refused row of docs/zero-gap/guarded-commands.tsv is judged by PARSING the
# command's arguments the way the tool does (ground truth recorded for git 2.53, bash 5.3, util-linux 2.41, procps):
# options in any order and position (GNU and git permute: `git reset HEAD~1 --hard`), short clusters (`-qf`, `-ef`),
# option VALUES skipped (`git update-ref -m msg -d`, `git commit -m "--no-verify is..."`), unique long-option prefixes
# resolved (`--har`, `--h`, `--dele`, `--forc`, `--f`; an AMBIGUOUS prefix marks every candidate, because the tool then
# refuses to run, so refusing costs nothing), at command position of the normalised command (every wrapper stage), so
# `echo will reboot later` and `git commit -m "avoid git add -A"` stay allowed. What each row refuses, in any spelling:
#   reset-hard        git reset with --hard;      stash-all   git stash except list/show
#   restore-discard   git restore unless it touches the index alone (-S/--staged and no -W/--worktree)
#   checkout-discard  every discard form: `git checkout` with -f/--force, paths after `--`, a tree-ish plus paths,
#                     --pathspec-from-file, or one operand that is an existing path and no ref (loose or packed);
#                     `git switch -f|--discard-changes`; `git checkout-index -f`; `git read-tree -u --reset`.
#                     A plain branch switch, `-b/-B/-c`, and `git restore --staged` stay allowed
#   add-all/add-dot   git add -A/--all, -u/--update without a pathspec, a whole-tree pathspec (. ./ * ** :/ :(top), a
#                     path resolving to the cwd, the work-tree top or an ancestor: "$PWD", $(pwd), the absolute repo
#                     path, `..` from a subdirectory), or ONLY exclude pathspecs (`:!x`, `:(exclude)x` add everything else)
#   clean-*           git clean with -f/--force, or with -c clean.requireForce=false and no -n
#   force-push (any)  git push -f/--force/--force-with-lease/--force-if-includes/--mirror or a +refspec
#   remote-branch-*   git push -d/--delete/--prune, or a refspec with an empty source (`:old`); `git push origin :`
#                     (matching) stays allowed
#   branch-delete     git branch -D, -d with -f, and -M/-C (or -m/-c -f) onto an EXISTING branch
#   ref-delete        git update-ref -d, a zero new value, or --stdin fed a `delete` line (or unknown input)
#   history-rewrite   git filter-branch, git filter-repo
#   no-verify / force-with-lease  flag classes judged on the options a git command really passes, per subcommand,
#                     matched WHOLE (`--no-verify-signatures` is another option), `git commit -n`/-nm; a hook bypass by
#                     configuration counts: -c|--config-env core.hooksPath, GIT_CONFIG_KEY_n / GIT_CONFIG_PARAMETERS, and
#                     `git config [scope] core.hooksPath VALUE`. grep/rg/git grep/git log -G searching for them are allowed
#   privilege-escalation  sudo doas pkexec run0 su
#   host-power (+poweroff/reboot/halt)  the bare commands; systemctl with a power verb (suspend hibernate hybrid-sleep
#                     suspend-then-hibernate sleep poweroff reboot halt kexec soft-reboot emergency rescue) or isolate
#                     after ANY options (-i, -q, --no-ask-password, --check-inhibitors=no), or start/restart/isolate/
#                     enable --now of a power unit (suspend.target, systemd-suspend.service, ...); loginctl power verbs;
#                     shutdown (but -c/--show); telinit/init 0 1 6 s; pm-suspend & co; rtcwake (but -m no|show|disable|on);
#                     busctl/gdbus call, dbus-send, qdbus of login1/systemd1/SessionManager Suspend/PowerOff/Reboot/...
#                     or StartUnit of a power unit
#   session-kill      (project) systemctl exit / --user exit, start of exit.target, loginctl terminate-*/kill-*,
#                     gnome-/cinnamon-session-quit, xfce4-session-logout, lxqt-leave, D-Bus Exit/Logout/Terminate*/Kill*
#   signal-by-pattern pkill -f/--full in any cluster or prefix (signal words -9 -TERM -SIGKILL are skipped), and
#                     kill $(pgrep ...) / kill `pidof ...`
#   signal-by-name    killall (any)
#   signal-all-processes (project) kill of a pid < 2 (-1 every process, 0 our group, 1 init, a negative pgid) unless the
#                     signal is 0; killall5; pkill -u/-U/--euid/--uid, -s 0, -g 0
#   rm roots (remove-root, remove-home, project rm-recursive-root)  rm -r|-R|--recursive (any spelling) or find -delete
#                     of / , /home, $HOME or an ancestor after the shell's expansions ($HOME ${HOME} ${HOME:?} ${HOME%/}
#                     $VAR assigned earlier on the line, $(pwd), ~ ~/ ~user, //, /., ~/..), of a glob that names one
#                     (/ho?e) or of a catch-all glob directly under one (/*, /*/, ~/*/, ~/.*/, /home/*/). An UNSET variable
#                     is empty (each Bash call is a fresh shell): `rm -rf "$S"/*` with S unset is `rm -rf /*` and is
#                     refused; `${S:?}` aborts the command and is allowed. A sub-path (`~/Projects/x/*`) is not a root.
# A refused row with no parser above (a FUTURE row) falls back to its `candidate` ERE at command position. Every refusal
# names what to do instead (HINTS; the proof asserts the hint).
#
# TMPFS RULE (host-hang fix WP1, 2026-10-14). Refuses BULK writes that bring DISK data into RAM-backed
# tmpfs (/tmp, /dev/shm, /run/user/N). Bulk means: recursive (cp -a|-r|-R, rsync, zip -r, podman|docker cp),
# a clone/worktree/bundle/archive (git clone / worktree add / bundle create / archive, tar -c), an archive
# extraction (tar -x, unzip, 7z x), git FETCHING into a repo on tmpfs or checking a disk repo out into a
# work tree on tmpfs, podman|docker save|export, a directory or a file over 64 MiB moved (`mv`, a
# cross-device full copy), copied (`cp` without -r) or installed (`install`, not -d) — size and type are checked on this host —, `dd`
# (of= or stdout redirected onto tmpfs) without count= or over 64 MiB (count x bs, else ibs), `git push`
# into a repository on tmpfs, `git remote update` / `remote add -f` in one, and a download (curl -o/-O,
# wget -O/-P/cwd, or stdout redirected onto tmpfs) whose FILE NAME (the target's OR any URL's) is a model or
# an archive (.gguf .bin .safetensors .onnx .pt .tar .tgz .gz .xz .zst .zip .7z .iso .img .whl ..., also with a partial
# suffix .part .partial .tmp .download .crdownload .incomplete .N): a
# download's size cannot be known statically, so a small page or JSON fetched into /tmp is allowed. NOT
# bulk (allowed): a single named file of bounded or unknown size (`mv out.txt /tmp/`, `cp a /tmp/a`,
# `> /tmp/f`, `go build -o /tmp/x`, `dd ... count=1`), `cp -l|-s` (links copy no data), a tmpfs -> tmpfs
# copy, and a checkout inside a repo that already lives on tmpfs. A producer writing to stdout counts its PIPELINE
# sinks: the redirects of pass-through filters downstream (cat tee gzip zstd xz bzip2 lz4 pv dd base64 openssl gpg ...)
# and tee's files (`podman save img | gzip > /tmp/x.tgz`, `curl URL.gguf | tee /tmp/m.gguf`); a non-pass-through
# filter (`| sha256sum > /tmp/sum`) ends the data flow. Destinations are resolved through
# literal paths, `cd`/`pushd` (subshell-scoped; `cd -`), `git -C`, `env -C`, GIT_DIR/GIT_WORK_TREE,
# VAR=literal and `export VAR=` earlier on the same line, `for VAR in literal`, $TMPDIR / ${TMPDIR:-/tmp}
# (an in-line `export TMPDIR=` wins over the hook's own environment; unset => /tmp), $PWD / $(pwd) and $(mktemp ...)
# (=> that TMPDIR unless -p/--tmpdir/template says otherwise). The only escape is an inline
# AGENT_TMPFS_OK='<at least 3 distinct real words>' prefix on THAT command (an earlier `export` does not
# count); it is appended to $AGENT_TMPFS_OK_LOG (default <agent-scratch>/tmpfs-overrides.log) and refused
# when the log cannot be written. An agent can still write such a reason: the log is the control.
#
# REPLAY (how the re-reviews measured false positives; the corpus is NOT tracked: real agent commands carry private
# paths and names into a PUBLIC repository). Extract every Bash tool command from ~/.claude*/projects/*/*.jsonl
# (tool_use blocks, name "Bash", input.command), feed each as {"tool_name":"Bash","tool_input":{"command":...},"cwd":...}
# to this hook and diff the rc against the previous version. 2026-10-14 round 3 (28b75d1): 5,101 commands, 100 refused,
# 0 mis-parses, p95 82 ms. Round 4 (vs 7ab93e2/d156b13): 94 refused by both, 0 verdict changes, p95 93 ms.
# Round 5 (this version vs b44c9b0, same corpus): 96 refused (94 before), 2 verdict changes, both intended - a commit
# run with `git -c core.hooksPath=/dev/null` (a real hook bypass, now no-verify) and a `git checkout <file>` that discards
# that file's edits (checkout-discard); 0 tracebacks, 0 timeouts, p95 81 ms per call (89 ms before: the compiled-code
# cache more than pays for the larger program).
#
# REVIEW MUTANTS. The proof counts a mutant as caught only when a NAMED case's VERDICT flips (a crashing mutant proves
# nothing; a catalogue refusal without its hint counts as a flip). Round 5: P13 removes each '# MUTANT:' line
# (63 lexer/normaliser/structural mutants) and P15 applies 102 old->new replacement mutants, the round-4 review's
# survivors among them (flock lock-file drop, `*`/`**` whole-tree, every literal-prefix bypass); P11 removes each of the
# 17 tmpfs rule branches.
#
# KNOWN LIMITS — what this hook does NOT see (documented, not covered; the upstream guard shares them):
#  - code it cannot read: a script FILE run by name (`bash x.sh`, `./x.sh`), `source`/`.` of a file, an alias or shell
#    function defined in an earlier Bash call, code inside an interpreter (`python3 -c "shutil.copytree(...)"`, perl,
#    node, awk system(), make recipes), a here-document or here-string fed to a non-shell interpreter (`python3 - <<EOF`);
#  - text built at run time: base64/printf into eval, variables set by `read`, by a command substitution other than
#    mktemp / pwd / `git rev-parse --show-toplevel`, or in an EARLIER Bash call (an unset variable is judged EMPTY, as the
#    fresh shell will see it), positional/special parameters ($1, $@), process substitution;
#  - commands run elsewhere or later: `ssh host 'cmd'`, tmux/screen sessions, at/batch/cron, `systemd-run --on-*`
#    timers, `pgrep -f x | xargs kill` (xargs gets its pids from the pipe), a git ALIAS (`git ci -n`: an unknown
#    subcommand gets a long-option scan only), `-c alias.x='!cmd'`, `git difftool -x`, a hook directory edited in place;
#  - git operations outside the catalogue classes: `git commit -a` (sweeps every tracked edit), `git rm -r .`,
#    `git merge|rebase|cherry-pick --abort`, `git branch -f NAME REV`, `git reflog expire` + `git gc --prune=now`, a
#    force refspec CONFIGURED in remote.NAME.push, `-c include.path=` / GIT_CONFIG_GLOBAL pointing at a file that sets
#    core.hooksPath; interactive `-p` modes;
#  - host/session forms outside the parsers above: `pkill gnome-shell` by plain name (only -f, user and session selectors
#    are refused), `systemctl --user stop graphical-session.target` or of a desktop unit, kill of a session process by a
#    pid it found elsewhere, writes to /sys/power/state (root only);
#  - destructive classes the catalogue does not list (disk wiping: mkfs, `dd of=/dev/...`, shred, wipefs);
#  - an rm root reached through a symlink, `find / -exec rm -rf {} +` (its {} is not a path), a variable assigned in an
#    earlier call to a root path;
#  - tmpfs writes: a destination reached through a symlink (`ln -s /tmp/x lnk && cp -a src lnk/`), a command
#    substitution other than mktemp/pwd used as a path (treated as unknown, i.e. disk), a download whose target AND URL
#    names carry no model/archive suffix (`curl -o /tmp/blob 'https://h/get?id=1'`: its size cannot be known), tools not
#    listed in the TMPFS RULE (`go mod download` into GOMODCACHE=/tmp/x, `npm ci --cache /tmp/x`, cpio/pax, split,
#    compressors writing beside an input on tmpfs, `podman build` caches), and data piped through a filter that is not
#    pass-through (`| my-tool > /tmp/x`).
# The compiled-code cache (see LOADER) trusts files the user owns that nobody else can write: whoever can write
# ~/.cache can also edit this script. Use a disk TMPDIR (docs/AGENT_GUARDRAILS.md section D) for the structural fix.
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
import fnmatch, json, os, pwd, re, sys, time

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
BRACE_MAX = 256

def brace_seq(inner):
    m = re.match(r"^(-?[0-9]+)\.\.(-?[0-9]+)(?:\.\.(-?[0-9]+))?$", inner) or re.match(r"^([A-Za-z])\.\.([A-Za-z])(?:\.\.(-?[0-9]+))?$", inner)
    if not m:
        return None
    num = m.group(1).lstrip("-").isdigit()
    a, b = (int(m.group(1)), int(m.group(2))) if num else (ord(m.group(1)), ord(m.group(2)))
    step = abs(int(m.group(3) or 1)) or 1
    if abs(b - a) // step >= BRACE_MAX:
        return None
    vals = range(a, b + (1 if b >= a else -1), step if b >= a else -step)
    return [str(v) if num else chr(v) for v in vals]

def brace_expand(t, m, depth=0):
    """bash brace expansion of ONE word: `m` marks each character of `t` 'u' (unquoted) or 'q' (quoted, or inside $(..) ${..}
    `..`), and only unquoted braces with a top-level comma or a valid sequence expand ({git,reset,--hard}, --{hard,}, ~{,})."""
    if "{" not in t or depth > 16:
        return [t]
    n, i = len(t), 0
    while i < n:
        if t[i] != "{" or m[i] != "u":
            i += 1; continue
        lvl, j, commas = 0, i, []
        while j < n:
            if m[j] == "u":
                if t[j] == "{":
                    lvl += 1
                elif t[j] == "}":
                    lvl -= 1
                    if lvl == 0:
                        break
                elif t[j] == "," and lvl == 1:
                    commas.append(j)
            j += 1
        if j >= n:
            return [t]
        if commas:
            parts, k = [], i + 1
            for c in commas + [j]:
                parts.append((t[k:c], m[k:c])); k = c + 1
        else:
            seq = brace_seq(t[i + 1:j]) if "q" not in m[i + 1:j] else None
            if seq is None:
                i += 1; continue                  # literal braces ({}, {x}, ${...} is masked): look further right
            parts = [(v, "u" * len(v)) for v in seq]
        out = []
        for pt, pm in parts:
            out.extend(brace_expand(t[:i] + pt + t[j + 1:], m[:i] + pm + m[j + 1:], depth + 1))
            if len(out) > BRACE_MAX:
                return [t]
        return out
    return [t]

def lex(s):
    toks = []
    n, i = len(s), 0
    st = {"buf": [], "m": [], "q": False, "subs": [], "in": False, "delim": None}
    pending = []

    def end_word():
        if st["in"]:
            w = {"t": "".join(st["buf"]), "q": st["q"], "subs": st["subs"]}
            if st["delim"] is not None:   # a here-document delimiter: its body is bound HERE, to the command owning the <<
                ref = ["", w["q"]]
                pending.append((w["t"], st["delim"], ref)); st["delim"] = None
                toks.append(("W", w))
                toks.append(("H", ref))  # MUTANT:heredoc-owner
            else:
                alts = [w["t"]]
                alts = brace_expand(w["t"], "".join(st["m"]))  # MUTANT:brace-expand
                for k, t in enumerate(alts):
                    toks.append(("W", {"t": t, "q": w["q"], "subs": w["subs"] if k == 0 else []}))
        st.update(buf=[], m=[], q=False, subs=[], **{"in": False})

    def put(x, quoted=False, nobrace=False):
        st["buf"].append(x); st["in"] = True
        st["m"].append(("q" if quoted or nobrace else "u") * len(x))
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
            put(s[i:k + 2], nobrace=True); i = k + 2; continue
        # an arithmetic command `(( ... ))` is data (its << is a shift); a $(...) inside it runs and is judged
        if s.startswith("((", i) and not st["in"]: k = find_close(s, i + 2, "(", ")"); st["subs"].extend(body_subs(s[i + 2:k])); put(s[i:k + 2], True); i = k + 2; continue  # MUTANT:arith-cmd
        if s.startswith("$(", i):
            k = find_close(s, i + 2, "(", ")"); st["subs"].append(s[i + 2:k]); put(s[i:k + 1], nobrace=True); i = k + 1; continue
        if s.startswith("${", i):
            k = s.find("}", i + 2); k = n if k < 0 else k; put(s[i:k + 1], nobrace=True); i = k + 1; continue
        if c == "`":
            k = s.find("`", i + 1); k = n if k < 0 else k
            st["subs"].append(s[i + 1:k]); put(s[i:k + 1], nobrace=True); i = k + 1; continue
        if c == "#" and not st["in"]:
            j = s.find("\n", i); i = n if j < 0 else j; continue
        if c in " \t":
            end_word(); i += 1; continue
        op = next((o for o in OPS if s.startswith(o, i)), None)
        if op:
            if op in REDIR_OPS and st["in"] and not st["q"] and "".join(st["buf"]).isdigit():
                st.update(buf=[], m=[], **{"in": False})
            end_word()
            if op == "\n":
                i += 1
                for delim, strip, ref in pending:
                    body = []
                    while i < n:
                        j = s.find("\n", i)
                        line = s[i:] if j < 0 else s[i:j]
                        i = n if j < 0 else j + 1
                        if (line.lstrip("\t") if strip else line) == delim:
                            break
                        body.append(line)
                    ref[0] = "\n".join(body)   # the placeholder sits in the command that owns this <<
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
VARRE = re.compile(r"\$\{([A-Za-z_][A-Za-z0-9_]*)(?:(:?[-=+?]|%%|%|##|#)([^}]*))?\}|\$([A-Za-z_][A-Za-z0-9_]*)")

def tmp_default():
    return os.environ.get("TMPDIR") or "/tmp"

def lookup(name, ctx):
    if name == "TMPDIR":              # an `export TMPDIR=...` / `TMPDIR=...` earlier on the line wins
        v = os.environ.get("TMPDIR")
        v = ctx["vars"].get("TMPDIR", v)  # MUTANT:tmpdir-vars
        return v if v is UNKNOWN or v else "/tmp"   # unset/empty TMPDIR: mktemp & co. fall back to /tmp
    if name in ctx["vars"]:
        return ctx["vars"][name]
    if name == "PWD" and ctx.get("cwd"):  # the COMMAND's working directory, not the hook's
        return ctx["cwd"]
    if name == "OLDPWD" and ctx.get("prev"):
        return ctx["prev"]
    return os.environ.get(name)       # each Bash call is a fresh shell: unset means empty

def repo_top(d):
    """The work-tree top of the repository containing directory `d` (the first ancestor holding .git), or None."""
    for _ in range(64):
        if not d:
            return None
        if os.path.lexists(os.path.join(d, ".git")):
            return d
        if d == "/":
            return None
        d = os.path.dirname(d)
    return None

def mktemp_path(inner, ctx):
    """The value of a command substitution that can be known statically: mktemp (its directory), pwd, and
    git rev-parse --show-toplevel. Anything else: None (unknown)."""
    items = [x for x in commands(lex(inner)) if x[0] == "cmd"]
    if len(items) != 1:
        return None
    a = [w["t"] for w in items[0][1]]
    if a and bn(a[0]) == "pwd" and all(x in ("-L", "-P") for x in a[1:]):
        return ctx["cwd"]
    if a[:3] == ["git", "rev-parse", "--show-toplevel"] and len(a) == 3:
        return repo_top(ctx["cwd"])
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
        if op in ("?", ":?") and (v is None or (op == ":?" and v == "")):
            bad.append(name); return ""          # ${S:?}: the shell aborts the command when S is unset (or empty)
        if op in ("%", "%%", "#", "##"):          # ${HOME%/} ${D%%/*} ${P#./}: pattern removal (shortest / longest)
            v, pat = v or "", expand(dflt or "", ctx, depth + 1)
            if pat is None:
                bad.append(name); return ""
            ks = range(len(v), -1, -1) if op in ("%", "##") else range(0, len(v) + 1)
            for k in ks:
                if op.startswith("%") and fnmatch.fnmatchcase(v[k:], pat):
                    return v[:k]
                if op.startswith("#") and fnmatch.fnmatchcase(v[:k], pat):
                    return v[k:]
            return v
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
    "flock": {"-w", "--timeout", "--wait", "-E", "--conflict-exit-code"},
    "sudo": {"-u", "-g", "-C", "-D", "-h", "-p", "-r", "-t", "-U", "-T"}, "doas": {"-u", "-C"},
    "time": set(), "watch": {"-n", "--interval"},
    "bounded-run": {"-m", "-t", "-c", "-s", "-T", "-n", "--mem", "--tasks", "--timeout"},
    "agent-admit.sh": {"--slots", "--tag", "--wait", "-m", "-T"},
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
        if name == "flock" and rest:          # util-linux flock: [opts] FILE -c 'CMD'  |  [opts] FILE CMD [ARGS]
            rest = rest[1:]                      # the lock file  # MUTANT:flock-file
            if rest and rest[0]["t"] in ("-c", "--command"):
                r["nested"].extend(w["t"] for w in rest[1:2])  # MUTANT:flock-c
                rest = []
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
    """Strip git global options. -> (argv texts, chdirs, work_tree, git_dir, config [name=value...])"""
    return git_globals_t([w["t"] for w in argv])

# git's global options (git.c handle_options): these take a SEPARATE value; every other word starting with '-' before the
# subcommand is a global option without one (an unknown one makes git exit non-zero, so nothing runs). git does NOT
# abbreviate global options.
GIT_GLOBAL_VAL = {"-C", "-c", "--git-dir", "--work-tree", "--namespace", "--config-env", "--attr-source", "--super-prefix",
                  "--list-cmds"}

def git_globals_t(a):
    """git_globals on argv TEXTS."""
    if not a or bn(a[0]) != "git":
        return a, [], None, None, []
    chdirs, wt, gd, cfg, i = [], None, None, [], 1
    while i < len(a):
        w = a[i]
        if not w.startswith("-") or w == "-":
            break
        if w == "--":
            i += 1; break
        if w in GIT_GLOBAL_VAL and i + 1 < len(a):
            v = a[i + 1]
            if w == "-C":
                chdirs.append(v)
            elif w == "--git-dir":
                gd = v
            elif w == "--work-tree":
                wt = v
            elif w in ("-c", "--config-env"):
                cfg.append(v)
            i += 2; continue
        if w.startswith("--git-dir="):
            gd = w.split("=", 1)[1]
        elif w.startswith("--work-tree="):
            wt = w.split("=", 1)[1]
        elif w.startswith("--config-env="):
            cfg.append(w.split("=", 1)[1])
        i += 1                                   # MUTANT-ANCHOR:git-global-generic
    return ["git"] + a[i:], chdirs, wt, gd, cfg

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

# ════════════════════════════════════════════════════════════════════════════════════════════════════
# Structural judgement of the refused classes (round 5, 2026-10-14). Every catalogue row is judged by PARSING the
# command's arguments the way the tool itself does, never by a literal prefix of the command line: options in any
# order, clusters (-qf), unique long-option prefixes (getopt_long and git parse-options both accept `--har`, `--dele`;
# an AMBIGUOUS prefix marks every candidate: the tool refuses to run it, so refusing it here costs nothing), values
# skipped. Ground truth recorded for git 2.53, bash 5.3, util-linux 2.41 and procps (round-5 probe scripts).
# A catalogue row with no parser below (a future row) still falls back to its regex at command position.
# ════════════════════════════════════════════════════════════════════════════════════════════════════
STRUCT_IDS = {"checkout-discard", "restore-discard", "stash-all", "clean-force-dirs", "add-all", "reset-hard", "force-push",
              "privilege-escalation", "host-power", "host-poweroff", "signal-by-pattern", "signal-by-name", "remove-root",
              "history-rewrite", "branch-delete", "ref-delete", "clean-ignored", "checkout-dot", "add-dot", "host-reboot",
              "host-halt", "remote-branch-delete-refspec", "remote-branch-delete-flag", "remove-home"}

def opt_parse(args, short_val="", spec=None, short_opt=""):
    """-> (shorts {letter: [value|None]}, longs {canonical: [value|None]}, positionals, words after `--`).
    Short options cluster; a letter in `short_val` takes the rest of its cluster or the next word as its value, one in
    `short_opt` only an attached value. A long option resolves by exact name, else by prefix among `spec` (name -> takes a
    value); an unknown long option is kept verbatim. Options after operands still count (GNU and git permute)."""
    spec = spec or {}
    sh, lo, pos, i = {}, {}, [], 0
    while i < len(args):
        w = args[i]
        if w == "--":
            return sh, lo, pos, args[i + 1:]
        if w.startswith("--"):
            name, eq, val = w.partition("=")
            cands = [name] if name in spec else [f for f in spec if len(name) > 2 and f.startswith(name)]  # MUTANT-ANCHOR:long-prefix
            if not cands:
                lo.setdefault(name, []).append(val if eq else None); i += 1; continue
            if not eq and any(spec[c] for c in cands) and i + 1 < len(args):
                val, eq = args[i + 1], "="; i += 1
            for c in cands:
                lo.setdefault(c, []).append(val if eq else None)
            i += 1; continue
        if w.startswith("-") and len(w) > 1:
            for k, ch in enumerate(w[1:], 1):
                if ch in short_val:
                    if k == len(w) - 1:
                        v = args[i + 1] if i + 1 < len(args) else ""; i += 1
                    else:
                        v = w[k + 1:]
                    sh.setdefault(ch, []).append(v); break
                if ch in short_opt:
                    sh.setdefault(ch, []).append(w[k + 1:] or None); break
                sh.setdefault(ch, []).append(None)
            i += 1; continue
        pos.append(w); i += 1
    return sh, lo, pos, []

def L(*flags, v=()):
    d = {f: False for f in flags}
    d.update({x: True for x in v})
    return d

# git subcommand -> (short letters taking a value, long options). Sources: git 2.53 builtin/*.c option tables.
GIT_SPEC = {
    "reset": ("", L("--hard", "--soft", "--mixed", "--merge", "--keep", "--quiet", "--no-quiet", "--patch", "--intent-to-add",
                    "--pathspec-file-nul", "--recurse-submodules", "--no-recurse-submodules", "--refresh", "--no-refresh",
                    v=("--pathspec-from-file",))),
    "checkout": ("bB", L("--force", "--quiet", "--merge", "--patch", "--detach", "--ours", "--theirs", "--overlay",
                         "--no-overlay", "--progress", "--no-progress", "--guess", "--no-guess", "--track", "--no-track",
                         "--ignore-other-worktrees", "--overwrite-ignore", "--no-overwrite-ignore", "--recurse-submodules",
                         "--no-recurse-submodules", "--pathspec-file-nul", "--ignore-skip-worktree-bits",
                         v=("--orphan", "--conflict", "--pathspec-from-file"))),
    "switch": ("cC", L("--force", "--discard-changes", "--detach", "--merge", "--quiet", "--progress", "--no-progress",
                       "--guess", "--no-guess", "--track", "--no-track", "--ignore-other-worktrees", "--recurse-submodules",
                       "--no-recurse-submodules", v=("--create", "--force-create", "--orphan", "--conflict"))),
    "checkout-index": ("", L("--all", "--force", "--index", "--no-create", "--quiet", "--stdin", "--temp",
                             "--ignore-skip-worktree-bits", v=("--prefix", "--stage"))),
    "read-tree": ("", L("--reset", "--trivial", "--aggressive", "--dry-run", "--no-sparse-checkout", "--empty", "--quiet",
                        "--recurse-submodules", "--no-recurse-submodules",
                        v=("--prefix", "--index-output", "--exclude-per-directory"))),
    "clean": ("e", L("--force", "--dry-run", "--quiet", "--interactive", v=("--exclude",))),
    "add": ("", L("--all", "--no-all", "--update", "--dry-run", "--verbose", "--force", "--interactive", "--patch", "--edit",
                  "--intent-to-add", "--refresh", "--ignore-errors", "--ignore-missing", "--renormalize", "--sparse",
                  "--ignore-removal", "--no-ignore-removal", "--pathspec-file-nul", v=("--chmod", "--pathspec-from-file"))),
    "push": ("o", L("--all", "--branches", "--mirror", "--delete", "--tags", "--dry-run", "--porcelain", "--force",
                    "--force-with-lease", "--force-if-includes", "--set-upstream", "--thin", "--no-thin", "--progress",
                    "--prune", "--no-verify", "--verify", "--follow-tags", "--no-follow-tags", "--signed", "--no-signed",
                    "--atomic", "--no-atomic", "--ipv4", "--ipv6", "--recurse-submodules", "--quiet", "--verbose",
                    v=("--repo", "--receive-pack", "--exec", "--push-option"))),
    "branch": ("u", L("--delete", "--force", "--move", "--copy", "--list", "--remotes", "--all", "--verbose", "--quiet",
                      "--track", "--no-track", "--unset-upstream", "--edit-description", "--show-current", "--create-reflog",
                      "--ignore-case", "--omit-empty", "--recurse-submodules", "--contains", "--no-contains", "--merged",
                      "--no-merged", "--column", "--no-column", "--abbrev", "--no-abbrev", "--color", "--no-color",
                      v=("--set-upstream-to", "--format", "--sort", "--points-at"))),
    "update-ref": ("m", L("--no-deref", "--stdin", "--create-reflog", "--batch-updates")),
    "rebase": ("xsXC", L(v=("--exec", "--onto", "--strategy", "--strategy-option", "--whitespace", "--empty"))),
}
FALSEY = ("false", "no", "off", "0")
ZERO_OID = re.compile(r"^(0{40}|0{64})$")

def is_exclude(p):
    """An exclude pathspec: :!x :^x :/!x :(exclude)x :(top,exclude)x"""
    if p.startswith(":("):
        k = p.find(")")
        return k > 0 and "exclude" in p[2:k].split(",")
    m = re.match(r"^:([/!^]*)", p)
    return bool(m) and ("!" in m.group(1) or "^" in m.group(1))

def whole_tree_at(w, ctx):
    """whole_tree(), or a path that resolves to the command's cwd, the work-tree top or an ancestor of it ("$PWD", $(pwd),
    an absolute repo path, `..` from a subdirectory)."""
    if whole_tree(w): return True  # MUTANT:whole-tree-spelling
    if w.startswith(":"):
        return False
    p = resolve(w, ctx)
    if not p:
        return False
    top = repo_top(ctx.get("cwd"))
    return p in ("/", ctx.get("cwd")) or bool(top) and (p == top or top.startswith(p.rstrip("/") + "/"))  # MUTANT-ANCHOR:whole-tree-at

def git_dir_of(top):
    """(gitdir, commondir) of the work tree at `top` (a linked worktree's .git is a `gitdir:` file)."""
    gd = os.path.join(top, ".git")
    try:
        if os.path.isfile(gd):
            with open(gd, encoding="utf-8") as fh:
                m = re.match(r"gitdir:\s*(.+)", fh.read().strip())
            gd = os.path.normpath(os.path.join(top, m.group(1))) if m else gd
        cd = gd
        if os.path.isfile(os.path.join(gd, "commondir")):
            with open(os.path.join(gd, "commondir"), encoding="utf-8") as fh:
                cd = os.path.normpath(os.path.join(gd, fh.read().strip()))
        return gd, cd
    except OSError:
        return gd, gd

def ref_exists(name, ctx):
    """`name` names a branch, tag or remote-tracking branch (loose or packed) of the repository at the command's cwd."""
    top = repo_top(ctx.get("cwd"))
    if not top or not name or name.startswith("-"):
        return False
    _gd, cd = git_dir_of(top)
    cands = ["refs/heads/" + name, "refs/tags/" + name, "refs/remotes/" + name, name]
    if any(os.path.isfile(os.path.join(cd, r)) for r in cands):
        return True
    try:
        if any(os.path.isfile(os.path.join(cd, "refs/remotes", r, name)) for r in os.listdir(os.path.join(cd, "refs/remotes"))):
            return True
    except OSError:
        pass
    try:
        with open(os.path.join(cd, "packed-refs"), encoding="utf-8") as fh:
            for line in fh:
                ref = line.rstrip("\n").split(" ", 1)[-1]
                if ref in cands or (ref.startswith("refs/remotes/") and ref.endswith("/" + name)):
                    return True
    except OSError:
        pass
    return False

def path_not_ref(name, ctx):
    """`git checkout <name>` without `--` checks out the PATH <name> (discarding its edits) when <name> exists in the work
    tree and is not a ref (git's own disambiguation, checked on this host)."""
    if not ctx.get("cwd") or whole_tree(name) or name.startswith(("-", ":")):
        return False
    p = resolve(name, ctx)
    return bool(p) and os.path.lexists(p) and repo_top(ctx["cwd"]) is not None and not ref_exists(name, ctx)

def stdin_has(io, rx):
    """True when the command's stdin is known to contain `rx`, or is UNKNOWN (a file or another program's output)."""
    texts = io.get("stdin")
    return texts is None or any(re.search(rx, t or "", re.M) for t in texts)

def git_struct(a, ids, ctx, cfg, env, io):
    sub, args = a[1], a[2:]
    sv, spec = GIT_SPEC.get(sub, ("", {}))
    sh, lo, pos, dd = opt_parse(args, sv, spec)
    hooks = [c for c in cfg if c.split("=", 1)[0].lower() == "core.hookspath"]
    hooks += [k for k, v in env.items() if k.startswith("GIT_CONFIG_KEY_") and str(v).lower() == "core.hookspath"]
    hooks += [k for k, v in env.items() if k == "GIT_CONFIG_PARAMETERS" and "core.hookspath" in str(v).lower()]
    if hooks and "no-verify" in ids:
        return "no-verify"                       # a hook bypass by configuration is a --no-verify
    if sub == "config" and "no-verify" in ids:
        low = [x.lower() for x in args]
        if "core.hookspath" in low:
            k = low.index("core.hookspath")
            reading = any(x in ("--get", "--get-all", "--get-regexp", "--unset", "--unset-all", "get", "unset", "--list", "-l")
                          for x in args[:k])
            if k + 1 < len(args) and not reading:
                return "no-verify"
    if sub == "reset" and "--hard" in lo and "reset-hard" in ids: return "reset-hard"  # MUTANT:s-reset
    if sub == "stash" and not (args and args[0] in ("list", "show")) and "stash-all" in ids: return "stash-all"  # MUTANT:s-stash
    if sub == "restore" and not readonly_git(a) and "restore-discard" in ids: return "restore-discard"  # MUTANT-ANCHOR:s-restore
    if sub in ("filter-branch", "filter-repo") and "history-rewrite" in ids: return "history-rewrite"
    if sub == "clean":
        dry = "n" in sh or "--dry-run" in lo
        unforced = any(c.split("=", 1)[0].lower() == "clean.requireforce" and c.split("=", 1)[-1].lower() in FALSEY for c in cfg)
        if "f" in sh or "--force" in lo or (unforced and not dry): return "clean-force-any-spelling"  # MUTANT:extra-clean
    if sub == "checkout":
        if any(whole_tree_at(p, ctx) for p in pos + dd): return "checkout-tree-discard"  # MUTANT:extra-checkout
        discard = ("f" in sh or "--force" in lo or dd or "--pathspec-from-file" in lo or len(pos) >= 2  # MUTANT-ANCHOR:checkout-discard
                   or (len(pos) == 1 and path_not_ref(pos[0], ctx)))
        if discard and "checkout-discard" in ids: return "checkout-discard"
    if sub == "switch" and ("f" in sh or "--force" in lo or "--discard-changes" in lo) and "checkout-discard" in ids: return "checkout-discard"  # MUTANT:s-switch
    if sub == "checkout-index" and ("f" in sh or "--force" in lo) and "checkout-discard" in ids: return "checkout-discard"  # MUTANT:s-checkout-index
    if sub == "read-tree" and "--reset" in lo and "u" in sh and "checkout-discard" in ids: return "checkout-discard"  # MUTANT:s-read-tree
    if sub == "add":
        ps = pos + dd
        if "A" in sh or "--all" in lo: return "add-all-any-spelling"  # MUTANT:extra-add-all
        if ("u" in sh or "--update" in lo) and not [p for p in ps if not is_exclude(p)]: return "add-all-any-spelling"
        if any(whole_tree_at(p, ctx) for p in ps): return "add-all-any-spelling"
        if ps and all(is_exclude(p) for p in ps): return "add-all-any-spelling"  # MUTANT:s-add-exclude
    if sub == "push":
        refs = (pos if "--repo" in lo else pos[1:]) + dd
        if ("f" in sh or any(k in lo for k in ("--force", "--force-with-lease", "--force-if-includes", "--mirror"))
                or any(r.startswith("+") and len(r) > 1 for r in refs)): return "force-push-any-spelling"  # MUTANT-ANCHOR:s-push-force
        if "d" in sh or "--delete" in lo or "--prune" in lo: return "remote-branch-delete-flag"  # MUTANT:s-push-delete
        if any(r.startswith(":") and len(r) > 1 for r in refs): return "remote-branch-delete-refspec"  # MUTANT-ANCHOR:s-push-refspec
    if sub == "branch":
        force = "f" in sh or "--force" in lo
        if "D" in sh or (("d" in sh or "--delete" in lo) and force): return "branch-force-delete"  # MUTANT:extra-branch
        moving = "M" in sh or "C" in sh or (force and ("m" in sh or "c" in sh or "--move" in lo or "--copy" in lo))
        if moving and pos and ref_exists(pos[-1], ctx): return "branch-force-delete"  # overwrites (deletes) that branch
    if sub == "update-ref" and "ref-delete" in ids:
        if "d" in sh: return "ref-delete"  # MUTANT:s-update-ref
        if len(pos) >= 2 and ZERO_OID.match(pos[1]): return "ref-delete"
        if "--stdin" in lo and stdin_has(io, r"^\s*(delete\s|update\s+\S+\s+0{40}\b)"): return "ref-delete"
    return None

def git_nested(a):
    """Commands git runs for you: (shell scripts, argvs). submodule foreach '<cmd>', rebase -x/--exec '<cmd>', bisect run."""
    scripts, argvs = [], []
    if len(a) < 2:
        return scripts, argvs
    if a[1] == "submodule":
        k = 2
        while k < len(a) and a[k].startswith("-"):
            k += 1
        if k < len(a) and a[k] == "foreach":
            r = a[k + 1:]
            while r and r[0] in ("--recursive", "-q", "--quiet", "--"):
                r = r[1:]
            if r: scripts.append(" ".join(r))  # MUTANT:submodule-foreach
    if a[1] == "rebase":
        sv, spec = GIT_SPEC["rebase"]
        sh, lo, _p, _d = opt_parse(a[2:], sv, spec)
        scripts += [v for v in sh.get("x", []) + lo.get("--exec", []) if v]  # MUTANT:rebase-exec
    if a[1] == "bisect" and len(a) > 3 and a[2] == "run":
        argvs.append(a[3:])
    return scripts, argvs

POWER_VERBS = {"suspend", "hibernate", "hybrid-sleep", "suspend-then-hibernate", "sleep", "poweroff", "reboot", "halt", "kexec",
               "soft-reboot", "emergency", "rescue"}
UNIT_VERBS = {"start", "restart", "try-restart", "reload-or-restart", "try-reload-or-restart", "isolate", "enqueue"}
POWER_UNIT = re.compile(r"^(systemd-)?(suspend|hibernate|hybrid-sleep|suspend-then-hibernate|sleep|poweroff|reboot|halt|kexec"
                        r"|soft-reboot|shutdown|emergency|rescue|final|ctrl-alt-del)(\.target|\.service)?$")
EXIT_UNIT = re.compile(r"^(systemd-)?exit(\.target|\.service)?$")
SYSTEMCTL_LONG = L(v=("--type", "--signal", "--property", "--output", "--lines", "--host", "--machine", "--state", "--kill-whom",
                      "--kill-value", "--root", "--image", "--image-policy", "--what", "--job-mode", "--preset-mode",
                      "--boot-loader-menu", "--boot-loader-entry", "--reboot-argument", "--timestamp", "--check-inhibitors",
                      "--message", "--when", "--drop-in"))
LOGIN_SESSION_VERBS = {"terminate-session", "terminate-user", "terminate-seat", "kill-session", "kill-user"}
DBUS_POWER = {"Suspend", "Hibernate", "HybridSleep", "SuspendThenHibernate", "Sleep", "PowerOff", "Reboot", "Halt", "KExec",
              "SoftReboot", "ScheduleShutdown", "Shutdown", "RequestShutdown", "RequestReboot"}
DBUS_SESSION = {"Exit", "TerminateSession", "TerminateUser", "TerminateSeat", "KillSession", "KillUser", "Logout", "logout"}
DBUS_START = {"StartUnit", "RestartUnit", "ReloadOrRestartUnit", "TryRestartUnit", "StartUnitReplace", "EnqueueUnitJob"}
SESSION_QUIT = {"gnome-session-quit", "cinnamon-session-quit", "xfce4-session-logout", "lxqt-leave", "lxsession-logout"}

def power_hit(a):
    """host power (CONST-033) and session kill, in every option spelling and front end."""
    n0, args = a[0], a[1:]
    if n0 == "systemctl":
        _s, lo, pos, dd = opt_parse(args, "tspPoHMn", SYSTEMCTL_LONG)
        units = pos + dd
        if not units:
            return None
        verb, rest = units[0], units[1:]
        if verb in POWER_VERBS or verb == "isolate": return "host-power"  # MUTANT:power-verb
        if verb == "exit": return "session-kill"
        if verb in UNIT_VERBS or (verb in ("enable", "reenable") and "--now" in lo):
            if any(EXIT_UNIT.match(u) for u in rest): return "session-kill"
            if any(POWER_UNIT.match(u) for u in rest): return "host-power"  # MUTANT:power-unit
        return None
    if n0 == "loginctl":
        _s, _l, pos, dd = opt_parse(args, "psnoHM", L(v=("--property", "--signal", "--lines", "--output", "--host", "--machine",
                                                         "--kill-whom", "--kill-value", "--when")))
        verb = (pos + dd + [""])[0]
        if verb in POWER_VERBS: return "host-power"  # MUTANT:loginctl
        if verb in LOGIN_SESSION_VERBS: return "session-kill"
        return None
    if n0 == "shutdown":
        sh, lo, _p, _d = opt_parse(args, "", L("--cancel", "--show"))
        return None if ("c" in sh or "--cancel" in lo or "--show" in lo) else "host-power"
    if n0 in ("telinit", "init") and any(x in ("0", "1", "6", "s", "S", "single", "emergency", "rescue") for x in args):
        return "host-power"
    if n0 in ("pm-suspend", "pm-hibernate", "pm-suspend-hybrid", "systemd-sleep", "zzz", "ZZZ"):
        return "host-power"
    if n0 == "rtcwake":
        sh, lo, _p, _d = opt_parse(args, "mdstA", L(v=("--mode", "--device", "--seconds", "--time", "--adjfile", "--date")))
        mode = (sh.get("m", []) + lo.get("--mode", []) + ["standby"])[0]
        return None if mode in ("no", "show", "disable", "on") else "host-power"
    if n0 in SESSION_QUIT:
        return "session-kill"
    if n0 == "mate-session-save" and any(x in ("--logout", "--force-logout", "--logout-dialog", "--shutdown-dialog") for x in args):
        return "session-kill"
    if n0 in ("busctl", "gdbus", "dbus-send", "qdbus", "qdbus6", "qdbus-qt5", "qdbus-qt6"):
        if n0 in ("busctl", "gdbus") and "call" not in args:
            return None
        if not re.search(r"login1|systemd1|SessionManager|ksmserver|ConsoleKit|PowerManagement", " ".join(args)):
            return None
        for w in args:
            last = re.split(r"[./]", w.split("=", 1)[-1])[-1]
            if last in DBUS_SESSION: return "session-kill"
            if last in DBUS_POWER: return "host-power"  # MUTANT:dbus-power
            if last in DBUS_START and any(EXIT_UNIT.match(x) for x in args): return "session-kill"
            if last in DBUS_START and any(POWER_UNIT.match(x) for x in args): return "host-power"
    return None

SIGNAMES = {"HUP", "INT", "QUIT", "ILL", "TRAP", "ABRT", "IOT", "BUS", "FPE", "KILL", "USR1", "SEGV", "USR2", "PIPE", "ALRM",
            "TERM", "STKFLT", "CHLD", "CLD", "CONT", "STOP", "TSTP", "TTIN", "TTOU", "URG", "XCPU", "XFSZ", "VTALRM", "PROF",
            "WINCH", "POLL", "IO", "PWR", "SYS", "RTMIN", "RTMAX"}

def is_signal(s):
    u = s.upper()
    u = u[3:] if u.startswith("SIG") else u
    return s.isdigit() or u in SIGNAMES or bool(re.fullmatch(r"RTM(IN|AX)[+-][0-9]+", u))

PKILL_LONG = L("--full", "--echo", "--count", "--inverse", "--lightweight", "--ignore-case", "--newest", "--oldest", "--exact",
               "--logpidfile", "--ignore-ancestors", "--require-handler", "--help", "--version",
               v=("--signal", "--pgroup", "--group", "--older", "--parent", "--session", "--terminal", "--euid", "--uid",
                  "--pidfile", "--runstates", "--cgroup", "--ns", "--nslist", "--queue", "--env"))

def kill_pids(args, ctx):
    """bash's kill builtin and util-linux kill: -> (signal, pid words) or (None, []) for list/print modes."""
    i, sig = 0, None
    while i < len(args):
        w = args[i]
        if w in ("-l", "-L", "--list", "--table", "-p", "--pid") or (w.startswith("-l") and sig is None):
            return None, []
        if w in ("-s", "-n", "--signal") and i + 1 < len(args):
            sig = args[i + 1]; i += 2; continue
        if w in ("-q", "--queue") and i + 1 < len(args):
            i += 2; continue
        if w == "--timeout" and i + 2 < len(args):
            i += 3; continue
        if w in ("-a", "--all", "--verbose", "-r", "--require-handler"):
            i += 1; continue
        if w == "--":
            i += 1; break
        if sig is None and w.startswith("-") and len(w) > 1 and is_signal(w[1:]):
            sig = w[1:]; i += 1; continue
        break
    return sig or "TERM", [expand(p, ctx) or p for p in args[i:]]

def signal_hit(a, ids, ctx):
    n0, args = a[0], a[1:]
    if n0 == "kill":
        if "signal-by-pattern" in ids and any(re.search(r"(\$\(|`)\s*(pgrep|pidof)\b", w) for w in args):
            return "signal-by-pattern"            # kill $(pgrep -f x) / kill `pidof x`: a pattern match is not a validated pid
        sig, pids = kill_pids(args, ctx)
        if sig and sig.upper().removeprefix("SIG") != "0" and any(re.fullmatch(r"-?[0-9]+", p) and int(p) < 2 for p in pids):  # MUTANT-ANCHOR:kill-all
            return "signal-all-processes"
        return None
    if n0 == "killall5":
        return "signal-all-processes"
    if n0 == "killall" and "signal-by-name" in ids:
        return "signal-by-name"
    if n0 == "pkill":
        rest = [w for w in args if not (re.fullmatch(r"-[A-Za-z0-9+]+", w) and is_signal(w[1:]))]  # -9 -TERM -SIGKILL
        sh, lo, _p, _d = opt_parse(rest, "gGOPstuUFrq", PKILL_LONG)
        if "u" in sh or "U" in sh or "--euid" in lo or "--uid" in lo: return "signal-all-processes"  # MUTANT:pkill-user
        groups = sh.get("s", []) + sh.get("g", []) + lo.get("--session", []) + lo.get("--pgroup", [])
        if any("0" in str(v).split(",") for v in groups): return "signal-all-processes"
        if ("f" in sh or "--full" in lo) and "signal-by-pattern" in ids: return "signal-by-pattern"  # MUTANT:pkill-full
    return None

def rm_root(w, ctx):
    """`w` names / , /home, $HOME or an ancestor of it, or a glob that matches one or every child of one, after the
    shell's expansions: $HOME ${HOME} ${HOME:?} ${HOME%/} $D (same-line assignment) $(pwd), ~ ~/ ~user, //, /., ~/.., /*,
    /*/, ~/.*/, /home/*/, /ho?e. A sub-path of them (`~/Projects/x/*`) is not a root."""
    h = os.path.normpath(os.environ.get("HOME") or "/nonexistent-home")
    t = expand(w, ctx)
    if t is None or t == "":
        return False
    if t == "~" or t.startswith("~/"):
        t = h + t[1:]
    elif t.startswith("~"):
        m, home_of = re.match(r"^~([A-Za-z0-9._][A-Za-z0-9._-]*)(/.*)?$", t), None
        try:
            home_of = pwd.getpwnam(m.group(1)).pw_dir if m else None
        except KeyError:
            pass
        if home_of is None:
            return False
        t = home_of + (m.group(2) or "")  # MUTANT:rm-tilde-user
    if not t.startswith("/"):
        if not ctx.get("cwd"):
            return False
        t = ctx["cwd"] + "/" + t
    t = re.sub(r"/+$", "", t) or "/"
    roots, d = {"/", "/home"}, h  # MUTANT-ANCHOR:rm-roots
    while d not in ("/", ""):
        roots.add(d); d = os.path.dirname(d)
    comps = t.split("/")
    gi = next((k for k, c in enumerate(comps) if re.search(r"[*?\[]", c)), None)
    if gi is None:
        return os.path.normpath(t) in roots  # MUTANT-ANCHOR:rm-normpath
    for r in roots:                                  # the pattern itself names a root (/ho?e, /h*)
        rc = os.path.normpath(r).split("/") if r != "/" else [""]
        if len(rc) == len(comps) and all(fnmatch.fnmatchcase(x, y) for x, y in zip(rc, comps)):
            return True
    parent = os.path.normpath("/".join(comps[:gi]) or "/")
    last = comps[gi]
    catch_all = "*" in last and all(ch in ".?" for ch in last.replace("*", ""))   # * .* ** ?* *.*
    return gi == len(comps) - 1 and parent in roots and catch_all  # MUTANT-ANCHOR:rm-glob

RM_LONG = L("--force", "--interactive", "--one-file-system", "--no-preserve-root", "--preserve-root", "--recursive", "--dir",
            "--verbose", "--help", "--version")

def struct_hit(a, ids, ctx, cfg=(), env=None, io=None):
    """The class a normalised argv (`a`: basename first, git globals stripped) belongs to, or None."""
    if not a or not a[0]:
        return None
    n0 = a[0]
    if n0 in ("sudo", "doas", "pkexec", "run0", "su") and "privilege-escalation" in ids: return "privilege-escalation"  # MUTANT:s-sudo
    for name, cid in (("reboot", "host-reboot"), ("poweroff", "host-poweroff"), ("halt", "host-halt")):
        if n0 == name and cid in ids:
            return cid
    x = power_hit(a) or signal_hit(a, ids, ctx)
    if x:
        return x
    if n0 == "rm":
        sh, lo, pos, dd = opt_parse(a[1:], "", RM_LONG)
        if ("r" in sh or "R" in sh or "--recursive" in lo) and any(rm_root(w, ctx) for w in pos + dd): return "rm-recursive-root"  # MUTANT:extra-rm-root
    if n0 == "find" and "-delete" in a:
        starts, k = [], 1
        while k < len(a):
            w = a[k]
            if w in ("-H", "-L", "-P") or re.match(r"^-O[0-9]*$", w):
                k += 1; continue
            if w == "-D":
                k += 2; continue
            if w.startswith(("-", "(", "!")):
                break
            starts.append(w); k += 1
        if any(rm_root(w, ctx) for w in starts): return "rm-recursive-root"  # MUTANT:find-delete
    if n0 == "git" and len(a) > 1:
        return git_struct(a, ids, ctx, cfg, env or {}, io or {})
    return None

def catalogue_hit(stage_texts, rules, ctx, env=None, io=None):
    """stage_texts: list of argv(text) lists for every unwrap stage."""
    ids = {id_ for id_, _rx in rules}
    for a in stage_texts:
        if not a or not a[0]:
            continue
        a = [bn(a[0])] + a[1:]  # MUTANT:basename
        t = " ".join(re.sub(r"\s", " ", x) for x in a)
        ga, _c, _w, _g, cfg = git_globals_t(a)
        for id_, rx in rules:
            if rx.pattern.startswith("-"):
                # a flag class (--no-verify, --force-with-lease) is a git OPTION, matched WHOLE (--no-verify-signatures
                # is another option): never judged on grep/rg/printf, nor on a git subcommand's values or patterns
                if ga[0] == "git" and any(rx.fullmatch(x) for x in git_flags(ga)): return id_  # MUTANT:flag-git-only
                continue
            if id_ in STRUCT_IDS:  # MUTANT-ANCHOR:struct-only
                continue           # judged structurally below, in every spelling
            m = rx.match(t)
            if not m:
                continue
            end = m.end()
            if m.group(0).endswith("/") and end < len(t) and not t[end].isspace():
                continue
            return id_
        x = struct_hit(ga, ids, ctx, cfg, env, io)
        if x:
            return x
    return None

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
        return False                     # :!x / :^x (exclude) and other short magic: judged by is_exclude
    return os.path.normpath(rest or ".") in (".", "*", "**")  # MUTANT-ANCHOR:whole-tree

HINTS = {
    "add-all": "stage named paths only: git add -- <path> <path>",
    "add-dot": "stage named paths only: git add -- <path> <path>",
    "add-all-any-spelling": "stage named paths only: git add -- <path> <path>",
    "force-push": "never force: git fetch, merge onto the latest main, then a plain git push",
    "force-with-lease": "never force: git fetch, merge onto the latest main, then a plain git push",
    "force-push-any-spelling": "never force: git fetch, merge onto the latest main, then a plain git push",
    "no-verify": "let the hooks run and fix what they report; there is no bypass (also none by core.hooksPath)",
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
    "ref-delete": "deleting refs is an operator decision: report the exact ref to the operator",
    "remote-branch-delete-refspec": "deleting a remote branch is an operator decision: report it; `git push origin :` (matching) is allowed",
    "remote-branch-delete-flag": "deleting a remote branch is an operator decision: report the exact branch to the operator",
    "rm-recursive-root": "remove a NAMED path inside your scratch dir: rm -rf -- \"${S:?}\"/<name> (an unset variable is empty in a fresh shell)",
    "remove-root": "remove a NAMED path inside your scratch dir: rm -rf -- \"$S\"/<name>",
    "remove-home": "remove a NAMED path inside your scratch dir: rm -rf -- \"$S\"/<name>",
    "signal-by-pattern": "signal one validated pid you started: kill <pid> (never by name or pattern)",
    "signal-by-name": "signal one validated pid you started: kill <pid> (never by name or pattern)",
    "signal-all-processes": "signal one validated pid you started: kill <pid> (never -1, 0, 1, a process group or all of a user's processes)",
    "privilege-escalation": "no sudo: report the step that needs root to the operator",
    "host-power": "never suspend, hibernate, power off, reboot or halt the host (CONST-033): report to the operator",
    "host-poweroff": "never suspend, hibernate, power off, reboot or halt the host (CONST-033): report to the operator",
    "host-reboot": "never suspend, hibernate, power off, reboot or halt the host (CONST-033): report to the operator",
    "host-halt": "never suspend, hibernate, power off, reboot or halt the host (CONST-033): report to the operator",
    "session-kill": "never end the desktop session or the user service manager: report to the operator",
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
BULK_SUFFIX = re.compile(r"\.(gguf|bin|safetensors|onnx|pt|pth|ckpt|tar|tgz|tbz2|txz|tzst|gz|xz|zst|bz2|zip|7z|iso|img|qcow2|vmdk|deb|rpm|whl|jar)"
                         r"(\.(part|partial|tmp|download|crdownload|incomplete|[0-9]+))?$", re.I)  # MUTANT-ANCHOR:bulk-partial

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

INSTALL_VAL = {"-m", "--mode", "-o", "--owner", "-g", "--group", "-S", "--suffix", "-t", "--target-directory"}

def r_install(c, x):
    """install(1) copies like cp: a directory or a > 64 MiB file installed into tmpfs is refused (-d only makes dirs)."""
    a = c.a
    if not a or a[0] != "install":
        return None
    args = a[1:]
    if cluster_has(args, "d") or "--directory" in args:
        return None
    tdir = opt_values(args, ("-t",), ("--target-directory",))
    pos = positionals(args, INSTALL_VAL)
    srcs, dest = (pos, tdir[-1]) if tdir else ((pos[:-1], pos[-1]) if len(pos) >= 2 else (None, None))
    if dest is None or not any(big_or_dir(c, s) for s in srcs): return None  # MUTANT:install-size
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

def url_names(args):
    urls = [w for w in args if re.match(r"^[a-z][a-z0-9+.-]*://", w)]
    return [os.path.basename(u.split("?")[0].split("#")[0].rstrip("/")) for u in urls]

def url_name(args):
    return (url_names(args) or [""])[-1]

def r_download(c, x):
    """A download's size cannot be known statically. Refused only when it lands on tmpfs AND its file name
    says bulk (a model or an archive: BULK_SUFFIX); a small page/JSON fetch into /tmp is allowed."""
    a = c.a
    if not a or a[0] not in ("curl", "wget"):
        return None
    args = a[1:]
    def bulk(path, name):                    # the TARGET's name or any URL's name says model/archive (`-o /tmp/model URL.gguf`)
        hit = is_tmpfs(path)
        hit = hit and any(BULK_SUFFIX.search(x or "") for x in [name] + url_names(args))  # MUTANT:download-suffix
        return path if hit else None
    def bulk_stdout():                        # to stdout, redirected (or piped through cat/gzip/tee) onto tmpfs
        o = c.out_tmpfs()
        return bulk(o, o) if o else None
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
    ("install", r_install),                   # BRANCH:install
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

PASSTHRU = {"cat", "tee", "gzip", "pigz", "zstd", "pzstd", "xz", "pixz", "bzip2", "pbzip2", "lz4", "lzop", "pv", "buffer", "mbuffer",
            "base64", "openssl", "gpg", "dd", "zcat", "gunzip", "unzstd", "unxz", "bunzip2"}

def pipe_sinks(items, k, ctx):
    """Files that receive command k's stdout through the pass-through filters downstream in its pipeline
    (`podman save img | gzip > /tmp/x.tgz`, `curl URL | tee /tmp/m.gguf`). A filter that is not pass-through (sha256sum,
    wc, grep) ends the data flow."""
    out, j = [], k + 1
    while j < len(items) and items[j][0] == "cmd" and items[j][4]:
        u = unwrap(items[j][1])
        a = [w["t"] for w in u["argv"]]
        if not a or bn(a[0]) not in PASSTHRU:
            break
        n0 = bn(a[0])
        out += [resolve(t["t"], ctx) for op, t in items[j][2] if op in OUT_REDIRS and t and not t["t"].isdigit() and t["t"] != "-"]
        if n0 == "tee":
            out += [resolve(x, ctx) for x in a[1:] if not x.startswith("-")]
        if n0 == "dd":
            out += [resolve(x[3:], ctx) for x in a[1:] if x.startswith("of=")]
        j += 1
    return [o for o in out if o]

def parallel_scripts(args, piped_text):
    """GNU parallel runs its command template through a shell: `parallel CMD ::: args`, `parallel ::: 'CMD' ...`, and the
    lines of its stdin when no command is given (`echo 'CMD' | parallel`)."""
    seps = {":::", "::::", ":::+", "::::+"}
    vals = {"-j", "--jobs", "-P", "--max-procs", "-S", "--sshlogin", "--sshloginfile", "--slf", "-a", "--arg-file", "--colsep",
            "-C", "-d", "--delimiter", "-E", "--eof", "-I", "-L", "--max-lines", "-n", "--max-args", "-N", "-s", "--max-chars",
            "--results", "--res", "--joblog", "--tmpdir", "--workdir", "--wd", "--timeout", "--halt", "--memfree", "--load",
            "--delay", "--retries", "--tag-string", "--env", "--basefile", "--bf", "--return", "--transferfile", "--tf",
            "--rpl", "--sshdelay", "--termseq", "--block", "--recstart", "--recend", "--header", "--nice", "--seqreplace"}
    i = 0
    while i < len(args) and args[i].startswith("-") and args[i] not in seps:
        i += 2 if args[i] in vals else 1
    cmd = []
    while i < len(args) and args[i] not in seps:
        cmd.append(args[i]); i += 1
    if cmd:
        return [" ".join(cmd)]
    after = [w for w in args[i:] if w not in seps]
    if after:
        return after
    return [l for l in (piped_text or "").split("\n") if l.strip()]

def judge_script(raw, rules, ctx, depth=0):
    """None | ("cat", id) | ("tmpfs", branch, dest, reason_given)"""
    if depth > 5:
        return None
    try:
        items = commands(lex(raw))
    except (IndexError, ValueError, RecursionError):
        return None
    for k, it in enumerate(items):
        if it[0] == "open":
            ctx["stack"].append((ctx["cwd"], ctx.get("prev"), dict(ctx["vars"]))); continue
        if it[0] == "close":
            if ctx["stack"]: ctx["cwd"], ctx["prev"], ctx["vars"] = ctx["stack"].pop()  # MUTANT:subshell-scope
            continue
        v = judge_cmd(it, rules, ctx, depth, pipe_sinks(items, k, ctx))
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

def judge_cmd(it, rules, ctx, depth, sinks=None):
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
    argv, chdirs, gwt, gdir, _cfg = git_globals(u["argv"])
    stages.append(argv)
    cctx = ctx
    if chdirs or u["chdir"]:
        cctx = sub_ctx(ctx)
        for d in ([u["chdir"]] if u["chdir"] else []) + chdirs:
            cctx["cwd"] = resolve(d, cctx)
    env = dict((k, v) for k, v in ctx["vars"].items() if isinstance(v, str))
    env.update(u["env"])
    # what the command reads on stdin: here-strings, here-documents, `echo|printf ... |`; None = unknown (a file, a program)
    stdin = [t["t"] for op, t in redirs if op == "<<<" and t] + [b for b, _dq in hds]
    if any(op in ("<", "<&", "<>") for op, _t in redirs) or (piped and not last_echo):
        stdin = None
    elif piped:
        stdin.append(last_echo)
    hit = catalogue_hit(stages, rules, cctx, env, {"stdin": stdin})
    if hit:
        return ("cat", hit)
    scripts, nargv = list(u["nested"]), list(u["nested_argv"])
    if argv and bn(argv[0]) == "git":
        gs, ga = git_nested(argv)
        scripts += gs; nargv += [[{"t": x, "q": True, "subs": []} for x in g] for g in ga]
    if argv and bn(argv[0]) == "script":      # util-linux script -c '<cmd>' / -qc / --command=
        sh_, lo_, _p, _d = opt_parse([x["t"] for x in u["argv"][1:]], "cEoTmBIO", L(v=(
            "--command", "--echo", "--output-limit", "--log-timing", "--logging-format", "--log-io", "--log-in", "--log-out")), "t")
        scripts += [v for v in sh_.get("c", []) + lo_.get("--command", []) if v]  # MUTANT:script-c
    if argv and bn(argv[0]) == "parallel": scripts += parallel_scripts([x["t"] for x in u["argv"][1:]], piped and last_echo)  # MUTANT:parallel
    for na in nargv:
        v = judge_cmd(("cmd", na, [], [], False), rules, sub_ctx(ctx), depth + 1)
        if v:
            return v
    for script in scripts:
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
    # `cat <<'EOF' | bash` / `cat <<< 'cmd' | sh`: cat passes its stdin text on
    if name == "cat" and not [t for t in a[1:] if t != "-"] and stdin: ctx["last_echo"] = "\n".join(stdin)  # MUTANT:cat-heredoc-pipe
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
    out = [resolve(t["t"], cctx) for op, t in redirs if op in OUT_REDIRS and t and not t["t"].isdigit() and t["t"] != "-"]
    if not out: out = list(sinks or [])  # stdout piped through pass-through filters into a file (`| gzip > /tmp/x`)  # MUTANT:pipe-sinks
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

# The hook runs on EVERY tool call, and compiling the ~1,900-line program costs ~30 ms per call on this host (measured
# 2026-10-14, python 3.14). LOADER keeps the compiled code in a per-user 0700 cache keyed by sha256(program + python
# version): a hit only unmarshals (~1 ms); a miss, an unreadable or corrupt entry, or one not owned by this user or
# writable by others is ignored and the source is compiled. Same trust boundary as the user's own files (whoever can
# write ~/.cache can also edit this script); GUARD_PCG_CACHE=off disables it, GUARD_PCG_CACHE_DIR moves it.
LOADER=$(cat <<'LDEOF'
import hashlib, marshal, os, stat, sys
src = os.environ.pop("GUARD_PCG_PY")
code, path = None, None
if os.environ.get("GUARD_PCG_CACHE", "on") != "off":
    d = os.environ.get("GUARD_PCG_CACHE_DIR") or os.path.join(
        os.environ.get("XDG_CACHE_HOME") or os.path.expanduser("~/.cache"), "guard-project-catalogue")
    path = os.path.join(d, hashlib.sha256((sys.version + "\0" + src).encode()).hexdigest() + ".code")
    try:
        st = os.stat(path)
        if st.st_uid == os.getuid() and not st.st_mode & (stat.S_IWGRP | stat.S_IWOTH) and stat.S_ISREG(st.st_mode):
            with open(path, "rb") as fh:
                code = marshal.loads(fh.read())
    except (OSError, ValueError, EOFError, TypeError):
        code = None
if code is None:
    code = compile(src, "guard-project-catalogue", "exec")
    if path:
        try:
            os.makedirs(os.path.dirname(path), mode=0o700, exist_ok=True)
            tmp = "%s.%d.tmp" % (path, os.getpid())
            fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
            with os.fdopen(fd, "wb") as fh:
                fh.write(marshal.dumps(code))
            os.replace(tmp, path)
            for f in os.listdir(os.path.dirname(path)):     # a miss: drop entries of older versions idle for 7 days
                q = os.path.join(os.path.dirname(path), f)
                if f.endswith((".code", ".tmp")) and q != path and os.stat(q).st_mtime < os.stat(path).st_mtime - 7 * 86400:
                    os.unlink(q)
        except OSError:
            pass
exec(code, {"__name__": "__main__", "__builtins__": __builtins__})
LDEOF
)
run_hook() { GUARD_PCG_PY="$PY" python3 -I -c "$LOADER" "$1" "$2" "$ROOT_DEFAULT"; }

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
    # Fixtures carry no host paths or names: @REPO@ = this checkout, @HOME@ = $HOME, @USER@ = the login name, @T@ = this proof's temp dir (it
    # holds small.txt and a SPARSE 65 MiB file, so the size rule is exercised without writing 65 MiB).
    printf 'x\n' >"$T/small.txt"; mkdir "$T/adir"; truncate -s 65M "$T/sparse65m" 2>/dev/null || { echo "COULD-NOT-PROVE: truncate failed"; return 2; }
    # @T@/repo: a throwaway repository where a FILE and a BRANCH share a name (loose `feature`, packed `packedbr`), so the
    # checkout-path rule is exercised against git's own refs (the hook only reads .git; it never runs git)
    { git init -q "$T/repo" && printf 'x\n' >"$T/repo/feature" && printf 'x\n' >"$T/repo/packedbr" && printf 'x\n' >"$T/repo/notes.txt" \
      && git -C "$T/repo" add -- feature packedbr notes.txt && git -C "$T/repo" -c user.email=p@p -c user.name=p commit -qm i \
      && git -C "$T/repo" branch packedbr && git -C "$T/repo" pack-refs --all && git -C "$T/repo" branch feature \
      && [ -f "$T/repo/.git/refs/heads/feature" ] && [ ! -f "$T/repo/.git/refs/heads/packedbr" ]; } >/dev/null 2>&1 || { echo "COULD-NOT-PROVE: fixture repo"; return 2; }
    probe_cwd() { # $1 command  $2 cwd ('-' = none)  [$3 python program, default the hook's]
        local j; j=$(python3 -I -c 'import json,pwd,os,sys
sub=lambda x: x.replace("@REPO@",sys.argv[3]).replace("@HOME@",sys.argv[4]).replace("@T@",sys.argv[5]).replace("@USER@",pwd.getpwuid(os.getuid()).pw_name)
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
import json, os, pwd, re, subprocess, sys
prog, cat, root, cases, only, home, tmp = sys.argv[1:8]
user = pwd.getpwuid(os.getuid()).pw_name
sub = lambda x: x.replace("@REPO@", root).replace("@HOME@", home).replace("@T@", tmp).replace("@USER@", user)
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
                    [extra-rm-root]=rev2-B12,rev2-B19 [extra-clean]=rev2-B10 [extra-checkout]=r5-B159,r5-B160 [extra-add-all]=rev2-B13
                    [extra-branch]=rev2-B18 [arith-subs]=r4-B52 [coproc-name]=r4-B50 [flag-prefix]=r4-B08,r4-B09
                    [flag-values]=r4-G30,r5-G86 [shell-env]=r4-B49 [herestring-shell]=r4-B11,r4-B12,r4-B13 [pipe-amp]=r4-B36
                    [function-restrip]=r4-B37
                    [brace-expand]=r5-B129,r5-B130,r5-B96 [cat-heredoc-pipe]=rev2-B06,r5-B144 [dbus-power]=r5-B19,r5-B20,r5-B21
                    [find-delete]=r5-B99,r5-B100 [flock-c]=r5-B116 [flock-file]=r5-B117,r5-B118
                    [heredoc-owner]=r5-B01,r5-B02,r5-B03,rev-N24 [install-size]=r5-G62 [loginctl]=r5-B17,r5-B18
                    [parallel]=r5-B122,r5-B123,r5-B124,r5-B125 [pipe-sinks]=r5-B135,r5-B140,r5-B141,r5-B142
                    [pkill-full]=r5-B65,r5-B66,r5-B67,r5-B68,r5-B69,r5-B70 [pkill-user]=r5-B43,r5-B44,r5-B46
                    [power-unit]=r5-B10,r5-B16 [power-verb]=r5-B05,r5-B06,r5-B07,r5-B08,r5-B09,r5-B13
                    [rebase-exec]=r5-B113,r5-B114,r5-B115 [rm-tilde-user]=r5-B91,r5-B92 [s-add-exclude]=r5-B101,r5-B102,r5-B108
                    [s-checkout-index]=r5-B78,r5-B79 [script-c]=r5-B119,r5-B120,r5-B121 [s-push-delete]=r5-B60,r5-B61,r5-B62,r5-B63,r5-B64
                    [s-read-tree]=r5-B80 [s-reset]=r5-B49,r5-B50,r5-B51,r5-B52,r5-B126 [s-stash]=r5-B157,r5-B158
                    [s-sudo]=r5-B154,r5-B155,r5-B156 [s-switch]=r5-B75,r5-B76,r5-B77 [submodule-foreach]=r5-B111,r5-B112
                    [s-update-ref]=r5-B53,r5-B54 [whole-tree-spelling]=r4-B18,r4-B54,r5-B106)
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
readonly-worktree|    return staged and not worktree  # MUTANT-ANCHOR:readonly-worktree|    return staged|r4-B01,r4-B02,r4-B03,r4-B04,r4-B05
env-C|                    r["chdir"] = rest[i + 1]["t"]|                    pass|own-B03
cd-minus|        if tgt == "-":|        if False:|own-G05
curl-O|        if (any(re.match(r"^-[A-Za-z]*O[A-Za-z]*$", w) for w in args)|        if False and (any(re.match(r"^-[A-Za-z]*O[A-Za-z]*$", w) for w in args)|own-B04
unzip-listmode|            return None                   # list / test / pipe / zipinfo / to-stdout modes write nothing|            pass|own-G06
export-vars|    if name in ("export", "declare", "typeset", "local", "readonly"):|    if False:|own-B05
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
hint-empty|    return HINTS.get(id_, "this is an operator decision: report the exact command and why it is needed")|    return ""|rev2-B10,rev2-B12,r4-B06,r4-B21
readonly-exemption|not readonly_git(a) and "restore-discard" in ids|"restore-discard" in ids|own-G03,own-G04,r4-G01,r4-G02,rev2-G13
stash-list-exempt|not (args and args[0] in ("list", "show")) and "stash-all" in ids|"stash-all" in ids|own-G02
flag-any-word|                if ga[0] == "git" and any(rx.fullmatch(x) for x in git_flags(ga)): return id_  # MUTANT:flag-git-only|                if any(rx.match(x) for x in a[1:]): return id_|rev2-G01,rev2-G02,rev2-G03,own-G11,r4-G03,r4-G04,r4-G05
flag-fullmatch|any(rx.fullmatch(x) for x in git_flags(ga))|any(rx.match(x) for x in git_flags(ga))|r5-G67,r5-G68,r5-G70
long-prefix|    return n.startswith("--") and len(n) >= minlen and full.startswith(n)|    return n == full|r4-B05,r4-B08,r4-B09
opt-prefix|[f for f in spec if len(name) > 2 and f.startswith(name)]  # MUTANT-ANCHOR:long-prefix|[]|r4-B19,r4-B20,r4-B22,r4-B24,r5-B51,r5-B61,r5-B74
struct-only|            if id_ in STRUCT_IDS:  # MUTANT-ANCHOR:struct-only|            if False:|r5-G69,own-G02,own-G03
heredoc-newline-bind|                    ref[0] = "\n".join(body)   # the placeholder sits in the command that owns this <<|                    ref[0] = "\n".join(body); toks.append(("H", ref))|r5-G01,r5-G02
git-global-generic|        i += 1                                   # MUTANT-ANCHOR:git-global-generic|        break|r5-B126,r5-B128
git-global-attr|"--config-env", "--attr-source",|"--config-env",|r5-B127
rm-normpath|        return os.path.normpath(t) in roots  # MUTANT-ANCHOR:rm-normpath|        return t in roots|r4-B26,r4-B28,r4-B29
rm-home-forms|    t = expand(w, ctx)|    t = w|r4-B30,r5-B87,r5-B93,r5-B95
rm-roots-slash-only|    roots, d = {"/", "/home"}, h  # MUTANT-ANCHOR:rm-roots|    roots, d = {"/"}, "/"|r4-B25,r4-B31,r4-B33
rm-glob|    return gi == len(comps) - 1 and parent in roots and catch_all  # MUTANT-ANCHOR:rm-glob|    return False|r5-B86,r5-B87,r5-B88,r5-B89,r5-B90
rm-glob-catch-all|all(ch in ".?" for ch in last.replace("*", ""))|True|r5-G81
rm-pattern-root|        if len(rc) == len(comps) and all(|        if False and all(|r5-B94
rm-unset-abort|        if op in ("?", ":?") and (v is None or (op == ":?" and v == "")):|        if False:|r5-G71
clean-needs-d|if "f" in sh or "--force" in lo or (unforced and not dry)|if ("f" in sh and "d" in sh) or "--force" in lo or (unforced and not dry)|r4-B21
clean-require-force|(unforced and not dry)|(False)|r5-B148
clean-require-force-dry|(unforced and not dry)|(unforced)|r5-G75
branch-long-only|if "D" in sh or (("d" in sh or "--delete" in lo) and force)|if "D" in sh or (("--delete" in lo) and force)|r4-B23
branch-move-existing|        if moving and pos and ref_exists(pos[-1], ctx): return "branch-force-delete"|        if moving and pos: return "branch-force-delete"|r5-G76
branch-move|        if moving and pos and ref_exists(pos[-1], ctx): return "branch-force-delete"|        if False: return "branch-force-delete"|r5-B149
whole-tree|    return os.path.normpath(rest or ".") in (".", "*", "**")  # MUTANT-ANCHOR:whole-tree|    return rest in (".", "*")|r4-B18,r4-B54,r5-B107
whole-tree-star|    return os.path.normpath(rest or ".") in (".", "*", "**")  # MUTANT-ANCHOR:whole-tree|    return os.path.normpath(rest or ".") in (".",)|r5-B106,r5-B107
whole-tree-at|    return p in ("/", ctx.get("cwd")) or bool(top) and (p == top or top.startswith(p.rstrip("/") + "/"))  # MUTANT-ANCHOR:whole-tree-at|    return False|r5-B103,r5-B104,r5-B105,r5-B109
add-update|        if ("u" in sh or "--update" in lo) and not|        if False and ("u" in sh or "--update" in lo) and not|r5-B150
add-update-pathspec|and not [p for p in ps if not is_exclude(p)]: return "add-all-any-spelling"|: return "add-all-any-spelling"|r5-G77
checkout-dashdash|"--force" in lo or dd or "--pathspec-from-file" in lo|"--force" in lo or "--pathspec-from-file" in lo|r4-G15,r5-B85
checkout-two-operands|"--pathspec-from-file" in lo or len(pos) >= 2|"--pathspec-from-file" in lo or False|r5-B81
checkout-path|(len(pos) == 1 and path_not_ref(pos[0], ctx))|False|r5-B84
checkout-not-ref|and not ref_exists(name, ctx)|and True|r5-G88,r5-G89
push-plus|                or any(r.startswith("+") and len(r) > 1 for r in refs)): return "force-push-any-spelling"  # MUTANT-ANCHOR:s-push-force|                or False): return "force-push-any-spelling"|r5-B161,r5-B162
push-matching|if any(r.startswith(":") and len(r) > 1 for r in refs)|if any(r.startswith(":") for r in refs)|r5-G69
push-refspec|if any(r.startswith(":") and len(r) > 1 for r in refs)|if False|r5-B58,r5-B59
push-repo-option|refs = (pos if "--repo" in lo else pos[1:]) + dd|refs = pos[1:] + dd|r5-B163
kill-below-two|and int(p) < 2 for p in pids)|and int(p) == -1 for p in pids)|r5-B37,r5-B38,r5-B42
kill-signal-zero|sig.upper().removeprefix("SIG") != "0" and |True and |r5-G13
kill-signal-option|        if sig is None and w.startswith("-") and len(w) > 1 and is_signal(w[1:]):|        if False:|r5-G78,r5-G79
kill-expand|[expand(p, ctx) or p for p in args[i:]]|args[i:]|r5-B152
pkill-signal-strip|rest = [w for w in args if not (re.fullmatch(r"-[A-Za-z0-9+]+", w) and is_signal(w[1:]))]|rest = list(args)|r5-G80
pkill-groups|        if any("0" in str(v).split(",") for v in groups): return "signal-all-processes"|        if False: return "signal-all-processes"|r5-B45,r5-B47
killall5|    if n0 == "killall5":|    if False:|r5-B165
bare-reboot|("reboot", "host-reboot"), ||own-B02,r5-B166
systemctl-exit|        if verb == "exit": return "session-kill"|        if False: return "session-kill"|r5-B29
systemctl-enable-now|(verb in ("enable", "reenable") and "--now" in lo)|False|r5-B151
login-session|        if verb in LOGIN_SESSION_VERBS: return "session-kill"|        if False: return "session-kill"|r5-B30,r5-B31
shutdown|        return None if ("c" in sh or "--cancel" in lo or "--show" in lo) else "host-power"|        return None|r5-B22,r5-B23
shutdown-cancel|        return None if ("c" in sh or "--cancel" in lo or "--show" in lo) else "host-power"|        return "host-power"|r5-G19
telinit|    if n0 in ("telinit", "init") and any(|    if False and any(|r5-B24
rtcwake|        return None if mode in ("no", "show", "disable", "on") else "host-power"|        return None|r5-B25
rtcwake-safe-mode|        return None if mode in ("no", "show", "disable", "on") else "host-power"|        return "host-power"|r5-G83
pm-suspend|    if n0 in ("pm-suspend", "pm-hibernate",|    if False and n0 in ("pm-suspend", "pm-hibernate",|r5-B26
session-quit|    if n0 in SESSION_QUIT:|    if False:|r5-B28
dbus-session|            if last in DBUS_SESSION: return "session-kill"|            if False: return "session-kill"|r5-B32,r5-B33
dbus-start-unit|            if last in DBUS_START and any(POWER_UNIT.match(x) for x in args): return "host-power"|            if False: return "host-power"|r5-B164
hookspath|    if hooks and "no-verify" in ids:|    if False:|r5-B145,r5-B147
config-hookspath|            if k + 1 < len(args) and not reading:|            if False:|r5-B146
update-ref-zero|        if len(pos) >= 2 and ZERO_OID.match(pos[1]): return "ref-delete"|        if False: return "ref-delete"|r5-B56
update-ref-stdin|        if "--stdin" in lo and stdin_has(|        if False and stdin_has(|r5-B55,r5-B57
filter-repo|("filter-branch", "filter-repo")|("filter-branch",)|r5-B153
parallel-stdin|    return [l for l in (piped_text or "").split("\n") if l.strip()]|    return []|r5-B125
parallel-args|    if after:|    if False:|r5-B123
bisect-run|        argvs.append(a[3:])|        pass|r5-B131
bulk-partial|r"(\.(part|r"(\.(zzpart|r5-B133
url-names|any(BULK_SUFFIX.search(x or "") for x in [name] + url_names(args))|any(BULK_SUFFIX.search(x or "") for x in [name])|r5-B132
tee-sink|        if n0 == "tee":|        if False:|r5-B135
kill-pgrep|        if "signal-by-pattern" in ids and any(re.search(|        if False and any(re.search(|r5-B170,r5-B171
passthru-stop|        if not a or bn(a[0]) not in PASSTHRU:|        if not a:|r5-G61,r5-G64,r5-G66
MUTS
    [ "$nr" -ge 8 ] && [ "$mr" -eq 0 ] && ok "P15 $nr replacement mutants each caught by a named case" || bad "P15 $mr of $nr replacement mutants undetected"
    # P14 TMPDIR on disk: "$TMPDIR"/${TMPDIR:-/tmp} resolve from the hook's own environment (disk => allowed)
    local jt; jt='{"tool_name":"Bash","tool_input":{"command":"cp -a src \"${TMPDIR:-/tmp}/x\" && cp -a src \"$TMPDIR/y\""}}'
    printf '%s' "$jt" | TMPDIR=/home/agent-disk-tmp python3 -I -c "$PY" hook "$CAT" "$ROOT_DEFAULT" 2>/dev/null; local r14a=$?
    printf '%s' "$jt" | env -u TMPDIR python3 -I -c "$PY" hook "$CAT" "$ROOT_DEFAULT" 2>/dev/null; local r14b=$?
    [ "$r14a" -eq 0 ] && [ "$r14b" -eq 2 ] && ok "P14 \$TMPDIR on disk allowed, unset TMPDIR (=> /tmp) refused" || bad "P14 rc disk=$r14a unset=$r14b"
    # L2 the compiled-code cache: a miss creates ONE entry, a hit gives the same verdict, and an entry that is corrupt or
    #    writable by others is ignored (a planted "allow everything" code object must not be loaded)
    local CD="$T/pcg-cache" l2=0 f
    lp() { printf '{"tool_name":"Bash","tool_input":{"command":"git add -A"}}' | GUARD_PCG_CACHE_DIR="$CD" run_hook hook "$CAT" 2>/dev/null; }
    lp; [ $? -eq 2 ] || l2=1
    [ "$(find "$CD" -name '*.code' | wc -l)" -eq 1 ] || l2=$((l2+2))
    lp; [ $? -eq 2 ] || l2=$((l2+4))
    f=$(find "$CD" -name '*.code' | head -1)
    printf 'garbage' >"$f"; lp; [ $? -eq 2 ] || l2=$((l2+8))
    python3 -I -c 'import marshal,sys; open(sys.argv[1],"wb").write(marshal.dumps(compile("import sys; sys.exit(0)","x","exec")))' "$f"
    chmod 0664 "$f"; lp; [ $? -eq 2 ] || l2=$((l2+16))
    [ "$l2" -eq 0 ] && ok "L2 code cache: one entry per version, same verdict on a hit, corrupt / group-writable entry ignored" || bad "L2 code cache defect mask=$l2"
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
