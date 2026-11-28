//! Alidade theme application: consumes the centralized
//! Astrometric [`DesignTokens`](super::tokens::TOKENS) and
//! installs visuals, spacing, and the strict 3-size type
//! scale once at startup. Color literals live only in
//! `src/ui/tokens.rs` (#652 guard); the shipped constant
//! names below are token aliases so existing call sites
//! keep compiling while every value has one source.

use egui::{Color32, CornerRadius, Margin, Stroke, TextStyle};

use super::tokens::TOKENS;

pub const BG_CANVAS: Color32 = TOKENS.bg_abyss;
pub const BG_DECK: Color32 = TOKENS.bg_deck;
pub const BG_PANEL: Color32 = TOKENS.bg_panel;
pub const BG_CARD: Color32 = TOKENS.bg_card;
pub const BG_CARD_ALT: Color32 = TOKENS.bg_card_elevated;
pub const BG_INPUT: Color32 = TOKENS.bg_input;
pub const BG_FAINT: Color32 = TOKENS.bg_faint;

pub const BORDER_SUBTLE: Color32 = TOKENS.stroke_hairline;
pub const BORDER_STRONG: Color32 = TOKENS.stroke_strong;

pub const ACCENT_CYAN: Color32 = TOKENS.cyan_telemetry;
pub const ACCENT_BRASS: Color32 = TOKENS.brass_sight;
pub const ACCENT_BLUE_FILL: Color32 = TOKENS.accent_fill;

pub const TEXT_PRIMARY: Color32 = TOKENS.text_primary;
/// Secondary body text (token `text_muted`, WCAG AA).
pub const TEXT_SECONDARY: Color32 = TOKENS.text_muted;
/// Disabled and caption ink (token `text_disabled`).
pub const TEXT_MUTED: Color32 = TOKENS.text_disabled;

pub const POSITIVE: Color32 = TOKENS.positive;
pub const POSITIVE_BG: Color32 = TOKENS.positive_bg;
pub const NEGATIVE: Color32 = TOKENS.negative;
pub const NEGATIVE_BG: Color32 = TOKENS.negative_bg;
pub const WARNING: Color32 = TOKENS.warning;
pub const WARNING_BG: Color32 = TOKENS.warning_bg;

/// Left inset (points) clearing the macOS traffic-light buttons
/// when the content view extends under a hidden titlebar; zero on
/// other platforms where native chrome keeps its own controls.
#[cfg(target_os = "macos")]
pub fn traffic_light_inset() -> f32 {
    78.0
}

/// Left inset (points) clearing the macOS traffic-light buttons;
/// zero off macOS.
#[cfg(not(target_os = "macos"))]
pub fn traffic_light_inset() -> f32 {
    0.0
}

/// Configure Alidade's Astrometric theme, spacing, and the
/// strict 3-size type scale (18 / 13.5 / 12, tabular mono)
/// on the egui context from [`TOKENS`].
pub fn apply(ctx: &egui::Context) {
    let t = TOKENS;
    let mut visuals = egui::Visuals::dark();
    visuals.dark_mode = true;
    visuals.override_text_color = Some(t.text_primary);
    visuals.panel_fill = t.bg_abyss;
    visuals.window_fill = t.bg_panel;
    visuals.extreme_bg_color = t.bg_input;
    visuals.faint_bg_color = t.bg_faint;
    visuals.code_bg_color = t.bg_input;
    visuals.warn_fg_color = t.warning;
    visuals.error_fg_color = t.negative;
    visuals.hyperlink_color = t.cyan_telemetry;

    visuals.selection.bg_fill = t.accent_fill;
    visuals.selection.stroke = Stroke::new(1.0_f32, t.cyan_telemetry);

    let radius = CornerRadius::same(t.radius_control);
    visuals.window_corner_radius = CornerRadius::same(t.radius_window);
    visuals.window_stroke = Stroke::new(1.0_f32, t.stroke_strong);

    visuals.widgets.noninteractive.bg_fill = t.bg_card;
    visuals.widgets.noninteractive.weak_bg_fill = t.bg_panel;
    visuals.widgets.noninteractive.bg_stroke = Stroke::new(1.0_f32, t.stroke_hairline);
    visuals.widgets.noninteractive.fg_stroke = Stroke::new(1.0_f32, t.text_primary);
    visuals.widgets.noninteractive.corner_radius = radius;

    visuals.widgets.inactive.bg_fill = t.bg_card_elevated;
    visuals.widgets.inactive.weak_bg_fill = t.bg_card;
    visuals.widgets.inactive.bg_stroke = Stroke::new(1.0_f32, t.stroke_strong);
    visuals.widgets.inactive.fg_stroke = Stroke::new(1.0_f32, t.text_primary);
    visuals.widgets.inactive.corner_radius = radius;

    visuals.widgets.hovered.bg_fill = t.bg_hover;
    visuals.widgets.hovered.weak_bg_fill = t.bg_hover;
    visuals.widgets.hovered.bg_stroke = Stroke::new(1.0_f32, t.cyan_telemetry);
    visuals.widgets.hovered.fg_stroke = Stroke::new(1.5_f32, t.text_primary);
    visuals.widgets.hovered.corner_radius = radius;

    visuals.widgets.active.bg_fill = t.accent_fill;
    visuals.widgets.active.weak_bg_fill = t.accent_fill;
    visuals.widgets.active.bg_stroke = Stroke::new(1.0_f32, t.cyan_telemetry);
    visuals.widgets.active.fg_stroke = Stroke::new(1.5_f32, t.text_primary);
    visuals.widgets.active.corner_radius = radius;

    visuals.widgets.open.bg_fill = t.bg_card_elevated;
    visuals.widgets.open.weak_bg_fill = t.bg_card;
    visuals.widgets.open.bg_stroke = Stroke::new(1.0_f32, t.stroke_strong);
    visuals.widgets.open.fg_stroke = Stroke::new(1.0_f32, t.text_primary);
    visuals.widgets.open.corner_radius = radius;

    ctx.set_visuals(visuals);

    let mut style = (*ctx.global_style()).clone();
    style.spacing.item_spacing = egui::vec2(t.spacing_item_x, t.spacing_item_y);
    style.spacing.button_padding = egui::vec2(10.0, 5.0);
    style.spacing.interact_size.y = 26.0;
    style.spacing.window_margin = Margin::same(12);
    style
        .text_styles
        .insert(TextStyle::Heading, t.typography.heading_font());
    style
        .text_styles
        .insert(TextStyle::Body, t.typography.body_font());
    style
        .text_styles
        .insert(TextStyle::Button, t.typography.body_font());
    style
        .text_styles
        .insert(TextStyle::Monospace, t.typography.mono_font());
    style
        .text_styles
        .insert(TextStyle::Small, t.typography.small_font());
    ctx.set_global_style(style);

    tracing::debug!("[UI] applied Astrometric DesignTokens theme");
}
