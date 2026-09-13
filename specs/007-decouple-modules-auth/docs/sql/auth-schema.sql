-- Auth Schema for workshop and ai_interviewing modules
-- Shared across both modules; stored in PostgreSQL for user management
-- Each module also maintains its own auth.db (SQLite) for session persistence

-- Users table (workshop/auth.db + ai_interviewing/auth.db + PostgreSQL)
CREATE TABLE IF NOT EXISTS auth_user (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    username    TEXT    NOT NULL UNIQUE,
    password    TEXT    NOT NULL,  -- bcrypt hash, cost-12
    role        TEXT    NOT NULL DEFAULT 'user',  -- 'admin' | 'user'
    created_at  TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
    updated_at  TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);

-- Module permissions (workshop/auth.db + ai_interviewing/auth.db + PostgreSQL)
CREATE TABLE IF NOT EXISTS auth_module (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    name        TEXT    NOT NULL UNIQUE,  -- 'workshop', 'ai_interviewing'
    description TEXT
);

-- Permission rows (workshop/auth.db + ai_interviewing/auth.db + PostgreSQL)
CREATE TABLE IF NOT EXISTS auth_permission (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    module_id       INTEGER NOT NULL,
    resource        TEXT    NOT NULL,
    actions         TEXT    NOT NULL,  -- comma-separated: read,write,delete
    FOREIGN KEY (module_id) REFERENCES auth_module(id)
);

-- User-module-role mapping (workshop/auth.db + ai_interviewing/auth.db + PostgreSQL)
CREATE TABLE IF NOT EXISTS auth_user_module (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id         INTEGER NOT NULL,
    module_id       INTEGER NOT NULL,
    role            TEXT    NOT NULL,  -- 'admin' | 'user'
    granted_at      TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
    FOREIGN KEY (user_id) REFERENCES auth_user(id),
    FOREIGN KEY (module_id) REFERENCES auth_module(id),
    UNIQUE(user_id, module_id)
);

-- Sessions (workshop/auth.db + ai_interviewing/auth.db + PostgreSQL)
CREATE TABLE IF NOT EXISTS auth_session (
    token_hash      TEXT    PRIMARY KEY,  -- SHA-256 of JWT/session token
    user_id         INTEGER NOT NULL,
    module_id       INTEGER NOT NULL,
    expires_at      TEXT    NOT NULL,
    revoked_at      TEXT,
    created_at      TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
    FOREIGN KEY (user_id) REFERENCES auth_user(id),
    FOREIGN KEY (module_id) REFERENCES auth_module(id)
);

-- Seed data: milosvasic (admin) and rami (user)
INSERT OR IGNORE INTO auth_user (username, password, role) VALUES
    ('milosvasic', '$2a$12$PLACEHOLDER', 'admin'),
    ('rami',         '$2a$12$PLACEHOLDER', 'user');

-- Module definitions
INSERT OR IGNORE INTO auth_module (id, name) VALUES
    (1, 'workshop'),
    (2, 'ai_interviewing');

-- Workshop permissions: milosvasic = full access; rami = full access on workshop
INSERT OR IGNORE INTO auth_permission (module_id, resource, actions) VALUES
    (1, 'all', 'read,write,delete');

INSERT OR IGNORE INTO auth_user_module (user_id, module_id, role) VALUES
    (1, 1, 'admin'),  -- milosvasic on workshop = admin
    (2, 1, 'admin');  -- rami on workshop = admin

-- ai_interviewing permissions: milosvasic = full access; rami = restricted
INSERT OR IGNORE INTO auth_permission (module_id, resource, actions) VALUES
    (2, 'knowledge_base', 'read,write'),
    (2, 'progress',      'read,write'),
    (2, 'employer_data', 'read'),
    (2, 'github_analysis', 'read');

INSERT OR IGNORE INTO auth_user_module (user_id, module_id, role) VALUES
    (1, 2, 'admin'),   -- milosvasic on ai_interviewing = admin
    (2, 2, 'user');    -- rami on ai_interviewing = user (restricted)
