-- golden-bad/V-G3-research-absolute.sql — mutation of golden-good.sql (feature 010, fix round 3). Expected rule(s): V-G3.
-- M2: research_ref is an absolute path to an existing file outside the repository root.
UPDATE items SET research_ref='/etc/passwd' WHERE atm_id='VSC-004';
