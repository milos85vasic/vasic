package main

import (
	"path/filepath"
	"testing"
)

func TestEscEscapesQuotes(t *testing.T) {
	// esc (attribute-safe) escapes the double quote; escText (content) does not.
	if got := esc(`a "b" & <c>`); got != `a &quot;b&quot; &amp; &lt;c&gt;` {
		t.Errorf("esc quote/amp/lt = %q", got)
	}
	if got := escText(`a "b"`); got != `a "b"` {
		t.Errorf("escText should keep raw quotes, got %q", got)
	}
}

func TestParseFrontmatter(t *testing.T) {
	md := "---\n" +
		"name: HelixTrack\n" +
		"status: beta\n" +
		"tech:\n" +
		"  - Go\n" +
		"  - PostgreSQL\n" +
		"empty:\n" +
		"---\n" +
		"# Body Title\n\nBody text."
	fm, body, err := parseFrontmatter(md)
	if err != nil {
		t.Fatalf("parseFrontmatter error: %v", err)
	}
	if fm.scalars["name"] != "HelixTrack" {
		t.Errorf("scalar name = %q", fm.scalars["name"])
	}
	if fm.scalars["status"] != "beta" {
		t.Errorf("scalar status = %q", fm.scalars["status"])
	}
	if len(fm.lists["tech"]) != 2 || fm.lists["tech"][0] != "Go" || fm.lists["tech"][1] != "PostgreSQL" {
		t.Errorf("list tech = %v", fm.lists["tech"])
	}
	// A key with an empty value opens an (empty) list.
	if l, ok := fm.lists["empty"]; !ok || len(l) != 0 {
		t.Errorf("empty key should be an empty list, got %v ok=%v", l, ok)
	}
	if body != "# Body Title\n\nBody text." {
		t.Errorf("body = %q", body)
	}
}

func TestParseFrontmatterNoFrontmatter(t *testing.T) {
	if _, _, err := parseFrontmatter("no frontmatter here"); err == nil {
		t.Error("expected error for missing frontmatter")
	}
}

// repoRoot resolves the repository root from the package directory (_tools/gen).
func repoRoot() string {
	r, _ := filepath.Abs(filepath.Join("..", ".."))
	return r
}

func TestLoadPortfolioAndBySlug(t *testing.T) {
	p, err := loadPortfolio(filepath.Join(repoRoot(), "_content", "portfolio", "portfolio.json"))
	if err != nil {
		t.Fatalf("loadPortfolio: %v", err)
	}
	if len(p.Entries) == 0 {
		t.Fatal("portfolio has no entries")
	}
	if p.Count != len(p.Entries) {
		t.Errorf("declared count=%d but entries=%d", p.Count, len(p.Entries))
	}
	e := p.bySlug("helixtrack")
	if e == nil {
		t.Fatal("bySlug(helixtrack) returned nil")
	}
	if e.Name != "HelixTrack" {
		t.Errorf("helixtrack name = %q", e.Name)
	}
	if p.bySlug("does-not-exist") != nil {
		t.Error("bySlug for unknown slug should be nil")
	}
}

// TestPortfolioDataHasNoPrivateLeak is the Go-side guard mirroring the
// validate.mjs data gate: the renderer trusts its input, so the *data* it
// consumes must never carry a private:true entry that still exposes repos.
// (Private-repo SUPPRESSION itself is enforced upstream at the data gate, not
// in the Go renderer — see _tests/TEST-TYPES.md.)
func TestPortfolioDataHasNoPrivateLeak(t *testing.T) {
	p, err := loadPortfolio(filepath.Join(repoRoot(), "_content", "portfolio", "portfolio.json"))
	if err != nil {
		t.Fatalf("loadPortfolio: %v", err)
	}
	for _, e := range p.Entries {
		if e.Private && len(e.Repos) > 0 {
			t.Errorf("private entry %q leaks %d repo URL(s)", e.Slug, len(e.Repos))
		}
	}
}
