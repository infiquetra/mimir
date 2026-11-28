//! SDE reference data: embedded offline baseline plus background
//! SDE-over-HTTP delta sync (ADR-011, card #654).
//!
//! Boot never blocks on the network: `ensure_embedded_baseline` seeds
//! a compact embedded slice into the `sde_*` tables synchronously,
//! and `http_sync::SdeSync` runs only from a background task (and
//! never in demo mode). All tracing here uses the `[SDE]` tag, which
//! is registered in `LOG_TAGS` in `src/ui/settings.rs`; the shell
//! wiring lives in `src/app/shell.rs`.

pub mod http_sync;

pub use http_sync::{
    commit_fetched_build, local_build_number, read_snapshot, FetchOutcome, FetchedBuild,
    LocalSdeSnapshot, SdeSync, SyncOutcome,
};

use crate::error::AppResult;
use http_sync::{parse_solar_systems_jsonl, parse_stargates_jsonl, parse_types_jsonl};

/// Compact embedded baseline so offline cold launches always succeed.
/// Build number `0` marks it as the pre-sync seed; any synced build
/// (`>= 1`) replaces it atomically via `http_sync::apply_sde_build`.
const EMBEDDED_TYPES_JSONL: &str = "\
{\"typeID\":34,\"typeName\":\"Tritanium\",\"groupID\":18,\"published\":true}\n\
{\"typeID\":35,\"typeName\":\"Pyerite\",\"groupID\":18,\"published\":true}\n\
{\"typeID\":36,\"typeName\":\"Mexallon\",\"groupID\":18,\"published\":true}\n\
{\"typeID\":37,\"typeName\":\"Isogen\",\"groupID\":18,\"published\":true}\n\
{\"typeID\":587,\"typeName\":\"Rifter\",\"groupID\":25,\"published\":true}\n";

const EMBEDDED_SYSTEMS_JSONL: &str = "\
{\"solarSystemID\":30000142,\"solarSystemName\":\"Jita\",\"regionID\":10000002,\"security\":0.945}\n\
{\"solarSystemID\":30000144,\"solarSystemName\":\"Perimeter\",\"regionID\":10000002,\"security\":0.9}\n";

const EMBEDDED_STARGATES_JSONL: &str = "\
{\"stargateID\":50000001,\"solarSystemID\":30000142,\"destination\":{\"stargateID\":50000002,\"solarSystemID\":30000144}}\n";

/// Seed the embedded baseline when no SDE rows exist yet. Returns
/// `true` when the baseline was inserted, `false` when verified rows
/// (baseline or synced) were already present. Synchronous and
/// network-free by construction. The shell wiring (`[SDE]` in
/// `LOG_TAGS`, Settings base-URL field, background spawn) lives in
/// `src/app/shell.rs` and `src/ui/settings.rs`.
pub fn ensure_embedded_baseline(conn: &mut rusqlite::Connection) -> AppResult<bool> {
    let existing: i64 = conn.query_row("SELECT COUNT(*) FROM sde_types", [], |r| r.get(0))?;
    if existing > 0 {
        tracing::debug!(
            "[SDE] embedded baseline skipped: {} types present",
            existing
        );
        return Ok(false);
    }
    tracing::info!("[SDE] seeding embedded baseline (offline boot)");
    let types = parse_types_jsonl(EMBEDDED_TYPES_JSONL)?;
    let systems = parse_solar_systems_jsonl(EMBEDDED_SYSTEMS_JSONL)?;
    let stargates = parse_stargates_jsonl(EMBEDDED_STARGATES_JSONL)?;
    http_sync::apply_sde_build(conn, 0, None, &types, &systems, &stargates)?;
    tracing::info!(
        "[SDE] embedded baseline ready types={} systems={} stargates={}",
        types.len(),
        systems.len(),
        stargates.len()
    );
    Ok(true)
}

#[cfg(test)]
mod offline_boot {
    use super::*;

    #[test]
    fn offline_boot_in_memory_baseline_under_100ms() {
        let started = std::time::Instant::now();
        let mut conn = crate::storage::db::open_in_memory().expect("in-memory db opens");
        let seeded = ensure_embedded_baseline(&mut conn).expect("baseline seeds");
        let elapsed = started.elapsed();
        assert!(seeded, "empty db must receive the embedded baseline");
        assert!(
            elapsed < std::time::Duration::from_millis(100),
            "offline boot baseline took {elapsed:?}, budget is 100 ms"
        );
        assert_eq!(local_build_number(&conn).expect("build"), 0);
        let type_count: i64 = conn
            .query_row("SELECT COUNT(*) FROM sde_types", [], |r| r.get(0))
            .expect("type count");
        assert!(type_count >= 5, "baseline types present, got {type_count}");
        let system_name: String = conn
            .query_row(
                "SELECT name FROM sde_solar_systems WHERE system_id = 30000142",
                [],
                |r| r.get(0),
            )
            .expect("jita present");
        assert_eq!(system_name, "Jita");
        // Idempotent: a second call keeps the existing rows.
        let seeded_again = ensure_embedded_baseline(&mut conn).expect("second seed call");
        assert!(!seeded_again);
        let type_count_after: i64 = conn
            .query_row("SELECT COUNT(*) FROM sde_types", [], |r| r.get(0))
            .expect("type count after");
        assert_eq!(type_count_after, type_count);
    }
}
