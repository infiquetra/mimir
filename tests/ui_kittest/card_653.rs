//! Card #653 smoke suite: every view, both viewports,
//! structural AccessKit/bounds/raw-id assertions on every
//! OS, plus Linux-only pixel goldens for the four distinct
//! workspace presets under `tests/snapshots/card_653/`
//! (8 non-duplicate goldens; per-view pixel renders mostly
//! re-render the same workspace, so presets are the unit).

use std::time::{Duration, Instant};

use mimir::app::state::View;
use mimir::ui::tiles::Workspace;

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
fn bounds_checker_rejects_deliberately_offscreen_and_cutoff_widgets() {
    // Mutation regression (P1-3): the old clip-rect check
    // could not fail. Both an entirely off-screen button
    // and a screen-cut button must now produce Err, while
    // an on-screen button passes.
    let size = (1280.0, 800.0);
    let run_probe = |rect: egui::Rect| -> Result<(), String> {
        let mut harness = egui_kittest::Harness::builder()
            .with_size(egui::vec2(size.0, size.1))
            .with_step_dt(harness::STEP_DT)
            .build_ui_state(
                move |ui, _: &mut ()| {
                    ui.put(rect, egui::Button::new("Bounds probe"));
                },
                (),
            );
        harness.run_steps(2);
        harness::check_paint_bounds(&harness.output().shapes, size)
    };
    let on_screen = egui::Rect::from_min_size(egui::pos2(40.0, 40.0), egui::vec2(160.0, 32.0));
    assert!(run_probe(on_screen).is_ok(), "on-screen button must pass");
    let off_screen = egui::Rect::from_min_size(egui::pos2(5000.0, 5000.0), egui::vec2(160.0, 32.0));
    assert!(
        run_probe(off_screen).is_err(),
        "off-screen button must fail the bounds check"
    );
    let cut_off = egui::Rect::from_min_size(egui::pos2(1200.0, 40.0), egui::vec2(600.0, 32.0));
    assert!(
        run_probe(cut_off).is_err(),
        "screen-cut button must fail the bounds check"
    );
}

#[test]
fn every_view_structural_contract_at_both_viewports() {
    assert_eq!(View::ALL.len(), 13);
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

/// Pixel goldens are anchored on Linux (Lavapipe in CI):
/// one render per distinct workspace preset per viewport
/// (8 goldens), e.g.
/// `tests/snapshots/card_653/command_deck_1440x900.png`.
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
        for workspace in Workspace::ALL {
            let first = workspace.preset_views()[0];
            harness::show_view(&mut harness, first);
            harness::assert_structural(&harness, first, size);
            let name = format!(
                "card_653/{}_{}x{}",
                workspace.id_stem(),
                size.0 as u32,
                size.1 as u32
            );
            harness.snapshot_options(name, &harness::snapshot_options());
        }
        results.extend(harness.take_snapshot_results());
    }
    drop(results);
}
