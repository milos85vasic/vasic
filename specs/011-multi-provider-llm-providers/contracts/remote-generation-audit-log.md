# Contract: Remote-Generation Audit Log

**Feature**: 011-multi-provider-llm-providers (User Story 2, FR-004/FR-005)

This is the one real external-facing interface this feature introduces:
a new artifact an operator reads, and a new flag that configures where it is
written. Everything else in this feature (the two new provider names, the
`lan` locality value) is reached through the existing `-answer-provider` /
`-answer-locality` surface and needs no separate contract.

## 1. File location and lifecycle

- **Path**: `<curriculum-dir>/remote-generations.jsonl`, derived the same way
  `redactionLogPath` in `cmd/workshop-server/redaction_log.go` derives
  `redactions.jsonl` — sibling of the registry file by default, overridable
  by an explicit flag.
- **New flag**: `-answer-audit-log <path>` / `$WORKSHOP_ANSWER_AUDIT_LOG`,
  added to `cmd/workshop-server/main.go` beside the existing
  `-redaction-log` flag (`main.go:~501-509` region, same flag-declaration
  block as `-answer-provider` itself).
- **Creation**: the file is created on first write if absent. It is never
  truncated, never rewritten, never reordered — append-only for the life of
  the deployment, exactly as `redactions.jsonl` is.
- **Absence is not an error at boot.** A deployment that has never enabled
  remote opt-in legitimately has no file yet. This mirrors
  `syncRedactionLog`'s own stated design: *"ABSENT IS NOT AN ERROR... A
  deployment with nothing ever redacted legitimately has no log."*

## 2. Write contract

**Function signature** (illustrative — exact Go signature is an
implementation-time decision, this fixes the *contract*, not the code):

```go
func writeAuditRecord(path string, rec RemoteGenerationAuditRecord) error
```

**Preconditions the caller (hosted.go) guarantees before calling**:

- `rec.Provider` is a non-empty catalogue row name.
- `rec.ContentBytes` is computed from the REQUEST TEXT LENGTH ONLY — the
  function receives an `int`, never the text itself. This is what makes FR-005's
  negative requirement structural rather than conventional: there is no
  parameter through which prompt/passage/answer text COULD reach the writer.

**Postconditions**:

- Exactly one line is appended to the file, or the call returns a non-nil
  `error` and **zero** lines are appended (no partial-line writes — the
  writer buffers the full JSON object before any `Write` call).
- The write is synchronous with the generation attempt it records (called
  from the same goroutine, before the caller's `Generate`/`newHostedProvider`
  returns to ITS caller) — so "the audit record exists" and "the generation
  attempt concluded" are never observably out of order from a reader's
  perspective, even though this feature does not implement Story 4's
  concurrency model.

**Failure handling — states the OPEN question rather than resolving it**:

Per spec.md's own Edge Case, whether a write failure here should fail the
generation attempt closed (§11.4.252's general posture) or allow it to
proceed with the failure logged through the general error path is
**explicitly `NEEDS CLARIFICATION`** and is not decided by this contract.
Implementation MUST pick one, mark the choice in a code comment naming this
section, and MUST NOT silently default to fail-open without that comment
being present — silently swallowing a write error would itself be a
§11.4.252 fail-open anti-pattern (`catch { /* ignore */ }`) regardless of
which side of the tradeoff the operator eventually prefers.

## 3. Read contract

No HTTP endpoint is added by this feature. The file is a directly operator-
readable artifact:

```bash
# Every remote-generation attempt this deployment has made:
jq -c . curriculum/remote-generations.jsonl

# Attempts that did NOT succeed:
jq -c 'select(.outcome != "success")' curriculum/remote-generations.jsonl

# Count of attempts vs. count of successes, to spot-check SC-003's
# one-record-per-attempt claim against a real test run:
jq -s 'length' curriculum/remote-generations.jsonl
```

**Schema stability**: every object carries exactly the nine fields listed in
`data-model.md` §4 (`id`, `ts`, `session_id`, `provider`, `model`, `endpoint`,
`content_bytes`, `outcome`, `duration_ms`). A future field MAY be added (readers MUST ignore unknown
fields, per the same append-tolerant convention `passage.RedactionLog`
already follows for its own JSONL shape); no field listed there is ever
removed or renamed without a version marker — none exists yet because this is
the schema's first version.

## 4. Non-goals of this contract

- **Not a queryable API.** Materialising this log into the served SQLite
  database (the way `redaction_log.go` materialises `redactions.jsonl` into a
  `redactions` table) is explicitly out of scope for this feature — nothing
  in FR-004/FR-005 requires the audit trail to be reachable over `/api/*`,
  only that it exist and be structured. A future feature may add that
  materialisation by following `redaction_log.go`'s own precedent.
- **Not a retention/rotation policy.** This feature does not specify log
  rotation, size caps, or archival. The existing `redactions.jsonl` has no
  such policy either; this audit log inherits the same silence rather than
  inventing a policy the sibling artifact does not have.
- **Not scoped to the two new rows.** Per FR-004, this applies to all 30
  hosted rows (28 existing + `openai` + `anthropic`) whenever remote opt-in
  is enabled — the write call site is inside the shared `HostedProvider` path
  (`hosted.go`), not duplicated per-row.
