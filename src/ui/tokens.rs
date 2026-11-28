//! Centralized Astrometric design tokens (#652).
//!
//! Every color, spacing step, corner radius, and type size
//! in the shell and views resolves through
//! [`DesignTokens`] (the single `TOKENS` constant). Inline
//! `Color32::from_rgb` literals are forbidden outside this
//! file; the permanent guard test
//! `no_inline_rgb_literals_outside_tokens` walks
//! `src/ui/` and `src/app/` on every `cargo test` run and
//! fails on any violation, binding every later UI card.
//!
//! Palette roles follow the Astrometric spec
//! (`visual-design-tokens-and-canvases.md`): deep obsidian
//! surfaces, brass sight accent, cyan telemetry accent,
//! strict 3-size body typography (18 / 13.5 / 12 px) with
//! tabular numerals for every numeric readout. Exact
//! shades preserve the shipped theme where the spec is
//! silent so the gate changes structure, not identity.
//! Logs nothing (render-cadence constants).

use egui::{Color32, FontId};

/// Strict 3-size body typography plus tabular numerals.
/// Sizes are points; `mono` backs every ISK, DPS, EHP,
/// volume, and countdown readout (monospace digits are
/// tabular by construction).
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct Typography {
    /// Panel and section headings (18 px).
    pub heading: f32,
    /// Primary row and control body (13.5 px).
    pub body: f32,
    /// Compact table and axis labels (12 px floor; never
    /// smaller anywhere in the UI).
    pub small: f32,
    /// Tabular numeral size (12 px, monospace family).
    pub mono: f32,
}

impl Typography {
    pub fn heading_font(&self) -> FontId {
        FontId::proportional(self.heading)
    }

    pub fn body_font(&self) -> FontId {
        FontId::proportional(self.body)
    }

    pub fn small_font(&self) -> FontId {
        FontId::proportional(self.small)
    }

    /// Tabular numeral font: monospace family, so digit
    /// columns never jitter as values tick.
    pub fn mono_font(&self) -> FontId {
        FontId::monospace(self.mono)
    }
}

/// The Astrometric token set. One `const` instance
/// ([`TOKENS`]) is the single source of truth; `theme.rs`
/// re-exports its fields under the shipped constant names.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct DesignTokens {
    // Surfaces (deep obsidian-slate elevation steps).
    pub bg_abyss: Color32,
    pub bg_deck: Color32,
    pub bg_panel: Color32,
    pub bg_card: Color32,
    pub bg_card_elevated: Color32,
    pub bg_input: Color32,
    pub bg_faint: Color32,
    pub bg_hover: Color32,
    // Strokes.
    pub stroke_hairline: Color32,
    pub stroke_strong: Color32,
    // Accents.
    pub brass_sight: Color32,
    pub cyan_telemetry: Color32,
    pub accent_fill: Color32,
    // Text.
    pub text_primary: Color32,
    /// Secondary body text; WCAG AA (>= 4.5:1) on both
    /// `bg_panel` and `bg_card_elevated` by test.
    pub text_muted: Color32,
    /// Disabled and axis-tick ink only; never body text
    /// (below AA by design, like every disabled style).
    pub text_disabled: Color32,
    // Status.
    pub positive: Color32,
    pub positive_bg: Color32,
    pub negative: Color32,
    pub negative_bg: Color32,
    pub warning: Color32,
    pub warning_bg: Color32,
    pub danger: Color32,
    // EVE damage channels.
    pub dmg_em: Color32,
    pub dmg_thermal: Color32,
    pub dmg_kinetic: Color32,
    pub dmg_explosive: Color32,
    // Security bands.
    pub sec_high: Color32,
    pub sec_low: Color32,
    pub sec_null: Color32,
    pub sec_wh: Color32,
    // Shape and rhythm.
    pub radius_control: u8,
    pub radius_card: u8,
    pub radius_window: u8,
    pub spacing_item_x: f32,
    pub spacing_item_y: f32,
    pub typography: Typography,
}

impl DesignTokens {
    /// The Astrometric palette. The only place in the
    /// crate where `Color32::from_rgb` literals may exist.
    pub const fn astrometric() -> Self {
        Self {
            bg_abyss: Color32::from_rgb(0x07, 0x0A, 0x10),
            bg_deck: Color32::from_rgb(0x0D, 0x11, 0x17),
            bg_panel: Color32::from_rgb(0x12, 0x19, 0x26),
            bg_card: Color32::from_rgb(0x17, 0x1F, 0x2C),
            bg_card_elevated: Color32::from_rgb(0x18, 0x22, 0x33),
            bg_input: Color32::from_rgb(0x0A, 0x0E, 0x14),
            bg_faint: Color32::from_rgb(0x15, 0x1D, 0x29),
            bg_hover: Color32::from_rgb(0x22, 0x30, 0x44),
            stroke_hairline: Color32::from_rgb(0x24, 0x32, 0x4A),
            stroke_strong: Color32::from_rgb(0x33, 0x41, 0x55),
            brass_sight: Color32::from_rgb(0xE5, 0xB5, 0x67),
            cyan_telemetry: Color32::from_rgb(0x38, 0xBD, 0xF8),
            accent_fill: Color32::from_rgb(0x16, 0x4E, 0x63),
            text_primary: Color32::from_rgb(0xE6, 0xED, 0xF7),
            text_muted: Color32::from_rgb(0x8B, 0x9B, 0xB4),
            text_disabled: Color32::from_rgb(0x64, 0x74, 0x8B),
            positive: Color32::from_rgb(0x34, 0xD3, 0x99),
            positive_bg: Color32::from_rgb(0x0E, 0x2A, 0x22),
            negative: Color32::from_rgb(0xF8, 0x71, 0x71),
            negative_bg: Color32::from_rgb(0x33, 0x14, 0x18),
            warning: Color32::from_rgb(0xF5, 0x9E, 0x0B),
            warning_bg: Color32::from_rgb(0x2B, 0x21, 0x11),
            danger: Color32::from_rgb(0xEF, 0x44, 0x44),
            dmg_em: Color32::from_rgb(0x38, 0xBD, 0xF8),
            dmg_thermal: Color32::from_rgb(0xF8, 0x71, 0x71),
            dmg_kinetic: Color32::from_rgb(0x94, 0xA3, 0xB8),
            dmg_explosive: Color32::from_rgb(0xFB, 0xBF, 0x24),
            sec_high: Color32::from_rgb(0x22, 0xD3, 0xEE),
            sec_low: Color32::from_rgb(0xF5, 0x9E, 0x0B),
            sec_null: Color32::from_rgb(0xEF, 0x44, 0x44),
            sec_wh: Color32::from_rgb(0xA8, 0x55, 0xF7),
            radius_control: 6,
            radius_card: 8,
            radius_window: 8,
            spacing_item_x: 8.0,
            spacing_item_y: 6.0,
            typography: Typography {
                heading: 18.0,
                body: 13.5,
                small: 12.0,
                mono: 12.0,
            },
        }
    }
}

/// The single token instance every surface consumes.
pub const TOKENS: DesignTokens = DesignTokens::astrometric();

/// WCAG relative luminance of an opaque color.
pub fn relative_luminance(color: Color32) -> f64 {
    fn linear(channel: u8) -> f64 {
        let value = f64::from(channel) / 255.0;
        if value <= 0.03928 {
            value / 12.92
        } else {
            ((value + 0.055) / 1.055).powf(2.4)
        }
    }
    0.2126 * linear(color.r()) + 0.7152 * linear(color.g()) + 0.0722 * linear(color.b())
}

/// WCAG contrast ratio between two opaque colors,
/// `(lighter + 0.05) / (darker + 0.05)`.
pub fn contrast_ratio(a: Color32, b: Color32) -> f64 {
    let (la, lb) = (relative_luminance(a), relative_luminance(b));
    let (hi, lo) = if la >= lb { (la, lb) } else { (lb, la) };
    (hi + 0.05) / (lo + 0.05)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::{Path, PathBuf};

    #[test]
    fn wcag_aa_contrast_for_body_text_on_surfaces() {
        // Acceptance: >= 4.5:1 for primary and muted text
        // against both panel surfaces. Hand-computed
        // references: primary on panel 14.94, muted on
        // elevated 5.66 (the tightest pair).
        for (label, ratio) in [
            (
                "primary/panel",
                contrast_ratio(TOKENS.text_primary, TOKENS.bg_panel),
            ),
            (
                "primary/elevated",
                contrast_ratio(TOKENS.text_primary, TOKENS.bg_card_elevated),
            ),
            (
                "muted/panel",
                contrast_ratio(TOKENS.text_muted, TOKENS.bg_panel),
            ),
            (
                "muted/elevated",
                contrast_ratio(TOKENS.text_muted, TOKENS.bg_card_elevated),
            ),
        ] {
            assert!(
                ratio >= 4.5,
                "{label} contrast {ratio:.2} below WCAG AA 4.5"
            );
        }
        // Primary text clears the >= 7:1 high-contrast bar.
        assert!(contrast_ratio(TOKENS.text_primary, TOKENS.bg_panel) >= 7.0);
    }

    #[test]
    fn typography_is_strict_three_size_body_with_tabular_mono() {
        let typo = TOKENS.typography;
        assert_eq!(typo.heading, 18.0);
        assert_eq!(typo.body, 13.5);
        assert_eq!(typo.small, 12.0);
        assert_eq!(typo.mono, 12.0);
        assert_eq!(typo.mono_font().family, egui::FontFamily::Monospace);
        assert_eq!(typo.body_font().family, egui::FontFamily::Proportional);
    }

    fn rust_files(root: &Path, out: &mut Vec<PathBuf>) {
        let Ok(entries) = std::fs::read_dir(root) else {
            return;
        };
        for entry in entries.flatten() {
            let path = entry.path();
            if path.is_dir() {
                rust_files(&path, out);
            } else if path.extension().is_some_and(|ext| ext == "rs") {
                out.push(path);
            }
        }
    }

    /// Permanent guard (#652): `Color32::from_rgb` may
    /// exist only in this file. The needle is assembled
    /// from parts so this test never trips itself; this
    /// file is excluded by path regardless.
    #[test]
    fn no_inline_rgb_literals_outside_tokens() {
        let needle = ["Color32::from", "_rgb"].concat();
        let manifest = Path::new(env!("CARGO_MANIFEST_DIR"));
        let tokens_path = manifest.join("src/ui/tokens.rs");
        let mut files = Vec::new();
        rust_files(&manifest.join("src/ui"), &mut files);
        rust_files(&manifest.join("src/app"), &mut files);
        assert!(!files.is_empty(), "guard must scan real files");
        let mut violations: Vec<String> = Vec::new();
        for file in files {
            if file == tokens_path {
                continue;
            }
            let Ok(text) = std::fs::read_to_string(&file) else {
                continue;
            };
            if text.contains(&needle) {
                violations.push(file.display().to_string());
            }
        }
        assert!(
            violations.is_empty(),
            "inline RGB literals outside src/ui/tokens.rs: {violations:?}"
        );
    }
}
