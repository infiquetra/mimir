//! Pantry (card #642): cross-character stockpile browsing with a
//! virtualized `egui_table` (only visible rows become widgets)
//! and Fit-Readiness rings for the selected saved fit. Every
//! rendered string is a resolved EVE name or the deterministic
//! `Unresolved Structure` bucket — never a raw numeric id. The
//! per-frame type-icon fetch cap (100) is preserved: the table
//! delegate queues icons only from its visible-row prefetch.
//!
//! Frame cost: derived rows, buckets, and available totals live
//! in `AppState::pantry_cache` (`PantryCache`), rebuilt only
//! when the snapshot fingerprint, name-cache size, or roster
//! fingerprint changes. A steady-state frame borrows the
//! snapshot (never clones it), re-filters only on query edits,
//! and hands the cached rows to the table delegate.

use std::collections::{HashMap, HashSet};

use egui_table::{
    AutoSizeMode, CellInfo, Column, HeaderCellInfo, HeaderRow, PrefetchInfo, Table, TableDelegate,
};

use super::portraits::{
    ensure_type_icon_requested, show_type_icon, PortraitImageCache, TYPE_ICON_PX,
};
use super::tokens::{TABLE_HEADER_HEIGHT, TABLE_ROW_HEIGHT, TOKENS};
use super::widgets;
use crate::app::state::{AppState, LoadState, StepUpRequest, View};
use crate::config::EveConfig;
use crate::esi::models::CharacterFitting;
use crate::names::resolver::{is_structure_id, NameResolver};
use crate::pantry::indexer::{
    characters_fingerprint, select_new_icon_fetches, PantryCacheKey, PantryDisplayRow,
    MAX_NEW_ICON_FETCHES_PER_FRAME, UNRESOLVED_STRUCTURE,
};
use crate::pantry::readiness::{compute_readiness, FitRequirement};
use crate::portraits::ImageKind;

/// Column basis widths at the 900 px reference pane width
/// (Item, Character, Location, Bay, Quantity); panes scale
/// from the basis, never below the matching floor.
const COL_BASIS_WIDTHS: [f32; 5] = [280.0, 150.0, 230.0, 140.0, 100.0];
/// Legibility floors enforced through `Column::range`: without
/// a range minimum, `egui_table`'s sizing pass collapses
/// truncated-label columns to its 4 px default minimum. The
/// five floors sum to 495 px so the table fits the Fitting &
/// Hangar split pane at 1280x800 without clipping Quantity.
const COL_MIN_WIDTHS: [f32; 5] = [155.0, 90.0, 125.0, 65.0, 60.0];
const COL_BASIS_TOTAL: f32 = 900.0;
const COL_MIN_PANE_WIDTH: f32 = 320.0;

/// Fit-Readiness ring geometry (points).
const RING_DIAMETER: f32 = 56.0;
const RING_RADIUS: f32 = 24.0;
const RING_STROKE: f32 = 5.0;
const RING_STEPS: usize = 48;

/// Pane-scaled columns with explicit range floors: the sizing
/// pass clamps measured widths into `range`, so the floor is
/// what keeps every column legible in narrow tiles.
fn pantry_columns(available_width: f32) -> Vec<Column> {
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

/// Resolve a location id for display: denied structure names
/// collapse into the deterministic unresolved bucket.
fn display_location_name(resolver: &NameResolver, location_id: i64) -> String {
    let name = resolver.location_name(location_id);
    if name == "Unknown Location" && is_structure_id(location_id) {
        UNRESOLVED_STRUCTURE.to_string()
    } else {
        name
    }
}

struct PantryDelegate<'a> {
    rows: Vec<PantryDisplayRow>,
    /// Indices into `rows` surviving the search filter, in
    /// build-sort order. The table renders only these.
    visible: Vec<usize>,
    state: &'a mut AppState,
    cache: &'a mut PortraitImageCache,
}

impl TableDelegate for PantryDelegate<'_> {
    fn prepare(&mut self, info: &PrefetchInfo) {
        // Queue icons for visible rows only, capped per frame.
        let start = (info.visible_rows.start as usize).min(self.visible.len());
        let end = (info.visible_rows.end as usize).min(self.visible.len());
        let visible_type_ids: Vec<i64> = self.visible[start..end]
            .iter()
            .map(|index| self.rows[*index].type_id)
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
                "[PANTRY] queueing {} new type icons this frame",
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
            1 => "Character",
            2 => "Location",
            3 => "Bay",
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
        let Some(row) = self
            .visible
            .get(cell.row_nr as usize)
            .and_then(|index| self.rows.get(*index))
        else {
            return;
        };
        // Clone the row's display fields so the icon call below
        // can borrow state and cache mutably.
        let row = row.clone();
        match cell.col_nr {
            0 => {
                show_type_icon(ui, self.cache, self.state, row.type_id, TYPE_ICON_PX);
                let mut label = row.type_name.clone();
                if row.is_blueprint_copy {
                    label.push_str(" (copy)");
                }
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
                        egui::RichText::new(&row.character_name)
                            .color(TOKENS.text_muted)
                            .font(TOKENS.typography.small_font()),
                    )
                    .truncate(),
                );
            }
            2 => {
                ui.add(
                    egui::Label::new(
                        egui::RichText::new(&row.location_name)
                            .color(TOKENS.text_muted)
                            .font(TOKENS.typography.small_font()),
                    )
                    .truncate(),
                );
            }
            3 => {
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

/// Requirements for one copy of a saved fit: hull plus items
/// grouped by type (charges and modules alike count per fit).
fn fit_requirements(fit: &CharacterFitting, resolver: &NameResolver) -> Vec<FitRequirement> {
    let mut by_type: HashMap<i64, i64> = HashMap::new();
    *by_type.entry(fit.ship_type_id).or_insert(0) += 1;
    for item in &fit.items {
        *by_type.entry(item.type_id).or_insert(0) += item.quantity.max(0);
    }
    let mut requirements: Vec<FitRequirement> = by_type
        .into_iter()
        .map(|(type_id, quantity_per_copy)| FitRequirement {
            type_id,
            type_name: resolver.name(type_id),
            quantity_per_copy,
        })
        .collect();
    requirements.sort_by(|a, b| a.type_name.cmp(&b.type_name));
    requirements
}

/// Bring `state.pantry_cache` up to date for this frame.
/// The items fingerprint is maintained by `PantrySnapshot`
/// itself (computed per data change), so the cache key here
/// is O(1) in the row count; the character-name map is built
/// only when a rebuild will actually run.
fn ensure_pantry_cache(state: &mut AppState, resolver: &NameResolver) {
    let Some(snapshot) = state.pantry.as_ready() else {
        return;
    };
    let roster: Vec<(i64, &str)> = state
        .characters
        .iter()
        .map(|c| (c.character_id, c.name.as_str()))
        .collect();
    let key = PantryCacheKey {
        items_fingerprint: snapshot.fingerprint,
        resolver_len: resolver.len(),
        characters_fingerprint: characters_fingerprint(&roster),
    };
    if state.pantry_cache.key == Some(key)
        && state.pantry_cache.filtered_key == Some(key)
        && state.pantry_cache.filtered_query == state.pantry_search
    {
        return;
    }
    // On a pure re-filter (key already warm) the name closures
    // are never invoked, so the map stays empty by design.
    let character_names: HashMap<i64, String> = if state.pantry_cache.key == Some(key) {
        HashMap::new()
    } else {
        state
            .characters
            .iter()
            .map(|c| (c.character_id, c.name.clone()))
            .collect()
    };
    let query = state.pantry_search.clone();
    let Some(snapshot) = state.pantry.as_ready() else {
        return;
    };
    state.pantry_cache.ensure(
        key,
        &snapshot.items,
        &query,
        |type_id| resolver.name(type_id),
        |character_id| {
            character_names
                .get(&character_id)
                .cloned()
                .unwrap_or_else(|| "Unknown Character".to_string())
        },
        |location_id| display_location_name(resolver, location_id),
        |id| is_structure_id(id) && resolver.location_name(id) == "Unknown Location",
    );
}

fn readiness_panel(ui: &mut egui::Ui, state: &AppState, resolver: &NameResolver) {
    let LoadState::Ready(fittings_data) = &state.fittings else {
        return;
    };
    let Ok(fittings) = &fittings_data.fittings else {
        return;
    };
    if fittings.is_empty() {
        return;
    }
    let fit = state
        .fittings_selected_fitting_id
        .and_then(|id| fittings.iter().find(|f| f.fitting_id == id))
        .unwrap_or(&fittings[0]);
    let requirements = fit_requirements(fit, resolver);
    // Cached available-stock totals (fitted gear and ship bays
    // excluded at cache build) — never a per-frame aggregate.
    let readiness = compute_readiness(&requirements, &state.pantry_cache.available_by_type);
    widgets::card(ui, |ui| {
        widgets::section_title(ui, &format!("Fit readiness — {}", fit.name));
        ui.horizontal(|ui| {
            // Completion ring: background track plus ratio arc.
            let (rect, _) = ui.allocate_exact_size(
                egui::vec2(RING_DIAMETER, RING_DIAMETER),
                egui::Sense::hover(),
            );
            let center = rect.center();
            let radius = RING_RADIUS;
            let painter = ui.painter();
            painter.circle_stroke(
                center,
                radius,
                egui::Stroke::new(RING_STROKE, TOKENS.stroke_hairline),
            );
            let ratio = readiness.completion_ratio.clamp(0.0, 1.0) as f32;
            if ratio > 0.0 {
                let steps = RING_STEPS;
                let points: Vec<egui::Pos2> = (0..=(steps as f32 * ratio) as usize)
                    .map(|step| {
                        let angle = -std::f32::consts::FRAC_PI_2
                            + (step as f32 / steps as f32) * std::f32::consts::TAU;
                        center + radius * egui::vec2(angle.cos(), angle.sin())
                    })
                    .collect();
                if points.len() > 1 {
                    painter.add(egui::Shape::line(
                        points,
                        egui::Stroke::new(RING_STROKE, TOKENS.positive),
                    ));
                }
            }
            ui.vertical(|ui| {
                ui.label(
                    egui::RichText::new(format!("{} buildable", readiness.buildable_copies))
                        .color(TOKENS.brass_sight)
                        .font(TOKENS.typography.heading_font()),
                );
                ui.add(
                    egui::ProgressBar::new(readiness.completion_ratio as f32).text(format!(
                        "{:.0}% of next copy",
                        readiness.completion_ratio * 100.0
                    )),
                );
            });
        });
        if readiness.unresolved_missing_count > 0 {
            ui.label(
                egui::RichText::new(format!(
                    "{} missing item name(s) could not be resolved yet and are not in the Multibuy block.",
                    readiness.unresolved_missing_count
                ))
                .color(TOKENS.warning)
                .font(TOKENS.typography.small_font()),
            );
        }
        if !readiness.multibuy_block.is_empty() {
            ui.label(
                egui::RichText::new("Missing for the next copy (EVE Multibuy):")
                    .color(TOKENS.text_muted)
                    .font(TOKENS.typography.small_font()),
            );
            ui.label(
                egui::RichText::new(&readiness.multibuy_block)
                    .color(TOKENS.text_primary)
                    .font(TOKENS.typography.mono_font()),
            );
            if ui.button("Copy Multibuy block").clicked() {
                tracing::info!("[PANTRY] copied Multibuy block for fit readiness");
                ui.ctx().copy_text(readiness.multibuy_block.clone());
            }
        }
    });
}

fn step_up_badges(ui: &mut egui::Ui, state: &mut AppState, step_up_character_ids: &[i64]) {
    for character_id in step_up_character_ids {
        let Some(name) = state
            .characters
            .iter()
            .find(|c| c.character_id == *character_id)
            .map(|c| c.name.clone())
        else {
            continue;
        };
        widgets::card(ui, |ui| {
            ui.label(
                egui::RichText::new(format!(
                    "{name} has not granted the assets scope, so their holdings are not in Pantry totals yet."
                ))
                .color(TOKENS.warning)
                .font(TOKENS.typography.body_font()),
            );
            let enabled = !state.demo && !state.auth.is_busy();
            if ui
                .add_enabled(enabled, egui::Button::new("Re-authorize with EVE SSO"))
                .clicked()
            {
                tracing::info!(
                    "[PANTRY] step-up re-authorize requested character_id={}",
                    character_id
                );
                state.stepup_requested =
                    Some(StepUpRequest::new(*character_id, EveConfig::ASSETS_SCOPES));
                state.status_message =
                    "EVE SSO requested: your browser should open to login.eveonline.com."
                        .to_string();
            }
        });
    }
}

pub fn show(
    ui: &mut egui::Ui,
    state: &mut AppState,
    resolver: &NameResolver,
    cache: &mut PortraitImageCache,
) {
    ui.heading("Pantry");
    widgets::mode_notice(ui, state.demo, state.offline);
    cache.prune(state);
    if state.characters.is_empty() {
        widgets::no_character_panel(ui);
        return;
    }
    // Borrow the snapshot — never clone it per frame. Only the
    // small badge list and emptiness fact are copied out before
    // the mutable renders below.
    let ready_facts = match &state.pantry {
        LoadState::Ready(snapshot) => Some((
            snapshot.step_up_character_ids.clone(),
            snapshot.items.is_empty(),
        )),
        _ => None,
    };
    let Some((step_up_ids, items_empty)) = ready_facts else {
        match &state.pantry {
            LoadState::Loading => widgets::loading_panel(ui, "Loading stockpile..."),
            LoadState::Empty => widgets::empty_panel(ui, "No stockpile data yet."),
            LoadState::Error(message) => {
                let message = message.clone();
                if widgets::error_panel_with_retry(ui, &message) {
                    tracing::warn!("[PANTRY] retry requested after load error");
                    state.retry_requested = true;
                }
            }
            LoadState::Ready(_) => unreachable!("Ready handled above"),
        }
        return;
    };
    step_up_badges(ui, state, &step_up_ids);
    if items_empty {
        widgets::empty_panel(
            ui,
            "No stockpile yet. Press Ctrl+R (or Refresh) after signing in.",
        );
        return;
    }
    ensure_pantry_cache(state, resolver);
    readiness_panel(ui, state, resolver);
    let focus = widgets::search_box(
        ui,
        &mut state.pantry_search,
        "Filter stockpile by item, character, or location (press / to focus)",
        state.focus_search && state.view == View::Pantry,
    );
    state.text_input_focused |= focus;
    if focus && state.view == View::Pantry {
        state.focus_search = false;
    }
    // Pick up a query edit from this frame's search box (a pure
    // re-filter on a warm cache; a no-op when nothing changed).
    ensure_pantry_cache(state, resolver);
    // Bucket summary: cached root places with resolved names only.
    ui.horizontal_wrapped(|ui| {
        for bucket in state.pantry_cache.buckets.iter().take(8) {
            ui.label(
                egui::RichText::new(format!(
                    "{} · {} · {} items",
                    bucket.display_name,
                    bucket.kind.label(),
                    widgets::format_count(bucket.total_quantity)
                ))
                .color(TOKENS.text_muted)
                .font(TOKENS.typography.small_font()),
            );
        }
    });
    let visible_len = state.pantry_cache.filtered.len();
    if visible_len == 0 {
        widgets::empty_panel(ui, "No stockpile rows match the search.");
        return;
    }
    ui.label(
        egui::RichText::new(format!(
            "{} stockpile rows across {} character(s)",
            widgets::format_count(visible_len as i64),
            state.characters.len()
        ))
        .color(TOKENS.text_muted)
        .font(TOKENS.typography.small_font()),
    );
    // Move the cached rows into the delegate (pointer moves, not
    // clones) so it can also hold `&mut state`; restore after.
    let rows = std::mem::take(&mut state.pantry_cache.rows);
    let visible = std::mem::take(&mut state.pantry_cache.filtered);
    let (rows, visible) = {
        let mut delegate = PantryDelegate {
            rows,
            visible,
            state,
            cache,
        };
        Table::new()
            .id_salt("pantry_table")
            .num_rows(visible_len as u64)
            .columns(pantry_columns(ui.available_width()))
            // Fit columns to the pane on resize (range floors
            // still bind), so narrow tiles shrink instead of
            // clipping the Quantity column off-screen.
            .auto_size_mode(AutoSizeMode::OnParentResize)
            .headers(vec![HeaderRow::new(TABLE_HEADER_HEIGHT)])
            .show(ui, &mut delegate);
        (delegate.rows, delegate.visible)
    };
    state.pantry_cache.rows = rows;
    state.pantry_cache.filtered = visible;
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn display_location_name_hides_denied_structure_ids() {
        let mut resolver = NameResolver::new();
        resolver.insert(60003760, "Jita Station".to_string());
        assert_eq!(display_location_name(&resolver, 60003760), "Jita Station");
        // Unresolved structure-range id -> deterministic bucket,
        // never the raw number.
        let denied = display_location_name(&resolver, 1_060_000_000_001);
        assert_eq!(denied, UNRESOLVED_STRUCTURE);
        assert!(!denied.chars().any(|c| c.is_ascii_digit()));
    }

    #[test]
    fn every_pantry_column_carries_a_legibility_floor() {
        // The collapsed-golden regression: without range minima
        // the egui_table sizing pass shrinks truncated labels to
        // 4 px. Every column must floor at its COL_MIN_WIDTHS
        // value at both golden pane widths.
        for width in [540.0, 900.0] {
            let columns = pantry_columns(width);
            assert_eq!(columns.len(), 5);
            for (column, floor) in columns.iter().zip(COL_MIN_WIDTHS) {
                assert_eq!(column.range.min, floor, "floor at pane width {width}");
                assert!(column.current >= floor);
                assert!(column.range.max > floor);
            }
        }
    }
}
