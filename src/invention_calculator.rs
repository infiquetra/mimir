//! Pure invention chance calculation for the Industry view's
//! Invention Calculator block.
//!
//! The math replicates the retired Flutter calculator at `ed698d3`
//! (`lib/features/industry/domain/invention_calculator.dart`): the
//! chance is the base probability times a skill factor of one plus
//! each of the three skill levels over 40, times a decryptor
//! multiplier, capped at 1.0. All five inputs — base probability,
//! three skill levels, and decryptor multiplier — are user-entered;
//! the app reads them from no blueprint, character skill, owned
//! decryptor, or loaded job. The starting values are Flutter's own
//! starting values, labelled as values to replace with the reader's
//! own; they are not the signed-in character's levels or any
//! blueprint's probability. See
//! `docs/industry-calculators-design.md`.
//!
//! The module is pure computation — no egui, no state, no network,
//! no database. It logs nothing: it runs at render cadence, so
//! per-frame logging would spam the log.
//!
//! The reaction calculator lives in `crate::reaction_calculator` over the
//! bundled industry data in `crate::names::industry_ref`;
//! there is still no production-chain calculator (see
//! `docs/industry-reaction-design.md` section 11).

/// Flutter's starting base probability (panel state
/// `_baseProbability = 0.30`): the `AppState` draft seed, labelled
/// as a user-entered starting value, never a derived figure.
pub const DEFAULT_BASE_PROBABILITY: f64 = 0.30;

/// Flutter's starting skill level (`_encryptionSkillLevel = 4`,
/// `_datacoreSkill1Level = 4`, `_datacoreSkill2Level = 4`): the
/// `AppState` draft seed for all three level fields, labelled as a
/// user-entered starting value, never a derived level.
pub const DEFAULT_SKILL_LEVEL: i64 = 4;

/// Flutter's starting decryptor multiplier (`_decryptorMultiplier
/// = 1.0`, none): the `AppState` draft seed, labelled as a
/// user-entered starting value, never a derived multiplier.
pub const DEFAULT_DECRYPTOR_MULTIPLIER: f64 = 1.0;

/// Parse a base-probability draft: trim, parse as `f64`, accept only
/// a finite value above 0 and at most 1. No comma stripping and no
/// `%` suffix rule: on a 0–1 fraction field a comma is a mistyped
/// decimal separator, not a thousands separator, and `30%` must not
/// silently read as a percent. Rejects `inf`, `-inf`, and `NaN` in
/// any case, only because the parser would otherwise accept them.
pub fn parse_base_probability(text: &str) -> Option<f64> {
    let value: f64 = text.trim().parse().ok()?;
    if value.is_finite() && value > 0.0 && value <= 1.0 {
        Some(value)
    } else {
        None
    }
}

/// Parse a skill-level draft: trim, parse as `i64`, accept only 1
/// to 5. A level is a whole number (Flutter's `int` parameters), so
/// fractional text such as `4.0` is rejected.
pub fn parse_skill_level(text: &str) -> Option<i64> {
    let value: i64 = text.trim().parse().ok()?;
    if (1..=5).contains(&value) {
        Some(value)
    } else {
        None
    }
}

/// Parse a decryptor-multiplier draft: trim, parse as `f64`, accept
/// only a finite value above 0. No upper bound at parse time
/// (Flutter's domain has none); [`calculate_probability`]'s
/// finiteness check rejects a typed multiplier so large the product
/// overflows. No `x` prefix rule: `x1.0` is rejected.
pub fn parse_decryptor_multiplier(text: &str) -> Option<f64> {
    let value: f64 = text.trim().parse().ok()?;
    if value.is_finite() && value > 0.0 {
        Some(value)
    } else {
        None
    }
}

/// Calculate the invention chance, or `None` when the base
/// probability is non-finite, at or below 0, or above 1, any skill
/// level is outside 1 to 5, the decryptor multiplier is non-finite
/// or at or below 0, or the computed raw chance is non-finite
/// (overflow from a huge finite multiplier). The finiteness check
/// runs before the cap, so an infinite product never becomes a
/// plausible `1.0` (Flutter's cap test would have produced one).
pub fn calculate_probability(
    base_probability: f64,
    encryption_skill_level: i64,
    datacore_skill1_level: i64,
    datacore_skill2_level: i64,
    decryptor_multiplier: f64,
) -> Option<f64> {
    if !(base_probability.is_finite()
        && base_probability > 0.0
        && base_probability <= 1.0
        && (1..=5).contains(&encryption_skill_level)
        && (1..=5).contains(&datacore_skill1_level)
        && (1..=5).contains(&datacore_skill2_level)
        && decryptor_multiplier.is_finite()
        && decryptor_multiplier > 0.0)
    {
        return None;
    }
    // Operand order matches Flutter exactly so floating-point
    // association matches the locked oracles.
    let skill_factor = 1.0
        + (encryption_skill_level as f64 / 40.0)
        + (datacore_skill1_level as f64 / 40.0)
        + (datacore_skill2_level as f64 / 40.0);
    let raw_chance = base_probability * skill_factor * decryptor_multiplier;
    if !raw_chance.is_finite() {
        return None;
    }
    Some(raw_chance.min(1.0))
}

/// The renderer's one call: parse all five drafts and return `Some`
/// only when all five parse and [`calculate_probability`] succeeds.
pub fn invention_calculator_result(
    base_probability_text: &str,
    encryption_skill_text: &str,
    datacore_skill1_text: &str,
    datacore_skill2_text: &str,
    decryptor_multiplier_text: &str,
) -> Option<f64> {
    let base_probability = parse_base_probability(base_probability_text)?;
    let encryption_skill_level = parse_skill_level(encryption_skill_text)?;
    let datacore_skill1_level = parse_skill_level(datacore_skill1_text)?;
    let datacore_skill2_level = parse_skill_level(datacore_skill2_text)?;
    let decryptor_multiplier = parse_decryptor_multiplier(decryptor_multiplier_text)?;
    calculate_probability(
        base_probability,
        encryption_skill_level,
        datacore_skill1_level,
        datacore_skill2_level,
        decryptor_multiplier,
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    const TOLERANCE: f64 = 1e-9;

    fn assert_approx(actual: f64, expected: f64) {
        assert!(
            (actual - expected).abs() < TOLERANCE,
            "expected {expected}, got {actual}"
        );
    }

    #[test]
    fn max_skills_no_decryptor() {
        // skill factor = 1.0 + 5/40 + 5/40 + 5/40 = 1.375
        // 0.30 * 1.375 = 0.4125
        let chance = calculate_probability(0.30, 5, 5, 5, 1.0).expect("valid inputs");
        assert_approx(chance, 0.4125);
    }

    #[test]
    fn max_skills_symmetry_decryptor() {
        // 0.4125 * 1.1 = 0.45375
        let chance = calculate_probability(0.30, 5, 5, 5, 1.1).expect("valid inputs");
        assert_approx(chance, 0.45375);
    }

    #[test]
    fn skills_four_optimized_decryptor() {
        // skill factor = 1.0 + 4/40 + 4/40 + 4/40 = 1.3
        // 0.40 * 1.3 = 0.52; 0.52 * 0.6 = 0.312
        let chance = calculate_probability(0.40, 4, 4, 4, 0.6).expect("valid inputs");
        assert_approx(chance, 0.312);
    }

    #[test]
    fn caps_at_one() {
        // 0.9 * 1.375 * 1.8 = 2.2275 -> capped at 1.0
        assert_eq!(calculate_probability(0.90, 5, 5, 5, 1.8), Some(1.0));
    }

    #[test]
    fn panel_starting_values() {
        // skill factor = 1.0 + 4/40 + 4/40 + 4/40 = 1.3
        // 0.30 * 1.3 * 1.0 = 0.39
        let chance = calculate_probability(0.30, 4, 4, 4, 1.0).expect("valid inputs");
        assert_approx(chance, 0.39);
    }

    #[test]
    fn minimum_skill_levels() {
        // skill factor = 1.0 + 1/40 + 1/40 + 1/40 = 1.075
        // 0.30 * 1.075 * 1.0 = 0.3225
        let chance = calculate_probability(0.30, 1, 1, 1, 1.0).expect("valid inputs");
        assert_approx(chance, 0.3225);
    }

    #[test]
    fn validation_matrix() {
        // Base probability at or below 0, above 1, or non-finite:
        // None with otherwise-valid inputs.
        for base in [0.0, -0.1, 1.1, f64::NAN, f64::INFINITY, f64::NEG_INFINITY] {
            assert_eq!(
                calculate_probability(base, 4, 4, 4, 1.0),
                None,
                "base {base}"
            );
        }
        // Each skill position at 0 gives None.
        assert_eq!(calculate_probability(0.30, 0, 4, 4, 1.0), None);
        assert_eq!(calculate_probability(0.30, 4, 0, 4, 1.0), None);
        assert_eq!(calculate_probability(0.30, 4, 4, 0, 1.0), None);
        // 6 and -1 give None in each of the three positions.
        for level in [6, -1] {
            assert_eq!(calculate_probability(0.30, level, 4, 4, 1.0), None);
            assert_eq!(calculate_probability(0.30, 4, level, 4, 1.0), None);
            assert_eq!(calculate_probability(0.30, 4, 4, level, 1.0), None);
        }
        // Decryptor multiplier at or below 0, or non-finite: None.
        for multiplier in [0.0, -1.0, f64::NAN, f64::INFINITY] {
            assert_eq!(
                calculate_probability(0.30, 4, 4, 4, multiplier),
                None,
                "multiplier {multiplier}"
            );
        }
        // Overflow: 1.0 * 1.375 * 1.5e308 exceeds the largest
        // finite double, so the raw chance is non-finite. None,
        // never a cap-produced 1.0.
        assert_eq!(calculate_probability(1.0, 5, 5, 5, 1.5e308), None);
        // Valid corner: base exactly 1.0 parses and calculates;
        // with levels 4 and multiplier 1.0 the raw chance 1.3
        // caps to exactly 1.0.
        assert_eq!(calculate_probability(1.0, 4, 4, 4, 1.0), Some(1.0));
    }

    #[test]
    fn base_probability_parser_cases() {
        assert_eq!(parse_base_probability("0.30"), Some(0.3));
        assert_eq!(parse_base_probability(" 0.5 "), Some(0.5));
        assert_eq!(parse_base_probability("1"), Some(1.0));
        for text in [
            "", "abc", "NaN", "inf", "-inf", "0", "-0.1", "1.1", "30", "30%",
        ] {
            assert_eq!(parse_base_probability(text), None, "base text {text:?}");
        }
    }

    #[test]
    fn skill_level_parser_cases() {
        assert_eq!(parse_skill_level("4"), Some(4));
        assert_eq!(parse_skill_level(" 5 "), Some(5));
        assert_eq!(parse_skill_level("1"), Some(1));
        for text in ["0", "6", "-1", "4.0", "", "abc"] {
            assert_eq!(parse_skill_level(text), None, "skill text {text:?}");
        }
    }

    #[test]
    fn decryptor_multiplier_parser_cases() {
        assert_eq!(parse_decryptor_multiplier("1.0"), Some(1.0));
        assert_eq!(parse_decryptor_multiplier("0.6"), Some(0.6));
        assert_eq!(parse_decryptor_multiplier("1.8"), Some(1.8));
        for text in ["0", "-1", "", "NaN", "x1.0"] {
            assert_eq!(
                parse_decryptor_multiplier(text),
                None,
                "multiplier text {text:?}"
            );
        }
    }

    #[test]
    fn result_cases() {
        let chance =
            invention_calculator_result("0.30", "4", "4", "4", "1.0").expect("valid drafts");
        assert_approx(chance, 0.39);
        // Any one invalid draft gives None, one case per field.
        assert_eq!(invention_calculator_result("", "4", "4", "4", "1.0"), None);
        assert_eq!(
            invention_calculator_result("0.30", "abc", "4", "4", "1.0"),
            None
        );
        assert_eq!(
            invention_calculator_result("0.30", "4", "", "4", "1.0"),
            None
        );
        assert_eq!(
            invention_calculator_result("0.30", "4", "4", "6", "1.0"),
            None
        );
        assert_eq!(invention_calculator_result("0.30", "4", "4", "4", ""), None);
        // All parse but the product overflows: None.
        assert_eq!(
            invention_calculator_result("1", "5", "5", "5", "1.5e308"),
            None
        );
    }

    #[test]
    fn defaults_match_flutter_starting_values() {
        assert_eq!(DEFAULT_BASE_PROBABILITY, 0.30);
        assert_eq!(DEFAULT_SKILL_LEVEL, 4);
        assert_eq!(DEFAULT_DECRYPTOR_MULTIPLIER, 1.0);
    }
}
