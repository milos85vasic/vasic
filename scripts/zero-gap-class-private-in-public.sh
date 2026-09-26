#!/usr/bin/env bash
# zero-gap-class-private-in-public.sh — sweep class `private-in-public` (feature 010, task T030,
# extended by T085, FR-020).
#
# WHAT IT DETECTS. FR-020: "No record produced by this programme MAY contain an unmeasured
# assertion, guessing language, a credential, or copied private content." Three detectors run
# over every public record the programme produces:
#
#   (1) GUESSING LANGUAGE in statements of cause or status  -> medium false-evidence
#       Terms (case-insensitive, whole words): probably likely maybe seems "appears to"
#       "appears that" apparently possibly "might be" "may have been" "may have caused" perhaps
#       presumably "I think" "should be", and a SENTENCE-INITIAL "it appears" — the §11.4.6
#       vocabulary. NOT in it, by measurement: bare "appears" and "could be" (on specs/002-009,
#       41 bare-"appears" and 26 "could be" hits, every one of 12 hand-read a factual or modal
#       use such as "appears exactly once" / "could be replayed"), and "may have" without
#       been/caused.
#       SKIP RULE (the heuristic that stands in for "a statement of cause or status"):
#       a line is NOT read when it is inside a ``` or ~~~ fenced block; is a blockquote
#       (`>`); is marked UNCONFIRMED / UNKNOWN: / PENDING_FORENSICS (a bare UNKNOWN cell,
#       e.g. a TSV recall column, is NOT a marker); names a hypothesis ("hypothes…",
#       "refuted"); or cites the rule anchor "11.4.6". A line merely containing "guess" or
#       "forbid" IS read (no wholesale skip). Inline `code` spans and a term that is itself
#       quoted ("probably", 'probably', “probably”) are removed before matching. Granularity is
#       the LINE, not the sentence. One finding per line (the first term matched is named).
#       Precision (re-measured 2026-09-26, fix round F3; population re-measured again same day,
#       fix round F4 / T085, after the specs/002-009 extension below): NOT a semantic parser — a
#       normative "X should be Y" is reported like a causal guess. Original-population rows: 8
#       hits, all 8 hand-read, 1 real (sweep-classes.tsv:21 "least likely to drift", an
#       unmeasured probability) and 7 not: progress.yml:43 a normative "should be"; progress.yml:
#       72, :86 and :95 review lines naming the vocabulary unquoted; and 3 SELF-REFERENCE rows —
#       the re-baselined report.txt, FINDINGS-BY-CLASS.tsv and report.json each carry another
#       class's finding whose description copies progress.yml:43, so a report of a sweep
#       re-reports the term: 1/8. specs/002-009 rows (T085: now INSIDE the population, was a
#       "wider sample" taken outside it): 47 hits, 10 hand-read, 2 real (a "presumably true"
#       status and a "likely result" prediction), 8 normative or comparative ("most likely to",
#       "should be read"): 2/10. Combined live tree total with both ranges: 55 hits (re-measured
#       2026-09-26 after T085; the two component counts above are unchanged, only their scope
#       label moved). Recall: 9 of 9 planted.
#       NOT seen, by design: a term on a line that carries a marker or the 11.4.6 anchor, or
#       inside a fence or blockquote; the excluded words above.
#
#   (2) CREDENTIALS -> critical security. Two layers, a hit on either is a finding:
#       (a) the constitution's scanner, reused BY REFERENCE, read-only:
#           submodules/constitution/scripts/hooks/credential_scan_lib.sh
#           (`helix_cred_detector1_real_hit_stream` per candidate line, and its adjacency
#           awk). INVERTED CONVENTION handled explicitly: that library returns 0 on a HIT
#           and 1 when clean, and 1 ALSO for an unreadable path — so this class never
#           hands it a path: it feeds single lines on stdin after checking readability
#           itself, and proves the library's polarity on every run with a canary (a
#           run-time-built fake AKIA line must be a hit, a plain line must be clean);
#           a failed canary is COULD-NOT-INSPECT, never clean. It is slow on long lines
#           (94.6 s on one 70 KB line, progress.yml), so a line over 16384 bytes is not
#           read by ANY detector and is reported COULD-NOT-INSPECT <item>:<line>. Its
#           email+password ADJACENCY pass reads a copy in which scp-style git remotes
#           (git@host:org/repo, including the $VAR forms the upstream strip misses — 3 false
#           hits on specs/007) are blanked; its value-pattern pass reads the line unchanged.
#       (b) generic shapes (awk, this file): AWS key ids (AKIA/ASIA/AGPA/AIDA/AROA/ANPA/
#           ANVA/AIPA + 16), PEM private-key armour, GitHub (ghp_/gho_/ghu_/ghs_/ghr_,
#           github_pat_), GitLab (glpat-), Slack (xox?-), JWT, URL userinfo passwords
#           (scheme://user:pass@ — placeholder values and $VAR/<x>/{x}/%x forms skipped),
#           and high-entropy tokens (>= 32 chars of [A-Za-z0-9+/_=-], Shannon entropy >= 4.2
#           bits/char, no run of 6 consecutive code points such as ABCDEF/012345, and at least
#           one /-separated component that mixes upper, lower and digit AND is not
#           IDENTIFIER-SHAPED — its word/digit segments, split at _ - . = + and at lower->upper
#           and letter<->digit boundaries, average under 3 characters. Go test names, CamelCase
#           identifiers, run directories and ULID routes average 3.4-5 and are not secrets;
#           a random token averages about 2).
#       THE MATCHED VALUE IS NEVER PRINTED, anywhere (a finding, --json output or a register
#       item description): T085 masked-output rule — a finding names the shape and a
#       "[REDACTED len=N]" marker, N being the length of the WITHHELD value only (never a
#       digest, excerpt or anything else derived from the value); a shape whose length this
#       class cannot itself measure (the constitution scanner reports hit/clean only) gets a
#       bare "[REDACTED]". The prior convention — a 12-hex sha256 prefix of the WHOLE LINE —
#       is dropped: it named no value either, but the length marker is what FR-020's
#       masked-output rule asks for and a line digest added nothing a location does not
#       already give. Precision (re-measured 2026-09-26, fix round F4 / T085, population now
#       including specs/002-009 per the extension below): live tree 1 hit, hand-read real (the
#       literal password at specs/007-decouple-modules-auth/spec.md:184, caught by layer (a) —
#       none of the generic shapes in layer (b) matches it) — before the identifier rule a
#       specs/002-009 sample gave 71 hits, 67 of them Go test names, paths and ULIDs. Recall on
#       the planted corpus: 4 of 4 planted shapes; the constitution library alone finds 2 of
#       those 4 (measured), which is why layer (b) exists. On the REAL specs/007-*/ passwords
#       (2 accounts, 15 lines across 5 files per the seed-build finding, T086 queues their
#       rotation): only 1 of 15 lines is recall — a real, accepted gap, out of scope for T085
#       and unchanged by it (population and masking are orthogonal to shape recall). NOT seen:
#       name-less short passwords, encoded/computed secrets, a secret split across lines, a
#       token < 32 chars in no known shape, a base64 secret none of whose /-components mixes
#       all three character classes.
#       CORPUS PLACEHOLDERS: the planted corpus stores NO secret-shaped text at rest (a
#       secret scanner may refuse the push, and history is permanent). It stores
#       @@ZG-AKIA@@, @@ZG-PRIVKEY-HEADER@@, @@ZG-ENTROPY@@ and @@ZG-URLPASS@@; --corpus mode
#       expands them into a scratch copy under $TMPDIR at scan time (values built at run time
#       by zg_expand below); live mode never expands. The proof shows the unexpanded files
#       yield no credential finding and the expanded copy yields the four planted ones.
#
#   (3) PRIVATE CONTENT -> critical content-boundary. Private text cannot be known from
#       here, so the detector is STRUCTURAL. The private repositories are DERIVED from the
#       fleet table in docs/content-boundary.md (rows whose visibility cell reads
#       **private**) — a dated observation of the provider, not a live query (this class
#       makes no network call); an absent or row-less table is COULD-NOT-INSPECT.
#       Shapes (inline `code` spans removed first; a private path inside a code span is a
#       PATH REFERENCE and never makes a line or an attribution private-shaped):
#         - a transcript timestamp `[h:mm:ss]` / `[mm:ss]` or an SRT/VTT cue `hh:mm:ss.mmm -->`
#         - a speaker turn `SPEAKER n:` / `Interviewer:` / `Interviewee:` / `Candidate:`
#         - a fenced block (info string not bash/sh/shell/zsh/console) or a blockquote whose
#           attribution line — the last non-blank line before it — names a private path
#         - a line that names a private path AND carries a quotation of >= 4 words
#           ("…" or “…”). NOT a quotation: a quoted span that itself contains the private
#           path (the author's own sentence naming it), a span that is a command-line option
#           argument (python -c "…"), and the outer quotes of a line that IS one YAML/JSON
#           double-quoted scalar (- "…", key: "…", "k": "…") — its content is read instead,
#           with \" unescaped, so an escaped quotation inside a ruling is still found.
#           JSON DOCUMENTS (a record named *.json, *.jsonl or *.ndjson; fix round F2, review
#           rev-base-B C1): EVERY string literal's delimiters are record syntax, never a
#           quotation — a sweep report.json names private paths in "location" values next to a
#           many-word "description" value, and before this rule the pairing of delimiters across
#           values made each such line a quotation (123 false CRITICALs from one baseline
#           report.json). Each string value is decoded (\" and \u0022 -> ", \u201c/\u201d -> the
#           curly quotes, other escapes -> a space) and only its CONTENT is read for a quotation,
#           so a quoted sentence INSIDE a value is still found; an UNTERMINATED string (a truncated
#           record) is read too. The file type is decided by the NAME only: JSON written into a
#           record of another extension gets the line rules above. Two limits (review rev-f, both
#           unchanged behaviour): a SINGLE-QUOTED span ('…') never counts as a quotation, in any
#           record; and the rule is LINE-level, so pretty-printed JSON that puts "location" and
#           "description" on separate lines is never a private-path-plus-quotation line — a
#           quotation in such a description is not seen unless the same line names the path.
#       A PATH-ONLY reference is allowed and is not reported (workshop/chapters/01/x.mp4).
#       Precision (re-measured 2026-09-26, fix round F2; population re-measured again same day,
#       fix round F4 / T085): live tree 0 hits over 149 records (was 31 before the specs/002-009
#       extension below; the specs/002-009 rows are now folded into this same live figure and
#       remain 0), including the baseline report.json that gave 123 false CRITICALs before the
#       JSON rule (live total 130 -> 7 at F2, every removed row one of those 123); specs/002-009
#       rows (T085: now INSIDE the population, was a "wider sample" taken outside it) 0 hits
#       (was 55, 0/5 real: 48 backticked paths, 4 paths inside the quote, 3 python -c
#       arguments). Recall: 11 of 11 planted shapes (5 of them JSON: \", \u201c and \u0022
#       escapes, literal curly quotes, an unterminated string); corpus clean/ holds a sweep-report-shaped report.json and a rows.jsonl
#       that name private paths in string values and must stay silent. NOT seen: copied
#       private prose with no quotation marks, attribution or transcript shape; a
#       backticked private path followed by a quotation; a quotation passed as a -x option
#       argument (that is scripts/verify-content-boundary.sh's job, which compares text).
#
# POPULATION (row `private-in-public` of docs/zero-gap/sweep-classes.tsv — row wording NOT YET
# updated for the T085 extension below; the controller who owns sweep-classes.tsv should append
# "plus specs/002-*/ through specs/009-*/ (T085)" to that row's population column): every
# public record the feature produces, PLUS (T085, FR-020) the numbered spec directories
# specs/002-*/ through specs/009-*/ — previously out of scope, extended because a scan run
# manually over them during the T085 seed-build check found two real, live account passwords
# exposed in public specs/007-*/ text (T086 queues their rotation). specs/001-*/ and any
# specs/010-*/ OTHER than specs/010-zero-gap-verified-closure/ stay OUT of scope; only the
# literal range 002-009 is added. Derived at run time, never listed:
#   git ls-files --cached --others --exclude-standard -- docs/zero-gap \
#       specs/010-zero-gap-verified-closure CONTINUATION.md 'specs/00[2-9]-*'
# i.e. TRACKED plus UNTRACKED-NOT-IGNORED files (the set `zg_manifest` fingerprints): a
# record written but not yet committed is exactly what must be caught before it is pushed,
# and docs/zero-gap/ is untracked until the class-wave commit. Every path that exists (a tracked
# path deleted from the work tree is not a record any more); a SYMLINK is COULD-NOT-INSPECT and
# never followed (a link can point outside --root), a non-regular file (FIFO, socket, device) is
# COULD-NOT-INSPECT and never opened; `_tests/fixtures/zero-gap/` is excluded. CONTINUATION.md is ONE item of which only the zero-gap ENTRIES are read: a
# heading (outside a fence) whose text matches "zero-gap", "spec 010" or "010-zero-gap"
# opens an entry, which ends at the next heading of the same or a higher level. The
# register export and cycle records land under docs/zero-gap/ and are covered when they
# exist. NOT covered: the evidence streams, which live GIT-IGNORED under
# .remember/logs/zero-gap/evidence/ (ruling T015) — ignored files are never published and
# are outside the sweep fingerprint; the dedicated FR-020 scanner (T062) owns them.
# With --corpus <dir>: the population is every non-directory entry under <dir> (same symlink and
# non-regular rule), placeholders are expanded as described in (2), and a file named
# CONTINUATION.md at its top gets the same entry rule.
#
# USAGE
#   zero-gap-class-private-in-public.sh --root <dir> [--corpus <dir>] [--emit-population]
#   zero-gap-class-private-in-public.sh --prove-failure
# Output: the class contract of docs/zero-gap/README.md (FINDING / COULD-NOT-INSPECT /
# INSPECTED <n> / POPULATION-SHA <sha256>); locations are <item>:<line>.
#
# EXIT: 0 every item read, no finding; 1 at least one FINDING (outranks 2); 2 could not
# determine (no population, unreadable/binary item, a line over 16 KB, a missing tool, the
# credential scanner absent or failing its canary, no private-repository table). 2 is never
# a pass. --prove-failure: 0 all cases behave, 1 a case failed, 2 cannot determine
# (including the live population moving while the proof ran).
#
# SIDE EFFECTS: none on --root (reads only; temporary files under $TMPDIR, removed on exit).
# ENVIRONMENT: runs under the runner's `env -i` allow-list; reads no other variable except
# ZG_PIP_CRED_LIB, a TEST HOOK used only by --prove-failure to point at a broken scanner.
# DEPENDENCIES: bash, git, awk, grep, sed, sort, sha256sum, od, cut, tr, head, wc, mktemp,
# find, paste; the constitution credential library (above).
set -uo pipefail
export LC_ALL=C LANG=C
ID=private-in-public
SELF=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/$(basename -- "${BASH_SOURCE[0]}")
HERE=$(dirname -- "$SELF")
LIVE_ROOT=$(cd -- "$HERE/.." && pwd)
CRED_LIB=${ZG_PIP_CRED_LIB:-$LIVE_ROOT/submodules/constitution/scripts/hooks/credential_scan_lib.sh}
MAXLINE=16384
REQ_TOOLS="awk git grep sed sort sha256sum od cut tr head wc mktemp find paste"

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

decode() { printf '%b' "$(printf '%s' "$1" | sed 's/%\([0-9A-F][0-9A-F]\)/\\x\1/g')"; }

# ---------------------------------------------------------------- corpus placeholders
# The planted corpus stores NO secret-shaped text at rest (ruling: a secret scanner may refuse the push,
# and history is permanent). It stores @@ZG-...@@ placeholders; --corpus mode expands them into a
# scratch copy under $TMPDIR at scan time. Every value is BUILT here at run time, never a literal:
#   @@ZG-AKIA@@            an AWS-key-id shape (AKIA + 16)       @@ZG-PRIVKEY-HEADER@@  a PEM private-key header
#   @@ZG-ENTROPY@@         a 34-char high-entropy token          @@ZG-URLPASS@@         a URL-userinfo password
# Live mode never expands anything: a placeholder in a live record is plain text.
zg_fake_entropy() {   # deterministic Park-Miller sequence over [A-Za-z0-9]; exact in double precision
    awk 'BEGIN { a = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"; x = 20260926; t = "FAKE"
                 for (i = 0; i < 30; i++) { x = (x * 16807) % 2147483647; t = t substr(a, x % 62 + 1, 1) }
                 print t }'
}
zg_expand() {   # <in file> <out file>
    local d=----- akia pem ent pw
    akia="AK""IA$(printf 'FAKE%.0s' 1 2 3 4)"
    pem="${d}BEGIN OPENSSH PRIVATE"" KEY${d}"
    ent=$(zg_fake_entropy)
    pw="Fake""Pass9x7"
    awk -v akia="$akia" -v pem="$pem" -v ent="$ent" -v pw="$pw" '{
            gsub(/@@ZG-AKIA@@/, akia); gsub(/@@ZG-PRIVKEY-HEADER@@/, pem)
            gsub(/@@ZG-ENTROPY@@/, ent); gsub(/@@ZG-URLPASS@@/, pw); print }' "$1" >"$2"
}

usage() { sed -n '2,/^set -uo pipefail$/{/^set -uo/d;s/^# \{0,1\}//;p}' "$SELF"; }

# ---------------------------------------------------------------- awk programs
# REGION: prints the file with every line this class does not read blanked (line numbers
# kept): lines outside CONTINUATION zero-gap entries (cont=1) and lines over maxlen bytes
# (their numbers go to longf).
AWK_REGION='
BEGIN { insec = 0; lvl = 0; fence = 0 }
{
    line = $0
    if (line ~ /^[ \t]*(```|~~~)/) fence = !fence
    if (cont) {
        if (!(line ~ /^[ \t]*(```|~~~)/) && !fence && match(line, /^#+[ \t]/)) {
            hl = RLENGTH - 1
            if (insec && hl <= lvl) insec = 0
            if (!insec && tolower(line) ~ /zero-gap|spec 010|010-zero-gap/) { insec = 1; lvl = hl }
        }
        if (!insec) { print ""; next }
    }
    if (length(line) > maxlen) { print FNR > longf; print ""; next }
    print line
}'

# DETECT: one record per hit, "<line>\t<G|C|P>\t<detail>" (G guessing, C credential, P private).
AWK_DETECT='
function rep(s, n,   r) { r = ""; while (n-- > 0) r = r s; return r }
function words(s,   n, i, w, c) { n = split(s, w, /[ \t]+/); c = 0; for (i = 1; i <= n; i++) if (w[i] != "") c++; return c }
function spans(s,   rest, a, b, q, pre) {   # 1 when s holds a >= 4-word quotation that is not the record syntax
    rest = s
    while (match(rest, /"[^"]+"/)) {
        q = substr(rest, RSTART + 1, RLENGTH - 2); pre = substr(rest, 1, RSTART - 1)
        rest = substr(rest, RSTART + RLENGTH)
        if (q ~ privre) continue                                          # the author sentence naming the path
        if (pre ~ /(^|[ \t])--?[A-Za-z][A-Za-z0-9-]*[ \t=]*$/) continue   # a command-line option argument (-c "...")
        if (words(q) >= 4) return 1
    }
    rest = s
    while ((a = index(rest, "\342\200\234")) > 0) {
        rest = substr(rest, a + 3); b = index(rest, "\342\200\235")
        if (b == 0) break
        q = substr(rest, 1, b - 1); rest = substr(rest, b + 3)
        if (q ~ privre) continue
        if (words(q) >= 4) return 1
    }
    return 0
}
function long_quote(s,   inner) {
    # A line that IS one YAML/JSON double-quoted scalar ("- "...", key: "...", "k": "..."): its outer
    # quotes are the record string syntax, not a quotation — read the scalar content instead,
    # with \" unescaped, so an escaped quotation inside it is still seen.
    if (match(s, /^[ \t]*(-[ \t]+)?([A-Za-z0-9_.-]+:[ \t]+|"[^"]*"[ \t]*:[ \t]*)?"/)) {
        inner = substr(s, RLENGTH + 1)
        if (match(inner, /"[ \t]*,?[ \t]*$/)) {
            inner = substr(inner, 1, RSTART - 1)
            if (inner !~ /(^|[^\\])"/) { gsub(/\\"/, "\"", inner); return spans(inner) }
        }
    }
    return spans(s)
}
function json_quote(s,   i, n, c, e, hex, instr, buf) {
    # A JSON/JSONL record: every string literal is record syntax, never a quotation. Each string
    # value is decoded (\" -> ", \\ -> \, \u201c/\u201d -> the curly quotes, \u0022 -> ", other escapes
    # -> a space) and its CONTENT is read by spans(), so a quotation inside a value is still found.
    n = length(s); instr = 0; buf = ""
    for (i = 1; i <= n; i++) {
        c = substr(s, i, 1)
        if (!instr) { if (c == "\"") { instr = 1; buf = "" } ; continue }
        if (c == "\\") {
            e = substr(s, i + 1, 1); i++
            if (e == "u") {
                hex = tolower(substr(s, i + 1, 4)); i += 4
                if (hex == "201c") buf = buf "\342\200\234"
                else if (hex == "201d") buf = buf "\342\200\235"
                else if (hex == "0022") buf = buf "\""
                else buf = buf " "
            } else if (e == "n" || e == "t" || e == "r" || e == "b" || e == "f") buf = buf " "
            else buf = buf e
            continue
        }
        if (c == "\"") { instr = 0; if (spans(buf)) return 1; continue }
        buf = buf c
    }
    if (instr && spans(buf)) return 1   # an unterminated string: its content is still read
    return 0
}
function segmean(t,   i, n, c, cls, pcls, segs, chars) {   # mean length of word/digit segments (identifier shape)
    n = length(t); segs = 0; chars = 0; pcls = ""
    for (i = 1; i <= n; i++) {
        c = substr(t, i, 1)
        if (c ~ /[\/_.=+-]/) { pcls = ""; continue }
        if (c ~ /[0-9]/) cls = "d"; else if (c ~ /[a-z]/) cls = "l"; else cls = "u"
        if (pcls == "" || (cls == "d") != (pcls == "d") || (cls == "u" && pcls == "l")) segs++
        chars++; pcls = cls
    }
    return segs ? chars / segs : 0
}
function mixed_component(t,   n, i, parts) {   # a /-component mixing upper, lower and digit that is not word-shaped
    n = split(t, parts, "/")
    for (i = 1; i <= n; i++)
        if (parts[i] ~ /[A-Z]/ && parts[i] ~ /[a-z]/ && parts[i] ~ /[0-9]/ && segmean(parts[i]) < 3) return 1
    return 0
}
function entropy(t,   i, n, c, H, p, cnt) {
    n = length(t); split("", cnt)
    for (i = 1; i <= n; i++) cnt[substr(t, i, 1)]++
    H = 0
    for (c in cnt) { p = cnt[c] / n; H -= p * log(p) / log(2) }
    return H
}
function ascending_run(t,   i, n, run, prev, c) {   # longest run of consecutive code points (ABCDEF, 012345)
    n = length(t); run = 1; prev = -9
    for (i = 1; i <= n; i++) {
        c = index(asc, substr(t, i, 1))
        if (c > 0 && c == prev + 1) { if (++run >= 6) return 1 } else run = 1
        prev = c
    }
    return 0
}
function placeholder(v,   l) {
    l = tolower(v)
    if (v ~ /^[$<{%*]/) return 1
    if (length(v) < 6) return 1
    if (l ~ /^(password|passwd|pass|secret|token|changeme|change_me|redacted|placeholder|example|dummy|x+|\*+)$/) return 1
    return 0
}
BEGIN {
    re_aws = "(^|[^A-Z0-9])(AKIA|ASIA|AGPA|AIDA|AROA|ANPA|ANVA|AIPA)" rep("[A-Z0-9]", 16) "([^A-Z0-9]|$)"
    re_pem = "-----BEGIN [A-Z0-9 ]*PRIVATE KEY( BLOCK)?-----"
    re_gh  = "(ghp|gho|ghu|ghs|ghr)_" rep("[A-Za-z0-9]", 36)
    re_ghp = "github_pat_" rep("[A-Za-z0-9_]", 22)
    re_gl  = "glpat-" rep("[A-Za-z0-9_-]", 20)
    re_sl  = "xox[abprs]-" rep("[A-Za-z0-9-]", 10)
    re_jwt = "eyJ" rep("[A-Za-z0-9_-]", 10) "[A-Za-z0-9_-]*[.]eyJ" rep("[A-Za-z0-9_-]", 10) "[A-Za-z0-9_-]*[.]" rep("[A-Za-z0-9_-]", 10)
    privre = "(^|[^A-Za-z0-9_./-])(" priv ")/[A-Za-z0-9_.~-]"
    guessre = "(^|[^a-z])(probably|likely|maybe|seems|appears[ \t]+(to|that)|apparently|possibly|might[ \t]+be|may[ \t]+have[ \t]+(been|caused)|perhaps|presumably|i[ \t]+think|should[ \t]+be)([^a-z]|$)"
    termre = "(probably|likely|maybe|seems|appears|appears to|appears that|it appears|apparently|possibly|might be|may have been|may have caused|perhaps|presumably|i think|should be)"
    asc = ""; for (i = 32; i < 127; i++) asc = asc sprintf("%c", i)
    fence = 0; prevnb = ""; prevq = 0
}
{
    raw = $0
    isfence = (raw ~ /^[ \t]*(```|~~~)/)
    code = raw; gsub(/`[^`]*`/, " ", code)

    # ---- (2) credentials: every line, fenced or not (a secret in a code block still leaks).
    # T085 masked-output rule (FR-020): each shape tag carries "shape:len" — len is the length
    # of the WITHHELD value only, so the finding can name a redaction marker ([REDACTED len=N])
    # without ever printing, or letting a caller recover, the value itself.
    k = ""
    # re_aws alone wraps its credential in boundary-consuming groups ((^|[^A-Z0-9]) ... ([^A-Z0-9]|$)),
    # so RLENGTH would over-count by the boundary character; the credential itself is always exactly
    # a 4-letter prefix (AKIA/ASIA/AGPA/AIDA/AROA/ANPA/ANVA/AIPA) + 16 = 20 chars, a constant by
    # construction of the pattern, so it is stated directly rather than taken from RLENGTH.
    if (raw ~ re_aws) k = k ",aws-access-key-id:20"
    if (match(raw, re_pem)) k = k ",private-key-armour:" RLENGTH
    if (match(raw, re_gh)) k = k ",github-token:" RLENGTH
    else if (match(raw, re_ghp)) k = k ",github-token:" RLENGTH
    if (match(raw, re_gl)) k = k ",gitlab-token:" RLENGTH
    if (match(raw, re_sl)) k = k ",slack-token:" RLENGTH
    if (match(raw, re_jwt)) k = k ",jwt:" RLENGTH
    rest = raw
    while (match(rest, /[A-Za-z][A-Za-z0-9+.-]*:\/\/[^\/ \t:@]+:[^\/ \t@]+@/)) {
        u = substr(rest, RSTART, RLENGTH); rest = substr(rest, RSTART + RLENGTH)
        sub(/^[^:]*:\/\/[^:]*:/, "", u); sub(/@$/, "", u)
        if (!placeholder(u)) { k = k ",url-userinfo-password:" length(u); break }
    }
    rest = raw
    while (match(rest, /[A-Za-z0-9+\/_=-]+/)) {
        t = substr(rest, RSTART, RLENGTH); rest = substr(rest, RSTART + RLENGTH)
        if (length(t) >= 32 && mixed_component(t) && entropy(t) >= 4.2 && !ascending_run(t)) { k = k ",high-entropy-token:" length(t); break }
    }
    if (k != "") print FNR "\tC\t" substr(k, 2)

    # ---- (3) private-content shapes
    p = ""
    if (code ~ /\[[0-9][0-9]?:[0-5][0-9](:[0-5][0-9])?([.,][0-9]+)?\]/ || code ~ /[0-9][0-9]:[0-5][0-9]:[0-5][0-9][.,][0-9]+[ \t]*-->/) p = p ",transcript-timestamp"
    if (code ~ /^[ \t>*_-]*(\[[0-9:.,]+\][ \t]*)?(SPEAKER|Speaker|INTERVIEWER|Interviewer|INTERVIEWEE|Interviewee|CANDIDATE|Candidate)([ _-]?[0-9A-Z][0-9A-Z]?[0-9A-Z]?)?[*_]*:[ \t]+[^ \t]/) p = p ",speaker-turn"
    isq = (raw ~ /^[ \t]*>/)
    if (!fence && isfence) {
        info = raw; sub(/^[ \t]*(```|~~~)[ \t]*/, "", info); info = tolower(info); sub(/[ \t].*$/, "", info)
        if (info !~ /^(bash|sh|shell|zsh|console)$/ && prevnb ~ privre) p = p ",fenced-block-attributed-to-private-path"
    }
    if (!fence && isq && !prevq && prevnb ~ privre) p = p ",blockquote-attributed-to-private-path"
    if (code ~ privre && (json ? json_quote(raw) : long_quote(code))) p = p ",private-path-cited-with-quotation"
    if (p != "") print FNR "\tP\t" substr(p, 2)

    # ---- (1) guessing language
    if (!fence && !isfence && !isq) {
        l = tolower(code)
        if (raw !~ /UNCONFIRMED|UNKNOWN:|PENDING_FORENSICS/ && tolower(raw) !~ /hypothes|refuted|11\.4\.6/) {
            gsub("[\"\047]" termre "[\"\047]", " ", l)
            gsub("\342\200[\230\234]" termre "\342\200[\231\235]", " ", l)
            w = ""
            if (match(l, guessre)) w = substr(l, RSTART, RLENGTH)
            else if (match(l, /(^|[.;:!?][ \t]+)[ \t*_]*it[ \t]+appears([^a-z]|$)/)) w = "it appears"   # sentence-initial only
            if (w != "") {
                gsub(/^[^a-z]+|[^a-z]+$/, "", w); gsub(/[ \t]+/, " ", w)
                print FNR "\tG\t" w
            }
        }
    }

    if (isfence) fence = !fence
    if (raw !~ /^[ \t]*$/) { if (!isq) prevnb = code; prevq = isq } else prevq = 0
}'

# ---------------------------------------------------------------- helpers
CNI=()          # "<token> <reason>" lines, printed at the end
cni() { CNI+=("$1 $2"); }
finish_undetermined() {  # print the CNI lines plus the contract trailer for an empty walk; exit 2
    local l
    for l in "${CNI[@]}"; do echo "COULD-NOT-INSPECT $l"; done
    echo "INSPECTED 0"
    echo "POPULATION-SHA $(printf '' | sha256sum | cut -d' ' -f1)"
    exit 2
}

# raw_items: NUL-separated raw relative paths of the population, unsorted
raw_items() {
    if [ -n "$CORPUS" ]; then
        ( cd "$CORPUS" && find . ! -type d -print0 ) | sed -z 's|^\./||'
    else
        git -C "$ROOT" ls-files -z --cached --others --exclude-standard -- \
            docs/zero-gap specs/010-zero-gap-verified-closure CONTINUATION.md 'specs/00[2-9]-*' \
            | awk 'BEGIN { RS = ORS = "\0" } !/^_tests\/fixtures\/zero-gap\//' \
            | while IFS= read -r -d '' p; do if [ -e "$ROOT/$p" ] || [ -L "$ROOT/$p" ]; then printf '%s\0' "$p"; fi; done
    fi
}

# private_paths: the private repositories named by the fleet table, as an ERE alternation
private_paths() {
    local t="$ROOT/docs/content-boundary.md"
    [ -r "$t" ] || return 2
    awk -F'|' 'NF >= 4 && $3 ~ /\*\*private\*\*/ {
                   p = $2; if (match(p, /`[^`]+`/)) { p = substr(p, RSTART + 1, RLENGTH - 2); if (p ~ /^[A-Za-z0-9_.\/-]+$/) print p }
               }' "$t" | LC_ALL=C sort -u | sed 's/[.]/[.]/g' | paste -sd'|' -
}

# cred_lib_ok: source the constitution scanner INTO THIS SHELL and prove its polarity
# (0 = hit, 1 = clean). Sets LIBWHY on failure. Never call it in a subshell.
cred_lib_ok() {
    LIBWHY=""
    [ -r "$CRED_LIB" ] || { LIBWHY="is absent or unreadable"; return 1; }
    # shellcheck disable=SC1090
    . "$CRED_LIB" >/dev/null 2>&1 || { LIBWHY="could not be sourced"; return 1; }
    if ! declare -F helix_cred_detector1_real_hit_stream >/dev/null || [ -z "${HELIX_CRED_VALUE_PATTERN:-}" ] || [ -z "${HELIX_CRED_ADJACENCY_AWK:-}" ]; then
        LIBWHY="does not define its detectors"; return 1
    fi
    local rc1 rc2
    printf 'aws_access_key_id = AKIA%s\n' "$(printf 'FAKE%.0s' 1 2 3 4)" | helix_cred_detector1_real_hit_stream; rc1=$?
    printf 'a plain sentence with no secret\n' | helix_cred_detector1_real_hit_stream; rc2=$?
    if [ "$rc1" -ne 0 ] || [ "$rc2" -ne 1 ]; then
        LIBWHY="failed its polarity canary (fake key rc=$rc1, want 0 = hit; plain line rc=$rc2, want 1 = clean)"; return 1
    fi
    return 0
}

# cred_lib_lines <region file>: line numbers the constitution scanner flags; rc 2 on a tool error
cred_lib_lines() {
    local f=$1 n rc gl
    gl=$(grep -n -Eia -- "$HELIX_CRED_VALUE_PATTERN" "$f" 2>/dev/null); rc=$?
    [ "$rc" -le 1 ] || return 2
    while IFS=: read -r n _; do
        [ -n "$n" ] || continue
        sed -n "${n}p" "$f" | helix_cred_detector1_real_hit_stream; rc=$?
        case "$rc" in 0) echo "$n" ;; 1) ;; *) return 2 ;; esac
    done <<<"$gl"
    # The adjacency (email + password) pass reads a copy in which scp-style git remotes
    # (git@host:org/repo, including $VAR forms the upstream strip misses) are blanked; line numbers kept.
    sed -E 's#(^|[^A-Za-z0-9._%+-])git@[A-Za-z0-9.-]+:[^[:space:]]*/[^[:space:]]*#\1 #g' "$f" >"$f.adj" 2>/dev/null || return 2
    awk "$HELIX_CRED_ADJACENCY_AWK" "$f.adj" >/dev/null 2>&1; rc=$?
    case "$rc" in 1) return 0 ;; 0) ;; *) return 2 ;; esac
    gl=$(grep -n -a '@' "$f.adj" 2>/dev/null) || true
    while IFS=: read -r n _; do
        [ -n "$n" ] || continue
        sed -n "${n}p" "$f.adj" | awk "$HELIX_CRED_ADJACENCY_AWK" >/dev/null 2>&1; rc=$?
        case "$rc" in 0) echo "$n" ;; 1) ;; *) return 2 ;; esac
    done <<<"$gl"
    return 0
}

# ---------------------------------------------------------------- main
main() {
    local tok raw full region hits libl n found=0 inspected=0 walked priv b cont rc l line cat detail desc ln json
    local cshape clen marks
    ROOT="" CORPUS="" EMIT=0
    while [ $# -gt 0 ]; do
        case "$1" in
            --root) ROOT="${2:-}"; shift 2 || shift ;;
            --corpus) CORPUS="${2:-}"; shift 2 || shift ;;
            --emit-population) EMIT=1; shift ;;
            -h|--help) usage; exit 0 ;;
            *) echo "COULD-NOT-INSPECT - unknown argument (see --help)"; exit 2 ;;
        esac
    done
    if [ -z "$ROOT" ] || [ ! -d "$ROOT" ]; then echo "COULD-NOT-INSPECT - --root is not a directory"; exit 2; fi
    ROOT=$(cd -- "$ROOT" && pwd)
    if [ -n "$CORPUS" ] && [ ! -d "$CORPUS" ]; then echo "COULD-NOT-INSPECT - --corpus is not a directory"; exit 2; fi
    for b in $REQ_TOOLS; do
        command -v "$b" >/dev/null 2>&1 || cni - "required tool $b is not on PATH; nothing was read"
    done
    [ "${#CNI[@]}" -eq 0 ] || finish_undetermined
    if [ -z "$CORPUS" ] && ! git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        cni - "--root is not a git work tree; the population (tracked + untracked-not-ignored records) cannot be derived"
        finish_undetermined
    fi
    base=${CORPUS:-$ROOT}
    if ! walked=$(raw_items | zg_pct_encode_z | awk 'NF' | LC_ALL=C sort -u); then
        cni - "the population could not be enumerated (git ls-files or find failed)"
        finish_undetermined
    fi
    if [ "$EMIT" -eq 1 ]; then
        [ -z "$walked" ] || printf '%s\n' "$walked"
        exit 0
    fi
    if [ -z "$walked" ]; then
        cni - "the population enumerated to zero records: a class that reads nothing is never clean"
        finish_undetermined
    fi

    priv=$(private_paths); rc=$?
    if [ "$rc" -ne 0 ] || [ -z "$priv" ]; then
        cni docs/content-boundary.md "no private-repository row could be read from the fleet table; the private-content detector cannot run"
        priv='x^y'
    fi
    if [ "${CRED_LIB#"$LIVE_ROOT"/}" != "$CRED_LIB" ]; then CRED_LIB_T=$(zg_pct_encode "${CRED_LIB#"$LIVE_ROOT"/}"); else CRED_LIB_T=-; fi
    if cred_lib_ok; then LIBOK=1
    else cni "$CRED_LIB_T" "the constitution credential scanner $LIBWHY; credential layer (a) cannot run"; LIBOK=0; fi

    TMPW=$(mktemp -d "${TMPDIR:-/tmp}/zg-pip.XXXXXX") || { cni - "cannot create a temporary directory"; finish_undetermined; }
    trap 'rm -rf "$TMPW"' EXIT
    : >"$TMPW/find"
    while IFS= read -r tok; do
        [ -n "$tok" ] || continue
        raw=$(decode "$tok"; printf x); raw=${raw%x}; full="$base/$raw"   # the x keeps a trailing newline in a name
        if [ -L "$full" ]; then cni "$tok" "record is a symbolic link; it is never followed (a link can point outside the root) and was not read"; continue; fi
        if [ ! -e "$full" ]; then cni "$tok" "record vanished between enumeration and reading; it was not scanned"; continue; fi
        if [ ! -f "$full" ]; then cni "$tok" "record is not a regular file (FIFO, socket or device); it is never opened"; continue; fi
        if [ ! -r "$full" ]; then cni "$tok" "record is not readable; it was not scanned"; continue; fi
        if [ "$(tr -d -c '\000' <"$full" | head -c 1 | wc -c)" -ne 0 ]; then
            cni "$tok" "record is binary (NUL bytes); this class reads text records only"; continue
        fi
        if [ -n "$CORPUS" ]; then
            if ! zg_expand "$full" "$TMPW/expanded"; then cni "$tok" "the placeholder expansion failed; it was not scanned"; continue; fi
            full="$TMPW/expanded"
        fi
        cont=0; [ "$raw" = CONTINUATION.md ] && cont=1
        region="$TMPW/region"; : >"$TMPW/long"
        if ! awk -v cont="$cont" -v maxlen="$MAXLINE" -v longf="$TMPW/long" "$AWK_REGION" "$full" >"$region" 2>/dev/null; then
            cni "$tok" "awk could not read the record"; continue
        fi
        inspected=$((inspected + 1))
        while IFS= read -r ln; do
            [ -n "$ln" ] && cni "$tok:$ln" "line exceeds $MAXLINE bytes; no detector read it (the credential scanner takes minutes on such lines)"
        done <"$TMPW/long"
        json=0; case "$raw" in *.json|*.jsonl|*.ndjson) json=1 ;; esac
        if ! hits=$(awk -v priv="$priv" -v json="$json" "$AWK_DETECT" "$region" 2>/dev/null); then
            cni "$tok" "the detector program failed on this record"; continue
        fi
        if [ "$LIBOK" -eq 1 ]; then
            if libl=$(cred_lib_lines "$region"); then
                while IFS= read -r n; do [ -n "$n" ] && hits+=$'\n'"$n"$'\t'C$'\t'constitution-credential-scanner; done <<<"$libl"
            else
                cni "$tok" "the constitution credential scanner failed on this record"
            fi
        fi
        # merge per (line, kind), then emit in line order
        while IFS=$'\t' read -r line cat detail; do
            [ -n "$line" ] || continue
            case "$cat" in
                G) desc="guessing term \"$detail\" (§11.4.6) in a statement outside code fences, quotes and UNCONFIRMED/hypothesis lines: a cause or status must be measured, or marked UNCONFIRMED"
                   printf '%s\t1\tFINDING %s medium false-evidence %s:%s %s %s:%s\n' "$line" "$ID" "$tok" "$line" "$desc" "$tok" "$line" ;;
                C) # T085 masked-output rule (FR-020): the description carries ONLY the location
                   # (already in the FINDING line), the class name ($ID, already in the FINDING
                   # line) and one "[REDACTED len=N]" marker per shape — N is the length of the
                   # WITHHELD value, never the value itself; a shape with no known length (the
                   # constitution scanner, which reports hit/clean only) gets a bare "[REDACTED]".
                   # No line digest, no excerpt: nothing here can be used to recover the secret.
                   marks=""
                   while IFS=: read -r cshape clen; do
                       [ -n "$cshape" ] || continue
                       if [ -n "$clen" ]; then marks="${marks}${marks:+, }$cshape [REDACTED len=$clen]"
                       else marks="${marks}${marks:+, }$cshape [REDACTED]"; fi
                   done < <(printf '%s\n' "$detail" | tr ',' '\n')
                   desc="credential-shaped value in a public record: $marks; the value is never printed (finding, --json output or register description)"
                   printf '%s\t2\tFINDING %s critical security %s:%s %s %s:%s\n' "$line" "$ID" "$tok" "$line" "$desc" "$tok" "$line" ;;
                P) desc="private-content shape ($detail) in a public record: a private repository may be cited by path only, never quoted or transcribed"
                   printf '%s\t3\tFINDING %s critical content-boundary %s:%s %s %s:%s\n' "$line" "$ID" "$tok" "$line" "$desc" "$tok" "$line" ;;
            esac
        done < <(printf '%s\n' "$hits" | awk -F'\t' 'NF == 3 { k = $1 "\t" $2; if (k in d) { if (index("," d[k] ",", "," $3 ",") == 0) d[k] = d[k] "," $3 } else { d[k] = $3; o[++n] = k } }
                                                    END { for (i = 1; i <= n; i++) print o[i] "\t" d[o[i]] }') \
            | LC_ALL=C sort -t$'\t' -k1,1n -k2,2n | cut -f3- >>"$TMPW/find"
    done <<<"$walked"

    found=$(awk 'END { print NR }' "$TMPW/find")
    cat "$TMPW/find"
    for l in "${CNI[@]}"; do echo "COULD-NOT-INSPECT $l"; done
    echo "INSPECTED $inspected"
    echo "POPULATION-SHA $(printf '%s\n' "$walked" | sha256sum | cut -d' ' -f1)"
    if [ "$found" -gt 0 ]; then exit 1; fi
    if [ "${#CNI[@]}" -gt 0 ]; then exit 2; fi
    exit 0
}

# >>> prove-failure harness
# Paired proof on THROWAWAY git repositories under mktemp; the live tree is only READ
# (its population is fingerprinted before and after and must be identical).
prove_failure() (
    local T pass=0 fail=0 skip=0 rc f1 f2 CB CORP FAKEKEY ENTTOK n b loc
    for b in git mktemp sha256sum cmp sed awk grep sort cut chmod id ln head tr od wc env comm; do
        command -v "$b" >/dev/null 2>&1 || { echo "prove-failure: cannot determine — '$b' missing" >&2; exit 2; }
    done
    CB="$LIVE_ROOT/docs/content-boundary.md"
    CORP="$LIVE_ROOT/_tests/fixtures/zero-gap/$ID"
    for b in "$CB" "$CORP/planted" "$CORP/clean" "$CORP/expect.tsv" "$LIVE_ROOT/scripts/zero-gap-lib.sh"; do
        [ -e "$b" ] || { echo "prove-failure: cannot determine — '${b#"$LIVE_ROOT"/}' absent" >&2; exit 2; }
    done
    # shellcheck source=zero-gap-lib.sh
    . "$LIVE_ROOT/scripts/zero-gap-lib.sh" || { echo "prove-failure: cannot determine — zero-gap-lib.sh unreadable" >&2; exit 2; }
    local -a PSPEC=(docs/zero-gap specs/010-zero-gap-verified-closure CONTINUATION.md "_tests/fixtures/zero-gap/$ID" "scripts/zero-gap-class-$ID.sh")
    f1=$(zg_fingerprint "$LIVE_ROOT" "${PSPEC[@]}" 2>/dev/null | cut -d' ' -f1)
    [ -n "$f1" ] || { echo "prove-failure: cannot determine — live fingerprint failed" >&2; exit 2; }
    T=$(mktemp -d) || exit 2
    trap 'chmod -R u+rwx "$T" 2>/dev/null; rm -rf "$T"' EXIT
    ok()  { pass=$((pass + 1)); echo "  PASS $1"; }
    bad() { fail=$((fail + 1)); echo "  FAIL $1"; }
    # run <outfile> [VAR=value...] -- <class args...> : the class under the runner's env -i allow-list
    run() {
        local o=$1; shift; local -a ev=()
        while [ $# -gt 0 ] && [ "$1" != -- ]; do ev+=("$1"); shift; done; shift
        env -i PATH="$PATH" HOME="${HOME:-$T}" TMPDIR="$T" LC_ALL=C LANG=C "${ev[@]}" bash "$SELF" "$@" >"$o" 2>"$o.err"
    }
    has()  { grep -qE -- "$2" "$1"; }                 # has <file> <ERE>
    nfind() { grep -c '^FINDING ' "$1"; }
    mkroot() {
        mkdir -p "$1/docs/zero-gap" "$1/specs/010-zero-gap-verified-closure" &&
        cp "$CB" "$1/docs/content-boundary.md" &&
        cp "$CORP/clean/rule.md" "$1/specs/010-zero-gap-verified-closure/rule.md" &&
        cp "$CORP/clean/progress.yml" "$1/specs/010-zero-gap-verified-closure/progress.yml" &&
        cp "$CORP/clean/CONTINUATION.md" "$1/CONTINUATION.md" &&
        printf 'A clean zero-gap record: the sweep exited 0 on the measured tree.\n' >"$1/docs/zero-gap/notes.md" &&
        git -C "$1" init -q >/dev/null 2>&1
    }
    # secret-shaped values are BUILT at run time, so no literal credential shape sits in this file
    FAKEKEY="AKIA$(printf 'FAKE%.0s' 1 2 3 4)"
    ENTTOK=$(zg_fake_entropy)

    echo "C0 control: clean records"
    mkroot "$T/c" || { echo "prove-failure: cannot build a throwaway repository" >&2; exit 2; }
    run "$T/c.out" -- --root "$T/c"; rc=$?
    if [ "$rc" -eq 0 ] && [ "$(nfind "$T/c.out")" -eq 0 ] && has "$T/c.out" '^INSPECTED 4$'; then ok "C0 rc 0, no finding, INSPECTED 4"; else bad "C0 rc=$rc $(head -c 600 "$T/c.out")"; fi
    run "$T/c.pop" -- --root "$T/c" --emit-population; rc=$?
    if [ "$rc" -eq 0 ] && [ "$(wc -l <"$T/c.pop")" -eq 4 ] \
       && has "$T/c.out" "^POPULATION-SHA $(sha256sum <"$T/c.pop" | cut -d' ' -f1)\$"; then ok "C0 POPULATION-SHA equals the sha of --emit-population (4 items)"; else bad "C0 emit rc=$rc $(cat "$T/c.pop")"; fi
    run "$T/c2.out" -- --root "$T/c"
    if cmp -s "$T/c.out" "$T/c2.out"; then ok "C1 two runs on one state are byte-identical"; else bad "C1 nondeterministic output"; fi

    echo "M1 guessing language in a cause statement"
    mkroot "$T/m1"; printf 'The deploy failed probably because the port was taken.\n' >>"$T/m1/docs/zero-gap/notes.md"
    run "$T/m1.out" -- --root "$T/m1"; rc=$?
    if [ "$rc" -eq 1 ] && has "$T/m1.out" '^FINDING private-in-public medium false-evidence docs/zero-gap/notes\.md:2 .* docs/zero-gap/notes\.md:2$'; then ok "M1 rc 1, medium false-evidence at notes.md:2"; else bad "M1 rc=$rc $(head -c 600 "$T/m1.out")"; fi

    echo "M2 credential shapes (the value never printed)"
    mkroot "$T/m2"; n=$(($(wc -l <"$T/m2/specs/010-zero-gap-verified-closure/rule.md") + 1))
    printf 'aws_access_key_id = %s\n' "$FAKEKEY" >>"$T/m2/specs/010-zero-gap-verified-closure/rule.md"
    run "$T/m2.out" -- --root "$T/m2"; rc=$?
    if [ "$rc" -eq 1 ] && has "$T/m2.out" "^FINDING private-in-public critical security specs/010-zero-gap-verified-closure/rule\\.md:$n "; then ok "M2a rc 1, critical security at rule.md:$n"; else bad "M2a rc=$rc $(head -c 600 "$T/m2.out")"; fi
    if ! grep -qF -- "FAKEFAKE" "$T/m2.out" "$T/m2.out.err"; then ok "M2b the matched value is not in stdout or stderr"; else bad "M2b the value leaked into the output"; fi
    # T085 masked-output rule (FR-020): a credential FINDING's description carries ONLY the
    # location (already in the FINDING line), the class name (private-in-public, field 2) and a
    # redaction marker "[REDACTED len=N]" (N = the length of the withheld value) — no line digest,
    # no recoverable secret text of any kind, in the finding, --json or a register description.
    if has "$T/m2.out" '\[REDACTED len=20\]'; then ok "M2d the finding carries a [REDACTED len=20] marker for the 20-char AKIA shape"; else bad "M2d rc=$rc $(head -c 600 "$T/m2.out")"; fi
    if ! has "$T/m2.out" 'sha256:'; then ok "M2e no line-digest disclosure remains in the description"; else bad "M2e a sha256 line digest is still printed"; fi
    mkroot "$T/m2e"; printf 'session %s here\n' "$ENTTOK" >>"$T/m2e/docs/zero-gap/notes.md"
    run "$T/m2e.out" -- --root "$T/m2e"; rc=$?
    if [ "$rc" -eq 1 ] && has "$T/m2e.out" '^FINDING private-in-public critical security docs/zero-gap/notes\.md:2 ' && ! grep -qF -- "$ENTTOK" "$T/m2e.out" "$T/m2e.out.err"; then ok "M2c high-entropy token found, value not printed"; else bad "M2c rc=$rc $(head -c 600 "$T/m2e.out")"; fi
    if has "$T/m2e.out" '\[REDACTED len=34\]'; then ok "M2f the high-entropy finding also carries [REDACTED len=34]"; else bad "M2f rc=$rc $(head -c 600 "$T/m2e.out")"; fi

    echo "M3 private text: a transcript-shaped passage"
    mkroot "$T/m3"; printf '[00:03:04] SPEAKER 1: a synthetic turn\n' >>"$T/m3/docs/zero-gap/notes.md"
    run "$T/m3.out" -- --root "$T/m3"; rc=$?
    if [ "$rc" -eq 1 ] && has "$T/m3.out" '^FINDING private-in-public critical content-boundary docs/zero-gap/notes\.md:2 '; then ok "M3 rc 1, critical content-boundary"; else bad "M3 rc=$rc $(head -c 600 "$T/m3.out")"; fi

    echo "M4 CONTINUATION.md: only zero-gap entries are read"
    mkroot "$T/m4a"; printf 'It broke, probably because of X.\n' >>"$T/m4a/CONTINUATION.md"
    run "$T/m4a.out" -- --root "$T/m4a"; rc=$?
    if [ "$rc" -eq 0 ] && [ "$(nfind "$T/m4a.out")" -eq 0 ]; then ok "M4a a guessing word outside a zero-gap entry is not read (rc 0)"; else bad "M4a rc=$rc $(head -c 600 "$T/m4a.out")"; fi
    mkroot "$T/m4b"; sed -i.bak '7a\
It broke, probably because of X.' "$T/m4b/CONTINUATION.md"; rm -f "$T/m4b/CONTINUATION.md.bak"
    run "$T/m4b.out" -- --root "$T/m4b"; rc=$?
    if [ "$rc" -eq 1 ] && has "$T/m4b.out" '^FINDING private-in-public medium false-evidence CONTINUATION\.md:8 '; then ok "M4b inside a zero-gap entry => rc 1 at CONTINUATION.md:8"; else bad "M4b rc=$rc $(head -c 600 "$T/m4b.out")"; fi

    echo "M16 population extension (T085): specs/002-*/ through specs/009-*/ are in scope; specs/001-*/ and any specs/010-*/ other than specs/010-zero-gap-verified-closure/ stay out"
    mkroot "$T/m16"
    mkdir -p "$T/m16/specs/002-fake-feature" "$T/m16/specs/009-fake-feature" "$T/m16/specs/001-fake-feature" "$T/m16/specs/010-other-feature"
    printf 'It broke, probably because of Q.\n' >"$T/m16/specs/002-fake-feature/notes.md"
    printf 'It broke, probably because of Q.\n' >"$T/m16/specs/009-fake-feature/notes.md"
    printf 'It broke, probably because of Q.\n' >"$T/m16/specs/001-fake-feature/notes.md"
    printf 'It broke, probably because of Q.\n' >"$T/m16/specs/010-other-feature/notes.md"
    run "$T/m16.out" -- --root "$T/m16"; rc=$?
    if has "$T/m16.out" '^FINDING private-in-public medium false-evidence specs/002-fake-feature/notes\.md:1 ' \
       && has "$T/m16.out" '^FINDING private-in-public medium false-evidence specs/009-fake-feature/notes\.md:1 '; then ok "M16a specs/002-*/ and specs/009-*/ records are now read"; else bad "M16a rc=$rc $(grep -c '^FINDING' "$T/m16.out")"; fi
    if ! has "$T/m16.out" 'specs/001-fake-feature/notes\.md'; then ok "M16b specs/001-*/ stays out of scope"; else bad "M16b specs/001-*/ leaked into the population"; fi
    if ! has "$T/m16.out" 'specs/010-other-feature/notes\.md'; then ok "M16c a specs/010-*/ directory other than specs/010-zero-gap-verified-closure/ stays out of scope"; else bad "M16c specs/010-other-feature/ leaked into the population"; fi
    run "$T/m16.pop" -- --root "$T/m16" --emit-population
    if [ "$(wc -l <"$T/m16.pop")" -eq 6 ]; then ok "M16d --emit-population counts exactly the 4 clean-control records plus the 2 in-scope specs/00[2-9]-*/ records"; else bad "M16d $(cat "$T/m16.pop")"; fi

    echo "M5 empty / absent population"
    mkdir -p "$T/m5/docs"; cp "$CB" "$T/m5/docs/content-boundary.md"; git -C "$T/m5" init -q >/dev/null 2>&1
    run "$T/m5.out" -- --root "$T/m5"; rc=$?
    if [ "$rc" -eq 2 ] && has "$T/m5.out" '^COULD-NOT-INSPECT ' && [ "$(nfind "$T/m5.out")" -eq 0 ]; then ok "M5a zero records => rc 2, never clean"; else bad "M5a rc=$rc $(head -c 600 "$T/m5.out")"; fi
    run "$T/m6.out" -- --root /nonexistent; rc=$?
    if [ "$rc" -eq 2 ] && has "$T/m6.out" '^COULD-NOT-INSPECT '; then ok "M5b --root /nonexistent => rc 2"; else bad "M5b rc=$rc"; fi
    mkdir -p "$T/m5c"; cp -r "$T/c/." "$T/m5c/"; rm -rf "$T/m5c/.git"
    run "$T/m5c.out" -- --root "$T/m5c"; rc=$?
    if [ "$rc" -eq 2 ]; then ok "M5c a root that is not a git work tree => rc 2"; else bad "M5c rc=$rc"; fi

    echo "M7 broken or missing tools"
    mkdir -p "$T/bin"
    for b in bash env git grep sed sort sha256sum od cut tr head wc mktemp rm cat find basename dirname mkdir chmod id ln cmp printf; do
        b=$(command -v "$b" 2>/dev/null) && [ -n "$b" ] && [ "${b#/}" != "$b" ] && ln -sf "$b" "$T/bin/"
    done
    mkroot "$T/m7"
    env -i PATH="$T/bin" HOME="${HOME:-$T}" TMPDIR="$T" LC_ALL=C LANG=C "$T/bin/bash" "$SELF" --root "$T/m7" >"$T/m7.out" 2>&1; rc=$?
    if [ "$rc" -eq 2 ] && has "$T/m7.out" '^COULD-NOT-INSPECT .*awk'; then ok "M7a awk missing => rc 2 naming awk"; else bad "M7a rc=$rc $(head -c 400 "$T/m7.out")"; fi
    run "$T/m8.out" ZG_PIP_CRED_LIB=/nonexistent/credential_scan_lib.sh -- --root "$T/c"; rc=$?
    if [ "$rc" -eq 2 ] && has "$T/m8.out" '^COULD-NOT-INSPECT .*credential'; then ok "M7b credential scanner absent => rc 2"; else bad "M7b rc=$rc $(head -c 400 "$T/m8.out")"; fi
    printf 'HELIX_CRED_VALUE_PATTERN=x\nHELIX_CRED_ADJACENCY_AWK="{}"\nhelix_cred_detector1_real_hit_stream() { cat >/dev/null; return 1; }\n' >"$T/deaf_lib.sh"
    run "$T/m8b.out" ZG_PIP_CRED_LIB="$T/deaf_lib.sh" -- --root "$T/c"; rc=$?
    if [ "$rc" -eq 2 ] && has "$T/m8b.out" '^COULD-NOT-INSPECT .*credential'; then ok "M7c a scanner that never reports a hit fails its canary => rc 2"; else bad "M7c rc=$rc $(head -c 400 "$T/m8b.out")"; fi
    printf 'HELIX_CRED_VALUE_PATTERN=x\nHELIX_CRED_ADJACENCY_AWK="{}"\nhelix_cred_detector1_real_hit_stream() { cat >/dev/null; return 0; }\n' >"$T/loud_lib.sh"
    run "$T/m8c.out" ZG_PIP_CRED_LIB="$T/loud_lib.sh" -- --root "$T/c"; rc=$?
    if [ "$rc" -eq 2 ] && has "$T/m8c.out" '^COULD-NOT-INSPECT .*polarity canary'; then ok "M7e a scanner that reports every line as a hit (inverted polarity) fails its canary => rc 2"; else bad "M7e rc=$rc $(head -c 400 "$T/m8c.out")"; fi
    mkroot "$T/m9"; rm -f "$T/m9/docs/content-boundary.md"
    run "$T/m9.out" -- --root "$T/m9"; rc=$?
    if [ "$rc" -eq 2 ] && has "$T/m9.out" '^COULD-NOT-INSPECT .*content-boundary'; then ok "M7d private-repository table absent => rc 2"; else bad "M7d rc=$rc $(head -c 400 "$T/m9.out")"; fi

    echo "M10 records that cannot be read as text"
    if [ "$(id -u)" -ne 0 ]; then
        mkroot "$T/m10"; chmod 000 "$T/m10/docs/zero-gap/notes.md"
        run "$T/m10.out" -- --root "$T/m10"; rc=$?
        chmod 644 "$T/m10/docs/zero-gap/notes.md"
        if [ "$rc" -eq 2 ] && has "$T/m10.out" '^COULD-NOT-INSPECT docs/zero-gap/notes\.md '; then ok "M10a unreadable record => rc 2"; else bad "M10a rc=$rc $(head -c 400 "$T/m10.out")"; fi
        mkroot "$T/m15"; chmod 000 "$T/m15/docs/zero-gap/notes.md"
        printf 'It failed, probably because of Y.\n' >>"$T/m15/specs/010-zero-gap-verified-closure/progress.yml"
        run "$T/m15.out" -- --root "$T/m15"; rc=$?
        chmod 644 "$T/m15/docs/zero-gap/notes.md"
        if [ "$rc" -eq 1 ] && has "$T/m15.out" '^COULD-NOT-INSPECT ' && has "$T/m15.out" '^FINDING '; then ok "M10b a finding outranks an undetermined (rc 1)"; else bad "M10b rc=$rc"; fi
    else
        skip=$((skip + 2)); echo "  SKIP M10a/M10b running as uid 0: permissions cannot make a file unreadable (not counted as a pass)"
    fi
    mkroot "$T/m11"; head -c 17000 /dev/zero | tr '\0' 'a' >>"$T/m11/docs/zero-gap/notes.md"; printf '\n' >>"$T/m11/docs/zero-gap/notes.md"
    run "$T/m11.out" -- --root "$T/m11"; rc=$?
    if [ "$rc" -eq 2 ] && has "$T/m11.out" '^COULD-NOT-INSPECT docs/zero-gap/notes\.md:2 '; then ok "M10c a line over 16384 bytes => rc 2 naming item:line"; else bad "M10c rc=$rc $(head -c 400 "$T/m11.out")"; fi
    mkroot "$T/m12"; printf 'a\0b\n' >"$T/m12/docs/zero-gap/blob.bin"
    run "$T/m12.out" -- --root "$T/m12"; rc=$?
    if [ "$rc" -eq 2 ] && has "$T/m12.out" '^COULD-NOT-INSPECT docs/zero-gap/blob\.bin '; then ok "M10d a binary record => rc 2"; else bad "M10d rc=$rc $(head -c 400 "$T/m12.out")"; fi

    echo "M14 planted corpus: exact recall, clean control silent"
    run "$T/cp.out" -- --root "$LIVE_ROOT" --corpus "$CORP/planted"; rc=$?
    grep '^FINDING ' "$T/cp.out" | cut -d' ' -f5 | LC_ALL=C sort -u >"$T/cp.got"
    grep -v '^#' "$CORP/expect.tsv" | awk -F'\t' 'NF { print $1 }' | LC_ALL=C sort -u >"$T/cp.want"
    if [ "$rc" -eq 1 ] && cmp -s "$T/cp.got" "$T/cp.want"; then ok "M14a planted/ => rc 1, found set == expect.tsv ($(wc -l <"$T/cp.want") locations)"; else bad "M14a rc=$rc missing=[$(comm -13 "$T/cp.got" "$T/cp.want" | tr '\n' ' ')] unexpected=[$(comm -23 "$T/cp.got" "$T/cp.want" | tr '\n' ' ')]"; fi
    run "$T/cc.out" -- --root "$LIVE_ROOT" --corpus "$CORP/clean"; rc=$?
    if [ "$rc" -eq 0 ] && [ "$(nfind "$T/cc.out")" -eq 0 ]; then ok "M14b clean/ => rc 0, no finding"; else bad "M14b rc=$rc $(grep '^FINDING' "$T/cc.out" | cut -d' ' -f5 | tr '\n' ' ')"; fi
    if ! grep -qF -- "FAKEFAKE" "$T/cp.out" "$T/cp.out.err" && ! grep -qF -- "$ENTTOK" "$T/cp.out" "$T/cp.out.err" && ! grep -qF -- "FakePass" "$T/cp.out" "$T/cp.out.err"; then ok "M14c no planted secret value is printed"; else bad "M14c a planted secret value was printed"; fi
    if [ "$(grep -c '^FINDING private-in-public critical security secret\.md:[3-6] ' "$T/cp.out")" -eq 4 ]; then ok "M14d the four placeholders of secret.md expand at scan time into four credential findings (lines 3-6)"; else bad "M14d $(grep 'secret\.md' "$T/cp.out" | cut -d' ' -f1-5 | tr '\n' ' ')"; fi

    echo "R1 the corpus holds NO secret-shaped text at rest (placeholders only)"
    mkroot "$T/r1"; n=0
    for b in "$CORP"/planted/* "$CORP"/clean/*; do n=$((n + 1)); cp "$b" "$T/r1/docs/zero-gap/at-rest-$n-$(basename "$b")"; done
    run "$T/r1.out" -- --root "$T/r1"; rc=$?
    if [ "$(grep -c '^FINDING private-in-public critical security ' "$T/r1.out")" -eq 0 ] && has "$T/r1.out" "^INSPECTED $((4 + n))\$"; then
        ok "R1 every corpus file scanned UNEXPANDED (live mode) yields no credential finding"
    else bad "R1 rc=$rc $(grep 'critical security' "$T/r1.out" | cut -d' ' -f1-5 | tr '\n' ' ')"; fi
    if ! grep -rqE -- 'AKIA[A-Z0-9]{16}|-----BEGIN [A-Z ]*PRIVATE KEY|://[^/ @]+:[^/ @]+@' "$CORP"; then ok "R2 no AWS-key, private-key header or URL-password shape anywhere under the corpus"; else bad "R2 a secret shape is stored at rest in the corpus"; fi

    echo "S symlinks, non-regular files and odd names"
    mkroot "$T/s1"; printf 'It failed, probably because of Z.\n' >"$T/outside.md"; ln -s "$T/outside.md" "$T/s1/docs/zero-gap/link.md"
    run "$T/s1.out" -- --root "$T/s1"; rc=$?
    if [ "$rc" -eq 2 ] && has "$T/s1.out" '^COULD-NOT-INSPECT docs/zero-gap/link\.md .*symbolic link' && [ "$(nfind "$T/s1.out")" -eq 0 ]; then ok "S1 a symlinked record => COULD-NOT-INSPECT, its target outside the root never read"; else bad "S1 rc=$rc $(head -c 400 "$T/s1.out")"; fi
    mkdir -p "$T/s2"; cp "$CORP/clean/rule.md" "$T/s2/"
    if mkfifo "$T/s2/pipe.md" 2>/dev/null; then
        env -i PATH="$PATH" HOME="${HOME:-$T}" TMPDIR="$T" LC_ALL=C LANG=C timeout -k 2 20 bash "$SELF" --root "$T/c" --corpus "$T/s2" >"$T/s2.out" 2>&1; rc=$?
        if [ "$rc" -eq 2 ] && has "$T/s2.out" '^COULD-NOT-INSPECT pipe\.md .*not a regular file'; then ok "S2 a FIFO record => COULD-NOT-INSPECT, never opened (no hang)"; else bad "S2 rc=$rc $(head -c 400 "$T/s2.out")"; fi
    else skip=$((skip + 1)); echo "  SKIP S2 mkfifo unavailable (not counted as a pass)"; fi
    mkroot "$T/s3"; printf 'It failed, probably because of W.\n' >"$T/s3/docs/zero-gap/odd"$'\n'
    run "$T/s3.out" -- --root "$T/s3"; rc=$?
    if [ "$rc" -eq 1 ] && has "$T/s3.out" '^FINDING private-in-public medium false-evidence docs/zero-gap/odd%0A:1 '; then ok "S3 a record whose name ends in a newline is read (not mislabelled unreadable)"; else bad "S3 rc=$rc $(head -c 400 "$T/s3.out")"; fi

    echo "Q quotations: the record syntax and path references are not quotations"
    mkroot "$T/q1"; printf '  - "Ruling: the notes in workshop/chapters/01/notes.md say \\"a planted synthetic sentence copied verbatim here\\" today."\n' >>"$T/q1/specs/010-zero-gap-verified-closure/progress.yml"
    run "$T/q1.out" -- --root "$T/q1"; rc=$?
    if [ "$rc" -eq 1 ] && has "$T/q1.out" '^FINDING private-in-public critical content-boundary specs/010-zero-gap-verified-closure/progress\.yml:[0-9]+ '; then ok "Q1 an escaped quotation inside a YAML scalar attributed to a private path IS found"; else bad "Q1 rc=$rc $(head -c 400 "$T/q1.out")"; fi
    # Q2/Q3 (fix round F2, rev-base-B C1): a sweep report.json names private paths inside JSON string
    # values; the string delimiters are record syntax, never a quotation — only a quotation INSIDE a
    # string value (\" or “...”) is one.
    mkroot "$T/q2"; mkdir -p "$T/q2/specs/010-zero-gap-verified-closure/baseline"
    {   printf '{\n  "findings": [\n'
        printf '    {"class": "build-if-missing", "severity": "medium", "location": "workshop/platform/scripts/restart.sh:17", "description": "builds only when the artefact is absent with no freshness guard", "evidence_ref": "workshop/platform/scripts/restart.sh:17"},\n'
        printf '    {"class": "x", "location": "ai_interviewing/docs/planted.md", "description": "a path only reference in a many word value"}\n  ]\n}\n'
    } >"$T/q2/specs/010-zero-gap-verified-closure/baseline/report.json"
    printf '{"location": "monetization/plan.txt:3", "description": "one JSON line naming a private path by path only"}\n' >"$T/q2/docs/zero-gap/rows.jsonl"
    run "$T/q2.out" -- --root "$T/q2"; rc=$?
    if [ "$rc" -eq 0 ] && [ "$(nfind "$T/q2.out")" -eq 0 ]; then ok "Q2 JSON/JSONL string values naming private paths are NOT a quotation (rc 0)"; else bad "Q2 rc=$rc $(grep '^FINDING' "$T/q2.out" | cut -d' ' -f5 | tr '\n' ' ')"; fi
    mkroot "$T/q3"
    {   printf '{"location": "workshop/chapters/01/notes.md:3", "description": "the notes say \\"a planted synthetic sentence copied verbatim here\\" today"}\n'
        printf '{"location": "workshop/chapters/01/notes.md:4", "description": "the notes say \\u201ca planted synthetic unicode escaped quotation\\u201d today"}\n'
    } >"$T/q3/docs/zero-gap/rows.jsonl"
    run "$T/q3.out" -- --root "$T/q3"; rc=$?
    if [ "$rc" -eq 1 ] && has "$T/q3.out" '^FINDING private-in-public critical content-boundary docs/zero-gap/rows\.jsonl:1 ' \
       && has "$T/q3.out" '^FINDING private-in-public critical content-boundary docs/zero-gap/rows\.jsonl:2 '; then ok "Q3 a quotation INSIDE a JSON string value (\\\" and \\u201c escapes) IS found"; else bad "Q3 rc=$rc $(head -c 400 "$T/q3.out")"; fi

    echo "L live population (read-only)"
    run "$T/lp.out" -- --root "$LIVE_ROOT" --emit-population; rc=$?
    if [ "$rc" -eq 0 ] && [ -s "$T/lp.out" ] && ! grep -q '^_tests/fixtures/zero-gap/' "$T/lp.out"; then ok "L1 live population non-empty ($(wc -l <"$T/lp.out") items), excludes _tests/fixtures/zero-gap/"; else bad "L1 rc=$rc"; fi
    f2=$(zg_fingerprint "$LIVE_ROOT" "${PSPEC[@]}" 2>/dev/null | cut -d' ' -f1)
    if [ "$f1" != "$f2" ]; then
        echo "prove-failure: cannot determine — the live population changed while the proof ran (a concurrent editor cannot be told apart from this proof)" >&2
        echo "== $pass passed, $fail failed, $skip skipped — UNDETERMINED"; exit 2
    fi
    ok "L2 live population byte-identical before and after"
    echo "== $pass passed, $fail failed, $skip skipped"
    if [ "$fail" -gt 0 ]; then exit 1; fi
    exit 0
)
# <<< prove-failure harness

case "${1:-}" in
    --prove-failure)
        prove_failure; exit $? ;;
esac
main "$@"
