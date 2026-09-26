package wi

// Feature 010, task T037: `workable-items-vsc report --by-module` — the
// per-module page (FR-024 "readable by a person in one place", SC-010 "for any
// module: what is open, what is closed and how do I know").
//
// The page is DERIVED, never typed: every count and every line comes from the
// register rows, the roster file and the SAME rule set `validate` runs — the
// base rules (validate.go) plus V-G1..V-G12 (validate_gap.go), on a register
// opened the way `validate` opens one — so the page and `validate` cannot
// disagree about what is wrong (fix round, review rev-t037 C1). The page has no
// rule of its own: an item is placed on no module section exactly when the base
// rules report it as id/prefix-not-in-roster or id/malformed, and it is then
// listed under "Unplaced items", never dropped.
//
// The source register is never opened by SQLite. Its path is resolved through
// symlinks; a non-empty -wal or any -journal beside the RESOLVED file is exit 2
// (its committed state is not all in the main file, and recovering it would be
// a write). The bytes are read twice and compared (a register written during
// the read is exit 2) and written to a private temporary directory, which is
// removed on return and on SIGINT/SIGTERM. The COPY is first opened the way
// `validate` opens a register (which may add the umbrella extension tables to
// the copy, as `validate` would to the register), then re-opened with
// mode=ro&immutable=1 for every rule and every line of the page.
//
// Exit codes: 0 the page was printed and the register carries no finding;
// 1 the page was printed and names at least one finding; 2 could not
// determine. A 2 raised before the register could be read (absent, unreadable,
// non-regular, non-SQLite, unmigrated or partially migrated register, a -wal or
// -journal beside it, a register that changed while being read, an unreadable
// roster, a bad --as-of) prints no page; a 2 from an undetermined validator row
// prints the page with that row under "Register problems"; a page that cannot
// be written is also a 2. A 2 is never a pass.

import (
	"bytes"
	"crypto/sha256"
	"database/sql"
	"errors"
	"fmt"
	"io"
	"os"
	"os/signal"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"unicode/utf8"
)

// ModuleReportOptions parameterises ReportByModule.
type ModuleReportOptions struct {
	Root   string // repository root: the roster and relative evidence paths resolve against it
	DBPath string // register file; read with plain file I/O and never opened by SQLite
	AsOf   string // ISO date every date rule is evaluated at (required)
}

// maxRegisterBytes caps the register copy (the live register is 2.4 MB at 530 rows).
const maxRegisterBytes = 512 << 20

// maxTitleRunes is the title length the page prints; longer titles are cut
// and marked with "…" (the page states the limit).
const maxTitleRunes = 200

// snapshotMidHook, when set, runs between the two reads of the register — a
// test seam for "the register changed while it was being read".
var snapshotMidHook func()

// placementRules are the base-validator findings that mean an item cannot be
// placed on any module section.
var placementRules = map[string]bool{"id/prefix-not-in-roster": true, "id/malformed": true}

// ReportByModule writes the per-module page to stdout and names every problem
// on stderr. See the file comment for the exit-code contract.
func ReportByModule(o ModuleReportOptions, stdout, stderr io.Writer) int {
	undet := func(format string, a ...any) int {
		fmt.Fprintf(stderr, "COULD NOT DETERMINE: "+format+"\n", a...)
		fmt.Fprintln(stderr, "COULD NOT DETERMINE — no page was produced. A 2 is never a pass.")
		return rcUndet
	}
	if _, err := ParseAsOf(o.AsOf); err != nil {
		return undet("%v", err)
	}
	snap, cleanup, err := snapshotRegister(o.DBPath)
	if err != nil {
		return undet("%v", err)
	}
	stop := installSignalCleanup(cleanup, os.Exit)
	defer func() { stop(); cleanup() }()

	// Opened as `validate` opens a register (the copy only), then closed.
	prep, err := Open(snap)
	if err != nil {
		return undet("%s: %v", o.DBPath, err)
	}
	prep.Close()
	db, err := sql.Open("sqlite", "file:"+snap+"?mode=ro&immutable=1")
	if err != nil {
		return undet("opening the register copy: %v", err)
	}
	defer db.Close()
	if err := requireMigrated(db); err != nil {
		if errors.Is(err, ErrNotMigrated) {
			return undet("%s: %v (the page lists zero-gap items only; an unmigrated register has none to list, which is not the same as having no gaps)", o.DBPath, err)
		}
		return undet("%s: %v", o.DBPath, err)
	}
	roster, err := LoadRoster(o.Root)
	if err != nil {
		return undet("reading the roster (%s): %v", RosterPath, err)
	}
	base, err := Validate(db, roster)
	if err != nil {
		return undet("evaluating the base rules: %v", err)
	}
	v, err := validateGapOn(db, GapOptions{AsOf: o.AsOf, Root: o.Root, Roster: roster})
	if err != nil {
		return undet("evaluating V-G1..V-G12: %v", err)
	}
	findings := append(append([]Finding{}, base.Findings...), v.rep.Findings...)
	sortFindings(findings)
	undetermined := append(append([]string{}, base.Undetermined...), v.rep.Undetermined...)
	sort.Strings(undetermined)

	page, err := buildModulePage(db, roster, findings, undetermined, o.AsOf)
	if err != nil {
		return undet("building the page: %v", err)
	}
	if _, err := stdout.Write(page.text); err != nil {
		fmt.Fprintf(stderr, "COULD NOT DETERMINE: writing the page: %v — the page was not delivered. A 2 is never a pass.\n", err)
		return rcUndet
	}
	for _, f := range findings {
		fmt.Fprintln(stderr, "FINDING  "+findingLine(f))
	}
	for _, u := range undetermined {
		fmt.Fprintln(stderr, "UNDET    "+oneLine(u))
	}
	switch {
	case len(findings) > 0:
		fmt.Fprintf(stderr, "FAIL — %d gap item(s) on the page, %d finding(s); each is named on the page under \"Register problems\".\n",
			page.items, len(findings))
		return rcFind
	case len(undetermined) > 0:
		fmt.Fprintf(stderr, "COULD NOT DETERMINE — the page was printed; %d gap item(s), %d unresolved condition(s). A 2 is never a pass.\n",
			page.items, len(undetermined))
		return rcUndet
	}
	fmt.Fprintf(stderr, "OK — %d gap item(s) across %d module(s); the register carries no finding at as-of %s.\n",
		page.items, len(roster.Members), o.AsOf)
	return rcOK
}

// findingLine is Finding.String with the id rendered safely: a register id is
// data and may hold a newline.
func findingLine(f Finding) string {
	id := f.ItemID
	if id != "" {
		id = idText(id)
	}
	return Finding{Rule: oneLine(f.Rule), ItemID: id, Detail: oneLine(f.Detail)}.String()
}

// oneLine replaces line breaks and tabs with spaces and keeps everything else,
// so a stderr line stays one line and still equals what `validate` prints.
var oneLine = strings.NewReplacer("\r\n", " ", "\n", " ", "\r", " ", "\t", " ").Replace

func sortFindings(fs []Finding) {
	sort.SliceStable(fs, func(i, j int) bool {
		a, b := fs[i], fs[j]
		if a.Rule != b.Rule {
			return a.Rule < b.Rule
		}
		if a.ItemID != b.ItemID {
			return a.ItemID < b.ItemID
		}
		return a.Detail < b.Detail
	})
}

// installSignalCleanup runs cleanup and then exit(2) on SIGINT or SIGTERM, so
// an interrupted run leaves no private copy behind. The returned stop
// uninstalls the handler.
func installSignalCleanup(cleanup func(), exit func(int)) func() {
	ch := make(chan os.Signal, 1)
	done := make(chan struct{})
	signal.Notify(ch, syscall.SIGINT, syscall.SIGTERM)
	var once sync.Once
	go func() {
		select {
		case <-ch:
			cleanup()
			exit(rcUndet)
		case <-done:
		}
	}()
	return func() {
		once.Do(func() {
			signal.Stop(ch)
			close(done)
		})
	}
}

// snapshotRegister copies the register into a private temporary directory and
// returns the copy's path. The source is only ever read with os file I/O.
func snapshotRegister(src string) (string, func(), error) {
	nop := func() {}
	if src == "" {
		return "", nop, errors.New("no register path given")
	}
	if _, err := os.Lstat(src); err != nil {
		return "", nop, fmt.Errorf("cannot open %s: %w", src, err)
	}
	real, err := filepath.EvalSymlinks(src)
	if err != nil {
		return "", nop, fmt.Errorf("cannot resolve %s: %w", src, err)
	}
	info, err := os.Stat(real)
	if err != nil {
		return "", nop, fmt.Errorf("cannot open %s: %w", real, err)
	}
	if !info.Mode().IsRegular() {
		return "", nop, fmt.Errorf("cannot open %s: not a regular file", src)
	}
	if info.Size() > maxRegisterBytes {
		return "", nop, fmt.Errorf("cannot open %s: %d bytes exceeds the %d-byte cap", src, info.Size(), maxRegisterBytes)
	}
	// Beside the RESOLVED file (where SQLite keeps them) and beside the given
	// path, in case they differ.
	for _, p := range uniq(real, src) {
		if w, err := os.Stat(p + "-wal"); err == nil && w.Size() > 0 {
			return "", nop, fmt.Errorf("%s-wal holds %d byte(s) of uncheckpointed frames: the register's committed state is not all in the main file, and checkpointing it would be a write", p, w.Size())
		}
		if _, err := os.Stat(p + "-journal"); err == nil {
			return "", nop, fmt.Errorf("%s-journal exists: a rollback journal beside the register means a write is in progress or was interrupted, and recovering it would be a write", p)
		}
	}
	first, err := readAll(real)
	if err != nil {
		return "", nop, fmt.Errorf("cannot read %s: %w", src, err)
	}
	if snapshotMidHook != nil {
		snapshotMidHook()
	}
	second, err := readAll(real)
	if err != nil {
		return "", nop, fmt.Errorf("cannot read %s: %w", src, err)
	}
	if sha256.Sum256(first) != sha256.Sum256(second) {
		return "", nop, fmt.Errorf("%s changed while it was being read — re-run on a quiet register", src)
	}
	dir, err := os.MkdirTemp("", "wi-module-report-")
	if err != nil {
		return "", nop, fmt.Errorf("creating a private copy directory: %w", err)
	}
	cleanup := func() { os.RemoveAll(dir) }
	dst := filepath.Join(dir, "register.db")
	if err := os.WriteFile(dst, first, 0o600); err != nil {
		cleanup()
		return "", nop, fmt.Errorf("writing the private copy: %w", err)
	}
	return dst, cleanup, nil
}

func uniq(a, b string) []string {
	if a == b {
		return []string{a}
	}
	return []string{a, b}
}

func readAll(p string) ([]byte, error) {
	f, err := os.Open(p)
	if err != nil {
		return nil, err
	}
	defer f.Close()
	return io.ReadAll(io.LimitReader(f, maxRegisterBytes+1))
}

// ── safe rendering ─────────────────────────────────────────────────────────

// flat collapses every run of whitespace (newlines included) to one space.
func flat(s string) string { return strings.Join(strings.Fields(s), " ") }

var htmlText = strings.NewReplacer("&", "&amp;", "<", "&lt;", ">", "&gt;")

// text renders register text for a Markdown line: one line, HTML-escaped.
func text(s string) string {
	s = flat(s)
	if s == "" {
		return "(none)"
	}
	return htmlText.Replace(s)
}

// code renders a path or identifier as inline code (literal in Markdown, so
// not HTML-escaped; a backtick would end the span and is replaced).
func code(s string) string {
	s = flat(s)
	if s == "" {
		return "(none)"
	}
	return "`" + strings.ReplaceAll(s, "`", "'") + "`"
}

// cell makes a rendered value safe inside a GFM table cell.
func cell(s string) string { return strings.ReplaceAll(s, "|", `\|`) }

// idText renders a register identifier: as-is when it is well formed, quoted
// (every control character escaped) inside a code span when it is not.
func idText(id string) string {
	if _, _, ok := SplitID(id); ok && !strings.ContainsAny(id, "\r\n\t `|<>&") {
		return id
	}
	return "`" + strings.ReplaceAll(strconv.Quote(id), "`", "'") + "`"
}

// titleText truncates to maxTitleRunes and escapes.
func titleText(s string) string {
	s = flat(s)
	if utf8.RuneCountInString(s) > maxTitleRunes {
		r := []rune(s)
		s = string(r[:maxTitleRunes]) + "…"
	}
	return text(s)
}

func orNone(ns sql.NullString) string {
	if !ns.Valid || strings.TrimSpace(ns.String) == "" {
		return "(none)"
	}
	return text(ns.String)
}

func codeOrNone(ns sql.NullString) string {
	if !ns.Valid || strings.TrimSpace(ns.String) == "" {
		return "(none)"
	}
	return code(ns.String)
}

// evidenceLabel turns a history row into "Event (tag check=…)".
func evidenceLabel(h histRow) string {
	label := text(h.event)
	if tag, ok := strings.CutPrefix(h.reason, "zero-gap:"); ok {
		fields := strings.Fields(tag)
		if len(fields) > 0 {
			var parts []string
			if !strings.EqualFold(fields[0], h.event) {
				parts = append(parts, fields[0])
			}
			for _, f := range fields[1:] {
				if strings.HasPrefix(f, "check=") {
					parts = append(parts, f)
				}
			}
			if len(parts) > 0 {
				label += " (" + text(strings.Join(parts, " ")) + ")"
			}
		}
	}
	return label
}

// ── page model ─────────────────────────────────────────────────────────────

type modulePage struct {
	text  []byte
	items int
}

type moduleItem struct {
	row      gapRow
	title    string
	hist     []histRow
	verdicts []verdictRow
	problems []Finding
	undet    []string
}

var severityRank = map[string]int{"critical": 0, "high": 1, "medium": 2, "low": 3}

// dispositionOrder is the order of the sub-sections of a module section.
var dispositionOrder = []struct{ key, heading string }{
	{"open", "Open"},
	{"classified", "Classified (not closed; reason, owner and re-check date below)"},
	{"closed", "Closed"},
	{"", "Unknown disposition"},
}

func dispositionKey(d string) string {
	if inSet(GapDispositions, d) {
		return d
	}
	return ""
}

func buildModulePage(db queryer, roster *Roster, findings []Finding, undetermined []string, asOf string) (*modulePage, error) {
	rows, err := loadGapRows(db)
	if err != nil {
		return nil, err
	}
	titles, err := loadTitles(db)
	if err != nil {
		return nil, err
	}
	hist, err := loadHistory(db)
	if err != nil {
		return nil, err
	}
	verdicts, err := loadVerdicts(db)
	if err != nil {
		return nil, err
	}
	members := roster.ByPrefix()
	legacy, legacyOutside, err := legacyCounts(db, members)
	if err != nil {
		return nil, err
	}

	// One entry per atm_id: the closed row when an id lives in both trackers
	// (the same rule `gap summary` applies, so the two never count differently).
	byID := map[string]gapRow{}
	for _, r := range rows {
		if prev, ok := byID[r.id]; ok && prev.disposition.String == "closed" {
			continue
		}
		byID[r.id] = r
	}
	unplacedIDs := map[string]bool{}
	for _, f := range findings {
		if placementRules[f.Rule] {
			unplacedIDs[f.ItemID] = true
		}
	}

	modules := map[string][]*moduleItem{}
	var unplaced []*moduleItem
	for id, r := range byID {
		it := &moduleItem{row: r, title: titles[id], hist: hist[id], verdicts: verdicts[id]}
		for _, f := range findings {
			if f.ItemID == id {
				it.problems = append(it.problems, f)
			}
		}
		for _, u := range undetermined {
			if strings.Contains(u, " "+id+" ") {
				it.undet = append(it.undet, u)
			}
		}
		prefix, _, _ := SplitID(id)
		if _, known := members[prefix]; unplacedIDs[id] || !known {
			unplaced = append(unplaced, it)
			continue
		}
		modules[prefix] = append(modules[prefix], it)
	}
	for _, items := range modules {
		sortItems(items)
	}
	sortItems(unplaced)

	prefixes := make([]string, 0, len(roster.Members))
	for _, sp := range roster.Members {
		prefixes = append(prefixes, sp.Prefix)
	}
	sort.Strings(prefixes)

	count := func(items []*moduleItem) map[string]int {
		c := map[string]int{"open": 0, "classified": 0, "closed": 0, "": 0}
		for _, it := range items {
			c[dispositionKey(it.row.disposition.String)]++
		}
		return c
	}
	problemsOf := func(items []*moduleItem) int {
		n := 0
		for _, it := range items {
			n += len(it.problems) + len(it.undet)
		}
		return n
	}

	var b bytes.Buffer
	p := func(format string, a ...any) { fmt.Fprintf(&b, format, a...) }

	all := count(nil)
	for _, items := range append(mapValues(modules), unplaced) {
		for k, n := range count(items) {
			all[k] += n
		}
	}
	total := len(byID)

	p("# Zero-gap register — per-module page\n\n")
	p("Generated by `workable-items-vsc report --by-module`. Every count and line below is derived from the\n")
	p("register rows, the roster (`%s`) and the rule set `validate` runs — the base rules plus\n", RosterPath)
	p("V-G1..V-G12 (FR-024); nothing is typed. Register text is shown on one line, HTML-escaped, and\n")
	p("titles are truncated to %d characters.\n\n", maxTitleRunes)
	p("- as-of: %s (every date rule is evaluated at this date)\n", asOf)
	p("- gap items: %d · open %d · classified %d · closed %d · unknown disposition %d\n", total, all["open"], all["classified"], all["closed"], all[""])
	p("- modules: %d · unplaced items: %d\n", len(prefixes), len(unplaced))
	p("- legacy items (no zero-gap schema, not listed): %d · legacy items under prefixes outside the roster: %d\n", sumValues(legacy)+legacyOutside, legacyOutside)
	p("- register problems: %d finding(s) · %d could-not-determine\n", len(findings), len(undetermined))
	p("- could-not-inspect: not stored in the register (sweep output, FR-005)\n")
	p("- %s\n\n", HonestyNotice)
	p("To answer \"what is open, what is closed and how do I know\" for one module: find its row in the\n")
	p("table, jump to its `## <PREFIX>` section, read `### Open`; each item lists its evidence and verdicts.\n\n")

	p("## Modules\n\n")
	p("| Module | Path | Class | Open | Classified | Closed | Problems | Legacy items not listed |\n")
	p("|---|---|---|---:|---:|---:|---:|---:|\n")
	for _, pfx := range prefixes {
		sp := members[pfx]
		c := count(modules[pfx])
		p("| %s | %s | %s | %d | %d | %d | %d | %d |\n", pfx, cell(code(sp.Path)), cell(text(string(sp.Class))),
			c["open"], c["classified"], c["closed"], problemsOf(modules[pfx]), legacy[pfx])
	}
	p("\n")

	p("## Register problems\n\n")
	if len(findings) == 0 && len(undetermined) == 0 {
		p("None: the base rules and V-G1..V-G12 report no finding and no undetermined row at as-of %s.\n\n", asOf)
	} else {
		for _, f := range findings {
			id := "(no id)"
			if f.ItemID != "" {
				id = idText(f.ItemID)
			}
			p("- FINDING %s %s — %s\n", text(f.Rule), id, text(f.Detail))
		}
		for _, u := range undetermined {
			p("- COULD NOT DETERMINE %s\n", text(u))
		}
		p("\n")
	}

	for _, pfx := range prefixes {
		sp := members[pfx]
		items := modules[pfx]
		c := count(items)
		p("## %s — %s (%s)\n\n", pfx, code(sp.Path), text(string(sp.Class)))
		p("Open %d · classified %d · closed %d · problems %d · legacy items not listed here: %d\n\n",
			c["open"], c["classified"], c["closed"], problemsOf(items), legacy[pfx])
		if len(items) == 0 {
			p("No zero-gap item is filed under %s.\n\n", pfx)
			continue
		}
		writeDispositionGroups(&b, items)
	}
	if len(unplaced) > 0 || legacyOutside > 0 {
		p("## Unplaced items\n\n")
		p("These items carry an identifier that is malformed or whose prefix names no module in the roster\n")
		p("(findings id/malformed, id/prefix-not-in-roster), so no module section lists them.\n")
		p("Legacy items under prefixes outside the roster (not listed): %d.\n\n", legacyOutside)
		writeDispositionGroups(&b, unplaced)
	}
	return &modulePage{text: b.Bytes(), items: total}, nil
}

func mapValues(m map[string][]*moduleItem) [][]*moduleItem {
	out := make([][]*moduleItem, 0, len(m))
	for _, v := range m {
		out = append(out, v)
	}
	return out
}

func sumValues(m map[string]int) int {
	n := 0
	for _, v := range m {
		n += v
	}
	return n
}

func sortItems(items []*moduleItem) {
	sort.Slice(items, func(i, j int) bool {
		a, b := items[i].row, items[j].row
		ra, oka := severityRank[a.severity]
		rb, okb := severityRank[b.severity]
		if !oka {
			ra = len(severityRank)
		}
		if !okb {
			rb = len(severityRank)
		}
		if ra != rb {
			return ra < rb
		}
		return a.id < b.id
	})
}

func writeDispositionGroups(b *bytes.Buffer, items []*moduleItem) {
	for _, d := range dispositionOrder {
		var group []*moduleItem
		for _, it := range items {
			if dispositionKey(it.row.disposition.String) == d.key {
				group = append(group, it)
			}
		}
		if len(group) == 0 {
			continue
		}
		fmt.Fprintf(b, "### %s (%d)\n\n", d.heading, len(group))
		for _, it := range group {
			writeItem(b, it)
		}
	}
}

func writeItem(b *bytes.Buffer, it *moduleItem) {
	r := it.row
	p := func(format string, a ...any) { fmt.Fprintf(b, format, a...) }
	p("#### %s — %s\n\n", idText(r.id), titleText(it.title))
	p("- status: %s · disposition: %s · severity: %s · kind: %s · category: %s\n",
		text(r.status), orNone(r.disposition), text(r.severity), orNone(r.kind), orNone(r.category))
	p("- location: %s · owner: %s · found by: %s\n", code(r.anchor), text(r.owner), orNone(r.sweep))
	switch r.disposition.String {
	case "open":
		p("- plan due: %s\n", orNone(r.plan))
	case "classified":
		p("- classified as: %s · owner: %s · re-check by: %s\n", orNone(r.reason), orNone(r.cowner), orNone(r.recheck))
	case "closed":
		p("- research: %s\n", codeOrNone(r.research))
	}
	if r.target.Valid && strings.TrimSpace(r.target.String) != "" {
		p("- measurable target: %s\n", text(r.target.String))
	}
	if r.recurrence.Valid && strings.TrimSpace(r.recurrence.String) != "" {
		p("- recurrence of: %s\n", idText(r.recurrence.String))
	}
	if r.reopens.Valid && r.reopens.Int64 > 0 {
		p("- reopened: %d time(s)\n", r.reopens.Int64)
	}
	cited := 0
	for _, h := range it.hist {
		if strings.TrimSpace(h.evid) != "" {
			cited++
		}
	}
	if cited == 0 {
		p("- evidence: none recorded\n")
	} else {
		p("- evidence (%d, in register order):\n", cited)
		for _, h := range it.hist {
			if strings.TrimSpace(h.evid) == "" {
				continue
			}
			p("  - %s: %s\n", evidenceLabel(h), code(h.evid))
		}
	}
	writeVerdicts(b, it)
	if len(it.problems) == 0 && len(it.undet) == 0 {
		p("- register check: clean\n\n")
		return
	}
	p("- register check: %d problem(s)\n", len(it.problems)+len(it.undet))
	for _, f := range it.problems {
		p("  - FINDING %s — %s\n", text(f.Rule), text(f.Detail))
	}
	for _, u := range it.undet {
		p("  - COULD NOT DETERMINE %s\n", text(u))
	}
	p("\n")
}

func writeVerdicts(b *bytes.Buffer, it *moduleItem) {
	byRole := map[string][]verdictRow{}
	for _, vr := range it.verdicts {
		byRole[vr.role] = append(byRole[vr.role], vr)
	}
	closed := it.row.disposition.String == "closed"
	if len(it.verdicts) == 0 && !closed {
		fmt.Fprintf(b, "- verdicts: none recorded (required only for closure)\n")
		return
	}
	fmt.Fprintf(b, "- verdicts:\n")
	for _, role := range []string{"verifier", "reviewer"} {
		rows := byRole[role]
		if len(rows) == 0 {
			if closed {
				fmt.Fprintf(b, "  - %s: MISSING (a closed item needs one)\n", role)
			} else {
				fmt.Fprintf(b, "  - %s: none recorded\n", role)
			}
			continue
		}
		for _, vr := range rows {
			fmt.Fprintf(b, "  - %s: %s (%s), outcome %d, on %s: %s\n", role, text(vr.actor), text(vr.kind), vr.outcome, text(vr.onDate), code(vr.evid))
		}
	}
}

// loadTitles maps atm_id to title (the Issues row wins when an id is in both).
func loadTitles(db queryer) (map[string]string, error) {
	rows, err := db.Query(`SELECT atm_id, COALESCE(title,'') FROM items ORDER BY atm_id, current_location DESC`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	m := map[string]string{}
	for rows.Next() {
		var id, t string
		if err := rows.Scan(&id, &t); err != nil {
			return nil, err
		}
		m[id] = t
	}
	return m, rows.Err()
}

// legacyCounts counts the distinct ids that are NOT gap items: per roster
// prefix, and in total for prefixes outside the roster (or malformed ids), so
// the page states how much of the register it does not list.
func legacyCounts(db queryer, members map[string]SubProject) (map[string]int, int, error) {
	rows, err := db.Query(`SELECT DISTINCT atm_id FROM items WHERE NOT ` + gapPredicate +
		` AND atm_id NOT IN (SELECT atm_id FROM items WHERE ` + gapPredicate + `)`)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()
	m, outside := map[string]int{}, 0
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			return nil, 0, err
		}
		p, _, ok := SplitID(id)
		if _, known := members[p]; ok && known {
			m[p]++
		} else {
			outside++
		}
	}
	return m, outside, rows.Err()
}
