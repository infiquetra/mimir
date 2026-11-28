//! Card #642 Pantry suite: structural AccessKit/bounds/
//! raw-id contract for the Pantry view (virtualized
//! stockpile table + Fit-Readiness rings) at both
//! viewports, plus Linux pixel goldens under
//! `tests/snapshots/card_642/`.

use mimir::app::state::View;

use crate::harness;

#[test]
fn pantry_structural_contract_at_both_viewports() {
    for size in harness::VIEWPORTS {
        let mut harness = harness::shell_harness(harness::demo_app(), size);
        harness::show_view(&mut harness, View::Pantry);
        harness::assert_structural(&harness, View::Pantry, size);
        // The readiness surface must actually render in
        // demo mode (seeded characters + fittings), not an
        // empty shell: a readiness or stockpile label is
        // present in painter text.
        let texts = harness::painter_texts(&harness.output().shapes);
        assert!(
            texts.iter().any(|t| t.contains("Pantry")
                || t.contains("Fit-Readiness")
                || t.contains("Readiness")),
            "pantry readiness surface missing at {size:?}: {texts:?}"
        );
    }
}

/// Pixel goldens anchored on Linux, one per viewport.
#[cfg(target_os = "linux")]
#[test]
fn card_642_pantry_pixel_snapshots_linux() {
    if !harness::adapter_available_or_skip("card_642 pantry pixel snapshots") {
        return;
    }
    let mut results = egui_kittest::SnapshotResults::default();
    for size in harness::VIEWPORTS {
        let mut harness = harness::shell_harness(harness::demo_app(), size);
        harness::show_view(&mut harness, View::Pantry);
        harness::assert_structural(&harness, View::Pantry, size);
        let name = harness::snapshot_name("card_642", View::Pantry, size);
        harness.snapshot_options(name, &harness::snapshot_options());
        results.extend(harness.take_snapshot_results());
    }
    drop(results);
}
