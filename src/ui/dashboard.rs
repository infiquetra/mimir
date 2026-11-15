//! Dashboard: multi-character overview, wealth, training, wallet trend.

use super::widgets;
use crate::app::state::{AppState, LoadState};
use crate::names::resolver::NameResolver;
use crate::names::sde::Sde;

pub fn show(ui: &mut egui::Ui, state: &mut AppState, sde: &Sde, _resolver: &NameResolver) {
    ui.heading("Dashboard");
    if state.characters.is_empty() {
        widgets::no_character_panel(ui);
        return;
    }
    ui.label("Multi-character overview (wallet, training, queue, location).");
    for c in &state.characters {
        ui.label(format!(
            "{} — {}",
            c.name,
            if c.is_active { "active" } else { "" }
        ));
    }
    ui.separator();
    match &state.skills {
        LoadState::Ready(data) => {
            ui.label(format!("Total skill points: {}", data.skills.total_sp));
            if let Some(next) = data.queue.first() {
                let name = sde.skill_name(next.skill_id);
                ui.label(format!(
                    "Next skill finishing: {} level {}",
                    name, next.finished_level
                ));
            } else {
                ui.label("Skill queue is empty.");
            }
        }
        LoadState::Loading => widgets::loading_panel(ui, "Loading training..."),
        LoadState::Empty => widgets::empty_panel(ui, "No skill data yet."),
        LoadState::Error(e) => widgets::error_panel(ui, e),
    }
    ui.separator();
    match &state.wallet {
        LoadState::Ready(w) => {
            ui.label(format!(
                "Combined wallet: {}",
                widgets::format_isk(w.balance)
            ));
        }
        LoadState::Loading => widgets::loading_panel(ui, "Loading wallet..."),
        LoadState::Empty => widgets::empty_panel(ui, "No wallet data yet."),
        LoadState::Error(e) => widgets::error_panel(ui, e),
    }
}
