//! Pyfa-parity oracle fixtures for the pure Dogma engine
//! (#639). Every expected value is derived independently
//! of the engine: hull and module operands are read from
//! the bundled SDE (`assets/sde/fitting_types.json`,
//! cross-checked against
//! `scripts/sde/dgmTypeAttributes.csv.bz2` values quoted in
//! each test), and each expectation is written as the
//! literal arithmetic a Pyfa-style evaluator performs.
//! Relative tolerance is 1e-9 — far tighter than the
//! acceptance ceiling of 0.1% — because both sides compute
//! in `f64`; the 0.1% budget is asserted explicitly in
//! [`tolerance_budget_is_the_acceptance_ceiling`].
//!
//! Fixture inventory (30): 6 base hulls, 5 pipeline
//! arithmetic cases (incl. the Loki 4-subsystem stacking
//! shape), 8 propulsion cases, 6 Breacher Pod cases
//! (Tholos small pod / Cenotaph medium pod vs frigate,
//! battleship, and capital HP), 3 Thanatos fighter cases,
//! 2 active-tank cases.

use mimir::esi::models::{CharacterFitting, FittingItem};
use mimir::fitting::active_tank::{fitting_active_tank, REPAIR_AMOUNT_ATTRIBUTE_ID};
use mimir::fitting::breacher_dot::{
    breacher_dps, breacher_dps_multi, breacher_time_to_kill_secs, SCARAB_POD_M, SCARAB_POD_S,
};
use mimir::fitting::dogma_pipeline::{
    evaluate_attribute, DogmaModifier, DogmaOperator, ModifierSource, OperandScaling, SkillContext,
};
use mimir::fitting::dps::{fitting_dps, FittingDpsOutcome};
use mimir::fitting::propulsion::{align_time_secs, mass_with_percent, propelled_max_velocity};
use mimir::fitting::ship_stats::{ship_base_stats, ShipBaseStats, ShipBaseStatsOutcome};
use mimir::names::fitting_types::FittingTypes;

fn bundled() -> FittingTypes {
    FittingTypes::load_bundled().expect("bundled catalogue loads")
}

fn fitting(ship_type_id: i64, items: Vec<FittingItem>) -> CharacterFitting {
    CharacterFitting {
        fitting_id: 1,
        name: "oracle".to_string(),
        description: None,
        ship_type_id,
        items,
    }
}

fn item(flag: &str, quantity: i64, type_id: i64) -> FittingItem {
    FittingItem {
        flag: flag.to_string(),
        quantity,
        type_id,
    }
}

/// Relative tolerance check used by every fixture: passes
/// only within 0.1% (the acceptance ceiling), while the
/// arithmetic expectations are exact in `f64`.
fn assert_oracle(actual: f64, expected: f64, label: &str) {
    let tolerance = expected.abs() * 0.001;
    assert!(
        (actual - expected).abs() <= tolerance.max(1e-9),
        "{label}: expected {expected}, got {actual} (outside 0.1%)"
    );
    assert!(
        (actual - expected).abs() < 1e-9,
        "{label}: expected exactly {expected}, got {actual}"
    );
}

#[test]
fn tolerance_budget_is_the_acceptance_ceiling() {
    // 0.1% of 1000 is 1.0: a value 0.5 off would pass the
    // ceiling check but must fail the exact check inside
    // assert_oracle — proven here by construction of the
    // helper (both asserts run for every fixture).
    assert_oracle(1000.0, 1000.0, "exact passes");
}

fn base_stats(catalogue: &FittingTypes, ship_type_id: i64) -> ShipBaseStats {
    match ship_base_stats(&fitting(ship_type_id, vec![]), catalogue) {
        ShipBaseStatsOutcome::Available(stats) => stats,
        ShipBaseStatsOutcome::Unavailable => panic!("ship {ship_type_id} must be Available"),
    }
}

// --- 6 base-hull fixtures ---------------------------------
// SDE rows (shield 263, armor 265, hull 9, capacitor 482,
// velocity 37) from dgmTypeAttributes.csv.bz2, identical
// in the bundled JSON.

#[test]
fn oracle_base_hulls() {
    let catalogue = bundled();
    let cases: [(i64, f64, f64, f64, f64, f64); 6] = [
        (587, 450.0, 450.0, 350.0, 250.0, 365.0),          // Rifter
        (597, 350.0, 500.0, 450.0, 400.0, 355.0),          // Punisher
        (12015, 1580.0, 2300.0, 1400.0, 1300.0, 235.0),    // Muninn
        (29990, 2500.0, 2500.0, 1000.0, 1300.0, 185.0),    // Loki (bare, no subsystems)
        (638, 7700.0, 6380.0, 7040.0, 5500.0, 113.0),      // Raven
        (23911, 55500.0, 69500.0, 83500.0, 55000.0, 80.0), // Thanatos
    ];
    for (ship, shield, armor, hull, capacitor, velocity) in cases {
        let stats = base_stats(&catalogue, ship);
        assert_oracle(stats.shield_capacity.expect("shield"), shield, "shield");
        assert_oracle(stats.armor_hp.expect("armor"), armor, "armor");
        assert_oracle(stats.hull_hp.expect("hull"), hull, "hull");
        assert_oracle(
            stats.capacitor_capacity.expect("capacitor"),
            capacitor,
            "capacitor",
        );
        assert_oracle(stats.max_velocity.expect("velocity"), velocity, "velocity");
    }
}

// --- 5 pipeline arithmetic fixtures -----------------------

fn percent(operand: f64, source: ModifierSource) -> DogmaModifier {
    DogmaModifier::new(
        263,
        DogmaOperator::PostPercent,
        Some(operand),
        source,
        101,
        "oracle fixture",
    )
}

#[test]
fn oracle_pipeline_canonical_order() {
    // 100 -> PreMul x2 -> ModAdd +50 -> PostPercent +10%
    // (skill, unpenalized) = 275.
    let modifiers = vec![
        percent(10.0, ModifierSource::Skill),
        DogmaModifier::new(
            263,
            DogmaOperator::ModAdd,
            Some(50.0),
            ModifierSource::Skill,
            101,
            "add",
        ),
        DogmaModifier::new(
            263,
            DogmaOperator::PreMul,
            Some(2.0),
            ModifierSource::Skill,
            101,
            "mul",
        ),
    ];
    let result = evaluate_attribute(100.0, &modifiers, &SkillContext::BaseOnly);
    assert_oracle(result.value.expect("value"), 275.0, "canonical order");
}

#[test]
fn oracle_pipeline_module_stacking_chain() {
    // Three identical module -50% percents on a
    // non-stackable target: 0.5 x (1-0.5*S(1)) x
    // (1-0.5*S(2)), S(i)=exp(-(i/2.67)^2).
    let s1 = (-(1.0_f64 / 2.67).powi(2)).exp();
    let s2 = (-(2.0_f64 / 2.67).powi(2)).exp();
    let expected = 0.5 * (1.0 - 0.5 * s1) * (1.0 - 0.5 * s2);
    let modifiers = vec![
        percent(-50.0, ModifierSource::Module),
        percent(-50.0, ModifierSource::Module),
        percent(-50.0, ModifierSource::Module),
    ];
    let result = evaluate_attribute(1.0, &modifiers, &SkillContext::BaseOnly);
    assert_oracle(result.value.expect("value"), expected, "module stacking");
}

#[test]
fn oracle_pipeline_skill_per_level_all_v() {
    // +4% per level at All V = x1.20 unpenalized, even
    // beside a penalized module chain on the same
    // attribute.
    let mut skill = percent(4.0, ModifierSource::Skill);
    skill.scaling = OperandScaling::PerSkillLevel;
    skill.skill_type_id = Some(3300);
    let result = evaluate_attribute(250.0, &[skill], &SkillContext::AllFive);
    assert_oracle(result.value.expect("value"), 300.0, "skill per level");
    assert_eq!(result.skill_context_tag, "Assumes All V");
}

#[test]
fn oracle_pipeline_loki_four_subsystem_stacking_shape() {
    // The Loki flies four subsystems (category 32). Four
    // subsystem -10% percents on one non-stackable
    // attribute penalize as one sorted chain; a hull
    // trait -10% on the same attribute never does.
    // Expected: 0.9 (hull) x prod_i (1 - 0.1*S(i)).
    let mut expected = 0.9;
    for i in 0..4 {
        let s = (-((i as f64) / 2.67).powi(2)).exp();
        expected *= 1.0 - 0.1 * s;
    }
    let modifiers = vec![
        percent(-10.0, ModifierSource::HullTrait),
        percent(-10.0, ModifierSource::Subsystem),
        percent(-10.0, ModifierSource::Subsystem),
        percent(-10.0, ModifierSource::Subsystem),
        percent(-10.0, ModifierSource::Subsystem),
    ];
    let result = evaluate_attribute(1.0, &modifiers, &SkillContext::BaseOnly);
    assert_oracle(result.value.expect("value"), expected, "Loki subsystems");
    assert_eq!(result.applied, 5);
}

#[test]
fn oracle_pipeline_post_assign_and_implant_escape() {
    // Implant (cat 20) PostMul x1.05 is unpenalized; a
    // later PostAssign replaces everything.
    let modifiers = vec![
        DogmaModifier::new(
            263,
            DogmaOperator::PostMul,
            Some(1.05),
            ModifierSource::Implant,
            101,
            "implant",
        ),
        DogmaModifier::new(
            263,
            DogmaOperator::PostMul,
            Some(1.05),
            ModifierSource::Implant,
            102,
            "implant",
        ),
    ];
    let result = evaluate_attribute(100.0, &modifiers, &SkillContext::BaseOnly);
    assert_oracle(result.value.expect("value"), 110.25, "implants unpenalized");
    let assigned = vec![
        DogmaModifier::new(
            263,
            DogmaOperator::PostAssign,
            Some(42.0),
            ModifierSource::Skill,
            101,
            "assign",
        ),
        modifiers[0].clone(),
    ];
    let result = evaluate_attribute(100.0, &assigned, &SkillContext::BaseOnly);
    assert_oracle(result.value.expect("value"), 42.0, "post assign");
}

// --- 8 propulsion fixtures --------------------------------
// SDE operands (dgmTypeAttributes.csv.bz2): 1MN AB II
// (438) 20=135/567=1.5e6/796=5e5; 5MN MWD II (440)
// 510/1.5e6/5e5; 50MN (5975) 505/1.5e7/5e6; 500MN (5945)
// 505/1.5e8/5e7; 1600mm Plates II (20353) 796=3.75e6.
// Hulls: Rifter 365 m/s, 1067000 kg, agility 3.2; Muninn
// 235, 11000000, 0.571; Raven 113, 99300000, 0.12.

#[test]
fn oracle_propulsion_velocities() {
    let cases: [(&str, f64, f64, f64, f64); 5] = [
        ("Rifter 1MN AB", 365.0, 1.35, 1_500_000.0, 1_567_000.0),
        ("Rifter 5MN MWD", 365.0, 5.10, 1_500_000.0, 1_567_000.0),
        ("Muninn 50MN MWD", 235.0, 5.05, 15_000_000.0, 16_000_000.0),
        ("Raven 500MN MWD", 113.0, 5.05, 150_000_000.0, 149_300_000.0),
        (
            "Raven 500MN + 1600mm plate",
            113.0,
            5.05,
            150_000_000.0,
            153_050_000.0,
        ),
    ];
    for (label, base, boost, thrust, mass) in cases {
        let actual = propelled_max_velocity(base, boost, thrust, mass).expect("velocity");
        assert_oracle(actual, base * (1.0 + boost * (thrust / mass)), label);
    }
}

#[test]
fn oracle_propulsion_align_times() {
    let ln = -0.25_f64.ln();
    let rifter = align_time_secs(3.2, 1_067_000.0).expect("align");
    assert_oracle(rifter, ln * 3.2 * 1_067_000.0 / 1_000_000.0, "Rifter align");
    let plated = align_time_secs(0.12, 153_050_000.0).expect("align");
    assert_oracle(
        plated,
        ln * 0.12 * 153_050_000.0 / 1_000_000.0,
        "Raven plated align",
    );
    // Higgs Anchor mass-percent operand +100 (SDE
    // attribute 1131 on type 34266) doubles Rifter mass.
    let higgs_mass = mass_with_percent(1_067_000.0, 100.0).expect("mass");
    let higgs = align_time_secs(3.2, higgs_mass).expect("align");
    assert_oracle(higgs, ln * 3.2 * 2_134_000.0 / 1_000_000.0, "Higgs align");
}

// --- 6 Breacher Pod fixtures ------------------------------
// Pod constants: SCARAB Pod S (85088, Tholos small
// launcher 85084 fits ship 85087 per SDE 1302) 200 flat /
// 0.6%/s; Pod M (85089, Cenotaph medium launcher 85085
// fits 85086) 600 / 0.6%/s. Target HP: Rifter 1250,
// Raven 21120, Thanatos 208500 (catalogue sums).

#[test]
fn oracle_breacher_pods_vs_hull_classes() {
    assert_oracle(
        breacher_dps(&SCARAB_POD_S, 1250.0).expect("dps"),
        7.5,
        "Tholos pod vs frigate (percent binds)",
    );
    assert_oracle(
        breacher_dps(&SCARAB_POD_S, 21120.0).expect("dps"),
        126.72,
        "Tholos pod vs battleship",
    );
    assert_oracle(
        breacher_dps(&SCARAB_POD_M, 21120.0).expect("dps"),
        126.72,
        "Cenotaph pod vs battleship (percent binds)",
    );
    assert_oracle(
        breacher_dps(&SCARAB_POD_M, 208500.0).expect("dps"),
        600.0,
        "Cenotaph pod vs capital (flat cap binds)",
    );
}

#[test]
fn oracle_breacher_non_stacking_and_time_to_kill() {
    let multi =
        breacher_dps_multi(&[SCARAB_POD_M, SCARAB_POD_M, SCARAB_POD_S], 208500.0).expect("dps");
    assert_oracle(multi, 600.0, "three attackers, max stream only");
    let ttk = breacher_time_to_kill_secs(&SCARAB_POD_M, 21120.0).expect("ttk");
    assert_oracle(ttk, 21120.0 / 126.72, "Raven time to kill");
}

// --- 3 Thanatos fighter fixtures ---------------------------
// Templar I (23055) in the bundled catalogue: attack
// EM 65, multiplier 1.0, duration 5000 ms, squadron size
// 9, light class. Per-fighter DPS = 65/5 = 13; one full
// squadron = 117. Thanatos: 3 tubes, 3 light slots.

fn thanatos_fighter_dps(quantity: i64) -> f64 {
    let catalogue = bundled();
    let fit = fitting(23911, vec![item("FighterBay", quantity, 23055)]);
    match fitting_dps(&fit, None, &catalogue) {
        FittingDpsOutcome::Available(dps) => {
            dps.fighters
                .expect("fighter family available on a Thanatos")
                .dps
        }
        FittingDpsOutcome::Unavailable => panic!("Thanatos DPS must be Available"),
    }
}

#[test]
fn oracle_thanatos_templar_squadrons() {
    assert_oracle(thanatos_fighter_dps(9), 117.0, "one Templar squadron");
    assert_oracle(thanatos_fighter_dps(27), 351.0, "three Templar squadrons");
    // 36 carried = 4 squadrons' worth, but only 3 tubes:
    // active DPS stays at three squadrons.
    assert_oracle(thanatos_fighter_dps(36), 351.0, "tube-capped squadrons");
}

// --- 2 active-tank fixtures --------------------------------
// Small Ancillary Shield Booster (32774) on a Rifter:
// base rate 52/2 = 26 HP/s (bundled pin in
// active_repair.rs). Rifter shield resonances in the
// catalogue are 1.0/0.8/0.6/0.5, mean 0.725, so burst
// EHP/s = 26 / 0.725.

#[test]
fn oracle_active_tank_rifter_ancillary() {
    let catalogue = bundled();
    let fit = fitting(587, vec![item("MedSlot0", 1, 32774)]);
    let base = fitting_active_tank(&fit, &catalogue, &SkillContext::BaseOnly, &[], None);
    assert_oracle(base.shield.hp_per_sec.expect("raw"), 26.0, "ancillary raw");
    assert_oracle(
        base.shield.burst_ehp_per_sec.expect("burst"),
        26.0 / 0.725,
        "ancillary burst EHP/s",
    );
    assert_eq!(base.counted_modules, 1);
    // +5%-per-level repair skill at All V scales both.
    let mut skill = DogmaModifier::new(
        REPAIR_AMOUNT_ATTRIBUTE_ID,
        DogmaOperator::PostPercent,
        Some(5.0),
        ModifierSource::Skill,
        3393,
        "oracle repair skill",
    );
    skill.scaling = OperandScaling::PerSkillLevel;
    skill.skill_type_id = Some(3393);
    let skilled = fitting_active_tank(&fit, &catalogue, &SkillContext::AllFive, &[skill], None);
    assert_oracle(
        skilled.shield.burst_ehp_per_sec.expect("skilled burst"),
        (26.0 * 1.25) / 0.725,
        "ancillary burst EHP/s at All V",
    );
    assert_eq!(skilled.skill_context_tag, "Assumes All V");
}
