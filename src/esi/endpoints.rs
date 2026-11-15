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

    #[test]
    fn reauthorize_detection() {
        let err = crate::error::AppError::from(EsiError::Reauthorize);
        assert!(needs_reauthorize(&err));
        let other = crate::error::AppError::from(EsiError::Status(500));
        assert!(!needs_reauthorize(&other));
    }
}
