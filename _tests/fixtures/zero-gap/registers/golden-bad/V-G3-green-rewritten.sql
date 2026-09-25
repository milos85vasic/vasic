-- golden-bad/V-G3-green-rewritten.sql — mutation of golden-good.sql (feature 010, fix round 3). Expected rule(s): V-G3.
-- I3: the GREEN file was rewritten after closure (same check, same time, different bytes); the recorded sha256 no longer matches.
UPDATE item_history SET evidence_path='_tests/fixtures/zero-gap/registers/evidence/VSC-004-green-rewritten.json' WHERE atm_id='VSC-004' AND (reason LIKE 'zero-gap:green-evidence%' OR event_type='Fixed'); UPDATE test_diary SET evidence_path='_tests/fixtures/zero-gap/registers/evidence/VSC-004-green-rewritten.json' WHERE atm_id='VSC-004';
