//! Offline demo data: bundled invented fixtures behind the same model and
//! repository types the live ESI path uses (`crate::esi::models`,
//! `crate::storage::repositories`, `crate::app::state`). No EVE
//! credentials, no network, and no real player data are involved: every
//! character, corporation, and ISK figure in `assets/demo/*.json` is
//! fictional.

use std::collections::{HashMap, HashSet};

use chrono::{DateTime, Utc};

use crate::app::state::{
    AppState, AssetsData, CharacterSummary, LoadState, SkillsData, WalletData,
};
use crate::error::{AppError, AppResult};
use crate::esi::models::*;
use crate::names::resolver::NameResolver;
use crate::names::sde::Sde;
use crate::storage::repositories::{
    self, CharacterRow, CharacterSkillRow, LoyaltyRow, SkillQueueRow, UniverseNameRow,
    WalletBalanceRow, WalletJournalRow, WalletTransactionRow,
};

pub const DEMO_CHARACTERS_JSON: &str = include_str!("../../assets/demo/characters.json");
pub const DEMO_SKILLQUEUE_JSON: &str = include_str!("../../assets/demo/skillqueue.json");
pub const DEMO_WALLET_JSON: &str = include_str!("../../assets/demo/wallet.json");
pub const DEMO_NAMES_JSON: &str = include_str!("../../assets/demo/names.json");
pub const DEMO_ASSETS_JSON: &str = include_str!("../../assets/demo/assets.json");

/// Command-line flag that selects demo mode (design section 1).
pub const DEMO_FLAG: &str = "--demo";
/// Environment variable that selects demo mode when set to a truthy value
/// (`1`, `true`, `yes`, `on`, case-insensitive).
pub const DEMO_ENV_VAR: &str = "MIMIR_DEMO";

/// Demo mode was requested via CLI flag or environment variable. Pure so
/// the selection rule is unit-testable without touching process state.
pub fn is_demo_requested(args: &[String], env_value: Option<&str>) -> bool {
    let by_flag = args.iter().any(|a| a == DEMO_FLAG);
    let by_env = env_value
        .map(|v| {
            matches!(
                v.trim().to_ascii_lowercase().as_str(),
                "1" | "true" | "yes" | "on"
            )
        })
        .unwrap_or(false);
    tracing::debug!("[DEMO] is_demo_requested flag={} env={}", by_flag, by_env);
    by_flag || by_env
}

/// Demo selection from this process's arguments and environment. The
/// integrator wires this into `src/main.rs` in place of the scaffold's
/// flag-only check.
pub fn demo_requested_from_process() -> bool {
    let args: Vec<String> = std::env::args().collect();
    let env = std::env::var(DEMO_ENV_VAR).ok();
    let requested = is_demo_requested(&args, env.as_deref());
    tracing::info!("[DEMO] demo_requested_from_process={}", requested);
    requested
}

#[derive(Debug, Clone, Default, serde::Deserialize)]
pub struct DemoCharacter {
    #[serde(default)]
    pub character_id: i64,
    #[serde(default)]
    pub name: String,
    #[serde(default)]
    pub corporation_id: i64,
    #[serde(default)]
    pub alliance_id: Option<i64>,
    #[serde(default)]
    pub security_status: f64,
}

/// Everything one demo character shows in the Phase-1 views.
#[derive(Debug, Clone, Default)]
pub struct DemoCharacterData {
    pub skills: CharacterSkills,
    pub queue: Vec<SkillQueueItem>,
    pub balance: f64,
    pub journal: Vec<WalletJournalItem>,
    pub transactions: Vec<WalletTransactionItem>,
    pub loyalty: Vec<LoyaltyPointItem>,
    pub assets: Vec<AssetItem>,
    pub custom_names: Vec<AssetName>,
}

#[derive(Debug, Clone, Default)]
pub struct DemoBundle {
    pub characters: Vec<DemoCharacter>,
    /// Per-character view data keyed by character id.
    pub data: HashMap<i64, DemoCharacterData>,
}

impl DemoBundle {
    pub fn character_data(&self, character_id: i64) -> Option<&DemoCharacterData> {
        self.data.get(&character_id)
    }

    pub fn first_character_id(&self) -> Option<i64> {
        self.characters.first().map(|c| c.character_id)
    }
}

#[derive(serde::Deserialize)]
struct CharactersFile {
    #[serde(default)]
    characters: Vec<DemoCharacter>,
}

#[derive(serde::Deserialize, Default)]
struct SkillFileEntry {
    #[serde(default)]
    skills: CharacterSkills,
    #[serde(default)]
    queue: Vec<SkillQueueItem>,
}

#[derive(serde::Deserialize, Default)]
struct WalletFileEntry {
    #[serde(default)]
    balance: f64,
    #[serde(default)]
    journal: Vec<WalletJournalItem>,
    #[serde(default)]
    transactions: Vec<WalletTransactionItem>,
    #[serde(default)]
    loyalty: Vec<LoyaltyPointItem>,
}

#[derive(serde::Deserialize, Default)]
struct AssetsFileEntry {
    #[serde(default)]
    assets: Vec<AssetItem>,
    #[serde(default)]
    custom_names: Vec<AssetName>,
}

fn parse_character_key(key: &str) -> AppResult<i64> {
    key.parse::<i64>().map_err(|_| {
        AppError::Message(format!(
            "[DEMO] demo fixture key is not a character id: {key}"
        ))
    })
}

/// Parse a bundle from explicit JSON texts (the bundled constants in
/// production, small literals in tests so error paths are reachable).
/// Kept with its original meaning — a bundle with no assets — so existing
/// three-argument callers and fixtures keep working unchanged.
pub fn load_demo_bundle_from(
    characters_json: &str,
    skillqueue_json: &str,
    wallet_json: &str,
) -> AppResult<DemoBundle> {
    load_demo_bundle_with_assets(characters_json, skillqueue_json, wallet_json, "{}")
}

/// Parse a bundle including the per-character assets file.
pub fn load_demo_bundle_with_assets(
    characters_json: &str,
    skillqueue_json: &str,
    wallet_json: &str,
    assets_json: &str,
) -> AppResult<DemoBundle> {
    tracing::debug!("[DEMO] parsing demo bundle");
    let characters: CharactersFile = serde_json::from_str(characters_json)?;
    let skills_by_id: HashMap<String, SkillFileEntry> = serde_json::from_str(skillqueue_json)?;
    let wallet_by_id: HashMap<String, WalletFileEntry> = serde_json::from_str(wallet_json)?;
    let assets_by_id: HashMap<String, AssetsFileEntry> = serde_json::from_str(assets_json)?;

    let mut data: HashMap<i64, DemoCharacterData> = HashMap::new();
    for (key, entry) in skills_by_id {
        let id = parse_character_key(&key)?;
        let slot = data.entry(id).or_default();
        slot.skills = entry.skills;
        slot.queue = entry.queue;
        slot.queue.sort_by_key(|q| q.queue_position);
    }
    for (key, entry) in wallet_by_id {
        let id = parse_character_key(&key)?;
        let slot = data.entry(id).or_default();
        slot.balance = entry.balance;
        slot.journal = entry.journal;
        slot.transactions = entry.transactions;
        slot.loyalty = entry.loyalty;
    }
    for (key, entry) in assets_by_id {
        let id = parse_character_key(&key)?;
        tracing::debug!(
            "[DEMO] character_id={} assets={} custom_names={}",
            id,
            entry.assets.len(),
            entry.custom_names.len()
        );
        let slot = data.entry(id).or_default();
        slot.assets = entry.assets;
        slot.custom_names = entry.custom_names;
    }

    let bundle = DemoBundle {
        characters: characters.characters,
        data,
    };
    validate_bundle(&bundle)?;
    tracing::info!(
        "[DEMO] bundle loaded characters={} with_data={}",
        bundle.characters.len(),
        bundle.data.len()
    );
    Ok(bundle)
}

/// Load the bundled demo JSON files into typed structures.
pub fn load_demo_bundle() -> AppResult<DemoBundle> {
    tracing::debug!("[DEMO] loading bundled demo fixtures");
    load_demo_bundle_with_assets(
        DEMO_CHARACTERS_JSON,
        DEMO_SKILLQUEUE_JSON,
        DEMO_WALLET_JSON,
        DEMO_ASSETS_JSON,
    )
}

/// Structural guarantees the views rely on: at least two fictional
/// characters, unique ids, data for every character, contiguous queue
/// positions, parseable queue dates, and journal ids unique across the
/// whole bundle (the `wallet_journal` primary key is the journal id).
pub fn validate_bundle(bundle: &DemoBundle) -> AppResult<()> {
    tracing::debug!(
        "[DEMO] validating bundle characters={}",
        bundle.characters.len()
    );
    let fail = |msg: String| AppError::Message(format!("[DEMO] invalid demo bundle: {msg}"));
    if bundle.characters.len() < 2 {
        return Err(fail("at least two demo characters are required".into()));
    }
    let mut character_ids = HashSet::new();
    let mut journal_ids = HashSet::new();
    for character in &bundle.characters {
        if !character_ids.insert(character.character_id) {
            return Err(fail(format!(
                "duplicate character_id {}",
                character.character_id
            )));
        }
        if character.name.trim().is_empty() {
            return Err(fail(format!(
                "character {} has an empty name",
                character.character_id
            )));
        }
        let Some(per) = bundle.data.get(&character.character_id) else {
            return Err(fail(format!(
                "character {} has no skill/wallet data",
                character.character_id
            )));
        };
        if per.queue.is_empty() {
            return Err(fail(format!(
                "character {} has an empty skill queue",
                character.character_id
            )));
        }
        for (expected, item) in per.queue.iter().enumerate() {
            if item.queue_position != expected as i32 {
                return Err(fail(format!(
                    "character {} queue_position {} expected {}",
                    character.character_id, item.queue_position, expected
                )));
            }
            for raw in [&item.start_date, &item.finish_date].into_iter().flatten() {
                if parse_esi_datetime(raw).is_none() {
                    return Err(fail(format!(
                        "character {} queue date does not parse: {raw}",
                        character.character_id
                    )));
                }
            }
        }
        for entry in &per.journal {
            if !journal_ids.insert(entry.id) {
                return Err(fail(format!("duplicate journal id {}", entry.id)));
            }
        }
        // Assets are optional (old literals carry none); validate only
        // what is present: item IDs unique within the character.
        let mut asset_item_ids = HashSet::new();
        for asset in &per.assets {
            if !asset_item_ids.insert(asset.item_id) {
                return Err(fail(format!(
                    "character {} duplicate asset item_id {}",
                    character.character_id, asset.item_id
                )));
            }
        }
    }
    tracing::debug!("[DEMO] bundle validation ok");
    Ok(())
}

/// Pre-resolved universe names for demo rows.
pub fn load_demo_names() -> AppResult<Vec<UniverseName>> {
    tracing::debug!("[DEMO] loading demo universe names");
    let names: Vec<UniverseName> = serde_json::from_str(DEMO_NAMES_JSON)?;
    tracing::info!("[DEMO] demo names loaded count={}", names.len());
    Ok(names)
}

/// Insert every bundled demo name into a resolver; returns how many.
pub fn seed_resolver(resolver: &mut NameResolver) -> AppResult<usize> {
    let names = load_demo_names()?;
    let count = names.len();
    for name in names {
        resolver.insert(name.id, name.name);
    }
    tracing::info!("[DEMO] resolver seeded names={}", count);
    Ok(count)
}

/// A `NameResolver` preloaded with the demo name table. Unknown ids fall
/// back to `Unknown Item` / `Unknown Location`, never a raw numeric ID.
pub fn demo_resolver() -> AppResult<NameResolver> {
    tracing::debug!("[DEMO] building demo name resolver");
    let mut resolver = NameResolver::new();
    seed_resolver(&mut resolver)?;
    Ok(resolver)
}

// ---------------------------------------------------------------------------
// Queue finish math (pure; the same dates the live ESI queue carries)
// ---------------------------------------------------------------------------

/// Parse an ESI ISO-8601 date (`2026-11-20T12:00:00Z`).
pub fn parse_esi_datetime(value: &str) -> Option<DateTime<Utc>> {
    DateTime::parse_from_rfc3339(value)
        .ok()
        .map(|dt| dt.with_timezone(&Utc))
}

/// Seconds from `now` until this queue item finishes (negative when it
/// already finished); `None` for paused entries without a finish date.
pub fn seconds_until_finish(item: &SkillQueueItem, now: DateTime<Utc>) -> Option<i64> {
    let finish = parse_esi_datetime(item.finish_date.as_deref()?)?;
    Some((finish - now).num_seconds())
}

/// The item training at `now`: started, not yet finished, lowest queue
/// position wins if hand-made data overlaps.
pub fn currently_training(queue: &[SkillQueueItem], now: DateTime<Utc>) -> Option<&SkillQueueItem> {
    let mut sorted: Vec<&SkillQueueItem> = queue.iter().collect();
    sorted.sort_by_key(|q| q.queue_position);
    let found = sorted.into_iter().find(|item| {
        let started = item
            .start_date
            .as_deref()
            .and_then(parse_esi_datetime)
            .map(|start| start <= now)
            .unwrap_or(false);
        let unfinished = seconds_until_finish(item, now)
            .map(|s| s > 0)
            .unwrap_or(false);
        started && unfinished
    });
    tracing::debug!(
        "[DEMO] currently_training found={}",
        found.map(|i| i.skill_id).unwrap_or(0)
    );
    found
}

/// When the whole queue finishes: the latest finish date present.
pub fn queue_end(queue: &[SkillQueueItem]) -> Option<DateTime<Utc>> {
    queue
        .iter()
        .filter_map(|i| i.finish_date.as_deref().and_then(parse_esi_datetime))
        .max()
}

/// Elapsed fraction of one queue item at `now`, clamped to `0.0..=1.0`;
/// `None` when either date is missing or the span is empty.
pub fn training_progress(item: &SkillQueueItem, now: DateTime<Utc>) -> Option<f64> {
    let start = parse_esi_datetime(item.start_date.as_deref()?)?;
    let finish = parse_esi_datetime(item.finish_date.as_deref()?)?;
    let span = (finish - start).num_seconds();
    if span <= 0 {
        return None;
    }
    let elapsed = (now - start).num_seconds();
    Some((elapsed as f64 / span as f64).clamp(0.0, 1.0))
}

// ---------------------------------------------------------------------------
// Wallet aggregation (pure; mirrors the SQL aggregates' meaning in memory)
// ---------------------------------------------------------------------------

#[derive(Debug, Clone, Copy, Default, PartialEq)]
pub struct WalletSummary {
    pub income: f64,
    pub expense: f64,
    pub net: f64,
    pub entries: usize,
}

/// Income (sum of positive amounts), expense (sum of negative amounts,
/// kept negative), and net over a journal slice.
pub fn summarize_wallet(journal: &[WalletJournalItem]) -> WalletSummary {
    let mut summary = WalletSummary {
        entries: journal.len(),
        ..WalletSummary::default()
    };
    for entry in journal {
        if entry.amount >= 0.0 {
            summary.income += entry.amount;
        } else {
            summary.expense += entry.amount;
        }
        summary.net += entry.amount;
    }
    tracing::debug!(
        "[DEMO] summarize_wallet entries={} net={:.2}",
        summary.entries,
        summary.net
    );
    summary
}

/// Net ISK per `ref_type`, largest absolute movement first (ties broken by
/// ref_type name so the order is deterministic).
pub fn net_by_ref_type(journal: &[WalletJournalItem]) -> Vec<(String, f64)> {
    let mut totals: HashMap<String, f64> = HashMap::new();
    for entry in journal {
        *totals.entry(entry.ref_type.clone()).or_default() += entry.amount;
    }
    let mut rows: Vec<(String, f64)> = totals.into_iter().collect();
    rows.sort_by(|a, b| {
        b.1.abs()
            .partial_cmp(&a.1.abs())
            .unwrap_or(std::cmp::Ordering::Equal)
            .then_with(|| a.0.cmp(&b.0))
    });
    tracing::debug!("[DEMO] net_by_ref_type groups={}", rows.len());
    rows
}

/// Journal entries dated within `days` days before `now` (inclusive).
/// Entries with unparseable dates are excluded.
pub fn journal_since(
    journal: &[WalletJournalItem],
    now: DateTime<Utc>,
    days: i64,
) -> Vec<&WalletJournalItem> {
    let cutoff = now - chrono::Duration::days(days);
    journal
        .iter()
        .filter(|entry| {
            parse_esi_datetime(&entry.date)
                .map(|date| date >= cutoff && date <= now)
                .unwrap_or(false)
        })
        .collect()
}

// ---------------------------------------------------------------------------
// Seeding: UI state and (through F2 repositories only) the database
// ---------------------------------------------------------------------------

/// Show one demo character in the per-view load states. The integrator
/// calls this when the user switches character in demo mode.
pub fn apply_character(state: &mut AppState, bundle: &DemoBundle, character_id: i64) {
    tracing::info!("[DEMO] apply_character character_id={}", character_id);
    let Some(character) = bundle
        .characters
        .iter()
        .find(|c| c.character_id == character_id)
    else {
        tracing::warn!(
            "[DEMO] apply_character unknown character_id={}",
            character_id
        );
        return;
    };
    let Some(per) = bundle.data.get(&character_id) else {
        tracing::warn!(
            "[DEMO] apply_character no data character_id={}",
            character_id
        );
        return;
    };
    let info = CharacterPublicInfo {
        name: character.name.clone(),
        corporation_id: character.corporation_id,
        alliance_id: character.alliance_id,
        security_status: character.security_status,
        ..Default::default()
    };
    state.character_detail = LoadState::Ready(info.clone());
    state.dashboard = LoadState::Ready(info);
    state.skills = LoadState::Ready(SkillsData {
        skills: per.skills.clone(),
        queue: per.queue.clone(),
    });
    state.wallet = LoadState::Ready(WalletData {
        balance: per.balance,
        journal: per.journal.clone(),
        transactions: per.transactions.clone(),
        loyalty: per.loyalty.clone(),
    });
    // Same filter as the live path: ESI's "None" placeholder and empty
    // names never reach AssetsData.
    let custom_names: HashMap<i64, String> = per
        .custom_names
        .iter()
        .filter(|n| !n.name.trim().is_empty() && n.name.trim() != "None")
        .map(|n| (n.item_id, n.name.clone()))
        .collect();
    state.assets = if per.assets.is_empty() {
        LoadState::Empty
    } else {
        LoadState::Ready(AssetsData {
            items: per.assets.clone(),
            custom_names,
        })
    };
    state.assets_needs_reauthorize = false;
}

/// Seed demo content into the UI state: both fictional characters, the
/// first one active, per-character overview summaries with skill names
/// already resolved through the bundled SDE (never raw skill IDs).
pub fn seed_demo_state(state: &mut AppState) {
    tracing::info!("[DEMO] seed_demo_state entry");
    state.demo = true;
    match load_demo_bundle() {
        Ok(bundle) => {
            state.characters = bundle
                .characters
                .iter()
                .map(|c| CharacterRow {
                    character_id: c.character_id,
                    name: c.name.clone(),
                    corporation_id: c.corporation_id,
                    alliance_id: c.alliance_id,
                    is_active: false,
                })
                .collect();

            let sde = Sde::load_bundled();
            if let Err(e) = &sde {
                tracing::warn!("[DEMO] SDE unavailable for summaries: {}", e);
            }
            let now = Utc::now();
            state.summaries.clear();
            for character in &bundle.characters {
                let Some(per) = bundle.data.get(&character.character_id) else {
                    continue;
                };
                let training = currently_training(&per.queue, now).or_else(|| per.queue.first());
                state.summaries.insert(
                    character.character_id,
                    CharacterSummary {
                        balance: Some(per.balance),
                        training_skill_name: match (&sde, training) {
                            (Ok(sde), Some(item)) => Some(sde.skill_name(item.skill_id)),
                            _ => None,
                        },
                        training_finish_date: training.and_then(|item| item.finish_date.clone()),
                        queue_len: Some(per.queue.len()),
                        total_sp: Some(per.skills.total_sp),
                        location_name: None,
                        ship_name: None,
                    },
                );
            }

            if let Some(first_id) = bundle.first_character_id() {
                state.set_active_character(first_id);
                apply_character(state, &bundle, first_id);
            }
            state.status_message = "Demo mode: sample data, no network.".to_string();
            tracing::info!(
                "[DEMO] seed complete characters={} summaries={}",
                state.characters.len(),
                state.summaries.len()
            );
        }
        Err(e) => {
            tracing::error!("[DEMO] seed failed: {}", e);
            state.status_message = format!("Demo data failed to load: {e}");
            state.skills = LoadState::Error(format!("Demo data failed to load: {e}"));
            state.wallet = LoadState::Error(format!("Demo data failed to load: {e}"));
            state.assets = LoadState::Error(format!("Demo data failed to load: {e}"));
        }
    }
}

/// Seed a bundle through the F2 repositories (never raw SQL here, per the
/// design's cross-builder contract). Idempotent: repository upserts and
/// queue/skill replacements make a second seed converge to the same rows.
pub fn seed_bundle_into_db(conn: &rusqlite::Connection, bundle: &DemoBundle) -> AppResult<()> {
    tracing::info!(
        "[DEMO] seed_bundle_into_db characters={}",
        bundle.characters.len()
    );
    let first_id = bundle.first_character_id();
    // Assets are in-memory only in this slice (no table); nothing to persist.
    for character in &bundle.characters {
        repositories::upsert_character(
            conn,
            &CharacterRow {
                character_id: character.character_id,
                name: character.name.clone(),
                corporation_id: character.corporation_id,
                alliance_id: character.alliance_id,
                is_active: Some(character.character_id) == first_id,
            },
        )?;
        let Some(per) = bundle.data.get(&character.character_id) else {
            tracing::warn!(
                "[DEMO] seed skipped data for character_id={}",
                character.character_id
            );
            continue;
        };
        let queue_rows: Vec<SkillQueueRow> = per
            .queue
            .iter()
            .map(|q| SkillQueueRow {
                character_id: character.character_id,
                queue_position: q.queue_position,
                skill_id: q.skill_id,
                finished_level: q.finished_level,
                start_date: q.start_date.clone(),
                finish_date: q.finish_date.clone(),
            })
            .collect();
        repositories::replace_skill_queue(conn, character.character_id, &queue_rows)?;
        let skill_rows: Vec<CharacterSkillRow> = per
            .skills
            .skills
            .iter()
            .map(|s| CharacterSkillRow {
                character_id: character.character_id,
                skill_id: s.skill_id,
                active_skill_level: s.active_skill_level,
                trained_skill_level: s.trained_skill_level,
                skillpoints_in_skill: s.skillpoints_in_skill,
            })
            .collect();
        repositories::replace_character_skills(conn, character.character_id, &skill_rows)?;
        repositories::set_wallet_balance(
            conn,
            &WalletBalanceRow {
                character_id: character.character_id,
                balance: per.balance,
            },
        )?;
        let journal_rows: Vec<WalletJournalRow> = per
            .journal
            .iter()
            .map(|j| WalletJournalRow {
                id: j.id,
                character_id: character.character_id,
                amount: j.amount,
                balance: j.balance,
                date: j.date.clone(),
                description: j.description.clone(),
                ref_type: j.ref_type.clone(),
                first_party_id: j.first_party_id,
                second_party_id: j.second_party_id,
            })
            .collect();
        repositories::upsert_journal(conn, &journal_rows)?;
        let transaction_rows: Vec<WalletTransactionRow> = per
            .transactions
            .iter()
            .map(|t| WalletTransactionRow {
                transaction_id: t.transaction_id,
                character_id: character.character_id,
                journal_ref_id: t.journal_ref_id,
                date: t.date.clone(),
                type_id: t.type_id,
                quantity: t.quantity,
                unit_price: t.unit_price,
                is_buy: t.is_buy,
                is_personal: t.is_personal,
                client_id: t.client_id,
                location_id: t.location_id,
            })
            .collect();
        repositories::upsert_transactions(conn, &transaction_rows)?;
        let loyalty_rows: Vec<LoyaltyRow> = per
            .loyalty
            .iter()
            .map(|l| LoyaltyRow {
                character_id: character.character_id,
                corporation_id: l.corporation_id,
                loyalty_points: l.loyalty_points,
            })
            .collect();
        repositories::replace_loyalty(conn, character.character_id, &loyalty_rows)?;
        tracing::debug!(
            "[DEMO] seeded character_id={} queue={} journal={}",
            character.character_id,
            per.queue.len(),
            per.journal.len()
        );
    }
    let name_rows: Vec<UniverseNameRow> = load_demo_names()?
        .into_iter()
        .map(|n| UniverseNameRow {
            id: n.id,
            name: n.name,
            category: n.category,
        })
        .collect();
    repositories::upsert_universe_names(conn, &name_rows)?;
    tracing::info!("[DEMO] seed_bundle_into_db complete");
    Ok(())
}

/// Load the bundled fixtures and seed them through the F2 repositories.
pub fn seed_into_db(conn: &rusqlite::Connection) -> AppResult<()> {
    tracing::debug!("[DEMO] seed_into_db entry");
    let bundle = load_demo_bundle()?;
    seed_bundle_into_db(conn, &bundle)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn fixed_now() -> DateTime<Utc> {
        parse_esi_datetime("2026-11-15T12:00:00Z").expect("fixed now parses")
    }

    fn item(skill_id: i64, position: i32, start: &str, finish: &str) -> SkillQueueItem {
        SkillQueueItem {
            skill_id,
            queue_position: position,
            finished_level: 5,
            start_date: Some(start.to_string()),
            finish_date: Some(finish.to_string()),
            ..Default::default()
        }
    }

    #[test]
    fn demo_selection_covers_flag_env_and_rejects_other_values() {
        let args = vec!["mimir".to_string()];
        assert!(!is_demo_requested(&args, None));
        assert!(!is_demo_requested(&args, Some("0")));
        assert!(!is_demo_requested(&args, Some("false")));
        assert!(is_demo_requested(&args, Some("1")));
        assert!(is_demo_requested(&args, Some(" TRUE ")));
        let flagged = vec!["mimir".to_string(), "--demo".to_string()];
        assert!(is_demo_requested(&flagged, None));
    }

    #[test]
    fn queue_math_at_a_fixed_instant() {
        let queue = vec![
            item(3300, 0, "2026-11-10T12:00:00Z", "2026-11-20T12:00:00Z"),
            item(3301, 1, "2026-11-20T12:00:00Z", "2026-11-25T12:00:00Z"),
        ];
        let now = fixed_now();
        assert_eq!(
            currently_training(&queue, now).map(|i| i.skill_id),
            Some(3300)
        );
        // Halfway through a 10-day span: 5 days remain, progress is 0.5.
        assert_eq!(seconds_until_finish(&queue[0], now), Some(5 * 24 * 3600));
        let progress = training_progress(&queue[0], now).expect("progress");
        assert!((progress - 0.5).abs() < 1e-9);
        assert_eq!(
            queue_end(&queue),
            parse_esi_datetime("2026-11-25T12:00:00Z")
        );
        // After the queue ends nothing is training and progress clamps.
        let later = parse_esi_datetime("2027-01-01T00:00:00Z").expect("later parses");
        assert!(currently_training(&queue, later).is_none());
        assert_eq!(training_progress(&queue[0], later), Some(1.0));
        // Paused entries (no dates) produce no finish math.
        let paused = SkillQueueItem::default();
        assert_eq!(seconds_until_finish(&paused, now), None);
        assert_eq!(training_progress(&paused, now), None);
    }

    #[test]
    fn wallet_aggregation_and_windows() {
        let journal = vec![
            WalletJournalItem {
                id: 1,
                amount: 100.0,
                date: "2026-11-15T00:00:00Z".into(),
                ref_type: "bounty_prizes".into(),
                ..Default::default()
            },
            WalletJournalItem {
                id: 2,
                amount: -40.0,
                date: "2026-11-10T00:00:00Z".into(),
                ref_type: "market_transaction".into(),
                ..Default::default()
            },
            WalletJournalItem {
                id: 3,
                amount: 50.0,
                date: "2026-01-01T00:00:00Z".into(),
                ref_type: "bounty_prizes".into(),
                ..Default::default()
            },
        ];
        let summary = summarize_wallet(&journal);
        assert_eq!(summary.income, 150.0);
        assert_eq!(summary.expense, -40.0);
        assert_eq!(summary.net, 110.0);
        assert_eq!(summary.entries, 3);
        let by_ref = net_by_ref_type(&journal);
        assert_eq!(by_ref[0], ("bounty_prizes".to_string(), 150.0));
        assert_eq!(by_ref[1], ("market_transaction".to_string(), -40.0));
        assert_eq!(journal_since(&journal, fixed_now(), 7).len(), 2);
        assert_eq!(journal_since(&journal, fixed_now(), 365).len(), 3);
    }

    #[test]
    fn malformed_and_invalid_bundles_are_errors_not_panics() {
        assert!(load_demo_bundle_from("not json", "{}", "{}").is_err());
        // One character only: fails the two-character floor.
        let one = r#"{"characters":[{"character_id":1,"name":"Solo"}]}"#;
        assert!(load_demo_bundle_from(one, "{}", "{}").is_err());
        // Non-numeric character key in the wallet file.
        let two =
            r#"{"characters":[{"character_id":1,"name":"One"},{"character_id":2,"name":"Two"}]}"#;
        assert!(load_demo_bundle_from(two, "{}", r#"{"nope":{}}"#).is_err());
    }

    #[test]
    fn bundled_fixtures_load_and_validate() {
        let bundle = load_demo_bundle().expect("bundled demo data loads");
        assert_eq!(bundle.characters.len(), 2);
        for character in &bundle.characters {
            let per = bundle
                .character_data(character.character_id)
                .expect("per-character data");
            assert!(!per.queue.is_empty());
            assert!(!per.journal.is_empty());
            assert!(per.balance > 0.0);
            assert!(!per.assets.is_empty(), "demo assets for {}", character.name);
        }
    }

    #[test]
    fn three_argument_loader_still_loads_with_empty_assets() {
        // Backwards-compatibility proof: bundled texts through the
        // original three-argument loader carry no assets.
        let bundle =
            load_demo_bundle_from(DEMO_CHARACTERS_JSON, DEMO_SKILLQUEUE_JSON, DEMO_WALLET_JSON)
                .expect("three-argument bundle loads");
        for per in bundle.data.values() {
            assert!(per.assets.is_empty());
            assert!(per.custom_names.is_empty());
        }
    }

    #[test]
    fn duplicate_asset_item_id_fails_validation() {
        let mut bundle = load_demo_bundle().expect("bundled bundle loads");
        let first = bundle.first_character_id().expect("first character");
        let per = bundle.data.get_mut(&first).expect("per-character data");
        let dupe = per.assets[0].clone();
        per.assets.push(dupe);
        assert!(validate_bundle(&bundle).is_err());
    }

    #[test]
    fn none_custom_names_never_reach_assets_data() {
        let bundle = load_demo_bundle().expect("bundled bundle loads");
        let mut state = AppState::new(true);
        apply_character(&mut state, &bundle, 90000001);
        let assets = state.assets.as_ready().expect("assets ready");
        assert_eq!(
            assets.custom_names.get(&710000002).map(String::as_str),
            Some("Aria's Rifter")
        );
        assert!(
            !assets.custom_names.contains_key(&710000003),
            "\"None\" filtered"
        );
        assert!(!state.assets_needs_reauthorize);
    }
}
