-- golden-bad/V-G3-verifier-early.sql — mutation of golden-good.sql (feature 010, fix round 1). Expected rule(s): V-G3.
-- C1: the verifier's record predates the GREEN record it claims to confirm.
UPDATE item_verdicts SET evidence_path = '_tests/fixtures/zero-gap/registers/evidence/VSC-004-verifier-early.json' WHERE item_id = 'VSC-004' AND role = 'verifier'; UPDATE item_history SET reason = 'zero-gap:close fixer=agent-fixer-A check-author=agent-author-B verdict=_tests/fixtures/zero-gap/registers/evidence/VSC-004-verifier-early.json' WHERE atm_id = 'VSC-004' AND event_type = 'Fixed';
