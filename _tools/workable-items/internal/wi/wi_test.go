package wi

import (
	"database/sql"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// newDB builds a database carrying the same tables the canonical binary
// creates, so the tests exercise the real constraints rather than a relaxed
// stand-in. The DDL below is copied from the canonical schema's own CHECK
// clauses; if upstream widens them, these tests keep asserting the narrower set
// and will need updating deliberately rather than drifting silently.
func newDB(t *testing.T) *sql.DB {
	t.Helper()
	path := filepath.Join(t.TempDir(), "wi.db")
	db, err := sql.Open("sqlite", path)
	if err != nil {
		t.Fatal(err)
	}
	_, err = db.Exec(`
CREATE TABLE items (
    atm_id TEXT NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('Bug','Feature','Task')),
    status TEXT NOT NULL,
    severity TEXT,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    forensic_anchor TEXT,
    closure_criteria TEXT,
    composes_with TEXT,
    destination TEXT,
    logic_group TEXT,
    created_by TEXT NOT NULL DEFAULT '',
    assigned_to TEXT NOT NULL DEFAULT '',
    current_location TEXT NOT NULL CHECK (current_location IN ('Issues','Fixed')) DEFAULT 'Issues',
    body_md TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    last_modified TEXT NOT NULL DEFAULT (datetime('now')),
    PRIMARY KEY (atm_id, current_location)
);
CREATE TABLE item_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    atm_id TEXT NOT NULL, event_type TEXT NOT NULL, by TEXT,
    on_date TEXT NOT NULL, reason TEXT, evidence_path TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE TABLE doc_segments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    document TEXT NOT NULL, seq INTEGER NOT NULL, kind TEXT NOT NULL,
    atm_id TEXT, raw TEXT, UNIQUE(document, seq)
);
`)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := db.Exec(extensionDDL); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { db.Close() })
	return db
}

func testRoster() *Roster {
	return &Roster{Members: []SubProject{
		{Prefix: "VSC", Path: ".", Class: ClassParent, Ratified: "operator", Declared: true},
		{Prefix: "WSP", Path: "workshop", Class: ClassOwned, Ratified: "operator", Declared: true},
		{Prefix: "SSP", Path: "submodules/superspec", Class: ClassThirdParty, Ratified: "proposed", Declared: true},
	}}
}

func goodItem(id, prefix string) Item {
	return Item{
		ID: id, Type: TypeTask, Status: StatusQueued,
		Title:           "a well-formed item used as the control",
		Description:     "This description is comfortably past the §11.4.91 floor of six words and forty characters.",
		CurrentLocation: "Issues", CreatedBy: "AI",
		SourceKind: "spec-task", SourcePath: "specs/x/tasks.md", SourceLocator: id,
		EvidenceClass: "checkbox-state",
	}
}

func TestValidateAcceptsAWellFormedItem(t *testing.T) {
	db := newDB(t)
	if _, _, err := InsertItems(db, []Item{goodItem("VSC-001", "VSC")}); err != nil {
		t.Fatal(err)
	}
	rep, err := Validate(db, testRoster())
	if err != nil {
		t.Fatal(err)
	}
	if rep.ExitCode() != 0 {
		t.Fatalf("want rc 0, got %d: %v %v", rep.ExitCode(), rep.Findings, rep.Undetermined)
	}
}

// The control above is what makes each case below meaningful: without it a
// validator that failed everything would look like a working detector.

func TestValidateRejectsAPrefixOutsideTheRoster(t *testing.T) {
	db := newDB(t)
	it := goodItem("ZZZ-001", "ZZZ")
	if _, _, err := InsertItems(db, []Item{it}); err != nil {
		t.Fatal(err)
	}
	rep, _ := Validate(db, testRoster())
	if !hasRule(rep, "id/prefix-not-in-roster") {
		t.Fatalf("want id/prefix-not-in-roster, got %v", rep.Findings)
	}
	if rep.ExitCode() != 1 {
		t.Fatalf("want rc 1, got %d", rep.ExitCode())
	}
}

func TestValidateRejectsAnItemFiledAgainstAThirdPartySubmodule(t *testing.T) {
	db := newDB(t)
	if _, _, err := InsertItems(db, []Item{goodItem("SSP-001", "SSP")}); err != nil {
		t.Fatal(err)
	}
	rep, _ := Validate(db, testRoster())
	if !hasRule(rep, "id/prefix-third-party") {
		t.Fatalf("want id/prefix-third-party, got %v", rep.Findings)
	}
}

func TestValidateRejectsAGapInTheIdSequence(t *testing.T) {
	db := newDB(t)
	items := []Item{goodItem("VSC-001", "VSC"), goodItem("VSC-003", "VSC")}
	items[1].SourceLocator = "VSC-003"
	if _, _, err := InsertItems(db, items); err != nil {
		t.Fatal(err)
	}
	rep, _ := Validate(db, testRoster())
	if !hasRule(rep, "id/sequence-gap") {
		t.Fatalf("want id/sequence-gap, got %v", rep.Findings)
	}
}

func TestValidateRejectsAClosureStatusMismatchedToItsType(t *testing.T) {
	db := newDB(t)
	it := goodItem("VSC-001", "VSC")
	it.Type = TypeBug
	it.Status = StatusCompleted // §11.4.33: a Bug closes as Fixed, never Completed
	it.CurrentLocation = "Fixed"
	if _, _, err := InsertItems(db, []Item{it}); err != nil {
		t.Fatal(err)
	}
	rep, _ := Validate(db, testRoster())
	if !hasRule(rep, "closure/type-mismatch") {
		t.Fatalf("want closure/type-mismatch, got %v", rep.Findings)
	}
}

func TestValidateAcceptsEachTypeClosingWithItsOwnTerminalWord(t *testing.T) {
	for typ, want := range map[string]string{TypeBug: StatusFixed, TypeFeature: StatusImplemented, TypeTask: StatusCompleted} {
		db := newDB(t)
		it := goodItem("VSC-001", "VSC")
		it.Type, it.Status, it.CurrentLocation = typ, want, "Fixed"
		if _, _, err := InsertItems(db, []Item{it}); err != nil {
			t.Fatal(err)
		}
		rep, _ := Validate(db, testRoster())
		if rep.ExitCode() != 0 {
			t.Fatalf("%s closing as %q should be clean, got %v", typ, want, rep.Findings)
		}
	}
}

func TestValidateRejectsADescriptionBelowTheClarityFloor(t *testing.T) {
	db := newDB(t)
	it := goodItem("VSC-001", "VSC")
	it.Description = "too short"
	if _, _, err := InsertItems(db, []Item{it}); err != nil {
		t.Fatal(err)
	}
	rep, _ := Validate(db, testRoster())
	if !hasRule(rep, "description/below-floor") {
		t.Fatalf("want description/below-floor, got %v", rep.Findings)
	}
}

func TestValidateRejectsAnItemWithNoProvenance(t *testing.T) {
	db := newDB(t)
	if _, _, err := InsertItems(db, []Item{goodItem("VSC-001", "VSC")}); err != nil {
		t.Fatal(err)
	}
	if _, err := db.Exec(`DELETE FROM item_provenance`); err != nil {
		t.Fatal(err)
	}
	rep, _ := Validate(db, testRoster())
	if !hasRule(rep, "provenance/missing") {
		t.Fatalf("want provenance/missing, got %v", rep.Findings)
	}
}

func TestValidateReportsAnEmptyTableAsUndeterminedNotClean(t *testing.T) {
	db := newDB(t)
	rep, _ := Validate(db, testRoster())
	if rep.ExitCode() != 2 {
		t.Fatalf("an empty item set must be rc 2, never rc 0; got %d", rep.ExitCode())
	}
}

func TestAFindingOutranksAnUndetermined(t *testing.T) {
	r := &Report{Findings: []Finding{{Rule: "x"}}, Undetermined: []string{"y"}}
	if r.ExitCode() != 1 {
		t.Fatalf("a finding must outrank an undetermined, else an unreadable leg can mask a violation; got %d", r.ExitCode())
	}
}

func TestInsertItemsIsIdempotentOnTheSameSourceLocator(t *testing.T) {
	db := newDB(t)
	it := goodItem("VSC-001", "VSC")
	if _, _, err := InsertItems(db, []Item{it}); err != nil {
		t.Fatal(err)
	}
	ins, skipped, err := InsertItems(db, []Item{it})
	if err != nil {
		t.Fatal(err)
	}
	if ins != 0 || skipped != 1 {
		t.Fatalf("a re-run over an unchanged source must insert nothing; got inserted=%d skipped=%d", ins, skipped)
	}
}

func TestInsertItemsWritesADocSegmentForEveryItem(t *testing.T) {
	db := newDB(t)
	if _, _, err := InsertItems(db, []Item{goodItem("VSC-001", "VSC")}); err != nil {
		t.Fatal(err)
	}
	var n int
	if err := db.QueryRow(`SELECT count(*) FROM doc_segments WHERE kind='item' AND atm_id='VSC-001'`).Scan(&n); err != nil {
		t.Fatal(err)
	}
	if n != 1 {
		// The canonical validator's own words for the absence: "db-to-md would
		// silently drop it". It caught exactly this during the adoption work.
		t.Fatalf("an item with no doc_segments row would be silently dropped by db-to-md; got %d rows", n)
	}
}

func TestInsertItemsRecordsAResolvableEvidencePathForAClosure(t *testing.T) {
	db := newDB(t)
	it := goodItem("VSC-001", "VSC")
	it.Status, it.CurrentLocation = StatusCompleted, "Fixed"
	if _, _, err := InsertItems(db, []Item{it}); err != nil {
		t.Fatal(err)
	}
	var ev, reason string
	if err := db.QueryRow(`SELECT evidence_path, reason FROM item_history WHERE atm_id='VSC-001'`).Scan(&ev, &reason); err != nil {
		t.Fatal(err)
	}
	if strings.Contains(ev, "#") {
		t.Fatalf("evidence_path must be a path that resolves on disk, not a path with a locator appended; got %q", ev)
	}
	if !strings.Contains(reason, it.SourceLocator) {
		t.Fatalf("the locator must survive in `reason` when it is kept out of the path; got %q", reason)
	}
}

func TestAllocateIDsIsDeterministicAcrossRuns(t *testing.T) {
	mk := func() []Item {
		return []Item{
			{ID: "VSC", SourcePath: "b.md", SourceLocator: "T010"},
			{ID: "VSC", SourcePath: "a.md", SourceLocator: "row 2"},
			{ID: "WSP", SourcePath: "a.md", SourceLocator: "row 10"},
		}
	}
	first := AllocateIDs(mk(), map[string]int{"VSC": 0, "WSP": 0})
	second := AllocateIDs(mk(), map[string]int{"VSC": 0, "WSP": 0})
	for i := range first {
		if first[i].ID != second[i].ID {
			// §11.4.54: "once assigned to an item it stays bound to that item for
			// the lifetime of the project". That can only hold if allocation is
			// deterministic over an unchanged input.
			t.Fatalf("allocation is not deterministic: %q vs %q", first[i].ID, second[i].ID)
		}
	}
	// "row 2" must precede "row 10": ASCII ordering would invert them.
	if first[0].SourceLocator != "row 2" {
		t.Fatalf("numeric locators must order numerically; got %q first", first[0].SourceLocator)
	}
}

func TestSplitAndFormatIDRoundTrip(t *testing.T) {
	for _, tc := range []struct {
		id     string
		prefix string
		n      int
		ok     bool
	}{
		{"VSC-001", "VSC", 1, true},
		{"WSP-142", "WSP", 142, true},
		{"vsc-001", "", 0, false},
		{"VS-001", "", 0, false},
		{"VSCX-001", "", 0, false},
		{"VSC-000", "", 0, false},
		{"VSC", "", 0, false},
	} {
		p, n, ok := SplitID(tc.id)
		if ok != tc.ok || p != tc.prefix || n != tc.n {
			t.Errorf("SplitID(%q) = (%q,%d,%v), want (%q,%d,%v)", tc.id, p, n, ok, tc.prefix, tc.n, tc.ok)
		}
		if tc.ok && FormatID(tc.prefix, tc.n) != tc.id {
			t.Errorf("FormatID(%q,%d) = %q, want %q", tc.prefix, tc.n, FormatID(tc.prefix, tc.n), tc.id)
		}
	}
}

func TestAttributionNamesTheSubProjectThePathBelongsTo(t *testing.T) {
	r := testRoster()
	for _, tc := range []struct {
		text string
		want string
	}{
		{"touch workshop/platform/backend/main.go", "WSP"},
		{"a row naming no path at all", "VSC"},
		{"my-workshop-fork/thing", "VSC"}, // bounded on the left
		{"workshopping the idea", "VSC"},  // bounded on the right
		{"`workshop` and nothing else", "WSP"},
	} {
		got, _ := attribute(tc.text, r)
		if got != tc.want {
			t.Errorf("attribute(%q) = %q, want %q", tc.text, got, tc.want)
		}
	}
}

func TestDecisionStatusMappingNeverUpgradesADecisionIntoACompletion(t *testing.T) {
	for _, cell := range []string{"DECIDED", "PENDING", "decided"} {
		st, _, _ := statusFromDecisionCell(cell)
		if st != StatusQueued {
			t.Errorf("a recorded DECISION is not completed work; %q mapped to %q", cell, st)
		}
	}
	if st, _, _ := statusFromDecisionCell("DONE"); st != StatusCompleted {
		t.Errorf("DONE must map to the Task terminal value, got %q", st)
	}
	if st, _, _ := statusFromDecisionCell("DONE (fix) / OPEN (the design finding)"); st != StatusInProgress {
		t.Errorf("a split DONE/OPEN row is neither terminal nor queued, got %q", st)
	}
	if st, _, note := statusFromDecisionCell("SOMETHING NOBODY PLANNED FOR"); st != StatusQueued || !strings.Contains(note, "UNKNOWN") {
		t.Errorf("an unmapped cell must be recorded conservatively and say UNKNOWN, got %q / %q", st, note)
	}
}

func TestRosterLoadsAndCrossChecksTheLiveFleet(t *testing.T) {
	root, err := FindRepoRoot(".")
	if err != nil {
		t.Skipf("not inside the umbrella checkout: %v", err)
	}
	if _, err := os.Stat(filepath.Join(root, RosterPath)); err != nil {
		t.Skipf("roster absent: %v", err)
	}
	r, err := LoadRoster(root)
	if err != nil {
		t.Fatal(err)
	}
	if len(r.Undetermined) != 0 {
		t.Fatalf("every declared submodule must carry an identifier; missing: %v", r.Undetermined)
	}
	if len(r.Orphans) != 0 {
		t.Fatalf("every roster row must name a declared submodule; orphans: %v", r.Orphans)
	}
	var operator int
	for _, sp := range r.Members {
		if sp.Ratified == "operator" {
			operator++
		}
	}
	if operator != 5 {
		t.Fatalf("exactly five identifiers were stated by the operator (VSC, WSP, AII, MVR, VDT); found %d marked ratified", operator)
	}
}

func hasRule(r *Report, rule string) bool {
	for _, f := range r.Findings {
		if f.Rule == rule {
			return true
		}
	}
	return false
}
