package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"regexp"
	"strconv"
)

// RawFields are the fields the adapter takes from one row of the constitution
// recorder (submodules/constitution/scripts/gates/lib/execution_record.sh).
//
// argv and cwd are deliberately NOT taken from the row. The recorder writes
// `command` as "$*" unescaped and escapes argv for backslash, quote and newline
// only, so any command carrying a double quote or a tab produces a row that is
// not JSON at all (measured: TestParseRecorderRow_RealRecorder). The adapter
// already holds the exact argv bytes and the cwd it ran in, so those two come
// from the adapter, and only the recorder's fixed-format fields come from here.
type RawFields struct {
	Ts           string
	ExitStatus   string // the recorder's wire value; ToRecord parses it, never defaults it
	DurationMs   int64
	StdoutDigest string
	StderrDigest string
	StdoutBytes  int64
	StderrBytes  int64
	StreamRef    string
	Truncated    bool
	Redacted     bool
	StrictJSON   bool // whether the raw row was itself valid JSON (informational)
}

// The recorder's printf format is fixed from `exit_status` to the end of the
// row, and every value in that tail is digits, hex, true/false or a path the
// adapter chose — so the tail is parsed by an anchored pattern, and a row that
// does not match is REFUSED (the producer moved; guessing would be §11.4.6).
var (
	rawHead = regexp.MustCompile(`^\{"ts":"([0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z)","cwd":"`)
	rawTail = regexp.MustCompile(`,"exit_status":"([^"]*)","duration_ms":"([0-9]+)",` +
		`"stdout_digest":"([0-9a-f]{64})","stderr_digest":"([0-9a-f]{64})",` +
		`"stdout_bytes":"([0-9]+)","stderr_bytes":"([0-9]+)",` +
		`"stream_ref":"([^"\\]*)","stream_truncated":"(true|false)","stream_redacted":"(true|false)"\}$`)
)

var errRawRow = errors.New("recorder row is not in the execution_record.sh format")

// ParseRecorderRow extracts the fixed-format fields of one recorder row.
func ParseRecorderRow(line []byte) (RawFields, error) {
	h := rawHead.FindSubmatch(line)
	tl := rawTail.FindSubmatch(line)
	if h == nil || tl == nil {
		return RawFields{}, fmt.Errorf("%w: %.120q", errRawRow, line)
	}
	num := func(b []byte, what string) (int64, error) {
		n, err := strconv.ParseInt(string(b), 10, 64)
		if err != nil {
			return 0, fmt.Errorf("%w: %s %q: %v", errRawRow, what, b, err)
		}
		return n, nil
	}
	f := RawFields{
		Ts:           string(h[1]),
		ExitStatus:   string(tl[1]),
		StdoutDigest: string(tl[3]),
		StderrDigest: string(tl[4]),
		StreamRef:    string(tl[7]),
		Truncated:    string(tl[8]) == "true",
		Redacted:     string(tl[9]) == "true",
		StrictJSON:   json.Valid(line),
	}
	var err error
	if f.DurationMs, err = num(tl[2], "duration_ms"); err != nil {
		return RawFields{}, err
	}
	if f.StdoutBytes, err = num(tl[5], "stdout_bytes"); err != nil {
		return RawFields{}, err
	}
	if f.StderrBytes, err = num(tl[6], "stderr_bytes"); err != nil {
		return RawFields{}, err
	}
	return f, nil
}
