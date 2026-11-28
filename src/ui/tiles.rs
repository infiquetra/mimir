//! Dockable `egui_tiles` workspaces (#652): four presets
//! over the eleven views, layout persistence, and the
//! extensible navigation registry.
//!
//! Each workspace owns one `egui_tiles::Tree<View>` whose
//! panes are whole views rendered by the shell's existing
//! per-view `show` functions (the shell's `Behavior`
//! impl lives in `src/app/shell.rs` beside the dispatch
//! it reuses). Adding a view in later waves means: add
//! the `View` variant, add it to exactly one preset (or a
//! new workspace), and navigation (rail list over
//! `View::ALL`, workspace switching, Quick-Sight) picks it
//! up without new keybindings — single keys stay bound to
//! the first eleven views only.
//!
//! Persistence: layouts serialize to one JSON document
//! stored through `app_settings` by the shell in live
//! mode only. [`restore_layouts`] returns `None` on ANY
//! parse or shape error so corrupted or older state
//! falls back cleanly to the default presets. Demo mode
//! never reads or writes layouts ([`should_persist_layout`]).
//! Logs nothing itself; the shell logs restores at debug.

use egui_tiles::{Tile, Tiles, Tree};
use serde::{Deserialize, Serialize};

use crate::app::state::View;

/// The four dockable workspaces. Order matches the
/// `Cmd+1..4` workspace shortcuts and the rail list.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, Serialize, Deserialize)]
pub enum Workspace {
    #[default]
    CommandDeck,
    FittingHangar,
    IndustryTrade,
    ExplorationOps,
}

impl Workspace {
    pub const ALL: [Workspace; 4] = [
        Workspace::CommandDeck,
        Workspace::FittingHangar,
        Workspace::IndustryTrade,
        Workspace::ExplorationOps,
    ];

    pub fn label(&self) -> &'static str {
        match self {
            Workspace::CommandDeck => "Command Deck",
            Workspace::FittingHangar => "Fitting & Hangar",
            Workspace::IndustryTrade => "Industry & Trade",
            Workspace::ExplorationOps => "Exploration & Ops",
        }
    }

    /// Stable persistence/tree id stem.
    pub fn id_stem(&self) -> &'static str {
        match self {
            Workspace::CommandDeck => "command_deck",
            Workspace::FittingHangar => "fitting_hangar",
            Workspace::IndustryTrade => "industry_trade",
            Workspace::ExplorationOps => "exploration_ops",
        }
    }

    pub fn index(&self) -> usize {
        Workspace::ALL.iter().position(|w| w == self).unwrap_or(0)
    }

    pub fn from_index(index: usize) -> Option<Workspace> {
        Workspace::ALL.get(index).copied()
    }

    /// The workspace whose preset contains `view`. Every
    /// current view belongs to exactly one preset; a
    /// future view added to no preset falls back to the
    /// Command Deck and is added there by the shell.
    pub fn for_view(view: View) -> Workspace {
        match view {
            View::Dashboard | View::Characters | View::Wallet => Workspace::CommandDeck,
            View::Fittings | View::Assets => Workspace::FittingHangar,
            View::Industry | View::Planets | View::Market => Workspace::IndustryTrade,
            View::Exploration | View::Skills | View::Settings => Workspace::ExplorationOps,
        }
    }

    /// Views in this workspace's default preset, in
    /// layout order. Across all workspaces this covers
    /// `View::ALL` exactly once (test-pinned).
    pub fn preset_views(&self) -> &'static [View] {
        match self {
            Workspace::CommandDeck => &[View::Dashboard, View::Characters, View::Wallet],
            Workspace::FittingHangar => &[View::Fittings, View::Assets],
            Workspace::IndustryTrade => &[View::Industry, View::Planets, View::Market],
            Workspace::ExplorationOps => &[View::Exploration, View::Skills, View::Settings],
        }
    }
}

/// Default pane tree for one workspace: a horizontal
/// split whose first cell tabs the first two preset views
/// (so docking/tabs are visible out of the box) and whose
/// remaining cells stand alone. Two-view workspaces are a
/// plain horizontal pair.
pub fn default_tree(workspace: Workspace) -> Tree<View> {
    let views = workspace.preset_views();
    let mut tiles = Tiles::default();
    let panes: Vec<_> = views.iter().map(|v| tiles.insert_pane(*v)).collect();
    let root = if panes.len() > 2 {
        let tabs = tiles.insert_tab_tile(vec![panes[0], panes[1]]);
        let mut children = vec![tabs];
        children.extend_from_slice(&panes[2..]);
        tiles.insert_horizontal_tile(children)
    } else {
        tiles.insert_horizontal_tile(panes)
    };
    Tree::new(egui::Id::unique(workspace.id_stem()), root, tiles)
}

/// All pane views currently in a tree (any order).
pub fn tree_views(tree: &Tree<View>) -> Vec<View> {
    tree.tiles
        .tiles()
        .filter_map(|tile| match tile {
            Tile::Pane(view) => Some(*view),
            Tile::Container(_) => None,
        })
        .collect()
}

/// Whether `tree` currently contains a pane for `view`.
pub fn tree_contains(tree: &Tree<View>, view: View) -> bool {
    tree_views(tree).contains(&view)
}

/// Serialized layouts for all four workspaces plus the
/// active one. Versioned so older shapes fail closed
/// into the default-preset fallback.
#[derive(Debug, Clone, Serialize, Deserialize)]
struct PersistedLayouts {
    version: u32,
    active: Workspace,
    trees: Vec<Option<Tree<View>>>,
}

const LAYOUT_VERSION: u32 = 1;

/// Serialize layouts for `app_settings` storage. `None`
/// only on a serde failure (treated as "do not persist").
pub fn serialize_layouts(trees: &[Option<Tree<View>>], active: Workspace) -> Option<String> {
    if trees.len() != Workspace::ALL.len() {
        return None;
    }
    serde_json::to_string(&PersistedLayouts {
        version: LAYOUT_VERSION,
        active,
        trees: trees.to_vec(),
    })
    .ok()
}

/// Restore layouts from persisted JSON. ANY error —
/// corrupt JSON, wrong version, wrong arity, unknown
/// view variant — returns `None` and the caller falls
/// back to [`default_tree`] presets.
pub fn restore_layouts(json: &str) -> Option<([Option<Tree<View>>; 4], Workspace)> {
    let persisted: PersistedLayouts = serde_json::from_str(json).ok()?;
    if persisted.version != LAYOUT_VERSION || persisted.trees.len() != Workspace::ALL.len() {
        return None;
    }
    let mut trees: [Option<Tree<View>>; 4] = [None, None, None, None];
    for (slot, tree) in trees.iter_mut().zip(persisted.trees) {
        *slot = tree;
    }
    Some((trees, persisted.active))
}

/// Layout persistence is live-only: demo mode writes (and
/// reads) zero disk state (AGENTS.md invariant 5).
pub fn should_persist_layout(demo: bool) -> bool {
    !demo
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn presets_cover_every_view_exactly_once() {
        let mut covered: Vec<View> = Vec::new();
        for workspace in Workspace::ALL {
            let tree = default_tree(workspace);
            let mut views = tree_views(&tree);
            assert_eq!(
                views.len(),
                workspace.preset_views().len(),
                "{} preset pane count",
                workspace.label()
            );
            for view in workspace.preset_views() {
                assert!(
                    views.contains(view),
                    "{} missing {view:?}",
                    workspace.label()
                );
                assert_eq!(Workspace::for_view(*view), workspace);
            }
            covered.append(&mut views);
        }
        assert_eq!(covered.len(), View::ALL.len(), "every view covered once");
        for view in View::ALL {
            assert_eq!(
                covered.iter().filter(|v| **v == view).count(),
                1,
                "{view:?} covered exactly once"
            );
        }
    }

    #[test]
    fn corrupted_or_foreign_json_falls_back() {
        for bad in [
            "",
            "not json",
            "{}",
            r#"{"version":99,"active":"CommandDeck","trees":[null,null,null,null]}"#,
            r#"{"version":1,"active":"CommandDeck","trees":[null]}"#,
            r#"{"version":1,"active":"Nope","trees":[null,null,null,null]}"#,
        ] {
            assert!(restore_layouts(bad).is_none(), "must reject: {bad}");
        }
        // The documented fallback itself always exists.
        for workspace in Workspace::ALL {
            assert!(!tree_views(&default_tree(workspace)).is_empty());
        }
    }

    #[test]
    fn layout_roundtrip_preserves_panes_and_active() {
        let trees: [Option<Tree<View>>; 4] = [
            Some(default_tree(Workspace::CommandDeck)),
            None,
            Some(default_tree(Workspace::IndustryTrade)),
            None,
        ];
        let json = serialize_layouts(&trees, Workspace::IndustryTrade).expect("serialize");
        let (restored, active) = restore_layouts(&json).expect("restore");
        assert_eq!(active, Workspace::IndustryTrade);
        assert!(restored[1].is_none() && restored[3].is_none());
        let deck = restored[0].as_ref().expect("deck restored");
        for view in Workspace::CommandDeck.preset_views() {
            assert!(tree_contains(deck, *view));
        }
    }

    #[test]
    fn demo_never_persists_layout() {
        assert!(!should_persist_layout(true));
        assert!(should_persist_layout(false));
    }
}
