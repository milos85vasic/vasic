-- golden-bad/V-G3-backdated-rows.sql — mutation of golden-good.sql (feature 010, fix round 4). Expected rule(s): V-G3.
-- F5: the closure rows are stamped 09:30 while the GREEN they cite was measured
-- at 11:00 and the verifier record at 11:30 — a row cannot cite evidence that
-- did not exist when the row was written. The zero-skew rule that the commands
-- apply at write time must also hold in the register itself.
UPDATE item_history SET created_at='2026-09-25 09:30:00'
 WHERE atm_id='VSC-004' AND (reason LIKE 'zero-gap:green-evidence%' OR event_type='Fixed');
