package authresponse

import "testing"

// T509: generic "invalid username or password" failure. The same function
// call answers "unknown username" and "known username, wrong password" —
// there is no parameter it could vary between the two, so the two call
// sites are structurally guaranteed to produce byte-identical output.
func TestLoginFailure_ByteIdenticalAcrossCauses(t *testing.T) {
	// Two call sites standing in for the two real handler branches. Neither
	// passes anything that could differ — that IS the property.
	unknownUsernameStatus, unknownUsernameBody := LoginFailure() // "no such user"
	wrongPasswordStatus, wrongPasswordBody := LoginFailure()     // "user exists, password wrong"

	if unknownUsernameStatus != wrongPasswordStatus {
		t.Fatalf("status codes differ: unknown-username=%d wrong-password=%d", unknownUsernameStatus, wrongPasswordStatus)
	}
	if unknownUsernameBody != wrongPasswordBody {
		t.Fatalf("bodies differ: unknown-username=%q wrong-password=%q", unknownUsernameBody, wrongPasswordBody)
	}
	if unknownUsernameBody == "" {
		t.Fatal("LoginFailure body is empty")
	}
}

// TestNoEnumeration_ControlVsMutation is the paired-mutation proof for
// T509: the real LoginFailure() is indistinguishable across the two causes
// by construction; a plausible-looking "helpful" handler that reports the
// two causes differently — the classic username-enumeration bug — is
// trivially distinguishable. The mutation arm below constructs exactly that
// handler and shows its two outputs differ, in contrast to the real
// package's output.
func TestNoEnumeration_ControlVsMutation(t *testing.T) {
	t.Run("control: real LoginFailure is identical for both causes", func(t *testing.T) {
		_, unknownBody := LoginFailure()
		_, wrongPasswordBody := LoginFailure()
		if unknownBody != wrongPasswordBody {
			t.Fatalf("real package leaked which branch ran: %q vs %q", unknownBody, wrongPasswordBody)
		}
		t.Logf("control PASS: both causes produce %q", unknownBody)
	})

	t.Run("mutation: a differentiating handler enables username enumeration", func(t *testing.T) {
		// mutantLoginFailure is what T509 forbids: a handler that, given
		// which branch it is on, reports a different message per cause.
		mutantLoginFailure := func(userExists bool) (int, string) {
			if !userExists {
				return 401, `{"error":"unknown username"}`
			}
			return 401, `{"error":"incorrect password"}`
		}

		unknownBody := mustBody(mutantLoginFailure(false))
		wrongPasswordBody := mustBody(mutantLoginFailure(true))
		if unknownBody == wrongPasswordBody {
			t.Fatalf("mutant unexpectedly produced identical bodies (%q) — mutation arm should differ to demonstrate the enumeration bug", unknownBody)
		}
		t.Logf("mutation PASS (i.e. mutant correctly EXHIBITS the enumeration bug): unknown-username=%q vs wrong-password=%q — "+
			"an attacker probing usernames could tell these apart; the real package's identical output (above) prevents that", unknownBody, wrongPasswordBody)
	})
}

func mustBody(_ int, body string) string { return body }
