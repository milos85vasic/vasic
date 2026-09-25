-- golden-bad/V-G3-V-G9-reclose-stale.sql — mutation of golden-good.sql (feature 010, fix round 1). Expected rule(s): V-G3, V-G9.
-- C2: VSC-004 was reopened on a failing record (2026-09-26T06:00Z) and then re-closed on its ORIGINAL RED/GREEN (GREEN 2026-09-25T11:00Z) and its old verdict rows.
INSERT INTO item_history (atm_id,event_type,by,on_date,reason,evidence_path,created_at) VALUES
 ('VSC-004','Reopened','AI','2026-09-26','captured-evidence-contradicts','_tests/fixtures/zero-gap/registers/evidence/VSC-004-recheck-fail.json','2026-09-26 06:30:00'),
 ('VSC-004','Updated','AI','2026-09-26','zero-gap:red-evidence check=CHK-vsc-004','_tests/fixtures/zero-gap/registers/evidence/VSC-004-red.json','2026-09-26 07:00:00'),
 ('VSC-004','Updated','AI','2026-09-26','zero-gap:green-evidence check=CHK-vsc-004','_tests/fixtures/zero-gap/registers/evidence/VSC-004-green.json','2026-09-26 07:00:00'),
 ('VSC-004','Fixed','AI','2026-09-26','zero-gap:close fixer=agent-fixer-A check-author=agent-author-B verdict=_tests/fixtures/zero-gap/registers/evidence/VSC-004-verifier.json','_tests/fixtures/zero-gap/registers/evidence/VSC-004-green.json','2026-09-26 07:00:00');
