-- golden-bad/V-G11.sql — mutation of golden-good.sql that ONLY rule V-G11 may flag (feature 010, T010).
-- V-G11: an Operator-blocked item whose unblock option carries no cost (FR-009).
UPDATE operator_block_details SET unblock_condition = '- ask the operator what to do' WHERE atm_id = 'VSC-003';
