-- Mimir Rust schema v1. Mirrors the Drift mimir.db Phase-1 slice.
-- The first nine tables are the scaffold contract (F4 tests count them).
-- esi_cache and token_meta are F2 additions; token_meta never holds token
-- values, only non-secret metadata (the tokens themselves live in the F1
-- keyring / 0600-file store).
-- v2 adds skill_plans and skill_plan_entries (docs/skill-plans-design.md
-- section 5); v1 DDL above is unchanged.
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
    id INTEGER NOT NULL,
    character_id INTEGER NOT NULL DEFAULT 0,
    amount REAL NOT NULL DEFAULT 0,
    balance REAL NOT NULL DEFAULT 0,
    date TEXT NOT NULL DEFAULT '',
    description TEXT NOT NULL DEFAULT '',
    ref_type TEXT NOT NULL DEFAULT '',
    first_party_id INTEGER,
    second_party_id INTEGER,
    PRIMARY KEY (character_id, id)
);
CREATE TABLE IF NOT EXISTS wallet_transactions (
    transaction_id INTEGER NOT NULL,
    character_id INTEGER NOT NULL DEFAULT 0,
    journal_ref_id INTEGER NOT NULL DEFAULT 0,
    date TEXT NOT NULL DEFAULT '',
    type_id INTEGER NOT NULL DEFAULT 0,
    quantity INTEGER NOT NULL DEFAULT 0,
    unit_price REAL NOT NULL DEFAULT 0,
    is_buy INTEGER NOT NULL DEFAULT 0,
    is_personal INTEGER NOT NULL DEFAULT 0,
    client_id INTEGER NOT NULL DEFAULT 0,
    location_id INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (character_id, transaction_id)
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
-- Cached ESI payloads with expiry (unix seconds). Expired rows are treated
-- as misses and pruned by the repositories layer.
CREATE TABLE IF NOT EXISTS esi_cache (
    cache_key TEXT PRIMARY KEY,
    payload_json TEXT NOT NULL DEFAULT '',
    fetched_at INTEGER NOT NULL DEFAULT 0,
    expires_at INTEGER NOT NULL DEFAULT 0
);
-- Non-secret token metadata only: granted scopes and access-token expiry.
-- There is deliberately no column capable of holding a token value.
CREATE TABLE IF NOT EXISTS token_meta (
    character_id INTEGER PRIMARY KEY,
    scopes TEXT NOT NULL DEFAULT '',
    expires_at INTEGER NOT NULL DEFAULT 0,
    updated_at TEXT NOT NULL DEFAULT ''
);
CREATE INDEX IF NOT EXISTS idx_skill_queue_character
    ON skill_queue (character_id, queue_position);
CREATE INDEX IF NOT EXISTS idx_wallet_journal_character_date
    ON wallet_journal (character_id, date DESC);
CREATE INDEX IF NOT EXISTS idx_wallet_journal_ref_type
    ON wallet_journal (character_id, ref_type);
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_character_date
    ON wallet_transactions (character_id, date DESC);
CREATE INDEX IF NOT EXISTS idx_universe_names_category
    ON universe_names (category);
CREATE INDEX IF NOT EXISTS idx_esi_cache_expires
    ON esi_cache (expires_at);
-- User-authored skill plans (the app's first non-ESI rows;
-- see docs/skill-plans-design.md section 5). plan_id is
-- storage-assigned; entries carry character_id so
-- delete_character can cascade by its table list.
CREATE TABLE IF NOT EXISTS skill_plans (
    plan_id INTEGER PRIMARY KEY AUTOINCREMENT,
    character_id INTEGER NOT NULL,
    name TEXT NOT NULL DEFAULT '',
    description TEXT NOT NULL DEFAULT '',
    created_at TEXT NOT NULL DEFAULT '',
    updated_at TEXT NOT NULL DEFAULT ''
);
CREATE TABLE IF NOT EXISTS skill_plan_entries (
    character_id INTEGER NOT NULL,
    plan_id INTEGER NOT NULL,
    sort_position INTEGER NOT NULL,
    skill_id INTEGER NOT NULL,
    target_level INTEGER NOT NULL DEFAULT 1,
    PRIMARY KEY (character_id, plan_id, sort_position)
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_skill_plan_entries_skill
    ON skill_plan_entries (character_id, plan_id, skill_id);
CREATE INDEX IF NOT EXISTS idx_skill_plans_character
    ON skill_plans (character_id, updated_at DESC);
-- SDE over HTTP reference tables (ADR-011, card #654). Additive only:
-- sync replaces rows inside these four tables in one transaction and
-- never deletes or drops characters, token_meta, skill_plans, or
-- skill_plan_entries.
CREATE TABLE IF NOT EXISTS sde_meta (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL DEFAULT ''
);
CREATE TABLE IF NOT EXISTS sde_types (
    type_id INTEGER PRIMARY KEY,
    name TEXT NOT NULL DEFAULT '',
    group_id INTEGER,
    published INTEGER NOT NULL DEFAULT 0
);
CREATE TABLE IF NOT EXISTS sde_solar_systems (
    system_id INTEGER PRIMARY KEY,
    name TEXT NOT NULL DEFAULT '',
    region_id INTEGER,
    security_status REAL
);
CREATE TABLE IF NOT EXISTS sde_stargates (
    stargate_id INTEGER PRIMARY KEY,
    name TEXT NOT NULL DEFAULT '',
    system_id INTEGER,
    destination_stargate_id INTEGER,
    destination_system_id INTEGER
);
CREATE INDEX IF NOT EXISTS idx_sde_types_group
    ON sde_types (group_id);
CREATE INDEX IF NOT EXISTS idx_sde_solar_systems_region
    ON sde_solar_systems (region_id);
CREATE INDEX IF NOT EXISTS idx_sde_stargates_system
    ON sde_stargates (system_id);
-- Cross-character Pantry asset index (card #642). Additive only:
-- one row per owned item instance across every linked character.
-- Deleting a character cascades (foreign_keys pragma is ON in
-- db::configure; delete_character also deletes explicitly).
CREATE TABLE IF NOT EXISTS character_assets (
    character_id INTEGER NOT NULL,
    item_id INTEGER NOT NULL,
    type_id INTEGER NOT NULL,
    location_id INTEGER NOT NULL,
    location_flag TEXT NOT NULL,
    location_type TEXT NOT NULL DEFAULT '',
    quantity INTEGER NOT NULL,
    is_singleton INTEGER NOT NULL,
    is_blueprint_copy INTEGER NOT NULL DEFAULT 0,
    is_blueprint INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (character_id, item_id),
    FOREIGN KEY (character_id) REFERENCES characters(character_id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_character_assets_character
    ON character_assets (character_id);
CREATE INDEX IF NOT EXISTS idx_character_assets_type
    ON character_assets (type_id);
