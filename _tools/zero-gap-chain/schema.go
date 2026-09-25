package main

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"regexp"
	"sort"
	"strconv"
	"time"
)

// Schema is a deliberately SMALL interpreter of the evidence-record contract
// (contracts/evidence-record.schema.json). The repository takes no new
// third-party dependency (Global Constraints), so this is not a general JSON
// Schema engine: it understands exactly the keywords the contract uses and
// REFUSES TO LOAD a schema carrying any other keyword. Silently ignoring an
// unknown keyword would accept records the contract forbids — a validator that
// cannot see a rule must say so, not pass (§11.4.201).
//
// The contract file is read at run time, never copied into code, so the
// contract stays the single source of truth.
type Schema struct {
	required []string
	props    map[string]*propSpec
}

type propSpec struct {
	typ       string // string|integer|boolean|array, or "" when enum carries the type
	format    string
	pattern   *regexp.Regexp
	enum      []json.RawMessage
	itemsType string
	minItems  int
	hasMinIt  bool
	minimum   int64
	hasMin    bool
}

var (
	topKeys  = set("$schema", "title", "type", "required", "properties", "additionalProperties", "$comment", "description")
	propKeys = set("type", "format", "pattern", "enum", "items", "minItems", "minimum", "description")
	itemKeys = set("type")
)

func set(ks ...string) map[string]bool {
	m := map[string]bool{}
	for _, k := range ks {
		m[k] = true
	}
	return m
}

var errSchema = errors.New("evidence schema")

// LoadSchema reads and compiles a contract file.
func LoadSchema(path string) (*Schema, error) {
	b, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("%w: reading %s: %v", errSchema, path, err)
	}
	var top map[string]json.RawMessage
	if err := json.Unmarshal(b, &top); err != nil {
		return nil, fmt.Errorf("%w: %s is not a JSON object: %v", errSchema, path, err)
	}
	for k := range top {
		if !topKeys[k] {
			return nil, fmt.Errorf("%w: unsupported top-level keyword %q — refusing to validate with a rule this interpreter cannot see", errSchema, k)
		}
	}
	var typ string
	if err := json.Unmarshal(top["type"], &typ); err != nil || typ != "object" {
		return nil, fmt.Errorf("%w: top-level type must be \"object\"", errSchema)
	}
	var addl bool = true
	if err := json.Unmarshal(top["additionalProperties"], &addl); err != nil || addl {
		return nil, fmt.Errorf("%w: additionalProperties must be false (open records cannot be bound byte-for-byte)", errSchema)
	}
	s := &Schema{props: map[string]*propSpec{}}
	if err := json.Unmarshal(top["required"], &s.required); err != nil {
		return nil, fmt.Errorf("%w: required: %v", errSchema, err)
	}
	var props map[string]map[string]json.RawMessage
	if err := json.Unmarshal(top["properties"], &props); err != nil {
		return nil, fmt.Errorf("%w: properties: %v", errSchema, err)
	}
	for name, raw := range props {
		p := &propSpec{}
		for k, v := range raw {
			if !propKeys[k] {
				return nil, fmt.Errorf("%w: property %q uses unsupported keyword %q", errSchema, name, k)
			}
			var err error
			switch k {
			case "type":
				err = json.Unmarshal(v, &p.typ)
				if err == nil && p.typ != "string" && p.typ != "integer" && p.typ != "boolean" && p.typ != "array" {
					err = fmt.Errorf("unsupported type %q", p.typ)
				}
			case "format":
				err = json.Unmarshal(v, &p.format)
				if err == nil && p.format != "date-time" {
					err = fmt.Errorf("unsupported format %q", p.format)
				}
			case "pattern":
				var pat string
				if err = json.Unmarshal(v, &pat); err == nil {
					p.pattern, err = regexp.Compile(pat)
				}
			case "enum":
				err = json.Unmarshal(v, &p.enum)
			case "items":
				var it map[string]json.RawMessage
				if err = json.Unmarshal(v, &it); err == nil {
					for ik := range it {
						if !itemKeys[ik] {
							err = fmt.Errorf("items uses unsupported keyword %q", ik)
						}
					}
					if err == nil {
						err = json.Unmarshal(it["type"], &p.itemsType)
						if err == nil && p.itemsType != "string" {
							err = fmt.Errorf("unsupported items type %q", p.itemsType)
						}
					}
				}
			case "minItems":
				err = json.Unmarshal(v, &p.minItems)
				p.hasMinIt = true
			case "minimum":
				err = json.Unmarshal(v, &p.minimum)
				p.hasMin = true
			}
			if err != nil {
				return nil, fmt.Errorf("%w: property %q keyword %q: %v", errSchema, name, k, err)
			}
		}
		if p.typ == "" && len(p.enum) == 0 {
			return nil, fmt.Errorf("%w: property %q has neither a type nor an enum", errSchema, name)
		}
		s.props[name] = p
	}
	for _, r := range s.required {
		if s.props[r] == nil {
			return nil, fmt.Errorf("%w: required %q has no property definition", errSchema, r)
		}
	}
	return s, nil
}

var intLit = regexp.MustCompile(`^-?(0|[1-9][0-9]*)$`)

// ValidateLine returns every violation of the contract by one JSON line. An
// empty result means the line satisfies every rule this interpreter loaded.
// Duplicate keys are refused: a reader would see only the last one, so the
// line would bind bytes that say two different things.
func (s *Schema) ValidateLine(line []byte) []string {
	if s == nil {
		return []string{"no schema loaded"}
	}
	dec := json.NewDecoder(bytes.NewReader(line))
	dec.UseNumber()
	tok, err := dec.Token()
	if err != nil || tok != json.Delim('{') {
		return []string{"line is not a JSON object"}
	}
	vals := map[string]json.RawMessage{}
	var bad []string
	for dec.More() {
		kt, err := dec.Token()
		if err != nil {
			return []string{"malformed JSON: " + err.Error()}
		}
		k, _ := kt.(string)
		var raw json.RawMessage
		if err := dec.Decode(&raw); err != nil {
			return []string{"malformed JSON value for " + strconv.Quote(k) + ": " + err.Error()}
		}
		if _, dup := vals[k]; dup {
			bad = append(bad, "duplicate key "+strconv.Quote(k))
		}
		vals[k] = raw
	}
	if tok, err := dec.Token(); err != nil || tok != json.Delim('}') {
		return []string{"malformed JSON object"}
	}
	if _, err := dec.Token(); err != io.EOF {
		return []string{"line carries more than one JSON value"}
	}
	for _, r := range s.required {
		if _, ok := vals[r]; !ok {
			bad = append(bad, "missing required field "+strconv.Quote(r))
		}
	}
	keys := make([]string, 0, len(vals))
	for k := range vals {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	for _, k := range keys {
		p := s.props[k]
		if p == nil {
			bad = append(bad, "unknown field "+strconv.Quote(k)+" (additionalProperties is false)")
			continue
		}
		bad = append(bad, p.check(k, vals[k])...)
	}
	return bad
}

func (p *propSpec) check(k string, raw json.RawMessage) []string {
	var bad []string
	fail := func(f string, a ...any) { bad = append(bad, fmt.Sprintf("%q: ", k)+fmt.Sprintf(f, a...)) }
	raw = bytes.TrimSpace(raw)
	switch p.typ {
	case "string":
		var v string
		if len(raw) == 0 || raw[0] != '"' || json.Unmarshal(raw, &v) != nil {
			fail("not a string")
			return bad
		}
		if p.pattern != nil && !p.pattern.MatchString(v) {
			fail("%q does not match %s", v, p.pattern)
		}
		if p.format == "date-time" {
			if _, err := time.Parse(time.RFC3339, v); err != nil {
				fail("%q is not an RFC 3339 date-time", v)
			}
		}
	case "integer":
		if !intLit.Match(raw) {
			fail("not an integer literal: %s", raw)
			return bad
		}
		n, err := strconv.ParseInt(string(raw), 10, 64)
		if err != nil {
			fail("integer out of range: %s", raw)
			return bad
		}
		if p.hasMin && n < p.minimum {
			fail("%d is below the minimum %d", n, p.minimum)
		}
	case "boolean":
		if string(raw) != "true" && string(raw) != "false" {
			fail("not a boolean: %s", raw)
		}
	case "array":
		if len(raw) == 0 || raw[0] != '[' {
			fail("not an array")
			return bad
		}
		var items []json.RawMessage
		if err := json.Unmarshal(raw, &items); err != nil {
			fail("malformed array")
			return bad
		}
		if p.hasMinIt && len(items) < p.minItems {
			fail("%d item(s), fewer than minItems %d", len(items), p.minItems)
		}
		for i, it := range items {
			it = bytes.TrimSpace(it)
			var v string
			if len(it) == 0 || it[0] != '"' || json.Unmarshal(it, &v) != nil {
				fail("item %d is not a string", i)
			}
		}
	}
	if len(p.enum) > 0 {
		ok := false
		for _, e := range p.enum {
			if bytes.Equal(bytes.TrimSpace(e), raw) {
				ok = true
			}
		}
		if !ok {
			fail("%s is not one of the enumerated values", raw)
		}
	}
	return bad
}
