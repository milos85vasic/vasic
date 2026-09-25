-- golden-bad/V-G5.sql — mutation of golden-good.sql that ONLY rule V-G5 may flag (feature 010, T010).
-- V-G5: a recurrence chain that cycles VSC-001 -> VSC-006 -> VSC-001 (FR-008).
UPDATE items SET recurrence_of = 'VSC-006' WHERE atm_id = 'VSC-001';
