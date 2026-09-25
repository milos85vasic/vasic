-- golden-bad/V-G3-diary-before-green.sql — mutation of golden-good.sql (feature 010, fix round 3). Expected rule(s): V-G3.
-- M3: the diary PASS row is dated before the GREEN it certifies.
UPDATE test_diary SET date_time='2026-09-25T10:00:00Z' WHERE atm_id='VSC-004';
