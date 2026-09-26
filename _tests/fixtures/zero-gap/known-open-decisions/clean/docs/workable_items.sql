CREATE TABLE items (atm_id TEXT NOT NULL, status TEXT NOT NULL, title TEXT NOT NULL, description TEXT NOT NULL);
CREATE TABLE operator_block_details (atm_id TEXT PRIMARY KEY, what TEXT NOT NULL, why_exhausted_alternatives TEXT NOT NULL, unblock_condition TEXT NOT NULL, who TEXT);
INSERT INTO items VALUES ('DEM-002','Operator-blocked','A blocked item with full detail','Detail row lists options and costs for this item');
INSERT INTO items VALUES ('DEM-003','Queued','A queued item','Not operator blocked so never a decision');
INSERT INTO operator_block_details VALUES ('DEM-002','need a key','tried the local key','Option A supply the key, cost is one minute; Option B skip the feature, cost is a missing report','operator');
