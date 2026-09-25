-- legacy-register.sql — two ordinary pre-feature-010 items, shaped like the rows the
-- tracked register held on 2026-09-25 (type Task; one Completed in Fixed, one Queued in
-- Issues). Applied to canonical-schema.sql WITHOUT migration, it is the "existing
-- register" that `gap migrate` must extend additively: after the migration every
-- column value below is unchanged, reopens_count reads 0, every other gap column is
-- NULL, and the canonical validator still accepts the database (feature 010, T006).
INSERT INTO items (atm_id,type,status,severity,title,description,created_by,current_location,body_md,created_at,last_modified)
VALUES
('VSC-001','Task','Completed (→ Fixed.md)',NULL,'legacy completed task used as a migration control',
 'A completed task recorded before the zero-gap columns existed; its values must survive the migration.',
 'AI','Fixed',
 '## VSC-001 — legacy completed task used as a migration control

**Status:** Completed (→ Fixed.md)
**Type:** Task
**Created-By:** AI

A completed task recorded before the zero-gap columns existed; its values must survive the migration.

','2026-09-08 20:38:53','2026-09-08 20:38:53'),
('VSC-002','Task','Queued',NULL,'legacy queued task used as a migration control',
 'A queued task recorded before the zero-gap columns existed; it is not a gap item after the migration.',
 'AI','Issues',
 '## VSC-002 — legacy queued task used as a migration control

**Status:** Queued
**Type:** Task
**Created-By:** AI

A queued task recorded before the zero-gap columns existed; it is not a gap item after the migration.

','2026-09-08 20:38:53','2026-09-08 20:38:53');
INSERT INTO doc_segments (document,seq,kind,atm_id) VALUES ('Fixed',0,'item','VSC-001'), ('Issues',0,'item','VSC-002');
INSERT INTO item_provenance (atm_id,source_kind,source_path,source_locator,evidence_class,status_note) VALUES
 ('VSC-001','spec-task','_tests/fixtures/zero-gap/registers/evidence/legacy-completion.md','legacy fixture','checkbox-state',''),
 ('VSC-002','spec-task','_tests/fixtures/zero-gap/registers/evidence/legacy-completion.md','legacy fixture','checkbox-state','');
INSERT INTO item_history (atm_id,event_type,by,on_date,reason,evidence_path,created_at) VALUES
 ('VSC-001','Completed','AI','2026-09-08','backfilled from spec-task at legacy fixture','_tests/fixtures/zero-gap/registers/evidence/legacy-completion.md','2026-09-08 20:38:53'),
 ('VSC-002','Opened','AI','2026-09-08','backfilled from spec-task at legacy fixture','_tests/fixtures/zero-gap/registers/evidence/legacy-completion.md','2026-09-08 20:38:53');
