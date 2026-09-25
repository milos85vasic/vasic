-- golden-bad/V-G4.sql — mutation of golden-good.sql that ONLY rule V-G4 may flag (feature 010, T010).
-- V-G4: an improvement item whose measurable target is blank (FR-025).
UPDATE items SET measurable_target = '   ' WHERE atm_id = 'VSC-005';
