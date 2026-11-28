//! Fit-Readiness solver (card #642): exact assemblable copies,
//! partial completion ratio, and the EVE Multibuy clipboard block
//! for what is missing. Pure functions — no DB, no UI — so the
//! numbers a ring or bar renders are pinned by unit tests.
//!
//! Definitions (test-pinned):
//! - `buildable_copies = min_i floor(have_i / need_i)` over
//!   requirements with `need_i > 0`. Zero-need requirements are
//!   ignored entirely; with no positive-need requirement the
//!   answer is 0 copies.
//! - `completion_ratio = sum_i min(have_i, need_i) / sum_i need_i`
//!   over positive-need requirements: progress toward one copy,
//!   in `[0.0, 1.0]` (0.0 when nothing is required).
//! - Missing items are what one *next* copy still needs:
//!   `need_i * (copies + 1) - have_i`, kept when positive.

use std::collections::HashMap;

/// One fit line: how many of a type a single copy consumes.
#[derive(Debug, Clone, PartialEq)]
pub struct FitRequirement {
    pub type_id: i64,
    pub type_name: String,
    pub quantity_per_copy: i64,
}

/// One shortfall line for the next copy.
#[derive(Debug, Clone, PartialEq)]
pub struct MissingItem {
    pub type_id: i64,
    pub type_name: String,
    pub quantity: i64,
}

#[derive(Debug, Clone, PartialEq)]
pub struct FitReadiness {
    pub buildable_copies: i64,
    pub completion_ratio: f64,
    pub missing_for_next_copy: Vec<MissingItem>,
    pub multibuy_block: String,
}

/// EVE Multibuy clipboard block: one `Name xQuantity` line per
/// missing item, sorted by name for deterministic pastes. Empty
/// when nothing is missing.
pub fn build_multibuy_block(missing: &[MissingItem]) -> String {
    let mut sorted: Vec<&MissingItem> = missing.iter().filter(|m| m.quantity > 0).collect();
    sorted.sort_by(|a, b| {
        a.type_name
            .cmp(&b.type_name)
            .then(a.type_id.cmp(&b.type_id))
    });
    sorted
        .iter()
        .map(|m| format!("{} x{}", m.type_name, m.quantity))
        .collect::<Vec<_>>()
        .join("\n")
}

pub fn compute_readiness(
    requirements: &[FitRequirement],
    available_by_type: &HashMap<i64, i64>,
) -> FitReadiness {
    let positive: Vec<&FitRequirement> = requirements
        .iter()
        .filter(|r| r.quantity_per_copy > 0)
        .collect();
    if positive.is_empty() {
        tracing::debug!("[PANTRY] readiness computed with no positive-need requirements");
        return FitReadiness {
            buildable_copies: 0,
            completion_ratio: 0.0,
            missing_for_next_copy: Vec::new(),
            multibuy_block: String::new(),
        };
    }
    let mut copies: i64 = i64::MAX;
    let mut have_capped: i64 = 0;
    let mut need_total: i64 = 0;
    for req in &positive {
        let have = available_by_type
            .get(&req.type_id)
            .copied()
            .unwrap_or(0)
            .max(0);
        copies = copies.min(have / req.quantity_per_copy);
        have_capped = have_capped.saturating_add(have.min(req.quantity_per_copy));
        need_total = need_total.saturating_add(req.quantity_per_copy);
    }
    let completion_ratio = if need_total > 0 {
        (have_capped as f64 / need_total as f64).clamp(0.0, 1.0)
    } else {
        0.0
    };
    let missing_for_next_copy: Vec<MissingItem> = positive
        .iter()
        .filter_map(|req| {
            let have = available_by_type
                .get(&req.type_id)
                .copied()
                .unwrap_or(0)
                .max(0);
            let shortfall = req
                .quantity_per_copy
                .saturating_mul(copies.saturating_add(1))
                .saturating_sub(have);
            (shortfall > 0).then(|| MissingItem {
                type_id: req.type_id,
                type_name: req.type_name.clone(),
                quantity: shortfall,
            })
        })
        .collect();
    let multibuy_block = build_multibuy_block(&missing_for_next_copy);
    tracing::debug!(
        "[PANTRY] readiness copies={} ratio={:.3} missing_lines={}",
        copies,
        completion_ratio,
        missing_for_next_copy.len()
    );
    FitReadiness {
        buildable_copies: copies,
        completion_ratio,
        missing_for_next_copy,
        multibuy_block,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn req(type_id: i64, name: &str, need: i64) -> FitRequirement {
        FitRequirement {
            type_id,
            type_name: name.to_string(),
            quantity_per_copy: need,
        }
    }

    fn avail(pairs: &[(i64, i64)]) -> HashMap<i64, i64> {
        pairs.iter().copied().collect()
    }

    #[test]
    fn exact_copies_use_floor_of_the_bottleneck() {
        // Hull x1 have 3, module x4 have 9 -> floor(9/4)=2 wins.
        let readiness = compute_readiness(
            &[req(587, "Rifter", 1), req(100, "Gyrostabilizer", 4)],
            &avail(&[(587, 3), (100, 9)]),
        );
        assert_eq!(readiness.buildable_copies, 2);
        // Next copy needs 3 gyros (12 - 9); hull already covers it.
        assert_eq!(
            readiness.missing_for_next_copy,
            vec![MissingItem {
                type_id: 100,
                type_name: "Gyrostabilizer".to_string(),
                quantity: 3
            }]
        );
        assert_eq!(readiness.multibuy_block, "Gyrostabilizer x3");
    }

    #[test]
    fn missing_type_and_zero_have_yield_zero_copies() {
        let readiness = compute_readiness(
            &[req(587, "Rifter", 1), req(200, "Nanofiber", 2)],
            &avail(&[(587, 5)]),
        );
        assert_eq!(readiness.buildable_copies, 0);
        assert_eq!(readiness.missing_for_next_copy.len(), 1);
        assert_eq!(readiness.missing_for_next_copy[0].quantity, 2);
        // One of three needed units present toward the first copy.
        assert!((readiness.completion_ratio - (1.0 / 3.0)).abs() < 1e-9);
    }

    #[test]
    fn zero_need_requirements_are_ignored_not_bottlenecks() {
        let readiness = compute_readiness(
            &[req(1, "Freebie", 0), req(587, "Rifter", 2)],
            &avail(&[(587, 5)]),
        );
        assert_eq!(readiness.buildable_copies, 2);
        assert_eq!(readiness.completion_ratio, 1.0);
        // The zero-need line contributes nothing; the next copy
        // still needs 1 more Rifter (2*3 - 5).
        assert_eq!(readiness.missing_for_next_copy.len(), 1);
        assert_eq!(readiness.missing_for_next_copy[0].quantity, 1);
        assert_eq!(readiness.multibuy_block, "Rifter x1");
    }

    #[test]
    fn empty_and_all_zero_requirements_are_zero_not_panic() {
        for reqs in [Vec::new(), vec![req(1, "Freebie", 0)]] {
            let readiness = compute_readiness(&reqs, &avail(&[]));
            assert_eq!(readiness.buildable_copies, 0);
            assert_eq!(readiness.completion_ratio, 0.0);
            assert!(readiness.multibuy_block.is_empty());
        }
    }

    #[test]
    fn partial_ratio_counts_capped_progress_toward_one_copy() {
        // Need 10, have 4 -> 40% of one copy, 0 buildable.
        let readiness = compute_readiness(&[req(34, "Tritanium", 10)], &avail(&[(34, 4)]));
        assert_eq!(readiness.buildable_copies, 0);
        assert!((readiness.completion_ratio - 0.4).abs() < 1e-9);
        assert_eq!(readiness.missing_for_next_copy[0].quantity, 6);
        assert_eq!(readiness.multibuy_block, "Tritanium x6");
    }

    #[test]
    fn multibuy_block_sorts_by_name_and_skips_zero_lines() {
        let block = build_multibuy_block(&[
            MissingItem {
                type_id: 2,
                type_name: "Zeta".to_string(),
                quantity: 1,
            },
            MissingItem {
                type_id: 1,
                type_name: "Alpha".to_string(),
                quantity: 2,
            },
            MissingItem {
                type_id: 3,
                type_name: "Zero".to_string(),
                quantity: 0,
            },
        ]);
        assert_eq!(block, "Alpha x2\nZeta x1");
        assert_eq!(build_multibuy_block(&[]), "");
    }
}
