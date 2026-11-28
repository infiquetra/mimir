//! Market: public regional orders and price history for one selected
//! item type, plus the active character's own open orders. Read-only:
//! the view sets request flags (`market_fetch_requested`,
//! `market_lookup_requested`, `stepup_requested`) and calls the two
//! selection helpers; it never fetches. Every rendered identifier is
//! a resolved EVE name, never a raw numeric ID.

use std::cmp::Ordering;

use super::portraits::{
    ensure_type_icon_requested, show_type_icon, PortraitImageCache, MARKET_TYPE_ICON_PX,
};
use super::widgets;
use crate::app::state::{
    market_region_name, AppState, LoadState, MarketData, SectionError, StepUpRequest,
    MARKET_REGIONS,
};
use crate::config::EveConfig;
use crate::esi::models::{CharacterOrder, MarketHistoryEntry, RegionalOrder, UniverseName};
use crate::names::resolver::NameResolver;
use crate::trade_calculator::{parse_fee_percent, parse_trade_price, trade_calculator_result};

pub const MARKET_TOP_N: usize = 10;
pub const MARKET_HISTORY_ROWS: usize = 30;
const QUICK_PICK_MAX: usize = 12;

/// Trade Calculator block wording (market trade calculator design
/// section 7): heading, input labels, guidance lines, and
/// disclosure, all verbatim. Named constants so tests assert them
/// byte-exactly without an egui frame.
pub const TRADE_CALCULATOR_HEADING: &str = "Trade Calculator";
pub const TRADE_CALCULATOR_INPUT_LABELS: [&str; 4] = [
    "Buy Price (ISK)",
    "Sell Price (ISK)",
    "Broker Fee % (entered by you)",
    "Sales Tax % (entered by you)",
];
pub const TRADE_CALCULATOR_INPUT_GUIDANCE: &str =
    "Enter a buy price and a sell price above 0 ISK, and fee percents from 0 to 100, to see the result.";
pub const TRADE_CALCULATOR_NO_RESULT_GUIDANCE: &str = "No result: the broker fee and sales tax together must be below 100%, and the prices must be small enough to calculate with.";
pub const TRADE_CALCULATOR_DISCLOSURE: &str = "Per-unit estimate using only the prices and percents you entered. The broker fee is charged on both the buy and sell orders; sales tax is charged on the sell order only. The starting percents (broker fee 1.0%, sales tax 2.0%) are starting values to replace with your own rates: Mimir does not read them from your character's skills, standings, or the station or structure, and they may not be the rates you actually pay. Relist fees and any quantity total are not included. Figures are rounded only for display, so these numbers can differ from EVE.";

#[derive(Debug, Clone, Default)]
pub struct OrderBookSummary {
    pub best_sell: Option<f64>,
    pub best_buy: Option<f64>,
    pub spread: Option<f64>,
    pub sell_order_count: usize,
    pub buy_order_count: usize,
    pub sell_volume_remain: i64,
    pub buy_volume_remain: i64,
    pub top_sells: Vec<RegionalOrder>,
    pub top_buys: Vec<RegionalOrder>,
    pub skipped_invalid: usize,
}

fn participating(order: &RegionalOrder) -> bool {
    order.price.is_finite() && order.price > 0.0
}

/// Invisible tie-breaks shared by both sides: larger remaining volume
/// first, earlier issued first, lower order id first.
fn tie_break(a: &RegionalOrder, b: &RegionalOrder) -> Ordering {
    b.volume_remain
        .cmp(&a.volume_remain)
        .then_with(|| a.issued.cmp(&b.issued))
        .then(a.order_id.cmp(&b.order_id))
}

/// Summarize a fetched regional order book. Prices decode from remote
/// JSON unvalidated, so non-finite or non-positive prices never
/// participate, and volume sums saturate.
pub fn summarize_orders(orders: &[RegionalOrder]) -> OrderBookSummary {
    let mut sells: Vec<RegionalOrder> = Vec::new();
    let mut buys: Vec<RegionalOrder> = Vec::new();
    let mut skipped_invalid = 0usize;
    for order in orders {
        if !participating(order) {
            skipped_invalid = skipped_invalid.saturating_add(1);
        } else if order.is_buy_order {
            buys.push(order.clone());
        } else {
            sells.push(order.clone());
        }
    }
    let best_sell = sells.iter().map(|o| o.price).min_by(f64::total_cmp);
    let best_buy = buys.iter().map(|o| o.price).max_by(f64::total_cmp);
    let spread = match (best_sell, best_buy) {
        (Some(sell), Some(buy)) => Some(sell - buy),
        _ => None,
    };
    let sell_volume_remain = sells
        .iter()
        .fold(0i64, |acc, o| acc.saturating_add(o.volume_remain.max(0)));
    let buy_volume_remain = buys
        .iter()
        .fold(0i64, |acc, o| acc.saturating_add(o.volume_remain.max(0)));
    let sell_order_count = sells.len();
    let buy_order_count = buys.len();
    sells.sort_by(|a, b| a.price.total_cmp(&b.price).then_with(|| tie_break(a, b)));
    buys.sort_by(|a, b| b.price.total_cmp(&a.price).then_with(|| tie_break(a, b)));
    sells.truncate(MARKET_TOP_N);
    buys.truncate(MARKET_TOP_N);
    tracing::debug!(
        "[MARKET] summarized orders sells={} buys={} skipped_invalid={}",
        sell_order_count,
        buy_order_count,
        skipped_invalid
    );
    OrderBookSummary {
        best_sell,
        best_buy,
        spread,
        sell_order_count,
        buy_order_count,
        sell_volume_remain,
        buy_volume_remain,
        top_sells: sells,
        top_buys: buys,
        skipped_invalid,
    }
}

#[derive(Debug, Clone, Default, PartialEq)]
pub struct CharacterOrderRow {
    pub order_id: i64,
    pub type_id: i64,
    pub location_id: i64,
    pub is_buy_order: bool,
    pub price: f64,
    pub filled: i64,
    pub volume_remain: i64,
    pub volume_total: i64,
    pub issued: String,
    pub duration_days: i64,
    pub escrow: Option<f64>,
    pub matches_selected_type: bool,
}

pub fn filled_volume(volume_total: i64, volume_remain: i64) -> i64 {
    // Volumes decode from remote JSON unvalidated: clamp the remaining
    // volume first so a negative can never inflate the filled amount.
    volume_total.saturating_sub(volume_remain.max(0)).max(0)
}

pub fn filled_fraction(volume_total: i64, volume_remain: i64) -> Option<f64> {
    if volume_total <= 0 {
        return None;
    }
    let ratio = filled_volume(volume_total, volume_remain) as f64 / volume_total as f64;
    ratio.is_finite().then_some(ratio.clamp(0.0, 1.0))
}

/// Rows for the character's own open orders, newest issued first.
/// No ISK figure is derived here: price and escrow are fetched
/// fields shown per row, never multiplied or summed.
pub fn character_order_rows(
    orders: &[CharacterOrder],
    selected_type_id: i64,
) -> Vec<CharacterOrderRow> {
    let mut rows: Vec<CharacterOrderRow> = orders
        .iter()
        .map(|order| CharacterOrderRow {
            order_id: order.order_id,
            type_id: order.type_id,
            location_id: order.location_id,
            is_buy_order: order.is_buy_order,
            price: order.price,
            filled: filled_volume(order.volume_total, order.volume_remain.max(0)),
            volume_remain: order.volume_remain.max(0),
            volume_total: order.volume_total,
            issued: order.issued.clone(),
            duration_days: order.duration,
            escrow: order.escrow,
            matches_selected_type: order.type_id == selected_type_id,
        })
        .collect();
    rows.sort_by(|a, b| b.issued.cmp(&a.issued).then(b.order_id.cmp(&a.order_id)));
    tracing::debug!("[MARKET] character order rows={}", rows.len());
    rows
}

#[derive(Debug, Clone, Default)]
pub struct HistorySummary {
    pub days_returned: usize,
    pub latest: Option<MarketHistoryEntry>,
    pub recent: Vec<MarketHistoryEntry>,
    pub recent_total_volume: i64,
    pub recent_total_orders: i64,
}

/// Newest-first history with saturating totals over the shown rows
/// only. No average-of-averages or trend figure is computed.
pub fn summarize_history(entries: &[MarketHistoryEntry]) -> HistorySummary {
    let mut sorted: Vec<MarketHistoryEntry> = entries.to_vec();
    sorted.sort_by(|a, b| b.date.cmp(&a.date));
    let latest = sorted.first().cloned();
    let recent: Vec<MarketHistoryEntry> = sorted.into_iter().take(MARKET_HISTORY_ROWS).collect();
    let recent_total_volume = recent
        .iter()
        .fold(0i64, |acc, e| acc.saturating_add(e.volume.max(0)));
    let recent_total_orders = recent
        .iter()
        .fold(0i64, |acc, e| acc.saturating_add(e.order_count.max(0)));
    tracing::debug!(
        "[MARKET] summarized history days={} shown={}",
        entries.len(),
        recent.len()
    );
    HistorySummary {
        days_returned: entries.len(),
        latest,
        recent,
        recent_total_volume,
        recent_total_orders,
    }
}

/// A finite price as ISK words; a non-finite price is "not available",
/// never `format_isk`'s "0.00 ISK" placeholder (a false quote).
pub fn price_label(price: f64) -> String {
    if price.is_finite() {
        widgets::format_isk(price)
    } else {
        "not available".to_string()
    }
}

/// Region words: resolver hit, else the curated hub constant, else
/// the location fallback. Never a raw region number.
pub fn region_label(region_id: i64, resolver: &NameResolver) -> String {
    if let Some(name) = resolver.cached(region_id) {
        return name.to_string();
    }
    match market_region_name(region_id) {
        Some(name) => name.to_string(),
        None => resolver.location_name(region_id),
    }
}

/// Types the user already holds: assets first, then wallet
/// transactions, deduplicated, labeled, sorted, capped.
pub fn quick_pick_types(state: &AppState, resolver: &NameResolver) -> Vec<(i64, String)> {
    let mut ids: Vec<i64> = Vec::new();
    if let Some(data) = state.assets.as_ready() {
        for item in &data.items {
            if item.type_id > 0 && !ids.contains(&item.type_id) {
                ids.push(item.type_id);
            }
        }
    }
    if let Some(data) = state.wallet.as_ready() {
        for tx in &data.transactions {
            if tx.type_id > 0 && !ids.contains(&tx.type_id) {
                ids.push(tx.type_id);
            }
        }
    }
    let mut picks: Vec<(i64, String)> = ids.into_iter().map(|id| (id, resolver.name(id))).collect();
    picks.sort_by(|a, b| {
        a.1.to_lowercase()
            .cmp(&b.1.to_lowercase())
            .then_with(|| a.1.cmp(&b.1))
            .then(a.0.cmp(&b.0))
    });
    picks.truncate(QUICK_PICK_MAX);
    tracing::debug!("[MARKET] quick picks offered={}", picks.len());
    picks
}

const MARKET_LOOKUP_PENDING: &str = "Looking up that item name…";

/// Submit the exact-name lookup: flags only, no fetch here. The
/// dedicated lookup generation kills any in-flight answer for older
/// text without cancelling an unrelated in-flight market data fetch.
fn submit_lookup(state: &mut AppState) {
    let trimmed = state.market_search.trim().to_string();
    if trimmed.is_empty() {
        return;
    }
    tracing::debug!("[MARKET] item name lookup submitted");
    state.market_lookup_requested = Some(trimmed);
    state.market_candidates.clear();
    state.market_lookup_message = Some(MARKET_LOOKUP_PENDING.to_string());
    state.market_lookup_generation = state.market_lookup_generation.wrapping_add(1);
}

fn candidate_word(candidate: &UniverseName) -> String {
    let trimmed = candidate.name.trim();
    if trimmed.is_empty() || trimmed.parse::<i64>().is_ok() {
        "Unknown Item".to_string()
    } else {
        trimmed.to_string()
    }
}

fn show_picker(ui: &mut egui::Ui, state: &mut AppState, resolver: &NameResolver) {
    // Snapshots first so the controls below can borrow `state` mutably.
    let candidates = state.market_candidates.clone();
    let quick_picks = quick_pick_types(state, resolver);
    let selected_id = state.market_selected_type_id;

    widgets::card(ui, |ui| {
        ui.horizontal(|ui| {
            let response = ui.add(
                egui::TextEdit::singleline(&mut state.market_search)
                    .hint_text("Item name, exactly as in EVE (then Look up)")
                    .desired_width(280.0),
            );
            if response.changed() {
                state.clear_market_lookup();
            }
            if state.focus_search {
                response.request_focus();
                state.focus_search = false;
            }
            state.text_input_focused |= response.has_focus();
            let enter_submit =
                response.lost_focus() && ui.input(|i| i.key_pressed(egui::Key::Enter));
            if ui.button("Look up item").clicked() || enter_submit {
                submit_lookup(state);
            }
            if !state.market_search.is_empty() && ui.button("Clear").clicked() {
                state.market_search.clear();
                state.clear_market_lookup();
            }
            if state.market_lookup_message.as_deref() == Some(MARKET_LOOKUP_PENDING) {
                ui.spinner();
            }
        });
        ui.label(
            egui::RichText::new("Name lookup needs the item's exact EVE name.")
                .color(super::theme::TEXT_SECONDARY),
        );
        if let Some(message) = state.market_lookup_message.clone() {
            ui.label(message);
        }

        if !candidates.is_empty() {
            ui.horizontal_wrapped(|ui| {
                for candidate in &candidates {
                    let word = candidate_word(candidate);
                    if ui.selectable_label(false, &word).clicked() {
                        tracing::debug!("[MARKET] lookup candidate chosen name={}", word);
                        state.set_market_selection(candidate.id, word);
                    }
                }
            });
        }

        ui.add_space(4.0);
        widgets::section_title(ui, "Items you hold");
        if quick_picks.is_empty() {
            ui.label(
                "Sign in and load Assets or Wallet to pick from items you hold, \
                 or look an item up by name above.",
            );
        } else {
            ui.horizontal_wrapped(|ui| {
                for (type_id, label) in &quick_picks {
                    let selected = selected_id == Some(*type_id);
                    if ui.selectable_label(selected, label).clicked() {
                        tracing::debug!("[MARKET] quick pick chosen name={}", label);
                        state.set_market_selection(*type_id, label.clone());
                    }
                }
            });
        }

        ui.add_space(4.0);
        widgets::section_title(ui, "Region");
        ui.horizontal_wrapped(|ui| {
            for region in MARKET_REGIONS {
                let label = region_label(region.id, resolver);
                let selected = state.market_region_id == region.id;
                if ui.selectable_label(selected, label).clicked() {
                    state.set_market_region(region.id);
                }
            }
        });
    });
}

/// Every line the Trade Calculator block renders after the heading
/// and input rows: the full result block plus the disclosure, or
/// one guidance line plus the disclosure. Pure over the drafts so
/// tests assert the rendered strings without an egui frame, like
/// the file's other pure summaries.
fn trade_calculator_lines(state: &AppState) -> Vec<String> {
    let mut lines = match trade_calculator_result(
        &state.market_trade_buy_price,
        &state.market_trade_sell_price,
        &state.market_trade_broker_fee_percent,
        &state.market_trade_sales_tax_percent,
    ) {
        Some((margin, break_even)) => {
            let mut lines = vec![
                if margin.is_profitable() {
                    "PROFITABLE".to_string()
                } else {
                    "LOSS".to_string()
                },
                price_label(margin.profit),
                format!("{:.1}% margin", margin.margin_percent),
                format!("Buy Price: {}", price_label(margin.buy_price)),
                format!("+ Broker Fee (buy): {}", price_label(margin.broker_fee_buy)),
                format!("= Total Cost: {}", price_label(margin.buy_total)),
                format!("Sell Price: {}", price_label(margin.sell_price)),
                format!(
                    "- Broker Fee (sell): {}",
                    price_label(margin.broker_fee_sell)
                ),
                format!("- Sales Tax: {}", price_label(margin.sales_tax)),
                format!("= Net Revenue: {}", price_label(margin.sell_net)),
                format!("Profit / Unit: {}", price_label(margin.profit)),
                format!("Total Fees: {}", price_label(margin.total_fees())),
            ];
            if let Some(break_even) = break_even {
                lines.push(format!(
                    "Break-Even Sell Price: {}",
                    price_label(break_even)
                ));
            }
            lines
        }
        None => {
            // Guidance selection only: no calculation is duplicated
            // here. All four drafts parse but the calculation
            // rejects them means the percents sum to 100 or more or
            // a huge-price output overflowed.
            let all_parse = parse_trade_price(&state.market_trade_buy_price).is_some()
                && parse_trade_price(&state.market_trade_sell_price).is_some()
                && parse_fee_percent(&state.market_trade_broker_fee_percent).is_some()
                && parse_fee_percent(&state.market_trade_sales_tax_percent).is_some();
            if all_parse {
                vec![TRADE_CALCULATOR_NO_RESULT_GUIDANCE.to_string()]
            } else {
                vec![TRADE_CALCULATOR_INPUT_GUIDANCE.to_string()]
            }
        }
    };
    lines.push(TRADE_CALCULATOR_DISCLOSURE.to_string());
    lines
}

fn show_trade_calculator(ui: &mut egui::Ui, state: &mut AppState) {
    let mut changed = false;
    egui::Grid::new("market_trade_calc_inputs")
        .spacing([12.0, 6.0])
        .show(ui, |ui| {
            ui.label(TRADE_CALCULATOR_INPUT_LABELS[0]);
            let response = ui.text_edit_singleline(&mut state.market_trade_buy_price);
            state.text_input_focused |= response.has_focus();
            changed |= response.changed();
            ui.end_row();
            ui.label(TRADE_CALCULATOR_INPUT_LABELS[1]);
            let response = ui.text_edit_singleline(&mut state.market_trade_sell_price);
            state.text_input_focused |= response.has_focus();
            changed |= response.changed();
            ui.end_row();
            ui.label(TRADE_CALCULATOR_INPUT_LABELS[2]);
            let response = ui.text_edit_singleline(&mut state.market_trade_broker_fee_percent);
            state.text_input_focused |= response.has_focus();
            changed |= response.changed();
            ui.end_row();
            ui.label(TRADE_CALCULATOR_INPUT_LABELS[3]);
            let response = ui.text_edit_singleline(&mut state.market_trade_sales_tax_percent);
            state.text_input_focused |= response.has_focus();
            changed |= response.changed();
            ui.end_row();
        });
    if changed {
        tracing::debug!("[MARKET] trade calculator input changed");
    }
    for line in trade_calculator_lines(state) {
        ui.label(line);
    }
}

fn section_error_line(ui: &mut egui::Ui, section: &str, error: &SectionError) {
    ui.label(format!("Could not load {section}: {}", error.message));
}

fn show_public_orders(ui: &mut egui::Ui, bundle: &MarketData, resolver: &NameResolver) {
    ui.heading("Public orders");
    match &bundle.public_orders {
        Err(error) => section_error_line(ui, "public orders", error),
        Ok(data) => {
            let summary = summarize_orders(&data.orders);
            if summary.skipped_invalid > 0 {
                tracing::debug!(
                    "[MARKET] public orders skipped_invalid={}",
                    summary.skipped_invalid
                );
            }
            if summary.sell_order_count == 0 && summary.buy_order_count == 0 {
                ui.label("No public orders for this item in this region.");
                return;
            }
            match summary.best_sell {
                Some(price) => ui.label(format!("Best sell: {}", price_label(price))),
                None => ui.label("Best sell: no sell orders"),
            };
            match summary.best_buy {
                Some(price) => ui.label(format!("Best buy: {}", price_label(price))),
                None => ui.label("Best buy: no buy orders"),
            };
            match summary.spread {
                Some(spread) => ui.label(format!("Spread: {}", price_label(spread))),
                None => ui.label("Spread: not available (one side of the book is empty)"),
            };
            ui.label(format!(
                "Sell orders: {} ({} remaining)",
                summary.sell_order_count, summary.sell_volume_remain
            ));
            ui.label(format!(
                "Buy orders: {} ({} remaining)",
                summary.buy_order_count, summary.buy_volume_remain
            ));
            if data.truncated {
                ui.label(
                    "Showing the first pages of orders only; counts and best \
                     prices cover the orders loaded.",
                );
            }
            ui.heading("Top sell orders");
            if summary.top_sells.is_empty() {
                ui.label("no sell orders");
            } else {
                for order in &summary.top_sells {
                    ui.label(format!(
                        "{} — {} remaining at {}",
                        price_label(order.price),
                        order.volume_remain,
                        resolver.location_name(order.location_id)
                    ));
                }
            }
            ui.heading("Top buy orders");
            if summary.top_buys.is_empty() {
                ui.label("no buy orders");
            } else {
                for order in &summary.top_buys {
                    ui.label(format!(
                        "{} — {} remaining at {}",
                        price_label(order.price),
                        order.volume_remain,
                        resolver.location_name(order.location_id)
                    ));
                }
            }
        }
    }
}

fn show_history(ui: &mut egui::Ui, bundle: &MarketData) {
    ui.heading("Price history");
    match &bundle.history {
        Err(error) => section_error_line(ui, "price history", error),
        Ok(entries) => {
            let summary = summarize_history(entries);
            let Some(latest) = &summary.latest else {
                ui.label("No price history for this item in this region.");
                return;
            };
            ui.label(format!("Latest: {}", latest.date));
            ui.label(format!("Average: {}", price_label(latest.average)));
            ui.label(format!("Highest: {}", price_label(latest.highest)));
            ui.label(format!("Lowest: {}", price_label(latest.lowest)));
            ui.label(format!("Orders: {}", latest.order_count));
            ui.label(format!("Volume: {}", latest.volume));
            for entry in &summary.recent {
                ui.label(format!(
                    "{} — average {}, volume {}",
                    entry.date,
                    price_label(entry.average),
                    entry.volume
                ));
            }
            ui.label(format!(
                "Last {} days shown: {} orders, {} traded.",
                summary.recent.len(),
                summary.recent_total_orders,
                summary.recent_total_volume
            ));
        }
    }
}

/// Step-up guidance inside the character-orders section only: the
/// button only sets the shell's step-up request flag; it clears
/// nothing and never blocks the public sections.
fn market_reauthorize_panel(ui: &mut egui::Ui, state: &mut AppState) {
    ui.heading("Your open orders need one more EVE permission.");
    ui.label(format!(
        "This character has not granted {}, the EVE SSO scope that lets \
         Mimir read the character's own open orders. The public orders \
         and history above need no permission and are unaffected.",
        EveConfig::MARKET_SCOPES.join(" ")
    ));
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
                "[AUTH] step-up re-authorize requested from Market view character_id={} scopes={}",
                active_id,
                EveConfig::MARKET_SCOPES.join(" ")
            );
            state.stepup_requested = Some(StepUpRequest::new(active_id, EveConfig::MARKET_SCOPES));
            state.status_message =
                "EVE SSO requested: your browser should open to login.eveonline.com.".to_string();
        }
    }
}

fn show_character_orders(
    ui: &mut egui::Ui,
    state: &mut AppState,
    bundle: &MarketData,
    resolver: &NameResolver,
) {
    ui.heading("Your open orders");
    if bundle.selection.character_id.is_none() {
        widgets::no_character_panel(ui);
        return;
    }
    match &bundle.character_orders {
        Err(error) if error.needs_reauthorize => {
            tracing::debug!("[MARKET] showing re-authorize guidance (missing scope)");
            market_reauthorize_panel(ui, state);
        }
        Err(error) => section_error_line(ui, "your open orders", error),
        Ok(data) => {
            if data.orders.is_empty() {
                ui.label("No open orders for this character.");
                return;
            }
            if let Some(name) = state.active_character().map(|c| c.name.clone()) {
                ui.label(format!("Open orders for {name}"));
            }
            if data.truncated {
                ui.label(
                    "Showing the first pages of your orders only; the list \
                     covers the orders loaded.",
                );
            }
            let rows = character_order_rows(&data.orders, bundle.selection.type_id);
            for row in &rows {
                ui.separator();
                let side = if row.is_buy_order { "BUY" } else { "SELL" };
                let marker = if row.matches_selected_type {
                    " (item shown above)"
                } else {
                    ""
                };
                ui.label(format!(
                    "{} — {}{}",
                    resolver.name(row.type_id),
                    side,
                    marker
                ));
                ui.label(format!("Price: {}", price_label(row.price)));
                ui.label(format!(
                    "Filled: {} of {} ({} remaining)",
                    row.filled, row.volume_total, row.volume_remain
                ));
                if let Some(fraction) = filled_fraction(row.volume_total, row.volume_remain) {
                    ui.add(egui::ProgressBar::new(fraction as f32));
                }
                ui.label(format!("At: {}", resolver.location_name(row.location_id)));
                if row.is_buy_order {
                    if let Some(escrow) = row.escrow.filter(|e| e.is_finite()) {
                        ui.label(format!("Escrow: {}", price_label(escrow)));
                    }
                }
            }
        }
    }
}

pub fn show(
    ui: &mut egui::Ui,
    state: &mut AppState,
    resolver: &NameResolver,
    cache: &mut PortraitImageCache,
) {
    ui.heading("Market");
    widgets::mode_notice(ui, state.demo, state.offline);
    // Freed textures for no-longer-known types go first, mirroring
    // Characters and Dashboard: without this the market icon
    // texture is never pruned and a stale texture could linger past
    // a character switch or a selection change.
    cache.prune(state);
    show_picker(ui, state, resolver);

    if let Some(type_id) = state.market_selected_type_id {
        // Exactly one ensure per selected type, inside the `Some`
        // branch: the icon and labels are built every frame (no
        // virtualization claim), bounded at one.
        ensure_type_icon_requested(state, type_id);
        let heading = resolver
            .cached(type_id)
            .map(str::to_string)
            .or_else(|| state.market_selected_type_name.clone())
            .unwrap_or_else(|| "Unknown Item".to_string());
        widgets::card(ui, |ui| {
            ui.horizontal(|ui| {
                show_type_icon(ui, cache, state, type_id, MARKET_TYPE_ICON_PX);
                ui.vertical(|ui| {
                    ui.heading(heading);
                    ui.label(format!(
                        "Region: {}",
                        region_label(state.market_region_id, resolver)
                    ));
                });
                ui.with_layout(egui::Layout::right_to_left(egui::Align::Center), |ui| {
                    if ui.button("Refresh market data").clicked() {
                        tracing::info!("[MARKET] refresh requested from Market view");
                        state.market_fetch_requested = true;
                    }
                });
            });
        });

        let snapshot = state.market.clone();
        match snapshot {
            LoadState::Loading => widgets::card(ui, |ui| {
                widgets::loading_panel(ui, "Loading market data...");
            }),
            LoadState::Empty => widgets::card(ui, |ui| {
                widgets::empty_panel(ui, "No market data yet.");
            }),
            LoadState::Error(e) => widgets::card(ui, |ui| {
                if widgets::error_panel_with_retry(ui, &e) {
                    tracing::warn!("[MARKET] retry requested after load error");
                    state.market_fetch_requested = true;
                }
            }),
            LoadState::Ready(bundle) => {
                ui.columns(2, |cols| {
                    widgets::card(&mut cols[0], |ui| {
                        show_public_orders(ui, &bundle, resolver);
                    });
                    widgets::card(&mut cols[1], |ui| {
                        show_history(ui, &bundle);
                    });
                });
                widgets::card(ui, |ui| {
                    show_character_orders(ui, state, &bundle, resolver);
                });
            }
        }
    } else {
        widgets::card(ui, |ui| {
            ui.label(
                "Choose an item to load public market data. Your own open \
                 orders appear here too once an item is chosen.",
            );
        });
    }

    // Trade calculator sits cleanly below market orders/history inside its own card.
    widgets::card(ui, |ui| {
        egui::CollapsingHeader::new(TRADE_CALCULATOR_HEADING)
            .default_open(false)
            .show(ui, |ui| {
                show_trade_calculator(ui, state);
            });
    });
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::app::state::{AssetsData, WalletData};
    use crate::esi::models::{AssetItem, WalletTransactionItem};

    fn order(id: i64, buy: bool, price: f64, remain: i64, issued: &str) -> RegionalOrder {
        RegionalOrder {
            order_id: id,
            type_id: 34,
            location_id: 60003760,
            price,
            volume_remain: remain,
            volume_total: remain,
            is_buy_order: buy,
            issued: issued.to_string(),
            ..Default::default()
        }
    }

    fn approx(a: f64, b: f64) -> bool {
        (a - b).abs() < 1e-9
    }

    #[test]
    fn summary_best_prices_spread_and_tie_breaks() {
        let orders = vec![
            order(3, false, 5.75, 80_000, "2026-11-10T08:00:00Z"),
            order(2, false, 5.75, 120_000, "2026-11-09T08:00:00Z"),
            order(1, false, 5.75, 120_000, "2026-11-08T08:00:00Z"),
            order(4, false, 5.90, 50_000, "2026-11-11T09:00:00Z"),
            order(5, true, 5.50, 90_000, "2026-11-12T10:00:00Z"),
            order(6, true, 5.25, 40_000, "2026-11-08T07:30:00Z"),
        ];
        let summary = summarize_orders(&orders);
        assert_eq!(summary.best_sell, Some(5.75));
        assert_eq!(summary.best_buy, Some(5.50));
        assert!(approx(summary.spread.expect("spread"), 0.25));
        assert_eq!(summary.sell_order_count, 4);
        assert_eq!(summary.buy_order_count, 2);
        assert_eq!(summary.sell_volume_remain, 370_000);
        assert_eq!(summary.buy_volume_remain, 130_000);
        // Price tie: larger volume first, then earlier issued.
        let sell_ids: Vec<i64> = summary.top_sells.iter().map(|o| o.order_id).collect();
        assert_eq!(sell_ids, vec![1, 2, 3, 4]);
        let buy_ids: Vec<i64> = summary.top_buys.iter().map(|o| o.order_id).collect();
        assert_eq!(buy_ids, vec![5, 6]);
        assert_eq!(summary.skipped_invalid, 0);
    }

    #[test]
    fn summary_empty_one_sided_crossed_and_invalid_prices() {
        let empty = summarize_orders(&[]);
        assert_eq!(empty.best_sell, None);
        assert_eq!(empty.best_buy, None);
        assert_eq!(empty.spread, None);
        assert_eq!(empty.sell_order_count + empty.buy_order_count, 0);
        let sells_only = summarize_orders(&[order(1, false, 5.0, 10, "2026-11-10T00:00:00Z")]);
        assert_eq!(sells_only.best_buy, None);
        assert_eq!(sells_only.spread, None);
        let crossed = summarize_orders(&[
            order(1, false, 5.0, 10, "2026-11-10T00:00:00Z"),
            order(2, true, 6.0, 10, "2026-11-10T00:00:00Z"),
        ]);
        assert_eq!(crossed.spread, Some(-1.0), "crossed book shown as-is");
        let invalid = summarize_orders(&[
            order(1, false, f64::NAN, 10, "2026-11-10T00:00:00Z"),
            order(2, false, f64::INFINITY, 10, "2026-11-10T00:00:00Z"),
            order(3, true, 0.0, 10, "2026-11-10T00:00:00Z"),
            order(4, true, -2.0, 10, "2026-11-10T00:00:00Z"),
            order(5, false, 7.0, 10, "2026-11-10T00:00:00Z"),
        ]);
        assert_eq!(invalid.skipped_invalid, 4);
        assert_eq!(invalid.best_sell, Some(7.0), "NaN never becomes best");
        assert_eq!(invalid.best_buy, None);
    }

    #[test]
    fn summary_top_n_truncates_and_volumes_saturate() {
        let many: Vec<RegionalOrder> = (1..=15)
            .map(|i| order(i, false, i as f64, 1, "2026-11-10T00:00:00Z"))
            .collect();
        let summary = summarize_orders(&many);
        assert_eq!(summary.top_sells.len(), MARKET_TOP_N);
        assert_eq!(summary.top_sells[0].price, 1.0);
        assert_eq!(summary.sell_order_count, 15);
        let overflow = summarize_orders(&[
            order(1, true, 5.0, i64::MAX, "2026-11-10T00:00:00Z"),
            order(2, true, 5.0, i64::MAX, "2026-11-10T00:00:00Z"),
            order(3, true, 5.0, -100, "2026-11-10T00:00:00Z"),
        ]);
        assert_eq!(overflow.buy_volume_remain, i64::MAX);
    }

    #[test]
    fn character_rows_filled_math_sort_and_match() {
        assert_eq!(filled_volume(50_000, 25_000), 25_000);
        assert_eq!(filled_volume(10, 25), 0, "remain above total clamps");
        assert_eq!(filled_volume(i64::MAX, -1), i64::MAX);
        assert_eq!(filled_fraction(0, 0), None);
        assert_eq!(filled_fraction(100, 25), Some(0.75));
        assert_eq!(filled_fraction(100, 250), Some(0.0));
        let rows = character_order_rows(
            &[
                CharacterOrder {
                    order_id: 10,
                    type_id: 34,
                    volume_remain: 25_000,
                    volume_total: 50_000,
                    issued: "2026-11-13T11:00:00Z".to_string(),
                    ..Default::default()
                },
                CharacterOrder {
                    order_id: 11,
                    type_id: 587,
                    volume_remain: 1,
                    volume_total: 1,
                    issued: "2026-11-13T11:00:00Z".to_string(),
                    ..Default::default()
                },
                CharacterOrder {
                    order_id: 12,
                    type_id: 34,
                    volume_remain: 5,
                    volume_total: 5,
                    issued: "2026-11-12T11:00:00Z".to_string(),
                    ..Default::default()
                },
            ],
            34,
        );
        // Issued descending; same timestamp puts the later order first.
        let ids: Vec<i64> = rows.iter().map(|r| r.order_id).collect();
        assert_eq!(ids, vec![11, 10, 12]);
        assert!(rows[1].matches_selected_type);
        assert!(!rows[0].matches_selected_type);
        assert_eq!(rows[1].filled, 25_000);
    }

    #[test]
    fn character_order_rows_clamp_negative_remaining() {
        // Volumes decode from remote JSON unvalidated: a negative
        // remaining volume must render as zero remaining, never as a
        // raw negative count or an inflated filled amount.
        assert_eq!(filled_volume(50, -100), 50);
        assert_eq!(filled_fraction(50, -100), Some(1.0));
        let rows = character_order_rows(
            &[CharacterOrder {
                order_id: 20,
                type_id: 34,
                volume_remain: -100,
                volume_total: 50,
                issued: "2026-11-13T11:00:00Z".to_string(),
                ..Default::default()
            }],
            34,
        );
        assert_eq!(rows[0].volume_remain, 0);
        assert_eq!(rows[0].filled, 50);
    }

    #[test]
    fn history_summary_sorts_truncates_and_saturates() {
        let empty = summarize_history(&[]);
        assert_eq!(empty.days_returned, 0);
        assert!(empty.latest.is_none() && empty.recent.is_empty());
        assert_eq!(empty.recent_total_volume + empty.recent_total_orders, 0);
        let entries: Vec<MarketHistoryEntry> = (1..=35)
            .map(|day| MarketHistoryEntry {
                date: format!("2026-10-{day:02}"),
                average: day as f64,
                volume: 100,
                order_count: 2,
                ..Default::default()
            })
            .collect();
        let summary = summarize_history(&entries);
        assert_eq!(summary.days_returned, 35);
        assert_eq!(summary.latest.expect("latest").date, "2026-10-35");
        assert_eq!(summary.recent.len(), MARKET_HISTORY_ROWS);
        assert_eq!(summary.recent_total_volume, 3_000);
        assert_eq!(summary.recent_total_orders, 60);
        let overflow = summarize_history(&[
            MarketHistoryEntry {
                date: "2026-11-14".to_string(),
                volume: i64::MAX,
                order_count: i64::MAX,
                ..Default::default()
            },
            MarketHistoryEntry {
                date: "2026-11-13".to_string(),
                volume: i64::MAX,
                order_count: -5,
                ..Default::default()
            },
        ]);
        assert_eq!(overflow.recent_total_volume, i64::MAX);
        assert_eq!(overflow.recent_total_orders, i64::MAX);
    }

    #[test]
    fn labels_never_render_raw_ids_or_fake_prices() {
        assert_eq!(price_label(5.75), "5.75 ISK");
        assert_eq!(price_label(f64::NAN), "not available");
        assert_eq!(price_label(f64::INFINITY), "not available");
        let empty_resolver = NameResolver::new();
        assert_eq!(region_label(10000002, &empty_resolver), "The Forge (Jita)");
        assert_eq!(region_label(42, &empty_resolver), "Unknown Location");
        let mut resolver = NameResolver::new();
        resolver.insert(10000002, "The Forge".to_string());
        assert_eq!(region_label(10000002, &resolver), "The Forge");
        for region in MARKET_REGIONS {
            let label = region_label(region.id, &empty_resolver);
            assert!(label.parse::<i64>().is_err(), "raw id: {label}");
        }
    }

    #[test]
    fn quick_picks_dedup_sort_cap_and_empty() {
        let mut state = AppState::new(false);
        let resolver = NameResolver::new();
        assert!(quick_pick_types(&state, &resolver).is_empty());
        let mut named = NameResolver::new();
        named.insert(34, "Tritanium".to_string());
        named.insert(587, "Rifter".to_string());
        named.insert(35, "Pyerite".to_string());
        state.assets = LoadState::Ready(AssetsData {
            items: vec![
                AssetItem {
                    type_id: 34,
                    ..Default::default()
                },
                AssetItem {
                    type_id: 34,
                    ..Default::default()
                },
                AssetItem {
                    type_id: 587,
                    ..Default::default()
                },
            ],
            custom_names: Default::default(),
        });
        state.wallet = LoadState::Ready(WalletData {
            transactions: vec![
                WalletTransactionItem {
                    type_id: 587,
                    ..Default::default()
                },
                WalletTransactionItem {
                    type_id: 35,
                    ..Default::default()
                },
            ],
            ..Default::default()
        });
        let picks = quick_pick_types(&state, &named);
        assert_eq!(
            picks,
            vec![
                (35, "Pyerite".to_string()),
                (587, "Rifter".to_string()),
                (34, "Tritanium".to_string())
            ]
        );
        // Cap: 20 distinct asset types offer at most 12 rows.
        state.assets = LoadState::Ready(AssetsData {
            items: (1..=20)
                .map(|type_id| AssetItem {
                    type_id,
                    ..Default::default()
                })
                .collect(),
            custom_names: Default::default(),
        });
        state.wallet = LoadState::Loading;
        assert_eq!(quick_pick_types(&state, &named).len(), 12);
    }

    #[test]
    fn market_header_runs_headless_and_queues_one_type_icon() {
        use crate::app::state::PortraitState;
        use crate::portraits::ImageKind;

        let ctx = egui::Context::default();
        // Type 3300 is only the market selection, never a fitting;
        // the fixture has no loaded saved fittings.
        let mut state = AppState::new(false);
        state.set_market_selection(3300, "Type X".to_string());
        let resolver = NameResolver::new();
        let mut cache = PortraitImageCache::new();

        let mut full_output = ctx.run_ui(egui::RawInput::default(), |ui| {
            egui::CentralPanel::default().show(ui, |ui| {
                show(ui, &mut state, &resolver, &mut cache);
            });
        });
        full_output.textures_delta.clear();
        // Exactly one queued request for the selected type, and
        // the blank-box path uploads nothing.
        assert_eq!(state.portrait_requests, vec![(ImageKind::Type, 3300)]);
        assert!(matches!(
            state.portrait_state(ImageKind::Type, 3300),
            PortraitState::Loading
        ));
        assert!(cache.is_empty(), "no Ready image means no texture upload");

        // A second frame queues nothing new (already Loading).
        let mut full_output = ctx.run_ui(egui::RawInput::default(), |ui| {
            egui::CentralPanel::default().show(ui, |ui| {
                show(ui, &mut state, &resolver, &mut cache);
            });
        });
        full_output.textures_delta.clear();
        assert_eq!(state.portrait_requests, vec![(ImageKind::Type, 3300)]);

        // With no selection the header queues nothing at all.
        let mut unselected = AppState::new(false);
        assert_eq!(unselected.market_selected_type_id, None);
        let mut full_output = ctx.run_ui(egui::RawInput::default(), |ui| {
            egui::CentralPanel::default().show(ui, |ui| {
                show(ui, &mut unselected, &resolver, &mut cache);
            });
        });
        full_output.textures_delta.clear();
        assert!(unselected.portrait_requests.is_empty());
        assert!(cache.is_empty());
    }

    #[test]
    fn lookup_submit_sets_flags_only_for_nonempty_text() {
        let mut state = AppState::new(false);
        state.market_search = "   ".to_string();
        submit_lookup(&mut state);
        assert_eq!(state.market_lookup_requested, None);
        assert_eq!(state.market_lookup_generation, 0);
        assert_eq!(state.market_generation, 0);
        state.market_search = "  Tritanium  ".to_string();
        state.market_candidates = vec![UniverseName {
            id: 34,
            name: "Tritanium".to_string(),
            category: "inventory_type".to_string(),
        }];
        submit_lookup(&mut state);
        assert_eq!(state.market_lookup_requested.as_deref(), Some("Tritanium"));
        assert!(state.market_candidates.is_empty());
        assert!(state.market_lookup_message.is_some());
        assert_eq!(state.market_lookup_generation, 1);
        assert_eq!(state.market_generation, 0);
    }

    fn trade_state(buy: &str, sell: &str, broker: &str, tax: &str) -> AppState {
        let mut state = AppState::new(false);
        state.market_trade_buy_price = buy.to_string();
        state.market_trade_sell_price = sell.to_string();
        state.market_trade_broker_fee_percent = broker.to_string();
        state.market_trade_sales_tax_percent = tax.to_string();
        state
    }

    #[test]
    fn trade_calculator_wording_is_verbatim() {
        assert_eq!(TRADE_CALCULATOR_HEADING, "Trade Calculator");
        assert_eq!(
            TRADE_CALCULATOR_INPUT_LABELS,
            [
                "Buy Price (ISK)",
                "Sell Price (ISK)",
                "Broker Fee % (entered by you)",
                "Sales Tax % (entered by you)",
            ]
        );
        assert_eq!(
            TRADE_CALCULATOR_INPUT_GUIDANCE,
            "Enter a buy price and a sell price above 0 ISK, and fee percents from 0 to 100, to see the result."
        );
        assert_eq!(
            TRADE_CALCULATOR_NO_RESULT_GUIDANCE,
            "No result: the broker fee and sales tax together must be below 100%, and the prices must be small enough to calculate with."
        );
        assert_eq!(
            TRADE_CALCULATOR_DISCLOSURE,
            "Per-unit estimate using only the prices and percents you entered. \
             The broker fee is charged on both the buy and sell orders; sales tax is charged on the sell order only. \
             The starting percents (broker fee 1.0%, sales tax 2.0%) are starting values to replace with your own rates: \
             Mimir does not read them from your character's skills, standings, or the station or structure, and they may not be the rates you actually pay. \
             Relist fees and any quantity total are not included. \
             Figures are rounded only for display, so these numbers can differ from EVE."
        );
    }

    #[test]
    fn trade_calculator_full_result_block() {
        // buy_total = 101; sell_net = 116.4; profit = 15.4;
        // margin = 15.2475...; broker = 2.2; tax = 2.4; fees = 4.6;
        // break_even = 104.1237...
        let state = trade_state("100", "120", "1.0", "2.0");
        assert_eq!(
            trade_calculator_lines(&state),
            vec![
                "PROFITABLE",
                "15.40 ISK",
                "15.2% margin",
                "Buy Price: 100.00 ISK",
                "+ Broker Fee (buy): 1.00 ISK",
                "= Total Cost: 101.00 ISK",
                "Sell Price: 120.00 ISK",
                "- Broker Fee (sell): 1.20 ISK",
                "- Sales Tax: 2.40 ISK",
                "= Net Revenue: 116.40 ISK",
                "Profit / Unit: 15.40 ISK",
                "Total Fees: 4.60 ISK",
                "Break-Even Sell Price: 104.12 ISK",
                TRADE_CALCULATOR_DISCLOSURE,
            ]
        );
    }

    #[test]
    fn trade_calculator_omits_missing_break_even_line() {
        // Margin exists but break-even overflows: buy_total is
        // 1.5e300 and the sell factor is about 1e-11, so the
        // break-even quotient is non-finite and its line is
        // omitted entirely (never a computed-looking zero).
        let lines = trade_calculator_lines(&trade_state("1e300", "1e300", "50", "49.999999999"));
        assert_eq!(lines[0], "LOSS");
        assert_eq!(lines.len(), 13);
        assert!(lines
            .iter()
            .all(|line| !line.starts_with("Break-Even Sell Price")));
        assert_eq!(lines[12], TRADE_CALCULATOR_DISCLOSURE);
    }

    #[test]
    fn trade_calculator_loss_wording() {
        // Equal prices at the starting percents: profit -4.
        let loss = trade_calculator_lines(&trade_state("100", "100", "1.0", "2.0"));
        assert_eq!(loss[0], "LOSS");
        assert_eq!(loss[2], "-4.0% margin");
        // Zero fees and equal prices: a computed zero is shown.
        let zero = trade_calculator_lines(&trade_state("100", "100", "0.0", "0.0"));
        assert_eq!(zero[0], "LOSS");
        assert_eq!(zero[1], "0.00 ISK");
        assert_eq!(zero[2], "0.0% margin");
    }

    #[test]
    fn trade_calculator_guidance_selection() {
        // Empty drafts: exactly the input guidance plus disclosure.
        assert_eq!(
            trade_calculator_lines(&AppState::new(false)),
            vec![TRADE_CALCULATOR_INPUT_GUIDANCE, TRADE_CALCULATOR_DISCLOSURE,]
        );
        // Invalid drafts: the same, with no computed figure.
        assert_eq!(
            trade_calculator_lines(&trade_state("abc", "120", "1.0", "2.0")),
            vec![TRADE_CALCULATOR_INPUT_GUIDANCE, TRADE_CALCULATOR_DISCLOSURE,]
        );
        // All parse but 60 + 40 = 100: the no-result guidance.
        assert_eq!(
            trade_calculator_lines(&trade_state("100", "120", "60", "40")),
            vec![
                TRADE_CALCULATOR_NO_RESULT_GUIDANCE,
                TRADE_CALCULATOR_DISCLOSURE,
            ]
        );
    }

    #[test]
    fn trade_calculator_demo_independence() {
        use crate::demo::data::seed_demo_state;

        let mut state = trade_state("100", "120", "1.0", "2.0");
        seed_demo_state(&mut state);
        // Seeding installs the demo Tritanium book and leaves the
        // four drafts exactly as constructed: no prefill.
        assert!(state.market.is_ready());
        assert_eq!(state.market_selected_type_id, Some(34));
        assert_eq!(
            state
                .market
                .as_ready()
                .expect("demo market ready")
                .selection
                .type_name,
            "Tritanium"
        );
        assert_eq!(state.market_trade_buy_price, "100");
        assert_eq!(state.market_trade_sell_price, "120");
        assert_eq!(state.market_trade_broker_fee_percent, "1.0");
        assert_eq!(state.market_trade_sales_tax_percent, "2.0");
        // Typing the demo prices (best buy 5.50, best sell 5.75)
        // computes the section 8 case: profit 0.0225, margin 0.4%.
        state.market_trade_buy_price = "5.50".to_string();
        state.market_trade_sell_price = "5.75".to_string();
        let lines = trade_calculator_lines(&state);
        assert_eq!(lines[0], "PROFITABLE");
        assert_eq!(lines[1], "0.02 ISK");
        assert_eq!(lines[2], "0.4% margin");
    }
}
