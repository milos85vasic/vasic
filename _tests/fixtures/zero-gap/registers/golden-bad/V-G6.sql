-- golden-bad/V-G6.sql — mutation of golden-good.sql that ONLY rule V-G6 may flag (feature 010, T010).
-- V-G6: APPLY ON TOP OF frozen-cycle.sql — VSC-005 silently leaves the frozen cycle (FR-026).
UPDATE items SET cycle = NULL WHERE atm_id = 'VSC-005';
