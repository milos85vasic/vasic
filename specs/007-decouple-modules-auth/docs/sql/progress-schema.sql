-- Progress Tracking Schema for workshop and ai_interviewing modules
-- Keys on derived auth.UserProgressKey(userID) = "auth-user:<id>"
-- Ensures per-account isolation and relogin stability

-- Workshop progress: stored as atomic-write JSON files (survive re-index)
-- ai_interviewing progress: stored in SQLite curriculum.db keyed by session string
-- Both use the derived key bridge for account-level isolation

-- Progress records (workshop internal/api/progress.go + ai_interviewing api.go)
CREATE TABLE IF NOT EXISTS progress_record (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    user_key        TEXT    NOT NULL,  -- "auth-user:<id>" derived from auth.UserProgressKey()
    area_id         TEXT    NOT NULL,
    lesson_id       TEXT,
    item_type       TEXT    NOT NULL,  -- 'lesson' | 'test' | 'exercise' | 'assessment'
    item_id         TEXT    NOT NULL,
    completed       BOOLEAN NOT NULL DEFAULT 0,
    score           INTEGER CHECK (score >= 0 AND score <= 100),
    started_at      TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
    completed_at    TEXT,
    FOREIGN KEY (user_key) REFERENCES auth_session(token_hash)
);

-- Session tracking (workshop pkg/learning/SessionStore + ai_interviewing internal/api)
CREATE TABLE IF NOT EXISTS progress_session (
    session_id      TEXT    PRIMARY KEY,  -- opaque client-chosen X-Session header
    user_key        TEXT    NOT NULL,  -- derived: "auth-user:<id>"
    module_id       INTEGER NOT NULL,
    created_at      TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
    expires_at      TEXT    NOT NULL,
    FOREIGN KEY (module_id) REFERENCES auth_module(id)
);

-- Progress summary view (for /api/progress/summary endpoint)
CREATE VIEW IF NOT EXISTS progress_summary AS
    SELECT
        user_key,
        module_id,
        COUNT(*)                                              AS total_items,
        SUM(CASE WHEN completed THEN 1 ELSE 0 END)            AS completed_items,
        AVG(CASE WHEN score IS NOT NULL THEN score END)       AS avg_score,
        MAX(completed_at)                                     AS last_activity
    FROM progress_record
    GROUP BY user_key, module_id;

-- Indexes for query performance
CREATE INDEX IF NOT EXISTS idx_progress_user_key    ON progress_record(user_key);
CREATE INDEX IF NOT EXISTS idx_progress_area        ON progress_record(user_key, area_id);
CREATE INDEX IF NOT EXISTS idx_progress_lesson      ON progress_record(user_key, lesson_id);
CREATE INDEX IF NOT EXISTS idx_progress_completed   ON progress_record(user_key, completed);
CREATE INDEX IF NOT EXISTS idx_progress_session_mod ON progress_session(module_id);

-- Example: rami posting progress (workshop)
-- INSERT INTO progress_record (user_key, area_id, lesson_id, item_type, item_id, completed, score)
-- VALUES ('auth-user:2', 'intro', 'lesson1', 'lesson', '1', 1, NULL);
-- Resulting key: "auth-user:2" — deterministic, survives restarts and relogin.

-- Per-account isolation proof: Two accounts posting the same item keep separate summaries.
-- Test: TestProgressIsPerAccount (ai_interviewing) proves this.
