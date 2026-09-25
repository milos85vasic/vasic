-- golden-bad/V-G9.sql — mutation of golden-good.sql that ONLY rule V-G9 may flag (feature 010, T010).
-- V-G9: a closed item whose LATEST evidence record now has outcome 1.
INSERT INTO item_history (atm_id,event_type,by,on_date,reason,evidence_path,created_at) VALUES ('VSC-004','Updated','AI','2026-09-26','zero-gap:recheck-evidence check=CHK-vsc-004','_tests/fixtures/zero-gap/registers/evidence/VSC-004-recheck-fail.json','2026-09-26 06:00:00');
