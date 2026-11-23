# Proposal: update the host-wide user-scope governance INDEX (not applied)

| Field | Value |
|---|---|
| Revision | 1 |
| Date | 2026-11-24 |
| Targets | `/home/milosvasic/.claude/CLAUDE.md` (regular file), `/home/milosvasic/.claude-claude3/CLAUDE.md` (symlink to `~/.claude-shared/CLAUDE.md`) |
| Status | PROPOSAL ONLY. Nothing under `~` was edited. |

## Why a proposal and not an edit

The search for a sanctioned generator found none. Searched: `submodules/constitution/scripts/**` (gates, `anchors/`,
`install_constitution.sh`, `post_update_hook.sh`) and `~/.claude-shared`. Only the constitution's own
`constitution_index.yaml` / group generator exists (`cm_constitution_index_fresh`), and it does not write the user-scope
file. `post_update_hook.sh` writes skills, MCP configs, git hooks and the Jev bootstrap into the consuming project, never
`~/.claude*/CLAUDE.md`. Both user files are therefore hand-maintained, and editing them is the operator's call.

Both files end their anchor list at `11.4.288`. The pinned constitution (`6d93ccd1`) defines anchors through `11.4.298`.

## Lines to append to the fenced anchor index, after the `11.4.288` line

Titles are the block-heading prefix, truncated in the file's own style. Read each block before relying on it.

```
11.4.289 No stubs, mocks or fixture servers as evidence: all testing, va...
11.4.290 Optimistic done with parallel background verification: PROVISIO...
11.4.291 Capacity-aware decision-model placement: a local decision model...
11.4.292 Reproduce first: every issue being fixed is REPRODUCED LIVE bef...
11.4.293 Scope discipline and image no-worse proof: all work serves the
11.4.294 Reproduction and investigation states are workable-item fields:...
11.4.295 Substitute app, same verdict: when a content API is geo-restric...
11.4.296 GitHub Issues are a source of workable items: the issues assign...
11.4.297 Pull-request delivery: a project that declares it by a recorded...
11.4.298 Release gate per product: a deployable build is deployed or tag...
```

## Companion edits to the prose of both files

- In the "Gaps this index does not hide" paragraph, change `anchors through 11.4.288 (read from the scratch clone canon-v72, 2026-10-26 ...)` to `anchors through 11.4.298 (read from the pinned submodule 6d93ccd1, 2026-11-24 ...)`.
- Optionally add one binding line to "Read these before you touch anything": `13. Reproduce first, no stubs as evidence, scope discipline: 11.4.292, 11.4.289, 11.4.293.`
  (Optional; the index is meant to stay thin, §11.4.141(3).)
- `11.4.64`, `11.4.175`, `11.4.203`-`11.4.206` stay listed as cited-but-undefined; this proposal did not re-check them.

## Apply

The two files are one content (the `.claude-claude3` one is a symlink to `~/.claude-shared/CLAUDE.md`; the `.claude` one is
a separate regular file, 21891 bytes at the time of writing), so apply the same lines to both. Back them up first (§9).
