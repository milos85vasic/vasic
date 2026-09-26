package wi

// Feature 010, task T037: `report --by-module`, the per-module page (FR-024,
// SC-010). Every register is built from the checked-in fixture corpus into a
// temporary directory; docs/workable_items.db is never opened here.

import (
	"bytes"
	"crypto/sha256"
	"database/sql"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"reflect"
	"sort"
	"strings"
	"syscall"
	"testing"
	"time"
)

// moduleGoldenRel is the checked-in page the golden-good register must render to.
const moduleGoldenRel = "module-page-golden-good.md"

// moduleRoot is a self-contained repository root: the good fixture roster
// (VSC + WSP) and the fixture evidence at the path the registers cite.
func moduleRoot(t *testing.T) string {
	t.Helper()
	root := rosterRepo(t, "roster-good")
	copyFixtureEvidence(t, root)
	return root
}

func runModuleReport(t *testing.T, root, db, asOf string) (int, string, string) {
	t.Helper()
	var out, errb bytes.Buffer
	rc := ReportByModule(ModuleReportOptions{Root: root, DBPath: db, AsOf: asOf}, &out, &errb)
	return rc, out.String(), errb.String()
}

func fileSum(t *testing.T, p string) [32]byte {
	t.Helper()
	b, err := os.ReadFile(p)
	if err != nil {
		t.Fatal(err)
	}
	return sha256.Sum256(b)
}

func TestModuleReportGoldenGoodEqualsTheCheckedInPage(t *testing.T) {
	root, db := moduleRoot(t), buildRegister(t, true, "golden-good.sql")
	rc, out, errs := runModuleReport(t, root, db, fixtureAsOf)
	if rc != 0 {
		t.Fatalf("golden-good: want rc 0, got %d\nstderr:\n%s", rc, errs)
	}
	want, err := os.ReadFile(fixturePath(t, moduleGoldenRel))
	if err != nil {
		t.Fatalf("reading the golden page: %v", err)
	}
	if out != string(want) {
		t.Fatalf("the page differs from %s\n--- got ---\n%s", moduleGoldenRel, out)
	}
	// Every gap item of the register is on the page, each exactly once as a heading.
	for _, id := range []string{"VSC-001", "VSC-002", "VSC-003", "VSC-004", "VSC-005", "VSC-006"} {
		if n := strings.Count(out, "#### "+id+" "); n != 1 {
			t.Fatalf("%s occurs %d time(s) as an item heading, want 1", id, n)
		}
	}
	// One section per roster module, the empty one included.
	for _, h := range []string{"## VSC — ", "## WSP — "} {
		if !strings.Contains(out, "\n"+h) {
			t.Fatalf("no module section %q", h)
		}
	}
}

func TestModuleReportIsByteStableAndCarriesNoTimestampOrHostPath(t *testing.T) {
	root, db := moduleRoot(t), buildRegister(t, true, "golden-good.sql")
	_, a, _ := runModuleReport(t, root, db, fixtureAsOf)
	_, b, _ := runModuleReport(t, root, db, fixtureAsOf)
	if a != b || a == "" {
		t.Fatal("two runs over an unchanged register differ (or are empty)")
	}
	// A second register built from the same SQL in another directory renders identically.
	_, c, _ := runModuleReport(t, moduleRoot(t), buildRegister(t, true, "golden-good.sql"), fixtureAsOf)
	if a != c {
		t.Fatal("the page depends on where the register or root lives")
	}
	for _, leak := range []string{root, db, os.TempDir(), "2026-09-27", "T00:", "UTC"} {
		if strings.Contains(a, leak) {
			t.Fatalf("the page carries %q (a path or a clock reading)", leak)
		}
	}
}

func TestModuleReportGoldenBadNamesEachProblemAndExitsOne(t *testing.T) {
	root := moduleRoot(t)
	db := buildRegister(t, true, "golden-good.sql", "golden-bad/module-page.sql")
	rc, out, errs := runModuleReport(t, root, db, fixtureAsOf)
	if rc != 1 {
		t.Fatalf("golden-bad: want rc 1, got %d\nstderr:\n%s", rc, errs)
	}
	named := []struct{ rule, id, text string }{
		{"id/prefix-not-in-roster", "ZZZ-001", "names no sub-project"},
		{"provenance/missing", "", "carry no item_provenance row"},
		{"V-G1", "VSC-005", "kind is missing"},
		{"V-G1", "VSC-005", "category is missing"},
		{"V-G3", "VSC-004", "verifier"},
	}
	for _, n := range named {
		line := ""
		for _, l := range strings.Split(errs, "\n") {
			if strings.Contains(l, n.rule) && strings.Contains(l, n.id) && strings.Contains(l, n.text) {
				line = l
			}
		}
		if line == "" {
			t.Errorf("stderr does not name %s %s (%q):\n%s", n.rule, n.id, n.text, errs)
		}
		if !strings.Contains(out, "FINDING "+n.rule) || !strings.Contains(out, n.text) {
			t.Errorf("the page does not name %s %s (%q)", n.rule, n.id, n.text)
		}
	}
	// The unplaced item is shown, not dropped.
	if !strings.Contains(out, "## Unplaced items") || !strings.Contains(out, "#### ZZZ-001 ") {
		t.Errorf("ZZZ-001 is not on the page under Unplaced items:\n%s", out)
	}
	// The closed item's missing verifier is visible in its own block.
	if !strings.Contains(out, "verifier: MISSING") {
		t.Errorf("VSC-004's missing verifier is not shown in its block:\n%s", out)
	}
}

// Each problem alone is enough for rc 1 (a combined fixture could hide that one
// of them is not detected at all).
func TestModuleReportEachProblemAloneIsAFinding(t *testing.T) {
	cases := map[string]string{
		"unplaced module": `INSERT INTO items (atm_id,type,status,severity,title,description,forensic_anchor,created_by,assigned_to,current_location,body_md,created_at,last_modified,kind,category,disposition,plan_due,sweep_class,reopens_count)
			SELECT 'ZZZ-001',type,status,severity,title,description,forensic_anchor,created_by,assigned_to,current_location,body_md,created_at,last_modified,kind,category,disposition,plan_due,sweep_class,reopens_count FROM items WHERE atm_id='VSC-001';
			INSERT INTO item_history (atm_id,event_type,by,on_date,reason,evidence_path,created_at) SELECT 'ZZZ-001',event_type,by,on_date,reason,evidence_path,created_at FROM item_history WHERE atm_id='VSC-001';`,
		"missing kind":      `UPDATE items SET kind = NULL WHERE atm_id = 'VSC-001';`,
		"missing category":  `UPDATE items SET category = NULL WHERE atm_id = 'VSC-001';`,
		"closed no verdict": `DELETE FROM item_verdicts WHERE item_id = 'VSC-004';`,
	}
	for name, stmt := range cases {
		t.Run(name, func(t *testing.T) {
			db := buildRegister(t, true, "golden-good.sql")
			h, err := sql.Open("sqlite", db)
			if err != nil {
				t.Fatal(err)
			}
			if _, err := h.Exec(stmt); err != nil {
				t.Fatal(err)
			}
			h.Close()
			if rc, _, errs := runModuleReport(t, moduleRoot(t), db, fixtureAsOf); rc != 1 {
				t.Fatalf("want rc 1, got %d\n%s", rc, errs)
			}
		})
	}
}

func TestModuleReportCannotDetermineIsTwoWithAReasonAndNoPage(t *testing.T) {
	root := moduleRoot(t)
	good := buildRegister(t, true, "golden-good.sql")

	unreadable := filepath.Join(t.TempDir(), "register.db")
	b, err := os.ReadFile(good)
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(unreadable, b, 0o000); err != nil {
		t.Fatal(err)
	}

	partial := buildRegister(t, true, "golden-good.sql")
	h, err := sql.Open("sqlite", partial)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := h.Exec(`DROP TABLE item_verdicts`); err != nil {
		t.Fatal(err)
	}
	h.Close()

	walDir := t.TempDir()
	withWAL := filepath.Join(walDir, "register.db")
	if err := os.WriteFile(withWAL, b, 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(withWAL+"-wal", []byte("uncheckpointed frames"), 0o644); err != nil {
		t.Fatal(err)
	}

	notSQLite := filepath.Join(t.TempDir(), "register.db")
	if err := os.WriteFile(notSQLite, []byte("this is not a database\n"), 0o644); err != nil {
		t.Fatal(err)
	}

	cases := []struct {
		name, db, asOf, reason string
	}{
		{"absent", filepath.Join(t.TempDir(), "absent.db"), fixtureAsOf, "no such file"},
		{"directory", t.TempDir(), fixtureAsOf, "not a regular file"},
		{"unmigrated", buildRegister(t, false, "legacy-register.sql"), fixtureAsOf, "gap migrate"},
		{"partially migrated", partial, fixtureAsOf, "PARTIALLY migrated"},
		{"uncheckpointed wal", withWAL, fixtureAsOf, "-wal"},
		{"not a database", notSQLite, fixtureAsOf, "COULD NOT DETERMINE"},
		{"bad as-of", good, "tomorrow", "--as-of"},
	}
	if os.Geteuid() != 0 { // root reads a mode-000 file, so the case proves nothing there
		cases = append(cases, struct{ name, db, asOf, reason string }{"unreadable", unreadable, fixtureAsOf, "permission denied"})
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			rc, out, errs := runModuleReport(t, root, c.db, c.asOf)
			if rc != 2 {
				t.Fatalf("want rc 2, got %d\nstdout:\n%s\nstderr:\n%s", rc, out, errs)
			}
			if out != "" {
				t.Fatalf("an undetermined register must print no page, got:\n%s", out)
			}
			if !strings.Contains(errs, "COULD NOT DETERMINE") || !strings.Contains(errs, c.reason) {
				t.Fatalf("the reason %q is not stated:\n%s", c.reason, errs)
			}
		})
	}
}

func TestModuleReportRosterUnreadableIsTwo(t *testing.T) {
	root := moduleRoot(t)
	if err := os.Remove(filepath.Join(root, RosterPath)); err != nil {
		t.Fatal(err)
	}
	rc, out, errs := runModuleReport(t, root, buildRegister(t, true, "golden-good.sql"), fixtureAsOf)
	if rc != 2 || out != "" || !strings.Contains(errs, "roster") {
		t.Fatalf("an unreadable roster: want rc 2 naming the roster and no page, got %d\n%s", rc, errs)
	}
}

// The source register is never written: its bytes are unchanged and no journal
// file is created beside it.
func TestModuleReportNeverWritesTheRegister(t *testing.T) {
	root, db := moduleRoot(t), buildRegister(t, true, "golden-good.sql", "golden-bad/module-page.sql")
	// a register with neither umbrella extension table: a writable open would create them
	h, err := sql.Open("sqlite", db)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := h.Exec(`DROP TABLE IF EXISTS sub_projects; DROP TABLE IF EXISTS item_provenance;`); err != nil {
		t.Fatal(err)
	}
	h.Close()
	before := fileSum(t, db)
	info, err := os.Stat(db)
	if err != nil {
		t.Fatal(err)
	}
	runModuleReport(t, root, db, fixtureAsOf)
	if fileSum(t, db) != before {
		t.Fatal("the register's bytes changed")
	}
	after, _ := os.Stat(db)
	if !after.ModTime().Equal(info.ModTime()) {
		t.Fatal("the register's modification time changed")
	}
	for _, sfx := range []string{"-wal", "-shm", "-journal"} {
		if _, err := os.Stat(db + sfx); err == nil {
			t.Fatalf("a %s file appeared beside the register", sfx)
		}
	}
}

// ── T037 fix round (review rev-t037) ───────────────────────────────────────

// validateFindings runs what `validate` runs (the base rules plus V-G1..V-G12,
// on a register opened the way `validate` opens one) on a separate copy of db,
// and returns its FINDING and UNDET lines in the form the report prints them.
func validateFindings(t *testing.T, root, db string) (findings, undet []string) {
	t.Helper()
	b, err := os.ReadFile(db)
	if err != nil {
		t.Fatal(err)
	}
	cp := filepath.Join(t.TempDir(), "validate-copy.db")
	if err := os.WriteFile(cp, b, 0o600); err != nil {
		t.Fatal(err)
	}
	h, err := Open(cp)
	if err != nil {
		t.Fatal(err)
	}
	defer h.Close()
	r, err := LoadRoster(root)
	if err != nil {
		t.Fatal(err)
	}
	base, err := Validate(h, r)
	if err != nil {
		t.Fatal(err)
	}
	gap, err := ValidateGap(h, GapOptions{AsOf: fixtureAsOf, Root: root, Roster: r})
	if err != nil {
		t.Fatal(err)
	}
	for _, f := range append(base.Findings, gap.Findings...) {
		findings = append(findings, "FINDING  "+f.String())
	}
	for _, u := range append(base.Undetermined, gap.Undetermined...) {
		undet = append(undet, "UNDET    "+u)
	}
	sort.Strings(findings)
	sort.Strings(undet)
	return findings, undet
}

func linesWith(s, prefix string) []string {
	var out []string
	for _, l := range strings.Split(s, "\n") {
		if strings.HasPrefix(l, prefix) {
			out = append(out, l)
		}
	}
	sort.Strings(out)
	return out
}

// C1: the page's finding set IS validate's finding set — no rule subset, no
// private rule of its own.
func TestModuleReportFindingSetEqualsValidate(t *testing.T) {
	cases := map[string][]string{
		"golden-bad":         {"golden-good.sql", "golden-bad/module-page.sql"},
		"provenance-missing": {"golden-good.sql"},
	}
	for name, files := range cases {
		t.Run(name, func(t *testing.T) {
			root := moduleRoot(t)
			db := buildRegister(t, true, files...)
			if name == "provenance-missing" {
				h, err := sql.Open("sqlite", db)
				if err != nil {
					t.Fatal(err)
				}
				if _, err := h.Exec(`DELETE FROM item_provenance WHERE atm_id = 'VSC-001'`); err != nil {
					t.Fatal(err)
				}
				h.Close()
			}
			wantF, wantU := validateFindings(t, root, db)
			if len(wantF) == 0 {
				t.Fatal("the case must carry at least one validate finding")
			}
			rc, out, errs := runModuleReport(t, root, db, fixtureAsOf)
			if rc != 1 {
				t.Fatalf("want rc 1, got %d\n%s", rc, errs)
			}
			if got := linesWith(errs, "FINDING  "); !reflect.DeepEqual(got, wantF) {
				t.Fatalf("finding set differs from validate\n--- report ---\n%s\n--- validate ---\n%s",
					strings.Join(got, "\n"), strings.Join(wantF, "\n"))
			}
			if got := linesWith(errs, "UNDET    "); !reflect.DeepEqual(got, wantU) {
				t.Fatalf("undetermined set differs from validate: %v vs %v", got, wantU)
			}
			if n := len(linesWith(out, "- FINDING ")); n != len(wantF) {
				t.Fatalf("the page lists %d finding(s), validate %d", n, len(wantF))
			}
		})
	}
}

// C2: the -wal / -journal refusal follows a symlinked --db to the real file.
func TestModuleReportSymlinkedRegisterStillRefusesWALAndJournal(t *testing.T) {
	root := moduleRoot(t)
	good := buildRegister(t, true, "golden-good.sql")
	b, err := os.ReadFile(good)
	if err != nil {
		t.Fatal(err)
	}
	mk := func(t *testing.T, sidecar string, content []byte) (real, link string) {
		dir, other := t.TempDir(), t.TempDir()
		real = filepath.Join(dir, "register.db")
		if err := os.WriteFile(real, b, 0o644); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(real+sidecar, content, 0o644); err != nil {
			t.Fatal(err)
		}
		link = filepath.Join(other, "link.db")
		if err := os.Symlink(real, link); err != nil {
			t.Fatal(err)
		}
		return real, link
	}
	cases := []struct {
		name, sidecar string
		content       []byte
	}{
		{"wal with frames", "-wal", []byte("uncheckpointed frames")},
		{"hot journal", "-journal", []byte("rollback journal")},
		{"empty journal", "-journal", nil},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			real, link := mk(t, c.sidecar, c.content)
			for _, p := range []string{real, link} {
				rc, out, errs := runModuleReport(t, root, p, fixtureAsOf)
				if rc != 2 || out != "" || !strings.Contains(errs, c.sidecar) {
					t.Fatalf("%s: want rc 2 naming %s and no page, got rc %d\n%s", p, c.sidecar, rc, errs)
				}
			}
		})
	}
	// Control: a symlink to a clean register renders the golden page.
	dir := t.TempDir()
	link := filepath.Join(dir, "link.db")
	if err := os.Symlink(good, link); err != nil {
		t.Fatal(err)
	}
	if rc, _, errs := runModuleReport(t, root, link, fixtureAsOf); rc != 0 {
		t.Fatalf("symlink to a clean register: want rc 0, got %d\n%s", rc, errs)
	}
}

// I1: identifiers, titles and other register text cannot inject headings or
// HTML; titles are truncated at the stated limit.
func TestModuleReportRegisterTextCannotSpoofThePage(t *testing.T) {
	root := moduleRoot(t)
	db := buildRegister(t, true, "golden-good.sql")
	h, err := sql.Open("sqlite", db)
	if err != nil {
		t.Fatal(err)
	}
	spoof := "VSC-007\n## VSC — `.` (parent)\n\n## WSP — `workshop` (owned)\n### Open (9)"
	long := "<script>alert(1)</script> " + strings.Repeat("A", 400)
	if _, err := h.Exec(`INSERT INTO items (atm_id,type,status,severity,title,description,forensic_anchor,created_by,assigned_to,current_location,body_md,created_at,last_modified,kind,category,disposition,plan_due,sweep_class,reopens_count)
		SELECT ?,type,status,severity,?,description,forensic_anchor,created_by,assigned_to,current_location,body_md,created_at,last_modified,kind,'<b>x</b>',disposition,plan_due,sweep_class,reopens_count FROM items WHERE atm_id='VSC-001'`, spoof, long); err != nil {
		t.Fatal(err)
	}
	h.Close()
	rc, out, _ := runModuleReport(t, root, db, fixtureAsOf)
	if rc != 1 {
		t.Fatalf("want rc 1 (id/malformed), got %d", rc)
	}
	for _, h := range []string{"## VSC — ", "## WSP — "} {
		if n := len(linesWith(out, h)); n != 1 {
			t.Fatalf("%d line(s) start with %q, want exactly 1:\n%s", n, h, out)
		}
	}
	if n := len(linesWith(out, "### Open (9)")); n != 0 {
		t.Fatal("a register id injected a sub-section heading")
	}
	if strings.Contains(out, "<script>") || strings.Contains(out, "<b>") {
		t.Fatal("raw HTML from the register reaches the page")
	}
	if !strings.Contains(out, "&lt;script&gt;") {
		t.Fatal("the title's HTML is not escaped")
	}
	if strings.Contains(out, strings.Repeat("A", 400)) || !strings.Contains(out, "…") {
		t.Fatal("a title over the limit is not truncated")
	}
	if !strings.Contains(out, fmt.Sprintf("truncated to %d characters", maxTitleRunes)) {
		t.Fatal("the page does not state the title limit")
	}
}

// I2 / M4b: an undetermined validator row prints the page AND exits 2.
func TestModuleReportUndeterminedRowPrintsThePageAndExitsTwo(t *testing.T) {
	root := moduleRoot(t)
	db := buildRegister(t, true, "golden-good.sql")
	h, err := sql.Open("sqlite", db)
	if err != nil {
		t.Fatal(err)
	}
	// A regular file used as a directory: stat fails with ENOTDIR, which is
	// neither "exists" nor "does not exist" — the rule cannot decide.
	if _, err := h.Exec(`UPDATE item_history SET evidence_path = evidence_path || '/below-a-file' WHERE atm_id = 'VSC-001'`); err != nil {
		t.Fatal(err)
	}
	h.Close()
	rc, out, errs := runModuleReport(t, root, db, fixtureAsOf)
	if rc != 2 {
		t.Fatalf("want rc 2, got %d\n%s", rc, errs)
	}
	if !strings.Contains(out, "# Zero-gap register — per-module page") || !strings.Contains(out, "- COULD NOT DETERMINE ") {
		t.Fatalf("the page (with its undetermined row) is not printed:\n%s", out)
	}
	if len(linesWith(errs, "UNDET    ")) == 0 {
		t.Fatal("stderr names no undetermined row")
	}
}

// I2 / M6: a register that changes while it is being read is exit 2.
func TestModuleReportRegisterChangedWhileReadIsTwo(t *testing.T) {
	root := moduleRoot(t)
	db := buildRegister(t, true, "golden-good.sql")
	snapshotMidHook = func() {
		f, err := os.OpenFile(db, os.O_APPEND|os.O_WRONLY, 0)
		if err != nil {
			t.Error(err)
			return
		}
		f.Write([]byte{0})
		f.Close()
	}
	t.Cleanup(func() { snapshotMidHook = nil })
	rc, out, errs := runModuleReport(t, root, db, fixtureAsOf)
	if rc != 2 || out != "" || !strings.Contains(errs, "changed while it was being read") {
		t.Fatalf("want rc 2 'changed while it was being read' and no page, got rc %d\n%s", rc, errs)
	}
}

// I2 / M2b: modules are sorted by prefix, not taken in roster-file order.
func TestModuleReportSortsModulesWhateverTheRosterOrder(t *testing.T) {
	root := rosterRepo(t, "roster-unsorted")
	copyFixtureEvidence(t, root)
	rc, out, errs := runModuleReport(t, root, buildRegister(t, true, "golden-good.sql"), fixtureAsOf)
	if rc != 0 {
		t.Fatalf("want rc 0, got %d\n%s", rc, errs)
	}
	want, err := os.ReadFile(fixturePath(t, moduleGoldenRel))
	if err != nil {
		t.Fatal(err)
	}
	if out != string(want) {
		t.Fatalf("an unsorted roster file changes the page:\n%s", out)
	}
}

// I2 / M2d: register problems are listed sorted by rule, id, detail — across
// the base and the V-G rule sets, not per set.
func TestModuleReportProblemsAreSorted(t *testing.T) {
	_, out, errs := runModuleReport(t, moduleRoot(t), buildRegister(t, true, "golden-good.sql", "golden-bad/module-page.sql"), fixtureAsOf)
	for name, lines := range map[string][]string{"page": pageLines(out, "- FINDING "), "stderr": pageLines(errs, "FINDING  ")} {
		if len(lines) < 2 {
			t.Fatalf("%s: too few findings to test ordering", name)
		}
		keys := make([][3]string, len(lines))
		for i, l := range lines {
			f := strings.Fields(l)
			keys[i] = [3]string{f[1], f[2], l}
		}
		if !sort.SliceIsSorted(keys, func(i, j int) bool {
			if keys[i][0] != keys[j][0] {
				return keys[i][0] < keys[j][0]
			}
			if keys[i][1] != keys[j][1] {
				return keys[i][1] < keys[j][1]
			}
			return keys[i][2] < keys[j][2]
		}) {
			t.Fatalf("%s findings are not sorted by rule, id, detail:\n%s", name, strings.Join(lines, "\n"))
		}
	}
}

// pageLines returns the lines with prefix in document order (unsorted).
func pageLines(s, prefix string) []string {
	var out []string
	for _, l := range strings.Split(s, "\n") {
		if strings.HasPrefix(l, prefix) {
			out = append(out, l)
		}
	}
	return out
}

type failingWriter struct{}

func (failingWriter) Write([]byte) (int, error) { return 0, errors.New("disk full") }

// Minor: a page that could not be written is exit 2, never 0.
func TestModuleReportStdoutWriteErrorIsTwo(t *testing.T) {
	var errb bytes.Buffer
	rc := ReportByModule(ModuleReportOptions{Root: moduleRoot(t), DBPath: buildRegister(t, true, "golden-good.sql"), AsOf: fixtureAsOf}, failingWriter{}, &errb)
	if rc != 2 || !strings.Contains(errb.String(), "disk full") {
		t.Fatalf("want rc 2 naming the write error, got %d\n%s", rc, errb.String())
	}
}

// Minor: SIGINT/SIGTERM removes the private copy before the process exits.
func TestModuleReportSignalRemovesThePrivateCopy(t *testing.T) {
	for _, sig := range []syscall.Signal{syscall.SIGTERM, syscall.SIGINT} {
		dir := t.TempDir()
		victim := filepath.Join(dir, "copy")
		if err := os.MkdirAll(victim, 0o700); err != nil {
			t.Fatal(err)
		}
		exited := make(chan int, 1)
		stop := installSignalCleanup(func() { os.RemoveAll(victim) }, func(code int) { exited <- code })
		if err := syscall.Kill(os.Getpid(), sig); err != nil {
			t.Fatal(err)
		}
		select {
		case code := <-exited:
			if code != 2 {
				t.Fatalf("%v: exit code %d, want 2", sig, code)
			}
		case <-time.After(5 * time.Second):
			t.Fatalf("%v: the handler did not run", sig)
		}
		stop()
		if _, err := os.Stat(victim); !errors.Is(err, os.ErrNotExist) {
			t.Fatalf("%v: the private copy was not removed", sig)
		}
	}
}

// Minor: legacy items under a prefix outside the roster are counted, not dropped.
func TestModuleReportCountsLegacyItemsOutsideTheRoster(t *testing.T) {
	db := buildRegister(t, true, "golden-good.sql")
	h, err := sql.Open("sqlite", db)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := h.Exec(`INSERT INTO items (atm_id,type,status,severity,title,description,created_by,current_location,body_md,created_at,last_modified,reopens_count)
		VALUES ('QQQ-001','Task','Queued','low','legacy row','a legacy row filed under a prefix outside the roster for the count','AI','Issues','x','2026-09-25 10:00:00','2026-09-25 10:00:00',0)`); err != nil {
		t.Fatal(err)
	}
	h.Close()
	_, out, _ := runModuleReport(t, moduleRoot(t), db, fixtureAsOf)
	if !strings.Contains(out, "legacy items under prefixes outside the roster: 1") {
		t.Fatalf("the legacy item outside the roster is not counted:\n%s", out)
	}
}

// Minor: a roster path containing '|' does not split its table cell.
func TestModuleReportPipeInARosterPathIsEscaped(t *testing.T) {
	root := t.TempDir()
	write := func(rel, s string) {
		p := filepath.Join(root, rel)
		if err := os.MkdirAll(filepath.Dir(p), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(p, []byte(s), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	write(".gitmodules", "[submodule \"odd\"]\n\tpath = od|d\n\turl = git@example.invalid:owner/odd.git\n")
	write("helix-deps.yaml", "- name: odd\n")
	write(RosterPath, "prefix\tpath\tclass\tratified\tnote\nVSC\t.\tparent\toperator\tthe umbrella\nODD\tod|d\towned\toperator\tpipe in path\n")
	copyFixtureEvidence(t, root)
	_, out, errs := runModuleReport(t, root, buildRegister(t, true, "golden-good.sql"), fixtureAsOf)
	row := ""
	for _, l := range strings.Split(out, "\n") {
		if strings.HasPrefix(l, "| ODD |") {
			row = l
		}
	}
	if row == "" {
		t.Fatalf("no table row for ODD:\n%s\n%s", out, errs)
	}
	if !strings.Contains(row, `od\|d`) || strings.Count(strings.ReplaceAll(row, `\|`, ""), "|") != 9 {
		t.Fatalf("the '|' in the path is not escaped in its cell: %s", row)
	}
}
