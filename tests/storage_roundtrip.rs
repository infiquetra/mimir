//! Temp-database schema and repository round-trips.

use mimir::storage::db;
use mimir::storage::repositories::{list_characters, upsert_character, CharacterRow};

#[test]
fn schema_migrates_on_empty_db() {
    let conn = db::open_in_memory().expect("in-memory db opens");
    let version: i64 = conn
        .query_row("PRAGMA user_version", [], |row| row.get(0))
        .expect("user_version readable");
    assert_eq!(version, db::SCHEMA_VERSION);
    let tables: i64 = conn
        .query_row(
            "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name IN \
             ('characters','skill_queue','character_skills','wallet_balances',\
              'wallet_journal','wallet_transactions','loyalty_points',\
              'universe_names','app_settings')",
            [],
            |row| row.get(0),
        )
        .expect("table count readable");
    assert_eq!(tables, 9);
}

#[test]
fn repository_stubs_roundtrip_without_error() {
    let conn = db::open_in_memory().expect("in-memory db opens");
    let row = CharacterRow {
        character_id: 90000001,
        name: "Demo Capsuleer".to_string(),
        corporation_id: 1000166,
        alliance_id: None,
        is_active: true,
    };
    upsert_character(&conn, &row).expect("stub upsert succeeds");
    // Stubs return empty lists until F2 lands the SQL bodies.
    let listed = list_characters(&conn).expect("stub list succeeds");
    assert!(listed.is_empty());
}

#[test]
fn temp_file_db_opens_and_migrates() {
    let dir = tempfile::tempdir().expect("tempdir");
    let path = dir.path().join("mimir.db");
    let _conn = db::open_db(&path).expect("file db opens");
    assert!(path.exists());
}
