//! Exploration: read-only offline wormhole reference browser over the
//! bundled `assets/sde/exploration.json` catalogue (design sections 7-8).
//! Every rendered string comes from the bundled reference; there is no
//! name resolution, no network, no character dependency, and no
//! `mode_notice` (its demo text would be false for real SDE data).
//! Raw EVE IDs (wormhole type IDs, beacon IDs, attribute IDs, system
//! IDs) are state and keys only, never rendered.

use super::widgets;
use crate::app::state::{AppState, DestinationFilter, ExplorationSection, LoadState, View};
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
    widgets::card(ui, |ui| {
        ui.horizontal_wrapped(|ui| {
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
        ui.label(
            egui::RichText::new(CAPITAL_QUALIFICATION)
                .size(super::tokens::TOKENS.typography.small)
                .color(super::theme::TEXT_SECONDARY),
        );
    });
    let groups = filtered_types(
        reference,
        &state.exploration_search,
        state.exploration_destination,
        state.exploration_capital_only,
    );
    ui.columns(2, |cols| {
        widgets::card(&mut cols[0], |ui| {
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
                egui::ScrollArea::vertical()
                    .id_salt("explore_types_scroll")
                    .max_height(460.0)
                    .show(ui, |ui| {
                        for group in groups.iter().take(EXPLORATION_RENDER_MAX) {
                            let mut row = group.code.clone();
                            if let Some(label) = shared_destination_label(group, &reference.types) {
                                row.push_str(&format!(" \u{00B7} {}", label));
                            }
                            if group.variants.len() > 1 {
                                row.push_str(&format!(
                                    " \u{00B7} {} variants",
                                    group.variants.len()
                                ));
                            }
                            let selected =
                                state.exploration_selected_code.as_deref() == Some(&group.code);
                            if ui.selectable_label(selected, row).clicked() {
                                tracing::info!("[EXPLORE] selected wormhole code={}", group.code);
                                state.exploration_selected_code = Some(group.code.clone());
                            }
                        }
                    });
            }
        });
        widgets::card(&mut cols[1], |ui| match &state.exploration_selected_code {
            Some(code) => show_type_detail(ui, reference, code),
            None => widgets::empty_panel(ui, "Select a wormhole code for details."),
        });
    });
}

#[allow(clippy::too_many_lines)]
fn show_systems(ui: &mut egui::Ui, state: &mut AppState, reference: &ExplorationRef) {
    if reference.systems.is_empty() {
        widgets::empty_panel(ui, "No system reference data.");
        return;
    }
    let systems = filter_systems(&reference.systems, &state.exploration_search);
    ui.columns(2, |cols| {
        widgets::card(&mut cols[0], |ui| {
            if systems.is_empty() {
                widgets::empty_panel(ui, "No systems match.");
            } else {
                let total = systems.len();
                ui.label(format!("{} systems", total));
                let shown = total.min(EXPLORATION_RENDER_MAX);
                if total > EXPLORATION_RENDER_MAX {
                    ui.label(format!("Showing {} of {} systems.", shown, total));
                }
                egui::ScrollArea::vertical()
                    .id_salt("explore_systems_scroll")
                    .max_height(460.0)
                    .show(ui, |ui| {
                        for system in systems.iter().take(EXPLORATION_RENDER_MAX) {
                            let row =
                                format!("{} \u{00B7} {}", system.name, system.security_label());
                            let selected =
                                state.exploration_selected_system_id == Some(system.system_id);
                            if ui.selectable_label(selected, row).clicked() {
                                tracing::info!("[EXPLORE] selected system name={}", system.name);
                                state.exploration_selected_system_id = Some(system.system_id);
                            }
                        }
                    });
            }
        });
        widgets::card(&mut cols[1], |ui| {
            match state.exploration_selected_system_id {
                Some(system_id) => show_system_detail(ui, reference, system_id),
                None => widgets::empty_panel(ui, "Select a system for details."),
            }
        });
    });
}

#[allow(clippy::too_many_lines)]
fn show_effects(ui: &mut egui::Ui, state: &mut AppState, reference: &ExplorationRef) {
    if reference.effects.is_empty() {
        widgets::empty_panel(ui, "No effect reference data.");
        return;
    }
    let effects = filter_effects(&reference.effects, &state.exploration_search);
    ui.columns(2, |cols| {
        widgets::card(&mut cols[0], |ui| {
            if effects.is_empty() {
                widgets::empty_panel(ui, "No effects match.");
            } else {
                let total = effects.len();
                ui.label(format!("{} effects", total));
                let shown = total.min(EXPLORATION_RENDER_MAX);
                if total > EXPLORATION_RENDER_MAX {
                    ui.label(format!("Showing {} of {} effects.", shown, total));
                }
                egui::ScrollArea::vertical()
                    .id_salt("explore_effects_scroll")
                    .max_height(460.0)
                    .show(ui, |ui| {
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
                                    && state.exploration_selected_strength.clamp(1, 6)
                                        == effect.strength;
                                if ui
                                    .selectable_label(
                                        selected,
                                        format!("Strength {}", effect.strength),
                                    )
                                    .clicked()
                                {
                                    tracing::info!(
                                        "[EXPLORE] selected effect family={} strength={}",
                                        family.label(),
                                        effect.strength
                                    );
                                    state.exploration_selected_family = Some(family);
                                    state.exploration_selected_strength =
                                        effect.strength.clamp(1, 6);
                                }
                            }
                        }
                    });
            }
        });
        widgets::card(&mut cols[1], |ui| {
            if let Some(family) = state.exploration_selected_family {
                show_effect_detail(ui, reference, family, state.exploration_selected_strength);
            } else {
                widgets::empty_panel(ui, "Select a wormhole effect for details.");
            }
        });
    });
}

/// Security band for strip node coloring (TOKENS sec_* only).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SecurityBand {
    High,
    Low,
    Null,
    Wormhole,
}

/// Mass status for one chain node (spec R10): a known limit,
/// an unpaired K162 (Unknown), or a public Eve-Scout row,
/// which never reports mass ("Mass not reported").
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum MassState {
    Known(i64),
    Unknown,
    NotReported,
}

impl MassState {
    pub fn label(&self) -> String {
        match self {
            Self::Known(kg) => format_kg(Some(*kg as f64)),
            Self::Unknown => "Unknown (K162)".to_string(),
            Self::NotReported => "Mass not reported".to_string(),
        }
    }
}

/// One Wormhole Subway Chain Strip node. Names only — the
/// system id is never stored here, so it cannot be rendered.
#[derive(Debug, Clone, PartialEq)]
pub struct SubwayNode {
    pub system_name: String,
    pub class_label: String,
    pub effect_label: String,
    pub band: SecurityBand,
    pub eol: bool,
    pub mass: MassState,
}

/// One connector between adjacent chain nodes; `eol` drives
/// the dashed `<4h` rendering from `eol_dashed`.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct SubwayConnector {
    pub eol: bool,
}

/// EOL decay: dashed ring when under 4h remain (spec R10:
/// `0 < remaining < 4h`; exactly 4h is stable, at/past expiry
/// the edge is gone, not dashed).
pub fn eol_dashed(remaining_secs: Option<i64>) -> bool {
    matches!(remaining_secs, Some(s) if s > 0 && s < 4 * 3600)
}

fn band_for(system: &RefSystem) -> SecurityBand {
    use crate::names::exploration_ref::SecurityCategory;
    match system.category() {
        SecurityCategory::Highsec => SecurityBand::High,
        SecurityCategory::Lowsec => SecurityBand::Low,
        SecurityCategory::Nullsec => SecurityBand::Null,
        _ => SecurityBand::Wormhole,
    }
}

fn class_label_for(system: &RefSystem) -> String {
    match system.inherited_class.or(system.raw_class) {
        Some(class @ 1..=6) => format!("C{class}"),
        Some(12) => "Thera".to_string(),
        Some(25) => "Pochven".to_string(),
        Some(class) => format!("C{class}"),
        None => system.security_label(),
    }
}

fn effect_label_for(system: &RefSystem, reference: &ExplorationRef) -> String {
    match effect_for_system(system, reference) {
        EffectResolution::Applied {
            family, strength, ..
        } => format!("{} {}", family.label(), strength),
        EffectResolution::None => "No effect".to_string(),
        EffectResolution::Unknown => "Effect unknown".to_string(),
    }
}

/// Order real edges into a display chain (no static systems).
/// Local confirmed edges and public snapshot edges merge as
/// undirected hops; the walk starts at an endpoint (smallest
/// name wins ties) and follows unvisited neighbours. EOL and
/// mass derive from the edge entering each node (the first
/// node uses its outgoing edge) against `now` (demo anchor via
/// `state.now_utc()` upstream). Empty input stays empty so the
/// strip can show an honest "No confirmed connections" state.
pub fn ordered_chain(
    local_edges: &[crate::exploration::router::RouterEdge],
    snapshot_edges: &[crate::exploration::router::RouterEdge],
    reference: &ExplorationRef,
    now: i64,
) -> (Vec<SubwayNode>, Vec<SubwayConnector>) {
    use crate::exploration::router::EdgeKind;
    use std::collections::HashMap;
    // Undirected hop table: key (min_id, max_id) -> (edge, public).
    let mut hops: HashMap<(i64, i64), (crate::exploration::router::RouterEdge, bool)> =
        HashMap::new();
    for (edges, public) in [(local_edges, false), (snapshot_edges, true)] {
        for edge in edges {
            if edge.kind != EdgeKind::Wormhole || edge.from_id == edge.to_id {
                continue;
            }
            if edge.expires_at.is_some_and(|exp| now >= exp) {
                continue;
            }
            let key = (edge.from_id.min(edge.to_id), edge.from_id.max(edge.to_id));
            // Local confirmed edges win over public duplicates.
            if public && hops.contains_key(&key) {
                continue;
            }
            hops.insert(key, (edge.clone(), public));
        }
    }
    if hops.is_empty() {
        return (Vec::new(), Vec::new());
    }
    let mut adjacency: HashMap<i64, Vec<i64>> = HashMap::new();
    for (a, b) in hops.keys() {
        adjacency.entry(*a).or_default().push(*b);
        adjacency.entry(*b).or_default().push(*a);
    }
    let name_of = |id: i64| {
        reference
            .system_by_id(id)
            .map(|s| s.name.clone())
            .unwrap_or_else(|| "Unknown system".to_string())
    };
    let mut starts: Vec<i64> = adjacency
        .iter()
        .filter(|(_, neighbours)| neighbours.len() == 1)
        .map(|(id, _)| *id)
        .collect();
    if starts.is_empty() {
        starts = adjacency.keys().copied().collect();
    }
    starts.sort_by_key(|a| name_of(*a));
    let start = starts[0];
    let mut order: Vec<i64> = vec![start];
    let mut visited: std::collections::HashSet<i64> = [start].into_iter().collect();
    let mut current = start;
    loop {
        let mut neighbours: Vec<i64> = adjacency
            .get(&current)
            .cloned()
            .unwrap_or_default()
            .into_iter()
            .filter(|id| !visited.contains(id))
            .collect();
        neighbours.sort_by_key(|a| name_of(*a));
        let Some(next) = neighbours.first().copied() else {
            break;
        };
        visited.insert(next);
        order.push(next);
        current = next;
    }
    let hop_between = |a: i64, b: i64| {
        hops.get(&(a.min(b), a.max(b)))
            .map(|(edge, public)| (edge.clone(), *public))
    };
    let mut nodes = Vec::new();
    let mut connectors = Vec::new();
    for (i, id) in order.iter().enumerate() {
        let Some(system) = reference.system_by_id(*id) else {
            continue;
        };
        let entering = if i == 0 {
            order.get(1).and_then(|next| hop_between(*id, *next))
        } else {
            hop_between(order[i - 1], *id)
        };
        let (eol, mass) = match &entering {
            Some((edge, public)) => {
                let remaining = edge.expires_at.map(|exp| exp - now);
                let mass = if *public {
                    MassState::NotReported
                } else {
                    match edge.effective_max_jump_mass_kg() {
                        Some(limit) => MassState::Known(limit),
                        None => MassState::Unknown,
                    }
                };
                (eol_dashed(remaining), mass)
            }
            None => (false, MassState::Unknown),
        };
        if i > 0 {
            if let Some((edge, _)) = hop_between(order[i - 1], *id) {
                connectors.push(SubwayConnector {
                    eol: eol_dashed(edge.expires_at.map(|exp| exp - now)),
                });
            }
        }
        nodes.push(SubwayNode {
            system_name: system.name.clone(),
            class_label: class_label_for(system),
            effect_label: effect_label_for(system, reference),
            band: band_for(system),
            eol,
            mass,
        });
    }
    tracing::debug!(
        "[EXPLORE] ordered_chain nodes={} connectors={}",
        nodes.len(),
        connectors.len()
    );
    (nodes, connectors)
}

fn band_color(band: SecurityBand) -> egui::Color32 {
    let t = super::tokens::TOKENS;
    match band {
        SecurityBand::High => t.sec_high,
        SecurityBand::Low => t.sec_low,
        SecurityBand::Null => t.sec_null,
        SecurityBand::Wormhole => t.sec_wh,
    }
}

/// Elide `text` with an ellipsis so its measured galley fits
/// `max_width` (zero overlap: every caption is measured with
/// `layout_no_wrap` and truncated into its per-node slot).
fn elide_to_width(fonts: &egui::Painter, text: &str, font: egui::FontId, max_width: f32) -> String {
    if max_width <= 0.0 {
        return String::new();
    }
    let full = fonts.layout_no_wrap(text.to_string(), font.clone(), egui::Color32::TRANSPARENT);
    if full.size().x <= max_width {
        return text.to_string();
    }
    let ellipsis = "\u{2026}";
    let mut best = ellipsis.to_string();
    for end in 0..=text.len() {
        if !text.is_char_boundary(end) {
            continue;
        }
        let candidate = format!("{}{ellipsis}", &text[..end]);
        let galley =
            fonts.layout_no_wrap(candidate.clone(), font.clone(), egui::Color32::TRANSPARENT);
        if galley.size().x <= max_width {
            best = candidate;
        } else {
            break;
        }
    }
    best
}

fn mass_ring_color(mass: MassState) -> egui::Color32 {
    let t = super::tokens::TOKENS;
    match mass {
        MassState::Known(_) => t.positive,
        MassState::Unknown => t.warning,
        MassState::NotReported => t.text_disabled,
    }
}

/// Horizontal Subway Chain Strip via painter over REAL edges:
/// nodes in chain order with class, system, weather, and mass
/// captions; an inner mass ring and an outer dashed EOL ring
/// (R10, two independent dimensions); connectors dashed when
/// that connection is EOL (<4h). Every measurement resolves
/// through DesignTokens strip fields; captions are measured
/// and elided into their node pitch so labels never overlap.
fn show_subway_strip(ui: &mut egui::Ui, state: &AppState, reference: &ExplorationRef) {
    let t = super::tokens::TOKENS;
    let now = state.now_utc().timestamp();
    let snapshot_edges = state
        .exploration_snapshot
        .as_ref()
        .map(|snap| crate::exploration::evescout::snapshot_edges(snap, now, false))
        .unwrap_or_default();
    let (nodes, connectors) = ordered_chain(
        &state.exploration_chain_edges,
        &snapshot_edges,
        reference,
        now,
    );
    widgets::card(ui, |ui| {
        ui.label(
            egui::RichText::new("Wormhole subway chain")
                .font(t.typography.heading_font())
                .color(t.text_primary),
        );
        if nodes.is_empty() {
            widgets::empty_panel(ui, "No confirmed connections");
            return;
        }
        let width = ui.available_width().max(t.strip_min_width);
        let (rect, _resp) =
            ui.allocate_exact_size(egui::vec2(width, t.strip_height), egui::Sense::hover());
        let painter = ui.painter_at(rect);
        let cy = rect.center().y - t.strip_center_drop;
        let count = nodes.len();
        let span = (rect.width() - t.strip_inset_x - t.strip_inset_x).max(t.strip_min_width * 0.0);
        let pitch = if count > 1 {
            span / (count - 1) as f32
        } else {
            span
        };
        let xs: Vec<f32> = nodes
            .iter()
            .enumerate()
            .map(|(i, _)| rect.left() + t.strip_inset_x + pitch * i as f32)
            .collect();
        // Connectors first (under nodes): dashed when EOL.
        for (i, pair) in xs.windows(2).enumerate() {
            let eol = connectors.get(i).is_some_and(|c| c.eol);
            let from = egui::pos2(pair[0], cy);
            let to = egui::pos2(pair[1], cy);
            if eol {
                let segments = (pitch / t.strip_mass_ring_radius).max(1.0) as usize;
                for seg in (0..segments).step_by(2) {
                    let start_t = seg as f32 / segments as f32;
                    let end_t = ((seg + 1) as f32 / segments as f32).min(1.0);
                    painter.line_segment(
                        [from + (to - from) * start_t, from + (to - from) * end_t],
                        egui::Stroke::new(t.strip_connector_width, t.warning),
                    );
                }
            } else {
                painter.line_segment(
                    [from, to],
                    egui::Stroke::new(t.strip_connector_width, t.cyan_telemetry),
                );
            }
        }
        for (i, node) in nodes.iter().enumerate() {
            let center = egui::pos2(xs[i], cy);
            let color = band_color(node.band);
            painter.circle_filled(center, t.strip_node_radius, t.bg_card_elevated);
            painter.circle_stroke(
                center,
                t.strip_node_radius,
                egui::Stroke::new(t.strip_node_stroke, color),
            );
            // Inner mass ring (R10 mass dimension).
            painter.circle_stroke(
                center,
                t.strip_mass_ring_radius,
                egui::Stroke::new(t.strip_ring_stroke, mass_ring_color(node.mass)),
            );
            if node.eol {
                // Outer dashed EOL ring (R10 time dimension).
                let mut angle = 0.0f32;
                let step = t.strip_dash_step_deg.to_radians();
                let arc = t.strip_dash_arc_deg.to_radians();
                while angle < std::f32::consts::TAU {
                    let a1 = angle;
                    let a2 = angle + arc;
                    painter.line_segment(
                        [
                            center
                                + egui::vec2(
                                    a1.cos() * t.strip_eol_ring_radius,
                                    a1.sin() * t.strip_eol_ring_radius,
                                ),
                            center
                                + egui::vec2(
                                    a2.cos() * t.strip_eol_ring_radius,
                                    a2.sin() * t.strip_eol_ring_radius,
                                ),
                        ],
                        egui::Stroke::new(t.strip_ring_stroke, t.warning),
                    );
                    angle += step;
                }
            }
            painter.text(
                center,
                egui::Align2::CENTER_CENTER,
                &node.class_label,
                t.typography.small_font(),
                t.text_primary,
            );
            let slot = pitch.max(t.strip_min_width * 0.0 + t.strip_node_radius * 2.0);
            for (text, offset, ink) in [
                (
                    node.system_name.clone(),
                    t.strip_name_offset_y,
                    t.text_primary,
                ),
                (
                    node.effect_label.clone(),
                    t.strip_weather_offset_y,
                    t.text_muted,
                ),
                (
                    node.mass.label(),
                    t.strip_mass_offset_y,
                    mass_ring_color(node.mass),
                ),
            ] {
                let elided = elide_to_width(&painter, &text, t.typography.small_font(), slot);
                painter.text(
                    center + egui::vec2(0.0, offset),
                    egui::Align2::CENTER_CENTER,
                    &elided,
                    t.typography.small_font(),
                    ink,
                );
            }
            if node.eol {
                painter.text(
                    center + egui::vec2(0.0, t.strip_eol_offset_y),
                    egui::Align2::CENTER_CENTER,
                    "EOL <4h",
                    t.typography.small_font(),
                    t.warning,
                );
            }
        }
    });
}

fn resolve_system_id(reference: &ExplorationRef, name: &str) -> Option<i64> {
    let needle = name.trim();
    reference
        .systems
        .iter()
        .find(|s| s.name.eq_ignore_ascii_case(needle))
        .map(|s| s.system_id)
}

fn router_nodes(reference: &ExplorationRef) -> Vec<crate::exploration::router::SystemNode> {
    reference
        .systems
        .iter()
        .map(|s| crate::exploration::router::SystemNode {
            system_id: s.system_id,
            name: s.name.clone(),
            security: s.raw_security,
            wormhole_class: s.inherited_class.or(s.raw_class),
        })
        .collect()
}

/// In-memory demo import: same upsert/retire semantics as
/// `notebook::import_scan`, against state only (zero DB).
fn apply_demo_import(
    state: &mut AppState,
    system_id: i64,
    rows: &[crate::exploration::notebook::ParsedScanRow],
) {
    use crate::exploration::notebook::{SignatureType, TrackedSignature};
    let now = state.now_utc().timestamp();
    let character_id = state.active_character_id.unwrap_or(0);
    for row in rows {
        let previous = state
            .exploration_signatures
            .iter()
            .find(|s| s.system_id == system_id && s.signature_id == row.signature_id)
            .cloned();
        if let Some(prev) = &previous {
            if prev.signature_type == SignatureType::Wormhole
                && row.signature_type != SignatureType::Wormhole
            {
                if let Some(dest) = prev.destination_system_id {
                    state.exploration_chain_edges.retain(|e| {
                        !((e.from_id == system_id && e.to_id == dest)
                            || (e.from_id == dest && e.to_id == system_id))
                    });
                }
            }
        }
        if let Some(existing) = state
            .exploration_signatures
            .iter_mut()
            .find(|s| s.system_id == system_id && s.signature_id == row.signature_id)
        {
            existing.signature_type = row.signature_type;
            existing.name = row.name.clone();
            existing.observed_at = now;
            if previous.as_ref().is_some_and(|p| {
                p.signature_type == SignatureType::Wormhole
                    && row.signature_type != SignatureType::Wormhole
            }) {
                existing.destination_system_id = None;
                existing.verified = false;
            }
        } else {
            state.exploration_signatures.push(TrackedSignature {
                character_id,
                system_id,
                signature_id: row.signature_id.clone(),
                signature_type: row.signature_type,
                name: row.name.clone(),
                destination_system_id: None,
                verified: false,
                observed_at: now,
            });
        }
    }
    state.exploration_signatures_system_id = Some(system_id);
}

/// Probe Scanner import, signature Confirm, and route finder
/// (#646 repair wiring). Scan episodes stay strictly local:
/// demo writes only in-memory state; live writes queue shell
/// requests drained off the UI thread. No network is added.
fn show_domain_panels(ui: &mut egui::Ui, state: &mut AppState, reference: &ExplorationRef) {
    use crate::exploration::notebook::SignatureType;
    use crate::exploration::router::{RouteMode, ShipClass};
    let now = state.now_utc().timestamp();
    // Live chain load: once per active character.
    if !state.demo
        && state.active_character_id.is_some()
        && state.exploration_loaded_for != state.active_character_id
        && !state.exploration_load_requested
    {
        state.exploration_load_requested = true;
    }
    widgets::card(ui, |ui| {
        ui.label(
            egui::RichText::new("Probe scanner")
                .font(super::tokens::TOKENS.typography.heading_font())
                .color(super::tokens::TOKENS.text_primary),
        );
        ui.label("Current system");
        ui.add(
            egui::TextEdit::singleline(&mut state.exploration_route_origin)
                .hint_text("Current system name"),
        );
        ui.label("Probe Scanner paste");
        ui.add(
            egui::TextEdit::multiline(&mut state.exploration_paste)
                .hint_text("Paste Probe Scanner rows")
                .desired_rows(3),
        );
        if ui.button("Import scan").clicked() {
            match crate::exploration::notebook::parse_probe_scan(&state.exploration_paste) {
                Ok(outcome) => {
                    let origin_name = state.exploration_route_origin.clone();
                    match resolve_system_id(reference, &origin_name) {
                        Some(system_id) => {
                            state.exploration_origin_system_id = Some(system_id);
                            if state.demo {
                                apply_demo_import(state, system_id, &outcome.rows);
                                state.exploration_status =
                                    Some(format!("Imported {} signatures", outcome.rows.len()));
                            } else if state.active_character_id.is_some() {
                                state.exploration_pending_import = Some((system_id, outcome.rows));
                                state.exploration_status = Some("Import queued".to_string());
                            } else {
                                state.exploration_status =
                                    Some("Select a character to track signatures".to_string());
                            }
                            if !outcome.diagnostics.is_empty() {
                                state.exploration_status =
                                    Some(format!("{} rows rejected", outcome.diagnostics.len()));
                            }
                        }
                        None => {
                            state.exploration_status =
                                Some("Current system name not found".to_string());
                        }
                    }
                }
                Err(error) => {
                    state.exploration_status = Some(error.to_string());
                }
            }
            tracing::info!("[EXPLORE] probe scan import requested");
        }
        if let Some(status) = &state.exploration_status {
            ui.label(status.clone());
        }
        if state.exploration_signatures.is_empty() {
            widgets::empty_panel(ui, "No signatures tracked yet.");
        } else {
            let signatures = state.exploration_signatures.clone();
            for signature in &signatures {
                let type_name = format!("{:?}", signature.signature_type);
                let row = format!("{} \u{00B7} {}", signature.signature_id, type_name);
                let selected = state.exploration_selected_signature.as_deref()
                    == Some(&signature.signature_id);
                if ui.selectable_label(selected, row).clicked() {
                    state.exploration_selected_signature = Some(signature.signature_id.clone());
                }
            }
        }
        if let Some(signature_id) = state.exploration_selected_signature.clone() {
            let signature = state
                .exploration_signatures
                .iter()
                .find(|s| s.signature_id == signature_id)
                .cloned();
            if let Some(signature) = signature {
                ui.label(format!("Confirm connection {}", signature.signature_id));
                ui.label("Destination system");
                ui.add(
                    egui::TextEdit::singleline(&mut state.exploration_confirm_dest_name)
                        .hint_text("Destination system name"),
                );
                ui.label("Wormhole code");
                ui.add(
                    egui::TextEdit::singleline(&mut state.exploration_confirm_code)
                        .hint_text("Wormhole code"),
                );
                ui.label("Max jump mass kg (optional)");
                ui.add(
                    egui::TextEdit::singleline(&mut state.exploration_confirm_mass)
                        .hint_text("Max jump mass kg"),
                );
                ui.label("Expiry hours from now (optional)");
                ui.add(
                    egui::TextEdit::singleline(&mut state.exploration_confirm_expiry_hours)
                        .hint_text("Expiry hours"),
                );
                if ui.button("Confirm connection").clicked() {
                    let dest_name = state.exploration_confirm_dest_name.clone();
                    let code = state.exploration_confirm_code.trim().to_string();
                    let mass = state.exploration_confirm_mass.trim().parse::<i64>().ok();
                    let expires_at = state
                        .exploration_confirm_expiry_hours
                        .trim()
                        .parse::<i64>()
                        .ok()
                        .map(|hours| now + hours * 3600);
                    match resolve_system_id(reference, &dest_name) {
                        _ if code.is_empty() => {
                            state.exploration_status =
                                Some("Wormhole code must not be empty".to_string());
                        }
                        _ if signature.signature_type != SignatureType::Wormhole => {
                            state.exploration_status =
                                Some("Only a wormhole signature can own a connection".to_string());
                        }
                        Some(to_system_id) => {
                            let from_system_id = signature.system_id;
                            if state.demo {
                                let edge = crate::exploration::router::RouterEdge::wormhole(
                                    from_system_id,
                                    to_system_id,
                                    &code,
                                    mass,
                                    expires_at,
                                );
                                let mut reverse = edge.clone();
                                reverse.from_id = to_system_id;
                                reverse.to_id = from_system_id;
                                state.exploration_chain_edges.push(edge);
                                state.exploration_chain_edges.push(reverse);
                                if let Some(tracked) = state
                                    .exploration_signatures
                                    .iter_mut()
                                    .find(|s| s.signature_id == signature_id)
                                {
                                    tracked.destination_system_id = Some(to_system_id);
                                    tracked.verified = true;
                                }
                                state.exploration_status = Some("Connection confirmed".to_string());
                            } else {
                                state.exploration_confirm_request =
                                    Some(crate::app::state::ExplorationConfirmRequest {
                                        signature_id: signature_id.clone(),
                                        from_system_id,
                                        to_system_id,
                                        wormhole_code: code,
                                        max_jump_mass_kg: mass,
                                        expires_at,
                                    });
                                state.exploration_status = Some("Confirmation queued".to_string());
                            }
                        }
                        None => {
                            state.exploration_status =
                                Some("Destination system name not found".to_string());
                        }
                    }
                    tracing::info!("[EXPLORE] confirm connection requested");
                }
            }
        }
    });
    widgets::card(ui, |ui| {
        ui.label(
            egui::RichText::new("Route finder")
                .font(super::tokens::TOKENS.typography.heading_font())
                .color(super::tokens::TOKENS.text_primary),
        );
        ui.label("Origin system");
        ui.add(
            egui::TextEdit::singleline(&mut state.exploration_route_origin)
                .hint_text("Current system name"),
        );
        let stale_origin = state.exploration_origin_system_id.is_some()
            && state.exploration_signatures_system_id.is_some()
            && state.exploration_origin_system_id != state.exploration_signatures_system_id;
        if stale_origin {
            ui.label("Origin may be stale");
            ui.checkbox(&mut state.exploration_origin_confirmed, "Confirm origin");
        }
        ui.label("Destination system");
        ui.add(
            egui::TextEdit::singleline(&mut state.exploration_route_destination)
                .hint_text("Destination system name"),
        );
        ui.label("Route mode");
        ui.horizontal_wrapped(|ui| {
            for mode in [
                RouteMode::Shortest,
                RouteMode::Safest,
                RouteMode::LessSecure,
            ] {
                if ui
                    .selectable_label(state.exploration_route_mode == mode, mode.label())
                    .clicked()
                {
                    state.exploration_route_mode = mode;
                }
            }
        });
        ui.label("Ship mass class");
        ui.horizontal_wrapped(|ui| {
            for (label, ship) in [
                ("Any", None),
                ("Frigate", Some(ShipClass::Frigate)),
                ("Battleship", Some(ShipClass::Battleship)),
                ("Capital", Some(ShipClass::Capital)),
            ] {
                if ui
                    .selectable_label(state.exploration_route_ship == ship, label)
                    .clicked()
                {
                    state.exploration_route_ship = ship;
                }
            }
        });
        if ui.button("Find route").clicked() {
            let origin = resolve_system_id(reference, &state.exploration_route_origin);
            let destination = resolve_system_id(reference, &state.exploration_route_destination);
            match (origin, destination) {
                (Some(origin_id), Some(destination_id)) => {
                    if stale_origin && !state.exploration_origin_confirmed {
                        state.exploration_route_message =
                            Some("Confirm the stale origin before routing".to_string());
                    } else if state.demo {
                        let snapshot_edges = state
                            .exploration_snapshot
                            .as_ref()
                            .map(|snap| {
                                crate::exploration::evescout::snapshot_edges(snap, now, false)
                            })
                            .unwrap_or_default();
                        let mut edges = state.exploration_chain_edges.clone();
                        edges.extend(snapshot_edges);
                        let route = crate::exploration::router::find_route(
                            &router_nodes(reference),
                            &edges,
                            origin_id,
                            destination_id,
                            state.exploration_route_mode,
                            state.exploration_route_ship,
                            now,
                        );
                        state.exploration_route_message = if route.is_some() {
                            None
                        } else {
                            Some("No route in the available connection graph".to_string())
                        };
                        state.exploration_route_result = route;
                    } else {
                        state.exploration_route_request =
                            Some(crate::app::state::ExplorationRouteRequest {
                                origin_id,
                                destination_id,
                                mode: state.exploration_route_mode,
                                ship: state.exploration_route_ship,
                            });
                        state.exploration_route_message = Some("Routing queued".to_string());
                    }
                }
                _ => {
                    state.exploration_route_message =
                        Some("Origin or destination name not found".to_string());
                }
            }
            tracing::info!("[EXPLORE] find route requested");
        }
        if let Some(message) = &state.exploration_route_message {
            ui.label(message.clone());
        }
        if let Some(route) = &state.exploration_route_result {
            if route.system_ids.len() <= 1 {
                ui.label("No travel required");
            } else {
                for step in &route.steps {
                    let name = reference
                        .system_by_id(step.system_id)
                        .map(|s| s.name.clone())
                        .unwrap_or_else(|| "Unknown system".to_string());
                    let via = match &step.via {
                        None => "Origin".to_string(),
                        Some(crate::exploration::router::RouteVia::Gate) => "Stargate".to_string(),
                        Some(crate::exploration::router::RouteVia::Wormhole { code }) => {
                            format!("Wormhole {}", code.as_deref().unwrap_or("Unknown"))
                        }
                    };
                    ui.label(format!("{} \u{00B7} {}", name, via));
                }
            }
        }
    });
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
    widgets::card(ui, |ui| {
        ui.label(
            egui::RichText::new(format!(
                "Reference data: CCP SDE {} (bundled, offline)",
                reference.manifest.sde_build
            ))
            .color(super::theme::TEXT_SECONDARY),
        );
        let hint = search_hint(state.exploration_section);
        let focus = widgets::search_box(
            ui,
            &mut state.exploration_search,
            hint,
            state.focus_search && state.view == View::Exploration,
        );
        state.text_input_focused |= focus;
        if focus && state.view == View::Exploration {
            state.focus_search = false;
        }
        ui.horizontal_wrapped(|ui| {
            for section in ExplorationSection::ALL {
                let selected = state.exploration_section == section;
                if ui.selectable_label(selected, section.label()).clicked() {
                    tracing::info!("[EXPLORE] section {}", section.label());
                    state.exploration_section = section;
                }
            }
        });
    });
    show_subway_strip(ui, state, &reference);
    show_domain_panels(ui, state, &reference);
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
    fn ordered_chain_uses_real_edges_only() {
        let reference = ExplorationRef::load_bundled().expect("bundled loads");
        // No edges: honest empty chain, never a static chain.
        let (nodes, connectors) = ordered_chain(&[], &[], &reference, 1_000);
        assert!(nodes.is_empty());
        assert!(connectors.is_empty());
        // One real EOL edge between two bundled systems.
        let a = reference
            .systems
            .iter()
            .find(|s| s.name == "Thera")
            .unwrap();
        let b = reference
            .systems
            .iter()
            .find(|s| s.name == "J002216")
            .unwrap();
        let edge = crate::exploration::router::RouterEdge::wormhole(
            a.system_id,
            b.system_id,
            "B274",
            Some(375_000_000),
            Some(1_000 + 2 * 3600),
        );
        let (nodes, connectors) = ordered_chain(&[edge], &[], &reference, 1_000);
        assert_eq!(nodes.len(), 2);
        assert_eq!(connectors.len(), 1);
        assert!(connectors[0].eol, "under-4h connector is EOL");
        assert!(nodes.iter().any(|n| n.eol));
        assert!(nodes.iter().all(|n| !n.effect_label.is_empty()));
        assert_eq!(nodes[1].mass, MassState::Known(375_000_000));
    }

    #[test]
    fn eol_dashed_only_inside_four_hour_window() {
        assert!(eol_dashed(Some(1)));
        assert!(eol_dashed(Some(4 * 3600 - 1)));
        assert!(!eol_dashed(Some(4 * 3600)), "exactly 4h is stable");
        assert!(!eol_dashed(Some(0)), "expired is pruned, not dashed");
        assert!(!eol_dashed(Some(-5)));
        assert!(!eol_dashed(None));
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
