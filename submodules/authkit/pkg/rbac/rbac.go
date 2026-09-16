// Package rbac makes the one decision every protected request needs: is this
// user allowed to perform this action on this resource in this module. It
// reads the ak_permission table pkg/store defines — a genuine
// (subject, module, resource, action) rule set — at decision time, on every
// call. Nothing about which users or roles have access is compiled into this
// package; the only thing compiled in is HOW to read the rule set.
//
// Covers:
//   - T511 (default-deny): a user with no matching row — because they hold
//     no role, or their role holds no matching grant, and they hold no
//     direct grant either — gets false, nil. Never an inherited or
//     admin-equivalent access, and never an error standing in for a grant.
//   - T507 (fail-closed): any error reaching the database (including "the
//     database is closed/unreachable") returns (false, err). This package
//     never returns (true, err) under any code path — see rbac_test.go's
//     DB-down test.
//   - T579 (genuine data-driven rules): Allowed's only per-call state is the
//     four strings it is given and whatever rows currently exist in
//     ak_permission. Adding a row is the entire extension mechanism; see
//     rbac_test.go's paired-mutation proof, which shows a hardcoded
//     two-branch stand-in does NOT react to a newly inserted row while this
//     Engine does.
package rbac

import (
	"context"
	"database/sql"
	"errors"
	"strconv"
)

// ErrNoStore is returned by Allowed when constructed with a nil *sql.DB.
var ErrNoStore = errors.New("authkit/rbac: no database")

// Engine answers Allowed queries against a shared authkit permission store.
type Engine struct {
	db *sql.DB
}

// New builds an Engine reading from db. db is typically store.Store.DB() from
// a *store.Store this package's caller already opened; Engine takes the raw
// handle (rather than importing pkg/store) so it depends on nothing but
// database/sql.
func New(db *sql.DB) *Engine {
	return &Engine{db: db}
}

// Allowed reports whether userID may perform action on resource within
// module. It is DEFAULT-DENY: the absence of a matching row — including a
// user who holds no role at all — is (false, nil), not an error and not an
// implicit grant. A database error of any kind is (false, err): this method
// never returns true unless it positively read a matching row.
//
// The check is: does ak_permission contain a row for
//   - ('user', userID, module, resource, action), OR
//   - ('role', r, module, resource, action) for some role r the user
//     currently holds via ak_user_role
//
// Both are read fresh on every call — there is no cache to invalidate and no
// compiled roster to fall out of sync with the data.
func (e *Engine) Allowed(ctx context.Context, userID, module, resource, action string) (bool, error) {
	if e == nil || e.db == nil {
		return false, ErrNoStore
	}
	uid, err := strconv.ParseInt(userID, 10, 64)
	if err != nil {
		// A malformed id can never legitimately match a row. Treat it as a
		// request fault, not a grant — still default-deny.
		return false, nil
	}

	const q = `
		SELECT EXISTS (
			SELECT 1 FROM ak_permission
			WHERE subject_type = 'user' AND subject_id = ?
			  AND module = ? AND resource = ? AND action = ?
			UNION ALL
			SELECT 1 FROM ak_permission p
			JOIN ak_user_role ur ON ur.role_id = p.subject_id
			WHERE p.subject_type = 'role' AND ur.user_id = ?
			  AND p.module = ? AND p.resource = ? AND p.action = ?
		)`
	var allowed bool
	err = e.db.QueryRowContext(ctx, q, uid, module, resource, action, uid, module, resource, action).Scan(&allowed)
	if err != nil {
		// Fail closed: whatever the failure (closed DB, network-backed
		// SQLite VFS unreachable, context cancellation, a malformed driver
		// response), the answer is deny. Never propagate a partial/garbage
		// scan as an allow.
		return false, err
	}
	return allowed, nil
}
