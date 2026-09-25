-- golden-bad/V-G3-reviewer-dir.sql — mutation of golden-good.sql (feature 010, fix round 1). Expected rule(s): V-G3.
-- C1: the reviewer's evidence path is a directory, not a regular file.
UPDATE item_verdicts SET evidence_path = '_tests/fixtures/zero-gap/registers/evidence' WHERE item_id = 'VSC-004' AND role = 'reviewer';
