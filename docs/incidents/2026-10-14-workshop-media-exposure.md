# Workshop media exposure, 2026-10-14

| Field | Value |
|---|---|
| Date | 2026-10-14 |
| Scope | Private `workshop` submodule, `workshop-server` static routes |
| Status | Fixed in the private repository and redeployed to the local container |
| Detail | Private repository, `docs/incidents/2026-10-14-media-exposure.md` |

The workshop platform's static `/media/` route (a plain file server over the
private chapter tree) answered unauthenticated requests on the host: a chapter
directory request returned a directory listing and the source files under it
were served without a session. The cause was two layers composing into a bypass.
The file server rendered directory listings, and the per-user session check
covered `/api/*` only, while the network gate trusts every loopback caller (the
container is published on `127.0.0.1`). The fix retires `/media/` (HTTP 410 for
every caller, nothing is read from disk), requires a valid session on the static
`/docs/` route from every caller, loopback included, and disables directory
listings there. Failing tests were written first and confirmed RED, then GREEN.
A paired-mutation proof covers each guard, and the redeployed container was
checked with status codes only. No file name or content from the private tree
appears in this note. Still open: provenance fields in signed-in API responses
still carry source paths, and that is tracked in the private repository.
