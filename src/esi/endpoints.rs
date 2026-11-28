//! Typed Phase-1 ESI calls (design section 5 endpoint set). Every call logs
//! with a bracketed feature tag and never logs tokens. Authenticated calls
//! take the character ID only; the access token (with auto-refresh) comes
//! from the `TokenStore` attached to `EsiClient`.

use super::client::EsiClient;
use super::models::*;
use crate::auth::token_store::AccessToken;
use crate::error::{AppResult, EsiError};

pub async fn get_character(
    client: &EsiClient,
    character_id: i64,
) -> AppResult<CharacterPublicInfo> {
    tracing::debug!("[CHAR] GET /characters/{}/", character_id);
    client
        .public_get(&format!("/characters/{character_id}/"))
        .await
}

/// The character's mining ledger. Requires scope
/// `esi-industry.read_character_mining.v1` (step-up only, never
/// first-auth); a missing scope surfaces as 401/403 via
/// `endpoints::needs_reauthorize`. Goes through `EsiClient` only.
pub async fn get_character_mining(
    client: &EsiClient,
    character_id: i64,
) -> AppResult<Vec<CharacterMiningEntry>> {
    tracing::debug!("[MINING] GET /characters/{}/mining/", character_id);
    let rows: Vec<CharacterMiningEntry> = client
        .auth_get(&format!("/characters/{character_id}/mining/"), character_id)
        .await?;
    tracing::info!(
        "[MINING] mining ledger fetched character_id={} rows={}",
        character_id,
        rows.len()
    );
    Ok(rows)
}

pub async fn get_skills(client: &EsiClient, character_id: i64) -> AppResult<CharacterSkills> {
    tracing::debug!("[SKILLS] GET /characters/{}/skills/", character_id);
    client
        .auth_get(&format!("/characters/{character_id}/skills/"), character_id)
        .await
}

pub async fn get_skill_queue(
    client: &EsiClient,
    character_id: i64,
) -> AppResult<Vec<SkillQueueItem>> {
    tracing::debug!("[SKILLS] GET /characters/{}/skillqueue/", character_id);
    client
        .auth_get(
            &format!("/characters/{character_id}/skillqueue/"),
            character_id,
        )
        .await
}

pub async fn get_attributes(
    client: &EsiClient,
    character_id: i64,
) -> AppResult<CharacterAttributes> {
    tracing::debug!("[SKILLS] GET /characters/{}/attributes/", character_id);
    client
        .auth_get(
            &format!("/characters/{character_id}/attributes/"),
            character_id,
        )
        .await
}

pub async fn get_wallet_balance(client: &EsiClient, character_id: i64) -> AppResult<f64> {
    tracing::debug!("[WALLET] GET /characters/{}/wallet/", character_id);
    client
        .auth_get(&format!("/characters/{character_id}/wallet/"), character_id)
        .await
}

/// One wallet-journal page (Flutter `getWalletJournal(page)` parity).
pub async fn get_wallet_journal_page(
    client: &EsiClient,
    character_id: i64,
    page: u32,
) -> AppResult<Vec<WalletJournalItem>> {
    tracing::debug!(
        "[WALLET] GET /characters/{}/wallet/journal/ page={}",
        character_id,
        page
    );
    let (items, _meta) = client
        .auth_get_page(
            &format!("/characters/{character_id}/wallet/journal/"),
            character_id,
            Some(page.max(1)),
        )
        .await?;
    Ok(items)
}

/// Defensive cap on paginated character endpoints when ESI omits `X-Pages`.
pub const UNBOUNDED_PAGE_CAP: u32 = 50;

/// Full wallet journal: walks pages until `X-Pages`/an empty page ends it
/// (or `UNBOUNDED_PAGE_CAP` if `X-Pages` is omitted).
pub async fn get_wallet_journal(
    client: &EsiClient,
    character_id: i64,
) -> AppResult<Vec<WalletJournalItem>> {
    tracing::debug!(
        "[WALLET] GET /characters/{}/wallet/journal/ (all pages)",
        character_id
    );
    let mut page = 1u32;
    let mut all: Vec<WalletJournalItem> = Vec::new();
    loop {
        let (items, meta) = client
            .auth_get_page::<Vec<WalletJournalItem>>(
                &format!("/characters/{character_id}/wallet/journal/"),
                character_id,
                Some(page),
            )
            .await?;
        let count = items.len();
        tracing::debug!(
            "[WALLET] journal page={} rows={} total={}",
            page,
            count,
            all.len() + count
        );
        all.extend(items);
        let last = match meta.pages {
            Some(total) => page >= total,
            None => {
                if count == 0 {
                    true
                } else if page >= UNBOUNDED_PAGE_CAP {
                    tracing::warn!(
                        "[WALLET] journal stopped at missing X-Pages cap page={} character_id={}",
                        page,
                        character_id
                    );
                    true
                } else {
                    false
                }
            }
        };
        if last {
            break;
        }
        page += 1;
    }
    tracing::info!(
        "[WALLET] journal fetched character_id={} rows={}",
        character_id,
        all.len()
    );
    Ok(all)
}

pub async fn get_wallet_transactions(
    client: &EsiClient,
    character_id: i64,
) -> AppResult<Vec<WalletTransactionItem>> {
    get_wallet_transactions_from(client, character_id, None).await
}

/// `from_id` pages backwards through older transactions (ESI semantics).
pub async fn get_wallet_transactions_from(
    client: &EsiClient,
    character_id: i64,
    from_id: Option<i64>,
) -> AppResult<Vec<WalletTransactionItem>> {
    tracing::debug!(
        "[WALLET] GET /characters/{}/wallet/transactions/",
        character_id
    );
    let path = match from_id {
        Some(id) => format!("/characters/{character_id}/wallet/transactions/?from_id={id}"),
        None => format!("/characters/{character_id}/wallet/transactions/"),
    };
    client.auth_get(&path, character_id).await
}

pub async fn get_loyalty_points(
    client: &EsiClient,
    character_id: i64,
) -> AppResult<Vec<LoyaltyPointItem>> {
    tracing::debug!("[WALLET] GET /characters/{}/loyalty/points/", character_id);
    client
        .auth_get(
            &format!("/characters/{character_id}/loyalty/points/"),
            character_id,
        )
        .await
}

/// One character-assets page. Requires scope `esi-assets.read_assets.v1`
/// (progressive step-up, never first-auth — design section 9); a missing
/// scope surfaces as HTTP 403 → `EsiError::Reauthorize`.
pub async fn get_assets_page(
    client: &EsiClient,
    character_id: i64,
    page: u32,
) -> AppResult<Vec<AssetItem>> {
    tracing::debug!(
        "[ASSETS] GET /characters/{}/assets/ page={}",
        character_id,
        page
    );
    let (items, _meta) = client
        .auth_get_page(
            &format!("/characters/{character_id}/assets/"),
            character_id,
            Some(page.max(1)),
        )
        .await?;
    Ok(items)
}

/// Full character asset list: walks pages until `X-Pages`/an empty page
/// ends it (or `UNBOUNDED_PAGE_CAP` if `X-Pages` is omitted). Any page error
/// (including the 403 scope failure) propagates; partial asset lists are
/// never returned as success.
pub async fn get_assets(client: &EsiClient, character_id: i64) -> AppResult<Vec<AssetItem>> {
    tracing::debug!(
        "[ASSETS] GET /characters/{}/assets/ (all pages)",
        character_id
    );
    let mut page = 1u32;
    let mut all: Vec<AssetItem> = Vec::new();
    loop {
        let (items, meta) = client
            .auth_get_page::<Vec<AssetItem>>(
                &format!("/characters/{character_id}/assets/"),
                character_id,
                Some(page),
            )
            .await?;
        let count = items.len();
        tracing::debug!(
            "[ASSETS] assets page={} rows={} total={}",
            page,
            count,
            all.len() + count
        );
        all.extend(items);
        let last = match meta.pages {
            Some(total) => page >= total,
            None => {
                if count == 0 {
                    true
                } else if page >= UNBOUNDED_PAGE_CAP {
                    tracing::warn!(
                        "[ASSETS] assets stopped at missing X-Pages cap page={} character_id={}",
                        page,
                        character_id
                    );
                    true
                } else {
                    false
                }
            }
        };
        if last {
            break;
        }
        page += 1;
    }
    tracing::info!(
        "[ASSETS] assets fetched character_id={} rows={}",
        character_id,
        all.len()
    );
    Ok(all)
}

/// Custom names for singleton item instances
/// (`POST /characters/{id}/assets/names/`), under the same
/// `esi-assets.read_assets.v1` scope as the asset list. ESI accepts at
/// most 1000 item IDs per call; chunking larger sets is the caller's
/// job (as the shell chunks `resolve_names`). Returned names are raw:
/// the caller filters empty and `"None"` placeholders.
pub async fn get_asset_names(
    client: &EsiClient,
    character_id: i64,
    item_ids: &[i64],
) -> AppResult<Vec<AssetName>> {
    tracing::debug!(
        "[ASSETS] POST /characters/{}/assets/names/ count={}",
        character_id,
        item_ids.len()
    );
    if item_ids.is_empty() {
        return Ok(Vec::new());
    }
    client
        .auth_post(
            &format!("/characters/{character_id}/assets/names/"),
            character_id,
            &item_ids.to_vec(),
        )
        .await
}

/// Hard cap for market page walks. Regional orders for one type and
/// one character's open orders are bounded populations; the cap is a
/// runaway guard, and hitting it is always disclosed via the
/// returned truncated flag rather than silent partial data.
pub const MARKET_MAX_PAGES: u32 = 10;

/// Public regional orders for exactly one type (`type_id` is always
/// embedded in the path; there is no unfiltered regional fetch).
/// Returns raw rows in fetch order plus a truncated flag (design 5.2).
pub async fn get_regional_orders(
    client: &EsiClient,
    region_id: i64,
    type_id: i64,
) -> AppResult<(Vec<RegionalOrder>, bool)> {
    get_regional_orders_capped(client, region_id, type_id, MARKET_MAX_PAGES).await
}

async fn get_regional_orders_capped(
    client: &EsiClient,
    region_id: i64,
    type_id: i64,
    max_pages: u32,
) -> AppResult<(Vec<RegionalOrder>, bool)> {
    let max_pages = max_pages.max(1);
    let path = format!("/markets/{region_id}/orders/?type_id={type_id}&order_type=all");
    tracing::debug!(
        "[MARKET] GET /markets/{}/orders/ type_id={} order_type=all (capped pages={})",
        region_id,
        type_id,
        max_pages
    );
    let mut page = 1u32;
    let mut all: Vec<RegionalOrder> = Vec::new();
    let mut truncated = false;
    loop {
        let (items, meta) = client
            .public_get_page::<Vec<RegionalOrder>>(&path, page)
            .await?;
        let count = items.len();
        tracing::debug!(
            "[MARKET] regional orders page={} rows={} total={}",
            page,
            count,
            all.len() + count
        );
        all.extend(items);
        match meta.pages {
            Some(total) if page >= total => break,
            Some(_) => {
                if page >= max_pages {
                    truncated = true;
                    break;
                }
            }
            None => {
                if count == 0 {
                    break;
                }
                if page >= max_pages {
                    truncated = true;
                    break;
                }
            }
        }
        page += 1;
    }
    tracing::info!(
        "[MARKET] regional orders fetched region_id={} type_id={} rows={} truncated={}",
        region_id,
        type_id,
        all.len(),
        truncated
    );
    Ok((all, truncated))
}

/// Public regional price history for exactly one type: one request,
/// rows returned unsorted exactly as ESI sent them (design 5.2).
pub async fn get_market_history(
    client: &EsiClient,
    region_id: i64,
    type_id: i64,
) -> AppResult<Vec<MarketHistoryEntry>> {
    tracing::debug!(
        "[MARKET] GET /markets/{}/history/ type_id={}",
        region_id,
        type_id
    );
    let rows: Vec<MarketHistoryEntry> = client
        .public_get(&format!("/markets/{region_id}/history/?type_id={type_id}"))
        .await?;
    tracing::info!(
        "[MARKET] history fetched region_id={} type_id={} rows={}",
        region_id,
        type_id,
        rows.len()
    );
    Ok(rows)
}

/// The character's own open orders (unpaginated in ESI: returns all active
/// orders in a single response). Requires scope
/// `esi-markets.read_character_orders.v1` (progressive step-up,
/// never first-auth); a missing scope surfaces as HTTP 403 →
/// `EsiError::Reauthorize`.
pub async fn get_character_orders(
    client: &EsiClient,
    character_id: i64,
) -> AppResult<(Vec<CharacterOrder>, bool)> {
    tracing::debug!("[MARKET] GET /characters/{}/orders/", character_id);
    let orders: Vec<CharacterOrder> = client
        .auth_get(&format!("/characters/{character_id}/orders/"), character_id)
        .await?;
    tracing::info!(
        "[MARKET] character orders fetched character_id={} rows={} truncated=false",
        character_id,
        orders.len()
    );
    Ok((orders, false))
}

/// Hard cap for industry page walks. A character's blueprint library is a
/// character-bounded population; the cap is a runaway guard, and hitting it
/// is always disclosed via the returned truncated flag rather than silent partial data.
pub const INDUSTRY_MAX_PAGES: u32 = 10;

/// The character's industry jobs (unpaginated in ESI), completed jobs
/// included. Requires scope `esi-industry.read_character_jobs.v1`
/// (progressive step-up, never first-auth); a missing scope surfaces
/// as HTTP 403 -> `EsiError::Reauthorize`. Rows return in fetch order,
/// unsorted and unfiltered.
pub async fn get_character_industry_jobs(
    client: &EsiClient,
    character_id: i64,
) -> AppResult<(Vec<IndustryJob>, bool)> {
    let path = format!("/characters/{character_id}/industry/jobs/?include_completed=true");
    tracing::debug!(
        "[INDUSTRY] GET /characters/{}/industry/jobs/?include_completed=true",
        character_id
    );
    let jobs: Vec<IndustryJob> = client.auth_get(&path, character_id).await?;
    tracing::info!(
        "[INDUSTRY] industry jobs fetched character_id={} rows={} truncated=false",
        character_id,
        jobs.len()
    );
    Ok((jobs, false))
}

/// The character's blueprint library. Requires scope
/// `esi-characters.read_blueprints.v1` (progressive step-up,
/// never first-auth); a missing scope surfaces as HTTP 403 ->
/// `EsiError::Reauthorize`. Any page error propagates; partial
/// page lists are never returned as success. Rows return in
/// fetch order, unsorted and unfiltered.
pub async fn get_character_blueprints(
    client: &EsiClient,
    character_id: i64,
) -> AppResult<(Vec<CharacterBlueprint>, bool)> {
    get_character_blueprints_capped(client, character_id, INDUSTRY_MAX_PAGES).await
}

async fn get_character_blueprints_capped(
    client: &EsiClient,
    character_id: i64,
    max_pages: u32,
) -> AppResult<(Vec<CharacterBlueprint>, bool)> {
    let max_pages = max_pages.max(1);
    tracing::debug!(
        "[INDUSTRY] GET /characters/{}/blueprints/ (capped pages={})",
        character_id,
        max_pages
    );
    let mut page = 1u32;
    let mut all: Vec<CharacterBlueprint> = Vec::new();
    let mut truncated = false;
    loop {
        let (items, meta) = client
            .auth_get_page::<Vec<CharacterBlueprint>>(
                &format!("/characters/{character_id}/blueprints/"),
                character_id,
                Some(page),
            )
            .await?;
        let count = items.len();
        tracing::debug!(
            "[INDUSTRY] blueprints page={} rows={} total={}",
            page,
            count,
            all.len() + count
        );
        all.extend(items);
        match meta.pages {
            Some(total) if page >= total => break,
            Some(_) => {
                if page >= max_pages {
                    truncated = true;
                    break;
                }
            }
            None => {
                if count == 0 {
                    break;
                }
                if page >= max_pages {
                    truncated = true;
                    break;
                }
            }
        }
        page += 1;
    }
    tracing::info!(
        "[INDUSTRY] blueprints fetched character_id={} rows={} truncated={}",
        character_id,
        all.len(),
        truncated
    );
    Ok((all, truncated))
}

/// The character's colonies, one row per colony. Requires scope
/// `esi-planets.manage_planets.v1` (progressive step-up, never
/// first-auth); a missing scope surfaces as HTTP 401/403 →
/// `EsiError::Reauthorize`/`Unauthorized`, detected only through
/// `endpoints::needs_reauthorize`. Rows return in fetch order,
/// unsorted and unfiltered.
pub async fn get_character_planets(
    client: &EsiClient,
    character_id: i64,
) -> AppResult<Vec<PlanetColony>> {
    tracing::debug!("[PI] GET /characters/{}/planets/", character_id);
    client
        .auth_get(
            &format!("/characters/{character_id}/planets/"),
            character_id,
        )
        .await
}

/// One colony's detail (pins, links, routes). Requires scope
/// `esi-planets.manage_planets.v1` (progressive step-up, never
/// first-auth); a missing scope surfaces as HTTP 401/403 →
/// `EsiError::Reauthorize`/`Unauthorized`, detected only through
/// `endpoints::needs_reauthorize`.
pub async fn get_character_planet(
    client: &EsiClient,
    character_id: i64,
    planet_id: i64,
) -> AppResult<PlanetColonyDetail> {
    tracing::debug!(
        "[PI] GET /characters/{}/planets/{}/",
        character_id,
        planet_id
    );
    client
        .auth_get(
            &format!("/characters/{character_id}/planets/{planet_id}/"),
            character_id,
        )
        .await
}

/// The character's saved fittings, in fetch order. Requires scope
/// `esi-fittings.read_fittings.v1` (progressive step-up, never
/// first-auth); a missing scope surfaces as HTTP 401/403 →
/// `EsiError::Reauthorize`/`Unauthorized`, detected only through
/// `endpoints::needs_reauthorize`. The list carries each fitting's
/// full item list, so selecting a fitting never fetches. Fitting
/// writes (`save_character_fitting` / `delete_character_fitting`)
/// live beside this function but need the separate write scope.
/// Rows return in fetch order, unsorted and unfiltered. The
/// endpoint function adds no scope logic.
pub async fn get_character_fittings(
    client: &EsiClient,
    character_id: i64,
) -> AppResult<Vec<CharacterFitting>> {
    tracing::debug!("[ESI] GET /characters/{}/fittings/", character_id);
    client
        .auth_get(
            &format!("/characters/{character_id}/fittings/"),
            character_id,
        )
        .await
}

/// Save a fitting to the character's in-game fitting list. Requires
/// scope `esi-fittings.write_fittings.v1` (progressive step-up,
/// never first-auth); a missing scope surfaces as HTTP 401/403 →
/// `EsiError::Reauthorize`/`Unauthorized`. Success is only a 2xx
/// whose body decodes as `SaveFittingResponse`; the returned
/// `fitting_id` is the caller's receipt. The trailing-slash path
/// matches the shipped read path and the retired Flutter POST.
pub async fn save_character_fitting(
    client: &EsiClient,
    character_id: i64,
    request: &SaveFittingRequest,
) -> AppResult<SaveFittingResponse> {
    tracing::debug!(
        "[FITTING] POST /characters/{}/fittings/ items={}",
        character_id,
        request.items.len()
    );
    client
        .auth_post(
            &format!("/characters/{character_id}/fittings/"),
            character_id,
            request,
        )
        .await
}

/// Delete a saved fitting from the character's in-game list.
/// Requires scope `esi-fittings.write_fittings.v1` (progressive
/// step-up, never first-auth). Success is the ESI 204 with no
/// body. The caller guards `fitting_id > 0` before spawning, so
/// only server-issued ids are ever delete targets.
pub async fn delete_character_fitting(
    client: &EsiClient,
    character_id: i64,
    fitting_id: i64,
) -> AppResult<()> {
    tracing::debug!(
        "[FITTING] DELETE /characters/{}/fittings/{}/",
        character_id,
        fitting_id
    );
    client
        .auth_delete(
            &format!("/characters/{character_id}/fittings/{fitting_id}/"),
            character_id,
        )
        .await
}

pub async fn get_location(client: &EsiClient, character_id: i64) -> AppResult<CharacterLocation> {
    tracing::debug!("[CHAR] GET /characters/{}/location/", character_id);
    client
        .auth_get(
            &format!("/characters/{character_id}/location/"),
            character_id,
        )
        .await
}

pub async fn get_ship(client: &EsiClient, character_id: i64) -> AppResult<CharacterShip> {
    tracing::debug!("[CHAR] GET /characters/{}/ship/", character_id);
    client
        .auth_get(&format!("/characters/{character_id}/ship/"), character_id)
        .await
}

pub async fn get_online(client: &EsiClient, character_id: i64) -> AppResult<CharacterOnline> {
    tracing::debug!("[CHAR] GET /characters/{}/online/", character_id);
    client
        .auth_get(&format!("/characters/{character_id}/online/"), character_id)
        .await
}

pub async fn get_clones(client: &EsiClient, character_id: i64) -> AppResult<CharacterClones> {
    tracing::debug!("[CHAR] GET /characters/{}/clones/", character_id);
    client
        .auth_get(&format!("/characters/{character_id}/clones/"), character_id)
        .await
}

pub async fn get_implants(client: &EsiClient, character_id: i64) -> AppResult<Vec<i64>> {
    tracing::debug!("[CHAR] GET /characters/{}/implants/", character_id);
    client
        .auth_get(
            &format!("/characters/{character_id}/implants/"),
            character_id,
        )
        .await
}

pub async fn get_standings(client: &EsiClient, character_id: i64) -> AppResult<Vec<Standing>> {
    tracing::debug!("[CHAR] GET /characters/{}/standings/", character_id);
    client
        .auth_get(
            &format!("/characters/{character_id}/standings/"),
            character_id,
        )
        .await
}

/// Resolve numeric IDs to names (`POST /universe/names/`). Display code
/// must show these names, never the raw IDs (repo rule).
pub async fn resolve_names(client: &EsiClient, ids: &[i64]) -> AppResult<Vec<UniverseName>> {
    tracing::debug!("[ESI] POST /universe/names/ count={}", ids.len());
    if ids.is_empty() {
        return Ok(Vec::new());
    }
    client.public_post("/universe/names/", &ids.to_vec()).await
}

/// Resolve names to IDs (`POST /universe/ids/`), flattened with categories.
pub async fn resolve_ids(client: &EsiClient, names: &[String]) -> AppResult<Vec<UniverseName>> {
    tracing::debug!("[ESI] POST /universe/ids/ count={}", names.len());
    if names.is_empty() {
        return Ok(Vec::new());
    }
    let grouped: UniverseIds = client
        .public_post("/universe/ids/", &names.to_vec())
        .await?;
    Ok(grouped.flatten())
}

pub async fn get_station(client: &EsiClient, station_id: i64) -> AppResult<StationInfo> {
    tracing::debug!("[ESI] GET /universe/stations/{}/", station_id);
    client
        .public_get(&format!("/universe/stations/{station_id}/"))
        .await
}

/// Authenticated structure lookup (Flutter `getStructureName` parity: ESI
/// 403s for structures the character cannot see, surfaced as
/// `EsiError::Reauthorize`; resolvers map that to "Unknown Location").
pub async fn get_structure_for_character(
    client: &EsiClient,
    structure_id: i64,
    character_id: i64,
) -> AppResult<StructureInfo> {
    tracing::debug!(
        "[ESI] GET /universe/structures/{}/ character_id={}",
        structure_id,
        character_id
    );
    client
        .auth_get(
            &format!("/universe/structures/{structure_id}/"),
            character_id,
        )
        .await
}

pub async fn get_structure_with_token(
    client: &EsiClient,
    structure_id: i64,
    access_token: &AccessToken,
) -> AppResult<StructureInfo> {
    tracing::debug!(
        "[ESI] GET /universe/structures/{}/ (explicit token)",
        structure_id
    );
    client
        .auth_get_with_token(
            &format!("/universe/structures/{structure_id}/"),
            access_token,
        )
        .await
}

pub async fn get_corporation(
    client: &EsiClient,
    corporation_id: i64,
) -> AppResult<CorporationInfo> {
    tracing::debug!("[ESI] GET /corporations/{}/", corporation_id);
    client
        .public_get(&format!("/corporations/{corporation_id}/"))
        .await
}

pub async fn get_alliance(client: &EsiClient, alliance_id: i64) -> AppResult<AllianceInfo> {
    tracing::debug!("[ESI] GET /alliances/{}/", alliance_id);
    client
        .public_get(&format!("/alliances/{alliance_id}/"))
        .await
}

/// True when an endpoint error means "show the re-authorize prompt".
pub fn needs_reauthorize(error: &crate::error::AppError) -> bool {
    matches!(
        error,
        crate::error::AppError::Esi(EsiError::Reauthorize | EsiError::Unauthorized)
    )
}

/// What a failed fitting write proves about the server state, for
/// honest status wording. `NotSent` means the request provably
/// never left this process (safe to retry by hand); `Definitive`
/// means ESI answered 4xx (nothing was created or deleted);
/// `AlreadyGone` is a DELETE 404 (the fitting is already gone);
/// `RateLimited` carries the server reset duration;
/// `Unknown` means no usable answer (transport, 5xx, or an
/// undecodable success body — the server may have committed).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum WriteFailureClass {
    NotSent,
    Definitive,
    AlreadyGone,
    RateLimited { reset_secs: u32 },
    Unknown,
}

/// Classify a fitting write error into what it proves about the
/// server state plus whether the remedy is re-authorization.
/// Every error variant is matched by name so a future variant is
/// a compile error here, not a silent miscategorization.
///
/// Every write 403 takes the re-authorize route: `EsiError`
/// cannot distinguish a missing scope from any other 403, and
/// this slice invents no body-sniffing discriminator. `NoTokens`
/// also routes to re-authorize (the read path's
/// `needs_reauthorize` covers only 401/403): with no stored
/// tokens the honest remedy is signing in again, and the write
/// panel is this view's route to it.
pub fn classify_write_error(
    error: &crate::error::AppError,
    is_delete: bool,
) -> (WriteFailureClass, bool) {
    use crate::error::{AppError, AuthError};
    match error {
        AppError::Esi(esi) => match esi {
            EsiError::Unauthorized => (WriteFailureClass::Definitive, true),
            EsiError::Reauthorize => (WriteFailureClass::Definitive, true),
            EsiError::NotFound(_) => {
                if is_delete {
                    (WriteFailureClass::AlreadyGone, false)
                } else {
                    (WriteFailureClass::Definitive, false)
                }
            }
            EsiError::RateLimited { reset_secs } => (
                WriteFailureClass::RateLimited {
                    reset_secs: *reset_secs,
                },
                false,
            ),
            EsiError::ErrorLimitExhausted { reset_secs } => (
                WriteFailureClass::RateLimited {
                    reset_secs: *reset_secs,
                },
                false,
            ),
            EsiError::Status(code) | EsiError::StatusMessage(code, _) => {
                if (400..500).contains(code) {
                    (WriteFailureClass::Definitive, false)
                } else {
                    (WriteFailureClass::Unknown, false)
                }
            }
            EsiError::NoTokens(_) => (WriteFailureClass::NotSent, true),
            EsiError::Http(_) => (WriteFailureClass::Unknown, false),
            EsiError::Decode(_) => (WriteFailureClass::Unknown, false),
            EsiError::NotWired(_) => (WriteFailureClass::NotSent, false),
            EsiError::Message(_) => (WriteFailureClass::NotSent, false),
        },
        AppError::Auth(auth) => (
            WriteFailureClass::NotSent,
            matches!(auth, AuthError::RefreshRejected),
        ),
        AppError::Db(_) => (WriteFailureClass::NotSent, false),
        AppError::Io(_) => (WriteFailureClass::NotSent, false),
        AppError::Json(_) => (WriteFailureClass::NotSent, false),
        AppError::Url(_) => (WriteFailureClass::NotSent, false),
        AppError::Message(_) => (WriteFailureClass::NotSent, false),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::auth::token_store::{RefreshToken, StoredTokens, TokenStore};
    use std::sync::Arc;
    use tokio::io::{AsyncReadExt, AsyncWriteExt};
    use tokio::net::TcpListener;

    /// Mock server that answers by `page=` query for journal pagination.
    async fn journal_server() -> String {
        let listener = TcpListener::bind("127.0.0.1:0").await.expect("bind");
        let addr = listener.local_addr().expect("addr");
        tokio::spawn(async move {
            loop {
                let Ok((mut socket, _peer)) = listener.accept().await else {
                    break;
                };
                tokio::spawn(async move {
                    let mut buffer = vec![0u8; 16384];
                    let count = socket.read(&mut buffer).await.unwrap_or(0);
                    let request = String::from_utf8_lossy(&buffer[..count]).into_owned();
                    let (body, pages) = if request.contains("page=2") {
                        (
                            r#"[{"id":2,"amount":-5.0,"balance":5.0,"date":"d","description":"x","ref_type":"b"}]"#,
                            2,
                        )
                    } else {
                        (
                            r#"[{"id":1,"amount":10.0,"balance":10.0,"date":"d","description":"x","ref_type":"a"}]"#,
                            2,
                        )
                    };
                    let payload = format!(
                        "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nX-Pages: {pages}\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{body}",
                        body.len()
                    );
                    let _ = socket.write_all(payload.as_bytes()).await;
                    let _ = socket.flush().await;
                });
            }
        });
        format!("http://{addr}")
    }

    fn client_with_fresh_tokens(base: String) -> (EsiClient, tempfile::TempDir) {
        let dir = tempfile::tempdir().expect("tempdir");
        let store = Arc::new(TokenStore::file_only(dir.path().join("tokens.json")));
        store
            .save(&StoredTokens {
                character_id: 7,
                access: AccessToken("test-access".to_string()),
                refresh: RefreshToken("test-refresh".to_string()),
                expires_at_unix: 4_000_000_000,
            })
            .expect("seed");
        (
            EsiClient::with_http(reqwest::Client::new(), base).with_token_store(store),
            dir,
        )
    }

    #[tokio::test]
    async fn wallet_journal_walks_all_pages() {
        let base = journal_server().await;
        let (client, _dir) = client_with_fresh_tokens(base);
        let journal = get_wallet_journal(&client, 7).await.expect("journal");
        assert_eq!(journal.len(), 2);
        assert_eq!(journal[0].id, 1);
        assert_eq!(journal[1].id, 2);
    }

    #[tokio::test]
    async fn empty_resolve_names_short_circuits() {
        let client = EsiClient::with_http(reqwest::Client::new(), "http://127.0.0.1:9".to_string());
        let names = resolve_names(&client, &[]).await.expect("empty ok");
        assert!(names.is_empty());
        let ids = resolve_ids(&client, &[]).await.expect("empty ok");
        assert!(ids.is_empty());
    }

    /// Mock server that answers by `page=` query for assets pagination.
    async fn assets_server() -> String {
        let listener = TcpListener::bind("127.0.0.1:0").await.expect("bind");
        let addr = listener.local_addr().expect("addr");
        tokio::spawn(async move {
            loop {
                let Ok((mut socket, _peer)) = listener.accept().await else {
                    break;
                };
                tokio::spawn(async move {
                    let mut buffer = vec![0u8; 16384];
                    let count = socket.read(&mut buffer).await.unwrap_or(0);
                    let request = String::from_utf8_lossy(&buffer[..count]).into_owned();
                    let body = if request.contains("page=2") {
                        r#"[{"item_id":102,"type_id":587,"quantity":1,"location_id":60003760,"location_flag":"Hangar","is_singleton":true}]"#
                    } else {
                        r#"[{"item_id":101,"type_id":34,"quantity":500,"location_id":60003760,"location_flag":"Hangar","is_singleton":false,"is_blueprint_copy":true}]"#
                    };
                    let payload = format!(
                        "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nX-Pages: 2\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{body}",
                        body.len()
                    );
                    let _ = socket.write_all(payload.as_bytes()).await;
                    let _ = socket.flush().await;
                });
            }
        });
        format!("http://{addr}")
    }

    /// One-shot mock server: captures the request, returns fixed status/body.
    async fn one_shot_server(
        status: u16,
        body: &'static str,
    ) -> (String, tokio::sync::oneshot::Receiver<String>) {
        let listener = TcpListener::bind("127.0.0.1:0").await.expect("bind");
        let addr = listener.local_addr().expect("addr");
        let (tx, rx) = tokio::sync::oneshot::channel::<String>();
        tokio::spawn(async move {
            if let Ok((mut socket, _peer)) = listener.accept().await {
                let mut buffer = vec![0u8; 16384];
                let count = socket.read(&mut buffer).await.unwrap_or(0);
                let _ = tx.send(String::from_utf8_lossy(&buffer[..count]).into_owned());
                let payload = format!(
                    "HTTP/1.1 {status} OK\r\nContent-Type: application/json\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{body}",
                    body.len()
                );
                let _ = socket.write_all(payload.as_bytes()).await;
                let _ = socket.flush().await;
            }
        });
        (format!("http://{addr}"), rx)
    }

    #[tokio::test]
    async fn assets_walks_all_pages() {
        let base = assets_server().await;
        let (client, _dir) = client_with_fresh_tokens(base);
        let assets = get_assets(&client, 7).await.expect("assets");
        assert_eq!(assets.len(), 2);
        assert_eq!(assets[0].item_id, 101);
        assert_eq!(assets[0].quantity, 500);
        assert_eq!(assets[0].is_blueprint_copy, Some(true));
        assert_eq!(assets[1].item_id, 102);
        assert!(assets[1].is_singleton);
    }

    #[tokio::test]
    async fn empty_asset_names_short_circuits() {
        let client = EsiClient::with_http(reqwest::Client::new(), "http://127.0.0.1:9".to_string());
        let names = get_asset_names(&client, 7, &[]).await.expect("empty ok");
        assert!(names.is_empty());
    }

    #[tokio::test]
    async fn asset_names_post_parses() {
        let (base, captured) = one_shot_server(
            200,
            r#"[{"item_id":102,"name":"Aria's Rifter"},{"item_id":103,"name":"None"}]"#,
        )
        .await;
        let (client, _dir) = client_with_fresh_tokens(base);
        let names = get_asset_names(&client, 7, &[102, 103])
            .await
            .expect("names");
        assert_eq!(names.len(), 2);
        assert_eq!(names[0].item_id, 102);
        assert_eq!(names[0].name, "Aria's Rifter");
        assert_eq!(names[1].name, "None");
        let request = captured.await.expect("captured");
        assert!(request.contains("assets/names"), "request: {request}");
        assert!(request.contains("[102,103]"), "request: {request}");
    }

    #[tokio::test]
    async fn assets_scope_failure_needs_reauthorize() {
        let (base, _captured) = one_shot_server(403, r#"{"error":"Forbidden"}"#).await;
        let (client, _dir) = client_with_fresh_tokens(base);
        let err = get_assets(&client, 7).await.expect_err("403 must error");
        assert!(needs_reauthorize(&err), "error: {err:?}");
    }

    #[tokio::test]
    async fn structure_lookup_sends_bearer_token_and_parses_name() {
        let (base, captured) = one_shot_server(
            200,
            r#"{"name":"Test Keepstar","solar_system_id":30000142,"type_id":35834}"#,
        )
        .await;
        let (client, _dir) = client_with_fresh_tokens(base);
        let info = get_structure_for_character(&client, 1030000000001, 7)
            .await
            .expect("structure");
        assert_eq!(info.name, "Test Keepstar");
        let request = captured.await.expect("captured");
        assert!(
            request.contains("/universe/structures/1030000000001/"),
            "request: {request}"
        );
        assert!(
            request.contains("Bearer test-access"),
            "authenticated lookup must send the bearer token, request: {request}"
        );
    }

    #[tokio::test]
    async fn structure_scope_failure_needs_reauthorize() {
        let (base, _captured) = one_shot_server(403, r#"{"error":"Forbidden"}"#).await;
        let (client, _dir) = client_with_fresh_tokens(base);
        let err = get_structure_for_character(&client, 1030000000001, 7)
            .await
            .expect_err("403 must error");
        assert!(needs_reauthorize(&err), "error: {err:?}");
    }

    #[derive(Clone, Copy, PartialEq)]
    enum SecondPage {
        Rows,
        Empty,
        Error,
    }

    /// Paged market mock: counts and captures requests, serves one
    /// order row per page (order_id encodes the page), and serves an
    /// unsorted two-day history for `/history/` paths.
    async fn market_server(
        pages_header: Option<u32>,
        second: SecondPage,
    ) -> (
        String,
        std::sync::Arc<std::sync::atomic::AtomicUsize>,
        std::sync::Arc<std::sync::Mutex<Vec<String>>>,
    ) {
        use std::sync::atomic::{AtomicUsize, Ordering};
        let listener = TcpListener::bind("127.0.0.1:0").await.expect("bind");
        let addr = listener.local_addr().expect("addr");
        let counter = std::sync::Arc::new(AtomicUsize::new(0));
        let captured = std::sync::Arc::new(std::sync::Mutex::new(Vec::<String>::new()));
        let task_counter = counter.clone();
        let task_captured = captured.clone();
        tokio::spawn(async move {
            loop {
                let Ok((mut socket, _peer)) = listener.accept().await else {
                    break;
                };
                let counter = task_counter.clone();
                let captured = task_captured.clone();
                tokio::spawn(async move {
                    let mut buffer = vec![0u8; 16384];
                    let count = socket.read(&mut buffer).await.unwrap_or(0);
                    let request = String::from_utf8_lossy(&buffer[..count]).into_owned();
                    counter.fetch_add(1, Ordering::SeqCst);
                    captured.lock().expect("capture lock").push(request.clone());
                    let page: u32 = request
                        .split("page=")
                        .nth(1)
                        .and_then(|rest| {
                            rest.chars()
                                .take_while(|c| c.is_ascii_digit())
                                .collect::<String>()
                                .parse()
                                .ok()
                        })
                        .unwrap_or(1);
                    let (status, body) = if request.contains("/history/") {
                        (
                            200,
                            r#"[{"date":"2026-11-10","average":5.0,"highest":6.0,"lowest":4.0,"order_count":10,"volume":100},{"date":"2026-11-12","average":5.5,"highest":6.5,"lowest":4.5,"order_count":12,"volume":120}]"#
                                .to_string(),
                        )
                    } else if page == 2 && second == SecondPage::Error {
                        (500, r#"{"error":"boom"}"#.to_string())
                    } else if page == 2 && second == SecondPage::Empty {
                        (200, "[]".to_string())
                    } else {
                        (
                            200,
                            format!(
                                r#"[{{"order_id":{},"type_id":34,"region_id":10000002,"location_id":60003760,"system_id":30000142,"price":5.0,"volume_remain":10,"volume_total":10,"min_volume":1,"is_buy_order":false,"issued":"2026-11-01T00:00:00Z","duration":90,"range":"station","is_corporation":false}}]"#,
                                100 + page
                            ),
                        )
                    };
                    let pages = match pages_header {
                        Some(total) => format!("X-Pages: {total}\r\n"),
                        None => String::new(),
                    };
                    let payload = format!(
                        "HTTP/1.1 {status} OK\r\nContent-Type: application/json\r\n{pages}Content-Length: {}\r\nConnection: close\r\n\r\n{body}",
                        body.len()
                    );
                    let _ = socket.write_all(payload.as_bytes()).await;
                    let _ = socket.flush().await;
                });
            }
        });
        (format!("http://{addr}"), counter, captured)
    }

    fn public_client(base: String) -> EsiClient {
        EsiClient::with_http(reqwest::Client::new(), base)
    }

    #[tokio::test]
    async fn regional_orders_walk_two_pages_with_type_id_always_present() {
        use std::sync::atomic::Ordering;
        let (base, counter, captured) = market_server(Some(2), SecondPage::Rows).await;
        // No token store attached: public endpoints must not need one.
        let client = public_client(base);
        let (orders, truncated) = get_regional_orders(&client, 10000002, 34)
            .await
            .expect("orders");
        assert_eq!(orders.len(), 2);
        assert_eq!(orders[0].order_id, 101);
        assert_eq!(orders[1].order_id, 102);
        assert!(!truncated);
        assert_eq!(counter.load(Ordering::SeqCst), 2);
        let requests = captured.lock().expect("capture lock").clone();
        assert_eq!(requests.len(), 2);
        for request in &requests {
            assert!(request.contains("/markets/10000002/orders/"), "{request}");
            assert!(request.contains("type_id=34"), "{request}");
            assert!(request.contains("order_type=all"), "{request}");
        }
        assert!(requests[1].contains("page=2"), "{}", requests[1]);
    }

    #[tokio::test]
    async fn regional_orders_cap_is_honored_and_reported_truncated() {
        use std::sync::atomic::Ordering;
        let (base, counter, _captured) = market_server(Some(5), SecondPage::Rows).await;
        let client = public_client(base);
        let (orders, truncated) = get_regional_orders_capped(&client, 10000002, 34, 2)
            .await
            .expect("orders");
        assert_eq!(orders.len(), 2);
        assert!(truncated);
        assert_eq!(
            counter.load(Ordering::SeqCst),
            2,
            "exactly the capped pages"
        );
    }

    #[tokio::test]
    async fn regional_orders_empty_region_returns_empty_not_truncated() {
        let (base, _captured) = one_shot_server(200, "[]").await;
        let client = public_client(base);
        let (orders, truncated) = get_regional_orders(&client, 10000002, 34)
            .await
            .expect("orders");
        assert!(orders.is_empty());
        assert!(!truncated);
    }

    #[tokio::test]
    async fn regional_orders_missing_xpages_empty_second_page_stops_clean() {
        use std::sync::atomic::Ordering;
        let (base, counter, _captured) = market_server(None, SecondPage::Empty).await;
        let client = public_client(base);
        let (orders, truncated) = get_regional_orders(&client, 10000002, 34)
            .await
            .expect("orders");
        assert_eq!(orders.len(), 1);
        assert!(!truncated);
        assert_eq!(counter.load(Ordering::SeqCst), 2);
    }

    #[tokio::test]
    async fn regional_orders_missing_xpages_nonempty_at_cap_is_truncated() {
        let (base, _counter, _captured) = market_server(None, SecondPage::Rows).await;
        let client = public_client(base);
        let (orders, truncated) = get_regional_orders_capped(&client, 10000002, 34, 2)
            .await
            .expect("orders");
        assert_eq!(orders.len(), 2);
        assert!(truncated);
    }

    #[tokio::test]
    async fn regional_orders_page_two_error_propagates() {
        let (base, _counter, _captured) = market_server(Some(2), SecondPage::Error).await;
        let client = public_client(base);
        let err = get_regional_orders(&client, 10000002, 34)
            .await
            .expect_err("page-2 failure must not return partial rows");
        assert!(!needs_reauthorize(&err), "error: {err:?}");
    }

    #[tokio::test]
    async fn market_history_is_one_request_and_returns_rows_unsorted() {
        use std::sync::atomic::Ordering;
        let (base, counter, captured) = market_server(None, SecondPage::Rows).await;
        let client = public_client(base);
        let history = get_market_history(&client, 10000002, 34)
            .await
            .expect("history");
        assert_eq!(history.len(), 2);
        assert_eq!(history[0].date, "2026-11-10");
        assert_eq!(history[1].date, "2026-11-12");
        assert_eq!(counter.load(Ordering::SeqCst), 1);
        let requests = captured.lock().expect("capture lock").clone();
        assert!(
            requests[0].contains("/markets/10000002/history/"),
            "{}",
            requests[0]
        );
        assert!(requests[0].contains("type_id=34"), "{}", requests[0]);
    }

    #[tokio::test]
    async fn character_orders_single_request_without_xpages_never_duplicates() {
        use std::sync::atomic::Ordering;
        let (base, counter, captured) = market_server(None, SecondPage::Rows).await;
        let (client, _dir) = client_with_fresh_tokens(base);
        let (orders, truncated) = get_character_orders(&client, 7).await.expect("orders");
        assert_eq!(counter.load(Ordering::SeqCst), 1);
        assert_eq!(orders.len(), 1);
        assert_eq!(orders[0].order_id, 101);
        assert!(!truncated);
        let requests = captured.lock().expect("capture lock").clone();
        assert_eq!(requests.len(), 1);
        assert!(
            requests[0].contains("/characters/7/orders/"),
            "{}",
            requests[0]
        );
        assert!(!requests[0].contains("page="), "{}", requests[0]);
    }

    #[tokio::test]
    async fn character_orders_http_error_propagates() {
        let (base, _captured) = one_shot_server(500, r#"{"error":"boom"}"#).await;
        let (client, _dir) = client_with_fresh_tokens(base);
        let err = get_character_orders(&client, 7)
            .await
            .expect_err("500 must error");
        assert!(!needs_reauthorize(&err), "error: {err:?}");
    }

    #[tokio::test]
    async fn character_orders_scope_failure_needs_reauthorize() {
        let (base, _captured) = one_shot_server(403, r#"{"error":"Forbidden"}"#).await;
        let (client, _dir) = client_with_fresh_tokens(base);
        let err = get_character_orders(&client, 7)
            .await
            .expect_err("403 must error");
        assert!(needs_reauthorize(&err), "error: {err:?}");
    }

    /// Paged industry mock: counts and captures requests and
    /// serves one row per page (the row id encodes the page),
    /// blueprints or jobs chosen by the request path.
    async fn industry_server(
        pages_header: Option<u32>,
        second: SecondPage,
    ) -> (
        String,
        std::sync::Arc<std::sync::atomic::AtomicUsize>,
        std::sync::Arc<std::sync::Mutex<Vec<String>>>,
    ) {
        use std::sync::atomic::{AtomicUsize, Ordering};
        let listener = TcpListener::bind("127.0.0.1:0").await.expect("bind");
        let addr = listener.local_addr().expect("addr");
        let counter = std::sync::Arc::new(AtomicUsize::new(0));
        let captured = std::sync::Arc::new(std::sync::Mutex::new(Vec::<String>::new()));
        let task_counter = counter.clone();
        let task_captured = captured.clone();
        tokio::spawn(async move {
            loop {
                let Ok((mut socket, _peer)) = listener.accept().await else {
                    break;
                };
                let counter = task_counter.clone();
                let captured = task_captured.clone();
                tokio::spawn(async move {
                    let mut buffer = vec![0u8; 16384];
                    let count = socket.read(&mut buffer).await.unwrap_or(0);
                    let request = String::from_utf8_lossy(&buffer[..count]).into_owned();
                    counter.fetch_add(1, Ordering::SeqCst);
                    captured.lock().expect("capture lock").push(request.clone());
                    let page: u32 = request
                        .split("page=")
                        .nth(1)
                        .and_then(|rest| {
                            rest.chars()
                                .take_while(|c| c.is_ascii_digit())
                                .collect::<String>()
                                .parse()
                                .ok()
                        })
                        .unwrap_or(1);
                    let (status, body) = if page == 2 && second == SecondPage::Error {
                        (500, r#"{"error":"boom"}"#.to_string())
                    } else if page == 2 && second == SecondPage::Empty {
                        (200, "[]".to_string())
                    } else if request.contains("/blueprints/") {
                        (
                            200,
                            format!(
                                r#"[{{"item_id":{},"type_id":681,"location_id":60003760,"location_flag":"Hangar","quantity":-1,"time_efficiency":0,"material_efficiency":0,"runs":-1}}]"#,
                                100 + page
                            ),
                        )
                    } else {
                        (
                            200,
                            format!(
                                r#"[{{"job_id":{},"facility_id":60003760,"activity_id":1,"blueprint_type_id":681,"product_type_id":587,"status":"active","start_date":"2026-11-14T10:00:00Z","end_date":"2026-11-15T11:00:00Z"}}]"#,
                                100 + page
                            ),
                        )
                    };
                    let pages = match pages_header {
                        Some(total) => format!("X-Pages: {total}\r\n"),
                        None => String::new(),
                    };
                    let payload = format!(
                        "HTTP/1.1 {status} OK\r\nContent-Type: application/json\r\n{pages}Content-Length: {}\r\nConnection: close\r\n\r\n{body}",
                        body.len()
                    );
                    let _ = socket.write_all(payload.as_bytes()).await;
                    let _ = socket.flush().await;
                });
            }
        });
        (format!("http://{addr}"), counter, captured)
    }

    #[tokio::test]
    async fn blueprints_walk_two_pages_in_fetch_order() {
        let (base, _counter, captured) = industry_server(Some(2), SecondPage::Rows).await;
        let (client, _dir) = client_with_fresh_tokens(base);
        let (blueprints, truncated) = get_character_blueprints(&client, 7)
            .await
            .expect("blueprints");
        assert_eq!(blueprints.len(), 2);
        assert_eq!(blueprints[0].item_id, 101);
        assert_eq!(blueprints[1].item_id, 102);
        assert_eq!(blueprints[0].quantity, -1);
        assert_eq!(blueprints[0].runs, -1);
        assert!(!truncated);
        let requests = captured.lock().expect("capture lock").clone();
        assert_eq!(requests.len(), 2);
        assert!(
            requests[0].contains("/characters/7/blueprints/"),
            "{}",
            requests[0]
        );
        assert!(requests[1].contains("page=2"), "{}", requests[1]);
    }

    #[tokio::test]
    async fn industry_jobs_single_page_embeds_include_completed_true() {
        use std::sync::atomic::Ordering;
        let (base, counter, captured) = industry_server(Some(1), SecondPage::Rows).await;
        let (client, _dir) = client_with_fresh_tokens(base);
        let (jobs, truncated) = get_character_industry_jobs(&client, 7).await.expect("jobs");
        assert_eq!(jobs.len(), 1);
        assert_eq!(jobs[0].job_id, 101);
        assert_eq!(jobs[0].status, "active");
        assert_eq!(jobs[0].product_type_id, Some(587));
        assert!(!truncated);
        assert_eq!(counter.load(Ordering::SeqCst), 1);
        let requests = captured.lock().expect("capture lock").clone();
        assert!(
            requests[0].contains("/characters/7/industry/jobs/"),
            "{}",
            requests[0]
        );
        assert!(
            requests[0].contains("include_completed=true"),
            "{}",
            requests[0]
        );
    }

    #[tokio::test]
    async fn industry_jobs_single_request_without_xpages_never_duplicates() {
        use std::sync::atomic::Ordering;
        let (base, counter, captured) = industry_server(None, SecondPage::Rows).await;
        let (client, _dir) = client_with_fresh_tokens(base);
        let (jobs, truncated) = get_character_industry_jobs(&client, 7).await.expect("jobs");
        assert_eq!(counter.load(Ordering::SeqCst), 1);
        assert_eq!(jobs.len(), 1);
        assert_eq!(jobs[0].job_id, 101);
        assert!(!truncated);
        let requests = captured.lock().expect("capture lock").clone();
        assert_eq!(requests.len(), 1);
        assert!(!requests[0].contains("page="), "{}", requests[0]);
        assert!(
            requests[0].contains("include_completed=true"),
            "{}",
            requests[0]
        );
    }

    #[tokio::test]
    async fn blueprints_cap_is_honored_and_reported_truncated() {
        use std::sync::atomic::Ordering;
        let (base, counter, _captured) = industry_server(Some(5), SecondPage::Rows).await;
        let (client, _dir) = client_with_fresh_tokens(base);
        let (blueprints, truncated) = get_character_blueprints_capped(&client, 7, 2)
            .await
            .expect("blueprints");
        assert_eq!(blueprints.len(), 2);
        assert!(truncated);
        assert_eq!(counter.load(Ordering::SeqCst), 2);
    }

    #[tokio::test]
    async fn industry_empty_returns_empty_not_truncated() {
        let (base, _captured) = one_shot_server(200, "[]").await;
        let (client, _dir) = client_with_fresh_tokens(base);
        let (jobs, truncated) = get_character_industry_jobs(&client, 7).await.expect("jobs");
        assert!(jobs.is_empty());
        assert!(!truncated);

        let (base, _captured) = one_shot_server(200, "[]").await;
        let (client, _dir) = client_with_fresh_tokens(base);
        let (blueprints, truncated) = get_character_blueprints(&client, 7)
            .await
            .expect("blueprints");
        assert!(blueprints.is_empty());
        assert!(!truncated);
    }

    #[tokio::test]
    async fn industry_missing_xpages_empty_second_page_stops_clean() {
        use std::sync::atomic::Ordering;
        let (base, counter, _captured) = industry_server(None, SecondPage::Empty).await;
        let (client, _dir) = client_with_fresh_tokens(base);
        let (blueprints, truncated) = get_character_blueprints(&client, 7)
            .await
            .expect("blueprints");
        assert_eq!(blueprints.len(), 1);
        assert!(!truncated);
        assert_eq!(counter.load(Ordering::SeqCst), 2);
    }

    #[tokio::test]
    async fn industry_missing_xpages_nonempty_at_cap_is_truncated() {
        let (base, _counter, _captured) = industry_server(None, SecondPage::Rows).await;
        let (client, _dir) = client_with_fresh_tokens(base);
        let (blueprints, truncated) = get_character_blueprints_capped(&client, 7, 2)
            .await
            .expect("blueprints");
        assert_eq!(blueprints.len(), 2);
        assert!(truncated);
    }

    #[tokio::test]
    async fn industry_errors_propagate() {
        let (base, _captured) = one_shot_server(500, r#"{"error":"boom"}"#).await;
        let (client, _dir) = client_with_fresh_tokens(base);
        let err = get_character_industry_jobs(&client, 7)
            .await
            .expect_err("500 must error");
        assert!(!needs_reauthorize(&err), "error: {err:?}");

        let (base, _counter, _captured) = industry_server(Some(2), SecondPage::Error).await;
        let (client, _dir) = client_with_fresh_tokens(base);
        let err = get_character_blueprints(&client, 7)
            .await
            .expect_err("page-2 failure must not return partial rows");
        assert!(!needs_reauthorize(&err), "error: {err:?}");
    }

    #[tokio::test]
    async fn industry_scope_failures_need_reauthorize() {
        let (base, _captured) = one_shot_server(403, r#"{"error":"Forbidden"}"#).await;
        let (client, _dir) = client_with_fresh_tokens(base);
        let err = get_character_industry_jobs(&client, 7)
            .await
            .expect_err("403 must error");
        assert!(needs_reauthorize(&err), "error: {err:?}");

        let (base, _captured) = one_shot_server(403, r#"{"error":"Forbidden"}"#).await;
        let (client, _dir) = client_with_fresh_tokens(base);
        let err = get_character_blueprints(&client, 7)
            .await
            .expect_err("403 must error");
        assert!(needs_reauthorize(&err), "error: {err:?}");
    }

    #[tokio::test]
    async fn industry_no_tokens_error_carries_no_character_id_text() {
        let client = EsiClient::with_http(reqwest::Client::new(), "http://127.0.0.1:9".to_string());
        let err = get_character_industry_jobs(&client, 90000001)
            .await
            .expect_err("no tokens must error");
        assert!(!err.to_string().contains("90000001"), "error: {err}");
        let err = get_character_blueprints(&client, 90000001)
            .await
            .expect_err("no tokens must error");
        assert!(!err.to_string().contains("90000001"), "error: {err}");
    }

    #[tokio::test]
    async fn colonies_list_parses_in_fetch_order() {
        let (base, captured) = one_shot_server(
            200,
            r#"[{"planet_id":700000001,"planet_type":"temperate","solar_system_id":30000142,"last_update":"2026-11-14T10:00:00Z","upgrade_level":2,"num_pins":9},{"planet_id":700000002,"planet_type":"oceanic","solar_system_id":30002187,"last_update":"2026-11-13T09:00:00Z","upgrade_level":1,"num_pins":4}]"#,
        )
        .await;
        let (client, _dir) = client_with_fresh_tokens(base);
        let colonies = get_character_planets(&client, 7).await.expect("colonies");
        assert_eq!(colonies.len(), 2);
        assert_eq!(colonies[0].planet_id, 700000001);
        assert_eq!(colonies[0].planet_type, "temperate");
        assert_eq!(colonies[0].solar_system_id, 30000142);
        assert_eq!(colonies[0].num_pins, 9);
        assert_eq!(colonies[1].planet_id, 700000002);
        let request = captured.await.expect("captured");
        assert!(
            request.contains("/characters/7/planets/"),
            "request: {request}"
        );
    }

    #[tokio::test]
    async fn colonies_empty_list_returns_empty() {
        let (base, _captured) = one_shot_server(200, "[]").await;
        let (client, _dir) = client_with_fresh_tokens(base);
        let colonies = get_character_planets(&client, 7).await.expect("colonies");
        assert!(colonies.is_empty());
    }

    #[tokio::test]
    async fn colony_detail_parses_pins_extractor_and_contents() {
        let (base, captured) = one_shot_server(
            200,
            r#"{"pins":[{"pin_id":700000011,"type_id":20001,"latitude":0.5,"longitude":-0.25,"install_time":"2026-11-01T08:00:00Z","expiry_time":"2026-11-21T08:00:00Z","last_cycle_start":"2026-11-14T10:00:00Z","schematic_id":15462,"extractor_details":{"product_type_id":34,"qty_per_cycle":120,"cycle_time":7200},"contents":[{"type_id":35,"amount":500}]}],"links":[{"source_pin_id":700000011,"destination_pin_id":700000012}],"routes":[{"source_pin_id":700000011,"destination_pin_id":700000012,"route_type":"basic"}]}"#,
        )
        .await;
        let (client, _dir) = client_with_fresh_tokens(base);
        let detail = get_character_planet(&client, 7, 700000001)
            .await
            .expect("detail");
        assert_eq!(detail.pins.len(), 1);
        let pin = &detail.pins[0];
        assert_eq!(pin.pin_id, 700000011);
        assert_eq!(pin.type_id, 20001);
        let extractor = pin.extractor_details.as_ref().expect("extractor");
        assert_eq!(extractor.product_type_id, Some(34));
        assert_eq!(extractor.qty_per_cycle, Some(120));
        assert_eq!(extractor.cycle_time, Some(7200));
        assert_eq!(pin.contents.len(), 1);
        assert_eq!(pin.contents[0].type_id, 35);
        assert_eq!(pin.contents[0].amount, 500);
        assert_eq!(detail.links.len(), 1);
        assert_eq!(detail.routes.len(), 1);
        let request = captured.await.expect("captured");
        assert!(
            request.contains("/characters/7/planets/700000001/"),
            "request: {request}"
        );
    }

    #[tokio::test]
    async fn colony_detail_optional_pin_fields_default() {
        let (base, _captured) = one_shot_server(
            200,
            r#"{"pins":[{"pin_id":700000021,"type_id":20003,"latitude":0.1,"longitude":0.2,"install_time":"2026-11-02T08:00:00Z"}]}"#,
        )
        .await;
        let (client, _dir) = client_with_fresh_tokens(base);
        let detail = get_character_planet(&client, 7, 700000001)
            .await
            .expect("detail");
        assert_eq!(detail.pins.len(), 1);
        let pin = &detail.pins[0];
        assert_eq!(pin.expiry_time, None);
        assert_eq!(pin.last_cycle_start, None);
        assert_eq!(pin.schematic_id, None);
        assert!(pin.extractor_details.is_none());
        assert!(pin.contents.is_empty());
        assert!(detail.links.is_empty());
        assert!(detail.routes.is_empty());
    }

    #[tokio::test]
    async fn colonies_scope_failure_needs_reauthorize() {
        let (base, _captured) = one_shot_server(403, r#"{"error":"Forbidden"}"#).await;
        let (client, _dir) = client_with_fresh_tokens(base);
        let err = get_character_planets(&client, 7)
            .await
            .expect_err("403 must error");
        assert!(needs_reauthorize(&err), "error: {err:?}");

        let (base, _captured) = one_shot_server(403, r#"{"error":"Forbidden"}"#).await;
        let (client, _dir) = client_with_fresh_tokens(base);
        let err = get_character_planet(&client, 7, 700000001)
            .await
            .expect_err("403 must error");
        assert!(needs_reauthorize(&err), "error: {err:?}");
    }

    #[tokio::test]
    async fn colony_no_tokens_error_carries_no_character_id_text() {
        let client = EsiClient::with_http(reqwest::Client::new(), "http://127.0.0.1:9".to_string());
        let err = get_character_planets(&client, 90000001)
            .await
            .expect_err("no tokens must error");
        assert!(!err.to_string().contains("90000001"), "error: {err}");
        let err = get_character_planet(&client, 90000001, 700000001)
            .await
            .expect_err("no tokens must error");
        assert!(!err.to_string().contains("90000001"), "error: {err}");
    }

    #[tokio::test]
    async fn fittings_list_parses_in_fetch_order() {
        let (base, captured) = one_shot_server(
            200,
            r#"[{"fitting_id":1,"name":"Demo Brawler","description":"Sample close-range fit","ship_type_id":587,"items":[{"flag":"LoSlot0","quantity":1,"type_id":2048},{"flag":"DroneBay","quantity":5,"type_id":2456}]},{"fitting_id":2,"name":"Mission Runner","description":null,"ship_type_id":597,"items":[{"flag":"HiSlot0","quantity":1,"type_id":2048},{"flag":"Cargo","quantity":-3,"type_id":36}]}]"#,
        )
        .await;
        let (client, _dir) = client_with_fresh_tokens(base);
        let fittings = get_character_fittings(&client, 7).await.expect("fittings");
        assert_eq!(fittings.len(), 2);
        assert_eq!(fittings[0].fitting_id, 1);
        assert_eq!(fittings[0].name, "Demo Brawler");
        assert_eq!(
            fittings[0].description.as_deref(),
            Some("Sample close-range fit")
        );
        assert_eq!(fittings[0].ship_type_id, 587);
        assert_eq!(fittings[0].items.len(), 2);
        assert_eq!(fittings[0].items[0].flag, "LoSlot0");
        assert_eq!(fittings[0].items[0].type_id, 2048);
        assert_eq!(fittings[0].items[1].flag, "DroneBay");
        assert_eq!(fittings[0].items[1].quantity, 5);
        assert_eq!(fittings[1].fitting_id, 2);
        assert_eq!(fittings[1].name, "Mission Runner");
        assert_eq!(fittings[1].description, None);
        assert_eq!(fittings[1].ship_type_id, 597);
        // Negative wire quantity parses unchanged; clamping is downstream.
        assert_eq!(fittings[1].items[1].quantity, -3);
        let request = captured.await.expect("captured");
        assert!(
            request.contains("/characters/7/fittings/"),
            "request: {request}"
        );
    }

    #[tokio::test]
    async fn fittings_empty_list_returns_empty() {
        let (base, _captured) = one_shot_server(200, "[]").await;
        let (client, _dir) = client_with_fresh_tokens(base);
        let fittings = get_character_fittings(&client, 7).await.expect("fittings");
        assert!(fittings.is_empty());
    }

    #[tokio::test]
    async fn fittings_scope_failure_needs_reauthorize() {
        let (base, _captured) = one_shot_server(403, r#"{"error":"Forbidden"}"#).await;
        let (client, _dir) = client_with_fresh_tokens(base);
        let err = get_character_fittings(&client, 7)
            .await
            .expect_err("403 must error");
        assert!(needs_reauthorize(&err), "error: {err:?}");
    }

    #[tokio::test]
    async fn fittings_server_error_does_not_need_reauthorize() {
        let (base, _captured) = one_shot_server(500, r#"{"error":"boom"}"#).await;
        let (client, _dir) = client_with_fresh_tokens(base);
        let err = get_character_fittings(&client, 7)
            .await
            .expect_err("500 must error");
        assert!(!needs_reauthorize(&err), "error: {err:?}");
    }

    #[tokio::test]
    async fn fittings_malformed_body_errors_without_panic() {
        let (base, _captured) = one_shot_server(200, "not-json{").await;
        let (client, _dir) = client_with_fresh_tokens(base);
        let err = get_character_fittings(&client, 7)
            .await
            .expect_err("malformed body must error");
        assert!(!needs_reauthorize(&err), "error: {err:?}");
    }

    #[tokio::test]
    async fn fittings_no_tokens_error_carries_no_character_id_text() {
        let client = EsiClient::with_http(reqwest::Client::new(), "http://127.0.0.1:9".to_string());
        let err = get_character_fittings(&client, 90000001)
            .await
            .expect_err("no tokens must error");
        assert!(!err.to_string().contains("90000001"), "error: {err}");
    }

    #[test]
    fn reauthorize_detection() {
        let err = crate::error::AppError::from(EsiError::Reauthorize);
        assert!(needs_reauthorize(&err));
        let other = crate::error::AppError::from(EsiError::Status(500));
        assert!(!needs_reauthorize(&other));
    }

    fn sample_save_request() -> SaveFittingRequest {
        SaveFittingRequest {
            name: "My Rifter".to_string(),
            description: "Saved from Mimir".to_string(),
            ship_type_id: 587,
            items: vec![
                FittingItem {
                    flag: "LoSlot0".to_string(),
                    quantity: 1,
                    type_id: 2048,
                },
                FittingItem {
                    flag: "DroneBay".to_string(),
                    quantity: 5,
                    type_id: 2456,
                },
            ],
        }
    }

    #[tokio::test]
    async fn fitting_save_posts_exact_body_and_parses_id() {
        let (base, captured) = one_shot_server(201, r#"{"fitting_id":4242}"#).await;
        let (client, _dir) = client_with_fresh_tokens(base);
        let response = save_character_fitting(&client, 7, &sample_save_request())
            .await
            .expect("save");
        assert_eq!(response.fitting_id, 4242);
        let request = captured.await.expect("captured");
        assert!(
            request.starts_with("POST /characters/7/fittings/?datasource=tranquility"),
            "request: {request}"
        );
        assert!(
            request.to_lowercase().contains("authorization: bearer "),
            "request must carry the bearer header: {request}"
        );
        assert!(
            request
                .to_lowercase()
                .contains("content-type: application/json"),
            "request must be JSON: {request}"
        );
        let body = request.split("\r\n\r\n").nth(1).expect("body present");
        assert_eq!(
            body,
            r#"{"name":"My Rifter","description":"Saved from Mimir","ship_type_id":587,"items":[{"flag":"LoSlot0","quantity":1,"type_id":2048},{"flag":"DroneBay","quantity":5,"type_id":2456}]}"#
        );
    }

    #[tokio::test]
    async fn fitting_delete_sends_delete_and_accepts_204_empty() {
        let (base, captured) = one_shot_server(204, "").await;
        let (client, _dir) = client_with_fresh_tokens(base);
        delete_character_fitting(&client, 7, 4242)
            .await
            .expect("delete");
        let request = captured.await.expect("captured");
        assert!(
            request.starts_with("DELETE /characters/7/fittings/4242/?datasource=tranquility"),
            "request: {request}"
        );
        assert!(
            request.to_lowercase().contains("authorization: bearer "),
            "request must carry the bearer header: {request}"
        );
        let body = request
            .split("\r\n\r\n")
            .nth(1)
            .expect("terminator present");
        assert_eq!(body, "", "delete carries no body, request: {request}");
    }

    #[tokio::test]
    async fn fitting_save_scope_failures_classify_as_definitive_reauthorize() {
        for status in [401u16, 403] {
            let (base, _captured) = one_shot_server(status, r#"{"error":"Forbidden"}"#).await;
            let (client, _dir) = client_with_fresh_tokens(base);
            let err = save_character_fitting(&client, 7, &sample_save_request())
                .await
                .expect_err("scope failure must error");
            assert_eq!(
                classify_write_error(&err, false),
                (WriteFailureClass::Definitive, true),
                "status {status} error: {err:?}"
            );
        }
        let (base, _captured) = one_shot_server(403, r#"{"error":"Forbidden"}"#).await;
        let (client, _dir) = client_with_fresh_tokens(base);
        let err = delete_character_fitting(&client, 7, 4242)
            .await
            .expect_err("scope failure must error");
        assert_eq!(
            classify_write_error(&err, true),
            (WriteFailureClass::Definitive, true),
            "delete 403 error: {err:?}"
        );
    }

    #[tokio::test]
    async fn fitting_save_server_error_classifies_unknown() {
        let (base, _captured) = one_shot_server(500, r#"{"error":"boom"}"#).await;
        let (client, _dir) = client_with_fresh_tokens(base);
        let err = save_character_fitting(&client, 7, &sample_save_request())
            .await
            .expect_err("500 must error");
        assert_eq!(
            classify_write_error(&err, false),
            (WriteFailureClass::Unknown, false),
            "error: {err:?}"
        );
    }

    #[tokio::test]
    async fn fitting_delete_404_is_already_gone_but_save_404_is_definitive() {
        let (base, _captured) = one_shot_server(404, r#"{"error":"gone"}"#).await;
        let (client, _dir) = client_with_fresh_tokens(base);
        let err = delete_character_fitting(&client, 7, 4242)
            .await
            .expect_err("404 must error");
        assert_eq!(
            classify_write_error(&err, true),
            (WriteFailureClass::AlreadyGone, false),
            "error: {err:?}"
        );
        let (base, _captured) = one_shot_server(404, r#"{"error":"gone"}"#).await;
        let (client, _dir) = client_with_fresh_tokens(base);
        let err = save_character_fitting(&client, 7, &sample_save_request())
            .await
            .expect_err("404 must error");
        assert_eq!(
            classify_write_error(&err, false),
            (WriteFailureClass::Definitive, false),
            "error: {err:?}"
        );
    }

    #[tokio::test]
    async fn fitting_save_rate_limited_classifies_rate_limited() {
        let (base, _captured) = one_shot_server(420, r#"{"error":"slow down"}"#).await;
        let (client, _dir) = client_with_fresh_tokens(base);
        let err = save_character_fitting(&client, 7, &sample_save_request())
            .await
            .expect_err("420 must error");
        assert_eq!(
            classify_write_error(&err, false),
            (WriteFailureClass::RateLimited { reset_secs: 0 }, false),
            "error: {err:?}"
        );
    }

    #[tokio::test]
    async fn fitting_save_malformed_success_body_classifies_unknown() {
        for body in ["{}", "not json"] {
            let (base, _captured) = one_shot_server(201, body).await;
            let (client, _dir) = client_with_fresh_tokens(base);
            let err = save_character_fitting(&client, 7, &sample_save_request())
                .await
                .expect_err("malformed receipt must error");
            assert_eq!(
                classify_write_error(&err, false),
                (WriteFailureClass::Unknown, false),
                "body {body} error: {err:?}"
            );
        }
    }

    #[tokio::test]
    async fn fitting_writes_without_tokens_are_not_sent_and_carry_no_id_text() {
        let client = EsiClient::with_http(reqwest::Client::new(), "http://127.0.0.1:9".to_string());
        let err = save_character_fitting(&client, 90000001, &sample_save_request())
            .await
            .expect_err("no tokens must error");
        assert_eq!(
            classify_write_error(&err, false),
            (WriteFailureClass::NotSent, true),
            "error: {err:?}"
        );
        assert!(!err.to_string().contains("90000001"), "error: {err}");
        let err = delete_character_fitting(&client, 90000001, 4242)
            .await
            .expect_err("no tokens must error");
        assert_eq!(
            classify_write_error(&err, true),
            (WriteFailureClass::NotSent, true),
            "error: {err:?}"
        );
        assert!(!err.to_string().contains("90000001"), "error: {err}");
    }

    #[test]
    fn classify_write_error_covers_every_row() {
        use crate::error::{AppError, AuthError};
        let assert_class = |err: AppError, is_delete: bool, expected: (WriteFailureClass, bool)| {
            assert_eq!(
                classify_write_error(&err, is_delete),
                expected,
                "error: {err:?}"
            );
        };
        assert_class(
            AppError::from(EsiError::Unauthorized),
            false,
            (WriteFailureClass::Definitive, true),
        );
        assert_class(
            AppError::from(EsiError::Reauthorize),
            true,
            (WriteFailureClass::Definitive, true),
        );
        assert_class(
            AppError::from(EsiError::NotFound("gone".to_string())),
            true,
            (WriteFailureClass::AlreadyGone, false),
        );
        assert_class(
            AppError::from(EsiError::NotFound("gone".to_string())),
            false,
            (WriteFailureClass::Definitive, false),
        );
        assert_class(
            AppError::from(EsiError::RateLimited { reset_secs: 42 }),
            false,
            (WriteFailureClass::RateLimited { reset_secs: 42 }, false),
        );
        assert_class(
            AppError::from(EsiError::ErrorLimitExhausted { reset_secs: 7 }),
            true,
            (WriteFailureClass::RateLimited { reset_secs: 7 }, false),
        );
        assert_class(
            AppError::from(EsiError::Status(400)),
            false,
            (WriteFailureClass::Definitive, false),
        );
        assert_class(
            AppError::from(EsiError::StatusMessage(422, "bad".to_string())),
            false,
            (WriteFailureClass::Definitive, false),
        );
        // 500 is the boundary: a `< 500` vs `<= 500` flip fails here.
        assert_class(
            AppError::from(EsiError::Status(500)),
            false,
            (WriteFailureClass::Unknown, false),
        );
        assert_class(
            AppError::from(EsiError::Status(503)),
            false,
            (WriteFailureClass::Unknown, false),
        );
        assert_class(
            AppError::from(EsiError::NoTokens(7)),
            false,
            (WriteFailureClass::NotSent, true),
        );
        assert_class(
            AppError::from(EsiError::Decode("bad".to_string())),
            false,
            (WriteFailureClass::Unknown, false),
        );
        assert_class(
            AppError::from(EsiError::NotWired("x".to_string())),
            false,
            (WriteFailureClass::NotSent, false),
        );
        assert_class(
            AppError::from(EsiError::Message("x".to_string())),
            false,
            (WriteFailureClass::NotSent, false),
        );
        assert_class(
            AppError::from(AuthError::RefreshRejected),
            false,
            (WriteFailureClass::NotSent, true),
        );
        assert_class(
            AppError::from(AuthError::Message("x".to_string())),
            true,
            (WriteFailureClass::NotSent, false),
        );
        let db = rusqlite::Connection::open(":memory:")
            .expect("memory db")
            .prepare("select * from no_such_table")
            .expect_err("missing table must error");
        assert_class(
            AppError::from(db),
            false,
            (WriteFailureClass::NotSent, false),
        );
        assert_class(
            AppError::from(std::io::Error::other("boom")),
            false,
            (WriteFailureClass::NotSent, false),
        );
        assert_class(
            AppError::from(serde_json::from_str::<serde_json::Value>("{").expect_err("bad json")),
            false,
            (WriteFailureClass::NotSent, false),
        );
        assert_class(
            AppError::from("http://[::1".parse::<url::Url>().expect_err("bad url")),
            false,
            (WriteFailureClass::NotSent, false),
        );
        assert_class(
            AppError::Message("x".to_string()),
            false,
            (WriteFailureClass::NotSent, false),
        );
    }

    #[tokio::test]
    async fn classify_write_error_http_transport_is_unknown() {
        // Unreachable server: the request fails in transport with
        // no stored tokens involved (fresh tokens are seeded, so
        // the failure is the connection itself).
        let (client, _dir) = client_with_fresh_tokens("http://127.0.0.1:9".to_string());
        let err = save_character_fitting(&client, 7, &sample_save_request())
            .await
            .expect_err("unreachable must error");
        assert_eq!(
            classify_write_error(&err, false),
            (WriteFailureClass::Unknown, false),
            "error: {err:?}"
        );
    }

    #[tokio::test]
    async fn unbounded_pagination_stops_at_cap_when_x_pages_missing() {
        let listener = TcpListener::bind("127.0.0.1:0").await.expect("bind");
        let addr = listener.local_addr().expect("addr");
        tokio::spawn(async move {
            loop {
                let Ok((mut socket, _)) = listener.accept().await else {
                    break;
                };
                tokio::spawn(async move {
                    let mut buf = vec![0u8; 4096];
                    let _ = socket.read(&mut buf).await;
                    let req = String::from_utf8_lossy(&buf);
                    let body = if req.contains("/assets/") {
                        r#"[{"item_id":1,"type_id":34,"quantity":1,"location_id":60003760,"location_type":"station","location_flag":"Hangar","is_singleton":false}]"#
                    } else {
                        r#"[{"id":1,"amount":10.0,"balance":10.0,"date":"d","description":"x","ref_type":"a"}]"#
                    };
                    let payload = format!(
                        "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{body}",
                        body.len()
                    );
                    let _ = socket.write_all(payload.as_bytes()).await;
                    let _ = socket.flush().await;
                });
            }
        });
        let (client, _dir) = client_with_fresh_tokens(format!("http://{addr}"));
        let journal = get_wallet_journal(&client, 7)
            .await
            .expect("journal stops at cap");
        assert_eq!(journal.len(), UNBOUNDED_PAGE_CAP as usize);
        let assets = get_assets(&client, 7).await.expect("assets stop at cap");
        assert_eq!(assets.len(), UNBOUNDED_PAGE_CAP as usize);
    }
}
