//! Offline demo data: bundled invented fixtures seeded into `AppState`.
//! No EVE credentials and no network are involved.

use crate::app::state::{AppState, LoadState, SkillsData, WalletData};
use crate::error::AppResult;
use crate::esi::models::*;
use crate::storage::repositories::CharacterRow;

pub const DEMO_CHARACTERS_JSON: &str = include_str!("../../assets/demo/characters.json");
pub const DEMO_SKILLQUEUE_JSON: &str = include_str!("../../assets/demo/skillqueue.json");
pub const DEMO_WALLET_JSON: &str = include_str!("../../assets/demo/wallet.json");
pub const DEMO_NAMES_JSON: &str = include_str!("../../assets/demo/names.json");

#[derive(Debug, Clone, Default, serde::Deserialize)]
pub struct DemoBundle {
    #[serde(default)]
    pub characters: Vec<DemoCharacter>,
    #[serde(default)]
    pub skill_queue: Vec<SkillQueueItem>,
    #[serde(default)]
    pub skills: CharacterSkills,
    #[serde(default)]
    pub balance: f64,
    #[serde(default)]
    pub journal: Vec<WalletJournalItem>,
    #[serde(default)]
    pub transactions: Vec<WalletTransactionItem>,
}

#[derive(Debug, Clone, Default, serde::Deserialize)]
pub struct DemoCharacter {
    #[serde(default)]
    pub character_id: i64,
    #[serde(default)]
    pub name: String,
    #[serde(default)]
    pub corporation_id: i64,
}

/// Load the bundled demo JSON files into typed structures.
pub fn load_demo_bundle() -> AppResult<DemoBundle> {
    tracing::debug!("[DEMO] loading bundled demo fixtures");
    let mut bundle: DemoBundle = serde_json::from_str(DEMO_CHARACTERS_JSON)?;
    let queue: Vec<SkillQueueItem> = serde_json::from_str(DEMO_SKILLQUEUE_JSON)?;
    bundle.skill_queue = queue;
    let wallet: DemoBundle = serde_json::from_str(DEMO_WALLET_JSON)?;
    bundle.balance = wallet.balance;
    bundle.journal = wallet.journal;
    bundle.transactions = wallet.transactions;
    bundle.skills = wallet.skills;
    tracing::info!(
        "[DEMO] bundle loaded characters={} queue={} journal={}",
        bundle.characters.len(),
        bundle.skill_queue.len(),
        bundle.journal.len()
    );
    Ok(bundle)
}

/// Pre-resolved universe names for demo rows (id, name) pairs.
pub fn load_demo_names() -> AppResult<Vec<UniverseName>> {
    tracing::debug!("[DEMO] loading demo universe names");
    let names: Vec<UniverseName> = serde_json::from_str(DEMO_NAMES_JSON)?;
    Ok(names)
}

/// Seed demo content into the UI state. Full repository seeding lands with
/// F4; this keeps `cargo run -- --demo` rendering real demo rows.
pub fn seed_demo_state(state: &mut AppState) {
    tracing::info!("[DEMO] seed_demo_state entry");
    match load_demo_bundle() {
        Ok(bundle) => {
            state.characters = bundle
                .characters
                .iter()
                .map(|c| CharacterRow {
                    character_id: c.character_id,
                    name: c.name.clone(),
                    corporation_id: c.corporation_id,
                    alliance_id: None,
                    is_active: false,
                })
                .collect();
            if let Some(first) = state.characters.first().cloned() {
                state.set_active_character(first.character_id);
                state.character_detail = LoadState::Ready(CharacterPublicInfo {
                    name: first.name.clone(),
                    corporation_id: first.corporation_id,
                    security_status: 5.0,
                    ..Default::default()
                });
                state.dashboard = state.character_detail.clone();
            }
            state.skills = LoadState::Ready(SkillsData {
                skills: bundle.skills.clone(),
                queue: bundle.skill_queue.clone(),
            });
            state.wallet = LoadState::Ready(WalletData {
                balance: bundle.balance,
                journal: bundle.journal.clone(),
                transactions: bundle.transactions.clone(),
                loyalty: Vec::new(),
            });
            state.status_message = "Demo mode: sample data, no network.".to_string();
            tracing::info!("[DEMO] seed complete characters={}", state.characters.len());
        }
        Err(e) => {
            tracing::error!("[DEMO] seed failed: {}", e);
            state.status_message = format!("Demo data failed to load: {e}");
        }
    }
}

/// Seed demo rows through the F2 repositories (stub for F4 wiring).
pub fn seed_into_db(_conn: &rusqlite::Connection) -> AppResult<()> {
    tracing::debug!("[DEMO] seed_into_db (stub)");
    Ok(())
}
