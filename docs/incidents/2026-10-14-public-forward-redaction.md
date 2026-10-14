# Public forward redaction, 2026-10-14

| Field | Value |
|---|---|
| Date | 2026-10-14 |
| Scope | Public umbrella repository, tracked files only |
| Decision | Operator, 2026-10-14: forward-redact now |
| Status | Working tree redacted; history unchanged |

## What was measured

A run-time probe (derived on the fly from the private chapter material; the probe
strings are never written to any tracked file) found two classes of private
identifier in tracked, already-pushed files:

- A source-notes filename in **2** spec files (`specs/009-meeting-notes-pdf-source/`: `quickstart.md`, `tasks.md`).
- Archive/video checksums in **4** files (`docs/workshop-curriculum/RECON.{md,html}`,
  `specs/001-workshop-curriculum-platform/research/transcription.{md,html}`), 3 matches across the `.md` files, mirrored in the `.html` exports.

## What was done

Each exposed string was replaced by a neutral placeholder
(`<source notes file (name withheld)>`, `<checksum withheld>`). Surrounding
documentation meaning is preserved. Probe hits across all tracked umbrella files:
6 files before, 0 after.

## What was NOT done

- History still contains the strings and cannot be rewritten (section 11.4.113).
  Forward edits contain the working tree only; this is containment, not remedy.
- Participant given names used as account handles (26 tracked files) were not
  edited in the first pass; listed for the operator. **Superseded the same day by
  the second pass below** (operator decision 2026-10-14: forward-redact now).
- Untracked and ignored documents are out of scope.

## Second pass: participant account handle (2026-10-14)

Operator decision (2026-10-14): forward-redact now, working tree only, history
unchanged. The probe token is derived from the private chapter material at run
time and is never written to any file. Matching is case-insensitive and bounded
by non-letters, so the token inside longer words is not touched.

| Measure | Before | After |
|---|---:|---:|
| Tracked files with a bounded match | 27 | 1 |
| Bounded matches | 118 | 1 |

The one remaining file is `_content_zh/products/Server-Factory-Additional-Components.pdf`:
the match falls inside compressed binary stream bytes (not text), so it is a
false positive and the file was not edited.

Replacements: `<participant-handle>` in prose, SQL, JSON and paths;
`PARTICIPANT_HANDLE` where the token was upper case inside an identifier (an
environment-variable name, a shell variable); a fixed-width form in one ASCII
diagram so its box alignment is kept. 26 files changed:

- 25 text files: `CONTINUATION.md`, `helix-deps.yaml`, `docs/qa/workshop-qa-access.md`,
  `docs/zero-gap/operator-queue-T086.md`, three files each under
  `docs/superpowers/plans/`, `docs/superpowers/research/`, and two under
  `docs/superpowers/specs/`; under `specs/007-decouple-modules-auth/`:
  `contracts/auth-api.md`, `data-model.md`, `docs/architecture/module-boundaries.md`,
  `docs/sql/auth-schema.sql`, `docs/sql/progress-schema.sql`, `plan.md`,
  `progress.yml`, `quickstart.md`, `spec.md`, `tasks.md`;
  `specs/008-unified-workshop-platform/{spec,tasks}.md`;
  `specs/012-document-ingestion-textbooks/spec.md`.
- `docs/workable_items.db`: 2 rows (VSC-397 in `items`, 4 text columns; its
  `operator_block_details` row), updated through SQL so the database stays
  consistent (`PRAGMA integrity_check` ok, row counts unchanged).

No tracked gate, fixture or test referenced the handle, so no gate expectations
changed. The real accounts inside the private submodules were not touched; the
redaction is documentation-only on the public side.

## Method

A throwaway script under the agent scratch directory loads the probe strings from
private material, searches every `git ls-files` entry case-insensitively
(plain, underscore, `%20` and hyphen variants of filenames; hex digests), and
prints counts per file only. No tracked script embeds the strings.
