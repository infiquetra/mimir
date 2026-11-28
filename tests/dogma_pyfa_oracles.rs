//! Independent reference fixtures for the pure Dogma
//! engine (#639, repair of P1-2).
//!
//! Every expected value below is a pinned NUMERIC LITERAL
//! derived by hand from bundled SDE operands
//! (`assets/sde/dogma.json` type attributes and
//! `assets/sde/effect_modifiers.json` effect rows, quoted
//! in each test) following Pyfa's published evaluator
//! algorithm (`eos/modifiedAttributeDict.py`: canonical
//! operator order, `boost` sharing the `multiply` penalty
//! group, penalized multipliers partitioned at 1.0). No
//! expectation restates engine code as an expression, so
//! a wrong formula fails here. Assertions use ONLY the
//! acceptance ceiling: 0.1% relative tolerance. Values
//! are independent hand arithmetic over SDE operands, not
//! captured Pyfa/EVE output (neither is runnable in this
//! environment); the derivation beside each literal is
//! the audit trail.
//!
//! Stacking effectiveness literals used in derivations:
//! S(1) = exp(-(1/2.67)^2) = 0.8691199808003975,
//! S(2) = 0.5705831435105602, S(3) = 0.28295515402326105.
//!
//! Fixture inventory (33): 6 pipeline, 8 velocity
//! (skills/traits/modules/subsystems/implants), 6 fitted
//! propulsion, 5 active tank, 5 Breacher Pod, 3 fighter.

use mimir::esi::models::{CharacterFitting, FittingItem};
use mimir::fitting::active_tank::fitting_active_tank_with_catalogue;
use mimir::fitting::breacher_dot::{
    breacher_dps, breacher_dps_multi, breacher_time_to_kill_secs, SCARAB_POD_M, SCARAB_POD_S,
};
use mimir::fitting::dogma_catalogue::{evaluate_ship_attribute, DogmaCatalogue, ATTR_MAX_VELOCITY};
use mimir::fitting::dogma_pipeline::{
    evaluate_attribute, DogmaModifier, DogmaOperator, ModifierSource, OperandScaling, SkillContext,
};
use mimir::fitting::dps::{fitting_dps, FittingDpsOutcome};
use mimir::fitting::propulsion::{fitting_propulsion, FittingPropulsionOutcome, PropulsionModule};
use mimir::names::fitting_types::FittingTypes;

fn bundled() -> FittingTypes {
    FittingTypes::load_bundled().expect("bundled catalogue loads")
}

fn dogma() -> DogmaCatalogue {
    DogmaCatalogue::load_bundled().expect("bundled dogma loads")
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

/// The acceptance assertion: 0.1% relative tolerance and
/// nothing tighter. `expected` is always a pinned literal.
fn assert_oracle(actual: f64, expected: f64, label: &str) {
    let tolerance = expected.abs() * 0.001;
    assert!(
        (actual - expected).abs() <= tolerance,
        "{label}: expected {expected}, got {actual} (outside 0.1%)"
    );
}

// --- Pipeline fixtures (6) --------------------------------

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
fn oracle_mixed_sign_stacking_splits_at_one() {
    // Pyfa partitions penalized multipliers into >1 and
    // <1 chains. Module -50% with module +10%: each is
    // first in its own chain -> 0.5 * 1.1 = 0.55 exactly.
    // (A single mixed chain would give 0.5435.)
    let modifiers = vec![
        percent(-50.0, ModifierSource::Module),
        percent(10.0, ModifierSource::Module),
    ];
    let result = evaluate_attribute(1.0, &modifiers, &SkillContext::BaseOnly);
    assert_oracle(result.value.expect("value"), 0.55, "mixed-sign split");
}

#[test]
fn oracle_post_mul_and_percent_share_penalty_group() {
    // Module PostMul x1.1 plus module PostPercent +10%
    // share one bonus chain: 1.1 * (1 + 0.1 * S(1))
    // = 1.1 * 1.0869119980800398 = 1.1956031978880437.
    // Separate chains would give 1.21.
    let modifiers = vec![
        DogmaModifier::new(
            263,
            DogmaOperator::PostMul,
            Some(1.1),
            ModifierSource::Module,
            101,
            "mul",
        ),
        percent(10.0, ModifierSource::Module),
    ];
    let result = evaluate_attribute(1.0, &modifiers, &SkillContext::BaseOnly);
    assert_oracle(
        result.value.expect("value"),
        1.1956031978880437,
        "shared penalty group",
    );
}

#[test]
fn oracle_three_module_penalty_chain() {
    // Three module -50% on one attribute:
    // 0.5 * (1 - 0.5*S(1)) * (1 - 0.5*S(2))
    // = 0.5 * 0.5654400095998013 * 0.7147084282447199
    // = 0.20206237026387663.
    let modifiers = vec![
        percent(-50.0, ModifierSource::Module),
        percent(-50.0, ModifierSource::Module),
        percent(-50.0, ModifierSource::Module),
    ];
    let result = evaluate_attribute(1.0, &modifiers, &SkillContext::BaseOnly);
    assert_oracle(
        result.value.expect("value"),
        0.20206237026387663,
        "three-module chain",
    );
}

#[test]
fn oracle_canonical_order_literal() {
    // 100 -> PreMul x2 = 200 -> ModAdd +50 = 250 ->
    // PostPercent +10% (skill) = 275.
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
fn oracle_skill_per_level_literal() {
    // +4% per level at All V on base 250: 250 * 1.20 = 300.
    let mut skill = percent(4.0, ModifierSource::Skill);
    skill.scaling = OperandScaling::PerSkillLevel;
    skill.skill_type_id = Some(3300);
    let result = evaluate_attribute(250.0, &[skill], &SkillContext::AllFive);
    assert_oracle(result.value.expect("value"), 300.0, "skill per level");
}

#[test]
fn oracle_four_subsystem_chain_shape_literal() {
    // Hull trait -10% (unpenalized) with four subsystem
    // -10% (penalized chain): 0.9 * prod_i(1 - 0.1*S(i))
    // for i=0..3 = 0.6776675618205112.
    let modifiers = vec![
        percent(-10.0, ModifierSource::HullTrait),
        percent(-10.0, ModifierSource::Subsystem),
        percent(-10.0, ModifierSource::Subsystem),
        percent(-10.0, ModifierSource::Subsystem),
        percent(-10.0, ModifierSource::Subsystem),
    ];
    let result = evaluate_attribute(1.0, &modifiers, &SkillContext::BaseOnly);
    assert_oracle(
        result.value.expect("value"),
        0.6776675618205112,
        "four subsystems + hull trait",
    );
    assert_eq!(result.applied, 5);
}

// --- Velocity fixtures (8) --------------------------------
// SDE operands (dogma.json): Rifter (587) velocity 365;
// Navigation (3449) +5%/level (attr 315 = 5.0); Overdrive
// Injector II (1236) +12.5% (attr 1076); Nanofiber II
// (2605) +9.5% (attr 1076); Hoarder (651) velocity 130,
// trait +5%/Minmatar-Hauler level (attr 493 = 5.0); Loki
// (29990) velocity 185, shield 2500; Loki Propulsion -
// Intercalated Nanofibers (45620) +5%/level (attr 1450);
// Loki Defensive - Augmented Durability (45596) shield
// +600 flat (attr 263) and +5%/level (attr 1448 = 5.0,
// Minmatar Defensive Systems 30545); NN-602 implant
// (3096) +2% (attr 1076).

fn velocity_of(fit: &CharacterFitting, base: f64, skills: &SkillContext) -> f64 {
    evaluate_ship_attribute(fit, &dogma(), ATTR_MAX_VELOCITY, base, skills, &[])
        .evaluated
        .value
        .expect("velocity value")
}

#[test]
fn oracle_rifter_navigation_all_v_and_trained() {
    let fit = fitting(587, vec![]);
    // 365 * 1.25 = 456.25; 365 * 1.15 = 419.75.
    assert_oracle(
        velocity_of(&fit, 365.0, &SkillContext::AllFive),
        456.25,
        "Rifter Navigation V",
    );
    assert_oracle(
        velocity_of(&fit, 365.0, &SkillContext::Trained(vec![(3449, 3)])),
        419.75,
        "Rifter Navigation III",
    );
    assert_oracle(
        velocity_of(&fit, 365.0, &SkillContext::BaseOnly),
        365.0,
        "Rifter base only",
    );
}

#[test]
fn oracle_hoarder_hull_trait_all_v() {
    // 130 * 1.25 (hull trait) * 1.25 (Navigation) = 203.125.
    let fit = fitting(651, vec![]);
    assert_oracle(
        velocity_of(&fit, 130.0, &SkillContext::AllFive),
        203.125,
        "Hoarder trait + Navigation",
    );
}

#[test]
fn oracle_rifter_overdrives_and_nanofiber() {
    // One Overdrive: 365 * 1.125 = 410.625.
    let one = fitting(587, vec![item("LoSlot0", 1, 1236)]);
    assert_oracle(
        velocity_of(&one, 365.0, &SkillContext::BaseOnly),
        410.625,
        "one Overdrive",
    );
    // Two Overdrives: 365 * 1.125 * (1 + 0.125*S(1))
    // = 455.23529901452036.
    let two = fitting(
        587,
        vec![item("LoSlot0", 1, 1236), item("LoSlot1", 1, 1236)],
    );
    assert_oracle(
        velocity_of(&two, 365.0, &SkillContext::BaseOnly),
        455.23529901452036,
        "two Overdrives",
    );
    // One Nanofiber: 365 * 1.095 = 399.675.
    let nano = fitting(587, vec![item("LoSlot0", 1, 2605)]);
    assert_oracle(
        velocity_of(&nano, 365.0, &SkillContext::BaseOnly),
        399.675,
        "one Nanofiber",
    );
    // NN-602 implant: 365 * 1.02 = 372.3 (unpenalized).
    let implant = fitting(587, vec![item("ImplantSlot0", 1, 3096)]);
    assert_oracle(
        velocity_of(&implant, 365.0, &SkillContext::BaseOnly),
        372.3,
        "NN-602 implant",
    );
}

#[test]
fn oracle_loki_real_four_subsystem_fit() {
    // Real Loki with four fitted subsystems: Defensive
    // 45596, Offensive 45607, Propulsion 45620, Core
    // 45632. Velocity: 185 * 1.25 (propulsion subsystem)
    // * 1.25 (Navigation) = 289.0625. Shield capacity at
    // Minmatar Defensive Systems V (30545):
    // (2500 + 600) * 1.25 = 3875.
    let fit = fitting(
        29990,
        vec![
            item("SubSystemSlot0", 1, 45596),
            item("SubSystemSlot1", 1, 45607),
            item("SubSystemSlot2", 1, 45620),
            item("SubSystemSlot3", 1, 45632),
        ],
    );
    assert_oracle(
        velocity_of(&fit, 185.0, &SkillContext::AllFive),
        289.0625,
        "Loki 4-subsystem velocity All V",
    );
    let shield = evaluate_ship_attribute(
        &fit,
        &dogma(),
        263,
        2500.0,
        &SkillContext::Trained(vec![(30545, 5)]),
        &[],
    );
    assert_oracle(
        shield.evaluated.value.expect("shield value"),
        3875.0,
        "Loki defensive shield (2500+600) x1.25",
    );
}

// --- Fitted propulsion fixtures (6) -----------------------
// SDE operands: 1MN AB II (438) 135/1.5e6/5e5; 500MN
// (5945) 505/1.5e8/5e7; 50MN (5975) 505/1.5e7/5e6.
// Hulls: Rifter 365 m/s 1067000 kg; Muninn (12015)
// 235 m/s 11000000 kg; Raven (638) 113 m/s 99300000 kg.

fn propelled(fit: &CharacterFitting, module: &PropulsionModule, skills: &SkillContext) -> f64 {
    match fitting_propulsion(fit, &bundled(), &dogma(), module, skills) {
        FittingPropulsionOutcome::Available(result) => result.propelled_velocity,
        FittingPropulsionOutcome::Unavailable => panic!("propulsion must be Available"),
    }
}

#[test]
fn oracle_fitted_propulsion_literals() {
    let dogma = dogma();
    // Rifter, explicit 1MN AB inputs, bare hull:
    // 365 * (1 + 1.35 * 1500000/1567000) = 836.6815571155074.
    let ab = PropulsionModule::from_sde(135.0, 1_500_000.0, 500_000.0);
    assert_oracle(
        propelled(&fitting(587, vec![]), &ab, &SkillContext::BaseOnly),
        836.6815571155074,
        "Rifter 1MN AB fitted",
    );
    // Raven + fitted 1600mm plate (20353) under 500MN:
    // 113 * (1 + 5.05 * 1.5e8/153050000) = 672.2780137210062.
    let mwd500 = PropulsionModule::from_catalogue(&dogma, 5945).expect("500MN inputs");
    assert_oracle(
        propelled(
            &fitting(638, vec![item("LoSlot0", 1, 20353)]),
            &mwd500,
            &SkillContext::BaseOnly,
        ),
        672.2780137210062,
        "Raven plated 500MN fitted",
    );
    // Muninn under catalogue 50MN (5975), bare hull:
    // 235 * (1 + 5.05 * 1.5e7/1.6e7) = 1347.578125.
    let mwd50 = PropulsionModule::from_catalogue(&dogma, 5975).expect("50MN inputs");
    assert_oracle(
        propelled(&fitting(12015, vec![]), &mwd50, &SkillContext::BaseOnly),
        1347.578125,
        "Muninn 50MN fitted",
    );
    // Rifter + Overdrive + Nanofiber + fitted 1MN AB II
    // at All V (Navigation x1.25, Acceleration Control
    // boost 1.6875, velocity chain 1.2178871979480426):
    // 365 * 1.2178871979480426 * 1.25
    //   * (1 + 1.6875 * 1.5e6/1567000) = 1453.246862062505.
    let ab2 = PropulsionModule::from_catalogue(&dogma, 438).expect("1MN AB II inputs");
    let fast = fitting(
        587,
        vec![
            item("MedSlot0", 1, 438),
            item("LoSlot0", 1, 1236),
            item("LoSlot1", 1, 2605),
        ],
    );
    assert_oracle(
        propelled(&fast, &ab2, &SkillContext::AllFive),
        1453.246862062505,
        "Rifter OD+nano All V propelled",
    );
    // Higgs-fitted Rifter (rig 34266: mass x2, velocity
    // x0.25): 91.25 * (1 + 1.35 * 1.5e6/2634000)
    // = 161.40233485193622.
    assert_oracle(
        propelled(
            &fitting(587, vec![item("RigSlot0", 1, 34266)]),
            &ab,
            &SkillContext::BaseOnly,
        ),
        161.40233485193622,
        "Higgs Rifter propelled",
    );
    // Entangler-fitted Rifter (49099: mass x0.2, velocity
    // x0.05): 18.25 * (1 + 1.35 * 1.5e6/713400)
    // = 70.05298570227082.
    assert_oracle(
        propelled(
            &fitting(587, vec![item("MedSlot1", 1, 49099)]),
            &ab,
            &SkillContext::BaseOnly,
        ),
        70.05298570227082,
        "Entangler Rifter propelled",
    );
}

// --- Active-tank fixtures (5) -----------------------------
// Small Ancillary Shield Booster (32774): 52 HP / 2000 ms
// = 26 HP/s. Medium Armor Repairer II (3530): 368 HP /
// 12000 ms. Rifter shield resonances 1.0/0.8/0.6/0.5,
// mean 0.725. Repair Systems (3393): -5% cycle/level.
// Myrmidon (24700): +7.5% armor repair amount per
// Gallente Battlecruiser (33097) level.

#[test]
fn oracle_active_tank_per_layer_literals() {
    let catalogue = bundled();
    let dogma = dogma();
    let rifter = fitting(
        587,
        vec![item("MedSlot0", 1, 32774), item("LoSlot0", 1, 3530)],
    );
    let base = fitting_active_tank_with_catalogue(
        &rifter,
        &catalogue,
        &dogma,
        &SkillContext::BaseOnly,
        None,
    );
    // Burst shield EHP/s: 26 / 0.725 = 35.862068965517246.
    assert_oracle(
        base.shield.burst_ehp_per_sec.expect("shield burst"),
        35.862068965517246,
        "SASB burst EHP/s",
    );
    let all_five = fitting_active_tank_with_catalogue(
        &rifter,
        &catalogue,
        &dogma,
        &SkillContext::AllFive,
        None,
    );
    // Shield raw stays 26.0 at All V (Repair Systems is
    // armor/hull only); armor raw: (368/12) / 0.75
    // = 40.88888888888889.
    assert_oracle(
        all_five.shield.hp_per_sec.expect("shield raw"),
        26.0,
        "shield raw never Repair-Systems boosted",
    );
    assert_oracle(
        all_five.armor.hp_per_sec.expect("armor raw"),
        40.88888888888889,
        "armor raw cycle-scaled All V",
    );
    let myrmidon = fitting(24700, vec![item("LoSlot0", 1, 3530)]);
    // All V: 368 * 1.375 / 9 = 56.22222222222222.
    let myrm_all = fitting_active_tank_with_catalogue(
        &myrmidon,
        &catalogue,
        &dogma,
        &SkillContext::AllFive,
        None,
    );
    assert_oracle(
        myrm_all.armor.hp_per_sec.expect("myrmidon all V"),
        56.22222222222222,
        "Myrmidon armor All V",
    );
    // Trained IV/IV: 368 * 1.30 / (12 * 0.80)
    // = 49.83333333333333.
    let myrm_trained = fitting_active_tank_with_catalogue(
        &myrmidon,
        &catalogue,
        &dogma,
        &SkillContext::Trained(vec![(33097, 4), (3393, 4)]),
        None,
    );
    assert_oracle(
        myrm_trained.armor.hp_per_sec.expect("myrmidon trained"),
        49.83333333333333,
        "Myrmidon armor Trained IV",
    );
    // BaseOnly: 368 / 12 = 30.666666666666668.
    let myrm_base = fitting_active_tank_with_catalogue(
        &myrmidon,
        &catalogue,
        &dogma,
        &SkillContext::BaseOnly,
        None,
    );
    assert_oracle(
        myrm_base.armor.hp_per_sec.expect("myrmidon base"),
        30.666666666666668,
        "Myrmidon armor BaseOnly",
    );
}

// --- Breacher Pod fixtures (5) ----------------------------
// Pod S (85088): 200 flat, 0.6%/s. Pod M (85089): 600
// flat, 0.6%/s. Targets: Rifter 1250 HP, Raven 21120 HP,
// Thanatos 208500 HP (catalogue layer sums).

#[test]
fn oracle_breacher_pod_literals() {
    // min(200, 0.006*1250) = 7.5; min(200, 0.006*21120)
    // = 126.72; min(600, 0.006*21120) = 126.72;
    // min(600, 0.006*208500) = 600.
    assert_oracle(
        breacher_dps(&SCARAB_POD_S, 1250.0).expect("dps"),
        7.5,
        "pod S frigate",
    );
    assert_oracle(
        breacher_dps(&SCARAB_POD_S, 21120.0).expect("dps"),
        126.72,
        "pod S battleship",
    );
    assert_oracle(
        breacher_dps(&SCARAB_POD_M, 21120.0).expect("dps"),
        126.72,
        "pod M battleship",
    );
    assert_oracle(
        breacher_dps(&SCARAB_POD_M, 208500.0).expect("dps"),
        600.0,
        "pod M capital flat cap",
    );
    // Non-stacking: max single stream wins; time to kill
    // 21120 / 126.72 = 166.66666666666666 s.
    assert_oracle(
        breacher_dps_multi(&[SCARAB_POD_M, SCARAB_POD_M, SCARAB_POD_S], 208500.0).expect("dps"),
        600.0,
        "three attackers non-stacking",
    );
    assert_oracle(
        breacher_time_to_kill_secs(&SCARAB_POD_M, 21120.0).expect("ttk"),
        166.66666666666666,
        "Raven time to kill",
    );
}

// --- Thanatos fighter fixtures (3) ------------------------
// Templar I (23055): 65 damage / 5 s = 13 DPS per
// fighter; squadron size 9; Thanatos 3 tubes.

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
    assert_oracle(thanatos_fighter_dps(36), 351.0, "tube-capped squadrons");
}
