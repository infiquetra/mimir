//! Pure fitting-resources calculation over the bundled catalogue.
//!
//! [`fitting_resources`] computes CPU and power grid used versus
//! the hull's output for one [`CharacterFitting`] from base
//! (unmodified) dogma attributes plus the fitted modules' and
//! rigs' output bonuses (see below).
//! [`fitting_resources_with_skills`] is the skill-aware entry point:
//! with `Some(levels)` it raises ship outputs by CPU Management
//! (skill 3426, +5% ship CPU output per trained level) and Power
//! Grid Management (skill 3413, +5% ship power output per trained
//! level), each as one unpenalized percent entry
//! (`output * (1 + 0.05 * level)`, level 5 = ×1.25), and it
//! reduces module needs by the five trained need-reduction
//! skills (see the `NEED_REDUCTION_ENTRIES` table below; Weapon
//! Upgrades and
//! Advanced Weapon Upgrades plus Energy Grid Upgrades,
//! Electronics Upgrades, and Shield Upgrades, each as one
//! unpenalized post-percent factor per matched modifier entry,
//! `need * (1 + percent * level / 100)`, level 5 = ×0.75 or
//! ×0.90 respectively). With `None` it returns exactly
//! [`fitting_resources`]. The base function applies no skill
//! scaling. Outputs are composed with the fitted modules' and
//! rigs' output bonuses on both arms (`docs/output-bonuses-
//! design.md` section 4); implants, and bonuses or reductions
//! from module need modifiers beyond the shipped skill
//! reductions, subsystems, and the ship itself, are not
//! applied, so totals can differ from EVE. See
//! `docs/fitting-skill-resources-design.md` and
//! `docs/fitting-need-reductions-design.md`.
//!
//! The module is pure computation over the bundled catalogue — no
//! egui, no state, no network, no database. It depends on
//! [`CharacterFitting`] / [`FittingItem`] and [`FittingTypes`],
//! the same dependencies the EFT parser already takes. It tests
//! ESI flag prefixes itself instead of depending on the UI enum,
//! following the [`crate::fitting::eft::ImportSection`]
//! independence precedent.

use crate::esi::models::{CharacterFitting, CharacterSkills, FittingItem};
use crate::names::fitting_types::FittingTypes;

/// CPU Management: +5% ship CPU output (attribute 48) per trained
/// level. Provenance: Flutter `dogma_engine.dart` `_skillModifiers`
/// at `ed698d3` (3426 → `cpuOutput` = 48 at 0.05/level); name in the
/// bundled skills catalogue.
pub const CPU_MANAGEMENT_SKILL_ID: i64 = 3426;

/// Power Grid Management: +5% ship power output (attribute 11) per
/// trained level. Same provenance (3413 → `powerOutput` = 11 at
/// 0.05/level). Skill 3418 is Capacitor Management and must never
/// appear here.
pub const POWER_GRID_MANAGEMENT_SKILL_ID: i64 = 3413;

/// Weapon Upgrades: -5% CPU need (attribute 50) per trained
/// level on filter-matched modules. Provenance: SDE attribute
/// 310 = -5.0 on type 3318; effects 581/675/677/3519 in
/// dogmaEffects modifierInfo.
pub const WEAPON_UPGRADES_SKILL_ID: i64 = 3318;

/// Advanced Weapon Upgrades: -2% power grid need (attribute 30)
/// per trained level on filter-matched modules. Provenance:
/// SDE attribute 323 = -2.0 on type 11207; effects 1638/3520
/// in dogmaEffects modifierInfo.
pub const ADVANCED_WEAPON_UPGRADES_SKILL_ID: i64 = 11207;

/// Energy Grid Upgrades: -5% CPU need per trained level on
/// filter-matched modules. Provenance: SDE attribute
/// 310 = -5.0 on type 3424; effect 396.
pub const ENERGY_GRID_UPGRADES_SKILL_ID: i64 = 3424;

/// Electronics Upgrades: -5% CPU need per trained level on
/// filter-matched modules. Provenance: SDE attribute
/// 310 = -5.0 on type 3432; effect 212.
pub const ELECTRONICS_UPGRADES_SKILL_ID: i64 = 3432;

/// Shield Upgrades: -5% power grid need per trained level on
/// filter-matched modules. Provenance: SDE attribute
/// 323 = -5.0 on type 3425; effect 273.
pub const SHIELD_UPGRADES_SKILL_ID: i64 = 3425;

/// Trained levels of the two resource output skills and the
/// five need-reduction skills, already clamped to `0..=5` by
/// [`resource_skill_levels`].
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct ResourceSkillLevels {
    pub cpu_management: i32,
    pub power_grid_management: i32,
    pub weapon_upgrades: i32,
    pub advanced_weapon_upgrades: i32,
    pub energy_grid_upgrades: i32,
    pub electronics_upgrades: i32,
    pub shield_upgrades: i32,
}

/// One module need-reduction filter: what the fitted module
/// must be for the entry to apply. `RequiredSkill` is exact
/// integer equality over the module's required-skill list (the
/// runtime form of Flutter's six-slot `requiresSkill`);
/// `Group` is exact equality over the module's inventory
/// group.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum NeedFilter {
    RequiredSkill(i64),
    Group(i64),
}

/// One skill need-reduction modifier entry: the source skill,
/// the dimension it touches, the per-level percent (stored as
/// a percent, -5.0/-2.0, never a 0.05-style fraction, so the
/// table can be checked against the `dgmTypeAttributes` rows
/// character for character), and the filter.
#[derive(Debug, Clone, Copy, PartialEq)]
struct NeedReductionEntry {
    source_skill_id: i64,
    is_cpu: bool,
    per_level_percent: f64,
    filter: NeedFilter,
}

/// The twelve skill need-reduction modifier entries, in the
/// section 2.1 table order of
/// `docs/fitting-need-reductions-design.md`. Each entry is one
/// shipped modifier fact: source skill, dimension, per-level
/// percent, filter. The effect id is shown in the trailing
/// comment so a reviewer can diff the table against
/// `dogmaEffects.jsonl` mechanically.
///
/// Deliberately absent, per design section 2.3: effect 672
/// (itemID-domain `weaponUpgradesSkillBoostCpu` — Flutter
/// skips every `itemID` modifier outright, so no inspected
/// body defines it); the 132/211/246 item-chain (the
/// client-side spelling of the ×level scaling this code
/// already models once, in the factor — counting them again
/// would double-scale); the three unpublished Advanced
/// siblings 11204/11206/11208 (0.0 bias, never in a trained
/// payload); implants and every module/rig/subsystem/ship
/// need modifier (the general pipeline this slice does not
/// build). No entry may be read from `dogma.json` or
/// `effect_modifiers.json` at runtime.
const NEED_REDUCTION_ENTRIES: [NeedReductionEntry; 12] = [
    // Weapon Upgrades (3318), CPU, -5.0/lvl.
    NeedReductionEntry {
        source_skill_id: WEAPON_UPGRADES_SKILL_ID,
        is_cpu: true,
        per_level_percent: -5.0,
        filter: NeedFilter::RequiredSkill(3300), // effect 581
    },
    NeedReductionEntry {
        source_skill_id: WEAPON_UPGRADES_SKILL_ID,
        is_cpu: true,
        per_level_percent: -5.0,
        filter: NeedFilter::RequiredSkill(55033), // effect 581
    },
    NeedReductionEntry {
        source_skill_id: WEAPON_UPGRADES_SKILL_ID,
        is_cpu: true,
        per_level_percent: -5.0,
        filter: NeedFilter::RequiredSkill(3421), // effect 675
    },
    NeedReductionEntry {
        source_skill_id: WEAPON_UPGRADES_SKILL_ID,
        is_cpu: true,
        per_level_percent: -5.0,
        filter: NeedFilter::RequiredSkill(3319), // effect 677
    },
    NeedReductionEntry {
        source_skill_id: WEAPON_UPGRADES_SKILL_ID,
        is_cpu: true,
        per_level_percent: -5.0,
        filter: NeedFilter::Group(862), // effect 3519
    },
    // Advanced Weapon Upgrades (11207), power, -2.0/lvl.
    NeedReductionEntry {
        source_skill_id: ADVANCED_WEAPON_UPGRADES_SKILL_ID,
        is_cpu: false,
        per_level_percent: -2.0,
        filter: NeedFilter::RequiredSkill(3300), // effect 1638
    },
    NeedReductionEntry {
        source_skill_id: ADVANCED_WEAPON_UPGRADES_SKILL_ID,
        is_cpu: false,
        per_level_percent: -2.0,
        filter: NeedFilter::RequiredSkill(3319), // effect 1638
    },
    NeedReductionEntry {
        source_skill_id: ADVANCED_WEAPON_UPGRADES_SKILL_ID,
        is_cpu: false,
        per_level_percent: -2.0,
        filter: NeedFilter::RequiredSkill(55033), // effect 1638
    },
    NeedReductionEntry {
        source_skill_id: ADVANCED_WEAPON_UPGRADES_SKILL_ID,
        is_cpu: false,
        per_level_percent: -2.0,
        filter: NeedFilter::RequiredSkill(28073), // effect 3520
    },
    // Energy Grid Upgrades (3424), CPU, -5.0/lvl.
    NeedReductionEntry {
        source_skill_id: ENERGY_GRID_UPGRADES_SKILL_ID,
        is_cpu: true,
        per_level_percent: -5.0,
        filter: NeedFilter::RequiredSkill(3424), // effect 396
    },
    // Electronics Upgrades (3432), CPU, -5.0/lvl.
    NeedReductionEntry {
        source_skill_id: ELECTRONICS_UPGRADES_SKILL_ID,
        is_cpu: true,
        per_level_percent: -5.0,
        filter: NeedFilter::RequiredSkill(3432), // effect 212
    },
    // Shield Upgrades (3425), power, -5.0/lvl.
    NeedReductionEntry {
        source_skill_id: SHIELD_UPGRADES_SKILL_ID,
        is_cpu: false,
        per_level_percent: -5.0,
        filter: NeedFilter::RequiredSkill(3425), // effect 273
    },
];

/// The raw (unclamped) trained level of a need-reduction
/// source skill. Lookup is by source skill, never by filter
/// skill: the filter names what the *module* must require;
/// the level comes from the source skill. Training Gunnery
/// (3300) or any other filter skill changes nothing by
/// itself.
fn source_level(levels: &ResourceSkillLevels, skill_id: i64) -> i32 {
    match skill_id {
        WEAPON_UPGRADES_SKILL_ID => levels.weapon_upgrades,
        ADVANCED_WEAPON_UPGRADES_SKILL_ID => levels.advanced_weapon_upgrades,
        ENERGY_GRID_UPGRADES_SKILL_ID => levels.energy_grid_upgrades,
        ELECTRONICS_UPGRADES_SKILL_ID => levels.electronics_upgrades,
        SHIELD_UPGRADES_SKILL_ID => levels.shield_upgrades,
        _ => 0,
    }
}

/// Whether one entry matches one catalogue row: a
/// required-skill entry matches when its filter skill is an
/// element of the row's required-skill list (exact integer
/// equality); the group entry matches when the row's group
/// is exactly the entry's group. A missing filter field
/// matches nothing (it is counted unreduced by the caller,
/// never treated as proven).
fn entry_matches(
    entry: &NeedReductionEntry,
    row: &crate::names::fitting_types::FittingType,
) -> bool {
    match entry.filter {
        NeedFilter::RequiredSkill(skill) => row
            .required_skill_ids
            .as_ref()
            .is_some_and(|ids| ids.contains(&skill)),
        NeedFilter::Group(group) => row.group_id == Some(group),
    }
}

/// The unpenalized post-percent product over one dimension's
/// entries for one row: `Π (1 + percent * clamped_source_level
/// / 100)` over matched entries (one factor per matched
/// modifier entry — two entries of one skill, or two skills
/// on one dimension, multiply). One factor per entry, never
/// per-level compounding: level 5 gives ×0.75 (or ×0.90 for
/// Advanced), not 0.95⁵/0.98⁵. Level 0 is factor 1, whether
/// the row is present at trained level 0 or absent from a
/// loaded bundle.
fn dimension_factor(
    levels: &ResourceSkillLevels,
    row: &crate::names::fitting_types::FittingType,
    is_cpu: bool,
) -> f64 {
    let mut factor = 1.0;
    for entry in &NEED_REDUCTION_ENTRIES {
        if entry.is_cpu != is_cpu {
            continue;
        }
        if entry_matches(entry, row) {
            let level = clamp_level(source_level(levels, entry.source_skill_id));
            factor *= 1.0 + entry.per_level_percent * level as f64 / 100.0;
        }
    }
    factor
}

/// Whether any source skill for one dimension has a clamped
/// level above 0 (CPU: 3318/3424/3432; power: 11207/3425).
/// When every relevant level is 0 the factor is provably 1
/// whatever the filters say, so a missing filter field
/// proves nothing and is never counted unreduced.
fn any_relevant_level(levels: &ResourceSkillLevels, is_cpu: bool) -> bool {
    if is_cpu {
        clamp_level(levels.weapon_upgrades) > 0
            || clamp_level(levels.energy_grid_upgrades) > 0
            || clamp_level(levels.electronics_upgrades) > 0
    } else {
        clamp_level(levels.advanced_weapon_upgrades) > 0 || clamp_level(levels.shield_upgrades) > 0
    }
}

fn clamp_level(level: i32) -> i32 {
    level.clamp(0, 5)
}

/// All seven trained levels from one loaded skills payload.
/// Absent rows and present level-0 rows both yield 0 (inside
/// a loaded payload an absent row means not injected, which
/// is arithmetically level 0); duplicate rows yield the last
/// row; every value is clamped to `0..=5`. Reads
/// `trained_skill_level` (the grounded parity field), never
/// `active_skill_level`.
pub fn resource_skill_levels(skills: &CharacterSkills) -> ResourceSkillLevels {
    // Last-wins over duplicates, mirroring the BTreeMap::collect
    // precedent in `crate::ui::skills::trained_levels`.
    let mut cpu: Option<i32> = None;
    let mut power: Option<i32> = None;
    let mut weapon: Option<i32> = None;
    let mut advanced: Option<i32> = None;
    let mut grid: Option<i32> = None;
    let mut electronics: Option<i32> = None;
    let mut shield: Option<i32> = None;
    for skill in &skills.skills {
        match skill.skill_id {
            CPU_MANAGEMENT_SKILL_ID => cpu = Some(skill.trained_skill_level),
            POWER_GRID_MANAGEMENT_SKILL_ID => power = Some(skill.trained_skill_level),
            WEAPON_UPGRADES_SKILL_ID => weapon = Some(skill.trained_skill_level),
            ADVANCED_WEAPON_UPGRADES_SKILL_ID => advanced = Some(skill.trained_skill_level),
            ENERGY_GRID_UPGRADES_SKILL_ID => grid = Some(skill.trained_skill_level),
            ELECTRONICS_UPGRADES_SKILL_ID => electronics = Some(skill.trained_skill_level),
            SHIELD_UPGRADES_SKILL_ID => shield = Some(skill.trained_skill_level),
            _ => {}
        }
    }
    ResourceSkillLevels {
        cpu_management: clamp_level(cpu.unwrap_or(0)),
        power_grid_management: clamp_level(power.unwrap_or(0)),
        weapon_upgrades: clamp_level(weapon.unwrap_or(0)),
        advanced_weapon_upgrades: clamp_level(advanced.unwrap_or(0)),
        energy_grid_upgrades: clamp_level(grid.unwrap_or(0)),
        electronics_upgrades: clamp_level(electronics.unwrap_or(0)),
        shield_upgrades: clamp_level(shield.unwrap_or(0)),
    }
}

/// One resource dimension: the (reduced) need summed over
/// counted fitted modules against the hull's output.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct ResourceBudget {
    pub used: f64,
    pub output: f64,
    /// Output before fitted-module output bonuses: the hull
    /// output on the None path, and the hull output times
    /// the shipped skill factor on the Some path. Equals
    /// `output` exactly when no output carrier is counted.
    pub base_output: f64,
    /// Consuming-section rows with no usable value for this
    /// dimension (absent from the catalogue, no attribute row, or
    /// an unusable value). Counted in rows, never silently zero.
    pub excluded_modules: usize,
    /// Sum of counted needs before skill reductions. Equals
    /// `used` when no levels are applied.
    pub base_used: f64,
    /// Counted modules kept at full need in this dimension
    /// because the catalogue row carries no filter data to
    /// prove or disprove a reduction (absent `groupId` /
    /// `requiredSkillIds` while a relevant level is above 0).
    /// A module whose reduction cannot be proven keeps its
    /// full base need in `used` and is counted here, never
    /// excluded. Zero on the shipped catalogue.
    pub unreduced_modules: usize,
    /// Counted rows the catalogue marks as carriers in this
    /// dimension whose output bonus cannot be applied, in
    /// quantity units, on both arms. Never summed with the
    /// other dimension's count, with `excluded_modules`, or
    /// with `unreduced_modules`.
    pub output_unapplied_modules: usize,
}

impl ResourceBudget {
    pub fn remaining(&self) -> f64 {
        self.output - self.used
    }

    pub fn is_over(&self) -> bool {
        self.used > self.output
    }
}

/// Base CPU / power grid outcome for one fitting.
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum FittingResources {
    Available {
        cpu: ResourceBudget,
        power: ResourceBudget,
    },
    /// The catalogue has no usable ship output for this fitting's
    /// ship, so no honest numbers exist.
    ShipNoOutput,
}

/// ESI flags whose items consume CPU or power grid: low, medium,
/// or high slots only. Rigs, subsystems, drones, fighters, cargo,
/// catch-all flags, and loaded charges never consume.
fn is_consuming_flag(flag: &str) -> bool {
    flag.starts_with("LoSlot") || flag.starts_with("MedSlot") || flag.starts_with("HiSlot")
}

/// Rig or subsystem flags whose catalogue-absent rows still
/// exclude in both dimensions (docs/output-bonuses-design.md
/// section 4): a wholly absent counted row may be an output
/// rig the bundled data cannot describe. Present rows under
/// these flags still neither consume nor exclude for needs.
fn is_rig_or_subsystem_flag(flag: &str) -> bool {
    flag.starts_with("RigSlot") || flag.starts_with("SubSystemSlot")
}

/// A catalogue value is usable only when present, finite, and
/// non-negative. A present `0.0` stays a real zero; anything else
/// is treated as no data for that dimension.
fn usable(value: Option<f64>) -> Option<f64> {
    value.filter(|v| v.is_finite() && *v >= 0.0)
}

/// CPU / power grid resources for one fitting. Equivalent to
/// [`fitting_resources_with_skills`] with `None`.
pub fn fitting_resources(fitting: &CharacterFitting, catalogue: &FittingTypes) -> FittingResources {
    fitting_resources_with_skills(fitting, catalogue, None)
}

/// Resources, with ship outputs raised by the two skills
/// and module needs reduced by the five need-reduction skills
/// when `levels` is `Some`. `None` is exactly
/// [`fitting_resources`]. `output` is
/// `(hull output + fitted-module adds) * fitted-module muls *
/// sorted percent chain` per dimension
/// (`docs/output-bonuses-design.md` section 4), where the
/// chain holds the fitted modules' percents plus one skill
/// percent of `5 * clamped_level` per dimension, so flat
/// adds are scaled by multipliers, module percents, and the
/// skill percent alike; `base_output` is the comparison
/// figure, the hull output scaled by
/// `1 + 0.05 * clamped_level` with no module bonuses. Each
/// counted need is reduced per module by `dimension_factor`
/// before the quantity multiplication, `used` carries the
/// reduced sum and `base_used` the pre-reduction sum.
/// Excluded-need checks run first: an excluded module is
/// never also unreduced, and an excluded row is never also
/// output-unapplied.
pub fn fitting_resources_with_skills(
    fitting: &CharacterFitting,
    catalogue: &FittingTypes,
    levels: Option<ResourceSkillLevels>,
) -> FittingResources {
    let mut cpu_excluded: usize = 0;
    let mut power_excluded: usize = 0;

    let ship_row = if fitting.ship_type_id > 0 {
        catalogue.lookup_by_id(fitting.ship_type_id)
    } else {
        None
    };
    let Some(ship) = ship_row else {
        return FittingResources::ShipNoOutput;
    };
    if ship.category_id != 6 {
        return FittingResources::ShipNoOutput;
    }
    let Some(cpu_output) = usable(ship.cpu_output) else {
        return FittingResources::ShipNoOutput;
    };
    let Some(power_output) = usable(ship.power_output) else {
        return FittingResources::ShipNoOutput;
    };

    // Skill scaling: defensive re-clamp so a hand-built
    // ResourceSkillLevels cannot exceed ×1.25. This shipped
    // expression is `base_output` verbatim, never re-derived
    // from the helper, so it is bit-identical to the output
    // this block has always shown.
    let (cpu_base_output, power_base_output) = match levels {
        None => (cpu_output, power_output),
        Some(levels) => {
            let cpu_factor = 1.0 + 0.05 * clamp_level(levels.cpu_management) as f64;
            let power_factor = 1.0 + 0.05 * clamp_level(levels.power_grid_management) as f64;
            (cpu_output * cpu_factor, power_output * power_factor)
        }
    };

    // Fitted-module output bonuses (docs/output-bonuses-
    // design.md section 4): the helper reads no catalogue
    // field itself and is called exactly once per dimension
    // pair. A helper `None` here is unreachable (the ship
    // gate above already passed) but returns `ShipNoOutput`
    // without panicking; a bonused `None` in either
    // dimension takes the whole result unavailable (no
    // per-dimension partial budget).
    let bonused = crate::fitting::ship_resistances::bonused_outputs(
        fitting,
        catalogue,
        levels.map(|l| (l.cpu_management, l.power_grid_management)),
    );
    let Some(bonused) = bonused else {
        return FittingResources::ShipNoOutput;
    };
    let (Some(cpu_output), Some(power_output)) = (bonused.values[0], bonused.values[1]) else {
        return FittingResources::ShipNoOutput;
    };
    let cpu_output_unapplied = bonused.cpu_output_unapplied_modules;
    let power_output_unapplied = bonused.power_output_unapplied_modules;

    let mut cpu_used: f64 = 0.0;
    let mut cpu_base_used: f64 = 0.0;
    let mut cpu_unreduced: usize = 0;
    let mut power_used: f64 = 0.0;
    let mut power_base_used: f64 = 0.0;
    let mut power_unreduced: usize = 0;
    // Defensive re-clamp for the need side, mirroring the
    // output scaling above: a hand-built ResourceSkillLevels
    // must not exceed ×0.75 / ×0.90 per entry. The factor
    // helper clamps each source level itself, so the live
    // value only gates the unprovable count below.
    let cpu_relevant = levels.is_some_and(|l| any_relevant_level(&l, true));
    let power_relevant = levels.is_some_and(|l| any_relevant_level(&l, false));
    for item in &fitting.items {
        if !consuming_item(item) {
            // A catalogue-absent counted (rig/subsystem)
            // row excludes in both dimensions: it may be an
            // output rig the bundled data cannot describe.
            // Present rows under these flags neither consume
            // nor exclude for needs.
            if item.type_id > 0
                && item.quantity.max(0) > 0
                && is_rig_or_subsystem_flag(&item.flag)
                && catalogue.lookup_by_id(item.type_id).is_none()
            {
                let quantity_units = usize::try_from(item.quantity.max(0)).unwrap_or(0);
                cpu_excluded = cpu_excluded.saturating_add(quantity_units);
                power_excluded = power_excluded.saturating_add(quantity_units);
            }
            continue;
        }
        let quantity = item.quantity.max(0);
        if quantity == 0 {
            continue;
        }
        let quantity_f = quantity as f64;
        // Excluded counts modules, matching the multiplied sums:
        // a stacked row of five uncounted modules reports five.
        let quantity_units = usize::try_from(quantity).unwrap_or(0);
        let Some(row) = catalogue.lookup_by_id(item.type_id) else {
            cpu_excluded = cpu_excluded.saturating_add(quantity_units);
            power_excluded = power_excluded.saturating_add(quantity_units);
            continue;
        };
        match usable(row.cpu) {
            Some(value) => {
                cpu_base_used += quantity_f * value;
                // Unreduced (never excluded): counted at full
                // need because the filter data that dimension's
                // entries need is absent. Only when a relevant
                // level is above 0 — at all 0 the factor is
                // provably 1 whatever the filters say. An
                // unreduced row takes factor 1 even when the
                // present half of its filter data matches an
                // entry: counted unreduced means counted at
                // full need, never partially reduced.
                let cpu_unprovable =
                    cpu_relevant && (row.required_skill_ids.is_none() || row.group_id.is_none());
                let factor = match (levels, cpu_unprovable) {
                    (Some(l), false) => dimension_factor(&l, row, true),
                    _ => 1.0,
                };
                cpu_used += quantity_f * value * factor;
                if cpu_unprovable {
                    cpu_unreduced = cpu_unreduced.saturating_add(quantity_units);
                }
            }
            None => cpu_excluded = cpu_excluded.saturating_add(quantity_units),
        }
        match usable(row.power) {
            Some(value) => {
                power_base_used += quantity_f * value;
                let power_unprovable = power_relevant && row.required_skill_ids.is_none();
                let factor = match (levels, power_unprovable) {
                    (Some(l), false) => dimension_factor(&l, row, false),
                    _ => 1.0,
                };
                power_used += quantity_f * value * factor;
                if power_unprovable {
                    power_unreduced = power_unreduced.saturating_add(quantity_units);
                }
            }
            None => power_excluded = power_excluded.saturating_add(quantity_units),
        }
    }

    FittingResources::Available {
        cpu: ResourceBudget {
            used: cpu_used,
            output: cpu_output,
            base_output: cpu_base_output,
            excluded_modules: cpu_excluded,
            base_used: cpu_base_used,
            unreduced_modules: cpu_unreduced,
            output_unapplied_modules: cpu_output_unapplied,
        },
        power: ResourceBudget {
            used: power_used,
            output: power_output,
            base_output: power_base_output,
            excluded_modules: power_excluded,
            base_used: power_base_used,
            unreduced_modules: power_unreduced,
            output_unapplied_modules: power_output_unapplied,
        },
    }
}

fn consuming_item(item: &FittingItem) -> bool {
    item.type_id > 0 && is_consuming_flag(&item.flag)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::fitting::eft::{parse_eft, EftImportOutcome};

    fn item(flag: &str, quantity: i64, type_id: i64) -> FittingItem {
        FittingItem {
            flag: flag.to_string(),
            quantity,
            type_id,
        }
    }

    fn fitting(ship_type_id: i64, items: Vec<FittingItem>) -> CharacterFitting {
        CharacterFitting {
            fitting_id: 1,
            name: "test".to_string(),
            description: None,
            ship_type_id,
            items,
        }
    }

    fn bundled() -> FittingTypes {
        FittingTypes::load_bundled().expect("bundled catalogue loads")
    }

    fn budgets(result: FittingResources) -> (ResourceBudget, ResourceBudget) {
        match result {
            FittingResources::Available { cpu, power } => (cpu, power),
            FittingResources::ShipNoOutput => panic!("expected Available, got ShipNoOutput"),
        }
    }

    fn assert_close(actual: f64, expected: f64) {
        assert!(
            (actual - expected).abs() < 1e-9,
            "expected {expected}, got {actual}"
        );
    }

    // Oracle rows read from scripts/sde/dgmTypeAttributes.csv.bz2:
    // (587, 48) = 130.0, (587, 11) = 41.0; (2048, 50) = 30.0,
    // (2048, 30) = 1.0; (1183, 50/30) = 6.0/6.0; (438, 50/30) =
    // 15.0/11.0; (448, 50/30) = 36.0/1.0; (2889, 50/30) = 9.0/4.0.
    #[test]
    fn hull_only_rifter_has_zero_used_and_full_remaining() {
        let catalogue = bundled();
        let (cpu, power) = budgets(fitting_resources(&fitting(587, vec![]), &catalogue));
        assert_close(cpu.used, 0.0);
        assert_close(cpu.output, 130.0);
        assert_close(power.used, 0.0);
        assert_close(power.output, 41.0);
        assert_close(cpu.remaining(), 130.0);
        assert_close(power.remaining(), 41.0);
        assert_eq!(cpu.excluded_modules, 0);
        assert_eq!(power.excluded_modules, 0);
        assert!(!cpu.is_over());
        assert!(!power.is_over());
    }

    #[test]
    fn rifter_with_damage_control_ii_in_low_slot() {
        let catalogue = bundled();
        let fit = fitting(587, vec![item("LoSlot0", 1, 2048)]);
        let (cpu, power) = budgets(fitting_resources(&fit, &catalogue));
        assert_close(cpu.used, 30.0);
        assert_close(power.used, 1.0);
        assert_close(cpu.remaining(), 100.0);
        assert_close(power.remaining(), 40.0);
        assert_eq!(cpu.excluded_modules, 0);
        assert_eq!(power.excluded_modules, 0);
    }

    // Sample-fit oracle through the shared synthesis path. Used is
    // 30+6+15+36+9*3 = 114.0 CPU and 1+6+11+1+4*3 = 31.0 power;
    // remaining 16.0/10.0; the rig, the loaded charge, the drones,
    // and the cargo neither count nor exclude.
    #[test]
    fn sample_fit_oracle_through_eft_synthesis() {
        let sample = concat!(
            "[Rifter, Sample Brawler]\n",
            "Damage Control II\n",
            "Small Armor Repairer II\n",
            "\n",
            "1MN Afterburner II\n",
            "Warp Scrambler II\n",
            "\n",
            "200mm AutoCannon II, Republic Fleet EMP S\n",
            "200mm AutoCannon II\n",
            "200mm AutoCannon II\n",
            "\n",
            "Small Projectile Burst Aerator I\n",
            "[Empty Rig slot]\n",
            "\n",
            "Hobgoblin II x2\n",
            "\n",
            "EMP S x200\n",
            "Nanite Repair Paste x8"
        );
        let catalogue = bundled();
        let synth = match parse_eft(sample, &catalogue) {
            EftImportOutcome::Imported(fitting) => fitting.to_character_fitting(),
            EftImportOutcome::Failed(fatal) => panic!("sample EFT must import: {fatal:?}"),
        };
        let (cpu, power) = budgets(fitting_resources(&synth, &catalogue));
        assert_close(cpu.used, 114.0);
        assert_close(power.used, 31.0);
        assert_close(cpu.remaining(), 16.0);
        assert_close(power.remaining(), 10.0);
        assert_eq!(cpu.excluded_modules, 0);
        assert_eq!(power.excluded_modules, 0);
    }

    // (2049) has no 50/30 rows in the cache (it is a blueprint,
    // category 9, so the generator emits no needs); (1236) is a
    // genuine zero-cost module with no rows; 999999 is absent from
    // the catalogue. Each adds 1 to both excluded counts and 0 to
    // both sums.
    #[test]
    fn unknown_and_dataless_slot_rows_are_excluded_not_zeroed() {
        let catalogue = bundled();
        let fit = fitting(
            587,
            vec![
                item("LoSlot0", 1, 999999),
                item("LoSlot1", 1, 2049),
                item("LoSlot2", 1, 1236),
            ],
        );
        let (cpu, power) = budgets(fitting_resources(&fit, &catalogue));
        assert_close(cpu.used, 0.0);
        assert_close(power.used, 0.0);
        assert_eq!(cpu.excluded_modules, 3);
        assert_eq!(power.excluded_modules, 3);
    }

    #[test]
    fn excluded_counts_modules_not_rows_for_stacked_rows() {
        // The UI says "N fitted modules"; a stacked slot row of
        // five unknown modules must report five, matching the
        // multiplied sums (reviewer F3).
        let catalogue = bundled();
        let fit = fitting(587, vec![item("LoSlot0", 5, 999999)]);
        let (cpu, power) = budgets(fitting_resources(&fit, &catalogue));
        assert_eq!(cpu.excluded_modules, 5);
        assert_eq!(power.excluded_modules, 5);
    }

    // (33981) Limited Hyperspatial Accelerator carries only a power
    // row: (30) = 1.0, no (50) row in the cache.
    #[test]
    fn power_only_row_counts_power_and_excludes_cpu() {
        let catalogue = bundled();
        let fit = fitting(587, vec![item("LoSlot0", 1, 33981)]);
        let (cpu, power) = budgets(fitting_resources(&fit, &catalogue));
        assert_close(cpu.used, 0.0);
        assert_close(power.used, 1.0);
        assert_eq!(cpu.excluded_modules, 1);
        assert_eq!(power.excluded_modules, 0);
    }

    // (1355) Reactor Control Unit II carries (50) = 22.0 and
    // (30) = 0.0: a present explicit zero, not an absence.
    #[test]
    fn explicit_zero_power_counts_as_real_zero() {
        let catalogue = bundled();
        let fit = fitting(587, vec![item("LoSlot0", 1, 1355)]);
        let (cpu, power) = budgets(fitting_resources(&fit, &catalogue));
        assert_close(cpu.used, 22.0);
        assert_close(power.used, 0.0);
        assert_eq!(cpu.excluded_modules, 0);
        assert_eq!(power.excluded_modules, 0);
    }

    // The same counted module under a non-consuming flag
    // contributes nothing and excludes nothing, including an
    // unknown type under DroneBay.
    #[test]
    fn non_consuming_sections_neither_count_nor_exclude() {
        let catalogue = bundled();
        let flags = [
            "RigSlot0",
            "SubSystemSlot0",
            "DroneBay",
            "FighterBay",
            "Cargo",
            "Foo",
            "",
        ];
        for flag in flags {
            let fit = fitting(587, vec![item(flag, 1, 2048)]);
            let (cpu, power) = budgets(fitting_resources(&fit, &catalogue));
            assert_close(cpu.used, 0.0);
            assert_close(power.used, 0.0);
            assert_eq!(cpu.excluded_modules, 0, "flag {flag}");
            assert_eq!(power.excluded_modules, 0, "flag {flag}");
        }
        let fit = fitting(587, vec![item("DroneBay", 1, 999999)]);
        let (cpu, power) = budgets(fitting_resources(&fit, &catalogue));
        assert_close(cpu.used, 0.0);
        assert_close(power.used, 0.0);
        assert_eq!(cpu.excluded_modules, 0);
        assert_eq!(power.excluded_modules, 0);
    }

    // Slot belonging is never judged: Damage Control II costs the
    // same in any low/medium/high slot, dated by the flag prefix.
    #[test]
    fn slot_flag_prefixes_consume_regardless_of_module() {
        let catalogue = bundled();
        for flag in ["LoSlot0", "MedSlot7", "HiSlot3"] {
            let fit = fitting(587, vec![item(flag, 1, 2048)]);
            let (cpu, power) = budgets(fitting_resources(&fit, &catalogue));
            assert_close(cpu.used, 30.0);
            assert_close(power.used, 1.0);
            assert_eq!(cpu.excluded_modules, 0, "flag {flag}");
            assert_eq!(power.excluded_modules, 0, "flag {flag}");
        }
    }

    #[test]
    fn quantity_multiplies_and_clamps() {
        let catalogue = bundled();
        let fit = fitting(587, vec![item("LoSlot0", 3, 2048)]);
        let (cpu, power) = budgets(fitting_resources(&fit, &catalogue));
        assert_close(cpu.used, 90.0);
        assert_close(power.used, 3.0);

        for quantity in [0, -5] {
            let fit = fitting(587, vec![item("LoSlot0", quantity, 2048)]);
            let (cpu, power) = budgets(fitting_resources(&fit, &catalogue));
            assert_close(cpu.used, 0.0);
            assert_close(power.used, 0.0);
            assert_eq!(cpu.excluded_modules, 0);
            assert_eq!(power.excluded_modules, 0);
        }
        for type_id in [0, -1] {
            let fit = fitting(587, vec![item("LoSlot0", 1, type_id)]);
            let (cpu, power) = budgets(fitting_resources(&fit, &catalogue));
            assert_close(cpu.used, 0.0);
            assert_close(power.used, 0.0);
            assert_eq!(cpu.excluded_modules, 0);
            assert_eq!(power.excluded_modules, 0);
        }
    }

    #[test]
    fn huge_quantity_stays_finite_and_reports_over() {
        let catalogue = bundled();
        let fit = fitting(587, vec![item("LoSlot0", i64::MAX, 2048)]);
        let (cpu, power) = budgets(fitting_resources(&fit, &catalogue));
        assert!(cpu.used.is_finite());
        assert!(cpu.is_over());
        assert!(power.used.is_finite());
        assert!(power.is_over());
        assert_eq!(cpu.excluded_modules, 0);
        assert_eq!(power.excluded_modules, 0);
    }

    #[test]
    fn ship_failures_return_no_output() {
        let catalogue = bundled();
        for ship_type_id in [999999, 2048, 0, -1] {
            let result = fitting_resources(&fitting(ship_type_id, vec![]), &catalogue);
            assert_eq!(
                result,
                FittingResources::ShipNoOutput,
                "ship {ship_type_id}"
            );
        }
    }

    // Fixture catalogue for the Zephyr/Echelon shape: a category-6
    // row with outputs present as Some(0.0).
    fn zero_output_catalogue() -> FittingTypes {
        FittingTypes::from_json(
            r#"{"types":[
                {"typeId":2078,"typeName":"Zephyr","categoryId":6,"slotEffects":[],"cpuOutput":0.0,"powerOutput":0.0},
                {"typeId":2048,"typeName":"Damage Control II","categoryId":7,"slotEffects":[11],"cpu":30.0,"power":1.0}]}"#,
        )
        .expect("fixture catalogue parses")
    }

    #[test]
    fn zero_output_ship_is_not_over_hull_only_and_is_over_with_a_module() {
        let catalogue = zero_output_catalogue();
        let (cpu, power) = budgets(fitting_resources(&fitting(2078, vec![]), &catalogue));
        assert_close(cpu.remaining(), 0.0);
        assert_close(power.remaining(), 0.0);
        assert!(!cpu.is_over());
        assert!(!power.is_over());

        let fit = fitting(2078, vec![item("LoSlot0", 1, 2048)]);
        let (cpu, power) = budgets(fitting_resources(&fit, &catalogue));
        assert_close(cpu.remaining(), -30.0);
        assert_close(power.remaining(), -1.0);
        assert!(cpu.is_over());
        assert!(power.is_over());
    }

    // 5 x Damage Control II = 150.0 CPU > 130.0, 5.0 power <= 41.0.
    #[test]
    fn over_budget_cpu_only_keeps_exact_numbers() {
        let catalogue = bundled();
        let items: Vec<FittingItem> = (0..5)
            .map(|n| item(&format!("LoSlot{n}"), 1, 2048))
            .collect();
        let (cpu, power) = budgets(fitting_resources(&fitting(587, items), &catalogue));
        assert_close(cpu.used, 150.0);
        assert_close(power.used, 5.0);
        assert!(cpu.is_over());
        assert!(!power.is_over());
        assert_close(cpu.remaining(), -20.0);
        assert_close(power.remaining(), 36.0);
    }

    // Fixture guards: an absent key loads as None; a negative value
    // is treated as excluded, never summed.
    #[test]
    fn fixture_guards_exclude_negative_and_absent_values() {
        let catalogue = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":587,"typeName":"Rifter","categoryId":6,"slotEffects":[],"cpuOutput":130.0,"powerOutput":41.0},
                {"typeId":1001,"typeName":"Negative Cpu","categoryId":7,"slotEffects":[11],"cpu":-5.0,"power":2.0},
                {"typeId":1003,"typeName":"Absent Cpu","categoryId":7,"slotEffects":[11],"power":1.0}]}"#,
        )
        .expect("fixture catalogue parses");
        let fit = fitting(
            587,
            vec![item("LoSlot0", 1, 1001), item("LoSlot1", 1, 1003)],
        );
        let (cpu, power) = budgets(fitting_resources(&fit, &catalogue));
        assert_close(cpu.used, 0.0);
        assert_close(power.used, 3.0);
        assert_eq!(cpu.excluded_modules, 2);
        assert_eq!(power.excluded_modules, 0);

        // A negative ship output yields no numbers at all.
        let bad_ship = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":587,"typeName":"Rifter","categoryId":6,"slotEffects":[],"cpuOutput":-1.0,"powerOutput":41.0}]}"#,
        )
        .expect("fixture catalogue parses");
        let result = fitting_resources(&fitting(587, vec![]), &bad_ship);
        assert_eq!(result, FittingResources::ShipNoOutput);
    }

    // serde_json rejects 1e999 as "number out of range", so no JSON
    // fixture can carry a non-finite value into the catalogue. The
    // shared usable predicate — the single branch both the ship
    // outputs and the module needs flow through — is pinned here
    // instead.
    #[test]
    fn usable_guard_rejects_non_finite_and_negative() {
        assert_eq!(usable(Some(2.5)), Some(2.5));
        assert_eq!(usable(Some(0.0)), Some(0.0));
        assert_eq!(usable(None), None);
        assert_eq!(usable(Some(-1.0)), None);
        assert_eq!(usable(Some(f64::INFINITY)), None);
        assert_eq!(usable(Some(f64::NEG_INFINITY)), None);
        assert_eq!(usable(Some(f64::NAN)), None);
    }

    fn skill(skill_id: i64, active: i32, trained: i32) -> crate::esi::models::Skill {
        crate::esi::models::Skill {
            skill_id,
            active_skill_level: active,
            trained_skill_level: trained,
            skillpoints_in_skill: 0,
        }
    }

    fn skills(rows: Vec<crate::esi::models::Skill>) -> CharacterSkills {
        CharacterSkills {
            skills: rows,
            total_sp: 0,
            unallocated_sp: None,
        }
    }

    fn levels(cpu: i32, pg: i32) -> ResourceSkillLevels {
        ResourceSkillLevels {
            cpu_management: cpu,
            power_grid_management: pg,
            weapon_upgrades: 0,
            advanced_weapon_upgrades: 0,
            energy_grid_upgrades: 0,
            electronics_upgrades: 0,
            shield_upgrades: 0,
        }
    }

    fn need_levels(
        weapon: i32,
        advanced: i32,
        grid: i32,
        electronics: i32,
        shield: i32,
    ) -> ResourceSkillLevels {
        ResourceSkillLevels {
            cpu_management: 0,
            power_grid_management: 0,
            weapon_upgrades: weapon,
            advanced_weapon_upgrades: advanced,
            energy_grid_upgrades: grid,
            electronics_upgrades: electronics,
            shield_upgrades: shield,
        }
    }

    // Real Rifter table (×(1 + 0.05·level) on base 130.0/41.0).
    // Level 2 (143.0, not 143.325) and level 5 (162.5, not
    // 130 × 1.05⁵ = 165.916…) kill the per-level compounding mutant.
    #[test]
    fn skill_outputs_follow_real_rifter_table_and_stay_independent() {
        let catalogue = bundled();
        let hull = fitting(587, vec![]);
        let table: [(i32, f64, f64); 6] = [
            (0, 130.0, 41.0),
            (1, 136.5, 43.05),
            (2, 143.0, 45.1),
            (3, 149.5, 47.15),
            (4, 156.0, 49.2),
            (5, 162.5, 51.25),
        ];
        for (level, cpu_expected, pg_expected) in table {
            let (cpu, power) = budgets(fitting_resources_with_skills(
                &hull,
                &catalogue,
                Some(levels(level, level)),
            ));
            assert_close(cpu.output, cpu_expected);
            assert_close(power.output, pg_expected);
        }
        // Independence: CPU L5 + PG L0 scales CPU only, and vice versa.
        let (cpu, power) = budgets(fitting_resources_with_skills(
            &hull,
            &catalogue,
            Some(levels(5, 0)),
        ));
        assert_close(cpu.output, 162.5);
        assert_close(power.output, 41.0);
        let (cpu, power) = budgets(fitting_resources_with_skills(
            &hull,
            &catalogue,
            Some(levels(0, 5)),
        ));
        assert_close(cpu.output, 130.0);
        assert_close(power.output, 51.25);
    }

    // Synthetic Flutter oracle (labelled synthetic): Flutter's
    // synthetic Rifter carries 125.0/37.0; 3426 L5 → 125 × 1.25 =
    // 156.25. Reproducing Flutter's synthetic numbers verbatim.
    #[test]
    fn synthetic_flutter_oracle_cpu_management_l5() {
        let catalogue = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":587,"typeName":"Rifter","categoryId":6,"slotEffects":[],"cpuOutput":125.0,"powerOutput":37.0}]}"#,
        )
        .expect("fixture catalogue parses");
        let hull = fitting(587, vec![]);
        let (cpu, power) = budgets(fitting_resources_with_skills(
            &hull,
            &catalogue,
            Some(levels(5, 0)),
        ));
        assert_close(cpu.output, 156.25);
        assert_close(power.output, 37.0);
        // Power grid side of the same synthetic row: 37 × 1.25 = 46.25.
        let (_, power) = budgets(fitting_resources_with_skills(
            &hull,
            &catalogue,
            Some(levels(0, 5)),
        ));
        assert_close(power.output, 46.25);
    }

    #[test]
    fn none_equals_base_on_real_and_no_output_fits() {
        let catalogue = bundled();
        let fit = fitting(587, vec![item("LoSlot0", 1, 2048)]);
        assert_eq!(
            fitting_resources(&fit, &catalogue),
            fitting_resources_with_skills(&fit, &catalogue, None)
        );
        // Design section 9 identity pin: on the None path
        // base_used equals used and nothing is unreduced.
        let (cpu, power) = budgets(fitting_resources(&fit, &catalogue));
        assert_close(cpu.base_used, cpu.used);
        assert_close(power.base_used, power.used);
        assert_eq!(cpu.unreduced_modules, 0);
        assert_eq!(power.unreduced_modules, 0);
        let no_output = fitting(999999, vec![]);
        assert_eq!(
            fitting_resources(&no_output, &catalogue),
            fitting_resources_with_skills(&no_output, &catalogue, None)
        );
        assert_eq!(
            fitting_resources(&no_output, &catalogue),
            FittingResources::ShipNoOutput
        );
    }

    #[test]
    fn lookup_absent_rows_yield_zero_zero() {
        // Mechanical literal extension for the five
        // need-reduction fields (design section 6): every
        // existing assertion is unchanged and must pass with
        // the same numbers — the level-0-identity gate.
        let levels = resource_skill_levels(&skills(vec![]));
        assert_eq!(
            levels,
            ResourceSkillLevels {
                cpu_management: 0,
                power_grid_management: 0,
                weapon_upgrades: 0,
                advanced_weapon_upgrades: 0,
                energy_grid_upgrades: 0,
                electronics_upgrades: 0,
                shield_upgrades: 0
            }
        );
        // Unrelated rows do not fill the two slots.
        let levels = resource_skill_levels(&skills(vec![skill(3300, 5, 5)]));
        assert_eq!(
            levels,
            ResourceSkillLevels {
                cpu_management: 0,
                power_grid_management: 0,
                weapon_upgrades: 0,
                advanced_weapon_upgrades: 0,
                energy_grid_upgrades: 0,
                electronics_upgrades: 0,
                shield_upgrades: 0
            }
        );
    }

    #[test]
    fn skill_id_constants_are_the_grounded_ids() {
        // Literal rows in the lookup tests below pin behavior to
        // these exact ids; the constants are pinned here too so a
        // swap fails at the unit boundary, not only via demo pins.
        assert_eq!(CPU_MANAGEMENT_SKILL_ID, 3426);
        assert_eq!(POWER_GRID_MANAGEMENT_SKILL_ID, 3413);
        // Design section 6 lookup pins: the five
        // need-reduction source skills, pinned exactly as the
        // output pair above.
        assert_eq!(WEAPON_UPGRADES_SKILL_ID, 3318);
        assert_eq!(ADVANCED_WEAPON_UPGRADES_SKILL_ID, 11207);
        assert_eq!(ENERGY_GRID_UPGRADES_SKILL_ID, 3424);
        assert_eq!(ELECTRONICS_UPGRADES_SKILL_ID, 3432);
        assert_eq!(SHIELD_UPGRADES_SKILL_ID, 3425);
    }

    #[test]
    fn lookup_reads_trained_not_active() {
        let levels = resource_skill_levels(&skills(vec![skill(3426, 5, 2), skill(3413, 1, 4)]));
        assert_eq!(
            levels,
            ResourceSkillLevels {
                cpu_management: 2,
                power_grid_management: 4,
                weapon_upgrades: 0,
                advanced_weapon_upgrades: 0,
                energy_grid_upgrades: 0,
                electronics_upgrades: 0,
                shield_upgrades: 0
            }
        );
        let present_zero =
            resource_skill_levels(&skills(vec![skill(3426, 5, 0), skill(3413, 5, 0)]));
        assert_eq!(
            present_zero,
            ResourceSkillLevels {
                cpu_management: 0,
                power_grid_management: 0,
                weapon_upgrades: 0,
                advanced_weapon_upgrades: 0,
                energy_grid_upgrades: 0,
                electronics_upgrades: 0,
                shield_upgrades: 0
            }
        );
    }

    #[test]
    fn lookup_wrong_id_3418_is_noop_and_output_equals_base() {
        // E0c.2 trap: 3418 is Capacitor Management, not a resource
        // skill. It must yield 0/0 and leave outputs at base.
        let levels = resource_skill_levels(&skills(vec![skill(3418, 5, 5)]));
        assert_eq!(
            levels,
            ResourceSkillLevels {
                cpu_management: 0,
                power_grid_management: 0,
                weapon_upgrades: 0,
                advanced_weapon_upgrades: 0,
                energy_grid_upgrades: 0,
                electronics_upgrades: 0,
                shield_upgrades: 0
            }
        );
        let catalogue = bundled();
        let hull = fitting(587, vec![]);
        let (cpu, power) = budgets(fitting_resources_with_skills(
            &hull,
            &catalogue,
            Some(levels),
        ));
        assert_close(cpu.output, 130.0);
        assert_close(power.output, 41.0);
    }

    #[test]
    fn lookup_duplicate_rows_last_wins() {
        let levels = resource_skill_levels(&skills(vec![
            skill(3426, 5, 1),
            skill(3426, 5, 4),
            skill(3413, 5, 2),
            skill(3413, 5, 3),
        ]));
        assert_eq!(
            levels,
            ResourceSkillLevels {
                cpu_management: 4,
                power_grid_management: 3,
                weapon_upgrades: 0,
                advanced_weapon_upgrades: 0,
                energy_grid_upgrades: 0,
                electronics_upgrades: 0,
                shield_upgrades: 0
            }
        );
    }

    #[test]
    fn lookup_clamps_negative_seven_and_i32_extremes_without_panic() {
        let levels = resource_skill_levels(&skills(vec![skill(3426, -3, -3), skill(3413, 7, 7)]));
        assert_eq!(
            levels,
            ResourceSkillLevels {
                cpu_management: 0,
                power_grid_management: 5,
                weapon_upgrades: 0,
                advanced_weapon_upgrades: 0,
                energy_grid_upgrades: 0,
                electronics_upgrades: 0,
                shield_upgrades: 0
            }
        );
        let extremes = resource_skill_levels(&skills(vec![
            skill(3426, i32::MIN, i32::MIN),
            skill(3413, i32::MAX, i32::MAX),
        ]));
        assert_eq!(
            extremes,
            ResourceSkillLevels {
                cpu_management: 0,
                power_grid_management: 5,
                weapon_upgrades: 0,
                advanced_weapon_upgrades: 0,
                energy_grid_upgrades: 0,
                electronics_upgrades: 0,
                shield_upgrades: 0
            }
        );
    }

    #[test]
    fn hand_built_levels_above_five_are_reclamped_inside() {
        let catalogue = bundled();
        let hull = fitting(587, vec![]);
        let (cpu, power) = budgets(fitting_resources_with_skills(
            &hull,
            &catalogue,
            Some(levels(99, 99)),
        ));
        assert_close(cpu.output, 162.5);
        assert_close(power.output, 51.25);
        let (cpu, power) = budgets(fitting_resources_with_skills(
            &hull,
            &catalogue,
            Some(levels(-99, -99)),
        ));
        assert_close(cpu.output, 130.0);
        assert_close(power.output, 41.0);
    }

    #[test]
    fn only_output_scales_used_and_excluded_stay_equal() {
        let catalogue = bundled();
        let fit = fitting(
            587,
            vec![
                item("LoSlot0", 1, 2048),
                item("LoSlot1", 1, 999999),
                item("LoSlot2", 1, 1236),
            ],
        );
        let base = fitting_resources(&fit, &catalogue);
        let applied = fitting_resources_with_skills(&fit, &catalogue, Some(levels(5, 5)));
        let (base_cpu, base_power) = budgets(base);
        let (applied_cpu, applied_power) = budgets(applied);
        assert_close(applied_cpu.used, base_cpu.used);
        assert_close(applied_power.used, base_power.used);
        assert_eq!(applied_cpu.excluded_modules, base_cpu.excluded_modules);
        assert_eq!(applied_power.excluded_modules, base_power.excluded_modules);
        assert_close(applied_cpu.output, 162.5);
        assert_close(applied_power.output, 51.25);
    }

    #[test]
    fn ship_no_output_and_zero_output_guards_hold_at_l5() {
        let catalogue = bundled();
        assert_eq!(
            fitting_resources_with_skills(&fitting(999999, vec![]), &catalogue, Some(levels(5, 5))),
            FittingResources::ShipNoOutput
        );
        let zero = zero_output_catalogue();
        let fit = fitting(2078, vec![item("LoSlot0", 1, 2048)]);
        let (cpu, power) = budgets(fitting_resources_with_skills(
            &fit,
            &zero,
            Some(levels(5, 5)),
        ));
        assert_close(cpu.output, 0.0);
        assert_close(power.output, 0.0);
        assert_close(cpu.remaining(), -30.0);
        assert_close(power.remaining(), -1.0);
        assert!(cpu.is_over());
        assert!(power.is_over());
        let hull = fitting(2078, vec![]);
        let (cpu, power) = budgets(fitting_resources_with_skills(
            &hull,
            &zero,
            Some(levels(5, 5)),
        ));
        assert_close(cpu.output, 0.0);
        assert_close(power.output, 0.0);
        assert!(!cpu.is_over());
        assert!(!power.is_over());
    }

    #[test]
    fn over_budget_flips_and_stays_over_against_applied_output() {
        let catalogue = bundled();
        let items5: Vec<FittingItem> = (0..5)
            .map(|n| item(&format!("LoSlot{n}"), 1, 2048))
            .collect();
        let fit5 = fitting(587, items5);
        // 150.0 used is over base 130.0 and under applied 162.5.
        let base = fitting_resources(&fit5, &catalogue);
        let (base_cpu, _) = budgets(base);
        assert!(base_cpu.is_over());
        assert_close(base_cpu.remaining(), -20.0);
        let applied = fitting_resources_with_skills(&fit5, &catalogue, Some(levels(5, 0)));
        let (applied_cpu, _) = budgets(applied);
        assert!(!applied_cpu.is_over());
        assert_close(applied_cpu.output, 162.5);
        assert_close(applied_cpu.used, 150.0);
        assert_close(applied_cpu.remaining(), 12.5);

        let items6: Vec<FittingItem> = (0..6)
            .map(|n| item(&format!("LoSlot{n}"), 1, 2048))
            .collect();
        let fit6 = fitting(587, items6);
        let applied6 = fitting_resources_with_skills(&fit6, &catalogue, Some(levels(5, 0)));
        let (applied6_cpu, _) = budgets(applied6);
        assert!(applied6_cpu.is_over());
        assert_close(applied6_cpu.output, 162.5);
        assert_close(applied6_cpu.used, 180.0);
        assert_close(applied6_cpu.remaining(), -17.5);
    }

    // Design section 9 level table on one matched module: 2889
    // (base 9.0 CPU / 4.0 power, requires Gunnery 3300) at
    // Weapon Upgrades levels 0/1/2/5 and Advanced Weapon
    // Upgrades levels 1/2/5. Percent is per-level post-percent
    // (×0.95/×0.90/×0.75), never per-level compounding:
    // 9 × 0.95⁵ = 6.964… and 4 × 0.98⁵ = 3.615… must both
    // fail the level-5 pins below.
    #[test]
    fn need_reduction_levels_on_2889_follow_linear_table() {
        let catalogue = bundled();
        let fit = fitting(587, vec![item("HiSlot0", 1, 2889)]);
        let table: [(i32, f64); 4] = [(0, 9.0), (1, 8.55), (2, 8.1), (5, 6.75)];
        for (level, cpu_expected) in table {
            let (cpu, power) = budgets(fitting_resources_with_skills(
                &fit,
                &catalogue,
                Some(need_levels(level, 0, 0, 0, 0)),
            ));
            assert_close(cpu.used, cpu_expected);
            assert_close(cpu.base_used, 9.0);
            assert_eq!(cpu.unreduced_modules, 0);
            assert_close(power.used, 4.0);
            assert_close(power.base_used, 4.0);
        }
        let power_table: [(i32, f64); 3] = [(1, 3.92), (2, 3.84), (5, 3.6)];
        for (level, power_expected) in power_table {
            let (cpu, power) = budgets(fitting_resources_with_skills(
                &fit,
                &catalogue,
                Some(need_levels(0, level, 0, 0, 0)),
            ));
            assert_close(power.used, power_expected);
            assert_close(power.base_used, 4.0);
            assert_eq!(power.unreduced_modules, 0);
            assert_close(cpu.used, 9.0);
            assert_close(cpu.base_used, 9.0);
        }
        // Dimension independence: CPU skill at 5 with power
        // skills at 0 scales CPU only, and vice versa.
        let (cpu, power) = budgets(fitting_resources_with_skills(
            &fit,
            &catalogue,
            Some(need_levels(5, 0, 0, 0, 0)),
        ));
        assert_close(cpu.used, 6.75);
        assert_close(power.used, 4.0);
        let (cpu, power) = budgets(fitting_resources_with_skills(
            &fit,
            &catalogue,
            Some(need_levels(0, 5, 0, 0, 0)),
        ));
        assert_close(cpu.used, 9.0);
        assert_close(power.used, 3.6);
        // Trained-not-active for a reduction skill (design
        // section 7): active 5, trained 2 yields the
        // level-2 factor (8.1), not the level-5 factor.
        let trained = resource_skill_levels(&skills(vec![skill(3318, 5, 2)]));
        let (cpu, _) = budgets(fitting_resources_with_skills(
            &fit,
            &catalogue,
            Some(trained),
        ));
        assert_close(cpu.used, 8.1);
    }

    // Design section 9: one real-row pin per shipped filter
    // entry, source skill at level 5. Literals read from the
    // shipped catalogue joined to the committed caches (the
    // section 2 join); the factor shape's only Flutter
    // citation is the Repair Systems E2.7 chain (design
    // section 2.2).
    #[test]
    fn one_real_row_per_shipped_filter_entry() {
        let catalogue = bundled();
        // Missile Launcher Operation (499, requires 3319):
        // both weapon skills match.
        let fit = fitting(587, vec![item("HiSlot0", 1, 499)]);
        let (cpu, power) = budgets(fitting_resources_with_skills(
            &fit,
            &catalogue,
            Some(need_levels(5, 5, 0, 0, 0)),
        ));
        assert_close(cpu.used, 15.75);
        assert_close(cpu.base_used, 21.0);
        assert_close(power.used, 5.4);
        assert_close(power.base_used, 6.0);
        assert_eq!(cpu.unreduced_modules, 0);
        assert_eq!(power.unreduced_modules, 0);
        // Energy Pulse Weapons (1547, requires 3421): CPU
        // only; power (8.0) untouched by the CPU skill.
        let fit = fitting(587, vec![item("HiSlot0", 1, 1547)]);
        let (cpu, power) = budgets(fitting_resources_with_skills(
            &fit,
            &catalogue,
            Some(need_levels(5, 0, 0, 0, 0)),
        ));
        assert_close(cpu.used, 22.5);
        assert_close(cpu.base_used, 30.0);
        assert_close(power.used, 8.0);
        assert_close(power.base_used, 8.0);
        // Vorton Projector Operation (54739, requires 55033):
        // both weapon skills match.
        let fit = fitting(587, vec![item("HiSlot0", 1, 54739)]);
        let (cpu, power) = budgets(fitting_resources_with_skills(
            &fit,
            &catalogue,
            Some(need_levels(5, 5, 0, 0, 0)),
        ));
        assert_close(cpu.used, 72.75);
        assert_close(cpu.base_used, 97.0);
        assert_close(power.used, 23.4);
        assert_close(power.base_used, 26.0);
        // Bomb group 862 plus Bomb Deployment (4256): CPU via
        // the group entry (28073 matches no CPU filter), power
        // via the skill entry.
        let fit = fitting(587, vec![item("HiSlot0", 1, 4256)]);
        let (cpu, power) = budgets(fitting_resources_with_skills(
            &fit,
            &catalogue,
            Some(need_levels(5, 5, 0, 0, 0)),
        ));
        assert_close(cpu.used, 41.25);
        assert_close(cpu.base_used, 55.0);
        assert_close(power.used, 9.0);
        assert_close(power.base_used, 10.0);
        // Energy Grid Upgrades (1355 RCU II, requires 3424):
        // CPU reduced; present-0.0 power stays a real 0.0 and
        // unexcluded under any factor.
        let fit = fitting(587, vec![item("LoSlot0", 1, 1355)]);
        let (cpu, power) = budgets(fitting_resources_with_skills(
            &fit,
            &catalogue,
            Some(need_levels(0, 0, 5, 0, 0)),
        ));
        assert_close(cpu.used, 16.5);
        assert_close(cpu.base_used, 22.0);
        assert_close(power.used, 0.0);
        assert_close(power.base_used, 0.0);
        assert_eq!(power.excluded_modules, 0);
        assert_eq!(power.unreduced_modules, 0);
        // Electronics Upgrades (1986 Signal Amplifier I,
        // requires 3432): CPU only; power (1.0) untouched.
        let fit = fitting(587, vec![item("MedSlot0", 1, 1986)]);
        let (cpu, power) = budgets(fitting_resources_with_skills(
            &fit,
            &catalogue,
            Some(need_levels(0, 0, 0, 5, 0)),
        ));
        assert_close(cpu.used, 15.0);
        assert_close(cpu.base_used, 20.0);
        assert_close(power.used, 1.0);
        assert_close(power.base_used, 1.0);
        // Shield Upgrades (377 Small Shield Extender I,
        // requires 3425): power only; CPU (20.0) untouched.
        let fit = fitting(587, vec![item("MedSlot0", 1, 377)]);
        let (cpu, power) = budgets(fitting_resources_with_skills(
            &fit,
            &catalogue,
            Some(need_levels(0, 0, 0, 0, 5)),
        ));
        assert_close(cpu.used, 20.0);
        assert_close(cpu.base_used, 20.0);
        assert_close(power.used, 1.5);
        assert_close(power.base_used, 2.0);
        // Fractional base: 37303 Dual 1000mm Railgun II,
        // CPU 126.5 requires Gunnery → 94.875 at level 5.
        let fit = fitting(587, vec![item("HiSlot0", 1, 37303)]);
        let (cpu, _) = budgets(fitting_resources_with_skills(
            &fit,
            &catalogue,
            Some(need_levels(5, 0, 0, 0, 0)),
        ));
        assert_close(cpu.used, 94.875);
        assert_close(cpu.base_used, 126.5);
    }

    // Design section 9 wrong-ID traps: skill-level lookup is
    // by source skill, never by filter skill. A payload with
    // only filter skills (Gunnery 3300, Missile Launcher
    // Operation 3319, Energy Pulse Weapons 3421, Bomb
    // Deployment 28073) or Capacitor Management (3418, the
    // existing trap), each at level 5 with no source skill,
    // changes no need. The other dimension's source skill
    // changes nothing in this dimension. A non-matching
    // module at all skills level 5 stays at full need with
    // base equal and both counts 0.
    #[test]
    fn filter_skill_levels_change_no_need() {
        let catalogue = bundled();
        let fit = fitting(587, vec![item("HiSlot0", 1, 2889)]);
        for filter_skill in [3300, 3319, 3421, 28073, 3418] {
            let levels = resource_skill_levels(&skills(vec![skill(filter_skill, 5, 5)]));
            let (cpu, power) = budgets(fitting_resources_with_skills(
                &fit,
                &catalogue,
                Some(levels),
            ));
            assert_close(cpu.used, 9.0);
            assert_close(power.used, 4.0);
            assert_close(cpu.base_used, 9.0);
            assert_close(power.base_used, 4.0);
        }
        // Only the other dimension's source skill: Shield 5
        // does not touch CPU; Weapon 5 does not touch power.
        let (cpu, _) = budgets(fitting_resources_with_skills(
            &fit,
            &catalogue,
            Some(need_levels(0, 0, 0, 0, 5)),
        ));
        assert_close(cpu.used, 9.0);
        let (_, power) = budgets(fitting_resources_with_skills(
            &fit,
            &catalogue,
            Some(need_levels(5, 0, 0, 0, 0)),
        ));
        assert_close(power.used, 4.0);
        // Non-matching module: 2048 Damage Control II
        // (requires 3394, group 60) at all skills level 5.
        let fit = fitting(587, vec![item("LoSlot0", 1, 2048)]);
        let (cpu, power) = budgets(fitting_resources_with_skills(
            &fit,
            &catalogue,
            Some(need_levels(5, 5, 5, 5, 5)),
        ));
        assert_close(cpu.used, 30.0);
        assert_close(cpu.base_used, 30.0);
        assert_close(power.used, 1.0);
        assert_close(power.base_used, 1.0);
        assert_eq!(cpu.unreduced_modules, 0);
        assert_eq!(power.unreduced_modules, 0);
        assert_eq!(cpu.excluded_modules, 0);
        assert_eq!(power.excluded_modules, 0);
    }

    // Design section 9: the shared EFT sample fit (the
    // existing 114.0/31.0 oracle: three 2889s are its only
    // matched modules) at Weapon Upgrades 5 + Advanced
    // Weapon Upgrades 5.
    #[test]
    fn sample_fit_at_both_weapon_skills_five() {
        let sample = concat!(
            "[Rifter, Sample Brawler]\n",
            "Damage Control II\n",
            "Small Armor Repairer II\n",
            "\n",
            "1MN Afterburner II\n",
            "Warp Scrambler II\n",
            "\n",
            "200mm AutoCannon II, Republic Fleet EMP S\n",
            "200mm AutoCannon II\n",
            "200mm AutoCannon II\n",
            "\n",
            "Small Projectile Burst Aerator I\n",
            "[Empty Rig slot]\n",
            "\n",
            "Hobgoblin II x2\n",
            "\n",
            "EMP S x200\n",
            "Nanite Repair Paste x8"
        );
        let catalogue = bundled();
        let synth = match parse_eft(sample, &catalogue) {
            EftImportOutcome::Imported(fitting) => fitting.to_character_fitting(),
            EftImportOutcome::Failed(fatal) => panic!("sample EFT must import: {fatal:?}"),
        };
        let (cpu, power) = budgets(fitting_resources_with_skills(
            &synth,
            &catalogue,
            Some(need_levels(5, 5, 0, 0, 0)),
        ));
        assert_close(cpu.used, 107.25);
        assert_close(cpu.base_used, 114.0);
        assert_close(power.used, 29.8);
        assert_close(power.base_used, 31.0);
        assert_eq!(cpu.unreduced_modules, 0);
        assert_eq!(power.unreduced_modules, 0);
        assert_eq!(cpu.excluded_modules, 0);
        assert_eq!(power.excluded_modules, 0);
        // Outputs stay at base (CPU/PG Management at 0).
        assert_close(cpu.output, 130.0);
        assert_close(power.output, 41.0);
    }

    // Design section 9: quantity multiplies the reduced
    // per-unit need (3 × 2889 → 20.25 CPU at Weapon 5), and
    // over-budget is judged on the reduced used of 16 ×
    // 2889 (base 144.0 over Rifter 130.0 becomes 108.0 under
    // it at Weapon 5 with CPU Management 0) while 20 ×
    // 2889 (135.0 reduced) stays over with remaining -5.0.
    #[test]
    fn quantity_multiplies_reduced_need_and_over_budget_judges_reduced() {
        let catalogue = bundled();
        let fit = fitting(587, vec![item("HiSlot0", 3, 2889)]);
        let (cpu, _) = budgets(fitting_resources_with_skills(
            &fit,
            &catalogue,
            Some(need_levels(5, 0, 0, 0, 0)),
        ));
        assert_close(cpu.used, 20.25);
        assert_close(cpu.base_used, 27.0);
        assert!(!cpu.is_over());
        let items16: Vec<FittingItem> = (0..16)
            .map(|n| item(&format!("HiSlot{n}"), 1, 2889))
            .collect();
        let fit16 = fitting(587, items16);
        let base = fitting_resources(&fit16, &catalogue);
        let (base_cpu, _) = budgets(base);
        assert_close(base_cpu.used, 144.0);
        assert!(base_cpu.is_over());
        let (applied_cpu, _) = budgets(fitting_resources_with_skills(
            &fit16,
            &catalogue,
            Some(need_levels(5, 0, 0, 0, 0)),
        ));
        assert_close(applied_cpu.used, 108.0);
        assert_close(applied_cpu.base_used, 144.0);
        assert!(!applied_cpu.is_over());
        let items20: Vec<FittingItem> = (0..20)
            .map(|n| item(&format!("HiSlot{n}"), 1, 2889))
            .collect();
        let fit20 = fitting(587, items20);
        let (applied20_cpu, _) = budgets(fitting_resources_with_skills(
            &fit20,
            &catalogue,
            Some(need_levels(5, 0, 0, 0, 0)),
        ));
        assert_close(applied20_cpu.used, 135.0);
        assert!(applied20_cpu.is_over());
        assert_close(applied20_cpu.remaining(), -5.0);
    }

    // Design section 9: excluded-before-reduction. 1236
    // (no needs) is excluded in both dimensions and never
    // unreduced at any levels; 33981 (power-only, requires
    // 3455 which matches nothing) counts power at base and
    // excludes CPU.
    #[test]
    fn excluded_needs_are_never_unreduced_at_levels() {
        let catalogue = bundled();
        let fit = fitting(587, vec![item("LoSlot0", 1, 1236)]);
        let (cpu, power) = budgets(fitting_resources_with_skills(
            &fit,
            &catalogue,
            Some(need_levels(5, 5, 5, 5, 5)),
        ));
        assert_eq!(cpu.excluded_modules, 1);
        assert_eq!(power.excluded_modules, 1);
        assert_eq!(cpu.unreduced_modules, 0);
        assert_eq!(power.unreduced_modules, 0);
        assert_close(cpu.used, 0.0);
        assert_close(power.used, 0.0);
        let fit = fitting(587, vec![item("LoSlot0", 1, 33981)]);
        let (cpu, power) = budgets(fitting_resources_with_skills(
            &fit,
            &catalogue,
            Some(need_levels(5, 5, 5, 5, 5)),
        ));
        assert_close(power.used, 1.0);
        assert_close(power.base_used, 1.0);
        assert_eq!(power.excluded_modules, 0);
        assert_eq!(power.unreduced_modules, 0);
        assert_eq!(cpu.excluded_modules, 1);
        assert_eq!(cpu.unreduced_modules, 0);
    }

    // Design section 9 guards: ShipNoOutput at all-5 levels,
    // and a hand-built levels struct with levels above 5 is
    // re-clamped on the need side (never exceeds ×0.75 /
    // ×0.90 per entry).
    #[test]
    fn ship_no_output_and_need_reclamp_at_all_five() {
        let catalogue = bundled();
        assert_eq!(
            fitting_resources_with_skills(
                &fitting(999999, vec![item("HiSlot0", 1, 2889)]),
                &catalogue,
                Some(need_levels(5, 5, 5, 5, 5)),
            ),
            FittingResources::ShipNoOutput
        );
        let fit = fitting(587, vec![item("HiSlot0", 1, 2889)]);
        let (cpu, power) = budgets(fitting_resources_with_skills(
            &fit,
            &catalogue,
            Some(ResourceSkillLevels {
                cpu_management: 0,
                power_grid_management: 0,
                weapon_upgrades: 99,
                advanced_weapon_upgrades: -99,
                energy_grid_upgrades: 99,
                electronics_upgrades: -1,
                shield_upgrades: i32::MAX,
            }),
        ));
        assert_close(cpu.used, 6.75);
        assert_close(power.used, 4.0);
        let (cpu, _) = budgets(fitting_resources_with_skills(
            &fit,
            &catalogue,
            Some(need_levels(0, 0, 5, 0, 0)),
        ));
        assert_close(cpu.used, 9.0);
    }

    // Design section 9 lookup pins extended to all seven
    // ids: absent ≡ 0, trained-not-active, duplicate
    // last-wins, −3/7/i32::MIN/i32::MAX clamping — the
    // existing two-skill contract, verbatim for the five new
    // skills.
    #[test]
    fn lookup_covers_all_seven_resource_skills() {
        let levels = resource_skill_levels(&skills(vec![
            skill(3318, 5, 2),
            skill(11207, 1, 4),
            skill(3424, 5, 5),
            skill(3432, 5, 0),
            skill(3425, 5, 3),
        ]));
        assert_eq!(
            levels,
            ResourceSkillLevels {
                cpu_management: 0,
                power_grid_management: 0,
                weapon_upgrades: 2,
                advanced_weapon_upgrades: 4,
                energy_grid_upgrades: 5,
                electronics_upgrades: 0,
                shield_upgrades: 3
            }
        );
        // Duplicate rows last-wins.
        let levels = resource_skill_levels(&skills(vec![
            skill(3318, 5, 1),
            skill(3318, 5, 4),
            skill(11207, 5, 2),
            skill(11207, 5, 3),
        ]));
        assert_eq!(levels.weapon_upgrades, 4);
        assert_eq!(levels.advanced_weapon_upgrades, 3);
        // Clamping, including i32 extremes.
        let levels = resource_skill_levels(&skills(vec![
            skill(3318, -3, -3),
            skill(11207, 7, 7),
            skill(3424, i32::MIN, i32::MIN),
            skill(3432, i32::MAX, i32::MAX),
            skill(3425, -1, -1),
        ]));
        assert_eq!(levels.weapon_upgrades, 0);
        assert_eq!(levels.advanced_weapon_upgrades, 5);
        assert_eq!(levels.energy_grid_upgrades, 0);
        assert_eq!(levels.electronics_upgrades, 5);
        assert_eq!(levels.shield_upgrades, 0);
    }

    // Synthetic catalogue (labelled synthetic — hand-built
    // `from_json` fixtures per house convention): a Rifter
    // plus a 10.0 CPU / 5.0 power module whose filter keys
    // vary per sub-case. The shipped catalogue makes the
    // unreduced count unreachable (design section 5
    // invariant), so it is pinned here only.
    fn synthetic_need_catalogue(module_json: &str) -> FittingTypes {
        let json = format!(
            r#"{{"types":[
                {{"typeId":587,"typeName":"Rifter","categoryId":6,"slotEffects":[],"cpuOutput":130.0,"powerOutput":41.0}},
                {module_json}]}}"#
        );
        FittingTypes::from_json(&json).expect("fixture catalogue parses")
    }

    // Design section 9 unreduced rule (synthetic fixtures,
    // labelled synthetic): a module row without the new
    // keys at Weapon 5 counts at full need with
    // unreduced_modules = its quantity in CPU (at Advanced
    // 5 also power); with all relevant levels 0 it counts 0;
    // a row with requiredSkillIds present but groupId
    // absent is unreduced in CPU only; Some([]) is proven
    // (0 unreduced, full need); a stacked quantity-3
    // unreduced row counts 3.
    #[test]
    fn unreduced_rule_on_synthetic_rows_without_filter_data() {
        let no_keys = synthetic_need_catalogue(
            r#"{"typeId":5001,"typeName":"No Filter Module","categoryId":7,"slotEffects":[11],"cpu":10.0,"power":5.0}"#,
        );
        let fit = fitting(587, vec![item("LoSlot0", 1, 5001)]);
        let (cpu, power) = budgets(fitting_resources_with_skills(
            &fit,
            &no_keys,
            Some(need_levels(5, 0, 0, 0, 0)),
        ));
        assert_close(cpu.used, 10.0);
        assert_close(cpu.base_used, 10.0);
        assert_eq!(cpu.unreduced_modules, 1);
        assert_close(power.used, 5.0);
        assert_eq!(power.unreduced_modules, 0);
        // At Advanced 5 the power side is unproven too.
        let (cpu, power) = budgets(fitting_resources_with_skills(
            &fit,
            &no_keys,
            Some(need_levels(5, 5, 0, 0, 0)),
        ));
        assert_eq!(cpu.unreduced_modules, 1);
        assert_eq!(power.unreduced_modules, 1);
        // All relevant levels 0: the factor is provably 1,
        // so nothing is unproven.
        let (cpu, power) = budgets(fitting_resources_with_skills(
            &fit,
            &no_keys,
            Some(need_levels(0, 0, 0, 0, 0)),
        ));
        assert_eq!(cpu.unreduced_modules, 0);
        assert_eq!(power.unreduced_modules, 0);
        // Stacked quantity-3 unreduced row counts 3.
        let fit3 = fitting(587, vec![item("LoSlot0", 3, 5001)]);
        let (cpu, _) = budgets(fitting_resources_with_skills(
            &fit3,
            &no_keys,
            Some(need_levels(5, 0, 0, 0, 0)),
        ));
        assert_close(cpu.used, 30.0);
        assert_eq!(cpu.unreduced_modules, 3);
        // requiredSkillIds present but groupId absent:
        // unreduced in CPU only.
        let group_absent = synthetic_need_catalogue(
            r#"{"typeId":5002,"typeName":"No Group Module","categoryId":7,"slotEffects":[11],"cpu":10.0,"power":5.0,"requiredSkillIds":[9999]}"#,
        );
        let fit = fitting(587, vec![item("LoSlot0", 1, 5002)]);
        let (cpu, power) = budgets(fitting_resources_with_skills(
            &fit,
            &group_absent,
            Some(need_levels(5, 5, 0, 0, 0)),
        ));
        assert_close(cpu.used, 10.0);
        assert_eq!(cpu.unreduced_modules, 1);
        assert_close(power.used, 5.0);
        assert_eq!(power.unreduced_modules, 0);
        // Some([]) is proven: full need, no count.
        let proven_empty = synthetic_need_catalogue(
            r#"{"typeId":5003,"typeName":"Proven Empty Module","categoryId":7,"slotEffects":[11],"cpu":10.0,"power":5.0,"groupId":999,"requiredSkillIds":[]}"#,
        );
        let fit = fitting(587, vec![item("LoSlot0", 1, 5003)]);
        let (cpu, power) = budgets(fitting_resources_with_skills(
            &fit,
            &proven_empty,
            Some(need_levels(5, 5, 5, 5, 5)),
        ));
        assert_close(cpu.used, 10.0);
        assert_close(power.used, 5.0);
        assert_eq!(cpu.unreduced_modules, 0);
        assert_eq!(power.unreduced_modules, 0);
        // Mixed presence: requiredSkillIds matches Weapon
        // Upgrades (3300 gate) but groupId is absent, so the
        // group-filtered entry cannot be proven either way.
        // Counted unreduced means counted at FULL need: the
        // matched reduction must not also be applied.
        let mixed = synthetic_need_catalogue(
            r#"{"typeId":5004,"typeName":"Mixed Presence Module","categoryId":7,"slotEffects":[11],"cpu":10.0,"power":5.0,"requiredSkillIds":[3300]}"#,
        );
        let fit = fitting(587, vec![item("LoSlot0", 1, 5004)]);
        let (cpu, _) = budgets(fitting_resources_with_skills(
            &fit,
            &mixed,
            Some(need_levels(5, 0, 0, 0, 0)),
        ));
        assert_close(cpu.used, 10.0);
        assert_close(cpu.base_used, 10.0);
        assert_eq!(cpu.unreduced_modules, 1);
    }

    // Design section 9 product rule (synthetic, labelled;
    // zero shipped rows): one factor per matched modifier
    // entry — two entries of one skill, or two skills on
    // one dimension, multiply.
    #[test]
    fn product_rule_multiplies_matched_entries_on_synthetic_rows() {
        // Requires both 3300 and 3319: two Weapon Upgrades
        // entries match → ×0.75 twice at level 5.
        let both_weapon = synthetic_need_catalogue(
            r#"{"typeId":6001,"typeName":"Two Weapon Gates","categoryId":7,"slotEffects":[11],"cpu":100.0,"power":100.0,"groupId":999,"requiredSkillIds":[3300,3319]}"#,
        );
        let fit = fitting(587, vec![item("LoSlot0", 1, 6001)]);
        let (cpu, power) = budgets(fitting_resources_with_skills(
            &fit,
            &both_weapon,
            Some(need_levels(5, 0, 0, 0, 0)),
        ));
        assert_close(cpu.used, 56.25);
        assert_close(cpu.base_used, 100.0);
        assert_close(power.used, 100.0);
        // Requires both 3300 (Weapon) and 3424 (Grid):
        // 100.0 → 75.0 under either alone, 56.25 under
        // both at 5.
        let mixed = synthetic_need_catalogue(
            r#"{"typeId":6002,"typeName":"Mixed Gates","categoryId":7,"slotEffects":[11],"cpu":100.0,"power":50.0,"groupId":999,"requiredSkillIds":[3300,3424]}"#,
        );
        let fit = fitting(587, vec![item("LoSlot0", 1, 6002)]);
        let (cpu, _) = budgets(fitting_resources_with_skills(
            &fit,
            &mixed,
            Some(need_levels(5, 0, 0, 0, 0)),
        ));
        assert_close(cpu.used, 75.0);
        let (cpu, _) = budgets(fitting_resources_with_skills(
            &fit,
            &mixed,
            Some(need_levels(0, 0, 5, 0, 0)),
        ));
        assert_close(cpu.used, 75.0);
        let (cpu, power) = budgets(fitting_resources_with_skills(
            &fit,
            &mixed,
            Some(need_levels(5, 0, 5, 0, 0)),
        ));
        assert_close(cpu.used, 56.25);
        assert_close(power.used, 50.0);
    }

    // --- Fitted-module output bonus oracles
    // (docs/output-bonuses-design.md sections 4, 8). Base
    // inputs re-read from the cache at design time: Rifter
    // 130.0/41.0; needs 1355 22.0/0.0, 4254 18.0/0.0,
    // 3888 0.0/1.0, 1541 22.0/0.0, 1445 4.0/0.0. ---

    fn assert_budgets_counts(
        cpu: &ResourceBudget,
        power: &ResourceBudget,
        excluded: (usize, usize),
        unreduced: (usize, usize),
        unapplied: (usize, usize),
    ) {
        assert_eq!(cpu.excluded_modules, excluded.0, "cpu excluded");
        assert_eq!(power.excluded_modules, excluded.1, "power excluded");
        assert_eq!(cpu.unreduced_modules, unreduced.0, "cpu unreduced");
        assert_eq!(power.unreduced_modules, unreduced.1, "power unreduced");
        assert_eq!(
            cpu.output_unapplied_modules, unapplied.0,
            "cpu output-unapplied"
        );
        assert_eq!(
            power.output_unapplied_modules, unapplied.1,
            "power output-unapplied"
        );
    }

    #[test]
    fn output_oracle_rcu_multiplier() {
        let catalogue = bundled();
        let fit = fitting(587, vec![item("LoSlot0", 1, 1355)]);
        let (cpu, power) = budgets(fitting_resources(&fit, &catalogue));
        assert_close(cpu.used, 22.0);
        assert_close(power.used, 0.0);
        assert_close(cpu.output, 130.0);
        assert_eq!(cpu.output, cpu.base_output);
        assert_close(power.output, 47.15);
        assert_close(power.base_output, 41.0);
        assert_close(cpu.remaining(), 108.0);
        assert_close(power.remaining(), 47.15);
        assert_budgets_counts(&cpu, &power, (0, 0), (0, 0), (0, 0));
        // Two units multiply in full, both ways.
        let two_slots = fitting(
            587,
            vec![item("LoSlot0", 1, 1355), item("LoSlot1", 1, 1355)],
        );
        let (_, power) = budgets(fitting_resources(&two_slots, &catalogue));
        assert_close(power.output, 54.2225);
        let stacked = fitting(587, vec![item("LoSlot0", 2, 1355)]);
        let (_, power) = budgets(fitting_resources(&stacked, &catalogue));
        assert_close(power.output, 54.2225);
    }

    #[test]
    fn output_oracle_mapc_flat_add() {
        let catalogue = bundled();
        let fit = fitting(587, vec![item("LoSlot0", 1, 4254)]);
        let (cpu, power) = budgets(fitting_resources(&fit, &catalogue));
        assert_close(cpu.used, 18.0);
        assert_close(power.output, 53.0);
        assert_close(power.base_output, 41.0);
        assert_eq!(cpu.output, cpu.base_output);
        assert_budgets_counts(&cpu, &power, (0, 0), (0, 0), (0, 0));
        let fit = fitting(587, vec![item("LoSlot0", 2, 4254)]);
        let (_, power) = budgets(fitting_resources(&fit, &catalogue));
        assert_close(power.output, 65.0);
    }

    #[test]
    fn output_oracle_coprocessor_cpu_only() {
        let catalogue = bundled();
        let fit = fitting(587, vec![item("LoSlot0", 1, 3888)]);
        let (cpu, power) = budgets(fitting_resources(&fit, &catalogue));
        assert_close(cpu.used, 0.0);
        assert_close(power.used, 1.0);
        assert_close(cpu.output, 143.0);
        assert_close(cpu.base_output, 130.0);
        assert_eq!(power.output, power.base_output);
        assert_close(cpu.remaining(), 143.0);
        assert_close(power.remaining(), 40.0);
        assert_budgets_counts(&cpu, &power, (0, 0), (0, 0), (0, 0));
    }

    #[test]
    fn output_oracle_pds_dual_and_two_multipliers() {
        let catalogue = bundled();
        let fit = fitting(587, vec![item("LoSlot0", 1, 1541)]);
        let (cpu, power) = budgets(fitting_resources(&fit, &catalogue));
        assert_close(power.output, 43.46);
        assert_eq!(cpu.output, cpu.base_output);
        assert_close(cpu.used, 22.0);
        assert_budgets_counts(&cpu, &power, (0, 0), (0, 0), (0, 0));
        let fit = fitting(
            587,
            vec![item("LoSlot0", 1, 1541), item("LoSlot1", 1, 1355)],
        );
        let (cpu, _) = budgets(fitting_resources(&fit, &catalogue));
        assert_close(cpu.used, 44.0);
        let (_, power) = budgets(fitting_resources(&fit, &catalogue));
        assert_close(power.output, 49.979);
        let fit = fitting(
            587,
            vec![item("LoSlot0", 1, 1355), item("LoSlot1", 1, 1541)],
        );
        let (_, power) = budgets(fitting_resources(&fit, &catalogue));
        assert_close(power.output, 49.979);
    }

    #[test]
    fn output_oracle_with_skills_adds_before_percent() {
        let catalogue = bundled();
        let fit = fitting(
            587,
            vec![
                item("LoSlot0", 1, 1355),
                item("LoSlot1", 1, 3888),
                item("LoSlot2", 1, 4254),
            ],
        );
        // None and Some all-zero are equal.
        let none_result = fitting_resources(&fit, &catalogue);
        let zero_result = fitting_resources_with_skills(&fit, &catalogue, Some(levels(0, 0)));
        assert_eq!(none_result, zero_result);
        let (cpu, power) = budgets(none_result);
        assert_close(cpu.used, 40.0);
        assert_close(power.used, 1.0);
        assert_close(cpu.output, 143.0);
        assert_close(cpu.remaining(), 103.0);
        assert_close(power.output, 60.95);
        assert_close(power.remaining(), 59.95);
        assert_close(cpu.base_output, 130.0);
        assert_close(power.base_output, 41.0);
        assert_eq!(cpu.base_used, cpu.used);
        assert_eq!(power.base_used, power.used);
        assert_budgets_counts(&cpu, &power, (0, 0), (0, 0), (0, 0));
        // With CPU Management 5 + Power Grid Management 5
        // (all need skills 0): the adds-first composition.
        // The skill-scales-base-then-adds mutant gives
        // (41.0 * 1.25 + 12.0) * 1.15 = 72.7375.
        let (cpu, power) = budgets(fitting_resources_with_skills(
            &fit,
            &catalogue,
            Some(levels(5, 5)),
        ));
        assert_close(cpu.output, 178.75);
        assert_close(power.output, 76.1875);
        assert_close(cpu.base_output, 162.5);
        assert_close(power.base_output, 51.25);
        assert_close(cpu.used, 40.0);
        assert_close(power.used, 1.0);
        assert_eq!(cpu.base_used, cpu.used);
        assert_eq!(power.base_used, power.used);
        // Both helper values pinned through bonused_outputs
        // directly (the ship_resistances oracle pins).
        let helper =
            crate::fitting::ship_resistances::bonused_outputs(&fit, &catalogue, Some((5, 5)))
                .expect("Some");
        assert_close(helper.values[0].expect("cpu Some"), 178.75);
        assert_close(helper.values[1].expect("power Some"), 76.1875);
    }

    #[test]
    fn output_oracle_rig_percents_counted_population() {
        let catalogue = bundled();
        // (a) CPU rig: counted for output, invisible to needs
        let fit = fitting(587, vec![item("RigSlot0", 1, 4399)]);
        let (cpu, power) = budgets(fitting_resources(&fit, &catalogue));
        assert_close(cpu.output, 142.48);
        assert_close(cpu.used, 0.0);
        assert_close(power.used, 0.0);
        assert_budgets_counts(&cpu, &power, (0, 0), (0, 0), (0, 0));
        // (b) power rig reaches the operator-4 number by the
        // operator-6 route
        let fit = fitting(587, vec![item("RigSlot0", 1, 26370)]);
        let (_, power) = budgets(fitting_resources(&fit, &catalogue));
        assert_close(power.output, 47.15);
        // (c) two power rigs, percents sorted 15.0 before 10.0
        let fit = fitting(
            587,
            vec![item("RigSlot0", 1, 26370), item("RigSlot1", 1, 25956)],
        );
        let (_, power) = budgets(fitting_resources(&fit, &catalogue));
        assert_close(power.output, 51.865);
        // (d) the same rig under Cargo: exactly base under ==,
        // counts all zero
        let fit = fitting(587, vec![item("Cargo", 1, 4399)]);
        let (cpu, power) = budgets(fitting_resources(&fit, &catalogue));
        assert_eq!(cpu.output, cpu.base_output);
        assert_eq!(power.output, power.base_output);
        assert_eq!(cpu.output, 130.0);
        assert_eq!(power.output, 41.0);
        assert_budgets_counts(&cpu, &power, (0, 0), (0, 0), (0, 0));
    }

    #[test]
    fn output_oracle_drawback_shrinks_and_flips() {
        let catalogue = bundled();
        let fit = fitting(587, vec![item("RigSlot0", 1, 25908)]);
        let (cpu, _) = budgets(fitting_resources(&fit, &catalogue));
        assert_close(cpu.output, 117.0);
        assert_close(cpu.base_output, 130.0);
        assert!(cpu.output < cpu.base_output);
        // With 5x DC (150.0 CPU) the rig flips the judgment
        // over; at CPU Management 5 the output (146.25) is
        // still over, where without the rig it judges under
        // at 162.5.
        let items: Vec<FittingItem> = (0..5)
            .map(|n| item(&format!("LoSlot{n}"), 1, 2048))
            .chain([item("RigSlot0", 1, 25908)])
            .collect();
        let (cpu, _) = budgets(fitting_resources(&fitting(587, items), &catalogue));
        assert_close(cpu.used, 150.0);
        assert_close(cpu.output, 117.0);
        assert!(cpu.is_over());
        let fit = fitting(
            587,
            vec![
                item("LoSlot0", 1, 2048),
                item("LoSlot1", 1, 2048),
                item("LoSlot2", 1, 2048),
                item("LoSlot3", 1, 2048),
                item("LoSlot4", 1, 2048),
                item("RigSlot0", 1, 25908),
            ],
        );
        let (cpu, _) = budgets(fitting_resources_with_skills(
            &fit,
            &catalogue,
            Some(levels(5, 0)),
        ));
        assert_close(cpu.output, 146.25);
        assert!(cpu.is_over());
        let items_no_rig: Vec<FittingItem> = (0..5)
            .map(|n| item(&format!("LoSlot{n}"), 1, 2048))
            .collect();
        let (cpu, _) = budgets(fitting_resources_with_skills(
            &fitting(587, items_no_rig),
            &catalogue,
            Some(levels(5, 0)),
        ));
        assert_close(cpu.output, 162.5);
        assert!(!cpu.is_over());
    }

    #[test]
    fn output_oracle_absent_split() {
        let catalogue = bundled();
        let fit = fitting(587, vec![item("LoSlot0", 1, 1445)]);
        let (cpu, power) = budgets(fitting_resources(&fit, &catalogue));
        assert_eq!(power.output, power.base_output);
        assert_eq!(power.output, 41.0);
        assert_eq!(power.output_unapplied_modules, 1);
        assert_eq!(cpu.output_unapplied_modules, 0);
        assert_eq!(cpu.output, cpu.base_output);
        assert_close(cpu.used, 4.0);
        assert_close(power.used, 0.0);
        assert_eq!(cpu.excluded_modules, 0);
        assert_eq!(power.excluded_modules, 0);
        let fit = fitting(587, vec![item("LoSlot0", 2, 1445)]);
        let (_, power) = budgets(fitting_resources(&fit, &catalogue));
        assert_eq!(power.output_unapplied_modules, 2);
        // Not level-gated: at Some((5, 5)) the output is
        // 51.25 == base_output with the count still 1.
        let fit = fitting(587, vec![item("LoSlot0", 1, 1445)]);
        let (_, power) = budgets(fitting_resources_with_skills(
            &fit,
            &catalogue,
            Some(levels(5, 5)),
        ));
        assert_eq!(power.output, power.base_output);
        assert_eq!(power.output, 51.25);
        assert_eq!(power.output_unapplied_modules, 1);
    }

    #[test]
    fn output_oracle_skill_inside_sorted_chain() {
        let catalogue = bundled();
        // (a) power: skill 25.0 then rig 15.0 after the sort
        let fit = fitting(587, vec![item("RigSlot0", 1, 26370)]);
        let (_, power) = budgets(fitting_resources_with_skills(
            &fit,
            &catalogue,
            Some(levels(0, 5)),
        ));
        assert_eq!(power.output, (41.0 + 0.0) * 1.0 * ((1.0 * 1.25) * 1.15));
        // (b) CPU: skill 25.0 then rig 9.6
        let fit = fitting(587, vec![item("RigSlot0", 1, 4399)]);
        let (cpu, _) = budgets(fitting_resources_with_skills(
            &fit,
            &catalogue,
            Some(levels(5, 0)),
        ));
        assert_eq!(
            cpu.output,
            (130.0 + 0.0) * 1.0 * ((1.0 * 1.25) * (1.0 + 9.6 / 100.0))
        );
        // (c) equal absolute values keep module-then-skill
        // order; the value is 130.0 * 0.9 * 1.1 = 128.7
        let fit = fitting(587, vec![item("RigSlot0", 1, 25908)]);
        let (cpu, _) = budgets(fitting_resources_with_skills(
            &fit,
            &catalogue,
            Some(levels(2, 0)),
        ));
        assert_close(cpu.output, 128.7);
    }

    #[test]
    fn output_oracle_over_flip_against_bonused() {
        let catalogue = bundled();
        let items: Vec<FittingItem> = (0..5)
            .map(|n| item(&format!("LoSlot{n}"), 1, 2048))
            .chain([item("LoSlot5", 1, 3888)])
            .collect();
        let (cpu, _) = budgets(fitting_resources(&fitting(587, items), &catalogue));
        assert_close(cpu.output, 143.0);
        assert!(cpu.is_over());
        assert_close(cpu.remaining(), -7.0);
        assert_close(cpu.used, 150.0);
        let (cpu, _) = budgets(fitting_resources_with_skills(
            &fitting(
                587,
                vec![
                    item("LoSlot0", 1, 2048),
                    item("LoSlot1", 1, 2048),
                    item("LoSlot2", 1, 2048),
                    item("LoSlot3", 1, 2048),
                    item("LoSlot4", 1, 2048),
                    item("LoSlot5", 1, 3888),
                ],
            ),
            &catalogue,
            Some(levels(5, 0)),
        ));
        assert_close(cpu.output, 178.75);
        assert!(!cpu.is_over());
    }

    #[test]
    fn output_empty_equals_current_exactly() {
        let catalogue = bundled();
        // Whole-outcome assert_eq carrying today's numbers
        assert_eq!(
            fitting_resources(&fitting(587, vec![]), &catalogue),
            FittingResources::Available {
                cpu: ResourceBudget {
                    used: 0.0,
                    output: 130.0,
                    base_output: 130.0,
                    excluded_modules: 0,
                    base_used: 0.0,
                    unreduced_modules: 0,
                    output_unapplied_modules: 0,
                },
                power: ResourceBudget {
                    used: 0.0,
                    output: 41.0,
                    base_output: 41.0,
                    excluded_modules: 0,
                    base_used: 0.0,
                    unreduced_modules: 0,
                    output_unapplied_modules: 0,
                },
            }
        );
        // Hull-only table asserted by assert_eq against
        // base * (1.0 + 0.05 * level) evaluated in the test
        // (the shipped assert_close table keeps pinning the
        // decimal literals unmodified).
        for level in 0..=5 {
            let (cpu, power) = budgets(fitting_resources_with_skills(
                &fitting(587, vec![]),
                &catalogue,
                Some(levels(level, level)),
            ));
            assert_eq!(cpu.output, 130.0 * (1.0 + 0.05 * level as f64));
            assert_eq!(power.output, 41.0 * (1.0 + 0.05 * level as f64));
            assert_eq!(cpu.output, cpu.base_output);
            assert_eq!(power.output, power.base_output);
        }
        let (cpu, power) = budgets(fitting_resources_with_skills(
            &fitting(597, vec![]),
            &catalogue,
            Some(levels(5, 5)),
        ));
        assert_eq!(cpu.output, 140.0 * 1.25);
        assert_eq!(power.output, 67.0 * 1.25);
        assert_eq!(cpu.output, cpu.base_output);
        assert_eq!(power.output, power.base_output);
        // Only non-counted and non-consuming items
        for (flag, quantity, type_id) in [
            ("RigSlot0", 1, 2048),
            ("SubSystemSlot0", 1, 2048),
            ("Cargo", 1, 3888),
            ("DroneBay", 1, 2048),
            ("LoSlot0", 0, 3888),
            ("LoSlot0", -5, 3888),
            ("LoSlot0", 1, 0),
            ("LoSlot0", 1, -1),
        ] {
            let (cpu, power) = budgets(fitting_resources(
                &fitting(587, vec![item(flag, quantity, type_id)]),
                &catalogue,
            ));
            assert_eq!(cpu.output, cpu.base_output, "flag {flag}");
            assert_eq!(power.output, power.base_output, "flag {flag}");
            assert_eq!(cpu.output_unapplied_modules, 0, "flag {flag}");
            assert_eq!(power.output_unapplied_modules, 0, "flag {flag}");
        }
        // Counted non-carriers (resistance carriers that are
        // output non-carriers), low and rig slots
        for flag in ["LoSlot0", "RigSlot0"] {
            let (cpu, power) = budgets(fitting_resources(
                &fitting(587, vec![item(flag, 1, 2048)]),
                &catalogue,
            ));
            assert_eq!(cpu.output, cpu.base_output, "flag {flag}");
            assert_eq!(power.output, power.base_output, "flag {flag}");
            assert_eq!(cpu.output_unapplied_modules, 0, "flag {flag}");
            assert_eq!(power.output_unapplied_modules, 0, "flag {flag}");
        }
        // EFT sample-fit oracle (rig 31668 is not a carrier)
        let sample = concat!(
            "[Rifter, Sample Brawler]\n",
            "Damage Control II\n",
            "Small Armor Repairer II\n",
            "\n",
            "1MN Afterburner II\n",
        );
        match parse_eft(sample, &catalogue) {
            EftImportOutcome::Imported(imported) => {
                let fit = imported.to_character_fitting();
                let (cpu, power) = budgets(fitting_resources(&fit, &catalogue));
                assert_eq!(cpu.output, cpu.base_output);
                assert_eq!(power.output, power.base_output);
                assert_eq!(cpu.output, 130.0);
                assert_eq!(power.output, 41.0);
                assert_eq!(cpu.output_unapplied_modules, 0);
                assert_eq!(power.output_unapplied_modules, 0);
            }
            EftImportOutcome::Failed(fatal) => panic!("sample must import, got {fatal:?}"),
        }
        // Synthetic Flutter oracle stays bit-identical
        let synthetic = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":587,"typeName":"Rifter","categoryId":6,"slotEffects":[],"cpuOutput":125.0,"powerOutput":37.0}]}"#,
        )
        .expect("fixture catalogue parses");
        let (cpu, power) = budgets(fitting_resources_with_skills(
            &fitting(587, vec![]),
            &synthetic,
            Some(levels(5, 5)),
        ));
        assert_eq!(cpu.output, 156.25);
        assert_eq!(power.output, 46.25);
        assert_eq!(cpu.output, cpu.base_output);
        assert_eq!(power.output, power.base_output);
    }

    #[test]
    fn output_base_output_is_todays_output() {
        let catalogue = bundled();
        // On carrier fits, base_output is today's figure and
        // output carries the bonuses.
        let fit = fitting(587, vec![item("LoSlot0", 1, 1355)]);
        let (_, power) = budgets(fitting_resources(&fit, &catalogue));
        assert_eq!(power.base_output, 41.0);
        assert_close(power.output, 47.15);
        let fit = fitting(
            587,
            vec![
                item("LoSlot0", 1, 1355),
                item("LoSlot1", 1, 3888),
                item("LoSlot2", 1, 4254),
            ],
        );
        let (cpu, power) = budgets(fitting_resources_with_skills(
            &fit,
            &catalogue,
            Some(levels(5, 5)),
        ));
        assert_eq!(cpu.base_output, 130.0 * (1.0 + 0.05 * 5.0));
        assert_eq!(power.base_output, 41.0 * (1.0 + 0.05 * 5.0));
        // Hand-built levels beyond 0..=5 re-clamp for the
        // new field (shipped pin semantics).
        let wild = ResourceSkillLevels {
            cpu_management: 99,
            power_grid_management: -1,
            weapon_upgrades: 0,
            advanced_weapon_upgrades: 0,
            energy_grid_upgrades: 0,
            electronics_upgrades: 0,
            shield_upgrades: 0,
        };
        let (cpu, power) = budgets(fitting_resources_with_skills(
            &fitting(587, vec![]),
            &catalogue,
            Some(wild),
        ));
        assert_eq!(cpu.base_output, 130.0 * (1.0 + 0.05 * 5.0));
        assert_eq!(power.base_output, 41.0);
        assert_eq!(cpu.output, cpu.base_output);
        assert_eq!(power.output, power.base_output);
        // No-carrier fits have output == base_output exactly
        let (cpu, power) = budgets(fitting_resources(
            &fitting(587, vec![item("LoSlot0", 1, 2048)]),
            &catalogue,
        ));
        assert_eq!(cpu.output, cpu.base_output);
        assert_eq!(power.output, power.base_output);
    }

    #[test]
    fn output_excluded_widening_absent_counted_rows() {
        let catalogue = bundled();
        // Unknown type at RigSlot0 and SubSystemSlot0: both
        // dimensions +1 per unit, used/outputs untouched,
        // output-unapplied 0.
        for flag in ["RigSlot0", "SubSystemSlot0"] {
            let fit = fitting(587, vec![item(flag, 1, 999999)]);
            let (cpu, power) = budgets(fitting_resources(&fit, &catalogue));
            assert_close(cpu.used, 0.0);
            assert_close(power.used, 0.0);
            assert_eq!(cpu.output, 130.0);
            assert_eq!(power.output, 41.0);
            assert_eq!(cpu.excluded_modules, 1, "flag {flag}");
            assert_eq!(power.excluded_modules, 1, "flag {flag}");
            assert_eq!(cpu.output_unapplied_modules, 0, "flag {flag}");
            assert_eq!(power.output_unapplied_modules, 0, "flag {flag}");
            let fit = fitting(587, vec![item(flag, 5, 999999)]);
            let (cpu, power) = budgets(fitting_resources(&fit, &catalogue));
            assert_eq!(cpu.excluded_modules, 5, "flag {flag}");
            assert_eq!(power.excluded_modules, 5, "flag {flag}");
        }
        // Unknown under non-counted flags still counts
        // nowhere (shipped pin stands).
        for flag in ["DroneBay", "Cargo"] {
            let fit = fitting(587, vec![item(flag, 1, 999999)]);
            let (cpu, power) = budgets(fitting_resources(&fit, &catalogue));
            assert_eq!(cpu.excluded_modules, 0, "flag {flag}");
            assert_eq!(power.excluded_modules, 0, "flag {flag}");
        }
        // A present non-carrier rig still 0.
        let fit = fitting(587, vec![item("RigSlot0", 1, 31668)]);
        let (cpu, power) = budgets(fitting_resources(&fit, &catalogue));
        assert_eq!(cpu.excluded_modules, 0);
        assert_eq!(power.excluded_modules, 0);
        assert_eq!(cpu.output_unapplied_modules, 0);
        assert_eq!(power.output_unapplied_modules, 0);
    }

    #[test]
    fn output_partiality_and_zero_rules() {
        // Absent powerOutput with a MAPC-equivalent fitted:
        // helper shows the split, public is ShipNoOutput
        // on both arms (no resurrection).
        let no_power = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":587,"typeName":"Rifter","categoryId":6,"slotEffects":[],"cpuOutput":130.0},
                {"typeId":101,"typeName":"Mapc","categoryId":7,"slotEffects":[11],"cpu":18.0,"power":0.0,"powerOutputModifiers":[[11,2,12.0]]}]}"#,
        )
        .expect("fixture catalogue parses");
        let fit = fitting(587, vec![item("LoSlot0", 1, 101)]);
        let helper =
            crate::fitting::ship_resistances::bonused_outputs(&fit, &no_power, None).expect("Some");
        assert_eq!(helper.values, [Some(130.0), None]);
        assert_eq!(
            fitting_resources(&fit, &no_power),
            FittingResources::ShipNoOutput
        );
        assert_eq!(
            fitting_resources_with_skills(&fit, &no_power, Some(levels(5, 5))),
            FittingResources::ShipNoOutput
        );
        // Mirror with cpuOutput absent
        let no_cpu = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":587,"typeName":"Rifter","categoryId":6,"slotEffects":[],"powerOutput":41.0},
                {"typeId":101,"typeName":"Coproc","categoryId":7,"slotEffects":[11],"cpu":0.0,"power":1.0,"cpuOutputModifiers":[[48,4,1.1]]}]}"#,
        )
        .expect("fixture catalogue parses");
        let fit = fitting(587, vec![item("LoSlot0", 1, 101)]);
        let helper =
            crate::fitting::ship_resistances::bonused_outputs(&fit, &no_cpu, None).expect("Some");
        assert_eq!(helper.values, [None, Some(41.0)]);
        assert_eq!(
            fitting_resources(&fit, &no_cpu),
            FittingResources::ShipNoOutput
        );
        // Present 0.0 + flat add raises output (application
        // to a present zero, not resurrection of absence).
        let zero_cat = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":2078,"typeName":"Zephyr","categoryId":6,"slotEffects":[],"cpuOutput":0.0,"powerOutput":0.0},
                {"typeId":101,"typeName":"Mapc","categoryId":7,"slotEffects":[11],"cpu":30.0,"power":1.0,"powerOutputModifiers":[[11,2,12.0]]}]}"#,
        )
        .expect("fixture catalogue parses");
        let (cpu, power) = budgets(fitting_resources(
            &fitting(2078, vec![item("LoSlot0", 1, 101)]),
            &zero_cat,
        ));
        assert_eq!(cpu.output, 0.0);
        assert_eq!(power.output, 12.0);
        // Fixture -100% gives a real zero judging over.
        let zeroed = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":587,"typeName":"Rifter","categoryId":6,"slotEffects":[],"cpuOutput":130.0,"powerOutput":41.0},
                {"typeId":101,"typeName":"Zero","categoryId":7,"slotEffects":[11],"cpu":30.0,"power":1.0,"powerOutputModifiers":[[11,6,-100.0]]}]}"#,
        )
        .expect("fixture catalogue parses");
        let helper = crate::fitting::ship_resistances::bonused_outputs(
            &fitting(587, vec![item("LoSlot0", 1, 101)]),
            &zeroed,
            None,
        )
        .expect("Some");
        assert_eq!(helper.values[1], Some(0.0));
        let (_, power) = budgets(fitting_resources(
            &fitting(587, vec![item("LoSlot0", 1, 101)]),
            &zeroed,
        ));
        assert_eq!(power.output, 0.0);
        assert!(power.is_over());
    }

    #[test]
    fn output_hostile_bounded_every_outcome_asserted() {
        let bundled_cat = bundled();
        // Fixture -20% rig at i64::MAX stalls subnormal:
        // helper None in that dimension, public ShipNoOutput
        // on both arms.
        let fixture = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":587,"typeName":"Rifter","categoryId":6,"slotEffects":[],"cpuOutput":130.0,"powerOutput":41.0},
                {"typeId":101,"typeName":"Host","categoryId":7,"slotEffects":[13],"powerOutputModifiers":[[11,6,-20.0]]}]}"#,
        )
        .expect("fixture catalogue parses");
        let fit = fitting(587, vec![item("RigSlot0", i64::MAX, 101)]);
        let helper =
            crate::fitting::ship_resistances::bonused_outputs(&fit, &fixture, None).expect("Some");
        assert_eq!(helper.values[1], None);
        assert_eq!(helper.values[0], Some(130.0));
        assert_eq!(
            fitting_resources(&fit, &fixture),
            FittingResources::ShipNoOutput
        );
        assert_eq!(
            fitting_resources_with_skills(&fit, &fixture, Some(levels(5, 5))),
            FittingResources::ShipNoOutput
        );
        // Real 25908 at i64::MAX stalls subnormal.
        let fit = fitting(587, vec![item("RigSlot0", i64::MAX, 25908)]);
        let helper = crate::fitting::ship_resistances::bonused_outputs(&fit, &bundled_cat, None)
            .expect("Some");
        assert_eq!(helper.values[0], None);
        assert_eq!(helper.values[1], Some(41.0));
        assert_eq!(
            fitting_resources(&fit, &bundled_cat),
            FittingResources::ShipNoOutput
        );
        // Real 1355 at i64::MAX overflows non-finite.
        let fit = fitting(587, vec![item("LoSlot0", i64::MAX, 1355)]);
        let helper = crate::fitting::ship_resistances::bonused_outputs(&fit, &bundled_cat, None)
            .expect("Some");
        assert_eq!(helper.values[1], None);
        assert_eq!(
            fitting_resources(&fit, &bundled_cat),
            FittingResources::ShipNoOutput
        );
        // Real 4254 at i64::MAX stays finite by formula
        // and stays Available.
        let fit = fitting(587, vec![item("LoSlot0", i64::MAX, 4254)]);
        let helper = crate::fitting::ship_resistances::bonused_outputs(&fit, &bundled_cat, None)
            .expect("Some");
        assert_eq!(helper.values[1], Some(41.0 + 12.0 * (i64::MAX as f64)));
        let (cpu, power) = budgets(fitting_resources(&fit, &bundled_cat));
        assert!(cpu.used.is_finite());
        assert!(power.used.is_finite());
        assert!(cpu.is_over());
        assert!(!power.is_over());
        // Negative results are ShipNoOutput, never a
        // negative output.
        for entries in ["[[11,6,-150.0]]", "[[11,4,-1.15]]"] {
            let negative = FittingTypes::from_json(
                &format!(
                    r#"{{"types":[{{"typeId":587,"typeName":"Rifter","categoryId":6,"slotEffects":[],"cpuOutput":130.0,"powerOutput":41.0}},
                    {{"typeId":101,"typeName":"Neg","categoryId":7,"slotEffects":[11],"cpu":30.0,"power":1.0,"powerOutputModifiers":{entries}}}]}}"#
                ),
            )
            .expect("fixture catalogue parses");
            let fit = fitting(587, vec![item("LoSlot0", 1, 101)]);
            let helper = crate::fitting::ship_resistances::bonused_outputs(&fit, &negative, None)
                .expect("Some");
            assert_eq!(helper.values[1], None, "entries {entries}");
            assert_eq!(
                fitting_resources(&fit, &negative),
                FittingResources::ShipNoOutput,
                "entries {entries}"
            );
        }
        let negative = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":587,"typeName":"Rifter","categoryId":6,"slotEffects":[],"cpuOutput":130.0,"powerOutput":41.0},
                {"typeId":101,"typeName":"NegAdd","categoryId":7,"slotEffects":[11],"cpu":30.0,"power":1.0,"powerOutputModifiers":[[11,2,-50.0]]}]}"#,
        )
        .expect("fixture catalogue parses");
        let fit = fitting(587, vec![item("LoSlot0", 1, 101)]);
        let helper =
            crate::fitting::ship_resistances::bonused_outputs(&fit, &negative, None).expect("Some");
        assert_eq!(helper.values[1], None);
        assert_eq!(
            fitting_resources(&fit, &negative),
            FittingResources::ShipNoOutput
        );
    }

    #[test]
    fn output_runtime_guards_never_sum() {
        let hull = r#"{"typeId":587,"typeName":"Rifter","categoryId":6,"slotEffects":[],"cpuOutput":130.0,"powerOutput":41.0}"#;
        // Marked-unapplied with an applicable entry: counted
        // once in power, applied (the output proves it), and
        // neither excluded nor unreduced.
        let cat = FittingTypes::from_json(
            &format!(r#"{{"types":[{hull},{{"typeId":101,"typeName":"Marked","categoryId":7,"slotEffects":[11],"cpu":30.0,"power":1.0,"powerOutputModifiers":[[11,4,1.15]],"powerOutputModifiersUnapplied":true}}]}}"#),
        )
        .expect("fixture parses");
        let (cpu, power) = budgets(fitting_resources(
            &fitting(587, vec![item("LoSlot0", 1, 101)]),
            &cat,
        ));
        assert_eq!(power.output_unapplied_modules, 1);
        assert_eq!(cpu.output_unapplied_modules, 0);
        assert_close(power.output, 47.15);
        assert_eq!(power.excluded_modules, 0);
        assert_eq!(cpu.unreduced_modules, 0);
        // Bad operators, wrong ids, and zero each count once
        // in that family only; a good sibling entry still
        // applies. One bad entry here carries the pin; the
        // helper tests pin every operator exhaustively.
        let cat = FittingTypes::from_json(
            &format!(r#"{{"types":[{hull},{{"typeId":101,"typeName":"Bad","categoryId":7,"slotEffects":[11],"cpu":30.0,"power":1.0,"powerOutputModifiers":[[11,0,1.15],[11,4,0.0],[11,4,1.1]]}}]}}"#),
        )
        .expect("fixture parses");
        let (cpu, power) = budgets(fitting_resources(
            &fitting(587, vec![item("LoSlot0", 1, 101)]),
            &cat,
        ));
        assert_eq!(power.output_unapplied_modules, 1);
        assert_eq!(cpu.output_unapplied_modules, 0);
        assert_close(power.output, 45.1);
        assert_eq!(power.excluded_modules, 0);
        assert_eq!(power.unreduced_modules, 0);
        // The grounded CPU flat add applies through the
        // public budget as well, skilled and unskilled.
        let cat = FittingTypes::from_json(
            &format!(r#"{{"types":[{hull},{{"typeId":101,"typeName":"CpuAdd","categoryId":7,"slotEffects":[11],"cpu":30.0,"power":1.0,"cpuOutputModifiers":[[48,2,25.0]]}}]}}"#),
        )
        .expect("fixture parses");
        let (cpu, _) = budgets(fitting_resources(
            &fitting(587, vec![item("LoSlot0", 1, 101)]),
            &cat,
        ));
        assert_close(cpu.output, 155.0);
        assert_close(cpu.base_output, 130.0);
        let (cpu, _) = budgets(fitting_resources_with_skills(
            &fitting(587, vec![item("LoSlot0", 1, 101)]),
            &cat,
            Some(levels(5, 0)),
        ));
        assert_close(cpu.output, 193.75);
        assert_close(cpu.base_output, 162.5);
    }

    #[test]
    fn output_need_and_sibling_independence() {
        let catalogue = bundled();
        // Fitting carriers leaves used/base_used/unreduced at
        // their shipped oracles on the same fit.
        let fit = fitting(
            587,
            vec![
                item("LoSlot0", 1, 1355),
                item("LoSlot1", 1, 4254),
                item("LoSlot2", 1, 1541),
            ],
        );
        let (cpu, power) = budgets(fitting_resources(&fit, &catalogue));
        assert_close(cpu.used, 22.0 + 18.0 + 22.0);
        assert_close(power.used, 0.0);
        assert_close(cpu.base_used, cpu.used);
        assert_close(power.base_used, power.used);
        assert_eq!(cpu.unreduced_modules, 0);
        assert_eq!(power.unreduced_modules, 0);
        // 4254 (a non-carrier in every sibling family) moves
        // no sibling base figure: base stats and base
        // resistances equal the hull-only case.
        let carrier = fitting(587, vec![item("LoSlot0", 1, 4254)]);
        let hull_only = fitting(587, vec![]);
        assert_eq!(
            crate::fitting::ship_stats::ship_base_stats(&carrier, &catalogue),
            crate::fitting::ship_stats::ship_base_stats(&hull_only, &catalogue)
        );
        assert_eq!(
            crate::fitting::ship_resistances::ship_resistances(&carrier, &catalogue),
            crate::fitting::ship_resistances::ship_resistances(&hull_only, &catalogue)
        );
        // The bonused sibling helpers for a 4254 fit equal
        // the hull-only case (no sibling entry exists to
        // apply), while the resources helper moves.
        let helper_carrier =
            crate::fitting::ship_resistances::bonused_outputs(&carrier, &catalogue, None)
                .expect("Some");
        let helper_hull =
            crate::fitting::ship_resistances::bonused_outputs(&hull_only, &catalogue, None)
                .expect("Some");
        assert_ne!(helper_carrier.values[1], helper_hull.values[1]);
    }
}
