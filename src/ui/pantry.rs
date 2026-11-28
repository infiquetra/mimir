//! Pantry (card #642): cross-character stockpile browsing with a
//! virtualized `egui_table` (only visible rows become widgets)
//! and Fit-Readiness rings for the selected saved fit. Every
//! rendered string is a resolved EVE name or the deterministic
//! `Unresolved Structure` bucket — never a raw numeric id. The
//! per-frame type-icon fetch cap (100) is preserved: the table
//! delegate queues icons only from its visible-row prefetch.

use std::collections::{HashMap, HashSet};

use egui_table::{CellInfo, Column, HeaderCellInfo, HeaderRow, PrefetchInfo, Table, TableDelegate};

use super::portraits::{
    ensure_type_icon_requested, show_type_icon, PortraitImageCache, TYPE_ICON_PX,
};
use super::tokens::TOKENS;
use super::widgets;
use crate::app::state::{AppState, LoadState, StepUpRequest, View};
use crate::config::EveConfig;
use crate::esi::models::CharacterFitting;
use crate::names::resolver::{is_structure_id, NameResolver};
use crate::pantry::indexer::{
    aggregate_by_type, build_buckets, build_display_rows, filter_row_indices,
    select_new_icon_fetches, PantryDisplayRow, MAX_NEW_ICON_FETCHES_PER_FRAME,
    UNRESOLVED_STRUCTURE,
};
use crate::pantry::readiness::{compute_readiness, FitRequirement};
use crate::pantry::PantrySnapshot;
use crate::portraits::ImageKind;

const HEADER_HEIGHT: f32 = 28.0;
const ROW_HEIGHT: f32 = 28.0;

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
        ROW_HEIGHT
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

fn readiness_panel(
    ui: &mut egui::Ui,
    state: &AppState,
    snapshot: &PantrySnapshot,
    resolver: &NameResolver,
) {
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
    let totals = aggregate_by_type(&snapshot.items);
    let available: HashMap<i64, i64> = totals.into_iter().collect();
    let readiness = compute_readiness(&requirements, &available);
    widgets::card(ui, |ui| {
        widgets::section_title(ui, &format!("Fit readiness — {}", fit.name));
        ui.horizontal(|ui| {
            // Completion ring: background track plus ratio arc.
            let (rect, _) = ui.allocate_exact_size(egui::vec2(56.0, 56.0), egui::Sense::hover());
            let center = rect.center();
            let radius = 24.0;
            let painter = ui.painter();
            painter.circle_stroke(
                center,
                radius,
                egui::Stroke::new(5.0, TOKENS.stroke_hairline),
            );
            let ratio = readiness.completion_ratio.clamp(0.0, 1.0) as f32;
            if ratio > 0.0 {
                let steps = 48usize;
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
                        egui::Stroke::new(5.0, TOKENS.positive),
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

fn step_up_badges(ui: &mut egui::Ui, state: &mut AppState, snapshot: &PantrySnapshot) {
    for character_id in &snapshot.step_up_character_ids {
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
    let snapshot = state.pantry.clone();
    match snapshot {
        LoadState::Ready(snapshot) => {
            step_up_badges(ui, state, &snapshot);
            if snapshot.items.is_empty() {
                widgets::empty_panel(
                    ui,
                    "No stockpile yet. Press Ctrl+R (or Refresh) after signing in.",
                );
                return;
            }
            readiness_panel(ui, state, &snapshot, resolver);
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
            // Bucket summary: root places with resolved names only.
            let buckets = build_buckets(
                &snapshot.items,
                |id| display_location_name(resolver, id),
                |id| is_structure_id(id) && resolver.location_name(id) == "Unknown Location",
            );
            ui.horizontal_wrapped(|ui| {
                for bucket in buckets.iter().take(8) {
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
            let character_names: HashMap<i64, String> = state
                .characters
                .iter()
                .map(|c| (c.character_id, c.name.clone()))
                .collect();
            let rows = build_display_rows(
                &snapshot.items,
                |type_id| resolver.name(type_id),
                |character_id| {
                    character_names
                        .get(&character_id)
                        .cloned()
                        .unwrap_or_else(|| "Unknown Character".to_string())
                },
                |location_id| display_location_name(resolver, location_id),
            );
            let visible = filter_row_indices(&rows, &state.pantry_search);
            if visible.is_empty() {
                widgets::empty_panel(ui, "No stockpile rows match the search.");
                return;
            }
            ui.label(
                egui::RichText::new(format!(
                    "{} stockpile rows across {} character(s)",
                    widgets::format_count(visible.len() as i64),
                    state.characters.len()
                ))
                .color(TOKENS.text_muted)
                .font(TOKENS.typography.small_font()),
            );
            let row_count = visible.len() as u64;
            let mut delegate = PantryDelegate {
                rows,
                visible,
                state,
                cache,
            };
            // Scale columns to the pane so narrow tiles
            // never overlap cell text (cells truncate).
            let available = ui.available_width().max(320.0);
            let unit = available / 900.0;
            Table::new()
                .id_salt("pantry_table")
                .num_rows(row_count)
                .columns(vec![
                    Column::new((280.0 * unit).max(160.0)),
                    Column::new((150.0 * unit).max(95.0)),
                    Column::new((230.0 * unit).max(130.0)),
                    Column::new((140.0 * unit).max(70.0)),
                    Column::new((100.0 * unit).max(64.0)),
                ])
                .headers(vec![HeaderRow::new(HEADER_HEIGHT)])
                .show(ui, &mut delegate);
        }
        LoadState::Loading => widgets::loading_panel(ui, "Loading stockpile..."),
        LoadState::Empty => widgets::empty_panel(ui, "No stockpile data yet."),
        LoadState::Error(message) => {
            if widgets::error_panel_with_retry(ui, &message) {
                tracing::warn!("[PANTRY] retry requested after load error");
                state.retry_requested = true;
            }
        }
    }
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
}
