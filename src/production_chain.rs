//! Pure production chain calculation for the Industry view's
//! Production Chain Calculator block.
//!
//! The traversal corrects the retired Flutter builder at `ed698d3`
//! (`lib/features/industry/domain/production_chain_builder.dart`), whose
//! probe treated each material type as if it were its own blueprint type.
//! Scripted over the shipped industry file, no product or material type is
//! also a blueprint type, so that probe expanded nothing on real data.
//! This module walks product to blueprint through the reverse index in
//! `crate::names::industry_ref` (`blueprints_producing`), then blueprint to
//! materials through the per-activity accessors, keeping Flutter's tree
//! shape, file-order children, and manufacturing-before-reaction candidate
//! ordering (observable only in ordering, never a tie-break).
//!
//! Quantities are whole-run arithmetic derived from the per-run meanings
//! the shipped reaction slice locked: materials are per-run inputs and the
//! product quantity is per-run output. For a wanted quantity the runs
//! needed are the smallest whole number making at least that quantity,
//! `runs = (quantity - 1) / batch + 1`, and each child input scales by
//! runs with checked multiplication. No efficiency, bonus, skill, or
//! leftover-netting adjustment is applied. See
//! `docs/production-chain-design.md`.
//!
//! Ambiguous products (more than one producing blueprint) are never
//! expanded as if one recipe were the recipe, and a product already on the
//! ancestor path is rendered once as a cycle leaf and never expanded
//! again. Depth and expansion budgets render honest truncated leaves.
//!
//! The module is pure computation — no egui, no `AppState`, no network,
//! no database, no `include_str!`. It logs nothing: it runs at render
//! cadence, so per-frame logging would spam the log. Data comes from the
//! bundled industry data via `&IndustryRef`; tests build graphs through
//! `IndustryRef::from_json` fixtures.

use crate::names::industry_ref::IndustryRef;

/// Flutter's starting quantity (`1`, units of the chosen item): the
/// `AppState` draft seed, labelled as a user-entered starting value,
/// never a derived figure. Quantity is units wanted, not runs.
pub const DEFAULT_QUANTITY: i64 = 1;

/// Implementation safety bound on chain depth (root = 0), above the
/// shipped data's scripted maximum depth of 7. A node at this depth is
/// rendered as a truncated leaf, never silently cut. Not an EVE rule.
pub const MAX_CHAIN_DEPTH: usize = 16;

/// Implementation safety bound on expanded produced nodes per chain,
/// above the shipped data's worst tree of 2,265 nodes. A node reached
/// with the budget exhausted is rendered as a truncated leaf. Not an
/// EVE rule.
pub const MAX_CHAIN_EXPANSIONS: usize = 5_000;

/// Classification of one chain node: whether it was expanded, or why
/// it is an honest leaf.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ChainNodeKind {
    Produced,
    RawMaterial,
    Cycle,
    MultipleBlueprints,
    Truncated,
}

/// One node of the production chain tree. `production_activity_id` is
/// `Some(activity)` exactly for `Produced` and `Truncated` nodes (a
/// truncated node has a known single producer it did not expand) and
/// `None` for leaf kinds. `dependencies` is non-empty exactly for
/// `Produced`. Names are resolved by the view, never here.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ChainNode {
    pub type_id: i64,
    pub quantity_required: i64,
    pub production_activity_id: Option<i64>,
    pub kind: ChainNodeKind,
    pub dependencies: Vec<ChainNode>,
}

/// Parse a quantity draft: trim, parse as `i64`, accept only a value of
/// at least 1. No comma stripping — on a whole-number count a comma is a
/// typo, not a thousands separator. No upper bound at parse time.
pub fn parse_quantity(text: &str) -> Option<i64> {
    let value: i64 = text.trim().parse().ok()?;
    if value >= 1 {
        Some(value)
    } else {
        None
    }
}

/// Whole-run count for a wanted quantity and a per-run batch: the
/// smallest whole number of runs making at least the quantity.
fn whole_runs(quantity: i64, batch: i64) -> Option<i64> {
    if quantity < 1 || batch < 1 {
        return None;
    }
    Some((quantity - 1) / batch + 1)
}

/// Recursive walk for `build_chain`. `ancestors` holds the products from
/// the root to the parent of `product`; `budget` counts the produced
/// nodes still allowed for the whole tree. Returns `None` for any input
/// or row that fails section 7 validation, failing the whole build.
#[allow(clippy::too_many_arguments)]
fn build_node(
    industry_data: &IndustryRef,
    product: i64,
    quantity: i64,
    depth: usize,
    ancestors: &[i64],
    budget: &mut usize,
) -> Option<ChainNode> {
    if product <= 0 || quantity < 1 {
        return None;
    }
    if ancestors.contains(&product) {
        return Some(ChainNode {
            type_id: product,
            quantity_required: quantity,
            production_activity_id: None,
            kind: ChainNodeKind::Cycle,
            dependencies: Vec::new(),
        });
    }
    let candidates = industry_data.blueprints_producing(product);
    if candidates.is_empty() {
        return Some(ChainNode {
            type_id: product,
            quantity_required: quantity,
            production_activity_id: None,
            kind: ChainNodeKind::RawMaterial,
            dependencies: Vec::new(),
        });
    }
    if candidates.len() > 1 {
        return Some(ChainNode {
            type_id: product,
            quantity_required: quantity,
            production_activity_id: None,
            kind: ChainNodeKind::MultipleBlueprints,
            dependencies: Vec::new(),
        });
    }
    let blueprint = candidates[0];
    let product_row = industry_data.product_row_for(blueprint, product)?;
    if product_row.type_id <= 0
        || product_row.product_type_id <= 0
        || product_row.quantity <= 0
        || blueprint <= 0
    {
        return None;
    }
    let activity = product_row.activity_id;
    let materials = match activity {
        crate::names::industry_ref::MANUFACTURING_ACTIVITY_ID => {
            industry_data.manufacturing_materials(blueprint)?
        }
        crate::names::industry_ref::REACTION_ACTIVITY_ID => {
            industry_data.reaction_materials(blueprint)?
        }
        _ => return None,
    };
    if materials.is_empty() {
        return None;
    }
    for row in &materials {
        if row.type_id <= 0 || row.material_type_id <= 0 || row.quantity <= 0 {
            return None;
        }
    }
    if depth == MAX_CHAIN_DEPTH || *budget == 0 {
        return Some(ChainNode {
            type_id: product,
            quantity_required: quantity,
            production_activity_id: Some(activity),
            kind: ChainNodeKind::Truncated,
            dependencies: Vec::new(),
        });
    }
    *budget -= 1;
    let batch = product_row.quantity;
    let runs = whole_runs(quantity, batch)?;
    let mut child_ancestors: Vec<i64> = ancestors.to_vec();
    child_ancestors.push(product);
    let mut dependencies = Vec::with_capacity(materials.len());
    for row in &materials {
        let child_qty = row.quantity.checked_mul(runs)?;
        let child = build_node(
            industry_data,
            row.material_type_id,
            child_qty,
            depth + 1,
            &child_ancestors,
            budget,
        )?;
        dependencies.push(child);
    }
    Some(ChainNode {
        type_id: product,
        quantity_required: quantity,
        production_activity_id: Some(activity),
        kind: ChainNodeKind::Produced,
        dependencies,
    })
}

/// Build the production chain for one product and wanted quantity, or
/// `None` when the ids or quantity are invalid, any row the expansion
/// reads is invalid or unreadable, or any multiplication overflows
/// `i64`. Cycle, ambiguous, and truncated nodes are `Some` results.
pub fn build_chain(
    industry_data: &IndustryRef,
    product_type_id: i64,
    quantity: i64,
) -> Option<ChainNode> {
    let mut budget = MAX_CHAIN_EXPANSIONS;
    build_node(
        industry_data,
        product_type_id,
        quantity,
        0,
        &[],
        &mut budget,
    )
}

/// The renderer's one call: parse the quantity text and build the chain,
/// returning `Some` only when the parse and the build both succeed.
pub fn production_chain_result(
    industry_data: &IndustryRef,
    product_type_id: i64,
    quantity_text: &str,
) -> Option<ChainNode> {
    let quantity = parse_quantity(quantity_text)?;
    build_chain(industry_data, product_type_id, quantity)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::names::industry_ref::IndustryRef;

    fn fixture() -> IndustryRef {
        let json = r#"{"materials":[{"typeId":100,"activityId":1,"materialTypeId":200,"quantity":2},{"typeId":100,"activityId":1,"materialTypeId":34,"quantity":5},{"typeId":101,"activityId":11,"materialTypeId":34,"quantity":7},{"typeId":102,"activityId":1,"materialTypeId":401,"quantity":1},{"typeId":103,"activityId":1,"materialTypeId":400,"quantity":3},{"typeId":103,"activityId":1,"materialTypeId":34,"quantity":2},{"typeId":104,"activityId":1,"materialTypeId":500,"quantity":1},{"typeId":104,"activityId":1,"materialTypeId":34,"quantity":3},{"typeId":105,"activityId":1,"materialTypeId":34,"quantity":1},{"typeId":106,"activityId":1,"materialTypeId":34,"quantity":9},{"typeId":107,"activityId":1,"materialTypeId":600,"quantity":2},{"typeId":107,"activityId":1,"materialTypeId":34,"quantity":1},{"typeId":108,"activityId":1,"materialTypeId":34,"quantity":2},{"typeId":109,"activityId":1,"materialTypeId":34,"quantity":1}],"products":[{"typeId":100,"activityId":1,"productTypeId":300,"quantity":1},{"typeId":101,"activityId":11,"productTypeId":200,"quantity":10},{"typeId":102,"activityId":1,"productTypeId":400,"quantity":1},{"typeId":103,"activityId":1,"productTypeId":401,"quantity":1},{"typeId":104,"activityId":1,"productTypeId":500,"quantity":1},{"typeId":105,"activityId":1,"productTypeId":600,"quantity":1},{"typeId":106,"activityId":1,"productTypeId":600,"quantity":1},{"typeId":107,"activityId":1,"productTypeId":700,"quantity":1},{"typeId":108,"activityId":1,"productTypeId":800,"quantity":1},{"typeId":109,"activityId":1,"productTypeId":900,"quantity":1}]}"#;
        IndustryRef::from_json(json).expect("fixture loads")
    }

    fn preorder(node: &ChainNode) -> Vec<(i64, i64, ChainNodeKind, Option<i64>, usize)> {
        let mut out = Vec::new();
        fn walk(
            node: &ChainNode,
            depth: usize,
            out: &mut Vec<(i64, i64, ChainNodeKind, Option<i64>, usize)>,
        ) {
            out.push((
                node.type_id,
                node.quantity_required,
                node.kind,
                node.production_activity_id,
                depth,
            ));
            for child in &node.dependencies {
                walk(child, depth + 1, out);
            }
        }
        walk(node, 0, &mut out);
        out
    }

    fn count_kind(node: &ChainNode, kind: &ChainNodeKind) -> usize {
        let mut count = if &node.kind == kind { 1 } else { 0 };
        for child in &node.dependencies {
            count += count_kind(child, kind);
        }
        count
    }

    #[test]
    fn fixture_batch_runs_drive_children() {
        let fx = fixture();
        let chain = build_chain(&fx, 300, 1).expect("chain for 300 x1");
        assert_eq!(
            preorder(&chain),
            vec![
                (300, 1, ChainNodeKind::Produced, Some(1), 0),
                (200, 2, ChainNodeKind::Produced, Some(11), 1),
                (34, 7, ChainNodeKind::RawMaterial, None, 2),
                (34, 5, ChainNodeKind::RawMaterial, None, 1),
            ]
        );
        // 200 child qty 12: runs = ceil(12/10) = 2, so 7*2 = 14.
        // Direct 34 child qty 30: 5 * 6 runs of the root.
        let chain = build_chain(&fx, 300, 6).expect("chain for 300 x6");
        assert_eq!(
            preorder(&chain),
            vec![
                (300, 6, ChainNodeKind::Produced, Some(1), 0),
                (200, 12, ChainNodeKind::Produced, Some(11), 1),
                (34, 14, ChainNodeKind::RawMaterial, None, 2),
                (34, 30, ChainNodeKind::RawMaterial, None, 1),
            ]
        );
        // Exactly one batch of 10: runs 1, child 7.
        let chain = build_chain(&fx, 200, 10).expect("chain for 200 x10");
        assert_eq!(
            preorder(&chain),
            vec![
                (200, 10, ChainNodeKind::Produced, Some(11), 0),
                (34, 7, ChainNodeKind::RawMaterial, None, 1),
            ]
        );
        // One unit over: runs 2, child 14.
        let chain = build_chain(&fx, 200, 11).expect("chain for 200 x11");
        assert_eq!(
            preorder(&chain),
            vec![
                (200, 11, ChainNodeKind::Produced, Some(11), 0),
                (34, 14, ChainNodeKind::RawMaterial, None, 1),
            ]
        );
    }

    #[test]
    fn fixture_cycle_ambiguous_and_leaves() {
        let fx = fixture();
        let chain = build_chain(&fx, 400, 1).expect("chain for 400");
        assert_eq!(
            preorder(&chain),
            vec![
                (400, 1, ChainNodeKind::Produced, Some(1), 0),
                (401, 1, ChainNodeKind::Produced, Some(1), 1),
                (400, 3, ChainNodeKind::Cycle, None, 2),
                (34, 2, ChainNodeKind::RawMaterial, None, 2),
            ]
        );
        let chain = build_chain(&fx, 500, 1).expect("chain for 500");
        assert_eq!(
            preorder(&chain),
            vec![
                (500, 1, ChainNodeKind::Produced, Some(1), 0),
                (500, 1, ChainNodeKind::Cycle, None, 1),
                (34, 3, ChainNodeKind::RawMaterial, None, 1),
            ]
        );
        let chain = build_chain(&fx, 600, 4).expect("chain for 600");
        assert_eq!(
            preorder(&chain),
            vec![(600, 4, ChainNodeKind::MultipleBlueprints, None, 0)]
        );
        assert!(chain.dependencies.is_empty());
        let chain = build_chain(&fx, 700, 1).expect("chain for 700");
        assert_eq!(
            preorder(&chain),
            vec![
                (700, 1, ChainNodeKind::Produced, Some(1), 0),
                (600, 2, ChainNodeKind::MultipleBlueprints, None, 1),
                (34, 1, ChainNodeKind::RawMaterial, None, 1),
            ]
        );
        let chain = build_chain(&fx, 34, 1).expect("chain for raw 34");
        assert_eq!(
            preorder(&chain),
            vec![(34, 1, ChainNodeKind::RawMaterial, None, 0)]
        );
        let chain = build_chain(&IndustryRef::default(), 300, 1).expect("chain on default");
        assert_eq!(
            preorder(&chain),
            vec![(300, 1, ChainNodeKind::RawMaterial, None, 0)]
        );
    }

    #[test]
    fn depth_limit_truncates_linear_chain() {
        let mut materials = String::new();
        let mut products = String::new();
        for i in 0..20 {
            let blueprint = 1000 + i;
            let product = 2000 + i;
            let child = 2001 + i;
            if i > 0 {
                materials.push(',');
                products.push(',');
            }
            materials.push_str(&format!(
                r#"{{"typeId":{blueprint},"activityId":1,"materialTypeId":{child},"quantity":1}}"#
            ));
            products.push_str(&format!(
                r#"{{"typeId":{blueprint},"activityId":1,"productTypeId":{product},"quantity":1}}"#
            ));
        }
        let json = format!(r#"{{"materials":[{materials}],"products":[{products}]}}"#);
        let data = IndustryRef::from_json(&json).expect("linear chain loads");
        let chain = build_chain(&data, 2000, 1).expect("linear chain builds");
        let rows = preorder(&chain);
        assert_eq!(rows.len(), 17);
        for (depth, row) in rows.iter().enumerate() {
            assert_eq!(row.4, depth);
            if depth < 16 {
                assert_eq!(row.2, ChainNodeKind::Produced, "depth {depth}");
                assert_eq!(row.3, Some(1));
            } else {
                assert_eq!(row.2, ChainNodeKind::Truncated);
                assert_eq!(row.3, Some(1));
            }
        }
        assert_eq!(count_kind(&chain, &ChainNodeKind::Produced), 16);
        assert_eq!(count_kind(&chain, &ChainNodeKind::Truncated), 1);
    }

    #[test]
    fn expansion_budget_truncates_fanout() {
        let mut materials = String::new();
        let mut products = String::new();
        let mut first = true;
        let mut first_product = true;
        let add = |blueprint: i64,
                   product: i64,
                   children: &[i64],
                   materials: &mut String,
                   products: &mut String,
                   first: &mut bool,
                   first_product: &mut bool| {
            for child in children {
                if !*first {
                    materials.push(',');
                }
                *first = false;
                materials.push_str(&format!(
                    r#"{{"typeId":{blueprint},"activityId":1,"materialTypeId":{child},"quantity":1}}"#
                ));
            }
            if !*first_product {
                products.push(',');
            }
            *first_product = false;
            products.push_str(&format!(
                r#"{{"typeId":{blueprint},"activityId":1,"productTypeId":{product},"quantity":1}}"#
            ));
        };
        let root_children: Vec<i64> = (0..10).map(|i| 3100 + i).collect();
        add(
            5000,
            3000,
            &root_children,
            &mut materials,
            &mut products,
            &mut first,
            &mut first_product,
        );
        for i in 0..10 {
            let level1: Vec<i64> = (0..10).map(|j| 3200 + j).collect();
            add(
                5100 + i,
                3100 + i,
                &level1,
                &mut materials,
                &mut products,
                &mut first,
                &mut first_product,
            );
        }
        for i in 0..10 {
            let level2: Vec<i64> = (0..10).map(|j| 3300 + j).collect();
            add(
                5200 + i,
                3200 + i,
                &level2,
                &mut materials,
                &mut products,
                &mut first,
                &mut first_product,
            );
        }
        for i in 0..10 {
            let level3: Vec<i64> = (0..10).map(|j| 3400 + j).collect();
            add(
                5300 + i,
                3300 + i,
                &level3,
                &mut materials,
                &mut products,
                &mut first,
                &mut first_product,
            );
        }
        for i in 0..10 {
            add(
                5400 + i,
                3400 + i,
                &[34],
                &mut materials,
                &mut products,
                &mut first,
                &mut first_product,
            );
        }
        let json = format!(r#"{{"materials":[{materials}],"products":[{products}]}}"#);
        let data = IndustryRef::from_json(&json).expect("fanout loads");
        let chain = build_chain(&data, 3000, 1).expect("fanout builds");
        assert_eq!(
            count_kind(&chain, &ChainNodeKind::Produced),
            MAX_CHAIN_EXPANSIONS
        );
        assert!(count_kind(&chain, &ChainNodeKind::Truncated) >= 1);
    }

    #[test]
    fn validation_and_overflow_matrix() {
        let fx = fixture();
        assert_eq!(build_chain(&fx, 0, 1), None);
        assert_eq!(build_chain(&fx, -1, 1), None);
        assert_eq!(build_chain(&fx, 300, 0), None);
        assert_eq!(build_chain(&fx, 300, -1), None);
        // 2 * i64::MAX overflows: blueprint 108 needs 2 of raw 34 per run.
        assert_eq!(build_chain(&fx, 800, i64::MAX), None);
        let chain = build_chain(&fx, 900, i64::MAX).expect("900 at max is exact");
        assert_eq!(
            preorder(&chain),
            vec![
                (900, i64::MAX, ChainNodeKind::Produced, Some(1), 0),
                (34, i64::MAX, ChainNodeKind::RawMaterial, None, 1),
            ]
        );
        let chain = build_chain(&fx, 34, i64::MAX).expect("raw at max has no multiply");
        assert_eq!(
            preorder(&chain),
            vec![(34, i64::MAX, ChainNodeKind::RawMaterial, None, 0)]
        );
    }

    #[test]
    fn parser_and_result_cases() {
        assert_eq!(parse_quantity("1"), Some(1));
        assert_eq!(parse_quantity(" 10 "), Some(10));
        assert_eq!(parse_quantity("9223372036854775807"), Some(i64::MAX));
        for text in ["", "0", "-1", "1.5", "1,000", "abc"] {
            assert_eq!(parse_quantity(text), None, "quantity text {text:?}");
        }
        let fx = fixture();
        let expected = build_chain(&fx, 300, 1).expect("300 x1");
        assert_eq!(
            production_chain_result(&fx, 300, "1"),
            Some(expected.clone())
        );
        assert_eq!(production_chain_result(&fx, 300, ""), None);
        assert_eq!(production_chain_result(&fx, 300, "0"), None);
        assert_eq!(
            production_chain_result(&fx, 800, "9223372036854775807"),
            None
        );
    }

    #[test]
    fn defaults_match_design() {
        assert_eq!(DEFAULT_QUANTITY, 1);
        assert_eq!(MAX_CHAIN_DEPTH, 16);
        assert_eq!(MAX_CHAIN_EXPANSIONS, 5_000);
    }

    #[test]
    fn real_data_small_blaster_battery_trees() {
        let data = IndustryRef::load_bundled().expect("bundled loads");
        let chain = build_chain(&data, 34, 1).expect("Tritanium chain");
        assert_eq!(
            preorder(&chain),
            vec![(34, 1, ChainNodeKind::RawMaterial, None, 0)]
        );
        let chain = build_chain(&data, 17404, 1).expect("Small Blaster Battery x1");
        assert_eq!(
            preorder(&chain),
            vec![
                (17404, 1, ChainNodeKind::Produced, Some(1), 0),
                (2872, 1, ChainNodeKind::RawMaterial, None, 1),
                (564, 1, ChainNodeKind::Produced, Some(1), 1),
                (34, 1596, ChainNodeKind::RawMaterial, None, 2),
                (35, 690, ChainNodeKind::RawMaterial, None, 2),
                (36, 144, ChainNodeKind::RawMaterial, None, 2),
            ]
        );
        let chain = build_chain(&data, 17404, 3).expect("Small Blaster Battery x3");
        assert_eq!(
            preorder(&chain),
            vec![
                (17404, 3, ChainNodeKind::Produced, Some(1), 0),
                (2872, 3, ChainNodeKind::RawMaterial, None, 1),
                (564, 3, ChainNodeKind::Produced, Some(1), 1),
                (34, 4788, ChainNodeKind::RawMaterial, None, 2),
                (35, 2070, ChainNodeKind::RawMaterial, None, 2),
                (36, 432, ChainNodeKind::RawMaterial, None, 2),
            ]
        );
    }

    #[test]
    fn real_data_carbon_fiber_trees() {
        let data = IndustryRef::load_bundled().expect("bundled loads");
        let chain = build_chain(&data, 57453, 1).expect("Carbon Fiber x1");
        assert_eq!(
            preorder(&chain),
            vec![
                (57453, 1, ChainNodeKind::Produced, Some(11), 0),
                (4246, 5, ChainNodeKind::Produced, Some(1), 1),
                (9848, 1, ChainNodeKind::RawMaterial, None, 2),
                (44, 4, ChainNodeKind::RawMaterial, None, 2),
                (3689, 4, ChainNodeKind::RawMaterial, None, 2),
                (9832, 9, ChainNodeKind::RawMaterial, None, 2),
                (16275, 20, ChainNodeKind::RawMaterial, None, 2),
                (3683, 22, ChainNodeKind::RawMaterial, None, 2),
                (16272, 170, ChainNodeKind::RawMaterial, None, 2),
                (16273, 350, ChainNodeKind::RawMaterial, None, 2),
                (17889, 450, ChainNodeKind::RawMaterial, None, 2),
                (16633, 100, ChainNodeKind::RawMaterial, None, 1),
                (16635, 100, ChainNodeKind::RawMaterial, None, 1),
            ]
        );
        let chain = build_chain(&data, 57453, 201).expect("Carbon Fiber x201");
        assert_eq!(
            preorder(&chain),
            vec![
                (57453, 201, ChainNodeKind::Produced, Some(11), 0),
                (4246, 10, ChainNodeKind::Produced, Some(1), 1),
                (9848, 1, ChainNodeKind::RawMaterial, None, 2),
                (44, 4, ChainNodeKind::RawMaterial, None, 2),
                (3689, 4, ChainNodeKind::RawMaterial, None, 2),
                (9832, 9, ChainNodeKind::RawMaterial, None, 2),
                (16275, 20, ChainNodeKind::RawMaterial, None, 2),
                (3683, 22, ChainNodeKind::RawMaterial, None, 2),
                (16272, 170, ChainNodeKind::RawMaterial, None, 2),
                (16273, 350, ChainNodeKind::RawMaterial, None, 2),
                (17889, 450, ChainNodeKind::RawMaterial, None, 2),
                (16633, 200, ChainNodeKind::RawMaterial, None, 1),
                (16635, 200, ChainNodeKind::RawMaterial, None, 1),
            ]
        );
    }

    #[test]
    fn real_data_cycle_ambiguous_and_worst_trees() {
        let data = IndustryRef::load_bundled().expect("bundled loads");
        let chain = build_chain(&data, 12238, 1).expect("Reprocessing Array");
        assert_eq!(
            preorder(&chain),
            vec![
                (12238, 1, ChainNodeKind::Produced, Some(1), 0),
                (12238, 1, ChainNodeKind::Cycle, None, 1),
            ]
        );
        let chain = build_chain(&data, 11543, 1).expect("Tungsten Carbide Armor Plate");
        let rows = preorder(&chain);
        assert_eq!(rows.len(), 39);
        assert_eq!(
            rows[1],
            (16672, 44, ChainNodeKind::MultipleBlueprints, None, 1)
        );
        assert_eq!(rows[2], (16678, 11, ChainNodeKind::Produced, Some(11), 1));
        let chain = build_chain(&data, 16672, 1).expect("ambiguous root");
        assert_eq!(
            preorder(&chain),
            vec![(16672, 1, ChainNodeKind::MultipleBlueprints, None, 0)]
        );
        let chain = build_chain(&data, 77288, 1).expect("Valravn");
        let rows = preorder(&chain);
        assert_eq!(rows.len(), 2265);
        assert_eq!(rows.iter().map(|row| row.4).max(), Some(7));
    }

    fn cycle_parents_only_and_at_qty1(node: &ChainNode) -> bool {
        if node.kind == ChainNodeKind::Cycle {
            return true;
        }
        for child in &node.dependencies {
            if child.kind == ChainNodeKind::Cycle
                && (node.dependencies.len() != 1 || child.quantity_required != 1)
            {
                return false;
            }
            if !cycle_parents_only_and_at_qty1(child) {
                return false;
            }
        }
        true
    }

    #[test]
    fn caps_unreachable_over_shipped_catalogue() {
        let data = IndustryRef::load_bundled().expect("bundled loads");
        let mut max_depth = 0;
        let mut max_nodes = 0;
        let mut cycle_trees = 0;
        for &product in data.buildable_product_type_ids() {
            let chain = build_chain(&data, product, 1)
                .unwrap_or_else(|| panic!("chain for buildable product {product} must be Some"));
            let rows = preorder(&chain);
            max_depth = max_depth.max(rows.iter().map(|row| row.4).max().unwrap_or(0));
            max_nodes = max_nodes.max(rows.len());
            assert_eq!(
                count_kind(&chain, &ChainNodeKind::Truncated),
                0,
                "no Truncated node for product {product}"
            );
            if rows.iter().any(|row| row.2 == ChainNodeKind::Cycle) {
                cycle_trees += 1;
                assert!(
                    cycle_parents_only_and_at_qty1(&chain),
                    "cycle parent shape for product {product}"
                );
            }
        }
        assert_eq!(max_depth, 7);
        assert_eq!(max_nodes, 2265);
        assert_eq!(cycle_trees, 51);
    }
}
