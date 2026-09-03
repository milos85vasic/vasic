#!/usr/bin/env bash
# gen-docs-chain-contexts.sh — DERIVE this repository's Docs Chain contexts
# from the tree, so a Markdown document added tomorrow is bound tomorrow.
#
# ============================================================================
# WHY A GENERATOR AND NOT A HAND-WRITTEN YAML
# ============================================================================
#
# Docs Chain binds EXPLICIT node paths. Its schema has no glob for a `markdown`
# node — `members:` exists only for `kind: fingerprint` — so a hand-maintained
# context is a roster, and a roster is the artefact that silently stops
# matching reality. §11.4.65 mandates that EVERY in-scope Markdown document
# has synchronised `.html` + `.pdf` siblings; a roster satisfies that on the
# day it is written and quietly stops satisfying it on the day someone adds a
# document and does not remember this file exists.
#
# So the roster is DERIVED. This script emits the contexts from the tree, and
# `scripts/verify-docs-chain.sh` re-derives them into a temp directory and
# diffs — a new in-scope document with no node is a DIFF, which is a FAILURE,
# not an omission. That pairing is the whole anti-rot mechanism.
#
# ============================================================================
# THE SCOPE RULE, AND WHY IT STOPS AT THIS REPOSITORY'S OWN BOUNDARY
# ============================================================================
#
# This repository is PUBLIC. Three of its submodules — derived here, never
# hardcoded — are PRIVATE. Docs Chain node paths are project-root-relative, so
# a context at THIS root could name `<private-submodule>/docs/x.md` and emit
# `<private-submodule>/docs/x.html` … or, with one wrong path, emit that HTML
# somewhere public. An HTML export carries the FULL text of its source. One
# such mistake is a permanent, irreversible disclosure into a public git
# history.
#
# The defence is structural rather than careful: THE SCOPE NEVER LEAVES THIS
# REPOSITORY. Every path emitted here is a file this repository itself tracks.
# No submodule path — public or private — is ever named, so no misconfiguration
# of THIS generator can produce a public export of a private source. A
# submodule that wants its own chain registers it in ITS OWN root, where its
# exports land in ITS OWN repository by construction (§11.4.28(B): a submodule
# is project-not-aware and self-contained).
#
# The submodule roster is read from `.gitmodules` at run time. Nothing here is
# a hardcoded list of private repositories, because such a list is wrong the
# moment a submodule is added.
#
# ============================================================================
# THE FORMAT SET, AND ITS CITATION
# ============================================================================
#
# `.html` + `.pdf`, per constitution §11.4.65 (Universal Markdown export
# mandate): "Any markdown document inside the project and which is not part of
# the applications or services source code MUST BE exported (be available) in
# PDF and HTML!" — mandatory protection 1, "Every INCLUDED `.md` file has
# `.html` and `.pdf` siblings."
#
# DOCX is NOT in the §11.4.65 universal set. It is added by §11.4.153 for the
# per-feature Status document class ("this doc class ADDS DOCX to the §11.4.65
# universal HTML+PDF export set; the other doc classes are unchanged"), and
# this repository currently has no document of that class. When one lands, add
# a docx leg here for that class only — not for the whole tree.
#
# Usage:
#   bash scripts/gen-docs-chain-contexts.sh              # write to .docs_chain/contexts
#   bash scripts/gen-docs-chain-contexts.sh --out DIR    # write elsewhere (the verifier does this)
#   bash scripts/gen-docs-chain-contexts.sh --root DIR
#   bash scripts/gen-docs-chain-contexts.sh --list       # print the in-scope .md set, one per line
#
# Exit: 0 wrote/listed · 2 could not determine (no root, not a git repo)

set -uo pipefail

SELF_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd -- "$SELF_DIR/.." && pwd)"
OUT=""
LIST=0

while [ "$#" -gt 0 ]; do
    case "$1" in
        --out)     OUT="${2:-}"; shift 2 ;;
        --root)    ROOT="${2:-}"; shift 2 ;;
        --list)    LIST=1; shift ;;
        -h|--help) sed -n '1,74p' "${BASH_SOURCE[0]}"; exit 0 ;;
        *) printf 'UNDETERMINED: unknown argument %s\n' "$1" >&2; exit 2 ;;
    esac
done

[ -d "$ROOT" ] || { printf 'UNDETERMINED: --root %s is not a directory\n' "$ROOT" >&2; exit 2; }
git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1 || {
    printf 'UNDETERMINED: %s is not a git repository; the in-scope set is derived\n' "$ROOT" >&2
    printf 'from `git ls-files` and cannot be derived without one.\n' >&2
    exit 2
}
[ -n "$OUT" ] || OUT="$ROOT/.docs_chain/contexts"

# ---------------------------------------------------------------------------
# THE SUBMODULE ROSTER — derived, never hardcoded.
#
# Read from .gitmodules. Every declared path is excluded from the in-scope set
# regardless of whether the submodule is public or private: the rule is "this
# repository's own files only", which is decidable without knowing anything
# about a remote's visibility setting. A rule that needed to know which
# submodules are private would be wrong the moment a visibility flag changes
# outside this tree.
# ---------------------------------------------------------------------------
submodule_paths() {
    [ -f "$ROOT/.gitmodules" ] || return 0
    git -C "$ROOT" config -f .gitmodules --get-regexp 'submodule\..*\.path' 2>/dev/null \
        | awk '{print $2}' | sed 's#/*$##' | sort -u
}

# ---------------------------------------------------------------------------
# THE IN-SCOPE SET — §11.4.65's INCLUDED scope, mapped onto this repository.
#
#   project root *.md      -> README, CONTINUATION, the four carriers, Constitution.md
#   docs/**/*.md           -> guides, research, incident notes, procedures
#   specs/**/*.md          -> the SpecKit planning trees
#
# EXCLUDED, and each exclusion is a §11.4.65 EXCLUDED class rather than a
# convenience:
#
#   every declared submodule path   third-party or separately-governed; its
#                                   chain belongs in its own root (see header)
#   .claude/ .specify/ .ashlrcode/  vendored agent/plugin/extension trees we do
#                                   not own and do not govern
#   _tests/node_modules/ etc.       dependency trees
#
# THE ENUMERATOR IS `ls-files` UNION `ls-files --others --exclude-standard` —
# tracked files AND untracked-but-not-ignored ones.
#
# Tracked-only was the first shape and it left a real window. This project's
# commit wrapper runs `git add .`, so a document written today and committed
# tomorrow is untracked in between; a tracked-only enumerator does not see it,
# the roster does not grow, and the coverage check that is supposed to catch an
# unbound document reports a clean tree — the §11.4.201(6) false-null, where a
# blind instrument and a compliant tree return the same quiet zero. Measured
# during this file's own authoring: `docs/docs-chain.md` was written, and the
# tracked-only enumerator did not see it.
#
# `--exclude-standard` honours `.gitignore`, so genuinely ignored scratch stays
# out. What is left is exactly the set the commit wrapper will stage.
# ---------------------------------------------------------------------------
in_scope() {
    local subs pat
    subs="$(submodule_paths)"

    { git -C "$ROOT" ls-files -- '*.md' 2>/dev/null
      git -C "$ROOT" ls-files --others --exclude-standard -- '*.md' 2>/dev/null
    } | LC_ALL=C sort -u | while IFS= read -r f; do
        [ -n "$f" ] || continue

        case "$f" in
            .claude/*|.specify/*|.ashlrcode/*|.github/*|.gemini/*|.qwen/*) continue ;;
            */node_modules/*|node_modules/*|*/vendor/*|*/venv/*) continue ;;
        esac

        # Under a declared submodule path? (Gitlinks are one entry to
        # `ls-files`, so this is belt-and-braces — a submodule's inner files do
        # not normally appear here at all. It stays because "normally" is the
        # word that precedes an incident.)
        while IFS= read -r pat; do
            [ -n "$pat" ] || continue
            case "$f" in "$pat"/*|"$pat") continue 2 ;; esac
        done <<EOF
$subs
EOF

        case "$f" in
            docs/*.md|docs/*/*.md|docs/*/*/*.md|docs/*/*/*/*.md) printf '%s\n' "$f" ;;
            specs/*.md|specs/*/*.md|specs/*/*/*.md|specs/*/*/*/*.md) printf '%s\n' "$f" ;;
            */*) : ;;                       # any other nested tree: out of scope
            *.md) printf '%s\n' "$f" ;;     # depth-0 project root
        esac
    done | LC_ALL=C sort
}

if [ "$LIST" -eq 1 ]; then
    in_scope
    exit 0
fi

# A node id must be a stable, unique, YAML-safe key. Derive it from the path so
# that renaming a document renames its nodes, and two documents can never
# collide on one id.
nid() {
    printf '%s' "$1" | sed -e 's/\.md$//' -e 's/[^A-Za-z0-9]/_/g' | tr '[:upper:]' '[:lower:]'
}

emit_context() {
    local name="$1" desc="$2" files="$3" f id
    printf 'context: %s\n' "$name"
    printf 'description: %s\n' "$desc"
    printf '# GENERATED by scripts/gen-docs-chain-contexts.sh — do not hand-edit.\n'
    printf '# Regenerate after adding or removing an in-scope Markdown document;\n'
    printf '# scripts/verify-docs-chain.sh FAILS while this file and the tree disagree.\n'
    printf '# Format set: .html + .pdf per constitution §11.4.65.\n'
    printf 'nodes:\n'
    while IFS= read -r f; do
        [ -n "$f" ] || continue
        id="$(nid "$f")"
        printf '  %s_md:   { kind: markdown, path: %s }\n'   "$id" "$f"
        printf '  %s_html: { kind: html,     path: %s }\n'   "$id" "${f%.md}.html"
        printf '  %s_pdf:  { kind: pdf,      path: %s }\n'   "$id" "${f%.md}.pdf"
    done <<EOF
$files
EOF
    printf 'edges:\n'
    while IFS= read -r f; do
        [ -n "$f" ] || continue
        id="$(nid "$f")"
        # md -> html -> pdf, never md -> pdf directly: the PDF is rendered from
        # the SAME HTML a reader opens, so the two exports cannot drift into
        # different renderings of one source.
        printf '  - { type: derive-from, from: %s_md,   to: %s_html, transform: md2html }\n'  "$id" "$id"
        printf '  - { type: derive-from, from: %s_html, to: %s_pdf,  transform: html2pdf }\n' "$id" "$id"
    done <<EOF
$files
EOF
    printf 'transforms:\n'
    printf '  md2html:  { builtin: pandoc-html }\n'
    printf '  html2pdf: { builtin: weasyprint-pdf }\n'
}

ALL="$(in_scope)"
[ -n "$ALL" ] || { printf 'UNDETERMINED: the in-scope Markdown set is EMPTY. A generator that\n' >&2
                   printf 'enumerated nothing has not reported a clean tree; it has failed to run.\n' >&2
                   exit 2; }

ROOTMD="$(printf '%s\n' "$ALL" | grep -v '/' || true)"
DOCSMD="$(printf '%s\n' "$ALL" | grep '^docs/' || true)"
SPECSMD="$(printf '%s\n' "$ALL" | grep '^specs/' || true)"

mkdir -p "$OUT" || { printf 'UNDETERMINED: cannot create %s\n' "$OUT" >&2; exit 2; }

[ -n "$ROOTMD" ]  && emit_context umbrella-root  'Project-root Markdown (README, CONTINUATION, the four governance carriers) -> html + pdf (§11.4.65)' "$ROOTMD"  > "$OUT/umbrella-root.yaml"
[ -n "$DOCSMD" ]  && emit_context umbrella-docs  'docs/** guides, research, incident notes and procedures -> html + pdf (§11.4.65)'                    "$DOCSMD"  > "$OUT/umbrella-docs.yaml"
[ -n "$SPECSMD" ] && emit_context umbrella-specs 'specs/** SpecKit planning trees -> html + pdf (§11.4.65)'                                            "$SPECSMD" > "$OUT/umbrella-specs.yaml"

printf 'wrote contexts to %s\n' "$OUT"
printf '  umbrella-root   %s document(s)\n' "$(printf '%s\n' "$ROOTMD"  | grep -c . || true)"
printf '  umbrella-docs   %s document(s)\n' "$(printf '%s\n' "$DOCSMD"  | grep -c . || true)"
printf '  umbrella-specs  %s document(s)\n' "$(printf '%s\n' "$SPECSMD" | grep -c . || true)"
exit 0
