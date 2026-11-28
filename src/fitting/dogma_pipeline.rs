//! Pure Dogma modifier evaluator: canonical operator order,
//! stacking penalties, skill contexts, and module states.
//!
//! The shipped `ship_*` blocks each apply one baked modifier
//! family (resonances, hit points, capacitor, outputs,
//! navigation/targeting) from generation-time-proven catalogue
//! triples. This module is the shared evaluator those families
//! — and the hull-trait (category 6), trained-skill
//! (category 16), implant/booster (category 20), and T3C
//! subsystem (category 32) sources the bundled extract does
//! not yet bake — all reduce to: one base attribute value
//! plus a list of [`DogmaModifier`]s in, one
//! [`EvaluatedAttribute`] with full provenance out.
//!
//! Canonical operator order (EVE Dogma): `PreAssign`,
//! `PreMul`, `PreDiv`, `ModAdd`, `ModSub`, `PostMul`,
//! `PostDiv`, `PostPercent`, `PostAssign`. Stacking penalty
//! `S(i) = exp(-(i / 2.67)^2)` over the 0-indexed penalized
//! chain, sorted by magnitude descending, applies ONLY to
//! module/rig/subsystem modifiers whose target attribute is
//! non-stackable — never to hull traits or skills. Unknown
//! or unusable operands land in `unapplied_effects` with a
//! named reason; nothing is ever guessed.
//!
//! The module is pure computation — no egui, no state, no
//! network, no database. It logs nothing: it runs at render
//! cadence, so per-frame `[FITTING]` logging would spam the
//! log (the `ship_resistances.rs` precedent).

/// How trained-skill levels resolve while evaluating. The
/// tag is part of every result so a caller can always
/// disclose whether a number assumes trained skills, all-V
/// skills, or no skills at all — never silently pretend
/// trained skills loaded.
#[derive(Debug, Clone, PartialEq)]
pub enum SkillContext {
    /// The character's trained levels, `(skill_type_id,
    /// level)` pairs. A skill absent from the list is
    /// untrained (level 0).
    Trained(Vec<(i64, i32)>),
    /// Every skill at level V.
    AllFive,
    /// No skill contributes; every level resolves to 0.
    BaseOnly,
}

impl SkillContext {
    /// The provenance tag disclosed beside any number
    /// derived under this context.
    pub fn tag(&self) -> &'static str {
        match self {
            SkillContext::Trained(_) => "Trained Character",
            SkillContext::AllFive => "Assumes All V",
            SkillContext::BaseOnly => "Base Only",
        }
    }

    /// Resolved level for one skill, clamped to `0..=5`.
    pub fn level(&self, skill_type_id: i64) -> i32 {
        match self {
            SkillContext::Trained(levels) => levels
                .iter()
                .find(|(id, _)| *id == skill_type_id)
                .map(|(_, level)| (*level).clamp(0, 5))
                .unwrap_or(0),
            SkillContext::AllFive => 5,
            SkillContext::BaseOnly => 0,
        }
    }
}

/// Activation state of the fitted item carrying a modifier.
/// Ordering is the EVE state ladder: an overheated module is
/// also active and online.
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub enum ModuleState {
    Offline,
    Online,
    Active,
    Overheated,
}

/// Which kind of owner carries a modifier. The kind alone
/// decides stacking-penalty eligibility (with the target's
/// stackable flag): fitted modules, rigs, and subsystems
/// penalize; hull traits, skills, implants, and charges
/// never do.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ModifierSource {
    /// Ship hull traits and role bonuses (category 6).
    HullTrait,
    /// Trained skills (category 16).
    Skill,
    /// Implants and boosters (category 20).
    Implant,
    /// Fitted modules (category 7, slot sections).
    Module,
    /// Fitted rigs (category 7, rig sections).
    Rig,
    /// T3C subsystems (category 32).
    Subsystem,
    /// Loaded charges (category 8).
    Charge,
    /// Any other owner; never stacking-penalized.
    Other,
}

/// One Dogma operator, in canonical evaluation order.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DogmaOperator {
    PreAssign,
    PreMul,
    PreDiv,
    ModAdd,
    ModSub,
    PostMul,
    PostDiv,
    PostPercent,
    PostAssign,
}

/// Whether a modifier's operand is final or scales per
/// trained level of its scaling skill (the shape every
/// percentage-per-level hull trait and skill bonus takes).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum OperandScaling {
    /// Operand applies as written.
    Flat,
    /// Operand is per skill level; the effective operand is
    /// `operand * level(skill_type_id)` under the active
    /// [`SkillContext`].
    PerSkillLevel,
}

/// One fully-described modifier over one attribute. Callers
/// resolve the operand from SDE data (or leave it `None` and
/// let the evaluator disclose it as unapplied); the
/// evaluator never invents one.
#[derive(Debug, Clone, PartialEq)]
pub struct DogmaModifier {
    /// Target dogma attribute id (used by
    /// [`evaluate_attributes`] grouping; single-attribute
    /// evaluation assumes the caller pre-filtered).
    pub attribute_id: i64,
    pub operator: DogmaOperator,
    /// The operand: a raw factor for mul/div operators, a
    /// flat delta for add/sub, a percent for `PostPercent`,
    /// a replacement value for assigns. `None` is an
    /// unpublished operand — disclosed, never guessed.
    pub operand: Option<f64>,
    pub source: ModifierSource,
    /// Owner type id, for provenance only.
    pub source_type_id: i64,
    /// Scaling skill for [`OperandScaling::PerSkillLevel`].
    pub skill_type_id: Option<i64>,
    pub scaling: OperandScaling,
    /// State of the carrying item. `Offline` modifiers
    /// never apply. An overheated modifier's operand is the
    /// already-overheat-scaled value the caller resolved
    /// from the SDE overload attributes.
    pub state: ModuleState,
    /// Whether the target attribute is stackable
    /// (`dgmAttributeTypes.stackable`). Stackable targets
    /// never penalize, whatever the source.
    pub target_stackable: bool,
    /// Human-readable provenance for `unapplied_effects`.
    pub label: String,
}

impl DogmaModifier {
    /// A flat, online modifier with no skill scaling — the
    /// common case. Callers override fields as needed.
    pub fn new(
        attribute_id: i64,
        operator: DogmaOperator,
        operand: Option<f64>,
        source: ModifierSource,
        source_type_id: i64,
        label: impl Into<String>,
    ) -> Self {
        Self {
            attribute_id,
            operator,
            operand,
            source,
            source_type_id,
            skill_type_id: None,
            scaling: OperandScaling::Flat,
            state: ModuleState::Online,
            target_stackable: false,
            label: label.into(),
        }
    }

    /// Whether this modifier joins the stacking-penalized
    /// chain: module/rig/subsystem owner on a non-stackable
    /// target. Hull traits (cat 6) and skills (cat 16) are
    /// never penalized.
    pub fn penalized(&self) -> bool {
        matches!(
            self.source,
            ModifierSource::Module | ModifierSource::Rig | ModifierSource::Subsystem
        ) && !self.target_stackable
    }
}

/// Why one modifier could not be applied.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum UnappliedReason {
    /// Operand absent (unpublished expression operand).
    MissingOperand,
    /// Operand present but NaN or infinite.
    NonFiniteOperand,
    /// Per-level scaling without a scaling skill.
    MissingScalingSkill,
    /// Division by a zero operand.
    ZeroDivisor,
    /// Modifier targets an attribute with no base value in
    /// a multi-attribute evaluation.
    UnknownAttribute,
}

/// One disclosed unapplied effect: what was skipped and why.
#[derive(Debug, Clone, PartialEq)]
pub struct UnappliedEffect {
    pub label: String,
    pub source_type_id: i64,
    pub operator: DogmaOperator,
    pub reason: UnappliedReason,
}

/// The evaluated value of one attribute plus the provenance
/// counts a caller must disclose beside it.
#[derive(Debug, Clone, PartialEq)]
pub struct EvaluatedAttribute {
    /// Final value, or `None` when the result went
    /// non-finite (overflow guard; never a silent zero).
    pub value: Option<f64>,
    /// Modifiers that actually changed (or confirmed) the
    /// value through the pipeline.
    pub applied: usize,
    /// Modifiers skipped because their carrier is offline.
    pub inactive_offline: usize,
    /// Every skipped modifier with its reason.
    pub unapplied_effects: Vec<UnappliedEffect>,
    /// Provenance tag of the [`SkillContext`] used.
    pub skill_context_tag: &'static str,
}

/// Stacking effectiveness of the 0-indexed `i`-th penalized
/// modifier in one chain: `exp(-(i / 2.67)^2)`. Identical to
/// `resistance_stacking_penalty(i + 1)` in
/// `ship_resistances.rs` (pinned by test).
pub fn stacking_effectiveness(i: usize) -> f64 {
    let scaled = i as f64 / 2.67;
    (-(scaled * scaled)).exp()
}

/// One modifier after operand resolution, ready for the
/// operator pipeline.
struct Resolved {
    operator: DogmaOperator,
    operand: f64,
    penalized: bool,
}

/// Product of one factor chain. Unpenalized factors multiply
/// raw; penalized factors sort by `|factor - 1|` descending
/// and the 0-indexed `i`-th contributes
/// `1 + (factor - 1) * S(i)`.
fn factor_chain(factors: &[(f64, bool)]) -> f64 {
    let mut product = 1.0;
    let mut penalized: Vec<f64> = Vec::new();
    for (factor, is_penalized) in factors {
        if *is_penalized {
            penalized.push(*factor);
        } else {
            product *= factor;
        }
    }
    penalized.sort_by(|a, b| (b - 1.0).abs().total_cmp(&(a - 1.0).abs()));
    for (i, factor) in penalized.iter().enumerate() {
        let effectiveness = stacking_effectiveness(i);
        if effectiveness == 0.0 {
            break;
        }
        product *= 1.0 + (factor - 1.0) * effectiveness;
    }
    product
}

/// Evaluate one attribute: `base` under every modifier in
/// `modifiers` (callers pre-filter to one attribute),
/// resolved under `skills`. Total: never panics, never
/// guesses an operand.
pub fn evaluate_attribute(
    base: f64,
    modifiers: &[DogmaModifier],
    skills: &SkillContext,
) -> EvaluatedAttribute {
    let mut unapplied_effects: Vec<UnappliedEffect> = Vec::new();
    let mut inactive_offline: usize = 0;
    let mut resolved: Vec<Resolved> = Vec::new();
    for modifier in modifiers {
        if modifier.state == ModuleState::Offline {
            inactive_offline = inactive_offline.saturating_add(1);
            continue;
        }
        let Some(raw) = modifier.operand else {
            unapplied_effects.push(UnappliedEffect {
                label: modifier.label.clone(),
                source_type_id: modifier.source_type_id,
                operator: modifier.operator,
                reason: UnappliedReason::MissingOperand,
            });
            continue;
        };
        if !raw.is_finite() {
            unapplied_effects.push(UnappliedEffect {
                label: modifier.label.clone(),
                source_type_id: modifier.source_type_id,
                operator: modifier.operator,
                reason: UnappliedReason::NonFiniteOperand,
            });
            continue;
        }
        let operand = match modifier.scaling {
            OperandScaling::Flat => raw,
            OperandScaling::PerSkillLevel => match modifier.skill_type_id {
                Some(skill_id) => raw * f64::from(skills.level(skill_id)),
                None => {
                    unapplied_effects.push(UnappliedEffect {
                        label: modifier.label.clone(),
                        source_type_id: modifier.source_type_id,
                        operator: modifier.operator,
                        reason: UnappliedReason::MissingScalingSkill,
                    });
                    continue;
                }
            },
        };
        if matches!(
            modifier.operator,
            DogmaOperator::PreDiv | DogmaOperator::PostDiv
        ) && operand == 0.0
        {
            unapplied_effects.push(UnappliedEffect {
                label: modifier.label.clone(),
                source_type_id: modifier.source_type_id,
                operator: modifier.operator,
                reason: UnappliedReason::ZeroDivisor,
            });
            continue;
        }
        resolved.push(Resolved {
            operator: modifier.operator,
            operand,
            penalized: modifier.penalized(),
        });
    }
    let applied = resolved.len();
    let mut value = base;
    // Canonical order. Assigns: last in input order wins.
    for entry in &resolved {
        if entry.operator == DogmaOperator::PreAssign {
            value = entry.operand;
        }
    }
    for entry in &resolved {
        if entry.operator == DogmaOperator::PreMul {
            value *= entry.operand;
        }
    }
    for entry in &resolved {
        if entry.operator == DogmaOperator::PreDiv {
            value /= entry.operand;
        }
    }
    for entry in &resolved {
        if entry.operator == DogmaOperator::ModAdd {
            value += entry.operand;
        }
    }
    for entry in &resolved {
        if entry.operator == DogmaOperator::ModSub {
            value -= entry.operand;
        }
    }
    let post_mul: Vec<(f64, bool)> = resolved
        .iter()
        .filter(|e| e.operator == DogmaOperator::PostMul)
        .map(|e| (e.operand, e.penalized))
        .collect();
    value *= factor_chain(&post_mul);
    for entry in &resolved {
        if entry.operator == DogmaOperator::PostDiv {
            value /= entry.operand;
        }
    }
    let post_percent: Vec<(f64, bool)> = resolved
        .iter()
        .filter(|e| e.operator == DogmaOperator::PostPercent)
        .map(|e| (1.0 + e.operand / 100.0, e.penalized))
        .collect();
    value *= factor_chain(&post_percent);
    for entry in &resolved {
        if entry.operator == DogmaOperator::PostAssign {
            value = entry.operand;
        }
    }
    EvaluatedAttribute {
        value: value.is_finite().then_some(value),
        applied,
        inactive_offline,
        unapplied_effects,
        skill_context_tag: skills.tag(),
    }
}

/// Evaluate several attributes at once. `bases` pairs each
/// attribute id with its base value; modifiers group by
/// `attribute_id`. A modifier targeting an attribute with
/// no base is disclosed once per result list in the
/// returned orphan list, never dropped silently. Results
/// preserve `bases` order.
pub fn evaluate_attributes(
    bases: &[(i64, f64)],
    modifiers: &[DogmaModifier],
    skills: &SkillContext,
) -> (Vec<(i64, EvaluatedAttribute)>, Vec<UnappliedEffect>) {
    let mut results: Vec<(i64, EvaluatedAttribute)> = Vec::with_capacity(bases.len());
    for (attribute_id, base) in bases {
        let own: Vec<DogmaModifier> = modifiers
            .iter()
            .filter(|m| m.attribute_id == *attribute_id)
            .cloned()
            .collect();
        results.push((*attribute_id, evaluate_attribute(*base, &own, skills)));
    }
    let orphans: Vec<UnappliedEffect> = modifiers
        .iter()
        .filter(|m| !bases.iter().any(|(id, _)| *id == m.attribute_id))
        .map(|m| UnappliedEffect {
            label: m.label.clone(),
            source_type_id: m.source_type_id,
            operator: m.operator,
            reason: UnappliedReason::UnknownAttribute,
        })
        .collect();
    (results, orphans)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn modifier(
        operator: DogmaOperator,
        operand: Option<f64>,
        source: ModifierSource,
    ) -> DogmaModifier {
        DogmaModifier::new(263, operator, operand, source, 101, "fixture")
    }

    fn assert_close(actual: f64, expected: f64, label: &str) {
        assert!(
            (actual - expected).abs() < 1e-9,
            "{label}: expected {expected}, got {actual}"
        );
    }

    fn value_of(result: &EvaluatedAttribute) -> f64 {
        result.value.expect("finite value")
    }

    #[test]
    fn canonical_operator_order_is_locked() {
        // Hand-derived: base 100 -> PreAssign 50 -> PreMul
        // x2 = 100 -> PreDiv /4 = 25 -> ModAdd +5 = 30 ->
        // ModSub -10 = 20 -> PostMul x3 = 60 -> PostDiv /2
        // = 30 -> PostPercent +10% = 33. Input order is
        // deliberately scrambled; only canonical order
        // reaches 33.
        let modifiers = vec![
            modifier(
                DogmaOperator::PostPercent,
                Some(10.0),
                ModifierSource::Skill,
            ),
            modifier(DogmaOperator::ModSub, Some(10.0), ModifierSource::Skill),
            modifier(DogmaOperator::PreAssign, Some(50.0), ModifierSource::Skill),
            modifier(DogmaOperator::PostDiv, Some(2.0), ModifierSource::Skill),
            modifier(DogmaOperator::ModAdd, Some(5.0), ModifierSource::Skill),
            modifier(DogmaOperator::PreMul, Some(2.0), ModifierSource::Skill),
            modifier(DogmaOperator::PostMul, Some(3.0), ModifierSource::Skill),
            modifier(DogmaOperator::PreDiv, Some(4.0), ModifierSource::Skill),
        ];
        let result = evaluate_attribute(100.0, &modifiers, &SkillContext::BaseOnly);
        assert_close(value_of(&result), 33.0, "canonical order");
        assert_eq!(result.applied, 8);
        assert!(result.unapplied_effects.is_empty());
        assert_eq!(result.skill_context_tag, "Base Only");
    }

    #[test]
    fn post_assign_wins_last() {
        let modifiers = vec![
            modifier(DogmaOperator::PostMul, Some(3.0), ModifierSource::Skill),
            modifier(DogmaOperator::PostAssign, Some(7.0), ModifierSource::Skill),
        ];
        let result = evaluate_attribute(100.0, &modifiers, &SkillContext::BaseOnly);
        assert_close(value_of(&result), 7.0, "post assign");
    }

    #[test]
    fn stacking_matches_resistance_precedent() {
        for i in 0..8 {
            assert_close(
                stacking_effectiveness(i),
                crate::fitting::ship_resistances::resistance_stacking_penalty(i + 1),
                "stacking parity",
            );
        }
        assert_close(stacking_effectiveness(0), 1.0, "first unpenalized");
    }

    #[test]
    fn penalized_chain_sorts_by_magnitude_and_skills_escape() {
        // Two module PostPercents (-55, -50) on a
        // non-stackable target penalize; a skill -25%
        // never does. Expected: 1.0 x 0.75 (skill) x 0.45
        // (first module full) x (1 - 0.50 * S(1)).
        let s1 = stacking_effectiveness(1);
        let expected = 0.75 * 0.45 * (1.0 - 0.50 * s1);
        let modifiers = vec![
            modifier(
                DogmaOperator::PostPercent,
                Some(-50.0),
                ModifierSource::Module,
            ),
            modifier(
                DogmaOperator::PostPercent,
                Some(-25.0),
                ModifierSource::Skill,
            ),
            modifier(
                DogmaOperator::PostPercent,
                Some(-55.0),
                ModifierSource::Module,
            ),
        ];
        let result = evaluate_attribute(1.0, &modifiers, &SkillContext::AllFive);
        assert_close(value_of(&result), expected, "penalized chain");
        // Hull traits escape identically: swap the skill
        // source for a hull trait, same value.
        let hull_modifiers = vec![
            modifier(
                DogmaOperator::PostPercent,
                Some(-50.0),
                ModifierSource::Module,
            ),
            modifier(
                DogmaOperator::PostPercent,
                Some(-25.0),
                ModifierSource::HullTrait,
            ),
            modifier(
                DogmaOperator::PostPercent,
                Some(-55.0),
                ModifierSource::Subsystem,
            ),
        ];
        let hull_result = evaluate_attribute(1.0, &hull_modifiers, &SkillContext::AllFive);
        assert_close(
            value_of(&hull_result),
            expected,
            "hull escapes, subsystem penalizes",
        );
    }

    #[test]
    fn stackable_target_never_penalizes() {
        let mut first = modifier(
            DogmaOperator::PostPercent,
            Some(-50.0),
            ModifierSource::Module,
        );
        first.target_stackable = true;
        let mut second = modifier(
            DogmaOperator::PostPercent,
            Some(-50.0),
            ModifierSource::Module,
        );
        second.target_stackable = true;
        let result = evaluate_attribute(1.0, &[first, second], &SkillContext::BaseOnly);
        assert_close(value_of(&result), 0.25, "stackable target");
    }

    #[test]
    fn per_level_scaling_follows_skill_context() {
        // +5% per level PostPercent from a hull trait scaled
        // by skill 3300: AllFive +25%, Trained III +15%,
        // BaseOnly +0%.
        let mut trait_mod = modifier(
            DogmaOperator::PostPercent,
            Some(5.0),
            ModifierSource::HullTrait,
        );
        trait_mod.scaling = OperandScaling::PerSkillLevel;
        trait_mod.skill_type_id = Some(3300);
        let all_five = evaluate_attribute(
            100.0,
            std::slice::from_ref(&trait_mod),
            &SkillContext::AllFive,
        );
        assert_close(value_of(&all_five), 125.0, "all five");
        assert_eq!(all_five.skill_context_tag, "Assumes All V");
        let trained = evaluate_attribute(
            100.0,
            std::slice::from_ref(&trait_mod),
            &SkillContext::Trained(vec![(3300, 3)]),
        );
        assert_close(value_of(&trained), 115.0, "trained III");
        assert_eq!(trained.skill_context_tag, "Trained Character");
        let base = evaluate_attribute(100.0, &[trait_mod], &SkillContext::BaseOnly);
        assert_close(value_of(&base), 100.0, "base only");
    }

    #[test]
    fn offline_and_unknown_operands_are_disclosed() {
        let mut offline = modifier(DogmaOperator::PostMul, Some(2.0), ModifierSource::Module);
        offline.state = ModuleState::Offline;
        let unknown = modifier(DogmaOperator::PostMul, None, ModifierSource::Module);
        let non_finite = modifier(
            DogmaOperator::PostMul,
            Some(f64::NAN),
            ModifierSource::Module,
        );
        let zero_div = modifier(DogmaOperator::PostDiv, Some(0.0), ModifierSource::Module);
        let result = evaluate_attribute(
            10.0,
            &[offline, unknown, non_finite, zero_div],
            &SkillContext::BaseOnly,
        );
        assert_close(value_of(&result), 10.0, "unchanged");
        assert_eq!(result.applied, 0);
        assert_eq!(result.inactive_offline, 1);
        assert_eq!(result.unapplied_effects.len(), 3);
        assert_eq!(
            result.unapplied_effects[0].reason,
            UnappliedReason::MissingOperand
        );
        assert_eq!(
            result.unapplied_effects[1].reason,
            UnappliedReason::NonFiniteOperand
        );
        assert_eq!(
            result.unapplied_effects[2].reason,
            UnappliedReason::ZeroDivisor
        );
    }

    #[test]
    fn overheated_modifier_applies_its_scaled_operand() {
        let mut hot = modifier(DogmaOperator::PostMul, Some(1.2), ModifierSource::Module);
        hot.state = ModuleState::Overheated;
        let result = evaluate_attribute(10.0, &[hot], &SkillContext::BaseOnly);
        assert_close(value_of(&result), 12.0, "overheated");
        assert_eq!(result.applied, 1);
    }

    #[test]
    fn non_finite_result_is_none_not_zero() {
        let modifiers = vec![modifier(
            DogmaOperator::PostMul,
            Some(1e308),
            ModifierSource::Skill,
        )];
        let result = evaluate_attribute(1e308, &modifiers, &SkillContext::BaseOnly);
        assert_eq!(result.value, None);
        assert_eq!(result.applied, 1);
    }

    #[test]
    fn multi_attribute_groups_and_discloses_orphans() {
        let mut orphan = modifier(DogmaOperator::PostMul, Some(2.0), ModifierSource::Skill);
        orphan.attribute_id = 999;
        let modifiers = vec![
            modifier(DogmaOperator::ModAdd, Some(5.0), ModifierSource::Skill),
            orphan,
        ];
        let (results, orphans) =
            evaluate_attributes(&[(263, 450.0)], &modifiers, &SkillContext::BaseOnly);
        assert_eq!(results.len(), 1);
        assert_close(value_of(&results[0].1), 455.0, "grouped add");
        assert_eq!(orphans.len(), 1);
        assert_eq!(orphans[0].reason, UnappliedReason::UnknownAttribute);
    }

    #[test]
    fn trained_levels_clamp_and_default_to_zero() {
        let context = SkillContext::Trained(vec![(3300, 9), (3310, -2)]);
        assert_eq!(context.level(3300), 5);
        assert_eq!(context.level(3310), 0);
        assert_eq!(context.level(9999), 0);
    }
}
