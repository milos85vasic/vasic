-- golden-bad/V-G3.sql — mutation of golden-good.sql that ONLY rule V-G3 may flag (feature 010, T010).
-- V-G3: a closed item with no independent verifier verdict (FR-018).
DELETE FROM item_verdicts WHERE item_id = 'VSC-004' AND role = 'verifier';
