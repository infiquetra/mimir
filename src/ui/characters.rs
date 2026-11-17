//! Characters: switcher list/detail, add via EVE SSO, delete/logout,
//! plus the read-only character-detail sections (status, attributes,
//! active implants, jump clones, standings) below the public-info block.
//! Corporation and alliance cells use resolved names, never raw IDs.
//! Auth and persistence run in F1/F2: this view only sets the request
//! flags on `AppState` and reflects `AuthState`.

use super::portraits::{self, PortraitImageCache};
use super::widgets;
use crate::app::state::{
    ship_display_name, AppState, AuthState, CharacterDetailData, LoadState, PortraitState,
    SectionError, StepUpRequest,
};
use crate::config::EveConfig;
use crate::esi::models::{CharacterAttributes, JumpClone, Standing};
use crate::names::resolver::NameResolver;

pub fn show(
    ui: &mut egui::Ui,
    state: &mut AppState,
    resolver: &NameResolver,
    cache: &mut PortraitImageCache,
) {
    ui.heading("Characters");
    widgets::mode_notice(ui, state.demo, state.offline);
    // Portraits for every visible character: freed textures for
    // removed characters go first, then one fetch is queued per
    // character that has no portrait in flight or failed yet. In
    // demo mode the shell drains without spawning, so this makes
    // zero network calls and every portrait stays a placeholder.
    cache.prune(&state.characters);
    let visible_ids: Vec<i64> = state.characters.iter().map(|c| c.character_id).collect();
    for id in visible_ids {
        portraits::ensure_portrait_requested(state, id);
    }

    // --- Auth status + add-character ---
    ui.label(format!("Sign-in: {}", state.auth.label()));
    if state.auth.is_busy() {
        ui.spinner();
        ui.label("Complete the EVE login in your browser; Mimir is waiting on 127.0.0.1:54321.");
    }
    ui.horizontal(|ui| {
        let add_enabled = !state.auth.is_busy();
        if ui
            .add_enabled(add_enabled, egui::Button::new("Add character (EVE SSO)"))
            .clicked()
        {
            tracing::info!("[AUTH] add-character requested from Characters view");
            state.login_requested = true;
            state.status_message =
                "EVE SSO requested: your browser should open to login.eveonline.com.".to_string();
        }
        if state.characters.is_empty() && ui.button("Try demo").clicked() {
            tracing::info!("[DEMO] demo requested from Characters view");
            state.demo = true;
            crate::demo::data::seed_demo_state(state);
        }
    });
    if state.auth == AuthState::Error {
        ui.colored_label(
            egui::Color32::LIGHT_RED,
            "Sign-in failed. Check the log in Settings (key 5), then try again.",
        );
    }

    if state.characters.is_empty() {
        widgets::no_character_panel(ui);
        return;
    }

    // --- Switcher list (PageUp/PageDown also cycles, see shell) ---
    ui.separator();
    ui.heading("Switch character (PageUp/PageDown)");
    let mut switch_to: Option<i64> = None;
    let rows: Vec<(i64, String, String, Option<String>, bool)> = state
        .characters
        .iter()
        .map(|c| {
            (
                c.character_id,
                c.name.clone(),
                resolver.name(c.corporation_id),
                c.alliance_id.map(|id| resolver.name(id)),
                c.is_active,
            )
        })
        .collect();
    egui::Grid::new("switcher_portraits").show(ui, |ui| {
        for (id, name, corp, alliance, is_active) in &rows {
            portraits::show_portrait(ui, cache, state, *id, name, portraits::LIST_PORTRAIT_PX);
            let mut label = format!("{} — {}", name, corp);
            if let Some(alliance) = alliance {
                label.push_str(&format!(" / {}", alliance));
            }
            if *is_active {
                label.push_str(" (active)");
            }
            if ui.selectable_label(*is_active, label).clicked() {
                switch_to = Some(*id);
            }
            ui.end_row();
        }
    });
    if let Some(id) = switch_to {
        state.set_active_character(id);
    }

    // --- Active character detail ---
    ui.separator();
    ui.heading("Active character");
    match &state.character_detail {
        LoadState::Ready(info) => {
            let corp = resolver.name(info.corporation_id);
            let portrait_name = if info.name.is_empty() {
                state
                    .active_character()
                    .map(|c| c.name.clone())
                    .unwrap_or_else(|| "Unknown Item".to_string())
            } else {
                info.name.clone()
            };
            let portrait_id = state.active_character_id;
            egui::Grid::new("character_detail")
                .striped(true)
                .show(ui, |ui| {
                    ui.label("Portrait");
                    match portrait_id {
                        Some(active_id) => {
                            ui.horizontal(|ui| {
                                portraits::show_portrait(
                                    ui,
                                    cache,
                                    state,
                                    active_id,
                                    &portrait_name,
                                    portraits::DETAIL_PORTRAIT_PX,
                                );
                                let status = portraits::placeholder_status(
                                    state.demo,
                                    state.portrait_state(active_id),
                                );
                                if !status.is_empty() {
                                    ui.label(status);
                                }
                            });
                        }
                        None => {
                            ui.label("No character selected.");
                        }
                    }
                    ui.end_row();
                    ui.label("Name");
                    ui.label(&portrait_name);
                    ui.end_row();
                    ui.label("Corporation");
                    ui.label(&corp);
                    ui.end_row();
                    if let Some(alliance_id) = info.alliance_id {
                        ui.label("Alliance");
                        ui.label(resolver.name(alliance_id));
                        ui.end_row();
                    }
                    ui.label("Security status");
                    ui.label(format!("{:.2}", info.security_status));
                    ui.end_row();
                    if !info.birthday.is_empty() {
                        ui.label("Born");
                        ui.label(widgets::format_date_short(&info.birthday));
                        ui.end_row();
                    }
                });
            if let Some(summary) = state
                .active_character_id
                .and_then(|id| state.summaries.get(&id))
            {
                if let Some(location) = &summary.location_name {
                    ui.label(format!("Location: {}", location));
                }
                if let Some(ship) = &summary.ship_name {
                    ui.label(format!("Ship: {}", ship));
                }
                if let Some(sp) = summary.total_sp {
                    ui.label(format!("Skill points: {}", widgets::format_sp(sp)));
                }
            }
        }
        LoadState::Loading => widgets::loading_panel(ui, "Loading character..."),
        LoadState::Empty => widgets::empty_panel(ui, "Select a character to see details."),
        LoadState::Error(e) => {
            if widgets::error_panel_with_retry(ui, e) {
                tracing::warn!("[CHAR] retry requested after detail load error");
                state.retry_requested = true;
            }
        }
    }

    // A failed portrait retries only from here, never from the
    // render path (which would loop at frame rate). Demo mode
    // never shows the button: no fetch is ever attempted there.
    if let Some(active_id) = state.active_character_id {
        if !state.demo
            && matches!(state.portrait_state(active_id), PortraitState::Failed)
            && ui.button("Retry portrait").clicked()
        {
            tracing::info!(
                "[PORTRAIT] portrait retry requested from Characters view character_id={}",
                active_id
            );
            state.request_portrait(active_id);
        }
    }

    // --- Character details (status, attributes, implants, clones,
    // standings), stacked below the public-info block ---
    show_character_details(ui, state, resolver);

    // --- Logout / delete (two-step inline confirm, no modal traps) ---
    if let Some(active) = state
        .active_character()
        .map(|c| (c.character_id, c.name.clone()))
    {
        ui.separator();
        ui.horizontal(|ui| {
            // Logout/delete must not race an in-flight browser sign-in:
            // removing tokens mid-callback would let the completion save
            // fresh tokens for a character the user just removed.
            let auth_idle = !state.auth.is_busy();
            if ui
                .add_enabled(
                    auth_idle,
                    egui::Button::new(format!("Log out {}", active.1)),
                )
                .clicked()
            {
                tracing::info!("[AUTH] logout requested character selected");
                state.logout_requested_id = Some(active.0);
                state.status_message = "Logout requested (token cleanup runs via F1).".to_string();
            }
            if state.confirm_delete_id == Some(active.0) {
                if ui
                    .add_enabled(auth_idle, egui::Button::new("Confirm delete"))
                    .clicked()
                {
                    tracing::warn!("[CHAR] delete confirmed character selected");
                    state.delete_requested_id = Some(active.0);
                    state.confirm_delete_id = None;
                    state.remove_character(active.0);
                    state.status_message = "Character removed locally.".to_string();
                }
                if ui.button("Cancel").clicked() {
                    state.confirm_delete_id = None;
                }
            } else if ui
                .add_enabled(auth_idle, egui::Button::new("Delete character..."))
                .clicked()
            {
                tracing::info!("[CHAR] delete requested, awaiting confirmation");
                state.confirm_delete_id = Some(active.0);
            }
        });
    }
}

/// The five attribute rows in their one fixed display order.
pub fn attribute_rows(attrs: &CharacterAttributes) -> Vec<(&'static str, i32)> {
    vec![
        ("Intelligence", attrs.intelligence),
        ("Memory", attrs.memory),
        ("Perception", attrs.perception),
        ("Willpower", attrs.willpower),
        ("Charisma", attrs.charisma),
    ]
}

/// Resolve implant type IDs to display names in ESI order. Unresolved
/// IDs fall back to the resolver's `Unknown Item` words, never a number.
pub fn implant_names(ids: &[i64], resolver: &NameResolver) -> Vec<String> {
    ids.iter().map(|id| resolver.name(*id)).collect()
}

/// A jump clone's title: its own name when it has one, else the plain
/// words "Jump clone". Never derived from `jump_clone_id`.
pub fn clone_display_name(clone: &JumpClone) -> String {
    match clone.name.as_deref().map(str::trim) {
        Some(name) if !name.is_empty() => name.to_string(),
        _ => "Jump clone".to_string(),
    }
}

/// One standings display row: resolved name plus formatted value.
#[derive(Debug, Clone, PartialEq)]
pub struct StandingRow {
    pub name: String,
    pub standing: f64,
    pub standing_text: String,
}

/// All standings under one fixed heading, sorted for display.
#[derive(Debug, Clone, PartialEq)]
pub struct StandingGroup {
    pub heading: &'static str,
    pub rows: Vec<StandingRow>,
}

/// Fixed group order; every unrecognized `from_type` (including the
/// empty string) lands in "Other" so no standing is ever dropped.
const STANDING_HEADINGS: [&str; 4] = ["Factions", "NPC corporations", "Agents", "Other"];

fn standing_group_index(from_type: &str) -> usize {
    match from_type {
        "faction" => 0,
        "npc_corp" | "corporation" => 1,
        "agent" => 2,
        _ => 3,
    }
}

/// Group standings for display: fixed group order (empty groups
/// omitted), rows sorted by value descending with resolved name and
/// then `from_id` as invisible tie-breaks. A non-finite value sorts
/// last in its group and renders "not available", never a number.
pub fn standing_groups(standings: &[Standing], resolver: &NameResolver) -> Vec<StandingGroup> {
    let mut buckets: [Vec<(String, f64, i64)>; 4] = Default::default();
    for standing in standings {
        buckets[standing_group_index(&standing.from_type)].push((
            resolver.name(standing.from_id),
            standing.standing,
            standing.from_id,
        ));
    }
    let mut groups = Vec::new();
    for (heading, mut rows) in STANDING_HEADINGS.into_iter().zip(buckets) {
        if rows.is_empty() {
            continue;
        }
        rows.sort_by(|a, b| {
            let by_value = match (a.1.is_finite(), b.1.is_finite()) {
                (true, true) => b.1.partial_cmp(&a.1).unwrap_or(std::cmp::Ordering::Equal),
                (true, false) => std::cmp::Ordering::Less,
                (false, true) => std::cmp::Ordering::Greater,
                (false, false) => std::cmp::Ordering::Equal,
            };
            by_value.then_with(|| a.0.cmp(&b.0)).then(a.2.cmp(&b.2))
        });
        groups.push(StandingGroup {
            heading,
            rows: rows
                .into_iter()
                .map(|(name, standing, _from_id)| StandingRow {
                    name,
                    standing,
                    standing_text: if standing.is_finite() {
                        format!("{standing:+.2}")
                    } else {
                        "not available".to_string()
                    },
                })
                .collect(),
        });
    }
    tracing::debug!(
        "[CHAR] grouped standings count={} groups={}",
        standings.len(),
        groups.len()
    );
    groups
}

/// `(positive, neutral, negative)` counts, folded with saturating
/// adds. A non-finite standing counts in none of the three.
pub fn standing_counts(standings: &[Standing]) -> (usize, usize, usize) {
    standings
        .iter()
        .fold((0usize, 0usize, 0usize), |(p, n, g), s| {
            if !s.standing.is_finite() {
                (p, n, g)
            } else if s.standing > 0.0 {
                (p.saturating_add(1), n, g)
            } else if s.standing == 0.0 {
                (p, n.saturating_add(1), g)
            } else {
                (p, n, g.saturating_add(1))
            }
        })
}

/// Uniform per-section failure line. A scope failure points at the
/// step-up panel above when it is showing; otherwise (the first-auth
/// attributes/implants case) it says so without offering one.
fn section_error_label(ui: &mut egui::Ui, section: &str, error: &SectionError, panel_shown: bool) {
    if error.needs_reauthorize && panel_shown {
        ui.label("Not authorized yet. Re-authorize above to load this section.");
    } else if error.needs_reauthorize {
        ui.label("Not authorized yet for this character.");
    } else {
        ui.label(format!("Could not load {section}: {}", error.message));
    }
}

/// Step-up guidance mirroring the Assets panel: the button only sets
/// the shell's step-up request flag for the active character; it never
/// clears or replaces any detail section.
fn detail_reauthorize_panel(ui: &mut egui::Ui, state: &mut AppState) {
    ui.heading("Some character details need more EVE permissions.");
    ui.label(format!(
        "Jump clones, standings, location, ship, and online state will not \
         load until this character grants these EVE SSO scopes: {}. \
         Attributes, active implants, and your other views are unaffected.",
        EveConfig::CHARACTER_DETAIL_SCOPES.join(" ")
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
                "[AUTH] step-up re-authorize requested from Characters view character_id={} scopes={}",
                active_id,
                EveConfig::CHARACTER_DETAIL_SCOPES.join(" ")
            );
            state.stepup_requested = Some(StepUpRequest::new(
                active_id,
                EveConfig::CHARACTER_DETAIL_SCOPES,
            ));
            state.status_message =
                "EVE SSO requested: your browser should open to login.eveonline.com.".to_string();
        }
    }
}

/// The character-detail block under the public-info grid. Renders from
/// a cloned snapshot so the step-up button can borrow `state` mutably.
fn show_character_details(ui: &mut egui::Ui, state: &mut AppState, resolver: &NameResolver) {
    let snapshot = state.character_details.clone();
    match snapshot {
        LoadState::Loading => widgets::loading_panel(ui, "Loading character details..."),
        LoadState::Empty => widgets::empty_panel(ui, "No character details yet."),
        LoadState::Error(e) => {
            if widgets::error_panel_with_retry(ui, &e) {
                tracing::warn!("[CHAR] retry requested after character detail load error");
                state.retry_requested = true;
            }
        }
        LoadState::Ready(bundle) => {
            let panel_shown =
                !state.demo && state.active_character_id.is_some() && bundle.needs_detail_stepup();
            if panel_shown {
                tracing::debug!(
                    "[CHAR] showing character detail re-authorize guidance (missing scopes)"
                );
                detail_reauthorize_panel(ui, state);
            }
            show_status_section(ui, &bundle, resolver, panel_shown);
            show_attributes_section(ui, &bundle, panel_shown);
            show_implants_section(ui, &bundle, resolver, panel_shown);
            show_clones_section(ui, &bundle, resolver, panel_shown);
            show_standings_section(ui, &bundle, resolver, panel_shown);
        }
    }
}

/// Status composes the independent online, location, and ship
/// sections; each line matches its own result so one failure hides
/// only its line.
fn show_status_section(
    ui: &mut egui::Ui,
    bundle: &CharacterDetailData,
    resolver: &NameResolver,
    panel_shown: bool,
) {
    ui.separator();
    ui.heading("Status");
    match &bundle.online {
        Ok(online) => {
            ui.label(if online.online {
                "Online now"
            } else {
                "Offline"
            });
            if let Some(last_login) = &online.last_login {
                ui.label(format!(
                    "Last login: {}",
                    widgets::format_date_short(last_login)
                ));
            }
            if let Some(last_logout) = &online.last_logout {
                ui.label(format!(
                    "Last logout: {}",
                    widgets::format_date_short(last_logout)
                ));
            }
            if let Some(logins) = online.logins {
                ui.label(format!("Logins: {logins}"));
            }
        }
        Err(e) => section_error_label(ui, "online", e, panel_shown),
    }
    match &bundle.location {
        Ok(location) => {
            if let Some(docked_id) = location.docked_location_id() {
                let docked = resolver.location_name(docked_id);
                ui.label(format!("Docked: {docked}"));
            }
            ui.label(format!(
                "Solar system: {}",
                resolver.location_name(location.solar_system_id)
            ));
        }
        Err(e) => section_error_label(ui, "location", e, panel_shown),
    }
    match &bundle.ship {
        Ok(ship) => {
            let type_name = resolver.name(ship.ship_type_id);
            let display = ship_display_name(&ship.ship_name, Some(&type_name))
                .unwrap_or_else(|| "Unknown Item".to_string());
            ui.label(format!("Ship: {display}"));
        }
        Err(e) => section_error_label(ui, "ship", e, panel_shown),
    }
}

fn show_attributes_section(ui: &mut egui::Ui, bundle: &CharacterDetailData, panel_shown: bool) {
    ui.separator();
    ui.heading("Attributes");
    match &bundle.attributes {
        Ok(attrs) => {
            egui::Grid::new("character_attributes")
                .striped(true)
                .show(ui, |ui| {
                    for (label, value) in attribute_rows(attrs) {
                        ui.label(label);
                        ui.label(value.to_string());
                        ui.end_row();
                    }
                    if let Some(bonus_remaps) = attrs.bonus_remaps {
                        ui.label("Bonus remaps");
                        ui.label(bonus_remaps.to_string());
                        ui.end_row();
                    }
                    if let Some(last_remap) = &attrs.last_remap_date {
                        ui.label("Last remap");
                        ui.label(widgets::format_date_short(last_remap));
                        ui.end_row();
                    }
                    if let Some(remap_available) = &attrs.accrued_remap_cooldown_date {
                        ui.label("Remap available");
                        ui.label(widgets::format_date_short(remap_available));
                        ui.end_row();
                    }
                });
        }
        Err(e) => section_error_label(ui, "attributes", e, panel_shown),
    }
}

fn show_implants_section(
    ui: &mut egui::Ui,
    bundle: &CharacterDetailData,
    resolver: &NameResolver,
    panel_shown: bool,
) {
    ui.separator();
    ui.heading("Active implants");
    match &bundle.implants {
        Ok(ids) => {
            let names = implant_names(ids, resolver);
            if names.is_empty() {
                ui.label("No implants currently active");
            } else {
                ui.label(format!("{} implant(s) active", names.len()));
                for name in &names {
                    ui.label(name);
                }
            }
        }
        Err(e) => section_error_label(ui, "active implants", e, panel_shown),
    }
}

fn show_clones_section(
    ui: &mut egui::Ui,
    bundle: &CharacterDetailData,
    resolver: &NameResolver,
    panel_shown: bool,
) {
    ui.separator();
    ui.heading("Jump clones");
    match &bundle.clones {
        Ok(clones) => {
            if let Some(home) = &clones.home_location {
                ui.label(format!(
                    "Home: {}",
                    resolver.location_name(home.location_id)
                ));
            }
            if let Some(last_jump) = &clones.last_clone_jump_date {
                ui.label(format!(
                    "Last clone jump: {}",
                    widgets::format_date_short(last_jump)
                ));
            }
            if let Some(last_change) = &clones.last_station_change_date {
                ui.label(format!(
                    "Last station change: {}",
                    widgets::format_date_short(last_change)
                ));
            }
            if clones.jump_clones.is_empty() {
                ui.label("No jump clones available");
                return;
            }
            ui.label(format!("{} jump clone(s)", clones.jump_clones.len()));
            for clone in &clones.jump_clones {
                ui.label(clone_display_name(clone));
                let location = resolver.location_name(clone.location_id);
                match clone.location_type.as_str() {
                    "station" | "structure" => {
                        ui.label(format!("{location} ({})", clone.location_type));
                    }
                    _ => {
                        ui.label(location);
                    }
                }
                let names = implant_names(&clone.implants, resolver);
                if names.is_empty() {
                    ui.label("No implants");
                } else {
                    ui.label(format!("Implants ({})", names.len()));
                    for name in &names {
                        ui.label(name);
                    }
                }
            }
        }
        Err(e) => section_error_label(ui, "jump clones", e, panel_shown),
    }
}

fn show_standings_section(
    ui: &mut egui::Ui,
    bundle: &CharacterDetailData,
    resolver: &NameResolver,
    panel_shown: bool,
) {
    ui.separator();
    ui.heading("Standings");
    match &bundle.standings {
        Ok(standings) => {
            if standings.is_empty() {
                ui.label("No standings yet");
                return;
            }
            let (positive, neutral, negative) = standing_counts(standings);
            ui.label(format!(
                "{positive} positive · {neutral} neutral · {negative} negative"
            ));
            for group in standing_groups(standings, resolver) {
                ui.strong(group.heading);
                for row in &group.rows {
                    ui.label(format!("{} {}", row.name, row.standing_text));
                }
            }
        }
        Err(e) => section_error_label(ui, "standings", e, panel_shown),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn resolver() -> NameResolver {
        let mut r = NameResolver::new();
        r.insert(22119, "Demo Memory Implant".to_string());
        r.insert(500001, "Caldari State".to_string());
        r.insert(500002, "Minmatar Republic".to_string());
        r.insert(1000125, "Caldari Navy".to_string());
        r.insert(1000006, "Kaalakiota Corporation".to_string());
        r.insert(3000001, "Agent Person".to_string());
        r.insert(99000001, "Demo Alliance".to_string());
        r
    }

    fn standing(from_id: i64, from_type: &str, standing: f64) -> Standing {
        Standing {
            from_id,
            from_type: from_type.to_string(),
            standing,
        }
    }

    #[test]
    fn attribute_rows_keep_fixed_order() {
        let attrs = CharacterAttributes {
            intelligence: 27,
            memory: 21,
            perception: 25,
            willpower: 24,
            charisma: 20,
            ..Default::default()
        };
        assert_eq!(
            attribute_rows(&attrs),
            vec![
                ("Intelligence", 27),
                ("Memory", 21),
                ("Perception", 25),
                ("Willpower", 24),
                ("Charisma", 20),
            ]
        );
    }

    #[test]
    fn implant_names_resolve_and_fall_back_to_words() {
        assert!(implant_names(&[], &resolver()).is_empty());
        let names = implant_names(&[22119, 22120], &resolver());
        assert_eq!(names[0], "Demo Memory Implant");
        assert_eq!(names[1], "Unknown Item");
        let unknown = implant_names(&[22119, 22120], &NameResolver::new());
        assert!(unknown.iter().all(|n| n == "Unknown Item"));
        for name in names.iter().chain(unknown.iter()) {
            assert!(name.parse::<i64>().is_err());
        }
    }

    #[test]
    fn clone_display_name_never_derives_from_id() {
        let named = JumpClone {
            jump_clone_id: 91000001,
            name: Some("Amarr spare".to_string()),
            ..Default::default()
        };
        assert_eq!(clone_display_name(&named), "Amarr spare");
        let unnamed = JumpClone {
            jump_clone_id: 91000001,
            ..Default::default()
        };
        assert_eq!(clone_display_name(&unnamed), "Jump clone");
        let whitespace = JumpClone {
            jump_clone_id: 91000001,
            name: Some("   ".to_string()),
            ..Default::default()
        };
        assert_eq!(clone_display_name(&whitespace), "Jump clone");
        assert!(!clone_display_name(&unnamed).contains("91000001"));
    }

    #[test]
    fn standing_groups_order_sort_and_keep_unknown_types() {
        let standings = vec![
            standing(99000001, "alliance", 0.0),
            standing(3000001, "agent", 1.0),
            standing(1000006, "corporation", 2.0),
            standing(500002, "faction", -1.5),
            standing(500001, "faction", 3.25),
            standing(1000125, "npc_corp", 2.0),
            standing(424242, "", f64::NAN),
        ];
        let groups = standing_groups(&standings, &resolver());
        let headings: Vec<&str> = groups.iter().map(|g| g.heading).collect();
        assert_eq!(
            headings,
            vec!["Factions", "NPC corporations", "Agents", "Other"]
        );
        // Factions sort descending; fixture precision survives the format.
        assert_eq!(groups[0].rows[0].name, "Caldari State");
        assert_eq!(groups[0].rows[0].standing_text, "+3.25");
        assert_eq!(groups[0].rows[1].name, "Minmatar Republic");
        assert_eq!(groups[0].rows[1].standing_text, "-1.50");
        // npc_corp and corporation merge; equal values tie-break by name.
        assert_eq!(groups[1].rows.len(), 2);
        assert_eq!(groups[1].rows[0].name, "Caldari Navy");
        assert_eq!(groups[1].rows[1].name, "Kaalakiota Corporation");
        // Unknown and empty from_type are kept under Other; zero shows
        // +0.00 and the non-finite value sorts last as words.
        assert_eq!(groups[3].rows.len(), 2);
        assert_eq!(groups[3].rows[0].name, "Demo Alliance");
        assert_eq!(groups[3].rows[0].standing_text, "+0.00");
        assert!(groups[3].rows[1].standing.is_nan());
        assert_eq!(groups[3].rows[1].standing_text, "not available");
        for group in &groups {
            for row in &group.rows {
                assert!(row.name.parse::<i64>().is_err());
            }
        }
        assert!(standing_groups(&[], &resolver()).is_empty());
    }

    #[test]
    fn standing_counts_split_by_sign() {
        assert_eq!(standing_counts(&[]), (0, 0, 0));
        let standings = vec![
            standing(1, "faction", 3.25),
            standing(2, "faction", 0.5),
            standing(3, "faction", 0.0),
            standing(4, "faction", -1.5),
            standing(5, "faction", f64::NAN),
            standing(6, "faction", f64::INFINITY),
        ];
        assert_eq!(standing_counts(&standings), (2, 1, 1));
    }
}
