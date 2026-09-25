-- golden-bad/V-G3-research-dir.sql — mutation of golden-good.sql (feature 010, fix round 1). Expected rule(s): V-G3.
-- C1: research_ref names a directory, not a regular file.
UPDATE items SET research_ref = '_tests/fixtures/zero-gap/registers/evidence' WHERE atm_id = 'VSC-004';
