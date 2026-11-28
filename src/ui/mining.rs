//! Live Mining & Residue HUD (card #648, repaired). Visual-first:
//! yield arc gauges, residue bars, ore-hold countdown, and Survey
//! Scanner belt valuation. The view sets request flags only; it
//! never fetches. Every rendered type is a resolved name, never a
//! raw numeric id. Rates are measured from real mining-event
//! timestamps through `state.now_utc()`-stamped session starts;
//! prices are per mined ore type from cached hub quotes only.

use std::collections::HashMap;

use super::tokens::TOKENS;
use super::widgets;
use crate::app::state::{AppState, LoadState, StepUpRequest};
use crate::config::EveConfig;
use crate::fitting::dogma_catalogue::DogmaCatalogue;
use crate::mining::ledger::{
    compressed_price_per_m3, fleet_totals_from_log_events, hold_capacity_for_ship, hold_countdown,
    m3_per_hour, price_per_m3_from_unit, session_elapsed_secs, session_totals_for_listener,
    value_session_by_ore, HoldCountdown,
};
use crate::mining::survey_scanner::{
    crystal_profile_from_dogma, finite_belt_comparison, parse_survey_scan, survey_text_cache_key,
};
use crate::names::fitting_types::{FittingTypes, NameLookup};
use crate::names::resolver::NameResolver;

fn mono(text: impl Into<String>) -> egui::RichText {
    egui::RichText::new(text.into())
        .font(TOKENS.typography.mono_font())
        .color(TOKENS.text_primary)
}

fn small(text: impl Into<String>) -> egui::RichText {
    egui::RichText::new(text.into())
        .font(TOKENS.typography.small_font())
        .color(TOKENS.text_muted)
}

/// One gauge as a vertical group: its label sits directly over its
/// own arc, so a wrapped layout can never orphan a label (#648 P2-3).
fn draw_arc_gauge(
    ui: &mut egui::Ui,
    label: &str,
    fraction: f64,
    color: egui::Color32,
    value: &str,
) {
    ui.vertical(|ui| {
        ui.label(
            egui::RichText::new(label)
                .font(TOKENS.typography.small_font())
                .color(TOKENS.text_muted),
        );
        let size = egui::vec2(TOKENS.gauge_size, TOKENS.gauge_size);
        let (response, painter) = ui.allocate_painter(size, egui::Sense::hover());
        let center = response.rect.center();
        let radius = TOKENS.gauge_radius;
        painter.circle_stroke(
            center,
            radius,
            egui::Stroke::new(TOKENS.gauge_stroke, TOKENS.bg_hover),
        );
        let frac = fraction.clamp(0.0, 1.0) as f32;
        if frac > 0.0 {
            let mut points = Vec::new();
            let steps = TOKENS.gauge_steps;
            for i in 0..=steps {
                let t = i as f32 / steps as f32;
                let angle = std::f32::consts::FRAC_PI_2 + t * frac * std::f32::consts::TAU;
                points.push(center + egui::vec2(radius * angle.cos(), -radius * angle.sin()));
            }
            painter.add(egui::Shape::line(
                points,
                egui::Stroke::new(TOKENS.gauge_stroke, color),
            ));
        }
        painter.text(
            center,
            egui::Align2::CENTER_CENTER,
            value,
            TOKENS.typography.mono_font(),
            TOKENS.text_primary,
        );
        response.on_hover_text(label);
    });
}

fn draw_bar(ui: &mut egui::Ui, label: &str, fraction: f64, color: egui::Color32) {
    ui.label(
        egui::RichText::new(format!("{label} {:.1}%", fraction.clamp(0.0, 1.0) * 100.0))
            .font(TOKENS.typography.small_font())
            .color(TOKENS.text_muted),
    );
    let width = ui.available_width().max(TOKENS.bar_min_width);
    let (response, painter) =
        ui.allocate_painter(egui::vec2(width, TOKENS.bar_height), egui::Sense::hover());
    painter.rect_filled(response.rect, TOKENS.radius_control, TOKENS.bg_hover);
    let mut fill = response.rect;
    fill.set_width(fill.width() * fraction.clamp(0.0, 1.0) as f32);
    painter.rect_filled(fill, TOKENS.radius_control, color);
}

fn ore_volume(fitting_types: Option<&FittingTypes>, ore_name: &str) -> Option<f64> {
    let types = fitting_types?;
    match types.lookup(ore_name) {
        NameLookup::Found(row) => row.volume.filter(|v| *v > 0.0),
        _ => None,
    }
}

/// Cached per-unit hub quotes for the ores actually in play. The
/// market history covers only its selected type, so it contributes
/// only when that selected type IS one of these ores — an unrelated
/// item's price is never applied to mined ore.
fn cached_ore_prices(state: &AppState, ore_names: &[String]) -> HashMap<String, f64> {
    let mut prices = state.mining_ore_price_per_unit.clone();
    if let Some(data) = state.market.as_ready() {
        if let Some(selected) = state.market_selected_type_name.as_deref() {
            if ore_names.iter().any(|name| name == selected) {
                if let Some(price) = data
                    .history
                    .as_ref()
                    .ok()
                    .and_then(|h| h.iter().rev().find(|e| e.average > 0.0))
                    .map(|e| e.average)
                {
                    prices.insert(selected.to_string(), price);
                }
            }
        }
    }
    prices
}

pub fn show(
    ui: &mut egui::Ui,
    state: &mut AppState,
    resolver: &NameResolver,
    fitting_types: Option<&FittingTypes>,
    dogma: Option<&DogmaCatalogue>,
) {
    ui.label(
        egui::RichText::new("Mining")
            .font(TOKENS.typography.heading_font())
            .color(TOKENS.text_primary),
    );
    tracing::debug!("[MINING] mining view render demo={}", state.demo);

    let volume_of = |name: &str| ore_volume(fitting_types, name);
    let listener = state.active_character().map(|c| c.name.clone());
    let session =
        session_totals_for_listener(&state.recent_log_events, listener.as_deref(), &volume_of);
    let elapsed_secs = session_elapsed_secs(
        &state.recent_log_events,
        listener.as_deref(),
        state.mining_session_started_unix,
    );
    let measured_rate = elapsed_secs
        .map(|elapsed| m3_per_hour(session.yield_m3, elapsed))
        .filter(|rate| *rate > 0.0);
    let yield_fraction = if session.total_m3() > 0.0 {
        session.yield_m3 / session.total_m3()
    } else {
        0.0
    };

    // Survey parse is cached on (hash, len) of the paste; it is
    // reparsed only when the text actually changes.
    let cache_key = survey_text_cache_key(&state.mining_survey_text);
    if state.mining_survey_cache_key != Some(cache_key) {
        state.mining_survey_cached = parse_survey_scan(&state.mining_survey_text);
        state.mining_survey_cache_key = Some(cache_key);
        tracing::debug!(
            "[MINING] survey reparsed rows={}",
            state.mining_survey_cached.rows.len()
        );
    }
    let parsed = state.mining_survey_cached.clone();

    let mut ore_names: Vec<String> = session.by_ore.iter().map(|o| o.ore_name.clone()).collect();
    for row in &parsed.rows {
        if !ore_names.contains(&row.ore_name) {
            ore_names.push(row.ore_name.clone());
        }
    }
    let per_unit_prices = cached_ore_prices(state, &ore_names);
    // Per-m3 prices: raw type price / SDE volume, else the compressed
    // type's price over its 100-unit raw volume equivalent.
    let mut per_m3_prices: HashMap<String, f64> = HashMap::new();
    for ore in &session.by_ore {
        let volume = ore_volume(fitting_types, &ore.ore_name);
        if let (Some(price), Some(volume)) = (per_unit_prices.get(&ore.ore_name), volume) {
            if let Some(per_m3) = price_per_m3_from_unit(*price, volume) {
                per_m3_prices.insert(ore.ore_name.clone(), per_m3);
                continue;
            }
        }
        let compressed_name = format!("Compressed {}", ore.ore_name);
        if let (Some(price), Some(volume)) = (per_unit_prices.get(&compressed_name), volume) {
            if let Some(per_m3) = compressed_price_per_m3(*price, volume, 100) {
                per_m3_prices.insert(ore.ore_name.clone(), per_m3);
            }
        }
    }
    let valuation = value_session_by_ore(&session, &per_m3_prices);

    widgets::card(ui, |ui| {
        widgets::section_title(ui, "Live session");
        ui.horizontal_wrapped(|ui| {
            draw_arc_gauge(
                ui,
                "Yield share",
                yield_fraction,
                TOKENS.cyan_telemetry,
                &format!("{:.0} m³", session.yield_m3),
            );
            draw_arc_gauge(
                ui,
                "Residue share",
                session.residue_ratio(),
                TOKENS.warning,
                &format!("{:.1}%", session.residue_ratio() * 100.0),
            );
            ui.vertical(|ui| {
                ui.label(mono(format!("Yield {:.1} m³", session.yield_m3)));
                ui.label(mono(format!("Residue {:.1} m³", session.residue_m3)));
                ui.label(mono(format!("Samples {}", session.samples)));
                if session.skipped_unknown_ore > 0 {
                    ui.label(small(format!(
                        "Skipped {} unknown ore lines",
                        session.skipped_unknown_ore
                    )));
                }
            });
        });
        draw_bar(ui, "Residue", session.residue_ratio(), TOKENS.warning);
        if session.yield_m3 <= 0.0 {
            ui.label("No mining yield this session yet.");
        } else {
            match measured_rate {
                Some(rate) => {
                    ui.label(mono(format!("{rate:.1} m³/hr")));
                }
                None => {
                    ui.label(mono("Rate not observed yet"));
                }
            }
            if valuation.priced_isk > 0.0 {
                ui.label(mono(widgets::format_isk(valuation.priced_isk)));
                if let Some(elapsed) = elapsed_secs {
                    if let Some(per_hour) = valuation.isk_per_hour(elapsed) {
                        ui.label(mono(format!("{} / hr", widgets::format_isk(per_hour))));
                    }
                }
                if valuation.unpriced_yield_m3 > 0.0 {
                    widgets::badge(ui, "Awaiting Hub Quote", TOKENS.warning_bg, TOKENS.warning);
                    ui.label(small(format!(
                        "Unpriced {:.1} m³ awaiting hub quote",
                        valuation.unpriced_yield_m3
                    )));
                }
            } else {
                widgets::badge(ui, "Awaiting Hub Quote", TOKENS.warning_bg, TOKENS.warning);
            }
        }
        // Multi-box summary: fleet totals across listeners, shown
        // only when more than one character is mining.
        let fleet = fleet_totals_from_log_events(&state.recent_log_events, &volume_of);
        if fleet.len() > 1 {
            let fleet_total = crate::mining::ledger::fleet_totals(&fleet);
            ui.label(small(format!(
                "Fleet ({} characters): {:.1} m³ yield, {:.1} m³ residue",
                fleet.len(),
                fleet_total.yield_m3,
                fleet_total.residue_m3
            )));
        }
    });

    // Ore-hold countdown from the active ship's SDE hold attributes.
    let ship_type_id = state
        .character_details
        .as_ready()
        .and_then(|d| d.ship.as_ref().ok())
        .map(|s| s.ship_type_id);
    let capacity = dogma.and_then(|d| hold_capacity_for_ship(d, ship_type_id));
    widgets::card(ui, |ui| {
        widgets::section_title(ui, "Ore hold");
        if dogma.is_none() {
            ui.label(mono("Ship catalogue loading…"));
        }
        match hold_countdown(capacity, session.yield_m3, measured_rate.unwrap_or(0.0)) {
            HoldCountdown::CapacityUnknown => {
                if dogma.is_some() {
                    widgets::badge(ui, "Capacity Unknown", TOKENS.warning_bg, TOKENS.warning);
                }
            }
            HoldCountdown::Known {
                fill_fraction,
                remaining_secs,
                ..
            } => {
                draw_bar(
                    ui,
                    "Mined this session (SDE base hold)",
                    fill_fraction,
                    TOKENS.cyan_telemetry,
                );
                ui.label(small("Base SDE capacity; skill bonuses excluded"));
                match remaining_secs {
                    Some(secs) => {
                        ui.label(mono(widgets::format_countdown(secs as i64)));
                    }
                    None => {
                        ui.label(mono("Fill rate not observed yet"));
                    }
                }
            }
        }
    });

    widgets::card(ui, |ui| {
        widgets::section_title(ui, "Mining ledger");
        if state.demo {
            ui.label("Demo mode: mining ledger uses session log events only (no network).");
        } else if state.active_character_id.is_none() {
            widgets::no_character_panel(ui);
        } else if state.mining_needs_reauthorize
            || matches!(&state.mining, LoadState::Ready(d) if d.needs_mining_stepup())
        {
            ui.label("Mining history needs one more EVE permission.");
            if ui.button("Re-authorize mining").clicked() {
                if let Some(id) = state.active_character_id {
                    tracing::info!("[MINING] mining step-up requested character_id={}", id);
                    state.stepup_requested = Some(StepUpRequest::new(id, EveConfig::MINING_SCOPES));
                }
            }
        } else {
            if ui.button("Load mining ledger").clicked() {
                tracing::info!("[MINING] mining ledger fetch requested");
                state.mining_fetch_requested = true;
            }
            match &state.mining {
                LoadState::Loading => widgets::loading_panel(ui, "Mining ledger"),
                LoadState::Empty => widgets::empty_panel(ui, "No mining ledger loaded yet."),
                LoadState::Error(message) => {
                    widgets::error_panel(ui, message);
                }
                LoadState::Ready(data) => {
                    if data.entries.is_empty() {
                        widgets::empty_panel(ui, "No mining history for this character.");
                    }
                    for entry in &data.entries {
                        let ore_name = resolver.name(entry.type_id);
                        let volume = fitting_types
                            .and_then(|t| t.lookup_by_id(entry.type_id))
                            .and_then(|row| row.volume)
                            .map(|v| v * entry.quantity.max(0) as f64);
                        ui.horizontal(|ui| {
                            ui.label(ore_name);
                            ui.label(mono(format!("{}", entry.quantity.max(0))));
                            if let Some(volume) = volume {
                                ui.label(mono(format!("{volume:.1} m³")));
                            }
                            ui.label(
                                egui::RichText::new(widgets::format_date_short(&entry.date))
                                    .font(TOKENS.typography.small_font())
                                    .color(TOKENS.text_muted),
                            );
                        });
                    }
                }
            }
        }
    });

    widgets::card(ui, |ui| {
        widgets::section_title(ui, "Survey Scanner");
        let label = ui.label("Paste a Survey Scanner result (tab-separated):");
        let response = ui
            .add(
                egui::TextEdit::multiline(&mut state.mining_survey_text)
                    .desired_rows(4)
                    .font(TOKENS.typography.mono_font()),
            )
            .labelled_by(label.id);
        state.text_input_focused |= response.has_focus();
        if let Some(rejection) = &parsed.rejection {
            ui.label(
                egui::RichText::new(rejection.clone())
                    .font(TOKENS.typography.small_font())
                    .color(TOKENS.warning),
            );
        } else if parsed.rows.is_empty() {
            ui.label("No survey rows parsed yet.");
        } else {
            ui.label(mono(format!(
                "Rocks {}  Volume {:.1} m³  Skipped {}",
                parsed.rows.len(),
                parsed.total_volume_m3(),
                parsed.skipped_rows
            )));
            for row in &parsed.rows {
                ui.horizontal(|ui| {
                    ui.label(&row.ore_name);
                    ui.label(mono(format!("{}", row.quantity.max(0))));
                    ui.label(mono(format!("{:.1} m³", row.volume_m3)));
                    ui.label(mono(format!("{:.1} km", row.distance_km)));
                });
            }
            let belt = parsed.valuation(&per_unit_prices);
            match belt.remaining_isk {
                Some(isk) => {
                    ui.label(mono(format!("Remaining belt {}", widgets::format_isk(isk))));
                }
                None => {
                    widgets::badge(ui, "Awaiting Hub Quote", TOKENS.warning_bg, TOKENS.warning);
                    if belt.priced_isk > 0.0 {
                        ui.label(mono(format!(
                            "Priced subtotal {}",
                            widgets::format_isk(belt.priced_isk)
                        )));
                    }
                }
            }
            // Crystal comparison: only from a real A/B crystal pair
            // found in saved fittings, profiles through Dogma and
            // weighed against this finite belt. Otherwise honest gap.
            let crystal_pair = find_crystal_pair(state, resolver);
            let comparison = match (crystal_pair, dogma, measured_rate, elapsed_secs) {
                (Some((a_id, b_id)), Some(dogma), Some(_), Some(elapsed)) => {
                    let gross_rate = m3_per_hour(session.total_m3(), elapsed);
                    match (
                        crystal_profile_from_dogma(dogma, a_id, gross_rate),
                        crystal_profile_from_dogma(dogma, b_id, gross_rate),
                    ) {
                        (Some(a), Some(b)) => Some(finite_belt_comparison(
                            a,
                            b,
                            parsed.total_volume_m3(),
                            belt.remaining_isk
                                .map(|isk| isk / parsed.total_volume_m3().max(1e-9)),
                        )),
                        _ => None,
                    }
                }
                _ => None,
            };
            match comparison {
                Some(cmp) => {
                    ui.label(format!(
                        "Crystal recommendation: {}",
                        cmp.comparison.recommended.label()
                    ));
                    ui.label(mono(format!(
                        "Type A kept {:.0} m³/hr  Type B kept {:.0} m³/hr",
                        cmp.comparison.type_a_kept_m3_per_hour,
                        cmp.comparison.type_b_kept_m3_per_hour
                    )));
                    ui.label(mono(format!(
                        "Belt recoverable: Type A {:.0} m³  Type B {:.0} m³",
                        cmp.type_a_recoverable_m3, cmp.type_b_recoverable_m3
                    )));
                }
                None => {
                    ui.label(mono("Comparison needs crystal/survey data"));
                }
            }
        }
    });
}

/// Find a Type A / Type B mining-crystal pair of one family among
/// saved fittings, by resolved name. `None` when no pair is known.
fn find_crystal_pair(state: &AppState, resolver: &NameResolver) -> Option<(i64, i64)> {
    let data = state.fittings.as_ready()?;
    let fittings = data.fittings.as_ref().ok()?;
    let mut type_a: Option<(String, i64)> = None;
    let mut type_b: Option<(String, i64)> = None;
    for fitting in fittings {
        for item in &fitting.items {
            let name = resolver.name(item.type_id);
            if let Some(at) = name.find("Mining Crystal Type A") {
                type_a = Some((name[..at].trim().to_string(), item.type_id));
            } else if let Some(at) = name.find("Mining Crystal Type B") {
                type_b = Some((name[..at].trim().to_string(), item.type_id));
            }
        }
    }
    match (type_a, type_b) {
        (Some((family_a, a)), Some((family_b, b))) if family_a == family_b => Some((a, b)),
        _ => None,
    }
}
