#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Personal-name-shaped FINAL PATH COMPONENTS in tracked files — fleet-wide.
#
# WHY THIS EXISTS, PRECISELY
# --------------------------
# On 2026-09-02 a personal given name belonging to a third party was found in a
# TRACKED, COMMITTED, PUSHED file in this PUBLIC repository. It was not in a
# sentence. It was the LAST COMPONENT OF AN ABSOLUTE FILESYSTEM PATH, sitting in
# a table of indexed directories under a work-assignments parent:
#
#       .../Projects/<assignment-ish dir>/<a person's given name>
#
# Two instruments were in a position to see it and neither did:
#   * scripts/audit-hardcoded-paths.sh MATCHED both lines with its own PATTERN,
#     but its SKIP regex began `^(docs/` and was applied BEFORE the pattern, so
#     the file was never read. That scope hole is closed separately (the `docs/`
#     entry is gone from that SKIP and must not return).
#   * scripts/verify-content-boundary.sh hunts COPIED PRIVATE CONTENT. A path is
#     not copied content; a name inside a path is not prose. Different question.
#
# So this is a THIRD question, asked on purpose: not "is this path portable?"
# and not "was private text pasted here?", but "does a filesystem path in this
# repository name a HUMAN?". Nothing in this tree asked it before.
#
# WHAT IT LOOKS FOR — SHAPE, NEVER IDENTITY
# -----------------------------------------
# A hit needs BOTH halves of the signal, because either alone is worthless:
#
#   1. the PARENT component is a ROLE CONTAINER — a directory whose name says
#      its children are people or work assigned to people (`assignments/`,
#      `students/`, `home/`, `clients/`, `interviewees/`, …), and
#   2. the FINAL component is NAME-SHAPED — one bare alphabetic token, no
#      digits, no separators, 3–20 characters, `Capitalised` or `lowercase`.
#
# NO PERSONAL NAME IS WRITTEN IN THIS FILE, in any fixture, or in any test.
# There is no name list and there must never be one: a detector that ships a
# roster of real names is itself the disclosure it was built to prevent. Every
# vocabulary below is ROLE NOUNS and GENERIC TECHNICAL WORDS. Print them with
# `--vocab` and check that claim rather than believing it.
#
# THE OUTPUT NEVER REPRINTS THE SUSPECTED NAME.
# A gate that echoes the leaked token into a terminal, a CI log or a pasted
# report has widened the disclosure it just found. Findings are reported as
# `file:line  <container>/<REDACTED len=N case=…>`. The reader opens the file.
#
# PRECISION / RECALL — STATED, NOT IMPLIED (§11.4.6)
# --------------------------------------------------
# This is tuned for PRECISION, deliberately, because the failure mode of a
# name detector is not a missed name — it is a noisy gate that everybody learns
# to ignore, after which it catches nothing at all. The two-part signal is the
# whole trade: requiring a role-container parent throws away recall to buy a
# report a human will actually read.
#
# WHAT IT DELIBERATELY CANNOT SEE (printed on every run, never silent):
#   B1  A name whose parent directory is NOT in the container vocabulary.
#       `Projects/<name>`, `notes/<name>`, `img/<name>.png` are all invisible.
#       This is the largest blind spot and it is the price of the precision.
#   B2  A name that is not the FINAL component: `.../<name>/notes.md` is
#       invisible. Only the leaf is examined.
#   B3  Non-ASCII names. Matching is ASCII-letters-only, so a name written in
#       Cyrillic, Greek, or with diacritics does not match the shape test.
#   B4  Compound and separated forms — `firstname-lastname`, `first_last`,
#       `FirstLast` in camel case, or anything carrying a digit.
#   B5  Anything subtracted below: generic words, and tokens belonging to this
#       repository's OWN derived public identity.
#   B6  Untracked and ignored files. The scan universe is `git ls-files`.
#   B7  A name already inside the PUBLISHED HISTORY of a public remote. This
#       gate reads the working tree. History is not editable after a push and
#       this instrument says nothing about it.
#   B8  RELATIVE paths. Only a run whose opening `/` is a genuine filesystem
#       root is examined. `assignments/<name>` with no leading slash is
#       invisible. This is the anchoring rule that took the measured finding
#       count on this tree from 135 to a readable number, and it is the single
#       largest deliberate sacrifice of recall in the whole instrument: the
#       discarded 135 were, on inspection, English ALTERNATIONS in prose
#       (`client/server`, `person/entity`, `reviewer/author`) and relative
#       asset URLs — not paths at all.
#
# THE SUBTRACTIONS, AND WHAT EACH COSTS
#   S1  A closed vocabulary of generic technical/English words in the FINAL
#       position (`index`, `backlog`, `default`, …), plus every container word
#       and its `+s` plural — a container word is never a person.
#       COST: a real person whose name collides with a generic word is missed.
#   S2  This repository's OWN public identity, DERIVED AT RUN TIME and never
#       written down: alphabetic tokens taken from `git config user.name` /
#       `user.email`, every remote URL (root and submodules), the `.gitmodules`
#       URLs, and the components of this checkout's own absolute path. The
#       owner's own account name under `home/` is not a third-party disclosure,
#       and hard-coding it here would put a real name in a tracked file.
#       COST: a third party sharing a token with the owner's identity is missed.
#       The subtraction is reported as a COUNT; the tokens are not printed.
#
# Each surviving hit also carries a CORPUS FREQUENCY — how many times that same
# token occurs as ANY component of ANY anchored path anywhere in the scanned
# universe. A leaked personal name appears once or twice; a service account or a
# project word appears all over the file that created it. Frequency is REPORTED
# to help the reader judge and is deliberately NOT a filter: making it one would
# let a leak hide behind a busy repository.
#
# OWNERSHIP, three-valued exactly as the sibling audits do it
#   OWNED         -> findings are real. They FAIL (rc 1).
#   THIRD-PARTY   -> reported as an out-of-scope NOTE, never a verdict input
#                    (§11.4.156(C) / §11.4.29).
#   UNINITIALISED -> rc 2, COULD NOT DETERMINE. Never a pass, never a failure.
#
#   ./scripts/verify-name-in-path.sh                  # audit this repo + fleet
#   ./scripts/verify-name-in-path.sh --root /path     # audit another checkout
#   ./scripts/verify-name-in-path.sh --list           # show the scan universe
#   ./scripts/verify-name-in-path.sh --vocab          # show both vocabularies
#   ./scripts/verify-name-in-path.sh --no-submodules  # this repository only
#   ./scripts/verify-name-in-path.sh --prove-failure  # its §1.1 paired proof
#
# Declared exceptions live in `.name-in-path-allow`, one `path` or `path:line`
# per line, with `# REASON:` (justified, counted) or `# BASELINE:` (known,
# unfixed, PRINTED LOUDLY) on the comment block above it.
#
# Exit 0 = clean · 1 = findings in an owned repo · 2 = could not do its job
# ------------------------------------------------------------------------------
set -uo pipefail

MODE="audit"
SWEEP=1
TARGET=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --list)          MODE="list" ;;
        --vocab)         MODE="vocab" ;;
        --help|-h)       MODE="help" ;;
        --no-submodules) SWEEP=0 ;;
        --prove-failure) MODE="prove" ;;
        --root)          shift; TARGET="${1:-}" ;;
        -*)              echo "FATAL: unknown option '$1'" >&2; exit 2 ;;
        *)               TARGET="$1" ;;
    esac
    shift
done

# Captured BEFORE the `cd` below: the §1.1 proof re-invokes this exact entry
# point from inside a sandbox, where a relative ${BASH_SOURCE[0]} stops
# resolving the moment the working directory moves.
SELF_ABS="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/$(basename -- "${BASH_SOURCE[0]}")"

if [[ "$MODE" == "help" ]]; then
    grep -E '^#' "$SELF_ABS" | sed -n '2,120p' | sed 's/^# \{0,1\}//'
    exit 0
fi

# ------------------------------------------------------------------------------
# THE TWO VOCABULARIES.
#
# Read them. Neither contains a personal name, and neither may ever acquire one.
# ------------------------------------------------------------------------------

# ROLE CONTAINERS — directories whose children are people, or work assigned to
# people. English only; that is blind spot B3's sibling and is stated, not hidden.
CONTAINERS='
assignment assignments assignee assignees
person persons people humans individuals
staff employee employees worker workers colleague colleagues
student students pupil pupils trainee trainees intern interns apprentice apprentices
teacher teachers instructor instructors mentor mentors tutor tutors coach coaches
client clients customer customers
participant participants attendee attendees delegate delegates guest guests
candidate candidates interviewee interviewees applicant applicants
contact contacts contractor contractors freelancer freelancers
member members roster rosters
home homes users accounts profiles
speaker speakers author authors owner owners reviewer reviewers maintainer maintainers
volunteer volunteers patient patients recipient recipients
'

# GENERIC WORDS that may legitimately be the leaf under a container directory.
# Closed vocabulary; every entry is a technical or structural noun, never a name.
GENERIC='
index indexes readme license licence changelog contributing notes note
list lists all any none null empty unknown other others misc general common
shared public private internal external default custom template templates
example examples sample samples fixture fixtures mock mocks stub stubs demo
test tests spec specs suite suites case cases
data raw input inputs output outputs result results report reports
doc docs documentation manual guide guides reference
src source sources bin lib libs include includes vendor vendors
build builds dist target targets out tmp temp cache caches
config configs conf settings setup install installer script scripts tool tools
asset assets image images img media static public style styles theme themes
main master head base root top parent child children leaf node nodes
new old current latest previous next first last final draft final
active inactive pending done todo backlog archive archives archived
open closed blocked ready review reviewed approved rejected
local remote origin upstream downstream mirror mirrors
dev development stage staging prod production release releases
backup backups restore snapshot snapshots history log logs audit audits
admin administrator root superuser guest anon anonymous nobody
you me us them someone somebody everyone anyone
name names value values key keys id ids type types kind kinds
file files folder folder dir dirs directory directories path paths
group groups team teams org orgs project projects repo repos
work works task tasks job jobs run runs step steps phase phases
evidence proof proofs check checks gate gates rule rules policy policies
model models view views controller controllers service services
api apis web app apps site sites page pages
deploy deployment deployments release ops infra platform
overview summary detail details status state states
'

if [[ "$MODE" == "vocab" ]]; then
    echo "ROLE CONTAINERS (a hit needs one of these as the PARENT component):"
    printf '%s' "$CONTAINERS" | tr ' ' '\n' | grep -v '^$' | sort -u | paste -sd' ' - | fold -sw 76 | sed 's/^/  /'
    echo
    echo "GENERIC LEAF WORDS (subtracted in the FINAL position; S1):"
    printf '%s' "$GENERIC" | tr ' ' '\n' | grep -v '^$' | sort -u | paste -sd' ' - | fold -sw 76 | sed 's/^/  /'
    echo
    echo "Neither list contains a personal name. It must stay that way: a name"
    echo "list in a tracked file IS the disclosure this gate exists to prevent."
    exit 0
fi

if [[ -n "$TARGET" ]]; then
    ROOT="$(cd -- "$TARGET" 2>/dev/null && pwd)" \
        || { echo "FATAL: no such directory '$TARGET'" >&2; exit 2; }
else
    ROOT="$(cd -- "$(dirname -- "$SELF_ABS")/.." && pwd)" \
        || { echo "FATAL: cannot resolve script directory" >&2; exit 2; }
fi

for _bin in git awk grep sort; do
    command -v "$_bin" >/dev/null 2>&1 \
        || { echo "FATAL: required tool '$_bin' not on PATH" >&2; exit 2; }
done

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'
    DIM=$'\033[2m';    NC=$'\033[0m'
else
    RED=""; GREEN=""; YELLOW=""; DIM=""; NC=""
fi

# ------------------------------------------------------------------------------
# §1.1 PAIRED MUTATION PROOF  (--prove-failure)
#
# Shape copied from scripts/audit-hardcoded-paths.sh --prove-failure, for the
# reason that file records: two proofs in this tree were once found running
# their CONTROL against the LIVE tree, so any real finding made the control fail
# and ZERO mutations executed. Here the control is a SYNTHETIC throwaway
# repository, green by construction, which no state of this tree can redden. The
# live run still happens first, REPORTED and never gating, so a proof that only
# touches a sandbox while the real gate cannot start is also ruled out.
#
# NO REAL PERSON'S NAME APPEARS IN ANY FIXTURE. The planted token is invented,
# and it is ASSEMBLED FROM FRAGMENTS so the joined `<container>/<token>` literal
# never exists in this file — otherwise the proof would plant a finding in the
# detector's own source and redden the gate it proves.
#
# Every byte written lands inside a `mktemp -d`; nothing under the target
# repository is created, modified or removed, so no restore is needed.
# ------------------------------------------------------------------------------
if [[ "$MODE" == "prove" ]]; then
    _c="assign"; _c="${_c}ments"          # a container word, never joined below
    _n="Zeph"; _n="${_n}yrine"            # an INVENTED given name, not a real one
    _g="Quer"; _g="${_g}cus"              # a second invented token

    echo "CM-NAME-IN-PATH §1.1 PAIRED MUTATION PROOF"
    echo "----------------------------------------------------------------------"
    p_fails=0

    pf_out="$(bash "$SELF_ABS" --root "$ROOT" 2>&1)"; pf_rc=$?
    case "$pf_rc" in
        0) printf '✅ %-26s the real detector ran against the real tree, rc=0 (clean)\n' "PRE-FLIGHT live-run" ;;
        1) printf 'ℹ %-26s the real detector RAN against the real tree, rc=1 (real findings).\n' "PRE-FLIGHT live-run"
           printf '                           REPORTED, NOT GATING: the battery below uses a synthetic\n'
           printf '                           control, so a red tree cannot switch the proof off.\n' ;;
        2) printf 'ℹ %-26s the real detector RAN and returned rc=2 on the real tree.\n' "PRE-FLIGHT live-run"
           printf '                           REPORTED, NOT GATING; the battery still runs.\n' ;;
        *) printf '❌ %-26s undocumented exit code %s; the contract is 0/1/2 only\n' "PRE-FLIGHT live-run" "$pf_rc"
           p_fails=$((p_fails+1)) ;;
    esac

    SB="$(mktemp -d "${TMPDIR:-/tmp}/nameinpath-proof.XXXXXX")" \
        || { echo "UNDET: cannot create a sandbox; the proof could not run" >&2; exit 2; }
    trap 'rm -rf "$SB"' EXIT INT TERM

    sgit() { git -c user.name=nip-proof -c user.email=nip-proof@invalid \
                 -c core.hooksPath=/dev/null -c init.defaultBranch=main "$@"; }

    # Green by construction: no container/name pair anywhere, no .gitmodules.
    mk_control() {
        local d="$1"
        rm -rf "$d"; mkdir -p "$d/docs" "$d/scripts" || return 1
        sgit -C "." init -q "$d" >/dev/null 2>&1 || return 1
        printf '# demo\n\nA synthetic repository used only as a proof control.\n' > "$d/README.md"
        printf 'see docs/overview.md and scripts/tool.sh\n'                        > "$d/docs/inventory.md"
        printf '#!/usr/bin/env bash\necho hi\n'                                    > "$d/scripts/tool.sh"
        sgit -C "$d" add -A >/dev/null 2>&1 || return 1
        return 0
    }

    # p_assert <label> <desc> <want-rc> <needle> <fn...>
    p_assert() {
        local label="$1" desc="$2" want="$3" needle="$4"; shift 4
        local dir out rc slug
        slug="$(printf '%s' "$label" | tr -cd 'A-Za-z0-9')"
        dir="${SB}/mut_${slug}"
        rm -rf "$dir"
        if ! cp -r "$PRISTINE" "$dir"; then
            printf '❌ %-26s could not copy the control\n' "$label"; p_fails=$((p_fails+1)); return
        fi
        if ! "$@" "$dir"; then
            printf '❌ %-26s could not apply the mutation (%s)\n' "$label" "$desc"; p_fails=$((p_fails+1)); rm -rf "$dir"; return
        fi
        out="$(bash "$SELF_ABS" --root "$dir" 2>&1)"; rc=$?
        if [[ $rc -ne $want ]]; then
            printf '❌ %-26s %s\n' "$label" "$desc"
            printf '                           -> rc=%s, wanted %s. THIS GATE WOULD BE A SHAM (§1.1).\n' "$rc" "$want"
            printf '%s\n' "$out" | tail -6 | sed 's/^/        /'
            p_fails=$((p_fails+1)); rm -rf "$dir"; return
        fi
        if [[ -n "$needle" ]] && ! printf '%s' "$out" | grep -qF -- "$needle"; then
            printf '❌ %-26s %s\n' "$label" "$desc"
            printf '                           -> rc=%s as wanted, but the output never NAMED %s.\n' "$rc" "'$needle'"
            printf '%s\n' "$out" | tail -6 | sed 's/^/        /'
            p_fails=$((p_fails+1)); rm -rf "$dir"; return
        fi
        # THE MASKING INVARIANT, asserted on EVERY mutation without exception:
        # the planted token must never be echoed back. A gate that reprints what
        # it found has widened the disclosure instead of reporting it.
        if printf '%s' "$out" | grep -qF -- "$_n"; then
            printf '❌ %-26s %s\n' "$label" "$desc"
            printf '                           -> the OUTPUT REPRINTED the suspected token. A detector that\n'
            printf '                              echoes the name it found is a second disclosure.\n'
            p_fails=$((p_fails+1)); rm -rf "$dir"; return
        fi
        printf '✅ %-26s %s\n' "$label" "$desc"
        printf '                           -> rc=%s (wanted %s)%s\n' "$rc" "$want" "${needle:+  [names '$needle']}"
        rm -rf "$dir"
    }

    PRISTINE="${SB}/pristine"
    if ! mk_control "$PRISTINE"; then
        echo "UNDET: could not build the synthetic control repository" >&2; exit 2
    fi

    echo "  sandbox: ${SB}"
    echo "----------------------------------------------------------------------"

    out="$(bash "$SELF_ABS" --root "$PRISTINE" 2>&1)"; rc=$?
    if [[ $rc -eq 0 ]]; then
        printf '✅ %-26s unmutated synthetic repository passes (rc=0), by construction\n' "CONTROL synthetic-green"
    else
        printf '❌ %-26s returned rc=%s\n' "CONTROL synthetic-green" "$rc"
        printf '                           -> ABORTING: ZERO mutations ran, so NOTHING was proved. This is a\n'
        printf '                              fault in the proof harness, not a statement about this tree.\n'
        printf '%s\n' "$out" | tail -8 | sed 's/^/        /'
        exit 1
    fi

    plant()      { printf 'store row: /srv/data/%s/%s\n' "$_c" "$_n" >> "$1/docs/inventory.md"; }
    plant_gen()  { printf 'store row: /srv/data/%s/backlog\n' "$_c" >> "$1/docs/inventory.md"; }
    plant_nc()   { printf 'store row: /srv/data/archive/%s\n' "$_n" >> "$1/docs/inventory.md"; }
    plant_sep()  { printf 'store row: /srv/data/%s/%s-%s\n' "$_c" "$_n" "$_g" >> "$1/docs/inventory.md"; }
    allow_reason()   { plant "$1" && printf '# REASON: synthetic, justified for the proof\ndocs/inventory.md\n' > "$1/.name-in-path-allow"; }
    allow_baseline() { plant "$1" && printf '# BASELINE: synthetic known-unfixed finding\ndocs/inventory.md\n'  > "$1/.name-in-path-allow"; }
    allow_line()     {
        plant "$1" || return 1
        local ln; ln="$(grep -n "$_c" "$1/docs/inventory.md" | tail -1 | cut -d: -f1)"
        printf '# REASON: synthetic, scoped to one line\ndocs/inventory.md:%s\n' "$ln" > "$1/.name-in-path-allow"
    }
    allow_wrongline() {
        plant "$1" || return 1
        printf '# REASON: synthetic, scoped to a line that does NOT offend\ndocs/inventory.md:1\n' > "$1/.name-in-path-allow"
    }
    stale_allow()    { printf '# BASELINE: names a file that no longer offends\nscripts/tool.sh\n' > "$1/.name-in-path-allow"; }
    identity_sub()   {
        # The leaf equals a token of the repository's OWN derived identity, so
        # subtraction S2 must remove it — and this proves S2 is live rather
        # than asserted, because the SAME leaf fires in mutation N1.
        printf 'store row: /srv/data/%s/%s\n' "$_c" "$_g" >> "$1/docs/inventory.md"
        sgit -C "$1" remote add origin "git@example.invalid:someorg/${_g}.git" >/dev/null 2>&1 || return 1
        return 0
    }
    not_a_repo()     { rm -rf "$1/.git"; }
    no_such_dir()    { rm -rf "$1"; }
    empty_universe() { local d="$1"; rm -rf "$d"; mkdir -p "$d" && sgit -C "." init -q "$d" >/dev/null 2>&1; }
    uninit_sub()     {
        local d="$1"
        printf '[submodule "vendor/thing"]\n\tpath = vendor/thing\n\turl = git@github.com:someone/thing.git\n' > "$d/.gitmodules"
        printf 'schema_version: 1\ndeps:\n  - name: thing\n    ssh_url: git@github.com:someone/thing.git\n'    > "$d/helix-deps.yaml"
        mkdir -p "$d/vendor/thing" || return 1
        sgit -C "$d" add -A >/dev/null 2>&1 || true
        return 0
    }

    p_assert "N1 name-under-container"  "an invented given name as the leaf under a role-container dir " 1 "docs/inventory.md"   plant
    p_assert "N2 REASON-suppresses"     "the SAME finding, allow-listed with '# REASON:'               " 0 "explicitly allowed"  allow_reason
    p_assert "N3 BASELINE-is-loud"      "the SAME finding, allow-listed with '# BASELINE:'             " 0 "baselined finding"   allow_baseline
    p_assert "N4 line-scoped-allow"     "allow-listed as path:line — the exact offending line          " 0 "explicitly allowed"  allow_line
    p_assert "N5 wrong-line-no-pardon"  "allow-listed at a line that does NOT offend — must NOT pardon " 1 "docs/inventory.md"   allow_wrongline
    p_assert "N6 generic-leaf"          "a GENERIC leaf under the same container — subtraction S1      " 0 "no personal-name"    plant_gen
    p_assert "N7 no-container-parent"   "the same token under a NON-container parent — blind spot B1   " 0 "no personal-name"    plant_nc
    p_assert "N8 separated-form"        "a hyphenated compound leaf — blind spot B4, deliberately blind" 0 "no personal-name"    plant_sep
    p_assert "N9 identity-subtracted"   "leaf equals a token of the repo's OWN derived identity — S2   " 0 "no personal-name"    identity_sub
    p_assert "N10 stale-allow"          "an allow entry matching nothing is reported, never silent     " 0 "stale allow"         stale_allow
    p_assert "N11 target-absent"        "the target directory does not exist — cannot be inspected     " 2 "no such directory"   no_such_dir
    p_assert "N12 not-a-git-tree"       "the target is not a git working tree — nothing to enumerate   " 2 "not a git working tree" not_a_repo
    p_assert "N13 empty-universe"       "zero tracked files — a clean verdict over nothing is a bluff  " 2 "scan universe is empty" empty_universe
    p_assert "N14 uninit-submodule"     "a declared submodule is not checked out — NOT pass, NOT fail  " 2 "not initialised"     uninit_sub

    bash "$SELF_ABS" --root "$PRISTINE" >/dev/null 2>&1; rc=$?
    if [[ $rc -eq 0 ]]; then
        printf '✅ %-26s the unmutated control is still green after the battery (rc=0)\n' "CONTROL restored"
    else
        printf '❌ %-26s the control no longer passes (rc=%s); a mutation leaked out of its copy\n' "CONTROL restored" "$rc"
        p_fails=$((p_fails+1))
    fi

    echo "----------------------------------------------------------------------"
    if [[ $p_fails -eq 0 ]]; then
        echo "✅ CM-NAME-IN-PATH §1.1 MUTATION PROOF: PASS — the REAL entry point ran against"
        echo "   the REAL tree (reported, never gating), a SYNTHETIC control green by"
        echo "   construction passed, and 14 mutations each produced the required"
        echo "   THREE-VALUED verdict: one planted name-in-path as rc=1; a line-scoped"
        echo "   allow that pardons the offending line while a MIS-scoped one does not;"
        echo "   three suppression mechanisms as rc=0 that still name what they suppress;"
        echo "   three deliberate blind spots (generic leaf, no container parent,"
        echo "   separated form) correctly NOT fired; the run-time identity subtraction"
        echo "   shown LIVE on the same leaf that fires without it; and four"
        echo "   could-not-determine states as rc=2 — never a pass, never an accusation."
        echo "   Every one of the 14 mutations additionally asserted that the OUTPUT"
        echo "   never reprinted the planted token. The control is still green."
        exit 0
    fi
    echo "❌ CM-NAME-IN-PATH §1.1 MUTATION PROOF: FAIL — ${p_fails} of 14 mutations did not behave as required"
    exit 1
fi

# ------------------------------------------------------------------------------
# audit / list
# ------------------------------------------------------------------------------
cd "$ROOT" || { echo "FATAL: cannot cd to '$ROOT'" >&2; exit 2; }
git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1 \
    || { echo "FATAL: '$ROOT' is not a git working tree" >&2; exit 2; }

ALLOW_FILE="$ROOT/.name-in-path-allow"

BIN_EXT='\.(png|jpe?g|gif|webp|ico|bmp|tiff?|pdf|docx?|pptx?|xlsx?|odt|woff2?|ttf|otf|eot|zip|gz|tgz|bz2|xz|7z|rar|mp4|mov|avi|mkv|webm|mp3|wav|flac|so|dylib|dll|exe|bin|jar|class|wasm|pyc|db|sqlite3?|part-[0-9][0-9]*)$'
MAXBYTES=2097152

# ---- the submodule fleet (derived; no roster anywhere) ----------------------
FLEET_OWNED=""; FLEET_THIRD=""; FLEET_UNINIT=""; FLEET_UNCLASSED=""
if [[ "$SWEEP" == "1" && -r "$ROOT/.gitmodules" ]]; then
    _paths="$(git config -f "$ROOT/.gitmodules" --get-regexp 'submodule\..*\.path' 2>/dev/null | awk '{print $2}')"
    if [[ -n "$_paths" ]]; then
        if [[ -r "$ROOT/helix-deps.yaml" ]]; then
            _owned_urls="$(sed -n -E 's/^[[:space:]]*ssh_url:[[:space:]]*(.+)$/\1/p' \
                           "$ROOT/helix-deps.yaml" 2>/dev/null | tr -d '\r' | sort -u)"
            while IFS= read -r _p; do
                [[ -n "$_p" ]] || continue
                if [[ ! -e "$ROOT/$_p/.git" ]] \
                   || ! git -C "$ROOT/$_p" rev-parse --git-dir >/dev/null 2>&1; then
                    FLEET_UNINIT="${FLEET_UNINIT}${_p}	not initialised (no usable .git)"$'\n'
                    continue
                fi
                _url="$(git config -f "$ROOT/.gitmodules" --get "submodule.${_p}.url" 2>/dev/null || echo '')"
                if [[ -n "$_url" ]] && ! printf '%s\n' "$_owned_urls" | grep -qxF "$_url"; then
                    FLEET_THIRD="${FLEET_THIRD}${_p}	${_url}"$'\n'
                else
                    FLEET_OWNED="${FLEET_OWNED}${_p}"$'\n'
                fi
            done <<< "$_paths"
        else
            FLEET_UNCLASSED="$_paths"
        fi
    fi
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/verify-nameinpath.XXXXXX")" \
    || { echo "FATAL: cannot create a temporary directory" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT INT TERM

repo_candidates() {   # $1 = repo path relative to $ROOT ("" = the root itself)
    local rel="$1" dir="$ROOT" pfx=""
    if [[ -n "$rel" ]]; then dir="$ROOT/$rel"; pfx="$rel/"; fi
    git -C "$dir" ls-files 2>/dev/null | awk -v p="$pfx" '$0 != "" {print p $0}'
}

: > "$WORK/cand.txt"
repo_candidates "" >> "$WORK/cand.txt"

SWEPT=0; SWEPT_PATHS=""; THIRD_PATHS=""
while IFS= read -r _p; do
    [[ -n "$_p" ]] || continue
    repo_candidates "$_p" >> "$WORK/cand.txt"
    SWEPT=$((SWEPT+1)); SWEPT_PATHS="${SWEPT_PATHS}${_p}"$'\n'
done <<< "$FLEET_OWNED"
while IFS= read -r _row; do
    [[ -n "$_row" ]] || continue
    _p="${_row%%	*}"
    THIRD_PATHS="${THIRD_PATHS}${_p}"$'\n'
    repo_candidates "$_p" >> "$WORK/cand.txt"
    SWEPT=$((SWEPT+1)); SWEPT_PATHS="${SWEPT_PATHS}${_p}"$'\n'
done <<< "$FLEET_THIRD"

grep -viE "$BIN_EXT" "$WORK/cand.txt" > "$WORK/cand2.txt" || true
: > "$WORK/files.txt"
: > "$WORK/notscanned.txt"
while IFS= read -r f; do
    [[ -n "$f" ]] || continue
    [[ -f "$ROOT/$f" ]] || continue          # drops gitlinks and deleted files
    [[ -r "$ROOT/$f" ]] || continue
    sz="$(wc -c < "$ROOT/$f" | tr -d ' ')"; [[ -n "$sz" ]] || sz=0
    if [[ "$sz" -gt "$MAXBYTES" ]]; then
        printf '%s (%s bytes)\n' "$f" "$sz" >> "$WORK/notscanned.txt"; continue
    fi
    printf '%s\n' "$f" >> "$WORK/files.txt"
done < "$WORK/cand2.txt"

FILE_COUNT=$(grep -c . "$WORK/files.txt" || true)

if [[ "$MODE" == "list" ]]; then
    cat "$WORK/files.txt"
    printf -- '---- %s file(s) in the scan universe across %s repositor%s\n' \
        "$FILE_COUNT" "$((SWEPT+1))" "$([[ $((SWEPT+1)) -eq 1 ]] && echo y || echo ies)"
    exit 0
fi

# ANTI-BLUFF: a clean verdict over zero files is the empty-build success.
if [[ "$FILE_COUNT" -eq 0 ]]; then
    echo "FATAL: scan universe is empty — refusing to report a clean tree over" >&2
    echo "       zero files. Check the target repository." >&2
    exit 2
fi

# ---- S2: derive this repository's OWN public identity tokens, at RUN TIME ----
# Nothing here is written to disk and no token is printed. The point of deriving
# rather than declaring is that a declared list would put a real account name in
# a tracked file, which is the class of defect this gate exists to catch.
{
    git -C "$ROOT" config user.name  2>/dev/null || true
    git -C "$ROOT" config user.email 2>/dev/null || true
    git -C "$ROOT" remote -v 2>/dev/null | awk '{print $2}'
    [[ -r "$ROOT/.gitmodules" ]] && git config -f "$ROOT/.gitmodules" --get-regexp 'submodule\..*\.url' 2>/dev/null | awk '{print $2}'
    printf '%s\n' "$ROOT"
    while IFS= read -r _p; do
        [[ -n "$_p" ]] || continue
        git -C "$ROOT/$_p" remote -v 2>/dev/null | awk '{print $2}'
    done <<< "$SWEPT_PATHS"
} | tr -c 'A-Za-z' '\n' \
  | awk 'length($0) >= 3 { print tolower($0) }' \
  | sort -u > "$WORK/identity.txt"
IDENT_COUNT=$(grep -c . "$WORK/identity.txt" || true)

# ---- the scan ----------------------------------------------------------------
# One awk process over the whole universe. No GNU-only extensions.
AWK_PROG='
function is_nameshaped(t,   i, c, lower) {
    if (length(t) < 3 || length(t) > 20) return 0
    lower = 0
    for (i = 1; i <= length(t); i++) {
        c = substr(t, i, 1)
        if (c >= "A" && c <= "Z") { if (i > 1) return 0 }   # B4: no camel case
        else if (c >= "a" && c <= "z") lower++
        else return 0                                      # digits / . _ - excluded
    }
    if (lower < 2) return 0
    return 1
}
BEGIN {
    n = split(CONT, a, /[ \t\n]+/); for (i = 1; i <= n; i++) if (a[i] != "") cont[a[i]] = 1
    n = split(GEN,  b, /[ \t\n]+/); for (i = 1; i <= n; i++) if (b[i] != "") gen[b[i]]  = 1
    # Every container word, and its +s plural, is also a generic LEAF: a
    # container name is never a person. (Subtraction S1, second half.)
    for (w in cont) { gen[w] = 1; gen[w "s"] = 1 }
    while ((getline id < IDFILE) > 0) if (id != "") ident[id] = 1
    close(IDFILE)
    H = 0
}
{
    s = $0
    while (match(s, /\/[A-Za-z0-9_][A-Za-z0-9_.\/-]*/)) {
        st = RSTART; ln = RLENGTH
        prev = (st > 1) ? substr(s, st - 1, 1) : ""
        tok  = substr(s, st, ln)
        s    = substr(s, st + ln)

        # ANCHORING — the single biggest precision lever, and the reason this
        # gate is readable at all. Measured on this tree: without it, 135
        # findings, essentially all of them English ALTERNATIONS in prose
        # ("client/server", "person/entity", "reviewer/author") and relative
        # asset URLs. An alternation is not a path. A run only counts when the
        # "/" that opens it is genuinely the ROOT of an absolute path, i.e. the
        # character before it is not itself part of a path, a URL scheme, a
        # variable, or a ratio.
        # COST, stated: a name in a RELATIVE path (`assignments/<name>` with no
        # leading "/") is now invisible. That is blind spot B8.
        if (prev != "" && prev ~ /[A-Za-z0-9_.~$@:%+-]/) continue

        sub(/\/+$/, "", tok)
        m = split(tok, parts, "/")
        # Corpus census: every component of every anchored path run is counted,
        # whether or not this run turns into a finding. That census is what the
        # per-hit frequency below reports.
        for (q = 2; q <= m; q++) if (parts[q] != "") comp[tolower(parts[q])]++
        # parts[1] is the empty string before the leading "/", so a real
        # `/<dir>/<leaf>` yields m == 3. Anything smaller is `/leaf` alone.
        if (m < 3) continue
        leaf = parts[m]; par = parts[m-1]
        if (leaf == "" || par == "") continue
        lpar = tolower(par); lleaf = tolower(leaf)
        if (!(lpar in cont)) continue          # B1: needs a role-container parent
        if (!is_nameshaped(leaf)) continue     # B3/B4: ASCII single-token shape
        if (lleaf in gen)   continue           # S1
        if (lleaf in ident) continue           # S2
        H++
        hf[H] = FILENAME; hl[H] = FNR; hp[H] = par
        hn[H] = length(leaf); hc[H] = (leaf ~ /^[A-Z]/ ? "Capitalised" : "lowercase")
        hk[H] = lleaf
    }
}
END {
    # The leaf token is counted here and NEVER emitted. A leaked personal name
    # appears once or twice in a corpus; an account or project word appears all
    # over it — `/home/<service-account>` recurs in every ENV, WORKDIR and COPY
    # line of the file that created it. The census is over EVERY component of
    # EVERY anchored path run in the whole scanned universe, so the number is
    # about the corpus rather than about the findings. It is REPORTED to help
    # the reader judge and is deliberately NOT a filter: making it one would let
    # a leak hide behind a busy repository.
    for (i = 1; i <= H; i++)
        printf "HIT\t%s\t%d\t%s\t%d\t%s\t%d\n", hf[i], hl[i], hp[i], hn[i], hc[i], comp[hk[i]]
}
'

FILES=()
while IFS= read -r f; do [[ -n "$f" ]] || continue; FILES+=("$f"); done < "$WORK/files.txt"

LC_ALL=C awk -v CONT="$CONTAINERS" -v GEN="$GENERIC" -v IDFILE="$WORK/identity.txt" \
    "$AWK_PROG" "${FILES[@]}" > "$WORK/hits.tsv" 2>"$WORK/awk.err"
AWK_RC=$?
if [[ $AWK_RC -ne 0 ]]; then
    echo "FATAL: the scan itself failed (awk rc=$AWK_RC)" >&2
    sed 's/^/       /' "$WORK/awk.err" >&2
    exit 2
fi

# ---- allow-list --------------------------------------------------------------
: > "$WORK/allow.tsv"
: > "$WORK/allow.unmarked"
if [[ -f "$ALLOW_FILE" ]]; then
    awk '
        { line = $0 }
        line ~ /^[[:space:]]*$/ { kind = ""; next }
        line ~ /^[[:space:]]*#/ {
            if (line ~ /BASELINE:/)    kind = "BASELINE"
            else if (line ~ /REASON:/) kind = "REASON"
            next
        }
        { p = line
          sub(/^[[:space:]]+/, "", p); sub(/[[:space:]]+$/, "", p)
          if (p == "") next
          printf "%s\t%s\n", (kind == "") ? "UNMARKED" : kind, p }
    ' "$ALLOW_FILE" > "$WORK/allow.tsv"
    grep '^UNMARKED	' "$WORK/allow.tsv" | cut -f2 > "$WORK/allow.unmarked" || true
fi

allow_kind() {   # $1 = file, $2 = line ; echoes REASON|BASELINE|UNMARKED or nothing
    [[ -s "$WORK/allow.tsv" ]] || return 1
    awk -F'\t' -v f="$1" -v l="$2" '
        $2 == f || $2 == (f ":" l) { print $1; found = 1; exit }
        END { exit !found }' "$WORK/allow.tsv"
}

# ---- report ------------------------------------------------------------------
is_third_party() {
    local f="$1" p
    while IFS= read -r p; do
        [[ -n "$p" ]] || continue
        case "$f" in "$p"/*) printf '%s' "$p"; return 0 ;; esac
    done <<< "$THIRD_PATHS"
    return 1
}

violations=0; allowed=0; baselined=0; note_hits=0
: > "$WORK/baselined.txt"; : > "$WORK/notes.txt"; : > "$WORK/fired.txt"

while IFS=$'\t' read -r _tag f ln par len kase freq; do
    [[ "${_tag:-}" == "HIT" ]] || continue
    kind="$(allow_kind "$f" "$ln" || true)"
    if [[ -n "$kind" ]]; then
        printf '%s\n' "$f" >> "$WORK/fired.txt"
        printf '%s:%s\n' "$f" "$ln" >> "$WORK/fired.txt"
        if [[ "$kind" == "BASELINE" ]]; then
            baselined=$((baselined+1))
            printf '%s:%s  %s/<REDACTED len=%s case=%s>\n' "$f" "$ln" "$par" "$len" "$kase" >> "$WORK/baselined.txt"
        else
            allowed=$((allowed+1))
            printf "${YELLOW}⚠️  allowed${NC} %s:%s\n" "$f" "$ln"
        fi
        continue
    fi

    if tp="$(is_third_party "$f")"; then
        note_hits=$((note_hits+1))
        printf '%s:%s  %s/<REDACTED len=%s case=%s>  [third-party: %s]\n' \
            "$f" "$ln" "$par" "$len" "$kase" "$tp" >> "$WORK/notes.txt"
        continue
    fi

    violations=$((violations+1))
    printf "${RED}❌ %s:%s${NC}  %s/<REDACTED len=%s case=%s>  [leaf token occurs %s× as a path component corpus-wide]\n" \
        "$f" "$ln" "$par" "$len" "$kase" "$freq"
done < "$WORK/hits.tsv"

echo "────────────────────────────────────────────────────────"
printf '%sscanned %d file(s) across %d repositor%s%s\n' \
    "$DIM" "$FILE_COUNT" "$((SWEPT+1))" "$([[ $((SWEPT+1)) -eq 1 ]] && echo y || echo ies)" "$NC"
printf '%ssubtracted %d run-time identity token(s) derived from this checkout (S2);%s\n' "$DIM" "$IDENT_COUNT" "$NC"
printf '%sthe tokens themselves are never printed and never stored.%s\n' "$DIM" "$NC"
printf '%sBLIND BY DESIGN: a name is invisible unless its parent directory is one of%s\n' "$DIM" "$NC"
printf '%sthe declared role containers (--vocab), unless it is the FINAL component,%s\n' "$DIM" "$NC"
printf '%sand unless it is a single ASCII alphabetic token. Compound, camel-case,%s\n' "$DIM" "$NC"
printf '%saccented, Cyrillic and digit-bearing forms are NOT seen. Neither is history.%s\n' "$DIM" "$NC"

if [[ -s "$WORK/notscanned.txt" ]]; then
    printf '%sNOT SCANNED — larger than %s bytes:%s\n' "$YELLOW" "$MAXBYTES" "$NC"
    sed 's/^/     /' "$WORK/notscanned.txt"
fi

if [[ -s "$WORK/allow.unmarked" ]]; then
    printf '%s⚠️  allow-list entr(ies) with no "# REASON:"/"# BASELINE:" marker:%s\n' "$YELLOW" "$NC"
    sed 's/^/     /' "$WORK/allow.unmarked"
    printf '%s   They are honoured, but an unexplained suppression is a bluff.%s\n' "$YELLOW" "$NC"
fi

if [[ "$baselined" -gt 0 ]]; then
    printf '%s⚠️  %d baselined finding(s) — REAL, KNOWN, UNFIXED:%s\n' "$YELLOW" "$baselined" "$NC"
    sort "$WORK/baselined.txt" | sed 's/^/     /'
    printf '%s   A baseline is recorded DEBT, not a justification.%s\n' "$YELLOW" "$NC"
fi

if [[ -s "$WORK/allow.tsv" ]]; then
    STALE="$(cut -f2 "$WORK/allow.tsv" | while IFS= read -r b; do
                 [[ -n "$b" ]] || continue
                 grep -qxF "$b" "$WORK/fired.txt" 2>/dev/null || printf '%s\n' "$b"
             done)"
    if [[ -n "$STALE" ]]; then
        printf '%s⚠️  stale allow entr(ies) — listed but matching nothing:%s\n' "$YELLOW" "$NC"
        printf '%s\n' "$STALE" | sed 's/^/     /'
        printf '%s   Remove them; a dead entry silences the next real finding.%s\n' "$YELLOW" "$NC"
    fi
fi

if [[ -s "$WORK/notes.txt" ]]; then
    printf '%sNOTE — %d finding(s) in THIRD-PARTY gitlink(s), OUT OF SCOPE per%s\n' "$YELLOW" "$note_hits" "$NC"
    printf '%s§11.4.156(C) / §11.4.29 — reported so they are never silently omitted:%s\n' "$YELLOW" "$NC"
    sed 's/^/  /' "$WORK/notes.txt"
fi

if [[ -n "$FLEET_UNCLASSED" ]]; then
    printf '%sNOT SWEPT — gitlink(s) declared here, but this checkout ships no%s\n' "$YELLOW" "$NC"
    printf '%shelix-deps.yaml, so ownership cannot be derived and is not guessed:%s\n' "$YELLOW" "$NC"
    printf '%s\n' "$FLEET_UNCLASSED" | sed 's/^/     /'
fi

if [[ -n "$FLEET_UNINIT" ]]; then
    printf '%s⚠️  COULD NOT DETERMINE — submodule(s) not initialised:%s\n' "$RED" "$NC"
    printf '%s' "$FLEET_UNINIT" | sed 's/\t/: /' | sed 's/^/     /'
    printf '%s   Their contents are unknown. This is NOT a pass and NOT a failure.%s\n' "$RED" "$NC"
    echo   "   Run: git submodule update --init --recursive"
    [[ "$violations" -gt 0 ]] && printf "${RED}❌ %d personal-name-shaped path component(s) in owned repositories%s\n" "$violations" "$NC"
    exit 2
fi

if [[ $violations -eq 0 ]]; then
    printf "${GREEN}✅ no personal-name-shaped final path component under any role-container directory${NC}"
    [[ $allowed -gt 0 ]] && printf " (%d explicitly allowed)" "$allowed"
    echo
    exit 0
fi
printf "${RED}❌ %d personal-name-shaped final path component(s) under a role-container directory${NC}\n" "$violations"
echo
echo "The token is NOT reprinted here on purpose. Open the file at the line shown."
echo "If it names a real person: REMOVE it from the working tree, and remember that"
echo "a redaction is containment, not a remedy — anything already pushed is public"
echo "permanently. See docs/content-boundary.md."
echo
echo "If it is genuinely not a person, declare it in"
echo "  .name-in-path-allow   as 'path' or 'path:line', with a '# REASON:' or"
echo "                        '# BASELINE:' line above it"
exit 1
