//! Eve-Scout public Thera/Turnur feed (#646): fixture/bundled
//! JSON parser, TTL staleness, offline fallback. Live HTTP, if
//! wired by the shell, must be background, live-mode-only and
//! error-tolerant; this module itself performs no network I/O.

use serde::Deserialize;

use crate::error::AppResult;
use crate::exploration::router::{EdgeKind, RouterEdge};

/// Fresh window (spec R11): age < 5 min is Fresh, else Stale.
pub const EVESCOUT_TTL_SECS: i64 = 300;
/// Past 24h public edges are view-only regardless of opt-in.
pub const EVESCOUT_MAX_STALE_SECS: i64 = 24 * 3600;
pub const THERA_SYSTEM_ID: i64 = 31_000_005;
pub const TURNUR_SYSTEM_ID: i64 = 30_002_086;

/// Bundled fixture (Thera + Turnur rows) used offline/tests.
pub const FIXTURE_JSON: &str = r#"[
  {"id": 101, "out_system_id": 31000005, "in_system_id": 30000142,
   "out_signature": "ABC-123", "in_signature": "DEF-456",
   "wh_type": "B274", "wh_exits_outward": true, "expires_at": 2000000000},
  {"id": 102, "out_system_id": 30002086, "in_system_id": 30002672,
   "out_signature": "GHI-789", "in_signature": null,
   "wh_type": "K162", "wh_exits_outward": false, "expires_at": null}
]"#;

#[derive(Debug, Clone, Deserialize)]
struct RawConnection {
    id: serde_json::Value,
    out_system_id: i64,
    in_system_id: i64,
    #[serde(default)]
    out_signature: Option<String>,
    #[serde(default)]
    in_signature: Option<String>,
    #[serde(default)]
    wh_type: Option<String>,
    #[serde(default)]
    wh_exits_outward: Option<bool>,
    #[serde(default)]
    expires_at: Option<serde_json::Value>,
}

#[derive(Debug, Clone, PartialEq)]
pub struct EveScoutConnection {
    pub record_key: String,
    pub hub_system_id: i64,
    pub far_system_id: i64,
    pub hub_signature: Option<String>,
    pub far_signature: Option<String>,
    pub wh_type: Option<String>,
    pub wh_exits_outward: Option<bool>,
    /// Unix seconds; None = Unknown time (never closure/zero).
    pub expires_at: Option<i64>,
}

#[derive(Debug, Clone, PartialEq)]
pub struct EveScoutSnapshot {
    pub connections: Vec<EveScoutConnection>,
    pub fetched_at: i64,
}

impl EveScoutSnapshot {
    pub fn is_stale(&self, now: i64) -> bool {
        now.saturating_sub(self.fetched_at) >= EVESCOUT_TTL_SECS
    }
    pub fn age_secs(&self, now: i64) -> i64 {
        now.saturating_sub(self.fetched_at).max(0)
    }
}

fn parse_expires(v: &Option<serde_json::Value>) -> Option<i64> {
    match v {
        Some(serde_json::Value::Number(n)) => n.as_i64(),
        Some(serde_json::Value::String(s)) => chrono::DateTime::parse_from_rfc3339(s)
            .ok()
            .map(|dt| dt.timestamp())
            .or_else(|| s.parse::<i64>().ok()),
        _ => None,
    }
}

fn record_key(id: &serde_json::Value) -> String {
    match id {
        serde_json::Value::Number(n) => format!("evescout:{}", n.as_i64().unwrap_or(0)),
        serde_json::Value::String(s) => {
            let digits: String = s.trim_start_matches('0').to_string();
            format!("evescout:{}", if digits.is_empty() { "0" } else { &digits })
        }
        _ => "evescout:0".to_string(),
    }
}

/// Parse a Thera/Turnur payload. Unrecognised hubs are kept
/// (hub-agnostic) but non-positive/distinct-id failures drop
/// the row, never the whole snapshot.
pub fn parse_evescout_json(json: &str, fetched_at: i64) -> AppResult<EveScoutSnapshot> {
    tracing::debug!("[EXPLORE] parse_evescout_json bytes={}", json.len());
    let raw: Vec<RawConnection> = serde_json::from_str(json)?;
    let mut connections = Vec::new();
    for row in raw {
        if row.out_system_id <= 0 || row.in_system_id <= 0 || row.out_system_id == row.in_system_id
        {
            continue;
        }
        connections.push(EveScoutConnection {
            record_key: record_key(&row.id),
            hub_system_id: row.out_system_id,
            far_system_id: row.in_system_id,
            hub_signature: row.out_signature,
            far_signature: row.in_signature,
            wh_type: row.wh_type,
            wh_exits_outward: row.wh_exits_outward,
            expires_at: parse_expires(&row.expires_at),
        });
    }
    Ok(EveScoutSnapshot {
        connections,
        fetched_at,
    })
}

/// Router edges from a snapshot. Expired rows always excluded;
/// stale rows only with explicit `use_stale` and age < 24h.
pub fn snapshot_edges(snapshot: &EveScoutSnapshot, now: i64, use_stale: bool) -> Vec<RouterEdge> {
    if snapshot.is_stale(now) && (!use_stale || snapshot.age_secs(now) >= EVESCOUT_MAX_STALE_SECS) {
        tracing::debug!("[EXPLORE] evescout snapshot stale; edges withheld");
        return Vec::new();
    }
    let mut edges = Vec::new();
    for conn in &snapshot.connections {
        if conn.expires_at.is_some_and(|exp| now >= exp) {
            continue;
        }
        let mass: Option<i64> = None; // public feed reports no mass state (R10)
        for (from, to) in [
            (conn.hub_system_id, conn.far_system_id),
            (conn.far_system_id, conn.hub_system_id),
        ] {
            edges.push(RouterEdge {
                from_id: from,
                to_id: to,
                kind: EdgeKind::Wormhole,
                max_jump_mass_kg: mass,
                wormhole_code: conn.wh_type.clone(),
                paired_forward_code: None,
                expires_at: conn.expires_at,
                verified: true,
            });
        }
    }
    edges
}

/// Offline fallback: stargates + local verified edges only.
pub fn offline_fallback_edges(
    stargate_edges: Vec<RouterEdge>,
    local_edges: Vec<RouterEdge>,
) -> Vec<RouterEdge> {
    let mut edges = stargate_edges;
    edges.extend(local_edges);
    edges
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::exploration::router::{find_route, RouteMode, SystemNode};

    #[test]
    fn fixture_parse_thera_turnur_and_orientation() {
        let snap = parse_evescout_json(FIXTURE_JSON, 1_000).unwrap();
        assert_eq!(snap.connections.len(), 2);
        assert_eq!(snap.connections[0].hub_system_id, THERA_SYSTEM_ID);
        assert_eq!(snap.connections[0].wh_type.as_deref(), Some("B274"));
        assert_eq!(snap.connections[0].wh_exits_outward, Some(true));
        assert_eq!(snap.connections[0].expires_at, Some(2_000_000_000));
        assert_eq!(snap.connections[1].hub_system_id, TURNUR_SYSTEM_ID);
        assert_eq!(
            snap.connections[1].far_signature, None,
            "missing far sig stays None"
        );
        // ISO expiry accepted too
        let iso = r#"[{"id":"007","out_system_id":31000005,"in_system_id":30000142,"expires_at":"2033-05-18T03:33:20Z"}]"#;
        let s2 = parse_evescout_json(iso, 0).unwrap();
        assert_eq!(s2.connections[0].record_key, "evescout:7");
        assert_eq!(s2.connections[0].expires_at, Some(2_000_000_000));
    }

    #[test]
    fn stale_ttl_marker_and_24h_view_only() {
        let snap = parse_evescout_json(FIXTURE_JSON, 1_000).unwrap();
        assert!(!snap.is_stale(1_000 + EVESCOUT_TTL_SECS - 1));
        assert!(
            snap.is_stale(1_000 + EVESCOUT_TTL_SECS),
            "at TTL boundary stale"
        );
        // Fresh: edges present; stale without opt-in: withheld
        assert!(!snapshot_edges(&snap, 1_000, false).is_empty());
        assert!(snapshot_edges(&snap, 1_000 + EVESCOUT_TTL_SECS, false).is_empty());
        assert!(!snapshot_edges(&snap, 1_000 + EVESCOUT_TTL_SECS, true).is_empty());
        // >=24h: view-only even with opt-in
        assert!(snapshot_edges(&snap, 1_000 + EVESCOUT_MAX_STALE_SECS, true).is_empty());
    }

    #[test]
    fn offline_fallback_routes_over_gates_and_local_only() {
        let nodes = vec![
            SystemNode {
                system_id: 1,
                name: "A".into(),
                security: Some(0.9),
                wormhole_class: None,
            },
            SystemNode {
                system_id: 2,
                name: "B".into(),
                security: Some(0.9),
                wormhole_class: None,
            },
            SystemNode {
                system_id: 3,
                name: "J1".into(),
                security: None,
                wormhole_class: Some(2),
            },
        ];
        let gates = vec![RouterEdge::stargate(1, 2), RouterEdge::stargate(2, 1)];
        let local = vec![RouterEdge::wormhole(
            2,
            3,
            "N944",
            Some(1_300_000_000),
            None,
        )];
        let edges = offline_fallback_edges(gates, local);
        let route = find_route(&nodes, &edges, 1, 3, RouteMode::Shortest, None, 0).unwrap();
        assert_eq!(route.system_ids, vec![1, 2, 3]);
    }
}
