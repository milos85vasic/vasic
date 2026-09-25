-- frozen-cycle.sql — applied on top of golden-good.sql (feature 010, T010). The tracked twin of the meta
-- record below is frozen-cycle.freeze.json (installed at docs/zero-gap/cycles/2026-C1/freeze.json in a test root).
-- Puts all six items in programme cycle 2026-C1 and records that cycle's freeze in the
-- DB `meta` table under key `zero_gap_freeze:<cycle>`, exactly as `gap freeze` writes it
-- (keys sorted; members listed in atm_id order; members_sha256 = sha256 of the members
-- joined by "\n" with a trailing "\n"). After this, V-G6 must reject any change to the
-- set of items carrying cycle = 2026-C1.
UPDATE items SET cycle = '2026-C1';
INSERT INTO meta (key, value, last_modified) VALUES ('zero_gap_freeze:2026-C1',
'{"chain_head":null,"cycle":"2026-C1","entry_count":null,"frozen_at":"2026-09-25","item_count":6,"members":["VSC-001","VSC-002","VSC-003","VSC-004","VSC-005","VSC-006"],"members_sha256":"ee158cdd55f10c1a7592abaf6180e72691428cde3dad9f80137f95d9c7b8466f","register_sha256":"129bf3a4cc748d32b43b66983654a561b1f7fd00bea783735ce7c2a528301741","sweep_manifest_sha256":null}',
'2026-09-25 12:00:00');
