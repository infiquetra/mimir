//! Typed Phase-1 ESI calls. Bodies are stubs for F1; every call logs with
//! the `[ESI]` tag and never logs tokens.

use super::client::EsiClient;
use super::models::*;
use crate::error::{AppResult, EsiError};

fn stub<T>(name: &str) -> AppResult<T> {
    tracing::debug!("[ESI] {} entry (stub)", name);
    Err(EsiError::NotWired(format!("{name} lands with F1")).into())
}

pub async fn get_character(
    _client: &EsiClient,
    character_id: i64,
) -> AppResult<CharacterPublicInfo> {
    tracing::debug!("[ESI] GET /characters/{}/ (stub)", character_id);
    stub("get_character")
}

pub async fn get_skills(_client: &EsiClient, character_id: i64) -> AppResult<CharacterSkills> {
    tracing::debug!("[ESI] GET /characters/{}/skills/ (stub)", character_id);
    stub("get_skills")
}

pub async fn get_skill_queue(
    _client: &EsiClient,
    character_id: i64,
) -> AppResult<Vec<SkillQueueItem>> {
    tracing::debug!("[ESI] GET /characters/{}/skillqueue/ (stub)", character_id);
    stub("get_skill_queue")
}

pub async fn get_attributes(
    _client: &EsiClient,
    character_id: i64,
) -> AppResult<CharacterAttributes> {
    tracing::debug!("[ESI] GET /characters/{}/attributes/ (stub)", character_id);
    stub("get_attributes")
}

pub async fn get_wallet_balance(_client: &EsiClient, character_id: i64) -> AppResult<f64> {
    tracing::debug!("[ESI] GET /characters/{}/wallet/ (stub)", character_id);
    stub("get_wallet_balance")
}

pub async fn get_wallet_journal(
    _client: &EsiClient,
    character_id: i64,
) -> AppResult<Vec<WalletJournalItem>> {
    tracing::debug!(
        "[ESI] GET /characters/{}/wallet/journal/ (stub)",
        character_id
    );
    stub("get_wallet_journal")
}

pub async fn get_wallet_transactions(
    _client: &EsiClient,
    character_id: i64,
) -> AppResult<Vec<WalletTransactionItem>> {
    tracing::debug!(
        "[ESI] GET /characters/{}/wallet/transactions/ (stub)",
        character_id
    );
    stub("get_wallet_transactions")
}

pub async fn get_loyalty_points(
    _client: &EsiClient,
    character_id: i64,
) -> AppResult<Vec<LoyaltyPointItem>> {
    tracing::debug!(
        "[ESI] GET /characters/{}/loyalty/points/ (stub)",
        character_id
    );
    stub("get_loyalty_points")
}

pub async fn get_location(_client: &EsiClient, character_id: i64) -> AppResult<CharacterLocation> {
    tracing::debug!("[ESI] GET /characters/{}/location/ (stub)", character_id);
    stub("get_location")
}

pub async fn get_ship(_client: &EsiClient, character_id: i64) -> AppResult<CharacterShip> {
    tracing::debug!("[ESI] GET /characters/{}/ship/ (stub)", character_id);
    stub("get_ship")
}

pub async fn get_online(_client: &EsiClient, character_id: i64) -> AppResult<CharacterOnline> {
    tracing::debug!("[ESI] GET /characters/{}/online/ (stub)", character_id);
    stub("get_online")
}

pub async fn get_clones(_client: &EsiClient, character_id: i64) -> AppResult<CharacterClones> {
    tracing::debug!("[ESI] GET /characters/{}/clones/ (stub)", character_id);
    stub("get_clones")
}

pub async fn get_implants(_client: &EsiClient, character_id: i64) -> AppResult<Vec<i64>> {
    tracing::debug!("[ESI] GET /characters/{}/implants/ (stub)", character_id);
    stub("get_implants")
}

pub async fn get_standings(_client: &EsiClient, character_id: i64) -> AppResult<Vec<Standing>> {
    tracing::debug!("[ESI] GET /characters/{}/standings/ (stub)", character_id);
    stub("get_standings")
}

pub async fn resolve_names(_client: &EsiClient, ids: &[i64]) -> AppResult<Vec<UniverseName>> {
    tracing::debug!("[ESI] POST /universe/names/ count={} (stub)", ids.len());
    stub("resolve_names")
}

pub async fn resolve_ids(_client: &EsiClient, names: &[String]) -> AppResult<Vec<UniverseName>> {
    tracing::debug!("[ESI] POST /universe/ids/ count={} (stub)", names.len());
    stub("resolve_ids")
}

pub async fn get_station(_client: &EsiClient, station_id: i64) -> AppResult<StationInfo> {
    tracing::debug!("[ESI] GET /universe/stations/{}/ (stub)", station_id);
    stub("get_station")
}

pub async fn get_structure(_client: &EsiClient, structure_id: i64) -> AppResult<StructureInfo> {
    tracing::debug!("[ESI] GET /universe/structures/{}/ (stub)", structure_id);
    stub("get_structure")
}

pub async fn get_corporation(
    _client: &EsiClient,
    corporation_id: i64,
) -> AppResult<CorporationInfo> {
    tracing::debug!("[ESI] GET /corporations/{}/ (stub)", corporation_id);
    stub("get_corporation")
}

pub async fn get_alliance(_client: &EsiClient, alliance_id: i64) -> AppResult<AllianceInfo> {
    tracing::debug!("[ESI] GET /alliances/{}/ (stub)", alliance_id);
    stub("get_alliance")
}
