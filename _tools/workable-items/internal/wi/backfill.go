package wi

import (
	"bufio"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
)

// ── Sub-project attribution ─────────────────────────────────────────────────
//
// An item's sub-project is DERIVED from paths the source row actually names,
// never guessed. A row naming no path, or naming paths belonging to more than
// one sub-project, is attributed to the parent VSC — which is the truthful
// answer, because the source document itself lives in the umbrella. Guessing a
// sub-project from subject matter would be exactly the fabrication §11.4.6
// forbids, and it would be invisible afterwards.

// attributionOrder fixes the precedence when a row names paths in more than one
// sub-project: the longest path wins, so `submodules/curriculum-kit` is not
// swallowed by a bare `submodules` mention. Ties fall back to the parent.
func attribute(text string, r *Roster) (prefix string, why string) {
	type hit struct {
		prefix string
		path   string
	}
	var hits []hit
	for _, sp := range r.Members {
		if sp.Path == "." {
			continue
		}
		if sp.Class == ClassThirdParty {
			continue
		}
		// A path mention must be bounded so `design-toolkit` does not match
		// inside `my-design-toolkit-fork`. The two boundaries are asymmetric on
		// purpose: on the LEFT nothing path-shaped may precede the mention
		// (including a `/`, which would make it a different path), while on the
		// RIGHT a `/` or `.` is a legitimate CONTINUATION — `workshop/platform`
		// names `workshop` — and only a further name character is not.
		idx := strings.Index(text, sp.Path)
		for idx >= 0 {
			okLeft := idx == 0 || (!isNameRune(rune(text[idx-1])) && text[idx-1] != '/')
			end := idx + len(sp.Path)
			okRight := end >= len(text) || !isNameRune(rune(text[end]))
			if okLeft && okRight {
				hits = append(hits, hit{sp.Prefix, sp.Path})
				break
			}
			next := strings.Index(text[idx+1:], sp.Path)
			if next < 0 {
				break
			}
			idx = idx + 1 + next
		}
	}
	if len(hits) == 0 {
		return "VSC", "no sub-project path named in the source row"
	}
	sort.Slice(hits, func(i, j int) bool { return len(hits[i].path) > len(hits[j].path) })
	distinct := map[string]bool{}
	for _, h := range hits {
		distinct[h.prefix] = true
	}
	if len(distinct) > 1 {
		names := make([]string, 0, len(distinct))
		for k := range distinct {
			names = append(names, k)
		}
		sort.Strings(names)
		return "VSC", "the source row names paths in more than one sub-project (" + strings.Join(names, ", ") + "), so it is attributed to the parent"
	}
	return hits[0].prefix, "the source row names the path " + hits[0].path
}

// isNameRune reports whether r can be part of a single path SEGMENT name.
// Separators (`/`, `.`) are deliberately excluded: they end a segment.
func isNameRune(r rune) bool {
	return r == '_' || r == '-' ||
		(r >= 'a' && r <= 'z') || (r >= 'A' && r <= 'Z') || (r >= '0' && r <= '9')
}

// ── Operator-decision documents (§11.4.208) ─────────────────────────────────

var decisionRowRe = regexp.MustCompile(`^\|\s*([0-9]+[a-z]?)\s*\|(.*)\|\s*$`)

// DecisionDocs finds every operator-decision document under docs/.
func DecisionDocs(root string) ([]string, error) {
	matches, err := filepath.Glob(filepath.Join(root, "docs", "OPERATOR-DECISIONS-*.md"))
	if err != nil {
		return nil, err
	}
	sort.Strings(matches)
	return matches, nil
}

// statusFromDecisionCell maps the document's own Status cell onto the closed
// set. The mapping is deliberately conservative and never upgrades: a decision
// RECORDED is not work COMPLETED, so DECIDED lands on Queued.
//
// Returns the status, the evidence class, and a note. An unmapped cell is
// recorded as Queued with an explicit UNKNOWN note rather than a guess.
func statusFromDecisionCell(cell string) (status, evidenceClass, note string) {
	c := strings.ToUpper(strings.TrimSpace(cell))
	switch {
	case c == "":
		return StatusQueued, "undetermined",
			"UNKNOWN: the source row carries an empty Status cell; recorded conservatively as Queued"
	case strings.Contains(c, "WITHDRAWN"):
		return StatusObsolete, "document-assertion",
			"the source row is marked WITHDRAWN and names its superseding row"
	case strings.Contains(c, "DONE") && strings.Contains(c, "OPEN"):
		return StatusInProgress, "document-assertion",
			"the source row is split — part DONE, part still OPEN — so neither a terminal status nor Queued is true; recorded as In progress"
	case strings.Contains(c, "DONE"):
		return StatusCompleted, "document-assertion",
			"CLOSURE EVIDENCE CLASS: the operator-decision document ASSERTS this row is DONE. That assertion was NOT re-verified by a run in the backfill session (§11.4.6)."
	case strings.Contains(c, "IN FLIGHT"):
		return StatusInProgress, "document-assertion", "the source row is marked IN FLIGHT"
	case strings.Contains(c, "DECIDED"), strings.Contains(c, "PENDING"):
		return StatusQueued, "document-assertion",
			"the source row records a DECISION, not an execution: the decision is made and the work is not evidenced complete"
	default:
		return StatusQueued, "undetermined",
			fmt.Sprintf("UNKNOWN: the source Status cell %q maps to no closed-set value; recorded conservatively as Queued", strings.TrimSpace(cell))
	}
}

// ParseDecisionDoc extracts one item per numbered decision row.
func ParseDecisionDoc(root, path string, r *Roster) ([]Item, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()

	rel, err := filepath.Rel(root, path)
	if err != nil {
		rel = path
	}
	docDate := strings.TrimSuffix(strings.TrimPrefix(filepath.Base(path), "OPERATOR-DECISIONS-"), ".md")

	var items []Item
	sc := bufio.NewScanner(f)
	sc.Buffer(make([]byte, 0, 64*1024), 4*1024*1024)
	lineNo := 0
	for sc.Scan() {
		lineNo++
		m := decisionRowRe.FindStringSubmatch(sc.Text())
		if m == nil {
			continue
		}
		num := m[1]
		cols := strings.Split(m[2], "|")
		if len(cols) < 3 {
			continue
		}
		question := strings.TrimSpace(cols[0])
		decision := strings.TrimSpace(cols[1])
		statusCell := strings.TrimSpace(cols[len(cols)-1])
		if question == "" || decision == "" {
			continue
		}

		status, evClass, note := statusFromDecisionCell(statusCell)
		prefix, why := attribute(question+" "+decision, r)

		desc := strings.Join([]string{
			"WHAT — operator decision " + num + " of " + docDate + ". The question put to the operator was: " + question,
			"DECISION — " + decision,
			"HOW IT MANIFESTS — the decision is recorded in " + rel + " row " + num + "; that document is the §11.4.208 operator-request ledger for the session.",
			"HOW TO REPRODUCE — read " + rel + ", table row " + num + ".",
			"ACCEPTANCE CRITERIA — the obligation the decision states is discharged with captured evidence per §11.4.5, recorded against this item.",
			"STATUS BASIS — " + note,
			"SUB-PROJECT BASIS — " + why + ".",
		}, "\n\n")

		items = append(items, Item{
			Type:            TypeTask,
			Status:          status,
			Severity:        "",
			Title:           "operator decision " + docDate + " #" + num + " — " + truncate(question, 90),
			Description:     desc,
			CurrentLocation: locationFor(status),
			CreatedBy:       "User",
			ForensicAnchor:  rel + " row " + num,
			SourceKind:      "operator-decision",
			SourcePath:      rel,
			SourceLocator:   "row " + num,
			EvidenceClass:   evClass,
			StatusNote:      note,
			ID:              prefix, // prefix only; the caller allocates the number
		})
	}
	return items, sc.Err()
}

// ── Spec task lists ─────────────────────────────────────────────────────────

var taskRowRe = regexp.MustCompile(`^\s*-\s*\[([ xX])\]\s*(?:\*\*)?(T[0-9]+)\b(.*)$`)

// SpecTaskFiles finds every specs/*/tasks.md.
func SpecTaskFiles(root string) ([]string, error) {
	matches, err := filepath.Glob(filepath.Join(root, "specs", "*", "tasks.md"))
	if err != nil {
		return nil, err
	}
	sort.Strings(matches)
	return matches, nil
}

var blockedRe = regexp.MustCompile(`\[BLOCKED:\s*([^\]]*)\]`)

// ParseSpecTasks extracts one item per T-numbered task row.
func ParseSpecTasks(root, path string, r *Roster) ([]Item, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()

	rel, err := filepath.Rel(root, path)
	if err != nil {
		rel = path
	}
	feature := filepath.Base(filepath.Dir(path))

	var items []Item
	sc := bufio.NewScanner(f)
	sc.Buffer(make([]byte, 0, 64*1024), 8*1024*1024)
	for sc.Scan() {
		m := taskRowRe.FindStringSubmatch(sc.Text())
		if m == nil {
			continue
		}
		mark, taskID, rest := m[1], m[2], strings.TrimSpace(m[3])
		if rest == "" {
			rest = "(the source row carries no text beyond its identifier)"
		}

		var status, evClass, note string
		if mark == "x" || mark == "X" {
			status, evClass = StatusCompleted, "checkbox-state"
			note = "CLOSURE EVIDENCE CLASS: the tracked task list marks this row [x]. The completion mark is the evidence; the work it claims was NOT re-verified by a run in the backfill session (§11.4.6)."
		} else {
			status, evClass = StatusQueued, "checkbox-state"
			note = "the tracked task list marks this row [ ] — not started or not finished"
			if b := blockedRe.FindStringSubmatch(rest); b != nil {
				note = "the tracked task list marks this row [ ] and annotates it " +
					"[BLOCKED: " + strings.TrimSpace(b[1]) + "]. Recorded as Queued rather than " +
					"Operator-blocked because §11.4.21 + §11.4.148(D3) require a WHY, an " +
					"exhausted-alternatives statement and an enumerated set of unblock CHOICES, " +
					"and the source row supplies none of the three. Inventing them to reach the " +
					"stronger status would be the fabrication §11.4.6 forbids."
			}
		}

		prefix, why := attribute(rest, r)

		desc := strings.Join([]string{
			"WHAT — " + feature + " task " + taskID + ": " + rest,
			"HOW IT MANIFESTS — the task is tracked in " + rel + " as row " + taskID + ".",
			"HOW TO REPRODUCE — read " + rel + " and locate the row beginning `" + taskID + "`.",
			"ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.",
			"STATUS BASIS — " + note,
			"SUB-PROJECT BASIS — " + why + ".",
		}, "\n\n")

		items = append(items, Item{
			Type:            TypeTask,
			Status:          status,
			Title:           feature + " " + taskID + " — " + truncate(rest, 90),
			Description:     desc,
			CurrentLocation: locationFor(status),
			CreatedBy:       "AI",
			ForensicAnchor:  rel + " " + taskID,
			SourceKind:      "spec-task",
			SourcePath:      rel,
			SourceLocator:   taskID,
			EvidenceClass:   evClass,
			StatusNote:      note,
			ID:              prefix,
		})
	}
	return items, sc.Err()
}

func locationFor(status string) string {
	switch status {
	case StatusFixed, StatusImplemented, StatusCompleted, StatusObsolete:
		return "Fixed"
	}
	return "Issues"
}

func truncate(s string, n int) string {
	s = strings.Join(strings.Fields(s), " ")
	// Strip Markdown emphasis and code fences so a title reads as a title.
	s = strings.NewReplacer("**", "", "`", "").Replace(s)
	if len(s) <= n {
		return s
	}
	cut := s[:n]
	if i := strings.LastIndex(cut, " "); i > n/2 {
		cut = cut[:i]
	}
	return cut + "…"
}

// AllocateIDs assigns each item its final identifier. Items arrive carrying
// only their prefix in ID; this walks them in a STABLE order (source path, then
// locator) so a re-run of the backfill over an unchanged tree allocates the
// same numbers — §11.4.54's "never renumbered" only holds if allocation is
// deterministic.
func AllocateIDs(items []Item, next map[string]int) []Item {
	sort.SliceStable(items, func(i, j int) bool {
		if items[i].SourcePath != items[j].SourcePath {
			return items[i].SourcePath < items[j].SourcePath
		}
		return locatorLess(items[i].SourceLocator, items[j].SourceLocator)
	})
	out := make([]Item, 0, len(items))
	for _, it := range items {
		prefix := it.ID
		next[prefix]++
		it.ID = FormatID(prefix, next[prefix])
		out = append(out, it)
	}
	return out
}

var digitsRe = regexp.MustCompile(`[0-9]+`)

// locatorLess orders "row 2" before "row 10" and "T002" before "T010", so the
// allocation order follows the source document rather than ASCII.
func locatorLess(a, b string) bool {
	an := digitsRe.FindString(a)
	bn := digitsRe.FindString(b)
	if an != "" && bn != "" && len(an) != len(bn) {
		return len(an) < len(bn)
	}
	return a < b
}
