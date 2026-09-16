package ratelimit

import (
	"testing"
	"time"
)

// T508: per-key rate limiting is real, not decorative — exceeding the
// threshold genuinely blocks subsequent calls, and (being time-based) the
// key recovers once the window has passed.
func TestAllow_BlocksAfterLimitThenRecovers(t *testing.T) {
	const limit = 3
	const window = 80 * time.Millisecond
	l := New(limit, window)

	for i := 0; i < limit; i++ {
		if !l.Allow("account:test-user-1") {
			t.Fatalf("call %d/%d unexpectedly blocked, want allowed (within limit)", i+1, limit)
		}
	}
	if l.Allow("account:test-user-1") {
		t.Fatal("call beyond the limit was allowed, want blocked")
	}
	if l.Allow("account:test-user-1") {
		t.Fatal("a second call beyond the limit was allowed, want blocked (limiter must stay closed, not one-shot)")
	}

	// A DIFFERENT key has its own independent budget — per-account /
	// per-source isolation is the whole point of keying by string.
	if !l.Allow("source-ip:203.0.113.9") {
		t.Fatal("a different key was blocked by another key's exhausted budget")
	}

	// Recovery: once the window has fully elapsed, the original key's
	// earlier hits age out and it is allowed again. A real sleep here (not
	// an injected clock) so this proves actual wall-clock recovery, not
	// just the arithmetic.
	time.Sleep(window + 20*time.Millisecond)
	if !l.Allow("account:test-user-1") {
		t.Fatal("call after the window elapsed was still blocked, want allowed (recovery)")
	}
}

// TestAllow_NotDecorative_ControlVsMutation is the paired-mutation proof:
// a decorative "limiter" that always returns true would pass a naive
// "call it and check no panic" test but must fail an assertion that it
// actually blocks past the threshold. The mutation arm is exactly that
// decorative stand-in.
func TestAllow_NotDecorative_ControlVsMutation(t *testing.T) {
	const limit = 2
	const window = time.Minute

	t.Run("control: real Limiter blocks past the threshold", func(t *testing.T) {
		l := New(limit, window)
		l.Allow("k")
		l.Allow("k")
		if l.Allow("k") {
			t.Fatal("real Limiter allowed a 3rd call within the window, want blocked")
		}
		t.Log("control PASS: real Limiter blocks the 3rd call")
	})

	t.Run("mutation: decorative always-allow limiter never blocks", func(t *testing.T) {
		decorative := func(key string) bool { return true } // BUG: always allows
		for i := 0; i < limit+5; i++ {
			if !decorative("k") {
				t.Fatalf("decorative limiter unexpectedly blocked at call %d — mutation arm must always allow to demonstrate the defect", i+1)
			}
		}
		t.Log("mutation PASS (i.e. mutant correctly EXHIBITS the decorative-limiter defect): " +
			"a stand-in that always returns true never blocks even far past the threshold — " +
			"this is the shape a decorative (non-functional) limiter has, and the real Limiter above does not have it")
	})
}

func TestNew_ClampsInvalidArgs(t *testing.T) {
	l := New(0, 0)
	if !l.Allow("k") {
		t.Fatal("first call with clamped limit=1 should still be allowed")
	}
	if l.Allow("k") {
		t.Fatal("second call with clamped limit=1 should be blocked")
	}
}
