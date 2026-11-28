---
name: alidade-visual-qa
description: "Execute two-tier automated UI, accessibility, and Metal visual verification for Alidade: Tier 1 headless egui_kittest + AccessKit snapshots on host CI, and Tier 2 SSH-locked full-window testing inside the hidden macos-test-02 UTM guest. Trigger before merging any UI, layout, or visualization PR."
---

# Alidade Two-Tier Visual & GUI Verification

Every change to `src/ui/`, `src/app/shell.rs`, theme tokens, or `wgpu` shaders must be proven visually and interactively—never merged on `cargo check` alone.

> **CRITICAL HOST DESKTOP GUARDRAIL:** Never launch GUI windows (`cargo run`, `Mimir.app`, `Alidade.app`), run `screencapture`, or synthesize mouse/keyboard events (`cliclick`) on the operator's live Mac Studio host desktop. Host runs steal focus and disrupt active work. Run Tier 1 headlessly in `cargo test`, and run all Tier 2 live-window checks over SSH inside the hidden **`macos-test-02`** (or `macos-test-03`) UTM guest.

## Tier 1: Headless `egui_kittest` + AccessKit Gate (Host & CI)

Run fast (`5–50 ms/test`) deterministic headless rendering and semantic widget checks via `egui_kittest`:

1. **Semantic AccessKit Queries**: Drive views through labels (`harness.get_by_label(...)`), never brittle pixel coordinates, for standard controls. `egui_kittest` panics if an interactive widget lacks an accessible label—treat every missing label on icon-only EVE buttons or slot controls as a bug.
2. **Deterministic Snapshot Diffs**:
   - Freeze time (`--fixed-dt`), disable cursor blink, use bundled `--demo` fixtures, and disable MSAA (`sample_count = 1`) in snapshot harnesses so Metal and Linux software `wgpu` stay within YIQ perceptual diff thresholds (`kittest.toml`: `threshold = 0.6`, `max_failed_pixels = 0`).
   - Assert every rendered state contains zero raw numeric EVE IDs and matches layout bounds across `1280x800` and `1600x1000` viewports.

## Tier 2: Full Metal Window & Interaction QA in `macos-test-02` UTM Guest

When verifying `eframe` macOS window chrome, traffic-light positioning, Retina scaling, custom `wgpu` Metal passes, system tray icons, or multi-step user journeys:

### 1. Acquire the Guest Lock & Boot Hidden

Serialize guest usage across builders with an atomic lock directory on the guest:

```sh
# Host shell (never opens a window on host)
if [ "$(/Applications/UTM.app/Contents/MacOS/utmctl status macos-test-02)" = stopped ]; then
  /Applications/UTM.app/Contents/MacOS/utmctl start --hide macos-test-02
fi

guest=macos-test-02.local
shots=$(mktemp -d "${TMPDIR:-/tmp}/alidade-shots.XXXXXX")
ssh -4 -o BatchMode=yes "$guest" 'umask 077; mkdir /tmp/alidade-visual-qa.lock'
```

Always release `/tmp/alidade-visual-qa.lock` (`rmdir /tmp/alidade-visual-qa.lock`) in a `trap` when collection finishes.

### 2. Stage & Launch Deterministically Inside the Guest

Sync the built binary/bundle to a scratch directory in the guest and launch in isolated `--demo` mode:

```sh
# Inside macos-test-02 guest over SSH
export RUST_LOG="info,mimir=debug"
./alidade --demo --view dashboard --window-size 1440x900 --fixed-dt &
app_pid=$!
```

### 3. Inspect Accessibility & Drive Spatial Canvases

- **Accessibility tree**: Query `eframe`'s native macOS `NSAccessibility` (`AccessKit`) bridge using `axcli` or Rust `accessibility` crate wrappers. (**Never** use `x3ro/macos-accessibility-client`, which was archived in January 2026.)
- **Spatial canvas interactions**: For custom `wgpu` star maps, Sankey-DAG nodes, and radial fitting slots, read the canvas container's `AXPosition` + `AXSize`, compute target coordinates, and dispatch `CGEvent` clicks/drags inside the guest via `cliclick` (`cliclick c:x,y` or `dd:x1,y1 dm:x2,y2 du:x2,y2`).
- **Window-scoped capture**: Capture crisp Retina screenshots by `CGWindowID` (`screencapture -x -o -l <wid> shots/<view>.png`), copy PNGs back to `$shots` on the host, kill `$app_pid`, release `/tmp/alidade-visual-qa.lock`, and inspect every captured PNG visually against the `mimir-context-library` UI prototype before sign-off.
