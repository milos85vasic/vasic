package store

import (
	"path/filepath"
	"testing"
)

func openTemp(t *testing.T) *Store {
	t.Helper()
	path := filepath.Join(t.TempDir(), "authkit-test.db")
	s, err := Open(path)
	if err != nil {
		t.Fatalf("Open: %v", err)
	}
	t.Cleanup(func() { _ = s.Close() })
	return s
}

// T488: schema + migrations produce a usable store: users, roles, role
// membership and grants all round-trip.
func TestOpen_MigratesAndSeedsUsable(t *testing.T) {
	s := openTemp(t)

	uid, err := s.CreateUser("test-user-1", "argon2id-fake-hash-for-test")
	if err != nil {
		t.Fatalf("CreateUser: %v", err)
	}
	if uid == "" {
		t.Fatal("CreateUser returned empty id")
	}

	gotID, hash, err := s.UserByUsername("test-user-1")
	if err != nil {
		t.Fatalf("UserByUsername: %v", err)
	}
	if gotID != uid || hash != "argon2id-fake-hash-for-test" {
		t.Fatalf("UserByUsername = (%q, %q), want (%q, %q)", gotID, hash, uid, "argon2id-fake-hash-for-test")
	}

	if _, _, err := s.UserByUsername("no-such-user"); err != ErrUserNotFound {
		t.Fatalf("UserByUsername(missing) error = %v, want ErrUserNotFound", err)
	}
}

func TestRoles_AssignAndRemove(t *testing.T) {
	s := openTemp(t)
	uid, err := s.CreateUser("test-user-2", "hash")
	if err != nil {
		t.Fatalf("CreateUser: %v", err)
	}
	if _, err := s.EnsureRole("admin"); err != nil {
		t.Fatalf("EnsureRole: %v", err)
	}
	if err := s.AssignRole(uid, "admin"); err != nil {
		t.Fatalf("AssignRole: %v", err)
	}
	if err := s.AssignRole(uid, "no-such-role"); err != ErrRoleNotFound {
		t.Fatalf("AssignRole(unknown role) error = %v, want ErrRoleNotFound", err)
	}
	if err := s.RemoveRole(uid, "admin"); err != nil {
		t.Fatalf("RemoveRole: %v", err)
	}
}

func TestGrantPermissions_RoundTrip(t *testing.T) {
	s := openTemp(t)
	if _, err := s.EnsureRole("user"); err != nil {
		t.Fatalf("EnsureRole: %v", err)
	}
	if err := s.GrantRolePermission("user", "workshop", "chapters", "read"); err != nil {
		t.Fatalf("GrantRolePermission: %v", err)
	}
	uid, err := s.CreateUser("test-user-3", "hash")
	if err != nil {
		t.Fatalf("CreateUser: %v", err)
	}
	if err := s.GrantUserPermission(uid, "ai_interviewing", "profile", "write"); err != nil {
		t.Fatalf("GrantUserPermission: %v", err)
	}

	var n int
	if err := s.DB().QueryRow(`SELECT COUNT(*) FROM ak_permission`).Scan(&n); err != nil {
		t.Fatalf("count permissions: %v", err)
	}
	if n != 2 {
		t.Fatalf("ak_permission has %d rows, want 2", n)
	}
}
