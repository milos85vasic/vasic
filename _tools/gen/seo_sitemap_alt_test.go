package main

import (
	"encoding/xml"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"testing"
)

var altLocales = []string{"en", "sr", "ru", "de", "es", "fr", "be", "zh", "kk", "hi", "ja", "ko", "ar", "tr", "fa"}

// fakeExpertiseTree writes the expertise page set (hub + 2 areas, 15 locales).
func fakeExpertiseTree(t *testing.T, root string, skip map[string]bool) {
	t.Helper()
	areas := []string{"go", "android"}
	put := func(rel string) {
		if skip[rel] {
			return
		}
		if err := writeFile(filepath.Join(root, rel, "index.html"), "<html></html>"); err != nil {
			t.Fatal(err)
		}
	}
	put("expertise")
	for _, l := range altLocales[1:] {
		put("expertise/" + l)
	}
	for _, a := range areas {
		put("expertise/" + a)
		for _, l := range altLocales[1:] {
			put("expertise/" + a + "/" + l)
		}
	}
}

func runSitemap(t *testing.T, root string) string {
	t.Helper()
	if err := writeSitemapRobots(sites["milosvasic.ru"], root); err != nil {
		t.Fatal(err)
	}
	b, err := os.ReadFile(filepath.Join(root, "sitemap.xml"))
	if err != nil {
		t.Fatal(err)
	}
	return string(b)
}

type smDoc struct {
	URLs []struct {
		Loc   string `xml:"loc"`
		Links []struct {
			Rel      string `xml:"rel,attr"`
			Hreflang string `xml:"hreflang,attr"`
			Href     string `xml:"href,attr"`
		} `xml:"http://www.w3.org/1999/xhtml link"`
	} `xml:"url"`
}

func parseSM(t *testing.T, s string) smDoc {
	t.Helper()
	var d smDoc
	if err := xml.Unmarshal([]byte(s), &d); err != nil {
		t.Fatalf("sitemap not well-formed: %v", err)
	}
	return d
}

func TestSitemapExpertiseAlternates(t *testing.T) {
	root := t.TempDir()
	fakeExpertiseTree(t, root, nil)
	s := runSitemap(t, root)
	if !strings.Contains(s, `xmlns:xhtml="http://www.w3.org/1999/xhtml"`) {
		t.Fatalf("missing xhtml namespace:\n%s", s[:300])
	}
	d := parseSM(t, s)
	if len(d.URLs) != 3*15 {
		t.Fatalf("want 45 urls, got %d", len(d.URLs))
	}
	for _, u := range d.URLs {
		if len(u.Links) != 16 {
			t.Errorf("%s: want 16 alternates, got %d", u.Loc, len(u.Links))
		}
		self := false
		for _, l := range u.Links {
			if l.Rel != "alternate" {
				t.Errorf("rel %q", l.Rel)
			}
			if l.Href == u.Loc {
				self = true
			}
			if l.Hreflang == "x-default" && !strings.HasSuffix(l.Href, "/expertise/") && !strings.Contains(l.Href, "/expertise/go/") && !strings.Contains(l.Href, "/expertise/android/") {
				t.Errorf("bad x-default %s", l.Href)
			}
		}
		if !self {
			t.Errorf("%s: no self-reference", u.Loc)
		}
	}
	// spot check scheme
	for _, want := range []string{
		`hreflang="x-default" href="https://milosvasic.ru/expertise/go/"`,
		`hreflang="ru" href="https://milosvasic.ru/expertise/go/ru/"`,
		`hreflang="en" href="https://milosvasic.ru/expertise/"`,
		`hreflang="fa" href="https://milosvasic.ru/expertise/fa/"`,
	} {
		if !strings.Contains(s, want) {
			t.Errorf("missing %s", want)
		}
	}
}

func TestSitemapNoAlternateToMissingFile(t *testing.T) {
	root := t.TempDir()
	fakeExpertiseTree(t, root, map[string]bool{"expertise/go/ja": true})
	d := parseSM(t, runSitemap(t, root))
	for _, u := range d.URLs {
		if strings.Contains(u.Loc, "/expertise/go/") {
			if len(u.Links) != 15 {
				t.Errorf("%s: want 15 alternates (ja missing), got %d", u.Loc, len(u.Links))
			}
		}
		for _, l := range u.Links {
			if l.Hreflang == "ja" && strings.Contains(l.Href, "/expertise/go/") {
				t.Errorf("alternate to non-existent page: %s", l.Href)
			}
		}
	}
}

func TestSitemapAlternatesDeterministic(t *testing.T) {
	root := t.TempDir()
	fakeExpertiseTree(t, root, nil)
	a := runSitemap(t, root)
	b := runSitemap(t, root)
	if a != b {
		t.Fatal("two runs differ")
	}
}

func TestSitemapNoAlternatesForOtherPages(t *testing.T) {
	root := t.TempDir()
	_ = writeFile(filepath.Join(root, "index.html"), "<html></html>")
	_ = writeFile(filepath.Join(root, "about/index.html"), "<html></html>")
	s := runSitemap(t, root)
	if strings.Contains(s, "xhtml") {
		t.Errorf("non-expertise sitemap must not change:\n%s", s)
	}
}

var fmHreflang = regexp.MustCompile(`hreflang=\\"([^"\\]+)\\" href=\\"([^"\\]+)\\"`)

// Against a temp copy of the live expertise source: sitemap alternates must
// equal each page's own seo_hreflang front matter.
func TestSitemapAlternatesMatchInPageHreflang(t *testing.T) {
	src := filepath.Join("..", "..", "milosvasic.ru", "expertise")
	if _, err := os.Stat(src); err != nil {
		t.Skip("no live expertise tree")
	}
	root := t.TempDir()
	dst := filepath.Join(root, "expertise")
	err := filepath.Walk(src, func(p string, info os.FileInfo, err error) error {
		if err != nil || info.IsDir() || info.Name() != "index.html" {
			return err
		}
		rel, _ := filepath.Rel(src, p)
		b, err := os.ReadFile(p)
		if err != nil {
			return err
		}
		return writeFile(filepath.Join(dst, rel), string(b))
	})
	if err != nil {
		t.Fatal(err)
	}
	d := parseSM(t, runSitemap(t, root))
	if len(d.URLs) != 165 {
		t.Fatalf("want 165 urls, got %d", len(d.URLs))
	}
	checked := 0
	for _, u := range d.URLs {
		rel := strings.TrimPrefix(u.Loc, "https://milosvasic.ru/")
		b, err := os.ReadFile(filepath.Join(root, rel, "index.html"))
		if err != nil {
			t.Fatal(err)
		}
		var want []string
		for _, m := range fmHreflang.FindAllStringSubmatch(string(b), -1) {
			want = append(want, m[1]+" "+m[2])
		}
		var got []string
		for _, l := range u.Links {
			got = append(got, l.Hreflang+" "+l.Href)
		}
		sort.Strings(want)
		sort.Strings(got)
		if len(want) != 16 || strings.Join(want, "|") != strings.Join(got, "|") {
			t.Errorf("%s: sitemap alternates != in-page hreflang\nwant %v\ngot  %v", u.Loc, want, got)
		}
		checked++
	}
	t.Logf("checked %d pages", checked)
}

// A locale directory that also holds locale subdirectories is an AREA whose id
// collides with a locale code (e.g. area "ko"): its pages would be mis-read as
// localized hubs, so generation must fail loudly.
func TestExpertiseAreaLocaleCollisionDetected(t *testing.T) {
	root := t.TempDir()
	fakeExpertiseTree(t, root, nil)
	if got := expertiseAreaLocaleCollisions(root); len(got) != 0 {
		t.Fatalf("clean tree reported collisions: %v", got)
	}
	if err := writeFile(filepath.Join(root, "expertise", "ko", "ru", "index.html"), "<html></html>"); err != nil {
		t.Fatal(err)
	}
	got := expertiseAreaLocaleCollisions(root)
	if len(got) != 1 || got[0] != "ko" {
		t.Fatalf("want [ko], got %v", got)
	}
}
