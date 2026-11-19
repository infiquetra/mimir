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
//! under `docs/cap-bonuses-design.md`.
//!
//! The module is pure computation over already-loaded base stats —
//! no egui, no state, no network, no database. It logs nothing:
//! it runs at render cadence, so per-frame `[FITTING]` logging
//! would spam the log; the catalogue load already logs counts once.

use crate::fitting::ship_stats::ShipBaseStats;

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

/// Base peak recharge rates for one hull's base stats. The
/// catalogue is never read and no modifier is applied; availability
/// is per-system and independent of every other fitting block.
pub fn ship_base_peak_recharge(stats: &ShipBaseStats) -> ShipBasePeakRecharge {
    ShipBasePeakRecharge {
        shield_hp_per_sec: peak_rate(
            stats.shield_capacity,
            stats.shield_recharge_secs,
            SHIELD_PEAK_FACTOR,
        ),
        capacitor_gj_per_sec: capacitor_peak_recharge(
            stats.capacitor_capacity,
            stats.capacitor_recharge_secs,
        ),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::esi::models::CharacterFitting;
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
}
