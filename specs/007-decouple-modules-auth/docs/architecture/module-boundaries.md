# Module Boundaries — Architecture Diagrams

**Spec**: specs/007-decouple-modules-auth
**Generated**: 2026-09-13

---

## 1. Overview

Two independent modules (`workshop` and `ai_interviewing`) are decoupled from the vasic umbrella into fully standalone projects. Each module is clonable, installable, and runnable without access to the vasic repository.

```
┌─────────────────────────────────────────────────────────────────────┐
│                        vasic umbrella                                │
│                                                                     │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐     │
│  │  workshop    │  │  ai_interview│  │  vasic.digital       │     │
│  │  (milos85vasic)│ │  (milos85vasic)│ │  (vasic-digital)     │     │
│  │              │  │              │  │                      │     │
│  │  ┌────────┐  │  │  ┌────────┐  │  │  ┌──────────────┐   │     │
│  │  │backend │  │  │  │backend │  │  │  │ containers   │   │     │
│  │  │ (Go)   │  │  │  │ (Go)   │  │  │  │ LLMProvider  │   │     │
│  │  └────────┘  │  │  └────────┘  │  │  │ RAG          │   │     │
│  │  ┌────────┐  │  │  ┌────────┐  │  │  │ verdict      │   │     │
│  │  │frontend│  │  │  │frontend│  │  │  │ passage      │   │     │
│  │  │(Angular)│ │  │  │(Angular)│ │  │  │ curriculum-kit│  │     │
│  │  └────────┘  │  │  └────────┘  │  │  │ design-toolkit│  │     │
│  │  ┌────────┐  │  │  ┌────────┐  │  │  └──────────────┘   │     │
│  │  │ auth   │  │  │  │ auth   │  │  │  └──────────────────┘     │
│  │  │store   │  │  │  │store   │  │  │                            │
│  │  └────────┘  │  │  └────────┘  │  │                            │
│  │              │  │              │  │                            │
│  │  SQLite      │  │  SQLite      │  │  vasic-digital submodules   │
│  │  (embedded)  │  │  (curriculum)│  │  (public, reusable)         │
│  └──────────────┘  └──────────────┘  └─────────────────────────────┘
│                                                                     │
│  ┌───────────────────────────────────────────────────────────┐      │
│  │ constitution (governance source)  │ superspec (third-party) │      │
│  └───────────────────────────────────────────────────────────┘      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 2. Data Flow — Workshop Module

```
┌──────────┐     ┌──────────┐     ┌──────────────┐     ┌──────────┐
│  User    │────▶│  chi     │────▶│  authhttp    │────▶│  auth    │
│ (browser)│     │  router  │     │  middleware  │     │  store   │
└──────────┘     └──────────┘     └──────────────┘     └────┬─────┘
                                                               │
                    ┌──────────────┐     ┌─────────────────────┘
                    │  progress    │◀────│  derived key
                    │  bridge      │     │  auth.UserProgressKey
                    └──────┬───────┘     └─────────────────────
                           │
                    ┌──────▼───────┐     ┌─────────────────────
                    │  curriculum  │◀────│  ProgressStore
                    │  (content)   │     │  (atomic JSON)
                    └──────┬───────┘     └─────────────────────
                           │
                    ┌──────▼───────┐     ┌─────────────────────
                    │  search      │◀────│  FTS5 index
                    │  (FTS5)      │     │  (per-member query)
                    └──────────────┘     └─────────────────────
```

**Key properties:**
- `auth.UserProgressKey(userID) = "auth-user:<id>"` — deterministic, survives restarts
- `X-Session` header remains pre-auth fallback
- All content gated by `authhttp.Middleware` (fail-closed 503 if auth store unopenable)
- Health endpoint (`/api/health`) is public
- Auth endpoints (`/api/auth/login|logout|switch`, `/api/auth/me`) are carved out of the middleware

---

## 3. Data Flow — ai_interviewing Module

```
┌──────────┐     ┌──────────┐     ┌──────────────┐     ┌──────────┐
│  User    │────▶│  chi     │────▶│  auth.go     │────▶│  auth    │
│ (browser)│     │  router  │     │  middleware  │     │  store   │
└──────────┘     └──────────┘     └──────────────┘     └────┬─────┘
                                                               │
                    ┌──────────────┐     ┌─────────────────────┘
                    │  progress    │◀────│  derived key
                    │  handler     │     │  auth.UserProgressKey
                    └──────┬───────┘     └─────────────────────
                           │
                    ┌──────▼───────┐     ┌─────────────────────
                    │  ingest      │◀────│  content group
                    │  (AI docs)   │     │  (knowledge_base)
                    └──────┬───────┘     └─────────────────────
                           │
                    ┌──────▼───────┐     ┌─────────────────────
                    │  search      │◀────│  knowledge_base
                    │  (vector)    │     │  (embedding-based)
                    └──────────────┘     └─────────────────────
```

**Key properties:**
- `postProgress/getProgress` use derived key (overrides client session)
- `TestProgressIsPerAccount` proves two accounts posting the same item keep separate summaries
- Restricted modules: `employer_data`, `github_analysis` (user role only, rami can't access)
- `search` drops hits from restricted modules (enforced at content layer, not just login response)

---

## 4. Module Boundary — Auth Database

```
┌──────────────────────────────────────────────────────────┐
│                  PostgreSQL (shared)                       │
│                                                          │
│  ┌───────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ auth_user │  │auth_module   │  │auth_permission│     │
│  │           │  │              │  │              │      │
│  │ milosvasic│  │ workshop     │  │ workshop/all │      │
│  │ admin     │  │ ai_interview │  │ ai_interview │      │
│  │           │  │              │  │              │      │
│  │ rami      │  │              │  │              │      │
│  │ user      │  │              │  │              │      │
│  └───────────┘  └──────────────┘  └──────────────┘      │
│                                                          │
│  ┌───────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ auth_     │  │auth_session  │  │ auth_user_   │      │
│  │ module    │  │              │  │ module       │      │
│  │           │  │              │  │              │      │
│  │ 1 workshop│  │ token_hash   │  │ milosvasic+  │      │
│  │ 2 ai_int  │  │ user_id FK   │  │ workshop=adm │      │
│  │           │  │ module_id FK │  │ rami=user    │      │
│  └───────────┘  └──────────────┘  └──────────────┘      │
└──────────────────────────────────────────────────────────┘
```

**Each module also maintains its own `auth.db` (SQLite)** for session persistence that survives index rebuilds by design.

---

## 5. Submodule Architecture

```
vasic-digital submodules (public, reusable):
├── containers       — runtime auto-detection, endpoint discovery, lifecycle
├── LLMProvider      — 40+ provider adapters, retry, circuit breaker, health
├── RAG              — document retrieval, chunking, embedding pipeline
├── verdict          — benchmark and verify LLMs
├── passage          — extraction pipeline (S00/S04 sections)
├── curriculum-kit   — Catalog → Area → Lesson → Material + Assessment
└── design-toolkit   — per-brand tokens and component CSS

milos85vasic submodules (standalone projects):
├── workshop         — teaching corpus with video-archive pipeline
├── ai_interviewing  — interview preparation with employer due-diligence
└── monetization     — docs, repos.txt, upstream declaration scripts

vasic-digital (root level):
└── vasic.digital    — committed static HTML site
```

---

## 6. Governance Cascade

```
submodules/constitution (source)
    │
    ├── C1: Fleet classification (13 gitlinks from .gitmodules)
    ├── C2: 12 × 4 = 48 owned-submodule carriers present
    ├── C3: All accepted by is_pointer_carrier predicate
    ├── C4: Cascade completeness (no gaps)
    ├── C5: Root lockstep (4 carriers identical)
    ├── C6: Manifest-fleet sync (14 gitlinks = 13 deps + third-party)
    ├── C7: Recursion (1 nested gitlink under milosvasic.ru)
    ├── C8: In-submodule lockstep (12 × 4 carriers identical)
    └── C9: Manifest pin sync (13 MATCH / 0 DRIFT)
    
    Result: 12 PASS, 0 FAIL, 0 ENV, 8 NOTE
```
