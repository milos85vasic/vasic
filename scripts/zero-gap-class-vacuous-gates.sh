#!/usr/bin/env bash
# zero-gap-class-vacuous-gates.sh — sweep class `vacuous-gates` (feature 010, T020).
#
# WHAT IT DETECTS
#   Gate scripts whose PASS can be reached over an EMPTY population or zero executed cases, i.e.
#   the constitution's "an absence assertion must first establish its subject set is non-empty"
#   and "a gate's population is part of its claim". Static, conservative, line-based heuristic.
#   A HIT is one of:
#     loop-enum       `for x in $(git ls-files ...|find ...|ls ...)`, `for x in <unquoted glob>`,
#                     `git ls-files|find ... | while ...`, `done < <(git ls-files|find ...)`
#     absence-assert  `[ -z "$(grep|find|git ls-files|git grep ...)" ]` (a pass when nothing matched)
#     zero-fail-pass  `[ "$fail" -eq 0 ] && exit 0|return 0` in a script that never tests a total /
#                     passed / ran counter (zero executed cases exit 0)
#     zero-count      a `grep -c` / `wc -l` count (directly, or through the variable it was assigned
#                     to) compared with 0 by -eq / == / -lt 1
#   A hit is CLEARED (not reported) when an emptiness guard sits in its region: an emptiness test
#   (-eq 0, -gt 0, -lt 1, -ge 1, -le 0, == 0, -z "..", -n "..", ! -s, empty, zero) on another line
#   within 3 lines of a refusal token (exit/return 1|2, rc=1|2, UNDET, undetermined, could not,
#   cannot, COULD-NOT, no ... found, empty population, FAIL, fatal, die, abort). Region of a loop =
#   12 lines before the loop through 12 lines after its matching `done` (for `done < <(...)` the
#   loop start is found by a backward done/for/while depth scan); of the other hits = +-12 lines.
#   For absence-assert / zero-count a refusal on the hit's own line after `&&`, or within 3 lines
#   after a hit line that opens `then`/`{`, also clears it (the empty case then fails); so does an
#   empty case RECORDED in a variable (`VAR="$VAR ..."` in the `then` branch) that a later
#   `-n "$VAR"` / `-z "$VAR"` test refuses strictly (exit/return 2, UNDET, cannot, could not).
#   A loop carries a verdict when its body holds a failure keyword or it sits in a detect_* function.
#   Comment lines and here-document bodies are skipped.
#   zero-fail-pass FIXED-BATTERY EXEMPTION: the verdict is not reported when at least one increment
#   of its failure counter is reached from STRAIGHT-LINE code (top level, or through a chain of
#   function calls - ok()/bad()/assert() - none of which sits inside a shell loop over data; a
#   `for x in a b c` literal word list is a fixed set, not data) AND the script has no skip counter
#   (skip/skipped/SKIP incremented): such a case runs on every invocation, so zero executed cases is
#   impossible. A counter reached only from inside a data loop, or a battery whose cases can all be
#   recorded as skipped, stays a finding.
#   PROOF-HELPER SETUP LOOP (fix round F2, review rev-base-A): a loop inside a PROOF HARNESS (a function
#   whose name holds prov/proof, with a `{` body or a `name() (` subshell body closed by a `)` line at
#   the indentation of its def line) is FIXTURE SETUP, not a verdict, when every verdict-keyword line
#   of its body is a setup-error propagation: `cmd || return 1` / `|| exit 1` whose command chain (the
#   line plus the &&/||/backslash continuation lines before it) runs no test ([ [[ test grep cmp diff
#   jq awk) and names no failure word. Such a loop is not reported. A loop in a proof helper that
#   JUDGES (grep -q ... || return 1, a test on a continuation line, a failure word such as check_drift,
#   a bare `return 1` under `if ! cmd`, a detect_* loop) stays a finding, and the setup shape OUTSIDE a
#   proof harness (for f in $(git ls-files); do jq . "$f" || exit 1; done) is a gate verdict and stays
#   a finding.
#
# PRECISION / RECALL (honest header, measured by hand on the live tree)
#   Recall loss (by design, conservative): any refusal token near ANY emptiness test in the region
#   clears the hit, even when that test guards a different variable; loops fed from variables
#   (`for x in $LIST`, `while read ... done <<< "$x"`) are not seen; a guard written far outside the
#   region is not seen; the fixed-battery exemption trusts one straight-line case, so a battery with
#   one fixed case plus an empty data-driven loop is not reported by zero-fail-pass. Precision loss:
#   a glob loop over a directory that is required to exist, a zero-count test inside a check whose
#   subject is guarded by other means (a `set -e` trap, a fixture built one function away), or a
#   fixture-building loop that `return 1`s on a setup error OUTSIDE a proof harness reads as a hit.
#   MEASURED 2026-09-26 (fix round F2) on the live population (62 items: 60 files + 2 non-shell gates):
#   2 findings, both read by hand: 1 real (scripts/audit/zero_findings_sweep.sh:525 - a declared
#   scanroot that does not exist is skipped by `[ -d ] || continue` and yields no row) and 1 true by
#   the rule but weak (scripts/test-setup-agents-wizard.sh:1543 - the battery has a skip counter, so
#   by the rule every case could be SKIPPED and exit 0 with zero executed; its assert_* cases are also
#   called inline, so zero executed does not arise on an ordinary run) = precision 1 real + 1 weak of 2.
#   The former false hit (scripts/zero-gap-class-doc-count-drift.sh:687, the mkrepo setup loop inside
#   its --prove-failure harness) is gone by the proof-helper rule above: live 3 -> 2. The previous round
#   measured 0.20 on zero-fail-pass (9 of 10 hits were fixed proof batteries); the exemption above
#   removed them, and the exact-body loop-procsub scan removed a cleanup loop and a stated-SKIP search
#   loop. Planted-corpus detection: 1.0 (N = 16 planted rows), a regression check of known patterns;
#   live-population recall UNMEASURED (16 planted rows incl. data-loop / skippable batteries and the
#   five judging-in-a-proof-helper shapes).
#
# POPULATION (docs/zero-gap/sweep-classes.tsv row `vacuous-gates`)
#   Every entry point named in column 3 of a `check` or `debt` row of scripts/check-registry.tsv,
#   plus every numbered gate `gate_N()` of scripts/pre-push-gates.sh: a gate whose whole body runs
#   ONE shell file under "$ROOT/" contributes that file; any other gate (a multi-step body, `go test`,
#   Playwright) is the typed item `scripts/pre-push-gates.sh:gate_N` and is COULD-NOT-INSPECT
#   ("non-shell gate"), never silently dropped. Restricted to paths that exist under --root in any
#   form and lie outside _tests/fixtures/zero-gap/; a symlink or special file is an item that is
#   COULD-NOT-INSPECT (never read, never followed). A row whose file does not exist is left to
#   scripts/verify-check-registry.sh (R3), not this class.
#   With --corpus <dir>: every non-directory entry under <dir> (non-regular => COULD-NOT-INSPECT),
#   locations relative to it.
#
# OUTPUT (class contract, docs/zero-gap/README.md): FINDING / COULD-NOT-INSPECT / INSPECTED /
#   POPULATION-SHA; INSPECTED and POPULATION-SHA are printed on every rc of an inspection run.
#   Finding: severity high, category false-evidence, location <path>:<line>.
# EXIT: 0 no finding over a full non-empty population; 1 at least one finding; 2 could not
#   determine (empty population, missing registry, --root not a directory, missing tool, a non-shell
#   gate, a non-regular item). A finding outranks an undetermined; an empty population is never clean.
# DOES NOT SEE: guards in other files (a sourced library), gates written in Python/JS/Go (reported
#   COULD-NOT-INSPECT when they are pre-push gates), loops driven by variables, and a gate that is
#   vacuous because a *different* file feeds it.
# Usage: --root <dir> [--corpus <dir>] [--emit-population] | --prove-failure
set -uo pipefail

# >>> zg_pct_encode (feature 010 class contract; copy verbatim)
# zg_pct_encode_z: NUL-separated raw items on stdin -> one canonical token per line.
# Every byte outside A-Z a-z 0-9 . _ ~ / + : @ , = - becomes %XX (uppercase hex).
zg_pct_encode_z() {
    LC_ALL=C od -An -v -tx1 | LC_ALL=C awk '
        BEGIN { hx = "0123456789abcdef"; safe = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._~/+:@,=-"; tok = ""; pending = 0 }
        { for (i = 1; i <= NF; i++) {
              if ($i == "00") { print tok; tok = ""; pending = 0; continue }
              pending = 1
              v = (index(hx, substr($i, 1, 1)) - 1) * 16 + index(hx, substr($i, 2, 1)) - 1
              c = (v > 32 && v < 127) ? sprintf("%c", v) : ""
              if (c != "" && index(safe, c) > 0) tok = tok c; else tok = tok "%" toupper($i)
          } }
        END { if (pending) print tok }'
}
# zg_pct_encode <string>: one item -> one canonical token.
zg_pct_encode() { printf '%s\0' "$1" | zg_pct_encode_z; }
# <<< zg_pct_encode

CLASS_ID=vacuous-gates
SELF_PATH=${BASH_SOURCE[0]}

# analyze_file <file> -> lines "<lineno>\t<kind>" for every unguarded hit
analyze_file() {
    LC_ALL=C awk '
    function isfail(s) { return (s ~ /exit[ \t]+[12]([^0-9]|$)|return[ \t]+[12]([^0-9]|$)|rc=[12]([^0-9]|$)|UNDET|undetermin|[Cc]ould not|[Cc]annot|CANNOT|COULD-NOT|[Nn]o .* found|empty population|FAIL|fatal|die |abort|bad /) }
    function isstrict(s) { return (s ~ /exit[ \t]+[12]([^0-9]|$)|return[ \t]+[12]([^0-9]|$)|rc=[12]([^0-9]|$)|UNDET|undetermin|[Cc]ould not|[Cc]annot|COULD-NOT/) }
    function isempty(s) { return (s ~ /-eq[ \t]+0|-gt[ \t]+0|-lt[ \t]+1|-ge[ \t]+1|-le[ \t]+0|==[ \t]*0|![ \t]+-s|(\[|\[\[|test)[ \t]+!?[ \t]*-[zn][ \t]+["$]|[Ee]mpty|[Zz]ero/) }
    function guarded(lo, hi, self,   j, k) {
        if (lo < 1) lo = 1
        if (hi > n) hi = n
        for (j = lo; j <= hi; j++) {
            if (j == self || skip[j] || !isempty(L[j])) continue
            for (k = j - 3; k <= j + 3; k++) if (k >= 1 && k <= n && !skip[k] && isfail(L[k])) return 1
        }
        return 0
    }
    function verdictbody(lo, hi,   j, f) {
        if (lo < 1) lo = 1
        if (hi > n) hi = n
        for (j = lo; j <= hi; j++) if (!skip[j] && L[j] ~ /exit[ \t]+1|return[ \t]+1|FAIL|[Ff]ail|[Bb]ad |assert|[Ff]inding|[Vv]iolation|[Mm]ismatch|DRIFT|[Dd]rift|ERR|[Mm]issing/) return 1
        # a loop inside a function named detect_* (a detector: its printed rows ARE the findings)
        # carries a verdict even without a failure keyword. Measured 2026-09-26: widening this to
        # check_/verify_/scan_/gate_ added 3 hand-read false hits and no real one, so it stays narrow.
        f = fnof(lo)
        if (f ~ /^detect[_-]/) return 1
        return 0
    }
    # inproof <line>: the line sits inside a PROOF HARNESS — a function named *prov*/*proof* with a
    # `{` body (fnof chain) or a `name() (` subshell body (PR_ ranges, closed by a `)` line at the
    # indentation of the def line)
    function inproof(j,   k) {
        for (k = 1; k <= npr; k++) if (PS_[k] <= j && j <= PE_[k]) return 1
        for (k = 1; k <= nfn; k++) if (FS_[k] <= j && j <= FE_[k] && FN_[k] ~ /prov|proof/) return 1
        return 0
    }
    # setuploop <lo> <hi>: 1 when the loop is FIXTURE SETUP inside a proof harness, not a verdict:
    # every verdict-keyword line of its body is a setup-error propagation — `cmd || return 1` /
    # `|| exit 1` whose command chain (the line plus the && / || / \ continuation lines before it)
    # runs no test ([ [[ test grep cmp diff jq awk) and names no failure word. A loop that judges
    # anything (grep -q ... || return 1) stays a verdict. Fix round F2 (review rev-base-A): the
    # mkrepo helper of zero-gap-class-doc-count-drift.sh --prove-failure read as a vacuous gate.
    function setuploop(lo, hi,   j, k, t, nv) {
        if (!inproof(lo)) return 0
        if (lo < 1) lo = 1
        if (hi > n) hi = n
        nv = 0
        for (j = lo; j <= hi; j++) {
            if (skip[j] || L[j] !~ /exit[ \t]+1|return[ \t]+1|FAIL|[Ff]ail|[Bb]ad |assert|[Ff]inding|[Vv]iolation|[Mm]ismatch|DRIFT|[Dd]rift|ERR|[Mm]issing/) continue
            nv++
            if (L[j] ~ /FAIL|[Ff]ail|[Bb]ad |assert|[Ff]inding|[Vv]iolation|[Mm]ismatch|DRIFT|[Dd]rift|ERR|[Mm]issing/) return 0
            t = unq(L[j])
            if (t !~ /\|\|[ \t]*(return|exit)[ \t]+1([^0-9]|$)/) return 0
            for (k = j; k >= lo; k--) {
                if (k < j && (skip[k] || unq(L[k]) !~ /(&&|\|\||\\)[ \t]*$/)) break
                if (unq(L[k]) ~ /(^|[ \t;&|(!{])(\[|\[\[|test|grep|cmp|diff|jq|awk)([ \t]|$)/) return 0
            }
        }
        return (nv > 0)
    }
    # loopstart <line of `done`> -> the line that opens the loop closed there (backward depth scan)
    function loopstart(i,   j, d, t, m) {
        d = 0
        for (j = i; j >= 1 && j >= i - 400; j--) {
            if (skip[j]) continue
            t = unq(L[j])
            m = gsub(/(^|[;&|( \t])done([ \t;&|)<>]|$)/, "&", t); d += m
            t = unq(L[j])
            m = gsub(/(^|[;&|( \t])(for|while|until)[ \t]/, "&", t); d -= m
            if (d <= 0) return j
        }
        return (i - 30 < 1 ? 1 : i - 30)
    }
    function loopend(start,   j, d, t, m) {
        d = 0
        for (j = start; j <= n; j++) {
            if (skip[j]) continue
            t = L[j]
            m = gsub(/(^|[;&|( \t])(for|while|until)[ \t]/, "&", t); d += m
            t = L[j]
            m = gsub(/(^|[;&|( \t])done([ \t;&|)]|$)/, "&", t); d -= m
            if (d <= 0) return j
        }
        return n
    }
    function passnear(i,   k) {
        for (k = i; k <= i + 3 && k <= n; k++) if (!skip[k] && L[k] ~ /PASS|✅|exit[ \t]+0|[Pp]ass/) return 1
        return 0
    }
    function condguard(i,   k) {
        if (L[i] ~ /&&.*(exit|return|UNDET|undetermin|[Cc]ould not|[Cc]annot|COULD-NOT|rc=)/ && isstrict(L[i])) return 1
        if (L[i] ~ /(then|\{)[ \t]*$/ || L[i] ~ /;[ \t]*then/) for (k = i + 1; k <= i + 3 && k <= n; k++) if (!skip[k] && isstrict(L[k])) return 1
        if (recorded(i)) return 1
        return 0
    }
    # recorded <hit line>: the empty case is RECORDED in a variable (VAR="...$VAR..." in the next
    # 3 lines of a `then` branch) and a later `-n "$VAR"` test is followed within 3 lines by a
    # strict refusal (exit/return 2, UNDET, cannot, could not, COULD-NOT) — the emptiness is refused
    # later instead of passing
    function recorded(i,   k, v, t, j, m) {
        if (L[i] !~ /(then|\{)[ \t]*$/ && L[i] !~ /;[ \t]*then/) return 0
        for (k = i + 1; k <= i + 3 && k <= n; k++) {
            if (skip[k]) continue
            if (!match(L[k], /^[ \t]*[A-Za-z_][A-Za-z_0-9]*=/)) continue
            v = substr(L[k], RSTART, RLENGTH); sub(/^[ \t]*/, "", v); sub(/=$/, "", v)
            if (index(L[k], "$" v) == 0 && index(L[k], "${" v) == 0) continue
            for (j = k + 1; j <= n; j++) {
                if (skip[j]) continue
                t = L[j]
                if (index(t, "-n \"$" v "\"") == 0 && index(t, "-n \"${" v "}\"") == 0 && index(t, "-z \"$" v "\"") == 0 && index(t, "-z \"${" v "}\"") == 0) continue
                for (m = j; m <= j + 3 && m <= n; m++) if (!skip[m] && isstrict(L[m])) return 1
            }
        }
        return 0
    }
    # strip quoted strings so braces inside them are not counted
    function unq(s) { gsub(/"([^"\\]|\\.)*"/, "\"\"", s); gsub(/\x27[^\x27]*\x27/, "\x27\x27", s); return s }
    # braceend <def line> -> the line that closes the function body opened on/after it
    function braceend(i,   j, d, t, o, c, opened) {
        d = 0; opened = 0
        for (j = i; j <= n && j <= i + 2000; j++) {
            if (skip[j]) continue
            t = unq(L[j]); gsub(/\$\{[^}]*\}/, "", t)
            o = gsub(/\{/, "{", t); c = gsub(/\}/, "}", t)
            if (o > 0) opened = 1
            d += o - c
            if (opened && d <= 0) return j
        }
        return i
    }
    # fnof <line> -> name of the innermost function whose body holds the line ("" = top level)
    function fnof(j,   k, best, bs) {
        best = ""; bs = 0
        for (k = 1; k <= nfn; k++) if (FS_[k] <= j && j <= FE_[k] && FS_[k] >= bs) { best = FN_[k]; bs = FS_[k] }
        return best
    }
    function indataloop(j,   k) {
        for (k = 1; k <= nlp; k++) if (LD_[k] && LS_[k] <= j && j <= LE_[k]) return 1
        return 0
    }
    # casesites <fail var>: 1 when at least one increment of the counter is reached from STRAIGHT-LINE
    # code (top level, or through a chain of function calls none of which sits inside a loop over
    # data). Such a case runs on every invocation, so "zero executed cases" is impossible. Paths
    # through a data loop are not counted. Sets nsites.
    function casesites(v,   j, k, q, head, tail, f, c, re, depth, seen, rest, cnt) {
        head = 0; tail = 0; nsites = 0
        re = "(^|[^A-Za-z_0-9])" v "=\\$\\(\\([ \t]*\\$?\\{?" v "\\}?[ \t]*\\+|\\(\\([ \t]*" v "[ \t]*(\\+\\+|\\+=)|let[ \t]+\"?" v "(\\+\\+|\\+=)"
        for (j = 1; j <= n; j++) if (!skip[j] && L[j] ~ re) { Q[++tail] = j; QD[tail] = 0 }
        if (tail == 0) return 0
        while (head < tail) {
            j = Q[++head]; depth = QD[head]
            if (indataloop(j)) continue
            f = fnof(j)
            if (f == "") { nsites++; continue }
            if (depth >= 6) continue
            if (seen[f]++) continue
            cnt = 0
            re = "(^|[;&|({ \t!])" f "([ \t;&|)]|$)"
            for (c = 1; c <= n; c++) {
                if (skip[c] || c == FDEF[f]) continue
                if (unq(L[c]) !~ re) continue
                if (FDEF[f] <= c && c <= FEND[f]) continue
                Q[++tail] = c; QD[tail] = depth + 1; cnt++
            }
        }
        return (nsites > 0)
    }
    { L[NR] = $0 }
    END {
        n = NR
        term = ""
        for (i = 1; i <= n; i++) {
            skip[i] = 0
            if (term != "") { skip[i] = 1; t = L[i]; sub(/^[ \t]+/, "", t); sub(/[ \t]+$/, "", t); if (t == term) term = ""; continue }
            if (L[i] ~ /^[ \t]*#/) { skip[i] = 1; continue }
            if (L[i] ~ /<<-?[ \t]*["\x27]?[A-Za-z_][A-Za-z_0-9]*["\x27]?/ && L[i] !~ /<<</) {
                t = L[i]; sub(/^.*<<-?[ \t]*["\x27]?/, "", t); sub(/["\x27]?[^A-Za-z_0-9].*$/, "", t); sub(/["\x27]?$/, "", t)
                if (t != "") term = t
            }
        }
        # function spans and loops (used by the zero-fail-pass fixed-case exemption)
        nfn = 0
        for (i = 1; i <= n; i++) {
            if (skip[i]) continue
            if (L[i] ~ /^[ \t]*(function[ \t]+)?[A-Za-z_][A-Za-z_0-9:.-]*[ \t]*\(\)[ \t]*(\{|$)/ || L[i] ~ /^[ \t]*function[ \t]+[A-Za-z_][A-Za-z_0-9:.-]*[ \t]*\{/) {
                nm = L[i]; sub(/^[ \t]*(function[ \t]+)?/, "", nm); sub(/[ \t]*(\(|\{).*$/, "", nm)
                nfn++; FN_[nfn] = nm; FS_[nfn] = i; FE_[nfn] = braceend(i); FDEF[nm] = i; FEND[nm] = FE_[nfn]
            }
        }
        # proof harnesses written as `name() (` subshell bodies (not in FN_: the fixed-battery
        # exemption reads `{` functions only)
        npr = 0
        for (i = 1; i <= n; i++) {
            if (skip[i] || L[i] !~ /^[ \t]*(function[ \t]+)?[A-Za-z_][A-Za-z_0-9:.-]*[ \t]*\(\)[ \t]*\([ \t]*$/) continue
            nm = L[i]; sub(/^[ \t]*(function[ \t]+)?/, "", nm); sub(/[ \t]*\(.*$/, "", nm)
            if (nm !~ /prov|proof/) continue
            ind = L[i]; sub(/[^ \t].*$/, "", ind)
            for (j = i + 1; j <= n; j++) if (!skip[j] && substr(L[j], 1, length(ind) + 1) == ind ")" && L[j] ~ /^[ \t]*\)[ \t]*$/) break
            npr++; PS_[npr] = i; PE_[npr] = (j <= n ? j : n)
        }
        nlp = 0
        for (i = 1; i <= n; i++) {
            if (skip[i]) continue
            if (unq(L[i]) !~ /(^|[;&|( \t])(for|while|until)([ \t(]|$)/) continue
            # a SHELL loop: `do` on this or the next line and a matching `done` (an awk/perl `for (`
            # inside an embedded program is not a shell loop and must not swallow the file)
            if (unq(L[i]) !~ /(^|[;& \t])do([ \t;]|$)/ && !(i < n && unq(L[i + 1]) ~ /^[ \t]*do([ \t;]|$)/)) continue
            e = loopend(i)
            if (unq(L[e]) !~ /(^|[;&|( \t])done([ \t;&|)<>]|$)/) continue
            nlp++; LS_[nlp] = i; LE_[nlp] = e; LD_[nlp] = 1
            t = unq(L[i])
            if (t ~ /(^|[;&|( \t])for[ \t]+[A-Za-z_][A-Za-z_0-9]*[ \t]+in[ \t]/ && t !~ /(^|[;&|( \t])(while|until)[ \t]/) {
                g = L[i]; sub(/^.*(^|[;&|( \t])for[ \t]+[A-Za-z_][A-Za-z_0-9]*[ \t]+in[ \t]+/, "", g); sub(/;[ \t]*do.*$/, "", g); sub(/[ \t]+do([ \t].*)?$/, "", g)
                # a literal word list (no expansion, no glob, no substitution) is a fixed set of cases
                if (g !~ /[$`*?[]/ && g != "") LD_[nlp] = 0
            }
        }
        skipcnt = 0
        for (i = 1; i <= n; i++) if (!skip[i] && L[i] ~ /(^|[^A-Za-z_0-9])(skip|skipped|skips|SKIP|SKIPPED|SKIPS|nskip|n_skip|N_SKIP)=\$\(\(|\(\([ \t]*(skip|skipped|skips|SKIP|SKIPPED|SKIPS|nskip|n_skip|N_SKIP)[ \t]*(\+\+|\+=)/) skipcnt = 1
        hascnt = 0
        for (i = 1; i <= n; i++) if (!skip[i] && L[i] ~ /\$\{?(TOTAL|total|passed|PASS|pass|ran|cases|ncases|checked|inspected|count|nrun|executed|nchecks|ok)\}?"?[ \t]+-(gt|ge|lt|le|eq|ne)[ \t]+[0-9]/) hascnt = 1
        for (i = 1; i <= n; i++) {
            if (skip[i]) continue
            line = L[i]
            if (line ~ /\$\{?(fail|failed|fails|FAIL|FAILS|failures|FAILURES|errors|nfail|bad)\}?"?[ \t]+-eq[ \t]+0/ && line ~ /(exit|return)[ \t]+0/ && !hascnt) {
                fv = line; match(fv, /\$\{?(fail|failed|fails|FAIL|FAILS|failures|FAILURES|errors|nfail|bad)\}?"?[ \t]+-eq/); fv = substr(fv, RSTART, RLENGTH); gsub(/[${}" \t]|-eq/, "", fv)
                # EXEMPT: a fixed battery — every increment of the counter is reached only through
                # straight-line calls (no loop over data) and no case can be recorded as skipped,
                # so zero executed cases is impossible
                if (!skipcnt && casesites(fv)) continue
                print i "\t" "zero-fail-pass"; continue
            }
            q = line; gsub(/"[^"]*"/, "\"\"", q); gsub(/\x27[^\x27]*\x27/, "\x27\x27", q)
            kind = ""
            if (line ~ /(^|[ \t;&|(])for[ \t]+[A-Za-z_][A-Za-z_0-9]*[ \t]+in[ \t]/) {
                if (line ~ /(\$\(|`)[ \t]*(git([ \t]+-C[ \t]+[^ \t]+)?[ \t]+(ls-files|grep)|find[ \t]|ls[ \t]|ls\))/) kind = "loop-enum"
                else { g = q; match(g, /for[ \t]+[A-Za-z_][A-Za-z_0-9]*[ \t]+in[ \t]+/); g = substr(g, RSTART + RLENGTH); sub(/;.*$/, "", g); if (g ~ /[*?]/ && g !~ /\$\(/) kind = "loop-glob" }
                if (kind != "") { e = loopend(i); if (verdictbody(i, e) && !setuploop(i, e) && !guarded(i - 12, e + 12, i)) print i "\t" kind }
                continue
            }
            if (line ~ /(git([ \t]+-C[ \t]+[^ \t]+)?[ \t]+ls-files|(^|[ \t;&|(])find[ \t])[^|]*\|[ \t]*while[ \t]/) {
                e = loopend(i); if (verdictbody(i, e) && !setuploop(i, e) && !guarded(i - 12, e + 12, i)) print i "\t" "loop-pipe"
                continue
            }
            if (line ~ /(^|[ \t;&|(])done[ \t]*<[ \t]*<\((git|find)/) {
                ls = loopstart(i)
                if (verdictbody(ls, i) && !setuploop(ls, i) && !guarded(ls - 12, i + 12, i)) print i "\t" "loop-procsub"
                continue
            }
            if (line ~ /(^|[ \t;&|(])while[ \t].*<\((git([ \t]+-C[ \t]+[^ \t]+)?[ \t]+ls-files|find[ \t])/) {
                e = loopend(i); if (verdictbody(i, e) && !setuploop(i, e) && !guarded(i - 12, e + 12, i)) print i "\t" "loop-procsub"
                continue
            }
            if (line ~ /-z[ \t]+"?\$\(/ && line ~ /(find[ \t]|git([ \t]+-C[ \t]+[^ \t]+)?[ \t]+(ls-files|grep)|grep[ \t])/) {
                if (!condguard(i) && !guarded(i - 12, i + 12, i)) print i "\t" "absence-assert"
                continue
            }
            asg = ""
            if (match(line, /^[ \t]*[A-Za-z_][A-Za-z_0-9]*=\$\(/) && line ~ /(grep[ \t]+-[A-Za-z]*c|wc[ \t]+-l)/) {
                v = line; sub(/^[ \t]*/, "", v); sub(/=.*$/, "", v); cnt[v] = 1
            }
            zt = (line ~ /-eq[ \t]+0([^0-9]|$)|==[ \t]*0([^0-9]|$)|-lt[ \t]+1([^0-9]|$)|(\[|\[\[)[^]]*[^!<>=]=[ \t]*0([^0-9]|$)/)
            if (zt) {
                hit = 0
                if (line ~ /(grep[ \t]+-[A-Za-z]*c|wc[ \t]+-l)/) hit = 1
                else for (v in cnt) if (index(line, "$" v) > 0 || index(line, "${" v "}") > 0) hit = 1
                if (hit && passnear(i) && !condguard(i) && !guarded(i - 12, i + 12, i)) print i "\t" "zero-count"
            }
        }
    }' "$1"
}

kind_desc() {
    case "$1" in
        loop-enum)      echo "loop over a git ls-files/find/ls enumeration passes on an empty population: no rc-2 refusal keyed on the count of items walked" ;;
        loop-glob)      echo "loop over an unquoted glob passes when nothing matches: no rc-2 refusal keyed on the count of items walked" ;;
        loop-pipe)      echo "git ls-files/find piped into while passes on an empty population: no rc-2 refusal keyed on the count of items walked" ;;
        loop-procsub)   echo "while loop fed from git ls-files/find passes on an empty population: no rc-2 refusal keyed on the count of items walked" ;;
        absence-assert) echo "absence assertion on an empty command substitution passes when the subject set is empty: subject set never shown non-empty" ;;
        zero-fail-pass) echo "the verdict is 'no failures counted => exit 0' and the script never tests a count of cases run: zero executed cases exit 0" ;;
        zero-count)     echo "a zero count of an enumeration is accepted as the pass condition: no rc-2 refusal for an empty subject set" ;;
        *)              echo "vacuous pass path" ;;
    esac
}

EMPTY_SHA=e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855   # sha256 of the empty population
ROOT="" CORPUS="" EMIT=0 PROVE=0
# fail_early <part> <reason>: nothing could be enumerated; an inspection run still prints INSPECTED
# and POPULATION-SHA (of the empty set) so every rc carries the full contract; --emit-population
# prints nothing on stdout and exits 2
fail_early() {
    if [ "$EMIT" -eq 1 ]; then echo "COULD-NOT-INSPECT $1 $2" >&2; exit 2; fi
    echo "COULD-NOT-INSPECT $1 $2"; echo "INSPECTED 0"; echo "POPULATION-SHA $EMPTY_SHA"; exit 2
}
while [ $# -gt 0 ]; do
    case "$1" in
        --root) ROOT="${2:-}"; shift 2 ;;
        --corpus) CORPUS="${2:-}"; shift 2 ;;
        --emit-population) EMIT=1; shift ;;
        --prove-failure) PROVE=1; shift ;;
        *) fail_early arguments "unknown argument (only --root --corpus --emit-population --prove-failure are accepted)" ;;
    esac
done

need_tools() {
    local t
    for t in awk sed sort sha256sum od mktemp; do
        command -v "$t" >/dev/null 2>&1 || { NEED_MISSING=$t; return 1; }
    done
    return 0
}

decode() { printf '%b' "$(printf '%s' "$1" | sed 's/%\([0-9A-F][0-9A-F]\)/\\x\1/g')"; }

# gate_items <pre-push-gates.sh> -> "F<TAB><path>" for a numbered gate whose whole body runs ONE
# shell entry point under "$ROOT/", else "G<TAB>gate_N<TAB><runner>" (a gate whose verdict comes
# from a non-shell runner such as `go test` or Playwright, which this analyser cannot read)
gate_items() {
    LC_ALL=C awk '
        function flush(   b, nref, t, r, runner) {
            if (name == "") return
            b = body; nref = 0; t = b
            while (match(t, /"\$ROOT\/[^"]+"/)) { r = substr(t, RSTART + 7, RLENGTH - 8); nref++; t = substr(t, RSTART + RLENGTH) }
            runner = ""
            if (b ~ /go[ \t]+test/) runner = "go-test"
            else if (b ~ /playwright/) runner = "Playwright"
            else if (b ~ /(^|[ \t;(])(npx|node|python3?|ruby|go[ \t]+run)[ \t]/) runner = "non-shell-command"
            if (nref == 1 && runner == "" && r ~ /\.sh$/) print "F\t" r
            else print "G\t" name "\t" (runner == "" ? "multi-step-body" : runner)
            name = ""; body = ""
        }
        /^gate_[0-9]+\(\)/ {
            flush(); name = $0; sub(/\(\).*$/, "", name); body = $0
            if ($0 ~ /\}[ \t]*$/) flush()
            next
        }
        name != "" { body = body "\n" $0; if ($0 ~ /^\}/) flush() }
        END { flush() }' "$1"
}

# raw_items -> NUL-separated relative paths of the population (file items only)
raw_items() {
    local p reg
    if [ -n "$CORPUS" ]; then
        ( cd "$CORPUS" && find . ! -type d -print0 ) | sed -z 's|^\./||'
        return 0
    fi
    reg="$ROOT/scripts/check-registry.tsv"
    {
        LC_ALL=C awk -F'\t' '/^#/ || NF < 3 { next } $1 == "check" || $1 == "debt" { print $3 }' "$reg"
        [ -f "$ROOT/scripts/pre-push-gates.sh" ] && [ ! -L "$ROOT/scripts/pre-push-gates.sh" ] && gate_items "$ROOT/scripts/pre-push-gates.sh" | awk -F'\t' '$1 == "F" { print $2 }'
    } | LC_ALL=C sort -u | while IFS= read -r p; do
        case "$p" in ''|/*|*..*|./*|_tests/fixtures/zero-gap/*) continue ;; esac
        # a named path that exists in ANY form (a symlink or special file too) is a population item;
        # the inspection refuses to read anything but a regular file
        if [ -e "$ROOT/$p" ] || [ -L "$ROOT/$p" ]; then printf '%s\0' "$p"; fi
    done
}

# gate_tokens -> one `scripts/pre-push-gates.sh:gate_N` token per non-shell gate (live mode only)
gate_tokens() {
    [ -z "$CORPUS" ] || return 0
    [ -f "$ROOT/scripts/pre-push-gates.sh" ] && [ ! -L "$ROOT/scripts/pre-push-gates.sh" ] || return 0
    gate_items "$ROOT/scripts/pre-push-gates.sh" | awk -F'\t' '$1 == "G" { print "scripts/pre-push-gates.sh:" $2 "\t" $3 }'
}

if [ "$PROVE" -eq 0 ]; then
    if [ -z "$ROOT" ] || [ ! -d "$ROOT" ]; then fail_early root "--root is not a directory"; fi
    if [ -n "$CORPUS" ] && [ ! -d "$CORPUS" ]; then fail_early corpus "--corpus is not a directory"; fi
    need_tools || fail_early "tool:$NEED_MISSING" "required tool is not on PATH"
    if [ -z "$CORPUS" ] && [ ! -f "$ROOT/scripts/check-registry.tsv" ]; then
        fail_early scripts/check-registry.tsv "the registry that names the population is absent"
    fi
    declare -A GATE_RUNNER=()
    while IFS=$'\t' read -r gt gr; do [ -n "$gt" ] && GATE_RUNNER[$gt]=$gr; done < <(gate_tokens)
    tokens=$( { raw_items | zg_pct_encode_z; for gt in "${!GATE_RUNNER[@]}"; do printf '%s\n' "$gt"; done; } | awk 'NF' | LC_ALL=C sort -u)
    if [ "$EMIT" -eq 1 ]; then [ -n "$tokens" ] && printf '%s\n' "$tokens"; exit 0; fi
    base=${CORPUS:-$ROOT}
    sha=$(if [ -n "$tokens" ]; then printf '%s\n' "$tokens" | sha256sum | cut -d' ' -f1; else echo "$EMPTY_SHA"; fi)
    if [ -z "$tokens" ]; then
        echo "COULD-NOT-INSPECT population the population is empty: no registered entry point exists under the root"
        echo "INSPECTED 0"; echo "POPULATION-SHA $sha"; exit 2
    fi
    n=0 found=0 undet=0
    while IFS= read -r tok; do
        [ -n "$tok" ] || continue
        if [ -n "${GATE_RUNNER[$tok]:-}" ]; then
            echo "COULD-NOT-INSPECT $tok non-shell gate: its verdict comes from ${GATE_RUNNER[$tok]} (not a single shell entry point), which this line-based shell analyser cannot read"
            undet=1; continue
        fi
        p=$(decode "$tok")
        if [ -L "$base/$p" ] || [ ! -f "$base/$p" ]; then echo "COULD-NOT-INSPECT $tok not a regular file (a symlink or special file): not read and never followed"; undet=1; continue; fi
        if [ ! -r "$base/$p" ]; then echo "COULD-NOT-INSPECT $tok file is not readable"; undet=1; continue; fi
        n=$((n + 1))
        hits=$(analyze_file "$base/$p") || { echo "COULD-NOT-INSPECT $tok the analyser failed on this file"; undet=1; continue; }
        while IFS=$'\t' read -r ln kind; do
            [ -n "$ln" ] || continue
            echo "FINDING $CLASS_ID high false-evidence $tok:$ln $(kind_desc "$kind") $tok:$ln"
            found=$((found + 1))
        done <<<"$hits"
    done <<<"$tokens"
    echo "INSPECTED $n"
    echo "POPULATION-SHA $sha"
    [ "$found" -gt 0 ] && exit 1
    [ "$undet" -gt 0 ] && exit 2
    exit 0
fi

# ------------------------------------------------------------------ --prove-failure
# Paired proof on THROWAWAY copies only (mktemp + trap). It runs the TRACKED corpus (copied) and
# requires the planted findings to equal expect.tsv exactly and the clean corpus to be silent, so a
# mutation that disables any one detector (loop-procsub, heredoc skipping, the fixed-battery
# exemption, the recorded-then-refused clearance, ...) fails this proof.
HERE=$(cd "$(dirname "$SELF_PATH")/.." && pwd)
SELF_ABS="$HERE/scripts/$(basename "$SELF_PATH")"
pass=0 fail=0
ok() { pass=$((pass + 1)); printf 'PASS %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf 'FAIL %s\n' "$1"; }
need_tools || { echo "COULD-NOT-INSPECT tool:$NEED_MISSING a required tool is missing"; exit 2; }
for t in git timeout mkfifo xargs; do command -v "$t" >/dev/null 2>&1 || { echo "COULD-NOT-INSPECT tool:$t required tool is not on PATH"; exit 2; }; done
PT=$(mktemp -d "${TMPDIR:-/tmp}/zg-vacuous.XXXXXX") || { echo "COULD-NOT-INSPECT tmp cannot create a scratch directory"; exit 2; }
trap 'rm -rf "$PT"' EXIT
# live_sum: the live tree's status AND the CONTENT of every modified/untracked file (porcelain alone
# misses a second write to an already-modified file); submodules are not walked
live_sum() {
    ( cd "$HERE" && {
        git --no-optional-locks status --porcelain=v1 -z --ignore-submodules=all 2>/dev/null
        git --no-optional-locks ls-files -z -m -o --exclude-standard 2>/dev/null | xargs -0 -r sha256sum -- 2>/dev/null
        sha256sum scripts/check-registry.tsv 2>/dev/null
    } | sha256sum | cut -d' ' -f1 )
}
before=$(live_sum)
cls() { ( cd "$PT" && timeout 60 bash "$SELF_ABS" "$@" </dev/null 2>&1 ); }

mkdir -p "$PT/corp/planted" "$PT/corp/clean" "$PT/empty" "$PT/root/scripts"
cat > "$PT/corp/planted/verify-x.sh" <<'PL'
#!/usr/bin/env bash
for f in $(git ls-files 'x*'); do
    grep -q m "$f" || exit 1
done
echo PASS
exit 0
PL
cat > "$PT/corp/clean/verify-x.sh" <<'CL'
#!/usr/bin/env bash
n=0
for f in $(git ls-files 'x*'); do
    n=$((n + 1))
done
if [ "$n" -eq 0 ]; then echo "could not determine"; exit 2; fi
echo PASS
exit 0
CL

out=$(cls --root "$PT" --corpus "$PT/corp/clean"); rc=$?
if [ "$rc" -eq 0 ] && ! grep -q '^FINDING' <<<"$out" && grep -q '^INSPECTED 1$' <<<"$out"; then ok "control: guarded loop over the clean corpus exits 0 with 1 inspected"; else bad "control rc=$rc: $out"; fi
out=$(cls --root "$PT" --corpus "$PT/corp/planted"); rc=$?
if [ "$rc" -eq 1 ] && grep -q '^FINDING vacuous-gates high false-evidence verify-x.sh:2 ' <<<"$out"; then ok "mutation: planted vacuous loop is a finding at verify-x.sh:2, rc 1"; else bad "planted rc=$rc: $out"; fi
out=$(cls --root "$PT" --corpus "$PT/empty"); rc=$?
if [ "$rc" -eq 2 ] && ! grep -q '^FINDING' <<<"$out" && grep -q '^INSPECTED 0$' <<<"$out" && grep -q "^POPULATION-SHA $EMPTY_SHA\$" <<<"$out"; then ok "empty corpus population is rc 2, never clean, INSPECTED 0 + POPULATION-SHA printed"; else bad "empty corpus rc=$rc: $out"; fi
out=$(cls --root /nonexistent); rc=$?
if [ "$rc" -eq 2 ] && grep -q '^INSPECTED 0$' <<<"$out" && grep -q '^POPULATION-SHA ' <<<"$out"; then ok "--root /nonexistent is rc 2 and still prints INSPECTED and POPULATION-SHA"; else bad "nonexistent root rc=$rc: $out"; fi

# the TRACKED corpus, copied: planted findings == expect.tsv exactly, clean corpus silent
FX="$HERE/_tests/fixtures/zero-gap/$CLASS_ID"
if [ -d "$FX/planted" ] && [ -d "$FX/clean" ] && [ -f "$FX/expect.tsv" ]; then
    cp -R "$FX" "$PT/fx"
    out=$(cls --root "$PT" --corpus "$PT/fx/planted"); rc=$?
    got=$(grep '^FINDING ' <<<"$out" | awk '{print $5}' | LC_ALL=C sort -u)
    want=$(awk -F'\t' '!/^#/ && NF { print $1 }' "$PT/fx/expect.tsv" | LC_ALL=C sort -u)
    if [ "$rc" -eq 1 ] && [ -n "$want" ] && [ "$got" = "$want" ]; then ok "tracked corpus planted/: findings equal expect.tsv exactly ($(printf '%s\n' "$want" | awk 'END{print NR}') rows, recall 1.0, nothing unexpected)"
    else bad "tracked corpus planted rc=$rc; missing: $(comm -23 <(printf '%s\n' "$want") <(printf '%s\n' "$got") | tr '\n' ' ') unexpected: $(comm -13 <(printf '%s\n' "$want") <(printf '%s\n' "$got") | tr '\n' ' ')"; fi
    out=$(cls --root "$PT" --corpus "$PT/fx/clean"); rc=$?
    if [ "$rc" -eq 0 ] && ! grep -q '^FINDING' <<<"$out"; then ok "tracked corpus clean/: no finding (fixed battery, recorded-then-refused, heredoc/comment near-misses), rc 0"; else bad "tracked corpus clean rc=$rc: $(grep '^FINDING' <<<"$out" | awk '{print $5}' | tr '\n' ' ')"; fi
else
    bad "tracked corpus $FX is incomplete"
fi

# live-mode throwaway repository: registry row -> planted script
cp "$PT/corp/planted/verify-x.sh" "$PT/root/scripts/verify-x.sh"
printf 'check\tx\tscripts/verify-x.sh\tflag\t--prove-failure\t--root /nonexistent\n' > "$PT/root/scripts/check-registry.tsv"
out=$(cls --root "$PT/root"); rc=$?
if [ "$rc" -eq 1 ] && grep -q '^FINDING vacuous-gates high false-evidence scripts/verify-x.sh:2 ' <<<"$out"; then ok "live mode: registered planted gate found at scripts/verify-x.sh:2"; else bad "live planted rc=$rc: $out"; fi
pop=$(cls --root "$PT/root" --emit-population)
sha=$(printf '%s\n' "$pop" | sha256sum | cut -d' ' -f1)
if [ "$pop" = "scripts/verify-x.sh" ] && grep -q "^POPULATION-SHA $sha\$" <<<"$out"; then ok "emitted population equals the walked set (sha matches)"; else bad "population mismatch: $pop"; fi
cp "$PT/corp/clean/verify-x.sh" "$PT/root/scripts/verify-x.sh"
out=$(cls --root "$PT/root"); rc=$?
if [ "$rc" -eq 0 ]; then ok "live mode: guarded gate is clean, rc 0"; else bad "live clean rc=$rc: $out"; fi

# pre-push gates: a one-file shell gate joins the population; a multi-step / go test gate is a
# typed COULD-NOT-INSPECT token, never silently dropped and never read as clean
cat > "$PT/root/scripts/pre-push-gates.sh" <<'PPG'
#!/usr/bin/env bash
gate_0() { bash "$ROOT/scripts/verify-y.sh"; }
gate_1() {
    cd "$ROOT/tools" || return 90
    go test ./...
}
PPG
cp "$PT/corp/clean/verify-x.sh" "$PT/root/scripts/verify-y.sh"
out=$(cls --root "$PT/root"); rc=$?
pop=$(cls --root "$PT/root" --emit-population)
if [ "$rc" -eq 2 ] && grep -q '^COULD-NOT-INSPECT scripts/pre-push-gates.sh:gate_1 non-shell gate' <<<"$out" && grep -qx 'scripts/verify-y.sh' <<<"$pop" && grep -qx 'scripts/pre-push-gates.sh:gate_1' <<<"$pop" && grep -q '^INSPECTED 2$' <<<"$out"; then ok "pre-push gates: gate_0's shell file joins the population, the go test gate_1 is COULD-NOT-INSPECT (rc 2)"; else bad "pre-push gates rc=$rc: $out // $pop"; fi
rm -f "$PT/root/scripts/pre-push-gates.sh" "$PT/root/scripts/verify-y.sh"

# a registered SYMLINK pointing outside the root is never read or followed
mkdir -p "$PT/outside"; cp "$PT/corp/planted/verify-x.sh" "$PT/outside/evil.sh"
ln -s "$PT/outside/evil.sh" "$PT/root/scripts/link.sh"
printf 'check\tx\tscripts/verify-x.sh\tflag\t--prove-failure\t--root /nonexistent\ncheck\tl\tscripts/link.sh\tflag\t--prove-failure\t--root /nonexistent\n' > "$PT/root/scripts/check-registry.tsv"
out=$(cls --root "$PT/root"); rc=$?
if [ "$rc" -eq 2 ] && grep -q '^COULD-NOT-INSPECT scripts/link.sh not a regular file' <<<"$out" && ! grep -q '^FINDING' <<<"$out"; then ok "a registered symlink leaving the root is COULD-NOT-INSPECT, not followed (its vacuous target is not reported)"; else bad "symlink rc=$rc: $out"; fi
rm -f "$PT/root/scripts/link.sh"
# a FIFO in a corpus: COULD-NOT-INSPECT, never read, never hangs
mkdir -p "$PT/fifo"; cp "$PT/corp/clean/verify-x.sh" "$PT/fifo/ok.sh"; mkfifo "$PT/fifo/pipe.sh"
out=$(cls --root "$PT" --corpus "$PT/fifo"); rc=$?
if [ "$rc" -eq 2 ] && grep -q '^COULD-NOT-INSPECT pipe.sh not a regular file' <<<"$out" && grep -q '^INSPECTED 1$' <<<"$out"; then ok "a FIFO is COULD-NOT-INSPECT without blocking (rc 2, 1 regular file inspected)"; else bad "fifo rc=$rc: $out"; fi

printf 'check\tx\tscripts/absent.sh\tflag\t--prove-failure\t--root /nonexistent\n' > "$PT/root/scripts/check-registry.tsv"
rm -f "$PT/root/scripts/verify-x.sh"
out=$(cls --root "$PT/root"); rc=$?
if [ "$rc" -eq 2 ]; then ok "live mode: registry naming no existing file is rc 2"; else bad "empty live population rc=$rc: $out"; fi
rm -f "$PT/root/scripts/check-registry.tsv"
out=$(cls --root "$PT/root"); rc=$?
if [ "$rc" -eq 2 ] && grep -q '^INSPECTED 0$' <<<"$out"; then ok "live mode: missing registry is rc 2 (INSPECTED 0 printed)"; else bad "missing registry rc=$rc: $out"; fi
out=$(cd "$PT" && PATH=/nonexistent-zg /bin/bash "$SELF_ABS" --root "$PT" --corpus "$PT/corp/clean" 2>&1); rc=$?
if [ "$rc" -eq 2 ] && ! grep -q '^FINDING' <<<"$out" && grep -q '^POPULATION-SHA ' <<<"$out"; then ok "missing tools (empty PATH) is rc 2, no verdict, contract lines printed"; else bad "missing tools rc=$rc: $out"; fi
after=$(live_sum)
if [ "$before" = "$after" ]; then ok "live tree byte-identical before and after the proof (status + content of every modified/untracked file)"
else
    echo "COULD-NOT-INSPECT live-tree the live tree moved while the proof ran; this proof writes only under its own scratch directory, so the change came from another writer and the byte-identical assertion cannot be judged (rc 2, never a pass)"
    echo "zero-gap-class-$CLASS_ID --prove-failure: $pass passed, $fail failed, live-tree assertion undetermined"
    [ "$fail" -gt 0 ] && exit 1
    exit 2
fi
echo "zero-gap-class-$CLASS_ID --prove-failure: $pass passed, $fail failed"
[ "$fail" -eq 0 ] && exit 0
exit 1
