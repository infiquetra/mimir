//! Wallet: balance, journal, and transactions. Item, party, and location
//! cells use resolved names, never raw IDs.

use super::widgets;
use crate::app::state::{AppState, LoadState};
use crate::names::resolver::NameResolver;

pub fn show(ui: &mut egui::Ui, state: &mut AppState, resolver: &NameResolver) {
    ui.heading("Wallet");
    if state.active_character().is_none() {
        widgets::no_character_panel(ui);
        return;
    }
    match &state.wallet {
        LoadState::Ready(w) => {
            ui.label(format!("Balance: {}", widgets::format_isk(w.balance)));
            ui.separator();
            ui.label("Journal:");
            if w.journal.is_empty() {
                ui.label("No journal entries.");
            }
            for row in &w.journal {
                let party = row
                    .second_party_id
                    .map(|id| resolver.name(id))
                    .unwrap_or_default();
                ui.label(format!(
                    "{} {} {} {}",
                    row.date,
                    row.ref_type,
                    widgets::format_isk(row.amount),
                    party
                ));
            }
            ui.separator();
            ui.label("Transactions:");
            if w.transactions.is_empty() {
                ui.label("No transactions.");
            }
            for row in &w.transactions {
                let item = resolver.name(row.type_id);
                let location = resolver.location_name(row.location_id);
                let verb = if row.is_buy { "Bought" } else { "Sold" };
                ui.label(format!(
                    "{} {} x{} at {} ({})",
                    verb,
                    item,
                    row.quantity,
                    widgets::format_isk(row.unit_price),
                    location
                ));
            }
            ui.separator();
            ui.label("Wallet analytics (30-day income/expense by ref type) lands with F3 queries.");
        }
        LoadState::Loading => widgets::loading_panel(ui, "Loading wallet..."),
        LoadState::Empty => widgets::empty_panel(ui, "No wallet data yet."),
        LoadState::Error(e) => widgets::error_panel(ui, e),
    }
}
