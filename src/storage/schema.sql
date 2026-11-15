-- Mimir Rust schema v1 (9 tables). Mirrors the Drift mimir.db Phase-1 slice.
CREATE TABLE IF NOT EXISTS characters (
    character_id INTEGER PRIMARY KEY,
    name TEXT NOT NULL DEFAULT '',
    corporation_id INTEGER NOT NULL DEFAULT 0,
    alliance_id INTEGER,
    is_active INTEGER NOT NULL DEFAULT 0,
    updated_at TEXT NOT NULL DEFAULT ''
);
CREATE TABLE IF NOT EXISTS skill_queue (
    character_id INTEGER NOT NULL,
    queue_position INTEGER NOT NULL,
    skill_id INTEGER NOT NULL,
    finished_level INTEGER NOT NULL DEFAULT 0,
    start_date TEXT,
    finish_date TEXT,
    PRIMARY KEY (character_id, queue_position)
);
CREATE TABLE IF NOT EXISTS character_skills (
    character_id INTEGER NOT NULL,
    skill_id INTEGER NOT NULL,
    active_skill_level INTEGER NOT NULL DEFAULT 0,
    trained_skill_level INTEGER NOT NULL DEFAULT 0,
    skillpoints_in_skill INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (character_id, skill_id)
);
CREATE TABLE IF NOT EXISTS wallet_balances (
    character_id INTEGER PRIMARY KEY,
    balance REAL NOT NULL DEFAULT 0,
    updated_at TEXT NOT NULL DEFAULT ''
);
CREATE TABLE IF NOT EXISTS wallet_journal (
    id INTEGER PRIMARY KEY,
    character_id INTEGER NOT NULL DEFAULT 0,
    amount REAL NOT NULL DEFAULT 0,
    balance REAL NOT NULL DEFAULT 0,
    date TEXT NOT NULL DEFAULT '',
    description TEXT NOT NULL DEFAULT '',
    ref_type TEXT NOT NULL DEFAULT '',
    first_party_id INTEGER,
    second_party_id INTEGER
);
CREATE TABLE IF NOT EXISTS wallet_transactions (
    transaction_id INTEGER PRIMARY KEY,
    character_id INTEGER NOT NULL DEFAULT 0,
    journal_ref_id INTEGER NOT NULL DEFAULT 0,
    date TEXT NOT NULL DEFAULT '',
    type_id INTEGER NOT NULL DEFAULT 0,
    quantity INTEGER NOT NULL DEFAULT 0,
    unit_price REAL NOT NULL DEFAULT 0,
    is_buy INTEGER NOT NULL DEFAULT 0,
    is_personal INTEGER NOT NULL DEFAULT 0,
    client_id INTEGER NOT NULL DEFAULT 0,
    location_id INTEGER NOT NULL DEFAULT 0
);
CREATE TABLE IF NOT EXISTS loyalty_points (
    character_id INTEGER NOT NULL,
    corporation_id INTEGER NOT NULL,
    loyalty_points INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (character_id, corporation_id)
);
CREATE TABLE IF NOT EXISTS universe_names (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL DEFAULT '',
    category TEXT NOT NULL DEFAULT ''
);
CREATE TABLE IF NOT EXISTS app_settings (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL DEFAULT ''
);
