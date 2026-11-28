//! Eve-Scout public Thera/Turnur feed (#646): fixture/bundled
//! JSON parser, TTL staleness, offline fallback. Live HTTP, if
//! wired by the shell, must be background, live-mode-only and
//! error-tolerant; this module itself performs no network I/O.

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
   "wh_type": "B274", "wh_exits_outward": true, "expires_at": 2000000000,
   "max_ship_size": "Battleship"},
  {"id": 102, "out_system_id": 30002086, "in_system_id": 30002672,
   "out_signature": "GHI-789", "in_signature": null,
   "wh_type": "N944", "wh_exits_outward": false, "expires_at": null,
   "max_ship_size": "Capital"}
]"#;

/// Reported maximum ship size category; unrecognized feed
/// strings keep their raw label as `Unknown` (spec field table).
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum MaxShipSize {
    Frigate,
    Destroyer,
    Cruiser,
    Battlecruiser,
    Battleship,
    Capital,
    Unknown(String),
}

impl MaxShipSize {
    pub fn from_feed(raw: &str) -> Self {
        match raw.trim().to_ascii_lowercase().as_str() {
            "frigate" => Self::Frigate,
            "destroyer" => Self::Destroyer,
            "cruiser" => Self::Cruiser,
            "battlecruiser" => Self::Battlecruiser,
            "battleship" => Self::Battleship,
            "capital" => Self::Capital,
            _ => Self::Unknown(raw.trim().to_string()),
        }
    }
    pub fn label(&self) -> String {
        match self {
            Self::Frigate => "Frigate".to_string(),
            Self::Destroyer => "Destroyer".to_string(),
            Self::Cruiser => "Cruiser".to_string(),
            Self::Battlecruiser => "Battlecruiser".to_string(),
            Self::Battleship => "Battleship".to_string(),
            Self::Capital => "Capital".to_string(),
            Self::Unknown(raw) => raw.clone(),
        }
    }
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
    pub max_ship_size: Option<MaxShipSize>,
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
/// (hub-agnostic); each row is parsed from `serde_json::Value`
/// independently, so one malformed row drops only itself and
/// valid siblings survive.
pub fn parse_evescout_json(json: &str, fetched_at: i64) -> AppResult<EveScoutSnapshot> {
    tracing::debug!("[EXPLORE] parse_evescout_json bytes={}", json.len());
    let raw: Vec<serde_json::Value> = serde_json::from_str(json)?;
    let mut connections = Vec::new();
    for row in &raw {
        let Some(out_id) = row.get("out_system_id").and_then(|v| v.as_i64()) else {
            tracing::debug!("[EXPLORE] evescout row dropped: bad out_system_id");
            continue;
        };
        let Some(in_id) = row.get("in_system_id").and_then(|v| v.as_i64()) else {
            tracing::debug!("[EXPLORE] evescout row dropped: bad in_system_id");
            continue;
        };
        if out_id <= 0 || in_id <= 0 || out_id == in_id {
            continue;
        }
        let str_field = |key: &str| row.get(key).and_then(|v| v.as_str()).map(|s| s.to_string());
        connections.push(EveScoutConnection {
            record_key: record_key(row.get("id").unwrap_or(&serde_json::Value::Null)),
            hub_system_id: out_id,
            far_system_id: in_id,
            hub_signature: str_field("out_signature"),
            far_signature: str_field("in_signature"),
            wh_type: str_field("wh_type"),
            wh_exits_outward: row.get("wh_exits_outward").and_then(|v| v.as_bool()),
            expires_at: parse_expires(&row.get("expires_at").cloned()),
            max_ship_size: str_field("max_ship_size").map(|s| MaxShipSize::from_feed(&s)),
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
                                      // R9 directionality: `wh_exits_outward` names the side
                                      // displaying `wh_type`; the far side displays K162.
        let (hub_code, far_code): (Option<String>, Option<String>) = match conn.wh_exits_outward {
            Some(true) => (conn.wh_type.clone(), Some("K162".to_string())),
            Some(false) => (Some("K162".to_string()), conn.wh_type.clone()),
            None => (conn.wh_type.clone(), conn.wh_type.clone()),
        };
        for (from, to, code, paired) in [
            (
                conn.hub_system_id,
                conn.far_system_id,
                hub_code.clone(),
                far_code.clone(),
            ),
            (
                conn.far_system_id,
                conn.hub_system_id,
                far_code.clone(),
                hub_code.clone(),
            ),
        ] {
            let paired_forward = if code.as_deref() == Some("K162") {
                paired.filter(|p| p != "K162")
            } else {
                None
            };
            edges.push(RouterEdge {
                from_id: from,
                to_id: to,
                kind: EdgeKind::Wormhole,
                max_jump_mass_kg: mass,
                wormhole_code: code,
                paired_forward_code: paired_forward,
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
        assert_eq!(
            snap.connections[0].max_ship_size,
            Some(MaxShipSize::Battleship)
        );
        assert_ne!(
            snap.connections[1].wh_type.as_deref(),
            Some("K162"),
            "originating code is never K162"
        );
        // ISO expiry accepted too
        let iso = r#"[{"id":"007","out_system_id":31000005,"in_system_id":30000142,"expires_at":"2033-05-18T03:33:20Z"}]"#;
        let s2 = parse_evescout_json(iso, 0).unwrap();
        assert_eq!(s2.connections[0].record_key, "evescout:7");
        assert_eq!(s2.connections[0].expires_at, Some(2_000_000_000));
    }

    #[test]
    fn malformed_row_drops_only_itself_and_unknown_ship_size_kept() {
        let payload = r#"[
          {"id": 1, "out_system_id": 31000005, "in_system_id": 30000142,
           "wh_type": "B274", "wh_exits_outward": true, "max_ship_size": "Mothership"},
          {"id": 2, "out_system_id": 31000005, "in_system_id": null,
           "wh_type": "B274", "wh_exits_outward": true},
          {"id": 3, "out_system_id": 30002086, "in_system_id": 30002672,
           "wh_type": "N944", "wh_exits_outward": false}
        ]"#;
        let snap = parse_evescout_json(payload, 1_000).unwrap();
        assert_eq!(snap.connections.len(), 2, "null-id row dropped alone");
        assert_eq!(
            snap.connections[0].max_ship_size,
            Some(MaxShipSize::Unknown("Mothership".to_string()))
        );
    }

    #[test]
    fn wh_exits_outward_directionality_per_direction_codes() {
        let snap = parse_evescout_json(FIXTURE_JSON, 1_000).unwrap();
        let edges = snapshot_edges(&snap, 1_000, false);
        let hub_to_far = edges
            .iter()
            .find(|e| e.from_id == THERA_SYSTEM_ID && e.to_id == 30_000_142)
            .unwrap();
        let far_to_hub = edges
            .iter()
            .find(|e| e.from_id == 30_000_142 && e.to_id == THERA_SYSTEM_ID)
            .unwrap();
        // outward=true: hub shows B274, far shows K162.
        assert_eq!(hub_to_far.wormhole_code.as_deref(), Some("B274"));
        assert_eq!(far_to_hub.wormhole_code.as_deref(), Some("K162"));
        assert_eq!(far_to_hub.paired_forward_code.as_deref(), Some("B274"));
        // Row 2 outward=false: reverse assignment.
        let turnur_out = edges
            .iter()
            .find(|e| e.from_id == TURNUR_SYSTEM_ID)
            .unwrap();
        let turnur_in = edges.iter().find(|e| e.to_id == TURNUR_SYSTEM_ID).unwrap();
        assert_eq!(turnur_out.wormhole_code.as_deref(), Some("K162"));
        assert_eq!(turnur_in.wormhole_code.as_deref(), Some("N944"));
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
