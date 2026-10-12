package wi

import (
	"encoding/json"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

// T057 fuzz targets for the umbrella workable-items validators. Run:
//   go test -run='^$' -fuzz=FuzzParseEvidenceRecord -fuzztime=20s ./internal/wi
// The seed corpus is also executed as ordinary tests by `go test`.

const fuzzGoodRecord = `{"ts":"2026-10-08T01:02:03Z","cwd":"/r","argv":["true"],"exit_status":0,"duration_ms":1,` +
	`"stdout_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",` +
	`"stderr_digest":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",` +
	`"stdout_bytes":0,"stderr_bytes":0,"stream_ref":"s","stream_truncated":false,"stream_redacted":false,` +
	`"item_id":"VSC-001","check_id":"c1",` +
	`"state_fingerprint_before":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc",` +
	`"state_fingerprint_after":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc",` +
	`"population_kind":"source","outcome":0,"verdict_role":"author","chain_seq":1,` +
	`"independence_tier":"t1","evidence_class":"e1"}`

// FuzzParseEvidenceRecord: never panics; an accepted record has no duplicate
// key (VSC-363: the last duplicate would silently win), a 0..2 outcome, a
// well-formed item id and a parsed timestamp; the control record is accepted;
// splicing a case-variant duplicate of ANY accepted key into it is refused.
func FuzzParseEvidenceRecord(f *testing.F) {
	f.Add([]byte(fuzzGoodRecord), "outcome")
	f.Add([]byte(fuzzGoodRecord+" x"), "ts")
	f.Add([]byte(`{"a":1,"A":2}`), "a")
	f.Add([]byte(`[]`), "")
	f.Add([]byte(""), "")
	f.Fuzz(func(t *testing.T, b []byte, key string) {
		if r, err := ParseEvidenceRecord(b); err == nil {
			if k, dup := firstDuplicateKey(b); dup {
				t.Fatalf("accepted a record with duplicate key %q: %s", k, b)
			}
			if *r.Outcome < 0 || *r.Outcome > 2 || !itemIDRe.MatchString(*r.ItemID) || r.time.IsZero() {
				t.Fatalf("accepted a malformed record: %s", b)
			}
		}
		// Duplicate-key injection into the known-good record.
		if key == "" || strings.ContainsAny(key, "\"\\") || !json.Valid([]byte(`"`+key+`"`)) {
			return
		}
		var m map[string]json.RawMessage
		if json.Unmarshal([]byte(fuzzGoodRecord), &m) != nil {
			t.Fatal("control record is not JSON")
		}
		if _, err := ParseEvidenceRecord([]byte(fuzzGoodRecord)); err != nil {
			t.Fatalf("control record refused: %v", err)
		}
		if _, ok := m[key]; !ok {
			return
		}
		dup := strings.TrimSuffix(fuzzGoodRecord, "}") + `,"` + strings.ToUpper(key) + `":0}`
		if _, err := ParseEvidenceRecord([]byte(dup)); err == nil {
			t.Fatalf("duplicate key %q (case-variant) accepted", key)
		}
	})
}

// FuzzConfine: a path Confine accepts never lies outside the root, an
// absolute path is never accepted, and a ".."-prefixed escape is refused.
func FuzzConfine(f *testing.F) {
	for _, s := range []string{"a/b", "../x", "a/../../x", "/etc/passwd", ".", "", "a//b", "..", "a/./b", "\x00", "a/..b"} {
		f.Add(s)
	}
	root := f.TempDir()
	f.Fuzz(func(t *testing.T, p string) {
		got, err := Confine(root, p)
		if err != nil {
			return
		}
		if filepath.IsAbs(p) {
			t.Fatalf("absolute path %q accepted -> %q", p, got)
		}
		if !within(root, got) {
			t.Fatalf("Confine(%q) = %q escapes root %q", p, got, root)
		}
	})
}

// FuzzParseAsOf: accepted values are exactly ten bytes, a real calendar date
// and returned unchanged; everything else errors without panicking.
func FuzzParseAsOf(f *testing.F) {
	for _, s := range []string{"2026-10-08", "2026-2-8", "2026-02-30", "", " 2026-10-08", "2026-10-08\n", "０２６-10-08", "2026-10-08T00:00:00Z"} {
		f.Add(s)
	}
	f.Fuzz(func(t *testing.T, s string) {
		got, err := ParseAsOf(s)
		if err != nil {
			if got != "" {
				t.Fatalf("error with non-empty value %q", got)
			}
			return
		}
		if got != s || len(s) != 10 || !validDate(s) {
			t.Fatalf("accepted %q -> %q", s, got)
		}
		if _, e := time.Parse("2006-01-02", s); e != nil {
			t.Fatalf("accepted unparseable %q", s)
		}
	})
}
