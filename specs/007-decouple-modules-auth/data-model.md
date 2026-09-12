# Data Model: Decouple Modules, Add Authentication & Extract Reusables

**Feature**: specs/007-decouple-modules-auth
**Generated**: 2026-09-12
**Source**: Plan.md Phase 1 Design

---

## Entities

### User
**Table**: `users` (shared auth database)

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| `id` | UUID | PK, not null, default gen_random_uuid() | Unique identifier |
| `username` | VARCHAR(100) | UNIQUE, not null | Login username: "milosvasic", "rami" |
| `password_hash` | VARCHAR(255) | not null | bcrypt/argon2 hash |
| `role` | VARCHAR(20) | not null, CHECK (role IN ('admin','user')) | "admin" = full access, "user" = restricted |
| `created_at` | TIMESTAMPTZ | not null, default now() | Account creation |
| `updated_at` | TIMESTAMPTZ | not null, default now() | Last profile update |
| `last_login` | TIMESTAMPTZ | nullable | Last successful login |

**Indexes**: 
- Primary key on `id`
- Unique index on `username`

**Seed Data**:
```sql
INSERT INTO users (username, password_hash, role) VALUES 
('milosvasic', '<bcrypt-hash-of-WhiteSnake8587>', 'admin'),
('rami', '<bcrypt-hash-of-Test12345>', 'user');
```

---

### Module
**Table**: `modules` (shared auth database)

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| `id` | UUID | PK, not null, default gen_random_uuid() | Unique identifier |
| `name` | VARCHAR(50) | UNIQUE, not null | Internal name: "workshop", "ai_interviewing" |
| `display_name` | VARCHAR(100) | not null | Human-readable: "Workshop Curriculum", "AI Interviewing" |
| `description` | TEXT | nullable | Module description |
| `created_at` | TIMESTAMPTZ | not null, default now() | Record creation |

**Seed Data**:
```sql
INSERT INTO modules (name, display_name, description) VALUES 
('workshop', 'Workshop Curriculum', 'Curriculum platform with chapters, lessons, exercises'),
('ai_interviewing', 'AI Interviewing', 'Knowledge base with areas, lessons, tests, exercises');
```

---

### Permission
**Table**: `permissions` (shared auth database)

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| `id` | UUID | PK, not null, default gen_random_uuid() | Unique identifier |
| `module_id` | UUID | FK → modules(id), not null | Module this permission applies to |
| `resource` | VARCHAR(100) | not null | Resource identifier |
| `action` | VARCHAR(20) | not null, CHECK (action IN ('read','write','delete')) | Action type |
| `role` | VARCHAR(20) | not null, CHECK (role IN ('admin','user')) | Role that has this permission |

**Resources** (per module):
- **workshop**: "all" (wildcard for full access)
- **ai_interviewing**: "knowledge_base", "progress", "employer_data", "github_analysis"

**Seed Data**:
```sql
-- workshop: both roles have full access
INSERT INTO permissions (module_id, resource, action, role) VALUES
((SELECT id FROM modules WHERE name='workshop'), 'all', 'read', 'admin'),
((SELECT id FROM modules WHERE name='workshop'), 'all', 'write', 'admin'),
((SELECT id FROM modules WHERE name='workshop'), 'all', 'delete', 'admin'),
((SELECT id FROM modules WHERE name='workshop'), 'all', 'read', 'user'),
((SELECT id FROM modules WHERE name='workshop'), 'all', 'write', 'user'),
((SELECT id FROM modules WHERE name='workshop'), 'all', 'delete', 'user');

-- ai_interviewing: admin has full access
INSERT INTO permissions (module_id, resource, action, role) VALUES
((SELECT id FROM modules WHERE name='ai_interviewing'), 'knowledge_base', 'read', 'admin'),
((SELECT id FROM modules WHERE name='ai_interviewing'), 'knowledge_base', 'write', 'admin'),
((SELECT id FROM modules WHERE name='ai_interviewing'), 'progress', 'read', 'admin'),
((SELECT id FROM modules WHERE name='ai_interviewing'), 'progress', 'write', 'admin'),
((SELECT id FROM modules WHERE name='ai_interviewing'), 'employer_data', 'read', 'admin'),
((SELECT id FROM modules WHERE name='ai_interviewing'), 'github_analysis', 'read', 'admin');

-- ai_interviewing: user has restricted access
INSERT INTO permissions (module_id, resource, action, role) VALUES
((SELECT id FROM modules WHERE name='ai_interviewing'), 'knowledge_base', 'read', 'user'),
((SELECT id FROM modules WHERE name='ai_interviewing'), 'progress', 'read', 'user'),
((SELECT id FROM modules WHERE name='ai_interviewing'), 'progress', 'write', 'user');
-- NOTE: NO permissions for employer_data, github_analysis for 'user' role
```

**Indexes**:
- Primary key on `id`
- Composite index on `(module_id, resource, action, role)` for fast lookup

---

### ProgressRecord
**Table**: `progress_records` (per-module database — each module has its own)

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| `id` | UUID | PK, not null, default gen_random_uuid() | Unique identifier |
| `user_id` | UUID | FK → users(id), not null | User who owns this progress |
| `module_id` | UUID | FK → modules(id), not null | Module context |
| `area_id` | VARCHAR(100) | not null | Area/category identifier |
| `lesson_id` | VARCHAR(100) | not null | Lesson identifier within area |
| `item_type` | VARCHAR(20) | not null, CHECK (item_type IN ('lesson','test','exercise')) | Type of learning item |
| `item_id` | VARCHAR(100) | not null | Specific item identifier |
| `completed` | BOOLEAN | not null, default false | Completion status |
| `score` | INTEGER | nullable | Score for tests (0-100) |
| `completed_at` | TIMESTAMPTZ | nullable | When completed |
| `created_at` | TIMESTAMPTZ | not null, default now() | Record creation |
| `updated_at` | TIMESTAMPTZ | not null, default now() | Last update |

**Indexes**:
- Primary key on `id`
- Composite unique index on `(user_id, module_id, area_id, lesson_id, item_type, item_id)` — one record per user/module/area/lesson/item
- Index on `(user_id, module_id)` for user's progress queries
- Index on `(module_id, area_id, lesson_id)` for area/lesson analytics

**Validation Rules**:
- `score` only applicable when `item_type = 'test'` and `completed = true`
- `completed_at` set when `completed` transitions to true
- `updated_at` updated on every modification

---

### Session
**Table**: `sessions` (shared auth database)

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| `id` | UUID | PK, not null, default gen_random_uuid() | Unique identifier |
| `user_id` | UUID | FK → users(id), not null | Session owner |
| `token` | VARCHAR(255) | UNIQUE, not null | Secure random token (32+ bytes) |
| `expires_at` | TIMESTAMPTZ | not null | Token expiration (24h default) |
| `created_at` | TIMESTAMPTZ | not null, default now() | Session creation |
| `revoked_at` | TIMESTAMPTZ | nullable | Explicit revocation (logout) |
| `ip_address` | INET | nullable | Client IP for audit |
| `user_agent` | TEXT | nullable | Client user agent for audit |

**Indexes**:
- Primary key on `id`
- Unique index on `token`
- Index on `(user_id, revoked_at)` for active sessions
- Index on `expires_at` for cleanup job

**Validation Rules**:
- Token generated via crypto/rand (32 bytes, base64url encoded)
- Default expiration: 24 hours from creation
- Session invalid if `revoked_at` is not null OR `expires_at < now()`
- Revocation on logout, password change, or admin action

---

## Relationships

```
users (1) ───< (N) sessions
users (1) ───< (N) progress_records
modules (1) ───< (N) permissions
modules (1) ───< (N) progress_records
```

## State Transitions

### User Authentication
```
UNAUTHENTICATED → (login) → AUTHENTICATED (session created)
AUTHENTICATED → (logout) → UNAUTHENTICATED (session revoked)
AUTHENTICATED → (token expiry) → UNAUTHENTICATED (session expired)
AUTHENTICATED → (switch account) → AUTHENTICATED (old session revoked, new created)
```

### Progress Tracking
```
NOT_STARTED → (start) → IN_PROGRESS (completed=false)
IN_PROGRESS → (complete) → COMPLETED (completed=true, completed_at=now, score set if test)
COMPLETED → (retry/reset) → NOT_STARTED (record deleted or new attempt created)
```

### Session Lifecycle
```
CREATED → (use) → ACTIVE
ACTIVE → (revoke) → REVOKED
ACTIVE → (expire) → EXPIRED
REVOKED/EXPIRED → (cleanup) → DELETED (by background job)
```

## Database Per Module

### Workshop Database (SQLite)
- Embedded in Go binary via modernc.org/sqlite
- Schema: `chapters`, `lessons`, `exercises`, `progress_records` (synced from shared auth via user_id)
- FTS5 on lesson content for search

### ai_interviewing Database (SQLite)
- File: `data/curriculum.db`
- Schema: `areas`, `lessons`, `tests`, `exercises`, `mcq`, `short_answers`, `progress_records`
- Ingested from `docs/`, `content/` via `ingest.sh`

### Shared Auth Database (PostgreSQL)
- Tables: `users`, `modules`, `permissions`, `sessions`
- Accessible by both modules via connection string
- Migrations managed via Go migrate or similar

---

## Validation Rules Summary

| Entity | Rule |
|--------|------|
| User | Username unique, password hashed, role enum |
| Module | Name unique, display_name required |
| Permission | (module, resource, action, role) unique; resource/action enums |
| ProgressRecord | Composite unique per user/module/area/lesson/item; score only for tests |
| Session | Token unique, expires_at > created_at, revoked_at nullable |

---

## Migration Strategy

1. **Shared Auth DB**: Create via migration scripts (Go migrate or SQL files)
2. **Workshop**: Add `progress_records` table to existing SQLite schema
3. **ai_interviewing**: Add `progress_records` table to existing SQLite schema
4. **Seed Data**: Insert users, modules, permissions in transaction
5. **Rollback**: Each migration has DOWN script