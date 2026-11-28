//! Assets: the active character's item list grouped by location, with
//! text search and singleton custom names. Every rendered string is a
//! resolved EVE name (or the resolver's Unknown fallback), never a raw ID.
//!
//! Rendering is a virtualized `egui_table` over every filtered
//! row (group order preserved, location carried per row): there
//! is no render cap, so every row is reachable by scrolling.
//! The per-frame type-icon fetch cap (100) still applies through
//! the delegate's visible-row prefetch, exactly as in Pantry.

use std::collections::{BTreeMap, HashMap, HashSet};

use egui_table::{
    AutoSizeMode, CellInfo, Column, HeaderCellInfo, HeaderRow, PrefetchInfo, Table, TableDelegate,
};

use super::portraits::{
    ensure_type_icon_requested, show_type_icon, PortraitImageCache, TYPE_ICON_PX,
};
use super::tokens::{TABLE_HEADER_HEIGHT, TABLE_ROW_HEIGHT, TOKENS};
use super::widgets;
use crate::app::state::{AppState, AssetsData, LoadState, StepUpRequest, View};
use crate::config::EveConfig;
use crate::esi::models::AssetItem;
use crate::names::resolver::NameResolver;
use crate::pantry::indexer::{select_new_icon_fetches, MAX_NEW_ICON_FETCHES_PER_FRAME};
use crate::portraits::ImageKind;

/// Column basis widths at the reference pane width (Item,
/// Location, Bay, Quantity) with legibility floors, mirroring
/// the Pantry table so both stock tables scale identically.
const COL_BASIS_WIDTHS: [f32; 4] = [300.0, 230.0, 140.0, 100.0];
const COL_MIN_WIDTHS: [f32; 4] = [170.0, 130.0, 70.0, 64.0];
const COL_BASIS_TOTAL: f32 = 770.0;
const COL_MIN_PANE_WIDTH: f32 = 320.0;

/// Pane-scaled columns with explicit `Column::range` floors
/// (see the Pantry table for why the floor is load-bearing).
fn asset_columns(available_width: f32) -> Vec<Column> {
    let unit = available_width.max(COL_MIN_PANE_WIDTH) / COL_BASIS_TOTAL;
    COL_BASIS_WIDTHS
        .iter()
        .zip(COL_MIN_WIDTHS)
        .map(|(basis, floor)| {
            Column::new((basis * unit).max(floor))
                .range(floor..=(basis * 2.0 * unit).max(floor * 1.5))
        })
        .collect()
}

/// One display row: names already resolved, never a raw numeric ID.
#[derive(Debug, Clone, Default, PartialEq)]
pub struct AssetRow {
    pub item_id: i64,
    // State-only image key for the row's type icon: never formatted
    // into any rendered string and never logged.
    pub type_id: i64,
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

/// Total displayed quantity for one location group. Quantities decode
/// straight from remote JSON with no range validation, so summation must
/// saturate instead of overflowing (panic in debug, wrap in release).
fn total_quantity(rows: &[AssetRow]) -> i64 {
    rows.iter()
        .fold(0i64, |acc, r| acc.saturating_add(r.quantity))
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
                type_id: item.type_id,
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
            let item_count = total_quantity(&rows);
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
        let item_count = total_quantity(&rows);
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

/// One virtualized table row: a grouped asset row plus its
/// resolved location name, so the flat table never loses the
/// grouping context the location cards used to carry.
#[derive(Debug, Clone, PartialEq)]
pub struct AssetDisplayRow {
    pub row: AssetRow,
    pub location_name: String,
}

/// Flatten location groups into table order (group order, then
/// in-group display order). Every filtered row is present:
/// virtualization replaced the old 100-row render truncation,
/// so the row count here is the table's `num_rows`.
pub fn flatten_groups(groups: &[AssetLocationGroup]) -> Vec<AssetDisplayRow> {
    let total: usize = groups.iter().map(|g| g.rows.len()).sum();
    let mut rows = Vec::with_capacity(total);
    for group in groups {
        for row in &group.rows {
            rows.push(AssetDisplayRow {
                row: row.clone(),
                location_name: group.location_name.clone(),
            });
        }
    }
    rows
}

struct AssetsDelegate<'a> {
    rows: Vec<AssetDisplayRow>,
    state: &'a mut AppState,
    cache: &'a mut PortraitImageCache,
}

impl TableDelegate for AssetsDelegate<'_> {
    fn prepare(&mut self, info: &PrefetchInfo) {
        // Queue icons for visible rows only, capped per frame
        // (the same 100-per-frame contract the truncated list
        // honored, now scoped to what is actually on screen).
        let start = (info.visible_rows.start as usize).min(self.rows.len());
        let end = (info.visible_rows.end as usize).min(self.rows.len());
        let visible_type_ids: Vec<i64> = self.rows[start..end]
            .iter()
            .map(|display| display.row.type_id)
            .collect();
        let mut already: HashSet<i64> = self
            .state
            .portrait_requests
            .iter()
            .filter(|(kind, _)| *kind == ImageKind::Type)
            .map(|(_, id)| *id)
            .collect();
        already.extend(
            self.state
                .portraits
                .keys()
                .filter(|(kind, _)| *kind == ImageKind::Type)
                .map(|(_, id)| *id),
        );
        let chosen =
            select_new_icon_fetches(&visible_type_ids, &already, MAX_NEW_ICON_FETCHES_PER_FRAME);
        if !chosen.is_empty() {
            tracing::debug!(
                "[ASSETS] queueing {} new type icons this frame",
                chosen.len()
            );
        }
        for type_id in chosen {
            ensure_type_icon_requested(self.state, type_id);
        }
    }

    fn header_cell_ui(&mut self, ui: &mut egui::Ui, cell: &HeaderCellInfo) {
        let label = match cell.col_range.start {
            0 => "Item",
            1 => "Location",
            2 => "Bay",
            _ => "Quantity",
        };
        ui.add(
            egui::Label::new(
                egui::RichText::new(label)
                    .color(TOKENS.text_muted)
                    .font(TOKENS.typography.small_font()),
            )
            .truncate(),
        );
    }

    fn cell_ui(&mut self, ui: &mut egui::Ui, cell: &CellInfo) {
        let Some(display) = self.rows.get(cell.row_nr as usize) else {
            return;
        };
        // Clone the row's display fields so the icon call below
        // can borrow state and cache mutably.
        let display = display.clone();
        let row = &display.row;
        match cell.col_nr {
            0 => {
                show_type_icon(ui, self.cache, self.state, row.type_id, TYPE_ICON_PX);
                let label = if row.has_custom_name {
                    format!("{} ({})", row.display_name, row.type_name)
                } else {
                    row.display_name.clone()
                };
                ui.add(
                    egui::Label::new(
                        egui::RichText::new(label)
                            .color(TOKENS.text_primary)
                            .font(TOKENS.typography.body_font()),
                    )
                    .truncate(),
                );
            }
            1 => {
                ui.add(
                    egui::Label::new(
                        egui::RichText::new(&display.location_name)
                            .color(TOKENS.text_muted)
                            .font(TOKENS.typography.small_font()),
                    )
                    .truncate(),
                );
            }
            2 => {
                ui.add(
                    egui::Label::new(
                        egui::RichText::new(&row.location_flag)
                            .color(TOKENS.text_muted)
                            .font(TOKENS.typography.small_font()),
                    )
                    .truncate(),
                );
            }
            _ => {
                ui.with_layout(egui::Layout::right_to_left(egui::Align::Center), |ui| {
                    ui.label(
                        egui::RichText::new(widgets::format_count(row.quantity))
                            .color(TOKENS.brass_sight)
                            .font(TOKENS.typography.mono_font()),
                    );
                });
            }
        }
    }

    fn default_row_height(&self) -> f32 {
        TABLE_ROW_HEIGHT
    }
}

/// Step-up guidance with a real Re-authorize button: the button only
/// sets the shell's step-up request flag for the active character.
fn reauthorize_panel(ui: &mut egui::Ui, state: &mut AppState) {
    ui.heading("Assets need one more EVE permission.");
    ui.label(
        "This character has not granted esi-assets.read_assets.v1, the EVE SSO \
         scope that lets Mimir read the character asset list. No asset data was \
         loaded, and your other views are unaffected.",
    );
    let active_id = state.active_character_id;
    if let Some(name) = state.active_character().map(|c| c.name.clone()) {
        ui.label(format!(
            "Choose Re-authorize and Mimir opens EVE SSO in your browser for {name}, \
             asking for the permissions already granted plus this one. Sign in as \
             {name}: approving as a different character is rejected and nothing \
             is saved."
        ));
    }
    let enabled = !state.demo && !state.auth.is_busy() && state.active_character_id.is_some();
    if state.auth.is_busy() {
        ui.spinner();
        ui.label(state.auth.label());
    }
    if ui
        .add_enabled(enabled, egui::Button::new("Re-authorize with EVE SSO"))
        .clicked()
    {
        if let Some(active_id) = active_id {
            tracing::info!(
                "[AUTH] step-up re-authorize requested from Assets view character_id={} scopes={}",
                active_id,
                EveConfig::ASSETS_SCOPES.join(" ")
            );
            state.stepup_requested = Some(StepUpRequest::new(active_id, EveConfig::ASSETS_SCOPES));
            state.status_message =
                "EVE SSO requested: your browser should open to login.eveonline.com.".to_string();
        }
    }
}

/// Structure-names step-up guidance (design section 5.3): a
/// non-blocking banner above the loaded assets. Structure names
/// being unavailable must never hide asset data that loaded fine.
fn structures_stepup_banner(ui: &mut egui::Ui, state: &mut AppState) {
    ui.heading("Some location names need one more EVE permission.");
    ui.label(
        "This character has not granted esi-universe.read_structures.v1, the EVE SSO \
         scope that lets Mimir look up player-built structure names. Locations inside \
         player structures show as Unknown Location until it is granted; everything \
         else is unaffected.",
    );
    let active_id = state.active_character_id;
    if let Some(name) = state.active_character().map(|c| c.name.clone()) {
        ui.label(format!(
            "Choose Re-authorize and Mimir opens EVE SSO in your browser for {name}, \
             asking for the permissions already granted plus this one. Sign in as \
             {name}: approving as a different character is rejected and nothing \
             is saved."
        ));
    }
    let enabled = !state.demo && !state.auth.is_busy() && state.active_character_id.is_some();
    if state.auth.is_busy() {
        ui.spinner();
        ui.label(state.auth.label());
    }
    if ui
        .add_enabled(enabled, egui::Button::new("Re-authorize with EVE SSO"))
        .clicked()
    {
        if let Some(active_id) = active_id {
            tracing::info!(
                "[AUTH] step-up re-authorize requested from Assets view character_id={} scopes={}",
                active_id,
                EveConfig::STRUCTURE_SCOPES.join(" ")
            );
            state.stepup_requested =
                Some(StepUpRequest::new(active_id, EveConfig::STRUCTURE_SCOPES));
            state.status_message =
                "EVE SSO requested: your browser should open to login.eveonline.com.".to_string();
        }
    }
}

pub fn show(
    ui: &mut egui::Ui,
    state: &mut AppState,
    resolver: &NameResolver,
    cache: &mut PortraitImageCache,
) {
    ui.heading("Assets");
    widgets::mode_notice(ui, state.demo, state.offline);
    cache.prune(state);
    if state.active_character().is_none() {
        widgets::no_character_panel(ui);
        return;
    }
    if state.assets_needs_reauthorize {
        tracing::debug!("[ASSETS] showing re-authorize guidance (missing scope)");
        reauthorize_panel(ui, state);
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
            // Structure step-up banner (design section 5.3): only
            // once assets have loaded (after the assets-scope panel
            // above), and never by replacing the data.
            if state.structures_needs_reauthorize {
                tracing::debug!("[ASSETS] showing structure step-up guidance (missing scope)");
                structures_stepup_banner(ui, state);
            }
            let focus = widgets::search_box(
                ui,
                &mut state.assets_search,
                "Filter assets by item or location (press / to focus)",
                state.focus_search && state.view == View::Assets,
            );
            state.text_input_focused |= focus;
            if focus && state.view == View::Assets {
                state.focus_search = false;
            }
            let groups = filter_groups(&group_assets(&data, resolver), &state.assets_search);
            if groups.is_empty() {
                widgets::empty_panel(ui, "No assets match the search.");
                return;
            }
            // Location summary chips keep the per-location counts
            // the group card headers carried; the table below
            // holds every filtered row (no render truncation).
            ui.horizontal_wrapped(|ui| {
                for group in groups.iter().take(8) {
                    let type_noun = if group.type_count == 1 {
                        "item type"
                    } else {
                        "item types"
                    };
                    let item_noun = if group.item_count == 1 {
                        "total item"
                    } else {
                        "total items"
                    };
                    ui.label(
                        egui::RichText::new(format!(
                            "{} — {} {}, {} {}",
                            group.location_name,
                            widgets::format_count(group.type_count as i64),
                            type_noun,
                            widgets::format_count(group.item_count),
                            item_noun
                        ))
                        .color(TOKENS.text_muted)
                        .font(TOKENS.typography.small_font()),
                    );
                }
            });
            let rows = flatten_groups(&groups);
            ui.label(
                egui::RichText::new(format!(
                    "{} asset rows across {} location(s)",
                    widgets::format_count(rows.len() as i64),
                    groups.len()
                ))
                .color(TOKENS.text_muted)
                .font(TOKENS.typography.small_font()),
            );
            let row_count = rows.len() as u64;
            let mut delegate = AssetsDelegate { rows, state, cache };
            Table::new()
                .id_salt("assets_table")
                .num_rows(row_count)
                .columns(asset_columns(ui.available_width()))
                .auto_size_mode(AutoSizeMode::OnParentResize)
                .headers(vec![HeaderRow::new(TABLE_HEADER_HEIGHT)])
                .show(ui, &mut delegate);
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
    fn group_assets_carries_type_id_onto_rows() {
        let groups = group_assets(&data(), &resolver());
        let by_item: HashMap<i64, i64> = groups
            .iter()
            .flat_map(|g| &g.rows)
            .map(|r| (r.item_id, r.type_id))
            .collect();
        assert_eq!(by_item[&1], 34);
        assert_eq!(by_item[&2], 587);
        assert_eq!(by_item[&3], 681);
        assert_eq!(by_item[&4], 34);
        // Both filter branches keep the carried id intact.
        let by_location = filter_groups(&groups, "jita");
        assert_eq!(
            by_location[0]
                .rows
                .iter()
                .map(|r| (r.item_id, r.type_id))
                .collect::<Vec<_>>(),
            vec![(2, 587), (1, 34)]
        );
        let by_item_name = filter_groups(&groups, "tritanium");
        assert!(by_item_name
            .iter()
            .flat_map(|g| &g.rows)
            .all(|r| r.type_id == 34));
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

    #[test]
    fn flatten_reaches_every_filtered_row_without_truncation() {
        // Virtualization contract (replaces the old 100-row
        // render cap): flattening keeps group order, carries
        // each row's location name, and drops nothing — the
        // table's num_rows is exactly this length, so every
        // filtered row is reachable by scrolling.
        let groups = group_assets(&data(), &resolver());
        let flat = flatten_groups(&groups);
        assert_eq!(flat.len(), 4);
        assert_eq!(flat[0].location_name, "Jita Station");
        assert_eq!(flat[0].row.display_name, "Aria's Rifter");
        assert!(flat.iter().all(|d| !d.location_name.is_empty()));
        // 125 rows in one location: all 125 survive grouping,
        // filtering, and flattening (no 100-row window).
        let mut big = AssetsData {
            items: Vec::new(),
            custom_names: HashMap::new(),
        };
        for n in 0..125 {
            big.items
                .push(item(n + 1, 1001 + n, 1, 60003760, false, None));
        }
        let mut big_resolver = NameResolver::new();
        big_resolver.insert(60003760, "Jita Station".to_string());
        for n in 0..125 {
            big_resolver.insert(1001 + n, format!("Item {}", 1001 + n));
        }
        let flat_big = flatten_groups(&filter_groups(&group_assets(&big, &big_resolver), ""));
        assert_eq!(flat_big.len(), 125);
        // Every asset column carries a legibility floor.
        for width in [420.0, 770.0] {
            for (column, floor) in asset_columns(width).iter().zip(COL_MIN_WIDTHS) {
                assert_eq!(column.range.min, floor);
            }
        }
    }

    #[test]
    fn assets_show_queues_icons_for_rendered_rows_only() {
        use crate::app::state::PortraitState;
        use crate::portraits::ImageKind;
        use crate::storage::repositories::CharacterRow;

        fn character_row(id: i64) -> CharacterRow {
            CharacterRow {
                character_id: id,
                name: "Test Pilot".to_string(),
                corporation_id: 1000166,
                alliance_id: None,
                is_active: false,
            }
        }

        fn state_with_assets(items: Vec<AssetItem>) -> AppState {
            let mut state = AppState::new(false);
            state.characters = vec![character_row(1)];
            state.set_active_character(1);
            state.assets = LoadState::Ready(AssetsData {
                items,
                custom_names: HashMap::new(),
            });
            state.fittings = LoadState::Loading;
            state
        }

        // `egui_table` runs a discarded sizing pass on its first
        // frame in a fresh context, and each pass may queue up
        // to the cap. Warm the table state up with a one-row
        // render so measured frames below are single-pass steady
        // frames — the regime the per-frame cap contract binds.
        fn warm_table(ctx: &egui::Context) {
            let mut state = state_with_assets(vec![item(1, 9999, 1, 60003760, false, None)]);
            let resolver = numbered_resolver(&[9999], &[(60003760, "Jita Station")]);
            let mut cache = PortraitImageCache::new();
            for _ in 0..2 {
                let mut full_output = ctx.run_ui(egui::RawInput::default(), |ui| {
                    egui::CentralPanel::default().show(ui, |ui| {
                        show(ui, &mut state, &resolver, &mut cache);
                    });
                });
                full_output.textures_delta.clear();
            }
        }

        fn numbered_resolver(type_ids: &[i64], locations: &[(i64, &str)]) -> NameResolver {
            let mut r = NameResolver::new();
            for id in type_ids {
                r.insert(*id, format!("Item {id}"));
            }
            for (lid, name) in locations {
                r.insert(*lid, (*name).to_string());
            }
            r
        }

        // No active character: show returns at the no-character panel.
        {
            let mut state = AppState::new(false);
            let resolver = NameResolver::new();
            let mut cache = PortraitImageCache::new();
            let ctx = egui::Context::default();
            let mut full_output = ctx.run_ui(egui::RawInput::default(), |ui| {
                egui::CentralPanel::default().show(ui, |ui| {
                    show(ui, &mut state, &resolver, &mut cache);
                });
            });
            full_output.textures_delta.clear();
            assert!(state.portrait_requests.is_empty());
            assert!(cache.is_empty());
        }

        // 125 rows in one location under virtualization: the
        // first frame queues only visible rows' icons and never
        // more than the 100-per-frame cap; the last row (1125,
        // sorted last) is not among them. Filtering to that row
        // makes it visible and queues exactly its icon — every
        // row stays reachable, with no duplicate queue entries.
        {
            let ids: Vec<i64> = (1001..=1125).collect();
            let items: Vec<AssetItem> = ids
                .iter()
                .enumerate()
                .map(|(idx, id)| item(idx as i64 + 1, *id, 1, 60003760, false, None))
                .collect();
            let mut state = state_with_assets(items);
            let resolver = numbered_resolver(&ids, &[(60003760, "Jita Station")]);
            let mut cache = PortraitImageCache::new();
            let ctx = egui::Context::default();
            warm_table(&ctx);
            let mut full_output = ctx.run_ui(egui::RawInput::default(), |ui| {
                egui::CentralPanel::default().show(ui, |ui| {
                    show(ui, &mut state, &resolver, &mut cache);
                });
            });
            full_output.textures_delta.clear();
            let after_first = state.portrait_requests.len();
            assert!(
                (1..=100).contains(&after_first),
                "first frame queues visible icons within the cap, got {after_first}"
            );
            assert!(cache.is_empty());
            assert!(!state.portrait_requests.contains(&(ImageKind::Type, 1125)));
            // Filter before scrolling: searching for the 125th
            // row's name reveals it and queues its icon (the
            // per-frame growth still respects the cap).
            state.assets_search = "Item 1125".to_string();
            let mut full_output = ctx.run_ui(egui::RawInput::default(), |ui| {
                egui::CentralPanel::default().show(ui, |ui| {
                    show(ui, &mut state, &resolver, &mut cache);
                });
            });
            full_output.textures_delta.clear();
            assert!(state.portrait_requests.contains(&(ImageKind::Type, 1125)));
            assert!(state.portrait_requests.len() - after_first <= 100);
            // A steady frame queues nothing new and never
            // duplicates a key.
            let settled = state.portrait_requests.len();
            let mut full_output = ctx.run_ui(egui::RawInput::default(), |ui| {
                egui::CentralPanel::default().show(ui, |ui| {
                    show(ui, &mut state, &resolver, &mut cache);
                });
            });
            full_output.textures_delta.clear();
            assert_eq!(state.portrait_requests.len(), settled);
            let unique: std::collections::HashSet<_> = state.portrait_requests.iter().collect();
            assert_eq!(unique.len(), state.portrait_requests.len());
            assert!(cache.is_empty());
        }

        // 60 + 60 rows across two locations: the first frame
        // still respects the single global 100-per-frame cap
        // (one flat table, one prefetch budget).
        {
            let ids_a: Vec<i64> = (2001..=2060).collect();
            let ids_b: Vec<i64> = (3001..=3060).collect();
            let mut items = Vec::new();
            for (idx, id) in ids_a.iter().enumerate() {
                items.push(item(idx as i64 + 1, *id, 1, 60003760, false, None));
            }
            for (idx, id) in ids_b.iter().enumerate() {
                items.push(item(1000 + idx as i64, *id, 1, 60011866, false, None));
            }
            let mut all_ids = ids_a.clone();
            all_ids.extend(ids_b.iter().copied());
            let mut state = state_with_assets(items);
            let resolver = numbered_resolver(
                &all_ids,
                &[(60003760, "Jita Station"), (60011866, "Amarr Station")],
            );
            let mut cache = PortraitImageCache::new();
            let ctx = egui::Context::default();
            warm_table(&ctx);
            let mut full_output = ctx.run_ui(egui::RawInput::default(), |ui| {
                egui::CentralPanel::default().show(ui, |ui| {
                    show(ui, &mut state, &resolver, &mut cache);
                });
            });
            full_output.textures_delta.clear();
            assert!(
                (1..=100).contains(&state.portrait_requests.len()),
                "global per-frame cap holds across locations, got {}",
                state.portrait_requests.len()
            );
            assert!(cache.is_empty());
        }

        // A type repeated on three rendered rows queues once.
        {
            let items = vec![
                item(1, 4001, 1, 60003760, false, None),
                item(2, 4001, 1, 60003760, false, None),
                item(3, 4001, 1, 60003760, false, None),
            ];
            let mut state = state_with_assets(items);
            let resolver = numbered_resolver(&[4001], &[(60003760, "Jita Station")]);
            let mut cache = PortraitImageCache::new();
            let ctx = egui::Context::default();
            let mut full_output = ctx.run_ui(egui::RawInput::default(), |ui| {
                egui::CentralPanel::default().show(ui, |ui| {
                    show(ui, &mut state, &resolver, &mut cache);
                });
            });
            full_output.textures_delta.clear();
            assert_eq!(
                state.portrait_requests,
                vec![(ImageKind::Type, 4001)],
                "duplicate rows must queue once"
            );
            assert!(matches!(
                state.portrait_state(ImageKind::Type, 4001),
                PortraitState::Loading
            ));
        }

        // A row with type_id == 0 queues nothing.
        {
            let items = vec![item(1, 0, 1, 60003760, false, None)];
            let mut state = state_with_assets(items);
            let resolver = NameResolver::new();
            let mut cache = PortraitImageCache::new();
            let ctx = egui::Context::default();
            let mut full_output = ctx.run_ui(egui::RawInput::default(), |ui| {
                egui::CentralPanel::default().show(ui, |ui| {
                    show(ui, &mut state, &resolver, &mut cache);
                });
            });
            full_output.textures_delta.clear();
            assert!(state.portrait_requests.is_empty());
            assert!(cache.is_empty());
            assert!(!state.portraits.contains_key(&(ImageKind::Type, 0)));
        }
    }

    #[test]
    fn assets_demo_queues_held_types_but_never_ready() {
        use crate::demo::data::seed_demo_state;
        use crate::portraits::ImageKind;

        // Demo installs Ready assets for its first character (6
        // rows, 5 distinct held types); a headless show queues
        // exactly those five keys and uploads nothing. The shell
        // drain refusal guarantees none spawn in demo, so the
        // keys stay Loading and never become Ready.
        let mut state = AppState::new(true);
        seed_demo_state(&mut state);
        assert!(state.assets.is_ready(), "demo must install Ready assets");
        let assets = state.assets.as_ready().expect("demo assets ready").clone();
        let mut distinct: Vec<i64> = assets.items.iter().map(|i| i.type_id).collect();
        distinct.sort_unstable();
        distinct.dedup();
        assert_eq!(distinct.len(), 5, "demo fixture carries five types");
        let resolver = crate::demo::data::demo_resolver().expect("demo resolver loads");
        let mut cache = PortraitImageCache::new();
        let ctx = egui::Context::default();
        let mut full_output = ctx.run_ui(egui::RawInput::default(), |ui| {
            egui::CentralPanel::default().show(ui, |ui| {
                show(ui, &mut state, &resolver, &mut cache);
            });
        });
        full_output.textures_delta.clear();
        let mut queued_ids: Vec<i64> = state
            .portrait_requests
            .iter()
            .filter(|(kind, _)| *kind == ImageKind::Type)
            .map(|(_, id)| *id)
            .collect();
        queued_ids.sort_unstable();
        assert_eq!(queued_ids, distinct, "demo queues exactly the held types");
        assert!(cache.is_empty(), "blank-box path uploads nothing in demo");
        for (_, id) in &state.portrait_requests {
            assert!(!matches!(
                state.portrait_state(ImageKind::Type, *id),
                crate::app::state::PortraitState::Ready(_)
            ));
        }
    }

    #[test]
    fn grouping_saturates_instead_of_overflowing() {
        // Quantities decode from remote JSON unvalidated: two i64::MAX
        // rows must saturate the group total, never panic or wrap.
        let overflow = AssetsData {
            items: vec![
                item(10, 34, i64::MAX, 60003760, false, None),
                item(11, 34, i64::MAX, 60003760, false, None),
            ],
            custom_names: HashMap::new(),
        };
        let groups = group_assets(&overflow, &resolver());
        assert_eq!(groups.len(), 1);
        assert_eq!(groups[0].item_count, i64::MAX);
        let filtered = filter_groups(&groups, "jita");
        assert_eq!(filtered.len(), 1);
        assert_eq!(filtered[0].item_count, i64::MAX);
    }
}
