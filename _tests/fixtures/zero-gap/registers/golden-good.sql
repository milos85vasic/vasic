-- golden-good.sql — a register that every validator MUST accept (feature 010, T010).
--
-- Build order (see _tools/workable-items/internal/wi/fixtures_test.go):
--   1. canonical-schema.sql      the pre-migration register
--   2. `gap migrate`             adds the 14 gap columns and the item_verdicts table
--   3. this file                 six gap items, one per final state the register allows
--
-- Every evidence_path / research_ref below is repository-relative and resolves to a
-- file under _tests/fixtures/zero-gap/registers/evidence/, so both the umbrella
-- validator and the canonical binary (which resolves paths against its working
-- directory) can check them when run from the repository root.
--
-- Actors: the fixer of VSC-004 is agent-fixer-A; its closure check was authored by
-- agent-author-B; the independent verifier is agent-verifier-C and the reviewer is
-- agent-reviewer-D — four different actors, as FR-018/FR-022 and §11.4.240(C)(1) need.
--
-- Digests (fix round 3, I3): the RED/GREEN history reasons carry `sha256=<hex>`, the closure row
-- carries `research-sha256=<hex>` and each verdict row its evidence_sha256 — the sha256 of the cited
-- fixture file, recomputed by TestFixtureGoldenGoodIsCleanUnderEveryValidator via the validator.
--
-- Dates: every plan_due / classification_recheck is 2026-12-31, so the register is
-- clean at --as-of 2026-09-25 and an elapsed-date mutation only needs a later --as-of.

-- VSC-001 — open defect with a dated plan (FR-006 "open with a dated plan").
INSERT INTO items (atm_id,type,status,severity,title,description,forensic_anchor,closure_criteria,
  created_by,assigned_to,current_location,body_md,created_at,last_modified,
  kind,category,disposition,plan_due,sweep_class,first_seen_fingerprint,reopens_count)
VALUES ('VSC-001','Bug','Queued','high','example gate reports PASS over an empty population',
  'The example gate enumerates zero files and still prints PASS, which is a vacuous green result.',
  'scripts/zero-gap-class-example.sh:12','the gate returns rc 2 on an empty population',
  'AI','agent-owner','Issues',
  '## VSC-001 — example gate reports PASS over an empty population

**Status:** Queued
**Type:** Bug
**Severity:** high
**Created-By:** AI
**Assigned-To:** agent-owner

The example gate enumerates zero files and still prints PASS, which is a vacuous green result.

',
  '2026-09-25 10:00:00','2026-09-25 10:00:00',
  'defect','false-evidence','open','2026-12-31','SC-example',
  'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',0);

-- VSC-002 — classified third-party (status stays the exact value Queued; D2).
INSERT INTO items (atm_id,type,status,severity,title,description,forensic_anchor,
  created_by,assigned_to,current_location,body_md,created_at,last_modified,
  kind,category,disposition,classification_reason,classification_owner,classification_recheck,
  sweep_class,reopens_count)
VALUES ('VSC-002','Bug','Queued','critical','upstream guard cites a consumer clause instead of the universal anchor',
  'The upstream guard refusal text cites a consuming-project clause; the fix belongs upstream, not here.',
  'submodules/constitution/scripts/hooks/guard-forbidden-commands.sh',
  'AI','agent-owner','Issues',
  '## VSC-002 — upstream guard cites a consumer clause instead of the universal anchor

**Status:** Queued
**Type:** Bug
**Severity:** critical
**Created-By:** AI
**Assigned-To:** agent-owner

The upstream guard refusal text cites a consuming-project clause; the fix belongs upstream, not here.

',
  '2026-09-25 10:00:00','2026-09-25 10:00:00',
  'danger-zone','security','classified','third-party','upstream issue tracker of the constitution repository','2026-12-31',
  'SC-example',0);

-- VSC-003 — classified operator-action (status Operator-blocked + options and cost; FR-009).
INSERT INTO items (atm_id,type,status,severity,title,description,forensic_anchor,
  created_by,assigned_to,current_location,body_md,created_at,last_modified,
  kind,category,disposition,classification_reason,classification_owner,classification_recheck,
  sweep_class,reopens_count)
VALUES ('VSC-003','Task','Operator-blocked','medium','export validator cannot OCR rendered pages on this host',
  'The export validator skips its OCR check because the OCR engine is not installed on the development host.',
  'scripts/validate-export.sh',
  'AI','agent-owner','Issues',
  '## VSC-003 — export validator cannot OCR rendered pages on this host

**Status:** Operator-blocked
**Type:** Task
**Severity:** medium
**Created-By:** AI
**Assigned-To:** agent-owner

The export validator skips its OCR check because the OCR engine is not installed on the development host.

',
  '2026-09-25 10:00:00','2026-09-25 10:00:00',
  'weak-spot','host-capability','classified','operator-action','operator','2026-12-31',
  'SC-example',0);
INSERT INTO operator_block_details (atm_id,what,why_exhausted_alternatives,unblock_condition,who)
VALUES ('VSC-003','install the OCR engine package on the development host',
  'a package install is an operator action; no user-space build of the engine exists in this tree',
  '- install the distribution OCR package — cost: one package install, about 30 MB of disk
- run the validator inside a container image that ships the engine — cost: one image pull and a slower validator run',
  'operator');

-- VSC-004 — closed with evidence (RED+GREEN same check id, verifier, reviewer, research).
INSERT INTO items (atm_id,type,status,severity,title,description,forensic_anchor,closure_criteria,
  created_by,assigned_to,current_location,body_md,created_at,last_modified,
  kind,category,disposition,research_ref,sweep_class,first_seen_fingerprint,reopens_count)
VALUES ('VSC-004','Bug','Fixed (→ Fixed.md)','high','gate recorded PASS over a missing evidence artefact',
  'The gate accepted a closure whose evidence path did not resolve, recording PASS without any artefact.',
  'scripts/verify-example.sh:40','the gate refuses a closure whose evidence does not resolve',
  'AI','agent-owner','Fixed',
  '## VSC-004 — gate recorded PASS over a missing evidence artefact

**Status:** Fixed (→ Fixed.md)
**Type:** Bug
**Evidence:** _tests/fixtures/zero-gap/registers/evidence/VSC-004-green.json
**Severity:** high
**Created-By:** AI
**Assigned-To:** agent-owner

The gate accepted a closure whose evidence path did not resolve, recording PASS without any artefact.

',
  '2026-09-25 10:00:00','2026-09-25 12:00:00',
  'defect','false-evidence','closed','_tests/fixtures/zero-gap/registers/evidence/VSC-004-research.md',
  'SC-example','aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',0);

-- VSC-005 — open improvement with a measurable target (FR-025).
INSERT INTO items (atm_id,type,status,severity,title,description,forensic_anchor,
  created_by,assigned_to,current_location,body_md,created_at,last_modified,
  kind,category,disposition,plan_due,measurable_target,sweep_class,reopens_count)
VALUES ('VSC-005','Task','Queued','low','add a fuzz test for the evidence-record parser',
  'The evidence-record parser has unit tests only; a fuzz test would exercise malformed JSON inputs.',
  '_tools/workable-items/internal/wi/gapevidence.go',
  'AI','agent-owner','Issues',
  '## VSC-005 — add a fuzz test for the evidence-record parser

**Status:** Queued
**Type:** Task
**Severity:** low
**Created-By:** AI
**Assigned-To:** agent-owner

The evidence-record parser has unit tests only; a fuzz test would exercise malformed JSON inputs.

',
  '2026-09-25 10:00:00','2026-09-25 10:00:00',
  'improvement','test-coverage','open','2026-12-31',
  'coverage.tsv cell (evidence-parser, fuzz) moves from gap to a registered check that executes more than 0 cases',
  'manual',0);

-- VSC-006 — open recurrence linked to its (open) head VSC-001 (FR-008, §11.4.214).
INSERT INTO items (atm_id,type,status,severity,title,description,forensic_anchor,
  created_by,assigned_to,current_location,body_md,created_at,last_modified,
  kind,category,disposition,plan_due,recurrence_of,sweep_class,reopens_count)
VALUES ('VSC-006','Bug','Queued','high','example gate reports PASS over an empty population again',
  'A second sweep found the same vacuous PASS in a sibling gate; it is linked to the first record.',
  'scripts/zero-gap-class-example-2.sh:12',
  'AI','agent-owner','Issues',
  '## VSC-006 — example gate reports PASS over an empty population again

**Status:** Queued
**Type:** Bug
**Severity:** high
**Created-By:** AI
**Assigned-To:** agent-owner

A second sweep found the same vacuous PASS in a sibling gate; it is linked to the first record.

',
  '2026-09-25 10:00:00','2026-09-25 10:00:00',
  'defect','false-evidence','open','2026-12-31','VSC-001','SC-example',0);

INSERT INTO doc_segments (document,seq,kind,atm_id) VALUES
  ('Issues',0,'item','VSC-001'), ('Issues',1,'item','VSC-002'), ('Issues',2,'item','VSC-003'),
  ('Issues',3,'item','VSC-005'), ('Issues',4,'item','VSC-006'), ('Fixed',0,'item','VSC-004');

INSERT INTO item_provenance (atm_id,source_kind,source_path,source_locator,evidence_class,status_note) VALUES
  ('VSC-001','session-work','_tests/fixtures/zero-gap/registers/evidence/legacy-completion.md','T010 fixture','undetermined','fixture row'),
  ('VSC-002','session-work','_tests/fixtures/zero-gap/registers/evidence/legacy-completion.md','T010 fixture','undetermined','fixture row'),
  ('VSC-003','session-work','_tests/fixtures/zero-gap/registers/evidence/legacy-completion.md','T010 fixture','undetermined','fixture row'),
  ('VSC-004','session-work','_tests/fixtures/zero-gap/registers/evidence/legacy-completion.md','T010 fixture','undetermined','fixture row'),
  ('VSC-005','session-work','_tests/fixtures/zero-gap/registers/evidence/legacy-completion.md','T010 fixture','undetermined','fixture row'),
  ('VSC-006','session-work','_tests/fixtures/zero-gap/registers/evidence/legacy-completion.md','T010 fixture','undetermined','fixture row');

INSERT INTO item_history (atm_id,event_type,by,on_date,reason,evidence_path,created_at) VALUES
  ('VSC-001','Opened','AI','2026-09-25','zero-gap:opened sweep_class=SC-example','_tests/fixtures/zero-gap/registers/evidence/sweep-finding.json','2026-09-25 10:00:00'),
  ('VSC-002','Opened','AI','2026-09-25','zero-gap:opened sweep_class=SC-example','_tests/fixtures/zero-gap/registers/evidence/sweep-finding.json','2026-09-25 10:00:00'),
  ('VSC-003','Opened','AI','2026-09-25','zero-gap:opened sweep_class=SC-example','_tests/fixtures/zero-gap/registers/evidence/sweep-finding.json','2026-09-25 10:00:00'),
  ('VSC-004','Opened','AI','2026-09-25','zero-gap:opened sweep_class=SC-example','_tests/fixtures/zero-gap/registers/evidence/sweep-finding.json','2026-09-25 10:00:00'),
  ('VSC-005','Opened','AI','2026-09-25','zero-gap:opened sweep_class=manual','_tests/fixtures/zero-gap/registers/evidence/sweep-finding.json','2026-09-25 10:00:00'),
  ('VSC-006','Opened','AI','2026-09-25','zero-gap:opened sweep_class=SC-example','_tests/fixtures/zero-gap/registers/evidence/sweep-finding.json','2026-09-25 10:00:00'),
  ('VSC-004','Updated','AI','2026-09-25','zero-gap:red-evidence check=CHK-vsc-004 sha256=dc2a7de58ef9ab1ec24229c1b4e2adb34972619a1c7e252faea82bc44dd70dfe','_tests/fixtures/zero-gap/registers/evidence/VSC-004-red.json','2026-09-25 12:00:00'),
  ('VSC-004','Updated','AI','2026-09-25','zero-gap:green-evidence check=CHK-vsc-004 sha256=7ec2366ec23fc19ac0c411f0e14f1330d95656ad8a0e681b1db6651432eaf329','_tests/fixtures/zero-gap/registers/evidence/VSC-004-green.json','2026-09-25 12:00:00'),
  ('VSC-004','Fixed','AI','2026-09-25','zero-gap:close fixer=agent-fixer-A check-author=agent-author-B verdict=_tests/fixtures/zero-gap/registers/evidence/VSC-004-verifier.json research-sha256=a8f3a8f562294c4f54b376d892526456c50a9a6003d4c679c8c4aebfd2e9c5eb','_tests/fixtures/zero-gap/registers/evidence/VSC-004-green.json','2026-09-25 12:00:00');

INSERT INTO test_diary (atm_id,date_time,tested_by,result,result_detail,observations,action_taken,
  status_changed,status_from,status_to,evidence_path,created_at)
VALUES ('VSC-004','2026-09-25T12:00:00Z','AI-agent','PASS','check CHK-vsc-004 outcome 0',
  'zero-gap green evidence for check CHK-vsc-004','closed by gap close',
  1,'Queued','Fixed (→ Fixed.md)','_tests/fixtures/zero-gap/registers/evidence/VSC-004-green.json','2026-09-25 12:00:00');

INSERT INTO item_verdicts (item_id,role,actor,actor_kind,on_date,outcome,evidence_path,evidence_sha256) VALUES
  ('VSC-004','verifier','agent-verifier-C','agent','2026-09-25',0,'_tests/fixtures/zero-gap/registers/evidence/VSC-004-verifier.json','e21853ac7700a3e57b605d95dd908673cde6ab94be1840590f990bd8c4bb3335'),
  ('VSC-004','reviewer','agent-reviewer-D','agent','2026-09-25',0,'_tests/fixtures/zero-gap/registers/evidence/VSC-004-review.md','e06eaded1cac7065109fbbc6ac5551c2420aafcc1c748f54e58748ebfc9d5863');
