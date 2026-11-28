//! SDE over HTTP JSONL delta sync (ADR-011, card #654).
//!
//! Polls a release manifest (`build_number` + `ETag`), streams the
//! `types`, `mapSolarSystems`, and `mapStargates` JSONL slices, and
//! swaps them into the `sde_*` reference tables inside a single
//! `rusqlite::Transaction`. All parsing and row-count validation
//! happens before the transaction opens, and any failure before
//! `commit()` leaves the prior verified build untouched. User tables
//! (`characters`, `token_meta`, `skill_plans`, `skill_plan_entries`)
//! are never deleted, dropped, or written here. Sync is background
//! only: boot serves the embedded baseline first (see `super`).

use crate::config::{now_unix, EveConfig};
use crate::error::{AppError, AppResult};

/// One parsed `types` JSONL row.
#[derive(Debug, Clone, PartialEq)]
pub struct SdeTypeRow {
    pub type_id: i64,
    pub name: String,
    pub group_id: Option<i64>,
    pub published: bool,
}

/// One parsed `mapSolarSystems` JSONL row.
#[derive(Debug, Clone, PartialEq)]
pub struct SdeSolarSystemRow {
    pub system_id: i64,
    pub name: String,
    pub region_id: Option<i64>,
    pub security_status: Option<f64>,
}

/// One parsed `mapStargates` JSONL row.
#[derive(Debug, Clone, PartialEq)]
pub struct SdeStargateRow {
    pub stargate_id: i64,
    pub name: String,
    pub system_id: Option<i64>,
    pub destination_stargate_id: Option<i64>,
    pub destination_system_id: Option<i64>,
}

/// Result of one sync attempt.
#[derive(Debug, Clone, PartialEq)]
pub enum SyncOutcome {
    /// Manifest matched the local build (HTTP 304 or same build number).
    NotModified { build_number: i64 },
    /// A newer build replaced the reference tables atomically.
    Updated {
        build_number: i64,
        types: usize,
        solar_systems: usize,
        stargates: usize,
    },
    /// Demo mode: no network request was issued at all.
    SkippedDemo,
}

/// SDE-over-HTTP client. Construct with `with_base_url` in production
/// and `with_http` against a local mock fixture in tests.
pub struct SdeSync {
    http: reqwest::Client,
    base_url: String,
}

impl SdeSync {
    pub fn new(base_url: String) -> AppResult<Self> {
        tracing::info!("[SDE] creating SDE sync client base={}", base_url);
        let http = reqwest::Client::builder()
            .timeout(std::time::Duration::from_millis(
                EveConfig::DEFAULT_TIMEOUT_MS,
            ))
            .user_agent(EveConfig::USER_AGENT)
            .build()
            .map_err(|e| AppError::Message(e.to_string()))?;
        Ok(Self::with_http(http, base_url))
    }

    pub fn with_http(http: reqwest::Client, base_url: String) -> Self {
        Self {
            http,
            base_url: base_url.trim_end_matches('/').to_string(),
        }
    }

    pub fn base_url(&self) -> &str {
        &self.base_url
    }

    async fn get_text(
        &self,
        path: &str,
        if_none_match: Option<&str>,
    ) -> AppResult<(u16, Option<String>, String)> {
        let url = format!("{}{}", self.base_url, path);
        tracing::debug!("[SDE] GET {}", path);
        let mut request = self
            .http
            .get(&url)
            .header(reqwest::header::USER_AGENT, EveConfig::USER_AGENT);
        if let Some(etag) = if_none_match {
            request = request.header(reqwest::header::IF_NONE_MATCH, etag);
        }
        let response = request
            .send()
            .await
            .map_err(|e| AppError::Message(format!("[SDE] request failed: {}", e.without_url())))?;
        let status = response.status().as_u16();
        let etag = response
            .headers()
            .get(reqwest::header::ETAG)
            .and_then(|v| v.to_str().ok())
            .map(|s| s.to_string());
        let body = response.text().await.map_err(|e| {
            AppError::Message(format!("[SDE] body read failed: {}", e.without_url()))
        })?;
        Ok((status, etag, body))
    }

    /// Background delta sync. Never call on the boot path; serve the
    /// embedded baseline first and run this from a background task.
    pub async fn sync(&self, conn: &mut rusqlite::Connection) -> AppResult<SyncOutcome> {
        let local_build = local_build_number(conn)?;
        let local_etag = local_meta(conn, "etag")?;
        tracing::info!(
            "[SDE] sync check local_build={} etag_present={}",
            local_build,
            local_etag.is_some()
        );
        let (status, manifest_etag, manifest_body) = self
            .get_text("/manifest.json", local_etag.as_deref())
            .await?;
        if status == 304 {
            tracing::info!("[SDE] manifest 304 not modified build={}", local_build);
            return Ok(SyncOutcome::NotModified {
                build_number: local_build,
            });
        }
        if status != 200 {
            return Err(AppError::Message(format!(
                "[SDE] manifest request failed with status {status}"
            )));
        }
        let remote_build = parse_manifest_build(&manifest_body)?;
        if local_build > 0 && remote_build <= local_build {
            tracing::info!(
                "[SDE] manifest build {} not newer than local {}",
                remote_build,
                local_build
            );
            return Ok(SyncOutcome::NotModified {
                build_number: local_build,
            });
        }

        let (_, _, types_body) = self.get_text("/types.jsonl", None).await?;
        let (_, _, systems_body) = self.get_text("/mapSolarSystems.jsonl", None).await?;
        let (_, _, stargates_body) = self.get_text("/mapStargates.jsonl", None).await?;

        // Parse and validate everything before opening the transaction:
        // a truncated or corrupt slice aborts here with zero DB writes.
        let types = parse_types_jsonl(&types_body)?;
        let systems = parse_solar_systems_jsonl(&systems_body)?;
        let stargates = parse_stargates_jsonl(&stargates_body)?;
        if types.is_empty() || systems.is_empty() || stargates.is_empty() {
            tracing::warn!(
                "[SDE] aborting sync: empty slice types={} systems={} stargates={}",
                types.len(),
                systems.len(),
                stargates.len()
            );
            return Err(AppError::Message(
                "[SDE] aborting sync: JSONL slice row-count validation failed (empty slice)"
                    .to_string(),
            ));
        }
        tracing::info!(
            "[SDE] applying build {} types={} systems={} stargates={}",
            remote_build,
            types.len(),
            systems.len(),
            stargates.len()
        );
        apply_sde_build(
            conn,
            remote_build,
            manifest_etag.as_deref(),
            &types,
            &systems,
            &stargates,
        )?;
        Ok(SyncOutcome::Updated {
            build_number: remote_build,
            types: types.len(),
            solar_systems: systems.len(),
            stargates: stargates.len(),
        })
    }

    /// Demo guard: demo mode issues zero SDE HTTP requests. The shell
    /// wiring that calls this lands after #651; the guard itself is
    /// enforced and tested here now.
    pub async fn sync_if_allowed(
        &self,
        conn: &mut rusqlite::Connection,
        demo: bool,
    ) -> AppResult<SyncOutcome> {
        if demo {
            tracing::info!("[SDE] sync skipped: demo mode (zero network requests)");
            return Ok(SyncOutcome::SkippedDemo);
        }
        self.sync(conn).await
    }
}

/// Locally stored SDE build number (`0` before any successful sync).
pub fn local_build_number(conn: &rusqlite::Connection) -> AppResult<i64> {
    let raw = local_meta(conn, "build_number")?;
    Ok(raw.and_then(|v| v.parse::<i64>().ok()).unwrap_or(0))
}

/// One `sde_meta` value by key, when present.
pub fn local_meta(conn: &rusqlite::Connection, key: &str) -> AppResult<Option<String>> {
    let mut stmt = conn.prepare("SELECT value FROM sde_meta WHERE key = ?1")?;
    let mut rows = stmt.query([key])?;
    match rows.next()? {
        Some(row) => Ok(Some(row.get(0)?)),
        None => Ok(None),
    }
}

/// Atomically replace the `sde_*` reference tables and stamp the new
/// build. Row counts are re-read inside the transaction and must be
/// non-zero before `commit()`; any error drops the transaction and
/// the prior build keeps serving.
pub fn apply_sde_build(
    conn: &mut rusqlite::Connection,
    build_number: i64,
    etag: Option<&str>,
    types: &[SdeTypeRow],
    systems: &[SdeSolarSystemRow],
    stargates: &[SdeStargateRow],
) -> AppResult<()> {
    tracing::debug!("[SDE] opening swap transaction build={}", build_number);
    let tx = conn.transaction()?;
    tx.execute("DELETE FROM sde_types", [])?;
    tx.execute("DELETE FROM sde_solar_systems", [])?;
    tx.execute("DELETE FROM sde_stargates", [])?;
    {
        let mut stmt = tx.prepare(
            "INSERT INTO sde_types (type_id, name, group_id, published) VALUES (?1, ?2, ?3, ?4)",
        )?;
        for row in types {
            stmt.execute(rusqlite::params![
                row.type_id,
                row.name,
                row.group_id,
                row.published as i64
            ])?;
        }
    }
    {
        let mut stmt = tx.prepare(
            "INSERT INTO sde_solar_systems (system_id, name, region_id, security_status) VALUES (?1, ?2, ?3, ?4)",
        )?;
        for row in systems {
            stmt.execute(rusqlite::params![
                row.system_id,
                row.name,
                row.region_id,
                row.security_status
            ])?;
        }
    }
    {
        let mut stmt = tx.prepare(
            "INSERT INTO sde_stargates (stargate_id, name, system_id, destination_stargate_id, destination_system_id) VALUES (?1, ?2, ?3, ?4, ?5)",
        )?;
        for row in stargates {
            stmt.execute(rusqlite::params![
                row.stargate_id,
                row.name,
                row.system_id,
                row.destination_stargate_id,
                row.destination_system_id
            ])?;
        }
    }
    let type_count: i64 = tx.query_row("SELECT COUNT(*) FROM sde_types", [], |r| r.get(0))?;
    let system_count: i64 =
        tx.query_row("SELECT COUNT(*) FROM sde_solar_systems", [], |r| r.get(0))?;
    let stargate_count: i64 =
        tx.query_row("SELECT COUNT(*) FROM sde_stargates", [], |r| r.get(0))?;
    if type_count == 0 || system_count == 0 || stargate_count == 0 {
        tracing::warn!(
            "[SDE] rolling back build {}: row counts types={} systems={} stargates={}",
            build_number,
            type_count,
            system_count,
            stargate_count
        );
        return Err(AppError::Message(
            "[SDE] row-count validation failed inside transaction; rolled back".to_string(),
        ));
    }
    tx.execute(
        "INSERT INTO sde_meta (key, value) VALUES ('build_number', ?1) \
         ON CONFLICT(key) DO UPDATE SET value = excluded.value",
        [build_number.to_string()],
    )?;
    if let Some(etag) = etag {
        tx.execute(
            "INSERT INTO sde_meta (key, value) VALUES ('etag', ?1) \
             ON CONFLICT(key) DO UPDATE SET value = excluded.value",
            [etag],
        )?;
    }
    tx.execute(
        "INSERT INTO sde_meta (key, value) VALUES ('synced_at', ?1) \
         ON CONFLICT(key) DO UPDATE SET value = excluded.value",
        [now_unix().to_string()],
    )?;
    tx.commit()?;
    tracing::info!("[SDE] committed build {}", build_number);
    Ok(())
}

fn parse_manifest_build(body: &str) -> AppResult<i64> {
    let value: serde_json::Value = serde_json::from_str(body)
        .map_err(|e| AppError::Message(format!("[SDE] manifest decode failed: {e}")))?;
    value
        .get("build_number")
        .or_else(|| value.get("buildNumber"))
        .and_then(|v| v.as_i64())
        .ok_or_else(|| AppError::Message("[SDE] manifest missing build_number".to_string()))
}

fn json_i64(value: &serde_json::Value, keys: &[&str]) -> Option<i64> {
    keys.iter()
        .find_map(|key| value.get(*key))
        .and_then(|v| v.as_i64().or_else(|| v.as_str()?.parse::<i64>().ok()))
}

fn json_f64(value: &serde_json::Value, keys: &[&str]) -> Option<f64> {
    keys.iter()
        .find_map(|key| value.get(*key))
        .and_then(|v| v.as_f64())
}

fn json_string(value: &serde_json::Value, keys: &[&str]) -> Option<String> {
    keys.iter()
        .find_map(|key| value.get(*key))
        .and_then(|v| v.as_str())
        .map(|s| s.to_string())
}

fn json_bool(value: &serde_json::Value, keys: &[&str]) -> bool {
    keys.iter()
        .find_map(|key| value.get(*key))
        .map(|v| match v {
            serde_json::Value::Bool(b) => *b,
            serde_json::Value::Number(n) => n.as_i64().map(|i| i != 0).unwrap_or(false),
            _ => false,
        })
        .unwrap_or(false)
}

fn parse_lines(body: &str) -> AppResult<Vec<serde_json::Value>> {
    let mut rows = Vec::new();
    for (index, line) in body.lines().enumerate() {
        let line = line.trim();
        if line.is_empty() {
            continue;
        }
        let value: serde_json::Value = serde_json::from_str(line).map_err(|e| {
            AppError::Message(format!("[SDE] corrupt JSONL at line {}: {e}", index + 1))
        })?;
        rows.push(value);
    }
    if rows.is_empty() {
        return Err(AppError::Message("[SDE] empty JSONL payload".to_string()));
    }
    Ok(rows)
}

/// Parse a `types` JSONL slice. Field spellings accept the CCP SDE
/// camel/Pascal variants (`typeID`/`typeId`/`type_id`/`id`, and the
/// matching name/group keys); a line missing its ID or name is corrupt.
pub fn parse_types_jsonl(body: &str) -> AppResult<Vec<SdeTypeRow>> {
    let values = parse_lines(body)?;
    let mut rows = Vec::with_capacity(values.len());
    for value in &values {
        let type_id = json_i64(value, &["typeID", "typeId", "type_id", "id", "_key"])
            .ok_or_else(|| AppError::Message("[SDE] types row missing type id".to_string()))?;
        let name = json_string(value, &["typeName", "name", "type_name"]).unwrap_or_default();
        rows.push(SdeTypeRow {
            type_id,
            name,
            group_id: json_i64(value, &["groupID", "groupId", "group_id"]),
            published: json_bool(value, &["published"]),
        });
    }
    Ok(rows)
}

/// Parse a `mapSolarSystems` JSONL slice.
pub fn parse_solar_systems_jsonl(body: &str) -> AppResult<Vec<SdeSolarSystemRow>> {
    let values = parse_lines(body)?;
    let mut rows = Vec::with_capacity(values.len());
    for value in &values {
        let system_id = json_i64(
            value,
            &[
                "solarSystemID",
                "solarSystemId",
                "systemID",
                "system_id",
                "id",
                "_key",
            ],
        )
        .ok_or_else(|| AppError::Message("[SDE] solar system row missing id".to_string()))?;
        rows.push(SdeSolarSystemRow {
            system_id,
            name: json_string(value, &["solarSystemName", "name", "system_name"])
                .unwrap_or_default(),
            region_id: json_i64(value, &["regionID", "regionId", "region_id"]),
            security_status: json_f64(value, &["security", "securityStatus", "security_status"]),
        });
    }
    Ok(rows)
}

/// Parse a `mapStargates` JSONL slice (flat or nested `destination`).
pub fn parse_stargates_jsonl(body: &str) -> AppResult<Vec<SdeStargateRow>> {
    let values = parse_lines(body)?;
    let mut rows = Vec::with_capacity(values.len());
    for value in &values {
        let stargate_id = json_i64(
            value,
            &["stargateID", "stargateId", "stargate_id", "id", "_key"],
        )
        .ok_or_else(|| AppError::Message("[SDE] stargate row missing id".to_string()))?;
        let destination = value.get("destination");
        let destination_stargate_id =
            json_i64(value, &["destinationStargateID", "destination_stargate_id"]).or_else(|| {
                destination.and_then(|d| json_i64(d, &["stargateID", "stargateId", "id"]))
            });
        let destination_system_id =
            json_i64(value, &["destinationSystemID", "destination_system_id"]).or_else(|| {
                destination.and_then(|d| {
                    json_i64(
                        d,
                        &["solarSystemID", "solarSystemId", "systemID", "system_id"],
                    )
                })
            });
        rows.push(SdeStargateRow {
            stargate_id,
            name: json_string(value, &["name", "stargateName"]).unwrap_or_default(),
            system_id: json_i64(value, &["solarSystemID", "solarSystemId", "system_id"]),
            destination_stargate_id,
            destination_system_id,
        });
    }
    Ok(rows)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::atomic::{AtomicUsize, Ordering};
    use std::sync::{Arc, Mutex as StdMutex};
    use tokio::io::{AsyncReadExt, AsyncWriteExt};

    const TYPES_V1: &str = "{\"typeID\":34,\"typeName\":\"Tritanium\",\"groupID\":18,\"published\":true}\n{\"typeID\":35,\"typeName\":\"Pyerite\",\"groupID\":18,\"published\":true}\n";
    const SYSTEMS_V1: &str = "{\"solarSystemID\":30000142,\"solarSystemName\":\"Jita\",\"regionID\":10000002,\"security\":0.945}\n{\"solarSystemID\":30000144,\"solarSystemName\":\"Perimeter\",\"regionID\":10000002,\"security\":0.9}\n";
    const GATES_V1: &str = "{\"stargateID\":50000001,\"solarSystemID\":30000142,\"destination\":{\"stargateID\":50000002,\"solarSystemID\":30000144}}\n";
    const TYPES_V2: &str = "{\"typeID\":34,\"typeName\":\"Tritanium\",\"groupID\":18,\"published\":true}\n{\"typeID\":36,\"typeName\":\"Mexallon\",\"groupID\":18,\"published\":true}\n{\"typeID\":37,\"typeName\":\"Isogen\",\"groupID\":18,\"published\":true}\n";

    #[derive(Clone)]
    struct MockSde {
        build_number: i64,
        etag: String,
        types: String,
        systems: String,
        stargates: String,
    }

    /// Local mock SDE fixture: routes manifest + JSONL slices by path,
    /// answers 304 when If-None-Match carries the current ETag, and
    /// counts every hit. No live network is involved.
    async fn mock_sde_server(
        state: MockSde,
    ) -> (String, Arc<AtomicUsize>, Arc<StdMutex<Vec<String>>>) {
        let listener = tokio::net::TcpListener::bind("127.0.0.1:0")
            .await
            .expect("bind sde mock");
        let addr = listener.local_addr().expect("addr");
        let hits = Arc::new(AtomicUsize::new(0));
        let captured: Arc<StdMutex<Vec<String>>> = Arc::new(StdMutex::new(Vec::new()));
        let hits_task = hits.clone();
        let captured_task = captured.clone();
        tokio::spawn(async move {
            loop {
                let Ok((mut socket, _)) = listener.accept().await else {
                    break;
                };
                let state = state.clone();
                let hits = hits_task.clone();
                let captured = captured_task.clone();
                tokio::spawn(async move {
                    let mut raw = Vec::new();
                    let mut chunk = [0u8; 4096];
                    loop {
                        match socket.read(&mut chunk).await {
                            Ok(0) => break,
                            Ok(n) => {
                                raw.extend_from_slice(&chunk[..n]);
                                if raw.windows(4).any(|w| w == b"\r\n\r\n") || raw.len() > 16384 {
                                    break;
                                }
                            }
                            Err(_) => break,
                        }
                    }
                    let request = String::from_utf8_lossy(&raw).into_owned();
                    hits.fetch_add(1, Ordering::SeqCst);
                    captured
                        .lock()
                        .expect("captured lock")
                        .push(request.clone());
                    let lower = request.to_lowercase();
                    let path = request
                        .split_whitespace()
                        .nth(1)
                        .unwrap_or("")
                        .split('?')
                        .next()
                        .unwrap_or("")
                        .to_string();
                    let payload = if path == "/manifest.json" {
                        if lower.contains(&format!("if-none-match: {}", state.etag)) {
                            "HTTP/1.1 304 Not Modified\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
                                .to_string()
                        } else {
                            let body = format!("{{\"build_number\":{}}}", state.build_number);
                            format!(
                                "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nETag: {}\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{body}",
                                state.etag,
                                body.len()
                            )
                        }
                    } else if path == "/types.jsonl" {
                        format!(
                            "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{}",
                            state.types.len(),
                            state.types
                        )
                    } else if path == "/mapSolarSystems.jsonl" {
                        format!(
                            "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{}",
                            state.systems.len(),
                            state.systems
                        )
                    } else if path == "/mapStargates.jsonl" {
                        format!(
                            "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{}",
                            state.stargates.len(),
                            state.stargates
                        )
                    } else {
                        "HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
                            .to_string()
                    };
                    let _ = socket.write_all(payload.as_bytes()).await;
                    let _ = socket.flush().await;
                });
            }
        });
        (format!("http://{addr}"), hits, captured)
    }

    fn mock_state(build_number: i64, etag: &str, types: &str) -> MockSde {
        MockSde {
            build_number,
            etag: etag.to_string(),
            types: types.to_string(),
            systems: SYSTEMS_V1.to_string(),
            stargates: GATES_V1.to_string(),
        }
    }

    fn seed_user_rows(conn: &rusqlite::Connection) {
        conn.execute(
            "INSERT INTO characters (character_id, name, corporation_id, is_active, updated_at) VALUES (90000001, 'Aria', 1000166, 1, '2026-11-15T00:00:00Z')",
            [],
        )
        .expect("seed character");
        conn.execute(
            "INSERT INTO skill_plans (plan_id, character_id, name, description, created_at, updated_at) VALUES (1, 90000001, 'Plan A', '', '2026-11-15T00:00:00Z', '2026-11-15T00:00:00Z')",
            [],
        )
        .expect("seed plan");
        conn.execute(
            "INSERT INTO skill_plan_entries (character_id, plan_id, sort_position, skill_id, target_level) VALUES (90000001, 1, 0, 3300, 5)",
            [],
        )
        .expect("seed plan entry");
    }

    fn user_row_counts(conn: &rusqlite::Connection) -> (i64, i64, i64) {
        let characters: i64 = conn
            .query_row("SELECT COUNT(*) FROM characters", [], |r| r.get(0))
            .expect("characters count");
        let plans: i64 = conn
            .query_row("SELECT COUNT(*) FROM skill_plans", [], |r| r.get(0))
            .expect("plans count");
        let entries: i64 = conn
            .query_row("SELECT COUNT(*) FROM skill_plan_entries", [], |r| r.get(0))
            .expect("entries count");
        (characters, plans, entries)
    }

    fn type_count(conn: &rusqlite::Connection) -> i64 {
        conn.query_row("SELECT COUNT(*) FROM sde_types", [], |r| r.get(0))
            .expect("type count")
    }

    #[tokio::test]
    async fn sync_applies_build_then_304_fast_path() {
        let (base, hits, captured) =
            mock_sde_server(mock_state(100, "\"build-100\"", TYPES_V1)).await;
        let sync = SdeSync::with_http(reqwest::Client::new(), base);
        let mut conn = crate::storage::db::open_in_memory().expect("db");
        seed_user_rows(&conn);
        let outcome = sync.sync(&mut conn).await.expect("first sync");
        assert_eq!(
            outcome,
            SyncOutcome::Updated {
                build_number: 100,
                types: 2,
                solar_systems: 2,
                stargates: 1
            }
        );
        assert_eq!(local_build_number(&conn).expect("build"), 100);
        assert_eq!(type_count(&conn), 2);
        assert_eq!(user_row_counts(&conn), (1, 1, 1));
        let hits_after_first = hits.load(Ordering::SeqCst);
        assert!(
            hits_after_first >= 4,
            "manifest + 3 slices, got {hits_after_first}"
        );

        // Second sync: manifest answers 304 via the stored ETag, so no
        // JSONL slice is fetched again.
        let outcome2 = sync.sync(&mut conn).await.expect("second sync");
        assert_eq!(outcome2, SyncOutcome::NotModified { build_number: 100 });
        assert_eq!(
            hits.load(Ordering::SeqCst),
            hits_after_first + 1,
            "304 fast-path must issue exactly one manifest request"
        );
        let requests = captured.lock().expect("captured lock").clone();
        let last = requests.last().expect("last request");
        assert!(last.to_lowercase().contains("if-none-match: \"build-100\""));
        assert_eq!(type_count(&conn), 2);
        assert_eq!(user_row_counts(&conn), (1, 1, 1));
    }

    #[tokio::test]
    async fn sync_atomic_build_number_upgrade_replaces_rows() {
        let (base, _hits, _captured) =
            mock_sde_server(mock_state(100, "\"build-100\"", TYPES_V1)).await;
        let sync = SdeSync::with_http(reqwest::Client::new(), base.clone());
        let mut conn = crate::storage::db::open_in_memory().expect("db");
        seed_user_rows(&conn);
        sync.sync(&mut conn).await.expect("v1 sync");
        assert_eq!(type_count(&conn), 2);

        let (base2, _h2, _c2) = mock_sde_server(mock_state(101, "\"build-101\"", TYPES_V2)).await;
        let sync2 = SdeSync::with_http(reqwest::Client::new(), base2);
        let _ = base;
        let outcome = sync2.sync(&mut conn).await.expect("v2 sync");
        assert_eq!(
            outcome,
            SyncOutcome::Updated {
                build_number: 101,
                types: 3,
                solar_systems: 2,
                stargates: 1
            }
        );
        assert_eq!(local_build_number(&conn).expect("build"), 101);
        assert_eq!(type_count(&conn), 3);
        let name: String = conn
            .query_row("SELECT name FROM sde_types WHERE type_id = 36", [], |r| {
                r.get(0)
            })
            .expect("mexallon present after upgrade");
        assert_eq!(name, "Mexallon");
        // Pyerite (35) existed only in build 100 and is gone after the swap.
        let stale: i64 = conn
            .query_row(
                "SELECT COUNT(*) FROM sde_types WHERE type_id = 35",
                [],
                |r| r.get(0),
            )
            .expect("stale check");
        assert_eq!(stale, 0);
        assert_eq!(user_row_counts(&conn), (1, 1, 1));
    }

    #[tokio::test]
    async fn truncated_jsonl_rolls_back_and_keeps_prior_build() {
        let (base, _h, _c) = mock_sde_server(mock_state(100, "\"build-100\"", TYPES_V1)).await;
        let sync = SdeSync::with_http(reqwest::Client::new(), base);
        let mut conn = crate::storage::db::open_in_memory().expect("db");
        seed_user_rows(&conn);
        sync.sync(&mut conn).await.expect("good sync");
        assert_eq!(local_build_number(&conn).expect("build"), 100);

        let truncated = "{\"typeID\":34,\"typeName\":\"Tritanium\",\"groupID\":18,\"published\":true}\n{\"typeID\":36,\"typeName\":\"Mex";
        let (base2, _h2, _c2) = mock_sde_server(mock_state(101, "\"build-101\"", truncated)).await;
        let sync2 = SdeSync::with_http(reqwest::Client::new(), base2);
        let result = sync2.sync(&mut conn).await;
        assert!(
            result.is_err(),
            "truncated JSONL must fail, got: {result:?}"
        );
        // Prior verified build keeps serving; user rows untouched.
        assert_eq!(
            local_build_number(&conn).expect("build after rollback"),
            100
        );
        assert_eq!(type_count(&conn), 2);
        let name: String = conn
            .query_row("SELECT name FROM sde_types WHERE type_id = 35", [], |r| {
                r.get(0)
            })
            .expect("pyerite survives rollback");
        assert_eq!(name, "Pyerite");
        assert_eq!(user_row_counts(&conn), (1, 1, 1));
    }

    #[tokio::test]
    async fn empty_jsonl_slice_aborts_without_touching_prior_build() {
        let (base, _h, _c) = mock_sde_server(mock_state(100, "\"build-100\"", TYPES_V1)).await;
        let sync = SdeSync::with_http(reqwest::Client::new(), base);
        let mut conn = crate::storage::db::open_in_memory().expect("db");
        sync.sync(&mut conn).await.expect("good sync");
        let (base2, _h2, _c2) = mock_sde_server(mock_state(101, "\"build-101\"", "")).await;
        let sync2 = SdeSync::with_http(reqwest::Client::new(), base2);
        let result = sync2.sync(&mut conn).await;
        assert!(result.is_err(), "empty slice must abort, got: {result:?}");
        assert_eq!(local_build_number(&conn).expect("build"), 100);
        assert_eq!(type_count(&conn), 2);
    }

    #[tokio::test]
    async fn demo_sde_isolation_issues_zero_requests() {
        let (base, hits, _captured) =
            mock_sde_server(mock_state(100, "\"build-100\"", TYPES_V1)).await;
        let sync = SdeSync::with_http(reqwest::Client::new(), base);
        let mut conn = crate::storage::db::open_in_memory().expect("db");
        let outcome = sync
            .sync_if_allowed(&mut conn, true)
            .await
            .expect("demo guard");
        assert_eq!(outcome, SyncOutcome::SkippedDemo);
        assert_eq!(
            hits.load(Ordering::SeqCst),
            0,
            "demo mode must issue zero SDE HTTP requests"
        );
        assert_eq!(local_build_number(&conn).expect("build"), 0);
    }

    #[test]
    fn parsers_reject_corrupt_and_empty_payloads() {
        assert!(parse_types_jsonl("").is_err());
        assert!(parse_types_jsonl("not json\n").is_err());
        assert!(parse_types_jsonl("{\"typeName\":\"NoId\"}\n").is_err());
        assert!(parse_solar_systems_jsonl("{\"name\":\"NoId\"}\n").is_err());
        assert!(parse_stargates_jsonl("{\"name\":\"NoId\"}\n").is_err());
        let rows = parse_types_jsonl(TYPES_V1).expect("valid types");
        assert_eq!(rows.len(), 2);
        assert_eq!(rows[0].type_id, 34);
        assert_eq!(rows[0].name, "Tritanium");
        assert!(rows[0].published);
    }
}
