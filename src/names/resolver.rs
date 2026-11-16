//! Universe name resolution: memory, then the persistent `universe_names`
//! table, then ESI. The interface never shows a raw numeric ID.
//!
//! The UI thread only ever calls the synchronous lookups ([`NameResolver::name`],
//! [`NameResolver::location_name`], [`NameResolver::missing`]); fills happen
//! through [`NameResolver::fill_from_db`] (sync) and
//! [`NameResolver::resolve_missing_esi`] (async, batched `POST
//! /universe/names/` with a structure fallback). Player-built structures are
//! not resolvable through `/universe/names/`, so ids at or above
//! [`STRUCTURE_ID_MIN`] go to the authenticated structure endpoint and stay
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

/// Player-built structure ids start here; NPC station ids are far below it
/// (60,000,000 range) and resolve through `/universe/names/`.
pub const STRUCTURE_ID_MIN: i64 = 1_000_000_000;

/// True when the id can only be a player-built structure, which
/// `/universe/names/` never resolves.
pub fn is_structure_id(id: i64) -> bool {
    id >= STRUCTURE_ID_MIN
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
        let trimmed = name.trim();
        let digits = trimmed
            .strip_prefix('+')
            .or_else(|| trimmed.strip_prefix('-'))
            .unwrap_or(trimmed);
        if trimmed.is_empty() || (!digits.is_empty() && digits.bytes().all(|b| b.is_ascii_digit()))
        {
            // A purely numeric remote "name" would render as a raw ID;
            // word fallbacks (Unknown Item/Location) are the contract.
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
    /// with structure ids routed to the authenticated structure endpoint.
    /// Newly resolved names are persisted when `conn` is given. Returns
    /// the ids that remain unresolved (they render as Unknown).
    pub async fn resolve_missing_esi(
        &mut self,
        client: &EsiClient,
        conn: Option<&rusqlite::Connection>,
        ids: &[i64],
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
        for chunk in batch.chunks(NAMES_BATCH_SIZE) {
            tracing::debug!("[ESI] resolve names batch count={}", chunk.len());
            match crate::esi::endpoints::resolve_names(client, chunk).await {
                Ok(names) => {
                    for n in &names {
                        fresh.push(UniverseNameRow {
                            id: n.id,
                            name: n.name.clone(),
                            category: n.category.clone(),
                        });
                    }
                    self.extend_from_universe_names(&names);
                }
                Err(e) => {
                    // Offline / ESI down: keep what memory+DB gave us and
                    // report the failure; the UI shows Unknown meanwhile.
                    tracing::warn!("[ESI] resolve names batch failed: {}", e);
                    return Err(e);
                }
            }
        }

        for &structure_id in &structures {
            match crate::esi::endpoints::get_structure(client, structure_id).await {
                Ok(info) if !info.name.is_empty() => {
                    tracing::debug!("[ESI] structure resolved id={}", structure_id);
                    fresh.push(UniverseNameRow {
                        id: structure_id,
                        name: info.name.clone(),
                        category: "structure".to_string(),
                    });
                    self.insert_with_category(structure_id, info.name, "structure".to_string());
                }
                Ok(_) => {
                    tracing::debug!("[ESI] structure returned empty name id={}", structure_id);
                }
                Err(e) => {
                    // 403 is expected for structures the character cannot
                    // see; that id stays Unknown Location by design.
                    tracing::debug!(
                        "[ESI] structure unresolved id={} reason={}",
                        structure_id,
                        e
                    );
                }
            }
        }

        if let Some(conn) = conn {
            if !fresh.is_empty() {
                repositories::upsert_universe_names(conn, &fresh)?;
            }
        }

        let still = self.missing(&pending);
        for &id in &still {
            self.unresolved.insert(id);
        }
        tracing::debug!(
            "[ESI] resolve_missing_esi resolved={} unresolved={}",
            pending.len() - still.len(),
            still.len()
        );
        Ok(still)
    }

    /// Scaffold-era signature kept for F3: runs the full pipeline through
    /// the backends given to [`Self::attach`]. Without attached backends it
    /// can only confirm the memory layer and logs what remains — prefer
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
        let still = self.resolve_missing_esi(&client, None, &want).await?;
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
    use crate::storage::db;

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
        assert!(is_structure_id(1_000_000_000));
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
            .resolve_missing_esi(&client, None, &[34])
            .await
            .expect("cached fill succeeds offline");
        assert!(still.is_empty());
    }
}
