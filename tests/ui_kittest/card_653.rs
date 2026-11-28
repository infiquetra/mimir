//! Card #653 smoke suite: every view, both viewports, structural
//! AccessKit/bounds/raw-id assertions on every OS, plus the
//! Linux-only pixel goldens under `tests/snapshots/card_653/`.

use std::time::{Duration, Instant};

use mimir::app::state::View;

use crate::harness;

#[test]
fn raw_eve_id_detector_matches_only_raw_patterns() {
    assert!(harness::contains_raw_eve_id("#90000001"));
    assert!(harness::contains_raw_eve_id("Item #34"));
    assert!(harness::contains_raw_eve_id("90000001"));
    assert!(!harness::contains_raw_eve_id("Tritanium"));
    assert!(!harness::contains_raw_eve_id("1,234,567 ISK"));
    assert!(!harness::contains_raw_eve_id("Skill level 5"));
    assert!(!harness::contains_raw_eve_id("#hashtag"));
}

#[test]
fn every_view_structural_contract_at_both_viewports() {
    assert_eq!(View::ALL.len(), 11);
    let started = Instant::now();
    for size in harness::VIEWPORTS {
        let mut harness = harness::shell_harness(harness::demo_app(), size);
        for view in View::ALL {
            harness::show_view(&mut harness, view);
            harness::assert_structural(&harness, view, size);
        }
    }
    let elapsed = started.elapsed();
    assert!(
        elapsed < Duration::from_secs(10),
        "[UI_KITTEST] structural suite took {elapsed:?}, budget is 10s"
    );
}

/// Pixel goldens are anchored on Linux (Lavapipe in CI). The file
/// name doubles as the snapshot name, e.g.
/// `tests/snapshots/card_653/dashboard_1440x900.png`.
#[cfg(target_os = "linux")]
#[test]
fn card_653_pixel_snapshots_linux() {
    if !harness::adapter_available_or_skip("card_653 pixel snapshots") {
        return;
    }
    // One merged SnapshotResults for both viewport harnesses, as
    // egui_kittest requires (it panics on unmerged drops).
    let mut results = egui_kittest::SnapshotResults::default();
    for size in harness::VIEWPORTS {
        let mut harness = harness::shell_harness(harness::demo_app(), size);
        for view in View::ALL {
            harness::show_view(&mut harness, view);
            harness::assert_structural(&harness, view, size);
            let name = harness::snapshot_name("card_653", view, size);
            harness.snapshot_options(name, &harness::snapshot_options());
        }
        results.extend(harness.take_snapshot_results());
    }
    drop(results);
}
