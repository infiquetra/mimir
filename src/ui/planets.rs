//! Planetary Industry: the active character's colonies list and one
//! selected colony's summary, read-only. The view sets request
//! flags only (`retry_requested`, `stepup_requested`); it never
//! fetches. Every rendered string is a resolved EVE name, a
//! whitelist word, a fetched date, or a row count — never a raw
//! numeric ID.

use super::widgets;
use crate::app::state::{AppState, LoadState, PlanetaryData, SectionError, StepUpRequest};
use crate::config::EveConfig;
use crate::esi::models::{PlanetColony, PlanetPin};
use crate::names::resolver::NameResolver;
use chrono::{DateTime, Utc};

pub fn planet_type_label(planet_type: &str) -> &'static str {
    match planet_type {
        "temperate" => "Temperate",
        "barren" => "Barren",
        "gas" => "Gas",
        "ice" => "Ice",
        "lava" => "Lava",
        "oceanic" => "Oceanic",
        "plasma" => "Plasma",
        "storm" => "Storm",
        _ => "Unknown planet type",
    }
}

#[derive(Debug, Clone, PartialEq)]
pub struct ColonyRow {
    pub planet_id: i64,
    pub system_name: String,
    pub planet_type_label: &'static str,
    pub upgrade_level: i64,
    pub num_pins: i64,
    pub last_update: String,
}

pub fn colony_rows(colonies: &[PlanetColony], resolver: &NameResolver) -> Vec<ColonyRow> {
    let mut rows: Vec<ColonyRow> = colonies
        .iter()
        .map(|colony| ColonyRow {
            planet_id: colony.planet_id,
            system_name: resolver.location_name(colony.solar_system_id),
            planet_type_label: planet_type_label(&colony.planet_type),
            upgrade_level: colony.upgrade_level.max(0),
            num_pins: colony.num_pins.max(0),
            last_update: colony.last_update.clone(),
        })
        .collect();
    rows.sort_by(|a, b| {
        a.system_name
            .to_lowercase()
            .cmp(&b.system_name.to_lowercase())
            .then_with(|| a.system_name.cmp(&b.system_name))
            .then_with(|| a.planet_type_label.cmp(b.planet_type_label))
            .then(a.planet_id.cmp(&b.planet_id))
    });
    tracing::debug!("[PI] colony rows={}", rows.len());
    rows
}

#[derive(Debug, Clone, PartialEq)]
pub struct PinTypeCountRow {
    pub type_id: i64,
    pub type_name: String,
    pub count: usize,
}

pub fn pin_type_counts(pins: &[PlanetPin], resolver: &NameResolver) -> Vec<PinTypeCountRow> {
    let mut skipped: usize = 0;
    let mut rows: Vec<PinTypeCountRow> = Vec::new();
    for pin in pins {
        if pin.type_id <= 0 {
            skipped = skipped.saturating_add(1);
            continue;
        }
        if let Some(row) = rows.iter_mut().find(|r| r.type_id == pin.type_id) {
            row.count = row.count.saturating_add(1);
        } else {
            rows.push(PinTypeCountRow {
                type_id: pin.type_id,
                type_name: resolver.name(pin.type_id),
                count: 1,
            });
        }
    }
    rows.sort_by(|a, b| {
        b.count
            .cmp(&a.count)
            .then_with(|| a.type_name.to_lowercase().cmp(&b.type_name.to_lowercase()))
            .then_with(|| a.type_name.cmp(&b.type_name))
            .then(a.type_id.cmp(&b.type_id))
    });
    tracing::debug!(
        "[PI] pin type counts rows={} skipped={}",
        rows.len(),
        skipped
    );
    rows
}

#[derive(Debug, Clone, PartialEq)]
pub struct ExtractorProductRow {
    pub pin_id: i64,
    pub pin_type_name: String,
    pub product_name: String,
    pub qty_per_cycle: Option<i64>,
    pub cycle_time: Option<i64>,
}

pub fn extractor_product_rows(
    pins: &[PlanetPin],
    resolver: &NameResolver,
) -> Vec<ExtractorProductRow> {
    let mut rows: Vec<ExtractorProductRow> = pins
        .iter()
        .filter_map(|pin| {
            let details = pin.extractor_details.as_ref()?;
            let product_id = details.product_type_id.filter(|id| *id > 0)?;
            Some(ExtractorProductRow {
                pin_id: pin.pin_id,
                pin_type_name: resolver.name(pin.type_id),
                product_name: resolver.name(product_id),
                qty_per_cycle: details.qty_per_cycle.map(|v| v.max(0)),
                cycle_time: details.cycle_time.map(|v| v.max(0)),
            })
        })
        .collect();
    rows.sort_by(|a, b| {
        a.product_name
            .to_lowercase()
            .cmp(&b.product_name.to_lowercase())
            .then_with(|| a.product_name.cmp(&b.product_name))
            .then_with(|| a.pin_type_name.cmp(&b.pin_type_name))
            .then(a.pin_id.cmp(&b.pin_id))
    });
    tracing::debug!("[PI] extractor product rows={}", rows.len());
    rows
}

#[derive(Debug, Clone, PartialEq)]
pub struct StorageContentRow {
    pub type_id: i64,
    pub type_name: String,
    pub amount: i64,
}

pub fn storage_content_rows(pins: &[PlanetPin], resolver: &NameResolver) -> Vec<StorageContentRow> {
    let mut skipped: usize = 0;
    let mut rows: Vec<StorageContentRow> = Vec::new();
    for pin in pins {
        for entry in &pin.contents {
            if entry.type_id <= 0 {
                skipped = skipped.saturating_add(1);
                continue;
            }
            let amount = entry.amount.max(0);
            if let Some(row) = rows.iter_mut().find(|r| r.type_id == entry.type_id) {
                row.amount = row.amount.saturating_add(amount);
            } else {
                rows.push(StorageContentRow {
                    type_id: entry.type_id,
                    type_name: resolver.name(entry.type_id),
                    amount,
                });
            }
        }
    }
    rows.retain(|row| row.amount > 0);
    rows.sort_by(|a, b| {
        b.amount
            .cmp(&a.amount)
            .then_with(|| a.type_name.to_lowercase().cmp(&b.type_name.to_lowercase()))
            .then_with(|| a.type_name.cmp(&b.type_name))
            .then(a.type_id.cmp(&b.type_id))
    });
    tracing::debug!(
        "[PI] storage content rows={} skipped={}",
        rows.len(),
        skipped
    );
    rows
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ColonySummaryState {
    NoPins,
    NoExtractors,
    NoExpiryData,
    AllExpired,
    Extracting,
}

#[derive(Debug, Clone, PartialEq)]
pub struct ColonySummary {
    pub state: ColonySummaryState,
    pub status_label: &'static str,
    pub extractor_count: usize,
    pub active_extractor_count: usize,
    pub next_completion: Option<DateTime<Utc>>,
    pub next_completion_label: String,
    pub active_pins_label: String,
    pub state_note: Option<&'static str>,
}

/// One-pass colony summary over the loaded pins of one colony.
/// `reported_pins` is the colony's stored `num_pins` (rendered as
/// `Active Pins`, clamped at zero; `None` renders `N/A`), never
/// derived from `pins.len()`. `now` is an input, never sampled
/// here. An extractor pin is one whose extractor product ID is
/// present and positive; its expiry counts only when it parses
/// and lies strictly after `now`. Unparseable expiry strings are
/// ignored, never guessed or rendered.
pub fn colony_summary(
    pins: &[PlanetPin],
    reported_pins: Option<i64>,
    now: DateTime<Utc>,
) -> ColonySummary {
    let mut extractor_count: usize = 0;
    let mut active_extractor_count: usize = 0;
    let mut parsed_expiry: bool = false;
    let mut next_completion: Option<DateTime<Utc>> = None;
    let mut unparseable_expiry: usize = 0;
    for pin in pins {
        let is_extractor = pin
            .extractor_details
            .as_ref()
            .and_then(|details| details.product_type_id)
            .filter(|id| *id > 0)
            .is_some();
        if !is_extractor {
            continue;
        }
        extractor_count = extractor_count.saturating_add(1);
        let Some(expiry) = pin.expiry_time.as_deref().and_then(widgets::parse_esi_date) else {
            if pin.expiry_time.is_some() {
                unparseable_expiry = unparseable_expiry.saturating_add(1);
            }
            continue;
        };
        parsed_expiry = true;
        if expiry > now {
            active_extractor_count = active_extractor_count.saturating_add(1);
            next_completion = Some(match next_completion {
                Some(current) if current <= expiry => current,
                _ => expiry,
            });
        }
    }
    let state = if pins.is_empty() {
        ColonySummaryState::NoPins
    } else if extractor_count == 0 {
        ColonySummaryState::NoExtractors
    } else if active_extractor_count > 0 {
        ColonySummaryState::Extracting
    } else if !parsed_expiry {
        ColonySummaryState::NoExpiryData
    } else {
        ColonySummaryState::AllExpired
    };
    let status_label = if state == ColonySummaryState::Extracting {
        "Extracting"
    } else {
        "Idle"
    };
    let next_completion_label = match next_completion {
        Some(expiry) => format!(
            "in {}",
            widgets::format_countdown((expiry - now).num_seconds())
        ),
        None => "N/A".to_string(),
    };
    let active_pins_label = match reported_pins {
        Some(n) => n.max(0).to_string(),
        None => "N/A".to_string(),
    };
    let state_note = match state {
        ColonySummaryState::NoPins | ColonySummaryState::Extracting => None,
        ColonySummaryState::NoExtractors => {
            Some("No extractor pins were reported, so nothing is extracting.")
        }
        ColonySummaryState::NoExpiryData => {
            Some("No extractor reported an expiry time, so no completion can be shown.")
        }
        ColonySummaryState::AllExpired => Some("All extractor expiry times are in the past."),
    };
    tracing::debug!(
        "[PI] colony summary pins={} extractors={} active={} state={:?} unparseable_expiry={}",
        pins.len(),
        extractor_count,
        active_extractor_count,
        state,
        unparseable_expiry
    );
    ColonySummary {
        state,
        status_label,
        extractor_count,
        active_extractor_count,
        next_completion,
        next_completion_label,
        active_pins_label,
        state_note,
    }
}

/// True when any extractor pin has a parseable expiry strictly
/// after `now` — the same active test [`colony_summary`] uses,
/// without its counting or logging. The shell uses it to keep
/// the colony countdown repainting while extraction runs.
pub fn has_active_extractor(pins: &[PlanetPin], now: DateTime<Utc>) -> bool {
    pins.iter().any(|pin| {
        let is_extractor = pin
            .extractor_details
            .as_ref()
            .and_then(|details| details.product_type_id)
            .filter(|id| *id > 0)
            .is_some();
        is_extractor
            && pin
                .expiry_time
                .as_deref()
                .and_then(widgets::parse_esi_date)
                .is_some_and(|expiry| expiry > now)
    })
}

pub const PIN_TYPE_RENDER_MAX: usize = 100;
pub const EXTRACTOR_RENDER_MAX: usize = 100;
pub const STORAGE_RENDER_MAX: usize = 100;

/// Uniform per-section failure line, copying the industry helper:
/// a scope failure points at the step-up panel above when it is
/// showing. The typed flag is branched on, never the message.
fn section_error_label(ui: &mut egui::Ui, section: &str, error: &SectionError, panel_shown: bool) {
    if error.needs_reauthorize && panel_shown {
        ui.label("Not authorized yet. Re-authorize above to load this section.");
    } else if error.needs_reauthorize {
        ui.label("Not authorized yet for this character.");
    } else {
        ui.label(format!("Could not load {section}: {}", error.message));
    }
}

fn planetary_reauthorize_panel(ui: &mut egui::Ui, state: &mut AppState) {
    ui.heading("Planetary Industry needs one more EVE permission.");
    ui.label(format!(
        "Colonies and colony detail will not load for this character \
         until this EVE SSO scope is granted: {}. Other views are unaffected.",
        EveConfig::PLANETS_SCOPES.join(" ")
    ));
    let active_id = state.active_character_id;
    if let Some(name) = state.active_character().map(|c| c.name.clone()) {
        ui.label(format!(
            "Choose Re-authorize and Mimir opens EVE SSO in your browser for {name}, \
             asking for the permissions already granted plus these. Sign in as \
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
                "[AUTH] step-up re-authorize requested from Planets view character_id={} scopes={}",
                active_id,
                EveConfig::PLANETS_SCOPES.join(" ")
            );
            state.stepup_requested = Some(StepUpRequest::new(active_id, EveConfig::PLANETS_SCOPES));
            state.status_message =
                "EVE SSO requested: your browser should open to login.eveonline.com.".to_string();
        }
    }
}

fn show_colonies_section(
    ui: &mut egui::Ui,
    state: &mut AppState,
    colonies: &crate::app::state::SectionResult<Vec<PlanetColony>>,
    resolver: &NameResolver,
    panel_shown: bool,
) {
    ui.heading("Colonies");
    match colonies {
        Err(error) => section_error_label(ui, "colonies", error, panel_shown),
        Ok(colonies) => {
            let rows = colony_rows(colonies, resolver);
            if rows.is_empty() {
                ui.label("No colonies for this character.");
                return;
            }
            ui.label(format!("{} colonies loaded.", rows.len()));
            for row in &rows {
                let selected = Some(row.planet_id) == state.planetary_selected_planet_id;
                let text = format!("{} \u{2014} {}", row.system_name, row.planet_type_label);
                if ui.selectable_label(selected, text).clicked() {
                    state.set_planetary_selection(row.planet_id);
                }
                ui.label(format!("Upgrade level: {}", row.upgrade_level));
                ui.label(format!("Pins: {}", row.num_pins));
                if !row.last_update.is_empty() {
                    ui.label(format!(
                        "Last update: {}",
                        widgets::format_date_short(&row.last_update)
                    ));
                }
            }
        }
    }
}

fn show_detail_section(
    ui: &mut egui::Ui,
    state: &mut AppState,
    bundle: &PlanetaryData,
    resolver: &NameResolver,
    panel_shown: bool,
) {
    ui.heading("Selected colony");
    let Some(selected_planet) = state.planetary_selected_planet_id else {
        ui.label("Select a colony above to see its pins, extractors, and stored items.");
        return;
    };
    let matching = bundle.detail.as_ref().filter(|d| {
        d.selection.planet_id == selected_planet
            && Some(d.selection.character_id) == state.active_character_id
    });
    let Some(detail) = matching else {
        widgets::loading_panel(ui, "Loading colony detail...");
        return;
    };
    match &detail.result {
        Err(error) => section_error_label(ui, "colony detail", error, panel_shown),
        Ok(detail) => {
            let pins = &detail.pins;
            let now = Utc::now();
            let reported_pins = match &bundle.colonies {
                Ok(colonies) => colonies
                    .iter()
                    .find(|colony| colony.planet_id == selected_planet)
                    .map(|colony| colony.num_pins),
                Err(_) => None,
            };
            let summary = colony_summary(pins, reported_pins, now);
            ui.heading("Colony summary");
            match summary.state {
                ColonySummaryState::NoPins => {
                    ui.label("No pins were reported for this colony.");
                }
                _ => {
                    ui.label(format!("Status: {}", summary.status_label));
                    ui.label(format!("Active Pins: {}", summary.active_pins_label));
                    ui.label(format!(
                        "Next Completion: {}",
                        summary.next_completion_label
                    ));
                    ui.label(format!("Extractors: {}", summary.extractor_count));
                    if let Some(note) = summary.state_note {
                        ui.label(note);
                    }
                }
            }
            ui.heading("Pin types");
            let pin_rows = pin_type_counts(pins, resolver);
            if pin_rows.is_empty() {
                ui.label("No pins were reported for this colony.");
            } else {
                if pin_rows.len() > PIN_TYPE_RENDER_MAX {
                    ui.label(format!(
                        "Showing {} of {} pin types.",
                        PIN_TYPE_RENDER_MAX,
                        pin_rows.len()
                    ));
                }
                for row in pin_rows.iter().take(PIN_TYPE_RENDER_MAX) {
                    ui.label(format!("{} \u{00d7} {}", row.count, row.type_name));
                }
            }
            ui.heading("Extractors");
            let extractor_rows = extractor_product_rows(pins, resolver);
            if extractor_rows.is_empty() {
                ui.label("No extractors were reported for this colony.");
            } else {
                if extractor_rows.len() > EXTRACTOR_RENDER_MAX {
                    ui.label(format!(
                        "Showing {} of {} extractors.",
                        EXTRACTOR_RENDER_MAX,
                        extractor_rows.len()
                    ));
                }
                for row in extractor_rows.iter().take(EXTRACTOR_RENDER_MAX) {
                    ui.label(format!(
                        "{} \u{2014} {}",
                        row.product_name, row.pin_type_name
                    ));
                    if let Some(qty) = row.qty_per_cycle {
                        ui.label(format!("Quantity per cycle: {qty}"));
                    }
                    if let Some(cycle) = row.cycle_time {
                        ui.label(format!("Cycle time: {cycle} seconds"));
                    }
                }
            }
            ui.heading("Stored items");
            let storage_rows = storage_content_rows(pins, resolver);
            if storage_rows.is_empty() {
                ui.label("No stored items were reported for this colony.");
            } else {
                if storage_rows.len() > STORAGE_RENDER_MAX {
                    ui.label(format!(
                        "Showing {} of {} stored items.",
                        STORAGE_RENDER_MAX,
                        storage_rows.len()
                    ));
                }
                for row in storage_rows.iter().take(STORAGE_RENDER_MAX) {
                    ui.label(format!("{} \u{00d7} {}", row.amount, row.type_name));
                }
            }
        }
    }
}

pub fn show(ui: &mut egui::Ui, state: &mut AppState, resolver: &NameResolver) {
    ui.heading("Planetary Industry");
    widgets::mode_notice(ui, state.demo, state.offline);
    if state.active_character().is_none() {
        widgets::no_character_panel(ui);
        return;
    }
    // Clone the snapshot so the step-up button and selectable rows
    // can borrow `state` mutably.
    let snapshot: LoadState<PlanetaryData> = state.planetary.clone();
    match snapshot {
        LoadState::Loading => widgets::loading_panel(ui, "Loading planetary data..."),
        LoadState::Empty => widgets::empty_panel(ui, "No planetary data yet."),
        LoadState::Error(e) => {
            if widgets::error_panel_with_retry(ui, &e) {
                tracing::warn!("[PI] retry requested after load error");
                state.retry_requested = true;
            }
        }
        LoadState::Ready(bundle) => {
            let panel_shown = !state.demo
                && state.active_character_id.is_some()
                && bundle.needs_planetary_stepup();
            if panel_shown {
                tracing::debug!("[PI] showing step-up guidance (missing planetary scope)");
                planetary_reauthorize_panel(ui, state);
            }
            show_colonies_section(ui, state, &bundle.colonies, resolver, panel_shown);
            show_detail_section(ui, state, &bundle, resolver, panel_shown);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::esi::models::{ExtractorDetails, PinContent};

    fn resolver() -> NameResolver {
        let mut r = NameResolver::new();
        r.insert(20001, "Demo Extractor".to_string());
        r.insert(20002, "Demo Factory".to_string());
        r.insert(20003, "Demo Storage".to_string());
        r.insert(34, "Tritanium".to_string());
        r.insert(35, "Pyerite".to_string());
        r.insert(36, "Mexallon".to_string());
        r.insert(37, "Isogen".to_string());
        r.insert(16679, "Ferrogel".to_string());
        r.insert(30000142, "Jita".to_string());
        r.insert(30002187, "Amarr".to_string());
        r
    }

    fn colony(
        planet_id: i64,
        planet_type: &str,
        system: i64,
        level: i64,
        pins: i64,
    ) -> PlanetColony {
        PlanetColony {
            planet_id,
            planet_type: planet_type.to_string(),
            solar_system_id: system,
            last_update: "2026-11-14T10:00:00Z".to_string(),
            upgrade_level: level,
            num_pins: pins,
        }
    }

    fn pin(pin_id: i64, type_id: i64) -> PlanetPin {
        PlanetPin {
            pin_id,
            type_id,
            ..Default::default()
        }
    }

    fn now() -> DateTime<Utc> {
        widgets::parse_esi_date("2026-11-15T12:00:00Z").expect("fixed test date parses")
    }

    fn extractor_pin(pin_id: i64, product_id: Option<i64>, expiry: Option<&str>) -> PlanetPin {
        PlanetPin {
            pin_id,
            type_id: 20001,
            expiry_time: expiry.map(str::to_string),
            extractor_details: Some(ExtractorDetails {
                product_type_id: product_id,
                qty_per_cycle: None,
                cycle_time: None,
            }),
            ..Default::default()
        }
    }

    #[test]
    fn has_active_extractor_matches_summary_active_test() {
        let future = extractor_pin(700000011, Some(34), Some("2026-11-20T12:00:00Z"));
        assert!(has_active_extractor(&[future], now()));
        let past = extractor_pin(700000011, Some(34), Some("2026-11-15T12:00:00Z"));
        assert!(!has_active_extractor(&[past], now()));
        let no_product = extractor_pin(700000011, None, Some("2026-11-20T12:00:00Z"));
        assert!(!has_active_extractor(&[no_product], now()));
        let unparseable = extractor_pin(700000011, Some(34), Some("not a date"));
        assert!(!has_active_extractor(&[unparseable], now()));
        assert!(!has_active_extractor(&[], now()));
    }

    #[test]
    fn colony_summary_empty_pins() {
        let summary = colony_summary(&[], Some(4), now());
        assert_eq!(summary.state, ColonySummaryState::NoPins);
        assert_eq!(summary.status_label, "Idle");
        assert_eq!(summary.extractor_count, 0);
        assert_eq!(summary.active_extractor_count, 0);
        assert_eq!(summary.next_completion, None);
        assert_eq!(summary.next_completion_label, "N/A");
        assert_eq!(summary.active_pins_label, "4");
        assert_eq!(summary.state_note, None);
    }

    #[test]
    fn colony_summary_non_extractors_cannot_activate() {
        let mut plain = pin(700000011, 20002);
        plain.expiry_time = Some("2026-11-20T12:00:00Z".to_string());
        let no_product = extractor_pin(700000012, None, Some("2026-11-20T12:00:00Z"));
        let summary = colony_summary(&[plain, no_product], Some(2), now());
        assert_eq!(summary.state, ColonySummaryState::NoExtractors);
        assert_eq!(summary.status_label, "Idle");
        assert_eq!(summary.extractor_count, 0);
        assert_eq!(summary.active_extractor_count, 0);
        assert_eq!(summary.next_completion, None);
        assert_eq!(summary.next_completion_label, "N/A");
        assert_eq!(
            summary.state_note,
            Some("No extractor pins were reported, so nothing is extracting.")
        );
    }

    #[test]
    fn colony_summary_non_positive_products_do_not_count() {
        let zero = extractor_pin(700000011, Some(0), Some("2026-11-20T12:00:00Z"));
        let negative = extractor_pin(700000012, Some(-3), Some("2026-11-20T12:00:00Z"));
        let summary = colony_summary(&[zero, negative], Some(2), now());
        assert_eq!(summary.state, ColonySummaryState::NoExtractors);
        assert_eq!(summary.extractor_count, 0);
        assert_eq!(summary.active_extractor_count, 0);
        // Mixed set: those two plus one expired valid extractor; the
        // summary count equals the extractors section row count.
        let pins = vec![
            extractor_pin(700000011, Some(0), Some("2026-11-20T12:00:00Z")),
            extractor_pin(700000012, Some(-3), Some("2026-11-20T12:00:00Z")),
            extractor_pin(700000013, Some(34), Some("2026-11-14T12:00:00Z")),
        ];
        let summary = colony_summary(&pins, Some(3), now());
        assert_eq!(summary.extractor_count, 1);
        assert_eq!(
            summary.extractor_count,
            extractor_product_rows(&pins, &resolver()).len()
        );
        assert_eq!(summary.state, ColonySummaryState::AllExpired);
    }

    #[test]
    fn colony_summary_no_expiry_data() {
        let pins = vec![
            extractor_pin(700000011, Some(34), None),
            extractor_pin(700000012, Some(34), Some("")),
            extractor_pin(700000013, Some(34), Some("not-a-date")),
        ];
        let summary = colony_summary(&pins, Some(3), now());
        assert_eq!(summary.state, ColonySummaryState::NoExpiryData);
        assert_eq!(summary.status_label, "Idle");
        assert_eq!(summary.extractor_count, 3);
        assert_eq!(summary.active_extractor_count, 0);
        assert_eq!(summary.next_completion, None);
        assert_eq!(summary.next_completion_label, "N/A");
        assert_eq!(
            summary.state_note,
            Some("No extractor reported an expiry time, so no completion can be shown.")
        );
    }

    #[test]
    fn colony_summary_all_expired_strict_boundary() {
        let pins = vec![
            // Exactly `now`: inactive by strictness.
            extractor_pin(700000011, Some(34), Some("2026-11-15T12:00:00Z")),
            extractor_pin(700000012, Some(34), Some("2026-11-14T12:00:00Z")),
            // An unparseable sibling changes nothing.
            extractor_pin(700000013, Some(34), Some("700000001")),
        ];
        let summary = colony_summary(&pins, Some(3), now());
        assert_eq!(summary.state, ColonySummaryState::AllExpired);
        assert_eq!(summary.status_label, "Idle");
        assert_eq!(summary.extractor_count, 3);
        assert_eq!(summary.active_extractor_count, 0);
        assert_eq!(summary.next_completion, None);
        assert_eq!(summary.next_completion_label, "N/A");
        assert_eq!(
            summary.state_note,
            Some("All extractor expiry times are in the past.")
        );
    }

    #[test]
    fn colony_summary_earliest_future_wins() {
        let pins = vec![
            extractor_pin(700000011, Some(34), Some("2026-11-21T08:00:00Z")),
            extractor_pin(700000012, Some(36), Some("2026-11-17T12:00:00Z")),
            extractor_pin(700000013, Some(34), Some("2026-11-10T12:00:00Z")),
            extractor_pin(700000014, Some(34), Some("700000001")),
        ];
        let summary = colony_summary(&pins, Some(4), now());
        assert_eq!(summary.state, ColonySummaryState::Extracting);
        assert_eq!(summary.status_label, "Extracting");
        assert_eq!(summary.extractor_count, 4);
        assert_eq!(summary.active_extractor_count, 2);
        assert_eq!(
            summary.next_completion,
            widgets::parse_esi_date("2026-11-17T12:00:00Z")
        );
        assert_eq!(summary.next_completion_label, "in 2d 0h 0m");
        assert_eq!(summary.state_note, None);
        // Reversed input order yields an equal summary.
        let mut reversed = pins.clone();
        reversed.reverse();
        assert_eq!(colony_summary(&reversed, Some(4), now()), summary);
    }

    #[test]
    fn colony_summary_duration_edges() {
        // 30 seconds out.
        let pins = vec![extractor_pin(
            700000011,
            Some(34),
            Some("2026-11-15T12:00:30Z"),
        )];
        assert_eq!(
            colony_summary(&pins, Some(1), now()).next_completion_label,
            "in 30s"
        );
        // 60 seconds out.
        let pins = vec![extractor_pin(
            700000011,
            Some(34),
            Some("2026-11-15T12:01:00Z"),
        )];
        assert_eq!(
            colony_summary(&pins, Some(1), now()).next_completion_label,
            "in 1m"
        );
        // Half a second of future: `num_seconds()` truncates to 0,
        // still Extracting with `in 0m`, never a negative string.
        let half_now =
            widgets::parse_esi_date("2026-11-15T12:00:00.500Z").expect("fixed test date parses");
        let pins = vec![extractor_pin(
            700000011,
            Some(34),
            Some("2026-11-15T12:00:01Z"),
        )];
        let summary = colony_summary(&pins, Some(1), half_now);
        assert_eq!(summary.state, ColonySummaryState::Extracting);
        assert_eq!(summary.next_completion_label, "in 0m");
    }

    #[test]
    fn colony_summary_demo_colony() {
        // The design section 9 fixture, rebuilt as literals:
        // two extractors expiring 2026-11-21T08:00:00Z, one bare
        // pin, one pin with an explicit null expiry.
        let pins = vec![
            extractor_pin(700000011, Some(34), Some("2026-11-21T08:00:00Z")),
            extractor_pin(700000012, Some(36), Some("2026-11-21T08:00:00Z")),
            pin(700000013, 20002),
            pin(700000014, 20003),
        ];
        let summary = colony_summary(&pins, Some(4), now());
        assert_eq!(summary.state, ColonySummaryState::Extracting);
        assert_eq!(summary.status_label, "Extracting");
        assert_eq!(summary.extractor_count, 2);
        assert_eq!(summary.active_extractor_count, 2);
        assert_eq!(
            summary.next_completion,
            widgets::parse_esi_date("2026-11-21T08:00:00Z")
        );
        // 6 days minus 4 hours = 504,000 seconds.
        assert_eq!(summary.next_completion_label, "in 5d 20h 0m");
        assert_eq!(summary.active_pins_label, "4");
        assert_eq!(summary.state_note, None);
    }

    #[test]
    fn colony_summary_reported_count_arms() {
        let pins = vec![
            extractor_pin(700000011, Some(34), Some("2026-11-21T08:00:00Z")),
            extractor_pin(700000012, Some(36), Some("2026-11-17T12:00:00Z")),
            extractor_pin(700000013, Some(34), Some("2026-11-10T12:00:00Z")),
            extractor_pin(700000014, Some(34), Some("700000001")),
        ];
        let clamped = colony_summary(&pins, Some(-2), now());
        let missing = colony_summary(&pins, None, now());
        let reported = colony_summary(&pins, Some(40), now());
        assert_eq!(clamped.active_pins_label, "0", "negative clamps to 0");
        assert_eq!(missing.active_pins_label, "N/A");
        assert_eq!(
            reported.active_pins_label, "40",
            "reported count wins, never pins.len()"
        );
        fn pins_fields(summary: &ColonySummary) -> (ColonySummaryState, usize, usize, String) {
            (
                summary.state,
                summary.extractor_count,
                summary.active_extractor_count,
                summary.next_completion_label.clone(),
            )
        }
        assert_eq!(pins_fields(&clamped), pins_fields(&missing));
        assert_eq!(pins_fields(&missing), pins_fields(&reported));
    }

    #[test]
    fn planet_type_whitelist_covers_all_words_and_fallback() {
        assert_eq!(planet_type_label("temperate"), "Temperate");
        assert_eq!(planet_type_label("barren"), "Barren");
        assert_eq!(planet_type_label("gas"), "Gas");
        assert_eq!(planet_type_label("ice"), "Ice");
        assert_eq!(planet_type_label("lava"), "Lava");
        assert_eq!(planet_type_label("oceanic"), "Oceanic");
        assert_eq!(planet_type_label("plasma"), "Plasma");
        assert_eq!(planet_type_label("storm"), "Storm");
        for other in ["", "Temperate", "VOLCANIC", "123", "unknown"] {
            assert_eq!(planet_type_label(other), "Unknown planet type", "{other}");
            assert!(planet_type_label(other).parse::<i64>().is_err());
        }
    }

    #[test]
    fn colony_rows_sort_clamp_and_resolve() {
        let mut negative = colony(700000003, "bogus", 30000142, -2, -1);
        negative.last_update = String::new();
        let colonies = vec![
            colony(700000002, "oceanic", 30002187, 1, 2),
            colony(700000001, "temperate", 30000142, 2, 4),
            negative,
            // Same system and type: planet_id tie-breaks.
            colony(700000004, "temperate", 30000142, 0, 0),
        ];
        let rows = colony_rows(&colonies, &resolver());
        assert_eq!(rows.len(), 4);
        // Amarr sorts before Jita by name.
        assert_eq!(rows[0].system_name, "Amarr");
        assert_eq!(rows[0].planet_id, 700000002);
        assert_eq!(rows[1].system_name, "Jita");
        assert_eq!(rows[1].planet_type_label, "Temperate");
        assert_eq!(rows[1].planet_id, 700000001);
        assert_eq!(rows[2].planet_id, 700000004);
        // Unknown type sorts last within Jita by label.
        assert_eq!(rows[3].planet_type_label, "Unknown planet type");
        assert_eq!(rows[3].upgrade_level, 0, "negative level clamps to 0");
        assert_eq!(rows[3].num_pins, 0, "negative pins clamp to 0");
        assert!(colony_rows(&[], &resolver()).is_empty());
    }

    #[test]
    fn pin_type_counts_group_skip_and_sort() {
        let pins = vec![
            pin(700000011, 20001),
            pin(700000012, 20001),
            pin(700000013, 20002),
            pin(700000014, 20001),
            pin(700000015, 0),
            pin(700000016, -7),
            pin(700000017, 20003),
        ];
        let rows = pin_type_counts(&pins, &resolver());
        assert_eq!(rows.len(), 3);
        // Count descending, then name.
        assert_eq!(rows[0].type_name, "Demo Extractor");
        assert_eq!(rows[0].count, 3);
        assert_eq!(rows[1].type_name, "Demo Factory");
        assert_eq!(rows[1].count, 1);
        assert_eq!(rows[2].type_name, "Demo Storage");
        assert_eq!(rows[2].count, 1);
        assert_eq!(rows[0].type_id, 20001);
        assert!(pin_type_counts(&[], &resolver()).is_empty());
    }

    #[test]
    fn extractor_rows_exclude_missing_product_clamp_and_keep_none() {
        let mut full = pin(700000011, 20001);
        full.extractor_details = Some(ExtractorDetails {
            product_type_id: Some(34),
            qty_per_cycle: Some(120),
            cycle_time: Some(7200),
        });
        let mut null_qty = pin(700000012, 20001);
        null_qty.extractor_details = Some(ExtractorDetails {
            product_type_id: Some(36),
            qty_per_cycle: None,
            cycle_time: Some(-5),
        });
        let mut no_product = pin(700000013, 20001);
        no_product.extractor_details = Some(ExtractorDetails {
            product_type_id: None,
            qty_per_cycle: Some(9),
            cycle_time: Some(9),
        });
        let mut zero_product = pin(700000014, 20001);
        zero_product.extractor_details = Some(ExtractorDetails {
            product_type_id: Some(0),
            qty_per_cycle: Some(9),
            cycle_time: Some(9),
        });
        let mut negative_qty = pin(700000015, 20001);
        negative_qty.extractor_details = Some(ExtractorDetails {
            product_type_id: Some(16679),
            qty_per_cycle: Some(-50),
            cycle_time: None,
        });
        let plain = pin(700000016, 20002);
        let rows = extractor_product_rows(
            &[
                full,
                null_qty,
                no_product,
                zero_product,
                negative_qty,
                plain,
            ],
            &resolver(),
        );
        assert_eq!(rows.len(), 3, "only pins with a positive product");
        // Sorted by product name: Ferrogel, Mexallon, Tritanium.
        assert_eq!(rows[0].product_name, "Ferrogel");
        assert_eq!(rows[0].qty_per_cycle, Some(0), "negative qty clamps to 0");
        assert_eq!(rows[0].cycle_time, None, "None stays None");
        assert_eq!(rows[1].product_name, "Mexallon");
        assert_eq!(rows[1].qty_per_cycle, None, "None stays None");
        assert_eq!(rows[1].cycle_time, Some(0), "negative cycle clamps to 0");
        assert_eq!(rows[2].product_name, "Tritanium");
        assert_eq!(rows[2].qty_per_cycle, Some(120));
        assert_eq!(rows[2].cycle_time, Some(7200));
        assert_eq!(rows[2].pin_type_name, "Demo Extractor");
        assert!(extractor_product_rows(&[], &resolver()).is_empty());
    }

    #[test]
    fn storage_rows_clamp_saturate_drop_zero_and_skip() {
        let mut first = pin(700000011, 20001);
        first.contents = vec![
            PinContent {
                type_id: 35,
                amount: 500,
            },
            PinContent {
                type_id: 36,
                amount: 250,
            },
            PinContent {
                type_id: 0,
                amount: 100,
            },
        ];
        let mut second = pin(700000012, 20002);
        second.contents = vec![
            PinContent {
                type_id: 35,
                amount: 300,
            },
            PinContent {
                type_id: 37,
                amount: -50,
            },
            PinContent {
                type_id: -4,
                amount: 100,
            },
        ];
        let mut saturated = pin(700000013, 20002);
        saturated.contents = vec![
            PinContent {
                type_id: 16679,
                amount: i64::MAX,
            },
            PinContent {
                type_id: 16679,
                amount: i64::MAX,
            },
        ];
        let mut zero_group = pin(700000014, 20003);
        zero_group.contents = vec![PinContent {
            type_id: 34,
            amount: 0,
        }];
        let rows = storage_content_rows(&[first, second, saturated, zero_group], &resolver());
        assert_eq!(rows.len(), 3, "zero-total Tritanium group is dropped");
        assert_eq!(rows[0].type_name, "Ferrogel");
        assert_eq!(rows[0].amount, i64::MAX, "saturates, never overflows");
        // Aggregation across pins of one shared type.
        assert_eq!(rows[1].type_name, "Pyerite");
        assert_eq!(rows[1].amount, 800);
        assert_eq!(rows[2].type_name, "Mexallon");
        assert_eq!(rows[2].amount, 250);
        assert!(storage_content_rows(&[], &resolver()).is_empty());
    }

    #[test]
    fn render_caps_cover_one_hundred_rows() {
        let pins: Vec<PlanetPin> = (0..(PIN_TYPE_RENDER_MAX as i64 + 5))
            .map(|i| {
                let mut p = pin(700100000 + i, if i % 2 == 0 { 20001 } else { 20002 });
                p.contents = vec![PinContent {
                    type_id: 34,
                    amount: 1,
                }];
                p
            })
            .collect();
        let counts = pin_type_counts(&pins, &resolver());
        assert_eq!(counts.len(), 2);
        let shown = counts.len().min(PIN_TYPE_RENDER_MAX);
        assert_eq!(shown, 2);
        let storage = storage_content_rows(&pins, &resolver());
        assert_eq!(storage.len(), 1);
        assert_eq!(storage[0].amount, PIN_TYPE_RENDER_MAX as i64 + 5);
        assert_eq!(PIN_TYPE_RENDER_MAX, 100);
        assert_eq!(EXTRACTOR_RENDER_MAX, 100);
        assert_eq!(STORAGE_RENDER_MAX, 100);
    }

    #[test]
    fn empty_resolver_never_renders_raw_ids() {
        let pins = vec![pin(700000011, 20001)];
        let counts = pin_type_counts(&pins, &NameResolver::new());
        assert_eq!(counts[0].type_name, "Unknown Item");
        assert!(counts[0].type_name.parse::<i64>().is_err());
        let rows = colony_rows(
            &[colony(700000001, "temperate", 30000142, 2, 4)],
            &NameResolver::new(),
        );
        assert_eq!(rows[0].system_name, "Unknown Location");
        assert!(rows[0].system_name.parse::<i64>().is_err());
    }
}
