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
- **Creation**: the file is created (mode 0600) when the hosted provider is BUILT - the construction-time
  probe opens it with create - so a permission fault is found at boot, not on the first request
  (amended 2026-10-20, H1: the earlier "on first write" wording did not match the implementation).
  An existing file that is group/other accessible is refused. It is never
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

**Amended 2026-10-20 (stream S1 review fixes) - WRITE-AHEAD.** A generation attempt
that sends prompt text writes TWO lines sharing one `id`: first an INTENT line with
`outcome: "attempt_started"` (appended and fsynced BEFORE the text is sent; if it cannot
be written the attempt is refused and nothing is sent), then the FINAL line with the real
outcome and `duration_ms` (if it cannot be written the result is discarded; the intent
line remains). Attempts that fail while the provider is being built (`credential_missing`,
`health_check_failed`) send no text and are a single line. The `outcome` vocabulary is
therefore SEVEN values: `attempt_started`, `success`, `health_check_failed`,
`credential_missing`, `upstream_error`, `cancelled`, `schema_violation`. A reader pairs
lines by `id`; an id with only `attempt_started` means "text may have left, outcome unknown".
`endpoint` is recorded as `scheme://host[:port]` only (no userinfo, path, parameters, query or
fragment); when no endpoint was configured it is the host of the vendor adapter's
`LLMPROVIDER_<KEY>_BASE_URL` override the row's adapter really reads (`<KEY>` = row name, except `zen` -> `ZEN_API`), else `vendor-default`. The file is created mode 0600,
is opened without following symlinks and must be a regular file. A record is ONE write call; a
short write is a failure and is NOT rolled back (a truncate could delete another process's
record), so a torn line is possible and readers MUST tolerate one. A hosted provider is not
built at all when no audit log is configured.

**Postconditions**:

- Exactly one line is appended to the file in one write call, or the call returns a non-nil
  `error`. (Superseded 2026-10-20: the earlier "zero lines ... no partial-line writes" wording
  assumed a truncate-rollback that the review rejected; see the amendment above.)
- The write is synchronous with the generation attempt it records (called
  from the same goroutine, before the caller's `Generate`/`newHostedProvider`
  returns to ITS caller) — so "the audit record exists" and "the generation
  attempt concluded" are never observably out of order from a reader's
  perspective, even though this feature does not implement Story 4's
  concurrency model.

**Failure handling - DECIDED (fail closed; amended 2026-10-20, H1)**:

The earlier text here left fail-open vs fail-closed as `NEEDS CLARIFICATION`. The implementation FAILS CLOSED
(section 2 WRITE-AHEAD above; code comment in `pkg/answer/audit.go` names this section): an intent line that cannot be
written refuses the attempt, a final line that cannot be written discards the result. This is an unreviewed
default pending operator confirmation, not a ruled decision, and it is never a silent fail-open. Further
amendments (H1): every audit write is bounded by the request deadline plus a 15 s cap (a stalled disk refuses the
attempt rather than holding it); each record is read back after it is written and an fsync error of any kind fails
the write; pseudo file systems (procfs, sysfs, cgroup, ...) are refused; operator-supplied strings are truncated
on write (model 256, endpoint 256, session 128, provider 64 bytes; a cut field ends `...[truncated]`) so a line is
at most 4 KiB; the `id` is `rg_<ts>_<16 hex digits>` (64 random bits); one record is one `Generate` call, so
`content_bytes` is the size of ONE send even if the vendor adapter re-sends the prompt internally (retries are not
visible to this package and are not counted).

## 3. Read contract

No HTTP endpoint is added by this feature. The file is a directly operator-
readable artifact:

Each generation is TWO lines (intent + final, same `id`); count and filter by pairing on `id`, and tolerate a
torn line (a plain `jq -c .` stops at the first one). The supported readers are `answer.ReadAuditRecords` and
`go run ./platform/backend/cmd/answer-audit-report [-json] <file>`; the equivalent `jq` (see `docs/providers.md`
section 3) skips torn lines with `fromjson?`:

```bash
# One row per attempt, with its final outcome ("unconcluded" when only the intent line exists):
jq -R -s -c '[split("\n")[] | fromjson? | select(.id)] | group_by(.id)[]
             | {id: .[0].id, outcome: (map(select(.outcome != "attempt_started")) | .[0].outcome // "unconcluded")}' \
   curriculum/remote-generations.jsonl

# Number of ATTEMPTS (not lines), to spot-check SC-003's one-record-per-attempt claim:
jq -R -s '[split("\n")[] | fromjson? | select(.id) | .id] | unique | length' curriculum/remote-generations.jsonl
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
