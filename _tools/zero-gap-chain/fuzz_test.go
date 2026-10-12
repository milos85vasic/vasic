package main

import (
	"encoding/json"
	"fmt"
	"strings"
	"testing"
	"unicode/utf8"
)

// T057 fuzz targets for the zero-gap-chain parsers/validators. Run:
//   go test -run='^$' -fuzz=FuzzArgvPolicy -fuzztime=20s
// Each target states the INVARIANT it checks; the seed corpus doubles as a
// plain regression test under `go test`.

const plantedSecret = "ZQ9plantedvalueZQ9"

// FuzzArgvPolicy: the policy never panics, a refusal always carries a reason
// and an acceptance never does, a reason never echoes a value, appending an
// argument can never turn a refusal into an acceptance, and a planted
// password flag is refused no matter what precedes it.
func FuzzArgvPolicy(f *testing.F) {
	for _, s := range []string{
		"ls -la", "--password=hunter2", "-u admin:pw", "curl -H Authorization: x",
		"https://u:p@host/x", "DB_PASS=abc", "?access_token=Q", "%74oken=X", "bearer", "git@github.com:a/b.git",
	} {
		f.Add(s, "echo hi")
	}
	f.Fuzz(func(t *testing.T, a, b string) {
		base := []string{a, b}
		refused, reason := ArgvPolicy(base)
		if refused && reason == "" {
			t.Fatalf("refused with empty reason: %q", base)
		}
		if !refused && reason != "" {
			t.Fatalf("accepted with a reason %q: %q", reason, base)
		}
		if refused {
			if r2, _ := ArgvPolicy(append(append([]string{}, base...), "tail")); !r2 {
				t.Fatalf("appending an argument un-refused %q", base)
			}
		}
		planted := append(append([]string{}, base...), "--password="+plantedSecret)
		pr, why := ArgvPolicy(planted)
		if !pr {
			t.Fatalf("planted --password not refused after %q", base)
		}
		if strings.Contains(why, plantedSecret) {
			t.Fatalf("reason leaks the secret value: %q", why)
		}
	})
}

// FuzzNormalizeArg: normalisation never panics and always yields valid UTF-8
// (it feeds regexps and the folded-name tables), including for invalid input.
func FuzzNormalizeArg(f *testing.F) {
	for _, s := range []string{`\x77`, `$'pass'`, "%2574oken", `"a"'b'`, "\xff\xfe", `\U0001F600`, `\777`, "%", "%4"} {
		f.Add(s)
	}
	f.Fuzz(func(t *testing.T, s string) {
		out := normalizeArg(s)
		if !utf8.ValidString(out) {
			t.Fatalf("normalizeArg(%q) = %q is not valid UTF-8", s, out)
		}
	})
}

// FuzzParseRecorderRow: arbitrary bytes never panic; an accepted row yields
// the digest/number shapes the format promises; a row built from the fixed
// format round-trips field-for-field.
func FuzzParseRecorderRow(f *testing.F) {
	d := strings.Repeat("a", 64)
	good := fmt.Sprintf(`{"ts":"2026-10-08T01:02:03Z","cwd":"/x","argv":["a"],"exit_status":"0","duration_ms":"12","stdout_digest":"%s","stderr_digest":"%s","stdout_bytes":"3","stderr_bytes":"0","stream_ref":"p/q","stream_truncated":"false","stream_redacted":"true"}`, d, d)
	f.Add([]byte(good), int64(5), "0")
	f.Add([]byte(`{}`), int64(0), "")
	f.Add([]byte(""), int64(-1), "x")
	f.Fuzz(func(t *testing.T, line []byte, dur int64, exit string) {
		if fl, err := ParseRecorderRow(line); err == nil {
			if len(fl.StdoutDigest) != 64 || len(fl.StderrDigest) != 64 || fl.DurationMs < 0 || fl.StdoutBytes < 0 || fl.StderrBytes < 0 {
				t.Fatalf("accepted row with malformed fields: %+v", fl)
			}
		}
		if dur < 0 || strings.ContainsAny(exit, "\"\\\x00") || !utf8.ValidString(exit) {
			return
		}
		row := fmt.Sprintf(`{"ts":"2026-10-08T01:02:03Z","cwd":"/x","argv":["a"],"exit_status":"%s","duration_ms":"%d","stdout_digest":"%s","stderr_digest":"%s","stdout_bytes":"1","stderr_bytes":"2","stream_ref":"s","stream_truncated":"true","stream_redacted":"false"}`, exit, dur, d, d)
		fl, err := ParseRecorderRow([]byte(row))
		if err != nil {
			t.Fatalf("well-formed row refused: %v\n%s", err, row)
		}
		if fl.ExitStatus != exit || fl.DurationMs != dur || fl.StdoutBytes != 1 || fl.StderrBytes != 2 || !fl.Truncated || fl.Redacted {
			t.Fatalf("round trip lost a field: %+v", fl)
		}
	})
}

// FuzzMarshalSidecarLine: invalid UTF-8 is always refused (never silently
// replaced), a valid record marshals to a single compact JSON line whose argv
// round-trips byte-for-byte, and the artifact binding is sha256:<64 hex>.
func FuzzMarshalSidecarLine(f *testing.F) {
	f.Add("2026-10-08T00:00:00Z", "/cwd", "ls", "-la", "item-1")
	f.Add("ts", "cwd", "a\"b", "<&>", " ")
	f.Add("ts", "cwd", "\xff", "x", "id")
	f.Fuzz(func(t *testing.T, ts, cwd, a0, a1, item string) {
		s := Sidecar{Ts: ts, Cwd: cwd, Argv: []string{a0, a1}, ItemID: item}
		line, err := MarshalSidecarLine(s)
		allValid := utf8.ValidString(ts) && utf8.ValidString(cwd) && utf8.ValidString(a0) && utf8.ValidString(a1) && utf8.ValidString(item)
		if !allValid {
			if err == nil {
				t.Fatalf("invalid UTF-8 accepted: %q", line)
			}
			return
		}
		if err != nil {
			t.Fatalf("valid record refused: %v", err)
		}
		if strings.HasSuffix(string(line), "\n") || strings.Contains(string(line), "\n") {
			t.Fatalf("line contains a newline: %q", line)
		}
		var back Sidecar
		if err := json.Unmarshal(line, &back); err != nil {
			t.Fatalf("line is not JSON: %v", err)
		}
		if back.Argv[0] != a0 || back.Argv[1] != a1 || back.Cwd != cwd || back.ItemID != item {
			t.Fatalf("round trip altered a field: %+v", back)
		}
		ap := ArtifactPathFor(line)
		if len(ap) != len("sha256:")+64 || !strings.HasPrefix(ap, "sha256:") || ap != ArtifactPathFor(line) {
			t.Fatalf("bad artifact path %q", ap)
		}
	})
}
