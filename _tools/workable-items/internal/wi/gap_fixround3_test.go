package wi

// Fix round 3 (round-2 re-review): I1 (a)-(d), I2, I3, M1, M2, M3. Written
// before the fixes and observed failing first.

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// hasDetail reports a finding of rule on item whose detail contains text.
func hasDetail(rep *Report, rule, item, text string) bool {
	for _, f := range rep.Findings {
		if f.Rule == rule && f.ItemID == item && strings.Contains(f.Detail, text) {
			return true
		}
	}
	return false
}

func TestRound3GoldenBadFixturesTripExactlyTheirRules(t *testing.T) {
	cases := []struct {
		file  string
		rules []string
	}{
		{"V-G3-V-G9-future", []string{"V-G3", "V-G9"}},
		{"V-G3-green-rewritten", []string{"V-G3"}},
		{"V-G1-reopen-bad", []string{"V-G1"}},
		{"V-G3-research-absolute", []string{"V-G3"}},
		{"V-G3-diary-unrelated", []string{"V-G3"}},
		{"V-G3-diary-before-green", []string{"V-G3"}},
	}
	for _, c := range cases {
		t.Run(c.file, func(t *testing.T) {
			rep := validateGapFixture(t, buildRegister(t, true, "golden-good.sql", "golden-bad/"+c.file+".sql"), fixtureAsOf, fixtureRoster())
			if rep.ExitCode() != 1 {
				t.Fatalf("want rc 1, got %d: findings=%v undet=%v", rep.ExitCode(), rep.Findings, rep.Undetermined)
			}
			if got := sortedRules(rep); strings.Join(got, ",") != strings.Join(c.rules, ",") {
				t.Fatalf("want exactly %v, got %v: %v", c.rules, got, rep.Findings)
			}
		})
	}
}

// ── I1 (d): zero skew for GREEN and verifier timestamps ────────────────────

func TestI1dAGreenOrVerifierDatedAfterNowIsRefusedEvenMinutesAhead(t *testing.T) {
	k := prepareClose(t) // package clock 2026-09-27T00:00:00Z
	b := strings.Repeat("b", 64)
	g := writeRecord(t, k.repo, "ev/VSC-001-green-plus4m.json", map[string]any{"item_id": "VSC-001", "check_id": "CHK-vsc-001",
		"outcome": 0, "state_fingerprint_before": b, "state_fingerprint_after": b, "ts": "2026-09-27T00:04:00Z", "chain_seq": 80})
	v := writeRecord(t, k.repo, "ev/VSC-001-verifier-plus4m30.json", map[string]any{"item_id": "VSC-001", "check_id": "CHK-vsc-001",
		"outcome": 0, "verdict_role": "verifier", "state_fingerprint_before": b, "state_fingerprint_after": b, "ts": "2026-09-27T00:04:30Z", "chain_seq": 81})
	if rc, out := gapRun(t, k.repo, k.db, "verdict", "--id", "VSC-001", "--role", "verifier", "--actor", "agent-verifier-C",
		"--actor-kind", "agent", "--outcome", "0", "--evidence", v, "--on", clockAsOf); rc != 1 || !strings.Contains(out, "in the future") {
		t.Fatalf("verifier record 4.5 minutes ahead: want rc 1 'in the future', got %d\n%s", rc, out)
	}
	applySQL(t, k.db, `DELETE FROM item_verdicts WHERE item_id='VSC-001' AND role='verifier';
INSERT INTO item_verdicts (item_id,role,actor,actor_kind,on_date,outcome,evidence_path) VALUES ('VSC-001','verifier','agent-verifier-C','agent','2026-09-27',0,'`+v+`')`)
	if rc, out := gapRun(t, k.repo, k.db, withArg(withArg(k.args(), "--green-evidence", g), "--verdict-ref", v)...); rc != 1 || !strings.Contains(out, "in the future") {
		t.Fatalf("GREEN 4 minutes ahead: want rc 1 'in the future', got %d\n%s", rc, out)
	}
}

// ── I1 (c): a reopen's failure must post-date the latest GREEN ─────────────

func TestI1cReopenRefusesAFailureNotLaterThanTheLatestGreen(t *testing.T) {
	repo, db := gapRepo(t), buildRegister(t, true, "golden-good.sql")
	// VSC-004's GREEN is 2026-09-25T11:00Z; move its closure stamp before it.
	applySQL(t, db, `UPDATE item_history SET created_at='2026-09-25 10:00:00' WHERE atm_id='VSC-004' AND event_type='Fixed'`)
	fail := writeRecord(t, repo, "ev/VSC-004-fail-1030.json", map[string]any{"item_id": "VSC-004", "check_id": "CHK-vsc-004",
		"outcome": 1, "exit_status": 1, "verdict_role": "verifier", "ts": "2026-09-25T10:30:00Z", "chain_seq": 82})
	if rc, out := gapRun(t, repo, db, "reopen", "--id", "VSC-004", "--evidence", fail, "--plan-due", "2026-12-31", "--as-of", clockAsOf); rc != 1 || !strings.Contains(out, "latest GREEN") {
		t.Fatalf("failure dated before the latest GREEN: want rc 1 naming the latest GREEN, got %d\n%s", rc, out)
	}
}

// ── I1 (a): the cut covers every evidence time cited before the reopen ─────

func TestI1aTheCutCoversEveryEvidenceTimeCitedBeforeTheReopen(t *testing.T) {
	root := fixtureRoot(t, false)
	e, f, g := strings.Repeat("e", 64), strings.Repeat("f", 64), strings.Repeat("c", 64)
	rec := func(rel string, m map[string]any) string { return writeRecord(t, root, rel, m) }
	green := rec("ev/green-1204.json", map[string]any{"item_id": "VSC-004", "check_id": "CHK-vsc-004", "outcome": 0,
		"state_fingerprint_before": e, "state_fingerprint_after": e, "ts": "2026-09-25T12:04:00Z", "chain_seq": 70})
	ver := rec("ev/verifier-120430.json", map[string]any{"item_id": "VSC-004", "check_id": "CHK-vsc-004", "outcome": 0, "verdict_role": "verifier",
		"state_fingerprint_before": e, "state_fingerprint_after": e, "ts": "2026-09-25T12:04:30Z", "chain_seq": 71})
	fail := rec("ev/fail-120030.json", map[string]any{"item_id": "VSC-004", "check_id": "CHK-vsc-004", "outcome": 1, "exit_status": 1, "verdict_role": "verifier",
		"state_fingerprint_before": g, "state_fingerprint_after": g, "ts": "2026-09-25T12:00:30Z", "chain_seq": 72})
	green2 := rec("ev/green2-1202.json", map[string]any{"item_id": "VSC-004", "check_id": "CHK-vsc-004", "outcome": 0,
		"state_fingerprint_before": f, "state_fingerprint_after": f, "ts": "2026-09-25T12:02:00Z", "chain_seq": 73})
	ver2 := rec("ev/verifier2-1203.json", map[string]any{"item_id": "VSC-004", "check_id": "CHK-vsc-004", "outcome": 0, "verdict_role": "verifier",
		"state_fingerprint_before": f, "state_fingerprint_after": f, "ts": "2026-09-25T12:03:00Z", "chain_seq": 74})
	rev2 := writeText(t, root, "ev/review2.md", "second review of VSC-004\n")
	touch(t, root, rev2, "2026-09-25T12:02:30Z")
	path := buildRegister(t, true, "golden-good.sql")
	applySQL(t, path, `
UPDATE item_history SET evidence_path='`+green+`' WHERE atm_id='VSC-004' AND (reason LIKE 'zero-gap:green-evidence%' OR event_type='Fixed');
UPDATE item_history SET reason=replace(reason,'`+ev+`VSC-004-verifier.json','`+ver+`') WHERE atm_id='VSC-004' AND event_type='Fixed';
UPDATE item_verdicts SET evidence_path='`+ver+`' WHERE item_id='VSC-004' AND role='verifier';
UPDATE test_diary SET evidence_path='`+green+`', date_time='2026-09-25T12:05:00Z' WHERE atm_id='VSC-004';
INSERT INTO item_history (atm_id,event_type,by,on_date,reason,evidence_path,created_at) VALUES
 ('VSC-004','Reopened','AI','2026-09-25','captured-evidence-contradicts','`+fail+`','2026-09-25 12:01:00'),
 ('VSC-004','Updated','AI','2026-09-26','zero-gap:red-evidence check=CHK-vsc-004','`+ev+`VSC-004-red.json','2026-09-26 12:10:00'),
 ('VSC-004','Updated','AI','2026-09-26','zero-gap:green-evidence check=CHK-vsc-004','`+green2+`','2026-09-26 12:10:00'),
 ('VSC-004','Fixed','AI','2026-09-26','zero-gap:close fixer=agent-fixer-A check-author=agent-author-B verdict=`+ver2+`','`+green2+`','2026-09-26 12:10:00');
INSERT INTO item_verdicts (item_id,role,actor,actor_kind,on_date,outcome,evidence_path) VALUES
 ('VSC-004','verifier','agent-verifier-C','agent','2026-09-26',0,'`+ver2+`'),
 ('VSC-004','reviewer','agent-reviewer-D','agent','2026-09-26',0,'`+rev2+`');
INSERT INTO test_diary (atm_id,date_time,tested_by,result,observations,action_taken,evidence_path)
 VALUES ('VSC-004','2026-09-25T12:02:30Z','AI-agent','PASS','run','none','`+green2+`');`)
	rep := validateGapIn(t, root, path, clockAsOf, fixtureRoster())
	found := false
	for _, fd := range rep.Findings {
		if fd.Rule == "V-G3" && fd.ItemID == "VSC-004" && strings.Contains(fd.Detail, "GREEN evidence "+green2) && strings.Contains(fd.Detail, "predates the latest reopen") {
			found = true
		}
	}
	if !found {
		t.Fatalf("a GREEN measured at 12:02 counted after a reopen whose earlier closure cited evidence up to 12:04:30: %v", rep.Findings)
	}
}

// ── I1 (b): a file cited in a previous closure never satisfies a later one ─

func TestI1bAFileFromAPreviousClosureNeverCountsAgain(t *testing.T) {
	for _, which := range []string{"GREEN copy", "verifier under a new actor"} {
		t.Run(which, func(t *testing.T) {
			k := prepareClose(t)
			if rc, out := gapRun(t, k.repo, k.db, k.args()...); rc != 0 {
				t.Fatalf("first close: rc %d\n%s", rc, out)
			}
			fail := reopenVSC001(t, k)
			setClock(t, "2026-09-27T17:00:00Z")
			args := withArg(k.args(), "--red-evidence", fail)
			switch which {
			case "GREEN copy":
				b, _ := os.ReadFile(filepath.Join(k.repo, k.green))
				cp := writeText(t, k.repo, "ev/VSC-001-green-copy.json", string(b))
				args = withArg(args, "--green-evidence", cp)
			case "verifier under a new actor":
				// Everything else is fresh, so only the reused verifier file is at issue.
				e := strings.Repeat("e", 64)
				green := writeRecord(t, k.repo, "ev/VSC-001-green2.json", map[string]any{"item_id": "VSC-001", "check_id": "CHK-vsc-001",
					"outcome": 0, "state_fingerprint_before": e, "state_fingerprint_after": e, "ts": "2026-09-27T16:00:00Z", "chain_seq": 41})
				rev := writeText(t, k.repo, "ev/VSC-001-review2.md", "second review\n")
				touch(t, k.repo, rev, "2026-09-27T16:10:00Z")
				addDiary(t, k.db, green, "2026-09-27T16:05:00Z")
				gapRun(t, k.repo, k.db, "verdict", "--id", "VSC-001", "--role", "reviewer", "--actor", "agent-reviewer-D",
					"--actor-kind", "agent", "--outcome", "0", "--evidence", rev, "--on", clockAsOf)
				applySQL(t, k.db, `INSERT INTO item_verdicts (item_id,role,actor,actor_kind,on_date,outcome,evidence_path)
                    VALUES ('VSC-001','verifier','agent-verifier-NEW','agent','2026-09-28',0,'`+k.verdict+`')`)
				args = withArg(args, "--green-evidence", green)
			}
			want := map[string]string{"GREEN copy": "GREEN evidence ev/VSC-001-green-copy.json was used in a previous closure",
				"verifier under a new actor": "verifier evidence " + k.verdict + " was used in a previous closure"}[which]
			rc, out := gapRun(t, k.repo, k.db, args...)
			if rc != 1 || !strings.Contains(out, want) {
				t.Fatalf("want rc 1 naming reuse from a previous closure, got %d\n%s", rc, out)
			}
		})
	}
}

// ── I2: validate agrees with the commands about future dates ──────────────

func TestI2ValidateFlagsEvidenceDatedAfterTheAsOfDay(t *testing.T) {
	k := prepareClose(t)
	setClock(t, "2031-01-01T02:00:00Z")
	b := strings.Repeat("b", 64)
	g := writeRecord(t, k.repo, "ev/VSC-001-green-2031.json", map[string]any{"item_id": "VSC-001", "check_id": "CHK-vsc-001",
		"outcome": 0, "state_fingerprint_before": b, "state_fingerprint_after": b, "ts": "2031-01-01T00:00:00Z", "chain_seq": 90})
	v := writeRecord(t, k.repo, "ev/VSC-001-verifier-2031.json", map[string]any{"item_id": "VSC-001", "check_id": "CHK-vsc-001",
		"outcome": 0, "verdict_role": "verifier", "state_fingerprint_before": b, "state_fingerprint_after": b, "ts": "2031-01-01T00:30:00Z", "chain_seq": 91})
	applySQL(t, k.db, `DELETE FROM item_verdicts WHERE item_id='VSC-001' AND role='verifier'`)
	if rc, out := gapRun(t, k.repo, k.db, "verdict", "--id", "VSC-001", "--role", "verifier", "--actor", "agent-verifier-C",
		"--actor-kind", "agent", "--outcome", "0", "--evidence", v, "--on", "2031-01-01"); rc != 0 {
		t.Fatalf("verdict at a 2031 clock: rc %d\n%s", rc, out)
	}
	addDiary(t, k.db, g, "2031-01-01T01:00:00Z")
	args := withArg(withArg(withArg(k.args(), "--green-evidence", g), "--verdict-ref", v), "--as-of", "2031-01-01")
	if rc, out := gapRun(t, k.repo, k.db, args...); rc != 0 {
		t.Fatalf("close at a 2031 clock: rc %d\n%s", rc, out)
	}
	r, _ := LoadRoster(k.repo)
	rep := validateGapIn(t, k.repo, k.db, clockAsOf, r)
	if !hasDetail(rep, "V-G3", "VSC-001", "after the end of --as-of") || !hasDetail(rep, "V-G9", "VSC-001", "after the end of --as-of") {
		t.Fatalf("evidence dated 2031 passed validate --as-of %s: rc %d %v", clockAsOf, rep.ExitCode(), rep.Findings)
	}
}

// ── I3: every cited file's sha256 is recorded and re-checked ──────────────

func TestI3AFileChangedAfterClosureIsCaught(t *testing.T) {
	for _, target := range []string{"green", "red", "verifier", "review", "research"} {
		for _, how := range []string{"rewrite", "symlink swap"} {
			t.Run(target+"/"+how, func(t *testing.T) {
				k := prepareClose(t)
				if rc, out := gapRun(t, k.repo, k.db, k.args()...); rc != 0 {
					t.Fatalf("close: rc %d\n%s", rc, out)
				}
				gapCleanIn(t, k.repo, k.db)
				rel := map[string]string{"green": k.green, "red": k.red, "verifier": k.verdict, "review": k.review, "research": k.research}[target]
				full := filepath.Join(k.repo, rel)
				orig, _ := os.ReadFile(full)
				var altered string
				if strings.HasSuffix(rel, ".json") {
					altered = strings.Replace(string(orig), `"stdout_bytes":0`, `"stdout_bytes":7`, 1)
				} else {
					altered = string(orig) + "edited after closure\n"
				}
				if altered == string(orig) {
					t.Fatal("the alteration changed nothing")
				}
				switch how {
				case "rewrite":
					os.WriteFile(full, []byte(altered), 0o644)
				case "symlink swap":
					other := writeText(t, k.repo, "ev/swapped-"+filepath.Base(rel), altered)
					os.Remove(full)
					if err := os.Symlink(filepath.Join(k.repo, other), full); err != nil {
						t.Fatal(err)
					}
				}
				r, _ := LoadRoster(k.repo)
				rep := validateGapIn(t, k.repo, k.db, clockAsOf, r)
				if !hasDetail(rep, "V-G3", "VSC-001", "changed after it was cited") {
					t.Fatalf("%s %s after closure went undetected: rc %d %v", target, how, rep.ExitCode(), rep.Findings)
				}
			})
		}
	}
}

// ── M2: paths must stay inside the repository root ────────────────────────

func TestM2EvidenceOutsideTheRootIsRefused(t *testing.T) {
	k := prepareClose(t)
	outside := filepath.Join(filepath.Dir(k.repo), "outside-evidence.json")
	b, _ := os.ReadFile(filepath.Join(k.repo, k.verdict))
	os.WriteFile(outside, b, 0o644)
	t.Cleanup(func() { os.Remove(outside) })
	os.Symlink(outside, filepath.Join(k.repo, "ev/link-out.json"))
	for name, p := range map[string]string{
		"dot-dot":           "../" + filepath.Base(outside),
		"absolute":          outside,
		"symlink leaves it": "ev/link-out.json",
	} {
		if rc, out := gapRun(t, k.repo, k.db, "verdict", "--id", "VSC-001", "--role", "verifier", "--actor", "agent-verifier-X",
			"--actor-kind", "agent", "--outcome", "0", "--evidence", p, "--on", clockAsOf); rc != 1 || !strings.Contains(out, "repository root") {
			t.Fatalf("gap verdict with %s evidence: want rc 1 naming the repository root, got %d\n%s", name, rc, out)
		}
	}
	// validate: a research_ref that climbs out of the root.
	path := buildRegister(t, true, "golden-good.sql")
	root := fixtureRoot(t, false)
	out2 := filepath.Join(filepath.Dir(root), "outside-research.md")
	os.WriteFile(out2, []byte("research kept outside the repository\n"), 0o644)
	t.Cleanup(func() { os.Remove(out2) })
	applySQL(t, path, `UPDATE items SET research_ref='../`+filepath.Base(out2)+`' WHERE atm_id='VSC-004'`)
	rep := validateGapIn(t, root, path, fixtureAsOf, fixtureRoster())
	if !hasDetail(rep, "V-G3", "VSC-004", "inside the repository root") {
		t.Fatalf("a research_ref outside the root was accepted: %v", rep.Findings)
	}
}

// I3 storage: item_verdicts gains a nullable evidence_sha256 column. A register
// migrated before round 3 (7-column item_verdicts) is extended additively by the
// next `gap migrate`, whose second run is again a no-op.
func TestI3MigrateAddsTheVerdictDigestColumnAdditively(t *testing.T) {
	path := buildRegister(t, false, "legacy-register.sql")
	db := rawOpen(t, path)
	if _, err := db.Exec(`CREATE TABLE item_verdicts (
    item_id TEXT NOT NULL, role TEXT NOT NULL CHECK (role IN ('verifier','reviewer')), actor TEXT NOT NULL,
    actor_kind TEXT NOT NULL CHECK (actor_kind IN ('agent','script')), on_date TEXT NOT NULL,
    outcome INTEGER NOT NULL CHECK (outcome IN (0,1,2)), evidence_path TEXT NOT NULL);
INSERT INTO item_verdicts (item_id,role,actor,actor_kind,on_date,outcome,evidence_path) VALUES ('VSC-001','verifier','a','agent','2026-09-25',0,'e');`); err != nil {
		t.Fatal(err)
	}
	res, err := Migrate(db, false)
	if err != nil {
		t.Fatalf("migrating a round-2 item_verdicts table: %v", err)
	}
	if !strings.Contains(strings.Join(res.Statements, "\n"), "ALTER TABLE item_verdicts ADD COLUMN evidence_sha256 TEXT;") {
		t.Fatalf("the digest column was not added: %v", res.Statements)
	}
	var n int
	db.QueryRow(`SELECT count(*) FROM item_verdicts WHERE item_id='VSC-001' AND evidence_sha256 IS NULL`).Scan(&n)
	if n != 1 {
		t.Fatal("the existing verdict row did not survive the migration")
	}
	if res2, err := Migrate(db, false); err != nil || len(res2.Statements) != 0 {
		t.Fatalf("second migration: %v %v", err, res2)
	}
}
