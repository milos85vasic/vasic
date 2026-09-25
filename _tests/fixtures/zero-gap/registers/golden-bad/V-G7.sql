-- golden-bad/V-G7.sql — mutation of golden-good.sql that ONLY rule V-G7 may flag (feature 010, T010).
-- V-G7: the forbidden 'accepted-as-is' disposition (clarification 1, FR-006).
UPDATE items SET disposition = 'accepted-as-is' WHERE atm_id = 'VSC-001';
