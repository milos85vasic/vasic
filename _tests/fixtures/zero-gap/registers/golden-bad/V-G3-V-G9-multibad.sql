-- golden-bad/V-G3-V-G9-multibad.sql — mutation of golden-good.sql (feature 010, fix round 1). Expected rule(s): V-G3, V-G9.
-- I1: the GREEN record has four malformed hex fields; the verdict text must be identical on every run.
UPDATE item_history SET evidence_path = '_tests/fixtures/zero-gap/registers/evidence/VSC-004-green-multibad.json' WHERE atm_id = 'VSC-004' AND reason LIKE 'zero-gap:green-evidence%';
