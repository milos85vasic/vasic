-- golden-bad/V-G1-reopen-bad.sql — mutation of golden-good.sql (feature 010, fix round 3). Expected rule(s): V-G1.
-- M1: a Reopened row inserted by direct SQL with evidence that does not resolve and a reason outside the §11.4.34 set.
INSERT INTO item_history (atm_id,event_type,by,on_date,reason,evidence_path,created_at) VALUES ('VSC-001','Reopened','AI','2026-09-25','because I said so','no/such/evidence.json','2026-09-25 13:00:00');
