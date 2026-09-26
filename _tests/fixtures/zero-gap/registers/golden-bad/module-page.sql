-- golden-bad/module-page.sql — mutation of golden-good.sql for `report --by-module` (feature 010, T037).
-- Three problems, each of which the per-module page MUST name, and each of which makes it exit 1:
--   1. ZZZ-001 — a complete gap item whose prefix names no module in the roster (base rule
--                id/prefix-not-in-roster) and has no item_provenance row (provenance/missing);
--                it must still appear on the page (under "Unplaced items"), never be dropped.
--   2. VSC-005 — the required gap columns kind and category are NULL (rule V-G1).
--   3. VSC-004 — a closed item with no independent verifier verdict (rule V-G3).

INSERT INTO items (atm_id,type,status,severity,title,description,forensic_anchor,closure_criteria,
  created_by,assigned_to,current_location,body_md,created_at,last_modified,
  kind,category,disposition,plan_due,sweep_class,reopens_count)
VALUES ('ZZZ-001','Bug','Queued','medium','gap item filed under a prefix no module carries',
  'An item whose identifier prefix is not in the roster cannot be placed on any module section.',
  'scripts/zero-gap-class-example.sh:30','the item is re-filed under a roster prefix',
  'AI','agent-owner','Issues',
  '## ZZZ-001 — gap item filed under a prefix no module carries

**Status:** Queued
**Type:** Bug
**Severity:** medium
**Created-By:** AI
**Assigned-To:** agent-owner

An item whose identifier prefix is not in the roster cannot be placed on any module section.

',
  '2026-09-25 10:00:00','2026-09-25 10:00:00',
  'defect','docs-drift','open','2026-12-31','SC-example',0);
INSERT INTO doc_segments (document,seq,kind,atm_id) VALUES ('Issues',5,'item','ZZZ-001');
INSERT INTO item_history (atm_id,event_type,by,on_date,reason,evidence_path,created_at) VALUES
  ('ZZZ-001','Opened','AI','2026-09-25','zero-gap:opened sweep_class=SC-example','_tests/fixtures/zero-gap/registers/evidence/sweep-finding.json','2026-09-25 10:00:00');

UPDATE items SET kind = NULL, category = NULL WHERE atm_id = 'VSC-005';

DELETE FROM item_verdicts WHERE item_id = 'VSC-004' AND role = 'verifier';
