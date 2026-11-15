//! Rusqlite open/migrate and per-OS app-data path resolution.

use std::path::PathBuf;

use crate::config::EveConfig;
use crate::error::AppResult;

pub const SCHEMA_SQL: &str = include_str!("schema.sql");
pub const SCHEMA_VERSION: i64 = 1;

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
    conn.busy_timeout(std::time::Duration::from_secs(5))?;
    Ok(())
}

/// Current `user_version` recorded in the database file (0 when unset).
pub fn schema_version(conn: &rusqlite::Connection) -> AppResult<i64> {
    let version: i64 = conn.query_row("PRAGMA user_version", [], |row| row.get(0))?;
    tracing::debug!("[DB] schema_version read version={}", version);
    Ok(version)
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
        assert_eq!(schema_version(&conn).expect("version readable"), 1);
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
}
