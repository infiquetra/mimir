//! Universe name resolution: memory, then the persistent `universe_names`
//! table, then ESI. The interface never shows a raw numeric ID.
//!
//! The UI thread only ever calls the synchronous lookups ([`NameResolver::name`],
//! [`NameResolver::location_name`], [`NameResolver::missing`]); fills happen
//! through [`NameResolver::fill_from_db`] (sync) and
//! [`NameResolver::resolve_missing_esi`] (async, batched `POST
//! /universe/names/` with an authenticated per-character structure
//! fallback). Player-built structures are not resolvable through
//! `/universe/names/`, so ids at or above [`STRUCTURE_ID_MIN`] go to the
//! authenticated structure endpoint for the caller's character and stay
//! "Unknown Location" when ESI refuses (403).

use std::collections::{HashMap, HashSet};
use std::sync::{Arc, Mutex};

use crate::error::AppResult;
use crate::esi::client::EsiClient;
use crate::esi::models::UniverseName;
use crate::storage::repositories::{self, UniverseNameRow};

pub const UNKNOWN_ITEM: &str = "Unknown Item";
pub const UNKNOWN_LOCATION: &str = "Unknown Location";

/// ESI accepts at most 1000 ids per `/universe/names/` call.
pub const NAMES_BATCH_SIZE: usize = 1000;

/// Hard cap on authenticated structure lookups in one resolve pass.
/// Sequential per-id GETs are the only per-id HTTP fan-out in name
/// resolution; the rest of the missing structures wait for the next
/// scheduled pass instead of bursting against ESI's error limit.
pub const MAX_STRUCTURE_LOOKUPS_PER_PASS: usize = 10;

/// Player-built Upwell structure ids start at 10^12 (`1_000_000_000_000`);
/// NPC stations (60,000,000 range) and character/corporation/alliance ids
/// (`< 10^12`, e.g. modern 2.1B+ characters) resolve through `/universe/names/`.
pub const STRUCTURE_ID_MIN: i64 = 1_000_000_000_000;

/// True when the id is in the Upwell player-built structure range, which
/// `/universe/names/` never resolves.
pub fn is_structure_id(id: i64) -> bool {
    id >= STRUCTURE_ID_MIN
}

/// True when a remote "name" may be displayed and persisted: non-empty
/// after trimming and not purely numeric. A purely numeric remote "name"
/// would render as a raw ID; word fallbacks (Unknown Item/Location) are
/// the contract.
pub fn is_displayable_name(name: &str) -> bool {
    let trimmed = name.trim();
    if trimmed.is_empty() {
        return false;
    }
    let digits = trimmed
        .strip_prefix('+')
        .or_else(|| trimmed.strip_prefix('-'))
        .unwrap_or(trimmed);
    // A lone sign ("+"/"-") leaves no digits and is not a name either.
    !digits.is_empty() && !digits.bytes().all(|b| b.is_ascii_digit())
}

/// The structure ids one pass may attempt: sorted ascending
/// (deterministic cap victims; resolved and pinned ids drop out via
/// [`NameResolver::missing`], so progress is monotonic across passes) and
/// truncated to [`MAX_STRUCTURE_LOOKUPS_PER_PASS`].
pub fn structure_lookup_batch(missing_structure_ids: &[i64]) -> Vec<i64> {
    let mut batch = missing_structure_ids.to_vec();
    batch.sort_unstable();
    batch.truncate(MAX_STRUCTURE_LOOKUPS_PER_PASS);
    batch
}

/// Resolve non-structure universe IDs against `POST /universe/names/`.
/// ESI rejects an entire batch with HTTP 404 when even one ID in it is
/// invalid (e.g., ID `1` EVE System in wallet journals or container item IDs),
/// so any 404 batch is bisected until only single rejected IDs are isolated.
/// Returns `(resolved, rejected_404_ids, fatal_non_404_error)`.
pub async fn resolve_names_resilient(
    client: &EsiClient,
    ids: &[i64],
) -> (Vec<UniverseName>, Vec<i64>, Option<crate::error::AppError>) {
    use crate::error::{AppError, EsiError};

    let mut resolved: Vec<UniverseName> = Vec::new();
    let mut rejected: Vec<i64> = Vec::new();
    let mut fatal: Option<AppError> = None;

    for chunk in ids.chunks(NAMES_BATCH_SIZE) {
        let mut stack: Vec<Vec<i64>> = vec![chunk.to_vec()];
        while let Some(batch) = stack.pop() {
            if batch.is_empty() {
                continue;
            }
            tracing::debug!("[ESI] resolve names batch count={}", batch.len());
            match crate::esi::endpoints::resolve_names(client, &batch).await {
                Ok(mut names) => resolved.append(&mut names),
                Err(AppError::Esi(EsiError::NotFound(_))) => {
                    if batch.len() == 1 {
                        tracing::debug!("[ESI] universe name rejected id={}", batch[0]);
                        rejected.push(batch[0]);
                    } else {
                        let mid = batch.len() / 2;
                        tracing::debug!(
                            "[ESI] universe names batch 404; bisecting len={}",
                            batch.len()
                        );
                        let (left, right) = batch.split_at(mid);
                        stack.push(right.to_vec());
                        stack.push(left.to_vec());
                    }
                }
                Err(e) => {
                    tracing::warn!("[ESI] resolve names batch failed: {}", e);
                    fatal = Some(e);
                    break;
                }
            }
        }
        if fatal.is_some() {
            break;
        }
    }

    (resolved, rejected, fatal)
}

#[derive(Debug, Clone, PartialEq)]
struct ResolvedName {
    name: String,
    category: String,
}

#[derive(Default)]
pub struct NameResolver {
    cache: HashMap<i64, ResolvedName>,
    /// Ids ESI already failed to resolve this session; avoids re-asking
    /// for the same unknown id on every frame.
    unresolved: HashSet<i64>,
    /// Optional backends attached by the integrator so the scaffold-era
    /// [`Self::resolve_missing`] signature can run the full pipeline.
    client: Option<Arc<EsiClient>>,
    conn: Option<Arc<Mutex<rusqlite::Connection>>>,
}

impl std::fmt::Debug for NameResolver {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("NameResolver")
            .field("cached", &self.cache.len())
            .field("unresolved", &self.unresolved.len())
            .field("has_client", &self.client.is_some())
            .field("has_db", &self.conn.is_some())
            .finish()
    }
}

impl NameResolver {
    pub fn new() -> Self {
        tracing::debug!("[DB] NameResolver::new");
        Self::default()
    }

    /// Attach the ESI client and shared DB connection used by
    /// [`Self::resolve_missing`]. Explicit-argument fills work without it.
    pub fn attach(&mut self, client: Arc<EsiClient>, conn: Arc<Mutex<rusqlite::Connection>>) {
        tracing::debug!("[DB] NameResolver backends attached");
        self.client = Some(client);
        self.conn = Some(conn);
    }

    pub fn insert(&mut self, id: i64, name: String) {
        self.insert_with_category(id, name, String::new());
    }

    pub fn insert_with_category(&mut self, id: i64, name: String, category: String) {
        if !is_displayable_name(&name) {
            tracing::debug!("[DB] ignoring empty or numeric name insert id={}", id);
            return;
        }
        self.unresolved.remove(&id);
        self.cache.insert(id, ResolvedName { name, category });
    }

    /// Ingest a batch from ESI `/universe/names/` (or demo fixtures).
    pub fn extend_from_universe_names(&mut self, names: &[UniverseName]) {
        tracing::debug!("[DB] resolver ingest universe names count={}", names.len());
        for n in names {
            self.insert_with_category(n.id, n.name.clone(), n.category.clone());
        }
    }

    /// Ingest persisted rows (startup hydration / DB fill).
    pub fn extend_from_rows(&mut self, rows: &[UniverseNameRow]) {
        tracing::debug!("[DB] resolver ingest db rows count={}", rows.len());
        for r in rows {
            self.insert_with_category(r.id, r.name.clone(), r.category.clone());
        }
    }

    pub fn cached(&self, id: i64) -> Option<&str> {
        self.cache.get(&id).map(|e| e.name.as_str())
    }

    /// ESI category of a cached id (`inventory_type`, `character`,
    /// `corporation`, `station`, `solar_system`, …), when known.
    pub fn category(&self, id: i64) -> Option<&str> {
        self.cache
            .get(&id)
            .map(|e| e.category.as_str())
            .filter(|c| !c.is_empty())
    }

    pub fn len(&self) -> usize {
        self.cache.len()
    }

    pub fn is_empty(&self) -> bool {
        self.cache.is_empty()
    }

    /// Resolved display name, or `Unknown Item` when unresolved.
    pub fn name(&self, id: i64) -> String {
        match self.cached(id) {
            Some(n) => n.to_string(),
            None => {
                tracing::debug!("[DB] name miss id={}", id);
                UNKNOWN_ITEM.to_string()
            }
        }
    }

    /// Resolved display name for a location, or `Unknown Location`.
    pub fn location_name(&self, id: i64) -> String {
        match self.cached(id) {
            Some(n) => n.to_string(),
            None => UNKNOWN_LOCATION.to_string(),
        }
    }

    /// Synchronous: which of these ids still need a fill. Deduped, and ids
    /// already known-unresolvable this session are excluded. The UI calls
    /// this per frame and only schedules a fill when it is non-empty.
    pub fn missing(&self, ids: &[i64]) -> Vec<i64> {
        let mut seen = HashSet::new();
        let mut out = Vec::new();
        for &id in ids {
            if id <= 0 || !seen.insert(id) {
                continue;
            }
            if !self.cache.contains_key(&id) && !self.unresolved.contains(&id) {
                out.push(id);
            }
        }
        out
    }

    /// Record ids ESI definitively refused (structure ACL denials) so
    /// [`Self::missing`] stops re-offering them this session. The shell
    /// calls this when a structure pass lands; [`Self::insert`] remains
    /// the only per-id un-pin.
    pub fn mark_unresolved(&mut self, ids: &[i64]) {
        for &id in ids {
            self.unresolved.insert(id);
        }
        tracing::debug!("[ESI] mark_unresolved count={}", ids.len());
    }

    /// Drop session pins for structure-class ids only, re-arming them
    /// under a different character's token or a newly granted scope.
    /// Non-structure pins are character-independent and stay.
    pub fn forget_unresolved_structures(&mut self) {
        let before = self.unresolved.len();
        self.unresolved.retain(|&id| !is_structure_id(id));
        tracing::debug!(
            "[ESI] forget_unresolved_structures removed={}",
            before - self.unresolved.len()
        );
    }

    /// Load every persisted name into memory (startup hydration).
    pub fn hydrate_from_db(&mut self, conn: &rusqlite::Connection) -> AppResult<usize> {
        tracing::debug!("[DB] hydrate_from_db entry");
        let rows = repositories::list_universe_names(conn)?;
        let count = rows.len();
        self.extend_from_rows(&rows);
        tracing::info!("[DB] resolver hydrated names={}", count);
        Ok(count)
    }

    /// Synchronous DB-layer fill. Returns the ids still missing afterwards
    /// (the set an async ESI fill should fetch).
    pub fn fill_from_db(
        &mut self,
        conn: &rusqlite::Connection,
        ids: &[i64],
    ) -> AppResult<Vec<i64>> {
        let want = self.missing(ids);
        tracing::debug!(
            "[DB] fill_from_db requested={} wanted={}",
            ids.len(),
            want.len()
        );
        if want.is_empty() {
            return Ok(Vec::new());
        }
        let rows = repositories::get_universe_names(conn, &want)?;
        self.extend_from_rows(&rows);
        Ok(self.missing(&want))
    }

    /// Persist everything currently cached (e.g. demo names injected with
    /// [`Self::insert`]) so the next launch resolves them offline.
    pub fn persist_all(&self, conn: &rusqlite::Connection) -> AppResult<()> {
        tracing::debug!("[DB] persist_all count={}", self.cache.len());
        let rows: Vec<UniverseNameRow> = self
            .cache
            .iter()
            .map(|(&id, e)| UniverseNameRow {
                id,
                name: e.name.clone(),
                category: e.category.clone(),
            })
            .collect();
        repositories::upsert_universe_names(conn, &rows)
    }

    /// Full async fill: memory → DB → batched ESI `/universe/names/`,
    /// with structure ids routed to the authenticated structure endpoint
    /// for `structure_character_id`. With no character (`None`), structure
    /// ids are not attempted at all and stay unpinned — the caller offered
    /// no token, which is a property of the call, not of the structures.
    /// Newly resolved names are persisted when `conn` is given. Returns
    /// the ids that remain unresolved (they render as Unknown).
    pub async fn resolve_missing_esi(
        &mut self,
        client: &EsiClient,
        conn: Option<&rusqlite::Connection>,
        ids: &[i64],
        structure_character_id: Option<i64>,
    ) -> AppResult<Vec<i64>> {
        tracing::debug!("[ESI] resolve_missing_esi requested={}", ids.len());
        let mut pending = self.missing(ids);
        if let Some(conn) = conn {
            if !pending.is_empty() {
                pending = self.fill_from_db(conn, &pending)?;
            }
        }
        if pending.is_empty() {
            return Ok(Vec::new());
        }

        let (structures, batch): (Vec<i64>, Vec<i64>) =
            pending.iter().copied().partition(|&id| is_structure_id(id));

        let mut fresh: Vec<UniverseNameRow> = Vec::new();
        let mut batch_fatal: Option<crate::error::AppError> = None;
        if !batch.is_empty() {
            let (names, rejected, fatal) = resolve_names_resilient(client, &batch).await;
            for n in &names {
                // Persist only displayable names, so a numeric
                // batch answer never reaches the DB even though
                // the memory insert guard would reject it anyway.
                if is_displayable_name(&n.name) {
                    fresh.push(UniverseNameRow {
                        id: n.id,
                        name: n.name.clone(),
                        category: n.category.clone(),
                    });
                }
            }
            self.extend_from_universe_names(&names);
            self.mark_unresolved(&rejected);
            batch_fatal = fatal;
        }
        if let Some(err) = batch_fatal {
            if let Some(conn) = conn {
                if !fresh.is_empty() {
                    repositories::upsert_universe_names(conn, &fresh)?;
                }
            }
            return Err(err);
        }

        // Structure ids resolve one at a time through the authenticated
        // endpoint, capped per pass. The batch above only ever sees
        // non-structure ids: /universe/names/ cannot resolve structures.
        // A structure id is pinned only on a definitive refusal (403,
        // 404, or a non-displayable answer). 401 (token-class) and transport-class
        // failures abort the rest of the pass, leaving the remainder
        // unpinned for the next pass, and never fail the whole fill —
        // batch names resolved above must still persist.
        let mut denied: Vec<i64> = Vec::new();
        if let Some(character_id) = structure_character_id {
            let attempt = structure_lookup_batch(&structures);
            tracing::debug!(
                "[ESI] structure lookup batch attempted={} pending={}",
                attempt.len(),
                structures.len()
            );
            for &structure_id in &attempt {
                match crate::esi::endpoints::get_structure_for_character(
                    client,
                    structure_id,
                    character_id,
                )
                .await
                {
                    Ok(info) if is_displayable_name(&info.name) => {
                        tracing::debug!("[ESI] structure resolved id={}", structure_id);
                        fresh.push(UniverseNameRow {
                            id: structure_id,
                            name: info.name.clone(),
                            category: "structure".to_string(),
                        });
                        self.insert_with_category(structure_id, info.name, "structure".to_string());
                    }
                    Ok(_) => {
                        // ESI answered with no displayable name; pin it.
                        tracing::debug!(
                            "[ESI] structure returned non-displayable name id={}",
                            structure_id
                        );
                        denied.push(structure_id);
                    }
                    Err(e)
                        if matches!(
                            &e,
                            crate::error::AppError::Esi(
                                crate::error::EsiError::Reauthorize
                                    | crate::error::EsiError::NotFound(_)
                            )
                        ) =>
                    {
                        // 403 (character cannot see it) and 404 (destroyed
                        // structure, or a parent item id above the
                        // structure threshold) are definitive per-id
                        // answers: pin that id and keep going so one dead
                        // id never head-of-line blocks larger ids on
                        // every future pass.
                        tracing::debug!("[ESI] structure denied id={} reason={}", structure_id, e);
                        denied.push(structure_id);
                    }
                    Err(e) => {
                        tracing::warn!("[ESI] structure lookup aborted reason={}", e);
                        break;
                    }
                }
            }
        } else if !structures.is_empty() {
            // No character context: do not attempt, do not pin. The ids
            // stay offered by missing() for a later pass with a token.
            tracing::debug!(
                "[ESI] structure lookup skipped: no character context pending={}",
                structures.len()
            );
        }

        if let Some(conn) = conn {
            if !fresh.is_empty() {
                repositories::upsert_universe_names(conn, &fresh)?;
            }
        }

        // Pinning: non-structure ids pin exactly as before; structure ids
        // pin only when ESI definitively refused them this pass. Ids
        // skipped for the cap, a missing character, or an aborted pass
        // stay offered by missing() so the next pass retries them.
        let still = self.missing(&pending);
        for &id in &still {
            if !is_structure_id(id) || denied.contains(&id) {
                self.unresolved.insert(id);
            }
        }
        tracing::debug!(
            "[ESI] resolve_missing_esi resolved={} unresolved={}",
            pending.len() - still.len(),
            still.len()
        );
        Ok(still)
    }

    /// Scaffold-era signature kept for F3: runs the full pipeline through
    /// the backends given to [`Self::attach`]. It carries no character
    /// context, so structure ids are never attempted on this path and stay
    /// unresolved (the shell scheduling path passes the active character).
    /// Without attached backends it can only confirm the memory layer and
    /// logs what remains — prefer
    /// [`Self::resolve_missing_esi`] with explicit handles.
    pub async fn resolve_missing(&mut self, ids: &[i64]) -> AppResult<()> {
        tracing::debug!("[DB] resolve_missing requested={}", ids.len());
        let (Some(client), Some(conn)) = (self.client.clone(), self.conn.clone()) else {
            let missing = self.missing(ids);
            if !missing.is_empty() {
                tracing::warn!(
                    "[DB] resolve_missing without attached backends; {} ids stay unresolved",
                    missing.len()
                );
            }
            return Ok(());
        };
        // Clone the Arcs out so no borrow of self crosses the lock; the
        // connection guard is released before the ESI awaits inside by
        // scoping each fill step — resolve_missing_esi takes the guard by
        // reference, so hold it only via a short re-lock per call below.
        let want = {
            let guard = conn
                .lock()
                .map_err(|_| crate::error::AppError::Message("[DB] db mutex poisoned".into()))?;
            self.fill_from_db(&guard, ids)?
        };
        if want.is_empty() {
            return Ok(());
        }
        let still = self.resolve_missing_esi(&client, None, &want, None).await?;
        if still.len() < want.len() {
            let guard = conn
                .lock()
                .map_err(|_| crate::error::AppError::Message("[DB] db mutex poisoned".into()))?;
            self.persist_all(&guard)?;
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::auth::token_store::{AccessToken, RefreshToken, StoredTokens, TokenStore};
    use crate::storage::db;
    use std::sync::{
        atomic::{AtomicUsize, Ordering},
        Arc, Mutex,
    };
    use tokio::io::{AsyncReadExt, AsyncWriteExt};
    use tokio::net::TcpListener;

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

    /// Counting mock serving both name routes: batch
    /// `POST /universe/names/` and structure
    /// `GET /universe/structures/{id}/`. Counts structure requests and
    /// captures every request.
    async fn name_resolution_mock(
        structure_status: u16,
        structure_body: &'static str,
        batch_status: u16,
        batch_body: &'static str,
    ) -> (String, Arc<AtomicUsize>, Arc<Mutex<Vec<String>>>) {
        let listener = TcpListener::bind("127.0.0.1:0").await.expect("bind");
        let addr = listener.local_addr().expect("addr");
        let counter = Arc::new(AtomicUsize::new(0));
        let captured = Arc::new(Mutex::new(Vec::<String>::new()));
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
                    if request.contains("/universe/structures/") {
                        counter.fetch_add(1, Ordering::SeqCst);
                    }
                    captured.lock().expect("capture lock").push(request.clone());
                    let (status, body) = if request.contains("/universe/structures/") {
                        (structure_status, structure_body)
                    } else if request.contains("/universe/names/") {
                        (batch_status, batch_body)
                    } else {
                        (404, r#"{"error":"not found"}"#)
                    };
                    let payload = format!(
                        "HTTP/1.1 {status} OK\r\nContent-Type: application/json\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{body}",
                        body.len()
                    );
                    let _ = socket.write_all(payload.as_bytes()).await;
                    let _ = socket.flush().await;
                });
            }
        });
        (format!("http://{addr}"), counter, captured)
    }

    #[test]
    fn sync_lookup_never_returns_a_raw_id() {
        let mut r = NameResolver::new();
        assert_eq!(r.name(34), UNKNOWN_ITEM);
        assert_eq!(r.location_name(60003760), UNKNOWN_LOCATION);
        r.insert(34, "Tritanium".to_string());
        assert_eq!(r.name(34), "Tritanium");
        assert_eq!(r.category(34), None);
        r.insert_with_category(35, "Pyerite".to_string(), "inventory_type".to_string());
        assert_eq!(r.category(35), Some("inventory_type"));
    }

    #[test]
    fn insert_rejects_numeric_names_so_lookup_never_returns_a_raw_id() {
        let mut r = NameResolver::new();
        // A numeric remote "name" would render exactly like the raw ID
        // the word fallbacks exist to prevent; it must not be cached.
        r.insert(10000002, "10000002".to_string());
        r.insert(34, " 34 ".to_string());
        assert_eq!(r.name(10000002), UNKNOWN_ITEM);
        assert_eq!(r.location_name(34), UNKNOWN_LOCATION);
        // All-digit names beyond i64 range and signed numerics are raw
        // IDs too; parsing alone would let them through.
        r.insert(36, "99999999999999999999".to_string());
        assert_eq!(r.name(36), UNKNOWN_ITEM);
        r.insert(37, "-37".to_string());
        assert_eq!(r.name(37), UNKNOWN_ITEM);
        // Normal and whitespace-padded real names still insert.
        r.insert(34, "Tritanium".to_string());
        assert_eq!(r.name(34), "Tritanium");
    }

    #[test]
    fn missing_dedups_ignores_nonpositive_and_skips_unresolved() {
        let mut r = NameResolver::new();
        r.insert(1, "One".to_string());
        r.unresolved.insert(2);
        assert_eq!(r.missing(&[1, 2, 3, 3, 0, -5]), vec![3]);
    }

    #[test]
    fn structure_classification_matches_eve_id_ranges() {
        assert!(!is_structure_id(60003760)); // Jita 4-4 NPC station
        assert!(!is_structure_id(2_112_625_428)); // Modern EVE character ID
        assert!(!is_structure_id(999_999_999_999));
        assert!(is_structure_id(1_000_000_000_000));
        assert!(is_structure_id(1_037_000_000_001));
    }

    #[test]
    fn db_fill_and_hydrate_roundtrip() {
        let conn = db::open_in_memory().expect("db opens");
        repositories::upsert_universe_names(
            &conn,
            &[UniverseNameRow {
                id: 34,
                name: "Tritanium".to_string(),
                category: "inventory_type".to_string(),
            }],
        )
        .expect("seed name");
        let mut r = NameResolver::new();
        let still = r.fill_from_db(&conn, &[34, 35]).expect("fill");
        assert_eq!(still, vec![35]);
        assert_eq!(r.name(34), "Tritanium");

        let mut fresh = NameResolver::new();
        assert_eq!(fresh.hydrate_from_db(&conn).expect("hydrate"), 1);
        assert_eq!(fresh.name(34), "Tritanium");
    }

    #[test]
    fn persist_all_makes_inserted_names_durable() {
        let conn = db::open_in_memory().expect("db opens");
        let mut r = NameResolver::new();
        r.extend_from_universe_names(&[UniverseName {
            id: 90000001,
            name: "Demo Capsuleer".to_string(),
            category: "character".to_string(),
        }]);
        r.persist_all(&conn).expect("persist");
        let row = repositories::get_universe_name(&conn, 90000001)
            .expect("read")
            .expect("row present");
        assert_eq!(row.name, "Demo Capsuleer");
        assert_eq!(row.category, "character");
    }

    #[tokio::test]
    async fn esi_fill_with_everything_cached_makes_no_network_call() {
        let mut r = NameResolver::new();
        r.insert(34, "Tritanium".to_string());
        let client = EsiClient::default();
        // All ids cached: returns before any endpoint call, so this passes
        // even while F1 endpoint bodies are still landing.
        let still = r
            .resolve_missing_esi(&client, None, &[34], None)
            .await
            .expect("cached fill succeeds offline");
        assert!(still.is_empty());
    }

    #[test]
    fn displayable_name_matrix() {
        for bad in [
            "",
            "  ",
            "123",
            "-5",
            "+7",
            "99999999999999999999",
            "+",
            "-",
        ] {
            assert!(!is_displayable_name(bad), "must reject {bad:?}");
        }
        for good in ["Keepstar 9", "  Perimeter - Tranquility Trading Tower "] {
            assert!(is_displayable_name(good), "must accept {good:?}");
        }
    }

    #[test]
    fn structure_lookup_batch_sorts_and_truncates_to_cap() {
        assert_eq!(MAX_STRUCTURE_LOOKUPS_PER_PASS, 10);
        let twelve = [
            1030000000011,
            1030000000002,
            1030000000001,
            1030000000010,
            1030000000003,
            1030000000009,
            1030000000004,
            1030000000008,
            1030000000005,
            1030000000007,
            1030000000006,
            1030000000012,
        ];
        assert_eq!(
            structure_lookup_batch(&twelve),
            [
                1030000000001,
                1030000000002,
                1030000000003,
                1030000000004,
                1030000000005,
                1030000000006,
                1030000000007,
                1030000000008,
                1030000000009,
                1030000000010,
            ]
        );
        assert!(structure_lookup_batch(&[]).is_empty());
    }

    #[test]
    fn mark_unresolved_and_forget_only_rearm_structures() {
        let mut r = NameResolver::new();
        r.mark_unresolved(&[1030000000001, 34]);
        assert!(r.missing(&[1030000000001]).is_empty());
        assert!(r.missing(&[34]).is_empty());
        r.forget_unresolved_structures();
        assert_eq!(r.missing(&[1030000000001]), vec![1030000000001]);
        assert!(
            r.missing(&[34]).is_empty(),
            "non-structure pins are character-independent and stay"
        );
    }

    #[tokio::test]
    async fn structure_resolves_through_authenticated_lookup_and_persists() {
        let conn = db::open_in_memory().expect("db opens");
        let (base, counter, _captured) = name_resolution_mock(
            200,
            r#"{"name":"Test Keepstar","solar_system_id":30000142,"type_id":35834}"#,
            200,
            "[]",
        )
        .await;
        let (client, _dir) = client_with_fresh_tokens(base);
        let mut r = NameResolver::new();
        let still = r
            .resolve_missing_esi(&client, Some(&conn), &[1030000000001], Some(7))
            .await
            .expect("structure fill succeeds");
        assert!(still.is_empty());
        assert_eq!(r.location_name(1030000000001), "Test Keepstar");
        assert_eq!(r.category(1030000000001), Some("structure"));
        assert_eq!(counter.load(Ordering::SeqCst), 1);
        let row = repositories::get_universe_name(&conn, 1030000000001)
            .expect("read")
            .expect("row present");
        assert_eq!(row.name, "Test Keepstar");
        assert_eq!(row.category, "structure");
    }

    #[tokio::test]
    async fn structure_without_character_is_not_pinned_and_resolves_after_grant() {
        let (base, counter, _captured) = name_resolution_mock(
            200,
            r#"{"name":"Test Keepstar","solar_system_id":30000142,"type_id":35834}"#,
            200,
            "[]",
        )
        .await;
        let (client, _dir) = client_with_fresh_tokens(base);
        let mut r = NameResolver::new();
        // No character: no request, still unresolved, and — unlike a
        // failure — not pinned, so missing() still offers the id.
        let still = r
            .resolve_missing_esi(&client, None, &[1030000000001], None)
            .await
            .expect("no-character fill succeeds");
        assert_eq!(still, vec![1030000000001]);
        assert_eq!(counter.load(Ordering::SeqCst), 0);
        assert_eq!(r.missing(&[1030000000001]), vec![1030000000001]);
        // A later grant (any character context) resolves it.
        let still = r
            .resolve_missing_esi(&client, None, &[1030000000001], Some(7))
            .await
            .expect("granted fill succeeds");
        assert!(still.is_empty());
        assert_eq!(r.location_name(1030000000001), "Test Keepstar");
        assert_eq!(counter.load(Ordering::SeqCst), 1);
    }

    #[tokio::test]
    async fn structure_forbidden_pins_until_forgotten() {
        let (base, _counter, _captured) =
            name_resolution_mock(403, r#"{"error":"Forbidden"}"#, 200, "[]").await;
        let (client, _dir) = client_with_fresh_tokens(base);
        let mut r = NameResolver::new();
        let still = r
            .resolve_missing_esi(&client, None, &[1030000000001], Some(7))
            .await
            .expect("forbidden structure fill still succeeds");
        assert_eq!(still, vec![1030000000001]);
        assert_eq!(r.location_name(1030000000001), UNKNOWN_LOCATION);
        assert!(
            r.missing(&[1030000000001]).is_empty(),
            "denied id stays pinned"
        );
        r.forget_unresolved_structures();
        assert_eq!(
            r.missing(&[1030000000001]),
            vec![1030000000001],
            "forget re-arms the id"
        );
    }

    #[tokio::test]
    async fn structure_not_found_pins_and_continues_to_siblings() {
        // A 404 (destroyed structure, or a parent item id above the
        // structure threshold) is a definitive per-id answer: it pins
        // that id and the pass moves on. Without this, the lowest
        // 404 id is retried first on every pass and larger ids are
        // never attempted (head-of-line blocking).
        let (base, counter, _captured) =
            name_resolution_mock(404, r#"{"error":"Not found"}"#, 200, "[]").await;
        let (client, _dir) = client_with_fresh_tokens(base);
        let mut r = NameResolver::new();
        let ids = [1030000000001, 1030000000002];
        let still = r
            .resolve_missing_esi(&client, None, &ids, Some(7))
            .await
            .expect("not-found structures never fail the fill");
        assert_eq!(still, ids.to_vec());
        assert_eq!(
            counter.load(Ordering::SeqCst),
            2,
            "both structures attempted, in-pass sibling isolation"
        );
        assert!(r.missing(&ids).is_empty(), "both 404 ids stay pinned");
        r.forget_unresolved_structures();
        assert_eq!(r.missing(&ids), ids.to_vec(), "forget re-arms both ids");
    }

    #[tokio::test]
    async fn numeric_batch_name_is_not_persisted() {
        let (base, _counter, _captured) = name_resolution_mock(
            200,
            "{}",
            200,
            r#"[{"id":34,"name":"34","category":"inventory_type"}]"#,
        )
        .await;
        let (client, _dir) = client_with_fresh_tokens(base);
        let conn = db::open_in_memory().expect("db opens");
        let mut r = NameResolver::new();
        let still = r
            .resolve_missing_esi(&client, Some(&conn), &[34], None)
            .await
            .expect("numeric batch fill succeeds");
        assert_eq!(still, vec![34]);
        assert_eq!(r.name(34), UNKNOWN_ITEM);
        assert!(
            repositories::get_universe_name(&conn, 34)
                .expect("read")
                .is_none(),
            "numeric batch name must never reach the DB"
        );
    }

    #[tokio::test]
    async fn transport_failure_aborts_structures_but_persists_batch() {
        let (base, counter, _captured) = name_resolution_mock(
            500,
            r#"{"error":"boom"}"#,
            200,
            r#"[{"id":34,"name":"Tritanium","category":"inventory_type"}]"#,
        )
        .await;
        let (client, _dir) = client_with_fresh_tokens(base);
        let conn = db::open_in_memory().expect("db opens");
        let mut r = NameResolver::new();
        let ids = [34, 1030000000001, 1030000000002];
        let still = r
            .resolve_missing_esi(&client, Some(&conn), &ids, Some(7))
            .await
            .expect("structure transport failure never fails the fill");
        // Batch name resolved and persisted.
        assert_eq!(r.name(34), "Tritanium");
        let row = repositories::get_universe_name(&conn, 34)
            .expect("read")
            .expect("batch row persisted");
        assert_eq!(row.name, "Tritanium");
        // Both structures returned unresolved, unpinned, and exactly one
        // structure request was made (abort the rest).
        assert_eq!(still, vec![1030000000001, 1030000000002]);
        assert_eq!(counter.load(Ordering::SeqCst), 1);
        assert_eq!(r.missing(&ids), vec![1030000000001, 1030000000002]);
    }

    #[tokio::test]
    async fn structure_fan_out_is_bounded_per_pass() {
        let (base, counter, _captured) = name_resolution_mock(
            200,
            r#"{"name":"Test Keepstar","solar_system_id":30000142,"type_id":35834}"#,
            200,
            "[]",
        )
        .await;
        let (client, _dir) = client_with_fresh_tokens(base);
        let mut r = NameResolver::new();
        let ids: Vec<i64> = (1..=12).map(|n| 1030000000000 + n).collect();
        // Offered in reverse so ascending batch order is what resolves
        // the 10 smallest.
        let mut offered = ids.clone();
        offered.reverse();
        let still = r
            .resolve_missing_esi(&client, None, &offered, Some(7))
            .await
            .expect("capped fill succeeds");
        assert_eq!(
            counter.load(Ordering::SeqCst),
            MAX_STRUCTURE_LOOKUPS_PER_PASS
        );
        assert_eq!(still.len(), 2);
        for id in &ids[..10] {
            assert_eq!(r.location_name(*id), "Test Keepstar");
        }
        let missing = r.missing(&ids);
        assert_eq!(missing, ids[10..].to_vec());
        let mut still_sorted = still.clone();
        still_sorted.sort_unstable();
        assert_eq!(still_sorted, ids[10..].to_vec());
    }

    #[tokio::test]
    async fn numeric_structure_name_is_neither_cached_nor_persisted() {
        let conn = db::open_in_memory().expect("db opens");
        let (base, _counter, _captured) = name_resolution_mock(
            200,
            r#"{"name":"1030000000001","solar_system_id":30000142,"type_id":35834}"#,
            200,
            "[]",
        )
        .await;
        let (client, _dir) = client_with_fresh_tokens(base);
        let mut r = NameResolver::new();
        let still = r
            .resolve_missing_esi(&client, Some(&conn), &[1030000000001], Some(7))
            .await
            .expect("numeric name fill succeeds");
        assert_eq!(still, vec![1030000000001]);
        assert_eq!(r.location_name(1030000000001), UNKNOWN_LOCATION);
        assert!(
            repositories::get_universe_name(&conn, 1030000000001)
                .expect("read")
                .is_none(),
            "numeric structure name must never reach the DB"
        );
        assert!(
            r.missing(&[1030000000001]).is_empty(),
            "numeric answer pins the id"
        );
    }

    #[tokio::test]
    async fn empty_structure_name_is_neither_cached_nor_persisted() {
        let conn = db::open_in_memory().expect("db opens");
        let (base, _counter, _captured) = name_resolution_mock(
            200,
            r#"{"name":"","solar_system_id":30000142,"type_id":35834}"#,
            200,
            "[]",
        )
        .await;
        let (client, _dir) = client_with_fresh_tokens(base);
        let mut r = NameResolver::new();
        let still = r
            .resolve_missing_esi(&client, Some(&conn), &[1030000000001], Some(7))
            .await
            .expect("empty name fill succeeds");
        assert_eq!(still, vec![1030000000001]);
        assert_eq!(r.location_name(1030000000001), UNKNOWN_LOCATION);
        assert!(
            repositories::get_universe_name(&conn, 1030000000001)
                .expect("read")
                .is_none(),
            "empty structure name must never reach the DB"
        );
        assert!(
            r.missing(&[1030000000001]).is_empty(),
            "empty answer pins the id"
        );
    }

    #[tokio::test]
    async fn resolve_names_resilient_bisects_around_invalid_id() {
        use tokio::io::{AsyncReadExt, AsyncWriteExt};
        use tokio::net::TcpListener;

        let listener = TcpListener::bind("127.0.0.1:0").await.expect("bind mock");
        let addr = listener.local_addr().expect("addr");
        tokio::spawn(async move {
            loop {
                let Ok((mut socket, _)) = listener.accept().await else {
                    break;
                };
                tokio::spawn(async move {
                    let mut buf = vec![0u8; 8192];
                    let n = socket.read(&mut buf).await.unwrap_or(0);
                    let req = String::from_utf8_lossy(&buf[..n]);
                    let body_str = req.split("\r\n\r\n").nth(1).unwrap_or("[]");
                    let ids: Vec<i64> = serde_json::from_str(body_str).unwrap_or_default();
                    let (status, resp_body) = if ids.contains(&1) {
                        (
                            404,
                            r#"{"error":"Ensure all IDs are valid before resolving."}"#.to_string(),
                        )
                    } else {
                        let entries: Vec<serde_json::Value> = ids
                            .iter()
                            .map(|&id| {
                                let (name, cat) = match id {
                                    34 => ("Tritanium", "inventory_type"),
                                    35 => ("Pyerite", "inventory_type"),
                                    2_112_625_428 => ("Modern Capsuleer", "character"),
                                    _ => ("Other", "inventory_type"),
                                };
                                serde_json::json!({ "id": id, "name": name, "category": cat })
                            })
                            .collect();
                        (200, serde_json::Value::Array(entries).to_string())
                    };
                    let payload = format!(
                        "HTTP/1.1 {status} OK\r\nContent-Type: application/json\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{resp_body}",
                        resp_body.len()
                    );
                    let _ = socket.write_all(payload.as_bytes()).await;
                    let _ = socket.flush().await;
                });
            }
        });

        let client = EsiClient::with_http(reqwest::Client::new(), format!("http://{addr}"));
        let (names, rejected, fatal) =
            resolve_names_resilient(&client, &[34, 1, 35, 2_112_625_428]).await;
        assert!(fatal.is_none());
        assert_eq!(rejected, vec![1]);
        assert_eq!(names.len(), 3);
        assert_eq!(names[0].id, 34);
        assert_eq!(names[1].id, 35);
        assert_eq!(names[2].id, 2_112_625_428);
        assert_eq!(names[2].name, "Modern Capsuleer");
    }
}
