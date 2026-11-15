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
        PathBuf::from(".")
    }
}

pub fn db_path() -> PathBuf {
    app_data_dir().join(EveConfig::DB_FILENAME)
}

/// Open (creating if needed) the database and run migrations.
pub fn open_db(path: &std::path::Path) -> AppResult<rusqlite::Connection> {
    tracing::info!("[DB] opening database at {}", path.display());
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent)?;
    }
    let conn = rusqlite::Connection::open(path)?;
    migrate(&conn)?;
    tracing::debug!("[DB] database ready version={}", SCHEMA_VERSION);
    Ok(conn)
}

pub fn open_in_memory() -> AppResult<rusqlite::Connection> {
    tracing::debug!("[DB] opening in-memory database");
    let conn = rusqlite::Connection::open_in_memory()?;
    migrate(&conn)?;
    Ok(conn)
}

pub fn migrate(conn: &rusqlite::Connection) -> AppResult<()> {
    tracing::debug!("[DB] migrate to version {}", SCHEMA_VERSION);
    conn.execute_batch(SCHEMA_SQL)?;
    conn.pragma_update(None, "user_version", SCHEMA_VERSION)?;
    Ok(())
}
