#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# verify-content-boundary.sh — FAIL when content that exists only in a PRIVATE
# repository of this fleet appears inside a PUBLIC one.
#
# WHY THIS EXISTS
# ---------------
# This tree is an umbrella whose gitlinks span both visibilities. A gitlink in a
# public repository exposes a commit SHA and nothing else, so material inside a
# private submodule stays private *as long as nobody copies it out*. That
# protection is one careless quote away from failing: a single paragraph of a
# private teaching session pasted into a public `docs/` or `specs/` file is
# public permanently and irreversibly, because it is then in a public
# repository's history and history is not editable after a push.
#
# The pressure that produces exactly that mistake is ordinary and constant:
# agents and humans documenting the work comprehensively, reaching for an
# illustrative quote. Nothing in this repository measured it before this script.
#
# WHAT IT IS NOT
# --------------
# It is NOT a secret scanner (no entropy heuristics, no credential patterns) and
# it is NOT a licence checker. It answers three questions, one per key space:
#
#   prose  does a run of >= --window normalised tokens from a private
#          repository also exist, verbatim, in a public one?
#   short  does a private document's own HEADING / list item / caption line —
#          which is far shorter than that window — appear in a public file?
#   name   does a personal name that exists only in a private repository appear
#          in a public file, in either order?
#
# ── WHY "short" AND "name" EXIST: the 2026-09-01 incident ────────────────────
# The prose pass alone scored two public files CLEAN while both reproduced a
# private notes document's complete section-heading list, and while a third
# party's full real name stood in three public locations. THREE independent
# barriers stacked to make that invisible, and lowering one of them alone would
# not have helped:
#
#   1. the WINDOW. Five of the seven headings are five or six tokens long, so
#      no shingle of them is ever built at 8, at 10, or at anything above 6.
#   2. the 40-CHARACTER floor. A five-token phrase needs an average word length
#      of 7.2 to clear it. Most headings do not.
#   3. PROSE-SHAPE, ">= 2 distinct function words". A heading is a noun phrase.
#      "Nightly ingest of the partner catalogue" has one.
#
# Reproduce all three with a synthetic fixture:
#   scripts/verify-content-boundary.sh --prove-failure     (cases M11, M12, M17)
# M11b and M17a are the paired halves: the same planted heading, with the short
# pass switched off, still scores rc 0. That is the defect, demonstrated.
#
# ── WHY THE SHORT PASS DOES NOT RESURRECT THE FALSE-POSITIVE FLOOD ──────────
# Because its precision does not come from the window. Dropping to a 5-token
# window with the old filters produced 8,535 short-class rows on this tree —
# unusable, and exactly the outcome the 24,963-hit naive form was rejected for.
# The short pass buys its precision back from the private document's own
# STRUCTURE instead, and the measured cost of each step is recorded here:
#
#   8,535  5-token windows, private side unrestricted
#     -63% the private line must be PROSE, not code or markup (no {}<>=|;~$@#_/`
#          characters). This alone removes the whole CSS / SCSS / HTML / Go /
#          go.sum contribution.
#     ...  the private line must be a HEADING, a LIST ITEM or a line that OPENS
#          a block, and be <= --short-line-max tokens long. A short line in the
#          middle of a wrapped paragraph is ordinary prose the long pass
#          already covers.
#      35  final, measured 2026-09-01 on this tree.
#
# The PUBLIC side is deliberately unrestricted: in the public file the same
# words may sit mid-paragraph, inside a bullet, or be re-wrapped by the editor
# that pasted them. Narrowing what may BECOME a candidate is safe; narrowing
# where it may be FOUND would be a new blind spot.
#
# ── The false-positive problem, which is the whole difficulty ────────────────
# A naive "grep the private files' lines in the public tree" is worthless here,
# and that is measured, not asserted: on this tree the naive form produced
# 24,963 hits, of which the top thirty were ALL legitimate — design tokens the
# public `design-system/` deliberately consumes from a private design toolkit,
# governance carriers propagated verbatim by §11.4.157 lockstep, and staged
# carrier copies under `docs/constitution-adoption/propagation/` whose entire
# purpose is to be byte-identical to their destination. A gate that reports
# 24,963 findings gets switched off in a week, and then the real leak ships.
#
# So four filters run, three of them DERIVED (recomputed every run from the
# repositories themselves, nothing baked in) and one DECLARED:
#
#   1. PROSE-SHAPE (derived). A leak of a session transcript is natural
#      language. A shingle qualifies only if it carries >= 2 distinct English
#      function words and >= 5 alphabetic tokens of length >= 3. This removes
#      CSS declarations, minified markup and code boilerplate, which on this
#      tree were the single largest residual class (measured: 1,731 -> 1,216
#      after the earlier filters, and it is what removes ~9,000 hits of shared
#      `:root{--od-*}` token blocks). DECLARED LIMIT: the model is English
#      prose. Private *code* copied into a public repository is outside this
#      instrument and is not claimed to be covered.
#
#   1b. PROSE-LINE (derived, short + name classes only). The PRIVATE line a
#      short key or a name candidate comes from must contain none of
#      `{}<>=|;~$@#_/` and no `](`. Code, markup, CSS, `go.sum` and JSON are
#      not documents and do not have headings or participants. Measured: it
#      removes 63% of the short class and 63% of the name class in one step.
#
#   1c. STRUCTURAL (derived, short class only). The PRIVATE line must carry a
#      heading / bullet marker OR open a block, and be <= --short-line-max
#      tokens. A short line in the middle of a wrapped paragraph is ordinary
#      prose that the long pass already covers.
#
#   2. PATH-REFERENCE (derived). A public file may legitimately NAME a private
#      path or filename — `workshop/chapters/01/<recording>.mp4` in a build
#      command is a REFERENCE, not a disclosure of what was said in it. The
#      private repositories' own tracked paths and basenames are read from
#      `git ls-files`, shingled the same way, and subtracted. This is derived
#      from the private index, so it needs no maintenance when files are added.
#      On this tree it is what correctly clears the recording's filename where
#      it is quoted in planning documents, while leaving a quotation of the
#      recording's NOTES standing.
#
#   3. ALREADY-PUBLIC (derived). A shingle found in TWO OR MORE distinct public
#      repositories is already public: republishing it discloses nothing that
#      was not already disclosed. On this tree this one rule removes 99% of the
#      noise (165,638 -> 1,765 for the umbrella) without a single hand-written
#      exception. ITS BOUNDARY IS STATED RATHER THAN HIDDEN: it cannot exonerate
#      and is not meant to exonerate a passage leaked into two public
#      repositories at once, and every shingle it clears is COUNTED and its
#      private source files are NAMED in the summary. It is never silent.
#
#   3b. NAME PATH-REFERENCE (derived, name class only). A candidate whose
#      EVERY token already appears in the private source path or in the public
#      file's own path is naming the document's subject, not a person. EVERY,
#      never "any": the one artefact in this fleet whose filename carries a
#      participant's FIRST name would otherwise pardon that person's full name.
#
#   3c. NAME JUNCTION (derived, name class only, BOTH sides). Two capitalised
#      tokens form a name candidate only when what stands between them is
#      something a personal name may actually contain: whitespace, at most one
#      hyphen, at most one comma. See `sepcode`/`junctions` below.
#
#      WHY THIS IS NOT A NARROWING OF WHERE A NAME MAY BE FOUND, and therefore
#      why it applies to the public side too, against the usual doctrine: the
#      old N pass folded EVERY non-alphanumeric run into one separator, which
#      fused list items into a single "name". `A/B/C` became one capitalised
#      run. That run stands in NEITHER text — it is a tokeniser defect, not a
#      filter, and fixing it on one side only would leave the two corpora
#      normalised differently, which is the one thing this script's header
#      says must never happen.
#
#      Measured on this tree 2026-09-01: 67 of the 125 surviving name rows
#      (54%) came from exactly this fusion and every one of them was a false
#      positive. Route (a), the git identities, contributed ZERO rows; every
#      finding came from route (b), the capitalised-run route this rule fixes.
#
#      THE COMMA IS ALLOWED, DELIBERATELY. Breaking on it would remove a
#      further 15 rows (12%) and 4 more distinct findings, all comma-separated
#      enumerations of product names — but `Surname, Firstname` is a real
#      personal-name rendering, it is the form an index, a bibliography and an
#      attendance roster use, and the comma is the ONLY punctuation it
#      contains. Order-insensitive matching (mutation M15) exists precisely to
#      catch it, and a comma break would delete the shape it matches. A
#      series-scoped exception ("break only inside a run of three or more
#      comma-separated capitalised items") was designed and REJECTED: it
#      false-breaks the ordinary appositive `Surname, Firstname, who chaired`,
#      which is exactly the leaked-roster prose it would exist to protect. The
#      15 rows are therefore a DECLARED, measured, unfixed noise source, not a
#      hidden one.
#
#      AN INTRA-WORD HYPHEN IS ALLOWED for the same kind of reason and was the
#      triage's own fourth, not-recommended proposal: breaking on it would
#      clear 7 more rows and cost every double-barrelled given name.
#
#   3d. NAME PARAGRAPH BREAK (derived, name class only, both sides). A
#      capitalised run may be re-wrapped onto the next line — that is a real
#      leak shape and mutation M19 keeps it caught — but it may not bridge a
#      TOKEN-FREE line. A person is not written across a paragraph break, a
#      horizontal rule, or a PDF page break. Measured: 2 further rows.
#
#   4. DECLARED (`.content-boundary-allow`). Content that flows between a
#      specific private path and a specific public path BY DESIGN. Entries are
#      PAIRS — one private glob, one public glob, one mandatory reason — so an
#      exemption authorising design tokens to reach `design-system/` does not
#      also authorise a transcript to reach it. Same shape and same discipline
#      as `.hardcoded-paths-allow`: an unexplained suppression is a bluff.
#
# ── Fleet derivation (nothing is hardcoded) ──────────────────────────────────
# The fleet is read from `.gitmodules` plus this tree's own remote, exactly as
# gate_E and the audits do. Visibility is asked of the PROVIDER, never assumed
# and never inferred from a name: a repository can be flipped private-to-public
# in one click, and a list baked into this file would then be quietly wrong.
# A repository whose visibility cannot be established is UNVERIFIED and is
# never treated as a pass.
#
# Scan TARGETS are public repositories we can actually push, with push
# permission taken from the provider's own report — the same ownership
# derivation `scripts/verify-provider-ci.sh` uses for §11.4.156(C). A public
# upstream we cannot push is not a repository we can leak into from here, and
# is reported OUT-OF-SCOPE rather than scanned.
#
# ── Usage ────────────────────────────────────────────────────────────────────
#   scripts/verify-content-boundary.sh [options]
#     --root <dir>        tree to inspect (default: this script's parent)
#     --json              machine-readable on stdout, human log on stderr
#     --quiet             verdict + counts only
#     --list-fleet        print the derived public/private map and exit 0
#     --window <n>        long-pass shingle width in tokens (default 10)
#     --short-window <n>  short-pass width in tokens (default 5, minimum 3)
#     --short-line-max <n> longest private line that may still be a heading
#                         (default 9; above it the line is treated as prose)
#     --no-short          disable the short pass  (used by the paired proof to
#                         demonstrate the ORIGINAL defect; never for a real run)
#     --no-names          disable the personal-name pass
#     --name-rank <n>     the n most frequent corpus tokens count as ordinary
#                         words and may not form a name (default 2000)
#     --name-ppm <n>      a token occurring >= n times per MILLION private prose
#                         tokens is an ordinary word and may not form a name
#                         (default 25; rank-independent, so it tracks the corpus
#                         instead of a fixed position in it). 0 disables it.
#     --name-floor <n>    absolute form of the same floor, in occurrences; it
#                         overrides --name-ppm. 0 disables the floor. Used by
#                         the paired proof, where a fixture is far too small for
#                         any per-million rate to reach 1.
#     --allow <file>      declared-exemption file (default <root>/.content-boundary-allow)
#     --fleet-spec <f>    SYNTHETIC fleet for the paired proof; see below
#     --prove-failure     run the §1.1 paired mutation battery and exit
#     --help              this text
#
# ── Exit codes (three-valued, this project's convention) ─────────────────────
#     0  no private-only prose was found in any in-scope public repository
#     1  LEAK: at least one surviving match, private side and public side both
#        named, with the matched text and a file:line on the public side
#     2  COULD NOT DETERMINE — visibility unknown for a repository in the fleet,
#        no provider client, unauthenticated, a private submodule not
#        initialised, a private PDF with no text extractor available, or a
#        malformed exemption file.
#   Precedence: 1 outranks 2. A leak is a FACT and is reported as one; the rows
#   that could not be checked are printed on EVERY run regardless of the exit
#   code, so a 1 never hides a 2 and a 2 never reads as a 0. An empty result
#   with unresolved rows is 2 — never 0. "I could not look" is not "clean".
#
# ── --fleet-spec, stated openly because it is a bypass shape ────────────────
# The paired proof needs a fleet whose roles are true BY CONSTRUCTION: a
# synthetic tree has no provider, so its visibility is unknowable and every
# synthetic control would exit 2 and prove nothing. `--fleet-spec` supplies
# `path<TAB>role` rows for such a tree. It is fenced so it cannot whitewash a
# real run: it REQUIRES `--root`, it REFUSES to run when the resolved root is
# the repository this script itself lives in, every output line is marked
# SYNTHETIC FLEET, and the JSON carries "fleet_source":"spec". A --fleet-spec
# run is not evidence about this repository and says so in its own summary.
#
# ── What this instrument STILL cannot see — declared, not implied away ──────
#   * a 5-to-9 token fragment lifted from the MIDDLE of a long private prose
#     line. The short pass indexes structural lines only; the long pass needs
#     --window tokens. Fragments in that band are covered by neither.
#   * non-ASCII text of any kind. Tokenisation is `[^A-Za-z0-9]` — Cyrillic,
#     Greek and CJK private material is invisible to every pass, and so is a
#     name written in them. This predates the short and name passes and is not
#     fixed by them.
#   * a name written in lowercase, or with a non-`Aa+` shape (`McDonald`,
#     `O'Brien`, a single mononym, an all-caps rendering).
#   * a name so frequent in the private corpus that its tokens enter the
#     --name-rank common set OR reach the --name-ppm frequency floor, or that
#     appears in >= 2 public repositories. THE FLOOR IS THE SHARPEST OF THESE
#     AND IT GROWS WITH THE CORPUS: at 25 ppm over the 1,325,163 private prose
#     tokens measured on 2026-09-01 the floor is 33 occurrences, while the two
#     real given names present in this corpus occur 5 and 11 times. A recurring
#     participant in a longer course WILL cross it. Route (a), the git
#     identities, is deliberately exempt from the floor and is the only thing
#     that still sees such a person — and only if they commit.
#   * a name whose two tokens are separated by anything other than whitespace,
#     one hyphen or one comma. That is what makes `A/B/C` stop reading as a
#     name, and it costs: a name split across two markdown TABLE CELLS
#     (`| Firstname | Surname |`), across two code spans, across two path
#     segments, or written with any non-ASCII comma (`、`, `،`) is no longer
#     seen. Measured on this tree the rule removed 67 of 125 rows and cost no
#     observed true positive, but the blind spot is real and is declared here
#     rather than implied away.
#   * a name whose two tokens sit on either side of a token-free line. A person
#     is never written across a paragraph break, a horizontal rule or a PDF
#     page break — but a name genuinely re-wrapped onto the NEXT line is still
#     seen, and mutation M19 holds that open.
#   * private CODE copied into a public repository (prose-shape filter, and now
#     also the short pass's prose-line rule).
#   * translated, paraphrased or reordered content. This is a verbatim matcher.
#   * anything in git HISTORY. Every pass reads the working tree only.
#
# ── Side effects ─────────────────────────────────────────────────────────────
# NONE. Every provider call is a read. No git command that writes is run: no
# fetch, no push, no checkout, no submodule update, no config write. Nothing in
# any working tree is modified. This script reports; the operator decides.
#
# ── Dependencies ─────────────────────────────────────────────────────────────
# Required: bash 4+, git, awk, sort, comm. Optional: `gh` authenticated (absence
# makes github.com rows UNVERIFIED -> exit 2, never a pass); `pdftotext` for
# PDF-borne private material (absence makes those files UNREADABLE -> exit 2,
# because the most sensitive artefact in this fleet is a PDF and silently
# skipping it would be the exact bluff §11.4 forbids).
# ------------------------------------------------------------------------------
set -uo pipefail

# Every sort/comm/join below must agree on collation. Without this, `sort`
# collates by locale while `join` assumes byte order, and join silently
# produces WRONG output — a false negative in a leak detector, which is the
# one failure mode this instrument must not have.
export LC_ALL=C

ROOT_DEFAULT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
SELF_REPO="$ROOT_DEFAULT"
ROOT="$ROOT_DEFAULT"
JSON=0
QUIET=0
LIST_ONLY=0
WIDTH=10
ALLOW_FILE=""
FLEET_SPEC=""
PROVE=0
MIN_CHARS=40

# ── short pass (class D2: headings, list items, captions) ────────────────────
# A separate, NARROWER pass. Its strictness does not come from the window — it
# comes from the private side's own document STRUCTURE: only a private source
# LINE short enough to be a heading, a list item, a table cell or a caption
# contributes short keys at all. See the header note "Why the short pass does
# not resurrect the false-positive flood".
DO_SHORT=1
SHORT_W=5           # window for the short pass, in tokens
SHORT_MINC=20       # character floor for a short shingle (long pass uses 40)
SHORT_MINAL=4       # alphabetic tokens of length >= 3 required, out of SHORT_W
SHORT_LINEMAX=9     # a private line longer than this is prose, not a heading

# ── name pass (class D3: a real person's full name) ──────────────────────────
DO_NAMES=1
NAME_RANK=2000      # the N most frequent corpus tokens are "common words"
NAME_MINCOUNT=5     # ... but only when they actually occur this often
NAME_IDENT_MAX=5000 # commits walked per repo when deriving git identities
# An absolute RANK is not scale-free: rank 2000 means something different in a
# 16k-token vocabulary than in a 200k one, and on this tree it is far too weak
# — every token of every surviving false positive sat BELOW it (ranks 2167 to
# 14849), several of them occurring 45 to 80 times. The floor below is
# rank-independent and expressed per MILLION prose tokens, so it tracks the
# corpus instead of a fixed position in it, and it is 0 in a small fixture,
# where nothing can clear it and no candidate is lost.
NAME_PPM=25         # >= this many occurrences per million prose tokens = ordinary
NAME_FLOOR=-1       # absolute override; -1 = derive from NAME_PPM, 0 = disabled

usage() { awk 'NR==1{next} /^#/{sub(/^# ?/,""); print; next} {exit}' "${BASH_SOURCE[0]}"; }

while [[ $# -gt 0 ]]; do
    case "$1" in
        --root)        ROOT="$(cd -- "${2:-}" 2>/dev/null && pwd)" || { echo "FATAL: --root: no such directory '${2:-}'" >&2; exit 2; }; shift 2 ;;
        --json)        JSON=1; shift ;;
        --quiet)       QUIET=1; shift ;;
        --list-fleet)  LIST_ONLY=1; shift ;;
        --window)      WIDTH="${2:-10}"; shift 2 ;;
        --short-window) SHORT_W="${2:-5}"; shift 2 ;;
        --short-line-max) SHORT_LINEMAX="${2:-12}"; shift 2 ;;
        --no-short)    DO_SHORT=0; shift ;;
        --no-names)    DO_NAMES=0; shift ;;
        --name-rank)   NAME_RANK="${2:-2000}"; shift 2 ;;
        --name-ppm)    NAME_PPM="${2:-25}"; shift 2 ;;
        --name-floor)  NAME_FLOOR="${2:-0}"; shift 2 ;;
        --allow)       ALLOW_FILE="${2:-}"; shift 2 ;;
        --fleet-spec)  FLEET_SPEC="${2:-}"; shift 2 ;;
        --prove-failure) PROVE=1; shift ;;
        --help|-h)     usage; exit 0 ;;
        *)             echo "FATAL: unknown option '$1' (try --help)" >&2; exit 2 ;;
    esac
done

[[ "$WIDTH" =~ ^[0-9]+$ && "$WIDTH" -ge 5 ]] || { echo "FATAL: --window expects an integer >= 5" >&2; exit 2; }
[[ "$SHORT_W" =~ ^[0-9]+$ && "$SHORT_W" -ge 3 ]] || { echo "FATAL: --short-window expects an integer >= 3" >&2; exit 2; }
[[ "$SHORT_LINEMAX" =~ ^[0-9]+$ && "$SHORT_LINEMAX" -ge "$SHORT_W" ]] || { echo "FATAL: --short-line-max expects an integer >= --short-window" >&2; exit 2; }
[[ "$NAME_RANK" =~ ^[0-9]+$ ]] || { echo "FATAL: --name-rank expects an integer" >&2; exit 2; }
[[ "$NAME_PPM" =~ ^[0-9]+$ ]] || { echo "FATAL: --name-ppm expects a non-negative integer" >&2; exit 2; }
[[ "$NAME_FLOOR" =~ ^-?[0-9]+$ && "$NAME_FLOOR" -ge -1 ]] || { echo "FATAL: --name-floor expects an integer >= 0" >&2; exit 2; }
[[ $DO_SHORT -eq 1 ]] || SHORT_W=0
[[ -n "$ALLOW_FILE" ]] || ALLOW_FILE="$ROOT/.content-boundary-allow"

if [[ $JSON -eq 1 ]]; then exec 3>&2; else exec 3>&1; fi
say() { printf '%s\n' "$*" >&3; }
vsay() { [[ $QUIET -eq 1 ]] || printf '%s\n' "$*" >&3; }

if [[ -t 1 && $JSON -eq 0 ]]; then
    C_RED=$'\033[0;31m'; C_GRN=$'\033[0;32m'; C_YEL=$'\033[1;33m'
    C_DIM=$'\033[2m'; C_BLD=$'\033[1m'; C_OFF=$'\033[0m'
else
    C_RED=""; C_GRN=""; C_YEL=""; C_DIM=""; C_BLD=""; C_OFF=""
fi

# ══════════════════════════════════════════════════════════════════════════════
# §1.1 PAIRED MUTATION PROOF
#
# The control is SYNTHETIC — green BY CONSTRUCTION — and the live tree is only a
# REPORTED pre-flight that cannot disable the battery. That shape is deliberate
# and is the fix this repository already had to make twice: a proof that
# baselines against the live tree runs ZERO mutations the moment the live tree
# has a real finding, exits non-zero, and has proved nothing while looking busy.
# This gate is EXPECTED to be red on this tree today, so a live-tree control
# would have been inoperative from its first run.
# ══════════════════════════════════════════════════════════════════════════════
P_PASS=0; P_FAIL=0
p_case() { # $1 name  $2 expected  $3 got  $4 ok(0/1)  $5 detail
    if [[ "$4" -eq 0 ]]; then
        P_PASS=$((P_PASS + 1)); printf 'PASS  %-44s expected %-22s got %s\n' "$1" "$2" "$3"
    else
        P_FAIL=$((P_FAIL + 1)); printf 'FAIL  %-44s expected %-22s got %s\n' "$1" "$2" "$3"
        [[ -n "${5:-}" ]] && printf '      %s\n' "$5"
    fi
}

mkrepo() { # $1 dir — a real git repo with one commit, no remote
    mkdir -p "$1"
    git -C "$1" init -q 2>/dev/null
    git -C "$1" config user.email proof@example.invalid
    git -C "$1" config user.name proof
    git -C "$1" add -A >/dev/null 2>&1
    git -C "$1" -c commit.gpgsign=false commit -qm seed --allow-empty >/dev/null 2>&1
}

# EVERY FIXTURE STRING BELOW IS SYNTHETIC AND WAS WRITTEN FOR THIS PROOF.
# No heading, sentence or name from any real private document appears here. A
# fixture that carried the real leaked content would re-leak it into this
# public repository — the proof would become the incident.
#
# The two personal names are invented token pairs, chosen to be name-SHAPED
# (`^[A-Z][a-z]+$` twice over) and to belong to nobody.
build_fixture() { # $1 base dir — synthetic public umbrella + private submodule
    local b="$1"
    mkdir -p "$b/pub/docs" "$b/pub/priv/chapters"
    # Private material: prose that exists nowhere public. Note the SHAPE — four
    # short section headings, each followed by its own body text, exactly the
    # structure of a meeting-notes document. Headings are 5 and 6 tokens long,
    # which is the class the long window cannot see.
    cat >"$b/pub/priv/chapters/notes.txt" <<'PRIVEOF'
Session notes

The review pipeline and escalation ladder
  - queue depth was raised twice during the trial week and nobody noticed it
  - the second reviewer is optional whenever the score exceeds the threshold

Nightly ingest of the partner catalogue
  - the feed arrives late on the days when the upstream export has to be retried
  - duplicate rows are dropped before the reconciliation step begins each night

The deployment checklist and escalation
  - the rollback rehearsal is skipped whenever the change window is under an hour
  - paging goes to the secondary rota after midnight in every one of the regions

Quarterly forecast for the regional cohorts
  - the northern cohort grew faster than the model had predicted for the spring
  - renewal assumptions were revised downward after the pricing change was made

The participant asked how the orchestration layer decides which model to call
and whether the routing table is refreshed between sessions or pinned for the
duration of a single run.
He then described a workflow in which the reviewer never sees the raw output
because a second pass rewrites it before any human is shown the result.
PRIVEOF
    # A private attendance record. The names are the D3 class.
    cat >"$b/pub/priv/chapters/attendance.txt" <<'PRIVEOF'
Attendance for the session recorded above.

Present: Varnex Quilloby and Tarnisk Vendrelle.
Varnex Quilloby chaired the first half and Tarnisk Vendrelle took the notes
for the second half of the same session.
PRIVEOF
    printf 'A private toolkit note about the token pipeline that is shared with the public kit by design.\n' \
        >"$b/pub/priv/chapters/shared-by-design.txt"
    mkrepo "$b/pub/priv"
    # Public umbrella: benign docs only.
    cat >"$b/pub/docs/plan.md" <<'PUBEOF'
# Plan

This document describes the build. It does not quote any session material and
it exists so that the control has real prose to scan rather than an empty tree.
Every sentence here was written for this document alone and appears nowhere in
the private repository that sits beside it.
PUBEOF
    printf 'A private toolkit note about the token pipeline that is shared with the public kit by design.\n' \
        >"$b/pub/docs/kit.md"
    mkrepo "$b/pub"
    printf '%s\t%s\n' "priv" "private" >"$b/spec.tsv"
    printf '%s\t%s\n' "." "public" >>"$b/spec.tsv"
    cat >"$b/allow" <<'ALLOWEOF'
# REASON: the kit note is propagated into the public kit by design.
priv/chapters/shared-by-design.txt	docs/kit.md	declared propagation fixture
ALLOWEOF
}

run_prove() {
    local self="${BASH_SOURCE[0]}" tmp rc out
    tmp="$(mktemp -d)" || { echo "PROOF FATAL: mktemp failed" >&2; return 2; }
    # An EXIT trap, deliberately NOT a RETURN trap: a RETURN trap fires on the
    # return of nested helper functions too, which silently removed this fixture
    # before the last cases ran and made them report on a tree that was gone.
    # shellcheck disable=SC2064
    trap "rm -rf '$tmp'" EXIT

    echo "paired mutation proof for $(basename "$self")"
    echo "synthetic fixture: $tmp"
    echo

    build_fixture "$tmp"
    local B="$tmp/pub" SPEC="$tmp/spec.tsv" ALLOW="$tmp/allow"

    # ---- C0 CONTROL: synthetic clean tree must be green -------------------
    out="$(bash "$self" --root "$B" --fleet-spec "$SPEC" --allow "$ALLOW" --quiet 2>&1)"; rc=$?
    p_case "C0 synthetic control is clean" "rc=0" "rc=$rc" \
        "$( [[ $rc -eq 0 ]] && echo 0 || echo 1 )" "$out"
    if [[ $rc -ne 0 ]]; then
        echo
        echo "PROOF ABORT: the control is not green, so no mutation below could be"
        echo "             attributed to the mutation rather than to the fixture."
        echo "proof: $P_PASS passed, $P_FAIL failed, 0 mutations run"
        return 1
    fi

    # ---- M1 verbatim quote from a private file into a public file --------
    cp -a "$B" "$tmp/m1"
    { printf '\n'; sed -n '1,3p' "$tmp/m1/priv/chapters/notes.txt"; } >>"$tmp/m1/docs/plan.md"
    out="$(bash "$self" --root "$tmp/m1" --fleet-spec "$SPEC" --allow "$ALLOW" 2>&1)"; rc=$?
    p_case "M1 planted verbatim quote" "rc=1" "rc=$rc" \
        "$( [[ $rc -eq 1 ]] && echo 0 || echo 1 )" "$(tail -5 <<<"$out")"
    local m1p=1 m1q=1
    grep -q 'priv/chapters/notes.txt' <<<"$out" && m1p=0
    grep -q 'docs/plan.md' <<<"$out" && m1q=0
    p_case "M1 names the private side" "path printed" \
        "$( [[ $m1p -eq 0 ]] && echo printed || echo ABSENT )" "$m1p" "$(tail -5 <<<"$out")"
    p_case "M1 names the public side" "path printed" \
        "$( [[ $m1q -eq 0 ]] && echo printed || echo ABSENT )" "$m1q" "$(tail -5 <<<"$out")"

    # ---- M2 re-wrapped quote: the leak shape that line-matching misses ----
    cp -a "$B" "$tmp/m2"
    { printf '\nAs recorded: "'; tr '\n' ' ' <"$tmp/m2/priv/chapters/notes.txt" | cut -c1-190; printf '"\n'; } \
        >>"$tmp/m2/docs/plan.md"
    out="$(bash "$self" --root "$tmp/m2" --fleet-spec "$SPEC" --allow "$ALLOW" --quiet 2>&1)"; rc=$?
    p_case "M2 quote re-wrapped onto one line" "rc=1" "rc=$rc" \
        "$( [[ $rc -eq 1 ]] && echo 0 || echo 1 )" "$out"

    # ---- M3 FALSE-POSITIVE GUARD: a path reference is not a leak ----------
    cp -a "$B" "$tmp/m3"
    cat >>"$tmp/m3/docs/plan.md" <<'M3EOF'

Run the extractor over `priv/chapters/notes.txt` and then over
priv/chapters/shared-by-design.txt, checking both against the manifest before
the archive step is allowed to proceed with the rest of the pipeline run.
M3EOF
    out="$(bash "$self" --root "$tmp/m3" --fleet-spec "$SPEC" --allow "$ALLOW" --quiet 2>&1)"; rc=$?
    p_case "M3 path reference only stays clean" "rc=0" "rc=$rc" \
        "$( [[ $rc -eq 0 ]] && echo 0 || echo 1 )" "$out"

    # ---- M4 FALSE-POSITIVE GUARD: declared propagation stays clean --------
    #      and the SAME public file still fails on undeclared content, so the
    #      exemption is proved to be scoped rather than a blanket pardon.
    cp -a "$B" "$tmp/m4"
    { printf '\n'; sed -n '1,3p' "$tmp/m4/priv/chapters/notes.txt"; } >>"$tmp/m4/docs/kit.md"
    out="$(bash "$self" --root "$tmp/m4" --fleet-spec "$SPEC" --allow "$ALLOW" --quiet 2>&1)"; rc=$?
    p_case "M4 exemption does not pardon other content" "rc=1" "rc=$rc" \
        "$( [[ $rc -eq 1 ]] && echo 0 || echo 1 )" "$out"

    # ---- M5 an uninitialised private submodule is UNDETERMINED -----------
    cp -a "$B" "$tmp/m5"
    rm -rf "$tmp/m5/priv"; mkdir -p "$tmp/m5/priv"
    out="$(bash "$self" --root "$tmp/m5" --fleet-spec "$SPEC" --allow "$ALLOW" --quiet 2>&1)"; rc=$?
    p_case "M5 uninitialised private submodule" "rc=2" "rc=$rc" \
        "$( [[ $rc -eq 2 ]] && echo 0 || echo 1 )" "$out"

    # ---- M6 a leak is still reported when something else is undetermined --
    cp -a "$tmp/m1" "$tmp/m6"
    printf '%s\t%s\n' "ghost" "private" >>"$tmp/m6spec.tsv"
    cat "$SPEC" >>"$tmp/m6spec.tsv"
    out="$(bash "$self" --root "$tmp/m6" --fleet-spec "$tmp/m6spec.tsv" --allow "$ALLOW" --quiet 2>&1)"; rc=$?
    p_case "M6 leak outranks undetermined" "rc=1" "rc=$rc" \
        "$( [[ $rc -eq 1 ]] && echo 0 || echo 1 )" "$out"

    # ---- M7 a malformed exemption file is UNDETERMINED, never a pass ------
    #      Isolated on a tree with nothing for any exemption to pardon, so the
    #      rc can only come from the malformed file and not from a leak the
    #      broken file stopped excusing.
    cp -a "$B" "$tmp/m7"; rm -f "$tmp/m7/docs/kit.md"
    git -C "$tmp/m7" add -A >/dev/null 2>&1
    git -C "$tmp/m7" -c commit.gpgsign=false commit -qm m7 >/dev/null 2>&1
    printf 'this row has only one field\n' >"$tmp/bad-allow"
    out="$(bash "$self" --root "$tmp/m7" --fleet-spec "$SPEC" --allow "$tmp/bad-allow" --quiet 2>&1)"; rc=$?
    p_case "M7 malformed exemption file" "rc=2" "rc=$rc" \
        "$( [[ $rc -eq 2 ]] && echo 0 || echo 1 )" "$out"

    # ---- M8 no provider client => UNVERIFIED => rc 2 (real derivation) ----
    #      Run WITHOUT --fleet-spec so the real visibility path is exercised.
    local shim="$tmp/nobin"; mkdir -p "$shim"
    printf '#!/bin/sh\nexit 127\n' >"$shim/gh"; chmod +x "$shim/gh"
    out="$(PATH="$shim:$PATH" bash "$self" --root "$SELF_REPO" --quiet 2>&1)"; rc=$?
    p_case "M8 provider client unusable (REAL tree)" "rc=2" "rc=$rc" \
        "$( [[ $rc -eq 2 ]] && echo 0 || echo 1 )" "$(tail -4 <<<"$out")"

    # ---- M9 --fleet-spec refuses to whitewash this repository ------------
    out="$(bash "$self" --root "$SELF_REPO" --fleet-spec "$SPEC" --quiet 2>&1)"; rc=$?
    local m9=1; grep -q 'refuses' <<<"$out" && m9=0
    p_case "M9 --fleet-spec refused on the real root" "rc=2 + refusal" \
        "rc=$rc $( [[ $m9 -eq 0 ]] && echo 'refused' || echo 'NOT refused' )" \
        "$( [[ $rc -eq 2 && $m9 -eq 0 ]] && echo 0 || echo 1 )" "$out"

    # ══════════════════════════════════════════════════════════════════════════
    # F2 — THE SHORT-PHRASE CLASS. Every one of these was invisible to the gate
    # before the short pass existed: a phrase shorter than the long window
    # produces no shingle at all, so there was nothing to compare.
    # ══════════════════════════════════════════════════════════════════════════

    # ---- M11 a FIVE-word private heading, reproduced verbatim -------------
    cp -a "$B" "$tmp/m11"
    cat >>"$tmp/m11/docs/plan.md" <<'M11EOF'

The agenda item was recorded upstream as The deployment checklist and escalation
before the working group renamed it for the published programme.
M11EOF
    out="$(bash "$self" --root "$tmp/m11" --fleet-spec "$SPEC" --allow "$ALLOW" --quiet 2>&1)"; rc=$?
    p_case "M11 five-word private heading" "rc=1" "rc=$rc" \
        "$( [[ $rc -eq 1 ]] && echo 0 || echo 1 )" "$out"
    # ... and the LONG pass alone must still miss it. Without this second half
    # the case proves only that the tree is red, not that the short pass is
    # what caught it.
    out="$(bash "$self" --root "$tmp/m11" --fleet-spec "$SPEC" --allow "$ALLOW" --no-short --no-names --quiet 2>&1)"; rc=$?
    p_case "M11b long pass alone is blind to it" "rc=0 (the old defect)" "rc=$rc" \
        "$( [[ $rc -eq 0 ]] && echo 0 || echo 1 )" "$out"

    # ---- M12 a SIX-word private heading, reproduced verbatim --------------
    cp -a "$B" "$tmp/m12"
    cat >>"$tmp/m12/docs/plan.md" <<'M12EOF'

Section four of the published outline is Nightly ingest of the partner catalogue
which the programme committee approved without further amendment.
M12EOF
    out="$(bash "$self" --root "$tmp/m12" --fleet-spec "$SPEC" --allow "$ALLOW" --quiet 2>&1)"; rc=$?
    p_case "M12 six-word private heading" "rc=1" "rc=$rc" \
        "$( [[ $rc -eq 1 ]] && echo 0 || echo 1 )" "$out"

    # ---- M13 the same heading RE-WRAPPED across a line break --------------
    #      Token-stream matching, not line-grep: the break must not hide it.
    cp -a "$B" "$tmp/m13"
    cat >>"$tmp/m13/docs/plan.md" <<'M13EOF'

The committee kept the working title Quarterly forecast for
the regional cohorts when it published the outline last week.
M13EOF
    out="$(bash "$self" --root "$tmp/m13" --fleet-spec "$SPEC" --allow "$ALLOW" --quiet 2>&1)"; rc=$?
    p_case "M13 heading re-wrapped across a line break" "rc=1" "rc=$rc" \
        "$( [[ $rc -eq 1 ]] && echo 0 || echo 1 )" "$out"

    # ---- M14/M15 F3 — a personal name, forward and reversed ---------------
    cp -a "$B" "$tmp/m14"
    cat >>"$tmp/m14/docs/plan.md" <<'M14EOF'

The programme was proposed by Varnex Quilloby during the planning round and
the committee adopted it without amendment at the following meeting.
M14EOF
    out="$(bash "$self" --root "$tmp/m14" --fleet-spec "$SPEC" --allow "$ALLOW" 2>&1)"; rc=$?
    p_case "M14 personal name, forward order" "rc=1" "rc=$rc" \
        "$( [[ $rc -eq 1 ]] && echo 0 || echo 1 )" "$(tail -6 <<<"$out")"
    local m14w=1
    grep -q 'personal name' <<<"$out" && ! grep -qi 'varnex quilloby' <<<"$out" && m14w=0
    p_case "M14 the name itself is WITHHELD from output" "withheld" \
        "$( [[ $m14w -eq 0 ]] && echo withheld || echo PRINTED )" "$m14w" "$(tail -6 <<<"$out")"

    cp -a "$B" "$tmp/m15"
    cat >>"$tmp/m15/docs/plan.md" <<'M15EOF'

The published index lists the chair as Vendrelle Tarnisk, surname first, which
is the convention that the archive has always used for its own records.
M15EOF
    out="$(bash "$self" --root "$tmp/m15" --fleet-spec "$SPEC" --allow "$ALLOW" --quiet 2>&1)"; rc=$?
    p_case "M15 personal name, REVERSED order" "rc=1" "rc=$rc" \
        "$( [[ $rc -eq 1 ]] && echo 0 || echo 1 )" "$out"

    # ---- M16 CONTROL: the short pass must not match everything ------------
    #      Ordinary prose, a capitalised product-style pair whose tokens are
    #      common lowercase words in the private corpus, and a five-word phrase
    #      built from the same vocabulary as the private notes but never
    #      written in them. All three must stay clean.
    cp -a "$B" "$tmp/m16"
    cat >>"$tmp/m16/docs/plan.md" <<'M16EOF'

The Review Pipeline is described here in the project's own words. The rollback
rehearsal and the reconciliation step are named because the public programme
needs them, and every sentence in this paragraph was composed for this file.
The escalation ladder and the partner catalogue are ordinary nouns in this
domain and their appearance together proves nothing on its own.
M16EOF
    out="$(bash "$self" --root "$tmp/m16" --fleet-spec "$SPEC" --allow "$ALLOW" --quiet 2>&1)"; rc=$?
    p_case "M16 CONTROL near-miss prose stays clean" "rc=0" "rc=$rc" \
        "$( [[ $rc -eq 0 ]] && echo 0 || echo 1 )" "$out"

    # ---- M17 REGRESSION: the exact structure that escaped on 2026-09-01 ---
    #      A private notes document whose short section headings are separated
    #      by their own body text, and a public file that reproduces the
    #      HEADING LIST and nothing else. No sentence is quoted. The long pass
    #      sees nothing, because no ten-token run is shared. This is a
    #      synthetic stand-in: same structure, none of the real strings.
    cp -a "$B" "$tmp/m17"
    cat >>"$tmp/m17/docs/plan.md" <<'M17EOF'

The source document is organised under four topic headings:

- The review pipeline and escalation ladder
- Nightly ingest of the partner catalogue
- The deployment checklist and escalation
- Quarterly forecast for the regional cohorts
M17EOF
    out="$(bash "$self" --root "$tmp/m17" --fleet-spec "$SPEC" --allow "$ALLOW" --no-short --no-names --quiet 2>&1)"; rc=$?
    p_case "M17a heading list — long pass alone (the defect)" "rc=0" "rc=$rc" \
        "$( [[ $rc -eq 0 ]] && echo 0 || echo 1 )" "$out"
    out="$(bash "$self" --root "$tmp/m17" --fleet-spec "$SPEC" --allow "$ALLOW" --quiet 2>&1)"; rc=$?
    p_case "M17b heading list — short pass catches it" "rc=1" "rc=$rc" \
        "$( [[ $rc -eq 1 ]] && echo 0 || echo 1 )" "$out"

    # ══════════════════════════════════════════════════════════════════════════
    # F4 — THE NAME-JUNCTION AND FREQUENCY-FLOOR TIGHTENINGS (2026-09-01).
    # Each one is a PAIR: the shape it now clears, and the shape it must still
    # catch built from the SAME two tokens, so a pass cannot come from the
    # detector having simply gone quiet.
    # ══════════════════════════════════════════════════════════════════════════

    # ---- M18 hard junctions: fused runs clear, spaced runs still caught ---
    cp -a "$B" "$tmp/m18"
    cat >>"$tmp/m18/docs/plan.md" <<'M18EOF'

The pipeline stages are Varnex/Quilloby and the fallback route is
Varnex|Quilloby, configured as Varnex;Quilloby in the older files and written
**Varnex:** **Quilloby** in the generated table of contents.
The serialised form is "Varnex",
"Quilloby" as emitted by the exporter, and the qualified identifier is
Varnex.Quilloby throughout the reference documentation for this component.
M18EOF
    out="$(bash "$self" --root "$tmp/m18" --fleet-spec "$SPEC" --allow "$ALLOW" --quiet 2>&1)"; rc=$?
    p_case "M18a hard-separator fusions are NOT a name" "rc=0" "rc=$rc" \
        "$( [[ $rc -eq 0 ]] && echo 0 || echo 1 )" "$out"
    # ... and the SAME two tokens, separated the way a name actually is, must
    # still be caught. Without this half, M18a would also pass if the name pass
    # had simply stopped working.
    cp -a "$tmp/m18" "$tmp/m18b"
    printf '\nThe session was chaired by Varnex Quilloby before the vote was taken.\n' \
        >>"$tmp/m18b/docs/plan.md"
    out="$(bash "$self" --root "$tmp/m18b" --fleet-spec "$SPEC" --allow "$ALLOW" --quiet 2>&1)"; rc=$?
    p_case "M18b same tokens, spaced, still caught" "rc=1" "rc=$rc" \
        "$( [[ $rc -eq 1 ]] && echo 0 || echo 1 )" "$out"

    # ---- M19 a name RE-WRAPPED onto the next line is still a name --------
    #      The junction rule must not become a line-oriented matcher; this is
    #      the recall half of M20 and the reason the break is "token-free
    #      line", not "line break".
    cp -a "$B" "$tmp/m19"
    cat >>"$tmp/m19/docs/plan.md" <<'M19EOF'

The minutes record that the chair for the whole of the session was Varnex
Quilloby, and that the vote was carried without any further amendment at all.
M19EOF
    out="$(bash "$self" --root "$tmp/m19" --fleet-spec "$SPEC" --allow "$ALLOW" --quiet 2>&1)"; rc=$?
    p_case "M19 name re-wrapped across a line break" "rc=1" "rc=$rc" \
        "$( [[ $rc -eq 1 ]] && echo 0 || echo 1 )" "$out"

    # ---- M20 a name may not bridge a TOKEN-FREE line ---------------------
    cp -a "$B" "$tmp/m20"
    cat >>"$tmp/m20/docs/plan.md" <<'M20EOF'

The heading of the closing section of the published programme is Varnex

Quilloby is a word that begins the paragraph that follows the break above.
M20EOF
    out="$(bash "$self" --root "$tmp/m20" --fleet-spec "$SPEC" --allow "$ALLOW" --quiet 2>&1)"; rc=$?
    p_case "M20a name across a paragraph break is cleared" "rc=0" "rc=$rc" \
        "$( [[ $rc -eq 0 ]] && echo 0 || echo 1 )" "$out"
    cp -a "$B" "$tmp/m20b"
    cat >>"$tmp/m20b/docs/plan.md" <<'M20BEOF'

The heading of the closing section of the published programme is Varnex
Quilloby is a word that begins the paragraph that follows the line above.
M20BEOF
    out="$(bash "$self" --root "$tmp/m20b" --fleet-spec "$SPEC" --allow "$ALLOW" --quiet 2>&1)"; rc=$?
    p_case "M20b same two lines, adjacent, still caught" "rc=1" "rc=$rc" \
        "$( [[ $rc -eq 1 ]] && echo 0 || echo 1 )" "$out"

    # ---- M21 THE COMMA DECISION, held open by a test ---------------------
    #      `Surname, Firstname` is a real rendering. If a later change makes the
    #      comma a hard separator to buy a quieter run, THIS case goes red and
    #      says why. That is the whole point of writing the judgement down as a
    #      mutation instead of a comment.
    cp -a "$B" "$tmp/m21"
    cat >>"$tmp/m21/docs/plan.md" <<'M21EOF'

The published attendance index lists the chair of the session as
Quilloby, Varnex — surname first, which is the convention the archive uses.
M21EOF
    out="$(bash "$self" --root "$tmp/m21" --fleet-spec "$SPEC" --allow "$ALLOW" --quiet 2>&1)"; rc=$?
    p_case "M21 'Surname, Firstname' is still a name" "rc=1" "rc=$rc" \
        "$( [[ $rc -eq 1 ]] && echo 0 || echo 1 )" "$out"

    # ---- M22 THE FREQUENCY FLOOR, and its recall cost, in one pair -------
    #      The floor is the one tightening that trades real recall. Both halves
    #      are run against the SAME tree so the only difference is the floor.
    #
    #      EXACTLY TWO extra private lines, which is a measured constraint and
    #      not a stylistic choice: they put the given name at 4 occurrences in
    #      the fixture's prose. A third line takes it to 5, where the
    #      PRE-EXISTING rank rule (rank <= 2000 AND count >= NAME_MINCOUNT = 5)
    #      sweeps the candidate on its own — and then both halves of this pair
    #      would score rc=0 and the mutation would prove nothing about the
    #      floor. That also corrects a claim this file used to make: a small
    #      fixture CAN clear NAME_MINCOUNT. The new floor is the part that
    #      cannot, because it is derived from corpus size.
    cp -a "$B" "$tmp/m22"
    cat >>"$tmp/m22/priv/chapters/attendance.txt" <<'M22PEOF'
Varnex Quilloby opened the meeting and the group agreed to the agenda as read.
Varnex Quilloby then invited the second reviewer to summarise the open items.
M22PEOF
    git -C "$tmp/m22/priv" add -A >/dev/null 2>&1
    git -C "$tmp/m22/priv" -c commit.gpgsign=false commit -qm m22 >/dev/null 2>&1
    cat >>"$tmp/m22/docs/plan.md" <<'M22EOF'

The chair for that session was Varnex Quilloby and the minutes were approved.
M22EOF
    out="$(bash "$self" --root "$tmp/m22" --fleet-spec "$SPEC" --allow "$ALLOW" --name-floor 0 --quiet 2>&1)"; rc=$?
    p_case "M22a floor disabled: the name is caught" "rc=1" "rc=$rc" \
        "$( [[ $rc -eq 1 ]] && echo 0 || echo 1 )" "$out"
    out="$(bash "$self" --root "$tmp/m22" --fleet-spec "$SPEC" --allow "$ALLOW" --name-floor 3 --quiet 2>&1)"; rc=$?
    p_case "M22b floor=3 sweeps it — THE DECLARED COST" "rc=0" "rc=$rc" \
        "$( [[ $rc -eq 0 ]] && echo 0 || echo 1 )" "$out"

    # ---- M10 the detector is not constant: it must clear a clean copy ----
    #      after having failed a dirty one, from the SAME fixture.
    out="$(bash "$self" --root "$B" --fleet-spec "$SPEC" --allow "$ALLOW" --quiet 2>&1)"; rc=$?
    p_case "M10 control still clean after mutations" "rc=0" "rc=$rc" \
        "$( [[ $rc -eq 0 ]] && echo 0 || echo 1 )" "$out"

    # ---- pre-flight against the LIVE tree: REPORTED, never gating --------
    echo
    echo "── live-tree pre-flight (reported, cannot disable the battery) ──"
    local lrc
    bash "$self" --root "$SELF_REPO" --quiet >"$tmp/live.log" 2>&1; lrc=$?
    echo "live run rc=$lrc  ($(tail -n 1 "$tmp/live.log" 2>/dev/null || echo 'no output captured'))"
    echo "  A non-zero live rc is a statement about THIS TREE, not about the"
    echo "  battery above; all 22 mutations ran against the synthetic fixture."

    echo
    echo "proof: $P_PASS passed, $P_FAIL failed, 22 mutations run"
    [[ $P_FAIL -eq 0 ]]
}

if [[ $PROVE -eq 1 ]]; then
    run_prove
    exit $?
fi

# ══════════════════════════════════════════════════════════════════════════════
# FLEET DERIVATION
# ══════════════════════════════════════════════════════════════════════════════
command -v git >/dev/null 2>&1 || { echo "FATAL: git not found" >&2; exit 2; }
[[ -d "$ROOT" ]] || { echo "FATAL: root '$ROOT' does not exist" >&2; exit 2; }

SYNTHETIC=0
if [[ -n "$FLEET_SPEC" ]]; then
    if [[ "$ROOT" == "$SELF_REPO" ]]; then
        say "FATAL: --fleet-spec refuses to run against the repository this script lives in."
        say "       A synthetic fleet may never be used to declare the real tree clean."
        exit 2
    fi
    [[ -r "$FLEET_SPEC" ]] || { say "FATAL: --fleet-spec: cannot read '$FLEET_SPEC'"; exit 2; }
    SYNTHETIC=1
fi

# `git -C <dir> rev-parse --git-dir` SUCCEEDS inside an empty directory that
# merely sits within another repository — it walks UP and answers about the
# parent. An uninitialised submodule is exactly such an empty directory, so the
# obvious test reports it as a healthy repository and its content silently
# counts as "nothing to find". That is a false CLEAN, which is the one verdict
# this instrument must never produce by accident. Require the directory to BE
# the top level of the repository git resolves for it.
is_repo_root() { # $1 absolute directory
    local top here
    [[ -d "$1" ]] || return 1
    top="$(git -C "$1" rev-parse --show-toplevel 2>/dev/null)" || return 1
    [[ -n "$top" ]] || return 1
    here="$(cd -- "$1" 2>/dev/null && pwd -P)" || return 1
    top="$(cd -- "$top" 2>/dev/null && pwd -P)" || return 1
    [[ "$here" == "$top" ]]
}

TMPD="$(mktemp -d)" || { echo "FATAL: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$TMPD"' EXIT

# Progress trace. A gate that scans every tracked file in a dozen repositories
# takes minutes; silence for minutes is indistinguishable from a hang, and an
# operator who cannot tell the difference kills the run and stops trusting it.
CB_T0=$SECONDS
trace() { [[ -n "${CB_TRACE:-}" ]] && printf '[%4ds] %s\n' "$((SECONDS - CB_T0))" "$*" >&2; return 0; }

# Rows: path \t role \t evidence
FLEET="$TMPD/fleet.tsv"; : >"$FLEET"
UNDET=0
UNDET_ROWS="$TMPD/undet.txt"; : >"$UNDET_ROWS"
undet() { UNDET=1; printf '%s\n' "$*" >>"$UNDET_ROWS"; }

if [[ $SYNTHETIC -eq 1 ]]; then
    while IFS=$'\t' read -r p role _; do
        [[ -z "${p:-}" || "$p" == \#* ]] && continue
        if ! is_repo_root "$ROOT/$p"; then
            undet "$p: declared '$role' by --fleet-spec but is not a git repository (not initialised)"
            printf '%s\t%s\t%s\n' "$p" "unverified" "spec:not-a-repo" >>"$FLEET"
            continue
        fi
        printf '%s\t%s\t%s\n' "$p" "$role" "spec" >>"$FLEET"
    done <"$FLEET_SPEC"
else
    # ---- provider adapter -----------------------------------------------
    # host is derived from the remote URL; only hosts with an adapter can be
    # answered. Any other host is UNVERIFIED and says which host it was.
    GH_OK=0
    if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then GH_OK=1; fi

    slug_of() { # $1 remote url -> owner/repo, or empty
        local u="$1"
        u="${u%.git}"
        case "$u" in
            git@*:*)          printf '%s\n' "${u#*:}" ;;
            ssh://*)          u="${u#ssh://}"; u="${u#*@}"; printf '%s\n' "${u#*/}" ;;
            https://*|http://*) u="${u#*://}"; u="${u#*@}"; printf '%s\n' "${u#*/}" ;;
            *)                printf '\n' ;;
        esac
    }
    host_of() {
        local u="$1"
        case "$u" in
            git@*:*)            u="${u#git@}"; printf '%s\n' "${u%%:*}" ;;
            ssh://*)            u="${u#ssh://}"; u="${u#*@}"; printf '%s\n' "${u%%/*}" ;;
            https://*|http://*) u="${u#*://}"; u="${u#*@}"; printf '%s\n' "${u%%/*}" ;;
            *)                  printf '\n' ;;
        esac
    }

    classify() { # $1 repo-relative path ("." for the umbrella)  $2 remote url
        local p="$1" url="$2" host slug meta priv push
        host="$(host_of "$url")"; slug="$(slug_of "$url")"
        if [[ -z "$host" || -z "$slug" ]]; then
            undet "$p: remote '$url' is not a recognised URL shape; visibility unknown"
            printf '%s\t%s\t%s\n' "$p" "unverified" "unparseable-remote" >>"$FLEET"; return
        fi
        if [[ "$host" != "github.com" ]]; then
            undet "$p: host '$host' has no visibility adapter registered; GitHub's answer is not generalised to it"
            printf '%s\t%s\t%s\n' "$p" "unverified" "no-adapter:$host" >>"$FLEET"; return
        fi
        if [[ $GH_OK -eq 0 ]]; then
            undet "$p: github.com requires an authenticated 'gh'; none usable, so visibility is UNKNOWN (not 'public')"
            printf '%s\t%s\t%s\n' "$p" "unverified" "no-client" >>"$FLEET"; return
        fi
        meta="$(gh api "repos/$slug" --jq '"\(.private)\t\(.permissions.push)"' 2>/dev/null)" || meta=""
        if [[ -z "$meta" ]]; then
            undet "$p: provider did not answer for '$slug' (network, scope, or repository gone)"
            printf '%s\t%s\t%s\n' "$p" "unverified" "provider-silent" >>"$FLEET"; return
        fi
        priv="${meta%%$'\t'*}"; push="${meta##*$'\t'}"
        if [[ "$priv" == "true" ]]; then
            printf '%s\t%s\t%s\n' "$p" "private" "provider:private=true" >>"$FLEET"
        elif [[ "$priv" == "false" ]]; then
            if [[ "$push" == "true" ]]; then
                printf '%s\t%s\t%s\n' "$p" "public" "provider:private=false,push=true" >>"$FLEET"
            else
                printf '%s\t%s\t%s\n' "$p" "out-of-scope" "provider:private=false,push=$push" >>"$FLEET"
            fi
        else
            undet "$p: provider returned an unusable visibility value for '$slug'"
            printf '%s\t%s\t%s\n' "$p" "unverified" "provider-unusable" >>"$FLEET"
        fi
    }

    UMB_URL="$(git -C "$ROOT" config --get remote.origin.url 2>/dev/null)"
    if [[ -z "$UMB_URL" ]]; then
        UMB_URL="$(git -C "$ROOT" remote -v 2>/dev/null | awk 'NR==1{print $2}')"
    fi
    if [[ -z "$UMB_URL" ]]; then
        undet ".: this tree has no upstream configured; its own visibility is unknown"
        printf '%s\t%s\t%s\n' "." "unverified" "no-remote" >>"$FLEET"
    else
        classify "." "$UMB_URL"
    fi

    if [[ -f "$ROOT/.gitmodules" ]]; then
        while IFS= read -r key; do
            name="${key#submodule.}"; name="${name%.path}"
            sp="$(git -C "$ROOT" config -f "$ROOT/.gitmodules" --get "submodule.$name.path" 2>/dev/null)"
            su="$(git -C "$ROOT" config -f "$ROOT/.gitmodules" --get "submodule.$name.url" 2>/dev/null)"
            [[ -z "$sp" ]] && continue
            classify "$sp" "${su:-}"
        done < <(git -C "$ROOT" config -f "$ROOT/.gitmodules" --name-only --get-regexp '^submodule\..*\.path$' 2>/dev/null)
    fi
fi

# initialisation check for everything we intend to read
while IFS=$'\t' read -r p role ev; do
    [[ "$role" == "private" || "$role" == "public" ]] || continue
    d="$ROOT/$p"; [[ "$p" == "." ]] && d="$ROOT"
    if ! is_repo_root "$d"; then
        undet "$p: declared $role but is not an initialised git repository here; its content could not be read"
        # demote so it is never scanned as if it were empty
        sed -i "s|^$(printf '%s' "$p" | sed 's/[][\\/.^$*]/\\&/g')\t$role\t|$p\tunverified\t|" "$FLEET" 2>/dev/null
    fi
done <"$FLEET"

if [[ $LIST_ONLY -eq 1 ]]; then
    say "${C_BLD}derived fleet${C_OFF}${SYNTHETIC:+ }$( [[ $SYNTHETIC -eq 1 ]] && echo "${C_YEL}(SYNTHETIC FLEET)${C_OFF}")"
    while IFS=$'\t' read -r p role ev; do printf '  %-28s %-13s %s\n' "$p" "$role" "$ev" >&3; done <"$FLEET"
    exit 0
fi

mapfile -t PRIV_PATHS < <(awk -F'\t' '$2=="private"{print $1}' "$FLEET")
mapfile -t PUB_PATHS  < <(awk -F'\t' '$2=="public"{print $1}' "$FLEET")

# ══════════════════════════════════════════════════════════════════════════════
# DECLARED EXEMPTIONS
# ══════════════════════════════════════════════════════════════════════════════
ALLOW_TSV="$TMPD/allow.tsv"; : >"$ALLOW_TSV"
ALLOW_N=0
if [[ -e "$ALLOW_FILE" ]]; then
    if [[ ! -r "$ALLOW_FILE" ]]; then
        undet "exemption file '$ALLOW_FILE' exists but is unreadable"
    else
        lineno=0; bad=0
        while IFS= read -r raw || [[ -n "$raw" ]]; do
            lineno=$((lineno + 1))
            [[ -z "${raw//[[:space:]]/}" || "$raw" == \#* ]] && continue
            IFS=$'\t' read -r g_priv g_pub reason <<<"$raw"
            if [[ -z "${g_priv:-}" || -z "${g_pub:-}" || -z "${reason:-}" ]]; then
                say "${C_RED}MALFORMED${C_OFF} $ALLOW_FILE:$lineno — expected 3 TAB-separated fields (private-glob, public-glob, reason)"
                bad=1; continue
            fi
            printf '%s\t%s\t%s\n' "$g_priv" "$g_pub" "$reason" >>"$ALLOW_TSV"
            ALLOW_N=$((ALLOW_N + 1))
        done <"$ALLOW_FILE"
        [[ $bad -eq 1 ]] && undet "exemption file '$ALLOW_FILE' has malformed rows; the declared set could not be read"
    fi
fi

# ══════════════════════════════════════════════════════════════════════════════
# SHINGLE EMITTERS
# Identical normalisation on both sides, or the comparison is meaningless.
# ══════════════════════════════════════════════════════════════════════════════
SHINGLE_AWK="$TMPD/shingle.awk"
cat >"$SHINGLE_AWK" <<'AWKEOF'
# in : one or more text files (FILENAME is the repo-relative path)
# out: TAG \t key \t first-line-number \t PFX FILENAME
#
#      TAG L  long prose shingle   (W tokens, prose-shape filtered)
#      TAG S  short structural key (SW tokens; on the PRIVATE side only emitted
#             from source lines short enough to BE a heading/list item/caption)
#      TAG N  a run of 2 or 3 consecutively CAPITALISED tokens — the shape a
#             personal name has in prose
#
# Tokens are folded to lowercase alphanumerics and everything else becomes a
# separator, so markdown emphasis, quote marks and — critically — LINE WRAPPING
# cannot hide a quotation. A passage re-wrapped by the editor that pasted it is
# still the same token run, which is exactly the leak shape a line-oriented
# grep cannot see. Capitalisation is captured BEFORE folding, per token, so a
# name split across a line break is still a capitalised run.
BEGIN{
  split("the and of to a is that for with in it as on by an be are this from or not was were we you they i our their its have has had can will would should", F, " ")
  for (i in F) FW[F[i]] = 1
  # Anchor sets. The public side is streamed through the PRIVATE side's own
  # first tokens, so the short and name passes cost a hash lookup per position
  # instead of a string build per position. Empty = no anchoring (private side).
  if (SANCH != "") { while ((getline ln < SANCH) > 0) SA[ln] = 1; close(SANCH); useSA = 1 }
  if (NANCH != "") { while ((getline ln < NANCH) > 0) NA[ln] = 1; close(NANCH); useNA = 1 }
  # One character class decides "this line is prose, not code or markup". It is
  # applied ONLY to the private side, and only to the two new key spaces: it
  # narrows what may BECOME a candidate, never what may be found. Measured on
  # this tree, this single test removes the entire CSS / SCSS / HTML / Go /
  # go.sum contribution, which was 63% of the short class and 63% of the name
  # class — font stacks like a two-word typeface name were the largest single
  # source of bogus "personal names".
  CODECH = "[{}<>=|;~$@#_/`\\\\^]"
}
# ── NAME JUNCTIONS: what may stand between a given name and a surname ────────
# The N pass used to fold EVERY non-alphanumeric run into one separator, which
# is right for the prose pass (it is what defeats re-wrapping) and wrong here:
# it FUSES list items into a single "name". `A/B/C` became one capitalised run,
# and on this tree that one defect produced most of the class.
#
# The rule is an ALLOW-list, not a deny-list, because the allow-list is the
# thing that can actually be justified: state what CAN sit between the two
# tokens of a person's name, and treat everything else as a break.
#
#   0  whitespace only ......................... `Firstname Surname`
#   1  a bare hyphen, or a comma with optional
#      surrounding whitespace .................. `Anne-Marie`, `Surname, Firstname`
#   2  anything else ........................... a DELIMITER, never intra-name
#
# A junction is name-compatible when its two halves sum to <= 1 — so at most one
# comma or hyphen, and never two. `Qdrant, Pinecone` keeps the comma (see the
# comma decision in the header); `Qdrant/Pinecone`, `"Mistral",\n"Cohere"`,
# `Intl.Segmenter`, `**Frontend:** **Angular**` and a markdown table cell
# boundary all break.
# The two line-edge codes are computed inline in the tokenising rule, as
# anchored membership tests — see the note there on why the readable
# `sub()`-and-inspect form was too slow to keep.
#
# Junction classes for every adjacent token pair ON ONE LINE, in order.
# Written as whole-line regex work rather than a per-token walk because the
# obvious `match()`-and-shrink shape is O(n^2) per line and made a prototype of
# this run take longer than the whole gate. It is called ONLY for lines that
# actually carry two capitalised tokens, which is a small minority.
function junctions(s, out,   sig, k, i, ch, m) {
  sig = s
  gsub(/[A-Za-z0-9]+/, "A", sig)
  sub(/^[^A]+/, "", sig); sub(/[^A]+$/, "", sig)
  k = 1
  while (k > 0) k = gsub(/A([ \t]+|-|[ \t]*,[ \t]*)A/, "A\001A", sig)
  gsub(/[^A\001]+/, "\002", sig)
  m = 0
  for (i = 1; i <= length(sig); i++) {
    ch = substr(sig, i, 1)
    if      (ch == "\001") { m++; out[m] = 1 }
    else if (ch == "\002") { m++; out[m] = 0 }
  }
  return m
}
# Is the junction immediately BEFORE token i one a personal name may contain?
# Cross-line junctions were settled at tokenise time (cheap). Same-line ones are
# resolved here, at most once per line: the name loop walks tokens in order, so
# a one-entry cache is enough and the signature is never built for a line the
# loop never reaches.
function jok(i,   L, k) {
  if (JOK[i] >= 0) return JOK[i]
  L = tl[i]
  if (LASTSIG != L) { NSIG = (L in RAW) ? junctions(RAW[L], JC) : 0; LASTSIG = L }
  k = co[i] - 1
  return (k >= 1 && k <= NSIG) ? JC[k] : 0
}
function flush(   i, j, l, s, fw, al) {
  if (cur == "") return
  # ── L: the long prose pass, unchanged ──────────────────────────────────────
  for (i = 1; i + W - 1 <= ntok; i++) {
    s = tok[i]; fw = 0; al = 0
    delete seen
    if (tok[i] in FW) { seen[tok[i]] = 1; fw = 1 }
    if (tok[i] ~ /^[a-z][a-z]+[a-z]$/) al = 1
    for (j = i + 1; j < i + W; j++) {
      s = s " " tok[j]
      if (tok[j] in FW) { if (!(tok[j] in seen)) { seen[tok[j]] = 1; fw++ } }
      if (tok[j] ~ /^[a-z][a-z]+[a-z]$/) al++
    }
    if (length(s) < MINC) continue
    # PROSE-SHAPE filter, applied at emit time on BOTH sides so the two corpora
    # are always compared under identical rules.
    if (fw < 2 || al < 5) continue
    print "L\t" s "\t" tl[i] "\t" PFX cur
  }
  # ── S: the short pass ──────────────────────────────────────────────────────
  # The long pass CANNOT see a phrase shorter than W: no such shingle is ever
  # built. Three independent barriers stack — the window, the 40-character
  # floor, and "two distinct function words", which a noun-phrase heading does
  # not have. So the short pass drops all three and buys its precision back
  # from STRUCTURE instead: SLINEMAX > 0 (private side) restricts keys to
  # windows lying wholly inside a source line short enough to be a heading, a
  # list item, a table cell or a caption. SLINEMAX = 0 (public side) means no
  # such restriction, because in the public file the same words may sit in the
  # middle of a paragraph or be re-wrapped.
  if (SW > 0) {
    for (i = 1; i + SW - 1 <= ntok; i++) {
      if (useSA && !(tok[i] in SA)) continue
      if (PRIVSIDE) {
        l = tl[i]
        if (l != tl[i + SW - 1]) continue          # one source line, not two
        if (LT[l] < SW || LT[l] > SLINEMAX) continue
        if (!PR[l]) continue                        # prose, not code or markup
        # STRUCTURAL: a heading marker / list bullet, or a short line that
        # OPENS a block. A short line in the MIDDLE of a wrapped paragraph is
        # ordinary prose the long pass already covers, and admitting it was
        # what turned this pass into a 5-token scan of the whole corpus.
        #
        # "Standing alone between two blank lines" was tried first and is
        # WRONG: in a real notes document a heading is followed immediately by
        # its own body, so that rule dropped the exact class it exists to
        # catch. Mutation M17b caught that before it shipped — which is the
        # entire argument for pairing a gate with a mutation.
        if (!MK[l] && (NB[l-1]+0) != 0) continue
      }
      s = tok[i]; al = (tok[i] ~ /^[a-z][a-z]+[a-z]$/) ? 1 : 0
      for (j = i + 1; j < i + SW; j++) {
        s = s " " tok[j]
        if (tok[j] ~ /^[a-z][a-z]+[a-z]$/) al++
      }
      if (length(s) < SMINC || al < SMINAL) continue
      print "S\t" s "\t" tl[i] "\t" PFX cur
    }
  }
  # ── N: capitalised runs, the shape a personal name has ─────────────────────
  if (NAMES) {
    for (i = 1; i + 1 <= ntok; i++) {
      if (!cp[i] || !cp[i + 1]) continue
      # JUNCTION: the two tokens must be separated by something a personal name
      # may actually contain. This is applied on BOTH sides on purpose. It is
      # not a filter on where a name may be FOUND — it is a fix to the
      # TOKENISER, which was inventing a run that stands in neither text. A
      # slash-separated list is three items in the private file and three items
      # in the public one, and reading it as one name on either side is the
      # same defect.
      if (useNA && !(tok[i] in NA)) continue
      # Private side only: a candidate NAME must come from prose. A CSS font
      # stack, an HTML attribute or a Go type name is a capitalised token pair
      # and is not a person. The PUBLIC side is deliberately unrestricted — a
      # name disclosed inside public markup is still a disclosure.
      if (PRIVSIDE && !PR[tl[i]]) continue
      # Cheapest-first on purpose: the anchor and prose tests above reject
      # almost every position, and only what survives them pays for a junction
      # signature.
      if (!jok(i + 1)) continue
      print "N\t" tok[i] " " tok[i + 1] "\t" tl[i] "\t" PFX cur
      if (i + 2 <= ntok && cp[i + 2] && jok(i + 2))
        print "N\t" tok[i] " " tok[i + 1] " " tok[i + 2] "\t" tl[i] "\t" PFX cur
    }
  }
  delete tok; delete tl; delete cp; delete LT; delete MK; delete PR; delete NB
  delete JOK; delete co; delete RAW; delete JC
  ntok = 0; prevTC = 0; LASTSIG = -1; NSIG = 0
}
FNR == 1 { flush(); cur = (NAME != "" ? NAME : FILENAME) }
{
  if (PRIVSIDE) {
    rest = $0
    MK[FNR] = sub(/^[ \t]*(#+|[-*+>]|[0-9]+[.)])[ \t]+/, "", rest) ? 1 : 0
    PR[FNR] = (rest ~ CODECH || rest ~ /\]\(/) ? 0 : 1
  }
  # ── name-junction classification, N pass only ──────────────────────────────
  # Guarded: the whole-line signature is computed ONLY when the line really
  # carries two capitalised tokens with something between them. On this tree
  # that is a small minority of lines, so the prose and short passes pay one
  # extra regex TEST per line and nothing more.
  # Written as anchored membership TESTS rather than the obvious
  # `sub(/^.*[A-Za-z0-9]/, "", copy)`: that form backtracks a greedy `.*` and
  # rebuilds a string for every line of every file in the fleet. The tests
  # below fail fast and allocate nothing.
  if (NAMES) {
    if      ($0 ~ /^[ \t]*[A-Za-z0-9]/)             nl_lc = 0
    else if ($0 ~ /^[ \t]*[-,][ \t]*[A-Za-z0-9]/)   nl_lc = 1
    else                                            nl_lc = 2
    if      ($0 ~ /[A-Za-z0-9][ \t]*$/)             nl_tc = 0
    else if ($0 ~ /[A-Za-z0-9][ \t]*[-,][ \t]*$/)   nl_tc = 1
    else                                            nl_tc = 2
    # The line is KEPT, not analysed. Building the junction signature here cost
    # 16% of the whole gate, because it ran for every line carrying two
    # capitalised tokens — while on the public side the name loop is ANCHORED
    # and discards almost all of them before the signature is ever consulted.
    # So the signature is built on demand in flush(), at most once per line.
    # The guard is the exact precondition for a same-line capitalised PAIR:
    # `Aa..` then a separator run then `Aa`. If it does not hold, no such pair
    # exists on this line and no junction of it is ever read.
    if ($0 ~ /[A-Z][a-z][A-Za-z0-9]*[^A-Za-z0-9]+[A-Z][a-z]/) RAW[FNR] = $0
  }
  line = $0
  gsub(/[^A-Za-z0-9]+/, " ", line)
  n = split(line, t, " ")
  c = 0
  for (i = 1; i <= n; i++) if (t[i] != "") {
    ntok++; tok[ntok] = tolower(t[i]); tl[ntok] = FNR
    cp[ntok] = (t[i] ~ /^[A-Z][a-z]+$/) ? 1 : 0
    c++
    if (NAMES) {
      co[ntok] = c
      if (c == 1) {
        # This junction crosses a line boundary. It is name-compatible only
        # when the two tokens sit on ADJACENT lines — a personal name never
        # spans a paragraph break, so a token-free line between them is a hard
        # break — and when the previous line's tail plus this line's head carry
        # at most one comma or hyphen between them.
        JOK[ntok] = (ntok > 1 && tl[ntok - 1] == FNR - 1 && prevTC + nl_lc <= 1) ? 1 : 0
      } else {
        JOK[ntok] = -1          # same-line junction: resolved lazily in flush()
      }
    }
  }
  if (NAMES && c > 0) prevTC = nl_tc
  LT[FNR] = c
  NB[FNR] = (c > 0) ? 1 : 0
}
END{ flush() }
AWKEOF

# Files that carry no prose to leak and would only add cost. Lock files, source
# maps and minified bundles are machine output; the size cap keeps one generated
# artefact from dominating the run. Both are DECLARED, counted, and printed —
# never a silent narrowing of what was checked.
SKIPPED_BIG="$TMPD/skipped.txt"; : >"$SKIPPED_BIG"
SIZE_CAP=524288
EMIT_SEQ=0

# The umbrella's own path is "."; every label must be plain "docs/x.md", never
# "./docs/x.md", or an exemption glob written the obvious way would silently
# fail to match — a false NEGATIVE hiding inside a false-positive guard.
qualify() { if [[ "$1" == "." ]]; then printf '%s\n' "$2"; else printf '%s/%s\n' "$1" "$2"; fi; }

# One awk per REPOSITORY, not per file. The per-file shape spawned four
# processes for each of ~6,500 tracked files and made the gate unusable; this
# is the same computation with three orders of magnitude fewer spawns.
emit_repo() { # $1 repo-relative path  $2 out-BASE (.L/.S/.N appended)  $3 "priv"|"pub"
    local p="$1" out="$2" side="$3" dir pfx base list txts pdfs f sz nm
    local slinemax=0 privside=0 sanch="" nanch="" tagged
    dir="$ROOT/$p"; [[ "$p" == "." ]] && dir="$ROOT"
    pfx="$p/"; [[ "$p" == "." ]] && pfx=""
    EMIT_SEQ=$((EMIT_SEQ + 1))
    base="$TMPD/emit.$EMIT_SEQ"
    list="$base.all"; txts="$base.txt"; pdfs="$base.pdf"; tagged="$base.tagged"
    : >"$list"; : >"$txts"; : >"$pdfs"; : >"$tagged"
    if [[ "$side" == "priv" ]]; then
        slinemax="$SHORT_LINEMAX"; privside=1
    else
        # public side: anchored on the private side's own first tokens
        sanch="$SANCHOR_FILE"; nanch="$NANCHOR_FILE"
    fi

    # NOTE: a tracked path containing a literal newline would break this list.
    # git rejects such paths on every platform this project targets; if one ever
    # appears, `git ls-files -z` and this filter disagree and the run is wrong
    # rather than silently short — which is why the file count is reported.
    git -C "$dir" ls-files -z 2>/dev/null | tr '\0' '\n' \
        | grep -vE '(lock\.json|\.min\.[A-Za-z0-9]+|\.map)$' >"$list" || :
    [[ -s "$list" ]] || return 0

    # Binary/text split and sizes, both in BATCHES.
    ( cd "$dir" && xargs -a "$list" -d '\n' -r grep -Il . 2>/dev/null ) >"$base.textnames" || :
    ( cd "$dir" && xargs -a "$list" -d '\n' -r wc -c 2>/dev/null ) \
        | awk '{ sz=$1; $1=""; sub(/^ /,""); if ($0 != "total") print sz "\t" $0 }' >"$base.sizes" || :

    awk -F'\t' -v CAP="$SIZE_CAP" -v SIDE="$side" -v PFX="$pfx" -v SK="$SKIPPED_BIG" '
        NR==FNR { text[$0]=1; next }
        { nm=$2; if (!(nm in text)) next
          if ($1+0 > CAP) { printf "%s\t%s%s\t%s bytes > cap\n", SIDE, PFX, nm, $1 >> SK; next }
          print nm }' "$base.textnames" "$base.sizes" >"$txts"

    if [[ -s "$txts" ]]; then
        ( cd "$dir" && xargs -a "$txts" -d '\n' -r \
            awk -v W="$WIDTH" -v MINC="$MIN_CHARS" -v PFX="$pfx" \
                -v SW="$SHORT_W" -v SMINC="$SHORT_MINC" -v SMINAL="$SHORT_MINAL" \
                -v SLINEMAX="$slinemax" -v NAMES="$DO_NAMES" -v PRIVSIDE="$privside" \
                -v SANCH="$sanch" -v NANCH="$nanch" \
                -f "$SHINGLE_AWK" ) >>"$tagged" || :
    fi

    # PDFs are text-bearing but binary on disk. The most sensitive artefact in
    # this fleet is a PDF, so an inability to read one is UNDETERMINED, never a
    # quiet skip.
    grep -iE '\.pdf$' "$list" >"$pdfs" 2>/dev/null || :
    if [[ -s "$pdfs" ]]; then
        while IFS= read -r f; do
            [[ -n "$f" ]] || continue
            if ! command -v pdftotext >/dev/null 2>&1; then
                undet "$(qualify "$p" "$f"): a PDF in a $side repository could not be read (no pdftotext); its content was NOT checked"
                continue
            fi
            if ! pdftotext -layout "$dir/$f" "$base.pdftxt" 2>/dev/null; then
                undet "$(qualify "$p" "$f"): pdftotext could not extract text; its content was NOT checked"
                continue
            fi
            awk -v W="$WIDTH" -v MINC="$MIN_CHARS" -v PFX="$pfx" -v NAME="$f" \
                -v SW="$SHORT_W" -v SMINC="$SHORT_MINC" -v SMINAL="$SHORT_MINAL" \
                -v SLINEMAX="$slinemax" -v NAMES="$DO_NAMES" -v PRIVSIDE="$privside" \
                -v SANCH="$sanch" -v NANCH="$nanch" \
                -f "$SHINGLE_AWK" "$base.pdftxt" >>"$tagged" || :
            rm -f "$base.pdftxt"
        done <"$pdfs"
    fi

    # One split per repository. The emitter tags each record because a single
    # pass over every file is the whole point: the three key spaces must not
    # cost three reads of the tree.
    [[ -s "$tagged" ]] || return 0
    awk -F'\t' -v L="$out.L" -v S="$out.S" -v N="$out.N" '
        { rec = $2 "\t" $3 "\t" $4
          if      ($1 == "L") print rec >> L
          else if ($1 == "S") print rec >> S
          else if ($1 == "N") print rec >> N }' "$tagged"
    rm -f "$tagged"
}

# ── private corpus ────────────────────────────────────────────────────────────
# The private side is NEVER anchored: it is where the candidate keys come from.
SANCHOR_FILE=""; NANCHOR_FILE=""
PRIV_BASE="$TMPD/priv"
: >"$PRIV_BASE.L"; : >"$PRIV_BASE.S"; : >"$PRIV_BASE.N"
for p in "${PRIV_PATHS[@]:-}"; do
    [[ -n "$p" ]] || continue
    trace "private corpus: $p"
    emit_repo "$p" "$PRIV_BASE" priv
done
trace "private corpus done (L=$(wc -l <"$PRIV_BASE.L") S=$(wc -l <"$PRIV_BASE.S") N=$(wc -l <"$PRIV_BASE.N"))"

# ── PATH-REFERENCE mask, derived from the private indexes themselves ─────────
# Built once per WIDTH in use. A mask built at 10 tokens cannot mask a 5-token
# key, so the short pass needs its own or every private file name would read as
# a short-phrase leak.
priv_path_lines() {
    for p in "${PRIV_PATHS[@]:-}"; do
        [[ -n "$p" ]] || continue
        git -C "$ROOT/$p" ls-files 2>/dev/null | sed "s|^|$p/|"    # with submodule prefix
        git -C "$ROOT/$p" ls-files 2>/dev/null
        git -C "$ROOT/$p" ls-files 2>/dev/null | sed 's|.*/||'
    done
}
build_pathmask() { # $1 width  $2 out-file
    priv_path_lines | awk -v W="$1" '
        { line=$0; gsub(/[^A-Za-z0-9]+/," ",line); line=tolower(line)
          n=split(line,t," "); ntok=0; delete tok
          for(i=1;i<=n;i++) if(t[i]!=""){ntok++;tok[ntok]=t[i]}
          for(i=1;i+W-1<=ntok;i++){ s=tok[i]; for(j=i+1;j<i+W;j++) s=s" "tok[j]; print s } }' \
        | sort -u >"$2"
}
PATHMASK="$TMPD/pathmask.L"; build_pathmask "$WIDTH" "$PATHMASK"
PATHMASK_S="$TMPD/pathmask.S"; : >"$PATHMASK_S"
[[ $SHORT_W -gt 0 && "$SHORT_W" != "$WIDTH" ]] && build_pathmask "$SHORT_W" "$PATHMASK_S"
[[ "$SHORT_W" == "$WIDTH" ]] && cp "$PATHMASK" "$PATHMASK_S"

trace "path-reference mask built (L=$(wc -l <"$PATHMASK") S=$(wc -l <"$PATHMASK_S"))"
PRIV_KEYS="$TMPD/priv.keys.L"
cut -f1 "$PRIV_BASE.L" | sort -u | comm -23 - "$PATHMASK" >"$PRIV_KEYS"
PRIV_SKEYS="$TMPD/priv.keys.S"; : >"$PRIV_SKEYS"
[[ $SHORT_W -gt 0 ]] && cut -f1 "$PRIV_BASE.S" | sort -u | comm -23 - "$PATHMASK_S" >"$PRIV_SKEYS"
trace "private keys: long=$(wc -l <"$PRIV_KEYS") short=$(wc -l <"$PRIV_SKEYS")"

# ══════════════════════════════════════════════════════════════════════════════
# NAME CANDIDATES (class D3)
#
# NOTHING HERE IS A LIST OF NAMES. No name is written into this script, into its
# configuration, into its tests or into any file it creates — writing one down
# would itself be the disclosure the check exists to prevent. Candidates are
# DERIVED, every run, from the private repositories, by two independent routes:
#
#   (a) git identities of the private repositories — author and committer names
#       are person names BY CONSTRUCTION, with no heuristic involved;
#   (b) runs of consecutively Capitalised tokens in private prose, keeping only
#       those whose every token is RARE IN LOWERCASE across this corpus.
#
# (b) is what separates "Firstname Surname" from "Design Toolkit" or "Getting
# Started" without a gazetteer: a common noun that happens to be capitalised in
# a heading is abundant in lowercase elsewhere, and a surname is not.
#
# This file used to claim the rank rule was "scale-free — in a small fixture
# nothing clears NAME_MINCOUNT and no candidate is lost". BOTH HALVES ARE
# WITHDRAWN, because both are measurably false:
#   * not scale-free. Rank 2000 is a position in a VOCABULARY, and on this tree
#     it lands at count 89, so every token of every surviving false positive
#     (ranks 2167-14849, counts 1-80) passed straight through it.
#   * a small fixture DOES clear NAME_MINCOUNT. Mutation M22 needed exactly two
#     planted lines; a third put the fixture's given name at 5 occurrences and
#     the rank rule swept it unaided.
# The rank rule is KEPT — nothing that was ordinary should stop being ordinary
# — and the rank-independent NAME_PPM floor is unioned with it. THAT floor is
# the one that is 0 in a small corpus, because it is derived from corpus size.
#
# Route (a) is NOT subject to either rule. A git identity is a person by
# construction and needs no frequency evidence — which matters more now than it
# did, because the floor is the only tightening here with a real recall cost
# and route (a) is what still sees a name that crosses it.
#
# Names that are git identities of a PUBLIC repository are SUBTRACTED: the
# person who commits to the public repositories is publishing under that name
# already. That is how the repository owner's own name is excluded — derived,
# not hardcoded.
# ══════════════════════════════════════════════════════════════════════════════
NAME_CAND="$TMPD/names.cand"; : >"$NAME_CAND"
PRIV_NSRC="$TMPD/priv.src.N"; : >"$PRIV_NSRC"
if [[ $DO_NAMES -eq 1 ]]; then
    TOKFREQ="$TMPD/tokfreq"
    cut -f1 "$PRIV_BASE.L" | cut -d' ' -f1 | sort | uniq -c | sort -k1,1nr >"$TOKFREQ"
    # Corpus size, measured — not assumed. Every number derived from it is
    # printed in the summary, so the floor is never an invisible constant.
    TOK_TOTAL=$(awk '{s+=$1} END{print s+0}' "$TOKFREQ")
    if [[ "$NAME_FLOOR" -ge 0 ]]; then
        FLOOR="$NAME_FLOOR"
    else
        FLOOR=$(awk -v T="$TOK_TOTAL" -v P="$NAME_PPM" 'BEGIN{printf "%d", int(T * P / 1000000)}')
    fi
    COMMON_TOK="$TMPD/common.tokens"
    # ORDINARY = the old rank rule (kept, so nothing that was ordinary stops
    # being ordinary) UNION the new rank-independent frequency floor.
    awk -v R="$NAME_RANK" -v M="$NAME_MINCOUNT" -v F="$FLOOR" \
        '(NR<=R && $1+0>=M) || (F>0 && $1+0>=F) {print $2}' "$TOKFREQ" | sort -u >"$COMMON_TOK"

    git_identity_keys() { # $1 absolute repo dir
        { git -C "$1" log --format='%an%n%cn' -n "$NAME_IDENT_MAX" 2>/dev/null
          git -C "$1" config --get user.name 2>/dev/null; } \
        | awk '{ gsub(/[^A-Za-z]+/," "); n=split(tolower($0),a," ")
                 m=0; delete t; for(i=1;i<=n;i++) if(length(a[i])>=2){m++;t[m]=a[i]}
                 for(i=1;i+1<=m;i++){ print t[i]" "t[i+1]
                                      if(i+2<=m) print t[i]" "t[i+1]" "t[i+2] } }' \
        | sort -u
    }
    PUB_IDENT="$TMPD/ident.pub"; : >"$PUB_IDENT"
    for p in "${PUB_PATHS[@]:-}"; do
        [[ -n "$p" ]] || continue
        d="$ROOT/$p"; [[ "$p" == "." ]] && d="$ROOT"
        git_identity_keys "$d" >>"$PUB_IDENT"
    done
    # a public identity is excluded in BOTH orders, because the detector matches
    # both orders and an exclusion that only covered one would be half a rule.
    awk '{ print; n=split($0,a," "); if(n==2) print a[2]" "a[1] }' "$PUB_IDENT" \
        | sort -u >"$TMPD/ident.pub.keys"

    PRIV_IDENT="$TMPD/ident.priv"; : >"$PRIV_IDENT"
    for p in "${PRIV_PATHS[@]:-}"; do
        [[ -n "$p" ]] || continue
        git_identity_keys "$ROOT/$p" | sed "s|\$|\t$p:<git identity>|" >>"$PRIV_IDENT"
    done

    cut -f1 "$PRIV_BASE.N" | sort -u | awk -v C="$COMMON_TOK" '
        BEGIN{ while ((getline t < C) > 0) CM[t]=1; close(C) }
        { n=split($0,a," "); ok=1
          for(i=1;i<=n;i++) if (length(a[i]) < 2 || (a[i] in CM)) { ok=0; break }
          if (ok) print }' >"$TMPD/names.shape"

    { cat "$TMPD/names.shape"; cut -f1 "$PRIV_IDENT"; } | sort -u \
        | comm -23 - "$TMPD/ident.pub.keys" >"$NAME_CAND"

    { awk -F'\t' 'NR==FNR{K[$0]=1;next} ($1 in K){print $1"\t"$3}' "$NAME_CAND" "$PRIV_BASE.N"
      awk -F'\t' 'NR==FNR{K[$0]=1;next} ($1 in K){print $1"\t"$2}' "$NAME_CAND" "$PRIV_IDENT"
    } | sort -u >"$PRIV_NSRC"
    trace "name candidates: $(wc -l <"$NAME_CAND") (common-token set $(wc -l <"$COMMON_TOK"))"
fi

# key -> the private files it came from (only for keys that survived the mask)
PRIV_SRC="$TMPD/priv.src.L"
awk -F'\t' 'NR==FNR{K[$0]=1;next} ($1 in K){print $1"\t"$3}' "$PRIV_KEYS" "$PRIV_BASE.L" | sort -u >"$PRIV_SRC"
PRIV_SSRC="$TMPD/priv.src.S"; : >"$PRIV_SSRC"
[[ $SHORT_W -gt 0 ]] && awk -F'\t' 'NR==FNR{K[$0]=1;next} ($1 in K){print $1"\t"$3}' \
    "$PRIV_SKEYS" "$PRIV_BASE.S" | sort -u >"$PRIV_SSRC"
trace "private key->source tables: L=$(wc -l <"$PRIV_SRC") S=$(wc -l <"$PRIV_SSRC") N=$(wc -l <"$PRIV_NSRC")"

# ── anchors for the public side ──────────────────────────────────────────────
# The public emitter builds a short shingle or a name run only where the FIRST
# token is one the private side actually has. Both orders of every name
# candidate are anchored, or a reversed name would never be built to be tested.
SANCHOR_FILE="$TMPD/anchor.S"; : >"$SANCHOR_FILE"
NANCHOR_FILE="$TMPD/anchor.N"; : >"$NANCHOR_FILE"
[[ $SHORT_W -gt 0 ]] && cut -d' ' -f1 "$PRIV_SKEYS" | sort -u >"$SANCHOR_FILE"
[[ $DO_NAMES -eq 1 ]] && tr ' ' '\n' <"$NAME_CAND" | sort -u >"$NANCHOR_FILE"

# ── scan every in-scope public repository, streaming ─────────────────────────
HITS_L="$TMPD/hits.L"; : >"$HITS_L"
HITS_S="$TMPD/hits.S"; : >"$HITS_S"
HITS_N="$TMPD/hits.N"; : >"$HITS_N"
PUB_BASE="$TMPD/pub"
for p in "${PUB_PATHS[@]:-}"; do
    [[ -n "$p" ]] || continue
    trace "scanning public repo: $p"
    : >"$PUB_BASE.L"; : >"$PUB_BASE.S"; : >"$PUB_BASE.N"
    emit_repo "$p" "$PUB_BASE" pub
    awk -F'\t' -v REPO="$p" 'NR==FNR{K[$0]=1;next} ($1 in K){print $1"\t"REPO"\t"$3"\t"$2}' \
        "$PRIV_KEYS" "$PUB_BASE.L" >>"$HITS_L"
    [[ $SHORT_W -gt 0 ]] && awk -F'\t' -v REPO="$p" 'NR==FNR{K[$0]=1;next} ($1 in K){print $1"\t"REPO"\t"$3"\t"$2}' \
        "$PRIV_SKEYS" "$PUB_BASE.S" >>"$HITS_S"
    # names match in EITHER order; the row always carries the CANDIDATE key so
    # the private-source join and the exemption globs see one canonical form.
    [[ $DO_NAMES -eq 1 ]] && awk -F'\t' -v REPO="$p" '
        NR==FNR{K[$0]=1;next}
        { if ($1 in K) { print $1"\t"REPO"\t"$3"\t"$2; next }
          n=split($1,a," "); if (n==2) { r=a[2]" "a[1]; if (r in K) print r"\t"REPO"\t"$3"\t"$2 } }' \
        "$NAME_CAND" "$PUB_BASE.N" >>"$HITS_N"
    rm -f "$PUB_BASE.L" "$PUB_BASE.S" "$PUB_BASE.N"
done
trace "public scan done (L=$(wc -l <"$HITS_L") S=$(wc -l <"$HITS_S") N=$(wc -l <"$HITS_N") raw matches)"

# ── ALREADY-PUBLIC + DECLARED exemptions, once per key space ─────────────────
# Each class gets its OWN already-public set: "present in >= 2 public
# repositories" has to be asked of the same kind of key it is answering about.
EXEMPT_TOTAL=0
MULTI_TOTAL=0
FINAL="$TMPD/final.tsv"; : >"$FINAL"
declare -A MULTI_BY_CLASS=()

resolve_class() { # $1 class  $2 hits  $3 priv-src  $4 out
    local cls="$1" hits="$2" psrc="$3" out="$4"
    local mp="$TMPD/multipub.$cls" surv="$TMPD/surv.$cls" pairs="$TMPD/pairs.$cls"
    local exc="$TMPD/ex.$cls"
    : >"$out"; : >"$mp"; printf '0\n' >"$exc"; printf '0\n' >"$TMPD/pathex.$cls"
    [[ -s "$hits" ]] || return 0
    cut -f1,2 "$hits" | sort -u | cut -f1 | uniq -d >"$mp"
    sort -t$'\t' -k1,1 "$hits" | join -t$'\t' -1 1 -2 1 -v 1 - "$mp" >"$surv" 2>/dev/null || : >"$surv"
    sort -t$'\t' -k1,1 -o "$surv" "$surv"
    join -t$'\t' -1 1 -2 1 -o 0,2.2,1.2,1.3,1.4 "$surv" "$psrc" >"$pairs" 2>/dev/null || : >"$pairs"
    awk -F'\t' -v ALLOW="$ALLOW_TSV" -v EXC="$exc" -v CLS="$cls" -v PEX="$TMPD/pathex.$cls" '
    # PATH-REFERENCE, name flavour. A candidate whose EVERY token already
    # appears in the private source path or in the public file path is naming
    # the document''s subject, not a person: `.../29-mail-server-factory.pdf`
    # reaching `_content/products/Mail-Server-Factory.md` is a product page,
    # sixteen times over once the site is localised.
    #
    # EVERY token, never "any". The one artefact in this fleet whose FILENAME
    # carries a participant''s FIRST name would otherwise pardon that person''s
    # full name — first name in the path, surname not, so "all" keeps it and
    # "any" would have lost it. That asymmetry is the whole reason this rule is
    # written this way.
    function normpath(s) { gsub(/[^A-Za-z0-9]+/, " ", s); return " " tolower(s) " " }
    function allin(key, path,   n, a, i, p) {
      p = normpath(path); n = split(key, a, " ")
      for (i = 1; i <= n; i++) if (index(p, " " a[i] " ") == 0) return 0
      return 1
    }
    function glob2re(g,   r, i, c) {
      r = "^"
      for (i = 1; i <= length(g); i++) {
        c = substr(g, i, 1)
        if (c == "*")      r = r ".*"
        else if (c == "?") r = r "."
        else if (index("\\^$.[]|()+{}", c)) r = r "\\" c
        else               r = r c
      }
      return r "$"
    }
    BEGIN{
      FS = "\t"
      while ((getline ln < ALLOW) > 0) {
        split(ln, a, "\t")
        if (a[1] == "" || a[2] == "") continue
        NA++; GP[NA] = glob2re(a[1]); GQ[NA] = glob2re(a[2])
      }
      close(ALLOW)
    }
    {
      priv = $2; pub = $4
      if (CLS == "name" && (allin($1, priv) || allin($1, pub))) { pe++; next }
      for (i = 1; i <= NA; i++) if (priv ~ GP[i] && pub ~ GQ[i]) { ex++; next }
      print CLS "\t" priv "\t" pub "\t" $5 "\t" $1
    }
    END{ printf "%d\n", ex + 0 > EXC; printf "%d\n", pe + 0 > PEX }
    ' "$pairs" >"$out"
}

# Done as ONE sorted join plus ONE awk per class. The obvious shape —
# re-scanning the private-source table once per surviving hit — is
# O(hits x sources) and made this gate take longer than the push it guards.
resolve_class prose "$HITS_L" "$PRIV_SRC"  "$TMPD/final.L"
resolve_class short "$HITS_S" "$PRIV_SSRC" "$TMPD/final.S"
resolve_class name  "$HITS_N" "$PRIV_NSRC" "$TMPD/final.N"
cat "$TMPD/final.L" "$TMPD/final.S" "$TMPD/final.N" >"$FINAL"
for cls in prose short name; do
    n=$(cat "$TMPD/ex.$cls" 2>/dev/null || echo 0)
    EXEMPT_TOTAL=$((EXEMPT_TOTAL + n))
    m=$(wc -l <"$TMPD/multipub.$cls" 2>/dev/null | tr -d ' ' || echo 0)
    MULTI_BY_CLASS[$cls]=$m
    MULTI_TOTAL=$((MULTI_TOTAL + m))
done
EXEMPTED=$EXEMPT_TOTAL
trace "exemptions applied; $(wc -l <"$FINAL") surviving rows"

sort -u -o "$FINAL" "$FINAL"

# A stable, non-disclosing IDENTIFIER for every name finding, appended as a
# sixth column. Two rows carrying the same person get the same id, so a report
# can say "three occurrences of two distinct names" without any report, log or
# archive ever containing the name itself. It is a small polynomial digest, not
# a security primitive, and it is not claimed to be one.
awk -F'\t' '
function h(s,   i, v) { v = 0
  for (i = 1; i <= length(s); i++) v = (v * 131 + ORD[substr(s, i, 1)]) % 2147483647
  return sprintf("%08x", v) }
BEGIN{ OFS = "\t"
  # substr(), not split(s,a,"") — an empty field separator is undefined in
  # POSIX awk and this tree already carries seven frozen GNU-only assumptions.
  A = "abcdefghijklmnopqrstuvwxyz0123456789 -"
  for (i = 1; i <= length(A); i++) ORD[substr(A, i, 1)] = i + 32 }
{ print $0, ($1 == "name" ? h($5) : "-") }' "$FINAL" >"$FINAL.id" && mv "$FINAL.id" "$FINAL"

# Counted from the DEDUPLICATED result, never from the per-class files: the
# union is `sort -u`'d, so a per-class `wc -l` overstates the total it is meant
# to decompose. A summary whose parts do not add up to its own total is the
# kind of small dishonesty that makes a whole report unusable.
LEAKS=$(wc -l <"$FINAL" | tr -d ' ')
LEAKS_PROSE=$(awk -F'\t' '$1=="prose"' "$FINAL" | wc -l | tr -d ' ')
LEAKS_SHORT=$(awk -F'\t' '$1=="short"' "$FINAL" | wc -l | tr -d ' ')
LEAKS_NAME=$(awk -F'\t' '$1=="name"' "$FINAL" | wc -l | tr -d ' ')
MULTI_N=$MULTI_TOTAL
MULTIPUB="$TMPD/multipub.prose"
UNDET_N=$(wc -l <"$UNDET_ROWS" | tr -d ' ')
SKIP_N=$(wc -l <"$SKIPPED_BIG" | tr -d ' ')

# ══════════════════════════════════════════════════════════════════════════════
# REPORT
# ══════════════════════════════════════════════════════════════════════════════
MARK=""; [[ $SYNTHETIC -eq 1 ]] && MARK="${C_YEL}[SYNTHETIC FLEET]${C_OFF} "

vsay ""
vsay "${MARK}${C_BLD}content boundary — private material inside public repositories${C_OFF}"
vsay "root: $ROOT"
vsay ""
vsay "${C_BLD}fleet${C_OFF}"
while IFS=$'\t' read -r p role ev; do
    col="$C_DIM"
    case "$role" in
        private)      col="$C_YEL" ;;
        public)       col="$C_GRN" ;;
        unverified)   col="$C_RED" ;;
    esac
    vsay "  $(printf '%-28s' "$p") ${col}$(printf '%-13s' "$role")${C_OFF} ${C_DIM}$ev${C_OFF}"
done <"$FLEET"

if [[ $LEAKS -gt 0 ]]; then
    say ""
    say "${MARK}${C_RED}${C_BLD}LEAK — private-only content found in a public repository${C_OFF}"
    say "  ${C_DIM}classes: prose=$LEAKS_PROSE (>= $WIDTH-token run)  short=$LEAKS_SHORT (private heading/list line, $SHORT_W-token run)  name=$LEAKS_NAME (personal name)${C_OFF}"
    [[ $LEAKS_NAME -gt 0 ]] && say "  ${C_DIM}$(awk -F'\t' '$1=="name" && !($6 in n){n[$6]=1; c++} END{print c+0}' "$FINAL") distinct personal name(s), identified below by digest only${C_OFF}"
    prev=""; prevcls=""
    while IFS=$'\t' read -r cls src pub line key nid; do
        if [[ "$src" != "$prev" || "$cls" != "$prevcls" ]]; then
            say ""; say "  ${C_YEL}private${C_OFF}  $src   ${C_DIM}[$cls]${C_OFF}"
            prev="$src"; prevcls="$cls"
        fi
        say "    ${C_RED}public${C_OFF}   $pub:$line"
        if [[ "$cls" == "name" ]]; then
            # DELIBERATELY NOT PRINTED. The matched text is a real person's
            # name and this output gets pasted into reports, CI logs and
            # incident notes — which is how the D3 class spread the first time.
            # The public file:line above is enough to act on, and reading it
            # is a deliberate act rather than a side effect of running a gate.
            say "      ${C_DIM}matched:${C_OFF} personal name #$nid ($(awk '{print NF}' <<<"$key") tokens), forward or reversed — withheld; read the public line above"
        else
            say "      ${C_DIM}matched:${C_OFF} ${key:0:110}"
        fi
    done <"$FINAL"
fi

# ALWAYS printed, whatever the exit code.
if [[ $UNDET_N -gt 0 ]]; then
    say ""
    say "${MARK}${C_YEL}${C_BLD}COULD NOT DETERMINE${C_OFF} ($UNDET_N)"
    while IFS= read -r r; do say "  - $r"; done <"$UNDET_ROWS"
fi

if [[ $QUIET -eq 0 ]]; then
    vsay ""
    vsay "${C_BLD}derived exonerations${C_OFF} ${C_DIM}(recomputed this run, nothing baked in)${C_OFF}"
    vsay "  path-reference mask   $(wc -l <"$PATHMASK" | tr -d ' ') long + $(wc -l <"$PATHMASK_S" | tr -d ' ') short shingles built from the private indexes' own file names"
    vsay "  ${C_DIM}not applied to the name class: a full name in a public file is a finding even${C_OFF}"
    vsay "  ${C_DIM}when a private FILE is named after the person. Use .content-boundary-allow to decide.${C_OFF}"
    vsay "  already-public        $MULTI_N key(s) in >= 2 public repositories (prose ${MULTI_BY_CLASS[prose]:-0}, short ${MULTI_BY_CLASS[short]:-0}, name ${MULTI_BY_CLASS[name]:-0})"
    if [[ $DO_NAMES -eq 1 ]]; then
        vsay "  name candidates       $(wc -l <"$NAME_CAND" | tr -d ' ') derived this run; $(wc -l <"$TMPD/ident.pub.keys" 2>/dev/null | tr -d ' ') public git identity form(s) subtracted"
        vsay "  name frequency floor  ${FLOOR:-0} occurrence(s) over ${TOK_TOTAL:-0} prose tokens ($( [[ "${NAME_FLOOR:-0}" -ge 0 ]] && echo "--name-floor, absolute" || echo "${NAME_PPM} per million, scale-free" )); $(wc -l <"$COMMON_TOK" 2>/dev/null | tr -d ' ') token(s) count as ordinary words"
        vsay "  ${C_DIM}RECALL COST, stated: a person whose name token reaches that floor in the${C_OFF}"
        vsay "  ${C_DIM}private corpus is invisible to the shape route. Only the git-identity${C_OFF}"
        vsay "  ${C_DIM}route still sees them, and only if they commit. See docs/content-boundary.md.${C_OFF}"
        vsay "  name path-reference   $(cat "$TMPD/pathex.name" 2>/dev/null || echo 0) match(es) whose every token is already in the private or public file's own path"
    fi
    if [[ $MULTI_N -gt 0 ]]; then
        vsay "  ${C_DIM}boundary: this cannot exonerate a passage leaked into two public repos at once.${C_OFF}"
        vsay "  ${C_DIM}private sources it cleared:${C_OFF}"
        awk -F'\t' 'NR==FNR{M[$0]=1;next} ($1 in M){print $2}' "$MULTIPUB" "$PRIV_SRC" \
            | sort -u | head -12 | while IFS= read -r s; do vsay "    ${C_DIM}$s${C_OFF}"; done
    fi
    vsay "  declared exemptions   $ALLOW_N pair(s) in ${ALLOW_FILE#"$ROOT"/}; $EXEMPTED match(es) pardoned"
    if [[ $SKIP_N -gt 0 ]]; then
        vsay "  not indexed           $SKIP_N file(s) over the ${SIZE_CAP}-byte cap or machine-generated"
    fi
fi

RC=0
[[ $UNDET -eq 1 ]] && RC=2
[[ $LEAKS -gt 0 ]] && RC=1   # precedence: a leak is a fact and outranks

say ""
case $RC in
  0) say "${MARK}${C_GRN}${C_BLD}CLEAN${C_OFF} — no private-only prose found in any in-scope public repository" ;;
  1) say "${MARK}${C_RED}${C_BLD}LEAK${C_OFF} — $LEAKS surviving match(es) (prose $LEAKS_PROSE, short $LEAKS_SHORT, name $LEAKS_NAME); $UNDET_N row(s) also could not be determined" ;;
  2) say "${MARK}${C_YEL}${C_BLD}COULD NOT DETERMINE${C_OFF} — $UNDET_N unresolved row(s); this is NOT a pass" ;;
esac
[[ $SYNTHETIC -eq 1 ]] && say "${C_YEL}This run used a SYNTHETIC fleet and is not evidence about any real repository.${C_OFF}"

if [[ $JSON -eq 1 ]]; then
    printf '{\n  "root": "%s",\n  "fleet_source": "%s",\n' "$ROOT" "$( [[ $SYNTHETIC -eq 1 ]] && echo spec || echo derived )"
    printf '  "counts": { "leaks": %s, "prose": %s, "short": %s, "name": %s, "undetermined": %s, "already_public": %s, "exempted": %s, "not_indexed": %s },\n' \
        "$LEAKS" "$LEAKS_PROSE" "$LEAKS_SHORT" "$LEAKS_NAME" "$UNDET_N" "$MULTI_N" "$EXEMPTED" "$SKIP_N"
    printf '  "windows": { "long": %s, "short": %s, "short_line_max": %s, "names": %s },\n' \
        "$WIDTH" "$SHORT_W" "$SHORT_LINEMAX" "$DO_NAMES"
    printf '  "fleet": [\n'
    awk -F'\t' '{printf "%s    {\"path\":\"%s\",\"role\":\"%s\",\"evidence\":\"%s\"}", (NR>1?",\n":""), $1,$2,$3} END{print ""}' "$FLEET"
    printf '  ],\n  "leaks": [\n'
    # The name class's matched text is REDACTED here for the same reason it is
    # withheld from the terminal: JSON gets archived, and a real person's name
    # in an archived artefact is the D3 disclosure all over again.
    awk -F'\t' '{gsub(/"/,"\\\"")
                 m = ($1 == "name" ? "<personal name withheld #" $6 ">" : $5)
                 printf "%s    {\"class\":\"%s\",\"private\":\"%s\",\"public\":\"%s\",\"line\":%s,\"match\":\"%s\"}", (NR>1?",\n":""), $1,$2,$3,$4,m} END{print ""}' "$FINAL"
    printf '  ],\n  "undetermined": [\n'
    awk '{gsub(/"/,"\\\"");printf "%s    \"%s\"", (NR>1?",\n":""), $0} END{print ""}' "$UNDET_ROWS"
    printf '  ],\n  "exit": %s\n}\n' "$RC"
fi

exit $RC
