-- golden-bad/V-G2.sql — mutation of golden-good.sql that ONLY rule V-G2 may flag (feature 010, T010).
-- V-G2: a classified item whose recheck date has elapsed at --as-of 2026-09-25.
UPDATE items SET classification_recheck = '2026-09-01' WHERE atm_id = 'VSC-002';
