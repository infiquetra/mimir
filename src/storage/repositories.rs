//! Typed CRUD per table plus the wallet aggregates the dashboard needs.
//!
//! Every function takes `&rusqlite::Connection`; multi-row writes open an
//! `unchecked_transaction` so a failed refresh never leaves a half-written
//! queue or wallet behind. No token values are ever stored here —
//! `token_meta` holds scopes and expiry only. Dates are stored as the
//! ISO-8601 text ESI returns (`2026-11-15T00:00:00Z`), so lexicographic
//! ordering is chronological ordering.

use rusqlite::{params, OptionalExtension};

use crate::error::AppResult;

#[derive(Debug, Clone, Default, PartialEq)]
pub struct CharacterRow {
    pub character_id: i64,
    pub name: String,
    pub corporation_id: i64,
    pub alliance_id: Option<i64>,
    pub is_active: bool,
}

#[derive(Debug, Clone, Default, PartialEq)]
pub struct SkillQueueRow {
    pub character_id: i64,
    pub queue_position: i32,
    pub skill_id: i64,
    pub finished_level: i32,
    pub start_date: Option<String>,
    pub finish_date: Option<String>,
}

#[derive(Debug, Clone, Default, PartialEq)]
pub struct CharacterSkillRow {
    pub character_id: i64,
    pub skill_id: i64,
    pub active_skill_level: i32,
    pub trained_skill_level: i32,
    pub skillpoints_in_skill: i64,
}

#[derive(Debug, Clone, Default, PartialEq)]
pub struct WalletBalanceRow {
    pub character_id: i64,
    pub balance: f64,
}

#[derive(Debug, Clone, Default, PartialEq)]
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

#[derive(Debug, Clone, Default, PartialEq)]
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

#[derive(Debug, Clone, Default, PartialEq)]
pub struct LoyaltyRow {
    pub character_id: i64,
    pub corporation_id: i64,
    pub loyalty_points: i64,
}

/// One persisted `universe_names` row (the F2 mirror of F1's
/// `esi::models::UniverseName`, so storage callers need no ESI types).
#[derive(Debug, Clone, Default, PartialEq)]
pub struct UniverseNameRow {
    pub id: i64,
    pub name: String,
    pub category: String,
}

/// Non-secret token metadata. There is no field for a token value by
/// design; tokens live in the F1 keyring / 0600-file store.
#[derive(Debug, Clone, Default, PartialEq)]
pub struct TokenMetaRow {
    pub character_id: i64,
    /// Space-separated granted scopes, as returned by EVE SSO.
    pub scopes: String,
    /// Access-token expiry as unix seconds (0 when unknown).
    pub expires_at: i64,
}

/// One day of wallet movement for the dashboard trend card.
#[derive(Debug, Clone, Default, PartialEq)]
pub struct WalletDayRow {
    /// `YYYY-MM-DD` (first ten characters of the stored ESI date).
    pub day: String,
    pub income: f64,
    pub expense: f64,
    pub net: f64,
}

/// Journal totals grouped by ESI `ref_type` for wallet analytics.
#[derive(Debug, Clone, Default, PartialEq)]
pub struct RefTypeTotalRow {
    pub ref_type: String,
    pub total: f64,
    pub entries: i64,
}

fn now_iso() -> String {
    chrono::Utc::now().format("%Y-%m-%dT%H:%M:%SZ").to_string()
}

fn now_unix() -> i64 {
    chrono::Utc::now().timestamp()
}

/// `YYYY-MM-DD` cutoff `days` before today (UTC), for range aggregates.
fn cutoff_day(days: i64) -> String {
    (chrono::Utc::now() - chrono::Duration::days(days))
        .format("%Y-%m-%d")
        .to_string()
}

// ---------------------------------------------------------------------------
// Characters
// ---------------------------------------------------------------------------

fn character_from_row(row: &rusqlite::Row<'_>) -> rusqlite::Result<CharacterRow> {
    let is_active: i64 = row.get(4)?;
    Ok(CharacterRow {
        character_id: row.get(0)?,
        name: row.get(1)?,
        corporation_id: row.get(2)?,
        alliance_id: row.get(3)?,
        is_active: is_active != 0,
    })
}

const CHARACTER_COLS: &str = "character_id, name, corporation_id, alliance_id, is_active";

pub fn upsert_character(conn: &rusqlite::Connection, row: &CharacterRow) -> AppResult<()> {
    tracing::debug!("[CHAR] upsert_character character_id={}", row.character_id);
    conn.execute(
        "INSERT INTO characters \
         (character_id, name, corporation_id, alliance_id, is_active, updated_at) \
         VALUES (?1, ?2, ?3, ?4, ?5, ?6) \
         ON CONFLICT(character_id) DO UPDATE SET \
           name=excluded.name, corporation_id=excluded.corporation_id, \
           alliance_id=excluded.alliance_id, is_active=excluded.is_active, \
           updated_at=excluded.updated_at",
        params![
            row.character_id,
            row.name,
            row.corporation_id,
            row.alliance_id,
            row.is_active as i64,
            now_iso()
        ],
    )?;
    Ok(())
}

pub fn list_characters(conn: &rusqlite::Connection) -> AppResult<Vec<CharacterRow>> {
    tracing::debug!("[DB] list_characters entry");
    let mut stmt = conn.prepare(&format!(
        "SELECT {CHARACTER_COLS} FROM characters ORDER BY name COLLATE NOCASE"
    ))?;
    let rows = stmt.query_map([], character_from_row)?;
    let mut out = Vec::new();
    for row in rows {
        out.push(row?);
    }
    tracing::debug!("[DB] list_characters exit count={}", out.len());
    Ok(out)
}

pub fn get_character(
    conn: &rusqlite::Connection,
    character_id: i64,
) -> AppResult<Option<CharacterRow>> {
    tracing::debug!("[DB] get_character character_id={}", character_id);
    let row = conn
        .query_row(
            &format!("SELECT {CHARACTER_COLS} FROM characters WHERE character_id = ?1"),
            params![character_id],
            character_from_row,
        )
        .optional()?;
    Ok(row)
}

pub fn active_character(conn: &rusqlite::Connection) -> AppResult<Option<CharacterRow>> {
    tracing::debug!("[DB] active_character entry");
    let row = conn
        .query_row(
            &format!(
                "SELECT {CHARACTER_COLS} FROM characters WHERE is_active != 0 \
                 ORDER BY character_id LIMIT 1"
            ),
            [],
            character_from_row,
        )
        .optional()?;
    Ok(row)
}

/// Make exactly one character active (the character-rail switch).
pub fn set_active_character(conn: &rusqlite::Connection, character_id: i64) -> AppResult<()> {
    tracing::info!("[CHAR] set_active_character character_id={}", character_id);
    let tx = conn.unchecked_transaction()?;
    tx.execute("UPDATE characters SET is_active = 0", [])?;
    let changed = tx.execute(
        "UPDATE characters SET is_active = 1 WHERE character_id = ?1",
        params![character_id],
    )?;
    tx.commit()?;
    if changed == 0 {
        tracing::warn!(
            "[CHAR] set_active_character matched no row character_id={}",
            character_id
        );
    }
    Ok(())
}

/// Delete a character and every cached row that belongs to it, including
/// its token metadata. Returns false when the character did not exist.
pub fn delete_character(conn: &rusqlite::Connection, character_id: i64) -> AppResult<bool> {
    tracing::info!("[CHAR] delete_character character_id={}", character_id);
    let tx = conn.unchecked_transaction()?;
    for table in [
        "skill_queue",
        "character_skills",
        "wallet_balances",
        "wallet_journal",
        "wallet_transactions",
        "loyalty_points",
        "token_meta",
    ] {
        tx.execute(
            &format!("DELETE FROM {table} WHERE character_id = ?1"),
            params![character_id],
        )?;
    }
    let changed = tx.execute(
        "DELETE FROM characters WHERE character_id = ?1",
        params![character_id],
    )?;
    tx.commit()?;
    Ok(changed > 0)
}

pub fn character_count(conn: &rusqlite::Connection) -> AppResult<i64> {
    tracing::debug!("[DB] character_count entry");
    let count: i64 = conn.query_row("SELECT COUNT(*) FROM characters", [], |r| r.get(0))?;
    Ok(count)
}

// ---------------------------------------------------------------------------
// Skills
// ---------------------------------------------------------------------------

pub fn replace_skill_queue(
    conn: &rusqlite::Connection,
    character_id: i64,
    rows: &[SkillQueueRow],
) -> AppResult<()> {
    tracing::debug!(
        "[SKILLS] replace_skill_queue character_id={} count={}",
        character_id,
        rows.len()
    );
    let tx = conn.unchecked_transaction()?;
    tx.execute(
        "DELETE FROM skill_queue WHERE character_id = ?1",
        params![character_id],
    )?;
    {
        let mut stmt = tx.prepare(
            "INSERT INTO skill_queue \
             (character_id, queue_position, skill_id, finished_level, start_date, finish_date) \
             VALUES (?1, ?2, ?3, ?4, ?5, ?6)",
        )?;
        for row in rows {
            stmt.execute(params![
                character_id,
                row.queue_position,
                row.skill_id,
                row.finished_level,
                row.start_date,
                row.finish_date
            ])?;
        }
    }
    tx.commit()?;
    Ok(())
}

pub fn list_skill_queue(
    conn: &rusqlite::Connection,
    character_id: i64,
) -> AppResult<Vec<SkillQueueRow>> {
    tracing::debug!("[SKILLS] list_skill_queue character_id={}", character_id);
    let mut stmt = conn.prepare(
        "SELECT character_id, queue_position, skill_id, finished_level, start_date, finish_date \
         FROM skill_queue WHERE character_id = ?1 ORDER BY queue_position",
    )?;
    let rows = stmt.query_map(params![character_id], |row| {
        Ok(SkillQueueRow {
            character_id: row.get(0)?,
            queue_position: row.get(1)?,
            skill_id: row.get(2)?,
            finished_level: row.get(3)?,
            start_date: row.get(4)?,
            finish_date: row.get(5)?,
        })
    })?;
    let mut out = Vec::new();
    for row in rows {
        out.push(row?);
    }
    Ok(out)
}

pub fn replace_character_skills(
    conn: &rusqlite::Connection,
    character_id: i64,
    rows: &[CharacterSkillRow],
) -> AppResult<()> {
    tracing::debug!(
        "[SKILLS] replace_character_skills character_id={} count={}",
        character_id,
        rows.len()
    );
    let tx = conn.unchecked_transaction()?;
    tx.execute(
        "DELETE FROM character_skills WHERE character_id = ?1",
        params![character_id],
    )?;
    {
        let mut stmt = tx.prepare(
            "INSERT INTO character_skills \
             (character_id, skill_id, active_skill_level, trained_skill_level, \
              skillpoints_in_skill) VALUES (?1, ?2, ?3, ?4, ?5)",
        )?;
        for row in rows {
            stmt.execute(params![
                character_id,
                row.skill_id,
                row.active_skill_level,
                row.trained_skill_level,
                row.skillpoints_in_skill
            ])?;
        }
    }
    tx.commit()?;
    Ok(())
}

pub fn list_character_skills(
    conn: &rusqlite::Connection,
    character_id: i64,
) -> AppResult<Vec<CharacterSkillRow>> {
    tracing::debug!(
        "[SKILLS] list_character_skills character_id={}",
        character_id
    );
    let mut stmt = conn.prepare(
        "SELECT character_id, skill_id, active_skill_level, trained_skill_level, \
         skillpoints_in_skill FROM character_skills WHERE character_id = ?1 \
         ORDER BY skill_id",
    )?;
    let rows = stmt.query_map(params![character_id], |row| {
        Ok(CharacterSkillRow {
            character_id: row.get(0)?,
            skill_id: row.get(1)?,
            active_skill_level: row.get(2)?,
            trained_skill_level: row.get(3)?,
            skillpoints_in_skill: row.get(4)?,
        })
    })?;
    let mut out = Vec::new();
    for row in rows {
        out.push(row?);
    }
    Ok(out)
}

/// Total trained SP for a character (sum over the cached skill rows).
pub fn total_skillpoints(conn: &rusqlite::Connection, character_id: i64) -> AppResult<i64> {
    tracing::debug!("[SKILLS] total_skillpoints character_id={}", character_id);
    let total: i64 = conn.query_row(
        "SELECT COALESCE(SUM(skillpoints_in_skill), 0) FROM character_skills \
         WHERE character_id = ?1",
        params![character_id],
        |r| r.get(0),
    )?;
    Ok(total)
}

// ---------------------------------------------------------------------------
// Wallet
// ---------------------------------------------------------------------------

pub fn set_wallet_balance(conn: &rusqlite::Connection, row: &WalletBalanceRow) -> AppResult<()> {
    tracing::debug!(
        "[WALLET] set_wallet_balance character_id={}",
        row.character_id
    );
    conn.execute(
        "INSERT INTO wallet_balances (character_id, balance, updated_at) \
         VALUES (?1, ?2, ?3) ON CONFLICT(character_id) DO UPDATE SET \
           balance=excluded.balance, updated_at=excluded.updated_at",
        params![row.character_id, row.balance, now_iso()],
    )?;
    Ok(())
}

pub fn wallet_balance(conn: &rusqlite::Connection, character_id: i64) -> AppResult<Option<f64>> {
    tracing::debug!("[WALLET] wallet_balance character_id={}", character_id);
    let balance = conn
        .query_row(
            "SELECT balance FROM wallet_balances WHERE character_id = ?1",
            params![character_id],
            |r| r.get(0),
        )
        .optional()?;
    Ok(balance)
}

/// Combined ISK across every stored character (dashboard wealth card).
pub fn combined_wallet_balance(conn: &rusqlite::Connection) -> AppResult<f64> {
    tracing::debug!("[WALLET] combined_wallet_balance entry");
    let total: f64 = conn.query_row(
        "SELECT COALESCE(SUM(balance), 0) FROM wallet_balances",
        [],
        |r| r.get(0),
    )?;
    Ok(total)
}

pub fn upsert_journal(conn: &rusqlite::Connection, rows: &[WalletJournalRow]) -> AppResult<()> {
    tracing::debug!("[WALLET] upsert_journal count={}", rows.len());
    let tx = conn.unchecked_transaction()?;
    {
        let mut stmt = tx.prepare(
            "INSERT INTO wallet_journal \
             (id, character_id, amount, balance, date, description, ref_type, \
              first_party_id, second_party_id) \
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9) \
             ON CONFLICT(id) DO UPDATE SET \
               character_id=excluded.character_id, amount=excluded.amount, \
               balance=excluded.balance, date=excluded.date, \
               description=excluded.description, ref_type=excluded.ref_type, \
               first_party_id=excluded.first_party_id, \
               second_party_id=excluded.second_party_id",
        )?;
        for row in rows {
            stmt.execute(params![
                row.id,
                row.character_id,
                row.amount,
                row.balance,
                row.date,
                row.description,
                row.ref_type,
                row.first_party_id,
                row.second_party_id
            ])?;
        }
    }
    tx.commit()?;
    Ok(())
}

fn journal_from_row(row: &rusqlite::Row<'_>) -> rusqlite::Result<WalletJournalRow> {
    Ok(WalletJournalRow {
        id: row.get(0)?,
        character_id: row.get(1)?,
        amount: row.get(2)?,
        balance: row.get(3)?,
        date: row.get(4)?,
        description: row.get(5)?,
        ref_type: row.get(6)?,
        first_party_id: row.get(7)?,
        second_party_id: row.get(8)?,
    })
}

const JOURNAL_COLS: &str =
    "id, character_id, amount, balance, date, description, ref_type, first_party_id, second_party_id";

/// Journal rows for one character, newest first.
pub fn list_journal(
    conn: &rusqlite::Connection,
    character_id: i64,
) -> AppResult<Vec<WalletJournalRow>> {
    tracing::debug!("[WALLET] list_journal character_id={}", character_id);
    let mut stmt = conn.prepare(&format!(
        "SELECT {JOURNAL_COLS} FROM wallet_journal WHERE character_id = ?1 \
         ORDER BY date DESC, id DESC"
    ))?;
    let rows = stmt.query_map(params![character_id], journal_from_row)?;
    let mut out = Vec::new();
    for row in rows {
        out.push(row?);
    }
    Ok(out)
}

/// Journal rows since `since` (ISO date text), newest first — the 7/30/90
/// day wallet filters pass their own cutoff.
pub fn list_journal_since(
    conn: &rusqlite::Connection,
    character_id: i64,
    since: &str,
) -> AppResult<Vec<WalletJournalRow>> {
    tracing::debug!(
        "[WALLET] list_journal_since character_id={} since={}",
        character_id,
        since
    );
    let mut stmt = conn.prepare(&format!(
        "SELECT {JOURNAL_COLS} FROM wallet_journal \
         WHERE character_id = ?1 AND date >= ?2 ORDER BY date DESC, id DESC"
    ))?;
    let rows = stmt.query_map(params![character_id, since], journal_from_row)?;
    let mut out = Vec::new();
    for row in rows {
        out.push(row?);
    }
    Ok(out)
}

/// Highest journal id stored for a character; ESI journal paging uses
/// `from_id` below this instead of refetching known pages.
pub fn max_journal_id(conn: &rusqlite::Connection, character_id: i64) -> AppResult<Option<i64>> {
    tracing::debug!("[WALLET] max_journal_id character_id={}", character_id);
    let max: Option<i64> = conn.query_row(
        "SELECT MAX(id) FROM wallet_journal WHERE character_id = ?1",
        params![character_id],
        |r| r.get(0),
    )?;
    Ok(max)
}

/// Daily income/expense/net over the last `days` days, oldest first
/// (dashboard 30-day wallet trend).
pub fn wallet_daily_trend(
    conn: &rusqlite::Connection,
    character_id: i64,
    days: i64,
) -> AppResult<Vec<WalletDayRow>> {
    tracing::debug!(
        "[WALLET] wallet_daily_trend character_id={} days={}",
        character_id,
        days
    );
    let since = cutoff_day(days.max(0));
    let mut stmt = conn.prepare(
        "SELECT substr(date, 1, 10) AS day, \
           COALESCE(SUM(CASE WHEN amount > 0 THEN amount END), 0), \
           COALESCE(SUM(CASE WHEN amount < 0 THEN amount END), 0), \
           COALESCE(SUM(amount), 0) \
         FROM wallet_journal WHERE character_id = ?1 AND date >= ?2 \
         GROUP BY day ORDER BY day",
    )?;
    let rows = stmt.query_map(params![character_id, since], |row| {
        Ok(WalletDayRow {
            day: row.get(0)?,
            income: row.get(1)?,
            expense: row.get(2)?,
            net: row.get(3)?,
        })
    })?;
    let mut out = Vec::new();
    for row in rows {
        out.push(row?);
    }
    Ok(out)
}

/// Journal totals by `ref_type` over the last `days` days, largest
/// absolute movement first (wallet analytics summary).
pub fn wallet_ref_type_totals(
    conn: &rusqlite::Connection,
    character_id: i64,
    days: i64,
) -> AppResult<Vec<RefTypeTotalRow>> {
    tracing::debug!(
        "[WALLET] wallet_ref_type_totals character_id={} days={}",
        character_id,
        days
    );
    let since = cutoff_day(days.max(0));
    let mut stmt = conn.prepare(
        "SELECT ref_type, COALESCE(SUM(amount), 0), COUNT(*) FROM wallet_journal \
         WHERE character_id = ?1 AND date >= ?2 GROUP BY ref_type \
         ORDER BY ABS(SUM(amount)) DESC",
    )?;
    let rows = stmt.query_map(params![character_id, since], |row| {
        Ok(RefTypeTotalRow {
            ref_type: row.get(0)?,
            total: row.get(1)?,
            entries: row.get(2)?,
        })
    })?;
    let mut out = Vec::new();
    for row in rows {
        out.push(row?);
    }
    Ok(out)
}

pub fn upsert_transactions(
    conn: &rusqlite::Connection,
    rows: &[WalletTransactionRow],
) -> AppResult<()> {
    tracing::debug!("[WALLET] upsert_transactions count={}", rows.len());
    let tx = conn.unchecked_transaction()?;
    {
        let mut stmt = tx.prepare(
            "INSERT INTO wallet_transactions \
             (transaction_id, character_id, journal_ref_id, date, type_id, quantity, \
              unit_price, is_buy, is_personal, client_id, location_id) \
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11) \
             ON CONFLICT(transaction_id) DO UPDATE SET \
               character_id=excluded.character_id, \
               journal_ref_id=excluded.journal_ref_id, date=excluded.date, \
               type_id=excluded.type_id, quantity=excluded.quantity, \
               unit_price=excluded.unit_price, is_buy=excluded.is_buy, \
               is_personal=excluded.is_personal, client_id=excluded.client_id, \
               location_id=excluded.location_id",
        )?;
        for row in rows {
            stmt.execute(params![
                row.transaction_id,
                row.character_id,
                row.journal_ref_id,
                row.date,
                row.type_id,
                row.quantity,
                row.unit_price,
                row.is_buy as i64,
                row.is_personal as i64,
                row.client_id,
                row.location_id
            ])?;
        }
    }
    tx.commit()?;
    Ok(())
}

/// Market transactions for one character, newest first.
pub fn list_transactions(
    conn: &rusqlite::Connection,
    character_id: i64,
) -> AppResult<Vec<WalletTransactionRow>> {
    tracing::debug!("[WALLET] list_transactions character_id={}", character_id);
    let mut stmt = conn.prepare(
        "SELECT transaction_id, character_id, journal_ref_id, date, type_id, quantity, \
         unit_price, is_buy, is_personal, client_id, location_id \
         FROM wallet_transactions WHERE character_id = ?1 \
         ORDER BY date DESC, transaction_id DESC",
    )?;
    let rows = stmt.query_map(params![character_id], |row| {
        let is_buy: i64 = row.get(7)?;
        let is_personal: i64 = row.get(8)?;
        Ok(WalletTransactionRow {
            transaction_id: row.get(0)?,
            character_id: row.get(1)?,
            journal_ref_id: row.get(2)?,
            date: row.get(3)?,
            type_id: row.get(4)?,
            quantity: row.get(5)?,
            unit_price: row.get(6)?,
            is_buy: is_buy != 0,
            is_personal: is_personal != 0,
            client_id: row.get(9)?,
            location_id: row.get(10)?,
        })
    })?;
    let mut out = Vec::new();
    for row in rows {
        out.push(row?);
    }
    Ok(out)
}

pub fn replace_loyalty(
    conn: &rusqlite::Connection,
    character_id: i64,
    rows: &[LoyaltyRow],
) -> AppResult<()> {
    tracing::debug!(
        "[WALLET] replace_loyalty character_id={} count={}",
        character_id,
        rows.len()
    );
    let tx = conn.unchecked_transaction()?;
    tx.execute(
        "DELETE FROM loyalty_points WHERE character_id = ?1",
        params![character_id],
    )?;
    {
        let mut stmt = tx.prepare(
            "INSERT INTO loyalty_points (character_id, corporation_id, loyalty_points) \
             VALUES (?1, ?2, ?3)",
        )?;
        for row in rows {
            stmt.execute(params![
                character_id,
                row.corporation_id,
                row.loyalty_points
            ])?;
        }
    }
    tx.commit()?;
    Ok(())
}

pub fn list_loyalty(conn: &rusqlite::Connection, character_id: i64) -> AppResult<Vec<LoyaltyRow>> {
    tracing::debug!("[WALLET] list_loyalty character_id={}", character_id);
    let mut stmt = conn.prepare(
        "SELECT character_id, corporation_id, loyalty_points FROM loyalty_points \
         WHERE character_id = ?1 ORDER BY loyalty_points DESC",
    )?;
    let rows = stmt.query_map(params![character_id], |row| {
        Ok(LoyaltyRow {
            character_id: row.get(0)?,
            corporation_id: row.get(1)?,
            loyalty_points: row.get(2)?,
        })
    })?;
    let mut out = Vec::new();
    for row in rows {
        out.push(row?);
    }
    Ok(out)
}

// ---------------------------------------------------------------------------
// Universe names (persistent ID -> name cache)
// ---------------------------------------------------------------------------

pub fn upsert_universe_names(
    conn: &rusqlite::Connection,
    rows: &[UniverseNameRow],
) -> AppResult<()> {
    tracing::debug!("[DB] upsert_universe_names count={}", rows.len());
    let tx = conn.unchecked_transaction()?;
    {
        let mut stmt = tx.prepare(
            "INSERT INTO universe_names (id, name, category) VALUES (?1, ?2, ?3) \
             ON CONFLICT(id) DO UPDATE SET name=excluded.name, category=excluded.category",
        )?;
        for row in rows {
            // Never persist an empty name: it would render as a blank cell
            // instead of the Unknown fallback.
            if row.name.is_empty() {
                continue;
            }
            stmt.execute(params![row.id, row.name, row.category])?;
        }
    }
    tx.commit()?;
    Ok(())
}

pub fn get_universe_name(
    conn: &rusqlite::Connection,
    id: i64,
) -> AppResult<Option<UniverseNameRow>> {
    tracing::debug!("[DB] get_universe_name id={}", id);
    let row = conn
        .query_row(
            "SELECT id, name, category FROM universe_names WHERE id = ?1",
            params![id],
            |r| {
                Ok(UniverseNameRow {
                    id: r.get(0)?,
                    name: r.get(1)?,
                    category: r.get(2)?,
                })
            },
        )
        .optional()?;
    Ok(row)
}

/// Batch lookup for the name resolver: returns only the ids that are
/// already persisted, in one query. Missing ids are simply absent.
pub fn get_universe_names(
    conn: &rusqlite::Connection,
    ids: &[i64],
) -> AppResult<Vec<UniverseNameRow>> {
    tracing::debug!("[DB] get_universe_names count={}", ids.len());
    if ids.is_empty() {
        return Ok(Vec::new());
    }
    // Chunked to stay far below SQLite's bound-variable limit.
    let mut out = Vec::new();
    for chunk in ids.chunks(500) {
        let placeholders = vec!["?"; chunk.len()].join(",");
        let sql =
            format!("SELECT id, name, category FROM universe_names WHERE id IN ({placeholders})");
        let mut stmt = conn.prepare(&sql)?;
        let rows = stmt.query_map(rusqlite::params_from_iter(chunk.iter()), |r| {
            Ok(UniverseNameRow {
                id: r.get(0)?,
                name: r.get(1)?,
                category: r.get(2)?,
            })
        })?;
        for row in rows {
            out.push(row?);
        }
    }
    tracing::debug!(
        "[DB] get_universe_names hits={} requested={}",
        out.len(),
        ids.len()
    );
    Ok(out)
}

/// Every persisted name (resolver hydration at startup).
pub fn list_universe_names(conn: &rusqlite::Connection) -> AppResult<Vec<UniverseNameRow>> {
    tracing::debug!("[DB] list_universe_names entry");
    let mut stmt = conn.prepare("SELECT id, name, category FROM universe_names")?;
    let rows = stmt.query_map([], |r| {
        Ok(UniverseNameRow {
            id: r.get(0)?,
            name: r.get(1)?,
            category: r.get(2)?,
        })
    })?;
    let mut out = Vec::new();
    for row in rows {
        out.push(row?);
    }
    Ok(out)
}

/// Case-insensitive substring search over persisted names (UI search box).
pub fn search_universe_names(
    conn: &rusqlite::Connection,
    query: &str,
    limit: i64,
) -> AppResult<Vec<UniverseNameRow>> {
    tracing::debug!("[DB] search_universe_names query_len={}", query.len());
    let pattern = format!("%{query}%");
    let mut stmt = conn.prepare(
        "SELECT id, name, category FROM universe_names \
         WHERE name LIKE ?1 COLLATE NOCASE ORDER BY name LIMIT ?2",
    )?;
    let rows = stmt.query_map(params![pattern, limit], |r| {
        Ok(UniverseNameRow {
            id: r.get(0)?,
            name: r.get(1)?,
            category: r.get(2)?,
        })
    })?;
    let mut out = Vec::new();
    for row in rows {
        out.push(row?);
    }
    Ok(out)
}

// ---------------------------------------------------------------------------
// Settings
// ---------------------------------------------------------------------------

pub fn get_setting(conn: &rusqlite::Connection, key: &str) -> AppResult<Option<String>> {
    tracing::debug!("[DB] get_setting key={}", key);
    let value = conn
        .query_row(
            "SELECT value FROM app_settings WHERE key = ?1",
            params![key],
            |r| r.get(0),
        )
        .optional()?;
    Ok(value)
}

pub fn set_setting(conn: &rusqlite::Connection, key: &str, value: &str) -> AppResult<()> {
    // Setting values are never logged: a future setting could hold
    // something sensitive, and the key alone is enough to debug flow.
    tracing::debug!("[DB] set_setting key={}", key);
    conn.execute(
        "INSERT INTO app_settings (key, value) VALUES (?1, ?2) \
         ON CONFLICT(key) DO UPDATE SET value=excluded.value",
        params![key, value],
    )?;
    Ok(())
}

pub fn delete_setting(conn: &rusqlite::Connection, key: &str) -> AppResult<()> {
    tracing::debug!("[DB] delete_setting key={}", key);
    conn.execute("DELETE FROM app_settings WHERE key = ?1", params![key])?;
    Ok(())
}

// ---------------------------------------------------------------------------
// ESI payload cache with expiry
// ---------------------------------------------------------------------------

/// Store a raw ESI payload under `cache_key` for `ttl_secs`. Callers build
/// keys from endpoint + character id (never from tokens).
pub fn cache_put(
    conn: &rusqlite::Connection,
    cache_key: &str,
    payload_json: &str,
    ttl_secs: i64,
) -> AppResult<()> {
    tracing::debug!(
        "[DB] cache_put key={} ttl_secs={} bytes={}",
        cache_key,
        ttl_secs,
        payload_json.len()
    );
    let fetched = now_unix();
    conn.execute(
        "INSERT INTO esi_cache (cache_key, payload_json, fetched_at, expires_at) \
         VALUES (?1, ?2, ?3, ?4) ON CONFLICT(cache_key) DO UPDATE SET \
           payload_json=excluded.payload_json, fetched_at=excluded.fetched_at, \
           expires_at=excluded.expires_at",
        params![cache_key, payload_json, fetched, fetched + ttl_secs.max(0)],
    )?;
    Ok(())
}

/// Cached payload when present and unexpired. An expired row is deleted
/// and reported as a miss, so stale data can never be shown as fresh.
pub fn cache_get(conn: &rusqlite::Connection, cache_key: &str) -> AppResult<Option<String>> {
    tracing::debug!("[DB] cache_get key={}", cache_key);
    let row: Option<(String, i64)> = conn
        .query_row(
            "SELECT payload_json, expires_at FROM esi_cache WHERE cache_key = ?1",
            params![cache_key],
            |r| Ok((r.get(0)?, r.get(1)?)),
        )
        .optional()?;
    match row {
        None => Ok(None),
        Some((payload, expires_at)) => {
            if expires_at > now_unix() {
                Ok(Some(payload))
            } else {
                tracing::debug!("[DB] cache_get expired key={}", cache_key);
                conn.execute(
                    "DELETE FROM esi_cache WHERE cache_key = ?1",
                    params![cache_key],
                )?;
                Ok(None)
            }
        }
    }
}

/// Seconds until `cache_key` expires (negative/None when absent or stale).
pub fn cache_expires_in(conn: &rusqlite::Connection, cache_key: &str) -> AppResult<Option<i64>> {
    tracing::debug!("[DB] cache_expires_in key={}", cache_key);
    let expires: Option<i64> = conn
        .query_row(
            "SELECT expires_at FROM esi_cache WHERE cache_key = ?1",
            params![cache_key],
            |r| r.get(0),
        )
        .optional()?;
    Ok(expires.map(|e| e - now_unix()))
}

/// Delete every expired payload; returns how many rows were removed.
pub fn cache_prune_expired(conn: &rusqlite::Connection) -> AppResult<usize> {
    tracing::debug!("[DB] cache_prune_expired entry");
    let removed = conn.execute(
        "DELETE FROM esi_cache WHERE expires_at <= ?1",
        params![now_unix()],
    )?;
    tracing::debug!("[DB] cache_prune_expired removed={}", removed);
    Ok(removed)
}

// ---------------------------------------------------------------------------
// Token metadata (never token values)
// ---------------------------------------------------------------------------

pub fn set_token_meta(conn: &rusqlite::Connection, row: &TokenMetaRow) -> AppResult<()> {
    // Scopes are not secrets, but keep the log to ids and counts anyway.
    tracing::debug!(
        "[AUTH] set_token_meta character_id={} scope_count={}",
        row.character_id,
        row.scopes.split_whitespace().count()
    );
    conn.execute(
        "INSERT INTO token_meta (character_id, scopes, expires_at, updated_at) \
         VALUES (?1, ?2, ?3, ?4) ON CONFLICT(character_id) DO UPDATE SET \
           scopes=excluded.scopes, expires_at=excluded.expires_at, \
           updated_at=excluded.updated_at",
        params![row.character_id, row.scopes, row.expires_at, now_iso()],
    )?;
    Ok(())
}

pub fn get_token_meta(
    conn: &rusqlite::Connection,
    character_id: i64,
) -> AppResult<Option<TokenMetaRow>> {
    tracing::debug!("[AUTH] get_token_meta character_id={}", character_id);
    let row = conn
        .query_row(
            "SELECT character_id, scopes, expires_at FROM token_meta \
             WHERE character_id = ?1",
            params![character_id],
            |r| {
                Ok(TokenMetaRow {
                    character_id: r.get(0)?,
                    scopes: r.get(1)?,
                    expires_at: r.get(2)?,
                })
            },
        )
        .optional()?;
    Ok(row)
}

pub fn delete_token_meta(conn: &rusqlite::Connection, character_id: i64) -> AppResult<()> {
    tracing::debug!("[AUTH] delete_token_meta character_id={}", character_id);
    conn.execute(
        "DELETE FROM token_meta WHERE character_id = ?1",
        params![character_id],
    )?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::storage::db;

    fn char_row(id: i64, name: &str, active: bool) -> CharacterRow {
        CharacterRow {
            character_id: id,
            name: name.to_string(),
            corporation_id: 1000166,
            alliance_id: Some(99000001),
            is_active: active,
        }
    }

    #[test]
    fn character_roundtrip_upsert_and_active_switch() {
        let conn = db::open_in_memory().expect("db opens");
        upsert_character(&conn, &char_row(2, "Beta", false)).expect("upsert beta");
        upsert_character(&conn, &char_row(1, "Alpha", true)).expect("upsert alpha");
        let listed = list_characters(&conn).expect("list");
        assert_eq!(listed.len(), 2);
        assert_eq!(listed[0].name, "Alpha");
        assert_eq!(
            active_character(&conn)
                .expect("active")
                .expect("one active")
                .character_id,
            1
        );
        set_active_character(&conn, 2).expect("switch active");
        assert_eq!(
            active_character(&conn)
                .expect("active")
                .expect("one active")
                .character_id,
            2
        );
        // Upsert updates in place instead of duplicating.
        upsert_character(&conn, &char_row(1, "Alpha Renamed", false)).expect("re-upsert");
        assert_eq!(character_count(&conn).expect("count"), 2);
        assert_eq!(
            get_character(&conn, 1).expect("get").expect("row").name,
            "Alpha Renamed"
        );
    }

    #[test]
    fn delete_character_cascades_to_child_tables() {
        let conn = db::open_in_memory().expect("db opens");
        upsert_character(&conn, &char_row(7, "Doomed", true)).expect("upsert");
        set_wallet_balance(
            &conn,
            &WalletBalanceRow {
                character_id: 7,
                balance: 42.0,
            },
        )
        .expect("balance");
        set_token_meta(
            &conn,
            &TokenMetaRow {
                character_id: 7,
                scopes: "publicData".to_string(),
                expires_at: 123,
            },
        )
        .expect("token meta");
        assert!(delete_character(&conn, 7).expect("delete"));
        assert!(!delete_character(&conn, 7).expect("second delete"));
        assert_eq!(wallet_balance(&conn, 7).expect("balance read"), None);
        assert_eq!(get_token_meta(&conn, 7).expect("meta read"), None);
    }

    #[test]
    fn skill_queue_replace_is_atomic_and_ordered() {
        let conn = db::open_in_memory().expect("db opens");
        let rows = vec![
            SkillQueueRow {
                character_id: 1,
                queue_position: 1,
                skill_id: 3301,
                finished_level: 4,
                start_date: None,
                finish_date: Some("2026-11-20T00:00:00Z".to_string()),
            },
            SkillQueueRow {
                character_id: 1,
                queue_position: 0,
                skill_id: 3300,
                finished_level: 5,
                start_date: Some("2026-11-15T00:00:00Z".to_string()),
                finish_date: Some("2026-11-18T00:00:00Z".to_string()),
            },
        ];
        replace_skill_queue(&conn, 1, &rows).expect("replace");
        let listed = list_skill_queue(&conn, 1).expect("list");
        assert_eq!(listed.len(), 2);
        assert_eq!(listed[0].skill_id, 3300);
        replace_skill_queue(&conn, 1, &[]).expect("replace empty");
        assert!(list_skill_queue(&conn, 1).expect("list").is_empty());
    }

    #[test]
    fn wallet_aggregates_match_seeded_rows() {
        let conn = db::open_in_memory().expect("db opens");
        let today = chrono::Utc::now().format("%Y-%m-%dT%H:%M:%SZ").to_string();
        let journal = vec![
            WalletJournalRow {
                id: 1,
                character_id: 9,
                amount: 100.0,
                balance: 100.0,
                date: today.clone(),
                ref_type: "bounty".to_string(),
                ..Default::default()
            },
            WalletJournalRow {
                id: 2,
                character_id: 9,
                amount: -30.0,
                balance: 70.0,
                date: today.clone(),
                ref_type: "market".to_string(),
                ..Default::default()
            },
        ];
        upsert_journal(&conn, &journal).expect("journal upsert");
        assert_eq!(max_journal_id(&conn, 9).expect("max"), Some(2));
        let trend = wallet_daily_trend(&conn, 9, 30).expect("trend");
        assert_eq!(trend.len(), 1);
        assert_eq!(trend[0].income, 100.0);
        assert_eq!(trend[0].expense, -30.0);
        assert_eq!(trend[0].net, 70.0);
        let totals = wallet_ref_type_totals(&conn, 9, 30).expect("totals");
        assert_eq!(totals[0].ref_type, "bounty");
        assert_eq!(totals[0].total, 100.0);
        // Re-upserting the same journal id updates rather than duplicates.
        upsert_journal(&conn, &journal).expect("journal re-upsert");
        assert_eq!(list_journal(&conn, 9).expect("list").len(), 2);
    }

    #[test]
    fn universe_names_batch_and_search() {
        let conn = db::open_in_memory().expect("db opens");
        upsert_universe_names(
            &conn,
            &[
                UniverseNameRow {
                    id: 34,
                    name: "Tritanium".to_string(),
                    category: "inventory_type".to_string(),
                },
                UniverseNameRow {
                    id: 60003760,
                    name: "Jita IV - Moon 4".to_string(),
                    category: "station".to_string(),
                },
                UniverseNameRow {
                    id: 99,
                    name: String::new(),
                    category: "inventory_type".to_string(),
                },
            ],
        )
        .expect("upsert names");
        let hits = get_universe_names(&conn, &[34, 42, 60003760]).expect("batch");
        assert_eq!(hits.len(), 2);
        // Empty names are never persisted.
        assert_eq!(get_universe_name(&conn, 99).expect("get"), None);
        let found = search_universe_names(&conn, "jita", 10).expect("search");
        assert_eq!(found.len(), 1);
        assert_eq!(found[0].id, 60003760);
    }

    #[test]
    fn esi_cache_expiry_and_prune() {
        let conn = db::open_in_memory().expect("db opens");
        cache_put(&conn, "skills:1", "{}", 3600).expect("put fresh");
        cache_put(&conn, "wallet:1", "[]", 0).expect("put already-stale");
        assert_eq!(
            cache_get(&conn, "skills:1").expect("get"),
            Some("{}".to_string())
        );
        assert_eq!(cache_get(&conn, "wallet:1").expect("get stale"), None);
        cache_put(&conn, "wallet:1", "[]", 0).expect("put stale again");
        assert_eq!(cache_prune_expired(&conn).expect("prune"), 1);
        assert!(
            cache_expires_in(&conn, "skills:1")
                .expect("ttl")
                .expect("present")
                > 0
        );
    }

    #[test]
    fn settings_roundtrip() {
        let conn = db::open_in_memory().expect("db opens");
        assert_eq!(get_setting(&conn, "startup_view").expect("get"), None);
        set_setting(&conn, "startup_view", "wallet").expect("set");
        set_setting(&conn, "startup_view", "skills").expect("overwrite");
        assert_eq!(
            get_setting(&conn, "startup_view").expect("get"),
            Some("skills".to_string())
        );
        delete_setting(&conn, "startup_view").expect("delete");
        assert_eq!(get_setting(&conn, "startup_view").expect("get"), None);
    }
}
