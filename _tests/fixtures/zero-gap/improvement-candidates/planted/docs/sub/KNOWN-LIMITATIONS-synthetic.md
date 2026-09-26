# Known limitations - synthetic

## Limits

- The importer accepts only UTF-8 files.
- Concurrent writers are serialised by a single lock; target: p95 under 200 ms.
