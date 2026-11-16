//! Exploration: read-only offline wormhole reference browser over the
//! bundled `assets/sde/exploration.json` catalogue (design sections 7-8).
//! Every rendered string comes from the bundled reference; there is no
//! name resolution, no network, no character dependency, and no
//! `mode_notice` (its demo text would be false for real SDE data).
//! Raw EVE IDs (wormhole type IDs, beacon IDs, attribute IDs, system
//! IDs) are state and keys only, never rendered.

use super::widgets;
use crate::app::state::{AppState, DestinationFilter, ExplorationSection, LoadState};
use std::sync::Arc;

use crate::names::exploration_ref::{
    code_group_from_variants, effect_for_system, search_types, statics_label, CodeGroup,
    EffectFamily, EffectResolution, ExplorationRef, RefEffect, RefSystem, TypeSearchQuery,
    WormholeType,
};

/// Maximum group/system rows rendered at once, with the shown/total
/// counts disclosed beside the list. Matches the sibling views
/// (fittings, industry, planets at 100).
pub const EXPLORATION_RENDER_MAX: usize = 100;

/// Whole-view error sentence (design section 8.4). Any bundled-data
/// failure renders this and nothing else; the data cannot be retried.
pub const EXPLORATION_ERROR: &str = "Exploration reference data could not be loaded. The bundled data is missing or damaged; reinstalling the app restores it.";

/// Capital-size qualification line (design section 8.2, Product R7).
pub const CAPITAL_QUALIFICATION: &str = "Capital-size means a nominal per-jump mass limit of at least 1,000,000,000 kg. It does not guarantee a ship can use a connection.";

/// Resonance explanatory sentence (design section 8.3, Product 4.2).
pub const RESONANCE_SENTENCE: &str = "Increased damage resonance worsens resistance: a 50% resistance with +50% resonance becomes 25%, not 0%.";

/// Vorton scope sentence (design section 8.3, Wolf-Rayet only).
pub const VORTON_SENTENCE: &str = "Scope includes Vorton projector effects.";

fn family_order(family: EffectFamily) -> u8 {
    match family {
        EffectFamily::Pulsar => 0,
        EffectFamily::BlackHole => 1,
        EffectFamily::CataclysmicVariable => 2,
        EffectFamily::Magnetar => 3,
        EffectFamily::RedGiant => 4,
        EffectFamily::WolfRayet => 5,
    }
}

/// Empty-text display order for wormhole code groups (design
/// section 7.3): code A-Z, then smallest variant type ID. The
/// deriver returned insertion order, which the bundled file's
/// type-ID sort would make non-alphabetical, so the view locks
/// this order as a pure function.
pub fn sorted_groups(groups: &[CodeGroup], catalog: &[WormholeType]) -> Vec<CodeGroup> {
    let mut sorted = groups.to_vec();
    sorted.sort_by(|a, b| {
        a.code
            .cmp(&b.code)
            .then_with(|| min_type_id(a, catalog).cmp(&min_type_id(b, catalog)))
    });
    tracing::debug!("[EXPLORE] sorted groups={}", sorted.len());
    sorted
}

fn min_type_id(group: &CodeGroup, catalog: &[WormholeType]) -> i64 {
    group
        .variants
        .iter()
        .filter_map(|&i| catalog.get(i))
        .map(|t| t.type_id)
        .min()
        .unwrap_or(i64::MAX)
}

/// Systems display order (design section 7.3): name A-Z, then system ID.
pub fn sorted_systems(systems: &[RefSystem]) -> Vec<&RefSystem> {
    let mut sorted: Vec<&RefSystem> = systems.iter().collect();
    sorted.sort_by(|a, b| a.name.cmp(&b.name).then(a.system_id.cmp(&b.system_id)));
    tracing::debug!("[EXPLORE] sorted systems={}", sorted.len());
    sorted
}

/// Effects display order (design section 7.3): `EffectFamily`
/// declaration order, strengths 1-6 inside each family.
pub fn sorted_effects(effects: &[RefEffect]) -> Vec<&RefEffect> {
    let mut sorted: Vec<&RefEffect> = effects.iter().collect();
    sorted.sort_by(|a, b| {
        family_order(a.family)
            .cmp(&family_order(b.family))
            .then(a.strength.cmp(&b.strength))
    });
    tracing::debug!("[EXPLORE] sorted effects={}", sorted.len());
    sorted
}

/// True when one destination label passes a chip. `JSpace` passes
/// the six J-space class labels `C1`..`C6`; every other chip is an
/// exact match (design section 7.3).
pub fn destination_matches(label: &str, filter: DestinationFilter) -> bool {
    if filter == DestinationFilter::JSpace {
        matches!(label, "C1" | "C2" | "C3" | "C4" | "C5" | "C6")
    } else {
        label == filter.label()
    }
}

/// Narrow code groups to the variants whose destination passes a
/// chip, dropping groups with no matching variant. Groups are
/// rebuilt through `code_group_from_variants` so variant counts and
/// shared lifetime/jump-mass values describe only kept variants,
/// even if a future SDE pin gives one code divergent destinations.
pub fn narrow_groups_to_destination(
    groups: Vec<CodeGroup>,
    types: &[WormholeType],
    filter: DestinationFilter,
) -> Vec<CodeGroup> {
    let mut narrowed = Vec::new();
    for group in groups {
        let matching: Vec<usize> = group
            .variants
            .iter()
            .copied()
            .filter(|&i| {
                types
                    .get(i)
                    .is_some_and(|t| destination_matches(&t.destination_label(), filter))
            })
            .collect();
        if matching.is_empty() {
            continue;
        }
        narrowed.push(code_group_from_variants(group.code, types, &matching));
    }
    tracing::debug!(
        "[EXPLORE] narrowed groups to destination {:?} kept={}",
        filter,
        narrowed.len()
    );
    narrowed
}

/// Filter wormhole types for the Types section (design section 7.3).
/// Text matching ports `ReferenceDeriver.search` via
/// `search_types` (exact > prefix > substring rank, then code);
/// destination and capital conditions must hold on the same variant
/// (the deriver narrows to matching variants only). Capital never
/// clears the search text: both conditions pass through and combine
/// with AND (Product R7).
pub fn filtered_types(
    reference: &ExplorationRef,
    text: &str,
    destination: Option<DestinationFilter>,
    capital_only: bool,
) -> Vec<CodeGroup> {
    let query = TypeSearchQuery {
        text: text.to_string(),
        capital_only,
        ..Default::default()
    };
    let mut groups = search_types(&reference.types, &query);
    // Empty text displays in locked code order (design section 7.3);
    // non-empty text keeps the deriver rank order from search_types.
    if text.trim().is_empty() {
        groups = sorted_groups(&groups, &reference.types);
    }
    if let Some(filter) = destination {
        groups = narrow_groups_to_destination(groups, &reference.types, filter);
    }
    tracing::debug!(
        "[EXPLORE] filtered types groups={} text_len={} destination={:?} capital={}",
        groups.len(),
        text.len(),
        destination,
        capital_only
    );
    groups
}

/// Systems filter (design section 7.3): case-insensitive substring
/// match on the system name only, via `widgets::matches_search`, in
/// `sorted_systems` order. Destination and capital chips do not
/// apply in this section. A trimmed-empty needle matches all.
pub fn filter_systems<'a>(systems: &'a [RefSystem], query: &str) -> Vec<&'a RefSystem> {
    let needle = query.trim();
    let kept: Vec<&RefSystem> = sorted_systems(systems)
        .into_iter()
        .filter(|s| widgets::matches_search(&s.name, needle))
        .collect();
    tracing::debug!("[EXPLORE] filtered systems kept={}", kept.len());
    kept
}

/// Effects filter (design section 7.3): the 36 rows are small and
/// complete, so text filters families by family-label substring via
/// `widgets::matches_search` rather than individual rows. Strengths
/// inside a kept family always remain.
pub fn filter_effects<'a>(effects: &'a [RefEffect], query: &str) -> Vec<&'a RefEffect> {
    let needle = query.trim();
    let kept: Vec<&RefEffect> = sorted_effects(effects)
        .into_iter()
        .filter(|e| widgets::matches_search(e.family.label(), needle))
        .collect();
    tracing::debug!("[EXPLORE] filtered effects kept={}", kept.len());
    kept
}

/// Group result counts for the Types list (design section 8.2):
/// `{n} code groups` plus `{m} types` in parentheses when any group
/// has more than one variant. Counts are computed from loaded data.
pub fn group_result_counts(groups: &[CodeGroup]) -> (usize, usize) {
    let types: usize = groups.iter().map(|g| g.variants.len()).sum();
    (groups.len(), types)
}

/// Thousands-grouped integer, mirroring the `format_isk` grouping.
fn group_integer(value: i64) -> String {
    let digits = value.unsigned_abs().to_string();
    let mut grouped = String::new();
    for (i, ch) in digits.chars().enumerate() {
        if i > 0 && (digits.len() - i).is_multiple_of(3) {
            grouped.push(',');
        }
        grouped.push(ch);
    }
    if value < 0 {
        format!("-{grouped}")
    } else {
        grouped
    }
}

fn format_mass(value: Option<f64>, suffix: &str) -> String {
    match value {
        None => "Unknown".to_string(),
        Some(kg) if !kg.is_finite() => "Unknown".to_string(),
        Some(kg) if kg.fract() == 0.0 && kg.abs() <= 9_007_199_254_740_992.0 => {
            format!("{} {}", group_integer(kg as i64), suffix)
        }
        Some(kg) => format!("{kg} {suffix}"),
    }
}

/// Mass formatter (design section 8.2): grouped integer when
/// integral, plain decimal otherwise, plus ` kg`; `None` is `Unknown`.
pub fn format_kg(value: Option<f64>) -> String {
    format_mass(value, "kg")
}

/// Regeneration formatter: same as `format_kg` with ` kg/cycle`
/// (never kg/s, design section 8.2).
pub fn format_regen(value: Option<f64>) -> String {
    format_mass(value, "kg/cycle")
}

/// Lifetime formatter (design section 8.2): exact seconds plus
/// `widgets::format_countdown`, so B274 reads `86400s (1d 0h 0m)`.
pub fn format_lifetime(seconds: Option<i64>) -> String {
    match seconds {
        None => "Unknown".to_string(),
        Some(secs) => format!("{}s ({})", secs, widgets::format_countdown(secs)),
    }
}

/// Signed percentage (design section 8.3): explicit `+`/`-` sign,
/// `0%` with no sign.
pub fn format_percent(percent: f64) -> String {
    if !percent.is_finite() {
        return "Unknown".to_string();
    }
    if percent == 0.0 {
        return "0%".to_string();
    }
    if percent.fract() == 0.0 {
        format!("{:+}%", percent as i64)
    } else {
        format!("{percent:+}%")
    }
}

/// One line per distinct modifier label, in first-seen order, so
/// resonance rows sharing a label render once (design section 8.3).
fn modifier_lines(effect: &RefEffect) -> Vec<String> {
    let mut seen: Vec<String> = Vec::new();
    let mut lines: Vec<String> = Vec::new();
    for modifier in &effect.modifiers {
        if seen.contains(&modifier.label) {
            continue;
        }
        seen.push(modifier.label.clone());
        lines.push(format!(
            "{} {}",
            modifier.label,
            format_percent(modifier.percent)
        ));
    }
    lines
}

/// Shared destination label for a group row, or `None` when variants
/// disagree (design section 8.2: ` · {label}` only when they agree).
fn shared_destination_label(group: &CodeGroup, catalog: &[WormholeType]) -> Option<String> {
    let mut labels = group
        .variants
        .iter()
        .filter_map(|&i| catalog.get(i))
        .map(|t| t.destination_label());
    let first = labels.next()?;
    if labels.all(|label| label == first) {
        Some(first)
    } else {
        None
    }
}

fn search_hint(section: ExplorationSection) -> &'static str {
    match section {
        ExplorationSection::Types => {
            "Filter by wormhole code, name or destination (press / to focus)"
        }
        ExplorationSection::Systems => "Filter systems by name (press / to focus)",
        ExplorationSection::Effects => "Filter effects by family (press / to focus)",
    }
}

fn show_type_detail(ui: &mut egui::Ui, reference: &ExplorationRef, code: &str) {
    use crate::names::exploration_ref::group_by_code;
    let groups = group_by_code(&reference.types);
    let Some(group) = groups.iter().find(|g| g.code == code) else {
        widgets::empty_panel(ui, "Select a wormhole code for details.");
        return;
    };
    ui.heading(group.code.clone());
    let catalog = &reference.types;
    let variants: Vec<&WormholeType> = group
        .variants
        .iter()
        .filter_map(|&i| catalog.get(i))
        .collect();
    if variants.is_empty() {
        return;
    }
    let first = variants[0];
    let lifetimes: Vec<Option<i64>> = variants.iter().map(|t| t.lifetime_seconds()).collect();
    let lifetime_agrees = lifetimes.iter().all(|v| *v == lifetimes[0]);
    let lifetime_label = if lifetime_agrees {
        format_lifetime(first.lifetime_seconds())
    } else {
        "Varies".to_string()
    };
    let jump_label = if group.jump_varies {
        "Varies".to_string()
    } else {
        format_kg(group.shared_jump_mass_kg)
    };
    let totals: Vec<Option<f64>> = variants.iter().map(|t| t.raw_total_mass_kg).collect();
    let total_label = if totals.iter().all(|v| *v == totals[0]) {
        format_kg(first.raw_total_mass_kg)
    } else {
        "Varies".to_string()
    };
    let regens: Vec<Option<f64>> = variants.iter().map(|t| t.raw_regen_kg).collect();
    let regen_label = if regens.iter().all(|v| *v == regens[0]) {
        format_regen(first.raw_regen_kg)
    } else {
        "Varies".to_string()
    };
    let destination_label =
        shared_destination_label(group, catalog).unwrap_or_else(|| "Varies".to_string());
    ui.label(format!("Reliable lifetime {}", lifetime_label));
    ui.label(format!("Jump mass {}", jump_label));
    ui.label(format!("Total mass {}", total_label));
    ui.label(format!("Regen {}", regen_label));
    ui.label(format!("Destination {}", destination_label));
    let disagrees = group.jump_varies
        || !lifetime_agrees
        || totals.iter().any(|v| *v != totals[0])
        || regens.iter().any(|v| *v != regens[0])
        || shared_destination_label(group, catalog).is_none();
    if variants.len() > 1 && disagrees {
        for variant in &variants {
            ui.label(format!(
                "{}: lifetime {}, jump {}, total {}, regen {}, destination {}",
                variant.name,
                format_lifetime(variant.lifetime_seconds()),
                format_kg(variant.raw_jump_mass_kg),
                format_kg(variant.raw_total_mass_kg),
                format_regen(variant.raw_regen_kg),
                variant.destination_label()
            ));
        }
    }
}

fn show_system_detail(ui: &mut egui::Ui, reference: &ExplorationRef, system_id: i64) {
    let Some(system) = reference.system_by_id(system_id) else {
        widgets::empty_panel(ui, "Select a system for details.");
        return;
    };
    let mut hierarchy = vec![system.name.clone()];
    if let Some(constellation) = &system.constellation_name {
        if !constellation.is_empty() {
            hierarchy.push(constellation.clone());
        }
    }
    if let Some(region) = &system.region_name {
        if !region.is_empty() {
            hierarchy.push(region.clone());
        }
    }
    ui.heading(hierarchy.join(" \u{2192} "));
    ui.label(system.security_label());
    ui.label(format!("Security {}", system.security_display()));
    match effect_for_system(system, reference) {
        EffectResolution::Applied {
            family,
            strength,
            beacon_type_id,
        } => {
            ui.label(format!("Effect {} {}", family.label(), strength));
            if let Some(effect) = reference.effect_by_beacon(beacon_type_id) {
                for line in modifier_lines(effect) {
                    ui.label(line);
                }
            } else if let Some(effect) = reference
                .effects
                .iter()
                .find(|e| e.family == family && e.strength == strength)
            {
                for line in modifier_lines(effect) {
                    ui.label(line);
                }
            }
        }
        EffectResolution::None => {
            ui.label("No system effect");
        }
        EffectResolution::Unknown => {
            ui.label("System effect unknown");
        }
    }
    ui.label(statics_label(reference, system_id));
}

fn show_effect_detail(
    ui: &mut egui::Ui,
    reference: &ExplorationRef,
    family: EffectFamily,
    strength: u8,
) {
    let strength = strength.clamp(1, 6);
    let Some(effect) = reference
        .effects
        .iter()
        .find(|e| e.family == family && e.strength == strength)
    else {
        return;
    };
    ui.separator();
    ui.heading(format!("Effect {} {}", family.label(), strength));
    for line in modifier_lines(effect) {
        ui.label(line);
    }
    ui.label(RESONANCE_SENTENCE);
    if family == EffectFamily::WolfRayet {
        ui.label(VORTON_SENTENCE);
    }
}

#[allow(clippy::too_many_lines)]
fn show_types(ui: &mut egui::Ui, state: &mut AppState, reference: &ExplorationRef) {
    if reference.types.is_empty() {
        widgets::empty_panel(ui, "No wormhole reference data.");
        return;
    }
    ui.horizontal(|ui| {
        for filter in DestinationFilter::ALL {
            let selected = state.exploration_destination == Some(filter);
            if ui.selectable_label(selected, filter.label()).clicked() {
                state.exploration_destination = if selected { None } else { Some(filter) };
                tracing::info!(
                    "[EXPLORE] destination filter {:?}",
                    state.exploration_destination
                );
            }
        }
        if ui
            .selectable_label(state.exploration_capital_only, "Capital-size")
            .clicked()
        {
            state.exploration_capital_only = !state.exploration_capital_only;
            tracing::info!(
                "[EXPLORE] capital filter {}",
                state.exploration_capital_only
            );
        }
    });
    ui.label(CAPITAL_QUALIFICATION);
    let groups = filtered_types(
        reference,
        &state.exploration_search,
        state.exploration_destination,
        state.exploration_capital_only,
    );
    if groups.is_empty() {
        widgets::empty_panel(ui, "No wormhole types match.");
    } else {
        let (code_groups, type_count) = group_result_counts(&groups);
        let has_multiple = groups.iter().any(|g| g.variants.len() > 1);
        if has_multiple {
            ui.label(format!(
                "{} code groups ({} types)",
                code_groups, type_count
            ));
        } else {
            ui.label(format!("{} code groups", code_groups));
        }
        let shown = code_groups.min(EXPLORATION_RENDER_MAX);
        if code_groups > EXPLORATION_RENDER_MAX {
            ui.label(format!("Showing {} of {} code groups.", shown, code_groups));
        }
        for group in groups.iter().take(EXPLORATION_RENDER_MAX) {
            let mut row = group.code.clone();
            if let Some(label) = shared_destination_label(group, &reference.types) {
                row.push_str(&format!(" \u{00B7} {}", label));
            }
            if group.variants.len() > 1 {
                row.push_str(&format!(" \u{00B7} {} variants", group.variants.len()));
            }
            let selected = state.exploration_selected_code.as_deref() == Some(&group.code);
            if ui.selectable_label(selected, row).clicked() {
                tracing::info!("[EXPLORE] selected wormhole code={}", group.code);
                state.exploration_selected_code = Some(group.code.clone());
            }
        }
    }
    ui.separator();
    match &state.exploration_selected_code {
        Some(code) => show_type_detail(ui, reference, code),
        None => widgets::empty_panel(ui, "Select a wormhole code for details."),
    }
}

#[allow(clippy::too_many_lines)]
fn show_systems(ui: &mut egui::Ui, state: &mut AppState, reference: &ExplorationRef) {
    if reference.systems.is_empty() {
        widgets::empty_panel(ui, "No system reference data.");
        return;
    }
    let systems = filter_systems(&reference.systems, &state.exploration_search);
    if systems.is_empty() {
        widgets::empty_panel(ui, "No systems match.");
    } else {
        let total = systems.len();
        ui.label(format!("{} systems", total));
        let shown = total.min(EXPLORATION_RENDER_MAX);
        if total > EXPLORATION_RENDER_MAX {
            ui.label(format!("Showing {} of {} systems.", shown, total));
        }
        for system in systems.iter().take(EXPLORATION_RENDER_MAX) {
            let row = format!("{} \u{00B7} {}", system.name, system.security_label());
            let selected = state.exploration_selected_system_id == Some(system.system_id);
            if ui.selectable_label(selected, row).clicked() {
                tracing::info!("[EXPLORE] selected system name={}", system.name);
                state.exploration_selected_system_id = Some(system.system_id);
            }
        }
    }
    ui.separator();
    match state.exploration_selected_system_id {
        Some(system_id) => show_system_detail(ui, reference, system_id),
        None => widgets::empty_panel(ui, "Select a system for details."),
    }
}

#[allow(clippy::too_many_lines)]
fn show_effects(ui: &mut egui::Ui, state: &mut AppState, reference: &ExplorationRef) {
    if reference.effects.is_empty() {
        widgets::empty_panel(ui, "No effect reference data.");
        return;
    }
    let effects = filter_effects(&reference.effects, &state.exploration_search);
    if effects.is_empty() {
        widgets::empty_panel(ui, "No effects match.");
    } else {
        let total = effects.len();
        ui.label(format!("{} effects", total));
        let shown = total.min(EXPLORATION_RENDER_MAX);
        if total > EXPLORATION_RENDER_MAX {
            ui.label(format!("Showing {} of {} effects.", shown, total));
        }
        for family in [
            EffectFamily::Pulsar,
            EffectFamily::BlackHole,
            EffectFamily::CataclysmicVariable,
            EffectFamily::Magnetar,
            EffectFamily::RedGiant,
            EffectFamily::WolfRayet,
        ] {
            let in_family: Vec<&&RefEffect> =
                effects.iter().filter(|e| e.family == family).collect();
            if in_family.is_empty() {
                continue;
            }
            ui.heading(family.label());
            for effect in in_family.iter().take(EXPLORATION_RENDER_MAX) {
                let selected = state.exploration_selected_family == Some(family)
                    && state.exploration_selected_strength.clamp(1, 6) == effect.strength;
                if ui
                    .selectable_label(selected, format!("Strength {}", effect.strength))
                    .clicked()
                {
                    tracing::info!(
                        "[EXPLORE] selected effect family={} strength={}",
                        family.label(),
                        effect.strength
                    );
                    state.exploration_selected_family = Some(family);
                    state.exploration_selected_strength = effect.strength.clamp(1, 6);
                }
            }
        }
    }
    if let Some(family) = state.exploration_selected_family {
        show_effect_detail(ui, reference, family, state.exploration_selected_strength);
    }
}

pub fn show(ui: &mut egui::Ui, state: &mut AppState) {
    ui.heading("Exploration");
    // Clone only the `Arc` handle out of the load state so the frame
    // can mutate view-local state while reading the catalogue; the
    // catalogue itself (2,631 systems plus indexes) is never cloned.
    let reference: Arc<ExplorationRef> = match &state.exploration {
        LoadState::Loading => {
            widgets::loading_panel(ui, "Loading exploration reference...");
            return;
        }
        LoadState::Error(_) => {
            widgets::error_panel(ui, EXPLORATION_ERROR);
            return;
        }
        LoadState::Empty => {
            match state.exploration_section {
                ExplorationSection::Types => {
                    widgets::empty_panel(ui, "No wormhole reference data.")
                }
                ExplorationSection::Systems => {
                    widgets::empty_panel(ui, "No system reference data.")
                }
                ExplorationSection::Effects => {
                    widgets::empty_panel(ui, "No effect reference data.")
                }
            }
            return;
        }
        LoadState::Ready(data) => Arc::clone(&data.reference),
    };
    ui.label(format!(
        "Reference data: CCP SDE {} (bundled, offline)",
        reference.manifest.sde_build
    ));
    let hint = search_hint(state.exploration_section);
    let focus = widgets::search_box(ui, &mut state.exploration_search, hint, state.focus_search);
    state.text_input_focused |= focus;
    if focus {
        state.focus_search = false;
    }
    ui.horizontal(|ui| {
        for section in ExplorationSection::ALL {
            let selected = state.exploration_section == section;
            if ui.selectable_label(selected, section.label()).clicked() {
                tracing::info!("[EXPLORE] section {}", section.label());
                state.exploration_section = section;
            }
        }
    });
    match state.exploration_section {
        ExplorationSection::Types => show_types(ui, state, &reference),
        ExplorationSection::Systems => show_systems(ui, state, &reference),
        ExplorationSection::Effects => show_effects(ui, state, &reference),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::names::exploration_ref::{group_by_code, RefModifier, RefSystem};

    #[allow(clippy::too_many_arguments)]
    fn wormhole(
        type_id: i64,
        code: &str,
        name: &str,
        class: Option<i64>,
        minutes: Option<i64>,
        total: Option<f64>,
        jump: Option<f64>,
        regen: Option<f64>,
    ) -> WormholeType {
        WormholeType {
            type_id,
            code: code.to_string(),
            name: name.to_string(),
            published: true,
            raw_target_class: class,
            raw_target_distribution: None,
            raw_max_stable_time_minutes: minutes,
            raw_total_mass_kg: total,
            raw_jump_mass_kg: jump,
            raw_regen_kg: regen,
        }
    }

    fn system(id: i64, name: &str) -> RefSystem {
        RefSystem {
            system_id: id,
            name: name.to_string(),
            constellation_id: None,
            region_id: None,
            constellation_name: Some("C".to_string()),
            region_name: Some("R".to_string()),
            raw_security: Some(-0.99),
            raw_class: Some(5),
            inherited_class: Some(5),
            inheritance_source: Some("constellation".to_string()),
            effect_beacon_type_id: None,
            visual_sun_type_id: None,
            effect_verified_absent: false,
        }
    }

    fn effect(family: EffectFamily, strength: u8, beacon: i64) -> RefEffect {
        RefEffect {
            family,
            strength,
            beacon_type_id: beacon,
            modifiers: Vec::new(),
        }
    }

    #[test]
    fn formatters_cover_design_values() {
        assert_eq!(format_kg(None), "Unknown");
        assert_eq!(format_kg(Some(2_000_000_000.0)), "2,000,000,000 kg");
        assert_eq!(format_kg(Some(375_000_000.0)), "375,000,000 kg");
        assert_eq!(format_kg(Some(0.0)), "0 kg");
        assert_eq!(format_kg(Some(12.5)), "12.5 kg");
        assert_eq!(format_regen(None), "Unknown");
        assert_eq!(format_regen(Some(1_250.0)), "1,250 kg/cycle");
        assert!(!format_regen(Some(1_250.0)).ends_with("kg/s"));
        assert_eq!(format_lifetime(None), "Unknown");
        assert_eq!(format_lifetime(Some(86400)), "86400s (1d 0h 0m)");
        assert_eq!(format_lifetime(Some(16200)), "16200s (4h 30m)");
        assert_eq!(format_lifetime(Some(0)), "0s (0m)");
        assert_eq!(format_percent(30.0), "+30%");
        assert_eq!(format_percent(-15.0), "-15%");
        assert_eq!(format_percent(0.0), "0%");
        assert_eq!(format_percent(-50.0), "-50%");
        assert_eq!(format_percent(200.0), "+200%");
        assert_eq!(format_percent(12.5), "+12.5%");
    }

    #[test]
    fn destination_chip_j_space_is_c1_to_c6() {
        for label in ["C1", "C2", "C3", "C4", "C5", "C6"] {
            assert!(
                destination_matches(label, DestinationFilter::JSpace),
                "{label}"
            );
        }
        assert!(!destination_matches("Highsec", DestinationFilter::JSpace));
        assert!(!destination_matches("J-space", DestinationFilter::JSpace));
        assert!(destination_matches("Highsec", DestinationFilter::Highsec));
        assert!(!destination_matches("Lowsec", DestinationFilter::Highsec));
        assert!(destination_matches("Pochven", DestinationFilter::Pochven));
        assert_eq!(DestinationFilter::ALL.len(), 5);
        assert_eq!(DestinationFilter::JSpace.label(), "J-space");
        assert_eq!(DestinationFilter::Pochven.label(), "Pochven");
    }

    #[test]
    fn sorted_groups_orders_code_then_type_id() {
        let catalog = vec![
            wormhole(
                3,
                "B274",
                "Wormhole B274",
                Some(7),
                Some(1440),
                Some(2e9),
                Some(375e6),
                None,
            ),
            wormhole(1, "A001", "Wormhole A001", Some(1), None, None, None, None),
            wormhole(
                2,
                "C729",
                "Wormhole C729",
                Some(-1),
                Some(720),
                Some(1e9),
                Some(410e6),
                None,
            ),
        ];
        let groups = group_by_code(&catalog);
        let mut reversed = groups.clone();
        reversed.reverse();
        let sorted = sorted_groups(&reversed, &catalog);
        assert_eq!(sorted.len(), 3);
        assert_eq!(sorted[0].code, "A001");
        assert_eq!(sorted[1].code, "B274");
        assert_eq!(sorted[2].code, "C729");
        // Same code twice (hand-built): smallest variant type ID wins.
        let a_late = CodeGroup {
            code: "A001".to_string(),
            variants: vec![2],
            shared_lifetime_seconds: None,
            shared_jump_mass_kg: None,
            jump_varies: false,
        };
        let a_early = CodeGroup {
            code: "A001".to_string(),
            variants: vec![1],
            shared_lifetime_seconds: None,
            shared_jump_mass_kg: None,
            jump_varies: false,
        };
        let tied = sorted_groups(&[a_late, a_early], &catalog);
        assert_eq!(tied[0].variants, vec![1]);
        assert_eq!(tied[1].variants, vec![2]);
    }

    #[test]
    fn sorted_systems_orders_name_then_id() {
        let systems = vec![
            system(20, "Thera"),
            system(10, "Thera"),
            system(5, "J005926"),
            system(30, "A-Block"),
        ];
        let sorted = sorted_systems(&systems);
        assert_eq!(sorted[0].name, "A-Block");
        assert_eq!(sorted[1].name, "J005926");
        assert_eq!(sorted[2].name, "Thera");
        assert_eq!(sorted[2].system_id, 10);
        assert_eq!(sorted[3].system_id, 20);
        assert!(sorted_systems(&[]).is_empty());
    }

    #[test]
    fn sorted_effects_orders_family_then_strength() {
        let effects = vec![
            effect(EffectFamily::WolfRayet, 6, 30879),
            effect(EffectFamily::Pulsar, 2, 30865),
            effect(EffectFamily::Pulsar, 1, 30844),
            effect(EffectFamily::WolfRayet, 1, 30849),
            effect(EffectFamily::Magnetar, 1, 30847),
        ];
        let sorted = sorted_effects(&effects);
        assert_eq!(sorted[0].family, EffectFamily::Pulsar);
        assert_eq!(sorted[0].strength, 1);
        assert_eq!(sorted[1].strength, 2);
        assert_eq!(sorted[2].family, EffectFamily::Magnetar);
        assert_eq!(sorted[3].family, EffectFamily::WolfRayet);
        assert_eq!(sorted[3].strength, 1);
        assert_eq!(sorted[4].strength, 6);
        assert!(sorted_effects(&[]).is_empty());
    }

    #[test]
    fn systems_filter_substring_prefix_empty_no_match() {
        let systems = vec![
            system(1, "Thera"),
            system(2, "J005926"),
            system(3, "J010569"),
            system(4, "Pochven"),
        ];
        assert_eq!(filter_systems(&systems, "").len(), 4);
        assert_eq!(filter_systems(&systems, "   ").len(), 4);
        let prefix = filter_systems(&systems, "ther");
        assert_eq!(prefix.len(), 1);
        assert_eq!(prefix[0].name, "Thera");
        let substring = filter_systems(&systems, "005");
        assert_eq!(substring.len(), 1);
        assert_eq!(substring[0].name, "J005926");
        let case = filter_systems(&systems, "j0");
        assert_eq!(case.len(), 2);
        assert!(filter_systems(&systems, "zzzz").is_empty());
    }

    #[test]
    fn effects_filter_substring_prefix_empty_no_match() {
        let reference = ExplorationRef::load_bundled().expect("bundled loads");
        assert_eq!(filter_effects(&reference.effects, "").len(), 36);
        assert_eq!(filter_effects(&reference.effects, "pulsar").len(), 6);
        assert_eq!(filter_effects(&reference.effects, "puls").len(), 6);
        assert_eq!(filter_effects(&reference.effects, "magnet").len(), 6);
        assert_eq!(filter_effects(&reference.effects, "wolf").len(), 6);
        // Name substring, case-insensitive.
        assert_eq!(filter_effects(&reference.effects, "CATACLYSMIC").len(), 6);
        assert!(filter_effects(&reference.effects, "zzzz").is_empty());
    }

    #[test]
    fn types_filter_exact_prefix_substring_empty_no_match() {
        let reference = ExplorationRef::load_bundled().expect("bundled loads");
        let all = filtered_types(&reference, "", None, false);
        assert!(!all.is_empty());
        let all_groups = group_by_code(&reference.types);
        assert_eq!(all.len(), all_groups.len());
        assert_eq!(
            group_result_counts(&all).0,
            group_result_counts(&all_groups).0
        );
        // Trimmed empty matches all as well.
        assert_eq!(
            filtered_types(&reference, "   ", None, false).len(),
            all.len()
        );
        let exact = filtered_types(&reference, " b274 ", None, false);
        assert_eq!(exact.len(), 1);
        assert_eq!(exact[0].code, "B274");
        let prefix = filtered_types(&reference, "b27", None, false);
        assert!(
            prefix.iter().any(|g| g.code == "B274"),
            "prefix b27 finds B274"
        );
        let substring = filtered_types(&reference, "274", None, false);
        assert!(
            substring.iter().any(|g| g.code == "B274"),
            "substring 274 finds B274"
        );
        assert!(filtered_types(&reference, "zzzz-no-match", None, false).is_empty());
        // Destination text participates in the same search.
        let highsec = filtered_types(&reference, "highsec", None, false);
        assert!(
            highsec.iter().any(|g| g.code == "B274"),
            "destination text finds B274"
        );
    }

    #[test]
    fn types_destination_and_capital_combine_without_clearing_search() {
        let reference = ExplorationRef::load_bundled().expect("bundled loads");
        // B274 is Highsec with 375,000,000 kg jump mass (below capital).
        assert_eq!(
            filtered_types(&reference, "B274", Some(DestinationFilter::Highsec), false).len(),
            1
        );
        assert!(
            filtered_types(&reference, "B274", Some(DestinationFilter::Lowsec), false).is_empty()
        );
        assert!(
            filtered_types(&reference, "B274", Some(DestinationFilter::JSpace), false).is_empty()
        );
        // Capital ANDs with the text: B274 is not capital-size, and
        // the text is not cleared (otherwise every capital type
        // would survive). Both single-condition results minus this
        // intersection prove the AND.
        assert!(
            filtered_types(&reference, "B274", None, true).is_empty(),
            "capital true keeps the B274 text condition"
        );
        let capital_only = filtered_types(&reference, "", None, true);
        assert!(!capital_only.is_empty());
        assert!(capital_only.iter().all(|g| g
            .variants
            .iter()
            .any(|&i| reference.types[i].is_capital_size())));
        // J-space chip keeps only C1-C6 destinations.
        let jspace = filtered_types(&reference, "", Some(DestinationFilter::JSpace), false);
        assert!(!jspace.is_empty());
        for group in &jspace {
            for &i in &group.variants {
                assert!(destination_matches(
                    &reference.types[i].destination_label(),
                    DestinationFilter::JSpace
                ));
            }
        }
    }

    #[test]
    fn group_counts_report_groups_and_total_types() {
        let reference = ExplorationRef::load_bundled().expect("bundled loads");
        let groups = group_by_code(&reference.types);
        let (code_groups, type_count) = group_result_counts(&groups);
        assert_eq!(code_groups, groups.len());
        assert_eq!(type_count, reference.types.len());
        assert!(groups.iter().any(|g| g.variants.len() > 1));
        assert_eq!(group_result_counts(&[]), (0, 0));
    }

    #[test]
    fn render_caps_cover_one_hundred_rows() {
        assert_eq!(EXPLORATION_RENDER_MAX, 100);
        // Oversized synthetic systems: shown is capped, total is kept.
        let systems: Vec<RefSystem> = (0..150i64)
            .map(|i| system(i, &format!("Sys{:03}", i)))
            .collect();
        let filtered = filter_systems(&systems, "");
        assert_eq!(filtered.len(), 150);
        assert_eq!(filtered.len().min(EXPLORATION_RENDER_MAX), 100);
        // Bundled code groups (102) also exceed the cap.
        let reference = ExplorationRef::load_bundled().expect("bundled loads");
        let groups = filtered_types(&reference, "", None, false);
        assert!(groups.len() > EXPLORATION_RENDER_MAX);
        assert_eq!(groups.len().min(EXPLORATION_RENDER_MAX), 100);
        // Effects never exceed it (36 rows).
        assert_eq!(reference.effects.len(), 36);
        assert_eq!(reference.effects.len().min(EXPLORATION_RENDER_MAX), 36);
    }

    #[test]
    fn modifier_lines_dedupe_shared_resonance_labels() {
        let effect = RefEffect {
            family: EffectFamily::Pulsar,
            strength: 1,
            beacon_type_id: 30844,
            modifiers: vec![
                RefModifier {
                    attribute_id: 1465,
                    label: "Armor damage resonance, all types".to_string(),
                    percent: 15.0,
                },
                RefModifier {
                    attribute_id: 1466,
                    label: "Armor damage resonance, all types".to_string(),
                    percent: 15.0,
                },
                RefModifier {
                    attribute_id: 1500,
                    label: "Capacitor recharge time".to_string(),
                    percent: -15.0,
                },
            ],
        };
        let lines = modifier_lines(&effect);
        assert_eq!(lines.len(), 2);
        assert_eq!(lines[0], "Armor damage resonance, all types +15%");
        assert_eq!(lines[1], "Capacitor recharge time -15%");
        assert!(lines[1].contains("time"));
        assert!(!lines[1].contains("cap recharge"));
    }

    #[test]
    fn live_and_demo_states_start_with_same_exploration_defaults() {
        // Design section 8.5: live and demo start from identical
        // exploration defaults, and the one bundled catalogue the
        // shell loads for both modes matches its own manifest row
        // counts. The shell's single load path for both modes is
        // covered by `exploration_startup_load_is_ready_or_fixed_error_sentence`.
        let live = AppState::new(false);
        let demo = AppState::new(true);
        assert!(live.exploration_search.is_empty());
        assert!(demo.exploration_search.is_empty());
        assert_eq!(live.exploration_section, demo.exploration_section);
        assert_eq!(
            live.exploration_selected_strength,
            demo.exploration_selected_strength
        );
        assert_eq!(live.exploration_selected_strength, 1);
        let reference = ExplorationRef::load_bundled().expect("bundled loads");
        assert_eq!(reference.manifest.sde_build, 3503375);
        assert_eq!(
            reference.manifest.row_counts.get("types"),
            Some(&reference.types.len())
        );
        assert_eq!(
            reference.manifest.row_counts.get("systems"),
            Some(&reference.systems.len())
        );
        assert_eq!(
            reference.manifest.row_counts.get("effects"),
            Some(&reference.effects.len())
        );
        assert_eq!(
            reference.manifest.row_counts.get("statics"),
            Some(&reference.statics.len())
        );
    }

    #[test]
    fn destination_narrowing_drops_non_matching_variants_of_a_code() {
        // One synthetic code whose two variants disagree on
        // destination (no bundled code does today): narrowing must
        // keep only the matching variant and recount from it alone.
        let types = vec![
            wormhole(
                1,
                "X001",
                "Synthetic X001 highsec",
                Some(7),
                Some(1440),
                Some(2e9),
                Some(375e6),
                Some(0.0),
            ),
            wormhole(
                2,
                "X001",
                "Synthetic X001 lowsec",
                Some(8),
                Some(960),
                Some(2e9),
                Some(375e6),
                Some(0.0),
            ),
            wormhole(
                3,
                "X002",
                "Synthetic X002",
                Some(9),
                Some(960),
                Some(2e9),
                Some(375e6),
                Some(0.0),
            ),
        ];
        let groups = group_by_code(&types);
        assert_eq!(group_result_counts(&groups), (2, 3));
        let highsec =
            narrow_groups_to_destination(groups.clone(), &types, DestinationFilter::Highsec);
        assert_eq!(group_result_counts(&highsec), (1, 1));
        assert_eq!(highsec[0].code, "X001");
        assert_eq!(highsec[0].variants, vec![0]);
        // Shared lifetime now describes only the kept variant
        // (1440 minutes), not the dropped 960-minute one.
        assert_eq!(highsec[0].shared_lifetime_seconds, Some(86400));
        let jspace = narrow_groups_to_destination(groups, &types, DestinationFilter::JSpace);
        assert!(jspace.is_empty());
    }
}
