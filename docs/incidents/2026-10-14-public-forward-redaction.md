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
  edited; listed for the operator, as the handle may be the owner's own username.
- Untracked and ignored documents are out of scope.

## Method

A throwaway script under the agent scratch directory loads the probe strings from
private material, searches every `git ls-files` entry case-insensitively
(plain, underscore, `%20` and hyphen variants of filenames; hex digests), and
prints counts per file only. No tracked script embeds the strings.
