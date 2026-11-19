//! Pure ship base peak recharge rate calculation over base stats.
//!
//! [`ship_base_peak_recharge`] derives the peak shield recharge rate
//! in HP/s and the peak capacitor recharge rate in GJ/s for one
//! hull from the base (unmodified) capacity and full recharge
//! durations already carried on [`ShipBaseStats`]. Both rates are
//! arithmetic on those base values only. See
//! `docs/peak-recharge-rates-design.md`.
//!
//! No modifier of any kind is applied by `ship_base_peak_recharge`:
//! fitted modules, rigs, subsystems, skills, implants, and
//! ship bonuses contribute nothing, so the values describe the
//! bare hull and can differ from EVE. `capacitor_peak_recharge`
//! is the shared guarded capacitor formula at bonused inputs
//! under `docs/cap-bonuses-design.md`. `shield_peak_recharge`
//! is the shared guarded shield formula and
//! `ship_shield_peak_recharge_with_module_bonuses` is the
//! bonused consumer under
//! `docs/shield-recharge-bonuses-design.md`.
//!
//! The module is pure computation over already-loaded base stats —
//! no egui, no state, no network, no database. It logs nothing:
//! it runs at render cadence, so per-frame `[FITTING]` logging
//! would spam the log; the catalogue load already logs counts once.

use crate::esi::models::CharacterFitting;
use crate::fitting::ship_resistances::{bonused_hit_points, bonused_shield_recharge_duration};
use crate::fitting::ship_stats::ShipBaseStats;
use crate::names::fitting_types::FittingTypes;

/// Shield peak factor: peak shield recharge is
/// `2.5 * shield_capacity / shield_recharge_secs`.
///
/// Grounded in the Flutter production body at `ed698d3`,
/// `lib/features/fitting/domain/dogma_engine.dart:891-894`:
/// `2.5 * shieldHp / (shieldRecharge / 1000)` with the guard
/// `shieldRecharge > 0`. Bare-oracle equivalence: Flutter test
/// E2.8 (`dogma_engine_test.dart:1485-1492`) uses an empty fitting
/// with no skills, so base and adjusted coincide there.
const SHIELD_PEAK_FACTOR: f64 = 2.5;

/// Capacitor peak factor: peak capacitor recharge is
/// `2.5 * capacitor_capacity / capacitor_recharge_secs`.
///
/// Grounded independently of the shield constant, not by analogy:
/// differentiating the capacitor simulator's own closed form
/// `cap = ((1 + (sqrt(cap/C) - 1) * exp(-dt/tau))^2) * C`
/// (`cap_simulator.dart:73-75, 272-275` with `tau = rechargeMs / 5.0`
/// at `:116`) gives peak rate `0.5 * C / tau`, i.e. `2.5 * C / T`
/// for full recharge duration `T`. The two explicit test statements
/// in `cap_simulator_test.dart` (`:18-19` "2.5 * 1000 / 60 = 41.7
/// GJ/s" and `:75` "0.5 * 1000 / 12s = 41.7 GJ/s") corroborate the
/// same fixture. No charge-level percentage is stated in any body,
/// so no percentage is rendered.
const CAPACITOR_PEAK_FACTOR: f64 = 2.5;

/// One hull's base peak recharge rates. Each field is full-precision
/// `f64` HP/s or GJ/s from base capacity and base full recharge
/// duration only; `None` means that rate cannot honestly be
/// computed from the base stats: the caller omits it, never renders
/// a zero. Shield and capacitor availability are independent.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct ShipBasePeakRecharge {
    pub shield_hp_per_sec: Option<f64>,
    pub capacitor_gj_per_sec: Option<f64>,
}

/// Peak rate for one system from its capacity, recharge duration in
/// seconds, and factor. Returns `None` unless both inputs are
/// finite with capacity `>= 0` and recharge `> 0`, and the result
/// is finite. A zero capacity with a positive recharge yields an
/// honest `Some(0.0)`.
fn peak_rate(capacity: Option<f64>, recharge_secs: Option<f64>, factor: f64) -> Option<f64> {
    let capacity = capacity.filter(|v| v.is_finite() && *v >= 0.0)?;
    let recharge_secs = recharge_secs.filter(|v| v.is_finite() && *v > 0.0)?;
    let rate = factor * capacity / recharge_secs;
    if rate.is_finite() {
        Some(rate)
    } else {
        None
    }
}

/// Capacitor peak recharge in GJ/s for one (capacity,
/// recharge duration in seconds) pair under the shipped
/// guards (`peak_rate` with `CAPACITOR_PEAK_FACTOR`):
/// `None` unless capacity is finite `>= 0`, recharge is
/// finite `> 0`, and the rate is finite.
pub(crate) fn capacitor_peak_recharge(
    capacity: Option<f64>,
    recharge_secs: Option<f64>,
) -> Option<f64> {
    peak_rate(capacity, recharge_secs, CAPACITOR_PEAK_FACTOR)
}

/// Shield peak recharge in HP/s for one (shield hit
/// points, recharge duration in seconds) pair under the
/// shipped guards (`peak_rate` with `SHIELD_PEAK_FACTOR`):
/// `None` unless capacity is finite `>= 0`, recharge is
/// finite `> 0`, and the rate is finite.
pub(crate) fn shield_peak_recharge(
    capacity: Option<f64>,
    recharge_secs: Option<f64>,
) -> Option<f64> {
    peak_rate(capacity, recharge_secs, SHIELD_PEAK_FACTOR)
}

/// Base peak recharge rates for one hull's base stats. The
/// catalogue is never read and no modifier is applied; availability
/// is per-system and independent of every other fitting block.
pub fn ship_base_peak_recharge(stats: &ShipBaseStats) -> ShipBasePeakRecharge {
    ShipBasePeakRecharge {
        shield_hp_per_sec: shield_peak_recharge(stats.shield_capacity, stats.shield_recharge_secs),
        capacitor_gj_per_sec: capacitor_peak_recharge(
            stats.capacitor_capacity,
            stats.capacitor_recharge_secs,
        ),
    }
}

/// Bonused shield peak recharge plus the fitted-module
/// counts the caller must disclose beside it
/// (`docs/shield-recharge-bonuses-design.md` section 4).
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct BonusedShieldPeakRecharge {
    /// Peak passive shield recharge in HP/s from bonused
    /// shield hit points over bonused shield recharge
    /// duration. A plain `f64`: an `Available` result
    /// always carries the peak it exists to show,
    /// including an honest `0.0` from a real-zero bonused
    /// numerator over a positive duration.
    pub shield_hp_per_sec: f64,
    /// Counted fitted rows with no catalogue row at all,
    /// from `bonused_shield_recharge_duration`. Same
    /// definition, units, and source predicate as
    /// `BonusedShipEhp::excluded_modules`.
    pub excluded_modules: usize,
    /// Hit-point-dimension count, verbatim from
    /// `bonused_hit_points`. Whole-dimension (any of
    /// shield/armor/hull), as that helper defines it;
    /// never summed with
    /// `shield_recharge_unapplied_modules`.
    pub hit_point_unapplied_modules: usize,
    /// Shield-recharge-dimension count, from
    /// `bonused_shield_recharge_duration`. Never summed
    /// with `hit_point_unapplied_modules` or any
    /// resistance/capacitor count.
    pub shield_recharge_unapplied_modules: usize,
}

/// Bonused shield peak recharge outcome for one fitting.
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum BonusedShieldPeakRechargeOutcome {
    Available(BonusedShieldPeakRecharge),
    /// The ship gate failed, or either bonused input is
    /// absent, negative, non-finite, or a positive
    /// subnormal, or the bonused shield recharge duration
    /// is zero, or the peak rate is non-finite, so no
    /// honest number exists.
    Unavailable,
}

/// Bonused shield peak recharge for one fitting
/// (`docs/shield-recharge-bonuses-design.md` section 4).
/// Never panics; there is no error channel.
pub fn ship_shield_peak_recharge_with_module_bonuses(
    fitting: &CharacterFitting,
    catalogue: &FittingTypes,
) -> BonusedShieldPeakRechargeOutcome {
    let Some(hit_points) = bonused_hit_points(fitting, catalogue) else {
        return BonusedShieldPeakRechargeOutcome::Unavailable;
    };
    let Some(duration) = bonused_shield_recharge_duration(fitting, catalogue) else {
        return BonusedShieldPeakRechargeOutcome::Unavailable;
    };
    let shield_hp = hit_points.hit_points[0]
        .filter(|v| v.is_finite() && *v >= 0.0 && (*v == 0.0 || v.is_normal()));
    let bonused_recharge_ms = duration.recharge_ms.filter(|v| v.is_finite() && *v > 0.0);
    let (Some(shield_hp), Some(bonused_recharge_ms)) = (shield_hp, bonused_recharge_ms) else {
        return BonusedShieldPeakRechargeOutcome::Unavailable;
    };
    let recharge_secs = bonused_recharge_ms / 1000.0;
    let Some(shield_hp_per_sec) = shield_peak_recharge(Some(shield_hp), Some(recharge_secs)) else {
        return BonusedShieldPeakRechargeOutcome::Unavailable;
    };
    BonusedShieldPeakRechargeOutcome::Available(BonusedShieldPeakRecharge {
        shield_hp_per_sec,
        excluded_modules: duration.excluded_modules,
        hit_point_unapplied_modules: hit_points.hit_point_unapplied_modules,
        shield_recharge_unapplied_modules: duration.shield_recharge_unapplied_modules,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::esi::models::{CharacterFitting, FittingItem};
    use crate::fitting::ship_resistances::{bonused_hit_points, bonused_shield_recharge_duration};
    use crate::fitting::ship_stats::{ship_base_stats, ShipBaseStatsOutcome};
    use crate::names::fitting_types::FittingTypes;

    fn fitting(ship_type_id: i64) -> CharacterFitting {
        CharacterFitting {
            fitting_id: 1,
            name: "test".to_string(),
            description: None,
            ship_type_id,
            items: vec![],
        }
    }

    fn fitting_with_items(ship_type_id: i64, items: Vec<FittingItem>) -> CharacterFitting {
        CharacterFitting {
            fitting_id: 1,
            name: "test".to_string(),
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

    fn bundled() -> FittingTypes {
        FittingTypes::load_bundled().expect("bundled catalogue loads")
    }

    fn available(result: ShipBaseStatsOutcome) -> ShipBaseStats {
        match result {
            ShipBaseStatsOutcome::Available(stats) => stats,
            ShipBaseStatsOutcome::Unavailable => panic!("expected Available, got Unavailable"),
        }
    }

    /// Hand-derived rate with divisions shown; uniform `1e-9`
    /// absolute tolerance per design section 6 (resistances
    /// precedent), including for the exactly-representable 5.0 /
    /// 6.25 so the tolerance discipline cannot rot.
    fn assert_rate_close(actual: Option<f64>, expected: f64, label: &str) {
        match actual {
            Some(value) => assert!(
                (value - expected).abs() < 1e-9,
                "{label}: expected {expected}, got {value}"
            ),
            None => panic!("{label}: expected Some({expected}), got None"),
        }
    }

    fn base_stats(
        shield_capacity: Option<f64>,
        shield_recharge_secs: Option<f64>,
        capacitor_capacity: Option<f64>,
        capacitor_recharge_secs: Option<f64>,
    ) -> ShipBaseStats {
        ShipBaseStats {
            shield_capacity,
            armor_hp: Some(999.0),
            hull_hp: Some(888.0),
            capacitor_capacity,
            max_velocity: Some(777.0),
            shield_recharge_secs,
            capacitor_recharge_secs,
        }
    }

    // Oracle rows from the bundled catalogue via the #578/#581
    // pinned inputs (ship_stats.rs:137-139, 167-179):
    // Rifter 587: shield 450.0 HP, capacitor 250.0 GJ,
    // shield 625.0 s, capacitor 125.0 s.
    // Punisher 597: shield 350.0 HP, capacitor 400.0 GJ,
    // shield 625.0 s, capacitor 160.0 s.
    // Divisions shown:
    //   Rifter shield: 2.5 * 450.0 / 625.0 = 1125.0 / 625.0 = 1.8 HP/s
    //   Rifter capacitor: 2.5 * 250.0 / 125.0 = 625.0 / 125.0 = 5.0 GJ/s
    //   Punisher shield: 2.5 * 350.0 / 625.0 = 875.0 / 625.0 = 1.4 HP/s
    //   Punisher capacitor: 2.5 * 400.0 / 160.0 = 1000.0 / 160.0 = 6.25 GJ/s
    // Rifter shield is the Flutter E2.8 bare oracle (base and
    // adjusted coincide there: no modifiers trained or fitted).
    #[test]
    fn rifter_oracle_matches_hand_derived_rates() {
        let catalogue = bundled();
        let stats = available(ship_base_stats(&fitting(587), &catalogue));
        let peaks = ship_base_peak_recharge(&stats);
        assert_rate_close(peaks.shield_hp_per_sec, 1.8, "Rifter shield peak");
        assert_rate_close(peaks.capacitor_gj_per_sec, 5.0, "Rifter capacitor peak");
    }

    #[test]
    fn punisher_oracle_matches_hand_derived_rates() {
        let catalogue = bundled();
        let stats = available(ship_base_stats(&fitting(597), &catalogue));
        let peaks = ship_base_peak_recharge(&stats);
        assert_rate_close(peaks.shield_hp_per_sec, 1.4, "Punisher shield peak");
        assert_rate_close(peaks.capacitor_gj_per_sec, 6.25, "Punisher capacitor peak");
    }

    // Capacitor comment fixture as a second pure oracle: capacity
    // 1000.0 GJ, recharge 60.0 s → 2.5 * 1000.0 / 60.0
    // = 2500.0 / 60.0 = 41.666... GJ/s, asserted within 1e-9 of
    // the unrounded quotient. The comments' rounded 41.7 is never
    // asserted as a literal.
    #[test]
    fn capacitor_comment_fixture_matches_formula_not_rounded_comment() {
        let stats = base_stats(None, None, Some(1000.0), Some(60.0));
        let peaks = ship_base_peak_recharge(&stats);
        assert_rate_close(
            peaks.capacitor_gj_per_sec,
            2500.0 / 60.0,
            "capacitor fixture",
        );
        assert_eq!(peaks.shield_hp_per_sec, None);
    }

    // Guard matrix (design section 2.3), shield system.
    #[test]
    fn shield_absent_capacity_is_none() {
        let stats = base_stats(None, Some(625.0), None, None);
        assert_eq!(ship_base_peak_recharge(&stats).shield_hp_per_sec, None);
    }

    #[test]
    fn shield_absent_recharge_is_none() {
        let stats = base_stats(Some(450.0), None, None, None);
        assert_eq!(ship_base_peak_recharge(&stats).shield_hp_per_sec, None);
    }

    #[test]
    fn shield_zero_recharge_is_none() {
        let stats = base_stats(Some(450.0), Some(0.0), None, None);
        assert_eq!(ship_base_peak_recharge(&stats).shield_hp_per_sec, None);
    }

    #[test]
    fn shield_zero_capacity_with_positive_recharge_is_zero() {
        let stats = base_stats(Some(0.0), Some(625.0), None, None);
        assert_eq!(ship_base_peak_recharge(&stats).shield_hp_per_sec, Some(0.0));
    }

    // Guard matrix, capacitor system.
    #[test]
    fn capacitor_absent_capacity_is_none() {
        let stats = base_stats(None, None, None, Some(125.0));
        assert_eq!(ship_base_peak_recharge(&stats).capacitor_gj_per_sec, None);
    }

    #[test]
    fn capacitor_absent_recharge_is_none() {
        let stats = base_stats(None, None, Some(250.0), None);
        assert_eq!(ship_base_peak_recharge(&stats).capacitor_gj_per_sec, None);
    }

    #[test]
    fn capacitor_zero_recharge_is_none() {
        let stats = base_stats(None, None, Some(250.0), Some(0.0));
        assert_eq!(ship_base_peak_recharge(&stats).capacitor_gj_per_sec, None);
    }

    #[test]
    fn capacitor_zero_capacity_with_positive_recharge_is_zero() {
        let stats = base_stats(None, None, Some(0.0), Some(125.0));
        assert_eq!(
            ship_base_peak_recharge(&stats).capacitor_gj_per_sec,
            Some(0.0)
        );
    }

    // Non-finite / negative inputs (direct construction): None.
    #[test]
    fn negative_nan_and_infinite_inputs_are_none() {
        let cases = [
            Some(-1.0),
            Some(f64::NAN),
            Some(f64::INFINITY),
            Some(f64::NEG_INFINITY),
        ];
        for bad in cases {
            let shield_bad_capacity = base_stats(bad, Some(625.0), None, None);
            assert_eq!(
                ship_base_peak_recharge(&shield_bad_capacity).shield_hp_per_sec,
                None,
                "shield capacity {bad:?}"
            );
            let shield_bad_recharge = base_stats(Some(450.0), bad, None, None);
            assert_eq!(
                ship_base_peak_recharge(&shield_bad_recharge).shield_hp_per_sec,
                None,
                "shield recharge {bad:?}"
            );
            let cap_bad_capacity = base_stats(None, None, bad, Some(125.0));
            assert_eq!(
                ship_base_peak_recharge(&cap_bad_capacity).capacitor_gj_per_sec,
                None,
                "capacitor capacity {bad:?}"
            );
            let cap_bad_recharge = base_stats(None, None, Some(250.0), bad);
            assert_eq!(
                ship_base_peak_recharge(&cap_bad_recharge).capacitor_gj_per_sec,
                None,
                "capacitor recharge {bad:?}"
            );
        }
    }

    // Overflow to a non-finite rate: None.
    #[test]
    fn overflow_to_non_finite_rate_is_none() {
        // 2.5 * f64::MAX / 1e-9 overflows to infinity.
        let stats = base_stats(Some(f64::MAX), Some(1e-9), Some(f64::MAX), Some(1e-9));
        let peaks = ship_base_peak_recharge(&stats);
        assert_eq!(peaks.shield_hp_per_sec, None);
        assert_eq!(peaks.capacitor_gj_per_sec, None);
    }

    // Per-system independence: shield complete with capacitor
    // absent yields exactly one Some, and the mirror.
    #[test]
    fn shield_complete_with_capacitor_absent_yields_one_some() {
        let stats = base_stats(Some(450.0), Some(625.0), None, None);
        let peaks = ship_base_peak_recharge(&stats);
        assert_rate_close(peaks.shield_hp_per_sec, 1.8, "shield only");
        assert_eq!(peaks.capacitor_gj_per_sec, None);
    }

    #[test]
    fn capacitor_complete_with_shield_absent_yields_one_some() {
        let stats = base_stats(None, None, Some(250.0), Some(125.0));
        let peaks = ship_base_peak_recharge(&stats);
        assert_eq!(peaks.shield_hp_per_sec, None);
        assert_rate_close(peaks.capacitor_gj_per_sec, 5.0, "capacitor only");
    }

    // Other base-stat fields do not affect peaks.
    #[test]
    fn armor_hull_and_velocity_do_not_affect_peaks() {
        let full = base_stats(Some(450.0), Some(625.0), Some(250.0), Some(125.0));
        let sparse = ShipBaseStats {
            shield_capacity: Some(450.0),
            armor_hp: None,
            hull_hp: None,
            capacitor_capacity: Some(250.0),
            max_velocity: None,
            shield_recharge_secs: Some(625.0),
            capacitor_recharge_secs: Some(125.0),
        };
        let different = ShipBaseStats {
            shield_capacity: Some(450.0),
            armor_hp: Some(1.0),
            hull_hp: Some(2.0),
            capacitor_capacity: Some(250.0),
            max_velocity: Some(3.0),
            shield_recharge_secs: Some(625.0),
            capacitor_recharge_secs: Some(125.0),
        };
        assert_eq!(
            ship_base_peak_recharge(&full),
            ship_base_peak_recharge(&sparse)
        );
        assert_eq!(
            ship_base_peak_recharge(&full),
            ship_base_peak_recharge(&different)
        );
    }

    // --- Bonused shield peak (docs/shield-recharge-bonuses-
    // design.md sections 4, 8) ---

    fn bonused_peak(fit: &CharacterFitting, catalogue: &FittingTypes) -> BonusedShieldPeakRecharge {
        match ship_shield_peak_recharge_with_module_bonuses(fit, catalogue) {
            BonusedShieldPeakRechargeOutcome::Available(bonused) => bonused,
            BonusedShieldPeakRechargeOutcome::Unavailable => {
                panic!("expected Available bonused peak, got Unavailable")
            }
        }
    }

    fn assert_f64_close(actual: f64, expected: f64, label: &str) {
        assert!(
            (actual - expected).abs() < 1e-9,
            "{label}: expected {expected}, got {actual}"
        );
    }

    #[test]
    fn oracle1_recharger_multiplier_only() {
        let catalogue = bundled();
        let fit = fitting_with_items(587, vec![item("MedSlot0", 1, 394)]);
        let bonused = bonused_peak(&fit, &catalogue);
        let duration = bonused_shield_recharge_duration(&fit, &catalogue).expect("helper Some");
        assert_eq!(duration.recharge_ms, Some(531250.0));
        assert_f64_close(bonused.shield_hp_per_sec, 1125.0 / 531.25, "Oracle 1 peak");
        assert_eq!(bonused.excluded_modules, 0);
        assert_eq!(bonused.hit_point_unapplied_modules, 0);
        assert_eq!(bonused.shield_recharge_unapplied_modules, 0);
    }

    #[test]
    fn oracle2_percent_only_relay_and_purger() {
        let catalogue = bundled();
        let relay_fit = fitting_with_items(587, vec![item("LoSlot0", 1, 2331)]);
        let relay = bonused_peak(&relay_fit, &catalogue);
        let relay_dur =
            bonused_shield_recharge_duration(&relay_fit, &catalogue).expect("helper Some");
        assert_eq!(relay_dur.recharge_ms, Some(500000.0));
        assert_f64_close(
            relay.shield_hp_per_sec,
            1125.0 / 500.0,
            "Oracle 2 relay peak",
        );
        assert_eq!(relay.excluded_modules, 0);
        assert_eq!(relay.hit_point_unapplied_modules, 0);
        assert_eq!(relay.shield_recharge_unapplied_modules, 0);

        let purger_fit = fitting_with_items(587, vec![item("RigSlot0", 1, 26084)]);
        let purger = bonused_peak(&purger_fit, &catalogue);
        let purger_dur =
            bonused_shield_recharge_duration(&purger_fit, &catalogue).expect("helper Some");
        assert_eq!(purger_dur.recharge_ms, Some(500000.0));
        assert_f64_close(
            purger.shield_hp_per_sec,
            1125.0 / 500.0,
            "Oracle 2 purger peak",
        );

        let two_fit = fitting_with_items(
            587,
            vec![item("RigSlot0", 1, 26084), item("RigSlot1", 1, 26084)],
        );
        let two = bonused_peak(&two_fit, &catalogue);
        let two_dur = bonused_shield_recharge_duration(&two_fit, &catalogue).expect("helper Some");
        assert_f64_close(
            two_dur.recharge_ms.unwrap(),
            400000.0,
            "Oracle 2 two purgers ms",
        );
        assert_f64_close(
            two.shield_hp_per_sec,
            1125.0 / 400.0,
            "Oracle 2 two purgers peak",
        );

        let stacked_fit = fitting_with_items(587, vec![item("RigSlot0", 2, 26084)]);
        let stacked = bonused_peak(&stacked_fit, &catalogue);
        assert_eq!(stacked.shield_hp_per_sec, two.shield_hp_per_sec);
    }

    #[test]
    fn oracle3_flux_coil_combo() {
        let catalogue = bundled();
        let fit = fitting_with_items(587, vec![item("LoSlot0", 1, 1256)]);
        let bonused = bonused_peak(&fit, &catalogue);
        let numerator = bonused_hit_points(&fit, &catalogue)
            .expect("helper Some")
            .hit_points[0];
        assert_eq!(numerator, Some(382.5));
        let duration = bonused_shield_recharge_duration(&fit, &catalogue).expect("helper Some");
        assert_eq!(duration.recharge_ms, Some(437500.0));
        assert_f64_close(bonused.shield_hp_per_sec, 956.25 / 437.5, "Oracle 3 peak");
    }

    #[test]
    fn oracle4_extender_combos() {
        let catalogue = bundled();
        let extender_fit = fitting_with_items(587, vec![item("MedSlot0", 1, 3831)]);
        let extender = bonused_peak(&extender_fit, &catalogue);
        let extender_dur =
            bonused_shield_recharge_duration(&extender_fit, &catalogue).expect("helper Some");
        assert_eq!(extender_dur.recharge_ms, Some(625000.0));
        assert_f64_close(extender.shield_hp_per_sec, 3875.0 / 625.0, "Oracle 4a peak");
        assert_eq!(extender.shield_recharge_unapplied_modules, 0);
        assert_eq!(extender.hit_point_unapplied_modules, 0);

        let both_fit = fitting_with_items(
            587,
            vec![item("MedSlot0", 1, 3831), item("MedSlot1", 1, 394)],
        );
        let both = bonused_peak(&both_fit, &catalogue);
        let both_dur =
            bonused_shield_recharge_duration(&both_fit, &catalogue).expect("helper Some");
        assert_eq!(both_dur.recharge_ms, Some(531250.0));
        assert_f64_close(both.shield_hp_per_sec, 3875.0 / 531.25, "Oracle 4b peak");

        let punisher_fit = fitting_with_items(597, vec![item("MedSlot0", 1, 394)]);
        let punisher = bonused_peak(&punisher_fit, &catalogue);
        let punisher_dur =
            bonused_shield_recharge_duration(&punisher_fit, &catalogue).expect("helper Some");
        assert_eq!(punisher_dur.recharge_ms, Some(531250.0));
        assert_f64_close(punisher.shield_hp_per_sec, 875.0 / 531.25, "Oracle 4c peak");
    }

    #[test]
    fn oracle5_slower_than_base() {
        let catalogue = bundled();
        let fit = fitting_with_items(587, vec![item("RigSlot0", 1, 4399)]);
        let bonused = bonused_peak(&fit, &catalogue);
        let duration = bonused_shield_recharge_duration(&fit, &catalogue).expect("helper Some");
        assert_eq!(duration.recharge_ms, Some(687500.0));
        assert_f64_close(bonused.shield_hp_per_sec, 1125.0 / 687.5, "Oracle 5 peak");
        assert!(bonused.shield_hp_per_sec < 1.8);
    }

    #[test]
    fn oracle6_four_family_row() {
        let catalogue = bundled();
        let fit = fitting_with_items(587, vec![item("LoSlot0", 1, 1541)]);
        let bonused = bonused_peak(&fit, &catalogue);
        let numerator = bonused_hit_points(&fit, &catalogue)
            .expect("helper Some")
            .hit_points[0];
        assert_eq!(numerator, Some(472.5));
        let duration = bonused_shield_recharge_duration(&fit, &catalogue).expect("helper Some");
        assert_eq!(duration.recharge_ms, Some(571875.0));
        assert_f64_close(
            bonused.shield_hp_per_sec,
            1181.25 / 571.875,
            "Oracle 6 peak",
        );
    }

    #[test]
    fn oracle7_absent_split_pin() {
        let catalogue = bundled();
        let fit = fitting_with_items(587, vec![item("LoSlot0", 1, 1445)]);
        let bonused = bonused_peak(&fit, &catalogue);
        let duration = bonused_shield_recharge_duration(&fit, &catalogue).expect("helper Some");
        assert_eq!(duration.recharge_ms, Some(625000.0));
        assert_eq!(duration.shield_recharge_unapplied_modules, 1);
        let numerator = bonused_hit_points(&fit, &catalogue).expect("helper Some");
        assert_eq!(numerator.hit_points[0], Some(450.0));
        assert_eq!(numerator.hit_point_unapplied_modules, 1);
        assert_eq!(bonused.excluded_modules, 0);
        assert_eq!(bonused.hit_point_unapplied_modules, 1);
        assert_eq!(bonused.shield_recharge_unapplied_modules, 1);
        // Peak equals base exactly (1.8-tier), compared via base fn not literal.
        let stats = available(ship_base_stats(&fit, &catalogue));
        let base_peak = ship_base_peak_recharge(&stats).shield_hp_per_sec;
        assert_eq!(Some(bonused.shield_hp_per_sec), base_peak);

        let stacked_fit = fitting_with_items(587, vec![item("LoSlot0", 2, 1445)]);
        let stacked = bonused_peak(&stacked_fit, &catalogue);
        assert_eq!(stacked.hit_point_unapplied_modules, 2);
        assert_eq!(stacked.shield_recharge_unapplied_modules, 2);
        assert_eq!(stacked.excluded_modules, 0);
    }

    #[test]
    fn empty_equals_base_exactly() {
        let catalogue = bundled();
        // Hull-only Rifter and Punisher
        for ship in [587, 597] {
            let fit = fitting(ship);
            let bonused = bonused_peak(&fit, &catalogue);
            let stats = available(ship_base_stats(&fit, &catalogue));
            let base_peak = ship_base_peak_recharge(&stats).shield_hp_per_sec;
            assert_eq!(Some(bonused.shield_hp_per_sec), base_peak, "ship {ship}");
            assert_eq!(bonused.excluded_modules, 0);
            assert_eq!(bonused.hit_point_unapplied_modules, 0);
            assert_eq!(bonused.shield_recharge_unapplied_modules, 0);
        }
        // Only non-counted items (cargo/charge/drone flags, quantity 0, type_id <=0)
        let fit = fitting_with_items(
            587,
            vec![
                item("Cargo", 5, 34),
                item("Hangar", 1, 1225),
                item("DroneBay", 5, 2456),
                item("MedSlot0", 0, 394),
                item("MedSlot0", 1, 0),
                item("MedSlot0", 1, -1),
            ],
        );
        let bonused = bonused_peak(&fit, &catalogue);
        let stats = available(ship_base_stats(&fit, &catalogue));
        let base_peak = ship_base_peak_recharge(&stats).shield_hp_per_sec;
        assert_eq!(Some(bonused.shield_hp_per_sec), base_peak);
        assert_eq!(bonused.excluded_modules, 0);
        assert_eq!(bonused.hit_point_unapplied_modules, 0);
        assert_eq!(bonused.shield_recharge_unapplied_modules, 0);
        // Counted double non-carrier (2048)
        let fit = fitting_with_items(
            587,
            vec![item("LoSlot0", 1, 2048), item("LoSlot1", 1, 2048)],
        );
        let bonused = bonused_peak(&fit, &catalogue);
        let stats = available(ship_base_stats(&fit, &catalogue));
        let base_peak = ship_base_peak_recharge(&stats).shield_hp_per_sec;
        assert_eq!(Some(bonused.shield_hp_per_sec), base_peak);
        // Identity carrier in both dimensions (1353)
        let fit = fitting_with_items(587, vec![item("LoSlot0", 1, 1353)]);
        let bonused = bonused_peak(&fit, &catalogue);
        let stats = available(ship_base_stats(&fit, &catalogue));
        let base_peak = ship_base_peak_recharge(&stats).shield_hp_per_sec;
        assert_eq!(Some(bonused.shield_hp_per_sec), base_peak);
        assert_eq!(bonused.excluded_modules, 0);
        assert_eq!(bonused.hit_point_unapplied_modules, 0);
        assert_eq!(bonused.shield_recharge_unapplied_modules, 0);
        // Demo fittings
        // Demo Brawler rows 2048/2049/1225/2050/2050/1535/28270
        let brawler = fitting_with_items(
            587,
            vec![
                item("LoSlot0", 1, 2048),
                item("LoSlot1", 1, 2049),
                item("HiSlot0", 1, 1225),
                item("HiSlot1", 1, 2050),
                item("HiSlot2", 1, 2050),
                item("MedSlot0", 1, 1535),
                item("RigSlot0", 1, 28270),
            ],
        );
        let brawler_bonused = bonused_peak(&brawler, &catalogue);
        let brawler_stats = available(ship_base_stats(&brawler, &catalogue));
        let brawler_base = ship_base_peak_recharge(&brawler_stats).shield_hp_per_sec;
        assert_eq!(Some(brawler_bonused.shield_hp_per_sec), brawler_base);
        assert_eq!(brawler_bonused.excluded_modules, 1);
        assert_eq!(brawler_bonused.hit_point_unapplied_modules, 0);
        assert_eq!(brawler_bonused.shield_recharge_unapplied_modules, 0);
        // Mission Runner
        let mission = fitting_with_items(
            587,
            vec![
                item("HiSlot0", 1, 2048),
                item("LoSlot0", 1, 2049),
                item("DroneBay", 3, 2456),
                item("Cargo", 10, 37),
            ],
        );
        let mission_bonused = bonused_peak(&mission, &catalogue);
        let mission_stats = available(ship_base_stats(&mission, &catalogue));
        let mission_base = ship_base_peak_recharge(&mission_stats).shield_hp_per_sec;
        assert_eq!(Some(mission_bonused.shield_hp_per_sec), mission_base);
        assert_eq!(mission_bonused.excluded_modules, 0);
        assert_eq!(mission_bonused.hit_point_unapplied_modules, 0);
        assert_eq!(mission_bonused.shield_recharge_unapplied_modules, 0);
        // Demo Runner (Punisher)
        let runner = fitting_with_items(
            597,
            vec![
                item("LoSlot0", 1, 2048),
                item("HiSlot0", 1, 2050),
                item("MedSlot0", 1, 1225),
                item("DroneBay", 3, 2456),
                item("Cargo", 20, 36),
            ],
        );
        let runner_bonused = bonused_peak(&runner, &catalogue);
        let runner_stats = available(ship_base_stats(&runner, &catalogue));
        let runner_base = ship_base_peak_recharge(&runner_stats).shield_hp_per_sec;
        assert_eq!(Some(runner_bonused.shield_hp_per_sec), runner_base);
        assert_eq!(runner_bonused.excluded_modules, 0);
    }

    #[test]
    fn shared_count_equalities() {
        let catalogue = bundled();
        let fit = fitting_with_items(
            587,
            vec![item("MedSlot0", 1, 394), item("LoSlot0", 1, 999999)],
        );
        let bonused = bonused_peak(&fit, &catalogue);
        let resistances = crate::fitting::ship_resistances::ship_resistances_with_module_bonuses(
            &fit, &catalogue,
        );
        if let crate::fitting::ship_resistances::BonusedShipResistancesOutcome::Available(r) =
            resistances
        {
            assert_eq!(bonused.excluded_modules, r.excluded_modules);
        }
        let cap_helper = crate::fitting::ship_resistances::bonused_capacitor(&fit, &catalogue)
            .expect("cap helper Some");
        assert_eq!(bonused.excluded_modules, cap_helper.excluded_modules);
        let hp_helper = bonused_hit_points(&fit, &catalogue).expect("hp helper Some");
        assert_eq!(
            bonused.hit_point_unapplied_modules,
            hp_helper.hit_point_unapplied_modules
        );
        let ehp = crate::fitting::ship_ehp::ship_ehp_with_module_bonuses(&fit, &catalogue);
        if let crate::fitting::ship_ehp::BonusedShipEhpOutcome::Available(e) = ehp {
            assert_eq!(
                bonused.hit_point_unapplied_modules,
                e.hit_point_unapplied_modules
            );
        }
        // Dimension guards: capacitor-unapplied only row leaves shield counts at own values and vice versa
        let cap_only = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":42,"typeName":"Fixture Hull","categoryId":6,"slotEffects":[],"shieldCapacity":450.0,"shieldRechargeRate":625000.0,"capacitorCapacity":250.0,"rechargeRate":125000.0},
                {"typeId":101,"typeName":"CapOnly","categoryId":7,"slotEffects":[11],"capacitorCapacityModifiers":[],"capacitorCapacityModifiersUnapplied":true}]}"#,
        )
        .expect("fixture parses");
        let fit = fitting_with_items(42, vec![item("LoSlot0", 1, 101)]);
        let bonused = bonused_peak(&fit, &cap_only);
        assert_eq!(bonused.hit_point_unapplied_modules, 0);
        assert_eq!(bonused.shield_recharge_unapplied_modules, 0);
        let sr_only = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":42,"typeName":"Fixture Hull","categoryId":6,"slotEffects":[],"shieldCapacity":450.0,"shieldRechargeRate":625000.0,"capacitorCapacity":250.0,"rechargeRate":125000.0},
                {"typeId":101,"typeName":"SrOnly","categoryId":7,"slotEffects":[13],"shieldRechargeModifiers":[],"shieldRechargeModifiersUnapplied":true}]}"#,
        )
        .expect("fixture parses");
        let fit = fitting_with_items(42, vec![item("MedSlot0", 1, 101)]);
        let bonused = bonused_peak(&fit, &sr_only);
        assert_eq!(bonused.hit_point_unapplied_modules, 0);
        assert_eq!(bonused.shield_recharge_unapplied_modules, 1);
    }

    #[test]
    fn whole_dimension_hit_point_count() {
        let catalogue = bundled();
        let fit = fitting_with_items(587, vec![item("LoSlot0", 1, 47817)]);
        let bonused = bonused_peak(&fit, &catalogue);
        let stats = available(ship_base_stats(&fit, &catalogue));
        let base_peak = ship_base_peak_recharge(&stats).shield_hp_per_sec;
        assert_eq!(Some(bonused.shield_hp_per_sec), base_peak);
        assert_eq!(bonused.excluded_modules, 0);
        assert_eq!(bonused.shield_recharge_unapplied_modules, 0);
        assert_eq!(bonused.hit_point_unapplied_modules, 1);
    }

    #[test]
    fn partial_and_coupled_unavailable() {
        // shieldCapacity absent, recharge present
        let catalogue = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":42,"typeName":"No Shield Hull","categoryId":6,"slotEffects":[],"shieldRechargeRate":625000.0},
                {"typeId":101,"typeName":"Extender","categoryId":7,"slotEffects":[13],"hitPointModifiers":[[263,2,1100.0]]},
                {"typeId":102,"typeName":"Recharger","categoryId":7,"slotEffects":[13],"shieldRechargeModifiers":[[479,4,0.85]]}]}"#,
        )
        .expect("fixture parses");
        let fit = fitting_with_items(42, vec![item("MedSlot0", 1, 101), item("MedSlot1", 1, 102)]);
        let numerator = bonused_hit_points(&fit, &catalogue).expect("hp Some");
        assert_eq!(numerator.hit_points[0], None);
        let duration = bonused_shield_recharge_duration(&fit, &catalogue).expect("dur Some");
        assert_eq!(duration.recharge_ms, Some(531250.0));
        assert_eq!(
            ship_shield_peak_recharge_with_module_bonuses(&fit, &catalogue),
            BonusedShieldPeakRechargeOutcome::Unavailable
        );
        let stats = ship_base_stats(&fit, &catalogue);
        let base_peak = match stats {
            ShipBaseStatsOutcome::Available(s) => ship_base_peak_recharge(&s).shield_hp_per_sec,
            ShipBaseStatsOutcome::Unavailable => None,
        };
        assert_eq!(base_peak, None);
        // Mirror: duration absent
        let catalogue = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":42,"typeName":"No Recharge Hull","categoryId":6,"slotEffects":[],"shieldCapacity":450.0},
                {"typeId":101,"typeName":"Extender","categoryId":7,"slotEffects":[13],"hitPointModifiers":[[263,2,1100.0]]},
                {"typeId":102,"typeName":"Recharger","categoryId":7,"slotEffects":[13],"shieldRechargeModifiers":[[479,4,0.85]]}]}"#,
        )
        .expect("fixture parses");
        let fit = fitting_with_items(42, vec![item("MedSlot0", 1, 101), item("MedSlot1", 1, 102)]);
        let numerator = bonused_hit_points(&fit, &catalogue).expect("hp Some");
        assert_eq!(numerator.hit_points[0], Some(1550.0));
        let duration = bonused_shield_recharge_duration(&fit, &catalogue).expect("dur Some");
        assert_eq!(duration.recharge_ms, None);
        assert_eq!(
            ship_shield_peak_recharge_with_module_bonuses(&fit, &catalogue),
            BonusedShieldPeakRechargeOutcome::Unavailable
        );
        // Present 0.0 shield capacity with extender
        let catalogue = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":42,"typeName":"Zero Shield Hull","categoryId":6,"slotEffects":[],"shieldCapacity":0.0,"shieldRechargeRate":625000.0},
                {"typeId":101,"typeName":"Extender","categoryId":7,"slotEffects":[13],"hitPointModifiers":[[263,2,1100.0]]}]}"#,
        )
        .expect("fixture parses");
        let fit = fitting_with_items(42, vec![item("MedSlot0", 1, 101)]);
        let numerator = bonused_hit_points(&fit, &catalogue).expect("hp Some");
        assert_eq!(numerator.hit_points[0], Some(1100.0));
        let bonused = bonused_peak(&fit, &catalogue);
        assert_f64_close(
            bonused.shield_hp_per_sec,
            2750.0 / 625.0,
            "zero+extender peak",
        );
        // Present 0.0 with no extender
        let fit = fitting_with_items(42, vec![]);
        let bonused = bonused_peak(&fit, &catalogue);
        assert_eq!(bonused.shield_hp_per_sec, 0.0);
        // Present 0.0 duration
        let catalogue = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":42,"typeName":"Zero Recharge Hull","categoryId":6,"slotEffects":[],"shieldCapacity":450.0,"shieldRechargeRate":0.0},
                {"typeId":101,"typeName":"Recharger","categoryId":7,"slotEffects":[13],"shieldRechargeModifiers":[[479,4,0.85]]}]}"#,
        )
        .expect("fixture parses");
        for items in [vec![], vec![item("MedSlot0", 1, 101)]] {
            let fit = fitting_with_items(42, items);
            let duration = bonused_shield_recharge_duration(&fit, &catalogue).expect("dur Some");
            assert_eq!(duration.recharge_ms, Some(0.0));
            assert_eq!(
                ship_shield_peak_recharge_with_module_bonuses(&fit, &catalogue),
                BonusedShieldPeakRechargeOutcome::Unavailable
            );
            let base = match ship_base_stats(&fit, &catalogue) {
                ShipBaseStatsOutcome::Available(s) => ship_base_peak_recharge(&s).shield_hp_per_sec,
                ShipBaseStatsOutcome::Unavailable => None,
            };
            assert_eq!(base, None);
        }
    }

    #[test]
    fn hostile_bounded() {
        let fixture_hull = r#"{"typeId":42,"typeName":"Fixture Hull","categoryId":6,"slotEffects":[],"shieldCapacity":450.0,"shieldRechargeRate":625000.0}"#;
        // percent -100 -> helper Some(0.0), public Unavailable, base still Some
        let catalogue = FittingTypes::from_json(
            &format!(r#"{{"types":[{fixture_hull},{{"typeId":101,"typeName":"Host","categoryId":7,"slotEffects":[13],"shieldRechargeModifiers":[[479,6,-100.0]]}}]}}"#),
        )
        .expect("fixture parses");
        let fit = fitting_with_items(42, vec![item("MedSlot0", 1, 101)]);
        let duration = bonused_shield_recharge_duration(&fit, &catalogue).expect("dur Some");
        assert_eq!(duration.recharge_ms, Some(0.0));
        assert_eq!(
            ship_shield_peak_recharge_with_module_bonuses(&fit, &catalogue),
            BonusedShieldPeakRechargeOutcome::Unavailable
        );
        let base = match ship_base_stats(&fit, &catalogue) {
            ShipBaseStatsOutcome::Available(s) => ship_base_peak_recharge(&s).shield_hp_per_sec,
            ShipBaseStatsOutcome::Unavailable => None,
        };
        assert!(base.is_some());
        assert_f64_close(base.unwrap(), 1.8, "base still 1.8-tier");
        // percent -150 -> helper None
        let catalogue = FittingTypes::from_json(
            &format!(r#"{{"types":[{fixture_hull},{{"typeId":101,"typeName":"Host","categoryId":7,"slotEffects":[13],"shieldRechargeModifiers":[[479,6,-150.0]]}}]}}"#),
        )
        .expect("fixture parses");
        let duration = bonused_shield_recharge_duration(&fit, &catalogue).expect("dur Some");
        assert_eq!(duration.recharge_ms, None);
        assert_eq!(
            ship_shield_peak_recharge_with_module_bonuses(&fit, &catalogue),
            BonusedShieldPeakRechargeOutcome::Unavailable
        );
        // mul -0.85 -> None
        let catalogue = FittingTypes::from_json(
            &format!(r#"{{"types":[{fixture_hull},{{"typeId":101,"typeName":"Host","categoryId":7,"slotEffects":[13],"shieldRechargeModifiers":[[479,4,-0.85]]}}]}}"#),
        )
        .expect("fixture parses");
        let duration = bonused_shield_recharge_duration(&fit, &catalogue).expect("dur Some");
        assert_eq!(duration.recharge_ms, None);
        // i64::MAX percent -20 -> helper None, public Unavailable
        let catalogue = FittingTypes::from_json(
            &format!(r#"{{"types":[{fixture_hull},{{"typeId":101,"typeName":"Host","categoryId":7,"slotEffects":[13],"shieldRechargeModifiers":[[479,6,-20.0]]}}]}}"#),
        )
        .expect("fixture parses");
        let fit_max = fitting_with_items(42, vec![item("RigSlot0", i64::MAX, 101)]);
        let duration = bonused_shield_recharge_duration(&fit_max, &catalogue).expect("dur Some");
        assert_eq!(duration.recharge_ms, None);
        assert_eq!(
            ship_shield_peak_recharge_with_module_bonuses(&fit_max, &catalogue),
            BonusedShieldPeakRechargeOutcome::Unavailable
        );
        // i64::MAX mul 0.85 -> helper None
        let catalogue = FittingTypes::from_json(
            &format!(r#"{{"types":[{fixture_hull},{{"typeId":101,"typeName":"Host","categoryId":7,"slotEffects":[13],"shieldRechargeModifiers":[[479,4,0.85]]}}]}}"#),
        )
        .expect("fixture parses");
        let fit_max = fitting_with_items(42, vec![item("MedSlot0", i64::MAX, 101)]);
        let duration = bonused_shield_recharge_duration(&fit_max, &catalogue).expect("dur Some");
        assert_eq!(duration.recharge_ms, None);
        assert_eq!(
            ship_shield_peak_recharge_with_module_bonuses(&fit_max, &catalogue),
            BonusedShieldPeakRechargeOutcome::Unavailable
        );
        // numerator-side mirror: i64::MAX -15% on 263 -> positive subnormal numerator, public Unavailable
        let catalogue = FittingTypes::from_json(
            &format!(r#"{{"types":[{fixture_hull},{{"typeId":101,"typeName":"Host","categoryId":7,"slotEffects":[13],"hitPointModifiers":[[263,6,-15.0]]}}]}}"#),
        )
        .expect("fixture parses");
        let fit_max = fitting_with_items(42, vec![item("MedSlot0", i64::MAX, 101)]);
        let numerator = bonused_hit_points(&fit_max, &catalogue).expect("hp Some");
        let sub = numerator.hit_points[0].expect("numerator Some subnormal");
        assert!(sub > 0.0 && !sub.is_normal(), "numerator subnormal {sub:?}");
        assert_eq!(
            ship_shield_peak_recharge_with_module_bonuses(&fit_max, &catalogue),
            BonusedShieldPeakRechargeOutcome::Unavailable
        );
        // numerator exact-zero companion: quantity 1 -100% on 263 -> Some(0.0), peak 0.0
        let catalogue = FittingTypes::from_json(
            &format!(r#"{{"types":[{fixture_hull},{{"typeId":101,"typeName":"Host","categoryId":7,"slotEffects":[13],"hitPointModifiers":[[263,6,-100.0]]}}]}}"#),
        )
        .expect("fixture parses");
        let fit = fitting_with_items(42, vec![item("MedSlot0", 1, 101)]);
        let numerator = bonused_hit_points(&fit, &catalogue).expect("hp Some");
        assert_eq!(numerator.hit_points[0], Some(0.0));
        let bonused = bonused_peak(&fit, &catalogue);
        assert_eq!(bonused.shield_hp_per_sec, 0.0);
        // i64::MAX op-2 add on 479 -> finite 625000+1000*(MAX as f64)
        let catalogue = FittingTypes::from_json(
            &format!(r#"{{"types":[{fixture_hull},{{"typeId":101,"typeName":"Host","categoryId":7,"slotEffects":[13],"shieldRechargeModifiers":[[479,2,1000.0]]}}]}}"#),
        )
        .expect("fixture parses");
        let fit_max = fitting_with_items(42, vec![item("MedSlot0", i64::MAX, 101)]);
        let duration = bonused_shield_recharge_duration(&fit_max, &catalogue).expect("dur Some");
        let expected = 625000.0 + 1000.0 * (i64::MAX as f64);
        assert_eq!(duration.recharge_ms, Some(expected));
        // rate overflow: 1e308 / 1.0 ms
        let catalogue = FittingTypes::from_json(
            r#"{"types":[{"typeId":42,"typeName":"Big Hull","categoryId":6,"slotEffects":[],"shieldCapacity":1e308,"shieldRechargeRate":1.0}]}"#,
        )
        .expect("fixture parses");
        let fit = fitting_with_items(42, vec![]);
        let duration = bonused_shield_recharge_duration(&fit, &catalogue).expect("dur Some");
        assert!(duration.recharge_ms.is_some());
        assert_eq!(
            ship_shield_peak_recharge_with_module_bonuses(&fit, &catalogue),
            BonusedShieldPeakRechargeOutcome::Unavailable
        );
        // wrapper pins
        assert_eq!(shield_peak_recharge(Some(0.0), Some(625.0)), Some(0.0));
        assert_eq!(shield_peak_recharge(Some(450.0), Some(0.0)), None);
        assert_eq!(shield_peak_recharge(Some(f64::MAX), Some(1e-9)), None);
    }

    #[test]
    fn runtime_guard_counts() {
        // marked-unapplied with applicable entry counted once, entry still applied
        let catalogue = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":42,"typeName":"Fixture Hull","categoryId":6,"slotEffects":[],"shieldCapacity":450.0,"shieldRechargeRate":625000.0},
                {"typeId":101,"typeName":"MarkedWithEntry","categoryId":7,"slotEffects":[13],"shieldRechargeModifiers":[[479,4,0.85]],"shieldRechargeModifiersUnapplied":true}]}"#,
        )
        .expect("fixture parses");
        let fit = fitting_with_items(42, vec![item("MedSlot0", 1, 101)]);
        let duration = bonused_shield_recharge_duration(&fit, &catalogue).expect("dur Some");
        assert_eq!(duration.shield_recharge_unapplied_modules, 1);
        assert_eq!(duration.recharge_ms, Some(531250.0));
        // operators 0,3,5,7 plus wrong id, zero, non-finite -> each counts once never twice
        let catalogue = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":42,"typeName":"Fixture Hull","categoryId":6,"slotEffects":[],"shieldCapacity":450.0,"shieldRechargeRate":625000.0},
                {"typeId":101,"typeName":"Bad","categoryId":7,"slotEffects":[13],"shieldRechargeModifiers":[[479,0,0.9],[479,3,0.9],[479,5,0.9],[479,7,0.9],[263,4,0.8],[479,4,0.0],[479,4,0.85]]}]}"#,
        )
        .expect("fixture parses");
        let fit = fitting_with_items(42, vec![item("MedSlot0", 1, 101)]);
        let duration = bonused_shield_recharge_duration(&fit, &catalogue).expect("dur Some");
        assert_eq!(duration.shield_recharge_unapplied_modules, 1);
        assert_eq!(duration.recharge_ms, Some(531250.0));
        // two bad entries on one item still count once
        let catalogue = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":42,"typeName":"Fixture Hull","categoryId":6,"slotEffects":[],"shieldCapacity":450.0,"shieldRechargeRate":625000.0},
                {"typeId":101,"typeName":"Bad2","categoryId":7,"slotEffects":[13],"shieldRechargeModifiers":[[479,0,0.9],[479,3,0.9]]}]}"#,
        )
        .expect("fixture parses");
        let fit = fitting_with_items(42, vec![item("MedSlot0", 1, 101)]);
        let duration = bonused_shield_recharge_duration(&fit, &catalogue).expect("dur Some");
        assert_eq!(duration.shield_recharge_unapplied_modules, 1);
        assert_eq!(duration.recharge_ms, Some(625000.0));
        // operator-2 fixture applies as flat add
        let catalogue = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":42,"typeName":"Fixture Hull","categoryId":6,"slotEffects":[],"shieldCapacity":450.0,"shieldRechargeRate":625000.0},
                {"typeId":101,"typeName":"Add","categoryId":7,"slotEffects":[13],"shieldRechargeModifiers":[[479,2,-50000.0]]}]}"#,
        )
        .expect("fixture parses");
        let fit = fitting_with_items(42, vec![item("MedSlot0", 1, 101)]);
        let duration = bonused_shield_recharge_duration(&fit, &catalogue).expect("dur Some");
        assert_eq!(duration.recharge_ms, Some(575000.0));
        assert_eq!(duration.shield_recharge_unapplied_modules, 0);
    }

    #[test]
    fn base_independence_regression() {
        let catalogue = bundled();
        let fit = fitting_with_items(587, vec![item("MedSlot0", 1, 394)]);
        // Base peak stays 1.8-tier, bonused moves
        let stats = available(ship_base_stats(&fit, &catalogue));
        let base = ship_base_peak_recharge(&stats);
        assert_f64_close(base.shield_hp_per_sec.unwrap(), 1.8, "base shield");
        assert_f64_close(base.capacitor_gj_per_sec.unwrap(), 5.0, "base cap");
        assert_ne!(
            bonused_peak(&fit, &catalogue).shield_hp_per_sec,
            base.shield_hp_per_sec.unwrap()
        );
        // ship_base_stats unaffected by fitting items
        let hull_only_stats = available(ship_base_stats(&fitting(587), &catalogue));
        assert_eq!(stats.shield_capacity, hull_only_stats.shield_capacity);
        // 394 moves no EHP
        let hull_ehp =
            crate::fitting::ship_ehp::ship_ehp_with_module_bonuses(&fitting(587), &catalogue);
        let fitted_ehp = crate::fitting::ship_ehp::ship_ehp_with_module_bonuses(&fit, &catalogue);
        assert_eq!(fitted_ehp, hull_ehp);
        // 3831 moves EHP numerator and peak together
        let extender_fit = fitting_with_items(587, vec![item("MedSlot0", 1, 3831)]);
        let _ehp =
            crate::fitting::ship_ehp::ship_ehp_with_module_bonuses(&extender_fit, &catalogue);
        let peak = bonused_peak(&extender_fit, &catalogue);
        assert_eq!(peak.shield_hp_per_sec, 2.5 * 1550.0 / 625.0);
        // resistances and capacitor functions still at shipped oracles (smoke: not Unavailable where expected)
        assert!(matches!(
            crate::fitting::ship_resistances::ship_resistances_with_module_bonuses(
                &fitting(587),
                &catalogue
            ),
            crate::fitting::ship_resistances::BonusedShipResistancesOutcome::Available(_)
        ));
        assert!(matches!(
            crate::fitting::ship_cap_stability::fitting_cap_stability_with_module_bonuses(
                &fitting_with_items(587, vec![item("MedSlot0", 1, 421)]),
                &catalogue
            )
            .outcome,
            crate::fitting::ship_cap_stability::CapStabilityOutcome::Stable { .. }
                | crate::fitting::ship_cap_stability::CapStabilityOutcome::Depletes { .. }
        ));
    }

    #[test]
    fn unavailable_shapes() {
        let catalogue = bundled();
        for ship in [999999, 2048, 0, -1] {
            let fit = fitting_with_items(ship, vec![item("MedSlot0", 1, 394)]);
            assert_eq!(
                ship_shield_peak_recharge_with_module_bonuses(&fit, &catalogue),
                BonusedShieldPeakRechargeOutcome::Unavailable,
                "ship {ship}"
            );
            assert!(bonused_shield_recharge_duration(&fit, &catalogue).is_none());
            assert!(bonused_hit_points(&fit, &catalogue).is_none());
        }
        // helper Some with recharge_ms None where base unusable
        let catalogue = FittingTypes::from_json(
            r#"{"types":[{"typeId":42,"typeName":"Bare Hull","categoryId":6,"slotEffects":[]}]}"#,
        )
        .expect("fixture parses");
        let fit = fitting_with_items(42, vec![]);
        let duration = bonused_shield_recharge_duration(&fit, &catalogue).expect("dur Some");
        assert_eq!(duration.recharge_ms, None);
    }
}
