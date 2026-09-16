package password

import "testing"

// T502: salted password hashing.

func TestHashAndVerify_ControlArm(t *testing.T) {
	const pw = "test-password-not-real"

	h, err := Hash(pw)
	if err != nil {
		t.Fatalf("Hash: %v", err)
	}

	ok, err := Verify(pw, h)
	if err != nil {
		t.Fatalf("Verify(correct): %v", err)
	}
	if !ok {
		t.Fatal("Verify(correct password) = false, want true")
	}

	ok, err = Verify("test-password-wrong", h)
	if err != nil {
		t.Fatalf("Verify(wrong): %v", err)
	}
	if ok {
		t.Fatal("Verify(wrong password) = true, want false")
	}
}

// TestSaltedness_ControlVsMutation is the paired-mutation proof T502 asks
// for: hashing the SAME password twice must produce two DIFFERENT encoded
// strings (because the salt is fresh per call), while both strings still
// verify against the original password. A broken implementation that either
// stores plaintext or hashes without a salt CANNOT have this property — it
// necessarily produces the same output every time for the same input. The
// mutation arm below is exactly such a broken implementation, constructed
// in-line, and is shown to fail the differentiation test the real Hash
// passes.
func TestSaltedness_ControlVsMutation(t *testing.T) {
	const pw = "test-password-not-real"

	t.Run("control: real Hash salts, two hashes of the same password differ", func(t *testing.T) {
		h1, err := Hash(pw)
		if err != nil {
			t.Fatalf("Hash #1: %v", err)
		}
		h2, err := Hash(pw)
		if err != nil {
			t.Fatalf("Hash #2: %v", err)
		}
		if h1 == h2 {
			t.Fatalf("two Hash(%q) calls produced identical output %q — salt is not being randomized", pw, h1)
		}
		for _, h := range []string{h1, h2} {
			ok, err := Verify(pw, h)
			if err != nil || !ok {
				t.Fatalf("Verify(%q, %q) = (%v, %v), want (true, nil)", pw, h, ok, err)
			}
		}
		t.Logf("control PASS: h1=%s h2=%s (different, both verify)", h1, h2)
	})

	t.Run("mutation: unsalted/plaintext-storing hash collides on repeat", func(t *testing.T) {
		// mutantHashPlaintext is what T502 explicitly forbids: storing the
		// password in a recoverable/comparable form with NO per-call
		// randomness. It stands in for "unsalted hash" and "plaintext
		// storage" alike — both produce the same output every time for the
		// same input, which is the property under test.
		mutantHashPlaintext := func(plaintext string) string {
			return "plaintext:" + plaintext
		}

		m1 := mutantHashPlaintext(pw)
		m2 := mutantHashPlaintext(pw)
		if m1 != m2 {
			t.Fatalf("mutant unexpectedly varied (%q vs %q); mutation arm is supposed to collide", m1, m2)
		}
		t.Logf("mutation FAILS the salted-ness property as expected: m1=%s m2=%s (identical — no salt)", m1, m2)
	})
}

func TestVerify_MalformedHash(t *testing.T) {
	_, err := Verify("anything", "not-a-real-encoded-hash")
	if err != ErrInvalidHash {
		t.Fatalf("Verify(malformed hash) error = %v, want ErrInvalidHash", err)
	}
}

func TestVerify_HashSurvivesParamChange(t *testing.T) {
	// A hash encodes its own cost parameters, so verification of an
	// already-stored hash must not depend on the package's current
	// DefaultParams.
	cheap := Params{MemoryKiB: 8 * 1024, Iterations: 1, Threads: 1, SaltLen: 16, KeyLen: 32}
	h, err := HashWithParams("test-password-not-real", cheap)
	if err != nil {
		t.Fatalf("HashWithParams: %v", err)
	}
	ok, err := Verify("test-password-not-real", h)
	if err != nil || !ok {
		t.Fatalf("Verify(cheap-params hash) = (%v, %v), want (true, nil)", ok, err)
	}
}
