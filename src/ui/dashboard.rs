//! Dashboard: multi-character overview grid, combined wealth, training
//! overview with countdowns, and a wallet summary.

use std::collections::HashMap;

use chrono::Utc;

use super::portraits::{self, PortraitImageCache};
use super::skills;
use super::wallet::compute_analytics;
use super::widgets;
use crate::app::state::{AppState, CharacterSummary, LoadState, View};
use crate::names::resolver::NameResolver;
use crate::names::sde::Sde;
use crate::storage::repositories::CharacterRow;

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
    tracing::debug!(
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
            if ui.button("Try demo").clicked() {
                tracing::info!("[DEMO] demo requested from dashboard");
                state.demo = true;
                crate::demo::data::seed_demo_state(state);
            }
        });
        return;
    }

    // --- Multi-character overview (improvement over Flutter) ---
    // Per-character wallet/training cells come from `state.summaries`
    // (integrator-filled); the active character also falls back to the
    // loaded skills/wallet bundles. Missing cells say "not loaded".
    ui.heading("All characters");
    let now = Utc::now();
    let active_id = state.active_character_id;
    let active_balance = state.wallet.as_ready().map(|w| w.balance);
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
    egui::Grid::new("dashboard_overview")
        .striped(true)
        .show(ui, |ui| {
            ui.label("Portrait");
            ui.label("Character (click to switch)");
            ui.label("Corporation");
            ui.label("Wallet");
            ui.label("Training");
            ui.label("Finishes");
            ui.label("Queue");
            ui.label("Location / ship");
            ui.end_row();
            for (id, name, corp, is_active) in &rows {
                portraits::show_portrait(ui, cache, state, *id, name, portraits::LIST_PORTRAIT_PX);
                let summary = state.summaries.get(id);
                if ui
                    .selectable_label(
                        *is_active,
                        format!("{}{}", name, if *is_active { " (active)" } else { "" }),
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
                ui.label(
                    balance
                        .map(widgets::format_isk)
                        .unwrap_or_else(|| "not loaded".to_string()),
                );
                let active_training = if *is_active {
                    state
                        .skills
                        .as_ready()
                        .and_then(|d| skills::active_or_first_queue_item(&d.queue, now))
                } else {
                    None
                };
                let training = summary
                    .and_then(|s| s.training_skill_name.clone())
                    .or_else(|| active_training.map(|q| sde.skill_name(q.skill_id)));
                ui.label(training.unwrap_or_else(|| "not loaded".to_string()));
                let finish = summary
                    .and_then(|s| s.training_finish_date.as_deref())
                    .or_else(|| active_training.and_then(|q| q.finish_date.as_deref()));
                ui.label(widgets::countdown_label(finish, now));
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
                    Some(s) => match (s.location_name.as_deref(), s.ship_name.as_deref()) {
                        (Some(loc), Some(ship)) => format!("{loc} / {ship}"),
                        (Some(loc), None) => loc.to_string(),
                        (None, Some(ship)) => ship.to_string(),
                        (None, None) => "not loaded".to_string(),
                    },
                    None => "not loaded".to_string(),
                };
                ui.label(place);
                ui.end_row();
            }
        });
    if let Some(id) = switch_to {
        state.set_active_character(id);
    }

    // --- Combined wealth (only loaded balances across active roster are summed) ---
    let combined = combined_wallet_balance(
        &state.characters,
        &state.summaries,
        active_id,
        active_balance,
    );
    ui.separator();
    match (combined, active_balance) {
        (Some(total), _) => {
            ui.label(format!(
                "Combined wallet (loaded characters): {}",
                widgets::format_isk(total)
            ));
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

    // --- Training overview + next skills finishing ---
    ui.separator();
    ui.heading("Training (active character)");
    match &state.skills {
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
            if ui.button("Open Skills (key 3)").clicked() {
                state.switch_view(View::Skills);
            }
        }
        LoadState::Loading => widgets::loading_panel(ui, "Loading training..."),
        LoadState::Empty => widgets::empty_panel(ui, "No skill data yet."),
        LoadState::Error(e) => {
            if widgets::error_panel_with_retry(ui, e) {
                state.retry_requested = true;
            }
        }
    }

    // --- Wallet trend summary (30-day income/expense/net) ---
    ui.separator();
    ui.heading("Wallet summary (30 days, active character)");
    match &state.wallet {
        LoadState::Ready(w) => {
            let analytics = compute_analytics(&w.journal, now, Some(30), active_id, resolver);
            if analytics.counted == 0 {
                ui.label("No journal activity in the last 30 days.");
            } else {
                ui.label(format!(
                    "Income {} | Expenses {} | Net {}",
                    widgets::format_isk_signed(analytics.total_in),
                    widgets::format_isk_signed(-analytics.total_out),
                    widgets::format_isk_signed(analytics.net)
                ));
            }
            if ui.button("Open Wallet (key 4)").clicked() {
                state.switch_view(View::Wallet);
            }
        }
        LoadState::Loading => widgets::loading_panel(ui, "Loading wallet..."),
        LoadState::Empty => widgets::empty_panel(ui, "No wallet data yet."),
        LoadState::Error(e) => {
            if widgets::error_panel_with_retry(ui, e) {
                state.retry_requested = true;
            }
        }
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
}
