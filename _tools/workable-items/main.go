// Command workable-items-vsc is the UMBRELLA-LOCAL half of the §11.4.93
// workable-items system for this monorepo.
//
// It is not a second tracker. §11.4.93 places the tracker itself in the
// constitution submodule and says so in terms: "The Go binary lives in the
// constitution submodule (constitution/scripts/workable-items/) so consumers
// reference it from there per §11.4.74 catalogue-first discipline — never
// reimplement." That binary is present at
// submodules/constitution/scripts/workable-items/bin/workable-items-linux and
// it is what creates the schema, adds, updates, closes, exports and validates
// items. This command adds the two things the umbrella needs and the canonical
// binary does not have:
//
//  1. a MULTI-sub-project identifier roster. The canonical tool derives ONE
//     three-letter key from the project root name (prefix.go). This monorepo
//     needs one key per sub-project — VSC/WSP/AII/MVR/VDT and the rest —
//     cross-checked against the fleet derived from .gitmodules.
//  2. the backfill ingestors for this repository's own evidence sources, and a
//     validator that asserts every id's prefix names a real sub-project.
//
// Exit codes are three-valued throughout, and 2 is never a pass:
//
//	0  clean
//	1  a real finding
//	2  could not determine
package main

import (
	"database/sql"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"text/tabwriter"

	"digital.vasic/vasic/workableitems/internal/wi"
)

const (
	exitClean        = 0
	exitFinding      = 1
	exitUndetermined = 2
)

// DefaultDBPath is the canonical location mandated by §11.4.93 ("Database file
// at canonical path docs/workable_items.db") and §11.4.95 (TRACKED in git,
// never gitignored). It is repository-relative and resolved against the
// discovered repository root — never a host path (operator directive,
// 2026-09-08: nothing host-related may be hardcoded).
const DefaultDBPath = "docs/workable_items.db"

func main() { os.Exit(run(os.Args[1:])) }

func usage() {
	fmt.Fprint(os.Stderr, `workable-items-vsc — umbrella sub-project roster, backfill and integrity gate

usage: workable-items-vsc <subcommand> [flags]

  roster        Derive the fleet from .gitmodules + helix-deps.yaml and cross-check
                it against docs/workable-items/sub-projects.tsv.
                0 every declared submodule has an identifier · 1 an orphan row ·
                2 a declared submodule has no identifier (coverage undetermined).
  seed-roster   Write the cross-checked roster into the database's sub_projects table.
  backfill      Ingest operator-decision documents and spec task lists into the DB.
                --dry-run prints what would be written and writes nothing.
  validate      Assert the §11.4.148(D1) status+type+id contract over every item,
                plus §11.4.33 closure vocabulary, §11.4.91 description floor,
                §11.4.54 id uniqueness/sequence, and prefix-in-roster membership.
  report        Read-only tallies by status, type, sub-project and evidence class.

Common flags:
  --repo <dir>   repository root (default: discovered by walking up from CWD)
  --db <path>    database path (default: <repo>/`+DefaultDBPath+`)
`)
}

func run(args []string) int {
	if len(args) == 0 {
		usage()
		return exitUndetermined
	}
	switch args[0] {
	case "roster":
		return cmdRoster(args[1:])
	case "seed-roster":
		return cmdSeedRoster(args[1:])
	case "backfill":
		return cmdBackfill(args[1:])
	case "provenance":
		return cmdProvenance(args[1:])
	case "validate":
		return cmdValidate(args[1:])
	case "report":
		return cmdReport(args[1:])
	case "-h", "--help", "help":
		usage()
		return exitClean
	default:
		fmt.Fprintf(os.Stderr, "unknown subcommand %q\n", args[0])
		usage()
		return exitUndetermined
	}
}

// resolve discovers the repository root and the database path without ever
// consulting a hardcoded host path.
func resolve(fs *flag.FlagSet, repoFlag, dbFlag *string) (root, db string, err error) {
	if *repoFlag != "" {
		root, err = filepath.Abs(*repoFlag)
	} else {
		cwd, e := os.Getwd()
		if e != nil {
			return "", "", e
		}
		root, err = wi.FindRepoRoot(cwd)
	}
	if err != nil {
		return "", "", err
	}
	if *dbFlag != "" {
		db, err = filepath.Abs(*dbFlag)
		return root, db, err
	}
	return root, filepath.Join(root, DefaultDBPath), nil
}

func cmdRoster(args []string) int {
	fs := flag.NewFlagSet("roster", flag.ContinueOnError)
	repo := fs.String("repo", "", "repository root")
	db := fs.String("db", "", "database path (unused by this subcommand)")
	if err := fs.Parse(args); err != nil {
		return exitUndetermined
	}
	root, _, err := resolve(fs, repo, db)
	if err != nil {
		fmt.Fprintf(os.Stderr, "COULD NOT DETERMINE: %v\n", err)
		return exitUndetermined
	}
	r, err := wi.LoadRoster(root)
	if err != nil {
		fmt.Fprintf(os.Stderr, "COULD NOT DETERMINE: %v\n", err)
		return exitUndetermined
	}
	names, err := wi.ManifestNames(root)
	if err != nil {
		fmt.Fprintf(os.Stderr, "COULD NOT DETERMINE: reading helix-deps.yaml: %v\n", err)
		return exitUndetermined
	}

	w := tabwriter.NewWriter(os.Stdout, 0, 0, 2, ' ', 0)
	fmt.Fprintln(w, "PREFIX\tPATH\tCLASS\tRATIFIED\tDECLARED")
	operator, proposed := 0, 0
	for _, sp := range r.Members {
		declared := "yes"
		if !sp.Declared {
			declared = "NO — orphan row"
		}
		if sp.Ratified == "operator" {
			operator++
		} else {
			proposed++
		}
		fmt.Fprintf(w, "%s\t%s\t%s\t%s\t%s\n", sp.Prefix, sp.Path, sp.Class, sp.Ratified, declared)
	}
	w.Flush()

	fmt.Printf("\n%d identifier(s): %d ratified by the operator, %d PROPOSED and awaiting ratification.\n",
		len(r.Members), operator, proposed)
	fmt.Printf("helix-deps.yaml records %d dep name(s); .gitmodules declares %d submodule(s).\n",
		len(names), len(r.Members)-1+len(r.Undetermined)-orphanCount(r))

	rc := exitClean
	for _, o := range r.Orphans {
		fmt.Printf("FINDING — roster row for %q names no declared submodule.\n", o)
		rc = exitFinding
	}
	if len(r.Undetermined) > 0 {
		fmt.Printf("COULD NOT DETERMINE — %d declared submodule(s) carry no identifier: %s\n",
			len(r.Undetermined), strings.Join(r.Undetermined, ", "))
		if rc == exitClean {
			rc = exitUndetermined
		}
	}
	if rc == exitClean {
		fmt.Println("OK — every declared submodule carries exactly one identifier, and every identifier names a declared submodule.")
	}
	return rc
}

func orphanCount(r *wi.Roster) int { return len(r.Orphans) }

func cmdSeedRoster(args []string) int {
	fs := flag.NewFlagSet("seed-roster", flag.ContinueOnError)
	repo := fs.String("repo", "", "repository root")
	dbPath := fs.String("db", "", "database path")
	if err := fs.Parse(args); err != nil {
		return exitUndetermined
	}
	root, dbp, err := resolve(fs, repo, dbPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "COULD NOT DETERMINE: %v\n", err)
		return exitUndetermined
	}
	r, err := wi.LoadRoster(root)
	if err != nil {
		fmt.Fprintf(os.Stderr, "COULD NOT DETERMINE: %v\n", err)
		return exitUndetermined
	}
	db, err := wi.Open(dbp)
	if err != nil {
		fmt.Fprintf(os.Stderr, "COULD NOT DETERMINE: %v\n", err)
		return exitUndetermined
	}
	defer db.Close()
	if err := wi.SyncRoster(db, r); err != nil {
		fmt.Fprintf(os.Stderr, "FINDING: %v\n", err)
		return exitFinding
	}
	fmt.Printf("seed-roster: %d sub-project row(s) written to %s\n", len(r.Members), dbp)
	return exitClean
}

func cmdBackfill(args []string) int {
	fs := flag.NewFlagSet("backfill", flag.ContinueOnError)
	repo := fs.String("repo", "", "repository root")
	dbPath := fs.String("db", "", "database path")
	dry := fs.Bool("dry-run", false, "parse and report; write nothing")
	if err := fs.Parse(args); err != nil {
		return exitUndetermined
	}
	root, dbp, err := resolve(fs, repo, dbPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "COULD NOT DETERMINE: %v\n", err)
		return exitUndetermined
	}
	r, err := wi.LoadRoster(root)
	if err != nil {
		fmt.Fprintf(os.Stderr, "COULD NOT DETERMINE: %v\n", err)
		return exitUndetermined
	}

	var all []wi.Item
	perSource := map[string]int{}

	decisions, err := wi.DecisionDocs(root)
	if err != nil {
		fmt.Fprintf(os.Stderr, "COULD NOT DETERMINE: %v\n", err)
		return exitUndetermined
	}
	for _, p := range decisions {
		items, err := wi.ParseDecisionDoc(root, p, r)
		if err != nil {
			fmt.Fprintf(os.Stderr, "COULD NOT DETERMINE: parsing %s: %v\n", p, err)
			return exitUndetermined
		}
		rel, _ := filepath.Rel(root, p)
		perSource[rel] = len(items)
		all = append(all, items...)
	}

	specs, err := wi.SpecTaskFiles(root)
	if err != nil {
		fmt.Fprintf(os.Stderr, "COULD NOT DETERMINE: %v\n", err)
		return exitUndetermined
	}
	for _, p := range specs {
		items, err := wi.ParseSpecTasks(root, p, r)
		if err != nil {
			fmt.Fprintf(os.Stderr, "COULD NOT DETERMINE: parsing %s: %v\n", p, err)
			return exitUndetermined
		}
		rel, _ := filepath.Rel(root, p)
		perSource[rel] = len(items)
		all = append(all, items...)
	}

	if len(all) == 0 {
		fmt.Fprintln(os.Stderr, "COULD NOT DETERMINE: no source document yielded a single item — the ingestors read nothing, which is not the same as there being nothing to read")
		return exitUndetermined
	}

	keys := make([]string, 0, len(perSource))
	for k := range perSource {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	fmt.Println("SOURCES READ")
	for _, k := range keys {
		fmt.Printf("  %-64s %4d row(s)\n", k, perSource[k])
	}

	if *dry {
		fmt.Printf("\ndry-run: %d item(s) parsed; nothing written.\n", len(all))
		printPlan(all)
		return exitClean
	}

	db, err := wi.Open(dbp)
	if err != nil {
		fmt.Fprintf(os.Stderr, "COULD NOT DETERMINE: %v\n", err)
		return exitUndetermined
	}
	defer db.Close()

	prefixes := make([]string, 0, len(r.Members))
	for _, sp := range r.Members {
		prefixes = append(prefixes, sp.Prefix)
	}
	next, err := wi.NextIDs(db, prefixes)
	if err != nil {
		fmt.Fprintf(os.Stderr, "COULD NOT DETERMINE: %v\n", err)
		return exitUndetermined
	}
	allocated := wi.AllocateIDs(all, next)
	ins, skipped, err := wi.InsertItems(db, allocated)
	if err != nil {
		fmt.Fprintf(os.Stderr, "FINDING: %v\n", err)
		return exitFinding
	}
	fmt.Printf("\nbackfill: %d item(s) inserted, %d already present (idempotent skip).\n", ins, skipped)
	printPlan(allocated)
	return exitClean
}

func printPlan(items []wi.Item) {
	byPrefix := map[string]int{}
	byStatus := map[string]int{}
	byEvidence := map[string]int{}
	for _, it := range items {
		p := it.ID
		if pfx, _, ok := wi.SplitID(it.ID); ok {
			p = pfx
		}
		byPrefix[p]++
		byStatus[it.Status]++
		byEvidence[it.EvidenceClass]++
	}
	printMap("BY SUB-PROJECT", byPrefix)
	printMap("BY STATUS", byStatus)
	printMap("BY EVIDENCE CLASS", byEvidence)
}

func printMap(title string, m map[string]int) {
	keys := make([]string, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	fmt.Println("\n" + title)
	for _, k := range keys {
		fmt.Printf("  %-24s %4d\n", k, m[k])
	}
}

// cmdProvenance attaches a provenance row to an item that was created outside
// the backfill ingestors — for instance one added with the canonical binary.
// It is explicit and manual on purpose: auto-attaching provenance to whatever
// row happens to lack one would invent the very attribution this table exists
// to make auditable.
func cmdProvenance(args []string) int {
	fs := flag.NewFlagSet("provenance", flag.ContinueOnError)
	repo := fs.String("repo", "", "repository root")
	dbPath := fs.String("db", "", "database path")
	id := fs.String("id", "", "item identifier")
	kind := fs.String("kind", "", "source kind: operator-decision | spec-task | session-work")
	path := fs.String("path", "", "source path, repository-relative")
	locator := fs.String("locator", "", "locator within the source")
	class := fs.String("evidence-class", "", "document-assertion | checkbox-state | undetermined")
	note := fs.String("note", "", "what the status rests on")
	if err := fs.Parse(args); err != nil {
		return exitUndetermined
	}
	if *id == "" || *kind == "" || *path == "" || *locator == "" || *class == "" {
		fmt.Fprintln(os.Stderr, "COULD NOT DETERMINE: --id, --kind, --path, --locator and --evidence-class are all required")
		return exitUndetermined
	}
	_, dbp, err := resolve(fs, repo, dbPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "COULD NOT DETERMINE: %v\n", err)
		return exitUndetermined
	}
	db, err := wi.Open(dbp)
	if err != nil {
		fmt.Fprintf(os.Stderr, "COULD NOT DETERMINE: %v\n", err)
		return exitUndetermined
	}
	defer db.Close()
	var n int
	if err := db.QueryRow(`SELECT count(*) FROM items WHERE atm_id = ?`, *id).Scan(&n); err != nil || n == 0 {
		fmt.Fprintf(os.Stderr, "FINDING: no item %q exists — provenance may not be attached to a row that is not there\n", *id)
		return exitFinding
	}
	if _, err := db.Exec(`INSERT OR REPLACE INTO item_provenance
        (atm_id,source_kind,source_path,source_locator,evidence_class,status_note)
        VALUES (?,?,?,?,?,?)`, *id, *kind, *path, *locator, *class, *note); err != nil {
		fmt.Fprintf(os.Stderr, "FINDING: %v\n", err)
		return exitFinding
	}
	fmt.Printf("provenance: %s <- %s %s (%s)\n", *id, *kind, *path, *class)
	return exitClean
}

func cmdValidate(args []string) int {
	fs := flag.NewFlagSet("validate", flag.ContinueOnError)
	repo := fs.String("repo", "", "repository root")
	dbPath := fs.String("db", "", "database path")
	if err := fs.Parse(args); err != nil {
		return exitUndetermined
	}
	root, dbp, err := resolve(fs, repo, dbPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "COULD NOT DETERMINE: %v\n", err)
		return exitUndetermined
	}
	r, rosterErr := wi.LoadRoster(root)
	if rosterErr != nil {
		fmt.Fprintf(os.Stderr, "COULD NOT DETERMINE: reading the roster: %v\n", rosterErr)
		return exitUndetermined
	}
	db, err := wi.Open(dbp)
	if err != nil {
		fmt.Fprintf(os.Stderr, "COULD NOT DETERMINE: %v\n", err)
		return exitUndetermined
	}
	defer db.Close()

	rep, err := wi.Validate(db, r)
	if err != nil {
		fmt.Fprintf(os.Stderr, "COULD NOT DETERMINE: %v\n", err)
		return exitUndetermined
	}
	for _, f := range rep.Findings {
		fmt.Println("FINDING  " + f.String())
	}
	for _, u := range rep.Undetermined {
		fmt.Println("UNDET    " + u)
	}
	rc := rep.ExitCode()
	switch rc {
	case exitClean:
		fmt.Printf("OK — %d item(s); every item carries a valid status, a valid type and a unique id whose prefix names a roster sub-project.\n", rep.Items)
	case exitFinding:
		fmt.Printf("FAIL — %d item(s), %d finding(s).\n", rep.Items, len(rep.Findings))
	default:
		fmt.Printf("COULD NOT DETERMINE — %d item(s), %d unresolved condition(s). A 2 is never a pass.\n", rep.Items, len(rep.Undetermined))
	}
	return rc
}

func cmdReport(args []string) int {
	fs := flag.NewFlagSet("report", flag.ContinueOnError)
	repo := fs.String("repo", "", "repository root")
	dbPath := fs.String("db", "", "database path")
	if err := fs.Parse(args); err != nil {
		return exitUndetermined
	}
	_, dbp, err := resolve(fs, repo, dbPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "COULD NOT DETERMINE: %v\n", err)
		return exitUndetermined
	}
	db, err := wi.Open(dbp)
	if err != nil {
		fmt.Fprintf(os.Stderr, "COULD NOT DETERMINE: %v\n", err)
		return exitUndetermined
	}
	defer db.Close()

	if err := section(db, "BY STATUS", "status"); err != nil {
		fmt.Fprintf(os.Stderr, "COULD NOT DETERMINE: %v\n", err)
		return exitUndetermined
	}
	if err := section(db, "BY TYPE", "type"); err != nil {
		fmt.Fprintf(os.Stderr, "COULD NOT DETERMINE: %v\n", err)
		return exitUndetermined
	}
	if err := section(db, "BY LOCATION", "current_location"); err != nil {
		fmt.Fprintf(os.Stderr, "COULD NOT DETERMINE: %v\n", err)
		return exitUndetermined
	}
	rows, err := wi.TallyByPrefix(db)
	if err != nil {
		fmt.Fprintf(os.Stderr, "COULD NOT DETERMINE: %v\n", err)
		return exitUndetermined
	}
	fmt.Println("\nBY SUB-PROJECT")
	for _, r := range rows {
		fmt.Printf("  %-24s %s\n", r[0], r[1])
	}
	if err := evidenceSection(db); err != nil {
		fmt.Fprintf(os.Stderr, "COULD NOT DETERMINE: %v\n", err)
		return exitUndetermined
	}
	return exitClean
}

func section(db *sql.DB, title, column string) error {
	rows, err := wi.Tally(db, column)
	if err != nil {
		return err
	}
	fmt.Println("\n" + title)
	for _, r := range rows {
		fmt.Printf("  %-24s %s\n", r[0], r[1])
	}
	return nil
}

func evidenceSection(db *sql.DB) error {
	rows, err := db.Query(`SELECT evidence_class, source_kind, count(*) FROM item_provenance GROUP BY 1,2 ORDER BY 3 DESC`)
	if err != nil {
		return err
	}
	defer rows.Close()
	fmt.Println("\nBY EVIDENCE CLASS × SOURCE")
	for rows.Next() {
		var ec, sk string
		var n int
		if err := rows.Scan(&ec, &sk, &n); err != nil {
			return err
		}
		fmt.Printf("  %-20s %-20s %d\n", ec, sk, n)
	}
	return rows.Err()
}
