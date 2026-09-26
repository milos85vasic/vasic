# Operator decisions - synthetic

Prose paragraph that mentions a limitation and a deferred item but is not a list line, so it is no candidate.

## Decisions

- Known limitation: the cache warmup takes 90 seconds on a cold start; improve it to under 30 seconds.
- Deferred improvement: the retry logic is not yet exponential.
- The gate exits 0 at 12 PASS and is registered.
| # | Item | Note |
|---|---|---|
| 1 | Report renderer | residual gap: renders 40% slower than the baseline on 1000 rows |
| 2 | Plain fact row | the export is complete |
- Deferred minor: shared lock file is never pruned; follow-up needed.
```
- a fenced line with a limitation that must be skipped
```
- Improvement: the audit walk misses symlinked directories.
- Deferred: cut the cold rebuild to 5 minutes; it must also stay below 9 minutes on CI.

| # | Known limitation | Target |
|---|---|---|
| 1 | The nightly export has no retry | none stated |
