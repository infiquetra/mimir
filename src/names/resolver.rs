//! Universe name resolution: memory, database, then
//! `POST /universe/names/`. The interface never shows a raw numeric ID.

use std::collections::HashMap;

use crate::error::AppResult;

pub const UNKNOWN_ITEM: &str = "Unknown Item";
pub const UNKNOWN_LOCATION: &str = "Unknown Location";

#[derive(Debug, Default)]
pub struct NameResolver {
    cache: HashMap<i64, String>,
}

impl NameResolver {
    pub fn new() -> Self {
        tracing::debug!("[DB] NameResolver::new");
        Self::default()
    }

    pub fn insert(&mut self, id: i64, name: String) {
        self.cache.insert(id, name);
    }

    pub fn cached(&self, id: i64) -> Option<&str> {
        self.cache.get(&id).map(|s| s.as_str())
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

    pub async fn resolve_missing(&mut self, _ids: &[i64]) -> AppResult<()> {
        tracing::debug!("[DB] resolve_missing (stub)");
        Ok(())
    }
}
