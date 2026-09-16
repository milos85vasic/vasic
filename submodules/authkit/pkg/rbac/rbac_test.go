package rbac

import (
	"context"
	"path/filepath"
	"testing"

	"github.com/vasic-digital/authkit/pkg/store"
)

func openTemp(t *testing.T) *store.Store {
	t.Helper()
	path := filepath.Join(t.TempDir(), "authkit-rbac-test.db")
	s, err := store.Open(path)
	if err != nil {
		t.Fatalf("store.Open: %v", err)
	}
	t.Cleanup(func() { _ = s.Close() })
	return s
}

// T511: a user with no role and no direct grant gets zero access — false,
// nil, never an error standing in for a decision and never an implicit
// grant.
func TestAllowed_RolelessUserDefaultDenies(t *testing.T) {
	s := openTemp(t)
	uid, err := s.CreateUser("test-user-roleless", "hash")
	if err != nil {
		t.Fatalf("CreateUser: %v", err)
	}
	e := New(s.DB())

	allowed, err := e.Allowed(context.Background(), uid, "workshop", "chapters", "read")
	if err != nil {
		t.Fatalf("Allowed returned an error for a roleless user, want (false, nil): %v", err)
	}
	if allowed {
		t.Fatal("Allowed(roleless user) = true, want false (default-deny)")
	}
}

// T507: fail-closed when the store is unreachable. The control run proves
// the same call would be ALLOWED with the database up; the broken-DB run
// proves it is DENIED once the database is closed underneath the Engine —
// never (true, err), always (false, err-or-nil-but-false).
func TestAllowed_FailsClosedWhenDBDown(t *testing.T) {
	s := openTemp(t)
	uid, err := s.CreateUser("test-user-failclosed", "hash")
	if err != nil {
		t.Fatalf("CreateUser: %v", err)
	}
	if _, err := s.EnsureRole("admin"); err != nil {
		t.Fatalf("EnsureRole: %v", err)
	}
	if err := s.AssignRole(uid, "admin"); err != nil {
		t.Fatalf("AssignRole: %v", err)
	}
	if err := s.GrantRolePermission("admin", "workshop", "chapters", "read"); err != nil {
		t.Fatalf("GrantRolePermission: %v", err)
	}

	e := New(s.DB())

	t.Run("control: DB up, grant is honored", func(t *testing.T) {
		allowed, err := e.Allowed(context.Background(), uid, "workshop", "chapters", "read")
		if err != nil {
			t.Fatalf("Allowed (DB up): unexpected error %v", err)
		}
		if !allowed {
			t.Fatal("Allowed (DB up) = false, want true (the grant exists)")
		}
		t.Logf("control PASS: DB up, Allowed = true")
	})

	if err := s.DB().Close(); err != nil {
		t.Fatalf("closing DB to simulate outage: %v", err)
	}

	t.Run("DB down: same call now denies", func(t *testing.T) {
		allowed, err := e.Allowed(context.Background(), uid, "workshop", "chapters", "read")
		if err == nil {
			t.Fatal("Allowed (DB down) returned nil error, want a database error")
		}
		if allowed {
			t.Fatal("Allowed (DB down) = true, want false — must fail CLOSED, never open")
		}
		t.Logf("DB-down PASS: Allowed = (false, %v) — same grant, now denied", err)
	})
}

// T579: the permission model is a genuine (subject, module, resource,
// action) rule set read from the database at decision time, NOT a
// hardcoded two-user roster. This test seeds two users on two modules,
// proves their access, then adds a THIRD tuple as a pure data INSERT with
// zero code changes and shows it takes effect immediately — while a
// throwaway hardcoded two-branch stand-in (the mutation arm) does NOT react
// to the same new row.
func TestAllowed_T579_DataDrivenNotHardcoded(t *testing.T) {
	s := openTemp(t)

	u1, err := s.CreateUser("test-user-1", "hash1")
	if err != nil {
		t.Fatalf("CreateUser u1: %v", err)
	}
	u2, err := s.CreateUser("test-user-2", "hash2")
	if err != nil {
		t.Fatalf("CreateUser u2: %v", err)
	}
	u3, err := s.CreateUser("test-user-3", "hash3")
	if err != nil {
		t.Fatalf("CreateUser u3: %v", err)
	}

	if _, err := s.EnsureRole("role-a"); err != nil {
		t.Fatalf("EnsureRole role-a: %v", err)
	}
	if _, err := s.EnsureRole("role-b"); err != nil {
		t.Fatalf("EnsureRole role-b: %v", err)
	}
	if err := s.AssignRole(u1, "role-a"); err != nil {
		t.Fatalf("AssignRole u1/role-a: %v", err)
	}
	if err := s.AssignRole(u2, "role-b"); err != nil {
		t.Fatalf("AssignRole u2/role-b: %v", err)
	}
	// u1 -> module "moduleA" resource "docs" action "read"
	if err := s.GrantRolePermission("role-a", "moduleA", "docs", "read"); err != nil {
		t.Fatalf("grant role-a: %v", err)
	}
	// u2 -> module "moduleB" resource "reports" action "read"
	if err := s.GrantRolePermission("role-b", "moduleB", "reports", "read"); err != nil {
		t.Fatalf("grant role-b: %v", err)
	}

	e := New(s.DB())
	ctx := context.Background()

	assertAllowed := func(t *testing.T, userID, module, resource, action string, want bool) {
		t.Helper()
		got, err := e.Allowed(ctx, userID, module, resource, action)
		if err != nil {
			t.Fatalf("Allowed(%s,%s,%s,%s): %v", userID, module, resource, action, err)
		}
		if got != want {
			t.Fatalf("Allowed(%s,%s,%s,%s) = %v, want %v", userID, module, resource, action, got, want)
		}
	}

	// Baseline: each user has exactly the access granted to their own role,
	// and no access to the other module.
	t.Run("baseline before the third tuple", func(t *testing.T) {
		assertAllowed(t, u1, "moduleA", "docs", "read", true)
		assertAllowed(t, u1, "moduleB", "reports", "read", false)
		assertAllowed(t, u2, "moduleB", "reports", "read", true)
		assertAllowed(t, u2, "moduleA", "docs", "read", false)
		// u3 has no role and no grant at all yet.
		assertAllowed(t, u3, "moduleC", "settings", "write", false)
	})

	// The extension under test: a THIRD tuple, added as pure data — one
	// INSERT, via the same GrantUserPermission path any deployment would
	// use, no Go code anywhere touched or recompiled.
	if err := s.GrantUserPermission(u3, "moduleC", "settings", "write"); err != nil {
		t.Fatalf("GrantUserPermission u3 (the third tuple): %v", err)
	}

	t.Run("control: real Engine reacts to the new row with zero code changes", func(t *testing.T) {
		assertAllowed(t, u3, "moduleC", "settings", "write", true)
		// And the first two users' access is UNCHANGED by the new row.
		assertAllowed(t, u1, "moduleA", "docs", "read", true)
		assertAllowed(t, u1, "moduleB", "reports", "read", false)
		assertAllowed(t, u2, "moduleB", "reports", "read", true)
		assertAllowed(t, u2, "moduleA", "docs", "read", false)
		t.Log("control PASS: third tuple took effect via data alone; existing users' access unchanged")
	})

	t.Run("mutation: hardcoded two-user branch ignores the new row", func(t *testing.T) {
		// mutantAllowed is what T579 forbids: a permission "check" that is
		// really a compiled-in roster of exactly the two users/tuples this
		// test happened to seed FIRST, with no database read at all. It
		// stands in for the regression T579 exists to catch — someone
		// "simplifying" pkg/rbac into an if/else ladder instead of a table
		// read.
		mutantAllowed := func(userID, module, resource, action string) bool {
			switch {
			case userID == u1 && module == "moduleA" && resource == "docs" && action == "read":
				return true
			case userID == u2 && module == "moduleB" && resource == "reports" && action == "read":
				return true
			default:
				return false
			}
		}

		// The real engine allows the third tuple (proven above). The
		// hardcoded mutant, given the exact same inputs, does not — because
		// it never looks at ak_permission at all.
		if got := mutantAllowed(u3, "moduleC", "settings", "write"); got {
			t.Fatalf("mutant unexpectedly allowed the new tuple (got %v) — mutation arm should NOT react to new data, so this test would give no signal", got)
		}
		realGot, err := e.Allowed(ctx, u3, "moduleC", "settings", "write")
		if err != nil {
			t.Fatalf("real Engine.Allowed: %v", err)
		}
		if !realGot {
			t.Fatal("real Engine.Allowed(third tuple) = false, want true — cannot demonstrate the contrast")
		}
		t.Logf("mutation PASS (i.e. mutant correctly FAILS the extensibility property): "+
			"real Engine.Allowed(third tuple)=%v, mutantAllowed(third tuple)=false — "+
			"a hardcoded roster does not pick up a new data row; the real engine does", realGot)
	})
}
