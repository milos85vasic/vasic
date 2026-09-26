CREATE TABLE items (atm_id TEXT NOT NULL, status TEXT NOT NULL, title TEXT NOT NULL, description TEXT NOT NULL);
CREATE TABLE operator_block_details (atm_id TEXT PRIMARY KEY, what TEXT NOT NULL, why_exhausted_alternatives TEXT NOT NULL, unblock_condition TEXT NOT NULL, who TEXT);
INSERT INTO items VALUES ('SYN-001','Operator-blocked','signing key rotation waits for the operator to provision a hardware token','blocked until the token exists');
INSERT INTO items VALUES ('SYN-002','Queued','known limitation: search latency is 800 ms at the 95th percentile','improve the query planner so the 95th percentile drops');
INSERT INTO items VALUES ('SYN-003','Queued','add a dashboard tile for build times','a plain new feature request with nothing else stated');
INSERT INTO items VALUES ('SYN-004','Completed (→ Fixed.md)','fixed limitation of the importer','out of scope because it is completed');
INSERT INTO operator_block_details VALUES ('SYN-001','the token','no alternative','operator provisions the token','operator');
