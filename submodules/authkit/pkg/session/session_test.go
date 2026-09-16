package session

import (
	"context"
	"path/filepath"
	"testing"
	"time"

	"github.com/vasic-digital/authkit/pkg/store"
)

const testSecret = "test-secret-not-real-32-bytes!!!" // exactly 32 bytes

func openManager(t *testing.T) (*store.Store, *Manager) {
	t.Helper()
	path := filepath.Join(t.TempDir(), "authkit-session-test.db")
	s, err := store.Open(path)
	if err != nil {
		t.Fatalf("store.Open: %v", err)
	}
	t.Cleanup(func() { _ = s.Close() })
	m, err := NewManager(s.DB(), []byte(testSecret))
	if err != nil {
		t.Fatalf("NewManager: %v", err)
	}
	return s, m
}

func mustUser(t *testing.T, s *store.Store, username string) string {
	t.Helper()
	uid, err := s.CreateUser(username, "hash")
	if err != nil {
		t.Fatalf("CreateUser: %v", err)
	}
	return uid
}

// T505: session-ID regeneration on login (session-fixation protection).
//
// Login's signature is Login(ctx, userID) — it takes no session id as
// input anywhere. That is the entire defense: there is no parameter through
// which a pre-authentication ("fixed") session id could flow into the
// authenticated session. This test proves it two ways: (1) two logins for
// the same user never produce the same id, and (2) an id an attacker might
// have fixed into a victim's cookie BEFORE login is never returned by, or
// valid after, Login — because Login never learns of it.
func TestLogin_SessionFixation_ControlVsMutation(t *testing.T) {
	s, m := openManager(t)
	ctx := context.Background()
	uid := mustUser(t, s, "test-user-fixation")

	// Simulate an attacker fixing a session id into the victim's browser
	// BEFORE authentication — the classic session-fixation setup. This
	// value is never given to Login; it exists only so the test can prove
	// it never comes back out of it.
	const preAuthID = "attacker-fixed-pre-auth-session-id"

	t.Run("control: real Login always mints fresh ids, never the pre-auth one", func(t *testing.T) {
		sid1, err := m.Login(ctx, uid)
		if err != nil {
			t.Fatalf("Login #1: %v", err)
		}
		sid2, err := m.Login(ctx, uid)
		if err != nil {
			t.Fatalf("Login #2: %v", err)
		}
		if sid1 == sid2 {
			t.Fatalf("two Login calls for the same user produced the SAME session id %q — not regenerating", sid1)
		}
		if sid1 == preAuthID || sid2 == preAuthID {
			t.Fatalf("Login returned the attacker-fixed pre-auth id %q — fixation succeeded", preAuthID)
		}
		// The pre-auth id was never inserted anywhere, so it must not
		// resolve to a valid session at all.
		tok, err := m.Mint(preAuthID, "any-module")
		if err != nil {
			t.Fatalf("Mint: %v", err)
		}
		if _, err := m.Validate(ctx, tok, "any-module"); err != ErrInvalidToken {
			t.Fatalf("Validate(token bound to never-issued pre-auth id) error = %v, want ErrInvalidToken", err)
		}
		t.Logf("control PASS: sid1=%s sid2=%s (both fresh, neither is the pre-auth id, pre-auth id is not a valid session)", sid1, sid2)
	})

	t.Run("mutation: a fixation-vulnerable Login stand-in reuses a hinted id", func(t *testing.T) {
		// mutantLogin is what T505 forbids: a Login that, given a
		// caller-supplied "existing session id hint", just reuses it
		// instead of always minting fresh. Real code with this shape is
		// exactly how a fixation vulnerability is introduced — e.g. "carry
		// the anonymous session through to the authenticated one for
		// convenience."
		mutantLogin := func(ctx context.Context, s *store.Store, userID, hintedExistingID string) (string, error) {
			if hintedExistingID != "" {
				return hintedExistingID, nil // BUG: reuses caller-supplied id
			}
			sid, err := randomID()
			if err != nil {
				return "", err
			}
			return sid, nil
		}

		got, err := mutantLogin(ctx, s, uid, preAuthID)
		if err != nil {
			t.Fatalf("mutantLogin: %v", err)
		}
		if got != preAuthID {
			t.Fatalf("mutant unexpectedly did not reuse the hinted id (got %q) — mutation arm should reuse it to demonstrate the vulnerability", got)
		}
		t.Logf("mutation PASS (i.e. mutant correctly EXHIBITS the fixation bug): mutantLogin returned the attacker-fixed id %q unchanged — this is what real Login must never do, and does not", got)
	})
}

// T506: audience-scoped tokens. A token minted for one module is rejected
// by a different module's validator, even though both read the same shared
// user/session store.
func TestMintValidate_AudienceScoping(t *testing.T) {
	s, m := openManager(t)
	ctx := context.Background()
	uid := mustUser(t, s, "test-user-audience")

	sid, err := m.Login(ctx, uid)
	if err != nil {
		t.Fatalf("Login: %v", err)
	}
	token, err := m.Mint(sid, "workshop")
	if err != nil {
		t.Fatalf("Mint: %v", err)
	}

	t.Run("correct audience validates", func(t *testing.T) {
		claims, err := m.Validate(ctx, token, "workshop")
		if err != nil {
			t.Fatalf("Validate(workshop token, workshop) = %v, want success", err)
		}
		if claims.SessionID != sid || claims.Audience != "workshop" {
			t.Fatalf("claims = %+v, want SessionID=%q Audience=workshop", claims, sid)
		}
	})

	t.Run("different module's validator rejects it", func(t *testing.T) {
		_, err := m.Validate(ctx, token, "ai_interviewing")
		if err != ErrAudienceMismatch {
			t.Fatalf("Validate(workshop token, ai_interviewing) error = %v, want ErrAudienceMismatch", err)
		}
	})
}

// T507: fail-closed when the store is unreachable. Control proves the token
// validates with the DB up; the broken-DB run proves the SAME token is
// rejected once the database is closed underneath the Manager.
func TestValidate_FailsClosedWhenDBDown(t *testing.T) {
	s, m := openManager(t)
	ctx := context.Background()
	uid := mustUser(t, s, "test-user-faildb")

	sid, err := m.Login(ctx, uid)
	if err != nil {
		t.Fatalf("Login: %v", err)
	}
	token, err := m.Mint(sid, "workshop")
	if err != nil {
		t.Fatalf("Mint: %v", err)
	}

	t.Run("control: DB up, token validates", func(t *testing.T) {
		if _, err := m.Validate(ctx, token, "workshop"); err != nil {
			t.Fatalf("Validate (DB up): unexpected error %v", err)
		}
		t.Log("control PASS: DB up, Validate succeeded")
	})

	if err := s.DB().Close(); err != nil {
		t.Fatalf("closing DB to simulate outage: %v", err)
	}

	t.Run("DB down: same token now rejected", func(t *testing.T) {
		claims, err := m.Validate(ctx, token, "workshop")
		if err == nil {
			t.Fatal("Validate (DB down) returned nil error, want a database error")
		}
		if claims != (Claims{}) {
			t.Fatalf("Validate (DB down) returned non-zero claims %+v, want zero value", claims)
		}
		t.Logf("DB-down PASS: Validate = (zero claims, %v) — same token, now rejected", err)
	})
}

func TestInvalidate_RevokesSession(t *testing.T) {
	s, m := openManager(t)
	ctx := context.Background()
	uid := mustUser(t, s, "test-user-logout")

	sid, err := m.Login(ctx, uid)
	if err != nil {
		t.Fatalf("Login: %v", err)
	}
	token, err := m.Mint(sid, "workshop")
	if err != nil {
		t.Fatalf("Mint: %v", err)
	}
	if _, err := m.Validate(ctx, token, "workshop"); err != nil {
		t.Fatalf("Validate before logout: %v", err)
	}
	if err := m.Invalidate(ctx, sid); err != nil {
		t.Fatalf("Invalidate: %v", err)
	}
	if _, err := m.Validate(ctx, token, "workshop"); err != ErrInvalidToken {
		t.Fatalf("Validate after logout: error = %v, want ErrInvalidToken", err)
	}
}

func TestInvalidateAllBefore_CutoverInvalidation(t *testing.T) {
	s, m := openManager(t)
	ctx := context.Background()
	uid := mustUser(t, s, "test-user-cutover")

	sid, err := m.Login(ctx, uid)
	if err != nil {
		t.Fatalf("Login: %v", err)
	}
	token, err := m.Mint(sid, "workshop")
	if err != nil {
		t.Fatalf("Mint: %v", err)
	}
	if _, err := m.Validate(ctx, token, "workshop"); err != nil {
		t.Fatalf("Validate before cutover: %v", err)
	}

	// Set the cutover to the future: every token issued so far (including
	// the one just minted) now predates it and must be rejected.
	if err := m.InvalidateAllBefore(ctx, time.Now().UTC().Add(time.Hour)); err != nil {
		t.Fatalf("InvalidateAllBefore: %v", err)
	}
	if _, err := m.Validate(ctx, token, "workshop"); err != ErrInvalidToken {
		t.Fatalf("Validate after cutover: error = %v, want ErrInvalidToken", err)
	}

	// A token minted AFTER the cutover is fine.
	newToken, err := m.Mint(sid, "workshop")
	if err != nil {
		t.Fatalf("Mint (post-cutover): %v", err)
	}
	// The session itself is still valid (never revoked); only tokens issued
	// before the cutover are rejected. Since the cutover is set an hour in
	// the future, a token minted "now" still predates it too — assert that
	// explicitly rather than assume it, so this test documents the real
	// boundary rather than a coincidence.
	if _, err := m.Validate(ctx, newToken, "workshop"); err != ErrInvalidToken {
		t.Fatalf("Validate (token minted before a future cutover) error = %v, want ErrInvalidToken", err)
	}
}

func TestNewManager_RejectsShortSecret(t *testing.T) {
	if _, err := NewManager(nil, []byte("too-short")); err == nil {
		t.Fatal("NewManager with a short secret succeeded, want an error")
	}
}
