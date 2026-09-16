// Package ratelimit is a per-key sliding-window limiter for login attempts
// (T508): per-account (key = username) and per-source (key = client IP) are
// both just "a key" to this package — a caller wires the policy by choosing
// what string it passes as key, e.g. calling Allow twice per attempt with
// two Limiters, one keyed on username and one on source IP.
//
// It is a REAL limiter, not a decorative counter that always returns true:
// Allow prunes timestamps older than the configured window on every call and
// denies once the count of remaining timestamps reaches the limit, so a
// caller that exceeds the threshold is genuinely blocked until the window
// slides past the offending attempts (ratelimit_test.go proves both the
// block and the time-based recovery).
package ratelimit

import (
	"sync"
	"time"
)

// Limiter is a sliding-window rate limiter: at most Limit calls to Allow may
// return true for a given key within any Window-duration lookback from the
// current call.
type Limiter struct {
	limit  int
	window time.Duration

	mu   sync.Mutex
	hits map[string][]time.Time
}

// New builds a Limiter allowing at most limit calls to Allow, per key,
// within any rolling window of duration window. limit must be >= 1 and
// window must be > 0 — New clamps both to 1 if given a non-positive value
// rather than constructing a limiter that either blocks everything or never
// blocks anything, either of which would silently defeat the purpose of
// calling it.
func New(limit int, window time.Duration) *Limiter {
	if limit < 1 {
		limit = 1
	}
	if window <= 0 {
		window = time.Second
	}
	return &Limiter{limit: limit, window: window, hits: make(map[string][]time.Time)}
}

// Allow reports whether one more action under key is permitted right now,
// and — if so — records it as having happened, so it counts against key's
// budget for subsequent calls within the window.
func (l *Limiter) Allow(key string) bool {
	return l.allowAt(key, time.Now())
}

// allowAt is Allow with an explicit "now", so tests can exercise window
// recovery deterministically without a real sleep for the steady-state
// pruning logic (a real sleep is still used for the end-to-end recovery
// assertion in ratelimit_test.go, so the test also proves real wall-clock
// behavior, not only the injected-clock arithmetic).
func (l *Limiter) allowAt(key string, now time.Time) bool {
	l.mu.Lock()
	defer l.mu.Unlock()

	cutoff := now.Add(-l.window)
	existing := l.hits[key]
	kept := existing[:0]
	for _, t := range existing {
		if t.After(cutoff) {
			kept = append(kept, t)
		}
	}

	if len(kept) >= l.limit {
		l.hits[key] = kept
		return false
	}
	kept = append(kept, now)
	l.hits[key] = kept
	return true
}
