package main

import "testing"

// T058: tests added because the umbrella mutation proof (scripts/prove-umbrella-mutants.sh)
// found two mutants of this module that NO pre-existing test killed (MG3, MG5).

// MG3: yamlQuote must escape backslashes before quotes, or a title ending in a backslash
// closes the YAML scalar early and corrupts the Jekyll front matter.
func TestYamlQuoteEscapesBackslashAndQuote(t *testing.T) {
	cases := []struct{ in, want string }{
		{`plain`, `"plain"`},
		{`say "hi"`, `"say \"hi\""`},
		{`back\slash`, `"back\\slash"`},
		{`ends\`, `"ends\\"`},
		{`\"`, `"\\\""`},
	}
	for _, c := range cases {
		if got := yamlQuote(c.in); got != c.want {
			t.Errorf("yamlQuote(%q) = %s, want %s", c.in, got, c.want)
		}
	}
}

// MG5: a key missing from a language's dictionary must degrade to the English source string
// (never to the raw key while English exists), and an unknown language must do the same.
func TestTFallsBackToEnglishThenKey(t *testing.T) {
	var key, en string
	for k, v := range uiDict["en"] {
		if v != "" && v != k {
			key, en = k, v
			break
		}
	}
	if key == "" {
		t.Fatal("no English UI string with a value distinct from its key to test the fallback with")
	}
	if got := T("zz-no-such-language", key); got != en {
		t.Errorf("unknown language: T = %q, want the English %q", got, en)
	}
	if got := T("zz-no-such-language", "no.such.key.anywhere"); got != "no.such.key.anywhere" {
		t.Errorf("unknown key must echo the key, got %q", got)
	}
}
