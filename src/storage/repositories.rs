//! Typed CRUD per table. Bodies are stubs for F2; signatures are final.

use crate::error::AppResult;

#[derive(Debug, Clone, Default)]
pub struct CharacterRow {
    pub character_id: i64,
    pub name: String,
    pub corporation_id: i64,
    pub alliance_id: Option<i64>,
    pub is_active: bool,
}

#[derive(Debug, Clone, Default)]
pub struct SkillQueueRow {
    pub character_id: i64,
    pub queue_position: i32,
    pub skill_id: i64,
    pub finished_level: i32,
    pub start_date: Option<String>,
    pub finish_date: Option<String>,
}

#[derive(Debug, Clone, Default)]
pub struct CharacterSkillRow {
    pub character_id: i64,
    pub skill_id: i64,
    pub active_skill_level: i32,
    pub trained_skill_level: i32,
    pub skillpoints_in_skill: i64,
}

#[derive(Debug, Clone, Default)]
pub struct WalletBalanceRow {
    pub character_id: i64,
    pub balance: f64,
}

#[derive(Debug, Clone, Default)]
pub struct WalletJournalRow {
    pub id: i64,
    pub character_id: i64,
    pub amount: f64,
    pub balance: f64,
    pub date: String,
    pub description: String,
    pub ref_type: String,
    pub first_party_id: Option<i64>,
    pub second_party_id: Option<i64>,
}

#[derive(Debug, Clone, Default)]
pub struct WalletTransactionRow {
    pub transaction_id: i64,
    pub character_id: i64,
    pub journal_ref_id: i64,
    pub date: String,
    pub type_id: i64,
    pub quantity: i64,
    pub unit_price: f64,
    pub is_buy: bool,
    pub is_personal: bool,
    pub client_id: i64,
    pub location_id: i64,
}

#[derive(Debug, Clone, Default)]
pub struct LoyaltyRow {
    pub character_id: i64,
    pub corporation_id: i64,
    pub loyalty_points: i64,
}

pub fn upsert_character(_conn: &rusqlite::Connection, _row: &CharacterRow) -> AppResult<()> {
    tracing::debug!("[DB] upsert_character (stub)");
    Ok(())
}

pub fn list_characters(_conn: &rusqlite::Connection) -> AppResult<Vec<CharacterRow>> {
    tracing::debug!("[DB] list_characters (stub)");
    Ok(Vec::new())
}

pub fn active_character(_conn: &rusqlite::Connection) -> AppResult<Option<CharacterRow>> {
    tracing::debug!("[DB] active_character (stub)");
    Ok(None)
}

pub fn replace_skill_queue(
    _conn: &rusqlite::Connection,
    character_id: i64,
    _rows: &[SkillQueueRow],
) -> AppResult<()> {
    tracing::debug!(
        "[DB] replace_skill_queue character_id={} (stub)",
        character_id
    );
    Ok(())
}

pub fn list_skill_queue(
    _conn: &rusqlite::Connection,
    character_id: i64,
) -> AppResult<Vec<SkillQueueRow>> {
    tracing::debug!("[DB] list_skill_queue character_id={} (stub)", character_id);
    Ok(Vec::new())
}

pub fn replace_character_skills(
    _conn: &rusqlite::Connection,
    character_id: i64,
    _rows: &[CharacterSkillRow],
) -> AppResult<()> {
    tracing::debug!(
        "[DB] replace_character_skills character_id={} (stub)",
        character_id
    );
    Ok(())
}

pub fn list_character_skills(
    _conn: &rusqlite::Connection,
    character_id: i64,
) -> AppResult<Vec<CharacterSkillRow>> {
    tracing::debug!(
        "[DB] list_character_skills character_id={} (stub)",
        character_id
    );
    Ok(Vec::new())
}

pub fn set_wallet_balance(_conn: &rusqlite::Connection, _row: &WalletBalanceRow) -> AppResult<()> {
    tracing::debug!("[WALLET] set_wallet_balance (stub)");
    Ok(())
}

pub fn wallet_balance(_conn: &rusqlite::Connection, character_id: i64) -> AppResult<Option<f64>> {
    tracing::debug!(
        "[WALLET] wallet_balance character_id={} (stub)",
        character_id
    );
    Ok(None)
}

pub fn upsert_journal(_conn: &rusqlite::Connection, _rows: &[WalletJournalRow]) -> AppResult<()> {
    tracing::debug!("[WALLET] upsert_journal (stub)");
    Ok(())
}

pub fn list_journal(
    _conn: &rusqlite::Connection,
    character_id: i64,
) -> AppResult<Vec<WalletJournalRow>> {
    tracing::debug!("[WALLET] list_journal character_id={} (stub)", character_id);
    Ok(Vec::new())
}

pub fn upsert_transactions(
    _conn: &rusqlite::Connection,
    _rows: &[WalletTransactionRow],
) -> AppResult<()> {
    tracing::debug!("[WALLET] upsert_transactions (stub)");
    Ok(())
}

pub fn list_transactions(
    _conn: &rusqlite::Connection,
    character_id: i64,
) -> AppResult<Vec<WalletTransactionRow>> {
    tracing::debug!(
        "[WALLET] list_transactions character_id={} (stub)",
        character_id
    );
    Ok(Vec::new())
}

pub fn replace_loyalty(
    _conn: &rusqlite::Connection,
    character_id: i64,
    _rows: &[LoyaltyRow],
) -> AppResult<()> {
    tracing::debug!(
        "[WALLET] replace_loyalty character_id={} (stub)",
        character_id
    );
    Ok(())
}

pub fn list_loyalty(_conn: &rusqlite::Connection, character_id: i64) -> AppResult<Vec<LoyaltyRow>> {
    tracing::debug!("[WALLET] list_loyalty character_id={} (stub)", character_id);
    Ok(Vec::new())
}

pub fn get_setting(_conn: &rusqlite::Connection, key: &str) -> AppResult<Option<String>> {
    tracing::debug!("[DB] get_setting key={} (stub)", key);
    Ok(None)
}

pub fn set_setting(_conn: &rusqlite::Connection, key: &str, _value: &str) -> AppResult<()> {
    tracing::debug!("[DB] set_setting key={} (stub)", key);
    Ok(())
}
