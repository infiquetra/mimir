//! Card #646 exploration suite: structural contract for
//! the Exploration view including the real-edge Wormhole
//! Subway Chain Strip (ordered chain nodes with weather
//! badges, mass state, and EOL "<4h" markers), plus Linux
//! pixel goldens under `tests/snapshots/card_646/`.

use mimir::app::state::View;

use crate::harness;

#[test]
fn exploration_structural_contract_at_both_viewports() {
    for size in harness::VIEWPORTS {
        let mut harness = harness::shell_harness(harness::demo_app(), size);
        harness::show_view(&mut harness, View::Exploration);
        harness::assert_structural(&harness, View::Exploration, size);
        // Subway strip node cards actually paint: class
        // labels for several wormhole classes present.
        let texts = harness::painter_texts(&harness.output().shapes);
        for class in ["C1", "C3", "C6"] {
            assert!(
                texts.iter().any(|t| t == class),
                "subway class {class} missing at {size:?}"
            );
        }
        assert!(
            texts.iter().any(|t| t.contains("Wormhole subway chain")),
            "subway strip heading missing at {size:?}"
        );
        // AC4: the demo chain carries an under-4h edge, so
        // the EOL marker must render (dashed connector is
        // pixel-level; the text marker is the paint proof).
        assert!(
            texts.iter().any(|t| t.contains("EOL <4h")),
            "EOL <4h marker missing at {size:?}: {texts:?}"
        );
        // R10 mass dimension: a public leg renders the "Mass
        // not reported" state (elided to "Mass not..." at the
        // narrow pane pitch) and known-mass legs render their
        // grouped kg figure (likewise elided when narrow).
        assert!(
            texts.iter().any(|t| t.contains("Mass not")),
            "Mass not reported label missing at {size:?}"
        );
        assert!(
            texts.iter().any(|t| t.contains("375,000")),
            "known mass label missing at {size:?}"
        );
        // Weather badge on chain nodes.
        assert!(
            texts.iter().any(|t| {
                t.contains("effect")
                    || t.contains("Pulsar")
                    || t.contains("Magnetar")
                    || t.contains("Cataclysmic")
                    || t.contains("Black Hole")
                    || t.contains("Red Giant")
                    || t.contains("Wolf-Rayet")
            }),
            "weather badge missing at {size:?}"
        );
    }
}

/// Pixel goldens anchored on Linux, one per viewport.
#[cfg(target_os = "linux")]
#[test]
fn card_646_exploration_pixel_snapshots_linux() {
    if !harness::adapter_available_or_skip("card_646 exploration pixel snapshots") {
        return;
    }
    let mut results = egui_kittest::SnapshotResults::default();
    for size in harness::VIEWPORTS {
        let mut harness = harness::shell_harness(harness::demo_app(), size);
        harness::show_view(&mut harness, View::Exploration);
        harness::assert_structural(&harness, View::Exploration, size);
        let name = harness::snapshot_name("card_646", View::Exploration, size);
        harness.snapshot_options(name, &harness::snapshot_options());
        results.extend(harness.take_snapshot_results());
    }
    drop(results);
}
