package wi

// V-G3(c) "newest verdict per role" (operator decision 2026-10-08). Written before the
// implementation and observed failing first. Table-driven; each case builds the
// prepareClose kit (a valid verifier row dated fixtureAsOf and a valid reviewer row)
// and then appends extra verdict rows around it.

import (
	"strings"
	"testing"
)

var (
	nvA = strings.Repeat("a", 64)
	nvB = strings.Repeat("b", 64)
)

// nvVerifier writes a verifier evidence record (check CHK-vsc-001) and records the verdict row via the CLI.
func nvVerifier(t *testing.T, k closeKit, name, ts string, seq int, outcome int, actor, on string) string {
	t.Helper()
	rel := writeRecord(t, k.repo, "ev/"+name+".json", map[string]any{"item_id": "VSC-001", "check_id": "CHK-vsc-001",
		"outcome": outcome, "verdict_role": "verifier", "state_fingerprint_before": nvB, "state_fingerprint_after": nvB,
		"ts": ts, "chain_seq": seq})
	if rc, out := gapRun(t, k.repo, k.db, "verdict", "--id", "VSC-001", "--role", "verifier", "--actor", actor,
		"--actor-kind", "agent", "--outcome", itoa(outcome), "--evidence", rel, "--on", on); rc != 0 {
		t.Fatalf("recording verifier row %s: rc %d\n%s", name, rc, out)
	}
	return rel
}

func nvReviewer(t *testing.T, k closeKit, name string, outcome int, on string) {
	t.Helper()
	rel := writeText(t, k.repo, "ev/"+name+".md", "review "+name+" of VSC-001\n")
	if rc, out := gapRun(t, k.repo, k.db, "verdict", "--id", "VSC-001", "--role", "reviewer", "--actor", "agent-reviewer-D",
		"--actor-kind", "agent", "--outcome", itoa(outcome), "--evidence", rel, "--on", on); rc != 0 {
		t.Fatalf("recording reviewer row %s: rc %d\n%s", name, rc, out)
	}
}

func itoa(i int) string { return string(rune('0' + i)) }

func TestV_G3NewestVerdictPerRoleIsTheOneEvaluated(t *testing.T) {
	type tc struct {
		name    string
		setup   func(t *testing.T, k *closeKit) // appends rows; may change k.verdict (the --verdict-ref)
		closes  bool
		refusal string // substring expected in the refusal output
	}
	cases := []tc{
		{"old stale approving verifier row + newer valid verifier row closes", func(t *testing.T, k *closeKit) {
			// older (09-24) approving row whose evidence predates the GREEN (11:00 on 09-25): legacy shape
			nvVerifier(t, *k, "VSC-001-verifier-old", "2026-09-24T10:00:00Z", 5, 0, "agent-verifier-OLD", "2026-09-24")
		}, true, ""},
		{"newest verifier row stale (not later than GREEN) is refused", func(t *testing.T, k *closeKit) {
			k.verdict = nvVerifier(t, *k, "VSC-001-verifier-stale", "2026-09-25T10:30:00Z", 13, 0, "agent-verifier-E", "2026-09-26")
		}, false, "not later than the GREEN"},
		{"newest verifier outcome 1 over older outcome 0 is refused", func(t *testing.T, k *closeKit) {
			nvVerifier(t, *k, "VSC-001-verifier-fail", "2026-09-26T09:00:00Z", 14, 1, "agent-verifier-E", "2026-09-26")
		}, false, "DISAGREES"},
		{"older verifier disagreement superseded by a newer valid approval closes", func(t *testing.T, k *closeKit) {
			nvVerifier(t, *k, "VSC-001-verifier-oldfail", "2026-09-24T09:00:00Z", 6, 1, "agent-verifier-OLD", "2026-09-24")
		}, true, ""},
		{"newest verifier row by the fixer is refused even with an older independent approval", func(t *testing.T, k *closeKit) {
			nvVerifier(t, *k, "VSC-001-verifier-fixer", "2026-09-26T12:00:00Z", 15, 0, "agent-fixer-A", "2026-09-26")
		}, false, "is the fixer"},
		{"same day: later row (rowid) wins - disagreement after approval is refused", func(t *testing.T, k *closeKit) {
			nvVerifier(t, *k, "VSC-001-verifier-sameday", "2026-09-25T12:00:00Z", 16, 1, "agent-verifier-E", "2026-09-25")
		}, false, "DISAGREES"},
		{"old approving reviewer dated before the GREEN day + newer valid review closes", func(t *testing.T, k *closeKit) {
			nvReviewer(t, *k, "VSC-001-review-old", 0, "2026-09-24")
		}, true, ""},
		{"older reviewer rejection superseded by newer approval closes", func(t *testing.T, k *closeKit) {
			nvReviewer(t, *k, "VSC-001-review-oldrej", 1, "2026-09-24")
		}, true, ""},
		{"newest reviewer rejection over older approval is refused", func(t *testing.T, k *closeKit) {
			nvReviewer(t, *k, "VSC-001-review-rej", 1, "2026-09-26")
		}, false, "rejected the fix"},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			k := prepareClose(t)
			c.setup(t, &k)
			before := fileSHA(t, k.db)
			args := k.args()
			for i := range args {
				if args[i] == "--verdict-ref" {
					args[i+1] = k.verdict
				}
			}
			rc, out := gapRun(t, k.repo, k.db, args...)
			if c.closes {
				if rc != 0 {
					t.Fatalf("want the close to succeed, got rc %d\n%s", rc, out)
				}
				gapCleanIn(t, k.repo, k.db)
				return
			}
			if rc == 0 {
				t.Fatalf("want a refusal containing %q, the close succeeded\n%s", c.refusal, out)
			}
			if !strings.Contains(out, c.refusal) {
				t.Fatalf("refused, but not for %q:\n%s", c.refusal, out)
			}
			if fileSHA(t, k.db) != before {
				t.Fatal("a refused close modified the register")
			}
		})
	}
}

// ── review fixes (2026-10-08): a malformed or future-dated row can neither win nor hide ──

// nvRaw inserts a verdict row directly (the CLI refuses malformed dates), citing a real evidence path.
func nvRaw(t *testing.T, k closeKit, role, actor string, outcome int, on, evid string) {
	t.Helper()
	applySQL(t, k.db, `INSERT INTO item_verdicts (item_id,role,actor,actor_kind,on_date,outcome,evidence_path,evidence_sha256) VALUES
 ('VSC-001','`+role+`','`+actor+`','agent','`+on+`',`+itoa(outcome)+`,'`+evid+`','`+nvA+`')`)
}

func TestV_G3MalformedOrFutureRowsCanNeitherWinNorHide(t *testing.T) {
	const excl = "excluded from the newest-row ordering"
	type tc struct {
		name    string
		setup   func(t *testing.T, k *closeKit)
		refusal []string
	}
	rejV := func(t *testing.T, k *closeKit) {
		nvVerifier(t, *k, "VSC-001-verifier-fail", "2026-09-26T09:00:00Z", 14, 1, "agent-verifier-E", "2026-09-26")
	}
	rejR := func(t *testing.T, k *closeKit) { nvReviewer(t, *k, "VSC-001-review-rej", 1, "2026-09-26") }
	cases := []tc{}
	for _, d := range []string{"9999-12-31", "2099-01-01", "~", "2026-10-8", "", "2026-09-28"} {
		d := d
		cases = append(cases,
			tc{"verifier approval dated " + d + " vs later real rejection", func(t *testing.T, k *closeKit) {
				nvRaw(t, *k, "verifier", "agent-verifier-X", 0, d, k.verdict)
				rejV(t, k)
			}, []string{"DISAGREES", excl}},
			tc{"reviewer approval dated " + d + " vs later real rejection", func(t *testing.T, k *closeKit) {
				nvRaw(t, *k, "reviewer", "agent-reviewer-X", 0, d, k.review)
				rejR(t, k)
			}, []string{"rejected the fix", excl}},
			tc{"verifier row dated " + d + " alone is a finding, not skipped", func(t *testing.T, k *closeKit) {
				nvRaw(t, *k, "verifier", "agent-verifier-X", 0, d, k.verdict)
			}, []string{excl}},
			tc{"reviewer row dated " + d + " alone is a finding, not skipped", func(t *testing.T, k *closeKit) {
				nvRaw(t, *k, "reviewer", "agent-reviewer-X", 0, d, k.review)
			}, []string{excl}},
		)
	}
	cases = append(cases,
		tc{"verdict-ref naming an OLDER approving verifier row while a newer approval exists is refused", func(t *testing.T, k *closeKit) {
			nvVerifier(t, *k, "VSC-001-verifier-newer", "2026-09-25T12:00:00Z", 17, 0, "agent-verifier-E", "2026-09-26")
		}, []string{"names no valid verifier row"}},
		tc{"interleaved roles: newest verifier valid, newest reviewer a rejection", func(t *testing.T, k *closeKit) {
			nvVerifier(t, *k, "VSC-001-verifier-newer", "2026-09-25T12:00:00Z", 17, 0, "agent-verifier-E", "2026-09-26")
			nvReviewer(t, *k, "VSC-001-review-rej", 1, "2026-09-26")
		}, []string{"rejected the fix", "names no valid verifier row"}},
	)
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			k := prepareClose(t)
			c.setup(t, &k)
			before := fileSHA(t, k.db)
			rc, out := gapRun(t, k.repo, k.db, k.args()...)
			if rc == 0 {
				t.Fatalf("want a refusal, the close succeeded\n%s", out)
			}
			for _, s := range c.refusal {
				if !strings.Contains(out, s) {
					t.Fatalf("refused, but output lacks %q:\n%s", s, out)
				}
			}
			if fileSHA(t, k.db) != before {
				t.Fatal("a refused close modified the register")
			}
		})
	}
}

// The pure ordering: reopen-cut interaction (watermark and non-watermark paths), two items, interleaved roles.
func TestV_G3NewestSelectionUnit(t *testing.T) {
	row := func(role, actor string, outcome int, on string) verdictRow {
		return verdictRow{role: role, actor: actor, kind: "agent", evid: "ev/" + actor, onDate: on, outcome: outcome}
	}
	const asOf = "2026-09-27"
	t.Run("no reopen: newest per role, roles independent and interleaved", func(t *testing.T) {
		vs := []verdictRow{row("verifier", "v1", 0, "2026-09-24"), row("reviewer", "r1", 0, "2026-09-26"), row("verifier", "v2", 1, "2026-09-25"), row("reviewer", "r2", 1, "2026-09-25")}
		n, ex := newestVerdictPerRole(vs, reopenCut{idx: -1}, asOf)
		if len(ex) != 0 || n["verifier"] != 2 || n["reviewer"] != 1 {
			t.Fatalf("got newest %v excluded %v", n, ex)
		}
	})
	t.Run("two items do not interact", func(t *testing.T) {
		a := []verdictRow{row("verifier", "v1", 0, "2026-09-24")}
		b := []verdictRow{row("verifier", "v9", 1, "2026-09-26")}
		na, _ := newestVerdictPerRole(a, reopenCut{idx: -1}, asOf)
		nb, _ := newestVerdictPerRole(b, reopenCut{idx: -1}, asOf)
		if va := a[na["verifier"]]; va.actor != "v1" {
			t.Fatal("item A")
		}
		if vb := b[nb["verifier"]]; vb.actor != "v9" {
			t.Fatal("item B")
		}
	})
	t.Run("same day: later insertion wins", func(t *testing.T) {
		vs := []verdictRow{row("verifier", "v1", 0, "2026-09-25"), row("verifier", "v2", 1, "2026-09-25")}
		if n, _ := newestVerdictPerRole(vs, reopenCut{idx: -1}, asOf); n["verifier"] != 1 {
			t.Fatalf("got %v", n)
		}
	})
	t.Run("non-watermark reopen cut: rows dated on/before the reopen day are history", func(t *testing.T) {
		vs := []verdictRow{row("verifier", "v1", 0, "2026-09-24"), row("verifier", "v2", 0, "2026-09-26"), row("verifier", "v3", 1, "2026-09-25")}
		cut := reopenCut{idx: 0, onDate: "2026-09-25"}
		n, _ := newestVerdictPerRole(vs, cut, asOf)
		if n["verifier"] != 1 {
			t.Fatalf("the stale 09-25 rejection must not be newest: %v", n)
		}
		if n2, _ := newestVerdictPerRole(vs[:1], cut, asOf); len(n2) != 0 {
			t.Fatalf("all rows stale: want no newest, got %v", n2)
		}
	})
	t.Run("watermark reopen cut: stale-key rows are history, a later fresh row wins", func(t *testing.T) {
		vs := []verdictRow{row("reviewer", "r1", 0, "2026-09-26"), row("reviewer", "r2", 1, "2026-09-26")}
		cut := reopenCut{idx: 0, watermark: true, stale: map[string]bool{verdictKey(vs[1]): true}}
		n, _ := newestVerdictPerRole(vs, cut, asOf)
		if n["reviewer"] != 0 {
			t.Fatalf("the stale rejection is history; fresh r1 is newest: %v", n)
		}
	})
	t.Run("bad dates are excluded and reported, never newest", func(t *testing.T) {
		vs := []verdictRow{row("reviewer", "r1", 1, "2026-09-26"), row("reviewer", "r2", 0, "9999-12-31"), row("reviewer", "r3", 0, "~"), row("reviewer", "r4", 0, "2026-9-26"), row("reviewer", "r5", 0, ""), row("reviewer", "r6", 0, "2026-09-28")}
		n, ex := newestVerdictPerRole(vs, reopenCut{idx: -1}, asOf)
		if n["reviewer"] != 0 || len(ex) != 5 {
			t.Fatalf("got newest %v excluded %v", n, ex)
		}
	})
	t.Run("stale bad-dated rows (before the cut) are not reported", func(t *testing.T) {
		vs := []verdictRow{row("reviewer", "r2", 0, "9999-12-31")}
		cut := reopenCut{idx: 0, watermark: true, stale: map[string]bool{verdictKey(vs[0]): true}}
		if _, ex := newestVerdictPerRole(vs, cut, asOf); len(ex) != 0 {
			t.Fatalf("stale row reported: %v", ex)
		}
	})
}
