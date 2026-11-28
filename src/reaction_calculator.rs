//! Pure reaction quantity calculation for the Industry view's
//! Reaction Calculator block.
//!
//! The math replicates the retired Flutter calculator at `ed698d3`
//! (`lib/features/industry/domain/reaction_calculator.dart`): inputs are
//! `round(runs * baseQty * (1.0 - facilityMaterialBonus))` on the total
//! amount for all runs with a minimum of 1, and outputs are
//! `baseQty * runs` with no bonus or rounding. Base quantities come
//! from the bundled industry data in `crate::names::industry_ref` at
//! activity 11, runs from the reader, and the facility material bonus
//! percent from the reader. The starting values are Flutter's own
//! starting values, labelled as values to replace with the reader's own;
//! they are not derived from structures, blueprints, skills, assets, or
//! jobs. See `docs/industry-reaction-design.md`.
//!
//! The module is pure computation — no egui, no state, no network,
//! no database, no `include_str!`. It logs nothing: it runs at render
//! cadence, so per-frame logging would spam the log. The production-chain
//! calculator lives in `crate::production_chain` over the same bundled
//! data (see `docs/production-chain-design.md`).

use std::collections::HashSet;

/// Flutter's starting runs (`_runs = 1`): the `AppState` draft seed,
/// labelled as a user-entered starting value, never a derived figure.
pub const DEFAULT_RUNS: i64 = 1;

/// Flutter's starting facility material bonus percent
/// (`_facilityMaterialBonus = 0.0`): the `AppState` draft seed, labelled
/// as a user-entered starting value, never a derived rate.
pub const DEFAULT_FACILITY_BONUS_PERCENT: f64 = 0.0;

/// Largest integer up to which every integer is exactly representable
/// in `f64`. Above it a total converted to `f64` moves to a neighbour
/// representable value, so the rounded result would be wrong by whole
/// units. Applies to inputs only.
const MAX_EXACT_FLOAT_QUANTITY: i64 = 9_007_199_254_740_992;

/// Reaction quantity result. Vectors are in input-slice order (file
/// order from the loader), never a map.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct ReactionResult {
    pub inputs: Vec<(i64, i64)>,
    pub outputs: Vec<(i64, i64)>,
}

/// Parse a runs draft: trim, parse as `i64`, accept only a value of at
/// least 1. No comma stripping — on a whole-number count a comma is a
/// typo, not a thousands separator. No upper bound at parse time; the
/// calculation's checked arithmetic rejects a count too large to
/// multiply.
pub fn parse_runs(text: &str) -> Option<i64> {
    let value: i64 = text.trim().parse().ok()?;
    if value >= 1 {
        Some(value)
    } else {
        None
    }
}

/// Parse a facility material bonus percent draft: trim, remove one
/// trailing `%` if present, strip commas, parse as `f64`, accept only
/// a finite value of at least 0 and below 100. Rejects `inf`, `-inf`,
/// and `NaN` in any case, only because the parser would otherwise
/// accept them. Exactly 100 is rejected rather than downstream.
pub fn parse_facility_bonus_percent(text: &str) -> Option<f64> {
    let trimmed = text.trim();
    let without_suffix = trimmed.strip_suffix('%').unwrap_or(trimmed);
    let cleaned = without_suffix.replace(',', "");
    let value: f64 = cleaned.parse().ok()?;
    if value.is_finite() && (0.0..100.0).contains(&value) {
        Some(value)
    } else {
        None
    }
}

/// Calculate input quantities, or `None` when runs is below 1, the
/// bonus fraction is non-finite, below 0, or at or above 1, the slice
/// is empty, any type number or quantity is at or below 0, the same
/// type appears twice, any `runs * base_qty` overflows `i64`, any input
/// total exceeds 2^53, or the rounded value is non-finite, negative, or
/// above 2^53. All arithmetic is checked; the cast only sees a value
/// proven in range.
pub fn calculate_inputs(
    base_inputs: &[(i64, i64)],
    runs: i64,
    facility_material_bonus: f64,
) -> Option<Vec<(i64, i64)>> {
    if runs < 1 {
        return None;
    }
    if !(facility_material_bonus.is_finite() && (0.0..1.0).contains(&facility_material_bonus)) {
        return None;
    }
    if base_inputs.is_empty() {
        return None;
    }
    let mut seen = HashSet::with_capacity(base_inputs.len());
    for (type_id, qty) in base_inputs {
        if *type_id <= 0 || *qty <= 0 {
            return None;
        }
        if !seen.insert(*type_id) {
            return None;
        }
    }

    let max_exact_f64 = MAX_EXACT_FLOAT_QUANTITY as f64;
    let mut out = Vec::with_capacity(base_inputs.len());
    for (type_id, base_qty) in base_inputs {
        let total_base_qty = runs.checked_mul(*base_qty)?;
        if total_base_qty > MAX_EXACT_FLOAT_QUANTITY {
            return None;
        }
        let product = (total_base_qty as f64) * (1.0 - facility_material_bonus);
        let rounded = product.round();
        if !rounded.is_finite() || rounded < 0.0 || rounded > max_exact_f64 {
            return None;
        }
        let actual_qty = rounded as i64;
        let input_qty = if actual_qty > 0 { actual_qty } else { 1 };
        out.push((*type_id, input_qty));
    }
    Some(out)
}

/// Calculate output quantities.
pub fn calculate_outputs(base_outputs: &[(i64, i64)], runs: i64) -> Option<Vec<(i64, i64)>> {
    if runs < 1 {
        return None;
    }
    if base_outputs.is_empty() {
        return None;
    }
    let mut seen = HashSet::with_capacity(base_outputs.len());
    for (type_id, qty) in base_outputs {
        if *type_id <= 0 || *qty <= 0 {
            return None;
        }
        if !seen.insert(*type_id) {
            return None;
        }
    }
    let mut out = Vec::with_capacity(base_outputs.len());
    for (type_id, base_qty) in base_outputs {
        let out_qty = runs.checked_mul(*base_qty)?;
        out.push((*type_id, out_qty));
    }
    Some(out)
}

/// The renderer's one call: parse both texts, divide the percent by
/// 100.0 exactly once, and return `Some` only when both calculations
/// succeed — never inputs without outputs or the reverse.
pub fn reaction_calculator_result(
    base_inputs: &[(i64, i64)],
    base_outputs: &[(i64, i64)],
    runs_text: &str,
    facility_bonus_percent_text: &str,
) -> Option<ReactionResult> {
    let runs = parse_runs(runs_text)?;
    let percent = parse_facility_bonus_percent(facility_bonus_percent_text)?;
    let facility_material_bonus = percent / 100.0;
    let inputs = calculate_inputs(base_inputs, runs, facility_material_bonus)?;
    let outputs = calculate_outputs(base_outputs, runs)?;
    Some(ReactionResult { inputs, outputs })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn flutter_oracle_1() {
        assert_eq!(
            calculate_inputs(&[(16641, 100), (16642, 100)], 1, 0.0),
            Some(vec![(16641, 100), (16642, 100)])
        );
    }

    #[test]
    fn flutter_oracle_2() {
        // 100 * (1 - 0.048) = 95.2 -> 95
        assert_eq!(
            calculate_inputs(&[(16641, 100), (16642, 100)], 1, 0.048),
            Some(vec![(16641, 95), (16642, 95)])
        );
    }

    #[test]
    fn flutter_oracle_3() {
        // 10 runs = 1000 base; 1000 * (1 - 0.048) = 952
        assert_eq!(
            calculate_inputs(&[(16641, 100), (16642, 100)], 10, 0.048),
            Some(vec![(16641, 952), (16642, 952)])
        );
    }

    #[test]
    fn flutter_oracle_4() {
        assert_eq!(
            calculate_outputs(&[(16654, 10)], 5),
            Some(vec![(16654, 50)])
        );
    }

    #[test]
    fn small_quantity_rounding() {
        // 5 * (1 - 0.048) = 4.76 -> 5
        assert_eq!(
            calculate_inputs(&[(4246, 5)], 1, 0.048),
            Some(vec![(4246, 5)])
        );
        // 50 * (1 - 0.048) = 47.6 -> 48
        assert_eq!(
            calculate_inputs(&[(4246, 5)], 10, 0.048),
            Some(vec![(4246, 48)])
        );
        assert_eq!(
            calculate_inputs(&[(16633, 100)], 10, 0.048),
            Some(vec![(16633, 952)])
        );
    }

    #[test]
    fn rounding_ties_half_away() {
        // 5 * (1 - 0.5) = 2.5 -> 3
        assert_eq!(calculate_inputs(&[(1, 5)], 1, 0.5), Some(vec![(1, 3)]));
        // 25 * (1 - 0.02) = 24.5 -> 25
        assert_eq!(calculate_inputs(&[(1, 25)], 1, 0.02), Some(vec![(1, 25)]));
    }

    #[test]
    fn minimum_guard_applies_once_to_total() {
        // 1 * (1 - 0.99) = 0.01 -> 0 -> 1
        assert_eq!(calculate_inputs(&[(1, 1)], 1, 0.99), Some(vec![(1, 1)]));
        // 10 * 1 * (1 - 0.99) = 0.1 -> 0 -> 1 (never 10)
        assert_eq!(calculate_inputs(&[(1, 1)], 10, 0.99), Some(vec![(1, 1)]));
        // per-run versus total: the guard fires once
        assert_eq!(calculate_inputs(&[(1, 1)], 100, 0.99), Some(vec![(1, 1)]));
    }

    #[test]
    fn outputs_at_runs_1_are_base_quantities() {
        assert_eq!(
            calculate_outputs(&[(16654, 10)], 1),
            Some(vec![(16654, 10)])
        );
    }

    #[test]
    fn validation_matrix_inputs() {
        for runs in [0, -1] {
            assert_eq!(calculate_inputs(&[(16641, 100)], runs, 0.0), None);
        }
        for bonus in [-0.01, 1.0, 1.1, f64::NAN, f64::INFINITY, f64::NEG_INFINITY] {
            assert_eq!(
                calculate_inputs(&[(16641, 100)], 1, bonus),
                None,
                "bonus {bonus}"
            );
        }
        assert_eq!(calculate_inputs(&[], 1, 0.0), None);
        assert_eq!(calculate_inputs(&[(0, 100)], 1, 0.0), None);
        assert_eq!(calculate_inputs(&[(-1, 100)], 1, 0.0), None);
        assert_eq!(calculate_inputs(&[(16641, 0)], 1, 0.0), None);
        assert_eq!(calculate_inputs(&[(16641, -5)], 1, 0.0), None);
        assert_eq!(
            calculate_inputs(&[(16641, 100), (16641, 100)], 1, 0.0),
            None
        );
    }

    #[test]
    fn validation_matrix_outputs() {
        for runs in [0, -1] {
            assert_eq!(calculate_outputs(&[(16654, 10)], runs), None);
        }
        assert_eq!(calculate_outputs(&[], 1), None);
        assert_eq!(calculate_outputs(&[(0, 10)], 1), None);
        assert_eq!(calculate_outputs(&[(-1, 10)], 1), None);
        assert_eq!(calculate_outputs(&[(16654, 0)], 1), None);
        assert_eq!(calculate_outputs(&[(16654, -5)], 1), None);
        assert_eq!(calculate_outputs(&[(16654, 10), (16654, 10)], 1), None);
    }

    #[test]
    fn overflow_and_precision_boundary() {
        assert_eq!(calculate_inputs(&[(16641, i64::MAX)], 2, 0.0), None);
        assert_eq!(calculate_outputs(&[(16654, i64::MAX)], 2), None);
        assert_eq!(
            calculate_inputs(&[(37, 9_007_199_254_740_992)], 1, 0.0),
            Some(vec![(37, 9_007_199_254_740_992)])
        );
        assert_eq!(
            calculate_inputs(&[(37, 9_007_199_254_740_993)], 1, 0.0),
            None
        );
        // same 2^53+1 through outputs at runs 1 is integer-exact
        assert_eq!(
            calculate_outputs(&[(37, 9_007_199_254_740_993)], 1),
            Some(vec![(37, 9_007_199_254_740_993)])
        );
    }

    #[test]
    fn runs_parser_cases() {
        assert_eq!(parse_runs("1"), Some(1));
        assert_eq!(parse_runs(" 10 "), Some(10));
        assert_eq!(parse_runs("101"), Some(101));
        assert_eq!(parse_runs("9223372036854775807"), Some(i64::MAX));
        for text in ["", "0", "-1", "1.5", "1,000", "abc"] {
            assert_eq!(parse_runs(text), None, "runs text {text:?}");
        }
    }

    #[test]
    fn bonus_parser_cases() {
        assert_eq!(parse_facility_bonus_percent("0"), Some(0.0));
        assert_eq!(parse_facility_bonus_percent("0.0"), Some(0.0));
        assert_eq!(parse_facility_bonus_percent("4.8"), Some(4.8));
        assert_eq!(parse_facility_bonus_percent("4.8%"), Some(4.8));
        assert_eq!(parse_facility_bonus_percent(" 5.6 "), Some(5.6));
        assert_eq!(parse_facility_bonus_percent("99.9"), Some(99.9));
        for text in ["", "-0.1", "100", "100%", "NaN", "inf"] {
            assert_eq!(
                parse_facility_bonus_percent(text),
                None,
                "bonus text {text:?}"
            );
        }
        // divide pin: 4.8 / 100.0 == 0.048 exactly
        assert_eq!(parse_facility_bonus_percent("4.8").unwrap() / 100.0, 0.048);
    }

    #[test]
    fn result_cases() {
        let base_inputs = [(16641, 100), (16642, 100)];
        let base_outputs = [(16654, 10)];

        let r = reaction_calculator_result(&base_inputs, &base_outputs, "1", "0.0").expect("valid");
        assert_eq!(r.inputs, vec![(16641, 100), (16642, 100)]);
        assert_eq!(r.outputs, vec![(16654, 10)]);

        let r = reaction_calculator_result(&base_inputs, &base_outputs, "1", "4.8").expect("valid");
        assert_eq!(r.inputs, vec![(16641, 95), (16642, 95)]);
        assert_eq!(r.outputs, vec![(16654, 10)]);

        let r =
            reaction_calculator_result(&base_inputs, &base_outputs, "10", "4.8").expect("valid");
        assert_eq!(r.inputs, vec![(16641, 952), (16642, 952)]);
        assert_eq!(r.outputs, vec![(16654, 100)]);

        assert_eq!(
            reaction_calculator_result(&base_inputs, &base_outputs, "", "0.0"),
            None
        );
        assert_eq!(
            reaction_calculator_result(&base_inputs, &base_outputs, "1", ""),
            None
        );
        assert_eq!(
            reaction_calculator_result(&base_inputs, &base_outputs, "abc", "0.0"),
            None
        );
        assert_eq!(
            reaction_calculator_result(&base_inputs, &base_outputs, "1", "100"),
            None
        );

        // runs parses but calculation rejects magnitude
        assert_eq!(
            reaction_calculator_result(
                &[(16641, 100)],
                &[(16654, 10)],
                "9223372036854775807",
                "0.0"
            ),
            None
        );
    }

    #[test]
    fn defaults_match_flutter() {
        assert_eq!(DEFAULT_RUNS, 1);
        assert_eq!(DEFAULT_FACILITY_BONUS_PERCENT, 0.0);
    }
}
