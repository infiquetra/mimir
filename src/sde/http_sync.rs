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

use sha2::{Digest, Sha256};

use crate::config::{now_unix, EveConfig};
use crate::error::{AppError, AppResult};

/// Maximum accepted SDE response body (128 MiB); larger aborts without commit.
pub const MAX_SDE_BODY_BYTES: usize = 128 * 1024 * 1024;
const MAX_SDE_BODY_U64: u64 = MAX_SDE_BODY_BYTES as u64;

/// Validate an operator SDE base URL: `https` everywhere except loopback
/// `http` (127.0.0.1, localhost, [::1]) used by local mirrors and tests.
pub fn validate_base_url(raw: &str) -> AppResult<String> {
    let trimmed = raw.trim().trim_end_matches('/');
    let parsed = url::Url::parse(trimmed)
        .map_err(|e| AppError::Message(format!("[SDE] invalid base URL: {e}")))?;
    let host = parsed
        .host_str()
        .ok_or_else(|| AppError::Message("[SDE] base URL missing host".to_string()))?;
    let loopback = matches!(host, "127.0.0.1" | "localhost" | "::1" | "[::1]");
    match parsed.scheme() {
        "https" => Ok(trimmed.to_string()),
        "http" if loopback => Ok(trimmed.to_string()),
        "http" => Err(AppError::Message(
            "[SDE] base URL must use https (http only allowed for loopback)".to_string(),
        )),
        other => Err(AppError::Message(format!(
            "[SDE] base URL scheme '{other}' not allowed; use https"
        ))),
    }
}

/// Log-safe rendering of a base URL: scheme + host[:port] only. Userinfo,
/// path, query and fragment never appear, so credentials cannot leak.
pub fn redacted_base_for_log(raw: &str) -> String {
    match url::Url::parse(raw.trim()) {
        Ok(u) => match (u.host_str(), u.port()) {
            (Some(host), Some(port)) => format!("{}://{}:{}", u.scheme(), host, port),
            (Some(host), None) => format!("{}://{}", u.scheme(), host),
            _ => format!("{}://<invalid>", u.scheme()),
        },
        Err(_) => "<invalid-url>".to_string(),
    }
}

fn sha256_hex(body: &str) -> String {
    let digest = Sha256::digest(body.as_bytes());
    digest.iter().map(|b| format!("{b:02x}")).collect()
}

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

/// Short-lock snapshot of local SDE state (Step A). Read under the DB
/// mutex, then drop the guard before any network work.
#[derive(Debug, Clone, PartialEq)]
pub struct LocalSdeSnapshot {
    pub build_number: i64,
    pub etag: Option<String>,
}

/// Read the snapshot under a short lock; caller drops the guard after.
pub fn read_snapshot(conn: &rusqlite::Connection) -> AppResult<LocalSdeSnapshot> {
    Ok(LocalSdeSnapshot {
        build_number: local_build_number(conn)?,
        etag: local_meta(conn, "etag")?,
    })
}

/// A fully fetched and parsed build, ready for the short-lock commit
/// (Step C). Produced with zero DB lock held (Step B).
#[derive(Debug, Clone)]
pub struct FetchedBuild {
    pub build_number: i64,
    pub etag: Option<String>,
    pub types: Vec<SdeTypeRow>,
    pub solar_systems: Vec<SdeSolarSystemRow>,
    pub stargates: Vec<SdeStargateRow>,
}

/// Result of the lock-free fetch phase.
#[derive(Debug, Clone)]
pub enum FetchOutcome {
    NotModified { build_number: i64 },
    Ready(Box<FetchedBuild>),
    SkippedDemo,
}

/// Commit a fetched build under a short lock (Step C). Re-reads the
/// local build and aborts as `NotModified` if it moved since Step A,
/// so a stale fetch never overwrites a newer local build.
pub fn commit_fetched_build(
    conn: &mut rusqlite::Connection,
    snapshot: &LocalSdeSnapshot,
    fetched: FetchedBuild,
) -> AppResult<SyncOutcome> {
    let current = local_build_number(conn)?;
    if current != snapshot.build_number {
        tracing::warn!(
            "[SDE] aborting stale apply: local build moved {} -> {} during fetch",
            snapshot.build_number,
            current
        );
        return Ok(SyncOutcome::NotModified {
            build_number: current,
        });
    }
    tracing::info!(
        "[SDE] applying build {} types={} systems={} stargates={}",
        fetched.build_number,
        fetched.types.len(),
        fetched.solar_systems.len(),
        fetched.stargates.len()
    );
    apply_sde_build(
        conn,
        fetched.build_number,
        fetched.etag.as_deref(),
        &fetched.types,
        &fetched.solar_systems,
        &fetched.stargates,
    )?;
    Ok(SyncOutcome::Updated {
        build_number: fetched.build_number,
        types: fetched.types.len(),
        solar_systems: fetched.solar_systems.len(),
        stargates: fetched.stargates.len(),
    })
}

/// SDE-over-HTTP client. Construct with `new` in production (validates
/// the URL) and `with_http` against a local mock fixture in tests.
pub struct SdeSync {
    http: reqwest::Client,
    base_url: String,
}

impl SdeSync {
    pub fn new(base_url: String) -> AppResult<Self> {
        let validated = validate_base_url(&base_url)?;
        tracing::info!(
            "[SDE] creating SDE sync client base={}",
            redacted_base_for_log(&validated)
        );
        let http = reqwest::Client::builder()
            .timeout(std::time::Duration::from_millis(
                EveConfig::DEFAULT_TIMEOUT_MS,
            ))
            .user_agent(EveConfig::USER_AGENT)
            .build()
            .map_err(|e| AppError::Message(e.to_string()))?;
        Ok(Self::with_http(http, validated))
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
        let mut response = request
            .send()
            .await
            .map_err(|e| AppError::Message(format!("[SDE] request failed: {}", e.without_url())))?;
        let status = response.status().as_u16();
        let etag = response
            .headers()
            .get(reqwest::header::ETAG)
            .and_then(|v| v.to_str().ok())
            .map(|s| s.to_string());
        if let Some(len) = response.content_length() {
            if len > MAX_SDE_BODY_U64 {
                return Err(AppError::Message(format!(
                    "[SDE] response body too large for {path}: {len} bytes exceeds cap"
                )));
            }
        }
        // Stream with an enforced cap: never unbounded `text()`.
        let mut bytes: Vec<u8> = Vec::new();
        loop {
            let chunk = response.chunk().await.map_err(|e| {
                AppError::Message(format!("[SDE] body read failed: {}", e.without_url()))
            })?;
            let Some(chunk) = chunk else { break };
            if bytes.len() + chunk.len() > MAX_SDE_BODY_BYTES {
                return Err(AppError::Message(format!(
                    "[SDE] response body too large for {path}: exceeds cap"
                )));
            }
            bytes.extend_from_slice(&chunk);
        }
        let body = String::from_utf8(bytes)
            .map_err(|e| AppError::Message(format!("[SDE] body decode failed for {path}: {e}")))?;
        Ok((status, etag, body))
    }

    async fn get_slice(&self, path: &str) -> AppResult<String> {
        let (status, _etag, body) = self.get_text(path, None).await?;
        if status != 200 {
            return Err(AppError::Message(format!(
                "[SDE] slice {path} request failed with status {status}"
            )));
        }
        Ok(body)
    }

    /// Lock-free fetch phase (Step B): manifest + slices + parsing with
    /// no DB connection involved. Callable without any `&Connection`.
    pub async fn fetch_build(&self, snapshot: &LocalSdeSnapshot) -> AppResult<FetchOutcome> {
        validate_base_url(&self.base_url)?;
        let local_build = snapshot.build_number;
        tracing::info!(
            "[SDE] sync check local_build={} etag_present={}",
            local_build,
            snapshot.etag.is_some()
        );
        let (status, manifest_etag, manifest_body) = self
            .get_text("/manifest.json", snapshot.etag.as_deref())
            .await?;
        if status == 304 {
            tracing::info!("[SDE] manifest 304 not modified build={}", local_build);
            return Ok(FetchOutcome::NotModified {
                build_number: local_build,
            });
        }
        if status != 200 {
            return Err(AppError::Message(format!(
                "[SDE] manifest request failed with status {status}"
            )));
        }
        let manifest = parse_manifest(&manifest_body)?;
        let remote_build = manifest.build_number;
        if local_build > 0 && remote_build <= local_build {
            tracing::info!(
                "[SDE] manifest build {} not newer than local {}",
                remote_build,
                local_build
            );
            return Ok(FetchOutcome::NotModified {
                build_number: local_build,
            });
        }
        let types_body = self.get_slice("/types.jsonl").await?;
        let systems_body = self.get_slice("/mapSolarSystems.jsonl").await?;
        let stargates_body = self.get_slice("/mapStargates.jsonl").await?;
        // Validate digests/counts against the manifest when it carries them.
        validate_slice(&manifest, "types", &types_body)?;
        validate_slice(&manifest, "systems", &systems_body)?;
        validate_slice(&manifest, "stargates", &stargates_body)?;
        let types = parse_types_jsonl(&types_body)?;
        let systems = parse_solar_systems_jsonl(&systems_body)?;
        let stargates = parse_stargates_jsonl(&stargates_body)?;
        validate_count(&manifest, "types", types.len())?;
        validate_count(&manifest, "systems", systems.len())?;
        validate_count(&manifest, "stargates", stargates.len())?;
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
        Ok(FetchOutcome::Ready(Box::new(FetchedBuild {
            build_number: remote_build,
            etag: manifest_etag,
            types,
            solar_systems: systems,
            stargates,
        })))
    }

    /// Demo guard around the lock-free fetch: demo issues zero requests.
    pub async fn fetch_if_allowed(
        &self,
        snapshot: &LocalSdeSnapshot,
        demo: bool,
    ) -> AppResult<FetchOutcome> {
        if demo {
            tracing::info!("[SDE] sync skipped: demo mode (zero network requests)");
            return Ok(FetchOutcome::SkippedDemo);
        }
        self.fetch_build(snapshot).await
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

/// Parsed manifest: build number plus optional per-slice expectations.
/// Count/digest fields are `Option` and tolerant of absence.
#[derive(Debug, Clone, Default)]
struct ManifestInfo {
    build_number: i64,
    types_count: Option<usize>,
    systems_count: Option<usize>,
    stargates_count: Option<usize>,
    types_sha256: Option<String>,
    systems_sha256: Option<String>,
    stargates_sha256: Option<String>,
}

fn manifest_count(value: &serde_json::Value, slice: &str) -> Option<usize> {
    let direct = [
        format!("{slice}_count"),
        format!("{slice}_rows"),
        match slice {
            "types" => "type_count".to_string(),
            "systems" => "solar_systems_count".to_string(),
            _ => "stargate_count".to_string(),
        },
    ];
    for key in &direct {
        if let Some(n) = value.get(key).and_then(|v| v.as_u64()) {
            return Some(n as usize);
        }
    }
    if let Some(counts) = value.get("counts") {
        if let Some(n) = counts.get(slice).and_then(|v| v.as_u64()) {
            return Some(n as usize);
        }
    }
    if let Some(slices) = value.get("slices") {
        let file = match slice {
            "types" => "types.jsonl",
            "systems" => "mapSolarSystems.jsonl",
            _ => "mapStargates.jsonl",
        };
        if let Some(entry) = slices.get(file).or_else(|| slices.get(slice)) {
            if let Some(n) = entry
                .get("count")
                .or_else(|| entry.get("rows"))
                .and_then(|v| v.as_u64())
            {
                return Some(n as usize);
            }
        }
    }
    if let Some(entry) = value.get(slice) {
        if let Some(n) = entry
            .get("count")
            .or_else(|| entry.get("rows"))
            .and_then(|v| v.as_u64())
        {
            return Some(n as usize);
        }
    }
    None
}

fn manifest_digest(value: &serde_json::Value, slice: &str) -> Option<String> {
    let direct = [
        format!("{slice}_sha256"),
        format!("{slice}_sha"),
        format!("{slice}_digest"),
    ];
    for key in &direct {
        if let Some(s) = value.get(key).and_then(|v| v.as_str()) {
            return Some(s.to_lowercase());
        }
    }
    if let Some(digests) = value.get("sha256").or_else(|| value.get("digests")) {
        if let Some(s) = digests.get(slice).and_then(|v| v.as_str()) {
            return Some(s.to_lowercase());
        }
    }
    if let Some(slices) = value.get("slices") {
        let file = match slice {
            "types" => "types.jsonl",
            "systems" => "mapSolarSystems.jsonl",
            _ => "mapStargates.jsonl",
        };
        if let Some(entry) = slices.get(file).or_else(|| slices.get(slice)) {
            if let Some(s) = entry
                .get("sha256")
                .or_else(|| entry.get("digest"))
                .and_then(|v| v.as_str())
            {
                return Some(s.to_lowercase());
            }
        }
    }
    if let Some(entry) = value.get(slice) {
        if let Some(s) = entry
            .get("sha256")
            .or_else(|| entry.get("digest"))
            .and_then(|v| v.as_str())
        {
            return Some(s.to_lowercase());
        }
    }
    None
}

fn parse_manifest(body: &str) -> AppResult<ManifestInfo> {
    let value: serde_json::Value = serde_json::from_str(body)
        .map_err(|e| AppError::Message(format!("[SDE] manifest decode failed: {e}")))?;
    let build_number = value
        .get("build_number")
        .or_else(|| value.get("buildNumber"))
        .and_then(|v| v.as_i64())
        .ok_or_else(|| AppError::Message("[SDE] manifest missing build_number".to_string()))?;
    Ok(ManifestInfo {
        build_number,
        types_count: manifest_count(&value, "types"),
        systems_count: manifest_count(&value, "systems"),
        stargates_count: manifest_count(&value, "stargates"),
        types_sha256: manifest_digest(&value, "types"),
        systems_sha256: manifest_digest(&value, "systems"),
        stargates_sha256: manifest_digest(&value, "stargates"),
    })
}

fn expected_count(manifest: &ManifestInfo, slice: &str) -> Option<usize> {
    match slice {
        "types" => manifest.types_count,
        "systems" => manifest.systems_count,
        _ => manifest.stargates_count,
    }
}

fn expected_digest<'a>(manifest: &'a ManifestInfo, slice: &str) -> Option<&'a str> {
    match slice {
        "types" => manifest.types_sha256.as_deref(),
        "systems" => manifest.systems_sha256.as_deref(),
        _ => manifest.stargates_sha256.as_deref(),
    }
}

fn validate_slice(manifest: &ManifestInfo, slice: &str, body: &str) -> AppResult<()> {
    if let Some(expected) = expected_digest(manifest, slice) {
        let actual = sha256_hex(body);
        if actual != expected {
            tracing::warn!("[SDE] aborting sync: {slice} sha256 mismatch");
            return Err(AppError::Message(format!(
                "[SDE] aborting sync: {slice} sha256 mismatch"
            )));
        }
    }
    Ok(())
}

fn validate_count(manifest: &ManifestInfo, slice: &str, actual: usize) -> AppResult<()> {
    if let Some(expected) = expected_count(manifest, slice) {
        if actual != expected {
            tracing::warn!(
                "[SDE] aborting sync: {slice} row count mismatch expected={} actual={}",
                expected,
                actual
            );
            return Err(AppError::Message(format!(
                "[SDE] aborting sync: {slice} row count mismatch expected {expected} got {actual}"
            )));
        }
    }
    Ok(())
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

fn required_name(value: &serde_json::Value, keys: &[&str], label: &str) -> AppResult<String> {
    let name = json_string(value, keys)
        .ok_or_else(|| AppError::Message(format!("[SDE] {label} row missing name")))?;
    if name.trim().is_empty() {
        return Err(AppError::Message(format!("[SDE] {label} row missing name")));
    }
    Ok(name)
}

/// Parse a `types` JSONL slice. Field spellings accept the CCP SDE
/// camel/Pascal variants (`typeID`/`typeId`/`type_id`/`id`, and the
/// matching name/group keys); a line missing its ID or name, or with
/// an empty/whitespace name, is corrupt and rejects the whole slice.
pub fn parse_types_jsonl(body: &str) -> AppResult<Vec<SdeTypeRow>> {
    let values = parse_lines(body)?;
    let mut rows = Vec::with_capacity(values.len());
    for value in &values {
        let type_id = json_i64(value, &["typeID", "typeId", "type_id", "id", "_key"])
            .ok_or_else(|| AppError::Message("[SDE] types row missing type id".to_string()))?;
        let name = required_name(value, &["typeName", "name", "type_name"], "types")?;
        rows.push(SdeTypeRow {
            type_id,
            name,
            group_id: json_i64(value, &["groupID", "groupId", "group_id"]),
            published: json_bool(value, &["published"]),
        });
    }
    Ok(rows)
}

/// Parse a `mapSolarSystems` JSONL slice. A line missing its ID or
/// name, or with an empty/whitespace name, is corrupt.
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
            name: required_name(
                value,
                &["solarSystemName", "name", "system_name"],
                "solar system",
            )?,
            region_id: json_i64(value, &["regionID", "regionId", "region_id"]),
            security_status: json_f64(value, &["security", "securityStatus", "security_status"]),
        });
    }
    Ok(rows)
}

/// Parse a `mapStargates` JSONL slice (flat or nested `destination`).
/// Stargate rows carry no name in the SDE slices, so a missing name is
/// stored empty; a present but empty/whitespace name is corrupt.
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
        let gate_name = json_string(value, &["name", "stargateName"]);
        if let Some(n) = &gate_name {
            if n.trim().is_empty() {
                return Err(AppError::Message(
                    "[SDE] stargate row missing name".to_string(),
                ));
            }
        }
        rows.push(SdeStargateRow {
            stargate_id,
            name: gate_name.unwrap_or_default(),
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
        manifest_body: Option<String>,
        types_status: u16,
    }

    /// Three-step sync mirroring the shell: snapshot (short lock),
    /// fetch (no lock), commit (short lock).
    async fn run_sync(sync: &SdeSync, conn: &mut rusqlite::Connection) -> AppResult<SyncOutcome> {
        let snapshot = read_snapshot(conn)?;
        match sync.fetch_if_allowed(&snapshot, false).await? {
            FetchOutcome::Ready(fetched) => commit_fetched_build(conn, &snapshot, *fetched),
            FetchOutcome::NotModified { build_number } => {
                Ok(SyncOutcome::NotModified { build_number })
            }
            FetchOutcome::SkippedDemo => Ok(SyncOutcome::SkippedDemo),
        }
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
                            let body = state.manifest_body.clone().unwrap_or_else(|| {
                                format!("{{\"build_number\":{}}}", state.build_number)
                            });
                            format!(
                                "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nETag: {}\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{body}",
                                state.etag,
                                body.len()
                            )
                        }
                    } else if path == "/types.jsonl" {
                        format!(
                            "HTTP/1.1 {} OK\r\nContent-Type: application/json\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{}",
                            state.types_status,
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
            manifest_body: None,
            types_status: 200,
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
        let outcome = run_sync(&sync, &mut conn).await.expect("first sync");
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
        let outcome2 = run_sync(&sync, &mut conn).await.expect("second sync");
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
        run_sync(&sync, &mut conn).await.expect("v1 sync");
        assert_eq!(type_count(&conn), 2);

        let (base2, _h2, _c2) = mock_sde_server(mock_state(101, "\"build-101\"", TYPES_V2)).await;
        let sync2 = SdeSync::with_http(reqwest::Client::new(), base2);
        let _ = base;
        let outcome = run_sync(&sync2, &mut conn).await.expect("v2 sync");
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
        run_sync(&sync, &mut conn).await.expect("good sync");
        assert_eq!(local_build_number(&conn).expect("build"), 100);

        let truncated = "{\"typeID\":34,\"typeName\":\"Tritanium\",\"groupID\":18,\"published\":true}\n{\"typeID\":36,\"typeName\":\"Mex";
        let (base2, _h2, _c2) = mock_sde_server(mock_state(101, "\"build-101\"", truncated)).await;
        let sync2 = SdeSync::with_http(reqwest::Client::new(), base2);
        let result = run_sync(&sync2, &mut conn).await;
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
        run_sync(&sync, &mut conn).await.expect("good sync");
        let (base2, _h2, _c2) = mock_sde_server(mock_state(101, "\"build-101\"", "")).await;
        let sync2 = SdeSync::with_http(reqwest::Client::new(), base2);
        let result = run_sync(&sync2, &mut conn).await;
        assert!(result.is_err(), "empty slice must abort, got: {result:?}");
        assert_eq!(local_build_number(&conn).expect("build"), 100);
        assert_eq!(type_count(&conn), 2);
    }

    #[tokio::test]
    async fn demo_sde_isolation_issues_zero_requests() {
        let (base, hits, _captured) =
            mock_sde_server(mock_state(100, "\"build-100\"", TYPES_V1)).await;
        let sync = SdeSync::with_http(reqwest::Client::new(), base);
        let conn = crate::storage::db::open_in_memory().expect("db");
        let snapshot = read_snapshot(&conn).expect("snapshot");
        let outcome = sync
            .fetch_if_allowed(&snapshot, true)
            .await
            .expect("demo guard");
        assert!(matches!(outcome, FetchOutcome::SkippedDemo));
        assert_eq!(
            hits.load(Ordering::SeqCst),
            0,
            "demo mode must issue zero SDE HTTP requests"
        );
        assert_eq!(local_build_number(&conn).expect("build"), 0);
    }

    #[tokio::test]
    async fn fetch_build_callable_without_connection() {
        // Step B needs no &Connection: snapshot is plain data.
        let (base, _h, _c) = mock_sde_server(mock_state(100, "\"b100\"", TYPES_V1)).await;
        let sync = SdeSync::with_http(reqwest::Client::new(), base);
        let snapshot = LocalSdeSnapshot {
            build_number: 0,
            etag: None,
        };
        let outcome = sync.fetch_build(&snapshot).await.expect("fetch");
        match outcome {
            FetchOutcome::Ready(f) => {
                assert_eq!(f.build_number, 100);
                assert_eq!(f.types.len(), 2);
            }
            other => panic!("expected Ready, got {other:?}"),
        }
    }

    #[tokio::test]
    async fn commit_aborts_when_local_build_moved_during_fetch() {
        let (base, _h, _c) = mock_sde_server(mock_state(100, "\"b100\"", TYPES_V1)).await;
        let sync = SdeSync::with_http(reqwest::Client::new(), base.clone());
        let mut conn = crate::storage::db::open_in_memory().expect("db");
        run_sync(&sync, &mut conn).await.expect("v1");
        let (base2, _h2, _c2) = mock_sde_server(mock_state(101, "\"b101\"", TYPES_V2)).await;
        let sync2 = SdeSync::with_http(reqwest::Client::new(), base2);
        let snapshot = read_snapshot(&conn).expect("snap");
        let fetched = match sync2.fetch_build(&snapshot).await.expect("fetch") {
            FetchOutcome::Ready(f) => *f,
            other => panic!("expected Ready {other:?}"),
        };
        // Simulate another writer moving the build during fetch.
        conn.execute(
            "INSERT INTO sde_meta (key, value) VALUES ('build_number','999') ON CONFLICT(key) DO UPDATE SET value=excluded.value",
            [],
        )
        .expect("move build");
        let outcome = commit_fetched_build(&mut conn, &snapshot, fetched).expect("commit");
        assert_eq!(outcome, SyncOutcome::NotModified { build_number: 999 });
        assert_eq!(type_count(&conn), 2);
    }

    #[tokio::test]
    async fn slice_http_500_aborts_and_keeps_prior_build() {
        let (base, _h, _c) = mock_sde_server(mock_state(100, "\"b100\"", TYPES_V1)).await;
        let sync = SdeSync::with_http(reqwest::Client::new(), base);
        let mut conn = crate::storage::db::open_in_memory().expect("db");
        run_sync(&sync, &mut conn).await.expect("good");
        let mut bad = mock_state(101, "\"b101\"", TYPES_V2);
        bad.types_status = 500;
        let (base2, _h2, _c2) = mock_sde_server(bad).await;
        let sync2 = SdeSync::with_http(reqwest::Client::new(), base2);
        let result = run_sync(&sync2, &mut conn).await;
        assert!(result.is_err(), "500 slice must abort: {result:?}");
        assert_eq!(local_build_number(&conn).expect("b"), 100);
        assert_eq!(type_count(&conn), 2);
    }

    #[tokio::test]
    async fn manifest_count_mismatch_rolls_back() {
        let (base, _h, _c) = mock_sde_server(mock_state(100, "\"b100\"", TYPES_V1)).await;
        let sync = SdeSync::with_http(reqwest::Client::new(), base);
        let mut conn = crate::storage::db::open_in_memory().expect("db");
        run_sync(&sync, &mut conn).await.expect("good");
        // Short-but-line-aligned: 1 type line, manifest claims 99.
        let one = "{\"typeID\":34,\"typeName\":\"Tritanium\",\"groupID\":18,\"published\":true}\n";
        let mut st = mock_state(101, "\"b101\"", one);
        st.manifest_body = Some(
            "{\"build_number\":101,\"types_count\":99,\"systems_count\":2,\"stargates_count\":1}"
                .to_string(),
        );
        let (base2, _h2, _c2) = mock_sde_server(st).await;
        let sync2 = SdeSync::with_http(reqwest::Client::new(), base2);
        let result = run_sync(&sync2, &mut conn).await;
        assert!(result.is_err(), "count mismatch must abort: {result:?}");
        assert_eq!(local_build_number(&conn).expect("b"), 100);
        assert_eq!(type_count(&conn), 2);
    }

    #[tokio::test]
    async fn manifest_sha_mismatch_rolls_back() {
        let (base, _h, _c) = mock_sde_server(mock_state(100, "\"b100\"", TYPES_V1)).await;
        let sync = SdeSync::with_http(reqwest::Client::new(), base);
        let mut conn = crate::storage::db::open_in_memory().expect("db");
        run_sync(&sync, &mut conn).await.expect("good");
        let mut st = mock_state(101, "\"b101\"", TYPES_V2);
        st.manifest_body = Some(format!(
            "{{\"build_number\":101,\"types_sha256\":\"{}\"}}",
            "0".repeat(64)
        ));
        let (base2, _h2, _c2) = mock_sde_server(st).await;
        let sync2 = SdeSync::with_http(reqwest::Client::new(), base2);
        let result = run_sync(&sync2, &mut conn).await;
        assert!(result.is_err(), "sha mismatch must abort: {result:?}");
        assert_eq!(local_build_number(&conn).expect("b"), 100);
        assert_eq!(type_count(&conn), 2);
    }

    #[tokio::test]
    async fn manifest_sha_match_commits() {
        let mut st = mock_state(100, "\"b100\"", TYPES_V1);
        st.manifest_body = Some(format!(
            "{{\"build_number\":100,\"types_sha256\":\"{}\",\"types_count\":2}}",
            sha256_hex(TYPES_V1)
        ));
        let (base, _h, _c) = mock_sde_server(st).await;
        let sync = SdeSync::with_http(reqwest::Client::new(), base);
        let mut conn = crate::storage::db::open_in_memory().expect("db");
        let outcome = run_sync(&sync, &mut conn).await.expect("sha ok");
        assert!(matches!(
            outcome,
            SyncOutcome::Updated {
                build_number: 100,
                ..
            }
        ));
    }

    #[tokio::test]
    async fn over_cap_content_length_aborts_without_commit() {
        let listener = tokio::net::TcpListener::bind("127.0.0.1:0")
            .await
            .expect("bind cap mock");
        let addr = listener.local_addr().expect("addr");
        tokio::spawn(async move {
            if let Ok((mut socket, _)) = listener.accept().await {
                let mut buf = vec![0u8; 4096];
                let _ = socket.read(&mut buf).await;
                let payload = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nETag: \"x\"\r\nContent-Length: 200000000\r\nConnection: close\r\n\r\n{\"build_number\":100}";
                let _ = socket.write_all(payload.as_bytes()).await;
                let _ = socket.flush().await;
            }
        });
        let sync = SdeSync::with_http(reqwest::Client::new(), format!("http://{addr}"));
        let snapshot = LocalSdeSnapshot {
            build_number: 0,
            etag: None,
        };
        let result = sync.fetch_build(&snapshot).await;
        assert!(result.is_err(), "over-cap must abort: {result:?}");
        let msg = format!("{:?}", result.err());
        assert!(msg.contains("too large"), "cap error: {msg}");
    }

    #[test]
    fn base_url_validation_and_redacted_log() {
        assert!(validate_base_url("https://example.com/sde").is_ok());
        assert!(validate_base_url("http://127.0.0.1:8080/sde").is_ok());
        assert!(validate_base_url("http://localhost/sde").is_ok());
        assert!(validate_base_url("http://[::1]:9/sde").is_ok());
        assert!(validate_base_url("http://example.com/sde").is_err());
        assert!(validate_base_url("ftp://example.com/sde").is_err());
        assert!(SdeSync::new("http://example.com/sde".to_string()).is_err());
        let redacted =
            redacted_base_for_log("https://user:secret@example.com:8443/path?token=abc123");
        assert_eq!(redacted, "https://example.com:8443");
        assert!(!redacted.contains("secret"));
        assert!(!redacted.contains("abc123"));
        assert!(!redacted.contains("user"));
    }

    #[test]
    fn parsers_reject_missing_and_empty_names() {
        assert!(parse_types_jsonl("{\"typeID\":34}\n").is_err());
        assert!(parse_types_jsonl("{\"typeID\":34,\"typeName\":\"\"}\n").is_err());
        assert!(parse_types_jsonl("{\"typeID\":34,\"typeName\":\"  \"}\n").is_err());
        assert!(parse_solar_systems_jsonl("{\"solarSystemID\":1}\n").is_err());
        assert!(
            parse_solar_systems_jsonl("{\"solarSystemID\":1,\"solarSystemName\":\"\"}\n").is_err()
        );
        assert!(parse_types_jsonl(TYPES_V1).is_ok());
        assert!(parse_solar_systems_jsonl(SYSTEMS_V1).is_ok());
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
