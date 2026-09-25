-- golden-bad/V-G12.sql — mutation of golden-good.sql that ONLY rule V-G12 may flag (feature 010, T010).
-- V-G12: an orphan item_verdicts row naming no item.
INSERT INTO item_verdicts (item_id,role,actor,actor_kind,on_date,outcome,evidence_path) VALUES ('VSC-999','verifier','agent-verifier-C','agent','2026-09-25',0,'_tests/fixtures/zero-gap/registers/evidence/VSC-004-verifier.json');
