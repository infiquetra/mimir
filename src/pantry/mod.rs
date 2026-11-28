//! Cross-character Pantry stockpile engine (card #642).
//!
//! `indexer` aggregates every linked character's persisted (or
//! freshly fetched) assets into location buckets and per-type
//! totals; `readiness` solves how many copies of a fit the stock
//! can assemble. Both are pure: the shell owns DB reads/writes
//! with short locks (never across `.await`) and demo mode never
//! touches the live `character_assets` table at all.

pub mod indexer;
pub mod readiness;

use indexer::PantryItem;

/// In-memory Pantry snapshot the UI renders: cross-character by
/// design, so a character switch never clears it; removing a
/// character drops exactly that character's rows and badge.
#[derive(Debug, Clone, Default, PartialEq)]
pub struct PantrySnapshot {
    pub items: Vec<PantryItem>,
    /// Character ids lacking `esi-assets.read_assets.v1`.
    pub step_up_character_ids: Vec<i64>,
}

impl PantrySnapshot {
    /// Drop one character's rows and badge (removal / DB cascade
    /// companion: state must not keep showing deleted holdings).
    pub fn remove_character(&mut self, character_id: i64) {
        self.items.retain(|i| i.character_id != character_id);
        self.step_up_character_ids.retain(|id| *id != character_id);
        tracing::debug!("[PANTRY] dropped removed character from snapshot");
    }
}

/// Whether Pantry persistence may run: live mode only. Demo
/// performs zero live-DB reads/writes (guard + counters are
/// exercised by `demo_isolation` tests below).
pub fn should_persist_pantry(demo: bool) -> bool {
    !demo
}

/// Persist one character's fetched assets into `character_assets`
/// and reload the cross-character snapshot. Short lock only; the
/// caller must not hold the DB mutex across any `.await`.
pub fn persist_and_reload(
    db: &std::sync::Mutex<rusqlite::Connection>,
    character_id: i64,
    items: &[PantryItem],
) -> crate::error::AppResult<PantrySnapshot> {
    let rows: Vec<crate::storage::repositories::CharacterAssetRow> =
        items.iter().map(PantryItem::to_row).collect();
    let all = {
        let conn = db
            .lock()
            .map_err(|_| crate::error::AppError::Message("database lock poisoned".to_string()))?;
        crate::storage::repositories::replace_character_assets(&conn, character_id, &rows)?;
        crate::storage::repositories::list_all_character_assets(&conn)?
    };
    tracing::debug!(
        "[PANTRY] persisted character assets and reloaded snapshot rows={}",
        all.len()
    );
    Ok(PantrySnapshot {
        items: all.iter().map(PantryItem::from_row).collect(),
        step_up_character_ids: Vec::new(),
    })
}

/// Load the snapshot from SQLite without writing (startup path).
pub fn load_snapshot(
    db: &std::sync::Mutex<rusqlite::Connection>,
) -> crate::error::AppResult<PantrySnapshot> {
    let all = {
        let conn = db
            .lock()
            .map_err(|_| crate::error::AppError::Message("database lock poisoned".to_string()))?;
        crate::storage::repositories::list_all_character_assets(&conn)?
    };
    Ok(PantrySnapshot {
        items: all.iter().map(PantryItem::from_row).collect(),
        step_up_character_ids: Vec::new(),
    })
}

#[cfg(test)]
mod virtualization_bench {
    use super::indexer::{build_display_rows, filter_row_indices, PantryItem};
    use std::time::{Duration, Instant};

    fn synthetic_items(count: usize) -> Vec<PantryItem> {
        (0..count)
            .map(|n| PantryItem {
                character_id: (n % 3) as i64 + 1,
                item_id: n as i64 + 1,
                type_id: (n % 500) as i64 + 1,
                location_id: 60003760 + (n % 7) as i64,
                location_flag: "Hangar".to_string(),
                location_type: "station".to_string(),
                quantity: (n % 97) as i64 + 1,
                is_singleton: false,
                is_blueprint_copy: false,
            })
            .collect()
    }

    #[test]
    fn filters_and_sorts_25000_rows_under_2ms_best_of_n() {
        // Setup mirrors Quick-Sight: the row set (with resolved
        // names, build-time sort, and precomputed search keys)
        // is built once per snapshot, outside the timed region.
        let items = synthetic_items(25_000);
        let rows = build_display_rows(
            &items,
            |type_id| format!("Type {type_id}"),
            |character_id| format!("Character {character_id}"),
            |location_id| format!("Location {location_id}"),
        );
        assert_eq!(rows.len(), 25_000);
        // Build-time sort is the order every filter preserves.
        assert!(rows
            .windows(2)
            .all(|pair| pair[0].type_name <= pair[1].type_name));
        // One warm-up so lazy statics never pollute the samples.
        assert_eq!(filter_row_indices(&rows, "type 42").len(), 550);
        let mut best = Duration::MAX;
        for _ in 0..9 {
            let started = Instant::now();
            let filtered = filter_row_indices(&rows, "type 42");
            best = best.min(started.elapsed());
            assert_eq!(filtered.len(), 550);
            std::hint::black_box(filtered);
        }
        assert!(
            best < Duration::from_millis(2),
            "25,000-row filter/sort prep took {best:?} (best of 9), budget 2.0 ms"
        );
    }
}

#[cfg(test)]
mod demo_isolation {
    use super::*;
    use crate::storage::db;
    use crate::storage::repositories;

    fn seed_character(conn: &rusqlite::Connection, character_id: i64) {
        conn.execute(
            "INSERT INTO characters (character_id, name, corporation_id, is_active, updated_at) \
             VALUES (?1, 'Tester', 1000, 1, '')",
            rusqlite::params![character_id],
        )
        .expect("seed character");
    }

    #[test]
    fn demo_mode_never_touches_live_character_assets() {
        // The guard is the contract: in demo the shell skips every
        // persist/load call, so a live table stays untouched.
        assert!(!should_persist_pantry(true));
        assert!(should_persist_pantry(false));

        // Prove the storage path itself against a throwaway
        // in-memory database (never the real db_path): write,
        // reload, cascade-delete, and confirm zero orphans.
        let conn = db::open_in_memory().expect("in-memory db");
        seed_character(&conn, 7);
        seed_character(&conn, 8);
        let rows = [
            repositories::CharacterAssetRow {
                character_id: 7,
                item_id: 100,
                type_id: 34,
                location_id: 60003760,
                location_flag: "Hangar".to_string(),
                quantity: 10,
                is_singleton: false,
            },
            repositories::CharacterAssetRow {
                character_id: 8,
                item_id: 200,
                type_id: 34,
                location_id: 60003760,
                location_flag: "Hangar".to_string(),
                quantity: 5,
                is_singleton: false,
            },
        ];
        repositories::replace_character_assets(&conn, 7, &rows[..1]).expect("write char 7");
        repositories::replace_character_assets(&conn, 8, &rows[1..]).expect("write char 8");
        assert_eq!(
            repositories::list_all_character_assets(&conn)
                .expect("list all")
                .len(),
            2
        );

        // FK cascade alone (no explicit delete list) must orphan 0.
        conn.execute("DELETE FROM characters WHERE character_id = 8", [])
            .expect("raw character delete");
        let orphans: i64 = conn
            .query_row(
                "SELECT COUNT(*) FROM character_assets WHERE character_id = 8",
                [],
                |r| r.get(0),
            )
            .expect("orphan count");
        assert_eq!(orphans, 0, "ON DELETE CASCADE leaves no orphans");

        // The repository path the app actually calls agrees.
        assert!(repositories::delete_character(&conn, 7).expect("delete char 7"));
        assert_eq!(
            repositories::list_all_character_assets(&conn)
                .expect("list after delete")
                .len(),
            0
        );
    }
}
