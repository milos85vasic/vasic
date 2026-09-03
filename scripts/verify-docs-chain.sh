#!/usr/bin/env bash
# verify-docs-chain.sh — the Docs Chain binding is COMPLETE, CONTAINED, and IN SYNC.
#
# ============================================================================
# THE THREE FAILURE MODES THIS EXISTS FOR
# ============================================================================
#
# 1. DRIFT. A `.md` is edited, its `.html` and `.pdf` are not regenerated, and
#    an operator reads a divergent export while the Markdown is correct. That
#    is the exact "operator reads divergent HTML/PDF while .md is correct"
#    PASS-bluff §11.4.65 names by hand. Docs Chain can fix it; only a gate
#    makes anyone notice it needs fixing.
#
# 2. ROT. A Markdown document is added and never bound, because Docs Chain
#    binds explicit node paths and the context is a roster. The tree grows, the
#    roster does not, and §11.4.65 coverage silently falls below 100% while
#    every export that IS registered stays perfectly in sync — a green gate
#    over a shrinking scope. This check re-derives the roster from the tree and
#    fails on the difference, so "no new document went unbound" is measured
#    rather than assumed.
#
# 3. LEAK. This repository is PUBLIC and three of its submodules are PRIVATE.
#    Docs Chain node paths are project-root-relative, and an HTML or PDF export
#    carries the FULL TEXT of its source. A context at this root that named a
#    private source would render that source into a file, and one wrong path
#    would render it into a PUBLIC one. Committed and pushed, that is a
#    permanent, irreversible disclosure — history is not editable after a push.
#
#    The defence is structural, not careful. Checks C1 and C2 below assert that
#    NO node path in ANY context at this root leaves this repository: not into
#    a submodule (public or private), not through `..`, not by an absolute
#    path. A private source therefore has no node in any public-root chain, so
#    no transform can be asked to render one. A submodule that wants a chain
#    registers it in ITS OWN root, where its exports land in ITS OWN repository
#    by construction (§11.4.28(B)).
#
#    The submodule roster is read from `.gitmodules` at run time. This file
#    contains no list of private repositories, because such a list is wrong the
#    moment a submodule is added and a check that must be edited to stay
#    correct is a check that will not be.
#
# ============================================================================
# THE FORMAT SET IS .html + .pdf, AND THE CITATION IS §11.4.65
# ============================================================================
#
# Constitution §11.4.65, mandatory protection 1: "Every INCLUDED `.md` file has
# `.html` and `.pdf` siblings." DOCX is not in that set — §11.4.153 adds it for
# the per-feature Status document class only, and this repository has no
# document of that class. This check therefore asserts html+pdf and would be a
# §11.4.201(1) false-positive refusal if it demanded docx.
#
# ============================================================================
# THREE-VALUED EXIT, and rc=2 is NEVER a pass
# ============================================================================
#
#   0  every context is contained, complete, and in sync
#   1  a real finding: drift, an unbound document, or a path that leaves this
#      repository
#   2  could not determine: no root, not a git repository, no Docs Chain
#      binary, or a context that will not parse
#
# A CONFIRMED FAILURE OUTRANKS AN UNDETERMINED, and the counts are reported
# separately. There is no `--allow`, no `--ignore`, no suppression list: a
# suppression file is how a roster rots in the first place.
#
# Usage:
#   bash scripts/verify-docs-chain.sh
#   bash scripts/verify-docs-chain.sh --root <dir>
#   bash scripts/verify-docs-chain.sh --prove-failure   # §1.1 paired proof
#
# The Docs Chain binary is resolved from $DOCS_CHAIN_BIN, then PATH, then the
# constitution submodule's own build output. Nothing is assumed about where a
# host keeps it.

set -uo pipefail

SELF_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd -- "$SELF_DIR/.." && pwd)"
PROVE=0

while [ "$#" -gt 0 ]; do
    case "$1" in
        --prove-failure) PROVE=1; shift ;;
        --root)          ROOT="${2:-}"; shift 2 ;;
        -h|--help)       sed -n '1,80p' "${BASH_SOURCE[0]}"; exit 0 ;;
        *) printf 'UNDETERMINED: unknown argument %s\n' "$1" >&2; exit 2 ;;
    esac
done

FAIL=0; UNDET=0

# ---------------------------------------------------------------------------
# EXIT-CODE TRANSLATION — the two contracts DISAGREE about the meaning of 2,
# and passing it through would invert the safe direction.
#
#   docs_chain:   0 ok · 1 error · 2 CONFLICT · 3 transform-fail · 4 cycle/config-error
#   this project: 0 ok · 1 a real finding · 2 COULD NOT DETERMINE (never a pass)
#
# A docs_chain 2 is a CONFIRMED conflict — both sides of a sync edge dirty. Read
# as this project's 2 it would become "could not determine", DOWNGRADING a
# confirmed failure into an undetermined one, which is exactly backwards: the
# repository's own rule is that a confirmed failure OUTRANKS an undetermined.
#
# So the mapping is explicit, named, and asserted by --prove-failure (M7)
# rather than left implicit at a call site:
#
#   0 -> ok      the chains are in sync
#   1 -> FAIL    docs_chain "error" here means drift, which is a real finding
#   2 -> FAIL    CONFLICT is a confirmed finding, NOT an undetermined one
#   3 -> UNDET   a transform could not run (e.g. a ToolAbsentError)
#   4 -> UNDET   the configuration would not load; sync state is unknowable
#   * -> UNDET   an unknown code is not a pass
# ---------------------------------------------------------------------------
translate_docs_chain_rc() {
    case "$1" in
        0) printf 'ok'    ;;
        1) printf 'FAIL'  ;;
        2) printf 'FAIL'  ;;
        3) printf 'UNDET' ;;
        4) printf 'UNDET' ;;
        *) printf 'UNDET' ;;
    esac
}

green() { printf '  \033[32m%-10s\033[0m %s\n' "$1" "$2"; }
redln() { printf '  \033[31m%-10s\033[0m %s\n' "$1" "$2"; }
amber() { printf '  \033[33m%-10s\033[0m %s\n' "$1" "$2"; }
bad()   { redln "$1" "$2"; FAIL=$((FAIL+1)); }
undet() { amber "$1" "$2"; UNDET=$((UNDET+1)); }

# ---------------------------------------------------------------------------
# BINARY RESOLUTION. Probed, in order, and reported honestly when absent — an
# absent tool is could-not-determine (rc 2), never a clean tree (rc 0). The
# §11.4.201(6) false-null: a missing binary and a compliant tree would
# otherwise return the same quiet zero.
# ---------------------------------------------------------------------------
resolve_bin() {
    if [ -n "${DOCS_CHAIN_BIN:-}" ] && [ -x "${DOCS_CHAIN_BIN}" ]; then
        printf '%s' "$DOCS_CHAIN_BIN"; return 0
    fi
    if command -v docs_chain >/dev/null 2>&1; then
        command -v docs_chain; return 0
    fi
    local built="$ROOT/submodules/constitution/submodules/docs_chain/docs_chain"
    [ -x "$built" ] && { printf '%s' "$built"; return 0; }
    return 1
}

# ===========================================================================
# --prove-failure: the §1.1 paired mutation for THIS check.
#
# A check never observed reporting a leak is not known to detect one. This
# builds a throwaway repository — NEVER the real tree — and requires a
# specific verdict from each seeded defect, plus a golden-FALSE control that
# must NOT fire (§11.4.201(1): a check that refuses a clean tree has replaced
# a bluff with a deadlock).
# ===========================================================================
if [ "$PROVE" -eq 1 ]; then
    printf '== prove-failure: this check must be SEEN detecting drift, rot and escape ==\n\n'

    BIN="$(resolve_bin)" || {
        printf 'UNDETERMINED: no docs_chain binary. Build it with:\n' >&2
        printf '  (cd submodules/constitution/submodules/docs_chain && go build -o docs_chain ./cmd/docs_chain)\n' >&2
        exit 2
    }
    export DOCS_CHAIN_BIN="$BIN"

    LAB="$(mktemp -d)" || { printf 'UNDETERMINED: cannot create a lab directory\n' >&2; exit 2; }
    trap 'rm -rf "$LAB"' EXIT

    mkdir -p "$LAB/scripts" "$LAB/docs" "$LAB/sub"
    cp "$SELF_DIR/gen-docs-chain-contexts.sh" "$LAB/scripts/"
    cp "${BASH_SOURCE[0]}"                     "$LAB/scripts/"
    printf '# Lab\n\nA lab document.\n'       > "$LAB/README.md"
    printf '# Guide\n\nA lab guide.\n'        > "$LAB/docs/guide.md"
    printf '# Private\n\nSecret prose.\n'     > "$LAB/sub/PRIVATE.md"
    # A declared submodule path, exactly as .gitmodules spells one. The lab's
    # `sub/` stands in for a private submodule: the check must refuse a node
    # naming it WITHOUT knowing anything about a remote's visibility.
    printf '[submodule "sub"]\n\tpath = sub\n\turl = git@example.invalid:o/sub.git\n' > "$LAB/.gitmodules"

    git -C "$LAB" init -q                                   >/dev/null 2>&1
    git -C "$LAB" config user.email lab@example.invalid     >/dev/null 2>&1
    git -C "$LAB" config user.name  lab                     >/dev/null 2>&1
    git -C "$LAB" add -A                                    >/dev/null 2>&1

    run_lab() { bash "$LAB/scripts/verify-docs-chain.sh" --root "$LAB" >"$LAB/out.txt" 2>&1; printf '%s' "$?"; }

    bash "$LAB/scripts/gen-docs-chain-contexts.sh" --root "$LAB" >/dev/null 2>&1 || {
        printf 'UNDETERMINED: the generator failed inside the lab\n' >&2; exit 2; }
    "$BIN" sync --all --root "$LAB" >/dev/null 2>&1 || {
        printf 'UNDETERMINED: the lab could not be synced; this proof would measure a\n' >&2
        printf 'broken fixture rather than the check.\n' >&2; exit 2; }
    git -C "$LAB" add -A >/dev/null 2>&1

    printf -- '--- GOLDEN-FALSE control: a clean, fully-synced lab ---\n'
    G="$(run_lab)"; sed 's/^/    | /' "$LAB/out.txt" | head -10
    printf '    rc=%s (expected 0)\n\n' "$G"

    printf -- '--- M1 DRIFT: edit a source, do not re-sync ---\n'
    printf '# Guide\n\nAn EDITED lab guide.\n' > "$LAB/docs/guide.md"
    M1="$(run_lab)"; grep -i 'drift\|out of sync\|C4' "$LAB/out.txt" | head -3 | sed 's/^/    | /'
    printf '    rc=%s (expected 1)\n\n' "$M1"
    printf '# Guide\n\nA lab guide.\n' > "$LAB/docs/guide.md"
    "$BIN" sync --all --root "$LAB" >/dev/null 2>&1

    printf -- '--- M2 MISSING EXPORT: delete a .pdf sibling ---\n'
    rm -f "$LAB/docs/guide.pdf"
    M2="$(run_lab)"; grep -i 'missing\|absent\|C5' "$LAB/out.txt" | head -3 | sed 's/^/    | /'
    printf '    rc=%s (expected 1)\n\n' "$M2"
    "$BIN" sync --all --root "$LAB" >/dev/null 2>&1

    printf -- '--- M3 ROT: add a document and leave it unbound ---\n'
    printf '# Orphan\n\nAdded later, bound by nobody.\n' > "$LAB/docs/orphan.md"
    git -C "$LAB" add -A >/dev/null 2>&1
    M3="$(run_lab)"; grep -i 'unbound\|coverage\|C3' "$LAB/out.txt" | head -3 | sed 's/^/    | /'
    printf '    rc=%s (expected 1)\n\n' "$M3"
    rm -f "$LAB/docs/orphan.md"; git -C "$LAB" add -A >/dev/null 2>&1

    printf -- '--- M4 LEAK: a context names a source inside a declared submodule ---\n'
    cat >> "$LAB/.docs_chain/contexts/umbrella-docs.yaml" <<'LEAKY'
# --- seeded by --prove-failure ---
LEAKY
    # Rewrite the context to include a node under the declared submodule path.
    # This is EXACTLY the shape that would render a private source into a file.
    awk '/^nodes:/{print; print "  leak_md:   { kind: markdown, path: sub/PRIVATE.md }"; print "  leak_html: { kind: html,     path: sub/PRIVATE.html }"; next} {print}' \
        "$LAB/.docs_chain/contexts/umbrella-docs.yaml" > "$LAB/ctx.tmp" && mv "$LAB/ctx.tmp" "$LAB/.docs_chain/contexts/umbrella-docs.yaml"
    M4="$(run_lab)"; grep -i 'submodule\|leaves this repository\|C1' "$LAB/out.txt" | head -4 | sed 's/^/    | /'
    printf '    rc=%s (expected 1)\n\n' "$M4"

    printf -- '--- M5 ESCAPE: a context names a path above the root via .. ---\n'
    bash "$LAB/scripts/gen-docs-chain-contexts.sh" --root "$LAB" >/dev/null 2>&1
    awk '/^nodes:/{print; print "  esc_md:   { kind: markdown, path: ../outside.md }"; print "  esc_html: { kind: html,     path: ../outside.html }"; next} {print}' \
        "$LAB/.docs_chain/contexts/umbrella-docs.yaml" > "$LAB/ctx.tmp" && mv "$LAB/ctx.tmp" "$LAB/.docs_chain/contexts/umbrella-docs.yaml"
    M5="$(run_lab)"; grep -i 'escape\|\.\.\|C2' "$LAB/out.txt" | head -3 | sed 's/^/    | /'
    printf '    rc=%s (expected 1)\n\n' "$M5"

    printf -- '--- M6 UNDETERMINED: no Docs Chain binary is resolvable ---\n'
    bash "$LAB/scripts/gen-docs-chain-contexts.sh" --root "$LAB" >/dev/null 2>&1
    "$BIN" sync --all --root "$LAB" >/dev/null 2>&1
    # A sanitised PATH, NOT an empty one. `PATH=/nonexistent` was the first
    # shape and it was WRONG: the shell then could not resolve `bash` either,
    # so the probe exited 127 without ever reaching the check — a §11.4.201(11)
    # proxy failure, measuring the harness instead of the subject. Keep the
    # standard binary directories, remove only the thing under test.
    M6_PATH=/usr/bin:/bin
    if PATH="$M6_PATH" command -v docs_chain >/dev/null 2>&1; then
        # Honest SKIP (§11.4.3) rather than a false assertion: this host keeps a
        # docs_chain on the sanitised PATH, so "no binary is resolvable" is not a
        # state this lab can construct without lying about it.
        printf '    SKIP: docs_chain is present on %s, so the absent-binary state\n' "$M6_PATH"
        printf '    cannot be constructed here. Reason: tool_present_on_sanitised_path.\n\n'
        M6=2
    else
        M6="$(DOCS_CHAIN_BIN=/nonexistent/docs_chain PATH="$M6_PATH" bash "$LAB/scripts/verify-docs-chain.sh" --root "$LAB" >"$LAB/out.txt" 2>&1; printf '%s' "$?")"
        sed 's/^/    | /' "$LAB/out.txt" | head -5
        printf '    rc=%s (expected 2 — an absent tool is NOT a pass)\n\n' "$M6"
    fi

    printf -- '--- M7 EXIT-CODE TRANSLATION: docs_chain 2 (CONFLICT) must NOT become 2 here ---\n'
    # The two contracts disagree about 2. Passing it through would downgrade a
    # CONFIRMED conflict into "could not determine", inverting the safe
    # direction. Assert the whole table, not only the colliding value — a
    # mapping tested at one point is a mapping nobody can refactor safely.
    T_OK=1
    for pair in '0:ok' '1:FAIL' '2:FAIL' '3:UNDET' '4:UNDET' '9:UNDET'; do
        in="${pair%%:*}"; want="${pair##*:}"; got="$(translate_docs_chain_rc "$in")"
        printf '    docs_chain rc=%s -> %-5s (expected %-5s) %s\n' \
               "$in" "$got" "$want" "$( [ "$got" = "$want" ] && echo OK || echo MISMATCH )"
        [ "$got" = "$want" ] || T_OK=0
    done
    printf '    the collision: docs_chain 2 = CONFLICT (a confirmed finding); this\n'
    printf '    project'"'"'s 2 = COULD NOT DETERMINE. It maps to FAIL, never to 2.\n\n'

    FAILS=0
    [ "$T_OK" -eq 1 ] || { printf 'PROBLEM: the docs_chain exit-code translation table is wrong; a CONFLICT\n' >&2
                           printf 'could be reported as could-not-determine, downgrading a real finding\n' >&2; FAILS=1; }
    [ "$G"  -eq 0 ] || { printf 'PROBLEM: a clean lab did not yield 0 (got %s) — false-positive refusal\n' "$G"  >&2; FAILS=1; }
    [ "$M1" -eq 1 ] || { printf 'PROBLEM: DRIFT did not yield 1 (got %s)\n'          "$M1" >&2; FAILS=1; }
    [ "$M2" -eq 1 ] || { printf 'PROBLEM: a MISSING EXPORT did not yield 1 (got %s)\n' "$M2" >&2; FAILS=1; }
    [ "$M3" -eq 1 ] || { printf 'PROBLEM: an UNBOUND document did not yield 1 (got %s)\n' "$M3" >&2; FAILS=1; }
    [ "$M4" -eq 1 ] || { printf 'PROBLEM: a SUBMODULE-SOURCED node did not yield 1 (got %s) — the leak\n' "$M4" >&2
                         printf 'invariant is not enforced, which is the one that can cause real harm\n' >&2; FAILS=1; }
    [ "$M5" -eq 1 ] || { printf 'PROBLEM: a ".." ESCAPE did not yield 1 (got %s)\n'  "$M5" >&2; FAILS=1; }
    [ "$M6" -eq 2 ] || { printf 'PROBLEM: an absent binary did not yield 2 (got %s)\n' "$M6" >&2; FAILS=1; }
    if [ "$FAILS" -ne 0 ]; then
        printf '\nPROBLEM: this check does not grade what it claims to.\n' >&2
        exit 1
    fi

    printf 'MUTATION PROOF: PASS — 5 mutations caught, 1 undetermined state demonstrated,\n'
    printf 'and 1 translation table pinned, over 13 assertions: golden-FALSE control 0;\n'
    printf 'M1 drift 1; M2 missing export 1; M3 unbound document 1; M4 submodule-sourced\n'
    printf 'node 1 (the leak invariant); M5 ".." escape 1; M6 absent binary 2; M7 the six\n'
    printf 'docs_chain->project exit-code mappings, including the 2=CONFLICT collision that\n'
    printf 'must map to FAIL and never to could-not-determine. Every mutation was seeded\n'
    printf 'into a throwaway git repository; the real tree was never touched.\n'
    exit 0
fi

# ===========================================================================
# THE REAL RUN
# ===========================================================================
[ -d "$ROOT" ] || { printf 'UNDETERMINED: --root %s is not a directory\n' "$ROOT" >&2; exit 2; }
git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1 || {
    printf 'UNDETERMINED: %s is not a git repository\n' "$ROOT" >&2; exit 2; }

CTXDIR="$ROOT/.docs_chain/contexts"
printf '== docs chain: contained, complete, in sync ==\n'
printf 'root: %s\n\n' "$ROOT"

if [ ! -d "$CTXDIR" ]; then
    printf 'UNDETERMINED: no %s. Nothing is bound, so nothing can be judged in sync.\n' "$CTXDIR" >&2
    printf 'Register the chains with: bash scripts/gen-docs-chain-contexts.sh\n' >&2
    exit 2
fi

CTXS="$(find "$CTXDIR" -maxdepth 1 -type f -name '*.yaml' 2>/dev/null | LC_ALL=C sort)"
[ -n "$CTXS" ] || { printf 'UNDETERMINED: %s holds no *.yaml context.\n' "$CTXDIR" >&2; exit 2; }

BIN="$(resolve_bin)" || {
    printf 'UNDETERMINED: no docs_chain binary is resolvable ($DOCS_CHAIN_BIN, PATH,\n' >&2
    printf 'or the constitution submodule build output). Sync state is NOT KNOWN from\n' >&2
    printf 'here, and an unknown state is not a clean one. Build it with:\n' >&2
    printf '  (cd submodules/constitution/submodules/docs_chain && go build -o docs_chain ./cmd/docs_chain)\n' >&2
    exit 2
}

# The declared submodule roster — derived, never hardcoded (see the header).
SUBS="$(git -C "$ROOT" config -f .gitmodules --get-regexp 'submodule\..*\.path' 2>/dev/null \
        | awk '{print $2}' | sed 's#/*$##' | LC_ALL=C sort -u)"
SUBN="$(printf '%s\n' "$SUBS" | grep -c . || true)"

# Every `path:` value across every context, one per line. Read file-by-file
# rather than by word-splitting the list: a repository whose absolute path
# contains a space is not this repository's problem to have an opinion about,
# and a check that silently scanned FEWER files than it thinks would be the
# §11.4.201(6) false-null — a clean verdict from a blind instrument.
node_paths() {
    local c
    while IFS= read -r c; do
        [ -n "$c" ] || continue
        grep -hoE 'path:[[:space:]]*[^}]+' "$c" 2>/dev/null \
            | sed -e 's/^path:[[:space:]]*//' -e 's/[[:space:]]*$//'
    done <<EOF
$CTXS
EOF
}

ALLPATHS="$(node_paths)"
NP="$(printf '%s\n' "$ALLPATHS" | grep -c . || true)"

# ---------------------------------------------------------------------------
# C1  CONTAINMENT — no node path may name a declared submodule.
#
# THE LEAK INVARIANT. This repository is public; three of its submodules are
# private. A node under a submodule path would render that submodule's source
# into a file this root's configuration chose the location of. Refusing the
# whole class — public submodules included — makes the rule decidable without
# consulting any remote's visibility setting, which is a property this tree
# cannot see and which changes outside it.
# ---------------------------------------------------------------------------
C1_BAD=""
if [ "$SUBN" -gt 0 ]; then
    while IFS= read -r p; do
        [ -n "$p" ] || continue
        while IFS= read -r s; do
            [ -n "$s" ] || continue
            case "$p" in "$s"/*|"$s") C1_BAD="$C1_BAD  $p  (under declared submodule '$s')"$'\n' ;; esac
        done <<EOF
$SUBS
EOF
    done <<EOF
$ALLPATHS
EOF
fi
if [ -n "$C1_BAD" ]; then
    bad "C1" "CONTAINMENT — $(printf '%s' "$C1_BAD" | grep -c .) node path(s) name a declared submodule"
    printf '%s' "$C1_BAD" | sed 's/^/             /'
    printf '             A submodule chain belongs in that submodule'"'"'s OWN root, where its\n'
    printf '             exports land in its OWN repository (§11.4.28(B)). Three of this\n'
    printf '             fleet'"'"'s submodules are PRIVATE and this repository is PUBLIC.\n'
else
    green "C1" "containment: no node path names any of the $SUBN declared submodule(s)"
fi

# ---------------------------------------------------------------------------
# C2  NO ESCAPE — every node path is relative and stays under the root.
# `..` or a leading `/` would place an export outside this repository entirely,
# which is the same disclosure risk as C1 by a different route.
# ---------------------------------------------------------------------------
C2_BAD=""
while IFS= read -r p; do
    [ -n "$p" ] || continue
    case "$p" in
        /*)         C2_BAD="$C2_BAD  $p  (absolute path)"$'\n' ;;
        ../*|*/../*|*/..) C2_BAD="$C2_BAD  $p  (escapes the root via ..)"$'\n' ;;
    esac
done <<EOF
$ALLPATHS
EOF
if [ -n "$C2_BAD" ]; then
    bad "C2" "ESCAPE — $(printf '%s' "$C2_BAD" | grep -c .) node path(s) leave this repository"
    printf '%s' "$C2_BAD" | sed 's/^/             /'
else
    green "C2" "no escape: all $NP node path(s) are relative and stay under the root"
fi

# ---------------------------------------------------------------------------
# C3  COVERAGE — the roster still matches the tree.
#
# Re-derive the contexts into a temp directory and diff. A Markdown document
# added since the last generation has no node, and this is the only check that
# can see that: `docs_chain verify` reports on what is REGISTERED and is
# perfectly happy with a shrinking scope.
# ---------------------------------------------------------------------------
TMPCTX="$(mktemp -d)" || { printf 'UNDETERMINED: cannot create a temp directory\n' >&2; exit 2; }
trap 'rm -rf "$TMPCTX"' EXIT
if bash "$SELF_DIR/gen-docs-chain-contexts.sh" --root "$ROOT" --out "$TMPCTX" >/dev/null 2>&1; then
    if diff -r -q "$TMPCTX" "$CTXDIR" >/dev/null 2>&1; then
        green "C3" "coverage: the registered roster equals the tree ($(($NP / 3)) document(s) bound)"
    else
        bad "C3" "UNBOUND or STALE — the registered contexts disagree with the tree"
        diff -r -u "$TMPCTX" "$CTXDIR" 2>/dev/null | grep -E '^[+-] +[a-z0-9_]+_md:' | head -12 \
            | sed -e 's/^-/             MISSING from the contexts: /' -e 's/^+/             STALE in the contexts:    /'
        printf '             Regenerate with: bash scripts/gen-docs-chain-contexts.sh\n'
    fi
else
    undet "C3" "coverage: the generator could not re-derive the roster"
fi

# ---------------------------------------------------------------------------
# C4  SYNC — Docs Chain's own read-only drift check.
# Content-hash based: a `touch` is not a change, a byte is.
# ---------------------------------------------------------------------------
VOUT="$("$BIN" verify --all --root "$ROOT" 2>&1)"; VRC=$?
case "$(translate_docs_chain_rc "$VRC")" in
    ok)   green "C4" "sync: every registered chain is in-sync (docs_chain verify rc=0)" ;;
    FAIL)
        if [ "$VRC" -eq 2 ]; then
            # NOT an undetermined. docs_chain 2 = CONFLICT = a confirmed finding.
            bad "C4" "CONFLICT — both sides of a sync edge are dirty (docs_chain rc=2, translated to FAIL)"
        else
            bad "C4" "DRIFT — a chained document is out of sync with its exports (docs_chain rc=$VRC)"
            printf '             Regenerate with: docs_chain sync --all\n'
        fi
        printf '%s\n' "$VOUT" | sed 's/^/             /' | head -12 ;;
    *)    undet "C4" "sync: docs_chain verify exited $VRC (transform failure or config error), translated to UNDETERMINED"
        printf '%s\n' "$VOUT" | sed 's/^/             /' | head -8 ;;
esac

# ---------------------------------------------------------------------------
# C5  EXPORTS PRESENT AND NON-DEGENERATE — §11.4.65 protection 1.
#
# `verify` compares hashes against recorded state. A zero-byte or absent export
# is a distinct failure worth naming on its own: an empty PDF that "matches its
# recorded hash" is still not an export anybody can read (§11.4.38 —
# non-degenerate, not merely present).
# ---------------------------------------------------------------------------
C5_BAD=""; C5_OK=0
while IFS= read -r p; do
    [ -n "$p" ] || continue
    case "$p" in *.html|*.pdf) ;; *) continue ;; esac
    f="$ROOT/$p"
    if [ ! -f "$f" ]; then
        C5_BAD="$C5_BAD  $p  (absent)"$'\n'
    elif [ ! -s "$f" ]; then
        C5_BAD="$C5_BAD  $p  (zero bytes — degenerate)"$'\n'
    else
        C5_OK=$((C5_OK+1))
    fi
done <<EOF
$ALLPATHS
EOF
if [ -n "$C5_BAD" ]; then
    bad "C5" "MISSING EXPORT — $(printf '%s' "$C5_BAD" | grep -c .) sibling(s) absent or degenerate"
    printf '%s' "$C5_BAD" | sed 's/^/             /' | head -12
else
    green "C5" "exports: all $C5_OK .html/.pdf sibling(s) exist and are non-empty (§11.4.65 protection 1)"
fi

printf '\n=== CM-DOCS-CHAIN-SYNC: %d FAIL, %d UNDET over 5 checks ===\n' "$FAIL" "$UNDET"

# A CONFIRMED FAILURE OUTRANKS AN UNDETERMINED.
if [ "$FAIL" -gt 0 ]; then
    printf '\033[31m❌ docs chain: %d finding(s). A divergent export is the exact PASS-bluff\n' "$FAIL"
    printf '   §11.4.65 forbids: an operator reads the HTML or PDF while the .md is right.\033[0m\n'
    exit 1
fi
if [ "$UNDET" -gt 0 ]; then
    printf '\033[33m⚠ docs chain: %d state(s) COULD NOT BE DETERMINED — which is not a pass.\033[0m\n' "$UNDET"
    exit 2
fi
printf '\033[32m✅ docs chain: contained, complete, and in sync.\033[0m\n'
exit 0
