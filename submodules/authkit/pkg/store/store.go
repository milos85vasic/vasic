// Package store is the shared SQLite persistence layer for authkit: users,
// roles, role assignments, the data-driven permission matrix, and sessions.
//
// It is intentionally the ONLY package in this module that knows SQL. Every
// other package (pkg/rbac, pkg/session) is handed a *sql.DB via Store.DB()
// and does its own reads against these tables — that split keeps the schema
// centralized (one migration set, one place to reason about columns) while
// letting the packages that make security DECISIONS (allow/deny,
// valid/invalid) own their own query and their own fail-closed behavior.
//
// Pure-Go SQLite (modernc.org/sqlite) — no cgo. The pragma string mirrors
// ai_interviewing/platform/backend/internal/store/store.go exactly, so a
// consuming module's existing operational assumptions about WAL mode, the
// busy timeout and foreign-key enforcement carry over unchanged.
//
// Covers T488 (shared DB schema + migrations for a user store with roles
// admin/user) and is the storage substrate T502/T505/T506/T507/T511/T579
// build on.
package store

import (
	"database/sql"
	"errors"
	"strconv"
	"time"

	_ "modernc.org/sqlite"
)

// Store wraps the shared authkit database. It is safe for concurrent use by
// multiple goroutines (database/sql pools its own connections); SetMaxOpenConns
// is pinned to 1 for the same reason ai_interviewing pins it: WAL mode plus a
// single writer keeps modernc.org/sqlite deterministic under concurrent access
// from this process, and this store is small and write-light enough that
// serializing writes costs nothing observable.
type Store struct {
	db *sql.DB
}

// ErrUserNotFound is returned by UserByUsername and UserByID when no row
// matches. It is deliberately distinct from a driver error: a caller that
// wants "generic invalid credentials" behavior (T509) must be able to tell
// "no such user" apart from "the database is unreachable" even though both
// ultimately produce the same user-facing message.
var ErrUserNotFound = errors.New("authkit/store: user not found")

// ErrRoleNotFound is returned by role lookups when the named role does not
// exist and the caller did not ask for it to be created.
var ErrRoleNotFound = errors.New("authkit/store: role not found")

// Open opens (creating if necessary) the SQLite database at path and runs
// every migration. The pragma string is fixed and matches both consuming
// applications' own store layers:
//
//	_pragma=busy_timeout(5000)&_pragma=journal_mode(WAL)&_pragma=foreign_keys(ON)
func Open(path string) (*Store, error) {
	db, err := sql.Open("sqlite", path+"?_pragma=busy_timeout(5000)&_pragma=journal_mode(WAL)&_pragma=foreign_keys(ON)")
	if err != nil {
		return nil, err
	}
	db.SetMaxOpenConns(1)
	s := &Store{db: db}
	if err := s.migrate(); err != nil {
		_ = db.Close()
		return nil, err
	}
	return s, nil
}

// DB returns the underlying *sql.DB. pkg/rbac and pkg/session use it to run
// their own read queries against the tables this package defines, and tests
// use it to simulate a DB-down condition (Store.DB().Close()) without
// tearing down the Store value itself.
func (s *Store) DB() *sql.DB { return s.db }

// Close closes the underlying database connection.
func (s *Store) Close() error { return s.db.Close() }

func (s *Store) migrate() error {
	for _, stmt := range migrations {
		if _, err := s.db.Exec(stmt); err != nil {
			return err
		}
	}
	return nil
}

// --- users -------------------------------------------------------------

// CreateUser inserts a new user with an already-hashed password (never a
// plaintext one — pkg/password produces the hash) and returns its id as a
// string. Usernames are unique; inserting a duplicate returns the driver's
// UNIQUE constraint error unchanged so a caller can detect it with
// errors.Is / string matching as it prefers.
func (s *Store) CreateUser(username, passwordHash string) (string, error) {
	now := time.Now().UTC().Format(time.RFC3339)
	res, err := s.db.Exec(`INSERT INTO ak_user(username, password_hash, created_at) VALUES(?,?,?)`,
		username, passwordHash, now)
	if err != nil {
		return "", err
	}
	id, err := res.LastInsertId()
	if err != nil {
		return "", err
	}
	return formatID(id), nil
}

// UserByUsername resolves a username to (userID, passwordHash). It returns
// ErrUserNotFound — never a bare sql.ErrNoRows — when the username does not
// exist, so callers implementing T509 (generic auth failure) can treat
// ErrUserNotFound and "known user, wrong password" identically without
// needing to know about database/sql's sentinel.
func (s *Store) UserByUsername(username string) (userID, passwordHash string, err error) {
	var id int64
	err = s.db.QueryRow(`SELECT id, password_hash FROM ak_user WHERE username = ?`, username).Scan(&id, &passwordHash)
	if errors.Is(err, sql.ErrNoRows) {
		return "", "", ErrUserNotFound
	}
	if err != nil {
		return "", "", err
	}
	return formatID(id), passwordHash, nil
}

// UserByID resolves a userID to its username. Used by callers that only hold
// an id (e.g. from a validated session) and need it for display or audit.
func (s *Store) UserByID(userID string) (username string, err error) {
	id, err := parseID(userID)
	if err != nil {
		return "", ErrUserNotFound
	}
	err = s.db.QueryRow(`SELECT username FROM ak_user WHERE id = ?`, id).Scan(&username)
	if errors.Is(err, sql.ErrNoRows) {
		return "", ErrUserNotFound
	}
	return username, err
}

// SetPasswordHash replaces a user's stored hash (e.g. after a password
// change). It never accepts or stores a plaintext password.
func (s *Store) SetPasswordHash(userID, passwordHash string) error {
	id, err := parseID(userID)
	if err != nil {
		return err
	}
	_, err = s.db.Exec(`UPDATE ak_user SET password_hash = ? WHERE id = ?`, passwordHash, id)
	return err
}

// --- roles ---------------------------------------------------------------

// EnsureRole creates the named role if it does not already exist and returns
// its id either way. Role names are the closed-ish vocabulary a deployment
// chooses (this module ships no hardcoded "admin"/"user" — see T511 and
// T579: the ROWS are data, not a compiled-in list).
func (s *Store) EnsureRole(name string) (string, error) {
	if _, err := s.db.Exec(`INSERT OR IGNORE INTO ak_role(name) VALUES(?)`, name); err != nil {
		return "", err
	}
	var id int64
	if err := s.db.QueryRow(`SELECT id FROM ak_role WHERE name = ?`, name).Scan(&id); err != nil {
		return "", err
	}
	return formatID(id), nil
}

// AssignRole grants userID the named role. The role must already exist
// (created via EnsureRole) — AssignRole does not silently create one, so a
// typo'd role name fails loudly instead of quietly minting an unused role.
func (s *Store) AssignRole(userID, roleName string) error {
	uid, err := parseID(userID)
	if err != nil {
		return err
	}
	var rid int64
	if err := s.db.QueryRow(`SELECT id FROM ak_role WHERE name = ?`, roleName).Scan(&rid); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return ErrRoleNotFound
		}
		return err
	}
	_, err = s.db.Exec(`INSERT OR IGNORE INTO ak_user_role(user_id, role_id) VALUES(?,?)`, uid, rid)
	return err
}

// RemoveRole revokes userID's membership in the named role. Used to prove a
// roleless user (T511) gets zero access: assign then remove, leaving zero
// ak_user_role rows for that user.
func (s *Store) RemoveRole(userID, roleName string) error {
	uid, err := parseID(userID)
	if err != nil {
		return err
	}
	_, err = s.db.Exec(`
		DELETE FROM ak_user_role
		WHERE user_id = ? AND role_id = (SELECT id FROM ak_role WHERE name = ?)`,
		uid, roleName)
	return err
}

// --- permissions (T579: genuine data, not a hardcoded roster) ------------

// GrantRolePermission inserts one (role, module, resource, action) rule.
// This is the extensibility surface T579 exercises directly: a THIRD tuple
// granted here, with zero code changes anywhere in this module or a
// consumer, takes effect the next time pkg/rbac.Engine.Allowed is called —
// because Allowed reads this table at decision time, every time.
func (s *Store) GrantRolePermission(roleName, module, resource, action string) error {
	var rid int64
	if err := s.db.QueryRow(`SELECT id FROM ak_role WHERE name = ?`, roleName).Scan(&rid); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return ErrRoleNotFound
		}
		return err
	}
	_, err := s.db.Exec(`
		INSERT OR IGNORE INTO ak_permission(subject_type, subject_id, module, resource, action)
		VALUES('role', ?, ?, ?, ?)`, rid, module, resource, action)
	return err
}

// GrantUserPermission inserts one (user, module, resource, action) rule that
// applies to a single account directly, bypassing roles entirely. Exists so
// the permission model can express a per-account override, not only
// per-role access — matching the "(user, module, resource, action) rule
// set" T579 requires this to genuinely be.
func (s *Store) GrantUserPermission(userID, module, resource, action string) error {
	uid, err := parseID(userID)
	if err != nil {
		return err
	}
	_, err = s.db.Exec(`
		INSERT OR IGNORE INTO ak_permission(subject_type, subject_id, module, resource, action)
		VALUES('user', ?, ?, ?, ?)`, uid, module, resource, action)
	return err
}

// --- id helpers ------------------------------------------------------------

// formatID/parseID convert between the storage representation (an integer
// primary key) and the public string-typed id every package in this module
// uses, so callers never need to know the storage representation.
func formatID(id int64) string { return strconv.FormatInt(id, 10) }

func parseID(s string) (int64, error) { return strconv.ParseInt(s, 10, 64) }
