# Contract: ResponseSource — what this feature requires from spec 013

This feature reads, never writes, spec 013's response log. It needs one narrow, read-only seam, defined here so
013's owner can provide it (or confirm an equivalent exists) without 021 reaching into 013's package internals.

```go
// platform/backend/pkg/medium/source.go  (interface owned by 021; implemented by an adapter in
// cmd/workshop-server/wire_medium.go over pkg/scoring.Store — a NEW file in 013's package is permitted:
// pkg/scoring/read_responses.go, sequenced after 013 US1 merges)
type ResponseSource interface {
    // Newest-first rows for ONE session, at most limit. truncated=true when more existed.
    ResponsesForSession(ctx context.Context, session string, limit int) (rows []ResponseRow, truncated bool, err error)
}

type ResponseRow struct {
    EntryID          string
    Area             string
    QuestionID       string
    At               time.Time
    Correct          bool
    GradedBy         string  // "machine" | "self_reported" | "ungraded"   <-- see Open Item 1
    ServedDifficulty float64
    AbilityBefore    float64
}

type QuestionKindLookup func(questionID string) (assessment.Kind, bool)
```

## Open items for spec 013 (each is a task in tasks.md, BLOCKED until 013 US1 lands)

1. **`GradedBy` provenance.** 013's `ResponseLogEntry` (data-model §1.1) carries `correct` but, as drafted, no
   field distinguishing a machine-graded outcome from an ungraded or self-reported one. For `short` the
   curriculum-kit marker sets `Graded=false`, and what 013 writes for `correct` in that case is UNCONFIRMED.
   If 013 records `correct=false` for an ungraded short answer, medium statistics would count every short answer as
   a failure — a silent, systematic bias. The adapter MUST derive `GradedBy` from the question kind and the
   grading path (graded path: `QuestionOutcome.Graded`), and the reader MUST drop ungraded rows from performance
   evidence. T004/T028 verify against the real implementation. If 013 cannot supply provenance without a schema
   change, the request goes to 013's owner as an additive column (013 FR-015 anticipates additive needs).
2. **Question-kind lookup.** `ResponseLogEntry` stores `question_id`, not kind. The adapter resolves kind from the
   assessment bank (`pkg/assessment` store) at read time; unknown ids are counted as `unmapped`, not guessed.
3. **Read cost.** `response_log_question`/session indexes exist (013 DDL §5); a session-scoped newest-first read
   needs `(session, at)`; if absent, the additive index is part of the 013 request.
4. **Isolation.** The adapter MUST filter by session in SQL, not post-hoc in Go (a SQL filter cannot leak a row
   by a later refactor; a Go filter can).

## Failure semantics

`err != nil` ⇒ handler answers `503 unavailable` with code `scoring_store_unreadable`; `source == nil` ⇒
`scoring_store_absent`. Neither is ever mapped to "zero observations".
