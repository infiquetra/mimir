---
name: Alidade
repository: infiquetra/mimir
context_library: infiquetra/mimir-context-library
last_updated: 2026-11-27
---

# Alidade Strategy

> **Brand & Repository Note:** **Alidade** (named for the precision sighting arm of an astrolabe used to take star bearings) is the product name for our native Rust EVE Online astrometric, industrial, and fitting companion. Repository slugs remain `infiquetra/mimir` and `infiquetra/mimir-context-library` on GitHub Project #16 for Git and SDLC routing stability.

## Target problem

EVE Online players—especially on macOS—face a fragmented, Windows-centric companion ecosystem (`jEveAssets` ended maintenance in October 2025, `EVE Isk Per Hour` was marked abandoned in November 2025, `Ravworks` stalled on March 2025 static data, and `SMT` remains Windows-only C#), forcing players to juggle spreadsheets and text-heavy legacy tools that miss 2024–2026 game mechanics (`Equinox`, `Revenant`, `Legion`, `Fractured Skies`, and CCP's November 2026 `SDE over HTTP` & pure OpenAPI cutover).

## Guiding approach

Build **Alidade** as a fast, offline-capable native Rust desktop instrument (`egui 0.37` + `eframe` on `wgpu` Metal, Rerun-style `DesignTokens`, and `egui_tiles` multi-viewport docking) that replaces spreadsheet tables with **spatial, flow, and polar visualizations** (`egui_wgpu::CallbackTrait` 120 fps 2D/3D star maps, WGSL polar application envelopes, radial fitting wheels, and Sankey-DAG industry/PI pipelines) and **solver-backed AI copilots** (routing cleanly across local Home Lab, Ollama, and Colab OpenAI-compatible endpoints plus OS keyring BYOK cloud providers, grounded in live ESI, `SDE over HTTP`, and real-time local EVE client log + clipboard telemetry).

## Primary persona

Multi-character EVE Online players on macOS (with Linux and Windows secondary support) managing industrial production chains, cross-structure stockpiles ("Pantry"), wormhole/nullsec navigation, and ship fittings who want immediate visual situational awareness and mathematically verified AI recommendations rather than dense text tables.

## Key metrics

- **Sub-16.6 ms (60–120 fps) Spatial Frame Budget** — Zero dropped frames on Apple Silicon Metal across the ~8,000-system 2D/3D star map, WGSL polar application envelopes, and Sankey-DAG industry graphs (`cargo test` benchmarks + UTM Metal telemetry).
- **100% Visual & Accessibility Gate Pass Rate** — Every view passes headless `egui_kittest` pixel/AccessKit snapshot checks in host CI and locked `--demo --fixed-dt` window captures inside the `macos-test-02` UTM guest, matched against approved HTML/Canvas prototypes in `mimir-context-library`.
- **Zero Unverified Dogma or BOM Recommendations** — 100% of AI Engagement AAR, "Fit From My Hangar", Pantry liquidation, and Build-vs-Buy-vs-React outputs pass deterministic Rust dogma, inventory, and order-depth verification before display.
- **SDE-over-HTTP Freshness Lag (< 24h)** — Dynamic `SDE over HTTP` delta sync ingests new CCP expansion hulls, modules, schematics, and blueprints without requiring a binary release.

## Investment tracks (Objectives on Project #16)

1. **`ui-foundation-and-tooling`** — Upgrade `egui`/`eframe` `0.29 -> 0.37` on `wgpu` (Metal), rebrand UI/bundle to `Alidade.app`, land Rerun-inspired `DesignTokens` + `egui_tiles` workspace gated by HTML/Canvas prototypes, maintain multi-agent UI/wgpu/UTM skills (Muse, Claude, Codex, OpenCode, Gemini), and enforce `egui_kittest` + UTM visual QA.
2. **`sde-http-and-log-daemon`** — Replace compiled static JSON extracts with dynamic CCP `SDE over HTTP` + pure OpenAPI sync, add real-time macOS `FSEvents` watching of local EVE Gamelogs/Chatlogs and clipboard watcher, and ship multi-viewport pop-outs + macOS menu-bar tray notifications.
3. **`visual-fitting-and-aar`** — Replace text-heavy fitting blocks with a radial fitting wheel, 120 fps WGSL polar application & angular-velocity heatmaps, capacitor/tank curves, "Fit From My Hangar" spare-parts solver, and the revived AI Engagement AAR + synchronized timeline scrubber.
4. **`pantry-and-industry-dag`** — Deliver cross-character/cross-structure Pantry stockpile readiness, net-realized-ISK idle-stockpile liquidation routing, and `petgraph` + `dagre` + `egui-snarl` + `kurbo`/`lyon` Sankey-DAG manufacturing, reaction, invention, and Planetary Industry stall pipelines.
5. **`starmap-3d-and-intel`** — Ship a 120 fps instanced `wgpu` 2D/3D New Eden star map (`kiddo` spatial picking), capital jump-drive spheres, Equinox Power/Workforce/Skyhook overlays, Wanderer-style wormhole subway chains, and live Local/D-Scan telemetry profiling.
6. **`mining-corp-and-campaigns`** — Add live mining-log crystal/residue & Metenox passive moon break-even ledgers, role-fenced 10-scope Corporation management (hangars, wallets, structure fuel), and Faction Campaign / Freelance Job tracking.
