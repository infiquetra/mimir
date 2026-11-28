//! Probe-scanner notebook (#646): paste parser + character-scoped
//! SQLite store. Hard invariant: unverified signatures NEVER
//! create traversable edges; scan data never leaves the device
//! (no network types in this module at all).

use rusqlite::{params, Connection};

use crate::error::AppResult;
use crate::exploration::router::{EdgeKind, RouterEdge};

pub const MAX_PASTE_BYTES: usize = 512 * 1024;
pub const MAX_PASTE_ROWS: usize = 5_000;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SignatureType {
    Unknown,
    Wormhole,
    Data,
    Relic,
    Gas,
    Combat,
    Ore,
}

#[derive(Debug, Clone, PartialEq)]
pub struct ParsedScanRow {
    pub signature_id: String,
    pub group: String,
    pub signature_type: SignatureType,
    pub type_label: String,
    pub name: Option<String>,
    pub signal_percent: Option<f64>,
}

#[derive(Debug, Clone, PartialEq)]
pub struct ParseOutcome {
    pub rows: Vec<ParsedScanRow>,
    /// (1-based source row, reason) for rejected rows.
    pub diagnostics: Vec<(usize, String)>,
}

fn valid_signature_id(code: &str) -> bool {
    let b = code.as_bytes();
    b.len() == 7
        && b[0].is_ascii_uppercase()
        && b[1].is_ascii_uppercase()
        && b[2].is_ascii_uppercase()
        && b[3] == b'-'
        && b[4].is_ascii_digit()
        && b[5].is_ascii_digit()
        && b[6].is_ascii_digit()
}

fn map_type(label: &str) -> SignatureType {
    match label.trim().to_ascii_lowercase().as_str() {
        "wormhole" => SignatureType::Wormhole,
        "data site" | "data" => SignatureType::Data,
        "relic site" | "relic" => SignatureType::Relic,
        "gas site" | "gas" => SignatureType::Gas,
        "combat site" | "combat" => SignatureType::Combat,
        "ore site" | "ore" => SignatureType::Ore,
        _ => SignatureType::Unknown,
    }
}

/// Parse EVE Probe Scanner tab-separated paste. Pure; caller
/// reads the clipboard only on explicit Paste. Whole-input
/// errors (oversize) return Err, never silent truncation.
pub fn parse_probe_scan(text: &str) -> AppResult<ParseOutcome> {
    tracing::debug!("[EXPLORE] parse_probe_scan bytes={}", text.len());
    if text.len() > MAX_PASTE_BYTES {
        return Err(crate::error::AppError::Message(format!(
            "scanner paste too large: {} bytes (max {MAX_PASTE_BYTES})",
            text.len()
        )));
    }
    let text = text.strip_prefix('\u{feff}').unwrap_or(text);
    let mut rows = Vec::new();
    let mut diagnostics = Vec::new();
    let mut nonblank = 0usize;
    for (idx, line) in text.lines().enumerate() {
        let row_no = idx + 1;
        if line.trim().is_empty() {
            continue;
        }
        nonblank += 1;
        if nonblank > MAX_PASTE_ROWS {
            return Err(crate::error::AppError::Message(format!(
                "scanner paste too many rows (max {MAX_PASTE_ROWS})"
            )));
        }
        let cells: Vec<&str> = line.split('\t').collect();
        // Optional English header.
        if cells
            .first()
            .is_some_and(|c| c.trim().eq_ignore_ascii_case("ID"))
            && cells
                .get(1)
                .is_some_and(|c| c.trim().eq_ignore_ascii_case("Group"))
        {
            continue;
        }
        if !(2..=6).contains(&cells.len()) {
            diagnostics.push((
                row_no,
                format!("expected 2-6 tab cells, got {}", cells.len()),
            ));
            continue;
        }
        let code = cells[0].trim().to_ascii_uppercase();
        if !valid_signature_id(&code) {
            diagnostics.push((row_no, "invalid signature id".to_string()));
            continue;
        }
        let group = cells[1].trim().to_string();
        let group_l = group.to_ascii_lowercase();
        if group_l != "cosmic signature" && group_l != "cosmic anomaly" {
            diagnostics.push((row_no, format!("unsupported group: {group}")));
            continue;
        }
        let type_label = cells
            .get(2)
            .map(|c| c.trim().to_string())
            .unwrap_or_default();
        let name = cells
            .get(3)
            .map(|c| c.trim().to_string())
            .filter(|s| !s.is_empty());
        let signal_percent = cells
            .get(4)
            .and_then(|c| c.trim().trim_end_matches('%').trim().parse::<f64>().ok());
        rows.push(ParsedScanRow {
            signature_id: code,
            group,
            signature_type: map_type(&type_label),
            type_label,
            name,
            signal_percent,
        });
    }
    Ok(ParseOutcome { rows, diagnostics })
}

#[derive(Debug, Clone, PartialEq)]
pub struct TrackedSignature {
    pub character_id: i64,
    pub system_id: i64,
    pub signature_id: String,
    pub signature_type: SignatureType,
    pub name: Option<String>,
    /// Only set by explicit Confirm connection; scans leave None.
    pub destination_system_id: Option<i64>,
    pub verified: bool,
    pub observed_at: i64,
}

/// Single source of truth: `src/storage/schema.sql` (included
/// as `SCHEMA_SQL` by `db::migrate`). Executing the full batch
/// keeps notebook tables byte-identical with migrated databases.
pub fn ensure_notebook_tables(conn: &Connection) -> AppResult<()> {
    conn.execute_batch(crate::storage::db::SCHEMA_SQL)?;
    Ok(())
}

fn type_label(t: SignatureType) -> &'static str {
    match t {
        SignatureType::Unknown => "Unknown",
        SignatureType::Wormhole => "Wormhole",
        SignatureType::Data => "Data",
        SignatureType::Relic => "Relic",
        SignatureType::Gas => "Gas",
        SignatureType::Combat => "Combat",
        SignatureType::Ore => "Ore",
    }
}
fn type_from_label(s: &str) -> SignatureType {
    match s {
        "Wormhole" => SignatureType::Wormhole,
        "Data" => SignatureType::Data,
        "Relic" => SignatureType::Relic,
        "Gas" => SignatureType::Gas,
        "Combat" => SignatureType::Combat,
        "Ore" => SignatureType::Ore,
        _ => SignatureType::Unknown,
    }
}

/// Import parsed rows for one character/system. Signatures are
/// stored unverified with no destination: import alone can
/// never create a route edge. Returns rows written.
pub fn import_scan(
    conn: &Connection,
    character_id: i64,
    system_id: i64,
    rows: &[ParsedScanRow],
    now: i64,
) -> AppResult<usize> {
    ensure_notebook_tables(conn)?;
    tracing::info!(
        "[EXPLORE] import_scan character_id={} system_id={} rows={}",
        character_id,
        system_id,
        rows.len()
    );
    let tx = conn.unchecked_transaction()?;
    let mut written = 0;
    for row in rows {
        // R20: a rescan changing a signature away from Wormhole
        // atomically retires its owned connection in this tx.
        let previous: Option<(String, Option<i64>)> = tx
            .query_row(
                "SELECT signature_type, destination_system_id FROM exploration_signatures \
                 WHERE character_id=?1 AND system_id=?2 AND signature_id=?3",
                params![character_id, system_id, row.signature_id],
                |r| Ok((r.get(0)?, r.get(1)?)),
            )
            .ok();
        if let Some((prev_label, prev_dest)) = &previous {
            if type_from_label(prev_label) == SignatureType::Wormhole
                && row.signature_type != SignatureType::Wormhole
            {
                if let Some(dest) = prev_dest {
                    tx.execute(
                        "DELETE FROM exploration_connections \
                         WHERE character_id=?1 AND from_system_id=?2 AND to_system_id=?3",
                        params![character_id, system_id, dest],
                    )?;
                    tracing::info!(
                        "[EXPLORE] retired connection on rescan signature_id={}",
                        row.signature_id
                    );
                }
            }
        }
        tx.execute(
            "INSERT INTO exploration_signatures \
             (character_id, system_id, signature_id, signature_type, name, destination_system_id, verified, observed_at) \
             VALUES (?1,?2,?3,?4,?5,NULL,0,?6) \
             ON CONFLICT(character_id, system_id, signature_id) DO UPDATE SET \
             signature_type=excluded.signature_type, name=excluded.name, observed_at=excluded.observed_at",
            params![
                character_id,
                system_id,
                row.signature_id,
                type_label(row.signature_type),
                row.name,
                now
            ],
        )?;
        if previous.as_ref().is_some_and(|(prev_label, _)| {
            type_from_label(prev_label) == SignatureType::Wormhole
                && row.signature_type != SignatureType::Wormhole
        }) {
            tx.execute(
                "UPDATE exploration_signatures SET destination_system_id=NULL, verified=0 \
                 WHERE character_id=?1 AND system_id=?2 AND signature_id=?3",
                params![character_id, system_id, row.signature_id],
            )?;
        }
        written += 1;
    }
    tx.commit()?;
    Ok(written)
}

pub fn list_signatures(
    conn: &Connection,
    character_id: i64,
    system_id: i64,
) -> AppResult<Vec<TrackedSignature>> {
    ensure_notebook_tables(conn)?;
    let mut stmt = conn.prepare(
        "SELECT character_id, system_id, signature_id, signature_type, name, \
         destination_system_id, verified, observed_at FROM exploration_signatures \
         WHERE character_id=?1 AND system_id=?2 ORDER BY signature_id",
    )?;
    let rows = stmt.query_map(params![character_id, system_id], |r| {
        Ok(TrackedSignature {
            character_id: r.get(0)?,
            system_id: r.get(1)?,
            signature_id: r.get(2)?,
            signature_type: type_from_label(&r.get::<_, String>(3)?),
            name: r.get(4)?,
            destination_system_id: r.get(5)?,
            verified: r.get::<_, i64>(6)? != 0,
            observed_at: r.get(7)?,
        })
    })?;
    let mut out = Vec::new();
    for row in rows {
        out.push(row?);
    }
    Ok(out)
}

/// Parameters for the ONLY edge-creating path.
#[derive(Debug, Clone)]
pub struct ConfirmConnection {
    pub character_id: i64,
    pub from_system_id: i64,
    pub signature_id: String,
    pub to_system_id: i64,
    pub wormhole_code: String,
    pub max_jump_mass_kg: Option<i64>,
    pub expires_at: Option<i64>,
    pub now: i64,
}

/// Explicitly confirm a connection. Requires a wormhole
/// signature already in the notebook for this character.
pub fn confirm_connection(conn: &Connection, req: &ConfirmConnection) -> AppResult<()> {
    let (
        character_id,
        from_system_id,
        signature_id,
        to_system_id,
        wormhole_code,
        max_jump_mass_kg,
        expires_at,
        now,
    ) = (
        req.character_id,
        req.from_system_id,
        req.signature_id.as_str(),
        req.to_system_id,
        req.wormhole_code.as_str(),
        req.max_jump_mass_kg,
        req.expires_at,
        req.now,
    );
    ensure_notebook_tables(conn)?;
    if from_system_id == to_system_id {
        return Err(crate::error::AppError::Message(
            "connection endpoints must differ".to_string(),
        ));
    }
    if wormhole_code.trim().is_empty() {
        return Err(crate::error::AppError::Message(
            "wormhole code must not be empty".to_string(),
        ));
    }
    if expires_at.is_some_and(|exp| exp <= now) {
        return Err(crate::error::AppError::Message(
            "connection expiry must be in the future".to_string(),
        ));
    }
    tracing::info!(
        "[EXPLORE] confirm_connection character_id={} signature_id={}",
        character_id,
        signature_id
    );
    let tx = conn.unchecked_transaction()?;
    // R20 inside the transaction: only an active Wormhole
    // signature may own a connection.
    let stored_type: Option<String> = tx
        .query_row(
            "SELECT signature_type FROM exploration_signatures \
             WHERE character_id=?1 AND system_id=?2 AND signature_id=?3",
            params![character_id, from_system_id, signature_id],
            |r| r.get(0),
        )
        .ok();
    match stored_type.as_deref() {
        None => {
            return Err(crate::error::AppError::Message(
                "signature not in notebook for this character/system".to_string(),
            ));
        }
        Some(label) if type_from_label(label) != SignatureType::Wormhole => {
            return Err(crate::error::AppError::Message(
                "only a wormhole signature can own a connection".to_string(),
            ));
        }
        _ => {}
    }
    tx.execute(
        "UPDATE exploration_signatures SET destination_system_id=?1, verified=1 \
         WHERE character_id=?2 AND system_id=?3 AND signature_id=?4",
        params![to_system_id, character_id, from_system_id, signature_id],
    )?;
    tx.execute(
        "INSERT OR REPLACE INTO exploration_connections \
         (character_id, from_system_id, to_system_id, wormhole_code, max_jump_mass_kg, expires_at, verified_at) \
         VALUES (?1,?2,?3,?4,?5,?6,?7)",
        params![character_id, from_system_id, to_system_id, wormhole_code, max_jump_mass_kg, expires_at, now],
    )?;
    tx.commit()?;
    Ok(())
}

/// Traversable edges for routing: verified connections only,
/// character-scoped, unexpired. Unverified signatures yield none.
pub fn traversable_edges(
    conn: &Connection,
    character_id: i64,
    now: i64,
) -> AppResult<Vec<RouterEdge>> {
    ensure_notebook_tables(conn)?;
    let mut stmt = conn.prepare(
        "SELECT from_system_id, to_system_id, wormhole_code, max_jump_mass_kg, expires_at, verified_at \
         FROM exploration_connections WHERE character_id=?1 ORDER BY from_system_id, to_system_id",
    )?;
    let rows = stmt.query_map(params![character_id], |r| {
        Ok((
            r.get::<_, i64>(0)?,
            r.get::<_, i64>(1)?,
            r.get::<_, String>(2)?,
            r.get::<_, Option<i64>>(3)?,
            r.get::<_, Option<i64>>(4)?,
            r.get::<_, i64>(5)?,
        ))
    })?;
    let mut edges = Vec::new();
    for row in rows {
        let (from, to, code, mass, expires, verified_at) = row?;
        if expires.is_some_and(|exp| now >= exp) {
            continue;
        }
        // R20/R22: verification expires for routing after 24h.
        if now.saturating_sub(verified_at) >= 86_400 {
            continue;
        }
        // Both directions: wormholes are traversable both ways (R21).
        edges.push(RouterEdge {
            from_id: from,
            to_id: to,
            kind: EdgeKind::Wormhole,
            max_jump_mass_kg: mass,
            wormhole_code: Some(code.clone()),
            paired_forward_code: None,
            expires_at: expires,
            verified: true,
        });
        edges.push(RouterEdge {
            from_id: to,
            to_id: from,
            kind: EdgeKind::Wormhole,
            max_jump_mass_kg: mass,
            wormhole_code: Some(code),
            paired_forward_code: None,
            expires_at: expires,
            verified: true,
        });
    }
    Ok(edges)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn mem() -> Connection {
        Connection::open_in_memory().unwrap()
    }

    #[test]
    fn paste_parse_valid_header_crlf_and_invalid_rows() {
        let text = "ID\tGroup\tType\tName\tSignal\tDistance\r\nABC-123\tCosmic Signature\tWormhole\t\t100.0%\t12.3 km\r\nXYZ-999\tCosmic Anomaly\tCombat Site\tRuined Site\t85.5%\t1.0 km\nbad-row\nDEF-456\tCosmic Signature\tData Site\t\t50%\t2 km";
        let out = parse_probe_scan(text).unwrap();
        assert_eq!(out.rows.len(), 3);
        assert_eq!(out.rows[0].signature_id, "ABC-123");
        assert_eq!(out.rows[0].signature_type, SignatureType::Wormhole);
        assert_eq!(out.rows[1].signature_type, SignatureType::Combat);
        assert_eq!(out.diagnostics.len(), 1);
        assert_eq!(out.diagnostics[0].0, 4);
        // Lowercase id normalised
        let out2 = parse_probe_scan("abc-123\tCosmic Signature\tWormhole").unwrap();
        assert_eq!(out2.rows[0].signature_id, "ABC-123");
        // Oversize is whole-input error, not truncation
        assert!(parse_probe_scan(&"x".repeat(MAX_PASTE_BYTES + 1)).is_err());
    }

    #[test]
    fn unverified_signatures_never_create_edges() {
        let conn = mem();
        let parsed =
            parse_probe_scan("ABC-123\tCosmic Signature\tWormhole\tWormhole ABC-123").unwrap();
        import_scan(&conn, 7, 100, &parsed.rows, 1_000).unwrap();
        let sigs = list_signatures(&conn, 7, 100).unwrap();
        assert_eq!(sigs.len(), 1);
        assert!(!sigs[0].verified);
        assert_eq!(sigs[0].destination_system_id, None);
        // THE invariant: a scanned wormhole row alone yields zero edges
        assert!(traversable_edges(&conn, 7, 1_000).unwrap().is_empty());
        // Only explicit confirmation creates edges (both directions)
        confirm_connection(
            &conn,
            &ConfirmConnection {
                character_id: 7,
                from_system_id: 100,
                signature_id: "ABC-123".to_string(),
                to_system_id: 200,
                wormhole_code: "B274".to_string(),
                max_jump_mass_kg: Some(375_000_000),
                expires_at: None,
                now: 1_000,
            },
        )
        .unwrap();
        let edges = traversable_edges(&conn, 7, 1_000).unwrap();
        assert_eq!(edges.len(), 2);
        assert!(edges.iter().all(|e| e.verified));
    }

    #[test]
    fn character_scoping_isolates_notebooks() {
        let conn = mem();
        let parsed = parse_probe_scan("ABC-123\tCosmic Signature\tWormhole").unwrap();
        import_scan(&conn, 7, 100, &parsed.rows, 1).unwrap();
        import_scan(&conn, 8, 100, &parsed.rows, 1).unwrap();
        confirm_connection(
            &conn,
            &ConfirmConnection {
                character_id: 7,
                from_system_id: 100,
                signature_id: "ABC-123".to_string(),
                to_system_id: 200,
                wormhole_code: "B274".to_string(),
                max_jump_mass_kg: None,
                expires_at: None,
                now: 1,
            },
        )
        .unwrap();
        assert_eq!(list_signatures(&conn, 7, 100).unwrap().len(), 1);
        assert_eq!(list_signatures(&conn, 8, 100).unwrap().len(), 1);
        assert_eq!(traversable_edges(&conn, 7, 1).unwrap().len(), 2);
        assert!(
            traversable_edges(&conn, 8, 1).unwrap().is_empty(),
            "no cross-character bleed"
        );
        // Expired confirmed edge pruned
        assert!(traversable_edges(&conn, 7, 1).unwrap().len() == 2);
    }

    fn confirm_req(code: &str, expires_at: Option<i64>, now: i64) -> ConfirmConnection {
        ConfirmConnection {
            character_id: 7,
            from_system_id: 100,
            signature_id: "ABC-123".to_string(),
            to_system_id: 200,
            wormhole_code: code.to_string(),
            max_jump_mass_kg: None,
            expires_at,
            now,
        }
    }

    #[test]
    fn data_and_combat_signatures_cannot_own_connections() {
        for paste in [
            "ABC-123\tCosmic Signature\tData Site",
            "ABC-123\tCosmic Anomaly\tCombat Site",
        ] {
            let conn = mem();
            let parsed = parse_probe_scan(paste).unwrap();
            import_scan(&conn, 7, 100, &parsed.rows, 1_000).unwrap();
            assert!(
                confirm_connection(&conn, &confirm_req("B274", None, 1_000)).is_err(),
                "{paste}"
            );
            assert!(traversable_edges(&conn, 7, 1_000).unwrap().is_empty());
        }
    }

    #[test]
    fn rescan_away_from_wormhole_retires_edge() {
        let conn = mem();
        let wh = parse_probe_scan("ABC-123\tCosmic Signature\tWormhole").unwrap();
        import_scan(&conn, 7, 100, &wh.rows, 1_000).unwrap();
        confirm_connection(&conn, &confirm_req("B274", None, 1_000)).unwrap();
        assert_eq!(traversable_edges(&conn, 7, 1_000).unwrap().len(), 2);
        let relic = parse_probe_scan("ABC-123\tCosmic Signature\tRelic Site").unwrap();
        import_scan(&conn, 7, 100, &relic.rows, 2_000).unwrap();
        assert!(traversable_edges(&conn, 7, 2_000).unwrap().is_empty());
    }

    #[test]
    fn verification_age_24h_boundary_and_expiry_validation() {
        let conn = mem();
        let wh = parse_probe_scan("ABC-123\tCosmic Signature\tWormhole").unwrap();
        import_scan(&conn, 7, 100, &wh.rows, 1_000).unwrap();
        // Past expiry and empty code rejected.
        assert!(confirm_connection(&conn, &confirm_req("B274", Some(999), 1_000)).is_err());
        assert!(confirm_connection(&conn, &confirm_req("B274", Some(1_000), 1_000)).is_err());
        assert!(confirm_connection(&conn, &confirm_req("", None, 1_000)).is_err());
        assert!(confirm_connection(&conn, &confirm_req("  ", None, 1_000)).is_err());
        confirm_connection(&conn, &confirm_req("B274", None, 1_000)).unwrap();
        // 23h59m included, exactly 24h excluded.
        assert_eq!(
            traversable_edges(&conn, 7, 1_000 + 86_399).unwrap().len(),
            2
        );
        assert!(traversable_edges(&conn, 7, 1_000 + 86_400)
            .unwrap()
            .is_empty());
        assert!(traversable_edges(&conn, 7, 1_000 + 400 * 86_400)
            .unwrap()
            .is_empty());
    }

    #[test]
    fn notebook_tables_match_schema_source() {
        let via_ensure = mem();
        ensure_notebook_tables(&via_ensure).unwrap();
        let via_schema = mem();
        via_schema
            .execute_batch(crate::storage::db::SCHEMA_SQL)
            .unwrap();
        for conn in [&via_ensure, &via_schema] {
            let count: i64 = conn
                .query_row(
                    "SELECT COUNT(*) FROM sqlite_master WHERE type='table' \
                     AND name IN ('exploration_signatures','exploration_connections')",
                    [],
                    |r| r.get(0),
                )
                .unwrap();
            assert_eq!(count, 2);
        }
    }
}
