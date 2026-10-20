# Data Model: UX Research Wave

**Feature**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)

Client-side models only (TypeScript, new files). No backend table or endpoint is added by this spec.
Existing models read: `Answer`/`normaliseAnswer` (`core/api.ts`, `core/models.ts`), `LoadStatus`
(`core/load-status.ts`), rail model (`core/rail.component.ts`).

## AskStreamEvent (from the server, `pkg/answer/provider.go:120-137`)

`{kind, phase?, elapsed_s, tokens?, tokens_per_second?, delta?, verified, note?, outcome?}` plus the
`withheld` body. Parsed, never trusted blindly: unknown kinds are counted and ignored.

## StageRecord / AskStreamState

| Field | Type | Notes |
|---|---|---|
| `stages` | `StageRecord[]` | `{phase, started_at_s, ended_at_s?, note?}` in arrival order |
| `status` | `connecting`\|`streaming`\|`done`\|`dropped`\|`failed` | closed set; one UI sentence each |
| `draft` | `{text, verified:false}`? | only with opt-in; removed on result/withheld |
| `jobId` | string? | for the single reconnect |
| `unknownEvents` | number | diagnostics only |
| `outcome` | normalised `Answer`? | terminal |

## ConfidenceRecord (session store)

`{questionId, confidence: 'low'|'medium'|'high', selfExplanation: string (<=500), committedAt}` keyed by
`areaSlug + questionId`; cleared on sign-out. See `contracts/practice-confidence-fields.md`.

## MomentLink

`{pid: string (ULID), t?: number seconds >=0}` <-> URL. Grammar kept: `/chapters/<slug>[/transcript][?t=][&end=][#p-<pid>]`
(spec 004 `research.md:137`); `/passage/:pid` unchanged. Added (only if router tests prove no collision):
`?pid=<ULID>&t=<s>` on the transcript route, resolved after pid lookup.

## PaletteItem

`{id, kind: 'chapter'|'area'|'passage'|'command', label, secondary?, target: RouterLink|Action}`.
Sources: existing `/api/search`/`/api/suggest` results (no new endpoint), the static route list, a
small command registry (`core/palette-commands.ts`). Closed `kind` vocabulary shown as text labels.

## PeekModel

`{pid, excerpt (<=280 chars plain text), source label, state: 'ready'|'loading'|'withheld'|'absent'}`.
`withheld` mirrors the 410 branch (`features/passage/passage.component.ts:177,258`).

## RailRelevance

`{queryId, buckets: number[] (0..1 per rail bucket), total_hits}`; derived from the existing search
result set grouped by rail bucket (client-side); absent when no query is active. The rail keeps its
original layers and gains a mode flag `layer: 'uncertainty' | 'relevance'`.

## UxFlags (`core/ux-flags.ts`)

`{askStream, practiceConfidence, comfort, mediaSession, momentLinks, palette, peek, railRelevance}`:
booleans, default false; sources in precedence order: localStorage override (per-viewer convenience,
wrapped in try/catch), then a build-time default constant that the orchestrator flips after the story's
live acceptance (FR-020).
