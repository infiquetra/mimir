---
name: alidade-wgpu-viz
description: Architect and implement 120 fps GPU-accelerated 2D/3D visualizations in Alidade on egui 0.37 + eframe wgpu (Metal): petgraph + dagre + egui-snarl + kurbo/lyon Sankey-DAG pipelines, instanced 8,000-system 3D star maps with kiddo spatial picking, radial fitting wheels, and WGSL polar application shaders.
---

# Alidade `wgpu` Spatial, Flow & Polar Visualizations

Alidade runs on **`egui 0.37` + `eframe` (`wgpu` Metal backend)** specifically because `egui_wgpu::CallbackTrait` shares the native `wgpu::Device`, `Queue`, and `RenderPass` directly for zero-copy 120 fps 2D/3D viewports alongside `epaint::Mesh` vector tessellation. Follow these exact patterns when building visual canvases.

## 1. Industry, Reactions & Planetary Industry (Sankey-DAG Pipelines)

- **Canonical Graph Model (`petgraph 0.8`)**: Represent blueprint BOMs, reaction chains, and PI colony links in `petgraph::stable_graph::StableDiGraph<NodePayload, EdgeFlow>` for cycle safety, topological sorting, and critical-path bottleneck calculation.
- **Deterministic Tiered Auto-Layout (`dagre` / Sugiyama)**: Never make users manually untangle machine-generated BOM trees. Compute initial `(x, y)` node ranks left-to-right (Raw/Pantry Inputs -> Reactions/Components -> Final Hull/Module) via `dagre` or Sugiyama rank assignment, caching node positions per `(blueprint_id, layout_generation)` so frames never re-solve layout unless topology changes.
- **Interactive Node Chrome (`egui-snarl 0.12`)**: Use `egui-snarl` (`Snarl<BomNode>` + `SnarlViewer`) for zoomable/pannable node editing with 5-zone node headers: 32px EVE item icon, ME/TE or schematic cycle badge, inline Build/Buy/React segmented toggle, and a bottom Pantry stock progress bar.
- **Proportional Sankey Ribbons (`kurbo 0.13` + `lyon 1.0`)**:
  - Scale ribbon stroke/fill thickness proportionally to `log1p(isk_value)` or `m3_volume`.
  - Construct smooth cubic Bézier ribbons in `kurbo::BezPath`, tessellate via `lyon::tessellation::FillTessellator` into `egui::epaint::Mesh`, and cache the `Mesh` until pan/zoom/selection invalidates it.
  - Color-code flows semantically: Emerald (`100% in Pantry`), Amber (`Buildable / Active Job`), Coral (`Missing Bottleneck -> 1-click Multibuy`).

## 2. 120 fps 2D/3D New Eden Star Map & Wormhole Chains (~8,000 Systems)

- **Zero-Copy Instanced Pass (`egui_wgpu::CallbackTrait`)**:
  - Upload static solar system records (`pos_xyz: [f32; 3]`, `sec_status: f32`, `region_id: u32`) once at startup into a GPU vertex/storage buffer, paired with a dynamic per-system overlay buffer (`activity_heat`, `sov_power_workforce`, `pilot_presence_mask`).
  - Render all ~8,000 stars in **1 instanced quad draw call** (`6 vertices x N instances`) using camera-facing WGSL billboards with signed-distance-field (SDF) radial glow falloff—never tessellate sphere meshes per star.
  - Render stargates, Ansiblex bridges, and A*/Dijkstra routes (`petgraph`) in **1 instanced line/ribbon pass**, and render capital jump-drive envelopes as translucent backface-culled Fresnel spheres in an offscreen depth-enabled pass.
- **Sub-Microsecond Spatial Picking (`kiddo 6.3`)**:
  - Build a `kiddo::ImmutableKdTree<f32, 3>` over 3D universe coordinates for instant `.within::<SquaredEuclidean>(jump_ly_sq)` jump-envelope queries.
  - Maintain a 2D screen-space spatial index of projected visible systems per camera move so cursor hover and marquee selection run in `< 5 µs` with zero frame hitching.
- **Camera Rig (`glam`)**: Use frame-rate-independent exponential smoothing (`1.0 - (-stiffness * dt).exp()`) for orbit, pan, and zoom transitions, plus a toggleable flattening parameter `0.0 (3D Orbit) <-> 1.0 (2D Schematic / Subway Plane)` honoring reduced-motion settings.

## 3. Radial Ship Fitting Wheel & WGSL Polar Application Envelopes

- **Circular Fitting Wheel (`kurbo` + `lyon` -> `epaint::Mesh`)**:
  - Tessellate crisp anti-aliased concentric rings for High, Mid, Low, Rig, and Subsystem arcs plus radial CPU, Powergrid, Calibration, and 4-channel (EM/Therm/Kin/Exp) EHP resist gauges.
  - Place interactive 32px module & charge slots at polar coordinates `(cx + r * theta.cos(), cy + r * theta.sin())` via `ui.put(slot_rect, ...)`, exposing full AccessKit labels (`"High Slot 1: Heavy Missile Launcher II (Scourge Fury)"`).
- **Real-Time Polar Damage Application Shader (`egui_wgpu::CallbackTrait`)**:
  - Evaluate EVE turret tracking (`0.5 ^ (...)`) and missile explosion radius/velocity formulas per pixel in polar coordinates `(radius = range_km, angle = target_transversal_or_angular_vel)` inside a lightweight WGSL fragment shader fed by a uniform buffer (`ShipWeaponUniforms`).
  - Draw crisp 25% / 50% / 75% / 90% hit-quality contour isolines using `fwidth()` screen-space derivatives so scrubbing target speed/sig sliders updates at 120 fps with zero CPU plotting lag.
- **Synchronized Timelines (`egui_plot 0.38`)**: Use `egui_plot` with linked X-axes (`link_axis`) for Combat AAR engagement replay scrubbers (Range/Transversal + Capacitor % + Incoming/Outgoing DPS + Breacher Pod raw-HP DoT ticks).

## 4. Shader & Snapshot Determinism Guardrails

- When running under `--fixed-dt` or `egui_kittest` snapshot harnesses, force `sample_count = 1`, clamp UV/polar denominators away from `0.0` (preventing `NaN`/`Inf` pixel differences across Apple Silicon Metal vs Linux Lavapipe CI), and keep all `CallbackTrait` GPU resources keyed inside `CallbackResources` (`egui_wgpu::RenderState::renderer`) rather than global statics.
