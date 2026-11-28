//! Tuple-cost Dijkstra router (#646).
//! Cost is lexicographic `(security_penalty, jump_count,
//! wormhole_uncertainty_penalty, path_system_ids)`; per-mode
//! edge penalties below. Spec R24 uses (jumps, riskSum, seq);
//! brief tuple reorders security first — Safest/LessSecure
//! differ only by security mapping, Shortest zeroes it.

use std::cmp::Reverse;
use std::collections::{BinaryHeap, HashMap};

use petgraph::graph::{DiGraph, NodeIndex};

/// Ship classes for mass filtering (representative hull mass kg).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ShipClass {
    Frigate,
    Battleship,
    Capital,
}

impl ShipClass {
    pub fn mass_kg(&self) -> i64 {
        match self {
            Self::Frigate => 1_600_000,
            Self::Battleship => 103_000_000,
            Self::Capital => 1_250_000_000,
        }
    }
    pub fn label(&self) -> &'static str {
        match self {
            Self::Frigate => "Frigate",
            Self::Battleship => "Battleship",
            Self::Capital => "Capital",
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum RouteMode {
    Shortest,
    Safest,
    LessSecure,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum EdgeKind {
    Stargate,
    Wormhole,
}

#[derive(Debug, Clone, PartialEq)]
pub struct SystemNode {
    pub system_id: i64,
    pub name: String,
    /// Raw security status; `None` = unknown.
    pub security: Option<f64>,
    /// Wormhole class 1..=6, 12 Thera, 25 Pochven; None = k-space.
    pub wormhole_class: Option<i64>,
}

impl SystemNode {
    pub fn is_wormhole(&self) -> bool {
        self.wormhole_class.is_some()
    }
    pub fn is_highsec(&self) -> bool {
        !self.is_wormhole() && self.security.is_some_and(|s| s >= 0.45)
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct RouterEdge {
    pub from_id: i64,
    pub to_id: i64,
    pub kind: EdgeKind,
    /// Per-jump mass limit kg; None = Unknown (never guessed).
    pub max_jump_mass_kg: Option<i64>,
    pub wormhole_code: Option<String>,
    /// Forward code paired with a K162; None = unpaired.
    pub paired_forward_code: Option<String>,
    /// Unix seconds; edge pruned when `now >= expires_at`.
    pub expires_at: Option<i64>,
    pub verified: bool,
}

impl RouterEdge {
    pub fn stargate(from_id: i64, to_id: i64) -> Self {
        Self {
            from_id,
            to_id,
            kind: EdgeKind::Stargate,
            max_jump_mass_kg: None,
            wormhole_code: None,
            paired_forward_code: None,
            expires_at: None,
            verified: true,
        }
    }
    pub fn wormhole(
        from_id: i64,
        to_id: i64,
        code: &str,
        max_jump_mass_kg: Option<i64>,
        expires_at: Option<i64>,
    ) -> Self {
        Self {
            from_id,
            to_id,
            kind: EdgeKind::Wormhole,
            max_jump_mass_kg,
            wormhole_code: Some(code.to_string()),
            paired_forward_code: None,
            expires_at,
            verified: true,
        }
    }
    /// K162 with no paired forward code: mass stays Unknown.
    pub fn k162_unpaired(from_id: i64, to_id: i64, expires_at: Option<i64>) -> Self {
        let mut e = Self::wormhole(from_id, to_id, "K162", None, expires_at);
        e.paired_forward_code = None;
        e
    }
    /// Effective mass limit. Unpaired K162 is always Unknown,
    /// even if a caller stored a value — never guessed.
    pub fn effective_max_jump_mass_kg(&self) -> Option<i64> {
        if self.kind == EdgeKind::Stargate {
            return None; // gates have no mass limit; None = unlimited here
        }
        if self.wormhole_code.as_deref() == Some("K162") && self.paired_forward_code.is_none() {
            return None;
        }
        self.max_jump_mass_kg
    }
    pub fn is_expired(&self, now: i64) -> bool {
        self.expires_at.is_some_and(|exp| now >= exp)
    }
}

/// Security penalty for *entering* `dest` under `mode`.
/// Shortest: 0 everywhere (pure jumps). Safest: highsec-first.
/// LessSecure: prefers low/null (inverse of Safest).
pub fn security_penalty(mode: RouteMode, dest: &SystemNode) -> u32 {
    match mode {
        RouteMode::Shortest => 0,
        RouteMode::Safest => {
            if dest.is_wormhole() {
                12
            } else if dest.is_highsec() {
                0
            } else {
                match dest.security {
                    Some(s) if s > 0.0 => 10, // lowsec
                    Some(_) => 20,            // nullsec
                    None => 15,               // unknown
                }
            }
        }
        RouteMode::LessSecure => {
            if dest.is_wormhole() {
                5
            } else if dest.is_highsec() {
                20
            } else {
                match dest.security {
                    Some(s) if s > 0.0 => 0, // lowsec preferred
                    Some(_) => 0,            // nullsec preferred
                    None => 5,
                }
            }
        }
    }
}

pub fn wormhole_uncertainty(edge: &RouterEdge) -> u32 {
    match edge.kind {
        EdgeKind::Wormhole => 1,
        EdgeKind::Stargate => 0,
    }
}

/// Whether `edge` may be traversed. Expired and unverified
/// edges are always pruned; mass checks apply to wormholes.
pub fn edge_traversable(edge: &RouterEdge, ship: Option<ShipClass>, now: i64) -> bool {
    if !edge.verified || edge.is_expired(now) {
        return false;
    }
    if edge.kind == EdgeKind::Wormhole {
        if let Some(ship) = ship {
            match edge.effective_max_jump_mass_kg() {
                // Unknown mass never guessed traversable for
                // mass-limited (ship-specified) queries.
                None => return false,
                Some(limit) => {
                    if ship.mass_kg() > limit {
                        return false;
                    }
                }
            }
        }
    }
    true
}

/// Lexicographic route cost; `path` is the deterministic
/// system-id tiebreak (full entered-system sequence).
#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord)]
pub struct RouteCost {
    pub security_penalty: u32,
    pub jumps: u32,
    pub wormhole_uncertainty: u32,
    pub path: Vec<i64>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Route {
    pub system_ids: Vec<i64>,
    pub cost: RouteCost,
}

impl Route {
    pub fn jumps(&self) -> u32 {
        self.cost.jumps
    }
}

/// Dijkstra over a petgraph DiGraph. Returns None if no
/// eligible route; origin == destination is a zero-jump route.
pub fn find_route(
    nodes: &[SystemNode],
    edges: &[RouterEdge],
    origin: i64,
    destination: i64,
    mode: RouteMode,
    ship: Option<ShipClass>,
    now: i64,
) -> Option<Route> {
    tracing::debug!(
        "[EXPLORE] find_route mode={mode:?} ship={ship:?} nodes={} edges={}",
        nodes.len(),
        edges.len()
    );
    if origin == destination && nodes.iter().any(|n| n.system_id == origin) {
        return Some(Route {
            system_ids: vec![origin],
            cost: RouteCost {
                security_penalty: 0,
                jumps: 0,
                wormhole_uncertainty: 0,
                path: vec![origin],
            },
        });
    }
    let mut graph: DiGraph<i64, ()> = DiGraph::new();
    let mut index: HashMap<i64, NodeIndex> = HashMap::new();
    let mut by_id: HashMap<i64, &SystemNode> = HashMap::new();
    for node in nodes {
        by_id.insert(node.system_id, node);
        index.insert(node.system_id, graph.add_node(node.system_id));
    }
    let (Some(&origin_ix), Some(&dest_ix)) = (index.get(&origin), index.get(&destination)) else {
        return None;
    };
    // Adjacency kept outside graph weights: parallel edges matter.
    let mut adjacency: HashMap<NodeIndex, Vec<RouterEdge>> = HashMap::new();
    for edge in edges {
        if !edge_traversable(edge, ship, now) {
            continue;
        }
        let (Some(&from), Some(&to)) = (index.get(&edge.from_id), index.get(&edge.to_id)) else {
            continue;
        };
        graph.add_edge(from, to, ());
        adjacency.entry(from).or_default().push(edge.clone());
    }
    for list in adjacency.values_mut() {
        list.sort_by_key(|e| e.to_id);
    }

    let start = RouteCost {
        security_penalty: 0,
        jumps: 0,
        wormhole_uncertainty: 0,
        path: vec![origin],
    };
    let mut best: HashMap<NodeIndex, RouteCost> = HashMap::new();
    best.insert(origin_ix, start.clone());
    let mut heap: BinaryHeap<Reverse<(RouteCost, NodeIndex)>> = BinaryHeap::new();
    heap.push(Reverse((start, origin_ix)));
    while let Some(Reverse((cost, ix))) = heap.pop() {
        if best.get(&ix).is_some_and(|b| *b != cost) {
            continue; // stale queue entry
        }
        if ix == dest_ix {
            return Some(Route {
                system_ids: cost.path.clone(),
                cost,
            });
        }
        let Some(outgoing) = adjacency.get(&ix) else {
            continue;
        };
        for edge in outgoing {
            let Some(dest_node) = by_id.get(&edge.to_id) else {
                continue;
            };
            let mut path = cost.path.clone();
            path.push(edge.to_id);
            let next = RouteCost {
                security_penalty: cost.security_penalty + security_penalty(mode, dest_node),
                jumps: cost.jumps + 1,
                wormhole_uncertainty: cost.wormhole_uncertainty + wormhole_uncertainty(edge),
                path,
            };
            let to_ix = index[&edge.to_id];
            let better = match best.get(&to_ix) {
                None => true,
                Some(current) => next < *current,
            };
            if better {
                best.insert(to_ix, next.clone());
                heap.push(Reverse((next, to_ix)));
            }
        }
    }
    None
}

/// Build stargate edges from `sde_stargates` (#654 tables).
/// Empty when SDE sync has not populated the tables — caller
/// falls back to wormhole-only routing; never fabricated.
pub fn stargate_edges_from_db(conn: &rusqlite::Connection) -> Vec<RouterEdge> {
    let Ok(mut stmt) = conn.prepare(
        "SELECT system_id, destination_system_id FROM sde_stargates \
         WHERE system_id IS NOT NULL AND destination_system_id IS NOT NULL",
    ) else {
        tracing::debug!("[EXPLORE] sde_stargates unavailable; gate graph empty");
        return Vec::new();
    };
    let rows = stmt.query_map([], |row| Ok((row.get::<_, i64>(0)?, row.get::<_, i64>(1)?)));
    let mut edges = Vec::new();
    if let Ok(rows) = rows {
        for row in rows.flatten() {
            if row.0 != row.1 {
                edges.push(RouterEdge::stargate(row.0, row.1));
            }
        }
    }
    tracing::debug!("[EXPLORE] stargate edges loaded count={}", edges.len());
    edges
}

#[cfg(test)]
mod tests {
    use super::*;

    fn node(id: i64, security: Option<f64>) -> SystemNode {
        SystemNode {
            system_id: id,
            name: format!("Sys{id}"),
            security,
            wormhole_class: None,
        }
    }
    fn wh_node(id: i64) -> SystemNode {
        SystemNode {
            system_id: id,
            name: format!("J{id}"),
            security: None,
            wormhole_class: Some(3),
        }
    }
    // Diamond: 1 -high(2)-> 4 direct low(3): 1->3->4 (2 jumps via low),
    // 1->2->4 (2 jumps via high). Plus 1->4 direct (1 jump, null dest is 4? dest sec fixed)
    #[test]
    fn tuple_ordering_safest_prefers_highsec_shortest_prefers_fewer_jumps() {
        // 1 origin(null origin irrelevant), 2 high, 3 low, 4 high dest
        let nodes = vec![
            node(1, Some(0.9)),
            node(2, Some(0.9)),
            node(3, Some(0.2)),
            node(4, Some(0.9)),
        ];
        let edges = vec![
            RouterEdge::stargate(1, 3),
            RouterEdge::stargate(3, 4),
            RouterEdge::stargate(1, 2),
            RouterEdge::stargate(2, 4),
            RouterEdge::stargate(1, 4),
        ];
        let shortest = find_route(&nodes, &edges, 1, 4, RouteMode::Shortest, None, 100).unwrap();
        assert_eq!(shortest.system_ids, vec![1, 4], "shortest is direct");
        // Without direct edge, Safest picks highsec path, Shortest ties -> deterministic id path [1,2,4] < [1,3,4]
        let edges2 = &edges[..4];
        let safest = find_route(&nodes, edges2, 1, 4, RouteMode::Safest, None, 100).unwrap();
        assert_eq!(safest.system_ids, vec![1, 2, 4]);
        assert_eq!(safest.cost.security_penalty, 0);
        let short2 = find_route(&nodes, edges2, 1, 4, RouteMode::Shortest, None, 100).unwrap();
        assert_eq!(short2.system_ids, vec![1, 2, 4], "tiebreak smallest ids");
        let less = find_route(&nodes, edges2, 1, 4, RouteMode::LessSecure, None, 100).unwrap();
        assert_eq!(less.system_ids, vec![1, 3, 4], "less-secure prefers lowsec");
    }

    #[test]
    fn mass_filter_frigate_vs_battleship_vs_capital() {
        let nodes = vec![node(1, Some(0.9)), wh_node(2), node(3, Some(0.9))];
        // B274-like 375M limit: frigate+battleship pass, capital fails
        let edges = vec![
            RouterEdge::wormhole(1, 2, "B274", Some(375_000_000), None),
            RouterEdge::wormhole(2, 1, "K162", Some(375_000_000), None),
            RouterEdge::wormhole(2, 3, "B274", Some(375_000_000), None),
            RouterEdge::wormhole(3, 2, "K162", Some(375_000_000), None),
        ];
        // Note 2->1 K162 paired code present as wormhole() sets code K162 but paired None => blocked for ship queries.
        // Use forward edges only direction 1->2->3 for assertion.
        assert!(find_route(
            &nodes,
            &edges,
            1,
            3,
            RouteMode::Shortest,
            Some(ShipClass::Frigate),
            0
        )
        .is_some());
        assert!(find_route(
            &nodes,
            &edges,
            1,
            3,
            RouteMode::Shortest,
            Some(ShipClass::Battleship),
            0
        )
        .is_some());
        assert!(find_route(
            &nodes,
            &edges,
            1,
            3,
            RouteMode::Shortest,
            Some(ShipClass::Capital),
            0
        )
        .is_none());
        // Small hole 20M: only frigate
        let small = vec![RouterEdge::wormhole(1, 3, "R943", Some(20_000_000), None)];
        let nodes2 = vec![node(1, Some(0.9)), node(3, Some(0.9))];
        assert!(find_route(
            &nodes2,
            &small,
            1,
            3,
            RouteMode::Shortest,
            Some(ShipClass::Frigate),
            0
        )
        .is_some());
        assert!(find_route(
            &nodes2,
            &small,
            1,
            3,
            RouteMode::Shortest,
            Some(ShipClass::Battleship),
            0
        )
        .is_none());
    }

    #[test]
    fn k162_unknown_never_traversable_for_mass_limited_query() {
        let nodes = vec![node(1, Some(0.9)), node(2, Some(0.9))];
        let edges = vec![RouterEdge::k162_unpaired(1, 2, None)];
        assert_eq!(edges[0].effective_max_jump_mass_kg(), None);
        assert!(find_route(
            &nodes,
            &edges,
            1,
            2,
            RouteMode::Shortest,
            Some(ShipClass::Frigate),
            0
        )
        .is_none());
        // No ship filter: unknown mass allowed (uncertainty penalised, not blocked)
        assert!(find_route(&nodes, &edges, 1, 2, RouteMode::Shortest, None, 0).is_some());
        // Paired K162 resolves mass
        let mut paired = RouterEdge::k162_unpaired(1, 2, None);
        paired.paired_forward_code = Some("B274".to_string());
        paired.max_jump_mass_kg = Some(375_000_000);
        assert_eq!(paired.effective_max_jump_mass_kg(), Some(375_000_000));
        assert!(find_route(
            &nodes,
            &[paired],
            1,
            2,
            RouteMode::Shortest,
            Some(ShipClass::Frigate),
            0
        )
        .is_some());
    }

    #[test]
    fn expired_edges_pruned_at_boundary() {
        let nodes = vec![node(1, Some(0.9)), node(2, Some(0.9))];
        let edges = vec![RouterEdge::wormhole(
            1,
            2,
            "B274",
            Some(375_000_000),
            Some(1_000),
        )];
        assert!(find_route(&nodes, &edges, 1, 2, RouteMode::Shortest, None, 999).is_some());
        assert!(
            find_route(&nodes, &edges, 1, 2, RouteMode::Shortest, None, 1_000).is_none(),
            "now>=expires_at prunes"
        );
        assert!(find_route(&nodes, &edges, 1, 2, RouteMode::Shortest, None, 1_001).is_none());
    }

    #[test]
    fn deterministic_tiebreak_and_zero_route() {
        let nodes = vec![
            node(1, Some(0.5)),
            node(2, Some(0.5)),
            node(3, Some(0.5)),
            node(4, Some(0.5)),
        ];
        // Two equal 2-jump paths: [1,3,4] inserted first, [1,2,4] must win
        let edges = vec![
            RouterEdge::stargate(1, 3),
            RouterEdge::stargate(3, 4),
            RouterEdge::stargate(1, 2),
            RouterEdge::stargate(2, 4),
        ];
        let r = find_route(&nodes, &edges, 1, 4, RouteMode::Shortest, None, 0).unwrap();
        assert_eq!(r.system_ids, vec![1, 2, 4]);
        let zero = find_route(&nodes, &edges, 1, 1, RouteMode::Safest, None, 0).unwrap();
        assert_eq!(zero.jumps(), 0);
        assert!(find_route(&nodes, &edges, 4, 1, RouteMode::Shortest, None, 0).is_none());
    }

    #[test]
    fn unverified_edges_never_route() {
        let nodes = vec![node(1, Some(0.9)), node(2, Some(0.9))];
        let mut e = RouterEdge::wormhole(1, 2, "B274", Some(375_000_000), None);
        e.verified = false;
        assert!(find_route(&nodes, &[e], 1, 2, RouteMode::Shortest, None, 0).is_none());
    }

    #[test]
    fn stargate_edges_from_empty_db_is_empty_not_fabricated() {
        let conn = rusqlite::Connection::open_in_memory().unwrap();
        conn.execute_batch(crate::storage::db::SCHEMA_SQL).unwrap();
        assert!(stargate_edges_from_db(&conn).is_empty());
        conn.execute("INSERT INTO sde_stargates (stargate_id,name,system_id,destination_stargate_id,destination_system_id) VALUES (1,'g',100,2,200)", []).unwrap();
        let edges = stargate_edges_from_db(&conn);
        assert_eq!(edges.len(), 1);
        assert_eq!((edges[0].from_id, edges[0].to_id), (100, 200));
    }
}
