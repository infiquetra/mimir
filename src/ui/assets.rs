//! Assets: the active character's item list grouped by location, with
//! text search and singleton custom names. Every rendered string is a
//! resolved EVE name (or the resolver's Unknown fallback), never a raw ID.

use std::collections::{BTreeMap, HashMap};

use super::widgets;
use crate::app::state::{AppState, AssetsData, LoadState};
use crate::esi::models::AssetItem;
use crate::names::resolver::NameResolver;

/// One display row: names already resolved, never a raw numeric ID.
#[derive(Debug, Clone, Default, PartialEq)]
pub struct AssetRow {
    pub item_id: i64,
    pub display_name: String,
    pub type_name: String,
    pub quantity: i64,
    pub location_flag: String,
    pub is_singleton: bool,
    pub is_blueprint_copy: bool,
    pub has_custom_name: bool,
}

/// All assets at one location, with counts for the group header.
#[derive(Debug, Clone, Default, PartialEq)]
pub struct AssetLocationGroup {
    pub location_id: i64,
    pub location_name: String,
    pub rows: Vec<AssetRow>,
    pub item_count: i64,
    pub type_count: usize,
}

/// `(display, type_name)` for one asset. A custom singleton name wins over
/// the type name; a blueprint copy gains a `" (copy)"` suffix.
pub fn display_name(
    item: &AssetItem,
    custom_names: &HashMap<i64, String>,
    resolver: &NameResolver,
) -> (String, String) {
    let type_name = resolver.name(item.type_id);
    let mut display = match custom_names.get(&item.item_id) {
        Some(name) if !name.is_empty() => name.clone(),
        _ => type_name.clone(),
    };
    if item.is_blueprint_copy == Some(true) {
        display.push_str(" (copy)");
    }
    (display, type_name)
}

/// Group assets by location. Groups sort by total quantity descending,
/// then location name, then location ID; rows sort by display name.
pub fn group_assets(data: &AssetsData, resolver: &NameResolver) -> Vec<AssetLocationGroup> {
    let mut by_location: BTreeMap<i64, Vec<AssetRow>> = BTreeMap::new();
    for item in &data.items {
        let has_custom_name = data
            .custom_names
            .get(&item.item_id)
            .is_some_and(|n| !n.is_empty());
        let (display, type_name) = display_name(item, &data.custom_names, resolver);
        by_location
            .entry(item.location_id)
            .or_default()
            .push(AssetRow {
                item_id: item.item_id,
                display_name: display,
                type_name,
                quantity: item.quantity,
                location_flag: item.location_flag.clone(),
                is_singleton: item.is_singleton,
                is_blueprint_copy: item.is_blueprint_copy == Some(true),
                has_custom_name,
            });
    }
    let mut groups: Vec<AssetLocationGroup> = by_location
        .into_iter()
        .map(|(location_id, mut rows)| {
            rows.sort_by(|a, b| {
                a.display_name
                    .cmp(&b.display_name)
                    .then(a.item_id.cmp(&b.item_id))
            });
            let item_count = rows.iter().map(|r| r.quantity).sum();
            let type_count = rows.len();
            AssetLocationGroup {
                location_id,
                location_name: resolver.location_name(location_id),
                rows,
                item_count,
                type_count,
            }
        })
        .collect();
    groups.sort_by(|a, b| {
        b.item_count
            .cmp(&a.item_count)
            .then_with(|| a.location_name.cmp(&b.location_name))
            .then(a.location_id.cmp(&b.location_id))
    });
    tracing::debug!(
        "[ASSETS] grouped items={} locations={}",
        data.items.len(),
        groups.len()
    );
    groups
}

/// Search filter: a matching location name keeps all its rows, otherwise
/// only rows whose display or type name matches. Counts are recomputed
/// from the kept rows so group headers never describe hidden rows.
pub fn filter_groups(groups: &[AssetLocationGroup], query: &str) -> Vec<AssetLocationGroup> {
    if query.is_empty() {
        return groups.to_vec();
    }
    let mut out = Vec::new();
    for group in groups {
        let rows: Vec<AssetRow> = if widgets::matches_search(&group.location_name, query) {
            group.rows.clone()
        } else {
            group
                .rows
                .iter()
                .filter(|r| {
                    widgets::matches_search(&r.display_name, query)
                        || widgets::matches_search(&r.type_name, query)
                })
                .cloned()
                .collect()
        };
        if rows.is_empty() {
            continue;
        }
        let item_count = rows.iter().map(|r| r.quantity).sum();
        let type_count = rows.len();
        out.push(AssetLocationGroup {
            location_id: group.location_id,
            location_name: group.location_name.clone(),
            rows,
            item_count,
            type_count,
        });
    }
    out
}

/// Honest step-up guidance: names the missing scope, offers no button
/// that pretends to grant it (that flow is a follow-up, design D4).
fn reauthorize_panel(ui: &mut egui::Ui) {
    ui.heading("Assets need one more EVE permission.");
    ui.label(
        "This character has not granted esi-assets.read_assets.v1, the EVE SSO \
         scope that lets Mimir read the character asset list. No asset data was \
         loaded, and your other views are unaffected.",
    );
    ui.label(
        "Granting extra scopes after first sign-in (step-up sign-in) is not in \
         this build yet, so this view stays empty for this character until that \
         follow-up lands. Demo mode (Settings) shows the full Assets view with \
         sample data.",
    );
}

pub fn show(ui: &mut egui::Ui, state: &mut AppState, resolver: &NameResolver) {
    ui.heading("Assets");
    widgets::mode_notice(ui, state.demo, state.offline);
    if state.active_character().is_none() {
        widgets::no_character_panel(ui);
        return;
    }
    if state.assets_needs_reauthorize {
        tracing::debug!("[ASSETS] showing re-authorize guidance (missing scope)");
        reauthorize_panel(ui);
        return;
    }
    // Clone the snapshot so the search box can borrow `state` mutably.
    let snapshot = state.assets.clone();
    match snapshot {
        LoadState::Ready(data) => {
            if data.items.is_empty() {
                widgets::empty_panel(
                    ui,
                    "No assets yet. Press Ctrl+R (or Refresh) after signing in.",
                );
                return;
            }
            let focus = widgets::search_box(
                ui,
                &mut state.assets_search,
                "Filter assets by item or location (press / to focus)",
                state.focus_search,
            );
            state.text_input_focused |= focus;
            if focus {
                state.focus_search = false;
            }
            let groups = filter_groups(&group_assets(&data, resolver), &state.assets_search);
            if groups.is_empty() {
                widgets::empty_panel(ui, "No assets match the search.");
                return;
            }
            for group in &groups {
                ui.heading(format!(
                    "{} — {} item types, {} total items",
                    group.location_name, group.type_count, group.item_count
                ));
                for row in &group.rows {
                    if row.has_custom_name {
                        ui.label(format!(
                            "{} x{} ({})",
                            row.display_name, row.quantity, row.type_name
                        ));
                    } else {
                        ui.label(format!("{} x{}", row.display_name, row.quantity));
                    }
                }
            }
        }
        LoadState::Loading => widgets::loading_panel(ui, "Loading assets..."),
        LoadState::Empty => widgets::empty_panel(ui, "No assets data yet."),
        LoadState::Error(e) => {
            if widgets::error_panel_with_retry(ui, &e) {
                tracing::warn!("[ASSETS] retry requested after load error");
                state.retry_requested = true;
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn item(
        item_id: i64,
        type_id: i64,
        quantity: i64,
        location_id: i64,
        singleton: bool,
        copy: Option<bool>,
    ) -> AssetItem {
        AssetItem {
            item_id,
            type_id,
            quantity,
            location_id,
            location_flag: "Hangar".to_string(),
            is_singleton: singleton,
            is_blueprint_copy: copy,
            ..Default::default()
        }
    }

    fn resolver() -> NameResolver {
        let mut r = NameResolver::new();
        r.insert(34, "Tritanium".to_string());
        r.insert(587, "Rifter".to_string());
        r.insert(681, "Bantam Blueprint".to_string());
        r.insert(60003760, "Jita Station".to_string());
        r.insert(60011866, "Amarr Station".to_string());
        r
    }

    fn data() -> AssetsData {
        AssetsData {
            items: vec![
                item(1, 34, 150_000, 60003760, false, None),
                item(2, 587, 1, 60003760, true, Some(false)),
                item(3, 681, 1, 60011866, true, Some(true)),
                item(4, 34, 42, 60011866, false, None),
            ],
            custom_names: HashMap::from([(2, "Aria's Rifter".to_string())]),
        }
    }

    #[test]
    fn grouping_sorts_counts_and_never_shows_raw_ids() {
        let groups = group_assets(&data(), &resolver());
        assert_eq!(groups.len(), 2);
        // Largest total quantity first: Jita 150001, then Amarr 43.
        assert_eq!(groups[0].location_name, "Jita Station");
        assert_eq!(groups[0].item_count, 150_001);
        assert_eq!(groups[0].type_count, 2);
        assert_eq!(groups[1].location_name, "Amarr Station");
        assert_eq!(groups[1].item_count, 43);
        // Rows sort by display name; custom name beats type name.
        assert_eq!(groups[0].rows[0].display_name, "Aria's Rifter");
        assert_eq!(groups[0].rows[0].type_name, "Rifter");
        assert!(groups[0].rows[0].has_custom_name);
        assert_eq!(groups[0].rows[1].display_name, "Tritanium");
        assert!(!groups[0].rows[1].has_custom_name);
        // Blueprint copy suffix only on the copy.
        let copy = groups[1]
            .rows
            .iter()
            .find(|r| r.item_id == 3)
            .expect("copy row");
        assert_eq!(copy.display_name, "Bantam Blueprint (copy)");
        assert!(copy.is_blueprint_copy);
        assert!(groups
            .iter()
            .flat_map(|g| &g.rows)
            .filter(|r| r.item_id != 3)
            .all(|r| !r.display_name.ends_with(" (copy)")));
        // No rendered name is a raw numeric ID.
        for group in &groups {
            assert!(group.location_name.parse::<i64>().is_err());
            for row in &group.rows {
                assert!(row.display_name.parse::<i64>().is_err());
                assert!(row.type_name.parse::<i64>().is_err());
            }
        }
        // Empty resolver: word fallbacks, still never numbers.
        let unknown = group_assets(&data(), &NameResolver::new());
        assert!(unknown
            .iter()
            .all(|g| g.location_name == "Unknown Location"));
        assert!(unknown
            .iter()
            .flat_map(|g| &g.rows)
            .filter(|r| !r.has_custom_name)
            .all(|r| r.type_name == "Unknown Item"));
    }

    #[test]
    fn filter_recomputes_counts() {
        let groups = group_assets(&data(), &resolver());
        // Empty query is the identity.
        assert_eq!(filter_groups(&groups, ""), groups);
        // Location match keeps all rows with original counts.
        let by_location = filter_groups(&groups, "jita");
        assert_eq!(by_location.len(), 1);
        assert_eq!(by_location[0].type_count, 2);
        assert_eq!(by_location[0].item_count, 150_001);
        // Item match keeps only matches; counts describe kept rows only.
        let by_item = filter_groups(&groups, "tritanium");
        assert_eq!(by_item.len(), 2);
        assert_eq!(by_item[0].type_count, 1);
        assert_eq!(by_item[0].item_count, 150_000);
        assert_eq!(by_item[1].type_count, 1);
        assert_eq!(by_item[1].item_count, 42);
        // Type name still finds a custom-named row.
        let by_type = filter_groups(&groups, "rifter");
        assert_eq!(by_type.len(), 1);
        assert_eq!(by_type[0].rows[0].display_name, "Aria's Rifter");
        // Nothing matches -> no groups.
        assert!(filter_groups(&groups, "zzzzz").is_empty());
    }
}
