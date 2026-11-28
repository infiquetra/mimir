---
name: alidade-ui-design
description: Design and build studio-grade native Rust desktop interfaces for Alidade (egui 0.37 + wgpu Metal + egui_tiles) using astrometric dark DesignTokens, HTML/Canvas prototype gates, strict 3-size typography, and visual-first density. Trigger whenever redesigning or editing src/ui/, src/app/shell.rs, theme tokens, or UI prototypes.
---

# Alidade UI Design System (Astrometric Instrument Craft)

Stock immediate-mode `egui` looks like a programmer debug inspector when built with default borders, uniform gray surfaces, and walls of `.label(...)` prose. **Alidade** commits to an unmistakable point of view: **a precision astrometric instrument for New Eden**—modeled on Rerun's `re_ui` token architecture and Google Frontend Design's typographic and anti-clutter discipline, where **spatial canvases, flow diagrams, proportion, color conviction, and tabular numerals** carry the experience rather than text walls.

## 1. Mandatory HTML/Canvas Prototype Gate (Before Rust Layout Work)

Before rewriting any major view in `src/ui/` or adding a new spatial workspace:
1. Check `mimir-context-library/platform-specs/ui-mockups/` for the approved interactive HTML/Canvas visual prototype covering that surface.
2. If no prototype exists or the layout changes materially, author or update the static/Canvas prototype in `mimir-context-library/platform-specs/ui-mockups/` first so proportion, hierarchy, color contrast, and visual-to-text ratio are proven before spending Rust build cycles.
3. Match the Rust `egui` + `wgpu` implementation directly to the prototype's token values, pane ratios, and visual affordances.

## 2. Astrometric Color & Surface Tokens (`DesignTokens`)

Define every color in one central `DesignTokens` struct (`src/ui/theme.rs`)—never scatter inline `Color32::from_rgb(...)` literals across view files:

- **Deep Obsidian Canvas (`#090D14`)**: Root workspace background behind `egui_tiles` split panes (`1px` subtle `#1B2432` hairlines—never chunky `2px+` rounded gray `egui::Group` boxes).
- **Recessed Instrument Slate (`#101722`)**: Primary panel surface; `#16202F` elevated interactive surface on hover/selection.
- **High-Contrast Text (`>= 7:1` primary, `>= 4.5:1` muted)**: `#E6EDF7` primary ink, `#94A3B8` secondary telemetry labels, `#64748B` disabled/axis ticks.
- **Deliberate Semantic Accents (Never Rainbow Clutter)**:
  - **Alidade Brass (`#D9A441`)**: Primary bearing accent, active view indicator, and ISK/wealth focal numerals.
  - **Astrometric Cyan (`#38BDF8`)**: Active selection vector, capacitor/shield arcs, and route lines.
  - **Semantic Status**: `#2DD4BF` emerald/teal (`Ready` / `In Stock` / `Cap Stable`), `#F59E0B` amber (`Build/React` / `Step-Up Needed` / `Warning`), `#F43F5E` coral (`Bottleneck` / `Depletes` / `Alert`).

## 3. Strict 3-Size Typography & Tabular Numerals

- **At most 2 font families**: Load one crisp neo-grotesk UI family (e.g. `Inter` or `Plus Jakarta Sans`) plus tabular numerals (`monospace` or OpenType `tnum` feature) strictly for aligned ISK, countdowns, coordinates, and dogma numbers.
- **Lock 3 body font sizes across panels** (`18px` panel/section heading, `13.5px` primary row/control body, `12px` compact table/axis label—never place `< 12px` micro-text anywhere on screen). Window/masthead focal KPIs (`22–28px`) are the sole exception.
- **Sentence case everywhere**: Write `"Shield peak recharge"` and `"Active jobs"`, never tracked-out `ALL CAPS` kickers or eyebrows above headings.

## 4. "Less Text, More Visual" Workspace Rules

1. **Open directly into the live instrument**: Never push controls or spatial views below banner prose or multi-paragraph disclaimers. Move secondary dogma methodology disclosures into compact `(?)` hover tooltips or collapsible inspector drawers (`<= 65ch` when expanded).
2. **Replace prose lists with visual primitives**:
   - Ship slots -> **Radial Fitting Wheel** + **Polar Application Heatmap** (not 9 stacked text disclosure blocks).
   - Industry BOMs & PI -> **Left-to-Right Sankey-DAG Flow Canvas** with inline stock bars (not raw indented text trees).
   - Star systems & wormholes -> **Interactive 2D/3D Star Map & Subway Chain** (not plain text system lists).
   - Skill queues & job runs -> **Horizontal Gantt / Countdown Progress Strips** with live tick interpolation.
3. **Rerun-style `list_item` rows & Command Palette**:
   - Use fixed-height (`28–32px`) borderless hierarchical rows with 20px EVE type/portrait icons on the left, right-aligned tabular figures, and hover-revealed secondary actions—never wall-to-wall button grids.
   - Route rare actions and cross-view jumps through a fuzzy `Cmd+K` / `/` Command Palette rather than crowding top toolbars.
4. **Frameless macOS Chrome (`eframe 0.37`)**:
   - Use `ViewportBuilder::default().with_fullsize_content_view(true).with_titlebar_shown(false)` and `eframe::Frame::set_traffic_lights_position(...)` on macOS so the top instrument bar reserves exact left inset for native traffic lights without wasted vertical chrome.

## 5. Pre-PR UI Checklist

- [ ] Zero raw `Color32::from_rgb` outside `src/ui/theme.rs`.
- [ ] Zero raw numeric EVE IDs rendered anywhere (`NameResolver` / `Sde` enforced).
- [ ] Zero multi-sentence methodology walls blocking above-the-fold canvases (disclosures live in inspector/popover drawers with exact counts preserved).
- [ ] Single-key shortcuts gated by `state.text_input_focused || ctx.wants_keyboard_input()`.
- [ ] Every icon-only button carries `.on_hover_text(...)` / AccessKit label so `egui_kittest` passes without accessibility panics.
