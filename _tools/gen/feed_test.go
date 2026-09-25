package main

import (
	"encoding/xml"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

// Feed tests. The shipped defect (found by a 2026-09-24 live audit): milosvasic.ru
// served a VALID but EMPTY Atom feed (jekyll-feed with no _posts). These tests pin
// the replacement: a feed is written ONLY when it has entries, its entries are the
// site's real canonical product pages, and generating twice gives identical bytes.

type atomFeed struct {
	XMLName xml.Name `xml:"http://www.w3.org/2005/Atom feed"`
	ID      string   `xml:"id"`
	Title   string   `xml:"title"`
	Updated string   `xml:"updated"`
	Lang    string   `xml:"http://www.w3.org/XML/1998/namespace lang,attr"`
	Author  struct {
		Name string `xml:"name"`
	} `xml:"author"`
	Links []struct {
		Rel  string `xml:"rel,attr"`
		Type string `xml:"type,attr"`
		Href string `xml:"href,attr"`
	} `xml:"link"`
	Entries []struct {
		ID      string `xml:"id"`
		Title   string `xml:"title"`
		Updated string `xml:"updated"`
		Summary string `xml:"summary"`
		Link    struct {
			Href string `xml:"href,attr"`
		} `xml:"link"`
	} `xml:"entry"`
}

func feedSite() *Site {
	s := testSite()
	s.Key = "milosvasic.ru"
	s.Domain = "milosvasic.ru"
	s.Brand = "Miloš Vasić"
	s.Jekyll = true
	return s
}

func writePage(t *testing.T, root, rel, title, desc string) {
	t.Helper()
	body := "---\nlayout: default\nlang: en\ntitle: " + yamlQuote(title) + "\ndescription: " + yamlQuote(desc) + "\n---\n\n<p>x</p>\n"
	p := filepath.Join(root, rel)
	if err := writeFile(p, body); err != nil {
		t.Fatal(err)
	}
	when := time.Date(2026, 9, 24, 13, 0, 0, 0, time.UTC)
	if err := os.Chtimes(p, when, when); err != nil {
		t.Fatal(err)
	}
}

func readFeed(t *testing.T, path string) (atomFeed, string) {
	t.Helper()
	raw, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("feed not written: %v", err)
	}
	var f atomFeed
	if err := xml.Unmarshal(raw, &f); err != nil {
		t.Fatalf("feed is not well-formed Atom XML: %v\n%s", err, raw)
	}
	return f, string(raw)
}

func TestWriteFeeds_EnglishAndPerLanguage(t *testing.T) {
	root := t.TempDir()
	writePage(t, root, "products/helixtrack.html", "HelixTrack — Miloš Vasić", "Tracker")
	writePage(t, root, "products/catalogizer.html", "Catalogizer", "Media \"manager\" & more <b>")
	writePage(t, root, "products/ru/helixtrack.html", "ХеликсТрек", "Трекер задач")
	writePage(t, root, "products/ar/helixtrack.html", "هيليكس تراك", "متتبع")
	writePage(t, root, "products/zh/helixtrack.html", "螺旋追踪", "任务追踪")
	writePage(t, root, "index.html", "Home", "Home")
	if err := writeFeeds(feedSite(), root); err != nil {
		t.Fatalf("writeFeeds: %v", err)
	}
	en, _ := readFeed(t, filepath.Join(root, "feed.xml"))
	if len(en.Entries) != 2 {
		t.Fatalf("english feed must list the 2 english product pages (not the home page), got %d", len(en.Entries))
	}
	if en.ID != "https://milosvasic.ru/feed.xml" {
		t.Errorf("feed id must be its canonical URL, got %q", en.ID)
	}
	if en.Author.Name == "" {
		t.Error("RFC 4287 requires a feed author when entries carry none")
	}
	ids := map[string]bool{}
	for _, e := range en.Entries {
		ids[e.ID] = true
		if e.ID != e.Link.Href || !strings.HasPrefix(e.ID, "https://milosvasic.ru/products/") {
			t.Errorf("entry id/link must be the absolute canonical page URL, got id=%q link=%q", e.ID, e.Link.Href)
		}
		if e.Updated != "2026-09-24T00:00:00Z" {
			t.Errorf("entry updated must be the file's date at day granularity (RFC 3339), got %q", e.Updated)
		}
		if strings.Contains(e.ID, "localhost") {
			t.Errorf("localhost leaked into %q", e.ID)
		}
	}
	if !ids["https://milosvasic.ru/products/catalogizer.html"] {
		t.Errorf("missing catalogizer entry: %v", ids)
	}
	hasSelf := false
	for _, l := range en.Links {
		if l.Rel == "self" && l.Type == "application/atom+xml" && l.Href == "https://milosvasic.ru/feed.xml" {
			hasSelf = true
		}
	}
	if !hasSelf {
		t.Error("feed needs rel=self type=application/atom+xml at its own canonical URL")
	}
	for lang, want := range map[string]string{"ru": "ХеликсТрек", "ar": "هيليكس تراك", "zh": "螺旋追踪"} {
		f, _ := readFeed(t, filepath.Join(root, lang, "feed.xml"))
		if len(f.Entries) != 1 || f.Entries[0].Title != want {
			t.Errorf("%s feed wrong: %+v", lang, f.Entries)
		}
		if f.Lang != lang {
			t.Errorf("%s feed xml:lang = %q", lang, f.Lang)
		}
		if f.ID != "https://milosvasic.ru/"+lang+"/feed.xml" || f.Entries[0].ID != "https://milosvasic.ru/products/"+lang+"/helixtrack.html" {
			t.Errorf("%s ids not canonical: %q / %q", lang, f.ID, f.Entries[0].ID)
		}
	}
	// XML escaping: & < > " survive a round trip verbatim.
	for _, e := range en.Entries {
		if strings.HasSuffix(e.ID, "catalogizer.html") && e.Summary != "Media \"manager\" & more <b>" {
			t.Errorf("summary not escaped/round-tripped correctly: %q", e.Summary)
		}
	}
}

func TestWriteFeeds_NeverWritesAnEmptyFeed(t *testing.T) {
	root := t.TempDir()
	writePage(t, root, "index.html", "Home", "Home") // no product pages at all
	if err := writeFeeds(feedSite(), root); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(filepath.Join(root, "feed.xml")); err == nil {
		t.Fatal("a feed with zero entries must not be written — that is exactly the defect being replaced")
	}
	// A language directory with no pages gets no feed either.
	if err := os.MkdirAll(filepath.Join(root, "products", "de"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := writeFeeds(feedSite(), root); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(filepath.Join(root, "de", "feed.xml")); err == nil {
		t.Fatal("empty language directory must not produce an empty feed")
	}
}

func TestWriteFeeds_DeterministicAndSkipsNonJekyllSites(t *testing.T) {
	root := t.TempDir()
	writePage(t, root, "products/a.html", "A", "a")
	writePage(t, root, "products/b.html", "B", "b")
	writePage(t, root, "products/ru/a.html", "А", "а")
	s := feedSite()
	if err := writeFeeds(s, root); err != nil {
		t.Fatal(err)
	}
	first1, _ := os.ReadFile(filepath.Join(root, "feed.xml"))
	first2, _ := os.ReadFile(filepath.Join(root, "ru", "feed.xml"))
	// Regenerating rewrites the feed files: their own mtimes change, and that must
	// NOT leak into the output (only the source pages' dates may).
	if err := writeFeeds(s, root); err != nil {
		t.Fatal(err)
	}
	second1, _ := os.ReadFile(filepath.Join(root, "feed.xml"))
	second2, _ := os.ReadFile(filepath.Join(root, "ru", "feed.xml"))
	if string(first1) != string(second1) || string(first2) != string(second2) {
		t.Fatal("two generations must be byte-identical")
	}
	// The feed must not list itself or a previous feed as an entry.
	if strings.Count(string(second1), "<entry>") != 2 {
		t.Fatalf("expected exactly 2 entries, feed:\n%s", second1)
	}
	// vasic.digital (not a Jekyll site, self-contained pages) gets no feed.
	other := t.TempDir()
	writePage(t, other, "products/a.html", "A", "a")
	v := testSite()
	v.Jekyll = false
	if err := writeFeeds(v, other); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(filepath.Join(other, "feed.xml")); err == nil {
		t.Fatal("non-Jekyll site must not get a feed")
	}
}

func TestWriteFeeds_StripsIllegalXMLCharacters(t *testing.T) {
	root := t.TempDir()
	writePage(t, root, "products/a.html", "A\x00B\x0bC", "d\x1fe")
	if err := writeFeeds(feedSite(), root); err != nil {
		t.Fatal(err)
	}
	f, raw := readFeed(t, filepath.Join(root, "feed.xml"))
	if strings.ContainsAny(raw, "\x00\x0b\x1f") {
		t.Fatal("control characters must never reach the XML")
	}
	if f.Entries[0].Title != "ABC" || f.Entries[0].Summary != "de" {
		t.Errorf("illegal characters must be dropped, got %q / %q", f.Entries[0].Title, f.Entries[0].Summary)
	}
}
