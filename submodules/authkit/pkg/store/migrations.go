package store

// migrations is a versioned, append-only list of DDL statements applied in
// order, each idempotent (CREATE ... IF NOT EXISTS / CREATE INDEX ... IF NOT
// EXISTS) so Open can run the full list on every startup without an explicit
// schema_version bookkeeping table — the same "migrate() replays the whole
// schema" convention ai_interviewing's own store.go uses. A future migration
// is appended as migrations[1], never edited into migrations[0].
//
// T488: this is the shared DB schema. Tables:
//
//	ak_user        one row per account: username, password_hash (never
//	               plaintext or reversibly-encrypted — see pkg/password),
//	               created_at.
//	ak_role        named roles ("admin", "user", or anything else a
//	               deployment chooses — this module hardcodes none).
//	ak_user_role   many-to-many user<->role membership.
//	ak_permission  the data-driven access-control matrix. Shaped
//	               (id, subject_type, subject_id, module, resource, action)
//	               — subject_type/subject_id together are the
//	               "role_id_or_user_id" T579 calls for: a permission can
//	               apply to a whole role or to one specific user. pkg/rbac
//	               reads this table at decision time; adding a row is the
//	               entire extension mechanism (T579).
//	ak_session     one row per issued session id (T505/T506): created_at,
//	               revoked_at (session-level invalidation / logout).
//	ak_cutover     a single row holding the "minimum valid issued-at"
//	               timestamp (T506's global invalidate-all-before-time —
//	               e.g. for a credential-rotation cutover). Any session
//	               token whose issued-at predates this value is rejected
//	               by pkg/session.Validate regardless of the session row's
//	               own state.
var migrations = []string{
	migration0001,
}

const migration0001 = `
CREATE TABLE IF NOT EXISTS ak_user (
  id            INTEGER PRIMARY KEY,
  username      TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  created_at    TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS ak_role (
  id   INTEGER PRIMARY KEY,
  name TEXT NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS ak_user_role (
  user_id INTEGER NOT NULL,
  role_id INTEGER NOT NULL,
  PRIMARY KEY (user_id, role_id),
  FOREIGN KEY (user_id) REFERENCES ak_user(id) ON DELETE CASCADE,
  FOREIGN KEY (role_id) REFERENCES ak_role(id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_ak_user_role_user ON ak_user_role(user_id);

-- The extensibility-critical table (T579). subject_type disambiguates
-- subject_id between a role row and a user row (SQLite has no native
-- polymorphic foreign key); the pair is what the task text calls
-- "role_id_or_user_id". No row here is compiled into any Go source file —
-- every grant is a plain INSERT, and every check is a plain SELECT.
CREATE TABLE IF NOT EXISTS ak_permission (
  id           INTEGER PRIMARY KEY,
  subject_type TEXT NOT NULL CHECK (subject_type IN ('role','user')),
  subject_id   INTEGER NOT NULL,
  module       TEXT NOT NULL,
  resource     TEXT NOT NULL,
  action       TEXT NOT NULL,
  UNIQUE(subject_type, subject_id, module, resource, action)
);
CREATE INDEX IF NOT EXISTS idx_ak_permission_lookup
  ON ak_permission(subject_type, subject_id, module, resource, action);

CREATE TABLE IF NOT EXISTS ak_session (
  id         TEXT PRIMARY KEY,
  user_id    INTEGER NOT NULL,
  created_at TEXT NOT NULL,
  revoked_at TEXT,
  FOREIGN KEY (user_id) REFERENCES ak_user(id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_ak_session_user ON ak_session(user_id);

-- Singleton row (id fixed at 1) holding the cutover timestamp for T506's
-- invalidate-everything-before-now operation. Absent row / empty value means
-- "no cutover has ever been set" and every session is eligible on that axis.
CREATE TABLE IF NOT EXISTS ak_cutover (
  id                  INTEGER PRIMARY KEY CHECK (id = 1),
  min_valid_issued_at TEXT NOT NULL
);
`
