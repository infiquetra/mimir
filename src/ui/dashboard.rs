//! Dashboard: multi-character overview grid, combined wealth, training
//! overview with countdowns, and a wallet summary.

use std::collections::{HashMap, HashSet};

use chrono::Utc;

use super::portraits::{self, PortraitImageCache};
use super::skills;
use super::theme;
use super::wallet::compute_analytics;
use super::widgets;
use crate::app::state::{AppState, CharacterSummary, LoadState, SkillsData, View};
use crate::names::resolver::NameResolver;
use crate::names::sde::Sde;
use crate::storage::repositories::CharacterRow;

/// Derive the `(training_text, training_muted, finishes_text, finishes_muted)`
/// cells for the Dashboard character table, distinguishing unloaded skill state
/// (`"not loaded"`) from a loaded empty queue (`"idle"` / `"paused"`).
pub fn character_training_cells(
    summary: Option<&CharacterSummary>,
    active_skills: Option<&SkillsData>,
    sde: &Sde,
    now: chrono::DateTime<Utc>,
) -> (String, bool, String, bool) {
    let skills_loaded = summary.and_then(|s| s.queue_len).is_some()
        || summary
            .and_then(|s| s.training_skill_name.as_ref())
            .is_some()
        || active_skills.is_some();
    if !skills_loaded {
        return (
            "not loaded".to_string(),
            true,
            "not loaded".to_string(),
            true,
        );
    }
    let (training, finish) = if let Some(data) = active_skills {
        let item = skills::active_or_first_queue_item(&data.queue, now);
        (
            item.map(|q| sde.skill_name(q.skill_id)),
            item.and_then(|q| q.finish_date.as_deref()),
        )
    } else {
        (
            summary.and_then(|s| s.training_skill_name.clone()),
            summary.and_then(|s| s.training_finish_date.as_deref()),
        )
    };
    let (training_text, training_muted) = match training {
        Some(name) => (name, false),
        None => ("idle".to_string(), true),
    };
    (
        training_text,
        training_muted,
        widgets::countdown_label(finish, now),
        false,
    )
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum OpsTone {
    Primary,
    Accent,
    Positive,
    Warning,
    Secondary,
    Muted,
}

impl OpsTone {
    pub fn color(self) -> egui::Color32 {
        match self {
            OpsTone::Primary => theme::TEXT_PRIMARY,
            OpsTone::Accent => theme::ACCENT_CYAN,
            OpsTone::Positive => theme::POSITIVE,
            OpsTone::Warning => theme::WARNING,
            OpsTone::Secondary => theme::TEXT_SECONDARY,
            OpsTone::Muted => theme::TEXT_SECONDARY,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct OpsMetric {
    pub value: String,
    pub detail: Option<String>,
    pub tone: OpsTone,
}

impl OpsMetric {
    fn plain(value: impl Into<String>, tone: OpsTone) -> Self {
        Self {
            value: value.into(),
            detail: None,
            tone,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct OperationsSnapshot {
    pub industry: OpsMetric,
    pub planets: OpsMetric,
    pub assets: OpsMetric,
    pub fittings: OpsMetric,
}

fn format_count_noun(count: i64, singular: &str, plural: &str) -> String {
    let formatted = widgets::format_count(count);
    let noun = if count == 1 { singular } else { plural };
    format!("{formatted} {noun}")
}

/// Summarize already-loaded Industry, Planetary Industry, Assets, and Fittings
/// bundles for the active character without triggering fetches or exposing raw IDs.
pub fn operations_snapshot(state: &AppState, now: chrono::DateTime<Utc>) -> OperationsSnapshot {
    let industry = match &state.industry {
        LoadState::Loading => OpsMetric::plain("Loading...", OpsTone::Muted),
        LoadState::Empty => OpsMetric::plain("Not loaded", OpsTone::Muted),
        LoadState::Error(_) => OpsMetric::plain("Unavailable", OpsTone::Muted),
        LoadState::Ready(bundle) => {
            let detail = match &bundle.blueprints {
                Ok(bps) => Some(format_count_noun(
                    bps.blueprints.len() as i64,
                    "blueprint",
                    "blueprints",
                )),
                Err(e) if e.needs_reauthorize => Some("Blueprints need authorization".to_string()),
                Err(_) => None,
            };
            match &bundle.jobs {
                Ok(jobs_data) => {
                    let mut active = 0usize;
                    let mut ready = 0usize;
                    let mut paused = 0usize;
                    for job in &jobs_data.jobs {
                        match job.status.as_str() {
                            "active" => active = active.saturating_add(1),
                            "ready" => ready = ready.saturating_add(1),
                            "paused" => paused = paused.saturating_add(1),
                            _ => {}
                        }
                    }
                    let (value, tone) = if ready > 0 && active > 0 {
                        (format!("{active} active, {ready} ready"), OpsTone::Positive)
                    } else if ready > 0 {
                        (format!("{ready} ready to deliver"), OpsTone::Positive)
                    } else if active > 0 {
                        (
                            format_count_noun(active as i64, "active job", "active jobs"),
                            OpsTone::Accent,
                        )
                    } else if paused > 0 {
                        (
                            format_count_noun(paused as i64, "paused job", "paused jobs"),
                            OpsTone::Warning,
                        )
                    } else if !jobs_data.jobs.is_empty() {
                        (
                            format_count_noun(
                                jobs_data.jobs.len() as i64,
                                "historical job",
                                "historical jobs",
                            ),
                            OpsTone::Secondary,
                        )
                    } else {
                        ("No industry jobs".to_string(), OpsTone::Secondary)
                    };
                    OpsMetric {
                        value,
                        detail,
                        tone,
                    }
                }
                Err(e) if e.needs_reauthorize => {
                    OpsMetric::plain("Needs authorization", OpsTone::Warning)
                }
                Err(_) => OpsMetric::plain("Unavailable", OpsTone::Muted),
            }
        }
    };

    let planets = match &state.planetary {
        LoadState::Loading => OpsMetric::plain("Loading...", OpsTone::Muted),
        LoadState::Empty => OpsMetric::plain("Not loaded", OpsTone::Muted),
        LoadState::Error(_) => OpsMetric::plain("Unavailable", OpsTone::Muted),
        LoadState::Ready(bundle) => match &bundle.colonies {
            Ok(colonies) => {
                if colonies.is_empty() {
                    OpsMetric::plain("No colonies", OpsTone::Secondary)
                } else {
                    let value = format_count_noun(colonies.len() as i64, "colony", "colonies");
                    let total_pins: i64 = colonies
                        .iter()
                        .fold(0i64, |acc, c| acc.saturating_add(c.num_pins.max(0)));
                    let mut detail =
                        format!("{} total", format_count_noun(total_pins, "pin", "pins"));
                    let mut tone = OpsTone::Accent;
                    if let Some(selected) = &bundle.detail {
                        if Some(selected.selection.character_id) == state.active_character_id
                            && Some(selected.selection.planet_id)
                                == state.planetary_selected_planet_id
                        {
                            if let Ok(colony) = &selected.result {
                                if super::planets::has_active_extractor(&colony.pins, now) {
                                    detail.push_str(" — extracting");
                                    tone = OpsTone::Positive;
                                } else {
                                    detail.push_str(" — selected colony idle");
                                }
                            }
                        }
                    }
                    OpsMetric {
                        value,
                        detail: Some(detail),
                        tone,
                    }
                }
            }
            Err(e) if e.needs_reauthorize => {
                OpsMetric::plain("Needs authorization", OpsTone::Warning)
            }
            Err(_) => OpsMetric::plain("Unavailable", OpsTone::Muted),
        },
    };

    let assets = match &state.assets {
        LoadState::Loading => OpsMetric::plain("Loading...", OpsTone::Muted),
        LoadState::Empty => OpsMetric::plain("Not loaded", OpsTone::Muted),
        LoadState::Error(_) if state.assets_needs_reauthorize => {
            OpsMetric::plain("Needs authorization", OpsTone::Warning)
        }
        LoadState::Error(_) => OpsMetric::plain("Unavailable", OpsTone::Muted),
        LoadState::Ready(data) => {
            if data.items.is_empty() {
                OpsMetric::plain("No items", OpsTone::Secondary)
            } else {
                let distinct_locations: HashSet<i64> =
                    data.items.iter().map(|item| item.location_id).collect();
                OpsMetric {
                    value: format_count_noun(data.items.len() as i64, "stack", "stacks"),
                    detail: Some(format!(
                        "Across {}",
                        format_count_noun(distinct_locations.len() as i64, "location", "locations")
                    )),
                    tone: OpsTone::Primary,
                }
            }
        }
    };

    let fittings = match &state.fittings {
        LoadState::Loading => OpsMetric::plain("Loading...", OpsTone::Muted),
        LoadState::Empty => OpsMetric::plain("Not loaded", OpsTone::Muted),
        LoadState::Error(_) => OpsMetric::plain("Unavailable", OpsTone::Muted),
        LoadState::Ready(bundle) => match &bundle.fittings {
            Ok(list) => {
                if list.is_empty() {
                    OpsMetric::plain("No saved fittings", OpsTone::Secondary)
                } else {
                    OpsMetric::plain(
                        format_count_noun(list.len() as i64, "saved fitting", "saved fittings"),
                        OpsTone::Primary,
                    )
                }
            }
            Err(e) if e.needs_reauthorize => {
                OpsMetric::plain("Needs authorization", OpsTone::Warning)
            }
            Err(_) => OpsMetric::plain("Unavailable", OpsTone::Muted),
        },
    };

    OperationsSnapshot {
        industry,
        planets,
        assets,
        fittings,
    }
}

fn render_ops_tile(ui: &mut egui::Ui, label: &str, metric: &OpsMetric, button_label: &str) -> bool {
    let mut clicked = false;
    egui::Frame::new()
        .fill(theme::BG_CARD_ALT)
        .stroke(egui::Stroke::new(1.0_f32, theme::BORDER_SUBTLE))
        .corner_radius(egui::CornerRadius::same(6))
        .inner_margin(egui::Margin::symmetric(10, 8))
        .show(ui, |ui| {
            ui.set_width(ui.available_width());
            ui.label(
                egui::RichText::new(label)
                    .size(super::tokens::TOKENS.typography.small)
                    .color(theme::TEXT_SECONDARY),
            );
            ui.add_space(2.0);
            ui.label(
                widgets::numeric_text(metric.value.clone())
                    .size(super::tokens::TOKENS.typography.heading)
                    .strong()
                    .color(metric.tone.color()),
            );
            ui.add_space(1.0);
            // Keep uniform card height so quick-open buttons align across the row.
            let detail_text = metric.detail.as_deref().unwrap_or(" ");
            ui.label(
                egui::RichText::new(detail_text)
                    .size(super::tokens::TOKENS.typography.small)
                    .color(theme::TEXT_SECONDARY),
            );
            ui.add_space(6.0);
            ui.horizontal(|ui| {
                if ui.button(button_label).clicked() {
                    clicked = true;
                }
            });
        });
    clicked
}

/// Sum wallet balances across the current character roster, falling back to the
/// active character's live wallet balance if its summary is absent.
pub fn combined_wallet_balance(
    characters: &[CharacterRow],
    summaries: &HashMap<i64, CharacterSummary>,
    active_id: Option<i64>,
    active_balance: Option<f64>,
) -> Option<f64> {
    let mut combined: Option<f64> = None;
    for character in characters {
        let balance = summaries
            .get(&character.character_id)
            .and_then(|s| s.balance)
            .or(if active_id == Some(character.character_id) {
                active_balance
            } else {
                None
            });
        if let Some(value) = balance {
            combined = Some(combined.unwrap_or(0.0) + value);
        }
    }
    tracing::trace!(
        "[UI] combined_wallet_balance characters={} has_total={}",
        characters.len(),
        combined.is_some()
    );
    combined
}

pub fn show(
    ui: &mut egui::Ui,
    state: &mut AppState,
    sde: &Sde,
    resolver: &NameResolver,
    cache: &mut PortraitImageCache,
) {
    ui.heading("Dashboard");
    widgets::mode_notice(ui, state.demo, state.offline);
    // Portraits for every visible character: freed textures for
    // removed characters go first, then one fetch is queued per
    // character that has no portrait in flight or failed yet. In
    // demo mode the shell drains without spawning, so this makes
    // zero network calls and every portrait stays a placeholder.
    cache.prune(state);
    let visible_ids: Vec<i64> = state.characters.iter().map(|c| c.character_id).collect();
    for id in visible_ids {
        portraits::ensure_portrait_requested(state, id);
    }
    if state.characters.is_empty() {
        widgets::no_character_panel(ui);
        ui.horizontal(|ui| {
            if ui.button("Add character (EVE SSO)").clicked() {
                tracing::info!("[AUTH] add-character requested from dashboard");
                state.login_requested = true;
                state.switch_view(View::Characters);
            }
            if ui
                .add_enabled(!state.auth.is_busy(), egui::Button::new("Try demo"))
                .clicked()
            {
                tracing::info!("[DEMO] demo requested from dashboard");
                state.demo = true;
                crate::demo::data::seed_demo_state(state);
            }
        });
        return;
    }

    // --- Top KPI summary row ---
    let now = Utc::now();
    let active_id = state.active_character_id;
    let active_balance = state.wallet.as_ready().map(|w| w.balance);
    let combined = combined_wallet_balance(
        &state.characters,
        &state.summaries,
        active_id,
        active_balance,
    );
    let wallet_kpi_value = combined
        .or(active_balance)
        .map(widgets::format_isk)
        .unwrap_or_else(|| "Not loaded".to_string());
    let wallet_kpi_color = if combined.or(active_balance).is_some() {
        theme::ACCENT_CYAN
    } else {
        theme::TEXT_SECONDARY
    };
    let (training_kpi_value, training_kpi_color) = match &state.skills {
        LoadState::Ready(data) => {
            if let Some(next) = skills::upcoming_queue_items(&data.queue, now).first() {
                (
                    format!(
                        "{} ({})",
                        sde.skill_name(next.skill_id),
                        widgets::countdown_label(next.finish_date.as_deref(), now)
                    ),
                    theme::TEXT_PRIMARY,
                )
            } else if data.queue.is_empty() {
                ("Idle (empty queue)".to_string(), theme::TEXT_SECONDARY)
            } else {
                (
                    "All queued skills finished".to_string(),
                    theme::TEXT_SECONDARY,
                )
            }
        }
        LoadState::Loading => ("Loading...".to_string(), theme::TEXT_SECONDARY),
        _ => ("Not loaded".to_string(), theme::TEXT_SECONDARY),
    };
    let (net_kpi_value, net_kpi_color) = match &state.wallet {
        LoadState::Ready(w) => {
            let analytics = compute_analytics(&w.journal, now, Some(30), active_id, resolver);
            if analytics.counted == 0 {
                ("0.00 ISK".to_string(), theme::TEXT_SECONDARY)
            } else {
                (
                    widgets::format_isk_signed(analytics.net),
                    widgets::isk_color(analytics.net),
                )
            }
        }
        LoadState::Loading => ("Loading...".to_string(), theme::TEXT_SECONDARY),
        _ => ("Not loaded".to_string(), theme::TEXT_SECONDARY),
    };
    ui.horizontal_wrapped(|ui| {
        widgets::metric_tile(ui, "Combined Wallet", &wallet_kpi_value, wallet_kpi_color);
        widgets::metric_tile(
            ui,
            "Active Training",
            &training_kpi_value,
            training_kpi_color,
        );
        widgets::metric_tile(ui, "30-Day Net (Active)", &net_kpi_value, net_kpi_color);
    });
    ui.add_space(4.0);

    // --- Multi-character overview ---
    let rows: Vec<(i64, String, String, bool)> = state
        .characters
        .iter()
        .map(|c| {
            (
                c.character_id,
                c.name.clone(),
                resolver.name(c.corporation_id),
                Some(c.character_id) == active_id,
            )
        })
        .collect();
    let mut switch_to: Option<i64> = None;
    widgets::card(ui, |ui| {
        widgets::section_title(ui, "All characters");
        ui.add_space(4.0);
        egui::ScrollArea::horizontal()
            .id_salt("dashboard_overview_hscroll")
            .show(ui, |ui| {
                egui::Grid::new("dashboard_overview")
                    .striped(true)
                    .spacing([12.0, 8.0])
                    .show(ui, |ui| {
                        for header in [
                            "Portrait",
                            "Character",
                            "Corporation",
                            "Wallet",
                            "Training",
                            "Finishes",
                            "Queue",
                            "Location / ship",
                        ] {
                            ui.label(
                                egui::RichText::new(header)
                                    .strong()
                                    .color(theme::TEXT_SECONDARY),
                            );
                        }
                        ui.end_row();
                        for (id, name, corp, is_active) in &rows {
                            portraits::show_portrait(
                                ui,
                                cache,
                                state,
                                *id,
                                name,
                                portraits::LIST_PORTRAIT_PX,
                            );
                            let summary = state.summaries.get(id);
                            if ui
                                .selectable_label(
                                    *is_active,
                                    format!(
                                        "{}{}",
                                        name,
                                        if *is_active { " (active)" } else { "" }
                                    ),
                                )
                                .clicked()
                            {
                                switch_to = Some(*id);
                            }
                            ui.label(corp);
                            let balance = summary.and_then(|s| s.balance).or(if *is_active {
                                active_balance
                            } else {
                                None
                            });
                            match balance {
                                Some(val) => ui.colored_label(
                                    theme::TEXT_PRIMARY,
                                    widgets::numeric_text(widgets::format_isk(val)),
                                ),
                                None => ui.colored_label(theme::TEXT_SECONDARY, "not loaded"),
                            };
                            let active_skills = if *is_active {
                                state.skills.as_ready()
                            } else {
                                None
                            };
                            let (training_text, training_muted, finishes_text, finishes_muted) =
                                character_training_cells(summary, active_skills, sde, now);
                            if training_muted {
                                ui.colored_label(
                                    theme::TEXT_SECONDARY,
                                    widgets::numeric_text(training_text),
                                );
                            } else {
                                ui.label(widgets::numeric_text(training_text));
                            }
                            if finishes_muted {
                                ui.colored_label(
                                    theme::TEXT_SECONDARY,
                                    widgets::numeric_text(finishes_text),
                                );
                            } else {
                                ui.label(widgets::numeric_text(finishes_text));
                            }
                            let queue_len = summary.and_then(|s| s.queue_len).or_else(|| {
                                if *is_active {
                                    state.skills.as_ready().map(|d| d.queue.len())
                                } else {
                                    None
                                }
                            });
                            ui.label(
                                queue_len
                                    .map(|n| format!("{n}"))
                                    .unwrap_or_else(|| "not loaded".to_string()),
                            );
                            let place = match summary {
                                Some(s) => {
                                    match (s.location_name.as_deref(), s.ship_name.as_deref()) {
                                        (Some(loc), Some(ship)) => format!("{loc} / {ship}"),
                                        (Some(loc), None) => loc.to_string(),
                                        (None, Some(ship)) => ship.to_string(),
                                        (None, None) => "not loaded".to_string(),
                                    }
                                }
                                None => "not loaded".to_string(),
                            };
                            ui.label(place);
                            ui.end_row();
                        }
                    });
            });
        ui.add_space(4.0);
        match (combined, active_balance) {
            (Some(total), _) => {
                ui.label(
                    egui::RichText::new(format!(
                        "Combined wallet (loaded characters): {}",
                        widgets::format_isk(total)
                    ))
                    .color(theme::TEXT_SECONDARY),
                );
            }
            (None, Some(balance)) => {
                ui.label(format!(
                    "Active character wallet: {} (switch characters to load the rest)",
                    widgets::format_isk(balance)
                ));
            }
            (None, None) => match &state.wallet {
                LoadState::Loading => widgets::loading_panel(ui, "Loading wallet..."),
                LoadState::Empty => widgets::empty_panel(ui, "No wallet data yet."),
                LoadState::Error(e) => {
                    if widgets::error_panel_with_retry(ui, e) {
                        state.retry_requested = true;
                    }
                }
                LoadState::Ready(_) => {}
            },
        }
    });
    if let Some(id) = switch_to {
        state.set_active_character(id);
    }

    // --- Two-column cards: Training + 30-day Wallet summary ---
    let mut open_skills = false;
    let mut open_wallet = false;
    let mut retry = false;
    let skills_snap = state.skills.clone();
    let wallet_snap = state.wallet.clone();
    ui.columns(2, |cols| {
        widgets::card(&mut cols[0], |ui| {
            widgets::section_title(ui, "Training (active character)");
            ui.add_space(4.0);
            match &skills_snap {
                LoadState::Ready(data) => {
                    ui.label(format!(
                        "Total skill points: {}",
                        widgets::format_sp(data.skills.total_sp)
                    ));
                    let upcoming = skills::upcoming_queue_items(&data.queue, now);
                    if data.queue.is_empty() {
                        ui.label("Skill queue is empty.");
                    } else if upcoming.is_empty() {
                        ui.label("All queued skills have finished.");
                    } else {
                        for next in upcoming.iter().take(3) {
                            ui.label(format!(
                                "{} level {} — {}",
                                sde.skill_name(next.skill_id),
                                next.finished_level,
                                widgets::countdown_label(next.finish_date.as_deref(), now)
                            ));
                        }
                    }
                    ui.add_space(4.0);
                    ui.horizontal(|ui| {
                        if ui.button("Open Skills (key 3)").clicked() {
                            open_skills = true;
                        }
                    });
                }
                LoadState::Loading => widgets::loading_panel(ui, "Loading training..."),
                LoadState::Empty => widgets::empty_panel(ui, "No skill data yet."),
                LoadState::Error(e) => {
                    if widgets::error_panel_with_retry(ui, e) {
                        retry = true;
                    }
                }
            }
        });
        widgets::card(&mut cols[1], |ui| {
            widgets::section_title(ui, "Wallet summary (30 days, active character)");
            ui.add_space(4.0);
            match &wallet_snap {
                LoadState::Ready(w) => {
                    let analytics =
                        compute_analytics(&w.journal, now, Some(30), active_id, resolver);
                    if analytics.counted == 0 {
                        ui.label("No journal activity in the last 30 days.");
                    } else {
                        egui::Grid::new("dashboard_wallet_30d")
                            .spacing([12.0, 4.0])
                            .show(ui, |ui| {
                                ui.label("Income");
                                ui.colored_label(
                                    theme::POSITIVE,
                                    widgets::format_isk_signed(analytics.total_in),
                                );
                                ui.end_row();
                                ui.label("Expenses");
                                ui.colored_label(
                                    theme::NEGATIVE,
                                    widgets::format_isk_signed(-analytics.total_out),
                                );
                                ui.end_row();
                                ui.label("Net");
                                ui.colored_label(
                                    widgets::isk_color(analytics.net),
                                    widgets::format_isk_signed(analytics.net),
                                );
                                ui.end_row();
                            });
                    }
                    ui.add_space(4.0);
                    ui.horizontal(|ui| {
                        if ui.button("Open Wallet (key 4)").clicked() {
                            open_wallet = true;
                        }
                    });
                }
                LoadState::Loading => widgets::loading_panel(ui, "Loading wallet..."),
                LoadState::Empty => widgets::empty_panel(ui, "No wallet data yet."),
                LoadState::Error(e) => {
                    if widgets::error_panel_with_retry(ui, e) {
                        retry = true;
                    }
                }
            }
        });
    });
    if retry {
        state.retry_requested = true;
    }
    if open_skills {
        state.switch_view(View::Skills);
    }
    if open_wallet {
        state.switch_view(View::Wallet);
    }

    // --- Operations at a glance (already-loaded active character bundles) ---
    let ops = operations_snapshot(state, now);
    let mut open_ops_view: Option<View> = None;
    widgets::card(ui, |ui| {
        widgets::section_title(ui, "Operations at a glance (active character)");
        ui.add_space(6.0);
        ui.columns(4, |cols| {
            if render_ops_tile(
                &mut cols[0],
                "Industry",
                &ops.industry,
                "Open Industry (key 7)",
            ) {
                open_ops_view = Some(View::Industry);
            }
            if render_ops_tile(
                &mut cols[1],
                "Planetary Industry",
                &ops.planets,
                "Open Planets (key 8)",
            ) {
                open_ops_view = Some(View::Planets);
            }
            if render_ops_tile(&mut cols[2], "Assets", &ops.assets, "Open Assets (key 5)") {
                open_ops_view = Some(View::Assets);
            }
            if render_ops_tile(
                &mut cols[3],
                "Saved Fittings",
                &ops.fittings,
                "Open Fittings (key 9)",
            ) {
                open_ops_view = Some(View::Fittings);
            }
        });
    });
    if let Some(view) = open_ops_view {
        tracing::info!("[UI] dashboard quick-open view={}", view.label());
        state.switch_view(view);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn char_row(id: i64, name: &str) -> CharacterRow {
        CharacterRow {
            character_id: id,
            name: name.to_string(),
            corporation_id: 1000166,
            alliance_id: None,
            is_active: false,
        }
    }

    #[test]
    fn combined_wallet_ignores_orphan_summaries_and_falls_back_to_active() {
        let chars = vec![char_row(1, "Aria"), char_row(2, "Marcus")];
        let mut summaries = HashMap::new();
        summaries.insert(
            1,
            CharacterSummary {
                balance: Some(100.0),
                ..Default::default()
            },
        );
        // Orphaned summary for removed character 99 must not contribute.
        summaries.insert(
            99,
            CharacterSummary {
                balance: Some(9_999.0),
                ..Default::default()
            },
        );

        let total = combined_wallet_balance(&chars, &summaries, Some(2), Some(50.0));
        assert_eq!(total, Some(150.0));

        // If no summary or active balance exists, result is None.
        let empty = combined_wallet_balance(&chars, &HashMap::new(), Some(2), None);
        assert_eq!(empty, None);
    }

    #[test]
    fn character_training_cells_distinguishes_unloaded_empty_queue_and_active_training() {
        let sde = Sde::load_bundled().expect("bundled SDE loads");
        let now = Utc::now();

        let (tr, tr_m, fin, fin_m) = character_training_cells(None, None, &sde, now);
        assert_eq!(
            (tr.as_str(), tr_m, fin.as_str(), fin_m),
            ("not loaded", true, "not loaded", true)
        );

        let empty_summary = CharacterSummary {
            queue_len: Some(0),
            ..Default::default()
        };
        let (tr, tr_m, fin, fin_m) =
            character_training_cells(Some(&empty_summary), None, &sde, now);
        assert_eq!(
            (tr.as_str(), tr_m, fin.as_str(), fin_m),
            ("idle", true, "paused", false)
        );

        let active_summary = CharacterSummary {
            queue_len: Some(1),
            training_skill_name: Some("Gunnery".to_string()),
            training_finish_date: Some((now + chrono::Duration::hours(2)).to_rfc3339()),
            ..Default::default()
        };
        let (tr, tr_m, fin, fin_m) =
            character_training_cells(Some(&active_summary), None, &sde, now);
        assert_eq!(tr, "Gunnery");
        assert!(!tr_m);
        assert!(!fin_m);
        assert!(fin.contains('h') || fin.contains('m'));
    }

    #[test]
    fn operations_snapshot_summarizes_demo_character_without_raw_ids() {
        let mut state = AppState::new(true);
        crate::demo::data::seed_demo_state(&mut state);
        let now = widgets::parse_esi_date("2026-11-18T12:00:00Z").expect("valid date");

        let ops = operations_snapshot(&state, now);
        assert_eq!(ops.industry.value, "1 active, 1 ready");
        assert_eq!(ops.industry.detail.as_deref(), Some("4 blueprints"));
        assert_eq!(ops.industry.tone, OpsTone::Positive);

        assert_eq!(ops.planets.value, "2 colonies");
        assert_eq!(
            ops.planets.detail.as_deref(),
            Some("8 pins total — extracting")
        );
        assert_eq!(ops.planets.tone, OpsTone::Positive);

        assert_eq!(ops.assets.value, "6 stacks");
        assert_eq!(ops.assets.detail.as_deref(), Some("Across 3 locations"));
        assert_eq!(ops.assets.tone, OpsTone::Primary);

        assert_eq!(ops.fittings.value, "2 saved fittings");
        assert_eq!(ops.fittings.detail, None);
        assert_eq!(ops.fittings.tone, OpsTone::Primary);

        for metric in [&ops.industry, &ops.planets, &ops.assets, &ops.fittings] {
            for raw in ["90000001", "60003760", "700000001", "1030000000001"] {
                assert!(!metric.value.contains(raw), "raw id {raw} leaked in value");
                if let Some(detail) = &metric.detail {
                    assert!(!detail.contains(raw), "raw id {raw} leaked in detail");
                }
            }
        }
    }

    #[test]
    fn operations_snapshot_handles_loading_empty_and_reauthorize_states() {
        use crate::app::state::{FittingsData, IndustryData, PlanetaryData, SectionError};

        let now = Utc::now();
        let loading_state = AppState::new(false);
        let ops = operations_snapshot(&loading_state, now);
        assert_eq!(ops.industry.value, "Loading...");
        assert_eq!(ops.planets.value, "Loading...");
        assert_eq!(ops.assets.value, "Loading...");
        assert_eq!(ops.fittings.value, "Loading...");

        let mut empty_state = AppState::new(false);
        empty_state.industry = LoadState::Empty;
        empty_state.planetary = LoadState::Empty;
        empty_state.assets = LoadState::Empty;
        empty_state.fittings = LoadState::Empty;
        let ops = operations_snapshot(&empty_state, now);
        assert_eq!(ops.industry.value, "Not loaded");
        assert_eq!(ops.planets.value, "Not loaded");
        assert_eq!(ops.assets.value, "Not loaded");
        assert_eq!(ops.fittings.value, "Not loaded");

        let reauth = || SectionError {
            message: "forbidden".to_string(),
            needs_reauthorize: true,
        };
        let mut reauth_state = AppState::new(false);
        reauth_state.industry = LoadState::Ready(IndustryData {
            jobs: Err(reauth()),
            blueprints: Err(reauth()),
        });
        reauth_state.planetary = LoadState::Ready(PlanetaryData {
            colonies: Err(reauth()),
            detail: None,
        });
        reauth_state.assets = LoadState::Error("forbidden".to_string());
        reauth_state.assets_needs_reauthorize = true;
        reauth_state.fittings = LoadState::Ready(FittingsData {
            fittings: Err(reauth()),
        });

        let ops = operations_snapshot(&reauth_state, now);
        for metric in [&ops.industry, &ops.planets, &ops.assets, &ops.fittings] {
            assert_eq!(metric.value, "Needs authorization");
            assert_eq!(metric.tone, OpsTone::Warning);
        }
    }

    #[test]
    fn character_training_cells_prefers_live_active_skills_over_stale_summary() {
        use crate::esi::models::{CharacterSkills, SkillQueueItem};

        let sde = Sde::load_bundled().expect("bundled SDE loads");
        let now = Utc::now();
        let finished_skill_id = 3300;
        let running_skill_id = 3301;
        let stale_summary = CharacterSummary {
            queue_len: Some(2),
            training_skill_name: Some(sde.skill_name(finished_skill_id)),
            training_finish_date: Some((now - chrono::Duration::minutes(10)).to_rfc3339()),
            ..Default::default()
        };
        let active_skills = SkillsData {
            skills: CharacterSkills::default(),
            queue: vec![
                SkillQueueItem {
                    skill_id: finished_skill_id,
                    finished_level: 5,
                    queue_position: 0,
                    finish_date: Some((now - chrono::Duration::minutes(10)).to_rfc3339()),
                    ..Default::default()
                },
                SkillQueueItem {
                    skill_id: running_skill_id,
                    finished_level: 4,
                    queue_position: 1,
                    finish_date: Some((now + chrono::Duration::hours(3)).to_rfc3339()),
                    ..Default::default()
                },
            ],
        };

        let (training, tr_muted, finish, fin_muted) =
            character_training_cells(Some(&stale_summary), Some(&active_skills), &sde, now);
        assert_eq!(training, sde.skill_name(running_skill_id));
        assert!(!tr_muted);
        assert!(!fin_muted);
        assert!(finish.starts_with("in "));
        assert_ne!(finish, "finished");
    }

    #[test]
    fn operations_snapshot_ignores_planetary_detail_for_other_selected_planet() {
        let mut state = AppState::new(true);
        crate::demo::data::seed_demo_state(&mut state);
        let now = widgets::parse_esi_date("2026-11-18T12:00:00Z").expect("valid date");

        // Switch selection away from 700000001 while bundle.detail is still stamped for 700000001.
        state.set_planetary_selection(700000002);
        let ops = operations_snapshot(&state, now);
        assert_eq!(ops.planets.value, "2 colonies");
        assert_eq!(ops.planets.detail.as_deref(), Some("8 pins total"));
        assert_eq!(ops.planets.tone, OpsTone::Accent);
    }
}
