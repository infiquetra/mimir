//! Card #648 mining HUD suite: structural contract for
//! the Mining view (yield arcs, residue bars, ore-hold
//! countdown, Survey Scanner valuation) at both
//! viewports, plus Linux pixel goldens under
//! `tests/snapshots/card_648/`.

use egui_kittest::kittest::Queryable;
use mimir::app::state::View;

use crate::harness;

#[test]
fn mining_hud_structural_contract_at_both_viewports() {
    for size in harness::VIEWPORTS {
        let mut harness = harness::shell_harness(harness::demo_app(), size);
        harness::show_view(&mut harness, View::Mining);
        harness::assert_structural(&harness, View::Mining, size);
        // HUD sections actually paint (not an empty shell).
        let texts = harness::painter_texts(&harness.output().shapes);
        // Above-fold sections via painter text; ledger and
        // Survey Scanner sit below the pane fold at the
        // smaller viewport, asserted via AccessKit below.
        for expected in ["Live session", "Ore hold"] {
            assert!(
                texts.iter().any(|t| t.contains(expected)),
                "mining section {expected:?} missing at {size:?}"
            );
        }
        let _ledger = harness.get_by_label("Mining ledger");
        let _survey = harness.get_by_label("Survey Scanner");
    }
}

/// Pixel goldens anchored on Linux, one per viewport.
#[cfg(target_os = "linux")]
#[test]
fn card_648_mining_pixel_snapshots_linux() {
    if !harness::adapter_available_or_skip("card_648 mining pixel snapshots") {
        return;
    }
    let mut results = egui_kittest::SnapshotResults::default();
    for size in harness::VIEWPORTS {
        let mut harness = harness::shell_harness(harness::demo_app(), size);
        harness::show_view(&mut harness, View::Mining);
        harness::assert_structural(&harness, View::Mining, size);
        let name = harness::snapshot_name("card_648", View::Mining, size);
        harness.snapshot_options(name, &harness::snapshot_options());
        results.extend(harness.take_snapshot_results());
    }
    drop(results);
}
