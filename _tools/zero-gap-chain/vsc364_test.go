package main

import "testing"

// VSC-364 (T014 N1, N2): percent-encoded names and five credential-name shapes.
func TestVSC364_PercentEncodedAndAuthShapesRefused(t *testing.T) {
	cases := map[string][]string{
		"pct query key": {"curl", "https://h.invalid/x?%74oken=PLACEHOLDER"},
		"pct double":    {"curl", "https://h.invalid/x?%2574oken=PLACEHOLDER"},
		"pct flag":      {"tool", "--%70assword", "PLACEHOLDER"},
		"flag auth":     {"tool", "--auth", "PLACEHOLDER"},
		"flag creds":    {"tool", "--creds", "PLACEHOLDER"},
		"flag pat":      {"tool", "--pat", "PLACEHOLDER"},
		"env NPM_AUTH":  {"env", "NPM_AUTH=PLACEHOLDER", "tool"},
		"header X-Auth": {"curl", "-H", "X-Auth: PLACEHOLDER", "https://h.invalid"},
	}
	for name, argv := range cases {
		if refused, _ := ArgvPolicy(argv); !refused {
			t.Errorf("%s: %q was not refused", name, argv)
		}
	}
}

func TestVSC364_ControlsStillAllowed(t *testing.T) {
	for _, argv := range [][]string{
		{"git", "log", "--author=someone"},
		{"curl", "https://h.invalid/x?q=100%25&page=2"},
		{"ls", "-la"},
		{"go", "test", "./..."},
	} {
		if refused, why := ArgvPolicy(argv); refused {
			t.Errorf("%q wrongly refused: %s", argv, why)
		}
	}
}

func TestVSC364_RedactURLDecodesNames(t *testing.T) {
	got := redactURL("https://h.invalid/x?%74oken=PLACEHOLDER&a=1")
	want := "https://h.invalid/x?%74oken=<redacted>&a=1"
	if got != want {
		t.Errorf("got %q want %q", got, want)
	}
}
