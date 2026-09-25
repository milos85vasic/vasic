-- golden-bad/V-G3-diary-unrelated.sql — mutation of golden-good.sql (feature 010, fix round 3). Expected rule(s): V-G3.
-- M3: the diary PASS row cites a file that is not the GREEN it certifies.
UPDATE test_diary SET evidence_path='_tests/fixtures/zero-gap/registers/evidence/VSC-004-research.md' WHERE atm_id='VSC-004';
