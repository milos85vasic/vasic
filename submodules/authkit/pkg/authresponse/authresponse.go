// Package authresponse gives every consumer ONE way to answer a failed
// login, so "unknown username" and "known username, wrong password" are
// byte-for-byte indistinguishable to whoever is asking (T509: no username
// enumeration).
//
// The defense is structural, not a matter of remembering to word two
// messages the same: LoginFailure takes NO argument that could vary between
// the two cases, so there is no way to construct a caller that accidentally
// leaks which branch it took. A handler that wanted to differentiate would
// have to bypass this package entirely and write its own response — which is
// exactly the failure mode authresponse_test.go's mutation arm constructs
// and shows is byte-distinguishable, in contrast to this package's output.
package authresponse

// StatusCode is the HTTP status LoginFailure's response is meant to be sent
// with. It is exported as data (not hardcoded into every caller) so a
// consumer's HTTP layer can set it without this package importing net/http.
const StatusCode = 401

// Body is the fixed response body LoginFailure returns for every failed
// login, regardless of cause.
const Body = `{"error":"invalid username or password"}`

// LoginFailure returns the status code and body a caller should send back
// for ANY failed login — unknown username, wrong password, disabled
// account, or any other reason authentication did not succeed. It accepts
// no parameter describing why, on purpose: there is nothing in its call
// signature a caller could vary, so two call sites handling the two
// different failure causes are guaranteed, by construction, to produce an
// identical response.
func LoginFailure() (statusCode int, body string) {
	return StatusCode, Body
}
