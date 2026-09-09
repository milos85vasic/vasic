// Package wi implements the umbrella-local half of the §11.4.93 workable-items
// system: the sub-project identifier roster, the backfill ingestors, and the
// integrity validator.
//
// It is deliberately NOT a second workable-items CRUD tool. §11.4.93 states,
// verbatim:
//
//	"The Go binary lives in the constitution submodule
//	 (constitution/scripts/workable-items/) so consumers reference it from
//	 there per §11.4.74 catalogue-first discipline — never reimplement."
//
// That binary exists at submodules/constitution/scripts/workable-items/ and is
// what creates the schema, mutates items, closes them and regenerates the
// Markdown surfaces. This package adds only the two things the umbrella needs
// and the canonical binary does not have: a MULTI-sub-project identifier roster
// (the canonical tool derives ONE prefix from the project root name), and the
// backfill ingestors for this repository's own evidence sources.
package wi

import (
	"bufio"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
)

// Class is the closed set of sub-project classes carried in the roster file.
type Class string

const (
	ClassParent     Class = "parent"
	ClassOwned      Class = "owned"
	ClassGovernance Class = "governance-source"
	ClassThirdParty Class = "third-party"
)

func validClass(c Class) bool {
	switch c {
	case ClassParent, ClassOwned, ClassGovernance, ClassThirdParty:
		return true
	}
	return false
}

// SubProject is one identifier-bearing member of the fleet.
type SubProject struct {
	Prefix   string
	Path     string
	Class    Class
	Ratified string // "operator" (stated by the operator) | "proposed" (awaiting ratification)
	Note     string
	URL      string // derived from .gitmodules; empty for the parent
	Declared bool   // true when .gitmodules declares this path
}

// Roster is the cross-checked result of reading the roster file against the
// live .gitmodules declaration.
type Roster struct {
	Members []SubProject
	// Undetermined names paths declared in .gitmodules that carry no roster row.
	// A non-empty slice is rc 2 — the tracking coverage of the fleet cannot be
	// established, which is never a pass.
	Undetermined []string
	// Orphans names roster rows whose path is neither "." nor a declared
	// submodule. A non-empty slice is a finding (rc 1).
	Orphans []string
}

// RosterPath is the roster file's location relative to the repository root.
const RosterPath = "docs/workable-items/sub-projects.tsv"

// FindRepoRoot walks up from start looking for the marker that identifies this
// umbrella checkout. No host path is ever hardcoded (operator directive,
// 2026-09-08) — the root is discovered, never assumed.
func FindRepoRoot(start string) (string, error) {
	dir, err := filepath.Abs(start)
	if err != nil {
		return "", err
	}
	for {
		if _, err := os.Stat(filepath.Join(dir, ".gitmodules")); err == nil {
			if _, err := os.Stat(filepath.Join(dir, "helix-deps.yaml")); err == nil {
				return dir, nil
			}
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			return "", fmt.Errorf("no directory at or above %q carries both .gitmodules and helix-deps.yaml", start)
		}
		dir = parent
	}
}

// declaredSubmodules reads the submodule path->url map from .gitmodules using
// git itself, so the parse matches what `git submodule update` would act on
// rather than a hand-rolled INI reader.
func declaredSubmodules(root string) (map[string]string, error) {
	out, err := exec.Command("git", "config", "-f", filepath.Join(root, ".gitmodules"),
		"--get-regexp", `submodule\..*\.path`).Output()
	if err != nil {
		return nil, fmt.Errorf("reading .gitmodules paths: %w", err)
	}
	paths := map[string]string{} // submodule name -> path
	for _, line := range strings.Split(strings.TrimSpace(string(out)), "\n") {
		if line == "" {
			continue
		}
		key, val, ok := strings.Cut(line, " ")
		if !ok {
			continue
		}
		name := strings.TrimSuffix(strings.TrimPrefix(key, "submodule."), ".path")
		paths[name] = val
	}
	urlOut, err := exec.Command("git", "config", "-f", filepath.Join(root, ".gitmodules"),
		"--get-regexp", `submodule\..*\.url`).Output()
	if err != nil {
		return nil, fmt.Errorf("reading .gitmodules urls: %w", err)
	}
	urls := map[string]string{}
	for _, line := range strings.Split(strings.TrimSpace(string(urlOut)), "\n") {
		if line == "" {
			continue
		}
		key, val, ok := strings.Cut(line, " ")
		if !ok {
			continue
		}
		name := strings.TrimSuffix(strings.TrimPrefix(key, "submodule."), ".url")
		urls[name] = val
	}
	byPath := map[string]string{}
	for name, p := range paths {
		byPath[p] = urls[name]
	}
	return byPath, nil
}

// manifestNames reads the dep names recorded in helix-deps.yaml. It is a
// deliberately narrow line reader rather than a YAML parse: the only datum
// wanted is the `- name:` list, and acquiring a YAML dependency for one field
// would make this instrument able to fail to load — a parser that can fail to
// load is a parser that can report a fleet it never read.
func manifestNames(root string) ([]string, error) {
	f, err := os.Open(filepath.Join(root, "helix-deps.yaml"))
	if err != nil {
		return nil, err
	}
	defer f.Close()
	var names []string
	sc := bufio.NewScanner(f)
	sc.Buffer(make([]byte, 0, 64*1024), 4*1024*1024)
	for sc.Scan() {
		line := sc.Text()
		trimmed := strings.TrimSpace(line)
		if !strings.HasPrefix(trimmed, "- name:") {
			continue
		}
		if strings.HasPrefix(strings.TrimLeft(line, " \t"), "#") {
			continue
		}
		names = append(names, strings.TrimSpace(strings.TrimPrefix(trimmed, "- name:")))
	}
	if err := sc.Err(); err != nil {
		return nil, err
	}
	sort.Strings(names)
	return names, nil
}

// ManifestNames is the exported reader used by the roster cross-check and by
// tests that assert the manifest and .gitmodules agree.
func ManifestNames(root string) ([]string, error) { return manifestNames(root) }

// LoadRoster reads the roster file and cross-checks it against .gitmodules.
func LoadRoster(root string) (*Roster, error) {
	f, err := os.Open(filepath.Join(root, RosterPath))
	if err != nil {
		return nil, err
	}
	defer f.Close()

	declared, err := declaredSubmodules(root)
	if err != nil {
		return nil, err
	}

	r := &Roster{}
	seenPrefix := map[string]string{}
	seenPath := map[string]bool{}
	sc := bufio.NewScanner(f)
	lineNo := 0
	for sc.Scan() {
		lineNo++
		line := sc.Text()
		if strings.HasPrefix(line, "#") || strings.TrimSpace(line) == "" {
			continue
		}
		fields := strings.Split(line, "\t")
		if len(fields) < 4 {
			return nil, fmt.Errorf("%s:%d: malformed row — want 5 tab-separated fields, got %d", RosterPath, lineNo, len(fields))
		}
		if fields[0] == "prefix" {
			continue // header
		}
		sp := SubProject{
			Prefix:   fields[0],
			Path:     fields[1],
			Class:    Class(fields[2]),
			Ratified: fields[3],
		}
		if len(fields) > 4 {
			sp.Note = fields[4]
		}
		if !ValidPrefix(sp.Prefix) {
			return nil, fmt.Errorf("%s:%d: prefix %q is not three uppercase ASCII letters", RosterPath, lineNo, sp.Prefix)
		}
		if prev, dup := seenPrefix[sp.Prefix]; dup {
			return nil, fmt.Errorf("%s:%d: prefix %q already assigned to %q", RosterPath, lineNo, sp.Prefix, prev)
		}
		seenPrefix[sp.Prefix] = sp.Path
		if seenPath[sp.Path] {
			return nil, fmt.Errorf("%s:%d: path %q appears twice", RosterPath, lineNo, sp.Path)
		}
		seenPath[sp.Path] = true
		if !validClass(sp.Class) {
			return nil, fmt.Errorf("%s:%d: class %q is outside the closed set", RosterPath, lineNo, sp.Class)
		}
		if sp.Ratified != "operator" && sp.Ratified != "proposed" {
			return nil, fmt.Errorf("%s:%d: ratified %q is outside the closed set {operator, proposed}", RosterPath, lineNo, sp.Ratified)
		}
		if sp.Path == "." {
			sp.Declared = true // the parent is this repository, not a submodule
		} else if url, ok := declared[sp.Path]; ok {
			sp.Declared = true
			sp.URL = url
		} else {
			r.Orphans = append(r.Orphans, sp.Path)
		}
		r.Members = append(r.Members, sp)
	}
	if err := sc.Err(); err != nil {
		return nil, err
	}
	for path := range declared {
		if !seenPath[path] {
			r.Undetermined = append(r.Undetermined, path)
		}
	}
	sort.Strings(r.Undetermined)
	sort.Strings(r.Orphans)
	return r, nil
}

// ValidPrefix reports whether s is exactly three uppercase ASCII letters — the
// shape the canonical tracker's own heading grammar requires
// (constitution/scripts/workable-items/cmd/workable-items/parse.go:
// issueHeadingRe `^## [A-Z]{3}-…`), and the shape the operator stated.
func ValidPrefix(s string) bool {
	if len(s) != 3 {
		return false
	}
	for _, r := range s {
		if r < 'A' || r > 'Z' {
			return false
		}
	}
	return true
}

// ByPrefix indexes a roster for lookup.
func (r *Roster) ByPrefix() map[string]SubProject {
	m := make(map[string]SubProject, len(r.Members))
	for _, sp := range r.Members {
		m[sp.Prefix] = sp
	}
	return m
}
