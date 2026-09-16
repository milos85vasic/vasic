// Package session implements login session lifecycle (T505) and
// audience-scoped bearer tokens (T506) on top of the ak_session /
// ak_cutover tables pkg/store defines.
//
// Two independent properties are load-bearing here, each with its own test
// in session_test.go:
//
//   - Session-fixation protection (T505): Login NEVER accepts, reuses or
//     extends an existing session id. Its only input is the authenticated
//     userID; its only output path for a session id is "generate 32 random
//     bytes right now." A pre-authentication session id an attacker fixed
//     into a victim's browser therefore cannot become the authenticated
//     session — there is no code path through which it could.
//   - Audience scoping (T506): a token minted with Mint(sid, "workshop") is
//     rejected by Validate(token, "ai_interviewing") even though both
//     modules read the SAME underlying user/session store. The audience is
//     part of the signed payload, so a module cannot be tricked into
//     accepting a token minted for a different module by any means short of
//     forging the HMAC.
//
// T507 (fail-closed): Validate's database lookups (session revocation, the
// global cutover) return (Claims{}, err) on any database error — the same
// contract pkg/rbac.Engine.Allowed uses. A token is never accepted on the
// strength of a failed check.
package session

import (
	"context"
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"database/sql"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"strconv"
	"strings"
	"time"
)

// ErrInvalidToken covers every reason a token is rejected except an audience
// mismatch: bad encoding, bad signature, unknown/revoked session, or a token
// issued before the configured cutover.
var ErrInvalidToken = errors.New("authkit/session: invalid or expired token")

// ErrAudienceMismatch is returned by Validate specifically when the token's
// signature and session are otherwise valid but its audience claim does not
// equal the audience the caller asked to validate against (T506).
var ErrAudienceMismatch = errors.New("authkit/session: token audience does not match")

// MinSecretLen is the minimum accepted length, in bytes, of the HMAC signing
// secret. 32 bytes (256 bits) matches the security margin SHA-256 itself
// provides; accepting anything weaker would make the signature the weak
// link instead of the algorithm.
const MinSecretLen = 32

// Claims is what a successfully validated token proves.
type Claims struct {
	SessionID string
	Audience  string
	IssuedAt  time.Time
}

// Manager issues and validates sessions and tokens against a shared authkit
// database.
type Manager struct {
	db     *sql.DB
	secret []byte
}

// NewManager builds a Manager reading/writing db (typically
// store.Store.DB()) and signing tokens with secret, which every module that
// must accept each other's tokens has to configure identically — it is the
// shared trust root. NewManager refuses a secret shorter than MinSecretLen.
func NewManager(db *sql.DB, secret []byte) (*Manager, error) {
	if len(secret) < MinSecretLen {
		return nil, fmt.Errorf("authkit/session: secret must be at least %d bytes, got %d", MinSecretLen, len(secret))
	}
	cp := make([]byte, len(secret))
	copy(cp, secret)
	return &Manager{db: db, secret: cp}, nil
}

// Login records a brand-new, cryptographically random session id for userID
// and returns it. It is the ENTIRE session-fixation defense: the function
// takes no session id as input, anywhere, so there is no parameter through
// which a pre-authentication id could flow into the authenticated session.
// Every call — including a second Login for the same user — mints a fresh
// id; nothing is ever extended or renewed in place.
func (m *Manager) Login(ctx context.Context, userID string) (sessionID string, err error) {
	uid, err := strconv.ParseInt(userID, 10, 64)
	if err != nil {
		return "", fmt.Errorf("authkit/session: invalid user id %q: %w", userID, err)
	}
	sid, err := randomID()
	if err != nil {
		return "", err
	}
	now := time.Now().UTC().Format(time.RFC3339Nano)
	if _, err := m.db.ExecContext(ctx, `INSERT INTO ak_session(id, user_id, created_at) VALUES(?,?,?)`, sid, uid, now); err != nil {
		return "", err
	}
	return sid, nil
}

// Invalidate revokes a single session (logout). Validating a token bound to
// an invalidated session subsequently fails, regardless of the token's own
// expiry.
func (m *Manager) Invalidate(ctx context.Context, sessionID string) error {
	now := time.Now().UTC().Format(time.RFC3339Nano)
	_, err := m.db.ExecContext(ctx, `UPDATE ak_session SET revoked_at = ? WHERE id = ? AND revoked_at IS NULL`, now, sessionID)
	return err
}

// InvalidateAllBefore sets the global cutover: any token whose issued-at
// timestamp predates cutoff is rejected by Validate from this call onward,
// regardless of that token's individual session state. This is the
// mass-invalidation primitive a credential-rotation or security-incident
// cutover needs — logging out every session ever issued without having to
// enumerate and revoke each ak_session row individually.
func (m *Manager) InvalidateAllBefore(ctx context.Context, cutoff time.Time) error {
	_, err := m.db.ExecContext(ctx, `
		INSERT INTO ak_cutover(id, min_valid_issued_at) VALUES(1, ?)
		ON CONFLICT(id) DO UPDATE SET min_valid_issued_at = excluded.min_valid_issued_at`,
		cutoff.UTC().Format(time.RFC3339Nano))
	return err
}

// Mint signs an audience-scoped bearer token for an already-issued session
// id. It performs no database access: the token is a self-contained,
// HMAC-SHA256-signed claim set (sessionID, audience, issued-at), verified
// the same way by every module that shares the signing secret.
func (m *Manager) Mint(sessionID, audience string) (token string, err error) {
	p := payload{Sub: sessionID, Aud: audience, Iat: time.Now().UTC().Unix()}
	raw, err := json.Marshal(p)
	if err != nil {
		return "", err
	}
	body := base64.RawURLEncoding.EncodeToString(raw)
	mac := m.sign(body)
	return body + "." + base64.RawURLEncoding.EncodeToString(mac), nil
}

// Validate verifies token's signature, requires its audience claim to equal
// expectedAudience (T506), and requires its underlying session to still be
// valid: not revoked (Invalidate) and issued at or after the configured
// cutover (InvalidateAllBefore). Any database error while checking those two
// conditions is returned as-is with a zero Claims — never treated as
// success (T507).
func (m *Manager) Validate(ctx context.Context, token, expectedAudience string) (Claims, error) {
	body, mac, ok := splitToken(token)
	if !ok {
		return Claims{}, ErrInvalidToken
	}
	if !hmac.Equal(mac, m.sign(body)) {
		return Claims{}, ErrInvalidToken
	}
	raw, err := base64.RawURLEncoding.DecodeString(body)
	if err != nil {
		return Claims{}, ErrInvalidToken
	}
	var p payload
	if err := json.Unmarshal(raw, &p); err != nil {
		return Claims{}, ErrInvalidToken
	}

	// Audience check happens before any database access: a
	// wrong-audience token is rejected on the strength of its own claims,
	// with no dependence on store state.
	if p.Aud != expectedAudience {
		return Claims{}, ErrAudienceMismatch
	}

	var revokedAt sql.NullString
	err = m.db.QueryRowContext(ctx, `SELECT revoked_at FROM ak_session WHERE id = ?`, p.Sub).Scan(&revokedAt)
	if errors.Is(err, sql.ErrNoRows) {
		return Claims{}, ErrInvalidToken
	}
	if err != nil {
		// Fail closed: a database error is never treated as "no revocation
		// found" / accept.
		return Claims{}, err
	}
	if revokedAt.Valid {
		return Claims{}, ErrInvalidToken
	}

	var cutoverAt sql.NullString
	err = m.db.QueryRowContext(ctx, `SELECT min_valid_issued_at FROM ak_cutover WHERE id = 1`).Scan(&cutoverAt)
	if err != nil && !errors.Is(err, sql.ErrNoRows) {
		return Claims{}, err
	}
	issuedAt := time.Unix(p.Iat, 0).UTC()
	if cutoverAt.Valid {
		cutoff, err := time.Parse(time.RFC3339Nano, cutoverAt.String)
		if err != nil {
			return Claims{}, fmt.Errorf("authkit/session: corrupt cutover value: %w", err)
		}
		if issuedAt.Before(cutoff) {
			return Claims{}, ErrInvalidToken
		}
	}

	return Claims{SessionID: p.Sub, Audience: p.Aud, IssuedAt: issuedAt}, nil
}

func (m *Manager) sign(body string) []byte {
	h := hmac.New(sha256.New, m.secret)
	h.Write([]byte(body))
	return h.Sum(nil)
}

type payload struct {
	Sub string `json:"sub"`
	Aud string `json:"aud"`
	Iat int64  `json:"iat"`
}

func splitToken(token string) (body string, mac []byte, ok bool) {
	parts := strings.Split(token, ".")
	if len(parts) != 2 || parts[0] == "" || parts[1] == "" {
		return "", nil, false
	}
	decodedMac, err := base64.RawURLEncoding.DecodeString(parts[1])
	if err != nil {
		return "", nil, false
	}
	return parts[0], decodedMac, true
}

func randomID() (string, error) {
	buf := make([]byte, 32)
	if _, err := rand.Read(buf); err != nil {
		return "", err
	}
	return base64.RawURLEncoding.EncodeToString(buf), nil
}
