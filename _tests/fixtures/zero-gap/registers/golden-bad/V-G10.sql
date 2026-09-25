-- golden-bad/V-G10.sql — mutation of golden-good.sql that ONLY rule V-G10 may flag (feature 010, T010).
-- V-G10: an open item with no dated plan (FR-006).
UPDATE items SET plan_due = NULL WHERE atm_id = 'VSC-001';
