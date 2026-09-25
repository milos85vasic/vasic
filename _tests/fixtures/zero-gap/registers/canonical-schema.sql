-- canonical-schema.sql — the PRE-MIGRATION register schema used by every zero-gap
-- register fixture (feature 010, task T010).
--
-- Provenance: a schema-only dump (`.schema`, no rows) of a scratch COPY of
-- docs/workable_items.db, canonical schema_version 6, taken 2026-09-25. The tracked
-- database was never opened for writing. One line was removed: the dump's
-- `CREATE TABLE sqlite_sequence(...)`, an SQLite-internal table that cannot be created
-- by hand and is recreated automatically by the first AUTOINCREMENT insert.
-- The two umbrella extension tables (sub_projects, item_provenance) are included
-- because _tools/workable-items creates them on open.
--
-- Nothing here is a gap column: `gap migrate` adds those. A fixture built from this
-- file alone is therefore the "not yet migrated" register.
CREATE TABLE items (
    -- §11.4.54 ATM-NNN ticket identifier (monotonic, append-only, never
    -- renumbered, never reused). NOT a bare PRIMARY KEY: the SAME ticket id
    -- legitimately appears in BOTH trackers — a tombstone in Issues.md AND a
    -- closure row in Fixed.md (e.g. HXC-017). The identity is therefore
    -- (atm_id, current_location); see the composite PRIMARY KEY below.
    atm_id           TEXT NOT NULL,

    -- §11.4.16 Type closed-set
    type             TEXT NOT NULL CHECK (type IN ('Bug', 'Feature', 'Task')),

    -- §11.4.15 + §11.4.21 + §11.4.90 Status closed-set (8 values)
    status           TEXT NOT NULL CHECK (status IN (
                         'Queued', 'In progress', 'Ready for testing',
                         'In testing', 'Reopened', 'Operator-blocked',
                         'Fixed (→ Fixed.md)', 'Implemented (→ Fixed.md)',
                         'Completed (→ Fixed.md)', 'Obsolete (→ Fixed.md)'
                     )),

    -- Severity (informational only; not closed-set, but recommended)
    severity         TEXT,

    -- Heading line text (full H2 heading including code prefix per §11.4.54)
    title            TEXT NOT NULL,

    -- §11.4.91 description floor: ≥ 6 words OR ≥ 40 chars (enforced at insert)
    description      TEXT NOT NULL,

    -- Forensic anchor — verbatim user mandate or operator quote
    forensic_anchor  TEXT,

    -- Closure criteria (markdown body)
    closure_criteria TEXT,

    -- Composes-with cross-references — JSON array of §-letter or ATM-NNN refs
    composes_with    TEXT,                    -- JSON-encoded array

    -- Group-atomic track-assignment (docs/tracks/ASSIGNMENT_MECHANISM_DESIGN.md
    -- §3.1; §11.4.176/§11.4.119/§11.4.111 — v6). destination = the branch this
    -- item lands on ('main' | 'feature:<slug>'); logic_group = the single
    -- mutually-exclusive set the item belongs to. Referential integrity
    -- (logic_group -> logic_groups.group_id) is enforced at the Go layer by
    -- `validate-groups` (a later phase) — no DB-level FOREIGN KEY, consistent
    -- with the obsolete_details / operator_block_details / firebase_metadata
    -- precedent of Go-side-validated cross-references rather than SQL FK. Both
    -- columns are NULL until classified (one-time seeding, a later phase); NULL
    -- means "not yet classified", never "no group" — every item whose status is
    -- open MUST carry non-null values before it is dispatchable (a later
    -- phase's totality invariant). Additive + nullable: existing rows are
    -- unaffected (migrateColumns ADDs them on a pre-v6 DB).
    destination      TEXT,
    logic_group      TEXT,

    -- Participant attribution (§11.4.104 / Herald PARTICIPANT_ATTRIBUTION.md).
    -- created_by  = canonical handle that opened the item; assigned_to = canonical
    -- handle the item is assigned to. Canonical handle closed set: "Claude" (the
    -- system agent; never tagged), or a subscriber's @username. Empty '' = legacy
    -- item with no attribution recorded (back-compat default).
    created_by       TEXT NOT NULL DEFAULT '',
    assigned_to      TEXT NOT NULL DEFAULT '',

    -- Current document location for atomic-move discipline per §11.4.19
    current_location TEXT NOT NULL CHECK (current_location IN ('Issues', 'Fixed')) DEFAULT 'Issues',

    -- §11.4.93 byte-identical-round-trip mechanism: the verbatim raw Markdown
    -- block (Issues H2 item) or raw table row (Fixed) this item was parsed
    -- from. db→md regeneration concatenates these (interleaved with
    -- doc_segments raw prose) to reproduce the source byte-for-byte.
    body_md          TEXT,

    -- Representation discriminator (GAP A). The SAME ticket id can be present in
    -- the SAME tracker under TWO surface forms: a pipe-table closure ROW
    -- ('table') AND a detailed H2 SECTION ('section') — e.g. HXC-044 in Fixed.md.
    -- (atm_id, current_location) alone collided; the identity is therefore
    -- (atm_id, current_location, representation). Default 'section': CRUD-created
    -- items + every H2-form item are 'section'; only legacy pipe-table rows are
    -- 'table'. A DB materialised before this column carries the old 2-tuple PK
    -- and is rebuilt by migrateRepresentationColumn (lossless, idempotent).
    representation   TEXT NOT NULL DEFAULT 'section'
                     CHECK (representation IN ('section', 'table')),

    -- Per-item closure metadata (GAP B). Parsed FROM a Fixed.md pipe-table row
    -- (`| Closure | Title | Type | Status | Round | Commit(s) | Evidence |`) so
    -- db→md can SYNTHESIZE a pipe row from DB fields (not only replay raw
    -- body_md). NULL when the item has no pipe-table representation. Additive +
    -- nullable: existing rows are unaffected (migrateColumns ADDs them).
    closure_date     TEXT,
    round            TEXT,
    commit_ref       TEXT,

    -- §11.4.148/§11.4.149 sub-task hierarchy. A testing session against a parent
    -- item is itself a first-class workable item distinguished by a non-NULL
    -- parent_atm_id (the parent's id). session_ref is the human session label.
    -- NULL parent_atm_id = a top-level item. Back-compat: rows materialised under
    -- an older schema have these columns ADDed by migrateColumns (NULL = top-level).
    parent_atm_id    TEXT,
    session_ref      TEXT,

    -- Timestamps
    created_at       TEXT NOT NULL DEFAULT (datetime('now')),
    last_modified    TEXT NOT NULL DEFAULT (datetime('now')),

    -- Composite identity: a ticket may be present in both trackers at once AND,
    -- within ONE tracker, under both a pipe-table row + an H2 section (GAP A).
    PRIMARY KEY (atm_id, current_location, representation)
);
CREATE TABLE item_history (
    id               INTEGER PRIMARY KEY AUTOINCREMENT,
    atm_id           TEXT NOT NULL,

    -- Event type — closed-set
    event_type       TEXT NOT NULL CHECK (event_type IN (
                         'Opened', 'Updated', 'Reopened',
                         'Fixed', 'Implemented', 'Completed', 'Obsolete'
                     )),

    -- §11.4.34 source attribution
    by               TEXT CHECK (by IN ('AI', 'User', NULL)),

    -- ISO date
    on_date          TEXT NOT NULL,

    -- §11.4.34 / §11.4.90 closed-set Reason vocabulary
    reason           TEXT,

    -- Captured-evidence per §11.4.5 — path to artefact under qa-results/ etc.
    evidence_path    TEXT,

    created_at       TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX idx_item_history_atm_id ON item_history(atm_id);
CREATE INDEX idx_item_history_event_type ON item_history(event_type);
CREATE TABLE obsolete_details (
    atm_id                  TEXT PRIMARY KEY,

    -- ISO date of obsolescence determination
    since                   TEXT NOT NULL,

    -- §11.4.90 closed-set Reason vocabulary
    -- 'not-reproducible' = a reported defect that does NOT reproduce on the
    -- canonical tree/baseline (environment / isolated-worktree artifact), not a
    -- real product defect; triple_check_evidence captures the non-reproduction.
    reason                  TEXT NOT NULL CHECK (reason IN (
                                'superseded-by-design-change',
                                'superseded-by-later-mandate',
                                'feature-removed',
                                'duplicate-of',
                                'unsupported-topology',
                                'not-reproducible'
                            )),

    -- §-letter / ATM-NNN reference of the work that obsoleted this item
    superseding_item        TEXT NOT NULL,

    -- §11.4.90 triple-check: positive captured evidence (NOT bare assertion)
    triple_check_evidence   TEXT NOT NULL
);
CREATE TABLE operator_block_details (
    atm_id                       TEXT PRIMARY KEY,
    what                         TEXT NOT NULL,
    why_exhausted_alternatives   TEXT NOT NULL,
    unblock_condition            TEXT NOT NULL,
    who                          TEXT
);
CREATE TABLE firebase_metadata (
    atm_id                 TEXT PRIMARY KEY,
    firebase_issue_ids     TEXT,           -- JSON array
    firebase_url           TEXT,
    stacktrace_cluster_hash TEXT,
    kpi                    TEXT,           -- Performance KPI ref
    funnel                 TEXT            -- Analytics funnel ref
);
CREATE TABLE logic_groups (
    -- Stable id, lowercase snake/kebab (§11.4.29), e.g. 'mistiq-vader-rebrand',
    -- 'audio-5.1-multichannel', 'video-bugs', 'urgent-main', 'unassigned-triage'.
    group_id     TEXT PRIMARY KEY,

    -- Human title (>= 6 words / §11.4.91 clarity floor).
    title        TEXT NOT NULL,

    -- The single branch every member of this group lands on: 'main' |
    -- 'feature:<slug>'. A group is homogeneous in destination (design §3.1
    -- destination-agreement invariant, Go-validated by a later phase).
    destination  TEXT NOT NULL,

    -- Lower = sooner. Derived from ROADMAP ordering; 'urgent-main' = 0.
    priority     INTEGER NOT NULL,

    -- Group lifecycle state machine (ASSIGNMENT_MECHANISM_DESIGN.md §4).
    -- 'open': >=1 open member, unowned. 'in-progress': exactly one track owns
    -- it (multitrack_claim.sh). 'group-complete': every member terminal +
    -- destination merge confirmed; the owning track has freed.
    state        TEXT NOT NULL DEFAULT 'open'
                 CHECK (state IN ('open', 'in-progress', 'group-complete')),

    -- Plain-language membership definition for audit — NOT a matcher (the
    -- defect this mechanism replaces was substring-matching free text; this
    -- field is documentation only, never consulted by the assigner).
    scope_note   TEXT,

    -- Pointer to the ROADMAP / priority-doc line that set this group's
    -- priority (audit trail for §11.4.66 operator-confirmed priorities).
    roadmap_ref  TEXT
);
CREATE INDEX idx_logic_groups_destination ON logic_groups(destination);
CREATE INDEX idx_logic_groups_state ON logic_groups(state);
CREATE TABLE doc_segments (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    document    TEXT NOT NULL CHECK (document IN ('Issues', 'Fixed')),
    seq         INTEGER NOT NULL,
    kind        TEXT NOT NULL CHECK (kind IN ('item', 'raw')),
    atm_id      TEXT,          -- set when kind='item' (FK-ish to items.atm_id)
    -- Which item REPRESENTATION this segment points to (GAP A): a 'table' segment
    -- references the pipe-table row, a 'section' segment the H2 block, so the
    -- renderer disambiguates when the SAME atm_id has both in one document.
    -- Default 'section' (raw segments + legacy DBs); raw segments ignore it.
    representation TEXT NOT NULL DEFAULT 'section',
    raw         TEXT,          -- set when kind='raw'
    UNIQUE(document, seq)
);
CREATE INDEX idx_doc_segments_document ON doc_segments(document);
CREATE TABLE test_diary (
    entry_id       INTEGER PRIMARY KEY AUTOINCREMENT,
    atm_id         TEXT NOT NULL,
    date_time      TEXT NOT NULL,            -- ISO-8601 UTC
    tested_by      TEXT NOT NULL CHECK (tested_by IN ('User', 'Operator', 'AI-agent', 'HelixQA')),
    result         TEXT NOT NULL CHECK (result IN ('PASS', 'FAIL', 'SKIP')),
    result_detail  TEXT,
    observations   TEXT NOT NULL,
    action_taken   TEXT NOT NULL,
    status_changed INTEGER NOT NULL DEFAULT 0,
    status_from    TEXT,
    status_to      TEXT,
    evidence_path  TEXT,                     -- §11.4.69 captured-evidence path
    feature_class  TEXT,                     -- §11.4.69 sink-side feature class
    created_at     TEXT NOT NULL DEFAULT (datetime('now')),
    -- §11.4.149: a PASS run MUST cite captured evidence.
    CHECK (result <> 'PASS' OR (evidence_path IS NOT NULL AND evidence_path <> ''))
);
CREATE INDEX idx_test_diary_atm_id ON test_diary(atm_id);
CREATE VIEW test_diary_summary AS
SELECT
    d.atm_id                                                   AS atm_id,
    COUNT(*)                                                   AS total_runs,
    SUM(CASE WHEN d.result = 'PASS' THEN 1 ELSE 0 END)         AS pass_runs,
    SUM(CASE WHEN d.result = 'FAIL' THEN 1 ELSE 0 END)         AS fail_runs,
    SUM(CASE WHEN d.result = 'SKIP' THEN 1 ELSE 0 END)         AS skip_runs,
    MAX(d.date_time)                                           AS last_run,
    (SELECT l.result FROM test_diary l WHERE l.atm_id = d.atm_id
        ORDER BY l.date_time DESC, l.entry_id DESC LIMIT 1)    AS last_result,
    SUM(d.status_changed)                                      AS status_changes,
    (SELECT GROUP_CONCAT(t) FROM (SELECT DISTINCT tested_by AS t
        FROM test_diary WHERE atm_id = d.atm_id ORDER BY t))   AS testers,
    (SELECT GROUP_CONCAT(c) FROM (SELECT DISTINCT feature_class AS c
        FROM test_diary WHERE atm_id = d.atm_id AND feature_class IS NOT NULL
        AND feature_class <> '' ORDER BY c))                   AS feature_classes
FROM test_diary d
GROUP BY d.atm_id
/* test_diary_summary(atm_id,total_runs,pass_runs,fail_runs,skip_runs,last_run,last_result,status_changes,testers,feature_classes) */;
CREATE TABLE meta (
    key                  TEXT PRIMARY KEY,
    value                TEXT NOT NULL,
    last_modified        TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX idx_items_parent ON items(parent_atm_id);
CREATE INDEX idx_items_logic_group ON items(logic_group);
CREATE INDEX idx_items_destination ON items(destination);
CREATE INDEX idx_items_status ON items(status);
CREATE INDEX idx_items_type ON items(type);
CREATE INDEX idx_items_status_type ON items(status, type);
CREATE INDEX idx_items_current_location ON items(current_location);
CREATE INDEX idx_items_created_by ON items(created_by);
CREATE INDEX idx_items_assigned_to ON items(assigned_to);
CREATE TABLE sub_projects (
    prefix    TEXT PRIMARY KEY CHECK (length(prefix) = 3),
    path      TEXT NOT NULL UNIQUE,
    class     TEXT NOT NULL CHECK (class IN ('parent','owned','governance-source','third-party')),
    ratified  TEXT NOT NULL CHECK (ratified IN ('operator','proposed')),
    url       TEXT NOT NULL DEFAULT '',
    note      TEXT NOT NULL DEFAULT '',
    synced_at TEXT NOT NULL
);
CREATE TABLE item_provenance (
    atm_id         TEXT PRIMARY KEY,
    source_kind    TEXT NOT NULL CHECK (source_kind IN ('operator-decision','spec-task','session-work')),
    source_path    TEXT NOT NULL,
    source_locator TEXT NOT NULL,
    evidence_class TEXT NOT NULL CHECK (evidence_class IN (
                       'document-assertion',   -- the source document states the outcome; not re-run here
                       'checkbox-state',       -- a tracked task list records the completion mark
                       'undetermined'          -- the source does not state an outcome
                   )),
    status_note    TEXT NOT NULL DEFAULT ''
);
INSERT INTO meta(key, value, last_modified) VALUES
    ('schema_version', '6', '2026-09-08 20:38:53'),
    ('last_sync_direction', 'none', '2026-09-08 20:38:53'),
    ('last_sync_timestamp', '', '2026-09-08 20:38:53'),
    ('integrity_hash', '', '2026-09-08 20:38:53');
