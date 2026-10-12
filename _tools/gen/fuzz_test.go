package main

import (
	"strings"
	"testing"
)

// T057 fuzz targets for the site generator's parsers and HTML/YAML emitters.
//   go test -run='^$' -fuzz=FuzzRenderBody -fuzztime=20s
// Seeds run as ordinary tests under `go test`.

const injMarker = "<zzinj"

var allowedTags = strings.NewReplacer("<strong>", "", "</strong>", "", "<code>", "", "</code>", "")

// FuzzInline: inline markdown never lets a raw '<' or '>' from the input
// through; only its own <strong>/<code> tags may appear.
func FuzzInline(f *testing.F) {
	for _, s := range []string{"**b**", "`c`", "<script>", "**<x>**", "a & b", "`<zzinj>`", "****", "` `"} {
		f.Add(s)
	}
	f.Fuzz(func(t *testing.T, s string) {
		out := allowedTags.Replace(inline(s))
		if strings.ContainsAny(out, "<>") {
			t.Fatalf("inline(%q) leaks markup: %q", s, out)
		}
	})
}

// FuzzRenderBody: a raw HTML tag planted on its own line, as a list item, as a
// heading or inside bold/code never reaches the output unescaped, for both the
// simple and the rich renderer.
func FuzzRenderBody(f *testing.F) {
	for _, s := range []string{"# T\nintro\n\n## S\n- a\n- b", "text", "", "> q\n### h", "- **x**", "`a`"} {
		f.Add(s)
	}
	f.Fuzz(func(t *testing.T, s string) {
		// Only the planted marker is judged: arbitrary input may legitimately
		// contain "<" that is escaped; the marker proves the escape ran.
		for _, shape := range []string{"\n<zzinj>", "\n- <zzinj>", "\n## <zzinj>", "\n**<zzinj>**", "\n`<zzinj>`", "\n> <zzinj>", "\n### <zzinj>"} {
			in := strings.ReplaceAll(s, injMarker, "") + shape
			if strings.Contains(renderBody(in), injMarker) {
				t.Fatalf("renderBody leaked %q after %q", shape, s)
			}
			if strings.Contains(renderContentBlocks(in), injMarker) {
				t.Fatalf("renderContentBlocks leaked %q after %q", shape, s)
			}
			pre, secs := splitSections(in)
			if strings.Contains(renderContentBlocks(pre), injMarker) {
				t.Fatalf("preamble leaked %q", shape)
			}
			for _, sec := range secs {
				if strings.Contains(renderContentBlocks(sec.body), injMarker) {
					t.Fatalf("section body leaked %q", shape)
				}
			}
		}
	})
}

// FuzzEsc: esc output holds no markup characters and is reversible.
func FuzzEsc(f *testing.F) {
	for _, s := range []string{"a & b", `"q"`, "<>", "&amp;", "&lt;"} {
		f.Add(s)
	}
	f.Fuzz(func(t *testing.T, s string) {
		out := esc(s)
		if strings.ContainsAny(out, `<>"`) {
			t.Fatalf("esc(%q) = %q has raw markup", s, out)
		}
		back := strings.NewReplacer("&lt;", "<", "&gt;", ">", "&quot;", `"`, "&amp;", "&").Replace(out)
		if back != s {
			t.Fatalf("esc(%q) not reversible: %q", s, back)
		}
	})
}

// fuzzYamlUnquote is an independent reader of a YAML double-quoted scalar
// restricted to the two escapes yamlQuote emits.
func fuzzYamlUnquote(q string) (string, bool) {
	if len(q) < 2 || q[0] != '"' || q[len(q)-1] != '"' {
		return "", false
	}
	var b strings.Builder
	in := q[1 : len(q)-1]
	for i := 0; i < len(in); i++ {
		switch in[i] {
		case '\\':
			if i+1 >= len(in) || (in[i+1] != '\\' && in[i+1] != '"') {
				return "", false
			}
			i++
			b.WriteByte(in[i])
		case '"':
			return "", false // an unescaped quote would end the scalar early
		default:
			b.WriteByte(in[i])
		}
	}
	return b.String(), true
}

// FuzzYamlQuote: the front-matter scalar always reads back as the input.
func FuzzYamlQuote(f *testing.F) {
	for _, s := range []string{`a "b" c`, `back\slash`, `\"`, `"`, `\`, "", `end\`} {
		f.Add(s)
	}
	f.Fuzz(func(t *testing.T, s string) {
		got, ok := fuzzYamlUnquote(yamlQuote(s))
		if !ok || got != s {
			t.Fatalf("yamlQuote(%q) = %q reads back %q ok=%v", s, yamlQuote(s), got, ok)
		}
	})
}

// FuzzParseFrontmatter: never panics; success returns a body that follows the
// first closing fence; a well-formed single `key: value` document round-trips.
func FuzzParseFrontmatter(f *testing.F) {
	f.Add("---\nname: X\ntags:\n  - a\n  - b\n---\n# body", "k", "v")
	f.Add("no frontmatter", "k", "v")
	f.Add("---\n---\n", "", "")
	f.Add("---\nk: v\n---\n---\nx\n---\n", "k", "w")
	f.Fuzz(func(t *testing.T, doc, key, val string) {
		if fm, body, err := parseFrontmatter(doc); err == nil {
			if !strings.HasPrefix(doc, "---\n") || !strings.HasSuffix(doc, body) {
				t.Fatalf("accepted %q with body %q", doc, body)
			}
			if fm.scalars == nil || fm.lists == nil {
				t.Fatalf("nil maps for %q", doc)
			}
		}
		if key == "" || strings.ContainsAny(key, "\n:") || strings.ContainsAny(val, "\n") ||
			val == "" || strings.TrimLeft(val, " \t\r\f\v") != val || !kvKeyOK(key) {
			return
		}
		fm, body, err := parseFrontmatter("---\n" + key + ": " + val + "\n---\nB")
		if err != nil || fm.scalars[key] != val || body != "B" {
			t.Fatalf("round trip %q=%q failed: %+v %q %v", key, val, fm, body, err)
		}
	})
}

func kvKeyOK(k string) bool {
	for i := 0; i < len(k); i++ {
		c := k[i]
		alpha := c == '_' || (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z')
		if !(alpha || (i > 0 && c >= '0' && c <= '9')) {
			return false
		}
	}
	return true
}
