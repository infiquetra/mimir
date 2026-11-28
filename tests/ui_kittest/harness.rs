//! Shared demo-seeded `MimirApp` frame runner for `ui_kittest`.
//!
//! Determinism: fixed timestep (`with_step_dt(1/60)`), harness
//! default `RendererOptions::PREDICTABLE` (`msaa_samples = 1`, i.e.
//! sample_count 1; the wgpu snapshot texture is also created with
//! `sample_count: 1` in egui_kittest 0.37), cursor blink and scroll
//! animation disabled by the harness itself. Demo mode only: the
//! app is built with no backends, no runtime, and no database, so
//! a frame can neither touch disk nor the network.

use std::sync::{Arc, Mutex};
use std::time::Duration;

use egui_kittest::kittest::NodeT;
use egui_kittest::{Harness, SnapshotOptions};
use mimir::app::state::View;
use mimir::MimirApp;

/// Viewports exercised for every `View::ALL` variant.
pub const VIEWPORTS: [(f32, f32); 2] = [(1440.0, 900.0), (1280.0, 800.0)];

/// Fixed frame step for every harness in this suite.
pub const STEP_DT: f32 = 1.0 / 60.0;

/// Bounds tolerance in logical points: AccessKit/paint rects may
/// overshoot the screen rect by at most this much (antialiasing
/// feathering on panel edges) before a view counts as clipped.
pub const BOUNDS_TOLERANCE: f32 = 2.0;

/// Build a demo-seeded app with zero backends (in-memory only).
pub fn demo_app() -> MimirApp {
    MimirApp::new(true, Arc::new(Mutex::new(Vec::new())), None, None)
}

/// Build a harness at `size` around `app`, rendering the real shell.
pub fn shell_harness(app: MimirApp, size: (f32, f32)) -> Harness<'static, MimirApp> {
    Harness::builder()
        .with_size(egui::vec2(size.0, size.1))
        .with_step_dt(STEP_DT)
        .with_max_steps(8)
        .build_ui_state(|ui, app: &mut MimirApp| app.show_shell_for_kittest(ui), app)
}

/// Switch the harness app to `view` and settle a few fixed frames.
pub fn show_view(harness: &mut Harness<'_, MimirApp>, view: View) {
    harness.state_mut().apply_initial_view(view);
    harness.run_steps(3);
}

/// Per-card snapshot name, e.g. `card_653/dashboard_1440x900`.
pub fn snapshot_name(card: &str, view: View, size: (f32, f32)) -> String {
    format!(
        "{card}/{}_{}x{}",
        view.label().to_ascii_lowercase(),
        size.0 as u32,
        size.1 as u32
    )
}

/// Snapshot options anchored on `tests/snapshots` with the
/// `kittest.toml` thresholds (0.6 YIQ, zero failed pixels).
pub fn snapshot_options() -> SnapshotOptions {
    SnapshotOptions::new().output_path("tests/snapshots")
}

/// True when text looks like a raw EVE identifier: a `#<digits>`
/// fallback or a whole label that is one bare number of 7+ digits.
/// Formatted quantities (commas, units, decimals) never match.
pub fn contains_raw_eve_id(text: &str) -> bool {
    let bytes = text.as_bytes();
    for (i, b) in bytes.iter().enumerate() {
        if *b == b'#' && bytes.get(i + 1).is_some_and(u8::is_ascii_digit) {
            return true;
        }
    }
    let trimmed = text.trim();
    trimmed.len() >= 7 && trimmed.bytes().all(|b| b.is_ascii_digit())
}

/// Assert the cross-OS structural contract for the current frame:
/// every interactive widget has an accessible name (the harness
/// accessibility check panics otherwise), every paint clip rect
/// stays inside the screen rect (within [`BOUNDS_TOLERANCE`]),
/// and no AccessKit name or value carries a raw EVE identifier.
/// AccessKit bounds are unclipped layout rects: scroll-area and
/// tile-pane content legitimately extends past the screen, so
/// rendered bounds are proven at the paint layer (every non-empty
/// clip rect inside the screen) while AccessKit rects must only
/// be finite.
pub fn assert_structural(harness: &Harness<'_, MimirApp>, view: View, size: (f32, f32)) {
    harness.check_accessibility();
    let screen = egui::Rect::from_min_size(egui::Pos2::ZERO, egui::vec2(size.0, size.1));
    let allowed = screen.expand(BOUNDS_TOLERANCE);

    let root = harness.root();
    let mut nodes = 0usize;
    let mut interactive = 0usize;
    for node in root.children_recursive() {
        nodes += 1;
        let ak = node.accesskit_node();
        if let Some(label) = ak.label() {
            assert!(
                !contains_raw_eve_id(&label),
                "[UI_KITTEST] view {} at {}x{}: AccessKit label {label:?} looks like a raw EVE id",
                view.label(),
                size.0,
                size.1
            );
        }
        // Label-role nodes store their text in the AccessKit
        // value; numeric controls legitimately carry bare numbers
        // as values, so only label text is scanned there.
        if ak.role() == egui::accesskit::Role::Label {
            if let Some(value) = ak.value() {
                assert!(
                    !contains_raw_eve_id(&value),
                    "[UI_KITTEST] view {} at {}x{}: AccessKit label value {value:?} looks like a raw EVE id",
                    view.label(),
                    size.0,
                    size.1
                );
            }
        }
        let role = ak.role();
        let is_interactive = matches!(
            role,
            egui::accesskit::Role::Button
                | egui::accesskit::Role::CheckBox
                | egui::accesskit::Role::RadioButton
                | egui::accesskit::Role::Slider
                | egui::accesskit::Role::Tab
                | egui::accesskit::Role::TextInput
                | egui::accesskit::Role::ComboBox
        );
        if is_interactive {
            interactive += 1;
            let named = ak.label().is_some_and(|label| !label.trim().is_empty())
                || ak.value().is_some_and(|value| !value.trim().is_empty())
                || ak
                    .data()
                    .placeholder()
                    .is_some_and(|hint| !hint.trim().is_empty());
            assert!(
                named,
                "[UI_KITTEST] view {} at {}x{}: interactive {role:?} node has no accessible name",
                view.label(),
                size.0,
                size.1
            );
        }
        if let Some(bounds) = ak.bounding_box() {
            let rect = egui::Rect::from_min_max(
                egui::pos2(bounds.x0 as f32, bounds.y0 as f32),
                egui::pos2(bounds.x1 as f32, bounds.y1 as f32),
            );
            assert!(
                rect.is_finite(),
                "[UI_KITTEST] view {} at {}x{}: AccessKit rect {rect:?} for {role:?} is not finite",
                view.label(),
                size.0,
                size.1
            );
        }
    }
    assert!(
        nodes > 0,
        "[UI_KITTEST] view {} produced no AccessKit nodes",
        view.label()
    );
    assert!(
        interactive > 0,
        "[UI_KITTEST] view {} produced no interactive AccessKit nodes",
        view.label()
    );

    // Paint-level clipped bounds: every clipped shape must be
    // clipped to a rect inside the screen (same tolerance).
    assert!(
        !harness.output().shapes.is_empty(),
        "[UI_KITTEST] view {} produced no paint shapes",
        view.label()
    );
    for clipped in &harness.output().shapes {
        // Inverted clip rects are egui's empty clip (hidden tab
        // panes): they render nothing, so they cannot clip out.
        if clipped.clip_rect.min.x > clipped.clip_rect.max.x
            || clipped.clip_rect.min.y > clipped.clip_rect.max.y
        {
            continue;
        }
        assert!(
            allowed.contains_rect(clipped.clip_rect),
            "[UI_KITTEST] view {} at {}x{}: paint clip rect {:?} escapes screen {screen:?} beyond {BOUNDS_TOLERANCE}pt tolerance",
            view.label(),
            size.0,
            size.1,
            clipped.clip_rect
        );
    }
}

/// Whether this machine exposes any usable wgpu adapter.
/// Probed with the same `wgpu` build the app ships (Vulkan on
/// Linux, Metal on macOS), never with a window or surface.
pub fn has_wgpu_adapter() -> bool {
    let runtime = match tokio::runtime::Builder::new_current_thread()
        .enable_all()
        .build()
    {
        Ok(runtime) => runtime,
        Err(_) => return false,
    };
    runtime.block_on(async {
        let mut descriptor = wgpu::InstanceDescriptor::new_without_display_handle();
        descriptor.backends.remove(wgpu::Backends::BROWSER_WEBGPU);
        let instance = wgpu::Instance::new(descriptor);
        tokio::time::timeout(
            Duration::from_secs(10),
            instance.request_adapter(&wgpu::RequestAdapterOptions::default()),
        )
        .await
        .is_ok_and(|result| result.is_ok())
    })
}

/// Adapter policy for pixel snapshots: on CI a missing adapter is
/// a loud failure; locally it skips only the pixel diff.
pub fn adapter_available_or_skip(test_label: &str) -> bool {
    if has_wgpu_adapter() {
        return true;
    }
    if std::env::var("CI").is_ok_and(|value| value == "true") {
        panic!(
            "[UI_KITTEST] CI=true but no wgpu adapter found for {test_label}; \
             pixel snapshots must not silently skip in CI (mesa-vulkan-drivers installed?)"
        );
    }
    println!(
        "[UI_KITTEST] no local wgpu adapter; structural AccessKit/bounds passed, pixel diff runs in Linux CI"
    );
    false
}
