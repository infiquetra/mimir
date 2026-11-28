//! Rusqlite open/migrate and per-OS app-data path resolution.

use std::path::PathBuf;

use crate::config::EveConfig;
use crate::error::AppResult;

pub const SCHEMA_SQL: &str = include_str!("schema.sql");
pub const SCHEMA_VERSION: i64 = 3;

pub fn app_data_dir() -> PathBuf {
    tracing::debug!("[DB] resolving app data dir");
    if let Some(dirs) = directories::ProjectDirs::from("com", "infiquetra", "mimir") {
        dirs.data_dir().to_path_buf()
    } else {
        tracing::warn!("[DB] no per-OS data dir available; falling back to working directory");
        PathBuf::from(".")
    }
}

/// Cache directory (portrait/icon image cache lives here, never the DB).
pub fn app_cache_dir() -> PathBuf {
    tracing::debug!("[DB] resolving app cache dir");
    if let Some(dirs) = directories::ProjectDirs::from("com", "infiquetra", "mimir") {
        dirs.cache_dir().to_path_buf()
    } else {
        app_data_dir()
    }
}

pub fn db_path() -> PathBuf {
    app_data_dir().join(EveConfig::DB_FILENAME)
}

/// Path of the F1 plaintext token fallback file (created with mode 0600 by
/// the token store only when no OS keyring backend answers). The storage
/// layer itself never reads or writes token values.
pub fn token_fallback_path() -> PathBuf {
    app_data_dir().join(EveConfig::TOKEN_FILE_FILENAME)
}

/// Open (creating if needed) the database and run migrations.
pub fn open_db(path: &std::path::Path) -> AppResult<rusqlite::Connection> {
    tracing::info!("[DB] opening database at {}", path.display());
    if let Some(parent) = path.parent() {
        if !parent.as_os_str().is_empty() {
            std::fs::create_dir_all(parent)?;
        }
    }
    let conn = rusqlite::Connection::open(path)?;
    configure(&conn)?;
    migrate(&conn)?;
    tracing::debug!("[DB] database ready version={}", SCHEMA_VERSION);
    Ok(conn)
}

pub fn open_in_memory() -> AppResult<rusqlite::Connection> {
    tracing::debug!("[DB] opening in-memory database");
    let conn = rusqlite::Connection::open_in_memory()?;
    configure(&conn)?;
    migrate(&conn)?;
    Ok(conn)
}

fn configure(conn: &rusqlite::Connection) -> AppResult<()> {
    tracing::debug!("[DB] applying connection pragmas");
    // WAL lets the UI read while a refresh task writes; it is a no-op for
    // in-memory databases. busy_timeout avoids spurious "database is
    // locked" failures when refresh and render overlap.
    conn.pragma_update(None, "journal_mode", "WAL")?;
    conn.pragma_update(None, "synchronous", "NORMAL")?;
    // SQLite ships with foreign-key enforcement OFF per connection;
    // character_assets relies on ON DELETE CASCADE from characters.
    conn.pragma_update(None, "foreign_keys", "ON")?;
    conn.busy_timeout(std::time::Duration::from_secs(5))?;
    Ok(())
}

/// Current `user_version` recorded in the database file (0 when unset).
pub fn schema_version(conn: &rusqlite::Connection) -> AppResult<i64> {
    let version: i64 = conn.query_row("PRAGMA user_version", [], |row| row.get(0))?;
    tracing::debug!("[DB] schema_version read version={}", version);
    Ok(version)
}

fn pk_col_count(conn: &rusqlite::Connection, table: &str) -> AppResult<usize> {
    let count: i64 = conn.query_row(
        "SELECT COUNT(*) FROM pragma_table_info(?1) WHERE pk > 0",
        [table],
        |row| row.get(0),
    )?;
    Ok(count.max(0) as usize)
}

/// Upgrade v1/v2 single-column wallet PKs (`id` / `transaction_id`) to composite
/// `(character_id, ...)` PKs so two characters trading together keep both rows.
fn migrate_wallet_composite_pks(conn: &rusqlite::Connection) -> AppResult<()> {
    if pk_col_count(conn, "wallet_journal")? == 1 {
        tracing::info!("[DB] migrating wallet_journal to composite primary key (v3)");
        let tx = conn.unchecked_transaction()?;
        tx.execute_batch(
            "CREATE TABLE wallet_journal_v3 (
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
            INSERT OR REPLACE INTO wallet_journal_v3
                (id, character_id, amount, balance, date, description, ref_type, first_party_id, second_party_id)
                SELECT id, character_id, amount, balance, date, description, ref_type, first_party_id, second_party_id
                FROM wallet_journal;
            DROP TABLE wallet_journal;
            ALTER TABLE wallet_journal_v3 RENAME TO wallet_journal;
            CREATE INDEX IF NOT EXISTS idx_wallet_journal_character_date
                ON wallet_journal (character_id, date DESC);
            CREATE INDEX IF NOT EXISTS idx_wallet_journal_ref_type
                ON wallet_journal (character_id, ref_type);",
        )?;
        tx.commit()?;
    }
    if pk_col_count(conn, "wallet_transactions")? == 1 {
        tracing::info!("[DB] migrating wallet_transactions to composite primary key (v3)");
        let tx = conn.unchecked_transaction()?;
        tx.execute_batch(
            "CREATE TABLE wallet_transactions_v3 (
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
            INSERT OR REPLACE INTO wallet_transactions_v3
                (transaction_id, character_id, journal_ref_id, date, type_id, quantity, unit_price, is_buy, is_personal, client_id, location_id)
                SELECT transaction_id, character_id, journal_ref_id, date, type_id, quantity, unit_price, is_buy, is_personal, client_id, location_id
                FROM wallet_transactions;
            DROP TABLE wallet_transactions;
            ALTER TABLE wallet_transactions_v3 RENAME TO wallet_transactions;
            CREATE INDEX IF NOT EXISTS idx_wallet_transactions_character_date
                ON wallet_transactions (character_id, date DESC);",
        )?;
        tx.commit()?;
    }
    Ok(())
}

pub fn migrate(conn: &rusqlite::Connection) -> AppResult<()> {
    tracing::debug!("[DB] migrate to version {}", SCHEMA_VERSION);
    let current = schema_version(conn)?;
    if current > SCHEMA_VERSION {
        // A newer build wrote this file. The DDL below is additive
        // (IF NOT EXISTS), so running it is still safe, but say so loudly.
        tracing::warn!(
            "[DB] database schema version {} is newer than supported {}; continuing",
            current,
            SCHEMA_VERSION
        );
    }
    conn.execute_batch(SCHEMA_SQL)?;
    migrate_wallet_composite_pks(conn)?;
    if current <= SCHEMA_VERSION {
        conn.pragma_update(None, "user_version", SCHEMA_VERSION)?;
    }
    tracing::debug!("[DB] migrate complete version={}", SCHEMA_VERSION);
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn migrate_is_idempotent_and_sets_version() {
        let conn = open_in_memory().expect("in-memory db opens");
        migrate(&conn).expect("second migrate is a no-op success");
        assert_eq!(schema_version(&conn).expect("version readable"), 3);
    }

    #[test]
    fn schema_creates_contract_tables_plus_f2_additions() {
        let conn = open_in_memory().expect("in-memory db opens");
        let count: i64 = conn
            .query_row(
                "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name IN \
                 ('characters','skill_queue','character_skills','wallet_balances',\
                  'wallet_journal','wallet_transactions','loyalty_points',\
                  'universe_names','app_settings','esi_cache','token_meta')",
                [],
                |row| row.get(0),
            )
            .expect("table count readable");
        assert_eq!(count, 11);
    }

    #[test]
    fn schema_creates_plan_tables() {
        let conn = open_in_memory().expect("in-memory db opens");
        let count: i64 = conn
            .query_row(
                "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name IN \
                 ('skill_plans','skill_plan_entries')",
                [],
                |row| row.get(0),
            )
            .expect("plan table count readable");
        assert_eq!(count, 2);
    }

    // T11: migrate_from_v1_adds_plan_tables_and_keeps_rows (design section 5.2).
    #[test]
    fn migrate_from_v1_adds_plan_tables_and_keeps_rows() {
        // Simulate a v1 file: open in-memory, migrate fully, then strip
        // back to v1 shape (stamp user_version = 1, drop the plan
        // tables), insert one character, then re-run migrate(). This is
        // the only honest way to test an upgrade when open_in_memory()
        // always migrates to current.
        let conn = rusqlite::Connection::open_in_memory().expect("in-memory db opens");
        conn.pragma_update(None, "user_version", 1_i64)
            .expect("stamp v1");
        conn.execute_batch(
            "CREATE TABLE IF NOT EXISTS characters (\
               character_id INTEGER PRIMARY KEY, name TEXT NOT NULL DEFAULT '', \
               corporation_id INTEGER NOT NULL DEFAULT 0, alliance_id INTEGER, \
               is_active INTEGER NOT NULL DEFAULT 0, updated_at TEXT NOT NULL DEFAULT '');\
             INSERT INTO characters (character_id, name, corporation_id, is_active, updated_at) \
               VALUES (90000001, 'Aria', 1000166, 1, '2026-11-15T00:00:00Z');",
        )
        .expect("v1 character row");
        // No plan tables exist yet on a v1 file; migrate() adds them.
        migrate(&conn).expect("upgrade migrate");
        assert_eq!(schema_version(&conn).expect("version readable"), 3);
        let plan_tables: i64 = conn
            .query_row(
                "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name IN \
                 ('skill_plans','skill_plan_entries')",
                [],
                |row| row.get(0),
            )
            .expect("plan table count readable after upgrade");
        assert_eq!(plan_tables, 2);
        let name: String = conn
            .query_row(
                "SELECT name FROM characters WHERE character_id = 90000001",
                [],
                |row| row.get(0),
            )
            .expect("character row survived");
        assert_eq!(name, "Aria");
    }

    #[test]
    fn migrate_from_v2_rebuilds_wallet_composite_pks_and_keeps_rows() {
        let conn = rusqlite::Connection::open_in_memory().expect("in-memory db opens");
        conn.pragma_update(None, "user_version", 2_i64)
            .expect("stamp v2");
        conn.execute_batch(
            "CREATE TABLE wallet_journal (
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
            CREATE TABLE wallet_transactions (
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
            INSERT INTO wallet_journal (id, character_id, amount, balance, date, description, ref_type)
                VALUES (500, 1, 100.0, 1000.0, '2026-11-15T00:00:00Z', 'Trade', 'market_escrow');
            INSERT INTO wallet_transactions (transaction_id, character_id, journal_ref_id, date, type_id, quantity, unit_price, is_buy, is_personal, client_id, location_id)
                VALUES (900, 1, 500, '2026-11-15T00:00:00Z', 34, 10, 5.0, 1, 1, 2, 60003760);",
        )
        .expect("v2 wallet tables");

        migrate(&conn).expect("upgrade to v3");
        assert_eq!(schema_version(&conn).expect("v3"), 3);
        assert_eq!(pk_col_count(&conn, "wallet_journal").expect("pk"), 2);
        assert_eq!(pk_col_count(&conn, "wallet_transactions").expect("pk"), 2);

        // Existing rows preserved AND character 2 can share the exact same id/transaction_id.
        crate::storage::repositories::upsert_journal(
            &conn,
            &[crate::storage::repositories::WalletJournalRow {
                id: 500,
                character_id: 2,
                amount: -100.0,
                balance: 500.0,
                date: "2026-11-15T00:00:00Z".to_string(),
                description: "Trade".to_string(),
                ref_type: "market_escrow".to_string(),
                first_party_id: Some(1),
                second_party_id: Some(2),
            }],
        )
        .expect("insert char 2 journal");
        crate::storage::repositories::upsert_transactions(
            &conn,
            &[crate::storage::repositories::WalletTransactionRow {
                transaction_id: 900,
                character_id: 2,
                journal_ref_id: 500,
                date: "2026-11-15T00:00:00Z".to_string(),
                type_id: 34,
                quantity: 10,
                unit_price: 5.0,
                is_buy: false,
                is_personal: true,
                client_id: 1,
                location_id: 60003760,
            }],
        )
        .expect("insert char 2 tx");

        assert_eq!(
            crate::storage::repositories::list_journal(&conn, 1)
                .expect("j1")
                .len(),
            1
        );
        assert_eq!(
            crate::storage::repositories::list_journal(&conn, 2)
                .expect("j2")
                .len(),
            1
        );
        assert_eq!(
            crate::storage::repositories::list_transactions(&conn, 1)
                .expect("t1")
                .len(),
            1
        );
        assert_eq!(
            crate::storage::repositories::list_transactions(&conn, 2)
                .expect("t2")
                .len(),
            1
        );
    }
}
