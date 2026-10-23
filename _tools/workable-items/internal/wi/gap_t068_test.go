package wi

// Feature 010, task T068: chain-bound closure evidence (V-G13) and the
// write-time requirement on `gap close` / `gap verdict`.

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

type t068Rec struct {
	rel     string // path under the fixture root
	seq     int64
	session string
}

// t068Chain writes a chain.jsonl whose artifact_path binds each record file's bytes.
func t068Chain(t *testing.T, root string, recs []t068Rec) string {
	t.Helper()
	dir := t.TempDir()
	var lines []string
	for _, r := range recs {
		b, err := os.ReadFile(filepath.Join(root, r.rel))
		if err != nil {
			t.Fatal(err)
		}
		row, _ := json.Marshal(map[string]any{"seq": r.seq, "artifact_path": RecordDigest(b), "author_session_id": r.session})
		lines = append(lines, string(row))
	}
	if err := os.WriteFile(filepath.Join(dir, "chain.jsonl"), []byte(strings.Join(lines, "\n")+"\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	return dir
}

const evRel = fixtureRel + "/evidence/"

func t068Setup(t *testing.T) (root, db string) {
	t.Helper()
	return fixtureRoot(t, false), buildRegister(t, true, "golden-good.sql")
}

func t068Validate(t *testing.T, root, db string, b *ChainBinder) *Report {
	t.Helper()
	d := openFixture(t, db)
	rep, err := ValidateGap(d, GapOptions{AsOf: fixtureAsOf, Root: root, Roster: fixtureRoster(), Chain: b})
	if err != nil {
		t.Fatalf("ValidateGap: %v", err)
	}
	return rep
}

func t068Binder(t *testing.T, dir string, rc int) *ChainBinder {
	t.Helper()
	b, err := LoadChainBinder(dir)
	if err != nil {
		t.Fatal(err)
	}
	b.VerifyRC = rc
	return b
}

var t068Good = []t068Rec{
	{evRel + "VSC-004-red.json", 1, "sess-fixer"},
	{evRel + "VSC-004-green.json", 2, "sess-fixer"},
	{evRel + "VSC-004-verifier.json", 3, "sess-verifier"},
}

func TestT068BoundRecordsSatisfyVG13(t *testing.T) {
	root, db := t068Setup(t)
	rep := t068Validate(t, root, db, t068Binder(t, t068Chain(t, root, t068Good), 0))
	if hasGapFinding(rep, "V-G13", "") || len(rep.Undetermined) != 0 {
		t.Fatalf("a fully bound closure was flagged: %v %v", rep.Findings, rep.Undetermined)
	}
	if len(rep.Findings) != 0 {
		t.Fatalf("golden-good with a good chain is not clean: %v", rep.Findings)
	}
}

func TestT068NoChainMeansNoBindingRule(t *testing.T) {
	root, db := t068Setup(t)
	rep := t068Validate(t, root, db, nil)
	if hasGapFinding(rep, "V-G13", "") {
		t.Fatal("V-G13 fired without a chain (the rule is opt-in for validate)")
	}
}

func TestT068EditedRecordIsCaught(t *testing.T) {
	root, db := t068Setup(t)
	dir := t068Chain(t, root, t068Good)
	// a forged copy: the verifier record is edited AFTER it was sealed
	p := filepath.Join(root, evRel+"VSC-004-verifier.json")
	b, _ := os.ReadFile(p)
	if err := os.WriteFile(p, append(b, ' ', '\n'), 0o644); err != nil {
		t.Fatal(err)
	}
	rep := t068Validate(t, root, db, t068Binder(t, dir, 0))
	if !hasGapFinding(rep, "V-G13", "VSC-004") {
		t.Fatalf("an edited verifier record was not caught by the chain binding: %v", rep.Findings)
	}
}

func TestT068RecordMissingFromChainIsCaught(t *testing.T) {
	root, db := t068Setup(t)
	rep := t068Validate(t, root, db, t068Binder(t, t068Chain(t, root, t068Good[:2]), 0))
	if !hasGapFinding(rep, "V-G13", "VSC-004") {
		t.Fatalf("a verifier record with no chain row was accepted: %v", rep.Findings)
	}
}

func TestT068VerifierSessionEqualToGreenIsCaught(t *testing.T) {
	root, db := t068Setup(t)
	same := []t068Rec{t068Good[0], t068Good[1], {t068Good[2].rel, 3, "sess-fixer"}}
	rep := t068Validate(t, root, db, t068Binder(t, t068Chain(t, root, same), 0))
	if !hasGapFinding(rep, "V-G13", "VSC-004") {
		t.Fatalf("a verifier running in the GREEN's session was accepted: %v", rep.Findings)
	}
}

func TestT068UnverifiedChainIsUndeterminedNotAPass(t *testing.T) {
	root, db := t068Setup(t)
	rep := t068Validate(t, root, db, t068Binder(t, t068Chain(t, root, t068Good), 2))
	if len(rep.Undetermined) == 0 || rep.ExitCode() != 2 {
		t.Fatalf("a chain that does not verify must be rc 2, got rc %d undet=%v", rep.ExitCode(), rep.Undetermined)
	}
	rep = t068Validate(t, root, db, t068Binder(t, t068Chain(t, root, t068Good), 1))
	if !hasGapFinding(rep, "V-G13", "") || rep.ExitCode() != 1 {
		t.Fatalf("a chain whose verifier DETECTED an alteration must be rc 1: %v", rep.Findings)
	}
}

// ── the CLI: close/verdict require the binding unless skipped with a reason ──

func TestT068VerdictAndCloseRequireTheBindingUnlessSkippedLoudly(t *testing.T) {
	repo, db := gapRepo(t), buildRegister(t, true, "golden-good.sql")
	missing := filepath.Join(t.TempDir(), "no-such-store")
	for _, args := range [][]string{
		{"verdict", "--repo", repo, "--db", db, "--id", "VSC-005", "--role", "verifier", "--actor", "a1", "--actor-kind", "agent", "--outcome", "0", "--evidence", evRel + "VSC-004-verifier.json", "--chain-store", missing},
		{"close", "--repo", repo, "--db", db, "--id", "VSC-005", "--chain-store", missing},
	} {
		rc, out, errs := runGapCLI(t, args...)
		if rc != 2 || !strings.Contains(out+errs, "evidence chain") || strings.Contains(out+errs, "flag provided but not defined") {
			t.Fatalf("%s without a usable chain store: want rc 2 naming the chain, got %d\n%s%s", args[0], rc, out, errs)
		}
	}
	rc, out, errs := runGapCLI(t, "verdict", "--repo", repo, "--db", db, "--id", "VSC-005", "--role", "verifier", "--actor", "a1", "--actor-kind", "agent",
		"--outcome", "0", "--evidence", evRel+"VSC-004-verifier.json", "--chain-store", missing, "--skip-chain-binding", "")
	if rc == 0 {
		t.Fatalf("an empty skip reason must not skip: %s%s", out, errs)
	}
	rc, out, errs = runGapCLI(t, "verdict", "--repo", repo, "--db", db, "--id", "VSC-005", "--role", "verifier", "--actor", "a1", "--actor-kind", "agent",
		"--outcome", "0", "--evidence", evRel+"VSC-004-verifier.json", "--skip-chain-binding", "fixture register has no chain")
	if !strings.Contains(out+errs, "CHAIN-BINDING SKIPPED") || !strings.Contains(out+errs, "fixture register has no chain") {
		t.Fatalf("a skip must be loud and carry its reason (rc %d):\n%s%s", rc, out, errs)
	}
}

func TestT068RecordDigestExcludesOneTrailingNewline(t *testing.T) {
	h := sha256.Sum256([]byte("x"))
	if RecordDigest([]byte("x\n")) != "sha256:"+hex.EncodeToString(h[:]) || RecordDigest([]byte("x")) != RecordDigest([]byte("x\n")) {
		t.Fatal("digest rule differs from the adapter's (line bytes, no trailing newline)")
	}
	_ = fmt.Sprint
}
