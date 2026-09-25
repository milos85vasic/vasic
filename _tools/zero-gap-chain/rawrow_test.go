package main

import (
	"bytes"
	"os"
	"os/exec"
	"path/filepath"
	"testing"
)

// A row exactly as execution_record.sh's printf emits it.
const strictRow = `{"ts":"2026-09-25T10:00:00Z","cwd":"/srv/zg-fixture","command":"/bin/sh -c exit 0","argv":["/bin/sh","-c","exit 0"],"exit_status":"0","duration_ms":"12","stdout_digest":"e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855","stderr_digest":"e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855","stdout_bytes":"0","stderr_bytes":"0","stream_ref":"/srv/zg-fixture/streams/20260925T100000Z_1","stream_truncated":"false","stream_redacted":"false"}`

func TestParseRecorderRow_StrictRow(t *testing.T) {
	f, err := ParseRecorderRow([]byte(strictRow))
	if err != nil {
		t.Fatalf("parse: %v", err)
	}
	if f.Ts != "2026-09-25T10:00:00Z" || f.ExitStatus != "0" || f.DurationMs != 12 ||
		f.StdoutBytes != 0 || f.StreamRef != "/srv/zg-fixture/streams/20260925T100000Z_1" ||
		f.Truncated || f.Redacted || !f.StrictJSON {
		t.Fatalf("fields wrong: %+v", f)
	}
}

// The recorder writes `command` as "$*" UNESCAPED, so any argv holding a double
// quote yields a row that is not JSON. The fixed-format fields are still
// recoverable and MUST be, or every such command would be unrecordable.
func TestParseRecorderRow_UnescapedQuoteStillParsesFixedFields(t *testing.T) {
	row := bytes.Replace([]byte(strictRow), []byte(`"command":"/bin/sh -c exit 0"`),
		[]byte(`"command":"/bin/sh -c echo "hi""`), 1)
	f, err := ParseRecorderRow(row)
	if err != nil {
		t.Fatalf("parse: %v", err)
	}
	if f.StrictJSON {
		t.Fatal("an invalid-JSON row was reported as strict JSON")
	}
	if f.ExitStatus != "0" || f.DurationMs != 12 || f.Ts != "2026-09-25T10:00:00Z" {
		t.Fatalf("fixed fields not recovered: %+v", f)
	}
}

func TestParseRecorderRow_RefusesUnknownShape(t *testing.T) {
	for _, bad := range []string{
		``,
		`garbage`,
		`{"ts":"2026-09-25T10:00:00Z"}`,
		// digest not 64 hex: the fixed format moved or was forged
		bytes.NewBuffer(bytes.Replace([]byte(strictRow), []byte(`"stdout_digest":"e3b0`), []byte(`"stdout_digest":"XXb0`), 1)).String(),
		// truncated flag outside the closed set
		bytes.NewBuffer(bytes.Replace([]byte(strictRow), []byte(`"stream_truncated":"false"`), []byte(`"stream_truncated":"maybe"`), 1)).String(),
	} {
		if _, err := ParseRecorderRow([]byte(bad)); err == nil {
			t.Fatalf("accepted a row that is not the recorder's format: %q", bad)
		}
	}
}

// Drive the REAL constitution recorder and parse what it wrote — the parser is
// tested against the producer, not against a string we typed.
func TestParseRecorderRow_RealRecorder(t *testing.T) {
	bash, err := exec.LookPath("bash")
	if err != nil {
		t.Skip("bash absent: the real recorder cannot be driven (honest skip, not a pass)")
	}
	lib, err := filepath.Abs("../../submodules/constitution/scripts/gates/lib/execution_record.sh")
	if err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(lib); err != nil {
		t.Fatalf("recorder library absent at %s: %v", lib, err)
	}
	tmp := t.TempDir()
	rec := filepath.Join(tmp, "rec.jsonl")
	script := `. "$1"; exec_record_run "$2" "$3" -- /bin/sh -c 'printf hello; echo "q\"uote" >&2; exit 3'; exit 0`
	cmd := exec.Command(bash, "-c", script, "x", lib, rec, filepath.Join(tmp, "streams"))
	if out, err := cmd.CombinedOutput(); err != nil {
		t.Fatalf("recorder run failed: %v\n%s", err, out)
	}
	b, err := os.ReadFile(rec)
	if err != nil {
		t.Fatal(err)
	}
	f, err := ParseRecorderRow(bytes.TrimRight(b, "\n"))
	if err != nil {
		t.Fatalf("parse real row: %v\n%s", err, b)
	}
	if f.ExitStatus != "3" || f.StdoutBytes != 5 {
		t.Fatalf("real row mis-parsed: %+v", f)
	}
	if f.StdoutDigest != hex64("hello") {
		t.Fatalf("stdout digest %s is not sha256(hello)", f.StdoutDigest)
	}
}

// The recorder writes `command` as "$*" UNESCAPED, so an argument carrying a
// newline splits ONE row across two physical lines (found by the adapter's E8
// proof case). The fixed-format fields must still be recovered.
func TestParseRecorderRow_RowSpanningLines(t *testing.T) {
	row := bytes.Replace([]byte(strictRow), []byte(`"command":"/bin/sh -c exit 0"`),
		[]byte("\"command\":\"/bin/sh -c exit 0 e\nf\""), 1)
	f, err := ParseRecorderRow(row)
	if err != nil {
		t.Fatalf("parse: %v", err)
	}
	if f.StrictJSON || f.ExitStatus != "0" || f.StreamRef != "/srv/zg-fixture/streams/20260925T100000Z_1" {
		t.Fatalf("fields wrong: %+v", f)
	}
}

// cmdAppend must accept such a row from its --raw-row file.
func TestCmdAppend_AcceptsRowSpanningLines(t *testing.T) {
	dir := t.TempDir()
	row := bytes.Replace([]byte(strictRow), []byte(`"command":"/bin/sh -c exit 0"`),
		[]byte("\"command\":\"/bin/sh -c exit 0 e\nf\""), 1)
	rf := filepath.Join(dir, "row")
	if err := os.WriteFile(rf, append(row, '\n'), 0o600); err != nil {
		t.Fatal(err)
	}
	var out, errb bytes.Buffer
	rc := run([]string{"append", "--store", filepath.Join(dir, "s"), "--schema", schemaPath,
		"--session", "s", "--cwd", "/srv/zg-fixture", "--raw-row", rf, "--stream-ref", "/srv/zg-fixture/streams/x",
		"--item-id", "ATM-001", "--check-id", "c", "--population-kind", "source", "--verdict-role", "author",
		"--independence-tier", "instance", "--evidence-class", "runtime", "--fp-before", hex64("a"),
		"--fp-after", hex64("a"), "--check-verdict", "0", "--", "/bin/sh", "-c", "exit 0", "e\nf"}, &out, &errb)
	if rc != 0 {
		t.Fatalf("rc=%d stderr=%s", rc, errb.String())
	}
}
