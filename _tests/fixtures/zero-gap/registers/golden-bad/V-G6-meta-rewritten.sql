-- golden-bad/V-G6-meta-rewritten.sql — APPLY ON TOP OF frozen-cycle.sql (feature 010, fix round 1). Expected rule: V-G6.
-- I3: VSC-005 leaves the frozen cycle AND the DB meta freeze record is rewritten CONSISTENTLY (members, digest, count),
-- so only the tracked docs/zero-gap/cycles/2026-C1/freeze.json (fixture: frozen-cycle.freeze.json) still shows 6 members.
UPDATE items SET cycle = NULL WHERE atm_id = 'VSC-005';
UPDATE meta SET value = '{"chain_head":null,"cycle":"2026-C1","entry_count":null,"frozen_at":"2026-09-25","item_count":5,"members":["VSC-001","VSC-002","VSC-003","VSC-004","VSC-006"],"members_sha256":"c65acd68e492677354ef00fd32d2df4249acaaa57b0c1a8703825daf2bb26b85","register_sha256":"129bf3a4cc748d32b43b66983654a561b1f7fd00bea783735ce7c2a528301741","sweep_manifest_sha256":null}' WHERE key = 'zero_gap_freeze:2026-C1';
