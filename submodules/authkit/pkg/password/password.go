// Package password hashes and verifies account passwords with Argon2id, the
// password-hashing function OWASP's current Password Storage Cheat Sheet
// recommends first (ahead of bcrypt/scrypt) when it is available, precisely
// because it won 2015's Password Hashing Competition against attacks that
// use custom ASIC/GPU hardware — a resistance bcrypt was never designed for.
// Go's golang.org/x/crypto/argon2 is the reference implementation's own
// team's Go port and is already a well-established dependency across the
// Go ecosystem.
//
// Covers T502: salted password hashing. There is no plaintext password
// column anywhere in this module (see pkg/store's schema) and no reversible
// encryption of a password — Hash produces a one-way digest; Verify never
// recovers the original plaintext, it recomputes and compares.
package password

import (
	"crypto/rand"
	"crypto/subtle"
	"encoding/base64"
	"errors"
	"fmt"
	"strings"

	"golang.org/x/crypto/argon2"
)

// Params are the Argon2id cost parameters. The defaults below follow OWASP's
// 2024 Password Storage Cheat Sheet "if much stronger hardware is not
// available" Argon2id recommendation: memory 19 MiB (19*1024 KiB), 2
// iterations, 1 degree of parallelism, a 16-byte salt and a 32-byte output.
// That is deliberately the OWASP entry tuned for a resource-constrained
// server rather than the "9 MiB / t=4" mobile-app row or the heavier
// dedicated-hardware rows — this module runs inside two ordinary application
// backends, not a dedicated auth appliance, and 19 MiB/hash keeps concurrent
// logins cheap while remaining far more GPU/ASIC-resistant than bcrypt at any
// cost bcrypt supports.
type Params struct {
	MemoryKiB  uint32 // Argon2 "m" parameter, in KiB.
	Iterations uint32 // Argon2 "t" parameter.
	Threads    uint8  // Argon2 "p" parameter.
	SaltLen    uint32
	KeyLen     uint32
}

// DefaultParams is OWASP's current Argon2id baseline recommendation, see the
// Params doc comment above.
var DefaultParams = Params{
	MemoryKiB:  19 * 1024,
	Iterations: 2,
	Threads:    1,
	SaltLen:    16,
	KeyLen:     32,
}

const encodingVersion = 19 // argon2.Version, pinned into the encoded string.

// ErrInvalidHash is returned by Verify when the stored hash is not in the
// format Hash produces (corrupt row, or a row from a different scheme
// entirely). It is a decode error, not a "password did not match" result —
// callers that conflate the two would turn a data problem into a silent
// permanent lockout with no diagnostic.
var ErrInvalidHash = errors.New("authkit/password: invalid encoded hash")

// Hash derives an Argon2id digest of plaintext under DefaultParams, using a
// fresh cryptographically random salt every call, and returns it encoded as
// a single self-describing string:
//
//	$argon2id$v=19$m=19456,t=2,p=1$<base64 salt>$<base64 key>
//
// Because the salt is random per call, hashing the SAME plaintext twice
// produces two DIFFERENT encoded strings — this is the property
// pkg/password's tests hold as the load-bearing one, since an unsalted or
// plaintext-storing implementation cannot have it.
func Hash(plaintext string) (string, error) {
	return HashWithParams(plaintext, DefaultParams)
}

// HashWithParams is Hash with explicit cost parameters, for callers that
// need to tune cost (e.g. faster hashing in a test suite) without changing
// the module-wide default.
func HashWithParams(plaintext string, p Params) (string, error) {
	salt := make([]byte, p.SaltLen)
	if _, err := rand.Read(salt); err != nil {
		return "", fmt.Errorf("authkit/password: generating salt: %w", err)
	}
	key := argon2.IDKey([]byte(plaintext), salt, p.Iterations, p.MemoryKiB, p.Threads, p.KeyLen)
	encoded := fmt.Sprintf("$argon2id$v=%d$m=%d,t=%d,p=%d$%s$%s",
		encodingVersion, p.MemoryKiB, p.Iterations, p.Threads,
		base64.RawStdEncoding.EncodeToString(salt),
		base64.RawStdEncoding.EncodeToString(key))
	return encoded, nil
}

// Verify reports whether plaintext hashes (under the parameters ENCODED IN
// hash — not the caller's current DefaultParams, so a cost-parameter bump
// never breaks verification of already-stored hashes) to the same digest as
// hash. Comparison is constant-time.
//
// A malformed hash returns (false, ErrInvalidHash): callers that only check
// the bool still get "not authenticated", but the error lets an operator
// tell "wrong password" apart from "corrupt row" in a log.
func Verify(plaintext, hash string) (bool, error) {
	p, salt, key, err := decode(hash)
	if err != nil {
		return false, err
	}
	candidate := argon2.IDKey([]byte(plaintext), salt, p.Iterations, p.MemoryKiB, p.Threads, uint32(len(key)))
	return subtle.ConstantTimeCompare(candidate, key) == 1, nil
}

func decode(encoded string) (Params, []byte, []byte, error) {
	parts := strings.Split(encoded, "$")
	// "$argon2id$v=19$m=...,t=...,p=...$salt$key" splits into 6 fields, the
	// first ("") from the leading '$'.
	if len(parts) != 6 || parts[1] != "argon2id" {
		return Params{}, nil, nil, ErrInvalidHash
	}
	var version int
	if _, err := fmt.Sscanf(parts[2], "v=%d", &version); err != nil || version != encodingVersion {
		return Params{}, nil, nil, ErrInvalidHash
	}
	var p Params
	if _, err := fmt.Sscanf(parts[3], "m=%d,t=%d,p=%d", &p.MemoryKiB, &p.Iterations, &p.Threads); err != nil {
		return Params{}, nil, nil, ErrInvalidHash
	}
	salt, err := base64.RawStdEncoding.DecodeString(parts[4])
	if err != nil {
		return Params{}, nil, nil, ErrInvalidHash
	}
	key, err := base64.RawStdEncoding.DecodeString(parts[5])
	if err != nil {
		return Params{}, nil, nil, ErrInvalidHash
	}
	return p, salt, key, nil
}
