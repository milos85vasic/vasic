# job_seeker research 03 - Go + Gin + HTTP/3 + Brotli stack reference

Date: 2026-11-24. Research only; nothing built or run for this document.
Evidence tags: READ = read from the file in this checkout; FETCHED = fetched 2026-11-24; UNCONFIRMED = not verified.

## 1. Reference implementation: ai_interviewing/platform/backend (READ)

- Module `github.com/milos85vasic/ai_interviewing/platform/backend`, `go 1.26.2` (toolchain on host: go1.26.8).
- Layout: `cmd/server`, `cmd/hashpw`, `internal/{api,auth,store,server,bootguard,buildinfo,ingest,testseed}`, `gates/` (shell + Go live-gate programs), `Containerfile`.
- Gin wiring (`internal/api/api.go`): `gin.SetMode(ReleaseMode)`, `gin.New()` (not `Default`), `gin.Recovery()`, security-headers middleware (`secheaders.go`: nosniff, X-Frame-Options DENY, CSP with hashed inline scripts, HSTS only over TLS to a real DNS name). `Router()` returns a `*gin.Engine`, which is an `http.Handler`.
- HTTP/3 (`internal/server/server.go`): the Gin handler is wrapped as `http.Handler`, then served three ways: plain HTTP/1.1 on `-http`, HTTPS (h2 via ALPN) with `http.Server.ServeTLS` on TCP, and `http3.Server{Handler, TLSConfig}.Serve(udpConn)` on UDP **bound to the same port number as the TCP TLS listener** (`listenTLSPair`). Alt-Svc is set by a tiny middleware on the TLS-wrapped handler: `h3=":<port>"; ma=86400`, using the port actually bound. It does not use `SetQUICHeaders`. If TLS or either bind fails it degrades to HTTP-only and reports `TLSErr` (never advertises a dead port).
- TLS certs: `ensureCert` generates a self-signed ECDSA P-256 cert (5 years, SANs: localhost, hostname, hostname.local, all non-loopback IPs) into `-certs` dir, key mode 0600, and reuses it. Local/LAN only. MinVersion TLS1.2.
- Brotli: hand-rolled middleware on `github.com/andybalholm/brotli` v1.2.2 (`NewWriterLevel`, DefaultCompression). It is notably careful: RFC 9110 Accept-Encoding q-value parsing, `Vary`, distinct `-br` ETag suffix, no compression of 206/Range, 304 handling, HEAD, Flush. It wraps the whole handler at the net/http layer, not as Gin middleware.
- Graceful shutdown: `signal.Notify(SIGINT,SIGTERM)`, then `Stop(ctx)` with a 5 s timeout calling `http.Shutdown` on both servers and `h3.Close()` (not `h3.Shutdown`), then closes the packet conn. Gap worth fixing in job_seeker: use `h3.Shutdown(ctx)` (GOAWAY, drains) first.
- Config: **flags**, not env (`-http -https -db -certs -state ...`), plus env only for secrets and mode (`AUTH_SHARED_SECRET`, `AI_INTERVIEWING_ENV=production`). `bootguard.Check` refuses to boot in production with seed-account password hashes unrotated. `-state` writes the bound addresses as JSON (removed on exit); `-port-fallback` walks forward when a port is taken.
- Health: `GET/HEAD /api/health`, registered before auth, returns `{ok, version, proto, stats, source_commit, source_dirty}`; `buildinfo` is stamped via ldflags and says so honestly when unstamped. No separate `/ready`.
- Auth: bcrypt (`golang.org/x/crypto`) accounts in SQLite plus an optional `authkit` bridge (local `replace` to `submodules/authkit`, audience-scoped tokens), login rate limiter (per username and remote address, default 10 per minute).
- Errors: ad-hoc `c.JSON(status, gin.H{"error": "..."})`. No typed error model. job_seeker should do better (section 4).
- Logging: stdlib `log` / stderr prints. No structured logging. job_seeker should use `log/slog`.
- Storage: `modernc.org/sqlite` v1.59.0 (pure Go, CGO_ENABLED=0), DSN `?_pragma=busy_timeout(5000)&_pragma=journal_mode(WAL)&_pragma=foreign_keys(ON)`, `SetMaxOpenConns(1)`.
- Tests: 26 `_test.go` files, mostly `internal/api` black-box (`package api_test`, `httptest` against `Router()`, `seedAPI`/`doRaw` helpers), named regression files (`audit_regressions_test.go`, `hardening_test.go`, `contract_test.go`, `error_paths_test.go`). `gates/*.sh` + `gates/cmd/glive` are live end-to-end gates against a container, with `prove-*` scripts proving the gates fail when they should. I did not run any of it.
- Container: `Containerfile` builds with `golang:1.26-alpine`, `CGO_ENABLED=0`, runs on `alpine:3.20` as uid 10001, exposes 8099 only (HTTP) in the gate recipe. The build context must be the umbrella root because of the `replace` path. Orchestration is a compose file (`gates/compose.glive.yml`).
- Section 11.4.76: the Containers submodule (`submodules/containers`, Go module `digital.vasic.containers`) is authoritative for runtime detection, lifecycle, health, compose orchestration. A `Containerfile` image recipe is allowed (read in CLAUDE.md: the recipe itself is not the violation); hand-rolled runtime/lifecycle/orchestration scripts around it are. job_seeker must start/stop/health-check its container through that module (as `_tools/containers/` in the umbrella does), not through custom podman shell.

## 2. Verified versions and APIs (FETCHED)

| Item | Finding |
|---|---|
| quic-go | Latest release **v0.65.0** (2026-11-03). Reference pins v0.61.0 (older). Only breaking change noted for v0.65.0: `http3.HTTPStreamer.HTTPStream` now returns `(*Stream, error)` and no longer sends an implicit 200; irrelevant to a plain handler server. Module Go requirement not shown on the page: UNCONFIRMED, but the reference builds with Go 1.26. |
| http3.Server API (pkg.go.dev v0.65.0) | Fields: `Addr`, `Port` (for Alt-Svc), `TLSConfig`, `QUICConfig`, `Handler`, `EnableDatagrams`, `MaxHeaderBytes`, `IdleTimeout`, `ConnContext`, `Logger *slog.Logger`. Methods: `ListenAndServe`, `ListenAndServeTLS(cert,key)`, `Serve(net.PacketConn)`, `ServeListener`, `ServeQUICConn`, `SetQUICHeaders(http.Header) error` (sets Alt-Svc), `Shutdown(ctx)` (GOAWAY then drain), `Close()`. Docs warn that `Close`/`Shutdown` concurrent with `ListenAndServe` may race UDP socket creation; use `Serve(conn)` as the reference does. Closing a conn passed to `Serve` is the caller's job. |
| gin-gonic/gin | Latest **v1.12.0** (2026-02-28), same as the reference. `*gin.Engine` implements `http.Handler`, so it is passed straight as `http3.Server.Handler` and `http.Server.Handler`. |
| Brotli library | Reference uses `github.com/andybalholm/brotli` v1.2.2 (pure Go, no cgo). Could not fetch its release list (API 404), so "latest" is UNCONFIRMED; run `go list -m -versions github.com/andybalholm/brotli` at adoption. |
| Gin brotli middleware | `gin-contrib/gzip` is gzip only (per task premise; I did not re-fetch it). `github.com/anargu/gin-brotli`: 34 stars, 15 commits, no releases, adapted from the gzip middleware, uses andybalholm/brotli; last-commit date not visible. That is thin maintenance, so I recommend **not** adding it. Recommendation: copy the reference's net/http-layer `brotliMiddleware` (well tested against RFC 9110 edge cases), place it outside Gin so it covers every listener. For JSON-only APIs a simple cut-down version is enough. |
| Cronet in Go | There is no first-party Go Cronet binding. `github.com/SagerNet/cronet-go` ("Go bindings for naiveproxy", active, last push 2026-11-18, 48 stars) wraps Chromium's network stack via cgo with prebuilt native libs. My attempt to fetch `google/cronet-go` returned 404 (it does not exist as I assumed). Cronet's natural homes are Android (`org.chromium.net`) and iOS. |

## 3. Honest recommendation on "Cronet" client side

Cronet is Chromium's networking stack for native apps. A browser web console already speaks HTTP/3 natively through the browser's own stack; Cronet adds nothing there. So:

- **Web console**: plain `fetch` in the browser. HTTP/3 happens automatically after the first response carries `Alt-Svc`. Caveat: browsers refuse QUIC to a self-signed cert without a trusted root, so use a locally trusted CA (mkcert or an internal CA) or a real DNS name with a real cert; otherwise the browser silently stays on h2.
- **Any native mobile client later**: Cronet via the platform library (Android `CronetEngine`), not Go.
- **Go-side client (tests, CLI, provider scrapers)**: `quic-go/http3.Transport` (or `http3.RoundTripper`). Do not use cgo Cronet bindings; they add a heavy native dependency for no benefit. The task rule "Cronet on the client side" is therefore satisfied by Cronet only on mobile; state that explicitly to the operator rather than forcing a Go binding.

## 4. Recommended module layout for job_seeker

```
job_seeker/
  go.mod                      # go 1.26.x
  cmd/
    jobseekerd/main.go        # server: flags->env config, wiring, graceful shutdown
    jsctl/main.go             # operator CLI (hash password, migrate, import/export)
  internal/
    config/                   # env-by-name loader + validation (fail-fast)
    server/                   # TCP h1/h2 + QUIC h3 listener pair, Alt-Svc, cert, brotli
    api/                      # gin router, handlers, error model, middleware, health
    auth/                     # single-operator login, session/token, rate limiter
    providers/                # job-source adapters behind an interface (one pkg per provider)
    store/                    # SQLite access, migrations (embedded SQL), repositories
    match/                    # CV/profile vs posting scoring
    apply/                    # application drafting/submission workflow (human-in-the-loop gate)
    jobs/                     # background scheduler/worker (fetch, match, notify), context-cancelled
    buildinfo/                # ldflags-stamped commit/dirty, shown in /healthz
  pkg/                        # only genuinely reusable, stable pieces (e.g. brotli middleware, apierr)
  deploy/Containerfile        # image recipe only; runtime via Containers submodule
  gates/                      # live end-to-end gates + prove-* scripts, like the reference
```

Conventions to carry over: build-info stamping, `gin.New()` + explicit middleware, black-box `httptest` API tests plus live container gates with proofs that the gates can fail, pure-Go SQLite so `CGO_ENABLED=0`. Improvements over the reference: `slog` JSON logs with request id and no secrets; a single error type `{ "error": {"code","message","request_id"} }` with a central `c.Error` mapper; `/healthz` (liveness, no dependencies) and `/readyz` (DB reachable, migrations applied) both unauthenticated; env config instead of flags for secrets; `h3.Shutdown` before `Close`; split `internal/server` (transport) from `internal/api` (routes) as the reference already does.

## 5. Dependency list (versions verified unless marked)

| Module | Version | Basis |
|---|---|---|
| Go | 1.26.x (host 1.26.8) | READ go env + reference go.mod |
| github.com/gin-gonic/gin | v1.12.0 | FETCHED latest, = reference |
| github.com/quic-go/quic-go | v0.65.0 | FETCHED latest (reference is v0.61.0; bump and re-run tests) |
| github.com/andybalholm/brotli | v1.2.2 | READ reference pin; latest UNCONFIRMED |
| modernc.org/sqlite | v1.59.0 | READ reference pin; latest UNCONFIRMED |
| golang.org/x/crypto | v0.57.0 | READ reference pin (bcrypt or argon2id); latest UNCONFIRMED |
| quic-go/qpack, x/net, x/sys, x/text | transitive, let `go mod tidy` resolve | |
| digital.vasic.containers (submodules/containers) | gitlink pin, tooling only | READ CLAUDE.md |
| authkit (submodules/authkit) | local replace, optional | READ reference go.mod: not needed for one operator; skip unless sharing tokens with other umbrella services |

Check with `go list -m -u all` and `govulncheck` at project start; pins above are not a substitute.

## 6. SQLite vs Postgres

**Recommend SQLite** (`modernc.org/sqlite`, WAL, `busy_timeout`, `foreign_keys(ON)`, single writer connection, a small read pool is optional). Reasons: one operator, low write rate, no second service to run and secure, trivial backup (`VACUUM INTO` or file copy while quiescent), pure Go so scratch/alpine images and `CGO_ENABLED=0` work, and the reference already proves the pattern. Move to Postgres only if: multiple concurrent writers (heavy parallel scraping), more than one operator or tenant, full-text or vector search beyond SQLite FTS5 is needed, or the DB grows beyond a few GB. Keep all SQL behind `internal/store` repositories and use embedded numbered migrations so a later move is contained. Store the DB on a named volume, not the image; mind that an `-ingest`-style pre-built DB baked into the image (as in the reference) is wrong for personal data.

## 7. Config and secrets

- Env-by-name only: `JOBSEEKER_HTTP_ADDR`, `JOBSEEKER_HTTPS_ADDR`, `JOBSEEKER_DB_PATH`, `JOBSEEKER_CERT_DIR` (or `_CERT_FILE`/`_KEY_FILE`), `JOBSEEKER_OPERATOR_PASSWORD_HASH`, `JOBSEEKER_SESSION_KEY`, provider API keys as `JOBSEEKER_PROVIDER_<NAME>_KEY`, plus `JOBSEEKER_ENV`. Values are read from the process environment; the operator's `~/api_keys.sh` style source file stays outside the repo. Never print values; log only names and presence/absence. A `.env.example` holds names only; `.env` is gitignored, mode 0600.
- Fail closed: refuse to boot in production if the operator hash or session key is missing or equals a documented example (the reference's `bootguard` idea, applied to env).
- Single-operator auth: one argon2id/bcrypt hash from env, login rate limit, HttpOnly + Secure + SameSite=Strict session cookie or short-lived signed token, CSRF protection for cookie auth, no registration endpoint, all routes except `/healthz`, `/readyz`, `/login` behind auth. Provider credentials and CV data are personal data; encrypt provider tokens at rest with a key from env if they are stored in the DB.
- Do not auto-generate self-signed certs in production; the reference does it for local use. For a LAN/private host use a locally trusted CA cert mounted read-only.

## 8. Risks

1. **HTTP/3 falls back silently**: self-signed or untrusted cert, UDP blocked by firewall or by the container port mapping (must publish UDP as well as TCP), or Alt-Svc advertising a port that is not the published one. Mitigate with a live gate that asserts an actual h3 response (`proto == "HTTP/3.0"` from an `http3.Transport` client; the reference's health endpoint already echoes `proto`).
2. quic-go is pre-1.0 (v0.65.0); minor releases carry API breaks (v0.65.0 changed `HTTPStream`). Pin, read release notes on each bump, keep the h3 usage minimal.
3. Reference is on v0.61.0; a bump is untested here (UNCONFIRMED that it builds unchanged).
4. UDP receive buffer size on Linux (quic-go logs a warning; `net.core.rmem_max` is a host sysctl change, an operator action).
5. Brotli middleware correctness (ETag, Range, Vary, 304) is easy to get subtly wrong; reuse the reference's tested code and tests rather than `anargu/gin-brotli` (maintenance unclear).
6. "Cronet" has no Go binding of first-party quality; the cgo SagerNet bindings are naiveproxy-oriented and heavy. Decision needed from the operator (section 3).
7. SQLite with `SetMaxOpenConns(1)` can stall long background jobs against API reads; keep jobs short, batch writes, or add a separate read-only pool.
8. Compliance with job-site terms of service and anti-bot measures for scraping providers, plus automated applying on the operator's behalf; keep the `apply` step human-approved.
9. Personal data (CV, contacts) in a repo or image: gitignore data dirs, never bake the DB into the image, back up with pre-op copies (section 9).
10. Section 11.4.76: any container start/stop/health script written by hand is a violation; use `digital.vasic.containers`. Section 11.4.209/11.4.142: independent review of the build before acceptance.
11. Unverified here: none of the reference tests, build or container gates were run in this task.

## 9. Summary (12 lines)

1. Reference = Gin (`gin.New`, Recovery, security headers) over `net/http`, Go 1.26.2, SQLite via modernc, bcrypt auth.
2. HTTP/3: `http3.Server{Handler, TLSConfig}.Serve(udpConn)` on the same port number as the TCP TLS listener; Alt-Svc `h3=":<port>"; ma=86400` set by a middleware.
3. Brotli: hand-rolled net/http middleware on andybalholm/brotli v1.2.2 with RFC-correct Accept-Encoding, Vary, ETag, Range handling.
4. Gaps to fix in job_seeker: flags-only config, no slog, ad-hoc error JSON, no /readyz, `h3.Close` instead of `Shutdown`.
5. Verified latest: quic-go v0.65.0 (2026-11-03), gin v1.12.0; reference is on quic-go v0.61.0.
6. `gin-contrib/gzip` has no brotli; `anargu/gin-brotli` is lightly maintained; recommend reusing the reference middleware.
7. Cronet has no first-party Go binding; web console uses browser fetch (h3 automatic), Go clients use `quic-go/http3.Transport`, Cronet only for future Android/iOS.
8. Layout: cmd/{jobseekerd,jsctl}, internal/{config,server,api,auth,providers,store,match,apply,jobs,buildinfo}, pkg/, deploy/Containerfile, gates/.
9. Storage: SQLite (WAL, pure Go, single writer); Postgres only if multi-writer/multi-tenant.
10. Secrets: env-by-name (`JOBSEEKER_*`), names-only `.env.example`, fail-closed boot guard, never printed or committed.
11. Container: Containerfile for the image only; lifecycle through `submodules/containers` per section 11.4.76; publish both TCP and UDP.
12. Top risks: silent h3 fallback (cert/UDP), pre-1.0 quic-go API churn, Cronet expectation mismatch, scraping/ToS, personal data handling.
