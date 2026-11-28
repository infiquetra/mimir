//! Pure ship navigation and targeting base values calculation
//! over the bundled catalogue.
//!
//! [`ship_nav_targeting`] reads the hull's base warp speed,
//! align time, mass, signature radius, targeting range, scan
//! resolution, sensor strengths, and maximum locked targets
//! for one [`CharacterFitting`] from base (unmodified) dogma
//! attributes only. No modifier of any kind is applied: fitted
//! modules, rigs, subsystems, skills, implants, and ship
//! bonuses contribute nothing, so the values describe the bare
//! hull and can differ from EVE. See
//! `docs/nav-targeting-design.md`.
//!
//! [`ship_nav_targeting_with_module_bonuses`] applies the
//! fitted modules' and rigs' plain catalogue bonuses on the
//! eleven navigation and targeting attributes under
//! `docs/nav-targeting-bonuses-design.md`: the same base
//! values plus generation-time-proven `ItemModifier`/`shipID`
//! bonuses, with align time re-derived from the bonused
//! agility and mass. Max velocity, skills, implants,
//! subsystems, ship bonuses, and scripts are excluded, so
//! the numbers can differ from EVE.
//!
//! The module is pure computation over the bundled catalogue — no
//! egui, no state, no network, no database. It depends on
//! [`CharacterFitting`] and [`FittingTypes`], the same
//! dependencies `ship_stats.rs` takes. It logs nothing: it runs at
//! render cadence, so per-frame `[FITTING]` logging would spam
//! the log; the catalogue load already logs counts once.

use crate::esi::models::CharacterFitting;
use crate::names::fitting_types::FittingTypes;

/// Align-time factor: `-ln(0.25)`, the magnitude of the
/// natural log of one quarter, `ln(4)`.
///
/// Grounded in the Flutter production body at `ed698d3`,
/// `lib/features/fitting/domain/dogma_engine.dart`: align is
/// `-log(0.25) * agility * massKg / 1e6` seconds, where base
/// agility and base mass substitute for Flutter's post-modifier
/// `attr()` values. The `1e6` divisor carries the kg-to-nonstandard
/// scaling verbatim; no unit conversion lives here.
const ALIGN_TIME_FACTOR: f64 = 1.3862943611198906;

/// One hull's base navigation and targeting values. Each field
/// is the catalogue value when usable (present, finite,
/// non-negative; targeting range converted m → km, locked
/// targets as an integer count, align time derived from base
/// agility and base mass); a present `0.0` stays a real zero.
/// `None` means no data or not computable: the caller omits the
/// line, never renders a zero. Agility is align input data
/// only and carries no display line (design section 2.3).
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct ShipNavTargeting {
    /// Warp speed in AU/s under the dogma 1281 base-warp-speed
    /// invariant (design section 2.1).
    pub warp_speed: Option<f64>,
    /// Full align time in seconds, derived as
    /// `-ln(0.25) * agility * mass / 1_000_000`
    /// (design section 2.2).
    pub align_time_secs: Option<f64>,
    /// Inertia modifier, align input only, not displayed.
    pub agility: Option<f64>,
    /// Hull mass in kg (invTypes column, design section 2.4).
    pub mass: Option<f64>,
    /// Signature radius in m.
    pub signature_radius: Option<f64>,
    /// Targeting range in km (catalogue metres / 1000).
    pub max_target_range_km: Option<f64>,
    /// Scan resolution in mm.
    pub scan_resolution: Option<f64>,
    /// RADAR sensor strength in points.
    pub sensor_radar: Option<f64>,
    /// Ladar sensor strength in points.
    pub sensor_ladar: Option<f64>,
    /// Magnetometric sensor strength in points.
    pub sensor_magnetometric: Option<f64>,
    /// Gravimetric sensor strength in points.
    pub sensor_gravimetric: Option<f64>,
    /// Maximum locked targets, a bare integer count.
    pub max_locked_targets: Option<i64>,
}

/// Base navigation and targeting outcome for one fitting.
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum ShipNavTargetingOutcome {
    Available(ShipNavTargeting),
    /// The catalogue has no usable base navigation and
    /// targeting data for this fitting's ship, so no honest
    /// numbers exist.
    Unavailable,
}

/// A catalogue value is usable only when present, finite, and
/// non-negative. A present `0.0` stays a real zero; anything
/// else is treated as no data for that stat (`resources.rs`
/// uses the same rule for its dimensions).
fn usable(value: Option<f64>) -> Option<f64> {
    value.filter(|v| v.is_finite() && *v >= 0.0)
}

/// A catalogue count is usable only when present, finite,
/// non-negative, integral (`fract() == 0.0`), and at most
/// 2^53 (the largest consecutive integer an `f64` spells
/// exactly). A present `0.0` stays a real zero; anything else
/// — absent, negative, NaN, infinite, fractional, or beyond
/// exact-integer range — is no data for that stat, never a
/// rounded or clamped count (`slot_layout.rs` uses the same
/// rule for its dimensions).
fn usable_count(value: Option<f64>) -> Option<i64> {
    value
        .filter(|v| v.is_finite() && *v >= 0.0 && v.fract() == 0.0 && *v <= 9_007_199_254_740_992.0)
        .map(|v| v as i64)
}

/// A bonused count converts by the inspected Flutter rule,
/// not by `usable_count`: Flutter computes `attr(192)`
/// through the generic `(base + adds) × mul × percent`
/// composition and reads the stat as
/// `maxLockedTargets: attr(192).toInt()` (final stats block,
/// `dogma_engine.dart` at `ed698d3`; `models.dart` carries
/// it as an `int`), and Dart `double.toInt()` truncates
/// toward zero. A non-integral *computed* value therefore
/// truncates where a non-integral *catalogue* value stays
/// `None` under `usable_count`; a negative computed value
/// is filtered to `None` before conversion and never
/// truncates up to 0. The guards are the design's
/// post-modifier rule verbatim: finite, `>= 0.0`, exact
/// `0.0` or normal, and `<= 2^53` for cast safety.
fn bonused_count(value: Option<f64>) -> Option<i64> {
    value
        .filter(|v| {
            v.is_finite()
                && *v >= 0.0
                && (*v == 0.0 || v.is_normal())
                && *v <= 9_007_199_254_740_992.0
        })
        .map(|v| v as i64)
}

/// Align time in seconds from base agility and base mass:
/// `-ln(0.25) * agility * mass / 1_000_000`. Returns `Some`
/// only when both inputs are present, finite, and `> 0`
/// (Flutter's `0.0` sentinel for "not computable" is mapped
/// to absence, the peak-rate precedent) and the result is
/// finite; otherwise `None` and the line is omitted. The
/// inputs are re-checked here even though callers pass guarded
/// values, so no caller can smuggle a NaN into a rendered
/// line (the `ship_ehp` precedent).
fn align_time_secs(agility: Option<f64>, mass: Option<f64>) -> Option<f64> {
    let agility = agility.filter(|v| v.is_finite() && *v > 0.0)?;
    let mass = mass.filter(|v| v.is_finite() && *v > 0.0)?;
    let align = ALIGN_TIME_FACTOR * agility * mass / 1_000_000.0;
    if align.is_finite() {
        Some(align)
    } else {
        None
    }
}

/// Base navigation and targeting values for one fitting. The
/// fitting's items are never read, and availability is
/// independent of
/// [`crate::fitting::resources::FittingResources`],
/// [`crate::fitting::ship_stats::ShipBaseStats`], and every
/// other fitting block: this function keys off the eleven
/// base navigation and targeting catalogue fields only. The
/// derived align time never counts toward availability on its
/// own.
pub fn ship_nav_targeting(
    fitting: &CharacterFitting,
    catalogue: &FittingTypes,
) -> ShipNavTargetingOutcome {
    let ship_row = if fitting.ship_type_id > 0 {
        catalogue.lookup_by_id(fitting.ship_type_id)
    } else {
        None
    };
    let Some(ship) = ship_row else {
        return ShipNavTargetingOutcome::Unavailable;
    };
    if ship.category_id != 6 {
        return ShipNavTargetingOutcome::Unavailable;
    }
    let agility = usable(ship.agility);
    let mass = usable(ship.mass);
    let targeting = ShipNavTargeting {
        warp_speed: usable(ship.warp_speed_multiplier),
        align_time_secs: align_time_secs(agility, mass),
        agility,
        mass,
        signature_radius: usable(ship.signature_radius),
        max_target_range_km: usable(ship.max_target_range).map(|m| m / 1000.0),
        scan_resolution: usable(ship.scan_resolution),
        sensor_radar: usable(ship.scan_radar_strength),
        sensor_ladar: usable(ship.scan_ladar_strength),
        sensor_magnetometric: usable(ship.scan_magnetometric_strength),
        sensor_gravimetric: usable(ship.scan_gravimetric_strength),
        max_locked_targets: usable_count(ship.max_locked_targets),
    };
    if targeting.warp_speed.is_none()
        && targeting.agility.is_none()
        && targeting.mass.is_none()
        && targeting.signature_radius.is_none()
        && targeting.max_target_range_km.is_none()
        && targeting.scan_resolution.is_none()
        && targeting.sensor_radar.is_none()
        && targeting.sensor_ladar.is_none()
        && targeting.sensor_magnetometric.is_none()
        && targeting.sensor_gravimetric.is_none()
        && targeting.max_locked_targets.is_none()
    {
        return ShipNavTargetingOutcome::Unavailable;
    }
    ShipNavTargetingOutcome::Available(targeting)
}

/// Bonused navigation and targeting values plus the
/// counts the caller must disclose beside them.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct BonusedShipNavTargeting {
    pub targeting: ShipNavTargeting,
    /// Counted fitted rows with no catalogue row at all,
    /// so no navigation or targeting bonus can be proven
    /// or disproven for them, in quantity units.
    pub excluded_modules: usize,
    /// Counted fitted rows the catalogue marks as warp
    /// speed carriers whose bonus cannot be applied, in
    /// quantity units; never summed with any other count.
    pub warp_speed_unapplied_modules: usize,
    /// Counted fitted rows the catalogue marks as agility
    /// carriers whose bonus cannot be applied, in quantity
    /// units; never summed with any other count.
    pub agility_unapplied_modules: usize,
    /// Counted fitted rows the catalogue marks as mass
    /// carriers whose bonus cannot be applied, in quantity
    /// units; never summed with any other count.
    pub mass_unapplied_modules: usize,
    /// Counted fitted rows the catalogue marks as signature
    /// radius carriers whose bonus cannot be applied, in
    /// quantity units; never summed with any other count.
    pub signature_radius_unapplied_modules: usize,
    /// Counted fitted rows the catalogue marks as targeting
    /// range carriers whose bonus cannot be applied, in
    /// quantity units; never summed with any other count.
    pub max_target_range_unapplied_modules: usize,
    /// Counted fitted rows the catalogue marks as scan
    /// resolution carriers whose bonus cannot be applied, in
    /// quantity units; never summed with any other count.
    pub scan_resolution_unapplied_modules: usize,
    /// Counted fitted rows the catalogue marks as RADAR
    /// sensor strength carriers whose bonus cannot be
    /// applied, in quantity units; never summed with any
    /// other count.
    pub sensor_radar_unapplied_modules: usize,
    /// Counted fitted rows the catalogue marks as Ladar
    /// sensor strength carriers whose bonus cannot be
    /// applied, in quantity units; never summed with any
    /// other count.
    pub sensor_ladar_unapplied_modules: usize,
    /// Counted fitted rows the catalogue marks as
    /// Magnetometric sensor strength carriers whose bonus
    /// cannot be applied, in quantity units; never summed
    /// with any other count.
    pub sensor_magnetometric_unapplied_modules: usize,
    /// Counted fitted rows the catalogue marks as
    /// Gravimetric sensor strength carriers whose bonus
    /// cannot be applied, in quantity units; never summed
    /// with any other count.
    pub sensor_gravimetric_unapplied_modules: usize,
    /// Counted fitted rows the catalogue marks as max
    /// locked targets carriers whose bonus cannot be
    /// applied, in quantity units; never summed with any
    /// other count.
    pub max_locked_targets_unapplied_modules: usize,
}

#[allow(clippy::large_enum_variant)]
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum BonusedShipNavTargetingOutcome {
    Available(BonusedShipNavTargeting),
    Unavailable,
}

/// Bonused navigation and targeting values for one
/// fitting (`docs/nav-targeting-bonuses-design.md` section
/// 4). Never panics; a catalogue row that violates the
/// section 3 invariants at load is guarded here, never
/// trusted.
pub fn ship_nav_targeting_with_module_bonuses(
    fitting: &CharacterFitting,
    catalogue: &FittingTypes,
) -> BonusedShipNavTargetingOutcome {
    let Some(bonused) = crate::fitting::ship_resistances::bonused_nav_targeting(fitting, catalogue)
    else {
        return BonusedShipNavTargetingOutcome::Unavailable;
    };
    let agility = bonused.values[1];
    let mass = bonused.values[2];
    let targeting = ShipNavTargeting {
        warp_speed: bonused.values[0],
        align_time_secs: align_time_secs(agility, mass),
        agility,
        mass,
        signature_radius: bonused.values[3],
        max_target_range_km: bonused.values[4].map(|m| m / 1000.0),
        scan_resolution: bonused.values[5],
        sensor_radar: bonused.values[6],
        sensor_ladar: bonused.values[7],
        sensor_magnetometric: bonused.values[8],
        sensor_gravimetric: bonused.values[9],
        max_locked_targets: bonused_count(bonused.values[10]),
    };
    if targeting.warp_speed.is_none()
        && targeting.agility.is_none()
        && targeting.mass.is_none()
        && targeting.signature_radius.is_none()
        && targeting.max_target_range_km.is_none()
        && targeting.scan_resolution.is_none()
        && targeting.sensor_radar.is_none()
        && targeting.sensor_ladar.is_none()
        && targeting.sensor_magnetometric.is_none()
        && targeting.sensor_gravimetric.is_none()
        && targeting.max_locked_targets.is_none()
    {
        return BonusedShipNavTargetingOutcome::Unavailable;
    }
    BonusedShipNavTargetingOutcome::Available(BonusedShipNavTargeting {
        targeting,
        excluded_modules: bonused.excluded_modules,
        warp_speed_unapplied_modules: bonused.unapplied_modules[0],
        agility_unapplied_modules: bonused.unapplied_modules[1],
        mass_unapplied_modules: bonused.unapplied_modules[2],
        signature_radius_unapplied_modules: bonused.unapplied_modules[3],
        max_target_range_unapplied_modules: bonused.unapplied_modules[4],
        scan_resolution_unapplied_modules: bonused.unapplied_modules[5],
        sensor_radar_unapplied_modules: bonused.unapplied_modules[6],
        sensor_ladar_unapplied_modules: bonused.unapplied_modules[7],
        sensor_magnetometric_unapplied_modules: bonused.unapplied_modules[8],
        sensor_gravimetric_unapplied_modules: bonused.unapplied_modules[9],
        max_locked_targets_unapplied_modules: bonused.unapplied_modules[10],
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::esi::models::FittingItem;
    use crate::fitting::resources::fitting_resources;
    use crate::fitting::ship_resistances::bonused_nav_targeting;
    use crate::fitting::ship_stats::ship_base_stats;

    fn fitting(ship_type_id: i64, items: Vec<FittingItem>) -> CharacterFitting {
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

    fn available(result: ShipNavTargetingOutcome) -> ShipNavTargeting {
        match result {
            ShipNavTargetingOutcome::Available(targeting) => targeting,
            ShipNavTargetingOutcome::Unavailable => panic!("expected Available, got Unavailable"),
        }
    }

    fn bonused_available(result: BonusedShipNavTargetingOutcome) -> BonusedShipNavTargeting {
        match result {
            BonusedShipNavTargetingOutcome::Available(bonused) => bonused,
            BonusedShipNavTargetingOutcome::Unavailable => {
                panic!("expected Available, got Unavailable")
            }
        }
    }

    /// Hand-derived bonused oracle: absolute tolerance
    /// 1e-9 with literals carrying full f64 precision,
    /// each multiplied out in the comment beside it.
    fn assert_bonused_close(actual: Option<f64>, expected: f64, label: &str) {
        match actual {
            Some(value) => assert!(
                (value - expected).abs() < 1e-9,
                "{label}: expected {expected}, got {value}"
            ),
            None => panic!("{label}: expected Some({expected}), got None"),
        }
    }

    fn assert_all_unapplied_zero(bonused: &BonusedShipNavTargeting) {
        assert_eq!(bonused.warp_speed_unapplied_modules, 0);
        assert_eq!(bonused.agility_unapplied_modules, 0);
        assert_eq!(bonused.mass_unapplied_modules, 0);
        assert_eq!(bonused.signature_radius_unapplied_modules, 0);
        assert_eq!(bonused.max_target_range_unapplied_modules, 0);
        assert_eq!(bonused.scan_resolution_unapplied_modules, 0);
        assert_eq!(bonused.sensor_radar_unapplied_modules, 0);
        assert_eq!(bonused.sensor_ladar_unapplied_modules, 0);
        assert_eq!(bonused.sensor_magnetometric_unapplied_modules, 0);
        assert_eq!(bonused.sensor_gravimetric_unapplied_modules, 0);
        assert_eq!(bonused.max_locked_targets_unapplied_modules, 0);
    }

    /// Hand-derived align oracle: absolute tolerance 1e-9 with
    /// literals carrying full f64 precision, each multiplied
    /// out in the comment beside it.
    fn assert_align_close(actual: Option<f64>, expected: f64, label: &str) {
        match actual {
            Some(value) => assert!(
                (value - expected).abs() < 1e-9,
                "{label}: expected {expected}, got {value}"
            ),
            None => panic!("{label}: expected Some({expected}), got None"),
        }
    }

    // Oracle rows read from assets/sde/fitting_types.json,
    // confirmed against scripts/sde/dgmTypeAttributes.csv.bz2
    // and invTypes.csv.bz2 (design section 7):
    // Rifter 587: 600 5.0, 70 3.2, mass 1,067,000, 552 35.0,
    // 76 22,500, 564 660.0, sensors 0/8/0/0, 192 4.
    // Punisher 597: 5.0, 2.9, 1,190,000, 37.0, 25,000,
    // 640.0, 10/0/0/0, 4. Osprey 620: 4.0, 0.61, 11,100,000,
    // 95.0, 62,500, 280.0, 0/0/0/15, 8. Raven 638: 3.0, 0.12,
    // 99,300,000, 410.0, 90,000, 111.0, 0/0/0/22, 7.
    // Erebus 671: 1.5, 0.037, 2,100,000,000, 23,205.0,
    // 250,000, 65.0, 0/0/240/0, 8. Legion 29986: 4.0, 0.52,
    // 14,500,000, 170.0, 70,000, 230.0, 17/0/0/0, 6.
    // Targeting range is already km: 22,500 / 1000 = 22.5 etc.
    #[test]
    fn oracle_ships_return_all_literal_values() {
        let catalogue = bundled();
        let cases = [
            (
                587,
                5.0,
                3.2,
                1_067_000.0,
                35.0,
                22.5,
                660.0,
                0.0,
                8.0,
                0.0,
                0.0,
                4i64,
            ),
            (
                597,
                5.0,
                2.9,
                1_190_000.0,
                37.0,
                25.0,
                640.0,
                10.0,
                0.0,
                0.0,
                0.0,
                4i64,
            ),
            (
                620,
                4.0,
                0.61,
                11_100_000.0,
                95.0,
                62.5,
                280.0,
                0.0,
                0.0,
                0.0,
                15.0,
                8i64,
            ),
            (
                638,
                3.0,
                0.12,
                99_300_000.0,
                410.0,
                90.0,
                111.0,
                0.0,
                0.0,
                0.0,
                22.0,
                7i64,
            ),
            (
                671,
                1.5,
                0.037,
                2_100_000_000.0,
                23_205.0,
                250.0,
                65.0,
                0.0,
                0.0,
                240.0,
                0.0,
                8i64,
            ),
            (
                29986,
                4.0,
                0.52,
                14_500_000.0,
                170.0,
                70.0,
                230.0,
                17.0,
                0.0,
                0.0,
                0.0,
                6i64,
            ),
        ];
        for (
            ship_type_id,
            warp,
            agility,
            mass,
            sig,
            range_km,
            scan,
            radar,
            ladar,
            magn,
            grav,
            locks,
        ) in cases
        {
            let targeting = available(ship_nav_targeting(
                &fitting(ship_type_id, vec![]),
                &catalogue,
            ));
            assert_eq!(targeting.warp_speed, Some(warp), "ship {ship_type_id}");
            assert_eq!(targeting.agility, Some(agility), "ship {ship_type_id}");
            assert_eq!(targeting.mass, Some(mass), "ship {ship_type_id}");
            assert_eq!(targeting.signature_radius, Some(sig), "ship {ship_type_id}");
            assert_eq!(
                targeting.max_target_range_km,
                Some(range_km),
                "ship {ship_type_id}"
            );
            assert_eq!(targeting.scan_resolution, Some(scan), "ship {ship_type_id}");
            assert_eq!(targeting.sensor_radar, Some(radar), "ship {ship_type_id}");
            assert_eq!(targeting.sensor_ladar, Some(ladar), "ship {ship_type_id}");
            assert_eq!(
                targeting.sensor_magnetometric,
                Some(magn),
                "ship {ship_type_id}"
            );
            assert_eq!(
                targeting.sensor_gravimetric,
                Some(grav),
                "ship {ship_type_id}"
            );
            assert_eq!(
                targeting.max_locked_targets,
                Some(locks),
                "ship {ship_type_id}"
            );
        }
    }

    // Align literals hand-derived from section 2.2 with
    // `-ln(0.25) = 1.3862943611198906` (ln 4):
    //   Rifter: 1.3862943611198906 * 3.2 * 1,067,000 / 1e6
    //           = 4.733363466607754 (Flutter closeTo(4.7334, 0.001))
    //   Punisher: 1.3862943611198906 * 2.9 * 1,190,000 / 1e6
    //           = 4.784101840224742
    //   Osprey: 1.3862943611198906 * 0.61 * 11,100,000 / 1e6
    //           = 9.386599119142778
    //   Raven: 1.3862943611198906 * 0.12 * 99,300,000 / 1e6
    //          = 16.519083607104616
    //   Erebus: 1.3862943611198906 * 0.037 * 2,100,000,000 / 1e6
    //           = 107.7150718590155
    //   Capsule: 1.3862943611198906 * 2.0 * 32,000 / 1e6
    //            = 0.08872283911167299
    //   Legion: 1.3862943611198906 * 0.52 * 14,500,000 / 1e6
    //           = 10.452659482843977
    //   Apotheosis: 1.3862943611198906 * 1.0 * 1,600,000 / 1e6
    //               = 2.218070977791825
    #[test]
    fn align_literals_match_hand_derived_values() {
        let catalogue = bundled();
        let cases = [
            (587, 4.733363466607754),
            (597, 4.784101840224742),
            (620, 9.386599119142778),
            (638, 16.519083607104616),
            (671, 107.7150718590155),
            (670, 0.08872283911167299),
            (29986, 10.452659482843977),
            (29266, 2.218070977791825),
        ];
        for (ship_type_id, expected) in cases {
            let targeting = available(ship_nav_targeting(
                &fitting(ship_type_id, vec![]),
                &catalogue,
            ));
            assert_align_close(
                targeting.align_time_secs,
                expected,
                &format!("ship {ship_type_id}"),
            );
        }
        // Flutter parity pin: the Rifter bare-oracle value is
        // within the Flutter test's own closeTo(4.7334, 0.001)
        // band.
        let rifter = available(ship_nav_targeting(&fitting(587, vec![]), &catalogue));
        match rifter.align_time_secs {
            Some(value) => assert!(
                (value - 4.7334).abs() < 0.001,
                "Rifter align Flutter parity: got {value}"
            ),
            None => panic!("Rifter align must be Some, got None"),
        }
    }

    // Capsule 670: present zeros stay Some(0.0) — targeting
    // range 0.0 m, three sensors 0.0 — locked targets Some(0),
    // scan resolution absent, align still computed
    // (1.3862943611198906 * 2.0 * 32,000 / 1e6 = 0.0887228391...).
    #[test]
    fn capsule_present_zeros_stay_some_and_absent_scan_is_none() {
        let catalogue = bundled();
        let targeting = available(ship_nav_targeting(&fitting(670, vec![]), &catalogue));
        assert_eq!(targeting.warp_speed, Some(4.0));
        assert_eq!(targeting.agility, Some(2.0));
        assert_eq!(targeting.mass, Some(32_000.0));
        assert_eq!(targeting.signature_radius, Some(25.0));
        assert_eq!(targeting.max_target_range_km, Some(0.0));
        assert_eq!(targeting.scan_resolution, None);
        assert_eq!(targeting.sensor_radar, Some(0.0));
        assert_eq!(targeting.sensor_ladar, Some(3.0));
        assert_eq!(targeting.sensor_magnetometric, Some(0.0));
        assert_eq!(targeting.sensor_gravimetric, Some(0.0));
        assert_eq!(targeting.max_locked_targets, Some(0));
        assert_align_close(
            targeting.align_time_secs,
            0.08872283911167299,
            "Capsule align",
        );
    }

    // The no-modifiers lock as a test: fitted modules —
    // including an unknown type and a stacked quantity — change
    // nothing.
    #[test]
    fn fitted_items_are_ignored() {
        let catalogue = bundled();
        let hull_only = ship_nav_targeting(&fitting(587, vec![]), &catalogue);
        let fitted = ship_nav_targeting(
            &fitting(
                587,
                vec![
                    item("LoSlot0", 1, 2048),
                    item("MedSlot0", 3, 1183),
                    item("HiSlot0", 1, 999999),
                ],
            ),
            &catalogue,
        );
        assert_eq!(fitted, hull_only);
    }

    // Absent versus zero, via fixture catalogue: the Capsule
    // row already proves absent scan resolution beside present
    // zeros on real data; here a minimal fixture proves the
    // per-field distinction and the all-None collapse.
    #[test]
    fn absent_is_none_and_present_zero_renders() {
        let catalogue = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":42,"typeName":"Fixture Hull","categoryId":6,"slotEffects":[],
                 "warpSpeedMultiplier":5.0,"agility":3.2,"signatureRadius":35.0,
                 "maxTargetRange":0.0,"scanRadarStrength":0.0,"scanLadarStrength":8.0,
                 "scanMagnetometricStrength":0.0,"scanGravimetricStrength":0.0,
                 "maxLockedTargets":0.0,"mass":1067000.0}]}"#,
        )
        .expect("fixture catalogue parses");
        let targeting = available(ship_nav_targeting(&fitting(42, vec![]), &catalogue));
        assert_eq!(targeting.scan_resolution, None);
        assert_eq!(targeting.max_target_range_km, Some(0.0));
        assert_eq!(targeting.max_locked_targets, Some(0));
        assert!(targeting.align_time_secs.is_some());
    }

    #[test]
    fn all_absent_collapses_to_unavailable_and_single_stat_stays_available() {
        let catalogue = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":42,"typeName":"Bare Hull","categoryId":6,"slotEffects":[]},
                {"typeId":43,"typeName":"Lone Stat","categoryId":6,"slotEffects":[],
                 "warpSpeedMultiplier":5.0}]}"#,
        )
        .expect("fixture catalogue parses");
        assert_eq!(
            ship_nav_targeting(&fitting(42, vec![]), &catalogue),
            ShipNavTargetingOutcome::Unavailable
        );
        let targeting = available(ship_nav_targeting(&fitting(43, vec![]), &catalogue));
        assert_eq!(targeting.warp_speed, Some(5.0));
        assert_eq!(targeting.agility, None);
        assert_eq!(targeting.mass, None);
        assert_eq!(targeting.signature_radius, None);
        assert_eq!(targeting.max_target_range_km, None);
        assert_eq!(targeting.scan_resolution, None);
        assert_eq!(targeting.sensor_radar, None);
        assert_eq!(targeting.sensor_ladar, None);
        assert_eq!(targeting.sensor_magnetometric, None);
        assert_eq!(targeting.sensor_gravimetric, None);
        assert_eq!(targeting.max_locked_targets, None);
        assert_eq!(targeting.align_time_secs, None);
    }

    // Guard pin: a negative catalogue value is no data for
    // that stat only; the other stats still render. JSON
    // cannot spell NaN, so the non-finite half is pinned
    // through the shared usable rules' direct calls below.
    #[test]
    fn negative_value_is_no_data_for_that_stat_only() {
        let catalogue = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":42,"typeName":"Fixture Hull","categoryId":6,"slotEffects":[],
                 "warpSpeedMultiplier":-1.0,"agility":3.2,"signatureRadius":35.0,
                 "maxTargetRange":22500.0,"scanResolution":660.0,"scanRadarStrength":0.0,
                 "scanLadarStrength":8.0,"scanMagnetometricStrength":0.0,
                 "scanGravimetricStrength":0.0,"maxLockedTargets":4.0,"mass":1067000.0}]}"#,
        )
        .expect("fixture catalogue parses");
        let targeting = available(ship_nav_targeting(&fitting(42, vec![]), &catalogue));
        assert_eq!(targeting.warp_speed, None);
        assert_eq!(targeting.agility, Some(3.2));
        assert_eq!(targeting.signature_radius, Some(35.0));
        assert_eq!(targeting.max_target_range_km, Some(22.5));
        assert_eq!(targeting.scan_resolution, Some(660.0));
        assert_eq!(targeting.max_locked_targets, Some(4));
        assert!(targeting.align_time_secs.is_some());
    }

    #[test]
    fn usable_guards_reject_non_finite_and_negative() {
        assert_eq!(usable(Some(2.5)), Some(2.5));
        assert_eq!(usable(Some(0.0)), Some(0.0));
        assert_eq!(usable(None), None);
        assert_eq!(usable(Some(-1.0)), None);
        assert_eq!(usable(Some(f64::INFINITY)), None);
        assert_eq!(usable(Some(f64::NEG_INFINITY)), None);
        assert_eq!(usable(Some(f64::NAN)), None);
        assert_eq!(usable_count(Some(4.0)), Some(4));
        assert_eq!(usable_count(Some(0.0)), Some(0));
        assert_eq!(usable_count(None), None);
        assert_eq!(usable_count(Some(-1.0)), None);
        assert_eq!(usable_count(Some(4.5)), None);
        assert_eq!(usable_count(Some(f64::INFINITY)), None);
        assert_eq!(usable_count(Some(f64::NAN)), None);
    }

    // Align guards: a present 0.0 agility or mass is still
    // Some data for its own field but yields no align time;
    // missing agility or mass likewise; overflow to a
    // non-finite result is None. 1.3862943611198906 * 3.2 *
    // 1,067,000 / 1e6 = 4.733363466607754 for the positive case.
    #[test]
    fn align_guards_zero_missing_and_overflow_are_none() {
        assert_eq!(
            align_time_secs(Some(0.0), Some(1_067_000.0)),
            None,
            "zero agility"
        );
        assert_eq!(align_time_secs(Some(3.2), Some(0.0)), None, "zero mass");
        assert_eq!(
            align_time_secs(None, Some(1_067_000.0)),
            None,
            "missing agility"
        );
        assert_eq!(align_time_secs(Some(3.2), None), None, "missing mass");
        assert_eq!(align_time_secs(None, None), None, "both missing");
        assert_eq!(
            align_time_secs(Some(f64::MAX), Some(f64::MAX)),
            None,
            "overflow to non-finite"
        );
        assert_align_close(
            align_time_secs(Some(3.2), Some(1_067_000.0)),
            4.733363466607754,
            "Rifter fixture",
        );
        // Zero-input catalogue rows keep their own fields while
        // align stays None.
        let catalogue = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":42,"typeName":"Zero Agility","categoryId":6,"slotEffects":[],
                 "agility":0.0,"mass":1067000.0},
                {"typeId":43,"typeName":"Missing Agility","categoryId":6,"slotEffects":[],
                 "mass":1067000.0}]}"#,
        )
        .expect("fixture catalogue parses");
        let zero_agility = available(ship_nav_targeting(&fitting(42, vec![]), &catalogue));
        assert_eq!(zero_agility.agility, Some(0.0));
        assert_eq!(zero_agility.mass, Some(1_067_000.0));
        assert_eq!(zero_agility.align_time_secs, None);
        let missing_agility = available(ship_nav_targeting(&fitting(43, vec![]), &catalogue));
        assert_eq!(missing_agility.agility, None);
        assert_eq!(missing_agility.mass, Some(1_067_000.0));
        assert_eq!(missing_agility.align_time_secs, None);
    }

    // Non-integral locked-targets catalogue values are no
    // data for that stat only; the other stats still render.
    #[test]
    fn non_integral_locked_targets_is_none_and_others_unaffected() {
        let catalogue = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":42,"typeName":"Fixture Hull","categoryId":6,"slotEffects":[],
                 "warpSpeedMultiplier":5.0,"maxLockedTargets":4.5}]}"#,
        )
        .expect("fixture catalogue parses");
        let targeting = available(ship_nav_targeting(&fitting(42, vec![]), &catalogue));
        assert_eq!(targeting.max_locked_targets, None);
        assert_eq!(targeting.warp_speed, Some(5.0));
    }

    #[test]
    fn ship_failures_are_unavailable() {
        let catalogue = bundled();
        for ship_type_id in [999999, 2048, 0, -1] {
            let result = ship_nav_targeting(&fitting(ship_type_id, vec![]), &catalogue);
            assert_eq!(
                result,
                ShipNavTargetingOutcome::Unavailable,
                "ship {ship_type_id}"
            );
        }
    }

    // Independence from neighbours, in both directions
    // (fixtures): outputs without nav data give resources
    // Available and nav Unavailable; nav data without outputs
    // gives resources ShipNoOutput and nav Available. A ship
    // with full #578 stats but no nav fields leaves #578
    // Available and this block Unavailable.
    #[test]
    fn availability_is_independent_of_neighbours() {
        let outputs_only = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":42,"typeName":"Outputs Only","categoryId":6,"slotEffects":[],
                 "cpuOutput":130.0,"powerOutput":41.0}]}"#,
        )
        .expect("fixture catalogue parses");
        let fit = fitting(42, vec![]);
        assert!(matches!(
            fitting_resources(&fit, &outputs_only),
            crate::fitting::resources::FittingResources::Available { .. }
        ));
        assert_eq!(
            ship_nav_targeting(&fit, &outputs_only),
            ShipNavTargetingOutcome::Unavailable
        );

        let nav_only = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":43,"typeName":"Nav Only","categoryId":6,"slotEffects":[],
                 "warpSpeedMultiplier":5.0}]}"#,
        )
        .expect("fixture catalogue parses");
        let fit = fitting(43, vec![]);
        assert_eq!(
            fitting_resources(&fit, &nav_only),
            crate::fitting::resources::FittingResources::ShipNoOutput
        );
        assert!(matches!(
            ship_nav_targeting(&fit, &nav_only),
            ShipNavTargetingOutcome::Available(_)
        ));

        let stats_only = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":44,"typeName":"Stats Only","categoryId":6,"slotEffects":[],
                 "shieldCapacity":450.0,"armorHP":450.0,"hp":350.0,
                 "capacitorCapacity":250.0,"maxVelocity":365.0,
                 "shieldRechargeRate":625000.0,"rechargeRate":125000.0}]}"#,
        )
        .expect("fixture catalogue parses");
        let fit = fitting(44, vec![]);
        assert!(matches!(
            ship_base_stats(&fit, &stats_only),
            crate::fitting::ship_stats::ShipBaseStatsOutcome::Available(_)
        ));
        assert_eq!(
            ship_nav_targeting(&fit, &stats_only),
            ShipNavTargetingOutcome::Unavailable
        );
    }

    // --- Bonused navigation and targeting pins
    // (docs/nav-targeting-bonuses-design.md sections 4, 8;
    // Rifter 587 base: warp 5.0 AU/s, agility 3.2, mass
    // 1,067,000 kg, signature 35.0 m, range 22,500 m,
    // scan 660.0 mm, sensors 0/8/0/0, locks 4, align
    // 4.733363466607754 s; Punisher 597 base: warp 5.0,
    // agility 2.9, mass 1,190,000, signature 37.0, range
    // 25,000 m, scan 640.0, sensors 10/0/0/0, locks 4).
    // Formula per attribute:
    // (base + adds) * mul * percent, in catalogue units;
    // comments show the hand multiplication.

    #[test]
    fn bonused_nav_targeting_warp_per_family() {
        let catalogue = bundled();
        // Oracle 1: 26322 Large Hyperspatial Velocity
        // Optimizer II [[600, 6, 25.0]]:
        // 5.0 * 1.25 = 6.25 AU/s.
        let fit = fitting(587, vec![item("RigSlot0", 1, 26322)]);
        let bonused = bonused_available(ship_nav_targeting_with_module_bonuses(&fit, &catalogue));
        assert_bonused_close(bonused.targeting.warp_speed, 6.25, "oracle 1 warp");
        assert_eq!(bonused.excluded_modules, 0);
        assert_all_unapplied_zero(&bonused);
        // Helper raw value is the same AU/s figure.
        let helper = bonused_nav_targeting(&fit, &catalogue).expect("helper Some");
        assert_bonused_close(helper.values[0], 6.25, "oracle 1 helper warp");
        assert_eq!(helper.excluded_modules, 0);
        assert_eq!(helper.unapplied_modules, [0; 11]);
        // Oracle 2: 33985 Prototype Hyperspatial
        // Accelerator [[600, 2, 0.3]]:
        // 5.0 + 0.3 = 5.3 AU/s.
        let fit = fitting(587, vec![item("LoSlot0", 1, 33985)]);
        let bonused = bonused_available(ship_nav_targeting_with_module_bonuses(&fit, &catalogue));
        assert_bonused_close(bonused.targeting.warp_speed, 5.3, "oracle 2 warp");
        assert_eq!(bonused.excluded_modules, 0);
        assert_all_unapplied_zero(&bonused);
    }

    #[test]
    fn bonused_nav_targeting_agility_mass_align() {
        let catalogue = bundled();
        // Oracle 3: 2605 Nanofiber Internal Structure II
        // [[70, 6, -15.75]]: agility 3.2 * 0.8425 = 2.696;
        // align 1.386294… * 2.696 * 1,067,000 / 1e6
        // = 3.9878587206170333 s.
        let fit = fitting(587, vec![item("LoSlot0", 1, 2605)]);
        let bonused = bonused_available(ship_nav_targeting_with_module_bonuses(&fit, &catalogue));
        assert_bonused_close(bonused.targeting.agility, 2.696, "oracle 3 agility");
        assert_align_close(
            bonused.targeting.align_time_secs,
            3.9878587206170333,
            "oracle 3 align",
        );
        assert_eq!(bonused.targeting.mass, Some(1_067_000.0));
        // Oracle 4 (Flutter cross-pin): 20353 1600mm Steel
        // Plates II [[4, 2, 3750000.0]]: mass 4,817,000.0 kg;
        // align = 21.36889580004644 s (Flutter's plate test
        // expects closeTo(21.369, 0.01) on the same operands).
        let fit = fitting(587, vec![item("LoSlot0", 1, 20353)]);
        let bonused = bonused_available(ship_nav_targeting_with_module_bonuses(&fit, &catalogue));
        assert_eq!(bonused.targeting.mass, Some(4_817_000.0));
        assert_align_close(
            bonused.targeting.align_time_secs,
            21.36889580004644,
            "oracle 4 align",
        );
        match bonused.targeting.align_time_secs {
            Some(value) => assert!(
                (value - 21.369).abs() < 0.01,
                "oracle 4 Flutter parity: got {value}"
            ),
            None => panic!("oracle 4 align must be Some, got None"),
        }
        // Oracle 5 (single-input mutant killer): 2605 +
        // 20353 together: align over bonused 2.696 and
        // bonused 4,817,000 = 18.003294711539127 s.
        let fit = fitting(
            587,
            vec![item("LoSlot0", 1, 2605), item("LoSlot1", 1, 20353)],
        );
        let bonused = bonused_available(ship_nav_targeting_with_module_bonuses(&fit, &catalogue));
        assert_bonused_close(bonused.targeting.agility, 2.696, "oracle 5 agility");
        assert_eq!(bonused.targeting.mass, Some(4_817_000.0));
        assert_align_close(
            bonused.targeting.align_time_secs,
            18.003294711539127,
            "oracle 5 align",
        );
    }

    #[test]
    fn bonused_nav_targeting_signature_family() {
        let catalogue = bundled();
        // Oracle 6 (Flutter cross-pin): 3831 Medium Shield
        // Extender II [[552, 2, 7.0]]:
        // 35.0 + 7.0 = 42.0 m (Flutter E0a.1: 35 -> 42).
        let fit = fitting(587, vec![item("MedSlot0", 1, 3831)]);
        let bonused = bonused_available(ship_nav_targeting_with_module_bonuses(&fit, &catalogue));
        assert_eq!(bonused.targeting.signature_radius, Some(42.0));
        assert_eq!(bonused.targeting.signature_radius, Some(42.0));
        // Oracle 7 (add-before-percent mutant killer):
        // 3831 + 1405 [[552, 6, 11.0]]:
        // (35.0 + 7.0) * 1.11 = 46.62 m.
        let fit = fitting(
            587,
            vec![item("MedSlot0", 1, 3831), item("LoSlot0", 1, 1405)],
        );
        let bonused = bonused_available(ship_nav_targeting_with_module_bonuses(&fit, &catalogue));
        assert_bonused_close(
            bonused.targeting.signature_radius,
            46.62,
            "oracle 7 signature",
        );
        // Oracle 8 (dual multiplier): 4409 Signature Radius
        // Suppressor I [[552, 4, 0.9], [552, 4, 0.3]]:
        // 35.0 * 0.9 * 0.3 = 9.45 m.
        let fit = fitting(587, vec![item("MedSlot0", 1, 4409)]);
        let bonused = bonused_available(ship_nav_targeting_with_module_bonuses(&fit, &catalogue));
        assert_bonused_close(
            bonused.targeting.signature_radius,
            9.45,
            "oracle 8 signature",
        );
        let helper = bonused_nav_targeting(&fit, &catalogue).expect("helper Some");
        assert_bonused_close(helper.values[3], 9.45, "oracle 8 helper signature");
    }

    #[test]
    fn bonused_nav_targeting_range_and_scan() {
        let catalogue = bundled();
        // Oracle 9: 1952 Sensor Booster II
        // [[76, 6, 30.0]]: 22,500 * 1.3 = 29,250 m -> 29.25 km
        // (conversion after bonus).
        let fit = fitting(587, vec![item("MedSlot0", 1, 1952)]);
        let bonused = bonused_available(ship_nav_targeting_with_module_bonuses(&fit, &catalogue));
        assert_bonused_close(
            bonused.targeting.max_target_range_km,
            29.25,
            "oracle 9 range",
        );
        // Helper raw value stays in metres before conversion.
        let helper = bonused_nav_targeting(&fit, &catalogue).expect("helper Some");
        assert_bonused_close(helper.values[4], 29_250.0, "oracle 9 helper range m");
        // Oracle 10 (shrink, no clamp): 10998 Warp Core
        // Stabilizer I [[76, 6, -50.0]]:
        // 22,500 * 0.5 = 11,250 m -> 11.25 km, below base.
        let fit = fitting(587, vec![item("LoSlot0", 1, 10998)]);
        let bonused = bonused_available(ship_nav_targeting_with_module_bonuses(&fit, &catalogue));
        assert_bonused_close(
            bonused.targeting.max_target_range_km,
            11.25,
            "oracle 10 range",
        );
        // Oracle 11: 1952 [[564, 6, 30.0]] + 11370
        // Prototype Cloaking Device I [[564, 4, 0.5]]:
        // 660.0 * 0.5 * 1.3 = 429.0 mm.
        let fit = fitting(
            587,
            vec![item("MedSlot0", 1, 1952), item("HiSlot0", 1, 11370)],
        );
        let bonused = bonused_available(ship_nav_targeting_with_module_bonuses(&fit, &catalogue));
        assert_bonused_close(bonused.targeting.scan_resolution, 429.0, "oracle 11 scan");
        let helper = bonused_nav_targeting(&fit, &catalogue).expect("helper Some");
        assert_bonused_close(helper.values[5], 429.0, "oracle 11 helper scan");
    }

    #[test]
    fn bonused_nav_targeting_sensors_and_locks() {
        let catalogue = bundled();
        // Oracle 12: Punisher + 1987 Signal Amplifier II
        // (48.0 on each of 208-211): RADAR 10.0 * 1.48 =
        // 14.8, the three present zeros stay Some(0.0);
        // Rifter Ladar 8.0 * 1.48 = 11.84.
        let fit = fitting(597, vec![item("LoSlot0", 1, 1987)]);
        let bonused = bonused_available(ship_nav_targeting_with_module_bonuses(&fit, &catalogue));
        assert_bonused_close(bonused.targeting.sensor_radar, 14.8, "oracle 12 radar");
        assert_eq!(bonused.targeting.sensor_ladar, Some(0.0));
        assert_eq!(bonused.targeting.sensor_magnetometric, Some(0.0));
        assert_eq!(bonused.targeting.sensor_gravimetric, Some(0.0));
        let fit = fitting(587, vec![item("LoSlot0", 1, 1987)]);
        let bonused = bonused_available(ship_nav_targeting_with_module_bonuses(&fit, &catalogue));
        assert_bonused_close(bonused.targeting.sensor_ladar, 11.84, "oracle 12 ladar");
        // Oracle 13: 1987 on Rifter: 4 + 2 = Some(6).
        assert_eq!(bonused.targeting.max_locked_targets, Some(6));
        let helper = bonused_nav_targeting(&fit, &catalogue).expect("helper Some");
        assert_bonused_close(helper.values[10], 6.0, "oracle 13 helper locks f64");
        assert_eq!(bonused.excluded_modules, 0);
        assert_all_unapplied_zero(&bonused);
    }

    #[test]
    fn bonused_nav_targeting_multi_family_and_splits() {
        let catalogue = bundled();
        // Oracle 14: 34266 Small Higgs Anchor I on Rifter:
        // warp 5.0 * 0.9 = 4.5, agility 3.2 * 0.45 = 1.44,
        // mass 1,067,000 * 2.0 = 2,134,000.0, align
        // = 4.260027119946979 s.
        let fit = fitting(587, vec![item("RigSlot0", 1, 34266)]);
        let bonused = bonused_available(ship_nav_targeting_with_module_bonuses(&fit, &catalogue));
        assert_bonused_close(bonused.targeting.warp_speed, 4.5, "oracle 14 warp");
        assert_bonused_close(bonused.targeting.agility, 1.44, "oracle 14 agility");
        assert_eq!(bonused.targeting.mass, Some(2_134_000.0));
        assert_align_close(
            bonused.targeting.align_time_secs,
            4.260027119946979,
            "oracle 14 align",
        );
        assert_eq!(bonused.targeting.signature_radius, Some(35.0));
        assert_eq!(bonused.targeting.max_target_range_km, Some(22.5));
        assert_eq!(bonused.targeting.scan_resolution, Some(660.0));
        assert_eq!(bonused.targeting.max_locked_targets, Some(4));
        assert_eq!(bonused.excluded_modules, 0);
        assert_all_unapplied_zero(&bonused);
        // Oracle 15 (split pin 1): 1182 Auto Targeting System
        // I on Rifter: locks Some(6), range still 22.5 km,
        // range unapplied 1, every other unapplied 0, in both
        // the helper array (position of 76) and the unpacked
        // public fields.
        let fit = fitting(587, vec![item("HiSlot0", 1, 1182)]);
        let bonused = bonused_available(ship_nav_targeting_with_module_bonuses(&fit, &catalogue));
        assert_eq!(bonused.targeting.max_locked_targets, Some(6));
        assert_eq!(bonused.targeting.max_target_range_km, Some(22.5));
        assert_eq!(bonused.max_target_range_unapplied_modules, 1);
        assert_eq!(bonused.warp_speed_unapplied_modules, 0);
        assert_eq!(bonused.agility_unapplied_modules, 0);
        assert_eq!(bonused.mass_unapplied_modules, 0);
        assert_eq!(bonused.signature_radius_unapplied_modules, 0);
        assert_eq!(bonused.scan_resolution_unapplied_modules, 0);
        assert_eq!(bonused.sensor_radar_unapplied_modules, 0);
        assert_eq!(bonused.sensor_ladar_unapplied_modules, 0);
        assert_eq!(bonused.sensor_magnetometric_unapplied_modules, 0);
        assert_eq!(bonused.sensor_gravimetric_unapplied_modules, 0);
        assert_eq!(bonused.max_locked_targets_unapplied_modules, 0);
        let helper = bonused_nav_targeting(&fit, &catalogue).expect("helper Some");
        assert_eq!(helper.unapplied_modules, [0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0]);
        assert_bonused_close(helper.values[4], 22_500.0, "oracle 15 helper range m");
        assert_bonused_close(helper.values[10], 6.0, "oracle 15 helper locks f64");
        // Oracle 16 (split pin 2): 27951 Triage Module I on
        // Rifter: mass 1,067,000 * 10.0 = 10,670,000.0, locks
        // Some(8), scan still 660.0, scan unapplied 1,
        // others 0.
        let fit = fitting(587, vec![item("HiSlot0", 1, 27951)]);
        let bonused = bonused_available(ship_nav_targeting_with_module_bonuses(&fit, &catalogue));
        assert_eq!(bonused.targeting.mass, Some(10_670_000.0));
        assert_eq!(bonused.targeting.max_locked_targets, Some(8));
        assert_eq!(bonused.targeting.scan_resolution, Some(660.0));
        assert_eq!(bonused.scan_resolution_unapplied_modules, 1);
        assert_eq!(bonused.warp_speed_unapplied_modules, 0);
        assert_eq!(bonused.agility_unapplied_modules, 0);
        assert_eq!(bonused.mass_unapplied_modules, 0);
        assert_eq!(bonused.signature_radius_unapplied_modules, 0);
        assert_eq!(bonused.max_target_range_unapplied_modules, 0);
        assert_eq!(bonused.max_locked_targets_unapplied_modules, 0);
        let helper = bonused_nav_targeting(&fit, &catalogue).expect("helper Some");
        assert_eq!(helper.unapplied_modules, [0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0]);
        // Oracle 17: marked-with-nothing-applied: 47812
        // (mass 1, qty 2) and 47800 (signature 1, qty 2).
        let fit = fitting(587, vec![item("LoSlot0", 2, 47812)]);
        let bonused = bonused_available(ship_nav_targeting_with_module_bonuses(&fit, &catalogue));
        assert_eq!(bonused.targeting.mass, Some(1_067_000.0));
        assert_eq!(bonused.mass_unapplied_modules, 2);
        let helper = bonused_nav_targeting(&fit, &catalogue).expect("helper Some");
        assert_eq!(helper.unapplied_modules[2], 2);
        let fit = fitting(587, vec![item("MedSlot0", 2, 47800)]);
        let bonused = bonused_available(ship_nav_targeting_with_module_bonuses(&fit, &catalogue));
        assert_eq!(bonused.targeting.signature_radius, Some(35.0));
        assert_eq!(bonused.signature_radius_unapplied_modules, 2);
        let helper = bonused_nav_targeting(&fit, &catalogue).expect("helper Some");
        assert_eq!(helper.unapplied_modules[3], 2);
    }

    #[test]
    fn bonused_nav_targeting_no_counted_items_equals_base() {
        let catalogue = bundled();
        // Empty fitting: bonused targeting equals the shipped
        // base struct by assert_eq, all twelve counts 0.
        let empty = fitting(587, vec![]);
        let base = available(ship_nav_targeting(&empty, &catalogue));
        let bonused = bonused_available(ship_nav_targeting_with_module_bonuses(&empty, &catalogue));
        assert_eq!(bonused.targeting, base);
        assert_eq!(bonused.excluded_modules, 0);
        assert_all_unapplied_zero(&bonused);
        // Non-counted flags only (carrier cargo), zero and
        // negative quantities, and a counted non-carrier
        // (2048) each leave the base values untouched.
        let ignored = fitting(
            587,
            vec![
                item("DroneBay", 1, 26322),
                item("Cargo", 1, 26322),
                item("FighterBay", 1, 1952),
                item("LoSlot0", 0, 26322),
                item("LoSlot1", -3, 26322),
                item("MedSlot0", 1, 2048),
            ],
        );
        let bonused_ignored =
            bonused_available(ship_nav_targeting_with_module_bonuses(&ignored, &catalogue));
        let base_ignored = available(ship_nav_targeting(&ignored, &catalogue));
        assert_eq!(bonused_ignored.targeting, base_ignored);
        assert_eq!(bonused_ignored.targeting, base);
        assert_eq!(bonused_ignored.excluded_modules, 0);
        assert_all_unapplied_zero(&bonused_ignored);
        // Counted catalogue-absent type: base values with
        // excluded equal to the quantity and all unapplied 0.
        let absent = fitting(587, vec![item("RigSlot0", 3, 999999)]);
        let bonused_absent =
            bonused_available(ship_nav_targeting_with_module_bonuses(&absent, &catalogue));
        assert_eq!(bonused_absent.targeting, base);
        assert_eq!(bonused_absent.excluded_modules, 3);
        assert_all_unapplied_zero(&bonused_absent);
        // The excluded count equals bonused_resonances' on
        // the same fitting (the shared-definition pin).
        let resistances_helper =
            crate::fitting::ship_resistances::bonused_resonances(&absent, &catalogue)
                .expect("resistances helper Some");
        assert_eq!(
            bonused_absent.excluded_modules,
            resistances_helper.excluded_modules
        );
        // Rig-slot counting: oracle 1's rig applies from
        // RigSlot; the same type under Cargo does not apply
        // and counts nowhere.
        let rig = fitting(587, vec![item("RigSlot0", 1, 26322)]);
        let bonused_rig =
            bonused_available(ship_nav_targeting_with_module_bonuses(&rig, &catalogue));
        assert_bonused_close(bonused_rig.targeting.warp_speed, 6.25, "rig warp");
        let cargo = fitting(587, vec![item("Cargo", 1, 26322)]);
        let bonused_cargo =
            bonused_available(ship_nav_targeting_with_module_bonuses(&cargo, &catalogue));
        assert_eq!(bonused_cargo.targeting, base);
        assert_eq!(bonused_cargo.excluded_modules, 0);
        assert_all_unapplied_zero(&bonused_cargo);
        // A subsystem-slot carrier (catalogue category 7
        // type under SubSystemSlot) applies — slot belonging
        // is never judged.
        let subsystem_slot = fitting(587, vec![item("SubSystemSlot0", 1, 3831)]);
        let bonused_subsystem = bonused_available(ship_nav_targeting_with_module_bonuses(
            &subsystem_slot,
            &catalogue,
        ));
        assert_eq!(bonused_subsystem.targeting.signature_radius, Some(42.0));
        // While a category-32 subsystem type itself (45600)
        // carries no keys and contributes nothing under any
        // flag, counting nowhere.
        for flag in ["SubSystemSlot0", "LoSlot0", "RigSlot0"] {
            let fit = fitting(587, vec![item(flag, 1, 45600)]);
            let bonused =
                bonused_available(ship_nav_targeting_with_module_bonuses(&fit, &catalogue));
            assert_eq!(bonused.targeting, base, "flag {flag}");
            assert_eq!(bonused.excluded_modules, 0, "flag {flag}");
            assert_all_unapplied_zero(&bonused);
        }
    }

    #[test]
    fn bonused_nav_targeting_present_zero_and_absent() {
        let catalogue = bundled();
        // Capsule 670 (range Some(0.0), locks Some(0), scan
        // None) + 3831 -> signature 25.0 + 7.0 = 32.0, range
        // stays Some(0.0) km under a fitted 1952 percent, locks
        // Some(2) under 1987's add on a zero base, scan stays
        // None under 1952 (absent never resurrected), align
        // still derives — each field independently.
        let fit = fitting(670, vec![item("MedSlot0", 1, 3831)]);
        let bonused = bonused_available(ship_nav_targeting_with_module_bonuses(&fit, &catalogue));
        assert_eq!(bonused.targeting.signature_radius, Some(32.0));
        let fit = fitting(670, vec![item("MedSlot0", 1, 1952)]);
        let bonused = bonused_available(ship_nav_targeting_with_module_bonuses(&fit, &catalogue));
        assert_eq!(bonused.targeting.max_target_range_km, Some(0.0));
        assert_eq!(bonused.targeting.scan_resolution, None);
        let fit = fitting(670, vec![item("LoSlot0", 1, 1987)]);
        let bonused = bonused_available(ship_nav_targeting_with_module_bonuses(&fit, &catalogue));
        assert_eq!(bonused.targeting.max_locked_targets, Some(2));
        assert!(bonused.targeting.align_time_secs.is_some());
        assert_align_close(
            bonused.targeting.align_time_secs,
            0.08872283911167299,
            "Capsule bonused align",
        );
    }

    #[test]
    fn bonused_nav_targeting_per_field_guards_and_independence() {
        // Negative base per field -> that field None,
        // neighbours untouched (synthetic catalogue,
        // base-design shape).
        let catalogue = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":42,"typeName":"Fixture Hull","categoryId":6,"slotEffects":[],
                 "warpSpeedMultiplier":-1.0,"agility":3.2,"signatureRadius":35.0,
                 "maxTargetRange":22500.0,"scanResolution":660.0,"scanRadarStrength":0.0,
                 "scanLadarStrength":8.0,"scanMagnetometricStrength":0.0,
                 "scanGravimetricStrength":0.0,"maxLockedTargets":4.0,"mass":1067000.0}]}"#,
        )
        .expect("fixture catalogue parses");
        let bonused = bonused_available(ship_nav_targeting_with_module_bonuses(
            &fitting(42, vec![]),
            &catalogue,
        ));
        assert_eq!(bonused.targeting.warp_speed, None);
        assert_eq!(bonused.targeting.agility, Some(3.2));
        assert_eq!(bonused.targeting.mass, Some(1_067_000.0));
        assert_eq!(bonused.targeting.signature_radius, Some(35.0));
        assert_eq!(bonused.targeting.max_target_range_km, Some(22.5));
        assert_eq!(bonused.targeting.scan_resolution, Some(660.0));
        assert_eq!(bonused.targeting.max_locked_targets, Some(4));
        // NaN/infinite bases cannot be spelled in JSON
        // (serde rejects 1e400 as out of range) and are
        // pinned through bonused_count's direct guards
        // below (the shared is_finite branch, mirroring the
        // usable() pins above); a finite base that overflows
        // to a non-finite bonused result is no data for that
        // field only.
        assert_eq!(bonused_count(Some(f64::INFINITY)), None);
        assert_eq!(bonused_count(Some(f64::NAN)), None);
        assert_eq!(bonused_count(Some(f64::NEG_INFINITY)), None);
        let catalogue = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":42,"typeName":"Fixture Hull","categoryId":6,"slotEffects":[],
                 "warpSpeedMultiplier":1.7976931348623157e308,"agility":3.2,"signatureRadius":35.0,
                 "maxTargetRange":22500.0,"scanResolution":660.0,"scanRadarStrength":0.0,
                 "scanLadarStrength":8.0,"scanMagnetometricStrength":0.0,
                 "scanGravimetricStrength":0.0,"maxLockedTargets":4.0,"mass":1067000.0},
                {"typeId":101,"typeName":"Overflow","categoryId":7,"slotEffects":[13],"warpSpeedMultiplierModifiers":[[600,6,100.0]]}]}"#,
        )
        .expect("fixture catalogue parses");
        let bonused = bonused_available(ship_nav_targeting_with_module_bonuses(
            &fitting(42, vec![item("MedSlot0", 1, 101)]),
            &catalogue,
        ));
        assert_eq!(bonused.targeting.warp_speed, None);
        assert_eq!(bonused.targeting.agility, Some(3.2));
        assert_eq!(bonused.targeting.signature_radius, Some(35.0));
        // Non-ship / unknown / ship_type_id <= 0 ->
        // Unavailable.
        let bundled_catalogue = bundled();
        for ship_type_id in [999999, 2048, 0, -1] {
            assert_eq!(
                ship_nav_targeting_with_module_bonuses(
                    &fitting(ship_type_id, vec![item("LoSlot0", 1, 26322)]),
                    &bundled_catalogue,
                ),
                BonusedShipNavTargetingOutcome::Unavailable,
                "ship {ship_type_id}"
            );
        }
        // All-eleven-None synthetic -> Unavailable even with
        // counted carriers fitted (bonuses never resurrect
        // availability).
        let bare = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":42,"typeName":"Bare Hull","categoryId":6,"slotEffects":[]},
                {"typeId":101,"typeName":"Warp","categoryId":7,"slotEffects":[13],"warpSpeedMultiplierModifiers":[[600,6,25.0]]}]}"#,
        )
        .expect("fixture catalogue parses");
        assert_eq!(
            ship_nav_targeting_with_module_bonuses(
                &fitting(42, vec![item("RigSlot0", 1, 101)]),
                &bare,
            ),
            BonusedShipNavTargetingOutcome::Unavailable
        );
        // Neighbour independence (base mirrors): bonused
        // Available while resources are ShipNoOutput, and a
        // full-#578-stats ship with no nav fields leaves this
        // block Unavailable and #578 untouched.
        let nav_only = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":43,"typeName":"Nav Only","categoryId":6,"slotEffects":[],
                 "warpSpeedMultiplier":5.0}]}"#,
        )
        .expect("fixture catalogue parses");
        let fit = fitting(43, vec![]);
        assert_eq!(
            fitting_resources(&fit, &nav_only),
            crate::fitting::resources::FittingResources::ShipNoOutput
        );
        assert!(matches!(
            ship_nav_targeting_with_module_bonuses(&fit, &nav_only),
            BonusedShipNavTargetingOutcome::Available(_)
        ));
        let stats_only = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":44,"typeName":"Stats Only","categoryId":6,"slotEffects":[],
                 "shieldCapacity":450.0,"armorHP":450.0,"hp":350.0,
                 "capacitorCapacity":250.0,"maxVelocity":365.0,
                 "shieldRechargeRate":625000.0,"rechargeRate":125000.0}]}"#,
        )
        .expect("fixture catalogue parses");
        let fit = fitting(44, vec![]);
        assert!(matches!(
            ship_base_stats(&fit, &stats_only),
            crate::fitting::ship_stats::ShipBaseStatsOutcome::Available(_)
        ));
        assert_eq!(
            ship_nav_targeting_with_module_bonuses(&fit, &stats_only),
            BonusedShipNavTargetingOutcome::Unavailable
        );
    }

    #[test]
    fn bonused_nav_targeting_hostile_bounded() {
        let catalogue = bundled();
        // Quantity i64::MAX of 11370 (mul 0.5 on 564):
        // completes via the bounded stall; scan is the
        // asserted exact Some(0.0); every other field base.
        let fit = fitting(587, vec![item("HiSlot0", i64::MAX, 11370)]);
        let bonused = bonused_available(ship_nav_targeting_with_module_bonuses(&fit, &catalogue));
        assert_eq!(bonused.targeting.scan_resolution, Some(0.0));
        assert_eq!(bonused.targeting.warp_speed, Some(5.0));
        assert_eq!(bonused.targeting.signature_radius, Some(35.0));
        assert_eq!(bonused.targeting.max_target_range_km, Some(22.5));
        assert_eq!(bonused.targeting.max_locked_targets, Some(4));
        assert_eq!(bonused.excluded_modules, 0);
        assert_all_unapplied_zero(&bonused);
        let helper = bonused_nav_targeting(&fit, &catalogue).expect("helper Some");
        assert_eq!(helper.values[5], Some(0.0));
        // Quantity i64::MAX of a percent carrier (10998 at
        // -50): range asserted Some(0.0) km, no hang.
        let fit = fitting(587, vec![item("LoSlot0", i64::MAX, 10998)]);
        let bonused = bonused_available(ship_nav_targeting_with_module_bonuses(&fit, &catalogue));
        assert_eq!(bonused.targeting.max_target_range_km, Some(0.0));
        // The scan family of the same row (WCS also carries
        // a 0.5 mul on 564) stays base under the range
        // hostile quantity only if its own runs stall to
        // zero; the asserted range zero proves completion.
        let helper = bonused_nav_targeting(&fit, &catalogue).expect("helper Some");
        assert_eq!(helper.values[4], Some(0.0));
    }

    #[test]
    fn bonused_nav_targeting_subnormal_and_zero() {
        let hull = r#"{"typeId":42,"typeName":"Fixture Hull","categoryId":6,"slotEffects":[],"warpSpeedMultiplier":5.0,"agility":3.2,"signatureRadius":35.0,"maxTargetRange":22500.0,"scanResolution":660.0,"scanRadarStrength":0.0,"scanLadarStrength":8.0,"scanMagnetometricStrength":0.0,"scanGravimetricStrength":0.0,"maxLockedTargets":4.0,"mass":1067000.0}"#;
        // Subnormal: operand 5e-324 (min positive subnormal)
        // operator 4 on 600 -> warp None (line omitted),
        // the other ten fields base-Some (per-field
        // completeness).
        let catalogue = FittingTypes::from_json(
            &format!(r#"{{"types":[{hull},{{"typeId":101,"typeName":"Sub","categoryId":7,"slotEffects":[13],"warpSpeedMultiplierModifiers":[[600,4,5e-324]]}}]}}"#),
        )
        .expect("fixture catalogue parses");
        let bonused = bonused_available(ship_nav_targeting_with_module_bonuses(
            &fitting(42, vec![item("MedSlot0", 1, 101)]),
            &catalogue,
        ));
        assert_eq!(bonused.targeting.warp_speed, None);
        assert_eq!(bonused.targeting.agility, Some(3.2));
        assert_eq!(bonused.targeting.mass, Some(1_067_000.0));
        assert_eq!(bonused.targeting.signature_radius, Some(35.0));
        assert_eq!(bonused.targeting.max_target_range_km, Some(22.5));
        assert_eq!(bonused.targeting.scan_resolution, Some(660.0));
        assert_eq!(bonused.targeting.sensor_radar, Some(0.0));
        assert_eq!(bonused.targeting.sensor_ladar, Some(8.0));
        assert_eq!(bonused.targeting.max_locked_targets, Some(4));
        assert!(bonused.targeting.align_time_secs.is_some());
        // Positive-subnormal fixture base on 552 ->
        // signature None, neighbours Some.
        let catalogue = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":42,"typeName":"Fixture Hull","categoryId":6,"slotEffects":[],
                 "warpSpeedMultiplier":5.0,"agility":3.2,"signatureRadius":5e-324,
                 "maxTargetRange":22500.0,"scanResolution":660.0,"scanRadarStrength":0.0,
                 "scanLadarStrength":8.0,"scanMagnetometricStrength":0.0,
                 "scanGravimetricStrength":0.0,"maxLockedTargets":4.0,"mass":1067000.0}]}"#,
        )
        .expect("fixture catalogue parses");
        let bonused = bonused_available(ship_nav_targeting_with_module_bonuses(
            &fitting(42, vec![]),
            &catalogue,
        ));
        assert_eq!(bonused.targeting.signature_radius, None);
        assert_eq!(bonused.targeting.warp_speed, Some(5.0));
        assert_eq!(bonused.targeting.scan_resolution, Some(660.0));
        assert_eq!(bonused.targeting.max_locked_targets, Some(4));
        // Exact-zero survival: fixture -100.0 percent on 600
        // -> Some(0.0) (the 2ac348f zero kept, never confused
        // with absence).
        let catalogue = FittingTypes::from_json(
            &format!(r#"{{"types":[{hull},{{"typeId":101,"typeName":"Zero","categoryId":7,"slotEffects":[13],"warpSpeedMultiplierModifiers":[[600,6,-100.0]]}}]}}"#),
        )
        .expect("fixture catalogue parses");
        let bonused = bonused_available(ship_nav_targeting_with_module_bonuses(
            &fitting(42, vec![item("MedSlot0", 1, 101)]),
            &catalogue,
        ));
        assert_eq!(bonused.targeting.warp_speed, Some(0.0));
    }

    #[test]
    fn bonused_nav_targeting_negative_and_integer() {
        let hull = r#"{"typeId":42,"typeName":"Fixture Hull","categoryId":6,"slotEffects":[],"warpSpeedMultiplier":5.0,"agility":3.2,"signatureRadius":35.0,"maxTargetRange":22500.0,"scanResolution":660.0,"scanRadarStrength":0.0,"scanLadarStrength":8.0,"scanMagnetometricStrength":0.0,"scanGravimetricStrength":0.0,"maxLockedTargets":4.0,"mass":1067000.0}"#;
        // Negative result: fixture percent -150.0 on 76 ->
        // range None (never a negative kilometre), others base.
        let catalogue = FittingTypes::from_json(
            &format!(r#"{{"types":[{hull},{{"typeId":101,"typeName":"Neg","categoryId":7,"slotEffects":[13],"maxTargetRangeModifiers":[[76,6,-150.0]]}}]}}"#),
        )
        .expect("fixture catalogue parses");
        let bonused = bonused_available(ship_nav_targeting_with_module_bonuses(
            &fitting(42, vec![item("MedSlot0", 1, 101)]),
            &catalogue,
        ));
        assert_eq!(bonused.targeting.max_target_range_km, None);
        assert_eq!(bonused.targeting.warp_speed, Some(5.0));
        assert_eq!(bonused.targeting.scan_resolution, Some(660.0));
        assert_eq!(bonused.targeting.max_locked_targets, Some(4));
        // Fixture multiplier -1.0 at odd quantity on 564 ->
        // scan None (parity branch, never a hang).
        let catalogue = FittingTypes::from_json(
            &format!(r#"{{"types":[{hull},{{"typeId":101,"typeName":"NegMul","categoryId":7,"slotEffects":[13],"scanResolutionModifiers":[[564,4,-1.0]]}}]}}"#),
        )
        .expect("fixture catalogue parses");
        let bonused = bonused_available(ship_nav_targeting_with_module_bonuses(
            &fitting(42, vec![item("MedSlot0", 1, 101)]),
            &catalogue,
        ));
        assert_eq!(bonused.targeting.scan_resolution, None);
        assert_eq!(bonused.targeting.warp_speed, Some(5.0));
        // Integer rule, hostile side: fixture percent 12.5 on
        // 192 over base 4 (4 * 1.125 = 4.5) -> Some(4) by
        // truncation toward zero (design section 2's Flutter
        // attr(192).toInt() rule) — and the same fixture
        // through the *base* path remains integral-or-None
        // (base 4.5 -> locks None).
        let catalogue = FittingTypes::from_json(
            &format!(r#"{{"types":[{hull},{{"typeId":101,"typeName":"Trunc","categoryId":7,"slotEffects":[13],"maxLockedTargetsModifiers":[[192,6,12.5]]}}]}}"#),
        )
        .expect("fixture catalogue parses");
        let bonused = bonused_available(ship_nav_targeting_with_module_bonuses(
            &fitting(42, vec![item("MedSlot0", 1, 101)]),
            &catalogue,
        ));
        assert_eq!(bonused.targeting.max_locked_targets, Some(4));
        let base_catalogue = FittingTypes::from_json(
            r#"{"types":[
                {"typeId":42,"typeName":"Fixture Hull","categoryId":6,"slotEffects":[],
                 "warpSpeedMultiplier":5.0,"maxLockedTargets":4.5}]}"#,
        )
        .expect("fixture catalogue parses");
        let base = available(ship_nav_targeting(&fitting(42, vec![]), &base_catalogue));
        assert_eq!(base.max_locked_targets, None);
        assert_eq!(base.warp_speed, Some(5.0));
        // Fixture bonused count above 2^53 and negative
        // bonused count -> None.
        assert_eq!(bonused_count(Some(1e16)), None);
        assert_eq!(bonused_count(Some(-0.5)), None);
        assert_eq!(bonused_count(Some(0.0)), Some(0));
        assert_eq!(bonused_count(Some(4.5)), Some(4));
        // A fixture percent -150.0 on 192 yields a negative
        // computed count filtered to None before conversion.
        let catalogue = FittingTypes::from_json(
            &format!(r#"{{"types":[{hull},{{"typeId":101,"typeName":"NegLock","categoryId":7,"slotEffects":[13],"maxLockedTargetsModifiers":[[192,6,-150.0]]}}]}}"#),
        )
        .expect("fixture catalogue parses");
        let bonused = bonused_available(ship_nav_targeting_with_module_bonuses(
            &fitting(42, vec![item("MedSlot0", 1, 101)]),
            &catalogue,
        ));
        assert_eq!(bonused.targeting.max_locked_targets, None);
        assert_eq!(bonused.targeting.warp_speed, Some(5.0));
    }

    #[test]
    fn bonused_nav_targeting_defective_guards() {
        let hull = r#"{"typeId":42,"typeName":"Fixture Hull","categoryId":6,"slotEffects":[],"warpSpeedMultiplier":5.0,"agility":3.2,"signatureRadius":35.0,"maxTargetRange":22500.0,"scanResolution":660.0,"scanRadarStrength":0.0,"scanLadarStrength":8.0,"scanMagnetometricStrength":0.0,"scanGravimetricStrength":0.0,"maxLockedTargets":4.0,"mass":1067000.0}"#;
        // Unsupported operators 0/5 count once in that
        // family only and contribute nothing.
        for operator in [0, 5] {
            let catalogue = FittingTypes::from_json(
                &format!(r#"{{"types":[{hull},{{"typeId":101,"typeName":"Bad","categoryId":7,"slotEffects":[13],"warpSpeedMultiplierModifiers":[[600,{operator},25.0]]}}]}}"#),
            )
            .expect("fixture catalogue parses");
            let bonused = bonused_available(ship_nav_targeting_with_module_bonuses(
                &fitting(42, vec![item("MedSlot0", 1, 101)]),
                &catalogue,
            ));
            assert_eq!(
                bonused.warp_speed_unapplied_modules, 1,
                "operator {operator}"
            );
            assert_eq!(bonused.agility_unapplied_modules, 0, "operator {operator}");
            assert_eq!(
                bonused.targeting.warp_speed,
                Some(5.0),
                "operator {operator}"
            );
            let helper =
                bonused_nav_targeting(&fitting(42, vec![item("MedSlot0", 1, 101)]), &catalogue)
                    .expect("helper Some");
            assert_eq!(helper.unapplied_modules, [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]);
        }
        // Zero operand counts once and contributes nothing
        // (a non-finite operand shares this same guard
        // branch; JSON cannot carry one, so the zero case
        // pins it).
        let catalogue = FittingTypes::from_json(
            &format!(r#"{{"types":[{hull},{{"typeId":101,"typeName":"Bad","categoryId":7,"slotEffects":[13],"warpSpeedMultiplierModifiers":[[600,6,0.0]]}}]}}"#),
        )
        .expect("fixture catalogue parses");
        let bonused = bonused_available(ship_nav_targeting_with_module_bonuses(
            &fitting(42, vec![item("MedSlot0", 1, 101)]),
            &catalogue,
        ));
        assert_eq!(bonused.warp_speed_unapplied_modules, 1);
        assert_eq!(bonused.targeting.warp_speed, Some(5.0));
        // Another family's modified id counts in the family
        // it sits in only; the other dimension is untouched.
        let catalogue = FittingTypes::from_json(
            &format!(r#"{{"types":[{hull},{{"typeId":101,"typeName":"Bad","categoryId":7,"slotEffects":[13],"warpSpeedMultiplierModifiers":[[552,4,0.9]]}}]}}"#),
        )
        .expect("fixture catalogue parses");
        let bonused = bonused_available(ship_nav_targeting_with_module_bonuses(
            &fitting(42, vec![item("MedSlot0", 1, 101)]),
            &catalogue,
        ));
        assert_eq!(bonused.warp_speed_unapplied_modules, 1);
        assert_eq!(bonused.signature_radius_unapplied_modules, 0);
        assert_eq!(bonused.targeting.warp_speed, Some(5.0));
        assert_eq!(bonused.targeting.signature_radius, Some(35.0));
        // Two bad entries on one item still count once; a
        // good entry on the same item still applies.
        let catalogue = FittingTypes::from_json(
            &format!(r#"{{"types":[{hull},{{"typeId":101,"typeName":"Bad","categoryId":7,"slotEffects":[13],"warpSpeedMultiplierModifiers":[[600,0,25.0],[600,5,20.0],[600,6,25.0]]}}]}}"#),
        )
        .expect("fixture catalogue parses");
        let bonused = bonused_available(ship_nav_targeting_with_module_bonuses(
            &fitting(42, vec![item("MedSlot0", 1, 101)]),
            &catalogue,
        ));
        assert_eq!(bonused.warp_speed_unapplied_modules, 1);
        assert_bonused_close(bonused.targeting.warp_speed, 6.25, "good still applies");
        // Signature dual-entry fixture with one bad leg: the
        // good multiplier still applies and the item counts
        // once.
        let catalogue = FittingTypes::from_json(
            &format!(r#"{{"types":[{hull},{{"typeId":101,"typeName":"Bad","categoryId":7,"slotEffects":[13],"signatureRadiusModifiers":[[552,0,0.5],[552,4,0.9]]}}]}}"#),
        )
        .expect("fixture catalogue parses");
        let bonused = bonused_available(ship_nav_targeting_with_module_bonuses(
            &fitting(42, vec![item("MedSlot0", 1, 101)]),
            &catalogue,
        ));
        assert_eq!(bonused.signature_radius_unapplied_modules, 1);
        assert_bonused_close(
            bonused.targeting.signature_radius,
            31.5,
            "signature good still applies",
        );
    }
}
