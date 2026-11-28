//! Wallet: balance, analytics summary, journal, and transactions. Item,
//! party, and location cells use resolved names, never raw IDs.

use std::collections::BTreeMap;

use chrono::{DateTime, Utc};

use super::theme;
use super::widgets;
use crate::app::state::{AppState, LoadState, View, WalletPeriod};
use crate::esi::models::WalletJournalItem;
use crate::names::resolver::NameResolver;

/// Income/expense totals, per-ref-type nets, and top counterparties for a
/// journal window. Counterparty names are resolved before they reach here.
#[derive(Debug, Clone, Default, PartialEq)]
pub struct WalletAnalytics {
    pub total_in: f64,
    pub total_out: f64,
    pub net: f64,
    pub counted: usize,
    pub by_ref_type: Vec<(String, f64)>,
    pub top_counterparties: Vec<(String, f64)>,
}

fn within_window(date: &str, now: DateTime<Utc>, days: Option<i64>) -> bool {
    match days {
        None => true,
        Some(days) => match widgets::parse_esi_date(date) {
            Some(parsed) => {
                (now - parsed).num_days() <= days && parsed <= now + chrono::TimeDelta::days(1)
            }
            // Unparseable rows stay visible rather than silently vanishing.
            None => true,
        },
    }
}

/// Resolve the other party of a wallet journal row, preferring whichever of
/// `second_party_id` / `first_party_id` differs from the active character.
pub fn journal_counterparty_id(
    row: &WalletJournalItem,
    self_character_id: Option<i64>,
) -> Option<i64> {
    [row.second_party_id, row.first_party_id]
        .into_iter()
        .flatten()
        .find(|id| Some(*id) != self_character_id)
        .or_else(|| row.second_party_id.or(row.first_party_id))
}

/// Pure analytics over journal rows. Non-finite amounts are skipped.
pub fn compute_analytics(
    journal: &[WalletJournalItem],
    now: DateTime<Utc>,
    days: Option<i64>,
    self_character_id: Option<i64>,
    resolver: &NameResolver,
) -> WalletAnalytics {
    let mut analytics = WalletAnalytics::default();
    let mut ref_totals: BTreeMap<String, f64> = BTreeMap::new();
    let mut party_totals: BTreeMap<String, f64> = BTreeMap::new();
    for row in journal {
        if !row.amount.is_finite() || !within_window(&row.date, now, days) {
            continue;
        }
        analytics.counted += 1;
        if row.amount >= 0.0 {
            analytics.total_in += row.amount;
        } else {
            analytics.total_out += row.amount.abs();
        }
        *ref_totals.entry(row.ref_type.clone()).or_default() += row.amount;
        if let Some(id) = journal_counterparty_id(row, self_character_id) {
            *party_totals.entry(resolver.name(id)).or_default() += row.amount;
        }
    }
    analytics.net = analytics.total_in - analytics.total_out;
    let mut refs: Vec<(String, f64)> = ref_totals.into_iter().collect();
    refs.sort_by(|a, b| b.1.abs().total_cmp(&a.1.abs()).then(a.0.cmp(&b.0)));
    analytics.by_ref_type = refs;
    let mut parties: Vec<(String, f64)> = party_totals.into_iter().collect();
    parties.sort_by(|a, b| b.1.abs().total_cmp(&a.1.abs()).then(a.0.cmp(&b.0)));
    parties.truncate(5);
    analytics.top_counterparties = parties;
    analytics
}

pub fn show(ui: &mut egui::Ui, state: &mut AppState, resolver: &NameResolver) {
    ui.heading("Wallet");
    widgets::mode_notice(ui, state.demo, state.offline);
    if state.active_character().is_none() {
        widgets::no_character_panel(ui);
        return;
    }
    // Clone the snapshot so filter/search edits below can borrow `state`.
    let snapshot = state.wallet.clone();
    match snapshot {
        LoadState::Ready(w) => {
            let now = Utc::now();
            if w.journal.is_empty() && w.transactions.is_empty() {
                widgets::card(ui, |ui| {
                    ui.label(widgets::numeric_text(format!(
                        "Balance: {}",
                        widgets::format_isk(w.balance)
                    )));
                    widgets::empty_panel(
                        ui,
                        "No wallet history yet. Press Ctrl+R (or Refresh) after signing in.",
                    );
                });
                if !w.loyalty.is_empty() {
                    show_loyalty_card(ui, &w.loyalty, resolver);
                }
                return;
            }

            let analytics = compute_analytics(
                &w.journal,
                now,
                state.wallet_period.days(),
                state.active_character_id,
                resolver,
            );
            ui.horizontal_wrapped(|ui| {
                widgets::metric_tile(
                    ui,
                    "Balance",
                    &widgets::format_isk(w.balance),
                    theme::ACCENT_CYAN,
                );
                widgets::metric_tile(
                    ui,
                    "Income",
                    &widgets::format_isk_signed(analytics.total_in),
                    theme::POSITIVE,
                );
                widgets::metric_tile(
                    ui,
                    "Expenses",
                    &widgets::format_isk_signed(-analytics.total_out),
                    theme::NEGATIVE,
                );
                widgets::metric_tile(
                    ui,
                    "Net",
                    &widgets::format_isk_signed(analytics.net),
                    widgets::isk_color(analytics.net),
                );
            });
            ui.add_space(4.0);

            widgets::card(ui, |ui| {
                ui.horizontal_wrapped(|ui| {
                    ui.label("Period:");
                    for period in WalletPeriod::ALL {
                        if ui
                            .selectable_label(state.wallet_period == period, period.label())
                            .clicked()
                        {
                            tracing::debug!("[WALLET] period filter {}", period.label());
                            state.wallet_period = period;
                        }
                    }
                });
                let focus = widgets::search_box(
                    ui,
                    &mut state.wallet_search,
                    "Filter journal/transactions (press / to focus, arrows move)",
                    state.focus_search && state.view == View::Wallet,
                );
                state.text_input_focused |= focus;
                if focus && state.view == View::Wallet {
                    state.focus_search = false;
                }
            });

            // --- Two-column Analytics: By type + Top counterparties ---
            ui.columns(2, |cols| {
                widgets::card(&mut cols[0], |ui| {
                    widgets::section_title(
                        ui,
                        &format!("Analytics ({}) — By type", state.wallet_period.label()),
                    );
                    ui.label(format!("Journal rows counted: {}", analytics.counted));
                    if analytics.by_ref_type.is_empty() {
                        ui.label("No journal rows in this period.");
                    } else {
                        ui.label(
                            egui::RichText::new("By type (click to filter journal):")
                                .color(theme::TEXT_SECONDARY),
                        );
                        let mut ref_rows: Vec<(String, f64)> = analytics.by_ref_type.clone();
                        ref_rows.truncate(8);
                        for (ref_type, net) in ref_rows {
                            let selected =
                                state.wallet_ref_filter.as_deref() == Some(ref_type.as_str());
                            ui.horizontal(|ui| {
                                if ui.selectable_label(selected, &ref_type).clicked() {
                                    tracing::debug!("[WALLET] ref-type filter {}", ref_type);
                                    state.wallet_ref_filter =
                                        if selected { None } else { Some(ref_type) };
                                }
                                ui.colored_label(
                                    widgets::isk_color(net),
                                    widgets::format_isk_signed(net),
                                );
                            });
                        }
                        if state.wallet_ref_filter.is_some()
                            && ui.button("Clear type filter").clicked()
                        {
                            state.wallet_ref_filter = None;
                        }
                    }
                });
                widgets::card(&mut cols[1], |ui| {
                    widgets::section_title(ui, "Top counterparties (resolved names)");
                    if analytics.top_counterparties.is_empty() {
                        ui.label("No counterparties in this period.");
                    } else {
                        for (name, net) in &analytics.top_counterparties {
                            ui.horizontal(|ui| {
                                ui.label(name);
                                ui.colored_label(
                                    widgets::isk_color(*net),
                                    widgets::format_isk_signed(*net),
                                );
                            });
                        }
                    }
                });
            });

            // --- Journal table ---
            let active_id = state.active_character_id;
            let query = state.wallet_search.clone();
            let ref_filter = state.wallet_ref_filter.clone();
            let mut visible: Vec<&WalletJournalItem> = w
                .journal
                .iter()
                .filter(|row| within_window(&row.date, now, state.wallet_period.days()))
                .filter(|row| {
                    ref_filter
                        .as_deref()
                        .map(|f| row.ref_type == f)
                        .unwrap_or(true)
                })
                .filter(|row| {
                    let party = journal_counterparty_id(row, active_id)
                        .map(|id| resolver.name(id))
                        .unwrap_or_default();
                    widgets::matches_search(&row.description, &query)
                        || widgets::matches_search(&row.ref_type, &query)
                        || widgets::matches_search(&party, &query)
                })
                .collect();
            visible.sort_by(|a, b| b.date.cmp(&a.date));

            // Arrow-key row movement (skipped while typing in search).
            if !state.text_input_focused
                && !ui.ctx().egui_wants_keyboard_input()
                && !visible.is_empty()
            {
                let (down, up) = ui.ctx().input(|i| {
                    (
                        i.key_pressed(egui::Key::ArrowDown),
                        i.key_pressed(egui::Key::ArrowUp),
                    )
                });
                if down && state.selected_journal_row + 1 < visible.len() {
                    state.selected_journal_row += 1;
                }
                if up && state.selected_journal_row > 0 {
                    state.selected_journal_row -= 1;
                }
            }
            if state.selected_journal_row >= visible.len() {
                state.selected_journal_row = visible.len().saturating_sub(1);
            }

            widgets::card(ui, |ui| {
                widgets::section_title(ui, &format!("Journal ({} rows)", visible.len()));
                ui.add_space(4.0);
                if visible.is_empty() {
                    widgets::empty_panel(ui, "No journal entries match the current filters.");
                } else {
                    egui::ScrollArea::vertical()
                        .id_salt("wallet_scroll")
                        .max_height(260.0)
                        .show(ui, |ui| {
                            egui::Grid::new("wallet_journal")
                                .striped(true)
                                .spacing([14.0, 5.0])
                                .show(ui, |ui| {
                                    for header in
                                        ["Date", "Type", "Amount", "Counterparty", "Description"]
                                    {
                                        ui.label(
                                            egui::RichText::new(header)
                                                .strong()
                                                .color(theme::TEXT_SECONDARY),
                                        );
                                    }
                                    ui.end_row();
                                    for (idx, row) in visible.iter().enumerate() {
                                        let party = journal_counterparty_id(row, active_id)
                                            .map(|id| resolver.name(id))
                                            .unwrap_or_default();
                                        let marker = if idx == state.selected_journal_row {
                                            ">"
                                        } else {
                                            ""
                                        };
                                        ui.label(format!(
                                            "{} {}",
                                            marker,
                                            widgets::format_date_short(&row.date)
                                        ));
                                        ui.label(&row.ref_type);
                                        ui.colored_label(
                                            widgets::isk_color(row.amount),
                                            widgets::format_isk_signed(row.amount),
                                        );
                                        ui.label(&party);
                                        ui.label(&row.description);
                                        ui.end_row();
                                    }
                                });
                        });
                }
            });

            // --- Transactions table ---
            widgets::card(ui, |ui| {
                widgets::section_title(ui, "Transactions");
                ui.add_space(4.0);
                if w.transactions.is_empty() {
                    widgets::empty_panel(ui, "No market transactions yet.");
                } else {
                    let mut visible_tx: Vec<_> = w
                        .transactions
                        .iter()
                        .filter(|row| within_window(&row.date, now, state.wallet_period.days()))
                        .filter(|row| {
                            let item = resolver.name(row.type_id);
                            let location = resolver.location_name(row.location_id);
                            widgets::matches_search(&item, &query)
                                || widgets::matches_search(&location, &query)
                        })
                        .collect();
                    visible_tx.sort_by(|a, b| b.date.cmp(&a.date));
                    if visible_tx.is_empty() {
                        widgets::empty_panel(ui, "No transactions match the current filters.");
                    } else {
                        egui::Grid::new("wallet_transactions")
                            .striped(true)
                            .spacing([14.0, 5.0])
                            .show(ui, |ui| {
                                for header in
                                    ["Date", "Side", "Item", "Quantity", "Unit Price", "Location"]
                                {
                                    ui.label(
                                        egui::RichText::new(header)
                                            .strong()
                                            .color(theme::TEXT_SECONDARY),
                                    );
                                }
                                ui.end_row();
                                for row in &visible_tx {
                                    let item = resolver.name(row.type_id);
                                    let location = resolver.location_name(row.location_id);
                                    ui.label(widgets::format_date_short(&row.date));
                                    if row.is_buy {
                                        widgets::badge(
                                            ui,
                                            "BUY",
                                            theme::NEGATIVE_BG,
                                            theme::NEGATIVE,
                                        );
                                    } else {
                                        widgets::badge(
                                            ui,
                                            "SELL",
                                            theme::POSITIVE_BG,
                                            theme::POSITIVE,
                                        );
                                    }
                                    ui.label(item);
                                    ui.label(widgets::format_count(row.quantity));
                                    ui.label(widgets::format_isk(row.unit_price));
                                    ui.label(location);
                                    ui.end_row();
                                }
                            });
                    }
                }
            });

            if !w.loyalty.is_empty() {
                show_loyalty_card(ui, &w.loyalty, resolver);
            }
        }
        LoadState::Loading => widgets::loading_panel(ui, "Loading wallet..."),
        LoadState::Empty => widgets::empty_panel(ui, "No wallet data yet."),
        LoadState::Error(e) => {
            if widgets::error_panel_with_retry(ui, &e) {
                tracing::warn!("[WALLET] retry requested after load error");
                state.retry_requested = true;
            }
        }
    }
}

fn show_loyalty_card(
    ui: &mut egui::Ui,
    loyalty: &[crate::esi::models::LoyaltyPointItem],
    resolver: &NameResolver,
) {
    widgets::card(ui, |ui| {
        widgets::section_title(ui, "Loyalty points");
        for row in loyalty {
            ui.label(format!(
                "{}: {} LP",
                resolver.name(row.corporation_id),
                widgets::format_count(row.loyalty_points)
            ));
        }
    });
}

#[cfg(test)]
mod tests {
    use super::*;

    fn row(amount: f64, ref_type: &str, date: &str, second: Option<i64>) -> WalletJournalItem {
        WalletJournalItem {
            amount,
            ref_type: ref_type.to_string(),
            date: date.to_string(),
            second_party_id: second,
            ..Default::default()
        }
    }

    fn now() -> DateTime<Utc> {
        widgets::parse_esi_date("2026-11-15T12:00:00Z").expect("fixed date")
    }

    #[test]
    fn analytics_totals_refs_and_counterparties() {
        let mut resolver = NameResolver::new();
        resolver.insert(1000125, "CONCORD".to_string());
        resolver.insert(90000003, "Demo Trader".to_string());
        let journal = vec![
            row(
                2_500_000.0,
                "bounty_prizes",
                "2026-11-14T10:00:00Z",
                Some(1000125),
            ),
            row(
                -150_000.0,
                "market_transaction",
                "2026-11-13T09:00:00Z",
                Some(90000003),
            ),
            row(
                -50_000.0,
                "market_transaction",
                "2026-01-01T09:00:00Z",
                Some(90000003),
            ),
            row(f64::NAN, "bounty_prizes", "2026-11-14T10:00:00Z", None),
        ];
        let all = compute_analytics(&journal, now(), None, Some(90000001), &resolver);
        assert_eq!(all.counted, 3);
        assert_eq!(all.total_in, 2_500_000.0);
        assert_eq!(all.total_out, 200_000.0);
        assert_eq!(all.net, 2_300_000.0);
        assert_eq!(all.top_counterparties[0].0, "CONCORD");
        assert!(all
            .top_counterparties
            .iter()
            .all(|(n, _)| n.parse::<i64>().is_err()));

        let recent = compute_analytics(&journal, now(), Some(30), Some(90000001), &resolver);
        assert_eq!(
            recent.counted, 2,
            "January row falls outside the 30-day window"
        );
        assert_eq!(recent.total_out, 150_000.0);
    }

    #[test]
    fn analytics_empty_and_unresolved_never_show_raw_ids() {
        let resolver = NameResolver::new(); // empty cache -> Unknown Item
        let empty = compute_analytics(&[], now(), None, None, &resolver);
        assert_eq!(empty, WalletAnalytics::default());
        let journal = vec![row(1.0, "x", "not-a-date", Some(424242))];
        let result = compute_analytics(&journal, now(), Some(7), None, &resolver);
        assert_eq!(result.counted, 1, "unparseable date stays visible");
        assert_eq!(result.top_counterparties[0].0, "Unknown Item");
    }

    #[test]
    fn journal_counterparty_id_handles_incoming_and_outgoing_rows() {
        let incoming = WalletJournalItem {
            first_party_id: Some(1000125),
            second_party_id: Some(90000001),
            ..Default::default()
        };
        assert_eq!(
            journal_counterparty_id(&incoming, Some(90000001)),
            Some(1000125)
        );

        let outgoing = WalletJournalItem {
            first_party_id: Some(90000001),
            second_party_id: Some(90000003),
            ..Default::default()
        };
        assert_eq!(
            journal_counterparty_id(&outgoing, Some(90000001)),
            Some(90000003)
        );
        assert_eq!(journal_counterparty_id(&incoming, None), Some(90000001));
    }
}
