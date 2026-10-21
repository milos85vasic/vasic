# Contract: Research Re-ingest Stage

**Implements**: FR-006..FR-010 | **Wrapper**: `workshop/scripts/ingest-research-docs.sh dry-run|stage|verify|selftest`
(as built; the first draft of this contract named it `ingest-research.sh --dry-run|--apply`, and the apply step
is now the GENERATED `<out>/apply.sh`, run by the orchestrator, because the stage never writes the live
registry) | **Filter**: `workshop/pipeline/research_redaction_filter.py` | **Measuring helper**:
`workshop/pipeline/research_reingest_prove.py`

## Exit contract *(three-valued; 2 is never a pass)*

| rc | Meaning |
|---|---|
| 0 | dry-run proved rows-only/idempotent, or the live merge completed and verified |
| 1 | a real problem: pre-existing row changed, count mismatch, content_type missing, second run not idempotent |
| 2 | could not determine: toolchain absent, redaction state unreadable, backup distinctness gate unavailable, tree not quiescent |

## Pipeline

```text
0. admission     bash scripts/agent-admit.sh --tag research-ingest -m 4G -T 1800 --verdict3 -- <step>
1. split         pipeline/venv/bin/python pipeline/md_sections.py <md> <sidecar> --chapter docs \
                   --path docs/research/<rel>.md --content-type authored_lesson --code-content-type code
                 (one per .md; poc/ .py/.ts/.epub/.txt files are NOT ingested — no splitter exists, spec.md Q3)
2. filter        pipeline/research_redaction_filter.py <sidecar>   # drops literal [REDACTED] rows; rc 2 if unclassifiable
3. dry-run       cp curriculum/passages.jsonl $SC/regcopy/passages.jsonl
                 platform/bin/ingest-transcript -dir $SC/regcopy -run $RUN -kinds doc_section,code \
                   -skip-suppressed -no-write-anchors -source-root $PWD -docs <sidecar> [-docs …]
4. prove         rows_after - rows_before == sum(sections_added); changed_existing_rows == 0 (per-line sha256);
                 re-run step 3 on the merged copy → new=0 changed=0
5. (orchestrator only) backup   real copy → .backups/passages.jsonl.pre-$RUN ; sha256 recorded BEFORE write
6. (orchestrator only) merge    same ingest against curriculum/ ; verify-backup-distinctness.sh
7. validate      registry-restamp-content-type -check ; row counts by kind/content_type unchanged except adds
8. evidence      workshop/evidence/018-$RUN/{reingest.json,result.json,manifest.sha256}
```

## Reconciliation with the as-built script *(review of S11)*

| Contract draft | As built |
|---|---|
| `ingest-research.sh --dry-run` (default) | `ingest-research-docs.sh dry-run` |
| `ingest-research.sh --apply` | `ingest-research-docs.sh stage` writes `<out>/apply.sh` + `apply-plan.json` (promoter invocations); `WORKSHOP_ORCH=1 bash <out>/apply.sh` applies; `ingest-research-docs.sh verify` re-measures and refuses a torn apply |
| (not stated) | `--out` is a destination: absent, empty, or a previous run's marked output; never a directory to empty |
| (not stated) | `selftest` proves the sandbox (empty netns, `/run` empty read-only tmpfs, io_uring seccomp) |
| rc 2 from the ingest binary | rc 2 (UNDETERMINED), not a finding |

## Hard guards

- **No model**: every tool runs under bwrap `--unshare-net` with `/run` and `/tmp` as empty tmpfs mounts and an
  io_uring seccomp filter, under `strace -f`; EVERY `connect()` of any family (filesystem and abstract AF_UNIX
  included) is counted, the single exemption being libc's failed nscd probe; `model_calls` in `reingest.json` is the
  measured count and MUST be 0. Residual risk, stated: a filesystem AF_UNIX socket on the host filesystem outside
  `/run` and `/tmp` is detected (the stage fails) rather than prevented.
- **No anchors**: `-no-write-anchors` always; a pre/post sha256 of every research `.md` MUST be equal.
- **Redaction**: exclusion happens before ingest; `-skip-suppressed` also set; evidence stores counts only.
- **Not corpus mode**: the wrapper never calls `scripts/ingest.sh`; a test greps the wrapper for that string.

## Evidence schema

`reingest.json` per data-model.md §5; `result.json` = `{check, expected, observed, rc}[]`; `manifest.sha256` = sha256
of every evidence file, written last.
