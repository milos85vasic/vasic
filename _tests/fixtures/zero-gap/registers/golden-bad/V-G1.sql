-- golden-bad/V-G1.sql — mutation of golden-good.sql that ONLY rule V-G1 may flag (feature 010, T010).
-- V-G1: category outside the closed set (research D4).
UPDATE items SET category = 'misc' WHERE atm_id = 'VSC-001';
