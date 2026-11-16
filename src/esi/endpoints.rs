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

/// Full wallet journal: walks pages until `X-Pages`/an empty page ends it.
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
            None => count == 0,
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
/// ends it. Any page error (including the 403 scope failure) propagates;
/// partial asset lists are never returned as success.
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
            None => count == 0,
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

/// The character's own open orders. Requires scope
/// `esi-markets.read_character_orders.v1` (progressive step-up,
/// never first-auth); a missing scope surfaces as HTTP 403 →
/// `EsiError::Reauthorize`. Any page error propagates; partial page
/// lists are never returned as success.
pub async fn get_character_orders(
    client: &EsiClient,
    character_id: i64,
) -> AppResult<(Vec<CharacterOrder>, bool)> {
    get_character_orders_capped(client, character_id, MARKET_MAX_PAGES).await
}

async fn get_character_orders_capped(
    client: &EsiClient,
    character_id: i64,
    max_pages: u32,
) -> AppResult<(Vec<CharacterOrder>, bool)> {
    let max_pages = max_pages.max(1);
    tracing::debug!(
        "[MARKET] GET /characters/{}/orders/ (capped pages={})",
        character_id,
        max_pages
    );
    let mut page = 1u32;
    let mut all: Vec<CharacterOrder> = Vec::new();
    let mut truncated = false;
    loop {
        let (items, meta) = client
            .auth_get_page::<Vec<CharacterOrder>>(
                &format!("/characters/{character_id}/orders/"),
                character_id,
                Some(page),
            )
            .await?;
        let count = items.len();
        tracing::debug!(
            "[MARKET] character orders page={} rows={} total={}",
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
        "[MARKET] character orders fetched character_id={} rows={} truncated={}",
        character_id,
        all.len(),
        truncated
    );
    Ok((all, truncated))
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

/// Structure lookup without a character context (public attempt; live ESI
/// usually 401s). Prefer `get_structure_for_character`.
pub async fn get_structure(client: &EsiClient, structure_id: i64) -> AppResult<StructureInfo> {
    tracing::debug!("[ESI] GET /universe/structures/{}/", structure_id);
    client
        .public_get(&format!("/universe/structures/{structure_id}/"))
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
    async fn character_orders_walk_pages() {
        let (base, _counter, captured) = market_server(Some(2), SecondPage::Rows).await;
        let (client, _dir) = client_with_fresh_tokens(base);
        let (orders, truncated) = get_character_orders(&client, 7).await.expect("orders");
        assert_eq!(orders.len(), 2);
        assert_eq!(orders[0].order_id, 101);
        assert_eq!(orders[1].order_id, 102);
        assert!(!truncated);
        let requests = captured.lock().expect("capture lock").clone();
        assert!(
            requests[0].contains("/characters/7/orders/"),
            "{}",
            requests[0]
        );
        assert!(requests[1].contains("page=2"), "{}", requests[1]);
    }

    #[tokio::test]
    async fn character_orders_cap_is_honored_and_reported_truncated() {
        use std::sync::atomic::Ordering;
        let (base, counter, _captured) = market_server(Some(5), SecondPage::Rows).await;
        let (client, _dir) = client_with_fresh_tokens(base);
        let (orders, truncated) = get_character_orders_capped(&client, 7, 2)
            .await
            .expect("orders");
        assert_eq!(orders.len(), 2);
        assert!(truncated);
        assert_eq!(counter.load(Ordering::SeqCst), 2);
    }

    #[tokio::test]
    async fn character_orders_page_two_error_propagates() {
        let (base, _counter, _captured) = market_server(Some(2), SecondPage::Error).await;
        let (client, _dir) = client_with_fresh_tokens(base);
        let err = get_character_orders(&client, 7)
            .await
            .expect_err("page-2 failure must not return partial rows");
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

    #[test]
    fn reauthorize_detection() {
        let err = crate::error::AppError::from(EsiError::Reauthorize);
        assert!(needs_reauthorize(&err));
        let other = crate::error::AppError::from(EsiError::Status(500));
        assert!(!needs_reauthorize(&other));
    }
}
