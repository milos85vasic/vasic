# authkit

A shared authentication/authorization primitive library for Go, built to be
imported by two separate application backends (`workshop` and
`ai_interviewing`) that each wire it into their own HTTP servers and each
open their own copy of the store.

Module path: `github.com/vasic-digital/authkit`. Go 1.26.2. Pure-Go SQLite
(`modernc.org/sqlite`) — no cgo.

This module was built as a normal local Go module at
`submodules/authkit` inside the `vasic` umbrella repository. It is **not**
itself a published module or a registered git submodule yet — publishing it
as a standalone repository and registering the gitlink is a separate,
operator-authorized step (see the umbrella `CLAUDE.md` "Owned submodules"
section for the pattern this follows, mirroring `submodules/passage` and
`submodules/verdict`).

## Packages

| Package | Purpose | Tasks covered |
|---|---|---|
| `pkg/store` | Schema + migrations, `Open`/`Close`, user/role/permission CRUD | T488 |
| `pkg/password` | Argon2id password hashing | T502 |
| `pkg/rbac` | `(user, module, resource, action)` permission decisions | T511, T507, T579 |
| `pkg/session` | Session lifecycle + audience-scoped tokens | T505, T506, T507 |
| `pkg/ratelimit` | Per-key sliding-window rate limiting | T508 |
| `pkg/authresponse` | Generic, non-enumerating login-failure response | T509 |

## Schema

One SQLite database, six tables (`pkg/store/migrations.go`):

```
ak_user        id, username (unique), password_hash, created_at
ak_role        id, name (unique)
ak_user_role   user_id, role_id            -- many-to-many role membership
ak_permission  id, subject_type ('role'|'user'), subject_id, module, resource, action
ak_session     id (random), user_id, created_at, revoked_at
ak_cutover     id=1, min_valid_issued_at   -- global "invalidate everything before" cutover
```

`ak_permission` is the extensibility-critical table (T579). `subject_type` +
`subject_id` together are what the task calls "role_id_or_user_id": a grant
can apply to every member of a role, or to one specific account directly.
There is no compiled-in roster anywhere in this module — `pkg/rbac.Engine`
reads this table fresh on every `Allowed` call, so granting a brand-new
`(module, resource, action)` tuple to a brand-new subject is a single
`INSERT`, with **zero** code changes, and it takes effect immediately. See
`pkg/rbac/rbac_test.go`'s `TestAllowed_T579_DataDrivenNotHardcoded`, which
proves this by adding a third tuple as pure data and contrasting the real
engine (reacts) against a hardcoded two-branch stand-in (does not).

There is no plaintext or reversibly-encrypted password column anywhere —
`ak_user.password_hash` only ever holds an Argon2id-encoded string from
`pkg/password.Hash`.

## Password hashing

`pkg/password` uses Argon2id (`golang.org/x/crypto/argon2`), OWASP's current
first recommendation for password storage, ahead of bcrypt, because it was
purpose-built to resist the custom ASIC/GPU attacks bcrypt predates. Default
cost parameters follow OWASP's 2024 Password Storage Cheat Sheet
resource-constrained-server row: memory 19 MiB, 2 iterations, 1 thread, a
16-byte random salt per hash, 32-byte output. The parameters are encoded
into the stored string itself (`$argon2id$v=19$m=...,t=...,p=...$salt$key`),
so a future cost bump never breaks verification of already-stored hashes.

```go
hash, err := password.Hash(plaintext)
ok, err := password.Verify(plaintext, hash)
```

## RBAC engine

```go
engine := rbac.New(store.DB())
allowed, err := engine.Allowed(ctx, userID, "workshop", "chapters", "read")
```

Default-deny: a user with no matching role grant and no direct grant gets
`(false, nil)` — never an implicit allow, never an error standing in for a
decision (T511). Any database error is `(false, err)` — this method never
returns `true` unless it positively read a matching row (T507).

## Sessions and audience-scoped tokens

```go
mgr, err := session.NewManager(store.DB(), sharedSecret) // sharedSecret: >= 32 bytes, same value in every module

sid, err  := mgr.Login(ctx, userID)          // ALWAYS a fresh random id (T505)
token, err := mgr.Mint(sid, "workshop")       // audience = the minting module's name (T506)
claims, err := mgr.Validate(ctx, token, "workshop") // rejects a mismatched audience

err = mgr.Invalidate(ctx, sid)                          // single-session logout
err = mgr.InvalidateAllBefore(ctx, cutoverTime)          // mass invalidation (T512-style cutover)
```

**Session fixation (T505).** `Login` takes only a `userID` — there is no
parameter through which a pre-authentication session id could flow into the
authenticated session. Every call mints a fresh, `crypto/rand`-sourced id;
nothing is ever renewed or extended in place.

**Audience scoping (T506).** A token is `base64url(JSON{sub,aud,iat}) "."
base64url(HMAC-SHA256(...))`. Two modules that both read the same
`ak_user`/`ak_session` rows still cannot accept each other's tokens: the
audience claim is part of the signed payload, and `Validate` rejects a
mismatch before it even queries the database.

Token design choice: a small hand-rolled HMAC-SHA256 scheme rather than a
JWT library. The format is JWT-shaped (`payload.signature`, base64url,
HMAC-signed) but intentionally minimal — no algorithm-confusion surface, no
header to parse, and one fewer dependency for two applications that only
need to trust each other, not a third party's token format.

**Fail-closed (T507).** `Validate`'s two database checks — is the session
revoked, has a global cutover been set — return the query error unchanged
on any database failure, with a zero `Claims`. A token is never accepted on
the strength of a failed check.

## Rate limiting

```go
limiter := ratelimit.New(5, time.Minute) // 5 attempts per rolling minute, per key
if !limiter.Allow(usernameKey) { /* deny */ }
if !limiter.Allow(sourceIPKey) { /* deny */ }
```

A real sliding-window limiter (prunes expired hits and counts what remains
on every call) — not a counter that always returns `true`. Call it once per
key you want to throttle independently; per-account and per-source
throttling (T508) are both just "a key" to this package.

## Generic auth failure (T509)

```go
status, body := authresponse.LoginFailure()
```

Takes no argument describing why authentication failed. Both call sites — a
handler's "no such user" branch and its "wrong password" branch — call the
exact same function with the exact same signature, so their responses are
byte-identical by construction, not by convention two handlers have to
remember to follow.

## Wiring this into a consuming module

```go
st, err := store.Open("authkit.db")
if err != nil { /* ... */ }
defer st.Close()

// One-time setup (idempotent — INSERT OR IGNORE under the hood):
st.EnsureRole("admin")
st.EnsureRole("user")
st.GrantRolePermission("admin", "workshop", "all", "read")
// ...

engine := rbac.New(st.DB())
sessions, err := session.NewManager(st.DB(), sharedSecret)
limiter := ratelimit.New(5, time.Minute)

// On a login request:
if !limiter.Allow("account:"+username) || !limiter.Allow("source:"+clientIP) {
    http.Error(w, "too many attempts", http.StatusTooManyRequests)
    return
}
userID, hash, err := st.UserByUsername(username)
if err != nil { // unknown user OR any other lookup failure
    status, body := authresponse.LoginFailure()
    // write status/body — do this on invalid-password below too, unchanged
    return
}
ok, err := password.Verify(suppliedPassword, hash)
if err != nil || !ok {
    status, body := authresponse.LoginFailure() // identical to the branch above
    return
}
sid, err := sessions.Login(r.Context(), userID)
token, err := sessions.Mint(sid, "workshop") // this module's own name as audience

// On every protected request:
claims, err := sessions.Validate(r.Context(), token, "workshop")
if err != nil { /* 401 */ }
allowed, err := engine.Allowed(r.Context(), claims.SessionID /* -> resolve to userID */, "workshop", resource, action)
if err != nil || !allowed { /* 403 */ }
```

## Testing

Every package has real `*_test.go` coverage, including an explicit
control-vs-mutation pair per security property (see each package's test file
for the paired-mutation proof: `pkg/password`, `pkg/rbac` (T579),
`pkg/session` (T505 fixation), `pkg/ratelimit`, `pkg/authresponse`; `pkg/rbac`
and `pkg/session` additionally carry a real fail-closed test that closes the
underlying database mid-test).

```
go build ./...
go vet ./...
go test -count=1 ./...
```
