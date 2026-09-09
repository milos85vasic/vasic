package wi

import (
	"database/sql"
	"fmt"
	"sort"
	"strings"
)

// The §11.4.15 + §11.4.21 + §11.4.90 status closed set, spelled exactly as the
// canonical schema's CHECK constraint spells it. These constants exist so a
// typo is a compile error here rather than a constraint violation at run time.
const (
	StatusQueued      = "Queued"
	StatusInProgress  = "In progress"
	StatusReadyTest   = "Ready for testing"
	StatusInTesting   = "In testing"
	StatusReopened    = "Reopened"
	StatusBlocked     = "Operator-blocked"
	StatusFixed       = "Fixed (→ Fixed.md)"
	StatusImplemented = "Implemented (→ Fixed.md)"
	StatusCompleted   = "Completed (→ Fixed.md)"
	StatusObsolete    = "Obsolete (→ Fixed.md)"
)

// The §11.4.16 type closed set.
const (
	TypeBug     = "Bug"
	TypeFeature = "Feature"
	TypeTask    = "Task"
)

// closureFor is the §11.4.33 type-aware closure vocabulary, verbatim from the
// anchor's own three-row table: Bug -> Fixed, Feature -> Implemented,
// Task -> Completed. Obsolete is §11.4.90's fourth terminal value and applies
// regardless of type, so it is handled separately.
var closureFor = map[string]string{
	TypeBug:     StatusFixed,
	TypeFeature: StatusImplemented,
	TypeTask:    StatusCompleted,
}

// ClosureFor returns the §11.4.33 terminal status for an item type.
func ClosureFor(itemType string) string { return closureFor[itemType] }

var validStatus = map[string]bool{
	StatusQueued: true, StatusInProgress: true, StatusReadyTest: true,
	StatusInTesting: true, StatusReopened: true, StatusBlocked: true,
	StatusFixed: true, StatusImplemented: true, StatusCompleted: true,
	StatusObsolete: true,
}

var validType = map[string]bool{TypeBug: true, TypeFeature: true, TypeTask: true}

// Finding is one integrity violation.
type Finding struct {
	Rule   string
	ItemID string
	Detail string
}

func (f Finding) String() string {
	id := f.ItemID
	if id == "" {
		id = "(no id)"
	}
	return fmt.Sprintf("%-28s %-12s %s", f.Rule, id, f.Detail)
}

// Report is the validator's three-valued result.
type Report struct {
	Items        int
	Findings     []Finding
	Undetermined []string
}

// Validate walks every item and asserts the §11.4.148(D1) integrity contract —
// "every workable item, at every moment, MUST carry (i) a **Status:** from the
// §11.4.15 / §11.4.21 / §11.4.90 closed set, (ii) a **Type:** from the
// §11.4.16 closed set {Bug | Feature | Task}, and (iii) a stable, unique,
// monotonic, append-only [<ID-NNN>] identifier per §11.4.54" — plus the
// umbrella's own addition: the id's PREFIX must name a real roster sub-project.
//
// It is three-valued. An unreadable roster or an empty item set is
// UNDETERMINED (rc 2), never a pass: a validator that reports OK over a table
// it could not read is the false-green this repository's registry exists to
// prevent.
func Validate(db *sql.DB, r *Roster) (*Report, error) {
	rep := &Report{}

	if r == nil {
		rep.Undetermined = append(rep.Undetermined, "no roster supplied — prefix membership cannot be checked")
	}
	var known map[string]SubProject
	if r != nil {
		known = r.ByPrefix()
		if len(r.Undetermined) > 0 {
			rep.Undetermined = append(rep.Undetermined, fmt.Sprintf(
				"%d declared submodule(s) carry no roster row: %s",
				len(r.Undetermined), strings.Join(r.Undetermined, ", ")))
		}
		for _, o := range r.Orphans {
			rep.Findings = append(rep.Findings, Finding{
				Rule: "roster/orphan-row", Detail: fmt.Sprintf("roster row for %q names no declared submodule", o)})
		}
	}

	rows, err := db.Query(`SELECT atm_id, type, status, title, description, current_location FROM items`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	seen := map[string]int{}
	perPrefix := map[string][]int{}
	for rows.Next() {
		var id, typ, status, title, desc, loc sql.NullString
		if err := rows.Scan(&id, &typ, &status, &title, &desc, &loc); err != nil {
			return nil, err
		}
		rep.Items++
		itemID := id.String

		// (iii) identifier present and well-formed.
		prefix, n, ok := SplitID(itemID)
		if !ok {
			rep.Findings = append(rep.Findings, Finding{
				Rule: "id/malformed", ItemID: itemID,
				Detail: "identifier is not <THREE-UPPERCASE>-<positive integer>"})
		} else {
			perPrefix[prefix] = append(perPrefix[prefix], n)
			if known != nil {
				sp, in := known[prefix]
				if !in {
					rep.Findings = append(rep.Findings, Finding{
						Rule: "id/prefix-not-in-roster", ItemID: itemID,
						Detail: fmt.Sprintf("prefix %q names no sub-project in %s", prefix, RosterPath)})
				} else if sp.Class == ClassThirdParty {
					rep.Findings = append(rep.Findings, Finding{
						Rule: "id/prefix-third-party", ItemID: itemID,
						Detail: fmt.Sprintf("prefix %q is reserved for third-party %q; no item may be filed against it", prefix, sp.Path)})
				}
			}
		}

		// Uniqueness across the (atm_id, current_location) composite: the same
		// id in the SAME location twice is a duplicate; the same id in Issues
		// AND Fixed is the canonical schema's documented tombstone shape and is
		// legitimate, so the key includes the location.
		key := itemID + "@" + loc.String
		seen[key]++
		if seen[key] > 1 {
			rep.Findings = append(rep.Findings, Finding{
				Rule: "id/duplicate", ItemID: itemID,
				Detail: fmt.Sprintf("appears %d times in %s", seen[key], loc.String)})
		}

		// (ii) type from the closed set.
		if !typ.Valid || typ.String == "" {
			rep.Findings = append(rep.Findings, Finding{Rule: "type/missing", ItemID: itemID, Detail: "no type"})
		} else if !validType[typ.String] {
			rep.Findings = append(rep.Findings, Finding{
				Rule: "type/not-in-closed-set", ItemID: itemID,
				Detail: fmt.Sprintf("%q is outside {Bug, Feature, Task}", typ.String)})
		}

		// (i) status from the closed set.
		if !status.Valid || status.String == "" {
			rep.Findings = append(rep.Findings, Finding{Rule: "status/missing", ItemID: itemID, Detail: "no status"})
		} else if !validStatus[status.String] {
			rep.Findings = append(rep.Findings, Finding{
				Rule: "status/not-in-closed-set", ItemID: itemID,
				Detail: fmt.Sprintf("%q is outside the §11.4.15/§11.4.21/§11.4.90 closed set", status.String)})
		}

		// §11.4.33 type-aware closure vocabulary.
		if validType[typ.String] && validStatus[status.String] {
			terminal := status.String == StatusFixed || status.String == StatusImplemented || status.String == StatusCompleted
			if terminal && closureFor[typ.String] != status.String {
				rep.Findings = append(rep.Findings, Finding{
					Rule: "closure/type-mismatch", ItemID: itemID,
					Detail: fmt.Sprintf("type %s closes as %q, not %q", typ.String, closureFor[typ.String], status.String)})
			}
		}

		// §11.4.91 description floor: >= 6 words OR >= 40 characters.
		d := strings.TrimSpace(desc.String)
		if len(d) < 40 && len(strings.Fields(d)) < 6 {
			rep.Findings = append(rep.Findings, Finding{
				Rule: "description/below-floor", ItemID: itemID,
				Detail: fmt.Sprintf("%d chars / %d words — below the §11.4.91 floor", len(d), len(strings.Fields(d)))})
		}

		if strings.TrimSpace(title.String) == "" {
			rep.Findings = append(rep.Findings, Finding{Rule: "title/empty", ItemID: itemID, Detail: "no title"})
		}
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}

	// §11.4.54(4): gaps are forbidden in the assignment sequence.
	for prefix, ns := range perPrefix {
		sort.Ints(ns)
		uniq := ns[:0:0]
		for i, n := range ns {
			if i == 0 || n != ns[i-1] {
				uniq = append(uniq, n)
			}
		}
		for i, n := range uniq {
			if n != i+1 {
				rep.Findings = append(rep.Findings, Finding{
					Rule: "id/sequence-gap", ItemID: FormatID(prefix, n),
					Detail: fmt.Sprintf("expected %s at position %d — the sequence has a gap", FormatID(prefix, i+1), i+1)})
				break
			}
		}
	}

	if rep.Items == 0 {
		rep.Undetermined = append(rep.Undetermined,
			"the items table is empty — no integrity claim can be made about an empty set")
	}

	// Every item must carry a provenance row, so no status is unattributable.
	var orphanProv int
	if err := db.QueryRow(`SELECT count(*) FROM (SELECT DISTINCT atm_id FROM items) i
        WHERE NOT EXISTS (SELECT 1 FROM item_provenance p WHERE p.atm_id = i.atm_id)`).Scan(&orphanProv); err == nil && orphanProv > 0 {
		rep.Findings = append(rep.Findings, Finding{
			Rule: "provenance/missing", Detail: fmt.Sprintf("%d item(s) carry no item_provenance row", orphanProv)})
	}

	sort.SliceStable(rep.Findings, func(i, j int) bool {
		if rep.Findings[i].Rule != rep.Findings[j].Rule {
			return rep.Findings[i].Rule < rep.Findings[j].Rule
		}
		return rep.Findings[i].ItemID < rep.Findings[j].ItemID
	})
	return rep, nil
}

// ExitCode maps a report onto the three-valued contract used throughout this
// repository: 0 clean, 1 a real finding, 2 could not determine. A finding
// OUTRANKS an undetermined row, so an instrument that cannot read part of the
// tree can never mask a violation it did read.
func (r *Report) ExitCode() int {
	if len(r.Findings) > 0 {
		return 1
	}
	if len(r.Undetermined) > 0 {
		return 2
	}
	return 0
}
