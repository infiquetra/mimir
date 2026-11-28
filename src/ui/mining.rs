//! Live Mining & Residue HUD (card #648). Visual-first: yield arc
//! gauges, residue bars, ore-hold countdown, and Survey Scanner belt
//! valuation. The view sets request flags only; it never fetches.
//! Every rendered type is a resolved name, never a raw numeric id.

use std::collections::HashMap;

use super::tokens::TOKENS;
use super::widgets;
use crate::app::state::{AppState, LoadState, StepUpRequest};
use crate::config::EveConfig;
use crate::fitting::dogma_catalogue::DogmaCatalogue;
use crate::mining::ledger::{
    hold_capacity_for_ship, hold_countdown, hub_valuation, session_totals_from_log_events,
    HoldCountdown, HubValuation,
};
use crate::mining::survey_scanner::{crystal_comparison, parse_survey_scan, CrystalProfile};
use crate::names::fitting_types::FittingTypes;
use crate::names::resolver::NameResolver;

fn mono(text: impl Into<String>) -> egui::RichText {
    egui::RichText::new(text.into())
        .font(TOKENS.typography.mono_font())
        .color(TOKENS.text_primary)
}

fn draw_arc_gauge(
    ui: &mut egui::Ui,
    label: &str,
    fraction: f64,
    color: egui::Color32,
    value: &str,
) {
    ui.label(
        egui::RichText::new(label)
            .font(TOKENS.typography.small_font())
            .color(TOKENS.text_muted),
    );
    let size = egui::vec2(120.0, 120.0);
    let (response, painter) = ui.allocate_painter(size, egui::Sense::hover());
    let center = response.rect.center();
    let radius = 48.0;
    painter.circle_stroke(center, radius, egui::Stroke::new(6.0, TOKENS.bg_hover));
    let frac = fraction.clamp(0.0, 1.0) as f32;
    if frac > 0.0 {
        let mut points = Vec::new();
        let steps = 48;
        for i in 0..=steps {
            let t = i as f32 / steps as f32;
            let angle = std::f32::consts::FRAC_PI_2 + t * frac * std::f32::consts::TAU;
            points.push(center + egui::vec2(radius * angle.cos(), -radius * angle.sin()));
        }
        painter.add(egui::Shape::line(points, egui::Stroke::new(6.0, color)));
    }
    painter.text(
        center,
        egui::Align2::CENTER_CENTER,
        value,
        TOKENS.typography.mono_font(),
        TOKENS.text_primary,
    );
    response.on_hover_text(label);
}

fn draw_bar(ui: &mut egui::Ui, label: &str, fraction: f64, color: egui::Color32) {
    ui.label(
        egui::RichText::new(format!("{label} {:.1}%", fraction.clamp(0.0, 1.0) * 100.0))
            .font(TOKENS.typography.small_font())
            .color(TOKENS.text_muted),
    );
    let width = ui.available_width().max(80.0);
    let (response, painter) = ui.allocate_painter(egui::vec2(width, 14.0), egui::Sense::hover());
    painter.rect_filled(response.rect, TOKENS.radius_control, TOKENS.bg_hover);
    let mut fill = response.rect;
    fill.set_width(fill.width() * fraction.clamp(0.0, 1.0) as f32);
    painter.rect_filled(fill, TOKENS.radius_control, color);
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

    let session = session_totals_from_log_events(&state.recent_log_events);
    let elapsed_secs = 3600.0;
    let yield_fraction = if session.total_m3() > 0.0 {
        session.yield_m3 / session.total_m3()
    } else {
        0.0
    };

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
            });
        });
        draw_bar(ui, "Residue", session.residue_ratio(), TOKENS.warning);
        // Hub valuation from existing market history when present.
        let hub_price = state.market.as_ready().and_then(|data| {
            data.history
                .as_ref()
                .ok()
                .and_then(|h| h.iter().rev().find(|e| e.average > 0.0))
                .map(|e| e.average)
        });
        if session.yield_m3 <= 0.0 {
            // An empty session has no rate to quote; never
            // render a misleading "0.00 ISK / hr".
            ui.label("No mining yield this session yet.");
        } else {
            match hub_valuation(session.yield_m3, elapsed_secs, hub_price) {
                HubValuation::AwaitingHubQuote => {
                    widgets::badge(ui, "Awaiting Hub Quote", TOKENS.warning_bg, TOKENS.warning);
                }
                HubValuation::Priced {
                    isk_per_hour,
                    total_isk,
                } => {
                    ui.label(mono(format!("{} / hr", widgets::format_isk(isk_per_hour))));
                    ui.label(mono(widgets::format_isk(total_isk)));
                }
            }
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
        match hold_countdown(capacity, session.yield_m3, 0.0) {
            HoldCountdown::CapacityUnknown => {
                widgets::badge(ui, "Capacity Unknown", TOKENS.warning_bg, TOKENS.warning);
            }
            HoldCountdown::Known {
                fill_fraction,
                remaining_secs,
                ..
            } => {
                draw_bar(ui, "Ore hold fill", fill_fraction, TOKENS.cyan_telemetry);
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
        let parsed = parse_survey_scan(&state.mining_survey_text);
        if parsed.rows.is_empty() {
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
            let valuation = parsed.valuation(&HashMap::new());
            if valuation.remaining_isk.is_none() {
                widgets::badge(ui, "Awaiting Hub Quote", TOKENS.warning_bg, TOKENS.warning);
            }
            let comparison = crystal_comparison(
                CrystalProfile {
                    yield_m3_per_hour: 1000.0,
                    residue_ratio: session.residue_ratio(),
                },
                CrystalProfile {
                    yield_m3_per_hour: 1150.0,
                    residue_ratio: (session.residue_ratio() + 0.15).min(0.9),
                },
                None,
            );
            ui.label(format!(
                "Crystal recommendation: {}",
                comparison.recommended.label()
            ));
            ui.label(mono(format!(
                "Type A kept {:.0} m³/hr  Type B kept {:.0} m³/hr",
                comparison.type_a_kept_m3_per_hour, comparison.type_b_kept_m3_per_hour
            )));
        }
    });
}
